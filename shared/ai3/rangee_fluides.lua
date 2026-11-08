--[[
  Lot PETROLE-RANGEE, étape 2 (directive du DC, 8/11 : « les bâtiments de chimie et de raffinage doivent se brancher en parallèle sur ces
  bus. Le pattern de construction doit être un module capable d'être dupliqué (copié-collé) de gauche à droite pour former une longue rangée
  extensible […] La duplication ne doit s'arrêter que devant un obstacle physique infranchissable »). RANGÉE DE MODULES sur bus : règle PURE
  (aucune API du jeu, aucun nom d'objet : tout se lit dans le relevé des prototypes et dans les entités du site) ; test :
  tests/rangee_fluides_test.lua, mutants compris.

  Le MODULE est la cellule du site de base (machines, bras, coffres, tuyaux d'un fluide INTERNE comme le gaz). Ses prises sur un fluide
  EXTERNE (le brut, l'eau : un tuyau relié au réseau du site de base ou à la pompe) sont les raccords de ses machines posés sur ce réseau.
  Une copie du module est la même cellule translatée de `dx` tuiles le long d'un axe (le pas). Chaque fluide externe a son BUS : une ligne
  droite parallèle à l'axe, à `h` tuiles de la rangée de prises (h = 0 : sur la rangée), reliée à chaque prise de chaque copie par un
  tuyau droit perpendiculaire (un « piquage » de h + 1 tuiles). Le bus prolonge celui du site de base : il part de sa prise.
    Rf.analyze(rel, ents, opts)  le module et ses prises depuis les entités du projet de base (roles : extracteur, pompe, machine, tuyau,
                                 bras-entree, bras-sortie, quai, sortie, poteau, liaison) ; ou nil et la cause.
    Rf.plan(mod, req)            pas, hauteur des bus, copies posables (arrêt devant la première tuile bloquée) ou nil et la cause.
    Rf.use(rel, cells, fluid)    consommation d'un module en unités de `fluid` par seconde (recette, durée, vitesse de la machine).
    Rf.count(supply, use, kmax)  nombre de modules que l'approvisionnement nourrit (au moins 1, au plus kmax).
  Règles de contact (jamais deux fluides qui se touchent) : deux tuyaux de fluides différents ne sont jamais voisins (4 voisins) ni sur la
  même tuile ; un tuyau ne se pose pas sur un raccord de machine qui n'attend pas son fluide (raccord inutilisé compris).
  Déterminisme : listes et clés triées, aucune trigonométrie, aucun temps mesuré.
]]

local Rf = {}

Rf.HMAX = 4          -- distance au plus d'un bus à la rangée de prises (tuiles)
Rf.DX_EXTRA = 10     -- pas essayés : de la largeur du module + 1 à la largeur + DX_EXTRA
Rf.KMAX = 8          -- modules au plus d'une rangée (le site de base compris)
Rf.BATCH = 3         -- copies au plus par chantier d'extension
Rf.CANDS = 4         -- (pas, bus) sans contact, un par pas, essayés contre le terrain : celui qui pose le plus de copies l'emporte

local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
local DIRS = { 0, 2, 4, 6 }
local floor, abs = math.floor, math.abs

local function tkey(x, y) return (x + 1048576) * 2097152 + (y + 1048576) end
local function untkey(k) return floor(k / 2097152) - 1048576, k % 2097152 - 1048576 end
Rf.tkey, Rf.untkey = tkey, untkey

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function rect_of(e, cx, cy, dir)
  local w, h = e.w or 1, e.h or 1
  if dir == 2 or dir == 6 then w, h = h, w end
  local x0, y0 = floor(cx - w / 2 + 0.01), floor(cy - h / 2 + 0.01)
  return x0, y0, x0 + w - 1, y0 + h - 1
end

local function conn_tile(cx, cy, p) return floor(cx + p[1] + 0.01), floor(cy + p[2] + 0.01) end

--- Direction (0 N, 2 E, 4 S, 6 O) dans laquelle un raccord sort de sa machine : l'axe où la position relative est la plus grande.
local function out_dir(p)
  if abs(p[2]) >= abs(p[1]) then return p[2] < 0 and 0 or 4 end
  return p[1] < 0 and 6 or 2
end

---------------------------------------------------------------------------------------------------
-- Analyse du site de base
---------------------------------------------------------------------------------------------------
local BODY_ROLES = { machine = true, ["bras-entree"] = true, ["bras-sortie"] = true, quai = true, sortie = true }

local function flood(tubes, starts)
  local net, stack = {}, {}
  for _, k in ipairs(starts) do if tubes[k] and not net[k] then net[k] = true; stack[#stack + 1] = k end end
  while #stack > 0 do
    local k = table.remove(stack)
    local x, y = untkey(k)
    for _, d in ipairs(DIRS) do
      local nk = tkey(x + DV[d][1], y + DV[d][2])
      if tubes[nk] and not net[nk] then net[nk] = true; stack[#stack + 1] = nk end
    end
  end
  return net
end

--- Raccords d'une entité posée : { { tx, ty, dir (sortie) } } pour toutes ses boîtes à fluide.
local function conns_of(rel, e)
  local info = rel.entities[e.name]
  local out = {}
  for _, b in ipairs((info and info.boxes) or {}) do
    for _, p in ipairs((b.conns and b.conns[e.dir or 0]) or {}) do
      local tx, ty = conn_tile(e.x, e.y, p)
      out[#out + 1] = { tx = tx, ty = ty, dir = out_dir(p) }
    end
  end
  return out
end

--- opts :
---          quais = { {x, y, item, flow} }, outs = { {x, y, at} } du projet de base }.
--- Rend mod ou (nil, cause).
function Rf.analyze(rel, ents, opts)
  opts = opts or {}
  local tubes, e_starts, p_starts = {}, {}, {}
  for _, e in ipairs(ents or {}) do
    if e.role == "tuyau" then
      tubes[tkey(floor(e.x), floor(e.y))] = true
    elseif e.role == "extracteur" then
      for _, c in ipairs(conns_of(rel, e)) do e_starts[#e_starts + 1] = tkey(c.tx, c.ty) end
    elseif e.role == "pompe" then
      for _, c in ipairs(conns_of(rel, e)) do p_starts[#p_starts + 1] = tkey(c.tx, c.ty) end
    end
  end
  table.sort(e_starts)
  table.sort(p_starts)
  local brut, eau = flood(tubes, e_starts), flood(tubes, p_starts)
  local label = {} -- tuile de tuyau -> étiquette
  for _, k in ipairs(sorted_keys(tubes)) do
    if brut[k] then label[k] = "brut" elseif eau[k] then label[k] = "eau" else label[k] = "interne" end
  end
  local mod = { ents = {}, tiles = {}, conns = {}, taps = {}, label0 = label, quais = {}, outs = {} }
  local tapsets = { brut = {}, eau = {} }
  local nmach = 0
  for _, e in ipairs(ents or {}) do
    local info = rel.entities[e.name]
    if BODY_ROLES[e.role] then
      mod.ents[#mod.ents + 1] = { name = e.name, x = e.x, y = e.y, dir = e.dir or 0, role = e.role, recipe = e.recipe }
      if e.role == "machine" then nmach = nmach + 1 end
      local x0, y0, x1, y1 = rect_of(info or { w = 1, h = 1 }, e.x, e.y, e.dir or 0)
      for ty = y0, y1 do for tx = x0, x1 do mod.tiles[#mod.tiles + 1] = { tx, ty, "m" } end end
      if e.role == "machine" then
        for _, c in ipairs(conns_of(rel, e)) do
          local k = tkey(c.tx, c.ty)
          local lab = label[k] or false
          mod.conns[#mod.conns + 1] = { c.tx, c.ty, lab }
          if lab == "brut" or lab == "eau" then
            tapsets[lab][#tapsets[lab] + 1] = { tx = c.tx, ty = c.ty, out = c.dir }
          end
        end
      end
    end
  end
  if nmach == 0 then return nil, "aucune machine dans le site de base" end
  -- tuyaux du fluide interne : ils font partie du module
  for _, k in ipairs(sorted_keys(label)) do
    if label[k] == "interne" then
      local x, y = untkey(k)
      mod.ents[#mod.ents + 1] = { name = nil, x = x + 0.5, y = y + 0.5, dir = 0, role = "tuyau", fluid = "interne", tile = { x, y } }
      mod.tiles[#mod.tiles + 1] = { x, y, "interne" }
    end
  end
  -- prises : un fluide externe a toutes ses prises sur une même rangée, sortant dans la même direction
  local axis
  for _, f in ipairs({ "brut", "eau" }) do
    local list = tapsets[f]
    if #list > 0 then
      table.sort(list, function(a, b) if a.ty ~= b.ty then return a.ty < b.ty end return a.tx < b.tx end)
      local d0 = list[1].out
      local horiz = d0 == 0 or d0 == 4 -- sortie nord/sud : la rangée de prises est horizontale (axe de la rangée de modules : x)
      for _, t in ipairs(list) do
        if t.out ~= d0 then return nil, "prises du fluide " .. f .. " dans des directions differentes" end
        if horiz and t.ty ~= list[1].ty then return nil, "prises du fluide " .. f .. " sur plusieurs rangees" end
        if not horiz and t.tx ~= list[1].tx then return nil, "prises du fluide " .. f .. " sur plusieurs colonnes" end
      end
      local a = horiz and "h" or "v"
      if axis and axis ~= a then return nil, "prises des fluides externes sur des axes differents" end
      axis = a
      mod.taps[f] = { tiles = list, out = d0 }
    end
  end
  if not axis then return nil, "aucune prise sur un fluide externe" end
  mod.axis = axis
  -- quais et sorties du projet de base : translatés avec le module
  for _, q in ipairs(opts.quais or {}) do mod.quais[#mod.quais + 1] = { x = q.x, y = q.y, item = q.item, flow = q.flow } end
  for _, o in ipairs(opts.outs or {}) do mod.outs[#mod.outs + 1] = { x = o.x, y = o.y, at = o.at } end
  -- emprise du module le long de l'axe
  local lo, hi = math.huge, -math.huge
  for _, t in ipairs(mod.tiles) do
    local u = axis == "h" and t[1] or t[2]
    lo, hi = math.min(lo, u), math.max(hi, u)
  end
  mod.lo, mod.hi = lo, hi
  return mod
end

---------------------------------------------------------------------------------------------------
-- Plan
---------------------------------------------------------------------------------------------------
local function shifted(mod, shift, x, y)
  if mod.axis == "h" then return x + shift, y end
  return x, y + shift
end

--- Tuiles d'une copie à `shift` tuiles de la base, plus les piquages et les bus de chaque fluide externe entre les copies `ks` (liste
--- d'indices de copie, avec leur décalage). Rend T (clé -> étiquette) et la liste des conflits (au plus 3, texte), ou nil si juste.
--- `hs` : hauteur du bus de chaque fluide ; `step` : pas signé (dx × sens).
local function world(mod, ks, step, hs)
  local T, bad = {}, {}
  local function put(x, y, lab, what)
    local k = tkey(x, y)
    local cur = T[k]
    if cur ~= nil and cur ~= lab then
      if #bad < 3 then bad[#bad + 1] = string.format("%s en (%d,%d) sur %s", what, x, y, cur) end
    end
    if cur == nil then T[k] = lab end
  end
  for _, kk in ipairs(ks) do
    local sh = kk * step
    for _, t in ipairs(mod.tiles) do
      local x, y = shifted(mod, sh, t[1], t[2])
      put(x, y, t[3], "module")
    end
  end
  -- piquages et bus : de la prise de la copie la plus basse à celle de la plus haute (plus, la prise de base fait partie du réseau existant)
  local kmin, kmax = math.huge, -math.huge
  for _, kk in ipairs(ks) do kmin, kmax = math.min(kmin, kk), math.max(kmax, kk) end
  for _, f in ipairs({ "brut", "eau" }) do
    local tp = mod.taps[f]
    if tp then
      local h = hs[f] or 0
      local ox, oy = DV[tp.out][1], DV[tp.out][2]
      local ulo, uhi = math.huge, -math.huge
      for _, kk in ipairs(ks) do
        local sh = kk * step
        for _, t in ipairs(tp.tiles) do
          for j = 0, h do
            local x, y = shifted(mod, sh, t.tx + ox * j, t.ty + oy * j)
            put(x, y, f, "piquage de " .. f)
            local u = mod.axis == "h" and x or y
            ulo, uhi = math.min(ulo, u), math.max(uhi, u)
          end
        end
      end
      -- le bus : la ligne du fond des piquages, de la première à la dernière prise
      local t0 = tp.tiles[1]
      local vline = (mod.axis == "h") and (t0.ty + oy * h) or (t0.tx + ox * h)
      for u = ulo, uhi do
        local x, y
        if mod.axis == "h" then x, y = u, vline else x, y = vline, u end
        put(x, y, f, "bus de " .. f)
      end
    end
  end
  return T, bad
end

--- Les règles de contact sur une carte T de tuiles étiquetées, avec les raccords `conns` ({ x, y, étiquette ou faux }) de chaque copie.
local function contacts(mod, T, ks, step, bad)
  for _, kk in ipairs(ks) do
    local sh = kk * step
    for _, c in ipairs(mod.conns) do
      local x, y = shifted(mod, sh, c[1], c[2])
      local lab = T[tkey(x, y)]
      if lab and lab ~= "m" and lab ~= c[3] then
        if #bad < 3 then bad[#bad + 1] = string.format("tuyau de %s sur un raccord qui n'attend pas ce fluide en (%d,%d)", lab, x, y) end
      end
    end
  end
  for _, k in ipairs(sorted_keys(T)) do
    local lab = T[k]
    if lab ~= "m" then
      local x, y = untkey(k)
      for _, d in ipairs(DIRS) do
        local g = T[tkey(x + DV[d][1], y + DV[d][2])]
        if g and g ~= "m" and g ~= lab then
          if #bad < 3 then bad[#bad + 1] = string.format("tuyaux de %s et de %s voisins en (%d,%d)", lab, g, x, y) end
        end
      end
    end
  end
  return bad
end

local function pair_ok(mod, dx, hs)
  local ks = { 0, 1, 2 }
  local T, bad = world(mod, ks, dx, hs)
  contacts(mod, T, ks, dx, bad)
  return #bad == 0, bad[1]
end

--- req : { blocked(tx, ty), L0 = { [clé] = étiquette } (tuyaux et raccords existants : base et copies déjà posées), conn0 = { [clé] = étiquette ou faux }
---          (raccords des machines existantes), kmax (copies à poser au plus), from (indice de la première copie, défaut 1),
---          fixed = { dx, sign, hs = { brut, eau } } (pas et bus d'un chantier précédent) ou nil }.
--- Rend { n, dx, sign, hs, ents, quais, outs, cause } ; n = 0 : aucune copie ne tient (cause).
function Rf.plan(mod, req)
  local from = req.from or 1
  local kmax = req.kmax or 1
  local W = mod.hi - mod.lo + 1
  local why
  local cands = {} -- (pas, hauteur des bus) qui évitent tout contact, dans l'ordre d'essai ; au plus Rf.CANDS essayés contre le terrain
  if req.fixed then
    cands[1] = { dx = req.fixed.dx, hs = req.fixed.hs }
  else
    local hlist = {}
    for _, f in ipairs({ "brut", "eau" }) do hlist[f] = mod.taps[f] and Rf.HMAX or 0 end
    -- un candidat par pas : les bus les plus bas d'abord
    for d = W + 1, W + Rf.DX_EXTRA do
      local found = false
      for hc = 0, hlist.brut do
        for hw = 0, hlist.eau do
          if not found then
            local h = { brut = hc, eau = hw }
            local ok, bad = pair_ok(mod, d, h)
            if ok then cands[#cands + 1] = { dx = d, hs = h }; found = true else why = why or bad end
          end
        end
      end
      if #cands >= Rf.CANDS then break end
    end
    if #cands == 0 then return { n = 0, ents = {}, quais = {}, outs = {}, tubes = {}, cause = "aucun pas ni bus n evite le contact : " .. tostring(why) } end
  end
  -- tuiles de module déjà posées : les copies avant `from` (le site de base est la copie 0)
  local function modworld(ks, step)
    local E = {}
    for _, kk in ipairs(ks) do
      for _, t in ipairs(mod.tiles) do
        local x, y = shifted(mod, kk * step, t[1], t[2])
        E[tkey(x, y)] = t[3]
      end
    end
    return E
  end
  local function upto(k)
    local l = {}
    for i = 0, k do l[#l + 1] = i end
    return l
  end
  -- copies posables, dans les deux sens (le sens qui en pose le plus l'emporte, + en cas d'égalité)
  local function run(dx, hs, sg)
    local step = dx * sg
    local E = modworld(upto(from - 1), step)
    local n, cause = 0, nil
    for k = from, from + kmax - 1 do
      local ks = upto(k)
      local T, bad = world(mod, ks, step, hs)
      contacts(mod, T, ks, step, bad)
      local fails = bad[1]
      if not fails then
        for _, key in ipairs(sorted_keys(T)) do
          local lab = T[key]
          if E[key] ~= lab and req.L0[key] ~= lab then
            local x, y = untkey(key)
            if req.blocked(x, y) then
              fails = string.format("%s : tuile bloquee en (%d,%d)", lab == "m" and "module" or ("tuyau de " .. lab), x, y)
              break
            end
            if lab ~= "m" then
              for _, d in ipairs(DIRS) do
                local g = req.L0[tkey(x + DV[d][1], y + DV[d][2])]
                if g and g ~= lab then fails = string.format("tuyau de %s contre un tuyau de %s en (%d,%d)", lab, g, x, y) break end
              end
              if fails then break end
              local c0 = req.conn0 and req.conn0[key]
              if c0 ~= nil and c0 ~= lab then
                fails = string.format("tuyau de %s sur un raccord existant en (%d,%d)", lab, x, y)
                break
              end
            end
          end
        end
      end
      if fails then cause = fails break end
      for _, t in ipairs(mod.tiles) do
        local x, y = shifted(mod, k * step, t[1], t[2])
        E[tkey(x, y)] = t[3]
      end
      n = n + 1
    end
    return n, cause
  end
  -- le candidat qui pose le plus de copies l'emporte (le premier à égalité), dans le sens + puis le sens -
  local dx, hs, sign, np, cp = cands[1].dx, cands[1].hs, 1, -1, nil
  if req.fixed then sign = req.fixed.sign end
  for _, c in ipairs(cands) do
    if req.fixed then
      local n1, c1 = run(c.dx, c.hs, sign)
      if n1 > np then dx, hs, np, cp = c.dx, c.hs, n1, c1 end
    else
      local n1, c1 = run(c.dx, c.hs, 1)
      if n1 > np then dx, hs, sign, np, cp = c.dx, c.hs, 1, n1, c1 end
      local n2, c2 = run(c.dx, c.hs, -1)
      if n2 > np then dx, hs, sign, np, cp = c.dx, c.hs, -1, n2, c2 end
    end
    if np >= kmax then break end
  end
  local step = dx * sign
  local out = { n = np, dx = dx, sign = sign, hs = hs, cause = cp, ents = {}, quais = {}, outs = {}, tubes = {} }
  if np == 0 then return out end
  for k = from, from + np - 1 do
    local sh = k * step
    for _, e in ipairs(mod.ents) do
      if e.role ~= "tuyau" then
        local x, y = shifted(mod, sh, e.x, e.y)
        out.ents[#out.ents + 1] = { name = e.name, x = x, y = y, dir = e.dir, role = e.role, recipe = e.recipe, copy = k }
      end
    end
    for _, q in ipairs(mod.quais) do
      local x, y = shifted(mod, sh, q.x, q.y)
      out.quais[#out.quais + 1] = { x = x, y = y, item = q.item, flow = q.flow }
    end
    for _, o in ipairs(mod.outs) do
      local x, y = shifted(mod, sh, o.x, o.y)
      out.outs[#out.outs + 1] = { x = x, y = y, at = o.at }
    end
  end
  -- tuyaux neufs : toutes les tuiles de tuyau (internes, piquages, bus) qui ne sont pas déjà posées
  local ks = upto(from + np - 1)
  local T = world(mod, ks, step, hs)
  local E0 = modworld(upto(from - 1), step)
  for _, key in ipairs(sorted_keys(T)) do
    local lab = T[key]
    if lab ~= "m" and E0[key] ~= lab and req.L0[key] ~= lab then
      local x, y = untkey(key)
      out.tubes[#out.tubes + 1] = { x = x, y = y, fluid = lab }
    end
  end
  return out
end

--- Étiquettes de tous les tuyaux d'un site (brut, eau, interne) et raccords de toutes ses machines : { L0, conn0 } pour Rf.plan.
--- `ents` : entités de tous les projets du site (base, extensions, copies déjà planifiées).
function Rf.world0(rel, ents)
  local tubes, e_starts, p_starts = {}, {}, {}
  for _, e in ipairs(ents or {}) do
    if e.role == "tuyau" then
      tubes[tkey(floor(e.x), floor(e.y))] = true
    elseif e.role == "extracteur" then
      for _, c in ipairs(conns_of(rel, e)) do e_starts[#e_starts + 1] = tkey(c.tx, c.ty) end
    elseif e.role == "pompe" then
      for _, c in ipairs(conns_of(rel, e)) do p_starts[#p_starts + 1] = tkey(c.tx, c.ty) end
    end
  end
  table.sort(e_starts)
  table.sort(p_starts)
  local brut, eau = flood(tubes, e_starts), flood(tubes, p_starts)
  local L0, conn0 = {}, {}
  for _, k in ipairs(sorted_keys(tubes)) do
    if brut[k] then L0[k] = "brut" elseif eau[k] then L0[k] = "eau" else L0[k] = "interne" end
  end
  for _, e in ipairs(ents or {}) do
    if e.role == "machine" or e.role == "extracteur" or e.role == "pompe" then
      for _, c in ipairs(conns_of(rel, e)) do conn0[tkey(c.tx, c.ty)] = L0[tkey(c.tx, c.ty)] or false end
    end
  end
  return L0, conn0
end

---------------------------------------------------------------------------------------------------
-- Demande
---------------------------------------------------------------------------------------------------
--- Consommation d'un module en unités/s de `fluid` : somme, sur les cellules `cells` ({ recipe, machine }), de la quantité du fluide dans les
--- ingrédients de la recette divisée par sa durée réelle (energy / vitesse de la machine). `rel.recipes[r] = { energy, ingredients = { {type,
--- name, amount} } }`, `rel.entities[m].speed`.
function Rf.use(rel, cells, fluid)
  local total = 0
  for _, c in ipairs(cells or {}) do
    local r = rel.recipes[c.recipe]
    local m = rel.entities[c.machine]
    if r and m then
      local speed = (m.speed and m.speed > 0) and m.speed or 1
      local dur = (r.energy and r.energy > 0) and r.energy / speed or 0
      if dur > 0 then
        for _, ing in ipairs(r.ingredients or {}) do
          if ing.name == fluid then total = total + (ing.amount or 0) / dur end
        end
      end
    end
  end
  return total
end

--- Nombre de modules que `supply` unités/s nourrissent à `use` unités/s chacun : au moins 1, au plus kmax.
function Rf.count(supply, use, kmax)
  kmax = kmax or Rf.KMAX
  if not (type(supply) == "number" and type(use) == "number") or use <= 0 or supply ~= supply then return 1 end
  local n = floor(supply / use + 1e-9)
  if n < 1 then n = 1 end
  if n > kmax then n = kmax end
  return n
end

return Rf
