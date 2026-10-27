--[[
  Réglage du lot CAPITAL « améliorer, et monter les époques » (fo-logs/2026-10-27_CAPITAL/INTEGRATION.md). Étape
  settings uniquement ; requis par settings.lua.

  fo-war-capital   les factions (pas votre équipe) posent leur centre de commandement près de leur QG, montent leurs
                   bâtiments à niveaux et leur centre (l'époque suivante) quand cela vaut son coût : valeur lue dans les
                   prototypes, coût lu dans les données des niveaux, payé par le mécanisme du joueur (coffre du QG).
                   Relu à chaque pensée (script/ai3/capital.lua, Capital.on) : l'éteindre en cours de partie arrête les
                   NOUVELLES améliorations et les objets qu'elles voulaient (les bâtiments montés et le centre posé
                   restent). Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting) ; les bancs
                   capital-partie, capital-verif-guide et capital-pnj-reduit l'allument eux-mêmes.
  Traductions : locale/*/capital.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-capital",
    setting_type = "runtime-global",
    -- ÉTEINT par défaut (correction après revue du lot CAPITAL, 27/10) : la recherche des factions est retardée quand il
    -- est allumé (palier 2 en médiane plus tard qu'au témoin sur les 2 graines mesurées, palier 3 sur 1 des 2 : D1 ouvert,
    -- INTEGRATION.md §3 et « Correction après revue »).
    default_value = false,
    order = "e-war-z-capital",
  },
})
