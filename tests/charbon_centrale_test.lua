--[[
  Tests hors jeu du lot CHARBON-CENTRALE (retour du DC du 29/10 sur la 0.6.18 : coffre de charbon de la centrale oublié).
  1. Règles pures (shared/team/charbon_centrale.lua) et mutants.
  2. Le VRAI code de script/team/build.lua (quai_tasks, cc_say, plant_burn_kw, plant_automated, charbon_step), extrait entre ses
     repères et exécuté avec un moteur de bouchons : tâche urgente avant le vide, journal par épisode, projet d'alimentation demandé
     une fois, rang, refus et pause, centrale automatisée.
  3. Chaîne statique : plan_project → plan_alim → Build.plan_drills → plan_finish ; pulse_team → charbon_step ; Build.burn_rate compte
     les chaudières nourries à la main.
  Usage, depuis la racine du mod :   lua5.2 tests/charbon_centrale_test.lua
]]
package.path = "./?.lua;" .. package.path
local Cc0 = require("shared.team.charbon_centrale")
local M = require("shared.team.modules")
local P = require("shared.team.plan")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
end
local function section(name) if not quiet then print("== " .. name) end end

local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end

local BOILER_KW = M.BASE.boiler.burner_kw
local RATE1 = BOILER_KW / M.COAL_J -- 0,45/s

--- Batterie sur un module Cc (le vrai ou un mutant).
local function battery(Cc)
  section("1. Consommation")
  check(math.abs(Cc.rate(BOILER_KW, M.COAL_J) - 0.45) < 1e-9, "une chaudiere a pleine charge : 0,45 charbon/s (donnees)")
  check(Cc.rate(0, M.COAL_J) == 0 and Cc.rate(nil, M.COAL_J) == 0 and Cc.rate(1800, 0) == 0, "rien a bruler : 0")

  section("2. Seuil d'avance et cible")
  local r = Cc.refill(400, RATE1, 1000, 1600)
  check(r.low == 108 and not r.due, "1 chaudiere : seuil 0,45 x 240 s = 108 ; 400 au coffre, rien a faire")
  check(r.target == 540, "1 chaudiere : cible 0,45 x 1200 s = 540")
  r = Cc.refill(107, RATE1, 1000, 1600)
  check(r.due and r.count == 540 - 107 and r.prio >= 90, "107 < 108 : tache URGENTE (prio >= 90), porter jusqu'a la cible")
  check(r.prio == Cc.PRIO and Cc.PRIO >= 90, "priorite d'urgence (O.URGENT_PRIO = 90)")
  r = Cc.refill(108, RATE1, 1000, 1600)
  check(not r.due, "exactement au seuil : pas encore")
  r = Cc.refill(59, RATE1, 1000, 1600)
  check(r.due, "sous l'ancien seuil (60) : toujours du")
  r = Cc.refill(100, RATE1, 1000, 1600)
  check(r.due, "100 charbons (3,7 min a pleine charge) : du AVANT le vide (l'ancien seuil 60 attendait)")
  r = Cc.refill(0, 0, 1000, 1600)
  check(r.low == Cc.MIN_LOW and r.target == Cc.MIN_FILL and r.due, "consommation inconnue : l'ancien seuil et l'ancienne charge")
  r = Cc.refill(0, 2 * RATE1, 1000, 1600)
  check(r.low == 216 and r.target == 1080 and r.count == 1000, "2 chaudieres : seuil 216, cible 1080, borne par le coffre du QG (1000)")
  r = Cc.refill(0, 4 * RATE1, 5000, 1600)
  check(r.target == 1440 and r.low == 432, "4 chaudieres : cible bornee a 90 % du coffre (1440)")
  r = Cc.refill(0, 4 * RATE1, 5000, 400)
  check(r.target == 360 and r.low == 180 and r.low < r.target, "petit coffre : seuil sous la cible (moitie)")
  r = Cc.refill(50, RATE1, 0, 1600)
  check(not r.due and r.short and r.why == "coffre du QG sans charbon", "coffre du QG vide : pas de tache, cause rendue")
  r = Cc.refill(50, RATE1, nil, 1600)
  check(not r.due and r.short, "stock inconnu : comme vide")
  r = Cc.refill(50, RATE1, 3, 1600)
  check(r.due and r.count == 3, "3 charbons au QG : on porte ce qu'il y a")
  r = Cc.refill(50, RATE1, 1000, nil)
  check(r.due and r.target == 540, "place du coffre inconnue : cible non bornee")

  section("3. Automatisee ?")
  check(Cc.automated({ "centrale", "foreuses" }, nil), "foreuses au plan de la centrale : automatisee")
  check(Cc.automated({ "centrale" }, "fini"), "projet d'alimentation fini : automatisee")
  check(not Cc.automated({ "centrale" }, "chantier"), "projet d'alimentation rouvert (pieces detruites) : non")
  check(not Cc.automated({ "centrale" }, nil), "rien : nourrie a la main")
  check(not Cc.automated(nil, "reserve"), "projet en reserve : non")

  section("4. Projet d'alimentation")
  local base = { automated = false, quai = true, alim_open = false, other_open = false, tick = 1000 }
  check(Cc.want_alim({}, base) == true, "centrale finie nourrie a la main : projet demande")
  local c = copy(base); c.automated = true
  check(not Cc.want_alim({}, c), "deja automatisee : rien")
  c = copy(base); c.quai = false
  check(not Cc.want_alim({}, c), "pas de coffre : rien")
  c = copy(base); c.alim_open = true
  check(not Cc.want_alim({}, c), "son projet en cours : rien")
  c = copy(base); c.other_open = true
  check(not Cc.want_alim({}, c), "un seul projet d'alimentation ouvert par equipe")
  c = copy(base); c.off = true
  check(not Cc.want_alim({}, c), "reglage de banc : coupe")
  local st = {}
  Cc.refused(st, 1000)
  check(st.tries == 1 and st.retry_at == 1000 + Cc.RETRY_TICKS and Cc.RETRY_TICKS >= 3600 and st.alim == nil,
    "refus : compte, pause d'au moins une minute, projet oublie")
  c = copy(base); c.tick = 1000 + Cc.RETRY_TICKS - 1
  check(not Cc.want_alim(st, c), "pendant la pause : rien")
  c.tick = 1000 + Cc.RETRY_TICKS
  check(Cc.want_alim(st, c) == true, "apres la pause : nouvel essai")
  for _ = 2, Cc.MAX_TRIES do Cc.refused(st, 1000) end
  check(st.tries == Cc.MAX_TRIES and st.retry_at == 1000 + Cc.LONG_RETRY_TICKS and Cc.LONG_RETRY_TICKS > Cc.RETRY_TICKS,
    "plafond de refus atteint : pause LONGUE")
  check(Cc.LONG_RETRY_TICKS <= 216000, "pause longue d'une heure au plus (jamais d'abandon de fait)")
  c.tick = 1000 + Cc.LONG_RETRY_TICKS - 1
  check(not Cc.want_alim(st, c), "pendant la pause longue : rien")
  c.tick = 1000 + Cc.LONG_RETRY_TICKS
  check(Cc.want_alim(st, c) == true, "apres la pause longue : nouvel essai (jamais d'abandon definitif, « on automatise tout »)")
  Cc.refused(st, 5000)
  check(st.retry_at == 5000 + Cc.LONG_RETRY_TICKS, "au-dela du plafond : toujours la pause longue")

  section("5. Arrivees du tapis a la tete")
  -- tete en (10, 5), sens ouest (6) : derriere = est (11, 5) vers l'ouest ; gauche de l'ouest = sud
  local d = P.W
  local lx, ly = P.left_of(d)
  local arr = Cc.arrivals(10, 5, P.DV[d], { lx, ly }, d, P.dir_of)
  check(#arr == 3 and arr[1].x == 11 and arr[1].y == 5 and arr[1].dir == P.W, "1re arrivee : derriere la tete, tout droit")
  check(arr[2].x == 10 + lx and arr[2].y == 5 + ly and P.DV[arr[2].dir][1] == -lx and P.DV[arr[2].dir][2] == -ly,
    "2e : par la gauche, tournee vers la tete")
  check(arr[3].x == 10 - lx and arr[3].y == 5 - ly and P.DV[arr[3].dir][1] == lx and P.DV[arr[3].dir][2] == ly,
    "3e : par la droite, tournee vers la tete")
end

battery(Cc0)

---------------------------------------------------------------------------------------------------
-- 2. Le vrai code de build.lua, moteur de bouchons
---------------------------------------------------------------------------------------------------
section("6. build.lua : quai_tasks et charbon_step (code reel)")
local fh = assert(io.open("script/team/build.lua", "rb"))
local src = fh:read("*a")
fh:close()
local function between(a_mark, b_mark)
  local a = assert(src:find(a_mark, 1, true), "repere absent : " .. a_mark)
  local b = assert(src:find(b_mark, a, true), "repere absent : " .. b_mark)
  return src:sub(a, b - 1)
end
local chunk_src = between("--- Lot CHARBON-CENTRALE : boilers (nombre)", "--- Lot CHARBON-CENTRALE : plan du projet")
  .. between("--- Lot CHARBON-CENTRALE : journal du coffre", "-- Raccordement : fils")
  .. between("--- Lot CHARBON-CENTRALE : relevé des centrales finies", "local function pulse_team")

local W = { logs = {}, stock = 0, chests = {}, tick = 0, requests = {} }
local Build = { QUAI_LOW = 60, QUAI_FILL = 400, COLLECT_AT = 200 }
Build.request = function(f, spec)
  local b = f.build
  local id = b.next_id
  b.next_id = id + 1
  b.projects[id] = { id = id, spec = spec, state = "attente", ents = {}, parts = {}, quais = {}, outs = {}, prio = spec.prio }
  b.order[#b.order + 1] = id
  W.requests[#W.requests + 1] = { id = id, spec = spec }
  return id
end
local env = {
  Cc = Cc0, M = M, P = P, Build = Build,
  Sweep = require("shared.team.rebuild_sweep"), -- lot FUITES-PILE : « rouvert » = reconstruction (Sweep.rebuilding) ou murs, pas un agrandissement
  Stock = { count = function() return W.stock end },
  seg_passable = function() return function() return true end end,
  free_spot = function(_, _, x, y) return x, y end,
  defines = { inventory = { chest = 1 } },
  log = function(s) W.logs[#W.logs + 1] = s end,
}
env.game = setmetatable({}, { __index = function(_, k) if k == "tick" then return W.tick end end })
local chunk = assert(load(chunk_src .. "\nreturn { quai_tasks = quai_tasks, charbon_step = charbon_step, plant_automated = plant_automated, plant_burn_kw = plant_burn_kw }",
  "charbon_build", "t", setmetatable(env, { __index = _G })))
local X = chunk()

local function chest_at(n, cap)
  return { force = { name = "f1" },
    get_item_count = function() return W.chests[1] end,
    get_inventory = function() return { get_insertable_count = function() return (cap or 1600) - W.chests[1] end,
      get_item_count = function() return W.chests[1] end } end }
end
local surface = { find_entity = function(name, pos) if name == "iron-chest" and W.chests[1] then return chest_at() end return nil end }

local function team()
  local lat = P.lattice({ x = 0.5, y = 0.5 })
  local f = { key = "f1", force = "f1", build = { opts = {}, lat = lat, segs = {}, projects = {}, order = {}, next_id = 1, occ = {} } }
  local b = f.build
  local plant = { id = 1, spec = { gen = "steam", prio = 60 }, state = "fini", prio = 60, outs = {},
    parts = { { kind = "centrale" } },
    ents = { { name = "boiler", x = 5, y = 5 }, { name = "steam-engine", x = 5, y = 0 }, { name = M.BURNER_ARM or "burner-inserter", x = 4, y = 7 },
      { name = "transport-belt", x = 10.5, y = 5.5, dir = P.W, role = "tete" } },
    quais = { { x = 10.5, y = 4.5, item = "coal" } } }
  b.projects[1] = plant
  b.order[1] = 1
  b.next_id = 2
  return f, plant
end

do
  local f, plant = team()
  local n, kw = X.plant_burn_kw(plant)
  check(n == 1 and kw == BOILER_KW, "plant_burn_kw : 1 chaudiere, puissance des donnees")
  W.stock, W.chests[1] = 1000, 400
  local out = {}
  X.quai_tasks(f, plant, surface, out)
  check(#out == 0, "coffre a 400 : aucune tache")
  W.chests[1] = 100
  out = {}
  X.quai_tasks(f, plant, surface, out)
  check(#out == 1 and out[1].prio == Cc0.PRIO and out[1].kind == "carry" and out[1].no_rush == true,
    "coffre a 100 (sous 108) : tache URGENTE de portage, AVANT le vide (avant le lot : 100 >= 60, rien)")
  check(out[1] and out[1].items[1][1] == "coal" and out[1].items[1][2] == 440, "porter jusqu'a la cible 540 (440)")
  check(out[1] and out[1].key == "ia1d:1:q:1" and out[1].ia1d.mode == "fill", "meme cle et meme mode que le remplissage d'avant")
  check(#W.logs == 1 and W.logs[1]:find("[FO-CHARBON-CENTRALE]", 1, true) and W.logs[1]:find("URGENTE", 1, true), "journal : une ligne")
  X.quai_tasks(f, plant, surface, {})
  check(#W.logs == 1, "meme episode : pas de deuxieme ligne")
  W.chests[1] = 500
  X.quai_tasks(f, plant, surface, {})
  W.chests[1] = 90
  X.quai_tasks(f, plant, surface, {})
  check(#W.logs == 2, "nouvel episode apres un remplissage : nouvelle ligne")
  W.stock = 0
  out = {}
  X.quai_tasks(f, plant, surface, out)
  check(#out == 0 and #W.logs == 3 and W.logs[3]:find("SANS charbon", 1, true), "coffre du QG vide : pas de tache, la cause au journal")
  -- un module qui n'est pas une centrale garde la règle d'avant
  local mod = { id = 7, spec = { gen = "smelter" }, state = "fini", prio = 55, ents = {}, parts = {}, outs = {}, quais = { { x = 1.5, y = 1.5, item = "iron-ore" } } }
  W.stock, W.chests[1] = 1000, 100
  out = {}
  X.quai_tasks(f, mod, surface, out)
  check(#out == 0, "autre module, 100 au coffre : rien (ancienne regle, seuil 60)")
  W.chests[1] = 59
  out = {}
  X.quai_tasks(f, mod, surface, out)
  check(#out == 1 and out[1].prio == 58 and out[1].items[1][2] == 341, "autre module sous 60 : ancienne tache (prio + 3, charge 400)")
end

do
  W.logs, W.requests = {}, {}
  local f, plant = team()
  local b = f.build
  -- un projet en attente, et un rouvert
  b.projects[2] = { id = 2, spec = { gen = "smelter" }, state = "attente", ents = {}, parts = {}, quais = {}, outs = {} }
  b.projects[3] = { id = 3, spec = { gen = "smelter" }, state = "chantier", reopened = true, ents = {}, parts = {}, quais = {}, outs = {} }
  b.order = { 1, 2, 3 }
  b.next_id = 4
  W.tick = 100
  X.charbon_step(f, W.tick)
  check(#W.requests == 1 and W.requests[1].spec.alim == 1 and W.requests[1].spec.prio == Cc0.PROJECT_PRIO, "centrale nourrie a la main : projet d'alimentation demande")
  check(b.order[1] == 3 and b.order[2] == 4 and b.order[3] == 1 and b.order[4] == 2,
    "prioritaire : apres le projet rouvert, devant les projets en attente (" .. table.concat(b.order, ",") .. ")")
  check(b.charbon[1].alim == 4, "memoire de la centrale : son projet")
  check(W.logs[#W.logs]:find("[FO-CHARBON-CENTRALE]", 1, true) and W.logs[#W.logs]:find("demande", 1, true), "journal de la demande")
  W.tick = W.tick + Cc0.EVERY
  X.charbon_step(f, W.tick)
  check(#W.requests == 1, "projet en cours : pas de deuxieme demande")
  -- burn : nourrie a la main tant que le projet n'est pas fini
  check(not X.plant_automated(b, plant), "projet d'alimentation en attente : pas automatisee")
  b.projects[4].state, b.projects[4].reason = "refuse", "foreuses : trop loin"
  W.tick = W.tick + Cc0.EVERY
  X.charbon_step(f, W.tick)
  check(b.charbon[1].tries == 1 and #W.requests == 1, "refus : compte, pas de nouvelle demande pendant la pause")
  check(W.logs[#W.logs]:find("refus 1 (pause courte", 1, true) ~= nil, "journal du refus")
  W.tick = W.tick + Cc0.RETRY_TICKS
  X.charbon_step(f, W.tick)
  check(#W.requests == 2 and b.charbon[1].alim == 5, "apres la pause : nouvel essai")
  b.projects[5].state = "fini"
  W.tick = W.tick + Cc0.EVERY
  local nlog = #W.logs
  X.charbon_step(f, W.tick)
  check(X.plant_automated(b, plant), "projet fini : centrale automatisee")
  check(#W.logs == nlog + 1 and W.logs[#W.logs]:find("nourrie par des foreuses", 1, true), "journal : centrale automatisee (une fois)")
  W.tick = W.tick + Cc0.EVERY
  X.charbon_step(f, W.tick)
  check(#W.logs == nlog + 1 and #W.requests == 2, "automatisee : plus rien")
  b.projects[5].state = "chantier" -- foreuses détruites, projet rouvert par la reconstruction
  W.tick = W.tick + Cc0.EVERY
  X.charbon_step(f, W.tick)
  check(not X.plant_automated(b, plant) and #W.requests == 2, "projet rouvert : pas automatisee, pas de doublon (la reconstruction le refait)")
  -- réglage de banc
  local f2 = team()
  f2.build.opts.no_alim = true
  W.requests = {}
  X.charbon_step(f2, 1)
  check(#W.requests == 0, "no_alim : rien")
end

---------------------------------------------------------------------------------------------------
-- 3. Chaîne statique
---------------------------------------------------------------------------------------------------
section("7. Chaine dans build.lua")
check(src:find("if spec.alim then return plan_alim(f, surface, p) end", 1, true) ~= nil, "plan_project aiguille le projet d'alimentation")
check(src:find("Build.plan_drills(f, surface, p, fuel, rate, a, nil)", 1, true) ~= nil, "plan_alim reutilise le plan des foreuses")
check(src:find("return plan_finish(f, surface, p, masks, false)", 1, true) ~= nil and src:find("return plan_finish(f, surface, p, main.masks, is_plant)", 1, true) ~= nil,
  "fin de plan commune (poteaux, appuis, obstacles)")
check(src:find("charbon_step(f, tick)\nend", 1, true) ~= nil, "pulse_team appelle charbon_step")
check(src:find("if hand and sp and sp.water and sp.burner_kw then", 1, true) ~= nil, "Build.burn_rate compte les chaudieres nourries a la main")
check(src:find("local r = Cc.refill(", 1, true) ~= nil, "quai_tasks lit la regle de remplissage")
check(src:find("name == \"no_alim\"", 1, true) ~= nil, "reglage de banc no_alim")
check(src:find("if p.state == \"fini\" or p.state == \"chantier\" or (p.reopened and p.state ~= \"refuse\" and is_plant_project(p)) then\n        quai_tasks(f, p, surface, tasks)", 1, true) ~= nil,
  "Build.think : le coffre d'une centrale ROUVERTE (reserve, fantomes...) se remplit aussi")

---------------------------------------------------------------------------------------------------
-- Mutants
---------------------------------------------------------------------------------------------------
section("8. Mutants")
local function mutant(label, edit)
  local Cm = dofile("shared/team/charbon_centrale.lua") -- module neuf : ses fonctions lisent SES constantes
  edit(Cm)
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(battery, Cm)
  quiet = false
  local caught = failures > f0 or not ok
  passes, failures = p0, f0
  check(caught, "mutant refuse : " .. label)
end
mutant("seuil = ancien seuil fixe (60)", function(C) C.LEAD_S = 0 end)
mutant("priorite non urgente", function(C) C.PRIO = 63 end)
mutant("tache meme sans charbon au QG", function(C)
  local old = C.refill
  C.refill = function(n, rate, have, cap) return old(n, rate, (have and have > 0) and have or 1000, cap) end
end)
mutant("cible non bornee par le coffre", function(C) C.CAP_SHARE = 100 end)
mutant("projet rouvert compte comme automatise", function(C) C.automated = function() return true end end)
mutant("plusieurs projets ouverts", function(C)
  local old = C.want_alim
  C.want_alim = function(st, c) local c2 = copy(c); c2.other_open = false; return old(st, c2) end
end)
mutant("pas de pause apres un refus", function(C) C.RETRY_TICKS = 0 end)
mutant("abandon definitif apres le plafond", function(C) C.LONG_RETRY_TICKS = 10 ^ 12 end)
mutant("arrivee unique", function(C) local old = C.arrivals; C.arrivals = function(...) local a = old(...); return { a[1] } end end)

print(string.format("[CHARBON-CENTRALE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
