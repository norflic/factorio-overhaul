--[[
  Réglage du lot ADOPTE. Étape settings uniquement ; requis par settings.lua.

  fo-war-adopte   votre équipe adopte les machines (fours à combustion) que VOUS posez à la main, isolées (ni bras, ni tapis,
                  ni foreuse alentour) et proches de son coffre : ses tournées de fonte les chargent, les vident et les
                  ravitaillent (script/team/adopte.lua, règle pure shared/team/adopte.lua). Vrai par défaut : le couper arrête
                  toute nouvelle adoption et rend les machines adoptées à la migration suivante ; rien n'est jamais démoli.
                  Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
  Traductions : locale/*/adopte.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-adopte",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-adopte",
  },
})
