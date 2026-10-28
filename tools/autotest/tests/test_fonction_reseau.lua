-- Lot RESEAU-VIVANT : test hors jeu de tools/autotest/fo-autotest/scenarios/fonction_reseau.lua (mesure à vide du réseau).
-- Usage (depuis la racine du mod) : lua5.2 tools/autotest/tests/test_fonction_reseau.lua -> « BILAN : N OK, 0 ECHEC(S) »
package.path = "tools/autotest/fo-autotest/?.lua;" .. package.path
local Z = require("scenarios/fonction_reseau")

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end

local function pole(x, y, nb, name) return { x = x, y = y, name = name or "p", supply = 2.5, nb = nb or {} } end
local function box(x, y) return { x0 = x - 0.5, y0 = y - 0.5, x1 = x + 0.5, y1 = y + 0.5 } end

-- 1. chaîne de 3 poteaux (1-2-3), centrale au bout 1, consommateur au bout 3 : aucun redondant, rien de serré
do
  local poles = { pole(0, 0, { 2 }), pole(7, 0, { 1, 3 }), pole(14, 0, { 2 }) }
  local R = Z.measure(poles, { box(14, 1) }, { box(0, 1) })
  check(R.powered == 1, "chaine : 1 alimente")
  check(R.single == 0 and R.glouton == 0, "chaine : aucun poteau redondant")
  check(R.pairs_lt2 == 0, "chaine : pas de paire serree")
  check(R.sans_poteau == 0 and R.ilots == 0, "chaine : tout couvert")
  check(R.comps == 1 and R.comps_gen == 1, "chaine : une composante avec centrale")
end

-- 2. doublon : deux poteaux à 1 tuile, tous deux reliés, couvrant le même consommateur
do
  local poles = { pole(0, 0, { 2, 3 }), pole(7, 0, { 1, 3, 4 }), pole(8, 0, { 1, 2, 4 }), pole(14, 0, { 2, 3 }) }
  local R = Z.measure(poles, { box(14, 1) }, { box(0, 1) })
  check(R.pairs_lt2 == 1 and R.pairs_lt1 == 1, "doublon : une paire serree")
  check(R.poles_in_pair == 2, "doublon : deux poteaux en paire")
  check(R.single == 2, "doublon : chacun des deux est redondant seul")
  check(R.glouton == 1, "doublon : on n'en retire qu'un (l'autre devient pivot)")
  check(R.powered == 1, "doublon : le consommateur reste alimente")
end

-- 3. poteau de nom différent : pas une paire
do
  local poles = { pole(0, 0, { 2 }, "a"), pole(1, 0, { 1 }, "b") }
  local R = Z.measure(poles, {}, { box(0, 1) })
  check(R.pairs_lt2 == 0, "noms differents : pas de paire")
end

-- 4. île sans centrale : consommateur couvert mais pas alimenté
do
  local poles = { pole(0, 0, {}), pole(30, 0, {}) }
  local R = Z.measure(poles, { box(30, 1), box(100, 100) }, { box(0, 1) })
  check(R.powered == 0, "ile : rien d'alimente")
  check(R.ilots == 1, "ile : un consommateur sur ilot")
  check(R.sans_poteau == 1, "ile : un consommateur sous aucun poteau")
  check(R.comps == 2 and R.comps_gen == 1, "ile : 2 composantes dont 1 avec centrale")
  check(R.poles_hors_service == 1, "ile : un poteau hors service")
end

-- 5. poteau pivot (point d'articulation) et poteau seul à couvrir : non redondants
do
  local poles = { pole(0, 0, { 2 }), pole(7, 0, { 1, 3 }), pole(14, 0, { 2 }) }
  local R = Z.measure(poles, { box(14, 1), box(7, 1) }, { box(0, 1) })
  check(R.single == 0, "pivot : le poteau du milieu n'est pas redondant")
  -- poteau terminal sans rien à couvrir ni à relier : redondant
  local poles2 = { pole(0, 0, { 2 }), pole(7, 0, { 1, 3 }), pole(14, 0, { 2 }), pole(30, 30, { 5 }), pole(37, 30, { 4 }) }
  local R2 = Z.measure(poles2, { box(7, 1) }, { box(0, 1) })
  check(R2.powered == 1, "antenne : le consommateur est alimente")
  check(R2.single == 1, "antenne : seul le poteau terminal du reseau vivant est redondant (l'ilot est hors service): " .. R2.single)
  check(R2.poles_hors_service == 2, "antenne : l'ilot sans centrale compte hors service")
end

-- 6. déterminisme
do
  local poles = { pole(0, 0, { 2, 3 }), pole(7, 0, { 1, 3, 4 }), pole(8, 0, { 1, 2, 4 }), pole(14, 0, { 2, 3 }) }
  local a = Z.line(Z.measure(poles, { box(14, 1) }, { box(0, 1) }))
  local b = Z.line(Z.measure(poles, { box(14, 1) }, { box(0, 1) }))
  check(a == b, "determinisme de la ligne")
  check(a:find("redondants_glouton=1", 1, true) ~= nil, "la ligne porte le glouton")
end

-- 7. lecture du moteur simulé
do
  local function ent(x, y, name, un)
    return { valid = true, unit_number = un, position = { x = x, y = y }, name = name or "p", prototype = { supply_area_distance = 2.5 },
      neighbours = { copper = {} }, bounding_box = { left_top = { x = x - 0.5, y = y - 0.5 }, right_bottom = { x = x + 0.5, y = y + 0.5 } } }
  end
  local a, b = ent(0, 0, "p", 1), ent(7, 0, "p", 2)
  a.neighbours.copper = { b }
  b.neighbours.copper = { a }
  local s = { find_entities_filtered = function() return { b, a } end }
  local poles, cons, prods, ents = Z.read(s, "f", { ent(7, 1, "m", 9) }, { ent(0, 1, "g", 10) })
  check(#poles == 2 and ents[1] == a, "lecture : poteaux tries par numero d'unite")
  check(poles[1].nb[1] == 2 and poles[2].nb[1] == 1, "lecture : voisins par fil")
  local R = Z.measure(poles, cons, prods)
  check(R.powered == 1, "lecture : alimente")
end

print(string.format("BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
