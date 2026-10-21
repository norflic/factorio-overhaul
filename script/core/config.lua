--[[
  Cache des paramètres runtime-global.

  Lire settings.global à chaque tick coûte des allocations ; on met en cache dans une table locale.
  C'est sûr en multijoueur : les paramètres runtime-global font partie de l'état synchronisé, le cache est
  reconstruit paresseusement sur chaque client (premier accès) et à chaque changement de paramètre.
]]

local Events = require("script.core.events")

local Config = {}

local KEYS = {
  debug_render = "fo-debug-render",
  steer_period = "fo-companion-steer-period",
  brain_period = "fo-companion-brain-period",
  path_max_inflight = "fo-path-max-inflight",
}

local cache = nil

local function refresh()
  local g = settings.global
  local c = {}
  for key, setting_name in pairs(KEYS) do
    c[key] = g[setting_name].value
  end
  cache = c
end

function Config.get(key)
  if not cache then refresh() end
  return cache[key]
end

Events.on(defines.events.on_runtime_mod_setting_changed, function()
  cache = nil
end)

Events.on_configuration_changed(function()
  cache = nil
end)

return Config
