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
  local f = battery(Q, false)
  check(f > 0, "mutant refusé : " .. name .. " (" .. f .. " échec(s))")
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
mutant("entrée = coffre entier (ancienne règle QUAI_FILL)", function(Q)
  local base = Q.quotas
  Q.quotas = function(...) local r = base(...); for _, c in ipairs(r.ins) do if not c.free then c.want = c.cap; c.low = 60 end end; return r end
end)

print(string.format("[QUOTAS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
