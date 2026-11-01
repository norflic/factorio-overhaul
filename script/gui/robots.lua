--[[
  Lot RB-2 JOUEUR (1/11) : l'INTERFACE des robots. Règles pures : shared/robots/modele.lua et commande.lua ; état : global.fo.robots.

  Deux surfaces, aucune seconde logique (chaque bouton appelle la fonction que les outils et l'interface distante appellent aussi) :
    - Panneau de l'ATELIER (gui.relative, à droite de l'interface de la machine, ancré aux seuls ateliers de robots) : par robot,
      « Maintenir N » (− / + / ∞), ordre dans la file (▲ ▼, visibles à partir de deux entrées), et le RALLIEMENT de l'atelier :
      « Choisir sur la carte » (met l'outil de ralliement en main), « Ici » (à votre position), « Par défaut ».
      Une seule entrée de file est un simple « Maintenir N » ; la file n'impose la recette qu'à partir de deux entrées (ou à un
      atelier sans recette) : voir Mo.recipe_wanted.
    - Onglet « Armée » de la fenêtre « Équipe et factions » (script/gui/team_window.lua) : points et plafond, effectifs par robot,
      ateliers et leurs ralliements, robots choisis, pertes ; boutons « Prendre l'outil d'ordre », « Choisir tous mes robots »,
      « Désélectionner », « Tous au ralliement ». Les boutons sont dans la partie FIXE de l'onglet (jamais refaits pendant un clic) ;
      les chiffres dans la partie vivante (refaite chaque seconde).
  Déterminisme : l'interface LIT l'état ; elle n'écrit que par les fonctions de script/robots/ appelées depuis on_gui_click (action
  d'un joueur que le moteur synchronise) ; aucune lecture locale ; aucun `pairs`. Réglage maître éteint : les boutons ne font rien.
]]

local Events = require("script.core.events")
local Armee = require("script.robots.armee")
local Usine = require("script.robots.usine")
local Outils = require("script.robots.outils")
local Ro = require("shared.content.robots")
local Mo = require("shared.robots.modele")

local Gui = {}

local P = "fo_rb_"
local PANEL = "fo_rb_panel"
local GREY = { r = 0.62, g = 0.62, b = 0.62 }
local GOOD = { r = 0.55, g = 0.95, b = 0.55 }
local WARN = { r = 1, g = 0.7, b = 0.3 }

local refresh_window = function() end -- rempli par la fenêtre (Gui.set_refresh) : refait l'onglet après une action

function Gui.set_refresh(fn) refresh_window = fn end

local function fmt(x) return string.format("%.0f", x) end

local function robot_name(id) return { "fo-robots.name-" .. id } end

---------------------------------------------------------------------------------------------------
-- Panneau de l'atelier
---------------------------------------------------------------------------------------------------
local function workshop_names()
  local out = {}
  for _, w in ipairs(Ro.WORKSHOPS) do out[#out + 1] = w.name end
  return out
end

local function small_button(parent, name, caption, tooltip)
  local b = parent.add({ type = "button", name = name, caption = caption, tooltip = tooltip })
  b.style.minimal_width = 28
  b.style.maximal_width = 36
  b.style.height = 28
  b.style.padding = 0
  return b
end

local function build_panel(player)
  local root = player.gui.relative
  local f = root[PANEL]
  if f and f.valid then return f end
  f = root.add({ type = "frame", name = PANEL, direction = "vertical", caption = { "fo-robots-ui.panel-title" },
    anchor = { gui = defines.relative_gui_type.assembling_machine_gui, position = defines.relative_gui_position.right,
      names = workshop_names() } })
  local army = f.add({ type = "label", name = P .. "army" })
  army.style.single_line = false
  army.style.maximal_width = 300
  for _, r in ipairs(Ro.ROBOTS) do
    local row = f.add({ type = "flow", name = P .. "row_" .. r.id, direction = "vertical" })
    row.style.top_margin = 4
    row.add({ type = "label", name = P .. "have_" .. r.id, style = "bold_label" })
    local keep = row.add({ type = "flow", name = P .. "keep_" .. r.id, direction = "horizontal" })
    keep.style.vertical_align = "center"
    keep.style.horizontal_spacing = 4
    keep.add({ type = "label", caption = { "fo-robots-ui.keep" }, tooltip = { "fo-robots-ui.keep-tip" } })
    small_button(keep, P .. "dec_" .. r.id, "-", { "fo-robots-ui.dec" })
    local val = keep.add({ type = "label", name = P .. "val_" .. r.id })
    val.style.minimal_width = 36
    val.style.horizontal_align = "center"
    small_button(keep, P .. "inc_" .. r.id, "+", { "fo-robots-ui.inc" })
    small_button(keep, P .. "inf_" .. r.id, "∞", { "fo-robots-ui.inf" })
    small_button(keep, P .. "up_" .. r.id, "▲", { "fo-robots-ui.up" })
    small_button(keep, P .. "dn_" .. r.id, "▼", { "fo-robots-ui.down" })
  end
  f.add({ type = "line", direction = "horizontal" })
  local rally = f.add({ type = "label", name = P .. "rally", style = "bold_label" })
  rally.style.single_line = false
  rally.style.maximal_width = 300
  local btns = f.add({ type = "flow", name = P .. "rally_btns", direction = "vertical" })
  btns.add({ type = "button", name = P .. "rally_pick", caption = { "fo-robots-ui.rally-pick" }, tooltip = { "fo-robots-ui.rally-pick-tip" } })
  local two = btns.add({ type = "flow", direction = "horizontal" })
  two.add({ type = "button", name = P .. "rally_here", caption = { "fo-robots-ui.rally-here" }, tooltip = { "fo-robots-ui.rally-here-tip" } })
  two.add({ type = "button", name = P .. "rally_reset", caption = { "fo-robots-ui.rally-reset" }, tooltip = { "fo-robots-ui.rally-reset-tip" } })
  local note = f.add({ type = "label", name = P .. "note", caption = { "fo-robots-ui.panel-note" } })
  note.style.single_line = false
  note.style.maximal_width = 300
  note.style.font_color = GREY
  return f
end

--- Atelier ouvert par un joueur (nil sinon).
local function opened_workshop(player)
  local ent = player.opened
  if ent and player.opened_gui_type == defines.gui_type.entity and ent.valid and ent.object_name == "LuaEntity"
      and Ro.is_workshop(ent.name) then
    return ent
  end
  return nil
end

--- Remplit le panneau depuis l'état (captions et visibilités seulement : aucun élément refait, donc aucun clic perdu).
local function fill_panel(player, ent)
  local f = build_panel(player)
  local rec = Usine.record(ent.unit_number)
  local force = ent.force
  f.visible = rec ~= nil
  if not rec then return end
  f[P .. "army"].caption = { "fo-robots-ui.army", Armee.used(force.name), Armee.cap(force), Armee.age(force) }
  local mine = {}
  for _, r in ipairs(Ro.robots_of(ent.name)) do mine[r.id] = true end
  local queue = rec.queue or {}
  for _, r in ipairs(Ro.ROBOTS) do
    local row = f[P .. "row_" .. r.id]
    row.visible = mine[r.id] == true
    if mine[r.id] then
      row[P .. "have_" .. r.id].caption = { "fo-robots-ui.have", robot_name(r.id), Armee.have(force.name, r.id) }
      local target = Mo.queue_target(queue, r.id)
      local keep = row[P .. "keep_" .. r.id]
      keep[P .. "val_" .. r.id].caption = target and tostring(target) or { "fo-robots-ui.unlimited" }
      keep[P .. "val_" .. r.id].style.font_color = target and GOOD or GREY
      keep[P .. "up_" .. r.id].visible = #queue >= 2 and target ~= nil
      keep[P .. "dn_" .. r.id].visible = #queue >= 2 and target ~= nil
    end
  end
  local p = Usine.rally_of(rec)
  f[P .. "rally"].caption = rec.rally and { "fo-robots-ui.rally-set", fmt(p.x), fmt(p.y) } or { "fo-robots-ui.rally-default", fmt(p.x), fmt(p.y) }
  f[P .. "rally_btns"][P .. "rally_reset"].enabled = rec.rally ~= nil
end

local function on_workshop_gui(e)
  local player = game.get_player(e.player_index)
  if not player then return end
  local ent = opened_workshop(player)
  if ent then
    fill_panel(player, ent)
  else
    local root = player.gui and player.gui.relative -- le moteur simulé des bancs hors jeu n'a pas d'interface relative
    local f = root and root[PANEL]
    if f and f.valid then f.visible = false end
  end
end
Events.on(defines.events.on_gui_opened, on_workshop_gui)
Events.on(defines.events.on_gui_closed, on_workshop_gui)

-- Les chiffres bougent pendant que la machine est ouverte (robots créés, perdus) : une fois par seconde, les joueurs concernés.
Events.on_nth_tick(60, function()
  if not Armee.enabled() then return end
  for _, player in ipairs(game.connected_players) do
    local ent = opened_workshop(player)
    if ent then fill_panel(player, ent) end
  end
end)

---------------------------------------------------------------------------------------------------
-- Onglet « Armée » de la fenêtre « Équipe et factions »
---------------------------------------------------------------------------------------------------
function Gui.tab(H)
  local def = {}

  def.sig = function() return Armee.enabled() and "on" or "off" end

  def.fixed = function(c, player)
    H.label(c, { "fo-robots-ui.tab-intro" }, { color = GREY })
    if not Armee.enabled() then
      H.label(c, { "fo-robots-ui.off" }, { color = WARN })
      return
    end
    local row = c.add({ type = "flow", direction = "horizontal" })
    row.style.horizontal_spacing = 6
    row.style.top_margin = 6
    row.add({ type = "button", name = P .. "army_tool", caption = { "fo-robots-ui.army-tool" }, tooltip = { "fo-robots-ui.army-tool-tip" },
      style = "green_button" })
    row.add({ type = "button", name = P .. "army_all", caption = { "fo-robots-ui.army-all" }, tooltip = { "fo-robots-ui.army-all-tip" } })
    row.add({ type = "button", name = P .. "army_none", caption = { "fo-robots-ui.army-none" }, tooltip = { "fo-robots-ui.army-none-tip" } })
    row.add({ type = "button", name = P .. "army_rally", caption = { "fo-robots-ui.army-rally" }, tooltip = { "fo-robots-ui.army-rally-tip" } })
    H.heading(c, { "fo-robots-ui.keys-title" })
    for _, k in ipairs({ "key-choose", "key-attack", "key-strike", "key-move" }) do
      H.label(c, { "fo-robots-ui." .. k }, { color = GREY })
    end
  end

  def.live = function(c, player)
    if not Armee.enabled() then return end
    local s = Armee.S()
    local force = player.force
    if not s then return end
    H.heading(c, { "fo-robots-ui.army-title" })
    H.label(c, { "fo-robots-ui.army", Armee.used(force.name), Armee.cap(force), Armee.age(force) }, { font = "default-bold" })
    local tbl = c.add({ type = "table", column_count = 3, draw_horizontal_line_after_headers = true })
    tbl.style.horizontal_spacing = 24
    tbl.style.top_margin = 4
    for _, k in ipairs({ "col-robot", "col-alive", "col-points" }) do
      tbl.add({ type = "label", caption = { "fo-robots-ui." .. k }, style = "bold_label" })
    end
    for _, r in ipairs(Ro.ROBOTS) do
      tbl.add({ type = "label", caption = robot_name(r.id) })
      tbl.add({ type = "label", caption = tostring(Armee.have(force.name, r.id)) })
      tbl.add({ type = "label", caption = tostring(r.points) })
    end
    local sel = Outils.selection(player.index)
    H.label(c, { #sel > 0 and "fo-robots-ui.selected" or "fo-robots-ui.selected-none", #sel },
      { color = #sel > 0 and GOOD or GREY })
    H.heading(c, { "fo-robots-ui.workshops-title" })
    local shown = 0
    for _, un in ipairs(s.list) do
      local rec = s.factories[un]
      if rec and rec.e and rec.e.valid and rec.e.force == force then
        shown = shown + 1
        if shown <= 8 then
          local pos, p = rec.e.position, Usine.rally_of(rec)
          local queue = {}
          for _, q in ipairs(rec.queue or {}) do queue[#queue + 1] = { "", robot_name(q.id), " x", tostring(q.n), " " } end
          H.label(c, { "fo-robots-ui.workshop-line", fmt(pos.x), fmt(pos.y), fmt(p.x), fmt(p.y),
            #queue > 0 and { "", table.unpack(queue) } or { "fo-robots-ui.unlimited" } })
        end
      end
    end
    if shown == 0 then H.label(c, { "fo-robots-ui.workshops-none" }, { color = GREY }) end
    if shown > 8 then H.label(c, { "fo-robots-ui.workshops-more", shown - 8 }, { color = GREY }) end
    H.heading(c, { "fo-robots-ui.history-title" })
    H.label(c, { "fo-robots-ui.history", s.stats.created, s.stats.lost, s.stats.ordered })
  end

  return def
end

---------------------------------------------------------------------------------------------------
-- Clics
---------------------------------------------------------------------------------------------------
local function with_workshop(player, fn)
  local ent = opened_workshop(player)
  if not ent then return end
  fn(ent)
  fill_panel(player, ent)
end

--- Un clic sur un bouton du lot (prefixe « fo_rb_ »). Rend vrai si le clic était à nous.
function Gui.click(player, name)
  if name:sub(1, #P) ~= P then return false end
  local what, id = name:match("^fo_rb_(%a+)_([%w%-]+)$")
  if what and id and Ro.robot(id) and (what == "dec" or what == "inc" or what == "inf" or what == "up" or what == "dn") then
    with_workshop(player, function(ent)
      local rec = Usine.record(ent.unit_number)
      if not rec then return end
      local cur = Mo.queue_target(rec.queue, id)
      if what == "inc" then
        Usine.set_target(ent.unit_number, id, (cur or 0) + 1)
      elseif what == "dec" then
        if cur then Usine.set_target(ent.unit_number, id, math.max(0, cur - 1)) end
      elseif what == "inf" then
        Usine.set_target(ent.unit_number, id, nil)
      elseif what == "up" then
        Usine.move_target(ent.unit_number, id, -1)
      else
        Usine.move_target(ent.unit_number, id, 1)
      end
    end)
    return true
  end
  if name == P .. "rally_pick" then
    with_workshop(player, function(ent) Outils.give_rally_tool(player, ent.unit_number) end)
  elseif name == P .. "rally_here" then
    with_workshop(player, function(ent)
      Usine.set_rally(ent.unit_number, player.position.x, player.position.y)
    end)
  elseif name == P .. "rally_reset" then
    with_workshop(player, function(ent) Usine.set_rally(ent.unit_number) end)
  elseif name == P .. "army_tool" then
    Outils.give_order_tool(player)
  elseif name == P .. "army_all" then
    if Armee.enabled() then Outils.choose(player.index, Outils.all_of(player.force)) end
    refresh_window(player)
  elseif name == P .. "army_none" then
    Outils.choose(player.index, {})
    refresh_window(player)
  elseif name == P .. "army_rally" then
    Outils.all_to_rally(player)
    refresh_window(player)
  else
    return false
  end
  return true
end

Events.on(defines.events.on_gui_click, function(e)
  local el = e.element
  if not (el and el.valid) then return end
  local player = game.get_player(e.player_index)
  if player then Gui.click(player, el.name) end
end)

---------------------------------------------------------------------------------------------------
-- Interface distante « fo-robots-gui » (bancs et captures) : cliquer un bouton par son nom (même fonction que le clic), ouvrir un
-- atelier, lire le panneau.
---------------------------------------------------------------------------------------------------
local function find(el, name)
  for _, ch in ipairs(el.children) do
    if ch.name == name then return ch end
    local r = find(ch, name)
    if r then return r end
  end
  return nil
end

local function caption_text(el)
  local cap = el.caption
  if type(cap) == "table" then return cap[1] end
  return cap
end

remote.add_interface("fo-robots-gui", {
  --- Ouvre l'interface d'un atelier pour un joueur (bancs : comme un clic sur la machine).
  open = function(player_index, workshop)
    local player = game.get_player(player_index)
    local rec = Usine.record(workshop)
    if not (player and rec) then return false end
    player.opened = rec.e
    on_workshop_gui({ player_index = player_index })
    return true
  end,
  close = function(player_index)
    local player = game.get_player(player_index)
    if not player then return false end
    player.opened = nil
    on_workshop_gui({ player_index = player_index })
    return true
  end,
  --- Clique un bouton du lot par son nom (panneau de l'atelier, onglet « Armée » : cherché dans les deux).
  click = function(player_index, name)
    local player = game.get_player(player_index)
    if not player then return false end
    return Gui.click(player, name)
  end,
  --- Lecture du panneau d'atelier : { visible, army, rally, keys = { [robot] = valeur affichée }, ups = { [robot] = visible } }.
  panel = function(player_index)
    local player = game.get_player(player_index)
    local f = player and player.gui.relative[PANEL]
    if not (f and f.valid) then return nil end
    local out = { visible = f.visible, army = caption_text(f[P .. "army"]), rally = caption_text(f[P .. "rally"]), keys = {}, ups = {} }
    for _, r in ipairs(Ro.ROBOTS) do
      local val = f[P .. "row_" .. r.id][P .. "keep_" .. r.id][P .. "val_" .. r.id]
      out.keys[r.id] = type(val.caption) == "table" and "inf" or val.caption
      out.ups[r.id] = f[P .. "row_" .. r.id][P .. "keep_" .. r.id][P .. "up_" .. r.id].visible
    end
    return out
  end,
  --- Montre un élément nommé de l'interface (existence), partout sous l'écran et le relatif du joueur.
  has = function(player_index, name)
    local player = game.get_player(player_index)
    if not player then return false end
    return (find(player.gui.relative, name) or find(player.gui.screen, name)) ~= nil
  end,
})

return Gui
