--[[
  Lot COUT-600 (9/11) : Sites.census(surface, name, pos, hint) (script/faction/sites.lua) rend EXACTEMENT le même recensement qu'avec
  Sites.census(surface, name, pos) : mêmes champs (tuiles, quantité, boîte, centre, identifiant, coupure). L'indice (la boîte du gisement
  connue) ne sert qu'à lire moins de tuiles : un carré borné par la boîte au lieu de 96 x 96, puis 192 x 192 quand le gisement touche le bord.
    1. équivalence sur des centaines de mondes tirés d'une graine fixe : un ou plusieurs gisements voisins, trous, graine au centre ou
       décentrée (le carré de 96 est doublé), centre hors du gisement (un autre gisement plus proche), gisement épuisé en partie ou ayant
       GRANDI depuis la boîte connue (nouveaux chunks), indice d'un AUTRE gisement, indice qui ne contient pas le centre ;
    2. coût : tuiles lues par find_entities_filtered et instructions Lua (debug.sethook), avec et sans indice, gisement ordinaire et 600 % ;
    3. mutants : une règle de l'indice retirée est vue par la comparaison.
  Usage, depuis la racine du mod : lua5.2 tests/census_hint_test.lua
]]
package.path = "./?.lua;" .. package.path
local function stub() return setmetatable({}, { __index = function() return function() end end }) end
for _, m in ipairs({ "script.faction.state", "script.core.scheduler", "script.core.profiler", "script.core.trace", "script.faction.journal",
  "script.faction.character", "script.ai3.extension" }) do package.loaded[m] = stub() end
_G.global = {}
_G.game = {}

local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1; print("[CENSUS-HINT] ECHEC : " .. msg) end
end

local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local SRC = slurp("script/faction/sites.lua")
local function load_sites(src, tiles_cap)
  local S = assert(load(src, "sites", "t"))()
  if tiles_cap then S.CENSUS_TILES = tiles_cap end
  return S
end
local Sites = load_sites(SRC)

local seed = 20261109
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return math.floor(seed / 65536) % n end

-- Surface simulée : tuiles { x, y } (entités au centre de tuile, quantité fonction de la tuile) ; compte les lectures.
local reads, calls = 0, 0
local function surface_of(tiles)
  return { find_entities_filtered = function(q)
    calls = calls + 1
    local ar = q.area
    local out = {}
    for _, t in ipairs(tiles) do
      local px, py = t[1] + 0.5, t[2] + 0.5
      if px >= ar[1][1] and px < ar[2][1] and py >= ar[1][2] and py < ar[2][2] then
        out[#out + 1] = { position = { x = px, y = py }, amount = 100 + (t[1] * 7 + t[2] * 3) % 50 }
      end
    end
    reads = reads + #out
    return out
  end }
end
local function blob(cx, cy, r, out, holes, density)
  for x = cx - r, cx + r do
    for y = cy - r, cy + r do
      if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r and not (holes and holes(x, y)) and (not density or rnd(100) < density) then out[#out + 1] = { x, y } end
    end
  end
  return out
end
local function shuffle(t) for i = #t, 2, -1 do local j = rnd(i) + 1; t[i], t[j] = t[j], t[i] end return t end

local FIELDS = { "tiles", "amount", "x0", "y0", "x1", "y1", "cx", "cy", "id", "cut" }
local function same(a, b)
  if a == nil or b == nil then return a == b end
  for _, k in ipairs(FIELDS) do if a[k] ~= b[k] then return false, k .. " : " .. tostring(a[k]) .. " / " .. tostring(b[k]) end end
  return true
end

-- Un monde : retourne tiles, pos, hint (la boîte d'un recensement précédent, éventuellement périmée), description
local function gen_world(S)
  local tiles = {}
  local ox, oy = (rnd(2) == 0 and -1 or 1) * rnd(600), (rnd(2) == 0 and -1 or 1) * rnd(600)
  local nb = 1 + rnd(3)
  local density = ({ nil, 95, 70 })[1 + rnd(3)]
  local r1 = 3 + rnd(26)
  local centers = {}
  for b = 1, nb do
    local r = b == 1 and r1 or (3 + rnd(20))
    local cx = ox + (b == 1 and 0 or (rnd(2 * (r + r1 + 30)) - (r + r1 + 30)))
    local cy = oy + (b == 1 and 0 or (rnd(2 * (r + r1 + 30)) - (r + r1 + 30)))
    centers[b] = { cx, cy, r }
    local holes
    if rnd(3) == 0 then local hx, hy, hr = cx + rnd(7) - 3, cy + rnd(7) - 3, 1 + rnd(3); holes = function(x, y) return (x - hx) ^ 2 + (y - hy) ^ 2 <= hr * hr end end
    blob(cx, cy, r, tiles, holes, density)
  end
  shuffle(tiles)
  -- centre : proche du centre du gisement 1, décentré (jusqu'à r1 + 6), ou près d'un autre gisement
  local pick = rnd(4)
  local c = centers[pick == 3 and nb or 1]
  local spread = pick == 0 and 2 or (pick == 1 and r1 + 6 or (pick == 2 and 40 or c[3] + 4))
  local pos = { x = c[1] + 0.5 + rnd(2 * spread + 1) - spread, y = c[2] + 0.5 + rnd(2 * spread + 1) - spread }
  -- indice : la boîte du recensement du monde AVANT l'évolution (sans indice), sur le gisement de la graine
  local before = S.census(surface_of(tiles), "res", pos)
  local hint = before and { x0 = before.x0, y0 = before.y0, x1 = before.x1, y1 = before.y1 } or nil
  local evo = rnd(5)
  local desc = "evolution " .. evo
  if evo == 1 then -- épuisé en partie
    local keep = {}
    for _, t in ipairs(tiles) do if rnd(100) >= 12 then keep[#keep + 1] = t end end
    tiles = keep
  elseif evo == 2 and before then -- a grandi : nouveaux chunks au bord de la boîte connue
    blob(before.x1 + 2, math.floor((before.y0 + before.y1) / 2), 6 + rnd(12), tiles, nil, 90)
  elseif evo == 3 then -- indice d'un autre gisement (ou périmé de plusieurs dizaines de tuiles)
    hint = { x0 = ox + 150, y0 = oy + 150, x1 = ox + 190, y1 = oy + 190 }
  elseif evo == 4 and before then -- indice qui ne contient pas le centre
    hint = { x0 = before.x0 + 1, y0 = before.y0 + 1, x1 = before.x0 + 3, y1 = before.y0 + 3 }
  end
  return tiles, pos, hint, desc
end

local function equivalence(S, n, quiet)
  local bad, hinted_ok = 0, 0
  for i = 1, n do
    local tiles, pos, hint, desc = gen_world(Sites)
    reads, calls = 0, 0
    local old = S.census(surface_of(tiles), "res", pos)
    local r_old = reads
    reads, calls = 0, 0
    local new = S.census(surface_of(tiles), "res", pos, hint)
    local r_new = reads
    local ok, why = same(old, new)
    if ok and old and hint and r_new < r_old then hinted_ok = hinted_ok + 1 end
    if not ok then
      bad = bad + 1
      if bad <= 3 and not quiet then print(string.format("  monde %d (%d tuiles, %s) : %s", i, #tiles, desc, tostring(why))) end
    end
  end
  return bad, hinted_ok
end

local N = 400
local bad, saved = equivalence(Sites, N)
check(bad == 0, string.format("1.a équivalence : %d écart(s) sur %d mondes", bad, N))
check(saved > N * 0.2, "1.b l'indice lit moins de tuiles dans au moins un monde sur cinq (" .. saved .. " sur " .. N .. ")")


-- Mondes ciblés (kill des mutants) : un gisement 1 (r=6, à l'origine) dont la boîte est l'indice, un gisement 2 (r=3) plus près du centre que
-- lui mais hors du carré lu (ou juste dehors de la boîte + marge) ; le recensement sans indice choisit la graine dans le gisement 2.
local function targeted(S)
  local bad = 0
  local worlds = {
    { dx = 31, dy = 0, px = 18.5, py = 0.5 },
    { dx = 18, dy = 0, px = 14.5, py = 0.5 }, { dx = -18, dy = 0, px = -13.5, py = 0.5 },
    { dx = 0, dy = 18, px = 0.5, py = 14.5 }, { dx = 0, dy = -18, px = 0.5, py = -13.5 },
  }
  for _, w in ipairs(worlds) do
    local tiles = blob(0, 0, 6, {}, nil, nil)
    blob(w.dx, w.dy, 3, tiles, nil, nil)
    shuffle(tiles)
    local pos = { x = w.px, y = w.py }
    local hint = { x0 = -6, y0 = -6, x1 = 7, y1 = 7 }
    local ref = Sites.census(surface_of(tiles), "res", pos)
    local got = S.census(surface_of(tiles), "res", pos, hint)
    if not same(ref, got) then bad = bad + 1 end
  end
  return bad
end
check(targeted(Sites) == 0, "1.f centre près d'un autre gisement que celui de l'indice : même résultat")

-- sans tuile, tuile seule, coupure (plafond de tuiles), indice nil
do
  reads, calls = 0, 0
  local empty = surface_of({})
  check(Sites.census(empty, "res", { x = 0.5, y = 0.5 }, { x0 = -5, y0 = -5, x1 = 5, y1 = 5 }) == nil, "1.c aucune tuile : rien, avec indice")
  local one = surface_of({ { 3, 4 } })
  local a, b = Sites.census(one, "res", { x = 3.5, y = 4.5 }), Sites.census(one, "res", { x = 3.5, y = 4.5 }, { x0 = 3, y0 = 4, x1 = 4, y1 = 5 })
  check(same(a, b) and a.tiles == 1, "1.d une tuile")
  local S2 = load_sites(SRC, 150)
  local big = blob(0, 0, 14, {}, nil, nil) -- 600 tuiles : coupée à 150
  local c1 = S2.census(surface_of(big), "res", { x = 0.5, y = 0.5 })
  local c2 = S2.census(surface_of(big), "res", { x = 0.5, y = 0.5 }, { x0 = -14, y0 = -14, x1 = 15, y1 = 15 })
  check(same(c1, c2) and c1.cut == true, "1.e composante coupée au plafond de tuiles : même résultat, cut vrai")
end

---------------------------------------------------------------------------------------------------
-- 2. Coût
---------------------------------------------------------------------------------------------------
local function instr(fn)
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 100)
  local r = fn()
  debug.sethook()
  return c * 100, r
end
local COST_MAX = 1300000 -- instructions Lua au pire cas avec indice (sans indice : 0,93 M et 2,3 à 2,8 M mesurés)
local worst_hint = 0
for _, c in ipairs({ { "ordinaire (r=11)", 11, 0 }, { "600 % (r=32), graine au centre", 32, 0 }, { "600 % (r=32), graine décentrée de 22", 32, 22 } }) do
  local tiles = blob(0, 0, c[2], {}, nil, nil)
  local t2 = blob(0, 0, c[2], {}, nil, nil)
  blob(70, 0, c[2], t2) -- un gisement voisin dans le même carré de 192
  if c[2] == 32 then blob(0, 75, 32, t2) end
  shuffle(t2)
  local pos = { x = c[3] + 0.5, y = 0.5 }
  local hint = { x0 = -c[2], y0 = -c[2], x1 = c[2] + 1, y1 = c[2] + 1 }
  reads, calls = 0, 0
  local n_old = instr(function() return Sites.census(surface_of(t2), "res", pos) end)
  local r_old = reads
  reads, calls = 0, 0
  local n_new = instr(function() return Sites.census(surface_of(t2), "res", pos, hint) end)
  local r_new = reads
  if n_new > worst_hint then worst_hint = n_new end
  print(string.format("[CENSUS-HINT] cout %-40s : sans indice %d instr, %d tuiles lues ; avec indice %d instr, %d tuiles lues", c[1], n_old, r_old, n_new, r_new))
end
check(worst_hint <= COST_MAX, string.format("2.a coût avec indice au pire cas %d <= %d instructions", worst_hint, COST_MAX))

---------------------------------------------------------------------------------------------------
-- 3. Mutants
---------------------------------------------------------------------------------------------------
local MUTANTS = {
  { "graine proche non exigée", "r and r.sd <= near * near and not r.cut", "r and not r.cut" },
  { "bord du carré lu non contrôlé", "and not touches_square(r, ax0, ay0, ax1, ay1)\n", "\n" },
  { "bord du carré maximal non contrôlé", "\n        and not touches_square(r, pos.x - mx, pos.y - mx, pos.x + mx, pos.y + mx) then", " then" },
  { "carré lu sans le carré proche du centre", "local ax0, ay0 = math.min(hint.x0 - m, pos.x - near), math.min(hint.y0 - m, pos.y - near)", "local ax0, ay0 = hint.x0 - m, hint.y0 - m" },
  { "carré lu sans le carré proche du centre (bord droit)", "local ax1, ay1 = math.max(hint.x1 + m, pos.x + near), math.max(hint.y1 + m, pos.y + near)", "local ax1, ay1 = hint.x1 + m, hint.y1 + m" },
}
local function mutant_module(old, new)
  local a, b = SRC:find(old, 1, true)
  assert(a, "mutant introuvable : " .. old)
  assert(not SRC:find(old, b + 1, true), "mutant ambigu : " .. old)
  return load_sites(SRC:sub(1, a - 1) .. new .. SRC:sub(b + 1))
end
local refused = 0
for _, m in ipairs(MUTANTS) do
  local ok, Mm = pcall(mutant_module, m[2], m[3])
  local killed = not ok
  if ok then
    local ran, nbad = pcall(function() return (equivalence(Mm, 400, true)) + targeted(Mm) end)
    killed = (not ran) or nbad > 0
  end
  if killed then refused = refused + 1 end
  check(killed, "3. mutant refusé : " .. m[1])
end
print(string.format("[CENSUS-HINT] mutants refusés : %d sur %d", refused, #MUTANTS))

print(string.format("[CENSUS-HINT] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
