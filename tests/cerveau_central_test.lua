--[[
  Lot CERVEAU-CENTRAL (5/11) : optimisations EXACTES du calcul par PNJ (aucune décision changée).
    P1 : tri des tuiles de minage par distance au QG, positions lues une fois (shared/team/tri_proches.lua), contre l'ancien
         comparateur de script/team/worker.lua et de script/ai3/comportement.lua (M.retarget_mine) : même permutation,
         égalités comprises ; lectures de `.position` comptées ; mutants refusés.
    P2 : autodéfense sautée quand le regard du même tick n'a rien vu dans un disque qui contient le sien (M.look_clear) :
         contre une recherche exhaustive du plus proche ennemi ; mutants refusés.
  La partie A/B au moteur simulé (global sérialisé et journal identiques, ancien code contre nouveau) est à part :
  fo-logs/2026-11-05_CERVEAU-CENTRAL (ab_jeu.lua), car elle tourne sur deux arbres de sources.
  Lancement : lua5.2 tests/cerveau_central_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

-- Générateur pseudo-aléatoire déterministe (pas de math.random : même tirage partout)
local seed = 12345
local function rnd(n)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed % n
end

---------------------------------------------------------------------------------------------------
section("P1 : Tp.sort contre l'ancien tri (même permutation, égalités comprises)")
---------------------------------------------------------------------------------------------------
local Tp = require("shared.team.tri_proches")

local reads = 0
local ENT = { __index = function(t, k) if k == "position" then reads = reads + 1 return { x = t._x, y = t._y } end end }
local function ent(id, x, y) return setmetatable({ id = id, _x = x, _y = y }, ENT) end

local function dist2(a, b) -- celle de script/team/worker.lua (et d2 de script/ai3/comportement.lua : même arithmétique)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function old_sort(res, c) -- copie exacte de l'ancien comparateur (worker.lua:674, comportement.lua:703)
  table.sort(res, function(a, b)
    local da, db = dist2(a.position, c), dist2(b.position, c)
    if da ~= db then return da < db end
    if a.position.x ~= b.position.x then return a.position.x < b.position.x end
    return a.position.y < b.position.y
  end)
  return res
end

-- Mutants (chacun doit donner au moins une permutation différente de l'ancien tri)
local MUT = {
  ["y inverse"] = function(list, c, d2f)
    local recs = {}
    for i, e in ipairs(list) do local p = e.position recs[i] = { e = e, x = p.x, y = p.y, d = d2f(p, c) } end
    table.sort(recs, function(a, b)
      if a.d ~= b.d then return a.d < b.d end
      if a.x ~= b.x then return a.x < b.x end
      return a.y > b.y
    end)
    for i = 1, #recs do list[i] = recs[i].e end
    return list
  end,
  ["sans departage x"] = function(list, c, d2f)
    local recs = {}
    for i, e in ipairs(list) do local p = e.position recs[i] = { e = e, x = p.x, y = p.y, d = d2f(p, c) } end
    table.sort(recs, function(a, b)
      if a.d ~= b.d then return a.d < b.d end
      return a.y < b.y
    end)
    for i = 1, #recs do list[i] = recs[i].e end
    return list
  end,
  ["ordre de depart perdu"] = function(list, c, d2f) -- tableau de départ inversé avant le tri : visible sur les égalités totales
    local recs = {}
    local n = #list
    for i, e in ipairs(list) do local p = e.position recs[n + 1 - i] = { e = e, x = p.x, y = p.y, d = d2f(p, c) } end
    table.sort(recs, function(a, b)
      if a.d ~= b.d then return a.d < b.d end
      if a.x ~= b.x then return a.x < b.x end
      return a.y < b.y
    end)
    for i = 1, n do list[i] = recs[i].e end
    return list
  end,
}

local function make_list(n, c, dup)
  local out = {}
  for i = 1, n do
    -- tuiles de minerai : centres de tuiles autour du QG (beaucoup d'égalités de distance par symétrie) ; `dup` : doublons de
    -- position (égalités totales : deux arbres au même endroit, cas limite)
    local x = c.x + rnd(41) - 20 + 0.5
    local y = c.y + rnd(41) - 20 + 0.5
    if dup and i > 1 and rnd(4) == 0 then local o = out[rnd(i - 1) + 1] x, y = o._x, o._y end
    out[i] = ent(i, x, y)
  end
  return out
end
local function ids(list) local o = {} for i, e in ipairs(list) do o[i] = e.id end return table.concat(o, ",") end

local cases, same, ties = 0, 0, 0
local reads_old, reads_new = 0, 0
local mut_caught = {}
for k in pairs(MUT) do mut_caught[k] = false end
local sizes = { 0, 1, 2, 3, 5, 10, 40, 100, 256 }
for round = 1, 60 do
  for _, n in ipairs(sizes) do
    local c = { x = rnd(200) - 100 + (rnd(2) == 0 and 0.5 or 0), y = rnd(200) - 100 }
    local dup = round % 3 == 0
    local base = make_list(n, c, dup)
    local a, b = {}, {}
    for i, e in ipairs(base) do a[i], b[i] = e, e end
    reads = 0
    old_sort(a, c)
    reads_old = reads_old + reads
    reads = 0
    Tp.sort(b, c, dist2)
    reads_new = reads_new + reads
    check(reads == n, string.format("Tp.sort lit .position une fois par élément (n = %d, %d lectures)", n, reads))
    cases = cases + 1
    if ids(a) == ids(b) then same = same + 1 else print("  ECHEC : permutation différente, n = " .. n) failures = failures + 1 end
    -- égalités de distance présentes ?
    for i = 2, #a do
      if dist2(a[i].position, c) == dist2(a[i - 1].position, c) then ties = ties + 1 break end
    end
    for name, fn in pairs(MUT) do
      local m = {}
      for i, e in ipairs(base) do m[i] = e end
      fn(m, c, dist2)
      if ids(m) ~= ids(a) then mut_caught[name] = true end
    end
  end
end
check(same == cases, string.format("même permutation dans %d cas sur %d", same, cases))
check(ties > 100, string.format("cas avec égalités de distance : %d (au moins 100)", ties))
check(reads_new * 4 < reads_old, string.format("lectures de .position : %d (ancien) contre %d (nouveau)", reads_old, reads_new))
print(string.format("  lectures de .position : %d (ancien tri) contre %d (Tp.sort), %d cas, %d avec égalités", reads_old, reads_new, cases, ties))
for _, name in ipairs({ "ordre de depart perdu", "sans departage x", "y inverse" }) do
  check(mut_caught[name], "mutant refusé : " .. name)
end
-- La liste rendue est la même table, triée en place
do
  local c = { x = 0, y = 0 }
  local l = make_list(20, c, false)
  check(Tp.sort(l, c, dist2) == l, "Tp.sort trie en place et rend la liste")
end

---------------------------------------------------------------------------------------------------
section("P2 : M.look_clear contre une recherche exhaustive")
---------------------------------------------------------------------------------------------------
local Mock = require("tests.mock_engine")
Mock.new_game({ patches = {}, p_busy = 0, p_nopath = 0, p_lost = 0 })
local CP = require("script.ai3.comportement")
local Re = require("shared.ai3.reaction")
local DEFENSE_RADIUS = 18 -- script/team/worker.lua
do
  local src = io.open("script/team/worker.lua", "r"):read("*a")
  check(src:find("local DEFENSE_RADIUS = 18", 1, true) ~= nil, "rayon de l'autodéfense : 18 (worker.lua)")
  check(src:find("H.look_clear(agent.id, tick, p, DEFENSE_RADIUS)", 1, true) ~= nil, "l'autodéfense passe par M.look_clear")
  local cps = io.open("script/ai3/comportement.lua", "r"):read("*a")
  check(cps:find("note_look(agent.id, tick, c, r, enemy == nil)", 1, true) ~= nil, "le regard note son disque et son résultat")
end

local function nearest_within(enemies, p, R)
  local best, bd
  for _, q in ipairs(enemies) do
    local dx, dy = q.x - p.x, q.y - p.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d <= R and (not bd or d < bd) then best, bd = q, d end
  end
  return best
end

-- Prédicats mutants (copies fautives de M.look_clear)
local MUT2 = {
  ["rayon de l'autodefense oublie"] = function(L, p, R) local dx, dy = p.x - L.x, p.y - L.y return L.none and math.sqrt(dx * dx + dy * dy) <= L.r end,
  ["resultat du regard ignore"] = function(L, p, R) local dx, dy = p.x - L.x, p.y - L.y return math.sqrt(dx * dx + dy * dy) + R + 1 <= L.r end,
  ["centre du regard pris pour le PNJ"] = function(L, p, R) return L.none and R + 1 <= L.r end,
}
local caught2 = {}
local skips, trials, wrong = 0, 0, 0
local tick = 1000
for round = 1, 4000 do
  tick = tick + 1
  local enemies = {}
  for i = 1, rnd(6) do enemies[i] = { x = rnd(240) - 120, y = rnd(240) - 120 } end
  -- PNJ en p, regard 20 tuiles devant au plus (Re.LOOK_AHEAD), rayon du regard de Re.LOOK_MIN à Re.LOOK_MAX
  local p = { x = rnd(160) - 80 + 0.25, y = rnd(160) - 80 + 0.5 }
  local ahead = rnd(Re.LOOK_AHEAD + 1)
  local dir = rnd(4)
  local c = { x = p.x + (dir == 0 and ahead or dir == 1 and -ahead or 0), y = p.y + (dir == 2 and ahead or dir == 3 and -ahead or 0) }
  local r = Re.LOOK_MIN + rnd(Re.LOOK_MAX - Re.LOOK_MIN + 1)
  local seen = nearest_within(enemies, c, r)
  CP.note_look(7, tick, c, r, seen == nil)
  -- le PNJ a pu être déplacé d'au plus 30 tuiles (cas qu'une recherche juste doit encore couvrir)
  local q = { x = p.x + rnd(61) - 30, y = p.y + rnd(61) - 30 }
  for _, pp in ipairs({ p, q }) do
    trials = trials + 1
    local truth = nearest_within(enemies, pp, DEFENSE_RADIUS)
    if CP.look_clear(7, tick, pp, DEFENSE_RADIUS) then
      skips = skips + 1
      if truth ~= nil then wrong = wrong + 1 end
    end
    local L = { x = c.x, y = c.y, r = r, none = seen == nil }
    for name, fn in pairs(MUT2) do
      if fn(L, pp, DEFENSE_RADIUS) and truth ~= nil then caught2[name] = true end
    end
  end
  -- un autre tick : jamais de saut sur un regard ancien
  check(not CP.look_clear(7, tick + 1, p, DEFENSE_RADIUS), "regard d'un autre tick : pas de saut")
  -- un autre PNJ : jamais de saut
  if round % 50 == 0 then check(not CP.look_clear(8, tick, p, DEFENSE_RADIUS), "regard d'un autre PNJ : pas de saut") end
end
check(wrong == 0, string.format("aucun saut là où un ennemi est à portée : %d faux sur %d sauts", wrong, skips))
check(skips > 500, string.format("sauts constatés : %d sur %d essais (au moins 500)", skips, trials))
print(string.format("  %d essais, %d sauts, %d faux", trials, skips, wrong))
for _, name in ipairs({ "centre du regard pris pour le PNJ", "rayon de l'autodefense oublie", "resultat du regard ignore" }) do
  check(caught2[name], "mutant refusé : " .. name)
end
-- La table du regard ne garde qu'un tick
CP.note_look(9, 5000, { x = 0, y = 0 }, 56, true)
check(CP.look_clear(9, 5000, { x = 0, y = 0 }, DEFENSE_RADIUS), "regard vide du tick : saut")
CP.note_look(10, 5001, { x = 500, y = 500 }, 56, true)
check(not CP.look_clear(9, 5000, { x = 0, y = 0 }, DEFENSE_RADIUS), "tick suivant : la table est vidée")
check(not CP.look_clear(9, 5001, { x = 0, y = 0 }, DEFENSE_RADIUS), "tick suivant : l'ancien regard d'un PNJ ne compte plus")

print(string.format("[CERVEAU-CENTRAL] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
