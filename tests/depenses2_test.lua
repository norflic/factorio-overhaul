--[[
  Lot DEPENSES2 (4/11) : règle du stock qui dort (shared/ai3/depenses.lua) : excédent, sommeil, défense d'abord (30 % au plus, toute la
  matière « défense seule »), recherche (laboratoires de plus), armement, interrupteur, déterminisme ; mutants de code et de constantes.
  Usage : lua5.2 tests/depenses2_test.lua (depuis la racine du mod ; moins d'une seconde)
]]
package.path = "./?.lua;" .. package.path

local passes, failures, quiet = 0, 0, false
local function check(c, msg)
  if c then passes = passes + 1 else failures = failures + 1 if not quiet then print("[DEPENSES2] ECHEC : " .. msg) end end
end
local MIN = 3600
local fh = assert(io.open("shared/ai3/depenses.lua", "rb"))
local SRC = fh:read("*a")
fh:close()
local function load_dp(src) return assert(load(src, "=depenses"))() end

local function run(Dp, t1, prods, want, on)
  local st, res = Dp.new(), nil
  for t = 0, t1, MIN do st, res = Dp.step(st, { on = on ~= false, tick = t, products = prods, want = want }) end
  return st, res
end

local function suite(Dp)
  -- excédent et réserve
  check(Dp.excess(1000, 100, false) == 400, "excédent : 1 000 libres, 100/min, 6 min gardées -> 400")
  check(Dp.excess(1000, 100, true) == 0, "besoin non couvert : rien")
  check(Dp.excess(50, 0, false) == 0, "plancher de 100")
  -- sommeil
  local P = { { key = "a", free = 5000, made = 100 } }
  local _, r4 = run(Dp, 4 * MIN, P, {})
  check(next(r4.per) == nil, "4 min : ne dort pas encore")
  local st5, r5 = run(Dp, 5 * MIN, P, {})
  check(r5.per.a and math.abs(r5.per.a - 4400) < 1e-6, "5 min : dort, excédent 4 400 (" .. tostring(r5.per.a) .. ")")
  local _, r6 = Dp.step(st5, { on = true, tick = 6 * MIN, products = { { key = "a", free = 300, made = 100 } } })
  check(next(r6.per) == nil, "un creux remet l'horloge à zéro")
  -- défense d'abord, plafonnée
  local _, rd = run(Dp, 10 * MIN, P, { a = 999 })
  check(rd.defense.a == 999, "défense servie sur sa demande (999 < 30 %)")
  local _, rd2 = run(Dp, 10 * MIN, P, { a = 99999 })
  check(rd2.defense.a == 1320, "défense plafonnée à 30 % de l'excédent (" .. tostring(rd2.defense.a) .. ")")
  local _, rs = run(Dp, 10 * MIN, { { key = "s", free = 3000, made = 0, def_only = true } }, { s = 5000 })
  check(rs.defense.s == 2900 and rs.research == 0, "matière « défense seule » : tout l'excédent à la défense, rien à la recherche")
  local _, rs2 = run(Dp, 10 * MIN, { { key = "s", free = 3000, made = 0, def_only = true } }, { s = 1000 })
  check(rs2.defense.s == 1000 and rs2.research == 0, "matière « défense seule » non demandée : jamais à la recherche")
  local _, rbig = run(Dp, 10 * MIN, { { key = "a", free = 20600, made = 100 } }, {})
  check(rbig.labs == 4, "laboratoires de plus plafonnés à 4 (" .. tostring(rbig.labs) .. ")")
  local _, r0 = run(Dp, 10 * MIN, P, {})
  check(r0.defense.a == 0, "sans demande : rien retenu pour la défense")
  -- recherche puis armement
  check(math.abs(r0.research - 4400) < 1e-6 and r0.labs == 4, "recherche : 4 400 plaques -> 4 laboratoires (plafond)")
  check(math.abs(rd.research - 3401) < 1e-6 and rd.labs == 3 and math.abs(rd.arms - 401) < 1e-6, "défense d'abord, puis recherche (3), armement le reste")
  -- essai 3 : le centre d'abord
  local sth = run(Dp, 10 * MIN, P, { a = 999 })
  local _, rh = Dp.step(sth, { on = true, tick = 11 * MIN, products = P, want = { a = 999 }, hold = true })
  check(rh.hold and rh.labs == 0 and next(rh.arms_by) == nil and rh.defense.a == 999,
    "centre en attente : 0 laboratoire, 0 armement, la défense reste servie")
  check(Dp.soldiers_extra(rh, "a", false) == 0, "centre en attente : 0 soldat")
  local rvh = Dp.reserved(rh, 9, 5, nil, nil, nil, nil)
  check((rvh.a or 0) == 999, "centre en attente : rien d'engagé pour les laboratoires, la défense seule (" .. tostring(rvh.a) .. ")")
  local _, rp = run(Dp, 10 * MIN, { { key = "a", free = 1500, made = 100 } }, {})
  check(rp.labs == 0, "sous 1 000 plaques après défense : aucun laboratoire de plus")
  -- interrupteur
  local st, _ = run(Dp, 10 * MIN, P, {})
  local st2, re = Dp.step(st, { on = false, tick = 11 * MIN, products = P })
  check(re.labs == 0 and next(re.defense) == nil and next(st2.since) == nil, "éteint : rien, horloges oubliées")
  -- déterminisme et état
  local _, x = run(Dp, 10 * MIN, { P[1], { key = "b", free = 3000, made = 0 } }, { a = 10 })
  local _, y = run(Dp, 10 * MIN, { P[1], { key = "b", free = 3000, made = 0 } }, { a = 10 })
  check(x.why == y.why and x.why:find("a dort", 1, true) < x.why:find("b dort", 1, true), "mêmes entrées, même sortie, ordre de l'appelant")
  check(math.abs(Dp.smooth(100, 400, MIN) - 190) < 1e-6, "production lissée")
  check(rd.rper and math.abs((rd.rper.a or 0) - 3401) < 1e-6, "part de la recherche par matière (3 401)")
  -- revue D1 : cible ABSOLUE, aucun cliquet. On simule la pose d'un laboratoire par pensée, 30 pensées.
  local base, now, target = nil, 2, nil
  for _ = 1, 30 do
    target, base = Dp.labs_target(base, now, 4, 7)
    if target and now < target then now = now + 1 end
  end
  check(now == 6 and base == 2 and target == 6, "laboratoires : base figée à 2, cible 6, posés 6 après 30 pensées (" .. now .. ")")
  -- essai 3 : cible MONOTONE pendant un sommeil (le surplus oscille autour du seuil : n = 2, 1, 2, 1)
  local b2, t2, seen = nil, nil, {}
  for i, n in ipairs({ 2, 1, 2, 1, 3, 1 }) do
    t2, b2 = Dp.labs_target(b2, 2, n, 13, t2)
    seen[i] = t2
  end
  check(seen[1] == 4 and seen[2] == 4 and seen[4] == 4 and seen[5] == 5 and seen[6] == 5, "cible monotone : 4 4 4 4 5 5 (" .. table.concat(seen, " ") .. ")")
  check(Dp.labs_target(2, 2, 1, 13, 99) == 6, "cible monotone jamais au-delà de base + 4 (6)")
  check(Dp.labs_target(5, 5, 4, 7) == 7, "cible plafonnée par l'appelant (7)")
  check(Dp.labs_target(5, 5, 0, 7) == nil and select(2, Dp.labs_target(5, 5, 0, 7)) == nil, "rien ne dort : aucune cible, base oubliée")
  check(Dp.engaged(6, 4, 60) == 120 and Dp.engaged(nil, 4, 60) == 0 and Dp.engaged(4, 6, 60) == 0, "plaques engagées : 2 laboratoires à faire = 120")
  -- revue D3 : armement
  local _, rs3 = run(Dp, 10 * MIN, { { key = "a", free = 20600, made = 100 } }, {})
  check(rs3.labs == 4 and Dp.soldiers_extra(rs3, "a", false) == 6, "armement : après 4 laboratoires, le reste paie 6 soldats de plus (plafond)")
  check(Dp.soldiers_extra(rs3, "a", true) == 0, "matière clé qui manque (key_short) : aucun soldat de plus (E4)")
  check(Dp.soldiers_extra(rs3, "z", false) == 0 and Dp.soldiers_extra(rs3, nil, false) == 0, "matière clé qui ne dort pas : aucun soldat")
  -- E4 : par matière. Seul le cuivre dort : il ne paie pas des recrues en fer.
  local _, rcu = run(Dp, 10 * MIN, { { key = "fer", free = 50, made = 0 }, { key = "cuivre", free = 20600, made = 100 } }, {})
  check(rcu.arms > 3000 and Dp.soldiers_extra(rcu, "fer", false) == 0, "le cuivre qui dort ne paie pas de soldats en fer (" .. math.floor(rcu.arms) .. ")")
  local _, rmx = run(Dp, 10 * MIN, { { key = "fer", free = 10600, made = 100 }, { key = "cuivre", free = 10600, made = 100 } }, {})
  check(math.abs(rmx.arms_by.fer - rmx.arms_by.cuivre) < 1e-6 and math.abs(rmx.arms_by.fer + rmx.arms_by.cuivre - rmx.arms) < 1e-6,
    "armement par matière : au prorata, somme = armement total")
  -- E2 : débit des soldats = min(t − cerveau, t − présents) × coût, sur la matière clé ; jamais plus que l'excédent qui dort
  local rv = Dp.reserved(rs3, nil, nil, 24, 18, 0, "a")
  check(math.abs((rv.a or 0) - 6 * 60) < 1e-6, "débit : 6 soldats au-dessus de la cible du cerveau (pas 24) = 360 (" .. tostring(rv.a) .. ")")
  local rv2 = Dp.reserved(rs3, nil, nil, 24, 18, 22, "a")
  check(math.abs((rv2.a or 0) - 2 * 60) < 1e-6, "débit : 2 encore à recruter (22 présents) = 120")
  local rv3 = Dp.reserved(rs3, 9, 5, nil, nil, nil, nil)
  check(math.abs((rv3.a or 0) - 4 * 60) < 1e-6, "débit : 4 laboratoires encore à faire = 240")
  local tiny = { per = { a = 100 }, rper = { a = 100 }, research = 100, defense = { a = 0 } }
  check(Dp.reserved(tiny, 20, 0, 30, 0, 0, "a").a == 100, "débit jamais au-delà de l'excédent qui dort (100)")
  check(Dp.soldiers(18, 3, 30) == 21 and Dp.soldiers(29, 3, 30) == 30 and Dp.soldiers(18, 0, 30) == 18 and Dp.soldiers(35, 3, 30) == 35,
    "cible d'armée : +3, plafond de soldats, rien sans excédent, jamais baissée")
  -- revue D5 : relevé manqué, demande qui n'est pas une table
  local stg = run(Dp, 10 * MIN, P, {})
  local _, rg = Dp.step(stg, { on = true, tick = 14 * MIN, products = P })
  check(next(rg.per) == nil, "relevé manqué (4 min) : sommeil interrompu, horloges oubliées")
  local okw, rw = pcall(function() return select(2, run(Dp, 10 * MIN, P, 5)) end)
  check(okw and rw and rw.defense.a == 0, "demande qui n'est pas une table : ignorée sans erreur")
end

suite(load_dp(SRC))
local function mutant(name, old, new, const)
  local src = SRC
  if old then
    local i = src:find(old, 1, true)
    if not i then check(false, "mutant introuvable : " .. name) return end
    src = src:sub(1, i - 1) .. new .. src:sub(i + #old)
  end
  local before, pb = failures, passes
  quiet = true
  local ok = pcall(function() local Dp = load_dp(src) if const then const(Dp) end suite(Dp) end)
  quiet = false
  local caught = (not ok) or failures > before
  failures, passes = before, pb
  check(caught, "mutant détecté : " .. name)
end
mutant("dort tout de suite", nil, nil, function(Dp) Dp.N_DORT = 0 end)
mutant("aucun tampon", nil, nil, function(Dp) Dp.H_SEUIL = 0 end)
mutant("aucun plancher", nil, nil, function(Dp) Dp.FLOOR = 0 end)
mutant("défense sans plafond", nil, nil, function(Dp) Dp.DEF_PCT = 100 end)
mutant("laboratoires sans plafond", nil, nil, function(Dp) Dp.LABS_MAX = 99 end)
mutant("laboratoire bon marché", nil, nil, function(Dp) Dp.LAB_PLATES = 100 end)
mutant("manque ignoré", "  if missing then return 0 end\n", "")
mutant("horloge jamais remise à zéro", " else st.since[k] = nil end", " end")
mutant("interrupteur sans effet", "  if not inp.on then", "  if false then")
mutant("défense seule ignorée", "local cap = p.def_only and exc or exc * Dp.DEF_PCT / 100", "local cap = exc * Dp.DEF_PCT / 100")
mutant("demande de défense ignorée", "math.max(0, num(want[k]))", "cap")
mutant("défense seule payée par la recherche", "if not p.def_only then\n        res.research", "if true then\n        res.research")
mutant("cliquet : base relative", "base = base or math.max(0, math.floor(num(now)))", "base = math.max(0, math.floor(num(now)))")
mutant("soldiers sans plafond", nil, nil, function(Dp) Dp.SOLDIERS_MAX = 99 end)
mutant("relevé manqué ignoré", "if dt and dt > Dp.GAP then st.since, dt = {}, nil end", "")
mutant("demande non gardée", "type(inp.want) == \"table\" and inp.want or {}", "inp.want or {}")
mutant("engagé négatif", "return math.max(0, math.floor(num(target)) - math.floor(num(now))) * num(cost)", "return (math.floor(num(target)) - math.floor(num(now))) * num(cost)")
mutant("armée baissée", "return math.max(a, math.min(", "return (math.min(")
mutant("centre en attente ignoré", "  if res.hold then\n", "  if false then\n")
mutant("cible qui oscille", "if type(prev) == \"number\" and prev > t then t = prev end", "")
mutant("cible monotone sans plafond base + 4", "math.floor(num(cap))), base + Dp.LABS_MAX)", "math.floor(num(cap))), 1e9)")
mutant("matière clé qui manque ignorée", "if not res or res.hold or key_short or key == nil then return 0 end", "if not res or res.hold or key == nil then return 0 end")
mutant("armement non compté par matière", "local a = num((res.arms_by or {})[key])", "local a = num(res.arms)")
mutant("débit des soldats sur toute l'armée", "num(sold_target) - num(sold_brain), num(sold_target) - num(sold_now)", "num(sold_target) - num(sold_now), num(sold_target) - num(sold_now)")
mutant("laboratoires débités pendant l'attente du centre", "res.hold and 0 or Dp.engaged(lab_target, lab_now, Dp.LAB_COST)", "Dp.engaged(lab_target, lab_now, Dp.LAB_COST)")
mutant("débit au-delà de l'excédent", "out[k] = math.min(out[k], num((res.per or {})[k]))", "out[k] = out[k]")
print(string.format("[DEPENSES2] BILAN : %d OK, %d ECHEC(S) (dont 26 mutants)", passes, failures))
os.exit(failures == 0 and 0 or 1)
