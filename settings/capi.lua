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
    -- ALLUMÉ par défaut (étape 1 du 27/10 au soir : comportement par défaut, plus de réglage éteint ; les garde-fous
    -- verif-guide, pnj-reduit et K10 restent à rejouer à chaque changement, BRANCHEMENT.md). Éteint : les factions
    -- ne passent plus d'ordre de capitalisation.
    default_value = true,
    order = "e-war-z-capi",
  },
})
