--[[
  Lot S1 SURVIE, suite (décision du 1/11 : « protéger d'abord ») : banc HORS JEU. Lancement : lua5.2 tests/s1_protege_test.lua (racine du mod).
    1. règles pures (shared/team/survie_qg.lua) : avant-poste à protéger, plus grosse vague reçue, réserve de chargeurs sur la menace ;
    2. planificateur : un avant-poste que des vagues touchent et sans tourelles n'est ni agrandi ni travaillé au fond, même en mode survie ; la
       défense passe d'abord ; sans tourelle posable, rien ne change ;
    3. cerveau : réserve de chargeurs sur la menace (payée même quand la production passe d'abord), recherche de la tourelle servie d'abord et
       sans plancher de fer, ses packs dans le besoin ;
    4. la chaîne lue dans les sources ; 5. mutants.
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
local NAMES = { "shared.team.survie_qg", "shared.team.priorite", "shared.team.planner", "shared.ai3.buts", "shared.ai3.projets", "shared.ai3.cerveau",
  "shared.ai3.reserve" }
local KEYMAP = { Sq = NAMES[1], Pr = NAMES[2], Pl = NAMES[3], B = NAMES[4], P = NAMES[5], C = NAMES[6], Rs = NAMES[7] }
local ORDER = { "Sq", "Pr", "Rs", "Pl", "B", "P", "C" }
local function load_world(over)
  over = over or {}
  local saved = {}
  for _, n in ipairs(NAMES) do saved[n] = package.loaded[n]; package.loaded[n] = nil end
  local W = {}
  for _, key in ipairs(ORDER) do
    local name = KEYMAP[key]
    if over[key] then package.loaded[name] = assert(load(over[key], "@" .. name))()
    else package.loaded[name] = nil; package.loaded[name] = require(name) end
    W[key] = package.loaded[name]
  end
  for _, n in ipairs(NAMES) do package.loaded[n] = saved[n] end
  return W
end
local W0 = load_world()
local Sq, Pr, Planner, B, P, C, Rs = W0.Sq, W0.Pr, W0.Pl, W0.B, W0.P, W0.C, W0.Rs

local function same_facts(a, b)
  for k, v in pairs(a) do if b[k] ~= v then return false, k end end
  for k, v in pairs(b) do if a[k] ~= v then return false, k end end
  return true
end

---------------------------------------------------------------------------------------------------
section("1. Règles pures : avant-poste à protéger, plus grosse vague, réserve de chargeurs")
---------------------------------------------------------------------------------------------------
local function sq_facts(Sx)
  local f = {}
  f.pf_hit, f.pf_small, f.pf_defended, f.pf_edge = Sx.protect_first({ hit = 200, turrets = 0, wanted = 2 }), Sx.protect_first({ hit = Sx.SITE_HIT - 1, turrets = 0, wanted = 2 }),
    Sx.protect_first({ hit = 900, turrets = 2, wanted = 2 }), Sx.protect_first({ hit = Sx.SITE_HIT, turrets = 1, wanted = 2 })
  f.pf_nil = Sx.protect_first(nil)
  local waves = { { t = 100, pv = 400, hq = true }, { t = 200, pv = 1740, hq = false }, { t = -300000, pv = 9999, hq = false }, { t = 5000000, pv = 7777, hq = true } }
  f.any = Sx.threat_any(waves, 1000)
  f.any_edge = Sx.threat_any({ { t = 0, pv = 321 } }, Sx.WINDOW)
  f.any_out = Sx.threat_any({ { t = 0, pv = 321 } }, Sx.WINDOW + 1)
  f.res_wave = Sx.ammo_reserve({ threat = 1740, turrets = 7, per_turret = 20 })
  f.res_cap = Sx.ammo_reserve({ threat = 100000, turrets = 7, per_turret = 20 })
  f.res_small = Sx.ammo_reserve({ threat = Sx.SITE_HIT - 1, turrets = 7, per_turret = 20 })
  f.res_none = Sx.ammo_reserve({ threat = 5000, turrets = 0, per_turret = 20 })
  f.res_noper = Sx.ammo_reserve({ threat = 5000, turrets = 3, per_turret = 0 })
  f.res_round = Sx.ammo_reserve({ threat = 161, turrets = 9, per_turret = 20 })
  f.res_edge = Sx.ammo_reserve({ threat = Sx.SITE_HIT, turrets = 9, per_turret = 20 })
  return f
end
local F0 = sq_facts(Sq)
check(F0.pf_hit and not F0.pf_small and not F0.pf_defended and not F0.pf_nil and F0.pf_edge,
  "protéger : vagues reçues au seuil ou au-dessus ET tourelles manquantes ; un petit raid, un site défendu, rien : non")
check(F0.any == 1740 and F0.any_edge == 321 and F0.any_out == 0, "plus grosse vague reçue n'importe où : fenêtre de 30 min, bord compris, futur et ancien exclus")
check(F0.res_wave == 44 and F0.res_cap == 140 and F0.res_small == 0 and F0.res_none == 0 and F0.res_noper == 0,
  "réserve de chargeurs : 1 740 PV -> 44 (40 PV par chargeur), plafonnée à la charge des 7 tourelles (140), rien sous le seuil, sans tourelle")
check(F0.res_edge == 4 and F0.res_round == 5, "réserve : arrondi au-dessus (150 PV -> 4, 161 PV -> 5)")

---------------------------------------------------------------------------------------------------
section("2. Planificateur : l'avant-poste touché est protégé d'abord, même en mode survie")
---------------------------------------------------------------------------------------------------
local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)
local recipes_nt = {}
for k, v in pairs(recipes) do if k ~= "gun-turret" then recipes_nt[k] = v end end
local book_nt = Book.new(recipes_nt)
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
local function op(id, kind, drills, turrets, protect)
  return { id = id, kind = kind, drills = drills, full = false, turrets = turrets or 0, coal_needed = 0, fuel_low = false, output = 0,
    idle_ticks = 0, has_task = true, has_fortify = false, protect = protect or nil }
end
local function keys_of(p)
  local set = {}
  for _, t in ipairs(p.tasks) do set[t.key] = true end
  return set
end
local kit = { ["burner-mining-drill"] = 20, ["stone-furnace"] = 20, ["iron-chest"] = 8 }
local function stock_of(over)
  local st = { [IRON] = 3000, [COPPER] = 1000, coal = 500, stone = 500, [T.turret_ammo] = 60, ["gun-turret"] = 4 }
  for k, x in pairs(kit) do st[k] = x end
  for k, x in pairs(over or {}) do st[k] = x end
  return st
end
local function pl_facts(Pl)
  local f = {}
  local outs_hit = { op(1, "coal", 4, 1), op(2, "iron", 8, 0, true), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
  local outs_calm = { op(1, "coal", 4, 1), op(2, "iron", 8, 0, false), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
  for _, sc in ipairs({ { "calm", outs_calm }, { "hit", outs_hit } }) do
    local p = Pl.plan(view({ stock = stock_of(), outposts = sc[2], survie = true }), book)
    local k = keys_of(p)
    f[sc[1] .. "_mode"], f[sc[1] .. "_pf"] = p.priorite.mode, p.priorite.production_first
    f[sc[1] .. "_extend"], f[sc[1] .. "_fortify"] = k["extend:2"] and 1 or 0, k["fortify:2"] and 1 or 0
    f[sc[1] .. "_turret_ok"] = p.turret_ok and 1 or 0
    f[sc[1] .. "_cp"] = p.priorite.production_cost or -1
  end
  -- pauvre en fer (aucune tourelle au stock, 160 de fer) : le site touché fait fabriquer sa tourelle sous l'ancien plancher
  local poor = Pl.plan(view({ stock = stock_of({ [IRON] = 160, ["gun-turret"] = 0, [T.turret_ammo] = 0 }), outposts = outs_hit, survie = true }), book)
  f.poor_mode = poor.priorite.mode
  f.poor_craft_turret = keys_of(poor)["craft:gun-turret:defense:1"] and 1 or 0
  local poor0 = Pl.plan(view({ stock = stock_of({ [IRON] = 160, ["gun-turret"] = 0, [T.turret_ammo] = 0 }), outposts = outs_calm, survie = true }), book)
  f.poor_calm_craft = keys_of(poor0)["craft:gun-turret:defense:1"] and 1 or 0
  -- sans recette de tourelle : rien ne change (le site touché s'agrandit comme avant)
  local nt = Pl.plan(view({ stock = stock_of({ ["gun-turret"] = 0 }), outposts = outs_hit, survie = true }), book_nt)
  f.norecipe_mode, f.norecipe_extend = nt.priorite.mode, keys_of(nt)["extend:2"] and 1 or 0
  -- le site touché mais DÉFENDU (turrets >= voulues) : pas de protection
  local def = Pl.plan(view({ stock = stock_of(), outposts = { op(1, "coal", 4, 1), op(2, "iron", 8, 9, true), op(3, "copper", 3, 1), op(4, "stone", 2, 1) },
    survie = true }), book)
  f.defended_mode = def.priorite.mode
  return f
end
local L0 = pl_facts(Planner)
check(L0.calm_mode == Pr.MODE_SURVIE_PENURIE and L0.calm_pf and L0.calm_extend == 1,
  "témoin : mode survie, site de fer sans tourelle mais que rien ne touche : la production d'abord, il s'agrandit sans attendre sa tourelle (fer riche : sa tourelle part aussi)")
check(L0.hit_mode == Pr.MODE_QG_PERIL and not L0.hit_pf and L0.hit_extend == 0 and L0.hit_fortify == 1 and L0.hit_turret_ok == 1,
  "même site TOUCHÉ par des vagues : la défense d'abord, pas d'agrandissement, sa tourelle posée")
check(L0.poor_mode == Pr.MODE_QG_PERIL and L0.poor_craft_turret == 1 and L0.poor_calm_craft == 0,
  "fer 160, aucune tourelle : le site touché fait fabriquer sa tourelle sous l'ancien plancher de 150 ; le site calme, non")
check(L0.norecipe_mode == Pr.MODE_SURVIE_PENURIE and L0.norecipe_extend == 1, "sans recette de tourelle : rien ne change (production d'abord, le site s'agrandit)")
check(L0.defended_mode == Pr.MODE_SURVIE_PENURIE, "site touché mais défendu : pas de protection, la survie-pénurie comme avant")

---------------------------------------------------------------------------------------------------
section("3. Cerveau : réserve de chargeurs sur la menace, recherche de la tourelle d'abord")
---------------------------------------------------------------------------------------------------
local function fac_s(over)
  local s = { is_player = false, workers = 8, soldiers = 0, soldiers_max = 30, stock = { [T.turret_ammo] = 10, stone = 50 },
    cap = { coal = 1, iron = 2, copper = 1, stone = 1 }, pending = {}, sites = {}, smelters = 4, smelters_pending = 0,
    weights = B.weights({}, nil), research = nil, army_target = 18, economy_done = false }
  for k, x in pairs(over or {}) do s[k] = x end
  return s
end
local TG = { targets = { coal = 2, iron = 2, copper = 1, stone = 1 }, iron2_set = true }
local function goal_of(goals, key) for _, g in ipairs(goals) do if g.key == key then return g end end end
local function brain_facts(Bx)
  local f = {}
  local g0 = goal_of(Bx.generate(fac_s(), TG), "defense:munitions")
  local g1 = goal_of(Bx.generate(fac_s({ ammo_reserve = 100 }), TG), "defense:munitions")
  local g2 = goal_of(Bx.generate(fac_s({ ammo_reserve = 100, stock = { [T.turret_ammo] = 100 } }), TG), "defense:munitions")
  local g3 = goal_of(Bx.generate(fac_s({ ammo_reserve = 5 }), TG), "defense:munitions")
  f.base_n, f.base_min = g0 and g0.n, g0 and g0.minimal_n
  f.res_n, f.res_min = g1 and g1.n, g1 and g1.minimal_n
  f.res_full = g2 == nil and "none" or "goal"
  f.small_n, f.small_min = g3 and g3.n, g3 and g3.minimal_n
  -- hors « boot » (rien de prêt), la réserve ouvre quand même le but
  local gb = goal_of(Bx.generate(fac_s({ ammo_reserve = 100, cap = { coal = 0, iron = 0, copper = 0, stone = 0 } }), TG), "defense:munitions")
  local gn = goal_of(Bx.generate(fac_s({ cap = { coal = 0, iron = 0, copper = 0, stone = 0 } }), TG), "defense:munitions")
  f.boot_reserve, f.boot_none = gb ~= nil, gn ~= nil
  -- recherche de la tourelle : pas de plafond d'économie, servie d'abord
  local rd = goal_of(Bx.generate(fac_s({ research = { tech = "gun-turret", payable = true, for_defense = true, iron_cost = 400 } }), TG), "recherche")
  local rn = goal_of(Bx.generate(fac_s({ research = { tech = "gun-turret", payable = true, iron_cost = 400 } }), TG), "recherche")
  f.rd_value, f.rn_value = rd and rd.value, rn and rn.value
  f.rd_short, f.rn_short = rd and rd.short == true, rn and rn.short == true
  return f
end
local K0 = brain_facts(B)
check(K0.base_n == 50 and K0.base_min == 10, "témoin : réserve ordinaire B.AMMO_STOCK (60), minimum B.AMMO_MIN (20), 10 au coffre")
check(K0.res_n == 90 and K0.res_min == 90, "réserve de 100 chargeurs sur la menace : on en veut 90 de plus, et tout est payé même quand la production passe d'abord")
check(K0.res_full == "none" and K0.small_n == 50 and K0.small_min == 10, "réserve atteinte : plus de but ; réserve plus petite que l'ordinaire : l'ordinaire")
check(K0.boot_reserve and not K0.boot_none, "avant l'amorçage (rien de prêt), des vagues reçues ouvrent la réserve quand même")
check(K0.rd_value > B.RESEARCH_PRE and K0.rn_value == B.RESEARCH_PRE and K0.rd_short and not K0.rn_short,
  "recherche de la tourelle : pas plafonnée à B.RESEARCH_PRE avant le fer II et servie comme un travail court ; sans for_defense : plafonnée")

-- C.think : packs sous le plancher de fer
local function think_facts(Cx, Px, Rx)
  local f = {}
  local fstock = { [IRON] = 60, [COPPER] = 200, coal = 200, stone = 200, [T.turret_ammo] = 60, ["burner-mining-drill"] = 4, ["stone-furnace"] = 4 }
  for _, sc in ipairs({ { "dfn", true }, { "ord", false } }) do
    local v = view({ is_player = true, stock = fstock, workers = 8, smelters = 4, outposts = { op(1, "coal", 8, 1), op(2, "iron", 16, 1), op(3, "copper", 3, 1), op(4, "stone", 2, 1) },
      ladder = T.player_ladder, defend_first = true, hq_turrets = 0, hq_defend = 0 })
    local r = { tech = "gun-turret", payable = true, palier = false, packs = { { "automation-science-pack", 9 } }, for_defense = sc[2] or nil }
    local stt = Cx.new_state(0)
    local plan = Cx.think(v, book, stt, { tick = 0, weights = B.weights({}, nil), research = r, reach = {}, iron_floor = 150, is_player = true, industrie = true })
    f[sc[1] .. "_claim"] = stt.noyau and stt.noyau.parts and stt.noyau.parts.research or -1
    local n = 0
    for _, t in ipairs(plan.tasks) do if t.kind == "craft" and t.item == "automation-science-pack" then n = n + 1 end end
    f[sc[1] .. "_packs"] = n
  end
  -- le besoin porte les packs de la recherche de la tourelle
  local core = Rx.core({ research = { { "automation-science-pack", 9 }, { "x", 2 } } })
  local none = Rx.core({})
  local sum = 0
  for _, it in ipairs(core) do sum = sum + it[2] end
  f.core_sum, f.core_none = sum, #none
  return f
end
local H0 = think_facts(C, P, Rs)
check(H0.dfn_packs > 0 and H0.ord_packs == 0, "fer 60 sous un plancher de 150 : les packs de la recherche de la tourelle sont fabriqués, ceux d'une recherche ordinaire attendent")
check(H0.dfn_claim == 9 and H0.ord_claim == 0 and H0.core_sum == 11 and H0.core_none == 0, "le besoin (noyau) porte les packs de la recherche de la tourelle")

---------------------------------------------------------------------------------------------------
section("4. La chaîne lue dans les sources")
---------------------------------------------------------------------------------------------------
local src = {
  team = read_src("script/team/team.lua"), glue = read_src("script/team/survie_qg.lua"), planner = read_src("shared/team/planner.lua"),
  recon = read_src("script/team/reconstruction.lua"), surv = read_src("script/team/survie.lua"), cer = read_src("script/ai3/cerveau.lua"),
  scer = read_src("shared/ai3/cerveau.lua"), buts = read_src("shared/ai3/buts.lua"), res = read_src("shared/ai3/reserve.lua"),
}
local function has(s, pat) return s:find(pat, 1, true) ~= nil end
check(has(src.team, "SurvieQg.mark_protect(f, oid, tick, st.turrets, want_t)") and has(src.team, "SurvieQg.note_plan(f, plan)"),
  "maillon 1 (vue) : chaque avant-poste porte `protect`, le plan dit si une tourelle est posable")
check(has(src.planner, "local in_peril = qg_peril or protect_any") and has(src.planner, "out.turret_ok = turret_ok"),
  "maillon 2 (planificateur) : le site touché passe la défense d'abord (donc exclu de l'agrandissement), le plan publie turret_ok")
check(has(src.recon, "s1.prot[seed.oid] ~= nil") and has(src.recon, "protect_wait and math.huge"), "maillon 3 (reconstruction) : la pièce d'un site touché attend ses tourelles, sans compter pour l'abandon")
check(has(src.surv, "o.protect and f.team.s1 and f.team.s1.turret_ok == true"), "maillon 4 (survie) : l'agrandissement de survie évite le site touché")
check(has(src.cer, "ammo_reserve = SurvieQg.ammo_reserve(f, tick)") and has(src.scer, "ammo_reserve = ctx.ammo_reserve or 0") and has(src.buts, "math.max(B.AMMO_STOCK, reserve)"),
  "maillon 5 (réserve) : le runtime calcule la réserve, la situation la porte, le but la lit")
check(has(src.cer, "e.type == \"unlock-recipe\" and e.recipe == T.turret") and has(src.buts, "not r.for_defense") and has(src.scer, "ctx.research.for_defense"),
  "maillon 6 (recherche) : le runtime reconnaît la recherche de la tourelle, le but la sert d'abord, le noyau porte ses packs")
check(has(src.res, "add(acc, inp.research)"), "maillon 7 (noyau) : Rs.core ajoute les packs")

---------------------------------------------------------------------------------------------------
section("4 bis. Intégration 0.6.33 : le plan du cerveau publie la tourelle posable, la réserve est du besoin, l'attente n'abandonne pas")
---------------------------------------------------------------------------------------------------
do
  local hit = { op(1, "coal", 4, 1), op(2, "iron", 8, 0, true), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
  local rich = Planner.plan(view({ stock = stock_of(), outposts = hit }), book)
  local broke = Planner.plan(view({ stock = stock_of({ [IRON] = 0, [COPPER] = 0, ["gun-turret"] = 0, ["iron-gear-wheel"] = 0 }), outposts = hit }), book)
  check(rich.turret_ok == true and rich.turret_payable == true, "fer au coffre : la tourelle est posable tout de suite")
  check(broke.turret_ok == true and broke.turret_payable == false, "recette connue, 0 de fer : pas posable tout de suite (refaire passe avant d'attendre une tourelle)")
  local function think(reserve)
    local v = view({ is_player = true, stock = stock_of(), workers = 8, smelters = 4, outposts = hit, ladder = T.player_ladder, defend_first = true, hq_turrets = 0, hq_defend = 0 })
    local stt = C.new_state(0)
    local plan = C.think(v, book, stt, { tick = 0, weights = B.weights({}, nil), reach = {}, iron_floor = 150, is_player = true, industrie = true, ammo_reserve = reserve })
    return plan, stt
  end
  local plan0, st0 = think(0)
  local plan1, st1 = think(100)
  check(plan1.turret_ok == true and plan1.turret_payable == true, "le plan du CERVEAU (allumé par défaut) publie turret_ok et turret_payable : sans eux, les maillons 3 et 4 ne s'allument jamais")
  check(st1.noyau.parts.defense == st0.noyau.parts.defense + 100, "la réserve de chargeurs est dans le noyau : ni I1 ni le puits de C2 n'en prennent le fer")
  local Rc = require("shared.team.reconstruction")
  local rst = { lost = { k = { defers = 3 } } }
  for i = 1, 200 do Rc.defer(rst, "k", i, i, math.huge) end
  check(rst.lost.k.defers == 3 and not rst.lost.k.abandoned and rst.lost.k.retry == 200, "attendre ses tourelles ne compte aucun report (200 attentes : ni compteur ni abandon)")
  Rc.defer(rst, "k", 300, 300, 3)
  check(rst.lost.k.abandoned == true, "témoin : un report compté au-delà de son plafond abandonne")
end

---------------------------------------------------------------------------------------------------
section("5. Mutants")
---------------------------------------------------------------------------------------------------
local base = {
  Sq = read_src("shared/team/survie_qg.lua"), Pl = read_src("shared/team/planner.lua"), B = read_src("shared/ai3/buts.lua"),
  C = read_src("shared/ai3/cerveau.lua"), Rs = read_src("shared/ai3/reserve.lua"), P = read_src("shared/ai3/projets.lua"),
}
local function mutate(src_, old, new)
  local a, b = src_:find(old, 1, true)
  if not a then return nil end
  return src_:sub(1, a - 1) .. new .. src_:sub(b + 1)
end
local mutants = {
  { "protection sans seuil de vagues", "Sq", "return num(a.hit) >= Sq.SITE_HIT and num(a.turrets) < num(a.wanted)", "return num(a.hit) > 0 and num(a.turrets) < num(a.wanted)" },
  { "protection d'un site défendu", "Sq", "return num(a.hit) >= Sq.SITE_HIT and num(a.turrets) < num(a.wanted)", "return num(a.hit) >= Sq.SITE_HIT" },
  { "protection au seuil exclu", "Sq", "return num(a.hit) >= Sq.SITE_HIT and", "return num(a.hit) > Sq.SITE_HIT and" },
  { "vague hors fenêtre comptée", "Sq", "if w.t and tick >= w.t and tick - w.t <= Sq.WINDOW and num(w.pv) > best then", "if w.t and tick >= w.t and num(w.pv) > best then" },
  { "vague future comptée", "Sq", "if w.t and tick >= w.t and tick - w.t <= Sq.WINDOW and num(w.pv) > best then", "if w.t and tick - w.t <= Sq.WINDOW and num(w.pv) > best then" },
  { "réserve sans plafond", "Sq", "return n < cap and n or cap", "return n" },
  { "réserve sans seuil", "Sq", "if threat < Sq.SITE_HIT or turrets <= 0 or per <= 0 then return 0 end", "if turrets <= 0 or per <= 0 then return 0 end" },
  { "réserve arrondie vers le bas", "Sq", "local n = ceil(threat / Sq.PV_PER_MAG)", "local n = math.floor(threat / Sq.PV_PER_MAG)" },
  { "protection sans tourelle posable", "Pl", "  if df and turret_ok then\n    for _, o in ipairs(view.outposts or {}) do\n      if o.protect", "  if df then\n    for _, o in ipairs(view.outposts or {}) do\n      if o.protect" },
  { "protection d'un site défendu (planificateur)", "Pl", "if o.protect and (o.turrets or 0) < (o.want_t or T.defend_turrets(o.drills)) then protect_any = true end", "if o.protect then protect_any = true end" },
  { "protection sans effet sur la priorité", "Pl", "local in_peril = qg_peril or protect_any", "local in_peril = qg_peril" },
  { "pas de réserve dans le but", "B", "local ammo_target = math.max(B.AMMO_STOCK, reserve)", "local ammo_target = B.AMMO_STOCK" },
  { "réserve retenue par la production d'abord", "B", "minimal_n = math.max(0, math.max(B.AMMO_MIN, reserve) - (s.stock[ammo] or 0)) }", "minimal_n = math.max(0, B.AMMO_MIN - (s.stock[ammo] or 0)) }" },
  { "réserve sans amorçage", "B", "or s.at_war or reserve > 0", "or s.at_war" },
  { "recherche de la tourelle plafonnée", "B", "and not r.for_auto and not r.for_defense then v = B.RESEARCH_PRE end", "and not r.for_auto then v = B.RESEARCH_PRE end" },
  { "recherche de la tourelle pas courte", "B", "short = (cheap or r.for_defense) or nil }", "short = cheap or nil }" },
  { "packs hors du besoin", "C", "research = (ctx.research and ctx.research.for_defense) and ctx.research.packs or nil }, tick)", "research = nil }, tick)" },
  { "noyau sans packs", "Rs", "  add(acc, inp.research)\n", "" },
}
local killed = 0
for _, mu in ipairs(mutants) do
  local txt = mutate(base[mu[2]], mu[3], mu[4])
  if not txt then
    check(false, "mutant « " .. mu[1] .. " » : le texte à muter existe encore")
  else
    local W = load_world({ [mu[2]] = txt })
    local fa, fb
    if mu[2] == "Sq" then fa, fb = F0, sq_facts(W.Sq)
    elseif mu[2] == "Pl" then fa, fb = L0, pl_facts(W.Pl)
    elseif mu[2] == "B" then fa, fb = K0, brain_facts(W.B)
    else fa, fb = H0, think_facts(W.C, W.P, W.Rs) end
    local same = same_facts(fa, fb)
    if not same then killed = killed + 1 end
    check(not same, "mutant « " .. mu[1] .. " » détecté")
  end
end
print(string.format("[S1-PROTEGE] mutants refusés : %d sur %d", killed, #mutants))
check(killed == #mutants, "tous les mutants sont refusés")
print(string.format("[S1-PROTEGE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
