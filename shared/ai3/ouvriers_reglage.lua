--[[
  Lot OUVRIERS-30 (0.6.95, ordre du DC du 11/11, 09 h 47 : « enregistre le réglage par défaut à 30 pour éviter les faux
  plafonnements économiques des sauvegardes ») : MIGRATION UNIQUE du réglage de carte « Factions : ouvriers au plus »
  (fo-war-workers) dans une partie sauvegardée avant la 0.6.95. Règle PURE (aucune API) : quand la migration est due, et quelle
  valeur écrire. L'exécutant est script/ai3/ouvriers_reglage.lua.

  Pourquoi (F510) : le défaut vaut 30 depuis le lot SCALE (shared/team/scale.lua), mais un réglage de carte stocké dans une
  sauvegarde (et dans les réglages de carte de l'écran titre) garde sa valeur : les parties du DC du 10/11 tournaient à 8, les
  factions restaient saturées à 8 PNJ et dormaient sur des milliers de plaques.
  Quoi : la valeur lue, si c'est un nombre SOUS le défaut du réglage (lu dans Scale, jamais écrit ici), devient ce défaut ; une
  valeur égale ou plus haute est gardée. Quand : comme Vr.due (shared/ai3/video_reglages.lua), à on_configuration_changed d'une
  montée depuis une version antérieure à Ow.BEFORE, une seule fois par partie (drapeau `done` de l'exécutant) : un réglage baissé
  ensuite par le DC est respecté.
]]

local Vr = require("shared.ai3.video_reglages")
local Scale = require("shared.team.scale")

local Ow = {}

Ow.NAME = "fo-war-workers"
Ow.BEFORE = { 0, 6, 95 }

--- La migration est-elle due ? data = ConfigurationChangedData, mod_name = nom du mod, done = drapeau de la partie.
function Ow.due(data, mod_name, done)
  if done then return false end
  local ch = data and data.mod_changes and data.mod_changes[mod_name]
  return Vr.older(ch and ch.old_version, Ow.BEFORE) == true
end

--- Valeur à écrire pour la valeur lue v : le défaut du réglage si v est un nombre en dessous, nil sinon (rien à écrire).
function Ow.to_set(v)
  local def = Scale.DEFAULTS[Ow.NAME]
  if type(v) == "number" and type(def) == "number" and v < def then return def end
  return nil
end

return Ow
