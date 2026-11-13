--[[
  s41 reinjection : une ligne du tronc déjà posée, dérivée de nouveau par une rangée, reçoit un quai de réinjection (bras + coffre) en amont de la prise,
  alimenté en courant par une chaîne de poteaux reliée au poteau de passage de la rangée. Usage : lua5.2 tests/s41_reinjection_test.lua
]]
package.path = "./?.lua;" .. package.path
local ok_n, ko_n = 0, 0
local function check(cond, what)
  if cond then ok_n = ok_n + 1 else ko_n = ko_n + 1; print("ECHEC : " .. what) end
end
local Mt = require("shared.team.mall_tronc")
local Mr = require("shared.team.mall_rangee")
local NAMES = { tapis = "belt", bras = "arm", coffre = "chest", poteau = "pole", repartiteur = "split", souterrain = "ug" }
local function size(name, dir) if name == "split" then return 2, 1 end return 1, 1 end
local function count(ents, role) local n = 0 for _, e in ipairs(ents) do if e.role == role then n = n + 1 end end return n end

-- rangée 1 : première section, aucune réinjection (les seuls quais sont ceux des têtes)
local lines = { Mt.ligne(1, "fer"), Mt.ligne(2, "cuivre") }
local s1 = Mt.section(lines, { j = 1, bus = { a = 1, b = 2 } }, NAMES)
check(#s1.quais == 4, "rangee 1 : 4 quais de tete, vu " .. #s1.quais)
check(#Mr.verifie(s1.ents, size, 7.5, 2.5) == 0, "rangee 1 conforme")
for _, ln in ipairs(lines) do ln.y_to = s1.y_to[ln.k] end

-- rangée 2 : les deux lignes sont dérivées une seconde fois : un quai de réinjection chacune, dans la tuile de passage (y = 14), à l'ouest de la ligne
local s2 = Mt.section(lines, { j = 2, bus = { a = 1, b = 2 } }, NAMES)
check(#s2.quais == 2, "rangee 2 : 2 quais de reinjection, vu " .. #s2.quais)
check(count(s2.ents, "quai-bras") == 2 and count(s2.ents, "quai") == 2, "rangee 2 : 2 bras et 2 coffres")
local seen = {}
for _, q in ipairs(s2.quais) do seen[q.item] = q end
check(seen.fer and seen.fer.x == Mt.XL(1) - 1.5 and seen.fer.y == 14.5, "quai du fer a l'ouest de la ligne 1, tuile de passage")
check(seen.cuivre and seen.cuivre.x == Mt.XL(2) - 1.5 and seen.cuivre.y == 14.5, "quai du cuivre a l'ouest de la ligne 2")
-- en amont des prises (répartiteurs en y = 20 et 21)
for _, e in ipairs(s2.ents) do if e.name == "split" then check(e.y > 15, "repartiteur en aval du quai de reinjection") end end
-- géométrie : aucun chevauchement, poteaux d'un seul tenant AVEC le relais de passage (3,5 ; 14,5), bras couverts
local errs = Mr.verifie(s2.ents, size, 7.5, 2.5)
check(#errs == 0, "rangee 2 conforme : " .. table.concat(errs, " | "))
-- et pas de chevauchement avec ce que la rangée 1 a posé
local occ = {}
for _, e in ipairs(s1.ents) do local w = size(e.name); for dx = 0, w - 1 do occ[math.floor(e.x - w / 2 + 1e-6) + dx .. ":" .. math.floor(e.y)] = true end end
local clash = 0
for _, e in ipairs(s2.ents) do local w = size(e.name); for dx = 0, w - 1 do if occ[math.floor(e.x - w / 2 + 1e-6) + dx .. ":" .. math.floor(e.y)] then clash = clash + 1 end end end
check(clash == 0, "rangee 2 ne recouvre rien de la rangee 1, vu " .. clash)
for _, ln in ipairs(lines) do ln.y_to = s2.y_to[ln.k] end

-- rangée 3 qui ne dérive que la ligne 2 : un seul quai (ligne 2), la ligne 1 ne reçoit qu'un poteau de chaîne ; ligne 3 neuve dérivée : tête, pas de réinjection
local s3 = Mt.section(lines, { j = 3, bus = { a = 2 } }, NAMES)
check(#s3.quais == 1 and s3.quais[1].item == "cuivre" and s3.quais[1].y == 29.5, "rangee 3 : un quai de reinjection, ligne 2")
check(#Mr.verifie(s3.ents, size, 7.5, 2.5) == 0, "rangee 3 conforme")
local l3 = { lines[1], lines[2], Mt.ligne(3, "acier") }
local s3b = Mt.section(l3, { j = 3, bus = { a = 3 } }, NAMES)
check(#s3b.quais == 2 and s3b.quais[1].item == "acier" and s3b.quais[1].y < 0, "ligne neuve : quais de tete seulement")
-- ligne 3 réinjectée seule : chaîne de poteaux jusqu'à elle
for _, ln in ipairs(l3) do ln.y_to = s3b.y_to[ln.k] end
local s4 = Mt.section(l3, { j = 4, bus = { a = 3 } }, NAMES)
check(#s4.quais == 1 and s4.quais[1].item == "acier" and s4.quais[1].x == Mt.XL(3) - 1.5, "rangee 4 : reinjection de la ligne 3")
local e4 = Mr.verifie(s4.ents, size, 7.5, 2.5)
check(#e4 == 0, "rangee 4 conforme : " .. table.concat(e4, " | "))
check(s4.quais[1].x >= -Mt.WEST, "quai dans la place reservee a l'ouest")
-- déterminisme
local a, b2 = Mt.section(l3, { j = 4, bus = { a = 3 } }, NAMES), Mt.section(l3, { j = 4, bus = { a = 3 } }, NAMES)
local same = #a.ents == #b2.ents
for i = 1, #a.ents do if a.ents[i].x ~= b2.ents[i].x or a.ents[i].y ~= b2.ents[i].y or a.ents[i].name ~= b2.ents[i].name then same = false end end
check(same, "deux appels, meme liste")

print(string.format("s41_reinjection_test : %d OK, %d ECHEC", ok_n, ko_n))
if ko_n > 0 then os.exit(1) end
