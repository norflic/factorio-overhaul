--[[
  Lot COLLECTE (7/11) : rappel d'un PNJ occupé pour une tâche urgente (priorité 90 ou plus) que personne ne prend. Règle pure :
  shared/team/rappel_urgent.lua (cas, mutants, coût : tests/rappel_urgent_test.lua). Appelé par Team.think (script/team/team.lua), à côté de
  Poles.sur_stops, avec la même suite : Worker.abort(agent, f, tick, "preempte") ; ce fichier ne décide rien d'autre que de CHOISIR.
  Lecture seule hors f.team.rappel_at (tick du dernier rappel) et f.stats.rappels (compte, pour le journal).
  Ne requiert ni script/team/worker.lua (cycle) ni poles.lua : le PNJ rappelé est rendu à l'appelant.
]]
local R = require("shared.team.rappel_urgent")
local O = require("shared.team.org")
local Re = require("shared.ai3.reaction")
local State = require("script.faction.state")
local Board = require("script.team.board")
local Registry = require("script.companion.registry")

local Rp = {}

Rp.LOGS = 20 -- lignes [FO-RAPPEL] au plus par équipe et par partie

--- PNJ à rappeler (liste de 0 ou 1 agent) pour cette équipe à ce tick.
function Rp.stops(f, tick)
  if not (f.team and f.engineers and f.hq_pos) then return {} end
  -- Filtre peu coûteux : au moins une tâche libre urgente au tableau ?
  local tasks = {}
  for _, t in ipairs(Board.get(f).list or {}) do
    if not t.worker and (t.prio or 0) >= R.URGENT then
      local pos = t.ia1d and t.ia1d.ax and { x = t.ia1d.ax, y = t.ia1d.ay } or f.hq_pos
      tasks[#tasks + 1] = { key = t.key, prio = t.prio, created = t.created, x = pos.x, y = pos.y,
        ok = not O.DESIGN_KINDS[t.kind] and Board.prenable(f, t) }
    end
  end
  if #tasks == 0 then return {} end
  local npcs = {}
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    local e = a and a.entity
    if e and e.valid then
      local t = a.task
      local busy = t ~= nil and not a.failed -- un PNJ qui rentre après un échec compte comme libre
      npcs[#npcs + 1] = { id = id, busy = busy, prio = t and t.prio or 0, x = e.position.x, y = e.position.y,
        defending = t ~= nil and (Re.recall_exempt(t.kind, t.defend) or t.tag == "annexe-urgente"),
        explore = t ~= nil and t.kind == "explore" }
    end
  end
  local pick = R.pick({ tick = tick, last_at = f.team.rappel_at, tasks = tasks, npcs = npcs })
  if not pick then return {} end
  local a = Registry.get(pick.npc)
  if not (a and a.task) then return {} end
  f.team.rappel_at = tick
  f.stats.rappels = (f.stats.rappels or 0) + 1
  if f.stats.rappels <= Rp.LOGS then
    log(string.format("[FO-RAPPEL] %s a %.1f min : tache urgente %s (priorite libre au tableau), PNJ %d rappele, tache abandonnee %s (%s, priorite %d)",
      f.key or "player", tick / 3600, tostring(pick.urgent), pick.npc, tostring(a.task.key), tostring(a.task.kind), pick.dropped_prio))
  end
  return { a }
end

return Rp
