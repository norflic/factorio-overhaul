--[[
  s49 tranches : le plan d'un cadre neuf pas à pas (Ch.plan_begin / Ch.plan_step / Ch.plan_result), UN plan_order par pas, et Champ.frame
  qui fait un pas par appel. Le plan ne change pas : empreintes des plans de v0.7.107 (Ch.plan d'avant, variantes enchaînées dans le même
  appel) sur des specs qui demandent 1, 2, 3 et 4 variantes ; plan pas à pas == Ch.plan ; séquence reprise du début (chargement) == même plan.
  Usage, depuis la racine du mod :   lua5.2 tests/s49_tranches_test.lua
]]
package.path = "./?.lua;" .. package.path
local Ch = require("shared.team.champ")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local function ser(v, seen)
  if type(v) ~= "table" then return tostring(v) end
  if seen[v] then return "<cyc>" end
  seen[v] = true
  local ks = {}
  for k in pairs(v) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  local o = {}
  for _, k in ipairs(ks) do local x = v[k]; if type(x) ~= "function" then o[#o + 1] = tostring(k) .. "=" .. ser(x, seen) end end
  seen[v] = nil
  return "{" .. table.concat(o, ",") .. "}"
end
local function hash(s)
  local h = 0
  for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
  return h
end
local function ph(p, why) return p and hash(ser(p, {})) or ("nil:" .. tostring(why)) end

local BELTS3 = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }
local function ellipse(cx, cy, a, b)
  local out = {}
  for x = cx - a, cx + a do for y = cy - b, cy + b do if ((x - cx) / a) ^ 2 + ((y - cy) / b) ^ 2 <= 1 then out[#out + 1] = x; out[#out + 1] = y end end end
  return out
end
local function disc(cx, cy, r)
  local out = {}
  for x = cx - r, cx + r do for y = cy - r, cy + r do if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then out[#out + 1] = x; out[#out + 1] = y end end end
  return out
end
-- specs de tests/s46_champ-cout_test.lua
local function spec46(ore, o)
  return { ore = ore, blocked = {}, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = BELTS3, furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }, inserter = { rate = 0.83 },
    target = { x = 1000, y = 0 }, max_side = 8, design = "colonne", axis = o.axis,
    coal = o.coal and { tiles = o.coal, rate = 0.5 } or nil, logistics = { splitter = true, underground = 5 } }
end
-- cadres réels relevés en jeu (tests/champ_colonne_test.lua, load_spec)
local function split(str, sep)
  local out = {}
  if str == nil or str == "" then return out end
  for part in (str .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
  return out
end
local function nums(str) local out = {} for _, x in ipairs(split(str, ",")) do out[#out + 1] = tonumber(x) end return out end
local function set(str) local out = {} for _, x in ipairs(split(str, ",")) do out[tonumber(x)] = true end return out end
local function load_spec(path)
  local h = assert(io.open(path, "r"))
  local line = h:read("*l")
  h:close()
  local fl = {}
  for _, kv in ipairs(split(line, "|")) do local k, v = kv:match("^([%w_]+)=(.*)$"); if k then fl[k] = v end end
  return function()
    local d, pl, fu, tg = nums(fl.drill), nums(fl.pole), split(fl.furnace, ","), nums(fl.target)
    local belts = {}
    for _, x in ipairs(split(fl.belts, ";")) do belts[#belts + 1] = { lane = tonumber(x) } end
    return { ore = nums(fl.ore), blocked = set(fl.blocked), mine = set(fl.mine), soft = fl.soft ~= "" and set(fl.soft) or nil,
      drill = { size = d[1], reach = d[2], rate = d[3] }, pole = { reach = pl[1], wire = pl[2] }, belts = belts,
      furnace = { size = tonumber(fu[1]), rate = tonumber(fu[2]), fuel = fu[3] == "true", fuel_rate = tonumber(fu[4]) },
      inserter = { rate = tonumber(fl.ins) }, target = { x = tg[1], y = tg[2] }, max_side = tonumber(fl.max_side), design = "colonne",
      logistics = { underground = tonumber(fl.ug), splitter = fl.splitter == "true" }, coal = { tiles = nums(fl.coal), rate = tonumber(fl.coalrate) },
      ug_tiles = {} }
  end
end

-- { nom, spec neuve, variantes attendues, empreinte du plan de v0.7.107 (Ch.plan d'avant s49) }
local CASES = {
  { "petit", function() return spec46(ellipse(0, 0, 12, 9), { coal = ellipse(0, 20, 5, 5) }) end, nil, 1169538760 },
  { "ellipse 45x30", function() return spec46(ellipse(0, 0, 45, 30), { coal = ellipse(0, 50, 8, 8) }) end, nil, 988782013 },
  { "ellipse 45x30 axe y", function() return spec46(ellipse(0, 0, 45, 30), { coal = ellipse(0, 50, 8, 8), axis = "y" }) end, nil, 702834682 },
  { "disque sans charbon", function() return spec46(disc(0, 0, 20), {}) end, nil, nil },
  { "joueur 271828182", load_spec("tests/fixtures/champ_spec_player_271828182.txt"), nil, nil },
  { "scarlet 20261020", load_spec("tests/fixtures/champ_spec_scarlet_20261020.txt"), nil, nil },
}
local REF107 = { -- lua5.2 sur le champ.lua de v0.7.107 (Ch.plan d'avant s49), mêmes specs
  ["disque sans charbon"] = 1195242882,
  ["joueur 271828182"] = 1105317308,
  ["scarlet 20261020"] = 281488711,
}
for _, cs in ipairs(CASES) do cs[4] = cs[4] or REF107[cs[1]] end

print("== s49 tranches : un plan_order par pas, plan identique à Ch.plan et à v0.7.107")
local seen_n = {}
for _, cs in ipairs(CASES) do
  -- pas à pas : chaque pas calcule exactement UN plan_order
  local st = Ch.plan_begin(cs[2]())
  local one, steps = true, 0
  repeat
    local o0 = Ch.ORDERS
    local done = Ch.plan_step(st)
    steps = steps + 1
    if Ch.ORDERS - o0 ~= 1 then one = false end
  until done or steps > 8
  local hs = ph(Ch.plan_result(st))
  check(one and steps == st.n and steps <= 4, string.format("%s : %d pas, un plan_order par pas", cs[1], steps))
  seen_n[steps] = true
  -- Ch.plan (les pas enchaînés dans le même appel) : même plan, mêmes variantes
  local o0 = Ch.ORDERS
  local hp = ph(Ch.plan(cs[2]()))
  check(hp == hs and Ch.ORDERS - o0 == steps, string.format("%s : pas à pas %s == Ch.plan %s (%d plan_order)", cs[1], tostring(hs), tostring(hp), Ch.ORDERS - o0))
  -- empreinte du plan de v0.7.107
  check(cs[4] ~= nil and hs == cs[4], string.format("%s : empreinte %s == v0.7.107 %s", cs[1], tostring(hs), tostring(cs[4])))
  -- reprise : une séquence coupée (mémoire locale perdue au chargement) recommencée sur une spec neuve donne le même plan
  local st2 = Ch.plan_begin(cs[2]())
  Ch.plan_step(st2)
  local st3 = Ch.plan_begin(cs[2]())
  while not Ch.plan_step(st3) do end
  check(ph(Ch.plan_result(st3)) == hs, cs[1] .. " : séquence recommencée, même plan")
  print(string.format("  %s : %d variante(s), empreinte %s", cs[1], steps, tostring(hs)))
end
check(seen_n[1] and seen_n[2] and seen_n[3] and seen_n[4], "les quatre longueurs de séquence (1 à 4 variantes) sont couvertes")

-- Ch.plan_next : règle pure, ne modifie pas les résultats, rend la même variante tant qu'elle n'est pas calculée
do
  local sp = spec46(ellipse(0, 0, 12, 9), { coal = ellipse(0, 20, 5, 5) })
  local res = {}
  local i1 = Ch.plan_next(sp, res)
  local i2 = Ch.plan_next(sp, res)
  check(i1 == 1 and i2 == 1 and next(res) == nil, "plan_next : variante 1 d'abord, sans effet sur les résultats")
  local fp = { design = "champ" }
  check(Ch.plan_next(sp, { { p = fp } }) == nil, "plan_next : un plan qui n'est pas en colonne est complet en une variante")
  local fr = spec46(ellipse(0, 0, 12, 9), {})
  fr.frame = { axis = "x" }
  check(Ch.plan_next(fr, { { p = { design = "colonne", fuelled = true, exit = 1, ents = { { kind = "coffre", role = "combustible" } } } } }) == nil,
    "plan_next : un cadre figé (bande) n'a qu'une variante")
  local cp = { design = "colonne", fuelled = true, exit = 1, ents = { { kind = "coffre", role = "combustible" } }, bands = {} }
  local i, vs = Ch.plan_next(sp, { { p = cp } })
  check(i == 2 and vs.coal_first == -1 and sp.coal_first == nil, "plan_next : coffre de tête -> autre ordre des côtés (copie de la spec)")
end

-- Champ.frame (script/team/champ.lua) : un pas par appel, séquence en mémoire locale, jamais dans global
do
  local h = assert(io.open("script/team/champ.lua", "r"))
  local src = h:read("*a")
  h:close()
  local fi = src:find("function Champ.frame(f, surface, o)", 1, true)
  local fe = fi and src:find("\nfunction ", fi + 10, true) or nil
  local blk = (fi and fe) and src:sub(fi, fe) or ""
  local nstep = 0
  for _ in blk:gmatch("Ch%.plan_step%(") do nstep = nstep + 1 end
  check(nstep == 1 and not blk:find("Ch.plan(", 1, true), "Champ.frame : un seul Ch.plan_step par appel, aucun Ch.plan entier")
  local st = blk:find("Ch.plan_step(seq.st)", 1, true)
  local w = blk:find("if not done then return nil, Ax.WAIT end", 1, true)
  check(st and w and st < w, "Champ.frame : pas-encore (Ax.WAIT) entre deux pas")
  local code = src:gsub("settings%.global", ""):gsub("%-%-[^\n]*", "")
  check(src:find("local SEQ = {}", 1, true) ~= nil and not code:find("global%s*[%.%[]"), "séquences en mémoire locale du module (global jamais nommé)")
end

print(string.format("s49 tranches : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
