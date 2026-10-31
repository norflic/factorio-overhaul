-- Dézoom étendu : deux touches (Ctrl + molette) qui écrivent `player.zoom` plus bas que la limite de la molette
-- (script/gui/dezoom.lua, shared/gui/dezoom.lua). `consuming = "none"` : Ctrl + molette n'est lié à aucune commande de
-- base (config.ini : zoom-in/out = molette, Maj + molette), donc rien n'est bloqué.
data:extend({
  {
    type = "custom-input",
    name = "fo-dezoom-down",
    key_sequence = "CONTROL + mouse-wheel-down",
    consuming = "none",
    order = "b[fo-dezoom]-a",
  },
  {
    type = "custom-input",
    name = "fo-dezoom-up",
    key_sequence = "CONTROL + mouse-wheel-up",
    consuming = "none",
    order = "b[fo-dezoom]-b",
  },
})
