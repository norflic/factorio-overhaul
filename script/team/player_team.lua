--[[
  Équipe du JOUEUR : les compagnons travaillent pour le joueur avec le même cerveau d'équipe que les
  factions IA (shared/team/planner.lua, échelle T.player_ladder : charbon, fer, cuivre, pierre, munitions,
  expansion, fonderie, avant-postes défendus).

  Le joueur pose un COFFRE D'ÉQUIPE (objet fo-team-chest) : c'est le stock de l'équipe. Les ouvriers ne
  consomment que ce qu'il contient ; ils y rapportent la production des avant-postes qu'ils construisent.
  Lot IA1-a : fo-npc-start PNJ (8) sont offerts à la pose du coffre ; ensuite, un ouvrier est recruté dès que
  son prix (pistolet + 10 chargeurs + (10 + effectif) plaques de fer) est dans le coffre, jusqu'à
  fo-player-team-npc-max (30 ; T.player_workers_max = 8 avant). Le cerveau fabrique ces équipements lui-même
  s'il a des plaques.

    /fo-team status    objectif, ce qui manque, stock, tâches
    /fo-team dismiss   renvoie tous les ouvriers (leur équipement revient au coffre)
]]

local Events = require("script.core.events")
local Scheduler = require("script.core.scheduler")
local Storage = require("script.core.storage")
local T = require("shared.team.config")
local State = require("script.faction.state")
local Sites = require("script.faction.sites")
local Registry = require("script.companion.registry")
local Team = require("script.team.team")

local PlayerTeam = {}

local CHEST = "fo-team-chest"
local THINK_LANE = "fo-pteam"
local PROSPECT_LANE = "fo-pteam-prospect"

local function get() return Storage.ns("pteam").team end

function PlayerTeam.get() return get() end

local function create(chest)
  local surface = chest.surface
  local f = {
    id = "player", key = "player", force = chest.force.name, is_player = true, personality = "builder",
    color = { r = 0.95, g = 0.85, b = 0.3 }, hq = chest, hq_pos = { x = chest.position.x, y = chest.position.y },
    tech = 0, upgrades = 0, started = game.tick, surface = surface.index,
    engineers = {}, engineers_count = 0, outposts = {}, outposts_count = 0, next_oid = 0,
    turrets = {}, soldiers = {}, soldiers_count = 0, garrison_count = 0, groups = {}, smelters = {},
    stats = { attacks = 0, outposts_built = 0, outposts_lost = 0, soldiers_lost = 0, kills = 0 },
  }
  Storage.ns("pteam").team = f
  Team.init(f, surface)
  f.chest_reg = script.register_on_entity_destroyed(chest)
  f.goal_label = rendering.draw_text({
    text = Team.goal_text(f), surface = surface, target = chest, target_offset = { 0, -1.6 },
    color = { r = 1, g = 1, b = 1 }, scale = 1.1, alignment = "center",
  })
  Scheduler.add(THINK_LANE, 1)
  Scheduler.add(PROSPECT_LANE, 1)
  game.print({ "fo-team.created" })
  return f
end

local function dismiss(f, refund)
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    -- Lot IA1-a : un kit OFFERT (PNJ de départ, embauche de secours sans arme) n'est jamais rendu.
    if refund and f.hq and f.hq.valid and not (a and a.free_kit) then
      for _, it in ipairs(T.kits.worker) do f.hq.insert({ name = it[1], count = it[2] }) end
    end
    Registry.remove(id, true)
  end
end

local function on_built(e)
  local ent = e.created_entity or e.entity
  if not (ent and ent.valid and ent.name == CHEST) then return end
  local f = get()
  if f and f.hq and f.hq.valid then
    local player = e.player_index and game.get_player(e.player_index)
    if player then player.print({ "fo-team.only-one" }) end
    return
  end
  create(ent)
end

Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)

Events.on(defines.events.on_entity_destroyed, function(e)
  local f = get()
  if not f or e.registration_number ~= f.chest_reg then return end
  dismiss(f, false)
  if f.goal_label and rendering.is_valid(f.goal_label) then rendering.destroy(f.goal_label) end
  Storage.ns("pteam").team = nil
  Scheduler.remove(THINK_LANE, 1)
  Scheduler.remove(PROSPECT_LANE, 1)
  game.print({ "fo-team.lost" })
end)

Scheduler.define_lane(THINK_LANE, 300, function(_, tick)
  local f = get()
  if not (f and f.hq and f.hq.valid) then return end
  Team.think(f, f.hq.surface, tick)
end)

Scheduler.define_lane(PROSPECT_LANE, 30, function(_, tick)
  local f = get()
  if not (f and f.hq and f.hq.valid) then return end
  Sites.prospect(f, f.hq.surface, tick)
end)

Events.on_nth_tick(600, function()
  local f = get()
  if f and f.goal_label and rendering.is_valid(f.goal_label) then rendering.set_text(f.goal_label, Team.goal_text(f)) end
end)

commands.add_command("fo-team", { "fo-team.command-help" }, function(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  local f = get()
  local sub = (cmd.parameter or "status"):match("^%s*(%S*)")
  if not f then
    if player then player.print({ "fo-team.none" }) end
    return
  end
  if sub == "dismiss" then
    dismiss(f, true)
    if player then player.print({ "fo-team.dismissed" }) end
    return
  end
  local line = Team.status_line(f)
  if player then
    player.print(Team.goal_text(f))
    player.print(line)
  end
  log(line)
end)

return PlayerTeam
