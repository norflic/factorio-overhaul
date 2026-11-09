--[[
  Lot FONTE-PRECOCE (9/11) : banc HORS JEU. Lancement, depuis la racine du mod : lua5.2 tests/fonte_precoce_test.lua
  Mesuré (sonde-8min, 3 graines, scarlet et azure) : 4 fours au QG avant le premier avant-poste de fer, minerai de fer qui attend au coffre (68 à 260), 213 plaques
  de fer fondues seulement à la minute 7 ou 8 ; la croissance de la fonderie du QG ne s'ouvrait qu'avec un avant-poste de fer à 75 % de capacité.
    1. règle pure Fp.extra : minerai qui attend, plaque sous son plancher, pas encore d'avant-poste de fer, borne ;
    2. B.generate : le but « capital:fonderie » existe avant l'avant-poste de fer quand le minerai attend ; pas sinon ; après l'avant-poste, règle d'avant ;
    3. câblage ; 4. mutants.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local passes, failures = 0, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end return cond end
local function read_src(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end
local ORE, PLATE = T.outposts.iron.resource, T.outposts.iron.product

local function load_world(over)
  over = over or {}
  local names = { "shared.ai3.fonte_precoce", "shared.ai3.buts" }
  local keys = { "Fp", "B" }
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
  local s = { is_player = false, workers = 8, soldiers = 0, soldiers_max = 0, stock = { [ORE] = 100, [PLATE] = 10 },
    cap = { coal = 1, iron = 0, copper = 0, stone = 0 }, pending = {}, sites = {}, smelters = 4, smelters_pending = 0,
    weights = B.weights({}, nil), research = nil, army_target = 0, economy_done = false }
  for k, x in pairs(over or {}) do s[k] = x end
  return s
end
local TG = { targets = { coal = 2, iron = 2, copper = 1, stone = 1 }, iron2_set = true }
local function goal_of(goals, key) for _, g in ipairs(goals) do if g.key == key then return g end end end

local function facts(W)
  local Fp, B = W.Fp, W.B
  local f = {}
  local function ex(over) local a = { cap = 0, plate = 10, floor = 100, ore = 100, have = 4 } for k, v in pairs(over or {}) do a[k] = v end return Fp.extra(a) end
  f.e_ok = ex()
  f.e_two = ex({ have = 4 })
  f.e_near_hard = ex({ have = 7, ore = 200 })
  f.e_hard = ex({ have = 8, ore = 500 })
  f.e_cap = ex({ cap = 0.8 })
  f.e_plate = ex({ plate = 100 })
  f.e_noore = ex({ ore = 30 })
  f.e_ore_edge = ex({ ore = 38 })
  f.e_ore_just = ex({ ore = 37 })
  f.e_nil = Fp.extra(nil)
  local function g(over) return goal_of(B.generate(fac_s(B, over), TG), "capital:fonderie") end
  local a0 = g({})
  f.g_early = a0 and a0.n or 0
  f.g_fond = (a0 and a0.fond) and 1 or 0
  local n0 = g({ cap = { coal = 1, iron = 1, copper = 0, stone = 0 }, smelters = 3, stock = { [ORE] = 100, [PLATE] = 500 } })
  f.g_nofond = (n0 and not n0.fond) and 1 or 0 -- fonderie ordinaire (avant-poste en place) : garde sa place parmi les K
  f.g_noore = g({ stock = { [ORE] = 20, [PLATE] = 10 } }) and 1 or 0
  f.g_plate = g({ stock = { [ORE] = 100, [PLATE] = 500 } }) and 1 or 0
  f.g_cap = g({ cap = { coal = 1, iron = 1, copper = 0, stone = 0 } }) and 1 or 0 -- avant-poste en place : règle d'avant (4 fours = la base, rien de plus)
  f.g_hard = g({ smelters = 8 }) and 1 or 0
  f.g_pending = (function() local x = g({ smelters = 3, smelters_pending = 1 }) return x and x.n or 0 end)()
  local x = g({ smelters = 6, smelters_pending = 1 })
  f.g_pend_hard = x and x.n or 0
  return f
end

local W0 = load_world()
local F0 = facts(W0)
print("== 1. Fp.extra")
check(F0.e_ok == 2, "minerai qui attend (100 pour 4 fours), plaque sous le plancher, pas d'avant-poste : 2 fours de plus (" .. F0.e_ok .. ")")
check(F0.e_near_hard == 1 and F0.e_hard == 0, "borne Fp.HARD : 7 fours -> 1 de plus ; 8 -> 0")
check(F0.e_cap == 0 and F0.e_plate == 0, "avant-poste de fer en place, ou plaque au-dessus du plancher : rien")
check(F0.e_noore == 0 and F0.e_ore_edge == 2 and F0.e_ore_just == 0, "minerai sous 30 s de débit des fours posés (38 = 4 x 19 x 30 / 60) : rien ; à 38 : oui")
check(F0.e_nil == 0, "sans entrée : rien")
print("== 2. B.generate")
check(F0.g_early == 2, "faction sans avant-poste de fer, minerai qui attend : but « capital:fonderie » de 2 fours (" .. F0.g_early .. ")")
check(F0.g_noore == 0 and F0.g_plate == 0 and F0.g_cap == 0 and F0.g_hard == 0, "sans minerai, plaque suffisante, avant-poste présent, borne : aucun but")
check(F0.g_pending == 2, "fours en cours comptés (3 posés + 1 en cours = 4 : 2 de plus) (" .. F0.g_pending .. ")")
check(F0.g_pend_hard == 1, "6 posés + 1 en cours = 7 : la borne de 8 ne laisse qu'un four (" .. F0.g_pend_hard .. ")")
check(F0.g_fond == 1 and F0.g_nofond == 1, "but de fonte précoce = FOND (hors des K places) ; la fonderie ordinaire reste dans les K")
print("== 3. Câblage")
do
  local buts = read_src("shared/ai3/buts.lua")
  check(buts:find("Fp.extra({ cap = s.cap[key.top]", 1, true) ~= nil and buts:find("or early > 0) then", 1, true) ~= nil, "buts : la règle ouvre le but avant l'avant-poste")
end
print("== 4. Mutants")
local killed, total = 0, 0
local function mutant(name, which, path, from, to)
  total = total + 1
  local src = read_src(path)
  local i, j = src:find(from, 1, true)
  if not i then check(false, "mutant '" .. name .. "' : texte introuvable") return end
  local ok, F = pcall(facts, load_world({ [which] = src:sub(1, i - 1) .. to .. src:sub(j + 1) }))
  local changed = not ok
  if ok then for k, v in pairs(F0) do if F[k] ~= v then changed = true end end end
  if check(changed, "mutant refusé : " .. name) then killed = killed + 1 end
end
local FP, BP = "shared/ai3/fonte_precoce.lua", "shared/ai3/buts.lua"
mutant("l'avant-poste en place ne coupe pas la règle", "Fp", FP, "if (a.cap or 0) >= Fp.CAP_MIN then return 0 end", "")
mutant("pas de borne", "Fp", FP, "return math.max(0, math.min(Fp.STEP, Fp.HARD - have))", "return Fp.STEP")
mutant("la plaque n'a pas besoin de manquer", "Fp", FP, "if (a.plate or 0) >= (a.floor or 0) then return 0 end", "")
mutant("le minerai n'a pas besoin d'attendre", "Fp", FP, "if (a.ore or 0) < have * Fp.PER_MIN * Fp.SECONDS / 60 then return 0 end", "")
mutant("le but ignore la règle", "B", BP, "or early > 0) then", ") then")
mutant("le but ne compte pas les fours en cours", "B", BP, "have = (s.smelters or 0) + (s.smelters_pending or 0) })", "have = (s.smelters or 0) })")
mutant("le but précoce prend une des K places", "B", BP, "fond = (early > 0 and (s.cap[key.top] or 0) < 0.75) or nil }", "fond = nil }")
mutant("la cible ne monte pas", "B", BP, "smelters_want = math.max(smelters_want, (s.smelters or 0) + (s.smelters_pending or 0) + early)", "smelters_want = smelters_want")
print(string.format("   mutants refusés : %d / %d", killed, total))
check(killed == total, "tous les mutants refusés")
print(string.format("[FONTE-PRECOCE] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, total))
os.exit(failures == 0 and 0 or 1)
