--[[
  Lot PETROLE : PIÈCES que l'exécutant des chaînes à fluides pose autour de ses machines, en données nommées. Hors de
  shared/ai3 (règle anti-échelle d'IA-G, tests/iag_test.lua §8 : un fichier de décision ne nomme aucun objet du jeu),
  comme les pièces de l'automatisation (shared/team/automatisation_donnees.lua, D.PARTS). Ce ne sont pas des choix : ce
  sont les briques du plan directeur (script/team/build.lua sert les quais par leur coffre « iron-chest », ses tâches
  « remplir » et « vider » le cherchent par ce nom). Machines, extracteurs, recettes, fluides et raccords sont LUS dans
  les prototypes (shared/ai3/fluides.lua, script/ai3/petrole.lua).
  PUR : aucune API Factorio.
]]
local D = {}

D.PIPE = "pipe"
D.CHEST = "iron-chest"
D.ARM = "inserter"
-- Poteaux candidats, dans l'ordre d'essai : le premier dont l'équipe a l'objet au coffre ou la recette ouverte.
D.POLES = { "medium-electric-pole", "small-electric-pole" }

return D
