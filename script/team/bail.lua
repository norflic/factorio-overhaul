--[[
  Lot ETAGE4 : bail des tournées prises (règle pure : shared/team/bail.lua). À chaque pensée d'équipe, après la synchronisation du tableau
  (script/team/team.lua) : pour chaque tâche PRISE d'un type à bail (Bl.KINDS), relevé du progrès du PNJ qui la tient (étape, état de la
  machine, position) dans la tâche (t.prog, nombres seuls) ; bail échu : Worker.release_stuck (abandon, puis dégagement au bail suivant) et
  une ligne [FO-BAIL] qui dit l'état exact du PNJ (machine, étape, navigation, position). Un PNJ qui n'existe plus : la tâche est rendue.
  Interrupteur de banc : f.team.bail_regle == false coupe tout (comportement de 0.6.51). État : t.prog (dans la tâche), f.stats.bail_*.
]]
local Bl = require("shared.team.bail")
local State = require("script.faction.state")
local Registry = require("script.companion.registry")
local Board = require("script.team.board")
local Worker = require("script.team.worker")

local B = {}

B.LOGS = 40 -- lignes [FO-BAIL] au plus par équipe

--- État du PNJ AVANT qu'il soit rendu (machine, étape, navigation, but, position) : ce que le journal doit dire.
local function describe(agent)
  local e = agent and agent.entity
  local p = e and e.valid and e.position or { x = 0, y = 0 }
  local step = agent and agent.steps and agent.steps[agent.pc]
  local g = agent and agent.goal
  return string.format("PNJ %s etat %s, etape %s/%s (%s), nav %s (%s), but %s, position (%.1f, %.1f), %s", tostring(agent and agent.id),
    tostring(agent and agent.state), tostring(agent and agent.pc), tostring(agent and agent.steps and #agent.steps), tostring(step and step[1]),
    tostring(agent and agent.nav), tostring(agent and agent.nav_fail), g and string.format("(%.1f, %.1f)", g.x, g.y) or "-", p.x, p.y,
    agent and agent.street_walk and "rue" or "chemin")
end

local function line(f, t, desc, why, stall, tick)
  f.stats.bail_logs = (f.stats.bail_logs or 0) + 1
  if f.stats.bail_logs > B.LOGS then return end
  log(string.format("[FO-BAIL] %s : %s rendue (%s) apres %d s sans progres ; %s a %.1f min",
    f.key or "player", tostring(t.key), why, math.floor(stall / 60), desc, tick / 3600))
end

--- Une pensée d'équipe : relevés de progrès et baux échus. Rend le nombre de tâches rendues.
function B.think(f, tick)
  if not (f.team and f.team.bail_regle ~= false) then return 0 end
  local b = Board.get(f)
  local n = 0
  for _, key in ipairs(State.sorted_keys(b.tasks)) do
    local t = b.tasks[key]
    if t and t.worker and Bl.KINDS[t.kind] then
      local agent = Registry.get(t.worker)
      local e = agent and agent.entity
      if not (agent and e and e.valid and agent.task == t) then
        -- Le PNJ qui la tenait n'existe plus ou tient autre chose : la tâche est rendue (elle ne sera jamais finie par lui).
        f.stats.bail_orphan = (f.stats.bail_orphan or 0) + 1
        line(f, t, describe(agent), "sans PNJ", tick - (t.claimed or tick), tick)
        t.fail = t.fail or "bail"
        Board.finish(f, t, false, tick)
        n = n + 1
      else
        local p = e.position
        local prog, stall = Bl.progress(t.prog, { pc = agent.pc, state = agent.state, x = p.x, y = p.y }, tick)
        t.prog = prog
        if Bl.expired(t.kind, stall) then
          local desc = describe(agent)
          local how = Worker.release_stuck(agent, f, tick)
          f.stats.bail_released = (f.stats.bail_released or 0) + 1
          line(f, t, desc, how, stall, tick)
          t.prog = nil -- l'abandon est un progrès (nouvelle étape) ; le prochain relevé repart de zéro
          n = n + 1
        end
      end
    end
  end
  return n
end

return B
