-- Lot DEFENSE-FACTIONS : une équipe en guerre qui perd des pièces face à une autre équipe met en tête les recherches qui renforcent ses
-- tourelles ou débloquent une munition (shared/ai3/general.lua, ctx.war ; poids lu par shared/ai3/catalogue.lua, techs[t].war).
-- Lancer : lua5.2 tests/guerre_recherche_test.lua
package.path = "./?.lua;" .. package.path
local Gen = require("shared.ai3.general")
local R = require("shared.ai3.reglages")

local passes, failures = 0, 0
local function check(c, msg)
  if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- 1. Valeur : une recherche de guerre (war = 2) vaut 2 x Gen.V_WAR de plus en guerre, rien hors guerre.
local cat = { techs = { t1 = { unlocks = {}, bonus = {}, war = 2 }, t0 = { unlocks = {}, bonus = {}, war = 0 } }, products = {}, role = {} }
local ev, state = { feas = {} }, { techs = {} }
local v_peace = Gen.value(cat, ev, state, "t1", {})
local v_war, why = Gen.value(cat, ev, state, "t1", { war = true })
local v_other = Gen.value(cat, ev, state, "t0", { war = true })
check(v_war - v_peace == 2 * Gen.V_WAR, "guerre : +2 x V_WAR (" .. tostring(v_war - v_peace) .. ")")
check(v_other == Gen.value(cat, ev, state, "t0", {}), "recherche sans effet de guerre : inchangée en guerre")
local tagged = false
for _, w in ipairs(why) do if w[1] == "guerre" then tagged = true end end
check(tagged, "raison « guerre » écrite")

-- 2. Les effets de guerre sont des types du moteur, rangés dans le seul fichier nommé (reglages.lua).
check(R.WAR_EFFECT["turret-attack"] and R.WAR_EFFECT["ammo-damage"] and R.WAR_EFFECT["gun-speed"] and not R.WAR_EFFECT["laboratory-speed"],
  "R.WAR_EFFECT : dégâts et cadence des tourelles, pas les bonus de production")
check(R.ITEM_AMMO == "ammo", "munition = type d'objet du moteur")

-- 3. Catalogue : le poids de guerre se lit au relevé (effets + recettes débloquées qui produisent une munition).
local K = require("shared.ai3.catalogue")
local dump = {
  recipes = {
    ["m-fort"] = { category = "crafting", energy = 1, enabled = false, ingredients = { { type = "item", name = "plaque", amount = 1 } },
      products = { { type = "item", name = "munition-forte", amount = 1 } } },
    ["outil"] = { category = "crafting", energy = 1, enabled = false, ingredients = { { type = "item", name = "plaque", amount = 1 } },
      products = { { type = "item", name = "outil", amount = 1 } } },
  },
  techs = {
    ["armes-2"] = { count = 10, time = 5, ingredients = {}, prerequisites = {}, unlocks = { "m-fort" }, effects = { "ammo-damage" } },
    ["outils"] = { count = 10, time = 5, ingredients = {}, prerequisites = {}, unlocks = { "outil" }, effects = { "laboratory-speed" } },
  },
  entities = {}, resources = {},
  items = { ["munition-forte"] = { type = "ammo" }, ["outil"] = { type = "item" }, ["plaque"] = { type = "item" } },
}
local ok, c = pcall(K.build, dump, {})
check(ok, "catalogue construit (" .. tostring(not ok and c or "") .. ")")
if ok then
  check(c.techs["armes-2"].war == 2, "armes-2 : effet ammo-damage + munition débloquée = 2 (" .. tostring(c.techs["armes-2"].war) .. ")")
  check(c.techs["outils"].war == 0, "outils : 0")
end

print(string.format("[GUERRE-RECHERCHE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
