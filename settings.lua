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
    -- Le moteur sert 10 CLIENTS au plus à la fois pour toute requête (max_clients_to_accept_any_new_request,
    -- partagés avec les biters ; ce n'est pas un nombre par tick, lot IA1-a), puis seulement les requêtes
    -- courtes : rester en dessous. Émissions par tick : fo-path-issue-per-tick (settings/team.lua). Maximum de 50
    -- gardé tel quel (une partie qui l'aurait réglé au-delà de 10 ne change pas) : à décider par l'intégrateur.
    type = "int-setting",
    name = "fo-path-max-inflight",
    setting_type = "runtime-global",
    default_value = 6,
    minimum_value = 1,
    maximum_value = 50,
    order = "d",
  },
  -- Lot IA0 : « fo-war-player-ceasefire » retiré : plus aucun code ne le lit, le réglage de partie
  -- « fo-pvp-difficulty » (settings/faction.lua) le remplace (« Paisible » = ancien comportement). Une
  -- sauvegarde qui en contient une valeur la perd sans erreur ; une guerre en cours reçoit son état PvP au
  -- chargement (script/faction/pvp.lua, PvP.ensure : hostilités existantes conservées).
  -- Lot V2c : « fo-level-time-factor » retiré : l'amélioration est instantanée (Q19), plus aucun code ne le
  -- lit. Une sauvegarde qui en contient une valeur la perd sans erreur (réglage inconnu ignoré au chargement).
})

-- Réglages par lot (un fichier par lot, requis ici par l'intégrateur).
require("settings.faction")
require("settings.team") -- lot IA1-a : taille des équipes de PNJ (shared/team/scale.lua)
require("settings.ia3b") -- lot IA3-b : place de marché, registre, manque de plaques (fo-war-ia3-marche)
require("settings.ia3c") -- lot IA3-c : cerveau par besoins (fo-war-ia3-cerveau, éteint par défaut)
require("settings.ia3k") -- lot IA3-k : comportements visibles des PNJ (fo-war-ia3-comportement)
require("settings.ia3e") -- lot IA3-e : automatiser ce qui revient (fo-war-ia3e)
require("settings.capital") -- lot CAPITAL : améliorer et monter les époques (fo-war-capital, éteint par défaut)
require("settings.capi") -- lot CAPIB : capitaliser (fo-war-capi, éteint par défaut ; agit avec fo-war-ia3e)
require("settings.adopte") -- lot ADOPTE : adopter les machines posées à la main (fo-war-adopte)
require("settings.petrole") -- lot PETROLE : aller au pétrole (fo-war-petrole, éteint par défaut)
