--[[
  Lot NIDS : banc HORS JEU de la règle de nettoyage des nids menaçants (shared/ai3/nids.lua) : sites, menace (biens et
  incidents), armée suffisante et garnison gardée, attentes 5/10/20/40 min, suivi (fin, repli, délai), effacement des nids
  détruits de la carte de connaissance, branchement dans l'attribution des rôles (Sd.assign), déterminisme ; mutants qui
  doivent échouer.
  Lancement : lua5.2 tests/nids_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Nd = require("shared.ai3.nids")
local Sd = require("shared.ai3.soldats")
local K = require("shared.ai3.carte")

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
end
local function section(name) if not quiet then print("== " .. name) end end

local HQ = { x = 0, y = 0, w = Nd.W_HQ }
local function ctx(over)
  local c = { tick = 100000, sites = { { x = 100, y = 0, sp = 2, wm = 1 } }, assets = { HQ }, incidents = {}, holds = {},
    total = 20, idle = 18 }
  for k, v in pairs(over or {}) do c[k] = v end
  return c
end

local function suite()
  section("sites de nid")
  local sites = Nd.sites({ { x = 100, y = 10 }, { x = 120, y = 0 }, { x = -300, y = 300 }, { x = 110, y = 5 } },
    { { x = 105, y = 0 }, { x = 400, y = 400 }, { x = -290, y = 290 } })
  check(#sites == 2, "4 nids -> 2 sites (" .. #sites .. ")")
  check(sites[1].x < sites[2].x and sites[1].sp == 1 and sites[2].sp == 3, "site isolé et site de 3 nids, triés par x")
  check(sites[1].wm == 1 and sites[2].wm == 1, "un ver proche rattaché à son site, un ver lointain ignoré")
  local a = Nd.sites({ { x = 5, y = 5 }, { x = 6, y = 6 }, { x = 200, y = 0 } }, {})
  local b = Nd.sites({ { x = 200, y = 0 }, { x = 6, y = 6 }, { x = 5, y = 5 } }, {})
  check(#a == #b and a[1].x == b[1].x and a[1].y == b[1].y and a[2].x == b[2].x and a[1].sp == b[1].sp, "indépendant de l'ordre d'entrée (déterminisme)")
  check(#Nd.sites({}, { { x = 1, y = 1 } }) == 0, "des vers seuls ne font pas un site de nid")

  section("menace : biens et incidents")
  local s1 = Nd.rank({ { x = 100, y = 0, sp = 1, wm = 0 } }, { HQ }, {}, 0)[1]
  check(s1.prox == math.floor(Nd.W_HQ * (Nd.REACH - 100) / Nd.REACH) and s1.inc == 0, "proximité du QG à 100 tuiles : " .. s1.prox)
  local s2 = Nd.rank({ { x = 100, y = 0, sp = 1, wm = 0 } }, { { x = 0, y = 0, w = 1000 }, { x = 160, y = 0, w = 400 } }, {}, 0)[1]
  check(s2.prox > s1.prox, "un avant-poste proche ajoute à la menace")
  local s3 = Nd.rank({ { x = 400, y = 0, sp = 1, wm = 0 } }, { HQ }, {}, 0)[1]
  check(s3.prox == 0 and s3.menace == 0, "un nid à 400 tuiles du QG ne le menace pas")
  local inc = { { x = 95, y = 5, t = 0, w = 120 }, { x = 5000, y = 0, t = 0, w = 120 } }
  local s4 = Nd.rank({ { x = 100, y = 0, sp = 1, wm = 0 }, { x = -150, y = 0, sp = 1, wm = 0 } }, {}, inc, 0)
  check(s4[1].inc == 120 and s4[2].inc == 0, "incident rattaché au site le plus proche ; l'incident à 5 000 tuiles est ignoré")
  local s5 = Nd.rank({ { x = 100, y = 0, sp = 1, wm = 0 } }, {}, inc, 40 * 3600 / 2)[1]
  check(s5.inc == 60, "un incident pèse la moitié à mi-vie (" .. s5.inc .. ")")
  local s6 = Nd.rank({ { x = 100, y = 0, sp = 1, wm = 0 } }, {}, inc, 40 * 3600)[1]
  check(s6.inc == 0, "un incident ne compte plus après 40 min")
  check(Nd.incident_w("unit") < Nd.incident_w("ammo-turret") and Nd.incident_w("wall") == Nd.INC_W.default, "poids par type : unité < tourelle ; autre = défaut")
  local list = {}
  for i = 1, Nd.MAX_INCIDENTS + 5 do Nd.record_incident(list, i, i, i, 10) end
  check(#list == Nd.MAX_INCIDENTS and list[1].t == 6, "les incidents anciens sortent de la liste")

  section("décision : menace, armée, garnison")
  local d, why = Nd.decide(ctx())
  check(d and d.x == 100 and d.need == Sd.clear_need(3), "nid à 100 tuiles du QG, armée de 18 : on part avec le besoin de la règle des rôles (" .. tostring(d and d.need) .. ")")
  check(d and d.reserve == Nd.reserve(20), "la garnison gardée est portée par la décision (" .. tostring(d and d.reserve) .. ")")
  check(Nd.reserve(20) == 5 and Nd.reserve(4) == Nd.KEEP_MIN and Nd.reserve(0) == Nd.KEEP_MIN, "garnison : un quart (5 sur 20), 3 au moins")
  local d2_ = Nd.decide(ctx({ sites = { { x = 190, y = 0, sp = 1, wm = 0 } } }))
  check(d2_ == nil, "nid à 190 tuiles du QG, aucun incident : menace trop faible")
  local near = { { x = 160, y = 0, sp = 1, wm = 0 } } -- menace 200 (QG seul), besoin 5
  check(Nd.decide(ctx({ sites = near, idle = 11, total = 20 })) == nil, "menace 200, armée libre juste au-dessus du besoin : seuil 250 non atteint")
  check(Nd.decide(ctx({ sites = near, idle = 15, total = 20 })) ~= nil, "même nid, armée libre double du besoin : seuil abaissé, on part")
  check(Nd.decide(ctx({ sites = { { x = 190, y = 0, sp = 1, wm = 0 } }, idle = 40, total = 40 })) == nil, "jamais sous le plancher absolu (menace 50)")
  check(Nd.decide(ctx({ sites = { { x = 190, y = 0, sp = 1, wm = 0 } }, idle = 40, total = 40, incidents = { { x = 190, y = 0, t = 100000, w = 5 } } })) == nil, "site frappé d'un coup léger, grosse armée : le plancher absolu tient (menace 55)")
  local d3 = Nd.decide(ctx({ sites = { { x = 190, y = 0, sp = 1, wm = 0 } }, incidents = { { x = 150, y = 0, t = 99000, w = 120 } }, idle = 11 }))
  check(d3 ~= nil, "le même nid qui a frappé (tourelle détruite) est attaqué")
  local d4, w4 = Nd.decide(ctx({ idle = 9, total = 20 }))
  check(d4 == nil and w4.courts == 1, "armée insuffisante : 9 libres - 5 gardés = 4 < besoin " .. Nd.need({ sp = 2, wm = 1 }, 0))
  local d5 = Nd.decide(ctx({ idle = 5 + Nd.need({ sp = 2, wm = 1 }, 0), total = 20 }))
  check(d5 ~= nil, "armée juste suffisante : on part")
  local d6, w6 = Nd.decide(ctx({ sites = {} }))
  check(d6 == nil and w6.sites == 0, "aucun nid connu : aucune cible (jamais un point non reconnu)")
  -- le plus menaçant d'abord ; trop grand pour l'armée : le suivant
  local two = { { x = 60, y = 0, sp = 6, wm = 4 }, { x = -120, y = 0, sp = 1, wm = 0 } }
  local d7 = Nd.decide(ctx({ sites = two, idle = 14, total = 20 }))
  check(d7 and d7.x == -120, "le nid le plus menaçant est trop gros pour l'armée : on prend le suivant, faisable")
  local d8 = Nd.decide(ctx({ sites = two, idle = 40, total = 40 }))
  check(d8 and d8.x == 60, "armée suffisante : le plus menaçant d'abord")

  section("attentes 5, 10, 20, 40 min")
  local holds = {}
  local site = { x = 100, y = 0, sp = 2, wm = 1 }
  local t = 100000
  local waits = {}
  for i = 1, 5 do
    local h = Nd.fail(holds, site, t)
    waits[i] = (h["until"] - t) / 3600
    t = h["until"]
  end
  check(waits[1] == 5 and waits[2] == 10 and waits[3] == 20 and waits[4] == 40 and waits[5] == 40, "attentes : 5, 10, 20, 40, 40 min (" .. table.concat(waits, ",") .. ")")
  local hh = {}
  Nd.fail(hh, site, 1000)
  local dd = Nd.decide(ctx({ holds = hh, tick = 1000 + 100 }))
  check(dd == nil, "site en attente : pas d'opération")
  local dd2, wd2 = Nd.decide(ctx({ holds = hh, tick = 1000 + Nd.WAIT, idle = 20 }))
  check(dd2 ~= nil and dd2.fails == 1 and dd2.need > Nd.need(site, 0), "attente écoulée : on repart avec un besoin plus grand (" .. tostring(dd2 and dd2.need) .. ")")
  local near_site = { x = 130, y = 20, sp = 1, wm = 0 }
  check(Nd.hold_of(hh, near_site) ~= nil and Nd.hold_of(hh, { x = 400, y = 0 }) == nil, "l'attente vaut pour un site voisin (64 tuiles), pas pour un site lointain")
  Nd.success(hh, site)
  check(#hh == 0, "une victoire efface l'attente")
  check(Nd.need(site, 0) == Sd.clear_need(3) and Nd.need(site, 2) == 2 * Nd.need(site, 0), "besoin : +50 % par échec (2 échecs = double)")

  section("suivi de l'opération")
  local op = { engaged = 10, started = 0, dist = 100 }
  check(Nd.supervise(op, { tick = 600, alive = 10, spawners = 0 }) == "done", "plus aucun nid au moteur : terminé")
  check(Nd.supervise(op, { tick = 600, alive = 10, spawners = 2 }) == "continue", "des nids restent, aucune perte : on continue")
  check(Nd.supervise(op, { tick = 600, alive = 7, spawners = 2 }) == "continue", "3 morts sur 10 : on continue")
  check(Nd.supervise(op, { tick = 600, alive = 6, spawners = 2 }) == "retreat", "4 morts sur 10 (40 %) : repli")
  check(Nd.supervise(op, { tick = 600, alive = 0, spawners = 2 }) == "retreat", "plus personne : repli")
  check(Nd.supervise(op, { tick = 16401, alive = 10, spawners = 2 }) == "timeout", "délai dépassé : abandon")
  check(Nd.supervise(op, { tick = 16399, alive = 10, spawners = 2 }) == "continue", "avant le délai : on continue")
  check(Nd.supervise(op, { tick = 16401, alive = 10, spawners = 0 }) == "done", "nid détruit juste après le délai : terminé, pas abandon")
  check(Nd.deadline(0, 400) > Nd.deadline(0, 100), "une cible lointaine laisse plus de temps")

  section("carte de connaissance")
  local m = K.new()
  K.record(m, K.key_of(100, 0), 10, { nests = { { x = 100, y = 0 }, { x = 110, y = 4 } }, worms = { { x = 104, y = 0 } } })
  K.record(m, K.key_of(-300, 0), 10, { nests = { { x = -300, y = 0 } } })
  local nests, worms = Nd.known(m, { { x = 0, y = 0 } }, 200)
  check(#nests == 2 and #worms == 1, "seuls les nids vus à moins de 200 tuiles des biens sont connus (" .. #nests .. ")")
  local n_all = Nd.known(m, { { x = 0, y = 0 } }, 500)
  check(#n_all == 3, "à 500 tuiles : les 3 nids vus")
  local nz = Nd.known(K.new(), { { x = 0, y = 0 } }, 500)
  check(#nz == 0, "carte vide : aucun nid connu")
  check(Nd.purge(m, 100, 0, 40) == 2, "effacement des 2 nids détruits")
  local after = Nd.known(m, { { x = 0, y = 0 } }, 200)
  check(#after == 0, "un nid détruit n'est plus une cible")
  local still = Nd.known(m, { { x = -300, y = 0 } }, 50)
  check(#still == 1, "le nid voisin non détruit reste connu")

  section("attribution des rôles (Sd.assign)")
  local function soldiers(n)
    local out = {}
    for i = 1, n do out[i] = { id = i, x = (i % 5) * 3, y = 14 + math.floor(i / 5) * 2 } end
    return out
  end
  local cl = { { x = 100, y = 0, k = 3, killed = true, need = 9, reserve = 5, nid = true } }
  local o1 = Sd.assign({ tick = 100, hq = { x = 0, y = 0 }, agr = 100, soldiers = soldiers(14), threats = cl })
  local n1 = 0
  for _, o in pairs(o1) do if o.role == "clear" then n1 = n1 + 1 end end
  check(n1 == 9, "14 libres, besoin 9, garnison 5 : 9 partent (" .. n1 .. ")")
  local o2 = Sd.assign({ tick = 100, hq = { x = 0, y = 0 }, agr = 100, soldiers = soldiers(13), threats = cl })
  local n2 = 0
  for _, o in pairs(o2) do if o.role == "clear" then n2 = n2 + 1 end end
  check(n2 == 0, "13 libres : la garnison de 5 ne serait plus tenue, personne ne part")
  local o3 = Sd.assign({ tick = 100, hq = { x = 0, y = 0 }, agr = 100, soldiers = soldiers(14), threats = {},
    clearing = { x = 100, y = 0, need = 9, nid = true } })
  local n3 = 0
  for _, o in pairs(o3) do if o.role == "clear" then n3 = n3 + 1 end end
  check(n3 == 9, "opération en cours : le besoin de l'opération est tenu (" .. n3 .. ")")
  local o4 = Sd.assign({ tick = 100, hq = { x = 0, y = 0 }, agr = 100, soldiers = soldiers(14), threats = { { x = 100, y = 0, k = 1 } } })
  local n4 = 0
  for _, o in pairs(o4) do if o.role == "clear" then n4 = n4 + 1 end end
  check(n4 == 0, "règle d'avant inchangée : agressivité 100 et menace sans mort, personne ne part")
end

suite()
local p0 = passes

print("== mutants")
local keep = {}
local function patch(t, k, v) keep[#keep + 1] = { t, k, t[k] }; t[k] = v end
local function unpatch() for i = #keep, 1, -1 do local e = keep[i]; e[1][e[2]] = e[3] end keep = {} end
local function run_quiet()
  quiet = true
  local f0 = failures
  suite()
  quiet = false
  return failures - f0
end
local function mutant(name, apply)
  local pp, ff = passes, failures
  apply()
  local n = run_quiet()
  unpatch()
  passes, failures = pp, ff
  check(n > 0, "mutant « " .. name .. " » détecté (" .. n .. ")")
end
mutant("garnison jamais gardée", function() patch(Nd, "KEEP_MIN", 0) patch(Nd, "KEEP_PM", 0) end)
mutant("besoin nul", function() patch(Nd, "need", function() return 0 end) end)
mutant("aucune montée du besoin après échec", function() patch(Nd, "FAIL_PM", 0) end)
mutant("attentes ignorées", function() patch(Nd, "hold_of", function() return nil end) end)
mutant("attente fixe", function() patch(Nd, "WAIT_CAP", Nd.WAIT) end)
mutant("attente jamais doublée", function() patch(Nd, "fail", function(holds, site, tick)
  local h = { x = site.x, y = site.y, fails = 1, ["until"] = tick + Nd.WAIT }
  holds[#holds + 1] = h
  return h
end) end)
mutant("incidents ignorés", function() patch(Nd, "incident_now", function() return 0 end) end)
mutant("incident qui ne s'éteint jamais", function() patch(Nd, "INC_TTL", 1e12) end)
mutant("seuil de menace nul", function() patch(Nd, "MIN_MENACE", 0) patch(Nd, "MIN_MENACE_HIT", 0) end)
mutant("seuil du site frappé égal au seuil sans incident", function() patch(Nd, "MIN_MENACE_HIT", Nd.MIN_MENACE) end)
mutant("seuil jamais abaissé par le surplus", function() patch(Nd, "SURPLUS_MAX", 1) end)
mutant("plancher absolu nul", function() patch(Nd, "MIN_ABS", 0) end)
mutant("portée des biens nulle", function() patch(Nd, "REACH", 0) end)
mutant("repli jamais décidé", function() patch(Nd, "LOSS_MAX", 1001) end)
mutant("repli trop tôt", function() patch(Nd, "LOSS_MAX", 100) end)
mutant("délai infini", function() patch(Nd, "SIEGE_TICKS", 1e12) end)
mutant("fin sans le moteur (toujours en cours)", function()
  local s0 = Nd.supervise
  patch(Nd, "supervise", function(op, now) local j = {} for k, v in pairs(now) do j[k] = v end j.spawners = math.max(1, j.spawners) return s0(op, j) end)
end)
mutant("carte non purgée", function() patch(Nd, "purge", function() return 0 end) end)
mutant("tout nid vu à n'importe quelle distance", function()
  local k0 = Nd.known
  patch(Nd, "known", function(m, around, r) return k0(m, around, 1e9) end)
end)
mutant("vers comptés pour rien", function() patch(Nd, "WORM_R", 0) end)
mutant("sites non regroupés", function() patch(Nd, "SITE_R", 0) end)
mutant("attribution des incidents sans portée", function() patch(Nd, "ATTR_R", 1e9) end)
mutant("victoire sans effacement de l'attente", function() patch(Nd, "success", function() end) end)

print(string.format("[NIDS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
