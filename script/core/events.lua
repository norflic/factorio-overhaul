--[[
  Bus d'événements multi-abonnés.

  Factorio n'autorise qu'UN handler par événement et par mod (script.on_event écrase le précédent).
  Ce module collecte les abonnements de tous les modules au chargement, puis les lie en une seule fois
  via Events.bind() (appelé à la fin de control.lua).

  Contraintes :
  - Les abonnements se font au niveau fichier (au require), jamais dans un handler : ainsi on_init et
    on_load produisent exactement le même câblage sur tous les clients.
  - L'ordre d'appel des abonnés = l'ordre des require dans control.lua.
]]

local Events = {}

local handlers = {}      -- [event_id] = { fn, ... }
local nth_handlers = {}  -- [n] = { fn, ... }
local nth_order = {}     -- n dans l'ordre d'enregistrement
local event_order = {}   -- event_id dans l'ordre d'enregistrement
local init_fns, load_fns, config_fns = {}, {}, {}
local bound = false

local function guard(what)
  if bound then error("Events." .. what .. " appelé après Events.bind() : abonnement dynamique interdit") end
end

function Events.on(event_id, fn)
  guard("on")
  assert(event_id ~= nil, "Events.on : event_id nil")
  local list = handlers[event_id]
  if not list then
    list = {}
    handlers[event_id] = list
    event_order[#event_order + 1] = event_id
  end
  list[#list + 1] = fn
end

function Events.on_nth_tick(n, fn)
  guard("on_nth_tick")
  local list = nth_handlers[n]
  if not list then
    list = {}
    nth_handlers[n] = list
    nth_order[#nth_order + 1] = n
  end
  list[#list + 1] = fn
end

function Events.on_init(fn) guard("on_init"); init_fns[#init_fns + 1] = fn end
function Events.on_load(fn) guard("on_load"); load_fns[#load_fns + 1] = fn end
function Events.on_configuration_changed(fn) guard("on_configuration_changed"); config_fns[#config_fns + 1] = fn end

-- Chaque handler lié est mesuré par le profileur (portée "event:<nom>" / "nth:<n>") quand il est actif :
-- c'est ainsi que l'on attribue les pics de temps script en moteur réel. Coût hors mesure : un test.
local Profiler = nil

local function dispatcher(list, scope)
  local n = #list
  return function(e)
    Profiler.start(scope)
    for i = 1, n do list[i](e) end
    Profiler.stop(scope)
  end
end

function Events.bind()
  guard("bind")
  bound = true
  script.on_init(function()
    for i = 1, #init_fns do init_fns[i]() end
  end)
  script.on_load(function()
    for i = 1, #load_fns do load_fns[i]() end
  end)
  script.on_configuration_changed(function(data)
    for i = 1, #config_fns do config_fns[i](data) end
  end)
  Profiler = require("script.core.profiler") -- chargé à la liaison : pas de dépendance circulaire
  local names = {}
  for name, id in pairs(defines.events) do names[id] = name end
  for i = 1, #event_order do
    local id = event_order[i]
    script.on_event(id, dispatcher(handlers[id], "event:" .. tostring(names[id] or id)))
  end
  for i = 1, #nth_order do
    local n = nth_order[i]
    script.on_nth_tick(n, dispatcher(nth_handlers[n], "nth:" .. n))
  end
end

return Events
