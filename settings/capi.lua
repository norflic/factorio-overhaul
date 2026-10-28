--[[
  Réglage du lot CAPIB « brancher la capitalisation » (fo-logs/2026-10-27_CAPI/BRANCHEMENT.md). Étape settings
  uniquement ; requis par settings.lua.

  fo-war-capi   les factions (pas votre équipe) réinvestissent leur production en capacité : couvrir leurs gisements de
                foreuses (jusqu'à 80 % des tuiles), en ouvrir d'autres, des fours au débit du minerai livré, des rangées
                d'assembleurs, des laboratoires (règle shared/ai3/capitalisation.lua, runtime script/ai3/capitalisation.lua).
                N'agit qu'avec fo-war-ia3e allumé (l'automatisation est son exécutant : fonderies à foreuses, rangées).
                Relu à chaque pensée : l'éteindre en cours de partie arrête les NOUVEAUX ordres (ce qui est posé reste).
                Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting) ; les bancs capi-* l'allument.
  Traductions : locale/*/capi.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-capi",
    setting_type = "runtime-global",
    -- ÉTEINT par défaut : allumé seulement quand les critères (1) à (5) du DC sont prouvés en moteur réel ET que les
    -- garde-fous (verif-guide, pnj-reduit, K10) restent verts réglage allumé (BRANCHEMENT.md).
    default_value = true,
    order = "e-war-z-capi",
  },
})
