--[[
  Lot GEANT-D-ABORD (9/11) : le nombre RÉEL de tuiles d'un gisement entre dans la valeur d'un site, le rang des sites de la capitalisation et le
  départage des champs de bande, sans jamais battre un danger, une contestation ou une impossibilité d'atteindre.
  Constat (journal INTEG-MAX, graine 1618033988, votre équipe à 116 min) : fer 187 / 2 164 tuiles couvertes (14 foreuses), cuivre 8 / 1 299 ; charbon
  de 197 tuiles couvert à 63 %. Causes lues dans le code : shared/faction/valeur.lua (V.components : richesse sur 64 tuiles au plus, aucune taille),
  script/faction/sites.lua (probe : un chunk, 64 tuiles), shared/ai3/capitalisation.lua (les 3 sites les plus PROCHES seuls évalués), Th.order (le numéro).
    1. V.size_gain : 0 sous V.SIZE_SMALL, V.SIZE_MAX à V.SIZE_GIANT, linéaire, entier, monotone ;
    2. V.components : le gain est ajouté à la valeur ; jamais avec du danger, de la contestation ou un accès >= 1 000 ; borné par V.SIZE_MAX ; propriété
       sur 5 000 sites tirés d'une graine fixe (valeur avec / sans taille) ;
    3. Ca.size_credit, Ca.site_rank : crédit plafonné, ne change que l'ordre ; un géant plus loin passe devant un petit cercle plus près, pas devant un
       site beaucoup plus près ;
    4. Th.order : départage par tuiles réelles APRÈS « voulu », rang de minerai, extraction thermique, plaque en manque ; le numéro en dernier ;
    5. Sites.deposit_of : comptage du moteur d'abord, recensement borné seulement pour un grand voisinage, UNE fois par gisement (cache f.dep_boxes
       plafonné) ; coût (debug.sethook) ;
    6. mutants.
  Usage, depuis la racine du mod : lua5.2 tests/geant_test.lua
]]
package.path = "./?.lua;" .. package.path
local function stub() return setmetatable({}, { __index = function() return function() end end }) end
for _, m in ipairs({ "script.faction.state", "script.core.scheduler", "script.core.profiler", "script.core.trace", "script.faction.journal",
  "script.faction.character", "script.ai3.extension" }) do package.loaded[m] = stub() end
_G.global = {}
_G.game = {}

local V = require("shared.faction.valeur")
local Ca = require("shared.ai3.capitalisation")
local Th = require("shared.team.thermique")

local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1; print("[GEANT] ECHEC : " .. msg) end
end
local seed = 20261109
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return math.floor(seed / 65536) % n end
local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end

---------------------------------------------------------------------------------------------------
-- 1. V.size_gain
---------------------------------------------------------------------------------------------------
check(V.size_gain(nil) == 0 and V.size_gain(0) == 0 and V.size_gain(V.SIZE_SMALL) == 0 and V.size_gain(64) == 0, "1.a inconnu, vide, petit : 0")
check(V.size_gain(V.SIZE_GIANT) == V.SIZE_MAX and V.size_gain(1e6) == V.SIZE_MAX, "1.b géant : le maximum, plafonné")
do
  local prev, mono, int = 0, true, true
  for t = 0, 4000, 7 do
    local g = V.size_gain(t)
    if g < prev then mono = false end
    if g ~= math.floor(g) or g < 0 or g > V.SIZE_MAX then int = false end
    prev = g
  end
  check(mono and int, "1.c monotone, entier, entre 0 et V.SIZE_MAX")
end

---------------------------------------------------------------------------------------------------
-- 2. V.components
---------------------------------------------------------------------------------------------------
local function ctx_of(o)
  o = o or {}
  return { hq = { x = 0, y = 0 }, anchors = o.anchors or {}, rivals = o.rivals or {}, lost = o.lost or {}, tick = 0, ambition = 1000, prudence = 1000, appetite = 1000 }
end
do
  local s0 = { x = 80, y = 0, rich = 30000, water = false, rough = 0, cliffs = 0 }
  local s1 = { x = 80, y = 0, rich = 30000, water = false, rough = 0, cliffs = 0, deposit = 3000 }
  local a, b = V.components(s0, ctx_of()), V.components(s1, ctx_of())
  check(b.size == V.SIZE_MAX and b.value == a.value + V.SIZE_MAX and a.size == 0, "2.a gisement géant sans danger : valeur + V.SIZE_MAX")
  local dang = ctx_of({ rivals = { { x = 100, y = 0, hq = false } } })
  local c0, c1 = V.components(s0, dang), V.components(s1, dang)
  check(c1.size == 0 and c1.value == c0.value and c0.danger > 0, "2.b géant près d'un avant-poste rival : aucun gain (le danger gagne)")
  local hq = ctx_of({ rivals = { { x = 300, y = 0, hq = true } } })
  check(V.components(s1, hq).size == 0 and V.components(s1, hq).danger > 0, "2.c géant près d'un QG rival : aucun gain")
  local far = { x = 900, y = 0, rich = 30000, deposit = 3000 }
  local cf = V.components(far, ctx_of())
  check(cf.access >= 1000 and cf.size == 0, "2.d géant hors de portée (accès " .. cf.access .. "): aucun gain")
  local lost = ctx_of({ lost = { { x = 80, y = 10, tick = 0 } } })
  check(V.components(s1, lost).size == 0, "2.e géant sur un site perdu récemment : aucun gain")
end
do
  local bad, n_gain = 0, 0
  for _ = 1, 5000 do
    local site = { x = rnd(600) - 300, y = rnd(600) - 300, rich = rnd(200000), water = rnd(2) == 0, rough = rnd(30), cliffs = rnd(4) }
    local ctx = ctx_of({ anchors = rnd(2) == 0 and { { x = rnd(200) - 100, y = rnd(200) - 100 } } or {},
      rivals = rnd(3) == 0 and { { x = rnd(800) - 400, y = rnd(800) - 400, hq = rnd(2) == 0 } } or {},
      lost = rnd(5) == 0 and { { x = rnd(300) - 150, y = rnd(300) - 150, tick = 0 } } or {} })
    local base = V.components(site, ctx)
    site.deposit = rnd(5000)
    local with = V.components(site, ctx)
    local d = with.value - base.value
    if d < 0 or d > V.SIZE_MAX then bad = bad + 1 end
    if (base.danger > 0 or base.contest > 0 or base.access >= 1000) and d ~= 0 then bad = bad + 1 end
    if d > 0 then n_gain = n_gain + 1 end
  end
  check(bad == 0, "2.f propriété (5 000 sites) : le gain est dans [0, SIZE_MAX], nul avec danger, contestation ou accès >= 1 000 (" .. bad .. " écart(s))")
  check(n_gain > 500, "2.g le gain joue dans un nombre notable de cas (" .. n_gain .. ")")
end

---------------------------------------------------------------------------------------------------
-- 3. Ca.size_credit, Ca.site_rank
---------------------------------------------------------------------------------------------------
check(Ca.size_credit(nil) == 0 and Ca.size_credit(300) == 0 and Ca.size_credit(2500) == Ca.GIANT_CREDIT and Ca.size_credit(9999) == Ca.GIANT_CREDIT, "3.a crédit : 0 en deçà, plafonné au-delà")
do
  local prev, mono = 0, true
  for t = 0, 4000, 13 do local c = Ca.size_credit(t); if c < prev then mono = false end; prev = c end
  check(mono, "3.b crédit monotone")
end
do
  local small_near = { id = "a", dist = 100, tiles = 150 }
  local giant_mid = { id = "b", dist = 170, tiles = 3000 }
  local giant_far = { id = "c", dist = 260, tiles = 3000 }
  check(Ca.site_rank(giant_mid) < Ca.site_rank(small_near), "3.c un géant à 70 tuiles de plus passe devant un petit cercle (rang " .. Ca.site_rank(giant_mid) .. " < " .. Ca.site_rank(small_near) .. ")")
  check(Ca.site_rank(giant_far) > Ca.site_rank(small_near), "3.d un géant bien plus loin ne passe pas devant le petit cercle proche")
  local l = { giant_far, small_near, giant_mid }
  table.sort(l, function(x, y) local rx, ry = Ca.site_rank(x), Ca.site_rank(y); if rx ~= ry then return rx < ry end return x.id < y.id end)
  check(l[1].id == "b" and l[2].id == "a" and l[3].id == "c", "3.e ordre b, a, c")
end

---------------------------------------------------------------------------------------------------
-- 4. Th.order
---------------------------------------------------------------------------------------------------
do
  local function ids(l) local o = {} for _, x in ipairs(Th.order(l)) do o[#o + 1] = x.id end return table.concat(o, ",") end
  check(ids({ { id = 1, tiles = 200 }, { id = 2, tiles = 3000 }, { id = 3, tiles = 900 } }) == "2,3,1", "4.a à égalité, le plus grand gisement d'abord")
  check(ids({ { id = 1, tiles = 200, wanted = true }, { id = 2, tiles = 3000 } }) == "1,2", "4.b le voulu par la capitalisation reste devant")
  check(ids({ { id = 1, tiles = 200, tier = 0 }, { id = 2, tiles = 3000, tier = 1 } }) == "1,2", "4.c le rang de minerai (plaques d'abord) reste devant")
  check(ids({ { id = 1, tiles = 200, have = 0 }, { id = 2, tiles = 3000, have = 50 } }) == "1,2", "4.d la plaque en manque reste devant")
  check(ids({ { id = 1 }, { id = 2 }, { id = 3 } }) == "1,2,3", "4.e sans taille : le numéro, comme avant")
  check(ids({ { id = 5, tiles = 700 }, { id = 4, tiles = 700 } }) == "4,5", "4.f taille égale : le numéro")
end

---------------------------------------------------------------------------------------------------
-- 5. Sites.deposit_of
---------------------------------------------------------------------------------------------------
local SRC_SITES = slurp("script/faction/sites.lua")
local function load_sites(src) return assert(load(src, "sites", "t"))() end
local Sites = load_sites(SRC_SITES)
local counts, censuses = { count = 0, find = 0 }, 0
local function disc(cx, cy, r, out)
  out = out or {}
  for x = cx - r, cx + r do for y = cy - r, cy + r do if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then out[#out + 1] = { x, y } end end end
  return out
end
local function surface_of(tiles)
  return {
    count_entities_filtered = function(q)
      counts.count = counts.count + 1
      local n = 0
      for _, t in ipairs(tiles) do
        if (t[1] + 0.5 - q.position.x) ^ 2 + (t[2] + 0.5 - q.position.y) ^ 2 <= q.radius ^ 2 then
          n = n + 1
          if q.limit and n >= q.limit then break end
        end
      end
      return n
    end,
    find_entities_filtered = function(q)
      counts.find = counts.find + 1
      local ar = q.area
      local out = {}
      for _, t in ipairs(tiles) do
        local px, py = t[1] + 0.5, t[2] + 0.5
        if px >= ar[1][1] and px < ar[2][1] and py >= ar[1][2] and py < ar[2][2] then out[#out + 1] = { position = { x = px, y = py }, amount = 100 } end
      end
      return out
    end,
  }
end
do
  local f = {}
  local giant = disc(0, 0, 32)
  local s = surface_of(giant)
  local n1 = Sites.deposit_of(f, s, "res", { x = 5.5, y = 3.5 })
  check(n1 == #giant and counts.find >= 1, "5.a un grand voisinage : recensement, nombre réel de tuiles (" .. n1 .. " / " .. #giant .. ")")
  local finds = counts.find
  local n2 = Sites.deposit_of(f, s, "res", { x = -20.5, y = 10.5 })
  check(n2 == #giant and counts.find == finds, "5.b un autre site du même gisement : le cache, aucune lecture de plus")
  check(#f.dep_boxes == 1, "5.c une seule boîte gardée")
  local small = surface_of(disc(200, 200, 6))
  counts.find = 0
  local n3 = Sites.deposit_of(f, small, "res", { x = 200.5, y = 200.5 })
  check(n3 < Sites.DEPOSIT_BIG and counts.find == 0, "5.d un petit gisement : comptage du moteur seulement (" .. n3 .. " tuiles, " .. counts.find .. " recensement)")
  check(V.size_gain(n3) == 0, "5.e un petit gisement : aucun gain")
  local g2 = {}
  for k = 1, Sites.DEP_BOXES_MAX + 5 do
    local sf = surface_of(disc(k * 200, 0, 12))
    Sites.deposit_of(g2, sf, "res", { x = k * 200 + 0.5, y = 0.5 })
  end
  check(#g2.dep_boxes <= Sites.DEP_BOXES_MAX, "5.f le cache est plafonné (" .. #g2.dep_boxes .. ")")
  local other = Sites.deposit_of({ dep_boxes = { { res = "autre", x0 = -50, y0 = -50, x1 = 50, y1 = 50, tiles = 9999 } } }, s, "res", { x = 5.5, y = 3.5 })
  check(other == #giant, "5.g la boîte d'une autre ressource ne sert pas")
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 100)
  Sites.deposit_of({}, surface_of(giant), "res", { x = 5.5, y = 3.5 })
  debug.sethook()
  print(string.format("[GEANT] coût de Sites.deposit_of, premier site d'un gisement de %d tuiles : %d instructions (les suivants : le cache)", #giant, c * 100))
  check(c * 100 <= 1400000, "5.h coût du premier site d'un géant <= 1,4 M instructions")
  local d = 0
  local fcache = { dep_boxes = { { res = "res", x0 = -33, y0 = -33, x1 = 34, y1 = 34, tiles = #giant } } }
  debug.sethook(function() d = d + 1 end, "", 100)
  Sites.deposit_of(fcache, surface_of(giant), "res", { x = 5.5, y = 3.5 })
  debug.sethook()
  check(d * 100 <= 2000, "5.i site suivant du même gisement : le cache coûte au plus 2 000 instructions (" .. d * 100 .. ")")
end

---------------------------------------------------------------------------------------------------
-- 6. Mutants
---------------------------------------------------------------------------------------------------
local function mutate(path, old, new)
  local src = slurp(path)
  local a, b = src:find(old, 1, true)
  assert(a, "mutant introuvable : " .. old)
  assert(not src:find(old, b + 1, true), "mutant ambigu : " .. old)
  return load(src:sub(1, a - 1) .. new .. src:sub(b + 1), "mutant", "t")()
end
local function suite_valeur(Vm)
  local ok = true
  local s1 = { x = 80, y = 0, rich = 30000, deposit = 3000 }
  local base = ctx_of()
  if Vm.components(s1, base).size ~= Vm.SIZE_MAX then ok = false end
  if Vm.components(s1, ctx_of({ rivals = { { x = 100, y = 0, hq = false } } })).size ~= 0 then ok = false end
  if Vm.components(s1, ctx_of({ rivals = { { x = 300, y = 0, hq = true } } })).size ~= 0 then ok = false end
  if Vm.components({ x = 900, y = 0, rich = 30000, deposit = 3000 }, base).size ~= 0 then ok = false end
  if Vm.components({ x = 80, y = 0, rich = 30000, deposit = 100 }, base).size ~= 0 then ok = false end
  if Vm.size_gain(1400) ~= 125 then ok = false end
  local s0 = { x = 80, y = 0, rich = 30000 }
  if Vm.components(s1, base).value - Vm.components(s0, base).value ~= Vm.SIZE_MAX then ok = false end
  return ok
end
local VM = {
  { "géant préféré malgré danger", "c.size = (c.danger == 0 and c.contest == 0 and c.access < 1000) and", "c.size = (c.contest == 0 and c.access < 1000) and" },
  -- (« géant préféré malgré contestation » : mutant ÉQUIVALENT, V.CONTEST_R (64) < V.DANGER_OP_R (160) : un site disputé a toujours du danger, sauf prudence nulle où les deux sont nuls)
  { "géant préféré malgré l'impossibilité d'atteindre", "c.size = (c.danger == 0 and c.contest == 0 and c.access < 1000) and", "c.size = (c.danger == 0 and c.contest == 0) and" },
  { "gain non plafonné", "if tiles >= V.SIZE_GIANT then return V.SIZE_MAX end", "" },
  { "petit gisement récompensé", "if type(tiles) ~= \"number\" or tiles <= V.SIZE_SMALL then return 0 end", "if type(tiles) ~= \"number\" then return 0 end" },
  { "gain absent de la valeur", "- c.danger - c.contest + c.size", "- c.danger - c.contest" },
}
check(suite_valeur(V), "6.a la suite de mutants passe sur le code réel")
local killed = 0
for _, m in ipairs(VM) do
  local ok, Vm = pcall(mutate, "shared/faction/valeur.lua", m[2], m[3])
  local dead = not ok or not suite_valeur(Vm)
  if dead then killed = killed + 1 end
  check(dead, "6. mutant refusé : " .. m[1])
end
local function suite_order(Tm)
  local function ids(l) local o = {} for _, x in ipairs(Tm.order(l)) do o[#o + 1] = x.id end return table.concat(o, ",") end
  return ids({ { id = 1, tiles = 200 }, { id = 2, tiles = 3000 }, { id = 3, tiles = 900 } }) == "2,3,1"
    and ids({ { id = 1, tiles = 200, wanted = true }, { id = 2, tiles = 3000 } }) == "1,2"
    and ids({ { id = 1, tiles = 200, tier = 0 }, { id = 2, tiles = 3000, tier = 1 } }) == "1,2"
    and ids({ { id = 1 }, { id = 2 } }) == "1,2" and ids({ { id = 5, tiles = 700 }, { id = 4, tiles = 700 } }) == "4,5"
end
local TM = {
  { "le plus petit d'abord", "if sa ~= sb then return sa > sb end", "if sa ~= sb then return sa < sb end" },
  { "la taille avant tout", "local wa, wb = a.wanted and 1 or 0, b.wanted and 1 or 0", "if (a.tiles or 0) ~= (b.tiles or 0) then return (a.tiles or 0) > (b.tiles or 0) end\n    local wa, wb = a.wanted and 1 or 0, b.wanted and 1 or 0" },
  { "taille ignorée", "local sa, sb = a.tiles or 0, b.tiles or 0", "local sa, sb = 0, 0" },
}
check(suite_order(Th), "6.b la suite du départage passe sur le code réel")
for _, m in ipairs(TM) do
  local ok, Tm = pcall(mutate, "shared/team/thermique.lua", m[2], m[3])
  local dead = not ok or not suite_order(Tm)
  if dead then killed = killed + 1 end
  check(dead, "6. mutant refusé : " .. m[1])
end
local function suite_credit(Cm)
  return Cm.size_credit(300) == 0 and Cm.size_credit(100) == 0 and Cm.size_credit(9999) == Cm.GIANT_CREDIT and Cm.size_credit(2500) == Cm.GIANT_CREDIT and Cm.size_credit(1400) == 45
    and Cm.site_rank({ dist = 170, tiles = 3000 }) < Cm.site_rank({ dist = 100, tiles = 150 })
    and Cm.site_rank({ dist = 260, tiles = 3000 }) > Cm.site_rank({ dist = 100, tiles = 150 })
end
local CM = {
  { "crédit non plafonné", "if tiles >= Ca.GIANT_FULL then return Ca.GIANT_CREDIT end", "" },
  { "crédit au petit gisement", "if type(tiles) ~= \"number\" or tiles <= Ca.GIANT_SMALL then return 0 end", "if type(tiles) ~= \"number\" then return 0 end" },
  { "rang sans crédit", "return (f.dist or Ca.DIST) - Ca.size_credit(f.tiles)", "return (f.dist or Ca.DIST)" },
  { "crédit ajouté", "return (f.dist or Ca.DIST) - Ca.size_credit(f.tiles)", "return (f.dist or Ca.DIST) + Ca.size_credit(f.tiles)" },
}
check(suite_credit(Ca), "6.c la suite du rang passe sur le code réel")
for _, m in ipairs(CM) do
  local ok, Cm = pcall(mutate, "shared/ai3/capitalisation.lua", m[2], m[3])
  local dead = not ok or not suite_credit(Cm)
  if dead then killed = killed + 1 end
  check(dead, "6. mutant refusé : " .. m[1])
end
local function suite_sites(Sm)
  local f = {}
  local giant = disc(0, 0, 32)
  local s = surface_of(giant)
  local a = Sm.deposit_of(f, s, "res", { x = 5.5, y = 3.5 })
  local finds = counts.find
  local b = Sm.deposit_of(f, s, "res", { x = -20.5, y = 10.5 })
  local c = Sm.deposit_of({}, surface_of(disc(200, 200, 6)), "res", { x = 200.5, y = 200.5 })
  return a == #giant and counts.find == finds and b == #giant and c < Sm.DEPOSIT_BIG
end
local SM = {
  { "pas de cache", "if b.res == res and site.x >= b.x0 and site.x < b.x1 and site.y >= b.y0 and site.y < b.y1 then return b.tiles end", "" },
  { "recensement toujours", "if near < Sites.DEPOSIT_BIG then return near end", "" },
  { "comptage seul", "local c = Sites.census(surface, res, { x = site.x, y = site.y })", "local c = nil" },
}
check(suite_sites(Sites), "6.d la suite du recensement du site passe sur le code réel")
for _, m in ipairs(SM) do
  local ok, Sm = pcall(function() return load_sites((function() local a, b = SRC_SITES:find(m[2], 1, true); assert(a, m[1]); return SRC_SITES:sub(1, a - 1) .. m[3] .. SRC_SITES:sub(b + 1) end)()) end)
  local dead = not ok or not suite_sites(Sm)
  if dead then killed = killed + 1 end
  check(dead, "6. mutant refusé : " .. m[1])
end
print(string.format("[GEANT] mutants refusés : %d sur %d", killed, #VM + #TM + #CM + #SM))

print(string.format("[GEANT] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
