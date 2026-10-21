--[[
  Navigation partagée des agents riches (compagnons, ingénieurs de faction).

  Un agent "navigue" vers agent.goal : demande de chemin (PathService) -> suivi de waypoints (Locomotion),
  avec détection de blocage. La navigation ne décide de rien : elle émet des événements vers la machine à
  états de l'agent (agent.machine) :
    "nav_moving"  : chemin trouvé, l'agent marche ;
    "nav_arrived" : destination atteinte ;
    "nav_failed"  : pas de chemin, abandon ou blocage (raison dans agent.nav_fail : "no_path", "stuck",
                    "timeout", "busy", "dropped").

  État porté par l'agent (sérialisable) : nav ("pathing" | "moving" | nil), nav_tick, goal, ticket,
  last_x, last_y, last_check, stuck.
]]

local PathService = require("script.core.path_service")
local FSM = require("script.core.fsm")
local Registry = require("script.companion.registry")
local Locomotion = require("script.companion.locomotion")
local Render = require("script.companion.render")
local C = require("script.companion.constants")

local Nav = {}

local HANDLER = "fo-nav"

local function emit(agent, event, tick)
  FSM.event(agent.machine, agent, event, tick)
end

local function measure(agent, tick)
  local pos = agent.entity.position
  local dx, dy = pos.x - agent.last_x, pos.y - agent.last_y
  local moved = math.sqrt(dx * dx + dy * dy)
  local dt = tick - agent.last_check
  agent.last_x, agent.last_y, agent.last_check = pos.x, pos.y, tick
  local stats = Registry.stats()
  stats.dist = stats.dist + moved
  stats.move_ticks = stats.move_ticks + dt
  return moved, dt
end

--- Lance une navigation vers goal = { x, y }.
function Nav.go(agent, goal, tick, opts)
  opts = opts or {}
  if agent.nav == "moving" then Nav.stop(agent, tick) end
  agent.goal = goal
  agent.nav = "pathing"
  agent.nav_tick = tick
  local e = agent.entity
  local pos = e.position
  -- Trajets longs (ingénieurs vers des sites à 300-400 tuiles) : pas de marge de boîte, le corps passe
  -- entre les arbres des forêts denses (la marge H4 sert au suivi rapproché, pas aux longs trajets).
  local gdx, gdy = goal.x - pos.x, goal.y - pos.y
  local long = gdx * gdx + gdy * gdy > 150 * 150
  -- Grille de pathfinding : pleine résolution. Moteur réel (session 3) : la grille grossière (-1) produisait
  -- des chemins qui rasaient falaises et arbres ; les ingénieurs restaient bloqués au même point.
  local res = 0
  agent.nav_fail = nil
  agent.ticket = PathService.request(HANDLER, agent.id, {
    surface = agent.surface,
    proto = C.BODY,
    pad = long and 0 or C.PATH_BBOX_PAD,
    start = { x = pos.x, y = pos.y },
    goal = goal,
    force = e.force.name,
    radius = opts.radius or C.PATH_RADIUS,
    flags = { cache = true, prefer_straight_paths = true, low_priority = opts.low_priority or false },
    ignore = e,
    res = res,
  })
end

--- Interrompt la navigation (sans événement).
function Nav.stop(agent, tick)
  if agent.nav == "moving" and tick and agent.entity.valid then measure(agent, tick) end
  Locomotion.stop(agent)
  agent.nav = nil
end

function Nav.active(agent)
  return agent.nav ~= nil
end

--- À appeler à chaque pensée de l'agent pendant une navigation : abandon et détection de blocage.
function Nav.think(agent, tick)
  if agent.nav == "pathing" then
    if tick - agent.nav_tick > C.PATH_GIVE_UP_TICKS then
      agent.nav = nil
      agent.nav_fail = "timeout"
      emit(agent, "nav_failed", tick)
    end
  elseif agent.nav == "moving" then
    local moved, dt = measure(agent, tick)
    if moved < C.STUCK_RATIO * Locomotion.speed() * dt then
      agent.stuck = agent.stuck + 1
      if agent.stuck >= C.STUCK_LIMIT then
        Registry.stats().stuck = Registry.stats().stuck + 1
        Locomotion.stop(agent)
        agent.nav = nil
        agent.nav_fail = "stuck"
        emit(agent, "nav_failed", tick)
      end
    else
      agent.stuck = 0
    end
  end
end

PathService.register_handler(HANDLER, function(id, path, ticket, reason, tick)
  local agent = Registry.get(id)
  if not agent or agent.nav ~= "pathing" or agent.ticket ~= ticket then return end -- résultat périmé
  if path and #path > 0 and agent.entity.valid then
    Locomotion.set_path(agent, path)
    local pos = agent.entity.position
    agent.last_x, agent.last_y, agent.last_check = pos.x, pos.y, tick
    agent.stuck = 0
    agent.nav = "moving"
    Locomotion.start(agent)
    Render.path(agent)
    emit(agent, "nav_moving", tick)
  else
    Registry.stats().path_fail = Registry.stats().path_fail + 1
    agent.nav = nil
    agent.nav_fail = reason or "no_path"
    emit(agent, "nav_failed", tick)
  end
end)

Locomotion.on_arrival(function(agent, tick)
  if agent.nav ~= "moving" then return end
  measure(agent, tick)
  agent.nav = nil
  emit(agent, "nav_arrived", tick)
end)

return Nav
