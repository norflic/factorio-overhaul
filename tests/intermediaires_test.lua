--[[
  Lot MAIN-ET-INTERMEDIAIRES (D09, D10 du DC, 28/10) : banc HORS JEU. Lancement : lua5.2 tests/intermediaires_test.lua (racine du mod).
    1. règle pure D09 (shared/team/intermediaires.lua) : seuil, hystérésis, survie, part de la main retirée, clés exemptées ;
    2. règle pure D10 : plafond proportionnel au besoin, demande, modules consommateurs, réserve, hystérésis ;
    3. runtime (script/team/intermediaires.lua) sur un monde simulé : tâches libres retirées, prises gardées, survie, force du joueur
       non lue, quais d'un module au plafond, décisions écrites au journal ;
    4. chaîne lue dans les sources (team.lua, poles.lua, automatisation.lua) ;
    5. mutants : chaque règle retirée change un fait observé.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")

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
local SRC_I = read_src("shared/team/intermediaires.lua")
local function load_I(text) return assert(load(text or SRC_I, "@shared/team/intermediaires.lua"))() end

local IRON, ORE = T.outposts.iron.product, T.outposts.iron.resource
local COAL = T.outposts.coal.resource

---------------------------------------------------------------------------------------------------
-- 1. D09 pur
---------------------------------------------------------------------------------------------------
local function d09_facts(I)
  local f = {}
  local th = I.MARGINAL * I.HAND_RATE
  f.below = I.hand_useless(false, { flow = th - 1 })
  f.at = I.hand_useless(false, { flow = th })
  f.keep_on = I.hand_useless(true, { flow = th * I.OFF })          -- hystérésis : gardé coupé à la moitié du seuil
  f.off_low = I.hand_useless(true, { flow = th * I.OFF - 1 })      -- repris sous la moitié
  f.survie = I.hand_useless(true, { flow = 10 * th, survie = true })
  -- 4 PNJ au minage à la main qui nourrissent les fours du QG : 120 plaques/min aux statistiques, aucune machine de plus
  f.hand_only = I.machine_flow({ stat = 4 * I.HAND_RATE, hand_miners = 4, per_ore = 1 })
  f.stat_mod = I.machine_flow({ stat = 50, modules = 200 })
  f.player = I.machine_flow({ stat = nil, modules = 0 })
  f.nan = I.machine_flow({ stat = 0 / 0, modules = 0 / 0 })
  f.ex1 = I.exempt_key("survie:mine:x:1")
  f.ex2 = I.exempt_key("crise:mine:1")
  f.ex3 = I.exempt_key("mine:x")
  f.ex4 = I.exempt_key(nil)
  return f
end

section("1. D09 : minage a la main d'une ressource que les machines sortent")
local I = load_I()
local F9 = d09_facts(I)
check(I.MARGINAL * I.HAND_RATE == 120, "seuil de coupure 120/min (4 PNJ a 30/min)")
check(F9.below == false, "sous le seuil : minage a la main permis")
check(F9.at == true, "au seuil : coupe")
check(F9.keep_on == true, "hysteresis : reste coupe a la moitie du seuil")
check(F9.off_low == false, "hysteresis : repris sous la moitie du seuil")
check(F9.survie == false, "mode survie : jamais coupe (exception du DC)")
check(F9.hand_only == 0, "les plaques du minerai mine a la main ne comptent pas comme machines")
check(F9.stat_mod == 200, "modules mesures pris quand ils depassent les statistiques")
check(F9.player == 0, "force non lue (joueur) et aucun module : debit nul")
check(F9.nan == 0, "valeurs invalides : debit nul")
check(F9.ex1 and F9.ex2 and not F9.ex3 and not F9.ex4, "cles exemptees : survie: et crise: seulement")
-- per_ore : un four qui prend 2 minerais par plaque ne retire que la moitié
check(I.machine_flow({ stat = 100, hand_miners = 2, per_ore = 0.5 }) == 20, "ressource extraite convertie en produit (per_ore), part de la main retiree avant")

---------------------------------------------------------------------------------------------------
-- 2. D10 pur
---------------------------------------------------------------------------------------------------
local function d10_facts(I)
  local f = {}
  f.min = I.cap({})
  f.cons = I.cap({ cons = 30 })
  f.cons2 = I.cap({ cons = 60 })
  f.full = I.cap({ cons = 30, demand = 25, feeders = 2, reserve = 100 })
  f.neg = I.cap({ cons = -5, demand = -3, feeders = -1, reserve = -9 })
  f.o1 = I.over(false, 99, 100)
  f.o2 = I.over(false, 100, 100)
  f.o3 = I.over(true, 51, 100)
  f.o4 = I.over(true, 50, 100)
  return f
end
section("2. D10 : plafond d'un intermediaire fabrique d'avance")
local F10 = d10_facts(I)
check(F10.min == I.MIN_STOCK, "sans besoin mesure : plancher " .. I.MIN_STOCK)
check(F10.cons == 300, "30/min consommes : 10 min d'avance = 300")
check(F10.cons2 == 2 * F10.cons, "plafond proportionnel a la consommation")
check(F10.full == 300 + 25 + 2 * I.FEED + 100, "demande, modules consommateurs et reserve ajoutes")
check(F10.neg == I.MIN_STOCK, "valeurs negatives ignorees")
check(F10.o1 == false and F10.o2 == true, "au plafond : plus nourri")
check(F10.o3 == true and F10.o4 == false, "hysteresis : nourri de nouveau a la moitie du plafond")

---------------------------------------------------------------------------------------------------
-- 3. Runtime sur un monde simulé
---------------------------------------------------------------------------------------------------
section("3. runtime : taches retirees avant le marche")
local LOG = {}
_G.log = function(s) LOG[#LOG + 1] = s end
_G.defines = { flow_precision_index = { one_minute = 1 } }
local FLOW = {}
local function force_named(name)
  return { item_production_statistics = { get_flow_count = function(a)
    assert(a.input == true and a.precision_index == 1)
    return (FLOW[name] or {})[a.name] or 0
  end } }
end
_G.game = { forces = setmetatable({}, { __index = function(_, k) return force_named(k) end }), tick = 0 }

local BOARDS, BRIEFS, STOCK, SURVIE = {}, {}, {}, {}
local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end
package.loaded["script.faction.state"] = { sorted_keys = sorted_keys, war = function() return { started = 0 } end }
package.loaded["script.team.board"] = {
  get = function(f) return BOARDS[f.key] end,
  drop_free = function(f, keep)
    local b, out, n = BOARDS[f.key], {}, 0
    for _, t in ipairs(b.list) do
      if not t.worker and not keep(t) then n = n + 1 else out[#out + 1] = t end
    end
    b.list = out
    return n
  end,
}
package.loaded["script.team.build"] = { brief = function(f, id) return BRIEFS[id] end }
package.loaded["script.team.stock"] = { count = function(f, item) return (STOCK[f.key] or {})[item] or 0 end }
package.loaded["script.team.survie"] = { on = function(f) return SURVIE[f.key] == true end }

local function load_rt(itext)
  package.loaded["shared.team.intermediaires"] = load_I(itext)
  package.loaded["script.team.intermediaires"] = nil
  local src = read_src("script/team/intermediaires.lua")
  return assert(load(src, "@script/team/intermediaires.lua"))()
end

local GEAR = "objet-intermediaire" -- clé opaque : la règle ne lit aucun nom
--- Monde : une faction et votre équipe ; fer des machines, un module d'intermédiaire nourri par un quai.
local function world(opts)
  opts = opts or {}
  LOG = {}
  FLOW = { fa = { [ORE] = opts.flow or 300 }, player = { [ORE] = 9999 } }
  STOCK = { fa = { [GEAR] = opts.gears or 0 }, player = { [GEAR] = opts.gears or 0 } }
  SURVIE = { fa = opts.survie or false }
  BRIEFS = { [7] = { quais = { IRON } }, [8] = { quais = { GEAR } } }
  local function mods()
    return { { id = 7, product = GEAR, state = "fini", rate_meas = 60 }, { id = 8, product = "pack", state = "fini", rate_meas = 5 },
      { id = 9, product = IRON, state = "fini", rate_meas = opts.mod_iron or 0 } }
  end
  local function tasks()
    return {
      { key = "mine:" .. ORE, kind = "mine", resource = ORE },
      { key = "ia3:mine:" .. ORE .. ":1", kind = "mine", resource = ORE },
      { key = "fond:mine:" .. ORE .. ":fer:1", kind = "mine", resource = ORE, fond = true },
      { key = "survie:mine:" .. ORE .. ":1", kind = "mine", resource = ORE },
      { key = "mine:" .. ORE .. ":pris", kind = "mine", resource = ORE, worker = 3 },
      { key = "mine:" .. COAL, kind = "mine", resource = COAL },
      { key = "ia1d:7:q:1", kind = "carry", ia1d = { pid = 7, mode = "fill", idx = 1 } },
      { key = "ia1d:7:o:1", kind = "carry", ia1d = { pid = 7, mode = "collect", idx = 1 } },
      { key = "ia1d:8:q:1", kind = "carry", ia1d = { pid = 8, mode = "fill", idx = 1 } },
      { key = "craft:x", kind = "craft", item = "x", uses = { { GEAR, opts.demand or 0 } } },
    }
  end
  local fa = { key = "fa", force = "fa", hq = { valid = true }, build = {}, team = { ia3e = { mods = mods() },
    ia3 = { bilan = { items = { [GEAR] = { c = opts.cons or 0 } } } } } }
  local pl = { key = "player", force = "player", is_player = true, hq = { valid = true }, build = {},
    team = { ia3e = { mods = mods() } } }
  BOARDS = { fa = { list = tasks() }, player = { list = tasks() } }
  return fa, pl
end
local function keys_of(f)
  local s = {}
  for _, t in ipairs(BOARDS[f.key].list) do s[t.key] = true end
  return s
end

local function rt_facts(itext)
  local Inter = load_rt(itext)
  local R = {}
  -- a) faction, fer des machines 300/min (1 PNJ au minage : 270 nets), intermédiaire sous le plafond
  local fa, pl = world({ flow = 300, gears = 50 })
  Inter.think(fa, 3600)
  local k = keys_of(fa)
  R.a_planner = k["mine:" .. ORE] == nil
  R.a_ia3 = k["ia3:mine:" .. ORE .. ":1"] == nil
  R.a_fond = k["fond:mine:" .. ORE .. ":fer:1"] == nil
  R.a_survie_key = k["survie:mine:" .. ORE .. ":1"] == true
  R.a_taken = k["mine:" .. ORE .. ":pris"] == true
  R.a_coal = k["mine:" .. COAL] == true
  R.a_fill = k["ia1d:7:q:1"] == true
  R.a_skip = Inter.mine_skip(fa)[ORE] == true
  R.a_log = false
  for _, l in ipairs(LOG) do if l:find("[FO-MAIN-FOURNIE] fa : minage a la main de " .. ORE .. " COUPE", 1, true) then R.a_log = true end end
  -- même équipe, pensée suivante, fer à 70/min : hystérésis (seuil de reprise 60)
  FLOW.fa[ORE] = 70 + I.HAND_RATE
  BOARDS.fa.list[#BOARDS.fa.list + 1] = { key = "mine:" .. ORE .. ":bis", kind = "mine", resource = ORE }
  Inter.think(fa, 7200)
  R.a_hyst = keys_of(fa)["mine:" .. ORE .. ":bis"] == nil
  FLOW.fa[ORE] = 40
  Inter.think(fa, 10800)
  R.a_resume = Inter.mine_skip(fa)[ORE] == nil
  -- b) votre équipe : la force « player » (9999/min, l'usine du joueur humain) n'est pas lue ; sans module de fer, rien n'est coupé
  Inter.think(pl, 3600)
  R.b_player = keys_of(pl)["mine:" .. ORE] == true
  -- … avec une fonderie (module fini) qui sort 150/min : coupé
  local _, pl2 = world({ mod_iron = 150 })
  Inter.think(pl2, 3600)
  R.b_player_mod = keys_of(pl2)["mine:" .. ORE] == nil
  -- c) mode survie : rien de coupé
  local fa3 = world({ flow = 300, survie = true })
  Inter.think(fa3, 3600)
  R.c_survie = keys_of(fa3)["mine:" .. ORE] == true and Inter.mine_skip(fa3)[ORE] == nil
  -- d) D10 : intermédiaire au-dessus du plafond (plancher 100 + 1 module consommateur 200 = 300) : quai d'entrée plus rempli
  local fa4 = world({ flow = 0, gears = 300 })
  Inter.think(fa4, 3600)
  local k4 = keys_of(fa4)
  R.d_fill = k4["ia1d:7:q:1"] == nil
  R.d_collect = k4["ia1d:7:o:1"] == true
  R.d_other = k4["ia1d:8:q:1"] == true
  R.d_over = Inter.over(fa4, GEAR)
  R.d_log = false
  for _, l in ipairs(LOG) do if l:find("[FO-INTERMEDIAIRE] fa : " .. GEAR .. " AU PLAFOND", 1, true) then R.d_log = true end end
  -- … 299 : sous le plafond
  local fa5 = world({ flow = 0, gears = 299 })
  Inter.think(fa5, 3600)
  R.d_under = keys_of(fa5)["ia1d:7:q:1"] == true
  -- … la consommation mesurée relève le plafond (40/min : 400 + 200 = 600)
  local fa6 = world({ flow = 0, gears = 500, cons = 40 })
  Inter.think(fa6, 3600)
  R.d_cons = keys_of(fa6)["ia1d:7:q:1"] == true
  -- … la demande des tâches ouvertes aussi (300 + 250)
  local fa7 = world({ flow = 0, gears = 500, demand = 250 })
  Inter.think(fa7, 3600)
  R.d_demand = keys_of(fa7)["ia1d:7:q:1"] == true
  -- e) bascule éteinte : rien ne change
  Inter.ENABLED = false
  local fa8 = world({ flow = 300, gears = 9999 })
  Inter.think(fa8, 3600)
  R.e_off = #BOARDS.fa.list == 10 and Inter.over(fa8, GEAR) == false and next(Inter.mine_skip(fa8)) == nil
  -- f) déterminisme : deux passages identiques, même journal
  local function run()
    local Inter2 = load_rt(itext)
    local g = world({ flow = 300, gears = 400 })
    Inter2.think(g, 3600)
    return table.concat(LOG, "\n") .. "|" .. table.concat(sorted_keys(keys_of(g)), ",")
  end
  R.f_det = run() == run()
  return R
end

local R = rt_facts()
check(R.a_planner and R.a_ia3 and R.a_fond, "faction, fer 270/min nets : minage a la main du minerai retire (planificateur, cerveau, renfort de fer)")
check(R.a_survie_key, "tache de survie gardee")
check(R.a_taken, "tache deja prise gardee (va a son terme)")
check(R.a_coal, "autre ressource sans machine : gardee")
check(R.a_fill, "intermediaire sous le plafond : quai rempli")
check(R.a_skip, "Inter.mine_skip publie la ressource coupee (lue par poles.lua)")
check(R.a_log, "journal [FO-MAIN-FOURNIE] a la coupure")
check(R.a_hyst, "hysteresis : 70/min nets, reste coupe")
check(R.a_resume, "40/min : repris")
check(R.b_player, "votre equipe : la force du joueur humain n'est pas lue")
check(R.b_player_mod, "votre equipe : fonderie (module fini) a 150/min : coupe")
check(R.c_survie, "mode survie : rien de coupe")
check(R.d_fill and R.d_over, "intermediaire au plafond : remplissage du quai d'entree retire")
check(R.d_collect, "vidage du quai de sortie garde")
check(R.d_other, "module d'un autre produit : nourri")
check(R.d_log, "journal [FO-INTERMEDIAIRE] au plafond")
check(R.d_under, "sous le plafond : nourri")
check(R.d_cons, "consommation mesuree : plafond releve")
check(R.d_demand, "demande des taches ouvertes : plafond releve")
check(R.e_off, "bascule eteinte : decisions d'avant le lot")
check(R.f_det, "deterministe")

---------------------------------------------------------------------------------------------------
-- 4. Chaîne lue dans les sources
---------------------------------------------------------------------------------------------------
section("4. chaine dans les sources")
local team = read_src("script/team/team.lua")
local ia, ib = team:find("Inter.think(f, tick)", 1, true), team:find("Board.assign(f, tick)", 1, true)
local ic = team:find("Recon.repair_think(f, surface, tick)", 1, true)
check(ia and ib and ic and ic < ia and ia < ib, "team.lua : Inter.think apres la reconstruction et le plan directeur, avant le marche")
local poles = read_src("script/team/poles.lua")
local pa, pb = poles:find("Inter.mine_skip(f)", 1, true), poles:find("FerEquipe.extra_mines", 1, true)
check(pa and pb and pa < pb, "poles.lua : ressources coupees ajoutees a skip avant le fond et le renfort de fer")
local auto = read_src("script/ai3/automatisation.lua")
check(auto:find("and not Inter.over(f, m.product)", 1, true) ~= nil, "automatisation.lua : rien n'est fabrique pour les quais d'un module au plafond")
check(not SRC_I:find("%-plate") and not SRC_I:find("gear"), "regle pure : aucun nom d'objet")
local srt = read_src("script/team/intermediaires.lua")
check(not srt:find('"[%w]+%-plate"') and not srt:find("gear%-wheel"), "runtime : aucun nom d'objet")

---------------------------------------------------------------------------------------------------
-- 5. Mutants
---------------------------------------------------------------------------------------------------
section("5. mutants")
local function mutant(name, from, to, detect)
  local s, n = SRC_I:gsub(from, to, 1)
  if not check(n == 1, "mutant " .. name .. " : motif introuvable") then return end
  local ok, killed = pcall(detect, s)
  check(ok and killed, "mutant " .. name .. " detecte")
end
local function differs9(s) local m = d09_facts(load_I(s)) for k, v in pairs(F9) do if m[k] ~= v then return true end end return false end
local function differs10(s) local m = d10_facts(load_I(s)) for k, v in pairs(F10) do if m[k] ~= v then return true end end return false end
local function differs_rt(s)
  local m = rt_facts(s)
  for k, v in pairs(R) do if m[k] ~= v then return true end end
  return false
end
mutant("survie ignoree", "if a%.survie then return false end", "", differs9)
mutant("sans hysteresis D09", "if prev then th = th %* I%.OFF end", "", differs9)
mutant("part de la main gardee", "num%(a%.stat%) %- num%(a%.hand_miners%) %* I%.HAND_RATE", "num(a.stat)", differs9)
mutant("modules ignores", "math%.max%(stat, math%.max%(0, num%(a%.modules%)%)%)", "stat", differs9)
mutant("cles exemptees vides", 'return key:sub%(1, 7%) == "survie:" or key:sub%(1, 6%) == "crise:"', "return false", differs9)
mutant("plafond fixe", "math%.ceil%(math%.max%(0, num%(a%.cons%)%) %* I%.HORIZON%)", "0", differs10)
mutant("demande ignoree", "%+ math%.max%(0, math%.floor%(num%(a%.demand%)%)%)", "", differs10)
mutant("sans hysteresis D10", "if prev then return have > math%.floor%(cap %* I%.RESUME%) end", "", differs10)
mutant("plafond jamais atteint", "return have >= cap", "return false", differs_rt)

print(string.format("[INTERMEDIAIRES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
