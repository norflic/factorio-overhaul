--[[
  Réglage MAÎTRE du lot INDUSTRIE (fo-logs/2026-10-31_INDUSTRIE/PLAN.md). Étape settings uniquement ; requis par settings.lua.

  fo-war-industrie   les équipes de PNJ (factions et votre équipe) industrialisent. ALLUMÉ par défaut (0.6.30 : éteint, le DC ne verrait rien en
                     jeu). Trois effets, un seul réglage :
                     I1 (réserve) : les équipes ne gardent plus un pourcentage de leur stock « pour rien » : elles évaluent leur besoin
                     (défense, reconstruction, recrues, ce que le planificateur consomme) et investissent le reste, sans pourcentage ;
                     votre équipe ne retient plus sa réserve de fer de croissance tant que ce besoin est couvert. Sous menace du QG, la
                     règle d'avant s'applique.
                     I2 (inactifs) : un PNJ sans tâche reçoit la file sûre (shared/team/travail_sur.lua).
                     I3 (treillis) : le treillis grandit d'un coup vers un gisement, jusqu'à l'anneau 12 (shared/team/treillis.lua).
                     Relu à chaque pensée : l'éteindre en cours de partie rend les anciennes règles (ce qui est posé reste, le rayon
                     déjà atteint aussi). Une sauvegarde d'avant 0.6.30 n'a pas ce réglage : elle prend la valeur par défaut au chargement.
                     Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
  Traductions : locale/*/industrie.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-industrie",
    setting_type = "runtime-global",
    default_value = true, -- intégration 0.6.30 ; témoin d'un banc : war_setting("fo-war-industrie", false)
    order = "e-war-z-industrie",
  },
})
