--[[
  Mesure du coût script par sous-système (outil de R&D, désactivé par défaut).

  - Le drapeau "activé" vit dans le stockage persistant (identique sur tous les clients).
  - Les LuaProfiler vivent dans une table LOCALE : ils ne sont pas sérialisables et n'influencent jamais
    l'état du jeu (ils ne servent qu'à l'affichage). Un client qui rejoint en cours de mesure repart de zéro.
  - Interdit : piloter une décision de gameplay à partir d'un temps mesuré (désynchronisation garantie).
    Les budgets du mod sont exprimés en unités de travail déterministes (agents/tick), calibrées hors-ligne.
]]

local Storage = require("script.core.storage")

local Profiler = {}

Storage.declare("prof", function()
  return { enabled = false, since = 0 }
end)

local timers = {}
-- Chronomètres des portées attribuées après coup et comptes de passages (lot PERF ; voir Profiler.fmark). Lot PERF3 :
-- déclarés AVANT set_enabled, qui les remet à zéro (avant, sa remise à zéro écrivait une variable globale homonyme).
local marks = {}
local counts = {}
-- Lot PERF : copie LOCALE du mode fin (lue à chaque mesure fine, une vingtaine par pensée de PNJ : sans elle, chaque
-- appel relisait le stockage). Elle ne sert qu'à mesurer (jamais à décider) ; recopiée de global par set_enabled et par
-- chaque mesure ordinaire (Profiler.start, plusieurs fois par tick) : juste dès le premier tick après un chargement.
local fine_on = false

-- Lot PERF3 : DÉTAIL PAR TICK (bancs seulement, profiler(true, "detail")) : chaque portée (ordinaire ou fine) est aussi
-- chronométrée DANS le tick, avec sa portée mère ; au premier appel du tick suivant (hors de toute portée : c'est le
-- répartiteur d'un événement de premier niveau), une ligne « [FO-PERF3-T] <tick> <nom><mère> <durée> ... » part au
-- journal. tools/autotest/perf3.py en tire qui coûte à chaque pic. Tables LOCALES (jamais dans global, jamais lues par une
-- décision) ; mode allumé : le mode fin l'est aussi. Copie locale du drapeau, recopiée comme fine_on.
local detail_on = false
local dt_tick = -1
local dt_names = {}   -- portées vues dans le tick, dans l'ordre de première fin
local dt_acc = {}     -- [nom] = LuaProfiler accumulé dans le tick
local dt_mother = {}  -- [nom] = portée mère à sa première ouverture dans le tick ("-" : premier niveau)
local dt_run = {}     -- [nom] = chronomètre de l'ouverture en cours
local dt_stack = {}   -- portées ouvertes (noms), la plus récente en haut

local function refresh(p)
  detail_on = (p.enabled and p.detail == true) or false
  fine_on = (p.enabled and (p.fine == true or p.detail == true)) or false
end

local function dt_flush()
  local n = #dt_names
  if n > 0 then
    -- Une LocalisedString porte au plus 20 paramètres : paquets de 9 portées (18 paramètres), sous une table mère.
    local out = { "", "[FO-PERF3-T] ", tostring(dt_tick) }
    local chunk = { "" }
    for i = 1, n do
      local name = dt_names[i]
      chunk[#chunk + 1] = " " .. name .. "<" .. dt_mother[name] .. " "
      chunk[#chunk + 1] = dt_acc[name]
      if #chunk >= 19 then
        out[#out + 1] = chunk
        chunk = { "" }
      end
    end
    if #chunk > 1 then out[#out + 1] = chunk end
    log(out)
  end
  dt_names, dt_acc, dt_mother, dt_run, dt_stack = {}, {}, {}, {}, {}
end

local function dt_open(name)
  local tick = game.tick
  if tick ~= dt_tick then
    dt_flush()
    dt_tick = tick
  end
  if not dt_mother[name] then dt_mother[name] = dt_stack[#dt_stack] or "-" end
  dt_stack[#dt_stack + 1] = name
  local m = dt_run[name]
  if m then m.reset() else dt_run[name] = game.create_profiler() end
end

local function dt_close(name)
  local m = dt_run[name]
  if not m then return end
  m.stop()
  local a = dt_acc[name]
  if not a then
    a = game.create_profiler(true)
    dt_acc[name] = a
    dt_names[#dt_names + 1] = name
  end
  a.add(m)
  if dt_stack[#dt_stack] == name then dt_stack[#dt_stack] = nil end
end

function Profiler.enabled()
  return Storage.ns("prof").enabled
end

--- fine : true (portées fines), false (éteintes), "detail" (fines + détail par tick, lot PERF3), nil (inchangé).
function Profiler.set_enabled(on, tick, fine)
  local p = Storage.ns("prof")
  p.enabled = on
  p.since = tick
  -- Lot PERF : portées FINES (par état du cerveau des PNJ, par sous-étape de l'ouvrier) seulement sur demande : elles
  -- ajoutent une dizaine de mesures par pensée de PNJ, ce qui fausserait une mesure K10 de référence (ia1-scale allume le
  -- profileur ORDINAIRE). fine = nil garde le réglage précédent.
  if fine == "detail" then
    p.fine, p.detail = nil, true
  elseif fine ~= nil then
    p.fine = fine and true or nil
    p.detail = nil
  end
  refresh(p)
  timers = {}
  counts = {}
  dt_tick = -1
  dt_names, dt_acc, dt_mother, dt_run, dt_stack = {}, {}, {}, {}, {}
end

function Profiler.fine()
  return fine_on
end

--- Mesures fines (lot PERF) : rien quand le profileur ou le mode fin est éteint (un test d'une variable locale).
function Profiler.fstart(name)
  if not fine_on then return end
  local t = timers[name]
  if not t then
    t = game.create_profiler(true)
    timers[name] = t
  end
  t.restart()
  if detail_on then dt_open(name) end
end
function Profiler.fstop(name)
  local t = timers[name]
  if t then t.stop() end
  if detail_on then dt_close(name) end
end

-- Lot PERF (correction après revue) : portée attribuée APRÈS COUP selon son issue (porte acceptée ou refusée, prise de
-- tâche suivie d'un départ ou d'un refus), avec le NOMBRE de passages. fmark(slot) lance un chronomètre de travail ;
-- fcredit(slot, nom) l'arrête, l'ajoute à la portée « nom » et compte un passage. Mode fin seulement ; chronomètres et
-- comptes en tables LOCALES (jamais dans global, jamais lus par une décision).
function Profiler.fmark(slot)
  if not fine_on then return end
  local m = marks[slot]
  if m then m.reset() else marks[slot] = game.create_profiler() end
end
function Profiler.fcredit(slot, name)
  if not fine_on then return end
  local m = marks[slot]
  if not m then return end
  m.stop()
  local t = timers[name]
  if not t then
    t = game.create_profiler(true)
    timers[name] = t
  end
  t.add(m)
  counts[name] = (counts[name] or 0) + 1
  if detail_on then
    if game.tick ~= dt_tick then
      dt_flush()
      dt_tick = game.tick
    end
    local a = dt_acc[name]
    if not a then
      a = game.create_profiler(true)
      dt_acc[name] = a
      dt_names[#dt_names + 1] = name
      dt_mother[name] = dt_stack[#dt_stack] or "-"
    end
    a.add(m)
  end
end

function Profiler.start(name)
  local p = Storage.ns("prof")
  refresh(p)
  if not p.enabled then return end
  local t = timers[name]
  if not t then
    t = game.create_profiler(true)
    timers[name] = t
  end
  t.restart()
  if detail_on then dt_open(name) end
end

function Profiler.stop(name)
  local t = timers[name]
  if t then t.stop() end
  if detail_on then dt_close(name) end
end

-- Retourne une liste de LocalisedString (une par sous-système), triée par nom.
function Profiler.report(tick)
  local p = Storage.ns("prof")
  local lines = {}
  if not p.enabled then return lines, 0 end
  local window = math.max(1, tick - p.since)
  local names = {}
  for name in pairs(timers) do names[#names + 1] = name end
  table.sort(names)
  for i = 1, #names do
    local name = names[i]
    local avg = game.create_profiler(true)
    avg.add(timers[name])
    avg.divide(window)
    if counts[name] then
      lines[#lines + 1] = { "", "  ", name, " | total ", timers[name], " | moyenne/tick ", avg, " | passages ", tostring(counts[name]) }
    else
      lines[#lines + 1] = { "", "  ", name, " | total ", timers[name], " | moyenne/tick ", avg }
    end
  end
  return lines, window
end

return Profiler
