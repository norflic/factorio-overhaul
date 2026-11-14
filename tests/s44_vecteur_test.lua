-- s44 vecteur : ligne de tourelles perpendiculaire à l'axe d'approche (shared/team/vecteur.lua) et priorité de la centrale attaquée (G.plan).
-- Usage : lua5.2 tests/s44_vecteur_test.lua (depuis la racine du mod).
package.path = "./?.lua;" .. package.path
local V = require("shared.team.vecteur")
local G = require("shared.team.garde_centrale")
local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1; print("ECHEC : " .. m) end end

-- attaquant plein nord (y négatif) à 40 tuiles : ligne horizontale à 6 tuiles au nord de la structure
local l = V.ligne(0, 0, 0, -40, 6, 5, 3)
check(#l == 5, "5 emplacements")
local ok = true
for _, q in ipairs(l) do if q.y ~= -6 then ok = false end end
check(ok, "tous à 6 tuiles devant, côté ennemi (y = -6)")
check(l[1].x == 0 and math.abs(l[2].x) == 3 and l[3].x == -l[2].x and math.abs(l[4].x) == 6, "du centre vers les bords, pas de 3 (perpendiculaire)")
-- attaquant à l'est : ligne verticale à x = 6
local e = V.ligne(10, 10, 50, 10, 6, 3, 3)
check(e[1].x == 16 and e[2].x == 16 and e[3].x == 16 and e[2].y ~= e[3].y, "attaquant à l'est : ligne verticale devant (x = 16)")
-- diagonale : centre de ligne entre la structure et l'ennemi, perpendiculaire (produit scalaire nul)
local dg = V.ligne(0, 0, 30, 30, 6, 3, 3)
check(dg[1].x > 0 and dg[1].y > 0, "diagonale : centre de ligne côté ennemi")
local dx, dy = dg[2].x - dg[1].x, dg[2].y - dg[1].y
check(math.abs(dx * 30 + dy * 30) <= 2 * 30, "diagonale : ligne perpendiculaire à l'axe (à l'arrondi près)")
-- jamais au-delà de l'attaquant
local pr = V.ligne(0, 0, 3, 0, 6, 1, 3)
check(pr[1].x == 3, "attaquant à 3 tuiles : ligne bornée à sa position")
check(#V.ligne(5, 5, 5, 5, 6, 5, 3) == 0, "attaquant confondu : pas d'axe")
check(V.fresh({ ax = 1, t = 100 }, 100 + V.TTL - 1) and not V.fresh({ ax = 1, t = 100 }, 100 + V.TTL), "relevé valable TTL ticks")
check(not V.fresh(nil, 0), "pas de relevé")

-- G.plan : deux centrales sans garde ; la seconde attaquée par le nord passe devant, et ses premiers emplacements sont au nord
local function plant(id, cx, cy, threat)
  return { id = id, boilers = 1, threat = threat,
    pieces = { { x = cx - 2, y = cy }, { x = cx + 2, y = cy }, { x = cx, y = cy + 3 } } }
end
local base = G.plan({ plant("a", 0, 0), plant("b", 100, 0) }, {}, 18, 10)
check(base.pick.id == "a", "sans attaque : la première (règle inchangée)")
check(base.pick.need.sites[1].x > 0 and base.pick.need.sites[1].y == 1, "sans attaque : anneau fixe, est d'abord (inchangé)")
local hot = G.plan({ plant("a", 0, 0), plant("b", 100, 0, { x = 100, y = -60 }) }, {}, 18, 10)
check(hot.pick.id == "b", "centrale attaquée choisie en premier")
local s1 = hot.pick.need.sites[1]
check(s1.y < 0 and math.abs(s1.x - 100) <= 1, "premier emplacement entre l'ennemi (nord) et la centrale")
local all = true
for i = 1, 3 do local q = hot.pick.need.sites[i]; if not G.covers(hot.pick.pieces, q.x, q.y, 18) then all = false end end
check(all, "emplacements de la ligne à portée de toutes les pièces")
local rest = plant("b", 100, 0, { x = 100, y = -60 }); rest.rest = true
check(G.plan({ plant("a", 0, 0), rest }, {}, 18, 10).pick.id == "b", "centrale attaquée : sort du repos")

print(string.format("s44 vecteur : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
