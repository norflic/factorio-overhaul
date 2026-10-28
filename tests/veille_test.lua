--[[
  Tests hors jeu de la reconnaissance régulière (lot VEILLE). Usage, depuis la racine du mod : lua5.2 tests/veille_test.lua
  Règle pure : shared/faction/veille.lua. Chaque règle est abîmée par un mutant qui doit faire échouer au moins une vérification.
]]
package.path = "./?.lua;" .. package.path
local V = require("shared.faction.veille")

local passes, failures, verbose = 0, 0, false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if verbose then print("  ECHEC : " .. msg) end end
end

local function battery()
  -- Cadence
  check(V.interval(1000, 0, 0) == V.INTERVAL, "intervalle de base : 10 min")
  check(V.interval(2000, 0, 0) == V.INTERVAL / 2 and V.interval(500, 0, 0) == 2 * V.INTERVAL, "plus curieuse, plus souvent")
  check(V.interval(5000, 0, 0) == V.interval(2000, 0, 0) and V.interval(1, 0, 0) == V.interval(500, 0, 0), "curiosité bornée")
  check(V.interval(1000, 300, 0) == math.floor(V.INTERVAL * 1.6), "la menace allonge l'intervalle (1 000 + 2 x menace)")
  check(V.interval(1000, 0, 1) == 2 * V.INTERVAL and V.interval(1000, 0, 2) == 4 * V.INTERVAL, "doublé par perte")
  check(V.interval(1000, 0, 99) == V.interval(1000, 0, V.LOSS_CAP), "doublement borné")
  check(V.interval(nil, nil, nil) == V.INTERVAL, "défauts")
  -- Rayon croissant
  check(V.radius(0) == 300 and V.radius(1) == 450 and V.radius(2) == 600, "rayon : 300 + 150 par trajet")
  check(V.radius(100) == V.RMAX and V.radius(-3) == V.R0 and V.radius(nil) == V.R0, "rayon plafonné à 1 600, jamais sous 300")
  check(V.in_band(300, 300) and V.in_band(300 + V.BAND, 300) and not V.in_band(300 + V.BAND + 1, 300)
    and not V.in_band(300 - V.BAND - 1, 300), "bande R +- 96")
  check(V.stale(nil) and V.stale(V.STALE) and not V.stale(V.STALE - 1), "secteur but : jamais vu ou vu depuis 20 min")
  -- Octants (sans trigonométrie)
  check(V.octant(10, 0) == 0 and V.octant(0, 10) == 2 and V.octant(-10, 0) == 4 and V.octant(0, -10) == 6, "axes")
  check(V.octant(10, 10) == 1 and V.octant(-10, 10) == 3 and V.octant(-10, -10) == 5 and V.octant(10, -10) == 7, "diagonales")
  check(V.octant(10, 4) == 0 and V.octant(10, 5) == 1 and V.octant(0, 0) == 0, "frontière à 22,5 degrés")
  -- Choix du but
  local c = {
    { key = "a", dh = 300, octant = 0, age = 40000 }, { key = "b", dh = 320, octant = 1, age = 90000 },
    { key = "c", dh = 280, octant = 2, age = nil }, { key = "d", dh = 260, octant = 3, age = nil },
  }
  check(V.pick(c, 5).key == "d", "jamais vu d'abord, le plus proche à octant égal")
  check(V.pick(c, 3).key == "c", "jamais vu : l'octant du précédent passe après")
  table.remove(c, 4); table.remove(c, 3)
  check(V.pick(c, 5).key == "b", "le plus ancien d'abord")
  check(V.pick({}, 0) == nil and V.pick(nil, 0) == nil, "aucun candidat : nil")
  local tie = { { key = "x", dh = 300, octant = 4, age = 5 }, { key = "y", dh = 300, octant = 6, age = 5 } }
  check(V.pick(tie, 4).key == "y" and V.pick(tie, 6).key == "x", "à âge égal, on change d'octant")
  local eq = { { key = "q", dh = 300, octant = 4, age = 5 }, { key = "p", dh = 300, octant = 4, age = 5 } }
  check(V.pick(eq, 0).key == "p", "égalité : la clé (déterminisme)")
  -- Départ
  local function want(o)
    local cc = { ready = 1, busy = false, tick = 100000, next_at = 0, threat = 0, survive = false, alert = false, hq_ok = true,
      enemies = false, quiet_until = 0 }
    for k, v in pairs(o or {}) do cc[k] = v end
    return V.want(cc)
  end
  check(want(), "toutes conditions réunies : il part")
  local ok, why = want({ ready = 0 })
  check(not ok and why == "pas d'eclaireur", "pas de vivier : pas de départ")
  ok, why = want({ busy = true }); check(not ok and why == "eclaireur en cours", "un éclaireur à la fois")
  ok, why = want({ survive = true }); check(not ok and why == "survie", "survie")
  ok, why = want({ alert = true }); check(not ok and why == "alerte", "alerte du QG")
  ok, why = want({ hq_ok = false }); check(not ok and why == "defense du debut", "tourelles du QG incomplètes")
  ok, why = want({ enemies = true }); check(not ok and why == "ennemis pres du QG", "ennemis près du QG")
  ok, why = want({ quiet_until = 100001 }); check(not ok and why == "pertes recentes", "mort de soldat depuis moins de 5 min")
  check(want({ quiet_until = 100000 }), "5 min écoulées")
  ok, why = want({ threat = V.THREAT_MAX + 1 }); check(not ok and why == "menace", "menace")
  check(want({ threat = V.THREAT_MAX }), "menace au seuil")
  ok, why = want({ next_at = 100001 }); check(not ok and why == "delai", "délai")
  check(want({ vs_player = true, garrison = 0 }), "la guerre contre le joueur et la garnison n'empêchent PAS le départ (vivier réservé)")
  -- Fabrication du vivier
  local function train(o)
    local cc = { have = 0, soldiers = 12, tick = 100000, next_train = 0, hq_ok = true, stock_ok = true, survive = false, alert = false,
      threat = 0 }
    for k, v in pairs(o or {}) do cc[k] = v end
    return V.train_due(cc)
  end
  check(train(), "armée de départ faite : on fabrique le vivier")
  ok, why = train({ have = 1 }); check(not ok and why == "vivier plein", "un seul à la fois")
  ok, why = train({ soldiers = 9 }); check(not ok and why == "armee de depart", "sous l'armée de départ : on ne le fabrique pas")
  check(train({ soldiers = V.START_ARMY }), "armée de départ juste atteinte")
  ok, why = train({ hq_ok = false }); check(not ok and why == "defense du debut", "tourelles du QG d'abord")
  ok, why = train({ stock_ok = false }); check(not ok and why == "fer insuffisant", "kit non payable")
  ok, why = train({ next_train = 100001 }); check(not ok and why == "delai", "délai de remplacement")
  ok, why = train({ survive = true }); check(not ok and why == "survie", "survie")
  ok, why = train({ threat = 101 }); check(not ok and why == "menace", "menace")
  local seen = {}
  for _, r in ipairs(V.REASONS) do seen[r] = true end
  for _, r in ipairs({ "pas d'eclaireur", "eclaireur en cours", "survie", "alerte", "defense du debut", "ennemis pres du QG",
    "pertes recentes", "menace", "delai", "armee de depart", "fer insuffisant", "vivier plein", "aucun secteur" }) do
    check(seen[r], "raison déclarée : " .. r)
  end
end

local function run()
  passes, failures = 0, 0
  battery()
  return passes, failures
end

verbose = true
local p, f = run()
local real_fail = f
print(string.format("[VEILLE] %d OK, %d ECHEC(S) (règles réelles)", p, f))
verbose = false

local mutants = {}
local function mutant(name, apply) mutants[#mutants + 1] = { name = name, apply = apply } end
local function wrap(fn_name, mod)
  return function() local o = V[fn_name]; V[fn_name] = mod(o); return function() V[fn_name] = o end end
end
local function copy_with(t, k, v) local c = {}; for a, b in pairs(t) do c[a] = b end; c[k] = v; return c end

mutant("interval ignore la menace", wrap("interval", function(o) return function(c, t, l) return o(c, 0, l) end end))
mutant("interval ne double pas par perte", wrap("interval", function(o) return function(c, t, l) return o(c, t, 0) end end))
mutant("interval ignore la curiosité", wrap("interval", function(o) return function(c, t, l) return o(1000, t, l) end end))
mutant("radius ne croît pas", wrap("radius", function(o) return function() return V.R0 end end))
mutant("radius sans plafond", wrap("radius", function(o) return function(n) return V.R0 + V.STEP * (n or 0) end end))
mutant("pick ignore l'âge", wrap("pick", function(o) return function(c, l)
  local d = {}
  for i, x in ipairs(c or {}) do d[i] = copy_with(x, "age", x.age and 1 or nil) end
  local r = o(d, l)
  if not r then return nil end
  for _, x in ipairs(c) do if x.key == r.key then return x end end
end end))
mutant("pick préfère le vu au jamais vu", wrap("pick", function(o) return function(c, l)
  local d = {}
  for i, x in ipairs(c or {}) do d[i] = copy_with(x, "age", x.age == nil and 0 or x.age) end
  local r = o(d, l)
  if not r then return nil end
  for _, x in ipairs(c) do if x.key == r.key then return x end end
end end))
mutant("pick sans alternance d'octant", wrap("pick", function(o) return function(c, l) return o(c, -1) end end))
mutant("want ignore le vivier", wrap("want", function(o) return function(c) return o(copy_with(c, "ready", 1)) end end))
mutant("want ignore les ennemis", wrap("want", function(o) return function(c) return o(copy_with(c, "enemies", false)) end end))
mutant("want ignore les pertes récentes", wrap("want", function(o) return function(c) return o(copy_with(c, "quiet_until", 0)) end end))
mutant("want ignore les tourelles du QG", wrap("want", function(o) return function(c) return o(copy_with(c, "hq_ok", true)) end end))
mutant("want ignore la menace", wrap("want", function(o) return function(c) return o(copy_with(c, "threat", 0)) end end))
mutant("want ignore le délai", wrap("want", function(o) return function(c) return o(copy_with(c, "next_at", 0)) end end))
mutant("want ignore l'alerte", wrap("want", function(o) return function(c) return o(copy_with(c, "alert", false)) end end))
mutant("want refuse en guerre contre le joueur", wrap("want", function(o) return function(c)
  if c.vs_player then return false, "guerre" end
  return o(c)
end end))
mutant("train_due ignore l'armée de départ", wrap("train_due", function(o) return function(c) return o(copy_with(c, "soldiers", 99)) end end))
mutant("train_due ignore le stock", wrap("train_due", function(o) return function(c) return o(copy_with(c, "stock_ok", true)) end end))
mutant("train_due fabrique sans limite", wrap("train_due", function(o) return function(c) return o(copy_with(c, "have", 0)) end end))
mutant("train_due ignore le délai", wrap("train_due", function(o) return function(c) return o(copy_with(c, "next_train", 0)) end end))
mutant("octant faux sur les diagonales", wrap("octant", function(o) return function(dx, dy) return o(dx, 0) end end))

local survivors = 0
for _, mu in ipairs(mutants) do
  local undo = mu.apply()
  local ok, pf, ff = pcall(run)
  undo()
  local caught = (not ok) or ff > 0
  if not caught then survivors = survivors + 1 end
  print(string.format("  mutant %-44s : %s", mu.name, caught and "refusé" or "SURVIVANT"))
end
local pp, ff2 = run()
print(string.format("[VEILLE] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés ; règles réelles rejouées : %d ECHEC(S)", p, real_fail,
  #mutants - survivors, #mutants, ff2))
os.exit((real_fail == 0 and survivors == 0 and ff2 == 0) and 0 or 1)
