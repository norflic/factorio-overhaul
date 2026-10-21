--[[
  Tableau des tâches d'une équipe : ce que le cerveau a décidé, qui s'en occupe.

  f.team.board = { tasks = { [clé] = tâche } }   tâche.worker = id d'ouvrier si prise
  - sync : remplace les tâches LIBRES par le nouveau plan ; les tâches prises continuent.
  - claim : l'ouvrier prend la tâche libre la plus prioritaire (ordre déterministe : priorité, clé).
  - finish : tâche terminée (réussie ou non) ; un échec la met en pause un moment (pas de boucle d'échecs).
]]

local Board = {}

local RETRY_TICKS = 1800

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

function Board.get(f)
  f.team.board = f.team.board or { tasks = {}, cooldown = {} }
  return f.team.board
end

--- Clés des tâches prises (pour que le cerveau ne les replanifie pas).
function Board.open(f)
  local b = Board.get(f)
  local open = {}
  for key, t in pairs(b.tasks) do if t.worker then open[key] = true end end
  return open
end

function Board.sync(f, planned, tick)
  local b = Board.get(f)
  local keep = {}
  for key, t in pairs(b.tasks) do
    if t.worker then keep[key] = t end
  end
  for _, t in ipairs(planned) do
    local cd = b.cooldown[t.key]
    if not keep[t.key] and not (cd and tick < cd) then
      t.created = tick
      keep[t.key] = t
    end
  end
  b.tasks = keep
end

function Board.claim(f, agent, tick)
  local b = Board.get(f)
  local best
  for _, key in ipairs(sorted_keys(b.tasks)) do
    local t = b.tasks[key]
    if not t.worker and (not best or t.prio > best.prio) then best = t end
  end
  if best then
    best.worker = agent.id
    best.claimed = tick
  end
  return best
end

function Board.finish(f, task, ok, tick)
  local b = Board.get(f)
  if b.tasks[task.key] == task then b.tasks[task.key] = nil end
  local st = f.team.task_stats
  st[task.kind] = st[task.kind] or { ok = 0, fail = 0 }
  if ok then
    st[task.kind].ok = st[task.kind].ok + 1
  else
    st[task.kind].fail = st[task.kind].fail + 1
    b.cooldown[task.key] = tick + RETRY_TICKS
    if task.fail then
      f.team.fail_reasons[task.fail] = (f.team.fail_reasons[task.fail] or 0) + 1
    end
  end
end

--- Objets attendus des fabrications en cours (le cerveau ne les recommande pas).
function Board.incoming(f)
  local b = Board.get(f)
  local inc = {}
  for _, key in ipairs(sorted_keys(b.tasks)) do
    local t = b.tasks[key]
    if t.worker and t.kind == "craft" then inc[t.item] = (inc[t.item] or 0) + t.count end
  end
  return inc
end

function Board.count(f)
  local b = Board.get(f)
  local open, taken = 0, 0
  for _, t in pairs(b.tasks) do
    if t.worker then taken = taken + 1 else open = open + 1 end
  end
  return open, taken
end

--- Tâches de construction en cours, par type d'avant-poste (le cerveau les compte comme « en chantier »).
function Board.pending(f)
  local b = Board.get(f)
  local pend, smelters = {}, 0
  local fortify = {}
  for _, t in pairs(b.tasks) do
    if t.worker then
      if t.kind == "build" or t.kind == "extend" then pend[t.outpost_kind] = (pend[t.outpost_kind] or 0) + 1 end
      if t.kind == "smelters" then smelters = smelters + t.count end
      if t.kind == "fortify" then fortify[t.outpost] = true end
    end
  end
  return pend, smelters, fortify
end

function Board.has(f, key)
  local t = Board.get(f).tasks[key]
  return t ~= nil and t.worker ~= nil
end

return Board
