--[[
  Lot ARMEE-ANTICIPATION (retour du DC du 29/10, point 2) : banc HORS JEU de la règle pure shared/ai3/armee.lua (besoin,
  regroupement, raid, mémoire des raids repoussés ; l'ESTIMATION vient depuis le lot PREVISION de l'estimateur unique,
  shared/ai3/prevision.lua et prevision_choix.lua, testés par tests/prevision_test.lua) et de son branchement dans Sd.assign (shared/ai3/soldats.lua :
  regroupement au lieu des patrouilles, raid seulement avec l'effectif, aucune autre expédition pendant l'alerte, besoin du
  nettoyage compté sur le champ entier). Mutants qui doivent échouer.
  Lancement : lua5.2 tests/armee_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local A = require("shared.ai3.armee")
local Pv = require("shared.ai3.prevision")
local Pc = require("shared.ai3.prevision_choix")
local Sd = require("shared.ai3.soldats")
local Bu = require("shared.ai3.buts")

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
end
local function section(name) if not quiet then print("== " .. name) end end

local HQ = { x = 0, y = 0 }
local HOME = { x = 0, y = 14 }
local function soldiers(n)
  local out = {}
  for i = 1, n do out[i] = { id = i, x = (i % 5) * 3, y = 14 + math.floor(i / 5) * 2 } end
  return out
end
local function count(orders, role)
  local n = 0
  for _, o in pairs(orders) do if o.role == role then n = n + 1 end end
  return n
end
-- Champ de nids : nests nids + worms vers autour de (x, y), groupé par Sd.clusters, avec unités et pollution.
local function field(x, y, nests, worms, units, polluted)
  local th = {}
  for i = 1, nests do th[#th + 1] = { x = x + i, y = y, kind = "spawner" } end
  for i = 1, worms do th[#th + 1] = { x = x, y = y + i, kind = "worm" } end
  table.sort(th, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  local c = Sd.clusters(th)[1]
  c.units, c.polluted = units or 0, polluted
  return c
end

-- Lot PREVISION : situation estimée par l'estimateur unique. QG pollueur (100/min), tourelles (dps), `soldiers` soldats de 480 PV
-- chacun ; champ de `nests` nids autour de (fx, fy) dont la case porte la pollution `c` (0 : le nid ne reçoit rien) ; unités VUES
-- (PV) à portée d'œil du QG. Unité moyenne : 75 PV, 4 de pollution, 0,2 tuile/tick ; cadence vanilla d'un nid (10 unités/min à
-- l'évolution 0, 24 à 1 : lot PREVISION-CALIB, le nid d'une case saturée tourne à sa cadence). Rend l'estimation et les décisions.
local function situation(o)
  local nests = {}
  for i = 1, o.nests or 2 do nests[#nests + 1] = { x = o.fx + i, y = o.fy, c = o.c or 0, nb = 0 } end
  local est = Pv.estimate({ evo = 0, kinds = { { units = { { hp = 75, cost = 4, speed = 0.2, pts = { { 0, 1 } } } }, rate_max = 10, rate_max1 = 24 } },
    gather = { min = 1, max = 10, size = 200 }, sites = { { key = "qg", x = 0, y = 0, emit = 100, dps = o.dps or 0,
      dpsr = (o.dps or 0) * 18, turrets = o.turrets or 0, seen = o.seen or 0, contact = 0 } }, nests = nests, rivals = {} })
  local n = o.soldiers or 10
  local pc = Pc.update(Pc.new(), est, { soldiers = n, soldiers_max = 30, soldier_value = 480, mobile = n * 480,
    turret_value = 600, iron = o.iron or 2000, reserve = 150, kit_iron = 20, turret_iron = 60 }, 0)
  return est, pc
end
local function decide(fields, o)
  local est, pc = situation(o)
  return A.estimate({ tick = 0, hq = HQ, home = HOME, strength = 1, fields = fields, prev = pc, est = est,
    free = o.free or 13, soldier_value = 480, fails = o.fails }), est, pc
end

local function body()
  section("Besoin : monotone, force d'un soldat, zéro sans menace")
  check(A.need(0, 1) == 0 and A.need(nil, 1) == 0, "aucune menace : aucun soldat")
  check(A.need(2, 1) == 3, "poids 2, fusilier : 3 soldats (marge 1,5) : " .. A.need(2, 1))
  check(A.need(10, 1) > A.need(4, 1), "plus de menace, plus de soldats")
  check(A.need(10, 2) < A.need(10, 1), "soldats plus forts : moins de soldats")

  section("Champs : nids seulement, triés par distance, bornés")
  local cl = {}
  for i = 1, 12 do cl[#cl + 1] = { x = 200 - i * 10, y = 0, k = 1, nests = 1 } end
  cl[#cl + 1] = { x = 5, y = 0, k = 1, nests = 0 } -- ver seul : pas un champ
  local fs = A.fields(cl, HQ)
  check(#fs == A.MAX_FIELDS, "au plus " .. A.MAX_FIELDS .. " champs (" .. #fs .. ")")
  check(fs[1].x == 80 and fs[1].nests == 1, "le plus proche d'abord, le ver seul écarté")

  section("Regroupement : vers la menace, à MUSTER_R au plus")
  local m = A.muster(HQ, { x = 100, y = 0 }, HOME)
  check(math.abs(m.x - A.MUSTER_R) < 1e-9 and m.y == 0, "à MUSTER_R tuiles vers la menace")
  local m2 = A.muster(HQ, { x = 0, y = -30 }, HOME)
  check(math.abs(m2.y + 10) < 1e-9, "menace proche : au tiers de la distance")
  local m3 = A.muster(HQ, nil, HOME)
  check(m3.x == HOME.x and m3.y == HOME.y, "direction inconnue : rassemblement du QG")

  section("Estimation (prévision) : un champ que la pollution n'atteint pas ne prépare pas de vague")
  local cold = field(90, 0, 2, 4, 6, false)
  local e0 = decide({ cold }, { fx = 90, fy = 0, c = 0 })
  check(not e0.alert and e0.threat == 0 and #e0.hot == 0, "champ froid : aucune alerte (menace " .. e0.threat .. ")")

  section("Estimation (prévision) : champ pollué -> alerte d'état, besoin borné, regroupement, raid préventif")
  local hot = field(90, 0, 2, 4, 6, true)
  local e1, est1, pc1 = decide({ hot }, { fx = 90, fy = 0, c = 50 })
  check(e1.alert, "alerte")
  check(math.abs(e1.threat - est1.by.qg.w5) < 1e-6 and e1.threat > 0, "menace = vague de la prévision (" .. e1.threat .. " PV)")
  check(e1.need == pc1.army_need and e1.need > 0 and e1.need <= 30, "besoin = celui de la prévision, sous le plafond (" .. e1.need .. ")")
  check(e1.nests == 2 and e1.worms == 4, "2 nids et 4 vers comptés (" .. e1.nests .. ", " .. e1.worms .. ")")
  check(e1.muster and e1.muster.x > 0 and e1.muster.x <= A.MUSTER_R + 1e-9, "regroupement entre le QG et le champ")
  check(e1.raid and e1.raid.need == Sd.clear_need(6) + A.need(6, 1), "raid : champ entier + défenseurs VUS (" .. tostring(e1.raid and e1.raid.need) .. ")")
  -- Relecture : l'effectif recruté couvre le raid visé (+ réserve), sous le même budget que la prévision.
  check(e1.raid and e1.recruit == math.min(e1.raid.need + A.RAID_RESERVE, pc1.army_cap) and e1.recruit >= e1.need,
    "recrutement : besoin du raid + réserve, sous le budget (" .. tostring(e1.recruit) .. ", vague seule " .. tostring(e1.need) .. ")")
  check(A.raid_alive(e1.raid, { { x = e1.raid.x + 10, y = e1.raid.y } }), "raid visé : groupe encore connu")
  check(not A.raid_alive(e1.raid, { { x = e1.raid.x + 60, y = e1.raid.y } }) and not A.raid_alive(e1.raid, {}) and not A.raid_alive(nil, {}),
    "raid visé : champ nettoyé depuis l'estimation : plus de raid")
  local far = field(150, 0, 2, 0, 0, true)
  local e2 = decide({ far }, { fx = 150, fy = 0, c = 50 })
  check(e2.alert and e2.raid == nil, "champ menaçant hors de portée d'expédition : alerte sans raid")
  check(e2.recruit == e2.need, "sans raid : recrutement au besoin de la vague")
  local one = field(90, 0, 1, 0, 30, true) -- un nid défendu par 30 de poids VUS
  local e2b = decide({ one }, { fx = 90, fy = 0, c = 50, nests = 1 })
  check(e2b.raid == nil and e2b.raid_why and e2b.raid_why:find("engage"), "un nid bien défendu : le raid vaut moins qu'il n'engage, refusé (" .. tostring(e2b.raid_why) .. ")")
  local e3 = decide({}, { fx = 300, fy = 0, nests = 0, seen = 3000, soldiers = 2 })
  check(e3.alert and e3.threat == 3000, "vague VUE à portée d'œil, peu de soldats : alerte (" .. e3.threat .. ")")
  local e4 = decide({}, { fx = 300, fy = 0, nests = 0, seen = 3000, soldiers = 10 })
  check(not e4.alert, "la même vague couverte par 10 soldats : pas d'alerte (écart, pas niveau)")
  local e5 = decide({ hot }, { fx = 90, fy = 0, c = 50, nests = 20, iron = 150 })
  check(e5.alert and e5.raid == nil and e5.muster.x == HOME.x and e5.muster.y == HOME.y,
    "vague insurmontable (aucun fer libre) : repli au QG, aucun raid")

  section("Raid repoussé : la fois suivante, au moins FAIL_MULT × la force envoyée")
  local fails = A.record_fail({}, hot.x, hot.y, 15, 100)
  check(#fails == 1 and fails[1].n == 15, "retraite mémorisée")
  check(A.raid_need(hot, 1, fails, 200) == 30, "besoin relevé à 2 × 15 (" .. A.raid_need(hot, 1, fails, 200) .. ")")
  check(A.raid_need(hot, 1, A.record_fail({}, hot.x, hot.y, 5, 100), 200) == Sd.clear_need(6) + A.need(6, 1), "2 × une petite force sous le besoin ordinaire : besoin ordinaire")
  check(A.raid_need(hot, 1, fails, 100 + A.FAIL_TICKS) == Sd.clear_need(6) + A.need(6, 1), "mémoire échue : besoin ordinaire")
  local fails2 = A.record_fail(fails, hot.x + 2, hot.y, 4, 300)
  check(#fails2 == 1 and fails2[1].n == 4, "même champ : l'entrée est remplacée")
  check(A.alert_on({ alert = true }) and not A.alert_on({ alert = false }) and not A.alert_on(nil)
    and not A.alert_on({ alert_until = 1e9 }), "alerte d'état (l'ancienne alerte à l'horloge d'une sauvegarde ne compte plus)")

  section("Sd.assign : regroupement au lieu des patrouilles (13 soldats, DC)")
  local base = { tick = 10, hq = HQ, agr = 1000, soldiers = soldiers(13), threats = {} }
  local o0 = Sd.assign(base)
  check(count(o0, "patrol") > 0 and count(o0, "muster") == 0, "sans alerte : patrouilles par paires")
  local mu = { tick = 10, hq = HQ, agr = 1000, soldiers = soldiers(13), threats = {}, muster = { x = 20, y = 0 } }
  local o1 = Sd.assign(mu)
  check(count(o1, "muster") == 13 and count(o1, "patrol") == 0 and count(o1, "guard") == 0, "alerte : les 13 au même point")
  local same = true
  for _, o in pairs(o1) do if o.x ~= 20 or o.y ~= 0 then same = false end end
  check(same, "un seul point de regroupement")

  section("Sd.assign : raid seulement avec l'effectif, sinon aucune expédition dispersée")
  local need = e1.raid.need
  local r = { x = e1.raid.x, y = e1.raid.y, k = e1.raid.k, wide = e1.raid.wide, nests = 2, need = need, reserve = A.RAID_RESERVE }
  local small = Sd.assign({ tick = 10, hq = HQ, agr = 1000, soldiers = soldiers(13), muster = { x = 20, y = 0 }, raid = r,
    threats = { field(-40, 0, 1, 0, 0, false) } })
  local o2, s2 = small, select(2, Sd.assign({ tick = 10, hq = HQ, agr = 1000, soldiers = soldiers(13), muster = { x = 20, y = 0 }, raid = r,
    threats = { field(-40, 0, 1, 0, 0, false) } }))
  check(count(o2, "clear") == 0 and s2.raid == "effectif", "13 soldats pour un besoin de " .. need .. " : raid différé")
  check(count(o2, "muster") == 13, "raid différé : tout le monde au regroupement (aucune expédition ailleurs)")
  local big, s3 = Sd.assign({ tick = 10, hq = HQ, agr = 1000, soldiers = soldiers(need + A.RAID_RESERVE), muster = { x = 20, y = 0 }, raid = r, threats = {} })
  check(s3.raid == "lance" and s3.offense and count(big, "clear") == need, "effectif suffisant : raid de " .. need .. " soldats (" .. count(big, "clear") .. ")")
  check(count(big, "muster") == A.RAID_RESERVE, "la réserve reste au regroupement")
  local _, s3b = Sd.assign({ tick = 10, hq = HQ, agr = 1000, soldiers = soldiers(need), muster = { x = 20, y = 0 }, raid = r, threats = {} })
  check(s3b.raid == "effectif", "juste le besoin, sans réserve : le QG n'est pas vidé, raid différé")
  local _, s4 = Sd.assign({ tick = 10, hq = HQ, agr = 1000, soldiers = soldiers(40), muster = { x = 20, y = 0 }, raid = r, threats = {},
    blocked = { { x = r.x, y = r.y, ["until"] = 100 } } })
  check(s4.raid == "bloque", "champ d'une retraite récente : raid bloqué")
  local o5 = Sd.assign({ tick = 10, hq = HQ, agr = 1000, soldiers = soldiers(40), muster = { x = 20, y = 0 }, raid = r, threats = {}, offense = false })
  check(count(o5, "clear") == 0, "coupure de banc (offense = false) : aucun raid")

  section("Nettoyage : besoin compté sur le champ ENTIER (« quatre soldats dans un endroit trop dangereux »)")
  -- Un ver qui a tué, au bord d'un champ de 2 nids et 4 vers : groupe de 24 tuiles k = 1, champ entier wide = 6.
  local edge = { x = 70, y = 0, k = 1, wide = 6, killed = true, nests = 0, rival = 0, known = 0 }
  check(Sd.field_need(edge) == Sd.clear_need(6), "besoin du champ entier : " .. Sd.field_need(edge))
  local o6 = Sd.assign({ tick = 10, hq = HQ, agr = 1000, soldiers = soldiers(8), threats = { edge } })
  check(count(o6, "clear") == 0, "8 soldats contre un champ de 6 menaces : personne n'y va (avant : 5 envoyés)")
  local o7 = Sd.assign({ tick = 10, hq = HQ, agr = 1000, soldiers = soldiers(20), threats = { edge } })
  check(count(o7, "clear") == Sd.clear_need(6), "20 soldats : la force du champ entier y va (" .. count(o7, "clear") .. ")")
  local lone = { x = 70, y = 0, k = 1, killed = true, nests = 0, rival = 0, known = 0 }
  local o8 = Sd.assign({ tick = 10, hq = HQ, agr = 1000, soldiers = soldiers(8), threats = { lone } })
  check(count(o8, "clear") == Sd.clear_need(1), "ver isolé (pas de champ) : besoin inchangé (" .. count(o8, "clear") .. ")")

  section("Cerveau (IA3) : vague annoncée -> l'armée monte au besoin, valeur de la protection")
  local function s_of(alert, need, soldiers)
    return { is_player = false, workers = 8, soldiers = soldiers, soldiers_max = 30, stock = { ["firearm-magazine"] = 80 },
      cap = { coal = 1, iron = 1, copper = 1, stone = 1 }, pending = {}, sites = {}, smelters = 4, smelters_pending = 0,
      weights = Bu.weights({}, nil), army_target = 18, economy_done = false, army_alert = alert, army_need = need }
  end
  local function army_goal(sx)
    for _, g in ipairs(Bu.generate(sx, { targets = { coal = 1, iron = 1, copper = 1, stone = 1 }, iron2_set = true })) do
      if g.kind == "army" then return g end
    end
    return nil
  end
  local g0 = army_goal(s_of(false, 0, 13))
  local g1 = army_goal(s_of(true, 25, 13))
  check(g0 and not g0.alert and g0.target == 18, "sans alerte : armée visée ordinaire (18)")
  check(g1 and g1.alert and g1.target == 25 and g1.minimal and g1.value > g0.value,
    string.format("alerte : but de protection (cible %s, valeur %s contre %s), jamais retenu par « production d'abord »",
      tostring(g1 and g1.target), tostring(g1 and g1.value), tostring(g0 and g0.value)))
  local g2 = army_goal(s_of(true, 80, 13))
  check(g2 and g2.target == 30, "besoin au-delà du plafond : recruter au maximum (30)")
  local g3 = army_goal(s_of(true, 12, 13))
  check(g3 and not g3.alert, "effectif déjà au besoin : pas de but d'alerte")

  section("Déterminisme")
  local x1 = Sd.assign({ tick = 10, hq = HQ, agr = 1000, soldiers = soldiers(13), muster = { x = 20, y = 0 }, raid = r, threats = {} })
  local x2 = Sd.assign({ tick = 10, hq = HQ, agr = 1000, soldiers = soldiers(13), muster = { x = 20, y = 0 }, raid = r, threats = {} })
  local eq = true
  for i = 1, 13 do if (x1[i] and x1[i].key) ~= (x2[i] and x2[i].key) then eq = false end end
  check(eq, "deux passages identiques")
end

body()
local main_pass, main_fail = passes, failures

-- Mutants : chaque règle cassée doit faire échouer le banc.
local function mutant(name, apply, restore)
  quiet = true
  passes, failures = 0, 0
  apply()
  local ok = pcall(body)
  restore()
  quiet = false
  local caught = failures > 0 or not ok
  print(string.format("  mutant %s : %s", name, caught and "refusé" or "SURVIT"))
  return caught
end
local killed, total = 0, 0
local function run(name, apply, restore)
  total = total + 1
  if mutant(name, apply, restore) then killed = killed + 1 end
end
do
  local orig = Sd.field_need
  run("besoin du nettoyage sur le seul groupe de 24 tuiles", function() Sd.field_need = function(th) return Sd.clear_need(th.k or 1) end end,
    function() Sd.field_need = orig end)
end
do
  local orig = A.MARGIN
  run("marge nulle", function() A.MARGIN = 0 end, function() A.MARGIN = orig end)
end
do
  local orig = A.hot
  run("champ que la pollution n'atteint pas compté chaud", function() A.hot = function() return true end end, function() A.hot = orig end)
end
do
  local orig = Pc.raid_gate
  run("porte du raid ouverte à tout", function() Pc.raid_gate = function() return true, "ouvert" end end, function() Pc.raid_gate = orig end)
end
do
  local orig = Sd.assign
  run("regroupement ignoré", function()
    Sd.assign = function(input) input.muster = nil return orig(input) end
  end, function() Sd.assign = orig end)
end
do
  local orig = A.raid_need
  run("raid sans les défenseurs", function()
    A.raid_need = function(c, s, fl, t) local u = c.units c.units = 0 local n = orig(c, s, fl, t) c.units = u return n end
  end, function() A.raid_need = orig end)
end
do
  local orig = A.FAIL_MULT
  run("retraite oubliée", function() A.FAIL_MULT = 0 end, function() A.FAIL_MULT = orig end)
end
do
  local orig = Bu.ARMY_ALERT
  run("vague annoncée sans priorité de protection", function() Bu.ARMY_ALERT = 1 end, function() Bu.ARMY_ALERT = orig end)
end
do
  local orig = A.RAID_RESERVE
  run("réserve du raid supprimée", function() A.RAID_RESERVE = 0 end, function() A.RAID_RESERVE = orig end)
end

do
  local orig = A.estimate
  run("recrutement au seul besoin de la menace (raid jamais payable)", function()
    A.estimate = function(input) local o = orig(input) o.recruit = o.need return o end
  end, function() A.estimate = orig end)
end
do
  local orig = A.raid_alive
  run("raid fantôme sur un champ nettoyé", function() A.raid_alive = function(r) return r ~= nil end end,
    function() A.raid_alive = orig end)
end

passes, failures = main_pass, main_fail
check(killed == total, string.format("mutants refusés : %d sur %d", killed, total))
print(string.format("[ARMEE] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refusés sur %d)", passes, failures, killed, total))
os.exit(failures == 0 and 0 or 1)
