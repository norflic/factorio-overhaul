--[[
  Lot X10-CHEMINS, étalonnage E-CH1 (fo-logs/2026-11-07_X10/CHEMINS_CRITERES.md §4) : ce que coûte au PATHFINDER du moteur une
  demande de chemin, PAR CLASSE, avec la boîte et le masque des PNJ (prototype fo-companion, marge 0,15, rayon 2, résolution 0).
  Mod de test seulement : demandes BRUTES (surface.request_path), aucune du mod.

  Carte de banc (graine de fo-autotest.bat). Au départ (avant le tick 300) :
    - un LAC : une tuile d'eau dont le disque de rayon 6 est tout eau (la plus proche de l'origine) ;
    - un départ S sur la terre, à 30 tuiles du lac ; buts : G30 à 30 tuiles de S (côté opposé au lac), G150 à 150 tuiles ;
    - un but ENFERMÉ : un anneau de murs de pierre (carré, demi-côté 3) autour d'un point libre à 30 tuiles de S ;
    - un départ BLOQUÉ : un four de pierre posé à 10 tuiles de S, départ en son centre.
  Phases, dans l'ordre, DEUX tours (chacune : ÉMISSION pendant EMIT ticks, au plus MAXF recherches en vol, une demande au plus par tick, départ
  et but décalés de quelques tuiles d'une demande à l'autre ; puis attente que tout soit fini, WAIT ticks au plus) :
    repos, ok30, ok150, eau, enferme, depart, ok30-cache (même chose que ok30, cache du moteur allumé comme les PNJ), repos, puis
    les mêmes une seconde fois, repos.
  Pour chaque phase, une ligne « PHASE <rang>:<nom> debut T0 fin-emission T1 fin T2 emises N ok a echec b retry c latence L points P » :
  tools/autotest/x10_chemins_etalon.py y lit le pathFinder du moteur (--benchmark-verbose) sur [T0, T2[, moins celui du repos,
  rapporté aux demandes finies. Mesure de TEMPS : --seul seulement, avec l'accord du lead.
    py -3.9 -B tools/autotest/banc.py --seul --qui X10-CHEMINS --out "<racine>\fo-logs\2026-11-07_X10\E-CH1-<n>"
       -- 2400 x10-chemins-etalon <source>
]]

local BODY = "fo-companion"
local PAD, RADIUS, RES = 0.15, 2, 0
local SETUP_END = 300
local EMIT, WAIT, MAXF = 130, 100, 4
-- Deux tours des mêmes classes (bruit lu sur le passage même), encadrés de repos ; clé d'une phase : « <rang>:<nom> ».
local CLASSES = { "ok30", "ok150", "eau", "enferme", "depart", "ok30-cache" }
local PHASES = { "repos" }
for _ = 1, 2 do
  for _, c in ipairs(CLASSES) do PHASES[#PHASES + 1] = c end
  PHASES[#PHASES + 1] = "repos"
end
local CHECK = 2380
local JIT = { { 0, 0 }, { 2, 0 }, { 0, 2 }, { -2, 0 }, { 0, -2 }, { 2, 2 }, { -2, 2 }, { 2, -2 }, { -2, -2 }, { 3, 1 }, { 1, 3 },
  { -3, 1 }, { -1, -3 }, { 3, -1 }, { -3, -1 }, { 1, -3 } }

local function G() global.x10e = global.x10e or { by_id = {}, ph = {} } return global.x10e end

-- Résultats des demandes : abonnement au CHARGEMENT du greffon (F24) ; seul ce scénario s'y abonne quand il est chargé.
script.on_event(defines.events.on_script_path_request_finished, function(e)
  local g = G()
  local r = g.by_id[e.id]
  if not r then return end
  g.by_id[e.id] = nil
  g.inflight = (g.inflight or 1) - 1
  local p = g.ph[r.phase]
  if e.try_again_later then
    p.retry = p.retry + 1
    return
  end
  if e.path then
    p.ok = p.ok + 1
    p.pts = p.pts + #e.path
  else
    p.fail = p.fail + 1
  end
  p.lat = p.lat + (e.tick - r.t0)
end)

local function bbox(pad)
  local b = game.entity_prototypes[BODY].collision_box
  return { { b.left_top.x - pad, b.left_top.y - pad }, { b.right_bottom.x + pad, b.right_bottom.y + pad } }
end

local function land(s, p, r)
  return s.count_tiles_filtered({ position = p, radius = r, collision_mask = "player-layer", limit = 1 }) == 0
end

local function free_spot(s, p)
  local q = s.find_non_colliding_position(BODY, p, 6, 0.5)
  return q and { x = q.x, y = q.y } or nil
end

--- Tuile d'eau dont le disque de rayon 6 est tout eau, la plus proche de l'origine, dans le carré généré [-R, R]².
local function find_lake(s, R)
  local best, bd
  for _, t in ipairs(s.find_tiles_filtered({ area = { { -R, -R }, { R, R } }, name = { "water", "deepwater" }, limit = 20000 })) do
    local p = { x = t.position.x + 0.5, y = t.position.y + 0.5 }
    local d = p.x * p.x + p.y * p.y
    if (not bd or d < bd) and s.count_tiles_filtered({ position = p, radius = 6, collision_mask = "player-layer", invert = true, limit = 1 }) == 0 then
      best, bd = p, d
    end
  end
  return best
end

local S = {
  description = "X10-CHEMINS E-CH1 : cout d'une demande de chemin par classe (pathFinder du moteur)",
  check_tick = CHECK,
}

S.init = function(ctx)
  local s = ctx.surface()
  local g = G()
  s.request_to_generate_chunks({ 0, 0 }, 10)
  s.force_generate_chunk_requests()
  local W = find_lake(s, 320)
  ctx.check(W ~= nil, "lac trouve (disque de rayon 6 tout eau)", W and string.format("(%.1f, %.1f)", W.x, W.y))
  if not W then return end
  -- Départ : terre à 30 tuiles du lac, dans la direction qui laisse le plus de terre (32 directions essayées).
  local Sx
  for k = 0, 31 do
    local a = 2 * math.pi * k / 32
    local p = { x = W.x + 30 * math.cos(a), y = W.y + 30 * math.sin(a) }
    local far = { x = W.x + 60 * math.cos(a), y = W.y + 60 * math.sin(a) }
    if land(s, p, 4) and land(s, far, 4) then
      local q = free_spot(s, p)
      if q then Sx = { p = q, ux = math.cos(a), uy = math.sin(a) } break end
    end
  end
  ctx.check(Sx ~= nil, "depart sur la terre a 30 tuiles du lac", Sx and string.format("(%.1f, %.1f)", Sx.p.x, Sx.p.y))
  if not Sx then return end
  local P0, ux, uy = Sx.p, Sx.ux, Sx.uy
  local px, py = -uy, ux -- perpendiculaire
  local g30 = free_spot(s, { x = P0.x + 30 * ux, y = P0.y + 30 * uy })
  local g150 = free_spot(s, { x = P0.x + 150 * ux, y = P0.y + 150 * uy })
  -- But enfermé : anneau de murs (demi-côté 3) autour d'un point libre à 30 tuiles de S, de côté.
  local ec = free_spot(s, { x = P0.x + 30 * px, y = P0.y + 30 * py })
  local walls = 0
  if ec then
    local cx, cy = math.floor(ec.x) + 0.5, math.floor(ec.y) + 0.5
    ec = { x = cx, y = cy }
    for dx = -3, 3 do
      for dy = -3, 3 do
        if math.max(math.abs(dx), math.abs(dy)) == 3 then
          for _, e in ipairs(s.find_entities_filtered({ area = { { cx + dx - 0.5, cy + dy - 0.5 }, { cx + dx + 0.5, cy + dy + 0.5 } }, type = { "tree", "simple-entity" } })) do e.destroy() end
          if s.create_entity({ name = "stone-wall", position = { cx + dx, cy + dy }, force = "player" }) then walls = walls + 1 end
        end
      end
    end
  end
  -- Départ bloqué : four de pierre à 10 tuiles de S, de l'autre côté.
  local fp = free_spot(s, { x = P0.x - 10 * px, y = P0.y - 10 * py })
  local furnace = fp and s.create_entity({ name = "stone-furnace", position = fp, force = "player" })
  ctx.check(g30 and g150 and ec and walls == 24 and furnace, "buts et obstacles poses (G30, G150, anneau de 24 murs, four)",
    string.format("G30 %s, G150 %s, enferme %s (%d murs), four %s", tostring(g30 ~= nil), tostring(g150 ~= nil), tostring(ec ~= nil), walls, tostring(furnace ~= nil)))
  g.S, g.W, g.g30, g.g150, g.ec = P0, W, g30, g150, ec
  g.fp = furnace and { x = furnace.position.x, y = furnace.position.y } or nil
  local npc = s.count_entities_filtered({ name = BODY })
  local units = s.count_entities_filtered({ type = "unit" })
  ctx.log(string.format("POSE lac (%.1f, %.1f) depart (%.1f, %.1f) G30 (%.1f, %.1f) G150 (%.1f, %.1f) enferme (%.1f, %.1f) four (%.1f, %.1f) ; PNJ sur la carte %d, unites %d",
    W.x, W.y, P0.x, P0.y, g30 and g30.x or 0, g30 and g30.y or 0, g150 and g150.x or 0, g150 and g150.y or 0, ec and ec.x or 0, ec and ec.y or 0,
    g.fp and g.fp.x or 0, g.fp and g.fp.y or 0, npc, units))
  g.i, g.t0, g.emit_end, g.inflight, g.n = 1, SETUP_END, SETUP_END + EMIT, 0, 0
  for i = 1, #PHASES do g.ph[i] = { emitted = 0, ok = 0, fail = 0, retry = 0, lat = 0, pts = 0 } end
  g.ready = true
end

local function request(s, g, name, k)
  local j = JIT[k % #JIT + 1]
  local start, goal, cache = nil, nil, false
  if name == "ok30" or name == "ok30-cache" then
    start, goal, cache = g.S, g.g30, name == "ok30-cache"
  elseif name == "ok150" then
    start, goal = g.S, g.g150
  elseif name == "eau" then
    start, goal = g.S, g.W
  elseif name == "enferme" then
    start, goal = g.S, g.ec
  elseif name == "depart" then
    start, goal = g.fp, g.g30
    j = { 0, 0 } -- départ au centre du four (bloqué)
  end
  if not (start and goal) then return nil end
  local gj = (name == "eau" or name == "enferme") and { 0, 0 } or { j[2], -j[1] }
  return s.request_path({
    bounding_box = bbox(PAD), collision_mask = game.entity_prototypes[BODY].collision_mask,
    start = { x = start.x + j[1], y = start.y + j[2] }, goal = { x = goal.x + gj[1], y = goal.y + gj[2] }, force = "player",
    radius = RADIUS, pathfind_flags = { cache = cache, prefer_straight_paths = true, low_priority = false }, path_resolution_modifier = RES,
  })
end

S.tick = function(ctx, e)
  local g = G()
  if not g.ready or g.done then return end
  local t = e.tick
  if t < g.t0 then return end
  local name = PHASES[g.i]
  local p = g.ph[g.i]
  local emitting = t < g.emit_end and not name:find("^repos")
  if emitting and (g.inflight or 0) < MAXF then
    g.n = g.n + 1
    local id = request(ctx.surface(), g, name, g.n)
    if id then
      g.by_id[id] = { phase = g.i, t0 = t }
      g.inflight = (g.inflight or 0) + 1
      p.emitted = p.emitted + 1
    end
  end
  local over = t >= g.emit_end and ((g.inflight or 0) == 0 or t >= g.emit_end + WAIT)
  if over then
    ctx.log(string.format("PHASE %d:%s debut %d fin-emission %d fin %d emises %d ok %d echec %d retry %d latence %.2f points %.1f en-vol %d",
      g.i, name, g.t0, g.emit_end, t, p.emitted, p.ok, p.fail, p.retry, (p.ok + p.fail) > 0 and p.lat / (p.ok + p.fail) or 0,
      p.ok > 0 and p.pts / p.ok or 0, g.inflight or 0))
    g.i = g.i + 1
    if g.i > #PHASES then g.done = true return end
    g.t0 = t + 1
    g.emit_end = g.t0 + EMIT
    -- Les demandes encore en vol (attente dépassée) restent comptées dans leur phase d'origine.
  end
end

S.finish = function(ctx)
  local g = G()
  ctx.check(g.done == true, "toutes les phases jouees avant la fin", tostring(g.i))
  local by = {}
  for i, name in ipairs(PHASES) do
    local p = g.ph[i]
    if p then
      local b = by[name] or { ok = 0, fail = 0 }
      b.ok, b.fail = b.ok + p.ok, b.fail + p.fail
      by[name] = b
    end
  end
  if not by.ok30 then return end
  ctx.check(by.ok30.ok > 0 and by.ok150.ok > 0, "des chemins trouves (ok30, ok150)", string.format("%d, %d", by.ok30.ok, by.ok150.ok))
  ctx.check(by.eau.fail > 0 and by.enferme.fail > 0, "des echecs vers le lac et vers le but enferme", string.format("%d, %d", by.eau.fail, by.enferme.fail))
end

return S
