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
  check(Dp.labs_target(5, 5, 4, 7) == 7, "cible plafonnée par l'appelant (7)")
  check(Dp.labs_target(5, 5, 0, 7) == nil and select(2, Dp.labs_target(5, 5, 0, 7)) == nil, "rien ne dort : aucune cible, base oubliée")
  check(Dp.engaged(6, 4, 60) == 120 and Dp.engaged(nil, 4, 60) == 0 and Dp.engaged(4, 6, 60) == 0, "plaques engagées : 2 laboratoires à faire = 120")
  -- revue D3 : armement
  local _, rs3 = run(Dp, 10 * MIN, { { key = "a", free = 20600, made = 100 } }, {})
  check(rs3.labs == 4 and rs3.soldiers == 6, "armement : après 4 laboratoires, le reste paie 6 soldats de plus (plafond)")
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
print(string.format("[DEPENSES2] BILAN : %d OK, %d ECHEC(S) (dont 18 mutants)", passes, failures))
os.exit(failures == 0 and 0 or 1)
