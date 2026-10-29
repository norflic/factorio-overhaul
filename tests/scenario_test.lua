--[[
  Tests hors jeu du journal d'époque (piste SCENARIOS, 30/10).
  Usage, depuis la racine du mod :   lua5.2 tests/scenario_test.lua

  1. Règle pure (shared/scenario/journal.lua) : objectifs des 15 époques dérivés des données (coût du centre = L.cost,
     plafond = L.building_cap, gisements filtrés par les prototypes, cartographie X0, Porte à l'époque 15 seulement),
     annonce sans répétition (J.decide), choix de /fo-journal (J.pick).
  2. Traductions : locale/fr/scenarios.cfg et locale/en/scenarios.cfg ont les mêmes clés ; Codex I à XIV identiques
     au scénario approuvé (shared/content/epochs.lua) ; actes identiques à X.acts ; chaque clé citée par le script
     existe dans les deux langues.
  3. Le module de jeu (script/scenario/journal.lua) sur un moteur FACTICE minimal : partie neuve (intro, épave, époque 1
     à la réparation, saut d'époques, centre détruit puis reconstruit, aucune annonce répétée), commande /fo-journal,
     boutons, factions ignorées, sauvegarde 0.6.18 alignée sans annonce.
  4. Règles du mod : `global` jamais nommé, `require` seulement en tête de fichier, aucun `pairs` sans tri.
  5. Mutants : chaque contrôle clé refuse une version fausse.
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local L = require("shared.levels.config")
local X = require("shared.content.epochs")
local W = require("shared.content.world")
local J = require("shared.scenario.journal")
local CC = L.by_key.command

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

---------------------------------------------------------------------------------------------------
section("1. Règle pure : objectifs des 15 époques")
---------------------------------------------------------------------------------------------------
local function kinds_of(list)
  local t = {}
  for _, o in ipairs(list) do t[#t + 1] = o.kind end
  return table.concat(t, ",")
end

local function objectives_ok(Jm)
  local ok = true
  for k = 1, 15 do
    local list = Jm.objectives(k)
    local first = list[1]
    if k < 15 then
      if not (first.kind == "centre" and first.target == k + 1) then ok = false end
      local cost = L.cost(CC, k + 1)
      if #first.cost ~= #cost then ok = false end
      for i, c in ipairs(cost) do
        if not (first.cost[i] and first.cost[i][1] == c[1] and first.cost[i][2] == c[2]) then ok = false end
      end
    else
      for _, o in ipairs(list) do if o.kind == "centre" then ok = false end end
    end
    local gate, threat, cap = 0, 0, nil
    for _, o in ipairs(list) do
      if o.kind == "gate" then gate = gate + 1 end
      if o.kind == "threat" then threat = threat + 1 end
      if o.kind == "cap" then cap = o.level end
    end
    if gate ~= (k == 15 and 1 or 0) then ok = false end
    local def = 0
    for _, o in ipairs(list) do if o.kind == "defense" then def = def + 1; if o.nests ~= X.milestone_defense_nests(k) then ok = false end end end
    if def ~= 1 then ok = false end
    if threat ~= 1 or list[#list].kind ~= "threat" then ok = false end
    if cap ~= math.min(30, 2 * k) then ok = false end
  end
  return ok
end
check(objectives_ok(J), "centre (coût exact L.cost), plafond 2k, Porte à l'époque 15 seulement, menace en dernier")

do
  local all = function() return true end
  local none = function() return false end
  check(kinds_of(J.objectives(1, none)) == "centre,cap,chart,defense,threat", "époque 1 sans ressource : " .. kinds_of(J.objectives(1, none)))
  check(kinds_of(J.objectives(15, none)) == "cap,defense,gate,threat", "époque 15 : " .. kinds_of(J.objectives(15, none)))
  -- Gisements : jalon X0 puis garanties de world.lua, filtrés par le prédicat.
  local c5 = J.resource_candidates(5)
  check(c5[1] == "fo-fumarole" and c5[2] == "fo-tungsten-ore" and #c5 == 2, "époque 5 : fumerolle (X0) puis tungstène (garanti) : " .. table.concat(c5, ","))
  local c11 = J.resource_candidates(11)
  check(#c11 == 2 and c11[1] == "fo-ilmenite" and c11[2] == "fo-brine", "époque 11 : ilménite (sans doublon) puis saumure : " .. table.concat(c11, ","))
  local present = { ["fo-tungsten-ore"] = true }
  local r5 = {}
  for _, o in ipairs(J.objectives(5, function(n) return present[n] end)) do
    if o.kind == "resource" then r5[#r5 + 1] = o.name end
  end
  check(#r5 == 1 and r5[1] == "fo-tungsten-ore", "prototype absent (fumerolle) filtré : " .. table.concat(r5, ","))
  check(J.resource_candidates(4)[1] == "crude-oil", "époque 4 : pétrole brut")
  -- Chaque ressource garantie de world.lua est citée par l'époque qu'elle porte.
  check(#W.resource_order >= 5, "ressources garanties relevées dans W.resource_order")
  for _, key in ipairs(W.resource_order) do
    local r = W.resources[key]
    local found = false
    for _, n in ipairs(J.resource_candidates(r.epoch)) do if n == r.resource then found = true end end
    check(found, "ressource garantie " .. r.resource .. " citée à l'époque " .. r.epoch)
  end
  local charts = 0
  for k = 1, 15 do
    local c = J.chart_target(k)
    if c then charts = charts + 1; check(c == 64 * k, "cartographie de l'époque " .. k .. " = 64 × k (" .. c .. ")") end
    for _, o in ipairs(J.objectives(k, all)) do
      if o.kind == "chart" then check(o.chunks == c, "objectif de cartographie de l'époque " .. k) end
    end
  end
  check(charts >= 4, "au moins 4 époques ont une cible de cartographie (" .. charts .. ")")
  for k = 1, 15 do
    check(J.act_of(k) ~= nil, "acte de l'époque " .. k)
    check(J.epoch_key(k) == L.epochs[k].key, "clé de nom de l'époque " .. k)
  end
  check(J.act_of(1) == 1 and J.act_of(5) == 2 and J.act_of(10) == 3 and J.act_of(15) == 4, "actes 1 à 4 aux bornes")
  check(not pcall(J.objectives, 0) and not pcall(J.objectives, 16), "époque hors bornes refusée")
end

section("1 ter. Recherches de l'époque (classement des niveaux)")
do
  local function tech(name, packs, unlocks, researched)
    local ing, eff = {}, {}
    for _, p in ipairs(packs) do ing[#ing + 1] = { name = p, amount = 1 } end
    for _, r in ipairs(unlocks or {}) do eff[#eff + 1] = { type = "unlock-recipe", recipe = r } end
    return { name = name, effects = eff, unit = { ingredients = ing }, researched = researched }
  end
  local red = { "automation-science-pack" }
  local green = { "automation-science-pack", "logistic-science-pack" }
  local list = { tech("t-a", red, nil, true), tech("t-b", red, nil, false), tech("t-c", red, nil, false),
    tech("t-d", green, nil, true) }
  for _, t in ipairs(list) do check(J.tech_epoch(t) == L.vanilla_tech_epoch(t), "J.tech_epoch = règle des niveaux (" .. t.name .. ")") end
  local e1 = J.tech_epoch(list[1])
  local done, target, total = J.research_progress(list, e1)
  check(total == 3 and done == 1 and target == math.ceil(X.MILESTONE_RESEARCH_SHARE * 3), "progrès des recherches : 1 / " .. target .. " sur 3")
  local with = J.objectives(e1, nil, list)
  local r
  for _, o in ipairs(with) do if o.kind == "research" then r = o end end
  check(r and r.done == 1 and r.total == 3, "objectif de recherche présent quand l'époque a des technologies")
  local none = J.objectives(15, nil, list)
  local has = false
  for _, o in ipairs(none) do if o.kind == "research" then has = true end end
  check(not has, "aucun objectif de recherche pour une époque sans technologie")
  check(kinds_of(J.objectives(1, function() return false end)) == "centre,cap,chart,defense,threat", "sans liste de technologies : pas de recherche")
end

section("1 bis. Annonce et commande")
local function decide_ok(Jm)
  local ok = true
  local function eq(a, b, c, d) if a ~= b or c ~= d then ok = false end end
  local k, r = Jm.decide(nil, 0); eq(k, nil, r, 0)
  k, r = Jm.decide(0, 1); eq(k, 1, r, 1)
  k, r = Jm.decide(1, 1); eq(k, nil, r, 1)             -- jamais deux fois
  k, r = Jm.decide(1, 4); eq(k, 4, r, 4)               -- saut : la dernière seulement
  k, r = Jm.decide(4, 0); eq(k, nil, r, 4)             -- centre détruit : rien, la marque reste
  k, r = Jm.decide(4, 3); eq(k, nil, r, 4)
  k, r = Jm.decide(4, 5); eq(k, 5, r, 5)
  k, r = Jm.decide(15, 15); eq(k, nil, r, 15)
  k, r = Jm.decide(14, 99); eq(k, 15, r, 15)           -- borné à 15
  return ok
end
check(decide_ok(J), "J.decide : première fois, jamais deux fois, saut, centre perdu, borne")
do
  local function p(a, r) local k, why = J.pick(a, r); return tostring(k) .. "/" .. tostring(why) end
  check(p(nil, 0) == "nil/none" and p("", 0) == "nil/none", "commande sans époque atteinte : intro")
  check(p(nil, 6) == "6/nil" and p("  ", 6) == "6/nil", "commande sans argument : époque actuelle")
  check(p("3", 6) == "3/nil" and p(" 6 ", 6) == "6/nil", "commande avec une époque atteinte")
  check(p("7", 6) == "nil/not-reached", "époque pas encore atteinte refusée")
  check(p("0", 6) == "nil/invalid" and p("16", 15) == "nil/invalid" and p("abc", 6) == "nil/invalid" and p("2x", 6) == "nil/invalid",
    "argument invalide refusé")
end

---------------------------------------------------------------------------------------------------
section("2. Traductions")
---------------------------------------------------------------------------------------------------
local function parse_cfg(text)
  local t, section_name = {}, nil
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    line = line:gsub("\r$", "")
    local s = line:match("^%[(.+)%]$")
    if s then section_name = s
    elseif line ~= "" and not line:match("^[#;]") then
      local k, v = line:match("^([^=]+)=(.*)$")
      if k and section_name then t[section_name .. "." .. k] = v end
    end
  end
  return t
end
local FR = parse_cfg(read("locale/fr/scenarios.cfg"))
local EN = parse_cfg(read("locale/en/scenarios.cfg"))

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function parity_errors(fr, en)
  local errs = {}
  for _, k in ipairs(sorted_keys(fr)) do if en[k] == nil then errs[#errs + 1] = "EN manque " .. k end end
  for _, k in ipairs(sorted_keys(en)) do if fr[k] == nil then errs[#errs + 1] = "FR manque " .. k end end
  return errs
end
local pe = parity_errors(FR, EN)
check(#pe == 0, "mêmes clés en FR et en EN : " .. table.concat(pe, ", "))
check(#sorted_keys(FR) >= 50, "au moins 50 clés (" .. #sorted_keys(FR) .. ")")

for k = 1, 15 do
  for _, key in ipairs(J.keys_of(k)) do
    check(FR["fo-journal." .. key] and FR["fo-journal." .. key] ~= "", "FR : fo-journal." .. key)
    check(EN["fo-journal." .. key] and EN["fo-journal." .. key] ~= "", "EN : fo-journal." .. key)
  end
end
for k = 1, 14 do
  check(FR["fo-journal.codex-" .. k] == X.epochs[k].codex_fr, "Codex " .. k .. " FR identique au scénario approuvé")
  check(EN["fo-journal.codex-" .. k] == X.epochs[k].codex_en, "Codex " .. k .. " EN identique au scénario approuvé")
end
check(X.epochs[15].codex_fr == nil or FR["fo-journal.codex-15"] == X.epochs[15].codex_fr,
  "Codex XV : texte proposé tant que X0 n'en a pas, sinon celui de X0")
for _, a in ipairs(X.acts) do
  check(FR["fo-journal.act-" .. a.n] == a.fr and EN["fo-journal.act-" .. a.n] == a.en, "acte " .. a.n .. " identique à X.acts")
end
check(FR["fo-journal.intro"]:find(X.story.intro_fr, 1, true) == 1 and EN["fo-journal.intro"]:find(X.story.intro_en, 1, true) == 1,
  "intro : texte du scénario approuvé (X.story)")

-- Chaque clé citée par le script existe ; les paramètres __n__ concordent entre FR et EN.
local SRC = read("script/scenario/journal.lua")
local cited = {}
for key in SRC:gmatch('lk%("([%w%-]+)"') do if not key:match("%-$") then cited[key] = true end end
for key in SRC:gmatch('"fo%-journal%.([%w%-]+)"') do cited[key] = true end
local n_cited = 0
for _, key in ipairs(sorted_keys(cited)) do
  n_cited = n_cited + 1
  check(FR["fo-journal." .. key] ~= nil and EN["fo-journal." .. key] ~= nil, "clé citée par le script : fo-journal." .. key)
end
check(n_cited >= 15, "clés citées relevées dans le script (" .. n_cited .. ")")
for _, k in ipairs(sorted_keys(FR)) do
  local function params(s)
    local t = {}
    for n in (s or ""):gmatch("__(%d)__") do t[#t + 1] = n end
    table.sort(t)
    return table.concat(t, ",")
  end
  check(params(FR[k]) == params(EN[k]), "mêmes paramètres FR/EN : " .. k)
end
-- Les noms d'époque utilisés existent (section fo-epochs du lot V2).
local V2FR, V2EN = parse_cfg(read("locale/fr/v2.cfg")), parse_cfg(read("locale/en/v2.cfg"))
for k = 1, 15 do
  local key = "fo-epochs.name-" .. J.epoch_key(k)
  check(V2FR[key] and V2EN[key], "nom d'époque " .. key)
end

---------------------------------------------------------------------------------------------------
section("3. Module de jeu sur un moteur factice")
---------------------------------------------------------------------------------------------------
local Fake = {}

local function new_element(spec, parent)
  local el = { type = spec.type, name = spec.name, caption = spec.caption, tags = spec.tags, valid = true,
               style = {}, children = {}, parent = parent }
  function el.add(s)
    local c = new_element(s, el)
    el.children[#el.children + 1] = c
    if s.name then el[s.name] = c end
    return c
  end
  function el.destroy()
    el.valid = false
    if parent and el.name then parent[el.name] = nil end
  end
  return el
end

local function find_texts(el, out)
  out = out or {}
  if el.caption then out[#out + 1] = el.caption end
  for _, c in ipairs(el.children or {}) do find_texts(c, out) end
  return out
end

local function flat(ls)
  if type(ls) ~= "table" then return tostring(ls) end
  local parts = {}
  for _, v in ipairs(ls) do parts[#parts + 1] = flat(v) end
  return table.concat(parts, "|")
end

local function setup(opts)
  local handlers = { on = {}, nth = {}, init = {}, config = {} }
  local root = {}
  local namespaces = {}
  package.loaded["script.core.events"] = {
    on = function(id, fn) handlers.on[id] = handlers.on[id] or {}; table.insert(handlers.on[id], fn) end,
    on_nth_tick = function(n, fn) handlers.nth[n] = handlers.nth[n] or {}; table.insert(handlers.nth[n], fn) end,
    on_init = function(fn) table.insert(handlers.init, fn) end,
    on_configuration_changed = function(fn) table.insert(handlers.config, fn) end,
  }
  package.loaded["script.core.storage"] = {
    declare = function(name, init) namespaces[#namespaces + 1] = { name = name, init = init } end,
    ns = function(name) return root.fo and root.fo[name] end,
  }
  local cc_level = { player = 0 }
  local wreck = { player = false }
  local cc_entity = { valid = true, name = L.name(CC, 1),
    get_inventory = function() return { get_item_count = function(item) return item == "iron-plate" and 500 or 0 end } end }
  package.loaded["script.levels.levels"] = {
    cc = function(force) return (cc_level[force.name] or 0) > 0 and cc_entity or nil end,
    cc_level = function(force) return cc_level[force.name] or 0 end,
    is_wreck = function(force) return wreck[force.name] == true end,
    on_replaced = {},
  }
  package.loaded["script.scenario.journal"] = nil

  local logs, chat, game_chat, commands_t, remotes = {}, {}, {}, {}, {}
  local function make_player(index, force)
    local p = { index = index, valid = true, force = force, controller_type = 1, surface = Fake.surface,
      gui = { screen = new_element({ type = "screen" }) } }
    function p.print(m) chat[#chat + 1] = { index = index, msg = m } end
    function p.get_main_inventory() return { get_item_count = function() return 0 end } end
    return p
  end
  Fake.surface = { get_chunks = function()
    local i = 0
    return function() i = i + 1; if i <= 10 then return { x = i, y = 0 } end end
  end }
  local force = { name = "player", valid = true, players = {}, connected_players = {},
    technologies = { ["t-red"] = { enabled = true, upgrade = false, effects = {}, researched = true,
      research_unit_ingredients = { { type = "item", name = "automation-science-pack", amount = 1 } } } },
    is_chunk_charted = function(_, c) return c.x <= 7 end }
  local faction = { name = "fo-faction-scarlet", valid = true, players = {}, connected_players = {} }
  cc_level[faction.name] = 5
  local players = {}
  for i = 1, (opts.players or 1) do
    local p = make_player(i, force)
    players[i] = p
    force.players[#force.players + 1] = p
    force.connected_players[#force.connected_players + 1] = p
  end
  local protos = { ["crude-oil"] = { type = "resource", localised_name = "Crude oil" } }
  for _, key in ipairs(W.resource_order) do local r = W.resources[key]; protos[r.resource] = { type = "resource", localised_name = r.resource } end
  _G.defines = { events = { on_gui_click = "on_gui_click", on_entity_died = "on_entity_died" }, controllers = { character = 1, cutscene = 7 },
    inventory = { chest = 1 } }
  _G.game = {
    tick = 0,
    forces = { player = force, [faction.name] = faction },
    players = players, connected_players = players,
    get_player = function(i) return players[i] end,
    entity_prototypes = protos,
    item_prototypes = setmetatable({}, { __index = function() return {} end }),
    print = function(m) game_chat[#game_chat + 1] = m end,
  }
  _G.log = function(m) logs[#logs + 1] = m end
  _G.commands = { add_command = function(name, help, fn) commands_t[name] = fn end }
  _G.remote = { add_interface = function(name, t) remotes[name] = t end }

  require("script.scenario.journal")
  local env = { handlers = handlers, root = root, cc_level = cc_level, wreck = wreck, players = players, force = force,
    faction = faction, logs = logs, chat = chat, game_chat = game_chat, commands = commands_t, remotes = remotes,
    namespaces = namespaces }
  function env.create_namespaces()
    root.fo = root.fo or {}
    for _, ns in ipairs(namespaces) do if root.fo[ns.name] == nil then root.fo[ns.name] = ns.init() end end
  end
  function env.init() env.create_namespaces(); for _, f in ipairs(handlers.init) do f() end end
  function env.config_changed() env.create_namespaces(); for _, f in ipairs(handlers.config) do f() end end
  function env.poll() game.tick = game.tick + 120; for _, f in ipairs(handlers.nth[120] or {}) do f() end end
  function env.st() return root.fo.journal end
  function env.frame(i) return players[i or 1].gui.screen.fo_journal_frame end
  function env.click(i, el) for _, f in ipairs(handlers.on.on_gui_click or {}) do f({ element = el, player_index = i }) end end
  function env.cmd(i, param) commands_t["fo-journal"]({ player_index = i, parameter = param }) end
  return env
end

local function find_button(frame, name)
  local function walk(el)
    if el.name == name then return el end
    for _, c in ipairs(el.children or {}) do local r = walk(c); if r then return r end end
  end
  return walk(frame)
end

local function no_functions(v, seen)
  seen = seen or {}
  if type(v) == "function" then return false end
  if type(v) ~= "table" or seen[v] then return true end
  seen[v] = true
  for k, x in pairs(v) do if not no_functions(k, seen) or not no_functions(x, seen) then return false end end
  return true
end

do -- Partie neuve
  local env = setup({ players = 1 })
  check(env.handlers.nth[120] and #env.handlers.nth[120] == 1, "relevé périodique enregistré (120 ticks)")
  check(env.commands["fo-journal"] ~= nil and env.remotes["fo-journal"] ~= nil, "commande /fo-journal et interface distante")
  env.init()
  check(env.st().born == "init", "partie neuve : naissance notée")
  env.players[1].controller_type = 7 -- cinématique de freeplay
  env.wreck.player = true
  env.poll()
  check(env.frame() == nil and env.st().stats.intros == 0, "pas d'intro pendant la cinématique")
  env.players[1].controller_type = 1
  env.poll()
  local f = env.frame()
  check(f and flat(f.caption):find("intro%-title"), "intro montrée au retour en personnage")
  local texts = flat(find_texts(f))
  check(texts:find("intro%-repair") ~= nil, "intro : objectif « réparer l'épave » quand le centre est une épave")
  check(env.st().reached.player == 0 and env.st().stats.announced == 0, "épave : aucune époque annoncée")
  env.poll()
  check(env.st().stats.intros == 1, "intro jamais rejouée")
  -- Réparation : époque 1.
  env.wreck.player = false
  env.cc_level.player = 1
  env.poll()
  f = env.frame()
  check(env.st().reached.player == 1 and env.st().stats.announced == 1, "réparation : époque 1 annoncée")
  check(f and flat(f.caption):find("fo%-journal%.title|1|") ~= nil, "fenêtre du journal de l'époque 1 : " .. (f and flat(f.caption) or "aucune"))
  texts = flat(find_texts(f))
  check(texts:find("codex%-1") and texts:find("obj%-centre") and texts:find("obj%-cap") and texts:find("threat%-1"),
    "fenêtre : Codex, centre suivant, plafond, menace")
  check(texts:find("%[item=iron%-plate%] 310 / 310") ~= nil, "coût du centre 2 lu avec ce que contient le centre (fer 500 ≥ 310)")
  check(texts:find("obj%-chart|7|64") ~= nil, "cartographie : chunks comptés (7) et cible (64)")
  check(texts:find("obj%-research|1|1|1") ~= nil, "recherches de l'époque 1 lues sur la force : 1 / 1")
  check(#env.chat == 1 and flat(env.chat[1].msg):find("chat%-epoch|1|"), "ligne de chat à l'annonce")
  env.poll()
  check(env.st().stats.announced == 1, "époque 1 jamais annoncée deux fois")
  -- Passage du centre par le crochet Levels.on_replaced (saut à 3).
  env.cc_level.player = 3
  local hooks = package.loaded["script.levels.levels"].on_replaced
  check(#hooks == 1, "crochet Levels.on_replaced posé")
  hooks[1](42, { valid = true, name = L.name(CC, 3), force = env.force })
  check(env.st().reached.player == 3 and env.st().stats.announced == 2, "crochet : époque 3 annoncée tout de suite")
  hooks[1](43, { valid = true, name = L.name(L.by_key.gun, 5), force = env.force })
  check(env.st().stats.announced == 2, "crochet : un autre bâtiment ne change rien")
  env.poll()
  check(env.st().stats.announced == 2, "relevé après le crochet : rien de plus")
  -- Centre détruit puis reconstruit plus bas, puis au-dessus.
  env.cc_level.player = 0; env.poll()
  env.cc_level.player = 2; env.poll()
  check(env.st().reached.player == 3 and env.st().stats.announced == 2, "centre perdu puis reconstruit : rien de rejoué")
  env.cc_level.player = 4; env.poll()
  check(env.st().reached.player == 4 and env.st().stats.announced == 3, "époque 4 annoncée")
  check(env.st().base.player[4] == 0, "base des nids notée à l'annonce")
  -- Jalon de défense : nids détruits pendant l'époque 4 (base notée à l'annonce).
  local function die(type_, force) for _, fn in ipairs(env.handlers.on.on_entity_died or {}) do fn({ entity = { valid = true, type = type_ }, force = force }) end end
  die("unit-spawner", env.force); die("unit-spawner", env.force); die("unit", env.force); die("unit-spawner", env.faction); die("unit-spawner", nil)
  check(env.st().nests.player == 2 and env.st().nests[env.faction.name] == nil, "nids comptés pour la force du joueur seulement (2)")
  env.cmd(1, "4")
  check(flat(find_texts(env.frame())):find("obj%-defense|2|6") ~= nil, "jalon de défense de l'époque 4 : 2 / 6")
  env.cc_level.player = 5; env.poll()
  check(flat(find_texts(env.frame())):find("obj%-defense|0|7") ~= nil, "époque 5 : compteur repart de la base notée (0 / 7)")
  env.cmd(1, "4")
  check(flat(find_texts(env.frame())):find("obj%-defense|2|6") ~= nil, "époque 4 relue : 2 / 6 (total moins base, sans borne haute)")
  env.cc_level.player = 4
  -- Factions : jamais suivies.
  check(env.st().reached[env.faction.name] == nil, "faction (sans joueur) ignorée")
  -- Commande et boutons.
  env.cmd(1, nil)
  check(flat(env.frame().caption):find("title|5|") ~= nil, "/fo-journal : époque actuelle (5)")
  env.cmd(1, "2")
  check(flat(env.frame().caption):find("title|2|") ~= nil, "/fo-journal 2 : époque 2")
  local nchat = #env.chat
  env.cmd(1, "9")
  check(#env.chat == nchat + 1 and flat(env.chat[#env.chat].msg):find("command%-not%-reached"), "/fo-journal 9 : pas atteinte")
  env.cmd(1, "zz")
  check(flat(env.chat[#env.chat].msg):find("command%-invalid"), "/fo-journal zz : invalide")
  local nxt = find_button(env.frame(), "fo_journal_next")
  local prv = find_button(env.frame(), "fo_journal_prev")
  check(nxt and nxt.tags.epoch == 3 and prv and prv.tags.epoch == 1, "boutons précédent (1) et suivant (3) depuis l'époque 2")
  env.click(1, nxt)
  check(flat(env.frame().caption):find("title|3|") ~= nil, "bouton suivant : époque 3")
  env.cmd(1, "5")
  check(find_button(env.frame(), "fo_journal_next") == nil, "pas de bouton suivant à l'époque atteinte la plus haute")
  env.click(1, { valid = true, name = "fo_journal_next", tags = { epoch = 9 } })
  check(flat(env.frame().caption):find("title|5|") ~= nil, "bouton forgé vers une époque non atteinte : ignoré")
  env.click(1, find_button(env.frame(), "fo_journal_close"))
  check(env.frame() == nil, "bouton fermer")
  -- Interface distante.
  local s = env.remotes["fo-journal"].status("player")
  check(s.reached == 5 and s.announced == 4 and s.intros == 1 and s.born == "init" and s.nests == 2, "interface : status")
  local ob = env.remotes["fo-journal"].objectives(5)
  check(ob[1].kind == "centre" and ob[1].target == 6, "interface : objectifs de l'époque 5")
  local res = {}
  for _, o in ipairs(ob) do if o.kind == "resource" then res[#res + 1] = o.name end end
  check(table.concat(res, ",") == "fo-tungsten-ore", "interface : la fumerolle (absente du jeu) n'est pas proposée")
  check(env.remotes["fo-journal"].open(1, 0) == true and flat(env.frame().caption):find("intro%-title"), "interface : open 0 = intro")
  check(env.remotes["fo-journal"].open(1, 2) == true and flat(env.frame().caption):find("title|2|"), "interface : open 2")
  check(env.remotes["fo-journal"].open(1, 9) == false, "interface : open d'une époque non atteinte refusé")
  check(no_functions(env.st()), "stockage : aucune fonction (sérialisable)")
end

do -- Plusieurs joueurs : chacun reçoit sa fenêtre
  local env = setup({ players = 2 })
  env.init()
  env.cc_level.player = 2
  env.poll()
  check(env.frame(1) and env.frame(2), "deux joueurs connectés : une fenêtre chacun")
  check(env.st().stats.announced == 1 and #env.chat == 2, "une annonce, une ligne de chat par joueur")
end

do -- Sauvegarde 0.6.18 (pas d'espace « journal ») : alignement sans annonce
  local env = setup({ players = 1 })
  env.cc_level.player = 6
  env.config_changed()
  check(env.st().born == "migration" and env.st().reached.player == 6, "sauvegarde existante : alignée sur l'époque 6")
  check(env.st().stats.announced == 0 and env.frame() == nil, "aucune annonce ni fenêtre à la migration")
  check(env.st().intro[1] == true, "joueur existant : intro réputée lue")
  check(#env.game_chat == 1 and flat(env.game_chat[1]):find("migrated"), "une ligne de chat signale /fo-journal")
  env.poll()
  check(env.st().stats.announced == 0 and env.st().stats.intros == 0 and env.frame() == nil, "relevé suivant : rien de rejoué")
  env.cc_level.player = 7; env.poll()
  check(env.st().stats.announced == 1 and env.st().reached.player == 7, "époque suivante annoncée normalement")
  env.config_changed()
  check(#env.game_chat == 1 and env.st().stats.aligned == 1, "mise à jour suivante : pas de nouvel alignement")
end

---------------------------------------------------------------------------------------------------
section("4. Règles du mod (fichiers de la piste)")
---------------------------------------------------------------------------------------------------
local function rules_errors(path)
  local errs = {}
  local src = read(path)
  local n = 0
  for line in (src .. "\n"):gmatch("([^\n]*)\n") do
    n = n + 1
    local code = line:gsub("%-%-.*$", "")
    if code:find("%f[%w_]global%f[^%w_]") then errs[#errs + 1] = path .. ":" .. n .. " nomme global" end
    if code:find("require%s*%(") and not code:match("^local [%w_]+ = require%(") then
      errs[#errs + 1] = path .. ":" .. n .. " require hors de l'en-tête"
    end
  end
  -- Chaque boucle sur pairs remplit une liste triée ensuite (table.sort dans les 6 lignes).
  local lines = {}
  for line in (src .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
  for i, line in ipairs(lines) do
    local code = line:gsub("%-%-.*$", "")
    if code:find("in pairs%(") then
      local sorted = false
      for j = i, math.min(#lines, i + 6) do if lines[j]:find("table%.sort") then sorted = true end end
      if not sorted then errs[#errs + 1] = path .. ":" .. i .. " pairs sans tri" end
    end
  end
  return errs
end
for _, path in ipairs({ "shared/scenario/journal.lua", "script/scenario/journal.lua" }) do
  local e = rules_errors(path)
  check(#e == 0, "règles : " .. path .. " " .. table.concat(e, " ; "))
end
check(not read("shared/scenario/journal.lua"):find("game%."), "shared/scenario : Lua pur (aucun appel au moteur)")

---------------------------------------------------------------------------------------------------
section("5. Mutants")
---------------------------------------------------------------------------------------------------
do
  local M = {}
  for k, v in pairs(J) do M[k] = v end
  M.decide = function(reached, level) reached = reached or 0; if (level or 0) >= reached then return level, level end; return nil, reached end
  check(not decide_ok(M), "mutant : annonce répétée à époque égale, refusé")
  M.decide = function(reached, level) if (level or 0) > (reached or 0) then return level, level end; return nil, level or 0 end
  check(not decide_ok(M), "mutant : marque perdue quand le centre redescend, refusé")
  M.decide = J.decide
  local orig = M.objectives
  M.objectives = function(k, exists)
    local out = orig(k, exists)
    if k == 15 then table.insert(out, 1, { kind = "centre", target = 16, cost = {} }) end
    return out
  end
  check(not objectives_ok(M), "mutant : passage du centre proposé à l'époque 15, refusé")
  M.objectives = function(k, exists)
    local out = orig(k, exists)
    for _, o in ipairs(out) do if o.kind == "cap" then o.level = 2 * k + 1 end end
    return out
  end
  check(not objectives_ok(M), "mutant : plafond faux, refusé")
  M.objectives = function(k) local out = orig(k); if out[1].cost and out[1].cost[1] then out[1].cost[1][2] = out[1].cost[1][2] + 1 end; return out end
  check(not objectives_ok(M), "mutant : coût du centre différent de L.cost, refusé")
  local en2 = {}
  for k, v in pairs(EN) do en2[k] = v end
  en2["fo-journal.threat-7"] = nil
  check(#parity_errors(FR, en2) == 1, "mutant : clé EN manquante, détectée")
  local bad = os.tmpname()
  local f = io.open(bad, "wb")
  f:write("local A = require(\"x\")\nlocal function g()\n  local B = require(\"y\")\n  for k in pairs(t) do end\n  return global\nend\n")
  f:close()
  check(#rules_errors(bad) == 3, "mutant : require en fonction, pairs sans tri, global, détectés (" .. #rules_errors(bad) .. ")")
  os.remove(bad)
end

print(string.format("[SCENARIO] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
