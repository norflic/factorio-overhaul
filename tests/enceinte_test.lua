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

print(string.format("[ENCEINTE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
