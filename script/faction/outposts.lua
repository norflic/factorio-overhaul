--[[
  Avant-postes d'équipe : VRAIS bâtiments qui tournent (économie réelle, session 4).

  Un avant-poste = des foreuses à combustible posées sur un gisement, chacune déversant dans un four
  (minerais : plaques fondues sur place) ou un coffre (charbon, pierre). Les ouvriers les construisent avec
  des objets du stock, les ravitaillent en charbon et rapportent la production au QG.
  La fonderie du QG (fours alimentés à la main) produit acier et briques.

  outpost = { id, kind, pos, drills (nombre vivant), drill_list, sinks, turret_list, last_service }
]]

local F = require("shared.faction.config")
local T = require("shared.team.config")
local State = require("script.faction.state")
local Sites = require("script.faction.sites")

local Outposts = {}

local DIRS = { defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west }
local MAX_ATTEMPTS = 40

-- Point de dépôt de la foreuse à combustible vanilla (vector_to_place_result = {-0.5, -1.3} vers le nord),
-- tourné selon l'orientation (sens horaire).
local function drop_vector(dir)
  local x, y = T.drill_drop[1], T.drill_drop[2]
  if dir == defines.direction.east then return { -y, x } end
  if dir == defines.direction.south then return { -x, -y } end
  if dir == defines.direction.west then return { y, -x } end
  return { x, y }
end

local function valid_list(list)
  local out = {}
  for _, e in ipairs(list or {}) do if e.valid then out[#out + 1] = e end end
  return out
end

function Outposts.ammo_name(tech)
  return T.turret_ammo
end

function Outposts.add_turret(f, turret, oid, ammo_count)
  if ammo_count and ammo_count > 0 then turret.insert({ name = Outposts.ammo_name(f.tech), count = ammo_count }) end
  f.turrets[turret.unit_number] = turret
  State.own(turret, f.id, "turret", oid)
  if oid and f.outposts[oid] then
    local o = f.outposts[oid]
    o.turret_list = o.turret_list or {}
    o.turret_list[#o.turret_list + 1] = turret
  end
end

---------------------------------------------------------------------------------------------------
-- Pose
---------------------------------------------------------------------------------------------------
--- Emplacement du réceptacle (four 2×2 ou coffre 1×1) couvrant le point de dépôt d'une foreuse.
local function sink_position(surface, sink, drop, force, drill_pos)
  if sink == "stone-furnace" then
    local best, best_d
    for dx = 0, 1 do
      for dy = 0, 1 do
        local c = { x = math.floor(drop.x) + dx, y = math.floor(drop.y) + dy }
        if math.abs(c.x - drop.x) <= 1 and math.abs(c.y - drop.y) <= 1
          and surface.can_place_entity({ name = sink, position = c, force = force }) then
          local d = (c.x - drill_pos.x) ^ 2 + (c.y - drill_pos.y) ^ 2
          if not best_d or d > best_d then best, best_d = c, d end
        end
      end
    end
    return best
  end
  local c = { x = math.floor(drop.x) + 0.5, y = math.floor(drop.y) + 0.5 }
  if surface.can_place_entity({ name = sink, position = c, force = force }) then return c end
  return nil
end

--- Pose jusqu'à `max_pairs` paires foreuse + réceptacle sur le gisement `kind` autour de `center`, avec
--- les objets portés par `carrier` (inventaire de l'ouvrier). Renvoie drills, sinks.
local function place_pairs(f, surface, kind, center, carrier, max_pairs, radius)
  local spec = T.outposts[kind]
  local force = f.force
  -- L'ouvrier dégage le chantier : arbres et rochers abattus (le bois revient à l'équipe).
  for _, e in ipairs(surface.find_entities_filtered({ position = center, radius = radius, type = { "tree", "simple-entity" } })) do
    if e.valid then
      if e.type == "tree" then carrier.insert({ name = "wood", count = 4 }) end
      e.destroy()
    end
  end
  local resources = surface.find_entities_filtered({ position = center, radius = radius, name = spec.resource })
  table.sort(resources, function(a, b)
    local pa, pb = a.position, b.position
    local da = (pa.x - center.x) ^ 2 + (pa.y - center.y) ^ 2
    local db = (pb.x - center.x) ^ 2 + (pb.y - center.y) ^ 2
    if da ~= db then return da < db end
    if pa.x ~= pb.x then return pa.x < pb.x end
    return pa.y < pb.y
  end)
  -- Moteur réel (session 4) : poser une foreuse pour lire son point de dépôt, puis la détruire quand le
  -- réceptacle ne passait pas, coûtait jusqu'à 400 ms sur un gisement déjà occupé (centaines de tuiles ×
  -- 4 orientations). Le point de dépôt est désormais calculé (vecteur du prototype vanilla), chaque
  -- emplacement n'est essayé qu'une fois et le nombre d'essais est plafonné.
  local drills, sinks = {}, {}
  local tried, attempts = {}, 0
  for _, res in ipairs(resources) do
    if #drills >= max_pairs or attempts >= MAX_ATTEMPTS then break end
    if carrier.get_item_count(T.DRILL) < 1 or carrier.get_item_count(spec.sink) < 1 then break end
    local rp = res.position
    local pos = { x = math.floor(rp.x + 0.5), y = math.floor(rp.y + 0.5) } -- foreuse 2×2 : centre entier
    local key = pos.x * 65536 + pos.y
    if not tried[key] then
      tried[key] = true
      attempts = attempts + 1
    else
      pos = nil
    end
    for _, dir in ipairs(pos and DIRS or {}) do
      local v = drop_vector(dir)
      local drop = { x = pos.x + v[1], y = pos.y + v[2] }
      local spos = sink_position(surface, spec.sink, drop, force, pos)
      if spos and surface.can_place_entity({ name = T.DRILL, position = pos, direction = dir, force = force }) then
        local d = surface.create_entity({ name = T.DRILL, position = pos, direction = dir, force = force })
        if d then
          local s = surface.can_place_entity({ name = spec.sink, position = spos, force = force })
            and surface.create_entity({ name = spec.sink, position = spos, force = force })
          if s then
            carrier.remove({ name = T.DRILL, count = 1 })
            carrier.remove({ name = spec.sink, count = 1 })
            local burners = s.type == "furnace" and { d, s } or { d }
            for _, b in ipairs(burners) do
              local n = math.min(T.fuel_per_burner, carrier.get_item_count(T.fuel))
              if n > 0 then b.get_fuel_inventory().insert({ name = T.fuel, count = carrier.remove({ name = T.fuel, count = n }) }) end
            end
            drills[#drills + 1] = d
            sinks[#sinks + 1] = s
            break
          end
          d.destroy()
        end
      end
    end
  end
  return drills, sinks
end

--- Pose l'avant-poste `kind` autour de `site` avec les objets portés par `carrier` (inventaire de
--- l'ouvrier). Renvoie l'avant-poste (au moins une paire posée) ou nil.
function Outposts.build(f, surface, kind, site, carrier)
  local spec = T.outposts[kind]
  local drills, sinks = place_pairs(f, surface, kind, site, carrier, spec.drills, 14)
  if #drills == 0 then return nil end
  f.next_oid = f.next_oid + 1
  local oid = f.next_oid
  local outpost = {
    id = oid, kind = kind, pos = { x = site.x, y = site.y }, drills = #drills,
    drill_list = drills, sinks = sinks, turret_list = {}, last_service = game.tick,
  }
  for _, d in ipairs(drills) do State.own(d, f.id, "drill", oid) end
  for _, s in ipairs(sinks) do State.own(s, f.id, "sink", oid) end
  f.outposts[oid] = outpost
  f.outposts_count = f.outposts_count + 1
  f.stats.outposts_built = f.stats.outposts_built + 1
  return outpost
end

--- Agrandit un avant-poste existant (même gisement). Renvoie le nombre de paires ajoutées ; à 0 ou au
--- plafond, l'avant-poste est marqué plein.
function Outposts.extend(f, surface, o, carrier)
  local spec = T.outposts[o.kind]
  local room = T.max_drills(o.kind) - o.drills
  local drills, sinks = place_pairs(f, surface, o.kind, o.pos, carrier, math.min(spec.drills, room), 18)
  for _, d in ipairs(drills) do
    o.drill_list[#o.drill_list + 1] = d
    State.own(d, f.id, "drill", o.id)
  end
  for _, s in ipairs(sinks) do
    o.sinks[#o.sinks + 1] = s
    State.own(s, f.id, "sink", o.id)
  end
  o.drills = o.drills + #drills
  if #drills == 0 or o.drills >= T.max_drills(o.kind) then o.full = true end
  return #drills
end

local TURRET_OFFSETS = { { 7, 7 }, { -7, -7 }, { 7, -7 }, { -7, 7 }, { 9, 0 }, { -9, 0 }, { 0, 9 }, { 0, -9 } }

--- Pose jusqu'à `count` tourelles autour de l'avant-poste avec les objets portés.
function Outposts.fortify(f, surface, outpost, count, carrier)
  local placed = 0
  for _, o in ipairs(TURRET_OFFSETS) do
    if placed >= count or carrier.get_item_count("gun-turret") < 1 then break end
    local pos = surface.find_non_colliding_position("gun-turret", { x = outpost.pos.x + o[1], y = outpost.pos.y + o[2] }, 4, 1)
    if pos then
      local t = surface.create_entity({ name = "gun-turret", position = pos, force = f.force, raise_built = true })
      if t then
        carrier.remove({ name = "gun-turret", count = 1 })
        for _, ammo in ipairs({ "piercing-rounds-magazine", "firearm-magazine" }) do
          local n = math.min(T.turret_ammo_target - t.get_item_count(), carrier.get_item_count(ammo))
          if n > 0 then t.insert({ name = ammo, count = carrier.remove({ name = ammo, count = n }) }) end
        end
        Outposts.add_turret(f, t, outpost.id, 0)
        placed = placed + 1
      end
    end
  end
  return placed
end

---------------------------------------------------------------------------------------------------
-- Fonderie du QG
---------------------------------------------------------------------------------------------------
local SMELTER_OFFSETS = { { 9, -7 }, { 11, -7 }, { 13, -7 }, { 15, -7 }, { 9, -10 }, { 11, -10 } }

function Outposts.place_smelters(f, surface, count, carrier)
  f.smelters = f.smelters or {}
  local placed = 0
  for _, o in ipairs(SMELTER_OFFSETS) do
    if placed >= count or carrier.get_item_count(T.SMELTER) < 1 then break end
    local pos = surface.find_non_colliding_position(T.SMELTER, { x = f.hq_pos.x + o[1], y = f.hq_pos.y + o[2] }, 4, 1)
    if pos then
      local s = surface.create_entity({ name = T.SMELTER, position = pos, force = f.force, raise_built = true })
      if s then
        carrier.remove({ name = T.SMELTER, count = 1 })
        local n = math.min(T.fuel_per_burner, carrier.get_item_count(T.fuel))
        if n > 0 then s.get_fuel_inventory().insert({ name = T.fuel, count = carrier.remove({ name = T.fuel, count = n }) }) end
        f.smelters[#f.smelters + 1] = s
        State.own(s, f.id, "smelter")
        placed = placed + 1
      end
    end
  end
  return placed
end

function Outposts.smelters(f)
  f.smelters = valid_list(f.smelters)
  return f.smelters
end

---------------------------------------------------------------------------------------------------
-- Vue (pour le cerveau d'équipe) et entretien
---------------------------------------------------------------------------------------------------
local function fuel_of(e)
  local inv = e.get_fuel_inventory()
  return inv and inv.get_item_count(T.fuel) or 0
end

local function output_of(e)
  if e.type == "furnace" then return e.get_output_inventory().get_item_count() end
  if e.type == "container" then return e.get_inventory(defines.inventory.chest).get_item_count() end
  return 0
end

function Outposts.burners(o)
  local list = {}
  for _, d in ipairs(valid_list(o.drill_list)) do list[#list + 1] = d end
  for _, s in ipairs(valid_list(o.sinks)) do if s.type == "furnace" then list[#list + 1] = s end end
  return list
end

--- État d'un avant-poste : brûleur à court de charbon, production en attente, tourelles.
function Outposts.status(o, tick)
  local low, output = false, 0
  for _, b in ipairs(Outposts.burners(o)) do
    if fuel_of(b) < T.fuel_low then low = true end
  end
  for _, s in ipairs(valid_list(o.sinks)) do output = output + output_of(s) end
  o.turret_list = valid_list(o.turret_list)
  return { fuel_low = low, output = output, turrets = #o.turret_list, idle_ticks = tick - (o.last_service or 0) }
end

--- Charbon à apporter pour compléter tous les brûleurs d'une liste.
function Outposts.coal_needed_for(burners)
  local n = 0
  for _, b in ipairs(burners) do n = n + math.max(0, T.fuel_refill_to - fuel_of(b)) end
  return n
end

function Outposts.coal_needed(o)
  return Outposts.coal_needed_for(Outposts.burners(o))
end

--- Ramasse la production des réceptacles dans l'inventaire de l'ouvrier. Renvoie le nombre d'objets.
local function collect(sinks, carrier)
  local collected = 0
  for _, s in ipairs(sinks) do
    local inv = s.type == "container" and s.get_inventory(defines.inventory.chest) or s.get_output_inventory()
    for name, n in pairs(inv.get_contents()) do
      local moved = carrier.insert({ name = name, count = n })
      if moved > 0 then inv.remove({ name = name, count = moved }) end
      collected = collected + moved
    end
  end
  return collected
end

local function refuel(burners, carrier)
  for _, b in ipairs(burners) do
    local n = math.min(T.fuel_refill_to - fuel_of(b), carrier.get_item_count(T.fuel))
    if n > 0 then b.get_fuel_inventory().insert({ name = T.fuel, count = carrier.remove({ name = T.fuel, count = n }) }) end
  end
end

--- Tournée sur place : ramasse la production (un avant-poste de charbon se ravitaille sur la sienne) puis
--- complète le charbon de chaque brûleur. Renvoie le nombre d'objets ramassés.
function Outposts.service(o, carrier, tick)
  local collected = collect(valid_list(o.sinks), carrier)
  refuel(Outposts.burners(o), carrier)
  o.last_service = tick
  return collected
end

--- Fonderie du QG : vide les sorties, charge les entrées selon `smelt` ({ [produit] = n }), ravitaille.
function Outposts.service_smelters(f, carrier, smelt)
  local list = Outposts.smelters(f)
  local collected = collect(list, carrier)
  -- Un produit par four, dans l'ordre des demandes (tri déterministe).
  local products = {}
  for p in pairs(smelt or {}) do products[#products + 1] = p end
  table.sort(products)
  local i = 0
  for _, s in ipairs(list) do
    local src = s.get_inventory(defines.inventory.furnace_source)
    if src.is_empty() and #products > 0 then
      i = i % #products + 1
      local input = T.smelter_inputs[products[i]]
      if input then
        local n = math.min(input[2] * 10, carrier.get_item_count(input[1]))
        if n > 0 then src.insert({ name = input[1], count = carrier.remove({ name = input[1], count = n }) }) end
      end
    end
  end
  refuel(list, carrier)
  return collected
end

function Outposts.smelters_status(f)
  local out, low = 0, false
  for _, s in ipairs(Outposts.smelters(f)) do
    out = out + s.get_output_inventory().get_item_count()
    if fuel_of(s) < T.fuel_low then low = true end
  end
  return out, low
end

---------------------------------------------------------------------------------------------------
-- Tourelles : groupes (QG, avant-postes) et ravitaillement
---------------------------------------------------------------------------------------------------
local function ammo_of(t)
  local inv = t.get_inventory(defines.inventory.turret_ammo)
  return inv and inv.get_item_count() or 0
end

--- Groupes de tourelles : { key, pos, list, low } ; key = "hq" ou "o<id d'avant-poste>".
function Outposts.turret_groups(f)
  local groups, by_key = {}, {}
  for _, id in ipairs(State.sorted_keys(f.turrets)) do
    local t = f.turrets[id]
    if t.valid then
      local owner = State.owner(id)
      local oid = owner and owner.oid
      local key = oid and ("o" .. oid) or "hq"
      local g = by_key[key]
      if not g then
        local pos = f.hq_pos
        if oid then pos = f.outposts[oid] and f.outposts[oid].pos or t.position end
        g = { key = key, pos = pos, list = {}, low = 0 }
        by_key[key] = g
        groups[#groups + 1] = g
      end
      g.list[#g.list + 1] = t
      if ammo_of(t) < T.turret_ammo_low then g.low = g.low + 1 end
    else
      f.turrets[id] = nil
    end
  end
  return groups, by_key
end

--- Ravitaille les tourelles du groupe avec les munitions portées. Renvoie chargeurs posés.
function Outposts.refill_group(f, key, carrier)
  local _, by_key = Outposts.turret_groups(f)
  local g = by_key[key]
  if not g then return 0 end
  local put = 0
  for _, t in ipairs(g.list) do
    local missing = T.turret_ammo_target - ammo_of(t)
    for _, ammo in ipairs({ "piercing-rounds-magazine", "firearm-magazine" }) do
      local n = math.min(missing, carrier.get_item_count(ammo))
      if n > 0 then
        local moved = t.insert({ name = ammo, count = n })
        if moved > 0 then carrier.remove({ name = ammo, count = moved }) end
        missing = missing - moved
        put = put + moved
      end
    end
  end
  return put
end

function Outposts.group_pos(f, key)
  local _, by_key = Outposts.turret_groups(f)
  return by_key[key] and by_key[key].pos or nil
end

---------------------------------------------------------------------------------------------------
-- Pertes et ciblage
---------------------------------------------------------------------------------------------------
function Outposts.on_drill_lost(f, oid)
  local o = f.outposts[oid]
  if not o then return end
  o.drills = o.drills - 1
  if o.drills <= 0 then
    f.outposts[oid] = nil
    f.outposts_count = f.outposts_count - 1
    f.stats.outposts_lost = f.stats.outposts_lost + 1
    Sites.release(o.pos)
    -- Le gisement reste là : il revient à la réserve pour une reconstruction (règle du cerveau d'équipe).
    local spec = T.outposts[o.kind]
    if spec then
      f.prospects = f.prospects or {}
      f.prospects[#f.prospects + 1] = { x = o.pos.x, y = o.pos.y, resource = spec.resource, lost = true }
    end
  end
end

--- Position de l'avant-poste le plus proche d'un point (ou nil).
function Outposts.nearest(f, from)
  local best, best_d = nil, math.huge
  for _, oid in ipairs(State.sorted_keys(f.outposts)) do
    local p = f.outposts[oid].pos
    local dx, dy = p.x - from.x, p.y - from.y
    local d = dx * dx + dy * dy
    if d < best_d then best, best_d = p, d end
  end
  return best
end

function Outposts.turrets_wanted(tech)
  return F.outpost_turrets(tech)
end

return Outposts
