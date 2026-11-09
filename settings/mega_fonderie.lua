--[[
  Réglage du lot MEGA-FONDERIE. Étape settings uniquement ; requis par settings.lua (l'intégrateur ajoute la ligne
  require("settings.mega_fonderie")).

  fo-war-mega-fonderie   méga-fonderies des équipes (factions et votre équipe) : sur un gisement qui porte au moins deux lignes pleines
                         de bus, le cerveau décide un BLOC RECTANGULAIRE de fonte nourri par un bus de minerai à plusieurs lignes
                         (shared/team/mega_fonderie.lua ; décision une fois par minute, script/team/mega_fonderie.lua ; journal
                         [FO-MEGA]). Vrai par défaut. Éteint : aucune décision, rien n'est lu ni écrit. Tranche 1 : décision et taille
                         seulement, la pose du bloc vient ensuite (docs/MEGA_FONDERIE.md).
                         Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
  Traductions : locale/*/mega_fonderie.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-mega-fonderie",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-mega-fonderie",
  },
})
