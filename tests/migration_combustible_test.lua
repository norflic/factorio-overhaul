--[[
  Lot COMBUSTIBLE-MIGRATION (9/11) : règle pure du retrait des paires d'une bande de COMBUSTIBLE (shared/team/migration_combustible.lua) et seuil court du
  retour en arrière (shared/team/migration_retour.lua, c.fuel_low). Défaut mesuré : INTEG-NORMAL carte-g123456789-52b5db3a, avant-poste de charbon 2, 10 paires
  retirées à 33,0 min pour une bande à 0/134 entités ; plancher = générateurs seuls (~0).
  Lancement : lua5.2 tests/migration_combustible_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local quiet = false
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local MIN = 3600

local function battery(Mc, R, Th)
  -- 1. plancher : générateurs + brûleurs à pleine cadence
  check(math.abs(Mc.floor(0.5, { { kw = 150, n = 70 }, { kw = 90, n = 60 } }, 4000) - (0.5 + (10500 + 5400) / 4000)) < 1e-9, "plancher = générateurs + brûleurs (150 kW x 70, 90 kW x 60)")
  check(Mc.floor(0.5, { { kw = 150, n = 70 } }, nil) == 0.5 and Mc.floor(nil, nil, 4000) == 0, "sans valeur du combustible : les générateurs seuls ; sans rien : 0")
  check(Mc.floor(0, { { kw = -5, n = 3 }, { kw = 90, n = -1 } }, 4000) == 0, "valeurs négatives ignorées")
  -- 2. le cas mesuré : 70 brûleurs thermiques + 60 fours, 12 paires de charbon dont 10 retirées (reste 2 x 0,25 = 0,5/s), stock au QG 0
  local floor = Mc.floor(0, { { kw = 150, n = 70 }, { kw = 90, n = 60 } }, 4000)
  local ok, why = Mc.cut_ok({ fuel = true, ready = true, rest = 0.5, floor = floor, stock = 0 })
  check(ok == false and why == "stock-insuffisant", "cas mesuré (stock 0) : la coupe attend, paires en place")
  ok, why = Mc.cut_ok({ fuel = true, ready = true, rest = 0.5, floor = floor, stock = 150 })
  check(ok == false and why == "stock-insuffisant", "cas mesuré (stock 150 du QG) : toujours refusé")
  local need = (floor - 0.5) * Mc.CFG.build_s
  ok, why = Mc.cut_ok({ fuel = true, ready = true, rest = 0.5, floor = floor, stock = need })
  check(ok == true and why == "stock-couvre", "le stock couvre exactement le manque pendant le chantier : la coupe passe")
  ok = Mc.cut_ok({ fuel = true, ready = true, rest = 0.5, floor = floor, stock = need - 1 })
  check(ok == false, "un charbon de moins que le manque : refusé")
  ok, why = Mc.cut_ok({ fuel = true, ready = true, rest = 5, floor = floor, stock = 0 })
  check(ok == true and why == "plancher-tenu", "ce qui reste tient le plancher : la coupe passe sans stock")
  ok, why = Mc.cut_ok({ fuel = true, ready = true, rest = 0, floor = 0, stock = 0 })
  check(ok == true and why == "plancher-tenu", "aucun brûleur ni générateur : rien à protéger")
  -- 3. bande non constructible (ennemi, matières) : refusée même avec du stock
  ok, why = Mc.cut_ok({ fuel = true, ready = false, rest = 5, floor = 1, stock = 1e9 })
  check(ok == false and why == "pas-constructible", "bande non constructible maintenant : refusée")
  -- 4. hors combustible : la règle ne retient jamais
  ok, why = Mc.cut_ok({ fuel = false, ready = false, rest = 0, floor = 100, stock = 0 })
  check(ok == true and why == "hors-combustible", "hors combustible : jamais retenu")
  -- 5. pas d'impasse : la demande refusée tombe d'elle-même (Th.verdict : annulée après critical_wait, redemandée plus tard)
  check(Th.verdict(false, true, 1 * MIN) == "attendre" and Th.verdict(false, true, Th.CFG.critical_wait + 1) == "annuler",
    "coupe refusée : attente puis annulation, jamais une bande bloquée par ses propres paires")
  check(Th.verdict(true, true, 0) == "retirer", "coupe permise : retirer")
  -- 6. stock bas
  check(Mc.low(0, 4, Mc.CFG) == true and Mc.low(4 * Mc.CFG.horizon, 4, Mc.CFG) == false and Mc.low(4 * Mc.CFG.horizon - 1, 4, Mc.CFG) == true,
    "stock bas : sous horizon x plancher")
  check(Mc.low(0, 0, Mc.CFG) == false, "sans plancher : pas de manque")
  -- 6 bis. même formule que Th.fuel_short de la branche mega-fer-ordre (zero-idle-4 : floor > 1e-9 et stock + 1e-9 < floor x horizon, horizon 600 s) ; comparée à elle si elle est présente
  for _, c in ipairs({ { 0, 0 }, { 5, 0 }, { 0, 0.5 }, { 299, 0.5 }, { 300, 0.5 }, { 301, 0.5 }, { 1e9, 3 }, { 1e-12, 1e-12 } }) do
    local want = (c[2] > 1e-9) and (c[1] + 1e-9 < c[2] * 600)
    check(Mc.low(c[1], c[2], Mc.CFG) == want, string.format("Mc.low(%g, %g) = formule de Th.fuel_short", c[1], c[2]))
    if Th.fuel_short then check(Mc.low(c[1], c[2], Mc.CFG) == Th.fuel_short(c[1], c[2]), string.format("Mc.low(%g, %g) = Th.fuel_short", c[1], c[2])) end
  end
  check(Mc.CFG.horizon == 600 and Th.CFG.horizon == Mc.CFG.horizon, "horizon de Mc.low = Th.CFG.horizon (600 s)")
  -- 7. retour en arrière : seuil court quand le combustible manque
  check(R.CFG.stall_fuel == 5 * MIN and R.CFG.stall == 15 * MIN, "seuils : 5 min (combustible bas) et 15 min")
  local d, w = R.decide({ undo = 10, produced = false, state = "chantier", stalled = 6 * MIN, built = 0, total = 134, fuel_low = true })
  check(d == "retour" and w == "chantier-lent", "combustible bas, 6 min sans progrès, 0/134 : paires reposées")
  d, w = R.decide({ undo = 10, produced = false, state = "chantier", stalled = 6 * MIN, built = 0, total = 134 })
  check(d == "rien" and w == "avance", "combustible non bas : le seuil reste 15 min")
  d = R.decide({ undo = 10, produced = false, state = "chantier", stalled = 4 * MIN, built = 0, total = 134, fuel_low = true })
  check(d == "rien", "combustible bas mais 4 min seulement : on attend")
  d, w = R.decide({ undo = 10, produced = false, state = "chantier", stalled = 20 * MIN, built = 125, total = 134, fuel_low = true })
  check(d == "rien" and w == "presque-finie", "bande bâtie à 90 % : on la finit même combustible bas")
  d, w = R.decide({ undo = 10, produced = true, state = "chantier", stalled = 20 * MIN, built = 0, total = 134, fuel_low = true })
  check(d == "rien" and w == "produit", "une ligne qui a produit n'est jamais reposée")
end

local Mc0 = dofile("shared/team/migration_combustible.lua")
local R0 = dofile("shared/team/migration_retour.lua")
local Th0 = dofile("shared/team/thermique.lua")
battery(Mc0, R0, Th0)

-- 8. branchement dans l'exécutant (lecture du code)
local src = read("script/team/migration_champ.lua")
check(src:find('require("shared.team.migration_combustible")', 1, true) ~= nil, "migration_champ.lua requiert la règle")
local i = src:find("local function step_project", 1, true)
local blk = i and src:sub(i, i + 9000) or ""
check(blk:find("Mc.cut_ok(", 1, true) ~= nil and blk:find("fuel_floor(f, surface)", 1, true) ~= nil and blk:find("Th.verdict(ok, ctx.critical[o.kind], env.gate_age)", 1, true) ~= nil,
  "step_project : Mc.cut_ok décide la coupe d'une bande de combustible, puis Th.verdict")
check(src:find("fuel_low = fuel_low", 1, true) ~= nil and src:find("Mc.low(Stock.count(f, T.fuel), fuel_floor(f, surface))", 1, true) ~= nil,
  "step_build : le combustible bas est passé à Rb.decide")
check(src:find("sp.burner_kw", 1, true) ~= nil and src:find("fuel_value", 1, true) ~= nil, "plancher des brûleurs lu aux données (Mod.spec, prototype du combustible)")

-- 9. mutants
local function load_with(path, from, to)
  local s = read(path)
  local a, b = s:find(from, 1, true)
  assert(a, "motif de mutant introuvable : " .. from)
  assert(not s:find(from, b + 1, true), "motif de mutant ambigu : " .. from)
  return assert(load(s:sub(1, a - 1) .. to .. s:sub(b + 1), "=" .. path))()
end
local function mutant(label, path, from, to)
  local Mc, R = Mc0, R0
  if path:find("migration_combustible", 1, true) then Mc = load_with(path, from, to) else R = load_with(path, from, to) end
  local p0, f0 = passes, failures
  quiet = true
  local okb = pcall(battery, Mc, R, Th0)
  quiet = false
  local caught = failures > f0 or not okb
  passes, failures = p0, f0
  check(caught, "mutant refuse : " .. label)
end
local MCP, RP = "shared/team/migration_combustible.lua", "shared/team/migration_retour.lua"
mutant("bande bloquée par ses propres paires (le stock suffit mais la coupe est refusée)", MCP, 'if (c.stock or 0) + EPS >= deficit * cfg.build_s then return true, "stock-couvre" end', 'if false then return true, "stock-couvre" end')
mutant("plancher des seuls générateurs (brûleurs de l'équipe ignorés)", MCP, "total = total + math.max(0, b.kw or 0) * math.max(0, b.n or 0) / fuel_kj", "total = total + 0")
mutant("chantier de durée nulle (le stock n'a rien à couvrir)", MCP, "build_s = 26 * 60,", "build_s = 0,")
mutant("bande non constructible acceptée", MCP, 'if not c.ready then return false, "pas-constructible" end', "")
mutant("hors combustible retenu (migration des autres minerais bloquée)", MCP, 'if not c.fuel then return true, "hors-combustible" end', 'if not c.fuel then return false, "hors-combustible" end')
mutant("ce qui reste ignoré (le manque = tout le plancher)", MCP, "local deficit = math.max(0, (c.floor or 0) - math.max(0, c.rest or 0))", "local deficit = math.max(0, (c.floor or 0))")
mutant("stock bas jamais vu", MCP, "return (stock or 0) + EPS < floor * cfg.horizon", "return false")
mutant("seuil court ignoré au retour en arrière", RP, "if (c.stalled or 0) >= ((c.fuel_low and cfg.stall_fuel) or cfg.stall) then", "if (c.stalled or 0) >= cfg.stall then")
mutant("seuil court appliqué à tout (combustible non bas compris)", RP, "if (c.stalled or 0) >= ((c.fuel_low and cfg.stall_fuel) or cfg.stall) then", "if (c.stalled or 0) >= cfg.stall_fuel then")

print(string.format("[COMBUSTIBLE-MIGRATION] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
