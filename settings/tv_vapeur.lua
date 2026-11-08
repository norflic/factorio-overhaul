--[[
  Lot TV-VAPEUR (points V36 et V89 de docs/TODO_VIDEO.md). Étape settings uniquement ; le `require("settings.tv_vapeur")` de settings.lua
  est à l'intégrateur. Préfixe « fo-war- » : réglables par les bancs (interface distante war_setting). Lus à chaque usage.

  fo-war-degradation    dégradation graduée sous charge (script/core/charge.lua) : quand la file du jeton des travaux lourds s'allonge, les
                        travaux NON urgents (pensée des factions lointaines et calmes, relevé de l'alimentation des centrales) s'espacent
                        par paliers. ALLUMÉ par défaut ; éteint, rien ne s'espace (la cadence d'avant). Défense et courant : jamais.
  fo-war-vapeur-tampon  remplissage du coffre de charbon de la centrale aussi sur le tampon de vapeur bas (script/team/vapeur_glue.lua).
                        ALLUMÉ par défaut ; éteint, seule la consommation déclenche (la règle d'avant).
  Traductions : locale/*/tv_vapeur.cfg.
]]

data:extend({
  { type = "bool-setting", name = "fo-war-degradation", setting_type = "runtime-global", default_value = true, order = "e-war-z-tv-a" },
  { type = "bool-setting", name = "fo-war-vapeur-tampon", setting_type = "runtime-global", default_value = true, order = "e-war-z-tv-b" },
})
