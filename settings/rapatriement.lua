--[[
  Lot RAPATRIEMENT (8/11, demande du DC en jouant la 0.6.65) : réglage des lignes de rapatriement. Étape settings uniquement ; requis par
  settings.lua (ligne posée par l'intégrateur : require("settings.rapatriement")). Son lecteur (script/team/rapatriement.lua, Rap.on) garde un
  repli à « éteint » quand le réglage MANQUE (moteur simulé des tests, sauvegardes sans le réglage) ET exige le réglage maître fo-war-industrie.

  fo-war-rapatriement   un coffre de sortie lointain (champ, fonderie, site) à 56 tuiles du QG ou plus est relié par un tapis long à un coffre TAMPON
                        près des quais qui consomment son objet ; la ligne est un projet du plan directeur (fantômes, PNJ, fils comme une liaison de
                        quai). Traductions : locale/*/rapatriement.cfg. Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-rapatriement",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-video-v",
  },
})
