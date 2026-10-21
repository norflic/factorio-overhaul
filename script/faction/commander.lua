--[[
  Commandant de faction : boucle stratégique, une pensée par faction toutes les think_period ticks
  (voie "fo-commander" de l'ordonnanceur, donc étalée sur les ticks).

  Session 4 (économie réelle) : une pensée = (1) entretien des groupes armés, (2) CERVEAU D'ÉQUIPE
  (script/team/team.lua : objectif, tâches des ouvriers, recrutement, équipement des soldats, recherche, le
  tout payé avec les objets du stock), (3) décision d'attaque (shared/faction/strategy.lua, pure).

  Lot IA0 : la décision d'attaque passe par script/faction/pvp.lua (S.decide) : le joueur peut être pris
  pour cible selon le niveau de difficulté ; en « Paisible », la décision est celle d'avant IA0.
]]

local Events = require("script.core.events")
local Scheduler = require("script.core.scheduler")
local Profiler = require("script.core.profiler")
local F = require("shared.faction.config")
local S = require("shared.faction.strategy")
local State = require("script.faction.state")
local Sites = require("script.faction.sites")
local Military = require("script.faction.military")
local Outposts = require("script.faction.outposts")
local Team = require("script.team.team")
local PvP = require("script.faction.pvp")

local Commander = {}

Commander.LANE = "fo-commander"

local THREAT_TICKS = 900
local THREAT_RADIUS = 90

local function surface_of(war) return game.surfaces[war.surface] end

--- Rival : prochaine faction vivante ET atteignable dans le cycle (voisin désigné).
local function rival_of(f, tick)
  local alive = State.alive()
  local n = #alive
  if n < 2 then return nil end
  local start = 1
  for i, id in ipairs(alive) do
    if id == f.id then start = i break end
  end
  for k = 1, n - 1 do
    local id = alive[(start - 1 + k) % n + 1]
    if not Military.target_unreachable(f, id, tick) then return id end
  end
  return nil
end

local function pick_target(f, tick)
  local others = {}
  for _, id in ipairs(State.alive()) do
    if id ~= f.id and not Military.target_unreachable(f, id, tick) then
      others[#others + 1] = { id = id, outposts = State.faction(id).outposts_count }
    end
  end
  local rival = rival_of(f, tick)
  if not rival then return nil end
  return State.faction(F.pick_target(f.outposts_count, rival, others))
end

local function enemy_defense(t)
  local garrison = Military.garrison_strength(t, S.soldier_strength)
  local turrets = 0
  for _, tt in pairs(t.turrets) do if tt.valid then turrets = turrets + 1 end end
  if t.outposts_count > 0 then
    return 8 * math.min(turrets, 2 * t.outposts_count) / math.max(1, t.outposts_count) + 0.3 * garrison
  end
  return 8 * turrets + garrison
end

function Commander.view(f, tick)
  local target = pick_target(f, tick)
  return {
    tech = f.tech, personality = f.personality, upgrades = f.upgrades,
    garrison = f.garrison_count, soldiers_max = State.war().settings.soldiers_max,
    can_attack = tick >= (f.attack_block_until or 0) and not f.route_pending,
    enemy_defense = target and enemy_defense(target) or math.huge,
  }, target
end

function Commander.think(id, tick)
  local war = State.war()
  local f = war.factions[id]
  if not war.active or not f or f.eliminated then
    Scheduler.remove(Commander.LANE, id)
    return
  end
  if not (f.hq and f.hq.valid) then return end -- l'élimination est traitée par l'événement de destruction
  if not Scheduler.has(Sites.LANE, id) then Sites.track(f) end
  Profiler.start("faction:think")
  local surface = surface_of(war)
  f.last_think = tick
  Profiler.start("faction:maintain")
  Military.maintain(f, tick)
  Profiler.stop("faction:maintain")
  Profiler.start("faction:team")
  Team.think(f, surface, tick)
  Profiler.stop("faction:team")
  Profiler.start("faction:attack")
  local view, target = Commander.view(f, tick)
  PvP.think(f, surface, tick, view, target)
  Profiler.stop("faction:attack")
  Profiler.stop("faction:think")
end

Scheduler.define_lane(Commander.LANE, function()
  local s = State.war().settings
  return (s and s.think_period) or F.defaults.think_period
end, Commander.think)

---------------------------------------------------------------------------------------------------
-- Destructions et menaces
---------------------------------------------------------------------------------------------------
Commander.on_eliminated = nil -- branché par war.lua

Events.on(defines.events.on_entity_destroyed, function(e)
  local owner = State.owner(e.unit_number)
  if not owner then return end
  State.disown(e.unit_number)
  local f = State.faction(owner.f)
  if not f then return end
  if owner.kind == "soldier" then
    Military.on_soldier_lost(f, e.unit_number)
  elseif owner.kind == "drill" then
    Outposts.on_drill_lost(f, owner.oid)
  elseif owner.kind == "turret" then
    f.turrets[e.unit_number] = nil
  elseif owner.kind == "hq" and not f.eliminated then
    f.eliminated = true
    if Commander.on_eliminated then Commander.on_eliminated(f, e.tick) end
  end
end)

-- Une perte près du QG ou d'un avant-poste met la faction en alerte (défense prioritaire).
Events.on(defines.events.on_entity_died, function(e)
  local war = State.war()
  if not war.active then return end
  local entity = e.entity
  local f = State.by_force(entity.force.name)
  if not f or f.eliminated then return end
  local p = entity.position
  local dx, dy = p.x - f.hq_pos.x, p.y - f.hq_pos.y
  if dx * dx + dy * dy < THREAT_RADIUS * THREAT_RADIUS then
    f.threatened_until = e.tick + THREAT_TICKS
  end
  if e.force and e.force.name == "player" and Commander.on_player_hostility then
    Commander.on_player_hostility(f, e.tick)
  end
end)

return Commander
