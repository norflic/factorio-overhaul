--[[
  Simulateur hors-jeu de la guerre des factions : exécute shared/faction/strategy.lua (le MÊME cerveau
  que le runtime) dans un modèle abstrait (temps de trajet, combats de Lanchester simplifiés), pour
  calibrer shared/faction/config.lua sans lancer le jeu.

  Usage, depuis la racine du mod :   lua5.2 tools/sim_war.lua [minutes=60] [graine=1]
]]

package.path = "./?.lua;" .. package.path
local F = require("shared.faction.config")
local S = require("shared.faction.strategy")

local MINUTES = tonumber(arg and arg[1]) or 60
math.randomseed(tonumber(arg and arg[2]) or 1)

local DT = F.defaults.think_period / 60 -- secondes entre deux décisions
local SITES_PER_FACTION = 12
local TRAVEL = 50                       -- s : marche entre deux factions voisines
local OUTPOST_TRIP = 70                 -- s : aller + chantier

local factions = {}
for i, def in ipairs(F.factions) do
  factions[i] = {
    id = i, key = def.key, personality = def.personality,
    mu = F.economy.start_mu, research_fund = 0, tech = 0, upgrades = 0,
    engineers = 0, busy = {},           -- busy[j] = instant de fin de mission
    outposts = {}, pending = 0, sites = SITES_PER_FACTION,
    garrison = 0, soldiers = 0, groups = {},
    stats = { built = 0, lost_outposts = 0, kills = 0, losses = 0, attacks = 0 },
  }
end

local t = 0

local function income(f)
  local inc = F.hq_income(t / 60)
  for _, o in ipairs(f.outposts) do inc = inc + F.outpost_income(o, f.tech) end
  local total = 0
  for _, o in ipairs(factions) do total = total + #o.outposts end
  return inc * F.underdog_multiplier(#f.outposts, total / #factions)
end

local function unit_power(f, key)
  local s = F.soldiers[key]
  local dps = s.damage * 60 / s.cooldown * (1 + F.economy.upgrade_damage * f.upgrades)
  return dps, s.hp * 1.1 ^ f.tech
end

-- Défense d'une cible : un avant-poste (1 tourelle ≈ 8 fusiliers + 30 % de la garnison qui accourt)
-- tant qu'il en reste, sinon le QG (4 tourelles + toute la garnison).
local function defenders_of(def)
  if #def.outposts > 0 then return 8 * F.outpost_turrets(def.tech) + 0.3 * def.garrison, 0.3 end
  return F.military.hq_turrets * 8 + def.garrison, 1
end

local function combat(att_count, att, def)
  -- Lanchester (loi carrée).
  local a_dps, a_hp = unit_power(att, F.best_soldier(att.tech))
  local d_dps, d_hp = unit_power(def, F.best_soldier(def.tech))
  local defenders, committed = defenders_of(def)
  local a_str = att_count ^ 2 * a_dps * a_hp
  local d_str = defenders ^ 2 * d_dps * d_hp
  if a_str > d_str then
    local surv = math.floor(att_count * math.sqrt(1 - d_str / a_str))
    return true, surv, math.floor(def.garrison * (1 - committed))
  else
    local surv = math.floor(defenders * math.sqrt(1 - a_str / d_str))
    local lost = math.min(def.garrison * committed, defenders - surv)
    return false, 0, math.max(0, math.floor(def.garrison - lost))
  end
end

local report_at = { 5, 10, 15, 20, 30, 45, 60, 90, 120 }
local next_report = 1
local rows = {}

while t <= MINUTES * 60 do
  -- économie
  for _, f in ipairs(factions) do
    local gain = income(f) * DT
    local share = F.research_share(f.personality)
    f.research_fund = f.research_fund + gain * share
    f.mu = f.mu + gain * (1 - share)
    local still = {}
    for _, done_at in ipairs(f.busy) do
      if done_at <= t then
        f.outposts[#f.outposts + 1] = F.economy.drills_per_outpost
        f.pending = f.pending - 1
        f.stats.built = f.stats.built + 1
      else
        still[#still + 1] = done_at
      end
    end
    f.busy = still
  end
  -- combats arrivés
  for _, f in ipairs(factions) do
    local still = {}
    for _, g in ipairs(f.groups) do
      if g.arrive <= t and not g.done then
        local target = factions[g.target]
        local win, surv, def_left = combat(g.count, f, target)
        f.stats.losses = f.stats.losses + (g.count - surv)
        target.stats.losses = target.stats.losses + (target.garrison - def_left)
        target.soldiers = target.soldiers - (target.garrison - def_left)
        target.garrison = def_left
        target.turrets_low = F.military.hq_turrets
        f.soldiers = f.soldiers - (g.count - surv)
        if win and surv >= F.RAID_MIN_SURVIVORS and #target.outposts > 0 then
          table.remove(target.outposts)
          target.sites = target.sites + 1
          f.sites = f.sites + 1
          target.stats.lost_outposts = target.stats.lost_outposts + 1
        end
        g.done = true
        g.count = surv
        g.back = t + TRAVEL
      end
      if g.done and g.back <= t then
        f.garrison = f.garrison + g.count
      else
        still[#still + 1] = g
      end
    end
    f.groups = still
  end
  -- décisions
  for _, f in ipairs(factions) do
    local threatened = false
    for _, other in ipairs(factions) do
      for _, g in ipairs(other.groups) do
        if g.target == f.id and not g.done and g.arrive - t < 30 then threatened = true end
      end
    end
    local others_v = {}
    for _, o in ipairs(factions) do
      if o.id ~= f.id then others_v[#others_v + 1] = { id = o.id, outposts = #o.outposts } end
    end
    local rival = factions[F.pick_target(#f.outposts, f.id % #factions + 1, others_v)]
    local d, committed = defenders_of(rival)
    local enemy_defense = (d - rival.garrison * committed) + rival.garrison * committed * S.soldier_strength(F.best_soldier(rival.tech), rival.tech, rival.upgrades)
    local view = {
      mu = f.mu, income = income(f), tech = f.tech, personality = f.personality,
      engineers = f.engineers, engineers_idle = f.engineers - #f.busy, engineers_max = F.defaults.engineers_max,
      outposts = #f.outposts, outposts_pending = f.pending, sites_available = f.sites > 0,
      soldiers = f.soldiers, soldiers_max = F.defaults.soldiers_max, garrison = f.garrison, groups = #f.groups,
      threatened = threatened, enemy_defense = enemy_defense, turrets_low = f.turrets_low or 0, upgrades = f.upgrades, research_fund = f.research_fund,
    }
    for _, a in ipairs(S.decide(view)) do
      if a.kind == "recruit_engineer" and f.mu >= F.economy.engineer_cost then
        f.mu = f.mu - F.economy.engineer_cost
        f.engineers = f.engineers + 1
      elseif a.kind == "build_outpost" and f.mu >= F.economy.outpost_cost and f.sites > 0 then
        f.mu = f.mu - F.economy.outpost_cost
        f.sites = f.sites - 1
        f.pending = f.pending + 1
        f.busy[#f.busy + 1] = t + OUTPOST_TRIP
      elseif a.kind == "research" and f.research_fund >= a.from_fund and f.mu >= a.from_mu then
        f.research_fund = f.research_fund - a.from_fund
        f.mu = f.mu - a.from_mu
        f.tech = f.tech + 1
      elseif a.kind == "train" then
        local cost = F.soldiers[a.unit].cost * a.count
        if f.mu >= cost then
          f.mu = f.mu - cost
          f.soldiers = f.soldiers + a.count
          f.garrison = f.garrison + a.count
        end
      elseif a.kind == "attack" and a.count <= f.garrison then
        local others = {}
        for _, o in ipairs(factions) do
          if o.id ~= f.id then others[#others + 1] = { id = o.id, outposts = #o.outposts } end
        end
        local best = factions[F.pick_target(#f.outposts, f.id % #factions + 1, others)]
        f.garrison = f.garrison - a.count
        f.groups[#f.groups + 1] = { count = a.count, target = best.id, arrive = t + TRAVEL }
        f.stats.attacks = f.stats.attacks + 1
      elseif a.kind == "upgrade" and f.mu >= F.upgrade_cost(f.upgrades) then
        f.mu = f.mu - F.upgrade_cost(f.upgrades)
        f.upgrades = f.upgrades + 1
      elseif a.kind == "refill_turrets" then
        f.mu = f.mu - a.count * F.economy.turret_refill_mags * F.economy.mag_cost
        f.turrets_low = 0
      end
    end
  end
  if report_at[next_report] and t >= report_at[next_report] * 60 then
    for _, f in ipairs(factions) do
      rows[#rows + 1] = string.format("| %3d min | %-8s | %-10s | %7.0f | %5.1f | %d+%d | %2d | %3d | %3d | %2d | %3d |",
        report_at[next_report], f.key, f.personality, f.mu, income(f), f.tech, f.upgrades, #f.outposts, f.soldiers, f.garrison,
        f.stats.attacks, f.stats.losses)
    end
    next_report = next_report + 1
  end
  t = t + DT
end

print("| Temps | Faction | Personnalité | MU | Revenu MU/s | Tech+amél. | Avant-postes | Soldats | Garnison | Attaques | Pertes |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for _, r in ipairs(rows) do print(r) end
