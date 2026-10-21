--[[
  Couche LOCOMOTION : suivi de waypoints par walking_state (8 directions).

  Seuls les agents en mouvement sont dans la voie "fo-loco" : le coût est O(agents en mouvement / k)
  par tick, k = période de pilotage (paramètre fo-companion-steer-period).

  Deux modes, pour trancher l'hypothèse H1 (RD_LOG.md) :
  - "lazy"  : walking_state n'est écrit que quand la direction change. Correct SEULEMENT si le moteur
              conserve walking_state d'un tick à l'autre pour un character sans joueur (H1).
  - "every" : walking_state est réécrit à chaque pilotage. Si H1 est fausse, il faudra k = 1.
  Le banc d'essai mesure l'efficacité de déplacement (distance réelle / distance théorique) qui
  discrimine les deux cas : ~0.9 si H1 vraie, proche de 0 si H1 fausse (en lazy, la direction ne change
  pas assez souvent pour relancer la marche : mesuré 0.04 au banc simulé).

  Zéro allocation par pilotage : les tables walking_state sont des constantes partagées
  (le moteur copie la valeur à l'affectation), le chemin est stocké à plat {x1, y1, x2, y2, ...}.
]]

local Storage = require("script.core.storage")
local Config = require("script.core.config")
local Scheduler = require("script.core.scheduler")
local Geometry = require("script.core.geometry")
local Registry = require("script.companion.registry")
local C = require("script.companion.constants")

local Locomotion = {}

local WALK, HALT = {}, {}
for d = 0, 7 do
  WALK[d] = { walking = true, direction = d }
  HALT[d] = { walking = false, direction = d }
end

local arrival_handler = nil
local speed_cache = nil

Storage.declare("loco", function()
  return { mode = "lazy", stats = { steers = 0, writes = 0, arrivals = 0 } }
end)

function Locomotion.speed()
  if not speed_cache then speed_cache = game.entity_prototypes[C.BODY].running_speed end
  return speed_cache
end

function Locomotion.on_arrival(fn)
  arrival_handler = fn
end

function Locomotion.mode()
  return Storage.ns("loco").mode
end

function Locomotion.set_mode(mode)
  assert(mode == "lazy" or mode == "every", "mode inconnu : " .. tostring(mode))
  Storage.ns("loco").mode = mode
end

function Locomotion.stats()
  return Storage.ns("loco").stats
end

--- Convertit un chemin moteur (array de PathfinderWaypoint) en tableau plat.
function Locomotion.set_path(agent, waypoints)
  local flat = {}
  local n = #waypoints
  for i = 1, n do
    local p = waypoints[i].position
    flat[2 * i - 1] = p.x
    flat[2 * i] = p.y
  end
  agent.path = flat
  agent.wpn = n
  agent.wp = 1
  agent.dir = -1
end

function Locomotion.start(agent)
  if agent.wpn > 0 then Scheduler.add(C.LANE_LOCO, agent.id) end
end

function Locomotion.stop(agent)
  Scheduler.remove(C.LANE_LOCO, agent.id)
  if agent.dir ~= -1 then
    if agent.entity.valid then agent.entity.walking_state = HALT[agent.dir] end
    agent.dir = -1
  end
end

local function steer(id, tick)
  local agent = Registry.get(id)
  if not agent then
    Scheduler.remove(C.LANE_LOCO, id)
    return
  end
  local e = agent.entity
  if not e.valid then
    Registry.remove(id, false)
    return
  end
  local L = Storage.ns("loco")
  local st = L.stats
  st.steers = st.steers + 1

  local r = Locomotion.speed() * Config.get("steer_period") * C.ARRIVE_STEER_FACTOR
  if r < C.ARRIVE_MIN_RADIUS then r = C.ARRIVE_MIN_RADIUS end
  local r2 = r * r

  local pos = e.position
  local px, py = pos.x, pos.y
  local path, i, n = agent.path, agent.wp, agent.wpn
  local dx, dy = path[2 * i - 1] - px, path[2 * i] - py
  while dx * dx + dy * dy <= r2 do
    i = i + 1
    if i > n then
      agent.wp = i
      st.arrivals = st.arrivals + 1
      Locomotion.stop(agent)
      if arrival_handler then arrival_handler(agent, tick) end
      return
    end
    dx, dy = path[2 * i - 1] - px, path[2 * i] - py
  end
  agent.wp = i

  local d = Geometry.direction8(dx, dy)
  if d ~= agent.dir or L.mode == "every" then
    e.walking_state = WALK[d]
    agent.dir = d
    st.writes = st.writes + 1
  end
end

Scheduler.define_lane(C.LANE_LOCO, function() return Config.get("steer_period") end, steer)

Registry.on_removed(function(agent)
  Scheduler.remove(C.LANE_LOCO, agent.id)
end)

return Locomotion
