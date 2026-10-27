--[[
  Lot IA3-k : bancs HORS JEU des règles pures (docs/IA3K_COMPORTEMENTS.md) :
    - carte du danger (shared/ai3/danger.lua) : marques, portées, décroissances, morts de l'heure, oubli d'un nid
      nettoyé, bornes, porte des tâches (C5, C6) ;
    - itinéraire (shared/ai3/route.lua) : variation par tournée (C1 : écart ≥ 4 tuiles dans ≥ 50 % des paires,
      allongement ≤ 15 %), détour d'un ver (jamais à sa portée, C2), blocage, déterminisme, bornes ;
    - réaction (shared/ai3/reaction.lua) : peur (C3 : sous 40 %, un prudent plus tôt qu'un audacieux), détour,
      demi-tour, arrêt, combat en surnombre (C4) ;
    - MUTANTS : chaque règle retirée fait échouer au moins un contrôle.
  Lancement : lua5.2 tests/ia3k_regles_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local D = require("shared.ai3.danger")
local R = require("shared.ai3.route")
local Re = require("shared.ai3.reaction")
local Tr = require("shared.faction.traits")

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
end
local function section(name) if not quiet then print("== " .. name) end end

local MIN = 3600

local function stream_draw(seed, salt)
  local st = Tr.new_stream(seed, salt)
  return function(n) return Tr.range(st, 1, n) end
end

local function min_dist(samples, x, y)
  local m = 1e9
  for _, s in ipairs(samples) do
    local d = R.dist(s.x, s.y, x, y)
    if d < m then m = d end
  end
  return m
end

local function suite()
  ---------------------------------------------------------------------------------------------------
  section("danger : marques et portées")
  local m = D.new()
  check(D.mark_seen(m, 100, 100, "worm", 30, 0) == true, "ver inconnu : nouveau")
  check(D.mark_seen(m, 101, 100, "worm", 30, 60) == false, "même ver revu : pas nouveau, date rafraîchie")
  check(#m.threats == 1 and m.threats[1].t == 60, "une seule menace, revue au tick 60")
  local f = D.field(m, 60)
  check((f[D.key(D.cell(100), D.cell(100))] or 0) == 1000, "case du ver : 1 000")
  check((f[D.key(D.cell(100 + 30), D.cell(100))] or 0) == 1000, "case à 30 tuiles (portée) : 1 000")
  check((f[D.key(D.cell(100 + 60), D.cell(100))] or 0) == 0, "case à 60 tuiles : 0")
  check(D.danger_at(m, 100, 100, 60 + 30 * MIN) == math.floor(1000 * D.DEC2[30] / 1000), "ver après 30 min : 2 % par minute")
  check(D.DEC2[30] >= 530 and D.DEC2[30] <= 560, "0,98^30 ≈ 545 (" .. D.DEC2[30] .. ")")

  local mu = D.new()
  D.mark_seen(mu, 0, 0, "unit", 16, 0)
  check(D.danger_at(mu, 0, 0, 0) == 150, "unité vue : 150")
  check(D.danger_at(mu, 0, 0, 10 * MIN) == math.floor(150 * D.DEC10[10] / 1000), "unité après 10 min : 10 % par minute")
  check(D.DEC10[10] >= 340 and D.DEC10[10] <= 350, "0,9^10 ≈ 349 (" .. D.DEC10[10] .. ")")
  for _ = 1, 10 do D.mark_seen(mu, 0, 0, "unit", 16, 0) end
  check(D.danger_at(mu, 0, 0, 0) == D.MOBILE_CAP, "unités cumulées plafonnées à " .. D.MOBILE_CAP)
  D.mark_attack(mu, 200, 200, 0)
  check(D.danger_at(mu, 200, 200, 0) == D.ATTACK_W, "attaque subie : 300")

  section("danger géométrique (porte, itinéraire de secours)")
  local mg = D.new()
  D.mark_seen(mg, 0, 0, "worm", 30, 0)
  D.mark_death(mg, 100, 0, 0)
  check(D.danger_exact(mg, 33, 0, 0) == 1000, "à 33 tuiles d'un ver de 30 (portée + 4) : 1 000")
  check(D.danger_exact(mg, 35, 0, 0) == 0, "à 35 tuiles : 0 (la case, elle, est marquée)")
  check(D.danger_at(mg, 35, 0, 0) > 0, "la case de ce point est bien marquée (surestimation des cases)")
  check(D.danger_exact(mg, 120, 0, 0) == D.DEATH_W and D.danger_exact(mg, 126, 0, 0) == 0, "mort : 600 à 20 tuiles, 0 à 26")

  section("danger : meute (zone d'un groupe d'unités, décroissance rapide)")
  local mp = D.new()
  check(D.mark_seen(mp, 0, 0, "pack", 36, 0) == true, "meute nouvelle")
  check(D.mark_seen(mp, 8, 0, "pack", 40, 60) == false and mp.threats[1].x == 8 and mp.threats[1].r == 40,
    "meute revue à 8 tuiles : la même, déplacée, portée suivie")
  check(D.danger_at(mp, 8, 0, 60) == 800, "meute : 800 (bloquante)")
  check(D.danger_at(mp, 8, 0, 60 + 10 * MIN) == math.floor(800 * D.DEC10[10] / 1000), "meute : 10 % par minute")
  D.prune(mp, 60 + 30 * MIN)
  check(#mp.threats == 0, "meute oubliée après 30 min (sous 50)")
  check(D.forget_unseen(D.new(), 0, 0, 30, nil) == 0, "regard vide sans meute : rien à oublier")

  section("danger : morts (mémoire longue, règle de l'heure)")
  local md = D.new()
  D.mark_death(md, 50, 50, 0)
  check(D.danger_at(md, 50, 50, 29 * MIN) == D.DEATH_W, "mort pleine pendant 30 min")
  check(D.danger_at(md, 50, 50, 40 * MIN) < D.DEATH_W, "mort qui décroît après 30 min")
  check(D.deaths_near(md, { { x = 60, y = 50 } }, D.HOUR_R, 59 * MIN) == 1, "mort comptée dans l'heure à 10 tuiles")
  check(D.deaths_near(md, { { x = 60, y = 50 } }, D.HOUR_R, 61 * MIN) == 0, "mort hors de l'heure : plus comptée")
  check(D.deaths_near(md, { { x = 120, y = 50 } }, D.HOUR_R, MIN) == 0, "mort à 70 tuiles : pas « au même endroit »")
  D.mark_death(md, 55, 52, 10 * MIN)
  check(D.deaths_near(md, { { x = 52, y = 50 } }, D.HOUR_R, 20 * MIN) == 2, "deux morts au même endroit dans l'heure")

  local mh = D.new()
  D.mark_death(mh, 0, 0, 0, true)
  D.mark_death(mh, 1, 1, 10, true)
  D.mark_death(mh, 2, 0, 20, true)
  check(#mh.deaths == 3 and D.deaths_near(mh, { { x = 0, y = 0 } }, D.HOUR_R, 30) == 0,
    "morts au QG (attaque du QG) : gardées, mais hors de la règle de l'heure")
  check(D.danger_at(mh, 0, 0, 30) == 0 and D.danger_exact(mh, 0, 0, 30) == 0, "morts au QG : aucun danger sur la carte")

  section("danger : nid nettoyé oublié")
  local mf = D.new()
  D.mark_seen(mf, 10, 0, "spawner", 24, 0)
  D.mark_seen(mf, 40, 0, "worm", 30, 0)
  check(D.forget_unseen(mf, 0, 0, 36, 30) == 1, "ennemi le plus proche à 30 : le nid à 10 n'est plus là")
  check(#mf.threats == 1 and mf.threats[1].k == "worm", "le ver à 40 est gardé")
  check(D.forget_unseen(mf, 0, 0, 36, nil) == 0, "regard vide de rayon 36 : le ver à 40 hors du regard, gardé")

  section("danger : bornes et seuils")
  local mb = D.new()
  for i = 1, 100 do D.mark_seen(mb, i * 10, 0, "worm", 30, i) end
  check(#mb.threats == D.MAX_THREATS, "menaces fixes bornées à " .. D.MAX_THREATS)
  check(mb.threats[1].t == 100 - D.MAX_THREATS + 1, "les plus anciennes partent d'abord")
  for i = 1, 50 do D.mark_death(mb, i, 0, i) end
  check(#mb.deaths == D.MAX_DEATHS, "morts bornées à " .. D.MAX_DEATHS)
  for i = 1, 400 do D.mark_seen(mb, i * 40, 500, "unit", 4, 0) end
  D.prune(mb, 0)
  local nc = 0
  for _ in pairs(mb.cells) do nc = nc + 1 end
  check(nc <= D.MAX_CELLS, "cases mobiles bornées à " .. D.MAX_CELLS .. " (" .. nc .. ")")
  D.prune(mb, 200 * MIN)
  nc = 0
  for _ in pairs(mb.cells) do nc = nc + 1 end
  check(nc == 0 and #mb.deaths == 0, "ménage : cases éteintes et morts hors de l'heure retirées")
  check(D.block(1000) == 600 and D.block(1250) == 480 and D.block(562) == 750 and D.block(2000) == 400,
    "seuil de blocage selon la prudence : 600, 480, 750, 400")
  -- Déterminisme du champ : ordre d'insertion indifférent.
  local a, b = D.new(), D.new()
  local pts = { { 5, 7 }, { 300, -40 }, { -90, 66 }, { 140, 140 } }
  for i = 1, #pts do D.mark_seen(a, pts[i][1], pts[i][2], "unit", 16, 0) end
  for i = #pts, 1, -1 do D.mark_seen(b, pts[i][1], pts[i][2], "unit", 16, 0) end
  local fa, fb = D.field(a, 100), D.field(b, 100)
  local same = true
  for k, v in pairs(fa) do if fb[k] ~= v then same = false end end
  for k, v in pairs(fb) do if fa[k] ~= v then same = false end end
  check(same, "champ identique pour un ordre d'insertion inverse")

  section("porte des tâches (C5, C6)")
  local B = 600
  check(D.gate({ deaths = 2 }, { B = B, escort_ok = true }) == "wait", "2 morts dans l'heure : attendre, même escorté")
  check(D.gate({ deaths = 1 }, { B = B, escort_ok = true }) == "escort", "1 mort : escorte si possible")
  check(D.gate({ deaths = 1 }, { B = B, escort_ok = false }) == "wait", "1 mort sans escorte : attendre")
  check(D.gate({ blocked = true }, { B = B, escort_ok = false }) == "wait", "trajet bloqué sans escorte : attendre")
  check(D.gate({ goal_d = 800 }, { B = B, escort_ok = true }) == "escort", "but dangereux : escorte")
  check(D.gate({ max_d = 350 }, { B = B, prudence = 1200 }) == "wait", "trajet marqué, prudent sans escorte : attendre")
  check(D.gate({ max_d = 350 }, { B = B, prudence = 700 }) == "go", "trajet marqué, audacieux : part")
  check(D.gate({ max_d = 0, far = true }, { B = B, escort_ok = true }) == "escort", "au-delà du rayon sûr : escorte (C6)")
  check(D.gate({ max_d = 0 }, { B = B, escort_ok = true }) == "go", "trajet sûr : part")

  ---------------------------------------------------------------------------------------------------
  section("itinéraire : variation par tournée (C1)")
  local S, G = { x = 0, y = 0 }, { x = 100, y = 0 }
  local draw = stream_draw(20261020, 470)
  local hs, ok_len, ok_mag, side = {}, true, true, nil
  local wide, prevp = 0, nil
  for i = 1, 200 do
    local r = R.plan(S, G, { field = {}, n = 0, draw = draw, side = side })
    hs[i], side = r.h, r.side
    if r.len > 1.15 * r.direct then ok_len = false end
    local a = math.abs(r.h)
    if a < 0.08 * 100 - 1e-9 or a > 0.18 * 100 + 1e-9 or #r.pts ~= 2 then ok_mag = false end
    -- Écart MÉDIAN entre allers successifs (même mesure que le banc ia3k-variete).
    local p = R.samples(S, r.pts, G, 2)
    if prevp and R.median_gap(S, G, prevp, p, 8) >= 4 then wide = wide + 1 end
    prevp = p
  end
  check(ok_len, "allongement de la variation ≤ 15 %")
  check(ok_mag, "deux points de passage, écart latéral entre 8 % et 18 % de la distance")
  local far_pairs = 0
  for i = 1, 199 do if math.abs(hs[i] - hs[i + 1]) >= 4 then far_pairs = far_pairs + 1 end end
  check(far_pairs >= 100, "deux tournées successives à ≥ 4 tuiles d'écart dans ≥ 50 % des cas (" .. far_pairs .. " / 199)")
  check(wide >= 110, "écart MÉDIAN ≥ 4 tuiles entre allers successifs dans ≥ 55 % des paires (" .. wide .. " / 199)")
  local rshort = R.plan({ x = 0, y = 0 }, { x = 30, y = 0 }, { field = {}, n = 0, draw = draw })
  check(#rshort.pts == 0, "pas de variation sous 40 tuiles")

  section("itinéraire : détour d'un ver sur la route (C2)")
  local mw = D.new()
  D.mark_seen(mw, 100, 0, "worm", 30, 0)
  local fw, nw = D.field(mw, 0)
  local S2, G2 = { x = 0, y = 0 }, { x = 200, y = 0 }
  local rw = R.plan(S2, G2, { field = fw, n = nw, B = 600, seed = 12345 })
  check(rw.astar and not rw.blocked, "A* : chemin trouvé autour du ver")
  local smp = R.samples(S2, rw.pts, G2, 1)
  check(min_dist(smp, 100, 0) >= 32, "le trajet ne passe jamais à portée du ver (min " ..
    string.format("%.1f", min_dist(smp, 100, 0)) .. " ≥ 32)")
  check(rw.max_d < 600, "danger maximal traversé sous le seuil (" .. rw.max_d .. ")")
  check(rw.len <= 1.6 * rw.direct, "détour raisonnable (" .. string.format("%.0f", rw.len) .. " / " .. rw.direct .. ")")
  check(rw.expand <= R.MAX_EXPAND, "développements bornés (" .. rw.expand .. ")")
  local longest, prevq = 0, S2
  for _, q in ipairs(rw.pts) do longest = math.max(longest, R.dist(prevq.x, prevq.y, q.x, q.y)); prevq = q end
  longest = math.max(longest, R.dist(prevq.x, prevq.y, G2.x, G2.y))
  check(longest <= R.SEG_MAX + 1e-6, "contournement en tronçons de 24 tuiles au plus (F300 : écart du chemin du moteur ≤ 5) : " ..
    string.format("%.1f", longest))
  local rw2 = R.plan(S2, G2, { field = D.field(mw, 0), n = nw, B = 600, seed = 12345 })
  local same_pts = #rw2.pts == #rw.pts
  for i = 1, math.min(#rw.pts, #rw2.pts) do
    if rw.pts[i].x ~= rw2.pts[i].x or rw.pts[i].y ~= rw2.pts[i].y then same_pts = false end
  end
  check(same_pts, "déterministe : même champ, même graine, mêmes points")
  local rn = R.plan(S2, G2, { field = fw, n = nw, B = 600 })
  check(rw.len <= 1.25 * rn.len, "le bruit de tournée allonge peu (" .. string.format("%.0f / %.0f", rw.len, rn.len) .. ")")
  -- Bruit de tournée : deux graines peuvent prendre deux côtés (géométrie symétrique : ver au centre d'une rangée de
  -- cases, départ et but sur la même rangée).
  local msym = D.new()
  D.mark_seen(msym, 104, 8, "worm", 29, 0) -- zone de 39 tuiles : rangées -2 à 2, symétrique autour de la rangée 0
  local fs, ns = D.field(msym, 0)
  local sides = {}
  for sd = 1, 40 do
    local r = R.plan({ x = 0, y = 8 }, { x = 200, y = 8 }, { field = fs, n = ns, B = 600, seed = sd * 7919 })
    local up = false
    for _, p in ipairs(r.pts) do if p.y < 8 then up = true end end
    sides[up and "n" or "s"] = (sides[up and "n" or "s"] or 0) + 1
  end
  check((sides.n or 0) > 0 and (sides.s or 0) > 0, "le bruit de tournée fait passer des deux côtés (" ..
    tostring(sides.n) .. " au nord, " .. tostring(sides.s) .. " au sud)")

  section("itinéraire : coins de cases et premier segment (banc final-a05e690)")
  local mc = D.new()
  D.mark_seen(mc, 2167, -50, "worm", 25, 0)
  D.mark_seen(mc, 2173, -48, "worm", 30, 0)
  local fc, nc = D.field(mc, 0)
  local pc, gcl = { x = 2125, y = -68 }, { x = 2330, y = -50 }
  local rc = R.plan(pc, gcl, { field = fc, n = nc, B = 600, seed = 12345 })
  local closest_c = 1e9
  for _, q in ipairs(R.samples(pc, rc.pts, gcl, 1)) do closest_c = math.min(closest_c, R.dist(q.x, q.y, 2173, -48)) end
  check(rc.max_d < 600, "un coin de deux cases sûres n'est pas lu dans la case marquée voisine (danger max " .. rc.max_d .. ")")
  check(closest_c >= 40, "départ hors du centre de sa case : jamais à moins de 40 tuiles du ver (" .. string.format("%.1f", closest_c) .. ")")
  local d0 = R.danger_pt({ [D.key(1, 1)] = 900 }, 16, 16)
  check(d0 == 0, "point sur un coin : la case la moins dangereuse qu'il touche")

  section("itinéraire : blocage")
  local mbk = D.new()
  for _, p in ipairs({ { 30, 0 }, { -30, 0 }, { 0, 30 }, { 0, -30 }, { 30, 30 }, { -30, -30 }, { 30, -30 }, { -30, 30 } }) do
    D.mark_seen(mbk, p[1], p[2], "worm", 30, 0)
  end
  local fb2, nb2 = D.field(mbk, 0)
  local rb = R.plan({ x = -200, y = 0 }, { x = 0, y = 0 }, { field = fb2, n = nb2, B = 600 })
  check(rb.blocked and rb.escape == nil, "but encerclé de vers, départ sûr : trajet bloqué (la porte fera attendre)")
  local rb2 = R.plan({ x = 0, y = 0 }, { x = 300, y = 0 }, { field = fb2, n = nb2, B = 1e9 })
  check(not rb2.blocked and rb2.max_d > 0, "sans seuil (escorte) : un chemin qui minimise le danger")
  -- Sortie d'une zone marquée : le PNJ à 20 tuiles d'un ver va d'abord vers la case sûre la plus proche, jamais plus près.
  local mz = D.new()
  D.mark_seen(mz, 0, 0, "worm", 30, 0)
  local fz, nz = D.field(mz, 0)
  local rz = R.plan({ x = 20, y = 4 }, { x = 300, y = 4 }, { field = fz, n = nz, B = 600 })
  local szp = R.samples({ x = 20, y = 4 }, rz.pts, { x = 300, y = 4 }, 1)
  local closest = min_dist(szp, 0, 0)
  check(rz.escape ~= nil and not rz.blocked, "dans la zone d'un ver : sortie par la case sûre la plus proche, puis itinéraire")
  check(closest >= R.dist(20, 4, 0, 0) - 2, "la sortie ne rapproche jamais du ver (au plus près " .. string.format("%.1f", closest) .. ")")

  ---------------------------------------------------------------------------------------------------
  section("réaction : peur (C3)")
  check(Re.decide({ kind = "unit", dist = 20, hp = 350, armed = true, enemies = 3, walking = true }) == "flee",
    "sous 40 % de vie, unité à portée : fuite")
  check(Re.decide({ kind = "unit", dist = 20, hp = 450, armed = true, enemies = 1, prudence = 1250, walking = true }) == "flee",
    "prudent à 45 % : fuite")
  check(Re.decide({ kind = "unit", dist = 20, hp = 450, armed = true, enemies = 1, prudence = 600, walking = true }) ~= "flee",
    "audacieux à 45 % : pas encore de fuite")
  check(Re.fear(1250) > Re.fear(1000) and Re.fear(600) == 400 and Re.fear(1000) >= 400, "un prudent a peur plus tôt ; jamais sous 40 %")
  check(Re.decide({ kind = "unit", dist = 30, hp = 1000, armed = false, walking = true }) == "flee", "sans munitions : fuite")
  check(Re.decide({ kind = "worm", dist = 34, hp = 300, armed = true, walking = false }) == "flee", "blessé près d'un ver : fuite")
  section("réaction : menaces fixes et unités (C2, C4)")
  check(Re.decide({ kind = "worm", dist = 44, range = 30, on_route = true, hp = 1000, armed = true, walking = true }) == "detour",
    "ver sur la route, hors de portée : détour")
  check(Re.decide({ kind = "worm", dist = 25, range = 30, hp = 1000, armed = true, walking = true }) == "back",
    "déjà à portée d'un ver : demi-tour")
  check(Re.decide({ kind = "spawner", dist = 70, range = 24, on_route = false, hp = 1000, armed = true, walking = true }) == "none",
    "nid loin du trajet : seulement marqué")
  check(Re.decide({ kind = "unit", dist = 20, hp = 1000, armed = true, enemies = 3, allies = 5, walking = true }) == "engage",
    "6 armés contre 3 : combat")
  check(Re.decide({ kind = "unit", range = 30, dist = 20, hp = 1000, armed = true, enemies = 3, allies = 0, walking = true }) == "back",
    "seul contre 3, proches : demi-tour")
  check(Re.decide({ kind = "unit", range = 30, dist = 20, hp = 1000, armed = true, enemies = 3, allies = 0, walking = false }) == "flee",
    "seul contre 3 à l'arrêt : fuite")
  check(Re.decide({ kind = "unit", dist = 35, on_route = true, hp = 1000, armed = true, enemies = 3, walking = true }) == "stop",
    "unités loin sur la route : arrêt")
  check(Re.decide({ kind = "unit", range = 30, dist = 34, on_route = true, hp = 1000, armed = true, enemies = 3, walking = true }) == "detour",
    "unités juste hors de leur vue (30 < 34 ≤ 38) : détour immédiat")
  check(Re.decide({ kind = "unit", range = 30, dist = 45, on_route = true, hp = 1000, armed = true, enemies = 3, walking = true }) == "stop",
    "unités au-delà de leur vue + marge : arrêt")
  -- Force pesée : 2 petits déchiqueteurs (0,2 chacun) face à un ouvrier armé en bonne santé.
  check(Re.decide({ kind = "unit", range = 30, dist = 14, hp = 1000, armed = true, enemies = 0.4, prudence = 600, agressivite = 1500 }) == "engage",
    "audacieux armé contre 2 petits déchiqueteurs : combat")
  check(Re.decide({ kind = "unit", range = 30, dist = 14, hp = 480, armed = true, enemies = 0.4, prudence = 600, agressivite = 1500 }) == "engage",
    "audacieux à 48 % contre 2 petits : il se bat encore")
  check(Re.decide({ kind = "unit", range = 30, dist = 14, hp = 480, armed = true, enemies = 0.4, prudence = 1250 }) == "flee",
    "prudent à 48 % contre 2 petits : fuite (seuil 55 %)")
  check(Re.decide({ kind = "unit", range = 30, dist = 14, hp = 390, armed = true, enemies = 0.4, prudence = 600, agressivite = 1500 }) == "flee",
    "audacieux sous 40 % : fuite")
  check(Re.decide({ kind = "unit", range = 30, dist = 34, on_route = true, hp = 1000, armed = true, enemies = 3, walking = true, repeats = 2 }) == "back",
    "unités revues après 2 arrêts ou détours de la même tournée : demi-tour (renoncer)")
  check(Re.engage_ratio(600, 1800) == 1500 and Re.engage_ratio(1250, 700) == 3000, "rapport d'engagement 1,5 à 3 selon le caractère")
  check(Re.look_radius(562) == 40 and Re.look_radius(1250) == 56, "regard de 40 à 56 tuiles selon la prudence")
  check(Re.LOOK_AHEAD + Re.look_radius(562) >= 48 + D.MARGIN, "le regard le plus court voit une zone de béhémoth (48 + marge) avant d'y entrer")
  check(Re.decide({}) == "none", "aucun ennemi : rien")
end

local function run_quiet()
  quiet = true
  local p0, f0 = passes, failures
  local ok, err = pcall(suite)
  local fails = failures - f0
  passes, failures = p0, f0
  quiet = false
  return fails + (ok and 0 or 1), err
end

suite()
local base_fail = failures

---------------------------------------------------------------------------------------------------
-- ÉQUIVALENCE de l'A* accéléré (shared/ai3/route.lua) avec la version d'origine (gardée ici comme référence, copie
-- exacte de 3958412) : mêmes cases et même nombre de développements sur des cartes tirées au sort, avec et sans bruit
-- de tournée. Hors des mutants (contrôle de la seule implantation).
---------------------------------------------------------------------------------------------------
do
  print("== A* accéléré : identique à la version d'origine")
  local function less(a, b) if a.f ~= b.f then return a.f < b.f end return a.k < b.k end
  local function push(h, it)
    h[#h + 1] = it
    local i = #h
    while i > 1 do
      local p = math.floor(i / 2)
      if less(h[i], h[p]) then h[i], h[p] = h[p], h[i]; i = p else break end
    end
  end
  local function pop(h)
    local top = h[1]
    local last = h[#h]
    h[#h] = nil
    if #h > 0 then
      h[1] = last
      local i = 1
      while true do
        local l, r, m = 2 * i, 2 * i + 1, i
        if l <= #h and less(h[l], h[m]) then m = l end
        if r <= #h and less(h[r], h[m]) then m = r end
        if m == i then break end
        h[i], h[m] = h[m], h[i]
        i = m
      end
    end
    return top
  end
  local NB = { { 1, 0, 10 }, { -1, 0, 10 }, { 0, 1, 10 }, { 0, -1, 10 }, { 1, 1, 14 }, { 1, -1, 14 }, { -1, 1, 14 }, { -1, -1, 14 } }
  local function octile(ax, ay, bx, by)
    local dx, dy = math.abs(ax - bx), math.abs(ay - by)
    local mn, mx = dx < dy and dx or dy, dx < dy and dy or dx
    return 14 * mn + 10 * (mx - mn)
  end
  local function astar_ref(field, sc, gc, B, seed, max_expand)
    local cx0 = math.min(sc[1], gc[1]) - R.BOX_MARGIN
    local cy0 = math.min(sc[2], gc[2]) - R.BOX_MARGIN
    local cx1 = math.max(sc[1], gc[1]) + R.BOX_MARGIN
    local cy1 = math.max(sc[2], gc[2]) + R.BOX_MARGIN
    local sk, gk = D.key(sc[1], sc[2]), D.key(gc[1], gc[2])
    local g, from, closed = { [sk] = 0 }, {}, {}
    local open = {}
    push(open, { f = octile(sc[1], sc[2], gc[1], gc[2]), k = sk, cx = sc[1], cy = sc[2] })
    local expand = 0
    local cap = max_expand or R.MAX_EXPAND
    while #open > 0 do
      local cur = pop(open)
      if cur.k == gk then
        local path, k = {}, gk
        while k do
          local x, y = D.unkey(k)
          table.insert(path, 1, { x, y })
          k = from[k]
        end
        return path, expand
      end
      if not closed[cur.k] then
        closed[cur.k] = true
        expand = expand + 1
        if expand > cap then return nil, expand end
        for _, nb in ipairs(NB) do
          local nx, ny = cur.cx + nb[1], cur.cy + nb[2]
          if nx >= cx0 and nx <= cx1 and ny >= cy0 and ny <= cy1 then
            local nk = D.key(nx, ny)
            local dg = field[nk] or 0
            if not closed[nk] and (dg < B or nk == gk) then
              local noise = 0
              if seed then noise = Tr.mulmod(nk % (Tr.MOD - 1) + 1, seed) % (R.NOISE + 1) end
              local step = nb[3] * (1000 + dg * 10 + noise) / 1000
              local ng = g[cur.k] + step
              if not g[nk] or ng < g[nk] then
                g[nk] = ng
                from[nk] = cur.k
                push(open, { f = ng + octile(nx, ny, gc[1], gc[2]), k = nk, cx = nx, cy = ny })
              end
            end
          end
        end
      end
    end
    return nil, expand
  end
  local st = Tr.new_stream(20261027, 471)
  local function rnd(n) return Tr.range(st, 1, n) end
  local same, cases, found, blocked = 0, 0, 0, 0
  for c = 1, 300 do
    local map = D.new()
    local tick = 50 * MIN
    for i = 1, rnd(30) do
      local kinds = { "worm", "spawner", "turret", "unit", "pack" }
      D.mark_seen(map, rnd(500) - 250, rnd(500) - 250, kinds[rnd(5)], 14 + rnd(30), tick - rnd(40) * MIN)
    end
    for i = 1, rnd(6) - 1 do D.mark_death(map, rnd(400) - 200, rnd(400) - 200, tick - rnd(50) * MIN) end
    local field = D.field(map, tick)
    local sc = { rnd(20) - 10, rnd(20) - 10 }
    local gc = { rnd(40) - 20, rnd(40) - 20 }
    local B = ({ 400, 600, 750, 1e9 })[rnd(4)]
    local seed = (c % 2 == 0) and rnd(Tr.MOD - 2) or nil
    local cap = (c % 5 == 0) and 200 or nil
    local p1, n1 = R.astar(field, sc, gc, B, seed, cap)
    local p2, n2 = astar_ref(field, sc, gc, B, seed, cap)
    cases = cases + 1
    local eq = n1 == n2 and ((p1 == nil) == (p2 == nil))
    if eq and p1 then
      if #p1 ~= #p2 then eq = false else
        for i = 1, #p1 do if p1[i][1] ~= p2[i][1] or p1[i][2] ~= p2[i][2] then eq = false break end end
      end
    end
    if p1 then found = found + 1 else blocked = blocked + 1 end
    if eq then same = same + 1 end
  end
  check(same == cases and found > 50 and blocked > 10,
    string.format("A* accéléré = version d'origine : %d / %d cas identiques (%d chemins, %d sans issue)", same, cases, found, blocked))
end

-- ÉQUIVALENCE du champ accéléré (D.field, disques limités à la boîte) avec la version d'origine (référence ci-dessous,
-- copie exacte de 3958412) : mêmes cases, mêmes valeurs, même nombre, avec et sans boîte.
do
  print("== champ du danger accéléré : identique à la version d'origine")
  local function field_ref(map, tick, box)
    local out, n = {}, 0
    local function add(cx, cy, w)
      if w <= 0 then return end
      if box and (cx < box[1] or cy < box[2] or cx > box[3] or cy > box[4]) then return end
      local k = D.key(cx, cy)
      if not out[k] then n = n + 1 end
      out[k] = (out[k] or 0) + w
    end
    for _, t in ipairs(map.threats) do
      local K = D.KINDS[t.k] or D.KINDS.unit
      local w = math.floor(K.w * (K.fast and D.dec10(tick - t.t) or D.dec2(tick - t.t)) / 1000)
      if w > 0 then D.cells_within(t.x, t.y, t.r + D.MARGIN, function(cx, cy) add(cx, cy, w) end) end
    end
    for _, d in ipairs(map.deaths) do
      local age = tick - d.t
      local w = age < D.DEATH_FULL and D.DEATH_W or math.floor(D.DEATH_W * D.dec10(age - D.DEATH_FULL) / 1000)
      if d.home then w = 0 end
      if w > 0 then D.cells_within(d.x, d.y, D.DEATH_R, function(cx, cy) add(cx, cy, w) end) end
    end
    local keys = {}
    for k in pairs(map.cells) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local cx, cy = D.unkey(k)
      local c = map.cells[k]
      add(cx, cy, math.floor(c.m * D.dec10(tick - c.t) / 1000))
    end
    return out, n
  end
  local st = Tr.new_stream(20261027, 472)
  local function rnd(k) return Tr.range(st, 1, k) end
  local same, cases, cells = 0, 0, 0
  for c = 1, 200 do
    local map = D.new()
    local tick = 90 * MIN
    local kinds = { "worm", "spawner", "turret", "unit", "pack", "character" }
    for i = 1, rnd(40) do
      D.mark_seen(map, rnd(600) - 300 + rnd(100) / 7, rnd(600) - 300 - rnd(100) / 9, kinds[rnd(6)], 10 + rnd(40), tick - rnd(80) * MIN)
    end
    for i = 1, rnd(8) - 1 do D.mark_death(map, rnd(400) - 200, rnd(400) - 200, tick - rnd(70) * MIN, rnd(5) == 1) end
    for i = 1, rnd(5) - 1 do D.mark_attack(map, rnd(400) - 200, rnd(400) - 200, tick - rnd(20) * MIN) end
    local box = nil
    if c % 4 ~= 0 then
      local x0, y0 = rnd(40) - 25, rnd(40) - 25
      box = { x0, y0, x0 + rnd(30), y0 + rnd(30) }
    end
    local a, na = D.field(map, tick, box)
    local b, nb = field_ref(map, tick, box)
    local eq = na == nb
    for k, v in pairs(a) do if b[k] ~= v then eq = false end end
    for k, v in pairs(b) do if a[k] ~= v then eq = false end end
    cases, cells = cases + 1, cells + nb
    if eq then same = same + 1 end
  end
  check(same == cases and cells > 1000, string.format("champ accéléré = version d'origine : %d / %d cartes identiques (%d cases)", same, cases, cells))
end

print("== mutants (chaque règle retirée doit faire échouer au moins un contrôle)")
local function mutant(name, apply, restore)
  apply()
  local n = run_quiet()
  restore()
  check(n > 0, "mutant « " .. name .. " » détecté (" .. n .. " contrôle(s) en échec)")
end
local keep = {}
local function patch(t, k, v) keep[#keep + 1] = { t, k, t[k] }; t[k] = v end
local function unpatch() for i = #keep, 1, -1 do local e = keep[i]; e[1][e[2]] = e[3] end keep = {} end

mutant("mort non marquée", function() patch(D, "mark_death", function() end) end, unpatch)
mutant("porte sans la règle des 2 morts", function()
  local g = D.gate
  patch(D, "gate", function(info, ctx) local i2 = {} for k, v in pairs(info) do i2[k] = v end i2.deaths = 0 return g(i2, ctx) end)
end, unpatch)
mutant("pas de variation des trajets", function() patch(R, "via", function() return nil, 0 end) end, unpatch)
mutant("A* qui ignore le danger", function()
  local a = R.astar
  patch(R, "astar", function(field, sc, gc, B, seed, mx) return a({}, sc, gc, B, seed, mx) end)
end, unpatch)
mutant("peur égale pour tous", function() patch(Re, "fear", function() return 400 end) end, unpatch)
mutant("aucun détour d'une menace fixe", function()
  local d = Re.decide
  patch(Re, "decide", function(s) local a, r = d(s) if a == "detour" then return "none", r end return a, r end)
end, unpatch)
mutant("nid nettoyé jamais oublié", function() patch(D, "forget_unseen", function() return 0 end) end, unpatch)
mutant("aucune décroissance", function() patch(D, "dec10", function() return 1000 end); patch(D, "dec2", function() return 1000 end) end, unpatch)
mutant("seuil de blocage fixe", function() patch(D, "block", function() return 600 end) end, unpatch)

print(string.format("[IA3K-REGLES] BILAN : %d OK, %d ECHEC(S)%s", passes, failures, base_fail > 0 and " (suite de base en échec)" or ""))
os.exit(failures == 0 and 0 or 1)
