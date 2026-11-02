-- Lot CHAMP (audit du 2/11 : « une partie d'au moins 150 min ») : 150 min de dc-croissance sans images, relevé [FO-CHAMP-MESURE]
-- toutes les 7,5 min (scenarios/champ_croissance_common.lua). Lancement : banc.py --graine <N> --qui CHAMP -- 545000 champ-longue <source>.
return require("scenarios/champ_croissance_common")(540000)
