--[[
  Cache des paramètres runtime-global.

  Lire settings.global à chaque tick coûte des allocations ; on met en cache dans une table locale.
  C'est sûr en multijoueur : les paramètres runtime-global font partie de l'état synchronisé, le cache est
  reconstruit paresseusement sur chaque client (premier accès) et à chaque changement de paramètre.
]]

local Events = require("script.core.events")
local Scale = require("shared.team.scale")

local Config = {}

local KEYS = {
  debug_render = "fo-debug-render",
  steer_period = "fo-companion-steer-period",
  brain_period = "fo-companion-brain-period",
  path_max_inflight = "fo-path-max-inflight",
}
-- Lot IA1-a (settings/team.lua) : lus par Scale.read, qui rend le défaut (shared/team/scale.lua) d'un réglage
-- absent (moteur simulé des tests hors jeu) et borne la valeur.
local TEAM_KEYS = {
  factions = "fo-factions",
  npc_max = "fo-team-npc-max",
  player_npc_max = "fo-player-team-npc-max",
  npc_start = "fo-npc-start",
  agents_max = "fo-agents-max",
  path_issue_per_tick = "fo-path-issue-per-tick",
  recruit_idle_max = "fo-recruit-idle-max", -- correction IA1-a : frein par le travail
}

local cache = nil

local function refresh()
  local g = settings.global
  local c = {}
  for key, setting_name in pairs(KEYS) do
    c[key] = g[setting_name].value
  end
  local function get(name) return g[name].value end
  for key, setting_name in pairs(TEAM_KEYS) do
    c[key] = Scale.read(setting_name, get)
  end
  cache = c
end

function Config.get(key)
  if not cache then refresh() end
  return cache[key]
end

--- Vide le cache (réglage écrit par script : interface « fo-ia1 », set_setting).
function Config.invalidate() cache = nil end

Events.on(defines.events.on_runtime_mod_setting_changed, function()
  cache = nil
end)

Events.on_configuration_changed(function()
  cache = nil
end)

return Config
