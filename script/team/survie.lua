--[[
  Lot SURVIE-PENURIE : le MODE SURVIE d'une équipe de PNJ, côté moteur. La règle (entrée, sortie, hystérésis, tâches, porte) est
  PURE : shared/team/survie.lua (tests/survie_test.lua) ; ici seulement la lecture de l'état de l'équipe, le tableau des tâches et
  le journal [FO-SURVIE]. Aucun nom d'objet écrit ici : tout vient de shared/team/config.lua (T.outposts, T.smelter_inputs).

  État : f.team.survie = { on, since, entries, waits, relaxed, relax_why, mines, smelters, extends, said, ... } (nombres et tables ;
  créé en ÉVÈNEMENT par Survie.state, jamais dans on_load ; absent d'une sauvegarde d'avant le lot = mode éteint).

  Lecteurs de cet état (chaque écriture a au moins un lecteur) :
    s.on            Team.view (view.survie -> planificateur, shared/team/planner.lua -> Pr.decide), script/ai3/capitalisation.lua
                    (build_input), script/ai3/comportement.lua (M.gate) ;
    s.waits         Sv.paralysed (Survie.think) ;
    s.relaxed, s.relax_why, s.mines, s.smelters, s.extends   journal [FO-SURVIE] (bilan, sortie) ;
    s.keys          Sv.fresh (une tâche redemandée à chaque pensée n'est comptée qu'une fois) ;
    s.said          journal : une ligne la première fois que chaque effet agit pendant un séjour.
]]

local T = require("shared.team.config")
local Sv = require("shared.team.survie")
local Planner = require("shared.team.planner")
local Board = require("script.team.board")

local Survie = {}

-- Matières clés = produits des avant-postes (T.outposts) ; leur minerai ; le type d'avant-poste ; celles qui passent au four.
local KEYS, ORE_OF, KIND_OF, SMELTS = {}, {}, {}, {}
for _, kind in ipairs(T.OUTPOST_ORDER) do
  local spec = T.outposts[kind]
  KEYS[spec.product] = true
  ORE_OF[spec.product] = spec.resource
  KIND_OF[spec.product] = kind
  if T.smelter_inputs[spec.product] then SMELTS[spec.product] = true end
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- État de l'équipe, créé à la demande (en évènement seulement). Nil sans f.team.
function Survie.state(f)
  local t = f.team
  if not t then return nil end
  if not t.survie then t.survie = Sv.new() end
  return t.survie
end

--- Le mode est-il allumé ? (lecture seule : ne crée rien)
function Survie.on(f)
  local s = f and f.team and f.team.survie
  return s ~= nil and s.on == true
end

---------------------------------------------------------------------------------------------------
-- Porte (script/ai3/comportement.lua, M.gate)
---------------------------------------------------------------------------------------------------
--- Morts de l'heure à partir desquelles la porte attend pour cette tâche (nil : règle ordinaire).
function Survie.gate_deaths(f, kind) return Sv.gate_deaths(Survie.on(f), kind) end

--- Un refus de la porte (toute tâche, mode allumé ou non) : il compte pour la paralysie (shared/team/survie.lua, Sv.paralysed).
function Survie.note_wait(f, tick)
  local s = Survie.state(f)
  if s then Sv.note_wait(s, tick) end
end

--- Une décision de la porte vient d'être prise pour une tâche de ressources en mode survie. `base`/`base_why` : celle de la règle
--- ordinaire (même entrée), `decision`/`why` : celle qui s'applique. Un refus ordinaire devenu un départ est compté par motif (journal).
function Survie.note_gate(f, tick, base, base_why, decision, why)
  local s = Survie.state(f)
  if not s then return end
  if s.on and base == "wait" and decision ~= "wait" then
    s.relaxed = s.relaxed + 1
    s.relax_why[base_why] = (s.relax_why[base_why] or 0) + 1
    if not s.said["porte:" .. base_why] then
      s.said["porte:" .. base_why] = true
      log(string.format("[FO-SURVIE] %s : porte assouplie (%s -> %s) pour une tache de ressources a %.1f min (premiere fois de ce sejour)",
        tostring(f.key), base_why, why, tick / 3600))
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Pensée
---------------------------------------------------------------------------------------------------
local function said(f, s, key, tick, text)
  if s.said[key] then return end
  s.said[key] = true
  log(string.format("[FO-SURVIE] %s : %s a %.1f min (premiere fois de ce sejour)", tostring(f.key), text, tick / 3600))
end

local function relax_text(s)
  local parts = {}
  for _, k in ipairs(sorted_keys(s.relax_why)) do parts[#parts + 1] = string.format("%s %d", k, s.relax_why[k]) end
  return #parts > 0 and table.concat(parts, ", ") or "aucune"
end

local function totals(s)
  return string.format("portes assouplies %d (%s), minages demandes %d, fours demandes %d, agrandissements demandes %d",
    s.relaxed, relax_text(s), s.mines, s.smelters, s.extends)
end

--- Pensée de l'équipe (après le plan et la synchronisation du tableau). Décide l'entrée / la sortie du mode et, tant qu'il dure,
--- ajoute au tableau les tâches de survie. `view` : Team.view ; `plan` : le plan de la pensée.
function Survie.think(f, view, plan, tick)
  local s = Survie.state(f)
  if not s then return end
  local missing = {}
  for _, m in ipairs(plan.missing or {}) do missing[#missing + 1] = m end
  for _, k in ipairs(sorted_keys(plan.smelt)) do
    if type(plan.smelt[k]) == "number" then missing[#missing + 1] = { k, plan.smelt[k] } end
  end
  local short = Sv.shortages(missing, KEYS)
  local d = Sv.decide(s, { tick = tick, short = short, workers = view.workers or 0, idle = view.workers_idle or 0,
    threatened = view.threatened })
  if d.event == "entree" then
    s.said = {}
    s.relaxed, s.relax_why, s.mines, s.smelters, s.extends, s.keys = 0, {}, 0, 0, 0, {}
    log(string.format("[FO-SURVIE] %s : ENTREE en mode survie a %.1f min (entree n %d) : %s", tostring(f.key), tick / 3600, s.entries, d.cause))
  elseif d.event == "sortie" then
    log(string.format("[FO-SURVIE] %s : SORTIE du mode survie a %.1f min : %s ; bilan du sejour : %s", tostring(f.key), tick / 3600, d.cause, totals(s)))
  elseif d.event == "bilan" then
    log(string.format("[FO-SURVIE] %s : mode survie %s a %.1f min ; %s", tostring(f.key), d.cause, tick / 3600, totals(s)))
  end
  if not s.on then return end
  -- QG menacé (votre équipe : unités ennemies près du coffre) : tout le monde garde le coffre, aucune sortie.
  if view.hq_threat then return end
  local stock = view.stock or {}
  local b = Board.get(f)
  local tasks = {}
  -- 1. Minage à la main de la matière qui manque, par les PNJ sans tâche.
  local have = {}
  for _, t in ipairs(b.list or {}) do
    if t.kind == "mine" and t.resource then have[t.resource] = (have[t.resource] or 0) + 1 end
  end
  local mines = Sv.mines({ short = short, ore_of = ORE_OF, stock = stock, idle = view.workers_idle or 0, workers = view.workers or 0, have = have })
  for _, m in ipairs(mines) do
    tasks[#tasks + 1] = { key = "survie:mine:" .. m.ore .. ":" .. m.k, kind = "mine", prio = Sv.PRIO, resource = m.ore, count = m.count,
      prudent = true, danger_radius = Sv.MINE_DANGER_RADIUS, survie = true }
  end
  -- 2. Fours de réserve posés au QG, avec leur charbon.
  local n_sm = Sv.smelters({ short = short, smelts = SMELTS, smelters = view.smelters, pending = view.smelters_pending,
    stock_smelter = stock[T.SMELTER], stock_fuel = stock[T.fuel], fuel_per = T.fuel_per_burner })
  if n_sm > 0 then
    tasks[#tasks + 1] = { key = "smelters", kind = "smelters", prio = Sv.PRIO, count = n_sm,
      items = { { T.SMELTER, n_sm }, { T.fuel, T.fuel_per_burner * n_sm } }, survie = true }
  end
  -- 3. Foreuses de plus sur l'avant-poste le plus proche et sûr (à combustion : c'est ce que pose Outposts.extend).
  local function affordable(items)
    for _, it in ipairs(items) do if (stock[it[1]] or 0) < it[2] then return false end end
    return true
  end
  local aff, items_of = {}, {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    if (view.pending and view.pending[kind] or 0) == 0 then
      local full, mini = Planner.outpost_items(kind), Planner.minimal_items(kind)
      if affordable(full) then aff[kind], items_of[kind] = true, full
      elseif affordable(mini) then aff[kind], items_of[kind] = true, mini end
    end
  end
  local ops, lethal = {}, {}
  for _, o in ipairs(view.outposts or {}) do
    ops[#ops + 1] = { id = o.id, kind = o.kind, drills = o.drills, full = o.full, d2 = o.d2, max = T.max_drills(o.kind) }
    if o.lethal then lethal[o.id] = true end
  end
  for _, e in ipairs(Sv.extends({ short = short, kind_of = KIND_OF, outposts = ops, lethal = lethal, affordable = aff })) do
    tasks[#tasks + 1] = { key = "extend:" .. e.id, kind = "extend", prio = Sv.PRIO, outpost = e.id, outpost_kind = e.kind,
      items = items_of[e.kind], survie = true }
  end
  if #tasks == 0 then return end
  -- Board.add ignore une clé déjà au tableau (prise ou libre) ou en pause après un échec ; on compte ce qui est vraiment ajouté.
  -- Le tableau est refait à chaque pensée (Board.sync) : une tâche libre de survie est redemandée à chaque fois ; seule la PREMIÈRE
  -- demande d'une série est comptée au bilan (Sv.fresh).
  for _, t in ipairs(tasks) do
    if Board.add(f, { t }, tick) > 0 and Sv.fresh(s.keys, t.key, tick) then
      if t.kind == "mine" then
        s.mines = s.mines + 1
        said(f, s, "mine", tick, string.format("minage a la main de %s demande (%d) pour %s", t.resource, t.count, short[1] and short[1][1] or "?"))
      elseif t.kind == "smelters" then
        s.smelters = s.smelters + t.count
        said(f, s, "smelters", tick, string.format("pose de %d four(s) de reserve au QG demandee", t.count))
      else
        s.extends = s.extends + 1
        said(f, s, "extend", tick, string.format("agrandissement de l'avant-poste %s (%s) demande", tostring(t.outpost), tostring(t.outpost_kind)))
      end
    end
  end
end

return Survie
