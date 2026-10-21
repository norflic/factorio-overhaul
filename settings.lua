-- Étape settings : uniquement des déclarations de paramètres.
-- Tous les paramètres sont "runtime-global" : synchronisés en multijoueur, modifiables sans recharger.

data:extend({
  {
    type = "bool-setting",
    name = "fo-debug-render",
    setting_type = "runtime-global",
    default_value = false, -- surcouche de débogage (états, chemins) : désactivée en partie normale
    order = "a",
  },
  {
    -- Période de pilotage (ticks) des compagnons en mouvement. 1 = chaque tick.
    type = "int-setting",
    name = "fo-companion-steer-period",
    setting_type = "runtime-global",
    default_value = 4,
    minimum_value = 1,
    maximum_value = 30,
    order = "b",
  },
  {
    -- Période de décision (ticks) du cerveau de chaque compagnon.
    type = "int-setting",
    name = "fo-companion-brain-period",
    setting_type = "runtime-global",
    default_value = 60,
    minimum_value = 10,
    maximum_value = 600,
    order = "c",
  },
  {
    -- Requêtes de pathfinding scriptées en vol simultanément.
    -- Le moteur n'accepte que 10 nouvelles requêtes/tick (partagées avec les biters) : rester en dessous.
    type = "int-setting",
    name = "fo-path-max-inflight",
    setting_type = "runtime-global",
    default_value = 6,
    minimum_value = 1,
    maximum_value = 50,
    order = "d",
  },
  {
    -- Factions IA : cessez-le-feu avec le joueur au lancement (rompu si le joueur les attaque).
    type = "bool-setting",
    name = "fo-war-player-ceasefire",
    setting_type = "runtime-global",
    default_value = true,
    order = "e",
  },
  {
    -- Niveaux : multiplicateur de durée des chantiers d'amélioration (0 = instantané).
    type = "double-setting",
    name = "fo-level-time-factor",
    setting_type = "runtime-global",
    default_value = 1,
    minimum_value = 0,
    maximum_value = 10,
    order = "f",
  },
})

-- Réglages par lot (un fichier par lot, requis ici par l'intégrateur).
require("settings.faction")
