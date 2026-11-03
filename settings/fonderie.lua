--[[
  Réglage du lot FONDERIE. Étape settings uniquement ; requis par settings.lua.

  fo-war-fonderie-tapis   fonderies des champs de minerai en COLONNE À TAPIS : une voie de minerai, une voie de charbon, un bras par four,
                          plaques sur un tapis vers un quai de coffres ; le charbon arrive par tapis depuis une ligne de foreuses posée sur
                          le gisement de charbon le plus proche (shared/team/champ_colonne.lua) : plus de coffre de combustible à garnir
                          entre deux fours. Vrai par défaut pour une PARTIE NEUVE ; une sauvegarde d'avant le lot le garde éteint (marque
                          posée à la création de la partie, script/team/champ.lua, Champ.tapis) ; éteint : fonderie à coffres (0.6.41).
                          Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
  Traductions : locale/*/fonderie.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-fonderie-tapis",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-fonderie",
  },
})
