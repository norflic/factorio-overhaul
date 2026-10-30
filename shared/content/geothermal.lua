--[[
  Lot AMELIO-RESSOURCES, piste GÉOTHERMIE (30/10) : la fumerolle de l'âge 5 (scénario X0) EN JEU : fumerolle (fluide
  infini des cendres volcaniques, catégorie propre) → capteur géothermique (foreuse à sortie de fluide) → GAZ VOLCANIQUE
  (300 °C) → séparation à l'usine chimique : VAPEUR à 165 °C (machines à vapeur vanilla : de l'électricité sans
  combustible) et SOUFRE ; ou torchère (lot AMELIO-CRAFTS). Le capteur consomme 4 MANOMÈTRES : un second débouché du
  manomètre d'AMELIO-CRAFTS (le premier : la torchère).
  Lua PUR (tests/geothermal_test.lua) ; prototypes : prototypes/geothermal.lua ; gisement : shared/content/world.lua
  (fumarole).

  Rien n'est inventé : noms, recettes, bâtiment et technologie viennent de shared/content/epochs.lua (X0). Dépend du lot
  AMELIO-CRAFTS (manomètre, torchère, technologies fo-glassworks et fo-flaring) et du tungstène (plaque, M0).
]]

local C = require("shared.content.crafts")
local T = require("shared.content.titanium")

local Gt = {}

Gt.RESOURCE = "fo-fumarole"
Gt.FLUID = "fo-volcanic-gas"
Gt.RECIPES = {
  { name = "fo-volcanic-gas-separation" },
  { name = "fo-flare-volcanic-gas", flare = true },
}
-- Capteur géothermique (X0 : mining-drill 3 × 3, 300 kW, vitesse 1, catégorie fo-fumarole, sortie de fluide) : visuel
-- PROVISOIRE, le chevalet de pompage vanilla (une foreuse à sortie de fluide prouvée) teinté soufre et cendre.
Gt.BUILDINGS = {
  { name = "fo-geothermal-tap", copy = { "mining-drill", "pumpjack" }, tint = { r = 0.95, g = 0.82, b = 0.62 } },
}
-- Technologie d'X0 (âge 5, 290 unités) ; prérequis en jeu : la plaque de tungstène (ingrédient du capteur), la verrerie
-- (manomètre) et la torchère (sa recette pour le gaz volcanique). X0 n'en donne pas : c'est la règle de x3_test (un objet
-- du même âge requis hors des prérequis est un défaut).
Gt.TECH = { name = "fo-geothermal", epoch = 5, count = 290, time = 30,
  prerequisites = { "fo-tungsten-processing", "fo-glassworks", "fo-flaring" },
  unlocks = { "fo-geothermal-tap", "fo-volcanic-gas-separation", "fo-flare-volcanic-gas" } }

function Gt.recipe(n) return assert(T.x_recipe(n), "géothermie : recette X0 absente " .. n) end
function Gt.building(n) return assert(T.x_building(n), "géothermie : bâtiment X0 absent " .. n) end
function Gt.x_tech() return T.x_tech(Gt.TECH.name) end
function Gt.x_item(n) return T.x_item(n) end
function Gt.x_resource()
  for _, r in ipairs(require("shared.content.epochs").resources) do if r.name == Gt.RESOURCE then return r end end
end

local IN_GAME = { [Gt.RESOURCE] = true, [Gt.FLUID] = true }
for _, b in ipairs(Gt.BUILDINGS) do IN_GAME[b.name] = true end
-- La plaque de tungstène est en jeu depuis M0 (shared/content/world.lua, tungsten.plate).
IN_GAME["fo-tungsten-plate"] = true

function Gt.present(name) return IN_GAME[name] == true or C.present(name) end

function Gt.tech_count(t) return C.tech_count(t) end
function Gt.packs(k) return C.packs(k) end

--- Bilan d'un capteur sur une fumerolle à `yield_share` (1 = 100 %) : gaz/s, vapeur/s, soufre/s, puissance des machines
--- à vapeur (kW : 30 vapeurs/s à 165 °C font 900 kW, data/base : steam-engine), usines chimiques nécessaires.
function Gt.per_tap(yield_share, mining_yield)
  local b = Gt.building("fo-geothermal-tap")
  local mine = Gt.recipe("fo-capture-fumarole")
  local sep = Gt.recipe("fo-volcanic-gas-separation")
  local gas = (mining_yield or mine.results[1][2]) * (yield_share or 1) * b.mining_speed / mine.time
  local per = gas / sep.ingredients[1][2]
  local steam = per * sep.results[1][2] / sep.time
  local sulfur = per * sep.results[2][2] / sep.time
  return { gas = gas, steam = steam, sulfur = sulfur, kw = steam / 30 * 900, plants = per * sep.time }
end

return Gt
