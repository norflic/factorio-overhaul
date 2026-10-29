--[[
  Lot POTEAUX-V2 : test hors jeu de shared/team/pole_dedupe.lua : cas de doublon, de refus (q non pose, q hors reseau de centrale, voisin pose d'un autre
  reseau, voisin prevu hors de portee de q), portee commune, determinisme, aucun nom d'objet, mutants.
  Usage : lua5.2 tests/pole_dedupe_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function read(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end
local SRC = read("shared/team/pole_dedupe.lua")
local function load_d(src) local fn, err = load(src, "=dedupe", "t"); assert(fn, err); return fn() end
local D = load_d(SRC)

local function pole(x, y, posed, net, wire) return { x = x, y = y, posed = posed, net = net, wire = wire or 7.5 } end
local E = { x = 111.5, y = 10.5, wire = 7.5 }
local GEN = { [1] = true }

local base = { pole(110.5, 10.5, true, 1), pole(110.5, 3.5, true, 1), pole(110.5, 17.5, false, nil) }
local ok, q = D.redundant(E, base, GEN)
check(ok and q == 1, "doublon a 1 tuile d'un poteau pose et alimente, voisins joignables : saute")
local t = { pole(110.5, 10.5, false, nil), pole(110.5, 3.5, true, 1) }
check(not D.redundant(E, t, GEN), "q seulement prevu : pas un doublon")
check(not D.redundant(E, { pole(110.5, 10.5, false, 1) }, GEN), "q marque non pose, meme avec un reseau : pas un doublon")
t = { pole(110.5, 10.5, true, 7), pole(110.5, 3.5, true, 7) }
check(not D.redundant(E, t, GEN), "q pose hors du reseau d'une centrale : pas un doublon")
t = { pole(108.0, 10.5, true, 1) }
check(not D.redundant(E, t, GEN), "q a 3,5 tuiles : trop loin")
t = { pole(109.5, 10.5, true, 1) }
check(D.redundant(E, t, GEN), "q a exactement 2 tuiles : doublon")
t = { pole(110.5, 10.5, true, 1), pole(111.5, 3.5, true, 9) }
check(not D.redundant(E, t, GEN), "voisin pose d'un autre reseau : e fait le pont, pas un doublon")
t = { pole(110.5, 10.5, true, 1), pole(111.5, 3.5, true, nil) }
check(not D.redundant(E, t, GEN), "voisin pose de reseau inconnu : prudence")
t = { pole(111.5, 12.5, true, 1), pole(111.5, 3.5, false, nil) }
check(not D.redundant(E, t, GEN), "voisin prevu hors de portee de q : pas un doublon")
t = { pole(111.5, 11.5, true, 1), pole(111.5, 4.5, false, nil) }
check(D.redundant(E, t, GEN), "voisin prevu atteint aussi par q : doublon")
t = { pole(110.5, 10.5, true, 1), pole(111.5, 25.5, false, nil, 30) }
check(D.redundant(E, t, GEN), "voisin a 15 tuiles : hors de la portee de e (7,5) meme si lui porte plus loin")
check(not D.redundant(E, {}, GEN), "aucun poteau alentour")
t = { pole(112.5, 10.5, true, 1), pole(110.5, 10.5, true, 1) }
local _, qi = D.redundant(E, t, GEN)
check(qi == 2, "ex aequo : le plus petit (y, x)")
check(select(2, D.redundant(E, t, GEN)) == qi, "determinisme")
do
  local s = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  for _, w in ipairs({ "boiler", "steam", "engine", "pump", "iron", "coal", "fo%-", "electric" }) do check(not s:find(w), "aucun nom d'objet (" .. w .. ")") end
end

local MUT = {
  { "q non pose accepte", "if p.posed and p.net ~= nil and gen[p.net] then", "if p.net ~= nil and gen[p.net] then" },
  { "reseau de centrale ignore", "if p.posed and p.net ~= nil and gen[p.net] then", "if p.posed then" },
  { "rayon de doublon trop large", "dd <= D.DUP_R * D.DUP_R + 1e-9", "dd <= 9 * D.DUP_R * D.DUP_R" },
  { "voisin pose d'un autre reseau ignore", "if n.net == nil or n.net ~= pq.net then return false", "if false then return false" },
  { "voisin prevu hors de q ignore", "if d2(pq, n) > rq * rq + 1e-9 then return false", "if false then return false" },
  { "portee la plus longue", "return math.min(a.wire or 0, b.wire or 0)", "return math.max(a.wire or 0, b.wire or 0)" },
  { "plus loin choisi", "if not qd or dd < qd - 1e-9", "if not qd or dd > qd + 1e-9" },
  { "voisin de reseau inconnu accepte", "if n.net == nil or n.net ~= pq.net then", "if n.net ~= nil and n.net ~= pq.net then" },
}
local function battery(M)
  local bad = 0
  local function exp(c) if not c then bad = bad + 1 end end
  exp(M.redundant(E, base, GEN) == true)
  exp(not M.redundant(E, { pole(110.5, 10.5, false, nil), pole(110.5, 3.5, true, 1) }, GEN))
  exp(not M.redundant(E, { pole(110.5, 10.5, false, 1) }, GEN))
  exp(not M.redundant(E, { pole(110.5, 10.5, true, 7), pole(110.5, 3.5, true, 7) }, GEN))
  exp(not M.redundant(E, { pole(108.0, 10.5, true, 1) }, GEN))
  exp(not M.redundant(E, { pole(110.5, 10.5, true, 1), pole(111.5, 3.5, true, 9) }, GEN))
  exp(not M.redundant(E, { pole(110.5, 10.5, true, 1), pole(111.5, 3.5, true, nil) }, GEN))
  exp(not M.redundant(E, { pole(111.5, 12.5, true, 1), pole(111.5, 3.5, false, nil) }, GEN))
  exp(M.redundant(E, { pole(111.5, 11.5, true, 1), pole(111.5, 4.5, false, nil) }, GEN))
  exp(M.redundant(E, { pole(110.5, 10.5, true, 1), pole(111.5, 25.5, false, nil, 30) }, GEN))
  exp(not M.redundant(E, { pole(104.0, 10.5, true, 1) }, GEN))
  local _, i2 = M.redundant(E, { pole(112.5, 10.5, true, 1), pole(110.5, 10.5, true, 1) }, GEN)
  exp(i2 == 2)
  local _, i3 = M.redundant(E, { pole(110.5, 11.5, true, 1), pole(111.5, 10.5, true, 1) }, GEN)
  exp(i3 == 2)
  -- un voisin pose a 7 tuiles de portee propre 3 : portee commune 3, e ne l'atteint pas, donc doublon
  exp(M.redundant(E, { pole(110.5, 10.5, true, 1), pole(111.5, 3.5, true, 9, 3) }, GEN) == true)
  return bad
end
check(battery(D) == 0, "batterie sur le code vrai")
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local pos = SRC:find(m[2], 1, true)
  if not pos then kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local okc, M2 = pcall(load_d, SRC:sub(1, pos - 1) .. m[3] .. SRC:sub(pos + #m[2]))
    if not okc then refused = refused + 1
    else
      local ok2, bad = pcall(battery, M2)
      if not ok2 or bad > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
    end
  end
end
check(#kept == 0, "mutants NON refuses : " .. table.concat(kept, " ; "))
print(string.format("[DEDUPE] mutants refuses : %d sur %d", refused, #MUT))
print(string.format("[DEDUPE] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
