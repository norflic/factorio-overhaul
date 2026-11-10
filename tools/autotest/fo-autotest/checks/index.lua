-- Contrôles greffés au banc « content », exécutés dans cet ordre (format : tools/autotest/README.md).
-- Un lot ajoute son fichier checks/<nom>.lua et son nom ici (ligne à lui : pas de conflit de fusion).
return {
  "exemple",
  "levels_taille", -- lot V3-T : emprise croissante (agrandissement sur place, refus et contour)
  "levels_machines", -- lot V3-T2 : emprise croissante de toutes les familles (machines, laser, centre)
  "levels_points", -- lot V3-T2 (corrections) : points de jeu servis, fabrication à travers le remplacement rapide
  "equilibre", -- lot EQUILIBRE : 12 paliers, 6 familles, × 1,15 par niveau, laser 30 au-delà de 24 tuiles
  "assauts", -- lot ASSAUTS-TITANESQUES : barrière de périmètre (alimentée foudroie, sans courant témoin), assaut de boss forcé (Kaiju, phases)
  "kaijus", -- lot KAIJUS-MUTANTS : Écorcheur (ères, tir, PONTE en moteur), Écorchés (trois variantes vivantes), Ravageur (paliers, animations)
  "batiments", -- lot POLISSAGE-2 : les cinq tourelles électriques refaites (tête d'une direction) se chargent et tirent
}
