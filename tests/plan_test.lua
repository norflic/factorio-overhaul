--[[
  Tests hors jeu du plan directeur des équipes de PNJ (lot IA1-d, shared/team/plan.lua, pur).
  Usage, depuis la racine du mod :   lua5.2 tests/plan_test.lua

  Vérifie, sur des cartes SYNTHÉTIQUES (eau, falaises, forêt, falaises en réseau) :
    1. treillis : lots de 24, rues de 4, carrefours, tronçons, lot d'une position ;
    2. classement des lots et des tronçons depuis un relevé (raisons) ;
    3. marche par les rues : parcours sur les carrefours ouverts, détour autour des tronçons fermés, chemin en
       Manhattan (chaque pas suit une rue) ; aucun chemin quand tout est fermé ;
    4. points d'appui : toute tuile d'un lot a un point d'appui dans une rue praticable à 16 tuiles au plus ;
    5. placement d'un gabarit : fonderie dans un lot libre, foreuses sur le minerai (couverture), refus sans minerai ;
    6. têtes d'alimentation et quais : bras qui prennent au coffre et déposent sur le tapis, voie lointaine, aucune
       pièce sur le module ; arrivées latérales ;
    7. tapis entre modules (A*) : contourne un obstacle, chaque tuile tournée vers la suivante, déterministe ;
    8. chaînes de poteaux : portée respectée, tuiles libres ;
    9. chevauchements détectés ; ordre de pose.
]]

package.path = "./?.lua;" .. package.path

local P = require("shared.team.plan")
local M = require("shared.team.modules")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

---------------------------------------------------------------------------------------------------
-- Carte synthétique : tuiles marquées (eau, falaise, arbre) ; relevés calculés comme le ferait le moteur.
---------------------------------------------------------------------------------------------------
local function new_map() return { water = {}, cliff = {}, tree = {}, ore = {}, own = {} } end
local function mark(t, x0, y0, x1, y1, v) for y = y0, y1 do for x = x0, x1 do t[P.tkey(x, y)] = v or true end end end
local function survey(map, x0, y0, x1, y1)
  local s = { tiles = (x1 - x0) * (y1 - y0), water = 0, cliffs = 0, trees = 0, rocks = 0, foreign = 0, own = 0, res = {} }
  for y = y0, y1 - 1 do
    for x = x0, x1 - 1 do
      local k = P.tkey(x, y)
      if map.water[k] then s.water = s.water + 1 end
      if map.cliff[k] then s.cliffs = s.cliffs + 1 end
      if map.tree[k] then s.trees = s.trees + 1 end
      if map.own[k] then s.own = s.own + 1 end
      local r = map.ore[k]
      if r then s.res[r] = (s.res[r] or 0) + 1 end
    end
  end
  return s
end
local lat = P.lattice({ x = 0.5, y = 0.5 })

local function seg_states(map, r)
  local st = {}
  for _, key in ipairs(P.segs_within(r)) do
    local x0, y0, x1, y1 = P.seg_rect(lat, key)
    st[key] = P.classify_segment(survey(map, x0, y0, x1, y1))
  end
  return st
end

---------------------------------------------------------------------------------------------------
section("1. Treillis")
do
  local x0, y0, x1, y1 = P.lot_rect(lat, 0, 0)
  check(x0 == -12 and y0 == -12 and x1 == 12 and y1 == 12, "lot (0,0) = [-12, 12)")
  local a0 = P.lot_rect(lat, 1, 0)
  check(a0 - x1 == P.STREET, "rue de 4 entre deux lots")
  local n = P.node_pos(lat, 0, 0)
  check(n.x == 14 and n.y == 14, "carrefour (0,0) au milieu du croisement (14, 14)")
  check(P.in_street(lat, 12, 0) and P.in_street(lat, 15, 0) and not P.in_street(lat, 11, 0) and not P.in_street(lat, 16, 0),
    "tuiles 12 à 15 = rue")
  local i, j = P.lot_of(lat, 20, -30)
  check(i == 1 and j == -1, "lot de (20, -30) = (1, -1)")
  check(P.lot_of(lat, 13, 0) == nil, "une position de rue n'a pas de lot")
  local sx0, sy0, sx1, sy1 = P.seg_rect(lat, "h:0:0")
  check(sx0 == 12 and sy0 == 12 and sx1 == 44 and sy1 == 16, "tronçon h:0:0 = croisements compris")
  local sides = P.lot_sides(0, 0)
  check(sides[1] == "h:-1:-1" and sides[2] == "h:-1:0" and sides[3] == "v:-1:-1" and sides[4] == "v:0:-1", "rues qui bordent un lot")
  local lots = P.lots_within(2)
  check(#lots == 25 and lots[1].i == 0 and lots[1].j == 0 and lots[2].d == 1 and lots[25].d == 2, "lots par couronne")
  check(#P.segs_within(1) == 2 * 4 * 3, "tronçons d'un carré de rayon 1 : 24")
end

---------------------------------------------------------------------------------------------------
section("2. Classement")
do
  local s0 = { tiles = 576, water = 0, cliffs = 0, trees = 0, rocks = 0, foreign = 0, own = 0, res = {} }
  local function with(t) local o = {}; for k, v in pairs(s0) do o[k] = v end; for k, v in pairs(t) do o[k] = v end; return o end
  local st, why = P.classify_lot(s0)
  check(st == "libre" and why == nil, "lot vide : libre")
  st, why = P.classify_lot(with({ cliffs = 1 }))
  check(st == "refuse" and why == "falaise", "falaise : refusé (falaise)")
  st, why = P.classify_lot(with({ water = 300 }))
  check(st == "refuse" and why == "eau", "plus de la moitié d'eau : refusé (eau)")
  st = P.classify_lot(with({ water = 40 }))
  check(st == "rive", "un peu d'eau : rive")
  st, why = P.classify_lot(with({ foreign = 2 }))
  check(st == "refuse" and why == "conteste", "bâtiments d'une autre force : contesté")
  st, why = P.classify_lot(with({ nests = 1 }))
  check(st == "refuse" and why == "nid", "nid : refusé (nid)")
  st, why = P.classify_lot(with({ own = 3 }))
  check(st == "occupe", "nos bâtiments : occupé")
  st, why = P.classify_lot(with({ res = { ["iron-ore"] = 200, coal = 30 }, trees = 5 }))
  check(st == "gisement" and why == "iron-ore", "gisement : ressource majoritaire")
  st = P.classify_lot(with({ res = { ["iron-ore"] = 5 } }))
  check(st == "libre", "quelques tuiles de minerai : libre")
  st = P.classify_lot(with({ trees = 12 }))
  check(st == "defricher", "arbres : à défricher")
  local ss, sw = P.classify_segment(with({ trees = 3 }))
  check(ss == "encombre" and sw == nil, "tronçon boisé : encombré")
  ss, sw = P.classify_segment(with({ water = 1 }))
  check(ss == "ferme" and sw == "eau", "tronçon avec de l'eau : fermé (eau)")
  ss, sw = P.classify_segment(with({ cliffs = 1, trees = 4 }))
  check(ss == "ferme" and sw == "falaise", "tronçon avec falaise : fermé (falaise)")
  check(P.classify_segment(s0) == "ouvert", "tronçon vide : ouvert")
end

---------------------------------------------------------------------------------------------------
section("3. Marche par les rues")
do
  -- plaine : tout est ouvert
  local map = new_map()
  local st = seg_states(map, 3)
  local function ok(k) return st[k] == "ouvert" end
  local wp, len = P.street_path(lat, { x = 0, y = 0 }, { x = 70, y = 42 }, ok, 3)
  check(wp ~= nil, "plaine : un chemin")
  local manhattan = true
  for i = 2, #wp do
    if math.abs(wp[i].x - wp[i - 1].x) > 1e-9 and math.abs(wp[i].y - wp[i - 1].y) > 1e-9 then manhattan = false end
  end
  check(manhattan, "chaque pas suit un axe (Manhattan)")
  check(wp[#wp].x == 70 and wp[#wp].y == 42, "arrivée au but")
  check(len and len < 200, "longueur raisonnable (" .. tostring(len) .. ")")
  -- un mur d'eau au milieu des rues verticales x = 14 (j de -3 à 2), sauf une brèche en j = -3
  local m2 = new_map()
  mark(m2.water, 12, -40, 15, 80)
  local st2 = seg_states(m2, 3)
  local closed, encombre = 0, 0
  for _, k in ipairs(P.segs_within(3)) do
    if st2[k] == "ferme" then closed = closed + 1 end
  end
  check(closed >= 4, "mur d'eau : tronçons fermés (" .. closed .. ")")
  local function ok2(k) return st2[k] == "ouvert" end
  local wp2 = P.street_path(lat, { x = 0, y = 0 }, { x = 42, y = 0 }, ok2, 3)
  -- la rue verticale x = 14 est fermée de y = -40 à 80 : l'est n'est joignable qu'en contournant par le nord
  local crosses_water = false
  if wp2 then
    for i = 2, #wp2 do
      local a, b = wp2[i - 1], wp2[i]
      local lo, hi = math.min(a.x, b.x), math.max(a.x, b.x)
      if lo < 14 and hi > 14 and math.min(a.y, b.y) >= -40 and math.max(a.y, b.y) <= 80 then crosses_water = true end
    end
  end
  check(wp2 == nil or not crosses_water, "aucun chemin ne traverse l'eau")
  -- tout fermé : pas de chemin
  local none = P.street_path(lat, { x = 0, y = 0 }, { x = 70, y = 42 }, function() return false end, 3)
  check(none == nil, "rues toutes fermées : pas de chemin (le PNJ prendra le pathfinder)")
  -- détour : on ferme h:0:0 seulement ; le chemin de (14,14) à (42,14) passe par un autre carrefour
  local function ok3(k) return k ~= "h:0:0" end
  local nodes = P.route_nodes({ i = 0, j = 0 }, { i = 1, j = 0 }, ok3, 3)
  check(nodes and #nodes == 4, "tronçon fermé : détour par 3 tronçons (" .. (nodes and #nodes or 0) .. " carrefours)")
  -- forêt : tronçons encombrés (défrichage), jamais « ouverts »
  local m3 = new_map()
  for y = -150, 150, 3 do for x = -150, 150, 3 do m3.tree[P.tkey(x, y)] = true end end
  local st3 = seg_states(m3, 2)
  local n_enc = 0
  for _, k in ipairs(P.segs_within(2)) do if st3[k] == "encombre" then n_enc = n_enc + 1 end end
  check(n_enc == #P.segs_within(2), "forêt dense : tous les tronçons encombrés (" .. n_enc .. ")")
  -- falaises en réseau : une falaise par tronçon vertical sur deux
  local m4 = new_map()
  for _, k in ipairs(P.segs_within(3)) do
    local kind, i, j = P.parse_seg(k)
    if kind == "v" and (i + j) % 2 == 0 then
      local x0, y0 = P.seg_rect(lat, k)
      m4.cliff[P.tkey(x0 + 1, y0 + 10)] = true
    end
  end
  local st4 = seg_states(m4, 3)
  local function ok4(k) return st4[k] == "ouvert" end
  local wp4 = P.street_path(lat, { x = 14, y = 14 }, { x = 14, y = 70 }, ok4, 3)
  check(wp4 ~= nil, "falaises en réseau : un détour existe")
  local n4 = P.route_nodes({ i = 0, j = 0 }, { i = 0, j = 2 }, ok4, 3)
  local through = n4 == nil
  for k = 2, #(n4 or {}) do
    local a, b = n4[k - 1], n4[k]
    local key
    if a.i ~= b.i then key = P.seg_key("h", math.min(a.i, b.i), a.j) else key = P.seg_key("v", a.i, math.min(a.j, b.j)) end
    if st4[key] ~= "ouvert" then through = true end
  end
  check(not through and #n4 > 3, "détour sans tronçon fermé (" .. (n4 and #n4 or 0) .. " carrefours au lieu de 3)")
end

---------------------------------------------------------------------------------------------------
section("4. Points d'appui")
do
  local all_ok, far = true, 0
  for _, l in ipairs(P.lots_within(1)) do
    local x0, y0, x1, y1 = P.lot_rect(lat, l.i, l.j)
    for y = y0, y1 - 1 do
      for x = x0, x1 - 1 do
        local a = P.anchor_for(lat, x + 0.5, y + 0.5, function() return true end)
        if not a then all_ok = false else
          local dx, dy = a.x - x - 0.5, a.y - y - 0.5
          if dx * dx + dy * dy > 16 * 16 + 1e-9 then far = far + 1 end
          if not P.in_street(lat, math.floor(a.x), math.floor(a.y)) then all_ok = false end
        end
      end
    end
  end
  check(all_ok, "chaque tuile des 9 lots centraux a un point d'appui dans une rue")
  check(far == 0, "point d'appui à 16 tuiles au plus (" .. far .. " au-delà)")
  -- rue la plus proche fermée : l'autre axe
  local a = P.anchor_for(lat, 5.5, 10.5, function(k) return k:sub(1, 1) == "v" end)
  check(a and a.seg:sub(1, 1) == "v", "rue horizontale fermée : appui dans la rue verticale")
  local b = P.anchor_for(lat, 0.5, 0.5, function() return false end)
  check(b == nil, "aucune rue praticable : pas d'appui")
end

---------------------------------------------------------------------------------------------------
section("5. Placement d'un gabarit")
do
  local g = M.GEN.smelter("stone-furnace", "iron-ore", 4)
  local x0, y0, x1, y1 = P.lot_rect(lat, 1, 0)
  local fit = P.fit(g, { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }, { toward = { x = 0, y = 0 } })
  check(fit ~= nil, "fonderie de 8 fours : placée dans un lot libre")
  if fit then
    local inst = M.instantiate(g, fit.k, fit.ox, fit.oy)
    local inside = true
    for _, t in ipairs(P.port_room(inst)) do
      if t[1] < x0 or t[1] >= x1 or t[2] < y0 or t[2] >= y1 then inside = false end
    end
    check(inside, "place des têtes d'alimentation et des quais dans le lot")
    check(fit.ox >= x0 + 1 and fit.ox + fit.w <= x1 - 1, "marge d'une tuile aux rues")
  end
  -- foreuses : minerai dans la moitié est du lot (1,0)
  local d = M.GEN.drills("iron-ore", 2)
  local ore = {}
  for y = y0, y1 - 1 do for x = x0 + 8, x1 - 1 do ore[P.tkey(x, y)] = true end end
  local fd = P.fit(d, { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }, { ore = ore })
  check(fd ~= nil and fd.cover >= P.DRILL_COVER, "foreuses : couverture du minerai " .. (fd and string.format("%.2f", fd.cover) or "nil"))
  if fd then check(fd.ox >= x0 + 7, "foreuses posées sur la moitié minerai (x = " .. fd.ox .. ")") end
  local fn, why = P.fit(d, { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }, { ore = {} })
  check(fn == nil and why == "minerai", "sans minerai : refus (minerai)")
  -- eau dans le lot : free() refuse ces tuiles
  local water = {}
  for y = y0, y1 - 1 do for x = x0, x0 + 15 do water[P.tkey(x, y)] = true end end
  local fw = P.fit(g, { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }, { free = function(x, y) return not water[P.tkey(x, y)] end })
  check(fw == nil, "fonderie : refusée quand il ne reste que 8 colonnes sèches")
  -- gabarit trop grand
  local big = M.GEN.smelter("stone-furnace", "iron-ore", 12)
  local fb, wb = P.fit(big, { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }, {})
  check(fb == nil and wb == "trop grand", "gabarit plus grand que le lot : refus (trop grand)")
end

---------------------------------------------------------------------------------------------------
section("6. Têtes d'alimentation et quais")
do
  local g = M.GEN.smelter("stone-furnace", "iron-ore", 4)
  local inst = M.instantiate(g, 0, 30, 0)
  local ports = P.belt_ports(inst)
  local pin
  for _, p in ipairs(ports) do if p.io == "in" then pin = p end end
  check(pin and pin.dir == 4 and pin.lanes[1] == "iron-ore" and pin.lanes[2] == "coal", "port d'entrée de la fonderie : vers le sud, [minerai, charbon]")
  local fd = P.feeder(pin, { "tapis", "quai" })
  check(#fd.arrivals == 1 and #fd.chests == 1, "minerai par tapis, charbon par quai")
  local belts, ins, chest = 0, nil, nil
  for _, e in ipairs(fd.entities) do
    if e.name == "transport-belt" then belts = belts + 1 end
    if e.role == "quai-bras" then ins = e end
    if e.role == "quai" then chest = e end
  end
  check(belts == 3, "3 tuiles derrière le port (bout mort compris)")
  -- le bras prend au coffre (centre + DV[dir]) et dépose sur le tapis (centre − DV[dir])
  local v = P.DV[ins.dir]
  check(math.abs(ins.x + v[1] - chest.x) < 1e-9 and math.abs(ins.y + v[2] - chest.y) < 1e-9, "le bras du quai prend au coffre")
  local dx, dy = ins.x - v[1], ins.y - v[2]
  local on_belt = false
  for _, e in ipairs(fd.entities) do if e.name == "transport-belt" and math.abs(e.x - dx) < 1e-9 and math.abs(e.y - dy) < 1e-9 then on_belt = true end end
  check(on_belt, "le bras du quai dépose sur le tapis")
  -- voie lointaine : le charbon (voie 2 = droite du sens sud = ouest) ; le bras doit être à l'EST du tapis
  check(ins.x > pin.x + 0.5, "bras du charbon à l'est (dépose sur la voie ouest = voie 2)")
  -- arrivée du minerai : à l'est (voie 1 = gauche du sens sud = est), tournée vers l'ouest, 2 tuiles derrière
  local a = fd.arrivals[1]
  check(a.lane == 1 and a.x == pin.x + 1 and a.y == pin.y - 2 and a.dir == 6, "arrivée latérale du minerai à l'est, vers l'ouest")
  -- aucune pièce de la tête sur le module ; aucune entre elles
  local all = {}
  for _, e in ipairs(inst.entities) do all[#all + 1] = { name = e.name, x = e.position.x, y = e.position.y, dir = e.direction } end
  for _, e in ipairs(fd.entities) do all[#all + 1] = e end
  check(#P.overlaps(all) == 0, "tête d'alimentation sans chevauchement avec le module")
  -- quais de sortie
  local nq = 0
  for _, p in ipairs(ports) do
    if p.io == "out" then
      local q = P.out_quai(p)
      local bv = P.DV[q[1].dir]
      check(math.abs(q[1].x + bv[1] - (p.x + 0.5)) < 1e-9 and math.abs(q[1].y + bv[2] - (p.y + 0.5)) < 1e-9, "bras de sortie : prend au bout du tapis")
      check(math.abs(q[1].x - bv[1] - q[2].x) < 1e-9 and math.abs(q[1].y - bv[2] - q[2].y) < 1e-9, "bras de sortie : dépose dans le coffre")
      for _, e in ipairs(q) do all[#all + 1] = e end
      nq = nq + 1
    end
  end
  check(nq == 2 and #P.overlaps(all) == 0, "deux quais de sortie, sans chevauchement")
  -- deux voies par quai (centrale : charbon, charbon)
  local fq = P.feeder({ x = 0, y = 0, dir = 6, lanes = { "coal", "coal" } }, { "quai", "quai" })
  check(#fq.chests == 2 and #fq.arrivals == 0, "centrale : deux quais de charbon")
  check(#P.overlaps(fq.entities) == 0, "têtes à deux quais : sans chevauchement")
end

---------------------------------------------------------------------------------------------------
section("7. Tapis entre modules (A*)")
do
  local block = {}
  mark(block, 5, -5, 5, 5) -- mur vertical
  local function cost(x, y) if block[P.tkey(x, y)] then return nil end return 1 end
  local tiles, n = P.belt_route({ x = 0, y = 0 }, { x = 10, y = 0 }, 2, { x0 = -10, y0 = -10, x1 = 20, y1 = 10 }, cost)
  check(tiles ~= nil, "contourne un mur (" .. tostring(n) .. " nœuds)")
  if tiles then
    local ok = true
    for i = 1, #tiles - 1 do
      local v = P.DV[tiles[i].dir]
      if tiles[i].x + v[1] ~= tiles[i + 1].x or tiles[i].y + v[2] ~= tiles[i + 1].y then ok = false end
      if block[P.tkey(tiles[i].x, tiles[i].y)] then ok = false end
    end
    check(ok, "chaque tuile tournée vers la suivante, aucune sur le mur")
    check(tiles[#tiles].dir == 2, "dernière tuile dans la direction demandée")
    check(#tiles == 1 + 10 + 2 * 6, "tracé le plus court (" .. #tiles .. " tuiles)")
    local again = P.belt_route({ x = 0, y = 0 }, { x = 10, y = 0 }, 2, { x0 = -10, y0 = -10, x1 = 20, y1 = 10 }, cost)
    local same = #again == #tiles
    for i = 1, math.min(#again, #tiles) do if again[i].x ~= tiles[i].x or again[i].y ~= tiles[i].y then same = false end end
    check(same, "déterministe : même tracé")
  end
  local cut = P.belt_route({ x = 0, y = 0 }, { x = 10, y = 0 }, 2, { x0 = -10, y0 = -5, x1 = 20, y1 = 5 }, cost)
  check(cut == nil, "mur sur toute la hauteur des bornes : aucun tracé")
  -- rue plus chère : le tracé la traverse sans la longer
  local function cost2(x, y) return P.in_street(lat, x, y) and P.STREET_COST or 1 end
  local t2 = P.belt_route({ x = 5, y = 0 }, { x = 20, y = 0 }, 2, { x0 = 0, y0 = -10, x1 = 25, y1 = 10 }, cost2)
  local in_street = 0
  for _, t in ipairs(t2 or {}) do if P.in_street(lat, t.x, t.y) then in_street = in_street + 1 end end
  check(t2 and in_street == 4, "traverse la rue (4 tuiles) sans la longer (" .. in_street .. ")")
end

---------------------------------------------------------------------------------------------------
section("8. Poteaux")
do
  local block = {}
  mark(block, 10, -2, 12, 2)
  local function free(x, y) return not block[P.tkey(math.floor(x), math.floor(y))] end
  local chain = P.pole_chain({ x = 0.5, y = 0.5 }, { x = 40.5, y = 0.5 }, 9, false, free)
  check(chain ~= nil and #chain >= 4, "chaîne de poteaux moyens sur 40 tuiles (" .. (chain and #chain or 0) .. ")")
  if chain then
    local prev, ok = { x = 0.5, y = 0.5 }, true
    for _, c in ipairs(chain) do
      local dx, dy = c.x - prev.x, c.y - prev.y
      if dx * dx + dy * dy > 81 + 1e-9 then ok = false end
      if not free(c.x, c.y) then ok = false end
      prev = c
    end
    local dx, dy = 40.5 - prev.x, 0.5 - prev.y
    check(ok and dx * dx + dy * dy <= 81 + 1e-9, "chaque fil à 9 tuiles au plus, poteaux sur des tuiles libres")
  end
  local big = P.pole_chain({ x = 0, y = 0 }, { x = 56, y = 0 }, 30, true, function() return true end)
  check(big and #big == 1, "grands poteaux : un intermédiaire sur 56 tuiles")
  local np = P.node_pole(lat, 0, 0, true)
  check(np.x == 13 and np.y == 13, "grand poteau de carrefour dans le quart nord-ouest du croisement")
end

---------------------------------------------------------------------------------------------------
section("9. Chevauchements et ordre de pose")
do
  local list = {
    { name = "stone-furnace", x = 1, y = 1 }, { name = "inserter", x = 1.5, y = 2.5, dir = 0 },
    { name = "transport-belt", x = 0.5, y = 0.5, dir = 2 },
  }
  local bad = P.overlaps(list)
  check(#bad == 1 and bad[1][1] == 1 and bad[1][2] == 3, "tapis sous un four : chevauchement détecté")
  local order = P.sort_build({
    { name = "transport-belt", x = 0.5, y = 0.5 }, { name = "inserter", x = 0.5, y = 0.5 },
    { name = "medium-electric-pole", x = 3.5, y = 0.5 }, { name = "stone-furnace", x = 5, y = 5 }, { name = "iron-chest", x = 9.5, y = 0.5 },
  })
  check(order[1].name == "medium-electric-pole" and order[2].name == "stone-furnace" and order[3].name == "inserter"
    and order[4].name == "iron-chest" and order[5].name == "transport-belt", "ordre : poteaux, machines, bras, coffres, tapis")
end

print(string.format("[IA1-D PLAN] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
