--[[
  Réglages des factions IA : PvP et niveaux de difficulté (OBJECTIFS.md C4, réponse à Q4).
  Étape settings uniquement. Fichier possédé par le lot IA0 (OBJECTIFS.md §7).

  fo-pvp-difficulty (runtime-global : réglage de partie, modifiable en cours de partie, effet immédiat) :
  les factions vous attaquent-elles d'elles-mêmes, quand, combien et à quelle fréquence. Les valeurs et
  leurs paramètres sont dans shared/faction/config.lua (F.pvp_order, F.pvp) : une seule source.
  Traductions : locale/*/ia0.cfg ([mod-setting-name], [mod-setting-description], [string-mod-setting]).
]]

local F = require("shared.faction.config")

local values = {}
for i, v in ipairs(F.pvp_order) do values[i] = v end

data:extend({
  {
    type = "string-setting",
    name = "fo-pvp-difficulty",
    setting_type = "runtime-global",
    default_value = F.pvp_default,
    allowed_values = values,
    order = "e-pvp",
  },
})
