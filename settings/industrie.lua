--[[
  Réglage MAÎTRE du lot INDUSTRIE (fo-logs/2026-10-31_INDUSTRIE/PLAN.md). Étape settings uniquement ; requis par settings.lua.

  fo-war-industrie   les équipes de PNJ (factions et votre équipe) industrialisent. Sous-lot I1 (réserve) : les équipes ne gardent plus
                     un pourcentage de leur stock « pour rien » : elles évaluent leur besoin (défense, reconstruction, recrues, ce
                     que le planificateur consomme) et investissent le reste, sans pourcentage ; votre équipe ne retient plus sa
                     réserve de fer de croissance tant que ce besoin est couvert. Sous menace du QG, la règle d'avant s'applique.
                     Relu à chaque pensée : l'éteindre en cours de partie rend les anciennes règles (ce qui est posé reste).
                     Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
  Traductions : locale/*/industrie.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-industrie",
    setting_type = "runtime-global",
    -- ÉTEINT par défaut tant que les bancs du lot ne sont pas rejoués sur la partie entière (PLAN §8 : ia3b-fer, ia3c-dc-apres peuvent bouger).
    default_value = false,
    order = "e-war-z-industrie",
  },
})
