--[[
  Lot AMELIO-RESSOURCES, piste BAUXITE (30/10) : la chaîne C d'X3 (« monter des machines », âge 6) EN JEU jusqu'à son
  premier usage : bauxite + pierre + eau → alumine + BOUE ROUGE (frittage à la chaux, usine chimique vanilla) ; boue rouge
  → ciment (concasseur d'AMELIO-CRAFTS) ou fer (four à arc) : deux exutoires, aucun sous-produit détruit (D-17) ; alumine
  + anode de graphite → PLAQUE D'ALUMINIUM (cuve d'électrolyse ignée, 6 MW, la plus gourmande de l'âge 6) ; aluminium →
  PYLÔNE HAUTE TENSION à conducteur aluminium-acier (variante d'X3). Le pylône et sa technologie « Haute tension » sont
  ceux du scénario X0 (shared/content/epochs.lua), mis en jeu ici : la variante n'a de sens qu'avec lui.
  Lua PUR (tests/bauxite_test.lua) ; prototypes : prototypes/bauxite.lua ; gisement : shared/content/world.lua (bauxite).

  Rien n'est inventé : noms, recettes, bâtiments et technologies viennent de shared/content/x3.lua (proposition X3, « des
  voies, jamais une porte » : la bauxite n'est jamais obligatoire, aucune recette vanilla ni d'X0 n'est touchée) et, pour
  le pylône, de shared/content/epochs.lua. Dépend du lot AMELIO-CRAFTS (graphite, four à arc, concasseur, ciment, bobine,
  laitier, technologies fo-arc-smelting et fo-electrical-steel).
]]

local X3 = require("shared.content.x3")
local C = require("shared.content.crafts")
local T = require("shared.content.titanium")

local B = {}

B.ORE = "fo-bauxite"
B.ITEMS = { "fo-alumina", "fo-red-mud", "fo-aluminium-plate" }
-- Recettes d'X3 mises en jeu (ordre d'affichage). variant : la recette rend un objet déjà en jeu par une autre voie.
B.RECIPES = {
  { name = "fo-lime-sinter-alumina" },
  { name = "fo-red-mud-cement", variant = "fo-cement" },
  { name = "fo-red-mud-iron", variant = "iron-plate" },
  { name = "fo-hall-heroult" },
  { name = "fo-ht-pylon-aluminium", variant = "fo-ht-pylon" },
}
-- Bâtiments : la cuve (X3 : 4 × 4, 6 MW, « copie teintée du four électrique, étirée en 4 × 4 ») ; le pylône (X0 : 2 × 2,
-- fil de 64, zone d'alimentation 0,5 : un pylône de transport, il n'alimente rien ; copie du grand poteau).
B.BUILDINGS = {
  { name = "fo-reduction-cell", from = "x3", copy = { "furnace", "electric-furnace" }, side = 3,
    tint = { r = 0.80, g = 0.86, b = 0.95 } },
  { name = "fo-ht-pylon", from = "x0", copy = { "electric-pole", "big-electric-pole" }, side = 2,
    tint = { r = 0.78, g = 0.84, b = 0.92 } },
}
-- Technologies : « Haute tension » (X0) puis « Aluminium » (X3). Unités : X0 donne 180 à la haute tension ; X3 ne chiffre pas
-- l'aluminium : 250, celui de la technologie de l'âge 6 la plus chère du lot AMELIO-CRAFTS (fo-electrical-steel), règle
-- QX9 par C.tech_count. Prérequis : ceux d'X0 / X3, tous en jeu.
B.TECHS = {
  { name = "fo-high-voltage", from = "x0", epoch = 6, count = 180, time = 30,
    prerequisites = { "fo-electrical-steel" }, unlocks = { "fo-ht-pylon" } },
  { name = "fo-aluminium", from = "x3", epoch = 6, count = 250, time = 30,
    prerequisites = { "fo-arc-smelting", "fo-electrical-steel", "fo-high-voltage" },
    unlocks = { "fo-reduction-cell", "fo-lime-sinter-alumina", "fo-red-mud-cement", "fo-red-mud-iron", "fo-hall-heroult",
                "fo-ht-pylon-aluminium" } },
}

---------------------------------------------------------------------------------------------------
-- Index d'X3 (et d'X0 pour le pylône)
---------------------------------------------------------------------------------------------------
local item_by, recipe_by, building_by, tech_by = {}, {}, {}, {}
for _, it in ipairs(X3.items) do item_by[it.name] = it end
for _, r in ipairs(X3.recipes) do if not recipe_by[r.name] then recipe_by[r.name] = r end end
for _, b in ipairs(X3.buildings) do building_by[b.name] = b end
for _, t in ipairs(X3.technologies) do tech_by[t.name] = t end

function B.x3_item(n) return item_by[n] end
function B.x3_resource(n)
  for _, r in ipairs(X3.resources) do if r.name == n then return r end end
end
--- Recette (X3, sinon X0 : le pylône et sa recette d'origine).
function B.recipe(n)
  return assert(recipe_by[n] or T.x_recipe(n), "bauxite : recette absente d'X3 et d'X0 " .. n)
end
--- Bâtiment (X3 pour la cuve, X0 pour le pylône).
function B.building(n)
  return assert(building_by[n] or T.x_building(n), "bauxite : bâtiment absent d'X3 et d'X0 " .. n)
end
--- Technologie source (X3 ou X0).
function B.source_tech(t)
  if t.from == "x3" then return tech_by[t.name] end
  return T.x_tech(t.name)
end

local IN_GAME = { [B.ORE] = true }
for _, n in ipairs(B.ITEMS) do IN_GAME[n] = true end
for _, b in ipairs(B.BUILDINGS) do IN_GAME[b.name] = true end

--- En jeu avec ce lot (et CRAFTS, X1) ?
function B.present(name)
  return IN_GAME[name] == true or C.present(name)
end

--- Toutes les recettes du lot : procédés, puis bâtiments (la recette du pylône est celle d'X0).
function B.all_recipes()
  local out = {}
  for _, rr in ipairs(B.RECIPES) do out[#out + 1] = { name = rr.name, variant = rr.variant } end
  for _, b in ipairs(B.BUILDINGS) do out[#out + 1] = { name = b.name, building = true } end
  return out
end

--- Unités et packs de la technologie (règles du lot AMELIO-CRAFTS).
function B.tech_count(t) return C.tech_count(t) end
function B.packs(k) return C.packs(k) end

--- Bilan par plaque d'aluminium (une fabrication de chaque à la proportion) : bauxite, pierre, eau, graphite, boue rouge,
--- et l'énergie de la cuve (kJ).
function B.per_aluminium_plate()
  local hh = B.recipe("fo-hall-heroult")
  local ls = B.recipe("fo-lime-sinter-alumina")
  local cell = B.building("fo-reduction-cell")
  local plates = hh.results[1][2]
  local alumina = hh.ingredients[1][2] / plates
  local graphite = hh.ingredients[2][2] / plates
  local per_alumina = {}
  for _, i in ipairs(ls.ingredients) do per_alumina[i[1]] = i[2] / ls.results[1][2] end
  local mud_per_alumina = ls.results[2][2] / ls.results[1][2]
  return {
    alumina = alumina, graphite = graphite,
    bauxite = alumina * per_alumina["fo-bauxite"], stone = alumina * per_alumina["stone"], water = alumina * per_alumina["water"],
    red_mud = alumina * mud_per_alumina,
    kj = cell.kw * hh.time / (cell.speed or 1) / plates,
  }
end

--- Le pylône : aciers et cuivre économisés par la variante (X3 : « 2 plaques d'aluminium à la place des 4 câbles de cuivre
--- et de 4 aciers »).
function B.pylon_saving()
  local base, alu = B.recipe("fo-ht-pylon"), B.recipe("fo-ht-pylon-aluminium")
  local function count(r, n) for _, i in ipairs(r.ingredients) do if i[1] == n then return i[2] end end return 0 end
  return { steel = count(base, "steel-plate") - count(alu, "steel-plate"),
           cable = count(base, "copper-cable") - count(alu, "copper-cable"),
           aluminium = count(alu, "fo-aluminium-plate") }
end

return B
