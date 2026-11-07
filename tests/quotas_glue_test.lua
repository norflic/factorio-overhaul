--[[
  Lot VIDEO L4, branchement : banc HORS JEU du VRAI code de script/team/build.lua (out_wanted, out_tasks, quai_tasks, extraits du
  fichier) sur un moteur de bouchons, avec la colle script/team/quotas_glue.lua et la règle shared/team/quotas.lua.
  Lancement, depuis la racine du mod : lua5.2 tests/quotas_glue_test.lua
    1. sortie vide : une minute d'ingrédients, au moins une pile par voyage (pas 400), aucune collecte ;
    2. sortie à 90 % du quota : plus d'ALIMENTATION, la COLLECTE reste émise, en fin de liste ;
    3. coffre de sortie sous barre (2 cases) : quota borné à la barre, seuil de collecte borné (100 et non 200 : sans cela, plus
       d'alimentation à 180 et une collecte à 200 ne viendrait jamais) ;
    4. projet sans débit de sortie (site, projet d'avant 0.6.59) : l'ancienne règle à l'identique ;
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

_G.game = { item_prototypes = { ["iron-plate"] = { stack_size = 100 }, ["iron-ore"] = { stack_size = 50 }, coal = { stack_size = 50 } } }
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
  local Build = { QUAI_LOW = 60, QUAI_FILL = 400, COLLECT_AT = 200, Quotas = Qg }
  local env = {
    Build = Build,
    P = { anchor_for = function(_, x, y) return { x = x, y = y } end },
    seg_passable = function() return function() return true end end,
    free_spot = function(_, _, x, y) return x, y end,
    is_plant_project = function() return false end,
    plant_burn_kw = function() return 0, 0 end,
    Cc = {}, cc_say = function() end, Sante = { tasks = function() end }, M = {},
    Stock = { count = function(_, it) return (W.stock[it] or 0) end },
    defines = { inventory = { chest = 1 } },
    sorted_keys = function(t) local ks = {} for k in next, t or {} do ks[#ks + 1] = k end table.sort(ks) return ks end,
  }
  local chunk = assert(load(body .. "\nreturn { quai_tasks = quai_tasks, out_tasks = out_tasks }", "build_quotas", "t",
    setmetatable(env, { __index = _G })))
  return chunk()
end

local surface = { find_entity = function(_, pos) return W.chests[pos[1] .. "," .. pos[2]] end }
local f = { key = "f1", force = "f1", build = { lat = {} } }
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

print("[QUOTAS-GLUE] 1-4. code reel de build.lua")
check(battery(load_code(SRC, Qg0), true) == 0, "batterie sans echec")

-- 5. câblage
print("[QUOTAS-GLUE] 5. cablage")
check(SRC:find('Build.Quotas = require("script.team.quotas_glue")', 1, true) ~= nil, "Build.Quotas requis au chargement (champ, pas une locale)")
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

print(string.format("[QUOTAS-GLUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
