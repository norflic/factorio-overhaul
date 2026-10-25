--[[
  IA3 (conception) : bouchon des PROTOTYPES D'ENTITÉS et des pseudo-recettes, pour le prototype pur du cerveau
  générique (shared/ai3/graphe.lua) et son test hors jeu (tests/ai3_graphe_test.lua). Ce n'est PAS du code par
  bâtiment : c'est la donnée qu'en jeu le cerveau lira dans game.entity_prototypes (crafting_categories,
  resource_categories, electric_energy_source_prototype, burner_prototype, lab_inputs) et dans les prototypes des
  ressources, chaudières et générateurs. Valeurs relevées dans data/base/prototypes/entity (1.1.91) et dans
  X.base_machines (shared/content/epochs.lua) ; seules les catégories et la source d'énergie servent au prototype.

  Pseudo-catégories (préfixe « ai3- ») : la pompe de rive extrait l'eau (« ai3-offshore »), la chaudière fait de la
  vapeur (« ai3-boiling »), la machine à vapeur fait de l'électricité (« ai3-generating ») ; l'électricité est un
  fluide de pseudo-nom « ai3-electricity ».
]]

return {
  hand_categories = { crafting = true },
  fuel = "coal",
  electricity = "ai3-electricity",
  machines = {
    { name = "character", hand = true, crafting_categories = { "crafting" }, resource_categories = { "basic-solid" }, energy = "none" },
    { name = "stone-furnace", crafting_categories = { "smelting" }, energy = "burner" },
    { name = "steel-furnace", crafting_categories = { "smelting" }, energy = "burner" },
    { name = "electric-furnace", crafting_categories = { "smelting" }, energy = "electric" },
    { name = "assembling-machine-1", crafting_categories = { "crafting", "basic-crafting", "advanced-crafting" }, energy = "electric" },
    { name = "assembling-machine-2", crafting_categories = { "basic-crafting", "crafting", "advanced-crafting", "crafting-with-fluid" }, energy = "electric" },
    { name = "assembling-machine-3", crafting_categories = { "basic-crafting", "crafting", "advanced-crafting", "crafting-with-fluid" }, energy = "electric" },
    { name = "chemical-plant", crafting_categories = { "chemistry" }, energy = "electric" },
    { name = "oil-refinery", crafting_categories = { "oil-processing" }, energy = "electric" },
    { name = "centrifuge", crafting_categories = { "centrifuging" }, energy = "electric" },
    { name = "burner-mining-drill", resource_categories = { "basic-solid" }, energy = "burner" },
    { name = "electric-mining-drill", resource_categories = { "basic-solid" }, energy = "electric" },
    { name = "pumpjack", resource_categories = { "basic-fluid" }, energy = "electric" },
    { name = "offshore-pump", resource_categories = { "ai3-offshore" }, energy = "none" },
    { name = "boiler", crafting_categories = { "ai3-boiling" }, energy = "burner" },
    { name = "steam-engine", crafting_categories = { "ai3-generating" }, energy = "none" },
    { name = "lab", lab = true, energy = "electric" },
  },
  resources = {
    ["iron-ore"] = { category = "basic-solid" },
    ["copper-ore"] = { category = "basic-solid" },
    ["coal"] = { category = "basic-solid" },
    ["stone"] = { category = "basic-solid" },
    ["uranium-ore"] = { category = "basic-solid" },
    ["crude-oil"] = { category = "basic-fluid" },
    ["water"] = { category = "ai3-offshore" },
  },
  pseudo_recipes = {
    ["ai3-boil-water"] = { category = "ai3-boiling", energy = 1, hidden = false,
      ingredients = { { type = "fluid", name = "water", amount = 60 } }, products = { { type = "fluid", name = "steam", amount = 60 } } },
    ["ai3-generate"] = { category = "ai3-generating", energy = 1, hidden = false,
      ingredients = { { type = "fluid", name = "steam", amount = 30 } }, products = { { type = "fluid", name = "ai3-electricity", amount = 900 } } },
  },
}
