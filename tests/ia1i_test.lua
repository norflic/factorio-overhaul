--[[
  Tests hors jeu de l'interface « Équipe et factions » (lot IA1-i).
  Usage, depuis la racine du mod :   lua5.2 tests/ia1i_test.lua

  Vérifie :
    1. le modèle pur (shared/gui/ia1i.lua) : horloge, minutes, journal (différences de relevés, plafond de 20),
       relation d'une faction avec vous, traits saillants, préréglages tirés de O.PRESETS ;
    2. la fenêtre sur le moteur simulé, avec un conteneur d'interface FACTICE (le mock n'a pas d'interface) :
       raccourci et touche, onglets, chaque bouton cliqué par l'événement on_gui_click, état relu après ;
    3. AUCUNE seconde logique : la même partie jouée deux fois, une fois par le bouton, une fois par la commande
       (/fo-war start, /fo-team orientation, /fo-team dismiss, /fo-war stop), donne le même état ;
    4. lecture seule : la même partie de 10 min, fenêtre ouverte et rafraîchie chaque seconde, ou fermée, donne le
       même état de jeu (hors espace « ia1i » de l'interface) ; aucun rafraîchissement fenêtre fermée.
  Le moteur réel est prouvé par le scénario greffé « ia1-gui » et les captures (fo-captures.bat).
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local G = require("shared.gui.ia1i")
local O = require("shared.team.org")

---------------------------------------------------------------------------------------------------
section("Modèle pur : horloge, minutes")
do
  check(G.clock(0) == "0:00", "horloge 0")
  check(G.clock(125 * 60) == "2:05", "horloge 2:05 (" .. G.clock(125 * 60) .. ")")
  check(G.clock(3600 * 60 + 61 * 60) == "1:01:01", "horloge 1:01:01 (" .. G.clock(3600 * 60 + 61 * 60) .. ")")
  check(G.minutes(0) == 0 and G.minutes(-5) == 0, "minutes : 0 et négatif")
  check(G.minutes(1) == 1 and G.minutes(3600) == 1 and G.minutes(3601) == 2, "minutes arrondies au-dessus")
  check(#G.TABS == 7 and G.TAB_INDEX.factions == 3 and G.TABS[G.TAB_INDEX.pnj] == "pnj" and G.TAB_INDEX.partie == 5
    and G.TAB_INDEX.territoire == 6, "onglets et index (Partie ajouté en 5e position par le lot PANEL-STATS)")
  check(G.REFRESH <= 60, "rafraîchissement : au plus une fois par seconde (" .. G.REFRESH .. " ticks)")
end

section("Modèle pur : journal")
do
  local function team(o)
    local t = { n = 8, max = 30, recruited = 0, lost = 0, built = 0, outposts_lost = 0, goal = "coal", tech = 0,
      orientation = "equilibre" }
    for k, v in pairs(o or {}) do t[k] = v end
    return t
  end
  local war0 = { active = false, factions = {} }
  check(#G.journal_diff(nil, { team = team() }) == 0, "premier relevé : aucune entrée")
  local d = G.journal_diff({ war = war0 }, { team = team(), war = war0 })
  check(#d == 1 and d[1].kind == "team-created" and d[1].a == 8 and d[1].b == 30, "équipe fondée")
  d = G.journal_diff({ team = team(), war = war0 }, { war = war0 })
  check(#d == 1 and d[1].kind == "team-lost", "équipe perdue")
  d = G.journal_diff({ team = team(), war = war0 }, { team = team({ n = 9, recruited = 2, lost = 1, built = 1,
    outposts_lost = 1, goal = "iron", tech = 1, orientation = "ressources" }), war = war0 })
  local kinds = {}
  for _, e in ipairs(d) do kinds[#kinds + 1] = e.kind end
  check(table.concat(kinds, ",") == "recruits,lost,outpost-built,outpost-lost,goal,research,orientation",
    "différences de l'équipe, dans l'ordre (" .. table.concat(kinds, ",") .. ")")
  check(d[1].a == 2 and d[1].b == 9 and d[1].c == 30 and d[5].a == "iron" and d[6].a == 1, "valeurs des entrées")
  local done = team()
  done.goal = nil
  d = G.journal_diff({ team = team() }, { team = done })
  check(#d == 1 and d[1].kind == "goal-done", "objectifs atteints")
  check(#G.journal_diff({ team = team() }, { team = team() }) == 0, "rien de changé : aucune entrée")
  local w1 = { active = true, factions = { { key = "scarlet", declared = false, eliminated = false },
    { key = "azure", declared = true, eliminated = false }, { key = "emerald", declared = false, eliminated = false } } }
  d = G.journal_diff({ war = war0 }, { war = w1 })
  check(#d == 1 and d[1].kind == "war-started" and d[1].a == 3, "guerre lancée (3 factions)")
  local w2 = { active = true, factions = { { key = "scarlet", declared = true, eliminated = true },
    { key = "azure", declared = false, eliminated = false }, { key = "emerald", declared = true, eliminated = false } } }
  d = G.journal_diff({ war = w1 }, { war = w2 })
  kinds = {}
  for _, e in ipairs(d) do kinds[#kinds + 1] = e.kind .. ":" .. e.a end
  check(table.concat(kinds, ",") == "eliminated:scarlet,truce:azure,declared:emerald",
    "anéantie (prime sur la déclaration), trêve, déclaration (" .. table.concat(kinds, ",") .. ")")
  d = G.journal_diff({ war = w2 }, { war = war0 })
  check(#d == 1 and d[1].kind == "war-stopped", "guerre arrêtée")
  local list = {}
  for i = 1, 25 do G.journal_push(list, { { kind = "research", a = i } }, i * 60) end
  check(#list == G.JOURNAL_MAX and list[1].a == 6 and list[#list].a == 25 and list[#list].tick == 1500,
    "journal : les 20 dernières entrées, datées")
end

section("Modèle pur : factions, orientation")
do
  local r = G.relation({ eliminated = true, declared = true }, 0)
  check(r.kind == "eliminated", "anéantie")
  check(G.relation({ declared = true }, 0).kind == "war", "en guerre")
  check(G.relation({ declared = true, provoked = true }, 0).kind == "provoked", "guerre provoquée")
  r = G.relation({ grace_end = 1000 + 12 * 3600 - 1 }, 1000)
  check(r.kind == "truce" and r.minutes == 12, "trêve : 12 min restantes (" .. tostring(r.minutes) .. ")")
  r = G.relation({ grace_end = 500 }, 1000)
  check(r.kind == "truce" and r.minutes == 0, "trêve échue : 0 min")
  check(G.relation({}, 0).kind == "truce-peaceful", "sans fin de grâce (Paisible)")
  local order = { "a", "b", "c", "d" }
  local s = G.salient({ a = 900, b = 1500, c = 1500, d = 1200 }, order)
  check(#s == 2 and s[1].key == "b" and s[2].key == "c", "traits saillants : les deux plus forts, égalité dans l'ordre")
  check(#G.salient(nil, order) == 0, "sans traits : aucun")
  check(G.permille(1620) == "1,62" and G.permille(1000) == "1,00" and G.permille(755) == "0,76", "pour mille écrit 1,62")
  local rows = G.preset_rows()
  local ok = #rows == #O.PRESET_ORDER
  for i, row in ipairs(rows) do
    local p = O.PRESETS[row.name]
    ok = ok and row.name == O.PRESET_ORDER[i] and row.pts[1] == p.extraction and row.pts[2] == p.base
      and row.pts[3] == p.territoire and row.pts[1] + row.pts[2] + row.pts[3] == 100
  end
  check(ok, "préréglages : ceux de O.PRESETS, dans l'ordre, somme 100")
  check(G.current_preset("ressources") == "ressources" and G.current_preset({ 50, 50, 0 }) == "custom"
    and G.current_preset("inconnu") == "custom", "préréglage courant ou « custom »")
end

---------------------------------------------------------------------------------------------------
-- Interface factice : assez de LuaGuiElement pour la fenêtre (add, clear, destroy, enfants par nom, styles).
---------------------------------------------------------------------------------------------------
local function new_el(spec, parent)
  local el = { type = spec.type, name = spec.name or "", caption = spec.caption, tooltip = spec.tooltip,
    style_name = spec.style, enabled = true, valid = true, object_name = "LuaGuiElement", children = {}, style = {},
    parent = parent, sprite = spec.sprite, number = spec.number }
  el.add = function(s)
    assert(s.type, "add : type attendu")
    if s.name then
      for _, c in ipairs(el.children) do assert(c.name ~= s.name, "add : nom en double " .. s.name) end
    end
    local c = new_el(s, el)
    el.children[#el.children + 1] = c
    return c
  end
  el.clear = function()
    for _, c in ipairs(el.children) do c.valid = false end
    el.children = {}
  end
  el.destroy = function()
    el.valid = false
    if parent then
      for i, c in ipairs(parent.children) do if c == el then table.remove(parent.children, i) break end end
    end
  end
  el.add_tab = function(tab, content) el.tabs = el.tabs or {}; el.tabs[#el.tabs + 1] = { tab = tab, content = content } end
  el.force_auto_center = function() end
  return setmetatable(el, { __index = function(t, k)
    for _, c in ipairs(rawget(t, "children")) do if c.name == k then return c end end
    return nil
  end })
end

local function find(el, name)
  for _, c in ipairs(el.children) do
    if c.name == name then return c end
    local r = find(c, name)
    if r then return r end
  end
end

local function keys_of(el, out)
  out = out or {}
  for _, c in ipairs(el.children) do
    if type(c.caption) == "table" and type(c.caption[1]) == "string" then out[c.caption[1]] = (out[c.caption[1]] or 0) + 1 end
    keys_of(c, out)
  end
  return out
end

local W
local toggled = {}
local function setup_gui()
  W = M.world()
  local p = W.player
  p.gui.screen = new_el({ type = "screen" })
  toggled = {}
  p.set_shortcut_toggled = function(n, v) toggled[n] = v end
  p.is_shortcut_toggled = function(n) return toggled[n] or false end
  p.opened = nil
  defines.mouse_button_type = { left = 1, right = 2, middle = 3 }
  defines.gui_type = defines.gui_type or { custom = 1 }
end

local FRAME = "fo_ia1i_frame"
local function frame() return W.player.gui.screen[FRAME] end
local function click(name)
  local el = frame() and find(frame(), name)
  if not el then return false end
  M.dispatch(W.events[defines.events.on_gui_click], { element = el, player_index = 1, tick = game.tick })
  return true
end
local function select_tab(i)
  local tp = find(frame(), "fo_ia1i_tabs")
  tp.selected_tab_index = i
  M.dispatch(W.events[defines.events.on_gui_selected_tab_changed], { element = tp, player_index = 1, tick = game.tick })
end
local function pane(k) return find(frame(), "fo_ia1i_c_" .. k) end

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

local function place_chest()
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "pistol", 2 }, { "firearm-magazine", 40 }, { "burner-mining-drill", 6 }, { "stone-furnace", 6 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  M.dispatch(W.events[defines.events.on_built_entity], { created_entity = chest, player_index = 1, tick = game.tick })
  return chest
end

---------------------------------------------------------------------------------------------------
section("Fenêtre : raccourci, touche, onglets (moteur simulé)")
M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
setup_gui()
do
  M.dispatch(W.events[defines.events.on_lua_shortcut], { prototype_name = "fo-team-gui", player_index = 1 })
  check(frame() ~= nil, "raccourci : fenêtre ouverte")
  check(toggled["fo-team-gui"] == true, "raccourci allumé")
  check(W.player.opened == frame(), "fenêtre ouverte comme `opened` (Échap la ferme)")
  local tp = find(frame(), "fo_ia1i_tabs")
  check(tp and #tp.tabs == 7, "7 onglets")
  local k = keys_of(pane("equipe"))
  check(k["fo-ia1i.none-title"] == 1 and k["fo-ia1i.none-how"] == 1, "sans équipe : comment poser un coffre")
  M.dispatch(W.events[defines.events.on_lua_shortcut], { prototype_name = "autre", player_index = 1 })
  check(frame() ~= nil, "autre raccourci : ignoré")
  M.dispatch(W.events["fo-team-gui"], { player_index = 1, input_name = "fo-team-gui" })
  check(frame() == nil and toggled["fo-team-gui"] == false, "touche : fenêtre fermée, raccourci éteint")
  M.dispatch(W.events["fo-team-gui"], { player_index = 1, input_name = "fo-team-gui" })
  check(frame() ~= nil, "touche : fenêtre rouverte")
  local centered = 0
  frame().force_auto_center = function() centered = centered + 1 end
  M.dispatch(W.events[defines.events.on_player_display_resolution_changed], { player_index = 1 })
  M.dispatch(W.events[defines.events.on_player_display_scale_changed], { player_index = 1 })
  check(centered == 2, "taille ou échelle d'affichage changée : fenêtre recentrée (" .. centered .. ")")
  M.dispatch(W.events[defines.events.on_gui_closed], { element = frame(), player_index = 1 })
  check(frame() == nil, "Échap (on_gui_closed) : fenêtre fermée")
  M.dispatch(W.events[defines.events.on_player_display_resolution_changed], { player_index = 1 })
  check(true, "taille changée fenêtre fermée : rien à faire, sans erreur")
end

section("Mon équipe et PNJ")
local chest = place_chest()
M.run_ticks(60 * 60)
M.dispatch(W.events[defines.events.on_lua_shortcut], { prototype_name = "fo-team-gui", player_index = 1 })
do
  local k = keys_of(pane("equipe"))
  local goal = global.fo.pteam.team.team.goal
  check(k["fo-ia1i.goal"] == 1 and k["fo-team.goal-" .. tostring(goal)] == 1,
    "objectif affiché (" .. tostring(goal) .. ")")
  check(k["fo-ia1i.staff-line"] == 1 and k["fo-ia1i.col-pole"] == 1 and k["fo-ia1i.staff-age"] == 1,
    "effectifs, tableau des pôles et âge de la dernière pensée")
  check(k["fo-ia1b.mgr-gisements"] == 1 and k["fo-ia1b.mgr-defense"] == 1, "une ligne par manager")
  check(k["fo-ia1i.chest"] == 1 and (k["fo-ia1i.chest-empty"] or 0) == 0, "coffre affiché")
  check(k["fo-ia1i.journal"] == 1 and k["fo-ia1i.coming"] == 1, "journal et « à venir »")
  select_tab(G.TAB_INDEX.pnj)
  local f = global.fo.pteam.team
  k = keys_of(pane("pnj"))
  check(k["fo-ia1i.pnj-head"] == 1, "PNJ : en-tête")
  check((k["fo-ia1i.role-executant"] or 0) + (k["fo-ia1i.role-generalist"] or 0) == f.engineers_count,
    "PNJ : une ligne par PNJ vivant (" .. f.engineers_count .. ")")
  check(#pane("equipe").children == 0, "onglet caché vidé (rien de périmé)")
end

section("Orientation : préréglage et renvoi confirmé dans la fenêtre")
local Poles = require("script.team.poles")
do
  select_tab(G.TAB_INDEX.orientation)
  local f = global.fo.pteam.team
  check(find(frame(), "fo_ia1i_preset_ressources") ~= nil, "5 boutons de préréglage")
  check(find(frame(), "fo_ia1i_preset_equilibre").style_name == "green_button", "équilibre en vert au départ")
  check(click("fo_ia1i_preset_ressources"), "clic « Ressources »")
  check(Poles.orientation(f) == "ressources", "orientation écrite par Poles.set_orientation")
  check(find(frame(), "fo_ia1i_preset_ressources").style_name == "green_button", "Ressources en vert après le clic")
  check(W.prints[#W.prints]:find("fo%-ia1b%.orientation%-set") ~= nil or W.prints[#W.prints]:find("60") ~= nil,
    "même message que la commande (" .. tostring(W.prints[#W.prints]) .. ")")
  local n0 = f.engineers_count
  check(click("fo_ia1i_dismiss"), "clic « Renvoyer l'équipe »")
  check(find(frame(), "fo_ia1i_dismiss_yes") ~= nil and find(frame(), "fo_ia1i_dismiss") == nil, "confirmation affichée")
  check(f.engineers_count == n0 and n0 > 0, "rien de renvoyé avant la confirmation (" .. n0 .. " PNJ)")
  M.run_ticks(120)
  check(find(frame(), "fo_ia1i_dismiss_yes") ~= nil, "confirmation gardée par le rafraîchissement")
  check(click("fo_ia1i_dismiss_no"), "clic « Annuler »")
  check(find(frame(), "fo_ia1i_dismiss") ~= nil and f.engineers_count == n0, "annulé : rien de renvoyé")
end

section("Factions : lancer, cartes, arrêt confirmé")
local War = require("script.faction.war")
local State = require("script.faction.state")
do
  select_tab(G.TAB_INDEX.factions)
  local k = keys_of(pane("factions"))
  check(k["fo-ia1i.war-none"] == 1 and find(frame(), "fo_ia1i_war_start") ~= nil, "sans guerre : bouton « Lancer »")
  local function caption_of(el, key)
    for _, ch in ipairs(el.children) do
      if type(ch.caption) == "table" and ch.caption[1] == key then return ch.caption end
      local r = caption_of(ch, key)
      if r then return r end
    end
  end
  local cap = caption_of(pane("factions"), "fo-ia1i.war-start-text")
  local g = settings.global
  check(cap and cap[2] == g["fo-war-factions"].value and cap[3] == g["fo-war-soldiers"].value
    and cap[4] == g["fo-war-workers"].value,
    "réglages de carte affichés à côté du bouton (" .. (cap and (tostring(cap[2]) .. ", " .. tostring(cap[3]) .. ", "
    .. tostring(cap[4])) or "absent") .. ")")
  W.player.admin = false
  game.is_multiplayer = function() return true end
  setup_gui()
  M.dispatch(W.events[defines.events.on_lua_shortcut], { prototype_name = "fo-team-gui", player_index = 1 })
  select_tab(G.TAB_INDEX.factions)
  check(find(frame(), "fo_ia1i_war_start").enabled == false, "multijoueur, pas administrateur : bouton grisé")
  click("fo_ia1i_war_start")
  check(not State.war().active, "multijoueur, pas administrateur : guerre refusée (comme la commande)")
  W.player.admin = true
  game.is_multiplayer = function() return false end
  select_tab(G.TAB_INDEX.factions)
  check(click("fo_ia1i_war_start"), "clic « Lancer la guerre »")
  local ws = State.war().settings
  check(State.war().active and #State.alive() == settings.global["fo-war-factions"].value
    and ws.soldiers_max == settings.global["fo-war-soldiers"].value and ws.npc_from_setting == true,
    "guerre lancée avec les réglages de carte (" .. #State.alive() .. " factions, " .. tostring(ws.soldiers_max)
    .. " soldats au plus, ouvriers suivis du réglage : " .. tostring(ws.npc_from_setting) .. ")")
  M.run_ticks(3 * 3600)
  k = keys_of(pane("factions"))
  local n = #State.alive()
  check(k["fo-ia1i.war-head"] == 1 and k["fo-ia1i.character"] == n and k["fo-ia1i.forces"] == n,
    "une carte par faction (" .. tostring(k["fo-ia1i.character"]) .. " sur " .. n .. ")")
  check((k["fo-ia1i.rel-truce"] or 0) + (k["fo-ia1i.rel-truce-peaceful"] or 0) + (k["fo-ia1i.rel-war"] or 0)
    + (k["fo-ia1i.rel-truce-due"] or 0) + (k["fo-ia1i.rel-provoked"] or 0) == n, "relation avec vous sur chaque carte")
  check((k["fo-ia1i.chef"] or 0) + (k["fo-ia1i.chef-none"] or 0) == n, "posture du chef sur chaque carte")
  check((k["fo-ia1i.knows"] or 0) + (k["fo-ia1i.knows-nothing"] or 0) == n, "ce qu'elle sait de vous sur chaque carte")
  print(string.format("  postures : %d décidée(s), connaissance : %d", k["fo-ia1i.chef"] or 0, k["fo-ia1i.knows"] or 0))
  check(click("fo_ia1i_war_stop"), "clic « Arrêter la guerre »")
  check(State.war().active and find(frame(), "fo_ia1i_war_stop_yes") ~= nil, "confirmation affichée, guerre encore en cours")
  check(click("fo_ia1i_war_stop_no") and State.war().active, "annulé : guerre en cours")
  click("fo_ia1i_war_stop")
  check(click("fo_ia1i_war_stop_yes") and not State.war().active, "confirmé : guerre arrêtée par War.stop")
  check(W.prints[#W.prints]:find("war%-stopped") ~= nil, "message d'arrêt (" .. tostring(W.prints[#W.prints]) .. ")")
end

section("Journal et renvoi confirmé")
do
  select_tab(G.TAB_INDEX.orientation)
  local f = global.fo.pteam.team
  click("fo_ia1i_dismiss")
  check(click("fo_ia1i_dismiss_yes"), "clic « Confirmer le renvoi »")
  check(f.engineers_count == 0, "équipe renvoyée par PlayerTeam.dismiss (" .. f.engineers_count .. " PNJ)")
  M.run_ticks(60)
  local kinds = {}
  for _, e in ipairs(W.remote["fo-ia1i"].journal()) do kinds[e.kind] = true end
  check(kinds["orientation"] and kinds["war-started"] and kinds["war-stopped"], "journal : orientation, guerre lancée, arrêtée")
  select_tab(G.TAB_INDEX.equipe)
  local k = keys_of(pane("equipe"))
  check((k["fo-ia1i.j-line"] or 0) >= 3, "journal affiché dans « Mon équipe » (" .. tostring(k["fo-ia1i.j-line"]) .. ")")
end

section("Interface distante « fo-ia1i » (bancs)")
do
  local R = W.remote["fo-ia1i"]
  check(R.close(1) and frame() == nil, "close")
  check(R.open(1, "factions") and frame() ~= nil and R.state(1).tab == "factions", "open sur un onglet")
  check(R.select(1, "orientation") and R.state(1).tab == "orientation", "select")
  check(R.click(1, "fo_ia1i_dismiss") and R.state(1).confirm == "dismiss", "click (même fonction que le clic)")
  local st = R.state(1)
  local has = false
  for _, n in ipairs(st.names) do if n == "fo_ia1i_dismiss_yes" then has = true end end
  check(has and st.shortcut and st.opened, "state : noms, raccourci, opened")
  check(R.click(1, "inexistant") == false, "click d'un nom absent : faux")
  check(R.toggle(1) == false and frame() == nil, "toggle ferme")
end

---------------------------------------------------------------------------------------------------
-- Même partie, bouton contre commande ; fenêtre ouverte contre fermée
---------------------------------------------------------------------------------------------------
local function dump(t, seen, depth)
  seen = seen or {}
  depth = depth or 0
  if type(t) ~= "table" then return tostring(t) end
  if t._lua_object or t.object_name then return "<" .. tostring(t.name) .. ":" .. tostring(t.unit_number) .. ">" end
  if seen[t] then return "<cycle>" end
  if depth > 40 then return "<prof>" end
  seen[t] = true
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do
    if not (depth == 0 and k == "ia1i") then
      local v = t[k]
      if type(v) ~= "function" then parts[#parts + 1] = tostring(k) .. "=" .. dump(v, seen, depth + 1) end
    end
  end
  seen[t] = nil
  return "{" .. table.concat(parts, ",") .. "}"
end

local function game_state() return dump(global.fo) end

local function play(by_gui, gui_open, tab)
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
  setup_gui()
  place_chest()
  if gui_open then
    M.dispatch(W.events[defines.events.on_lua_shortcut], { prototype_name = "fo-team-gui", player_index = 1 })
    if tab then select_tab(G.TAB_INDEX[tab]) end
  end
  M.run_ticks(600)
  if by_gui == "gui" then
    if not frame() then M.dispatch(W.events[defines.events.on_lua_shortcut], { prototype_name = "fo-team-gui", player_index = 1 }) end
    select_tab(G.TAB_INDEX.factions)
    click("fo_ia1i_war_start")
    select_tab(G.TAB_INDEX.orientation)
    click("fo_ia1i_preset_protection")
  elseif by_gui == "cmd" then
    -- Le bouton prend les réglages de carte (comme le lancement automatique) : /fo-war start <factions> <soldats>.
    M.command("fo-war", "start " .. settings.global["fo-war-factions"].value .. " " .. settings.global["fo-war-soldiers"].value)
    M.command("fo-team", "orientation protection")
  end
  M.run_ticks(5 * 3600)
  if by_gui == "gui" then
    click("fo_ia1i_dismiss")
    click("fo_ia1i_dismiss_yes")
    select_tab(G.TAB_INDEX.factions)
    click("fo_ia1i_war_stop")
    click("fo_ia1i_war_stop_yes")
  elseif by_gui == "cmd" then
    M.command("fo-team", "dismiss")
    M.command("fo-war", "stop")
  end
  if gui_open and not frame() then
    M.dispatch(W.events[defines.events.on_lua_shortcut], { prototype_name = "fo-team-gui", player_index = 1 })
    if tab then select_tab(G.TAB_INDEX[tab]) end
  end
  M.run_ticks(5 * 3600)
  return game_state(), global.fo.ia1i.refreshes
end

section("Aucune seconde logique : bouton contre commande")
do
  local a = play("gui", false)
  local b = play("cmd", false)
  check(#a > 1000 and a == b, string.format("même état de jeu après lancer, orienter, renvoyer, arrêter (%d contre %d caractères)",
    #a, #b))
  if a ~= b then
    for i = 1, math.min(#a, #b) do
      if a:sub(i, i) ~= b:sub(i, i) then print("  premier écart : " .. a:sub(math.max(1, i - 120), i + 80)); break end
    end
  end
end

section("Lecture seule : fenêtre ouverte contre fermée (10 min de jeu)")
do
  local a, ra = play("cmd", true)
  local b, rb = play("cmd", false)
  check(a == b, string.format("même état de jeu, fenêtre ouverte et rafraîchie ou fermée (%d contre %d caractères)", #a, #b))
  check(ra >= 590 and rb == 0, string.format("rafraîchissements : %d fenêtre ouverte (une par seconde), %d fermée", ra, rb))
end

section("Onglet Partie : valeurs du panneau contre les compteurs du moteur simulé (lot PANEL-STATS)")
do
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
  setup_gui()
  place_chest()
  M.command("fo-war", "start 2 30")
  local pf = global.fo.pteam.team
  local force = game.forces[pf.force]
  -- Statistiques du moteur simulées (le mock n'en a pas) : le panneau doit les relire telles quelles.
  local input, output = { ["obj-a"] = 0, ["obj-b"] = 50 }, { ["obj-a"] = 0 }
  force.item_production_statistics = { input_counts = input, output_counts = output }
  force.kill_count_statistics = { input_counts = { u1 = 4, u2 = 6 }, output_counts = { b1 = 30, b2 = 12 } }
  local names, expected_total = {}, 0
  for name, proto in pairs(game.technology_prototypes) do
    names[#names + 1] = name
    if not proto.hidden then expected_total = expected_total + 1 end
  end
  table.sort(names)
  for i = 1, 5 do force.technologies[names[i]].researched = true end
  for _ = 1, 6 do -- 3 min : 120 objets « obj-a » par relevé de 30 s, soit 240 par minute
    M.run_ticks(1800)
    input["obj-a"] = input["obj-a"] + 120
  end
  local R = W.remote["fo-ia1i"]
  local d = R.panel("player")
  local alive = State.alive()
  check(#d.teams == 1 + #alive and d.teams[1].key == "player" and d.teams[1].player, "une ligne par équipe : la vôtre, puis les factions (" .. #d.teams .. ")")
  local row = d.teams[1]
  check(row.kills == 42 and row.losses == 10, "kills et pertes = somme des sorties et des entrées du moteur (" .. tostring(row.kills) .. ", " .. tostring(row.losses) .. ")")
  local done = 0 -- relu ici, indépendamment du panneau : les 5 posées plus celles que le jeu a payées lui-même
  for _, name in ipairs(names) do if force.technologies[name].researched then done = done + 1 end end
  check(done >= 5 and row.techs_done == done and row.techs_total == expected_total,
    "technologies : " .. done .. " recherchées sur " .. expected_total .. " (" .. tostring(row.techs_done) .. " sur " .. tostring(row.techs_total) .. ")")
  check(row.soldiers == (pf.soldiers_count or 0) and row.engineers == pf.engineers_count and row.outposts == (pf.outposts_count or 0)
    and row.npc_max == require("script.team.team").npc_max(pf), "soldats, PNJ, avant-postes = état de l'équipe")
  local pvp_sum = 0
  for i, id in ipairs(alive) do
    local fac = State.faction(id)
    local r = d.teams[i + 1]
    check(r.key == fac.key and r.attacks_in == (fac.pvp and fac.pvp.attacks or 0) and r.attacks_out == fac.stats.attacks
      and r.level == (fac.tech or 0), "faction " .. fac.key .. " : attaques et niveau = état de la faction")
    pvp_sum = pvp_sum + (fac.pvp and fac.pvp.attacks or 0)
  end
  check(row.attacks_in == pvp_sum and row.attacks_out == nil, "votre ligne : attaques subies = somme des factions, aucune lancée")
  local m = d.detail.machines
  check(#m == 2 and m[1].name == "obj-a" and m[1].total == input["obj-a"], "machines : l'objet qui coule le plus d'abord, cumul frais")
  check(m[1].rate and math.abs(m[1].rate - 240) <= 12, "machines : débit 240 / min à 5 % près (" .. tostring(m[1].rate) .. ")")
  check(m[2].name == "obj-b" and m[2].total == 50 and m[2].rate == 0, "machines : un compteur immobile a un débit nul")
  check(d.detail.prod_total == input["obj-a"] + 50 and d.detail.span >= 3600, "cumul total et durée des relevés (" .. tostring(d.detail.span) .. " ticks)")
  local w = d.detail.workers
  local sum = 0
  for _, t in ipairs(w.tasks) do sum = sum + t.n end
  check(w.alive == pf.engineers_count and sum == pf.engineers_count and w.total == sum,
    "PNJ : la somme des tâches vaut l'effectif vivant (" .. sum .. " sur " .. pf.engineers_count .. ")")
  check(d.detail.hands and d.detail.hands.mined == (pf.stats.mined or 0) and d.detail.hands.crafted == (pf.stats.crafted or 0),
    "mains : minerai miné et fabrications = compteurs du mod, à part des machines")

  -- Affichage
  R.close(1)
  check(R.open(1, "partie") and R.state(1).tab == "partie" and R.state(1).selected == G.TAB_INDEX.partie, "ouverture sur l'onglet Partie")
  local k = keys_of(pane("partie"))
  check(k["fo-panel.head"] == 1 and k["fo-panel.teams-title"] == 1 and k["fo-panel.tech-value"] == #d.teams
    and k["fo-panel.research-title"] == 1, "avancée : une ligne par équipe")
  check(k["fo-panel.machines-title"] == 1 and k["fo-panel.machines-note"] == 1 and k["fo-panel.hands-title"] == 1
    and k["fo-panel.hands-note"] == 1 and k["fo-panel.workers-title"] == 1,
    "machines, mains et PNJ : trois blocs séparés, chacun avec sa note")
  check((k["fo-panel.research-line"] or 0) + (k["fo-panel.research-none"] or 0) == #d.teams, "recherche en cours : une ligne par équipe")
  check(find(frame(), "fo_ia1i_pteam_player").style_name == "green_button", "équipe détaillée : la vôtre en vert")
  local function caption_of(el, key)
    for _, ch in ipairs(el.children) do
      if type(ch.caption) == "table" and ch.caption[1] == key then return ch.caption end
      local r = caption_of(ch, key)
      if r then return r end
    end
  end
  local fk = State.faction(alive[1]).key
  check(click("fo_ia1i_pteam_" .. fk), "clic sur le bouton d'une faction")
  local cap = caption_of(pane("partie"), "fo-panel.workers-title")
  check(cap and cap[2][1] == "fo-faction.name-" .. fk and find(frame(), "fo_ia1i_pteam_" .. fk).style_name == "green_button"
    and find(frame(), "fo_ia1i_pteam_player").style_name == "button", "équipe détaillée : la faction choisie")
  check(R.panel(fk).detail.key == fk, "interface distante : détail de la faction")
  -- Relevés tenus fenêtre fermée
  R.close(1)
  local n0 = #R.panel_ring("player")
  local r0 = R.state(1).refreshes
  M.run_ticks(1800 * 3)
  check(R.state(1).refreshes == r0, "fenêtre fermée : aucun rafraîchissement ajouté")
  check(#R.panel_ring("player") == math.min(n0 + 3, 7), "les relevés continuent fenêtre fermée (anneau borné à 7)")
  local ring = R.panel_ring("player")
  check(#ring <= 7 and ring[#ring].tick > ring[1].tick, "anneau borné et daté")
  -- Équipe disparue : son anneau est retiré
  State.faction(alive[1]).eliminated = true
  M.run_ticks(1800)
  check(#R.panel_ring(fk) == 0, "faction anéantie : son anneau est retiré")
end

section("Onglet Partie : lecture seule (fenêtre ouverte sur l'onglet contre fermée)")
do
  local a, ra = play("cmd", true, "partie")
  local b, rb = play("cmd", false)
  check(a == b, string.format("même état de jeu, onglet Partie ouvert et rafraîchi ou fenêtre fermée (%d contre %d caractères)", #a, #b))
  check(ra >= 590 and rb == 0, string.format("rafraîchissements : %d fenêtre ouverte, %d fermée", ra, rb))
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
