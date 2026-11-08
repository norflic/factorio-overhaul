--[[
  Lot CONSOLIDATION-TIERS (8/11) : test hors jeu de la maturité des tiers (shared/ai3/porte_rang.lua : Pr.solid_step, Pr.solid_mark,
  Pr.solid_list, Pr.decide(input.solid) ; branchement : rank_gate, solid_rows, consolidation dans shared/ai3/capitalisation.lua ;
  journal [FO-RANG] : script/ai3/rang_trace.lua, vérifié par sa partie pure). Question du DC (8/11) : « est-ce qu'ils ont effectivement
  respecté l'ordre des tiers [...] construit des machines d'assemblage de tiers supérieurs avant d'avoir fait et solidifié et consolidé
  les tiers inférieurs. » Critères (fo-logs/2026-11-08_CONSOLIDATION-TIERS/CRITERES.md) :
    C1 un ordre de rang r attend tant qu'une chaîne de rang < r qui l'alimente n'est pas consolidée (80 % de sa demande, 3 relevés de suite) ;
    C2 la cause est écrite (« rang r : chaine X de rang k non consolidee : debit a/b ... ») ;
    C3 la chaîne à consolider passe devant (r*) ; C4 sans issue ou sans mesure : rien n'est retenu ;
    C5 l'attente est bornée (levée) ; C6 déterminisme, listes triées ; C7 interrupteur : éteint, la décision est celle d'avant ;
    C8 mutants refusés.
  §1 Pr.solid_step ; §2 Pr.decide et Pr.solid_list ; §3 décisions entières (scènes du pack logistique) ; §4 déterminisme, état, interrupteurs ;
  §5 mutants appliqués au SOURCE de porte_rang.lua et de capitalisation.lua ; §6 rejeu de la partie scarlet (0.6.58) en miniature.
  Usage : lua5.2 tests/consolidation_test.lua   (depuis la racine du mod). Fichier de TEST : il nomme des objets vanilla.
]]

package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local Ca = require("shared.ai3.capitalisation")
local Rg = require("shared.ai3.rang")
local Pr0 = require("shared.ai3.porte_rang")

local pass, fail, quiet = 0, 0, false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[CONSOLIDATION] ECHEC : " .. msg) end
  end
end
local function say(s) if not quiet then print("[CONSOLIDATION] " .. s) end end

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
local function no_function(v, seen)
  seen = seen or {}
  if type(v) == "function" then return false end
  if type(v) == "table" and not seen[v] then
    seen[v] = true
    for _, k in ipairs(sk(v)) do if not no_function(v[k], seen) then return false end end
  end
  return true
end
local function has(s, pat) return s ~= nil and tostring(s):find(pat, 1, true) ~= nil end

---------------------------------------------------------------------------------------------------
-- §1 + §2 : batterie de la règle PURE (rejouée sur chaque mutant de porte_rang.lua)
---------------------------------------------------------------------------------------------------
local D0 = Ca.data(F.dump(), {})
local function pick(i) return D0.recipes[i], D0.recipes[i] and nil or "aucune recette" end
local RC = Rg.chain(D0, pick, { "iron-gear-wheel", "electronic-circuit", "copper-cable", "inserter", "transport-belt" })

local function row(item, rank, demand, rate, extra)
  local r = { item = item, rank = rank, demand = demand, rate = rate, stock_cover = 0 }
  for k, v in pairs(extra or {}) do r[k] = v end
  return r
end
--- Rejoue n minutes d'un même relevé ; rend le dernier verdict de `item`, l'état et toutes les lignes.
local function run(Pr, S, n, mk, item)
  local last, all = nil, {}
  for t = 1, n do
    local v, lines = Pr.solid_step(S, 1, mk(t))
    last = v[item]
    for _, l in ipairs(lines) do all[#all + 1] = l end
  end
  return last, all
end

local function battery(Pr)
  local p0, f0 = pass, fail

  -- §1 Seuil, durée (3 relevés de suite), fenêtre.
  local S = Pr.solid_new()
  local v1 = Pr.solid_step(S, 1, { row("x", 2, 10, 9) })
  check(v1.x and v1.x.ok == false, "§1 un relevé au-dessus du seuil ne suffit pas")
  local v2 = Pr.solid_step(S, 1, { row("x", 2, 10, 9) })
  check(v2.x.ok == false and has(v2.x.text, "tenu 2/3 min"), "§1 deux relevés : pas encore, le texte dit tenu 2/3 (" .. tostring(v2.x.text) .. ")")
  local v3 = Pr.solid_step(S, 1, { row("x", 2, 10, 9) })
  check(v3.x.ok == true, "§1 trois relevés de suite à 90 % : consolidée")
  local S2 = Pr.solid_new()
  local last = run(Pr, S2, 6, function() return { row("x", 2, 10, 7.9) } end, "x")
  check(last.ok == false and has(last.text, "sous 80% depuis"), "§1 79 % de la demande pendant 6 minutes : jamais consolidée (" .. tostring(last.text) .. ")")
  local S3 = Pr.solid_new()
  last = run(Pr, S3, 4, function() return { row("x", 2, 10, 8.0) } end, "x")
  check(last.ok == true, "§1 80 % exactement : consolidée")
  local S4 = Pr.solid_new()
  last = run(Pr, S4, 5, function() return { row("x", 2, 10, 0, { stock_cover = 8 }) } end, "x")
  check(last.ok == true, "§1 le stock compte : stock ÷ H à 80 % de la demande sans aucun débit")
  local S5 = Pr.solid_new()
  last = run(Pr, S5, 5, function() return { row("x", 2, 10, 20) } end, "x")
  check(last.ok == true and last.pct >= 199, "§1 le débit au-dessus de la demande consolide aussi")

  -- §1 Hystérésis : une minute creuse (fenêtre de 5) ne défait pas une chaîne consolidée ; une vraie chute si.
  local SH = Pr.solid_new()
  run(Pr, SH, 5, function() return { row("x", 2, 10, 9) } end, "x")
  local vh = Pr.solid_step(SH, 1, { row("x", 2, 10, 0) })
  check(vh.x.ok == true, "§1 une minute à 0 dans une fenêtre de 5 : la chaîne reste consolidée (" .. tostring(vh.x.pct) .. " %)")
  local lh
  for _ = 1, 4 do lh = Pr.solid_step(SH, 1, { row("x", 2, 10, 0) }) end
  check(lh.x.ok == false, "§1 cinq minutes à 0 : elle perd son statut")

  -- §1 Arrêtée : jamais consolidée (sauf stock qui tient seul la demande).
  local SA = Pr.solid_new()
  last = run(Pr, SA, 6, function() return { row("x", 2, 10, 9, { stopped = true }) } end, "x")
  check(last.ok == false and last.stopped == true and has(last.text, "arretee"), "§1 chaîne arrêtée : pas consolidée, le texte le dit (" .. tostring(last.text) .. ")")
  local SA2 = Pr.solid_new()
  last = run(Pr, SA2, 6, function() return { row("x", 2, 10, 0, { stopped = true, stock_cover = 9 }) } end, "x")
  check(last.ok == true, "§1 arrêtée mais le stock tient la demande : consolidée")

  -- §1 Non mesuré (fluide, flux absent) : rien à juger.
  local SU = Pr.solid_new()
  local vu = Pr.solid_step(SU, 1, { row("x", 2, 10, nil) })
  check(vu.x.unmeasured == true and vu.x.ok == false, "§1 sans mesure : non jugée")
  check(#Pr.solid_list(vu, function() return true, true end) == 0, "§1 sans mesure : ne retient rien même avec option et machines")
  local vz = Pr.solid_step(SU, 1, { row("y", 2, 0, 5) })
  check(vz.y == nil, "§1 demande nulle : pas de verdict")

  -- §1 Clock : le texte compte les minutes sans consolidation.
  local SC = Pr.solid_new()
  last = run(Pr, SC, 8, function() return { row("x", 2, 10, 0) } end, "x")
  check(last.bad_min == 7, "§1 depuis 7 min après 8 relevés (" .. tostring(last.bad_min) .. ")")

  -- §1 Levée : l'attente est comptée quand la chaîne retient un ordre ; épuisée, elle est levée une fois, la ligne dit pourquoi.
  local SL = Pr.solid_new()
  local lifted_at, said, marks = nil, 0, 0
  for t = 1, 30 do
    local v, lines = Pr.solid_step(SL, 1, { row("x", 2, 10, 0) })
    for _, l in ipairs(lines) do if has(l, "LEVEE") then said = said + 1 end end
    if v.x.lifted and lifted_at == nil then lifted_at = t end
    if not v.x.lifted then
      local ln = Pr.solid_mark(SL, "x", v.x.text)
      if ln then marks = marks + 1 end
    end
  end
  check(lifted_at == Pr.WAIT_MAX + 1, "§1 levée au relevé " .. tostring(lifted_at) .. " (" .. (Pr.WAIT_MAX + 1) .. " attendu : 20 minutes d'ordres retenus)")
  check(said == 1, "§1 une seule ligne de levée (" .. said .. ")")
  check(marks == 1, "§1 une seule ligne d'attente (" .. marks .. ")")
  check(#Pr.solid_list({ x = { item = "x", rank = 2, lifted = true, text = "t" } }, function() return true, true end) == 0, "§1 une chaîne levée ne retient plus")
  -- Pas de retenue : l'attente ne court pas.
  local SN = Pr.solid_new()
  last = run(Pr, SN, 40, function() return { row("x", 2, 10, 0) } end, "x")
  check(last.lifted == false, "§1 une chaîne qui ne retient aucun ordre n'use pas son attente (40 minutes, jamais levée)")
  -- Consolidation après levée : ligne de journal, la mémoire repart.
  local logs = {}
  for t = 1, 6 do
    local _, lines = Pr.solid_step(SL, 1, { row("x", 2, 10, 12) })
    for _, l in ipairs(lines) do logs[#logs + 1] = l end
  end
  check(#logs == 1 and has(logs[1], "consolidee") and has(logs[1], "apres la levee"), "§1 consolidée après la levée : une ligne (" .. tostring(logs[1]) .. ")")
  local vv = Pr.solid_step(SL, 1, { row("x", 2, 10, 0) })
  check(not vv.x.lifted and SL.items.x.wait == 0, "§1 consolidée, l'attente repart de zéro")

  -- §1 Oubli : plus de demande depuis Pr.SOLID_KEEP minutes, la mémoire s'efface (taille bornée).
  local SF = Pr.solid_new()
  Pr.solid_step(SF, 1, { row("x", 2, 10, 9), row("y", 2, 10, 9) })
  for _ = 1, Pr.SOLID_KEEP + 2 do Pr.solid_step(SF, 1, { row("y", 2, 10, 9) }) end
  check(SF.items.x == nil and SF.items.y ~= nil, "§1 une chaîne sans demande est oubliée, l'autre reste")
  check(no_function(SF), "§1 l'état ne garde aucune fonction")

  -- §1 Ordre d'entrée sans effet.
  local SO1, SO2 = Pr.solid_new(), Pr.solid_new()
  local ra = { row("a", 2, 10, 9), row("b", 3, 20, 1), row("c", 2, 5, 0) }
  local rb = { ra[3], ra[1], ra[2] }
  local va, la = Pr.solid_step(SO1, 1, ra)
  local vb, lb = Pr.solid_step(SO2, 1, rb)
  check(ser(va) == ser(vb) and ser(la) == ser(lb) and ser(SO1) == ser(SO2), "§1 l'ordre des lignes d'entrée est sans effet")

  -- §2 Pr.decide : cause, priorité, sans issue, indirect, même rang.
  local deps = Pr.deps(RC)
  local function order(item, extra)
    local o = { key = "o:" .. item, item = item, rank = RC.rank[item] }
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
  end
  local rk_cable = RC.rank["copper-cable"]
  local sol = { { item = "copper-cable", rank = rk_cable, option = false, text = "debit 0.0/90.0 sous 80% depuis 4 min" } }
  local r1 = Pr.decide({ orders = { order("electronic-circuit") }, short = {}, deps = deps, solid = sol })
  check(#r1.held == 1 and r1.held[1].cause == string.format("rang %d : chaine copper-cable de rang %d non consolidee : debit 0.0/90.0 sous 80%% depuis 4 min",
    RC.rank["electronic-circuit"], rk_cable), "§2 cause écrite au format du DC (" .. tostring(r1.held[1] and r1.held[1].cause) .. ")")
  check(r1.waiting["copper-cable"] == true, "§2 la chaîne qui retient est signalée")
  local r2 = Pr.decide({ orders = { order("electronic-circuit"), order("iron-gear-wheel") }, short = {}, deps = deps, solid = sol })
  check(#r2.allowed == 1 and r2.allowed[1].item == "iron-gear-wheel", "§2 la porte est CIBLÉE : la chaîne sans câble passe (" .. tostring(r2.allowed[1] and r2.allowed[1].item) .. ")")
  local r3 = Pr.decide({ orders = { order("inserter") }, short = {}, deps = deps, solid = sol })
  check(#r3.held == 1, "§2 dépendance INDIRECTE (inserter -> circuit -> câble) retenue")
  local r4 = Pr.decide({ orders = { order("copper-cable") }, short = {}, deps = deps, solid = sol })
  check(#r4.allowed == 1, "§2 la chaîne non consolidée peut elle-même être étendue (pas son propre bloqueur)")
  local r5 = Pr.decide({ orders = { order("electronic-circuit", { pile = 1 }) }, short = {}, deps = deps, solid = sol })
  check(#r5.allowed == 1, "§2 R0 et R1 de la pile jamais retenus")
  check(Pr.decide({ orders = { order("electronic-circuit") }, short = {}, deps = deps, solid = {} }).held[1] == nil, "§2 solid vide : rien n'est retenu")
  check(Pr.decide({ orders = { order("electronic-circuit") }, short = {}, deps = deps }).held[1] == nil, "§2 solid absent : la règle d'avant")
  local same = { { item = "electronic-circuit", rank = RC.rank["electronic-circuit"], option = true, text = "t" } }
  check(#Pr.decide({ orders = { order("electronic-circuit", { key = "o:autre" }) }, short = {}, deps = { ["electronic-circuit"] = { ["electronic-circuit"] = true } }, solid = same }).held == 0,
    "§2 même rang : pas de blocage")
  -- Priorité : r* = rang le plus bas d'une chaîne avec option ; sans option, la chaîne retient mais ne fixe pas r*.
  local with_opt = { { item = "copper-cable", rank = rk_cable, option = true, text = "t" } }
  check(Pr.decide({ orders = {}, short = {}, deps = deps, solid = with_opt }).rstar == rk_cable, "§2 chaîne non consolidée AVEC option : r* (priorité à sa consolidation)")
  check(Pr.decide({ orders = {}, short = {}, deps = deps, solid = sol }).rstar == nil, "§2 sans option : pas de r*")
  local rs = Pr.decide({ orders = {}, short = { { item = "iron-plate", rank = 1, option = true } }, deps = deps, solid = sol })
  check(rs.rstar == 1, "§2 une chaîne sans option ne remonte pas r* d'un manque plus bas (" .. tostring(rs.rstar) .. ")")
  local both = Pr.decide({ orders = { order("electronic-circuit") }, short = { { item = "copper-cable", rank = rk_cable, option = true } }, deps = deps, solid = sol })
  check(has(both.held[1].cause, "non consolidee"), "§2 manque ET non consolidée : la ligne de la consolidation (le débit mesuré)")
  -- Cause départagée par (rang, nom) quel que soit l'ordre.
  local two_a = { { item = "iron-gear-wheel", rank = 2, option = false, text = "g" }, { item = "copper-cable", rank = 2, option = false, text = "c" } }
  local two_b = { two_a[2], two_a[1] }
  local ca = Pr.decide({ orders = { order("inserter") }, short = {}, deps = deps, solid = two_a }).held[1].cause
  local cb = Pr.decide({ orders = { order("inserter") }, short = {}, deps = deps, solid = two_b }).held[1].cause
  check(ca == cb and has(ca, "copper-cable"), "§2 cause : le plus petit (rang, nom) quel que soit l'ordre des chaînes (" .. tostring(ca) .. ")")
  -- Toutes les chaînes qui retiennent l'ordre attendent en parallèle (pas seulement celle de la cause).
  local rw2 = Pr.decide({ orders = { order("inserter") }, short = {}, deps = deps,
    solid = { two_a[2], { item = "electronic-circuit", rank = RC.rank["electronic-circuit"], option = false, text = "e" } } })
  check(rw2.waiting["copper-cable"] and rw2.waiting["electronic-circuit"], "§2 l'attente court sur CHAQUE chaîne qui retient l'ordre (levée d'ensemble)")

  -- §2 Pr.solid_list : issue.
  local ver = { a = { item = "a", rank = 2, ok = false, text = "ta" }, b = { item = "b", rank = 2, ok = true }, c = { item = "c", rank = 3, ok = false, text = "tc" },
    d = { item = "d", rank = 3, ok = false, stopped = true, text = "td" } }
  local function issue(x)
    if x == "a" then return true, false elseif x == "c" then return false, false end
    return false, false
  end
  local lst = Pr.solid_list(ver, issue)
  check(#lst == 2 and lst[1].item == "a" and lst[1].option == true and lst[2].item == "d", "§2 issue : option -> retient ; consolidée -> non ; sans issue -> non ; arrêtée -> oui ("
    .. #lst .. ")")
  local lst2 = Pr.solid_list(ver, function(x) return false, x == "c" end)
  check(#lst2 == 2 and lst2[1].item == "c" and lst2[2].item == "d", "§2 machines ou ordre déjà là : issue (" .. #lst2 .. ")")

  -- §2 Pr.front : les options des chaînes qui retiennent passent devant, l'ordre relatif de chaque groupe est gardé.
  local lst3 = { "a", "b", "c", "d", "e" }
  local fr = Pr.front(lst3, function(e) return e == "d" or e == "b" end)
  check(table.concat(fr) == "bdace", "§2 front : b et d devant, a c e derrière dans leur ordre (" .. table.concat(fr) .. ")")
  check(table.concat(lst3) == "abcde", "§2 front : la liste d'entrée n'est pas modifiée")
  check(table.concat(Pr.front(lst3, function() return false end)) == "abcde" and table.concat(Pr.front(lst3, function() return true end)) == "abcde",
    "§2 front : rien ou tout devant, rien ne change")

  return pass - p0, fail - f0
end

local _, BASE = battery(Pr0)

---------------------------------------------------------------------------------------------------
-- §3 : décisions entières (relevé d'un vrai livre, chaîne du pack logistique)
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
local ALL = {}
for t in pairs(dump().techs) do ALL[t] = true end
local D = Ca.data(dump(), {})

local POSED = { { entity = "assembling-machine-2", recipe = "copper-cable", n = 6, where = "qg" },
  { entity = "assembling-machine-2", recipe = "electronic-circuit", n = 6, where = "qg" },
  { entity = "assembling-machine-2", recipe = "iron-gear-wheel", n = 4, where = "qg" } }
local BIG = { ["copper-cable"] = { made = 5000 }, ["electronic-circuit"] = { made = 5000 }, ["iron-gear-wheel"] = { made = 5000 } }

local function scene(posed, flows_extra, solid, tweak)
  local inp = { data = D, state = { techs = ALL }, stock = { coal = 3000 }, workers = 30, idle = 10,
    can_grow = true, traits = {}, weights = {}, open = {},
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
      { id = "dc", resource = "copper-ore", tiles = 200, amount = 5e5, open = true, dist = 80 },
      { id = "dk", resource = "coal", tiles = 200, amount = 5e5, open = true, dist = 50 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 12, deposit = "d1" },
      { entity = "electric-mining-drill", resource = "copper-ore", n = 12, deposit = "dc" },
      { entity = "electric-mining-drill", resource = "coal", n = 12, deposit = "dk" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 40, where = "qg" },
      { entity = "stone-furnace", recipe = "copper-plate", n = 20, where = "dc" } },
    labs = { { entity = "lab", n = 8 } }, research = { queue = {}, rate = 450 },
    flows = { ["iron-ore"] = { made = 360 }, ["copper-ore"] = { made = 360 }, coal = { made = 100 },
      ["iron-plate"] = { made = 720 }, ["copper-plate"] = { made = 360 } },
    sinks = { { item = "logistic-science-pack", rate = 30 } }, can_exec = function() return nil end, solid_mesure = solid }
  for _, m in ipairs(posed or {}) do inp.machines[#inp.machines + 1] = { entity = m.entity, recipe = m.recipe, n = m.n, where = m.where, n_cap = m.n_cap } end
  for k, v in pairs(flows_extra or {}) do inp.flows[k] = v end
  if tweak then tweak(inp) end
  return inp
end
--- Une décision entière ; rend (J, res).
local function decide(inp, st)
  local J = Ca.decide_begin(inp, st)
  while not Ca.decide_step(J) do end
  return J, J.res
end
local function refus_of(res, key)
  for _, r in ipairs(res.refus) do if r.key == key then return r.why end end
  return nil
end
local function ordered(res, key)
  for _, o in ipairs(res.orders) do if o.key == key then return true end end
  return false
end

do
  -- §3.1 Câble, circuit et engrenage POSÉS mais qui ne produisent rien : les tiers au-dessus attendent, la cause est écrite.
  local st = {}
  local J, res
  for t = 1, 6 do J, res = decide(scene(POSED, {}, true), st) end
  local why = refus_of(res, "chaine:inserter")
  check(why ~= nil and has(why, "non consolidee") and has(why, "copper-cable"), "§3.1 l'inserter attend le câble posé qui ne produit rien (" .. tostring(why) .. ")")
  check(not ordered(res, "chaine:inserter") and not ordered(res, "chaine:transport-belt"), "§3.1 aucun ordre de rang supérieur n'est émis")
  check(has(refus_of(res, "chaine:transport-belt"), "iron-gear-wheel"), "§3.1 la courroie attend l'engrenage, pas le câble (porte ciblée)")
  -- Sans la mesure (interrupteur du runtime absent) : la règle d'avant, les ordres passent.
  local st0 = {}
  for t = 1, 6 do J, res = decide(scene(POSED, {}, nil), st0) end
  check(ordered(res, "chaine:inserter") or ordered(res, "chaine:transport-belt"), "§3.1 sans input.solid_mesure : la règle d'avant (un ordre de rang supérieur passe)")
  check(st0.solid == nil, "§3.1 sans mesure, st.solid n'est pas créé")
  -- Interrupteur du code.
  Ca.CONSOLIDE_RANG = false
  local st1 = {}
  for t = 1, 6 do J, res = decide(scene(POSED, {}, true), st1) end
  Ca.CONSOLIDE_RANG = true
  check(ordered(res, "chaine:inserter") or ordered(res, "chaine:transport-belt"), "§3.1 Ca.CONSOLIDE_RANG éteint : la règle d'avant")
  check(st1.solid == nil, "§3.1 éteint, st.solid n'est pas créé")
  local o_off, o_old = {}, {}
  for _, o in ipairs(res.orders) do o_off[#o_off + 1] = o.key end
  local st2 = {}
  for t = 1, 6 do J, res = decide(scene(POSED, {}, nil), st2) end
  for _, o in ipairs(res.orders) do o_old[#o_old + 1] = o.key end
  check(table.concat(o_off, ",") == table.concat(o_old, ","), "§3.1 éteint = sans mesure : mêmes ordres")
end

do
  -- §3.2 Débits mesurés suffisants : la porte s'ouvre après les 3 relevés, pas avant ; la chaîne qui vient d'être ordonnée attend à son tour.
  local st = {}
  local seen_hold, opened_at = nil, nil
  for t = 1, 6 do
    local _, res = decide(scene(POSED, BIG, true), st)
    if t <= 2 then
      seen_hold = (seen_hold == nil or seen_hold) and not ordered(res, "chaine:inserter") and not ordered(res, "chaine:transport-belt")
    elseif opened_at == nil and (ordered(res, "chaine:inserter") or ordered(res, "chaine:transport-belt")) then
      opened_at = t
    end
  end
  check(seen_hold == true, "§3.2 pas d'ordre de rang supérieur avant les 3 relevés")
  check(opened_at == 3, "§3.2 la porte s'ouvre au troisième relevé (" .. tostring(opened_at) .. ")")
  local _, res = decide(scene(POSED, BIG, true), st)
  check(has(refus_of(res, "packs:logistic-science-pack"), "non consolidee"), "§3.2 le pack attend la courroie qui vient d'être ordonnée (" .. tostring(refus_of(res, "packs:logistic-science-pack")) .. ")")
end

do
  -- §3.3 Manque SANS ISSUE : le câble n'a ni machine, ni ordre, et l'exécutant le refuse : il ne retient rien.
  local posed3 = { POSED[2], POSED[3] }
  local st = {}
  local res
  for t = 1, 5 do
    local inp = scene(posed3, { ["electronic-circuit"] = BIG["electronic-circuit"], ["iron-gear-wheel"] = BIG["iron-gear-wheel"] }, true)
    inp.can_exec = function(kind, item) if item == "copper-cable" then return "non" end return nil end
    _, res = decide(inp, st)
  end
  check(ordered(res, "chaine:inserter"), "§3.3 le câble sans issue ne retient pas l'inserter")
  for _, r in ipairs(res.refus) do check(not has(r.why, "chaine copper-cable"), "§3.3 aucun refus ne nomme le câble sans issue (" .. tostring(r.why) .. ")") end
end

do
  -- §3.4 Levée : une chaîne posée qui ne produit jamais retient au plus Pr.WAIT_MAX minutes, une ligne le dit, le tier suivant n'attend pas
  -- 20 minutes de PLUS (les attentes courent en parallèle).
  local st = {}
  local gate_off, first_line, logs = nil, nil, {}
  for t = 1, 40 do
    local J, res = decide(scene(POSED, {}, true), st)
    for _, l in ipairs(J.ctx.cons_log or {}) do logs[#logs + 1] = { t, l } end
    if gate_off == nil and ordered(res, "chaine:inserter") then gate_off = t end
  end
  check(gate_off ~= nil and gate_off <= 3 + Pr0.WAIT_MAX + 1, "§3.4 l'inserter finit par passer au plus ~" .. (3 + Pr0.WAIT_MAX + 1) .. " relevés (" .. tostring(gate_off) .. ")")
  local lev = 0
  for _, e in ipairs(logs) do if has(e[2], "LEVEE") then lev = lev + 1 end end
  check(lev >= 1, "§3.4 au moins une ligne de levée au journal (" .. lev .. ")")
  local att = 0
  for _, e in ipairs(logs) do if has(e[2], "en attente sur la chaine") then att = att + 1 end end
  check(att >= 1 and att <= 12, "§3.4 les lignes d'attente sont rares : " .. att .. " en 40 minutes")
end

---------------------------------------------------------------------------------------------------
-- §4 : déterminisme, état, journal
---------------------------------------------------------------------------------------------------
do
  local function trace(rev)
    local st, out = {}, {}
    for t = 1, 6 do
      local inp = scene(POSED, t >= 3 and BIG or {}, true)
      if rev then
        local m = {}
        for i = #inp.machines, 1, -1 do m[#m + 1] = inp.machines[i] end
        inp.machines = m
        local s = {}
        for i = #inp.sinks, 1, -1 do s[#s + 1] = inp.sinks[i] end
        inp.sinks = s
      end
      local J, res = decide(inp, st)
      local keys = {}
      for _, o in ipairs(res.orders) do keys[#keys + 1] = o.key end
      local rs = {}
      for _, r in ipairs(res.refus) do rs[#rs + 1] = r.key .. "=" .. tostring(r.why) end
      out[#out + 1] = table.concat(keys, ",") .. "|" .. table.concat(rs, ";") .. "|" .. table.concat(J.ctx.cons_log or {}, ";")
    end
    return table.concat(out, "\n"), st
  end
  local a, sa = trace(false)
  local b = trace(false)
  local c = trace(true)
  check(a == b, "§4 même entrée, même sortie (ordres, refus, journal)")
  check(a == c, "§4 lignes d'entrée inversées, même sortie")
  check(no_function(sa) and sa.solid ~= nil, "§4 st.solid ne garde que des nombres, chaînes et tables")
  local n = 0
  for _ in pairs(sa.solid.items) do n = n + 1 end
  check(n >= 1 and n <= 40, "§4 mémoire bornée : " .. n .. " chaîne(s) suivie(s)")
end

do
  -- §4 Coût : une décision à 24 chaînes demandées (debug.sethook), mesuré contre la même décision sans la mesure.
  local function cost(solid)
    local st = {}
    for _ = 1, 3 do decide(scene(POSED, BIG, solid), st) end
    local c = 0
    debug.sethook(function() c = c + 1 end, "", 1)
    decide(scene(POSED, BIG, solid), st)
    debug.sethook()
    return c
  end
  local with, without = cost(true), cost(nil)
  say(string.format("§4 instructions d'une décision : %d avec la maturité des tiers, %d sans (+%d)", with, without, with - without))
  check(with - without < 60000, "§4 la maturité des tiers ajoute moins de 60 000 instructions à une décision (" .. (with - without) .. ")")
end

do
  -- §4 Journal [FO-RANG] : la partie pure de script/ai3/rang_trace.lua n'est pas chargeable hors jeu (Storage) ; son contrat est tenu ici
  -- par le texte des lignes (sans préfixe, sans saut de ligne, ASCII).
  local S = Pr0.solid_new()
  local _, lines = Pr0.solid_step(S, 1, { row("x", 2, 10, 0) })
  local ln = Pr0.solid_mark(S, "x", "debit 0.0/10.0 sous 80% depuis 0 min")
  check(ln ~= nil and not ln:find("\n") and not ln:find("[\128-\255]"), "§4 ligne d'attente : une seule ligne ASCII (" .. tostring(ln) .. ")")
  check(Pr0.solid_mark(S, "x", "t") == nil, "§4 pas de seconde ligne d'attente")
  check(Pr0.solid_mark(S, "absent", "t") == nil, "§4 chaîne inconnue : rien")
  check(#lines == 0, "§4 aucun compte rendu au premier relevé")
end

---------------------------------------------------------------------------------------------------
-- §6 : la partie scarlet (0.6.58) en miniature. Le module de circuits est FINI à 79,3 min, les circuits avancés sont DEMANDÉS à 79,8 min.
-- Ici : le tier du dessus (inserter, qui consomme les circuits) est demandé à la minute qui suit la fin du module de circuits.
---------------------------------------------------------------------------------------------------
do
  local st = {}
  local circuits_done = 5
  local asked = nil
  for t = 1, 14 do
    local posed = { POSED[1], POSED[3] }
    local flows = { ["copper-cable"] = BIG["copper-cable"], ["iron-gear-wheel"] = BIG["iron-gear-wheel"] }
    if t >= circuits_done then posed[#posed + 1] = POSED[2] end -- le module de circuits vient d'être fini : il ne produit rien encore
    if t >= circuits_done + 3 then flows["electronic-circuit"] = BIG["electronic-circuit"] end -- il produit à partir de 3 minutes plus tard
    local _, res = decide(scene(posed, flows, true), st)
    if asked == nil and ordered(res, "chaine:inserter") and t >= circuits_done then asked = t end
  end
  check(asked ~= nil and asked >= circuits_done + 3 + Pr0.SOLID_MIN - 1, "§6 l'inserter n'est demandé qu'après 3 relevés de débit des circuits : relevé " .. tostring(asked)
    .. " (circuits finis au " .. circuits_done .. ", débit dès le " .. (circuits_done + 3) .. ")")
  -- Le témoin : la règle d'avant demande l'inserter DÈS que le module est fini.
  local st0 = {}
  local asked0 = nil
  for t = 1, 14 do
    local posed = { POSED[1], POSED[3] }
    if t >= circuits_done then posed[#posed + 1] = POSED[2] end
    local _, res = decide(scene(posed, { ["copper-cable"] = BIG["copper-cable"], ["iron-gear-wheel"] = BIG["iron-gear-wheel"] }, nil), st0)
    if asked0 == nil and ordered(res, "chaine:inserter") and t >= circuits_done then asked0 = t end
  end
  check(asked0 ~= nil and asked0 <= circuits_done, "§6 témoin (règle d'avant) : l'inserter est demandé tout de suite (relevé " .. tostring(asked0) .. ")")
end

---------------------------------------------------------------------------------------------------
-- §7 : RETARD de croissance par étage, démarrage normal (demande de team-lead : au plus 5 min par étage). Simulation pure d'une usine qui
-- démarre : chaque chaîne ordonnée est posée `build` minutes plus tard et produit tout de suite à plein débit. Retard d'un étage = minutes
-- entre le début de production de l'étage du dessous et l'ordre de l'étage au-dessus (la règle d'avant ordonnait tout à la minute 1).
---------------------------------------------------------------------------------------------------
do
  local ITEMS = { "iron-gear-wheel", "copper-cable", "electronic-circuit", "inserter" }
  local BELOW = { ["iron-gear-wheel"] = false, ["copper-cable"] = false, ["electronic-circuit"] = "copper-cable", inserter = "electronic-circuit" }
  for _, build in ipairs({ 3, 5 }) do
    local st, first, posed_at = {}, {}, {}
    for t = 1, 30 do
      local posed, flows = {}, {}
      for _, it in ipairs(ITEMS) do
        if posed_at[it] and t >= posed_at[it] then
          posed[#posed + 1] = { entity = "assembling-machine-2", recipe = it, n = 6, where = "qg" }
          flows[it] = { made = 5000 }
        end
      end
      local _, res = decide(scene(posed, flows, true), st)
      for _, o in ipairs(res.orders) do
        local it = o.key:match("^chaine:(.+)$")
        if it and not first[it] then first[it] = t posed_at[it] = t + build end
      end
    end
    local worst = 0
    for _, it in ipairs(ITEMS) do
      local below = BELOW[it]
      if below and first[it] and posed_at[below] then
        local delay = first[it] - posed_at[below]
        if delay > worst then worst = delay end
      end
    end
    say(string.format("§7 construction %d min : ordres à %s ; retard max par étage %d min après le début de production de l'étage du dessous", build,
      "gear " .. tostring(first["iron-gear-wheel"]) .. ", cable " .. tostring(first["copper-cable"]) .. ", circuit " .. tostring(first["electronic-circuit"])
        .. ", inserter " .. tostring(first["inserter"]), worst))
    check(first["inserter"] ~= nil and worst <= 3, "§7 construction " .. build .. " min : chaque étage est ordonné au plus 3 min après que celui du dessous produit (" .. worst .. ")")
    check(first["iron-gear-wheel"] <= 3, "§7 construction " .. build .. " min : le premier étage attend au plus 3 relevés (" .. tostring(first["iron-gear-wheel"]) .. ")")
  end
end

---------------------------------------------------------------------------------------------------
-- §5 : mutants
---------------------------------------------------------------------------------------------------
local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
do
  local SRC = read("shared/ai3/porte_rang.lua")
  local MUT = {
    { "seuil à 0 %", "Pr.SOLID_PCT = 80 ", "Pr.SOLID_PCT = 0 " },
    { "durée nulle", "Pr.SOLID_MIN = 3 ", "Pr.SOLID_MIN = 1 " },
    { "sans hystérésis", "Pr.SOLID_DROP = 60 ", "Pr.SOLID_DROP = 80 " },
    { "fenêtre d'un relevé", "Pr.SOLID_WINDOW = 5 ", "Pr.SOLID_WINDOW = 1 " },
    { "pas de levée", "v.lifted = e.wait >= Pr.WAIT_MAX - Pr.EPS", "v.lifted = false" },
    { "attente qui ne compte pas", "if e.blk then e.wait = e.wait + (dt or 0) end", "e.wait = e.wait + 0" },
    { "attente comptée même sans retenue", "if e.blk then e.wait", "if true then e.wait" },
    { "sans issue qui retient", "if option or exists or v.stopped then", "if true then" },
    { "non mesuré jugé", "if r.rate == nil then", "if false then" },
    { "stock ignoré", "local pct = (mean + stock) * 100 / r.demand", "local pct = mean * 100 / r.demand" },
    { "arrêtée ignorée", "local stopped = r.stopped == true and stock * 100 / r.demand < Pr.SOLID_PCT", "local stopped = false" },
    { "horloge figée", "S.clock = (S.clock or 0) + (dt or 0)", "S.clock = (S.clock or 0)" },
    { "ligne d'attente à chaque relevé", "if e.said == nil then\n    e.said = \"wait\"", "if true then\n    e.said = \"wait\"" },
    { "consolidée sans durée tenue", "if e.run >= Pr.SOLID_MIN then e.solid = true end", "if e.run >= 1 then e.solid = true end" },
    { "décision sans consolidation", "for _, s in ipairs(input.solid or {}) do", "for _, s in ipairs({}) do" },
    { "r* même sans option", "if b.solid == nil or b.solid.option then rstar = b.rank break end", "if true then rstar = b.rank break end" },
    { "même rang qui bloque", "s.rank < o.rank and up[s.item] then\n          if s.solid then", "s.rank <= o.rank and up[s.item] then\n          if s.solid then" },
    { "attente d'une seule chaîne", "if s.solid and up[s.item] and s.rank < o.rank then waiting[s.item] = true end", "if false then waiting[s.item] = true end" },
    { "front sans effet", "if front(e) then a[#a + 1] = e else b[#b + 1] = e end", "b[#b + 1] = e" },
    { "oubli jamais", "if clock - (S.items[k].seen or 0) > Pr.SOLID_KEEP then S.items[k] = nil end", "" },
    { "stock non compté au seuil de sortie", "local thr = e.solid and Pr.SOLID_DROP or Pr.SOLID_PCT", "local thr = Pr.SOLID_PCT" },
  }
  local caught = 0
  check(BASE == 0, "§5 mutants jugés sur une batterie de base verte (" .. BASE .. " échec(s))")
  for _, mu in ipairs(BASE == 0 and MUT or {}) do
    local s, e = SRC:find(mu[2], 1, true)
    if not s or SRC:find(mu[2], e + 1, true) then
      check(false, "§5 mutant mal formé : " .. mu[1])
    else
      local Pm = assert(load(SRC:sub(1, s - 1) .. mu[3] .. SRC:sub(e + 1), "=consolidation-mutant"))()
      local p0, f0 = pass, fail
      quiet = true
      local ok, err = pcall(battery, Pm)
      debug.sethook()
      quiet = false
      local fails = fail - f0
      pass, fail = p0, f0
      local hit = (not ok) or fails > 0
      if hit then caught = caught + 1 end
      check(hit, "§5 mutant NON refusé : " .. mu[1])
      say(string.format("§5 mutant « %s » : %s", mu[1], ok and (fails .. " contrôle(s) en échec") or ("plantage " .. tostring(err):sub(1, 60))))
    end
  end
  check(caught == #MUT, string.format("§5 mutants de porte_rang.lua : %d refusés sur %d", caught, #MUT))
end

do
  -- Mutants du branchement (capitalisation.lua) : la batterie §3 est rejouée sur un module chargé depuis la source mutée.
  local SRC = read("shared/ai3/capitalisation.lua")
  local function integ(C)
    local p0, f0 = pass, fail
    local st = {}
    local J, res
    local function dec(inp, s)
      local j = C.decide_begin(inp, s)
      while not C.decide_step(j) do end
      return j, j.res
    end
    for _ = 1, 4 do J, res = dec(scene(POSED, {}, true), st) end
    check(not ordered(res, "chaine:inserter"), "§m1 l'inserter attend (câble posé sans débit)")
    check(has(refus_of(res, "chaine:inserter"), "copper-cable"), "§m1 la cause nomme le câble")
    check(has(refus_of(res, "chaine:transport-belt"), "iron-gear-wheel"), "§m1 porte ciblée (la courroie attend l'engrenage)")
    local j0, r0 = dec(scene(POSED, {}, true), {})
    check(not has(refus_of(r0, "chaine:inserter"), "-ore") and not has(refus_of(r0, "chaine:transport-belt"), "-ore"), "§m1 les bruts (rang 0) ne sont pas jugés")
    local logged = false
    for _, l in ipairs(j0.ctx.cons_log or {}) do if has(l, "en attente sur la chaine") then logged = true end end
    check(logged, "§m1 la première attente est écrite au journal")
    local st7, lifted_at = {}, nil
    for t = 1, 26 do
      local _, r7 = dec(scene(POSED, {}, true), st7)
      if lifted_at == nil and ordered(r7, "chaine:inserter") then lifted_at = t end
    end
    check(lifted_at ~= nil and lifted_at <= 3 + Pr0.WAIT_MAX + 1, "§m1 la levée libère l'inserter à temps (" .. tostring(lifted_at) .. ")")
    local st2 = {}
    local asked = nil
    for t = 1, 6 do
      local j, r = dec(scene(POSED, BIG, true), st2)
      if asked == nil and (ordered(r, "chaine:inserter") or ordered(r, "chaine:transport-belt")) then asked = t end
    end
    check(asked == 3, "§m1 débits suffisants : la porte s'ouvre au troisième relevé (" .. tostring(asked) .. ")")
    -- main : la fabrication à la main ne consolide pas.
    local st3 = {}
    local hand = { ["copper-cable"] = { made = 5000, hand = 5000 }, ["electronic-circuit"] = { made = 5000, hand = 5000 }, ["iron-gear-wheel"] = { made = 5000, hand = 5000 } }
    for _ = 1, 5 do J, res = dec(scene(POSED, hand, true), st3) end
    check(not ordered(res, "chaine:inserter"), "§m1 la fabrication à la main (hors statistiques) ne consolide pas")
    -- fluide : jamais jugé (aucune mesure).
    local st4 = {}
    local posed_f = { { entity = "assembling-machine-2", recipe = "iron-gear-wheel", n = 4, where = "qg" } }
    for _ = 1, 4 do J, res = dec(scene(posed_f, { ["iron-gear-wheel"] = BIG["iron-gear-wheel"], ["copper-cable"] = BIG["copper-cable"] }, true), st4) end
    -- arrêtée : machines posées dont aucune unité ne compte (confirmation), débit pourtant déclaré : pas consolidée, la cause le dit.
    local st8 = {}
    local stopped = { POSED[1], { entity = "assembling-machine-2", recipe = "electronic-circuit", n = 6, where = "qg", n_cap = 0 }, POSED[3] }
    for _ = 1, 5 do J, res = dec(scene(stopped, BIG, true), st8) end
    check(not ordered(res, "chaine:inserter") and has(refus_of(res, "chaine:inserter"), "arretee"), "§m1 une chaîne arrêtée ne consolide pas (" .. tostring(refus_of(res, "chaine:inserter")) .. ")")
    -- le stock compte : le câble n'a que du stock, les autres tiers produisent.
    local st9, asked9 = {}, nil
    for t = 1, 6 do
      local _, r9 = dec(scene(POSED, { ["electronic-circuit"] = BIG["electronic-circuit"], ["iron-gear-wheel"] = BIG["iron-gear-wheel"] }, true,
        function(inp) inp.stock["copper-cable"] = 5000 end), st9)
      if asked9 == nil and ordered(r9, "chaine:inserter") then asked9 = t end
    end
    check(asked9 == 3, "§m1 le stock du câble le consolide sans débit (" .. tostring(asked9) .. ")")
    -- sans issue : le câble refusé par l'exécutant et sans machine
    local st5 = {}
    local posed3 = { POSED[2], POSED[3] }
    for _ = 1, 5 do
      local inp = scene(posed3, { ["electronic-circuit"] = BIG["electronic-circuit"], ["iron-gear-wheel"] = BIG["iron-gear-wheel"] }, true)
      inp.can_exec = function(kind, item) if item == "copper-cable" then return "non" end return nil end
      J, res = dec(inp, st5)
    end
    check(ordered(res, "chaine:inserter"), "§m1 le câble sans issue ne retient pas l'inserter")
    -- une seule avance de la mémoire par décision.
    local st6 = {}
    for _ = 1, 3 do dec(scene(POSED, {}, true), st6) end
    check(st6.solid and math.abs(st6.solid.clock - 3) < 1e-9, "§m1 l'horloge avance d'une minute par décision (" .. tostring(st6.solid and st6.solid.clock) .. ")")
    return pass - p0, fail - f0
  end
  local _, base_fail = integ(Ca)
  check(base_fail == 0, "§5 branchement : batterie de base verte (" .. base_fail .. " échec(s))")
  local MUT = {
    { "porte non branchée", "local solid = Ca.CONSOLIDE_RANG and ctx.st ~= nil and ctx.input.solid_mesure and true or nil", "local solid = nil" },
    { "main comptée comme débit", "rate = math.max(0, (fl.made or 0) - (fl.hand or 0))", "rate = math.max(0, (fl.made or 0))" },
    { "issue toujours vraie", "return served[x] == true, ((plan.N[x] or 0) + (plan.NP[x] or 0) + (plan.NO[x] or 0)) > Ca.EPS", "return true, true" },
    { "mémoire avancée à chaque tour", "  if ctx.cons == nil then\n    ctx.st.solid", "  if true then\n    ctx.st.solid" },
    { "stock non lu", "stock_cover = (ctx.stock[i] or 0) / Ca.H_STOCK, rate = rate,", "stock_cover = 0, rate = rate," },
    { "arrêt non relevé", "stopped = (posed[i] or 0) > 0 and (cap[i] or 0) <= 0 }", "stopped = false }" },
    { "attente non marquée", "local line = Pr.solid_mark(ctx.st.solid, x, v and v.text)", "local line = nil" },
    { "attente non écrite", "if line then ctx.cons_log[#ctx.cons_log + 1] = line end", "" },
    { "demande ignorée", "rows[#rows + 1] = { item = i, rank = rk, demand = Ri,", "rows[#rows + 1] = { item = i, rank = rk, demand = 1e-12,", },
  }
  local caught = 0
  for _, mu in ipairs(base_fail == 0 and MUT or {}) do
    local s, e = SRC:find(mu[2], 1, true)
    if not s or SRC:find(mu[2], e + 1, true) then
      check(false, "§5 mutant mal formé : " .. mu[1])
    else
      local Cm = assert(load(SRC:sub(1, s - 1) .. mu[3] .. SRC:sub(e + 1), "=consolidation-capi-mutant"))()
      local p0, f0 = pass, fail
      quiet = true
      local ok, err = pcall(integ, Cm)
      debug.sethook()
      quiet = false
      local fails = fail - f0
      pass, fail = p0, f0
      local hit = (not ok) or fails > 0
      if hit then caught = caught + 1 end
      check(hit, "§5 mutant NON refusé : " .. mu[1])
      say(string.format("§5 mutant « %s » : %s", mu[1], ok and (fails .. " contrôle(s) en échec") or ("plantage " .. tostring(err):sub(1, 60))))
    end
  end
  check(caught == #MUT, string.format("§5 mutants du branchement : %d refusés sur %d", caught, #MUT))
end

print(string.format("[CONSOLIDATION] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
