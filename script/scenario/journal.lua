--[[
  Journal d'époque (piste SCENARIOS, 30/10) : le récit et les objectifs de chaque époque, EN JEU.
  Règles pures : shared/scenario/journal.lua ; design : docs/SCENARIOS_DESIGN.md §3.

  - Intro : au premier passage de chaque joueur en personnage (après la cinématique de freeplay), une fenêtre
    « Arche-5 » : texte d'introduction du scénario X0, et l'objectif « réparer l'épave » si son centre en est une.
  - Époque : quand le centre d'une force atteint une époque nouvelle (réparation de l'épave = époque 1, puis chaque
    passage du centre), la fenêtre du journal s'ouvre chez chaque joueur connecté de la force : Codex, acte,
    objectifs (coût exact du centre suivant, plafond, gisements de l'époque, cartographie, menace), plus une ligne
    de chat. Détection : crochet Levels.on_replaced (immédiat) et relevé toutes les 120 ticks (réparation, centre
    posé par script ou par un robot). Jamais deux annonces de la même époque (règle J.decide).
  - /fo-journal [k] : relire l'époque actuelle ou une époque déjà atteinte (boutons précédent / suivant).
  - Forces suivies : celles qui ont au moins un joueur, plus « player » (bancs sans joueur). Les factions n'ont pas
    de joueur : ignorées.
  - Sauvegarde d'avant le journal (0.6.18) : au premier chargement, chaque force est ALIGNÉE sur son époque actuelle
    sans rien annoncer, chaque joueur existant est réputé avoir lu l'intro ; une ligne de chat signale /fo-journal.
  - Aucun effet sur l'équilibre : rien n'est donné ni exigé.
  Stockage : espace « journal » { reached = { [force] = époque }, intro = { [index du joueur] = true }, born, stats }.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local L = require("shared.levels.config")
local J = require("shared.scenario.journal")
local Levels = require("script.levels.levels")

local Journal = {}

local FRAME = "fo_journal_frame"
local CC = L.by_key.command
local POLL = 120
local WIDTH = 460

Storage.declare("journal", function()
  return { reached = {}, intro = {}, born = nil, stats = { announced = 0, intros = 0, aligned = 0 } }
end)

local function S() return Storage.ns("journal") end

local function lk(key, ...) return { J.LOCALE .. "." .. key, ... } end

---------------------------------------------------------------------------------------------------
-- Lecture du jeu
---------------------------------------------------------------------------------------------------
local function resource_exists(name)
  local p = game.entity_prototypes[name]
  return p ~= nil and p.type == "resource"
end

--- Forces suivies, triées par nom.
local function tracked_forces()
  local names = {}
  for name, force in pairs(game.forces) do
    if name == "player" or #force.players > 0 then names[#names + 1] = name end
  end
  table.sort(names)
  local out = {}
  for _, n in ipairs(names) do out[#out + 1] = game.forces[n] end
  return out
end

--- Joueurs connectés de la force, triés par index.
local function connected_players(force)
  local list = {}
  for _, p in pairs(force.connected_players) do list[#list + 1] = p end
  table.sort(list, function(a, b) return a.index < b.index end)
  return list
end

--- Chunks cartographiés par la force sur une surface (compté à l'ouverture de la fenêtre seulement).
local function charted_chunks(force, surface)
  local n = 0
  for chunk in surface.get_chunks() do
    if force.is_chunk_charted(surface, chunk) then n = n + 1 end
  end
  return n
end

--- Combien d'`item` dans le centre de la force et sur le joueur.
local function have(force, player, item)
  local n = 0
  local cc = Levels.cc(force)
  if cc then
    local inv = cc.get_inventory(defines.inventory.chest)
    if inv then n = n + inv.get_item_count(item) end
  end
  local main = player and player.valid and player.get_main_inventory()
  if main then n = n + main.get_item_count(item) end
  return n
end

---------------------------------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------------------------------
function Journal.close(player)
  local f = player.gui.screen[FRAME]
  if f and f.valid then f.destroy() end
end

local function new_frame(player, caption)
  Journal.close(player)
  local frame = player.gui.screen.add({ type = "frame", name = FRAME, direction = "vertical", caption = caption })
  frame.auto_center = true
  return frame
end

local function text(parent, caption, color, font)
  local l = parent.add({ type = "label", caption = caption })
  l.style.single_line = false
  l.style.maximal_width = WIDTH
  if color then l.style.font_color = color end
  if font then l.style.font = font end
  return l
end

local function buttons(frame, k, reached)
  local row = frame.add({ type = "flow", direction = "horizontal" })
  if k and k > 1 then
    row.add({ type = "button", name = "fo_journal_prev", caption = lk("prev"), tags = { epoch = k - 1 } })
  end
  if k and k < reached then
    row.add({ type = "button", name = "fo_journal_next", caption = lk("next"), tags = { epoch = k + 1 } })
  end
  row.add({ type = "button", name = "fo_journal_close", caption = lk("close") })
  text(frame, lk("hint"), { r = 0.7, g = 0.7, b = 0.7 })
end

--- Fenêtre d'introduction (Arche-5).
function Journal.show_intro(player)
  local frame = new_frame(player, lk("intro-title"))
  text(frame, lk("intro"), nil, "default-semibold")
  if Levels.is_wreck(player.force) then
    text(frame, lk("intro-repair"), { r = 1, g = 0.75, b = 0.4 })
  end
  local st = S()
  buttons(frame, nil, st and st.reached[player.force.name] or 0)
end

local function objective_line(frame, player, o)
  local force = player.force
  if o.kind == "centre" then
    text(frame, lk("obj-centre", o.target, { "fo-epochs.name-" .. J.epoch_key(o.target) }))
    local tbl = frame.add({ type = "table", column_count = 3 })
    for _, c in ipairs(o.cost) do
      local item, need = c[1], c[2]
      local ok = game.item_prototypes[item] ~= nil
      local got = ok and have(force, player, item) or 0
      local l = tbl.add({ type = "label", caption = ok and ("[item=" .. item .. "] " .. math.min(got, need) .. " / " .. need)
        or (item .. " ? / " .. need) })
      l.style.font_color = (ok and got >= need) and { r = 0.6, g = 1, b = 0.6 } or { r = 1, g = 0.85, b = 0.6 }
    end
  elseif o.kind == "cap" then
    text(frame, lk("obj-cap", o.level))
  elseif o.kind == "resource" then
    local p = game.entity_prototypes[o.name]
    text(frame, lk("obj-resource", "[entity=" .. o.name .. "]", p and p.localised_name or o.name))
  elseif o.kind == "chart" then
    text(frame, lk("obj-chart", charted_chunks(force, player.surface), o.chunks))
  elseif o.kind == "gate" then
    text(frame, lk("obj-gate"))
  elseif o.kind == "threat" then
    text(frame, lk("obj-threat", lk("threat-" .. o.epoch)), { r = 1, g = 0.55, b = 0.5 })
  end
end

--- Fenêtre du journal de l'époque k.
function Journal.show_epoch(player, k)
  local st = S()
  local reached = st and st.reached[player.force.name] or k
  local frame = new_frame(player, lk("title", k, { "fo-epochs.name-" .. J.epoch_key(k) }))
  local act = J.act_of(k)
  text(frame, lk("act-line", act, lk("act-" .. act)), { r = 0.75, g = 0.85, b = 1 })
  text(frame, lk("codex-" .. k), nil, "default-semibold")
  frame.add({ type = "line" })
  text(frame, lk("objectives"), nil, "default-bold")
  for _, o in ipairs(J.objectives(k, resource_exists)) do objective_line(frame, player, o) end
  buttons(frame, k, reached)
end

---------------------------------------------------------------------------------------------------
-- Annonces
---------------------------------------------------------------------------------------------------
local function announce(force, k)
  local st = S()
  st.stats.announced = st.stats.announced + 1
  log("[FO-JOURNAL] force " .. force.name .. " : epoque " .. k .. " annoncee (tick " .. game.tick .. ")")
  for _, p in ipairs(connected_players(force)) do
    p.print(lk("chat-epoch", k, { "fo-epochs.name-" .. J.epoch_key(k) }))
    Journal.show_epoch(p, k)
  end
end

--- Relève l'époque du centre de `force` et annonce une époque nouvelle (règle J.decide).
function Journal.check_force(force)
  local st = S()
  if not (st and force and force.valid) then return end
  local k, reached = J.decide(st.reached[force.name], Levels.cc_level(force))
  st.reached[force.name] = reached
  if k then announce(force, k) end
end

local function check_intros()
  local st = S()
  local list = {}
  for _, p in pairs(game.connected_players) do list[#list + 1] = p end
  table.sort(list, function(a, b) return a.index < b.index end)
  for _, p in ipairs(list) do
    if not st.intro[p.index] and p.controller_type == defines.controllers.character then
      st.intro[p.index] = true
      st.stats.intros = st.stats.intros + 1
      log("[FO-JOURNAL] intro montree au joueur " .. p.index)
      Journal.show_intro(p)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------------------------------
Events.on_init(function()
  local st = S()
  if st then st.born = "init" end
end)

-- Sauvegarde d'avant le journal : alignement SANS annonce.
Events.on_configuration_changed(function()
  local st = S()
  if not st or st.born then return end
  st.born = "migration"
  for _, force in ipairs(tracked_forces()) do
    local _, reached = J.decide(st.reached[force.name], Levels.cc_level(force))
    st.reached[force.name] = reached
    st.stats.aligned = st.stats.aligned + 1
  end
  local idx = {}
  for _, p in pairs(game.players) do idx[#idx + 1] = p.index end
  table.sort(idx)
  for _, i in ipairs(idx) do st.intro[i] = true end
  log("[FO-JOURNAL] sauvegarde existante : " .. st.stats.aligned .. " force(s) alignee(s), " .. #idx .. " joueur(s), aucune annonce")
  game.print(lk("migrated"))
end)

Events.on_nth_tick(POLL, function()
  local st = S()
  if not st then return end
  for _, force in ipairs(tracked_forces()) do Journal.check_force(force) end
  check_intros()
end)

-- Passage du centre : annonce tout de suite (sans attendre le relevé).
Levels.on_replaced[#Levels.on_replaced + 1] = function(_, new)
  if new and new.valid and L.parse(new.name) == CC then
    local force = new.force
    if force.name == "player" or #force.players > 0 then Journal.check_force(force) end
  end
end

Events.on(defines.events.on_gui_click, function(e)
  local el = e.element
  if not (el and el.valid) then return end
  local name = el.name
  if name ~= "fo_journal_close" and name ~= "fo_journal_prev" and name ~= "fo_journal_next" then return end
  local player = game.get_player(e.player_index)
  if not player then return end
  if name == "fo_journal_close" then Journal.close(player); return end
  local st = S()
  local k = el.tags and tonumber(el.tags.epoch)
  local reached = st and st.reached[player.force.name] or 0
  if k and k >= 1 and k <= reached then Journal.show_epoch(player, k) end
end)

commands.add_command("fo-journal", { "fo-journal.command-help" }, function(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  if not player then return end
  local st = S()
  local k, why = J.pick(cmd.parameter, st and st.reached[player.force.name] or 0)
  if k then
    Journal.show_epoch(player, k)
  elseif why == "none" then
    Journal.show_intro(player)
  else
    player.print(lk("command-" .. why, J.MAX))
  end
end)

---------------------------------------------------------------------------------------------------
-- Interface distante (bancs)
---------------------------------------------------------------------------------------------------
remote.add_interface("fo-journal", {
  --- État : { reached, announced, intros, aligned, born }.
  status = function(force_name)
    local st = S() or { reached = {}, stats = {} }
    return { reached = st.reached[force_name or "player"] or 0, announced = st.stats.announced or 0,
             intros = st.stats.intros or 0, aligned = st.stats.aligned or 0, born = st.born }
  end,
  --- Objectifs de l'époque k, filtrés par les prototypes du jeu chargé (données simples).
  objectives = function(k)
    local out = {}
    for _, o in ipairs(J.objectives(k, resource_exists)) do
      out[#out + 1] = { kind = o.kind, target = o.target, level = o.level, name = o.name, chunks = o.chunks,
                        items = o.cost and #o.cost or nil }
    end
    return out
  end,
  --- Relève tout de suite l'époque de la force (sans attendre le relevé périodique).
  check = function(force_name)
    local force = game.forces[force_name or "player"]
    if force then Journal.check_force(force) end
  end,
})

return Journal
