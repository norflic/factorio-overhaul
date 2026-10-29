--[[
  Tests hors jeu de l'espace et de l'enceinte des équipes de PNJ (lot ESPACE, shared/team/enceinte.lua, pur).
  Usage, depuis la racine du mod :   lua5.2 tests/enceinte_test.lua
  Vérifie : géométrie de l'anneau (au-delà du treillis, jamais dedans), ouvertures sur les rues principales, tuiles
  écartées, décompte exact (formule = anneau), croissance et enceinte (cas limites), fabrication au coffre, déterminisme.
]]
package.path = "./?.lua;" .. package.path
local E = require("shared.team.enceinte")
local P = require("shared.team.plan")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local lat = P.lattice({ x = 100.5, y = -40.5 })

-- 1. Géométrie : aucune tuile de mur dans le treillis (lots et rues du rayon r), distance exacte au bord
for r = 1, 5 do
  local ring = E.ring(lat, r)
  local lo_x, hi_x = lat.ox - (28 * r + 16), lat.ox + 28 * r + 15
  local lo_y, hi_y = lat.oy - (28 * r + 16), lat.oy + 28 * r + 15
  local inside, minx, maxx = 0, math.huge, -math.huge
  for _, w in ipairs(ring.walls) do
    if w.tx >= lo_x and w.tx <= hi_x and w.ty >= lo_y and w.ty <= hi_y then inside = inside + 1 end
    minx, maxx = math.min(minx, w.tx), math.max(maxx, w.tx)
  end
  check(inside == 0, "r=" .. r .. " : aucun mur dans le treillis (" .. inside .. ")")
  check(minx == lo_x - E.GAP - 1 and maxx == hi_x + E.GAP + 1, "r=" .. r .. " : le mur est a GAP+1 du bord (x " .. minx .. ".." .. maxx .. ")")
  -- le treillis réel : tous les tronçons de segs_within(r) sont dans le carré [lo, hi], et touchent ses bords
  local ok, touch = true, 0
  for _, key in ipairs(P.segs_within(r)) do
    local x0, y0, x1, y1 = P.seg_rect(lat, key)
    if x0 < lo_x or y0 < lo_y or x1 - 1 > hi_x or y1 - 1 > hi_y then ok = false end
    if x0 == lo_x or y0 == lo_y or x1 - 1 == hi_x or y1 - 1 == hi_y then touch = touch + 1 end
  end
  check(ok and touch > 0, "r=" .. r .. " : le bord du treillis calcule colle a segs_within")
  -- les lots aussi
  local lots_ok = true
  for _, l in ipairs(P.lots_within(r)) do
    local x0, y0, x1, y1 = P.lot_rect(lat, l.i, l.j)
    if x0 < lo_x or y0 < lo_y or x1 - 1 > hi_x or y1 - 1 > hi_y then lots_ok = false end
  end
  check(lots_ok, "r=" .. r .. " : tous les lots sont dans le treillis")
  check(#ring.walls == E.max_walls(r), "r=" .. r .. " : formule max_walls = anneau (" .. #ring.walls .. " / " .. E.max_walls(r) .. ")")
  check(ring.gates == 4 * #E.MAIN_STREETS * E.STREET, "r=" .. r .. " : 4 cotes x 2 rues x 4 tuiles d'ouverture (" .. ring.gates .. ")")
  local seen, dup = {}, 0
  for _, w in ipairs(ring.walls) do local k = P.tkey(w.tx, w.ty); if seen[k] then dup = dup + 1 end seen[k] = true end
  check(dup == 0, "r=" .. r .. " : aucune tuile en double")
end

-- 2. Ouvertures : le prolongement exact des rues principales (le lot 0:0 borde les rues -1 et 0) est ouvert, rien d'autre
do
  local ring = E.ring(lat, 3)
  local x0, y0, x1, y1 = table.unpack(ring.bounds)
  local set = {}
  for _, w in ipairs(ring.walls) do set[P.tkey(w.tx, w.ty)] = true end
  local function gate_x(tx)
    for _, m in ipairs({ -1, 0 }) do
      local a = lat.ox + 28 * m + 12
      if tx >= a and tx < a + 4 then return true end
    end
    return false
  end
  local bad = 0
  for tx = x0, x1 do
    if gate_x(tx) == (set[P.tkey(tx, y0)] == true) then bad = bad + 1 end -- ouvert <=> pas de mur
  end
  check(bad == 0, "cote nord : mur partout sauf sur les 2 rues principales (" .. bad .. " ecarts)")
  -- les rues principales du lot du QG : tronçons v:0:j (colonne 0) et v:-1:j (colonne -1)
  local ax0, _, ax1 = P.seg_rect(lat, P.seg_key("v", 0, 0))
  local bx0, _, bx1 = P.seg_rect(lat, P.seg_key("v", -1, 0))
  check(gate_x(ax0) and gate_x(ax1 - 1) and not gate_x(ax0 - 1) and not gate_x(ax1), "l'ouverture a la largeur exacte de la rue v:0:j")
  check(gate_x(bx0) and gate_x(bx1 - 1) and not gate_x(bx0 - 1) and not gate_x(bx1), "l'ouverture a la largeur exacte de la rue v:-1:j")
  -- idem pour les rangées (côtés ouest et est)
  local gy_ok = true
  for ty = y0 + 1, y1 - 1 do
    local g = false
    for _, m in ipairs({ -1, 0 }) do local a = lat.oy + 28 * m + 12; if ty >= a and ty < a + 4 then g = true end end
    if g == (set[P.tkey(x0, ty)] == true) or g == (set[P.tkey(x1, ty)] == true) then gy_ok = false end
  end
  check(gy_ok, "cotes ouest et est : memes ouvertures sur les rangees -1 et 0")
  check(set[P.tkey(x0, y0)] and set[P.tkey(x1, y0)] and set[P.tkey(x0, y1)] and set[P.tkey(x1, y1)], "les 4 coins sont murs")
end

-- 3. Tuiles écartées (eau, ressource) : jamais murées, comptées par raison
do
  local full = E.ring(lat, 2)
  local x0, y0 = table.unpack(full.bounds)
  local water = {}
  for tx = x0 + 10, x0 + 19 do water[P.tkey(tx, y0)] = true end
  local ore = P.tkey(x0, y0 + 30)
  local ring = E.ring(lat, 2, { skip = function(tx, ty)
    local k = P.tkey(tx, ty)
    if water[k] then return "eau" end
    if k == ore then return "ressource" end
    return nil
  end })
  check(ring.skipped["eau"] == 10 and ring.skipped["ressource"] == 1, "eau et ressource ecartees et comptees")
  check(#ring.walls == #full.walls - 11, "11 murs de moins")
  local on_water = 0
  for _, w in ipairs(ring.walls) do if water[P.tkey(w.tx, w.ty)] or P.tkey(w.tx, w.ty) == ore then on_water = on_water + 1 end end
  check(on_water == 0, "aucun mur sur l'eau ni sur la ressource")
  local again = E.ring(lat, 2)
  local same = #again.walls == #full.walls
  for i, w in ipairs(again.walls) do if w.tx ~= full.walls[i].tx or w.ty ~= full.walls[i].ty then same = false end end
  check(same, "deterministe (deux appels, meme liste ordonnee)")
end

-- 4. Croissance et enceinte : cas limites
do
  local base = { radius = 3, rmax = 5, pending = 0, free = 1, busy = 1, done = 2, enc = false }
  local function with(t)
    local o = {}
    for _, k in ipairs({ "radius", "rmax", "pending", "free", "busy", "done", "enc" }) do o[k] = base[k] end
    for k, v in next, t do o[k] = v end
    return o
  end
  check(E.grow_due(base) == true, "croit : peu de place, peu de chantiers, un projet fini")
  check(E.grow_due(with({ free = E.GROW_FREE_MIN })) == false, "ne croit pas avec assez de place libre")
  check(E.grow_due(with({ free = E.GROW_FREE_MIN - 1 })) == true, "croit juste sous le seuil")
  check(E.grow_due(with({ radius = 5 })) == false, "ne croit pas au rayon maximal")
  check(E.grow_due(with({ pending = 3 })) == false, "ne croit pas pendant l'evaluation du rayon")
  check(E.grow_due(with({ busy = E.BUSY_MAX + 1 })) == false, "ne croit pas surcharge de chantiers")
  check(E.grow_due(with({ busy = E.BUSY_MAX })) == true, "croit a la limite de charge")
  check(E.grow_due(with({ done = 0 })) == false, "ne croit pas sans projet fini")
  check(E.grow_due(with({ enc = true })) == false, "ne croit plus apres l'enceinte")
  check(E.enclosure_due(with({ done = E.MIN_PROJECTS, free = 5 })) == true, "enceinte : base mure, place libre")
  check(E.enclosure_due(with({ done = E.MIN_PROJECTS - 1, free = 5 })) == false, "enceinte : base trop jeune")
  check(E.enclosure_due(with({ done = E.MIN_PROJECTS, free = 0 })) == false, "enceinte : la croissance passe d'abord")
  check(E.enclosure_due(with({ done = E.MIN_PROJECTS, free = 0, radius = 5 })) == true, "enceinte : rayon maximal, plus de croissance possible")
  check(E.enclosure_due(with({ done = E.MIN_PROJECTS, free = 5, enc = true })) == false, "enceinte : une seule")
  check(E.enclosure_due(with({ done = E.MIN_PROJECTS, free = 5, pending = 1 })) == false, "enceinte : attend l'evaluation")
  -- la croissance et l'enceinte ne sont jamais voulues ensemble, et au rayon maximal l'une des deux l'est (sauf base jeune)
  local both, neither_mature = 0, 0
  for free = 0, 6 do
    for radius = 1, 5 do
      for done = 0, 7 do
        for busy = 0, 4 do
          local i = with({ free = free, radius = radius, done = done, busy = busy })
          if E.grow_due(i) and E.enclosure_due(i) then both = both + 1 end
          if radius == 5 and done >= E.MIN_PROJECTS and not E.enclosure_due(i) then neither_mature = neither_mature + 1 end
        end
      end
    end
  end
  check(both == 0, "jamais croissance ET enceinte ensemble")
  check(neither_mature == 0, "au rayon maximal et base mure, l'enceinte est toujours voulue (pas de blocage)")
end

-- 5. Lots libres : le lot du QG, les lots pris, refusés et écartés ne comptent pas
do
  local lots = {
    ["0:0"] = { i = 0, j = 0, state = "libre" },
    ["1:0"] = { i = 1, j = 0, state = "libre" },
    ["2:0"] = { i = 2, j = 0, state = "defricher" },
    ["3:0"] = { i = 3, j = 0, state = "libre", used = 4 },
    ["4:0"] = { i = 4, j = 0, state = "refuse" },
    ["5:0"] = { i = 5, j = 0, state = "gisement" },
    ["6:0"] = { i = 6, j = 0, state = "libre", bad = 2 },
    ["7:0"] = { i = 7, j = 0, state = "libre", bad = 1 },
    ["8:0"] = { i = 8, j = 0, state = "inconnu" },
  }
  check(E.free_count(lots) == 3, "free_count : 3 lots utilisables (" .. E.free_count(lots) .. ")")
  check(E.free_count({}) == 0 and E.free_count(nil) == 0, "free_count : vide")
end

-- 6. Fabrication au coffre
do
  local stock = { brick = 12, x = 3 }
  local function count(n) return stock[n] or 0 end
  check(E.crafts_possible({ { name = "brick", amount = 5 } }, count) == 2, "12 briques : 2 fabrications de 5")
  check(E.crafts_possible({ { name = "brick", amount = 5 }, { name = "x", amount = 2 } }, count) == 1, "limite par le plus rare")
  check(E.crafts_possible({ { name = "absent", amount = 1 } }, count) == 0, "ingredient absent : 0")
  check(E.crafts_possible({}, count) == 0, "recette sans ingredient : 0 (jamais illimite)")
  check(E.crafts_to_run(7, 1, 100) == 7 and E.crafts_to_run(7, 1, 3) == 3 and E.crafts_to_run(0, 1, 5) == 0, "crafts_to_run")
  check(E.crafts_to_run(5, 2, 100) == 3, "crafts_to_run : arrondi vers le haut pour une recette qui rend 2")
  check(E.affordable(10, 4, 6) and not E.affordable(10, 4, 5), "affordable : exact")
end

-- 7. Enceinte bloquée en réserve (matière absente)
do
  local T0 = 1000
  check(not E.reserve_stalled("reserve", T0, nil, T0 + E.RESERVE_TICKS - 1), "reserve_stalled : pas encore")
  check(E.reserve_stalled("reserve", T0, nil, T0 + E.RESERVE_TICKS), "reserve_stalled : a l'heure dite")
  check(not E.reserve_stalled("chantier", T0, nil, T0 + 10 * E.RESERVE_TICKS), "reserve_stalled : jamais en chantier")
  check(not E.reserve_stalled("reserve", T0, T0 + 5, T0 + 10 * E.RESERVE_TICKS), "reserve_stalled : jamais pour une enceinte finie (reparation)")
  check(not E.reserve_stalled("reserve", nil, nil, T0 + 10 * E.RESERVE_TICKS), "reserve_stalled : pas de depart connu")
end

-- 8. Lot ENCEINTE2 : tronçons, menace, segments payés sur le stock
do
  check(E.GAP == 3, "l'anneau est a 3 tuiles du treillis au plus (GAP = " .. E.GAP .. ")")
  for r = 1, 5 do
    local runs, ring = E.runs(lat, r)
    local n, seen, dup, cont = 0, {}, 0, true
    for _, run in ipairs(runs) do
      n = n + #run.walls
      for i, w in ipairs(run.walls) do
        local k = E.key(w.tx, w.ty)
        if seen[k] then dup = dup + 1 end
        seen[k] = true
        if i > 1 then
          local q = run.walls[i - 1]
          if math.abs(w.tx - q.tx) + math.abs(w.ty - q.ty) ~= 1 or w.side ~= q.side then cont = false end
        end
      end
    end
    check(n == #ring.walls and n == E.max_walls(r) and dup == 0, "r=" .. r .. " : les troncons recouvrent l'anneau une fois (" .. n .. ")")
    check(cont, "r=" .. r .. " : chaque troncon est continu et d'un seul cote")
    check(#runs == 4 * (#E.MAIN_STREETS + 1), "r=" .. r .. " : 12 troncons (3 par cote, coupes aux 2 ouvertures) : " .. #runs)
    check(E.gate_count() == ring.gates, "gate_count = ouvertures de l'anneau")
  end
  -- côté d'une menace
  check(E.side_of(lat, lat.ox, lat.oy - 50) == "n" and E.side_of(lat, lat.ox, lat.oy + 50) == "s"
    and E.side_of(lat, lat.ox - 50, lat.oy) == "o" and E.side_of(lat, lat.ox + 50, lat.oy) == "e", "side_of : 4 cotes")
  check(E.side_of(lat, lat.ox + 30, lat.oy - 40) == "n" and E.side_of(lat, lat.ox + 40, lat.oy - 30) == "e", "side_of : axe dominant")
  -- menaces connues : portée, poids
  local sectors = {
    [5] = { sp = { { x = lat.ox + 100, y = lat.oy } }, wm = { { x = lat.ox + 100, y = lat.oy + 5 } } },
    [2] = { sp = { { x = lat.ox - 200, y = lat.oy - 10 } } },
    [9] = { sp = { { x = lat.ox + E.THREAT_RANGE + 1, y = lat.oy } } },
  }
  local th = E.known_threats(sectors, lat)
  local wsum = 0
  for _, t in ipairs(th) do wsum = wsum + t.w end
  check(#th == 3 and wsum == 2 * E.W_NEST + E.W_WORM, "known_threats : 3 menaces dans la portee, la 4e (hors portee) ignoree")
  check(#E.known_threats(nil, lat) == 0 and #E.known_threats({}, lat) == 0, "known_threats : rien de connu")
  -- ordre : le côté menacé d'abord, le plus proche du nid d'abord
  local runs = E.runs(lat, 3)
  local function first_side(threats) return runs[E.run_order(runs, lat, threats)[1]].side end
  check(first_side({}) == "n", "sans menace : l'ordre fixe (nord d'abord)")
  check(first_side({ { x = lat.ox + 150, y = lat.oy + 20, w = 3 } }) == "e", "un nid a l'est : cote est d'abord")
  check(first_side({ { x = lat.ox - 150, y = lat.oy + 20, w = 3 } }) == "o", "un nid a l'ouest : cote ouest d'abord")
  check(first_side({ { x = lat.ox, y = lat.oy + 150, w = 1 }, { x = lat.ox - 150, y = lat.oy, w = 3 } }) == "o", "le cote le plus menace d'abord")
  do
    local order = E.run_order(runs, lat, { { x = lat.ox + 150, y = lat.oy + 100, w = 3 } })
    local r1 = runs[order[1]]
    check(r1.side == "e" and r1.my > lat.oy, "nid a l'est-sud : le troncon est le plus proche du nid (" .. r1.side .. ")")
    local late_east, seen_other = 0, false
    local ids, dup = {}, 0
    for _, id in ipairs(order) do
      local sd = runs[id].side
      if sd == "e" then if seen_other then late_east = late_east + 1 end else seen_other = true end
      if ids[id] then dup = dup + 1 end
      ids[id] = true
    end
    check(late_east == 0, "tous les troncons du cote menace passent avant les autres")
    check(#order == #runs and dup == 0, "l'ordre est une permutation des troncons")
  end
  -- plafond de coût : un quart du stock
  check(E.segment_cap(0) == 0 and E.segment_cap(31) == 7 and E.segment_cap(32) == 8 and E.segment_cap(10000) == E.SEG_MAX, "segment_cap : un quart, plafonne")
  check(E.segment_cap(-5) == 0, "segment_cap : stock negatif")
  -- pose complète par segments, à plusieurs plafonds : couverture exacte, aucun recouvrement, jamais au-dessus du plafond
  for _, cap in ipairs({ 8, 13, 40 }) do
    local claimed = {}
    local order = E.run_order(runs, lat, { { x = lat.ox + 150, y = lat.oy, w = 3 } })
    local total, nseg, bad, tiny, why = 0, 0, 0, 0, nil
    while true do
      local seg
      seg, why = E.next_segment(runs, order, claimed, cap)
      if not seg then break end
      nseg = nseg + 1
      if #seg.walls > cap or #seg.walls > E.SEG_MAX then bad = bad + 1 end
      if #seg.walls < E.SEG_MIN then tiny = tiny + 1 end
      for _, w in ipairs(seg.walls) do
        if claimed[E.key(w.tx, w.ty)] then bad = bad + 1 end
        if w.side ~= seg.side then bad = bad + 1 end
      end
      E.claim(claimed, seg.walls, true)
      total = total + #seg.walls
      if nseg > 1000 then break end
    end
    check(why == "complet" and total == E.max_walls(3) and bad == 0, "cap " .. cap .. " : l'anneau est pose en " .. nseg .. " segments, exactement (" .. total .. " / " .. E.max_walls(3) .. ", " .. tostring(why) .. ")")
    check(tiny <= #runs, "cap " .. cap .. " : seuls les restes de troncons sont sous SEG_MIN (" .. tiny .. ")")
    check(E.unclaimed(runs, claimed) == 0, "cap " .. cap .. " : plus rien a reserver")
  end
  -- stock trop pauvre : aucun segment (plafond sous SEG_MIN), et rien n'est réservé
  do
    local claimed = {}
    local order = E.run_order(runs, lat, {})
    local seg, why = E.next_segment(runs, order, claimed, E.SEG_MIN - 1)
    check(seg == nil and why == "stock" and next(claimed) == nil, "plafond sous SEG_MIN : on attend (stock)")
    local seg0, why0 = E.next_segment(runs, order, claimed, 0)
    check(seg0 == nil and why0 == "stock", "plafond 0 : on attend")
    -- le reste d'un tronçon plus court que SEG_MIN reste payable s'il tient dans le plafond
    local run1 = runs[order[1]]
    for i = 1, #run1.walls - 3 do claimed[E.key(run1.walls[i].tx, run1.walls[i].ty)] = true end
    local tail = E.next_segment({ run1 }, { 1 }, claimed, 3)
    check(tail and #tail.walls == 3, "reste de 3 murs : posable avec un plafond de 3")
    check(E.next_segment({ run1 }, { 1 }, claimed, 2) == nil, "reste de 3 murs : pas avec un plafond de 2")
  end
  -- les tuiles rendues (segment annulé) reviennent dans le pool, au même endroit
  do
    local claimed = {}
    local order = E.run_order(runs, lat, {})
    local s1 = E.next_segment(runs, order, claimed, 20)
    E.claim(claimed, s1.walls, true)
    local s2 = E.next_segment(runs, order, claimed, 20)
    check(s2.walls[1].tx ~= s1.walls[1].tx or s2.walls[1].ty ~= s1.walls[1].ty, "le segment suivant ne recouvre pas le premier")
    E.claim(claimed, s1.walls, nil)
    local s3 = E.next_segment(runs, order, claimed, 20)
    check(s3.walls[1].tx == s1.walls[1].tx and s3.walls[1].ty == s1.walls[1].ty and #s3.walls == #s1.walls, "segment rendu : de nouveau le premier")
    local again = E.next_segment(runs, order, {}, 20)
    check(again.walls[1].tx == s1.walls[1].tx and #again.walls == #s1.walls, "deterministe")
  end
  -- coût réel : un quart du stock au plus, par segment, sur toute la pose
  do
    local stock, spent, worst = 400, 0, 0   -- 400 murs équivalents (2 000 briques)
    local claimed = {}
    local order = E.run_order(runs, lat, {})
    for _ = 1, 60 do
      local seg = E.next_segment(runs, order, claimed, E.segment_cap(stock))
      if not seg then break end
      worst = math.max(worst, #seg.walls / stock)
      E.claim(claimed, seg.walls, true)
      stock = stock - #seg.walls
      spent = spent + #seg.walls
    end
    check(worst <= 1 / E.STOCK_DIV + 1e-9, "aucun segment ne depasse un quart du stock du moment (" .. string.format("%.3f", worst) .. ")")
    check(spent < 400, "le stock n'est jamais vide d'un coup (" .. spent .. " murs poses sur 400)")
  end
end

-- 9. Lot ENCEINTE3 : contour SERRÉ sur l'empreinte réelle (retour du DC, Azur : murs « super loin »)
do
  local az = P.lattice({ x = 339.5, y = 339.5 })              -- le QG d'Azur : (339, 339)
  -- non-régression : l'anneau d'avant (rayon 3) est inchangé, 235..442
  do
    local x0, y0, x1, y1 = E.bounds(az, 3)
    check(x0 == 235 and y0 == 235 and x1 == 442 and y1 == 442, "Azur, rayon 3 : l'anneau d'avant est toujours 235..442 (" .. x0 .. ".." .. x1 .. ")")
    local ring = E.ring(az, 3)
    check(#ring.walls == E.max_walls(3) and ring.bounds[1] == 235 and ring.bounds[4] == 442, "Azur : l'anneau d'avant, murs = formule")
    check(E.bounds(az, 3, nil, nil) == 235, "E.bounds sans bornes figees : le rayon")
  end
  local function box(i, j) return E.lot_box(az, i, j) end
  local function lots(list) local out = {} for _, ij in ipairs(list) do out[#out + 1] = box(ij[1], ij[2]) end return out end
  -- une base de 5 lots autour du QG : (0,0), (1,0), (-1,0), (0,1), (0,-1), sans lot libre ni tourelle
  local used = lots({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } })
  local tb, info = E.tight_bounds(az, used, {})
  -- empreinte : x de 339-12-28 = 299 à 339+12+28 = 379 (fin exclue), idem y ; mur à 9 tuiles libres
  check(tb[1] == 299 - E.MARGIN - 1 and tb[3] == 379 + E.MARGIN and tb[2] == 299 - E.MARGIN - 1 and tb[4] == 379 + E.MARGIN,
    "contour serre : empreinte 299..379 + marge " .. E.MARGIN .. " (" .. table.concat(tb, ",") .. ")")
  check(info.core == 4 and #info.excluded == 0, "les 4 lots voisins sont dans l'empreinte")
  check(tb[1] > 235 and tb[3] < 442, "le contour serre est strictement a l'interieur de l'anneau d'Azur")
  check(E.gates_inside(az, tb), "les ouvertures des rues principales sont dans le contour")
  -- la distance de l'empreinte au mur est exactement la marge, sur les 4 cotes
  local ring = E.ring(az, 0, { bounds = tb })
  local mn = math.huge
  for _, w in ipairs(ring.walls) do
    local dx = math.max(299 - w.tx - 1, w.tx - 379, 0) -- tuiles libres entre le bord de l'empreinte et le mur
    local dy = math.max(299 - w.ty - 1, w.ty - 379, 0)
    mn = math.min(mn, math.max(dx, dy))
  end
  check(mn == E.MARGIN, "aucun mur a moins de " .. E.MARGIN .. " tuiles libres de l'empreinte, et il y en a a exactement " .. E.MARGIN .. " (" .. mn .. ")")
  check(#ring.walls == E.max_walls(0, { bounds = tb }), "max_walls(contour serre) = murs de l'anneau (" .. #ring.walls .. " / " .. E.max_walls(0, { bounds = tb }) .. ")")
  check(ring.gates == E.gate_count(), "toujours 32 tuiles d'ouverture")
  check(#ring.walls < E.max_walls(3) / 2, "bien moins de murs que l'anneau d'avant (" .. #ring.walls .. " contre " .. E.max_walls(3) .. ")")
  -- aucun mur dans un lot de l'empreinte
  local inlot = 0
  for _, w in ipairs(ring.walls) do
    for _, r in ipairs(used) do if w.tx >= r.x0 and w.tx < r.x1 and w.ty >= r.y0 and w.ty < r.y1 then inlot = inlot + 1 end end
  end
  check(inlot == 0, "aucun mur dans un lot de l'empreinte")
  -- troncons : 12, continus
  local runs = E.runs(az, 0, { bounds = tb })
  check(#runs == 12, "contour serre : 12 troncons (" .. #runs .. ")")
  local n = 0
  for _, run in ipairs(runs) do n = n + #run.walls end
  check(n == #ring.walls, "les troncons recouvrent le contour serre une fois")

  -- lot isole : (4, 0) est a 60 tuiles de l'empreinte (hors portee), (3, 0) a 32 (dans la portee)
  local far = lots({ { 1, 0 }, { 4, 0 } })
  local t1, i1 = E.tight_bounds(az, far, {})
  check(i1.core == 1 and #i1.excluded == 1 and i1.excluded[1].x0 == box(4, 0).x0, "lot isole a 60 tuiles : exclu du contour")
  check(t1[3] == box(1, 0).x1 + E.MARGIN, "le contour ne s'etire pas vers le lot isole (x1 " .. t1[3] .. ")")
  local near = lots({ { 1, 0 }, { 3, 0 } })
  local t2, i2 = E.tight_bounds(az, near, {})
  check(i2.core == 2 and #i2.excluded == 0 and t2[3] == box(3, 0).x1 + E.MARGIN, "un lot a 32 tuiles (un lot vide entre) est dans l'empreinte")
  -- croissance de proche en proche : (1,0), (3,0) puis (5,0) forment une chaine ; (8,0) reste dehors
  local chain = lots({ { 1, 0 }, { 3, 0 }, { 5, 0 }, { 8, 0 } })
  local t3, i3 = E.tight_bounds(az, chain, {})
  check(i3.core == 3 and #i3.excluded == 1 and i3.excluded[1].x0 == box(8, 0).x0, "chaine de lots a un lot d'ecart : suivie jusqu'au bout, le plus loin dehors")
  -- tourelles : une tourelle a 14 tuiles du lot du QG est dedans, une tourelle d'avant-poste a 150 tuiles dehors
  local tur = { { x0 = 339 + 25, y0 = 338, x1 = 339 + 27, y1 = 340 }, { x0 = 339 + 150, y0 = 338, x1 = 339 + 152, y1 = 340 } }
  local t4, i4 = E.tight_bounds(az, tur, {})
  check(i4.core == 1 and #i4.excluded == 1 and t4[3] == 339 + 27 + E.MARGIN, "tourelle proche dans l'empreinte, tourelle d'avant-poste dehors")
  -- l'empreinte ne contient QUE le lot du QG si rien n'est pris : le contour reste valide
  local t5 = E.tight_bounds(az, {}, {})
  check(t5[1] == 339 - 12 - E.MARGIN - 1 and t5[3] == 339 + 12 + E.MARGIN and E.gates_inside(az, t5), "empreinte vide : le lot du QG seul, ouvertures dedans")
  -- lots libres gardes dedans : les ROOM_LOTS plus proches, departages par ecart puis par cle
  local roomlots = {}
  for _, ij in ipairs({ { 0, 2 }, { 2, 0 }, { -2, 0 }, { 0, -2 }, { 2, 2 }, { 6, 6 } }) do
    local r = box(ij[1], ij[2]); r.k = ij[1] .. ":" .. ij[2]; roomlots[#roomlots + 1] = r
  end
  local t6, i6 = E.tight_bounds(az, used, roomlots)
  check(i6.room == E.ROOM_LOTS, "les " .. E.ROOM_LOTS .. " lots libres les plus proches sont gardes (" .. i6.room .. ")")
  check(t6[3] > tb[3] or t6[4] > tb[4], "le contour s'elargit pour garder de la place")
  -- le lot libre lointain (6,6) n'est pas gardé
  check(t6[3] < box(6, 6).x0 and t6[4] < box(6, 6).y0, "un lot libre lointain n'etire pas le contour")
  local no_room = E.tight_bounds(az, used, { box(9, 9) })
  check(no_room[1] == tb[1] and no_room[3] == tb[3], "un lot libre hors de portee n'est pas garde")
  -- un lot libre garde peut rapprocher un lot isole : celui-ci rejoint alors l'empreinte (le mur ne le coupe jamais)
  do
    local base = lots({ { 1, 0 } })
    local isolated = lots({ { 4, 0 } })                               -- 60 tuiles de l'empreinte : dehors
    local r2 = box(2, 1); r2.k = "2:1"                                -- libre, a 4 tuiles de l'empreinte : garde, et rapproche (4,0)
    local _, ii = E.tight_bounds(az, { base[1], isolated[1] }, { r2 })
    check(ii.core == 2 and #ii.excluded == 0, "le lot libre garde rapproche le lot isole : il rejoint l'empreinte")
  end
  -- determinisme et independance de l'ordre
  local mixed = lots({ { 3, 0 }, { 0, 1 }, { -1, 0 }, { 1, 0 }, { 5, 0 }, { 9, 9 }, { 0, -1 } })
  local ordered = lots({ { 9, 9 }, { 5, 0 }, { 3, 0 }, { 1, 0 }, { 0, 1 }, { 0, -1 }, { -1, 0 } })
  local ta, ia = E.tight_bounds(az, mixed, {})
  local tc, ic = E.tight_bounds(az, ordered, {})
  check(ta[1] == tc[1] and ta[2] == tc[2] and ta[3] == tc[3] and ta[4] == tc[4] and ia.core == ic.core, "l'ordre des lots ne change pas le contour")
  local ta2 = E.tight_bounds(az, mixed, {})
  check(ta2[1] == ta[1] and ta2[3] == ta[3], "meme entree, meme contour")
  -- propriete : sur 300 empreintes pseudo-aleatoires, un rectangle exclu est toujours hors du contour (ni coupe, ni dedans),
  -- tout rectangle garde est dedans, les ouvertures sont dedans
  do
    local seed = 12345
    local function rnd(m) seed = (seed * 1103515245 + 12345) % 2147483648; return math.floor(seed / 65536) % m end
    local bad_cut, bad_in, bad_gate, total_excl = 0, 0, 0, 0
    for _ = 1, 300 do
      local rects, rooms = {}, {}
      for _ = 1, 3 + rnd(10) do rects[#rects + 1] = box(rnd(15) - 7, rnd(15) - 7) end
      for _ = 1, rnd(5) do local r = box(rnd(15) - 7, rnd(15) - 7); r.k = tostring(rnd(1000)); rooms[#rooms + 1] = r end
      local tbb, inf = E.tight_bounds(az, rects, rooms)
      if not E.gates_inside(az, tbb) then bad_gate = bad_gate + 1 end
      local is_ex = {}
      for _, r in ipairs(inf.excluded) do
        is_ex[r] = true
        total_excl = total_excl + 1
        -- un rectangle exclu ne recouvre ni n'enferme aucune tuile de la boite du mur
        if r.x1 > tbb[1] and r.x0 <= tbb[3] and r.y1 > tbb[2] and r.y0 <= tbb[4] then bad_cut = bad_cut + 1 end
      end
      for _, r in ipairs(rects) do
        if not is_ex[r] and not E.inside(tbb, r) then bad_in = bad_in + 1 end
      end
    end
    check(bad_cut == 0 and bad_in == 0 and bad_gate == 0 and total_excl > 0,
      "300 empreintes au hasard : aucun lot exclu coupe ou enferme (" .. bad_cut .. "), aucun lot garde dehors (" .. bad_in .. "), ouvertures dedans (" .. bad_gate .. "), exclus vus " .. total_excl)
  end
  -- E.inside : le mur lui-meme n'est pas "dedans"
  check(E.inside(tb, { x0 = tb[1] + 1, y0 = tb[2] + 1, x1 = tb[3], y1 = tb[4] }) and not E.inside(tb, { x0 = tb[1], y0 = tb[2] + 1, x1 = tb[3], y1 = tb[4] }),
    "E.inside : l'interieur exclut la tuile du mur")
  -- relecture : le contour ne depasse JAMAIS l'anneau du rayon (marge 9 > 7 tuiles de l'anneau quand l'empreinte touche le dernier rang)
  do
    local edge = lots({ { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 }, { 1, 0 }, { 2, 0 }, { -1, 0 }, { -2, 0 }, { 0, 1 }, { 0, 2 }, { 0, -1 }, { 0, -2 } })
    local ox0, oy0, ox1, oy1 = E.bounds(az, 3)
    local wide = E.tight_bounds(az, edge, {})
    check(wide[3] > ox1 and wide[1] < ox0, "sans clamp, l'empreinte au dernier rang depasse l'anneau du rayon (" .. wide[1] .. ".." .. wide[3] .. " contre " .. ox0 .. ".." .. ox1 .. ")")
    local cl = E.tight_bounds(az, edge, {}, { clamp = { ox0, oy0, ox1, oy1 } })
    check(cl[1] == ox0 and cl[2] == oy0 and cl[3] == ox1 and cl[4] == oy1, "avec clamp : exactement l'anneau du rayon")
    local tur = { { x0 = 440, y0 = 339, x1 = 443, y1 = 342 } } -- tourelle au-dela du treillis, a moins de 36 tuiles du lot (3, 0)
    local ct = E.tight_bounds(az, { box(3, 0), tur[1] }, {}, { clamp = { ox0, oy0, ox1, oy1 } })
    check(ct[3] <= ox1 and ct[4] <= oy1 and ct[1] >= ox0 and ct[2] >= oy0, "avec clamp : une tourelle hors treillis ne tire pas le mur plus loin")
    check(E.max_walls(3, { bounds = cl }) == E.max_walls(3), "avec clamp : jamais plus de murs que l'ancien anneau")
    -- un contour interieur n'est pas modifie par le clamp
    local t_in = E.tight_bounds(az, used, {}, { clamp = { ox0, oy0, ox1, oy1 } })
    check(t_in[1] == tb[1] and t_in[2] == tb[2] and t_in[3] == tb[3] and t_in[4] == tb[4], "avec clamp : un contour interieur est inchange")
  end
end

-- 10. Lot ENCEINTE3 (lot A) : le segment démarre au bout du tronçon le plus proche du QG / de la menace, pas dans un coin
do
  local az = P.lattice({ x = 339.5, y = 339.5 })
  local runs = E.runs(az, 3)
  local order = E.run_order(runs, az, {})
  local refs = E.run_refs(runs, az, {})
  -- sans menace : la reference de chaque troncon est le QG
  local ok_qg = true
  for _, run in ipairs(runs) do if math.abs(refs[run.id].x - 339.5) > 1e-9 or math.abs(refs[run.id].y - 339.5) > 1e-9 then ok_qg = false end end
  check(ok_qg, "run_refs sans menace : le QG")
  -- premier tronçon (nord, de l'angle ouest a la 1re ouverture) : le segment de 12 murs commence a la tuile de l'OUVERTURE, pas au coin
  local r1 = runs[order[1]]
  local first, last = r1.walls[1], r1.walls[#r1.walls]
  local seg = E.next_segment(runs, order, {}, 12, refs)
  local d_first = (first.x - 339.5) ^ 2 + (first.y - 339.5) ^ 2
  local d_last = (last.x - 339.5) ^ 2 + (last.y - 339.5) ^ 2
  local want = d_last < d_first and last or first
  check(seg.walls[1].tx == want.tx and seg.walls[1].ty == want.ty and #seg.walls == 12,
    "sans menace : le segment demarre au bout du troncon le plus proche du QG (" .. seg.walls[1].tx .. "," .. seg.walls[1].ty .. ")")
  check(d_last < d_first and (seg.walls[1].tx ~= first.tx), "le premier troncon (angle ouest -> ouverture) : on ne commence pas par le coin")
  local old = E.next_segment(runs, order, {}, 12)
  check(old.walls[1].tx == first.tx and old.walls[1].ty == first.ty, "sans refs : l'ancien comportement (debut du troncon)")
  -- les segments suivants du même tronçon se suivent : chacun touche le précédent, de l'ouverture vers le coin
  do
    local claimed, prev = {}, nil
    local ok_adj, n = true, 0
    while true do
      local s2 = E.next_segment(runs, order, claimed, 12, refs)
      if not s2 or s2.run ~= order[1] then break end
      if prev then
        local a = prev.walls[#prev.walls]
        local b = s2.walls[1]
        if math.abs(a.tx - b.tx) + math.abs(a.ty - b.ty) ~= 1 then ok_adj = false end
      end
      E.claim(claimed, s2.walls, true)
      prev = s2
      n = n + 1
      if n > 50 then break end
    end
    check(ok_adj and n >= 2, "les segments d'un troncon se suivent bout a bout depuis l'ouverture (" .. n .. " segments)")
  end
  -- menace connue : le segment demarre au bout le plus proche de la menace
  for _, th in ipairs({ { x = 339 + 150, y = 339 - 100 }, { x = 339 - 160, y = 339 + 120 }, { x = 339 + 20, y = 339 + 200 }, { x = 339 - 30, y = 339 - 230 } }) do
    local threats = { { x = th.x, y = th.y, w = 3 } }
    local o2 = E.run_order(runs, az, threats)
    local rf = E.run_refs(runs, az, threats)
    local r = runs[o2[1]]
    local s3 = E.next_segment(runs, o2, {}, 10, rf)
    local ref = rf[r.id]
    check(ref.x == th.x and ref.y == th.y, "run_refs : la menace du cote (" .. th.x .. "," .. th.y .. ")")
    local da = (r.walls[1].x - th.x) ^ 2 + (r.walls[1].y - th.y) ^ 2
    local dz = (r.walls[#r.walls].x - th.x) ^ 2 + (r.walls[#r.walls].y - th.y) ^ 2
    local want2 = dz < da and r.walls[#r.walls] or r.walls[1]
    check(s3.walls[1].tx == want2.tx and s3.walls[1].ty == want2.ty and s3.run == r.id,
      "menace (" .. th.x .. "," .. th.y .. ") : le segment demarre au bout du troncon le plus proche d'elle")
  end
  -- couverture exacte conservee avec refs, a plusieurs plafonds
  for _, cap in ipairs({ 8, 13, 40 }) do
    local claimed, total, dup, nseg = {}, 0, 0, 0
    local th = { { x = 339 + 150, y = 339, w = 3 } }
    local o3, rf = E.run_order(runs, az, th), E.run_refs(runs, az, th)
    while true do
      local sg = E.next_segment(runs, o3, claimed, cap, rf)
      if not sg then break end
      for _, w in ipairs(sg.walls) do if claimed[E.key(w.tx, w.ty)] then dup = dup + 1 end end
      E.claim(claimed, sg.walls, true)
      total = total + #sg.walls
      nseg = nseg + 1
      if nseg > 1000 then break end
    end
    check(total == E.max_walls(3) and dup == 0, "refs, plafond " .. cap .. " : l'anneau est pose exactement (" .. total .. " / " .. E.max_walls(3) .. ")")
  end
  -- un bloc libre au milieu d'un troncon (segment rendu) : le segment prend le bout le plus proche de la reference
  do
    local r = runs[order[1]]
    local claimed = {}
    for i = 1, #r.walls do if i < 5 or i > #r.walls - 4 then claimed[E.key(r.walls[i].tx, r.walls[i].ty)] = true end end
    local mid_first, mid_last = r.walls[5], r.walls[#r.walls - 4]
    local sgw = E.next_segment(runs, order, claimed, 8, { [order[1]] = { x = mid_last.x + 300, y = mid_last.y } })
    check(sgw.run == order[1] and sgw.walls[1].tx == mid_last.tx and #sgw.walls == 8, "bloc central : demarre par le bout le plus proche de la reference")
    local sgw2 = E.next_segment(runs, order, claimed, 8, { [order[1]] = { x = mid_first.x - 300, y = mid_first.y } })
    check(sgw2.walls[1].tx == mid_first.tx, "bloc central : et par l'autre bout si la reference est de l'autre cote")
  end
  -- deux blocs libres dans le meme troncon : le plus proche de la reference d'abord
  do
    local r = runs[order[1]]
    local claimed = {}
    for i = 10, 14 do claimed[E.key(r.walls[i].tx, r.walls[i].ty)] = true end
    local ref = { [order[1]] = { x = r.walls[#r.walls].x + 200, y = r.walls[#r.walls].y } }
    local sg = E.next_segment(runs, order, claimed, 8, ref)
    check(sg.walls[1].tx == r.walls[#r.walls].tx, "deux blocs libres : le bloc le plus proche de la reference d'abord")
  end
end

print(string.format("[ENCEINTE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
