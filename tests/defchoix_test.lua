--[[
  Tests hors jeu du lot DEFENSE-CHOIX : shared/team/defchoix.lua (règle pure : base menacée ou envahie, tourelles du QG avant les soldats,
  attaque entre factions retenue) et son branchement (shared/team/planner.lua, script/faction/pvp.lua, script/faction/commander.lua,
  script/team/team.lua, shared/ai3/cerveau.lua).
  Usage : lua5.2 tests/defchoix_test.lua
  Vérifie : D.base (calme, envahie, QG occupé, pertes récentes, pertes anciennes, début de partie sans fausse alerte), D.turrets (calme,
  fonds, cuivre, recette, plafond, tâche déjà ouverte), planificateur (600 fer et 600 cuivre, base menacée : tâche « fortify » du QG,
  pas de levée d'urgence à la même pensée ; base calme : règle d'avant ; levée reprise quand la tâche est ouverte), coût-efficacité lue
  au livre, branchements (textes des sources), MUTANTS.
]]
package.path = "./?.lua;" .. package.path
local D = require("shared.team.defchoix")
local T = require("shared.team.config")
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")
local S = require("shared.team.scale")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("ECHEC : " .. msg) end
end
local function section(s) print("-- " .. s) end

local IRON, COPPER = T.outposts.iron.product, T.outposts.copper.product

---------------------------------------------------------------------------------------------------
section("1. D.base : base menacée ou envahie")
local function base_cases()
  local ok = true
  local function c(cond, msg) if not cond then ok = false end check(cond, msg) end
  c(not D.base({ tick = 100000, threatened_until = 0 }).insecure, "calme : base sûre")
  c(not D.base({ tick = 500, threatened_until = 0 }).insecure, "début de partie (threatened_until = 0) : pas de fausse alerte")
  c(not D.base({ tick = 500 }).insecure, "début de partie (champ absent) : pas de fausse alerte")
  local b = D.base({ tick = 100000, threatened_until = 0, invaders = 1 })
  c(b.insecure and b.why == D.WHY_INVADED, "unité ennemie dans la base : envahie")
  b = D.base({ tick = 100000, threatened_until = 0, hq_lethal_tick = 99000, lethal_ticks = 18000 })
  c(b.insecure and b.why == D.WHY_HQ, "QG occupé par les biters : menacée")
  c(not D.base({ tick = 200000, hq_lethal_tick = 99000, lethal_ticks = 18000 }).insecure, "QG occupé il y a longtemps : sûre")
  -- perte près du QG il y a 1 min (alerte du commandant finie depuis 45 s)
  b = D.base({ tick = 100000, threatened_until = 100000 - 3600 + D.THREAT_TICKS })
  c(b.insecure and b.why == D.WHY_LOSSES and b.ago == 3600, "perte il y a 1 min : menacée (l'alerte de 15 s ne suffit pas)")
  c(not D.base({ tick = 100000, threatened_until = 100000 - D.ALERT_TICKS - 1 + D.THREAT_TICKS }).insecure, "perte il y a plus de 2 min : sûre")
  c(D.may_attack(D.base({ tick = 100000 })) and not D.may_attack(D.base({ tick = 100000, invaders = 3 })), "D.may_attack suit D.base")
  return ok
end
base_cases()

---------------------------------------------------------------------------------------------------
section("2. D.turrets : tourelles du QG avant les soldats")
local function turret_cases()
  local ok = true
  local function c(cond, msg) if not cond then ok = false end check(cond, msg) end
  local rich = { alert = true, want = 0, have = 2, ok = true, busy = false, funds_iron = 450, cost_iron = 120, funds_copper = 570, cost_copper = 10 }
  local r = D.turrets(rich)
  c(r.paid == 3 and r.want == 5 and r.first and r.hold_soldiers, "600 fer, 600 cuivre, base menacée : 3 tourelles payables, le QG en veut 5")
  local calm = {}
  for k, v in pairs(rich) do calm[k] = v end
  calm.alert = false
  r = D.turrets(calm)
  c(r.want == 0 and not r.first and not r.hold_soldiers, "base calme : règle d'avant")
  local poor = {}
  for k, v in pairs(rich) do poor[k] = v end
  poor.funds_iron = 100
  r = D.turrets(poor)
  c(r.want == 0 and not r.first and r.why == "fonds", "fer sous le prix d'une tourelle (au-dessus du plancher) : les soldats comme avant")
  poor.funds_iron, poor.funds_copper = 450, 5
  c(not D.turrets(poor).first, "cuivre manquant : rien")
  poor.funds_copper, poor.ok = 570, false
  c(not D.turrets(poor).first and D.turrets(poor).why == "recette", "tourelle ni fabricable ni au stock : rien")
  local big = {}
  for k, v in pairs(rich) do big[k] = v end
  big.funds_iron, big.funds_copper = 100000, 100000
  c(D.turrets(big).want == D.HQ_CAP, "plafond : D.HQ_CAP tourelles au QG")
  big.have = D.HQ_CAP
  c(not D.turrets(big).first and D.turrets(big).why == "complet", "QG au plafond : plus rien d'abord")
  local busy = {}
  for k, v in pairs(rich) do busy[k] = v end
  busy.busy = true
  r = D.turrets(busy)
  c(r.first and not r.hold_soldiers, "tâche de pose déjà ouverte : la levée reprend")
  local keep = {}
  for k, v in pairs(rich) do keep[k] = v end
  keep.want = 6
  c(D.turrets(keep).want == 6, "un besoin plus grand (F.hq_post, règle d'avant) est gardé")
  -- relecture : tourelles déjà au stock, fer au plancher : elles sont posées (déjà payées)
  local st = {}
  for k, v in pairs(rich) do st[k] = v end
  st.funds_iron, st.stock = 0, 3
  r = D.turrets(st)
  c(r.paid == 3 and r.want == 5 and r.first, "fer au plancher, 3 tourelles au stock : le QG les veut")
  st.stock = 100
  c(D.turrets(st).want == D.HQ_CAP, "stock compté sous le plafond")
  return ok
end
turret_cases()

---------------------------------------------------------------------------------------------------
section("3. Planificateur : 600 fer et 600 cuivre pendant une attaque")
local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)
local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true },
    deferred = {}, stock = {}, incoming = {}, outposts = {}, pending = {}, sites = {}, smelters = 2,
    smelters_pending = 0, smelter_task = false, smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0,
    turret_groups = {}, soldiers = 4, soldiers_max = 30, workers = 8, workers_max = 30, workers_idle = 0,
    threatened = true, open = {}, workers_wanted = 30, no_research = true, ladder = {},
    hq_turrets = 1, hq_defend = 0, defend_first = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function stock() return { [IRON] = 600, [COPPER] = 600, coal = 100, stone = 100 } end
local function hq_task(plan)
  -- la défense du QG : tourelles en fabrication (« craft:<tourelle>:defense ») ou tâche « fortify » du QG (tourelles au stock)
  for _, t in ipairs(plan.tasks) do
    if t.kind == "fortify" and t.outpost == "hq" then return t end
    if t.kind == "craft" and t.key and t.key:find("craft:" .. T.turret .. ":defense", 1, true) then return t end
  end
  return nil
end
local function army_wants(plan)
  for _, t in ipairs(plan.tasks) do
    if t.kind == "craft" and t.key and t.key:find(":armee:", 1, true) then return true end
  end
  return plan.train ~= nil
end
local function planner_cases()
  local ok = true
  local function c(cond, msg) if not cond then ok = false end check(cond, msg) end
  -- Avant le lot (base_alert absent) : une faction ne veut aucune tourelle au QG (F.hq_post = 0) et lève des soldats.
  local before = Planner.plan(view({ stock = stock() }), book)
  c(hq_task(before) == nil, "base calme (règle d'avant) : aucune tourelle au QG d'une faction")
  c(army_wants(before), "règle d'avant : levée de soldats d'urgence")
  local p = Planner.plan(view({ stock = stock(), base_alert = true }), book)
  local t = hq_task(p)
  c(t ~= nil, "base menacée, 600 fer : tourelles du QG commandées (fabrication)")
  c(p.defchoix and p.defchoix.first and p.defchoix.want > 1, "out.defchoix : tourelles du QG d'abord")
  c(not army_wants(p), "la pensée qui commande les tourelles ne lance pas la levée d'urgence")
  local p2 = Planner.plan(view({ stock = stock(), base_alert = true, hq_fortify = true }), book)
  c(p2.defchoix.first and not p2.defchoix.hold_soldiers and army_wants(p2), "tâche de pose ouverte : la levée reprend")
  local st2 = stock()
  st2[T.turret], st2[T.turret_ammo] = 6, 200
  local pf = Planner.plan(view({ stock = st2, base_alert = true }), book)
  local ft
  for _, x in ipairs(pf.tasks) do if x.kind == "fortify" and x.outpost == "hq" then ft = x end end
  c(ft ~= nil and ft.items[1][1] == T.turret and ft.items[1][2] >= 1, "tourelles au stock : tâche « fortify » du QG")
  local poor = Planner.plan(view({ stock = { [IRON] = 160, [COPPER] = 600, coal = 100, stone = 100 }, base_alert = true }), book)
  c(not poor.defchoix.first and hq_task(poor) == nil, "fer au plancher : aucune tourelle, règle d'avant")
  -- relecture (famine) : Dc.turrets juge 1 tourelle payable sur le stock d'avant les recharges ; une recharge de tourelle mange le fer,
  -- le QG n'est plus servi (« fer ») : la levée d'urgence ne doit PAS être retenue (sinon ni tourelle ni soldat pendant toute l'alerte).
  local lean = { [IRON] = T.defend_iron_floor + 125, [COPPER] = 600, coal = 100, stone = 100 }
  local pr = Planner.plan(view({ stock = lean, base_alert = true,
    turret_groups = { { key = "o1", low = 1, has_task = false } } }), book)
  c(pr.defchoix.paid == 1 and not pr.defchoix.hold_soldiers and army_wants(pr),
    "recharges qui mangent le fer, QG non servi : la levée d'urgence n'est pas retenue")
  local pl = Planner.plan(view({ stock = stock(), base_alert = true, defend_first = false }), book)
  c(not pl.defchoix.first, "sans « défendre d'abord » : règle d'avant")
  return ok
end
planner_cases()

---------------------------------------------------------------------------------------------------
section("4. Coût-efficacité (livre de recettes vanilla)")
local function iron_of(list) local r = book:raw_cost(list) return r[IRON] or 0, r[COPPER] or 0 end
local ti, tc = iron_of({ { T.turret, 1 }, { T.turret_ammo, T.defend_ammo } })
local si, sc = iron_of(T.kits.rifleman)
print(string.format("  tourelle + %d chargeurs : %d fer, %d cuivre ; fusilier équipé : %d fer, %d cuivre", T.defend_ammo, ti, tc, si, sc))
check(ti > 0 and si > 0 and ti <= 3 * si, "une tourelle armée coûte au plus 3 fusiliers (documenté dans shared/team/defchoix.lua)")
check(math.floor((600 - T.defend_iron_floor) / ti) >= 3, "600 de fer paient au moins 3 tourelles armées au-dessus du plancher")

---------------------------------------------------------------------------------------------------
section("5. Branchements (sources)")
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local pvp = read("script/faction/pvp.lua")
local i_guard = pvp:find("Dc.may_attack(bs)", 1, true)
local i_attack = pvp:find("Military.attack(f, surface, target, a.attack.count, tick, opts)", 1, true)
check(i_guard and i_attack and i_guard < i_attack, "pvp.lua : attaque entre factions gardée par Dc.may_attack avant Military.attack")
check(pvp:find("[FO-DEFCHOIX]", 1, true) ~= nil, "pvp.lua : journal [FO-DEFCHOIX]")
check(read("script/faction/commander.lua"):find('require("shared.team.defchoix").THREAT_TICKS', 1, true) ~= nil,
  "commander.lua : durée d'alerte lue dans shared/team/defchoix.lua (une seule source)")
local team = read("script/team/team.lua")
check(team:find("view.base_alert =", 1, true) and team:find("[FO-DEFCHOIX]", 1, true), "team.lua : view.base_alert et journal")
check(read("shared/ai3/cerveau.lua"):find("defchoix = base.defchoix", 1, true) ~= nil, "cerveau IA3 : out.defchoix transmis")
check(not read("shared/team/defchoix.lua"):find("pairs%("), "règle pure : aucun pairs")

---------------------------------------------------------------------------------------------------
section("6. MUTANTS")
local function mutant(name, patch, run)
  local saved = {}
  for k, v in pairs(D) do saved[k] = v end
  patch()
  local p0, f0 = passes, failures
  local okp, res = pcall(run)
  local killed = (not okp) or res == false
  passes, failures = p0, f0
  for k in pairs(D) do D[k] = nil end
  for k, v in pairs(saved) do D[k] = v end
  check(killed, "mutant détecté : " .. name)
end
local quiet = print
print = function() end
mutant("alerte de 2 min retirée", function() D.ALERT_TICKS = 0 end, base_cases)
mutant("envahisseurs ignorés", function() local b = D.base D.base = function(a) a.invaders = 0 return b(a) end end, base_cases)
mutant("D.may_attack toujours vrai", function() D.may_attack = function() return true end end, base_cases)
mutant("tourelles sans alerte", function() local f = D.turrets D.turrets = function(a) a.alert = true return f(a) end end, turret_cases)
mutant("cuivre ignoré", function() local f = D.turrets D.turrets = function(a) a.cost_copper = 0 return f(a) end end, turret_cases)
mutant("plafond retiré", function() D.HQ_CAP = 1000 end, turret_cases)
mutant("levée jamais retenue", function() local f = D.turrets D.turrets = function(a) local r = f(a) r.hold_soldiers = false return r end end, planner_cases)
mutant("stock de tourelles ignoré", function() local f = D.turrets D.turrets = function(a) a.stock = 0 return f(a) end end, turret_cases)
mutant("tourelles jamais voulues", function() local f = D.turrets D.turrets = function(a) a.alert = false return f(a) end end, planner_cases)
print = quiet

print(string.format("[DEFCHOIX] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
