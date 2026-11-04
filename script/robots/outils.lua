--[[
  Lot RB-2 JOUEUR (1/11) : les OUTILS du joueur pour commander ses robots. Règles pures : shared/robots/commande.lua.

  Jamais de contrôle direct d'un robot : le joueur choisit des robots, puis une zone ; le moteur conduit chaque unité (chemin, combat).
    - Outil d'ordre `Ro.TOOL_ORDER` (SelectionToolPrototype, donné par le raccourci « Armée » ou la touche) :
        glisser (bouton gauche)        -> CHOISIR ses robots (remplace la sélection ; zone vide : sélection vidée) ;
        Maj + glisser                  -> MARCHE-ATTAQUE des robots choisis vers le centre de la zone ;
        glisser avec le bouton droit   -> ATTAQUER ce qui est encadré (ennemis : centre de gravité, rayon de leur étalement) ;
        Maj + bouton droit             -> ALLER au centre de la zone (les robots ripostent en route).
      Vue carte : la zone est celle du moteur (chart_selection_color) ; le CLIC sans glisser donne une zone nulle ou petite : le
      rayon minimal (Ro.MIN_ZONE) s'applique, ce qui est le même résultat (RB0 E6 : non prouvé par le banc, jamais joué).
    - Outil de ralliement `Ro.TOOL_RALLY` (mis en main par le bouton du panneau de l'atelier) : un clic ou un glisser fixe le
      ralliement de l'atelier qui l'a demandé (une seule fois : l'outil est ensuite rendu).
    - Dessin : les robots choisis sont cerclés ; le ralliement d'un atelier se voit quand on le survole ou qu'on place l'outil.
    - Alerte de pertes : une alerte du moteur (au plus une par Ro.ALERT_COOLDOWN ticks et par force), puis un bilan écrit.
  Les unités d'une FACTION n'obéissent pas au joueur (Ordres.order). Aucune décision ne dépend de la souris autrement que par
  les événements ci-dessus, que le moteur synchronise et rejoue au même tick chez tous les joueurs ; aucun `pairs` dans une décision ;
  l'état (sélection, atelier en attente, pertes) est dans global.fo.robots, en nombres. Réglage maître éteint : rien n'est ordonné.
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Armee = require("script.robots.armee")
local Ordres = require("script.robots.ordres")
local Usine = require("script.robots.usine")
local Ro = require("shared.content.robots")
local Cm = require("shared.robots.commande")

local Outils = {}

local DRAW_PERIOD = 30
local DRAW_TTL = 35
local TARGET_TYPES = { "unit", "unit-spawner", "turret", "spider-vehicle" } -- comme reverse_entity_type_filters du prototype

---------------------------------------------------------------------------------------------------
-- Sélection
---------------------------------------------------------------------------------------------------
--- Numéros d'unité choisis par un joueur, purgés des morts (écrit la purge). Rend la liste triée.
function Outils.selection(player_index)
  local sel = Armee.table_of("sel")
  if not sel then return {} end
  local kept = Cm.purge(sel[player_index] or {}, function(n) return Armee.commandable_entity(n) ~= nil end) -- lot BOURDON-SORTIE : Bourdon compris
  if sel[player_index] then sel[player_index] = kept end
  return kept
end

--- Remplace la sélection d'un joueur par ces numéros (triés, sans doublon, bornés). Rend la sélection.
function Outils.choose(player_index, numbers)
  local sel = Armee.table_of("sel")
  if not sel then return {} end
  sel[player_index] = Cm.choose(numbers)
  return sel[player_index]
end

--- Numéros des robots commandables de `force` parmi des entités (inscrits au registre, ou le Bourdon : lot BOURDON-SORTIE).
local function robots_of(force, entities)
  local out = {}
  for _, e in ipairs(entities or {}) do
    if e.valid and e.unit_number and e.force == force and Armee.commandable(e) then out[#out + 1] = e.unit_number end
  end
  return out
end

--- Tous les robots inscrits d'une force (liste triée).
function Outils.all_of(force)
  local s = Armee.S()
  if not s then return {} end
  local out = {}
  for _, un in ipairs(s.ledger.order) do
    if s.ledger.units[un].force == force.name and Armee.entity(un) then out[#out + 1] = un end
  end
  return out
end

local function entities_of(numbers)
  local out = {}
  for _, n in ipairs(numbers) do
    local e = Armee.commandable_entity(n)
    if e then out[#out + 1] = e end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Ordres
---------------------------------------------------------------------------------------------------
local function say(player, key, ...)
  player.print({ "fo-robots." .. key, ... })
end

--- Ordre `kind` ("move" ou "attack") à la sélection d'un joueur. Rend (ordonnés, raison du refus ou nil).
function Outils.order_selection(player, kind, pos, radius)
  local force = player.force
  local numbers = Outils.selection(player.index)
  if #numbers == 0 then return 0, "aucun robot choisi" end
  local ents = entities_of(numbers)
  local n, why = Ordres.order(force, ents, kind, pos, radius)
  return n, why
end

--- « Tous au ralliement » : chaque robot du joueur va au ralliement de son atelier d'origine. Rend (envoyés, sans destination).
function Outils.all_to_rally(player)
  local s = Armee.S()
  if not (s and Armee.enabled()) then return 0, 0 end
  local force = player.force
  if State.by_force(force.name) then return 0, 0 end
  local rallies, first = Usine.rallies(force.name)
  local plan, skipped = Cm.rally_all(Outils.all_of(force), s.ledger.units, rallies, first)
  local sent = 0
  for _, step in ipairs(plan) do
    local e = Armee.entity(step.unit)
    if e and Armee.send(e, "move", { x = step.x, y = step.y }, 3) then sent = sent + 1 end
  end
  s.stats.orders = s.stats.orders + 1
  s.stats.ordered = s.stats.ordered + sent
  log(string.format("[FO-ROBOTS] ordre rally force=%s : %d unite(s) au ralliement (%d sans destination)", force.name, sent, skipped))
  return sent, skipped
end

---------------------------------------------------------------------------------------------------
-- Événements des outils
---------------------------------------------------------------------------------------------------
local function rally_event(player, e)
  local pending = Armee.table_of("rally_for")
  local w = pending and pending[player.index]
  local c = Cm.center(e.area)
  if not (w and c) then return end
  local rec = Usine.record(w)
  if not (rec and rec.e.force == player.force) then
    pending[player.index] = nil
    return
  end
  Usine.set_rally(w, c.x, c.y)
  pending[player.index] = nil
  player.clear_cursor()
  log(string.format("[FO-ROBOTS] ralliement atelier=%d force=%s : (%.1f, %.1f)", w, player.force.name, c.x, c.y))
  say(player, "rally-set", string.format("%.0f", c.x), string.format("%.0f", c.y))
end

--- Gestionnaire commun des quatre événements de l'outil d'ordre (`ev` : selected, alt, reverse, alt_reverse).
local function handle(ev, e)
  local player = e.player_index and game.get_player(e.player_index)
  if not (player and player.valid) then return end
  if e.item == Ro.TOOL_RALLY then
    rally_event(player, e)
    return
  end
  if e.item ~= Ro.TOOL_ORDER then return end
  if not Armee.enabled() or State.by_force(player.force.name) then return end
  local action = Cm.action_of(ev)
  if action == "choose" then
    local sel = Outils.choose(player.index, robots_of(player.force, e.entities))
    log(string.format("[FO-ROBOTS] selection joueur=%d : %d robot(s)", player.index, #sel))
    say(player, #sel > 0 and "chosen" or "chosen-none", #sel)
    return
  end
  local kind = Cm.order_of(action)
  if not kind then return end
  local pos, radius
  if action == "strike" then
    local positions = {}
    for _, t in ipairs(e.entities or {}) do
      if t.valid and t.force ~= player.force then positions[#positions + 1] = t.position end
    end
    pos, radius = Cm.strike(e.area, positions)
  else
    pos, radius = Cm.center(e.area), Cm.radius(e.area)
  end
  if not pos then return end
  if kind == "move" then radius = Cm.move_radius(#Outils.selection(player.index)) end
  local n, why = Outils.order_selection(player, kind, pos, radius)
  if n > 0 then
    say(player, kind == "attack" and "ordered-attack" or "ordered-move", n)
  elseif why == "aucun robot choisi" then
    say(player, "none-chosen")
  end
end

Events.on(defines.events.on_player_selected_area, function(e) handle("selected", e) end)
Events.on(defines.events.on_player_alt_selected_area, function(e) handle("alt", e) end)
Events.on(defines.events.on_player_reverse_selected_area, function(e) handle("reverse", e) end)
Events.on(defines.events.on_player_alt_reverse_selected_area, function(e) handle("alt_reverse", e) end)

---------------------------------------------------------------------------------------------------
-- Outils en main
---------------------------------------------------------------------------------------------------
--- Met l'outil d'ordre en main (comme le raccourci). Rend vrai si l'outil est en main.
function Outils.give_order_tool(player)
  if not (player and player.valid and player.cursor_stack) then return false end
  player.clear_cursor()
  return player.cursor_stack.set_stack({ name = Ro.TOOL_ORDER, count = 1 })
end

--- Met l'outil de ralliement en main pour l'atelier `workshop` (le prochain clic fixe son ralliement). Rend vrai si c'est fait.
function Outils.give_rally_tool(player, workshop)
  if not (player and player.valid and player.cursor_stack) then return false end
  local rec = Usine.record(workshop)
  local pending = Armee.table_of("rally_for")
  if not (rec and pending) then return false end
  player.clear_cursor()
  if not player.cursor_stack.set_stack({ name = Ro.TOOL_RALLY, count = 1 }) then return false end
  pending[player.index] = workshop
  return true
end

---------------------------------------------------------------------------------------------------
-- Dessin : robots choisis, ralliement d'un atelier
---------------------------------------------------------------------------------------------------
local GREEN = { r = 0.3, g = 1, b = 0.3, a = 0.9 }
local AMBER = { r = 1, g = 0.75, b = 0.2, a = 0.95 }

local function draw_rally(player, rec)
  local from, to = rec.e.position, Usine.rally_of(rec)
  local surface = rec.e.surface
  rendering.draw_line({ color = AMBER, width = 2, from = from, to = to, surface = surface, time_to_live = DRAW_TTL,
    players = { player }, dash_length = 0.5, gap_length = 0.5 })
  rendering.draw_circle({ color = AMBER, radius = 1.5, width = 3, filled = false, target = to, surface = surface,
    time_to_live = DRAW_TTL, players = { player } })
end

local function draw_all()
  if not Armee.enabled() then return end
  local s = Armee.S()
  if not s then return end
  for _, player in ipairs(game.connected_players) do
    local sel = Outils.selection(player.index)
    for _, n in ipairs(sel) do
      local u = Armee.commandable_entity(n)
      if u then
        -- cercle à la taille du robot : 0,9 pour une unité, 2,5 pour une araignée (géants, Bourdon)
        rendering.draw_circle({ color = GREEN, radius = u.type == "spider-vehicle" and 2.5 or 0.9, width = 2, filled = false, target = u, surface = u.surface,
          time_to_live = DRAW_TTL, players = { player } })
      end
    end
    local shown
    local sel_ent = player.selected
    if sel_ent and sel_ent.valid and sel_ent.unit_number and Ro.is_workshop(sel_ent.name) and sel_ent.force == player.force then
      shown = Usine.record(sel_ent.unit_number)
    end
    local pending = s.rally_for and s.rally_for[player.index]
    if pending then shown = Usine.record(pending) or shown end
    if shown then draw_rally(player, shown) end
  end
end

Events.on_nth_tick(DRAW_PERIOD, draw_all)

---------------------------------------------------------------------------------------------------
-- Alerte de pertes
---------------------------------------------------------------------------------------------------
Events.on(defines.events.on_entity_died, function(e)
  local u = e.entity
  if not (u and u.valid and (u.type == "unit" or u.type == "spider-vehicle")) then return end
  local owner, id = Ro.parse_unit(u.name)
  if owner ~= Ro.PLAYER_OWNER then return end -- les pertes d'une faction ne sont pas votre affaire
  local alerts = Armee.table_of("alerts")
  if not alerts then return end
  local force = u.force
  local st = alerts[force.name]
  if not st then
    st = Cm.new_loss()
    alerts[force.name] = st
  end
  if Cm.loss_note(st, e.tick, u.position.x, u.position.y) then
    local s = Armee.S()
    s.stats.alerts = (s.stats.alerts or 0) + 1
    for _, p in ipairs(force.connected_players) do
      p.add_custom_alert(u, { type = "item", name = Ro.robot(id).kit }, { "fo-robots.alert-loss", { "fo-robots.name-" .. id } }, true)
    end
  end
end)

--- Bilan des salves de pertes terminées (liste triée des forces).
local function flush_losses(ev)
  local alerts = Armee.table_of("alerts")
  if not alerts then return end
  local names = {}
  for name in pairs(alerts) do names[#names + 1] = name end -- trié juste après
  table.sort(names)
  for _, name in ipairs(names) do
    local n, x, y = Cm.loss_flush(alerts[name], ev.tick)
    local force = game.forces[name]
    if n and force then
      local s = Armee.S()
      s.stats.loss_notes = (s.stats.loss_notes or 0) + 1
      force.print({ "fo-robots.loss-summary", n, string.format("%.0f", x), string.format("%.0f", y) })
      log(string.format("[FO-ROBOTS] bilan des pertes force=%s : %d robot(s) vers (%.0f, %.0f)", name, n, x, y))
    end
  end
end

Events.on_nth_tick(60, flush_losses)

---------------------------------------------------------------------------------------------------
-- Interface distante « fo-robots-ui » (bancs) : rejoue les événements des outils avec les données que le moteur leur donne
-- (zone, entités filtrées par le mode de l'outil) : le gestionnaire est le MÊME ; seul le tirage de la souris manque (RB0 E6).
---------------------------------------------------------------------------------------------------
local function filtered(surface, area, force, enemy)
  local box = { { area.x0, area.y0 }, { area.x1, area.y1 } }
  if not enemy then
    return surface.find_entities_filtered({ area = box, force = force, type = { "unit", "spider-vehicle" } })
  end
  local foes = {}
  local names = {}
  for name in pairs(game.forces) do names[#names + 1] = name end -- trié juste après
  table.sort(names)
  for _, name in ipairs(names) do
    if force.is_enemy(game.forces[name]) then foes[#foes + 1] = name end
  end
  if #foes == 0 then return {} end
  return surface.find_entities_filtered({ area = box, force = foes, type = TARGET_TYPES })
end

remote.add_interface("fo-robots-ui", {
  --- Événement d'un outil : ev (selected, alt, reverse, alt_reverse), item (nom de l'outil), zone x0, y0, x1, y1.
  tool = function(player_index, ev, item, x0, y0, x1, y1)
    local player = game.get_player(player_index)
    if not player then return false end
    local box = { left_top = { x = x0, y = y0 }, right_bottom = { x = x1, y = y1 } }
    local area = Cm.area(box)
    local enemy = (ev == "reverse")
    local ents = (ev == "selected" or ev == "reverse") and filtered(player.surface, area, player.force, enemy) or {}
    handle(ev, { player_index = player_index, item = item, area = box, entities = ents, surface = player.surface })
    return true
  end,
  selection = function(player_index) return Outils.selection(player_index) end,
  rally_pending = function(player_index)
    local pending = Armee.table_of("rally_for")
    return pending and pending[player_index] or nil
  end,
  give_order_tool = function(player_index)
    local player = game.get_player(player_index)
    return player ~= nil and Outils.give_order_tool(player)
  end,
  give_rally_tool = function(player_index, workshop)
    local player = game.get_player(player_index)
    return player ~= nil and Outils.give_rally_tool(player, workshop)
  end,
  cursor = function(player_index)
    local player = game.get_player(player_index)
    local c = player and player.cursor_stack
    return c and c.valid_for_read and c.name or nil
  end,
  all_to_rally = function(player_index)
    local player = game.get_player(player_index)
    if not player then return nil end
    local sent, skipped = Outils.all_to_rally(player)
    return { sent = sent, skipped = skipped }
  end,
  --- Lecture des compteurs d'alertes (bancs) : { alerts, loss_notes }.
  alerts = function()
    local s = Armee.S()
    return { alerts = s and s.stats.alerts or 0, loss_notes = s and s.stats.loss_notes or 0 }
  end,
})

return Outils
