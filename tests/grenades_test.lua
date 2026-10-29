--[[
  Lot GRENADES (retour du DC du 29/10, 0.6.13) : l'équipe ne FABRIQUE plus de grenades (un soldat à attaque de zone n'est
  plus l'équipement choisi). Usage, depuis la racine du mod : lua5.2 tests/grenades_test.lua
    §1 échelle des soldats : jamais le grenadier tant que T.zone_units est faux, à aucun niveau ;
    §2 le plan d'armée d'une équipe de niveau 2 et plus, riche : on entraîne un soldat sans zone, aucune grenade voulue ni
       fabriquée ;
    §3 l'interrupteur T.zone_units rend l'ancien comportement (le test échoue sans lui, il prouve que §1 et §2 mesurent bien) ;
    §4 projets du cerveau (EMIT.army) : même échelle (Planner.best_unit).
]]
package.path = "./?.lua;" .. package.path
local Planner = require("shared.team.planner")
local Book = require("shared.team.book")
local T = require("shared.team.config")
local F = require("shared.faction.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- Objets qu'un kit de soldat de zone demande (lus à la donnée : le kit du soldat dont le drapeau `rocket` est vrai).
local zone_items = {}
for _, key in ipairs(F.soldier_order) do
  if F.soldiers[key].rocket then
    for _, it in ipairs(T.kits[key]) do zone_items[it[1]] = true end
  end
end
check(next(zone_items) ~= nil, "la donnée désigne au moins un soldat de zone (sinon ce test ne mesure rien)")
check(zone_items["grenade"], "le kit du soldat de zone contient des grenades")

---------------------------------------------------------------------------------------------------
print("== 1. échelle des soldats")
for tech = 0, 15 do
  local u = Planner.best_unit(tech)
  check(not Planner.zone_unit(u), "niveau " .. tech .. " : " .. u .. " n'est pas un soldat de zone")
end
check(Planner.best_unit(0) == "rifleman" and Planner.best_unit(1) == "gunner", "niveaux 0 et 1 inchangés")
check(Planner.best_unit(2) == "gunner" and Planner.best_unit(9) == "gunner", "niveau 2 et plus : le mitrailleur (barreau d'avant)")

---------------------------------------------------------------------------------------------------
print("== 2. plan d'armée")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local function view(tech)
  return {
    tech = tech, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {},
    outposts = {}, pending = {}, sites = {}, smelters = 0, smelters_pending = 0, smelter_task = false,
    smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0, turret_groups = {},
    soldiers = 0, soldiers_max = 100, workers = 10, workers_max = 30, workers_idle = 0, threatened = true, open = {},
    workers_wanted = 30, recruit_cost = {}, recover_floor = 8, no_research = true,
  }
end
local function rich()
  return { ["iron-plate"] = 4000, ["copper-plate"] = 1000, coal = 2000, stone = 500, pistol = 5,
    ["firearm-magazine"] = 200, ["submachine-gun"] = 20, ["piercing-rounds-magazine"] = 100, ["light-armor"] = 20,
    grenade = 40 }
end
local function mentions_zone(plan)
  local seen = {}
  local function scan(list)
    for _, e in ipairs(list or {}) do
      local n = type(e) == "table" and (e.item or e.name or e[1]) or e
      if zone_items[n] then seen[#seen + 1] = n end
    end
  end
  for _, t in ipairs(plan.tasks) do scan(t.items); scan(t.craft); if t.item then scan({ t.item }) end end
  for k in pairs(plan.missing or {}) do if zone_items[k] then seen[#seen + 1] = k end end
  if plan.train and plan.train.uses then for _, u in ipairs(plan.train.uses) do scan({ u }) end end
  return seen
end
for _, tech in ipairs({ 2, 3, 5 }) do
  local v = view(tech)
  v.stock = rich()
  local plan = Planner.plan(v, book)
  check(plan.train ~= nil, "niveau " .. tech .. " : un lot de soldats part à l'entraînement")
  check(plan.train and not Planner.zone_unit(plan.train.unit), "niveau " .. tech .. " : soldat entraîné sans zone ("
    .. tostring(plan.train and plan.train.unit) .. ")")
  check(#mentions_zone(plan) == 0, "niveau " .. tech .. " : aucune grenade voulue ni fabriquée dans le plan")
  -- Même sans grenade au stock : le plan ne la réclame pas (cas du DC : « des grenades ont été produites »).
  local v2 = view(tech)
  v2.stock = rich()
  v2.stock.grenade = nil
  local p2 = Planner.plan(v2, book)
  check(#mentions_zone(p2) == 0, "niveau " .. tech .. " : sans grenade au stock, aucune n'est demandée")
end

---------------------------------------------------------------------------------------------------
print("== 3. interrupteur (ancien comportement)")
T.zone_units = true
check(Planner.best_unit(2) == "rocketeer", "T.zone_units vrai : le grenadier revient au niveau 2")
local vz = view(2)
vz.stock = rich()
local pz = Planner.plan(vz, book)
check(pz.train and Planner.zone_unit(pz.train.unit), "T.zone_units vrai : le plan entraîne le grenadier")
local vz2 = view(2)
vz2.stock = rich()
vz2.stock.grenade = nil
local pz2 = Planner.plan(vz2, book)
check(#mentions_zone(pz2) > 0 or (pz2.train and pz2.train.unit == "rocketeer"),
  "T.zone_units vrai, sans grenade au stock : le plan en réclame ou entraîne le grenadier (la sonde du §2 est sensible)")
T.zone_units = false
check(Planner.best_unit(2) == "gunner", "T.zone_units remis à faux")

---------------------------------------------------------------------------------------------------
print("== 4. projets du cerveau (échelle commune)")
local Projets = require("shared.ai3.projets")
check(Projets.FALLBACK_UNIT == "rifleman", "soldat de repli inchangé")
for tech = 0, 6 do
  check(not Planner.zone_unit(Planner.best_unit(tech)), "projets : niveau " .. tech .. " sans soldat de zone")
end

print(string.format("[GRENADES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
