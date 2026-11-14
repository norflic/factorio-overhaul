--[[
  Lot RB-1 CHAÎNE (31/10) : banc hors jeu des robots (shared/content/robots.lua, shared/robots/modele.lua, et les règles de
  forme des fichiers de script/robots/ et prototypes/robots.lua).
    §1 données : un robot (Trotte-Vapeur, âge 3), prix contre la valeur visée (200 MU, monnaies de shared/content/epochs.lua),
       ingrédients d'au plus 100 (un bras ne livre pas plus, RB0-1), DPS = dégâts × 60 / cadence, noms, relecture des noms d'unité,
       propriétaires = joueur + factions du mod ;
    §2 plafond en points (12 + 6 × âge ; réglage), kit retiré seulement s'il reste de la place et si « maintenir N » n'est pas atteint ;
    §3 registre des unités vivantes : points et effectifs par force, ajout et retrait idempotents, liste triée, balayage, cohérence,
       déterminisme (mêmes opérations, même état, quel que soit l'ordre d'arrivée) ;
    §4 file d'une usine (premier robot sous sa cible) ; §5 géométrie de la sortie et du ralliement ; ordres ;
    §6 forme des fichiers : aucun pairs dans une décision, aucun require dans une fonction (F24), `global` jamais nommé, aucun
       hasard ni horloge, aucun nom d'objet du lot dans shared/ai3 ni script/ai3 (le cerveau lira les prototypes, RB-3) ;
    §7 traductions FR et EN de tout ce que le lot déclare (clés localisées lues dans les sources) ;
    §8 mutants : chaque règle faussée est vue par au moins un contrôle.
  Usage : lua5.2 tests/robots_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local RO_SRC = read("shared/content/robots.lua")
local MO_SRC = read("shared/robots/modele.lua")

--- Charge les deux modules depuis un texte (mutants) ; rend (Ro, Mo) ou (nil, erreur).
local function load_all(ro_src, mo_src)
  local f1, e1 = load(ro_src, "=robots", "t")
  if not f1 then return nil, e1 end
  local ok1, Ro = pcall(f1)
  if not ok1 then return nil, Ro end
  local saved = package.loaded["shared.content.robots"]
  package.loaded["shared.content.robots"] = Ro
  local f2, e2 = load(mo_src, "=modele", "t")
  if not f2 then package.loaded["shared.content.robots"] = saved return nil, e2 end
  local ok2, Mo = pcall(f2)
  package.loaded["shared.content.robots"] = saved
  if not ok2 then return nil, Mo end
  return Ro, Mo
end

local X = require("shared.content.epochs")
local F = require("shared.faction.config")
local Lv = require("shared.levels.config")
local Cp = require("shared.content.compute")
local Pt = require("shared.content.robot_parts")

local function strip(src) return (src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")) end

local function suite(Ro, Mo)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end

  -- §1 Données : 12 robots, 4 usines.
  -- lot s43-robots : les 12 du plan d'abord, puis 3 variantes (r.variant = parent ; tests/s43_robots_test.lua les contrôle)
  local nplan, nvar = 0, 0
  for i, r in ipairs(Ro.ROBOTS) do
    if r.variant then nvar = nvar + 1 elseif i == nplan + 1 then nplan = nplan + 1 end
  end
  check(nplan == 12 and nvar == 3 and #Ro.ROBOTS == 15, "§1 douze robots du plan, puis trois variantes", tostring(#Ro.ROBOTS))
  local want_ids = { "steam-trotter", "scalehide", "coiler", "needle", "bellwether", "chamfer", "trowel", "finback", "levite", "toroid", "heliast", "crowned" }
  local want_ages = { 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }
  local ids_ok, ages_ok = true, true
  for i = 1, 12 do
    local r = Ro.ROBOTS[i]
    if r.id ~= want_ids[i] then ids_ok = false end
    if r.age ~= want_ages[i] then ages_ok = false end
  end
  check(ids_ok and ages_ok, "§1 les 12 robots du plan, dans l'ordre des âges 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15")
  local tr = Ro.robot("steam-trotter")
  check(tr and tr.age == 3 and tr.class == "P" and tr.points == 1, "§1 Trotte-Vapeur : âge 3, petit, 1 point")
  check(tr and tr.range == 18 and tr.speed == 0.14 and tr.hp0 == 900 and tr.dmg0 == 50 and tr.shot.cooldown == 30, "§1 Trotte-Vapeur : forme du plan (900 PV, 50 par tir), portée 18, vitesse 0,14")
  check(tr and tr.dps == tr.shot.damage * 60 / tr.shot.cooldown, "§1 DPS = dégâts × 60 / cadence")
  local value = {}
  for _, c in ipairs(X.currencies) do value[c.item] = c.value end
  for e = 2, 12 do local m = Lv.epoch_materials[e]; if m then value[m.item] = m.value end end
  local memo = {}
  local function mu_of(item)
    if memo[item] then return memo[item] end
    local v
    if Pt.present(item) then
      local rr = Pt.recipe(item)
      local s = 0
      for _, g in ipairs(rr.ingredients) do s = s + mu_of(g[1]) * g[2] end
      v = s / rr.results[1][2]
    elseif value[item] then v = value[item]
    elseif Ro.MU_ASSUMED[item] then v = Ro.MU_ASSUMED[item]
    else v = Cp.mu(item) end
    memo[item] = v
    return v
  end
  local function cost(list) local s = 0 for _, g in ipairs(list) do s = s + mu_of(g[1]) * g[2] end return s end
  check(cost(tr.ingredients) == tr.mu and tr.mu == 200, "§1 coût du Trotte-Vapeur en MU = 200 (10 moteurs × 9 + 22 aciers × 5)")
  local worst = 0
  for _, r in ipairs(Ro.ROBOTS) do
    local c = r.segment and (cost(r.segment.ingredients) * Ro.SEGMENTS + cost(r.final or {})) or cost(r.ingredients)
    local ratio = c / r.mu
    check(ratio >= 0.8 and ratio <= 1.2, "§1 coût de " .. r.id .. " à ±20 % du but : " .. string.format("%.0f contre %d MU", c, r.mu))
    local lists = { r.ingredients }
    if r.segment then lists[#lists + 1] = r.segment.ingredients end
    for _, l in ipairs(lists) do
      for _, g in ipairs(l) do worst = math.max(worst, g[2]) end
    end
    -- un ingrédient n'est cité qu'une fois par recette (le moteur refuse un doublon)
    for _, l in ipairs(lists) do
      local seen, dup = {}, false
      for _, g in ipairs(l) do if seen[g[1]] then dup = true end seen[g[1]] = true end
      check(not dup, "§1 " .. r.id .. " : aucun ingrédient en double dans une recette")
    end
  end
  for _, w in ipairs(Ro.FACTORIES) do for _, g in ipairs(w.ingredients) do worst = math.max(worst, g[2]) end end
  check(worst <= 100, "§1 aucun ingrédient au-delà de 100 (un bras ne livre pas plus, RB0-1)", tostring(worst))
  check(#tr.ingredients == 2, "§1 Trotte-Vapeur : deux solides, un coffre et un bras par ingrédient (RB0-2)")
  -- classes, boîtes, portées
  local class_half = { P = 0.4, M = 0.6, G = 0.9 }
  local boxes_ok, range_ok, units_ok, dps_ok = true, true, true, true
  for _, r in ipairs(Ro.ROBOTS) do
    if r.is_giant then
      if not (r.range == 100 and r.class == "giant" and r.points == 12 and r.giant and r.giant.scale >= 1.5) then range_ok = false end
    else
      if r.half ~= class_half[r.class] then boxes_ok = false end
      if r.range > 45 then range_ok = false end
      if r.half > 0.9 then units_ok = false end
    end
    if r.dps ~= r.shot.damage * 60 / r.shot.cooldown then dps_ok = false end
  end
  check(boxes_ok and units_ok, "§1 boîtes : petit ±0,4, moyen ±0,6, grand ±0,9 au plus (RB0 E2)")
  check(range_ok, "§1 portée d'une unité ≤ 45 (vision ≤ 45, PLAN §3) ; géant : portée 100 (RB0 : zones mortes à 60), 12 points")
  check(dps_ok, "§1 DPS = dégâts × 60 / cadence pour tous")
  local pts_ok = true
  for _, r in ipairs(Ro.ROBOTS) do
    if r.points ~= Ro.POINTS[r.class] then pts_ok = false end
  end
  check(pts_ok, "§1 points par classe")
  check(Ro.kit_name("steam-trotter") == "fo-robot-kit-steam-trotter" and tr.kit == Ro.kit_name("steam-trotter"), "§1 nom du kit")
  check(Ro.recipe_name("steam-trotter") == tr.recipe and Ro.robot_of_kit(tr.kit) == tr, "§1 recette et relecture du kit")
  check(Ro.unit_name("azure", "steam-trotter") == "fo-robot-azure-steam-trotter", "§1 nom d'unité par propriétaire")
  check(Ro.proto_name("azure", tr) == "fo-robot-azure-steam-trotter" and Ro.proto_name("azure", Ro.robot("toroid")) == "fo-robot-player-toroid",
    "§1 un géant n'a que le prototype du joueur")
  -- relecture des noms d'unité, pour tous les propriétaires et tous les robots
  local roundtrip = true
  for _, owner in ipairs(Ro.OWNERS) do
    for _, r in ipairs(Ro.ROBOTS) do
      local o, id = Ro.parse_unit(Ro.unit_name(owner, r.id))
      if o ~= owner or id ~= r.id then roundtrip = false end
    end
  end
  check(roundtrip, "§1 relecture du nom d'unité : propriétaire et robot")
  check(Ro.parse_unit("fo-robot-azure-inconnu") == nil and Ro.parse_unit("fo-azure-rifleman") == nil
    and Ro.parse_unit("fo-robot-workshop") == nil and Ro.parse_unit(nil) == nil, "§1 un autre nom n'est pas une unité de robot")
  check(#Ro.unit_names() == #Ro.OWNERS * 12 + 3, "§1 un prototype par propriétaire pour les 12 unités (9 du plan, 3 variantes), un seul pour chacun des 3 géants", tostring(#Ro.unit_names()))
  check(Ro.OWNERS[1] == Ro.PLAYER_OWNER and #Ro.OWNERS == 1 + #F.factions, "§1 propriétaires : le joueur puis les factions")
  local same = true
  for i, f in ipairs(F.factions) do if Ro.OWNERS[i + 1] ~= f.key then same = false end end
  check(same, "§1 les propriétaires suivent F.factions (clés et ordre)")
  check(Ro.owner_of("scarlet", { scarlet = "scarlet" }) == "scarlet" and Ro.owner_of("player", { scarlet = "scarlet" }) == "player"
    and Ro.owner_of("x") == "player", "§1 propriétaire d'une force : la faction, sinon le joueur")
  -- usines
  local sizes, cats, ages = { 3, 5, 7, 11 }, { "fo-robots-1", "fo-robots-2", "fo-robots-3", "fo-robots-4" }, { 3, 7, 10, 13 }
  local fact_ok = #Ro.FACTORIES == 4
  for i, w in ipairs(Ro.FACTORIES) do
    if w.size ~= sizes[i] or w.category ~= cats[i] or w.age ~= ages[i] or w.tier ~= i or not Ro.is_factory(w.name) then fact_ok = false end
  end
  check(fact_ok, "§1 quatre usines : 3 × 3, 5 × 5, 7 × 7, 11 × 11, catégories fo-robots-1 à -4, âges 3, 7, 10, 13")
  local w = Ro.workshop("fo-robot-workshop")
  check(w and w.size == 3 and w.age == 3 and w.category == "fo-robots-1" and Ro.is_workshop("fo-robot-workshop")
    and not Ro.is_workshop("assembling-machine-2"), "§1 atelier : 3 × 3, âge 3, catégorie fo-robots-1")
  -- lot US-V1 : feuilles des 4 usines (D-6), chacune nommée par sa `sheet`
  local UsinesSheets = dofile("tests/datastage/usines_sheets.lua")
  local ru = UsinesSheets.check(".")
  if not UsinesSheets.ok(ru) then for _, l in ipairs(UsinesSheets.lines(ru)) do print(l) end end
  local sheets_ok = UsinesSheets.ok(ru) and ru.n > 0
  for i, nom in ipairs(UsinesSheets.USINES) do
    if Ro.FACTORIES[i].sheet ~= nom then sheets_ok = false end
  end
  check(sheets_ok, string.format("§1 usines : feuilles de graphics/robots/usines (%d PNG au manifeste, %d images de sprites.lua relues)", ru.n, ru.refs or 0))
  local fcount, factory_ok = 0, true
  for _, r in ipairs(Ro.ROBOTS) do
    local f = Ro.factory(r.factory)
    if not f or f.age > r.age then factory_ok = false end
    fcount = fcount + 1
  end
  check(factory_ok and fcount == 15, "§1 chaque robot a une usine, arrivée au plus tard à son âge")
  check(#Ro.robots_of("fo-robot-workshop") == 5 and #Ro.robots_of("fo-robotics-bay") == 4 and #Ro.robots_of("fo-robot-dock") == 3
    and #Ro.robots_of("fo-robot-gantry") == 3 and #Ro.robots_of("nom-inconnu") == 0, "§1 robots d'un bâtiment : 5, 4, 3, 3 (variantes : 2 à l'atelier, 1 au hall)")
  check(Ro.POINTS.P == 1 and Ro.POINTS.M == 2 and Ro.POINTS.G == 4 and Ro.POINTS.giant == 12, "§1 points : P 1, M 2, G 4, géant 12")
  -- technologies : chaque robot et chaque usine ouverts une fois, prérequis en jeu ou dans le lot
  local opened_r, opened_f, tech_ok = {}, {}, true
  local names = {}
  for _, t in ipairs(Ro.TECHS) do names[t.name] = t end
  for _, t in ipairs(Pt.TECHS) do names[t.name] = t end
  for _, t in ipairs(Ro.TECHS) do
    for _, id in ipairs(t.robots or {}) do opened_r[id] = (opened_r[id] or 0) + 1 end
    for _, fn in ipairs(t.factories or {}) do opened_f[fn] = (opened_f[fn] or 0) + 1 end
    for _, pre in ipairs(t.prerequisites) do
      -- un prérequis du lot doit précéder (âge ≤) ; les autres sont des technologies du jeu de base ou d'un autre lot
      local lot = names[pre]
      if lot and lot.epoch > t.epoch then tech_ok = false end
    end
  end
  local every = true
  for _, r in ipairs(Ro.ROBOTS) do if opened_r[r.id] ~= 1 then every = false end end
  for _, f in ipairs(Ro.FACTORIES) do if opened_f[f.name] ~= 1 then every = false end end
  check(every, "§1 chaque robot et chaque usine est ouvert par une technologie, une seule")
  check(tech_ok, "§1 aucun prérequis du lot n'est d'un âge postérieur")
  local fac_tech = true
  for _, f in ipairs(Ro.FACTORIES) do if not Ro.tech(f.tech) then fac_tech = false end end
  check(fac_tech, "§1 la technologie de chaque usine existe")
  local unlocks = Ro.tech_unlocks()
  check(#unlocks == 2 and unlocks[1] == "fo-robot-workshop" and unlocks[2] == tr.recipe, "§1 la première technologie débloque l'atelier et le kit")
  check(Ro.TECH.epoch == 3 and Ro.TECH.prerequisites[1] == "engine", "§1 technologie de l'âge 3, après le moteur")
  -- géants : segments, assemblage final, plafond
  local gi_ok = #Ro.giants() == 3 and Ro.SEGMENTS == 10
  for _, r in ipairs(Ro.giants()) do
    local has10 = false
    for _, g in ipairs(r.ingredients) do if g[1] == r.segment_item and g[2] == 10 then has10 = true end end
    if not (has10 and r.segment_recipe == "fo-robot-make-segment-" .. r.id and r.factory == "fo-robot-gantry" and r.time == 120) then gi_ok = false end
  end
  check(gi_ok, "§1 géants : 10 segments, assemblage final de 120 s au portique")
  check(Ro.giant_allowed(12) == 0 and Ro.giant_allowed(13) == 1 and Ro.giant_allowed(14) == 2 and Ro.giant_allowed(15) == 3 and Ro.giant_allowed(99) == 3
    and Ro.giant_allowed(nil) == 0, "§1 géants admis : 0, puis 1, 2, 3 aux âges 13, 14, 15")
  local only_roles = true
  for _, r in ipairs(Ro.ROBOTS) do
    if r.id == "bellwether" and not (r.heal and r.heal.amount > 0 and r.heal.radius == 12 and r.heal.max == 30 and r.dps == 0) then only_roles = false end
    if r.id == "chamfer" and not (r.min_range == 12 and r.area and r.range == 45) then only_roles = false end
    if r.id == "trowel" and not (r.engineer and r.engineer.radius == 20) then only_roles = false end
    if r.id == "coiler" and not r.area then only_roles = false end
  end
  check(only_roles, "§1 rôles : soin (rayon 12, 30 au plus, 0 dégât), artillerie (portée minimale 12, zone), ingénieur (rayon 20), zone")

  -- §2 Plafond.
  check(Mo.cap(3) == 30 and Mo.cap(1) == 18 and Mo.cap(15) == 102, "§2 plafond 12 + 6 × âge : 30 à l'âge 3, 102 à l'âge 15",
    Mo.cap(3) .. " " .. Mo.cap(15))
  check(Mo.cap(0) == 18 and Mo.cap(-4) == 18 and Mo.cap(99) == 102 and Mo.cap(nil) == 18 and Mo.cap(3.9) == 30,
    "§2 âge ramené dans 1 à 15")
  check(Mo.cap(3, 2) == 2 and Mo.cap(3, 0) == 30 and Mo.cap(3, nil) == 30 and Mo.cap(15, 500) == 500, "§2 le réglage > 0 remplace le plafond")
  check(Mo.room(5, 30) == 25 and Mo.room(40, 30) == 0, "§2 points libres, jamais négatifs")
  local function rel(used, cap, pts, have, keep) return Mo.can_release({ used = used, cap = cap, points = pts, have = have, keep = keep }) end
  check(rel(0, 2, 1, 0) and rel(1, 2, 1, 1) and not rel(2, 2, 1, 2), "§2 plafond 2 : le 3e kit reste")
  check(not rel(29, 30, 2, 5) and rel(28, 30, 2, 5), "§2 un robot de 2 points exige 2 points libres")
  check(rel(0, 30, 1, 3, nil) and rel(0, 30, 1, 3, 4) and not rel(0, 30, 1, 4, 4) and not rel(0, 30, 1, 9, 4) and rel(0, 30, 1, 0, 1),
    "§2 maintenir N : le kit reste quand l'effectif a atteint N")
  check(not rel(0, 30, 1, 0, 0), "§2 maintenir 0 : aucun robot")
  local function relg(used, cap, have_g, allowed)
    return Mo.can_release({ used = used, cap = cap, points = 12, have = 0, giant = true, giants_have = have_g, giants_allowed = allowed })
  end
  check(not relg(0, 102, 0, 0) and relg(0, 102, 0, 1) and not relg(0, 102, 1, 1) and relg(0, 102, 2, 3) and not relg(0, 102, 3, 3),
    "§2 géants : le kit reste quand les géants admis à l'âge sont là (1, 2, 3 aux âges 13, 14, 15)")
  check(not relg(95, 102, 0, 3) and relg(90, 102, 0, 3), "§2 géants : 12 points libres exigés")
  check(Mo.giants_allowed(12) == 0 and Mo.giants_allowed(13) == 1 and Mo.giants_allowed(15) == 3, "§2 géants admis par âge")
  local lg = Mo.new_ledger()
  Mo.add(lg, "player", 1, "toroid", 12)
  Mo.add(lg, "player", 2, "crowned", 12)
  Mo.add(lg, "player", 3, "steam-trotter", 1)
  Mo.add(lg, "azure", 4, "toroid", 12)
  check(Mo.giants_of(lg, "player") == 2 and Mo.giants_of(lg, "azure") == 1 and Mo.giants_of(lg, "amber") == 0, "§2 géants vivants par force")
  check(table.concat(Mo.units_with(lg, "toroid"), ",") == "1,4" and #Mo.units_with(lg, "heliast") == 0, "§2 unités d'un robot, triées")
  check(Mo.check(lg), "§2 registre avec géants cohérent")

  -- §3 Registre.
  local l = Mo.new_ledger()
  check(Mo.count(l) == 0 and Mo.used(l, "player") == 0 and Mo.have(l, "player", "steam-trotter") == 0, "§3 registre vide")
  check(Mo.add(l, "player", 30, "steam-trotter", 1) and Mo.add(l, "player", 10, "steam-trotter", 1) and Mo.add(l, "scarlet", 20, "steam-trotter", 2),
    "§3 ajouts")
  check(not Mo.add(l, "player", 10, "steam-trotter", 1), "§3 ajouter deux fois la même unité : refusé")
  check(Mo.used(l, "player") == 2 and Mo.used(l, "scarlet") == 2 and Mo.have(l, "player", "steam-trotter") == 2, "§3 points et effectifs par force")
  check(table.concat(l.order, ",") == "10,20,30", "§3 liste triée par numéro d'unité malgré l'ordre d'arrivée", table.concat(l.order, ","))
  check(table.concat(Mo.units_of(l, "player"), ",") == "10,30" and table.concat(Mo.units_of(l, "scarlet"), ",") == "20", "§3 unités d'une force")
  check(table.concat(l.forces, ",") == "player,scarlet", "§3 forces triées")
  local f1, id1, p1 = Mo.remove(l, 10)
  check(f1 == "player" and id1 == "steam-trotter" and p1 == 1 and Mo.used(l, "player") == 1, "§3 retrait : les points sont rendus")
  check(Mo.remove(l, 10) == nil and Mo.used(l, "player") == 1, "§3 retirer deux fois : sans effet (idempotent)")
  check(Mo.remove(l, 999) == nil, "§3 retirer une inconnue : sans effet")
  check(Mo.check(l), "§3 cohérence interne")
  Mo.add(l, "player", 11, "steam-trotter", 1)
  Mo.add(l, "player", 12, "steam-trotter", 1)
  local gone = Mo.prune(l, function(un) return un ~= 11 and un ~= 30 end)
  check(#gone == 2 and gone[1] == 11 and gone[2] == 30 and Mo.used(l, "player") == 1 and Mo.have(l, "player", "steam-trotter") == 1,
    "§3 balayage : retire les unités refusées, dans l'ordre", table.concat(gone, ","))
  check(Mo.check(l), "§3 cohérence après balayage")
  local bad = Mo.new_ledger()
  Mo.add(bad, "player", 1, "steam-trotter", 1)
  bad.used.player = 5
  check(select(1, Mo.check(bad)) == false, "§3 une incohérence de points est vue")
  local bad2 = Mo.new_ledger()
  Mo.add(bad2, "player", 2, "steam-trotter", 1)
  Mo.add(bad2, "player", 1, "steam-trotter", 1)
  bad2.order = { 2, 1 }
  check(select(1, Mo.check(bad2)) == false, "§3 une liste non triée est vue")
  -- déterminisme : tous les ordres d'arrivée donnent le même état
  local function serial(order)
    local lg = Mo.new_ledger()
    for _, un in ipairs(order) do Mo.add(lg, un % 2 == 0 and "player" or "azure", un, "steam-trotter", 1) end
    Mo.remove(lg, 3)
    return table.concat(lg.order, ",") .. "|" .. table.concat(lg.forces, ",") .. "|" .. Mo.used(lg, "player") .. "," .. Mo.used(lg, "azure")
  end
  check(serial({ 5, 2, 3, 8, 1 }) == serial({ 1, 8, 3, 2, 5 }) and serial({ 1, 2, 3, 5, 8 }) == serial({ 3, 1, 5, 8, 2 }), "§3 état identique quel que soit l'ordre d'arrivée")

  -- §4 File.
  local q = { { id = "a", n = 2 }, { id = "b", n = 1 }, { id = "c", n = 0 } }
  check(Mo.queue_next(q, {}) == "a" and Mo.queue_next(q, { a = 2 }) == "b" and Mo.queue_next(q, { a = 2, b = 1 }) == nil, "§4 file : premier robot sous sa cible")
  check(Mo.queue_next(q, { a = 5, b = 0 }) == "b" and Mo.queue_next({}, {}) == nil and Mo.queue_next(nil, {}) == nil, "§4 file : trop de a, b manque ; file vide")
  check(Mo.queue_next({ { id = "c", n = 0 }, { id = "a", n = -1 } }, {}) == nil, "§4 file : cible nulle ou négative sautée")
  check(Mo.queue_valid(q, { a = true, b = true, c = true }) and not Mo.queue_valid(q, { a = true, b = true })
    and not Mo.queue_valid({ { id = "a", n = 1.5 } }, { a = true }) and not Mo.queue_valid({ { id = "a", n = -1 } }, { a = true }), "§4 file valide : robots connus, n entier ≥ 0")

  -- §5 Géométrie, ordres.
  local o = Mo.out_point({ x = 10, y = 20 }, 3)
  check(o.x == 10 and o.y == 23.5, "§5 sortie : sous le bord sud + 2 tuiles", tostring(o.y))
  local r = Mo.default_rally({ x = 10, y = 20 }, 3)
  check(r.x == 10 and r.y == 23.5 + Ro.RALLY_DEPTH, "§5 ralliement : au sud de la sortie")
  check(Mo.dist({ x = 0, y = 0 }, { x = 3, y = 4 }) == 5, "§5 distance")
  check(Mo.valid_point({ x = 1, y = 2 }) and Mo.valid_point({ 1, 2 }) and not Mo.valid_point({ x = 1 }) and not Mo.valid_point(nil)
    and not Mo.valid_point({ x = 0 / 0, y = 1 }) and not Mo.valid_point({ x = 1e9, y = 0 }), "§5 point d'ordre valide")
  check(Mo.is_order("move") and Mo.is_order("attack") and not Mo.is_order("flee"), "§5 ordres connus")
  return pass, fail, msgs
end

local Ro0, Mo0 = assert(load_all(RO_SRC, MO_SRC))
local pass, fail, msgs = suite(Ro0, Mo0)

-- §6 Forme des fichiers.
local FILES = { "shared/content/robots.lua", "shared/robots/modele.lua", "script/robots/armee.lua", "script/robots/usine.lua",
  "script/robots/ordres.lua", "prototypes/robots.lua", "settings/robots.lua",
  "shared/robots/commande.lua", "script/robots/outils.lua", "script/gui/robots.lua", "script/robots/faction.lua",
  "script/robots/soutien.lua", "script/robots/geant.lua", "shared/robots/duel.lua", "shared/content/robot_parts.lua", "prototypes/robot_parts.lua" }
local function check6(c, m)
  if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
end
for _, path in ipairs(FILES) do
  local code = strip(read(path))
  -- pairs() n'est toléré que sur les collections du moteur triées juste après (game.surfaces)
  local bare = false
  for line in code:gmatch("[^\n]+") do
    -- tolérés : les collections du moteur (surfaces, forces, dictionnaire rendu par set_recipe) et l'état des pertes, collectés dans une
    -- liste triée juste après
    if line:find("[^i_%w]pairs%s*%(") and not line:find("game%.surfaces") and not line:find("game%.forces")
        and not line:find("pairs%(back%)") and not line:find("pairs%(alerts%)") then bare = true end
  end
  check6(not bare, "§6 " .. path .. " : pairs() dans une décision")
  check6(not code:find("math%.random") and not code:find("os%.time") and not code:find("os%.clock") and not code:find("game%.tick"),
    "§6 " .. path .. " : hasard ou horloge")
  check6(not code:find("[^%.%w_%-]global%f[^%w_]"), "§6 " .. path .. " : `global` nommé (seul script/core/storage.lua le nomme)")
  -- F24 : aucun require dans une fonction (ligne indentée)
  local indented = false
  for line in code:gmatch("[^\n]+") do
    if line:match("^%s+.-require%s*%(") and not line:match("^%s*local%s+[%w_]+%s*=%s*require") then indented = true end
    if line:match("^%s+local%s+[%w_]+%s*=%s*require") then indented = true end
  end
  check6(not indented, "§6 " .. path .. " : require dans une fonction (F24)")
end
-- les fichiers de shared/ ne touchent pas à l'API du jeu
for _, path in ipairs({ "shared/content/robots.lua", "shared/robots/modele.lua", "shared/robots/commande.lua", "shared/robots/duel.lua",
    "shared/content/robot_parts.lua" }) do
  local code = strip(read(path))
  check6(not code:find("%f[%w_]game%.") and not code:find("%f[%w_]defines%.") and not code:find("%f[%w_]script%.") and not code:find("%f[%w_]settings%.")
    and not code:find("%f[%w_]data:extend") and not code:find("%f[%w_]log%s*%("), "§6 " .. path .. " : Lua pur (aucune API du jeu)")
end
-- §6 bis Intégration 0.6.33 : la demande d'une faction écarte ce que personne ne fabriquerait (plafond, géants admis, refus du mall) et demande les segments
do
  local fa = strip(read("script/robots/faction.lua"))
  check6(fa:find("Mo.can_release(Armee.release_params(force, r))", 1, true) ~= nil, "§6 bis candidats : la règle du balayage des ateliers (plafond, géants admis)")
  check6(fa:find("Ml.refused(ml, tick, kit)", 1, true) ~= nil and fa:find("Ml.refused(ml, tick, r.segment_item)", 1, true) ~= nil, "§6 bis candidats : refus du mall lus (kit, segments)")
  check6(fa:find("Ml.want(ml, tick, rb.segment_item, demand.rate * Ro.SEGMENTS, Id.SRC_REFUS)", 1, true) ~= nil, "§6 bis les segments d'un géant sont demandés")
  local ind = strip(read("script/ai3/industrie.lua"))
  check6(ind:find("Ml.refuse(ml, tick, r.item)", 1, true) ~= nil and ind:find("Ml.refuse(ml, tick, it)", 1, true) ~= nil, "§6 bis le mall note ses refus (règle du choix, gabarit)")
  local Ml = require("shared.ai3.mall")
  local ms = Ml.new()
  Ml.refuse(ms, 100, "x")
  check6(Ml.refused(ms, 100, "x") and Ml.refused(ms, 100 + Ml.REFUS_TTL - 1, "x") and not Ml.refused(ms, 100 + Ml.REFUS_TTL, "x") and not Ml.refused(ms, 100, "y"),
    "§6 bis un refus du mall s'éteint après Ml.REFUS_TTL")
  -- les kits que le patron refuse (plus de 8 entrées) existent bien : la règle ci-dessus sert à quelque chose
  local over = 0
  for _, r in ipairs(Ro0.ROBOTS) do if #r.ingredients > 8 then over = over + 1 end end
  check6(over == 3, "§6 bis 3 kits à plus de 8 entrées solides (Chanfrein, Aileron, Lévite)")
end
-- aucun nom du lot dans le cerveau (tests/iag_test.lua §8 le contrôle aussi, par permutation)
local brain_hits = {}
-- Lot TESTS-GIT (0.6.64) : liste par tests/depot.lua (git ls-files ; sans git, le disque, annoncé par une ligne [ENVIRONNEMENT]).
local Depot = require("tests.depot")
local brain_files, brain_src = Depot.lua_files({ "shared/ai3", "script/ai3" })
if brain_src == "disque" then Depot.env("§6 aucun nom de robot dans le cerveau (git ls-files)", #brain_files > 0) end
for _, path in ipairs(brain_files) do
  local code = strip(read(path))
  if code:find("fo%-robot") or code:find("steam%-trotter") then brain_hits[#brain_hits + 1] = path end
end
check6(#brain_files > 0 and #brain_hits == 0, "§6 aucun nom de robot dans shared/ai3 ni script/ai3 : " .. table.concat(brain_hits, " "))

-- §7 Traductions : toute clé localisée citée par les sources du lot existe en FR et EN.
local function cfg_keys(path)
  local keys, section = {}, nil
  for line in read(path):gmatch("[^\r\n]+") do
    local s = line:match("^%[([%w%-_]+)%]$")
    if s then section = s
    elseif section and not line:match("^%s*;") then
      local k = line:match("^([^=]+)=")
      if k then keys[section .. "." .. k] = true end
    end
  end
  return keys
end
local FR, EN = cfg_keys("locale/fr/robots.cfg"), cfg_keys("locale/en/robots.cfg")
local needed = { "fo-robots.unit-name", "item-subgroup-name.fo-robots", "item-subgroup-name.fo-robot-parts",
  "ammo-category-name.fo-robot", "ammo-category-name.fo-robot-shell",
  "mod-setting-name." .. Ro0.SETTING, "mod-setting-description." .. Ro0.SETTING,
  "mod-setting-name." .. Ro0.SETTING_CAP, "mod-setting-description." .. Ro0.SETTING_CAP }
for _, w in ipairs(Ro0.FACTORIES) do
  needed[#needed + 1] = "entity-name." .. w.name
  needed[#needed + 1] = "entity-description." .. w.name
  needed[#needed + 1] = "item-name." .. w.name
end
for _, r in ipairs(Ro0.ROBOTS) do
  needed[#needed + 1] = "fo-robots.name-" .. r.id
  needed[#needed + 1] = "fo-robots.desc-" .. r.id
  needed[#needed + 1] = "item-name." .. r.kit
  needed[#needed + 1] = "item-description." .. r.kit
  if r.is_giant then
    needed[#needed + 1] = "item-name." .. r.segment_item
    needed[#needed + 1] = "item-description." .. r.segment_item
    needed[#needed + 1] = "item-name." .. Ro0.shell_name(r.id)
    needed[#needed + 1] = "item-description." .. Ro0.shell_name(r.id)
    needed[#needed + 1] = "item-name." .. Ro0.gun_name(r.id)
  end
end
for _, t in ipairs(Ro0.TECHS) do
  needed[#needed + 1] = "technology-name." .. t.name
  needed[#needed + 1] = "technology-description." .. t.name
end
for _, t in ipairs(Pt.TECHS) do
  needed[#needed + 1] = "technology-name." .. t.name
  needed[#needed + 1] = "technology-description." .. t.name
end
for _, n in ipairs(Pt.ITEMS) do
  needed[#needed + 1] = "item-name." .. n
  needed[#needed + 1] = "item-description." .. n
end
for _, k in ipairs(needed) do
  check6(FR[k] ~= nil, "§7 traduction FR absente : " .. k)
  check6(EN[k] ~= nil, "§7 traduction EN absente : " .. k)
end
-- le prototype ne cite que des clés présentes : on relit ses chaînes { "section.clé" }
local proto = read("prototypes/robots.lua")
for key in proto:gmatch('{%s*"([%w%-_]+%.[%w%-_]+)"') do
  local base = key
  local found = FR[base] ~= nil or key:match("^entity%-name%.fo%-robot%-workshop$") ~= nil
  -- les noms par robot sont composés (name-<id>) : lus dans la boucle des robots
  if not found and (key == "fo-robots.name-" or key:find("^fo%-robots%.name%-") or key:find("^fo%-robots%.desc%-")) then found = true end
  check6(found, "§7 clé du prototype absente du locale FR : " .. key)
end
for _, r in ipairs(Ro0.ROBOTS) do
  check6(FR["fo-robots.name-" .. r.id] ~= nil and EN["fo-robots.name-" .. r.id] ~= nil, "§7 nom du robot " .. r.id .. " en FR et EN")
end
-- chaque section du FR a la même liste de clés en EN
local same = true
for k in pairs(FR) do if not EN[k] then same = false end end
for k in pairs(EN) do if not FR[k] then same = false end end
check6(same, "§7 FR et EN : mêmes clés")

-- §8 Mutants.
local MUTANTS = {
  { "plafond sans âge", "return Ro.CAP_BASE + Ro.CAP_PER_AGE * M.age_clamped(age)", "return Ro.CAP_BASE + Ro.CAP_PER_AGE" },
  { "âge sans borne haute", "return max(1, min(Ro.AGES, floor(tonumber(age) or 1)))", "return max(1, floor(tonumber(age) or 1))" },
  { "âge sans borne basse", "return max(1, min(Ro.AGES, floor(tonumber(age) or 1)))", "return min(Ro.AGES, floor(tonumber(age) or 1))" },
  { "réglage ignoré", "if override and override > 0 then return floor(override) end", "" },
  { "réglage nul compté", "if override and override > 0 then return floor(override) end", "if override then return floor(override) end" },
  { "points libres négatifs", "return max(0, cap - used)", "return cap - used" },
  { "plafond dépassable d'un point", "if p.used + p.points > p.cap then return false end", "if p.used + p.points > p.cap + 1 then return false end" },
  { "plafond sans les points du robot", "if p.used + p.points > p.cap then return false end", "if p.used > p.cap then return false end" },
  { "maintenir N ignoré", "if p.keep ~= nil and p.have >= p.keep then return false end", "" },
  { "géants sans plafond d'âge", "if p.giant and (p.giants_have or 0) >= (p.giants_allowed or 0) then return false end", "" },
  { "géants admis d'un de trop", "if p.giant and (p.giants_have or 0) >= (p.giants_allowed or 0) then return false end", "if p.giant and (p.giants_have or 0) > (p.giants_allowed or 0) then return false end" },
  { "géants non comptés", "if r.is_giant then n = n + M.have(l, force, r.id) end", "" },
  { "maintenir N d'une unité de trop", "if p.keep ~= nil and p.have >= p.keep then return false end", "if p.keep ~= nil and p.have > p.keep then return false end" },
  { "points non ajoutés", "l.used[force] = l.used[force] + points", "l.used[force] = l.used[force] + 0" },
  { "points non rendus", "l.used[u.force] = l.used[u.force] - u.points", "l.used[u.force] = l.used[u.force] - 0" },
  { "double ajout accepté", "if l.units[unit_number] then return false end\n  l.units[unit_number] = { force = force", "l.units[unit_number] = { force = force" },
  { "retrait non idempotent", "  local u = l.units[unit_number]\n  if not u then return nil end", "  local u = l.units[unit_number] or { force = 'player', id = 'steam-trotter', points = 1 }" },
  { "liste non triée", "while i >= 1 and list[i] > v do i = i - 1 end", "" },
  { "effectif non tenu", "l.by_id[force][id] = (l.by_id[force][id] or 0) + 1", "" },
  { "balayage sans retrait", "      M.remove(l, un)\n", "" },
  { "file sans effectif", "if (have[q.id] or 0) < q.n then return q.id end", "if q.n > 0 then return q.id end" },
  { "file jusqu'à la cible comprise", "if (have[q.id] or 0) < q.n then return q.id end", "if (have[q.id] or 0) <= q.n then return q.id end" },
  { "file inconnue acceptée", "if not known[q.id] then return false end", "" },
  { "sortie au nord", "return { x = pos.x, y = pos.y + size / 2 + 2 }", "return { x = pos.x, y = pos.y - size / 2 - 2 }" },
  { "ralliement sur la sortie", "return { x = o.x, y = o.y + Ro.RALLY_DEPTH }", "return { x = o.x, y = o.y }" },
  { "point non fini accepté", "return x == x and y == y and math.abs(x) < 1e7 and math.abs(y) < 1e7", "return true" },
  { "ordre inconnu accepté", "if k == kind then return true end", "return true" },
}
-- mutants des données
local RO_MUTANTS = {
  { "petit robot à 2 points", "P = 1, M = 2", "P = 2, M = 2" },
  { "base du plafond à 13", "Ro.CAP_BASE = 12", "Ro.CAP_BASE = 13" },
  { "pas du plafond à 5", "Ro.CAP_PER_AGE = 6", "Ro.CAP_PER_AGE = 5" },
  { "forme du Trotte-Vapeur changée", "hp0 = 900,", "hp0 = 800," },
  { "cadence changée", "shot = { damage = 23.1, cooldown = 30 }", "shot = { damage = 23.1, cooldown = 20 }" },
  { "géants admis dès l'âge 12", "Ro.GIANT_FIRST_AGE = 13", "Ro.GIANT_FIRST_AGE = 12" },
  { "quatre géants admis", "Ro.GIANT_MAX = 3", "Ro.GIANT_MAX = 4" },
  { "neuf segments", "Ro.SEGMENTS = 10", "Ro.SEGMENTS = 9" },
  { "portée d'un géant à 60", "hp0 = 600000, dmg0 = 10000, hp = 834000, shot = { damage = 13900, cooldown = 30 }, range = 100", "hp0 = 600000, dmg0 = 10000, hp = 834000, shot = { damage = 13900, cooldown = 30 }, range = 60" },
  { "Hall en 4 × 4", 'name = "fo-robotics-bay", tier = 2, age = 7, size = 5', 'name = "fo-robotics-bay", tier = 2, age = 7, size = 4' },
  { "portique à l'âge 12", 'name = "fo-robot-gantry", tier = 4, age = 13', 'name = "fo-robot-gantry", tier = 4, age = 12' },
  { "Cloche qui tire", 'heal = { amount = 172, radius = 12, max = 30, period = 60 }', 'heal = { amount = 172, radius = 12, max = 31, period = 60 }' },
  { "artillerie sans portée minimale", "dtype = \"explosion\", area = 3, area_share = 0.75, min_range = 12", "dtype = \"explosion\", area = 3, area_share = 0.75" },
  { "segment retiré d'un géant", "ingredients = {}, time = 120, mu = 459000", "ingredients = {}, time = 100, mu = 459000" },
  { "ingrédient du Lévite en double", '{ "fo-superconducting-coil", 100 }, { "fo-titanium-plate", 100 }, { "processing-unit", 100 }, { "fo-magnetic-actuator", 100 },\n      { "fo-laser-module", 100 }, { "fo-graphics-card", 100 }, { "fo-guidance-core", 100 }, { "low-density-structure", 100 },',
    '{ "fo-superconducting-coil", 100 }, { "fo-superconducting-coil", 100 }, { "processing-unit", 100 }, { "fo-magnetic-actuator", 100 },\n      { "fo-laser-module", 100 }, { "fo-graphics-card", 100 }, { "fo-guidance-core", 100 }, { "low-density-structure", 100 },' },
  { "coût du Lévite divisé par deux", '{ "fo-motherboard", 100 }, { "fo-controller", 100 } }, time = 90', '{ "fo-motherboard", 10 }, { "fo-controller", 10 } }, time = 90' },
  { "coût en acier changé", '{ "steel-plate", 22 }', '{ "steel-plate", 30 }' },
  { "ingrédient au-delà de 100", '{ "engine-unit", 10 }, { "steel-plate", 22 }', '{ "engine-unit", 10 }, { "steel-plate", 220 }' },
  { "premier robot à l'âge 7", "id = \"steam-trotter\", age = 3", "id = \"steam-trotter\", age = 7" },
  { "propriétaire manquant", '{ "player", "scarlet", "azure", "emerald", "amber" }', '{ "player", "scarlet", "azure", "emerald" }' },
  { "propriétaires dans un autre ordre", '{ "player", "scarlet", "azure", "emerald", "amber" }', '{ "player", "azure", "scarlet", "emerald", "amber" }' },
  { "nom d'unité changé", 'return Ro.PREFIX .. owner .. "-" .. id', 'return Ro.PREFIX .. id .. "-" .. owner' },
}
local refused, kept = 0, {}
local function try(label, ro_src, mo_src)
  local Ro, Mo = load_all(ro_src, mo_src)
  local f2 = 1
  if Ro then
    local ok, _, ff = pcall(suite, Ro, Mo)
    f2 = ok and ff or 1
  end
  if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = label end
end
for _, m in ipairs(MUTANTS) do
  local a, b = MO_SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    try(m[1], RO_SRC, MO_SRC:sub(1, a - 1) .. m[3] .. MO_SRC:sub(b + 1))
  end
end
for _, m in ipairs(RO_MUTANTS) do
  local a, b = RO_SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    try(m[1], RO_SRC:sub(1, a - 1) .. m[3] .. RO_SRC:sub(b + 1), MO_SRC)
  end
end
if #kept == 0 then pass = pass + 1 else
  fail = fail + 1
  msgs[#msgs + 1] = "§8 mutants NON refusés : " .. table.concat(kept, " ; ")
end

for _, m in ipairs(msgs) do print("[ROBOTS] ECHEC " .. m) end
print(string.format("[ROBOTS] mutants refusés : %d sur %d", refused, #MUTANTS + #RO_MUTANTS))
print(string.format("[ROBOTS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
