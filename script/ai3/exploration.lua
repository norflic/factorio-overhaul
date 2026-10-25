--[[
  IA3 « le cerveau des PNJ », lot IA3-f : EXPLORATION SOUS BROUILLARD (exécution ; règles pures dans
  shared/ai3/carte.lua). Conception : docs/IA3_CERVEAU.md §4.1, §4.6, §6.2 ; revue M3. Demande du DC (R-QCM-25g) : les
  PNJ « se débrouillent pour chercher du pétrole, comme les joueurs » ; constat du DC du 25/10 vers 18 h 45 (OBJECTIFS
  §5) : votre équipe « n'explore pas et ne regarde même pas autour d'elle » quand le fer manque.

  Chaque équipe (factions ET votre équipe) a une CARTE DE CONNAISSANCE (f.ai3f.m) faite de ses seuls regards :
    - YEUX : QG (160 tuiles), avant-postes (128), groupes de soldats (96, éclaireurs d'IA2-c 128), éclaireur d'IA3-f
      (128) et CHACUN de ses PNJ en marche (48), regardé tous les 64 tuiles parcourues (revue M3) ;
    - REGARDER un secteur de 64 × 64 = quelques comptages du moteur (ressources par nom, centre par quart, nids et vers,
      eau), 1 regard toutes les 8 ticks POUR TOUT LE MOD (voie « fo-ai3-look »), les équipes à tour de rôle ; un secteur
      non généré est demandé au moteur (`request_to_generate_chunks`, comme la présence d'un joueur) et regardé plus
      tard. Identique avec et sans images : jamais `is_chunk_charted` (F131).
  Ce que la carte change :
    - la prospection des avant-postes (script/faction/sites.lua) ne cherche plus que dans les secteurs VUS (crochet
      Sites.seen_filter) ; un gisement d'une ressource demandée, vu par un œil, est évalué tout de suite (Sites.probe_at) ;
    - le minage d'appoint d'une ressource sans tuile à 96 tuiles du coffre va au gisement CONNU et sûr le plus proche
      (crochet Worker.far_mine, au plus FAR_MINE tuiles) ;
    - TOUR DU PROPRIÉTAIRE à la fondation : un PNJ libre fait l'anneau de 150 tuiles autour du QG ;
    - EXPLORATION : une ressource DEMANDÉE (étape `explore` du cerveau : X.request ; ou besoin de site sans site, ou
      minage impossible faute de gisement connu) envoie un PNJ libre vers le secteur non vu de meilleure note
      (K.best_target) ; il rentre quand il a trouvé, quand il voit un ennemi à moins de 40 tuiles (il fuit et note le
      danger), ou au bout de 10 min. Un PNJ ouvrier (il sait marcher, fuir, revenir), jamais un soldat seul (F235).
  Le PNJ éclaireur est piloté SANS toucher à script/team/worker.lua : sa tâche est posée sur l'agent (kind « explore »,
  champ ai3f), son programme n'a que des étapes existantes (goto, wait, home) ; la voie le surveille et réécrit ses
  étapes (FSM.set de sa machine).

  Interface lue par le cerveau (nouveau ou ancien) : X.seen, X.known_sectors, X.deposits (avec risque d'expédition,
  E.risk), X.request, X.status, X.cancel, X.knowledge.
  Bascule (bancs avant / après sur la même source) : interface distante « fo-ia3f », set_fog(false) = comportement
  d'avant le lot (prospection sans brouillard, aucune exploration, aucun regard).

  État (nombres, chaînes, tables) : f.ai3f = { m, q, qi, inq, gen, born, fixed_at, fixed_n, tour, req, done, ex,
  next_mission, next_check, probed, audit, stats } ; global.fo.ai3f = { fog, lc, tc, seq, stats }.
  Journal : « [FO-IA3F] ».
]]

local Events = require("script.core.events")
local Scheduler = require("script.core.scheduler")
local Storage = require("script.core.storage")
local Profiler = require("script.core.profiler")
local FSM = require("script.core.fsm")
local K = require("shared.ai3.carte")
local A = require("shared.faction.adversaire")
local State = require("script.faction.state")
local Registry = require("script.companion.registry")
local Sites = require("script.faction.sites")
local Worker = require("script.team.worker")
local Poles = require("script.team.poles")

local X = {}

X.LOOK_LANE = "fo-ai3-look"
X.EYE_LANE = "fo-ai3-eyes"
local LOOK_PERIOD = 8          -- 1 regard toutes les 8 ticks pour tout le mod (comme la voie de repérage d'IA2-c)
local EYE_PERIOD = 15          -- éclaireurs surveillés à chaque passe ; une équipe par passe pour le reste
local QUEUE_MAX = 96
local SKIP_PER_PASS = 6        -- clés sautées sans appel moteur par passe (déjà vues, génération en attente)
local GEN_GIVEUP = 3600        -- secteur jamais généré après 1 min : oublié (il reviendra par un œil)
local RECENT = 600             -- un secteur regardé il y a moins de 10 s n'est pas regardé de nouveau
local FIXED_REFRESH = 5 * 3600
local CHECK_PERIOD = 1800      -- demandes automatiques : toutes les 30 s par équipe
local FLEE_RADIUS = 40         -- §4.1 : il fuit s'il voit un ennemi à moins de 40 tuiles
local ENEMY_PERIOD = 30
local MISSION_MAX = 10 * 3600  -- §4.1 : il rentre au bout de 10 min
local TOUR_RADIUS = 150        -- §4.1 : anneau de 150 tuiles autour du QG
local TOUR_DEADLINE = 15 * 3600 -- tour du propriétaire : seulement dans les 15 premières minutes de l'équipe
local COOLDOWN = 600
local COOLDOWN_FLEE = 3600
local WAYPOINT = 96            -- point de passage à au plus 96 tuiles de l'éclaireur (zone générée autour de lui)
local RETARGET = 120
local GEN_RADIUS = 4           -- chunks générés autour d'un éclaireur (128 tuiles : son œil)
local FAR_MINE = 256           -- minage d'appoint au plus à 256 tuiles du coffre (constat du DC : fer à environ 140)
local MINE_REQ_TTL = 10 * 3600 -- une demande « minage » non renouvelée expire après 10 min
local EXHAUSTED_RETRY = 10 * 3600
local PROBE_RETRY = 5 * 3600
local MIN_TEAM = 2             -- jamais d'éclaireur dans une équipe de moins de 2 PNJ

Storage.declare("ai3f", function()
  return { fog = true, lc = 0, tc = 0, seq = 0, stats = { looks = 0, skipped = 0, gen = 0, res_looks = 0 } }
end)

local function G() return Storage.ns("ai3f") end

function X.fog_on()
  local g = G()
  return g ~= nil and g.fog == true
end

---------------------------------------------------------------------------------------------------
-- Équipes
---------------------------------------------------------------------------------------------------
local function teams()
  local list = {}
  local war = State.war()
  if war.active then
    for _, id in ipairs(State.alive()) do
      local f = war.factions[id]
      if f and f.hq_pos and f.team and f.hq and f.hq.valid then list[#list + 1] = f end
    end
  end
  local p = State.faction("player")
  if p and p.hq and p.hq.valid and p.team then list[#list + 1] = p end
  return list
end

local function surface_of(f)
  if f.hq and f.hq.valid then return f.hq.surface end
  return nil
end

local function spawn_of(surface)
  local s = game.forces.player.get_spawn_position(surface)
  return { x = s.x, y = s.y }
end

--- Positions à éviter pour l'éclaireur : QG des autres factions (connus, comme dans IA2) ; pour une faction, le point
--- de départ du joueur (sa base).
local function rivals(f, surface)
  local out = {}
  for _, id in ipairs(State.alive()) do
    local r = State.faction(id)
    if r and r ~= f and r.hq_pos then out[#out + 1] = { x = r.hq_pos.x, y = r.hq_pos.y } end
  end
  if not f.is_player then out[#out + 1] = spawn_of(surface) end
  return out
end

local function dist2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

---------------------------------------------------------------------------------------------------
-- File des regards
---------------------------------------------------------------------------------------------------
local function push(k, key, tick, relook)
  if k.inq[key] or (#k.q - k.qi + 1) >= QUEUE_MAX then return false end
  if relook and not K.due(k.m, key, tick, relook) then return false end
  k.q[#k.q + 1] = key
  k.inq[key] = true
  return true
end

local function pop(k)
  if k.qi > #k.q then
    if #k.q > 0 then k.q, k.qi = {}, 1 end
    return nil
  end
  local key = k.q[k.qi]
  k.qi = k.qi + 1
  k.inq[key] = nil
  if k.qi > 64 and k.qi > #k.q / 2 then
    local rest = {}
    for i = k.qi, #k.q do rest[#rest + 1] = k.q[i] end
    k.q, k.qi = rest, 1
  end
  return key
end

local function eye_keys(x, y, r) return A.visible({ { x = x, y = y, r = r } }) end

local function push_eye(k, x, y, r, tick, relook)
  for _, key in ipairs(eye_keys(x, y, r)) do push(k, key, tick, relook) end
end

local function generated(surface, key)
  local sx, sy = K.xy(key)
  local cx, cy = sx * 2, sy * 2
  return surface.is_chunk_generated({ x = cx, y = cy }) and surface.is_chunk_generated({ x = cx + 1, y = cy })
    and surface.is_chunk_generated({ x = cx, y = cy + 1 }) and surface.is_chunk_generated({ x = cx + 1, y = cy + 1 })
end

-- Noms des ressources du jeu (cache LOCAL tiré des PROTOTYPES : identique chez tous les pairs, trié ; jamais dans global).
local resource_names = nil
local function names_of_resources()
  if not resource_names then
    local list = {}
    for name in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "resource" } })) do
      list[#list + 1] = name
    end
    table.sort(list)
    resource_names = list
  end
  return resource_names
end

local ENEMY_TYPES = { "unit-spawner", "turret" }

--- REGARDER un secteur : comptages du moteur, rien d'autre. Renvoie les ressources nouvelles du secteur.
local function look(k, surface, key, tick)
  local g = G()
  local sx, sy = K.xy(key)
  local x0, y0 = sx * K.SECTOR, sy * K.SECTOR
  local area = { { x0, y0 }, { x0 + K.SECTOR, y0 + K.SECTOR } }
  local obs = { res = {}, nests = {}, worms = {} }
  if surface.count_entities_filtered({ area = area, type = "resource", limit = 1 }) > 0 then
    g.stats.res_looks = g.stats.res_looks + 1
    local rest = {}
    for _, n in ipairs(names_of_resources()) do rest[#rest + 1] = n end
    while #rest > 0 do
      local e = surface.find_entities_filtered({ area = area, name = rest, limit = 1 })[1]
      if not e then break end
      local name = e.name
      local nxt = {}
      for _, n in ipairs(rest) do if n ~= name then nxt[#nxt + 1] = n end end
      rest = nxt
      -- Centre et taille : un comptage par quart de secteur (un chunk), quantité estimée sur 8 tuiles du quart le plus
      -- fourni.
      local n, wx, wy, best_q, best_n = 0, 0, 0, nil, 0
      for qy = 0, 1 do
        for qx = 0, 1 do
          local qx0, qy0 = x0 + qx * 32, y0 + qy * 32
          local qa = { { qx0, qy0 }, { qx0 + 32, qy0 + 32 } }
          local c = surface.count_entities_filtered({ area = qa, name = name })
          n = n + c
          wx, wy = wx + c * (qx0 + 16), wy + c * (qy0 + 16)
          if c > best_n then best_n, best_q = c, qa end
        end
      end
      if n > 0 then
        local sample = surface.find_entities_filtered({ area = best_q, name = name, limit = 8 })
        local sum = 0
        for _, r in ipairs(sample) do sum = sum + (r.amount or 0) end
        local a = #sample > 0 and math.floor(sum / #sample * n) or 0
        obs.res[#obs.res + 1] = { name = name, n = n, a = a, x = wx / n, y = wy / n }
      end
    end
  end
  if surface.count_entities_filtered({ area = area, force = "enemy", type = ENEMY_TYPES, limit = 1 }) > 0 then
    for _, e in ipairs(surface.find_entities_filtered({ area = area, force = "enemy", type = ENEMY_TYPES, limit = 24 })) do
      local p = { x = e.position.x, y = e.position.y }
      if e.type == "unit-spawner" then obs.nests[#obs.nests + 1] = p else obs.worms[#obs.worms + 1] = p end
    end
  end
  obs.water = surface.count_tiles_filtered({ area = area, collision_mask = "water-tile", limit = 1 }) > 0
  g.stats.looks = g.stats.looks + 1
  k.stats.looks = (k.stats.looks or 0) + 1
  return K.record(k.m, key, tick, obs)
end

---------------------------------------------------------------------------------------------------
-- Demandes d'exploration
---------------------------------------------------------------------------------------------------
local function team_label(f) return f.key or tostring(f.id) end

local function minutes(t) return t / 3600 end

local function open_request(f, k, res, tick, why)
  local r = k.req[res]
  if r then
    if why == "minage" then r.renewed = tick end
    return "en cours"
  end
  k.req[res] = { t = tick, why = why, known0 = K.count(k.m, res), renewed = tick }
  log(string.format("[FO-IA3F] %s : exploration demandee pour %s (%s) a %.1f min, gisements connus %d, secteurs vus %d",
    team_label(f), res, why, minutes(tick), k.req[res].known0, k.m.n))
  return "demande"
end

local function close_request(f, k, res, tick, outcome)
  local r = k.req[res]
  if not r then return end
  k.req[res] = nil
  k.done[#k.done + 1] = { res = res, why = r.why, t = r.t, closed = tick, outcome = outcome }
  while #k.done > 16 do table.remove(k.done, 1) end
  if outcome == "trouve" then
    k.stats.found = k.stats.found or {}
    k.stats.found[res] = k.stats.found[res] or (tick - r.t)
  end
  log(string.format("[FO-IA3F] %s : exploration %s : %s apres %.1f min (demandee a %.1f min, %s)", team_label(f), res,
    outcome, minutes(tick - r.t), minutes(r.t), r.why))
end

---------------------------------------------------------------------------------------------------
-- Ce que l'équipe voit de nouveau
---------------------------------------------------------------------------------------------------
local function on_fresh(f, k, surface, key, names, tick)
  for _, res in ipairs(names) do
    if k.m.found[res] == tick then
      local d = K.deposits(k.m, res, f.hq_pos)[1]
      log(string.format("[FO-IA3F] %s : premier gisement de %s vu a %.1f min en (%d, %d), %d tuiles du QG, secteurs vus %d",
        team_label(f), res, minutes(tick), d and d.x or 0, d and d.y or 0, d and math.floor(math.sqrt(d.d2)) or -1, k.m.n))
    end
    local r = k.req[res]
    if r and K.count(k.m, res) > (r.known0 or 0) then close_request(f, k, res, tick, "trouve") end
    -- Une ressource demandée par le cerveau (sites d'avant-poste) : le gisement est évalué tout de suite.
    if (f.site_needs or {})[res] and f.site_needs[res] > 0 and Sites.available(f, res) == 0 then
      for _, s in ipairs(k.m.s[key].r or {}) do
        if s.name == res and Sites.probe_at(f, surface, s.x, s.y, tick) then
          k.stats.injected = (k.stats.injected or 0) + 1
          log(string.format("[FO-IA3F] %s : site de %s retenu en (%d, %d) des qu'il a ete vu", team_label(f), res, s.x, s.y))
        end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Voie des regards
---------------------------------------------------------------------------------------------------
Scheduler.define_lane(X.LOOK_LANE, LOOK_PERIOD, function(_, tick)
  local g = G()
  if not g.fog then return end
  local list = teams()
  if #list == 0 then return end
  local skipped = 0
  for _ = 1, #list do
    g.lc = g.lc % #list + 1
    local f = list[g.lc]
    local k = f.ai3f
    if k and k.qi <= #k.q then
      local surface = surface_of(f)
      while skipped < SKIP_PER_PASS do
        local key = pop(k)
        if not key then break end
        if not K.due(k.m, key, tick, RECENT) then
          skipped = skipped + 1
        elseif generated(surface, key) then
          k.gen[key] = nil
          Profiler.start("ai3f:look")
          local fresh = look(k, surface, key, tick)
          Profiler.stop("ai3f:look")
          if #fresh > 0 then on_fresh(f, k, surface, key, fresh, tick) end
          return
        else
          skipped = skipped + 1
          local since = k.gen[key]
          if not since then
            local cx, cy = K.center(K.xy(key))
            surface.request_to_generate_chunks({ x = cx, y = cy }, 1)
            k.gen[key] = tick
            g.stats.gen = g.stats.gen + 1
            push(k, key)
          elseif tick - since < GEN_GIVEUP then
            push(k, key)
          else
            k.gen[key] = nil
          end
        end
      end
      g.stats.skipped = g.stats.skipped + skipped
      if skipped >= SKIP_PER_PASS then return end
    end
  end
end)

---------------------------------------------------------------------------------------------------
-- Éclaireur : mission, surveillance
---------------------------------------------------------------------------------------------------
local function set_steps(a, steps, tick)
  a.steps, a.pc, a.failed = steps, 1, nil
  FSM.set(a.machine, a, "step", tick)
end

local function go_home(a, ex, why, tick)
  ex.state, ex.why = "home", why
  set_steps(a, { { "home" } }, tick)
end

local function pick_idle(f)
  if (f.engineers_count or 0) < MIN_TEAM then return nil end
  for _, id in ipairs(sorted_keys(f.engineers or {})) do
    local a = Registry.get(id)
    if a and a.entity and a.entity.valid and a.task == nil and a.state == "idle" and not a.nav and a.machine then
      return a
    end
  end
  return nil
end

local function chunk_ready(surface, p)
  return surface.is_chunk_generated({ x = math.floor(p.x / 32), y = math.floor(p.y / 32) })
end

local function start_mission(f, k, a, kind, res, tick)
  local g = G()
  g.seq = g.seq + 1
  local surface = a.entity.surface
  local ex = { tag = g.seq, agent = a.id, kind = kind, res = res, started = tick, state = "out", bad = {} }
  a.task = { kind = "explore", key = "ai3f:" .. kind .. ":" .. g.seq, ai3f = g.seq, claimed = tick, res = res }
  a.ai3f_eye = K.EYE.explorer
  local steps
  if kind == "tour" then
    local first = type(f.id) == "number" and (f.id % 8) or 0
    local ring = K.ring(f.hq_pos.x, f.hq_pos.y, TOUR_RADIUS, first)
    steps = {}
    local wait = false
    for i = k.tour.next, #ring do
      local p = ring[i]
      if K.sector_risk(k.m, K.key_of(p.x, p.y), tick, rivals(f, surface)) < K.DANGER.skip then
        if not chunk_ready(surface, p) then
          surface.request_to_generate_chunks(p, 1)
          wait = true
        end
        steps[#steps + 1] = { "goto", p, 6 }
      end
    end
    if wait then table.insert(steps, 1, { "wait", 120 }) end
    ex.ring_first = k.tour.next
    steps[#steps + 1] = { "home" }
  else
    ex.known0 = K.count(k.m, res)
    steps = { { "wait", 120 }, { "home" } } -- la cible est choisie à la première surveillance (au plus 15 ticks)
    ex.next_target = tick
  end
  k.ex = ex
  k.stats.missions = (k.stats.missions or 0) + 1
  set_steps(a, steps, tick)
  log(string.format("[FO-IA3F] %s : eclaireur %d part (%s%s) a %.1f min, secteurs vus %d", team_label(f), a.id, kind,
    res and (" " .. res) or "", minutes(tick), k.m.n))
end

local function end_mission(f, k, tick, why)
  local ex = k.ex
  k.ex = nil
  local a = Registry.get(ex.agent)
  if a then a.ai3f_eye = nil end
  k.next_mission = tick + ((why == "fuite" or why == "perdu") and COOLDOWN_FLEE or COOLDOWN)
  if ex.kind == "tour" then
    k.tour.tries = (k.tour.tries or 0) + 1
    if why == "fini" or why == "duree" or k.tour.tries >= 3 then
      k.tour.state = "done"
      k.tour.done_at = tick
    end
  end
  log(string.format("[FO-IA3F] %s : eclaireur %d (%s%s) fin : %s apres %.1f min, secteurs vus %d", team_label(f), ex.agent,
    ex.kind, ex.res and (" " .. ex.res) or "", why, minutes(tick - ex.started), k.m.n))
end

local function retarget(f, k, a, ex, tick)
  local e = a.entity
  local surface = e.surface
  local me = { x = e.position.x, y = e.position.y }
  local key = K.best_target(k.m, { hq = f.hq_pos, me = me, tick = tick, res = ex.res, spawn = spawn_of(surface),
    rivals = rivals(f, surface), exclude = ex.bad })
  if not key then
    local r = ex.res and k.req[ex.res]
    if r then r.exhausted = tick end
    go_home(a, ex, "rien", tick)
    return
  end
  ex.target = key
  local cx, cy = K.center(K.xy(key))
  local wp = K.toward(me, { x = cx, y = cy }, WAYPOINT)
  local steps = { { "goto", wp, 6 }, { "wait", 600 }, { "home" } }
  if not chunk_ready(surface, wp) then
    surface.request_to_generate_chunks(wp, 2)
    table.insert(steps, 1, { "wait", 90 })
  end
  ex.next_target = tick + RETARGET
  ex.retargets = (ex.retargets or 0) + 1
  set_steps(a, steps, tick)
end

local function flee(f, k, a, ex, enemy, tick)
  local p = enemy.position
  K.mark(k.m, p.x, p.y, tick, 500)
  push(k, K.key_of(p.x, p.y))
  k.stats.flees = (k.stats.flees or 0) + 1
  if ex.kind == "tour" then k.tour.next = math.min(9, ex.ring_first + math.max(0, (a.pc or 1) - 1) + 1) end
  local e = a.entity
  log(string.format("[FO-IA3F] %s : eclaireur %d fuit (%s %s a %d tuiles) en (%d, %d) a %.1f min", team_label(f), a.id,
    enemy.type, enemy.name, math.floor(math.sqrt(dist2(p, e.position))), math.floor(e.position.x), math.floor(e.position.y),
    minutes(tick)))
  go_home(a, ex, "fuite", tick)
end

local function monitor(f, k, tick)
  local ex = k.ex
  local a = Registry.get(ex.agent)
  if not (a and a.entity and a.entity.valid) then
    end_mission(f, k, tick, "perdu")
    return
  end
  local t = a.task
  if not (t and t.ai3f == ex.tag) then
    end_mission(f, k, tick, ex.state == "home" and ex.why or "fini")
    return
  end
  if t.fail then -- chemin raté : le PNJ rentre de lui-même (étape home)
    if ex.target then ex.bad[ex.target] = true end
    if ex.state ~= "home" then ex.state, ex.why = "home", "chemin" end
    return
  end
  if ex.state == "home" then return end
  if tick >= (ex.next_enemy or 0) then
    ex.next_enemy = tick + ENEMY_PERIOD
    local e = a.entity
    local enemy = e.surface.find_nearest_enemy({ position = e.position, max_distance = FLEE_RADIUS, force = e.force })
    if enemy then
      flee(f, k, a, ex, enemy, tick)
      return
    end
  end
  if tick - ex.started >= MISSION_MAX then
    go_home(a, ex, "duree", tick)
    return
  end
  if ex.kind == "explore" then
    if K.count(k.m, ex.res) > (ex.known0 or 0) then
      go_home(a, ex, "trouve", tick)
      return
    end
    -- Nouvelle cible : la précédente est vue, ou le point de passage est atteint (étape « wait » après le goto).
    local step = a.steps and a.steps[a.pc]
    local arrived = step and step[1] == "wait" and (step[2] or 0) >= 600
    if tick >= (ex.next_target or 0) and (not ex.target or K.seen(k.m, ex.target) or arrived) then
      retarget(f, k, a, ex, tick)
    elseif step and step[1] == "home" and ex.state ~= "home" then
      retarget(f, k, a, ex, tick) -- ne jamais rentrer avant la fin de la mission
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Une équipe : fondation, yeux, demandes automatiques, missions, contrôle des sites
---------------------------------------------------------------------------------------------------
local function init(f, surface, tick)
  local war = State.war()
  local k = {
    m = K.new(), q = {}, qi = 1, inq = {}, gen = {}, born = f.started or war.started or tick, fixed_at = -1e9, fixed_n = -1,
    tour = { state = "todo", next = 1 }, req = {}, done = {}, ex = nil, next_mission = tick + 60, next_check = tick,
    probed = {}, audit = { outposts = {}, ok = 0, bad = {} }, stats = { looks = 0 },
  }
  f.ai3f = k
  -- Premier coup d'œil : le secteur du QG et ses 8 voisins, tout de suite (les gisements de départ y sont).
  local sx, sy = A.sector_of(f.hq_pos.x, f.hq_pos.y)
  for dy = -1, 1 do
    for dx = -1, 1 do
      local key = K.key(sx + dx, sy + dy)
      if generated(surface, key) then
        local fresh = look(k, surface, key, tick)
        if #fresh > 0 then on_fresh(f, k, surface, key, fresh, tick) end
      else
        push(k, key)
      end
    end
  end
  if tick - k.born > TOUR_DEADLINE then k.tour.state = "skip" end
  log(string.format("[FO-IA3F] %s : carte de connaissance ouverte a %.1f min, %d secteurs vus au premier coup d'oeil",
    team_label(f), minutes(tick), k.m.n))
  return k
end

local function fixed_eyes(f, k, tick)
  local n = f.outposts_count or 0
  if tick - k.fixed_at < FIXED_REFRESH and n == k.fixed_n then return end
  k.fixed_at, k.fixed_n = tick, n
  push_eye(k, f.hq_pos.x, f.hq_pos.y, K.EYE.hq, tick, K.RELOOK.fixed)
  for _, oid in ipairs(sorted_keys(f.outposts or {})) do
    local p = f.outposts[oid].pos
    push_eye(k, p.x, p.y, K.EYE.outpost, tick, K.RELOOK.fixed)
  end
end

local function moving_eyes(f, k, surface, tick)
  for _, gid in ipairs(sorted_keys(f.groups or {})) do
    local gr = f.groups[gid]
    if gr.group and gr.group.valid then
      local p = gr.group.position
      if not gr.k_x or (p.x - gr.k_x) ^ 2 + (p.y - gr.k_y) ^ 2 >= K.STEP * K.STEP then
        gr.k_x, gr.k_y = p.x, p.y
        push_eye(k, p.x, p.y, gr.state == "scout" and K.EYE.scout or K.EYE.group, tick, K.RELOOK.moving)
      end
    end
  end
  for _, id in ipairs(sorted_keys(f.engineers or {})) do
    local a = Registry.get(id)
    if a and a.entity and a.entity.valid then
      local p = a.entity.position
      if not a.k_x then
        a.k_x, a.k_y = p.x, p.y
      elseif (p.x - a.k_x) ^ 2 + (p.y - a.k_y) ^ 2 >= K.STEP * K.STEP then
        a.k_x, a.k_y = p.x, p.y
        local r = a.ai3f_eye or K.EYE.walker
        push_eye(k, p.x, p.y, r, tick, K.RELOOK.moving)
        -- Un éclaireur fait générer la carte autour de lui, comme la présence d'un joueur.
        if a.ai3f_eye then surface.request_to_generate_chunks(p, GEN_RADIUS) end
      end
    end
  end
end

--- Gisements connus d'une ressource soumis à la prospection (au plus 3 par contrôle, chacun au plus toutes les 5 min).
local function inject_known(f, k, surface, res, tick)
  local n = 0
  for _, d in ipairs(K.deposits(k.m, res, f.hq_pos)) do
    if n >= 3 then break end
    local last = k.probed[d.key]
    if not last or tick - last >= PROBE_RETRY then
      k.probed[d.key] = tick
      n = n + 1
      if Sites.probe_at(f, surface, d.x, d.y, tick) then
        k.stats.injected = (k.stats.injected or 0) + 1
        return true
      end
    end
  end
  return false
end

local function auto_requests(f, k, surface, tick)
  -- Besoin de site sans site en réserve : d'abord les gisements CONNUS, sinon explorer.
  local needs = f.site_needs or {}
  for _, res in ipairs(sorted_keys(needs)) do
    if (needs[res] or 0) > 0 and Sites.available(f, res) == 0 then
      if not inject_known(f, k, surface, res, tick) then open_request(f, k, res, tick, "site") end
    end
  end
  -- Fermetures : besoin satisfait, demande de minage non renouvelée.
  for _, res in ipairs(sorted_keys(k.req)) do
    local r = k.req[res]
    if r.why == "site" and ((needs[res] or 0) == 0 or Sites.available(f, res) > 0) then
      close_request(f, k, res, tick, "satisfait")
    elseif r.why == "minage" and tick - (r.renewed or r.t) >= MINE_REQ_TTL then
      close_request(f, k, res, tick, "expiree")
    end
  end
end

local function next_request(k, tick)
  local best, bt
  for _, res in ipairs(sorted_keys(k.req)) do
    local r = k.req[res]
    if not (r.exhausted and tick - r.exhausted < EXHAUSTED_RETRY) and (not bt or r.t < bt) then best, bt = res, r.t end
  end
  return best
end

local function audit(f, k, tick)
  for _, oid in ipairs(sorted_keys(f.outposts or {})) do
    if not k.audit.outposts[oid] then
      k.audit.outposts[oid] = true
      local p = f.outposts[oid].pos
      if K.seen_xy(k.m, p.x, p.y) then
        k.audit.ok = k.audit.ok + 1
      else
        k.audit.bad[#k.audit.bad + 1] = { oid = oid, x = math.floor(p.x), y = math.floor(p.y), t = tick }
        log(string.format("[FO-IA3F] %s : AVANT-POSTE %d dans un secteur JAMAIS VU en (%d, %d) a %.1f min", team_label(f), oid,
          math.floor(p.x), math.floor(p.y), minutes(tick)))
      end
    end
  end
end

local function team_pass(f, tick)
  local surface = surface_of(f)
  if not surface then return end
  local k = f.ai3f or init(f, surface, tick)
  fixed_eyes(f, k, tick)
  moving_eyes(f, k, surface, tick)
  audit(f, k, tick)
  if tick >= k.next_check then
    k.next_check = tick + CHECK_PERIOD
    auto_requests(f, k, surface, tick)
  end
  if k.ex or tick < k.next_mission then return end
  local kind, res
  if k.tour.state == "todo" then
    if tick - k.born > TOUR_DEADLINE then k.tour.state = "skip" else kind = "tour" end
  end
  if not kind then
    res = next_request(k, tick)
    if res then kind = "explore" end
  end
  if not kind then return end
  local a = pick_idle(f)
  if a then start_mission(f, k, a, kind, res, tick) end
end

Scheduler.define_lane(X.EYE_LANE, EYE_PERIOD, function(_, tick)
  local g = G()
  if not g.fog then return end
  local list = teams()
  if #list == 0 then return end
  Profiler.start("ai3f:eyes")
  for _, f in ipairs(list) do
    if f.ai3f and f.ai3f.ex then monitor(f, f.ai3f, tick) end
  end
  g.tc = g.tc % #list + 1
  team_pass(list[g.tc], tick)
  Profiler.stop("ai3f:eyes")
end)

local function ensure_lanes()
  Scheduler.add(X.LOOK_LANE, 1)
  Scheduler.add(X.EYE_LANE, 1)
end
Events.on_init(ensure_lanes)
Events.on_configuration_changed(ensure_lanes)

---------------------------------------------------------------------------------------------------
-- Morts : éclaireur compté, zone marquée (H11)
---------------------------------------------------------------------------------------------------
Registry.on_removed(function(agent)
  if not agent.faction or not agent.death_cause then return end
  local f = State.faction(agent.faction)
  local k = f and f.ai3f
  if not k then return end
  local p = agent.death_pos
  local by_enemy = agent.death_cause:find("/enemy:", 1, true) ~= nil
  local scout = agent.task and agent.task.ai3f ~= nil
  if p and (by_enemy or scout) then K.mark(k.m, p.x, p.y, game.tick, scout and 800 or 300) end
  if scout then
    k.stats.deaths = (k.stats.deaths or 0) + 1
    log(string.format("[FO-IA3F] %s : ECLAIREUR %d TUE (%s) en (%d, %d) a %.1f min", team_label(f), agent.id,
      agent.death_cause, p and math.floor(p.x) or 0, p and math.floor(p.y) or 0, minutes(game.tick)))
  end
end)

---------------------------------------------------------------------------------------------------
-- Crochets dans la prospection et le minage d'appoint
---------------------------------------------------------------------------------------------------
--- Prospection : un chunk n'est examiné que si son secteur a été VU par l'équipe (sans brouillard : toujours).
Sites.seen_filter = function(f, cx, cy)
  local g = G()
  if not (g and g.fog) then return true end
  local k = f.ai3f
  if not k then return false end
  return k.m.s[K.key(math.floor(cx / 2), math.floor(cy / 2))] ~= nil
end

--- Minage d'appoint sans tuile à portée du coffre : tuile libre du gisement CONNU et sûr le plus proche (au plus
--- FAR_MINE tuiles ; aucun nid ni ver vu à 64 tuiles, aucun incident récent, pas de perte récente de votre équipe).
--- Aucun : demande d'exploration de la ressource. Sans brouillard : nil (comportement d'avant le lot).
Worker.far_mine = function(f, task, surface, tick)
  local g = G()
  if not (g and g.fog) then return nil end
  local k = f.ai3f
  if not k then return nil end
  local res = task.resource
  for _, d in ipairs(K.deposits(k.m, res, f.hq_pos)) do
    if d.d2 > FAR_MINE * FAR_MINE then break end
    local nests, worms = K.enemies_near(k.m, d.x, d.y, K.NEAR)
    if nests + worms == 0 and K.marks_near(k.m, d.x, d.y, K.NEAR, tick) == 0
      and not (f.is_player and Poles.near_loss(f, d, tick)) then
      local tiles = surface.find_entities_filtered({ position = { x = d.x, y = d.y }, radius = 24, name = res, limit = 64 })
      table.sort(tiles, function(p, q)
        local dp, dq = dist2(p.position, f.hq_pos), dist2(q.position, f.hq_pos)
        if dp ~= dq then return dp < dq end
        if p.position.x ~= q.position.x then return p.position.x < q.position.x end
        return p.position.y < q.position.y
      end)
      for _, r in ipairs(tiles) do
        local p = r.position
        local busy = surface.count_entities_filtered({ area = { { p.x - 0.5, p.y - 0.5 }, { p.x + 0.5, p.y + 0.5 } },
          type = "resource", invert = true, limit = 1 })
        if busy == 0 then
          k.stats.far_mine = (k.stats.far_mine or 0) + 1
          if (k.stats.far_mine or 0) == 1 then
            log(string.format("[FO-IA3F] %s : minage de %s au gisement connu en (%d, %d), %d tuiles du QG (rien a %d tuiles)",
              team_label(f), res, math.floor(p.x), math.floor(p.y), math.floor(math.sqrt(dist2(p, f.hq_pos))), task.radius or 96))
          end
          return { x = p.x, y = p.y }
        end
      end
    end
  end
  open_request(f, k, res, tick, "minage")
  return nil
end

---------------------------------------------------------------------------------------------------
-- Interface lue par le cerveau
---------------------------------------------------------------------------------------------------
--- Carte de connaissance de l'équipe (lecture seule), ou nil.
function X.knowledge(f) return f and f.ai3f and f.ai3f.m or nil end

--- Tick du dernier regard sur le secteur du point, ou nil (jamais vu).
function X.seen(f, x, y)
  local m = X.knowledge(f)
  return m and K.seen_xy(m, x, y) or nil
end

--- Nombre de secteurs vus.
function X.known_sectors(f)
  local m = X.knowledge(f)
  return m and m.n or 0
end

--- Gisements CONNUS d'une ressource, du plus proche du QG au plus lointain, avec leur danger :
--- { x, y, tiles, amount, seen, distance, risk (E.risk, pour mille), inputs (nids, vers, chemin, part vue...) }.
function X.deposits(f, res, tick)
  local m = X.knowledge(f)
  if not m then return {} end
  tick = tick or game.tick
  local out = {}
  for _, d in ipairs(K.deposits(m, res, f.hq_pos)) do
    local risk, inputs = K.site_risk(m, d, f.hq_pos, tick)
    out[#out + 1] = { x = d.x, y = d.y, tiles = d.n, amount = d.a, seen = d.t, distance = math.floor(math.sqrt(d.d2)),
      risk = risk, inputs = inputs }
  end
  return out
end

--- Étape « explore » du cerveau : chercher une ressource. Renvoie « connu » (un gisement est déjà connu), « demande »
--- ou « en cours ».
function X.request(f, res, tick, why)
  local k = f and f.ai3f
  if not k then return nil end
  tick = tick or game.tick
  if K.count(k.m, res) > 0 and why ~= "encore" then return "connu" end
  return open_request(f, k, res, tick, why or "cerveau")
end

function X.cancel(f, res, tick)
  local k = f and f.ai3f
  if k and k.req[res] then close_request(f, k, res, tick or game.tick, "annulee") end
end

--- État d'une ressource pour le cerveau : connue, demande ouverte, éclaireur en route.
function X.status(f, res)
  local k = f and f.ai3f
  if not k then return nil end
  local r = k.req[res]
  return { known = K.count(k.m, res), open = r ~= nil, since = r and r.t or nil,
    exploring = k.ex ~= nil and k.ex.res == res, found_after = k.stats.found and k.stats.found[res] or nil }
end

---------------------------------------------------------------------------------------------------
-- Interface distante (bancs) : « fo-ia3f »
---------------------------------------------------------------------------------------------------
local function team_by_key(key)
  for _, f in ipairs(teams()) do
    if f.key == key or tostring(f.id) == tostring(key) then return f end
  end
  return nil
end

local function team_report(f)
  local k = f.ai3f
  if not k then return { key = f.key, open = false } end
  local sum = K.summary(k.m)
  local req = {}
  for _, res in ipairs(sorted_keys(k.req)) do
    local r = k.req[res]
    req[#req + 1] = { res = res, t = r.t, why = r.why, exhausted = r.exhausted }
  end
  local found = {}
  for _, res in ipairs(sorted_keys(k.m.found)) do found[#found + 1] = { res = res, t = k.m.found[res] } end
  return {
    key = f.key, open = true, sectors = sum.sectors, nests = sum.nests, worms = sum.worms, deposits = sum.deposits,
    found = found, requests = req, done = k.done, tour = k.tour.state, tour_done_at = k.tour.done_at,
    mission = k.ex and { kind = k.ex.kind, res = k.ex.res, started = k.ex.started, agent = k.ex.agent, state = k.ex.state } or nil,
    looks = k.stats.looks, missions = k.stats.missions or 0, flees = k.stats.flees or 0, deaths = k.stats.deaths or 0,
    injected = k.stats.injected or 0, far_mine = k.stats.far_mine or 0, audit_ok = k.audit.ok, audit_bad = #k.audit.bad,
    found_after = k.stats.found,
  }
end

remote.add_interface("fo-ia3f", {
  --- Brouillard (true : comportement du lot ; false : comportement d'avant le lot, pour les bancs avant / après).
  set_fog = function(on)
    G().fog = on and true or false
    log("[FO-IA3F] brouillard " .. (G().fog and "ACTIF" or "COUPE (comportement d'avant le lot)"))
    return G().fog
  end,
  fog = function() return X.fog_on() end,
  status = function()
    local out = { fog = X.fog_on(), stats = G().stats, teams = {} }
    for _, f in ipairs(teams()) do out.teams[#out.teams + 1] = team_report(f) end
    return out
  end,
  request = function(key, res)
    local f = team_by_key(key)
    return f and X.request(f, res, game.tick, "cerveau") or nil
  end,
  seen = function(key, x, y)
    local f = team_by_key(key)
    return f and X.seen(f, x, y) or nil
  end,
  deposits = function(key, res)
    local f = team_by_key(key)
    return f and X.deposits(f, res) or {}
  end,
  --- Réserve de sites d'une équipe : { x, y, resource, seen (tick du 1er regard sur son secteur ou nil) }.
  prospects = function(key)
    local f = team_by_key(key)
    local out = {}
    if not f then return out end
    for _, s in ipairs(f.prospects or {}) do
      out[#out + 1] = { x = s.x, y = s.y, resource = s.resource, seeded = s.seeded or false,
        seen = f.ai3f and K.first_seen(f.ai3f.m, K.key_of(s.x, s.y)) or nil }
    end
    return out
  end,
})

return X
