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

-- Lot X10-S0 : le profileur est requis par une dizaine de modules depuis les portées fines ; les bancs hors jeu qui remplacent
-- le stockage par une doublure réduite à ns() (adopte, reparation, reconstruction_exec, x10_s5) chargent ces modules sans
-- declare(). En jeu, declare existe toujours ; sans lui, Storage.ns("prof") de la doublure rend une table vide : mesure éteinte.
if Storage.declare then
  Storage.declare("prof", function()
    return { enabled = false, since = 0 }
  end)
end

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
-- Lot X10-S0, fait F403 (7/11) : toutes les tables du détail sont des CHAMPS d'une seule table locale, jamais des locaux du module
-- réaffectés : une table neuve rangée à chaque tick dans une upvalue fermée bloque le marquage du ramasse-miettes de Lua 5.2
-- (fo-logs/2026-11-07_X10/M8_CRITERES.md §3 bis : 9 cycles contre 21, tas de 516 Mo contre 57).
--   DT.names : portées vues dans le tick, dans l'ordre de première fin ; DT.acc : [nom] = LuaProfiler accumulé dans le tick ;
--   DT.mother : [nom] = portée mère à sa première ouverture dans le tick ("-" : premier niveau) ; DT.run : [nom] = chronomètre de
--   l'ouverture en cours ; DT.stack : portées ouvertes (noms), la plus récente en haut.
--   DT.cnt_names, DT.cnt : COMPTEURS du tick (Profiler.fcount, détail seulement), écrits à la fin de la ligne [FO-PERF3-T] sous la
--   forme « #nom=n » (pas une portée : perf3.py ne les lit pas comme telles).
--   DT.live : portées OUVERTES et pas encore fermées dans le tick. Une fermeture sans ouverture (build.lua ferme les quatre parties
--   du plan après un retour anticipé de plan_project, ouvertes ou non) ajoutait UNE SECONDE FOIS la durée de la dernière ouverture
--   fermée du même tick : compte double au détail. Elle ne compte plus rien.
local DT = { names = {}, acc = {}, mother = {}, run = {}, stack = {}, cnt_names = {}, cnt = {}, live = {} }
local function dt_reset()
  DT.names, DT.acc, DT.mother, DT.run, DT.stack = {}, {}, {}, {}, {}
  DT.cnt_names, DT.cnt, DT.live = {}, {}, {}
end

local function refresh(p)
  detail_on = (p.enabled and p.detail == true) or false
  fine_on = (p.enabled and (p.fine == true or p.detail == true)) or false
end

local function dt_flush()
  local n = #DT.names
  local nc = #DT.cnt_names
  if n > 0 or nc > 0 then
    -- Une LocalisedString porte au plus 20 paramètres : paquets de 9 portées (18 paramètres), sous une table mère. Lot X10-S0 : plus de
    -- 17 paquets (portées fines par gestionnaire, par état...) : les paquets sont regroupés par 19 sous un niveau de plus (même texte).
    local items = {}
    local chunk = { "" }
    for i = 1, n do
      local name = DT.names[i]
      chunk[#chunk + 1] = " " .. name .. "<" .. DT.mother[name] .. " "
      chunk[#chunk + 1] = DT.acc[name]
      if #chunk >= 19 then
        items[#items + 1] = chunk
        chunk = { "" }
      end
    end
    if #chunk > 1 then items[#items + 1] = chunk end
    if nc > 0 then
      local parts = {}
      for i = 1, nc do parts[i] = " #" .. DT.cnt_names[i] .. "=" .. string.format("%d", DT.cnt[DT.cnt_names[i]]) end
      items[#items + 1] = table.concat(parts)
    end
    local out = { "", "[FO-PERF3-T] ", tostring(dt_tick) }
    if #items <= 17 then
      for i = 1, #items do out[#out + 1] = items[i] end
    else
      local sup = { "" }
      for i = 1, #items do
        sup[#sup + 1] = items[i]
        if #sup >= 20 then
          out[#out + 1] = sup
          sup = { "" }
        end
      end
      if #sup > 1 then out[#out + 1] = sup end
    end
    log(out)
  end
  dt_reset()
end

local function dt_open(name)
  local tick = game.tick
  if tick ~= dt_tick then
    dt_flush()
    dt_tick = tick
  end
  if not DT.mother[name] then DT.mother[name] = DT.stack[#DT.stack] or "-" end
  DT.stack[#DT.stack + 1] = name
  local m = DT.run[name]
  if m then m.reset() else DT.run[name] = game.create_profiler() end
  DT.live[name] = true
end

local function dt_close(name)
  local m = DT.run[name]
  if not (m and DT.live[name]) then return end
  DT.live[name] = nil
  m.stop()
  local a = DT.acc[name]
  if not a then
    a = game.create_profiler(true)
    DT.acc[name] = a
    DT.names[#DT.names + 1] = name
  end
  a.add(m)
  if DT.stack[#DT.stack] == name then DT.stack[#DT.stack] = nil end
end

function Profiler.enabled()
  return Storage.ns("prof").enabled
end

--- Lot PERF3 : le détail par tick est-il allumé (bancs seulement) ? Copie locale, comme Profiler.fine().
function Profiler.detail()
  return detail_on
end

--- Lot PERF3 (bancs seulement, détail allumé) : une ligne « [FO-PERF3-DUMP] <tick> <étiquette> <table Lua> » : les ENTRÉES d'une
--- règle pure coûteuse (ex. la spec du plan du champ), rejouées hors jeu (tools/autotest/perf3_rejeu.lua) pour la mesurer et prouver
--- qu'une version plus rapide rend le même résultat. Clés triées (nombres puis chaînes), aucune fonction ; rien hors détail.
local function ser(v, out)
  local t = type(v)
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then out[#out + 1] = (v ~= v) and "0/0" or (v > 0 and "math.huge" or "-math.huge")
    elseif v == math.floor(v) and math.abs(v) < 2 ^ 53 then out[#out + 1] = string.format("%d", v)
    else out[#out + 1] = string.format("%.17g", v) end
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "boolean" then out[#out + 1] = v and "true" or "false"
  elseif t == "table" then
    local nk, sk = {}, {}
    for k in pairs(v) do
      if type(k) == "number" then nk[#nk + 1] = k elseif type(k) == "string" then sk[#sk + 1] = k end
    end
    table.sort(nk)
    table.sort(sk)
    out[#out + 1] = "{"
    for _, k in ipairs(nk) do
      out[#out + 1] = "["; ser(k, out); out[#out + 1] = "]="; ser(v[k], out); out[#out + 1] = ","
    end
    for _, k in ipairs(sk) do
      out[#out + 1] = "["; ser(k, out); out[#out + 1] = "]="; ser(v[k], out); out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  else
    out[#out + 1] = "nil"
  end
end
Profiler.ser = function(v) local out = {}; ser(v, out); return table.concat(out) end

function Profiler.dump(label, value)
  if not detail_on then return end
  log("[FO-PERF3-DUMP] " .. tostring(game.tick) .. " " .. tostring(label) .. " " .. Profiler.ser(value))
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
  dt_reset()
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

--- Lot X10-S0 : portée fine autour d'UN appel, au milieu d'une expression (champ d'un constructeur de table) : rend la PREMIÈRE
--- valeur de fn(...), comme le constructeur la prendrait. Mode fin éteint : l'appel tel quel (une fonction de plus sur la pile).
function Profiler.fwrap(name, fn, ...)
  if not fine_on then return (fn(...)) end
  Profiler.fstart(name)
  local r = fn(...)
  Profiler.fstop(name)
  return r
end

--- Lot X10-S0 : compteur du tick (détail seulement) : `n` ajouté à « nom », écrit à la fin de la ligne [FO-PERF3-T] du tick
--- (« #nom=n »). Mesure seulement, jamais lu par une décision ; un test sinon.
function Profiler.fcount(name, n)
  if not detail_on then return end
  local tick = game.tick
  if tick ~= dt_tick then
    dt_flush()
    dt_tick = tick
  end
  local c = DT.cnt[name]
  if not c then
    DT.cnt_names[#DT.cnt_names + 1] = name
    c = 0
  end
  DT.cnt[name] = c + (n or 1)
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
    local a = DT.acc[name]
    if not a then
      a = game.create_profiler(true)
      DT.acc[name] = a
      DT.names[#DT.names + 1] = name
      DT.mother[name] = DT.stack[#DT.stack] or "-"
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
