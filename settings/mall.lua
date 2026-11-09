--[[
  Lot MALL (8/11, directive du DC « centraliser sa production […] un véritable "Mall" », docs/MALL.md) : réglage du mall centralisé.
  Étape settings uniquement ; requis par settings.lua (require("settings.mall")). Son lecteur (script/team/mall.lua, Mall.on) garde un
  repli à « éteint » quand le réglage MANQUE (moteur simulé des tests, sauvegardes sans le réglage).

  fo-war-mall   tranche 1 : chaque équipe (factions et votre équipe) choisit tôt, par le terrain seul, un SECTEUR près du QG (ni eau,
                ni minerai, ni bâtiment) et le réserve : le treillis n'y pose plus de module isolé. Journal [FO-MALL] (secteur, état
                « interconnexions de survie établies »). Éteint en cours de partie : la réservation est rendue. Traductions : locale/*/mall.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-mall",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-video-x",
  },
  {
    type = "bool-setting",
    name = "fo-war-mall-s2-debit",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-video-y",
  },
})
