--[[
  Lot PORTE-PILE : banc HORS JEU du branchement du premier module de fabrication au moteur simulé réduit (la règle pure est dans
  tests/premier_test.lua). Lancement, depuis la racine du mod : lua5.2 tests/premier_glue_test.lua
    1. Build.cost_left : objets qui manquent à la réserve d'un projet (besoin des pièces non posées moins sa réserve), triés ;
    2. Build.reserve_suspended : le module neuf ADMIS par la pile (st.premier) garde sa réserve pendant la retenue ; un autre module,
       un module non admis, une famille autre que capital et capi restent suspendus ; la porte du mall (PileRt.porte_any, mall) ;
    3. câblage (lecture des sources) : Auto.think rend les candidats { done, cands } (modules de fabrication seulement, D.NOT_FAB), la
       pile les lit (Pi.signals), le mall passe `true` à la porte ;
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end
local function read(path) local fh = assert(io.open(path, "rb")) local s = fh:read("*a") fh:close() return s end

local Mk = require("tests.mock_engine")
Mk.new_game({})
local Build = require("script.team.build")
local Stock = require("script.team.stock")
local PileRt = require("script.team.pile")
local Pi = require("shared.ai3.pile")
local real_log, real_insert = log, Stock.insert
local LOGS = {}
log = function(s) LOGS[#LOGS + 1] = s end
local COFFRE = {}
Stock.insert = function(_, it, n) COFFRE[it] = (COFFRE[it] or 0) + n return n end

local CIRCUIT, OTHER = "electronic-circuit", "stone-brick"
local function team(hold, premier)
  local st = Pi.new()
  st.hold, st.top, st.focus, st.premier = hold, hold and Pi.ADAPTER or Pi.AMELIORER, {}, premier
  return { key = "fx", force = "fx", started = 0, hq = { valid = true }, team = { ia3 = { pile = st, short_core = {} } },
    build = { order = {}, projects = {} } }
end

print("== 1. Build.cost_left")
do
  local f = team(false)
  f.build.projects[3] = { id = 3, state = "reserve", spec = {}, stock = { ["transport-belt"] = 4 },
    ents = { { built = false, item = "transport-belt" }, { built = false, item = "transport-belt" }, { built = false, item = "transport-belt" },
      { built = false, item = "transport-belt" }, { built = false, item = "transport-belt" }, { built = false, item = "inserter" },
      { built = true, item = "iron-chest" } } }
  local c = Build.cost_left(f, 3)
  check(#c == 2 and c[1][1] == "inserter" and c[1][2] == 1 and c[2][1] == "transport-belt" and c[2][2] == 1,
    "5 tapis non posés, 4 déjà réservés : 1 tapis et 1 bras manquent, triés ; la pièce posée ne compte pas")
  check(Build.cost_left(f, 99) == nil and Build.cost_left(nil, 3) == nil, "projet absent : nil")
  f.build.projects[4] = { id = 4, state = "attente", spec = {}, stock = {}, ents = {} }
  check(#Build.cost_left(f, 4) == 0, "projet sans pièces (avant son plan) : rien ne manque")
end

print("== 2. Build.reserve_suspended : le module admis garde sa réserve")
do
  local pm = { items = { [CIRCUIT] = true }, mall = true, admitted = { 3 }, skipped = {} }
  local f = team(true, pm)
  local p = { id = 3, state = "reserve", spec = { pile = "capital", product = CIRCUIT }, stock = { ["stone-furnace"] = 3 },
    missing = { { "stone-furnace", 5 } }, ents = {} }
  check(Build.reserve_suspended(f, p, 100) == false, "module admis par la pile pendant la retenue : réserve non suspendue")
  check((COFFRE["stone-furnace"] or 0) == 0 and (p.stock["stone-furnace"] or 0) == 3 and #p.missing == 1,
    "… ses objets ne sont pas rendus au coffre et ses manques restent demandés au cerveau")
  local q = { id = 4, state = "reserve", spec = { pile = "capital", product = OTHER }, stock = { ["stone-furnace"] = 2 },
    missing = { { "stone-furnace", 5 } }, ents = {} }
  check(Build.reserve_suspended(f, q, 100) == true and (COFFRE["stone-furnace"] or 0) == 2, "un autre module reste suspendu et rend ses objets")
  local r = { id = 5, state = "reserve", spec = { pile = "migration", product = CIRCUIT }, stock = {}, missing = {}, ents = {} }
  check(Build.reserve_suspended(f, r, 100) == true, "même produit mais famille migration : suspendu")
  local g = team(true, nil)
  local p2 = { id = 6, state = "reserve", spec = { pile = "capital", product = CIRCUIT }, stock = {}, missing = {}, ents = {} }
  check(Build.reserve_suspended(g, p2, 100) == true, "sans exception écrite par la pile : suspendu comme avant")
  local h = team(true, { items = {}, mall = false, admitted = {}, skipped = { 6 } })
  check(Build.reserve_suspended(h, p2, 100) == true, "candidat refusé faute de stock libre : suspendu")
  -- la porte du mall
  local m = team(true, { items = {}, mall = true, admitted = {}, skipped = {} })
  check(PileRt.porte_any(m, "capital", { "inserter", "belt" }, true) == true, "porte du mall : une place libre, le bloc passe")
  check(PileRt.porte_any(m, "capital", { "inserter", "belt" }) == false, "… sans demande du mall (porte_any sans mall), il ne passe pas")
  local n = team(true, { items = {}, mall = false, admitted = {}, skipped = {} })
  check(PileRt.porte_any(n, "capital", { "inserter" }, true) == false, "porte du mall : places prises, le bloc attend")
  check(PileRt.porte(m, "recherche", "inserter", true) == false, "porte du mall : la recherche n'est pas ouverte")
end
log, Stock.insert = real_log, real_insert

print("== 3. Câblage (lecture des sources)")
local auto = read("script/ai3/automatisation.lua")
local ind = read("script/ai3/industrie.lua")
local pile = read("shared/ai3/pile.lua")
local W = {
  auto_cands = auto:find("premiers = { done = pdone, cands = pcands }", 1, true) ~= nil,
  auto_fab = auto:find("Pm.is_fab(m.gen, D.NOT_FAB)", 1, true) ~= nil,
  auto_cost = auto:find("Build.cost_left(f, m.id)", 1, true) ~= nil,
  auto_rebuild = auto:find("Sweep.goal_for_module(m) and not m.rebuild", 1, true) ~= nil,
  auto_fini = auto:find('if m.state == "fini" then pdone = pdone + 1', 1, true) ~= nil,
  ind_mall = ind:find('PileRt.porte_any(f, "capital", c.items, true)', 1, true) ~= nil,
  pile_sig = pile:find("premiers = ctx and ctx.auto and ctx.auto.premiers or nil", 1, true) ~= nil,
}
check(W.auto_cands and W.auto_fab and W.auto_cost, "automatisation : candidats (fabrication seulement, D.NOT_FAB) avec leur coût restant")
check(W.auto_rebuild and W.auto_fini, "automatisation : ni reconstruction ni module refuse ; les finis comptent")
check(W.ind_mall, "industrie : la décision du mall passe `true` à la porte")
check(W.pile_sig, "pile : Pi.signals relaie les candidats du contexte")

print(string.format("[PORTE-PILE-GLUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
