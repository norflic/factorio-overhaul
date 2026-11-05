--[[
  Lot PERIMETRE2 : banc HORS JEU de la règle pure shared/team/porte_couloir.lua (porte sur la brèche d'un couloir d'accès d'ÉTAGE 5 dans un
  anneau de murs). Lancement, depuis la racine du mod : lua5.2 tests/porte_couloir_test.lua
  Couloirs simulés comme Co.tiles d'ÉTAGE 5 : bande de 2 tuiles, chemin de Manhattan (axe dominant d'abord). Mutants : le texte du module est
  modifié, la suite doit échouer.
]]
package.path = "./?.lua;" .. package.path
local P = require("shared.team.plan")

local fh = assert(io.open("shared/team/porte_couloir.lua", "rb"))
local SRC = fh:read("*a")
fh:close()
local function load_pc(src) return assert(load(src, "@shared.team.porte_couloir"))() end

-- bande de couloir : de (x0, y) à (x1, y) le long de x (2 rangées : y et y + dy), ou le long de y
local function band_x(set, x0, x1, y, dy)
  for x = math.min(x0, x1), math.max(x0, x1) do set[P.tkey(x, y)] = 7 set[P.tkey(x, y + dy)] = 7 end
  return set
end
local function band_y(set, y0, y1, x, dx)
  for y = math.min(y0, y1), math.max(y0, y1) do set[P.tkey(x, y)] = 7 set[P.tkey(x + dx, y)] = 7 end
  return set
end

local function suite(Pc)
  local fails = {}
  local n = 0
  local function check(c, m) n = n + 1 if not c then fails[#fails + 1] = m end end
  local NORTH, EAST = 0, 2
  -- 1. couloir qui traverse le côté OUEST d'un anneau (mur le long de y en x = 194), bande le long de x, rangées y = 3 et 4
  local c1 = band_x({}, 160, 199, 3, 1)
  for _, y in ipairs({ 3, 4 }) do
    local k, d, ax = Pc.tile(194, y, c1, "o", true)
    check(k == "porte" and d == NORTH and ax == "x", "1. côté ouest traversé : porte verticale, passage selon x (y=" .. y .. " : " .. tostring(k) .. " " .. tostring(d) .. ")")
  end
  check(Pc.tile(194, 5, c1, "o", true) == "mur" and Pc.tile(194, 2, c1, "o", true) == "mur", "1. voisines hors couloir : mur")
  -- 2. couloir qui traverse le côté NORD (mur le long de x en y = -6), bande le long de y, colonnes x = 10 et 11
  local c2 = band_y({}, -30, 5, 10, 1)
  for _, x in ipairs({ 10, 11 }) do
    local k, d, ax = Pc.tile(x, -6, c2, "n", true)
    check(k == "porte" and d == EAST and ax == "y", "2. côté nord traversé : porte horizontale, passage selon y (x=" .. x .. " : " .. tostring(k) .. " " .. tostring(d) .. ")")
  end
  -- 3. couloir LE LONG du mur (côté ouest, x = 194 et 195, le long de y) : la porte suit le couloir (passage selon y), pas le mur
  local c3 = band_y({}, -20, 20, 194, 1)
  local k3, d3, a3 = Pc.tile(194, 0, c3, "o", true)
  check(k3 == "porte" and d3 == EAST and a3 == "y", "3. couloir le long du mur : passage selon le couloir (y), porte horizontale (" .. tostring(k3) .. " " .. tostring(d3) .. ")")
  -- 4. sans la recherche des portes : la brèche reste, quelle que soit la géométrie
  check(Pc.tile(194, 3, c1, "o", false) == "breche" and Pc.tile(10, -6, c2, "n", false) == "breche" and Pc.tile(194, 0, c3, "o", nil) == "breche",
    "4. sans recherche des portes : brèche (rien de posé)")
  check(select(2, Pc.tile(194, 3, c1, "o", false)) == nil, "4. brèche : aucune direction rendue")
  -- 5. tuile hors couloir : mur, recherche ou non
  check(Pc.tile(0, 0, c1, "o", true) == "mur" and Pc.tile(0, 0, c1, "o", false) == "mur", "5. hors couloir : mur")
  -- 6. bout de couloir (1 voisine en x, 1 en y) : le passage traverse le mur du côté
  local c6 = band_x({}, 194, 194, 3, 1) -- deux tuiles (194, 3) et (194, 4) : bout de bande
  c6[P.tkey(195, 3)] = 7
  local k6o, d6o = Pc.tile(194, 3, c6, "o", true)
  local k6n, d6n = Pc.tile(194, 3, c6, "n", true)
  local k6x, d6x = Pc.tile(194, 3, c6, nil, true)
  check(k6o == "porte" and d6o == NORTH, "6. égalité, côté ouest : passage selon x, porte verticale (" .. tostring(d6o) .. ")")
  check(k6n == "porte" and d6n == EAST, "6. égalité, côté nord : passage selon y, porte horizontale (" .. tostring(d6n) .. ")")
  check(k6x == "porte" and d6x == NORTH, "6. égalité, côté inconnu : passage selon x (" .. tostring(d6x) .. ")")
  -- 7. ensemble vide (couloirs coupés, Build.NO_COULOIR) ou absent : mur partout
  check(Pc.tile(194, 3, {}, "o", true) == "mur" and Pc.tile(194, 3, nil, "o", true) == "mur", "7. aucun couloir : mur")
  -- 8. la clé est celle de Build.couloirs (P.tkey), pas une autre : une clé « x,y » ne compte pas
  check(Pc.tile(194, 3, { ["194,3"] = 7 }, "o", true) == "mur", "8. clé P.tkey seulement")
  return fails, n
end

local passes, failures = 0, 0
local base, nbase = suite(load_pc(SRC))
for _, m in ipairs(base) do print("  ECHEC : " .. m) end
failures = failures + #base
passes = passes + nbase - #base

local function mutate(old, new)
  local a, b = SRC:find(old, 1, true)
  if not a then return nil end
  return SRC:sub(1, a - 1) .. new .. SRC:sub(b + 1)
end
local mutants = {
  { "porte sans la recherche", "if not gates then return \"breche\" end", "" },
  { "directions inversées", "Pc.DIR = { x = 0, y = 2 }", "Pc.DIR = { x = 2, y = 0 }" },
  { "orientation selon le mur seulement", "  if nx > ny then return \"x\" end\n  if ny > nx then return \"y\" end\n", "" },
  { "égalité : passage le long du mur", "if side == \"n\" or side == \"s\" then return \"y\" end\n  return \"x\"", "if side == \"n\" or side == \"s\" then return \"x\" end\n  return \"y\"" },
  { "toute tuile est une porte", "if not (cor and cor[P.tkey(tx, ty)] ~= nil) then return \"mur\" end", "if not cor then return \"mur\" end" },
  { "voisines en y comptées en x", "local ny = (cor[P.tkey(tx, ty - 1)] ~= nil and 1 or 0) + (cor[P.tkey(tx, ty + 1)] ~= nil and 1 or 0)", "local ny = 0" },
}
local killed = 0
for _, m in ipairs(mutants) do
  local txt = mutate(m[2], m[3])
  if not txt then failures = failures + 1 print("  ECHEC : mutant « " .. m[1] .. " » : texte introuvable")
  else
    local ok, f = pcall(function() return (suite(load_pc(txt))) end)
    if (not ok) or #f > 0 then killed = killed + 1 passes = passes + 1 else failures = failures + 1 print("  ECHEC : mutant « " .. m[1] .. " » non détecté") end
  end
end
print(string.format("[PORTE-COULOIR] mutants refusés : %d sur %d", killed, #mutants))
print(string.format("[PORTE-COULOIR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
