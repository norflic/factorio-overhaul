--[[
  Lot MUNITIONS (retour du DC du 3/11, partie 0.6.46 : « ils ont sous-produit des balles, donc les tourelles n'étaient pas chargées complètement
  [...] ils ont pas rempli à fond les munitions ») : banc HORS JEU. Lancement : lua5.2 tests/munitions_test.lua (racine du mod).

    1. la règle pure (shared/team/munitions.lua) : cible par tourelle (ordinaire, riche, hystérésis), seuil de recharge au plein, groupe et
       part urgente, tournée due, prise partielle, stock visé au coffre (plafond), meilleure munition fabricable ;
    2. le CAS du DC (fo-logs/2026-11-03_RETOUR3) : QG à 120 chargeurs pour 8 tourelles à 140,2 min, 40 tourelles et 158 chargeurs visés à
       117 min, 8 000 à 11 000 plaques de fer au coffre ;
    3. le planificateur : recharge au plein, partielle, part urgente avant les recrues, surplus riche après, munition choisie ; vue sans
       relevé : règle d'avant à l'identique ;
    4. le cerveau : le but « defense:munitions » suit la part urgente des tourelles, plafonné, et vise la munition choisie ;
    5. la CHAÎNE lue dans les sources (outposts, team, worker, planner, cerveau, buts) ;
    6. mutants : chaque règle cassée change au moins un fait observé.
  Essai 2 du lot (après verif-guide 271828182 : 988 chargeurs au coffre, 14 PNJ contre 23) : hystérésis de la cible riche, stock visé compté
  sur la cible ordinaire avec un plafond, surplus riche servi APRÈS les recrues, meilleure munition fabricable (balles perforantes), ÉCHANGE des
  tourelles pleines d'une munition moins bonne (banc munitions-perforantes, 1er passage : perforantes fabriquées, jamais portées).
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
local PIERCING = T.turret_ammo_ladder[2]

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
local function crafted_item(p, item, tag)
  local n = 0
  for _, t in ipairs(p.tasks) do if t.kind == "craft" and t.item == item and t.tag == tag then n = n + t.count end end
  return n
end
local function crafted(p, tag) return crafted_item(p, AMMO, tag) end
local function task_of(p, key) for _, t in ipairs(p.tasks) do if t.key == key then return t end end end
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
  -- 1. règle pure. Cible riche : 40 tourelles x 30 chargeurs x 4 fer = 4 800 ; entrée à 200 % (9 600), sortie sous 100 % (4 800).
  local function pt(iron, was, turrets, rich)
    local v = Mu.per_turret({ base = 20, rich = rich or 50, turrets = turrets or 40, iron = iron, mag_iron = 4, was = was })
    return v
  end
  f.pt_below, f.pt_enter, f.pt_band = pt(9599, false), pt(9600, false), pt(6000, false)
  f.pt_stay, f.pt_exit = pt(4800, true), pt(4799, true)
  f.pt_none, f.pt_bad = pt(99999, false, 0), pt(99999, false, 5, 10)
  local _, rich_flag = Mu.per_turret({ base = 20, rich = 50, turrets = 40, iron = 9600, mag_iron = 4 })
  f.pt_flag = rich_flag and 1 or 0
  f.top20, f.top50 = Mu.top(20), Mu.top(50)
  local g = Mu.group({ 20, 19, 15, 14, 7, 0 }, 20, 8)
  f.g_short, f.g_missing, f.g_low = g.short, g.missing, g.low
  local gr = Mu.group({ 50, 40, 30, 19, 0 }, 50, 8, 20)
  f.gr_short, f.gr_missing, f.gr_mb, f.gr_sb, f.gr_low = gr.short, gr.missing, gr.missing_base, gr.short_base, gr.low
  -- échange : 4 tourelles {20 base, 20 perforantes, 10 base, 0 vide}, meilleure = perforante (rang 2), cible 20
  local gw = Mu.group({ 20, 20, 10, 0 }, 20, 8, 20, { 1, 2, 1, 0 }, 2)
  f.gw_worse, f.gw_need, f.gw_short = gw.worse, gw.worse_need, gw.short
  f.up_full, f.up_part, f.up_none = Mu.upgrade_take(80, 200), Mu.upgrade_take(80, 25), Mu.upgrade_take(80, 19)
  f.due_small = Mu.due({ short = 1, missing = 6, low = 0 }) and 1 or 0
  f.due_trip = Mu.due({ short = 2, missing = 10, low = 0 }) and 1 or 0
  f.due_low = Mu.due({ short = 1, missing = 6, low = 1 }) and 1 or 0
  f.due_none = Mu.due({ short = 0, missing = 0, low = 0 }) and 1 or 0
  f.take_full = Mu.take(30, 3, 100)
  f.take_part = Mu.take(30, 3, 15)
  f.take_none = Mu.take(30, 3, 14)
  -- revue M1 : 3 vides + 5 à 14 sur 20 (8 sous la cible, 3 sous le seuil bas), 15 au coffre : la tournée part (avant : il en fallait 40)
  f.m1_take = Mu.take(90, 8, 15, 3)
  f.m1_take_nolow = Mu.take(90, 8, 15, 0)
  local fp = Mu.fill_plan({ 14, 0, 14, 0, 0, 14, 14, 14 }, { 5, 8, 20, 20 }, 15)
  f.m1_fill_empties = (fp[2] == 5 and fp[4] == 5 and fp[5] == 5 and fp[1] == 0 and fp[3] == 0 and fp[6] == 0) and 1 or 0
  local fp2 = Mu.fill_plan({ 14, 0, 14, 0, 0, 14, 14, 14 }, { 5, 8, 20, 20 }, 100)
  local tot2 = 0
  for _, x in ipairs(fp2) do tot2 = tot2 + x end
  local fp3 = Mu.fill_plan({ 3, 0 }, { 5 }, 4)
  f.m1_fill_low_first = (fp3[1] == 0 and fp3[2] == 4) and 1 or 0
  f.m1_fill_full = (fp2[2] == 20 and fp2[4] == 20 and fp2[5] == 20 and fp2[1] == 6 and tot2 == 90) and 1 or 0
  -- revue M2 : jamais de baisse à l'échange
  f.m2_over = Mu.swap_take(100, 20, 200, 20)
  f.m2_full = Mu.swap_take(20, 20, 20, 20)
  f.m2_short = Mu.swap_take(20, 20, 19, 20)
  f.m2_low = Mu.swap_take(10, 20, 20, 20)
  f.m2_rich = Mu.swap_take(30, 50, 40, 20)
  -- revue M3 : la base seulement pour le reste
  local c1, b1 = Mu.split_take(30, 10, false)
  local c2, b2 = Mu.split_take(30, 50, false)
  local c3, b3 = Mu.split_take(30, 0, true)
  f.m3 = string.format("%d/%d %d/%d %d/%d", c1, b1, c2, b2, c3, b3)
  f.st_turrets = Mu.stock_target({ turrets = 40, missing = 0, base = 20, floor = 158 })
  f.st_floor = Mu.stock_target({ turrets = 4, missing = 0, base = 20, floor = 60 })
  f.st_missing = Mu.stock_target({ turrets = 8, missing = 40, base = 20, floor = 60 })
  f.st_cap = Mu.stock_target({ turrets = 29, missing = 780, base = 20, floor = 60 })
  f.st_nobase = Mu.stock_target({ turrets = 29, missing = 780, floor = 60 })
  -- meilleure munition : { base, perforante, uranium }
  local function ba(p2, p3, cur)
    local i = Mu.best_ammo({ { enabled = true, makeable = true, stock = 0 }, p2, p3 or { enabled = false } }, cur)
    return i
  end
  f.ba_make = ba({ enabled = true, makeable = true, stock = 0 })
  f.ba_cannot = ba({ enabled = true, makeable = false, stock = 0 })
  f.ba_closed = ba({ enabled = false, makeable = false, stock = 50 })
  f.ba_stock = ba({ enabled = true, makeable = false, stock = 10 })
  f.ba_keep = ba({ enabled = true, makeable = false, stock = 3 }, nil, 2)
  f.ba_nokeep = ba({ enabled = true, makeable = false, stock = 3 }, nil, 1)
  f.ba_top = ba({ enabled = true, makeable = true, stock = 0 }, { enabled = true, makeable = true, stock = 0 })
  -- essai 3 : choix STABLE (Mu.stable_ammo). H = Mu.AMMO_HOLD ; une pensée toutes les 600 ticks.
  local H = Mu.AMMO_HOLD
  local function L(p2) return { { enabled = true, makeable = true, stock = 0 }, p2, { enabled = false } } end
  local OK2, NO2 = { enabled = true, makeable = true, stock = 0 }, { enabled = true, makeable = false, stock = 0 }
  local s1, i1 = Mu.stable_ammo(nil, L(OK2), 1000)
  local s2, i2 = Mu.stable_ammo(s1, L(OK2), 1000 + H - 1)
  local s3, i3 = Mu.stable_ammo(s2, L(OK2), 1000 + H)
  f.st_wait, f.st_before, f.st_after = i1, i2, i3
  -- éligibilité interrompue : l'attente repart de zéro
  local u1 = Mu.stable_ammo(nil, L(OK2), 0)
  local u2 = Mu.stable_ammo(u1, L(NO2), 600)
  local u3, j3 = Mu.stable_ammo(u2, L(OK2), 1200)
  local _, j4 = Mu.stable_ammo(u3, L(OK2), 1200 + H - 1)
  f.st_reset = (j3 == 1 and j4 == 1) and 1 or 0
  -- la courante (perforante) inutilisable : gardée H ticks, puis la base
  local d1, k1 = Mu.stable_ammo({ cur = 2 }, L(NO2), 5000)
  local _, k2 = Mu.stable_ammo(d1, L(NO2), 5000 + H - 1)
  local _, k3 = Mu.stable_ammo(d1, L(NO2), 5000 + H)
  f.st_keep, f.st_keep2, f.st_down = k1, k2, k3
  local _, k4 = Mu.stable_ammo({ cur = 2, bad_since = 0 }, L({ enabled = true, makeable = false, stock = 3 }), 10 * H)
  f.st_stock_keeps = k4
  local _, k5 = Mu.stable_ammo({ cur = 2 }, L({ enabled = false, makeable = false, stock = 50 }), 5000)
  f.st_closed = k5
  -- 60 pensées où l'acier va et vient (fabricable une pensée sur deux) : le choix ne bascule jamais ; l'ancienne règle bascule à chaque pensée
  local st, prev, flips, flips_old, prev_old = nil, 1, 0, 0, 1
  for n = 1, 60 do
    local lst = L((n % 2 == 0) and OK2 or NO2)
    local idx
    st, idx = Mu.stable_ammo(st, lst, n * 600)
    if idx ~= prev then flips = flips + 1 end
    prev = idx
    local io_ = Mu.best_ammo(lst, prev_old)
    if io_ ~= prev_old then flips_old = flips_old + 1 end
    prev_old = io_
  end
  f.st_flips, f.st_flips_old = flips, flips_old
  -- 2. cas du DC : QG à 120 chargeurs pour 8 tourelles (140,2 min)
  local hq = { 20, 20, 20, 15, 15, 10, 10, 10 }
  local old_low = 0
  for _, h in ipairs(hq) do if h < T.turret_ammo_low then old_low = old_low + 1 end end
  f.dc_old_low = old_low
  local dg = Mu.group(hq, 20, T.turret_ammo_low)
  f.dc_short, f.dc_missing = dg.short, dg.missing
  local rich = Mu.per_turret({ base = T.turret_ammo_target, rich = T.turret_ammo_rich, turrets = 40, iron = 11418, mag_iron = 4 })
  f.dc_rich = rich
  f.dc_rich_106 = Mu.per_turret({ base = T.turret_ammo_target, rich = T.turret_ammo_rich, turrets = 40, iron = 8059, mag_iron = 4 })
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
  -- surplus de la cible riche APRÈS les recrues : fer 100, recrue voulue (pistolet 5 fer + 10 chargeurs 40 fer + 18 fer), 120 de surplus
  local function grs(key, missing, mb, short, sb) return { key = key, low = 0, has_task = false, n = 4, short = short, missing = missing,
    missing_base = mb, short_base = sb } end
  -- (fer 100 : la recrue prend 63, l'objectif 32 ; un surplus de 12 chargeurs (48 fer) ne passe qu'APRÈS : il n'en reste que 5)
  local p7 = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200 }, turret_groups = { grs("hq", 12, 0, 1, 0) } }), book)
  f.sp_pistol = crafted_item(p7, "pistol", "ouvrier")
  f.sp_surplus = crafted(p7, "munitions-surplus")
  f.sp_urgent = crafted(p7, "munitions")
  -- fer 300 : il en reste après la recrue, l'objectif et la réserve : le surplus de 12 est fabriqué, à sa priorité basse
  local p7b = Pl.plan(view({ stock = { [IRON] = 300, [COPPER] = 200 }, turret_groups = { grs("hq", 12, 0, 1, 0) } }), book)
  f.sp_rich = crafted(p7b, "munitions-surplus")
  f.sp_rich_pistol = crafted_item(p7b, "pistol", "ouvrier")
  -- surplus servi par le stock qui reste après la recrue : 200 chargeurs, la recrue en prend 10, la tournée porte les 120
  local p8 = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [AMMO] = 200 }, turret_groups = { grs("hq", 120, 0, 4, 0) } }), book)
  local t8 = task_of(p8, "refill:hq")
  f.sp_count = t8 and t8.count or 0
  -- part urgente ET surplus : la tournée part avec l'urgent (30) puis reçoit le surplus (90) qui reste au coffre
  local p9 = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [AMMO] = 200 }, turret_groups = { grs("hq", 120, 30, 4, 2) } }), book)
  local t9 = task_of(p9, "refill:hq")
  f.sp_both = t9 and t9.count or 0
  -- munition choisie : balles perforantes, acier au coffre : elles sont fabriquées pour la recharge
  local p10 = Pl.plan(view({ stock = { [IRON] = 500, [COPPER] = 500, ["steel-plate"] = 50 }, turret_ammo = PIERCING,
    turret_groups = { grs("hq", 30, 30, 2, 2) } }), book)
  f.pl_piercing = crafted_item(p10, PIERCING, "munitions")
  -- revue M1 au planificateur : QG à 3 vides + 5 à 14, 15 chargeurs au coffre : tournée de 15
  local pm1 = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [AMMO] = 15 }, turret_groups = { { key = "hq", low = 3, has_task = false,
    n = 8, short = 8, missing = 90, missing_base = 90, short_base = 8 } } }), book)
  local tm1 = task_of(pm1, "refill:hq")
  f.m1_planner = tm1 and tm1.count or 0
  -- échange : 3 tourelles pleines de chargeurs de base, 58 perforantes au coffre : une tournée de 58 ; 10 au coffre : aucune
  local function grw(key, worse, need) return { key = key, low = 0, has_task = false, n = 3, short = 0, missing = 0, missing_base = 0,
    short_base = 0, worse = worse, worse_need = need } end
  local p11 = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [PIERCING] = 58 }, turret_ammo = PIERCING,
    turret_groups = { grw("hq", 3, 60) } }), book)
  local t11 = task_of(p11, "refill:hq")
  f.up_task = t11 and t11.count or 0
  f.up_craft = crafted_item(p11, PIERCING, "munitions") + crafted_item(p11, PIERCING, "munitions-surplus")
  local p12 = Pl.plan(view({ stock = { [IRON] = 100, [COPPER] = 200, [PIERCING] = 10 }, turret_ammo = PIERCING,
    turret_groups = { grw("hq", 3, 60) } }), book)
  f.up_small = keys_of(p12)["refill:hq"] and 1 or 0
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
  local b4 = ammo_goal({ ammo_reserve = 0, turrets_n = 8, ammo_missing = 0, turret_ammo = PIERCING })
  f.b_old_n = b0 and b0.n or 0
  f.b_turrets_n = b1 and b1.n or 0
  f.b_small_n = b2 and b2.n or 0
  f.b_missing_n = b3 and b3.n or 0
  f.b_min = b1 and b1.minimal_n or -1
  f.b_item = b4 and b4.item or "aucun"
  return f
end

local W0 = load_world()
local F0 = facts(W0)

---------------------------------------------------------------------------------------------------
section("1. Règle pure (shared/team/munitions.lua)")
---------------------------------------------------------------------------------------------------
check(F0.pt_below == 20 and F0.pt_enter == 50 and F0.pt_band == 20 and F0.pt_flag == 1,
  "cible riche : entrée quand le fer paie 2 fois le surplus de 40 tourelles (9 600 : 50 ; 9 599 ou 6 000 sans être riche : 20)")
check(F0.pt_stay == 50 and F0.pt_exit == 20, "hystérésis : riche, elle le reste jusqu'à 4 800 de fer (1 fois le surplus), puis 20 sous ce seuil")
check(F0.pt_none == 20 and F0.pt_bad == 20, "sans tourelle, ou cible riche sous l'ordinaire : la cible ordinaire")
check(F0.top20 == 15 and F0.top50 == 38, "seuil de recharge au plein : 75 % de la cible (15 sur 20, 38 sur 50)")
check(F0.g_short == 3 and F0.g_missing == 6 + 13 + 20 and F0.g_low == 2,
  "groupe {20,19,15,14,7,0} : 3 à recharger (14, 7, 0), 39 chargeurs pour le plein, 2 sous le seuil bas (" .. F0.g_short .. ", " .. F0.g_missing .. ")")
check(F0.gr_short == 3 and F0.gr_missing == 101 and F0.gr_mb == 21 and F0.gr_sb == 2 and F0.gr_low == 1,
  "groupe {50,40,30,19,0} à 50 : 3 à recharger, 101 chargeurs, dont 21 URGENTS (jusqu'à 20 : 1 + 20) pour 2 tourelles (" .. F0.gr_mb .. ")")
check(F0.gw_worse == 1 and F0.gw_need == 20 and F0.gw_short == 2,
  "échange : la tourelle pleine de chargeurs de base est à échanger (20), celle à 10 et la vide sont à recharger, la perforante non")
check(F0.up_full == 80 and F0.up_part == 25 and F0.up_none == 0, "échange : avec le stock seulement, au moins 20 (80 sur 200, 25, rien pour 19)")
check(F0.due_small == 0 and F0.due_trip == 1 and F0.due_low == 1 and F0.due_none == 0,
  "tournée : pas pour 6 chargeurs sans tourelle sous le seuil bas ; oui pour 10, ou pour une tourelle sous le seuil bas")
check(F0.take_full == 30 and F0.take_part == 15 and F0.take_none == 0,
  "prise au coffre : tout le manque (30 sur 100), le stock s'il donne 5 par tourelle (15 pour 3), rien en dessous (14)")
check(F0.st_turrets == 400 and F0.st_floor == 60 and F0.st_missing == 120,
  "stock visé : 10 par tourelle plus le manque urgent, au moins le plancher d'avant (400 pour 40 tourelles contre 158 ; 60 pour 4 ; 120)")
check(F0.m1_take == 15 and F0.m1_take_nolow == 0,
  "revue M1 : 3 vides + 5 à 14, 15 au coffre : la tournée part avec 15 (sans compter les vides : il en fallait 40)")
check(F0.m1_fill_low_first == 1, "revue M1 : 4 chargeurs pour {3, 0} : tous à la vide (la moins chargée d'abord)")
check(F0.m1_fill_empties == 1, "revue M1 : 15 chargeurs portés : 5 à chacune des 3 vides d'abord, rien aux tourelles à 14")
check(F0.m1_fill_full == 1, "revue M1 : 100 portés : les vides à 20, puis les tourelles à 14 à 20 (90 posés)")
check(F0.m2_over == 0 and F0.m2_full == 20 and F0.m2_short == 0 and F0.m2_low == 20 and F0.m2_rich == 30,
  "revue M2 : échange jamais en baisse (100 au-delà de la cible : pas d'échange ; 20 contre 19 portés : non ; 30 sur cible 50 : 30 remis)")
check(F0.m3 == "10/20 30/0 30/0", "revue M3 : la base seulement pour le reste (" .. F0.m3 .. ")")
check(F0.st_cap == 580 and F0.st_nobase == 1070, "plafond : une charge ordinaire par tourelle (29 tourelles : 580, et non 1 070 comme à l'essai 1)")
check(F0.ba_make == 2 and F0.ba_cannot == 1 and F0.ba_closed == 1 and F0.ba_stock == 2,
  "munition : perforante si sa recette est ouverte et qu'elle se fabrique, ou 10 au coffre ; sinon la base (recette fermée : base même avec 50)")
check(F0.st_wait == 1 and F0.st_before == 1 and F0.st_after == 2,
  "choix stable : la perforante n'est prise qu'après 5 min d'éligibilité continue (1, 1 à H - 1, 2 à H)")
check(F0.st_reset == 1, "choix stable : une interruption de l'éligibilité fait repartir l'attente")
check(F0.st_keep == 2 and F0.st_keep2 == 2 and F0.st_down == 1, "choix stable : la courante inutilisable est gardée 5 min, puis la base")
check(F0.st_stock_keeps == 2 and F0.st_closed == 1, "choix stable : gardée tant qu'il en reste au coffre ; recette fermée : la base aussitôt")
check(F0.st_flips == 0 and F0.st_flips_old >= 50,
  "acier qui va et vient une pensée sur deux pendant 60 pensées : 0 bascule (ancienne règle : " .. F0.st_flips_old .. ")")
check(F0.ba_keep == 2 and F0.ba_nokeep == 1 and F0.ba_top == 3,
  "munition collante : gardée avec 3 au coffre si elle était choisie, pas prise pour 3 ; la meilleure fabricable d'abord (uranium)")

---------------------------------------------------------------------------------------------------
section("2. Le cas du DC (QG à 120 chargeurs pour 8 tourelles, 140,2 min ; fer 8 059 à 106 min, 11 418 à 116 min, 40 tourelles)")
---------------------------------------------------------------------------------------------------
check(F0.dc_old_low == 0, "règle d'avant : aucune tourelle du QG sous 8 chargeurs, aucune recharge (constat du journal)")
check(F0.dc_short == 3 and F0.dc_missing == 30, "règle : les 3 tourelles à 10 chargeurs sont remises à 20 (30 chargeurs)")
check(F0.dc_rich == 50 and F0.dc_rich_short == 8 and F0.dc_rich_missing == 400 - 120,
  "fer 11 418 pour 40 tourelles (116 min) : cible riche 50, les 8 tourelles du QG rechargées (280 chargeurs : 400 au QG au lieu de 120)")
check(F0.dc_rich_106 == 20, "fer 8 059 (106 min) : sous les 9 600 de l'entrée, cible ordinaire")

---------------------------------------------------------------------------------------------------
section("3. Planificateur")
---------------------------------------------------------------------------------------------------
check(F0.pl_full_refill == 1 and F0.pl_full_craft == 0, "stock 100, manque 30 : tournée de recharge, rien à fabriquer")
check(F0.pl_part_refill == 1 and F0.pl_part_craft == 15, "stock 15, manque 30 (3 tourelles) : tournée PARTIELLE et 15 chargeurs fabriqués aussitôt (" ..
  F0.pl_part_craft .. ")")
check(F0.pl_none_refill == 0 and F0.pl_none_craft == 25, "stock 5 pour 3 tourelles : pas de tournée, 25 chargeurs fabriqués (" .. F0.pl_none_craft .. ")")
check(F0.pl_small_refill == 0, "avant-poste à 4 chargeurs du plein, aucune tourelle sous le seuil bas : pas de tournée")
check(F0.sp_pistol > 0 and F0.sp_urgent == 0 and F0.sp_surplus == 0,
  "surplus riche APRÈS la recrue : fer 100, l'équipement de la recrue est fabriqué, pas les 12 chargeurs du surplus (" .. F0.sp_surplus .. ")")
check(F0.sp_rich == 12 and F0.sp_rich_pistol > 0, "fer 300 : la recrue ET les 12 chargeurs du surplus (" .. F0.sp_rich .. ")")
check(F0.sp_count == 120, "surplus servi par le stock qui reste après la recrue : tournée de 120 chargeurs (" .. F0.sp_count .. ")")
check(F0.sp_both == 120, "part urgente (30) puis surplus (90) : une seule tournée de 120 (" .. F0.sp_both .. ")")
check(F0.pl_piercing == 30, "munition choisie perforante, acier au coffre : 30 balles perforantes fabriquées pour la recharge (" .. F0.pl_piercing .. ")")
check(F0.up_task == 58 and F0.up_craft == 0, "échange : 58 perforantes au coffre, une tournée de 58, rien fabriqué pour l'échange (" ..
  F0.up_task .. ")")
check(F0.up_small == 0, "échange : 10 perforantes au coffre, pas de tournée (moins d'une charge ordinaire)")
check(F0.m1_planner == 15, "revue M1 au planificateur : tournée de 15 pour les 3 tourelles vides du QG (" .. F0.m1_planner .. ")")
check(F0.pl_old_refill == 0 and F0.pl_old_craft == 25, "vue sans relevé : règle d'avant (tout ou rien : 15 < 40, pas de tournée, 25 fabriqués ; " ..
  F0.pl_old_craft .. ")")
check(F0.pl_old_none == 0, "vue sans relevé, aucune tourelle sous le seuil bas : aucune tournée (règle d'avant)")

---------------------------------------------------------------------------------------------------
section("4. Cerveau : but « defense:munitions »")
---------------------------------------------------------------------------------------------------
check(F0.b_old_n == 158 - 10, "sans relevé des tourelles : max(60, réserve 158) - stock 10 = 148 (règle d'avant ; " .. F0.b_old_n .. ")")
check(F0.b_turrets_n == 400 - 10, "40 tourelles : 400 - 10 = 390 (" .. F0.b_turrets_n .. ")")
check(F0.b_small_n == 60 - 10, "4 tourelles pleines : le plancher de 60 (" .. F0.b_small_n .. ")")
check(F0.b_missing_n == 160 - 10, "8 tourelles à qui manquent 280 chargeurs urgents : plafond 160 (une charge ordinaire), 160 - 10 = 150 (" ..
  F0.b_missing_n .. ")")
check(F0.b_min == 158 - 10, "la part MINIMALE (payée même quand la production passe d'abord) reste celle d'avant : réserve sur la menace")
check(F0.b_item == PIERCING, "munition choisie perforante : le but « defense:munitions » la vise (" .. tostring(F0.b_item) .. ")")

---------------------------------------------------------------------------------------------------
section("5. La chaîne dans les sources")
---------------------------------------------------------------------------------------------------
local function has(path, pat) return read_src(path):find(pat, 1, true) ~= nil end
check(has("script/faction/outposts.lua", "Mu.group(g.have, target, T.turret_ammo_low, T.turret_ammo_target, g.ranks, best)"),
  "Outposts.turret_groups lit Mu.group (part urgente)")
check(has("script/faction/outposts.lua", "local fill = math.min(T.turret_ammo_target, target)"),
  "Outposts.refill_group : paliers jusqu'à la cible ordinaire, puis le plein")
check(has("script/faction/outposts.lua", "for _, t in ipairs(list) do put = put + swap_for_best(t, carrier, target, fill) end"),
  "Outposts.refill_group échange une munition moins bonne")
check(has("script/faction/outposts.lua", "local v = T.munitions_on and f and f.team and f.team.ammo_item or nil"),
  "Outposts.ammo_name rend la munition choisie")
check(has("script/team/worker.lua", "local ammo = Outposts.ammo_name(f.tech, f)"), "la tournée porte la munition choisie")
check(has("script/team/worker.lua", 'if type(task.count) == "number" and task.count > 0 and task.count < need then need = task.count end'),
  "la tournée porte au plus ce que le planificateur lui a donné")
check(has("script/faction/outposts.lua", "local m = Mu.group(g.have, target, T.turret_ammo_low, T.turret_ammo_target, g.ranks, best)"),
  "Outposts.turret_groups relève les tourelles à échanger")
check(has("script/team/worker.lua", "if r > 0 and r < best then need = need + target"), "la tournée d'échange porte la cible entière")
check(has("shared/team/planner.lua", "local got = Mu.upgrade_take(g.worse_need, stock)"), "le planificateur lance l'échange (Mu.upgrade_take)")
check(has("script/team/team.lua", "f.team.ammo_state, idx, why = Mu.stable_ammo(f.team.ammo_state, cands, tick)"),
  "Team.view choisit la munition de façon stable (Mu.stable_ammo)")
check(has("script/team/team.lua", "rich = T.turret_ammo_rich_on and T.turret_ammo_rich or T.turret_ammo_target") and T.turret_ammo_rich_on == false,
  "essai 3 : cible riche éteinte (T.turret_ammo_rich_on)")
check(has("shared/team/planner.lua", "want({ { base_ammo, nb - part } }, 90, \"munitions\")"),
  "part urgente en munition de base quand la munition choisie ne se fabrique plus")
check(has("script/team/team.lua", "local choose = f.is_player or T.best_ammo_factions") and T.best_ammo_factions == false,
  "meilleure munition pour votre équipe seulement (une faction garde la munition de base)")
check(has("script/team/team.lua", "was = f.team.ammo_rich == true"), "Team.view garde l'état riche d'une pensée à l'autre (hystérésis)")
check(has("script/team/team.lua", "f.team.ammo_per_turret, f.team.ammo_rich = Mu.per_turret("), "Team.view écrit la cible par tourelle")
check(has("script/team/team.lua", "short = T.munitions_on and g.short or nil"), "Team.view passe short et missing au planificateur")
check(has("script/team/team.lua", "turret_ammo = T.munitions_on and Outposts.ammo_name(f.tech, f) or nil"), "Team.view passe la munition choisie")
check(has("shared/team/planner.lua", "local part = Mu.take(nb, math.max(1, g.short_base or g.short), stock, g.low)"), "revue M1 : le planificateur passe les vides")
check(has("script/faction/outposts.lua", "local plan = T.munitions_on and Mu.fill_plan(have, { Mu.REFILL_MIN, T.turret_ammo_low, fill, target }, carried) or nil"),
  "revue M1 : la tournée remplit la moins chargée d'abord (Mu.fill_plan)")
check(has("script/faction/outposts.lua", "local put = Mu.swap_take(n, target, carrier.get_item_count(best), fill)"), "revue M2 : échange par Mu.swap_take")
check(has("script/team/worker.lua", "local take_c, take_b = Mu.split_take(need, Stock.count(f, ammo), ammo == T.turret_ammo)"), "revue M3 : prise bornée")
check(has("shared/ai3/cerveau.lua", "missing + (g.missing_base or g.missing)"), "le stock visé ne compte que la part urgente")
check(has("shared/ai3/cerveau.lua", "turrets_n = C.turrets_seen(view).n"), "le cerveau relève les tourelles et leur manque")
check(has("shared/ai3/buts.lua", "ammo_target = Mu.stock_target("), "le but « defense:munitions » suit Mu.stock_target")
check(T.munitions_on == true and T.turret_ammo_rich > T.turret_ammo_target, "réglage : règle allumée, cible riche (éteinte) au-dessus de l'ordinaire")
check(T.turret_ammo_ladder[1] == T.turret_ammo and #T.turret_ammo_ladder >= 2, "échelle des munitions : la base d'abord, au moins une meilleure")

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
  { "prise tout ou rien", mutate("Mu", "if stock >= need_n * Mu.REFILL_MIN then return stock end", "") },
  { "stock visé sans tourelles", mutate("Mu", "Mu.SPARE = 10", "Mu.SPARE = 0") },
  { "jamais riche", mutate("Mu", "if iron * 100 >= cost * pct then return rich, true end", "") },
  { "sans hystérésis", mutate("Mu", "local pct = a.was and Mu.RICH_EXIT_PCT or Mu.RICH_ENTER_PCT", "local pct = Mu.RICH_ENTER_PCT") },
  { "sans plafond du stock", mutate("Mu", "if a.base ~= nil and t > cap then t = cap end", "") },
  { "tournée pour 1 chargeur", mutate("Mu", "return num(g.low) > 0 or num(g.missing) >= Mu.TRIP_MIN", "return true") },
  { "manque du groupe = cible entière", mutate("Mu", "out.missing = out.missing + (target - h)", "out.missing = out.missing + target") },
  { "groupe : pas de part urgente", mutate("Mu", "out.missing_base = out.missing_base + (base - h)", "out.missing_base = out.missing_base + (target - h)") },
  { "munition : toujours la base", mutate("Mu", 'if c.makeable then return i, "fabricable" end', "") },
  { "munition : pas collante", mutate("Mu", 'if i == current and num(c.stock) > 0 then return i, "gardee (au coffre)" end', "") },
  { "munition : recette fermée acceptée", mutate("Mu", "    if c.enabled then\n", "    if true then\n") },
  { "planificateur : reste non fabriqué", mutate("Pl", 'if part < nb and not want({ { ammo, nb - part } }, 90, "munitions") and ammo ~= base_ammo then', "if false then") },
  { "choix : sans attente", mutate("Mu", "Mu.AMMO_HOLD = 5 * 3600", "Mu.AMMO_HOLD = 0") },
  { "M1 : vides ignorées", mutate("Mu", "local need_n = low > 0 and low or short", "local need_n = short") },
  { "M1 : remplissage dans l'ordre", mutate("Mu", "if cur[a] ~= cur[b] then return cur[a] < cur[b] end", "") },
  { "M2 : échange en baisse", mutate("Mu", "if put <= 0 or carried < put or put < n then return 0 end", "if put <= 0 or carried < put then return 0 end") },
  { "M3 : base en double", mutate("Mu", "  return c, need - c", "  return c, need") },
  { "choix : quitte aussitôt", mutate("Mu", "if tick - out.bad_since >= Mu.AMMO_HOLD then", "if true then") },
  { "choix : l'attente ne repart pas", mutate("Mu", "  out.cand, out.cand_since = nil, nil\n  return out, out.cur, out.cur > 1", "  return out, out.cur, out.cur > 1") },
  { "planificateur : relevé ignoré", mutate("Pl", "if g.short ~= nil then", "if false then") },
  { "planificateur : surplus urgent", mutate("Pl", "local nb = math.min(n, g.missing_base or n)", "local nb = n") },
  { "planificateur : surplus oublié", mutate("Pl", "if n > nb then surplus[#surplus + 1] = { g = g, n = n - nb, task = task } end", "") },
  { "planificateur : munition de base", mutate("Pl", "local ammo = view.turret_ammo or base_ammo", "local ammo = base_ammo") },
  { "buts : stock visé d'avant", mutate("B", "if T.munitions_on and s.turrets_n then", "if false then") },
  { "buts : munition de base", mutate("B", "local ammo = s.turret_ammo or T.turret_ammo", "local ammo = T.turret_ammo") },
  { "échange : jamais", mutate("Mu", "if h >= top and r > 0 and r < best then", "if false then") },
  { "échange : sans minimum", mutate("Mu", "if n < Mu.UPGRADE_MIN then return 0 end", "") },
  { "planificateur : pas d'échange", mutate("Pl", "local got = Mu.upgrade_take(g.worse_need, stock)", "local got = 0") },
}
local killed = 0
for _, m in ipairs(MUTANTS) do
  local ok, Fm = pcall(function() return facts(load_world(m[2])) end)
  local diff = not ok
  local which = (not ok) and "erreur" or nil
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
