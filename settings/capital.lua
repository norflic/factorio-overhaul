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
    -- ALLUMÉ par défaut (lot AMELIORER, 29/10 : aucun réglage éteint par défaut). Le D1 du lot CAPITAL (recherche des
    -- factions retardée) venait du centre posé dès la minute 0, servi comme travail court devant la fonderie et les packs
    -- (fonderie finie à 6,1 min au lieu de 1,2) : le centre ne se travaille plus que sur des bras libres durables
    -- (shared/ai3/capital.lua, ctx.hold_center). Mesuré sur 4 graines : aucun retard systématique (fo-logs/2026-10-28_AMELIORER-D1).
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
