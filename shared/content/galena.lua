--[[
  Lot AMELIO-RESSOURCES (30/10) : la galène et le plomb de l'âge 9 (Atome), puis la chaîne du thorium de l'âge 12 qui
  leur donne leur débouché, EN JEU, tels que le scénario X0 les décrit (shared/content/epochs.lua, docs/SCENARIO_EPOQUES.md).
  Lua PUR : données et règles, testables hors jeu (tests/galena_test.lua) ; prototypes : prototypes/galena.lua ;
  gisement : shared/content/world.lua (galena).

  Rien n'est inventé, sauf les écarts écrits (P.DEVIATIONS) : noms, recettes, bâtiment, combustible et piles viennent de X.

  - Âge 9 : galène (gisements classiques à plus de 300 tuiles) → PLOMB au four (2 galènes, 3,2 s) → BLINDAGE PLOMBÉ
    (3 plombs + 1 acier, assembleur) ; grillage de la galène au four à arc (4 galènes + 20 oxygène → 3 plombs + 1 soufre).
  - Âge 12 (le débouché, D-17 du DC : « sous-produits : leur donner un usage ») : l'OXYDE DE THORIUM du lessivage de la
    monazite (lot X2) devient la CELLULE DE SEL AU THORIUM (usine chimique : 4 oxydes + 1 uranium 235 + 20 chlore), brûlée
    par le RÉACTEUR À SELS FONDUS (5 × 5, 160 MW de chaleur, sans bonus de voisinage ; 200 blindages plombés) ; le sel
    usé se retraite en centrifugeuse (2 sels → 1 oxyde + 1 uranium 238). L'oxygène de l'électrolyse de l'eau (lot X2)
    sert au grillage ; son soufre retourne à l'acide sulfurique du lessivage.

  Hors de ce lot : pack isotopique (aucun pack de X en jeu), irradiateur et branche B, piscine de refroidissement,
  vitrification (verre et sable absents), dépôt géologique.
]]

local X = require("shared.content.epochs")
local T = require("shared.content.titanium")
local S = require("shared.content.superconductors")

local P = {}

P.ORE = "fo-galena"            -- objet du minerai (X : produit de fo-galena) ; la ressource porte le même nom
P.ITEMS = { "fo-lead-plate", "fo-lead-shielding", "fo-thorium-salt-cell", "fo-spent-salt" }
P.FUEL_CATEGORY = "fo-thorium"

-- Recettes de procédé de X mises en jeu (ordre d'affichage) ; main : produit principal d'une recette à plusieurs produits.
P.RECIPES = {
  { name = "fo-lead-plate", epoch = 9 },
  { name = "fo-lead-shielding", epoch = 9 },
  { name = "fo-galena-roasting", epoch = 9, main = "fo-lead-plate" },
  { name = "fo-thorium-salt-cell", epoch = 12 },
  { name = "fo-salt-reprocessing", epoch = 12, main = "fo-thorium-oxide" },
}

-- Bâtiment : réacteur à sels fondus (X : proto reactor, 5 × 5, 160 MW, voisinage 0, 1 000 °C, transfert 1 GW). Visuel
-- PROVISOIRE : le réacteur nucléaire vanilla (même emprise 5 × 5), teinté de la couleur de l'âge 12.
P.REACTOR = { name = "fo-molten-salt-reactor", copy = "nuclear-reactor", tint = { r = 0.62, g = 0.86, b = 1.00 } }

-- Technologies EN JEU (aucun pack de X en jeu : packs vanilla). Unités : la proportion du lot X1 (500 pour X.TECH_UNITS
-- de l'âge 11, 3 760), arrondie à 50 : âge 9 (710) → 100 ; le thorium (âge 12, 5 950 ; trois recettes) → 400 ; le
-- grillage, une recette, comme la voie humide du lot X1 (200).
P.TECHS = {
  { name = "fo-lead-processing", x0 = "fo-isotopic-pack", epoch = 9, count = 100, time = 30,
    prerequisites = { "nuclear-power", "production-science-pack", "military-science-pack" },
    packs = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack",
              "production-science-pack" },
    unlocks = { "fo-lead-plate", "fo-lead-shielding" } },
  { name = "fo-galena-roasting", x0 = "fo-galena-roasting", epoch = 9, count = 200, time = 30,
    prerequisites = { "fo-lead-processing", "fo-superconductors" }, packs = T.PACKS,
    unlocks = { "fo-galena-roasting" } },
  { name = "fo-thorium", x0 = "fo-thorium", epoch = 12, count = 400, time = 30,
    prerequisites = { "fo-lead-processing", "fo-superconductors" }, packs = T.PACKS,
    unlocks = { "fo-thorium-salt-cell", "fo-molten-salt-reactor", "fo-salt-reprocessing" } },
}

-- ÉCARTS au scénario (écrits, comptés par le banc) :
P.DEVIATIONS = {
  ["fo-galena-roasting"] = { kind = "tech",
    why_fr = "âge 9 dans X, mais l'oxygène (électrolyse de l'eau) et le four à arc n'arrivent en jeu qu'aux âges 12 et 11 : la technologie demande les supraconducteurs" },
}

---------------------------------------------------------------------------------------------------
-- Présence en jeu
---------------------------------------------------------------------------------------------------
local IN_GAME = { [P.ORE] = true, [P.REACTOR.name] = true }
for _, n in ipairs(P.ITEMS) do IN_GAME[n] = true end

--- L'objet existe-t-il en jeu avec ce lot (et les lots X1, X2) ?
function P.present(name)
  return IN_GAME[name] == true or S.present(name)
end

--- Recette de procédé de P.RECIPES, telle que X la décrit.
function P.process_recipe(name)
  return assert(T.x_recipe(name), "galène : recette X absente pour " .. name)
end

--- Recette en jeu du réacteur : la recette X, ingrédients dépliés (règle du lot X1 ; tous présents avec ce lot).
function P.reactor_recipe()
  local r = assert(T.x_recipe(P.REACTOR.name), "galène : recette X absente pour le réacteur")
  local ings, trace = T.expand(r.ingredients, P.present)
  return { name = r.name, category = r.category, time = r.time, ingredients = ings, results = r.results, trace = trace }
end

--- Données du réacteur selon X (bâtiment).
function P.reactor_x()
  return assert(T.x_building(P.REACTOR.name), "galène : bâtiment X absent pour le réacteur")
end

--- Combustible : énergie (MJ), catégorie et reste brûlé de la cellule, selon X.
function P.fuel()
  local it = assert(T.x_item("fo-thorium-salt-cell"), "galène : cellule absente de X")
  return { mj = it.fuel, category = it.fuel_category, burnt = it.burnt }
end

--- Pile d'un objet de P.ITEMS selon X.
function P.stack(name)
  return assert(T.x_item(name), "galène : objet X absent " .. name).stack
end

--- Temps de combustion d'une cellule (s) dans le réacteur : énergie / puissance de X.
function P.cell_seconds()
  return P.fuel().mj * 1000 / P.reactor_x().heat_kw
end

---------------------------------------------------------------------------------------------------
-- Bilans matière (banc hors jeu)
---------------------------------------------------------------------------------------------------
--- Galènes par blindage plombé, par la voie du four (sans productivité).
function P.galena_per_shielding()
  local plate = P.process_recipe("fo-lead-plate")
  local sh = P.process_recipe("fo-lead-shielding")
  local galena_per_lead = plate.ingredients[1][2] / plate.results[1][2]
  local lead = 0
  for _, ing in ipairs(sh.ingredients) do if ing[1] == "fo-lead-plate" then lead = ing[2] end end
  return lead * galena_per_lead / sh.results[1][2]
end

--- Oxyde de thorium consommé NET par cellule brûlée, retraitement du sel usé compris (une cellule rend un sel usé).
function P.oxide_net_per_cell()
  local cell = P.process_recipe("fo-thorium-salt-cell")
  local rep = P.process_recipe("fo-salt-reprocessing")
  local need = 0
  for _, ing in ipairs(cell.ingredients) do if ing[1] == "fo-thorium-oxide" then need = ing[2] end end
  local back, salts = 0, 0
  for _, ing in ipairs(rep.ingredients) do if ing[1] == "fo-spent-salt" then salts = ing[2] end end
  for _, r in ipairs(rep.results) do if r[1] == "fo-thorium-oxide" then back = r[2] end end
  return need - back / salts
end

--- Liste des recettes de X (âges 9 à 14) qui consomment le blindage plombé : celles en jeu et celles qui manquent.
function P.shielding_consumers()
  local inside, missing = {}, {}
  for _, r in ipairs(X.recipes) do
    for _, ing in ipairs(r.ingredients or {}) do
      if ing[1] == "fo-lead-shielding" then
        local made = r.results and r.results[1] and r.results[1][1]
        local present = (r.name == P.REACTOR.name) or (made and P.present(made) and r.name ~= "fo-lead-shielding")
        if present then inside[#inside + 1] = r.name else missing[#missing + 1] = r.name end
      end
    end
  end
  return inside, missing
end

return P
