--[[
  Niveaux : panneau « Évolution » et touche U (session 5).

  Survoler un bâtiment à niveaux affiche (et garde affiché) son panneau : niveau et matériau, prochain
  niveau, gains de statistiques, coût (ce que vous avez / ce qu'il faut), durée, ouvriers libres, raison
  d'un refus (centre de commandement trop bas…). Bouton « Améliorer » ou touche U sur le bâtiment survolé.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local L = require("shared.levels.config")
local Levels = require("script.levels.levels")

local FRAME = "fo_lvl_panel"

Storage.declare("levels_ui", function() return { target = {}, unit = {} } end)
local function UI() return Storage.ns("levels_ui") end

---------------------------------------------------------------------------------------------------
-- Statistiques lues dans les prototypes (une seule source de vérité : l'étape data)
---------------------------------------------------------------------------------------------------
local function stat_value(proto, key)
  if key == "max_health" then return proto.max_health end
  if key == "damage_modifier" then return proto.attack_parameters and proto.attack_parameters.damage_modifier end
  if key == "range" then return proto.attack_parameters and proto.attack_parameters.range end
  if key == "mining_speed" then return proto.mining_speed end
  if key == "crafting_speed" then return proto.crafting_speed end
  if key == "energy_usage" then return proto.energy_usage and proto.energy_usage * 60 end
  if key == "inventory_size" then return proto.get_inventory_size(defines.inventory.chest) end
  return nil
end

local function fmt(key, v)
  if v == nil then return "—" end
  if key == "max_health" or key == "inventory_size" then return string.format("%d", math.floor(v + 0.5)) end
  if key == "damage_modifier" then return string.format("×%.2f", v) end
  if key == "range" then return string.format("%.2f", v) end
  if key == "energy_usage" then return string.format("%.0f kW", v / 1000) end
  return string.format("%.3g", v)
end

local function missing_text(list)
  local parts = {}
  for _, m in ipairs(list) do parts[#parts + 1] = "[item=" .. m[1] .. "]×" .. m[2] end
  return table.concat(parts, " ")
end

local function reason_message(info, reason)
  if reason == "cc-too-low" and info then return { "fo-levels.reason-cc-too-low", info.next - 1 } end
  if reason == "no-builder" and info then return { "fo-levels.reason-no-builder", info.builders } end
  if reason == "no-resources" and info then return { "fo-levels.reason-no-resources", missing_text(info.missing or {}) } end
  return { "fo-levels.reason-" .. tostring(reason) }
end

---------------------------------------------------------------------------------------------------
-- Panneau
---------------------------------------------------------------------------------------------------
local function set_target(player, entity)
  UI().target[player.index] = entity
  UI().unit[player.index] = entity and entity.unit_number or nil
end

local function close(player)
  local f = player.gui.left[FRAME]
  if f then f.destroy() end
  set_target(player, nil)
end

local function refresh(player)
  local target = UI().target[player.index]
  if not (target and target.valid) then
    close(player)
    return
  end
  local info = Levels.preview(target, player)
  if not info then
    close(player)
    return
  end
  local frame = player.gui.left[FRAME]
  if frame then frame.clear() else
    frame = player.gui.left.add({ type = "frame", name = FRAME, direction = "vertical", caption = { "fo-levels.panel-title" } })
  end
  local family, n = info.family, info.level
  local head = frame.add({ type = "flow", direction = "horizontal" })
  head.add({ type = "sprite", sprite = "entity/" .. target.name })
  local title = head.add({ type = "label", caption = target.localised_name })
  title.style.font = "default-bold"
  frame.add({ type = "label", caption = { "fo-levels.material-line", n, { "fo-levels.material-" .. L.materials[n].key } } })
  local ccl = info.cc_level
  frame.add({ type = "label", caption = { "fo-levels.cc-line", ccl, L.max_level(family, ccl), L.builders(ccl) } })

  if info.job then
    local job = info.job
    local p = math.min(1, (game.tick - job.start) / math.max(1, job.finish - job.start))
    local bar = frame.add({ type = "progressbar", value = p })
    bar.style.horizontally_stretchable = true
    frame.add({ type = "label", caption = { "fo-levels.in-progress", job.to, Levels.fmt_time(job.finish - game.tick) } })
  elseif n >= L.MAX then
    frame.add({ type = "label", caption = { "fo-levels.maxed" } })
  else
    frame.add({ type = "label", caption = { "fo-levels.next", info.next, { "fo-levels.material-" .. L.materials[info.next].key } } })
    local now = game.entity_prototypes[target.name]
    local nxt = game.entity_prototypes[L.name(family, info.next)]
    for _, st in ipairs(family.stats) do
      local key = st.path[#st.path]
      if key ~= "rotation_speed" then
        frame.add({ type = "label", caption = { "fo-levels.stat-line", { "fo-levels.stat-" .. key },
          fmt(key, stat_value(now, key)), fmt(key, stat_value(nxt, key)) } })
      end
    end
    frame.add({ type = "label", caption = { "fo-levels.cost" } })
    local invs = Levels.sources(target.force, player)
    local tbl = frame.add({ type = "table", column_count = 3 })
    for _, c in ipairs(info.cost) do
      local have = Levels.available(invs, c[1])
      local lbl = tbl.add({ type = "label", caption = "[item=" .. c[1] .. "] " .. math.min(have, c[2]) .. " / " .. c[2] })
      lbl.style.font_color = have >= c[2] and { r = 0.6, g = 1, b = 0.6 } or { r = 1, g = 0.45, b = 0.4 }
    end
    if info.ticks > 0 then
      frame.add({ type = "label", caption = { "fo-levels.duration", Levels.fmt_time(info.ticks) } })
      frame.add({ type = "label", caption = { "fo-levels.builders", math.max(0, info.builders - info.busy), info.builders } })
    else
      frame.add({ type = "label", caption = { "fo-levels.instant" } })
    end
    if not info.ok then
      local r = frame.add({ type = "label", caption = reason_message(info, info.reason) })
      r.style.font_color = { r = 1, g = 0.6, b = 0.3 }
    end
    local row = frame.add({ type = "flow", direction = "horizontal" })
    local b = row.add({ type = "button", name = "fo_lvl_up", caption = { "fo-levels.upgrade" }, style = "confirm_button" })
    b.enabled = info.ok
    if family.instant then row.add({ type = "button", name = "fo_lvl_row", caption = { "fo-levels.upgrade-row" } }) end
  end
  frame.add({ type = "button", name = "fo_lvl_close", caption = { "fo-levels.close" } })
end

local function try_upgrade(player, entity, row)
  if not (entity and entity.valid) then return end
  local where = entity.position
  if row then
    local done = Levels.start_row(entity, player)
    player.create_local_flying_text({ text = { "fo-levels.msg-row", done }, position = where })
    return
  end
  local ok, reason, info = Levels.start(entity, player)
  local text
  if ok and reason == "started" then
    text = { "fo-levels.msg-started", info.next, Levels.fmt_time(info.ticks) }
  elseif ok then
    text = { "fo-levels.msg-done", info.next }
  else
    text = reason_message(info, reason)
  end
  player.create_local_flying_text({ text = text, position = where })
end

---------------------------------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------------------------------
Events.on(defines.events.on_selected_entity_changed, function(e)
  local player = game.get_player(e.player_index)
  local sel = player and player.selected
  if not (sel and L.parse(sel.name)) then return end
  if UI().target[player.index] == sel then return end
  set_target(player, sel)
  refresh(player)
end)

Events.on("fo-level-up", function(e)
  local player = game.get_player(e.player_index)
  local sel = player and player.selected
  if not (sel and L.parse(sel.name)) then return end
  set_target(player, sel)
  try_upgrade(player, sel, false)
  refresh(player)
end)

Events.on(defines.events.on_gui_click, function(e)
  local el = e.element
  if not (el and el.valid) then return end
  local name = el.name
  if name ~= "fo_lvl_up" and name ~= "fo_lvl_row" and name ~= "fo_lvl_close" then return end
  local player = game.get_player(e.player_index)
  if name == "fo_lvl_close" then
    close(player)
    return
  end
  local target = UI().target[player.index]
  try_upgrade(player, target, name == "fo_lvl_row")
  refresh(player)
end)

Events.on_nth_tick(30, function()
  local ui = UI()
  for _, player in pairs(game.connected_players) do
    if ui.target[player.index] ~= nil then refresh(player) end
  end
end)

Events.on(defines.events.on_player_left_game, function(e)
  UI().target[e.player_index] = nil
  UI().unit[e.player_index] = nil
end)

-- Après une amélioration, le bâtiment est une NOUVELLE entité : le panneau la suit.
table.insert(Levels.on_replaced, function(old_unit, new)
  local ui = UI()
  for index, unit in pairs(ui.unit) do
    if unit == old_unit then
      ui.target[index] = new
      ui.unit[index] = new.unit_number
    end
  end
end)

return {}
