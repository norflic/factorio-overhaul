--[[
  Réglage du lot ACIER (8/11) : bloc « fonderie d'acier » automatisé. Étape settings uniquement ; requis par settings.lua
  (ajouté par l'intégrateur : require("settings.acier")).

  fo-war-acier   l'acier est fait par une rangée DYNAMIQUE de fours (tapis d'entrée de plaques de fer, tapis de sortie vers un coffre
                 tampon) demandée comme une rangée d'assembleurs, qui grandit avec la demande ; dès qu'un bloc fini produit au moins ce
                 que l'équipe demande, plus aucune tournée de PNJ n'est émise pour fondre de l'acier (reprise sous la moitié du débit ;
                 jamais coupé en mode survie). Éteint : l'acier se fait comme avant, par les tournées de fonte des PNJ.
                 Relu à chaque pensée d'équipe.
  Traductions : locale/*/acier.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-acier",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-capi-acier",
  },
})
