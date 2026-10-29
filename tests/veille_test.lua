--[[
  Tests hors jeu de la reconnaissance régulière par ouvrier libre (lot VEILLE, essai 2). Usage : lua5.2 tests/veille_test.lua
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
  check(V.interval(1000, 0) == V.INTERVAL, "intervalle de base : 10 min")
  check(V.interval(2000, 0) == V.INTERVAL / 2 and V.interval(500, 0) == 2 * V.INTERVAL, "plus curieuse, plus souvent")
  check(V.interval(5000, 0) == V.interval(2000, 0) and V.interval(1, 0) == V.interval(500, 0), "curiosité bornée")
  check(V.interval(1000, 300) == math.floor(V.INTERVAL * 1.6), "la menace allonge l'intervalle (1 000 + 2 x menace)")
  check(V.interval(nil, nil) == V.INTERVAL, "défauts")
  check(V.START >= V.INTERVAL and V.START == 15 * 3600, "premier départ : pas avant 15 min (mise en place de la base)")
  -- Rayon croissant
  check(V.radius(0) == 300 and V.radius(1) == 450 and V.radius(2) == 600, "rayon : 300 + 150 par mission")
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
    local cc = { tick = 100000, next_at = 0, threat = 0, survive = false, alert = false, tour_done = true, request = false,
      open_tasks = 0, idle = 4, missing = false }
    for k, v in pairs(o or {}) do cc[k] = v end
    return V.want(cc)
  end
  check(want(), "toutes conditions réunies : un ouvrier part")
  local ok, why
  ok, why = want({ survive = true }); check(not ok and why == "survie", "survie")
  ok, why = want({ alert = true }); check(not ok and why == "alerte", "alerte du QG")
  ok, why = want({ threat = V.THREAT_MAX + 1 }); check(not ok and why == "menace", "menace")
  check(want({ threat = V.THREAT_MAX }), "menace au seuil")
  ok, why = want({ request = true }); check(not ok and why == "demande de ressource", "une exploration de ressource demandée a priorité")
  ok, why = want({ tour_done = false }); check(not ok and why == "tour non fini", "le tour de fondation d'abord")
  check(want({ tour_done = nil }), "tour non renseigné : pas de blocage")
  -- Lot CORR-RECON : PNJ libres en SURPLUS (libres moins tâches prenables >= 2, >= 3 en crise)
  check(V.surplus(4, 1) == 3 and V.surplus(1, 4) == 0 and V.surplus(nil, nil) == 0, "surplus = libres - tâches, jamais négatif")
  check(want({ idle = 4, open_tasks = 1 }), "4 PNJ libres, 1 tâche prenable : un part (3 en surplus)")
  check(want({ idle = 4, open_tasks = 2 }), "4 PNJ libres, 2 tâches prenables : un part (surplus 2, au seuil)")
  ok, why = want({ idle = 4, open_tasks = 3 }); check(not ok and why == "tache libre", "4 PNJ libres, 3 tâches : surplus 1, personne ne part")
  ok, why = want({ idle = 4, open_tasks = 4 }); check(not ok and why == "tache libre", "4 PNJ libres, 4 tâches prenables : personne ne part")
  ok, why = want({ idle = 2, open_tasks = 1 }); check(not ok and why == "tache libre", "2 PNJ libres, 1 tâche : surplus 1, il reste")
  check(want({ idle = 5, open_tasks = 2, missing = true }), "crise, 5 libres, 2 tâches : surplus 3, un part")
  ok, why = want({ idle = 4, open_tasks = 2, missing = true }); check(not ok and why == "tache libre", "crise, 4 libres, 2 tâches : surplus 2 < 3, personne ne part")
  ok, why = want({ idle = 40, open_tasks = 39 }); check(not ok and why == "tache libre", "beaucoup de PNJ, presque toutes les tâches prises : non")
  ok, why = want({ idle = 0 }); check(not ok and why == "pas de PNJ libre", "aucun PNJ libre")
  ok, why = want({ idle = 1 }); check(not ok and why == "ouvriers pris", "un seul PNJ libre : il reste")
  check(want({ idle = V.IDLE_MIN }), "deux PNJ libres : un part")
  ok, why = want({ idle = V.IDLE_MIN, missing = true }); check(not ok and why == "ouvriers pris", "matière manquante : deux restent")
  check(want({ idle = V.IDLE_MIN_CRISIS, missing = true }), "crise, trois PNJ libres : un part")
  ok, why = want({ next_at = 100001 }); check(not ok and why == "delai", "délai")
  check(want({ next_at = 100000 }), "délai écoulé")
  local seen = {}
  for _, r in ipairs(V.REASONS) do seen[r] = true end
  for _, r in ipairs({ "survie", "alerte", "menace", "delai", "tache libre", "ouvriers pris", "tour non fini", "demande de ressource",
    "aucun secteur", "pas de PNJ libre" }) do
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
local function want_without(field, value)
  return wrap("want", function(o) return function(c) return o(copy_with(c, field, value)) end end)
end

mutant("interval ignore la menace", wrap("interval", function(o) return function(c, t) return o(c, 0) end end))
mutant("interval ignore la curiosité", wrap("interval", function(o) return function(c, t) return o(1000, t) end end))
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
mutant("want ignore la survie", want_without("survive", false))
mutant("want ignore l'alerte", want_without("alert", false))
mutant("want ignore la menace", want_without("threat", 0))
mutant("want ignore la demande de ressource", want_without("request", false))
mutant("want ignore le tour de fondation", want_without("tour_done", true))
mutant("want ignore les tâches libres", want_without("open_tasks", 0))
mutant("surplus ne retire pas les tâches", wrap("surplus", function(o) return function(i, t) return i or 0 end end))
mutant("surplus retire deux fois les tâches", wrap("surplus", function(o) return function(i, t) return math.max(0, (i or 0) - 2 * (t or 0)) end end))
mutant("surplus ignore les PNJ libres", wrap("surplus", function(o) return function(i, t) return 99 - (t or 0) end end))
mutant("surplus négatif non borné", wrap("surplus", function(o) return function(i, t) return (i or 0) - (t or 0) - 100 end end))
mutant("ancienne règle : une tâche prenable bloque", wrap("want", function(o) return function(c)
  if (c.open_tasks or 0) > 0 then return false, "tache libre" end
  return o(c)
end end))
mutant("la crise n'exige pas 3 en surplus", wrap("want", function(o) return function(c)
  local ok, why = o(c)
  if not ok and why == "tache libre" and c.missing then
    local cc = copy_with(c, "missing", false)
    return o(cc)
  end
  return ok, why
end end))
mutant("want ignore la crise", want_without("missing", false))
mutant("want ignore le délai", want_without("next_at", 0))
mutant("want ignore les PNJ libres", want_without("idle", 99))
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
