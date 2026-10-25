--[[
  Lot IA2-c : le JOUEUR SOUS BROUILLARD (D-16 : « brouillard partout », le joueur aussi). Exécution du modèle pur
  de shared/faction/adversaire.lua.

  Avant IA2-c (IA0) : un balayage global comptait les bâtiments du joueur sur un disque de 1 536 tuiles autour de son
  point de départ, et toutes les factions lisaient ce comptage (« elles voyaient tout »). Désormais :
    - chaque faction a ses YEUX : son QG (160 tuiles), ses avant-postes (128), ses groupes en route (96) et son
      ÉCLAIREUR (128) ; un secteur de 64 × 64 tuiles n'est regardé que s'il est dans ce champ (A.visible) ;
    - REGARDER un secteur = 1 comptage moteur (comme un pas de l'ancien balayage) ; s'il porte au moins sector_min
      installations, la faction retient la plus proche de son QG (cible) et la position des tourelles qu'elle y voit ;
      le coût reste celui de l'ancien balayage : 1 regard toutes les 8 ticks (voie « fo-pvp-scan »), les factions à
      tour de rôle ; rien en « Paisible » ;
    - ÉCLAIREURS : 6 min avant la fin de sa grâce, puis quand ce qu'elle sait du joueur date de plus de 10 min, une
      faction envoie un soldat vers le point de départ du joueur (connu, comme les QG rivaux) ou vers sa cible, puis
      autour (anneaux de 224 et 448 tuiles) ; il regarde à l'arrivée et rentre ;
    - MODÈLE du joueur (une fois par minute) : secteurs vus, tourelles vues, croissance sur 10 min, étendue, coups reçus
      de lui, attaques repoussées : style (tortue, expansionniste, agresseur, bâtisseur, équilibré, inconnu) ; le
      style choisit la CIBLE (A.pick_target) ;
    - CÔTÉ D'ARRIVÉE : défense vue par octant autour de la cible, le côté le moins défendu (A.pick_side) ; GO / NO-GO
      au rassemblement (A.go) ; ISSUE de chaque attaque (« [FO-PVP] issue ») et mémoire (défense apprise, octants
      pénalisés).

  État (nombres et tables seulement) : f.pvp.vision = { known, looked, queue, qi, reports, static, static_at,
  static_i, next_scout, scout_i, model, stream } ; war.pvp : tempo, first_done, looks (compteur `sweeps`).
  Flux : Tr.new_stream(graine, 300 + id) (sels 300 à 399 : lot IA2-c ; 300 = partie, tempo de la 1re attaque).
]]

local Events = require("script.core.events")
local F = require("shared.faction.config")
local S = require("shared.faction.strategy")
local A = require("shared.faction.adversaire")
local C = require("shared.faction.chef")
local Tr = require("shared.faction.traits")
local State = require("script.faction.state")
local Military = require("script.faction.military")
local Character = require("script.faction.character")

local Vision = {}

Vision.SALT = 300
local R = F.pvp_rules

-- Installations du joueur qui comptent comme cibles (production, énergie, défense, stockage), comme IA0.
Vision.INSTALL_TYPES = {
  "assembling-machine", "furnace", "mining-drill", "lab", "boiler", "generator", "reactor", "solar-panel",
  "accumulator", "radar", "rocket-silo", "roboport", "beacon", "storage-tank", "container", "logistic-container",
  "ammo-turret", "electric-turret", "fluid-turret", "artillery-turret",
}
Vision.TURRET_TYPES = { "ammo-turret", "electric-turret", "fluid-turret", "artillery-turret" }

local MOVING_RELOOK = 3600   -- un secteur vu par un œil mobile est regardé de nouveau après 60 s
local KNOWN_RELOOK = 7200    -- un secteur connu dans le champ est regardé de nouveau après 2 min
local STATIC_RELOOK = 14400  -- champ fixe (QG, avant-postes) : chaque secteur au plus toutes les 4 min
local STATIC_PER_PLAN = 4    -- secteurs du champ fixe ajoutés à chaque pensée
local QUEUE_MAX = 12
local STATIC_REFRESH = 5 * 3600
local RING = { 224, 448 }

---------------------------------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------------------------------
function Vision.state(f)
  local fp = f.pvp
  if not fp then return nil end
  local v = fp.vision
  if not v then
    v = {
      known = {}, looked = {}, queue = {}, qi = 1, reports = {}, static = nil, static_at = nil, static_i = 1,
      next_scout = 0, scout_i = 0,
      model = { snaps = {}, hits = {}, given = {}, learned = {}, repulsed = 0, style = "inconnu", next_snap = 0 },
      stream = Tr.new_stream(Character.map_seed(), Vision.SALT + f.id),
    }
    fp.vision = v
  end
  return v
end

local function draw_of(v) return function(n) return Tr.range(v.stream, 1, n) end end

--- Tempo de la partie (1re attaque contre le joueur), tiré une fois du flux de la partie (sel 300).
function Vision.game_tempo(p)
  if not p.tempo then
    local st = Tr.new_stream(Character.map_seed(), Vision.SALT)
    p.tempo = A.draw_tempo(function(n) return Tr.range(st, 1, n) end)
  end
  return p.tempo
end

--- La 1re attaque de la partie contre le joueur est-elle partie ? (partie existante : oui si une faction a attaqué.)
function Vision.first_done(p)
  if p.first_done == nil then
    p.first_done = false
    local war = State.war()
    for _, id in ipairs(State.sorted_keys(war.factions or {})) do
      local fp = war.factions[id].pvp
      if fp and (fp.attacks or 0) > 0 then p.first_done = true end
    end
  end
  return p.first_done
end

---------------------------------------------------------------------------------------------------
-- Yeux et champ de vision
---------------------------------------------------------------------------------------------------
--- Yeux d'une faction : { x, y, r, moving } (QG, avant-postes, puis groupes en route, éclaireur compris).
function Vision.eyes(f, moving_only)
  local list = {}
  if not moving_only then
    if f.hq_pos then list[#list + 1] = { x = f.hq_pos.x, y = f.hq_pos.y, r = A.VISION.hq } end
    for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
      local p = f.outposts[oid].pos
      list[#list + 1] = { x = p.x, y = p.y, r = A.VISION.outpost }
    end
  end
  for _, gid in ipairs(State.sorted_keys(f.groups or {})) do
    local g = f.groups[gid]
    if g.group and g.group.valid then
      local p = g.group.position
      list[#list + 1] = { x = p.x, y = p.y, r = g.state == "scout" and A.VISION.scout or A.VISION.group, moving = true }
    end
  end
  return list
end

local function push(q, inq, k)
  if #q < QUEUE_MAX and not inq[k] then
    q[#q + 1] = k
    inq[k] = true
  end
end

--- File des secteurs à regarder (refaite à chaque pensée du commandant) : rapports d'éclaireur et de rassemblement,
--- champ des yeux mobiles, secteurs connus dans le champ, puis quelques secteurs du champ fixe (curseur).
function Vision.plan(f, tick)
  local v = Vision.state(f)
  local q, inq = {}, {}
  -- Secteurs de la file précédente pas encore regardés (rapports d'éclaireur compris) : d'abord.
  for i = v.qi, #v.queue do push(q, inq, v.queue[i]) end
  local used = 0
  for i, k in ipairs(v.reports) do
    if #q >= QUEUE_MAX then break end
    push(q, inq, k)
    used = i
  end
  local rest = {}
  for i = used + 1, #v.reports do rest[#rest + 1] = v.reports[i] end
  v.reports = rest
  local moving = A.visible(Vision.eyes(f, true))
  for _, k in ipairs(moving) do
    if tick - (v.looked[k] or -1e9) >= MOVING_RELOOK then push(q, inq, k) end
  end
  if not v.static or tick - (v.static_at or 0) >= STATIC_REFRESH or v.static_n ~= (f.outposts_count or 0) then
    local eyes = Vision.eyes(f)
    local fixed = {}
    for _, e in ipairs(eyes) do if not e.moving then fixed[#fixed + 1] = e end end
    v.static = A.visible(fixed)
    v.static_at, v.static_n = tick, f.outposts_count or 0
    if v.static_i > #v.static then v.static_i = 1 end
  end
  local in_static = {}
  for _, k in ipairs(v.static) do in_static[k] = true end
  local moving_set = {}
  for _, k in ipairs(moving) do moving_set[k] = true end
  for _, k in ipairs(State.sorted_keys(v.known)) do
    if (in_static[k] or moving_set[k]) and tick - (v.looked[k] or -1e9) >= KNOWN_RELOOK then push(q, inq, k) end
  end
  local added, steps = 0, 0
  while added < STATIC_PER_PLAN and steps < #v.static do
    local k = v.static[v.static_i]
    v.static_i = v.static_i % #v.static + 1
    steps = steps + 1
    if tick - (v.looked[k] or -1e9) >= STATIC_RELOOK then
      push(q, inq, k)
      added = added + 1
    end
  end
  v.queue, v.qi = q, 1
end

--- Regarder un secteur : 1 comptage ; s'il porte une cible, l'installation la plus proche de notre QG et les
--- tourelles qui s'y trouvent (2 recherches). Renvoie le nombre d'installations vues.
function Vision.look(f, surface, key, tick, p)
  local v = Vision.state(f)
  v.looked[key] = tick
  if p then p.sweeps = (p.sweeps or 0) + 1 end
  local sx, sy = A.xy(key)
  if not surface.is_chunk_generated({ x = sx * 2, y = sy * 2 }) then
    v.known[key] = nil
    return 0
  end
  local x0, y0 = sx * A.SECTOR, sy * A.SECTOR
  local area = { { x0, y0 }, { x0 + A.SECTOR, y0 + A.SECTOR } }
  local n = surface.count_entities_filtered({ area = area, force = "player", type = Vision.INSTALL_TYPES, limit = 64 })
  if n < R.sector_min then
    v.known[key] = nil
    return n
  end
  local list = surface.find_entities_filtered({ area = area, force = "player", type = Vision.INSTALL_TYPES, limit = 16 })
  -- Cible : l'installation la plus proche de notre QG, une tourelle seulement s'il n'y a qu'elles (lot IA2-c : on
  -- frappe la base, on contourne ses tourelles par le côté le moins défendu).
  local pos, pd, pt
  for _, e in ipairs(list) do
    local ep = e.position
    local dx, dy = ep.x - f.hq_pos.x, ep.y - f.hq_pos.y
    local dd = dx * dx + dy * dy
    local turret = e.type == "ammo-turret" or e.type == "electric-turret" or e.type == "fluid-turret" or e.type == "artillery-turret"
    if pos and pt ~= turret then
      if pt and not turret then pos, pd, pt = { x = ep.x, y = ep.y }, dd, turret end
    elseif not pd or dd < pd or (dd == pd and (ep.x < pos.x or (ep.x == pos.x and ep.y < pos.y))) then
      pos, pd, pt = { x = ep.x, y = ep.y }, dd, turret
    end
  end
  local tl = surface.find_entities_filtered({ area = area, force = "player", type = Vision.TURRET_TYPES, limit = 32 })
  local turrets = {}
  for _, e in ipairs(tl) do turrets[#turrets + 1] = { x = e.position.x, y = e.position.y } end
  if pos then v.known[key] = { n = n, x = pos.x, y = pos.y, t = turrets, tick = tick } else v.known[key] = nil end
  return n
end

--- Un regard de la voie « fo-pvp-scan » (toutes les 8 ticks) : les factions à tour de rôle, le secteur suivant de
--- leur file. Aucun appel moteur quand la file est vide.
function Vision.pass(surface, p, tick)
  local alive = State.alive()
  if #alive == 0 then return end
  local war = State.war()
  for _ = 1, #alive do
    p.fcursor = (p.fcursor or 0) % #alive + 1
    local f = war.factions[alive[p.fcursor]]
    local v = f and f.pvp and f.pvp.vision
    if v and f.hq_pos then
      local k = v.queue[v.qi]
      if k then
        v.qi = v.qi + 1
        Vision.look(f, surface, k, tick, p)
        return
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Ce que la faction sait du joueur
---------------------------------------------------------------------------------------------------
--- Tourelles vues (toutes les positions retenues des secteurs connus, sans doublon de bord : F96).
local function known_turrets(v)
  local out, seen = {}, {}
  for _, k in ipairs(State.sorted_keys(v.known)) do
    for _, t in ipairs(v.known[k].t or {}) do
      local id = math.floor(t.x * 4) * 1048576 + math.floor(t.y * 4)
      if not seen[id] then
        seen[id] = true
        out[#out + 1] = t
      end
    end
  end
  return out
end
Vision.known_turrets = known_turrets

--- Secteurs connus, avec la défense vue autour de leur cible (+ défense apprise des attaques repoussées).
function Vision.known_list(f)
  local v = Vision.state(f)
  local turrets = known_turrets(v)
  local list = {}
  for _, k in ipairs(State.sorted_keys(v.known)) do
    local s = v.known[k]
    local def = R.defense_per_turret * A.turrets_near(turrets, s, R.defense_radius) + (v.model.learned[k] or 0)
    list[#list + 1] = { key = k, x = s.x, y = s.y, n = s.n, def = def }
  end
  return list, turrets
end

--- Vue « joueur » pour S.decide : territoire VU (secteurs), défense vue de la cible choisie par le style. nil si la
--- faction ne sait rien du joueur. Met à jour fp.target (pos, secteur, défense ; réévaluée toutes les target_ttl).
function Vision.player_view(f, p, fp, tick)
  local v = Vision.state(f)
  local list = Vision.known_list(f)
  if #list == 0 then
    fp.target = nil
    return nil
  end
  local t = fp.target
  if not t or tick - t.tick >= R.target_ttl or not v.known[t.sector] then
    local home = A.key(p.home.x, p.home.y)
    local s = A.pick_target(list, f.hq_pos, home, v.model.style)
    t = { pos = { x = s.x, y = s.y }, sector = s.key, defense = s.def, tick = tick }
    fp.target = t
  end
  return { score = #list, defense = t.defense, reachable = true }
end

--- Options d'une attaque contre le joueur : côté le moins défendu (défense vue par octant), rassemblement avancé à
--- 56 tuiles, défense de départ (go / no-go), secteur visé (mémoire).
function Vision.attack_opts(f, pos, defense, key)
  local v = Vision.state(f)
  local turrets = known_turrets(v)
  local sides = A.side_defense(turrets, pos, R.defense_radius)
  local direct = C.octant(f.hq_pos.x - pos.x, f.hq_pos.y - pos.y)
  local o = A.pick_side(sides, direct, A.penalized(v.model, key), draw_of(v))
  local mx = 0
  for k = 0, 7 do if sides[k] > mx then mx = sides[k] end end
  local d = C.DIRS[o]
  return { target = { x = pos.x, y = pos.y }, approach = { x = pos.x + d[1] * A.SIDE_RADIUS, y = pos.y + d[2] * A.SIDE_RADIUS },
    octant = o, launch_def = defense, side_def = sides[o], side_max = mx, key = key, direct = direct }
end

---------------------------------------------------------------------------------------------------
-- Modèle du joueur (style)
---------------------------------------------------------------------------------------------------
function Vision.update_model(f, tick)
  local v = Vision.state(f)
  local m = v.model
  if tick < (m.next_snap or 0) then return end
  m.next_snap = tick + 3600
  local list, turrets = Vision.known_list(f)
  local spread = 0
  for i = 1, #list do
    for j = i + 1, #list do
      local dx, dy = list[i].x - list[j].x, list[i].y - list[j].y
      local d = math.floor(math.sqrt(dx * dx + dy * dy))
      if d > spread then spread = d end
    end
  end
  A.snap(m, { tick = tick, units = #list, turrets = #turrets, spread = spread })
  local o = { units = #list, turrets = #turrets, growth = A.growth(m, tick), spread = spread,
    hits = A.recent(m.hits, tick), repulsed = m.repulsed or 0 }
  local style = A.classify(o)
  if style ~= m.style then
    log(string.format("[FO-PVP] modele tick %d %s : style %s (avant %s) : secteurs vus %d, tourelles vues %d, croissance %d, etendue %d, coups recus %d, attaques repoussees %d",
      tick, f.key, style, m.style or "-", o.units, o.turrets, o.growth, o.spread, o.hits, o.repulsed))
    m.style = style
    m.changes = (m.changes or 0) + 1
  end
end

---------------------------------------------------------------------------------------------------
-- Éclaireurs
---------------------------------------------------------------------------------------------------
--- Destination de la prochaine sonde : cible connue (rafraîchir), sinon point de départ du joueur, puis anneaux.
local function probe(f, p, v, spawn)
  local t = f.pvp.target
  if t then return { x = t.pos.x, y = t.pos.y }, "cible" end
  -- Secteurs connus sans cible encore choisie (avant la déclaration) : le plus proche de notre QG.
  local best, bd
  for _, k in ipairs(State.sorted_keys(v.known)) do
    local s = v.known[k]
    local dx, dy = s.x - f.hq_pos.x, s.y - f.hq_pos.y
    if not bd or dx * dx + dy * dy < bd then best, bd = s, dx * dx + dy * dy end
  end
  if best then return { x = best.x, y = best.y }, "connu" end
  local i = v.scout_i % (1 + 8 * #RING)
  if i == 0 then return { x = spawn.x, y = spawn.y }, "depart" end
  local ring = RING[math.floor((i - 1) / 8) + 1]
  -- Octants dans l'ordre, en partant de celui de notre QG vu du départ du joueur (le plus proche d'abord).
  local first = C.octant(f.hq_pos.x - spawn.x, f.hq_pos.y - spawn.y)
  if first < 0 then first = 0 end
  local o = (first + (i - 1) % 8) % 8
  local d = C.DIRS[o]
  return { x = spawn.x + d[1] * ring, y = spawn.y + d[2] * ring }, "anneau" .. ring
end

--- Politique d'éclairage (pensée du commandant, niveaux agressifs) : avant la fin de la grâce (SCOUT_LEAD), puis
--- quand ce que la faction sait date (A.STALE) ou qu'elle ne sait rien ; un éclaireur au plus toutes les SCOUT_GAP.
function Vision.scout_policy(f, surface, p, fp, tick, grace_end)
  local v = Vision.state(f)
  if tick < (v.next_scout or 0) or f.scout_pending then return end
  for _, gid in ipairs(State.sorted_keys(f.groups or {})) do
    if f.groups[gid].state == "scout" then return end
  end
  -- Ce que la faction sait date-t-il ? (rien de connu, ou le regard le plus récent sur un secteur connu a A.STALE.)
  -- Moteur réel (essai 1 du lot) : avant la déclaration, un éclaireur partait toutes les 5 min même quand le joueur
  -- venait d'être vu.
  local keys = State.sorted_keys(v.known)
  local fresh = -1e9
  for _, k in ipairs(keys) do
    local t = v.looked[k] or -1e9
    if t > fresh then fresh = t end
  end
  local stale = #keys == 0 or tick - fresh >= A.STALE
  local window = fp.declared or fp.provoked or (grace_end ~= nil and tick >= grace_end - A.SCOUT_LEAD)
  if not (stale and window) then return end
  local spawn = game.forces.player.get_spawn_position(surface)
  local dest, tag = probe(f, p, v, spawn)
  -- Moteur réel (essai 2 du lot, graine 123456789) : 4 éclaireurs seuls tués en route sur 5 (biters, 25 à 35 s après
  -- le départ) ; après chaque perte, une PATROUILLE plus grosse (1, 3, 5, puis 7 soldats) qui riposte.
  local size = math.min(1 + 2 * (v.scout_losses or 0), 7)
  if Military.scout(f, surface, dest, tick, tag, size) then
    v.next_scout = tick + A.SCOUT_GAP
    log(string.format("[FO-PVP] eclaireur tick %d %s : part vers (%d, %d) (%s), secteurs connus %d, %d soldat(s)", tick, f.key,
      math.floor(dest.x), math.floor(dest.y), tag, #keys, size))
  else
    v.next_scout = tick + 600
  end
end

Military.on_scout_lost = function(f, g, tick, alive)
  local v = f.pvp and Vision.state(f)
  if not v then return end
  if alive < (g.size or 1) then v.scout_losses = math.min((v.scout_losses or 0) + 1, 3) end
end

Military.on_scout_done = function(f, g, tick, arrived)
  local v = f.pvp and Vision.state(f)
  if not v then return end
  local at = g.dest
  if g.group and g.group.valid and not arrived then at = g.group.position end
  local keys = {}
  if at and not g.nopath then keys = A.visible({ { x = at.x, y = at.y, r = A.VISION.scout } }) end
  for _, k in ipairs(keys) do v.reports[#v.reports + 1] = k end
  -- Sonde suivante (départ du joueur, puis anneaux) seulement quand celle-ci a été faite (ou est injoignable) ; un
  -- éclaireur perdu en route (biters, F174) refait la même sonde.
  if (arrived or g.nopath) and (g.tag == "depart" or (g.tag or ""):find("^anneau")) then v.scout_i = v.scout_i + 1 end
  if arrived and (v.scout_losses or 0) > 0 then v.scout_losses = v.scout_losses - 1 end
  log(string.format("[FO-PVP] eclaireur tick %d %s : %s (%d, %d), %d secteurs a regarder", tick, f.key,
    g.nopath and "sans itineraire" or (arrived and "arrive" or "arrete"), math.floor(at and at.x or 0), math.floor(at and at.y or 0), #keys))
end

---------------------------------------------------------------------------------------------------
-- Rassemblement (go / no-go) et issue des attaques contre le joueur
---------------------------------------------------------------------------------------------------
local function rally_player(f, g, tick)
  local v = Vision.state(f)
  local war = State.war()
  local surface = game.surfaces[war.surface]
  local level = war.pvp and war.pvp.difficulty or "normal"
  local tl = surface.find_entities_filtered({ position = g.target, radius = R.defense_radius, force = "player", type = Vision.TURRET_TYPES, limit = 64 })
  local seen = R.defense_per_turret * #tl + (g.key and v.model.learned[g.key] or 0)
  local n = #g.group.members
  local force = n * S.soldier_strength(F.best_soldier(f.tech or 0), f.tech or 0, f.upgrades or 0)
  local ratio = S.player_ratio(level, Character.of(f))
  local go = A.go(force, ratio, g.launch_def or 0, seen)
  g.seen_def = seen
  if not go then f.stats.renonce_joueur = (f.stats.renonce_joueur or 0) + 1 end
  if g.key then v.reports[#v.reports + 1] = g.key end
  log(string.format("[FO-PVP] rassemblement tick %d %s -> joueur : %s, defense vue %d (depart %d), force %d, %d soldats, octant %s",
    tick, f.key, go and "go" or "renonce", seen, math.floor(g.launch_def or 0), math.floor(force), n, tostring(g.octant)))
  return go
end

Military.on_player_attack_ended = function(f, g, survivors, tick, alive)
  local v = f.pvp and Vision.state(f)
  if not v or not g.target then return end
  local surface = game.surfaces[State.war().surface]
  local standing = surface.count_entities_filtered({ position = g.target, radius = 16, force = "player", type = Vision.INSTALL_TYPES, limit = 1 }) > 0
  -- Moteur réel (essai 1 du lot) : l'attaque de zone s'arrête quand il ne reste plus de cible MILITAIRE (tourelles) ;
  -- les machines restent debout. Une attaque qui a fait tomber les tourelles autour du point visé a réussi.
  local turrets = surface.count_entities_filtered({ position = g.target, radius = R.defense_radius, force = "player", type = Vision.TURRET_TYPES, limit = 1 })
  local size = g.size or 0
  local outcome
  if g.renonce then
    outcome = "renonce"
  elseif alive and size > 0 and survivors * 2 < size and alive * 2 >= size then
    outcome = "dissous" -- la plupart des soldats ont quitté le groupe vivants (F174) : sans leçon
  elseif not standing or turrets == 0 then
    outcome = "reussie"
  elseif survivors > 0 then
    outcome = "repoussee"
  else
    outcome = "aneantie"
  end
  A.record_outcome(v.model, g.gid, outcome, g.size, survivors, g.seen_def)
  if g.key then v.reports[#v.reports + 1] = g.key end
  log(string.format("[FO-PVP] issue tick %d %s -> joueur : %s, %d envoyes, %d survivants, octant %s, vivants %s",
    tick, f.key, outcome, g.size or 0, survivors, tostring(g.octant or "-"), alive and tostring(alive) or "-"))
end

--- Crochet du rassemblement : joueur (modèle ci-dessus) ou rivale (chef, Vision.rally_rival branché par chef.lua).
Vision.rally_rival = nil
Military.on_rally = function(f, g, tick)
  if g.target_faction == "player" then return rally_player(f, g, tick) end
  if Vision.rally_rival then return Vision.rally_rival(f, g, tick) end
  return true
end

---------------------------------------------------------------------------------------------------
-- Coups reçus du joueur (style « agresseur ») : bâtiments d'une faction détruits par la force du joueur.
---------------------------------------------------------------------------------------------------
Events.on(defines.events.on_entity_died, function(e)
  local killer = e.force
  -- Éclaireur tué : par qui (journal ; moteur réel, essai 2 : 4 éclaireurs seuls sur 5 tués en route).
  local ent0 = e.entity
  if ent0 and ent0.valid and ent0.type == "unit" and ent0.unit_number then
    local fs = State.by_force(ent0.force.name)
    local s = fs and fs.soldiers and fs.soldiers[ent0.unit_number]
    local g = s and s.group and fs.groups[s.group]
    if g and g.state == "scout" then
      local p = ent0.position
      log(string.format("[FO-PVP] eclaireur tick %d %s : soldat tue par %s en (%d, %d)", e.tick, fs.key,
        killer and killer.name or "aucune", math.floor(p.x), math.floor(p.y)))
    end
  end
  if not killer or killer.name ~= "player" then return end
  local ent = e.entity
  if not (ent and ent.valid) or ent.type == "unit" or ent.type == "character" then return end
  local war = State.war()
  if not (war.active and war.pvp) then return end
  local f = State.by_force(ent.force.name)
  if not (f and f.pvp) then return end
  local m = Vision.state(f).model
  m.hits[#m.hits + 1] = e.tick
  while #m.hits > 16 do table.remove(m.hits, 1) end
end)

return Vision
