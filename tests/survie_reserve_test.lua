--[[
  Lot PARITE (reprise du 2/11 soir) : RÉSERVE DE SURVIE de la production d'abord. Banc HORS JEU. Lancement : lua5.2 tests/survie_reserve_test.lua
  (racine du mod). Critères : fo-logs/2026-11-02_PARITE/CRITERES2.md (R1).

  Décision du DC en autonomie : « un ordre de capitalisation ne descend pas le coffre sous la réserve de survie (défense du QG +
  reconstruction d'un avant-poste) tant que le QG n'a pas sa défense ». Mesure (runs150/final-pur-20261020, 25 à 31 min) : en « production
  d'abord » à 9 plaques, la production fabrique avec chaque plaque qui arrive, le coffre n'atteint jamais le plancher de la défense.

    1. la règle pure (Pr.survival_reserve) : cas, bornes, grille ;
    2. le planificateur : une cellule attaquée sans tourelles en « production d'abord » : la production ne fabrique plus sous la réserve ;
       sans cellule attaquée, ou avec du fer en abondance, ou en mode survie-pénurie : comme avant ;
    3. le noyau de la capitalisation (Rs.core) compte la réserve comme du besoin ;
    4. déterminisme ;
    5. mutants : chaque morceau de la règle retiré change au moins un fait.
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

local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)
local IRON = T.outposts.iron.product
local AMMO = T.turret_ammo

local function load_world(over)
  over = over or {}
  local names = { "shared.team.priorite", "shared.team.planner", "shared.ai3.reserve" }
  local saved = {}
  for _, n in ipairs(names) do saved[n] = package.loaded[n]; package.loaded[n] = nil end
  local function mod(name, path)
    if over[name] then
      package.loaded[name] = assert(load(over[name], "@" .. path))()
    else
      package.loaded[name] = nil
      package.loaded[name] = require(name)
    end
    return package.loaded[name]
  end
  local W = {}
  W.Pr = mod("shared.team.priorite", "priorite")
  W.Planner = mod("shared.team.planner", "planner")
  W.Rs = mod("shared.ai3.reserve", "reserve")
  for _, n in ipairs(names) do package.loaded[n] = saved[n] end
  return W
end

local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true, defense = true },
    deferred = {}, stock = {}, incoming = {}, outposts = {}, pending = {}, sites = {}, smelters = 2,
    smelters_pending = 0, smelter_task = false, smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0,
    turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 8, workers_max = 30, workers_idle = 0,
    threatened = false, open = {}, workers_wanted = 30, no_research = true, ladder = T.player_ladder,
    hq_turrets = T.defend_hq, defend_first = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function op(id, kind, drills, turrets, over)
  local o = { id = id, kind = kind, drills = drills, full = false, turrets = turrets or 0, coal_needed = 0,
    fuel_low = false, output = 0, idle_ticks = 0, has_task = true, has_fortify = false }
  for k, x in pairs(over or {}) do o[k] = x end
  return o
end
local function find(plan, pred)
  for _, t in ipairs(plan.tasks) do if pred(t) then return t end end
  return nil
end
local function key_is(k) return function(t) return t.key == k end end
local function with(base, extra)
  local s = {}
  for k, x in pairs(base) do s[k] = x end
  for k, x in pairs(extra or {}) do s[k] = x end
  return s
end

local W0 = load_world()
local Pr, Planner, Rs = W0.Pr, W0.Planner, W0.Rs

---------------------------------------------------------------------------------------------------
section("1. La règle pure")
---------------------------------------------------------------------------------------------------
local PF = Pr.MODE_PRODUCTION_D_ABORD
local function res(over) return Pr.survival_reserve(with({ mode = PF, defense_cost = 300, floor = 150, unit_cost = 120, attacked = true }, over)) end
check(res() == 270, "production d'abord, défense à payer, cellule attaquée : plancher + une unité (150 + 120)")
check(res({ unit_cost = 500 }) == 450, "une unité plus chère que la défense voulue : plancher + la défense (150 + 300)")
check(res({ attacked = false }) == 0, "aucune cellule attaquée : rien de retenu (la production comme avant)")
check(res({ defense_cost = 0 }) == 0, "aucune défense à payer : rien de retenu")
check(res({ mode = Pr.MODE_SURVIE_PENURIE }) == 0, "survie-pénurie : la production est la sortie, rien de retenu")
check(res({ mode = Pr.MODE_QG_PERIL }) == 0 and res({ mode = Pr.MODE_DEFENSE_D_ABORD }) == 0 and res({ mode = Pr.MODE_RIEN }) == 0
  and res({ mode = Pr.MODE_SURVIE }) == 0 and res({ mode = "inconnu" }) == 0, "les autres modes : rien de retenu")
check(Pr.survival_reserve(nil) == 0 and Pr.survival_reserve({}) == 0, "entrée vide : 0")
check(res({ floor = -5, unit_cost = -1, defense_cost = 10 }) == 0 or res({ floor = -5, unit_cost = -1, defense_cost = 10 }) >= 0,
  "entrées négatives : jamais de réserve négative")
local bad, n_cases = {}, 0
for _, mode in ipairs({ PF, Pr.MODE_DEFENSE_D_ABORD, Pr.MODE_SURVIE_PENURIE, Pr.MODE_QG_PERIL }) do
  for _, cd in ipairs({ 0, 10, 300 }) do
    for _, fl in ipairs({ 0, 60, 150 }) do
      for _, u in ipairs({ 0, 50, 400 }) do
        for _, att in ipairs({ false, true }) do
          n_cases = n_cases + 1
          local r = Pr.survival_reserve({ mode = mode, defense_cost = cd, floor = fl, unit_cost = u, attacked = att })
          if r < 0 then bad[#bad + 1] = "negatif" end
          if mode ~= PF and r ~= 0 then bad[#bad + 1] = "hors mode" end
          if r > fl + cd then bad[#bad + 1] = "plus que plancher + defense" end
          if (cd <= 0 or not att) and r ~= 0 then bad[#bad + 1] = "sans besoin" end
        end
      end
    end
  end
end
check(#bad == 0, string.format("%d cas de la grille, invariants tenus%s", n_cases, #bad > 0 and (" : " .. table.concat(bad, "; ")) or ""))

---------------------------------------------------------------------------------------------------
section("2. Le planificateur : la production ne fabrique plus sous la réserve")
---------------------------------------------------------------------------------------------------
-- Le fer est sous-défendu (1 tourelle sur 2) ; aucun bien d'équipement au stock : agrandir DEMANDE de fabriquer (foreuses, fours) avec le fer.
local outs = { op(1, "coal", 4, 1), op(2, "iron", 8, 1), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
local pick = { have = 0, count = 3, x = -50, y = -20, sites = {}, key = "-4,-2", score = 672 }
local base_stock = { ["copper-plate"] = 100, coal = 500, stone = 500 }
local function plan_with(P, iron, over)
  return P.plan(view(with({ stock = with(base_stock, { [IRON] = iron }), outposts = outs, sites = { iron = 1 } }, over)), book)
end
local function crafts_iron_for_production(plan)
  local n = 0
  for _, t in ipairs(plan.tasks) do
    if (t.kind == "craft") and (t.tag == "objectif" or t.tag == "charbon") then n = n + 1 end
  end
  return n
end
local no_front = plan_with(Planner, 260)
local attacked = plan_with(Planner, 260, { front = { pick = pick, busy = false } })
check(no_front.priorite.production_first and (no_front.priorite.reserve or 0) == 0,
  "témoin (aucune cellule attaquée) : la production d'abord, aucune réserve (" .. no_front.priorite.mode .. ")")
check(attacked.priorite.production_first and (attacked.priorite.reserve or 0) > 0,
  "cellule attaquée sans ses tourelles : la production d'abord ET une réserve de survie (" .. tostring(attacked.priorite.reserve) .. ")")
check(attacked.priorite.reserve >= T.defend_iron_floor, "la réserve couvre au moins le plancher de fer de la défense (" .. tostring(attacked.priorite.reserve) .. ")")
check(crafts_iron_for_production(no_front) > crafts_iron_for_production(attacked),
  string.format("sous la réserve, la production fabrique moins (%d tâche(s) de fabrication de production contre %d sans cellule attaquée)",
    crafts_iron_for_production(attacked), crafts_iron_for_production(no_front)))
local rich_plan = plan_with(Planner, 3000, { front = { pick = pick, busy = false } })
check(not rich_plan.priorite.production_first and (rich_plan.priorite.reserve or 0) == 0,
  "fer en abondance : la défense et la production sont payées, aucune réserve")
local pen = plan_with(Planner, 260, { front = { pick = pick, busy = false }, survie = true })
check((pen.priorite.reserve or 0) == 0, "mode survie-pénurie : aucune réserve (la production est la sortie)")
local nodf = plan_with(Planner, 260, { front = { pick = pick, busy = false }, defend_first = false })
check((nodf.priorite.reserve or 0) == 0, "sans « défendre d'abord » : règle d'avant, aucune réserve")
-- La défense, elle, garde tout le fer : la réserve ne diminue jamais ses fabrications.
local function defense_crafts(plan)
  local n = 0
  for _, t in ipairs(plan.tasks) do if t.tag == "defense" then n = n + 1 end end
  return n
end
check(defense_crafts(attacked) >= defense_crafts(no_front), "la défense fabrique autant avec la réserve que sans (" .. defense_crafts(attacked) .. " contre " .. defense_crafts(no_front) .. ")")

---------------------------------------------------------------------------------------------------
section("3. Le noyau de la capitalisation compte la réserve comme du besoin")
---------------------------------------------------------------------------------------------------
local core0 = Rs.core({})
local core1, parts1 = Rs.core({ floor = { { IRON, 270 } } })
local function iron_in(list) for _, it in ipairs(list) do if it[1] == IRON then return it[2] end end return 0 end
check(iron_in(core0) == 0 and iron_in(core1) == 270 and parts1.defense == 270, "le noyau contient la réserve (270 plaques) et la compte en défense")
local _, parts_pf = Rs.core({ production_first = true, floor = { { IRON, 270 } } })
check(parts_pf.defense == 270, "payée même quand la production passe d'abord")

---------------------------------------------------------------------------------------------------
section("4. Déterminisme")
---------------------------------------------------------------------------------------------------
local function sig(plan)
  local out = {}
  for _, t in ipairs(plan.tasks) do out[#out + 1] = t.key .. "@" .. tostring(t.prio) end
  return table.concat(out, ";") .. "|" .. tostring(plan.priorite.reserve)
end
check(sig(plan_with(Planner, 260, { front = { pick = pick } })) == sig(plan_with(Planner, 260, { front = { pick = pick } })), "deux plans identiques")

---------------------------------------------------------------------------------------------------
section("5. Mutants")
---------------------------------------------------------------------------------------------------
local src = {
  Pr = read_src("shared/team/priorite.lua"), Pl = read_src("shared/team/planner.lua"), Rs = read_src("shared/ai3/reserve.lua"),
}
local function mutate(text, from, to)
  local i, j = text:find(from, 1, true)
  if not i or text:find(from, j + 1, true) then return nil end
  return text:sub(1, i - 1) .. to .. text:sub(j + 1)
end
local function facts(W)
  local out = {}
  local a = plan_with(W.Planner, 260, { front = { pick = pick } })
  out[#out + 1] = sig(a)
  out[#out + 1] = sig(plan_with(W.Planner, 260))
  out[#out + 1] = sig(plan_with(W.Planner, 260, { front = { pick = pick }, survie = true }))
  out[#out + 1] = sig(plan_with(W.Planner, 3000, { front = { pick = pick } }))
  out[#out + 1] = tostring(W.Pr.survival_reserve({ mode = PF, defense_cost = 300, floor = 150, unit_cost = 120, attacked = true }))
  out[#out + 1] = tostring(W.Pr.survival_reserve({ mode = PF, defense_cost = 300, floor = 150, unit_cost = 120, attacked = false }))
  out[#out + 1] = tostring(W.Pr.survival_reserve({ mode = PF, defense_cost = 0, floor = 150, unit_cost = 120, attacked = true }))
  out[#out + 1] = tostring(W.Pr.survival_reserve({ mode = Pr.MODE_SURVIE_PENURIE, defense_cost = 300, floor = 150, unit_cost = 120, attacked = true }))
  out[#out + 1] = tostring(W.Pr.survival_reserve({ mode = PF, defense_cost = 50, floor = 150, unit_cost = 120, attacked = true }))
  local c, p = W.Rs.core({ floor = { { IRON, 270 } } })
  out[#out + 1] = tostring(iron_in(c)) .. "/" .. tostring(p.defense)
  return table.concat(out, "\n")
end
local base_facts = facts(W0)
local mutants = {
  { "règle : la réserve ne dépend plus de la cellule attaquée", "Pr", "if cd <= 0 or not a.attacked then return 0 end", "if cd <= 0 then return 0 end" },
  { "règle : la réserve vaut aussi sans défense à payer", "Pr", "if cd <= 0 or not a.attacked then return 0 end", "if not a.attacked then return 0 end" },
  { "règle : le mode survie-pénurie est aussi retenu", "Pr", "Pr.RESERVE_MODES = { [Pr.MODE_PRODUCTION_D_ABORD] = true }", "Pr.RESERVE_MODES = { [Pr.MODE_PRODUCTION_D_ABORD] = true, [Pr.MODE_SURVIE_PENURIE] = true }" },
  { "règle : le plancher n'est plus compté", "Pr", "return num(a.floor) + math.min(num(a.unit_cost), cd)", "return math.min(num(a.unit_cost), cd)" },
  { "règle : l'unité n'est plus bornée par la défense", "Pr", "math.min(num(a.unit_cost), cd)", "num(a.unit_cost)" },
  { "règle : l'unité de défense n'est plus comptée", "Pr", "return num(a.floor) + math.min(num(a.unit_cost), cd)", "return num(a.floor)" },
  { "planificateur : la réserve n'est plus fixée", "Pl", "    prod_reserve = pri.reserve\n", "" },
  { "planificateur : la production ne la respecte plus", "Pl", "if prod_reserve > 0 and PROD_TAGS[tag] then", "if false and PROD_TAGS[tag] then" },
  { "planificateur : la défense est aussi limitée", "Pl", "if prod_reserve > 0 and PROD_TAGS[tag] then", "if prod_reserve > 0 then" },
  { "planificateur : le charbon n'est plus limité", "Pl", "local PROD_TAGS = { charbon = true, objectif = true }", "local PROD_TAGS = { objectif = true }" },
  { "planificateur : l'objectif n'est plus limité", "Pl", "local PROD_TAGS = { charbon = true, objectif = true }", "local PROD_TAGS = { charbon = true }" },
  { "planificateur : la cellule attaquée est ignorée", "Pl", "attacked = (view.front and view.front.pick) and true or false })", "attacked = true })" },
  { "noyau : la réserve n'est plus du besoin", "Rs", "  add(acc, inp.floor)\n", "" },
  { "noyau : la réserve n'est plus comptée en défense", "Rs", "  parts.defense = parts.defense + count(inp.floor)\n", "" },
}
local killed = 0
for _, m in ipairs(mutants) do
  local name, which, from, to = m[1], m[2], m[3], m[4]
  local mutated = mutate(src[which], from, to)
  if check(mutated ~= nil, "mutant « " .. name .. " » : le texte à muter existe encore (une seule fois)") then
    local over = {}
    over[({ Pr = "shared.team.priorite", Pl = "shared.team.planner", Rs = "shared.ai3.reserve" })[which]] = mutated
    local ok, got = pcall(function() return facts(load_world(over)) end)
    if check((not ok) or got ~= base_facts, "mutant « " .. name .. " » refusé (un fait change)") then killed = killed + 1 end
  end
end
print(string.format("[SURVIE-RESERVE] mutants refusés : %d sur %d", killed, #mutants))
print(string.format("[SURVIE-RESERVE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
