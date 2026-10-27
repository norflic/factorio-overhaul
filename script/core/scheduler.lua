--[[
  Ordonnanceur à budget déterministe.

  Deux primitives :

  1. VOIES (lanes) en ROUE DE PÉRIODES : un ensemble d'identifiants traités chacun exactement une fois
     toutes les P ticks. Chaque id reçoit un créneau fixe s ∈ [1, P] (attribution tournante) et il est
     traité aux ticks où (tick % P) + 1 == s. Charge par tick ≈ n / P.
     Coût par tick d'une voie = (n / P) * c_handler. C'est LA formule de budget UPS du projet.

  2. MINUTERIES (timers) : "appelle le handler H avec la charge utile X au tick T". Roue indexée par tick,
     coût O(1) par tick.

  Garanties (testées dans tests/run.lua, P ∈ {1, 3, 7, 60}, forte rotation d'ids) :
  - Période exacte : à P constant, deux passages d'un même id sont séparés d'exactement P ticks ;
    un id ajouté est traité pour la première fois dans les P ticks.
  - Jamais deux passages d'un même id dans un même tick, même si un handler ajoute ou retire des ids
    (le sien ou d'autres), y compris un retrait suivi d'un ré-ajout.
  - Retrait O(1) : l'entrée devient périmée et elle est nettoyée au prochain passage de son créneau.

  Historique (RD_LOG) : la v1 "curseur round-robin" a échoué au banc sous rotation (doubles passages,
  attentes jusqu'à 2P) car son débit dépendait du nombre d'ids vivants. La roue n'a pas ce défaut.

  Tout l'état est dans le stockage persistant ; les handlers sont résolus par nom au runtime.
  Seule la table `stamps` est locale : elle ne sert qu'à l'intérieur d'un tick (aucun état inter-ticks),
  donc tous les clients calculent la même chose.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local Profiler = require("script.core.profiler")

local Scheduler = {}

local lanes = {}       -- [name] = { period = fn() -> int, handler = fn(id, tick), prof = string }
local lane_order = {}  -- ordre de traitement = ordre de définition
local timer_handlers = {}
local stamps = {}      -- [name] = { [id] = tick du dernier passage } (local, intra-tick uniquement)

Storage.declare("sched", function()
  return { lanes = {}, timers = {} }
end)

local function current_period(name)
  local p = math.floor(lanes[name].period())
  if p < 1 then p = 1 end
  return p
end

-- Réattribue tous les ids vivants sur P créneaux, dans un ordre déterministe.
local function rebuild(st, period)
  local ids, seen = {}, {}
  local old = st.buckets
  for s = 1, (st.period or 0) do
    local b = old[s]
    if b then
      for i = 1, #b do
        local id = b[i]
        if st.slot_of[id] == s and not seen[id] then
          seen[id] = true
          ids[#ids + 1] = id
        end
      end
    end
  end
  local buckets, slot_of = {}, {}
  for s = 1, period do buckets[s] = {} end
  for k = 1, #ids do
    local s = (k - 1) % period + 1
    local b = buckets[s]
    b[#b + 1] = ids[k]
    slot_of[ids[k]] = s
  end
  st.buckets, st.slot_of, st.period, st.rr, st.count = buckets, slot_of, period, #ids, #ids
end

local function lane_state(name)
  local S = Storage.ns("sched")
  local st = S.lanes[name]
  if not st then
    st = { buckets = {}, slot_of = {}, period = nil, rr = 0, count = 0 }
    S.lanes[name] = st
  end
  local p = current_period(name)
  if st.period ~= p then rebuild(st, p) end
  return st
end

--- Définit une voie. `period` : nombre ou fonction renvoyant un nombre de ticks (>= 1).
function Scheduler.define_lane(name, period, handler)
  assert(not lanes[name], "voie déjà définie : " .. name)
  local period_fn = period
  if type(period) == "number" then period_fn = function() return period end end
  lanes[name] = { period = period_fn, handler = handler, prof = "lane:" .. name }
  lane_order[#lane_order + 1] = name
  stamps[name] = {}
end

function Scheduler.define_timer(name, handler)
  assert(not timer_handlers[name], "timer déjà défini : " .. name)
  timer_handlers[name] = handler
end

function Scheduler.add(lane, id)
  local st = lane_state(lane)
  if st.slot_of[id] then return end
  local s = st.rr % st.period + 1
  st.rr = st.rr + 1
  local b = st.buckets[s]
  b[#b + 1] = id
  st.slot_of[id] = s
  st.count = st.count + 1
end

function Scheduler.has(lane, id)
  local st = Storage.ns("sched").lanes[lane]
  return st ~= nil and st.slot_of[id] ~= nil
end

function Scheduler.count(lane)
  local st = Storage.ns("sched").lanes[lane]
  return st and st.count or 0
end

function Scheduler.remove(lane, id)
  local st = Storage.ns("sched").lanes[lane]
  if not st or not st.slot_of[id] then return end
  st.slot_of[id] = nil
  st.count = st.count - 1
end

--- Programme un timer. `delay` >= 1 tick. `payload` doit être sérialisable (pas de fonction).
function Scheduler.after(delay, timer_name, payload)
  assert(timer_handlers[timer_name], "timer inconnu : " .. tostring(timer_name))
  if delay < 1 then delay = 1 end
  local at = game.tick + math.floor(delay)
  local timers = Storage.ns("sched").timers
  local bucket = timers[at]
  if not bucket then
    bucket = {}
    timers[at] = bucket
  end
  bucket[#bucket + 1] = { h = timer_name, p = payload }
end

local function run_timers(S, tick)
  local due = S.timers[tick]
  if not due then return end
  S.timers[tick] = nil
  for i = 1, #due do
    local t = due[i]
    local h = timer_handlers[t.h]
    if h then h(t.p, tick) end
  end
end

local function run_lane(name, tick)
  local st = Storage.ns("sched").lanes[name]
  if not st or (st.count == 0 and st.period) then return end
  local p = current_period(name)
  if st.period ~= p then rebuild(st, p) end
  local s = tick % p + 1
  local b = st.buckets[s]
  local n = #b
  if n == 0 then return end

  local cfg = lanes[name]
  local handler, slot_of, stamp = cfg.handler, st.slot_of, stamps[name]
  Profiler.start(cfg.prof)
  local j = 0
  for i = 1, n do
    local id = b[i]
    if slot_of[id] == s and stamp[id] ~= tick then
      stamp[id] = tick
      j = j + 1
      b[j] = id
      handler(id, tick)
    end
  end
  -- Les ids ajoutés à ce créneau pendant l'itération (indices > n) sont conservés pour le prochain tour.
  local m = #b
  for k = n + 1, m do
    j = j + 1
    b[j] = b[k]
  end
  for k = m, j + 1, -1 do b[k] = nil end
  Profiler.stop(cfg.prof)
end

function Scheduler.run(tick)
  local S = Storage.ns("sched")
  Profiler.start("sched:timers")
  run_timers(S, tick)
  Profiler.stop("sched:timers")
  for i = 1, #lane_order do
    run_lane(lane_order[i], tick)
  end
end

Events.on(defines.events.on_tick, function(e)
  Scheduler.run(e.tick)
end)

return Scheduler
