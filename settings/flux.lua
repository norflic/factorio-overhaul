--[[
  Réglages du lot TV-FLUX « fluides, stock et quotas » (points V42, G51, C11 de docs/TODO_VIDEO.md). Étape settings uniquement ; requis par
  settings.lua (ligne à poser par l'intégrateur : require("settings.flux")). Tous ALLUMÉS par défaut (ordre du DC du 7/11 : toutes les règles de
  la vidéo allumées). Leurs lecteurs gardent un repli à « éteint » quand le réglage MANQUE (moteur simulé des tests, qui ne les déclare pas).
  Une sauvegarde plus ancienne reçoit le défaut du jeu pour un réglage NOUVEAU (aucune migration à écrire).

  fo-war-barils         G51 : un fluide se juge sur ses barils pleins au coffre (shared/ai3/capitalisation.lua, Ca.barrel_stock ;
                        lu par Capi.barils_on, script/ai3/capitalisation.lua). Traductions : locale/*/flux.cfg.
  fo-war-soupape        V42 : la soupape des cuves de fluide d'un site fini (shared/ai3/fluides.lua, Fl.valve* ; lu par Pet.valve_on,
                        script/ai3/petrole.lua). Traductions : locale/*/flux.cfg.
  fo-war-quotas-pieces  C11 : les quotas d'un module suivent les machines réellement posées (shared/team/quotas.lua, Q.scale ; lu par
                        Qg.pieces_on, script/team/quotas_glue.lua). Traductions : locale/*/flux.cfg.
  Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-barils",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-flux-a",
  },
  {
    type = "bool-setting",
    name = "fo-war-soupape",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-flux-b",
  },
  {
    type = "bool-setting",
    name = "fo-war-quotas-pieces",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-flux-c",
  },
})
