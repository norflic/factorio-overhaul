--[[
  Lot DEPENSES (3/11) : le stock qui DORT déclenche des dépenses (shared/ai3/depenses.lua), et ses deux branchements purs :
  Cap.emit (shared/ai3/capital.lua : g.depense, l'amélioration de fond fabrique ses intermédiaires sans bras libre) et Em.slots
  (shared/ai3/emplacements.lua : `bonus`, emplacements de chantier de plus).
    §1 interrupteur ; §2 excédent (besoin évalué, tampon de production, plancher, manque) ; §3 horloge du sommeil ;
    §4 ordre des dépenses (intermédiaires, centre, défense bornée, capacité) et plancher ; §5 production lissée ;
    §6 déterminisme et état sans fonction ; §7 Cap.emit ; §8 Em.slots ;
    §9 mutants : de CODE (source relue, texte remplacé, rechargée) et de constantes ; chacun doit faire échouer au moins un contrôle.
  Usage : lua5.2 tests/depenses_test.lua   (depuis la racine du mod ; moins d'une seconde)
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("[DEPENSES] ECHEC : " .. msg) end
  end
end
local MIN = 3600

local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end
local SRC = { dp = read("shared/ai3/depenses.lua"), cap = read("shared/ai3/capital.lua"), em = read("shared/ai3/emplacements.lua") }
local function load_src(src, name)
  local fn = assert(load(src, "=" .. name))
  return fn()
end

local function prods(list)
  local out = {}
  for _, p in ipairs(list) do out[#out + 1] = { key = p[1], free = p[2], made = p[3] or 0, missing = p[4] } end
  return out
end

-- Un pas à chaque minute de t0 à t1 (inclus), mêmes produits ; made = production par minute.
local function run(Dp, st, t0, t1, list, demands, on)
  local res
  for t = t0, t1, MIN do
    st, res = Dp.step(st, { on = on ~= false, tick = t, products = prods(list), demands = demands })
  end
  return st, res
end

local function suite(Dp, Cap, Em)
  -- §1 interrupteur
  local st, res = run(Dp, Dp.new(), 0, 20 * MIN, { { "p1", 10000, 100 } }, {}, true)
  check(res.active and res.total > 0, "§1 allumé : 10 000 plaques libres pour 100/min dorment au bout de 20 min")
  st, res = Dp.step(st, { on = false, tick = 21 * MIN, products = prods({ { "p1", 10000, 100 } }) })
  check(not res.active and res.total == 0 and res.slots == 0 and not res.upgrade and res.defense == 0, "§1 éteint : rien n'est offert")
  check(next(st.since) == nil, "§1 éteint : horloges oubliées")
  st, res = Dp.step(st, { on = true, tick = 22 * MIN, products = prods({ { "p1", 10000, 100 } }) })
  check(not res.active, "§1 rallumé : l'horloge repart de zéro, rien ne dort encore")

  -- §2 excédent
  check(Dp.excess(1000, 100, false) == 400, "§2 1 000 libres, 100/min : on garde 6 min (600), excédent 400 (" .. Dp.excess(1000, 100, false) .. ")")
  check(Dp.excess(1000, 100, true) == 0, "§2 besoin non couvert : aucun excédent")
  check(Dp.excess(50, 0, false) == 0, "§2 sans production : le plancher (100) garde les 50 plaques")
  check(Dp.excess(250, 0, false) == 150, "§2 sans production : excédent au-delà du plancher seulement")
  check(Dp.excess(500, 100, false) == 0, "§2 sous le tampon : rien")

  -- §3 horloge du sommeil
  st, res = run(Dp, Dp.new(), 0, 4 * MIN, { { "p1", 5000, 100 } }, {})
  check(not res.active, "§3 4 min d'excédent : ne dort pas encore")
  st, res = run(Dp, st, 5 * MIN, 5 * MIN, { { "p1", 5000, 100 } }, {})
  check(res.active and math.abs(res.total - 4400) < 1e-6, "§3 5 min d'excédent : dort, budget = excédent (" .. res.total .. ")")
  st, res = run(Dp, st, 6 * MIN, 6 * MIN, { { "p1", 300, 100 } }, {})
  check(not res.active and st.since.p1 == nil, "§3 un creux sous le tampon remet l'horloge à zéro")
  st, res = run(Dp, st, 7 * MIN, 11 * MIN, { { "p1", 5000, 100 } }, {})
  check(not res.active, "§3 après le creux : 4 min ne suffisent pas")
  st, res = run(Dp, st, 12 * MIN, 12 * MIN, { { "p1", 5000, 100 } }, {})
  check(res.active, "§3 après le creux : 5 min d'un seul tenant, dort")

  -- §4 ordre et plancher
  local st4 = run(Dp, Dp.new(), 0, 10 * MIN, { { "p1", 1600, 100 } }, {}) -- excédent 1 000
  local _, r4 = Dp.step(st4, { on = true, tick = 11 * MIN, products = prods({ { "p1", 1600, 100 } }), demands = { intermediaires = 50 } })
  check(math.abs(r4.total - 1000) < 1e-6, "§4 budget 1 000 (" .. r4.total .. ")")
  check(r4.grant.intermediaires == 50 and r4.upgrade, "§4 intermédiaires servis d'abord (50) : amélioration de fond servie")
  check(math.abs(r4.grant.defense - 300) < 1e-6, "§4 défense : 30 % du budget au plus (" .. r4.grant.defense .. ")")
  check(math.abs(r4.grant.capacite - 650) < 1e-6 and r4.slots == 0, "§4 capacité : le reste (650), sous 1 500 : aucun emplacement")
  local sum = r4.grant.intermediaires + r4.grant.centre + r4.grant.defense + r4.grant.capacite
  check(sum <= r4.total + 1e-6, "§4 jamais plus que l'excédent (" .. sum .. " <= " .. r4.total .. ")")
  local _, r5 = Dp.step(st4, { on = true, tick = 11 * MIN, products = prods({ { "p1", 1600, 100 } }), demands = { intermediaires = 2000 } })
  check(not r5.upgrade and r5.grant.intermediaires == 1000 and r5.grant.defense == 0, "§4 intermédiaires plus chers que le budget : pas servis, rien après")
  local _, r6 = Dp.step(st4, { on = true, tick = 11 * MIN, products = prods({ { "p1", 1600, 100 } }), demands = { centre = 200, defense = 100 } })
  check(r6.grant.intermediaires == 0 and r6.grant.centre == 200 and r6.grant.defense == 100 and math.abs(r6.grant.capacite - 700) < 1e-6,
    "§4 centre avant défense (demande 100 < 30 %) avant capacité")
  check(r4.slots == 0 and r6.slots == 0, "§4 une amélioration ou le centre attend : aucun emplacement de plus")
  local st7 = run(Dp, Dp.new(), 0, 10 * MIN, { { "p1", 20600, 100 } }, {}) -- excédent 20 000
  local _, r7 = Dp.step(st7, { on = true, tick = 11 * MIN, products = prods({ { "p1", 20600, 100 } }), demands = {} })
  check(r7.slots == 3, "§4 emplacements de plus bornés à 3 (" .. r7.slots .. ")")
  local _, r7b = Dp.step(st7, { on = true, tick = 11 * MIN, products = prods({ { "p1", 20600, 100 } }), demands = { intermediaires = 15 } })
  local _, r7c = Dp.step(st7, { on = true, tick = 11 * MIN, products = prods({ { "p1", 20600, 100 } }), demands = { centre = 900 } })
  check(r7b.slots == 0 and r7c.slots == 0 and r7b.upgrade, "§4 ordre strict : une amélioration ou le centre attend, la capacité n'ouvre rien")
  local st8 = run(Dp, Dp.new(), 0, 10 * MIN, { { "p1", 4100, 100 } }, {}) -- excédent 3 500, capacité 2 450
  local _, r8 = Dp.step(st8, { on = true, tick = 11 * MIN, products = prods({ { "p1", 4100, 100 } }), demands = {} })
  check(r8.slots == 1, "§4 capacité 2 450 : un emplacement de plus (" .. r8.slots .. ")")
  -- un produit en manque ne compte pas, les autres si
  local st9 = run(Dp, Dp.new(), 0, 10 * MIN, { { "p1", 5000, 100, true }, { "p2", 1100, 0 } }, {})
  local _, r9 = Dp.step(st9, { on = true, tick = 11 * MIN, products = prods({ { "p1", 5000, 100, true }, { "p2", 1100, 0 } }), demands = {} })
  check(r9.per.p1 == nil and math.abs((r9.per.p2 or 0) - 1000) < 1e-6, "§4 produit en manque exclu, l'autre compte (1 000)")

  -- §5 production lissée
  check(math.abs(Dp.smooth(nil, 200, 2 * MIN) - 100) < 1e-6, "§5 200 objets en 2 min : 100/min")
  check(math.abs(Dp.smooth(100, 400, MIN) - 190) < 1e-6, "§5 lissage : 70 % de l'ancienne valeur (100) + 30 % de 400")
  local st10 = run(Dp, Dp.new(), 0, 10 * MIN, { { "p1", 3000, 400 } }, {}) -- 400/min : tampon 2 400, excédent 600
  check(st10.prod.p1 and math.abs(st10.prod.p1 - 400) < 1e-6, "§5 production mesurée 400/min")
  local _, r10 = Dp.step(st10, { on = true, tick = 11 * MIN, products = prods({ { "p1", 3000, 400 } }) })
  check(math.abs(r10.total - 600) < 1e-6, "§5 le tampon suit la production (excédent 600 : " .. r10.total .. ")")

  -- §6 déterminisme, état sans fonction
  local a1, ra = run(Dp, Dp.new(), 0, 10 * MIN, { { "p1", 5000, 100 }, { "p2", 3000, 50 } }, { intermediaires = 20 })
  local a2, rb = run(Dp, Dp.new(), 0, 10 * MIN, { { "p1", 5000, 100 }, { "p2", 3000, 50 } }, { intermediaires = 20 })
  check(ra.why == rb.why and ra.slots == rb.slots and ra.total == rb.total, "§6 mêmes entrées, même sortie")
  check(ra.why:find("p1", 1, true) < ra.why:find("p2", 1, true), "§6 produits dans l'ordre de l'appelant")
  local fn = false
  local function scan(t) for _, v in next, t do if type(v) == "function" then fn = true elseif type(v) == "table" then scan(v) end end end
  scan(a1)
  check(not fn, "§6 état sans fonction (sauvegarde)")
  check(Dp.cost_plates({ { "a", 3 }, { "b", 2 } }, function(i) return i == "a" and 1 or 2 end) == 7, "§6 coût en plaques (3 x 1 + 2 x 2)")
  check(Dp.cost_plates({ { "a", 3 } }) == 3, "§6 coût en plaques sans prix : 1 par objet")

  -- §7 Cap.emit : g.depense lève la règle des bras libres pour un bâtiment ; jamais pour rien d'autre
  local function emit_case(g, idle, take_ok)
    local wanted = 0
    local P = { take = function() return take_ok end, want = function() wanted = wanted + 1 end }
    local E = { view = { workers_idle = idle } }
    local r = Cap.emit(P)(E, { prio = 50 }, g)
    return r, wanted, E
  end
  local r, w = emit_case({ cost = { { "x", 1 } } }, 0, false)
  check(r == "matiere" and w == 0, "§7 bâtiment de fond sans bras libre, stock qui ne dort pas : rien n'est fabriqué (règle d'IA-G)")
  r, w = emit_case({ cost = { { "x", 1 } }, depense = true }, 0, false)
  check(r == "matiere" and w == 1, "§7 le stock dort : le bâtiment fait fabriquer ses intermédiaires sans bras libre")
  r, w = emit_case({ cost = { { "x", 1 } } }, 2, false)
  check(w == 1, "§7 bras libres : servi comme avant")
  -- prêt de l'excédent qui dort au stock virtuel, le temps du dépliage seulement
  do
    local seen, E = nil, { view = { workers_idle = 0 }, avail = { p = 5, q = 2 } }
    local P = { take = function() return false end,
      want = function(E_) seen = E_.avail.p; E_.avail.p = E_.avail.p - 30 end }
    Cap.emit(P)(E, { prio = 50 }, { cost = { { "x", 1 } }, depense = { p = 100 } })
    check(seen == 105, "§7 l'excédent qui dort est prêté au stock virtuel pendant le dépliage (" .. tostring(seen) .. ")")
    check(E.avail.p == 5 and E.avail.q == 2, "§7 le prêt non servi n'est jamais donné aux projets suivants (" .. tostring(E.avail.p) .. ")")
    local E3 = { view = { workers_idle = 0 }, avail = { p = 5 } }
    local P3 = { take = function() return false end, want = function(E_) E_.avail.p = E_.avail.p - 103 end }
    Cap.emit(P3)(E3, { prio = 50 }, { cost = { { "x", 1 } }, depense = { p = 100 } })
    check(E3.avail.p == 2, "§7 au-delà du prêt, le stock virtuel ordinaire paie (" .. tostring(E3.avail.p) .. ")")
    -- paiement : le prêt sert aussi à P.take
    local E4 = { view = { workers_idle = 0 }, avail = { p = 0 } }
    local P4 = { take = function(E_, cost) if (E_.avail.p or 0) >= 6 then E_.avail.p = E_.avail.p - 6 return true end return false end,
      want = function() end }
    local r4b = Cap.emit(P4)(E4, { prio = 50 }, { cost = { { "p", 6 } }, depense = { p = 100 }, key = "k", target = "t" })
    check(r4b == "ok" and E4.pay and #E4.pay == 1 and E4.avail.p == 0, "§7 le prêt paie l'amélioration ; rien n'en reste aux suivants")
  end
  local r2, w2, E2 = emit_case({ cost = { { "x", 1 } }, depense = true, key = "k", target = "t" }, 0, true)
  check(r2 == "ok" and w2 == 0 and E2.pay and #E2.pay == 1, "§7 coût au stock virtuel : payé, rien à fabriquer")

  -- §8 Em.slots : bonus
  local s0 = Em.slots({ base = 2, plates = { 0 }, mods = {}, tick = 0 })
  local s1 = Em.slots({ base = 2, plates = { 0 }, mods = {}, tick = 0, bonus = 2 })
  check(s0.cap == 2 and s1.cap == 4 and s1.bonus == 2, "§8 deux emplacements de plus par le stock qui dort (" .. s0.cap .. " -> " .. s1.cap .. ")")
  check(not s0.why:find("dort", 1, true) and s1.why:find("2 de plus par le stock qui dort", 1, true) ~= nil,
    "§8 texte : inchangé sans bonus, dit le bonus sinon")
  check(Em.slots({ base = 2, plates = {}, mods = {}, tick = 0, bonus = -3 }).cap == 2, "§8 bonus négatif ignoré")
end

local function fresh()
  return load_src(SRC.dp, "depenses"), load_src(SRC.cap, "capital"), load_src(SRC.em, "emplacements")
end

-- Passe de référence
do
  local Dp, Cap, Em = fresh()
  suite(Dp, Cap, Em)
end
local base_fail = failures

-- §9 mutants
local function run_mutant(name, which, old, new, const)
  local src = { dp = SRC.dp, cap = SRC.cap, em = SRC.em }
  if old then
    local i = src[which]:find(old, 1, true)
    if not i then
      check(false, "§9 mutant introuvable dans la source : " .. name)
      return
    end
    src[which] = src[which]:sub(1, i - 1) .. new .. src[which]:sub(i + #old)
  end
  local okl, Dp, Cap, Em = pcall(function()
    return load_src(src.dp, "depenses"), load_src(src.cap, "capital"), load_src(src.em, "emplacements")
  end)
  local before, pbefore = failures, passes
  quiet = true
  local okr = okl and pcall(function()
    if const then const(Dp) end
    suite(Dp, Cap, Em)
  end)
  quiet = false
  local caught = (not okl) or (not okr) or failures > before
  failures, passes = before, pbefore
  check(caught, "§9 mutant détecté : " .. name)
end

run_mutant("dort tout de suite", "dp", nil, nil, function(Dp) Dp.N_DORT = 0 end)
run_mutant("aucun tampon de production", "dp", nil, nil, function(Dp) Dp.H_SEUIL = 0 end)
run_mutant("aucun plancher", "dp", nil, nil, function(Dp) Dp.FLOOR = 0 end)
run_mutant("défense sans borne", "dp", nil, nil, function(Dp) Dp.DEF_PCT = 100 end)
run_mutant("capacité d'abord", "dp", nil, nil, function(Dp) Dp.ORDER = { "capacite", "intermediaires", "centre", "defense" } end)
run_mutant("emplacements sans plafond", "dp", nil, nil, function(Dp) Dp.SLOTS_MAX = 99 end)
run_mutant("emplacement bon marché", "dp", nil, nil, function(Dp) Dp.SLOT_PLATES = 100 end)
run_mutant("manque ignoré", "dp", "  if missing then return 0 end\n", "")
run_mutant("horloge jamais remise à zéro", "dp", "      st.since[key] = nil\n", "")
run_mutant("interrupteur sans effet", "dp", "  if not inp.on then", "  if false then")
run_mutant("amélioration servie même à moitié", "dp", "\n    and (res.grant.intermediaires or 0) >= math.max(0, num(d.intermediaires)) - 1e-9", "")
run_mutant("production non lissée", "dp", "(num(old) * Dp.PROD_KEEP + per_min * (1000 - Dp.PROD_KEEP)) / 1000", "per_min")
run_mutant("Cap.emit ignore g.depense", "cap", "not g.depense and ", "")
run_mutant("prêt gardé par les projets suivants", "cap", "E.avail[k] = math.min(E.avail[k] or 0, before[k])", "E.avail[k] = E.avail[k]")
run_mutant("aucun prêt", "cap", "E.avail[k] = before[k] + math.max(0, math.floor(lent[k] or 0))", "E.avail[k] = before[k]")
run_mutant("capacité même quand une amélioration attend", "dp", "res.slots = pending and 0 or ", "res.slots = ")
run_mutant("prêt absent du paiement", "cap", "E.avail[k] = before0[k] + math.max(0, math.floor(lent0[k] or 0))", "E.avail[k] = before0[k]")
run_mutant("Em.slots ignore le bonus", "em", "  local cap = base + extra + bonus\n", "  local cap = base + extra\n")

print(string.format("[DEPENSES] BILAN : %d OK, %d ECHEC(S)%s", passes, failures, base_fail > 0 and " (passe de reference en echec)" or ""))
os.exit(failures == 0 and 0 or 1)
