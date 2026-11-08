--[[
  Lot ELECTRIQUE (retour du DC du 8/11, 14 h 30, 0.6.66). Étape settings uniquement ; le `require("settings.electrique")` de settings.lua est
  à l'intégrateur. Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting). Lu à chaque usage (script/team/electrique.lua).

  fo-war-electrique  dès qu'une centrale est finie et que la foreuse électrique et un poteau sont obtenables : plus d'agrandissement ni
                     d'avant-poste thermique (sauf le combustible d'une centrale à l'arrêt), remplacement thermique -> électrique par champ
                     entier à la cadence de la marge de kW, kW des électriques prévues demandés à la centrale avant la pose. ALLUMÉ par
                     défaut ; éteint, le comportement d'avant (2 remplacements par passe, paires thermiques permises).
  Traductions : locale/*/electrique.cfg.
]]

data:extend({
  { type = "bool-setting", name = "fo-war-electrique", setting_type = "runtime-global", default_value = true, order = "e-war-z-el-a" },
})
