-- Le Bourdon (lot BOURDON, 1er/11) : règles pures de shared/robots/bourdon.lua, hors jeu. lua5.2 tests/bourdon_test.lua
package.path = "./?.lua;" .. package.path

local B = require("shared.robots.bourdon")

local ok, bad = 0, 0
local function check(c, nom, detail)
  if c then ok = ok + 1 else bad = bad + 1; print("[BOURDON] ECHEC " .. nom .. " " .. tostring(detail or "")) end
end
local function proche(a, b, e) return math.abs(a - b) <= (e or 1e-3) end

-- ------------------------------------------------------------- table des directions, contre math
for k = 0, 400 do
  local o = k / 400
  local c, s = B.dir(o)
  check(proche(c, math.cos(2 * math.pi * o), 2e-4) and proche(s, math.sin(2 * math.pi * o), 2e-4), "dir contre math", o)
end
check(select(2, B.dir(1.25)) > 0.999, "dir : fraction au-delà d'un tour")
check(B.dir(-1e-17) == 1, "dir : négatif infime, le modulo rend 1")
check(select(2, B.dir(-0.25)) < -0.999, "dir : négatif")
for t = -80, 200 do -- chaque instant de la balance reste calculable (le zéro négatif de la courbe a planté le jeu)
  local x = B.centre_battant(1.5, -10, B.balance(t, -1))
  check(x == x, "battant défini", t)
  x = B.centre_battant(1.5, -10, B.balance(t, 1))
  check(x == x, "battant défini", t)
end

-- ------------------------------------------------------------- géométrie des 6 ancres
check(#B.ANCRES == 6, "6 ancres")
for i, a in ipairs(B.ANCRES) do
  local bx, by = B.bas_chaine(i, 1)
  check(proche(bx, a.sol[1]) and proche(by, a.sol[2] - B.ANCRE_TETE), "posée : bas de chaîne sur la tête d'ancre", i)
  -- u est unitaire et va de la lèvre à la tête d'ancre, long dit la distance
  check(proche(a.u[1] * a.u[1] + a.u[2] * a.u[2], 1, 1e-3), "u unitaire", i)
  check(proche(a.levre[1] + a.u[1] * a.long, bx, 2e-2) and proche(a.levre[2] + a.u[2] * a.long, by, 2e-2), "lèvre + u × long = tête d'ancre", i)
  -- l'orientation tourne bien le bas de la feuille (axe y) vers u
  local c, s = B.dir(a.o)
  check(proche(-s, a.u[1], 2e-3) and proche(c, a.u[2], 2e-3), "orientation de la chaîne : (−sin, cos) = u", i)
  local co, so = B.dir(a.ombre_o)
  check(proche(-so, a.ombre_u[1], 2e-3) and proche(co, a.ombre_u[2], 2e-3), "orientation de l'ombre de chaîne", i)
  -- la chaîne est assez longue pour rester tendue jusque dans la lèvre, posée comme repliée (sinon on verrait son bout)
  check(a.long < B.CHAINE_LONG, "la feuille dépasse la chaîne visible, posée", i)
  -- repliée : le haut de la feuille reste dans la silhouette de la cloche (rayon 14 à la lèvre, 7 à hauteur des vitraux)
  local rx, ry = B.bas_chaine(i, 0)
  local hx, hy = B.centre_chaine(i, rx, ry)
  hx, hy = hx - a.u[1] * B.CHAINE_LONG / 2, hy - a.u[2] * B.CHAINE_LONG / 2
  check(hy < -30 and math.abs(hx) < 11, "repliée : le haut de la chaîne est caché derrière la cloche", string.format("%d %.1f %.1f", i, hx, hy))
  -- le centre de la feuille + demi-longueur retombe sur le bas
  local cx, cy = B.centre_chaine(i, bx, by)
  check(proche(cx + a.u[1] * B.CHAINE_LONG / 2, bx) and proche(cy + a.u[2] * B.CHAINE_LONG / 2, by), "centre de la feuille", i)
end
check(proche(select(2, B.ancre_depuis_bas(3, 4)), 4 + B.ANCRE_TETE), "ancre sous le bas de chaîne")

-- ------------------------------------------------------------- extension
check(B.ext_chute(0) == 0 and B.ext_chute(1) == 1 and B.ext_chute(-1) == 0 and B.ext_chute(2) == 1, "chute : bornes")
check(B.ext_chute(0.5) < 0.5, "chute : accélère")
check(B.ext_leve(0) == 1 and B.ext_leve(1) == 0, "levée : bornes")
for u = 0, 9 do
  check(B.ext_leve(u / 10) >= B.ext_leve((u + 1) / 10), "levée : décroît", u)
  check(B.ext_chute(u / 10) <= B.ext_chute((u + 1) / 10), "chute : croît", u)
end
check(B.hauteur_descente(0) == B.DESCENTE_H and B.hauteur_descente(B.DESCENTE) == 0, "descente : bornes")
for t = 0, B.DESCENTE - 1, 10 do
  check(B.hauteur_descente(t) >= B.hauteur_descente(t + 10), "descente : la cloche baisse", t)
end

-- ------------------------------------------------------------- l'onde, le temps
check(B.rayon(0) == 0 and B.rayon(-5) == 0, "pas d'onde avant le coup")
check(B.rayon(B.fin_onde()) >= B.R_FIN, "l'onde va jusqu'à son rayon de fin")
check(B.R_FIN > B.PORTEE, "l'onde visible dépasse la portée des dégâts")
check(B.force_onde(0) == 1 and B.force_onde(B.PORTEE) == 1 and B.force_onde(B.R_FIN) == 0, "force de l'onde : pleine jusqu'à la portée, éteinte à la fin")
for t = 1, B.fin_onde() do check(B.rayon(t) > B.rayon(t - 1), "l'onde avance", t) end
check(B.rayon2(B.DEBUT_ONDE2) == 0, "seconde onde : part après")
for t = B.DEBUT_ONDE2 + 1, B.fin_onde2() do check(B.rayon2(t) < B.rayon(t), "la seconde onde reste derrière la première", t) end
check(B.echelle_arc(0, 96, 12) == 0.18, "morceau d'arc : plancher d'échelle")
check(B.echelle_arc(60, 96, 12) * 12 >= 2 * 3.1416 * 60 / 96, "morceaux d'arc : se recouvrent à la portée")
check(B.echelle_arc(B.R_FIN, B.POUSSIERES, B.POUSSIERE_LONG) * B.POUSSIERE_LONG >= 2 * 3.1416 * B.R_FIN / B.POUSSIERES, "poussière : se recouvre au rayon de fin")

-- ------------------------------------------------------------- dégâts
check(B.degats(0) == B.DEGAT_CENTRE, "dégâts au centre")
check(proche(B.degats(B.PORTEE), B.DEGAT_BORD), "dégâts au bord")
check(B.degats(B.PORTEE + 0.01) == 0, "rien au-delà de la portée")
for r = 1, 60 do check(B.degats(r) < B.degats(r - 1), "dégâts décroissants", r) end
check(B.tranche(0) == 1 and B.tranche(2.99) == 1 and B.tranche(3) == 2, "tranches")

-- ------------------------------------------------------------- battant, vitraux
check(B.balance(-70) == 0 and B.balance(B.FIN_BALANCE) == 0, "battant : au repos avant et après")
do -- cible à l'est : le bas du battant part vers l'ouest, puis frappe vers l'est
  local bas = B.PIVOT[2] + 24
  local recul = B.centre_battant(0, bas, B.balance(-22, 1))
  local coup = B.centre_battant(0, bas, B.balance(0, 1))
  check(recul < -4 and coup > 3, "battant : recule à l'opposé de la cible, puis frappe vers elle", recul .. " " .. coup)
  check(B.centre_battant(0, bas, B.balance(0, -1)) < -3, "battant : le sens s'inverse")
end
check(B.vitraux(-70) == 1 and B.vitraux(-2) > 1 and B.vitraux(0) == 3 and B.vitraux(200) == 1, "vitraux : montent, éclatent, retombent")
for _, t in ipairs({ -70, -30, 0, 20, 120 }) do
  local a, b, c = B.copies(B.vitraux(t))
  check(proche(a + b + c, B.vitraux(t)) and a <= 1 and b <= 1 and c <= 1, "copies additives : somme", t)
end
local px, py = B.centre_battant(B.PIVOT[1], B.PIVOT[2] + 10, 0)
check(proche(px, 0) and proche(py, B.PIVOT[2] + 10), "battant : angle nul, rien ne bouge")
px, py = B.centre_battant(B.PIVOT[1], B.PIVOT[2] + 10, 0.25)
check(proche(px, -10, 1e-2) and proche(py, B.PIVOT[2], 1e-2), "battant : le quart de tour, sens des aiguilles")

-- ------------------------------------------------------------- flottement
local mini, maxi = 9, -9
for t = 0, 2000 do
  local v = B.flottement(t, 1)
  mini, maxi = math.min(mini, v), math.max(maxi, v)
end
check(maxi > 0.25 and maxi <= 0.33 and mini < -0.25, "flottement : amplitude")
check(B.flottement(100, 1) == B.flottement(100 + B.BALANCEMENT_PERIODE, 1), "flottement : périodique")

-- ------------------------------------------------------------- fissures
local p1 = B.plan_fissures(12345, nil)
local p2 = B.plan_fissures(12345, nil)
check(#p1 == #p2 and #p1 > 100 and #p1 <= B.MAX_SEGMENTS, "plan : déterministe, taille bornée", #p1)
local memes = true
for i = 1, #p1 do
  if p1[i].x ~= p2[i].x or p1[i].y ~= p2[i].y or p1[i].v ~= p2[i].v then memes = false end
end
check(memes, "plan : deux tirages identiques")
local p3 = B.plan_fissures(54321, nil)
check(p3[20].x ~= p1[20].x, "plan : autre graine, autre étoile")
local trie = true
local rmax = 0
for i = 2, #p1 do
  if p1[i].r < p1[i - 1].r then trie = false end
  rmax = math.max(rmax, p1[i].r)
end
check(trie, "plan : trié par arrivée de l'onde")
check(rmax > 45 and rmax <= B.R_FIN, "plan : portée de l'étoile", rmax)
local variantes = {}
for _, sg in ipairs(p1) do
  variantes[sg.v] = true
  check(sg.v >= 1 and sg.v <= 6 and sg.e > 0 and sg.vc >= 0 and sg.vc <= 1, "segment bien formé")
end
check(variantes[1] and variantes[6], "plan : les 6 feuilles servent")
local vers = B.plan_fissures(12345, 0.25) -- vers le sud
local dmax_sud, dmax_nord = 0, 0
for _, sg in ipairs(vers) do
  if sg.y > math.abs(sg.x) then dmax_sud = math.max(dmax_sud, sg.r) end
  if -sg.y > math.abs(sg.x) then dmax_nord = math.max(dmax_nord, sg.r) end
end
check(dmax_sud > dmax_nord, "plan : plus loin vers la cible", dmax_sud .. " / " .. dmax_nord)

-- ------------------------------------------------------------- fabrication (lot ROBOTS-JEU) : données et plafond de géants
do
  local Ro = require("shared.content.robots")
  local usine = Ro.factory(B.USINE)
  check(usine ~= nil and usine.size == 11 and usine.age == 13, "fabriqué au Portique (11 × 11, âge 13)", B.USINE)
  check(B.AGE == 15 and B.TECH.epoch == B.AGE, "âge 15, technologie de l'âge 15")
  check(B.OBJET ~= B.NOM and B.POSE ~= B.NOM, "l'objet pose le relais, jamais le spider-vehicle (cerveau des factions)")
  local n_ing = 0
  for _, g in ipairs(B.FAB.ingredients) do
    n_ing = n_ing + 1
    check(type(g[1]) == "string" and g[2] >= 1 and g[2] <= 100, "ingrédient de 1 à 100 (RB0-1)", g[1] .. " " .. tostring(g[2]))
  end
  check(n_ing >= 3 and B.FAB.temps > 0, "recette : au moins 3 ingrédients, durée positive")
  local crowned = Ro.robot("crowned")
  local seg = false
  for _, g in ipairs(B.FAB.ingredients) do if g[1] == crowned.segment_item then seg = true end end
  check(seg, "10 segments du Couronné : la cloche vient après le dernier géant", crowned.segment_item)
  local pre = Ro.tech(B.TECH.prerequisites[1])
  check(pre ~= nil and pre.epoch == 15, "prérequis : la technologie du Couronné (âge 15)", tostring(B.TECH.prerequisites[1]))
  check(Ro.tech(B.TECHNO) == nil, "technologie propre au Bourdon, hors des paliers de Ro.TECHS")
  -- plafond : un Bourdon compte pour un géant
  check(B.peut_poser({ actif = true, geants = 2, admis = 3 }), "plafond : 2 géants sur 3, il descend")
  check(not B.peut_poser({ actif = true, geants = 3, admis = 3 }), "plafond : 3 sur 3, refusé")
  check(not B.peut_poser({ actif = true, geants = 0, admis = Ro.giant_allowed(12) }), "âge 12 : aucun géant admis, refusé")
  check(B.peut_poser({ actif = true, geants = 0, admis = Ro.giant_allowed(15) }), "âge 15 : admis")
  check(not B.peut_poser({ actif = false, geants = 0, admis = 3 }), "robots éteints : refusé")
  check(not B.peut_poser(nil), "paramètres absents : refusé")
  -- mutants de la règle : chacun doit être vu par au moins un contrôle ci-dessus
  local function vu(regle)
    local cas = { { { actif = true, geants = 2, admis = 3 }, true }, { { actif = true, geants = 3, admis = 3 }, false },
      { { actif = false, geants = 0, admis = 3 }, false }, { { actif = true, geants = 0, admis = 0 }, false } }
    for _, c in ipairs(cas) do if regle(c[1]) ~= c[2] then return true end end
    return false
  end
  check(vu(function(p) return p.actif and p.geants <= p.admis end), "mutant « <= » vu")
  check(vu(function(p) return p.geants < p.admis end), "mutant « sans le réglage » vu")
  check(vu(function(p) return p.actif end), "mutant « sans plafond » vu")
  check(not vu(B.peut_poser), "témoin : la règle du lot passe ses propres cas")
end
-- le script : le relais remplacé, le compte branché au plafond, la pose fabriquée vérifie le plafond
do
  local f = assert(io.open("script/robots/bourdon.lua", "r"))
  local s = f:read("*a")
  f:close()
  check(s:find("Armee.hooks.extra_giants = M.compte", 1, true) ~= nil, "script : Bourdons comptés au plafond de géants")
  check(s:find("B.peut_poser(", 1, true) ~= nil and s:find("e.name == B.POSE", 1, true) ~= nil, "script : relais lu, plafond vérifié")
  f = assert(io.open("script/robots/armee.lua", "r"))
  s = f:read("*a")
  f:close()
  check(s:find("Armee.hooks.extra_giants(force_name)", 1, true) ~= nil, "armee : Armee.giants lit le compte des Bourdons")
  check(s:find("remote.call(\"fo-xp\", \"geants\", force_name)", 1, true) ~= nil and s:find("itf[\"fo-xp\"].geants", 1, true) ~= nil,
    "armee : géants du lot EXPERIMENTAUX (interface fo-xp) comptés au même plafond, sous garde")
end

-- ------------------------------------------------------------- les fichiers du lot : pas de trigonométrie, pas de hasard moteur
local function contient(path, motif)
  local f = assert(io.open(path, "r"))
  local s = f:read("*a")
  f:close()
  return s:find(motif, 1, true) ~= nil
end
for _, p in ipairs({ "shared/robots/bourdon.lua", "script/robots/bourdon.lua" }) do
  for _, motif in ipairs({ "math.sin", "math.cos", "math.atan", "math.random", "os.time", "os.clock" }) do
    check(not contient(p, motif), "interdit dans " .. p, motif)
  end
end

print(string.format("[BOURDON] BILAN : %d OK, %d ECHEC(S)", ok, bad))
os.exit(bad == 0 and 0 or 1)
