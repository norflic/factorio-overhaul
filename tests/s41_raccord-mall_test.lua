--[[
  s41 raccord-mall : Mt.place_libre (shared/team/mall_tronc.lua) n'ouvre à la chaîne de poteaux AUCUNE tuile que le tronc utilise (1 à 3 lignes, 4 rangées), et ouvre un passage
  continu à travers la place du tronc (sauts au plus égaux à la portée d'un petit poteau).
  Usage : lua5.2 tests/s41_raccord-mall_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local ok_n, ko_n = 0, 0
local function check(cond, what)
  if cond then ok_n = ok_n + 1 else ko_n = ko_n + 1; print("ECHEC : " .. what) end
end
local Mt = require("shared.team.mall_tronc")
local Mr = require("shared.team.mall_rangee")
local NAMES = { tapis = "belt", bras = "arm", coffre = "chest", poteau = "pole", repartiteur = "split", souterrain = "ug" }
local function tiles_of(e)
  if e.name == "split" then return { { math.floor(e.x - 1), math.floor(e.y) }, { math.floor(e.x), math.floor(e.y) } } end
  return { { math.floor(e.x), math.floor(e.y) } }
end

-- 1. aucune tuile d'une entité du tronc n'est ouverte, pour 1, 2 et 3 lignes, 4 rangées, toutes les paires de prises
for nl = 1, Mt.KMAX do
  for a = 1, nl do
    for b = 1, nl do
      local lines = {}
      for k = 1, nl do lines[k] = Mt.ligne(k, "o" .. k) end
      local pris = 0
      for j = 1, 4 do
        local sec = Mt.section(lines, { j = j, bus = { a = a, b = b } }, NAMES)
        for k, y in pairs(sec.y_to) do lines[k].y_to = y end
        for _, e in ipairs(sec.ents) do
          for _, t in ipairs(tiles_of(e)) do
            if Mt.place_libre(t[1], t[2]) or (t[1] < 0 and Mr.reserve_libre(t[1], t[2], Mt.WEST, Mt.NORTH)) then pris = pris + 1 end
          end
        end
      end
      check(pris == 0, string.format("§1 %d ligne(s), prises %d/%d : %d tuile(s) du tronc ouverte(s) a la chaine", nl, a, b, pris))
    end
  end
end

-- 2. hors de la place, et sur une rangée : jamais ouvert par place_libre
check(not Mt.place_libre(0, 14) and not Mt.place_libre(5, 14) and not Mt.place_libre(-Mt.WEST - 1, 5) and not Mt.place_libre(-9, Mt.Y_TOP - 1), "§2 hors de la place : rien")
check(not Mt.place_libre(-9, 5) and not Mt.place_libre(-3, 14) and not Mt.place_libre(-8, 14) and not Mt.place_libre(-9, -1), "§2 prises, tete de rangee, ligne, quai : fermes")

-- 3. passage continu de la tuile de passage (x = 0, libre par Mr.reserve_libre) jusqu'à l'ouest de la place, sauts <= 7 tuiles
for _, ry in ipairs({ 14, 29, 44 }) do
  local last, okp = 0, Mr.reserve_libre(0, ry, Mt.WEST, Mt.NORTH)
  for rx = -1, -Mt.WEST - 1, -1 do
    if Mt.place_libre(rx, ry) or Mr.reserve_libre(rx, ry, Mt.WEST, Mt.NORTH) then
      if last - rx > 7 then okp = false end
      last = rx
    end
  end
  check(okp and last == -Mt.WEST - 1, "§3 passage y = " .. ry .. " : traverse la place par sauts de 7 tuiles au plus")
end
-- 4. tête de la ligne 1 (poteau en x = -9, y = -2) : une tuile ouverte à 7 tuiles au plus, elle-même à 7 tuiles au plus de l'ouest de la place ; couloir ouest continu (y >= 0)
check(Mt.place_libre(Mt.XL(Mt.KMAX) - 2, Mt.Y_TOP + 1) and Mt.XL(1) - 1 - (Mt.XL(Mt.KMAX) - 2) <= 7, "§4 tete : tuile entre les coffres de la derniere ligne ouverte, a portee")
local col = true
for ry = 0, 60 do if not (Mt.place_libre(-Mt.WEST, ry) and Mt.place_libre(-Mt.WEST + 1, ry)) then col = false end end
check(col, "§4 couloir a l'ouest de la derniere ligne : ouvert sur toute la longueur")

print(string.format("s41 raccord-mall : %d OK, %d ECHEC", ok_n, ko_n))
if ko_n > 0 then os.exit(1) end
