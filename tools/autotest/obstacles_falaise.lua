--[[
  Lot OBSTACLES : compare l'emprise de collision RELEVÉE au moteur réel (scénario obstacles-falaise) au modèle pur
  shared/team/falaise.lua.
  Usage : lua5.2 tools/autotest/obstacles_falaise.lua <benchmark.log> [--mod <racine du mod>]
          lua5.2 tools/autotest/obstacles_falaise.lua --selftest
  Sortie : une ligne par orientation (tuiles du moteur, du modèle, MANQUES, en trop) et « [OBSTACLES-FALAISE] BILAN : … » ; code 0
  si aucun MANQUE (tuile refusée par le moteur et absente du modèle), 1 sinon, 2 si le journal ne contient pas les 20 falaises.
]]
local mod = "."
local path
local selftest = false
do
  local i = 1
  while i <= #arg do
    if arg[i] == "--mod" then mod = arg[i + 1]; i = i + 1
    elseif arg[i] == "--selftest" then selftest = true
    else path = arg[i] end
    i = i + 1
  end
end
package.path = mod .. "/?.lua;" .. package.path
local F = require("shared.team.falaise")

local function parse_line(l)
  local o, cx, cy, bl = l:match("FALAISE o=(%S+) cx=(%S+) cy=(%S+) bb=%S+ bloque=(%S*)")
  if not o then return nil end
  local set = {}
  for tx, ty in (bl or ""):gmatch("(%-?%d+):(%-?%d+)") do set[tonumber(tx) .. ":" .. tonumber(ty)] = true end
  return { o = o, cx = tonumber(cx), cy = tonumber(cy), engine = set }
end

local function window(cx, cy, R)
  local fx, fy = math.floor(cx), math.floor(cy)
  return fx - R, fy - R, fx + R - 1, fy + R - 1
end

--- Compare ; rend { n = falaises, misses = {…}, extras = nombre, engine = tuiles du moteur, model = tuiles du modèle }
local function compare(list)
  local out = { n = #list, misses = {}, extras = 0, engine = 0, model = 0, rows = {} }
  for _, c in ipairs(list) do
    local t = F.tiles(c.cx, c.cy, c.o, 1)
    local x0, y0, x1, y1 = window(c.cx, c.cy, 7)
    local model = {}
    local nmodel = 0
    for i = 1, #t - 1, 2 do
      if t[i] >= x0 and t[i] <= x1 and t[i + 1] >= y0 and t[i + 1] <= y1 then model[t[i] .. ":" .. t[i + 1]] = true; nmodel = nmodel + 1 end
    end
    local miss, extra, neng = {}, 0, 0
    for k in pairs(c.engine) do
      neng = neng + 1
      if not model[k] then miss[#miss + 1] = k end
    end
    for k in pairs(model) do if not c.engine[k] then extra = extra + 1 end end
    table.sort(miss)
    out.engine, out.model, out.extras = out.engine + neng, out.model + nmodel, out.extras + extra
    for _, k in ipairs(miss) do out.misses[#out.misses + 1] = c.o .. " " .. k end
    out.rows[#out.rows + 1] = string.format("  %-15s moteur %2d tuiles, modele %2d, MANQUES %d, en trop %d", c.o, neng, nmodel, #miss, extra)
  end
  return out
end

local function report(out)
  for _, r in ipairs(out.rows) do print(r) end
  for _, m in ipairs(out.misses) do print("  MANQUE : " .. m) end
  print(string.format("[OBSTACLES-FALAISE] BILAN : %d falaise(s), %d tuile(s) refusee(s) par le moteur, %d dans le modele, %d MANQUE(S), %d en trop",
    out.n, out.engine, out.model, #out.misses, out.extras))
end

if selftest then
  -- journal synthétique : le moteur = le modèle → 0 manque ; une tuile du moteur absente du modèle (dans la fenêtre) → manque détecté
  local list = {}
  local names = {}
  for k in pairs(F.BOXES) do names[#names + 1] = k end
  table.sort(names)
  for i, o in ipairs(names) do
    local cx, cy = (i - 1) * 14, 0.5
    local set = {}
    local t = F.tiles(cx, cy, o, 1)
    for j = 1, #t - 1, 2 do set[t[j] .. ":" .. t[j + 1]] = true end
    list[#list + 1] = { o = o, cx = cx, cy = cy, engine = set }
  end
  local ok = compare(list)
  assert(#ok.misses == 0 and ok.n == 20, "selftest : le modele contre lui-meme ne manque rien")
  local fx = math.floor(list[1].cx)
  list[1].engine[(fx + 6) .. ":" .. math.floor(list[1].cy)] = true -- tuile dans la fenêtre, absente du modèle
  local bad = compare(list)
  assert(#bad.misses >= 1, "selftest : une tuile du moteur absente du modele est un MANQUE")
  local line = parse_line("FALAISE o=west-to-east cx=178 cy=-429.5 bb=177,-430,179,-429 bloque=176:-431,177:-431")
  assert(line and line.o == "west-to-east" and line.engine["176:-431"] and line.engine["177:-431"], "selftest : lecture d'une ligne")
  print("[OBSTACLES-FALAISE] selftest : 3 controles OK")
  os.exit(0)
end

assert(path, "usage : lua5.2 tools/autotest/obstacles_falaise.lua <benchmark.log>")
local fh = assert(io.open(path, "rb"))
local list = {}
for l in fh:lines() do
  local c = parse_line(l)
  if c then list[#list + 1] = c end
end
fh:close()
if #list < 20 then
  print("[OBSTACLES-FALAISE] journal incomplet : " .. #list .. " falaise(s) sur 20")
  os.exit(2)
end
local out = compare(list)
report(out)
os.exit(#out.misses == 0 and 0 or 1)
