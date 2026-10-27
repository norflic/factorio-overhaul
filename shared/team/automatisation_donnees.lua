--[[
  Lot IA3-e : ce que l'EXÉCUTANT (plan directeur d'IA1-d, gabarits de shared/team/modules.lua) sait poser pour
  automatiser, en données nommées. Hors de shared/ai3 (règle anti-échelle d'IA-G, tests/iag_test.lua §8 : un fichier de
  décision ne nomme aucun objet du jeu) : la règle « main ou machine » (shared/ai3/automatiser.lua) les lit comme « ce
  que l'équipe sait faire », comme le cerveau général lit shared/team/config.lua (IA-G, INTEGRATION.md §4).
  PUR : aucune API Factorio.
]]
local D = {}

-- Gabarits écrits (générateurs de shared/team/modules.lua), plus efficaces que la rangée générée depuis la recette :
-- fonderies avec foreuses et tapis, îlots de circuits, packs. ext du gabarit : son paramètre agrandi ; ore : minerai servi
-- par des foreuses ; feed : têtes d'alimentation (« tapis » : voie de minerai par foreuses et tapis seulement).
D.METHODS = {
  { product = "iron-plate", gen = "smelter", args = { "stone-furnace", "iron-ore", 1 }, ore = "iron-ore", feed = "tapis" },
  { product = "copper-plate", gen = "smelter", args = { "stone-furnace", "copper-ore", 1 }, ore = "copper-ore", feed = "tapis" },
  { product = "iron-gear-wheel", gen = "gears", args = { 1, "assembling-machine-1" }, feed = true },
  { product = "electronic-circuit", gen = "circuits", args = { "assembling-machine-1", 1 }, feed = true },
  { product = "firearm-magazine", gen = "simple", args = { "firearm-magazine", 1, "assembling-machine-1" }, feed = true },
  { product = "automation-science-pack", gen = "red_packs", args = { "assembling-machine-1", 1 }, feed = true },
  { product = "logistic-science-pack", gen = "green_packs", args = { "assembling-machine-1", 1 }, feed = true },
}

-- La centrale à vapeur (générateur « steam » de modules.lua), demandée avant le premier module électrique.
D.PLANT = { gen = "steam", args = { 1 } }

-- Machines d'une rangée GÉNÉRÉE depuis une recette, dans l'ordre d'essai (la première dont les catégories contiennent
-- celle de la recette).
D.MACHINES = { "assembling-machine-1", "assembling-machine-2" }

-- Pièces que le plan directeur ajoute autour d'un gabarit (coût d'un module, A.cost) : tapis des foreuses, coffre et bras
-- d'un quai, bras rapide d'un quai de sortie chargé, poteau du réseau.
D.PARTS = { belt = "transport-belt", chest = "iron-chest", arm = "inserter", fast_arm = "fast-inserter",
  pole = "medium-electric-pole" }

return D
