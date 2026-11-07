--[[
  Lot VIDEO MINERAI-SONDE : SEUILS de la règle L9 (shared/team/lot_minerai.lua), en DONNÉES. La règle est pure et ne nomme aucun objet
  (anti-échelle, tests/iag_test.lua §8 bis) : les seuils par ressource vivent ici, lus par script/team/lots_minerai_glue.lua et passés à
  Lm.ores / Lm.role / Lm.reserve, ainsi qu'à P.classify_lot (shared/team/plan.lua) pour le classement d'un lot.

  Source (G42, G43) : le gist saisit un gisement au-dessus d'un seuil PAR RESSOURCE (uranium > 100 000) et au-dessus d'une SOMME de tous
  les minerais du lot (> 1 000 000) : « ne lance jamais une construction au hasard qui viendrait écraser un gisement de minerai précieux
  sur le chemin de croissance » (Directeur Créatif).

  Champs :
    min_tiles  tuiles d'une ressource qui font un lot de minerai par défaut (égal à P.MIN_RES_TILES, contrôlé par tests/plan_test.lua) ;
    tiles      { [ressource] = tuiles } : seuil de tuiles propre à une ressource (vide : le défaut pour toutes) ;
    amount     { [ressource] = quantité } : quantité TOTALE de la ressource dans le lot qui en fait un lot de minerai, même sous le
               seuil de tuiles (uranium : 100 000, soit 10 tuiles de 10 000) ;
    sum        somme des quantités de tous les minerais du lot au-dessus de laquelle le lot est de minerai, quelle que soit la ressource
               (strictement supérieure : 1 000 000) ;
    max_age    âge maximal (ticks) d'un relevé avant qu'il soit refait seul ; nil : un relevé ne vieillit pas, seuls les événements qui
               changent la place (porte fermée, bâtiment détruit, ennemi vu) le refont (G71).
  Une ressource liquide (pétrole brut) n'entre pas dans la somme : le relevé n'additionne que des minerais solides (script/team/lots_minerai_glue.lua,
  Lg.amount).
]]

return {
  min_tiles = 24,
  tiles = {},
  amount = { ["uranium-ore"] = 100000 },
  sum = 1000000,
  max_age = nil,
}
