--[[
  Couche RENDU (debug) : étiquette d'état au-dessus du compagnon, tracé du chemin au sol.

  Purement observationnel : ne lit que les agents, n'écrit que des objets de rendu.
  Le tracé de chemin est plafonné (segments et agents) pour ne pas devenir lui-même un coût.
]]

local Config = require("script.core.config")
local Registry = require("script.companion.registry")

local Render = {}

local MAX_SEGMENTS = 60
local MAX_AGENT_ID_WITH_PATH = 25 -- au-delà, pas de tracé (banc d'essai à grande échelle)
local PATH_TTL = 300

local STATE_COLORS = {
  idle = { r = 0.8, g = 0.8, b = 0.8 },
  pathing = { r = 1.0, g = 0.85, b = 0.2 },
  moving = { r = 0.3, g = 1.0, b = 0.4 },
}
local DEFAULT_COLOR = { r = 1, g = 1, b = 1 }
local PATH_COLOR = { r = 0.2, g = 0.6, b = 1.0, a = 0.6 }

local function destroy_label(agent)
  if agent.label and rendering.is_valid(agent.label) then rendering.destroy(agent.label) end
  agent.label = nil
end

function Render.state_changed(agent)
  if not Config.get("debug_render") then
    if agent.label then destroy_label(agent) end
    return
  end
  if not agent.entity.valid then return end
  local color = STATE_COLORS[agent.state] or DEFAULT_COLOR
  if agent.label and rendering.is_valid(agent.label) then
    rendering.set_text(agent.label, agent.state)
    rendering.set_color(agent.label, color)
  else
    agent.label = rendering.draw_text({
      text = agent.state,
      surface = agent.surface,
      target = agent.entity,
      target_offset = { 0, -2.6 },
      color = color,
      scale = 0.9,
      alignment = "center",
    })
  end
end

function Render.path(agent)
  if not Config.get("debug_render") or agent.id > MAX_AGENT_ID_WITH_PATH then return end
  local p, n = agent.path, agent.wpn
  if not p or n < 2 then return end
  local last = n - 1
  if last > MAX_SEGMENTS then last = MAX_SEGMENTS end
  for i = 1, last do
    rendering.draw_line({
      color = PATH_COLOR,
      width = 2,
      from = { p[2 * i - 1], p[2 * i] },
      to = { p[2 * i + 1], p[2 * i + 2] },
      surface = agent.surface,
      time_to_live = PATH_TTL,
      draw_on_ground = true,
    })
  end
end

Registry.on_removed(destroy_label)

return Render
