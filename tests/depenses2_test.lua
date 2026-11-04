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
mutant("défense seule payée par la recherche", "if not p.def_only then res.research", "if true then res.research")
print(string.format("[DEPENSES2] BILAN : %d OK, %d ECHEC(S) (dont 12 mutants)", passes, failures))
os.exit(failures == 0 and 0 or 1)
