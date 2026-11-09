--[[
  Lot FER-MUNITIONS (9/11) : banc HORS JEU. La réserve DORMANTE de chargeurs attend que le noyau de la défense soit couvert.
  Lancement, depuis la racine du mod : lua5.2 tests/fer_munitions_test.lua
  Mesuré (partie neuve, journal [FO-FER-SORTIE] de defense-ap, minutes 5 à 11) : 884 plaques de fer en chargeurs contre 200 en tourelles ;
  240 d'un coup à la minute 11 alors que 69 chargeurs dormaient au coffre, toutes les tourelles garnies (aucune sous le seuil bas), et que le
  noyau de la défense manquait de 28 à 67 plaques (pile : « noyau non couvert »).
    1. règle pure Mu.defer_spare : retenue de la pile ET noyau non couvert (budget évalué) ; sinon faux ;
    2. Mu.stock_target avec defer_spare : la réserve (Mu.SPARE par tourelle) attend ; le manque urgent et le plancher restent ;
    3. le but « defense:munitions » (B.generate) : réserve dormante différée, MINIMUM, réserve sur la menace reçue et manque urgent gardés ;
       pile absente, noyau couvert, ou pile non retenue : règle d'avant ;
    4. câblage (sources) ; 5. mutants.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end
local function read_src(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end
local AMMO = T.turret_ammo

local function load_world(over)
  over = over or {}
  local names = { "shared.team.munitions", "shared.ai3.buts" }
  local keys = { "Mu", "B" }
  local saved = {}
  for _, n in ipairs(names) do saved[n] = package.loaded[n]; package.loaded[n] = nil end
  local W = {}
  for i, n in ipairs(names) do
    local k = keys[i]
    if over[k] then package.loaded[n] = assert(load(over[k], "@" .. n))() else package.loaded[n] = require(n) end
    W[k] = package.loaded[n]
  end
  for _, n in ipairs(names) do package.loaded[n] = saved[n] end
  return W
end

local function fac_s(B, over)
  local s = { is_player = true, workers = 8, soldiers = 0, soldiers_max = 0, stock = { [AMMO] = 69, stone = 50 },
    cap = { coal = 1, iron = 2, copper = 1, stone = 1 }, pending = {}, sites = {}, smelters = 4, smelters_pending = 0,
    weights = B.weights({}, nil), research = nil, army_target = 0, economy_done = false, turrets_n = 10, ammo_missing = 0,
    ammo_reserve = 0 }
  for k, x in pairs(over or {}) do s[k] = x end
  return s
end
local function goal_of(goals, key) for _, g in ipairs(goals) do if g.key == key then return g end end end
local function st_of(pile) return { targets = { coal = 2, iron = 2, copper = 1, stone = 1 }, iron2_set = true, pile = pile } end
local SHORT = { hold = true, budget = { core_ok = false, covered = false } }   -- retenue, noyau non couvert
local COVERED = { hold = false, parallel = true, budget = { core_ok = true, covered = true } }
local HELD_OK = { hold = true, budget = { core_ok = true, covered = false } }   -- retenue mais noyau couvert une fois seulement

local function facts(W)
  local Mu, B = W.Mu, W.B
  local f = {}
  f.d_short, f.d_cov, f.d_heldok, f.d_nil, f.d_nobud = Mu.defer_spare(SHORT), Mu.defer_spare(COVERED), Mu.defer_spare(HELD_OK),
    Mu.defer_spare(nil), Mu.defer_spare({ hold = true })
  f.d_nohold = Mu.defer_spare({ hold = false, budget = { core_ok = false } })
  f.t_spare = Mu.stock_target({ turrets = 10, missing = 0, base = 20, floor = 60 })
  f.t_defer = Mu.stock_target({ turrets = 10, missing = 0, base = 20, floor = 20, defer_spare = true })
  f.t_defer_missing = Mu.stock_target({ turrets = 10, missing = 35, base = 20, floor = 20, defer_spare = true })
  f.t_defer_reserve = Mu.stock_target({ turrets = 10, missing = 0, base = 20, floor = 150, defer_spare = true })
  local function g(pile, over) return goal_of(B.generate(fac_s(B, over), st_of(pile)), "defense:munitions") end
  local a0, a1, a2 = g(nil), g(SHORT), g(COVERED)
  f.g_nil_n, f.g_short, f.g_cov_n = a0 and a0.n or 0, a1 and 1 or 0, a2 and a2.n or 0
  local a3 = g(SHORT, { stock = { [AMMO] = 8, stone = 50 } })
  f.g_min_n, f.g_min_minimal = a3 and a3.n or 0, a3 and a3.minimal_n or -1
  local a4 = g(SHORT, { ammo_reserve = 150 })
  f.g_reserve_n = a4 and a4.n or 0
  local a5 = g(SHORT, { ammo_missing = 60 })
  f.g_urgent_n = a5 and a5.n or 0
  local a6 = g(HELD_OK)
  f.g_heldok_n = a6 and a6.n or 0
  f.g_nopile_old = (g({ hold = true }) and 1 or 0)
  return f
end

local W0 = load_world()
local F0 = facts(W0)

print("== 1. Règle pure Mu.defer_spare")
check(F0.d_short == true, "retenue + noyau non couvert : la réserve dormante attend")
check(F0.d_cov == false and F0.d_heldok == false, "noyau couvert (même une fois seulement) : règle d'avant")
check(F0.d_nil == false and F0.d_nobud == false and F0.d_nohold == false, "sans pile, sans budget évalué, ou sans retenue : règle d'avant")

print("== 2. Mu.stock_target")
check(F0.t_spare == 100, "règle d'avant : 10 tourelles, 10 chargeurs de réserve chacune = 100 (" .. F0.t_spare .. ")")
check(F0.t_defer == 20, "réserve différée, rien d'urgent : le plancher seul (" .. F0.t_defer .. ")")
check(F0.t_defer_missing == 35, "le manque URGENT reste visé (" .. F0.t_defer_missing .. ")")
check(F0.t_defer_reserve == 150, "la réserve sur la menace reçue reste visée (" .. F0.t_defer_reserve .. ")")

print("== 3. Le but « defense:munitions »")
check(F0.g_nil_n == 31, "sans pile : 100 visés, 69 au coffre = 31 (règle d'avant) (" .. F0.g_nil_n .. ")")
check(F0.g_short == 0, "noyau non couvert : 69 chargeurs dorment au coffre, aucun but de réserve (le cas mesuré)")
check(F0.g_cov_n == 31, "noyau couvert : la réserve reprend (31)")
check(F0.g_min_n == 12 and F0.g_min_minimal == 12, "sous le MINIMUM (8 au coffre) : la part jusqu'au minimum de 20 reste fabriquée (" .. F0.g_min_n .. ")")
check(F0.g_reserve_n == 81, "réserve sur la menace reçue (150) : 150 - 69 = 81 même noyau non couvert (" .. F0.g_reserve_n .. ")")
check(F0.g_urgent_n == 0, "manque urgent 60 avec 69 au coffre : couvert par le stock, rien à fabriquer en plus")
check(F0.g_heldok_n == 31, "retenue mais noyau couvert : règle d'avant (31)")
check(F0.g_nopile_old == 1, "pile retenue sans budget évalué (réglage éteint) : règle d'avant, le but reste")

print("== 4. Câblage")
do
  local buts = read_src("shared/ai3/buts.lua")
  check(buts:find("Mu.defer_spare(st and st.pile)", 1, true) ~= nil, "buts.lua : le but lit l'état de la pile")
  check(buts:find("defer_spare = defer", 1, true) ~= nil and buts:find("defer and B.AMMO_MIN or B.AMMO_STOCK", 1, true) ~= nil,
    "buts.lua : le stock visé et le plancher suivent la différée")
end

print("== 5. Mutants")
local killed, total = 0, 0
local function mutant(name, which, from, to)
  total = total + 1
  local path = which == "Mu" and "shared/team/munitions.lua" or "shared/ai3/buts.lua"
  local src = read_src(path)
  local i, j = src:find(from, 1, true)
  if not i then check(false, "mutant '" .. name .. "' : texte introuvable") return end
  local W = load_world({ [which] = src:sub(1, i - 1) .. to .. src:sub(j + 1) })
  local ok, F = pcall(facts, W)
  local changed = not ok -- un plantage compte comme détecté
  if ok then for k, v in pairs(F0) do if F[k] ~= v then changed = true end end end
  if check(changed, "mutant refusé : " .. name) then killed = killed + 1 end
end
mutant("la pile sans retenue compte", "Mu", "pile.hold == true and", "true and")
mutant("noyau couvert compte", "Mu", "pile.budget.core_ok == false", "pile.budget.core_ok ~= nil")
mutant("budget non évalué compte", "Mu", 'type(pile.budget) == "table" and', "")
mutant("la réserve dormante n'est pas différée", "Mu", "(a.defer_spare and 0 or turrets * Mu.SPARE)", "(turrets * Mu.SPARE)")
mutant("le plancher ordinaire reste de 60", "B", "defer and B.AMMO_MIN or B.AMMO_STOCK", "B.AMMO_STOCK")
mutant("le but ignore la différée", "B", "floor = ammo_target, defer_spare = defer", "floor = ammo_target")
mutant("la réserve sur la menace est écrasée", "B", "math.max(defer and B.AMMO_MIN or B.AMMO_STOCK, reserve)", "(defer and B.AMMO_MIN or B.AMMO_STOCK)")
mutant("le manque urgent est écrasé", "Mu", "local t = num(a.missing) +", "local t = 0 +")
print(string.format("   mutants refusés : %d / %d", killed, total))
check(killed == total, "tous les mutants refusés")

print(string.format("[FER-MUNITIONS] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, total))
os.exit(failures == 0 and 0 or 1)
