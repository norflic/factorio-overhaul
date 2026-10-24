--[[
  Réglages des factions IA : PvP et niveaux de difficulté (OBJECTIFS.md C4, réponse à Q4).
  Étape settings uniquement. Fichier possédé par le lot IA0 (OBJECTIFS.md §7).

  fo-pvp-difficulty (runtime-global : réglage de partie, modifiable en cours de partie, effet immédiat) :
  les factions vous attaquent-elles d'elles-mêmes, quand, combien et à quelle fréquence. Les valeurs et
  leurs paramètres sont dans shared/faction/config.lua (F.pvp_order, F.pvp) : une seule source.
  Traductions : locale/*/ia0.cfg ([mod-setting-name], [mod-setting-description], [string-mod-setting]).
]]

local F = require("shared.faction.config")
local S = require("shared.team.scale")

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
  -- Lancement de la guerre sans console (lot PNJ-JOUABLE, 24/10) : coché, la guerre part seule au premier passage
  -- de script/faction/war.lua (tick 600 au plus tard), une fois par partie ; mêmes effets que `/fo-war start n s o`.
  {
    type = "bool-setting",
    name = "fo-war-autostart",
    setting_type = "runtime-global",
    default_value = false,
    order = "e-war-a",
  },
  -- Nombre de factions et ouvriers (PNJ) par faction : valeurs dans shared/team/scale.lua (S.SETTINGS, lot IA1-a,
  -- fusion avec 0.4.15 : un seul réglage par sens, aussi lu par « /fo-war start » sans nombre).
  {
    type = "int-setting",
    name = "fo-war-factions",
    setting_type = "runtime-global",
    default_value = S.spec("fo-war-factions").default,
    minimum_value = S.spec("fo-war-factions").min,
    maximum_value = S.spec("fo-war-factions").max,
    order = S.spec("fo-war-factions").order,
  },
  {
    type = "int-setting",
    name = "fo-war-soldiers",
    setting_type = "runtime-global",
    default_value = 30,
    minimum_value = 5,
    maximum_value = F.defaults.soldiers_max,
    order = "e-war-c",
  },
  {
    type = "int-setting",
    name = "fo-war-workers",
    setting_type = "runtime-global",
    default_value = S.spec("fo-war-workers").default,
    minimum_value = S.spec("fo-war-workers").min,
    maximum_value = S.spec("fo-war-workers").max,
    order = S.spec("fo-war-workers").order,
  },
})
