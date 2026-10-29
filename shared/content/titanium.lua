--[[
  Lot X1-TITANE (25/10) : le titane de l'âge 11 EN JEU, tel que le scénario X0 le décrit (shared/content/epochs.lua,
  docs/SCENARIO_EPOQUES.md, époque 11). Lua PUR : données et règles, testables hors jeu (tests/titanium_test.lua) ;
  génération des prototypes : prototypes/titanium.lua ; ressources de carte et biome : shared/content/world.lua.

  Rien n'est inventé ici : noms, recettes (ingrédients, produits, durées, catégories), bâtiments (taille, puissance,
  vitesse, catégories, boîtes de fluide) et piles viennent de X. Ce module ne fait que CHOISIR ce qui entre en jeu :

  - la chaîne du titane en 6 étapes (minerai d'ilménite → concentré → laitier titanifère → chloration (chlore de la
    saumure) → réduction de Kroll (magnésium recyclé) → plaque de titane), et son puits à sous-produits : le tungstène
    par voie humide (soude caustique + hydrogène de l'électrolyse de la saumure, même époque, usine chimique) ;
  - les 5 machines dont la chaîne a besoin : four à coke (âge 2), four à arc (6), électrolyseur (8), concentrateur
    (10), réacteur de Kroll (11). Les 4 premières appartiennent à des âges dont le contenu n'est pas en jeu : elles
    arrivent ICI avec le titane (une seule technologie), réduites aux recettes de la chaîne. Visuel PROVISOIRE (copie
    teintée d'une machine vanilla, dit dans leur description) ; SANS niveaux (X leur donne une famille : question S4) ;
  - le coke (âge 2), seul intermédiaire hors de l'âge 11 que la chaîne consomme.

  Règle « déplier » (recettes des bâtiments) : un ingrédient de X qui n'existe pas en jeu (bobine, carbure de
  tungstène...) est remplacé par les ingrédients de SA recette X, à la proportion (récursivement, arrondi au-dessus à la
  fin). Exemple : 1 bobine = 4 fils émaillés + 2 tôles magnétiques = 2 câbles + 1 plastique + 2 aciers + 0,5 pierre.
  Le coût en matière première est celui de X ; seules les étapes intermédiaires manquent. T.expand le fait.

  Hors de ce lot (dit dans fo-logs/2026-10-25_X1/NOTES.md) : composite titane, pack structurel, cryostat (biopolymère,
  graphite, carbure absents) ; brèche d'impact (branche D, et foreuse sur une ressource à deux produits non prouvée) ;
  torchère (âge 4) ; pylône et bras légers, tour d'observation.
]]

local X = require("shared.content.epochs")

local T = {}

-- Objets et fluides de X mis en jeu par ce lot (ordre d'affichage).
T.ITEMS = {
  "fo-ilmenite-ore", "fo-ilmenite-concentrate", "fo-titanium-slag", "fo-titanium-sponge", "fo-titanium-plate",
  "fo-caustic-soda", "fo-magnesium-chloride", "fo-magnesium", "fo-coke",
}
T.FLUIDS = { "fo-brine", "fo-chlorine", "fo-titanium-tetrachloride", "fo-hydrogen" }

-- Recettes de procédé de X mises en jeu (ordre d'affichage), avec le produit principal des recettes à plusieurs
-- produits (icône et nom de la recette).
T.RECIPES = {
  { name = "fo-coke" },
  { name = "fo-ilmenite-concentrate" },
  { name = "fo-ilmenite-smelting", main = "fo-titanium-slag" },
  { name = "fo-brine-electrolysis", main = "fo-chlorine" },
  { name = "fo-chlorination" },
  { name = "fo-kroll-reduction", main = "fo-titanium-sponge" },
  { name = "fo-magnesium-electrolysis", main = "fo-magnesium" },
  { name = "fo-titanium-plate" },
  { name = "fo-wet-tungsten" },
}

-- Machines : nom X, et visuel PROVISOIRE (copie d'une machine vanilla, teinte de l'époque d'origine, d'après la palette
-- de docs/DESIGN_EPOQUES.md §1.5 ; F36, F38 : une teinte ne fait que multiplier).
--   copy : type et nom de la machine vanilla copiée ; side : côté de la machine copiée (tuiles) ;
--   fluid : boîtes de fluide gardées de la copie (indices dans fluid_boxes de la copie) ; pipe_from : machine vanilla
--   dont on prend tuyaux et caches pour une boîte NEUVE (copie sans boîte de fluide).
T.BUILDINGS = {
  { name = "fo-coke-oven", copy = "assembling-machine-1", side = 3, tint = { r = 0.78, g = 0.58, b = 0.46 } },
  { name = "fo-arc-furnace", copy = "assembling-machine-2", side = 3, tint = { r = 0.80, g = 0.93, b = 1.00 } },
  { name = "fo-electrolyzer", copy = "chemical-plant", side = 3, tint = { r = 0.74, g = 0.95, b = 0.58 } },
  { name = "fo-ore-concentrator", copy = "assembling-machine-1", side = 3, tint = { r = 0.72, g = 0.80, b = 0.95 } },
  { name = "fo-kroll-reactor", copy = "centrifuge", side = 3, tint = { r = 0.95, g = 0.94, b = 0.90 },
    pipe_from = "assembling-machine-2" },
}

-- Technologies EN JEU (le pack structurel de X n'est pas en jeu : packs vanilla de l'âge 10, celui de l'utilité).
-- x0 : technologie de X dont elle reprend la partie en jeu.
T.TECHS = {
  { name = "fo-titanium-processing", x0 = "fo-structural-pack", count = 500, time = 30,
    prerequisites = { "utility-science-pack", "fo-tungsten-processing", "oil-processing", "fo-electrical-steel" },
    unlocks = { "fo-coke-oven", "fo-coke", "fo-ore-concentrator", "fo-ilmenite-concentrate", "fo-arc-furnace",
                "fo-ilmenite-smelting", "fo-electrolyzer", "fo-brine-electrolysis", "fo-chlorination", "fo-kroll-reactor",
                "fo-kroll-reduction", "fo-magnesium-electrolysis", "fo-titanium-plate" } },
  { name = "fo-wet-tungsten", x0 = "fo-wet-tungsten", count = 200, time = 30,
    prerequisites = { "fo-titanium-processing" }, unlocks = { "fo-wet-tungsten" } },
}
-- Packs de l'âge 10 en jeu (X : pack de l'époque 10 = utilité ; à partir de l'époque 4 le pack militaire est exigé).
T.PACKS = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack",
            "production-science-pack", "utility-science-pack" }

-- Objets du mod DÉJÀ en jeu avant ce lot (shared/content/world.lua) : ne se déplient pas.
T.ALREADY = { "fo-tungsten-ore", "fo-tungsten-plate", "fo-resonance-crystal", "fo-methane" }
-- Objets mis en jeu APRÈS ce lot par le lot AMELIO-CRAFTS (shared/content/crafts.lua, âge 6 : technologie
-- fo-electrical-steel, prérequis de fo-titanium-processing) : les recettes des bâtiments ne les déplient plus.
T.FROM_CRAFTS = { "fo-coil" }

---------------------------------------------------------------------------------------------------
-- Index de X (construits une fois)
---------------------------------------------------------------------------------------------------
local item_by, recipe_by, building_by, tech_by = {}, {}, {}, {}
for _, it in ipairs(X.items) do item_by[it.name] = it end
for _, r in ipairs(X.recipes) do if not recipe_by[r.name] then recipe_by[r.name] = r end end
for _, b in ipairs(X.buildings) do building_by[b.name] = b end
for _, t in ipairs(X.technologies) do tech_by[t.name] = t end

function T.x_item(name) return item_by[name] end
function T.x_recipe(name) return recipe_by[name] end
function T.x_building(name) return building_by[name] end
function T.x_tech(name) return tech_by[name] end

local IN_GAME = {}
for _, n in ipairs(T.ITEMS) do IN_GAME[n] = true end
for _, n in ipairs(T.FLUIDS) do IN_GAME[n] = true end
for _, b in ipairs(T.BUILDINGS) do IN_GAME[b.name] = true end
for _, n in ipairs(T.ALREADY) do IN_GAME[n] = true end
for _, n in ipairs(T.FROM_CRAFTS) do IN_GAME[n] = true end

--- L'objet existe-t-il en jeu avec ce lot ? (nom vanilla, ou objet du mod en jeu)
function T.present(name)
  return not name:find("^fo%-") or IN_GAME[name] == true
end

--- Recette X (genre « recipe ») qui fabrique `name`, et la quantité produite par fabrication ; nil sinon.
--- La première dans l'ordre de X (ordre des époques), jamais une recette de minage ni de repli.
function T.maker(name)
  for _, r in ipairs(X.recipes) do
    if r.kind == "recipe" or r.kind == "building" or r.kind == nil then
      for _, p in ipairs(r.results or {}) do
        if p[1] == name and not p.p then return r, p[2] end
      end
    end
  end
  return nil
end

--- Règle « déplier » : liste d'ingrédients { {nom, quantité} } -> liste où chaque ingrédient absent du jeu est
--- remplacé par ceux de sa recette X, à la proportion (récursif, profondeur 6 au plus) ; quantités arrondies au-dessus
--- À LA FIN, ordre de première apparition. Renvoie la liste et la trace { {absent, recette} } (ordre de dépliage).
function T.expand(ingredients)
  local acc, order, trace = {}, {}, {}
  local function add(name, q, depth)
    if T.present(name) then
      if not acc[name] then acc[name] = 0; order[#order + 1] = name end
      acc[name] = acc[name] + q
      return
    end
    assert(depth < 6, "titane : dépliage trop profond pour " .. name)
    local r, per = T.maker(name)
    assert(r, "titane : aucune recette X pour l'ingrédient absent " .. name)
    trace[#trace + 1] = { name, r.name }
    for _, ing in ipairs(r.ingredients) do add(ing[1], ing[2] * q / per, depth + 1) end
  end
  for _, ing in ipairs(ingredients) do add(ing[1], ing[2], 0) end
  local out = {}
  for _, n in ipairs(order) do out[#out + 1] = { n, math.ceil(acc[n] - 1e-9) } end
  return out, trace
end

--- Recette en jeu d'un bâtiment de T.BUILDINGS : la recette X du bâtiment, ingrédients dépliés.
function T.building_recipe(name)
  local r = assert(recipe_by[name], "titane : recette X absente pour " .. name)
  local ings, trace = T.expand(r.ingredients)
  return { name = r.name, category = r.category, time = r.time, ingredients = ings, results = r.results, trace = trace }
end

--- Une recette de procédé de T.RECIPES, telle que X la décrit (aucun dépliage : tous ses ingrédients sont en jeu,
--- contrôlé par le banc).
function T.process_recipe(name)
  return assert(recipe_by[name], "titane : recette X absente pour " .. name)
end

--- Catégories de fabrication NEUVES (celles des machines de T.BUILDINGS ; « chemistry » est vanilla).
function T.new_categories()
  local out, seen = {}, {}
  for _, b in ipairs(T.BUILDINGS) do
    for _, c in ipairs(building_by[b.name].categories or {}) do
      if not seen[c] then seen[c] = true; out[#out + 1] = c end
    end
  end
  return out
end

return T
