--[[
  Service de pathfinding partagé (compagnons aujourd'hui, faction IA demain).

  Pourquoi un service plutôt que des appels directs à LuaSurface.request_path :
  - Le pathfinder moteur est UNE ressource partagée avec les biters : par défaut il n'accepte que
    10 nouvelles requêtes par tick (map_settings.path_finder.max_clients_to_accept_any_new_request) et
    1 000 nœuds développés par tick. Sans plafond côté script, une armée IA affame les biters et inversement.
  - Les résultats arrivent de façon asynchrone (on_script_path_request_finished) : il faut une table
    "en vol" persistante, un ticket anti-résultat-périmé, des relances sur "try_again_later" et un timeout.

  API :
    PathService.register_handler(name, fn(owner, path|nil, ticket, reason, tick))   -- au chargement
    PathService.request(handler_name, owner, req) -> ticket
      req = { surface = index, proto = nom_prototype, pad = marge_bbox, start = pos, goal = pos,
              force = nom_force, radius = n, flags = PathfinderFlags, ignore = LuaEntity|nil, res = int }
    reason ∈ "ok" | "no_path" | "busy" | "timeout" | "dropped"
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local Config = require("script.core.config")
local Scheduler = require("script.core.scheduler")
local Profiler = require("script.core.profiler")
local Trace = require("script.core.trace")

local PathService = {}

local MAX_RETRIES = 4
local RETRY_BASE_DELAY = 15     -- ticks, multiplié par le rang de la relance
local TIMEOUT_TICKS = 1800
local SWEEP_PERIOD = 120
local RETRY_TIMER = "fo-path-retry"

local handlers = {}
local proto_cache = {}  -- [nom][pad] = { bbox, mask, layers } — local, reconstruit à la demande

Storage.declare("path", function()
  return {
    queue = {}, head = 1, tail = 0,
    inflight = {}, inflight_count = 0,
    next_ticket = 0,
    stats = {
      requested = 0, issued = 0, ok = 0, fail = 0, retry = 0, timeout = 0, dropped = 0,
      latency_sum = 0, waypoints_sum = 0,
    },
  }
end)

function PathService.register_handler(name, fn)
  assert(not handlers[name], "handler de chemin déjà défini : " .. name)
  handlers[name] = fn
end

local function proto_info(name, pad)
  local by_pad = proto_cache[name]
  if not by_pad then
    by_pad = {}
    proto_cache[name] = by_pad
  end
  local c = by_pad[pad]
  if not c then
    local p = game.entity_prototypes[name]
    local lt, rb = p.collision_box.left_top, p.collision_box.right_bottom
    -- Couches seules (sans les drapeaux du masque) : filtre des recherches d'obstacles au départ.
    local layers = {}
    for layer in pairs(p.collision_mask) do
      if layer ~= "consider-tile-transitions" and layer ~= "not-colliding-with-itself"
        and layer ~= "colliding-with-tiles-only" then
        layers[#layers + 1] = layer
      end
    end
    table.sort(layers)
    c = {
      bbox = { { lt.x - pad, lt.y - pad }, { rb.x + pad, rb.y + pad } },
      mask = p.collision_mask,
      layers = layers,
    }
    by_pad[pad] = c
  end
  return c
end

local function enqueue(P, req)
  P.tail = P.tail + 1
  P.queue[P.tail] = req
end

--- Diagnostic d'un échec "no_path" (moteur réel, session 3 : 69 % d'échecs à expliquer).
--- Catégories : but sur l'eau, but occupé (can_place_entity faux), autre (inaccessible : falaises, forêt…).
--- Entités (autres que le demandeur) qui chevauchent la boîte du corps à la position pos ; nil si aucune.
local function start_blocker(surface, info, pos, ignore)
  local b = info.bbox
  local hits = surface.find_entities_filtered({
    area = { { pos.x + b[1][1], pos.y + b[1][2] }, { pos.x + b[2][1], pos.y + b[2][2] } },
    collision_mask = info.layers, limit = 4,
  })
  for _, h in ipairs(hits) do
    if h ~= ignore then return h end
  end
  return nil
end

--- Sort le point de départ de la boîte (élargie) des obstacles qui la chevauchent : on pousse le point
--- juste au-delà du côté le plus proche de l'obstacle, jusqu'à 3 fois. Moteur réel (session 4) : un
--- ouvrier collé au QG avait un départ « libre » pour son corps mais pas pour la boîte élargie de la
--- requête ; find_non_colliding_position ne connaît que la boîte du prototype : 151 échecs en 30 min
--- pour une équipe, économie à l'arrêt.
local function push_out(surface, info, pos, ignore)
  local half = math.max(-info.bbox[1][1], info.bbox[2][1], -info.bbox[1][2], info.bbox[2][2]) + 0.15
  local p = { x = pos.x, y = pos.y }
  for _ = 1, 3 do
    local b = start_blocker(surface, info, p, ignore)
    if not b then return p end
    local bb = b.bounding_box
    local lt, rb = bb.left_top, bb.right_bottom
    local cands = {
      { x = lt.x - half, y = p.y }, { x = rb.x + half, y = p.y },
      { x = p.x, y = lt.y - half }, { x = p.x, y = rb.y + half },
    }
    local best, best_d
    for _, c in ipairs(cands) do
      local dx, dy = c.x - p.x, c.y - p.y
      local d = dx * dx + dy * dy
      if not best_d or d < best_d then best, best_d = c, d end
    end
    p = best
  end
  if start_blocker(surface, info, p, ignore) then return nil end
  return p
end

local function classify_failure(P, req)
  local surface = game.surfaces[req.surface]
  if not surface then return end
  local st = P.stats
  local gx, gy = req.goal.x, req.goal.y
  local tile = surface.get_tile(math.floor(gx), math.floor(gy))
  local info = proto_info(req.proto, req.pad)
  local blocker = req.ignore and req.ignore.valid and start_blocker(surface, info, req.start, req.ignore)
  local cause
  if blocker then
    cause = "start"
  elseif tile.valid and tile.collides_with("water-tile") then
    cause = "water"
  elseif not surface.can_place_entity({ name = req.proto, position = req.goal }) then
    cause = "blocked"
  else
    cause = "other"
  end
  st["fail_" .. cause] = (st["fail_" .. cause] or 0) + 1
  local dx, dy = gx - req.start.x, gy - req.start.y
  P.fail_samples = P.fail_samples or {}
  local s = P.fail_samples
  s[#s + 1] = string.format("%s%s d=%.0f (%.0f,%.0f)->(%.0f,%.0f) %s", cause, blocker and (":" .. blocker.name) or "",
    math.sqrt(dx * dx + dy * dy), req.start.x, req.start.y, gx, gy, tile.valid and tile.name or "?")
  if #s > 6 then table.remove(s, 1) end
end

function PathService.fail_samples()
  return Storage.ns("path").fail_samples or {}
end

local function deliver(req, path, reason, tick)
  local h = handlers[req.h]
  if h then h(req.owner, path, req.ticket, reason, tick) end
end

function PathService.request(handler_name, owner, req)
  assert(handlers[handler_name], "handler de chemin inconnu : " .. tostring(handler_name))
  local P = Storage.ns("path")
  P.next_ticket = P.next_ticket + 1
  req.h = handler_name
  req.owner = owner
  req.ticket = P.next_ticket
  req.retries = 0
  req.pad = req.pad or 0
  enqueue(P, req)
  P.stats.requested = P.stats.requested + 1
  return req.ticket
end

function PathService.queued()
  local P = Storage.ns("path")
  return P.tail - P.head + 1, P.inflight_count
end

function PathService.reset_stats()
  local st = Storage.ns("path").stats
  for k in pairs(st) do st[k] = 0 end
end

local function pump(tick)
  local P = Storage.ns("path")
  if P.head > P.tail then return end
  local max_inflight = Config.get("path_max_inflight")
  while P.inflight_count < max_inflight and P.head <= P.tail do
    local req = P.queue[P.head]
    P.queue[P.head] = nil
    P.head = P.head + 1
    local surface = game.surfaces[req.surface]
    if surface and (req.ignore == nil or req.ignore.valid) then
      local info = proto_info(req.proto, req.pad)
      -- Départ chevauchant un autre corps (foule d'agents, bâtiment) : le pathfinder échoue d'emblée.
      -- On part du point libre le plus proche (le corps y marche en premier waypoint).
      if req.ignore and start_blocker(surface, info, req.start, req.ignore) then
        local free = push_out(surface, info, req.start, req.ignore)
          or surface.find_non_colliding_position(req.proto, req.start, 3, 0.25)
        if free then
          req.start = free
          P.stats.start_moved = (P.stats.start_moved or 0) + 1
        end
      end
      local id = surface.request_path({
        bounding_box = info.bbox,
        collision_mask = info.mask,
        start = req.start,
        goal = req.goal,
        force = req.force,
        radius = req.radius,
        pathfind_flags = req.flags,
        path_resolution_modifier = req.res,
        entity_to_ignore = req.ignore,
      })
      P.inflight[id] = { req = req, t0 = tick }
      P.inflight_count = P.inflight_count + 1
      P.stats.issued = P.stats.issued + 1
    else
      P.stats.dropped = P.stats.dropped + 1
      deliver(req, nil, "dropped", tick)
    end
  end
  if P.head > P.tail then
    P.head = 1
    P.tail = 0
  end
end

Scheduler.define_timer(RETRY_TIMER, function(req)
  enqueue(Storage.ns("path"), req)
end)

-- Enregistré après le Scheduler : les demandes émises par les cerveaux pendant ce tick partent ce tick.
Events.on(defines.events.on_tick, function(e)
  Profiler.start("path:pump")
  pump(e.tick)
  Profiler.stop("path:pump")
end)

Events.on(defines.events.on_script_path_request_finished, function(e)
  local P = Storage.ns("path")
  local f = P.inflight[e.id]
  if not f then return end
  Profiler.start("path:callback")
  P.inflight[e.id] = nil
  P.inflight_count = P.inflight_count - 1
  local req, st = f.req, P.stats
  if e.try_again_later then
    st.retry = st.retry + 1
    if req.retries < MAX_RETRIES then
      req.retries = req.retries + 1
      Scheduler.after(RETRY_BASE_DELAY * req.retries, RETRY_TIMER, req)
    else
      st.fail = st.fail + 1
      deliver(req, nil, "busy", e.tick)
    end
  elseif e.path then
    st.ok = st.ok + 1
    st.latency_sum = st.latency_sum + (e.tick - f.t0)
    st.waypoints_sum = st.waypoints_sum + #e.path
    if #e.path > 120 then Trace.log("path", req.h, #e.path) end
    deliver(req, e.path, "ok", e.tick)
  else
    st.fail = st.fail + 1
    classify_failure(P, req)
    deliver(req, nil, "no_path", e.tick)
  end
  Profiler.stop("path:callback")
end)

-- Filet de sécurité : une requête sans réponse (ex. perdue au chargement) est libérée après TIMEOUT_TICKS.
Events.on_nth_tick(SWEEP_PERIOD, function(e)
  local P = Storage.ns("path")
  if P.inflight_count == 0 then return end
  local expired = {}
  for id, f in pairs(P.inflight) do
    if e.tick - f.t0 > TIMEOUT_TICKS then expired[#expired + 1] = id end
  end
  table.sort(expired) -- ordre indépendant de l'itération de pairs
  for i = 1, #expired do
    local id = expired[i]
    local f = P.inflight[id]
    P.inflight[id] = nil
    P.inflight_count = P.inflight_count - 1
    P.stats.timeout = P.stats.timeout + 1
    deliver(f.req, nil, "timeout", e.tick)
  end
end)

return PathService
