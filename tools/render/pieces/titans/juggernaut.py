"""JUGGERNAUT, titan ALLIÉ (lot TITANS, 9/11 ; ANIMÉ au lot TITANS-FINITIONS, 10/11) : Jaeger lourd humanoïde, bipède DIGITIGRADE,
canon rotatif à focalisation annulaire (bras droit), griffes d'énergie (bras gauche), cœur à vortex dans le dos sous un anneau
magnétique flottant. Environ 36 tuiles de haut à l'écran (les géants font 45 à 50 : un Jaeger ramassé, plus large d'épaules).

Modèle PARAMÉTRIQUE low-poly (le DC : « pas de rendu 8K ») : primitives du kit des géants (geo.py), un objet par matière (Lot).
`build(S, lot, stage, u=None, attaque=None, dirs=False)` : stage 1, 2 ou 3 = paliers d'évolution 1-2, 3-4, 5-6 (shared/robots/titans.lua) :
plaques de blindage, anneaux et pointes de cristal s'ajoutent, le canon grossit.
- u = None et attaque = None : pose de REPOS, UNE image (lacet PSI : il regarde vers le sud-est), comme les géants (feuilles historiques) ;
- u dans [0, 1[ : cycle de MARCHE (pas digitigrade : le pied recule au sol puis revient en l'air, genou résolu par IK à deux segments,
  balancement du torse et des bras) ; attaque dans [0, 1[ : SALVE du canon (le bras se lève à l'horizontale, les anneaux de focalisation
  glissent vers la bouche, le vortex grossit, éclair de bouche, recul) ; dirs = True : repère LOCAL sans lacet (+x = face), le rendu
  tourne le modèle sur 8 directions (batch_titans.anime, comme le Kaiju).
Repère LOCAL : +x = face, +y = gauche, +z = haut. FOULEE (tuiles par cycle) est lue par feuilles_titans et recopiée dans
shared/robots/titans.lua (T.JUGGERNAUT.anime.foulee, vérifié par tests/titans_test.lua).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
XP = os.path.normpath(os.path.join(HERE, "..", "experimentaux"))
if XP not in sys.path:
    sys.path.insert(0, XP)
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import geo as G  # noqa: E402
import greb as R  # noqa: E402
import titans_mat as TM  # noqa: E402

PREFIX = "ju_"
PSI = -math.radians(40.0)
KE = 1.15                    # échelle générale : 31 unités de modèle -> 36 tuiles
GRIS = os.environ.get("FO_GRIS", "") == "1"
HAUTEUR = 32.4 * KE          # hauteur du modèle (pour la caméra et le recadrage)
RAYON = 12.0 * KE            # rayon au sol englobant (ombre comprise : calculé par batch_titans)
# Série animée (lue par batch_titans et feuilles_titans) : images par animation, densité du rendu (px par tuile ; 20 : le Juggernaut fait
# 36 tuiles de haut, 8 directions × 12 images × 3 stades : à 24 comme le Kaiju les feuilles pèseraient 1,4 fois plus), rayon au sol et
# hauteur englobants (cadre fixe pour toutes les images et directions, en tuiles), portée du liseré de contact.
# ART-16DIR (11/11) : 16 directions réelles ; densité 12,5 pour tenir 80 Mpx HR avec 16 directions (lueur à demi-densité, ombre au quart)
SERIE = {"course": 8, "attaque": 4, "densite": 12.5, "R": 16.0, "zmax": 38.5, "dirs": 16}
AO = 0.6
GLOW_BLANC = False           # allié : la lueur garde ses couleurs (cyan, magenta)
AMP = 3.0                    # amplitude du pas (unités de modèle) : le pied va de +AMP à -AMP au sol
LEVEE = 1.6                  # levée du pied en l'air
FOULEE = 2 * 3.0 * 1.15      # tuiles par cycle = 2 × AMP × KE (distance_per_frame : FOULEE / images)
ATTAQUE = ((0.55, 0.0, 0.0), (1.0, 0.6, 1.0), (0.75, 0.35, 0.45), (0.35, 0.1, 0.0))   # par image : charge, recul, éclair


def XF(v):
    p = G.rot_z(v, PSI)
    return (p[0] * KE, p[1] * KE, max(0.0, p[2] * KE))


def XF0(v):
    """Sans lacet : repère local du modèle (+x = face) ; le rendu tourne le modèle par direction."""
    return (v[0] * KE, v[1] * KE, max(0.0, v[2] * KE))


# ------------------------------------------------------------------------------------------------ primitives angulaires
def hexseg(a, b, ra, rb, n=6, rot=0.0):
    """Segment à section polygonale (membre blindé, angulaire) de a (rayon ra) à b (rayon rb), bouché aux deux bouts."""
    fr = G._frames([a, b])
    rings = []
    for p, r, (t, n1, n2) in ((a, ra, fr[0]), (b, rb, fr[1])):
        ring = []
        for j in range(n):
            ang = rot + G.TAU * (j + 0.5) / n
            ring.append(G.add(p, G.add(G.mul(n1, r * math.cos(ang)), G.mul(n2, r * math.sin(ang)))))
        rings.append(ring)
    return G.loft(rings, True, True)


def pointe(base, d, L, r, n=6):
    """Pointe de cristal : prisme hexagonal qui s'élargit puis file en pointe, de `base` dans la direction `d`."""
    prof = [(0.0, r * 0.55), (L * 0.22, r), (L * 0.62, r * 0.62), (L, 0.0)]
    return G.oriente(G.tour(prof, n, "z", cap0=True), base, d)


def plaque(p, n, w, h, e=0.25, up=(0.0, 0.0, 1.0), coins=0.8, bis=0.82):
    """Plaque de blindage angulaire (hexagone allongé biseauté) posée au point p, normale n."""
    poly = [(-w / 2 * coins, -h / 2), (w / 2 * coins, -h / 2), (w / 2, 0.0), (w / 2 * coins, h / 2), (-w / 2 * coins, h / 2), (-w / 2, 0.0)]
    return R.pose(G.prisme(poly, 0.0, e, top_scale=bis), p, n, up)


def anneau(c, axe, rayon, e, ep):
    """Anneau magnétique : section rectangulaire (e : largeur radiale, ep : épaisseur), axe « x », « y » ou « z », centre c."""
    prof = [(-ep, rayon), (ep, rayon), (ep, rayon + e), (-ep, rayon + e), (-ep, rayon)]
    return G.tour(prof, 48, axe, c)


def rainure(c, axe, rayon, ep):
    """Gorge lumineuse d'un anneau (tube ouvert, mince) : couche lueur."""
    return G.tour([(-ep, rayon), (ep, rayon)], 48, axe, c)


# ------------------------------------------------------------------------------------------------ cinématique (marche)
def pas(u, amp, levee, appui=0.6):
    """Cycle d'un pied, u dans [0, 1[ : appui (le pied recule au sol de +amp à -amp), puis vol (il revient en l'air). Rend (avance, hauteur)."""
    u = u % 1.0
    if u < appui:
        return amp * (1.0 - 2.0 * u / appui), 0.0
    v = (u - appui) / (1.0 - appui)
    s = v * v * (3.0 - 2.0 * v)
    return amp * (2.0 * s - 1.0), levee * math.sin(math.pi * v) ** 0.8


def ik2(a, c, l1, l2, pole):
    """Genou d'une jambe à deux segments de a à c, plié du côté de `pole`."""
    v = G.sub(c, a)
    L = max(G.length(v), 1e-6)
    u = G.mul(v, 1.0 / L)
    L = min(L, (l1 + l2) * 0.995)
    x = (l1 * l1 - l2 * l2 + L * L) / (2.0 * L)
    h = math.sqrt(max(l1 * l1 - x * x, 0.0))
    p = G.sub(pole, G.mul(u, G.dot(pole, u)))
    p = G.norm(p)
    return G.add(G.add(a, G.mul(u, x)), G.mul(p, h))


# ------------------------------------------------------------------------------------------------ parties
def jambe(lot, M, s, stage, r, u=None, bob=0.0):
    """Jambe digitigrade du côté s (+1 gauche, -1 droite) : hanche, cuisse vers l'avant, tibia vers l'arrière, métatarse, 3 griffes.
    Propulseurs (tuyères) au mollet ; conduits lumineux sur la cuisse. u : phase du pied (None : repos)."""
    y = s * 4.3
    H = (0.0, y, 17.0 + bob)
    K0 = (3.7, y + s * 0.3, 11.4)
    A0 = (-1.5, y + s * 0.5, 5.6)
    T0 = (2.6, y + s * 0.7, 0.9)
    if u is None:
        K, A, T = K0, A0, T0
    else:
        dx, dz = pas(u, AMP, LEVEE)
        T = (T0[0] + dx, T0[1], T0[2] + dz)
        A = G.add(T, G.sub(A0, T0))                       # pied et métatarse rigides
        l1, l2 = G.length(G.sub(K0, (0.0, y, 17.0))), G.length(G.sub(A0, K0))
        K = ik2(H, A, l1, l2, (1.0, 0.0, 0.3))           # genou vers l'avant (digitigrade)
    # articulations : sphères de structure
    for p, rr in ((H, 1.6), (K, 1.3), (A, 1.05)):
        lot.put(M["struct"], G.sphere(p, rr, 10, 5))
    lot.put(M["accent"], G.boite(G.add(H, (0.9, s * 1.3, 0.2)), (0.45, 0.22, 0.22)))
    lot.put(M["accent"], G.boite(G.add(K, (0.8, s * 1.0, 0.0)), (0.3, 0.18, 0.18)))
    # cuisse : gros segment hexagonal blindé + plaque avant
    lot.put(M["blind"], hexseg(H, K, 2.1, 1.5, 6, 0.3))
    d = G.norm(G.sub(K, H))
    m = G.lerp(H, K, 0.5)
    lot.put(M["blind2"], plaque(G.add(m, (0.9, s * 0.9, 0.3)), G.norm((1.0, s * 0.6, 0.45)), 2.4, 3.6, 0.3, up=d))
    # conduit lumineux le long de la cuisse (côté extérieur)
    lot.put(M["conduit"], hexseg(G.add(H, (0.4, s * 1.75, -0.6)), G.add(K, (0.2, s * 1.3, 0.3)), 0.14, 0.12, 6))
    # tibia (vers l'arrière), plus fin, structure apparente + carénage
    lot.put(M["struct"], hexseg(K, A, 1.2, 0.95, 8))
    lot.put(M["blind2"], plaque(G.lerp(K, A, 0.45), G.norm((-0.8, s * 0.7, 0.3)), 1.5, 3.2, 0.26, up=G.norm(G.sub(A, K))))
    # vérin de propulsion (piston) de la hanche au talon
    lot.put(M["canon"], G.tube([G.add(H, (-1.2, 0.0, -0.4)), G.add(A, (-0.6, 0.0, 0.5))], 0.32, 8))
    lot.put(M["struct"], G.tube([G.lerp(G.add(H, (-1.2, 0.0, -0.4)), A, 0.55), G.add(A, (-0.6, 0.0, 0.5))], 0.48, 8))
    # tuyères du mollet (propulsion) : deux cônes vers l'arrière-bas, gorge lumineuse
    for q in (-0.55, 0.55):
        base = G.add(A, (-0.9, q + s * 0.4, 1.4))
        lot.put(M["canon"], G.oriente(G.tour([(0.0, 0.35), (0.8, 0.5), (1.3, 0.42), (1.35, 0.3)], 10, "z", cap0=True), base, (-0.8, 0.0, -0.45)))
        lot.put(M["turq"], G.oriente(G.tour([(1.2, 0.28), (1.25, 0.0)], 10, "z"), base, (-0.8, 0.0, -0.45)))
    # métatarse et pied : segment incliné vers l'avant, cheville blindée
    lot.put(M["blind"], hexseg(A, T, 1.1, 0.9, 6, 0.2))
    # griffes (3 avant, 1 arrière) : prismes effilés, ivoire métallique
    for k, (ax, ay) in enumerate(((1.0, 0.0), (0.7, 0.85), (0.7, -0.85))):
        base = G.add(T, (0.3 * ax, ay * 0.6, 0.2))
        lot.put(M["os"], pointe(base, G.norm((ax, ay * 0.7, -0.22)), 2.6 if k == 0 else 2.1, 0.42, 5))
    lot.put(M["os"], pointe(G.add(A, (-0.5, 0.0, -1.2)), (-0.9, 0.0, -0.45), 1.8, 0.36, 5))
    # genouillère (stage 3) et jupe de cuisse (stage 2+)
    if stage >= 2:
        lot.put(M["blind2"], plaque(G.add(H, (1.0, s * 1.0, 1.6)), G.norm((0.7, s * 0.9, 0.5)), 2.8, 2.2, 0.32, up=(0, 0, 1)))
        lot.put(M["blind"], plaque(G.add(H, (-1.2, s * 1.2, 1.4)), G.norm((-0.5, s * 1.0, 0.4)), 2.4, 2.0, 0.3, up=(0, 0, 1)))
    if stage >= 3:
        lot.put(M["blind"], plaque(G.add(K, (1.1, s * 0.6, 0.4)), G.norm((1.0, s * 0.4, 0.2)), 2.0, 2.6, 0.34, up=(0, 0, 1)))
        lot.put(M["cristal"], pointe(G.add(K, (0.9, s * 0.9, 0.9)), G.norm((0.7, s * 0.5, 0.9)), 1.6, 0.3))


def torse(lot, M, stage, r):
    """Bassin, torse en coque angulaire, plaques pectorales, tête-visière, cœur à vortex et son anneau dans le dos."""
    # bassin : prisme octogonal
    lot.put(M["blind2"], G.prisme(R.octo((0.0, 0.0), 4.6, 8), 15.8, 18.4, top_scale=1.15))
    lot.put(M["struct"], G.prisme(R.octo((0.0, 0.0), 3.4, 8), 18.2, 18.8, top_scale=0.95))
    # torse : loft de sections rectangulaires biseautées (épaules larges)
    def sect(z, w, d):
        return [(w, -d, z), (w * 0.55, -d * 1.15, z), (-w * 0.6, -d * 1.1, z), (-w, -d * 0.7, z), (-w, d * 0.7, z), (-w * 0.6, d * 1.1, z),
                (w * 0.55, d * 1.15, z), (w, d, z)]
    rings = [sect(18.4, 2.0, 3.2), sect(20.5, 2.8, 4.0), sect(23.5, 3.1, 5.0), sect(26.2, 2.7, 6.0), sect(27.6, 1.9, 4.6)]
    lot.put(M["blind"], G.loft(rings, True, True))
    # plaques pectorales et abdominales (avant, +x)
    for (z, w, h, yy) in ((25.0, 2.6, 2.4, 1.7), (25.0, 2.6, 2.4, -1.7), (22.2, 3.6, 1.8, 0.0), (20.2, 3.0, 1.5, 0.0)):
        lot.put(M["blind2"], plaque((3.0 if z > 24 else 2.9, yy, z), G.norm((1.0, yy * 0.15, 0.25)), w, h, 0.3))
    # conduit central lumineux (poitrine) et fentes de ventilation lumineuses
    lot.put(M["conduit"], G.boite((3.15, 0.0, 23.2), (0.22, 0.5, 5.2)))
    for yy in (-1.2, 1.2):
        lot.put(M["turq"], G.boite((2.95, yy, 21.4), (0.2, 1.0, 0.25)))
    # épaulières (stage 1 : simples ; 2 : étagées ; 3 : lourdes avec cristal)
    for s in (-1, 1):
        c = (0.3, s * 6.6, 26.9)
        lot.put(M["blind"], R.pose(G.prisme([(-2.0, -1.6), (2.2, -1.6), (2.6, 0.0), (2.2, 1.6), (-2.0, 1.6), (-2.5, 0.3)], 0.0, 1.3, 0.78), c, G.norm((0.0, s * 0.35, 1.0)), (1, 0, 0)))
        if stage >= 2:
            lot.put(M["blind2"], R.pose(G.prisme([(-1.6, -1.3), (1.8, -1.3), (2.1, 0.0), (1.8, 1.3), (-1.6, 1.3)], 0.0, 1.0, 0.8), G.add(c, (0.2, s * 0.9, 1.3)), G.norm((0.1, s * 0.5, 1.0)), (1, 0, 0)))
            lot.put(M["conduit"], hexseg(G.add(c, (-1.4, s * 0.5, 1.45)), G.add(c, (1.8, s * 0.5, 1.45)), 0.12, 0.12))
        if stage >= 3:
            lot.put(M["blind"], R.pose(G.prisme([(-1.2, -1.1), (1.5, -1.1), (1.8, 0.0), (1.5, 1.1), (-1.2, 1.1)], 0.0, 0.9, 0.8), G.add(c, (0.3, s * 1.6, 2.5)), G.norm((0.2, s * 0.7, 1.0)), (1, 0, 0)))
            for k in range(2):
                lot.put(M["cristal"], pointe(G.add(c, (-0.6 + 1.2 * k, s * 1.4, 2.9)), G.norm((-0.3 + 0.2 * k, s * 0.5, 1.0)), 2.6 - 0.5 * k, 0.4))
    # tête : visière angulaire, fente lumineuse, antennes
    lot.put(M["blind2"], G.loft([[(1.2, -1.2, 27.8), (2.4, -0.9, 27.8), (2.4, 0.9, 27.8), (1.2, 1.2, 27.8), (-0.6, 1.0, 27.8), (-0.6, -1.0, 27.8)],
                                [(1.5, -1.3, 29.3), (2.9, -0.9, 29.3), (2.9, 0.9, 29.3), (1.5, 1.3, 29.3), (-0.8, 1.1, 29.3), (-0.8, -1.1, 29.3)],
                                [(1.0, -0.9, 30.9), (2.0, -0.6, 30.9), (2.0, 0.6, 30.9), (1.0, 0.9, 30.9), (-0.9, 0.7, 30.9), (-0.9, -0.7, 30.9)]], True, True))
    lot.put(M["conduit"], G.boite((2.85, 0.0, 29.4), (0.2, 1.5, 0.28)))
    for s in (-1, 1):
        lot.put(M["struct"], G.tube([(-0.4, s * 0.8, 30.6), (-1.0, s * 1.4, 32.6)], 0.1, 6))
    # dos : cœur à vortex dans une cage, anneau magnétique flottant autour (axe x), gorge lumineuse
    C = (-3.3, 0.0, 24.2)
    lot.put(M["coeur"], G.sphere(C, 1.35, 16, 8))
    lot.put(M["halo"], G.sphere(C, 2.3, 16, 8))
    for k in range(4):
        a = G.TAU * (k + 0.5) / 4
        p0 = (C[0] + 0.2, C[1] + 1.1 * math.cos(a), C[2] + 1.1 * math.sin(a))
        p1 = (C[0] + 1.3, C[1] + 1.9 * math.cos(a), C[2] + 1.9 * math.sin(a))
        lot.put(M["struct"], G.tube([p0, p1], 0.18, 6))
    lot.put(M["anneau"], anneau((C[0] - 0.9, 0.0, C[2]), "x", 2.9, 0.55, 0.22))
    lot.put(M["turq"], rainure((C[0] - 1.15, 0.0, C[2]), "x", 3.15, 0.08))
    # échappements dorsaux (2 cheminées) et conduits du dos
    for s in (-1, 1):
        lot.put(M["canon"], G.tour([(26.0, 0.55), (28.6, 0.5), (29.2, 0.6), (29.3, 0.45)], 10, "z", (-1.6, s * 2.6, 0.0), cap0=True))
        lot.put(M["turq"], G.tour([(29.1, 0.4), (29.15, 0.0)], 10, "z", (-1.6, s * 2.6, 0.0)))
    if stage >= 2:
        # pointes de cristal dorsales (3), puis 5 au stage 3
        n = 3 if stage == 2 else 5
        for k in range(n):
            yy = (k - (n - 1) / 2.0) * 1.3
            L = 3.6 - 0.55 * abs(k - (n - 1) / 2.0)
            lot.put(M["cristal"], pointe((-2.2, yy, 27.2 - 0.2 * abs(yy)), G.norm((-0.55, yy * 0.08, 1.0)), L, 0.42))
    if stage >= 3:
        # grand halo magnétique derrière le torse
        lot.put(M["anneau"], anneau((-5.2, 0.0, 23.6), "x", 6.3, 0.7, 0.26))
        lot.put(M["turq"], rainure((-5.5, 0.0, 23.6), "x", 6.65, 0.1))
        lot.put(M["cristal"], rainure((-5.0, 0.0, 23.6), "x", 6.35, 0.06))


def bras_canon(lot, M, stage, r, swing=0.0, charge=0.0, recul=0.0, eclair=0.0):
    """Bras droit : épaule, bras, canon rotatif à 6 tubes, anneaux de focalisation flottants, vortex à la bouche.
    swing : rotation du bras autour de l'épaule (axe y ; négatif = le bras se lève) ; attaque : charge (anneaux vers la bouche, vortex
    plus gros), recul (le bras rentre le long de son axe), eclair (cône de lumière à la bouche)."""
    s = -1
    S_ = (0.6, s * 6.4, 25.4)
    E0 = (1.4, s * 7.9, 20.8)
    M0 = (7.2, s * 8.1, 19.2)
    E = G.rot_y(E0, swing, S_)
    Mz = G.rot_y(M0, swing, S_)
    d = G.norm(G.sub(Mz, E))
    if recul > 0:
        E = G.add(E, G.mul(d, -recul))
        Mz = G.add(Mz, G.mul(d, -recul))
    lot.put(M["struct"], G.sphere(S_, 1.25, 10, 5))
    lot.put(M["accent"], G.boite(G.add(S_, (0.9, s * 0.8, -0.3)), (0.35, 0.2, 0.2)))
    lot.put(M["blind"], hexseg(S_, E, 1.35, 1.05, 6, 0.2))
    lot.put(M["conduit"], hexseg(G.add(S_, (0.9, s * 0.9, -0.2)), G.add(E, (0.8, s * 0.6, 0.4)), 0.12, 0.12))
    lot.put(M["struct"], G.sphere(E, 1.05, 10, 5))
    # culasse et bloc rotatif
    lot.put(M["canon"], hexseg(E, G.lerp(E, Mz, 0.38), 1.25, 1.35, 8))
    rc = 1.0 if stage < 3 else 1.2
    nb = 6 if stage < 3 else 8
    fr = G._frames([E, Mz])[0]
    for k in range(nb):
        a = G.TAU * k / nb
        off = G.add(G.mul(fr[1], rc * 0.62 * math.cos(a)), G.mul(fr[2], rc * 0.62 * math.sin(a)))
        lot.put(M["canon"], G.tube([G.add(G.lerp(E, Mz, 0.36), off), G.add(Mz, off)], 0.3, 8))
    lot.put(M["struct"], G.tube([G.lerp(E, Mz, 0.36), G.add(Mz, G.mul(d, -0.3))], 0.42, 8))
    # anneaux de focalisation flottants autour du fût (axe = direction du canon) ; à la charge ils glissent vers la bouche
    n_an = 2 if stage == 1 else 3
    for k in range(n_an):
        t = 0.62 + 0.17 * k + 0.14 * charge
        c = G.lerp(E, Mz, t)
        ra = rc + 0.9 + 0.35 * k
        ring = anneau((0.0, 0.0, 0.0), "z", ra, 0.45, 0.16)
        lot.put(M["anneau"], G.oriente(ring, c, d))
        lot.put(M["turq"], G.oriente(rainure((0.0, 0.0, 0.0), "z", ra + 0.22, 0.07), c, d))
        for q in range(4):
            a = G.TAU * (q + 0.5) / 4
            lot.put(M["struct"], G.oriente(G.boite((ra + 0.5, 0.0, 0.0), (0.5, 0.35, 0.3), rz=a), c, d))
    # bouche : vortex de focalisation (cœur), couronne de cristal ; la charge gonfle le vortex, l'éclair file devant
    rv = 0.82 + 0.6 * charge
    lot.put(M["coeur"], G.oriente(G.tour([(0.0, 0.0), (0.05, rv)], 16, "z", cap1=True), G.add(Mz, G.mul(d, 0.15)), d))
    lot.put(M["halo"], G.sphere(G.add(Mz, G.mul(d, 0.4)), 1.5 + 1.0 * charge, 14, 7))
    if eclair > 0:
        lot.put(M["coeur"], G.oriente(G.tour([(0.0, 0.0), (0.1, 0.9), (3.2 * eclair, 0.5), (4.6 * eclair, 0.0)], 12, "z", cap0=True), G.add(Mz, G.mul(d, 0.3)), d))
        lot.put(M["halo"], G.sphere(G.add(Mz, G.mul(d, 2.0 * eclair)), 1.2 + 0.8 * eclair, 12, 6))
    for q in range(6):
        a = G.TAU * q / 6
        off = G.add(G.mul(fr[1], 1.15 * math.cos(a)), G.mul(fr[2], 1.15 * math.sin(a)))
        lot.put(M["cristal"], pointe(G.add(Mz, off), G.norm(G.add(d, G.mul(off, 0.25))), 1.1, 0.22))
    # munitions / échangeur sur le dessus du canon
    lot.put(M["blind2"], R.pose(G.prisme([(-1.2, -0.7), (1.6, -0.7), (1.9, 0.0), (1.6, 0.7), (-1.2, 0.7)], 0.0, 0.7, 0.8), G.add(G.lerp(E, Mz, 0.3), (0.0, 0.0, 1.3)), (0, 0, 1), (1, 0, 0)))


def bras_griffes(lot, M, stage, r, swing=0.0):
    """Bras gauche : bras, avant-bras blindé, main à 3 lames de cristal (griffes d'énergie) et conduit jusqu'au poignet. swing : voir bras_canon."""
    s = 1
    S_ = (0.6, s * 6.4, 25.4)
    E = G.rot_y((1.0, s * 7.6, 20.9), swing, S_)
    W = G.rot_y((3.6, s * 7.4, 17.2), swing, S_)
    lot.put(M["struct"], G.sphere(S_, 1.25, 10, 5))
    lot.put(M["blind"], hexseg(S_, E, 1.35, 1.05, 6, 0.2))
    lot.put(M["struct"], G.sphere(E, 1.0, 10, 5))
    lot.put(M["blind2"], hexseg(E, W, 1.1, 0.95, 6, 0.1))
    lot.put(M["conduit"], hexseg(G.add(E, (0.7, s * 0.7, 0.2)), G.add(W, (0.5, s * 0.7, 0.6)), 0.12, 0.12))
    lot.put(M["struct"], G.sphere(W, 0.85, 10, 5))
    # garde de la main et lames
    lot.put(M["blind"], plaque(G.add(W, (0.5, s * 0.5, 0.2)), G.norm((0.4, s * 1.0, 0.2)), 1.8, 1.6, 0.3, up=(0, 0, 1)))
    d0 = G.norm(G.rot_y((0.75, 0.0, -0.75), swing))
    n_l = 3 if stage < 3 else 4
    for k in range(n_l):
        q = (k - (n_l - 1) / 2.0) * 0.5
        dd = G.norm(G.add(d0, (0.0, q * 0.5, 0.0)))
        lot.put(M["struct"], hexseg(G.add(W, (0.2, q, -0.2)), G.add(W, G.add(G.mul(dd, 1.2), (0.0, q, 0.0))), 0.26, 0.2, 6))
        lot.put(M["cristal"], pointe(G.add(W, G.add(G.mul(dd, 1.1), (0.0, q, 0.0))), dd, 4.2 - 0.4 * abs(q) * 2, 0.34))


def build(S, lot, stage=1, u=None, attaque=None, dirs=False):
    """Construit le Juggernaut au stade `stage` (1 à 3) : repos (u et attaque None), marche (u) ou salve (attaque). Rend des comptes pour render.json."""
    M = TM.matieres(S, "ju_", GRIS)
    xf = XF0 if dirs else XF
    r = G.Rnd(2000 + stage)
    R.raz()
    if attaque is not None:
        i = int(round(attaque * SERIE["attaque"])) % SERIE["attaque"]
        charge, recul, eclair = ATTAQUE[i]
        swing_c, swing_g = -0.27, -0.45                      # le canon se lève à l'horizontale, les griffes se tendent
        phases, bob = (0.15, 0.45), 0.0                       # jambes campées, les deux pieds au sol (appui)
    elif u is not None:
        charge, recul, eclair = 0.0, 0.0, 0.0
        swing_c, swing_g = 0.14 * math.sin(G.TAU * u), -0.14 * math.sin(G.TAU * u)
        phases, bob = (u, u + 0.5), 0.3 * abs(math.sin(G.TAU * u))
    else:
        charge, recul, eclair = 0.0, 0.0, 0.0
        swing_c, swing_g, phases, bob = 0.0, 0.0, (None, None), 0.0
    lot.xf = (lambda v: xf((v[0], v[1], v[2] + bob))) if bob else xf
    torse(lot, M, stage, r)
    bras_canon(lot, M, stage, r, swing_c, charge, recul, eclair)
    bras_griffes(lot, M, stage, r, swing_g)
    lot.xf = xf
    for s, ph in ((1, phases[0]), (-1, phases[1])):
        jambe(lot, M, s, stage, r, ph, bob)
    return {"stage": stage, "pieces": lot.n, "u": u, "attaque": attaque}


def build_anime(S, lot, stage, u, attaque):
    """Entrée commune des titans animés (batch_titans.anime) : stade, phase de course ou d'attaque, sans lacet (8 directions)."""
    return build(S, lot, stage, u=u if attaque is None else None, attaque=attaque, dirs=True)
