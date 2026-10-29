--[[
  Lot FER-EQUIPE : fer de votre équipe de PNJ (shared/team/fer_equipe.lua, planner, fond). Usage : lua5.2 tests/fer_equipe_test.lua
    §1 défense couverte et réserve (force brute sur les cas limites) ;
    §2 minages de renfort (conditions, plafond) ;
    §3 cerveau : une recrue de croissance ne descend pas le coffre sous la réserve (avec et sans tourelle possible) ;
    §4 fond : tâches de renfort, clés distinctes, jamais en double, jamais en prudence ni après un échec.
]]
package.path = "./?.lua;" .. package.path
local FE = require("shared.team.fer_equipe")
local RES = 750 -- valeur arbitraire de réserve pour les contrôles du planificateur (le plancher du lot est supprimé)
local Fond = require("shared.team.fond")
local Planner = require("shared.team.planner")
local Book = require("shared.team.book")
local S = require("shared.team.scale")
local T = require("shared.team.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- §1
local ok_out = { { turrets = 1, need = 1 }, { turrets = 2, need = 1 } }
check(FE.defended({ turret_ok = true, hq_turrets = 4, defend_hq = 4, outposts = ok_out }), "défendu : QG 4/4 et avant-postes couverts")
check(not FE.defended({ turret_ok = false, hq_turrets = 4, defend_hq = 4, outposts = {} }), "aucune tourelle possible : non couvert")
check(not FE.defended({ turret_ok = true, hq_turrets = 3, defend_hq = 4, outposts = {} }), "QG 3/4 : non couvert")
check(not FE.defended({ turret_ok = true, hq_turrets = 4, defend_hq = 4, outposts = { { turrets = 0, need = 1 } } }), "un avant-poste nu : non couvert")
check(FE.defended({ turret_ok = true, hq_turrets = 0, defend_hq = 0 }), "sans exigence : couvert")
check(FE.reserve(nil, false) == nil, "non couvert, sans croissance : aucune réserve (plancher supprimé)")
check(FE.reserve(400, false) == 400, "non couvert, réserve de croissance 400 : la réserve habituelle seule")
check(FE.reserve(900, false) == 900, "non couvert, croissance 900 : la réserve habituelle")
check(FE.reserve(400, true) == 400, "couvert : réserve de croissance")
check(FE.reserve(nil, true) == nil and FE.reserve(0, true) == nil, "couvert sans croissance : aucune réserve")
check(FE.START_RESERVE == nil, "plancher de 750 supprimé")

-- §2
local function em(over)
  local a = { idle = 6, plates = 100, ore = 0, smelters = 2 }
  for k, v in pairs(over or {}) do a[k] = v end
  return FE.extra_mines(a)
end
check(em() == FE.EXTRA_CAP, "6 inactifs, coffre pauvre : plafond de renfort")
check(em({ idle = 2 }) == 2, "2 inactifs : 2 minages")
check(em({ idle = 0 }) == 0, "aucun inactif : rien")
check(em({ smelters = 0 }) == 0, "sans four au QG : le minerai ne sert pas")
check(em({ plates = FE.IRON_ENOUGH }) == 0 and em({ plates = FE.IRON_ENOUGH - 1 }) > 0, "fer suffisant : rien (borne)")
check(em({ ore = FE.ORE_ENOUGH }) == 0 and em({ ore = FE.ORE_ENOUGH - 1 }) > 0, "minerai suffisant : rien (borne)")
check(em({ prudent = true }) == 0 and em({ skip = true }) == 0, "prudence ou échec récent : rien")
check(FE.extra_mines({}) == 0, "entrées vides : rien")

-- §3
local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local cost = S.recruit_cost(8)
local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {},
    outposts = {}, pending = {}, sites = {}, smelters = 0, smelters_pending = 0, smelter_task = false,
    smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0, turret_groups = {},
    soldiers = 0, soldiers_max = 100, workers = 10, workers_max = 30, workers_idle = 0, threatened = false, open = {},
    workers_wanted = 30, recruit_cost = cost, recover_floor = 8, no_research = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  return v
end
local function stock(iron) return { ["iron-plate"] = iron, ["copper-plate"] = 200, pistol = 5, ["firearm-magazine"] = 50, coal = 100 } end
local rich = Planner.plan(view({ stock = stock(2500), iron_reserve = RES }), book)
check(rich.recruit_workers == 1, "2 500 plaques, réserve 750 : la recrue part")
local poor = Planner.plan(view({ stock = stock(RES + 20), iron_reserve = RES }), book)
check(not poor.recruit_workers and poor.recruit_held and poor.grow_short, "coffre à la réserve : recrue retenue")
local edge_need = RES
for _, it in ipairs(cost) do if it[1] == "iron-plate" then edge_need = edge_need + it[2] end end
-- (le plan retire d'abord ~40 plaques d'autres besoins : on contrôle un peu au-dessus et un peu au-dessous du seuil)
local edge = Planner.plan(view({ stock = stock(edge_need + 60), iron_reserve = RES }), book)
check(edge.recruit_workers == 1, "réserve + coût + 60 : la recrue part")
local below = Planner.plan(view({ stock = stock(edge_need - 1), iron_reserve = RES }), book)
check(not below.recruit_workers and below.grow_short, "un de moins : retenue")
local sans = Planner.plan(view({ stock = stock(RES + 20) }), book)
check(sans.recruit_workers == 1, "sans iron_reserve (factions, tests d'avant) : règle d'avant")
local floorv = Planner.plan(view({ workers = 5, stock = stock(100), iron_reserve = RES }), book)
check(not floorv.grow_short, "sous l'effectif de départ : la réserve ne retient pas (survie)")
local old = Planner.plan(view({ stock = stock(300), grow_reserve = 400 }), book)
check(not old.recruit_workers and old.grow_short, "ancienne réserve de croissance seule : inchangée")

-- §4
local function fview(over)
  local v = { outposts = {}, sites = {}, smelters = 2, stock = {}, incoming = {} }
  for k, x in pairs(over or {}) do v[k] = x end
  return v
end
local function mines(c, res)
  local n, ks = 0, {}
  for _, t in ipairs(c.extraction) do if t.kind == "mine" and t.resource == res then n = n + 1; ks[#ks + 1] = t.key end end
  return n, ks
end
local ore = T.outposts.iron.resource
local c1 = Fond.candidates(fview(), { [T.outposts.iron.product] = 10 }, { mine_left = 0, mine_radius = 96, iron_extra = { res = ore, n = 3 } })
local n1, k1 = mines(c1, ore)
check(n1 == 3 and k1[1] ~= k1[2] and k1[2] ~= k1[3], "plafond manuel à 0, renfort 3 : 3 minages de fer à clés distinctes")
check(c1.extraction[1].radius == 96 and c1.extraction[1].fond, "rayon près du coffre, tâche de fond")
local c2 = Fond.candidates(fview(), {}, { mine_left = 0, keys = { [k1[1]] = true }, iron_extra = { res = ore, n = 3 } })
check(mines(c2, ore) == 2, "une clé déjà au tableau : pas de doublon")
check(mines(Fond.candidates(fview(), {}, { mine_left = 0, prudent = true, iron_extra = { res = ore, n = 3 } }), ore) == 0, "prudence : rien")
check(mines(Fond.candidates(fview(), {}, { mine_left = 0, mine_skip = { [ore] = true }, iron_extra = { res = ore, n = 3 } }), ore) == 0, "échec récent : rien")
check(mines(Fond.candidates(fview(), {}, { mine_left = 0 }), ore) == 0, "sans renfort : rien (factions inchangées)")
local c3 = Fond.candidates(fview(), {}, { mine_left = 2, iron_extra = { res = ore, n = 2 } })
check(mines(c3, ore) >= 2, "le renfort s'ajoute au plafond ordinaire")

-- §5 : le renfort doit aussi servir votre équipe SOUS son effectif de départ (fond coupé). Constat des parties du 29/10
-- (fo-logs/2026-10-29_VAGUE2/FUMEE, graine 1618033988) : équipe à 6 PNJ sur 8 de la minute 26 à la 60, 100 % inactifs, fer à 0 :
-- fond coupé (script/team/poles.lua : full/safe exigent n >= effectif de départ), donc aucun minage de renfort, donc aucune recrue.
check(FE.recruit_iron({ { "pistol", 1 }, { "x-plate", 70 }, { "x-plate", 5 } }, "x-plate") == 75 and FE.recruit_iron(nil, "x-plate") == 0, "fer d'une recrue (journal)")
check(type(FE.off_fond) == "function", "FE.off_fond existe")
if type(FE.off_fond) == "function" then
  check(FE.off_fond({ player = true, fond_on = false, threat = false }), "votre équipe, fond coupé (sous l'effectif) : renfort permis")
  check(not FE.off_fond({ player = true, fond_on = true, threat = false }), "fond allumé : le chemin ordinaire s'en charge")
  check(not FE.off_fond({ player = true, fond_on = false, threat = true }), "QG menacé : tout le monde au coffre, aucun renfort")
  check(not FE.off_fond({ player = false, fond_on = false, threat = false }), "une faction : jamais")
  check(not FE.off_fond({}), "entrées vides : non")
end
check(type(Fond.iron_extra_tasks) == "function", "Fond.iron_extra_tasks existe")
if type(Fond.iron_extra_tasks) == "function" then
  local ts = Fond.iron_extra_tasks({ iron_extra = { res = ore, n = 3 }, mine_radius = 96 })
  check(#ts == 3 and ts[1].kind == "mine" and ts[1].resource == ore and ts[1].fond and ts[1].radius == 96, "3 tâches de minage de fer de fond")
  check(#Fond.iron_extra_tasks({ iron_extra = { res = ore, n = 3 }, keys = { [ts[1].key] = true } }) == 2, "clé déjà au tableau : pas de doublon")
  check(#Fond.iron_extra_tasks({ iron_extra = { res = ore, n = 3 }, prudent = true }) == 0, "prudence : rien")
  check(#Fond.iron_extra_tasks({ iron_extra = { res = ore, n = 3 }, mine_skip = { [ore] = true } }) == 0, "échec récent : rien")
  check(#Fond.iron_extra_tasks({}) == 0 and #Fond.iron_extra_tasks({ iron_extra = { res = ore, n = 0 } }) == 0, "sans renfort : rien")
  -- mêmes tâches que par Fond.candidates (fond allumé)
  local viaC = Fond.candidates(fview(), {}, { mine_left = 0, mine_radius = 96, iron_extra = { res = ore, n = 3 } })
  local _, kc = mines(viaC, ore)
  check(#kc == 3 and kc[1] == ts[1].key and kc[2] == ts[2].key and kc[3] == ts[3].key, "mêmes clés par les deux chemins")
end

print(string.format("[FER-EQUIPE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
