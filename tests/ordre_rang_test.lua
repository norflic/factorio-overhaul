--[[
  Lot VIDEO-ORDRE (lot 1 de la couverture vidéo, 7/11) : « ordre dans le rang ». Test hors jeu de shared/ai3/porte_rang.lua (Pr.order,
  Pr.tick, Pr.note, Pr.recent, Pr.big, Pr.median, Pr.big_hold) et de son branchement dans shared/ai3/capitalisation.lua (Ca.before,
  rank_gate). Demande du DC : « dans le rang retenu, construire d'abord ce qui couvre le PLUS GROS manque net mesuré. Ne pas reposer le
  même objet tant que le manque mesuré n'a pas bougé. Pas deux grosses unités de suite. »
  CRITÈRES (écrits avant le code, fo-logs/2026-11-07_VIDEO-COUVERTURE/SYNTHESE.txt, LOT 1) :
    C1.1 trois scènes (circuits verts ; chaîne du pack logistique ; chaîne du moteur, la seule chaîne « pétrole » que la capitalisation
         sait fabriquer : elle écarte toute recette à fluide) : l'option émise en premier est celle du plus gros manque net du rang
         retenu (le plus bas) : 3 sur 3, et l'ancien ordre (Ca.ORDRE_RANG éteint) ne la mettait pas en premier dans au moins 2 ;
    C1.2 sur le CORPUS de rang_test §9b (appels réels de Ca.requirements, 4 scènes), les options sont identiques à 0.6.61 (Ca.ORDRE_RANG
         éteint) hors les cas où le rang retenu contient deux options ; la liste des écarts attendus est écrite ci-dessous
         (EXPECTED_ECARTS) : aucune différence non listée, aucune ligne listée sans différence ; un écart n'est qu'une permutation
         des places du rang retenu, le reste de la liste ne bouge pas ;
    C1.3 un objet posé à la décision d n'est pas ré-ordonné à d+1 tant que le manque mesuré n'a pas changé : 0 doublon sur 20 décisions
         simulées (le témoin éteint en a) ; il revient après Pr.RETRY_MIN minutes (= Cf.RETRY) ou quand le signal bouge ; sans signal
         (L3 éteint) rien n'est retenu ;
    C1.4 anti-grosse unité : une grosse option ne passe pas derrière une grosse unité quand une autre option existe, elle passe après
         une autre option ; un mutant par règle ; au moins 10 mutants, tous refusés ;
    C1.5 déterminisme : même entrée, même sortie ; listes d'entrée inversées, même sortie (avec ai3_capitalisation_test, porte_rang_test,
         rang_test, repassés).
  Usage : lua5.2 tests/ordre_rang_test.lua [--ecarts]   (depuis la racine du mod). Fichier de TEST : il nomme des objets vanilla.
]]

package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local Ca0 = require("shared.ai3.capitalisation")
local Pr0 = require("shared.ai3.porte_rang")
local Cf = require("shared.ai3.confirmation")
local Rg0 = require("shared.ai3.rang")

local ECARTS = false
for i = 1, #arg do if arg[i] == "--ecarts" then ECARTS = true end end

local pass, fail, quiet = 0, 0, false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[ORDRE-RANG] ECHEC : " .. msg) end
  end
end
local function say(s) if not quiet then print("[ORDRE-RANG] " .. s) end end

local function sk(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end
local function ser(v)
  if type(v) == "table" then
    local parts = {}
    for _, k in ipairs(sk(v)) do
      if type(v[k]) ~= "function" then parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif type(v) == "number" then return string.format("%.17g", v) end
  return tostring(v)
end
local function deep(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = deep(v) end
  return c
end
local function reversed(t)
  local r = {}
  for i = #t, 1, -1 do r[#r + 1] = t[i] end
  return r
end

---------------------------------------------------------------------------------------------------
-- Relevé et scènes (vitesses et aires vanilla, comme tests/rang_cablage_test.lua)
---------------------------------------------------------------------------------------------------
local SP = { ["stone-furnace"] = 1, ["steel-furnace"] = 2, ["assembling-machine-1"] = 0.5, ["assembling-machine-2"] = 0.75,
  ["burner-mining-drill"] = 0.25, ["electric-mining-drill"] = 0.5, ["lab"] = 1 }
local AR = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 5 }
local KW = { ["stone-furnace"] = 90, ["steel-furnace"] = 90, ["burner-mining-drill"] = 150, ["electric-mining-drill"] = 90,
  ["assembling-machine-1"] = 75, ["assembling-machine-2"] = 150, ["lab"] = 60, ["boiler"] = 1800 }
local function dump()
  local d = F.dump()
  for _, t in ipairs(sk(d.techs)) do
    for _, r in ipairs(d.techs[t].unlocks or {}) do if d.recipes[r] then d.recipes[r].enabled = false end end
  end
  for _, e in ipairs(d.entities) do
    if SP[e.name] then e.speed = SP[e.name] end
    e.mining_area = AR[e.name]
    e.size = e.name == "burner-mining-drill" and 2 or 3
    e.energy_kw = KW[e.name]
  end
  for _, r in ipairs(d.resources) do r.mining_time = 1 end
  return d
end
local EXEC = { ["stone-furnace"] = true, ["steel-furnace"] = true, ["burner-mining-drill"] = true,
  ["electric-mining-drill"] = true, ["assembling-machine-1"] = true, ["assembling-machine-2"] = true }
local ALL = {}
for t in pairs(dump().techs) do ALL[t] = true end
local AUTO = { automation = true }

--- Base de départ : fer, cuivre et charbon couverts (le manque commence aux rangs 1 et plus), `iron` et `copper` fours de plaques.
local function base(D, sinks, techs, iron, copper)
  local inp = { data = D, state = { techs = techs }, stock = { coal = 3000 }, workers = 30, idle = 10,
    can_grow = true, traits = {}, weights = {}, open = {},
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
      { id = "dc", resource = "copper-ore", tiles = 200, amount = 5e5, open = true, dist = 80 },
      { id = "dk", resource = "coal", tiles = 200, amount = 5e5, open = true, dist = 50 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 12, deposit = "d1" },
      { entity = "electric-mining-drill", resource = "copper-ore", n = 12, deposit = "dc" },
      { entity = "electric-mining-drill", resource = "coal", n = 12, deposit = "dk" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = iron, where = "qg" },
      { entity = "stone-furnace", recipe = "copper-plate", n = copper, where = "dc" } },
    labs = { { entity = "lab", n = 8 } }, research = { queue = {}, rate = 450 },
    flows = { ["iron-ore"] = { made = 360 }, ["copper-ore"] = { made = 360 }, coal = { made = 100 },
      ["iron-plate"] = { made = iron * 18 }, ["copper-plate"] = { made = copper * 18 } }, sinks = sinks }
  return inp
end
local SCENES = {
  { "circuits verts", function(D) return base(D, { { item = "electronic-circuit", rate = 60 }, { item = "iron-gear-wheel", rate = 100 } }, AUTO, 30, 10) end },
  { "chaine du pack logistique", function(D) return base(D, { { item = "logistic-science-pack", rate = 30 } }, ALL, 40, 20) end },
  { "chaine du moteur (petrole)", function(D) return base(D, { { item = "engine-unit", rate = 20 } }, ALL, 40, 20) end },
}
local function with_power(inp)
  inp.power = { have_kw = 0, used_kw = 0, plant = { kw = 1800, burner_kw = 1800,
    items = { { "boiler", 1 }, { "steam-engine", 2 }, { "offshore-pump", 1 } } } }
  return inp
end

--- Une décision entière, interrupteurs posés le temps de l'appel.
local function decide(C, inp, st, ordre)
  local o0 = C.ORDRE_RANG
  C.ORDRE_RANG = ordre
  local ok, res = pcall(C.decide, inp, st or {})
  C.ORDRE_RANG = o0
  if not ok then error(res, 0) end
  return res
end
local function order_keys(res)
  local t = {}
  for _, o in ipairs(res.orders) do t[#t + 1] = o.key end
  return table.concat(t, ",")
end
local FAB = { chaine = true, packs = true, fours = true }
local function items_of(res)
  local s = {}
  for _, o in ipairs(res.orders) do if FAB[o.kind] and o.item then s[o.item] = true end end
  return s
end

--- Options du premier tour (ordre final de Ca.options) et ce qu'il faut pour juger le rang retenu : { opts, rstar, def, J }.
local function first_turn(C, inp, ordre)
  local o0 = C.ORDRE_RANG
  C.ORDRE_RANG = ordre
  local ok, J = pcall(C.decide_begin, inp, {})
  local opts = ok and C.options(J.ctx, J.plan, J.req) or nil
  C.ORDRE_RANG = o0
  if not ok then error(J, 0) end
  return opts, J
end
local function micro(x) return math.floor((x or 0) * 1e6 + 0.5) end
--- Oracle indépendant de la règle : rang retenu = rang le plus bas d'un manque net qu'une option sert ; l'option attendue en premier
--- est celle du plus gros manque net de ce rang (puis retour Tq, profondeur, clé).
local function oracle(C, opts, J)
  local rk = J.ctx.rang.rank
  local served, def = {}, {}
  for _, c in ipairs(opts) do
    local i = c.o.item or c.o.resource
    if i then served[i] = true end
  end
  local rstar = nil
  for _, i in ipairs(J.req.list) do
    local Ri = J.req.R[i] or 0
    if Ri > 0 and rk[i] ~= nil then
      local d = Ri - (J.plan.N[i] or 0) - (J.ctx.stock[i] or 0) / C.H_STOCK
      def[i] = d > 0 and d or 0
      if d > C.EPS and served[i] and (rstar == nil or rk[i] < rstar) then rstar = rk[i] end
    end
  end
  local grp = {}
  for _, c in ipairs(opts) do
    local i = c.o.item or c.o.resource
    if i and rk[i] == rstar then grp[#grp + 1] = c.o end
  end
  table.sort(grp, function(a, b)
    local am, bm = micro(def[a.item or a.resource]), micro(def[b.item or b.resource])
    if am ~= bm then return am > bm end
    if a.Tq ~= b.Tq then return a.Tq < b.Tq end
    if a.depth ~= b.depth then return a.depth < b.depth end
    return a.key < b.key
  end)
  return rstar, grp, def
end

---------------------------------------------------------------------------------------------------
-- Batterie de la règle PURE (rejouée sur chaque mutant de porte_rang.lua)
---------------------------------------------------------------------------------------------------
local function rec(key, item, rank, Tq, depth) return { key = key, item = item, rank = rank, Tq = Tq, depth = depth or 1 } end
local function keys_of(l)
  local t = {}
  for _, o in ipairs(l) do t[#t + 1] = o.key end
  return table.concat(t, ",")
end

local function unit_battery(Pr)
  local p0, f0 = pass, fail
  -- §1 Pr.order
  local A = rec("a", "ia", 2, 3000000)
  local B = rec("b", "ib", 2, 2000000)
  local Cc = rec("c", "ic", 3, 1000000)
  local Dd = rec("d", "id", 1, 4000000)
  local E = rec("e", "ie", 2, 5000000)
  local opts = { A, B, Cc, Dd, E }
  local new, old = Pr.order(opts, 2, { ia = 180, ib = 100, ie = 0 })
  check(keys_of(old) == "c,b,a,d,e", "§1 anciens : retour, profondeur, clé (" .. keys_of(old) .. ")")
  check(keys_of(new) == "c,a,b,d,e", "§1 le plus gros manque net du rang retenu d'abord, les autres options ne bougent pas (" .. keys_of(new) .. ")")
  check(keys_of(opts) == "a,b,c,d,e", "§1 la liste d'entrée n'est pas modifiée")
  local new2 = Pr.order({ E, Dd, Cc, B, A }, 2, { ia = 180, ib = 100, ie = 0 })
  check(keys_of(new2) == keys_of(new), "§1 l'ordre de la liste d'entrée est sans effet (" .. keys_of(new2) .. ")")
  local n3, o3 = Pr.order(opts, 2, { ia = 100, ib = 100, ie = 100 })
  check(keys_of(n3) == keys_of(o3), "§1 manques égaux : l'ancien ordre (retour d'abord) (" .. keys_of(n3) .. ")")
  local n4, o4 = Pr.order(opts, 2, { ia = 100 + 4e-7, ib = 100, ie = 100 })
  check(keys_of(n4) == keys_of(o4), "§1 manque comparé au millionième : 4e-7 d'écart ne change rien (" .. keys_of(n4) .. ")")
  local n5, o5 = Pr.order(opts, nil, { ia = 180 })
  check(keys_of(n5) == keys_of(o5), "§1 sans rang retenu rien ne change")
  local n6, o6 = Pr.order({ A }, 2, { ia = 180 })
  check(#n6 == 1 and n6[1] == A and o6[1] == A, "§1 une seule option au rang : rien ne change")
  local n7, o7 = Pr.order(opts, 2, { ia = 1, ib = 2, ie = 3 })
  check(keys_of(n7) == "c,e,b,d,a" and keys_of(o7) == "c,b,a,d,e", "§1 le rang retenu prend les places du rang (" .. keys_of(n7) .. ")")
  local Z1, Z2 = rec("k1", "z1", 2, 1000, 1), rec("k2", "z2", 2, 1000, 0)
  local n8 = Pr.order({ Z1, Z2 }, 2, {})
  check(keys_of(n8) == "k2,k1", "§1 manques nuls, retour égal : la profondeur (l'amont d'abord) puis la clé (" .. keys_of(n8) .. ")")

  -- §2 Pr.tick / Pr.note / Pr.recent
  local st = {}
  Pr.tick(st, 1)
  Pr.note(st, "x", 40)
  check(Pr.recent(st, "x", 40), "§2 posé à la minute 1, signal inchangé : récent")
  check(not Pr.recent(st, "y", 40), "§2 un autre objet n'est pas récent")
  check(Pr.recent(st, "x", 40.4), "§2 écart sous Pr.SIG_MOVE : inchangé")
  check(not Pr.recent(st, "x", 41), "§2 le signal a bougé : ré-ordonnable")
  check(not Pr.recent(st, "x", nil), "§2 sans signal (L3 éteint) : jamais récent")
  for _ = 1, Pr.RETRY_MIN - 1 do Pr.tick(st, 1) end
  check(Pr.recent(st, "x", 40), "§2 à Pr.RETRY_MIN - 1 minutes : encore récent")
  Pr.tick(st, 1)
  check(not Pr.recent(st, "x", 40), "§2 après Pr.RETRY_MIN minutes : ré-ordonnable")
  check(st.posed.x == nil, "§2 l'objet périmé est oublié (la mémoire ne grandit pas)")
  Pr.note(st, "w", nil)
  check(st.posed.w == nil, "§2 sans signal, rien n'est noté")
  check(not Pr.recent(nil, "x", 1) and not Pr.recent({}, "x", 1), "§2 mémoire absente : jamais récent")
  check(not Pr.recent({ clock = 10, posed = { x = { sig = 40, at = 4 } } }, "x", 40), "§2 posé il y a plus de Pr.RETRY_MIN minutes : jamais récent, même sans tick")

  -- §3 grosses unités
  check(Pr.big(21, 10) and not Pr.big(20, 10) and not Pr.big(5, 10), "§3 grosse = plus de BIG_K fois la médiane")
  check(not Pr.big(100, 0) and not Pr.big(100, nil) and not Pr.big(nil, 10), "§3 médiane nulle ou absente, coût absent : jamais grosse")
  check(Pr.median({ 5, 1, 9 }) == 5 and Pr.median({ 4, 1, 9, 2 }) == 2 and Pr.median({}) == nil, "§3 médiane (inférieure si pair)")
  local items = { { key = "c1", cost = 200 }, { key = "c2", cost = 210 }, { key = "p", cost = 20 }, { key = "q", cost = 30 }, { key = "r", cost = 25 } }
  local h1, med = Pr.big_hold(true, items)
  check(h1.c1 and h1.c2 and not h1.p and not h1.q and not h1.r and med == 30, "§3 après une grosse unité, les grosses cèdent (médiane " .. tostring(med) .. ")")
  local h2 = Pr.big_hold(false, items)
  check(next(h2) == nil, "§3 la précédente n'était pas grosse : rien n'est retenu")
  local h3 = Pr.big_hold(true, { { key = "c1", cost = 200 }, { key = "c2", cost = 210 } })
  local h4 = Pr.big_hold(true, { { key = "c1", cost = 200 } })
  check(next(h3) == nil and next(h4) == nil, "§3 deux coûts voisins, ou une seule option : aucune n'est grosse, la décision n'est pas vidée")
  check(Pr.BIG_K == 2 and Pr.RETRY_MIN == Cf.RETRY / 3600, "§3 donnée BIG_K = 2 ; Pr.RETRY_MIN = Cf.RETRY ÷ 3600 (" .. tostring(Pr.RETRY_MIN) .. ")")
  return pass - p0, fail - f0
end

---------------------------------------------------------------------------------------------------
-- Batterie branchée (Ca.decide), rejouée sur chaque mutant de capitalisation.lua et de porte_rang.lua
---------------------------------------------------------------------------------------------------
local function wired_battery(C)
  local p0, f0 = pass, fail
  local D = C.data(dump(), { exec = EXEC, exec_roles = { main = true, labo = true } })
  check(C.ORDRE_RANG == true, "§0 Ca.ORDRE_RANG allumé par défaut")

  -- C1.1 : trois scènes.
  local discr = 0
  for _, s in ipairs(SCENES) do
    local opts, J = first_turn(C, s[2](D), true)
    local rstar, grp = oracle(C, opts, J)
    local want = grp[1]
    check(rstar ~= nil and #grp >= 2, "C1.1 " .. s[1] .. " : un rang retenu qui contient deux options (r* " .. tostring(rstar) .. ", " .. #grp .. ")")
    check(want ~= nil and opts[1].o.key == want.key, "C1.1 " .. s[1] .. " : l'option émise en premier est celle du plus gros manque net du rang "
      .. tostring(rstar) .. " (" .. tostring(opts[1].o.key) .. " pour " .. tostring(want and want.key) .. ")")
    local res = decide(C, s[2](D), {}, true)
    check(want ~= nil and res.orders[1] ~= nil and res.orders[1].key == want.key, "C1.1 " .. s[1] .. " : l'ordre décidé en premier est le même ("
      .. tostring(res.orders[1] and res.orders[1].key) .. ")")
    local o0 = first_turn(C, s[2](D), false)
    if want ~= nil and o0[1].o.key ~= want.key then discr = discr + 1 end
  end
  check(discr >= 2, "C1.1 l'ancien ordre ne mettait pas cette option en premier dans " .. discr .. " scène(s) sur 3 (au moins 2)")

  -- Éteint : l'ancien ordre, ni mémoire ni état.
  do
    local st = {}
    local r = decide(C, SCENES[1][2](D), st, false)
    local r2 = decide(C, SCENES[1][2](D), {}, false)
    check(ser(r) == ser(r2) and st.posed == nil and st.clock == nil and st.last_big == nil,
      "§0 éteint : rien n'est écrit dans st (posed, clock, last_big)")
    local ro = first_turn(C, SCENES[1][2](D), false)
    check(ro[1].o.oTq == nil and ro[2].o.oTq == nil, "§0 éteint : aucune place prêtée")
  end

  -- C1.3 : 20 décisions de suite, signal mesuré inchangé.
  local function sim(n, mq, ordre, scene)
    local st, per = {}, {}
    for d = 1, n do
      local inp = (scene or SCENES[1][2])(D)
      if mq then inp.mq_build = mq(d) end
      per[d] = items_of(decide(C, inp, st, ordre))
    end
    return per, st
  end
  local per, st20 = sim(20, function() return {} end, true)
  local dup = 0
  for d = 1, 19 do
    for i in pairs(per[d]) do if per[d + 1][i] then dup = dup + 1 end end
  end
  check(dup == 0, "C1.3 0 doublon sur 20 décisions de suite (" .. dup .. ")")
  local first_again = nil
  for d = 2, 20 do if per[d]["copper-cable"] then first_again = d break end end
  check(per[1]["copper-cable"] and per[1]["iron-gear-wheel"] and first_again == 1 + Pr0.RETRY_MIN,
    "C1.3 l'objet revient après Pr.RETRY_MIN minutes, pas avant (décision " .. tostring(first_again) .. ")")
  local n_orders = 0
  for d = 1, 20 do for _ in pairs(per[d]) do n_orders = n_orders + 1 end end
  check(n_orders >= 4, "C1.3 la règle ne bloque pas tout : " .. n_orders .. " objet(s) ordonné(s) en 20 décisions")
  local perT = sim(20, function() return {} end, false)
  local dupT = 0
  for d = 1, 19 do for i in pairs(perT[d]) do if perT[d + 1][i] then dupT = dupT + 1 end end end
  check(dupT >= 1, "C1.3 témoin éteint : l'ancienne règle ré-ordonne le même objet (" .. dupT .. " doublon(s))")
  local perM = sim(4, function(d) return { ["copper-cable"] = d >= 3 and 5 or 0 } end, true)
  check(perM[2]["copper-cable"] == nil and perM[3]["copper-cable"] and perM[3]["iron-gear-wheel"] == nil,
    "C1.3 le signal du câble a bougé à la décision 3 : le câble revient, l'engrenage (inchangé) non")
  local perN = sim(3, nil, true)
  check(perN[2]["copper-cable"] and perN[2]["iron-gear-wheel"], "C1.3 sans signal mesuré (L3 éteint) : rien n'est retenu (règle d'avant)")
  check(st20.posed ~= nil and next(st20.posed) ~= nil and (st20.clock or 0) == 20, "C1.3 l'état est des nombres : horloge " .. tostring(st20.clock))

  -- C1.4 : pas deux grosses unités de suite (centrale puis suite).
  do
    local function power_scene()
      local inp = base(D, { { item = "electronic-circuit", rate = 60 }, { item = "iron-gear-wheel", rate = 100 } }, AUTO, 6, 4)
      inp.drills[3], inp.flows.coal = nil, nil -- 24 foreuses électriques sans courant : la centrale coûte plus de 2 fois la médiane
      return with_power(inp)
    end
    local r0 = decide(C, power_scene(), {}, true)
    check(r0.orders[1] and r0.orders[1].kind == "energie", "C1.4 la centrale est la première option d'une base neuve (" .. order_keys(r0) .. ")")
    local r1 = decide(C, power_scene(), { last_big = true }, true)
    local ie
    for i, o in ipairs(r1.orders) do if o.kind == "energie" then ie = i end end
    check(ie == nil or ie > 1, "C1.4 après une grosse unité, la centrale ne passe pas la première (" .. order_keys(r1) .. ")")
    local why = nil
    for _, rf in ipairs(r1.refus) do if rf.key == "energie" then why = rf.why end end
    check(ie ~= nil and ie > 1 or (why and why:find("grosse unite", 1, true)), "C1.4 refusée « grosse unite » ou décidée après une autre option (" .. tostring(why) .. ")")
    -- Mémoire d'une décision à l'autre : le dernier ordre de cette base neuve (les foreuses du fer) est une grosse unité.
    local function verts_scene()
      local inp = base(D, { { item = "electronic-circuit", rate = 60 } }, AUTO, 6, 4)
      inp.drills[3], inp.flows.coal, inp.stock = nil, nil, {}
      return inp
    end
    local st2 = {}
    local J1 = C.decide_begin(verts_scene(), st2)
    C.decide_step(J1)
    local rf1 = J1.ctx.refus["couvrir:d1"]
    while not C.decide_step(J1) do end
    check(rf1 == nil or not rf1.why:find("grosse unite", 1, true), "C1.4 première décision : aucune grosse unité avant elle, rien n'est retenu")
    local l1 = J1.res.orders[#J1.res.orders]
    check(st2.last_big == true and l1 ~= nil and l1.key == "couvrir:d1",
      "C1.4 le dernier ordre (les foreuses du fer) est une grosse unité, mémorisée dans st (" .. tostring(st2.last_big) .. ")")
    local J2 = C.decide_begin(verts_scene(), st2)
    C.decide_step(J2)
    local rf2 = J2.ctx.refus["couvrir:d1"]
    check(rf2 ~= nil and rf2.why:find("grosse unite", 1, true), "C1.4 décision suivante, premier tour : les foreuses du fer cèdent « grosse unite » ("
      .. tostring(rf2 and rf2.why) .. ")")
    while not C.decide_step(J2) do end
    local l2 = J2.res.orders[#J2.res.orders]
    check(l2 ~= nil and l2.key == "couvrir:d1", "C1.4 … et passent après une autre option, dans la même décision")
    -- Seule option possible : elle passe (aucune autre option).
    local rs = decide(C, with_power(base(D, { { item = "electronic-circuit", rate = 60 } }, AUTO, 30, 10)), { last_big = true }, true)
    check(#rs.orders >= 1, "C1.4 la décision n'est pas vidée par la règle (" .. order_keys(rs) .. ")")
  end

  -- C1.5 : déterminisme.
  do
    for _, s in ipairs(SCENES) do
      local a, b = decide(C, s[2](D), {}, true), decide(C, s[2](D), {}, true)
      check(ser(a) == ser(b), "C1.5 " .. s[1] .. " : même entrée, même sortie")
      local inp = s[2](D)
      inp.deposits, inp.drills, inp.machines, inp.sinks = reversed(inp.deposits), reversed(inp.drills), reversed(inp.machines), reversed(inp.sinks)
      local c = decide(C, inp, {}, true)
      check(order_keys(c) == order_keys(a), "C1.5 " .. s[1] .. " : listes d'entrée inversées, mêmes ordres")
    end
  end
  return pass - p0, fail - f0
end

---------------------------------------------------------------------------------------------------
-- C1.2 : corpus de tests/rang_test.lua §9b (appels réels de Ca.requirements), options contre l'ordre de 0.6.61
---------------------------------------------------------------------------------------------------
local EXPECTED_ECARTS = {} -- rempli plus bas (liste écrite après lecture de la sortie de --ecarts)

local function corpus_check(C)
  local function real_dump()
    local d = F.dump()
    for _, t in ipairs(sk(d.techs)) do
      for _, r in ipairs(d.techs[t].unlocks or {}) do if d.recipes[r] then d.recipes[r].enabled = false end end
    end
    return d
  end
  local function augmented_dump()
    local d = real_dump()
    local covered = {}
    for _, e in ipairs(d.entities) do for _, c in ipairs(e.crafting_categories or {}) do covered[c] = true end end
    local cats = {}
    for _, rn in ipairs(sk(d.recipes)) do
      local r = d.recipes[rn]
      if not r.hidden and not covered[r.category or ""] then cats[r.category or ""] = true end
    end
    for _, c in ipairs(sk(cats)) do
      d.entities[#d.entities + 1] = { name = "fictive-" .. c, type = "assembling-machine", item = "fictive-" .. c,
        crafting_categories = { c }, energy = "none", speed = 1 }
    end
    local D0 = C.data(d, {})
    local unp = C.unpackers(D0)
    local made = {}
    for n in pairs(D0.res) do made[n] = true end
    for n in pairs(D0.pumped) do made[n] = true end
    for _, rn in ipairs(D0.recipe_list) do
      if not unp[rn] then for _, p in ipairs(D0.recipes[rn].products) do made[p.name] = true end end
    end
    local used = {}
    for _, rn in ipairs(D0.recipe_list) do
      if not unp[rn] then
        for _, i in ipairs(D0.recipes[rn].ingredients) do if not made[i.name] then used[i.name] = i.fluid and "fluid" or "item" end end
      end
    end
    for _, n in ipairs(sk(used)) do
      d.resources[#d.resources + 1] = { entity = "fictive-" .. n, category = "fictive", products = { { type = used[n] or "item", name = n, amount = 1 } } }
    end
    return d
  end
  local V_SPEED = { ["stone-furnace"] = 1, ["steel-furnace"] = 2, ["electric-furnace"] = 2, ["assembling-machine-1"] = 0.5,
    ["assembling-machine-2"] = 0.75, ["assembling-machine-3"] = 1.25, ["burner-mining-drill"] = 0.25,
    ["electric-mining-drill"] = 0.5, ["pumpjack"] = 1, ["lab"] = 1, ["chemical-plant"] = 1, ["oil-refinery"] = 1, ["centrifuge"] = 1 }
  local V_AREA = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 5, ["pumpjack"] = 1 }
  local V_SIZE = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 3, ["stone-furnace"] = 2, ["steel-furnace"] = 2 }
  local V_KW = { ["stone-furnace"] = 90, ["steel-furnace"] = 90, ["electric-furnace"] = 180, ["burner-mining-drill"] = 150,
    ["electric-mining-drill"] = 90, ["assembling-machine-1"] = 75, ["assembling-machine-2"] = 150,
    ["assembling-machine-3"] = 375, ["lab"] = 60, ["boiler"] = 1800 }
  local function vanilla(d)
    for _, e in ipairs(d.entities) do
      if V_SPEED[e.name] then e.speed = V_SPEED[e.name] end
      e.mining_area = V_AREA[e.name]
      e.size = V_SIZE[e.name] or 3
      e.energy_kw = V_KW[e.name]
    end
    for _, r in ipairs(d.resources) do r.mining_time = r.entity == "uranium-ore" and 2 or 1 end
    return d
  end
  local DV = C.data(vanilla(real_dump()), { exec = EXEC, exec_roles = { main = true, labo = true } })
  local DVA = C.data(vanilla(augmented_dump()), {})
  local function scene(Dx, techs, sinks)
    return { data = Dx, state = { techs = techs }, stock = { ["electronic-circuit"] = 3000 }, workers = 30, idle = 10,
      can_grow = true, traits = {}, weights = {}, open = {},
      deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
        { id = "s2", resource = "iron-ore", tiles = 270, amount = 1e6, dist = 150 },
        { id = "dc", resource = "copper-ore", tiles = 200, amount = 5e5, open = true, dist = 80, smelt = "copper-plate",
          smelter = "stone-furnace" },
        { id = "dk", resource = "coal", tiles = 200, amount = 5e5, open = true, dist = 50 } },
      drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 4, deposit = "d1" },
        { entity = "burner-mining-drill", resource = "copper-ore", n = 4, deposit = "dc" },
        { entity = "burner-mining-drill", resource = "coal", n = 2, deposit = "dk" } },
      machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 6, where = "qg" },
        { entity = "stone-furnace", recipe = "iron-plate", n = 8, where = "d1" },
        { entity = "stone-furnace", recipe = "copper-plate", n = 4, where = "dc" } },
      labs = { { entity = "lab", n = 8 } },
      research = { queue = { { tech = "electronics", left = 27, time = 15, packs = { { "automation-science-pack", 1 } } },
        { tech = "fast-inserter", left = 2000, time = 15, packs = { { "automation-science-pack", 1 } } } }, rate = 450 },
      flows = { ["iron-ore"] = { made = 120 }, ["iron-plate"] = { made = 110 }, ["copper-plate"] = { made = 60 },
        ["coal"] = { made = 30 }, ["iron-gear-wheel"] = { made = 20, hand = 20 } },
      sinks = sinks }
  end
  local function capture(inp)
    local calls, orig = {}, C.requirements
    C.requirements = function(cx, pl)
      local req = orig(cx, pl)
      calls[#calls + 1] = { ctx = cx, plan = pl, req = req }
      return req
    end
    local ok, res = pcall(C.decide, inp, {})
    C.requirements = orig
    assert(ok, res)
    return calls
  end
  local auto = { automation = true }
  local RVA = Rg0.build(DVA, nil)
  local top = {}
  for k = 6, RVA.max do for _, n in ipairs(RVA.tiers[k]) do top[#top + 1] = { item = n, rate = 1 } end end
  local scenes = {
    { "riche", scene(DV, auto, { { item = "firearm-magazine", rate = 20, elastic = true } }) },
    { "packs hauts", scene(DV, ALL, { { item = "utility-science-pack", rate = 5 }, { item = "production-science-pack", rate = 5 } }) },
    { "uranium", scene(DV, ALL, { { item = "uranium-fuel-cell", rate = 2 }, { item = "rocket-control-unit", rate = 2 } }) },
    { "livre complet, rangs hauts", scene(DVA, ALL, top) },
  }
  local n_all, n_diff, n_two, bad, listed, seen = 0, 0, 0, {}, {}, {}
  for _, e in ipairs(EXPECTED_ECARTS) do listed[e] = true end
  local lines = {}
  for _, s in ipairs(scenes) do
    for j, c in ipairs(capture(s[2])) do
      if c.ctx.rang then
        n_all = n_all + 1
        local label = s[1] .. " #" .. j
        local function listing(ordre)
          local o0 = C.ORDRE_RANG
          C.ORDRE_RANG = ordre
          c.ctx.rg_info, c.ctx.rg_taken = nil, nil
          local ok, opts = pcall(C.options, c.ctx, c.plan, c.req)
          C.ORDRE_RANG = o0
          assert(ok, opts)
          local t = {}
          for _, x in ipairs(opts) do t[#t + 1] = x.o.key end
          return t, opts
        end
        local before = listing(false)
        local after, opts = listing(true)
        local same = table.concat(before, ",") == table.concat(after, ",")
        -- Le rang retenu contient-il deux options ? (rang le plus bas d'un manque servi, comme l'oracle)
        local rstar, grp = oracle(C, opts, { ctx = c.ctx, req = c.req, plan = c.plan })
        if #grp >= 2 then n_two = n_two + 1 end
        if not same then
          n_diff = n_diff + 1
          seen[label] = true
          lines[#lines + 1] = label
          -- permutation des places du rang retenu : toute position hors du rang garde sa clé
          local inrank = {}
          for _, x in ipairs(grp) do inrank[x.key] = true end
          local moved_outside = 0
          for p = 1, #before do
            if before[p] ~= after[p] and not (inrank[before[p]] and inrank[after[p]]) then moved_outside = moved_outside + 1 end
          end
          check(#grp >= 2 and moved_outside == 0, "C1.2 " .. label .. " : écart = permutation des places du rang retenu (" .. #grp
            .. " option(s), " .. moved_outside .. " place(s) hors du rang déplacée(s))")
        end
        if not same and not listed[label] then bad[#bad + 1] = label end
      end
    end
  end
  for _, e in ipairs(EXPECTED_ECARTS) do if not seen[e] then bad[#bad + 1] = e .. " (listé, sans écart)" end end
  if ECARTS then
    print("[ORDRE-RANG] écarts : " .. n_diff .. " sur " .. n_all .. " décisions du corpus (rang retenu à deux options : " .. n_two .. ")")
    for _, l in ipairs(lines) do print("[ORDRE-RANG]   " .. l) end
  end
  say(string.format("C1.2 corpus : %d appels, %d identiques à 0.6.61, %d écart(s) attendu(s), rang retenu à deux options : %d", n_all,
    n_all - n_diff, n_diff, n_two))
  check(n_all >= 10, "C1.2 le corpus a " .. n_all .. " appels (au moins 10)")
  check(#bad == 0, "C1.2 écarts non listés ou listés sans écart : " .. table.concat(bad, " | ", 1, math.min(#bad, 8)))
  check(#lines <= 10, "C1.2 au plus 10 écarts attendus (" .. #lines .. ")")
end

---------------------------------------------------------------------------------------------------
-- Exécution, coût, mutants
---------------------------------------------------------------------------------------------------
local BU = { unit_battery(Pr0) }
check(BU[2] == 0, "§1 à §3 : batterie pure verte (" .. BU[2] .. " échec(s))")
local _, BW = wired_battery(Ca0)
corpus_check(Ca0)

do -- coût en instructions : décision de la scène des circuits, ordre allumé contre éteint
  local D = Ca0.data(dump(), { exec = EXEC, exec_roles = { main = true, labo = true } })
  local function cost(ordre)
    local n = 0
    local inp = SCENES[1][2](D)
    debug.sethook(function() n = n + 1 end, "", 1)
    decide(Ca0, inp, {}, ordre)
    debug.sethook()
    return n
  end
  local off, on = cost(false), cost(true)
  print(string.format("[ORDRE-RANG] coût en instructions d'une décision (circuits verts) : éteint %d, allumé %d (%+.1f %%)", off, on, 100 * (on - off) / off))
  check(on <= off * 1.15 + 5000, string.format("coût : l'ordre dans le rang ajoute moins de 15 %% (%d contre %d)", on, off))
end

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local PR_SRC, CA_SRC = read("shared/ai3/porte_rang.lua"), read("shared/ai3/capitalisation.lua")

-- Mutants : { nom, cible ("pr" ou "ca"), texte exact, remplacement, batterie ("unit" : règle pure seule ; "wired" : branchée) }.
local MUT = {
  { "ordre : manque croissant", "pr", "if am ~= bm then return am > bm end", "if am ~= bm then return am < bm end", "unit" },
  { "ordre : tout le monde change de place", "pr", "if o.rank == rstar then slots[#slots + 1] = o at[#at + 1] = j end", "slots[#slots + 1] = o at[#at + 1] = j", "unit" },
  { "ordre : manque non arrondi", "pr", "math.floor((x or 0) * 1e6 + 0.5)", "(x or 0)", "unit" },
  { "ordre : ex aequo sans le retour", "pr", "    return Pr.old_before(a, b)\n  end)\n  local new = {}", "    return a.key < b.key\n  end)\n  local new = {}", "unit" },
  { "recent : horizon oublié", "pr", "  if (st.clock or 0) - p.at >= Pr.RETRY_MIN then return false end\n", "", "unit" },
  { "recent : signal ignoré", "pr", "return math.abs(sig - p.sig) <= Pr.SIG_MOVE", "return true", "unit" },
  { "recent : sans signal, retenu", "pr", "if sig == nil or st == nil or st.posed == nil then return false end",
    "if sig == nil then return true end if st == nil or st.posed == nil then return false end", "unit" },
  { "mémoire : jamais oubliée", "pr", "if st.clock - st.posed[k].at >= Pr.RETRY_MIN then st.posed[k] = nil end", "", "unit" },
  { "grosse unité : seuil inversé", "pr", "return cost > (k or Pr.BIG_K) * median", "return cost < (k or Pr.BIG_K) * median", "unit" },
  { "grosse unité : retenue sans grosse précédente", "pr", "if last_big then", "if true then", "unit" },
  { "grosse unité : tout est retenu", "pr", "if Pr.big(it.cost, med, k) then hold[it.key] = true end", "if it.cost ~= nil then hold[it.key] = true end", "unit" },
  { "médiane : le maximum", "pr", "return v[math.floor((#v + 1) / 2)]", "return v[#v]", "unit" },
  { "branchement : Pr.order jamais appelé", "ca", "local new, old = Pr.order(recs, g.rstar, net)", "local new, old = recs, recs", "wired" },
  { "branchement : la place prêtée n'est pas lue", "ca", "local at, bt = a.oTq or a.Tq, b.oTq or b.Tq", "local at, bt = a.Tq, b.Tq", "wired" },
  { "branchement : objet posé jamais noté", "ca", "if e.item ~= nil and sig ~= nil then Pr.note(st, e.item, sig[e.item] or 0) end", "", "wired" },
  { "branchement : grosse unité jamais mémorisée", "ca", "st.last_big = e.big", "st.last_big = false", "wired" },
  { "branchement : objet récent jamais retenu", "ca", "if cause[o.key] == nil and Pr.recent(st, o.item, sig[o.item] or 0) then", "if false then", "wired" },
  { "branchement : signal absent compté nul", "ca", "local sig = ctx.input and ctx.input.mq_build --", "local sig = (ctx.input and ctx.input.mq_build) or {} --", "wired" },
  { "branchement : horloge jamais avancée", "ca", "      Pr.tick(st, ctx.dt)\n", "", "wired" },
  { "branchement : réglage ignoré", "ca", "local on = Ca.ORDRE_RANG and st ~= nil", "local on = st ~= nil", "wired" },
}

local function cut(src, find, repl)
  local s, e = src:find(find, 1, true)
  if not s or src:find(find, e + 1, true) then return nil end
  return src:sub(1, s - 1) .. repl .. src:sub(e + 1)
end

local caught = 0
check(BU[2] == 0 and BW == 0, "mutants jugés sur des batteries vertes")
for _, mu in ipairs((BU[2] == 0 and BW == 0) and MUT or {}) do
  local src_pr, src_ca = PR_SRC, CA_SRC
  if mu[2] == "pr" then src_pr = cut(PR_SRC, mu[3], mu[4]) else src_ca = cut(CA_SRC, mu[3], mu[4]) end
  if not (src_pr and src_ca) then
    check(false, "mutant mal formé : " .. mu[1])
  else
    local Pm = assert(load(src_pr, "=porte-mutant"))()
    local saved_pr, saved_ca = package.loaded["shared.ai3.porte_rang"], package.loaded["shared.ai3.capitalisation"]
    package.loaded["shared.ai3.porte_rang"] = Pm
    local ok_load, Cm = pcall(function() return assert(load(src_ca, "=capi-mutant"))() end)
    local p0, f0 = pass, fail
    quiet = true
    local ok, err
    if mu[5] == "unit" then
      ok, err = pcall(unit_battery, Pm)
      if ok then
        local ok2, err2 = pcall(wired_battery, Cm)
        ok, err = ok2, err2
      end
    else
      ok, err = pcall(wired_battery, Cm)
    end
    debug.sethook()
    quiet = false
    package.loaded["shared.ai3.porte_rang"], package.loaded["shared.ai3.capitalisation"] = saved_pr, saved_ca
    local fails = fail - f0
    pass, fail = p0, f0
    local hit = (not ok_load) or (not ok) or fails > 0
    if hit then caught = caught + 1 end
    check(hit, "mutant NON refusé : " .. mu[1])
    print(string.format("[ORDRE-RANG] mutant « %s » : %s", mu[1], ok and (fails .. " contrôle(s) en échec") or ("plantage " .. tostring(err):sub(1, 90))))
  end
end
check(caught == #MUT and #MUT >= 10, string.format("mutants : %d refusés sur %d (au moins 10)", caught, #MUT))

print(string.format("[ORDRE-RANG] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
