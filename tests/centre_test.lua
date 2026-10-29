--[[
  Lot CENTRE-JEU : épave du centre de commandement et réparation (shared/levels/centre.lua, script/levels/centre.lua).
  Règles pures, puis moteur simulé : épave posée au premier joueur, niveau effectif 0 (aucun plafond), amélioration
  refusée, réparation payée sur l'inventaire du joueur, migration (centre déjà posé = réparé), IA non touchées.
  Usage : lua5.2 tests/centre_test.lua
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local L = require("shared.levels.config")
local C = require("shared.levels.centre")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[CENTRE] ECHEC : " .. msg) end
end

---------------------------------------------------------------------------------------------------
-- 1. Règles pures
---------------------------------------------------------------------------------------------------
local cost = C.repair_cost(L)
local base = L.cost(L.by_key.command, 2)
check(cost[1][1] == C.PACK_ITEM and cost[1][2] == C.PACK_COUNT, "le coût commence par les paquets de réparation")
check(#cost == #base + 1, "une ligne par matériau du coût 1 → 2, plus les paquets")
for i, b in ipairs(base) do
  check(cost[i + 1][1] == b[1], "matériau " .. b[1] .. " dans l'ordre du coût 1 → 2")
  check(cost[i + 1][2] >= 1 and cost[i + 1][2] <= b[2], "quantité de " .. b[1] .. " au plus celle du niveau 2")
  check(cost[i + 1][2] >= math.floor(b[2] * C.MATERIAL_SHARE * 0.9), "quantité de " .. b[1] .. " proche de la part voulue")
end
local c2 = C.repair_cost(L)
c2[1][2] = 999
check(C.repair_cost(L)[1][2] == C.PACK_COUNT, "le coût rendu est une nouvelle liste")
-- Lu aux données : un autre coût de centre change la réparation.
local fake = { by_key = { command = {} }, cost = function() return { { "x-item", 100 }, { "y-item", 1 } } end,
  round_nice = function(v) return math.floor(v + 0.5) end }
local fc = C.repair_cost(fake)
check(fc[2][1] == "x-item" and fc[2][2] == 50 and fc[3][1] == "y-item" and fc[3][2] == 1, "coût recalculé sur d'autres données (minimum 1)")

check(C.effective_level(7, true) == 0 and C.effective_level(7, false) == 7 and C.effective_level(nil, false) == 0, "niveau effectif")
check(L.building_cap(C.effective_level(15, true)) == 1, "épave : plafond des bâtiments minimal (aucun niveau offert)")
check(L.building_cap(C.effective_level(1, false)) == 2, "centre réparé niveau 1 : plafond 2")
check(C.should_start(false, nil, false) and not C.should_start(true, nil, false) and not C.should_start(false, true, false)
  and not C.should_start(false, nil, true), "départ : seulement sans centre, une fois, si non coupé")

local function have_of(t) return function(i) return t[i] or 0 end end
local always = function() return true end
local ok, why = C.can_repair({ is_centre = false, wrecked = true }, cost, have_of({}), always, true)
check(not ok and why == "not-centre", "pas un centre")
ok, why = C.can_repair({ is_centre = true, wrecked = false }, cost, have_of({}), always, true)
check(not ok and why == "not-wreck", "déjà réparé")
ok, why = C.can_repair({ is_centre = true, wrecked = true }, cost, have_of({}), always, false)
check(not ok and why == "no-player", "sans joueur")
ok, why = C.can_repair({ is_centre = true, wrecked = true }, cost, have_of({}), function(i) return i ~= cost[2][1] end, true)
check(not ok and why == "unknown-item", "objet de coût inexistant")
ok, why = C.can_repair({ is_centre = true, wrecked = true }, cost, have_of({}), always, true)
check(not ok and why == "no-resources", "rien en poche")
local full = {}
for _, c in ipairs(cost) do full[c[1]] = c[2] end
ok, why = C.can_repair({ is_centre = true, wrecked = true }, cost, have_of(full), always, true)
check(ok and why == nil, "tout en poche")
full[cost[2][1]] = cost[2][2] - 1
ok, why = C.can_repair({ is_centre = true, wrecked = true }, cost, have_of(full), always, true)
check(not ok and why == "no-resources", "un seul matériau en moins suffit à refuser")
check(#C.missing(cost, have_of(full)) == 1 and C.missing(cost, have_of(full))[1][2] == 1, "manque exact : 1")

---------------------------------------------------------------------------------------------------
-- 2. Moteur simulé
---------------------------------------------------------------------------------------------------
local CCN = L.name(L.by_key.command, 1)
local function box(x0, y0, x1, y1) return { left_top = { x = x0, y = y0 }, right_bottom = { x = x1, y = y1 } } end

local function world()
  M.new_world({ patches = {}, p_busy = 0, p_nopath = 0, p_lost = 0 })
  local w = M.world()
  rawset(w.prototypes, CCN, { type = "container", max_health = 3000, collision_box = box(-1.7, -1.7, 1.7, 1.7),
    selection_box = box(-2, -2, 2, 2), collision_mask = w.prototypes["gun-turret"].collision_mask,
    items_to_place_this = { { name = CCN, count = 1 } } })
  _G.game.item_prototypes = setmetatable({}, { __index = function() return {} end })
  M.load_mod()
  M.dispatch(w.on_init)
  return w
end

local function player_created(w)
  M.dispatch(w.events[defines.events.on_player_created], { player_index = 1 })
end
local function stock(w, items)
  for _, c in ipairs(items) do w.player.get_main_inventory().insert({ name = c[1], count = c[2] }) end
end
local function status(force) return remote.call("fo-centre", "status", force or "player") end
local function find_cc(w)
  for _, e in ipairs(w.entities) do if e.valid and e.name == CCN then return e end end
end
local function count_cc(w)
  local n = 0
  for _, e in ipairs(w.entities) do if e.valid and e.name == CCN then n = n + 1 end end
  return n
end

-- 2a. Partie neuve : l'épave naît près du premier joueur, une seule fois.
local w = world()
check(status().wreck == false and status().started == false, "avant le départ : ni épave ni départ fait")
player_created(w)
local wreck = find_cc(w)
check(wreck ~= nil and status().wreck == true and status().started == true, "épave posée au premier joueur")
check(wreck.force.name == "player", "épave de l'équipe du joueur")
check(wreck.position.x == 8 and wreck.position.y == 0, "posée à C.START_OFFSET du joueur")
check(wreck.health == 3000 * C.WRECK_HEALTH, "épave à " .. C.WRECK_HEALTH * 100 .. " % de vie")
check(rawget(wreck, "_minable") == false and rawget(wreck, "_operable") == false, "épave non minable, non ouvrable")
player_created(w)
check(count_cc(w) == 1, "second passage : toujours une seule épave")

local Levels = require("script.levels.levels")
local force = w.forces.player
check(Levels.cc(force) == wreck, "l'épave est enregistrée comme centre de l'équipe")
check(Levels.cc_level(force) == 0, "niveau effectif 0 tant que c'est une épave")
check(L.building_cap(Levels.cc_level(force)) == 1, "aucun plafond offert par l'épave")
local info = Levels.preview(wreck, nil, true)
check(info and not info.ok and info.reason == "wreck", "amélioration du centre refusée : « wreck »")
local okU, reasonU = Levels.start(wreck, w.player)
check(not okU and reasonU == "wreck", "Levels.start refuse aussi")
check(status().cost[1][1] == C.PACK_ITEM, "le coût est publié par l'interface distante")

-- 2b. Réparation : sans matériaux, rien ne change ; avec, payée sur l'inventaire du joueur.
local ok1, r1 = remote.call("fo-centre", "repair", "player", 1)
check(not ok1 and r1 == "no-resources" and status().wreck, "sans matériaux : refus, épave gardée")
local inv = w.player.get_main_inventory()
local pay = C.repair_cost(L)
local partial = {}
for i, c in ipairs(pay) do partial[i] = { c[1], i == 2 and c[2] - 1 or c[2] } end
stock(w, partial)
local ok2, r2 = remote.call("fo-centre", "repair", "player", 1)
check(not ok2 and r2 == "no-resources", "un matériau manque d'une unité : refus")
for _, c in ipairs(pay) do
  check(inv.get_item_count(c[1]) == (c[1] == pay[2][1] and c[2] - 1 or c[2]), "refus : rien prélevé de " .. c[1])
end
stock(w, { { pay[2][1], 1 + 7 } })
local ok3, r3 = remote.call("fo-centre", "repair", "player", 1)
check(ok3 and r3 == "done", "réparation payée : " .. tostring(r3))
check(inv.get_item_count(pay[2][1]) == 7, "exactement le coût prélevé (reste 7)")
check(inv.get_item_count(pay[1][1]) == 0, "paquets prélevés")
check(status().wreck == false and status().repaired == 1, "plus d'épave, un compte de réparation")
check(wreck.health == 3000 and rawget(wreck, "_minable") == true and rawget(wreck, "_operable") == true,
  "centre réparé : vie pleine, minable, ouvrable")
check(Levels.cc_level(force) == 1, "niveau effectif 1 après réparation")
check(L.building_cap(Levels.cc_level(force)) == 2, "plafond 2 après réparation")
local info2 = Levels.preview(wreck, nil, true)
check(info2 and info2.reason ~= "wreck", "plus de refus « wreck » (reste le coût du niveau 2 : " .. tostring(info2 and info2.reason) .. ")")
local ok4, r4 = remote.call("fo-centre", "repair", "player", 1)
check(not ok4 and r4 == "not-wreck", "réparer deux fois : refus")
local okc, why2 = L.check(L.by_key.command, 2, Levels.cc_level(force))
check(okc, "la règle d'amélioration du niveau 2 accepte un centre réparé : " .. tostring(why2))

-- 2c. Migration : un centre déjà posé (sauvegarde 0.6.11, aucun état) est réparé.
w = world()
w.surface.create_entity({ name = CCN, position = { x = 5, y = 5 }, force = "player", raise_built = true })
check(status().wreck == false, "centre existant : aucun état d'épave")
Levels = require("script.levels.levels")
check(Levels.cc_level(w.forces.player) == 1, "centre déjà posé : niveau 1, utilisable sans réparation")
player_created(w)
check(count_cc(w) == 1 and status().wreck == false, "le départ ne pose pas d'épave si l'équipe a un centre")
-- Mise à jour du mod : un état sans épave derrière est effacé.
global.fo.centre.wreck.player = 99999
M.dispatch(w.on_config, { mod_changes = {} })
check(global.fo.centre.wreck.player == nil, "on_configuration_changed efface un état d'épave sans épave derrière")

-- 2d. Épave détruite : l'état disparaît (la recette de départ reste la voie normale).
w = world()
player_created(w)
wreck = find_cc(w)
check(status().wreck, "(nouvelle partie) épave posée")
M.dispatch(w.events[defines.events.on_entity_died], { entity = wreck })
check(status().wreck == false and status().lost == 1, "épave détruite : état effacé")

-- 2d bis. Épave disparue SANS événement (destroy par script), puis un autre centre : l'état périmé ne fige pas le
-- nouveau centre au niveau 0 (relecture statique, 29/10).
w = world()
player_created(w)
wreck = find_cc(w)
wreck.destroy()
check(Levels.cc(w.forces.player) == nil and Levels.cc_level(w.forces.player) == 0, "épave détruite sans événement : plus de centre")
local fresh = w.surface.create_entity({ name = CCN, position = { x = 20, y = 20 }, force = "player", raise_built = true })
check(fresh ~= nil and Levels.cc(w.forces.player) == fresh, "un nouveau centre est enregistré")
check(Levels.cc_level(w.forces.player) == 1 and status().wreck == false, "état périmé ignoré : le nouveau centre est niveau 1")
local infoF = Levels.preview(fresh, nil, true)
check(infoF and infoF.reason ~= "wreck", "le nouveau centre n'est pas refusé comme épave")

-- 2e. Départ coupé (scénarios de banc) et autres forces non touchées.
w = world()
remote.call("fo-centre", "disable_start", true)
player_created(w)
check(find_cc(w) == nil and status().wreck == false, "départ coupé : aucune épave")
remote.call("fo-centre", "disable_start", false)
Levels = require("script.levels.levels")
local fac = w.surface.create_entity({ name = CCN, position = { x = 200, y = 200 }, force = "enemy", raise_built = true })
check(fac and Levels.cc_level(fac.force) == 1 and status(fac.force.name).wreck == false,
  "centre d'une autre force : niveau normal, jamais une épave")

print(string.format("[CENTRE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
