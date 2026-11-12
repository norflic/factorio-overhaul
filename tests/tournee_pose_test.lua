-- Lot CHANTIERS-FANTOMES : tournées de pose (shared/team/tournee_pose.lua). Usage : lua5.2 tests/tournee_pose_test.lua
package.path = "./?.lua;" .. package.path
local Tp = require("shared.team.tournee_pose")
local ok, ko = 0, 0
local function check(c, what)
  if c then ok = ok + 1 else ko = ko + 1 print("ECHEC : " .. what) end
end
local function a(k, x, y, n, items) return { k = k, x = x, y = y, n = n, items = items or { { "piece", n } } } end
local function stack() return 100 end

-- 1. Ligne de poteaux : 20 points d'appui à 7 tuiles l'un de l'autre, 1 pièce chacun : une seule tournée, de proche en proche depuis l'origine.
do
  local list = {}
  for i = 1, 20 do list[#list + 1] = a(string.format("p%02d", i), 7 * i, 0, 1) end
  local t = Tp.group(list, { x = 0, y = 0 }, stack)
  check(#t == 1, "ligne : une tournee (" .. #t .. ")")
  check(t[1][1] == 1 and t[1][20] == 20, "ligne : ordre de passage depuis l'origine")
end

-- 2. Borne de pièces : 10 points d'appui de 10 pièces voisins : tournées de 40 au plus (Tp.MAX_PIECES 48).
do
  local list = {}
  for i = 1, 10 do list[#list + 1] = a("c" .. i, 8 * i, 0, 10) end
  local t = Tp.group(list, { x = 0, y = 0 }, stack)
  local seen = 0
  for _, tour in ipairs(t) do
    local n = 0
    for _, i in ipairs(tour) do n = n + list[i].n; seen = seen + 1 end
    check(n <= Tp.MAX_PIECES, "bornes : " .. n .. " pieces")
  end
  check(seen == 10, "bornes : chaque point d'appui une fois")
  check(#t == 3, "bornes : 3 tournees (" .. #t .. ")")
end

-- 3. Saut trop long : deux groupes à 200 tuiles : deux tournées.
do
  local list = { a("a", 0, 0, 2), a("b", 8, 0, 2), a("c", 208, 0, 2), a("d", 216, 0, 2) }
  local t = Tp.group(list, { x = 0, y = 0 }, stack)
  check(#t == 2, "saut : 2 tournees")
end

-- 4. Piles : un objet de pile 1 (foreuse fictive), 40 pièces : bornées par Tp.MAX_SLOTS.
do
  local list = {}
  for i = 1, 8 do list[#list + 1] = a("f" .. i, 3 * i, 0, 5, { { "lourd", 5 } }) end
  local t = Tp.group(list, { x = 0, y = 0 }, function() return 1 end)
  for _, tour in ipairs(t) do
    local n = 0
    for _, i in ipairs(tour) do n = n + 5 end
    check(n <= Tp.MAX_SLOTS, "piles : " .. n .. " piles")
  end
end

-- 5. Un point d'appui trop gros fait sa tournée seul ; déterminisme (même entrée, même sortie).
do
  local list = { a("g", 0, 0, 100), a("h", 5, 0, 1) }
  local t1 = Tp.group(list, { x = 0, y = 0 }, stack)
  local t2 = Tp.group(list, { x = 0, y = 0 }, stack)
  check(#t1 == 2 and #t1[1] == 1, "gros : seul")
  check(table.concat(t1[1], ",") == table.concat(t2[1], ",") and table.concat(t1[2], ",") == table.concat(t2[2], ","), "determinisme")
end

-- 6. Égalité de distance : la plus petite clé d'abord.
do
  local list = { a("b", 10, 0, 1), a("a", -10, 0, 1) }
  local t = Tp.group(list, { x = 0, y = 0 }, stack)
  check(t[1][1] == 2, "egalite : cle la plus petite")
end

print(string.format("tournee_pose : %d OK, %d ECHEC(S)", ok, ko))
if ko > 0 then os.exit(1) end
