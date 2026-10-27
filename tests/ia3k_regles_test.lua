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
  local hs, ok_len, ok_mag = {}, true, true
  for i = 1, 200 do
    local r = R.plan(S, G, { field = {}, n = 0, draw = draw })
    hs[i] = r.h
    if r.len > 1.15 * r.direct then ok_len = false end
    local a = math.abs(r.h)
    if a < 0.06 * 100 - 1e-9 or a > 0.18 * 100 + 1e-9 then ok_mag = false end
  end
  check(ok_len, "allongement de la variation ≤ 15 %")
  check(ok_mag, "écart latéral du point de passage entre 6 % et 18 % de la distance")
  local far_pairs = 0
  for i = 1, 199 do if math.abs(hs[i] - hs[i + 1]) >= 4 then far_pairs = far_pairs + 1 end end
  check(far_pairs >= 100, "deux tournées successives à ≥ 4 tuiles d'écart dans ≥ 50 % des cas (" .. far_pairs .. " / 199)")
  local rshort = R.plan({ x = 0, y = 0 }, { x = 30, y = 0 }, { field = {}, n = 0, draw = draw })
  check(#rshort.pts == 0, "pas de variation sous 40 tuiles")
  -- Écart médian mesuré sur des trajets échantillonnés (même mesure que le banc ia3k-variete).
  local t1 = R.samples(S, { { x = 50, y = 8 } }, G, 2)
  local t2 = R.samples(S, { { x = 50, y = -6 } }, G, 2)
  local med = R.median_gap(S, G, t1, t2, 8)
  check(med >= 4 and med <= 14, "écart médian de deux trajets décalés de 8 et -6 au milieu : " .. string.format("%.1f", med))

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
  D.mark_seen(msym, 104, 8, "worm", 30, 0)
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

  section("itinéraire : blocage")
  local mbk = D.new()
  for _, p in ipairs({ { 30, 0 }, { -30, 0 }, { 0, 30 }, { 0, -30 }, { 30, 30 }, { -30, -30 }, { 30, -30 }, { -30, 30 } }) do
    D.mark_seen(mbk, p[1], p[2], "worm", 30, 0)
  end
  local fb2, nb2 = D.field(mbk, 0)
  local rb = R.plan({ x = 0, y = 0 }, { x = 300, y = 0 }, { field = fb2, n = nb2, B = 600 })
  check(rb.blocked, "PNJ encerclé de vers : trajet bloqué")
  local rb2 = R.plan({ x = 0, y = 0 }, { x = 300, y = 0 }, { field = fb2, n = nb2, B = 1e9 })
  check(not rb2.blocked and rb2.max_d > 0, "sans seuil (escorte, sortie) : un chemin qui minimise le danger")

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
  check(Re.decide({ kind = "unit", dist = 20, hp = 1000, armed = true, enemies = 3, allies = 0, walking = true }) == "back",
    "seul contre 3, proches : demi-tour")
  check(Re.decide({ kind = "unit", dist = 20, hp = 1000, armed = true, enemies = 3, allies = 0, walking = false }) == "flee",
    "seul contre 3 à l'arrêt : fuite")
  check(Re.decide({ kind = "unit", dist = 35, on_route = true, hp = 1000, armed = true, enemies = 3, walking = true }) == "stop",
    "unités loin sur la route : arrêt")
  check(Re.engage_ratio(600, 1800) == 1500 and Re.engage_ratio(1250, 700) == 3000, "rapport d'engagement 1,5 à 3 selon le caractère")
  check(Re.look_radius(562) == 28 and Re.look_radius(1250) == 40, "regard de 28 à 40 tuiles selon la prudence")
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
