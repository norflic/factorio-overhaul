--[[
  Prospection de sites d'avant-poste : gisements exploitables libres autour du QG.

  Moteur réel (session 3) :
  - les gisements sont rares près des QG (hors zone de départ le jeu place ~2,5 gisements/km² par minerai,
    avec un fondu jusqu'à 420 tuiles du centre) : prospection sur 12 chunks (~400 tuiles), QG à 480 tuiles
    du centre, 40 tuiles d'espacement entre avant-postes, mémoire des sites inaccessibles ;
  - un balayage complet en une décision coûtait jusqu'à 18 ms d'un coup ; des clés de chunk en chaîne
    coûtaient ~4 µs par lecture (88 % du coût) : clés numériques.

  D'où une PROSPECTION DE FOND : voie "fo-prospect" (une entrée par faction, période 30 ticks), 4 chunks
  par passage (du plus proche au plus lointain), sites trouvés mis en réserve (au plus le besoin du
  commandant, 4 maximum), et seulement quand le commandant a besoin de sites. Le commandant puise dans la
  réserve : sa décision ne coûte plus rien. Tour complet sans résultat : pause d'une minute.
]]

local State = require("script.faction.state")
local Scheduler = require("script.core.scheduler")
local Profiler = require("script.core.profiler")
local Trace = require("script.core.trace")
local Journal = require("script.faction.journal")

local Sites = {}

-- Prospection par CHUNKS en anneaux autour du QG (session 3). Le premier modèle sondait 16 directions sur
-- des anneaux : à 400 tuiles, deux sondes voisines étaient à 157 tuiles l'une de l'autre et manquaient
-- la plupart des gisements (30-60 tuiles de large). Ici chaque chunk du disque est examiné une fois par tour.
-- Session 4 (E16 it. 8) : quand un tour complet du disque ne trouve rien, la faction prospecte un disque
-- élargi (18 chunks, ~580 tuiles) : sans cela 3 factions sur 4 ne trouvaient jamais de 2e gisement de fer.
local PROSPECT_RADIUS_CHUNKS = 12.5
local WIDE_RADIUS_CHUNKS = 18
local OFFSETS = {}
local N_NEAR = 0
do
  local r = WIDE_RADIUS_CHUNKS
  for dx = -r, r do
    for dy = -r, r do
      local d2 = dx * dx + dy * dy
      if d2 >= 1 and d2 <= WIDE_RADIUS_CHUNKS * WIDE_RADIUS_CHUNKS then
        OFFSETS[#OFFSETS + 1] = { dx = dx, dy = dy, d2 = d2 }
      end
    end
  end
  table.sort(OFFSETS, function(p, q)
    if p.d2 ~= q.d2 then return p.d2 < q.d2 end
    if p.dy ~= q.dy then return p.dy < q.dy end
    return p.dx < q.dx
  end)
  for _, o in ipairs(OFFSETS) do
    if o.d2 <= PROSPECT_RADIUS_CHUNKS * PROSPECT_RADIUS_CHUNKS then N_NEAR = N_NEAR + 1 end
  end
end
local UNREACHABLE_TICKS = 108000 -- 30 min
local MIN_RESOURCES = 24      -- tuiles de ressource exploitables dans le chunk (sonde)
local MIN_SITE_RESOURCES = 12 -- tuiles exploitables lues autour du site
local MIN_DIST_OTHER_HQ = 110
local MIN_DIST_PLAYER_SPAWN = 140
-- Espacement minimal entre deux avant-postes (tuiles). Session 3 : l'exclusion par chunks voisins
-- (96 × 96 tuiles) interdisait d'exploiter un grand gisement à plusieurs ; on mesure la distance réelle.
local MIN_SITE_SPACING = 40
local ENEMY_CLEARANCE = 48
local CLAIM_SCAN_CHUNKS = 2

local chunk_key = State.chunk_key

local function claimed(war, pos)
  local claims = war.claims
  if next(claims) == nil then return false end
  local cx, cy = math.floor(pos.x / 32), math.floor(pos.y / 32)
  local cpos = war.claim_pos or {}
  for dx = -CLAIM_SCAN_CHUNKS, CLAIM_SCAN_CHUNKS do
    for dy = -CLAIM_SCAN_CHUNKS, CLAIM_SCAN_CHUNKS do
      local key = chunk_key(cx + dx, cy + dy)
      if claims[key] then
        local p = cpos[key]
        if not p then return true end -- ancienne sauvegarde sans position : prudence
        local ddx, ddy = p.x - pos.x, p.y - pos.y
        if ddx * ddx + ddy * ddy < MIN_SITE_SPACING * MIN_SITE_SPACING then return true end
      end
    end
  end
  return false
end

local function far_from(pos, others, min_dist)
  for _, o in ipairs(others) do
    local dx, dy = pos.x - o.x, pos.y - o.y
    if dx * dx + dy * dy < min_dist * min_dist then return false end
  end
  return true
end

local function unreachable(war, pos, tick)
  local until_tick = war.unreachable and war.unreachable[State.site_key(pos)]
  return until_tick ~= nil and tick < until_tick
end

--- Un ingénieur n'a pas trouvé de chemin vers ce site (ou rien n'a pu y être posé) : on l'évite un temps.
function Sites.mark_unreachable(pos, tick)
  local war = State.war()
  war.unreachable = war.unreachable or {}
  war.unreachable[State.site_key(pos)] = tick + UNREACHABLE_TICKS
end

local PROBES_PER_STEP = 4
local MAX_PROSPECTS = 8
local MAX_PER_KIND = 2
local IDLE_TICKS = 3600
Sites.LANE = "fo-prospect"
local LANE_PERIOD = 30

-- Sonde bon marché d'abord (aucun objet Lua créé), lecture détaillée seulement si prometteuse.
local function count_resources(surface, area, name, limit)
  Profiler.start("prospect:count")
  local n
  if name then
    n = surface.count_entities_filtered({ area = area, name = name, limit = limit })
  else
    n = surface.count_entities_filtered({ area = area, type = "resource", limit = limit })
  end
  Profiler.stop("prospect:count")
  return n
end

local function near_prospect(f, pos)
  for _, p in ipairs(f.prospects) do
    local dx, dy = p.x - pos.x, p.y - pos.y
    if dx * dx + dy * dy < MIN_SITE_SPACING * MIN_SITE_SPACING then return true end
  end
  return false
end

local function prospects_of(f, resource)
  local n = 0
  for _, p in ipairs(f.prospects or {}) do if p.resource == resource then n = n + 1 end end
  return n
end

--- Ressources encore recherchées (besoins du cerveau d'équipe, f.site_needs = { [ressource] = n }).
local function wanted_resources(f)
  local list = {}
  for _, res in ipairs(State.sorted_keys(f.site_needs or {})) do
    local want = math.min(MAX_PER_KIND, f.site_needs[res])
    if want > 0 and prospects_of(f, res) < want then list[#list + 1] = res end
  end
  return list
end

--- Une tranche de prospection pour la faction f (au plus PROBES_PER_STEP chunks).
--- Seulement si l'équipe a BESOIN de sites : en moteur réel la prospection permanente coûtait
--- 0,09 ms/tick en moyenne, plus que tout le reste du mod. Session 4 : un site = un gisement d'UNE
--- ressource demandée (charbon, fer, cuivre, pierre), centré sur ses tuiles.
function Sites.prospect(f, surface, tick)
  f.prospects = f.prospects or {}
  if #f.prospects >= MAX_PROSPECTS or tick < (f.prospect_idle_until or 0) then return end
  local wanted = wanted_resources(f)
  if #wanted == 0 then return end
  local war = State.war()
  local other_hqs = {}
  for _, id in ipairs(State.alive()) do
    if id ~= f.id then other_hqs[#other_hqs + 1] = State.faction(id).hq_pos end
  end
  local spawn = game.forces.player.get_spawn_position(surface)
  local hcx, hcy = math.floor(f.hq_pos.x / 32), math.floor(f.hq_pos.y / 32)
  local n = f.prospect_wide and #OFFSETS or N_NEAR
  for _ = 1, PROBES_PER_STEP do
    local k = f.site_cursor or 1
    if k > n then
      f.site_cursor = 1
      f.stats.prospect_cycles = (f.stats.prospect_cycles or 0) + 1
      if (f.prospect_found or 0) == 0 then
        if not f.prospect_wide then
          f.prospect_wide = true -- tour proche infructueux : disque élargi dès le tour suivant
          Trace.log("prospect", f.key, "wide")
        else
          f.prospect_idle_until = tick + IDLE_TICKS
        end
      end
      f.prospect_found = 0
      return
    end
    f.site_cursor = k + 1
    local o = OFFSETS[k]
    local cx, cy = hcx + o.dx, hcy + o.dy
    local center = { x = cx * 32 + 16, y = cy * 32 + 16 }
    Profiler.start("prospect:checks")
    -- Contrôles du moins cher au plus cher.
    local free = far_from(center, other_hqs, MIN_DIST_OTHER_HQ)
      and (f.is_player or far_from(center, { spawn }, MIN_DIST_PLAYER_SPAWN))
      and surface.is_chunk_generated({ x = cx, y = cy })
      and not unreachable(war, center, tick) and not claimed(war, center)
    Profiler.stop("prospect:checks")
    local area = { { cx * 32, cy * 32 }, { cx * 32 + 32, cy * 32 + 32 } }
    if free and count_resources(surface, area, nil, MIN_RESOURCES) >= MIN_RESOURCES then
      -- Ressource demandée la plus présente dans le chunk.
      local best, best_n = nil, 0
      for _, res in ipairs(wanted) do
        local c = count_resources(surface, area, res, 64)
        if c > best_n then best, best_n = res, c end
      end
      if best and best_n >= MIN_SITE_RESOURCES then
        Trace.log("prospect", f.key, best)
        Profiler.start("prospect:find")
        local tiles = surface.find_entities_filtered({ area = area, name = best, limit = 64 })
        Profiler.stop("prospect:find")
        local sx, sy = 0, 0
        for _, r in ipairs(tiles) do
          local p = r.position
          sx, sy = sx + p.x, sy + p.y
        end
        local site = { x = sx / #tiles, y = sy / #tiles, resource = best }
        -- Moteur réel (session 3) : 27 ingénieurs tués par des vers près de leurs sites. Un site à portée
        -- d'ennemis (déchiqueteurs) est évité ; les ennemis éliminés, il redevient prospectable.
        local hostile = surface.count_entities_filtered({ position = site, radius = ENEMY_CLEARANCE, force = "enemy", limit = 1 }) > 0
        if hostile then
          Sites.mark_unreachable(site, tick)
          f.stats.prospect_hostile = (f.stats.prospect_hostile or 0) + 1
        elseif not unreachable(war, site, tick) and not claimed(war, site) and not near_prospect(f, site) then
          f.prospects[#f.prospects + 1] = site
          f.prospect_found = (f.prospect_found or 0) + 1
          f.stats.prospected = (f.stats.prospected or 0) + 1
          wanted = wanted_resources(f)
          if #wanted == 0 or #f.prospects >= MAX_PROSPECTS then return end
        end
      end
    end
  end
end

--- Nombre de sites en réserve pour une ressource (toutes si nil).
function Sites.available(f, resource)
  if not resource then return f.prospects and #f.prospects or 0 end
  return prospects_of(f, resource)
end

--- Puise un site valide de la ressource demandée dans la réserve. Renvoie site ou nil.
function Sites.find(f, surface, tick, resource)
  local war = State.war()
  tick = tick or game.tick
  local list = f.prospects or {}
  local i = 1
  local function valid(s) return not claimed(war, s) and not unreachable(war, s, tick) end
  while i <= #list do
    local site = list[i]
    if resource == nil or site.resource == resource then
      -- Lot IA2-0 : rang du site choisi par distance au QG (journal seul, métrique M1 « plus proche d'abord »).
      local ok = valid(site)
      if ok then Journal.site(f, site, list, valid, tick) end
      table.remove(list, i)
      if ok then return site end
    else
      i = i + 1
    end
  end
  return nil
end

--- Inscrit / retire une faction de la prospection de fond.
function Sites.track(f) Scheduler.add(Sites.LANE, f.id) end
function Sites.untrack(id) Scheduler.remove(Sites.LANE, id) end

Scheduler.define_lane(Sites.LANE, LANE_PERIOD, function(id, tick)
  local war = State.war()
  local f = war.factions and war.factions[id]
  if not war.active or not f or f.eliminated then
    Scheduler.remove(Sites.LANE, id)
    return
  end
  local surface = game.surfaces[war.surface]
  if surface then Sites.prospect(f, surface, tick) end
end)

function Sites.claim(f, pos)
  local war = State.war()
  local key = State.site_key(pos)
  war.claims[key] = f.id
  war.claim_pos = war.claim_pos or {}
  war.claim_pos[key] = { x = pos.x, y = pos.y }
end

function Sites.release(pos)
  local war = State.war()
  local key = State.site_key(pos)
  war.claims[key] = nil
  if war.claim_pos then war.claim_pos[key] = nil end
end

return Sites
