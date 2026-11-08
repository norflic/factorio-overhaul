--[[
  Lot VIDEO L4 : banc HORS JEU des quotas dans le gabarit (shared/team/quotas.lua). Lancement, depuis la racine du mod :
  lua5.2 tests/quotas_test.lua
    1. quotas pour 3 recettes à débits différents (barre proportionnelle au débit nominal, partagée entre les coffres) ;
    2. gabarits réels de shared/team/modules.lua (fonderie à 1 et 4 fours : la barre suit le nominal calculé, I1) ;
    3. entrée : une minute d'ingrédients, bornée à la capacité du coffre (I2), objet sans consommation = hors quota ;
    4. alimentation coupée quand la sortie est pleine, COLLECTE gardée, seuil de collecte sous la capacité (pas d'interblocage) ;
    5. déterminisme (I3) ;
    6. coût en instructions (debug.sethook) ;
    7. mutants refusés.
]]
package.path = "./?.lua;" .. package.path
local Q0 = require("shared.team.quotas")
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end

-- données du banc (noms neutres : la règle n'en connaît aucun)
local STACK = { a = 100, b = 50, c = 200, x = 100, y = 50 }
local OPTS = { stack = STACK, slots = 32, collect_at = 200 }

local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end

local function battery(Q, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(c, msg) end
  end
  -- 1. trois recettes à débits différents (objets/s), un coffre de sortie chacune
  local rA = Q.quotas({ a = 0.5 }, { x = 0.5 }, { {} }, { { item = "x" } }, OPTS)          -- 300 a en 10 min → 3 cases de 100
  local rB = Q.quotas({ b = 0.1 }, { y = 0.2 }, { {} }, { { item = "y" } }, OPTS)          -- 60 b → 2 cases de 50
  local rC = Q.quotas({ c = 2.5 }, { x = 2.5 }, { {} }, { { item = "x" } }, OPTS)          -- 1500 c → 8 cases de 200
  ck(rA.main == "a" and rA.outs[1].cases == 3 and rA.outs[1].cap == 300, "A : 3 cases, 300 objets (" .. tostring(rA.outs[1].cases) .. ")")
  ck(rB.outs[1].cases == 2 and rB.outs[1].cap == 100, "B : 2 cases, 100 objets (" .. tostring(rB.outs[1].cases) .. ")")
  ck(rC.outs[1].cases == 8 and rC.outs[1].cap == 1600, "C : 8 cases, 1600 objets (" .. tostring(rC.outs[1].cases) .. ")")
  ck(rA.outs[1].cases ~= rB.outs[1].cases and rB.outs[1].cases ~= rC.outs[1].cases, "la barre suit le débit (jamais une constante)")
  -- partagée entre 3 coffres : 300 / 3 = 100 → 1 case chacun
  local r3 = Q.quotas({ a = 0.5 }, {}, { {}, {}, {} }, {}, OPTS)
  ck(#r3.outs == 3 and r3.outs[1].cases == 1 and r3.outs[3].cases == 1, "300 objets partagés entre 3 coffres : 1 case chacun")
  -- plafond du coffre
  local rBig = Q.quotas({ a = 100 }, {}, { {} }, {}, OPTS)
  ck(rBig.outs[1].cases == 32, "barre bornée aux cases du coffre (" .. tostring(rBig.outs[1].cases) .. ")")
  -- coffre à deux produits (ports d'un même coffre)
  local r2 = Q.quotas({ a = 0.5, b = 0.1 }, {}, { { items = { "a", "b" } } }, {}, OPTS)
  ck(r2.outs[1].cases == 5 and r2.outs[1].cap == 400, "coffre à deux produits : 3 + 2 cases (" .. tostring(r2.outs[1].cases) .. ")")
  -- objet sans pile (fluide, électricité) : aucun quota, jamais produit principal
  local rF = Q.quotas({ a = 0.1, z = 50 }, {}, { {} }, {}, OPTS)
  ck(rF.main == "a", "objet sans pile écarté du produit principal")

  -- 3. entrée : une minute, bornée à la capacité
  ck(rA.ins[1].want == 30 and rA.ins[1].low == 15, "entrée A : 30 x (1 min), refaite sous 15 (" .. tostring(rA.ins[1].want) .. ")")
  ck(rC.ins[1].want == 150, "entrée C : 150 x")
  local rHuge = Q.quotas({ a = 1 }, { x = 1000 }, { {} }, { { item = "x" } }, OPTS)
  ck(rHuge.ins[1].want <= 32 * 100, "I2 : la demande d'entrée ne dépasse pas le coffre (" .. tostring(rHuge.ins[1].want) .. ")")
  local r2in = Q.quotas({ a = 1 }, { x = 1 }, { {} }, { { item = "x" }, { item = "x" } }, OPTS)
  ck(r2in.ins[1].want == 30 and r2in.ins[2].want == 30, "60 x par minute sur 2 coffres d'entrée : 30 chacun")
  local rFree = Q.quotas({ a = 1 }, { x = 1 }, { {} }, { { item = "w" } }, OPTS)
  ck(rFree.ins[1].free == true, "entrée sans consommation nominale : hors quota (l'appelant garde sa règle)")
  local rLot = Q.quotas({ a = 0.01 }, { y = 0.01 }, { {} }, { { item = "y" } }, { stack = STACK, slots = 32, lot_min = 50 })
  ck(rLot.ins[1].want == 50, "charge minimale d'un voyage respectée (" .. tostring(rLot.ins[1].want) .. ")")
  local rLotF = Q.quotas({ a = 0.01 }, { y = 0.01, x = 5 }, { {} }, { { item = "y" }, { item = "x" } },
    { stack = STACK, slots = 32, lot_min = function(it) return STACK[it] end })
  ck(rLotF.ins[1].want == 50 and rLotF.ins[2].want == 300, "charge minimale par objet (une pile), sans rogner une minute plus grande")
  local rf = Q.refill(rA.ins[1], 10, 1000)
  ck(rf.due and rf.count == 20, "sous le seuil : remplir jusqu'à la minute (" .. tostring(rf.count) .. ")")
  ck(not Q.refill(rA.ins[1], 20, 1000).due, "au-dessus du seuil : rien")
  ck(not Q.refill(rA.ins[1], 0, 0).due, "stock nul : rien")
  ck(Q.refill(rA.ins[1], 0, 7).count == 7, "borné au stock")

  -- 4. alimentation et collecte
  ck(Q.feed_ok(rA, { 0 }), "sortie vide : alimenter")
  ck(Q.feed_ok(rA, { 269 }), "sortie à 89,7 % : alimenter")
  ck(not Q.feed_ok(rA, { 270 }), "sortie à 90 % : NE PLUS alimenter")
  ck(not Q.feed_ok(r3, { 100, 100, 70 }), "3 coffres à 90 % au total : ne plus alimenter")
  ck(Q.feed_ok(r3, { 100, 0, 0 }), "un coffre plein sur 3 : les autres machines consomment encore")
  ck(not Q.feed_ok(Q.quotas({ a = 0.5 }, {}, { {} }, {}, OPTS), { 300 }), "coffre plein : faux")
  ck(Q.feed_ok({ outs = {} }, {}), "module sans coffre borné (centrale) : toujours alimenté")
  for _, r in ipairs({ rA, rB, rC, r3, rBig }) do
    for i, o in ipairs(r.outs) do
      ck(o.collect_at and o.collect_at >= 1 and o.collect_at <= o.cap,
        string.format("seuil de collecte %s sous la capacité %d (sortie %d) : la sortie bornée reste collectée", tostring(o.collect_at), o.cap, i))
    end
  end
  ck(rB.outs[1].collect_at == 50, "petit module : collecte à 50 (la moitié de 100), pas au seuil de l'appelant 200")
  ck(rC.outs[1].collect_at == 200, "grand module : seuil de l'appelant (200) gardé")
  local tasks = {
    { key = "f1", ia1d = { pid = 1, mode = "fill" } }, { key = "c1", ia1d = { pid = 1, mode = "collect" } },
    { key = "f2", ia1d = { pid = 2, mode = "fill" } }, { key = "o", kind = "craft" },
  }
  local kept = Q.filter(tasks, { [1] = false, [2] = true })
  local keys = {}
  for _, t in ipairs(kept) do keys[#keys + 1] = t.key end
  ck(table.concat(keys, ",") == "c1,f2,o", "filtre : alimentation du module plein retirée, collecte gardée (" .. table.concat(keys, ",") .. ")")
  ck(#Q.filter(tasks, nil) == 4, "sans verdict : rien retiré")

  -- 8. Lot VIDEO-COUVERTURE 3 (C11, C3.2) : un coffre à PLUSIEURS produits partage ses cases en parts
  local two = { a = 0.5, b = 0.1 }                  -- 300 a (3 cases de 100) et 60 b (2 cases de 50) en 10 min
  local rP = Q.quotas(two, {}, { { items = { "a", "b" } } }, {}, OPTS)
  local sh = rP.outs[1].shares or {}
  ck(sh.a and sh.a.cases == 3 and sh.a.cap == 300 and sh.b and sh.b.cases == 2 and sh.b.cap == 100,
    "coffre à 2 produits, place pour tout : chacun garde 10 min de son débit (a 3 cases, b 2)")
  local sumcap = (sh.a and sh.a.cap or 0) + (sh.b and sh.b.cap or 0)
  ck(rP.outs[1].cap == sumcap and rP.outs[1].cases == 5, "capacité du coffre = somme des parts (" .. tostring(rP.outs[1].cap) .. ")")
  local o4 = { stack = STACK, slots = 4, collect_at = 200 }
  local r4 = Q.quotas(two, {}, { { items = { "a", "b" } } }, {}, o4)
  local s4 = r4.outs[1].shares
  ck(s4.a.cases + s4.b.cases == 4 and r4.outs[1].cases == 4, "barre de 4 cases pour 5 voulues : la somme des parts = les 4 cases")
  ck(s4.a.cases <= 3 and s4.b.cases <= 2 and s4.a.cases >= 1 and s4.b.cases >= 1, "chaque part borne à ce que le produit veut, au moins une case")
  ck(s4.a.cap + s4.b.cap == r4.outs[1].cap and r4.outs[1].cap <= 4 * 100, "somme des capacités = capacité du coffre, sous la barre")
  local r2c = Q.quotas(two, {}, { { items = { "a", "b" } } }, {}, { stack = STACK, slots = 2, collect_at = 200 })
  ck(r2c.outs[1].shares.a.cases == 1 and r2c.outs[1].shares.b.cases == 1, "barre de 2 cases, 2 produits : une case chacun")
  local r1c = Q.quotas(two, {}, { { items = { "a", "b" } } }, {}, { stack = STACK, slots = 1, collect_at = 200 })
  ck(r1c.outs[1].shares.a.cases == 1 and r1c.outs[1].shares.b.cases == 0 and r1c.outs[1].cases == 1,
    "une seule case pour 2 produits : au plus fort débit (a), jamais plus que la barre")
  local rb1 = Q.quotas({ a = 0.1, b = 0.5 }, {}, { { items = { "a", "b" } } }, {}, { stack = STACK, slots = 1, collect_at = 200 })
  ck(rb1.outs[1].shares.b.cases == 1 and rb1.outs[1].shares.a.cases == 0, "une case pour 2 produits : au plus fort débit (b), pas au premier nom")
  local rswap = Q.quotas({ b = 0.1, a = 0.5 }, {}, { { items = { "b", "a" } } }, {}, o4)
  ck(rswap.outs[1].shares.a.cases == s4.a.cases and rswap.outs[1].shares.b.cases == s4.b.cases, "l'ordre des produits ne change pas les parts")
  -- 2 coffres × 2 produits : les parts sont par coffre (la cible d'un produit est partagée entre ses coffres)
  local rQ = Q.quotas(two, {}, { { items = { "a", "b" } }, { items = { "a", "b" } } }, {}, OPTS)
  ck(rQ.outs[1].shares.a.cases == 2 and rQ.outs[1].shares.b.cases == 1 and rQ.outs[2].shares.a.cases == 2,
    "2 coffres à 2 produits : 150 a (2 cases) et 30 b (1 case) chacun")
  -- propriété : sur 300 cas, jamais plus que la barre, jamais plus que voulu, une case chacun dès que la barre le permet
  local seed = 12345
  local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return seed % n + 1 end
  local stacks = { p1 = 100, p2 = 50, p3 = 200, p4 = 100, p5 = 50 }
  local broken = 0
  for _ = 1, 300 do
    local nom, items = {}, {}
    local k = rnd(5)
    for j = 1, k do nom["p" .. j] = rnd(40) / 10 items[#items + 1] = "p" .. j end
    local slots = rnd(20)
    local rr = Q.quotas(nom, {}, { { items = items } }, {}, { stack = stacks, slots = slots, collect_at = 200 })
    local o = rr.outs[1]
    local sc, want_ok = 0, true
    local lone = Q.quotas(nom, {}, { { items = items } }, {}, { stack = stacks, slots = 1000, collect_at = 200 }).outs[1]
    for _, it in ipairs(items) do
      local x = o.shares[it]
      sc = sc + x.cases
      if x.cases > lone.shares[it].cases or x.cap ~= x.cases * stacks[it] then want_ok = false end
      if slots >= #items and x.cases < 1 then want_ok = false end
    end
    if sc > slots or o.cases ~= sc or not want_ok then broken = broken + 1 end
  end
  ck(broken == 0, "300 cas tires : parts toujours sous la barre, sous ce qui est voulu, une case chacun si possible (" .. broken .. " cas faux)")
  -- 8. Lot TV-QUOTAS (C11) : rapports mesurés sur les machines posées (modules de vitesse, de productivité, retirés), débits mis à l'échelle
  local o0, i0, n0 = Q.ratios({})
  ck(o0 == 1000 and i0 == 1000 and n0 == 0, "aucune machine relevee : 1000/1000, l'ancienne regle")
  local o1, i1, n1 = Q.ratios({ { speed_pm = 0, prod_pm = 0 }, { speed_pm = 0, prod_pm = 0 } })
  ck(o1 == 1000 and i1 == 1000 and n1 == 2, "machines sans module : 1000/1000 (modules retires : retour a l'identique)")
  local o2, i2 = Q.ratios({ { speed_pm = 500, prod_pm = 0 } })
  ck(o2 == 1500 and i2 == 1500, "modules de vitesse (+50 %) : sortie et entree x1,5 (" .. o2 .. "/" .. i2 .. ")")
  local o3, i3 = Q.ratios({ { speed_pm = -150, prod_pm = 200 } })
  ck(o3 == 1000 and i3 == 850, "productivite +20 % a -15 % de vitesse : sortie 0,85 x 1,2 = 1,02 -> 1000 (pas 5 %), entree 850 (" .. o3 .. "/" .. i3 .. ")")
  local o4, i4 = Q.ratios({ { speed_pm = 0, prod_pm = 400 } })
  ck(o4 == 1400 and i4 == 1000, "productivite seule : la sortie monte, l'entree ne bouge pas (" .. o4 .. "/" .. i4 .. ")")
  local o5, i5, n5 = Q.ratios({ { speed_pm = 1000, prod_pm = 0 }, { speed_pm = 0, prod_pm = 0 } })
  ck(o5 == 1500 and i5 == 1500 and n5 == 2, "une machine sur deux equipee (+100 %) : moyenne x1,5 (" .. o5 .. "/" .. i5 .. ")")
  local o6 = Q.ratios({ { speed_pm = 1010, prod_pm = 0 } })
  local o7 = Q.ratios({ { speed_pm = 1020, prod_pm = 0 } })
  ck(o6 == o7 and o6 == 2000, "arrondi au pas de 5 % : 2,01 et 2,02 donnent le meme rapport (pas de quota qui rebondit)")
  local o8, i8 = Q.ratios({ { speed_pm = 99999, prod_pm = 99999 } })
  ck(o8 == Q.RATIO_MAX_PM and i8 == Q.RATIO_MAX_PM, "rapport borne en haut")
  local o9, i9 = Q.ratios({ { speed_pm = -2000, prod_pm = -2000 } })
  ck(o9 == Q.RATIO_MIN_PM and i9 == Q.RATIO_MIN_PM, "rapport borne en bas")
  local o10 = Q.ratios({ { speed_pm = 0 / 0, prod_pm = 0 }, { speed_pm = 500, prod_pm = 0 }, { speed_pm = "x", prod_pm = 0 } })
  ck(o10 == 1500, "valeurs invalides (NaN, texte) ignorees")
  local sc = Q.scaled({ a = 0.5, b = 0.2 }, 1500)
  ck(math.abs(sc.a - 0.75) < 1e-9 and math.abs(sc.b - 0.3) < 1e-9, "debits mis au rapport")
  local base = Q.quotas({ a = 0.5 }, { x = 0.5 }, { {} }, { { item = "x" } }, OPTS)
  local fast = Q.quotas(Q.scaled({ a = 0.5 }, 2000), Q.scaled({ x = 0.5 }, 2000), { {} }, { { item = "x" } }, OPTS)
  ck(base.outs[1].cases == 3 and fast.outs[1].cases == 6 and fast.ins[1].want == 2 * base.ins[1].want,
    "modules de vitesse x2 : sortie 6 cases au lieu de 3, entree doublee (" .. fast.outs[1].cases .. ", " .. fast.ins[1].want .. " contre " .. base.ins[1].want .. ")")
  local again = Q.quotas(Q.scaled({ a = 0.5 }, 1000), Q.scaled({ x = 0.5 }, 1000), { {} }, { { item = "x" } }, OPTS)
  ck(again.outs[1].cases == base.outs[1].cases and again.ins[1].want == base.ins[1].want, "modules retires (rapport 1000) : quota d'avant")
  return fails
end

print("[QUOTAS] 1-5. règle")
check(battery(Q0, true) == 0, "batterie sans échec")
-- correction de l'attente du cas « coffres absents » (100 sur 100 lus) : le seul coffre lu est plein → faux
do
  local r3 = Q0.quotas({ a = 0.5 }, {}, { {}, {}, {} }, {}, OPTS)
  check(not Q0.feed_ok(r3, { 100, -1, nil }), "coffres absents non comptés : le seul coffre lu est plein → faux")
end

-- 2. gabarits réels
print("[QUOTAS] 2. gabarits de shared/team/modules.lua")
do
  local M = require("shared.team.modules")
  local function stack(it) return ({ ["iron-plate"] = 100, ["iron-ore"] = 50, coal = 50 })[it] end
  local g1 = M.GEN.smelter("stone-furnace", "iron-ore", 1)
  local g4 = M.GEN.smelter("stone-furnace", "iron-ore", 4)
  local ins = { { item = "iron-ore" }, { item = "coal" } }
  local q1 = Q0.of_gabarit(g1, ins, { stack = stack, slots = 32, collect_at = 200 }, { {} })
  local q4 = Q0.of_gabarit(g4, ins, { stack = stack, slots = 32, collect_at = 200 }, { {} })
  check(q1.main == "iron-plate", "produit principal lu au nominal")
  check(q1.outs[1].cases == 4 and q4.outs[1].cases == 15,
    string.format("barre suit le nominal : 1 four %d case(s), 4 fours %d (375 et 1500 plaques)", q1.outs[1].cases, q4.outs[1].cases))
  check(q4.ins[1].want == 150 and q4.ins[2].want == 11, string.format("entrée 4 fours : minerai %d, charbon %d", q4.ins[1].want, q4.ins[2].want))
  local qp = Q0.of_gabarit({ nominal = { a = 1 }, inputs = {}, ports = {
    { kind = "quai", io = "out", ent = 7, item = "a" }, { kind = "quai", io = "out", ent = 3, item = "a" },
    { kind = "quai", io = "out", ent = 9, item = "a", unite = true }, { kind = "tapis", io = "out", ent = 4 } } }, {}, OPTS)
  check(#qp.outs == 2 and qp.outs[1].cases == 3, "coffres de sortie lus aux ports « quai » (unité et tapis exclus), triés")
end

-- 5. déterminisme
do
  local a = Q0.quotas({ a = 0.5, b = 0.5 }, { x = 1, y = 1 }, { {}, { items = { "b" } } }, { { item = "y" }, { item = "x" } }, OPTS)
  local b = Q0.quotas({ b = 0.5, a = 0.5 }, { y = 1, x = 1 }, { {}, { items = { "b" } } }, { { item = "y" }, { item = "x" } }, OPTS)
  check(a.main == "a" and b.main == "a" and Q0.describe(a, { 1, 2 }) == Q0.describe(b, { 1, 2 }), "déterministe, égalité départagée par le nom")
end

-- 6. coût en instructions
print("[QUOTAS] 6. coût")
do
  local function count(fn)
    local c = 0
    debug.sethook(function() c = c + 1 end, "", 1)
    fn()
    debug.sethook()
    return c
  end
  local nominal, inputs, outs, ins, counts = {}, {}, {}, {}, {}
  local st = {}
  for i = 1, 4 do nominal["p" .. i] = 0.5 * i; st["p" .. i] = 100 end
  for i = 1, 8 do inputs["i" .. i] = 0.3 * i; st["i" .. i] = 50; ins[#ins + 1] = { item = "i" .. i } end
  for i = 1, 64 do outs[i] = {}; counts[i] = i end
  local opts = { stack = st, slots = 48, collect_at = 200 }
  local small = count(function() local q = Q0.quotas({ a = 0.5 }, { x = 0.5 }, { {} }, { { item = "x" } }, OPTS); Q0.feed_ok(q, { 1 }) end)
  local big, q = 0, nil
  big = count(function() q = Q0.quotas(nominal, inputs, outs, ins, opts) end)
  local feed = count(function() Q0.feed_ok(q, counts) end)
  local tasks = {}
  for i = 1, 200 do tasks[i] = { ia1d = { pid = i % 20, mode = (i % 2 == 0) and "fill" or "collect" } } end
  local verdicts = {}
  for i = 0, 19 do verdicts[i] = (i % 3 ~= 0) end
  local filt = count(function() Q0.filter(tasks, verdicts) end)
  print(string.format("[QUOTAS] instructions : module simple %d ; 64 coffres de sortie + 8 entrées : quotas %d, feed_ok %d ; filtre de 200 tournées %d",
    small, big, feed, filt))
  check(small < 2000 and big < 60000 and feed < 5000 and filt < 10000, "coût borné (quotas calculés à la pose, feed_ok par pensée)")
end

-- 7. mutants
print("[QUOTAS] 7. mutants")
local function mutant(name, patch)
  local Q = copy(Q0)
  patch(Q)
  local ok, f = pcall(battery, Q, false)
  check((not ok) or f > 0, "mutant refusé : " .. name .. " (" .. tostring(ok and f or "plantage") .. " échec(s))")
end
-- mutants SUR LA SOURCE (les fonctions de la règle s'appellent entre elles : un patch de copie ne les atteindrait pas)
local function src_mutant(name, from, to)
  local fh = assert(io.open("shared/team/quotas.lua", "rb"))
  local src = fh:read("*a")
  fh:close()
  local i, j = src:find(from, 1, true)
  assert(i, "mutant sans effet : " .. name)
  local Q = assert(load(src:sub(1, i - 1) .. to .. src:sub(j + 1), "=mutant"))()
  local ok, f = pcall(battery, Q, false)
  check((not ok) or f > 0, "mutant refusé : " .. name .. " (" .. tostring(ok and f or "plantage") .. " échec(s))")
end
mutant("alimentation gardée quand la sortie est pleine", function(Q) Q.feed_ok = function() return true end end)
mutant("barre constante", function(Q)
  local base = Q.quotas
  Q.quotas = function(...) local r = base(...); for _, o in ipairs(r.outs) do o.cases, o.cap = 4, 400 end; return r end
end)
mutant("collecte bloquée par feed_ok", function(Q)
  Q.filter = function(tasks, verdicts)
    local out = {}
    for _, t in ipairs(tasks or {}) do
      local j = t.ia1d
      if not (j and verdicts and verdicts[j.pid] == false) then out[#out + 1] = t end
    end
    return out
  end
end)
mutant("entrée non bornée au coffre (I2)", function(Q)
  local base = Q.quotas
  Q.quotas = function(nominal, inputs, outs, ins, opts)
    local r = base(nominal, inputs, outs, ins, opts)
    for j, c in ipairs(r.ins) do
      if not c.free then c.want = math.ceil(60 * inputs[c.item]) end
    end
    return r
  end
end)
mutant("seuil de collecte non borné à la capacité (interblocage)", function(Q)
  local base = Q.quotas
  Q.quotas = function(...) local r = base(...); for _, o in ipairs(r.outs) do o.collect_at = 200 end; return r end
end)
mutant("barre non partagée entre les coffres", function(Q)
  local base = Q.quotas
  Q.quotas = function(nominal, inputs, outs, ins, opts)
    local r = base(nominal, inputs, outs, ins, opts)
    if #r.outs > 1 then local one = base(nominal, inputs, { {} }, ins, opts).outs[1]; for i = 1, #r.outs do r.outs[i] = one end end
    return r
  end
end)
src_mutant("parts non bornées par la barre (somme > cases ouvertes)", "if total <= slots then return alloc end", "do return alloc end")
src_mutant("la première case de chaque produit oubliée", "for k = 1, n do alloc[k] = 1 extra_total", "for k = 1, n do alloc[k] = 0 extra_total")
src_mutant("restes non servis (cases ouvertes perdues)", "if x.room > 0 and x.r > 0 then", "if false then")
src_mutant("faible barre : les cases au hasard du nom, pas au plus fort débit", "if ra ~= rb then return ra > rb end", "")
mutant("coffre à plusieurs produits sans parts", function(Q)
  local base = Q.quotas
  Q.quotas = function(...) local r = base(...) for _, o in ipairs(r.outs) do o.shares = {} end return r end
end)
src_mutant("rapport de vitesse oublie (productivite seule)", "so + (1000 + sp) * (1000 + pr) / 1000", "so + (1000) * (1000 + pr) / 1000")
src_mutant("productivite oubliee dans la sortie", "so + (1000 + sp) * (1000 + pr) / 1000", "so + (1000 + sp)")
src_mutant("entree qui suit la productivite", "si + (1000 + sp)", "si + (1000 + sp) * (1000 + pr) / 1000")
src_mutant("rapport non arrondi au pas", "floor(v / n / Q.RATIO_STEP_PM + 0.5 + EPS) * Q.RATIO_STEP_PM", "floor(v / n + 0.5)")
src_mutant("rapport non borne en haut", "max(Q.RATIO_MIN_PM, min(Q.RATIO_MAX_PM, r))", "max(Q.RATIO_MIN_PM, r)")
src_mutant("rapport non borne en bas", "max(Q.RATIO_MIN_PM, min(Q.RATIO_MAX_PM, r))", "min(Q.RATIO_MAX_PM, r)")
src_mutant("moyenne remplacee par la somme", "floor(v / n / Q.RATIO_STEP_PM", "floor(v / Q.RATIO_STEP_PM")
src_mutant("debits non mis a l'echelle", "out[k] = (type(v) == \"number\") and (v * pm / 1000) or v", "out[k] = v")
mutant("entrée = coffre entier (ancienne règle QUAI_FILL)", function(Q)
  local base = Q.quotas
  Q.quotas = function(...) local r = base(...); for _, c in ipairs(r.ins) do if not c.free then c.want = c.cap; c.low = 60 end end; return r end
end)

print(string.format("[QUOTAS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
