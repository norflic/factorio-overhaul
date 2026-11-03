--[[
  Lot MUNITIONS (retour du DC du 3/11, partie 0.6.46 : « ils ont sous-produit des balles, donc les tourelles n'étaient pas chargées complètement
  [...] ils ont pas rempli à fond les munitions ») : banc HORS JEU. Lancement : lua5.2 tests/munitions_test.lua (racine du mod).

    1. la règle pure (shared/team/munitions.lua) : cible par tourelle (ordinaire, riche), seuil de recharge au plein, groupe, tournée due,
       prise partielle, stock visé au coffre ;
    2. le CAS du DC (fo-logs/2026-11-03_RETOUR3) : QG à 120 chargeurs pour 8 tourelles à 140,2 min, 40 tourelles et 158 chargeurs visés à
       117 min, 8 000 à 11 000 plaques de fer au coffre ;
    3. le planificateur : recharge au plein, partielle, le reste fabriqué à la même priorité ; vue sans relevé : règle d'avant à l'identique ;
    4. le cerveau : le but « defense:munitions » suit les tourelles ; sans relevé : règle d'avant ;
    5. la CHAÎNE lue dans les sources (outposts, team, worker, planner, cerveau, buts) ;
    6. mutants : chaque règle cassée change au moins un fait observé.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local S = require("shared.team.scale")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end
local function read_src(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local IRON, COPPER = T.outposts.iron.product, T.outposts.copper.product
local AMMO = T.turret_ammo

--- Charge Mu, puis le planificateur et les buts qui le requièrent (un mutant passe un texte modifié par module).
local function load_world(over)
  over = over or {}
  local names = { "shared.team.munitions", "shared.team.planner", "shared.ai3.buts" }
  local keys = { "Mu", "Pl", "B" }
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

local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)
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
local function keys_of(p)
  local set = {}
  for _, t in ipairs(p.tasks) do set[t.key] = true end
  return set
end
local function crafted(p, tag)
  local n = 0
  for _, t in ipairs(p.tasks) do if t.kind == "craft" and t.item == AMMO and t.tag == tag then n = n + t.count end end
  return n
end
local function fac_s(B, over)
  local s = { is_player = true, workers = 8, soldiers = 0, soldiers_max = 0, stock = { [AMMO] = 10, stone = 50 },
    cap = { coal = 1, iron = 2, copper = 1, stone = 1 }, pending = {}, sites = {}, smelters = 4, smelters_pending = 0,
    weights = B.weights({}, nil), research = nil, army_target = 0, economy_done = false }
  for k, x in pairs(over or {}) do s[k] = x end
  return s
end
local TG = { targets = { coal = 2, iron = 2, copper = 1, stone = 1 }, iron2_set = true }
local function goal_of(goals, key) for _, g in ipairs(goals) do if g.key == key then return g end end end

--- Les FAITS observés (le témoin et chaque mutant les recalculent).
local function facts(W)
  local Mu, Pl, B = W.Mu, W.Pl, W.B
  local f = {}
  -- 1. règle pure
  f.pt_base = Mu.per_turret({ base = 20, rich = 50, turrets = 40, iron = 4799, mag_iron = 4 })
  f.pt_rich = Mu.per_turret({ base = 20, rich = 50, turrets = 40, iron = 4800, mag_iron = 4 })
  f.pt_none = Mu.per_turret({ base = 20, rich = 50, turrets = 0, iron = 99999, mag_iron = 4 })
  f.pt_bad = Mu.per_turret({ base = 20, rich = 10, turrets = 5, iron = 99999, mag_iron = 4 })
  f.top20, f.top50 = Mu.top(20), Mu.top(50)
  local g = Mu.group({ 20, 19, 15, 14, 7, 0 }, 20, 8)
  f.g_short, f.g_missing, f.g_low = g.short, g.missing, g.low
  f.due_small = Mu.due({ short = 1, missing = 6, low = 0 }) and 1 or 0
  f.due_trip = Mu.due({ short = 2, missing = 10, low = 0 }) and 1 or 0
  f.due_low = Mu.due({ short = 1, missing = 6, low = 1 }) and 1 or 0
  f.due_none = Mu.due({ short = 0, missing = 0, low = 0 }) and 1 or 0
  f.take_full = Mu.take(30, 3, 100)
  f.take_part = Mu.take(30, 3, 15)
  f.take_none = Mu.take(30, 3, 14)
  f.st_turrets = Mu.stock_target({ turrets = 40, missing = 0, floor = 158 })
  f.st_floor = Mu.stock_target({ turrets = 4, missing = 0, floor = 60 })
  f.st_missing = Mu.stock_target({ turrets = 8, missing = 40, floor = 60 })
  -- 2. cas du DC : QG à 120 chargeurs pour 8 tourelles (140,2 min)
  local hq = { 20, 20, 20, 15, 15, 10, 10, 10 }
  local old_low = 0
  for _, h in ipairs(hq) do if h < T.turret_ammo_low then old_low = old_low + 1 end end
  f.dc_old_low = old_low
  local dg = Mu.group(hq, 20, T.turret_ammo_low)
  f.dc_short, f.dc_missing = dg.short, dg.missing
  local rich = Mu.per_turret({ base = T.turret_ammo_target, rich = T.turret_ammo_rich, turrets = 40, iron = 8059, mag_iron = 4 })
  f.dc_rich = rich
  local rg = Mu.group(hq, rich, T.turret_ammo_low)
  f.dc_rich_short, f.dc_rich_missing = rg.short, rg.missing
  -- 3. planificateur
  local function grp(key, short, missing, low) return { key = key, low = low or 0, has_task = false, n = 4, short = short, missing = missing } end
  local p1 = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [AMMO] = 100 }, turret_groups = { grp("hq", 3, 30) } }), book)
  f.pl_full_refill, f.pl_full_craft = keys_of(p1)["refill:hq"] and 1 or 0, crafted(p1, "munitions")
  local p2 = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [AMMO] = 15 }, turret_groups = { grp("hq", 3, 30) } }), book)
  f.pl_part_refill, f.pl_part_craft = keys_of(p2)["refill:hq"] and 1 or 0, crafted(p2, "munitions")
  local p3 = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [AMMO] = 5 }, turret_groups = { grp("hq", 3, 30) } }), book)
  f.pl_none_refill, f.pl_none_craft = keys_of(p3)["refill:hq"] and 1 or 0, crafted(p3, "munitions")
  local p4 = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [AMMO] = 100 }, turret_groups = { grp("o1", 1, 4) } }), book)
  f.pl_small_refill = keys_of(p4)["refill:o1"] and 1 or 0
  -- vue sans relevé (short absent) : la règle d'avant (seuil bas, tout ou rien)
  local p5 = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [AMMO] = 15 },
    turret_groups = { { key = "hq", low = 2, has_task = false } } }), book)
  f.pl_old_refill, f.pl_old_craft = keys_of(p5)["refill:hq"] and 1 or 0, crafted(p5, "munitions")
  local p6 = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [AMMO] = 100 },
    turret_groups = { { key = "hq", low = 0, has_task = false } } }), book)
  f.pl_old_none = keys_of(p6)["refill:hq"] and 1 or 0
  -- 4. cerveau : but « defense:munitions »
  local function ammo_goal(over) return goal_of(B.generate(fac_s(B, over), TG), "defense:munitions") end
  local b0 = ammo_goal({ ammo_reserve = 158 })
  local b1 = ammo_goal({ ammo_reserve = 158, turrets_n = 40, ammo_missing = 0 })
  local b2 = ammo_goal({ ammo_reserve = 0, turrets_n = 4, ammo_missing = 0 })
  local b3 = ammo_goal({ ammo_reserve = 0, turrets_n = 8, ammo_missing = 280, stock = { [AMMO] = 10, stone = 50 } })
  f.b_old_n = b0 and b0.n or 0
  f.b_turrets_n = b1 and b1.n or 0
  f.b_small_n = b2 and b2.n or 0
  f.b_missing_n = b3 and b3.n or 0
  f.b_min = b1 and b1.minimal_n or -1
  return f
end

local W0 = load_world()
local F0 = facts(W0)

---------------------------------------------------------------------------------------------------
section("1. Règle pure (shared/team/munitions.lua)")
---------------------------------------------------------------------------------------------------
check(F0.pt_base == 20 and F0.pt_rich == 50, "cible par tourelle : 20, ou 50 dès que le fer paie 40 tourelles x 30 chargeurs x 4 fer (4 800 : " ..
  F0.pt_base .. " / " .. F0.pt_rich .. ")")
check(F0.pt_none == 20 and F0.pt_bad == 20, "sans tourelle, ou cible riche sous l'ordinaire : la cible ordinaire")
check(F0.top20 == 15 and F0.top50 == 38, "seuil de recharge au plein : 75 % de la cible (15 sur 20, 38 sur 50)")
check(F0.g_short == 3 and F0.g_missing == 6 + 13 + 20 and F0.g_low == 2,
  "groupe {20,19,15,14,7,0} : 3 à recharger (14, 7, 0), 39 chargeurs pour le plein, 2 sous le seuil bas (" .. F0.g_short .. ", " .. F0.g_missing .. ")")
check(F0.due_small == 0 and F0.due_trip == 1 and F0.due_low == 1 and F0.due_none == 0,
  "tournée : pas pour 6 chargeurs sans tourelle sous le seuil bas ; oui pour 10, ou pour une tourelle sous le seuil bas")
check(F0.take_full == 30 and F0.take_part == 15 and F0.take_none == 0,
  "prise au coffre : tout le manque (30 sur 100), le stock s'il donne 5 par tourelle (15 pour 3), rien en dessous (14)")
check(F0.st_turrets == 400 and F0.st_floor == 60 and F0.st_missing == 120,
  "stock visé : 10 par tourelle plus le manque, au moins le plancher d'avant (400 pour 40 tourelles contre 158 ; 60 pour 4 ; 120)")

---------------------------------------------------------------------------------------------------
section("2. Le cas du DC (QG à 120 chargeurs pour 8 tourelles, 140,2 min ; fer 8 059 à 106 min, 40 tourelles)")
---------------------------------------------------------------------------------------------------
check(F0.dc_old_low == 0, "règle d'avant : aucune tourelle du QG sous 8 chargeurs, aucune recharge (constat du journal)")
check(F0.dc_short == 3 and F0.dc_missing == 30, "règle : les 3 tourelles à 10 chargeurs sont remises à 20 (30 chargeurs)")
check(F0.dc_rich == 50 and F0.dc_rich_short == 8 and F0.dc_rich_missing == 400 - 120,
  "fer 8 059 pour 40 tourelles : cible riche 50, les 8 tourelles du QG rechargées (280 chargeurs : 400 au QG au lieu de 120)")

---------------------------------------------------------------------------------------------------
section("3. Planificateur")
---------------------------------------------------------------------------------------------------
check(F0.pl_full_refill == 1 and F0.pl_full_craft == 0, "stock 100, manque 30 : tournée de recharge, rien à fabriquer")
check(F0.pl_part_refill == 1 and F0.pl_part_craft == 15, "stock 15, manque 30 (3 tourelles) : tournée PARTIELLE et 15 chargeurs fabriqués aussitôt (" ..
  F0.pl_part_craft .. ")")
check(F0.pl_none_refill == 0 and F0.pl_none_craft == 25, "stock 5 pour 3 tourelles : pas de tournée, 25 chargeurs fabriqués (" .. F0.pl_none_craft .. ")")
check(F0.pl_small_refill == 0, "avant-poste à 4 chargeurs du plein, aucune tourelle sous le seuil bas : pas de tournée")
check(F0.pl_old_refill == 0 and F0.pl_old_craft == 25, "vue sans relevé : règle d'avant (tout ou rien : 15 < 40, pas de tournée, 25 fabriqués ; " ..
  F0.pl_old_craft .. ")")
check(F0.pl_old_none == 0, "vue sans relevé, aucune tourelle sous le seuil bas : aucune tournée (règle d'avant)")

---------------------------------------------------------------------------------------------------
section("4. Cerveau : but « defense:munitions »")
---------------------------------------------------------------------------------------------------
check(F0.b_old_n == 158 - 10, "sans relevé des tourelles : max(60, réserve 158) - stock 10 = 148 (règle d'avant ; " .. F0.b_old_n .. ")")
check(F0.b_turrets_n == 400 - 10, "40 tourelles : 400 - 10 = 390 (" .. F0.b_turrets_n .. ")")
check(F0.b_small_n == 60 - 10, "4 tourelles pleines : le plancher de 60 (" .. F0.b_small_n .. ")")
check(F0.b_missing_n == 280 + 80 - 10, "8 tourelles à qui manquent 280 chargeurs : 360 - 10 = 350 (" .. F0.b_missing_n .. ")")
check(F0.b_min == 158 - 10, "la part MINIMALE (payée même quand la production passe d'abord) reste celle d'avant : réserve sur la menace")

---------------------------------------------------------------------------------------------------
section("5. La chaîne dans les sources")
---------------------------------------------------------------------------------------------------
local function has(path, pat) return read_src(path):find(pat, 1, true) ~= nil end
check(has("script/faction/outposts.lua", "Mu.group(g.have, target, T.turret_ammo_low)"), "Outposts.turret_groups lit Mu.group")
check(has("script/faction/outposts.lua", "local target = Outposts.ammo_target(f) -- lot MUNITIONS : au plein"), "Outposts.refill_group remplit à la cible de l'équipe")
check(has("script/team/worker.lua", "local target = Outposts.ammo_target(f)"), "la tournée prend au coffre le manque à la cible de l'équipe")
check(has("script/team/team.lua", "f.team.ammo_per_turret = Mu.per_turret("), "Team.view écrit la cible par tourelle (Mu.per_turret)")
check(has("script/team/team.lua", "short = T.munitions_on and g.short or nil"), "Team.view passe short et missing au planificateur")
check(has("shared/team/planner.lua", "local part = Mu.take(n, g.short, stock)"), "le planificateur prend au coffre par Mu.take")
check(has("shared/ai3/cerveau.lua", "turrets_n = C.turrets_seen(view).n"), "le cerveau relève les tourelles et leur manque")
check(has("shared/ai3/buts.lua", "ammo_target = Mu.stock_target("), "le but « defense:munitions » suit Mu.stock_target")
check(T.munitions_on == true and T.turret_ammo_rich > T.turret_ammo_target, "réglage : règle allumée, cible riche au-dessus de l'ordinaire")

---------------------------------------------------------------------------------------------------
section("6. Mutants")
---------------------------------------------------------------------------------------------------
local SRC = { Mu = read_src("shared/team/munitions.lua"), Pl = read_src("shared/team/planner.lua"), B = read_src("shared/ai3/buts.lua") }
local function mutate(key, from, to)
  local s, n = SRC[key]:gsub(from:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), (to:gsub("%%", "%%%%")), 1)
  assert(n == 1, "mutant introuvable : " .. from)
  return { [key] = s }
end
local MUTANTS = {
  { "seuil au plein = seuil bas (40 %)", mutate("Mu", "Mu.TOP_PCT = 75", "Mu.TOP_PCT = 40") },
  { "prise tout ou rien", mutate("Mu", "if stock >= short * Mu.REFILL_MIN then return stock end", "") },
  { "stock visé sans tourelles", mutate("Mu", "Mu.SPARE = 10", "Mu.SPARE = 0") },
  { "jamais riche", mutate("Mu", "if iron >= Mu.RICH_MARGIN * turrets * (rich - base) * mag_iron then return rich end", "") },
  { "tournée pour 1 chargeur", mutate("Mu", "return num(g.low) > 0 or num(g.missing) >= Mu.TRIP_MIN", "return true") },
  { "manque du groupe = cible entière", mutate("Mu", "out.missing = out.missing + (target - h)", "out.missing = out.missing + target") },
  { "planificateur : reste non fabriqué", mutate("Pl", "if part < n then want({ { ammo, n - part } }, 90, \"munitions\") end", "") },
  { "planificateur : relevé ignoré", mutate("Pl", "if g.short ~= nil then", "if false then") },
  { "buts : stock visé d'avant", mutate("B", "if T.munitions_on and s.turrets_n then", "if false then") },
}
local killed = 0
for _, m in ipairs(MUTANTS) do
  local ok, Fm = pcall(function() return facts(load_world(m[2])) end)
  local diff = not ok
  local which = ok and nil or "erreur"
  if ok then
    for _, k in ipairs((function() local ks = {} for k in pairs(F0) do ks[#ks + 1] = k end table.sort(ks) return ks end)()) do
      if Fm[k] ~= F0[k] then diff, which = true, k break end
    end
  end
  if diff then killed = killed + 1 end
  check(diff, "mutant « " .. m[1] .. " » vu" .. (which and (" (" .. which .. ")") or ""))
end
print(string.format("[MUNITIONS] mutants : %d/%d vus", killed, #MUTANTS))

print(string.format("[MUNITIONS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
