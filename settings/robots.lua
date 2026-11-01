--[[
  Réglages du lot RB-1 CHAÎNE (robots ; PLAN fo-logs/2026-10-31_ROBOTS). Étape settings uniquement ; requis par settings.lua.

  fo-war-robots      réglage maître. Allumé : le balayage des ateliers (script/robots/usine.lua) transforme les kits en unités
                     tant qu'il reste des points, et les ordres (script/robots/ordres.lua) sont servis. Éteint : rien ne tourne
                     (un kit reste dans la sortie de la machine, qui s'arrête d'elle-même) ; les unités déjà créées restent.
                     Relu à chaque balayage. Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
  fo-war-robots-cap  plafond d'armée en points, par force. 0 = automatique (12 + 6 × âge : 30 à l'âge 3, 102 à l'âge 15).
  Traductions : locale/*/robots.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-robots",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-robots-a",
  },
  {
    type = "int-setting",
    name = "fo-war-robots-cap",
    setting_type = "runtime-global",
    default_value = 0,
    minimum_value = 0,
    maximum_value = 1000,
    order = "e-war-z-robots-b",
  },
})
