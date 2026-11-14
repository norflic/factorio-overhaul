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

-- Lot MORTS (7/11, fo-logs\2026-11-07_MORTS\CRITERES.md) : les abonnés à on_entity_died ont une liste à part, avec leur INTÉRÊT
-- déclaré (Events.on_died). Mesuré par design-attaques : une mort appelait les 23 abonnés du mod, environ 80 µs ; chacun relisait
-- l'entité. L'aiguillage lit type et force UNE fois et n'appelle que les abonnés concernés, dans l'ordre d'enregistrement.
-- Un abonné par Events.on(on_entity_died) n'a rien déclaré : il reçoit TOUTES les morts (rien n'est filtré par erreur).
-- { { fn, types = { [type] = true } | nil (tous), noms = { nom } | nil, ennemi = true | false | nil } }, ordre d'enregistrement
local died = {}
Events.MORTS_TRIES = true -- false (bancs) : chaque mort appelle tous les abonnés, comme avant ce lot

--- Abonné à on_entity_died avec son intérêt :
---   `interet.types` : liste de types du moteur (nil : tous) ;
---   `interet.noms` : liste de noms d'entités, dont les TYPES s'ajoutent à `types` (lus aux prototypes à la première mort : ils sont fixés
---     pour la session ; un nom sans prototype n'ajoute rien) ;
---   `interet.ennemi` : true, force « enemy » seulement ; false, jamais la force « enemy » ; nil, toutes.
--- Hors de son intérêt, l'abonné n'est pas appelé : il doit n'y rien faire (preuve : tests/morts_test.lua, P1).
function Events.on_died(fn, interet)
  guard("on_died")
  interet = interet or {}
  local d = { fn = fn, noms = interet.noms, ennemi = interet.ennemi }
  if interet.types or interet.noms then
    d.types = {}
    for _, t in ipairs(interet.types or {}) do d.types[t] = true end
  end
  died[#died + 1] = d
end

-- EFFONDREMENT (parade du kit offert, 7/11) : on_post_entity_died est FILTRÉ AU MOTEUR (type « character ») par script/team/worker.lua,
-- à on_init et on_load (script.set_event_filter). Un nouvel abonné Events.on(on_post_entity_died) ne recevrait donc QUE les morts de
-- personnages : élargir le filtre de worker.lua (Worker.KIT_POST_FILTER) avant de s'abonner pour d'autres types.
function Events.on(event_id, fn)
  guard("on")
  assert(event_id ~= nil, "Events.on : event_id nil")
  if event_id == defines.events.on_entity_died then
    died[#died + 1] = { fn = fn } -- rien de déclaré : toutes les morts
    return
  end
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

-- Lot X10-S0 (7/11) : en mode FIN du profileur seulement, une sous-portée par gestionnaire (« <portée>@<fichier>:<ligne> »), pour
-- attribuer le temps d'un événement à plusieurs abonnés (nth:30 : une dizaine ; event:on_tick : six). Noms calculés une fois
-- (debug.getinfo), gardés en table LOCALE ; mesure seulement, jamais lus par une décision. Mode fin éteint : la boucle d'avant.
local function handler_names(list, scope)
  local out = {}
  for i = 1, #list do
    local info = debug.getinfo(list[i], "S")
    local src = info and info.short_src or "?"
    src = src:gsub("\\", "/"):gsub("^.*/script/", ""):gsub("^.*__/", "")
    out[i] = scope .. "@" .. src .. ":" .. tostring(info and info.linedefined or i)
  end
  return out
end

-- Lot S51 (14/11) : cumul TOUJOURS allumé par gestionnaire (gels de 30 s en x5 que [FO-PERF-PIC] ne voit pas). Un LuaProfiler de
-- tour (restart/stop autour de l'appel) et un LuaProfiler cumulé (add) par gestionnaire, créés au premier appel, en table LOCALE :
-- mesure seulement, jamais dans `global`, jamais lue par une décision. Toutes les CUMUL_PERIODE ticks : une ligne
-- « [FO-PERF-CUMUL] <clé> appels=N <durée> » par gestionnaire appelé dans la période, puis remise à zéro.
-- Coût mesuré hors jeu (tests/s51_profil_test.lua) : 3 appels d'API par gestionnaire et par appel.
Events.CUMUL_PERIODE = 3600
local cumuls = {}       -- { { cle, tour, cumul, appels } }, ordre de création (premier appel)
local cumul_next = nil  -- tick de la prochaine écriture

local function handler_key(fn, scope, i)
  local info = debug and debug.getinfo and debug.getinfo(fn, "S")
  if not info then return scope .. "#" .. i end
  local src = tostring(info.short_src or "?")
  src = src:gsub("\\", "/"):gsub("^.*/script/", ""):gsub("^.*__/", "")
  return scope .. "@" .. src .. ":" .. tostring(info.linedefined or i)
end

local function cumul_new(cle)
  local c = { cle = cle, tour = game.create_profiler(true), cumul = game.create_profiler(true), appels = 0 }
  cumuls[#cumuls + 1] = c
  return c
end

--- Écrit les cumuls de la période (gestionnaires appelés seulement) et les remet à zéro.
function Events.cumul_flush()
  for i = 1, #cumuls do
    local c = cumuls[i]
    if c.appels > 0 then
      log({ "", "[FO-PERF-CUMUL] " .. c.cle .. " appels=" .. c.appels .. " ", c.cumul })
      c.cumul.reset(); c.cumul.stop()
      c.appels = 0
    end
  end
end

local function cumul_tick(t)
  if not t then return end
  if not cumul_next then cumul_next = t + Events.CUMUL_PERIODE return end
  if t >= cumul_next then
    Events.cumul_flush()
    cumul_next = t + Events.CUMUL_PERIODE
  end
end

local function dispatcher(list, scope)
  local n = #list
  local sub = nil
  local keys = {}
  for i = 1, n do keys[i] = handler_key(list[i], scope, i) end
  local cs = {}
  return function(e)
    cumul_tick(e and e.tick)
    Profiler.start(scope)
    local fine = n > 1 and Profiler.fine()
    if fine then sub = sub or handler_names(list, scope) end
    for i = 1, n do
      local c = cs[i]
      if not c then c = cumul_new(keys[i]); cs[i] = c end
      if fine then Profiler.fstart(sub[i]) end
      local tour = c.tour
      tour.restart()
      list[i](e)
      tour.stop()
      c.cumul.add(tour)
      c.appels = c.appels + 1
      if fine then Profiler.fstop(sub[i]) end
    end
    Profiler.stop(scope)
  end
end

--- Bancs hors jeu : les cumuls (clé, appels).
function Events.cumul_list() return cumuls end

--- Lot MORTS : types des noms déclarés, lus une fois aux prototypes (pendant un événement : `game` existe).
local function resolve_names(d)
  if not d.noms or d.noms_lus then return end
  local protos = game.entity_prototypes
  for _, n in ipairs(d.noms) do
    local p = protos[n]
    if p then d.types[p.type] = true end
  end
  d.noms_lus = true
end

--- Lot MORTS : abonnés d'une clé (type, force « enemy » ou non), dans l'ordre d'enregistrement.
local function died_select(etype, enemy)
  local out = {}
  for i = 1, #died do
    local d = died[i]
    resolve_names(d)
    if (d.types == nil or d.types[etype]) and (d.ennemi == nil or d.ennemi == enemy) then out[#out + 1] = d.fn end
  end
  return out
end

-- Listes par clé, gardées en table LOCALE : elles ne dépendent que des intérêts déclarés (du code) et des prototypes, donc elles sont
-- les mêmes sur tous les clients et après un chargement. Deux tables (force « enemy » ou non) : aucune chaîne fabriquée par mort.
local died_cache = { [true] = {}, [false] = {} }

--- Abonnés appelés pour une mort de ce type et de cette force (« enemy » ou non), dans l'ordre d'enregistrement. Lu par les bancs.
function Events.died_for(etype, enemy)
  local by = died_cache[enemy and true or false]
  local list = by[etype]
  if not list then
    list = died_select(etype, enemy and true or false)
    by[etype] = list
  end
  return list
end

--- Bancs hors jeu : la liste des abonnés à on_entity_died (fn, types, noms, ennemi), dans l'ordre d'enregistrement.
function Events.died_list() return died end

--- Lot MORTS : gestionnaire de on_entity_died. Entité absente ou invalide, ou aiguillage éteint : tous les abonnés, comme avant ce lot.
local function died_dispatcher(scope)
  local all = {}
  for i = 1, #died do all[i] = died[i].fn end
  return function(e)
    Profiler.start(scope)
    local list = all
    local ent = e.entity
    if Events.MORTS_TRIES and ent and ent.valid then list = Events.died_for(ent.type, ent.force.name == "enemy") end
    for i = 1, #list do list[i](e) end
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
  if #died > 0 then
    local id = defines.events.on_entity_died
    script.on_event(id, died_dispatcher("event:" .. tostring(names[id] or id)))
  end
  for i = 1, #nth_order do
    local n = nth_order[i]
    script.on_nth_tick(n, dispatcher(nth_handlers[n], "nth:" .. n))
  end
end

return Events
