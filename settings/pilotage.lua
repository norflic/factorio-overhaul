--[[
  Réglages du lot TV-PILOTE (pilotage : docs/TODO_VIDEO.md V10, G02), ALLUMÉS par défaut (ordre du DC du 7/11 : toutes les règles de la
  vidéo allumées). Étape settings uniquement ; requis par settings.lua (ligne à poser par l'intégrateur : require("settings.pilotage")).
  Leurs lecteurs (script/ai3/pilotage.lua) gardent un repli à « éteint » quand le réglage MANQUE (moteur simulé des tests).

  fo-war-armee-famille  V10 : la famille armée (munitions et équipement des soldats, UNE liste) garde sa part δ + α de la capitalisation
                        contre les autres projets du cerveau (shared/ai3/famille_armee.lua). Traductions : locale/*/pilotage.cfg.
  fo-war-plafonds       G02 : plafond de sûreté par objet pour les fours, les chaînes et les packs (shared/ai3/plafonds.lua, Pf.HARD_OBJ).
                        Traductions : locale/*/pilotage.cfg.
  Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-armee-famille",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-pilotage-a",
  },
  {
    type = "bool-setting",
    name = "fo-war-plafonds",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-pilotage-b",
  },
})
