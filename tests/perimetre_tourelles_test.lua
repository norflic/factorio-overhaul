--[[
  Lot CC-TOURELLES (F489, règles du DC, 10/11/2026) : banc HORS JEU. Lancement : lua5.2 tests/perimetre_tourelles_test.lua (racine du mod).
    1. règle pure shared/team/perimetre_tourelles.lua : sans minerai, les emplacements d'avant ; sur un gisement, le premier point HORS
       minerai de chaque rayon (le point d'avant est sur le minerai) ; gisement plus grand que la portée : rien (repli d'avant à l'appelant) ;
       gisement d'un seul côté : les autres emplacements restent ; ordre gardé, déterminisme, aucun `pairs` ;
    2. plafond du DC : T.defend_turrets ne dépasse jamais T.defend_outpost_max (6) ; le planificateur ne fait AUCUN poste à un avant-poste
       qui a ses 6 tourelles, même à 100 foreuses ou sous une garde voulue de 12 ; à 5 tourelles il en veut 6, pas plus ;
    3. fer tendu : sous le plancher de fer de la défense, aucune tourelle d'avant-poste n'est FABRIQUÉE (règle d'avant gardée) ;
    4. la chaîne lue dans les sources : la pose d'un avant-poste passe par le périmètre et refuse une position sur le minerai ;
    5. mutants : chacun doit être refusé.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local S = require("shared.team.scale")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end
local function read_src(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local PM_PATH, PL_PATH, CF_PATH, OP_PATH = "shared/team/perimetre_tourelles.lua", "shared/team/planner.lua", "shared/team/config.lua",
  "script/faction/outposts.lua"
local PM_SRC, PL_SRC, CF_SRC, OP_SRC = read_src(PM_PATH), read_src(PL_PATH), read_src(CF_PATH), read_src(OP_PATH)
local IRON, COPPER = T.outposts.iron.product, T.outposts.copper.product

local OFF = { { 7, 7 }, { -7, -7 }, { 7, -7 }, { -7, 7 }, { 9, 0 }, { -9, 0 }, { 0, 9 }, { 0, -9 } }
local function square(h) return function(x, y) return math.abs(x) <= h and math.abs(y) <= h end end
local function none() return false end
local REACH, STEP = 42, 2

local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)

--- Charge le module du périmètre, la config et le planificateur depuis des sources (éventuellement modifiées).
local function load_all(pm_src, cf_src, pl_src)
  local saved = { package.loaded["shared.team.config"], package.loaded["shared.team.planner"] }
  local Cf = assert(load(cf_src or CF_SRC, "@" .. CF_PATH))()
  package.loaded["shared.team.config"] = Cf
  package.loaded["shared.team.planner"] = nil
  local Pl = assert(load(pl_src or PL_SRC, "@" .. PL_PATH))()
  local Pm = assert(load(pm_src or PM_SRC, "@" .. PM_PATH))()
  package.loaded["shared.team.config"], package.loaded["shared.team.planner"] = saved[1], saved[2]
  return Pm, Cf, Pl
end

local function view(Cf, over)
  local v = {
    tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true, defense = true },
    deferred = {}, stock = { [IRON] = 2000, [COPPER] = 2000, coal = 500, stone = 500 }, incoming = {}, outposts = {}, pending = {},
    sites = { iron = 1 }, smelters = 2, smelters_pending = 0, smelter_task = false, smelter_output = 0, smelter_fuel_low = false,
    smelter_coal = 0, turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 8, workers_max = 30, workers_idle = 0,
    threatened = false, open = {}, workers_wanted = 30, no_research = true, ladder = Cf.player_ladder, hq_turrets = 8, hq_defend = 4,
    defend_first = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  v.recruit_cost = S.recruit_cost(v.workers)
  return v
end
local function op(id, drills, turrets, want_t)
  return { id = id, kind = "iron", drills = drills, full = true, turrets = turrets, want_t = want_t, coal_needed = 0, fuel_low = false,
    output = 0, idle_ticks = 0, has_task = true, has_fortify = false }
end
local function post_of(plan, id)
  for _, d in ipairs(plan.defend and plan.defend.posts or {}) do if d.id == id then return d end end
  return nil
end
local function crafts_turret(plan)
  for _, t in ipairs(plan.tasks or {}) do
    if t.kind == "craft" then
      for _, it in ipairs(t.items or {}) do if it[1] == "gun-turret" then return true end end
      if t.item == "gun-turret" or t.recipe == "gun-turret" then return true end
    end
  end
  return false
end

--- Faits mesurés sur un jeu de sources ; chaque mutant doit en changer au moins un.
local function facts(pm_src, cf_src, pl_src)
  local Pm, Cf, Pl = load_all(pm_src, cf_src, pl_src)
  local f = {}
  -- 1. règle pure
  local s0, l0 = Pm.sites(OFF, 100, 50, none, STEP, REACH)
  f.id_ok = #s0 == 8 and l0 == 0
  for i, o in ipairs(OFF) do if not (s0[i] and s0[i].x == 100 + o[1] and s0[i].y == 50 + o[2]) then f.id_ok = false end end
  local ore = square(21)
  local s1, l1 = Pm.sites(OFF, 0, 0, ore, STEP, REACH)
  f.edge_n, f.edge_lost = #s1, l1
  f.off_ore, f.first_off = true, true
  for i, q in ipairs(s1) do
    if ore(q.x, q.y) then f.off_ore = false end
    local o = OFF[i]
    local sx, sy = (o[1] > 0 and 1 or (o[1] < 0 and -1 or 0)), (o[2] > 0 and 1 or (o[2] < 0 and -1 or 0))
    if not ore(q.x - sx * STEP, q.y - sy * STEP) then f.first_off = false end -- le pas d'avant est encore sur le minerai
  end
  f.east = s1[5] ~= nil and s1[5].x == 23 and s1[5].y == 0
  f.diag = s1[2] ~= nil and s1[2].x == -23 and s1[2].y == -23
  local s2, l2 = Pm.sites(OFF, 0, 0, square(500), STEP, REACH)
  f.giant_n, f.giant_lost = #s2, l2
  local east_only = function(x, y) return x >= 0 and x <= 30 and math.abs(y) <= 30 end
  local s3 = Pm.sites(OFF, 0, 0, east_only, STEP, REACH)
  f.west_kept = false
  for _, q in ipairs(s3) do if q.x == -9 and q.y == 0 then f.west_kept = true end end
  -- le 1er emplacement d'avant (7, 7) est sur le minerai : poussé à (31, 31) ; le 2e (-7, -7) est hors minerai : gardé, 2e
  f.order = s3[1] ~= nil and s3[1].x == 31 and s3[1].y == 31 and s3[2] ~= nil and s3[2].x == -7 and s3[2].y == -7
  local s4 = Pm.sites(OFF, 0, 0, east_only, STEP, REACH)
  f.det = #s3 == #s4
  for i = 1, #s3 do if not (s4[i] and s3[i].x == s4[i].x and s3[i].y == s4[i].y) then f.det = false end end
  -- 2. plafond
  f.cap = Cf.defend_outpost_max
  f.t0, f.t40, f.t1000 = Cf.defend_turrets(0), Cf.defend_turrets(40), Cf.defend_turrets(1000)
  local p6 = Pl.plan(view(Cf, { outposts = { op(1, 100, 6) } }), book)
  f.full_post = post_of(p6, 1)
  local p6w = Pl.plan(view(Cf, { outposts = { op(1, 100, 6, 12) } }), book)
  f.full_post_w = post_of(p6w, 1)
  local p5 = Pl.plan(view(Cf, { outposts = { op(1, 100, 5, 12) } }), book)
  local d5 = post_of(p5, 1)
  f.want5 = d5 and d5.want or nil
  f.und6 = Pl.undefended(view(Cf, { outposts = { op(1, 100, 6) } }))[1]
  -- 3. fer tendu
  local poor = Pl.plan(view(Cf, { stock = { [IRON] = math.max(0, Cf.defend_iron_floor - 20), [COPPER] = 500, coal = 50, stone = 50 },
    outposts = { op(1, 16, 0) } }), book)
  f.poor_craft = crafts_turret(poor)
  local dp = post_of(poor, 1)
  f.poor_why = dp and dp.why or "absent"
  local rich = Pl.plan(view(Cf, { outposts = { op(1, 16, 0) } }), book) -- témoin : au-dessus du plancher, la tourelle se fabrique
  f.rich_craft = crafts_turret(rich)
  return f
end

local function judge(f)
  section("1. Règle pure du périmètre")
  check(f.id_ok, "sans minerai : les huit emplacements d'avant, dans leur ordre")
  check(f.edge_n == 8 and f.edge_lost == 0, "gisement carré de 21 : un emplacement par rayon (" .. tostring(f.edge_n) .. ", " .. tostring(f.edge_lost) .. " perdus)")
  check(f.off_ore, "aucun emplacement sur le minerai")
  check(f.first_off, "chaque emplacement est le PREMIER point hors minerai de son rayon")
  check(f.east, "rayon est : (23, 0)")
  check(f.diag, "rayon nord-ouest : (-23, -23)")
  check(f.giant_n == 0 and f.giant_lost == 8, "gisement plus grand que la portée : rien, 8 directions sans bord")
  check(f.west_kept, "gisement à l'est seulement : l'emplacement ouest d'avant (-9, 0) reste")
  check(f.order, "l'ordre suit les emplacements d'avant")
  check(f.det, "déterminisme")
  section("2. Plafond du DC par avant-poste")
  check(f.cap == 6, "T.defend_outpost_max vaut 6 (" .. tostring(f.cap) .. ")")
  check(f.t0 == 1 and f.t40 == 6 and f.t1000 == 6, "T.defend_turrets : 1, 6, 6 (" .. tostring(f.t0) .. ", " .. tostring(f.t40) .. ", " .. tostring(f.t1000) .. ")")
  check(f.full_post == nil, "6 tourelles à 100 foreuses : aucun poste de défense")
  check(f.full_post_w == nil, "6 tourelles sous une garde voulue de 12 : aucun poste de défense")
  check(f.want5 == 6, "5 tourelles : 6 voulues, pas plus (" .. tostring(f.want5) .. ")")
  check(f.und6 == nil, "6 tourelles : l'avant-poste n'est pas « non défendu » (il s'agrandit)")
  section("3. Fer tendu")
  check(f.rich_craft, "témoin : fer abondant, la tourelle de l'avant-poste se fabrique (le contrôle n'est pas vide)")
  check(not f.poor_craft, "sous le plancher de fer : aucune tourelle fabriquée")
  check(f.poor_why ~= "fabrication", "sous le plancher de fer : le poste n'est pas « fabrication » (" .. tostring(f.poor_why) .. ")")
end

judge(facts())

section("4. La chaîne lue dans les sources")
check(OP_SRC:find("Outposts.perimeter(f, surface, outpost)", 1, true) ~= nil, "pose_order lit le périmètre de l'avant-poste")
check(OP_SRC:find("local accept = ore and function(q) return not ore(q.x, q.y) end or nil", 1, true) ~= nil, "Outposts.fortify refuse une position sur le minerai")
check(OP_SRC:find('type = "resource"', 1, true) ~= nil, "le minerai se lit au type d'entité (aucun nom)")
check(not PM_SRC:find("[^i]pairs%("), "aucun pairs dans la règle pure")
check(PL_SRC:find("math.min(T.defend_outpost_max, math.max(o.want_t or 0, T.defend_turrets(o.drills)))", 1, true) ~= nil, "le planificateur borne la garde voulue")

section("5. Mutants")
local function mutant(name, pm, cf, pl)
  local before = failures
  quiet = true
  local ok, err = pcall(function() judge(facts(pm, cf, pl)) end)
  quiet = false
  local refused = (not ok) or failures > before
  failures = before
  check(refused, "mutant refusé : " .. name .. (ok and "" or (" (erreur " .. tostring(err) .. ")")))
end
local function rep(src, a, b)
  local i, j = src:find(a, 1, true)
  assert(i, "motif absent du source : " .. a)
  return src:sub(1, i - 1) .. b .. src:sub(j + 1)
end
mutant("pas de marche (emplacements d'avant sur le minerai)", rep(PM_SRC, "if not ore(x, y) then found", "if true then found"))
mutant("un pas trop tôt (dernier point sur le minerai)",
  rep(PM_SRC, "if not ore(x, y) then found = { x = x, y = y } break end", "if not ore(x + sx * step, y + sy * step) then found = { x = x, y = y } break end"))
mutant("portée ignorée", rep(PM_SRC, "if math.max(math.abs(dx), math.abs(dy)) > reach then break end", "if math.max(math.abs(dx), math.abs(dy)) > 100000 then break end"))
mutant("direction ignorée (toujours vers l'est)", rep(PM_SRC, "local sx, sy = sign(o[1]), sign(o[2])", "local sx, sy = 1, 0"))
mutant("rayons sans bord non comptés", rep(PM_SRC, "else lost = lost + 1 end", "end"))
mutant("plafond retiré de la règle par foreuses",
  nil, rep(CF_SRC, "return math.min(T.defend_outpost_max, 1 + math.floor((drills or 0) / 8))", "return 1 + math.floor((drills or 0) / 8)"))
mutant("plafond retiré du planificateur",
  nil, nil, rep(PL_SRC, "math.min(T.defend_outpost_max, math.max(o.want_t or 0, T.defend_turrets(o.drills)))", "math.max(o.want_t or 0, T.defend_turrets(o.drills))"))
mutant("plafond à 8", nil, rep(CF_SRC, "T.defend_outpost_max = 6", "T.defend_outpost_max = 8"))

print(string.format("[PERIMETRE-TOURELLES] %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
