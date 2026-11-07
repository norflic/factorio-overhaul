--[[
  Sortie de spirale (shared/team/spirale.lua) : recrue GRATUITE de votre équipe sous son effectif de départ. Décision du DC (QCM,
  7/11 vers 14 h 25), mot pour mot : « je veux toujours n ouvriers minimum, donc 12 si 12 au départ. Au delas ça coute des
  ressources ». Lecture du lead : sous l'effectif de départ, ni plaques ni kit pris au stock, recrue équipée comme une autre, à
  2 PNJ comme à 1 ; au-delà, payée comme avant ; factions inchangées ; minage d'urgence gardé (parité avec les factions).
  État de la partie du DC sur 0.6.58 (fo-logs/2026-11-07_PARTIE-DC-0658/factorio-current-1415.log, votre équipe, 157,7 à 177 min) :
  2 PNJ sur 12, fer libre 0 ([FO-DEFENSE]), 194 chargeurs ([FO-REARMEMENT]), pierre et cuivre saturés ([FO-IA3C]).
  Sections : §1 règle pure ; §2 planificateur ; §3 lecteurs du cerveau (stock virtuel, budget de la pile) et copie d'E4 ;
  §4 câblage d'E4 (script/team/team.lua, structure) ; mutants de la règle, du planificateur, du cerveau, de la pile, de la copie.
  Le paiement en E4 est joué au moteur simulé par tests/pteam_test.lua (« Correction VERIF-NUIT (moteur simulé) »).
  Lancement : lua5.2 tests/spirale_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Sp = require("shared.team.spirale")
local T = require("shared.team.config")

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
end

local FE = T.outposts.iron.product

---------------------------------------------------------------------------------------------------
-- §1 Règle pure
---------------------------------------------------------------------------------------------------
local COST = { { FE, 22 }, { "pistol", 1 } }
local function suite_regle()
  check(Sp.free({ workers = 2, recover_floor = 12 }), "partie du DC (2 PNJ sur 12) : recrue gratuite")
  check(Sp.free({ workers = 1, recover_floor = 12 }) and Sp.free({ workers = 0, recover_floor = 12 }),
    "1 PNJ et 0 PNJ sur 12 : gratuite aussi (pas seulement sous 2)")
  check(Sp.free({ workers = 11, recover_floor = 12 }), "11 sur 12 : gratuite (la dernière qui manque)")
  check(not Sp.free({ workers = 12, recover_floor = 12 }) and not Sp.free({ workers = 13, recover_floor = 12 }),
    "12 et 13 sur 12 : payée (« au delas ça coute des ressources »)")
  check(not Sp.free({ workers = 1, recover_floor = 12, emergency = { floor = 12 } }), "faction (view.emergency) : jamais gratuite")
  check(not Sp.free({ workers = 1 }) and not Sp.free(nil), "sans effectif de départ connu, ou vue absente : jamais gratuite")
  local c = Sp.cost({ workers = 2, recover_floor = 12 }, COST)
  check(type(c) == "table" and #c == 0, "coût sous le départ : liste vide")
  check(Sp.cost({ workers = 12, recover_floor = 12 }, COST) == COST, "coût à l'effectif de départ : le coût tel quel")
  -- journal [FO-RECRUE] (choix (1) du lead : garde QGSURVIE gardée) : au plus une ligne par minute
  check(Sp.log_due(nil, 0) and not Sp.log_due(100, 3699) and Sp.log_due(100, 3700), "journal [FO-RECRUE] : au plus une ligne par minute")
  local tx = Sp.held_text({ key = "player", dist = 30.6, biters = 4, armed = 0, workers = 2, floor = 12, minutes = 157.7 })
  check(tx:find("[FO-RECRUE] player : recrue gratuite retenue : garde QG (biters a 31 tuiles, 0 tourelle(s) armee(s))", 1, true) == 1
    and tx:find("effectif 2/12 a 157.7 min", 1, true) ~= nil, "texte de [FO-RECRUE] : " .. tx)
  check(Sp.held_text({ key = "player" }):find("biters a ? tuiles", 1, true) ~= nil, "[FO-RECRUE] sans distance connue : « ? »")
end

---------------------------------------------------------------------------------------------------
-- §2 Planificateur (shared/team/planner.lua) : vues de votre équipe (recover_floor), livre des tests
---------------------------------------------------------------------------------------------------
local Planner = require("shared.team.planner")
local Book = require("shared.team.book")
local S = require("shared.team.scale")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local function pview(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {},
    outposts = {}, pending = {}, sites = {}, smelters = 2, smelters_pending = 0, smelter_task = false,
    smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0, turret_groups = {},
    soldiers = 0, soldiers_max = 0, workers = 2, workers_max = 30, workers_idle = 0, threatened = false, open = {},
    workers_wanted = 30, no_research = true, recover_floor = 12,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recover_floor == false then v.recover_floor = nil end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function has_task(plan, key)
  for _, t in ipairs(plan.tasks) do if t.key == key then return t end end
  return nil
end
local function wants_recruit(plan)
  for _, t in ipairs(plan.tasks) do if t.tag == "ouvrier" then return true end end
  return false
end
local DC = { ["firearm-magazine"] = 194, ["copper-plate"] = 5385, stone = 28888, coal = 300 }
local RICH = { [FE] = 2000, ["copper-plate"] = 500, coal = 100 }
local KIT = { [FE] = 2000, ["copper-plate"] = 500, coal = 100, pistol = 2, ["firearm-magazine"] = 30 }
local function free_armed(p)
  return p.recruit_workers == 1 and p.recruit_free == true and not p.recruit_unarmed and p.recruit_uses == nil
    and not wants_recruit(p)
end
local function suite_planner()
  local p2 = Planner.plan(pview({ workers = 2, stock = DC }), book)
  local mt = has_task(p2, "mine:iron-ore")
  check(free_armed(p2), "partie du DC (2 PNJ sur 12, fer 0) : recrue gratuite et équipée, rien de prélevé ni de fabriqué")
  check(mt ~= nil and mt.prio == 90, "partie du DC : minage d'urgence du fer à 90 (parité avec les factions)")
  check(free_armed(Planner.plan(pview({ workers = 1, stock = DC }), book)), "1 PNJ sur 12, fer 0 : gratuite et équipée (pas sans arme)")
  check(free_armed(Planner.plan(pview({ workers = 0, stock = {} }), book)), "équipe vide, coffre vide : gratuite et équipée")
  local pr = Planner.plan(pview({ workers = 5, stock = RICH }), book)
  check(free_armed(pr) and has_task(pr, "mine:iron-ore") == nil, "5 sur 12, 2 000 fer : gratuite (fer non pris), aucun minage d'urgence")
  local p12 = Planner.plan(pview({ workers = 12, stock = DC }), book)
  local m12 = has_task(p12, "mine:iron-ore")
  check(not p12.recruit_free and (m12 == nil or m12.prio < 90), "à l'effectif de départ : pas de recrue gratuite, pas de minage d'URGENCE")
  local p13 = Planner.plan(pview({ workers = 13, stock = KIT }), book)
  check(p13.recruit_workers == 1 and not p13.recruit_free and not p13.recruit_unarmed,
    "13 sur 12, kit et 2 000 fer au coffre : recrue de croissance PAYÉE (règle ordinaire)")
  local fac = Planner.plan(pview({ workers = 1, stock = RICH, recover_floor = false, emergency = { floor = 12, rebuild = false } }), book)
  check(fac.recruit_workers == 1 and not fac.recruit_free and fac.recruit_uses ~= nil, "faction (view.emergency) : payée avec les plaques, comme avant")
  local ph = Planner.plan(pview({ workers = 2, stock = DC, hold_recruits = true }), book)
  check(not ph.recruit_workers and not ph.recruit_free, "recrues retenues (garde QGSURVIE ou perte récente) : aucune recrue, gardée")
  local pb = Planner.plan(pview({ workers = 2, stock = DC, recruit_blocked = true }), book)
  check(not pb.recruit_free and not (pb.recruit_workers and not pb.recruit_unarmed), "plafond d'agents atteint : aucune recrue gratuite")
  local again = Planner.plan(pview({ workers = 2, stock = DC }), book)
  check(free_armed(again) and #again.tasks == #p2.tasks, "deux pensées identiques")
end

---------------------------------------------------------------------------------------------------
-- §3 Lecteurs du cerveau : stock virtuel (C.consumed), budget de la pile (Pi.signals), copie d'E4 (E.freeze)
---------------------------------------------------------------------------------------------------
local C = require("shared.ai3.cerveau")
local Pi = require("shared.ai3.pile")
local Et = require("shared.team.etapes")
local function suite_lecteurs()
  local v = pview({ workers = 2, stock = DC })
  local used_free = C.consumed({ tasks = {}, recruit_workers = 1, recruit_free = true }, v)
  local used_paid = C.consumed({ tasks = {}, recruit_workers = 1 }, v)
  check(used_free[FE] == nil and (used_paid[FE] or 0) > 0,
    string.format("stock virtuel : la recrue gratuite ne prend rien (fer %s ; payée : %s)", tostring(used_free[FE]), tostring(used_paid[FE])))
  local sp = Pi.signals({ workers = 2, recover_floor = 12, recruit_cost = { { FE, 30 } } }, {}, {}, {}, nil, nil)
  check(sp.survive == "effectif" and #(sp.recruit_claim or { 0 }) == 0,
    "budget de la pile, votre équipe sous le départ : survie « effectif » gardée, AUCUN fer réclamé pour les recrues")
  local sf = Pi.signals({ workers = 2, emergency = { floor = 12 }, recruit_cost = { { FE, 30 } } }, {}, {}, {}, nil, nil)
  check(sf.recruit_claim and sf.recruit_claim[1] and sf.recruit_claim[1][2] == 300, "budget de la pile, faction : 10 recrues à 30 fer = 300 (inchangé)")
  local fz = Et.freeze(v, { recruit_workers = 1, recruit_free = true })
  check(fz.plan.recruit_free == true, "copie d'E4 (shared/team/etapes.lua) : plan.recruit_free gardé de T à T + 3")
end

suite_regle()
suite_planner()
suite_lecteurs()
local base_fail = failures

---------------------------------------------------------------------------------------------------
-- Mutants
---------------------------------------------------------------------------------------------------
local killed, total = 0, 0
local function run_all() suite_regle() suite_planner() suite_lecteurs() end
local function judge(name, ok, f0)
  local caught = (failures > f0) or not ok
  if caught then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. name) end
end
local real_free = Sp.free
local function rule_mutant(name, f)
  total = total + 1
  Sp.free = f
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(run_all)
  quiet = false
  Sp.free = real_free
  judge(name, ok, f0)
  passes, failures = p0, f0
end
rule_mutant("jamais gratuite (0.6.58 : payée avec les plaques)", function() return false end)
rule_mutant("gratuite aussi à l'effectif de départ (<=)", function(v)
  return v ~= nil and not v.emergency and v.recover_floor ~= nil and (v.workers or 0) <= v.recover_floor end)
rule_mutant("gratuite aussi pour les factions", function(v)
  local fl = v and (v.recover_floor or (v.emergency and v.emergency.floor))
  return fl ~= nil and (v.workers or 0) < fl end)
rule_mutant("gratuite seulement sous 2 PNJ (ancienne consigne)", function(v) return real_free(v) and (v.workers or 0) < 2 end)
do -- journal à chaque pensée au lieu d'une fois par minute
  total = total + 1
  local real_every = Sp.LOG_EVERY
  Sp.LOG_EVERY = 300
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(run_all)
  quiet = false
  Sp.LOG_EVERY = real_every
  judge("[FO-RECRUE] a chaque pensee (300 ticks)", ok, f0)
  passes, failures = p0, f0
end

local function src_of(path) local fh = assert(io.open(path, "rb")) local t = fh:read("*a") fh:close() return t end
local function mutate(src, from, to)
  local a, b = src:find(from, 1, true)
  if not a then return nil end
  return src:sub(1, a - 1) .. to .. src:sub(b + 1)
end
--- Copie mutée d'un module (path, nom local du module dans ce test), chargée à part, puis les suites.
local function module_mutant(name, path, from, to, set)
  total = total + 1
  local mutated = mutate(src_of(path), from, to)
  if not mutated then print("  MUTANT INTROUVABLE : " .. name) return end
  local M = assert(load(mutated, "=" .. path .. "-mutant"))()
  local restore = set(M)
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(run_all)
  quiet = false
  restore()
  judge(name, ok, f0)
  passes, failures = p0, f0
end
local function set_planner(M) local r = Planner Planner = M return function() Planner = r end end
local function set_cerveau(M) local r = C C = M return function() C = r end end
local function set_pile(M) local r = Pi Pi = M return function() Pi = r end end
local function set_etapes(M) local r = Et Et = M return function() Et = r end end
module_mutant("planificateur : pas de drapeau recruit_free (E4 paierait)", "shared/team/planner.lua",
  "out.recruit_free = true", "", set_planner)
module_mutant("planificateur : pas de minage d'urgence", "shared/team/planner.lua",
  "if next(p.raw) ~= nil then emergency_mine(p.raw) end", "", set_planner)
module_mutant("planificateur : garde des recrues retenues ignorée", "shared/team/planner.lua",
  "if rf and not view.hold_recruits and not view.recruit_blocked and Sp.free(view) then",
  "if rf and not view.recruit_blocked and Sp.free(view) then", set_planner)
module_mutant("planificateur : plafond d'agents ignoré", "shared/team/planner.lua",
  "if rf and not view.hold_recruits and not view.recruit_blocked and Sp.free(view) then",
  "if rf and not view.hold_recruits and Sp.free(view) then", set_planner)
module_mutant("cerveau : la recrue gratuite prend au stock virtuel", "shared/ai3/cerveau.lua",
  "and not base.recruit_free then", "then", set_cerveau)
module_mutant("pile : les recrues gratuites réclament leur fer au budget", "shared/ai3/pile.lua",
  "ipairs(Sp.cost(view, view.recruit_cost) or {})", "ipairs(view.recruit_cost or {})", set_pile)
module_mutant("copie d'E4 : recruit_free perdu entre T et T + 3", "shared/team/etapes.lua",
  '"recruit_blocked", "recruit_free",', '"recruit_blocked",', set_etapes)

---------------------------------------------------------------------------------------------------
-- §4 Câblage hors du Lua pur (structure) : E4 saute le paiement, le besoin évalué ne compte pas les recrues gratuites
---------------------------------------------------------------------------------------------------
local function count(src, pat)
  local n, i = 0, 1
  while true do
    local x, y = src:find(pat, i, true)
    if not x then return n end
    n, i = n + 1, y + 1
  end
end
local WIRES = {
  { "script/team/team.lua", "local free = f.is_player and plan.recruit_free or false" },
  { "script/team/team.lua", "and (free or has_list(stock, pay)) then" },
  { "script/team/team.lua", "if not free then remove_list(f, pay) end" },
  { "script/team/team.lua", "if Worker.recruit(f, surface, tick, false, free) then" },
  { "script/team/team.lua", "elseif not free then" },
  { "shared/ai3/cerveau.lua", "cost = Sp.cost(view, view.recruit_cost)," },
  { "shared/ai3/cerveau.lua", "recruit_free = base.recruit_free," },
  -- [FO-RECRUE] : dans la branche de la garde QGSURVIE (hold_recruits), recrue gratuite seulement, au plus 1 par minute
  { "script/team/team.lua", "if Sp.free({ workers = f.engineers_count or 0, recover_floor = floor }) and Sp.log_due(f.team.recrue_log, tick) then" },
  { "script/team/team.lua", "f.team.recrue_log = tick" },
  { "script/team/team.lua", "log(Sp.held_text({" },
}
local wired = true
for _, w in ipairs(WIRES) do if count(src_of(w[1]), w[2]) ~= 1 then wired = false print("  CABLAGE ABSENT : " .. w[1] .. " : " .. w[2]) end end
check(wired, "câblage : E4 (gratuite : rien de retiré ni rendu, kit offert), cerveau (besoin évalué, plan rendu)")
local tm_mut = 0
for _, w in ipairs(WIRES) do
  local src = src_of(w[1])
  local x, y = src:find(w[2], 1, true)
  local mutated = x and (src:sub(1, x - 1) .. "--" .. src:sub(y + 1)) or src
  if count(mutated, w[2]) ~= 1 then tm_mut = tm_mut + 1 end
end
check(tm_mut == #WIRES, string.format("mutants de texte du câblage : %d / %d vus", tm_mut, #WIRES))
-- Les anciennes sorties de la consigne remplacée (hold, recrue sans arme sous 2) n'existent plus.
check(count(src_of("shared/team/planner.lua"), "spirale_hold") == 0 and count(src_of("script/team/build.lua"), "spirale_hold") == 0,
  "plus de fer gardé (hold) : ni planificateur ni plan directeur")

print(string.format("[SPIRALE] MUTANTS : %d / %d refuses", killed, total))
print(string.format("[SPIRALE] BILAN : %d OK, %d ECHEC(S)%s", passes, failures + (total - killed), base_fail > 0 and " (suite de base en echec)" or ""))
os.exit((failures == 0 and killed == total) and 0 or 1)
