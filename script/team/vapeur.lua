--[[
  Lot VAPEUR (14/11, P0 énergie) : relevé des centrales à vapeur de chaque équipe (règles pures : shared/team/vapeur.lua).
  Toutes les V.EVERY ticks, par équipe (ordre fixe : State.alive puis player) :
  - DEMANDE NOMINALE : entités électriques consommatrices posées par la force (LuaForce.get_entity_count, noms triés), × leur puissance
    maximale lue aux PROTOTYPES (max_energy_usage + ponction à vide de la source électrique) ; aucun nom d'objet en dur ;
  - CAPACITÉ NOMINALE : min(machines à vapeur, chaudières) de la force, lue aux prototypes (type « generator » : max_power_output ;
    type « boiler » : max_energy_production) ; + les machines des chantiers de centrale ouverts (projets du plan directeur) ;
  - ALIMENTATION : chaudières des centrales du plan directeur avec du combustible, centrales nourries par des foreuses (projet
    d'alimentation fini ou partie « foreuses », Cc.automated) ;
  - journal [FO-VAPEUR] ; f.build.vapeur = { missing, demand, cap, tick } est lu par script/team/plant_arms.lua (PA.watch) : la centrale
    s'étend sur la demande nominale × 1,3 AVANT toute baisse de tension.
  Chargé par script/team/plant_arms.lua (control.lua inchangé). Abonnement par le bus Events.
]]
local Events = require("script.core.events")
local State = require("script.faction.state")
local M = require("shared.team.modules")
local V = require("shared.team.vapeur")
local Cc = require("shared.team.charbon_centrale")

local Vap = {}

-- Données dérivées des prototypes (pas de `global` : refaites à chaque chargement). Listes TRIÉES par nom.
local PROTOS = nil
local function read(proto, key)
  local ok, v = pcall(function() return proto[key] end)
  if ok then return v end
  return nil
end
local CONSUMER_PRIO = { ["secondary-input"] = true, ["primary-input"] = true }
local function protos()
  if PROTOS then return PROTOS end
  local names = {}
  for name in pairs(game.entity_prototypes) do names[#names + 1] = name end
  table.sort(names)
  local out = { consumers = {}, generators = {}, boilers = {} }
  for _, name in ipairs(names) do
    local pr = game.entity_prototypes[name]
    local ty = read(pr, "type")
    if ty == "generator" then
      local w = tonumber(read(pr, "max_power_output")) or 0
      if w > 0 then out.generators[#out.generators + 1] = { name = name, kw = w * 60 / 1000 } end
    elseif ty == "boiler" then
      local w = tonumber(read(pr, "max_energy_production")) or 0
      if w > 0 then out.boilers[#out.boilers + 1] = { name = name, kw = w * 60 / 1000 } end
    else
      local es = read(pr, "electric_energy_source_prototype")
      if es then
        local prio = read(es, "usage_priority")
        if CONSUMER_PRIO[prio] then
          local w = (tonumber(read(pr, "max_energy_usage")) or 0) + (tonumber(read(es, "drain")) or 0)
          if w > 0 then out.consumers[#out.consumers + 1] = { name = name, kw = w * 60 / 1000 } end
        end
      end
    end
  end
  PROTOS = out
  return out
end

local function rows_of(force, list)
  local rows = {}
  for _, it in ipairs(list) do
    local n = force.get_entity_count(it.name) or 0
    if n > 0 then rows[#rows + 1] = { count = n, kw = it.kw } end
  end
  return rows
end

local function plant_ids(b)
  local ids = {}
  if b.plant then ids[#ids + 1] = b.plant end
  for _, id in ipairs(b.extra_plants or {}) do if id ~= b.plant then ids[#ids + 1] = id end end
  return ids
end

local function boiler_fed(r)
  local inv = r.get_fuel_inventory and r.get_fuel_inventory()
  if inv and inv.valid and inv.get_item_count() > 0 then return true end
  local bu = r.burner
  return bu ~= nil and bu.currently_burning ~= nil and (bu.remaining_burning_fuel or 0) > 0
end

--- Relevé d'une équipe : rend l'évènement de la ligne (et le range dans f.build.vapeur).
function Vap.census(f, tick)
  local b = f.build
  local force = game.forces[f.force or "player"]
  local surface = f.hq and f.hq.valid and f.hq.surface or nil
  if not (b and force and surface and force.get_entity_count) then return nil end
  local P = protos()
  local demand = V.demand_kw(rows_of(force, P.consumers))
  local cap = V.capacity_kw(V.demand_kw(rows_of(force, P.generators)), #P.boilers > 0 and V.demand_kw(rows_of(force, P.boilers)) or nil)
  local pending, fed, boilers, auto, plants, hand = 0, 0, 0, 0, 0, {}
  for _, pid in ipairs(plant_ids(b)) do
    local p = b.projects[pid]
    if p and p.state ~= "refuse" and not (p.state == "bloque" and not p.retry_at) then
      if p.state == "fini" or (p.reopened and p.finished) then -- (une centrale rouverte pour une pièce détruite reste une centrale bâtie)
        plants = plants + 1
        local kinds = {}
        for _, pt in ipairs(p.parts or {}) do kinds[#kinds + 1] = pt and pt.kind or "?" end
        local st = b.charbon and b.charbon[p.id]
        local alim = st and st.alim and b.projects[st.alim] or nil
        if Cc.automated(kinds, alim and alim.state or nil) then auto = auto + 1 else hand[#hand + 1] = tostring(p.id) end
        for _, e in ipairs(p.ents or {}) do
          local sp = M.spec(e.name)
          if sp and sp.water and sp.burner_kw then
            boilers = boilers + 1
            local r = surface.find_entity(e.name, { e.x, e.y })
            if r and r.valid and r.force.name == force.name and boiler_fed(r) then fed = fed + 1 end
          end
        end
      elseif not p.reopened then
        for _, e in ipairs(p.ents or {}) do
          local sp = M.spec(e.name)
          if sp and sp.power_out then pending = pending + sp.power_out end
        end
      end
    end
  end
  local missing = V.missing_kw(demand, cap, pending)
  local g = b.grow
  local sat = nil
  if g and (g.capacity or 0) > 0 then sat = math.min(1, (g.power or 0) / g.capacity) end
  b.vapeur = { missing = missing, demand = demand, cap = cap, pending = pending, fed = fed, boilers = boilers, tick = tick }
  return { team = f.key or "player", tick = tick, demand = demand, cap = cap, pending = pending, missing = missing,
    fed = fed, boilers = boilers, auto = auto, plants = plants, hand = table.concat(hand, ","), sat = sat }
end

local function teams()
  local out = {}
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and f.build then out[#out + 1] = f end
  end
  local pf = State.faction("player")
  if pf and pf.build then out[#out + 1] = pf end
  return out
end

Events.on_nth_tick(V.EVERY, function(e)
  for _, f in ipairs(teams()) do
    if f.hq and f.hq.valid then
      local ev = Vap.census(f, e.tick)
      if ev then
        f.build.vapeur_logs = (f.build.vapeur_logs or 0) + 1
        if f.build.vapeur_logs <= V.LOGS then log(V.line(ev)) end
      end
    end
  end
end)

return Vap
