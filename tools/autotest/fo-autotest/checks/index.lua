-- Contrôles greffés au banc « content », exécutés dans cet ordre (format : tools/autotest/README.md).
-- Un lot ajoute son fichier checks/<nom>.lua et son nom ici (ligne à lui : pas de conflit de fusion).
return {
  "exemple",
  "levels_taille", -- lot V3-T : emprise croissante (agrandissement sur place, refus et contour)
  "levels_machines", -- lot V3-T2 : emprise croissante de toutes les familles (machines, laser, centre)
  "levels_points", -- lot V3-T2 (corrections) : points de jeu servis, fabrication à travers le remplacement rapide
}
