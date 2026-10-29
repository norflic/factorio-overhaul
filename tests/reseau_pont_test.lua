--[[
  Lot RESEAU-VIVANT : test hors jeu des ponts (shared/team/reseau_pont.lua) : plus court écart îlot / réseau alimenté, plusieurs
  îlots, écart trop grand, réseau déjà alimenté ignoré, portée commune, déterminisme, aucun nom d'objet, mutants.
  Usage : lua5.2 tests/reseau_pont_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function read(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end
local SRC = read("shared/team/reseau_pont.lua")
local function load_b(src) local fn, err = load(src, "=pont", "t"); assert(fn, err); return fn() end
local B = load_b(SRC)

local function pole(x, y, id, wire) return { x = x, y = y, id = id, wire = wire or 7.5 } end

local poles = { pole(0, 0, 1), pole(7, 0, 1), pole(30, 0, 2), pole(37, 0, 2), pole(60, 40, 3), pole(14, 9, 1) }
local g = B.gaps(poles, { [2] = true }, { [1] = true })
check(#g == 1 and g[1].id == 2, "un ilot, un pont")
check(g[1].a == 3 and g[1].b == 6 and math.abs(g[1].d - math.sqrt(337)) < 1e-9, "plus court ecart : poteau 3 de l'ilot au poteau 6 du reseau (18,4 tuiles)")
check(g[1].reach == 7.5 and B.useful(g[1]), "portee de fil commune, pont utile")

g = B.gaps(poles, { [2] = true, [3] = true }, { [1] = true })
check(#g == 1 and g[1].id == 2, "l'ilot 3 est a plus de 45 tuiles : pas de pont")
g = B.gaps(poles, { [2] = true, [3] = true }, { [1] = true }, 80)
check(#g == 2 and g[1].id == 2 and g[2].id == 3, "plafond releve : deux ponts, le plus court d'abord")
g = B.gaps(poles, { [1] = true, [2] = true }, { [1] = true })
check(#g == 1 and g[1].id == 2, "un reseau deja alimente n'a pas besoin de pont")
g = B.gaps(poles, {}, { [1] = true })
check(#g == 0, "aucun reseau a relier")
g = B.gaps(poles, { [2] = true }, {})
check(#g == 0, "aucun reseau alimente : rien a relier")
local poles2 = { pole(0, 0, 1, 9), pole(20, 0, 2, 7.5) }
g = B.gaps(poles2, { [2] = true }, { [1] = true })
check(g[1].reach == 7.5, "portee commune = la plus courte")
check(not B.useful({ reach = 0, d = 5 }), "poteau sans portee : pas de pont")
-- egalite : le plus petit indice
local poles3 = { pole(0, 0, 1), pole(10, 0, 2), pole(10, 0, 2), pole(20, 0, 1) }
g = B.gaps(poles3, { [2] = true }, { [1] = true })
check(g[1].a == 2 and g[1].b == 1, "egalite : indices les plus petits")
-- determinisme
local a1 = B.gaps(poles, { [2] = true, [3] = true }, { [1] = true }, 80)
local a2 = B.gaps(poles, { [2] = true, [3] = true }, { [1] = true }, 80)
check(a1[1].a == a2[1].a and a1[2].id == a2[2].id, "determinisme")
-- aucun nom d'objet
do
  local s = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  for _, w in ipairs({ "boiler", "steam", "engine", "pump", "iron", "coal", "fo%-", "electric" }) do check(not s:find(w), "aucun nom d'objet (" .. w .. ")") end
end

local MUT = {
  { "reseau alimente confondu avec ilot", "if p.id and need[p.id] and not live[p.id] and best[p.id] == nil then", "if p.id and need[p.id] and best[p.id] == nil then" },
  { "plus long ecart choisi", "if not bd or d < bd - 1e-9 then bd, ba, bb = d, i, j end", "if not bd or d > bd + 1e-9 then bd, ba, bb = d, i, j end" },
  { "plafond ignore", "if bd and bd <= maxgap then", "if bd then" },
  { "portee non commune", "math.min(poles[ba].wire or 0, poles[bb].wire or 0)", "math.max(poles[ba].wire or 0, poles[bb].wire or 0)" },
  { "tri par id seul", "if x.d ~= y.d then return x.d < y.d end", "" },
  { "pont inutile accepte", "return g.reach > 0 and g.d > 0", "return true" },
  { "poteaux sans reseau comptes vivants", "if q.id and live[q.id] then", "if live[q.id] or not q.id then" },
}
local function battery(B2)
  local bad = 0
  local function exp(c) if not c then bad = bad + 1 end end
  local gg = B2.gaps(poles, { [2] = true }, { [1] = true })
  exp(#gg == 1 and gg[1].a == 3 and gg[1].b == 6)
  gg = B2.gaps(poles, { [2] = true, [3] = true }, { [1] = true })
  exp(#gg == 1)
  gg = B2.gaps(poles, { [2] = true, [3] = true }, { [1] = true }, 80)
  exp(#gg == 2 and gg[1].id == 2)
  gg = B2.gaps(poles, { [1] = true, [2] = true }, { [1] = true })
  exp(#gg == 1 and gg[1].id == 2)
  gg = B2.gaps(poles2, { [2] = true }, { [1] = true })
  exp(gg[1].reach == 7.5)
  exp(not B2.useful({ reach = 0, d = 5 }))
  local np = { pole(0, 0, 1), pole(5, 0, nil), pole(30, 0, 2) }
  gg = B2.gaps(np, { [2] = true }, { [1] = true })
  exp(gg[1] and gg[1].b == 1)
  local tie = { pole(0, 0, 1), pole(30, 0, 2), pole(0, 50, 3), pole(30, 50, 1) }
  gg = B2.gaps(tie, { [2] = true, [3] = true }, { [1] = true })
  exp(#gg == 2 and gg[1].id == 2)
  local two = { pole(0, 0, 1), pole(30, 0, 2), pole(0, 10, 3), pole(40, 0, 4) }
  gg = B2.gaps(two, { [2] = true, [3] = true }, { [1] = true })
  exp(#gg == 2 and gg[1].id == 3 and gg[2].id == 2)
  return bad
end
check(battery(B) == 0, "batterie sur le code vrai")
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local pos = SRC:find(m[2], 1, true)
  if not pos then kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local ok, B2 = pcall(load_b, SRC:sub(1, pos - 1) .. m[3] .. SRC:sub(pos + #m[2]))
    if not ok then refused = refused + 1
    else
      local ok2, bad = pcall(battery, B2)
      if not ok2 or bad > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
    end
  end
end
check(#kept == 0, "mutants NON refuses : " .. table.concat(kept, " ; "))
print(string.format("[PONT] mutants refuses : %d sur %d", refused, #MUT))
print(string.format("[PONT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
