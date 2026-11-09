--[[
  Lot TOURELLE-FER (9/11, option B) : banc HORS JEU. Lancement, depuis la racine du mod : lua5.2 tests/tourelle_fer_test.lua
  Mesuré (sonde de fer, 3 graines) : l'agrandissement du fer sur le champ déjà pris attend les tourelles de « défendre d'abord » (4,6 / 1,2 / 4,3 min
  sur 15 chez player) ; la tourelle d'un avant-poste ordinaire exige le fer au-dessus du plancher de 150 plus son prix. Elle débloque +8 foreuses.
    1. règle pure Tf.floors : avant-poste de fer sous son nombre de tourelles -> plancher réduit ; le reste inchangé ;
    2. le planificateur : la tourelle de l'avant-poste de fer est commandée à un stock plus bas que celle d'un avant-poste de cuivre ;
    3. Mu.defer_spare / Mu.stock_target : la réserve dormante de chargeurs attend ; manque urgent, minimum et réserve sur la menace restent ;
    4. le but « defense:munitions » (B.generate) suit s.iron_unlock ;
    5. câblage (sources) ; 6. mutants.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local S = require("shared.team.scale")
local passes, failures = 0, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end return cond end
local function read_src(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end
local AMMO = T.turret_ammo
local IRON, COPPER = T.outposts.iron.product, T.outposts.copper.product
local book = Book.new(dofile("tests/fixtures/recipes.lua"))

local function load_world(over)
  over = over or {}
  local names = { "shared.team.tourelle_fer", "shared.team.munitions", "shared.team.planner", "shared.ai3.buts" }
  local keys = { "Tf", "Mu", "Pl", "B" }
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

local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true, defense = true },
    deferred = {}, stock = {}, incoming = {}, outposts = {}, pending = {}, sites = { iron = 1 }, smelters = 2,
    smelters_pending = 0, smelter_task = false, smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0,
    turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 8, workers_max = 30, workers_idle = 0,
    threatened = false, open = {}, workers_wanted = 30, no_research = true, ladder = T.player_ladder,
    hq_turrets = T.defend_hq, defend_first = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function post_of(Pl, iron, kind)
  local p = Pl.plan(view({ stock = { [IRON] = iron, [COPPER] = 100 }, outposts = {
    { id = 1, kind = kind, drills = 16, turrets = 2, d2 = 100, pos = { x = 50, y = 0 }, has_fortify = false, idle_ticks = 0, fuel_low = false,
      output = 0, outputs = {}, stuck = 0, dry = 0, burners = 0 } } }), book)
  for _, x in ipairs(p.defend and p.defend.posts or {}) do if x.id == 1 then return x end end
end
local function fac_s(B, over)
  local s = { is_player = true, workers = 8, soldiers = 0, soldiers_max = 0, stock = { [AMMO] = 69, stone = 50 },
    cap = { coal = 1, iron = 2, copper = 1, stone = 1 }, pending = {}, sites = {}, smelters = 4, smelters_pending = 0,
    weights = B.weights({}, nil), research = nil, army_target = 0, economy_done = false, turrets_n = 10, ammo_missing = 0, ammo_reserve = 0 }
  for k, x in pairs(over or {}) do s[k] = x end
  return s
end
local TG = { targets = { coal = 2, iron = 2, copper = 1, stone = 1 }, iron2_set = true }
local function goal_of(goals, key) for _, g in ipairs(goals) do if g.key == key then return g end end end

local function facts(W)
  local Tf, Mu, Pl, B = W.Tf, W.Mu, W.Pl, W.B
  local f = {}
  local function fl(post) local a, b, c = Tf.floors(post, 150, 30, 60, 30) return a .. "/" .. b .. "/" .. tostring(c) end
  f.f_iron = fl({ iron = true, have = 2, want = 3 })
  f.f_full = fl({ iron = true, have = 3, want = 3 })
  f.f_other = fl({ iron = nil, have = 0, want = 2 })
  f.f_nil = fl(nil)
  f.f_low = Tf.floors({ iron = true, have = 0, want = 1 }, 40, 30, 60, 30)
  -- planificateur : seuils
  local function first_fab(kind) for _, iron in ipairs({ 100, 120, 140, 160, 180, 200, 220, 240, 260, 280, 300, 320, 340, 360, 380, 400 }) do
    local x = post_of(Pl, iron, kind)
    if x and x.why == "fabrication" then return iron end end return -1 end
  f.pl_iron = first_fab("iron")
  f.pl_copper = first_fab("copper")
  local x = post_of(Pl, 250, "iron")
  f.pl_reduced = (x and x.reduced) and 1 or 0
  f.pl_floor = x and x.floor_i or -1
  -- munitions
  f.m_off, f.m_on, f.m_nil = Mu.defer_spare(false), Mu.defer_spare(true), Mu.defer_spare(nil)
  f.t_spare = Mu.stock_target({ turrets = 10, missing = 0, base = 20, floor = 60 })
  f.t_defer = Mu.stock_target({ turrets = 10, missing = 0, base = 20, floor = 20, defer_spare = true })
  f.t_missing = Mu.stock_target({ turrets = 10, missing = 35, base = 20, floor = 20, defer_spare = true })
  f.t_reserve = Mu.stock_target({ turrets = 10, missing = 0, base = 20, floor = 150, defer_spare = true })
  local function g(over) return goal_of(B.generate(fac_s(B, over), TG), "defense:munitions") end
  local a0, a1 = g({}), g({ iron_unlock = true })
  f.g_n0, f.g_unlock = a0 and a0.n or 0, a1 and 1 or 0
  local a2 = g({ iron_unlock = true, stock = { [AMMO] = 8, stone = 50 } })
  f.g_min = a2 and a2.n or 0
  local a3 = g({ iron_unlock = true, ammo_reserve = 150 })
  f.g_reserve = a3 and a3.n or 0
  return f
end

local W0 = load_world()
local F0 = facts(W0)
print("== 1. Tf.floors")
check(F0.f_iron == "60/30/true", "avant-poste de fer sous son nombre de tourelles : plancher réduit (" .. F0.f_iron .. ")")
check(F0.f_full == "150/30/false" and F0.f_other == "150/30/false" and F0.f_nil == "150/30/false", "nombre atteint, autre avant-poste, poste absent : planchers ordinaires")
check(F0.f_low == 40, "un plancher déjà plus bas que le réduit n'est jamais relevé")
print("== 2. Planificateur")
check(F0.pl_iron > 0 and F0.pl_copper > 0 and F0.pl_iron < F0.pl_copper, "la tourelle du fer est commandée à un stock plus bas (" .. F0.pl_iron .. ") que celle du cuivre (" .. F0.pl_copper .. ")")
check(F0.pl_reduced == 1 and F0.pl_floor == 60, "le poste du fer porte le plancher réduit (journal [FO-DEFENSE])")
print("== 3. Munitions")
check(F0.m_on == true and F0.m_off == false and F0.m_nil == false, "Mu.defer_spare suit le signal")
check(F0.t_spare == 100 and F0.t_defer == 20 and F0.t_missing == 35 and F0.t_reserve == 150, "stock visé : réserve différée, manque urgent et réserve sur la menace gardés")
print("== 4. Le but defense:munitions")
check(F0.g_n0 == 31 and F0.g_unlock == 0, "69 au coffre : 31 à fabriquer pour la réserve ; plus aucun but quand la tourelle du fer manque")
check(F0.g_min == 12 and F0.g_reserve == 81, "minimum (20) et réserve sur la menace (150) restent payés (" .. F0.g_min .. ", " .. F0.g_reserve .. ")")
print("== 5. Câblage")
do
  local cer, plan, buts = read_src("shared/ai3/cerveau.lua"), read_src("shared/team/planner.lua"), read_src("shared/ai3/buts.lua")
  check(cer:find("iron_unlock = iron_unlock", 1, true) and cer:find("o.kind == top_kind and (o.turrets or 0) < T.defend_turrets(o.drills or 0)", 1, true),
    "cerveau : iron_unlock lu aux avant-postes de la ressource clé sous leurs tourelles")
  check(plan:find("if not qg_peril and pri.mode ~= Pr.MODE_SURVIE_PENURIE then fi, fc, reduced = Tf.floors(p, fl_i, fl_c, Sq.FLOOR_IRON, Sq.FLOOR_COPPER) end", 1, true) ~= nil, "planificateur : planchers de la tourelle du fer")
  check(buts:find("Mu.defer_spare(s.iron_unlock)", 1, true) ~= nil, "buts : la réserve lit le signal")
end
print("== 6. Mutants")
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
local TFP, MUP, PLP, BP = "shared/team/tourelle_fer.lua", "shared/team/munitions.lua", "shared/team/planner.lua", "shared/ai3/buts.lua"
mutant("tout poste a le plancher réduit", "Tf", TFP, "not post.iron or", "false or")
mutant("le nombre de tourelles atteint ne compte pas", "Tf", TFP, "or num(post.have) >= num(post.want)", "")
mutant("plancher jamais réduit", "Tf", TFP, "local fi, fc = math.min(base_iron, num(low_iron)), math.min(base_copper, num(low_copper))", "local fi, fc = base_iron, base_copper")
mutant("plancher relevé au réduit", "Tf", TFP, "math.min(base_iron, num(low_iron))", "num(low_iron)")
mutant("le planificateur ignore la règle", "Pl", PLP, "fi, fc, reduced = Tf.floors(p, fl_i, fl_c, Sq.FLOOR_IRON, Sq.FLOOR_COPPER)", "fi, fc, reduced = fl_i, fl_c, false")
mutant("le planificateur ne passe pas le plancher", "Pl", PLP, "d.why = want_defense(items, fi, fc) and \"fabrication\" or \"manque\"\n              if d.why == \"manque\" then d.raw = last_raw end\n            end",
  "d.why = want_defense(items) and \"fabrication\" or \"manque\"\n              if d.why == \"manque\" then d.raw = last_raw end\n            end")
mutant("la réserve dormante n'attend pas", "Mu", MUP, "(a.defer_spare and 0 or turrets * Mu.SPARE)", "(turrets * Mu.SPARE)")
mutant("Mu.defer_spare toujours faux", "Mu", MUP, "return unlock == true", "return false")
mutant("Mu.defer_spare toujours vrai", "Mu", MUP, "return unlock == true", "return true")
mutant("le but ignore le signal", "B", BP, "Mu.defer_spare(s.iron_unlock)", "false")
mutant("le plancher ordinaire reste de 60", "B", BP, "defer and B.AMMO_MIN or B.AMMO_STOCK", "B.AMMO_STOCK")
mutant("la réserve sur la menace est écrasée", "B", BP, "math.max(defer and B.AMMO_MIN or B.AMMO_STOCK, reserve)", "(defer and B.AMMO_MIN or B.AMMO_STOCK)")
mutant("le manque urgent est écrasé", "Mu", MUP, "local t = num(a.missing) +", "local t = 0 +")
print(string.format("   mutants refusés : %d / %d", killed, total))
check(killed == total, "tous les mutants refusés")
print(string.format("[TOURELLE-FER] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, total))
os.exit(failures == 0 and 0 or 1)
