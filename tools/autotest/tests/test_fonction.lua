-- Lot MESURES : test hors jeu (lua5.2) de tools/autotest/fo-autotest/scenarios/fonction_common.lua sur un moteur simulé.
-- Usage (depuis la racine du mod) : lua5.2 tools/autotest/tests/test_fonction.lua  -> « BILAN : N OK, 0 ECHEC(S) »
package.path = "tools/autotest/fo-autotest/?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end

local LOG = {}
function log(s) LOG[#LOG + 1] = s end
defines = { entity_status = { working = 1, no_ingredients = 2, no_power = 3, full_output = 4, no_ammo = 5,
  waiting_for_source_items = 6, no_fuel = 7 }, inventory = { chest = 1, turret_ammo = 2 } }

local next_un = 0
local ents = {}
local function E(t)
  next_un = next_un + 1
  t.unit_number = next_un
  t.valid = true
  t.force = t.force or "f"
  t.position = t.position or { x = 0, y = 0 }
  t.prototype = t.prototype or {}
  t.get_recipe = t.get_recipe or function() return nil end
  if t.type == "container" then t.get_inventory = function() return { get_contents = function() return {} end } end end
  ents[#ents + 1] = t
  return t
end
local function inv(items)
  return { get_contents = function() return items end, get_item_count = function()
    local n = 0 for _, v in pairs(items) do n = n + v end return n end }
end

local surf = {}
function surf.find_entities_filtered(a)
  local out = {}
  local types = a.type and (type(a.type) == "table" and a.type or { a.type })
  local names = a.name and (type(a.name) == "table" and a.name or { a.name })
  local function has(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end
  for _, e in ipairs(ents) do
    if e.valid and (not a.force or e.force == a.force) and (not types or has(types, e.type)) and (not names or has(names, e.name)) then
      out[#out + 1] = e
    end
  end
  if a.limit then while #out > a.limit do table.remove(out) end end
  return out
end

local stats = { ["iron-plate"] = 0 }
local fobj = { technologies = { a = { researched = true }, b = { researched = false } },
  item_production_statistics = { get_input_count = function(n) return stats[n] or 0 end, get_output_count = function() return 0 end } }
game = { forces = { f = fobj, g = fobj } }

local ELEC = { electric_energy_source_prototype = {} }
-- foreuse -> four A ; tapis b1 -> b2 -> b3, bras tire de b2 et dépose dans four B ; coffre alimenté par une foreuse -> bras -> four C ;
-- four D sans alimenteur ; four E : bras tirant d'un coffre non alimenté
local A = E({ type = "furnace", name = "stone-furnace", status = 1, crafting_speed = 1, products_finished = 0 })
local drill = E({ type = "mining-drill", name = "electric-mining-drill", status = 1, prototype = ELEC, drop_target = A })
local b1 = E({ type = "transport-belt", name = "tb", items = { 4, 4 } })
local b2 = E({ type = "transport-belt", name = "tb", items = { 1, 0 } })
local b3 = E({ type = "transport-belt", name = "tb", items = { 4, 4 } })
b1.belt_neighbours = { inputs = {}, outputs = { b2 } }
b2.belt_neighbours = { inputs = { b1 }, outputs = { b3 } }
b3.belt_neighbours = { inputs = { b2 }, outputs = {} }
local B = E({ type = "furnace", name = "stone-furnace", status = 2, crafting_speed = 1, products_finished = 0 })
E({ type = "inserter", name = "inserter", status = 6, prototype = ELEC, pickup_target = b2, drop_target = B })
local chestF = E({ type = "container", name = "iron-chest" })
E({ type = "mining-drill", name = "burner-mining-drill", status = 1, prototype = {}, drop_target = chestF })
local C = E({ type = "furnace", name = "stone-furnace", status = 2, crafting_speed = 1, products_finished = 0 })
E({ type = "inserter", name = "burner-inserter", status = 6, prototype = {}, pickup_target = chestF, drop_target = C })
local D = E({ type = "furnace", name = "stone-furnace", status = 2, crafting_speed = 1, products_finished = 0 })
local chestN = E({ type = "container", name = "iron-chest" })
local Ef = E({ type = "furnace", name = "stone-furnace", status = 2, crafting_speed = 1, products_finished = 0 })
E({ type = "inserter", name = "inserter", status = 6, prototype = ELEC, pickup_target = chestN, drop_target = Ef })
-- tapis plein sans prise ni sortie
local b4 = E({ type = "transport-belt", name = "tb", items = { 4, 4 } })
b4.belt_neighbours = { inputs = {}, outputs = {} }
for _, b in ipairs({ b1, b2, b3, b4 }) do
  local it = b.items
  b.get_transport_line = function(i) return { get_item_count = function() return it[i] end } end
end
-- électricité : un générateur relié au réseau 7, un pôle réseau 7, un pôle seul (réseau 9), foreuse électrique hors réseau
E({ type = "generator", name = "steam-engine", status = 1, electric_network_id = 7, energy_generated_last_tick = 1000 })
E({ type = "electric-pole", name = "pole", electric_network_id = 7 })
E({ type = "electric-pole", name = "pole", electric_network_id = 9 })
local dr2 = E({ type = "mining-drill", name = "electric-mining-drill", status = 3, prototype = ELEC })
dr2.electric_network_id = 9
drill.electric_network_id = 7
-- tourelles
E({ type = "ammo-turret", name = "gun-turret", status = 5, get_inventory = function() return inv({}) end })
E({ type = "ammo-turret", name = "gun-turret", status = 1, get_inventory = function() return inv({ m = 10 }) end })
-- corps : un inerte, un qui marche
local body1 = E({ type = "character", name = "character", position = { x = 0, y = 0 }, mining_state = { mining = false }, crafting_queue_size = 0 })
body1.get_main_inventory = function() return inv({ ["stone-furnace"] = 3, ["burner-mining-drill"] = 2 }) end
local body2 = E({ type = "character", name = "character", position = { x = 0, y = 0 }, mining_state = { mining = false }, crafting_queue_size = 0 })
body2.get_main_inventory = function() return inv({}) end
local hq = E({ type = "container", name = "fo-team-chest" })
hq.get_inventory = function() return inv({ ["stone-furnace"] = 40, ["iron-plate"] = 99 }) end

local function move(t)
  if t > 0 then body2.position = { x = body2.position.x + 5, y = 0 } end
end

local Fn = require("scenarios/fonction_common")
local st = {}
local forces = { { key = "player", force = "f" }, { key = "azure", force = "g" } }
Fn.sample_all(st, surf, forces, 0)
for t = 1, 4 do move(t) Fn.sample_all(st, surf, forces, t * 1800) end
-- A : 30 plaques en 2 min de jeu (nominal 37,5) : actif à plus de 50 % ; C : une seule
A.products_finished = 30
C.products_finished = 1
stats["iron-plate"] = 31
local ms = Fn.report_all(st, surf, forces, 2, 4 * 1800, {})

local function line(kind, key, minute)
  for i = #LOG, 1, -1 do
    if LOG[i]:find("[FO-FONCTION] " .. kind .. " minute " .. (minute or 2) .. " | " .. key .. " |", 1, true) then return LOG[i] end
  end
end
local function val(l, k) return l and tonumber(l:match(" " .. k .. "=(-?[%d%.]+)")) end

local L = line("fours", "player")
check(L ~= nil, "ligne fours")
check(val(L, "n") == 5, "5 fours comptés : " .. tostring(val(L, "n")))
check(val(L, "n_auto") == 3, "3 fours alimentés (foreuse, tapis, coffre alimenté) : " .. tostring(val(L, "n_auto")))
check(val(L, "n_coffre") == 1 and val(L, "n_main") == 1, "1 coffre non alimenté, 1 four à la main")
check(val(L, "foreuse") == 1 and val(L, "tapis") == 1 and val(L, "coffre_alimente") == 1 and val(L, "coffre") == 1 and val(L, "aucun") == 1,
  "répartition des alimenteurs : " .. tostring(L))
check(val(L, "a50_auto") == 1 and val(L, "a50_main") == 0 and val(L, "a50_coffre") == 0, "seul le four alimenté par foreuse est actif à 50 % : " .. tostring(L))
check(val(L, "prod_auto") == 2 and val(L, "prod_main") == 0, "deux fours alimentés ont produit, aucun four à la main")
check(val(L, "ws_auto") > 0 and val(L, "ws_main") == 0, "relevés working : alimentés > 0, main = 0")
local T = line("tapis", "player")
check(val(T, "tapis") == 4 and val(T, "utiles") == 2, "tapis utiles = b1, b2 (en amont de la prise) : " .. tostring(T))
check(val(T, "pleines") == 3 and val(T, "pleines_inutiles") == 2, "pleines inutiles = b3 (après la prise) et b4 : " .. tostring(T))
check(val(T, "terminaux_pleins_inutiles") == 2, "culs-de-sac pleins sans prise : b3 et b4 : " .. tostring(T))
local EL = line("elec", "player")
check(val(EL, "kw_moy") == 60.0 and val(EL, "reseaux_gen") == 1 and val(EL, "poteaux_reseau_gen") == 1 and val(EL, "poteaux") == 2,
  "électricité : 60 kW, 1 réseau de générateur, 1 pôle sur 2 : " .. tostring(EL))
check(val(EL, "foreuse_elec_pose") == 2 and val(EL, "foreuse_elec_reseau") == 1 and val(EL, "foreuse_elec_alimentes") == 1,
  "foreuses électriques : 2 posées, 1 dans le réseau du générateur, 1 alimentée : " .. tostring(EL))
check(val(EL, "bras_elec_pose") == 2 and val(EL, "bras_elec_reseau") == 0, "bras électriques hors réseau : " .. tostring(EL))
local BR = line("bras", "player")
check(val(BR, "elec") == 2 and val(BR, "therm") == 1, "bras électriques séparés des thermiques : " .. tostring(BR))
local TU = line("tourelles", "player")
check(val(TU, "vides") == 1 and val(TU, "armees") == 1, "tourelles : une vide, une armée : " .. tostring(TU))
local CO = line("corps", "player")
check(val(CO, "corps") == 2 and val(CO, "marche") == 4 and val(CO, "inerte") == 4, "corps : un marche, un inerte : " .. tostring(CO))
local DO = line("dormants", "player")
check(val(DO, "stock_coffre_fours") == 40 and val(DO, "stock_corps_fours") == 3 and val(DO, "stock_corps_foreuses") == 2,
  "stock hors pose : " .. tostring(DO))
check(line("statut", "player") ~= nil, "lignes statut")
local PR = line("prod", "player")
check(val(PR, "pnj") == 2 and val(PR, "morte") == 0, "prod : 2 PNJ, pas morte : " .. tostring(PR))
check(ms.player.fours_a50 == 1, "M.fours_a50")
check(ms.azure.morte == 1, "azure sans entité : morte")
local TE = line("tech", "player")
check(val(TE, "researched") == 1, "technologies terminées lues pareil pour toutes les forces")
check(Fn.median({ 3, 1, 2 }) == 2 and Fn.median({ 1, 2, 3, 4 }) == 2.5 and Fn.median({}) == nil, "médiane")

-- les forces sans corps sont marquées mortes et exclues de la médiane de parité
body1.valid, body2.valid = false, false
LOG = {}
local ms2 = Fn.report_all(st, surf, forces, 3, 5 * 1800, {})
check(ms2.player.morte == 1 and ms2.azure.morte == 1, "forces sans corps marquées mortes")
-- une faction vivante : la médiane de parité l'inclut
local az = E({ type = "character", name = "character", force = "g", mining_state = { mining = false }, crafting_queue_size = 0 })
az.get_main_inventory = function() return inv({}) end
local found
for _, l in ipairs(LOG) do if l:find("parite minute 3 | plaques_min", 1, true) then found = l end end
check(found and found:find("nviv=0", 1, true) and found:find("joueur_vivant=0", 1, true),
  "parité : médiane des vivantes vide, joueur marqué mort : " .. tostring(found))

LOG = {}
local ms3 = Fn.report_all(st, surf, forces, 4, 6 * 1800, {})
check(ms3.azure.morte == 0 and ms3.player.morte == 1, "azure vivante, joueur mort")
local f3
for _, l in ipairs(LOG) do if l:find("parite minute 4 | plaques_min", 1, true) then f3 = l end end
check(f3 and f3:find("nviv=1", 1, true) and f3:find("joueur_vivant=0", 1, true), "parité : 1 faction vivante dans la médiane, joueur mort : " .. tostring(f3))

print(string.format("BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
