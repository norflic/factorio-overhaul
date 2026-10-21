--[[
  Ingénieurs de faction : agents RICHES (corps "character" de la force de la faction).

  Machine "engineer" :
     idle ──(tâche reçue)──▶ travel ──(arrivé)──▶ building ──(chantier fini)──▶ returning ──▶ idle
                               └──(échec)──▶ returning (tâche rendue)
  Ils sont vulnérables : biters et factions ennemies peuvent les intercepter en chemin.
]]

local FSM = require("script.core.fsm")
local F = require("shared.faction.config")
local Registry = require("script.companion.registry")
local Render = require("script.companion.render")
local Brain = require("script.companion.brain")
local Nav = require("script.agents.nav")
local State = require("script.faction.state")
local Outposts = require("script.faction.outposts")
local Sites = require("script.faction.sites")
local Profiler = require("script.core.profiler")

local Engineer = {}

local MACHINE = "engineer"

local function set(agent, state, tick)
  FSM.set(MACHINE, agent, state, tick)
end

local function faction_of(agent)
  return agent.faction and State.faction(agent.faction) or nil
end

--- Rapatriement d'un ingénieur égaré (enclavé entre falaises, eau ou forêt dense). Moteur réel (session 3) :
--- un ingénieur bloqué dans une poche échouait ensuite TOUTES ses missions depuis ce point. La faction le
--- rappelle au QG (téléportation) ; aucun effet de jeu au-delà du trajet évité.
local HOME_RADIUS = 24
local function far_from_home(agent, f)
  local p = agent.entity.position
  local dx, dy = p.x - f.hq_pos.x, p.y - f.hq_pos.y
  return dx * dx + dy * dy > HOME_RADIUS * HOME_RADIUS
end

local function rescue(agent, f)
  local e = agent.entity
  if not (e and e.valid) then return false end
  local spot = e.surface.find_non_colliding_position(e.name, { x = f.hq_pos.x - 6, y = f.hq_pos.y + 8 }, 20, 0.5)
  if not spot then return false end
  e.teleport(spot)
  f.stats.rescued = (f.stats.rescued or 0) + 1
  return true
end

--- Rend la tâche en cours (échec ou mort) : libère le site et le compteur de chantiers.
--- refund = part du coût rendue (1 si le chantier n'a jamais commencé).
local function drop_task(agent, refund)
  local task = agent.task
  if not task then return end
  agent.task = nil
  local f = faction_of(agent)
  if f then
    f.pending = math.max(0, f.pending - 1)
    if refund and refund > 0 then f.mu = f.mu + F.economy.outpost_cost * refund end
  end
  Sites.release(task.site)
end

FSM.define(MACHINE, {
  idle = {
    think = function(agent, tick)
      if agent.task then set(agent, "travel", tick) end
    end,
  },
  travel = {
    enter = function(agent, tick) Nav.go(agent, agent.task.site, tick, { radius = 4 }) end,
    think = function(agent, tick) Nav.think(agent, tick) end,
    exit = function(agent, tick) if agent.nav then Nav.stop(agent, tick) end end,
    on = {
      nav_arrived = function(agent, tick) set(agent, "building", tick) end,
      nav_failed = function(agent, tick)
        local f = faction_of(agent)
        local reason = agent.nav_fail or "no_path"
        local task = agent.task
        -- Blocage en marche (arbre, autre corps) : on recalcule depuis la position atteinte, 3 fois au plus.
        if reason == "stuck" and task and (task.retries or 0) < 3 then
          task.retries = (task.retries or 0) + 1
          if f then f.stats.nav_retry = (f.stats.nav_retry or 0) + 1 end
          Nav.go(agent, task.site, tick, { radius = 4 })
          return
        end
        -- Pas de chemin depuis un point éloigné du QG : l'ingénieur est peut-être enclavé. Rappel au QG
        -- puis nouvel essai (une fois) avant de déclarer le site inaccessible.
        if reason == "no_path" and task and f and not task.rescued and far_from_home(agent, f) and rescue(agent, f) then
          task.rescued = true
          Nav.go(agent, task.site, tick, { radius = 4 })
          return
        end
        -- Moteur réel (session 3) : les échecs de chemin sont fréquents (forêts, falaises, lacs).
        -- Rien n'a été construit : remboursement complet, et le site est évité pendant 30 min.
        if f then
          f.stats.nav_fail = (f.stats.nav_fail or 0) + 1
          if Profiler.enabled() and task and agent.entity.valid then
            local p = agent.entity.position
            local dx, dy = task.site.x - p.x, task.site.y - p.y
            log(string.format("[FO-NAV] ingenieur %s : echec %s a %d tuiles du site (%d,%d) -> (%d,%d)", f.key, reason,
              math.floor(math.sqrt(dx * dx + dy * dy)), math.floor(p.x), math.floor(p.y), math.floor(task.site.x), math.floor(task.site.y)))
          end
        end
        if task then Sites.mark_unreachable(task.site, tick) end
        drop_task(agent, 1)
        set(agent, "returning", tick)
      end,
    },
  },
  building = {
    enter = function(agent, tick) agent.build_until = tick + F.economy.build_ticks end,
    think = function(agent, tick)
      if tick < agent.build_until then return end
      local f = faction_of(agent)
      local task = agent.task
      agent.task = nil
      if f and task and not f.eliminated then
        f.pending = math.max(0, f.pending - 1)
        local outpost = Outposts.build(f, agent.entity.surface, task.site)
        if outpost then
          f.stats.built = (f.stats.built or 0) + 1
        else
          f.stats.build_fail = (f.stats.build_fail or 0) + 1
          Sites.release(task.site)
          Sites.mark_unreachable(task.site, tick)
          f.mu = f.mu + F.economy.outpost_cost * 0.5
        end
      end
      set(agent, "returning", tick)
    end,
  },
  returning = {
    enter = function(agent, tick)
      local f = faction_of(agent)
      if f then Nav.go(agent, f.hq_pos, tick, { radius = 8 }) end
    end,
    think = function(agent, tick)
      if not agent.nav then set(agent, "idle", tick) return end
      Nav.think(agent, tick)
    end,
    exit = function(agent, tick) if agent.nav then Nav.stop(agent, tick) end end,
    on = {
      nav_arrived = function(agent, tick) set(agent, "idle", tick) end,
      nav_failed = function(agent, tick)
        local f = faction_of(agent)
        if f and far_from_home(agent, f) then rescue(agent, f) end -- ne jamais rester égaré
        set(agent, "idle", tick)
      end,
    },
  },
})

FSM.observe(MACHINE, function(agent) Render.state_changed(agent) end)

--- Recrute un ingénieur au QG.
function Engineer.recruit(f, surface, tick)
  local probe = { x = f.hq_pos.x - 6, y = f.hq_pos.y + 8 }
  local agent = Registry.spawn(surface, probe, f.force, nil, {
    machine = MACHINE, faction = f.id, behavior = "engineer", color = f.color,
  })
  if not agent then return nil end
  f.engineers[agent.id] = true
  f.engineers_count = f.engineers_count + 1
  Brain.attach(agent, tick, "idle")
  return agent
end

--- Premier ingénieur libre (ordre déterministe), ou nil.
function Engineer.idle_one(f)
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    if a and a.state == "idle" and not a.task then return a end
  end
  return nil
end

function Engineer.idle_count(f)
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    if a and a.state == "idle" and not a.task then n = n + 1 end
  end
  return n
end

Registry.on_removed(function(agent)
  if not agent.faction then return end
  local f = State.faction(agent.faction)
  if not f or not f.engineers[agent.id] then return end
  f.engineers[agent.id] = nil
  f.engineers_count = f.engineers_count - 1
  f.stats.engineers_lost = (f.stats.engineers_lost or 0) + 1
  -- Mort en mission : le site est dangereux (vers, nids, autre faction) ; on l'évite un temps.
  if agent.task then Sites.mark_unreachable(agent.task.site, game.tick) end
  drop_task(agent, 0)
end)

return Engineer
