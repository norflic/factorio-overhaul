--[[
  Réglage du lot MODULES-ORDRE (9/11) : le RELAIS de la porte du transport. Étape settings uniquement ; requis par settings.lua
  (ajouté par l'intégrateur : require("settings.relais")).

  fo-war-relais   une chaîne que la capitalisation a ordonnée et dont les PNJ font déjà la fabrication à la main (charge mesurée d'au
                  moins 0,25 PNJ sur la fenêtre) passe la porte du transport saturé : c'est cette fabrication à la main qui sature les PNJ
                  (shared/ai3/couverture.lua, Cv.relief ; lu par Capi.portes, script/ai3/capitalisation.lua). Les portes des chantiers, du
                  rang, du budget et du courant restent. Éteint : la porte retient la chaîne tant que le transport est saturé (témoin A/B
                  des bancs). Relu à chaque décision.
  Traductions : locale/*/relais.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-relais",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-capi-relais",
  },
})
