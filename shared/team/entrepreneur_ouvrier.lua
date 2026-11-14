--[[
  shared/team/entrepreneur_ouvrier.lua — ouvrier dédié du chantier entrepreneur (lot entrepreneur-ouvrier, 14/11) : règles PURES (Lua 5.2).

  Un projet du plan marqué spec.entrepreneur (script/team/migration_champ.lua, Mig.entrepreneur_scan) et pas encore fini reçoit UN ouvrier
  de l'équipe (E.pick_worker : l'ouvrier courant gardé s'il vit, sinon le plus petit numéro vivant). À sa prise de tâche
  (script/team/board.lua, Board.claim), cet ouvrier prend D'ABORD une tâche libre de ce projet (E.task_ok) ; sans tâche libre du projet
  au tableau, il prend sa tâche ordinaire (jamais figé). À la fin du projet (fini ou disparu), il est libéré et le bilan est écrit
  ([FO-ENTREPRENEUR-OUVRIER] : tâches faites, durée de pose).
  Lecteurs : script/team/board.lua (Board.claim, Board.finish), tests/entrepreneur_ouvrier_test.lua.
]]

local Ent = require("shared.team.entrepreneur")

local Eo = {}

Eo.CFG = {
  refresh = 60, -- ticks entre deux relectures des projets (cache de l'ouvrier dédié)
  dedie = true, -- l'ouvrier dédié prend d'abord une tâche de son projet (faux : bilan seul, mesure A/B du banc)
  log_max = 120, -- lignes [FO-ENTREPRENEUR-OUVRIER] par équipe au plus
}

local function num_keys(t)
  local ks = {}
  for k in pairs(t or {}) do if type(k) == "number" then ks[#ks + 1] = k end end
  table.sort(ks)
  return ks
end

--- Projet entrepreneur vivant : le plus petit numéro dont spec.entrepreneur est vrai et l'état n'est pas « fini ». nil sinon.
function Eo.live_pid(projects)
  for _, id in ipairs(num_keys(projects)) do
    local p = projects[id]
    if p and p.spec and Ent.monopoly(p.spec) and p.state ~= "fini" then return id end
  end
  return nil
end

--- Avance la fiche de l'ouvrier dédié. rec = fiche courante (ou nil) ; pid = projet vivant (ou nil) ; ids = numéros des PNJ ;
--- alive = { [id] = true } ; tick. Rend la fiche neuve (ou nil) et la liste des événements { { "lie" | "libere" | "relie", fiche } }.
function Eo.step(rec, pid, ids, alive, tick)
  local ev = {}
  if rec and rec.pid ~= pid then
    rec.t_end = tick
    ev[#ev + 1] = { "libere", rec }
    rec = nil
  end
  if pid == nil then return nil, ev end
  local wid = Ent.pick_worker(ids, alive, rec and rec.wid or nil)
  if not rec then
    rec = { pid = pid, wid = wid, t_bind = tick, own = 0, other = 0, fail = 0, claims = 0 }
    ev[#ev + 1] = { "lie", rec }
  elseif wid ~= rec.wid then
    rec.wid = wid
    ev[#ev + 1] = { "relie", rec }
  end
  return rec, ev
end

--- Tâche libre du projet pour l'ouvrier dédié : la première de `list` (déjà triée : priorité, clé), libre, encore au tableau (tasks),
--- dont le projet est `pid` (E.task_ok) et que `ok(t)` accepte (matière stricte, nil = toujours). Rend l'index ou nil.
function Eo.pick(list, tasks, pid, ok)
  for i, t in ipairs(list or {}) do
    local tp = t.ia1d and t.ia1d.pid
    if not t.worker and tasks[t.key] == t and tp ~= nil and Ent.task_ok(pid, tp, nil) and (ok == nil or ok(t)) then return i end
  end
  return nil
end

--- Compte une fin de tâche du projet dans la fiche (ok : réussie ; own : faite par l'ouvrier dédié).
function Eo.note_done(rec, task, wid, ok, tick)
  if not (rec and task and task.ia1d and task.ia1d.pid == rec.pid) then return false end
  if not ok then rec.fail = rec.fail + 1
  elseif wid ~= nil and wid == rec.wid then rec.own = rec.own + 1
  else rec.other = rec.other + 1 end
  rec.t_last = tick
  return true
end

--- Compte une prise de tâche du projet (n'importe quel ouvrier) : date de la première prise (début de la pose).
function Eo.note_claim(rec, task, tick)
  if not (rec and task and task.ia1d and task.ia1d.pid == rec.pid) then return false end
  rec.claims = rec.claims + 1
  if not rec.t_first then rec.t_first = tick end
  return true
end

return Eo
