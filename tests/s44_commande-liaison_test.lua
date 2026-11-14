-- s44 commande-liaison : un ordre de liaison A -> B impose la paire sortie (zone A) -> quai (zone B) du même objet, en tête.
-- Usage : lua5.2 tests/s44_commande-liaison_test.lua
package.path = "./?.lua;" .. package.path
local Co = require("shared.ai3.commande")
local ok, ko = 0, 0
local function check(c, m) if c then ok = ok + 1 else ko = ko + 1; print("  ECHEC : " .. m) end end

local st = Co.new_state()
-- ordre sans A (ancienne zone) : aucune paire imposée
Co.add(st, { kind = "liaison", x = 0, y = 0, r = 10 })
local srcs = { { key = "5:o1", x = 100, y = 0, item = "iron-plate" }, { key = "6:o1", x = 102, y = 0, item = "copper-plate" },
  { key = "7:o1", x = 104, y = 0, item = "iron-plate", linked = true } }
local docks = { { key = "1:q1", x = 2, y = 0, item = "copper-plate" }, { key = "2:q1", x = 3, y = 1, item = "iron-plate" },
  { key = "3:q1", x = 0, y = 0, item = "iron-plate", linked = true } }
check(#Co.forced_pairs(st.orders, docks, srcs) == 0, "zone seule : pas de paire imposée")
-- ordre A (100, 0) -> B (0, 0)
local id = Co.add(st, { kind = "liaison", x = 0, y = 0, r = 10, a = { x = 100, y = 0, r = 10 } })
check(st.orders[2].a and st.orders[2].a.x == 100, "A gardé dans l'ordre")
local fp = Co.forced_pairs(st.orders, docks, srcs)
check(#fp == 1, "une paire imposée")
check(fp[1] and fp[1].ordre == id, "numéro d'ordre")
-- la plus courte : cuivre 6:o1 (102,0) -> 1:q1 (2,0) = 100 ; fer 5:o1 (100,0) -> 2:q1 (3,1) = 98
check(fp[1] and fp[1].src.key == "5:o1" and fp[1].dock.key == "2:q1", "fer, plus courte, liés exclus")
check(fp[1] and fp[1].span == 98, "distance")
-- liés : plus rien de fer, reste le cuivre
srcs[1].linked = true
fp = Co.forced_pairs(st.orders, docks, srcs)
check(fp[1] and fp[1].src.key == "6:o1" and fp[1].dock.key == "1:q1", "repli sur le cuivre")
-- objet différent nulle part : rien
check(#Co.forced_pairs(st.orders, { { key = "9:q1", x = 0, y = 0, item = "gear" } }, srcs) == 0, "objets différents : rien")
-- hors zone A : rien
check(#Co.forced_pairs(st.orders, docks, { { key = "8:o1", x = 50, y = 0, item = "copper-plate" } }) == 0, "hors zone A : rien")
-- déterminisme : deux appels identiques
local a1, a2 = Co.forced_pairs(st.orders, docks, srcs), Co.forced_pairs(st.orders, docks, srcs)
check(a1[1].src.key == a2[1].src.key and a1[1].dock.key == a2[1].dock.key, "déterministe")
print(string.format("s44_commande-liaison : %d OK, %d ECHEC", ok, ko))
os.exit(ko == 0 and 0 or 1)
