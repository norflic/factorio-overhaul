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
local Pl = require("shared.ai3.places") -- lot SCALE (correction) : places du QG depuis l'emprise du prototype
local PlacesQG = require("script.ai3.places_qg") -- lot SCALE (correction) : pose sur la grille, place vérifiée
local Charge = require("shared.team.charge_four") -- lot FOURS : charge d'un four à la pile (règle pure)

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
local function sink_position(surface, sink, drop, force, drill_pos, fits)
  -- lot FANTOMES : `fits(name, pos)` est la vérification de place (l'aperçu des paires en passe une autre) ; par défaut, celle de la pose.
  fits = fits or function(name, pos) return surface.can_place_entity({ name = name, position = pos, force = force }) end
  if sink == "stone-furnace" then
    local best, best_d
    for dx = 0, 1 do
      for dy = 0, 1 do
        local c = { x = math.floor(drop.x) + dx, y = math.floor(drop.y) + dy }
        if math.abs(c.x - drop.x) <= 1 and math.abs(c.y - drop.y) <= 1 and fits(sink, c) then
          local d = (c.x - drill_pos.x) ^ 2 + (c.y - drill_pos.y) ^ 2
          if not best_d or d > best_d then best, best_d = c, d end
        end
      end
    end
    return best
  end
  local c = { x = math.floor(drop.x) + 0.5, y = math.floor(drop.y) + 0.5 }
  if fits(sink, c) then return c end
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
      -- lot AUTO : jamais sur une tuile réservée par un projet du plan directeur (fantômes pas encore posés)
      -- (crochet Outposts.reserved, posé par script/team/build.lua : l'ordre des require et des abonnements ne change pas)
      if spos and Outposts.reserved and (Outposts.reserved(f, T.DRILL, pos, dir) or Outposts.reserved(f, spec.sink, spos)) then spos = nil end
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

--- Lot FANTOMES : APERÇU des paires que `place_pairs` poserait (sans objets, sans rien détruire ni poser) : même parcours des
--- tuiles de minerai, mêmes orientations, mêmes points de dépôt. Arbres et rochers ne comptent pas (l'ouvrier les abat avant de
--- poser : vérification « script_ghost » avec `forced`), et deux paires de l'aperçu ne se recouvrent pas. Rend une liste de
--- { drill = { name, position, direction }, sink = { name, position } }.
function Outposts.preview_pairs(f, surface, kind, center, max_pairs, radius)
  local spec = T.outposts[kind]
  local force = f.force
  local taken = {}
  local function tiles(name, pos, dir)
    local p = game.entity_prototypes[name]
    local w, h = p.tile_width or 1, p.tile_height or 1
    if dir == defines.direction.east or dir == defines.direction.west then w, h = h, w end
    local x0, y0 = math.floor(pos.x - w / 2 + 0.01), math.floor(pos.y - h / 2 + 0.01)
    local out = {}
    for ty = y0, y0 + h - 1 do
      for tx = x0, x0 + w - 1 do out[#out + 1] = tx * 65536 + ty end
    end
    return out
  end
  local function free(name, pos, dir)
    for _, k in ipairs(tiles(name, pos, dir)) do if taken[k] then return false end end
    return true
  end
  local function fits(name, pos, dir)
    return free(name, pos, dir) and surface.can_place_entity({ name = name, position = pos, direction = dir, force = force,
      build_check_type = defines.build_check_type.script_ghost, forced = true })
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
  local out, tried, attempts = {}, {}, 0
  for _, res in ipairs(resources) do
    if #out >= max_pairs or attempts >= MAX_ATTEMPTS then break end
    local rp = res.position
    local pos = { x = math.floor(rp.x + 0.5), y = math.floor(rp.y + 0.5) }
    local key = pos.x * 65536 + pos.y
    if not tried[key] then
      tried[key] = true
      attempts = attempts + 1
      for _, dir in ipairs(DIRS) do
        local v = drop_vector(dir)
        local drop = { x = pos.x + v[1], y = pos.y + v[2] }
        local spos = sink_position(surface, spec.sink, drop, force, pos, function(name, p) return fits(name, p, 0) end)
        if spos and fits(T.DRILL, pos, dir) then
          for _, k in ipairs(tiles(T.DRILL, pos, dir)) do taken[k] = true end
          for _, k in ipairs(tiles(spec.sink, spos, 0)) do taken[k] = true end
          out[#out + 1] = { drill = { name = T.DRILL, position = pos, direction = dir }, sink = { name = spec.sink, position = spos } }
          break
        end
      end
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Réceptacles orphelins (lot IA2-b, F209) : coffres et fours d'un avant-poste perdu, restés sur la carte
---------------------------------------------------------------------------------------------------
Outposts.ORPHAN_WAIT = 30 * 3600 -- démontage proposé 30 min après la perte (la reconstruction sur place passe avant)

local ORPHAN_INVENTORIES = {
  container = { defines.inventory.chest },
  furnace = { defines.inventory.furnace_source, defines.inventory.furnace_result, defines.inventory.fuel },
}

--- Démonte un réceptacle dans l'inventaire `carrier` : son contenu puis l'objet lui-même (ce qui ne tient pas est
--- perdu). Renvoie vrai si l'entité a été retirée.
local function dismantle(e, carrier)
  if not (e and e.valid) then return false end
  for _, id in ipairs(ORPHAN_INVENTORIES[e.type] or {}) do
    local inv = e.get_inventory(id)
    if inv then
      local contents = inv.get_contents()
      local names = {}
      for name in pairs(contents) do names[#names + 1] = name end
      table.sort(names)
      for _, name in ipairs(names) do
        local moved = carrier.insert({ name = name, count = contents[name] })
        if moved > 0 then inv.remove({ name = name, count = moved }) end
      end
    end
  end
  carrier.insert({ name = e.name, count = 1 })
  e.destroy()
  return true
end

--- Orphelins valides d'une faction (les invalides sont retirés de la liste).
function Outposts.orphans(f)
  local out = {}
  for _, o in ipairs(f.orphans or {}) do
    if o.e and o.e.valid then out[#out + 1] = o end
  end
  f.orphans = out
  return out
end

--- Reprise : les orphelins à moins de `radius` tuiles de `pos` sont démontés par l'ouvrier sur place (leurs objets
--- servent à la reconstruction). Renvoie le nombre repris.
function Outposts.reclaim(f, pos, carrier, radius)
  local n, keep = 0, {}
  for _, o in ipairs(Outposts.orphans(f)) do
    local dx, dy = o.x - pos.x, o.y - pos.y
    if dx * dx + dy * dy <= radius * radius and dismantle(o.e, carrier) then
      n = n + 1
    else
      keep[#keep + 1] = o
    end
  end
  f.orphans = keep
  if n > 0 then
    f.stats.orphans_reclaimed = (f.stats.orphans_reclaimed or 0) + n
    log(string.format("[FO-STRAT] orphelins tick %d %s : %d repris a la reconstruction (%d, %d), %d restants", game.tick,
      tostring(f.key), n, math.floor(pos.x), math.floor(pos.y), #keep))
  end
  return n
end

--- Démontage des orphelins d'un avant-poste perdu (`oid`) par un ouvrier venu exprès. Renvoie le nombre démontés.
function Outposts.salvage(f, oid, carrier)
  local n, keep = 0, {}
  for _, o in ipairs(Outposts.orphans(f)) do
    if o.oid == oid and dismantle(o.e, carrier) then n = n + 1 else keep[#keep + 1] = o end
  end
  f.orphans = keep
  if n > 0 then
    f.stats.orphans_salvaged = (f.stats.orphans_salvaged or 0) + n
    log(string.format("[FO-STRAT] orphelins tick %d %s : %d demontes (avant-poste perdu %d), %d restants", game.tick,
      tostring(f.key), n, oid, #keep))
  end
  return n
end

--- Groupes d'orphelins prêts au démontage (perdus depuis ORPHAN_WAIT), un par avant-poste perdu, triés par numéro.
function Outposts.orphan_groups(f, tick)
  local by, list = {}, {}
  for _, o in ipairs(Outposts.orphans(f)) do
    if tick - (o.tick or 0) >= Outposts.ORPHAN_WAIT then
      local g = by[o.oid]
      if not g then
        g = { oid = o.oid, x = o.x, y = o.y, n = 0 }
        by[o.oid] = g
        list[#list + 1] = g
      end
      g.n = g.n + 1
    end
  end
  table.sort(list, function(a, b) return a.oid < b.oid end)
  return list
end

--- Pose l'avant-poste `kind` autour de `site` avec les objets portés par `carrier` (inventaire de
--- l'ouvrier). Renvoie l'avant-poste (au moins une paire posée) ou nil.
-- Crochet posé par script/team/fantomes.lua : le PNJ arrive et va poser, l'aperçu en fantômes de sa tâche part d'abord.
Outposts.on_arrive = nil

function Outposts.build(f, surface, kind, site, carrier)
  local spec = T.outposts[kind]
  if Outposts.on_arrive then Outposts.on_arrive(f, site, nil) end
  -- Lot IA2-b (F209) : les réceptacles orphelins d'un avant-poste perdu ici sont repris d'abord (ils libèrent la
  -- place des paires et leurs objets resservent).
  Outposts.reclaim(f, site, carrier, 24)
  local drills, sinks = place_pairs(f, surface, kind, site, carrier, spec.drills, 14)
  if #drills == 0 then return nil end
  f.next_oid = f.next_oid + 1
  local oid = f.next_oid
  local outpost = {
    id = oid, kind = kind, pos = { x = site.x, y = site.y }, drills = #drills,
    drill_list = drills, sinks = sinks, turret_list = {}, last_service = game.tick,
    -- Lot IA2-b : lectures du site (carte de valeur), rendues à la réserve si l'avant-poste est perdu.
    site_info = { rich = site.rich, tiles = site.tiles, water = site.water, rough = site.rough, cliffs = site.cliffs },
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
  if Outposts.on_arrive then Outposts.on_arrive(f, nil, o.id) end
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
  if #drills == 0 or o.drills >= T.max_drills(o.kind) then
    o.full = true
    o.hold_until = nil -- plein pour de bon (et non en attente après des échecs, lot ADOPTE)
  end
  if #drills > 0 then o.ext_fails = 0 end
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
-- Fours du QG (lot SCALE, correction après revue) : places en rangées depuis l'EMPRISE du four (collision_box du
-- prototype) et la disposition nommée de shared/team/config.lua (T.hq_rows.smelter), recalées sur la grille et VÉRIFIÉES
-- avant la pose (script/ai3/places_qg.lua : la pose d'avant chevauchait, capture s4-qg). Bloc de départ = places de main.
function Outposts.place_smelters(f, surface, count, carrier)
  f.smelters = f.smelters or {}
  return PlacesQG.place(surface, T.SMELTER, f.force, f.hq_pos, T.hq_rows.smelter,
    Pl.need(#f.smelters, count, T.hq_rows_slack), count, function(pos)
      if carrier.get_item_count(T.SMELTER) < 1 then return nil end
      local s = surface.create_entity({ name = T.SMELTER, position = pos, force = f.force, raise_built = true })
      if not (s and s.valid) then return false end
      carrier.remove({ name = T.SMELTER, count = 1 })
      local n = math.min(T.fuel_per_burner, carrier.get_item_count(T.fuel))
      if n > 0 then s.get_fuel_inventory().insert({ name = T.fuel, count = carrier.remove({ name = T.fuel, count = n }) }) end
      f.smelters[#f.smelters + 1] = s
      State.own(s, f.id, "smelter")
      return true
    end)
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

-- Lot FOURS : interrupteur de banc de la règle (`fo-ia1`, set_regle_four) ; allumée par défaut. Éteinte : le comportement de
-- 0.6.10 (10 fabrications au plus dans un four vide, tournée dès qu'une plaque attend), pour les témoins des bancs.
function Outposts.four_rule(f)
  return not (f.team and f.team.four_regle == false)
end

-- Entrée de fonderie -> plus petite (RATIO) et plus grande (MAXR) quantité par fabrication (T.smelter_inputs, listes triées).
local RATIO, MAXR = {}, {}
for _, p in ipairs(State.sorted_keys(T.smelter_inputs)) do
  local inp = T.smelter_inputs[p]
  if not RATIO[inp[1]] or inp[2] < RATIO[inp[1]] then RATIO[inp[1]] = inp[2] end
  if not MAXR[inp[1]] or inp[2] > MAXR[inp[1]] then MAXR[inp[1]] = inp[2] end
end

local function stack_of(item)
  local proto = game.item_prototypes[item]
  return proto and proto.stack_size or 50
end

local function demanded_item(products, item)
  for _, p in ipairs(products) do
    local inp = T.smelter_inputs[p]
    if inp and inp[1] == item then return true end
  end
  return false
end

-- Four dont l'entrée est inférieure à une fabrication et à l'arrêt : bloqué (son contenu est repris, il compte comme libre).
local function stuck(s, c)
  local r = c.valid_for_read and MAXR[c.name]
  return r and r > 1 and c.count < r and not s.is_crafting()
end

--- Lot FOURS : fours à charger, dans l'ordre de la fonderie. `products` = produits demandés (triés). Un four vide reçoit un
--- produit à tour de rôle ; un four tombé au tiers de sa pile est complété avec SON entrée (une entrée qui est elle-même un
--- produit de fonte, la plaque de l'acier, seulement pour une demande). Rend { { s, item, ratio, room, free } ... }.
function Outposts.smelt_loads(f, products, list)
  local out, i = {}, 0
  for _, s in ipairs(list or Outposts.smelters(f)) do
    local c = s.get_inventory(defines.inventory.furnace_source)[1]
    if c and c.valid_for_read then
      local ratio = RATIO[c.name]
      if ratio and not stuck(s, c) and (not T.smelter_inputs[c.name] or demanded_item(products, c.name)) then
        local room = Charge.room(c.count, stack_of(c.name), ratio)
        if room >= ratio then out[#out + 1] = { s = s, item = c.name, ratio = ratio, room = room, free = false } end
      end
    elseif #products > 0 then
      i = i % #products + 1
      local input = T.smelter_inputs[products[i]]
      if input then
        local room = Charge.room(0, stack_of(input[1]), input[2])
        if room >= input[2] then out[#out + 1] = { s = s, item = input[1], ratio = input[2], room = room, free = true } end
      end
    end
  end
  return out
end

--- Fonderie du QG : vide les sorties, charge les entrées selon `smelt` ({ [produit] = n }), ravitaille. Rend (collecté,
--- chargé, combustible posé) ; f.stats.smelt compte les visites, dont celles « à vide » (rien chargé, rien vidé, rien ravitaillé).
function Outposts.service_smelters(f, carrier, smelt)
  local list = Outposts.smelters(f)
  local collected = collect(list, carrier)
  -- Un produit par four, dans l'ordre des demandes (tri déterministe).
  local products = {}
  for p in pairs(smelt or {}) do products[#products + 1] = p end
  table.sort(products)
  -- Étape 1 (27/10 au soir) : un four chargé de MOINS que la recette n'en exige (acier : 5 plaques, il en avait 1 à 4) ne
  -- fond jamais et n'était jamais rechargé (il n'est rechargé que vide) : 3 fours sur 4 morts à jamais, 0 acier en 40 min,
  -- donc aucun poteau moyen ou grand, aucune électrification. Ses entrées sont reprises par le porteur.
  local ratio = {}
  for _, p in ipairs(State.sorted_keys(T.smelter_inputs)) do
    local inp = T.smelter_inputs[p]
    if inp[2] > 1 then ratio[inp[1]] = math.max(ratio[inp[1]] or 0, inp[2]) end
  end
  local loaded = 0
  if Outposts.four_rule(f) then
    for _, s in ipairs(list) do
      local src = s.get_inventory(defines.inventory.furnace_source)
      if not src.is_empty() and not s.is_crafting() then
        local c = src[1]
        if c.valid_for_read and ratio[c.name] and c.count < ratio[c.name] then
          carrier.insert({ name = c.name, count = c.count })
          src.clear()
        end
      end
    end
    -- Lot FOURS (remarque 12 du DC) : chaque four à charger est rempli jusqu'à sa pile (shared/team/charge_four.lua), à égalité
    -- entre les fours qui reçoivent la même entrée.
    local items = {}
    for _, l in ipairs(Outposts.smelt_loads(f, products, list)) do
      items[l.item] = items[l.item] or {}
      local g = items[l.item]
      g[#g + 1] = l
    end
    for _, item in ipairs(State.sorted_keys(items)) do
      local g = items[item]
      local rooms = {}
      for k, l in ipairs(g) do rooms[k] = l.room end
      local amounts = Charge.split(carrier.get_item_count(item), rooms, g[1].ratio)
      for k, l in ipairs(g) do
        local n = amounts[k]
        if n > 0 then
          local took = carrier.remove({ name = item, count = n })
          local put = l.s.get_inventory(defines.inventory.furnace_source).insert({ name = item, count = took })
          if put < took then carrier.insert({ name = item, count = took - put }) end
          loaded = loaded + put
        end
      end
    end
  else
    local i = 0
    for _, s in ipairs(list) do
      local src = s.get_inventory(defines.inventory.furnace_source)
      if not src.is_empty() and not s.is_crafting() then
        local c = src[1]
        if c.valid_for_read and ratio[c.name] and c.count < ratio[c.name] then
          carrier.insert({ name = c.name, count = c.count })
          src.clear()
        end
      end
      if src.is_empty() and #products > 0 then
        i = i % #products + 1
        local input = T.smelter_inputs[products[i]]
        if input then
          -- jamais moins d'une fabrication complète, et un multiple de l'entrée
          local n = math.min(input[2] * 10, carrier.get_item_count(input[1]))
          n = n - n % input[2]
          if n > 0 then
            local took = carrier.remove({ name = input[1], count = n })
            src.insert({ name = input[1], count = took })
            loaded = loaded + took
          end
        end
      end
    end
  end
  local fuel_before = carrier.get_item_count(T.fuel)
  if Outposts.four_rule(f) then
    -- Lot FOURS : combustible jusqu'à T.smelter_fuel_to, seulement dans les fours tombés au tiers de la cible.
    local fl = Outposts.smelter_fuel_loads(f, list)
    local rooms = {}
    for k, l in ipairs(fl) do rooms[k] = l.room end
    local amounts = Charge.split(carrier.get_item_count(T.fuel), rooms, 1)
    for k, l in ipairs(fl) do
      if amounts[k] > 0 then
        local took = carrier.remove({ name = T.fuel, count = amounts[k] })
        local put = l.s.get_fuel_inventory().insert({ name = T.fuel, count = took })
        if put < took then carrier.insert({ name = T.fuel, count = took - put }) end
      end
    end
  else
    refuel(list, carrier)
  end
  local fueled = math.max(0, fuel_before - carrier.get_item_count(T.fuel))
  local st = f.stats
  if st then
    local m = st.smelt or {}
    st.smelt = m
    m.visits = (m.visits or 0) + 1
    m.loaded = (m.loaded or 0) + loaded
    m.collected = (m.collected or 0) + collected
    m.fueled = (m.fueled or 0) + fueled
    if loaded == 0 and collected == 0 and fueled == 0 then m.empty = (m.empty or 0) + 1 end
  end
  return collected, loaded, fueled
end

function Outposts.smelters_status(f)
  local out, low = 0, false
  for _, s in ipairs(Outposts.smelters(f)) do
    out = out + s.get_output_inventory().get_item_count()
    if fuel_of(s) < T.fuel_low then low = true end
  end
  return out, low
end

--- Lot FOURS : fours du QG à ravitailler (tombés au tiers de T.smelter_fuel_to ou moins), { { s, room } } dans l'ordre de la fonderie.
function Outposts.smelter_fuel_loads(f, list)
  local out = {}
  for _, s in ipairs(list or Outposts.smelters(f)) do
    local room = Charge.room(fuel_of(s), T.smelter_fuel_to, 1)
    if room > 0 then out[#out + 1] = { s = s, room = room } end
  end
  return out
end

--- Lot FOURS : ce que la décision d'une tournée de fonte lit (shared/team/chaine_main.lua) : fours libres (entrée vide ou
--- bloquée) et, par entrée, fours tombés au tiers de leur pile. Rend (libres, { [entrée] = nombre }).
function Outposts.smelters_gate(f)
  local free, loads = 0, {}
  for _, s in ipairs(Outposts.smelters(f)) do
    local c = s.get_inventory(defines.inventory.furnace_source)[1]
    if not (c and c.valid_for_read) or stuck(s, c) then
      free = free + 1
    elseif RATIO[c.name] and Charge.room(c.count, stack_of(c.name), RATIO[c.name]) >= RATIO[c.name] then
      loads[c.name] = (loads[c.name] or 0) + 1
    end
  end
  return free, loads
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
    -- Lot IA2-b : site perdu retenu (danger de la carte de valeur) ; réceptacles restés sur la carte (F209) gardés dans
    -- la liste des orphelins (journal de forme ; repris à la reconstruction ou démontés par un ouvrier).
    Sites.note_lost(f, o.pos, game.tick)
    f.orphans = f.orphans or {}
    for _, s in ipairs(o.sinks or {}) do
      if s.valid then f.orphans[#f.orphans + 1] = { e = s, x = o.pos.x, y = o.pos.y, tick = game.tick, oid = oid } end
    end
    -- Le gisement reste là : il revient à la réserve pour une reconstruction (règle du cerveau d'équipe).
    local spec = T.outposts[o.kind]
    -- Lot IA2-c : dans les bornes de la réserve seulement (Sites.room_for) ; sinon la réserve a déjà ses choix.
    if spec and Sites.room_for(f, spec.resource) then
      f.prospects = f.prospects or {}
      local info = o.site_info or {}
      f.prospects[#f.prospects + 1] = { x = o.pos.x, y = o.pos.y, resource = spec.resource, lost = true,
        rich = info.rich, tiles = info.tiles, water = info.water, rough = info.rough, cliffs = info.cliffs }
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
