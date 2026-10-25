-- Lot IA3-a : la partie `default` du banc (comme ia3d-default : 4 factions, 8 PNJ au départ) AVEC l'essai « recherche
-- d'abord » (fo-war-ia3-recherche). Lancement : fo-autotest.bat nopause 432000 ia3a-default <source>.
-- Journal : [FO-IA3D-DEFAULT]. Comparaison avant / après sur la MÊME source : ia3d-default contre ia3a-default.
return require("scenarios/ia3d_common")("default", { ia3_research = true })
