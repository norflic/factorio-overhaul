-- Lot IA3-a : la partie du guide du DC (comme ia3d-reduit) AVEC l'essai « recherche d'abord » (fo-war-ia3-recherche).
-- Lancement : fo-autotest.bat nopause 432000 ia3a-reduit <source>. Journal : [FO-IA3D-REDUIT] (même analyse qu'IA3-DIAG).
-- Comparaison avant / après sur la MÊME source : ia3d-reduit (réglage éteint) contre ia3a-reduit, mêmes graines.
return require("scenarios/ia3d_common")("reduit", { ia3_research = true })
