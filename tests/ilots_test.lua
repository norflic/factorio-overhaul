--[[
  Tests hors jeu du lot ILOTS-MURS : shared/team/ilots.lua (règle pure) et son branchement au planificateur permanent
  (shared/team/planner.lua, view.ilot, poste FACULTATIF « ilot »). Usage, depuis la racine du mod :   lua5.2 tests/ilots_test.lua
  Vérifie : regroupement des lots isolés (voisins, transitivité, valeur comptée une fois par projet, ordre indifférent), îlot
  important, priorité (attaqué d'abord), mur collé à l'emprise sur la rue (jamais dans le lot, jamais en travers d'une rue sauf
  ouverture), ouvertures (PNJ, rue intérieure, tuiles réservées), segments par la machinerie de l'enceinte, tourelles (1 ou 2,
  emplacements dans l'emprise, plafond), « ressources d'abord » au planificateur (hors du coût de la défense, rien en production
  d'abord ni sous les planchers doublés) ; MUTANTS.
]]
package.path = "./?.lua;" .. package.path
local I = require("shared.team.ilots")
local E = require("shared.team.enceinte")
local P = require("shared.team.plan")
local T = require("shared.team.config")
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")
local S = require("shared.team.scale")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local lat = P.lattice({ x = 339.5, y = 339.5 })
local function lot(i, j, pid, value, plant)
  local x0, y0, x1, y1 = P.lot_rect(lat, i, j)
  return { k = P.lot_key(i, j), x0 = x0, y0 = y0, x1 = x1, y1 = y1, pid = pid, value = value, plant = plant }
end
local hq = { x = lat.ox + 0.5, y = lat.oy + 0.5 }

---------------------------------------------------------------------------------------------------
section("1. Regroupement des îlots")
---------------------------------------------------------------------------------------------------
do
  -- (5,0) et (6,0) voisins (une rue) ; (6,1) voisin de (6,0) : transitivité ; (5,-3) seul ; (5,0) et (6,0) du même projet 7
  local cands = { lot(5, 0, 7, 12), lot(6, 0, 7, 12), lot(6, 1, 8, 3), lot(5, -3, 9, 4) }
  local cl = I.clusters(cands)
  check(#cl == 2, "deux îlots (" .. #cl .. ")")
  local big = cl[1].key == "5:0+6:0+6:1" and cl[1] or cl[2]
  check(big.key == "5:0+6:0+6:1", "clé triée des lots du grand îlot (" .. tostring(big.key) .. ")")
  check(big.value == 15, "valeur : le projet 7 compte une fois (12), le projet 8 (3) : 15 (" .. tostring(big.value) .. ")")
  local x0, y0 = P.lot_rect(lat, 5, 0)
  local _, _, x1, y1 = P.lot_rect(lat, 6, 1)
  check(big.box.x0 == x0 and big.box.y0 == y0 and big.box.x1 == x1 and big.box.y1 == y1, "emprise = union des lots")
  -- ordre indifférent
  local rev = I.clusters({ cands[4], cands[3], cands[2], cands[1] })
  local keys_a, keys_b = {}, {}
  for _, c in ipairs(cl) do keys_a[#keys_a + 1] = c.key .. "/" .. c.value end
  for _, c in ipairs(rev) do keys_b[#keys_b + 1] = c.key .. "/" .. c.value end
  table.sort(keys_a); table.sort(keys_b)
  check(table.concat(keys_a, ",") == table.concat(keys_b, ","), "mêmes groupes et valeurs quel que soit l'ordre des candidats")
  -- deux lots à deux pas (un lot vide entre eux : écart 32) : séparés
  local cl2 = I.clusters({ lot(5, 0, 1, 10), lot(7, 0, 2, 10) })
  check(#cl2 == 2, "un lot vide entre deux lots : deux îlots")
  check(#I.clusters({}) == 0 and #I.clusters(nil) == 0, "aucun candidat : aucun îlot")
  check(I.value(10, false) == 10 and I.value(3, true) == 3 + I.PLANT_BONUS and I.value(nil, nil) == 0, "valeur : pièces + bonus de centrale")
  local c3 = I.clusters({ lot(5, 0, 1, I.value(2, true), true) })
  check(c3[1].plant == true and c3[1].value >= I.MIN_VALUE, "une centrale de 2 pièces est importante")
end

---------------------------------------------------------------------------------------------------
section("2. Dehors du contour, attaque, ordre, choix")
---------------------------------------------------------------------------------------------------
do
  local bounds = { lat.ox - 50, lat.oy - 50, lat.ox + 50, lat.oy + 50 } -- tuiles du mur de l'enceinte
  check(not I.outside(bounds, lot(0, 0)), "le lot du QG n'est pas dehors")
  check(not I.outside(bounds, lot(2, 0)), "un lot coupé par le mur n'est pas un îlot (son anneau croiserait l'enceinte)")
  check(I.outside(bounds, lot(3, 0)), "un lot entièrement dehors (écart >= 3) est un îlot")
  check(not I.outside(nil, lot(3, 0)), "sans contour serré : aucun îlot")
  -- mur de l'îlot jamais sur le mur de l'enceinte : écart 3 => 2 tuiles libres
  local r = { x0 = lat.ox + 50 + 3 + 1, y0 = lat.oy, x1 = lat.ox + 80, y1 = lat.oy + 10 }
  check(I.outside(bounds, r) and (r.x0 - 1) - (lat.ox + 50) - 1 == 2, "écart minimal : deux tuiles libres entre les deux murs")
  local box = { x0 = 100, y0 = 100, x1 = 124, y1 = 124 }
  local s, at = I.attack(box, { { x = 130, y = 110, score = 300 }, { x = 200, y = 200, score = 900 }, { x = 90, y = 110, score = 100 } })
  check(s == 400 and at and math.abs(at.x - (130 * 300 + 90 * 100) / 400) < 1e-9, "attaque : cellules à moins de 16 tuiles, centre pondéré")
  local s0, at0 = I.attack(box, {})
  check(s0 == 0 and at0 == nil, "aucune attaque : 0")
  -- ordre : attaqué d'abord, puis valeur, puis distance
  local rows = {
    { key = "a", box = { x0 = 500, y0 = 0, x1 = 524, y1 = 24 }, value = 50, attack = 0 },
    { key = "b", box = { x0 = 900, y0 = 0, x1 = 924, y1 = 24 }, value = 9, attack = I.ATTACK_MIN },
    { key = "c", box = { x0 = 400, y0 = 0, x1 = 424, y1 = 24 }, value = 50, attack = 0 },
    { key = "d", box = { x0 = 400, y0 = 0, x1 = 424, y1 = 24 }, value = 60, attack = I.ATTACK_MIN - 1 },
  }
  I.sort(rows, { x = 0, y = 0 })
  check(rows[1].key == "b" and rows[2].key == "d" and rows[3].key == "c" and rows[4].key == "a",
    "ordre : attaqué, puis attaque la plus forte, puis valeur, puis distance (" .. rows[1].key .. rows[2].key .. rows[3].key .. rows[4].key .. ")")
  -- choix d'un nouvel îlot
  local cl = I.clusters({ lot(5, 0, 1, 30), lot(-5, 0, 2, 12), lot(0, 6, 3, 2) })
  local pick, why, adm = I.pick_new(cl, {}, {}, hq)
  check(pick and pick.key == "5:0" and #adm == 2, "le plus précieux d'abord ; le petit (2 pièces) n'est pas admissible")
  local cells = { { x = lat.ox - 5 * 28, y = lat.oy, score = 400 } }
  local pick2 = I.pick_new(cl, {}, cells, hq)
  check(pick2 and pick2.key == "-5:0" and pick2.attack == 400 and pick2.at ~= nil, "un îlot attaqué passe avant un plus précieux")
  local pick3, why3 = I.pick_new(cl, { { key = "5:0", box = cl[1].box }, { key = "-5:0", box = cl[2].box } }, {}, hq)
  check(pick3 == nil and why3 == "petits", "les deux importants déjà retenus : il ne reste qu'un petit")
  local full = {}
  for n = 1, I.MAX do full[n] = { key = "x" .. n, box = { x0 = 0, y0 = 0, x1 = 1, y1 = 1 } } end
  local pick4, why4 = I.pick_new(cl, full, {}, hq)
  check(pick4 == nil and why4 == "plafond", "plafond de " .. I.MAX .. " îlots")
  -- un lot collé à un îlot retenu ne démarre pas un autre îlot
  local near = I.clusters({ lot(6, 0, 4, 30) })
  local pick5, why5 = I.pick_new(near, { { key = "5:0", box = cl[1].box } }, {}, hq)
  check(pick5 == nil and why5 == "voisins", "lot voisin d'un îlot retenu : pas de second mur dans la même rue")
  -- relecture : deux lots dehors en diagonale autour du coin nord-est du contour forment un îlot dont l'EMPRISE couvre le coin
  local corner = I.clusters({ lot(2, -3, 1, 20), lot(3, -2, 2, 20) })
  check(#corner == 1 and I.outside(bounds, lot(2, -3)) and I.outside(bounds, lot(3, -2)) and not I.outside(bounds, corner[1].box),
    "coin : deux lots dehors, un seul îlot, emprise qui croise le contour")
  local pick6, why6 = I.pick_new(corner, {}, {}, hq, nil, bounds)
  check(pick6 == nil and why6 == "contour", "coin : îlot écarté (son anneau croiserait l'enceinte) (" .. tostring(why6) .. ")")
  local pick7 = I.pick_new(cl, {}, {}, hq, nil, bounds)
  check(pick7 and pick7.key == "5:0", "contour donné : un îlot entièrement dehors reste choisi")
end

---------------------------------------------------------------------------------------------------
section("3. Mur de l'îlot")
---------------------------------------------------------------------------------------------------
local function ring_checks(box, label)
  local ring = I.ring(box, lat)
  local set, dup = {}, 0
  local on_street = 0
  for _, w in ipairs(ring.walls) do
    local k = w.tx .. ":" .. w.ty
    if set[k] then dup = dup + 1 end
    set[k] = true
    -- jamais sur une rue : une rue qui porte un de nos bâtiments serait « fermée » au relevé suivant du plan directeur
    if I.on_street(w.tx, lat.ox) or I.on_street(w.ty, lat.oy) then on_street = on_street + 1 end
  end
  local W, H = box.x1 - box.x0, box.y1 - box.y0
  check(dup == 0, label .. " : aucune tuile en double")
  check(on_street == 0, label .. " : aucun mur sur une rue (" .. on_street .. ")")
  check(#ring.walls + ring.gates == 2 * W + 2 * H - 4, label .. " : murs + ouvertures = périmètre (" .. #ring.walls .. " + " .. ring.gates .. ")")
  for _, w in ipairs(ring.walls) do
    local on_edge = w.tx == box.x0 or w.tx == box.x1 - 1 or w.ty == box.y0 or w.ty == box.y1 - 1
    local inside = w.tx >= box.x0 and w.tx < box.x1 and w.ty >= box.y0 and w.ty < box.y1
    if not (on_edge and inside) then check(false, label .. " : mur hors du bord de l'emprise " .. w.tx .. "," .. w.ty) break end
  end
  return ring, set
end
do
  local x0, y0, x1, y1 = P.lot_rect(lat, 5, 0)
  local box = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  local ring, set = ring_checks(box, "un lot")
  check(ring.gates == 4 * I.GATE, "un lot : une ouverture de " .. I.GATE .. " tuiles au milieu de chaque côté (" .. ring.gates .. ")")
  -- la rue qui borde le lot reste entièrement libre
  check(I.on_street(x0 - 1, lat.ox) and I.on_street(x1, lat.ox) and I.on_street(y0 - 1, lat.oy) and not set[(x0 - 1) .. ":" .. y0],
    "le mur est sur le bord du lot, la rue qui le borde reste libre")
  local mid = math.floor((x0 + x1) / 2)
  check(not set[mid .. ":" .. y0] and not set[(mid - 1) .. ":" .. y0] and set[(mid - 2) .. ":" .. y0] and set[(mid + 1) .. ":" .. y0],
    "ouverture des PNJ au milieu du côté nord (2 tuiles)")
  check(set[x0 .. ":" .. y0] and set[(x1 - 1) .. ":" .. (y1 - 1)], "coins murés")
  -- tuiles réservées (tapis, poteau) : laissées ouvertes, comptées à part
  local r2 = I.ring(box, lat, { skip = function(tx, ty) if ty == y0 and tx == x0 + 3 then return "reserve" end return nil end })
  check(#r2.walls == #ring.walls - 1 and r2.skipped.reserve == 1, "une tuile réservée reste ouverte (entrée de l'îlot jamais coupée)")
  -- deux lots voisins : la rue intérieure est ouverte là où l'anneau passe dessus
  local _, _, x1b, y1b = P.lot_rect(lat, 6, 0)
  local box2 = { x0 = x0, y0 = y0, x1 = x1b, y1 = y1b }
  local ring2, set2 = ring_checks(box2, "deux lots voisins")
  local open = true
  for tx = x1, x1 + 3 do if set2[tx .. ":" .. y0] or set2[tx .. ":" .. (y1b - 1)] then open = false end end
  check(open, "deux lots voisins : la rue entre eux est ouverte au nord et au sud (4 tuiles)")
  check(set2[(x1 - 1) .. ":" .. y0] and set2[(x1 + 4) .. ":" .. y0], "deux lots voisins : murs de part et d'autre de la rue")
  check(ring2.gates == 2 * 4 + 2 * I.GATE, "deux lots : rue intérieure (nord, sud ; l'ouverture des PNJ y tombe) et PNJ (ouest, est) (" .. ring2.gates .. ")")
  -- un bloc de 2 x 2 lots : la rue horizontale aussi
  local _, _, x1c, y1c = P.lot_rect(lat, 6, 1)
  ring_checks({ x0 = x0, y0 = y0, x1 = x1c, y1 = y1c }, "bloc de 2 x 2 lots")
  -- sans treillis (emprise quelconque) : pas d'ouverture de rue, seulement celles des PNJ
  local r4 = I.ring({ x0 = 0, y0 = 0, x1 = 10, y1 = 6 })
  check(r4.gates == 4 * I.GATE and #r4.walls == 2 * 10 + 2 * 6 - 4 - 4 * I.GATE, "emprise hors treillis : seulement les ouvertures des PNJ")
  check(#I.ring(box, lat, { gate = 0 }).walls == 2 * 24 + 2 * 24 - 4, "sans ouverture des PNJ : l'anneau entier (un lot ne porte aucune rue)")
end

---------------------------------------------------------------------------------------------------
section("4. Segments : la machinerie de l'enceinte")
---------------------------------------------------------------------------------------------------
do
  local x0, y0, x1, y1 = P.lot_rect(lat, 5, 0) -- à l'est du QG
  local box = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  local ring = I.ring(box, lat)
  local runs = E.split_runs(ring)
  local total = 0
  for _, r in ipairs(runs) do total = total + #r.walls end
  check(total == #ring.walls and #runs >= 8, "tronçons : tous les murs, coupés aux ouvertures et aux coins (" .. #runs .. ")")
  -- sans attaque : le côté à l'opposé du QG (l'est) d'abord
  local ref = I.ref_point(box, hq, nil)
  check(ref.x > x1, "point de référence : à l'opposé du QG")
  local order, refs = I.run_order(runs, ref)
  local claimed = {}
  local seg = E.next_segment(runs, order, claimed, 30, refs)
  check(seg and seg.side == "e", "premier segment : le côté tourné vers l'extérieur (" .. tostring(seg and seg.side) .. ")")
  check(seg and #seg.walls <= 30, "plafond du segment respecté")
  -- vers une attaque au nord
  local cx = math.floor((x0 + x1) / 2)
  local _, at = I.attack(box, { { x = cx, y = y0 - 10, score = 500 } })
  local o2, r2 = I.run_order(runs, I.ref_point(box, hq, at))
  local seg2 = E.next_segment(runs, o2, {}, 30, r2)
  check(seg2 and seg2.side == "n", "attaque au nord : le côté nord d'abord (" .. tostring(seg2 and seg2.side) .. ")")
  -- tout réserver : complet ; stock pauvre : aucun segment
  local s3, why3 = E.next_segment(runs, order, claimed, 2, refs)
  check(s3 == nil and why3 == "stock", "un quart du stock sous le minimum : aucun segment (« les ressources d'abord »)")
  local n, guard = 0, 0
  while guard < 100 do
    guard = guard + 1
    local s = E.next_segment(runs, order, claimed, 40, refs)
    if not s then break end
    E.claim(claimed, s.walls, true)
    n = n + #s.walls
  end
  local _, why4 = E.next_segment(runs, order, claimed, 40, refs)
  check(n == #ring.walls and why4 == "complet", "tous les segments posés : complet (" .. n .. " murs)")
  -- E.runs inchangé par la factorisation (E.split_runs)
  local runs_e, ring_e = E.runs(lat, 3)
  local tot_e = 0
  for _, r in ipairs(runs_e) do tot_e = tot_e + #r.walls end
  check(ring_e and tot_e == #ring_e.walls, "E.runs rend toujours (tronçons, anneau)")
end

---------------------------------------------------------------------------------------------------
section("5. Tourelles")
---------------------------------------------------------------------------------------------------
do
  check(I.want(0) == I.TURRETS and I.want(I.ATTACK_MIN) == I.TURRETS_ATTACKED and I.TURRETS == 1 and I.TURRETS_ATTACKED == 2,
    "une tourelle, deux si l'îlot a été attaqué (« une ou 2 tourelle »)")
  local box = { x0 = 100, y0 = 100, x1 = 124, y1 = 124 }
  check(I.guards(box, { { x = 110, y = 110 }, { x = 127, y = 100 }, { x = 129, y = 100 } }) == 2, "garde : dans l'emprise ou à moins de 4 tuiles")
  local sites = I.sites(box, { x = 200, y = 112 })
  check(#sites == 8, "8 emplacements")
  local inside = true
  for _, s in ipairs(sites) do if not (s.x > box.x0 and s.x < box.x1 and s.y > box.y0 and s.y < box.y1) then inside = false end end
  check(inside, "emplacements dans l'emprise (le mur ne s'interpose pas)")
  check(sites[1].x > 112, "le premier emplacement est du côté de la menace")
  check(I.accepts(box, 102, 110) and I.accepts(box, 122, 122) and not I.accepts(box, 101, 110) and not I.accepts(box, 126, 110),
    "pose acceptée seulement si la tourelle entière est en dedans du mur (jamais sur la rue ni sur le mur)")
  local isl = {
    { key = "calme", box = box, attack = 0, value = 40 },
    { key = "attaque", box = { x0 = 300, y0 = 100, x1 = 324, y1 = 124 }, attack = 500, at = { x = 330, y = 110 }, value = 10 },
  }
  local plan = I.plan_turrets(isl, {}, 0, { x = 0, y = 0 })
  check(plan.pick and plan.pick.key == "attaque" and plan.pick.missing == 2 and plan.pick.want == 2, "l'îlot attaqué d'abord, 2 tourelles")
  check(plan.pick and plan.pick.pos.x == 312 and #plan.pick.sites == 8 and plan.pick.box.x0 == 300, "la tâche porte centre, emplacements, emprise")
  local plan2 = I.plan_turrets(isl, { { x = 310, y = 110 }, { x = 312, y = 112 } }, 2, { x = 0, y = 0 })
  check(plan2.pick and plan2.pick.key == "calme" and plan2.pick.missing == 1, "l'îlot attaqué gardé : l'îlot calme reçoit 1 tourelle")
  local plan3 = I.plan_turrets(isl, {}, I.TEAM_MAX - 1, { x = 0, y = 0 })
  check(plan3.pick and plan3.pick.missing == 1, "plafond d'équipe : la commande est bornée par les places restantes")
  local plan4 = I.plan_turrets(isl, {}, I.TEAM_MAX, { x = 0, y = 0 })
  check(plan4.pick == nil and plan4.rows[1].skip == "plafond", "plafond d'équipe atteint : rien")
  isl[2].rest = true
  local plan5 = I.plan_turrets(isl, {}, 0, { x = 0, y = 0 })
  check(plan5.pick and plan5.pick.key == "calme", "îlot au repos (pose à zéro) : le suivant")
  local fi, fc = I.floors(T.defend_iron_floor, T.defend_copper_floor)
  check(fi == 2 * T.defend_iron_floor and fc == 2 * T.defend_copper_floor, "planchers doublés (« ressources d'abord »)")
end

---------------------------------------------------------------------------------------------------
section("6. Planificateur : poste facultatif « ilot »")
---------------------------------------------------------------------------------------------------
local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)
local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true },
    deferred = {}, stock = {}, incoming = {}, outposts = {}, pending = {}, sites = {}, smelters = 2,
    smelters_pending = 0, smelter_task = false, smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0,
    turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 8, workers_max = 30, workers_idle = 0,
    threatened = false, open = {}, workers_wanted = 30, no_research = true, ladder = T.player_ladder,
    hq_turrets = T.defend_hq, defend_first = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function ilot_view(over)
  local box = { x0 = 500, y0 = 0, x1 = 524, y1 = 24 }
  local fi, fc = I.floors(T.defend_iron_floor, T.defend_copper_floor)
  local v = { pick = { key = "5:0", want = 2, have = 0, missing = 2, sites = I.sites(box, nil), pos = { x = 512, y = 12 }, box = box },
    busy = false, floor_i = fi, floor_cu = fc }
  for k, x in pairs(over or {}) do v[k] = x end
  return v
end
local function ilot_task(plan)
  for _, t in ipairs(plan.tasks) do if t.kind == "fortify" and t.outpost == "ilot" then return t end end
  return nil
end
local function ilot_row(plan)
  for _, d in ipairs(plan.defend and plan.defend.posts or {}) do if d.id == "ilot" then return d end end
  return nil
end
local turret_name = T.turret
local rich = { ["iron-plate"] = 2000, ["copper-plate"] = 500, [turret_name] = 6, [T.turret_ammo] = 200, coal = 100, stone = 100 }
do
  local p1 = Planner.plan(view({ stock = rich, ilot = ilot_view() }), book)
  local t1 = ilot_task(p1)
  check(t1 ~= nil, "îlot sans tourelle, tourelles au stock : tâche fortify « ilot »")
  check(t1 and t1.ilot == "5:0" and t1.box and t1.box.x0 == 500 and #t1.sites == 8 and t1.pos.x == 512, "la tâche porte l'îlot, son emprise, ses emplacements")
  check(t1 and t1.items[1][1] == turret_name and t1.items[1][2] == 2, "2 tourelles prises au stock")
  -- hors du coût de la défense : le mode de priorité est le même avec ou sans l'îlot
  local base = Planner.plan(view({ stock = { ["iron-plate"] = 400, ["copper-plate"] = 100 } }), book)
  local with = Planner.plan(view({ stock = { ["iron-plate"] = 400, ["copper-plate"] = 100 }, ilot = ilot_view() }), book)
  check(base.priorite and with.priorite and base.priorite.mode == with.priorite.mode and base.priorite.defense_cost == with.priorite.defense_cost,
    "l'îlot n'entre pas dans le coût de la défense (" .. tostring(base.priorite and base.priorite.defense_cost) .. " = " .. tostring(with.priorite and with.priorite.defense_cost) .. ")")
  -- sous les planchers doublés : rien, et pas de fabrication
  local poor = Planner.plan(view({ stock = { ["iron-plate"] = T.defend_iron_floor + 40, ["copper-plate"] = 2 * T.defend_copper_floor + 40 }, ilot = ilot_view() }), book)
  local row = ilot_row(poor)
  check(ilot_task(poor) == nil and row and row.why == "ressources", "fer sous le plancher doublé : rien (« les ressources d'abord ») (" .. tostring(row and row.why) .. ")")
  check(row and row.raw == nil, "attente de l'îlot : aucune matière demandée")
  -- assez riche pour fabriquer au-dessus des planchers doublés : fabrication lancée
  local ok = Planner.plan(view({ stock = { ["iron-plate"] = 1200, ["copper-plate"] = 400 }, ilot = ilot_view() }), book)
  local row2 = ilot_row(ok)
  check(row2 and (row2.why == "fabrication" or row2.why == "tache_creee"), "fer au-dessus des planchers doublés : fabrication (" .. tostring(row2 and row2.why) .. ")")
  check(row2 and row2.floor_i == 2 * T.defend_iron_floor, "le journal [FO-DEFENSE] porte le plancher doublé")
  -- tâche déjà ouverte : pas de doublon
  local p3 = Planner.plan(view({ stock = rich, ilot = ilot_view({ busy = true }) }), book)
  check(ilot_task(p3) == nil, "tâche déjà prise : pas de doublon")
  local p4 = Planner.plan(view({ stock = rich, ilot = ilot_view(), open = { ["fortify:ilot"] = true } }), book)
  check(ilot_task(p4) == nil, "clé déjà ouverte au tableau : pas de doublon")
  local p5 = Planner.plan(view({ stock = rich, ilot = { busy = false } }), book)
  check(ilot_task(p5) == nil and ilot_row(p5) == nil, "rien à garder (pick nil) : aucun poste")
  -- sans « défendre d'abord » : aucun poste de défense, l'îlot non plus
  local p6 = Planner.plan(view({ stock = rich, ilot = ilot_view(), defend_first = false }), book)
  check(ilot_task(p6) == nil, "sans défendre d'abord : rien")
  -- équipe décimée : rien pour l'îlot
  local p7 = Planner.plan(view({ stock = rich, ilot = ilot_view(), workers = 2, recover_floor = 6 }), book)
  check(ilot_task(p7) == nil, "équipe décimée : les recrues d'abord, rien pour l'îlot")
  -- le QG passe avant l'îlot : QG sans ses tourelles et juste de quoi en payer une partie
  local p8 = Planner.plan(view({ stock = { [turret_name] = 2, [T.turret_ammo] = 40 }, hq_turrets = 0, ilot = ilot_view() }), book)
  local hq_t = nil
  for _, t in ipairs(p8.tasks) do if t.kind == "fortify" and t.outpost == "hq" then hq_t = t end end
  check(hq_t ~= nil and ilot_task(p8) == nil, "deux tourelles au stock, QG nu : le QG les prend, l'îlot attend")
end

---------------------------------------------------------------------------------------------------
section("7. Mutants (la règle les refuse)")
---------------------------------------------------------------------------------------------------
local function mutant(name, apply, undo, probe)
  apply()
  local ok, caught = pcall(probe)
  undo()
  check(ok and caught, "mutant « " .. name .. " » détecté")
end
do
  local x0, y0, x1, y1 = P.lot_rect(lat, 5, 0)
  local _, _, x1b, y1b = P.lot_rect(lat, 6, 0)
  local box2 = { x0 = x0, y0 = y0, x1 = x1b, y1 = y1b }
  -- 1. ouverture de rue supprimée : l'anneau (calculé avec le mutant actif) passe sur la rue intérieure (mesurée avec la vraie règle)
  local real_on = I.on_street
  local function probe_street()
    local saved = I.on_street
    local ring = I.ring(box2, lat) -- avec le mutant actif
    I.on_street = real_on
    local bad = false
    for _, w in ipairs(ring.walls) do if I.on_street(w.tx, lat.ox) or I.on_street(w.ty, lat.oy) then bad = true end end
    I.on_street = saved
    return bad
  end
  mutant("rue intérieure murée", function() I.on_street = function() return false end end, function() I.on_street = real_on end, probe_street)
  -- 2. tri sans la priorité de l'attaque
  local real_min = I.ATTACK_MIN
  mutant("attaque ignorée", function() I.ATTACK_MIN = math.huge end, function() I.ATTACK_MIN = real_min end, function()
    local cl = I.clusters({ lot(5, 0, 1, 30), lot(-5, 0, 2, 12) })
    local pick = I.pick_new(cl, {}, { { x = lat.ox - 5 * 28, y = lat.oy, score = 400 } }, hq)
    local plan = I.plan_turrets({ { key = "a", box = cl[1].box, attack = 400 } }, {}, 0, hq)
    -- le mutant ne passe plus l'attaqué devant OU ne lui donne qu'une tourelle : détecté
    return (pick and pick.key ~= "-5:0") or plan.pick.missing ~= 2
  end)
  -- 3. valeur comptée à chaque lot (projet sur deux lots compté deux fois)
  local real_cl = I.clusters
  mutant("valeur comptée deux fois", function()
    I.clusters = function(c, j) local out = real_cl(c, j); for _, x in ipairs(out) do x.value = x.value * #x.lots end return out end
  end, function() I.clusters = real_cl end, function()
    local out = I.clusters({ lot(5, 0, 7, 12), lot(6, 0, 7, 12) })
    return out[1].value ~= 12
  end)
  -- 4. mur posé sur la rue qui borde le lot (anneau décalé d'une tuile vers l'extérieur) : la rue serait fermée au relevé suivant
  local real_ring = I.ring
  -- (la vraie règle ouvre toute rangée posée sur une rue : l'anneau décalé n'a plus un seul mur)
  check(#real_ring({ x0 = x0 - 1, y0 = y0 - 1, x1 = x1 + 1, y1 = y1 + 1 }, lat).walls == 0, "anneau décalé sur la rue : entièrement ouvert")
  mutant("mur sur la rue", function()
    I.ring = function(b, l, o) return real_ring({ x0 = b.x0 - 1, y0 = b.y0 - 1, x1 = b.x1 + 1, y1 = b.y1 + 1 }, nil, o) end
  end, function() I.ring = real_ring end, function()
    local b = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
    for _, w in ipairs(I.ring(b, lat).walls) do if real_on(w.tx, lat.ox) or real_on(w.ty, lat.oy) then return true end end
    return false
  end)
  -- 5. tuile réservée murée quand même (entrée coupée)
  mutant("entrée coupée", function()
    I.ring = function(b, l, o) local o2 = {}; for k, v in pairs(o or {}) do o2[k] = v end; o2.skip = nil; return real_ring(b, l, o2) end
  end, function() I.ring = real_ring end, function()
    local b = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
    local r = I.ring(b, lat, { skip = function(tx, ty) if ty == y0 and tx == x0 + 3 then return "reserve" end end })
    for _, w in ipairs(r.walls) do if w.tx == x0 + 3 and w.ty == y0 then return true end end
    return false
  end)
  -- 6. lot coupé par l'enceinte pris pour un îlot
  local real_out = I.outside
  mutant("lot coupé par l'enceinte", function() I.outside = function(bd) return bd ~= nil end end, function() I.outside = real_out end, function()
    return I.outside({ lat.ox - 50, lat.oy - 50, lat.ox + 50, lat.oy + 50 }, lot(2, 0))
  end)
end

print(string.format("[ILOTS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
