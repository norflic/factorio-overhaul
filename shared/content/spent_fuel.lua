--[[
  Lot AMELIO-RESSOURCES, piste ÉTAIN (30/10) : le COMBUSTIBLE USÉ de l'âge 9 (X0, technologie fo-spent-fuel) EN JEU, le
  débouché du plomb À SON ÂGE : piscine d'entreposage (20 blindages plombés) où les cellules usées vanilla refroidissent
  10 min ; vitrification au four à arc (2 cellules refroidies + 4 verres → 1 colis vitrifié + 1 uranium 238) ; dépôt
  géologique (50 blindages plombés, coffre de 200 cases) qui reçoit les colis. Voie d'X0 À CÔTÉ du retraitement vanilla
  (qui reste). Le verre vient du lot AMELIO-CRAFTS. Lua PUR (tests/spent_fuel_test.lua) ; prototypes : prototypes/spent_fuel.lua.
]]

local T = require("shared.content.titanium")
local C = require("shared.content.crafts")
local P = require("shared.content.galena")

local F = {}

F.ITEMS = { "fo-cooled-spent-cell", "fo-vitrified-waste" }
F.RECIPES = { { name = "fo-spent-fuel-cooling" }, { name = "fo-vitrification", main = "fo-vitrified-waste" } }
-- Bâtiments : visuel PROVISOIRE (piscine : assembleur 2 agrandi en 4 × 4, teinte eau ; dépôt : coffre d'acier agrandi en
-- 6 × 6, gris béton).
F.BUILDINGS = {
  { name = "fo-cooling-pool", copy = { "assembling-machine", "assembling-machine-2" }, side = 3, tint = { r = 0.55, g = 0.80, b = 1.00 } },
  { name = "fo-geological-repository", copy = { "container", "steel-chest" }, side = 1, tint = { r = 0.62, g = 0.62, b = 0.66 } },
}
F.TECH = { name = "fo-spent-fuel", x0 = "fo-spent-fuel", epoch = 9, count = 150, time = 30,
  prerequisites = { "fo-lead-processing", "nuclear-fuel-reprocessing", "fo-arc-smelting", "fo-glassworks" },
  unlocks = { "fo-cooling-pool", "fo-spent-fuel-cooling", "fo-vitrification", "fo-geological-repository" } }

local IN_GAME = {}
for _, n in ipairs(F.ITEMS) do IN_GAME[n] = true end
for _, b in ipairs(F.BUILDINGS) do IN_GAME[b.name] = true end
function F.present(n) return IN_GAME[n] == true or P.present(n) or C.present(n) end

function F.recipe(n) return assert(T.x_recipe(n), "combustible usé : recette X0 absente " .. n) end
function F.building(n) return assert(T.x_building(n), "combustible usé : bâtiment X0 absent " .. n) end
function F.item(n) return assert(T.x_item(n), "combustible usé : objet X0 absent " .. n) end
function F.tech_count(t) return C.tech_count(t) end
function F.packs(k) return C.packs(k) end

--- Blindages plombés pour une piscine et un dépôt (X0).
function F.shielding_for_buildings()
  local n = 0
  for _, b in ipairs(F.BUILDINGS) do
    for _, i in ipairs(F.recipe(b.name).ingredients) do if i[1] == "fo-lead-shielding" then n = n + i[2] end end
  end
  return n
end

return F
