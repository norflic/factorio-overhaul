--[[
  Niveaux : panneau « Évolution » et touche U (session 5 ; époques : lot V2 ; amélioration instantanée et
  condition du centre : lot V2c).

  Survoler un bâtiment à niveaux affiche (et garde affiché) son panneau : niveau sur le maximum et ÉPOQUE,
  prochain niveau (époque, nouvelle silhouette ou pièce de plus), monnaie de l'époque (avec le matériau voulu
  quand l'objet est un remplaçant provisoire), gains de statistiques, coût (ce que vous avez / ce qu'il
  faut), « amélioration instantanée », raison d'un refus (centre de commandement trop bas…). Sur le CENTRE :
  la condition Q16 (niveau visé et familles qui bloquent). Bouton « Améliorer » ou touche U sur le bâtiment
  survolé : l'amélioration est faite aussitôt.
  Lot V3-T : quand le prochain niveau change d'emprise, une ligne « Taille : 2×2 → 3×3 » et l'état de la place
  (libre, ou ce qui gêne) ; un refus faute de place (« no-room ») le dit avec ce qui bloque. Correction V3-T
  (défauts 2, 7 et 10) : tant que le panneau est ouvert, la place est DESSINÉE au sol pour ce seul joueur, sans
  qu'il ait rien à faire (Levels.draw_room) : le carré retenu en vert (place libre : où ira le bâtiment, et la
  direction si ce n'est pas la position habituelle), ou le contour nécessaire et ce qui le bloque (place
  prise) ; le bouton « Améliorer » reste actif pour ce motif (un clic refuse sans rien payer et redessine le
  contour pour 300 ticks, comme la touche U).
  Lot V3-T3 (Q-T2-1, « QT21 option B ») : quand la place manque, un bouton « Libérer la place » (script/levels/free.lua :
  gêneurs marqués à démonter, fantômes décalés, agrandissement en attente) ; une demande en attente s'affiche (ligne
  bleue) avec un bouton « Annuler l'agrandissement ». Sans clic, rien ne change.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local L = require("shared.levels.config")
local Levels = require("script.levels.levels")
local Free = require("script.levels.free")
local Centre = require("script.levels.centre") -- lot CENTRE-JEU : épave de départ et réparation

local FRAME = "fo_lvl_panel"

-- drawn (correction V3-T) : dernier aperçu de place dessiné pour chaque joueur { unit, free, until_tick }
-- (nombres et booléens seulement, jamais d'identifiant de rendu) ; absent d'une sauvegarde d'avant : créé au
-- premier dessin.
Storage.declare("levels_ui", function() return { target = {}, unit = {}, drawn = {} } end)
local function UI() return Storage.ns("levels_ui") end

--- Période du rafraîchissement du panneau (ticks) : l'aperçu de place dessiné vit jusqu'au rafraîchissement
--- suivant, plus PREVIEW_OVERLAP ticks (jamais d'éclipse entre deux dessins).
local PERIOD = 30
local PREVIEW_OVERLAP = 2

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
  if key == "energy_consumption" then
    local ap = proto.attack_parameters
    return ap and ap.ammo_type and ap.ammo_type.energy_consumption
  end
  return nil
end

local function fmt(key, v)
  if v == nil then return "—" end
  if key == "max_health" or key == "inventory_size" then return string.format("%d", math.floor(v + 0.5)) end
  if key == "damage_modifier" then return string.format("×%.2f", v) end
  if key == "range" then return string.format("%.2f", v) end
  if key == "energy_usage" then return string.format("%.0f kW", v / 1000) end
  if key == "energy_consumption" then return string.format("%.0f kJ", v / 1000) end
  return string.format("%.3g", v)
end

local function missing_text(list)
  local parts = {}
  for _, m in ipairs(list) do parts[#parts + 1] = "[item=" .. m[1] .. "]×" .. m[2] end
  return table.concat(parts, " ")
end

--- Familles qui bloquent le centre (Q16) : « [entity=gun-turret] Mitrailleuse, … » (chaîne localisée ;
--- 6 familles au plus, sous la limite de 20 paramètres).
local function families_text(keys)
  local out = { "" }
  for i, key in ipairs(keys or {}) do
    local base = L.by_key[key].base
    if i > 1 then out[#out + 1] = ", " end
    out[#out + 1] = { "", "[entity=" .. base .. "] ", { "entity-name." .. base } }
  end
  return out
end

local function reason_message(info, reason)
  if reason == "cc-too-low" and info then
    return { "fo-levels.reason-cc-too-low", info.required_cc or L.required_cc(info.family, info.next) }
  end
  if reason == "wreck" then return { "fo-centre.reason-wreck" } end
  if reason == "cc-families" and info then
    return { "fo-epochs.reason-cc-families", info.condition_level, families_text(info.blocking) }
  end
  if reason == "no-resources" and info then return { "fo-levels.reason-no-resources", missing_text(info.missing or {}) } end
  if reason == "unknown-item" and info then return { "fo-epochs.reason-unknown-item", table.concat(info.unknown or {}, ", ") } end
  if reason == "no-room" and info and info.resize then
    local side = info.resize.to
    return { "fo-levels-taille.reason-no-room", side .. "×" .. side,
      Levels.blockers_text(info.room and info.room.target) }
  end
  return { "fo-levels.reason-" .. tostring(reason) }
end

local function epoch_name(e)
  return { "fo-epochs.name-" .. L.epochs[e].key }
end

--- Monnaie de l'époque qui paie le prochain niveau (avec le matériau voulu si l'objet est provisoire).
local function currency_line(family, next_level)
  local e = L.pay_epoch(family, next_level)
  local m = L.epoch_materials[e]
  if not m then return nil end
  local icon = "[item=" .. m.item .. "]"
  local name = game.item_prototypes[m.item] and game.item_prototypes[m.item].localised_name or m.item
  if m.provisional then
    return { "fo-epochs.currency-provisional", icon, name, { "fo-epochs.want-" .. m.key } }
  end
  return { "fo-epochs.currency", icon, name }
end

--- Direction d'un décalage (dx, dy) du centre, en clé de traduction (nord = y négatif) ; nil sans décalage.
local function direction_key(dx, dy)
  local ns = dy < 0 and "n" or (dy > 0 and "s" or "")
  local ew = dx < 0 and "w" or (dx > 0 and "e" or "")
  if ns == "" and ew == "" then return nil end
  return "fo-levels-taille.dir-" .. ns .. ew
end

--- Aperçu de la place au sol pour ce joueur (Levels.draw_room). Dessiné au plus une fois par période de
--- rafraîchissement pour un même bâtiment et un même état (libre / pris), avec une durée qui court jusqu'au
--- rafraîchissement suivant (+ PREVIEW_OVERLAP) : l'aperçu reste affiché en continu, sans s'empiler.
local function draw_preview(player, target, info)
  local room = info.room
  if not room then return end
  local ui = UI()
  ui.drawn = ui.drawn or {}
  local tick = game.tick
  local free = room.chosen ~= nil
  local d = ui.drawn[player.index]
  if d and d.unit == target.unit_number and d.free == free and tick < d.until_tick then return end
  local ttl = PERIOD - tick % PERIOD + PREVIEW_OVERLAP
  Levels.draw_room(target, room, player, ttl)
  ui.drawn[player.index] = { unit = target.unit_number, free = free, until_tick = tick + ttl - PREVIEW_OVERLAP }
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
  local e = L.epoch_of(family, n)
  frame.add({ type = "label", caption = { "fo-epochs.level-line", n, family.max, e, epoch_name(e) } })
  local ccl = info.cc_level
  -- Plafond des BÂTIMENTS (2 × centre), quelle que soit la famille survolée (le centre lui-même va à 15).
  frame.add({ type = "label", caption = { "fo-epochs.cc-line", ccl, L.building_cap(ccl) } })

  if Centre.panel(frame, player, target) then
    -- Épave du centre : section de réparation (bouton fo_centre_repair), à la place de l'amélioration.
  elseif n >= family.max then
    frame.add({ type = "label", caption = { "fo-levels.maxed" } })
  else
    local ne = L.epoch_of(family, info.next)
    local what = L.step_of(family, info.next) == 1 and { "fo-epochs.new-silhouette" } or { "fo-epochs.new-piece" }
    frame.add({ type = "label", caption = { "fo-epochs.next-line", info.next, ne, epoch_name(ne), what } })
    local cur = currency_line(family, info.next)
    if cur then frame.add({ type = "label", caption = cur }) end
    -- Lot V3-T : emprise qui grandit, et place autour du bâtiment.
    if info.resize then
      local a, b = info.resize.from, info.resize.to
      -- Correction V3-T2 (défaut 11) : la ligne de taille dès que la taille change, ET la ligne « hors grille » pour un
      -- bâtiment laissé hors grille par une mise à jour du mod (l'amélioration le remet sur la grille).
      if a ~= b then
        frame.add({ type = "label", caption = { "fo-levels-taille.resize-line", a .. "×" .. a, b .. "×" .. b } })
      end
      if info.resize.regrid then
        frame.add({ type = "label", caption = { "fo-levels-taille.regrid-line", a .. "×" .. a, b .. "×" .. b } })
      end
      local room = info.room
      local lbl
      if room and room.chosen then
        -- Position retenue autre que l'habituelle (la préférée est prise) : le joueur voit où le bâtiment
        -- va s'étendre avant de payer (texte + carré vert au sol).
        local dir = (room.index or 1) > 1 and direction_key(room.chosen.dx, room.chosen.dy)
        if dir then
          lbl = frame.add({ type = "label", caption = { "fo-levels-taille.room-free-moved", { dir } } })
        else
          lbl = frame.add({ type = "label", caption = { "fo-levels-taille.room-free" } })
        end
        lbl.style.font_color = { r = 0.6, g = 1, b = 0.6 }
      else
        lbl = frame.add({ type = "label", caption = { "fo-levels-taille.room-blocked",
          Levels.blockers_text(room and room.target) } })
        lbl.style.font_color = { r = 1, g = 0.45, b = 0.4 }
        -- Lot V3-T2 (correction, défauts 1 et 6) : ce qui gêne à cause d'un point de jeu servi (coffre de la foreuse,
        -- tuyau) est dit à part : on peut aussi le garder et libérer une autre position.
        local moved = room and room.target and room.target.moved
        if moved and #moved > 0 then
          lbl = frame.add({ type = "label", caption = { "fo-levels-taille.points-moved",
            Levels.blockers_text({ moved = moved }) } })
          lbl.style.font_color = { r = 1, g = 0.9, b = 0.3 }
        end
      end
      draw_preview(player, target, info)
    end
    local now = game.entity_prototypes[target.name]
    local nxt = game.entity_prototypes[L.name(family, info.next)]
    for _, st in ipairs(family.stats) do
      local key = st.path[#st.path]
      if key ~= "rotation_speed" and not st.hidden then
        frame.add({ type = "label", caption = { "fo-levels.stat-line", { st.label or ("fo-levels.stat-" .. key) },
          fmt(key, stat_value(now, key)), fmt(key, stat_value(nxt, key)) } })
      end
    end
    frame.add({ type = "label", caption = { "fo-levels.cost" } })
    local invs = Levels.sources(target.force, player)
    local tbl = frame.add({ type = "table", column_count = 3 })
    for _, c in ipairs(info.cost) do
      if Levels.item_exists(c[1]) then
        local have = Levels.available(invs, c[1])
        local lbl = tbl.add({ type = "label", caption = "[item=" .. c[1] .. "] " .. math.min(have, c[2]) .. " / " .. c[2] })
        lbl.style.font_color = have >= c[2] and { r = 0.6, g = 1, b = 0.6 } or { r = 1, g = 0.45, b = 0.4 }
      else
        local lbl = tbl.add({ type = "label", caption = c[1] .. " ?/ " .. c[2] })
        lbl.style.font_color = { r = 1, g = 0.45, b = 0.4 }
      end
    end
    frame.add({ type = "label", caption = { "fo-levels.instant" } })
    -- Centre : condition Q16, toujours affichée (niveau visé, puis « remplie » ou les familles qui bloquent).
    if info.condition_level then
      frame.add({ type = "label", caption = { "fo-epochs.cc-rule", info.condition_level } })
      local blocking = info.blocking or {}
      local lbl
      if #blocking == 0 then
        lbl = frame.add({ type = "label", caption = { "fo-epochs.cc-rule-ok" } })
        lbl.style.font_color = { r = 0.6, g = 1, b = 0.6 }
      else
        lbl = frame.add({ type = "label", caption = { "fo-epochs.cc-rule-missing", families_text(blocking) } })
        lbl.style.font_color = { r = 1, g = 0.45, b = 0.4 }
      end
    end
    if not info.ok then
      local r = frame.add({ type = "label", caption = reason_message(info, info.reason) })
      r.style.font_color = { r = 1, g = 0.6, b = 0.3 }
    end
    -- Lot V3-T3 (Q-T2-1, réponse « QT21 option B ») : demande « libérer la place » en attente, ou bouton pour la lancer
    -- quand SEULE la place manque (motif « no-room » : condition Q16 et coût réunis ; correction, défaut 10 : avec un
    -- coût qui manque, les bras seraient déplacés pour un bâtiment qui ne grandirait pas). La règle Q24 ne change pas :
    -- sans clic, refus et contour comme avant.
    local req = Free.request_of(target)
    local can_free = (not req) and info.room and not info.room.chosen and info.reason == "no-room"
    if req then
      local lbl = frame.add({ type = "label", caption = { "fo-levels-taille.free-pending", #req.marks, #req.ghosts,
        math.max(0, math.ceil((req.expire - game.tick) / 3600)) } })
      lbl.style.font_color = { r = 0.6, g = 0.85, b = 1 }
    end
    local row = frame.add({ type = "flow", direction = "horizontal" })
    local b = row.add({ type = "button", name = "fo_lvl_up", caption = { "fo-levels.upgrade" }, style = "confirm_button" })
    -- Correction V3-T (défauts 2 et 7) : actif aussi pour le motif « no-room » (un bouton désactivé n'émet pas
    -- on_gui_click, doc 1.1.91 de LuaGuiElement.enabled) : le clic refuse sans rien payer et redessine le
    -- contour nécessaire, comme la touche U.
    b.enabled = info.ok or info.reason == "no-room"
    if family.row then row.add({ type = "button", name = "fo_lvl_row", caption = { "fo-levels.upgrade-row" } }) end
    if can_free then
      row.add({ type = "button", name = "fo_lvl_free", caption = { "fo-levels-taille.free-button" }, tooltip = { "fo-levels-taille.free-tooltip" } })
    elseif req then
      row.add({ type = "button", name = "fo_lvl_free_cancel", caption = { "fo-levels-taille.free-cancel-button" } })
    end
  end
  frame.add({ type = "button", name = "fo_lvl_close", caption = { "fo-levels.close" } })
end

--- Lot CENTRE-JEU : réparer l'épave du centre (payé sur l'inventaire du joueur) et le dire.
local function try_repair(player, entity)
  if not (entity and entity.valid) then return end
  local ok, reason, info = Centre.repair(entity, player)
  local text
  if ok then
    text = { "fo-centre.msg-repaired" }
  elseif reason == "no-resources" then
    text = { "fo-centre.reason-no-resources", missing_text(info.missing or {}) }
  else
    text = { "fo-centre.reason-" .. tostring(reason) }
  end
  player.create_local_flying_text({ text = text, position = entity.position })
end

local function try_upgrade(player, entity, row)
  if not (entity and entity.valid) then return end
  if Centre.is_wreck_entity(entity) then return try_repair(player, entity) end
  local where = entity.position
  if row then
    local done = Levels.start_row(entity, player)
    player.create_local_flying_text({ text = { "fo-levels.msg-row", done }, position = where })
    return
  end
  local ok, reason, info = Levels.start(entity, player)
  local text
  if ok then
    text = { "fo-levels.msg-done", info.next }
  else
    text = reason_message(info, reason)
  end
  player.create_local_flying_text({ text = text, position = where })
end

---------------------------------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------------------------------
--- Un joueur ne voit et n'améliore que les bâtiments de SA force : le chantier est payé par le centre de
--- la force du bâtiment, et le panneau montre son stock.
local function own(player, entity)
  return entity and entity.valid and player and player.valid and entity.force.name == player.force.name
end

Events.on(defines.events.on_selected_entity_changed, function(e)
  local player = game.get_player(e.player_index)
  local sel = player and player.selected
  if not (sel and L.parse(sel.name) and own(player, sel)) then return end
  if UI().target[player.index] == sel then return end
  set_target(player, sel)
  refresh(player)
end)

Events.on("fo-level-up", function(e)
  local player = game.get_player(e.player_index)
  local sel = player and player.selected
  if not (sel and L.parse(sel.name) and own(player, sel)) then return end
  set_target(player, sel)
  try_upgrade(player, sel, false)
  refresh(player)
end)

Events.on(defines.events.on_gui_click, function(e)
  local el = e.element
  if not (el and el.valid) then return end
  local name = el.name
  if name ~= "fo_lvl_up" and name ~= "fo_lvl_row" and name ~= "fo_lvl_close" and name ~= "fo_lvl_free" and name ~= "fo_lvl_free_cancel" and name ~= "fo_centre_repair" then return end
  local player = game.get_player(e.player_index)
  if name == "fo_lvl_close" then
    close(player)
    return
  end
  local target = UI().target[player.index]
  if not own(player, target) then
    close(player)
    return
  end
  if name == "fo_lvl_free" then
    -- Lot V3-T3 : « libérer la place » (marques, fantômes, demande en attente) ; le détail part dans la console.
    local r = Free.free_room(target, { player = player })
    if not r.ok then
      local known = { ["room-free"] = true, already = true, ["too-many"] = true, blocked = true, ["no-resources"] = true, ["engine-refused"] = true }
      local key = known[r.reason] and r.reason or "other"
      player.create_local_flying_text({ text = { "fo-levels-taille.free-refused-" .. key }, position = target.position })
    end
  elseif name == "fo_lvl_free_cancel" then
    Free.cancel(target, "cancelled")
  elseif name == "fo_centre_repair" then
    try_repair(player, target)
  else
    try_upgrade(player, target, name == "fo_lvl_row")
  end
  refresh(player)
end)

-- Rafraîchissement : l'aperçu du centre lit le recensement Q16 EN CACHE (Levels.census_cached : au plus un
-- balayage des surfaces par force et par Levels.CENSUS_TTL ticks, ou après un retrait de bâtiment à niveaux).
Events.on_nth_tick(PERIOD, function()
  local ui = UI()
  for _, player in ipairs(game.connected_players) do
    if ui.target[player.index] ~= nil then refresh(player) end
  end
end)

Events.on(defines.events.on_player_left_game, function(e)
  UI().target[e.player_index] = nil
  UI().unit[e.player_index] = nil
  if UI().drawn then UI().drawn[e.player_index] = nil end
end)

-- Après une amélioration, le bâtiment est une NOUVELLE entité : le panneau la suit.
table.insert(Levels.on_replaced, function(old_unit, new)
  local ui = UI()
  local players = {}
  for index in pairs(ui.unit) do players[#players + 1] = index end
  table.sort(players)
  for _, index in ipairs(players) do
    if ui.unit[index] == old_unit then
      ui.target[index] = new
      ui.unit[index] = new.unit_number
    end
  end
end)

return {}
