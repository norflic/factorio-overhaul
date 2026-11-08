--[[
  Lot ZERO-IDLE-3 : mesure des causes d'inactivité (règle pure : shared/ai3/inactivite.lua). Appelée par l'état idle de
  script/team/worker.lua à chaque pensée d'un PNJ sans tâche. Cumul par équipe dans f.team.inact (nombres et chaînes), ligne
  [FO-INACTIF-CAUSE] par minute. Lecture seule : aucune décision n'en dépend.
]]

local I = require("shared.ai3.inactivite")

local Rt = {}

--- Ticks de cette pensée pour `agent` (écart avec sa pensée précédente) ; marque la pensée.
function Rt.dt(agent, tick)
  local d = I.dt(agent.idle_seen, tick)
  agent.idle_seen = tick
  return d
end

--- Le PNJ part au travail : sa prochaine attente repartira d'une période.
function Rt.depart(agent)
  agent.idle_seen = nil
end

--- Note l'issue `key` d'une pensée de `dt` ticks ; écrit la ligne de la minute quand elle est écoulée.
function Rt.note(f, agent, tick, key, dt)
  local team = f.team
  if not team then return end
  if agent.bg then key = key .. "+fabrique" end
  team.inact = I.note(team.inact, key, dt, tick)
  if I.due(team.inact, tick) then
    local line = I.line(f.key or (f.is_player and "player") or tostring(f.id), math.floor(tick / 3600), team.inact,
      f.engineers_count or 0, tick - team.inact.t0)
    if line then log(line) end
    team.inact = nil
  end
end

return Rt
