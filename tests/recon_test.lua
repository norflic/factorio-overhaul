--[[
  Tests hors jeu du lot RECON : CONNAISSANCE des rivales par une faction (shared/faction/recon.lua, shared/ai3/carte.lua
  rv, shared/faction/chef.lua : cible reconnue). Pur, aucun moteur. Usage, depuis la racine du mod :
    lua5.2 tests/recon_test.lua

  Réponse du DC (28/10) : « les factions ne peuvent viser QUE ce qu'elles ont reconnu ».
  Vérifie : cible inconnue => aucune cible et reconnaissance demandée ; vue => cible possible, point visé = le point vu ;
  périmée => aucune cible, reconnaissance vers le DERNIER point connu ; reconstatée vide => oubliée ; fusion des
  sources (yeux, carte) ; plafond d'avant-postes ; éclaireur (garnison, délai, perte, menace, survie) ; carte : les
  constructions d'un secteur sont remplacées à chaque regard ; déterminisme ; puis 10 MUTANTS, tous refusés.
]]

package.path = "./?.lua;" .. package.path
local R = require("shared.faction.recon")
local C = require("shared.faction.chef")
local K = require("shared.ai3.carte")
local Tr = require("shared.faction.traits")

local passes, failures = 0, 0
local verbose = true
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if verbose then print("  ECHEC : " .. msg) end end
end
local function section(name) if verbose then print("== " .. name) end end

local HOUR = 3600
local function traits()
  local t = {}
  for _, k in ipairs(Tr.ORDER) do t[k] = 1000 end
  return t
end
local function stream(seed) return Tr.new_stream(seed, 201) end
local function drawer(st) return function(n) return Tr.range(st, 1, n) end end

local function view(tick, rivals)
  return {
    tick = tick, minutes = math.floor(tick / 3600), traits = traits(), outposts = 4, desired = 6, sites = 1,
    iron = 150, copper = 400, coal = 100, stone = 200, tech = 1, workers = 10, idle = 3, goals = 6,
    soldiers = 30, garrison = 30, army_target = 60, strength = 1, reserve = 0, unprotected = 2, threatened = false,
    soldiers_lost = 0, enemy_near = false, rivals = rivals,
  }
end

-- Toutes les vérifications dans une fonction : elle sert aussi aux mutants (un mutant doit faire échouer au moins une).
local function battery()
  ---------------------------------------------------------------------------------------------------
  section("Règles pures : connaissance d'une rivale")
  local k = R.new()
  check(not R.known(k) and R.status(k, 1000) == "inconnue" and R.last(k) == nil, "rien vu : inconnue")
  check(R.aim(k, 1000, { x = 0, y = 0 }, C.target_point) == nil, "rien vu : aucun point visé")
  R.sight(k, "post", 700, 100, 1000)
  check(R.known(k) and R.status(k, 1000 + 10 * HOUR) == "fraiche", "un avant-poste vu : connue, fraîche 10 min après")
  check(R.status(k, 1000 + R.FRESH) == "fraiche" and R.status(k, 1000 + R.FRESH + 1) == "perimee",
    "fraîche jusqu'à R.FRESH inclus, périmée ensuite")
  local a = R.aim(k, 1000 + 100, { x = 0, y = 0 }, C.target_point)
  check(a and a.x == 700 and a.y == 100, "point visé = le point VU")
  check(R.aim(k, 1000 + R.FRESH + 1, { x = 0, y = 0 }, C.target_point) == nil, "périmée : plus de point visé (à revérifier)")
  local lp = R.last_point(k)
  check(lp and lp.x == 700 and lp.y == 100, "dernier point connu gardé même périmé")
  -- Un avant-poste voisin est le même ; un lointain est un autre.
  R.sight(k, "post", 710, 105, 5000)
  check(#k.posts == 1 and k.posts[1].t == 5000, "avant-poste à moins de R.MERGE_DIST : le même, date rafraîchie")
  R.sight(k, "post", 700 + R.MERGE_DIST + 40, 100, 6000)
  check(#k.posts == 2, "avant-poste lointain : un autre")
  -- Un regard plus ancien ne rajeunit pas.
  R.sight(k, "post", 700, 100, 10)
  check(k.posts[1].t == 5000, "un regard ancien ne rajeunit pas un point")
  -- QG : le point visé préfère la périphérie (C.target_point) s'il y a des avant-postes frais.
  R.sight(k, "hq", 900, 100, 6000)
  local a2 = R.aim(k, 6100, { x = 0, y = 0 }, C.target_point)
  check(a2 ~= nil, "QG + avant-postes frais : un point visé")
  local k2 = R.new()
  R.sight(k2, "hq", 900, 100, 6000)
  local a3 = R.aim(k2, 6100, { x = 0, y = 0 }, C.target_point)
  check(a3 and a3.x == 900, "QG vu seul : il est visé")
  -- Plafond.
  local k3 = R.new()
  for i = 1, R.MAX_POSTS + 5 do R.sight(k3, "post", i * 100, 0, i) end
  check(#k3.posts == R.MAX_POSTS, "plafond de R.MAX_POSTS avant-postes")
  local oldest_gone = true
  for _, e in ipairs(k3.posts) do if e.t <= 5 then oldest_gone = false end end
  check(oldest_gone, "les plus anciens sont oubliés d'abord")
  -- Oubli : un regard postérieur sur l'emplacement ne l'a pas retrouvé.
  local k4 = R.new()
  R.sight(k4, "post", 300, 300, 100)
  R.sight(k4, "hq", 500, 500, 100)
  local n = R.prune(k4, function(e) return e.x == 300 end)
  check(n == 1 and #k4.posts == 0 and k4.hq ~= nil, "reconstatée vide : l'avant-poste est oublié, le QG reste")
  check(R.status(k4, 200) == "fraiche", "QG vu : rivale encore connue")
  R.prune(k4, function() return true end)
  check(R.status(k4, 200) == "inconnue", "tout oublié : redevient inconnue")
  -- Fusion déterministe.
  local k5, k6 = R.new(), R.new()
  local sights = { { kind = "post", x = 100, y = 0, t = 50 }, { kind = "hq", x = 400, y = 0, t = 60 }, { kind = "post", x = 105, y = 3, t = 70 } }
  R.merge(k5, sights)
  R.merge(k6, sights)
  check(#k5.posts == 1 and k5.posts[1].t == 70 and k5.hq.t == 60 and k5.posts[1].x == k6.posts[1].x, "fusion : même résultat deux fois, points voisins fondus")

  ---------------------------------------------------------------------------------------------------
  section("Cible reconnue : le chef ne vise que ce qu'il a vu")
  local base = { { id = 2, outposts_seen = 3, defense = 12, army_out = false, weak = true, dist = 700 } }
  local plain = C.rank_targets(view(1000, base), C.new(stream(1), 0))
  check(#plain == 1, "vue sans champs de connaissance : inchangée (cible possible)")
  local unknown = { { id = 2, outposts_seen = 0, defense = 8, dist = 600, known = false, stale = false, reachable = true } }
  check(#C.rank_targets(view(1000, unknown), C.new(stream(1), 0)) == 0, "rivale jamais vue : aucune cible")
  local stale = { { id = 2, outposts_seen = 0, defense = 8, dist = 700, known = true, stale = true, last = { x = 700, y = 100 } } }
  check(#C.rank_targets(view(1000, stale), C.new(stream(1), 0)) == 0, "rivale périmée : aucune cible")
  local seen = { { id = 2, outposts_seen = 1, defense = 8, dist = 700, known = true, stale = false } }
  check(#C.rank_targets(view(1000, seen), C.new(stream(1), 0)) == 1, "rivale vue et fraîche : cible possible")
  -- Reconnaissance demandée seulement s'il n'y a aucune cible.
  local st = C.new(stream(2), 0)
  local d = C.think(st, view(5000, unknown), drawer(st.stream))
  check(d.target == nil and d.recon and d.recon.id == 2 and d.recon.kind == "inconnue", "aucune cible : reconnaissance d'une rivale INCONNUE demandée")
  check(d.scores ~= nil and (function()
    for _, s in ipairs(d.scores) do if (s.key == "assaut" or s.key == "raids") and s.score ~= 0 then return false end end
    return true
  end)(), "sans cible reconnue, ni assaut ni raid")
  local st2 = C.new(stream(2), 0)
  local d2 = C.think(st2, view(5000, stale), drawer(st2.stream))
  check(d2.target == nil and d2.recon and d2.recon.kind == "perimee" and d2.recon.x == 700 and d2.recon.y == 100,
    "périmée : reconnaissance vers le DERNIER point connu")
  local st3 = C.new(stream(2), 0)
  local d3 = C.think(st3, view(5000, seen), drawer(st3.stream))
  check(d3.target == 2 and d3.recon == nil, "rivale vue : cible, aucune reconnaissance")
  -- Plusieurs rivales : la rancune puis la périmée d'abord, puis le numéro.
  local multi = {
    { id = 2, known = false, stale = false, dist = 600 }, { id = 3, known = true, stale = true, last = { x = 1, y = 2 }, dist = 600 },
    { id = 4, known = false, stale = false, dist = 600 },
  }
  local st4 = C.new(stream(3), 0)
  check(C.recon_pick(view(0, multi), st4).id == 3, "périmée avant inconnue")
  st4.grudge[4] = 500
  check(C.recon_pick(view(0, multi), st4).id == 4, "la rancune passe avant")
  local one_ok = { { id = 2, known = true, stale = false, dist = 600 }, { id = 3, known = false, dist = 600 } }
  check(C.recon_pick(view(0, one_ok), C.new(stream(3), 0)).id == 3, "une rivale inconnue reste à chercher même si une autre est connue")
  check(C.recon_pick(view(0, { { id = 2, known = false, reachable = false } }), C.new(stream(3), 0)) == nil, "rivale injoignable : rien à chercher")
  -- Reconnaissance régulière : une rivale fraîche mais vieillissante est revérifiée avant l'assaut, même quand elle EST la cible.
  local aged = { { id = 2, outposts_seen = 1, defense = 8, dist = 700, known = true, stale = false, aging = true, last = { x = 5, y = 6 } } }
  local pa = C.recon_pick(view(0, aged), C.new(stream(3), 0))
  check(pa and pa.id == 2 and pa.kind == "vieillissante" and pa.x == 5 and pa.y == 6, "vieillissante : revérification vers son dernier point")
  local sta = C.new(stream(2), 0)
  local da = C.think(sta, view(5000, aged), drawer(sta.stream))
  check(da.target == 2 and da.recon and da.recon.kind == "vieillissante", "cible reconnue ET vieillissante : cible gardée, revérification demandée en même temps")
  local mix = { { id = 2, known = true, stale = false, aging = true, dist = 600 }, { id = 3, known = false, dist = 600 }, { id = 4, known = true, stale = true, dist = 600, last = { x = 1, y = 1 } } }
  check(C.recon_pick(view(0, mix), C.new(stream(3), 0)).id == 4, "périmée avant inconnue")
  table.remove(mix, 3)
  check(C.recon_pick(view(0, mix), C.new(stream(3), 0)).id == 3, "inconnue avant vieillissante")

  ---------------------------------------------------------------------------------------------------
  section("Éclaireur : garnison, délai, pertes, menace, survie")
  local req = { id = 2, kind = "inconnue" }
  local function want(o)
    local c = { recon = req, tick = 10000, next_at = 0, busy = false, garrison = 20, size = 1, threat = 0, survive = false }
    for kk, vv in pairs(o or {}) do c[kk] = vv end
    return (R.want(c))
  end
  check(want(), "garnison suffisante : il part")
  check(not want({ recon = false }), "rien à chercher : il ne part pas")
  check(not want({ busy = true }), "un éclaireur à la fois")
  check(not want({ garrison = R.RESERVE }), "garnison trop petite : il ne part pas")
  check(not want({ garrison = 1 + R.RESERVE }) and not want({ garrison = R.START_ARMY }), "sous l'armée de départ : il ne part pas")
  check(want({ garrison = 1 + R.START_ARMY }), "garnison juste suffisante : armée de départ gardée, éclaireur retiré")
  check(not want({ garrison = R.START_ARMY + 2, size = 3 }) and want({ garrison = R.START_ARMY + 3, size = 3 }),
    "une patrouille de 3 exige 3 soldats de plus")
  check(not want({ hq_ok = false }) and want({ hq_ok = true }), "tourelles du QG incomplètes : défense du début d'abord")
  check(not want({ enemies = true }), "ennemis vus près du QG : il ne part pas")
  check(not want({ quiet_until = 10001 }) and want({ quiet_until = 10000 }), "soldat mort depuis moins de 5 min : il ne part pas")
  check(not want({ next_at = 20000 }), "délai non écoulé")
  check(not want({ threat = R.THREAT_MAX + 1 }), "menace : la garnison reste au QG")
  check(not want({ survive = true }), "survie : la garnison reste au QG")
  check(R.size(0) == 1 and R.size(1) == 2 and R.size(2) == 3 and R.size(9) == R.SIZE_MAX and R.SIZE_MAX == 3,
    "taille : 1, +1 par perte, 3 au plus (plafond contre l'appauvrissement de la garnison, constat des sceptiques)")
  check(R.size(9, 5) == 1 and R.size(9, 8) == 2 and R.size(9, 12) == 3 and R.size(0, 2) == 1,
    "taille : jamais plus de 25 % de la garnison (au moins 1)")
  check(want({ garrison = 40, size = 1, keep = 40 }) == false and want({ garrison = 40, size = 1, keep = 20 }),
    "garnison gardée du caractère : l'éclaireur ne la fait jamais passer sous son plancher")
  check(not want({ alert = true }), "QG en alerte : la garnison reste au QG")
  -- Reconnaissance régulière : balayage selon la curiosité, la menace et les pertes.
  check(R.sweep_gap(2000, 0, 0) < R.sweep_gap(1000, 0, 0) and R.sweep_gap(500, 0, 0) > R.sweep_gap(1000, 0, 0),
    "plus curieuse, elle balaie plus souvent")
  check(R.sweep_gap(1000, 300, 0) > R.sweep_gap(1000, 0, 0), "la menace allonge le délai du balayage")
  check(R.sweep_gap(1000, 0, 1) == 2 * R.sweep_gap(1000, 0, 0), "délai de balayage doublé par perte")
  check(R.sweep_gap(1000, 0, 99) == R.sweep_gap(1000, 0, R.LOSS_CAP) and R.sweep_gap(2000, 0, 0) >= R.SWEEP_MIN, "balayage : borné")
  check(R.range(2000) > R.range(1000) and R.range(500) < R.range(1000), "plus curieuse, elle va plus loin")
  local so = R.standoff({ x = 0, y = 0 }, { x = 400, y = 0 })
  check(math.abs(so.x - (400 - R.STANDOFF)) < 1e-9 and so.y == 0, "revérification : à R.STANDOFF tuiles du point connu, côté QG")
  local near = R.standoff({ x = 0, y = 0 }, { x = 50, y = 0 })
  check(near.x == 50 and near.y == 0, "revérification : point plus proche que R.STANDOFF : le point lui-même")
  local kf = { hq = { x = 0, y = 0, t = 1000 }, posts = {} }
  check(not R.aging(kf, 1000 + R.AGING) and R.aging(kf, 1000 + R.AGING + 1) and R.aging(kf, 1000 + R.FRESH)
    and not R.aging(kf, 1000 + R.FRESH + 1) and not R.aging(nil, 5) and not R.aging(R.new(), 5), "vieillissante : entre R.AGING et R.FRESH")
  check(R.gap(1000, 1) == 2 * R.gap(1000, 0) and R.gap(1000, 2) == 4 * R.gap(1000, 0), "délai doublé à chaque perte (F235)")
  check(R.gap(2000, 0) < R.gap(1000, 0) and R.gap(500, 0) > R.gap(1000, 0), "plus agressif : plus souvent")
  check(R.gap(1000, 99) == R.gap(1000, R.LOSS_CAP), "doublement borné")

  ---------------------------------------------------------------------------------------------------
  section("Carte de connaissance : constructions de factions vues")
  local m = K.new()
  local key = K.key_of(100, 100)
  K.record(m, key, 1000, { rv = {
    { id = 3, kind = "post", x = 120, y = 90 }, { id = 2, kind = "hq", x = 100, y = 100 }, { id = 2, kind = "post", x = 90, y = 80 } } })
  local s2 = K.rival_sightings(m, 2)
  check(#s2 == 2 and s2[1].kind == "hq" and s2[1].t == 1000 and s2[2].kind == "post", "constructions de la faction 2 : triées, datées du regard")
  check(#K.rival_sightings(m, 3) == 1 and #K.rival_sightings(m, 9) == 0, "chaque faction ne voit que ses sightings")
  check(#K.rival_hqs(m) == 1, "QG vus")
  K.record(m, key, 2000, { rv = { { id = 3, kind = "post", x = 120, y = 90 } } })
  check(#K.rival_sightings(m, 2) == 0 and #K.rival_hqs(m) == 0, "secteur regardé de nouveau sans la construction : oubliée")
  K.record(m, key, 3000, {})
  check(#K.rival_sightings(m, 3) == 0, "secteur regardé vide : plus rien")
  -- Oubli de bout en bout : carte regardée plus tard sans la construction => R.prune la retire.
  local kn = R.new()
  K.record(m, key, 4000, { rv = { { id = 2, kind = "post", x = 90, y = 80 } } })
  R.merge(kn, K.rival_sightings(m, 2))
  check(#kn.posts == 1 and kn.posts[1].t == 4000, "regard de la carte -> connaissance")
  K.record(m, key, 9000, {})
  R.merge(kn, K.rival_sightings(m, 2))
  R.prune(kn, function(e) local t = K.seen_xy(m, e.x, e.y); return t ~= nil and t > e.t end)
  check(#kn.posts == 0, "secteur regardé plus tard sans la construction : oubliée de la connaissance")
  -- Plafond par secteur.
  local rvs = {}
  for i = 1, K.RV_KEEP + 10 do rvs[#rvs + 1] = { id = 2, kind = "post", x = 100 + (i % 50), y = 100 + math.floor(i / 50) } end
  K.record(m, key, 10000, { rv = rvs })
  check(#m.s[key].rv == K.RV_KEEP, "plafond de constructions retenues par secteur")
  local m2 = K.new()
  K.record(m2, key, 10000, { rv = rvs })
  local same = true
  for i, e in ipairs(m.s[key].rv) do
    local o = m2.s[key].rv[i]
    if o.x ~= e.x or o.y ~= e.y then same = false end
  end
  check(same, "même regard, même carte (déterminisme)")
  -- Anneau : les QG des factions sont à la même distance du départ que le nôtre.
  local ring = { x = 0, y = 0, r = 500 }
  check(K.ring_prior(ring, 500, 0) == 2000 and K.ring_prior(ring, 0, -500) == 2000, "sur l'anneau : 2 000")
  check(K.ring_prior(ring, 0, 0) == 500 and K.ring_prior(ring, 2000, 0) == 500, "loin de l'anneau : 500")
  check(K.ring_prior(ring, 400, 0) > K.ring_prior(ring, 300, 0) and K.ring_prior(ring, 300, 0) > K.ring_prior(ring, 100, 0),
    "plus près de l'anneau, plus probable")
  local ringh = { x = 0, y = 0, r = 500, hq = { x = 500, y = 0 } }
  check(K.ring_prior(ringh, 520, 20) == math.floor(K.ring_prior(ring, 520, 20) / 4), "sur l'anneau mais à côté de NOTRE QG : un quart")
  check(K.ring_prior(ringh, -500, 0) == 2000 and K.ring_prior(ringh, 0, 500) == 2000, "sur l'anneau, loin de notre QG : 2 000")
  local m3 = K.new()
  -- Deux secteurs vus côte à côte ; la frontière offre un secteur sur l'anneau (vers l'est) et un hors anneau (vers le centre).
  for _, kk in ipairs({ { 7, 0 }, { 8, 0 }, { 8, 1 } }) do K.record(m3, K.key(kk[1], kk[2]), 100, {}) end
  local flat = K.best_target(m3, { hq = { x = 512, y = 32 }, me = { x = 512, y = 32 }, tick = 200, spawn = { x = 0, y = 0 } })
  local ringed = K.best_target(m3, { hq = { x = 512, y = 32 }, me = { x = 512, y = 32 }, tick = 200, spawn = { x = 0, y = 0 },
    ring = { x = 0, y = 0, r = 512 } })
  local rx, ry = K.xy(ringed)
  local cx, cy = K.center(rx, ry)
  check(flat ~= nil and ringed ~= nil and math.abs(math.sqrt(cx * cx + cy * cy) - 512) < 120,
    "a priori d'anneau : la frontière choisie est près de l'anneau")
  -- Recherche d'une rivale : n'importe quel secteur non vu de l'anneau déjà généré, pas à côté de notre QG.
  local ms = K.new()
  local hq = { x = 512, y = 32 }
  for _, kk in ipairs({ { 7, 0 }, { 8, 0 }, { 8, 1 }, { 9, 0 } }) do K.record(ms, K.key(kk[1], kk[2]), 100, {}) end
  local rings = { x = 0, y = 0, r = 512, hq = hq }
  local function dist(a, b) return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2) end
  local sk = K.search_target(ms, { hq = hq, tick = 200, rivals = {}, ring = rings })
  local sx, sy = K.xy(sk)
  local scx, scy = K.center(sx, sy)
  check(sk ~= nil and ms.s[sk] == nil, "recherche : un secteur NON vu")
  check(math.abs(dist({ scx, scy }, { 0, 0 }) - 512) <= K.RING_FAR, "recherche : sur l'anneau (à K.RING_FAR près)")
  check(dist({ scx, scy }, { hq.x, hq.y }) >= 0.6 * 512 - 64, "recherche : pas à côté de notre QG")
  local sk2 = K.search_target(ms, { hq = hq, tick = 200, rivals = {}, ring = rings, exclude = { [sk] = true } })
  check(sk2 ~= nil and sk2 ~= sk, "recherche : un secteur exclu n'est pas choisi")
  local calls = 0
  local sk3 = K.search_target(ms, { hq = hq, tick = 200, rivals = {}, ring = rings, generated = function(kk) calls = calls + 1; return kk ~= sk end })
  check(sk3 ~= nil and sk3 ~= sk and calls >= 1, "recherche : un secteur non généré n'est pas choisi")
  check(K.search_target(ms, { hq = hq, tick = 200, rivals = {}, ring = rings, generated = function() return false end }) == nil,
    "recherche : rien de généré, rien à viser (repli sur la frontière)")
  check(K.search_target(ms, { hq = hq, tick = 200, rivals = {}, ring = rings, max_dist = 30 }) == nil, "recherche : portée bornée")
  -- Trajet dégagé : ni construction de faction vue près du segment, ni nid vu.
  local mp = K.new()
  K.record(mp, K.key(0, 0), 100, { rv = { { id = 2, kind = "hq", x = 300, y = 10 } } })
  K.record(mp, K.key(10, 10), 100, { nests = { { x = 650, y = 650 } } })
  check(not K.path_clear(mp, { x = 0, y = 0 }, { x = 600, y = 0 }), "trajet : une construction de faction à 10 tuiles du segment le ferme")
  check(K.path_clear(mp, { x = 0, y = 0 }, { x = 0, y = 600 }), "trajet : loin de tout ennemi vu, il est dégagé")
  check(not K.path_clear(mp, { x = 0, y = 0 }, { x = 700, y = 700 }), "trajet : un nid vu sur la route le ferme")
  local blocked = K.search_target(ms, { hq = hq, tick = 200, rivals = {}, ring = rings, path_ok = function() return false end })
  check(blocked == nil, "recherche : aucun trajet dégagé, aucun but")
  local far = K.search_target(ms, { hq = hq, tick = 200, rivals = {}, ring = rings })
  check(far == sk, "recherche : déterministe")
  -- Un saut direct vers la rivale, là où la frontière avançait d'un secteur par départ : le but est à plus de 300 tuiles du QG.
  check(dist({ scx, scy }, { hq.x, hq.y }) > 250, "recherche : un saut de plus de 250 tuiles (la frontière : 1 secteur)")
end

local function run(label)
  passes, failures = 0, 0
  battery()
  return passes, failures
end

verbose = true
local p, f = run("réel")
local real_fail = f
print(string.format("[RECON] %d OK, %d ECHEC(S) (règles réelles)", p, f))

---------------------------------------------------------------------------------------------------
-- MUTANTS : chaque règle abîmée doit faire échouer au moins une vérification.
---------------------------------------------------------------------------------------------------
print("== Mutants")
verbose = false
local mutants = {}
local function mutant(name, apply)
  mutants[#mutants + 1] = { name = name, apply = apply }
end

mutant("rank_targets ignore known", function()
  local orig = C.rank_targets
  C.rank_targets = function(v, st)
    local rv = {}
    for i, r in ipairs(v.rivals) do
      local c = {}
      for kk, vv in pairs(r) do c[kk] = vv end
      c.known = nil
      rv[i] = c
    end
    local v2 = {}
    for kk, vv in pairs(v) do v2[kk] = vv end
    v2.rivals = rv
    return orig(v2, st)
  end
  return function() C.rank_targets = orig end
end)
mutant("rank_targets ignore stale", function()
  local orig = C.rank_targets
  C.rank_targets = function(v, st)
    local rv = {}
    for i, r in ipairs(v.rivals) do
      local c = {}
      for kk, vv in pairs(r) do c[kk] = vv end
      c.stale = nil
      rv[i] = c
    end
    local v2 = {}
    for kk, vv in pairs(v) do v2[kk] = vv end
    v2.rivals = rv
    return orig(v2, st)
  end
  return function() C.rank_targets = orig end
end)
mutant("R.status ignore R.FRESH", function()
  local orig = R.status
  R.status = function(k, tick) local s = orig(k, tick); return s == "perimee" and "fraiche" or s end
  return function() R.status = orig end
end)
mutant("R.aim vise un point périmé", function()
  local orig = R.aim
  R.aim = function(k, tick, from, fn) return orig(k, 0, from, fn) end
  return function() R.aim = orig end
end)
mutant("R.prune ne retire rien", function()
  local orig = R.prune
  R.prune = function() return 0 end
  return function() R.prune = orig end
end)
mutant("R.sight ne fond pas les avant-postes voisins", function()
  local orig = R.MERGE_DIST
  R.MERGE_DIST = 0
  return function() R.MERGE_DIST = orig end
end)
mutant("R.want ignore la garnison", function()
  local orig = R.want
  R.want = function(c)
    local c2 = {}
    for kk, vv in pairs(c) do c2[kk] = vv end
    c2.garrison = 1000
    return orig(c2)
  end
  return function() R.want = orig end
end)
mutant("R.gap ne double pas après une perte", function()
  local orig = R.gap
  R.gap = function(a, losses) return orig(a, 0) end
  return function() R.gap = orig end
end)
mutant("recon_pick préfère l'inconnue à la périmée", function()
  local orig = C.recon_pick
  C.recon_pick = function(v, st)
    local rv = {}
    for _, r in ipairs(v.rivals) do if r.known == false then rv[#rv + 1] = r end end
    if #rv == 0 then return orig(v, st) end
    local v2 = {}
    for kk, vv in pairs(v) do v2[kk] = vv end
    v2.rivals = rv
    return orig(v2, st)
  end
  return function() C.recon_pick = orig end
end)
mutant("K.rival_sightings rend toutes les factions", function()
  local orig = K.rival_sightings
  K.rival_sightings = function(m, rid)
    local out = {}
    for _, id in ipairs({ 2, 3 }) do
      for _, e in ipairs(orig(m, id)) do out[#out + 1] = e end
    end
    return out
  end
  return function() K.rival_sightings = orig end
end)
mutant("K.record garde les constructions d'un regard à l'autre", function()
  local orig = K.record
  K.record = function(m, key, tick, obs)
    local prev = m.s[key] and m.s[key].rv
    local fresh = orig(m, key, tick, obs)
    if prev and not (obs.rv and #obs.rv > 0) then m.s[key].rv = prev end
    return fresh
  end
  return function() K.record = orig end
end)

mutant("R.size sans plafond de part de la garnison", function()
  local orig = R.size
  R.size = function(losses) return orig(losses) end
  return function() R.size = orig end
end)
mutant("R.want ignore la garnison gardée", function()
  local orig = R.want
  R.want = function(c)
    local c2 = {}
    for kk, vv in pairs(c) do c2[kk] = vv end
    c2.keep = 0
    return orig(c2)
  end
  return function() R.want = orig end
end)
mutant("R.want ignore l'armée de départ", function()
  local orig = R.want
  R.want = function(c)
    local c2 = {}
    for kk, vv in pairs(c) do c2[kk] = vv end
    c2.garrison = (c.garrison or 0) + R.START_ARMY
    return orig(c2)
  end
  return function() R.want = orig end
end)
mutant("R.want ignore les tourelles du QG, les ennemis et les pertes récentes", function()
  local orig = R.want
  R.want = function(c)
    local c2 = {}
    for kk, vv in pairs(c) do c2[kk] = vv end
    c2.hq_ok, c2.enemies, c2.quiet_until = true, false, 0
    return orig(c2)
  end
  return function() R.want = orig end
end)
mutant("R.want ignore l'alerte", function()
  local orig = R.want
  R.want = function(c)
    local c2 = {}
    for kk, vv in pairs(c) do c2[kk] = vv end
    c2.alert = false
    return orig(c2)
  end
  return function() R.want = orig end
end)
mutant("R.sweep_gap ignore la menace", function()
  local orig = R.sweep_gap
  R.sweep_gap = function(cur, threat, losses) return orig(cur, 0, losses) end
  return function() R.sweep_gap = orig end
end)
mutant("R.aging toujours faux", function()
  local orig = R.aging
  R.aging = function() return false end
  return function() R.aging = orig end
end)
mutant("K.ring_prior sans décote près de notre QG", function()
  local orig = K.ring_prior
  K.ring_prior = function(ring, cx, cy)
    return orig({ x = ring.x, y = ring.y, r = ring.r }, cx, cy)
  end
  return function() K.ring_prior = orig end
end)

mutant("K.search_target ignore la génération", function()
  local orig = K.search_target
  K.search_target = function(m, ctx)
    local c2 = {}
    for kk, vv in pairs(ctx) do c2[kk] = vv end
    c2.generated = nil
    return orig(m, c2)
  end
  return function() K.search_target = orig end
end)
mutant("K.search_target ignore les exclusions", function()
  local orig = K.search_target
  K.search_target = function(m, ctx)
    local c2 = {}
    for kk, vv in pairs(ctx) do c2[kk] = vv end
    c2.exclude = nil
    return orig(m, c2)
  end
  return function() K.search_target = orig end
end)

mutant("K.path_clear ne voit pas les constructions de faction", function()
  local orig = K.path_clear
  K.path_clear = function(m, a, b)
    local saved = {}
    for kk, s in pairs(m.s) do saved[kk] = s.rv; s.rv = nil end
    local r = orig(m, a, b)
    for kk, rv in pairs(saved) do m.s[kk].rv = rv end
    return r
  end
  return function() K.path_clear = orig end
end)

local survivors = 0
for _, mu in ipairs(mutants) do
  local undo = mu.apply()
  local ok, pf, ff = pcall(run, mu.name)
  undo()
  local caught = (not ok) or ff > 0
  if not caught then survivors = survivors + 1 end
  print(string.format("  mutant %-52s : %s", mu.name, caught and "refusé" or "SURVIT"))
end
verbose = true
local pm, fm = run("réel après mutants")
print(string.format("[RECON] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés ; règles réelles rejouées : %d ECHEC(S)",
  p, real_fail + survivors, #mutants - survivors, #mutants, fm))
os.exit((real_fail + survivors + fm) == 0 and 0 or 1)
