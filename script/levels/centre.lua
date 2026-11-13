--[[
  Centre de commandement : épave de départ et réparation (lot CENTRE-JEU, 29/10). Règles pures :
  shared/levels/centre.lua. Rien ne change d'emprise ni de sprite : l'épave est, pour l'instant, le centre de
  niveau 1 rendu INERTE (non minable, non ouvrable, 40 % de vie). Lot QG-JEU (1/11) : l'épave est l'entité fo-command-wreck
  (vaisseau couché de l'âge 0, emprise 8×4 comme le niveau 1 ; shared/levels/config.lua, L.WRECK, reconnue comme le
  niveau 1 du centre) ; la RÉPARER la remplace par fo-command-center sur place (Levels.swap).

  - Au PREMIER joueur d'une partie neuve (on_player_created), une épave est posée près de lui si son équipe n'a
    aucun centre. Une sauvegarde existante n'a pas d'état : son centre est « réparé » (migration sans code).
  - Tant que l'épave existe, Levels.cc_level(force) rend 0 (aucun plafond pour les autres familles) et
    Levels.preview refuse l'amélioration du centre avec la raison « wreck » (crochets posés ci-dessous).
  - Réparer (bouton du panneau ou touche U sur l'épave, remote « fo-centre ») : payé sur l'inventaire du JOUEUR ;
    l'épave devient un centre normal (vie pleine, minable, ouvrable).
  - Les IA ne passent jamais par ici : l'état n'est posé que pour la force du premier joueur ; un QG de faction
    (fo-faction-hq) ou un centre de faction n'est pas touché.
  - Si l'épave est détruite, l'état est effacé : l'ancienne voie (fabriquer un centre, recette de départ) reste ouverte.
  Stockage : espace « centre » { wreck = { [force] = numéro d'unité }, started = { [force] = true }, disabled, stats }.
  Absent d'une sauvegarde d'avant le lot : tout accès le tolère (lecture seule = « réparé »).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local L = require("shared.levels.config")
local C = require("shared.levels.centre")
local Levels = require("script.levels.levels")
local PlacesQG = require("script.ai3.places_qg") -- lot s41 spawn-joueur : le centre de départ saute une place sur une ressource

local Centre = {}

Storage.declare("centre", function()
  return { wreck = {}, started = {}, disabled = false, stats = { started = 0, repaired = 0, lost = 0 } }
end)

--- Espace de stockage, ou nil dans une sauvegarde d'avant le lot rechargée sans on_configuration_changed.
local function S() return Storage.ns("centre") end

local CC = L.by_key.command

---------------------------------------------------------------------------------------------------
-- Lecture de l'état
---------------------------------------------------------------------------------------------------
--- L'équipe a-t-elle une épave de centre (pas encore réparée) ?
--- Le registre doit désigner le centre VALIDE actuel de l'équipe : si l'épave a disparu sans événement (destroy par
--- script) et qu'un autre centre a été fabriqué, l'ancien état est périmé et ne doit pas figer le nouveau centre au
--- niveau 0. Lecture seule (aucune écriture de `global` ici) ; on_configuration_changed nettoie les restes.
function Centre.is_wreck(force)
  local st = S()
  if not (st and force) then return false end
  local un = st.wreck[force.name]
  if un == nil then return false end
  local cc = Levels.cc(force)
  return cc ~= nil and cc.unit_number == un
end

--- Cette entité est-elle l'épave de son équipe ?
function Centre.is_wreck_entity(entity)
  local st = S()
  if not (st and entity and entity.valid and entity.unit_number) then return false end
  return st.wreck[entity.force.name] == entity.unit_number
end

--- Coût de réparation (NOUVELLE liste), lu à la table des coûts du centre (L.cost).
function Centre.cost() return C.repair_cost(L) end

-- Crochets de script/levels/levels.lua : niveau effectif 0 et refus de l'amélioration d'une épave.
Levels.is_wreck = Centre.is_wreck

---------------------------------------------------------------------------------------------------
-- Poser et réparer
---------------------------------------------------------------------------------------------------
local function mark(entity)
  local st = S()
  st.wreck[entity.force.name] = entity.unit_number
  entity.minable = false
  entity.operable = false
  local max = entity.prototype.max_health
  if max and max > 0 then entity.health = max * C.WRECK_HEALTH end
end

--- Pose l'épave de l'équipe `force` près de `near` ({x, y}) sur `surface`. Renvoie l'entité ou nil.
function Centre.place_wreck(force, surface, near)
  local st = S()
  if not st then return nil end
  local name = L.WRECK
  local want = { x = near.x + C.START_OFFSET.x, y = near.y + C.START_OFFSET.y }
  -- Lot s41 spawn-joueur : places voisines de l'ancre dans l'ordre, hors ressource ; à défaut l'ancienne recherche (rayon START_RADIUS).
  local pos = C.start_pos(near, C.START_SPOTS,
    function(w) return surface.find_non_colliding_position(name, w, C.START_NEAR, 1) end,
    function(p) return PlacesQG.on_resource(surface, name, p) end,
    function() return surface.find_non_colliding_position(name, want, C.START_RADIUS, 1) end)
  if not pos then return nil end
  local e = surface.create_entity({ name = name, position = pos, force = force, raise_built = true })
  if not (e and e.valid) then return nil end
  if Levels.cc(force) ~= e then
    -- Un centre existait entre-temps (le gestionnaire de construction a rendu l'entité) : rien à marquer.
    return nil
  end
  mark(e)
  st.started[force.name] = true
  st.stats.started = st.stats.started + 1
  return e
end

local function clear(entity_or_force_name)
  local st = S()
  if st then st.wreck[entity_or_force_name] = nil end
end

--- Répare l'épave `entity`, payée sur l'inventaire de `player`. Renvoie ok, raison, info ({ cost, missing }).
--- Raisons de refus : not-centre, not-wreck, no-player, unknown-item, no-resources, invalid.
function Centre.repair(entity, player)
  if not (entity and entity.valid) then return false, "invalid" end
  local family = L.parse(entity.name)
  local cost = Centre.cost()
  local inv = player and player.valid and player.get_main_inventory() or nil
  local function have(item) return inv and inv.get_item_count(item) or 0 end
  local ok, reason = C.can_repair(
    { is_centre = family == CC, wrecked = Centre.is_wreck_entity(entity) },
    cost, have, Levels.item_exists, inv ~= nil)
  local info = { cost = cost, missing = C.missing(cost, have) }
  if not ok then return false, reason, info end
  -- Lot QG-JEU : l'épave est remplacée par le centre de niveau 1 AVANT de payer (un échec ne coûte rien).
  local force_name = entity.force.name
  local new = Levels.swap(entity, L.name(CC, 1))
  if not (new and new.valid) then return false, "replace-failed", info end
  Levels.pay({ inv }, cost)
  clear(force_name)
  new.minable = true
  new.operable = true
  new.health = new.prototype.max_health
  local st = S()
  st.stats.repaired = st.stats.repaired + 1
  return true, "done", info
end

--- Demande du DC (8/11, 13 h 20) : « le centre de commandement doit être proche du spawn du joueur, et déjà réparé au niveau 1 ».
--- Vrai : au départ, l'épave posée près du joueur est aussitôt remplacée, gratuitement, par le centre de niveau 1. Faux : épave à
--- réparer (lot CENTRE-JEU ; tests/centre_test.lua le remet à faux pour ses scènes d'épave).
Centre.START_REPAIRED = true

--- Remplace l'épave `entity` par le centre de niveau 1 SANS paiement (départ d'une partie neuve). Renvoie le centre ou nil.
function Centre.repair_free(entity)
  if not (entity and entity.valid and Centre.is_wreck_entity(entity)) then return nil end
  local force_name = entity.force.name
  local new = Levels.swap(entity, L.name(CC, 1))
  if not (new and new.valid) then return nil end
  clear(force_name)
  new.minable = true
  new.operable = true
  new.health = new.prototype.max_health
  local st = S()
  if st then st.stats.repaired = st.stats.repaired + 1 end
  return new
end

---------------------------------------------------------------------------------------------------
-- Panneau : section de l'épave (appelée par script/levels/panel.lua ; true = la section remplace l'amélioration)
---------------------------------------------------------------------------------------------------
function Centre.panel(frame, player, target)
  if not Centre.is_wreck_entity(target) then return false end
  local lbl = frame.add({ type = "label", caption = { "fo-centre.wreck-line" } })
  lbl.style.font_color = { r = 1, g = 0.6, b = 0.3 }
  frame.add({ type = "label", caption = { "fo-centre.wreck-hint" } })
  frame.add({ type = "label", caption = { "fo-centre.repair-cost" } })
  local inv = player.get_main_inventory()
  local all = true
  local tbl = frame.add({ type = "table", column_count = 3 })
  for _, c in ipairs(Centre.cost()) do
    local ok = Levels.item_exists(c[1])
    local have = ok and inv and inv.get_item_count(c[1]) or 0
    local l = tbl.add({ type = "label", caption = ok and ("[item=" .. c[1] .. "] " .. math.min(have, c[2]) .. " / " .. c[2])
      or (c[1] .. " ?/ " .. c[2]) })
    local fine = ok and have >= c[2]
    if not fine then all = false end
    l.style.font_color = fine and { r = 0.6, g = 1, b = 0.6 } or { r = 1, g = 0.45, b = 0.4 }
  end
  local b = frame.add({ type = "button", name = "fo_centre_repair", caption = { "fo-centre.repair" },
    style = "confirm_button" })
  -- Actif même s'il manque des matériaux : un bouton désactivé n'émet pas on_gui_click (doc 1.1.91) ; le clic dit ce qui manque.
  b.enabled = true
  if not all then b.tooltip = { "fo-centre.repair-missing" } end
  return true
end

---------------------------------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------------------------------
-- Départ : une épave près du premier joueur de l'équipe, si elle n'a aucun centre.
Events.on(defines.events.on_player_created, function(e)
  local st = S()
  if not st then return end
  local player = game.get_player(e.player_index)
  -- Pas de garde sur player.character : en freeplay le personnage existe à cet événement (la scène d'introduction ne
  -- vient qu'après) et la position du joueur est valide quel que soit son contrôleur ; une garde fausse supprimerait
  -- l'épave en silence.
  if not (player and player.valid) then return end
  local force = player.force
  local has = Levels.cc(force) ~= nil
  if not C.should_start(has, st.started[force.name], st.disabled) then return end
  -- Lot s41 spawn-joueur : ancre = point d'apparition de l'équipe (là où sont le vaisseau écrasé et le coffre d'équipe), pas le joueur.
  local near = C.start_anchor(force.get_spawn_position(player.surface), player.position)
  local wreck = Centre.place_wreck(force, player.surface, near)
  if not wreck then
    log("[FO-CENTRE] épave non posée pour " .. force.name .. " (pas de place libre ou centre déjà là)")
  elseif Centre.START_REPAIRED then
    local px, py = near.x, near.y
    local cc = Centre.repair_free(wreck)
    if cc then
      log(string.format("[FO-CENTRE] %s : centre pose repare au niveau 1 en (%.1f, %.1f), a %.1f tuile(s) du point d'apparition", force.name,
        cc.position.x, cc.position.y, math.sqrt((cc.position.x - px) ^ 2 + (cc.position.y - py) ^ 2)))
    else
      log("[FO-CENTRE] " .. force.name .. " : reparation de depart impossible, l'epave reste a reparer")
    end
  end
end)

-- Épave détruite ou retirée : l'état disparaît (l'équipe retrouve la recette de départ du centre).
local function on_gone(e)
  local ent = e.entity
  local st = S()
  if not (st and ent and ent.valid and ent.unit_number) then return end
  if st.wreck[ent.force.name] == ent.unit_number then
    st.wreck[ent.force.name] = nil
    st.stats.lost = st.stats.lost + 1
  end
end
Events.on_died(on_gone, { ennemi = false }) -- lot MORTS : la force « enemy » n'a pas d'épave de centre
Events.on(defines.events.on_player_mined_entity, on_gone)
Events.on(defines.events.on_robot_mined_entity, on_gone)
Events.on(defines.events.script_raised_destroy, on_gone)

-- Un remplacement (migration des emprises, réparation) : l'état de l'épave suit son entité.
Levels.on_replaced[#Levels.on_replaced + 1] = function(old_unit, new)
  local st = S()
  if not (st and old_unit and new and new.valid) then return end
  local name = new.force.name
  if st.wreck[name] == old_unit then st.wreck[name] = new.unit_number end
end

-- Mise à jour du mod : une épave d'avant le lot QG-JEU (centre de niveau 1 marqué épave) devient l'entité épave (même
-- place, même vie) ; puis un état sans épave valide derrière est effacé (équipes triées).
Events.on_configuration_changed(function()
  local st = S()
  if not st then return end
  local names = {}
  for name in pairs(st.wreck) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local force = game.forces[name]
    local cc = force and Levels.cc(force)
    if cc and cc.unit_number == st.wreck[name] and cc.name ~= L.WRECK then
      local old_unit, ratio = cc.unit_number, cc.get_health_ratio() or 1
      local new = Levels.swap(cc, L.WRECK)
      if new and new.valid then
        st.wreck[name] = new.unit_number
        new.minable = false
        new.operable = false
        new.health = new.prototype.max_health * ratio
        log("[FO-CENTRE] épave de " .. name .. " : entité remplacée par fo-command-wreck (ancien numéro " .. old_unit .. ")")
      end
    end
  end
  names = {}
  for name in pairs(st.wreck) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local force = game.forces[name]
    local cc = force and Levels.cc(force)
    if not (cc and cc.unit_number == st.wreck[name]) then st.wreck[name] = nil end
  end
end)

---------------------------------------------------------------------------------------------------
-- Interface distante (bancs, autres mods)
---------------------------------------------------------------------------------------------------
remote.add_interface("fo-centre", {
  --- État d'une équipe : { wreck, cost = {{objet, quantité}}, started, repaired }.
  status = function(force_name)
    local force = game.forces[force_name or "player"]
    local st = S() or { started = {}, stats = {} }
    return { wreck = force ~= nil and Centre.is_wreck(force), cost = Centre.cost(),
             started = st.started[force_name or "player"] == true, repaired = st.stats.repaired or 0,
             lost = st.stats.lost or 0 }
  end,
  --- Répare le centre de l'équipe, payé par le joueur `player_index`. Renvoie ok, raison.
  repair = function(force_name, player_index)
    local force = game.forces[force_name or "player"]
    local cc = force and Levels.cc(force)
    local ok, reason = Centre.repair(cc, game.get_player(player_index))
    return ok, reason
  end,
  --- Coupe (true) ou rétablit (false) la pose de l'épave au départ (scénarios de banc).
  disable_start = function(flag)
    local st = S()
    if st then st.disabled = flag == true end
  end,
  --- Pose l'épave de l'équipe près de (x, y) sur la surface d'index `surface_index` (défaut 1).
  place_wreck = function(force_name, x, y, surface_index)
    local force = game.forces[force_name or "player"]
    local surface = game.surfaces[surface_index or 1]
    if not (force and surface) then return false end
    return Centre.place_wreck(force, surface, { x = x, y = y }) ~= nil
  end,
})

return Centre
