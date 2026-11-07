--[[
  Service de pathfinding partagé (compagnons aujourd'hui, faction IA demain).

  Pourquoi un service plutôt que des appels directs à LuaSurface.request_path :
  - Le pathfinder moteur est UNE ressource partagée avec les biters : il sert sans condition tant que
    10 CLIENTS au plus sont en cours de service (map_settings.path_finder.max_clients_to_accept_any_new_request ;
    ce n'est pas un nombre de requêtes par tick : lot IA1-a, docs/EQUIPES_PNJ.md §12), puis seulement les
    requêtes courtes jusqu'à 100 clients, et développe 1 000 nœuds par tick pour tous. Sans plafond côté script,
    une armée IA affame les biters et inversement : au plus fo-path-max-inflight demandes du mod en vol (6) et
    fo-path-issue-per-tick émises par tick (2).
  - Les résultats arrivent de façon asynchrone (on_script_path_request_finished) : il faut une table
    "en vol" persistante, un ticket anti-résultat-périmé, des relances sur "try_again_later" et un timeout.

  API :
    PathService.register_handler(name, fn(owner, path|nil, ticket, reason, tick))   -- au chargement
    PathService.request(handler_name, owner, req) -> ticket
      req = { surface = index, proto = nom_prototype, pad = marge_bbox, start = pos, goal = pos,
              force = nom_force, radius = n, flags = PathfinderFlags, ignore = LuaEntity|nil, res = int }
    reason ∈ "ok" | "no_path" | "busy" | "timeout" | "dropped"

  Lot X10-CHEMINS (L5, règle pure shared/nav/chemins.lua) : avant request_path, un but dont le disque de rayon radius + 1,5 n'a
  aucune tuile praticable n'est PAS demandé (« no_path » livré au tick même, compté refused_water) ; un départ encore bloqué pour
  la boîte élargie mais libre pour la boîte du prototype est demandé sans marge (start_unpadded). Interface distante « fo-chemins »
  (bancs) : journal des demandes ([FO-CHEMINS-J], coupé par défaut) et lecture des stats.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local Config = require("script.core.config")
local Scheduler = require("script.core.scheduler")
local Profiler = require("script.core.profiler")
local Trace = require("script.core.trace")
local Ch = require("shared.nav.chemins")

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
      checks_goal = Ch.checks_goal(layers), -- lot X10-CHEMINS (L5) : contrôle du but (couche player-layer)
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

--- Lot X10-CHEMINS (L5) : observations du BUT pour Ch.precheck (shared/nav/chemins.lua) : tuiles praticables du disque de rayon
--- Ch.check_radius(radius), puis, seulement s'il n'y en a aucune, tuiles bloquantes du même disque et chunks générés. Un seul appel
--- au moteur quand le disque a une tuile praticable (le cas ordinaire). Rien pour un prototype sans la couche (info.checks_goal).
local function goal_obs(surface, info, req, obs)
  if not info.checks_goal then return end
  local g = req.goal
  local gx, gy = g.x or g[1], g.y or g[2] -- position en table nommée ou en tableau (MapPosition)
  local r = Ch.check_radius(req.radius)
  obs.goal_land = surface.count_tiles_filtered({ position = g, radius = r, collision_mask = Ch.LAYER, invert = true, limit = 1 })
  if obs.goal_land > 0 then return end
  obs.goal_blocking = surface.count_tiles_filtered({ position = g, radius = r, collision_mask = Ch.LAYER, limit = 1 })
  if obs.goal_blocking == 0 then return end
  local gen = true
  for _, c in ipairs(Ch.disc_chunks(gx, gy, r)) do
    if not surface.is_chunk_generated({ x = c[1], y = c[2] }) then
      gen = false
      break
    end
  end
  obs.goal_generated = gen
end

--- Lot X10-CHEMINS (relevé du lot L6) : une ligne par demande quand le journal est allumé (interface « fo-chemins », bancs
--- seulement ; coupé par défaut : un test de booléen par demande). ev : « R » refusée, « E » émise, « F » finie.
local function jlog(P, ev, req, tick, a, b, c)
  if not P.journal then return end
  log(string.format("[FO-CHEMINS-J] %d %s %d %s %s %.2f %.2f %.2f %.2f %s %s %s %s %s %s", tick, ev, req.ticket, tostring(req.h),
    tostring(req.owner), req.start.x or req.start[1], req.start.y or req.start[2], req.goal.x or req.goal[1], req.goal.y or req.goal[2],
    tostring(req.radius), tostring(req.pad),
    tostring(req.res), tostring(a), tostring(b), tostring(c)))
end

local function classify_failure(P, req)
  local surface = game.surfaces[req.surface]
  if not surface then return end
  local st = P.stats
  local gx, gy = req.goal.x, req.goal.y
  local tile = surface.get_tile(math.floor(gx), math.floor(gy))
  local info = proto_info(req.proto, req.bare and 0 or req.pad) -- lot X10-CHEMINS : demande partie sans marge (« unpad »)
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
  return cause
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
  -- Lot IA1-a : au plus fo-path-issue-per-tick demandes ÉMISES par tick (lissage des pointes : une armée qui
  -- part, des PNJ qui se débloquent ensemble), en plus de la limite des demandes en vol. Suivi : taille de la
  -- file et demandes en vol au plus haut (docs/EQUIPES_PNJ.md §12), émissions par tick au plus haut.
  local per_tick = Config.get("path_issue_per_tick")
  local st0 = P.stats
  local waiting = P.tail - P.head + 1
  if waiting > (st0.queue_max or 0) then st0.queue_max = waiting end
  local issued_now = 0
  while P.inflight_count < max_inflight and P.head <= P.tail and issued_now < per_tick do
    issued_now = issued_now + 1
    local req = P.queue[P.head]
    P.queue[P.head] = nil
    P.head = P.head + 1
    local surface = game.surfaces[req.surface]
    local info = surface and (req.ignore == nil or req.ignore.valid) and proto_info(req.proto, req.pad)
    -- Lot X10-CHEMINS (L5) : but impossible (aucune tuile praticable à moins de radius + 1,5) : rien n'est demandé au moteur ;
    -- « no_path » est livré au même gestionnaire, au tick même (comme « dropped »). La demande prend sa place dans le débit par
    -- tick (issued_now) : la file avance au même pas qu'avant.
    local obs = { pad = req.pad }
    req.bare = nil -- relance (« try_again_later ») : la boîte est rejugée
    if info then goal_obs(surface, info, req, obs) end
    if info and Ch.precheck(obs) == "refuse_water" then
      P.stats.refused_water = (P.stats.refused_water or 0) + 1
      jlog(P, "R", req, tick, "eau")
      deliver(req, nil, "no_path", tick)
    elseif info then
      -- Départ chevauchant un autre corps (foule d'agents, bâtiment) : le pathfinder échoue d'emblée.
      -- On part du point libre le plus proche (le corps y marche en premier waypoint).
      if req.ignore and start_blocker(surface, info, req.start, req.ignore) then
        local pushed = push_out(surface, info, req.start, req.ignore)
        local free = pushed or surface.find_non_colliding_position(req.proto, req.start, 3, 0.25)
        if free then
          req.start = free
          P.stats.start_moved = (P.stats.start_moved or 0) + 1
        end
        -- Lot X10-CHEMINS (L5) : find_non_colliding_position ne connaît que la boîte du prototype ; si la boîte ÉLARGIE touche
        -- encore un obstacle, la demande part avec la boîte du prototype (elle échouait au départ : 1 079 fois dans la partie
        -- du DC).
        if not pushed and req.pad > 0 then
          obs.start_blocked = start_blocker(surface, info, req.start, req.ignore) ~= nil
          if obs.start_blocked then
            obs.start_free_bare = start_blocker(surface, proto_info(req.proto, 0), req.start, req.ignore) == nil
          end
        end
      end
      if Ch.precheck(obs) == "unpad" then
        info = proto_info(req.proto, 0)
        req.bare = true
        P.stats.start_unpadded = (P.stats.start_unpadded or 0) + 1
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
      if P.inflight_count > (P.stats.inflight_max or 0) then P.stats.inflight_max = P.inflight_count end
      jlog(P, "E", req, tick, req.bare and "nu" or "-")
    else
      P.stats.dropped = P.stats.dropped + 1
      deliver(req, nil, "dropped", tick)
    end
  end
  if issued_now > (st0.issued_tick_max or 0) then st0.issued_tick_max = issued_now end
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
      jlog(P, "F", req, e.tick, "retry", 0, e.tick - f.t0)
    else
      st.fail = st.fail + 1
      jlog(P, "F", req, e.tick, "busy", 0, e.tick - f.t0)
      deliver(req, nil, "busy", e.tick)
    end
  elseif e.path then
    st.ok = st.ok + 1
    st.latency_sum = st.latency_sum + (e.tick - f.t0)
    st.waypoints_sum = st.waypoints_sum + #e.path
    if #e.path > 120 then Trace.log("path", req.h, #e.path) end
    jlog(P, "F", req, e.tick, "ok", #e.path, e.tick - f.t0)
    deliver(req, e.path, "ok", e.tick)
  else
    st.fail = st.fail + 1
    -- Lot X10-CHEMINS : latence des ÉCHECS comptée (elle ne l'était pas : le coût d'un échec n'était pas lisible).
    st.fail_latency_sum = (st.fail_latency_sum or 0) + (e.tick - f.t0)
    local cause = classify_failure(P, req)
    jlog(P, "F", req, e.tick, "no_path:" .. tostring(cause), 0, e.tick - f.t0)
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
    jlog(P, "F", f.req, e.tick, "timeout", 0, e.tick - f.t0)
    deliver(f.req, nil, "timeout", e.tick)
  end
end)

-- Lot X10-CHEMINS : bancs seulement. journal(true|false) allume ou coupe les lignes [FO-CHEMINS-J] ; stats() rend une copie des
-- compteurs du service (nombres seulement).
remote.add_interface("fo-chemins", {
  journal = function(on)
    Storage.ns("path").journal = on and true or nil
    return Storage.ns("path").journal == true
  end,
  stats = function()
    local out = {}
    for k, v in pairs(Storage.ns("path").stats) do out[k] = v end
    return out
  end,
})

return PathService
