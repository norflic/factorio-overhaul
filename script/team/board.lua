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
  -- Lot IA1-b : une tâche libre replanifiée garde sa date de naissance (`created`) : l'attente d'une tâche se compte
  -- d'une pensée à l'autre (règle « tâche en souffrance » de Board.claim). Dates des tâches libres retirées gardées
  -- pour Board.add (le fond est rouvert après la pensée d'organisation).
  local born = {}
  for key, t in pairs(b.tasks) do
    if t.worker then keep[key] = t else born[key] = t.created end
  end
  for _, t in ipairs(planned) do
    local cd = b.cooldown[t.key]
    if not keep[t.key] and not (cd and tick < cd) then
      t.created = born[t.key] or tick
      keep[t.key] = t
    end
  end
  b.tasks = keep
  b.born = born
  rebuild_list(b)
end

--- Lot IA1-b : ajoute des tâches au tableau après la synchronisation (travail de fond, crise injectée par un banc).
--- Une clé déjà présente (prise ou libre) ou en pause après un échec est ignorée. Liste retriée une fois.
function Board.add(f, tasks, tick)
  local b = Board.get(f)
  local born = b.born or {}
  local n = 0
  for _, t in ipairs(tasks) do
    local cd = b.cooldown[t.key]
    if not b.tasks[t.key] and not (cd and tick < cd) then
      t.created = born[t.key] or tick
      b.tasks[t.key] = t
      n = n + 1
    end
  end
  if n > 0 then rebuild_list(b) end
  return n
end

-- PNJ « neutre » du lot IA1-a : ni pôle, ni projet, ni zone (les pôles arrivent au lot IA1-b). Avec le rôle
-- généraliste et sans pôle, O.pick_task rend la PREMIÈRE tâche libre de la liste triée (urgence au rang 3,
-- le reste au rang 6, à rang égal l'ordre de la liste) : exactement la règle de l'ancien Board.claim (priorité
-- la plus haute, à égalité la plus petite clé). Contrôlé hors jeu sur des tableaux tirés au hasard
-- (tests/ia1_scale_test.lua). Aucun plafond hors pôle ni plafond manuel : rien n'est encore réparti par pôle.
local NEUTRAL = { role = "generalist" }

-- Lot IA1-b : un PNJ placé dans un pôle (agent.org, script/team/poles.lua) prend sa tâche par O.pick_task avec son
-- rôle, son pôle EFFECTIF (destination différée comprise), sa partie, et la limite des urgences hors pôle.
-- Règle « tâche en souffrance » (garde-fou des petites équipes, où un pôle peut n'avoir aucun exécutant) : une tâche
-- du CERVEAU (pas du fond) libre depuis STARVE_TICKS passe devant le travail de FOND de n'importe quel PNJ ; elle ne
-- passe jamais devant une tâche du cerveau de son pôle. Sans pôle (avant la première pensée d'organisation), règle
-- d'IA1-a (NEUTRAL).
Board.STARVE_TICKS = 1800

local function starving(list, gen, tick)
  for i = 1, #list do
    local t = list[i]
    if not t.worker and not t.fond and t.created and tick - t.created >= Board.STARVE_TICKS
      and (gen or not O.DESIGN_KINDS[t.kind]) then
      return i
    end
  end
  return nil
end

function Board.claim(f, agent, tick)
  local b = Board.get(f)
  local list = b.list
  local org = agent.org
  local i, away
  if org and org.pole then
    local npc = { id = agent.id, role = org.role or "executant", pole = org.pole, dest = org.dest, project = org.project,
      zone = org.zone }
    local n_away = 0
    for k = 1, #list do
      local t = list[k]
      if t.worker and t.away then n_away = n_away + 1 end
    end
    local n_exec = (f.team.org and f.team.org.n_exec) or 0
    i, away = O.pick_task(npc, list, { urgent_away = n_away, urgent_away_cap = O.urgent_away_cap(n_exec) })
    if i == nil or list[i].fond then
      local s = starving(list, npc.role == "generalist", tick)
      if s then
        i, away = s, false
        if f.team.org then f.team.org.stats.starve_taken = f.team.org.stats.starve_taken + 1 end
      end
    end
    -- Rang 7 (écart déclaré à la table du §4.5) : un exécutant dont le pôle n'a plus rien à lui donner prend le
    -- travail de FOND d'un autre pôle (le plus prioritaire), plutôt que rester inactif. Le travail du cerveau reste
    -- réparti par pôle ; seul le fond est partagé.
    if i == nil then
      for k = 1, #list do
        local t = list[k]
        if not t.worker and t.fond then
          i, away = k, true
          if f.team.org then f.team.org.stats.fond_cross = (f.team.org.stats.fond_cross or 0) + 1 end
          break
        end
      end
    end
    -- Lot IA1-b2 (complément du DC, 25/10 : « sur les 8 PNJ y en avait pas mal qui faisaient rien ») : rang 8, un PNJ
    -- qui n'a RIEN à prendre (ni son pôle, ni le fond) prend la tâche du cerveau qui attend le plus haut dans la liste,
    -- quel que soit son pôle (essai 6 : 44 à 74 % des attentes avec des tâches libres d'un autre pôle). Votre équipe
    -- seulement (l'économie des factions règle l'ordre des difficultés de pvp_test).
    if i == nil and f.is_player then
      for k = 1, #list do
        local t = list[k]
        if not t.worker and (npc.role == "generalist" or not O.DESIGN_KINDS[t.kind]) then
          i, away = k, true
          if f.team.org then f.team.org.stats.brain_cross = (f.team.org.stats.brain_cross or 0) + 1 end
          break
        end
      end
    end
  else
    -- Une tâche de la liste retirée du tableau depuis la pensée (finie) a un ouvrier : pick_task l'ignore.
    i = O.pick_task(NEUTRAL, list)
  end
  local best = i and list[i]
  if best and b.tasks[best.key] ~= best then best = nil end
  if best then
    best.worker = agent.id
    best.claimed = tick
    best.away = (away and (best.prio or 0) >= O.URGENT_PRIO) or nil
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
    b.cooldown[task.key] = tick + (task.fond and RETRY_TICKS * 2 or RETRY_TICKS)
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
