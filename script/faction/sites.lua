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
local Character = require("script.faction.character")
local V = require("shared.faction.valeur")
local Tr = require("shared.faction.traits")
local T = require("shared.team.config")

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
-- Espacement entre deux avant-postes : distance réelle (session 3 : l'exclusion par chunks voisins de 96 × 96 tuiles
-- interdisait d'exploiter un grand gisement à plusieurs), par RESSOURCE depuis le lot SITES (V.spacing).
local ENEMY_CLEARANCE = 48
local CLAIM_SCAN_CHUNKS = 2

local chunk_key = State.chunk_key

--- Ressource d'une revendication ancienne (écrite avant le lot SITES, sans ressource) : lue sur l'avant-poste de la
--- faction qui la détient, à la même position. Rend nil si introuvable (la règle prudente de 40 tuiles s'applique).
local function claim_resource(war, key, entry)
  local owner = war.claims[key]
  local f = owner and war.factions and war.factions[owner]
  if not f then return nil end
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    local dx, dy = o.pos.x - entry.x, o.pos.y - entry.y
    if dx * dx + dy * dy <= 4 then
      local spec = o.kind and T.outposts[o.kind]
      return spec and spec.resource or nil
    end
  end
  return nil
end

--- Revendication qui bloque le site `site` ({ x, y, resource, radius }) : { dist, x, y } ou nil. Une entrée ancienne
--- sans ressource est migrée à la lecture (claim_resource) ; sans position : prudence.
local function claim_blocker(war, site)
  local claims = war.claims
  if next(claims) == nil then return nil end
  local cx, cy = math.floor(site.x / 32), math.floor(site.y / 32)
  local cpos = war.claim_pos or {}
  for dx = -CLAIM_SCAN_CHUNKS, CLAIM_SCAN_CHUNKS do
    for dy = -CLAIM_SCAN_CHUNKS, CLAIM_SCAN_CHUNKS do
      local key = chunk_key(cx + dx, cy + dy)
      if claims[key] then
        local p = cpos[key]
        if not p then return { key = key } end -- ancienne sauvegarde sans position : prudence
        if p.resource == nil then p.resource = claim_resource(war, key, p) end
        if V.too_close(site, p) then
          return { key = key, dist = math.sqrt((p.x - site.x) ^ 2 + (p.y - site.y) ^ 2), x = p.x, y = p.y }
        end
      end
    end
  end
  return nil
end

local function claimed(war, site) return claim_blocker(war, site) ~= nil end

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
function Sites.mark_unreachable(pos, tick, ttl)
  local war = State.war()
  war.unreachable = war.unreachable or {}
  war.unreachable[State.site_key(pos)] = tick + (ttl or UNREACHABLE_TICKS)
end

---------------------------------------------------------------------------------------------------
-- Lot SITE-PROCHE (29/10) : plancher de valeur, site proche bloqué, signal `f.site_blocked`
---------------------------------------------------------------------------------------------------
-- Constat du DC (29/10, partie réelle, Emeraude, « ils vont vachement loin pour le charbon », audit
-- fo-logs/2026-10-29_VAGUE4/AUDIT4/site-charbon.md) : le gisement à 45 tuiles, écarté 30 min pour un ennemi vu une fois
-- (« hostile » puis « injoignable »), n'était plus candidat ; le choix ne refusait JAMAIS un site (valeur -2 083 observée)
-- et envoyait un ouvrier à 201-357 tuiles. Règles pures dans shared/faction/valeur.lua (V.FLOOR, V.admissible).
--   * mémoire f.site_block : sites de la FACTION vus bloqués (hostile, injoignable, écarté) avec leur échéance, 16 au plus
--     (le plus lointain du QG est oublié le premier) ;
--   * Sites.available / find_by_value ne comptent et ne puisent que les sites ADMISSIBLES : valeur au moins V.FLOOR, et
--     pas plus loin que V.suspend_limit tant qu'un site de la MÊME ressource, plus proche, est bloqué (suspendu, pas
--     perdu : il reste en réserve et redevient admissible à la fin du blocage) ;
--   * signal f.site_blocked[ressource] = { x, y, why, until_tick, d_blocked, n, since } posé tant qu'au moins un site est
--     suspendu (pour DEFENSE-FRONT et le cerveau : sécuriser le site proche plutôt que partir loin) ; AUCUNE action ici.
-- L'équipe du joueur garde la règle d'avant (premier site de la réserve) : rien de ceci ne la concerne.
local BLOCK_KEEP = 16
local BLOCK_LOG_MAX = 200

local function unreachable_until(war, pos)
  return war.unreachable and war.unreachable[State.site_key(pos)] or nil
end

local function dist_hq(f, p)
  local hq = f.hq_pos
  return math.floor(math.sqrt((p.x - hq.x) ^ 2 + (p.y - hq.y) ^ 2))
end

--- Retient qu'un site de `resource` est bloqué jusqu'à `until_tick` (même site et même ressource : échéance prolongée).
local function note_blocked(f, site, resource, why, until_tick)
  if not (f.hq_pos and resource and until_tick) then return end
  f.site_block = f.site_block or {}
  local key = State.site_key(site)
  for _, e in ipairs(f.site_block) do
    if e.key == key and e.resource == resource then
      if until_tick > e.until_tick then e.until_tick = until_tick end
      e.why = why
      return
    end
  end
  f.site_block[#f.site_block + 1] = { key = key, x = site.x, y = site.y, resource = resource, why = why, until_tick = until_tick }
  -- Au-delà de la borne, on oublie le blocage le plus LOINTAIN du QG (à égalité, le plus ancien) et non le plus ancien :
  -- c'est le site proche bloqué qui suspend le lointain, et la prospection note chaque chunk injoignable (un voisinage
  -- hostile en remplit la mémoire : le proche, noté le premier, aurait été oublié le premier).
  while #f.site_block > BLOCK_KEEP do
    local drop, dmax = 1, -1
    for i, e in ipairs(f.site_block) do
      local d = dist_hq(f, e)
      if d > dmax then drop, dmax = i, d end
    end
    table.remove(f.site_block, drop)
  end
end

--- Site bloqué le plus proche du QG pour `resource` : { d, x, y, why, until_tick } ou nil. Mémoire (échéances passées
--- retirées) et sites PERDUS récemment revenus à la réserve (le danger de perte dure V.LOST_TTL).
local function blocked_nearest(f, resource, tick)
  local best
  local function offer(d, x, y, why, until_tick)
    if not best or d < best.d then best = { d = d, x = x, y = y, why = why, until_tick = until_tick } end
  end
  local mem = f.site_block
  if mem then
    local keep = {}
    for _, e in ipairs(mem) do
      if e.until_tick > tick then
        keep[#keep + 1] = e
        if e.resource == resource then offer(dist_hq(f, e), e.x, e.y, e.why, e.until_tick) end
      end
    end
    if #keep ~= #mem then f.site_block = keep end
  end
  for _, s in ipairs(f.prospects or {}) do
    if s.lost and s.resource == resource then
      for _, l in ipairs(f.lost_sites or {}) do
        local age = tick - (l.tick or 0)
        if age >= 0 and age < V.LOST_TTL and (l.x - s.x) ^ 2 + (l.y - s.y) ^ 2 <= 4 then
          offer(dist_hq(f, s), s.x, s.y, "perte", l.tick + V.LOST_TTL)
        end
      end
    end
  end
  return best
end

--- Lot SITES (mémoire d'échec par site). Moteur réel, graine 1618033988, 28/10 : le seul site de cuivre de votre équipe
--- (101, -43) était puisé dans la réserve toutes les 35 s pendant toute la partie, puis rendu sans qu'aucun avant-poste
--- n'y soit posé (projet « extraction:copper actif », jamais de livraison, autre cuivre jamais cherché). Un site remis
--- à un ouvrier DEUX fois de suite sans revendication entre les deux (Sites.claim : l'ouvrier a franchi tous les
--- contrôles) est écarté, comme un site injoignable, pendant FAIL_BASE ticks, doublés à chaque nouvel échec (au plus
--- UNREACHABLE_TICKS). La réserve se vide alors de ce site : le projet demande l'exploration d'un autre gisement
--- (shared/ai3/projets.lua) et la prospection en trouve un autre. Un seul essai suit chaque attente.
local FAIL_BASE = 5 * 3600
local FAIL_FREE = 1          -- remises sans revendication tolérées avant l'écart
local function note_handout(f, site, tick)
  f.site_fail = f.site_fail or {}
  local key = State.site_key(site)
  local e = f.site_fail[key] or { n = 0 }
  f.site_fail[key] = e
  local again = e.out ~= nil
  if again then e.n = e.n + 1 end
  if again and e.n > FAIL_FREE then
    local ttl = math.min(UNREACHABLE_TICKS, FAIL_BASE * 2 ^ (e.n - FAIL_FREE - 1))
    Sites.mark_unreachable(site, tick, ttl)
    note_blocked(f, site, site.resource, "ecarte", tick + ttl)
    e.out = nil
    f.stats.site_backoff = (f.stats.site_backoff or 0) + 1
    log(string.format("[FO-SITES] ecarte tick %d %s %s : (%d, %d), %d remises sans avant-poste, ecarte %.1f min", tick, f.key,
      site.resource or "?", math.floor(site.x), math.floor(site.y), e.n, ttl / 3600))
    return false
  end
  e.out = tick
  return true
end

local PROBES_PER_STEP = 4
local MAX_PROSPECTS = 8
local MAX_PER_KIND = 2
-- Lot IA2-b : une faction garde un CHOIX de sites (besoin + 2, au plus 3 par ressource, 12 en tout), choisit par valeur
-- (Sites.find), et prospecte un tour sur deux autour d'un FRONT (un de ses avant-postes lointains, 6 chunks de rayon).
-- L'équipe du joueur garde la règle d'avant (premier site de la réserve, spirale autour du coffre).
local FACTION_EXTRA = 2
local FACTION_MAX_PER_KIND = 3
local FACTION_MAX_PROSPECTS = 12
local FRONT_RADIUS_CHUNKS = 6
local N_FRONT = 0
for _, o in ipairs(OFFSETS) do
  if o.d2 <= FRONT_RADIUS_CHUNKS * FRONT_RADIUS_CHUNKS then N_FRONT = N_FRONT + 1 end
end
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

--- Site de la réserve qui bloque `pos` ({ x, y, resource, radius }) : { site, dist } ou nil.
local function prospect_blocker(f, pos)
  for _, p in ipairs(f.prospects) do
    local dx, dy = p.x - pos.x, p.y - pos.y
    if V.too_close(pos, p) then return { site = p, dist = math.sqrt(dx * dx + dy * dy) } end
  end
  return nil
end

local function near_prospect(f, pos) return prospect_blocker(f, pos) ~= nil end

--- Lot SITES (trace) : un gisement lu et NON retenu, avec son motif. Compteurs dans f.stats.refus (rendus par le bilan),
--- une ligne [FO-SITES] par refus, au plus 400 par équipe.
local REFUS_LOG_MAX = 400
local function refuse(f, tick, reason, res, site, detail)
  f.stats.refus = f.stats.refus or {}
  local k = reason .. ":" .. res
  f.stats.refus[k] = (f.stats.refus[k] or 0) + 1
  if (f.stats.refus_logged or 0) >= REFUS_LOG_MAX then return end
  f.stats.refus_logged = (f.stats.refus_logged or 0) + 1
  local hq = f.hq_pos
  local d = hq and math.floor(math.sqrt((site.x - hq.x) ^ 2 + (site.y - hq.y) ^ 2)) or -1
  log(string.format("[FO-SITES] refus tick %d %s %s : (%d, %d), %d tuiles du QG, motif %s%s", tick, f.key, res,
    math.floor(site.x), math.floor(site.y), d, reason, detail and (" " .. detail) or ""))
end

local function prospects_of(f, resource)
  local n = 0
  for _, p in ipairs(f.prospects or {}) do if p.resource == resource then n = n + 1 end end
  return n
end

--- Lot IA2-c : la réserve peut-elle encore recevoir un site de cette ressource (bornes : 3 par ressource et 12 en
--- tout pour une faction, 2 et 8 pour l'équipe du joueur) ? Un avant-poste perdu y rendait son site SANS les
--- respecter (moteur simulé, tests/valeur_test.lua, trajectoire du lot IA2-c : Écarlate, 4 sites de charbon, 13 en tout).
function Sites.room_for(f, resource)
  local per, total = MAX_PER_KIND, MAX_PROSPECTS
  if not f.is_player then per, total = FACTION_MAX_PER_KIND, FACTION_MAX_PROSPECTS end
  return prospects_of(f, resource) < per and #(f.prospects or {}) < total
end

local function want_of(f, res)
  local need = (f.site_needs or {})[res] or 0
  local want = math.min(MAX_PER_KIND, need)
  if not f.is_player and need > 0 then want = math.min(FACTION_MAX_PER_KIND, need + FACTION_EXTRA) end
  return want
end

--- Ressources encore recherchées (besoins du cerveau d'équipe, f.site_needs = { [ressource] = n }).
local function wanted_resources(f)
  local list = {}
  for _, res in ipairs(State.sorted_keys(f.site_needs or {})) do
    local want = want_of(f, res)
    if want > 0 and prospects_of(f, res) < want then list[#list + 1] = res end
  end
  return list
end

local function max_prospects(f)
  return f.is_player and MAX_PROSPECTS or FACTION_MAX_PROSPECTS
end

--- Flux d'expansion de la faction (lot IA2-b) : Tr.new_stream(graine, 100 + id), créé à la première lecture (partie
--- existante comprise). Angles de départ (script/team/team.lua) puis hasard borné des fronts et des sites.
function Sites.stream(f)
  if not f.expand then f.expand = Tr.new_stream(Character.map_seed(), V.SALT + f.id) end
  return f.expand
end

local function draw_of(f)
  local st = Sites.stream(f)
  return function(n) return Tr.range(st, 1, n) end
end

--- Une tranche de prospection pour la faction f (au plus PROBES_PER_STEP chunks).
--- Seulement si l'équipe a BESOIN de sites : en moteur réel la prospection permanente coûtait
--- 0,09 ms/tick en moyenne, plus que tout le reste du mod. Session 4 : un site = un gisement d'UNE
--- ressource demandée (charbon, fer, cuivre, pierre), centré sur ses tuiles.
--- Lot IA2-b : origine du prochain tour de prospection (f.front ; nil = QG). Elle change à chaque nouvel ÉPISODE de
--- besoin (la réserve était pleine) et à la fin de chaque tour : un sur deux part du QG (curseur f.site_cursor, la
--- spirale d'avant y continue), l'autre d'un de nos avant-postes à V.FRONT_MIN tuiles ou plus du QG (curseur
--- f.front_cursor, remis à 1 quand le front change), choisi par V.pick_front (danger vu, contestation ; hasard borné).
function Sites.next_front(f, tick)
  f.scan_turn = (f.scan_turn or 0) + 1
  f.front_dry = f.front_dry or {}
  local fronts = {}
  local hq = f.hq_pos
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local p = f.outposts[oid].pos
    local dx, dy = p.x - hq.x, p.y - hq.y
    if dx * dx + dy * dy >= V.FRONT_MIN * V.FRONT_MIN then fronts[#fronts + 1] = { key = "o" .. oid, x = p.x, y = p.y } end
  end
  local key = nil
  if #fronts > 0 then key = V.pick_front(fronts, Sites.value_ctx(f, tick), f.front_dry, f.scan_turn, draw_of(f)) end
  local old = f.front and f.front.key or nil
  f.front = nil
  for _, p in ipairs(fronts) do
    if p.key == key then f.front = { key = p.key, x = p.x, y = p.y } end
  end
  if key ~= old then f.front_cursor, f.front_found = 1, 0 end
end

--- Lot IA2-b : RENOUVELLEMENT de la réserve. Toutes les V.REFRESH, le site de plus faible valeur d'une ressource
--- demandée dont la réserve est au complet est oublié (hors gisements de départ) : un nouveau tour de prospection part
--- alors de l'origine suivante (QG ou front). Sans cela, la réserve pleine dès les premières minutes ne bougeait plus
--- (moteur simulé : 0 site trouvé depuis un front en 15 min).
local function refresh_reserve(f, tick)
  local worst, worst_v
  local ctx = nil
  for _, res in ipairs(State.sorted_keys(f.site_needs or {})) do
    local want = want_of(f, res)
    if want > 0 and prospects_of(f, res) >= want then
      local cands = {}
      for _, s in ipairs(f.prospects or {}) do
        if s.resource == res and not s.seeded then cands[#cands + 1] = s end
      end
      if #cands > 0 then
        ctx = ctx or Sites.value_ctx(f, tick)
        local ranked = V.rank(cands, ctx)
        local last = ranked[#ranked]
        if not worst_v or last.value < worst_v then worst, worst_v = last.site, last.value end
      end
    end
  end
  if not worst then return end
  local out = {}
  for _, s in ipairs(f.prospects) do if s ~= worst then out[#out + 1] = s end end
  f.prospects = out
  f.stats.reserve_dropped = (f.stats.reserve_dropped or 0) + 1
end

--- Examine UN chunk (cx, cy) : gisement d'une ressource demandée, libre, centré sur ses tuiles, lu une fois (carte de
--- valeur), mis en réserve s'il n'est ni hostile, ni pris, ni injoignable. Renvoie true si un site a été ajouté.
--- (Corps de la boucle de Sites.prospect, sorti tel quel au lot IA3-f pour servir aussi à Sites.probe_at.)
local function probe(f, surface, cx, cy, tick, wanted, front, other_hqs, spawn, war)
  local center = { x = cx * 32 + 16, y = cy * 32 + 16 }
  Profiler.start("prospect:checks")
  -- Contrôles du moins cher au plus cher.
  local free = far_from(center, other_hqs, MIN_DIST_OTHER_HQ)
    and (f.is_player or far_from(center, { spawn }, MIN_DIST_PLAYER_SPAWN))
    and surface.is_chunk_generated({ x = cx, y = cy })
  local why = nil
  if free and unreachable(war, center, tick) then why = "injoignable" end
  free = free and why == nil
  Profiler.stop("prospect:checks")
  local area = { { cx * 32, cy * 32 }, { cx * 32 + 32, cy * 32 + 32 } }
  -- Lot SITE-PROCHE : le chunk injoignable est retenu (site bloqué) même quand le journal des refus est plein.
  if why and count_resources(surface, area, nil, MIN_RESOURCES) >= MIN_RESOURCES then
    for _, res in ipairs(wanted) do
      if count_resources(surface, area, res, 64) >= MIN_SITE_RESOURCES then
        refuse(f, tick, why, res, center)
        note_blocked(f, center, res, why, unreachable_until(war, center))
      end
    end
  end
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
      local sx, sy, rich = 0, 0, 0
      for _, r in ipairs(tiles) do
        local p = r.position
        sx, sy = sx + p.x, sy + p.y
        rich = rich + (r.amount or 0)
      end
      local site = { x = sx / #tiles, y = sy / #tiles, resource = best, front = front and front.key or nil }
      -- Lot SITES : rayon du site = étendue des tuiles lues autour de leur centre (espacement par ressource, V.spacing).
      local far2 = 0
      for _, r in ipairs(tiles) do
        local d2 = (r.position.x - site.x) ^ 2 + (r.position.y - site.y) ^ 2
        if d2 > far2 then far2 = d2 end
      end
      site.radius = math.ceil(math.sqrt(far2))
      -- Refus de Lua pur d'abord (injoignable, revendiqué, trop près d'un site de la réserve), avant les lectures moteur.
      if unreachable(war, site, tick) then
        refuse(f, tick, "injoignable", best, site)
        note_blocked(f, site, best, "injoignable", unreachable_until(war, site))
        return false
      end
      local cb, pb = claim_blocker(war, site), prospect_blocker(f, site)
      if cb then
        refuse(f, tick, "revendique", best, site, cb.dist and string.format("a %d tuiles de (%d, %d)", cb.dist, cb.x, cb.y) or "sans position")
        return false
      elseif pb then
        refuse(f, tick, "espacement", best, site, string.format("a %d tuiles du site %s (%d, %d)", pb.dist, pb.site.resource,
          pb.site.x, pb.site.y))
        return false
      end
      -- Lot IA2-b : richesse, eau et terrain lus UNE fois à la découverte (carte de valeur, shared/faction/valeur.lua).
      Profiler.start("prospect:value")
      site.rich, site.tiles = rich, #tiles
      site.water = surface.count_tiles_filtered({ position = site, radius = 24, collision_mask = "water-tile", limit = 1 }) > 0
      site.rough = surface.count_entities_filtered({ position = site, radius = 12, type = { "tree", "simple-entity" }, limit = 100 })
      site.cliffs = surface.count_entities_filtered({ position = site, radius = 16, type = "cliff", limit = 8 })
      Profiler.stop("prospect:value")
      -- Moteur réel (session 3) : 27 ingénieurs tués par des vers près de leurs sites. Un site à portée
      -- d'ennemis (déchiqueteurs) est évité ; les ennemis éliminés, il redevient prospectable.
      local hostile = surface.count_entities_filtered({ position = site, radius = ENEMY_CLEARANCE, force = "enemy", limit = 1 }) > 0
      if hostile then
        Sites.mark_unreachable(site, tick)
        note_blocked(f, site, best, "hostile", tick + UNREACHABLE_TICKS)
        f.stats.prospect_hostile = (f.stats.prospect_hostile or 0) + 1
        refuse(f, tick, "hostile", best, site)
      else
        f.prospects[#f.prospects + 1] = site
        f.stats.prospected = (f.stats.prospected or 0) + 1
        return true
      end
    end
  end
  return false
end

local function other_hqs_of(f)
  local other_hqs = {}
  for _, id in ipairs(State.alive()) do
    if id ~= f.id then other_hqs[#other_hqs + 1] = State.faction(id).hq_pos end
  end
  return other_hqs
end

--- Lot IA3-f (exploration sous brouillard) : crochet posé par script/ai3/exploration.lua. seen_filter(f, cx, cy) rend
--- faux pour un chunk dont le secteur n'a jamais été VU par l'équipe : la prospection le saute sans appel moteur et sans
--- compter de sonde. Sans crochet (ou brouillard coupé : il rend toujours vrai), la prospection est celle d'avant.
Sites.seen_filter = nil
local SKIPS_PER_STEP = 64

--- Lot IA3-f : un gisement VU par un œil de l'équipe (x, y) est examiné tout de suite, même hors du disque de
--- prospection (éclaireur lointain), avec les mêmes règles que la prospection. Renvoie true si un site a été ajouté.
function Sites.probe_at(f, surface, x, y, tick)
  f.prospects = f.prospects or {}
  if #f.prospects >= max_prospects(f) then return false end
  local wanted = wanted_resources(f)
  if #wanted == 0 then return false end
  local spawn = game.forces.player.get_spawn_position(surface)
  return probe(f, surface, math.floor(x / 32), math.floor(y / 32), tick, wanted, nil, other_hqs_of(f), spawn, State.war())
end

function Sites.prospect(f, surface, tick)
  f.prospects = f.prospects or {}
  if not f.is_player and tick >= (f.reserve_refresh or 0) then
    f.reserve_refresh = tick + V.REFRESH
    refresh_reserve(f, tick)
  end
  if #f.prospects >= max_prospects(f) or tick < (f.prospect_idle_until or 0) then
    f.scan_idle = true
    return
  end
  local wanted = wanted_resources(f)
  if #wanted == 0 then
    f.scan_idle = true
    return
  end
  local war = State.war()
  local other_hqs = other_hqs_of(f)
  local spawn = game.forces.player.get_spawn_position(surface)
  if not f.is_player then
    -- Front perdu (avant-poste détruit) : retour au QG.
    if f.front and not (f.outposts or {})[tonumber(f.front.key:sub(2))] then f.front = nil end
    -- Nouvel épisode de besoin : nouvelle origine (QG et front alternés).
    if f.scan_idle then
      f.scan_idle = false
      Sites.next_front(f, tick)
    end
  end
  local front = (not f.is_player) and f.front or nil
  local origin = front or f.hq_pos
  local hcx, hcy = math.floor(origin.x / 32), math.floor(origin.y / 32)
  local n = front and N_FRONT or (f.prospect_wide and #OFFSETS or N_NEAR)
  local cursor = front and "front_cursor" or "site_cursor"
  local probes, skips = 0, 0
  while probes < PROBES_PER_STEP do
    local k = f[cursor] or 1
    if k > n then
      f[cursor] = 1
      f.stats.prospect_cycles = (f.stats.prospect_cycles or 0) + 1
      if front then
        -- Lot IA2-b : un front dont le tour n'a rien trouvé est laissé V.FRONT_DRY (compteur propre au front).
        if (f.front_found or 0) == 0 then
          f.front_dry = f.front_dry or {}
          f.front_dry[front.key] = tick + V.FRONT_DRY
        end
        f.front_found = 0
      else
        if (f.prospect_found or 0) == 0 then
          if not f.prospect_wide then
            f.prospect_wide = true -- tour proche infructueux : disque élargi dès le tour suivant
            Trace.log("prospect", f.key, "wide")
          else
            f.prospect_idle_until = tick + IDLE_TICKS
          end
        end
        f.prospect_found = 0
      end
      if not f.is_player then Sites.next_front(f, tick) end
      return
    end
    f[cursor] = k + 1
    local o = OFFSETS[k]
    local cx, cy = hcx + o.dx, hcy + o.dy
    if Sites.seen_filter and not Sites.seen_filter(f, cx, cy) then
      -- Lot IA3-f : secteur jamais vu par l'équipe : sauté, sans appel moteur ni sonde comptée.
      skips = skips + 1
      if skips >= SKIPS_PER_STEP then return end
    else
      probes = probes + 1
      if probe(f, surface, cx, cy, tick, wanted, front, other_hqs, spawn, war) then
        if front then
          f.front_found = (f.front_found or 0) + 1
        else
          f.prospect_found = (f.prospect_found or 0) + 1
        end
        wanted = wanted_resources(f)
        if #wanted == 0 or #f.prospects >= max_prospects(f) then return end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Recensement COMPLET d'un gisement (lot CAPIB, préalable bloquant du branchement de la capitalisation : la sonde
-- ci-dessus ne lit que 64 tuiles d'un chunk, un gisement y paraissait couvert après 4 foreuses électriques)
---------------------------------------------------------------------------------------------------
-- Composante connexe (8 voisins) des entités de ressource `name` qui contient la tuile de ce minerai la plus proche de
-- `pos`, lue dans un carré qui double tant que la composante en touche le bord (Sites.CENSUS_HALF, au plus
-- Sites.CENSUS_MAX). Rend { tiles, amount, x0, y0, x1, y1, cx, cy, id, cut } (cut : composante tronquée au carré
-- maximal ou à Sites.CENSUS_TILES) ou nil (aucune tuile). Coût : un find_entities_filtered par carré, puis un parcours en
-- largeur (8 lectures par tuile) ; mesuré au profileur (clé « sites:census »). Ordre : celui des listes du moteur, puis
-- une file ; aucun pairs.
Sites.CENSUS_HALF = 48
Sites.CENSUS_MAX = 192
Sites.CENSUS_TILES = 6000
local OFF = 1048576 -- 2^20 : clé numérique d'une tuile (x + OFF) * 2^21 + (y + OFF)
local function tkey(x, y) return (x + OFF) * 2097152 + (y + OFF) end
local N8 = { { -1, -1 }, { 0, -1 }, { 1, -1 }, { -1, 0 }, { 1, 0 }, { -1, 1 }, { 0, 1 }, { 1, 1 } }

function Sites.census(surface, name, pos)
  Profiler.start("sites:census")
  local half = Sites.CENSUS_HALF
  local out = nil
  while true do
    local ents = surface.find_entities_filtered({ area = { { pos.x - half, pos.y - half }, { pos.x + half, pos.y + half } },
      name = name })
    local idx = {}
    local seed, sd = nil, nil
    for _, e in ipairs(ents) do
      local p = e.position
      local x, y = math.floor(p.x), math.floor(p.y)
      local k = tkey(x, y)
      idx[k] = e.amount or 0
      local dx, dy = x + 0.5 - pos.x, y + 0.5 - pos.y
      local d = dx * dx + dy * dy
      if sd == nil or d < sd or (d == sd and k < seed[3]) then seed, sd = { x, y, k }, d end
    end
    if not seed then break end
    local qx, qy = { seed[1] }, { seed[2] }
    local seen = { [seed[3]] = true }
    local head, n, amount = 1, 0, 0
    local x0, y0, x1, y1 = seed[1], seed[2], seed[1], seed[2]
    local sx, sy = 0, 0
    local cut = false
    while head <= #qx do
      local x, y = qx[head], qy[head]
      head = head + 1
      n = n + 1
      amount = amount + (idx[tkey(x, y)] or 0)
      sx, sy = sx + x, sy + y
      if x < x0 then x0 = x end
      if x > x1 then x1 = x end
      if y < y0 then y0 = y end
      if y > y1 then y1 = y end
      if n >= Sites.CENSUS_TILES then cut = true break end
      for _, d in ipairs(N8) do
        local k = tkey(x + d[1], y + d[2])
        if idx[k] and not seen[k] then
          seen[k] = true
          qx[#qx + 1], qy[#qy + 1] = x + d[1], y + d[2]
        end
      end
    end
    local touches = x0 <= pos.x - half + 1 or y0 <= pos.y - half + 1 or x1 >= pos.x + half - 2 or y1 >= pos.y + half - 2
    if touches and not cut and half < Sites.CENSUS_MAX then
      half = math.min(Sites.CENSUS_MAX, half * 2)
    else
      out = { tiles = n, amount = amount, x0 = x0, y0 = y0, x1 = x1 + 1, y1 = y1 + 1, cx = sx / n + 0.5, cy = sy / n + 0.5,
        id = name .. "@" .. x0 .. "," .. y0, cut = cut or (touches and half >= Sites.CENSUS_MAX) or nil }
      break
    end
  end
  Profiler.stop("sites:census")
  return out
end

--- Sites VALIDES de la réserve (ni revendiqués, ni injoignables : un injoignable est retenu comme bloqué) avec leur
--- verdict d'admission : liste { site, value, d_hq, ok, why, block }, `ctx` de la carte de valeur. `resource` nil : toutes.
--- Réservé aux factions (la réserve du joueur garde la règle d'avant).
local function admit(f, tick, resource)
  local war = State.war()
  local list = {}
  for _, s in ipairs(f.prospects or {}) do
    if resource == nil or s.resource == resource then
      if unreachable(war, s, tick) then
        note_blocked(f, s, s.resource, "injoignable", unreachable_until(war, s))
      elseif not claimed(war, s) then
        list[#list + 1] = { site = s }
      end
    end
  end
  local ctx = Sites.value_ctx(f, tick)
  local blocked = {}
  for _, e in ipairs(list) do
    local res = e.site.resource
    if blocked[res] == nil then blocked[res] = blocked_nearest(f, res, tick) or false end
    local comp = V.components(e.site, ctx)
    e.value, e.d_hq = comp.value, comp.d_hq
    local b = blocked[res] or nil
    e.ok, e.why = V.admissible({ value = comp.value, d_hq = comp.d_hq, seeded = e.site.seeded }, b and b.d or nil)
    e.block = b
  end
  return list, ctx
end

--- Trace et signal d'une passe d'admission sur une ressource : un site sous le plancher (une ligne par site), des sites
--- suspendus (une ligne par épisode, signal f.site_blocked[ressource] tant qu'il y en a), fin du blocage.
local function report(f, resource, list, tick)
  local first, n = nil, 0
  for _, e in ipairs(list) do
    if not e.ok then
      if e.why == "suspendu" then
        n = n + 1
        if not first or e.d_hq < first.d_hq then first = e end
      elseif not e.site.floor_logged then
        e.site.floor_logged = true
        f.stats.plancher = (f.stats.plancher or 0) + 1
        if (f.stats.site_block_logged or 0) < BLOCK_LOG_MAX then
          f.stats.site_block_logged = (f.stats.site_block_logged or 0) + 1
          log(string.format("[FO-SITES] plancher tick %d %s %s : (%d, %d), %d tuiles du QG, valeur %d sous le plancher %d", tick,
            f.key, resource, math.floor(e.site.x), math.floor(e.site.y), e.d_hq, e.value, V.FLOOR))
        end
      end
    end
  end
  local sig = f.site_blocked and f.site_blocked[resource]
  if first then
    local b = first.block
    f.site_blocked = f.site_blocked or {}
    if not sig or sig.x ~= b.x or sig.y ~= b.y then
      sig = { since = tick }
      f.site_blocked[resource] = sig
      f.stats.suspendu = (f.stats.suspendu or 0) + 1
      if (f.stats.site_block_logged or 0) < BLOCK_LOG_MAX then
        f.stats.site_block_logged = (f.stats.site_block_logged or 0) + 1
        log(string.format("[FO-SITES] suspendu tick %d %s %s : %d site(s) lointain(s) suspendu(s) (le plus proche a %d tuiles, valeur %d), site proche (%d, %d) a %d tuiles bloque (%s) jusqu'a %.1f min",
          tick, f.key, resource, n, first.d_hq, first.value, math.floor(b.x), math.floor(b.y), b.d, b.why, b.until_tick / 3600))
      end
    end
    sig.x, sig.y, sig.why, sig.until_tick, sig.d_blocked, sig.n = b.x, b.y, b.why, b.until_tick, b.d, n
  elseif sig then
    f.site_blocked[resource] = nil
    if (f.stats.site_block_logged or 0) < BLOCK_LOG_MAX then
      f.stats.site_block_logged = (f.stats.site_block_logged or 0) + 1
      log(string.format("[FO-SITES] debloque tick %d %s %s : plus aucun site suspendu (site proche (%d, %d) libre ou blocage fini)",
        tick, f.key, resource, math.floor(sig.x), math.floor(sig.y)))
    end
  end
end

--- Nombre de sites en réserve pour une ressource (toutes si nil). Pour une FACTION et une ressource : les seuls sites
--- ADMISSIBLES (lot SITE-PROCHE, valeur au moins V.FLOOR, non suspendus), et en second résultat la distance au QG du plus
--- proche d'entre eux (nil sans site : lue par shared/ai3/projets.lua, R1). L'équipe du joueur : compte brut, sans distance.
function Sites.available(f, resource, tick)
  if not resource then return f.prospects and #f.prospects or 0 end
  if f.is_player or not f.hq_pos then return prospects_of(f, resource) end
  tick = tick or game.tick
  local list = {}
  if prospects_of(f, resource) > 0 then list = admit(f, tick, resource) end
  report(f, resource, list, tick)
  local n, near = 0, nil
  for _, e in ipairs(list) do
    if e.ok then
      n = n + 1
      if not near or e.d_hq < near then near = e.d_hq end
    end
  end
  return n, near
end

---------------------------------------------------------------------------------------------------
-- Carte de valeur (lot IA2-b) : contexte vu par la faction
---------------------------------------------------------------------------------------------------
-- Champs de vision (mêmes rayons que le chef d'IA2-a, script/faction/chef.lua) : QG, avant-postes, groupes en route.
local VISION_HQ, VISION_OUTPOST, VISION_GROUP = 160, 128, 96
local LOST_KEEP = 8 -- sites perdus retenus (danger)

local function eyes(f)
  local list = {}
  if f.hq_pos then list[#list + 1] = { x = f.hq_pos.x, y = f.hq_pos.y, r2 = VISION_HQ * VISION_HQ } end
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local p = f.outposts[oid].pos
    list[#list + 1] = { x = p.x, y = p.y, r2 = VISION_OUTPOST * VISION_OUTPOST }
  end
  for _, gid in ipairs(State.sorted_keys(f.groups or {})) do
    local g = f.groups[gid]
    if g.group and g.group.valid then
      local p = g.group.position
      list[#list + 1] = { x = p.x, y = p.y, r2 = VISION_GROUP * VISION_GROUP }
    end
  end
  return list
end

local function seen_by(list, p)
  for _, e in ipairs(list) do
    local dx, dy = e.x - p.x, e.y - p.y
    if dx * dx + dy * dy <= e.r2 then return true end
  end
  return false
end

--- Contexte de la carte de valeur d'une faction (pur ensuite) : territoire (QG et avant-postes), rivales VUES (QG
--- connus, avant-postes dans nos champs de vision : brouillard D-16), nos sites perdus récents, traits, appétit du chef.
function Sites.value_ctx(f, tick)
  local ctx = { hq = f.hq_pos, anchors = {}, rivals = {}, lost = f.lost_sites or {}, tick = tick,
    ambition = 1000, prudence = 1000, appetite = 1000 }
  if f.hq_pos then ctx.anchors[1] = { x = f.hq_pos.x, y = f.hq_pos.y } end
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local p = f.outposts[oid].pos
    ctx.anchors[#ctx.anchors + 1] = { x = p.x, y = p.y }
  end
  if f.traits then ctx.ambition, ctx.prudence = f.traits.ambition or 1000, f.traits.prudence or 1000 end
  if f.chef then ctx.appetite = V.appetite(f.chef.mix, f.chef.survival) end
  if not f.is_player then
    local my = eyes(f)
    for _, rid in ipairs(State.alive()) do
      if rid ~= f.id then
        local r = State.faction(rid)
        if r.hq_pos then ctx.rivals[#ctx.rivals + 1] = { x = r.hq_pos.x, y = r.hq_pos.y, hq = true } end
        for _, oid in ipairs(State.sorted_keys(r.outposts or {})) do
          local p = r.outposts[oid].pos
          if seen_by(my, p) then ctx.rivals[#ctx.rivals + 1] = { x = p.x, y = p.y } end
        end
      end
    end
  end
  return ctx
end

--- Un avant-poste perdu : position retenue (danger des sites voisins pendant V.LOST_TTL).
function Sites.note_lost(f, pos, tick)
  f.lost_sites = f.lost_sites or {}
  table.insert(f.lost_sites, { x = pos.x, y = pos.y, tick = tick })
  while #f.lost_sites > LOST_KEEP do table.remove(f.lost_sites, 1) end
end

--- Meilleure valeur parmi les sites valides de la réserve (toutes ressources), ou nil (lu par le chef : considération
--- « meilleur site connu » de la posture « expansion »).
function Sites.best_value(f, tick)
  local war = State.war()
  if not f.is_player and f.hq_pos then -- lot SITE-PROCHE : seuls les sites admissibles comptent
    local list, ctx = admit(f, tick, nil)
    local ok = {}
    for _, e in ipairs(list) do if e.ok then ok[#ok + 1] = e.site end end
    if #ok == 0 then return nil end
    return V.rank(ok, ctx)[1].value
  end
  local cands = {}
  for _, s in ipairs(f.prospects or {}) do
    if not claimed(war, s) and not unreachable(war, s, tick) then cands[#cands + 1] = s end
  end
  if #cands == 0 then return nil end
  local ranked = V.rank(cands, Sites.value_ctx(f, tick))
  return ranked[1].value
end

--- Lot IA2-b : une FACTION choisit par valeur parmi les sites valides de la ressource (V.choose : hasard borné entre
--- les meilleurs, flux d'expansion) ; les sites invalides de cette ressource sont retirés de la réserve.
local function find_by_value(f, tick, resource)
  local war = State.war()
  local list = f.prospects or {}
  local function valid(s) return not claimed(war, s) and not unreachable(war, s, tick) end
  -- Lot SITE-PROCHE : seuls les sites ADMISSIBLES sont puisés ; un site valide mais inadmissible (sous le plancher,
  -- suspendu) reste en réserve, un site invalide en est retiré comme avant (son blocage est retenu : admit).
  local adm, ctx = admit(f, tick, resource)
  local is_valid, cands = {}, {}
  for _, e in ipairs(adm) do
    is_valid[e.site] = true
    if e.ok then
      cands[#cands + 1] = e.site
    end
  end
  if resource ~= nil then report(f, resource, adm, tick) end
  local keep = {}
  for _, s in ipairs(list) do
    if (resource ~= nil and s.resource ~= resource) or is_valid[s] then keep[#keep + 1] = s end
  end
  if #cands == 0 then
    f.prospects = keep
    return nil
  end
  local chosen, vrank, _, ranked = V.choose(cands, ctx, draw_of(f))
  local site = chosen.site
  local out = {}
  for _, s in ipairs(keep) do if s ~= site then out[#out + 1] = s end end
  f.prospects = out
  if not note_handout(f, site, tick) then return nil end -- écarté (mémoire d'échec) : le suivant au prochain appel
  Journal.site(f, site, list, valid, tick, { value = chosen.value, rank = vrank, n = #ranked })
  return site
end

--- Puise un site valide de la ressource demandée dans la réserve. Renvoie site ou nil.
function Sites.find(f, surface, tick, resource)
  tick = tick or game.tick
  if not f.is_player then return find_by_value(f, tick, resource) end
  local war = State.war()
  local list = f.prospects or {}
  local i = 1
  local function valid(s) return not claimed(war, s) and not unreachable(war, s, tick) end
  while i <= #list do
    local site = list[i]
    if resource == nil or site.resource == resource then
      -- Lot IA2-0 : rang du site choisi par distance au QG (journal seul, métrique M1 « plus proche d'abord »).
      local ok = valid(site) and note_handout(f, site, tick)
      if ok then
        -- Lot IA2-b (journal de référence) : valeur des candidats valides de la même ressource, rang du site puisé.
        local cands = {}
        for _, s in ipairs(list) do
          if s.resource == site.resource and valid(s) then cands[#cands + 1] = s end
        end
        local ranked = V.rank(cands, Sites.value_ctx(f, tick))
        local vk, vv = 1, 0
        for k, e in ipairs(ranked) do if e.site == site then vk, vv = k, e.value end end
        Journal.site(f, site, list, valid, tick, { value = vv, rank = vk, n = #ranked })
      end
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
  if f.site_fail then f.site_fail[key] = nil end -- lot SITES : l'ouvrier a franchi tous les contrôles
  war.claims[key] = f.id
  war.claim_pos = war.claim_pos or {}
  war.claim_pos[key] = { x = pos.x, y = pos.y, resource = pos.resource, radius = pos.radius }
end

function Sites.release(pos)
  local war = State.war()
  local key = State.site_key(pos)
  war.claims[key] = nil
  if war.claim_pos then war.claim_pos[key] = nil end
end

return Sites
