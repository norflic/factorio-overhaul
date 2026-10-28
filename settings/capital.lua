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
    -- ALLUMÉ par défaut (lot AMELIORER, décision de l'orchestrateur 28/10 : aucun réglage éteint par défaut). Le D1 du lot
    -- CAPITAL (recherche des factions retardée, non séparable du bruit de divergence F252) reste mesuré : le remplacement de
    -- machines ne réclame JAMAIS la recherche de sa cible (il ne remplace que ce qui est déjà débloqué).
    default_value = true,
    order = "e-war-z-capital",
  },
})
