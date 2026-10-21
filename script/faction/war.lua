--[[
  Guerre des factions : lancement, arrêt, état, diplomatie, affichage.

    /fo-war start [factions=4] [soldats=100] [ingénieurs=10] [distance=480]
    /fo-war status        tableau de bord (aussi dans factorio-current.log et script-output/fo-war/status.txt)
    /fo-war stop          supprime tout ce qui appartient aux factions
    /fo-war fund <n>      ajoute n plaques de fer (et cuivre, charbon, pierre) au stock de chaque faction

  Diplomatie : factions hostiles entre elles et aux déchiqueteurs. Avec le joueur : cessez-le-feu au
  lancement ; tuer une entité d'une faction lui fait déclarer la guerre au joueur. Lot IA0 : hors
  « Paisible », chaque faction déclare d'elle-même la guerre au joueur après un délai de grâce et le prend
  pour cible (script/faction/pvp.lua, réglage fo-pvp-difficulty). L'ancien réglage
  fo-war-player-ceasefire n'est plus lu (le niveau « Paisible » le remplace).
]]

local Events = require("script.core.events")
local Scheduler = require("script.core.scheduler")
local PathService = require("script.core.path_service")
local F = require("shared.faction.config")
local State = require("script.faction.state")
local Commander = require("script.faction.commander")
local Military = require("script.faction.military")
local Outposts = require("script.faction.outposts")
local Sites = require("script.faction.sites")
local Registry = require("script.companion.registry")
local Team = require("script.team.team")
local Storage = require("script.core.storage")
local PvP = require("script.faction.pvp")

local War = {}

local DIAG = 0.7071
local CORNERS = { { DIAG, -DIAG }, { DIAG, DIAG }, { -DIAG, DIAG }, { -DIAG, -DIAG } }
local CLEAR_RADIUS = 14
local ENEMY_CLEAR_RADIUS = 80

local function say(msg)
  game.print(msg)
  log(msg)
end

local function faction_name(f) return { "fo-faction.name-" .. f.key } end

local function update_label(f)
  if not (f.label and rendering.is_valid(f.label)) then return end
  rendering.set_text(f.label, {
    "fo-faction.label", faction_name(f), f.tech, f.soldiers_count, f.outposts_count,
  })
end

local function clear_area(surface, pos)
  local area = { { pos.x - CLEAR_RADIUS, pos.y - CLEAR_RADIUS }, { pos.x + CLEAR_RADIUS, pos.y + CLEAR_RADIUS } }
  for _, e in ipairs(surface.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff" } })) do
    e.destroy()
  end
  local earea = { { pos.x - ENEMY_CLEAR_RADIUS, pos.y - ENEMY_CLEAR_RADIUS }, { pos.x + ENEMY_CLEAR_RADIUS, pos.y + ENEMY_CLEAR_RADIUS } }
  for _, e in ipairs(surface.find_entities_filtered({ area = earea, force = "enemy" })) do
    e.destroy()
  end
end

local function set_player_relations(f, ceasefire)
  local force, player = game.forces[f.force], game.forces.player
  force.set_cease_fire(player, ceasefire)
  player.set_cease_fire(force, ceasefire)
end

--- Emplacements de QG candidats autour d'un point visé, du meilleur au moins bon. Moteur réel (session 3) :
--- un QG posé sur une presqu'île ou dans une poche de falaises n'atteignait aucun gisement et aucune cible.
--- Score = eau à 40 tuiles × 2 + eau à 80 tuiles + falaises à 40 tuiles × 30 ; candidats à 0, ±64 et ±128.
local HQ_OFFSETS = {
  { 0, 0 }, { 64, 0 }, { -64, 0 }, { 0, 64 }, { 0, -64 }, { 64, 64 }, { -64, -64 }, { 64, -64 }, { -64, 64 },
  { 128, 0 }, { -128, 0 }, { 0, 128 }, { 0, -128 }, { 128, 128 }, { -128, -128 }, { 128, -128 }, { -128, 128 },
}

local function ranked_hq_spots(surface, p0)
  local list = {}
  for i, o in ipairs(HQ_OFFSETS) do
    local c = { x = p0.x + o[1], y = p0.y + o[2] }
    local water_near = surface.count_tiles_filtered({ position = c, radius = 40, collision_mask = "water-tile" })
    local water_far = surface.count_tiles_filtered({ position = c, radius = 80, collision_mask = "water-tile" })
    local cliffs = surface.count_entities_filtered({ position = c, radius = 40, type = "cliff" })
    list[#list + 1] = { x = c.x, y = c.y, score = water_near * 2 + water_far + cliffs * 30 + i }
  end
  table.sort(list, function(a, b) return a.score < b.score end)
  return list
end

--- Fonde (ou refonde) le QG d'une faction en pos : QG, tourelles, étiquette, premier ingénieur.
local function found_hq(f, surface, pos)
  local force = game.forces[f.force]
  clear_area(surface, pos)
  local hq_pos = surface.find_non_colliding_position("fo-faction-hq", pos, 60, 1) or pos
  local hq = surface.create_entity({ name = "fo-faction-hq", position = hq_pos, force = force })
  f.hq = hq
  f.hq_pos = { x = hq_pos.x, y = hq_pos.y }
  State.own(hq, f.id, "hq")
  local offsets = { { 12, 0 }, { -12, 0 }, { 0, 10 }, { 0, -10 } }
  for k = 1, F.military.hq_turrets do
    local o = offsets[k]
    local tpos = surface.find_non_colliding_position("gun-turret", { x = hq_pos.x + o[1], y = hq_pos.y + o[2] }, 10, 1)
    if tpos then
      local t = surface.create_entity({ name = "gun-turret", position = tpos, force = force })
      if t then Outposts.add_turret(f, t, nil, 20) end
    end
  end
  f.label = rendering.draw_text({
    text = faction_name(f), surface = surface, target = hq, target_offset = { 0, -7 },
    color = f.color, scale = 3, alignment = "center",
  })
  update_label(f)
  game.forces.player.chart(surface, { { hq_pos.x - 64, hq_pos.y - 64 }, { hq_pos.x + 64, hq_pos.y + 64 } })
  -- Économie réelle (session 4) : stock de départ dans le QG, premiers ouvriers équipés.
  Team.init(f, surface)
  f.goal_label = rendering.draw_text({
    text = Team.goal_text(f), surface = surface, target = hq, target_offset = { 0, -5.2 },
    color = { r = 1, g = 1, b = 1 }, scale = 1.4, alignment = "center",
  })
end

--- Défait un QG fraîchement fondé (déménagement) : rien de tout cela ne compte comme une perte.
local function unfound_hq(f)
  if f.hq and f.hq.valid then
    State.disown(f.hq.unit_number)
    f.hq.destroy()
  end
  for _, id in ipairs(State.sorted_keys(f.turrets)) do
    local t = f.turrets[id]
    if t.valid then
      State.disown(t.unit_number)
      t.destroy()
    end
  end
  f.turrets = {}
  for _, aid in ipairs(State.sorted_keys(f.engineers)) do Registry.remove(aid, true) end
  f.stats.engineers_lost = 0
  for _, s in ipairs(f.smelters or {}) do if s.valid then s.destroy() end end
  f.smelters = {}
  for _, l in ipairs({ "label", "goal_label" }) do
    if f[l] and rendering.is_valid(f[l]) then rendering.destroy(f[l]) end
    f[l] = nil
  end
end

-- Vérification d'accès : depuis le QG, le centre de la carte doit être atteignable à pied ; sinon la faction
-- déménage vers le candidat suivant (4 essais au plus). Asynchrone (PathService), juste après le lancement.
local SITE_CHECK = "fo-war-site"
local MAX_RELOCATIONS = 4

local function request_site_check(f, surface)
  local war = State.war()
  local start = surface.find_non_colliding_position("fo-companion", { x = f.hq_pos.x - 6, y = f.hq_pos.y + 8 }, 20, 0.5)
    or { x = f.hq_pos.x - 6, y = f.hq_pos.y + 8 }
  f.site_ticket = PathService.request(SITE_CHECK, f.id, {
    surface = surface.index, proto = "fo-companion", pad = 0, start = start, goal = war.center,
    force = f.force, radius = 24, flags = { cache = false, low_priority = false }, res = 0,
  })
end

PathService.register_handler(SITE_CHECK, function(fid, path, ticket, reason, tick)
  local war = State.war()
  local f = war.active and war.factions[fid]
  if not f or f.site_ticket ~= ticket or f.eliminated then return end
  f.site_ticket = nil
  local surface = game.surfaces[war.surface]
  if path then
    f.site_ok = true
    return
  end
  if reason ~= "no_path" then -- pathfinder saturé ou délai : on redemande
    request_site_check(f, surface)
    return
  end
  f.site_index = (f.site_index or 1) + 1
  local nxt = f.site_candidates and f.site_candidates[f.site_index]
  if not nxt or (f.stats.relocations or 0) >= MAX_RELOCATIONS then
    f.site_ok = false
    return
  end
  f.stats.relocations = (f.stats.relocations or 0) + 1
  log(string.format("[FO-WAR] %s : QG enclave (aucun chemin vers le centre), demenagement en (%d, %d)", f.key, nxt.x, nxt.y))
  unfound_hq(f)
  found_hq(f, surface, nxt)
  request_site_check(f, surface)
end)

function War.start_at(surface, center, n, soldiers_max, engineers_max, distance)
  local war = State.war()
  if war.active then return false, "deja en cours" end
  n = math.max(2, math.min(F.MAX_FACTIONS, n))
  war.active = true
  war.started = game.tick
  war.surface = surface.index
  war.center = { x = center.x, y = center.y }
  war.settings = {
    soldiers_max = soldiers_max, engineers_max = engineers_max, distance = distance,
    think_period = F.defaults.think_period,
  }
  -- Génération synchrone du voisinage des QG (coût unique au lancement : choix d'emplacement), puis
  -- génération en arrière-plan du territoire de prospection (12 chunks autour du QG).
  local positions = {}
  for i = 1, n do
    local c = CORNERS[i]
    positions[i] = { x = center.x + c[1] * distance, y = center.y + c[2] * distance }
    surface.request_to_generate_chunks(positions[i], 7)
  end
  surface.force_generate_chunk_requests()
  local candidates = {}
  for i = 1, n do
    candidates[i] = ranked_hq_spots(surface, positions[i])
    surface.request_to_generate_chunks(candidates[i][1], 13)
  end

  for i = 1, n do
    local def = F.factions[i]
    local force_name = "fo-" .. def.key
    if not game.forces[force_name] then game.create_force(force_name) end
    local f = {
      id = i, key = def.key, force = force_name, personality = def.personality, color = def.color,
      hq = nil, hq_pos = nil, eliminated = false,
      tech = 0, upgrades = 0, last_think = game.tick,
      threatened_until = 0, sites_blocked_until = 0,
      engineers = {}, engineers_count = 0,
      outposts = {}, outposts_count = 0, next_oid = 0, pending = 0,
      turrets = {}, soldiers = {}, soldiers_count = 0, garrison_count = 0, groups = {},
      stats = { attacks = 0, outposts_built = 0, outposts_lost = 0, soldiers_lost = 0, kills = 0 },
      site_candidates = candidates[i], site_index = 1,
    }
    war.factions[i] = f
    war.by_force[force_name] = i
    found_hq(f, surface, candidates[i][1])
    Scheduler.add(Commander.LANE, i)
    Sites.track(f)
    request_site_check(f, surface)
  end

  -- Diplomatie : factions hostiles entre elles (défaut moteur), cessez-le-feu avec le joueur au lancement
  -- (lot IA0 : la difficulté décide ensuite si et quand chaque faction le rompt).
  for i = 1, n do
    local f = war.factions[i]
    for j = 1, n do
      if i ~= j then game.forces[f.force].set_cease_fire(war.factions[j].force, false) end
    end
    set_player_relations(f, true)
  end
  say({ "fo-faction.war-started", n })
  PvP.on_war_started(game.tick)
  return true
end

function War.start(player, n, soldiers_max, engineers_max, distance)
  return War.start_at(player.surface, player.force.get_spawn_position(player.surface), n, soldiers_max, engineers_max, distance)
end

function War.stop()
  local war = State.war()
  if not war.active then return 0 end
  local removed = 0
  for _, id in ipairs(State.sorted_keys(war.factions)) do
    local f = war.factions[id]
    for _, gid in ipairs(State.sorted_keys(f.groups)) do
      local g = f.groups[gid]
      if g.group.valid then g.group.destroy() end
    end
    for _, aid in ipairs(State.sorted_keys(f.engineers)) do
      Registry.remove(aid, true)
      removed = removed + 1
    end
    local surface = game.surfaces[war.surface]
    if surface then
      for _, e in ipairs(surface.find_entities_filtered({ force = f.force })) do
        if e.valid then
          e.destroy()
          removed = removed + 1
        end
      end
    end
    Scheduler.remove(Commander.LANE, id)
    Sites.untrack(id)
  end
  PvP.on_war_stopped()
  war.active = false
  war.factions, war.by_force, war.owners, war.claims = {}, {}, {}, {}
  return removed
end

--- Ajoute des matières premières au stock de chaque faction vivante (tests, scénarios) : `amount` plaques
--- de fer, un quart en cuivre, la moitié en charbon et en pierre.
function War.fund(amount)
  local war = State.war()
  if not war.active then return 0 end
  for _, id in ipairs(State.alive()) do
    local f = war.factions[id]
    if f.hq and f.hq.valid then
      for _, it in ipairs({ { "iron-plate", amount }, { "copper-plate", amount / 4 }, { "coal", amount / 2 }, { "stone", amount / 2 } }) do
        local n = math.floor(it[2])
        if n > 0 then f.hq.insert({ name = it[1], count = n }) end
      end
    end
  end
  return #State.alive()
end

function War.status_lines(tick)
  local war = State.war()
  local lines = {}
  if not war.active then
    lines[1] = "[FO-WAR] aucune guerre en cours (/fo-war start)"
    return lines
  end
  lines[1] = string.format("[FO-WAR] %.1f min | factions vivantes %d", (tick - war.started) / 3600, #State.alive())
  lines[2] = PvP.status_line(tick)
  for _, id in ipairs(State.sorted_keys(war.factions)) do
    local f = war.factions[id]
    local kinds = {}
    for _, oid in ipairs(State.sorted_keys(f.outposts)) do
      local k = f.outposts[oid].kind
      kinds[k] = (kinds[k] or 0) + 1
    end
    local ks = {}
    for _, k in ipairs(State.sorted_keys(kinds)) do ks[#ks + 1] = k .. " " .. kinds[k] end
    lines[#lines + 1] = {
      "", "  ", faction_name(f), string.format(
        " [%s]%s tech %d+%d | avant-postes %d (%s) | fonderie %d | soldats %d (garnison %d, groupes %d) | ouvriers %d | attaques %d | pertes %d",
        f.personality, f.eliminated and " ANEANTIE |" or "", f.tech, f.upgrades,
        f.outposts_count, table.concat(ks, ", "), f.smelters and #f.smelters or 0, f.soldiers_count, f.garrison_count,
        #State.sorted_keys(f.groups), f.engineers_count, f.stats.attacks, f.stats.soldiers_lost),
    }
    if f.team and f.hq and f.hq.valid then lines[#lines + 1] = Team.status_line(f) end
    local st = f.stats
    lines[#lines + 1] = string.format(
      "    chantiers : construits %d, chemin introuvable %d, rapatriements %d, pose impossible %d | tournees %d, munitions posees %d, fabrications %d (echecs %d), mine %d, tirs d'ouvriers %d | prospection : sites %d (hostiles %d), tours %d, en reserve %d | ouvriers perdus %d | attaques avortees %d, sans itineraire %d",
      st.built or 0, st.nav_fail or 0, st.rescued or 0, st.build_fail or 0, st.serviced or 0, st.refilled or 0,
      st.crafted or 0, st.craft_fail or 0, st.mined or 0, st.worker_shots or 0, st.prospected or 0, st.prospect_hostile or 0,
      st.prospect_cycles or 0, f.prospects and #f.prospects or 0, st.engineers_lost or 0, st.attack_fail or 0, st.route_fail or 0)
  end
  return lines
end

Commander.on_eliminated = function(f, tick)
  say({ "fo-faction.eliminated", faction_name(f) })
  if f.label and rendering.is_valid(f.label) then rendering.destroy(f.label) end
  Scheduler.remove(Commander.LANE, f.id)
  Sites.untrack(f.id)
  local alive = State.alive()
  if #alive == 1 then say({ "fo-faction.victory", faction_name(State.faction(alive[1])) }) end
end

Commander.on_player_hostility = function(f, tick)
  PvP.on_provoked(f, tick)
end

-- Rafraîchit les étiquettes des QG (nom, objectif d'équipe, ce qui manque) toutes les 10 s.
Events.on_nth_tick(600, function()
  local war = State.war()
  if not war.active then return end
  for _, id in ipairs(State.alive()) do
    local f = war.factions[id]
    update_label(f)
    if f.goal_label and rendering.is_valid(f.goal_label) then rendering.set_text(f.goal_label, Team.goal_text(f)) end
  end
end)

---------------------------------------------------------------------------------------------------
-- Commande
---------------------------------------------------------------------------------------------------
local USAGE = "Usage : /fo-war start [factions=4] [soldats=100] [ouvriers=10] [distance=480] | status | stop | fund <plaques>"

local function split(s)
  local out = {}
  for w in string.gmatch(s or "", "%S+") do out[#out + 1] = w end
  return out
end

commands.add_command("fo-war", USAGE, function(cmd)
  local player = game.get_player(cmd.player_index)
  if not player then return end
  if game.is_multiplayer() and not player.admin then
    player.print("[FO-WAR] reserve aux admins.")
    return
  end
  local args = split(cmd.parameter)
  local sub = args[1]
  if sub == "start" then
    local ok, err = War.start(player,
      math.floor(tonumber(args[2]) or F.MAX_FACTIONS),
      math.floor(tonumber(args[3]) or F.defaults.soldiers_max),
      math.floor(tonumber(args[4]) or F.defaults.engineers_max),
      math.floor(tonumber(args[5]) or F.defaults.distance))
    if not ok then player.print("[FO-WAR] " .. err) end
  elseif sub == "status" then
    for i, line in ipairs(War.status_lines(game.tick)) do
      player.print(line)
      log(line)
      game.write_file("fo-war/status.txt", { "", line, "\n" }, i > 1, player.index)
    end
  elseif sub == "stop" then
    player.print(string.format("[FO-WAR] guerre arretee, %d entites supprimees.", War.stop()))
  elseif sub == "fund" then
    local amount = tonumber(args[2]) or 1000
    War.fund(amount)
    player.print("[FO-WAR] +" .. amount .. " plaques de fer (et cuivre, charbon, pierre) par faction.")
  else
    player.print(USAGE)
  end
end)

-- Migration 0.2 -> 0.3 (schéma 2). L'économie à registre (MU) a disparu : une guerre 0.2 en cours n'a ni
-- stock réel, ni tableau de tâches, ni ouvriers. Elle est arrêtée proprement (unités, ingénieurs, bâtiments
-- des factions) et les joueurs sont prévenus : `/fo-war start` relance une guerre à économie réelle.
Storage.migration(2, function(fo)
  if fo.war and fo.war.active then fo.war.reset_v03 = true end
end)

Events.on_configuration_changed(function()
  local war = State.war()
  if not (war and war.reset_v03) then return end
  war.reset_v03 = nil
  for _, id in ipairs(State.sorted_keys(war.factions or {})) do
    local f = war.factions[id]
    f.groups = f.groups or {}
    f.engineers = f.engineers or {}
    for _, aid in ipairs(State.sorted_keys(f.engineers)) do
      local a = Registry.get(aid)
      if a then a.task = nil end -- tâche au format 0.2 : rien à rendre au stock
    end
  end
  local n = War.stop()
  log("[FO-WAR] migration 0.3 : guerre 0.2 arretee, " .. n .. " entites supprimees")
  say({ "fo-faction.war-reset-v03" })
end)

return War
