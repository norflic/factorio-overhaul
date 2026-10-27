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
-- Lot PERF : copie LOCALE du mode fin (lue à chaque mesure fine, une vingtaine par pensée de PNJ : sans elle, chaque
-- appel relisait le stockage). Elle ne sert qu'à mesurer (jamais à décider) ; recopiée de global par set_enabled et par
-- chaque mesure ordinaire (Profiler.start, plusieurs fois par tick) : juste dès le premier tick après un chargement.
local fine_on = false

function Profiler.enabled()
  return Storage.ns("prof").enabled
end

function Profiler.set_enabled(on, tick, fine)
  local p = Storage.ns("prof")
  p.enabled = on
  p.since = tick
  -- Lot PERF : portées FINES (par état du cerveau des PNJ, par sous-étape de l'ouvrier) seulement sur demande : elles
  -- ajoutent une dizaine de mesures par pensée de PNJ, ce qui fausserait une mesure K10 de référence (ia1-scale allume le
  -- profileur ORDINAIRE). fine = nil garde le réglage précédent.
  if fine ~= nil then p.fine = fine and true or nil end
  fine_on = (p.enabled and p.fine == true) or false
  timers = {}
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
end
function Profiler.fstop(name)
  local t = timers[name]
  if t then t.stop() end
end

function Profiler.start(name)
  local p = Storage.ns("prof")
  fine_on = (p.enabled and p.fine == true) or false
  if not p.enabled then return end
  local t = timers[name]
  if not t then
    t = game.create_profiler(true)
    timers[name] = t
  end
  t.restart()
end

function Profiler.stop(name)
  local t = timers[name]
  if t then t.stop() end
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
    lines[#lines + 1] = { "", "  ", name, " | total ", timers[name], " | moyenne/tick ", avg }
  end
  return lines, window
end

return Profiler
