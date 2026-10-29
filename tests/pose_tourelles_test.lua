--[[
  Tests hors jeu du lot TOURELLES : choix des emplacements de tourelles d'un avant-poste ou du QG (shared/team/pose_tourelles.lua).
  Usage :  lua5.2 tests/pose_tourelles_test.lua
  Cas : identité sans bâtiment ou quand tout est couvert partout (= ancien comportement), bâtiment lointain, tourelle existante,
  force brute contre un évaluateur indépendant (300 instances), glouton >= 63 % de l'optimum, jamais pire que l'ancien ordre sur
  400 plans aléatoires, invariance à l'ordre des bâtiments, doublons, déterminisme, absence de `pairs` ; MUTANTS refusés.
]]
package.path = "./?.lua;" .. package.path
local Pose = require("shared.team.pose_tourelles")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

-- Les 8 emplacements d'avant le lot, autour de (cx, cy), dans l'ancien ordre.
local OFF = { { 7, 7 }, { -7, -7 }, { 7, -7 }, { -7, 7 }, { 9, 0 }, { -9, 0 }, { 0, 9 }, { 0, -9 } }
local function ring(cx, cy)
  local c = {}
  for i, o in ipairs(OFF) do c[i] = { x = cx + o[1], y = cy + o[2] } end
  return c
end
local RANGE = 18

-- Générateur déterministe (le test n'utilise pas math.random).
local seed = 12345
local function rnd(n)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed % n
end

local function first_k(order, k)
  local t = {}
  for i = 1, k do t[i] = order[i] end
  return t
end
local function pts(cands, idx)
  local t = {}
  for _, i in ipairs(idx) do t[#t + 1] = cands[i] end
  return t
end

section("1. Sans bâtiment, ou tout couvert par tous : l'ancien ordre")
do
  local c = ring(0, 0)
  local r = Pose.choose({ candidates = c, assets = {}, range = RANGE, existing = {}, count = 2 })
  local same = #r.order == 8
  for i = 1, 8 do if r.order[i] ~= i then same = false end end
  check(same, "aucun bâtiment : ordre identique à l'ancien")
  -- un petit avant-poste : tous les bâtiments à moins de 4 tuiles du centre, couverts par toutes les tourelles
  local assets = { { x = 0, y = 0, w = 9 }, { x = 2, y = 1, w = 9 }, { x = -3, y = 2, w = 3 } }
  r = Pose.choose({ candidates = c, assets = assets, range = RANGE, existing = {}, count = 2 })
  same = true
  for i = 1, 8 do if r.order[i] ~= i then same = false end end
  check(same, "petit avant-poste (tout à portée de tout) : ordre identique à l'ancien")
  check(r.score == r.total, "...et toute l'aire est couverte")
  r = Pose.choose({ candidates = c, assets = assets, range = 0, existing = {}, count = 2 })
  check(r.order[1] == 1 and r.chosen == 0, "portée inconnue : ancien ordre, rien de choisi")
  r = Pose.choose({ candidates = c, assets = assets, range = RANGE, existing = {}, count = 0 })
  check(r.chosen == 0 and #r.order == 8, "zéro tourelle voulue : rien de choisi")
  r = Pose.choose({ candidates = {}, assets = assets, range = RANGE, existing = {}, count = 2 })
  check(#r.order == 0, "aucun candidat : liste vide")
end

section("2. Un bâtiment lointain d'un côté : la tourelle va de ce côté")
do
  local c = ring(0, 0)
  -- La tourelle (7,7) couvre à 14,4 tuiles (80 % de 18) ; un bâtiment en (-20, -20) n'est à portée que de (-7,-7) (distance 18,4 > 14,4)
  local assets = { { x = 0, y = 0, w = 9 }, { x = -14, y = -14, w = 9 } }
  local r = Pose.choose({ candidates = c, assets = assets, range = RANGE, existing = {}, count = 1 })
  check(r.order[1] == 2, "1 tourelle : (-7,-7), la seule qui couvre à la fois le centre et le bâtiment du nord-ouest (obtenu " .. tostring(r.order[1]) .. ")")
  check(r.score == r.total, "...et tout est couvert")
  local old = Pose.covered(assets, pts(c, { 1 }), RANGE)
  check(old < r.total, "l'ancienne première position (7,7) laissait le bâtiment à découvert")
  -- deux côtés opposés lointains : 2 tourelles diagonales opposées
  assets = { { x = 0, y = 0, w = 9 }, { x = -14, y = -14, w = 9 }, { x = 14, y = 14, w = 9 } }
  r = Pose.choose({ candidates = c, assets = assets, range = RANGE, existing = {}, count = 2 })
  local s = {}
  for _, i in ipairs(first_k(r.order, 2)) do s[i] = true end
  check(s[1] and s[2], "2 tourelles : (7,7) et (-7,-7), une par côté")
  check(r.score == r.total, "...tout couvert")
end

section("3. Les tourelles déjà posées comptent")
do
  local c = ring(0, 0)
  local assets = { { x = 0, y = 0, w = 9 }, { x = -14, y = -14, w = 9 }, { x = 14, y = 14, w = 9 } }
  -- une tourelle existe déjà au nord-ouest : la nouvelle va au sud-est
  local r = Pose.choose({ candidates = c, assets = assets, range = RANGE, existing = { { x = -8, y = -8 } }, count = 1 })
  check(r.order[1] == 1, "tourelle existante au nord-ouest : la nouvelle au sud-est (7,7)")
  check(r.base > 0, "l'aire déjà couverte est comptée")
  -- tout est déjà couvert : écartement maximal (la plus éloignée de l'existante)
  local assets2 = { { x = 0, y = 0, w = 9 } }
  r = Pose.choose({ candidates = c, assets = assets2, range = RANGE, existing = { { x = 7, y = 7 } }, count = 1 })
  check(r.order[1] == 2, "tout couvert déjà : on écarte (-7,-7), le plus loin de (7,7)")
end

section("4. Force brute contre un évaluateur indépendant (300 instances)")
do
  local function evaluator(c, assets, existing, k)
    -- énumère tous les sous-ensembles de taille k par masque binaire, score = poids des cases couvertes en plus
    local cells = Pose.cells(assets)
    local rc2 = (RANGE * Pose.COVER_PCT / 100) ^ 2
    local function covers(p, cell) return (p.x - cell.x) ^ 2 + (p.y - cell.y) ^ 2 <= rc2 end
    local best = -1
    local n = #c
    for mask = 0, 2 ^ n - 1 do
      local cnt, set = 0, {}
      for b = 0, n - 1 do
        if math.floor(mask / 2 ^ b) % 2 == 1 then cnt = cnt + 1; set[#set + 1] = c[b + 1] end
      end
      if cnt == k then
        local s = 0
        for _, cell in ipairs(cells) do
          local hit = false
          for _, e in ipairs(existing) do if covers(e, cell) then hit = true break end end
          if not hit then for _, p in ipairs(set) do if covers(p, cell) then hit = true break end end end
          if not hit then
            -- case non couverte : ne compte pas
          else
            local was = false
            for _, e in ipairs(existing) do if covers(e, cell) then was = true break end end
            if not was then s = s + cell.w end
          end
        end
        if s > best then best = s end
      end
    end
    return best
  end
  local bad = 0
  for _ = 1, 300 do
    local c = ring(0, 0)
    local assets = {}
    for _ = 1, 3 + rnd(12) do assets[#assets + 1] = { x = rnd(41) - 20, y = rnd(41) - 20, w = 1 + rnd(9) } end
    local existing = {}
    if rnd(3) == 0 then existing[1] = { x = rnd(21) - 10, y = rnd(21) - 10 } end
    local k = 1 + rnd(4)
    local r = Pose.choose({ candidates = c, assets = assets, range = RANGE, existing = existing, count = k })
    local want = evaluator(c, assets, existing, k)
    if r.score ~= want then bad = bad + 1 end
    if #r.order ~= 8 then bad = bad + 1 end
  end
  check(bad == 0, "le score choisi est l'optimum exact sur 300 instances (écarts : " .. bad .. ")")
end

section("5. Glouton : au moins 63 % de l'optimum")
do
  local saved = Pose.MAX_COMBOS
  local worst = 1
  for _ = 1, 200 do
    local c = ring(0, 0)
    local assets = {}
    for _ = 1, 4 + rnd(14) do assets[#assets + 1] = { x = rnd(51) - 25, y = rnd(51) - 25, w = 1 + rnd(9) } end
    local k = 2 + rnd(3)
    Pose.MAX_COMBOS = saved
    local exact = Pose.choose({ candidates = c, assets = assets, range = RANGE, existing = {}, count = k })
    Pose.MAX_COMBOS = 0
    local greedy = Pose.choose({ candidates = c, assets = assets, range = RANGE, existing = {}, count = k })
    Pose.MAX_COMBOS = saved
    if exact.score > 0 then worst = math.min(worst, greedy.score / exact.score) end
    check(greedy.score <= exact.score, "le glouton ne dépasse jamais l'optimum")
  end
  check(worst >= 0.632, string.format("rapport glouton / optimum >= 1 - 1/e (pire cas mesuré : %.3f)", worst))
end

section("6. Jamais pire que l'ancien ordre, souvent mieux (400 plans, avant-postes étalés)")
do
  local better, worse = 0, 0
  for _ = 1, 400 do
    local c = ring(0, 0)
    local assets = {}
    for _ = 1, 4 + rnd(16) do assets[#assets + 1] = { x = rnd(37) - 18, y = rnd(37) - 18, w = 1 + rnd(9) } end
    local k = 1 + rnd(4)
    local r = Pose.choose({ candidates = c, assets = assets, range = RANGE, existing = {}, count = k })
    local old = Pose.covered(assets, pts(c, first_k({ 1, 2, 3, 4, 5, 6, 7, 8 }, k)), RANGE)
    local new = Pose.covered(assets, pts(c, first_k(r.order, k)), RANGE)
    if new > old then better = better + 1 end
    if new < old then worse = worse + 1 end
  end
  check(worse == 0, "aucun plan où le nouvel ordre couvre moins que l'ancien (" .. worse .. ")")
  check(better >= 40, "le nouvel ordre couvre plus sur au moins 10 % des plans (" .. better .. " sur 400)")
end

section("7. Invariance à l'ordre des bâtiments, déterminisme")
do
  local c = ring(5, -3)
  local assets = {}
  for _ = 1, 25 do assets[#assets + 1] = { x = rnd(41) - 15, y = rnd(41) - 23, w = 1 + rnd(9) } end
  local rev = {}
  for i = #assets, 1, -1 do rev[#rev + 1] = assets[i] end
  local a = Pose.choose({ candidates = c, assets = assets, range = RANGE, existing = {}, count = 3 })
  local b = Pose.choose({ candidates = c, assets = rev, range = RANGE, existing = {}, count = 3 })
  local same = a.score == b.score
  for i = 1, 8 do if a.order[i] ~= b.order[i] then same = false end end
  check(same, "même ensemble et même ordre si les bâtiments arrivent dans l'ordre inverse")
  local a2 = Pose.choose({ candidates = c, assets = assets, range = RANGE, existing = {}, count = 3 })
  same = true
  for i = 1, 8 do if a.order[i] ~= a2.order[i] then same = false end end
  check(same, "deux appels identiques rendent le même ordre")
end

section("8. Ordre de pose : permutation complète, ensemble choisi d'abord")
do
  local c = ring(0, 0)
  local assets = { { x = 0, y = 0, w = 9 }, { x = -14, y = -14, w = 20 }, { x = 14, y = 14, w = 5 } }
  local r = Pose.choose({ candidates = c, assets = assets, range = RANGE, existing = {}, count = 2 })
  local seen, ok = {}, true
  for _, i in ipairs(r.order) do if seen[i] or i < 1 or i > 8 then ok = false end seen[i] = true end
  check(ok and #r.order == 8, "l'ordre est une permutation des 8 candidats (le repli reste disponible)")
  check(r.chosen == 2, "deux choisis")
  check(r.order[1] == 2, "le plus gros gain d'abord : (-7,-7) (poids 29 contre 14)")
end

section("9. Doublons et dépassement de la borne de cases")
do
  local d = Pose.dedup({ { x = 0, y = 0 }, { x = 1, y = 1 }, { x = 5, y = 0 }, { x = 5.5, y = 0.2 } })
  check(#d == 2 and d[1].x == 0 and d[2].x == 5, "deux candidats à moins de 2 tuiles sont le même emplacement")
  local many = {}
  for i = 1, 1000 do many[#many + 1] = { x = (i % 40) * 3, y = math.floor(i / 40) * 3, w = 1 + (i % 7) } end
  local cells = Pose.cells(many)
  check(#cells <= Pose.MAX_CELLS, "au plus MAX_CELLS cases (" .. #cells .. ")")
  local t = Pose.cells({ { x = 0.1, y = 0.1, w = 2 }, { x = 1.1, y = 1.1, w = 4 }, { x = 5, y = 5, w = 0 } })
  check(#t == 1 and t[1].w == 6, "deux bâtiments d'une même case s'additionnent, un poids nul est ignoré")
  check(Pose.role_factor("militaire") == 0 and Pose.role_factor("main") == 0 and Pose.role_factor(nil) == 0, "tourelles, murs et personnage ne pèsent pas")
  check(Pose.role_factor("foreuse") > 0 and Pose.role_factor("logistique") > 0, "foreuses et logistique pèsent")
end

section("10. Pas de pairs, pas de nom d'objet du jeu dans la règle pure")
do
  local f = io.open("shared/team/pose_tourelles.lua", "r")
  local src = f:read("*a")
  f:close()
  local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("pairs%(") or not code:gsub("ipairs%(", ""):find("pairs%("), "aucun appel à pairs")
  check(not code:find("gun%-turret") and not code:find("math%.random") and not code:find("math%.sin") and not code:find("math%.cos"),
    "aucun nom d'objet du jeu, aucun hasard, aucune trigonométrie")
end

section("11. MUTANTS (chacun doit faire échouer au moins un cas ci-dessus)")
do
  -- Rejoue deux cas de référence sous mutation de la règle et vérifie que l'écart est vu.
  local function kill(name, mutate, restore)
    mutate()
    local c = ring(0, 0)
    local assets = { { x = 0, y = 0, w = 9 }, { x = -14, y = -14, w = 9 }, { x = 14, y = 14, w = 9 } }
    local r = Pose.choose({ candidates = c, assets = assets, range = RANGE, existing = {}, count = 2 })
    local one = Pose.choose({ candidates = c, assets = { { x = 0, y = 0, w = 9 }, { x = -14, y = -14, w = 9 } }, range = RANGE, existing = {}, count = 1 })
    local ex = Pose.choose({ candidates = c, assets = { { x = 0, y = 0, w = 9 } }, range = RANGE, existing = { { x = 7, y = 7 } }, count = 1 })
    local s = {}
    for _, i in ipairs(first_k(r.order, 2)) do s[i] = true end
    local ok = s[1] and s[2] and r.score == r.total and one.order[1] == 2 and ex.order[1] == 2
    restore()
    check(not ok, "mutant refusé : " .. name)
  end
  local cp, mc = Pose.COVER_PCT, Pose.MAX_COMBOS
  kill("rayon utile nul", function() Pose.COVER_PCT = 0 end, function() Pose.COVER_PCT = cp end)
  kill("rayon utile trop court (20 %)", function() Pose.COVER_PCT = 20 end, function() Pose.COVER_PCT = cp end)
  kill("poids des bâtiments ignorés (cellules vides)", function() Pose.MAX_CELLS = 0 end, function() Pose.MAX_CELLS = 400 end)
  local choose = Pose.choose
  kill("choix remplacé par l'ancien ordre", function()
    Pose.choose = function(spec)
      local o = {}
      for i = 1, #spec.candidates do o[i] = i end
      return { order = o, chosen = 0, score = 0, base = 0, total = 1 }
    end
  end, function() Pose.choose = choose end)
  kill("tourelles existantes ignorées", function()
    Pose.choose = function(spec) spec.existing = {}; return choose(spec) end
  end, function() Pose.choose = choose end)
  Pose.MAX_COMBOS = mc
end

print(string.format("[TOURELLES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
