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

  État (nombres, chaînes, tables) : f.ai3f = { m, q, qi, inq, gen, born, fixed_at, fixed_n, tour, req, done, exl,
  next_mission, next_check, probed, audit, stats, home_seen } ; global.fo.ai3f = { fog, lc, tc, seq, stats }.
  Lot IA-V2 : `exl` = LISTE des missions en cours (un tour, ou jusqu'à EXPLORERS_MAX explorations quand des PNJ
  attendent sans travail) ; aucune demande d'exploration avant que les abords du QG soient vus (`home_seen`).
  Journal : « [FO-IA3F] ».
]]

local Rg = require("shared.ai3.reglages") -- lot IA-G : corps du personnage (place libre), nom déplacé
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
local Board = require("script.team.board") -- lot IA-V2 : crochet Board.on_fail (déjà chargé par control.lua)
-- Lot IA-V2 : le cerveau par besoins (IA3-c) lit les gisements CONNUS par un crochet (module déjà chargé par
-- script/team/team.lua : l'ordre de chargement, donc des abonnements, ne change pas).
local Ia3 = require("script.ai3.cerveau")
local Veille = require("script.faction.veille") -- lot VEILLE : reconnaissance régulière par ouvrier libre (état, compteurs, bilans)
local V = require("shared.faction.veille")

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
local FLEE_RADIUS = 64         -- §4.1 : il fuit s'il voit un ennemi (40 tuiles avant le lot IA-V2 : ia3-fer-joueur, 27/10 :
                               -- éclaireur tué par un petit biter à 177 tuiles du QG, 2 passages sur 3 ; 64 : au-delà de la
                               -- vue des biters, il fait demi-tour avant d'être pris en chasse)
local ENEMY_PERIOD = 15 -- lot IA-V2 : regard deux fois plus fréquent (30 avant)
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
-- Lot PD-CENTRALE (vérification rapide, 30/10) : la demande « centrale » (eau de la centrale lointaine) n'est jamais « trouvée »
-- par un gisement ; la centrale la ferme (posée, ou refus après 20 min, Cl.EXPLORE_WAIT). Si le projet disparaît avant (centrale
-- posée dans le treillis, projet abandonné), elle restait ouverte et, la plus ancienne, passait devant toutes les autres
-- (next_request) : expiration après 25 min.
local CENTRALE_REQ_TTL = 25 * 3600
local EXHAUSTED_RETRY = 10 * 3600
local PROBE_RETRY = 5 * 3600
local MIN_TEAM = 2             -- jamais d'éclaireur dans une équipe de moins de 2 PNJ
-- Lot IA-V2 (constats du DC : « plein qui foutent rien », « n'explorent pas et regardent même pas autour d'eux ») :
local HOME_GIVEUP = 2 * 3600   -- abords du QG (œil du QG) vus avant toute demande d'exploration, au plus 2 min d'attente
local EXPLORERS_MAX = 3        -- éclaireurs à la fois quand une ressource manque ET que des PNJ attendent sans travail
local IDLE_PER_EXPLORER = 3    -- un éclaireur de plus par 3 PNJ sans tâche (le premier part sans condition)
local MULTI_TEAM = 4           -- plusieurs éclaireurs seulement dans une équipe d'au moins 4 PNJ
local EXTRA_GAP = 300          -- départs des éclaireurs supplémentaires espacés de 5 s
local SPREAD = 160             -- un éclaireur de plus ne vise pas un secteur à moins de 160 tuiles de la cible d'un autre
-- Lot IA-V2 (moteur réel, ia3c-reduit, graine 20261020, 27/10 : Azur, 77 missions « chemin » en 0,0 min pendant 70 min,
-- toujours la même cible, aucun site de cuivre, donc aucune tourelle, donc l'avant-poste de fer bloqué par « défendre
-- d'abord ») : point de passage posé sur une case LIBRE ; une cible au chemin raté est écartée pour toute l'équipe.
local BAD_TTL = 10 * 3600      -- cible au chemin raté écartée 10 min (toutes missions de l'équipe)
local FREE_RADIUS = 24         -- case libre cherchée à 24 tuiles au plus du point de passage
local FAIL_MAX = 3             -- chemins ratés EN ROUTE repris par une autre cible, par mission d'exploration
-- Lot EXPLO (moteur réel, 28/10, graine 20261020 : Azur, QG au bord d'un lac de 200 tuiles, 17 fins « chemin » sur 30
-- départs, 0 gisement trouvé) : un chemin raté vers un point de passage bloque la région autour (BLOCK_R) et le cône
-- derrière lui (K.blocked_near) pour BLOCK_TTL ;
-- ni les tours ni les cibles ne la visent, et un tour saute le point raté au lieu de rejouer le même échec.
local BLOCK_R = 128
local BLOCK_TTL = 30 * 3600
local BLOCK_CAP = 16
local SHORT_MISSION = 600      -- mission « finie » en moins de 10 s à l'aller : demi-tour de danger, pas une fin

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
  -- Lot IA-V2 : un joueur regarde autour de sa base avant de partir explorer (critère A6) : pas de demande tant que les
  -- abords du QG ne sont pas vus (moteur réel, ia3c-dc-apres, 27/10 : exploration du fer demandée à 0,1 min alors que
  -- le gisement était à 127 tuiles, dans l'œil du QG pas encore regardé).
  if not k.home_seen then return "abords" end
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

local function start_mission(f, k, a, kind, res, tick, veille)
  local g = G()
  g.seq = g.seq + 1
  local surface = a.entity.surface
  local ex = { tag = g.seq, agent = a.id, kind = kind, res = res, started = tick, state = "out", bad = {}, veille = veille and true or nil }
  a.task = { kind = "explore", key = "ai3f:" .. kind .. ":" .. g.seq, ai3f = g.seq, claimed = tick, res = res }
  a.ai3f_eye = K.EYE.explorer
  local steps
  if kind == "tour" then
    local first = type(f.id) == "number" and (f.id % 8) or 0
    local ring = K.ring(f.hq_pos.x, f.hq_pos.y, TOUR_RADIUS, first)
    steps = {}
    local wait = false
    ex.pts = {}
    for i = k.tour.next, #ring do
      local p = ring[i]
      if K.sector_risk(k.m, K.key_of(p.x, p.y), tick, rivals(f, surface)) < K.DANGER.skip
        and not K.blocked_near(k.blocked, p.x, p.y, tick, BLOCK_R, BLOCK_TTL) then
        if not chunk_ready(surface, p) then
          surface.request_to_generate_chunks(p, 1)
          wait = true
        end
        -- Lot IA-V2 : point de l'anneau posé sur une case libre (eau, falaise : chemin raté en 0 s).
        local q = chunk_ready(surface, p) and surface.find_non_colliding_position(Rg.BODY, p, FREE_RADIUS, 1) or nil
        steps[#steps + 1] = { "goto", q and { x = q.x, y = q.y } or p, 6 }
        ex.pts[#ex.pts + 1] = { x = p.x, y = p.y, ring = i }
      end
    end
    if wait then table.insert(steps, 1, { "wait", 120 }) end
    ex.ring_first = k.tour.next
    steps[#steps + 1] = { "home" }
  else
    ex.known0 = res and K.count(k.m, res) or 0
    steps = { { "wait", 120 }, { "home" } } -- la cible est choisie à la première surveillance (au plus 15 ticks)
    ex.next_target = tick
  end
  k.exl = k.exl or {}
  k.exl[#k.exl + 1] = ex
  k.stats.missions = (k.stats.missions or 0) + 1
  set_steps(a, steps, tick)
  log(string.format("[FO-IA3F] %s : eclaireur %d part (%s%s) a %.1f min, secteurs vus %d, eclaireurs %d", team_label(f), a.id,
    kind, res and (" " .. res) or (veille and " veille" or ""), minutes(tick), k.m.n, #k.exl))
  if veille then Veille.on_start(f, tick) end
end

local function end_mission(f, k, ex, tick, why)
  local rest = {}
  for _, e in ipairs(k.exl or {}) do if e.tag ~= ex.tag then rest[#rest + 1] = e end end
  k.exl = rest
  local a = Registry.get(ex.agent)
  if a then a.ai3f_eye = nil end
  k.next_mission = tick + ((why == "fuite" or why == "perdu") and COOLDOWN_FLEE or COOLDOWN)
  -- Lot IA-V2 : chemins ratés à la suite : attente doublée à chaque fois (10 s, 20 s, … 160 s au plus).
  if why == "chemin" then
    k.chemin_n = math.min(4, (k.chemin_n or 0) + 1)
    k.next_mission = tick + COOLDOWN * (2 ^ k.chemin_n)
  else
    k.chemin_n = 0
  end
  -- Ménage des cibles écartées (expirées).
  for _, key in ipairs(sorted_keys(k.badt or {})) do
    if tick - k.badt[key] >= BAD_TTL then k.badt[key] = nil end
  end
  if ex.kind == "tour" then
    k.tour.tries = (k.tour.tries or 0) + 1
    if why == "fini" or why == "duree" or k.tour.tries >= 3 then
      k.tour.state = "done"
      k.tour.done_at = tick
    end
  end
  log(string.format("[FO-IA3F] %s : eclaireur %d (%s%s) fin : %s apres %.1f min, secteurs vus %d", team_label(f), ex.agent,
    ex.kind, ex.res and (" " .. ex.res) or (ex.veille and " veille" or ""), why, minutes(tick - ex.started), k.m.n))
  if ex.veille then Veille.on_end(f, tick, tick - ex.started, why) end
end

--- Secteurs écartés d'une cible d'exploration (table locale, jamais rangée dans global). `ex` : la mission du PNJ (cibles ratées de
--- cette mission), ou nil (lot VEILLE : choix du but d'une mission avant son départ).
local function make_exclude(k, tick, ex)
  -- Lot IA-V2 : plusieurs éclaireurs : chacun évite les secteurs proches de la cible d'un autre (exclusion calculée à la
  -- demande, table locale jamais rangée dans global).
  local others = {}
  for _, e in ipairs(k.exl or {}) do
    if (not ex or e.tag ~= ex.tag) and e.target then
      local ox, oy = K.center(K.xy(e.target))
      others[#others + 1] = { x = ox, y = oy }
    end
  end
  local badt = k.badt or {}
  return setmetatable({}, { __index = function(_, key)
    if ex and ex.bad[key] then return true end
    local t0 = badt[key]
    if t0 and tick - t0 < BAD_TTL then return true end
    local bx, by = K.center(K.xy(key))
    if k.blocked and #k.blocked > 0 and K.blocked_near(k.blocked, bx, by, tick, BLOCK_R, BLOCK_TTL) then return true end
    -- Lot EXPLO (moteur réel, 28/10 : votre équipe, 29 fuites sur 44 départs, 5 fois au même nid) : un secteur à portée de fuite
    -- d'un nid ou d'un ver VU est écarté (l'éclaireur y fuirait de toute façon à FLEE_RADIUS).
    local nests, worms = K.enemies_near(k.m, bx, by, FLEE_RADIUS)
    if nests + worms > 0 then return true end
    if #others > 0 then
      local cx, cy = K.center(K.xy(key))
      for _, o in ipairs(others) do
        if (cx - o.x) ^ 2 + (cy - o.y) ^ 2 < SPREAD * SPREAD then return true end
      end
    end
    return nil
  end })
end

local function retarget(f, k, a, ex, tick)
  local e = a.entity
  local surface = e.surface
  local me = { x = e.position.x, y = e.position.y }
  local exclude = make_exclude(k, tick, ex)
  local key
  if ex.veille then
    -- Lot VEILLE : le but est celui de la règle pure (secteur de la bande du rayon, le plus ancien d'abord), gardé jusqu'à ce qu'il soit
    -- vu ; seul le point de passage change d'une étape à l'autre. Un but dont le chemin a raté (ex.bad) n'est PAS regardé de nouveau :
    -- la reprise (FAIL_MAX) en choisit un autre (pick_goal l'écarte par k.badt).
    if ex.target and not ex.bad[ex.target] then
      key = ex.target
    else
      local vs = Veille.state(f)
      local g = Veille.pick_goal(f, tick, V.radius(vs.trips), vs.last_oct)
      if g then
        key = g.key
        vs.last_oct = g.octant
        Veille.on_goal(f, tick, g, V.radius(vs.trips))
      end
    end
  else
    key = K.best_target(k.m, { hq = f.hq_pos, me = me, tick = tick, res = ex.res, spawn = spawn_of(surface),
      rivals = rivals(f, surface), exclude = exclude })
  end
  if not key then
    local r = ex.res and k.req[ex.res]
    if r then r.exhausted = tick end
    go_home(a, ex, "rien", tick)
    return
  end
  ex.target = key
  local cx, cy = K.center(K.xy(key))
  local wp = K.toward(me, { x = cx, y = cy }, WAYPOINT)
  if chunk_ready(surface, wp) then
    local q = surface.find_non_colliding_position(Rg.BODY, wp, FREE_RADIUS, 1)
    if q then wp = { x = q.x, y = q.y } end
  end
  ex.wp = { x = wp.x, y = wp.y }
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

local function monitor_one(f, k, ex, tick)
  local a = Registry.get(ex.agent)
  if not (a and a.entity and a.entity.valid) then
    end_mission(f, k, ex, tick, "perdu")
    return
  end
  local t = a.task
  if not (t and t.ai3f == ex.tag) then
    -- Lot EXPLO (moteur réel, 28/10, graine 20261020 : votre équipe, 20 départs de suite finis en 0,0 min toutes les 12 s) :
    -- la tâche a disparu moins de 10 s après le départ, l'éclaireur étant encore à l'aller : le demi-tour de danger
    -- (script/ai3/comportement.lua : tâche abandonnée, puis retour au QG déjà atteint) est passé entre deux surveillances.
    -- La cible est écartée comme un chemin raté à la 2e fois.
    if ex.kind == "explore" and ex.state ~= "home" and tick - ex.started < SHORT_MISSION then
      if ex.target then
        -- Écartée à la 2e fois sur la même cible (une disparition isolée peut être un chemin raté au hasard).
        k.short = k.short or {}
        k.short[ex.target] = (k.short[ex.target] or 0) + 1
        if k.short[ex.target] >= 2 then
          k.short[ex.target] = nil
          k.badt = k.badt or {}
          k.badt[ex.target] = tick
        end
      end
      end_mission(f, k, ex, tick, "danger")
      return
    end
    end_mission(f, k, ex, tick, ex.state == "home" and ex.why or "fini")
    return
  end
  if not t.fail then
    local st = a.steps and a.steps[a.pc]
    if st and st[1] == "goto" then ex.last_goto, ex.last_pc = { x = st[2].x, y = st[2].y }, a.pc end
  elseif t.fail == "chemin" and not ex.noted_fail then
    ex.noted_fail = true
    -- Lot EXPLO : région bloquée (le point visé, sinon le point de passage de la mission) ; un tour saute le point raté.
    local gp = ex.last_goto or ex.wp or (ex.pts and ex.pts[1])
    if gp then
      k.blocked = k.blocked or {}
      local me = a.entity.position
      K.note_blocked(k.blocked, me.x, me.y, gp.x, gp.y, tick, BLOCK_CAP)
      k.stats.blocked = (k.stats.blocked or 0) + 1
      log(string.format("[FO-IA3F] %s : eclaireur %d : chemin rate vers (%d, %d), region bloquee (%d en tout)", team_label(f),
        a.id, math.floor(gp.x), math.floor(gp.y), #k.blocked))
    end
    if ex.kind == "tour" and ex.pts then
      -- Point du tour en cours : le dernier but vu, sinon le premier ; le tour reprend après lui.
      local idx = 1
      if ex.last_goto then
        for i, p in ipairs(ex.pts) do
          if math.abs(p.x - ex.last_goto.x) < FREE_RADIUS + 2 and math.abs(p.y - ex.last_goto.y) < FREE_RADIUS + 2 then idx = i break end
        end
      end
      k.tour.next = math.min(9, ex.pts[idx].ring + 1)
    end
  end
  if t.fail then -- chemin raté : le PNJ rentre de lui-même (étape home)
    if ex.target then
      ex.bad[ex.target] = true
      k.badt = k.badt or {}
      k.badt[ex.target] = tick -- lot IA-V2 : écartée pour toute l'équipe (BAD_TTL)
    end
    -- Lot IA-V2 (moteur réel, ia3c-reduit graine 20261020, code 4e0388b : Écarlate, 32 missions sur 33 finies sur
    -- « chemin », point de passage de 96 tuiles introuvable EN ROUTE, puis retour à pied au QG ; aucun fer lointain en
    -- 2 h) : une mission d'exploration prend une autre cible depuis là où il est, au plus FAIL_MAX fois. Factions
    -- seulement : votre équipe garde le retour au QG (cas du DC ia3-fer-joueur, 948888e : l'éclaireur repris à 6,6 min
    -- est tué au retour à 328 tuiles, 2 passages sur 2 ; le joueur explore lui-même au loin).
    if t.fail == "chemin" and ex.kind == "explore" and ex.state ~= "home" and not f.is_player
      and (ex.fails or 0) < FAIL_MAX then
      ex.fails = (ex.fails or 0) + 1
      ex.noted_fail = nil
      t.fail = nil
      k.stats.rerouted = (k.stats.rerouted or 0) + 1
      log(string.format("[FO-IA3F] %s : eclaireur %d : chemin rate en route, autre cible (%d/%d) a %.1f min", team_label(f),
        a.id, ex.fails, FAIL_MAX, minutes(tick)))
      retarget(f, k, a, ex, tick)
      return
    end
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
    if ex.res and K.count(k.m, ex.res) > (ex.known0 or 0) then
      go_home(a, ex, "trouve", tick)
      return
    end
    -- Nouvelle cible : la précédente est vue, ou le point de passage est atteint (étape « wait » après le goto).
    local step = a.steps and a.steps[a.pc]
    local arrived = step and step[1] == "wait" and (step[2] or 0) >= 600
    if ex.veille then
      -- Lot VEILLE : la mission finit quand son but est vu depuis son départ (l'œil du PNJ, 128 tuiles) ; sinon étape suivante vers lui.
      if ex.target and (K.seen(k.m, ex.target) or -1) >= ex.started then
        go_home(a, ex, "fini", tick)
        return
      end
      if tick >= (ex.next_target or 0) and (not ex.target or arrived) then
        retarget(f, k, a, ex, tick)
      elseif step and step[1] == "home" and ex.state ~= "home" then
        retarget(f, k, a, ex, tick)
      end
    elseif tick >= (ex.next_target or 0) and (not ex.target or K.seen(k.m, ex.target) or arrived) then
      retarget(f, k, a, ex, tick)
    elseif step and step[1] == "home" and ex.state ~= "home" then
      retarget(f, k, a, ex, tick) -- ne jamais rentrer avant la fin de la mission
    end
  end
end

local function monitor(f, k, tick)
  local list = {}
  for _, ex in ipairs(k.exl or {}) do list[#list + 1] = ex end
  for _, ex in ipairs(list) do monitor_one(f, k, ex, tick) end
end

---------------------------------------------------------------------------------------------------
-- Une équipe : fondation, yeux, demandes automatiques, missions, contrôle des sites
---------------------------------------------------------------------------------------------------
local function init(f, surface, tick)
  local war = State.war()
  local k = {
    m = K.new(), q = {}, qi = 1, inq = {}, gen = {}, born = f.started or war.started or tick, fixed_at = -1e9, fixed_n = -1,
    tour = { state = "todo", next = 1 }, req = {}, done = {}, exl = {}, next_mission = tick + 60, next_check = tick,
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
    elseif r.why == "centrale" and tick - r.t >= CENTRALE_REQ_TTL then
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

--- Mesures des bancs (avec ET sans brouillard : avant / après sur la même source) : date du n-ième avant-poste de chaque
--- type, date du premier site NON de départ de chaque ressource entré en réserve. f.ai3m (nombres seulement).
local function measure(f, tick)
  local mm = f.ai3m
  if not mm then
    mm = { out = {}, site = {} }
    f.ai3m = mm
  end
  local n = {}
  for _, oid in ipairs(sorted_keys(f.outposts or {})) do
    local kind = f.outposts[oid].kind or "?"
    n[kind] = (n[kind] or 0) + 1
  end
  for _, kind in ipairs(sorted_keys(n)) do
    local list = mm.out[kind] or {}
    mm.out[kind] = list
    while #list < n[kind] do list[#list + 1] = tick end
  end
  for _, s in ipairs(f.prospects or {}) do
    if not s.seeded and s.resource and not mm.site[s.resource] then mm.site[s.resource] = tick end
  end
end

--- Lot IA-V2 : les abords du QG (secteurs de l'œil du QG) sont-ils tous vus ? Une fois vrai, le reste (ou au bout de
--- HOME_GIVEUP : secteur jamais généré, file pleine).
local function home_check(f, k, tick)
  if k.home_seen then return true end
  local all = true
  for _, key in ipairs(eye_keys(f.hq_pos.x, f.hq_pos.y, K.EYE.hq)) do
    if not K.seen(k.m, key) then all = false break end
  end
  if all or tick - (k.opened or k.born) >= HOME_GIVEUP then
    k.home_seen = tick
    log(string.format("[FO-IA3F] %s : abords du QG %s a %.1f min, secteurs vus %d", team_label(f),
      all and "vus" or "vus en partie (delai)", minutes(tick), k.m.n))
    -- Demande en attente pendant le regard (crochet du minage) : les besoins sont relus tout de suite.
    k.next_check = tick
  end
  return k.home_seen ~= nil
end

local function idle_count(f)
  local n = 0
  for _, id in ipairs(sorted_keys(f.engineers or {})) do
    local a = Registry.get(id)
    if a and a.entity and a.entity.valid and a.task == nil and a.state == "idle" and not a.nav then n = n + 1 end
  end
  return n
end

local function team_pass(f, tick)
  local surface = surface_of(f)
  if not surface then return end
  measure(f, tick)
  local k = f.ai3f or init(f, surface, tick)
  k.exl = k.exl or {}
  k.opened = k.opened or tick
  fixed_eyes(f, k, tick)
  moving_eyes(f, k, surface, tick)
  audit(f, k, tick)
  home_check(f, k, tick)
  if tick >= k.next_check then
    k.next_check = tick + CHECK_PERIOD
    auto_requests(f, k, surface, tick)
  end
  if tick < k.next_mission then return end
  local n = #k.exl
  for _, ex in ipairs(k.exl) do if ex.kind == "tour" then return end end
  local kind, res
  if k.tour.state == "todo" and n == 0 then
    if tick - k.born > TOUR_DEADLINE then k.tour.state = "skip" else kind = "tour" end
  end
  if not kind then
    res = next_request(k, tick)
    if res then kind = "explore" end
  end
  -- Lot VEILLE : sans demande de ressource ni tour, une faction envoie à intervalle un ouvrier LIBRE reconnaître la carte (rayon
  -- croissant). Aucun soldat, aucun kit ; jamais votre équipe ; jamais un ouvrier utile (tâche libre au tableau, crise).
  local veille = false
  if not kind and n == 0 and not f.is_player and k.home_seen and Veille.enabled() then
    local vs = Veille.state(f)
    local st = f.chef
    local open = Board.takeable(f) -- tâches libres PRENABLES : un PNJ libre devant elles serait utile ; devant des tâches bloquées, non
    local idle = idle_count(f)
    local next_at = vs.next_at
    -- Bancs de mesure seulement (lot CORR-RECON) : comptes imposés, premier départ avancé, ancienne règle.
    if Veille.force then idle, open = Veille.force.idle or idle, Veille.force.open or open end
    if Veille.start and vs.sent == 0 then next_at = math.min(next_at, Veille.start) end
    if not Veille.surplus and open > 0 then open = math.max(open, idle) end -- ancienne règle : une tâche prenable bloque
    local ok, why = V.want({ tick = tick, next_at = next_at, threat = st and st.last_threat or 0, survive = st and st.survival or false,
      alert = tick < (f.threatened_until or 0), tour_done = k.tour.state ~= "todo", request = false, open_tasks = open,
      idle = idle, missing = f.team ~= nil and f.team.missing ~= nil and #f.team.missing > 0 })
    if ok then kind, veille = "explore", true else Veille.refuse(f, why) end
  end
  if not kind then return end
  if n > 0 then
    -- Lot IA-V2 (B4 : « met plusieurs personnes sur l'urgence ») : un éclaireur de plus seulement si des PNJ attendent
    -- sans travail (un par IDLE_PER_EXPLORER), dans une équipe d'au moins MULTI_TEAM PNJ, au plus EXPLORERS_MAX.
    if (f.engineers_count or 0) < MULTI_TEAM then return end
    local idle = idle_count(f)
    local cap = math.min(EXPLORERS_MAX, 1 + math.floor(idle / IDLE_PER_EXPLORER))
    if n >= cap then return end
  end
  -- Lot IA-V2 : le tour part quand les morceaux de carte de son anneau sont générés (ses points sont alors posés sur des
  -- cases libres ; moteur réel, 27/10 : tours d'Azur tous ratés sur « chemin » en 0,0 min) ; au plus 2 min d'attente.
  if kind == "tour" and tick - (k.opened or tick) < HOME_GIVEUP then
    local surface = surface_of(f)
    local first = type(f.id) == "number" and (f.id % 8) or 0
    local wait = false
    for _, p in ipairs(K.ring(f.hq_pos.x, f.hq_pos.y, TOUR_RADIUS, first)) do
      if not chunk_ready(surface, p) then
        surface.request_to_generate_chunks(p, 1)
        wait = true
      end
    end
    if wait then
      k.next_mission = tick + 120
      return
    end
  end
  local a = pick_idle(f)
  if a then
    start_mission(f, k, a, kind, res, tick, veille)
    if kind == "explore" then k.next_mission = tick + EXTRA_GAP end
  elseif veille then
    Veille.refuse(f, "pas de PNJ libre")
  end
end

Scheduler.define_lane(X.EYE_LANE, EYE_PERIOD, function(_, tick)
  local g = G()
  local list = teams()
  if #list == 0 then return end
  if not g.fog then
    -- Brouillard coupé (comportement d'avant le lot) : mesures seulement, une équipe par passe.
    g.tc = g.tc % #list + 1
    measure(list[g.tc], tick)
    return
  end
  Profiler.start("ai3f:eyes")
  for _, f in ipairs(list) do
    if f.ai3f and f.ai3f.exl and #f.ai3f.exl > 0 then monitor(f, f.ai3f, tick) end
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
  local unreach = k.unreach or {}
  for _, d in ipairs(K.deposits(k.m, res, f.hq_pos)) do
    if d.d2 > FAR_MINE * FAR_MINE then break end
    -- Lot IA-V2 : gisement au chemin raté récemment (Board.on_fail) : sauté (moteur réel, ia3c-reduit graine 20261020 :
    -- Azur, 45 minages à la main ratés sur « chemin », toujours vers les mêmes gisements de l'autre côté de l'eau).
    local t0 = unreach[d.key]
    if t0 and tick - t0 < BAD_TTL then goto continue end
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
          task.far_key = d.key -- lot IA-V2 : gisement visé (mémoire des chemins ratés, Board.on_fail)
          if (k.stats.far_mine or 0) == 1 then
            log(string.format("[FO-IA3F] %s : minage de %s au gisement connu en (%d, %d), %d tuiles du QG (rien a %d tuiles)",
              team_label(f), res, math.floor(p.x), math.floor(p.y), math.floor(math.sqrt(dist2(p, f.hq_pos))), task.radius or 96))
          end
          return { x = p.x, y = p.y }
        end
      end
    end
    ::continue::
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
    exploring = (function()
      for _, ex in ipairs(k.exl or {}) do if ex.res == res then return true end end
      return false
    end)(), found_after = k.stats.found and k.stats.found[res] or nil }
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
  local mm = f.ai3m or { out = {}, site = {} }
  if not k then return { key = f.key, open = false, outposts_at = mm.out, site_at = mm.site } end
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
    mission = k.exl and k.exl[1] and { kind = k.exl[1].kind, res = k.exl[1].res, started = k.exl[1].started,
      agent = k.exl[1].agent, state = k.exl[1].state } or nil, explorers = k.exl and #k.exl or 0, home_seen = k.home_seen,
    looks = k.stats.looks, missions = k.stats.missions or 0, flees = k.stats.flees or 0, deaths = k.stats.deaths or 0,
    injected = k.stats.injected or 0, far_mine = k.stats.far_mine or 0, audit_ok = k.audit.ok, audit_bad = #k.audit.bad,
    found_after = k.stats.found, outposts_at = mm.out, site_at = mm.site,
    marks = #k.m.marks, explorer_eye = K.EYE.explorer,
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

-- Lot IA-V2 : crochet du cerveau par besoins (script/ai3/cerveau.lua, gisements atteignables) : gisements CONNUS sous
-- brouillard, nil quand le brouillard est coupé (témoins « avant » : lecture de la carte entière, comme avant).
Ia3.known_deposits = function(f, res, tick)
  if not X.fog_on() then return nil end
  if not (f and f.ai3f) then return {} end
  return X.deposits(f, res, tick)
end
-- Abords du QG vus (aucune exploration demandée avant) ; nil quand le brouillard est coupé.
Ia3.home_known = function(f)
  if not X.fog_on() then return nil end
  return (f and f.ai3f and f.ai3f.home_seen) ~= nil
end

-- Lot IA-V2 : un minage lointain raté sur « chemin » marque son gisement injoignable BAD_TTL (Worker.far_mine le saute).
Board.on_fail = function(f, task, tick)
  if task.kind ~= "mine" or not task.far_key or task.fail ~= "chemin" then return end
  local k = f.ai3f
  if not k then return end
  k.unreach = k.unreach or {}
  k.unreach[task.far_key] = tick
  for _, key in ipairs(sorted_keys(k.unreach)) do
    if tick - k.unreach[key] >= BAD_TTL then k.unreach[key] = nil end
  end
end

---------------------------------------------------------------------------------------------------
-- Lot VEILLE : crochets lus par script/faction/veille.lua (carte de connaissance, choix du but)
---------------------------------------------------------------------------------------------------
--- Nombre de secteurs reconnus par l'équipe (champ n de la carte de connaissance), ou nil.
Veille.known = function(f)
  local k = f.ai3f
  return k and k.m and k.m.n or nil
end

--- But de la prochaine mission : parmi les secteurs GÉNÉRÉS de la bande R ± V.BAND autour du QG, jamais vus ou vus depuis V.STALE,
--- sûrs, hors exclusions et au trajet dégagé de tout nid ou ver vu, le choix de V.pick (le plus ancien d'abord, octants alternés).
--- Renvoie { key, x, y, octant, dh, n (candidats) } ou nil.
Veille.pick_goal = function(f, tick, radius, last_octant)
  local k = f.ai3f
  local surface = surface_of(f)
  if not (k and surface and f.hq_pos) then return nil end
  local hq = f.hq_pos
  local exclude = make_exclude(k, tick, nil)
  local span = radius + V.BAND
  local x0, x1 = math.floor((hq.x - span) / K.SECTOR), math.floor((hq.x + span) / K.SECTOR)
  local y0, y1 = math.floor((hq.y - span) / K.SECTOR), math.floor((hq.y + span) / K.SECTOR)
  local rivals_list = rivals(f, surface)
  local cands = {}
  for sy = y0, y1 do
    for sx = x0, x1 do
      local key = K.key(sx, sy)
      local cx, cy = K.center(sx, sy)
      local dh = math.sqrt((cx - hq.x) ^ 2 + (cy - hq.y) ^ 2)
      if V.in_band(dh, radius) and not exclude[key] then
        local s = k.m.s[key]
        local age = s and (tick - s.t) or nil
        if V.stale(age) and generated(surface, key) and K.sector_risk(k.m, key, tick, rivals_list) < K.DANGER.skip
          and K.path_clear(k.m, hq, { x = cx, y = cy }) then
          cands[#cands + 1] = { key = key, x = cx, y = cy, dh = dh, age = age, octant = V.octant(cx - hq.x, cy - hq.y) }
        end
      end
    end
  end
  local best = V.pick(cands, last_octant)
  if not best then return nil end
  return { key = best.key, x = best.x, y = best.y, octant = best.octant, dh = best.dh, n = #cands }
end

-- Lot PD-CENTRALE (D-24 : « il faut aller plus loin ») : la centrale lointaine (script/team/centrale_loin.lua) demande ici
-- l'exploration de l'eau quand aucune eau VUE ne tient la centrale ; crochet posé au chargement (pas de require croisé).
do
  local Far = require("script.team.centrale_loin")
  Far.hooks.request, Far.hooks.cancel = X.request, X.cancel
end

return X
