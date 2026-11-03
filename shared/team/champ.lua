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
    max_side foreuses par côté et par groupe au plus (nil : la voie la plus rapide)
    frame    cadre figé d'un plan précédent (plan.frame) : mêmes axe, phase, sortie, bords, décalages ; only = { [pr] = true } : ces
             bandes seulement (avec frame)
  plan = { axis, exit, frame, ents = { { kind, x, y, size, dir, band, group, pr, role, belt, module } }, bands, stats }
    kind : "foreuse" | "tapis" | "poteau" | "four" | "bras" | "coffre" ; dir 0 N, 2 E, 4 S, 6 O (foreuse : vers sa sortie ; tapis :
    sens de marche ; bras : côté où il PREND, convention de shared/team/modules.lua) ; role d'un coffre : "sortie" | "combustible".
  Déterminisme : listes triées, entiers, aucun `pairs` dans une décision, aucune trigonométrie.
]]

local Fd = require("shared.team.champ_fonderie")
local Mel = require("shared.team.melange")

local Ch = {}

Ch.CFG = {
  min_ore = 3,        -- tuiles de minerai au moins dans la zone d'une foreuse
  corridor = 32,      -- tuiles le long des rangées entre deux couloirs de passage (0 : aucun)
  gap = 2,            -- tuiles libres entre le bout du champ et la fonderie (passage)
  shift = 24,         -- tuiles dont la fonderie peut reculer pour trouver sa place (12 : bandes vides en jeu, la place prise par un autre chantier)
  both_ends = true,   -- une bande trop longue pour un tapis sort aussi par l'autre bout
  eps = 1e-9,
}

function Ch.key(x, y) return (x + 50000) * 100000 + (y + 50000) end
Ch.furnaces_for = Fd.furnaces_for

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
  for i = 1, #o - 1, 2 do
    local k = Ch.key(o[i], o[i + 1])
    if not c.ore[k] then c.ore[k] = true; local u, v = c.uv(o[i], o[i + 1]); c.list[#c.list + 1] = { u, v } end
  end
  c.is_ore = function(u, v) local x, y = c.xy(u, v); return c.ore[Ch.key(x, y)] == true end
  -- lot MELANGE : une tuile d'une autre ressource minable (jamais une tuile du minerai visé : celui-ci gagne s'il y est aussi)
  c.has_foreign = next(c.foreign) ~= nil
  c.is_foreign = function(u, v) local x, y = c.xy(u, v); local k = Ch.key(x, y); return c.foreign[k] == true and not c.ore[k] end
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
local function row_drills(c, spec, row, umin, umax, origin, o)
  local s, r = spec.drill.size, spec.drill.reach
  local out, seen, mined = {}, {}, 0
  local a = umin - r - s + 1 + o
  while a <= umax + r do
    local ok = true
    for u = a, a + s - 1 do
      if ok and corridor_col(origin, u) then ok = false end
      for v = row, row + s - 1 do if ok and not c.free(u, v) then ok = false end end
    end
    local n = 0
    -- lot MELANGE : zone qui touche une autre ressource minable -> refusée (la foreuse en déverserait sur le tapis de la bande)
    if ok and c.has_foreign then
      local x0, y0, x1, y1 = Mel.zone(a, row, s, r)
      if Mel.count(x0, y0, x1, y1, c.is_foreign) > 0 then ok = false end
    end
    if ok then
      for u = a - r, a + s - 1 + r do for v = row - r, row + s - 1 + r do if c.is_ore(u, v) then n = n + 1 end end end
    end
    if ok and n >= Ch.CFG.min_ore then
      out[#out + 1] = a
      for u = a - r, a + s - 1 + r do
        for v = row - r, row + s - 1 + r do
          local k = u * 100003 + v
          if c.is_ore(u, v) and not seen[k] then seen[k] = true; mined = mined + 1 end
        end
      end
      a = a + s
    else
      a = a + 1
    end
  end
  return out, mined
end

--- Meilleur décalage d'une rangée (plus de minerai miné, puis moins de foreuses, puis le plus petit), ou le décalage figé `fixed`.
local function best_row(c, spec, row, umin, umax, origin, fixed)
  local best, bm, bo
  for o = 0, spec.drill.size - 1 do
    if fixed == nil or fixed == o then
      local l, m = row_drills(c, spec, row, umin, umax, origin, o)
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
  while pr <= box.v1 do
    if not (frame and frame.only) or frame.only[pr] then
      local off = frame and frame.offsets and frame.offsets[tostring(pr)]
      local nl, nm, on = best_row(c, spec, pr + 1, box.u0, box.u1, origin, off and off[1])
      local sl, sm, os_ = best_row(c, spec, pr + s + 2, box.u0, box.u1, origin, off and off[2])
      if #nl + #sl > 0 then
        bands[#bands + 1] = { pr = pr, b = pr + s + 1, n = nl, s = sl, on = on, os = os_ }
        total = total + nm + sm
      end
    end
    pr = pr + pitch
  end
  return bands, total
end

--- Groupe d'une bande du côté `side` : foreuses prises depuis le bord, au plus `cap` par côté, tant que le tapis est libre jusqu'au
--- bord et (second groupe) en deçà de la coupe `limit` du premier. Rend { n, s, cut } (cut : centre de la foreuse la plus loin).
local function take_group(c, spec, band, side, cap, edge, used, limit)
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
    if (stop and beyond(it.cu, stop)) or cnt[it.side] >= cap then break end
    cnt[it.side] = cnt[it.side] + 1
    g[it.side][#g[it.side] + 1] = it.a
    g.cut = it.cu
    -- l'autre côté au même centre ne passe plus : la coupe recule (deux tapis ne partagent jamais une tuile)
    local nx = all[i + 1]
    if nx and nx.cu == it.cu and cnt[nx.side] >= cap then
      g[it.side][#g[it.side]] = nil
      g.cut = nil
      for j = i - 1, 1, -1 do if all[j].cu ~= it.cu then g.cut = all[j].cu break end end
      break
    end
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
    local best, ba, bb
    for i, p in ipairs(poles) do
      if root(i) == main then
        for j, q in ipairs(poles) do
          if root(j) ~= main then
            local d2 = (p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2
            if not best or d2 < best then best, ba, bb = d2, i, j end
          end
        end
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

local function long_axis(spec)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  local o = spec.ore
  for i = 1, #o - 1, 2 do
    x0, x1 = math.min(x0, o[i]), math.max(x1, o[i])
    y0, y1 = math.min(y0, o[i + 1]), math.max(y1, o[i + 1])
  end
  return (y1 - y0 > x1 - x0) and "y" or "x"
end

function Ch.plan(spec)
  if not (spec and spec.ore and #spec.ore >= 2 and spec.drill and spec.pole and spec.belts and #spec.belts > 0) then return nil, "donnees" end
  local d, F = spec.drill, spec.frame
  if spec.furnace and spec.furnace.size > d.size - 1 then return nil, "four trop grand pour la bande" end
  if spec.furnace and spec.furnace.fuel and spec.furnace.size < 2 then return nil, "four trop petit pour son coffre de combustible" end
  if spec.furnace and 2 * spec.furnace.size + 3 > spec.pole.wire + Ch.CFG.eps then return nil, "portee des poteaux" end
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
  local cap = Ch.lane_drills(spec.belts[#spec.belts].lane, d.rate)
  if spec.max_side then cap = math.min(cap, spec.max_side) end
  if cap < 1 then return nil, "tapis trop lent pour une foreuse" end
  local ents, out_bands = {}, {}
  local capped, flow_all, cap_all, no_smelter = 0, 0, 0, 0
  local function emit(kind, u, v, size, du, dv, bi, gi, pr, role, belt, module)
    local x, y = c.xy(u, v)
    local x2, y2 = c.xy(u + size - 1, v + size - 1)
    ents[#ents + 1] = { kind = kind, x = math.min(x, x2) + size / 2, y = math.min(y, y2) + size / 2, size = size,
      dir = (du ~= 0 or dv ~= 0) and c.dir(du, dv) or 0, band = bi, group = gi, pr = pr, role = role, belt = belt, module = module }
  end
  local offsets = {}
  for bi, bd in ipairs(bands) do
    offsets[tostring(bd.pr)] = { bd.on, bd.os }
    local used, groups, limit = {}, {}, nil
    for _, side in ipairs(Ch.CFG.both_ends and { exit, -exit } or { exit }) do
      local edge = side > 0 and umax or umin
      local g = take_group(c, spec, bd, side, cap, edge, used, limit)
      if g then
        local flow = (#g.n + #g.s) * d.rate
        local list, len, s_edge, count = Fd.place(spec, bd.b, side, edge, flow, Ch.CFG.gap, Ch.CFG.shift, c.free, c.is_ore)
        if list then
          for _, a in ipairs(g.n) do used[a .. "n"] = true end
          for _, a in ipairs(g.s) do used[a .. "s"] = true end
          for _, e in ipairs(list) do for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do c.take(u, v) end end end
          g.side, g.flow, g.s_edge, g.len, g.count, g.list = side, flow, s_edge, len, count, list
          g.belt = #spec.belts
          for i, bt in ipairs(spec.belts) do
            if Ch.lane_drills(bt.lane, d.rate) >= math.max(#g.n, #g.s) then g.belt = i break end
          end
          groups[#groups + 1] = g
          limit = g.cut
        else
          no_smelter = no_smelter + 1
        end
      end
    end
    local bo = { pr = bd.pr, b = bd.b, groups = {} }
    for _, l in ipairs({ { bd.n, "n" }, { bd.s, "s" } }) do
      for _, a in ipairs(l[1]) do if not used[a .. l[2]] then capped = capped + 1 end end
    end
    for gi, g in ipairs(groups) do
      for _, a in ipairs(g.n) do emit("foreuse", a, bd.pr + 1, d.size, 0, 1, bi, gi, bd.pr) end
      for _, a in ipairs(g.s) do emit("foreuse", a, bd.b + 1, d.size, 0, -1, bi, gi, bd.pr) end
      local s_end = g.s_edge + g.side * (g.len - 1)
      local nb = 0
      for u = g.cut, s_end, g.side do
        c.take(u, bd.b)
        emit("tapis", u, bd.b, 1, g.side, 0, bi, gi, bd.pr, nil, g.belt)
        nb = nb + 1
      end
      for _, e in ipairs(g.list) do emit(e.kind, e.u, e.v, e.size, e.du, e.dv, bi, gi, bd.pr, e.role, nil, e.module) end
      local capa = Fd.capacity(spec, g.count)
      flow_all, cap_all = flow_all + g.flow, cap_all + capa
      bo.groups[#bo.groups + 1] = { side = g.side, drills = #g.n + #g.s, per_side = math.max(#g.n, #g.s), flow = g.flow, belt = g.belt,
        count = g.count, capacity = capa, belt_tiles = nb, s_edge = g.s_edge, len = g.len, cut = g.cut,
        pole_u = g.s_edge + g.side * Fd.pole_col(spec) }
    end
    out_bands[#out_bands + 1] = bo
  end
  -- poteaux des rangées : la rangée pr couvre le haut de sa bande et le bas de la bande d'avant ; elle va jusqu'aux fonderies
  local rows, row_list, reach_to = {}, {}, {}
  for bi, bd in ipairs(bands) do
    local bo = out_bands[bi]
    if #bo.groups > 0 then
      for _, it in ipairs({ { bd.pr, bd.n, bd.pr }, { bd.pr + pitch, bd.s, bd.pr } }) do
        local row = it[1]
        if not rows[row] then rows[row] = {}; reach_to[row] = {}; row_list[#row_list + 1] = { row = row, pr = it[3] } end
        for _, a in ipairs(it[2]) do rows[row][#rows[row] + 1] = a end
        for _, g in ipairs(bo.groups) do reach_to[row][#reach_to[row] + 1] = g.pole_u end
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
    for _, p in ipairs(bridge(c, spec, all_poles)) do emit("poteau", p[1], p[2], 1, 0, 0, 0, 0, nil, "relais") end
  end
  local n = { foreuse = 0, poteau = 0, tapis = 0, four = 0, bras = 0, coffre = 0 }
  for _, e in ipairs(ents) do n[e.kind] = n[e.kind] + 1 end
  return {
    axis = axis, exit = exit, phase = phase, pitch = pitch, ents = ents, bands = out_bands,
    frame = { axis = axis, phase = phase, exit = exit, origin = origin, umin = umin, umax = umax, v0 = box.v0, offsets = offsets },
    stats = { tiles = #c.list, drills = n.foreuse, poles = n.poteau, belts = n.tapis, furnaces = n.four, inserters = n.bras,
      chests = n.coffre, capped = capped, flow = flow_all, capacity = cap_all, umin = umin, umax = umax, no_smelter = no_smelter,
      band_drills = (function() local k = 0; for _, bd in ipairs(bands) do k = k + #bd.n + #bd.s end; return k end)() },
  }
end

return Ch
