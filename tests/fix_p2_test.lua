--[[ Lot FIX-P2 : tests purs (shared/ai3/carte.lua) des 4 failles de l'audit statique.
  1. K.count compte les gisements (secteurs voisins fusionnés), pas les secteurs ;
  2. K.scout_ok : cible d'éclaireur écartée si un nid est vu sur son trajet ;
  3. K.corridor_ok : gisement lointain écarté si un nid est vu sur le couloir QG → gisement ;
  4. K.rank_known : gisements rangés par a / (distance + 100), à égalité par clé.
  Usage : lua5.2 tests/fix_p2_test.lua ]]
package.path = "./?.lua;" .. package.path
local K = require("shared.ai3.carte")
local pass, fail = 0, 0
local function check(c, msg) if c then pass = pass + 1 else fail = fail + 1; print("[FIX-P2] ECHEC : " .. msg) end end
local R = "res-a" -- nom quelconque : aucune dépendance à un objet du jeu

-- 1. gisement à cheval sur deux secteurs voisins : un seul gisement
local m = K.new()
K.record(m, K.key(2, 2), 10, { res = { { name = R, n = 50, a = 5000, x = 180, y = 150 } } })
check(K.count(m, R) == 1, "1 : premier secteur = 1 gisement")
K.record(m, K.key(3, 2), 20, { res = { { name = R, n = 40, a = 4000, x = 200, y = 150 } } })
check(K.count(m, R) == 1, "1 : secteur voisin = même gisement (obtenu " .. K.count(m, R) .. ")")
K.record(m, K.key(3, 3), 30, { res = { { name = R, n = 40, a = 4000, x = 200, y = 200 } } })
check(K.count(m, R) == 1, "1 : voisin en diagonale = même gisement")
K.record(m, K.key(10, 2), 40, { res = { { name = R, n = 40, a = 4000, x = 660, y = 150 } } })
check(K.count(m, R) == 2, "1 : secteur lointain = second gisement")
K.record(m, K.key(10, 2), 50, { res = {} })
check(K.count(m, R) == 1, "1 : gisement isolé disparu = décompté")
K.record(m, K.key(3, 3), 60, { res = {} })
check(K.count(m, R) == 1, "1 : morceau d'un gisement disparu = gisement toujours compté")
-- ressource absente des voisins : la ressource différente n'est pas fusionnée
K.record(m, K.key(2, 3), 70, { res = { { name = "res-b", n = 10, a = 100, x = 150, y = 200 } } })
check(K.count(m, "res-b") == 1, "1 : autre ressource voisine comptée à part")

-- 2. trajet de l'éclaireur
local m2 = K.new()
K.record(m2, K.key(2, 0), 1, { nests = { { x = 160, y = 32 } } })
local me = { x = 0, y = 32 }
check(K.scout_ok(m2, me, K.key(4, 0)) == false, "2 : nid sur le trajet = cible écartée")
check(K.scout_ok(m2, me, K.key(0, 4)) == true, "2 : trajet libre = cible acceptée")

-- 3. couloir du minage lointain
local m3 = K.new()
K.record(m3, K.key(1, 0), 1, { nests = { { x = 100, y = 10 } } })
local hq = { x = 0, y = 0 }
check(K.corridor_ok(m3, hq, { x = 200, y = 0 }) == false, "3 : nid sur le couloir = gisement sauté")
check(K.corridor_ok(m3, hq, { x = 0, y = 200 }) == true, "3 : couloir libre = gisement retenu")

-- 4. rang des gisements connus
local m4 = K.new()
K.record(m4, K.key(0, 1), 1, { res = { { name = R, n = 5, a = 1000, x = 30, y = 90 } } })       -- proche, pauvre
K.record(m4, K.key(5, 0), 1, { res = { { name = R, n = 90, a = 900000, x = 330, y = 30 } } })  -- loin, riche
K.record(m4, K.key(0, 5), 1, { res = { { name = R, n = 90, a = 900000, x = 30, y = 330 } } })  -- loin, riche, même score
local ranked = K.rank_known(K.deposits(m4, R, { x = 30, y = 30 }))
check(#ranked == 3, "4 : trois gisements")
check(ranked[1].a == 900000 and ranked[2].a == 900000, "4 : les riches avant le proche pauvre")
check(ranked[1].key < ranked[2].key, "4 : égalité départagée par clé")
check(ranked[3].a == 1000, "4 : le proche pauvre en dernier")

print(string.format("[FIX-P2] %d ok, %d echec(s)", pass, fail))
if fail > 0 then os.exit(1) end
