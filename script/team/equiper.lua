--[[
  Lot LEVIERS : tâche « equiper » des PNJ d'une faction — insérer des modules dans des machines DÉJÀ POSÉES (fours,
  assembleurs, foreuses). Décidée par la capitalisation (shared/ai3/leviers.lua, ordre de la sorte « equiper »), postée par
  script/ai3/capitalisation.lua. Le PNJ prend les modules au coffre du QG (étape « take » stricte), marche jusqu'à chaque
  machine de son lot (étapes « goto »), les insère (ACTS.equiper) puis rentre : AUCUN bâtiment ni module posé sans le
  travail d'un PNJ (consigne : « Bâtiments posés par script sans travail de PNJ : de la triche »).

  Après l'insertion, la balise cachée de la machine est recalculée tout de suite (script/modules/mult.lua) : le moteur
  additionne les modules, le mod multiplie (barème D-17) ; sans ce rappel, la machine attendrait le balayage tournant.
  Contrôles d'honnêteté : l'insertion passe par `can_insert` du moteur (effet ou recette non permis : refus, la machine
  est comptée « faite » sans module) ; le résultat est écrit dans l'ordre ouvert (f.team.capi.open[].inserted).
  Déterminisme : ordre des machines fixé par l'ordre, aucun pairs, aucun temps mesuré. Données : numéros d'unité et
  positions (nombres), jamais d'entité ni de fonction dans `global`.
]]

local Mult = require("script.modules.mult")

local Equip = {}

Equip.KIND = "equiper"
Equip.BATCH = 6     -- machines par tâche (une tournée courte : le travail compté est celui d'une pose par module)
Equip.PRIO = 55     -- sous l'urgence (90), au niveau d'une construction ordinaire
Equip.REACH = 3     -- tuiles : le PNJ s'arrête près de la machine (le centre est occupé)

--- Programme d'une tâche : prise au coffre, une étape de marche et une d'insertion par machine, retour au QG.
function Equip.program(f, task)
  if not (task.targets and #task.targets > 0 and task.items) then return nil end
  local steps = { { "home" }, { "take", task.items, strict = true } }
  for _, t in ipairs(task.targets) do
    steps[#steps + 1] = { "goto", { x = t.x, y = t.y }, Equip.REACH }
    steps[#steps + 1] = { "act", "equiper" }
  end
  steps[#steps + 1] = { "home" }
  task.ti = 0
  return steps
end

local function open_rec(f, key)
  local cs = f.team and f.team.capi
  if not cs then return nil end
  for _, rec in ipairs(cs.open or {}) do
    if rec.key == key then return rec end
  end
  return nil
end

--- Insère les modules de la tâche dans la machine visée. Renvoie vrai (même si la machine a disparu ou refuse : elle est
--- alors comptée traitée, l'ordre le sait).
function Equip.act(agent, f, task, surface, tick)
  task.ti = (task.ti or 0) + 1
  local t = task.targets and task.targets[task.ti]
  if not t then return true end
  local rec = open_rec(f, task.rec_key)
  local function mark(n, why)
    if not rec then return end
    rec.done = rec.done or {}
    rec.done[#rec.done + 1] = t.u
    rec.inserted = (rec.inserted or 0) + n
    if why then rec.refused = (rec.refused or 0) + 1 rec.why_refused = why end
  end
  local list = surface.find_entities_filtered({ position = { t.x, t.y }, name = t.entity, force = f.force, limit = 1 })
  local e = list[1]
  if not (e and e.valid) then mark(0, "machine disparue") return true end
  local inv = e.get_module_inventory()
  if not inv then mark(0, "aucun emplacement") return true end
  local mine = agent.entity.get_main_inventory()
  local have = mine.get_item_count(task.module)
  local want = math.min(task.per or 1, have)
  local put = 0
  for _ = 1, want do
    if not inv.can_insert({ name = task.module, count = 1 }) then break end
    if inv.insert({ name = task.module, count = 1 }) < 1 then break end
    mine.remove({ name = task.module, count = 1 })
    put = put + 1
  end
  if put > 0 then Mult.refresh(e, true) end
  local why = nil
  if put < (task.per or 1) then
    why = have <= 0 and "aucun module sur le PNJ" or (put == 0 and "insertion refusee par le moteur" or "emplacements insuffisants")
  end
  mark(put, why)
  return true
end

return Equip
