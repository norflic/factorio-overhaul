--[[
  Tableau des tâches d'une équipe : ce que le cerveau a décidé, qui s'en occupe.

  f.team.board = { tasks = { [clé] = tâche }, list = { tâche, ... } }   tâche.worker = id d'ouvrier si prise
  - sync : remplace les tâches LIBRES par le nouveau plan ; les tâches prises continuent. Lot IA1-a : le
    tableau est TRIÉ UNE FOIS par pensée (O.sort_tasks : priorité décroissante, puis clé) dans `list`.
  - claim : l'ouvrier prend la tâche libre la plus prioritaire (ordre déterministe : priorité, clé), en UN
    passage sur `list` (O.pick_task). Avant IA1-a, chaque prise triait toutes les clés : O(T log T) par
    ouvrier inoccupé et par pensée, soit 30 tris par pensée pour 30 PNJ.
  - finish : tâche terminée (réussie ou non) ; un échec la met en pause un moment (pas de boucle d'échecs).
]]

local O = require("shared.team.org")

local Board = {}

local RETRY_TICKS = 1800

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Liste triée des tâches du tableau (priorité décroissante, puis clé), une fois par pensée.
local function rebuild_list(b)
  local list = {}
  for _, key in ipairs(sorted_keys(b.tasks)) do list[#list + 1] = b.tasks[key] end
  b.list = O.sort_tasks(list)
end

function Board.get(f)
  f.team.board = f.team.board or { tasks = {}, cooldown = {} }
  local b = f.team.board
  -- Sauvegarde d'avant IA1-a : la liste triée se reconstruit à la première lecture (jamais dans on_load).
  if not b.list then rebuild_list(b) end
  return b
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
  rebuild_list(b)
end

-- PNJ « neutre » du lot IA1-a : ni pôle, ni projet, ni zone (les pôles arrivent au lot IA1-b). Avec le rôle
-- généraliste et sans pôle, O.pick_task rend la PREMIÈRE tâche libre de la liste triée (urgence au rang 3,
-- le reste au rang 6, à rang égal l'ordre de la liste) : exactement la règle de l'ancien Board.claim (priorité
-- la plus haute, à égalité la plus petite clé). Contrôlé hors jeu sur des tableaux tirés au hasard
-- (tests/ia1_scale_test.lua). Aucun plafond hors pôle ni plafond manuel : rien n'est encore réparti par pôle.
local NEUTRAL = { role = "generalist" }

function Board.claim(f, agent, tick)
  local b = Board.get(f)
  local list = b.list
  -- Une tâche de la liste retirée du tableau depuis la pensée (finie) a un ouvrier : pick_task l'ignore.
  local i = O.pick_task(NEUTRAL, list)
  local best = i and list[i]
  if best and b.tasks[best.key] ~= best then best = nil end
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
