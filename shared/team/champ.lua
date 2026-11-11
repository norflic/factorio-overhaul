--[[
  CHAMP (lot CHAMP, retour du DC du 2/11, points 1, 2, 3, 12, 13, 14) : plan d'un champ de minerai en RANGÉES RÉPÉTÉES.
  PUR : aucune API Factorio, aucun nom d'objet (tailles, portées et débits arrivent en DONNÉES : tests/iag_test.lua §8 bis).

  Le DC : « rangée poteaux électriques, rangée foreuses vers le bas, rangée convoyeur, rangée foreuses vers le haut, rangée
  poteaux électriques [...] et puis après on répète » ; « les convoyeurs qui passent en plein milieu du champ [...] ils pourraient
  juste retourner en arrière » ; « problème de minimisation, maximisation de l'espace, maximisation des foreuses électriques ».

  Géométrie (espace (u, v) : u le long des rangées = l'axe LONG du champ, v en travers). Une BANDE de pas 2 × côté + 2 :
    pr          rangée de poteaux (partagée avec la bande voisine), poteaux sur un TREILLIS fixe le long de u (pas ≤ fils,
                ≤ côté + 2 × portée : toute foreuse en touche un) : bâtir le champ bande par bande ne double aucun poteau
    pr+1..      foreuses tournées vers le tapis
    b = pr+c+1  tapis, qui sort par le bout du champ le plus proche du site de fonderie ; jamais à travers le champ
    ..pr+2c+1   foreuses tournées vers le tapis
  Les zones de minage (côté + 2 × portée) se recouvrent sur les rangées de poteaux et de tapis : tout le gisement est miné.
  Couloirs de passage : tous les CFG.corridor tuiles, deux colonnes sans foreuse (minées quand même) ; rangées de poteaux praticables.
  Débit : un tapis porte au plus voie / débit foreuses par côté (le plus lent des tapis donnés qui suffit) ; au-delà, la bande se
  coupe en deux groupes qui sortent chacun par SON bout ; le milieu attend un tapis plus rapide. Fonderie : shared/team/champ_fonderie.lua.

  Ch.plan(spec) -> plan, ou nil et raison. spec :
    ore      liste plate { x1, y1, x2, y2, ... } des tuiles de minerai (coins nord-ouest, entiers)
    blocked  { [Ch.key(x, y)] = true } : rien ne s'y pose (eau, falaise, bâtiment d'autrui)
    mine     { [Ch.key(x, y)] = true } : tuiles de NOS bâtiments du champ (paires à retirer, bandes déjà posées) : libres pour le plan
    foreign  { [Ch.key(x, y)] = true } ou nil : tuiles d'une AUTRE ressource que la foreuse sait miner (lot MELANGE, retour du DC du
             3/11 : « les minerais de charbon prennent la place des minerais de fer sur les convoyeurs ») : aucune foreuse dont la zone
             en touche une (la rangée se décale d'une tuile et réessaie ; shared/team/melange.lua)
    drill    { size, reach, rate }        côté, portée de minage au-delà du corps, objets/s
    pole     { reach, wire }              tuiles couvertes de part et d'autre (entier), portée des fils
    belts    { { lane = objets/s }, ... } du plus lent au plus rapide
    furnace  { size, rate, fuel } ou nil (coffres) ; inserter { rate } (mode coffres)
    target   { x, y }   site de fonderie (QG) : bout de sortie
    max_side foreuses par côté que le premier bout d'une bande prend (nil : la voie la plus rapide) ; le second bout prend le reste
    frame    cadre figé d'un plan précédent (plan.frame) : mêmes axe, phase, sortie, bords, décalages ; only = { [pr] = true } : ces
             bandes seulement (avec frame)
  plan = { axis, exit, frame, ents = { { kind, x, y, size, dir, band, group, pr, role, belt, module } }, bands, stats }
    kind : "foreuse" | "tapis" | "poteau" | "four" | "bras" | "coffre" ; dir 0 N, 2 E, 4 S, 6 O (foreuse : vers sa sortie ; tapis :
    sens de marche ; bras : côté où il PREND, convention de shared/team/modules.lua) ; role d'un coffre : "sortie" | "combustible".
  Déterminisme : listes triées, entiers, aucun `pairs` dans une décision, aucune trigonométrie.
]]

local Fd = require("shared.team.champ_fonderie")
local Co = require("shared.team.champ_colonne") -- lot FONDERIE : colonne nourrie par tapis, charbon compris
local Mel = require("shared.team.melange") -- lot MELANGE : zone d'une foreuse qui touche une autre ressource minable

local Ch = {}

Ch.CFG = {
  min_ore = 3,        -- tuiles de minerai au moins dans la zone d'une foreuse
  corridor = 32,      -- tuiles le long des rangées entre deux couloirs de passage (0 : aucun)
  gap = 2,            -- tuiles libres entre le bout du champ et la fonderie (passage)
  shift = 24,         -- tuiles dont la fonderie peut reculer pour trouver sa place (12 : bandes vides en jeu, la place prise par un autre chantier)
  both_ends = true,   -- une bande trop longue pour un tapis sort aussi par l'autre bout
  -- (lot FONDERIE, 3/11, le DC en 0.6.41 : « rien n'est automatique, rien n'est scalable ») une colonne d'un cadre neuf SANS voie de charbon
  -- (tracé sans chemin, pas de place pour le tronc) est REFUSÉE au lieu de retomber sur un coffre de tête à remplir ; le plan est refait
  -- sans elle (lot DECOUPLAGE : ses foreuses restent, tapis collecteur seul), au plus refuse_passes fois
  refuse_coffre = true,
  refuse_passes = 4,
  -- (lot FONDERIE, 3/11, décision du lead) le refus ne vaut que s'il garde au moins cette part des FOURS du champ (lot DECOUPLAGE : les
  -- foreuses restent toujours ; avant, la part des foreuses : le refus réduisait un champ d'azure de 41 foreuses à 4) ; sinon le cadre garde
  -- ses colonnes au coffre de tête (combustible)
  refuse_min = 0.5,
  -- (revue-fonderie, 3/11) un cadre neuf qui garde un coffre de tête ou refuse une colonne est aussi essayé dans l'autre ordre des côtés
  both_orders = true,
  eps = 1e-9,
}

function Ch.key(x, y) return (x + 50000) * 100000 + (y + 50000) end
Ch.BRIDGE_TRIES = 24 -- (lot FONDERIE) paires de poteaux essayées pour relier deux réseaux (bridge)
Ch.furnaces_for = Fd.furnaces_for

--- F555 : débit (objets/s) qu'un tapis de voie `lane` livre à la fonderie d'un groupe de n + s foreuses à `rate` : tout sur une voie
--- (colonne à combustible : l'autre voie porte le charbon), sinon une voie par côté. Les fours se dimensionnent sur ce débit.
function Ch.delivered(n, s, rate, lane, one_lane)
  if one_lane then return math.min((n + s) * rate, lane) end
  return math.min(n * rate, lane) + math.min(s * rate, lane)
end

--- Foreuses par côté qu'une voie porte.
function Ch.lane_drills(lane, rate)
  if not (lane and rate and rate > 0) then return 0 end
  return math.floor(lane / rate + Ch.CFG.eps)
end

local DIRS = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }

--- Lectures du champ dans le repère de l'axe : minerai, place libre, tuiles prises par le plan (clés en x, y).
local function context(spec, axis)
  local c = { taken = {}, blocked = spec.blocked or {}, mine = spec.mine or {}, ore = {}, list = {}, foreign = spec.foreign or {} }
  if axis == "x" then
    c.xy = function(u, v) return u, v end
    c.uv = function(x, y) return x, y end
  else
    c.xy = function(u, v) return v, u end
    c.uv = function(x, y) return y, x end
  end
  local o = spec.ore
  -- Lot PERF3 : le minerai aussi en clés du repère de l'axe (u, v) : is_ore sans changement de repère (même réponse : xy et uv sont
  -- deux bijections inverses l'une de l'autre ; c.ore n'est plus modifié après ce relevé)
  local ore_uv = {}
  for i = 1, #o - 1, 2 do
    local k = Ch.key(o[i], o[i + 1])
    if not c.ore[k] then
      c.ore[k] = true
      local u, v = c.uv(o[i], o[i + 1])
      c.list[#c.list + 1] = { u, v }
      ore_uv[Ch.key(u, v)] = true
    end
  end
  c.is_ore = function(u, v) return ore_uv[Ch.key(u, v)] == true end
  c.ore_uv = ore_uv
  -- lot MELANGE : une tuile d'une autre ressource minable (jamais une tuile du minerai visé : celui-ci gagne s'il y est aussi)
  c.has_foreign = next(c.foreign) ~= nil
  c.is_foreign = function(u, v) local x, y = c.xy(u, v); local k = Ch.key(x, y); return c.foreign[k] == true and not c.ore[k] end
  -- F500 (directive du DC du 10/11, 22 h) : toute ressource sous l'emprise d'une fonderie, le minerai visé comme celui d'un autre gisement
  c.is_resource = function(u, v)
    return c.is_ore(u, v) or c.is_foreign(u, v)
  end
  c.free = function(u, v)
    local x, y = c.xy(u, v)
    local k = Ch.key(x, y)
    return not c.taken[k] and (c.mine[k] or not c.blocked[k])
  end
  c.take = function(u, v) local x, y = c.xy(u, v); c.taken[Ch.key(x, y)] = true end
  c.dir = function(du, dv)
    local dx, dy = c.xy(du, dv)
    for _, d in ipairs({ 0, 2, 4, 6 }) do if DIRS[d][1] == dx and DIRS[d][2] == dy then return d end end
    return 0
  end
  return c
end

local function corridor_col(origin, u)
  local n = Ch.CFG.corridor
  if not n or n <= 0 then return false end
  local r = (u - origin) % n
  return r == n - 2 or r == n - 1
end

--- Foreuses d'une rangée (corps sur les rangées row..row+s-1), parcours glouton au décalage o. Rend { u0 } et le minerai miné.
local function row_drills(c, spec, row, umin, umax, origin, o, fm)
  local s, r = spec.drill.size, spec.drill.reach
  local out, mined = {}, 0
  local counted = -math.huge -- dernière colonne dont le minerai est compté dans `mined`
  -- Lot PERF3 : place libre lue UNE fois par tuile (la fenêtre glisse d'une tuile, et les décalages et les rangées d'une même passe de
  -- bands_for relisent les mêmes tuiles) : `fm`, mémoire tenue par bands_for, où rien n'est pris (c.taken inchangé pendant la passe) :
  -- mêmes réponses que c.free
  fm = fm or {}
  local cfree, key = c.free, Ch.key
  local c_free = function(u, v)
    local k = key(u, v)
    local x = fm[k]
    if x == nil then x = cfree(u, v) and true or false; fm[k] = x end
    return x
  end
  local c_is_ore = c.is_ore
  -- corps libre colonne par colonne (s tuiles de la rangée), gardé dans la même mémoire de passe
  fm.cols = fm.cols or {}
  local fcol = fm.cols[row]
  if not fcol then fcol = {}; fm.cols[row] = fcol end
  local function body_free(u)
    local x = fcol[u]
    if x == nil then
      x = true
      for v = row, row + s - 1 do if not c_free(u, v) then x = false break end end
      fcol[u] = x
    end
    return x
  end
  -- Lot PERF3 : minerai de la zone d'une foreuse compté par COLONNES (le minerai ne change pas pendant le plan : sommes gardées dans
  -- le contexte par rangée), au lieu de (s + 2r)² lectures par position : même nombre, entier exact
  c.ore_cols = c.ore_cols or {}
  local cols = c.ore_cols[row]
  if not cols then cols = {}; c.ore_cols[row] = cols end
  local v0, v1 = row - r, row + s - 1 + r
  local function col(u)
    local n = cols[u]
    if n == nil then
      n = 0
      for v = v0, v1 do if c_is_ore(u, v) then n = n + 1 end end
      cols[u] = n
    end
    return n
  end
  local a = umin - r - s + 1 + o
  while a <= umax + r do
    local ok = true
    for u = a, a + s - 1 do
      if ok and (corridor_col(origin, u) or not body_free(u)) then ok = false end
    end
    local n = 0
    -- lot MELANGE : zone qui touche une autre ressource minable -> refusée (la foreuse en déverserait sur le tapis de la bande)
    if ok and c.has_foreign then
      local x0, y0, x1, y1 = Mel.zone(a, row, s, r)
      if Mel.count(x0, y0, x1, y1, c.is_foreign) > 0 then ok = false end
    end
    if ok then
      for u = a - r, a + s - 1 + r do n = n + col(u) end
    end
    if ok and n >= Ch.CFG.min_ore then
      out[#out + 1] = a
      -- Lot PERF3 : minerai miné compté par colonnes ; les zones vont de gauche à droite (a croît), une colonne déjà comptée est
      -- à gauche de la dernière comptée (`counted`) : même total que l'ensemble des tuiles vues d'avant
      for u = math.max(a - r, counted + 1), a + s - 1 + r do mined = mined + col(u) end
      if a + s - 1 + r > counted then counted = a + s - 1 + r end
      a = a + s
    else
      a = a + 1
    end
  end
  return out, mined
end

--- Meilleur décalage d'une rangée (plus de minerai miné, puis moins de foreuses, puis le plus petit), ou le décalage figé `fixed`.
local function best_row(c, spec, row, umin, umax, origin, fixed, fm)
  local best, bm, bo
  for o = 0, spec.drill.size - 1 do
    if fixed == nil or fixed == o then
      local l, m = row_drills(c, spec, row, umin, umax, origin, o, fm)
      if not best or m > bm or (m == bm and #l < #best) then best, bm, bo = l, m, o end
    end
  end
  return best, bm, bo
end

--- Bandes d'une phase : { { pr, b, n = { u0 }, s = { u0 }, on, os } } et minerai miné (somme des rangées).
local function bands_for(c, spec, phase, box, origin, frame)
  local s = spec.drill.size
  local pitch = 2 * s + 2
  local bands, total = {}, 0
  local pr = box.v0 - phase
  local fm = {} -- lot PERF3 : place libre lue une fois par tuile pendant la passe (rien n'y est pris)
  while pr <= box.v1 do
    if not (frame and frame.only) or frame.only[pr] then
      local off = frame and frame.offsets and frame.offsets[tostring(pr)]
      local nl, nm, on = best_row(c, spec, pr + 1, box.u0, box.u1, origin, off and off[1], fm)
      local sl, sm, os_ = best_row(c, spec, pr + s + 2, box.u0, box.u1, origin, off and off[2], fm)
      if #nl + #sl > 0 then
        bands[#bands + 1] = { pr = pr, b = pr + s + 1, n = nl, s = sl, on = on, os = os_ }
        total = total + nm + sm
      end
    end
    pr = pr + pitch
  end
  return bands, total
end

--- Groupe d'une bande du côté `side` : foreuses prises depuis le bord tant que le tapis est libre jusqu'au bord et en deçà de la coupe
--- `limit`. Rend { n, s, cut } (cut : centre de la foreuse la plus loin).
--- F555 (DC, partie 0.7.3 : « 2 foreuses sur toute la largeur d'un gisement géant ») : le NOMBRE de foreuses ne dépend que du minerai
--- couvert (la boîte d'extraction) ; aucun plafond tiré de la fonderie (`side`, voie du charbon) : les fours se dimensionnent à part,
--- sur le débit que le tapis livre (Ch.delivered).
local function take_group(c, spec, band, side, edge, used, limit)
  local half = math.floor(spec.drill.size / 2)
  local all = {}
  for _, a in ipairs(band.n) do if not used[a .. "n"] then all[#all + 1] = { a = a, cu = a + half, side = "n" } end end
  for _, a in ipairs(band.s) do if not used[a .. "s"] then all[#all + 1] = { a = a, cu = a + half, side = "s" } end end
  table.sort(all, function(p, q)
    if p.cu ~= q.cu then if side > 0 then return p.cu > q.cu end return p.cu < q.cu end
    return p.side < q.side
  end)
  if #all == 0 then return nil end
  local function beyond(cu, lim) return (side > 0 and cu <= lim) or (side < 0 and cu >= lim) end
  local stop = limit
  local u, far = edge, all[#all].cu
  while (side > 0 and u >= far) or (side < 0 and u <= far) do
    if not c.free(u, band.b) then
      if not stop or not beyond(u, stop) then stop = u end
      break
    end
    u = u - side
  end
  local g, cnt = { n = {}, s = {} }, { n = 0, s = 0 }
  for i, it in ipairs(all) do
    if stop and beyond(it.cu, stop) then break end
    cnt[it.side] = cnt[it.side] + 1
    g[it.side][#g[it.side] + 1] = it.a
    g.cut = it.cu
  end
  if #g.n + #g.s == 0 or not g.cut then return nil end
  return g
end

--- Poteaux de la rangée `row` sur le treillis (u ≡ origin mod P) : un par foreuse non couverte, des relais où les fils manquent,
--- puis jusqu'aux colonnes de poteaux des fonderies `reach_to`. Rend la liste triée des u.
--- Pas du treillis des poteaux le long d'une rangée : au plus la portée des fils, au plus côté + 2 × portée (toute foreuse en touche un).
function Ch.lattice_step(spec)
  return math.max(1, math.min(math.floor(spec.pole.wire + Ch.CFG.eps), spec.drill.size + 2 * spec.pole.reach))
end

local function row_poles(c, spec, row, drills, origin, reach_to)
  local R, s = spec.pole.reach, spec.drill.size
  local P = Ch.lattice_step(spec)
  local function lattice_at_or_after(u) return u + ((origin - u) % P) end
  local set, list = {}, {}
  local function add(u) if not set[u] then set[u] = true; list[#list + 1] = u; c.take(u, row) end end
  local function try(lo, hi, prefer)
    if prefer and prefer >= lo and prefer <= hi and (set[prefer] or c.free(prefer, row)) then add(prefer) return prefer end
    for u = lo, hi do if set[u] then return u end end
    for u = lo, hi do if c.free(u, row) then add(u) return u end end
    return nil
  end
  table.sort(drills)
  for _, a in ipairs(drills) do
    local lo, hi = a - R, a + s - 1 + R
    local covered = false
    for u = lo, hi do if set[u] then covered = true end end
    if not covered then try(lo, hi, lattice_at_or_after(lo)) end
  end
  for _, t in ipairs(reach_to) do
    if #list > 0 then
      table.sort(list)
      local first, last = list[1], list[#list]
      local goal = t
      local from = (goal > last) and last or ((goal < first) and first or nil)
      if from then
        local dir = goal > from and 1 or -1
        local u = from
        local guard = 0
        while math.abs(goal - u) > R and guard < 400 do
          guard = guard + 1
          local want = u + dir * P
          if (dir > 0 and want > goal) or (dir < 0 and want < goal) then want = goal end
          local lo, hi = math.min(u + dir, want), math.max(u + dir, want)
          local got = try(lo, hi, want)
          if not got then break end
          u = got
        end
      end
    end
  end
  table.sort(list)
  -- relais : deux poteaux voisins trop loin l'un de l'autre
  local wire = math.floor(spec.pole.wire + Ch.CFG.eps)
  local i = 1
  while i < #list do
    if list[i + 1] - list[i] > wire then
      local got = try(list[i] + 1, list[i] + wire, lattice_at_or_after(list[i] + 1))
      if not got then break end
      table.sort(list)
    end
    i = i + 1
  end
  table.sort(list)
  return list
end

--- Relie les réseaux de poteaux séparés (eau, falaise, fonderie reculée) : relais en ligne droite, sur des tuiles libres, du réseau
--- du premier poteau vers le poteau le plus proche d'un autre réseau. `poles` : { { u, v } } (complété en place). Rend les relais.
local function bridge_0641(c, spec, poles)
  local wire = spec.pole.wire
  local w2 = wire * wire + Ch.CFG.eps
  local added = {}
  for _ = 1, 60 do
    local parent = {}
    for i = 1, #poles do parent[i] = i end
    local function root(i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
    local grid = {}
    local cell = math.max(1, math.ceil(wire))
    for i, p in ipairs(poles) do
      local k = Ch.key(math.floor(p[1] / cell), math.floor(p[2] / cell))
      grid[k] = grid[k] or {}
      grid[k][#grid[k] + 1] = i
    end
    for i, p in ipairs(poles) do
      local gx, gy = math.floor(p[1] / cell), math.floor(p[2] / cell)
      for dx = -1, 1 do
        for dy = -1, 1 do
          for _, j in ipairs(grid[Ch.key(gx + dx, gy + dy)] or {}) do
            local q = poles[j]
            if j > i and (p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 <= w2 then
              local a, b = root(i), root(j)
              if a ~= b then parent[a] = b end
            end
          end
        end
      end
    end
    -- Lot PERF3 : racine de chaque poteau calculée UNE fois (avant : root() dans la double boucle, N² appels), puis les mêmes paires
    -- dans le même ordre (i puis j croissants) : même paire retenue, à égalité comprise.
    local main = root(1)
    local ins, outs = {}, {}
    for i = 1, #poles do if root(i) == main then ins[#ins + 1] = i else outs[#outs + 1] = i end end
    local best, ba, bb
    for _, i in ipairs(ins) do
      local p = poles[i]
      local p1, p2 = p[1], p[2]
      for _, j in ipairs(outs) do
        local q = poles[j]
        local d2 = (p1 - q[1]) ^ 2 + (p2 - q[2]) ^ 2
        if not best or d2 < best then best, ba, bb = d2, i, j end
      end
    end
    if not best then return added end
    local a, b = poles[ba], poles[bb]
    local dist = math.sqrt(best)
    local n = math.ceil(dist / (wire - 0.5)) - 1
    local prev = a
    local ok = n >= 1
    for k = 1, n do
      local iu = math.floor(a[1] + (b[1] - a[1]) * k / (n + 1) + 0.5)
      local iv = math.floor(a[2] + (b[2] - a[2]) * k / (n + 1) + 0.5)
      local put
      for r = 0, 3 do
        for du = -r, r do
          for dv = -r, r do
            local u, v = iu + du, iv + dv
            if not put and math.max(math.abs(du), math.abs(dv)) == r and c.free(u, v)
              and (u - prev[1]) ^ 2 + (v - prev[2]) ^ 2 <= w2 then put = { u, v } end
          end
        end
      end
      if not put then ok = false break end
      c.take(put[1], put[2])
      poles[#poles + 1] = put
      added[#added + 1] = put
      prev = put
    end
    if not ok then return added end
  end
  return added
end

-- (lot FONDERIE) relais à plusieurs paires (Ch.BRIDGE_TRIES) pour la colonne à tapis ; le motif à coffres garde bridge_0641, à l'identique
local function bridge(c, spec, poles)
  local wire = spec.pole.wire
  local w2 = wire * wire + Ch.CFG.eps
  local added = {}
  for _ = 1, 60 do
    local parent = {}
    for i = 1, #poles do parent[i] = i end
    local function root(i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
    local grid = {}
    local cell = math.max(1, math.ceil(wire))
    for i, p in ipairs(poles) do
      local k = Ch.key(math.floor(p[1] / cell), math.floor(p[2] / cell))
      grid[k] = grid[k] or {}
      grid[k][#grid[k] + 1] = i
    end
    for i, p in ipairs(poles) do
      local gx, gy = math.floor(p[1] / cell), math.floor(p[2] / cell)
      for dx = -1, 1 do
        for dy = -1, 1 do
          for _, j in ipairs(grid[Ch.key(gx + dx, gy + dy)] or {}) do
            local q = poles[j]
            if j > i and (p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 <= w2 then
              local a, b = root(i), root(j)
              if a ~= b then parent[a] = b end
            end
          end
        end
      end
    end
    local main = root(1)
    -- (lot FONDERIE) les Ch.BRIDGE_TRIES paires (réseau principal, autre réseau) les plus proches, essayées dans l'ordre : avant, seule la plus
    -- proche l'était, et un échec arrêtait tout (deux rangées de poteaux d'une ligne de charbon à 8 tuiles : leur milieu est sur le tapis et
    -- les foreuses, aucun relais possible là, mais au bout de la ligne oui)
    -- Lot PERF3 : racines calculées une fois, mêmes paires dans le même ordre (voir bridge_0641)
    local ins, outs = {}, {}
    for i = 1, #poles do if root(i) == main then ins[#ins + 1] = i else outs[#outs + 1] = i end end
    local cand = {}
    local tries = Ch.BRIDGE_TRIES
    for _, i in ipairs(ins) do
      local p = poles[i]
      local p1, p2 = p[1], p[2]
      for _, j in ipairs(outs) do
        local q = poles[j]
        local d2 = (p1 - q[1]) ^ 2 + (p2 - q[2]) ^ 2
        if #cand < tries or d2 < cand[#cand][1] then
          local pos = #cand + 1
          while pos > 1 and cand[pos - 1][1] > d2 do pos = pos - 1 end
          table.insert(cand, pos, { d2, i, j })
          if #cand > tries then cand[#cand] = nil end
        end
      end
    end
    if #cand == 0 then return added end
    local done = false
    for _, cd in ipairs(cand) do
      if not done then
        local a, b = poles[cd[2]], poles[cd[3]]
        local n = math.ceil(math.sqrt(cd[1]) / (wire - 0.5)) - 1
        local prev, ok, chain, tmp = a, n >= 1, {}, {}
        for k = 1, n do
          if ok then
            local iu = math.floor(a[1] + (b[1] - a[1]) * k / (n + 1) + 0.5)
            local iv = math.floor(a[2] + (b[2] - a[2]) * k / (n + 1) + 0.5)
            local put
            for r = 0, 3 do
              for du = -r, r do
                for dv = -r, r do
                  local u, v = iu + du, iv + dv
                  if not put and math.max(math.abs(du), math.abs(dv)) == r and c.free(u, v) and not tmp[Ch.key(u, v)]
                    and (u - prev[1]) ^ 2 + (v - prev[2]) ^ 2 <= w2 then put = { u, v } end
                end
              end
            end
            if not put then ok = false else chain[#chain + 1] = put; tmp[Ch.key(put[1], put[2])] = true; prev = put end
          end
        end
        if ok and (prev[1] - b[1]) ^ 2 + (prev[2] - b[2]) ^ 2 <= w2 then
          for _, put in ipairs(chain) do
            c.take(put[1], put[2])
            poles[#poles + 1] = put
            added[#added + 1] = put
          end
          done = true
        end
      end
    end
    if not done then return added end
  end
  return added
end

local function long_axis(spec)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  local o = spec.ore
  for i = 1, #o - 1, 2 do
    x0, x1 = math.min(x0, o[i]), math.max(x1, o[i])
    y0, y1 = math.min(y0, o[i + 1]), math.max(y1, o[i + 1])
  end
  return (y1 - y0 > x1 - x0) and "y" or "x"
end

local function plan_once(spec)
  if not (spec and spec.ore and #spec.ore >= 2 and spec.drill and spec.pole and spec.belts and #spec.belts > 0) then return nil, "donnees" end
  local d, F = spec.drill, spec.frame
  -- lot FONDERIE : colonne à tapis (shared/team/champ_colonne.lua) pour un cadre neuf qui la demande ; un cadre figé garde SON motif
  -- (un cadre d'une sauvegarde 0.6.38 n'a pas `design` : ses bandes gardent la fonderie à coffres, rien n'est migré)
  local colonne = spec.furnace ~= nil and ((F and F.design) or (not F and spec.design)) == "colonne"
  if spec.furnace and spec.furnace.size > d.size - 1 then return nil, "four trop grand pour la bande" end
  if colonne then
    if spec.furnace.size < 2 then return nil, "four trop petit pour les poteaux de la colonne" end
  else
    if spec.furnace and spec.furnace.fuel and spec.furnace.size < 2 then return nil, "four trop petit pour son coffre de combustible" end
    if spec.furnace and 2 * spec.furnace.size + 3 > spec.pole.wire + Ch.CFG.eps then return nil, "portee des poteaux" end
  end
  local axis = (F and F.axis) or long_axis(spec)
  local c = context(spec, axis)
  local box = { u0 = math.huge, v0 = math.huge, u1 = -math.huge, v1 = -math.huge }
  for _, t in ipairs(c.list) do
    box.u0, box.u1 = math.min(box.u0, t[1]), math.max(box.u1, t[1])
    box.v0, box.v1 = math.min(box.v0, t[2]), math.max(box.v1, t[2])
  end
  local origin = (F and F.origin) or box.u0
  local pitch = 2 * d.size + 2
  local bands, phase
  if F and F.phase then
    phase = F.phase
    box.v0 = F.v0 or box.v0
    bands = bands_for(c, spec, phase, box, origin, F)
  else
    local bt
    for ph = 0, pitch - 1 do
      local bs, total = bands_for(c, spec, ph, box, origin, nil)
      if not bands or total > bt then bands, bt, phase = bs, total, ph end
    end
  end
  for _, bd in ipairs(bands) do
    for _, a in ipairs(bd.n) do for u = a, a + d.size - 1 do for v = bd.pr + 1, bd.pr + d.size do c.take(u, v) end end end
    for _, a in ipairs(bd.s) do for u = a, a + d.size - 1 do for v = bd.b + 1, bd.b + d.size do c.take(u, v) end end end
  end
  local umin, umax = box.u0, box.u1
  for _, bd in ipairs(bands) do
    for _, l in ipairs({ bd.n, bd.s }) do for _, a in ipairs(l) do umin = math.min(umin, a); umax = math.max(umax, a + d.size - 1) end end
  end
  if F and F.umin then umin, umax = F.umin, F.umax end
  local exit = (F and F.exit) or 1
  if not (F and F.exit) and spec.target then
    local tu = c.uv(spec.target.x, spec.target.y)
    if math.abs(tu - umin) < math.abs(tu - umax) then exit = -1 end
  end
  local lane = spec.belts[#spec.belts].lane
  local cap = Ch.lane_drills(lane, d.rate)
  if spec.max_side then cap = math.min(cap, spec.max_side) end
  if cap < 1 then return nil, "tapis trop lent pour une foreuse" end
  -- lot FONDERIE : avec du combustible, la tête charge tout le minerai sur UNE voie (l'autre porte le charbon)
  local fuelled = colonne and spec.furnace.fuel
  -- F555 : foreuses que le PREMIER bout d'une bande prend (partage entre les deux bouts, jamais un plafond de la bande)
  local first_k = fuelled and math.min(2 * cap, Ch.lane_drills(lane, d.rate)) or 2 * cap
  local ents, out_bands = {}, {}
  local capped, flow_all, cap_all, no_smelter = 0, 0, 0, 0
  local no_smelter_at -- 9/11 : première tuile prise qui empêche la colonne de fonderie d'un groupe (diagnostic du refus « sans place de fonderie »)
  local function emit(kind, u, v, size, du, dv, bi, gi, pr, role, belt, module)
    local x, y = c.xy(u, v)
    local x2, y2 = c.xy(u + size - 1, v + size - 1)
    ents[#ents + 1] = { kind = kind, x = math.min(x, x2) + size / 2, y = math.min(y, y2) + size / 2, size = size,
      dir = (du ~= 0 or dv ~= 0) and c.dir(du, dv) or 0, band = bi, group = gi, pr = pr, role = role, belt = belt, module = module }
  end
  -- (lot FONDERIE) une entité de la colonne ou du réseau de charbon : rectangle w × h (répartiteur), sens de souterrain
  local function emit_e(e, bi, gi, pr, belt)
    local w, h = e.w or e.size, e.h or e.size
    local xa, ya = c.xy(e.u, e.v)
    local xb, yb = c.xy(e.u + w - 1, e.v + h - 1)
    local x0, x1, y0, y1 = math.min(xa, xb), math.max(xa, xb), math.min(ya, yb), math.max(ya, yb)
    local o = { kind = e.kind, x = (x0 + x1 + 1) / 2, y = (y0 + y1 + 1) / 2, size = e.size,
      dir = (e.du ~= 0 or e.dv ~= 0) and c.dir(e.du, e.dv) or 0, band = bi, group = gi, pr = pr, role = e.role, belt = belt, ug = e.ug }
    if e.w then o.w, o.h = x1 - x0 + 1, y1 - y0 + 1 end
    ents[#ents + 1] = o
  end
  local offsets = {}
  local pending = {} -- (lot FONDERIE) colonnes posées, émises après le choix de leur charbon
  for bi, bd in ipairs(bands) do
    offsets[tostring(bd.pr)] = { bd.on, bd.os }
    local used, groups = {}, {}
    -- F555 : le premier bout prend `first_k` foreuses (les plus près de son bord), le second bout TOUT le reste, sans plafond ; premier
    -- groupe sans fonderie : le second prend toute la bande
    local cus = {}
    for _, l in ipairs({ bd.n, bd.s }) do for _, a in ipairs(l) do cus[#cus + 1] = a + math.floor(d.size / 2) end end
    table.sort(cus)
    local k = first_k
    local limit = nil
    if Ch.CFG.both_ends and #cus > k then
      -- les foreuses que le second bout ne joint pas (son tapis barré avant elles) restent au premier
      local far = exit > 0 and umin or umax
      local u2 = far
      while u2 >= umin and u2 <= umax and c.free(u2, bd.b) do u2 = u2 + exit end
      if exit > 0 then limit = math.min(cus[#cus - k], u2 - 1) else limit = math.max(cus[k + 1], u2 + 1) end
    end
    for _, side in ipairs(Ch.CFG.both_ends and { exit, -exit } or { exit }) do
      local edge = side > 0 and umax or umin
      local g = take_group(c, spec, bd, side, edge, used, limit)
      limit = nil
      if g then
        local flow = Ch.delivered(#g.n, #g.s, d.rate, lane, fuelled)
        local list, len, s_edge, count, info
        if colonne then
          local fixed = F and F.cols and F.cols[tostring(bd.pr)] and F.cols[tostring(bd.pr)][tostring(side)]
          local refused = (fixed and fixed.mode == "refusee") or (spec.refuse and spec.refuse[tostring(bd.pr) .. ":" .. tostring(side)])
          if refused then
            list = nil -- (lot FONDERIE) colonne refusée : pas de voie de charbon
          elseif not (F and F.cols) or fixed then
            local mode = fuelled and ((fixed and fixed.mode) or "voie") or nil
            list, len, s_edge, count, info = Co.place(spec, bd.b, side, edge, Fd.count(spec, flow), Ch.CFG.gap, Ch.CFG.shift, c.free,
              c.is_resource, mode, fixed)
            if not list and not no_smelter_at then
              -- diagnostic : la 1re tuile non libre le long du tapis puis dans la colonne, à la place du cadre figé ou à la 1re place essayée
              local s0 = fixed and fixed.s_edge or (edge + side * (Ch.CFG.gap + 1))
              local pu, pv
              for u = edge + side, s0 - side, side do if not pu and not c.free(u, bd.b) then pu, pv = u, bd.b end end
              if not pu then
                local lay = Co.layout(spec, bd.b, side, s0, fixed and fixed.count or Fd.count(spec, flow), mode)
                for _, e in ipairs(lay or {}) do
                  for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do if not pu and not c.free(u, v) then pu, pv = u, v end end end
                end
              end
              if pu then
                local px, py = c.xy(pu, pv)
                no_smelter_at = { x = px, y = py, fixed = fixed ~= nil, band = bd.pr, side = side }
              end
            end
          end
        else
          list, len, s_edge, count = Fd.place(spec, bd.b, side, edge, flow, Ch.CFG.gap, Ch.CFG.shift, c.free, c.is_resource)
        end
        -- lot DECOUPLAGE (directive du DC du 11/11) : une foreuse ne dépend QUE du minerai. Un groupe sans place de fonderie au bout de
        -- sa bande garde ses foreuses et son tapis collecteur jusqu'au bord du champ (g.bare : aucune fonderie dans ce plan, la fonderie se
        -- pose ailleurs sur le sol neutre, au bout du tapis) ; avant, ses foreuses étaient retirées du plan (émeraude fer : 37 sur 42).
        for _, a in ipairs(g.n) do used[a .. "n"] = true end
        for _, a in ipairs(g.s) do used[a .. "s"] = true end
        if list then
          for _, e in ipairs(list) do for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do c.take(u, v) end end end
          g.side, g.flow, g.s_edge, g.len, g.count, g.list, g.info = side, flow, s_edge, len, count, list, info
        else
          no_smelter = no_smelter + 1
          g.side, g.flow, g.s_edge, g.len, g.count, g.list, g.bare = side, flow, edge + side * (colonne and 2 or 1), 1, 0, {}, true
        end
        g.belt = #spec.belts
        local need_lane = fuelled and (#g.n + #g.s) or math.max(#g.n, #g.s)
        for i, bt in ipairs(spec.belts) do
          if Ch.lane_drills(bt.lane, d.rate) >= need_lane then g.belt = i break end
        end
        groups[#groups + 1] = g
        limit = g.cut
      end
    end
    local bo = { pr = bd.pr, b = bd.b, groups = {} }
    for _, l in ipairs({ { bd.n, "n" }, { bd.s, "s" } }) do
      for _, a in ipairs(l[1]) do if not used[a .. l[2]] then capped = capped + 1 end end
    end
    for gi, g in ipairs(groups) do
      for _, a in ipairs(g.n) do emit("foreuse", a, bd.pr + 1, d.size, 0, 1, bi, gi, bd.pr) end
      for _, a in ipairs(g.s) do emit("foreuse", a, bd.b + 1, d.size, 0, -1, bi, gi, bd.pr) end
      -- tapis de la bande : jusqu'au bout de la fonderie (motif à coffres), jusqu'à la tête de la colonne (lot FONDERIE)
      local s_end = colonne and (g.s_edge - g.side) or (g.s_edge + g.side * (g.len - 1))
      local nb = 0
      for u = g.cut, s_end, g.side do
        c.take(u, bd.b)
        emit("tapis", u, bd.b, 1, g.side, 0, bi, gi, bd.pr, colonne and "bande" or nil, g.belt)
        nb = nb + 1
      end
      if g.bare then
        -- (lot DECOUPLAGE) tapis collecteur seul : aucune fonderie émise ; la tuile devant sa sortie reste libre (rien n'y passe, le
        -- minerai ne tombe sur aucun autre tapis : l'entrée de la fonderie posée ailleurs)
        c.take(s_end + g.side, bd.b)
      elseif colonne then
        pending[#pending + 1] = { bi = bi, gi = gi, pr = bd.pr, b = bd.b, g = g }
      else
        for _, e in ipairs(g.list) do emit(e.kind, e.u, e.v, e.size, e.du, e.dv, bi, gi, bd.pr, e.role, nil, e.module) end
      end
      local capa = Fd.capacity(spec, g.count)
      flow_all, cap_all = flow_all + g.flow, cap_all + capa
      bo.groups[#bo.groups + 1] = { side = g.side, drills = #g.n + #g.s, per_side = math.max(#g.n, #g.s), flow = g.flow, belt = g.belt,
        count = g.count, capacity = capa, belt_tiles = nb, s_edge = g.s_edge, len = g.len, cut = g.cut,
        pole_u = g.bare and s_end or (g.s_edge + g.side * (colonne and g.info.head_pole or Fd.pole_col(spec))),
        pole_u2 = colonne and (g.bare and s_end or g.s_edge) or nil, bare = g.bare } -- (lot FONDERIE) poteau de liaison de tête, rejoint par la rangée pr + pas
    end
    out_bands[#out_bands + 1] = bo
  end
  -- lot FONDERIE : charbon des colonnes, un réseau par côté du champ (cadre neuf : calculé ; bande seule : rejoué du cadre)
  local cols_frame, coal_frame, coal_stats = nil, nil, {}
  local fallback = nil -- (lot FONDERIE) colonnes d'un cadre neuf retombées sur le coffre de tête : { pr, side, why }
  if colonne then
    cols_frame, coal_frame = {}, {}
    local nets = {}
    if fuelled and not F then
      local zone = { u0 = math.huge, u1 = -math.huge, v0 = math.huge, v1 = -math.huge }
      local function grow(u, v) zone.u0, zone.u1 = math.min(zone.u0, u), math.max(zone.u1, u); zone.v0, zone.v1 = math.min(zone.v0, v), math.max(zone.v1, v) end
      grow(umin, box.v0 - pitch); grow(umax, box.v1 + pitch)
      for _, it in ipairs(pending) do
        grow(it.g.s_edge, it.b); grow(it.g.s_edge + it.g.side * it.g.info.far, it.b)
      end
      local coal_set, coal_list = {}, {}
      local co = spec.coal
      if co and co.tiles then
        for i = 1, #co.tiles - 1, 2 do
          local u, v = c.uv(co.tiles[i], co.tiles[i + 1])
          local k = Co.tk(u, v)
          if not coal_set[k] then coal_set[k] = true; coal_list[#coal_list + 1] = { u, v } end
        end
      end
      local lg = spec.logistics or {}
      local ugs = {}
      for _, k in ipairs(spec.ug_tiles or {}) do local u, v = c.uv(k[1], k[2]); ugs[Co.tk(u, v)] = true end
      -- (revue-fonderie, 3/11) ordre des côtés : le premier réseau prend ses tuiles, le second ne croise son tracé qu'en souterrain ;
      -- spec.coal_first (posé par Ch.plan) fait passer l'autre côté d'abord
      local first = spec.coal_first or exit
      for _, side in ipairs({ first, -first }) do
        local cols = {}
        for _, it in ipairs(pending) do
          if it.g.side == side then
            cols[#cols + 1] = { key = tostring(it.pr), b = it.b, s_edge = it.g.s_edge, far = it.g.info.far, need = it.g.info.need }
          end
        end
        if #cols > 0 then
          local env = {
            free = c.free, coal = { tiles = coal_list, is_coal = function(u, v) return coal_set[Co.tk(u, v)] == true end, rate = co and co.rate,
              -- lot MELANGE : tuiles d'une autre ressource minable autour du charbon (le minerai du champ compris)
              is_foreign = co and co.foreign and function(u, v)
                if coal_set[Co.tk(u, v)] then return false end
                local x, y = c.xy(u, v)
                return co.foreign[Ch.key(x, y)] == true
              end or nil },
            forbid = function(u, v) return u >= zone.u0 - 1 and u <= zone.u1 + 1 and v >= zone.v0 - 1 and v <= zone.v1 + 1 end,
            -- (banc-2, 3/11) pas de répartiteur sur le tronc même débloqué : la cascade 50/50 n'a pas de plafond par colonne, les dernières
            -- attendent que les tampons d'amont se remplissent (mesuré : 12, 6, 4 et 4 fours garnis le long du tronc) ; le bras de
            -- dérivation, lui, borne la prise de chaque colonne. Les souterrains restent (passer sous un obstacle).
            drill = d, pole = spec.pole, ug = lg.underground, split = false, ugs = ugs, box = zone,
            inserter_rate = spec.inserter and spec.inserter.rate,
            soft = spec.soft and function(u, v) local x, y = c.xy(u, v); return spec.soft[Ch.key(x, y)] == true end or nil,
            lane_drills = co and co.rate and Ch.lane_drills(spec.belts[1].lane, co.rate) or nil,
            bridge = function(poles, free)
              local extra = {}
              local cc = { free = function(u, v) return not extra[Co.tk(u, v)] and free(u, v) end, take = function(u, v) extra[Co.tk(u, v)] = true end }
              return bridge(cc, spec, poles)
            end,
          }
          nets[side] = Co.network(cols, side, env)
          local nt = nets[side]
          -- le réseau prend ses tuiles (poteaux des rangées et relais du champ ne s'y posent pas)
          for _, e in ipairs(nt.ents) do
            for u = e.u, e.u + (e.w or e.size) - 1 do for v = e.v, e.v + (e.h or e.size) - 1 do c.take(u, v) end end
          end
          local last_key
          for _, cl in ipairs(cols) do if cl.last then last_key = cl.key end end
          local why = nt.why
          if nt.dropped and #nt.dropped > 0 then why = (why and (why .. " ; ") or "") .. table.concat(nt.dropped, " ; ") end
          coal_frame[tostring(side)] = { uT = nt.uT, dv = nt.dv, split = nt.split, last = last_key, ents = nt.ents, why = why,
            drills = nt.drills, undergrounds = nt.undergrounds }
        end
      end
    elseif F and F.coal then
      for _, side in ipairs({ exit, -exit }) do
        local cf = F.coal[tostring(side)]
        if cf then nets[side] = { uT = cf.uT, dv = cf.dv, split = cf.split, ents = cf.ents or {}, last = cf.last, why = cf.why } end
      end
    end
    local shared_done = {}
    fallback = {}
    for _, it in ipairs(pending) do
      local g = it.g
      local key = tostring(it.pr)
      local nt = nets[g.side]
      local mode = g.info.mode
      if mode == "voie" then
        if F and F.cols then
          mode = F.cols[key][tostring(g.side)].mode
        else
          mode = (nt and nt.modes and nt.modes[key]) or "coffre"
        end
      end
      if mode == "coffre" and g.info.mode == "voie" and not F then
        local cf = coal_frame[tostring(g.side)]
        fallback[#fallback + 1] = { pr = it.pr, side = g.side, why = (cf and cf.why) or "pas de reseau du charbon" }
      end
      if mode == "coffre" and g.info.mode == "voie" then
        -- repli : le coffre de tête (ses tuiles sont dans celles de la voie, déjà prises)
        local list, len, info = Co.layout(spec, it.b, g.side, g.s_edge, g.count, "coffre")
        g.list, g.info = list, info
        g.len = math.min(g.len, len)
      end
      for _, e in ipairs(g.list) do
        emit_e(e, it.bi, it.gi, it.pr, e.kind == "tapis" and (e.role == "charbon" and 1 or g.belt) or nil)
        -- lot FONDERIE-BLOC : le coffre de tête porte le charbon/s que sa colonne brûle (son quai a un débit : la liaison, le piquage et
        -- l'alimentation de quai le voient ; avant, 0 et « ne_se_paie_pas »)
        if e.kind == "coffre" and e.role == "combustible" then ents[#ents].need = g.info.need end
      end
      if mode == "voie" and nt and nt.uT then
        local cf = (F and F.cols) and nt or coal_frame[tostring(g.side)]
        local col = { b = it.b, s_edge = g.s_edge, far = g.info.far, last = (cf and cf.last) == key }
        for _, e in ipairs(Co.branch(col, nt, g.side, spec.pole.wire)) do
          for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do c.take(u, v) end end
          emit_e(e, it.bi, it.gi, it.pr, e.kind == "tapis" and 1 or nil)
        end
        if not shared_done[g.side] then
          shared_done[g.side] = true
          -- (projet séparé, 3/11) pièces COMMUNES du réseau du charbon d'un côté, marquées : le runtime les pose dans le projet « réseau du
          -- charbon » de ce côté, pas dans la bande
          for _, e in ipairs(nt.ents) do
            emit_e(e, 0, 0, nil, (e.kind == "tapis" or e.kind == "souterrain" or e.kind == "repartiteur") and 1 or nil)
            ents[#ents].coalnet = g.side
          end
        end
      end
      cols_frame[key] = cols_frame[key] or {}
      cols_frame[key][tostring(g.side)] = { s_edge = g.s_edge, count = g.count, mode = mode }
      g.mode = mode
      local og = out_bands[it.bi] and out_bands[it.bi].groups[it.gi]
      if og then og.mode = (mode == "voie" and nt and nt.uT) and "voie" or mode end
    end
    for _, side in ipairs({ exit, -exit }) do
      local nt = nets[side]
      if nt then
        local why = nt.why
        if nt.dropped and #nt.dropped > 0 then why = (why and (why .. " ; ") or "") .. table.concat(nt.dropped, " ; ") end
        coal_stats[#coal_stats + 1] = { side = side, voie = nt.uT ~= nil, why = why, drills = nt.drills, undergrounds = nt.undergrounds, split = nt.split }
      end
    end
    if F and F.coal then coal_frame = F.coal end
    -- bande seule : les colonnes des AUTRES bandes du cadre sont réservées (non posées) avant les poteaux des rangées, qui les
    -- contournent comme dans le plan entier (sinon un poteau prolongé prendrait la tuile d'un bras d'une colonne voisine à venir)
    if F and F.cols then
      local keys = {}
      for k in pairs(F.cols) do keys[#keys + 1] = k end
      table.sort(keys, function(a, b) return tonumber(a) < tonumber(b) end)
      for _, k in ipairs(keys) do
        for _, sk in ipairs({ "1", "-1" }) do
          local fc = F.cols[k][sk]
          if fc and fc.mode ~= "refusee" and not (F.only and F.only[tonumber(k)]) then
            local l = Co.layout(spec, tonumber(k) + d.size + 1, tonumber(sk), fc.s_edge, fc.count, fc.mode)
            for _, e in ipairs(l or {}) do
              for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do c.take(u, v) end end
            end
          end
        end
      end
    end
  end
  -- poteaux des rangées : la rangée pr couvre le haut de sa bande et le bas de la bande d'avant ; elle va jusqu'aux fonderies (lot
  -- FONDERIE : seule la rangée pr, du côté des fours, va jusqu'à la colonne ; l'autre passerait sur la colonne de la bande voisine)
  local rows, row_list, reach_to = {}, {}, {}
  for bi, bd in ipairs(bands) do
    local bo = out_bands[bi]
    if #bo.groups > 0 then
      for _, it in ipairs({ { bd.pr, bd.n, bd.pr, "pole_u" }, { bd.pr + pitch, bd.s, bd.pr, colonne and "pole_u2" or "pole_u" } }) do
        local row = it[1]
        if not rows[row] then rows[row] = {}; reach_to[row] = {}; row_list[#row_list + 1] = { row = row, pr = it[3] } end
        for _, a in ipairs(it[2]) do rows[row][#rows[row] + 1] = a end
        for _, g in ipairs(bo.groups) do reach_to[row][#reach_to[row] + 1] = g[it[4]] end
      end
    end
  end
  table.sort(row_list, function(p, q) return p.row < q.row end)
  local all_poles = {}
  for _, e in ipairs(ents) do
    if e.kind == "poteau" then local u, v = c.uv(math.floor(e.x), math.floor(e.y)); all_poles[#all_poles + 1] = { u, v } end
  end
  for _, r in ipairs(row_list) do
    table.sort(reach_to[r.row])
    for _, u in ipairs(row_poles(c, spec, r.row, rows[r.row], origin, reach_to[r.row])) do
      emit("poteau", u, r.row, 1, 0, 0, 0, 0, r.pr)
      all_poles[#all_poles + 1] = { u, r.row }
    end
  end
  if not (F and F.only) and #all_poles > 1 then
    for _, p in ipairs((colonne and bridge or bridge_0641)(c, spec, all_poles)) do emit("poteau", p[1], p[2], 1, 0, 0, 0, 0, nil, "relais") end
  end
  local n = { foreuse = 0, poteau = 0, tapis = 0, four = 0, bras = 0, coffre = 0, souterrain = 0, repartiteur = 0 }
  for _, e in ipairs(ents) do n[e.kind] = n[e.kind] + 1 end
  local frame = { axis = axis, phase = phase, exit = exit, origin = origin, umin = umin, umax = umax, v0 = box.v0, offsets = offsets }
  if colonne then frame.design, frame.cols, frame.coal = "colonne", cols_frame, coal_frame
  elseif spec.design and not F then frame.design = "coffres" end -- cadre neuf sans four (charbon, pierre) : distinct d'un cadre d'avant le lot
  return {
    axis = axis, exit = exit, phase = phase, pitch = pitch, ents = ents, bands = out_bands, design = colonne and "colonne" or nil,
    fallback = fallback,
    fuelled = fuelled or nil,
    frame = frame,
    stats = { tiles = #c.list, drills = n.foreuse, poles = n.poteau, belts = n.tapis, furnaces = n.four, inserters = n.bras,
      chests = n.coffre, capped = capped, flow = flow_all, capacity = cap_all, umin = umin, umax = umax, no_smelter = no_smelter, no_smelter_at = no_smelter_at,
      undergrounds = n.souterrain, splitters = n.repartiteur, coal = coal_stats,
      band_drills = (function() local k = 0; for _, bd in ipairs(bands) do k = k + #bd.n + #bd.s end; return k end)() },
  }
end

--- Plan du champ (voir plus haut). Lot FONDERIE : un cadre NEUF en colonne à combustible ne garde aucune colonne retombée sur le coffre de
--- tête : elles sont refusées (spec.refuse) et le plan est refait sans elles ; le cadre les note « refusee » (une bande seule les saute).
--- plan.refused = { { pr, side, why } } (journal « colonne refusee : pas de voie de charbon »).
--- Foreuses du champ d'un plan (la ligne de charbon exclue).
function Ch.field_drills(p)
  local n = 0
  for _, e in ipairs(p and p.ents or {}) do if e.kind == "foreuse" and e.role ~= "charbon" then n = n + 1 end end
  return n
end

--- Règle pure (lot FONDERIE, 3/11) : le refus des colonnes sans voie de charbon est-il gardé ? before / after : fours du champ avec le
--- coffre de tête / avec le refus (lot DECOUPLAGE : les fours, plus les foreuses, qui restent). Rend (gardé, coût en % perdu, arrondi).
function Ch.refuse_keeps(before, after, min)
  if before <= 0 then return true, 0 end
  local cost = math.floor((1 - after / before) * 100 + 0.5)
  return after >= (min or Ch.CFG.refuse_min) * before - 1e-9, cost
end

--- Fours d'un plan.
function Ch.furnaces(p)
  local n = 0
  for _, e in ipairs(p and p.ents or {}) do if e.kind == "four" then n = n + 1 end end
  return n
end

local function plan_order(spec)
  local p, why = plan_once(spec)
  if not (Ch.CFG.refuse_coffre and p and p.design == "colonne" and p.fuelled and not spec.frame) then return p, why end
  if not (p.fallback and #p.fallback > 0) then return p, why end
  local p0, why0 = p, why -- plan avec les colonnes au coffre de tête (0.6.42) : gardé si le refus coûte trop
  local refuse, refused = {}, {}
  for _ = 1, Ch.CFG.refuse_passes do
    if not (p.fallback and #p.fallback > 0) then break end
    for _, x in ipairs(p.fallback) do
      local k = tostring(x.pr) .. ":" .. tostring(x.side)
      if not refuse[k] then refuse[k] = true; refused[#refused + 1] = x end
    end
    local sp = {}
    for k, v in pairs(spec) do sp[k] = v end
    sp.refuse = refuse
    p, why = plan_once(sp)
    if not p then break end
  end
  -- refus impossible (plan vide, ou replis encore là après les passes) : il coûte toute la fonderie
  local after = (p and not (p.fallback and #p.fallback > 0)) and Ch.furnaces(p) or 0
  local keep, cost = Ch.refuse_keeps(Ch.furnaces(p0), after)
  if not keep then
    p0.coffre_cost, p0.coffre_cols = cost, #p0.fallback
    return p0, why0
  end
  table.sort(refused, function(a, b) if a.pr ~= b.pr then return a.pr < b.pr end return a.side < b.side end)
  p.refused, p.refuse_cost = refused, cost
  if p.frame.cols then
    for _, x in ipairs(refused) do
      local key = tostring(x.pr)
      p.frame.cols[key] = p.frame.cols[key] or {}
      p.frame.cols[key][tostring(x.side)] = { mode = "refusee" }
    end
  end
  return p, why
end

--- Coffres de tête (combustible) d'un plan.
function Ch.head_chests(p)
  local n = 0
  for _, e in ipairs(p and p.ents or {}) do if e.kind == "coffre" and e.role == "combustible" then n = n + 1 end end
  return n
end

--- Règle pure (revue-fonderie, 3/11) : des deux ordres des côtés du réseau du charbon, le meilleur plan : le moins de coffres de tête,
--- puis le plus de foreuses du champ ; à égalité, le premier (ordre habituel). Rend vrai si `b` est meilleur que `a`.
function Ch.better_order(a, b)
  if not b then return false end
  if not a then return true end
  local ca, cb = Ch.head_chests(a), Ch.head_chests(b)
  if ca ~= cb then return cb < ca end
  return Ch.field_drills(b) > Ch.field_drills(a)
end

--- Plan du champ. (revue-fonderie, 3/11 : 3 champs de fer sur environ 10 gardaient des coffres de tête, le côté calculé en second ne
--- croisant pas le tracé du premier sans souterrain ; rejoué hors jeu sur le cadre de scarlet, graine 20261020 : côté + « aucun chemin »,
--- 4 coffres de tête ; l'autre ordre : 0 coffre, une colonne refusée de l'autre côté, 13 % des foreuses) un cadre NEUF en colonne à
--- combustible qui garde un coffre de tête ou refuse une colonne est aussi calculé dans l'autre ordre des côtés ; le meilleur est gardé.
function Ch.plan(spec)
  local p, why = plan_order(spec)
  if not (Ch.CFG.both_orders and p and p.design == "colonne" and p.fuelled and not spec.frame and not spec.coal_first) then return p, why end
  if Ch.head_chests(p) == 0 and not (p.refused and #p.refused > 0) then return p, why end
  local sp = {}
  for k, v in pairs(spec) do sp[k] = v end
  sp.coal_first = -p.exit
  local q, qwhy = plan_order(sp)
  if Ch.better_order(p, q) then
    q.order_swapped = { chests = Ch.head_chests(p), drills = Ch.field_drills(p) }
    return q, qwhy
  end
  return p, why
end

return Ch
