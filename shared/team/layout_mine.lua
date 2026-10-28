--[[
  AGENCEMENT D'UN CHAMP DE MINERAI (lot LAYOUT). Lua PUR : aucune API du jeu, aucun nom d'objet ; lu hors jeu
  (tests/layout_mine_test.lua) et en jeu (script/team/layout_runtime.lua, qui relève le champ au moteur).

  PROBLEME. Dans une zone, poser des foreuses carrées de côté `w` et de rayon de captation `reach` sur des tuiles de minerai
  (positions, quantités, ressource), en LIGNES de part et d'autre de couloirs de tapis qui sortent vers l'extérieur, de sorte
  que :
    - le minerai CAPTÉ (somme des quantités des tuiles dans le rayon d'au moins une foreuse) soit maximal ;
    - aucune foreuse ne capte DEUX ressources différentes (une foreuse dont le rayon touche deux minerais est refusée) ;
    - aucune foreuse inactive (chacune capte au moins `min_tiles` tuiles qu'aucune autre ne capte déjà) ;
    - le débit d'une voie de tapis (moitié du débit du tapis : une foreuse dépose sur la voie de son côté) ne soit jamais
      dépassé : au besoin, le couloir est COUPÉ en deux tapis qui sortent chacun par un bout (deux sorties) ; au-delà,
      les foreuses en trop sont retirées (jamais d'embouteillage) ;
    - un couloir ne soit jamais sur un obstacle ni sur un autre couloir ; chaque sortie est au bord de la zone (le
      tapis de liaison continue de là, tracé par l'appelant) ;
    - la colonne extérieure (`gap`) reste libre entre deux lignes pour les poteaux.

  MODELE. Une LIGNE ("strip") = un tapis droit (axe V : vertical ; H : horizontal) en `c`, des foreuses contiguës de chaque
  côté (leur sortie tombe sur la tuile du tapis qui touche leur bord). Les foreuses d'un côté sont posées sur un réseau de
  pas `w` (décalage `phase` choisi pour couvrir le plus de minerai). Phase A : réseau de lignes de pas 2w + 1 + gap, décalage
  essayé de 0 à pas - 1 sur les deux axes, meilleur total gardé (tout un champ, sans coin perdu en bordure régulière).
  Phase B : remplissage glouton par des lignes isolées (un ou deux côtés) là où il reste du minerai (coins, bandes étroites).
  Mode "single" (une seule ligne, une seule sortie, au plus `max_drills` foreuses) : le mode de l'exécutant, qui n'a qu'une
  arrivée de tapis à servir.

  Ce n'est PAS un optimum prouvé : le glouton par lignes est comparé à une force brute sur de petits champs
  (tests/layout_mine_test.lua) ; l'écart mesuré y est écrit.

  Déterminisme : tous les parcours sont des plages entières ou des listes triées ; égalités départagées par (axe, c, v, côté).
  Coordonnées : tuiles entières (coin nord-ouest) ; une foreuse porte son coin (ox, oy) et son centre (x, y).
  Directions : 0 nord, 2 est, 4 sud, 6 ouest (celles du moteur).
]]

local LM = {}

LM.EPS = 1e-9
LM.DEFAULT_BELT_RATE = 15 -- objets/s d'un tapis (2 voies), si l'appelant ne donne pas le débit lu au prototype

local EPS = LM.EPS
local OFF, SPAN = 1048576, 2097152
local function tk(x, y) return (x + OFF) * SPAN + (y + OFF) end
LM.tkey = tk
local floor = math.floor

-- Axe V : tapis vertical (u = x, v = y) ; axe H : tapis horizontal (u = y, v = x).
local FLOW = { V = { low = 0, high = 4 }, H = { low = 6, high = 2 } }
local FACE = { V = { [-1] = 2, [1] = 6 }, H = { [-1] = 4, [1] = 0 } }
local AXES = { "V", "H" }
local function axes_of(opts)
  if opts.axes then return opts.axes end
  return AXES
end

local function xy(axis, u, v) if axis == "V" then return u, v end return v, u end

--- Couverture d'une foreuse de côté w et de rayon reach : décalages (tuiles) par rapport à son coin, bornes comprises.
function LM.cover_offsets(w, reach)
  local c = w / 2
  return math.ceil(c - reach - 0.5 - EPS), floor(c + reach - 0.5 + EPS)
end

---------------------------------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------------------------------
local function index_tiles(list)
  local ore = {}
  for _, t in ipairs(list or {}) do ore[tk(t.x, t.y)] = { x = t.x, y = t.y, res = t.res, amount = t.amount or 1 } end
  return ore
end

local function new_state(field, drill, opts)
  local S = { w = drill.w, speed = drill.speed, opts = opts, memo = {}, occ = {}, keep = {} }
  S.lo, S.hi = LM.cover_offsets(drill.w, drill.reach)
  S.drop = drill.drop or { 0, -(drill.w / 2 + 0.35) }
  S.bounds = field.bounds
  S.ore = field.ore or index_tiles(field.tiles)
  local bl = field.blocked
  if type(bl) == "table" then S.blocked = function(x, y) return bl[tk(x, y)] end
  else S.blocked = bl or function() return false end end
  S.gap = opts.gap or 0
  S.lane_cap = (opts.belt_rate or LM.DEFAULT_BELT_RATE) / 2
  local side = S.hi - S.lo + 1
  S.min_tiles = opts.min_tiles or math.max(1, floor(side * side / 8))
  S.mining_time = opts.mining_time or {}
  -- ressources présentes dans la zone (triées) ; `only` restreint
  local seen, names = {}, {}
  local b = S.bounds
  local cu = {}
  S.cnt = { V = {}, H = {} }
  local keys = {}
  for k in pairs(S.ore) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local o = S.ore[k]
    if o.x >= b.x0 and o.x < b.x1 and o.y >= b.y0 and o.y < b.y1 and (o.amount or 0) > 0 then
      if not seen[o.res] and (not opts.only or opts.only == o.res) then seen[o.res] = true; names[#names + 1] = o.res end
      S.cnt.V[o.x] = (S.cnt.V[o.x] or 0) + 1
      S.cnt.H[o.y] = (S.cnt.H[o.y] or 0) + 1
    end
  end
  table.sort(names)
  S.reslist = names
  return S
end

function LM.rate_of(S, res) return S.speed / (S.mining_time[res] or 1) end

local function tile_free(S, x, y)
  local b = S.bounds
  if x < b.x0 or x >= b.x1 or y < b.y0 or y >= b.y1 then return false end
  return not S.blocked(x, y) and not S.occ[tk(x, y)]
end

--- Foreuse au coin (ox, oy) : emprise libre d'obstacle, dans la zone, rayon sans DEUX ressources, au moins min_tiles
--- tuiles de minerai. Résultat mémorisé (ne dépend pas de ce qui est déjà posé).
local function drill_at(S, ox, oy)
  local k = tk(ox, oy)
  local e = S.memo[k]
  if e ~= nil then return e end
  e = false
  local w, b = S.w, S.bounds
  if ox >= b.x0 and oy >= b.y0 and ox + w <= b.x1 and oy + w <= b.y1 then
    local ok = true
    for y = oy, oy + w - 1 do
      for x = ox, ox + w - 1 do if S.blocked(x, y) then ok = false end end
    end
    if ok then
      local res, keys, amount, amts = nil, {}, 0, {}
      for y = oy + S.lo, oy + w - 1 + S.hi do
        for x = ox + S.lo, ox + w - 1 + S.hi do
          local o = S.ore[tk(x, y)]
          if o and (o.amount or 0) > 0 then
            if res and res ~= o.res then ok = false end
            res = o.res
            keys[#keys + 1] = tk(x, y)
            amount = amount + o.amount
            amts[#keys] = o.amount
          end
        end
      end
      if ok and res and #keys >= S.min_tiles then e = { res = res, keys = keys, amts = amts, amount = amount, n = #keys } end
    end
  end
  S.memo[k] = e
  return e
end

local function footprint_free(S, ox, oy)
  for y = oy, oy + S.w - 1 do
    for x = ox, ox + S.w - 1 do
      local k = tk(x, y)
      if S.occ[k] or S.keep[k] then return false end
    end
  end
  return true
end

--- Plages libres d'une colonne de tapis `c` : { a, b (v inclus), lo_open, hi_open } (ouvert : touche le bord de la zone).
local function runs_of(S, axis, c)
  local b = S.bounds
  local v0, v1, u0, u1
  if axis == "V" then v0, v1, u0, u1 = b.y0, b.y1, b.x0, b.x1 else v0, v1, u0, u1 = b.x0, b.x1, b.y0, b.y1 end
  local out = {}
  if c < u0 or c >= u1 then return out end
  local a
  for v = v0, v1 - 1 do
    local x, y = xy(axis, c, v)
    local f = tile_free(S, x, y)
    if f and not a then a = v end
    if not f and a then out[#out + 1] = { a = a, b = v - 1 }; a = nil end
  end
  if a then out[#out + 1] = { a = a, b = v1 - 1 } end
  -- Ouvert : touche le bord de la zone ET la tuile juste au-delà n'est pas un obstacle connu (un tapis qui sortirait sur
  -- l'eau, une falaise ou un bâtiment serait enfermé : le tapis de liaison n'aurait aucun chemin).
  local function beyond_free(v)
    local x, y = xy(axis, c, v)
    return not S.blocked(x, y)
  end
  for _, r in ipairs(out) do
    r.lo_open = r.a == v0 and beyond_free(v0 - 1)
    r.hi_open = r.b == v1 - 1 and beyond_free(v1)
  end
  return out
end

--- Tuile où tombe le minerai d'une foreuse de coin (ox, oy) tournée vers `dir` : centre + vecteur de sortie (donné vers le
--- nord, tourné comme la foreuse). Une foreuse de côté pair dépose à une demi-tuile du milieu : la tuile du tapis change.
local function drop_tile(w, drop, ox, oy, dir)
  local x, y = drop[1], drop[2]
  local rx, ry
  if dir == 0 then rx, ry = x, y elseif dir == 2 then rx, ry = -y, x elseif dir == 4 then rx, ry = -x, -y else rx, ry = y, -x end
  return floor(ox + w / 2 + rx + EPS), floor(oy + w / 2 + ry + EPS)
end
LM.drop_tile = drop_tile

--- Avec colonne de poteaux (gap > 0) : une foreuse n\x27est posee que si une tuile de la colonne exterieure de son cote, face a
--- ses rangees, est libre et dans la zone (sinon aucun poteau ne peut l\x27alimenter).
local function pole_room(S, axis, c, side, v0)
  if S.gap <= 0 then return true end
  local u = c + side * (S.w + 1)
  for v = v0, v0 + S.w - 1 do
    local x, y = xy(axis, u, v)
    if tile_free(S, x, y) then return true end
  end
  return false
end

local function side_cands(S, axis, c, run, side, phase, res)
  local out = {}
  local w = S.w
  local v0 = run.a + phase
  while v0 + w - 1 <= run.b do
    local ox, oy
    local u0 = side < 0 and c - w or c + 1
    if axis == "V" then ox, oy = u0, v0 else ox, oy = v0, u0 end
    local d = drill_at(S, ox, oy)
    if d and d.res == res and footprint_free(S, ox, oy) and pole_room(S, axis, c, side, v0) then
      local tx, ty = drop_tile(w, S.drop, ox, oy, FACE[axis][side])
      local ut, dr = tx, ty
      if axis == "H" then ut, dr = ty, tx end
      if ut == c and dr >= v0 and dr <= v0 + w - 1 then
        out[#out + 1] = { d = d, v0 = v0, side = side, ox = ox, oy = oy, dr = dr }
      end
    end
    v0 = v0 + w
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Gains
---------------------------------------------------------------------------------------------------
local function union_gain(S, list, cov)
  local seen, amount, n = {}, 0, 0
  for _, e in ipairs(list) do
    local keys, amts = e.d.keys, e.d.amts
    for i = 1, #keys do
      local k = keys[i]
      if not cov[k] and not seen[k] then seen[k] = true; amount = amount + amts[i]; n = n + 1 end
    end
  end
  return amount, n
end

--- Gain marginal d'une foreuse sur ce qui est déjà capté (cov) : (quantité, nombre de tuiles).
local function marginal(e, cov)
  local keys, amts = e.d.keys, e.d.amts
  local a, n = 0, 0
  for i = 1, #keys do
    if not cov[keys[i]] then a = a + amts[i]; n = n + 1 end
  end
  return a, n
end

--- Choix glouton de foreuses par gain marginal (au moins min_tiles NOUVELLES tuiles), au plus max_n.
local function choose_greedy(S, cands, cov, max_n)
  -- glouton PARESSEUX : un gain marginal ne fait que baisser ; on ne recalcule que la tête de liste
  local cov2 = setmetatable({}, { __index = cov })
  local bound, fresh, taken, sel = {}, {}, {}, {}
  for i, e in ipairs(cands) do bound[i] = marginal(e, cov2); fresh[i] = true end
  while #sel < max_n do
    local best
    for i = 1, #cands do
      if not taken[i] and (not best or bound[i] > bound[best]) then best = i end
    end
    if not best then break end
    if fresh[best] then
      taken[best] = true
      local _, n = marginal(cands[best], cov2)
      if n >= S.min_tiles then
        sel[#sel + 1] = cands[best]
        for _, k in ipairs(cands[best].d.keys) do cov2[k] = true end
        for i = 1, #cands do fresh[i] = false end
      end
    else
      bound[best] = marginal(cands[best], cov2)
      fresh[best] = true
    end
  end
  return sel
end

local function by_dr(a, b)
  if a.dr ~= b.dr then return a.dr < b.dr end
  return a.side < b.side
end

--- Retire des foreuses d'un groupe jusqu'à ce que chaque voie (côté) tienne dans lane_cap.
local function trim_lanes(S, members)
  local keep = {}
  for _, side in ipairs({ -1, 1 }) do
    local m, load = {}, 0
    for _, e in ipairs(members) do
      if e.side == side then m[#m + 1] = e; load = load + LM.rate_of(S, e.d.res) end
    end
    while load > S.lane_cap + EPS and #m > 0 do
      local bi = 1
      for i = 2, #m do
        if m[i].d.amount < m[bi].d.amount or (m[i].d.amount == m[bi].d.amount and m[i].v0 > m[bi].v0) then bi = i end
      end
      load = load - LM.rate_of(S, m[bi].d.res)
      table.remove(m, bi)
    end
    for _, e in ipairs(m) do keep[#keep + 1] = e end
  end
  table.sort(keep, by_dr)
  return keep
end

--- Sorties du couloir : où coupe-t-on (j foreuses vers le bas, le reste vers le haut), débits par voie respectés.
--- Rend la ligne finie ou nil.
local function finalize(S, axis, c, run, res, sel, cov, single, toward)
  table.sort(sel, by_dr)
  local n = #sel
  local options = {}
  if single then
    if run.lo_open then options[#options + 1] = n end
    if run.hi_open then options[#options + 1] = 0 end
  else
    for j = 0, n do
      local ok = (j == 0 or run.lo_open) and (j == n or run.hi_open)
      if ok and j > 0 and j < n and sel[j].dr == sel[j + 1].dr then ok = false end
      if ok then options[#options + 1] = j end
    end
  end
  local best
  for _, j in ipairs(options) do
    local low, high = {}, {}
    for i, e in ipairs(sel) do if i <= j then low[#low + 1] = e else high[#high + 1] = e end end
    low, high = trim_lanes(S, low), trim_lanes(S, high)
    local all = {}
    for _, e in ipairs(low) do all[#all + 1] = e end
    for _, e in ipairs(high) do all[#all + 1] = e end
    local gain, tiles = union_gain(S, all, cov)
    local cand = { low = low, high = high, gain = gain, tiles = tiles, j = j, nd = #all }
    local dist = 0
    if toward and #all > 0 then
      local ex, ey
      if #low > 0 and #high == 0 then ex, ey = xy(axis, c, run.a) elseif #high > 0 and #low == 0 then ex, ey = xy(axis, c, run.b) end
      if ex then dist = math.abs(ex - toward.x) + math.abs(ey - toward.y) end
    end
    cand.dist = dist
    local better = not best
    if best then
      if cand.gain ~= best.gain then better = cand.gain > best.gain
      elseif cand.dist ~= best.dist then better = cand.dist < best.dist
      elseif cand.nd ~= best.nd then better = cand.nd < best.nd end
    end
    if better then best = cand end
  end
  if not best or best.nd == 0 then return nil end
  local belts, exits = {}, {}
  local function piece(group, v_from, v_to, dir, edge_v)
    for v = v_from, v_to do
      local x, y = xy(axis, c, v)
      belts[#belts + 1] = { x = x, y = y, dir = dir }
    end
    local flow = 0
    for _, e in ipairs(group) do flow = flow + LM.rate_of(S, e.d.res) end
    local x, y = xy(axis, c, edge_v)
    exits[#exits + 1] = { x = x, y = y, dir = dir, flow = flow, drills = #group }
  end
  if #best.low > 0 then piece(best.low, run.a, best.low[#best.low].dr, FLOW[axis].low, run.a) end
  if #best.high > 0 then piece(best.high, best.high[1].dr, run.b, FLOW[axis].high, run.b) end
  local all = {}
  for _, e in ipairs(best.low) do all[#all + 1] = e end
  for _, e in ipairs(best.high) do all[#all + 1] = e end
  table.sort(all, by_dr)
  return { axis = axis, c = c, a = run.a, b = run.b, res = res, drills = all, belts = belts, exits = exits,
    gain = best.gain, tiles = best.tiles }
end

--- Foreuses candidates d'une ligne (décalage de chaque côté choisi), triées par (v, côté) ; nil si aucune.
local function prep_strip(S, axis, c, run, res, cov)
  local cands = {}
  for _, side in ipairs({ -1, 1 }) do
    local bp, bs
    for phase = 0, S.w - 1 do
      local list = side_cands(S, axis, c, run, side, phase, res)
      local s = 0
      if next(cov) == nil then
        -- rien de capté encore : somme des quantités (le recouvrement de deux voisines est le même à tous les décalages)
        for _, e in ipairs(list) do s = s + e.d.amount end
      else
        s = union_gain(S, list, cov)
      end
      if #list > 0 and (not bs or s > bs) then bp, bs = list, s end
    end
    for _, e in ipairs(bp or {}) do cands[#cands + 1] = e end
  end
  table.sort(cands, function(a, b) if a.v0 ~= b.v0 then return a.v0 < b.v0 end return a.side < b.side end)
  if #cands == 0 then return nil end
  return cands
end

--- Ligne finie depuis ses candidates (choix glouton, sorties, débits).
local function finish_strip(S, axis, c, run, res, cands, cov, single, max_n, toward)
  local sel = choose_greedy(S, cands, cov, max_n or math.huge)
  if #sel == 0 then return nil end
  return finalize(S, axis, c, run, res, sel, cov, single, toward)
end

--- Une ligne candidate sur la plage `run` du couloir c pour la ressource res (nil si rien de rentable).
local function eval_strip(S, axis, c, run, res, cov, single, max_n, toward)
  local cands = prep_strip(S, axis, c, run, res, cov)
  if not cands then return nil end
  return finish_strip(S, axis, c, run, res, cands, cov, single, max_n, toward)
end

local function apply_strip(S, st, cov)
  local w, gap = S.w, S.gap
  for _, e in ipairs(st.drills) do
    for y = e.oy, e.oy + w - 1 do
      for x = e.ox, e.ox + w - 1 do S.occ[tk(x, y)] = true end
    end
    for y = e.oy - gap, e.oy + w - 1 + gap do
      for x = e.ox - gap, e.ox + w - 1 + gap do S.keep[tk(x, y)] = true end
    end
    for _, k in ipairs(e.d.keys) do cov[k] = true end
  end
  for _, bt in ipairs(st.belts) do S.occ[tk(bt.x, bt.y)] = true end
end

local function strip_better(a, b, single)
  if a.gain ~= b.gain then return a.gain > b.gain end
  if single then
    local da, db = a.dist or 0, b.dist or 0
    if da ~= db then return da < db end
  end
  if #a.drills ~= #b.drills then return #a.drills < #b.drills end
  if a.axis ~= b.axis then return a.axis < b.axis end
  if a.c ~= b.c then return a.c < b.c end
  return a.a < b.a
end

local function u_range(S, axis)
  local b = S.bounds
  if axis == "V" then return b.x0, b.x1 end
  return b.y0, b.y1
end

local function band_has_ore(S, axis, c)
  local cnt = S.cnt[axis == "V" and "V" or "H"]
  for u = c - S.w + S.lo, c + S.w + S.hi do if cnt[u] then return true end end
  return false
end

---------------------------------------------------------------------------------------------------
-- Plan
---------------------------------------------------------------------------------------------------
local function assemble(S, strips, cov)
  local drills, belts, exits, rate = {}, {}, {}, 0
  local total, total_tiles = 0, 0
  local tot_seen = {}
  for k, o in pairs(S.ore) do
    -- tout le minerai du champ lu (y compris la marge au-delà de la zone : le rayon d'une foreuse du bord la dépasse)
    if (o.amount or 0) > 0 and (not S.opts.only or S.opts.only == o.res) then
      total = total + (o.amount or 0)
      total_tiles = total_tiles + 1
    end
    tot_seen[k] = true
  end
  local amount, tiles = 0, 0
  local ckeys = {}
  for k in pairs(cov) do ckeys[#ckeys + 1] = k end
  for _, k in ipairs(ckeys) do amount = amount + S.ore[k].amount; tiles = tiles + 1 end
  local poles, pset = {}, {}
  for i, st in ipairs(strips) do
    st.index = i
    for _, e in ipairs(st.drills) do
      local r = LM.rate_of(S, e.d.res)
      drills[#drills + 1] = { x = e.ox + S.w / 2, y = e.oy + S.w / 2, ox = e.ox, oy = e.oy, dir = FACE[st.axis][e.side],
        rate = r, res = e.d.res, amount = e.d.amount, tiles = e.d.n, strip = i, side = e.side }
      rate = rate + r
    end
    for _, bt in ipairs(st.belts) do belts[#belts + 1] = { x = bt.x, y = bt.y, dir = bt.dir, strip = i } end
    for _, ex in ipairs(st.exits) do exits[#exits + 1] = { x = ex.x, y = ex.y, dir = ex.dir, flow = ex.flow, drills = ex.drills, strip = i } end
    -- colonnes extérieures des deux côtés + deux rangées au-delà de chaque bout (liaison d'un côté à l'autre) : tuiles des poteaux
    local vmin, vmax = math.huge, -math.huge
    for _, e in ipairs(st.drills) do
      vmin = math.min(vmin, e.v0)
      vmax = math.max(vmax, e.v0 + S.w - 1)
    end
    local function add_pole(u, v)
      local x, y = xy(st.axis, u, v)
      local k = tk(x, y)
      if tile_free(S, x, y) and not pset[k] then pset[k] = true; poles[#poles + 1] = { x = x, y = y } end
    end
    for _, side in ipairs({ -1, 1 }) do
      for v = vmin, vmax do add_pole(st.c + side * (S.w + 1), v) end
    end
    for _, v in ipairs({ vmin - 1, vmin - 2, vmax + 1, vmax + 2 }) do
      for u = st.c - (S.w + 1), st.c + (S.w + 1) do add_pole(u, v) end
    end
  end
  table.sort(poles, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
  return { ok = true, strips = strips, drills = drills, belts = belts, exits = exits, pole_tiles = poles,
    drills_n = #drills, strips_n = #strips, covered = amount, covered_tiles = tiles, total = total, total_tiles = total_tiles, rate = rate, w = S.w,
    lo = S.lo, hi = S.hi, belt_rate = S.lane_cap * 2, gap = S.gap, bounds = S.bounds }
end

--- Plan d'un champ. field = { tiles = { {x, y, res, amount} } (ou ore = { [clé] = {...} }), blocked = fonction (x, y) ou
--- ensemble { [LM.tkey(x, y)] = true }, bounds = { x0, y0, x1, y1 } (x1, y1 exclus : zone où tout doit tenir) } ;
--- drill = { w (côté, tuiles), reach (rayon de captation), speed (minerai/s) } ; opts = { belt_rate (objets/s du tapis),
--- gap (colonnes libres entre lignes, 0 ou 1 : poteaux), axes (liste, défaut { "V", "H" }), min_tiles, mode = "all" | "single", max_drills (single),
--- toward = {x, y} (single : sortie la plus proche), only (ressource), mining_time = { [res] = secondes }, fill (lignes de
--- remplissage au plus, défaut 8) }. Rend le plan ou (nil, raison).
function LM.plan(field, drill, opts)
  opts = opts or {}
  if not (type(drill) == "table" and drill.w and drill.reach and drill.speed and drill.speed > 0) then return nil, "foreuse incomplete" end
  if drill.h and drill.h ~= drill.w then return nil, "foreuse non carree" end
  if not (field and field.bounds) then return nil, "zone absente" end
  local S = new_state(field, drill, opts)
  local depth = -S.drop[2] - drill.w / 2
  if not (depth > 0 and depth < 1) then return nil, "sortie de foreuse non adjacente" end
  if #S.reslist == 0 then return nil, "aucun minerai" end
  local cov = {}
  local single = opts.mode == "single"
  local w = S.w

  if single then
    local best
    local max_n = opts.max_drills or math.huge
    -- 1. candidates de chaque ligne et une borne haute de leur gain (les max_n plus riches foreuses, sans recouvrement)
    local pool = {}
    for _, axis in ipairs(axes_of(opts)) do
      local u0, u1 = u_range(S, axis)
      for c = u0, u1 - 1 do
        if band_has_ore(S, axis, c) then
          for _, run in ipairs(runs_of(S, axis, c)) do
            if run.lo_open or run.hi_open then
              for _, res in ipairs(S.reslist) do
                local cands = prep_strip(S, axis, c, run, res, cov)
                if cands then
                  local amounts = {}
                  for _, e in ipairs(cands) do amounts[#amounts + 1] = e.d.amount end
                  table.sort(amounts, function(x, y) return x > y end)
                  local bound = 0
                  for i = 1, math.min(#amounts, max_n) do bound = bound + amounts[i] end
                  pool[#pool + 1] = { axis = axis, c = c, run = run, res = res, cands = cands, bound = bound }
                end
              end
            end
          end
        end
      end
    end
    -- 2. par borne décroissante ; on s'arrête quand aucune ne peut battre la meilleure (égalité : évaluée, départage par la destination)
    table.sort(pool, function(x, y)
      if x.bound ~= y.bound then return x.bound > y.bound end
      if x.axis ~= y.axis then return x.axis < y.axis end
      if x.c ~= y.c then return x.c < y.c end
      return x.run.a < y.run.a
    end)
    for _, e in ipairs(pool) do
      if best and e.bound < best.gain then break end
      local st = finish_strip(S, e.axis, e.c, e.run, e.res, e.cands, cov, true, max_n, opts.toward)
      if st then
        st.dist = 0
        if opts.toward and #st.exits > 0 then
          st.dist = math.abs(st.exits[1].x - opts.toward.x) + math.abs(st.exits[1].y - opts.toward.y)
        end
        if not best or strip_better(st, best, true) then best = st end
      end
    end
    if not best then return nil, "aucune ligne" end
    apply_strip(S, best, cov)
    return assemble(S, { best }, cov)
  end

  -- Phase A : réseau de lignes parallèles, décalage et axe essayés
  local pitch = 2 * w + 1 + S.gap
  local bestA
  for _, axis in ipairs(axes_of(opts)) do
    local u0, u1 = u_range(S, axis)
    for s = 0, pitch - 1 do
      local lcov, strips, gain, nd = {}, {}, 0, 0
      local c = u0 + s
      while c < u1 do
        if band_has_ore(S, axis, c) then
          for _, run in ipairs(runs_of(S, axis, c)) do
            if run.lo_open or run.hi_open then
              local bs
              for _, res in ipairs(S.reslist) do
                local st = eval_strip(S, axis, c, run, res, lcov, false, math.huge, nil)
                if st and (not bs or st.gain > bs.gain) then bs = st end
              end
              if bs then
                strips[#strips + 1] = bs
                gain = gain + bs.gain
                nd = nd + #bs.drills
                for _, e in ipairs(bs.drills) do for _, k in ipairs(e.d.keys) do lcov[k] = true end end
              end
            end
          end
        end
        c = c + pitch
      end
      local cand = { strips = strips, gain = gain, nd = nd, axis = axis, s = s }
      local better = not bestA
      if bestA then
        if cand.gain ~= bestA.gain then better = cand.gain > bestA.gain
        elseif cand.nd ~= bestA.nd then better = cand.nd < bestA.nd end
      end
      if better and #strips > 0 then bestA = cand end
    end
  end
  local strips = {}
  if bestA then
    for _, st in ipairs(bestA.strips) do
      apply_strip(S, st, cov)
      strips[#strips + 1] = st
    end
  end
  -- Phase B : remplissage glouton (coins, bandes étroites)
  for _ = 1, opts.fill or 8 do
    local best
    for _, axis in ipairs(axes_of(opts)) do
      local u0, u1 = u_range(S, axis)
      for c = u0, u1 - 1 do
        if band_has_ore(S, axis, c) then
          for _, run in ipairs(runs_of(S, axis, c)) do
            if (run.lo_open or run.hi_open) and run.b - run.a + 1 >= w then
              for _, res in ipairs(S.reslist) do
                local st = eval_strip(S, axis, c, run, res, cov, false, math.huge, nil)
                if st and (not best or strip_better(st, best, false)) then best = st end
              end
            end
          end
        end
      end
    end
    if not best then break end
    apply_strip(S, best, cov)
    strips[#strips + 1] = best
  end
  if #strips == 0 then return nil, "aucune ligne" end
  return assemble(S, strips, cov)
end

---------------------------------------------------------------------------------------------------
-- Contrôle indépendant d'un plan (tests et garde de l'exécutant)
---------------------------------------------------------------------------------------------------
--- Liste des défauts d'un plan (vide : valide) : emprises hors zone, sur obstacle ou qui se recouvrent ; tapis hors zone,
--- sur obstacle ou sous une foreuse ; sortie de foreuse hors tapis ; deux ressources dans un rayon ; foreuse inactive ;
--- voie au-dessus du débit ; tapis qui n'aboutit pas à une sortie au bord de la zone.
function LM.check(plan, field, drill, opts)
  opts = opts or {}
  local errs = {}
  local S = new_state(field, drill, opts)
  local b = S.bounds
  local w = S.w
  local occ = {}
  local function err(m) errs[#errs + 1] = m end
  for i, d in ipairs(plan.drills) do
    if d.ox < b.x0 or d.oy < b.y0 or d.ox + w > b.x1 or d.oy + w > b.y1 then err("foreuse " .. i .. " hors zone") end
    for y = d.oy, d.oy + w - 1 do
      for x = d.ox, d.ox + w - 1 do
        if S.blocked(x, y) then err("foreuse " .. i .. " sur obstacle") end
        if occ[tk(x, y)] then err("foreuse " .. i .. " recouvre une autre entite") end
        occ[tk(x, y)] = "d"
      end
    end
  end
  local belt = {}
  for i, bt in ipairs(plan.belts) do
    if bt.x < b.x0 or bt.x >= b.x1 or bt.y < b.y0 or bt.y >= b.y1 then err("tapis " .. i .. " hors zone") end
    if S.blocked(bt.x, bt.y) then err("tapis " .. i .. " sur obstacle") end
    if occ[tk(bt.x, bt.y)] then err("tapis " .. i .. " recouvre une autre entite") end
    occ[tk(bt.x, bt.y)] = "b"
    belt[tk(bt.x, bt.y)] = bt
  end
  -- chaque foreuse : sa sortie tombe sur un tapis, rayon d'une seule ressource, active
  local cov, load = {}, {}
  for i, d in ipairs(plan.drills) do
    -- tuile de sortie recalculée ici (sans drop_tile) : le contrôle ne partage pas le code du plan
    local cx, cy = d.ox + w / 2, d.oy + w / 2
    local qx, qy = S.drop[1], S.drop[2]
    local rx, ry = qx, qy
    if d.dir == 2 then rx, ry = -qy, qx elseif d.dir == 4 then rx, ry = -qx, -qy elseif d.dir == 6 then rx, ry = qy, -qx end
    local tx, ty = floor(cx + rx + EPS), floor(cy + ry + EPS)
    local bt = belt[tk(tx, ty)]
    if not bt then err("foreuse " .. i .. " ne depose sur aucun tapis")
    else
      local k = bt.strip .. ":" .. bt.dir .. ":" .. d.side
      load[k] = (load[k] or 0) + d.rate
    end
    local res, n = nil, 0
    for y = d.oy + S.lo, d.oy + w - 1 + S.hi do
      for x = d.ox + S.lo, d.ox + w - 1 + S.hi do
        local o = S.ore[tk(x, y)]
        if o and (o.amount or 0) > 0 then
          if res and res ~= o.res then err("foreuse " .. i .. " capte deux ressources") end
          res = o.res
          if not cov[tk(x, y)] then n = n + 1 end
        end
      end
    end
    -- tuiles NOUVELLES vues dans l'ordre : le contrôle d'activité se refait après (ordre du plan)
    for y = d.oy + S.lo, d.oy + w - 1 + S.hi do
      for x = d.ox + S.lo, d.ox + w - 1 + S.hi do
        local o = S.ore[tk(x, y)]
        if o and (o.amount or 0) > 0 then cov[tk(x, y)] = true end
      end
    end
    if res == nil then err("foreuse " .. i .. " inactive (aucun minerai)") end
    if res and res ~= d.res then err("foreuse " .. i .. " : ressource annoncee differente") end
  end
  for _, k in ipairs((function() local t = {} for kk in pairs(load) do t[#t + 1] = kk end table.sort(t) return t end)()) do
    if load[k] > S.lane_cap + 1e-6 then err("voie " .. k .. " au-dessus du debit : " .. load[k]) end
  end
  -- colonne libre (poteaux) entre deux foreuses de lignes différentes : `gap` tuiles au moins
  if (opts.gap or 0) > 0 then
    for i, a in ipairs(plan.drills) do
      for j = i + 1, #plan.drills do
        local c = plan.drills[j]
        if a.strip ~= c.strip then
          local gx = math.max(a.ox - (c.ox + w), c.ox - (a.ox + w))
          local gy = math.max(a.oy - (c.oy + w), c.oy - (a.oy + w))
          if math.max(gx, gy) < opts.gap then err("foreuses " .. i .. " et " .. j .. " : pas de colonne libre entre deux lignes") end
        end
      end
    end
  end
  -- suivi des tapis jusqu'à une sortie
  local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
  local exit_at = {}
  for _, ex in ipairs(plan.exits) do exit_at[tk(ex.x, ex.y)] = ex end
  for i, bt in ipairs(plan.belts) do
    local x, y, steps = bt.x, bt.y, 0
    local reached = false
    while steps < 4096 do
      local cur = belt[tk(x, y)]
      if not cur then break end
      if exit_at[tk(x, y)] then
        reached = true
        local ex = exit_at[tk(x, y)]
        local nx, ny = x + DV[cur.dir][1], y + DV[cur.dir][2]
        if nx >= b.x0 and nx < b.x1 and ny >= b.y0 and ny < b.y1 then err("sortie " .. i .. " pas au bord de la zone") end
        if S.blocked(nx, ny) then err("sortie " .. i .. " enfermee : la tuile au-dela est un obstacle") end
        break
      end
      x, y = x + DV[cur.dir][1], y + DV[cur.dir][2]
      steps = steps + 1
    end
    if not reached then err("tapis " .. i .. " n'aboutit pas a une sortie") end
  end
  -- activité : chaque foreuse capte au moins min_tiles tuiles que les foreuses posées avant elle ne captent pas, dans
  -- l'ordre INVERSE aussi (aucune n'est entièrement redondante)
  local seen = {}
  local cnt = {}
  for i, d in ipairs(plan.drills) do
    for y = d.oy + S.lo, d.oy + w - 1 + S.hi do
      for x = d.ox + S.lo, d.ox + w - 1 + S.hi do
        local o = S.ore[tk(x, y)]
        if o and (o.amount or 0) > 0 then cnt[tk(x, y)] = (cnt[tk(x, y)] or 0) + 1 end
      end
    end
  end
  for i, d in ipairs(plan.drills) do
    local sole = 0
    for y = d.oy + S.lo, d.oy + w - 1 + S.hi do
      for x = d.ox + S.lo, d.ox + w - 1 + S.hi do
        local o = S.ore[tk(x, y)]
        if o and (o.amount or 0) > 0 and cnt[tk(x, y)] == 1 then sole = sole + 1 end
      end
    end
    seen[i] = sole
  end
  if opts.strict_active then
    for i = 1, #plan.drills do if seen[i] == 0 then err("foreuse " .. i .. " redondante (aucune tuile en propre)") end end
  end
  return errs
end

return LM
