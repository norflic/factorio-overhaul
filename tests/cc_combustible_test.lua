--[[
  Lot CC-COMBUSTIBLE (10/11, partie du DC en 0.6.87, graine 3592985581, fo-logs/2026-11-10_PLAYTEST-0687) : le charbon que le
  planificateur reserve aux tournees des bruleurs (shared/team/planner.lua, « reserve avant toute fabrication ») doit aussi manquer
  au stock virtuel du cerveau (shared/ai3/cerveau.lua, C.consumed) : sinon les agrandissements (zero-idle, projets) et les
  fabrications du cerveau prennent ce charbon pendant que les bruleurs deja poses restent a sec (journal du DC : 84 bruleurs a
  l'avant-poste 1, 30 a 48 a sec de 20 a 90 min, tournees parties a 0 charbon, « coffre_sans_charbon »).
  Lancement : lua5.2 tests/cc_combustible_test.lua (depuis la racine du mod). Mutants : FO_CC_MUTANT=1 (reserve non exportee par
  le planificateur), FO_CC_MUTANT=2 (reserve non lue par C.consumed) : le test doit echouer.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")
local S = require("shared.team.scale")
local C = require("shared.ai3.cerveau")

local MUT = os.getenv("FO_CC_MUTANT")
if MUT == "1" then
  local plan0 = Planner.plan
  Planner.plan = function(...) local out = plan0(...); out.fuel_reserve = nil; return out end
elseif MUT == "2" then
  local cons0 = C.consumed
  C.consumed = function(base, view)
    local b = setmetatable({ fuel_reserve = 0 }, { __index = base })
    return cons0(b, view)
  end
end

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {}, outposts = {},
    pending = {}, sites = {}, smelters = 0, smelters_pending = 0, smelter_task = false, smelter_output = 0,
    smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 10,
    workers_max = 30, workers_idle = 10, threatened = false, open = {}, workers_wanted = 10, no_research = true,
    ladder = {}, hq_turrets = T.defend_hq, defend_first = false,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function op(id, kind, drills, over)
  local o = { id = id, kind = kind, drills = drills, full = false, turrets = 1, coal_needed = 0, fuel_low = false,
    output = 0, idle_ticks = 0, has_task = true, has_fortify = false }
  for k, x in pairs(over or {}) do o[k] = x end
  return o
end

local book = Book.new(dofile("tests/fixtures/recipes.lua"))
-- 1. L'etat du DC : avant-poste de fer de 84 bruleurs (besoin de 600 charbons pour les remplir), 68 charbons au coffre.
local v = view({ stock = { [T.fuel] = 68, ["iron-plate"] = 400, stone = 200 },
  outposts = { op(1, "iron", 42, { coal_needed = 600, fuel_low = true }), op(2, "coal", 8, { coal_needed = 40 }) },
  smelter_coal = 12 })
local base = Planner.plan(v, book)
check(base.fuel_reserve == 612, "le planificateur expose sa reserve des bruleurs (612 = 600 du fer + 12 des fours ; le charbon exclu), vu "
  .. tostring(base.fuel_reserve))
local used = C.consumed(base, v)
check((used[T.fuel] or 0) >= 612, "le cerveau compte la reserve comme consommee (charbon >= 612), vu " .. tostring(used[T.fuel]))
local avail = math.max(0, v.stock[T.fuel] - (used[T.fuel] or 0))
check(avail == 0, "stock virtuel du cerveau en charbon nul : aucun kit d'agrandissement ne prend le charbon des bruleurs a sec, vu " .. avail)

-- 2. Bruleurs pleins : la reserve est nulle, le charbon reste au cerveau.
local v2 = view({ stock = { [T.fuel] = 500 }, outposts = { op(1, "iron", 42, { coal_needed = 0 }) } })
local b2 = Planner.plan(v2, book)
check((b2.fuel_reserve or -1) == 0, "bruleurs pleins : reserve nulle, vu " .. tostring(b2.fuel_reserve))
check((C.consumed(b2, v2)[T.fuel] or 0) == 0, "bruleurs pleins : rien n'est retire du charbon du cerveau")

-- 3. Le charbon d'un avant-poste de combustible n'entre pas dans la reserve (il se ravitaille sur sa sortie).
local v3 = view({ stock = { [T.fuel] = 100 }, outposts = { op(2, "coal", 8, { coal_needed = 80 }) } })
check((Planner.plan(v3, book).fuel_reserve or -1) == 0, "avant-poste de charbon seul : reserve nulle")

-- 4. Reserve et kits du plan s'additionnent (les taches du plan portent leurs objets).
local b4 = { tasks = { { kind = "extend", items = { { T.fuel, 20 } } } }, fuel_reserve = 100 }
check((C.consumed(b4, view())[T.fuel] or 0) == 120, "reserve + kit du plan = 120")

-- 5. Determinisme : deux plans du meme etat donnent la meme reserve.
check(Planner.plan(v, book).fuel_reserve == base.fuel_reserve, "determinisme de la reserve")

print(string.format("cc_combustible_test : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
