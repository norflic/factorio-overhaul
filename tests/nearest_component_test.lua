--[[
  Lot COUT-600 (9/11) : P.nearest_component (shared/team/pose_paires.lua) rend EXACTEMENT ce que rendait P.component(P.sorted(...)) : mêmes
  tuiles, MÊME ORDRE, tables {x, y} neuves. Mesuré avant le lot (gisement de 600 % = 3 209 tuiles) : 3,4 M d'instructions (5,8 M avec deux
  gisements voisins dans le rayon lu) pour une pensée qui en vaut 0,6 M.
    1. équivalence sur des milliers de cas tirés d'une graine fixe : disques, trous, nuages à portées variées (écart de 1 à 6 tuiles), 2 à 4
       gisements voisins, coordonnées entières ou en demi-tuile, négatives, centre dans ou hors du gisement (jusqu'à 25 tuiles), doublons,
       entrée mélangée, portée de 0 à 4 ;
    2. cas limites : aucune tuile, une tuile, graine à plus de P.SEED_MAX, rien ne change l'entrée ;
    3. coût (debug.sethook, instructions, déterministe) : gisement ordinaire, 600 %, 600 % + deux voisins, contre l'ancien enchaînement ;
    4. mutants : une règle fausse dans la nouvelle fonction est vue par la comparaison.
  Usage, depuis la racine du mod : lua5.2 tests/nearest_component_test.lua
]]
package.path = "./?.lua;" .. package.path
local P = require("shared.team.pose_paires")

local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1; print("[NEAREST-COMP] ECHEC : " .. msg) end
end

local seed = 20261109
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return math.floor(seed / 65536) % n end -- bits hauts : les bas d'un congruentiel alternent
local function shuffle(t) for i = #t, 2, -1 do local j = rnd(i) + 1; t[i], t[j] = t[j], t[i] end return t end

local function same(a, b)
  if #a ~= #b then return false, "longueurs " .. #a .. " / " .. #b end
  for i = 1, #a do
    if a[i].x ~= b[i].x or a[i].y ~= b[i].y then return false, "rang " .. i .. " : " .. a[i].x .. "," .. a[i].y .. " / " .. b[i].x .. "," .. b[i].y end
  end
  return true
end

local function blob(cx, cy, r, out, half, holes, density)
  for x = cx - r, cx + r do
    for y = cy - r, cy + r do
      if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r and not (holes and holes(x, y)) and (not density or rnd(100) < density) then
        out[#out + 1] = { x = x + (half and 0.5 or 0), y = y + (half and 0.5 or 0) }
      end
    end
  end
  return out
end

local function gen_case()
  local half = rnd(2) == 0
  local sgn = rnd(2) == 0 and -1 or 1
  local ox, oy = sgn * rnd(400), (rnd(2) == 0 and -1 or 1) * rnd(400)
  local res = {}
  local nb = 1 + rnd(4)
  local density = ({ nil, 90, 60, 35 })[1 + rnd(4)]
  local holes
  if rnd(3) == 0 then
    local hx, hy, hr = ox + rnd(7) - 3, oy + rnd(7) - 3, 1 + rnd(4)
    holes = function(x, y) return (x - hx) ^ 2 + (y - hy) ^ 2 <= hr * hr end
  end
  for b = 1, nb do
    local r = 1 + rnd(b == 1 and 14 or 10)
    blob(ox + (b == 1 and 0 or (rnd(2 * r + 28) - r - 14)), oy + (b == 1 and 0 or (rnd(2 * r + 28) - r - 14)), r, res, half, b == 1 and holes or nil, density)
  end
  if rnd(8) == 0 and #res > 0 then res[#res + 1] = { x = res[1].x, y = res[1].y } end -- doublon
  shuffle(res)
  local cr = rnd(3) == 0 and 25 or 8
  local center = { x = ox + rnd(2 * cr + 1) - cr + (half and 0.5 or 0), y = oy + rnd(2 * cr + 1) - cr + (half and 0.5 or 0) }
  return res, center, rnd(5)
end

---------------------------------------------------------------------------------------------------
-- 1. Équivalence
---------------------------------------------------------------------------------------------------
local function equivalence(NC, n, quiet)
  local bad, nonempty = 0, 0
  for i = 1, n do
    local res, center, gap = gen_case()
    local copy = {}
    for k, r in ipairs(res) do copy[k] = { x = r.x, y = r.y } end
    local old = P.component(P.sorted(res, center), gap, center)
    local new = NC(res, gap, center)
    local ok, why = same(old, new)
    if #old > 0 then nonempty = nonempty + 1 end
    for k, r in ipairs(res) do if r.x ~= copy[k].x or r.y ~= copy[k].y then ok, why = false, "entrée modifiée" end end
    if not ok then bad = bad + 1; if bad <= 3 and not quiet then print("  cas " .. i .. " (" .. #res .. " tuiles, portée " .. gap .. ") : " .. tostring(why)) end end
  end
  return bad, nonempty
end
local N = 3000
local bad, nonempty = equivalence(P.nearest_component, N)
check(bad == 0, string.format("1.a équivalence : %d écart(s) sur %d cas", bad, N))
check(nonempty > N * 0.5, "1.b au moins la moitié des cas rendent une composante (" .. nonempty .. ")")

---------------------------------------------------------------------------------------------------
-- 2. Cas limites
---------------------------------------------------------------------------------------------------
check(#P.nearest_component({}, P.GAP, { x = 0, y = 0 }) == 0, "2.a aucune tuile : rien")
local one = P.nearest_component({ { x = 1.5, y = 2.5 } }, P.GAP, { x = 0, y = 0 })
check(#one == 1 and one[1].x == 1.5 and one[1].y == 2.5, "2.b une tuile : elle-même")
check(#P.nearest_component({ { x = 40.5, y = 0.5 } }, P.GAP, { x = 0, y = 0 }) == 0, "2.c graine à plus de P.SEED_MAX : rien")
local line = {}
for x = 0, 10 do line[#line + 1] = { x = x * 3 + 0.5, y = 0.5 } end -- pas de 3 : tout se touche à la portée 2 (reach 3)
check(#P.nearest_component(line, 2, { x = 0, y = 0 }) == 11, "2.d pas de 3 : une seule composante à la portée 2")
local line4 = {}
for x = 0, 10 do line4[#line4 + 1] = { x = x * 4 + 0.5, y = 0.5 } end
check(#P.nearest_component(line4, 2, { x = 0, y = 0 }) == 1, "2.e pas de 4 : chaque tuile seule à la portée 2")
local diag = {}
for k = 0, 8 do diag[#diag + 1] = { x = k * 3 + 0.5, y = k * 3 + 0.5 } end -- diagonale à (3, 3) : touche par le coin
check(#P.nearest_component(diag, 2, { x = 0, y = 0 }) == 9, "2.f diagonale à (3, 3) : une composante")
local diag2 = {}
for k = 0, 8 do diag2[#diag2 + 1] = { x = k * 3 + 0.5, y = k * 4 + 0.5 } end -- écart en y de 4 : rien ne se touche
check(#P.nearest_component(diag2, 2, { x = 0, y = 0 }) == 1, "2.g écart en y de 4 : seule la graine")


-- graine à égalité de distance : la plus petite en x, puis en y, quel que soit l'ordre de l'entrée (deux composantes de tailles différentes) ;
-- gisements symétriques, centre sur un coin de tuile : quatre graines possibles. Rend le nombre d'écarts (rejoué sur les mutants).
local function tie_cases(NC)
  local bad = 0
  local function chk(ok) if not ok then bad = bad + 1 end end
  for _, order in ipairs({ 1, 2 }) do
    local left = { { x = -3.5, y = 0.5 } }
    local right = { { x = 3.5, y = 0.5 }, { x = 4.5, y = 0.5 }, { x = 5.5, y = 0.5 } }
    local res = {}
    for _, t in ipairs(order == 1 and { right, left } or { left, right }) do for _, r in ipairs(t) do res[#res + 1] = r end end
    local c = { x = 0, y = 0.5 }
    chk(same(P.component(P.sorted(res, c), 2, c), NC(res, 2, c)))
    local up = { { x = 0.5, y = 3.5 }, { x = 0.5, y = -3.5 }, { x = 1.5, y = -3.5 } }
    local c2 = { x = 0.5, y = 0 }
    chk(same(P.component(P.sorted(up, c2), 2, c2), NC(up, 2, c2)))
    local up2 = { { x = 1.5, y = -3.5 }, { x = 0.5, y = 3.5 }, { x = 0.5, y = -3.5 } }
    chk(same(P.component(P.sorted(up2, c2), 2, c2), NC(up2, 2, c2)))
  end
  for r = 2, 9 do
    local res = shuffle(blob(0, 0, r, {}, false))
    local c = { x = 0.5, y = 0.5 }
    chk(same(P.component(P.sorted(res, c), 2, c), NC(res, 2, c)))
  end
  return bad
end
check(tie_cases(P.nearest_component) == 0, "2.h égalités de distance (graine) et disques symétriques : même résultat que l'ancien")

---------------------------------------------------------------------------------------------------
-- 3. Coût
---------------------------------------------------------------------------------------------------
local function instr(fn)
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 100)
  fn()
  debug.sethook()
  return c * 100
end
local function disc(cx, cy, r, out) return blob(cx, cy, r, out or {}, true) end
local COST_MAX = 1300000 -- instructions par appel au pire cas lu ci-dessous (l'ancien enchaînement : 3,4 M et 5,8 M)
local cases = {
  { "ordinaire (r=11, 377 tuiles)", disc(0, 0, 11) },
  { "600 % (r=32, 3 209 tuiles)", disc(0, 0, 32) },
  { "600 % + 2 gisements voisins (9 627 tuiles)", (function() local t = disc(0, 0, 32); disc(70, 0, 32, t); disc(-60, 50, 32, t); return t end)() },
}
local worst_new = 0
for _, c in ipairs(cases) do
  shuffle(c[2])
  local center = { x = 0.5, y = 0.5 }
  local old = instr(function() P.component(P.sorted(c[2], center), P.GAP, center) end)
  local new = instr(function() P.nearest_component(c[2], P.GAP, center) end)
  if new > worst_new then worst_new = new end
  print(string.format("[NEAREST-COMP] cout %-46s : ancien %d, nouveau %d instructions (x%.1f)", c[1], old, new, old / math.max(new, 1)))
end
check(worst_new <= COST_MAX, string.format("3.a coût au pire cas %d <= %d instructions", worst_new, COST_MAX))

---------------------------------------------------------------------------------------------------
-- 4. Mutants
---------------------------------------------------------------------------------------------------
local f = assert(io.open("shared/team/pose_paires.lua", "rb"))
local SRC = f:read("*a"); f:close()
local function variant(old, new)
  local a, b = SRC:find(old, 1, true)
  assert(a, "mutant introuvable : " .. old)
  assert(not SRC:find(old, b + 1, true), "mutant ambigu : " .. old)
  return load(SRC:sub(1, a - 1) .. new .. SRC:sub(b + 1), "mutant", "t")()
end
local MUTANTS = {
  { "tronçon : écart > portée devient >=", "if x - prev > reach then", "if x - prev >= reach then" },
  { "tronçon : écart > portée devient > portée + 1", "if x - prev > reach then", "if x - prev > reach + 1 then" },
  { "rangées voisines : une de moins", "for dy = 1, reach do", "for dy = 1, reach - 1 do" },
  { "rangées voisines : une de plus", "for dy = 1, reach do", "for dy = 1, reach + 1 do" },
  { "recouvrement sans la portée", "if ra.lo - reach <= rb.hi and rb.lo - reach <= ra.hi then", "if ra.lo <= rb.hi and rb.lo <= ra.hi then" },
  { "recouvrement d'un seul côté", "if ra.lo - reach <= rb.hi and rb.lo - reach <= ra.hi then", "if ra.lo - reach <= rb.hi then" },
  { "balayage : avance l'autre liste", "if ra.hi <= rb.hi then i = i + 1 else j = j + 1 end", "if ra.hi >= rb.hi then i = i + 1 else j = j + 1 end" },
  { "toute tuile gardée", "if find(run) == root then", "if true then" },
  { "graine non bornée", "if (seed.x - cx) ^ 2 + (seed.y - cy) ^ 2 > P.SEED_MAX * P.SEED_MAX then return {} end", "" },
  { "graine : départage en x oublié", "(d == sd and (r.x < seed.x or (r.x == seed.x and r.y < seed.y)))", "(d == sd and (r.y < seed.y))" },
  { "tri : départage en y oublié", "return ys_[i] < ys_[j]", "return false" },
  { "tri : distance seule", "local xi, xj = xs_[i], xs_[j]\n    if xi ~= xj then return xi < xj end", "" },
  { "fusion sans racine", "if pa ~= pb then pb.parent = pa end", "" },
  { "portée ignorée", "local reach = gap + 1", "local reach = 3" },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local ok, Mm = pcall(variant, m[2], m[3])
  local killed = not ok
  if ok then
    local ran, nbad = pcall(function() local b = equivalence(Mm.nearest_component, 600, true); return b + tie_cases(Mm.nearest_component) end)
    killed = (not ran) or nbad > 0
  end
  if killed then refused = refused + 1 end
  if os.getenv("NC_DBG") then print("  mutant", m[1], ok, killed) end
  check(killed, "4. mutant refusé : " .. m[1])
end
print(string.format("[NEAREST-COMP] mutants refusés : %d sur %d", refused, #MUTANTS))

print(string.format("[NEAREST-COMP] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
