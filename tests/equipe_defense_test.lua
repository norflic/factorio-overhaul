--[[
  Lot EQUIPE (1/11) : banc HORS JEU. Lancement : lua5.2 tests/equipe_defense_test.lua (racine du mod).
  Parité de votre équipe avec les factions, premier palier de la défense du QG (fo-logs/2026-11-01_EQUIPE/RAPPORT.md) :
    1. règle pure shared/team/premiere_tourelle.lua : planchers réduits sous P.FIRST_N tourelles, au QG seulement ;
    2. planificateur : sans tourelle au QG, le fer d'un coffre pauvre (214 plaques, 0 tourelle, recette acquise) paie la première tourelle
       (avant : plancher 150 + commande partielle 80 = 230, jamais atteint) ; avec deux tourelles, les planchers ordinaires reviennent ;
       les autres postes gardent leurs planchers ; sans « défendre d'abord », rien ;
    3. la chaîne lue dans les sources : la technologie de la tourelle est un palier pour votre équipe comme pour une faction ;
    4. mutants : chacun doit être refusé.
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
local PT_PATH, PL_PATH = "shared/team/premiere_tourelle.lua", "shared/team/planner.lua"
local PT_SRC, PL_SRC = read_src(PT_PATH), read_src(PL_PATH)

--- Charge le planificateur avec un module « première tourelle » et un planificateur éventuellement modifiés (sources en texte).
local function load_planner(pt_src, pl_src)
  local saved = { package.loaded["shared.team.premiere_tourelle"], package.loaded["shared.team.planner"] }
  package.loaded["shared.team.premiere_tourelle"] = assert(load(pt_src or PT_SRC, "@" .. PT_PATH))()
  package.loaded["shared.team.planner"] = nil
  local Pl = assert(load(pl_src or PL_SRC, "@" .. PL_PATH))()
  local Pt = package.loaded["shared.team.premiere_tourelle"]
  package.loaded["shared.team.premiere_tourelle"], package.loaded["shared.team.planner"] = saved[1], saved[2]
  return Pl, Pt
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
    hq_turrets = 0, defend_first = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  v.recruit_cost = S.recruit_cost(v.workers)
  return v
end
local function post_of(plan, id)
  for _, d in ipairs(plan.defend and plan.defend.posts or {}) do if d.id == id then return d end end
  return nil
end
local function op(id, kind, drills, turrets)
  return { id = id, kind = kind, drills = drills, full = false, turrets = turrets or 0, coal_needed = 0, fuel_low = false, output = 0,
    idle_ticks = 0, has_task = true, has_fortify = false }
end
local function poor(iron, have, over)
  local v = { stock = { [IRON] = iron, [COPPER] = 100, coal = 50, stone = 50 }, hq_turrets = have }
  for k, x in pairs(over or {}) do v[k] = x end
  return view(v)
end

---------------------------------------------------------------------------------------------------
section("1. Règle pure : planchers réduits sous P.FIRST_N tourelles, au QG seulement")
---------------------------------------------------------------------------------------------------
local Pt0 = require("shared.team.premiere_tourelle")
local function pt_facts(Pt)
  local f = {}
  f.hq0_i, f.hq0_c, f.hq0_first = Pt.floors("hq", 0, 150, 30, 60, 10)
  local _
  f.hq1_i, _, f.hq1_first = Pt.floors("hq", Pt.FIRST_N - 1, 150, 30, 60, 10)
  f.hqn_i, f.hqn_c, f.hqn_first = Pt.floors("hq", Pt.FIRST_N, 150, 30, 60, 10)
  f.out_i, _, f.out_first = Pt.floors("2", 0, 150, 30, 60, 10)
  f.low_i, _, f.low_first = Pt.floors("hq", 0, 40, 5, 60, 10) -- déjà sous le plancher réduit : on ne relève jamais
  f.nil_i = Pt.floors("hq", nil, nil, nil, nil, nil)
  return f
end
local P0 = pt_facts(Pt0)
check(P0.hq0_i == 60 and P0.hq0_c == 10 and P0.hq0_first, "QG sans tourelle : planchers 60 / 10, premier palier")
check(P0.hq1_i == 60 and P0.hq1_first, "QG à FIRST_N - 1 tourelle : encore au premier palier")
check(P0.hqn_i == 150 and P0.hqn_c == 30 and not P0.hqn_first, "QG à FIRST_N tourelles : planchers ordinaires")
check(P0.out_i == 150 and not P0.out_first, "un autre poste que le QG garde ses planchers")
check(P0.low_i == 40 and not P0.low_first, "un plancher déjà plus bas n'est jamais relevé")
check(P0.nil_i == 0, "entrées absentes : zéro, sans erreur")
check(Pt0.FIRST_N == 2, "premier palier = 2 tourelles (le QG d'une faction n'en veut que 0 ou 2)")

---------------------------------------------------------------------------------------------------
section("2. Planificateur : le fer d'un coffre pauvre paie la première tourelle")
---------------------------------------------------------------------------------------------------
local function pl_facts(Pl)
  local f = {}
  for _, iron in ipairs({ 100, 140, 214 }) do
    for have = 0, 2 do
      local d = post_of(Pl.plan(poor(iron, have), book), "hq")
      f[iron .. "_" .. have] = d and { why = d.why, floor = d.floor_i, first = d.first } or { why = "-" }
    end
  end
  -- le poste d'un avant-poste de fer sans tourelle ne bénéficie PAS du palier
  local outs = Pl.plan(poor(214, 2, { outposts = { op(2, "iron", 8, 0) } }), book)
  local dp = post_of(outs, "2")
  f.outpost = dp and { why = dp.why, floor = dp.floor_i, first = dp.first } or { why = "-" }
  -- sans « défendre d'abord » : aucun poste
  f.no_df = post_of(Pl.plan(poor(214, 0, { defend_first = false }), book), "hq") == nil
  return f
end
local L0, Pt1 = nil, nil
do
  local Pl
  Pl, Pt1 = load_planner()
  L0 = pl_facts(Pl)
end
check(L0["214_0"].why == "fabrication" and L0["214_0"].first and L0["214_0"].floor == 60,
  "214 plaques, 0 tourelle : la première tourelle part en fabrication au plancher réduit (avant : « fer », 230 exigées)")
check(L0["140_0"].why == "fabrication" and L0["100_0"].why == "fer",
  "140 plaques (60 + 80) paient la première tourelle, 100 non : le plancher réduit reste un plancher")
check(L0["214_1"].why == "fabrication" and L0["214_1"].first, "une tourelle au QG : le deuxième palier est encore au plancher réduit")
check(L0["214_2"].why == "fer" and L0["214_2"].floor == 150 and not L0["214_2"].first,
  "deux tourelles au QG : planchers ordinaires (214 < 230 : on attend)")
check(L0.outpost.floor ~= 60 and not L0.outpost.first, "le poste d'un avant-poste garde son plancher")
check(L0.no_df, "sans « défendre d'abord » (factions de l'ancien cerveau) : aucun poste, rien ne change")

---------------------------------------------------------------------------------------------------
section("3. Chaîne lue dans les sources : la technologie de la tourelle est un palier pour votre équipe")
---------------------------------------------------------------------------------------------------
local GEN_SRC = read_src("script/ai3/general.lua")
local function chain_ok(src)
  local line = src:match("[^\n]*defense = [^\n]*T%.turret[^\n]*")
  return line ~= nil and not line:find("is_player", 1, true)
end
check(chain_ok(GEN_SRC), "script/ai3/general.lua : defense = T.turret sans exclure is_player (lot DEFENSE-FACTIONS D2 étendu)")
check(not chain_ok(GEN_SRC:gsub("defense = T%.turret", "defense = (not f.is_player) and T.turret or nil", 1)),
  "témoin : l'ancienne ligne est refusée par le contrôle")
local DL_SRC = read_src("script/team/defense_log.lua")
check(DL_SRC:find("premiere tourelle", 1, true) ~= nil, "le journal [FO-DEFENSE] dit « premiere tourelle » (journal par cause)")

---------------------------------------------------------------------------------------------------
section("4. Mutants")
---------------------------------------------------------------------------------------------------
local mutants, refused = 0, 0
local function mutant(name, pt_src, pl_src)
  mutants = mutants + 1
  local ok, Pl, Pt = pcall(load_planner, pt_src, pl_src)
  local dead = false
  if not ok then dead = true
  else
    local ok2, fm = pcall(pl_facts, Pl)
    local ok3, pm = pcall(pt_facts, Pt)
    if not (ok2 and ok3) then dead = true
    else
      for k, v in pairs(L0) do
        if type(v) == "table" then
          for kk, vv in pairs(v) do if fm[k][kk] ~= vv then dead = true end end
        elseif fm[k] ~= v then dead = true end
      end
      for k, v in pairs(P0) do if pm[k] ~= v then dead = true end end
    end
  end
  if dead then refused = refused + 1 end
  check(dead, "mutant refusé : " .. name)
end
local function sub(src, a, b)
  local out, n = src:gsub(a, function() return b end, 1)
  assert(n == 1, "motif introuvable : " .. a)
  return out
end
mutant("premier palier supprimé (FIRST_N = 0)", sub(PT_SRC, "P%.FIRST_N = 2", "P.FIRST_N = 0"), nil)
mutant("premier palier à 1 tourelle", sub(PT_SRC, "P%.FIRST_N = 2", "P.FIRST_N = 1"), nil)
mutant("premier palier à 4 tourelles", sub(PT_SRC, "P%.FIRST_N = 2", "P.FIRST_N = 4"), nil)
mutant("tous les postes au plancher réduit", sub(PT_SRC, 'post_id ~= "hq" or ', ""), nil)
mutant("plancher réduit ignoré", sub(PT_SRC, "local fi, fc = math%.min%(base_iron, num%(low_iron%)%), math%.min%(base_copper, num%(low_copper%)%)",
  "local fi, fc = base_iron, base_copper"), nil)
mutant("plancher réduit relevé (max au lieu de min)", sub(PT_SRC, "math%.min%(base_iron, num%(low_iron%)%)", "math.max(base_iron, num(low_iron))"), nil)
mutant("planificateur : règle non branchée", nil, sub(PL_SRC, "fi, fc, first_tier = Pt%.floors%(p%.id, p%.have, fi, fc, Sq%.FLOOR_IRON, Sq%.FLOOR_COPPER%)",
  "first_tier = false"))
mutant("planificateur : le QG est jugé sur les tourelles du poste voisin (have = 0)", nil, sub(PL_SRC,
  "Pt%.floors%(p%.id, p%.have, fi, fc", "Pt.floors(p.id, 0, fi, fc"))
mutant("planificateur : planchers du péril seulement (premier palier jamais marqué)", nil, sub(PL_SRC, "if first_tier then reduced, d%.first = true, true end", ""))
print(string.format("   %d mutants, %d refusés", mutants, refused))

print(string.format("[EQUIPE-DEFENSE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
