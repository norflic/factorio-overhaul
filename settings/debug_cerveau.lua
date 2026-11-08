--[[
  Lot DEBUG-CERVEAU : réglages PAR JOUEUR de la vue « Cerveau » (script/debug/cerveau.lua). Sans rapport avec fo-debug-render ni
  fo-debug-trace-carte. À ajouter par l'intégrateur : require("settings.debug_cerveau") dans settings.lua.
]]
data:extend({
  {
    type = "bool-setting",
    name = "fo-dbg-cerveau-textes",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "a-dbg-cerveau-a",
  },
  {
    type = "bool-setting",
    name = "fo-dbg-cerveau-ecarts-seuls",
    setting_type = "runtime-per-user",
    default_value = false,
    order = "a-dbg-cerveau-b",
  },
})
