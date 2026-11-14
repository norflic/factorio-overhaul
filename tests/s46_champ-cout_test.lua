--[[
  s46 champ-cout : la recherche de la phase des bandes d'un cadre neuf est faite une fois par Ch.plan et par axe (mémoire PHASE_MEMO),
  et les rangées sont partagées entre phases. Le plan ne change pas : empreintes des plans de v0.7.104 (avant la coupe) sur trois specs,
  plans identiques avec des tables neuves (mémoire par identité, vidée après chaque Ch.plan), borne de temps hors jeu.
  Usage, depuis la racine du mod :   lua5.2 tests/s46_champ-cout_test.lua
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
local BELTS3 = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }
local function ellipse(cx, cy, a, b)
  local out = {}
  for x = cx - a, cx + a do for y = cy - b, cy + b do if ((x - cx) / a) ^ 2 + ((y - cy) / b) ^ 2 <= 1 then out[#out + 1] = x; out[#out + 1] = y end end end
  return out
end
local function spec_of(ore, o)
  return { ore = ore, blocked = {}, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = BELTS3, furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }, inserter = { rate = 0.83 },
    target = { x = 1000, y = 0 }, max_side = 8, design = "colonne", axis = o.axis,
    coal = { tiles = o.coal, rate = 0.5 }, logistics = { splitter = true, underground = 5 } }
end
local CASES = {
  { "petit", function() return spec_of(ellipse(0, 0, 12, 9), { coal = ellipse(0, 20, 5, 5) }) end },
  { "ellipse 45x30", function() return spec_of(ellipse(0, 0, 45, 30), { coal = ellipse(0, 50, 8, 8) }) end },
  { "ellipse 45x30 axe y", function() return spec_of(ellipse(0, 0, 45, 30), { coal = ellipse(0, 50, 8, 8), axis = "y" }) end },
}
local REF = dofile("tests/s46_champ-cout_ref.lua")

print("== s46 champ-cout : plans identiques à v0.7.104, mémoire par Ch.plan")
for _, cs in ipairs(CASES) do
  local t = os.clock()
  local p = Ch.plan(cs[2]())
  local dt = os.clock() - t
  local h1 = p and hash(ser(p, {})) or -1
  check(REF[cs[1]] == nil or h1 == REF[cs[1]], string.format("%s : empreinte %d = v0.7.104 %s", cs[1], h1, tostring(REF[cs[1]])))
  local q = Ch.plan(cs[2]()) -- tables neuves : la mémoire du plan d'avant ne sert pas
  check(q and hash(ser(q, {})) == h1, cs[1] .. " : second plan (tables neuves) identique")
  check(dt < 3.0, string.format("%s : %.2f s hors jeu < 3 s", cs[1], dt))
end
print(string.format("s46_champ-cout_test : %d OK, %d ECHEC", passes, failures))
if failures > 0 then os.exit(1) end
