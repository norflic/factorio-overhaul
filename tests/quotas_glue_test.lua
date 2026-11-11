--[[
  Lot VIDEO L4, branchement : banc HORS JEU du VRAI code de script/team/build.lua (out_wanted, out_tasks, quai_tasks, extraits du
  fichier) sur un moteur de bouchons, avec la colle script/team/quotas_glue.lua et la règle shared/team/quotas.lua.
  Lancement, depuis la racine du mod : lua5.2 tests/quotas_glue_test.lua
    1. sortie vide : une minute d'ingrédients, au moins une pile par voyage (pas 400), aucune collecte ;
    2. sortie à 90 % du quota : plus d'ALIMENTATION, la COLLECTE reste émise, en fin de liste ;
    3. coffre de sortie sous barre (2 cases) : quota borné à la barre, seuil de collecte borné (100 et non 200 : sans cela, plus
       d'alimentation à 180 et une collecte à 200 ne viendrait jamais) ;
    4. projet sans débit de sortie (site, projet d'avant 0.6.59) : l'ancienne règle à l'identique ;
    4 ter. lot TV-QUOTAS (C11) : modules de vitesse et de productivité posés puis RETIRÉS dans les machines du projet : le quota est recalculé
       (sortie et entrée au rapport mesuré), la mesure n'a lieu qu'une fois par Qt.MEASURE_TICKS, journal [FO-QUOTA-MODULES] ;
    5. câblage : p.outflow posé au plan, Build.Quotas requis au chargement, aucune locale de plus au bloc principal (199 sur 200) ;
    6. mutants refusés (source de build.lua ou colle modifiés).
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end

local fh = assert(io.open("script/team/build.lua", "rb"))
local SRC = fh:read("*a")
fh:close()
local A_MARK = "--- Lot INDUSTRIE I6 (relecture 0.6.31) : la sortie d'un bloc de mall se vide-t-elle vers le QG ?"
local B_MARK = "-- Raccordement : fils"

_G.game = { tick = 0, item_prototypes = { ["iron-plate"] = { stack_size = 100 }, ["iron-ore"] = { stack_size = 50 }, coal = { stack_size = 50 } },
  entity_prototypes = { ["stone-furnace"] = { type = "furnace" }, ["inserter"] = { type = "inserter" } } }
local Qg0 = require("script.team.quotas_glue")

local W
local function inv_of(c)
  return setmetatable({
    get_item_count = function() return c.n end,
    get_bar = function() return c.bar or 33 end,                 -- F95 : sans barre, get_bar() = cases + 1
    get_contents = function() return c.n > 0 and { [c.item] = c.n } or {} end,
  }, { __len = function() return 32 end })
end
local function chest(n, item, bar)
  local c = { n = n, item = item, bar = bar }
  c.force = { name = "f1" }
  c.get_item_count = function() return c.n end
  c.get_inventory = function() return inv_of(c) end
  return c
end

local function load_code(src, Qg)
  local a = assert(src:find(A_MARK, 1, true), "repere absent")
  local b = assert(src:find(B_MARK, a, true), "repere absent")
  local body = src:sub(a, b - 1)
  local Build = { QUAI_LOW = 60, QUAI_FILL = 400, COLLECT_AT = 200, Quotas = Qg,
    Rempl = { adjust = function(_, _, _, _, _, _, _, _, r) return r end } } -- lot REMPLISSAGE : doublure neutre (stock juste), testee dans tests/remplissage_test.lua
  local env = {
    Build = Build,
    P = { anchor_for = function(_, x, y) return { x = x, y = y } end },
    seg_passable = function() return function() return true end end,
    free_spot = function(_, _, x, y) return x, y end,
    is_plant_project = function() return false end,
    plant_burn_kw = function() return 0, 0 end,
    Cc = require("shared.team.charbon_centrale"), cc_say = function() end, Sante = { tasks = function() end }, M = {},
    Stock = { count = function(_, it) return (W.stock[it] or 0) end },
    -- lot BRULEURS-A-SEC : reserve des bruleurs (burner_fuel_reserve) ; doublure sans bruleur : aucune reserve, le stock juste
    T = require("shared.team.config"),
    Outposts = { smelters = function() return {} end, burners = function() return {} end, fuel_levels = function(list) return list end }, -- lot CHAUDIERES
    defines = { inventory = { chest = 1 } },
    sorted_keys = function(t) local ks = {} for k in next, t or {} do ks[#ks + 1] = k end table.sort(ks) return ks end,
    -- (intégrateur, 8/11 : X10-S0 met des portées de mesure dans quai_tasks ; doublure muette, aucune décision)
    Profiler = setmetatable({}, { __index = function() return function() end end }),
  }
  local chunk = assert(load(body .. "\nreturn { quai_tasks = quai_tasks, out_tasks = out_tasks }", "build_quotas", "t",
    setmetatable(env, { __index = _G })))
  return chunk()
end

local surface = { find_entity = function(_, pos) return W.chests[pos[1] .. "," .. pos[2]] end,
  find_entities_filtered = function() return W.upgraded and { W.upgraded } or {} end }
local f = { key = "f1", force = "f1", outposts = {}, build = { lat = {} } }
local function smelter(with_flow)
  return { id = 7, prio = 55, state = "fini", spec = { gen = "smelter" },
    outflow = with_flow and { ["iron-plate"] = 0.625 } or nil,
    inflow = { ["iron-ore"] = 0.625, coal = 0.045 },
    outs = { { x = 10.5, y = 0.5 } },
    quais = { { x = 1.5, y = 1.5, item = "iron-ore" }, { x = 2.5, y = 1.5, item = "coal" } } }
end
local function world(out_n, out_bar)
  W = { stock = { ["iron-ore"] = 1000, coal = 1000 }, chests = {
    ["10.5,0.5"] = chest(out_n, "iron-plate", out_bar),
    ["1.5,1.5"] = chest(0, "iron-ore"), ["2.5,1.5"] = chest(0, "coal") } }
end
local function run(X, p)
  local out = {}
  X.quai_tasks(f, p, surface, out)
  local fills, collects, order = {}, 0, {}
  for _, t in ipairs(out) do
    order[#order + 1] = t.ia1d.mode
    if t.ia1d.mode == "fill" then fills[t.items[1][1]] = t.items[1][2] else collects = collects + 1 end
  end
  return fills, collects, table.concat(order, ",")
end

local function ser_shares(o)
  if not o or not o.shares then return "?" end
  local ks = {}
  for k in pairs(o.shares) do ks[#ks + 1] = k end
  table.sort(ks)
  local out = {}
  for _, k in ipairs(ks) do out[#out + 1] = k .. "=" .. o.shares[k].cases end
  return table.concat(out, ",")
end

local function battery(X, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(c, msg) end
  end
  -- 1. sortie vide
  world(0)
  local p = smelter(true)
  local fills, col = run(X, p)
  ck(fills["iron-ore"] == 50 and fills.coal == 50 and col == 0,
    string.format("sortie vide : une minute d'ingredients, au moins une pile par voyage (minerai %s : 38 -> 50, charbon %s : 3 -> 50), aucune collecte",
      tostring(fills["iron-ore"]), tostring(fills.coal)))
  ck(p.quota and p.quota.ins[1].low == 25, "entree refaite sous la moitie (25)")
  ck(p.quota and p.quota.outs[1].cases == 4 and p.quota.outs[1].cap == 400, "quota du four seul : 4 cases, 400 plaques (10 min de 0,625/s)")
  -- 2. sortie à 90 %
  world(360)
  fills, col, order = run(X, smelter(true))
  ck(next(fills) == nil, "sortie a 90 % : plus d'alimentation")
  ck(col == 1, "sortie a 90 % : la collecte reste emise")
  world(359)
  fills = run(X, smelter(true))
  ck(fills["iron-ore"] == 50, "sortie a 89,75 % : alimentation")
  world(250)
  fills, col, order = run(X, smelter(true))
  ck(order == "fill,fill,collect", "la collecte garde sa place en fin de liste (" .. order .. ")")
  -- 3. coffre sous barre de 2 cases
  world(180, 3)
  local pb = smelter(true)
  fills, col = run(X, pb)
  ck(pb.quota and pb.quota.outs[1].cap == 200 and pb.quota.outs[1].collect_at == 100, "barre de 2 cases : quota 200, collecte a 100")
  ck(next(fills) == nil and col == 1, "180 sur 200 : plus d'alimentation, collecte emise (seuil 100, pas 200 : pas d'interblocage)")
  -- 4. ancienne règle sans débit de sortie
  world(150)
  fills, col = run(X, smelter(false))
  ck(fills["iron-ore"] == 400 and fills.coal == 400 and col == 0, "sans debit de sortie : ancienne regle (charge 400, collecte a 200)")
  world(250)
  fills, col = run(X, smelter(false))
  ck(col == 1 and fills["iron-ore"] == 400, "sans debit de sortie : collecte a 200, alimentation jamais coupee")
  -- 4 bis. Lot VIDEO-COUVERTURE 3 (C11, C3.2) : un module à DEUX produits a un quota, la barre du coffre est partagée en parts
  local function duo()
    local p = smelter(true)
    p.outflow = { ["iron-plate"] = 0.625, coal = 0.1 }  -- 375 plaques (4 cases de 100), 60 charbon (2 cases de 50) en 10 min
    return p
  end
  world(0)
  local pd = duo()
  run(X, pd)
  local o = pd.quota and pd.quota.outs[1]
  ck(o ~= nil and o.cases == 6 and o.cap == 500 and o.shares and o.shares["iron-plate"].cases == 4 and o.shares.coal.cases == 2,
    "deux produits : 4 cases de plaques et 2 de charbon, 500 objets en tout (" .. tostring(o and o.cap) .. ")")
  world(449)
  local f1 = run(X, duo())
  ck(f1["iron-ore"] == 50, "deux produits, sortie a 89,8 % de la capacite : alimentation")
  world(450)
  local f2, c2 = run(X, duo())
  ck(next(f2) == nil and c2 == 1, "deux produits, sortie a 90 % : plus d'alimentation, la collecte est emise")
  world(180, 4)                                         -- barre a 4 : 3 cases ouvertes pour 2 produits
  local pb2 = duo()
  run(X, pb2)
  local sb = pb2.quota and pb2.quota.outs[1]
  ck(sb and sb.cases == 3 and sb.shares["iron-plate"].cases + sb.shares.coal.cases == 3 and sb.shares.coal.cases >= 1,
    "barre de 3 cases ouvertes : la somme des parts = 3, une case au moins au charbon (" .. ser_shares(sb) .. ")")
  ck(sb and sb.collect_at <= sb.cap * 500 / 1000, "seuil de collecte du coffre sous la moitie de sa capacite (pas d'interblocage)")
  return fails
end

-- 4 ter. Lot TV-QUOTAS (C11) : modules posés puis retirés
local function battery_modules(X, Qg, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(c, msg) end
  end
  local logs = {}
  local log0 = _G.log
  _G.log = function(m) logs[#logs + 1] = m end
  local function project()
    local p = smelter(true)
    p.ents = { { name = "inserter", x = 5.5, y = 5.5 }, { name = "stone-furnace", x = 20.5, y = 0.5 } }
    return p
  end
  local function furnace(sp, pr) return { valid = true, force = { name = "f1" }, speed_bonus = sp, productivity_bonus = pr } end
  local fg = { key = "f1", force = "f1", outposts = {}, build = { lat = {}, stats = {} } }
  local function step(p, tick)
    game.tick = tick
    local out = {}
    X.quai_tasks(fg, p, surface, out)
    return out
  end
  world(0)
  W.chests["20.5,0.5"] = furnace(0, 0)
  local p = project()
  step(p, 1000)
  local k0 = p.quota_key
  ck(p.quota and p.quota.outs[1].cases == 4 and p.qm_out == nil and p.qm_in == nil, "sans module : 4 cases, aucun rapport (l'ancienne regle)")
  ck(#logs == 0, "sans module : aucune ligne de journal")
  -- modules de vitesse posés (+100 %) : la mesure suivante recalcule
  W.chests["20.5,0.5"] = furnace(1.0, 0)
  step(p, 1300)
  ck(p.qm_out == nil and p.quota_key == k0, "avant la periode de mesure (600 ticks) : le quota ne bouge pas")
  step(p, 1600)
  ck(p.qm_out == 2000 and p.qm_in == 2000, "modules de vitesse +100 % relevés : sortie et entree x2 (" .. tostring(p.qm_out) .. "/" .. tostring(p.qm_in) .. ")")
  ck(p.quota and p.quota.outs[1].cases == 8 and p.quota.ins[1].want == 75 and p.quota_key ~= k0,
    "quota recalcule : 8 cases (1,25 plaque/s en 10 min) et 75 minerai a l'entree (" .. tostring(p.quota and p.quota.outs[1].cases) .. ", " .. tostring(p.quota and p.quota.ins[1].want) .. ")")
  ck(#logs == 1 and logs[1]:find("[FO-QUOTA-MODULES]", 1, true) and logs[1]:find("sortie x2.00 (avant x1.00)", 1, true), "journal [FO-QUOTA-MODULES] : " .. tostring(logs[1]))
  step(p, 2300)
  ck(#logs == 1 and p.qm_out == 2000, "rapport inchange : pas de nouvelle ligne de journal")
  -- modules retirés : retour à l'ancienne règle, clé d'avant
  W.chests["20.5,0.5"] = furnace(0, 0)
  step(p, 3000)
  ck(p.qm_out == nil and p.qm_in == nil and p.quota_key == k0 and p.quota.outs[1].cases == 4, "modules retires : quota d'avant, cle d'avant")
  ck(#logs == 2 and logs[2]:find("sortie x1.00 (avant x2.00)", 1, true) ~= nil, "journal du retrait")
  -- productivité seule : la sortie monte, l'entrée non
  W.chests["20.5,0.5"] = furnace(0, 0.4)
  step(p, 3700)
  ck(p.qm_out == 1400 and p.qm_in == nil, "productivite +40 % : sortie x1,4, entree inchangee (" .. tostring(p.qm_out) .. "/" .. tostring(p.qm_in) .. ")")
  ck(p.quota.ins[1].want == 50 and p.quota.outs[1].cases >= 5, "entree toujours a une minute (pile de 50), sortie plus large (" .. tostring(p.quota.outs[1].cases) .. ")")
  -- machine introuvable : rien de relevé, rapport remis à 1000
  W.chests["20.5,0.5"] = { valid = true, force = { name = "enemy" }, speed_bonus = 1.0, productivity_bonus = 0 }
  step(p, 4400)
  ck(p.qm_out == nil, "machine d'une autre force : non relevee")
  W.chests["20.5,0.5"] = nil
  step(p, 5100)
  ck(p.qm_out == nil, "machine disparue : l'ancienne regle")
  -- machine montée d'un niveau (autre nom au même centre) : retrouvée par le type
  W.upgraded = furnace(0.5, 0)
  step(p, 5800)
  ck(p.qm_out == 1500, "machine montee d'un niveau retrouvee par son type : x1,5 (" .. tostring(p.qm_out) .. ")")
  W.upgraded = nil
  -- réglage éteint : jamais de rapport
  local on = Qg.Qt.MODULES_RATIO
  Qg.Qt.MODULES_RATIO = false
  W.chests["20.5,0.5"] = furnace(1.0, 0)
  local p2 = project()
  step(p2, 9000)
  step(p2, 9700)
  ck(p2.qm_out == nil and p2.quota.outs[1].cases == 4, "reglage eteint : quota d'avant meme avec des modules")
  Qg.Qt.MODULES_RATIO = on
  -- projet sans machine relevable (ni p.ents) : inchangé
  local p3 = smelter(true)
  step(p3, 12000)
  ck(p3.qm_out == nil and p3.quota.outs[1].cases == 4, "projet sans machines relevees : quota d'avant")
  _G.log = log0
  W.chests["20.5,0.5"] = nil
  return fails
end

print("[QUOTAS-GLUE] 1-4. code reel de build.lua")
check(battery(load_code(SRC, Qg0), true) == 0, "batterie sans echec")
print("[QUOTAS-GLUE] 4 ter. modules poses puis retires (TV-QUOTAS, C11)")
check(battery_modules(load_code(SRC, Qg0), Qg0, true) == 0, "batterie des modules sans echec")

-- 5. câblage
print("[QUOTAS-GLUE] 5. cablage")
check(SRC:find('Build.Quotas = require("script.team.quotas_glue")', 1, true) ~= nil, "Build.Quotas requis au chargement (champ, pas une locale)")
check(SRC:find("Build.Quotas.measure(f, p, surface)", 1, true) ~= nil, "TV-QUOTAS : la mesure des modules precede le calcul du quota (out_tasks)")
check(SRC:find("p.outflow[k] = g.nominal[k]", 1, true) ~= nil, "p.outflow pose au plan depuis g.nominal (M.analyze), a cote de p.inflow")
do
  local cut
  for pos in SRC:gmatch("()\nreturn Build%s*$") do cut = pos end
  local head, tail = SRC:sub(1, cut), SRC:sub(cut + 1)
  local function ok_with(n)
    local t = {}
    for i = 1, n do t[i] = "local zz_" .. i .. " = nil" end
    return load(head .. table.concat(t, "\n") .. "\n" .. tail, "=x") ~= nil
  end
  local free = 0
  while free < 201 and ok_with(free + 1) do free = free + 1 end
  print(string.format("[QUOTAS-GLUE] build.lua : %d locales au bloc principal (encore %d)", 200 - free, free))
  check(200 - free <= 199, "aucune locale de plus au bloc principal de build.lua (199 au plus)")
end

-- 6. mutants
print("[QUOTAS-GLUE] 6. mutants")
local function src_mutant(name, from, to)
  local s, n = SRC:gsub(from, to)
  assert(n > 0, "mutant sans effet : " .. name)
  local ok, X = pcall(load_code, s, Qg0)
  local f2 = 1
  if ok then local ok2, r = pcall(battery, X, false); f2 = ok2 and r or 1 end
  check(f2 > 0, "mutant refuse : " .. name)
end
src_mutant("alimentation gardee quand la sortie est pleine", "elseif feed then", "elseif true then")
src_mutant("collecte retenue par le verdict", "for _, t in ipairs%(collect%) do out%[#out %+ 1%] = t end",
  "if feed then for _, t in ipairs(collect) do out[#out + 1] = t end end")
src_mutant("seuil de collecte non borne par le quota", "Build%.Quotas%.collect_at%(q, i, o%.at or Build%.COLLECT_AT%)", "(o.at or Build.COLLECT_AT)")
src_mutant("remplissage a l'ancienne (400) sous quota", "Build%.Quotas%.refill%(qta, i, n, have, Build%.QUAI_LOW, Build%.QUAI_FILL%)",
  "{ due = n < Build.QUAI_LOW and have > 0, count = math.min(Build.QUAI_FILL - n, have) }")
src_mutant("verdict sans les comptes des sorties", "local feed = Build%.Quotas%.feed_ok%(qta, counts%)", "local feed = Build.Quotas.feed_ok(qta, {})")
src_mutant("barre du coffre ignoree", "slots = math%.min%(in_slots, inv%.get_bar%(%) %- 1%)", "slots = in_slots")
do
  local Qg = {}
  for k, v in pairs(Qg0) do Qg[k] = v end
  Qg.of = function() return nil end
  local f2 = battery(load_code(SRC, Qg), false)
  check(f2 > 0, "mutant refuse : colle sans quota (ancienne regle partout)")
end

do -- lot VIDEO-COUVERTURE 3 : la colle d'avant (un seul produit par coffre) : le module à deux produits perd son quota
  local Qg = {}
  for k, v in pairs(Qg0) do Qg[k] = v end
  local of0 = Qg0.of
  Qg.of = function(p, ...)
    local n = 0
    for _, v in pairs(p.outflow or {}) do if (v or 0) > 0 then n = n + 1 end end
    if n > 1 then return nil end
    return of0(p, ...)
  end
  local f2 = battery(load_code(SRC, Qg), false)
  check(f2 > 0, "mutant refuse : colle d'avant (un seul produit par coffre)")
end

-- mutants du lot TV-QUOTAS : sources de la colle et de build.lua
do
  local fq = assert(io.open("script/team/quotas_glue.lua", "rb"))
  local GSRC = fq:read("*a")
  fq:close()
  local function glue_mutant(name, from, to)
    local i, j = GSRC:find(from, 1, true)
    assert(i, "mutant sans effet : " .. name)
    local Qg = assert(load(GSRC:sub(1, i - 1) .. to .. GSRC:sub(j + 1), "=glue_mutant"))()
    local ok, r = pcall(function() return battery_modules(load_code(SRC, Qg), Qg, false) end)
    check((not ok) or r > 0, "mutant refuse : " .. name)
  end
  glue_mutant("rapport mesure mais jamais applique aux debits", "outflow, inflow = Qt.scaled(outflow, ro or 1000), Qt.scaled(inflow, ri or 1000)", "")
  glue_mutant("rapport hors de la cle du quota (jamais recalcule)", "key = key .. string.format(\":m%d:%d\", ro or 1000, ri or 1000)", "")
  glue_mutant("entree mise au rapport de la sortie", "Qt.scaled(inflow, ri or 1000)", "Qt.scaled(inflow, ro or 1000)")
  glue_mutant("mesure a chaque appel (periode ignoree)", "now - p.qm_tick < Qt.MEASURE_TICKS", "false")
  glue_mutant("mesure jamais refaite apres la premiere", "if p.qm_tick and now >= p.qm_tick and now - p.qm_tick < Qt.MEASURE_TICKS then return false end", "if p.qm_tick then return false end")
  glue_mutant("productivite non relevee", "prod_pm = pm(ent.productivity_bonus)", "prod_pm = 0")
  glue_mutant("vitesse non relevee", "speed_pm = pm(ent.speed_bonus)", "speed_pm = 0")
  glue_mutant("retrait des modules oublie (rapport garde)", "p.qm_out, p.qm_in = (po ~= 1000) and po or nil, (pi ~= 1000) and pi or nil", "p.qm_out, p.qm_in = (po ~= 1000) and po or p.qm_out, (pi ~= 1000) and pi or p.qm_in")
  glue_mutant("machine montee d'un niveau perdue", "if not ent then", "if false then")
  glue_mutant("force ignoree", "ent.force.name == f.force", "true")
  glue_mutant("journal oublie", "log(string.format(\"[FO-QUOTA-MODULES]", "(function() end)(string.format(\"[FO-QUOTA-MODULES]")
  glue_mutant("reglage ignore", "if not Qt.MODULES_RATIO or type(p.outflow)", "if type(p.outflow)")
  local s1, n1 = SRC:gsub("  Build%.Quotas%.measure%(f, p, surface%)[^\n]*\n", "")
  assert(n1 == 1)
  local ok, r = pcall(function() return battery_modules(load_code(s1, Qg0), Qg0, false) end)
  check((not ok) or r > 0, "mutant refuse : build.lua sans appel de la mesure")
end

print(string.format("[QUOTAS-GLUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
