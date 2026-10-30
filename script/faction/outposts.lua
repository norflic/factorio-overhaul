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
local Events = require("script.core.events")
local Sites = require("script.faction.sites")
local Pl = require("shared.ai3.places") -- lot SCALE (correction) : places du QG depuis l'emprise du prototype
local PlacesQG = require("script.ai3.places_qg") -- lot SCALE (correction) : pose sur la grille, place vérifiée
local R = require("shared.ai3.reglages") -- lot TOURELLES : rôles des types du moteur (bâtiments à protéger)
local Pose = require("shared.team.pose_tourelles") -- lot TOURELLES : quels emplacements prendre (règle pure)
local Blocage = require("shared.team.blocage") -- lot FACTIONS-BLOQUEES : une tourelle ne se pose pas sur une tuile réservée (règle pure)
local Axe = require("shared.team.axe") -- lot TOURELLES-HORS-AXE : couloir d'extension des lignes (règle pure)
local Charge = require("shared.team.charge_four") -- lot FOURS : charge d'un four à la pile (règle pure)
local Paires = require("shared.team.pose_paires") -- lot EXTENSION-FER : parcours des emplacements, emplacements occupés écartés sans coût (règle pure)
local Ruines = require("script.team.ruines") -- lot REBUILD-AVANT-POSTE : un avant-poste perdu en entier garde son plan (ruine)

local Outposts = {}

local DIRS = { defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west }
Outposts.RADIUS = { build = Paires.BUILD_RADIUS, extend = Paires.EXTEND_RADIUS } -- rayons de place_pairs (lus aussi par script/team/fantomes.lua)
-- Lot EXTENSION-FER : types du moteur dont l'emprise occupe déjà une tuile de minerai (écartée sans coût, sans essai au moteur).
local OCCUPY_TYPES = { "mining-drill", "furnace", "container", "electric-pole", "ammo-turret", "wall", "assembling-machine" }

--- Lot EXTENSION-FER : ensemble des tuiles déjà prises autour de `center` (foreuses, fours, coffres, poteaux, tourelles...).
local function occupied_tiles(surface, center, radius)
  local occ = {}
  for _, e in ipairs(surface.find_entities_filtered({ position = center, radius = radius + 3, type = OCCUPY_TYPES })) do
    if e.valid then
      local bb = e.bounding_box
      for _, k in ipairs(Paires.box_tiles(bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y)) do occ[k] = true end
    end
  end
  return occ
end

--- Lot EXTENSION-FER : tuiles de minerai à parcourir, triées ; pour un agrandissement, seules celles du gisement du centre.
local function resource_tiles(surface, spec, center, radius, same_deposit)
  local raw = {}
  for _, r in ipairs(surface.find_entities_filtered({ position = center, radius = radius, name = spec.resource })) do
    if r.valid then raw[#raw + 1] = { x = r.position.x, y = r.position.y } end
  end
  local sorted = Paires.sorted(raw, center)
  if same_deposit then return Paires.component(sorted, Paires.GAP, center) end
  return sorted
end

--- Lot PLAFOND-FOREUSES : clés des tuiles minées par la foreuse `d` (zone de minage du prototype, sinon son emprise).
local function mined_keys(d)
  local p = d.position
  local r = d.prototype and d.prototype.mining_drill_radius
  if r and r > 0 then return Paires.box_tiles(p.x - r, p.y - r, p.x + r, p.y + r) end
  local bb = d.bounding_box
  return Paires.box_tiles(bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y)
end

--- Lot PLAFOND-FOREUSES : ensemble des tuiles minées par les foreuses de l'avant-poste `o` (lu par Paires report().covered).
local function mined_set(o)
  local set = {}
  for _, d in ipairs(o.drill_list or {}) do
    if d.valid then for _, k in ipairs(mined_keys(d)) do set[k] = true end end
  end
  return set
end

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

--- Lot EXTENSION-FER : l'ouvrier dégage arbres et rochers du disque (`center`, `radius`) ou de la zone `area` (le bois revient à l'équipe).
local function clear_trees(surface, carrier, center, radius, area)
  local found
  if area then
    found = surface.find_entities_filtered({ area = area, type = { "tree", "simple-entity" } })
  else
    found = surface.find_entities_filtered({ position = center, radius = radius, type = { "tree", "simple-entity" } })
  end
  for _, e in ipairs(found) do
    if e.valid then
      if e.type == "tree" then carrier.insert({ name = "wood", count = 4 }) end
      e.destroy()
    end
  end
end

--- Pose jusqu'à `max_pairs` paires foreuse + réceptacle sur le gisement `kind` autour de `center`, avec
--- les objets portés par `carrier` (inventaire de l'ouvrier). Renvoie drills, sinks, rapport.
--- Lot EXTENSION-FER : `o` (l'avant-poste, agrandissement seulement) limite le parcours au gisement du centre et mémorise dans
--- `o.ext_dead` les emplacements essayés en vain ; les emplacements déjà occupés ne comptent plus dans les essais (rapport :
--- attempts, occupied, dead, exhausted, capped, lacking).
local function place_pairs(f, surface, kind, center, carrier, max_pairs, radius, o)
  local spec = T.outposts[kind]
  local force = f.force
  -- Construction : l'ouvrier dégage tout le chantier d'abord. Agrandissement (rayon jusqu'à 32) : seulement autour de chaque
  -- emplacement essayé, pour ne pas raser toute la couronne du gisement.
  if not o then clear_trees(surface, carrier, center, radius) end
  -- Moteur réel (session 4) : poser une foreuse pour lire son point de dépôt, puis la détruire quand le
  -- réceptacle ne passait pas, coûtait jusqu'à 400 ms sur un gisement déjà occupé (centaines de tuiles ×
  -- 4 orientations). Le point de dépôt est désormais calculé (vecteur du prototype vanilla), chaque
  -- emplacement n'est essayé qu'une fois et le nombre d'essais est plafonné.
  local dp = game.entity_prototypes[T.DRILL]
  if o then o.ext_dead = o.ext_dead or {} end
  local pl = Paires.new({
    resources = resource_tiles(surface, spec, center, radius, o ~= nil), cap = Paires.MAX_ATTEMPTS,
    w = dp and dp.tile_width or 2, h = dp and dp.tile_height or 2,
    occupied = occupied_tiles(surface, center, radius), dead = o and o.ext_dead or nil,
    mined = o and mined_set(o) or nil }) -- lot PLAFOND-FOREUSES : couverture du gisement (verdict « couverture »)
  local drills, sinks = {}, {}
  local lacking = false
  -- lot PLAFOND-FOREUSES : gisement déjà couvert à Paires.KAPPA (foreuses électriques du lot FOREUSES, zone de minage 5 x 5) : rien
  -- de plus à poser, le verdict dira « couverture »
  if o then
    local r0 = pl.report()
    if Paires.permille(r0.covered, r0.tiles) >= Paires.KAPPA then max_pairs = 0 end
  end
  while #drills < max_pairs do
    if carrier.get_item_count(T.DRILL) < 1 or carrier.get_item_count(spec.sink) < 1 then
      lacking = true
      break
    end
    local pos = pl.next()
    if not pos then break end
    if o then
      clear_trees(surface, carrier, nil, nil, { { pos.x - 4, pos.y - 4 }, { pos.x + 4, pos.y + 4 } })
    end
    local done = false
    for _, dir in ipairs(DIRS) do
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
            for _, e in ipairs({ d, s }) do
              local bb = e.bounding_box
              pl.occupy(Paires.box_tiles(bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y))
            end
            pl.cover(mined_keys(d))
            done = true
            break
          end
          d.destroy()
        end
      end
    end
    if not done then pl.fail(pos) end
  end
  local rep = pl.report()
  rep.lacking = lacking
  if o and rep.exhausted then o.ext_dead = nil end -- balayage complet : le prochain repart de zéro (un obstacle a pu partir)
  return drills, sinks, rep
end

--- Lot FANTOMES : APERÇU des paires que `place_pairs` poserait (sans objets, sans rien détruire ni poser) : même parcours des
--- tuiles de minerai, mêmes orientations, mêmes points de dépôt. Arbres et rochers ne comptent pas (l'ouvrier les abat avant de
--- poser : vérification « script_ghost » avec `forced`), et deux paires de l'aperçu ne se recouvrent pas. Rend une liste de
--- { drill = { name, position, direction }, sink = { name, position } }.
--- Lot EXTENSION-FER : `o` (agrandissement) : même gisement, mêmes emplacements écartés que la pose (`o.ext_dead` en lecture).
function Outposts.preview_pairs(f, surface, kind, center, max_pairs, radius, o)
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
  local dp = game.entity_prototypes[T.DRILL]
  local pl = Paires.new({
    resources = resource_tiles(surface, spec, center, radius, o ~= nil), cap = Paires.MAX_ATTEMPTS,
    w = dp and dp.tile_width or 2, h = dp and dp.tile_height or 2,
    occupied = occupied_tiles(surface, center, radius), dead = o and o.ext_dead or nil,
    mined = o and mined_set(o) or nil })
  local out = {}
  -- lot PLAFOND-FOREUSES (relecture) : même arrêt que place_pairs, un gisement couvert à Paires.KAPPA n'a pas d'aperçu à poser
  if o then
    local r0 = pl.report()
    if Paires.permille(r0.covered, r0.tiles) >= Paires.KAPPA then max_pairs = 0 end
  end
  while #out < max_pairs do
    local pos = pl.next()
    if not pos then break end
    for _, dir in ipairs(DIRS) do
      local v = drop_vector(dir)
      local drop = { x = pos.x + v[1], y = pos.y + v[2] }
      local spos = sink_position(surface, spec.sink, drop, force, pos, function(name, p) return fits(name, p, 0) end)
      if spos and fits(T.DRILL, pos, dir) then
        for _, k in ipairs(tiles(T.DRILL, pos, dir)) do taken[k] = true end
        for _, k in ipairs(tiles(spec.sink, spos, 0)) do taken[k] = true end
        pl.occupy(tiles(T.DRILL, pos, dir))
        pl.occupy(tiles(spec.sink, spos, 0))
        out[#out + 1] = { drill = { name = T.DRILL, position = pos, direction = dir }, sink = { name = spec.sink, position = spos } }
        break
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
    -- Lot REBUILD-AVANT-POSTE : les réceptacles d'un avant-poste dont la ruine vit sont repris à la recréation, jamais démontés avant
    if tick - (o.tick or 0) >= Outposts.ORPHAN_WAIT and not Ruines.keeps(f.recon, o.oid) then
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
  local drills, sinks = place_pairs(f, surface, kind, site, carrier, spec.drills, Outposts.RADIUS.build)
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

--- Agrandit un avant-poste existant (même gisement). Renvoie le nombre de paires ajoutées.
--- Lot EXTENSION-FER (audit du 29/10 : l'agrandissement ne posait plus rien et marquait l'avant-poste plein pour toute la partie) :
--- l'avant-poste n'est marqué plein (`o.full`) que par shared/team/pose_paires.lua (verdict) : balayage COMPLET du gisement (rayon
--- Outposts.RADIUS.extend, emplacements occupés écartés sans coût) sans emplacement restant, ou gisement couvert à Paires.KAPPA ‰
--- (lot PLAFOND-FOREUSES : le plafond de foreuses est supprimé, T.max_drills rend l'infini). Plafond
--- d'essais atteint ou ouvrier sans objets : pas plein, le prochain appel reprend. Journal [FO-EXTEND].
function Outposts.extend(f, surface, o, carrier)
  if o.migr then return 0 end -- lot MIGRATION-CHAMP : le champ est migré vers des foreuses électriques en rangées, pas de paire thermique de plus
  local spec = T.outposts[o.kind]
  if Outposts.on_arrive then Outposts.on_arrive(f, nil, o.id) end
  local room = T.max_drills(o.kind) - o.drills
  local want = math.min(spec.drills, room)
  local drills, sinks, rep = place_pairs(f, surface, o.kind, o.pos, carrier, want, Outposts.RADIUS.extend, o)
  for _, d in ipairs(drills) do
    o.drill_list[#o.drill_list + 1] = d
    State.own(d, f.id, "drill", o.id)
  end
  for _, s in ipairs(sinks) do
    o.sinks[#o.sinks + 1] = s
    State.own(s, f.id, "sink", o.id)
  end
  o.drills = o.drills + #drills
  local v = Paires.verdict({ placed = #drills, drills_after = o.drills, drills_max = T.max_drills(o.kind),
    exhausted = rep.exhausted, capped = rep.capped, lacking = rep.lacking, covered = rep.covered, tiles = rep.tiles })
  if v.full then
    o.full = true
    o.full_by = "pose_paires" -- plein selon la règle d'EXTENSION-FER (et non par l'ancien défaut : Outposts.reopen)
    o.full_why = v.why -- lot PLAFOND-FOREUSES : motif du plein (lecteur : Outposts.uncap, migration du plafond supprimé)
    o.hold_until = nil -- plein pour de bon (et non en attente après des échecs, lot ADOPTE)
  end
  if #drills > 0 then o.ext_fails = 0 elseif v.fail then o.ext_fails = (o.ext_fails or 0) + 1 end
  f.stats = f.stats or {}
  f.stats.extend_calls = (f.stats.extend_calls or 0) + 1
  if v.full then f.stats.extend_full = (f.stats.extend_full or 0) + 1 end
  if (f.stats.extend_logs or 0) < Paires.LOGS then
    f.stats.extend_logs = (f.stats.extend_logs or 0) + 1
    -- lot PLAFOND-FOREUSES : plus de plafond de foreuses à écrire ; la couverture du gisement (‰, seuil Paires.KAPPA) le remplace
    log(string.format("[FO-EXTEND] tick %d %s avant-poste %d %s : %d posee(s) / %d voulue(s), foreuses %d, couverture %d/%d pour mille, essais %d, occupees %d, ecartees %d, tuiles %d, plein=%s (%s)",
      game.tick, tostring(f.key), o.id, o.kind, #drills, want, o.drills, Paires.permille(rep.covered, rep.tiles), Paires.KAPPA, rep.attempts, rep.occupied, rep.dead, rep.tiles,
      v.full and "oui" or "non", v.why))
  end
  return #drills
end

--- Lot EXTENSION-FER : rouvre les avant-postes d'une équipe marqués pleins par l'ancien défaut (0.6.16 et avant : un agrandissement
--- qui ne posait rien marquait l'avant-poste plein pour toute la partie). Seuls sont rouverts ceux dont le `full` ne vient pas de la
--- règle de pose_paires, qui ne sont pas en attente (lot ADOPTE) et qui restent sous leur plafond de foreuses : le prochain
--- agrandissement les referme s'ils sont vraiment saturés. Rend le nombre rouvert.
function Outposts.reopen(f)
  local n = 0
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    if o.full and o.full_by ~= "pose_paires" and not o.migr and not o.hold_until and (o.drills or 0) < T.max_drills(o.kind) then
      o.full, o.ext_dead = false, nil
      n = n + 1
    end
  end
  return n
end

-- Lot PLAFOND-FOREUSES : plafond de foreuses par avant-poste de 0.6.18 et avant (shared/team/config.lua : 12, fer 20, pierre 8),
-- lu seulement par la migration ci-dessous.
Outposts.CAP_0618 = { iron = 20, stone = 8 }
Outposts.CAP_0618_OTHER = 12

--- Lot PLAFOND-FOREUSES : rouvre les avant-postes fermés par l'ancien plafond de foreuses (verdict « plafond » de pose_paires, avant le
--- lot : `full_by` = "pose_paires" sans `full_why`, au moins autant de foreuses que le plafond de 0.6.18). Un avant-poste fermé par un
--- balayage complet sous le plafond reste fermé ; à égalité (plein au balayage pile au plafond), il est rouvert : l'agrandissement
--- suivant le referme sans essai au moteur s'il est vraiment saturé. Ni en attente (ADOPTE), ni migré (MIGRATION-CHAMP). Rend le nombre.
function Outposts.uncap(f)
  local n = 0
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    local cap = Outposts.CAP_0618[o.kind] or Outposts.CAP_0618_OTHER
    if o.full and o.full_by == "pose_paires" and o.full_why == nil and not o.migr and not o.hold_until and (o.drills or 0) >= cap then
      o.full, o.full_by = false, nil
      n = n + 1
    end
  end
  return n
end

Events.on_configuration_changed(function()
  local war = State.war()
  local total, uncapped = 0, 0
  for _, id in ipairs(State.sorted_keys(war and war.factions or {})) do
    local f = war.factions[id]
    if f then
      total = total + Outposts.reopen(f)
      uncapped = uncapped + Outposts.uncap(f)
    end
  end
  local team = State.faction("player")
  if team then
    total = total + Outposts.reopen(team)
    uncapped = uncapped + Outposts.uncap(team)
  end
  if total > 0 then log("[FO-EXTEND] migration : " .. total .. " avant-poste(s) rouvert(s) (marques pleins par l'ancien defaut d'agrandissement)") end
  if uncapped > 0 then log("[FO-PLAFOND] migration : " .. uncapped .. " avant-poste(s) rouvert(s) (fermes par l'ancien plafond de foreuses, supprime)") end
end)

local TURRET_OFFSETS = { { 7, 7 }, { -7, -7 }, { 7, -7 }, { -7, 7 }, { 9, 0 }, { -9, 0 }, { 0, 9 }, { 0, -9 } }
local TURRET = "gun-turret"
Outposts.ASSET_RADIUS_OUT = 24 -- lot TOURELLES : tuiles autour d'un avant-poste où les bâtiments de l'équipe sont à protéger
Outposts.ASSET_RADIUS_HQ = 40  -- ... autour du QG
Outposts.POSE_LOGS = 40        -- lignes de journal [FO-TOUR-POSE] au plus par équipe

--- Lot TOURELLES : bâtiments de l'équipe autour du centre, { {x, y, w} } (w = aire de l'emprise × facteur du rôle).
local function assets_around(f, surface, center, radius)
  local types = {}
  for _, ty in ipairs(R.ENTITY_TYPES) do
    if Pose.role_factor(R.ENTITY_ROLE[ty]) > 0 then types[#types + 1] = ty end
  end
  local out = {}
  local hq = f.hq and f.hq.valid and f.hq or nil
  for _, e in ipairs(surface.find_entities_filtered({ position = center, radius = radius, force = f.force, type = types })) do
    local bb = e.bounding_box
    local area = math.max(1, math.floor((bb.right_bottom.x - bb.left_top.x) * (bb.right_bottom.y - bb.left_top.y) + 0.5))
    local w = area * Pose.role_factor(R.ENTITY_ROLE[e.type])
    if hq and e.unit_number and e.unit_number == hq.unit_number then w = Pose.HQ_WEIGHT end
    out[#out + 1] = { x = e.position.x, y = e.position.y, w = w }
  end
  return out
end

--- Lot TOURELLES : positions de pose dans l'ordre. Les emplacements sont ceux d'avant le lot (les 8 de TURRET_OFFSETS avec leur
--- repli du moteur, sans doublon) ; seul l'ORDRE change : celui qui couvre le plus de bâtiments de l'équipe (règle pure :
--- shared/team/pose_tourelles.lua). Sans portée lue ni bâtiment : l'ancien ordre.
local function pose_order(f, surface, outpost, count)
  local raw = {}
  for _, o in ipairs(TURRET_OFFSETS) do
    local pos = surface.find_non_colliding_position(TURRET, { x = outpost.pos.x + o[1], y = outpost.pos.y + o[2] }, 4, 1)
    if pos then raw[#raw + 1] = { x = pos.x, y = pos.y } end
  end
  local cands = Pose.dedup(raw)
  local proto = game.entity_prototypes[TURRET]
  local range = proto and proto.turret_range or 0
  if range <= 0 or #cands == 0 then return cands end
  local center = outpost.pos
  local is_hq = outpost.id == nil
  local radius = is_hq and Outposts.ASSET_RADIUS_HQ or Outposts.ASSET_RADIUS_OUT
  local existing = {}
  for _, t in ipairs(surface.find_entities_filtered({ position = center, radius = radius + range, force = f.force, name = TURRET })) do
    existing[#existing + 1] = { x = t.position.x, y = t.position.y }
  end
  table.sort(existing, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
  local assets = assets_around(f, surface, center, radius)
  -- lot PD-ESPACEMENT : écart minimal entre tourelles (un emplacement serré contre une tourelle déjà là passe après les autres)
  local pick = Pose.choose({ candidates = cands, assets = assets, range = range, existing = existing, count = count, gap = Pose.gap(range) })
  local out = {}
  for _, i in ipairs(pick.order) do out[#out + 1] = cands[i] end
  f.stats = f.stats or {}
  f.stats.pose_logs = (f.stats.pose_logs or 0) + 1
  if f.stats.pose_logs <= Outposts.POSE_LOGS then
    local before, tot = Pose.covered(assets, existing, range)
    local after = {}
    for _, t in ipairs(existing) do after[#after + 1] = t end
    for i = 1, math.min(count, pick.chosen) do after[#after + 1] = out[i] end
    local cov = Pose.covered(assets, after, range)
    log(string.format("[FO-TOUR-POSE] %s %s en (%.0f, %.0f) : %d tourelle(s) voulue(s), %d emplacement(s), %d batiment(s), aire protegee %d -> %d sur %d",
      f.key or "?", is_hq and "QG" or ("avant-poste " .. tostring(outpost.id)), center.x, center.y, count, #cands, #assets, before, cov, tot))
  end
  return out
end


--- Pose jusqu'à `count` tourelles autour de l'avant-poste avec les objets portés.
function Outposts.fortify(f, surface, outpost, count, carrier)
  -- lot CENTRALE-GARDE : même pose que fortify_at (emplacements = les huit points autour du poste), chargeurs perforants d'abord
  -- lot TOURELLES : mêmes emplacements qu'avant, pris dans l'ordre qui protège le plus de bâtiments de l'équipe
  local sites = pose_order(f, surface, outpost, count)
  -- repli d'avant le lot : les huit points d'origine, résolus APRÈS chaque pose (deux points qui se replient sur la même place avant
  -- toute pose ne font pas perdre une tourelle)
  for _, o in ipairs(TURRET_OFFSETS) do sites[#sites + 1] = { x = outpost.pos.x + o[1], y = outpost.pos.y + o[2] } end
  return Outposts.fortify_at(f, surface, outpost.id, sites, count, carrier, nil, { "piercing-rounds-magazine", T.turret_ammo })
end

--- Lot CENTRALE-GARDE : pose jusqu'à `count` tourelles aux emplacements `sites` ({ x, y }, dans l'ordre), pleines de munitions, pour le
--- poste `oid` (ex. "plant" : groupe de ravitaillement « o<oid> »). `accept(pos)` refuse une position trouvée hors de la zone voulue.
--- Les objets viennent de l'inventaire `carrier` (déjà pris au stock par la tâche). Rend le nombre posé.
function Outposts.fortify_at(f, surface, oid, sites, count, carrier, accept, ammos)
  local placed = 0
  ammos = ammos or { T.turret_ammo }
  -- lot TOURELLES-HORS-AXE : couloirs d'extension des lignes de l'équipe (Build.corridors, crochet posé par script/team/build.lua),
  -- lus une fois par pose ; emprise de la tourelle en tuiles (prototype)
  local cors = (Outposts.corridors ~= nil and Outposts.corridors(f)) or {}
  local tp = game.entity_prototypes[T.turret]
  local tw, th = tp and tp.tile_width or 2, tp and tp.tile_height or 2
  local function in_axe(q) return Axe.hit(cors, Axe.tile_rect(q.x, q.y, tw, th)) end
  -- lot PD-ESPACEMENT (D07) : tourelles de l'équipe autour des emplacements (lues une fois, puis complétées à chaque pose) ; une
  -- position plus proche que l'écart voulu d'une autre tourelle est refusée comme une tuile réservée. Passe 1 : Pose.gap ;
  -- passe 2 (seulement s'il en manque) : Pose.GAP_MIN. Bilan au journal [FO-TOUR-ECART].
  -- (Intégration 0.6.21 : résolution proposée par PD-ESPACEMENT, fo-logs/2026-10-30_AMELIO/PD-ESPACEMENT/RESOLUTION_HORS_AXE.lua, plus
  -- la relecture du lot (`mine`, passe 2) : les deux refus (couloir d'extension ET écart) dans le même prédicat ; repli sans contrôle de
  -- HORS-AXE ; écart contrôlé sur la position finale ; journal du couloir à la passe 1 seulement.)
  local near = Outposts.turrets_near(f, surface, sites)
  local gaps = { Pose.gap(Outposts.turret_range()), Pose.GAP_MIN }
  local ec = { refused = 0, by_pass = { 0, 0 }, near0 = #near, min = nil }
  -- relecture : la passe 2 saute un emplacement déjà TENU par une tourelle de cette pose (à moins de Pose.GAP_MIN de son point) ; sinon,
  -- au plancher, l'anneau de cet emplacement donnait une 2e tourelle à 3 tuiles de la 1re avant de servir les emplacements restés
  -- vides (l'amas que le DC reproche ; moteur factice : (0,0) entre (3,0) et (-3,0) au lieu de (0,3))
  local mine = {}
  for pass = 1, 2 do
    local gap = gaps[pass]
    for _, s in ipairs(sites) do
      if placed >= count or carrier.get_item_count(T.turret) < 1 then break end
      if pass == 2 and not Pose.spaced(s.x, s.y, mine, gaps[2]) then goto suivant end
      -- lot FACTIONS-BLOQUEES : jamais sur une tuile réservée par un projet du plan directeur ; lot TOURELLES-HORS-AXE : ni dans le
      -- couloir d'extension d'une ligne (places sur le CÔTÉ de la ligne d'abord, Axe.side_spots, puis les anneaux voisins ; le repli
      -- sans contrôle ne tombe jamais dans un couloir)
      local spots = Axe.side_spots(s.x, s.y, cors, tw, th)
      local hit = #spots > 0 and in_axe(s) or nil
      for _, q in ipairs(Blocage.spots(s.x, s.y)) do spots[#spots + 1] = q end
      local pos = Blocage.first_free(spots,
        function(c) return surface.find_non_colliding_position(T.turret, { x = c.x, y = c.y }, 4, 1) end,
        function(q) -- réservée, dans un couloir d'extension, hors de la zone voulue (accept), ou trop près d'une autre tourelle
          if (Outposts.reserved ~= nil and Outposts.reserved(f, T.turret, q)) or in_axe(q) ~= nil or (accept ~= nil and not accept(q)) then
            return true
          end
          if not Pose.spaced(q.x, q.y, near, gap) then ec.refused = ec.refused + 1 return true end
          return false
        end)
      if not pos then
        local q = surface.find_non_colliding_position(T.turret, { x = s.x, y = s.y }, 4, 1)
        if q and not in_axe(q) then pos = q end
      end
      if hit and Outposts.axe_log and pass == 1 then
        Outposts.axe_log(f, pos and string.format("pose (%s) : emplacement (%g, %g) dans le couloir d'extension du projet %d (partie %d, axe %s) -> tourelle en (%g, %g), hors du couloir",
            tostring(oid), s.x, s.y, hit.pid or 0, hit.part or 0, hit.axis, pos.x, pos.y)
          or string.format("pose (%s) : emplacement (%g, %g) dans le couloir d'extension du projet %d (partie %d, axe %s), aucune place hors des couloirs : emplacement saute",
            tostring(oid), s.x, s.y, hit.pid or 0, hit.part or 0, hit.axis))
      end
      if pos and (accept == nil or accept(pos)) and Pose.spaced(pos.x, pos.y, near, gap) then
        local t = surface.create_entity({ name = T.turret, position = pos, force = f.force, raise_built = true })
        if t then
          carrier.remove({ name = T.turret, count = 1 })
          for _, ammo in ipairs(ammos) do
            local n = math.min(T.turret_ammo_target - t.get_item_count(), carrier.get_item_count(ammo))
            if n > 0 then t.insert({ name = ammo, count = carrier.remove({ name = ammo, count = n }) }) end
          end
          Outposts.add_turret(f, t, oid, 0)
          placed = placed + 1
          local d = Pose.nearest(t.position.x, t.position.y, near)
          if d and (ec.min == nil or d < ec.min) then ec.min = d end
          near[#near + 1] = { x = t.position.x, y = t.position.y }
          ec.by_pass[pass] = ec.by_pass[pass] + 1
          mine[#mine + 1] = { x = t.position.x, y = t.position.y }
        end
      end
      ::suivant::
    end
    if placed >= count or carrier.get_item_count(T.turret) < 1 then break end
  end
  Outposts.ecart_log(f, oid, count, placed, gaps, ec)
  return placed
end

--- Lot PD-ESPACEMENT : portée de la tourelle posée (prototype), 0 si inconnue.
function Outposts.turret_range()
  local proto = game.entity_prototypes[T.turret]
  return proto and proto.turret_range or 0
end

--- Lot PD-ESPACEMENT : tourelles de l'équipe (tous types de tourelle du moteur, R.TURRET_TYPES) autour des emplacements `sites`, à la
--- portée de recherche de la pose (anneaux de Blocage, rayon du moteur) plus l'écart ; { {x, y} } triées (déterminisme).
Outposts.ECART_LOGS = 40 -- lignes [FO-TOUR-ECART] au plus par équipe
function Outposts.turrets_near(f, surface, sites)
  local out = {}
  if #sites == 0 then return out end
  local x0, y0, x1, y1 = sites[1].x, sites[1].y, sites[1].x, sites[1].y
  for _, s in ipairs(sites) do
    if s.x < x0 then x0 = s.x end
    if s.x > x1 then x1 = s.x end
    if s.y < y0 then y0 = s.y end
    if s.y > y1 then y1 = s.y end
  end
  local m = Blocage.RING * Blocage.RINGS + 4 + Pose.GAP + 2
  local isturret = {}
  for _, ty in ipairs(R.TURRET_TYPES) do isturret[ty] = true end
  for _, e in ipairs(surface.find_entities_filtered({ area = { { x0 - m, y0 - m }, { x1 + m, y1 + m } }, force = f.force, type = R.TURRET_TYPES })) do
    if e.valid ~= false and isturret[e.type] then out[#out + 1] = { x = e.position.x, y = e.position.y } end
  end
  table.sort(out, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
  return out
end

--- Lot PD-ESPACEMENT : une ligne par pose (au plus Outposts.ECART_LOGS par équipe), avec la cause : « ecart » (toutes à l'écart voulu),
--- « plancher » (place serrée : passe 2), « manque-ecart » (moins posées que voulu, des places refusées pour l'écart), « manque-place »
--- (moins posées que voulu sans que l'écart y soit pour rien : zone, réserves, tourelles portées).
function Outposts.ecart_log(f, oid, count, placed, gaps, ec)
  if count <= 0 then return end
  local cause = "ecart"
  if placed < count then cause = ec.refused > 0 and "manque-ecart" or "manque-place"
  elseif ec.by_pass[2] > 0 then cause = "plancher" end
  f.stats = f.stats or {}
  f.stats.ecart_logs = (f.stats.ecart_logs or 0) + 1
  if f.stats.ecart_logs > Outposts.ECART_LOGS then return end
  log(string.format("[FO-TOUR-ECART] %s poste %s : %s ; %d posee(s) sur %d voulue(s), %d a l'ecart >= %g, %d au plancher >= %g ; plus proche voisine %s ; %d place(s) refusee(s) pour l'ecart ; %d tourelle(s) deja autour",
    f.key or "player", tostring(oid or "hq"), cause, placed, count, ec.by_pass[1], gaps[1], ec.by_pass[2], gaps[2],
    ec.min and string.format("%.1f tuiles", ec.min) or "aucune", ec.refused, ec.near0))
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
  -- Lot FOREUSES : une foreuse électrique de l'avant-poste (remplacement sur place) ne brûle rien : ni ravitaillement ni « manque de charbon ».
  for _, d in ipairs(valid_list(o.drill_list)) do if d.burner then list[#list + 1] = d end end
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
  -- Lot MIGRATION-CHAMP : un champ entièrement migré n'a plus rien à ravitailler ni à collecter ici (la fonderie du plan a ses coffres) :
  -- pas de tournée d'entretien « à l'heure » (les tourelles gardent leur ravitaillement par leurs propres tâches)
  local idle = (o.migr == "fini" and #valid_list(o.drill_list) == 0) and 0 or (tick - (o.last_service or 0))
  return { fuel_low = low, output = output, turrets = #o.turret_list, idle_ticks = idle }
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
  -- Lot PLAFOND-FOREUSES : sans plafond, un avant-poste peut compter des centaines de brûleurs et le charbon porté ne suffit plus à
  -- tous ; le plus à court d'abord (à égalité, l'ordre de la liste), et non plus toujours les foreuses avant les fours de la liste.
  local order = {}
  for i, b in ipairs(burners) do order[i] = { b = b, fuel = fuel_of(b), i = i } end
  table.sort(order, function(a, c) if a.fuel ~= c.fuel then return a.fuel < c.fuel end return a.i < c.i end)
  burners = {}
  for i, it in ipairs(order) do burners[i] = it.b end
  local short = 0
  for _, b in ipairs(burners) do
    local n = math.min(T.fuel_refill_to - fuel_of(b), carrier.get_item_count(T.fuel))
    if n > 0 then b.get_fuel_inventory().insert({ name = T.fuel, count = carrier.remove({ name = T.fuel, count = n }) }) end
    if fuel_of(b) < T.fuel_low then short = short + 1 end
  end
  return short
end

Outposts.COAL_SHORT_LOGS = 5 -- lot PLAFOND-FOREUSES : lignes [FO-CHARBON] au plus par avant-poste

--- Tournée sur place : ramasse la production (un avant-poste de charbon se ravitaille sur la sienne) puis
--- complète le charbon de chaque brûleur. Renvoie le nombre d'objets ramassés.
--- Lot PLAFOND-FOREUSES : brûleurs laissés sous T.fuel_low faute de charbon porté comptés dans `o.coal_short` (tournées courtes ;
--- lecteur : le journal [FO-CHARBON], les premières fois seulement, et tests/extension_fer_moteur_test.lua).
function Outposts.service(o, carrier, tick)
  local collected = collect(valid_list(o.sinks), carrier)
  local burners = Outposts.burners(o)
  local short = refuel(burners, carrier)
  if short > 0 then
    o.coal_short = (o.coal_short or 0) + 1
    if o.coal_short <= Outposts.COAL_SHORT_LOGS then
      log(string.format("[FO-CHARBON] tick %d avant-poste %s %s : %d bruleur(s) sur %d sous %d charbons apres la tournee (charbon porte insuffisant, tournee courte n. %d)",
        tick, tostring(o.id), tostring(o.kind), short, #burners, T.fuel_low, o.coal_short))
    end
  end
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
  local out = {}
  list = list or Outposts.smelters(f)
  -- Fours multi-types : un four vide va à l'entrée demandée qui a le moins de fours (et non plus toujours à la première).
  local items, counts = {}, {}
  for k, p in ipairs(products) do
    local input = T.smelter_inputs[p]
    items[k] = input and input[1] or p
  end
  for _, s in ipairs(list) do
    local c = s.get_inventory(defines.inventory.furnace_source)[1]
    if c and c.valid_for_read then counts[c.name] = (counts[c.name] or 0) + 1 end
  end
  for _, s in ipairs(list) do
    local c = s.get_inventory(defines.inventory.furnace_source)[1]
    if c and c.valid_for_read then
      local ratio = RATIO[c.name]
      if ratio and not stuck(s, c) and (not T.smelter_inputs[c.name] or demanded_item(products, c.name)) then
        local room = Charge.room(c.count, stack_of(c.name), ratio)
        if room >= ratio then out[#out + 1] = { s = s, item = c.name, ratio = ratio, room = room, free = false } end
      end
    elseif #products > 0 then
      local input = T.smelter_inputs[products[Charge.least_served(items, counts)]]
      if input then
        counts[input[1]] = (counts[input[1]] or 0) + 1
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
        -- même définition du « bloqué » que la décision (smelters_gate) : sinon un four compté libre ne serait jamais vidé
        if stuck(s, c) then
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
      local avail = carrier.get_item_count(item)
      -- Une entrée qui est elle-même un produit de fonte (la plaque de l'acier) n'est chargée que pour la demande : le porteur
      -- a aussi les plaques qu'il vient de vider des fours, qui ne doivent pas toutes partir en acier.
      if T.smelter_inputs[item] then
        local cap = 0
        for _, p in ipairs(products) do
          local inp = T.smelter_inputs[p]
          if inp and inp[1] == item then cap = cap + inp[2] * ((smelt and smelt[p]) or 0) end
        end
        if cap < avail then avail = cap end
      end
      local amounts = Charge.split(avail, rooms, g[1].ratio)
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
    -- Lot REBUILD-AVANT-POSTE : si le registre de reconstruction garde ses foreuses (ruine), le champ sera refait EN PLACE et n'est
    -- pas pénalisé ; sinon (rien au registre) le comportement d'avant : pénalité de valeur de 30 min.
    local keep = Ruines.on_total_loss(f, o, game.tick)
    Sites.note_lost(f, o.pos, game.tick, keep and oid or nil)
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
