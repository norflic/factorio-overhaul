--[[
  Lot PETROLE-RANGEE (directive du DC, 8/11 vers 18 h : « Un joueur humain pose des chevalets sur l'intégralité des puits disponibles,
  les relie entre eux, et fait sortir tout ce pétrole brut vers une ligne principale »). COLLECTEUR d'un champ de puits : règle PURE
  (aucune API du jeu, aucun nom d'objet : l'extracteur arrive en DONNÉES, lu aux prototypes par script/ai3/petrole.lua ; test :
  tests/collecteur_test.lua, mutants compris).

  Col.plan(req) pose, pour un lot de puits :
    1. les EXTRACTEURS : un par puits, centré sur lui, dans la direction dont le raccord de sortie (lu au prototype, par direction)
       donne le plus court embranchement ; deux emprises ne se chevauchent jamais, un puits sans emprise libre est écarté AVEC SA CAUSE ;
    2. un COLLECTEUR (épine dorsale) : UNE ligne droite de tuyaux qui traverse le champ (horizontale ou verticale, la plus longue étendue
       d'abord, la ligne qui sert le plus de puits en embranchement droit), prolongeant la ligne d'un lot précédent (req.hint) ;
    3. des EMBRANCHEMENTS : chaque raccord de sortie rejoint le réseau (collecteur, réseau existant, embranchements déjà posés) par un
       tuyau DROIT, sinon EN L (deux segments), jamais un tracé quelconque ; le puits le plus proche du collecteur d'abord ;
    4. les COMPOSANTES : les tuyaux posés qui ne touchent pas le réseau existant forment des composantes, chacune avec la tuile d'où la
       relier à lui (la plus proche de req.toward) : la ligne principale vers les machines est tracée par l'appelant (A* par tranches).
  Entrée req :
    wells    { {x, y} } centres des puits (nombres, ceux du jeu) ;
    ext      { w, h, boxes = { { type, conns = { [0|2|4|6] = { {x, y}, ... } } } } } : l'extracteur du relevé (shared/ai3/fluides.lua) ;
    free     function(tx, ty) -> vrai si la tuile peut porter un tuyau ou une emprise (ni eau, ni falaise, ni bâtiment, ni tuyau d'un autre
             fluide) ; elle est appelée au plus une fois par tuile (mémoire locale) ;
    net      { [clé de tuile] = vrai } tuyaux du brut déjà posés (réseau existant), facultatif ; clé = Col.tkey(tx, ty) ;
    toward   { x, y } où la ligne principale doit aller (défaut : le centre du réseau existant, sinon des puits) ;
    max_n    puits au plus dans ce lot (défaut tous) ; hint { axis = "h" | "v", c } la ligne du collecteur précédent, facultatif.
  Sortie : { extractors = { {x, y, dir, cx, cy, len, kind} }, tubes = { clés triées }, skipped = { {x, y, cause, code} }, deferred = n,
             trunk = { axis, c, a, b } ou nil, comps = { { from = {tx, ty}, n = tuyaux } }, joined = vrai si rien à relier, spent = nombre de
             tuiles lues }.
  Déterminisme : listes triées, égalités départagées par la distance, puis y, puis x, puis la direction ; aucun hasard, aucune
  trigonométrie, aucun temps mesuré.
]]

local Col = {}

Col.MAX_BRANCH = 14   -- longueur d'un embranchement droit ou en L (tuiles de tuyau neuves)
Col.MAX_LINK = 40     -- … au second tour, pour les puits restés seuls
Col.SHIFTS = 6        -- lignes de collecteur essayées de part et d'autre de la médiane
Col.PAD = 2           -- tuiles de part et d'autre des puits sur la ligne du collecteur
Col.TOP = 4           -- lignes retenues à l'étape 2 pour le calcul complet des embranchements
Col.TARGETS = 5       -- tuiles du réseau les plus proches d'un puits, essayées comme cibles d'un embranchement

local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
local DIRS = { 0, 2, 4, 6 }
Col.DV = DV

local floor, abs = math.floor, math.abs

--- Clé d'une tuile : la formule de shared/ai3/fluides.lua (Fl.tkey), recopiée pour ne pas dépendre de lui.
local function tkey(x, y) return (x + 1048576) * 2097152 + (y + 1048576) end
Col.tkey = tkey
local function untkey(k) return floor(k / 2097152) - 1048576, k % 2097152 - 1048576 end
Col.untkey = untkey

local function rect_of(w, h, cx, cy, dir)
  if dir == 2 or dir == 6 then w, h = h, w end
  local x0, y0 = floor(cx - w / 2 + 0.01), floor(cy - h / 2 + 0.01)
  return x0, y0, x0 + w - 1, y0 + h - 1
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Raccord de sortie de l'extracteur pour la direction `dir` : (tx, ty) de la tuile voisine où un tuyau se raccorde, ou nil.
local function out_conn(ext, cx, cy, dir)
  for _, b in ipairs(ext.boxes or {}) do
    if b.type == "output" or b.type == "input-output" then
      local p = b.conns and b.conns[dir] and b.conns[dir][1]
      if p then return floor(cx + (p[1] or p.x) + 0.01), floor(cy + (p[2] or p.y) + 0.01) end
    end
  end
  return nil
end
Col.out_conn = out_conn

---------------------------------------------------------------------------------------------------
-- Champ
---------------------------------------------------------------------------------------------------
--- Les puits d'un MÊME champ : ceux liés, de proche en proche (écart de Tchebychev au plus `gap` tuiles), à l'un des points `seeds`
--- (les puits déjà équipés du site). Rend la liste triée (y, x), au plus `max` puits : quand il faut couper, les plus proches du centre
--- des `seeds` restent. Les puits qui sont eux-mêmes des `seeds` sont rendus aussi (l'appelant les écarte s'ils sont équipés).
function Col.cluster(wells, seeds, gap, max)
  local pts = {}
  for _, w in ipairs(wells or {}) do pts[#pts + 1] = { x = w.x, y = w.y } end
  table.sort(pts, function(a, b)
    if a.y ~= b.y then return a.y < b.y end
    return a.x < b.x
  end)
  local front, inside = {}, {}
  for _, s in ipairs(seeds or {}) do front[#front + 1] = { x = s.x, y = s.y } end
  local sx, sy = 0, 0
  for _, s in ipairs(front) do sx, sy = sx + s.x, sy + s.y end
  if #front > 0 then sx, sy = sx / #front, sy / #front end
  local changed = #front > 0
  while changed do
    changed = false
    for i, p in ipairs(pts) do
      if not inside[i] then
        for _, q in ipairs(front) do
          if abs(p.x - q.x) <= gap and abs(p.y - q.y) <= gap then
            inside[i] = true
            front[#front + 1] = p
            changed = true
            break
          end
        end
      end
    end
  end
  local out = {}
  for i, p in ipairs(pts) do if inside[i] then out[#out + 1] = p end end
  if max and #out > max then
    table.sort(out, function(a, b)
      local da, db = (a.x - sx) ^ 2 + (a.y - sy) ^ 2, (b.x - sx) ^ 2 + (b.y - sy) ^ 2
      if da ~= db then return da < db end
      if a.y ~= b.y then return a.y < b.y end
      return a.x < b.x
    end)
    local cut = {}
    for i = 1, max do cut[i] = out[i] end
    table.sort(cut, function(a, b)
      if a.y ~= b.y then return a.y < b.y end
      return a.x < b.x
    end)
    out = cut
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Plan
---------------------------------------------------------------------------------------------------
function Col.plan(req)
  local ext = req.ext or {}
  local ew, eh = ext.w or 1, ext.h or 1
  local S0 = req.net or {}
  local spent = 0
  local memo = {}
  local function free(tx, ty)
    local k = tkey(tx, ty)
    local v = memo[k]
    if v == nil then
      spent = spent + 1
      v = req.free(tx, ty) and true or false
      memo[k] = v
    end
    return v
  end
  local out = { extractors = {}, tubes = {}, skipped = {}, deferred = 0, comps = {}, joined = true, spent = 0 }

  -- direction de la ligne principale
  local tx0, ty0
  if req.toward then
    tx0, ty0 = req.toward.x, req.toward.y
  else
    local n, sx, sy = 0, 0, 0
    for _, k in ipairs(sorted_keys(S0)) do
      local x, y = untkey(k)
      n, sx, sy = n + 1, sx + x, sy + y
    end
    if n == 0 then
      for _, w in ipairs(req.wells or {}) do n, sx, sy = n + 1, sx + w.x, sy + w.y end
    end
    if n > 0 then tx0, ty0 = sx / n, sy / n else tx0, ty0 = 0, 0 end
  end
  local function d2(x, y) return (x - tx0) ^ 2 + (y - ty0) ^ 2 end

  -----------------------------------------------------------------------------------------------
  -- 1. Puits : emprises, dans l'ordre de la distance à la ligne principale
  -----------------------------------------------------------------------------------------------
  local wells = {}
  for _, w in ipairs(req.wells or {}) do wells[#wells + 1] = { x = w.x, y = w.y } end
  table.sort(wells, function(a, b)
    local da, db = d2(a.x, a.y), d2(b.x, b.y)
    if da ~= db then return da < db end
    if a.y ~= b.y then return a.y < b.y end
    return a.x < b.x
  end)
  local occ = {}      -- tuiles des emprises acceptées
  local acc = {}      -- puits acceptés : { x, y, opts = { [dir] = { cx, cy } } }
  local max_n = req.max_n or math.huge
  for _, w in ipairs(wells) do
    if #acc >= max_n then
      out.deferred = out.deferred + 1
    else
      local opts, any_free, any_conn = {}, false, false
      local nopts = 0
      for _, d in ipairs(DIRS) do
        local cx, cy = out_conn(ext, w.x, w.y, d)
        if cx then
          any_conn = true
          local x0, y0, x1, y1 = rect_of(ew, eh, w.x, w.y, d)
          local ok, clash = true, false
          for ty = y0, y1 do
            for tx = x0, x1 do
              if S0[tkey(tx, ty)] or not free(tx, ty) then ok = false end
              if occ[tkey(tx, ty)] then clash = true end
            end
          end
          if ok then any_free = true end
          if ok and not clash then
            -- le raccord est hors de l'emprise (c'est la tuile voisine) et ne doit pas tomber sur une emprise voisine
            if not occ[tkey(cx, cy)] and (S0[tkey(cx, cy)] or free(cx, cy)) then
              opts[d] = { cx = cx, cy = cy, rect = { x0, y0, x1, y1 } }
              nopts = nopts + 1
            end
          end
        end
      end
      if not any_conn then
        out.skipped[#out.skipped + 1] = { x = w.x, y = w.y, cause = "extracteur sans raccord de sortie", code = "raccord" }
      elseif nopts == 0 then
        local cause, code = "emprise non libre (eau, falaise, batiment ou tuyau)", "emprise"
        if any_free then cause, code = "emprise chevauchee par le chevalet voisin ou raccord sans place", "voisin" end
        out.skipped[#out.skipped + 1] = { x = w.x, y = w.y, cause = cause, code = code }
      else
        -- l'emprise est réservée (celle de la première direction : les emprises d'une direction à l'autre ne diffèrent que si
        -- l'extracteur n'est pas carré ; chaque direction garde la sienne et la direction choisie réserve la sienne plus bas)
        local first
        for _, d in ipairs(DIRS) do if opts[d] then first = first or d end end
        local r = opts[first].rect
        for ty = r[2], r[4] do for tx = r[1], r[3] do occ[tkey(tx, ty)] = true end end
        acc[#acc + 1] = { x = w.x, y = w.y, opts = opts, fp = first }
      end
    end
  end
  if #acc == 0 then out.spent = spent return out end

  -----------------------------------------------------------------------------------------------
  -- 2. Collecteur : la ligne droite qui sert le plus de puits
  -----------------------------------------------------------------------------------------------
  local function pass(tx, ty) -- une tuile de tuyau : réseau existant, ou libre hors des emprises
    local k = tkey(tx, ty)
    if S0[k] then return true end
    if occ[k] then return false end
    return free(tx, ty)
  end
  local xmin, xmax, ymin, ymax = math.huge, -math.huge, math.huge, -math.huge
  for _, w in ipairs(acc) do
    local tx, ty = floor(w.x), floor(w.y)
    xmin, xmax, ymin, ymax = math.min(xmin, tx), math.max(xmax, tx), math.min(ymin, ty), math.max(ymax, ty)
  end
  -- candidats : (axe, ligne), la ligne du lot précédent d'abord, puis la médiane et ses voisines
  local function median(list)
    table.sort(list)
    return list[floor((#list + 1) / 2)]
  end
  local mx, my = {}, {}
  for _, w in ipairs(acc) do mx[#mx + 1] = floor(w.x); my[#my + 1] = floor(w.y) end
  local medx, medy = median(mx), median(my)
  local axes = { "h", "v" }
  if (ymax - ymin) > (xmax - xmin) then axes = { "v", "h" } end
  local cands = {}
  local seen = {}
  local function add_cand(axis, c)
    local key = axis .. ":" .. c
    if not seen[key] then seen[key] = true; cands[#cands + 1] = { axis = axis, c = c } end
  end
  if req.hint and (req.hint.axis == "h" or req.hint.axis == "v") then add_cand(req.hint.axis, req.hint.c) end
  for _, axis in ipairs(axes) do
    local med = axis == "h" and medy or medx
    add_cand(axis, med)
    for s = 1, Col.SHIFTS do add_cand(axis, med - s); add_cand(axis, med + s) end
  end
  -- étape A : intervalle libre de chaque ligne qui contient le plus de projections de puits
  local function interval(cand)
    local lo = (cand.axis == "h" and xmin or ymin) - Col.PAD
    local hi = (cand.axis == "h" and xmax or ymax) + Col.PAD
    local proj = {}
    for _, w in ipairs(acc) do proj[#proj + 1] = cand.axis == "h" and floor(w.x) or floor(w.y) end
    table.sort(proj)
    local best, run_a = nil, nil
    local function close(a, b)
      local n = 0
      for _, p in ipairs(proj) do if p >= a and p <= b then n = n + 1 end end
      if not best or n > best.n or (n == best.n and (b - a) > (best.b - best.a)) then best = { a = a, b = b, n = n } end
    end
    for t = lo, hi + 1 do
      local ok = false
      if t <= hi then
        if cand.axis == "h" then ok = pass(t, cand.c) else ok = pass(cand.c, t) end
      end
      if ok then run_a = run_a or t elseif run_a then close(run_a, t - 1); run_a = nil end
    end
    return best
  end
  local ranked = {}
  for i, cd in ipairs(cands) do
    local iv = interval(cd)
    if iv and iv.n > 0 then
      local hinted = (req.hint and cd.axis == req.hint.axis and cd.c == req.hint.c) and 1 or 0
      ranked[#ranked + 1] = { cand = cd, iv = iv, i = i, hinted = hinted }
    end
  end
  table.sort(ranked, function(a, b)
    if a.hinted ~= b.hinted then return a.hinted > b.hinted end
    if a.iv.n ~= b.iv.n then return a.iv.n > b.iv.n end
    return a.i < b.i
  end)

  -- Un ensemble de tuiles du réseau `S` (clé -> vrai) est aussi tenu en liste (Sl, ordre d'ajout) : les cibles d'un puits sont les
  -- Col.TARGETS tuiles du réseau les plus proches de son centre. Un tracé va du raccord à une cible par un segment droit, ou par
  -- deux segments (horizontal puis vertical, ou l'inverse) ; il s'arrête AVANT la cible. Coût par puits : quatre directions × cibles ×
  -- deux tracés × leur longueur, bornée par `lim` (aucune recherche en largeur).
  local function nearest(Sl, wx, wy)
    local best = {}
    for _, k in ipairs(Sl) do
      local x, y = untkey(k)
      local dd = abs(x + 0.5 - wx) + abs(y + 0.5 - wy)
      local n = #best
      if n < Col.TARGETS or dd < best[n].d or (dd == best[n].d and (y < best[n].y or (y == best[n].y and x < best[n].x))) then
        local item = { d = dd, x = x, y = y }
        local i = n + 1
        if n >= Col.TARGETS then best[n] = nil; i = n end
        best[i] = item
        while i > 1 do
          local u, v = best[i], best[i - 1]
          if u.d < v.d or (u.d == v.d and (u.y < v.y or (u.y == v.y and u.x < v.x))) then best[i], best[i - 1] = v, u; i = i - 1 else break end
        end
      end
    end
    return best
  end
  local function attach(w, S, Sl, lim)
    local best
    local function offer(len, kind, d, tiles)
      if not best or len < best.len or (len == best.len and best.kind == "L" and kind ~= "L") then
        best = { len = len, kind = kind, dir = d, tiles = tiles }
      end
    end
    local targets
    for _, d in ipairs(DIRS) do
      local o = w.opts[d]
      if o then
        local c0 = tkey(o.cx, o.cy)
        if S[c0] then
          offer(0, "direct", d, {})
        elseif pass(o.cx, o.cy) then
          targets = targets or nearest(Sl, w.x, w.y)
          for _, T in ipairs(targets) do
            local dx, dy = T.x - o.cx, T.y - o.cy
            if abs(dx) + abs(dy) <= lim then
              local sx, sy = dx > 0 and 1 or -1, dy > 0 and 1 or -1
              -- tracé 1 : horizontal d'abord (ligne du raccord), puis vertical (colonne de la cible) ; tracé 2 : l'inverse
              for shape = 1, ((dx == 0 or dy == 0) and 1 or 2) do
                local tiles, ok, neu = {}, true, 0
                local function walk(x, y)
                  local kk = tkey(x, y)
                  if not S[kk] then
                    if occ[kk] or not free(x, y) then return false end
                    neu = neu + 1
                  end
                  tiles[#tiles + 1] = { x, y }
                  return true
                end
                local x, y = o.cx, o.cy
                if shape == 1 then
                  for _ = 1, abs(dx) do if not walk(x, y) then ok = false break end x = x + sx end
                  if ok then for _ = 1, abs(dy) do if not walk(x, y) then ok = false break end y = y + sy end end
                else
                  for _ = 1, abs(dy) do if not walk(x, y) then ok = false break end y = y + sy end
                  if ok then for _ = 1, abs(dx) do if not walk(x, y) then ok = false break end x = x + sx end end
                end
                if ok then offer(neu, (dx == 0 or dy == 0) and "droit" or "L", d, tiles) end
              end
            end
          end
        end
      end
    end
    return best
  end

  -- étape B : les meilleures lignes sont jugées sur les puits qu'un tuyau DROIT (perpendiculaire) relie à la ligne : nombre de puits
  -- servis, puis longueur totale (calcul léger : un rayon par direction de raccord)
  local function straight_len(w, cd, iv)
    local best
    for _, d in ipairs(DIRS) do
      local o = w.opts[d]
      if o then
        local along, across = o.cx, o.cy
        if cd.axis == "v" then along, across = o.cy, o.cx end
        if along >= iv.a and along <= iv.b then
          local n = abs(cd.c - across)
          if n <= Col.MAX_BRANCH and (not best or n < best) then
            local step = cd.c > across and 1 or -1
            local ok = true
            for i = 0, n - 1 do
              local a, b = along, across + i * step
              local tx, ty = a, b
              if cd.axis == "v" then tx, ty = b, a end
              if not pass(tx, ty) then ok = false break end
            end
            if ok then best = n end
          end
        end
      end
    end
    return best
  end
  local S0list = sorted_keys(S0)
  local function line_set(cd, iv)
    local S, Sl = {}, {}
    for _, k in ipairs(S0list) do S[k] = true; Sl[#Sl + 1] = k end
    for t = iv.a, iv.b do
      local k = cd.axis == "h" and tkey(t, cd.c) or tkey(cd.c, t)
      if not S[k] then S[k] = true; Sl[#Sl + 1] = k end
    end
    return S, Sl
  end
  local choice, hinted_try
  for i = 1, math.min(Col.TOP, #ranked) do
    local r = ranked[i]
    local served, total = 0, 0
    for _, w in ipairs(acc) do
      local n = straight_len(w, r.cand, r.iv)
      if n then served, total = served + 1, total + n end
    end
    local score = { served, -total, -i }
    if r.hinted == 1 then hinted_try = { r = r, score = score } end
    if not choice or score[1] > choice.score[1] or (score[1] == choice.score[1] and (score[2] > choice.score[2]
        or (score[2] == choice.score[2] and score[3] > choice.score[3]))) then
      choice = { r = r, score = score }
    end
  end
  -- la ligne du lot précédent est gardée tant qu'elle sert au moins 80 % de ce que sert la meilleure (une seule épine pour tout le champ)
  if hinted_try and choice and hinted_try ~= choice and hinted_try.score[1] * 5 >= choice.score[1] * 4 and hinted_try.score[1] >= 2 then
    choice = hinted_try
  end
  -- une ligne qui ne sert qu'un puits n'est pas un collecteur : le raccord de ce puits rejoint le réseau tout seul
  if choice and choice.score[1] < 2 then choice = nil end

  -----------------------------------------------------------------------------------------------
  -- 3. Embranchements : le puits le plus proche du réseau d'abord ; le collecteur n'est posé que sur le tronçon servi
  -----------------------------------------------------------------------------------------------
  local tubes = {}
  local S, Sl
  local trunk
  if choice then
    local cd, iv = choice.r.cand, choice.r.iv
    S, Sl = line_set(cd, iv)
    trunk = { axis = cd.axis, c = cd.c, a = iv.a, b = iv.b }
  else
    S, Sl = {}, {}
    for _, k in ipairs(S0list) do S[k] = true; Sl[#Sl + 1] = k end
  end
  local function place_tiles(tiles)
    for _, t in ipairs(tiles) do
      local k = tkey(t[1], t[2])
      if not S[k] then tubes[k] = true; S[k] = true; Sl[#Sl + 1] = k end
    end
  end
  local placed = {}
  local function commit(w, at)
    local o = w.opts[at.dir]
    place_tiles(at.tiles)
    -- l'emprise de la direction choisie remplace celle réservée à l'étape 1 quand elles diffèrent (extracteur non carré)
    if at.dir ~= w.fp then
      local r0 = w.opts[w.fp].rect
      for ty = r0[2], r0[4] do for tx = r0[1], r0[3] do occ[tkey(tx, ty)] = nil end end
      for ty = o.rect[2], o.rect[4] do for tx = o.rect[1], o.rect[3] do occ[tkey(tx, ty)] = true end end
    end
    placed[#placed + 1] = { x = w.x, y = w.y, dir = at.dir, cx = o.cx, cy = o.cy, len = at.len, kind = at.kind }
  end
  local pending = {}
  for i, w in ipairs(acc) do pending[i] = w end

  -- ordre fixe : le puits le plus proche du réseau d'abord (les suivants s'accrochent à ses tuyaux), puis y, puis x ; les puits restés
  -- sans tracé au premier tour sont revus avec la longueur permise élargie, le réseau ayant grandi
  local function by_near()
    local keyed = {}
    for _, w in ipairs(pending) do
      local t = nearest(Sl, w.x, w.y)
      keyed[#keyed + 1] = { w = w, d = t[1] and t[1].d or 0 }
    end
    table.sort(keyed, function(a, b)
      if a.d ~= b.d then return a.d < b.d end
      if a.w.y ~= b.w.y then return a.w.y < b.w.y end
      return a.w.x < b.w.x
    end)
    return keyed
  end
  local function round(lim)
    local rest = {}
    for _, kw in ipairs(by_near()) do
      local at = attach(kw.w, S, Sl, lim)
      if at then commit(kw.w, at) else rest[#rest + 1] = kw.w end
    end
    local progress = #rest < #pending
    pending = rest
    return progress
  end
  -- ni réseau existant ni collecteur posable : le premier puits amorce le réseau par son raccord de sortie
  if next(S) == nil and #pending > 0 then
    local w = table.remove(pending, 1)
    local bd, bdist
    for _, d in ipairs(DIRS) do
      local o = w.opts[d]
      if o and pass(o.cx, o.cy) then
        local dd = d2(o.cx + 0.5, o.cy + 0.5)
        if not bdist or dd < bdist then bd, bdist = d, dd end
      end
    end
    if bd then
      local o = w.opts[bd]
      commit(w, { dir = bd, tiles = { { o.cx, o.cy } }, len = 1, kind = "amorce" })
    else
      out.skipped[#out.skipped + 1] = { x = w.x, y = w.y, code = "raccord", cause = "raccord de sortie sans place" }
    end
  end
  round(Col.MAX_BRANCH)
  while #pending > 0 and round(Col.MAX_LINK) do end
  for _, w in ipairs(pending) do
    out.skipped[#out.skipped + 1] = { x = w.x, y = w.y, code = "raccord",
      cause = string.format("aucun tuyau droit ni en L jusqu'au collecteur (%d tuiles au plus)", Col.MAX_LINK) }
  end
  out.extractors = placed
  table.sort(out.skipped, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)

  -- le collecteur ne garde que le tronçon utile : de la première à la dernière tuile atteinte par un embranchement ou la ligne vers les
  -- machines ; une ligne sans embranchement posé n'est pas posée du tout
  if trunk then
    local lo, hi
    local function touch(t) lo = lo and math.min(lo, t) or t; hi = hi and math.max(hi, t) or t end
    -- les tuyaux neufs adjacents à une tuile de la ligne, et les raccords posés sur elle, marquent les accroches
    for t = trunk.a, trunk.b do
      local k = trunk.axis == "h" and tkey(t, trunk.c) or tkey(trunk.c, t)
      local ax, ay = (trunk.axis == "h") and t or trunk.c, (trunk.axis == "h") and trunk.c or t
      for _, d in ipairs(DIRS) do
        local nk = tkey(ax + DV[d][1], ay + DV[d][2])
        if tubes[nk] then touch(t) end
      end
      for _, e in ipairs(placed) do
        if e.cx == ax and e.cy == ay then touch(t) end
      end
      if S0[k] then touch(t) end
    end
    if lo then
      -- la ligne principale part du bout le plus proche de la cible : le tronçon va jusqu'à ce bout si le réseau existant n'est pas là
      for t = lo, hi do
        local k = trunk.axis == "h" and tkey(t, trunk.c) or tkey(trunk.c, t)
        if not S0[k] then tubes[k] = true end
      end
      trunk.a, trunk.b = lo, hi
    else
      trunk = nil
    end
  end
  for k in pairs(tubes) do
    if S0[k] then tubes[k] = nil end
  end

  -----------------------------------------------------------------------------------------------
  -- 4. Composantes : ce qui ne touche pas le réseau existant doit être relié par l'appelant
  -----------------------------------------------------------------------------------------------
  local keys = sorted_keys(tubes)
  out.tubes = keys
  local reached = {}
  local stack = {}
  -- tuyaux neufs voisins d'une tuile du réseau existant, ou raccords posés sur lui
  for _, k in ipairs(keys) do
    local x, y = untkey(k)
    for _, d in ipairs(DIRS) do
      if S0[tkey(x + DV[d][1], y + DV[d][2])] then reached[k] = true end
    end
  end
  for _, k in ipairs(keys) do if reached[k] then stack[#stack + 1] = k end end
  local function flood(stk, mark)
    while #stk > 0 do
      local k = table.remove(stk)
      local x, y = untkey(k)
      for _, d in ipairs(DIRS) do
        local nk = tkey(x + DV[d][1], y + DV[d][2])
        if tubes[nk] and not mark[nk] then mark[nk] = true; stk[#stk + 1] = nk end
      end
    end
  end
  flood(stack, reached)
  for _, k in ipairs(keys) do
    if not reached[k] then
      local comp = { [k] = true }
      flood({ k }, comp)
      local n, bk, bd = 0, nil, nil
      for _, ck in ipairs(sorted_keys(comp)) do
        reached[ck] = true
        n = n + 1
        local x, y = untkey(ck)
        local dd = abs(x + 0.5 - tx0) + abs(y + 0.5 - ty0)
        if not bd or dd < bd then bk, bd = ck, dd end
      end
      local fx, fy = untkey(bk)
      out.comps[#out.comps + 1] = { from = { fx, fy }, n = n }
    end
  end
  out.joined = #out.comps == 0
  out.trunk = trunk
  out.spent = spent
  -- les extracteurs déjà au réseau par un raccord posé sur lui comptent comme reliés (longueur 0) : rien à ajouter ici
  return out
end

return Col
