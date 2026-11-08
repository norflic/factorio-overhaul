-- Lot BLOCAGE-SORTIE-2 : releve d'etat de la partie du DC (reglages laisses tels quels, fo-war-petrole faux) sur 20 min de jeu, fenetres de 5 min.
-- Joue AVANT (source 0cda6793) et APRES (source du lot) : memes sauvegarde, graine et duree. Voir fo-logs\2026-11-08_BLOCAGE-SORTIE\CRITERES.md.
return require("scenarios/mesure_dc_common")("temoin", false, 20)
