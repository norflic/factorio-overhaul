--[[
  Lot X2 (25/10) : les ressources de l'âge 12 (Supraconducteurs) EN JEU, telles que le scénario X0 les décrit
  (shared/content/epochs.lua, docs/SCENARIO_EPOQUES.md, époque 12). Lua PUR : données et règles, testables hors jeu
  (tests/superconductors_test.lua) ; génération des prototypes : prototypes/superconductors.lua ; ressource de carte et
  biome : shared/content/world.lua (monazite, sables noirs).

  Rien n'est inventé ici, sauf UN écart écrit (S.DEVIATIONS) : noms, recettes (ingrédients, produits, durées,
  catégories), bâtiments (taille, puissance, vitesse, catégories, boîtes de fluide) et piles viennent de X. Ce module
  CHOISIT ce qui entre en jeu : la chaîne de la MONNAIE de l'âge 12, la bobine supraconductrice (X.currencies, époque
  12), et ce qu'elle demande :

  - monazite (sables noirs) → concentré (concentrateur, lot X1) → lessivage (usine chimique, acide sulfurique) →
    concentré de terres rares + oxyde de thorium → extraction par solvant (colonne d'extraction, huile légère) →
    néodyme + YTTRIUM → ruban supraconducteur YBCO (four de frittage : yttrium + cuivre + oxygène) → BOBINE
    (bobineuse : 4 rubans + 1 cryostat + 20 azote liquide) ;
  - azote liquide (et oxygène liquide) : distillation de l'air, sans ingrédient (unité cryogénique) ;
  - oxygène : électrolyse de l'eau (âge 8 dans X ; électrolyseur du lot X1), qui rend aussi de l'hydrogène ;
  - cryostat (âge 11 dans X) : plaque de titane + 2 biopolymères + 1 processeur ; le biopolymère (âge 8, chaîne des
    cultures méthanotrophes du marais) n'est PAS en jeu : écart S.DEVIATIONS (plastique à sa place) ;
  - aimant permanent (four de frittage : néodyme + fer) : seul débouché en jeu du néodyme (X : pack magnétique,
    locomotive maglev, turbines ; pas en jeu).

  Machines (stats de X, visuel PROVISOIRE, SANS niveaux comme au lot X1) : unité cryogénique (12), colonne d'extraction
  (12), four de frittage (5), bobineuse (6). Le four de frittage et la bobineuse appartiennent à des âges dont le contenu
  n'est pas en jeu : ils arrivent ICI avec la technologie de l'âge 12, réduits aux recettes de la chaîne (comme le four
  à coke ou le four à arc au lot X1).

  Hors de ce lot (dit dans fo-logs/2026-10-25_X2/NOTES.md) : pack magnétique (aucun pack de X n'est en jeu, X1 non
  plus), réacteur à sels fondus et chaîne du thorium (cellule, sel usé, retraitement : seul débouché de l'oxyde de
  thorium), hélium (gaz volcanique de l'âge 5 absent), accumulateur supraconducteur, cellules SMES, locomotive maglev,
  torchère (âge 4 : l'oxygène liquide n'a aucun débouché à l'âge 12), branche A (haloscope, veine de caustique).
]]

local X = require("shared.content.epochs")
local T = require("shared.content.titanium")

local S = {}

-- Objets et fluides de X mis en jeu par ce lot (ordre d'affichage). Le minerai de monazite est créé avec son gisement
-- (prototypes/world.lua).
S.ITEMS = {
  "fo-monazite-concentrate", "fo-rare-earth-concentrate", "fo-thorium-oxide", "fo-neodymium", "fo-yttrium",
  "fo-superconducting-tape", "fo-permanent-magnet", "fo-cryostat", "fo-superconducting-coil",
}
S.FLUIDS = { "fo-oxygen", "fo-liquid-nitrogen", "fo-liquid-oxygen" }
-- Objets du mod déjà en jeu avant ce lot (shared/content/world.lua) : la monazite est ajoutée par ce lot à world.lua.
S.ORE = "fo-monazite-ore"

-- Recettes de procédé de X mises en jeu (ordre d'affichage), avec le produit principal des recettes à plusieurs produits.
S.RECIPES = {
  { name = "fo-monazite-concentrate" },
  { name = "fo-monazite-leaching", main = "fo-rare-earth-concentrate" },
  { name = "fo-solvent-extraction", main = "fo-yttrium" },
  { name = "fo-air-distillation", main = "fo-liquid-nitrogen" },
  { name = "fo-water-electrolysis", main = "fo-oxygen" },
  { name = "fo-superconducting-tape" },
  { name = "fo-permanent-magnet" },
  { name = "fo-cryostat" },
  { name = "fo-superconducting-coil" },
}

-- ÉCART au scénario (le seul) : le biopolymère (PHB, monnaie de l'âge 8, fait de cultures méthanotrophes nées d'un
-- échantillon de vase ramassé à la main dans le marais) n'est pas en jeu, et la règle « déplier » ne s'applique pas (la
-- culture vient d'une cueillette, sans recette). Le plastique (monnaie de l'âge 4, le polymère vanilla) prend sa place,
-- au même nombre : valeur du cryostat 101 MU au lieu de 103 (X.currencies : biopolymère 4, plastique 3, plaque de
-- titane 20, processeur 75), soit 2 % de moins. À rétablir quand l'âge 8 sera en jeu.
S.DEVIATIONS = {
  ["fo-cryostat"] = { replace = { ["fo-biopolymer"] = "plastic-bar" },
    why_fr = "biopolymère (âge 8) absent du jeu : plastique (polymère vanilla) au même nombre, valeur -2 %" },
}

-- Machines : nom X, et visuel PROVISOIRE (copie d'une machine vanilla, teinte de l'époque d'origine ; F36, F38 : une
-- teinte ne fait que multiplier).
--   copy : machine vanilla copiée ; side : son côté (tuiles) ; keep_fluid_boxes : garder les boîtes de fluide de la copie
--   (la raffinerie a exactement les 2 entrées et 3 sorties de l'unité cryogénique) ; sinon boîtes de X (lot X1).
S.BUILDINGS = {
  { name = "fo-cryogenic-unit", copy = "oil-refinery", side = 5, keep_fluid_boxes = true, tint = { r = 0.70, g = 0.86, b = 1.00 } },
  { name = "fo-extraction-column", copy = "chemical-plant", side = 3, tint = { r = 0.95, g = 0.86, b = 0.55 } },
  { name = "fo-sintering-furnace", copy = "assembling-machine-3", side = 3, tint = { r = 1.00, g = 0.66, b = 0.48 } },
  { name = "fo-coil-winder", copy = "assembling-machine-1", side = 3, tint = { r = 0.62, g = 0.80, b = 1.00 } },
}

-- Technologies EN JEU (aucun pack de X n'est en jeu : packs vanilla de l'âge 10, comme au lot X1). Unités : celles du
-- lot X1 (500 pour la technologie de l'âge 11) à la proportion de X.TECH_UNITS (âge 12 : 5 950 / 3 760) ; le cryostat,
-- une seule recette, comme la voie humide du lot X1 (200).
--   x0 : technologie de X dont elle reprend la partie en jeu.
S.TECHS = {
  { name = "fo-cryostat", x0 = "fo-cryostat", count = 200, time = 30,
    prerequisites = { "fo-titanium-processing" }, unlocks = { "fo-cryostat" } },
  { name = "fo-superconductors", x0 = "fo-magnetic-pack", count = 800, time = 30,
    prerequisites = { "fo-cryostat", "advanced-oil-processing" },
    unlocks = { "fo-monazite-concentrate", "fo-extraction-column", "fo-monazite-leaching", "fo-solvent-extraction",
                "fo-cryogenic-unit", "fo-air-distillation", "fo-water-electrolysis", "fo-sintering-furnace",
                "fo-superconducting-tape", "fo-permanent-magnet", "fo-coil-winder", "fo-superconducting-coil" } },
}
S.PACKS = T.PACKS

---------------------------------------------------------------------------------------------------
-- Présence en jeu (ce lot, plus le titane du lot X1 et le monde)
---------------------------------------------------------------------------------------------------
local IN_GAME = {}
for _, n in ipairs(S.ITEMS) do IN_GAME[n] = true end
for _, n in ipairs(S.FLUIDS) do IN_GAME[n] = true end
for _, b in ipairs(S.BUILDINGS) do IN_GAME[b.name] = true end
IN_GAME[S.ORE] = true

--- L'objet existe-t-il en jeu avec ce lot (et le lot X1) ?
function S.present(name)
  return IN_GAME[name] == true or T.present(name)
end

--- Recette en jeu d'un bâtiment de S.BUILDINGS : la recette X, ingrédients dépliés (règle du lot X1).
function S.building_recipe(name)
  local r = assert(T.x_recipe(name), "supraconducteurs : recette X absente pour " .. name)
  local ings, trace = T.expand(r.ingredients, S.present)
  return { name = r.name, category = r.category, time = r.time, ingredients = ings, results = r.results, trace = trace }
end

--- Une recette de procédé de S.RECIPES : celle de X, avec l'écart de S.DEVIATIONS s'il y en a un (copie : X n'est
--- jamais modifié). Renvoie la recette et l'écart (nil sinon).
function S.process_recipe(name)
  local r = assert(T.x_recipe(name), "supraconducteurs : recette X absente pour " .. name)
  local dev = S.DEVIATIONS[name]
  if not dev then return r, nil end
  local c = {}
  for k, v in pairs(r) do c[k] = v end
  c.ingredients = {}
  for i, ing in ipairs(r.ingredients) do
    c.ingredients[i] = { dev.replace[ing[1]] or ing[1], ing[2] }
  end
  return c, dev
end

--- Catégories de fabrication NEUVES (celles des machines de S.BUILDINGS).
function S.new_categories()
  local out, seen = {}, {}
  for _, b in ipairs(S.BUILDINGS) do
    for _, c in ipairs(T.x_building(b.name).categories or {}) do
      if not seen[c] then seen[c] = true; out[#out + 1] = c end
    end
  end
  return out
end

--- Machine de X qui fait une recette de procédé : celle de S.BUILDINGS ou du lot X1 dont les catégories la contiennent,
--- sinon le nom de la catégorie (vanilla : « chemistry » → usine chimique, « crafting » → assembleur).
function S.machine_for(recipe_name)
  local r = S.process_recipe(recipe_name)
  for _, list in ipairs({ S.BUILDINGS, T.BUILDINGS }) do
    for _, b in ipairs(list) do
      for _, c in ipairs(T.x_building(b.name).categories or {}) do
        if c == r.category then return b.name end
      end
    end
  end
  return r.category
end

---------------------------------------------------------------------------------------------------
-- Bilan matière de la monnaie (banc hors jeu, NOTES) : ce qu'il faut par bobine, et les sous-produits.
---------------------------------------------------------------------------------------------------
--- Quantités par bobine supraconductrice (une fabrication de chaque recette à la proportion) : table nom -> quantité,
--- positive = consommée, négative = rendue en sous-produit. Ne déplie que les recettes de S.RECIPES.
function S.per_coil()
  local need = {}
  local function add(n, q) need[n] = (need[n] or 0) + q end
  local made_by = {}
  for _, rr in ipairs(S.RECIPES) do
    local r = S.process_recipe(rr.name)
    local main = rr.main or r.results[1][1]
    for _, p in ipairs(r.results) do
      if p[1] == main then made_by[main] = { r = r, per = p[2] } end
    end
  end
  local function make(n, q, depth)
    local m = made_by[n]
    if not m or depth > 8 then add(n, q); return end
    local k = q / m.per
    for _, ing in ipairs(m.r.ingredients) do make(ing[1], ing[2] * k, depth + 1) end
    for _, p in ipairs(m.r.results) do
      if p[1] ~= n then add(p[1], -p[2] * k) end
    end
  end
  make("fo-superconducting-coil", 1, 0)
  return need
end

return S
