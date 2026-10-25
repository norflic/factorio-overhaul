--[[
  Réglage du lot IA3-c « le cerveau par besoins » (docs/IA3_CERVEAU.md §5.4, §6.2). Étape settings uniquement ; requis
  par settings.lua (commit de l'intégrateur).

  fo-war-ia3-cerveau   le nouveau cerveau des PNJ (buts par besoin, projets en parallèle, vraie recherche des factions
                       par le laboratoire du QG ; shared/ai3/cerveau.lua, script/ai3/cerveau.lua) REMPLACE l'échelle des
                       objectifs, pour les factions ET votre équipe. ÉTEINT par défaut tant que les critères du lot ne
                       sont pas mesurés (règle de l'intégrateur, revue M10). Lu par chaque équipe à sa première pensée et
                       FIGÉ dans son état ; une partie en cours dont le réglage s'allume est migrée à ce moment-là.
                       Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting) ; la conception
                       écrivait « fo-ia3-cerveau ».
  Traductions : locale/*/ia3c.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-ia3-cerveau",
    setting_type = "runtime-global",
    default_value = false,
    order = "e-war-z-ia3-c",
  },
})
