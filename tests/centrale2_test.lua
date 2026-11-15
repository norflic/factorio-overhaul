-- Lot CENTRALE2 : la centrale de plus demandée pendant la saturation est un but URGENT du cerveau (A.goals, A.PLANT_URGENT).
-- Lancer : lua5.2 tests/centrale2_test.lua (depuis la racine du mod).
package.path = "./?.lua;" .. package.path
local A = require("shared.ai3.automatiser")
local passes, failures = 0, 0
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end end

local function goals_for(urgent)
  local base = { { key = "recherche", value = 70 }, { key = "armee", value = 99 } }
  local auto = { mods = {
    { id = 3, product = "steel-plate", state = "reserve", missing = { { "x", 1 } }, gain = 1 },
    { id = 17, product = "centrale", state = "reserve", missing = { { "y", 2 } }, gain = 0, urgent = urgent },
  } }
  return A.goals(base, auto, {}, nil)
end
local function value_of(gs, key) for _, g in ipairs(gs) do if g.key == key then return g.value end end return nil end

local g0 = goals_for(nil)
check(value_of(g0, "auto:centrale") < 70, "1a : centrale ordinaire sous la recherche (" .. tostring(value_of(g0, "auto:centrale")) .. ")")
local g1 = goals_for(true)
check(value_of(g1, "auto:centrale") == A.PLANT_URGENT, "1b : centrale urgente a A.PLANT_URGENT")
check(g1[2].key == "auto:centrale", "1c : juste apres l'armee, devant la recherche et les modules (" .. tostring(g1[2].key) .. ")")
print(string.format("[CENTRALE2] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
