--[[
  Lot C3C : bande du cadre la plus proche de la zone d'un ordre Maj+A (shared/team/migration_champ.lua M.near_order, branché dans begin_band).
  Scène du banc C4B-preemption : ordre gisement en (44, -36) rayon 11 ; champ 100001, axe x, bandes -13, -29, -53 (pas 16) ; avant, la
  bande -13 (la plus proche du QG) partait d'abord. Usage : lua5.2 tests/c3c_ordre_bande_test.lua (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local function read(p) local fh = assert(io.open(p, "rb")) local s = fh:read("*a") fh:close() return s end
local SRC = read("shared/team/migration_champ.lua")
local passes, failures = 0, 0
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end end

local function suite(Mg)
  local before = failures
  check(type(Mg.near_order) == "function", "Mg.near_order existe")
  if type(Mg.near_order) ~= "function" then return failures - before end
  local order = { -13, -29, -53, 3, 19 }
  local od = { x = 44, y = -36, r = 11 }
  local out = Mg.near_order(order, "x", od)
  check(out[1] == -53 and out[2] == -29, "bandes qui coupent le cercle d'abord, la plus proche du centre en tete (" .. tostring(out[1]) .. ", " .. tostring(out[2]) .. ")")
  check(out[3] == -13, "puis la plus proche hors du cercle")
  local o2 = Mg.near_order({ 0, 16, 32, 48 }, "x", { x = 0, y = 31, r = 1 })
  check(o2[1] == 16 and o2[2] == 32, "centre au bord haut d'une bande : la bande qui le contient d'abord (milieu de bande, pas son debut)")
  check(#out == #order and order[1] == -13, "liste neuve, meme taille, ordre du cadre intact")
  local outy = Mg.near_order({ 100, 116, 132 }, "y", { x = 120, y = 0, r = 2 })
  check(outy[1] == 116, "axe y : la coordonnee en travers est x")
  local far = Mg.near_order({ 0, 16, 32 }, "x", { x = 0, y = 500, r = 5 })
  check(far[1] == 32 and far[3] == 0, "aucune bande dans le cercle : la plus proche d'abord")
  local same = Mg.near_order({ 5, 1 }, "x", nil)
  check(same[1] == 5 and same[2] == 1, "sans ordre : ordre du cadre garde")
  return failures - before
end

print("== 1. Regle pure")
local M = assert(load(SRC, "=migration_champ"))()
suite(M)
print("== 2. Branchement")
local MS = read("script/team/migration_champ.lua")
check(MS:find('seq = Mg.near_order(st.order, st.frame and st.frame.axis, od)', 1, true) ~= nil, "begin_band lit l'ordre Maj+A vivant du champ")
check(MS:find('if od.kind == "gisement" and od.band_fid == o.id and not od.t_fin and od.x and od.y then', 1, true) ~= nil, "seulement l'ordre gisement vivant de CE champ")
print("== 3. Mutants")
local mutants = {
  { "pas ignore", "local mid = x + pitch / 2", "local mid = x" },
  { "distance ignoree", "if ra.d ~= rb.d then return ra.d < rb.d end", "" },
  { "axe inverse", "local c = (axis == \"x\") and od.y or od.x", "local c = (axis == \"x\") and od.x or od.y" },
}
local killed = 0
for _, mu in ipairs(mutants) do
  local a, b = SRC:find(mu[2], 1, true)
  check(a ~= nil, "mutant applicable : " .. mu[1])
  if a then
    local sp, sf = passes, failures
    local silent = print
    _G.print = function() end
    local ok, Mm = pcall(function() return assert(load(SRC:sub(1, a - 1) .. mu[3] .. SRC:sub(b + 1), "=m"))() end)
    local res = ok and select(2, pcall(suite, Mm)) or 1
    _G.print = silent
    passes, failures = sp, sf
    local k = (not ok) or type(res) ~= "number" or res > 0
    check(k, "mutant refuse : " .. mu[1])
    if k then killed = killed + 1 end
  end
end
print(string.format("[C3C] mutants %d refuses sur %d", killed, #mutants))
print(string.format("[C3C] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
