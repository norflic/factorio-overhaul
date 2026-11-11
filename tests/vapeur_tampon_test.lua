--[[
  Lot TV-VAPEUR, point V36 (remplissage de charbon de la centrale aussi sur le TAMPON de vapeur) :
    V1. Règle pure shared/team/vapeur_tampon.lua : taux, hystérésis (V37), confort.
    V2. Cc.refill avec steam_low : dû au-dessus du seuil d'avance tant que le coffre est sous le confort de la cible ; sinon la règle d'avant
        (sans steam_low : octet pour octet).
    V3. Colle moteur script/team/vapeur_glue.lua (doublure des machines à vapeur) : lecture des boîtes, une lecture par Vt.EVERY, hystérésis,
        réglage, projet pas fini, journal.
    V4. Le VRAI quai_tasks de script/team/build.lua (extrait entre ses repères) : tâche urgente de portage déclenchée par la vapeur basse.
    Mutants (texte de la source changé) : ils DOIVENT tous être vus.
  Usage, depuis la racine du mod :   lua5.2 tests/vapeur_tampon_test.lua
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end
local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end
local function mutated(path, subs)
  local src = read(path)
  for _, x in ipairs(subs) do
    local a, b = src:find(x[1], 1, true)
    assert(a, "mutant : texte absent de " .. path .. " : " .. x[1])
    assert(not src:find(x[1], b + 1, true), "mutant : texte present plusieurs fois : " .. x[1])
    src = src:sub(1, a - 1) .. x[2] .. src:sub(b + 1)
  end
  return src
end
local function load_src(src, name, env) return assert(load(src, "=" .. name, "t", env or _G))() end

local Vt = require("shared.team.vapeur_tampon")
local Cc = require("shared.team.charbon_centrale")
local M = require("shared.team.modules")
local P = require("shared.team.plan")
local RATE1 = M.BASE.boiler.burner_kw / M.COAL_J -- 0,45/s

------------------------------------------------------------------------------------------------
print("== V1. Regle pure")
do
  check(Vt.ratio({ { amount = 100, cap = 200 }, { amount = 0, cap = 200 } }) == 0.25, "taux = vapeur totale / capacite totale (100 sur 400)")
  check(Vt.ratio({}) == nil and Vt.ratio(nil) == nil and Vt.ratio({ { amount = 5, cap = 0 } }) == nil, "rien de lu ou capacite nulle : nil")
  check(Vt.ratio({ { amount = 999, cap = 200 } }) == 1, "vapeur au-dela de la capacite : bornee a 1")
  check(Vt.low(false, 0.29) == true and Vt.low(false, 0.30) == false, "on entre dans l'etat bas sous 30 %")
  check(Vt.low(true, 0.59) == true and Vt.low(true, 0.60) == false, "on en sort a 60 % (hysteresis)")
  check(Vt.low(false, 0.45) == false and Vt.low(true, 0.45) == true, "entre 30 et 60 % : l'etat precedent est garde")
  check(Vt.low(false, nil) == false and Vt.low(true, nil) == false, "rien de lu : pas bas (garde fermee)")
  check(Vt.comfort(540) == 405, "confort de la cible 540 : 405")
  check(Vt.COMFORT == Cc.STEAM_COMFORT, "le confort de Vt est celui de Cc")
  local parts = {}
  for i = 1, 30 do parts[i] = { amount = (i <= Vt.MAX_READ) and 0 or 200, cap = 200 } end
  check(Vt.ratio(parts) == 0, "au plus Vt.MAX_READ machines lues (les premieres)")
end

------------------------------------------------------------------------------------------------
print("== V2. Cc.refill")
local function battery(C)
  local out = {}
  local r = C.refill(300, RATE1, 1000, 1600, true)
  out[#out + 1] = r.due and r.steam == true and r.count == 540 - 300 and r.prio == C.PRIO and r.why == "tampon de vapeur bas"
  r = C.refill(300, RATE1, 1000, 1600, false)
  out[#out + 1] = not r.due and r.why == "au-dessus du seuil"
  r = C.refill(300, RATE1, 1000, 1600)
  out[#out + 1] = not r.due
  r = C.refill(405, RATE1, 1000, 1600, true)
  out[#out + 1] = not r.due and r.why == "au-dessus du seuil"
  r = C.refill(404, RATE1, 1000, 1600, true)
  out[#out + 1] = r.due and r.count == 136
  r = C.refill(107, RATE1, 1000, 1600, true)
  out[#out + 1] = r.due and r.steam == nil and r.why == "sous le seuil"
  r = C.refill(300, RATE1, 0, 1600, true)
  out[#out + 1] = not r.due and r.short == true
  r = C.refill(300, RATE1, 50, 1600, true)
  out[#out + 1] = r.due and r.count == 50
  r = C.refill(250, 4 * RATE1, 5000, 400, true)
  out[#out + 1] = r.target == 360 and r.due and r.count == 110
  return out
end
do
  local o = battery(Cc)
  local names = { "tampon bas, coffre a 300 (>108, <405) : tache urgente", "tampon normal : rien (regle d'avant)", "sans parametre : rien (regle d'avant)",
    "coffre au confort exact (405) : rien", "coffre a 404 : du", "sous le seuil d'avance : meme tache qu'avant (sans marque vapeur)",
    "coffre du QG vide : pas de tache, cause rendue", "3 charbons... 50 au QG : on porte ce qu'il y a", "petit coffre : cible 360, confort respecte" }
  for i, n in ipairs(names) do check(o[i] == true, "V2 : " .. n) end
  -- sans steam_low : la regle d'avant, case par case
  local same = true
  for n = 0, 700, 7 do
    local a, b = Cc.refill(n, RATE1, 1000, 1600), Cc.refill(n, RATE1, 1000, 1600, false)
    if a.due ~= b.due or a.count ~= b.count or a.why ~= b.why then same = false end
  end
  check(same, "V2 : steam_low faux ou absent : memes reponses sur 0..700 charbons")
end

------------------------------------------------------------------------------------------------
print("== V3. Colle moteur")
local STATE = { tick = 0, reads = 0, engines = {}, setting = true }
_G.settings = { global = { ["fo-war-vapeur-tampon"] = { value = true } } }
_G.game = setmetatable({}, { __index = function(_, k) if k == "tick" then return STATE.tick end end })
local LOGS = {}
_G.log = function(s) LOGS[#LOGS + 1] = s end
local function engine(amount, cap, force)
  return { valid = true, force = { name = force or "f1" },
    fluidbox = setmetatable({ get_capacity = function() return cap end }, { __index = function(_, i) if i == 1 then return { name = "steam", amount = amount } end end }) }
end
local surface = { find_entity = function(name, pos)
  STATE.reads = STATE.reads + 1
  return STATE.engines[pos[1] .. "," .. pos[2]]
end }
local function plant()
  return { id = 1, state = "fini", ents = {
    { name = "boiler", x = 5, y = 5 }, { name = "steam-engine", x = 5, y = 0 }, { name = "steam-engine", x = 5, y = -6 },
    { name = "transport-belt", x = 10.5, y = 5.5 } } }
end
local function team() return { key = "f1", force = "f1", build = {} } end
local function fresh_glue(subs)
  package.loaded["script.team.vapeur_glue"] = nil
  LOGS = {}
  if subs then return load_src(mutated("script/team/vapeur_glue.lua", subs), "vapeur_glue", setmetatable({ require = require }, { __index = _G })) end
  return require("script.team.vapeur_glue")
end
do
  local Vg = fresh_glue()
  STATE.engines = { ["5,0"] = engine(20, 200), ["5,-6"] = engine(20, 200) } -- 10 %
  local f, p = team(), plant()
  STATE.tick = 1000
  check(Vg.low(f, p, surface) == true, "V3 : machines a 10 % : tampon BAS")
  check(STATE.reads == 2, "V3 : 2 machines a vapeur lues (ni chaudiere ni tapis)")
  check(#LOGS == 1 and LOGS[1]:find("[FO-VAPEUR-TAMPON]", 1, true) and LOGS[1]:find("BAS", 1, true), "V3 : journal [FO-VAPEUR-TAMPON] BAS")
  STATE.reads = 0
  STATE.tick = 1100
  STATE.engines["5,0"], STATE.engines["5,-6"] = engine(200, 200), engine(200, 200)
  check(Vg.low(f, p, surface) == true and STATE.reads == 0, "V3 : 100 ticks plus tard : etat garde, aucune relecture (Vt.EVERY = 300)")
  STATE.tick = 1300
  check(Vg.low(f, p, surface) == false and STATE.reads == 2, "V3 : 300 ticks plus tard, machines pleines : relu, tampon revenu")
  check(#LOGS == 2 and LOGS[2]:find("revenu", 1, true), "V3 : journal 'revenu'")
  STATE.engines["5,0"], STATE.engines["5,-6"] = engine(100, 200), engine(100, 200) -- 50 % : entre les seuils
  STATE.tick = 1600
  check(Vg.low(f, p, surface) == false, "V3 : 50 %, etait normal : reste normal")
  STATE.engines["5,0"], STATE.engines["5,-6"] = engine(20, 200), engine(20, 200)
  STATE.tick = 1900
  check(Vg.low(f, p, surface) == true, "V3 : retombe a 10 % : bas")
  STATE.engines["5,0"], STATE.engines["5,-6"] = engine(100, 200), engine(100, 200)
  STATE.tick = 2200
  check(Vg.low(f, p, surface) == true, "V3 : a 50 %, etait bas : reste bas (hysteresis)")
  _G.settings.global["fo-war-vapeur-tampon"].value = false
  STATE.tick = 3000
  check(Vg.low(f, p, surface) == false, "V3 : reglage eteint : jamais bas")
  _G.settings.global["fo-war-vapeur-tampon"].value = true
  -- projet pas fini, machines absentes, machines d'une autre force
  local f2, p2 = team(), plant()
  p2.state = "chantier"
  STATE.tick = 4000
  check(Vg.low(f2, p2, surface) == false, "V3 : projet pas fini : faux")
  STATE.engines = {}
  p2.state = "fini"
  check(Vg.low(f2, p2, surface) == false, "V3 : aucune machine posee : faux (garde fermee)")
  STATE.engines = { ["5,0"] = engine(0, 200, "autre"), ["5,-6"] = engine(0, 200, "autre") }
  f2.build.charbon[1].steam_at = nil
  check(Vg.low(f2, p2, surface) == false, "V3 : machines d'une autre force : ignorees")
  -- une seule machine posee sur deux : lue seule
  STATE.engines = { ["5,0"] = engine(10, 200) }
  f2.build.charbon[1].steam_at = nil
  check(Vg.low(f2, p2, surface) == true, "V3 : une machine posee sur deux, a 5 % : bas")
end

------------------------------------------------------------------------------------------------
print("== V4. quai_tasks (code reel)")
local build = read("script/team/build.lua")
local function between(a_mark, b_mark)
  local a = assert(build:find(a_mark, 1, true), "repere absent : " .. a_mark)
  local b = assert(build:find(b_mark, a, true), "repere absent : " .. b_mark)
  return build:sub(a, b - 1)
end
local chunk_src = between("--- Lot CHARBON-CENTRALE : boilers (nombre)", "--- Lot CHARBON-CENTRALE : plan du projet")
  .. between("--- Lot CHARBON-CENTRALE : journal du coffre", "-- Raccordement : fils")
local W = { logs = {}, stock = 1000, chest = 300 }
local function run_quai(Vg_stub, mod_src)
  local Build = { QUAI_LOW = 60, QUAI_FILL = 400, COLLECT_AT = 200, QUAI_CHEST = "iron-chest", Vg = Vg_stub } -- 0.6.67 : quai_tasks cherche Build.QUAI_CHEST
  Build.Quotas = require("script.team.quotas_glue")
  local env = {
    Cc = Cc, M = M, P = P, Build = Build,
    Stock = { count = function() return W.stock end },
    -- lot BRULEURS-A-SEC : reserve des bruleurs (burner_fuel_reserve) ; doublure sans bruleur : aucune reserve, le stock juste
    T = require("shared.team.config"),
    Outposts = { smelters = function() return {} end, burners = function() return {} end, fuel_levels = function(list) return list end }, -- lot CHAUDIERES
    Sante = { tasks = function() end },
    seg_passable = function() return function() return true end end,
    free_spot = function(_, _, x, y) return x, y end,
    defines = { inventory = { chest = 1 } },
    log = function(s) W.logs[#W.logs + 1] = s end,
    game = _G.game,
  }
  local src = mod_src or chunk_src
  local chunk = assert(load(src .. "\nreturn { quai_tasks = quai_tasks }", "quai", "t", setmetatable(env, { __index = _G })))
  local X = chunk()
  local chest = { force = { name = "f1" }, get_item_count = function() return W.chest end,
    get_inventory = function() return { get_insertable_count = function() return 1600 - W.chest end, get_item_count = function() return W.chest end } end }
  local surf = { find_entity = function(name) if name == "iron-chest" then return chest end return nil end }
  local lat = P.lattice({ x = 0.5, y = 0.5 })
  local f = { key = "f1", force = "f1", outposts = {}, build = { opts = {}, lat = lat, segs = {}, projects = {}, order = {}, next_id = 1, occ = {} } }
  local pl = { id = 1, spec = { gen = "steam", prio = 60 }, state = "fini", prio = 60, outs = {}, parts = { { kind = "centrale" } },
    ents = { { name = "boiler", x = 5, y = 5 }, { name = "steam-engine", x = 5, y = 0 } },
    quais = { { x = 10.5, y = 4.5, item = "coal" } } }
  f.build.projects[1], f.build.order[1] = pl, 1
  local out = {}
  X.quai_tasks(f, pl, surf, out)
  return out
end
do
  W.chest, W.logs = 300, {}
  local out = run_quai({ low = function() return false end })
  check(#out == 0, "V4 : coffre a 300 (sous le confort 405, au-dessus du seuil 108), tampon normal : aucune tache")
  out = run_quai({ low = function() return true end })
  check(#out == 1 and out[1].prio == Cc.PRIO and out[1].kind == "carry" and out[1].no_rush == true and out[1].items[1][2] == 240,
    "V4 : meme coffre, tampon BAS : tache URGENTE de portage jusqu'a la cible (240)")
  check(#W.logs == 1 and W.logs[1]:find("tampon de vapeur BAS", 1, true), "V4 : journal [FO-CHARBON-CENTRALE] dit que c'est la vapeur")
  W.chest = 500
  out = run_quai({ low = function() return true end })
  check(#out == 0, "V4 : coffre a 500 (au-dessus du confort), tampon BAS : rien (le manque ne vient pas du charbon)")
  W.chest = 300
  out = run_quai(nil)
  check(#out == 0, "V4 : sans Build.Vg (doublures des bancs hors jeu) : la regle d'avant")
  check(build:find("Build.Vg and Build.Vg.low(f, p, surface)", 1, true) ~= nil, "V4 : quai_tasks interroge Build.Vg.low")
  check(build:find('Build.Vg = require("script.team.vapeur_glue")', 1, true) ~= nil, "V4 : Build.Vg est la colle")
end

------------------------------------------------------------------------------------------------
print("== Mutants")
local function mutant(name, fn)
  local ok, caught = pcall(fn)
  if ok and caught then check(true, "mutant refuse : " .. name) else check(false, "mutant SURVIVANT : " .. name .. (ok and "" or " (" .. tostring(caught) .. ")")) end
end
local function cc_with(subs) return load_src(mutated("shared/team/charbon_centrale.lua", subs), "mut_cc") end
local function bat_differs(C) local o = battery(C) for _, v in ipairs(o) do if v ~= true then return true end end return false end
mutant("Cc : vapeur ignoree", function() return bat_differs(cc_with({ { "if steam_low then trigger =", "if false then trigger =" } })) end)
mutant("Cc : confort a 100 %", function() return bat_differs(cc_with({ { "Cc.STEAM_COMFORT = 0.75", "Cc.STEAM_COMFORT = 1.0" } })) end)
mutant("Cc : confort a 50 %", function() return bat_differs(cc_with({ { "Cc.STEAM_COMFORT = 0.75", "Cc.STEAM_COMFORT = 0.5" } })) end)
mutant("Cc : la vapeur bas rend la tache meme sans charbon au QG", function()
  return bat_differs(cc_with({ { "if not have or have <= 0 then", "if (not have or have <= 0) and not steam_low then" } })) end)
local function vt_with(subs) return load_src(mutated("shared/team/vapeur_tampon.lua", subs), "mut_vt") end
mutant("Vt : pas d'hysteresis", function() return vt_with({ { "if prev then return ratio < Vt.LOW_OUT end", "" } }).low(true, 0.45) ~= true end)
mutant("Vt : taux non borne", function() return vt_with({ { "math.max(0, math.min(p.amount or 0, p.cap))", "(p.amount or 0)" } }).ratio({ { amount = 999, cap = 200 } }) ~= 1 end)
mutant("Vt : rien de lu = bas", function() return vt_with({ { 'if type(ratio) ~= "number" then return false, "tampon illisible', 'if type(ratio) ~= "number" then return true, "tampon illisible' } }).low(false, nil) ~= false end)
mutant("colle : reglage ignore", function()
  local Vg = fresh_glue({ { "if ok and v == false then return false end", "" } })
  _G.settings.global["fo-war-vapeur-tampon"].value = false
  STATE.engines = { ["5,0"] = engine(0, 200), ["5,-6"] = engine(0, 200) }
  STATE.tick = 20000
  local r = Vg.low(team(), plant(), surface)
  _G.settings.global["fo-war-vapeur-tampon"].value = true
  return r == true
end)
mutant("colle : relit a chaque appel", function()
  local Vg = fresh_glue({ { "if st.steam_at and tick - st.steam_at < Vt.EVERY then return st.steam_low == true end", "" } })
  STATE.engines = { ["5,0"] = engine(0, 200), ["5,-6"] = engine(0, 200) }
  local f, p = team(), plant()
  STATE.tick = 30000
  Vg.low(f, p, surface)
  STATE.reads = 0
  STATE.tick = 30010
  Vg.low(f, p, surface)
  return STATE.reads ~= 0
end)
mutant("colle : projet pas fini lu quand meme", function()
  local Vg = fresh_glue({ { 'or p.state ~= "fini" then return false end', 'then return false end' } })
  STATE.engines = { ["5,0"] = engine(0, 200), ["5,-6"] = engine(0, 200) }
  local p = plant()
  p.state = "chantier"
  STATE.tick = 40000
  return Vg.low(team(), p, surface) == true
end)
mutant("build : le tampon n'est pas passe a Cc.refill", function()
  local src = chunk_src:gsub(", steam_low%)", ")", 1)
  local out = (function()
    W.chest, W.logs = 300, {}
    return run_quai({ low = function() return true end }, src)
  end)()
  return #out == 0
end)

package.loaded["script.team.vapeur_glue"] = nil
print(string.format("[VAPEUR-TAMPON] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
