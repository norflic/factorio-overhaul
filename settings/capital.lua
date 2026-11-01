--[[
  Réglage du lot CAPITAL « améliorer, et monter les époques » (fo-logs/2026-10-27_CAPITAL/INTEGRATION.md). Étape
  settings uniquement ; requis par settings.lua.

  fo-war-capital   (ALLUMÉ par défaut depuis le lot C1) les factions (pas votre équipe) posent leur centre de commandement près de leur QG, montent leurs
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
    -- ALLUMÉ par défaut (lot C1, 31/10) : éteint, les factions ne montaient jamais leur centre (donc aucune époque ne s'ouvrait
    -- pour elles) ni leurs bâtiments ; mesuré : partie de 2 h à 3 factions, `fo-war-capital=false`, 0 ligne « centre monte ».
    -- Ancien motif de l'extinction (correction après revue du 27/10) : la recherche des factions était retardée quand il est
    -- allumé (palier 2 en médiane plus tard qu'au témoin sur les 2 graines mesurées, palier 3 sur 1 des 2 : D1 ouvert,
    -- INTEGRATION.md §3, RD_LOG F381) ; le DC a tranché pour l'amélioration sans fin (31/10). D1 reste à mesurer.
    default_value = true,
    order = "e-war-z-capital",
  },
  -- Lot AMELIORER (28/10) : le remplacement sur place des machines hors famille (four de pierre, premier assembleur) par la
  -- machine supérieure lue aux prototypes. ALLUMÉ par défaut : il ne remplace que ce qui est déjà débloqué, ne réclame jamais
  -- la recherche de sa cible et ne touche ni centre ni tourelles. Relu à chaque pensée (runtime-global).
  {
    type = "bool-setting",
    name = "fo-war-remplacer",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-capital-b",
  },
})
