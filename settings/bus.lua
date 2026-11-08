--[[
  Lot RESEAU-GRAPHE (bus de produits, ordre du DC du 8/11 à 13 h 05) : réglage du bus. Étape settings uniquement ; requis par settings.lua (ligne
  posée par l'intégrateur). Lecteur : script/team/bus.lua (Bus.on), avec repli à « éteint » quand le réglage MANQUE (moteur simulé des tests).

  fo-war-bus   une file de tapis par objet, choisie par la règle shared/team/reseau_graphe.lua, relie un coffre de sortie lointain à un quai
               (tronc le long des rues, souterrains par le lot traversee) ; journal [FO-BUS]. Traductions : locale/*/bus.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-bus",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-video-v",
  },
})
