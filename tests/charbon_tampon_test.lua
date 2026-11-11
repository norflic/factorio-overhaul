--[[
  Lot COMBUSTIBLE-CENTRALE (levier a, 8/11) : tampon de charbon des avant-postes pour une centrale dont le coffre du QG est sans charbon.
  1. Règle pure Cc.pick_buffer (shared/team/charbon_centrale.lua) et ses mutants.
  2. Exécutant script/team/charbon_tampon.lua (moteur de bouchons) : tampons lus, tâche à dépôt, journal par tampon.
  3. Le VRAI quai_tasks de script/team/build.lua (extrait comme tests/charbon_centrale_test.lua) : le tampon ne sert QUE quand le QG n'a pas
     de charbon ; sans tampon, l'ancien verdict « aucune tâche possible » ; chaîne statique worker.lua (programme à dépôt).
  Usage, depuis la racine du mod :   lua5.2 tests/charbon_tampon_test.lua
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local quiet = false
local function check(cond, msg) if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end end
local LOGS = {}
_G.log = function(s) LOGS[#LOGS + 1] = s end
_G.defines = { inventory = { chest = 1 } }
local T = require("shared.team.config")
local P = require("shared.team.plan")
local M = require("shared.team.modules")
local Cc0 = require("shared.team.charbon_centrale")

local function B(id, count, d2, x, y) return { id = id, count = count, d2 = d2, x = x or 0, y = y or 0 } end

local function battery(Cc)
  -- 1. règle pure
  local r = Cc.pick_buffer({ B("1/1", 500, 900), B("2/1", 300, 100) }, 200)
  check(r and r.buffer.id == "2/1" and r.count == 200, "deux tampons qui couvrent : le plus proche")
  r = Cc.pick_buffer({ B("1/1", 500, 900), B("2/1", 150, 100) }, 400)
  check(r and r.buffer.id == "1/1" and r.count == 400, "un seul couvre (500 - 60 >= 400) : celui-la, meme plus loin")
  r = Cc.pick_buffer({ B("1/1", 200, 100), B("2/1", 300, 900) }, 400)
  check(r and r.buffer.id == "2/1" and r.count == 240, "aucun ne couvre : le plus garni, ce qu'il peut donner (300 - 60)")
  check(Cc.pick_buffer({ B("1/1", 60 + Cc.BUFFER_MIN - 1, 1) }, 100) == nil, "reste utilisable sous le minimum : ecarte")
  r = Cc.pick_buffer({ B("1/1", 60 + Cc.BUFFER_MIN, 1) }, 100)
  check(r and r.count == Cc.BUFFER_MIN, "reste utilisable = minimum : pris, borne par ce qu'il reste")
  check(Cc.pick_buffer({ B("1/1", 500, 1) }, 0) == nil and Cc.pick_buffer({}, 100) == nil and Cc.pick_buffer(nil, 100) == nil, "besoin nul ou aucun tampon : rien")
  r = Cc.pick_buffer({ B("2/1", 500, 50, 5, 5), B("1/2", 500, 50, 9, 9), B("1/1", 500, 50, 9, 1) }, 100)
  check(r and r.buffer.id == "1/1", "egalite totale : l'id le plus petit (ordre total)")
  r = Cc.pick_buffer({ B("1/1", 500, 50, 9, 9), B("1/1", 500, 50, 9, 1) }, 100)
  check(r and r.buffer.y == 1, "meme id, meme distance : x puis y")
  local keep = Cc.pick_buffer({ B("1/1", 120, 1) }, 500, 100)
  check(keep == nil, "garde du tampon parametrable (120 - 100 < minimum)")
  local sorted_in = { B("b", 300, 10), B("a", 300, 10) }
  local r1 = Cc.pick_buffer(sorted_in, 100)
  local r2 = Cc.pick_buffer({ sorted_in[2], sorted_in[1] }, 100)
  check(r1 and r2 and r1.buffer.id == r2.buffer.id, "independant de l'ordre d'entree (deterministe)")
end
battery(Cc0)

local function mutant(label, edit)
  local Cm = dofile("shared/team/charbon_centrale.lua")
  edit(Cm)
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(battery, Cm)
  quiet = false
  local caught = failures > f0 or not ok
  passes, failures = p0, f0
  check(caught, "mutant refuse : " .. label)
end
mutant("tampon vide jusqu'au bout (pas de garde)", function(C) C.BUFFER_KEEP = 0 end)
mutant("minimum nul", function(C) C.BUFFER_MIN = 0 end)
mutant("le plus loin d'abord", function(C)
  local o = C.pick_buffer
  C.pick_buffer = function(bs, w, k)
    local t = {}
    for i, b in ipairs(bs or {}) do t[i] = { id = b.id, x = b.x, y = b.y, count = b.count, d2 = -(b.d2 or 0) } end
    return o(t, w, k)
  end
end)
mutant("couverture ignoree (le plus proche meme s'il ne couvre pas)", function(C)
  local o = C.pick_buffer
  C.pick_buffer = function(bs, w, k) local r = o(bs, math.huge, k) if r then r.count = math.min(w, r.count) end return r end
end)
mutant("porte plus que le besoin", function(C)
  local o = C.pick_buffer
  C.pick_buffer = function(bs, w, k) local r = o(bs, w, k) if r then r.count = r.count + 1 end return r end
end)
mutant("tampon meme si le besoin est nul", function(C)
  local o = C.pick_buffer
  C.pick_buffer = function(bs, w, k) return o(bs, (w and w > 0) and w or 1, k) end
end)

-- 2. exécutant
local Ct = require("script.team.charbon_tampon")
local function sink(name, x, y, n, valid)
  return { valid = valid ~= false, type = "container", name = name, position = { x = x, y = y },
    get_inventory = function() return { get_item_count = function() return n end } end }
end
local function ffrom(outposts)
  return { key = "f1", force = "f1", outposts = outposts, build = {} }
end
local plant = { id = 1 }
local q = { x = 10, y = 4, item = "coal" }
local OUT = T.outposts.coal
local f = ffrom({
  [3] = { id = 3, kind = "coal", sinks = { sink(OUT.sink, 50, 0, 300), sink(OUT.sink, 52, 0, 50), sink("wooden-chest", 51, 0, 900), sink(OUT.sink, 53, 0, 900, false) } },
  [1] = { id = 1, kind = "iron", sinks = { sink(T.outposts.iron.sink, 5, 5, 999) } },
})
local bs = Ct.buffers(f, "coal", 10, 4, OUT.sink)
check(#bs == 2 and bs[1].id == "3/1" and bs[2].id == "3/2", "tampons : seuls les coffres de sortie valides d'un avant-poste de charbon (" .. #bs .. ")")
check(bs[1].count == 300 and bs[1].d2 == 40 * 40 + 16, "compte et distance carree au coffre de la centrale")
local r0 = { short = true, target = 540, prio = 91 }
local t, why = Ct.relay(f, plant, nil, 1, q, 0, r0, 10.5, 5, OUT.sink, 3600)
check(t and t.key == "ia1d:1:q:1" and t.kind == "carry" and t.prio == 91 and t.no_rush and t.ia1d.mode == "fill", "tache de remplissage urgente, meme cle que celle du QG")
check(t and t.items == nil and t.depot_items[1][1] == "coal" and t.depot_items[1][2] == 240 and t.ia1d.depot.x == 50, "a depot : 300 - 60 charbons pris au tampon, rien au QG")
check(t and t.ia1d.ax == 10.5 and t.ia1d.ay == 5, "point d'appui du coffre de la centrale")
check(#LOGS == 1 and LOGS[1]:find("[FO-CHARBON-CENTRALE]", 1, true) and LOGS[1]:find("tampon de l'avant-poste 3/1", 1, true), "journal : une ligne")
Ct.relay(f, plant, nil, 1, q, 0, r0, 10.5, 5, OUT.sink, 3700)
check(#LOGS == 1, "meme tampon : pas de deuxieme ligne")
t, why = Ct.relay(f, plant, nil, 1, q, 0, { short = nil, target = 540 }, 1, 1, OUT.sink, 1)
check(t == nil and why == "le QG a du charbon", "le QG a du charbon : jamais de tampon")
t, why = Ct.relay(ffrom({}), plant, nil, 1, q, 0, r0, 1, 1, OUT.sink, 1)
check(t == nil, "aucun avant-poste : rien (l'ancien verdict)")
local build0 = f.build
f.build = { opts = { no_tampon = true } } -- interrupteur du banc temoin (remote fo-ia1d set_option no_tampon)
t, why = Ct.relay(f, plant, nil, 1, q, 0, r0, 10.5, 5, OUT.sink, 3600)
check(t == nil and why:find("regle coupee", 1, true), "regle coupee (temoin) : jamais de tampon")
f.build = build0

-- 3. le vrai quai_tasks
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
local W = { stock = 0, chest = 0 }
local Build = { QUAI_LOW = 60, QUAI_FILL = 400, COLLECT_AT = 200, QUAI_CHEST = "iron-chest", Ct = Ct,
  Quartiers = { DEPOT = OUT.sink }, Rempl = { adjust = function(_, _, _, _, _, _, _, _, r) return r end } }
Build.Quotas = require("script.team.quotas_glue")
local env = {
  Cc = Cc0, M = M, P = P, Build = Build,
  Sweep = require("shared.team.rebuild_sweep"),
  Stock = { count = function() return W.stock end },
  -- lot BRULEURS-A-SEC : reserve des bruleurs (burner_fuel_reserve) ; doublure sans bruleur : aucune reserve, le stock juste
  T = T,
  Outposts = { smelters = function() return {} end, burners = function() return {} end, fuel_levels = function(list) return list end }, -- lot CHAUDIERES : réserve des tournées dues (Cc.tour_reserve)
  Sante = { tasks = function() end },
  seg_passable = function() return function() return true end end,
  free_spot = function(_, _, x, y) return x, y end,
  defines = _G.defines,
  log = _G.log,
}
env.game = { tick = 7200 }
local chunk = assert(load(chunk_src .. "\nreturn { quai_tasks = quai_tasks }", "charbon_build", "t", setmetatable(env, { __index = _G })))
local X = chunk()
local chest = { force = { name = "f1" }, get_item_count = function() return W.chest end,
  get_inventory = function() return { get_insertable_count = function() return 1600 - W.chest end, get_item_count = function() return W.chest end } end }
local surface = { find_entity = function(name) if name == "iron-chest" then return chest end end }
local function team(outposts)
  local lat = P.lattice({ x = 0.5, y = 0.5 })
  local ft = { key = "f1", force = "f1", outposts = outposts, build = { opts = {}, lat = lat, segs = {}, projects = {}, order = { 1 }, next_id = 2, occ = {} } }
  local pl = { id = 1, spec = { gen = "steam", prio = 60 }, state = "fini", prio = 60, outs = {}, parts = { { kind = "centrale" } },
    ents = { { name = "boiler", x = 5, y = 5 }, { name = "steam-engine", x = 5, y = 0 }, { name = M.BURNER_ARM or "burner-inserter", x = 4, y = 7 },
      { name = "transport-belt", x = 10.5, y = 5.5, dir = P.W, role = "tete" } },
    quais = { { x = 10.5, y = 4.5, item = "coal" } } }
  ft.build.projects[1] = pl
  return ft, pl
end
do
  LOGS = {}
  local ft, pl = team({ [3] = { id = 3, kind = "coal", sinks = { sink(OUT.sink, 50, 0, 300) } } })
  W.stock, W.chest = 0, 40
  local out = {}
  X.quai_tasks(ft, pl, surface, out)
  check(#out == 1 and out[1].ia1d.depot and out[1].depot_items[1][2] == 240, "QG sans charbon, tampon garni : tache a depot (240)")
  check(#LOGS == 1 and LOGS[1]:find("tampon", 1, true) and not LOGS[1]:find("aucune tache possible", 1, true), "journal du tampon, pas « aucune tache possible »")
  W.stock = 1000
  out = {}
  X.quai_tasks(ft, pl, surface, out)
  check(#out == 1 and out[1].items and out[1].ia1d.depot == nil, "QG avec charbon : tache ordinaire du QG, aucun tampon")
  W.stock, W.chest = 0, 400
  out = {}
  X.quai_tasks(ft, pl, surface, out)
  check(#out == 0, "coffre au-dessus du seuil : rien, meme sans charbon au QG")
  LOGS = {}
  local ft2, pl2 = team({ [3] = { id = 3, kind = "coal", sinks = { sink(OUT.sink, 50, 0, 80) } } })
  W.stock, W.chest = 0, 40
  out = {}
  X.quai_tasks(ft2, pl2, surface, out)
  check(#out == 0 and #LOGS == 1 and LOGS[1]:find("SANS charbon", 1, true), "tampon sous la garde : ancien verdict, la cause au journal")
end

-- 3 bis. quai de COMBUSTIBLE d'une colonne de champ (lot COMBUSTIBLE-MIGRATION : q.flow = objets/s brûlés par ses fours) : seuil et cible à la consommation
do
  LOGS = {}
  local ft3 = team({})
  local pc = { id = 5, spec = { site = "champ", prio = 52 }, state = "fini", prio = 52, outs = {}, parts = {}, ents = {},
    quais = { { x = 10.5, y = 4.5, item = "coal", flow = 0.5 } } }
  ft3.build.projects[5] = pc
  W.stock, W.chest = 1000, 100
  local out = {}
  X.quai_tasks(ft3, pc, surface, out)
  check(#out == 1 and out[1].prio == Cc0.PRIO and out[1].no_rush and out[1].items and out[1].items[1][2] == 500, "quai a flow, 100 charbons < 120 (0,5/s x 240 s) : tache URGENTE, cible 600 (500 a porter)")
  W.chest = 130
  out = {}
  X.quai_tasks(ft3, pc, surface, out)
  check(#out == 0, "quai a flow au-dessus du seuil a la consommation : rien (l'ancien seuil fixe 60 ne l'aurait pas vu non plus)")
  local pc2 = { id = 6, spec = { site = "champ", prio = 52 }, state = "fini", prio = 52, outs = {}, parts = {}, ents = {},
    quais = { { x = 10.5, y = 4.5, item = "coal" } } }
  ft3.build.projects[6] = pc2
  W.chest = 100
  out = {}
  X.quai_tasks(ft3, pc2, surface, out)
  check(#out == 0, "quai SANS flow : l'ancienne regle (seuil fixe 60), 100 charbons : rien")
  W.chest = 50
  out = {}
  X.quai_tasks(ft3, pc2, surface, out)
  check(#out == 1 and out[1].prio == 55, "quai SANS flow sous le seuil fixe : priorite du projet + 3")
  local ft4, pc4 = team({ [3] = { id = 3, kind = "coal", sinks = { sink(OUT.sink, 50, 0, 300) } } })
  pc4.parts, pc4.quais, pc4.ents, pc4.id = {}, { { x = 10.5, y = 4.5, item = "coal", flow = 0.5 } }, {}, 5
  ft4.build.projects[5] = pc4
  W.stock, W.chest = 0, 40
  out = {}
  X.quai_tasks(ft4, pc4, surface, out)
  check(#out == 1 and out[1].ia1d.depot ~= nil, "quai a flow, QG sans charbon : le tampon d'un avant-poste de charbon le remplit")
end

-- chaîne statique : le programme à dépôt du travailleur
local wf = assert(io.open("script/team/worker.lua", "rb"))
local wsrc = wf:read("*a")
wf:close()
check(wsrc:find('elseif j.mode == "fill" and j.depot then', 1, true) ~= nil and wsrc:find('{ "take_depot", j.depot, task.depot_items }', 1, true) ~= nil,
  "worker.lua : un remplissage a depot passe par take_depot")
check(src:find('Build.Ct = require("script.team.charbon_tampon")', 1, true) ~= nil and src:find("Build.Ct.relay(", 1, true) ~= nil, "build.lua branche le tampon")

print(string.format("[CHARBON-TAMPON] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
