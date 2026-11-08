--[[
  Réglages du lot TV-PLACE (sonde et place ; points G37, G38, G57 et C07 de docs/TODO_VIDEO.md). Quatre interrupteurs, tous ALLUMÉS par
  défaut (ordre du DC du 8/11 : 100 % des points de la vidéo intégrés et allumés). Leurs lecteurs gardent un repli à « éteint » quand le
  réglage MANQUE (moteur simulé des tests, qui ne les déclare pas). Traductions : locale/*/place.cfg. Requis par settings.lua (l'intégrateur).

  fo-war-sonde-30         G37 : sonde de gisement de 30 x 30 autour d'un lot, lot « en bord de gisement » (shared/team/sonde_lot.lua ;
                          script/team/place_glue.lua).
  fo-war-sites-10         G57 : sites des factions sondés aussi en fenêtres de 10 x 10 (shared/faction/sonde10.lua ; script/faction/sites.lua).
  fo-war-defrichage-prev  G38 : défrichage préventif de 50 x 50 autour d'un lot à défricher (shared/team/defrichage_prev.lua ;
                          script/team/place_glue.lua), sous le jeton des travaux lourds.
  fo-war-place-simple     C07 : repli de placement simple avant de faire grandir le treillis (shared/team/place_simple.lua ;
                          script/team/place_glue.lua).
  Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-sonde-30",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-place-a",
  },
  {
    type = "bool-setting",
    name = "fo-war-sites-10",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-place-b",
  },
  {
    type = "bool-setting",
    name = "fo-war-defrichage-prev",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-place-c",
  },
  {
    type = "bool-setting",
    name = "fo-war-place-simple",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-place-d",
  },
})
