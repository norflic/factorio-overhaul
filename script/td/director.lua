--[[
  Mode DÉFENSE DE TOURS (runtime) : activable et désactivable à tout moment, en plus de la guerre des
  factions. Règles pures : shared/td/waves.lua.

    /fo-waves on [secondes]   active (première vague après le délai, 120 s par défaut)
    /fo-waves off             désactive (les assaillants restants se retirent : ils sont supprimés)
    /fo-waves next            lance la vague suivante tout de suite
    /fo-waves status          état
  Bouton « Vagues » en haut à gauche de l'écran (admin en multijoueur) et interface distante
  (remote.call("factorio-overhaul", "waves", "on"|"off"|"next"|"status")).

  Les assaillants forment une force dédiée, « fo-horde » : hostile au joueur et aux factions, en paix avec
  les déchiqueteurs naturels. Ce sont des unités moteur (IA C++) pilotées par groupes : coût script
  minime (une pensée par seconde, apparition étalée de TD.spawn_per_second unités par seconde).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local RNG = require("script.core.rng")
local TD = require("shared.td.waves")
local Profiler = require("script.core.profiler")

local Director = {}

local FORCE = "fo-horde"
local DEFENDER = "player"
local BUTTON = "fo-td-button"
local FRAME = "fo-td-frame"

Storage.declare("td", function()
  return {
    active = false, wave = 0, phase = "idle", next_tick = 0, started = 0,
    pending = {}, spawns = {}, groups = {}, units = {}, alive = 0, spawned = 0,
    target = nil, tags = {}, stats = { kills = 0, cleared = 0, leaked = 0, best = 0 },
  }
end)

local function S() return Storage.ns("td") end

local function say(msg)
  game.print(msg)
  log(msg)
end

local function horde_force()
  local f = game.forces[FORCE]
  if not f then
    f = game.create_force(FORCE)
    -- En paix avec les déchiqueteurs naturels (sinon les deux nuées s'entre-dévorent en chemin).
    f.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire(f, true)
    f.set_friend("enemy", true)
    game.forces.enemy.set_friend(f, true)
  end
  return f
end

--- Centre de la base défendue : barycentre des tourelles du joueur, sinon point de départ.
local function base_center(surface)
  local force = game.forces[DEFENDER]
  local turrets = surface.find_entities_filtered({ force = force, type = { "ammo-turret", "electric-turret", "fluid-turret" }, limit = 400 })
  if #turrets == 0 then return force.get_spawn_position(surface) end
  local sx, sy = 0, 0
  for _, t in ipairs(turrets) do
    local p = t.position
    sx, sy = sx + p.x, sy + p.y
  end
  return { x = sx / #turrets, y = sy / #turrets }
end

local function clear_tags()
  local st = S()
  for _, tag in ipairs(st.tags) do if tag.valid then tag.destroy() end end
  st.tags = {}
end

--- Points d'apparition de la vague, sur la terre ferme, annoncés sur la carte.
local function pick_spawns(surface, center, n)
  local spawns = {}
  local base_angle = RNG.float() * 2 * math.pi
  for i = 1, n do
    local a = base_angle + (i - 1) * 2 * math.pi / n
    local p = { x = center.x + math.cos(a) * TD.spawn_distance, y = center.y + math.sin(a) * TD.spawn_distance }
    surface.request_to_generate_chunks(p, 1)
    surface.force_generate_chunk_requests()
    local q = surface.find_non_colliding_position("big-biter", p, 40, 2)
    if q then spawns[#spawns + 1] = q end
  end
  if #spawns == 0 then spawns[1] = { x = center.x + TD.spawn_distance, y = center.y } end
  clear_tags()
  local force = game.forces[DEFENDER]
  for _, p in ipairs(spawns) do
    local tag = force.add_chart_tag(surface, { position = p, icon = { type = "virtual", name = "signal-red" }, text = "Vague" })
    if tag then table.insert(S().tags, tag) end
  end
  return spawns
end

--- Point d'apparition de secours (groupe bloqué), annoncé sur la carte sans effacer les autres.
local function relocation_point(surface, center)
  local a = RNG.float() * 2 * math.pi
  local p = { x = center.x + math.cos(a) * TD.spawn_distance, y = center.y + math.sin(a) * TD.spawn_distance }
  surface.request_to_generate_chunks(p, 1)
  surface.force_generate_chunk_requests()
  local q = surface.find_non_colliding_position("big-biter", p, 40, 2)
  if q then
    local tag = game.forces[DEFENDER].add_chart_tag(surface, { position = q, icon = { type = "virtual", name = "signal-red" }, text = "Vague" })
    if tag then table.insert(S().tags, tag) end
  end
  return q
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function assault(g, target)
  g.set_command({
    type = defines.command.attack_area, destination = target, radius = TD.target_radius,
    distraction = defines.distraction.by_enemy,
  })
  g.start_moving()
end

local function distance(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

local REGROUP_PERIOD = 600 -- contrôle des groupes toutes les 10 s
local STUCK_CHECKS = 3     -- 30 s sans se rapprocher de la base : le groupe repart d'un autre point

--- Groupes bloqués (moteur réel : vagues 4 et 5 immobiles 6 min, chemin introuvable depuis leur point
--- d'apparition) : un groupe inactif est relancé ; un groupe qui ne se rapproche plus repart d'un autre
--- point d'apparition, hors de vue ; les unités sans groupe sont regroupées.
--- Défenses restantes autour de la base (tourelles du joueur à moins de 60 tuiles de la cible).
local function defenses_left(surface, target)
  return surface.count_entities_filtered({
    position = target, radius = 60, force = game.forces[DEFENDER],
    type = { "ammo-turret", "electric-turret", "fluid-turret", "artillery-turret" }, limit = 1,
  })
end

--- Renvoie true si la base est tombée (les assaillants sont arrivés et plus aucune tourelle ne tient).
local function regroup()
  local st = S()
  local surface = game.surfaces[1]
  local force = horde_force()
  st.gstate = st.gstate or {}
  local arrived = false
  local orphans = {}
  for _, un in ipairs(sorted_keys(st.units)) do
    local u = st.units[un]
    if u.valid and not (u.unit_group and u.unit_group.valid) then orphans[#orphans + 1] = u end
  end
  if #orphans > 0 then
    local g = surface.create_unit_group({ position = orphans[1].position, force = force })
    for _, u in ipairs(orphans) do g.add_member(u) end
    st.groups[#st.groups + 1] = g
    assault(g, st.target)
  end
  for _, i in ipairs(sorted_keys(st.groups)) do
    local g = st.groups[i]
    if g.valid and #g.members > 0 then
      local d = distance(g.position, st.target)
      if d <= TD.target_radius then arrived = true end
      local gs = st.gstate[i] or { d = d, stuck = 0 }
      local state = g.state
      local fighting = state == defines.group_state.attacking_target or state == defines.group_state.attacking_distraction
      if fighting or d < gs.d - 4 or d <= TD.target_radius then gs.stuck = 0 else gs.stuck = gs.stuck + 1 end
      gs.d = math.min(gs.d, d)
      if Profiler.enabled() then
        log(string.format("[FO-TD] vague %d groupe %d : %d membres, etat %d, a %d tuiles, immobile %d", st.wave, i, #g.members, state, math.floor(d), gs.stuck))
      end
      if d > TD.target_radius and (state == defines.group_state.finished or state == defines.group_state.wander_in_group) then
        assault(g, st.target)
        st.stats.relaunched = (st.stats.relaunched or 0) + 1
      end
      if gs.stuck >= STUCK_CHECKS and d > TD.target_radius then
        local sp = relocation_point(surface, st.target)
        if sp then
          local ng = surface.create_unit_group({ position = sp, force = force })
          for _, u in ipairs(g.members) do
            local p = surface.find_non_colliding_position(u.name, sp, 20, 0.5)
            if p then u.teleport(p) end
            ng.add_member(u)
          end
          if g.valid then g.destroy() end
          st.groups[i] = ng
          assault(ng, st.target)
          gs = { d = distance(sp, st.target), stuck = 0 }
          st.stats.relocated = (st.stats.relocated or 0) + 1
          log(string.format("[FO-TD] vague %d : groupe %d bloque a %d tuiles, nouveau depart en (%d,%d)", st.wave, i, math.floor(d), math.floor(sp.x), math.floor(sp.y)))
        end
      end
      st.gstate[i] = gs
    end
  end
  return arrived and defenses_left(surface, st.target) == 0
end

local function reward(wave)
  local items = TD.reward(wave)
  for _, player in pairs(game.connected_players) do
    if player.force.name == DEFENDER and player.character then
      for _, it in ipairs(items) do
        if game.item_prototypes[it[1]] then
          local n = player.insert({ name = it[1], count = it[2] })
          if n < it[2] then
            player.surface.spill_item_stack(player.position, { name = it[1], count = it[2] - n }, true, player.force, false)
          end
        end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Déroulé
---------------------------------------------------------------------------------------------------
local function begin_build(tick, delay)
  local st = S()
  st.phase = "build"
  st.next_tick = tick + (delay or TD.build_ticks(st.wave + 1))
end

local function begin_wave(tick)
  local st = S()
  local surface = game.surfaces[1]
  st.wave = st.wave + 1
  st.phase = "wave"
  st.started = tick
  st.target = base_center(surface)
  st.pending = TD.compose(st.wave, RNG.float)
  st.spawns = pick_spawns(surface, st.target, TD.spawn_points(st.wave))
  st.groups = {}
  st.gstate = {}
  st.spawned = 0
  st.total = TD.total(st.pending)
  say({ "fo-td.wave-start", st.wave, st.total, TD.is_boss(st.wave) and { "fo-td.boss" } or "" })
end

local function spawn_some(tick)
  local st = S()
  local surface = game.surfaces[1]
  local force = horde_force()
  local budget = TD.spawn_per_second
  while budget > 0 and #st.pending > 0 do
    local entry = st.pending[1]
    local i = (st.spawned % #st.spawns) + 1
    local sp = st.spawns[i]
    local pos = surface.find_non_colliding_position(entry[1], sp, 20, 0.5)
    if not pos then break end
    local u = surface.create_entity({ name = entry[1], position = pos, force = force })
    if u then
      st.units[u.unit_number] = u
      st.alive = st.alive + 1
      local g = st.groups[i]
      if not (g and g.valid) then
        g = surface.create_unit_group({ position = sp, force = force })
        st.groups[i] = g
      end
      g.add_member(u)
    end
    st.spawned = st.spawned + 1
    entry[2] = entry[2] - 1
    if entry[2] <= 0 then table.remove(st.pending, 1) end
    budget = budget - 1
  end
  -- Tout le monde est là : assaut.
  if #st.pending == 0 and not st.launched then
    for _, i in ipairs(sorted_keys(st.groups)) do
      local g = st.groups[i]
      if g.valid then assault(g, st.target) end
    end
    st.launched = true
    st.launched_at = tick
  end
end

local function end_wave(tick, cleared)
  local st = S()
  if cleared then
    st.stats.cleared = st.stats.cleared + 1
    st.stats.best = math.max(st.stats.best, st.wave)
    reward(st.wave)
    say({ "fo-td.wave-cleared", st.wave })
  else
    -- Vague bloquée (terrain) : les survivants sont rappelés (supprimés), comptés comme passés.
    for _ in pairs(st.units) do st.stats.leaked = st.stats.leaked + 1 end
    Director.destroy_units()
    say({ "fo-td.wave-timeout", st.wave })
  end
  st.launched = false
  clear_tags()
  begin_build(tick)
end

--- La base est tombée : la défense s'arrête (record conservé), les assaillants se retirent.
local function base_fallen(tick)
  local st = S()
  st.stats.best = math.max(st.stats.best, st.wave - 1)
  st.stats.fallen = (st.stats.fallen or 0) + 1
  Director.destroy_units()
  clear_tags()
  say({ "fo-td.base-fallen", st.wave, st.stats.best })
  st.active = false
  st.phase = "idle"
  st.pending = {}
  st.launched = false
end

function Director.destroy_units()
  local st = S()
  local surface = game.surfaces[1]
  for _, g in pairs(st.groups) do if g.valid then g.destroy() end end
  st.groups = {}
  for _, e in ipairs(surface.find_entities_filtered({ force = FORCE, type = "unit" })) do e.destroy() end
  st.units = {}
  st.alive = 0
end

function Director.start(delay_ticks)
  local st = S()
  if st.active then return false end
  horde_force()
  st.active = true
  st.pending = {}
  begin_build(game.tick, delay_ticks or TD.first_delay)
  say({ "fo-td.enabled", math.floor((st.next_tick - game.tick) / 60) })
  return true
end

function Director.stop()
  local st = S()
  if not st.active then return false end
  st.active = false
  st.phase = "idle"
  st.pending = {}
  Director.destroy_units()
  clear_tags()
  say({ "fo-td.disabled", st.stats.best })
  return true
end

function Director.next()
  local st = S()
  if not st.active then return false end
  if st.phase == "build" then st.next_tick = game.tick end
  return true
end

function Director.state()
  return S()
end

Events.on_nth_tick(60, function(e)
  local st = S()
  if not st.active then return end
  local tick = e.tick
  if st.phase == "build" then
    if tick >= st.next_tick then begin_wave(tick) end
  elseif st.phase == "wave" then
    if #st.pending > 0 or not st.launched then spawn_some(tick) end
    -- Recompte (une unité peut disparaître sans mourir : script tiers, sortie de carte...).
    local alive = 0
    for un, u in pairs(st.units) do
      if u.valid then alive = alive + 1 else st.units[un] = nil end
    end
    st.alive = alive
    if st.launched and not st.launched_at then st.launched_at = tick end
    if st.launched and alive > 0 and tick > st.launched_at and (tick - st.launched_at) % REGROUP_PERIOD < 60 then
      if regroup() then
        base_fallen(tick)
        return
      end
    end
    if #st.pending == 0 and st.alive <= 0 then
      end_wave(tick, true)
    elseif tick - st.started > TD.wave_timeout then
      end_wave(tick, false)
    end
  end
end)

Events.on(defines.events.on_entity_died, function(e)
  local st = S()
  local ent = e.entity
  if not st.active or not (ent and ent.unit_number) then return end
  if st.units[ent.unit_number] then
    st.units[ent.unit_number] = nil
    st.alive = st.alive - 1
    st.stats.kills = st.stats.kills + 1
  end
end)

---------------------------------------------------------------------------------------------------
-- Interface : bouton, panneau, commande
---------------------------------------------------------------------------------------------------
local function fmt_time(ticks)
  local s = math.max(0, math.floor(ticks / 60))
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function ensure_button(player)
  local top = player.gui.top
  if not top[BUTTON] then
    top.add({ type = "sprite-button", name = BUTTON, sprite = "item/gun-turret", tooltip = { "fo-td.button-tooltip" } })
  end
end

local function update_frame(player)
  local st = S()
  local left = player.gui.left
  local frame = left[FRAME]
  if not st.active then
    if frame then frame.destroy() end
    return
  end
  if not frame then
    frame = left.add({ type = "frame", name = FRAME, direction = "vertical", caption = { "fo-td.title" } })
    frame.add({ type = "label", name = "line1" })
    frame.add({ type = "label", name = "line2" })
  end
  if st.phase == "build" then
    frame.line1.caption = { "fo-td.next-wave", st.wave + 1, fmt_time(st.next_tick - game.tick) }
    frame.line2.caption = { "fo-td.record", st.stats.cleared, st.stats.kills }
  else
    frame.line1.caption = { "fo-td.wave-running", st.wave, st.alive, #st.pending > 0 and TD.total(st.pending) or 0 }
    frame.line2.caption = { "fo-td.record", st.stats.cleared, st.stats.kills }
  end
end

Events.on_nth_tick(30, function()
  for _, player in pairs(game.connected_players) do
    ensure_button(player)
    update_frame(player)
  end
end)

local function allowed(player)
  return not game.is_multiplayer() or player.admin
end

Events.on(defines.events.on_gui_click, function(e)
  if not (e.element and e.element.valid and e.element.name == BUTTON) then return end
  local player = game.get_player(e.player_index)
  if not allowed(player) then
    player.print({ "fo-td.admin-only" })
    return
  end
  if S().active then Director.stop() else Director.start() end
end)

commands.add_command("fo-waves", { "fo-td.command-help" }, function(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  if player and not allowed(player) then
    player.print({ "fo-td.admin-only" })
    return
  end
  local args = {}
  for w in string.gmatch(cmd.parameter or "", "%S+") do args[#args + 1] = w end
  local sub = args[1] or "status"
  if sub == "on" then
    Director.start(args[2] and math.floor(tonumber(args[2]) * 60) or nil)
  elseif sub == "off" then
    Director.stop()
  elseif sub == "next" then
    Director.next()
  else
    local st = S()
    local msg = string.format("[FO-TD] actif=%s vague=%d phase=%s vivants=%d a venir=%d | tenues %d, tues %d, passes %d",
      tostring(st.active), st.wave, st.phase, st.alive, TD.total(st.pending), st.stats.cleared, st.stats.kills, st.stats.leaked)
    if player then player.print(msg) end
    log(msg)
  end
end)

return Director
