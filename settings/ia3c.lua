--[[
  Réglage du lot IA3-c « le cerveau par besoins » (docs/IA3_CERVEAU.md §5.4, §6.2). Étape settings uniquement ; requis
  par settings.lua (commit de l'intégrateur).

  fo-war-ia3-cerveau   le nouveau cerveau des PNJ (buts par besoin, projets en parallèle, vraie recherche des factions
                       par le laboratoire du QG ; shared/ai3/cerveau.lua, script/ai3/cerveau.lua) REMPLACE l'échelle des
                       objectifs, pour les factions ET votre équipe. ALLUMÉ par défaut depuis le lot IA-V2 (27/10,
                       version 0.5.0 : critères mesurés, fo-logs/2026-10-27_IA-V2/INTEGRATION.md ; éteint avant,
                       règle de l'intégrateur, revue M10). Une partie 0.4.x chargée en 0.5.0 reçoit la valeur par défaut :
                       chaque équipe MIGRE à sa pensée suivante (§5.4). Relu à chaque pensée d'une équipe tant
                       qu'il est éteint pour elle : l'allumer en cours de partie MIGRE l'équipe (un réglage de carte ne
                       se change qu'une partie chargée) ; une fois allumé pour une équipe, il y est FIGÉ (l'éteindre est
                       ignoré et dit au journal : aucune migration nouveau → ancien).
                       Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting) ; la conception
                       écrivait « fo-ia3-cerveau ».
  Traductions : locale/*/ia3c.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-ia3-cerveau",
    setting_type = "runtime-global",
    default_value = true, -- lot IA-V2 (0.5.0)
    order = "e-war-z-ia3-c",
  },
})
