--[[
  Couche DÉCISION des agents riches.

  - La voie "fo-brain" fait penser chaque agent une fois toutes les P ticks (fo-companion-brain-period),
    quelle que soit sa machine à états (agent.machine : "companion", "engineer", ...).
  - Ce fichier définit la machine "companion" :
        idle ──(objectif)──▶ pathing ──(chemin)──▶ moving ──(arrivée / échec)──▶ idle
    Comportements : "wander" (errance autour de home, charge de benchmark stable) et "follow" (suit le
    joueur propriétaire). La navigation elle-même est dans script/agents/nav.lua.
]]

local Storage = require("script.core.storage")
local Config = require("script.core.config")
local Scheduler = require("script.core.scheduler")
local FSM = require("script.core.fsm")
local RNG = require("script.core.rng")
local Registry = require("script.companion.registry")
local Render = require("script.companion.render")
local Nav = require("script.agents.nav")
local C = require("script.companion.constants")
local Profiler = require("script.core.profiler")

local Brain = {}

-- Lot PERF : portée du profileur par machine et par état (« brain:<machine>:<état> »), noms gardés en cache local
-- (aucune chaîne fabriquée à chaque pensée) ; rien n'est mesuré quand le profileur est éteint (un test).
local prof_names = {}
local function prof_name(machine, state)
  local m = prof_names[machine]
  if not m then m = {} prof_names[machine] = m end
  local n = m[state or "?"]
  if not n then n = "brain:" .. machine .. ":" .. tostring(state) m[state or "?"] = n end
  return n
end

local RING = {
  { 1, 0 }, { 0.7, 0.7 }, { 0, 1 }, { -0.7, 0.7 }, { -1, 0 }, { -0.7, -0.7 }, { 0, -1 }, { 0.7, -0.7 },
}

local function set(agent, state, tick)
  FSM.set(C.MACHINE, agent, state, tick)
end

local function owner_character(agent)
  if not agent.owner then return nil end
  local player = game.get_player(agent.owner)
  if not player or not player.valid then return nil end
  local c = player.character
  if c and c.valid and c.surface.index == agent.surface then return c end
  return nil
end

local function follow_goal(agent, cpos)
  local o = RING[agent.id % #RING + 1]
  return { x = cpos.x + o[1] * C.FOLLOW_RING, y = cpos.y + o[2] * C.FOLLOW_RING }
end

local function pick_goal(agent)
  if agent.behavior == "follow" then
    local c = owner_character(agent)
    if not c then return nil end
    local cpos, pos = c.position, agent.entity.position
    local dx, dy = cpos.x - pos.x, cpos.y - pos.y
    if dx * dx + dy * dy < C.FOLLOW_START_DIST * C.FOLLOW_START_DIST then return nil end
    return follow_goal(agent, cpos)
  end
  local r = agent.wander_radius
  local surface = agent.entity.surface
  local goal
  -- Moteur réel (session 3) : une destination sur l'eau est un échec de chemin garanti. 4 tirages au plus.
  for _ = 1, 4 do
    goal = {
      x = agent.home.x + (RNG.float() * 2 - 1) * r,
      y = agent.home.y + (RNG.float() * 2 - 1) * r,
    }
    local tile = surface.get_tile(math.floor(goal.x), math.floor(goal.y))
    if not (tile.valid and tile.collides_with("water-tile")) then return goal end
  end
  return goal
end

FSM.define(C.MACHINE, {
  idle = {
    enter = function(agent, tick)
      if agent.behavior == "follow" then
        agent.pause_until = tick + C.FOLLOW_PAUSE
      else
        agent.pause_until = tick + RNG.range(C.PAUSE_MIN, C.PAUSE_MAX)
      end
    end,
    think = function(agent, tick)
      if tick < agent.pause_until then return end
      local goal = pick_goal(agent)
      if goal then
        agent.goal = goal
        set(agent, "pathing", tick)
      end
    end,
  },

  pathing = {
    enter = function(agent, tick)
      Nav.go(agent, agent.goal, tick, { low_priority = agent.behavior == "wander" })
    end,
    think = function(agent, tick) Nav.think(agent, tick) end,
    on = {
      nav_moving = function(agent, tick) set(agent, "moving", tick) end,
      nav_failed = function(agent, tick) set(agent, "idle", tick) end,
    },
  },

  moving = {
    think = function(agent, tick)
      Nav.think(agent, tick)
      if agent.state ~= "moving" then return end -- Nav a pu signaler un blocage
      if agent.behavior == "follow" then
        local c = owner_character(agent)
        if c then
          local g = follow_goal(agent, c.position)
          local gx, gy = g.x - agent.goal.x, g.y - agent.goal.y
          if gx * gx + gy * gy > C.FOLLOW_REPATH_DIST * C.FOLLOW_REPATH_DIST then
            agent.goal = g
            set(agent, "pathing", tick)
          end
        end
      end
    end,
    exit = function(agent, tick)
      if agent.nav then Nav.stop(agent, tick) end
    end,
    on = {
      nav_arrived = function(agent, tick) set(agent, "idle", tick) end,
      nav_failed = function(agent, tick) set(agent, "idle", tick) end,
    },
  },
})

FSM.observe(C.MACHINE, function(agent)
  Render.state_changed(agent)
end)

local function think(id, tick)
  local agent = Registry.get(id)
  if not agent then
    Scheduler.remove(C.LANE_BRAIN, id)
    return
  end
  if not agent.entity.valid then
    Registry.remove(id, false)
    return
  end
  local machine = agent.machine or C.MACHINE
  if Profiler.enabled() then
    local n = prof_name(machine, agent.state)
    Profiler.start(n)
    FSM.think(machine, agent, tick)
    Profiler.stop(n)
    return
  end
  FSM.think(machine, agent, tick)
end

Scheduler.define_lane(C.LANE_BRAIN, function() return Config.get("brain_period") end, think)

Registry.on_removed(function(agent)
  Scheduler.remove(C.LANE_BRAIN, agent.id)
end)

--- Branche un agent sur le cerveau, dans l'état initial de sa machine.
function Brain.attach(agent, tick, initial_state)
  agent.machine = agent.machine or C.MACHINE
  Scheduler.add(C.LANE_BRAIN, agent.id)
  FSM.set(agent.machine, agent, initial_state or "idle", tick)
end

function Brain.state_counts()
  local counts = {}
  local agents = Storage.ns("companion").agents
  for _, id in ipairs(Registry.ids()) do
    local s = agents[id].state
    counts[s] = (counts[s] or 0) + 1
  end
  return counts
end

return Brain
