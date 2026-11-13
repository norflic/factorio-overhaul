"""RAVAGEUR, méga-robot d'ASSAUT allié (lot KAIJUS-MUTANTS, 10/11 ; concept du DC : mécha bipède à gatling et lames, Gemini_Generated_Image_h9w0ls…) :
Jaeger élancé à tête-orbe flottante sous un halo de segments, deux grandes AILES-LAMES gravées dans le dos, bras gauche terminé par un
canon GATLING à six tubes sous anneaux de focalisation, bras droit à trois longues LAMES de cristal, jambes digitigrades à tuyères,
conduits cyan en circuits sur tout le blindage argent iridescent. Environ 26 tuiles de haut (le Juggernaut en fait 36 : plus ramassé,
plus vif). Âges 13 à 15 (shared/robots/titans.lua T.RAVAGEUR) ; stades 1 à 3 : ailes plus grandes, lames et cristaux s'ajoutent.

Modèle paramétrique low-poly ANIMÉ comme le Juggernaut (juggernaut.py) : `build_anime(S, lot, stage, u, attaque)` : marche (u) ou RAFALE
(attaque : le gatling se lève, les anneaux glissent, éclairs de bouche et recul, les lames se tendent). Repère LOCAL : +x = face,
+y = gauche, +z = haut ; le rendu tourne le modèle sur 8 directions (batch_titans.anime).
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
from juggernaut import hexseg, pointe, plaque, anneau, rainure, pas, ik2, traces, bague  # noqa: E402
from leviathan import lunette_vortex  # noqa: E402  (S43 V3 : cœur à vortex du buste)
import titans_v3 as V3  # noqa: E402

PREFIX = "ra_"
GRIS = os.environ.get("FO_GRIS", "") == "1"
KE = 0.86                    # 30 unités de modèle -> 26 tuiles
# ART-16DIR (11/11) : 16 directions réelles ; densité 17 pour tenir 80 Mpx HR (lueur à demi-densité, ombre au quart)
SERIE = {"course": 8, "attaque": 4, "densite": 17.0, "R": 13.5, "zmax": 28.0, "sol": 400.0, "dirs": 16}
AO = 0.6
GLOW_BLANC = False
AMP = 2.6
LEVEE = 1.4
FOULEE = 2 * 2.6 * 0.86      # tuiles par cycle = 2 × AMP × KE
ATTAQUE = ((0.5, 0.0, 0.3), (1.0, 0.5, 1.0), (0.8, 0.3, 0.6), (0.6, 0.15, 0.9))   # par image : charge, recul, éclair (rafale continue)


def XF0(v):
    return (v[0] * KE, v[1] * KE, max(0.0, v[2] * KE))


def jambe(lot, M, s, stage, u, bob):
    """Jambe digitigrade élancée : hanche, cuisse blindée, tibia à structure apparente, métatarse, 3 griffes ; tuyères au mollet."""
    y = s * 3.6
    H = (0.0, y, 15.4 + bob)
    K0 = (3.2, y + s * 0.2, 10.2)
    A0 = (-1.2, y + s * 0.4, 5.0)
    T0 = (2.2, y + s * 0.6, 0.8)
    dx, dz = pas(u, AMP, LEVEE)
    T = (T0[0] + dx, T0[1], T0[2] + dz)
    A = G.add(T, G.sub(A0, T0))
    l1, l2 = G.length(G.sub(K0, (0.0, y, 15.4))), G.length(G.sub(A0, K0))
    K = ik2(H, A, l1, l2, (1.0, 0.0, 0.3))
    for p, rr in ((H, 1.3), (K, 1.05), (A, 0.85)):
        lot.put(M["struct"], G.sphere(p, rr, 10, 5))
    lot.put(M["accent"], G.boite(G.add(H, (0.7, s * 1.1, 0.2)), (0.35, 0.18, 0.18)))
    # S43 V3 : cuisse MASSIVE (plus de jambe squelettique), grande plaque frontale, genouillère, tibia blindé ; un seul conduit par membre
    lot.put(M["blind"], hexseg(H, K, 2.4, 1.65, 6, 0.3))
    d = G.norm(G.sub(K, H))
    lot.put(M["blind2"], plaque(G.add(G.lerp(H, K, 0.5), (1.0, s * 0.8, 0.3)), G.norm((1.0, s * 0.6, 0.45)), 2.6, 4.0, 0.4, up=d))
    lot.put(M["conduit"], hexseg(G.add(H, (0.5, s * 1.9, -0.5)), G.add(K, (0.4, s * 1.4, 0.3)), 0.13, 0.12, 6))
    lot.put(M["struct"], hexseg(K, A, 1.1, 0.85, 8))
    lot.put(M["blind"], hexseg(G.lerp(K, A, 0.1), G.lerp(K, A, 0.85), 1.5, 1.15, 6, 0.2))
    lot.put(M["blind2"], plaque(G.lerp(K, A, 0.45), G.norm((-0.8, s * 0.7, 0.3)), 1.8, 3.2, 0.32, up=G.norm(G.sub(A, K))))
    lot.put(M["blind2"], plaque(G.add(K, (0.9, 0.0, 0.2)), G.norm((1.0, 0.0, 0.25)), 2.2, 2.0, 0.45, up=(0, 0, 1)))
    lot.put(M["canon"], G.tube([G.add(H, (-1.0, 0.0, -0.3)), G.add(A, (-0.5, 0.0, 0.4))], 0.26, 8))
    for q in (-0.45, 0.45):
        base = G.add(A, (-0.7, q + s * 0.3, 1.1))
        lot.put(M["canon"], G.oriente(G.tour([(0.0, 0.3), (0.7, 0.42), (1.1, 0.36), (1.15, 0.25)], 10, "z", cap0=True), base, (-0.8, 0.0, -0.45)))
        lot.put(M["turq"], G.oriente(G.tour([(1.0, 0.24), (1.05, 0.0)], 10, "z"), base, (-0.8, 0.0, -0.45)))
    lot.put(M["blind"], hexseg(A, T, 1.0, 0.8, 6, 0.2))
    # TITANS2 (11/11) : griffes CINÉTIQUES (concept : serres articulées) : phalange blindée biseautée, rotule, gorge cyan, serre recourbée
    for k, (ax, ay) in enumerate(((1.0, 0.0), (0.7, 0.8), (0.7, -0.8))):
        base = G.add(T, (0.25 * ax, ay * 0.5, 0.15))
        d1 = G.norm((ax, ay * 0.7, 0.18))
        j1 = G.add(base, G.mul(d1, 0.9 if k == 0 else 0.72))
        lot.put(M["struct"], hexseg(base, j1, 0.34, 0.27, 6))
        lot.put(M["blind2"], hexseg(G.add(base, (0.0, 0.0, 0.14)), G.add(j1, (0.0, 0.0, 0.14)), 0.29, 0.22, 4, 0.785))
        lot.put(M["struct"], G.sphere(j1, 0.26, 8, 4))
        lot.put(M["turq"], G.oriente(rainure((0.0, 0.0, 0.0), "z", 0.28, 0.06), G.lerp(base, j1, 0.5), d1))
        lot.put(M["os"], pointe(j1, G.norm((ax, ay * 0.7, -0.7)), 1.75 if k == 0 else 1.4, 0.29, 5))
    # S43 V3 : sabot blindé large (contact au sol lisible), anneau de lévitation magnétique à la cheville
    lot.put(M["blind"], G.boite(G.add(T, (0.3, 0.0, 0.45)), (2.2, 1.6, 0.7)))
    lot.put(M["anneau"], anneau(G.add(T, (0.3, 0.0, 0.35)), "z", 1.55, 0.32, 0.1))
    bague(lot, M, K, (0.0, 1.0, 0.0), 1.45)
    lot.put(M["os"], pointe(G.add(A, (-0.4, 0.0, -1.0)), (-0.9, 0.0, -0.45), 1.5, 0.3, 5))
    if stage >= 2:
        lot.put(M["blind2"], plaque(G.add(H, (0.8, s * 0.9, 1.3)), G.norm((0.7, s * 0.9, 0.5)), 2.2, 1.8, 0.28, up=(0, 0, 1)))
    if stage >= 3:
        lot.put(M["cristal"], pointe(G.add(K, (0.8, s * 0.7, 0.8)), G.norm((0.7, s * 0.5, 0.9)), 1.4, 0.26))


def torse(lot, M, stage, lean):
    """Bassin, torse élancé à épaules larges, visière-poitrine à conduits en V, tête-orbe flottante sous un halo de segments,
    ailes-lames dorsales gravées, cœur dorsal."""
    lot.put(M["blind2"], G.prisme(R.octo((0.0, 0.0), 2.9, 8), 14.6, 16.6, top_scale=1.1))
    lot.put(M["struct"], G.prisme(R.octo((0.0, 0.0), 2.1, 8), 16.4, 17.0, top_scale=0.95))
    def sect(z, w, d, x=0.0):
        return [(x + w, -d, z), (x + w * 0.55, -d * 1.15, z), (x - w * 0.6, -d * 1.1, z), (x - w, -d * 0.7, z), (x - w, d * 0.7, z), (x - w * 0.6, d * 1.1, z),
                (x + w * 0.55, d * 1.15, z), (x + w, d, z)]
    # S43 V3 : buste MASSIF en coin (1,3 fois plus large et profond) : la silhouette se lit au zoom normal
    rings = [sect(16.6, 1.7, 2.5), sect(18.6, 2.5, 3.4, 0.2 * lean), sect(21.4, 3.0, 5.0, 0.5 * lean), sect(23.8, 2.8, 6.0, 0.7 * lean), sect(25.0, 1.9, 4.4, 0.8 * lean)]
    lot.put(M["blind"], G.loft(rings, True, True))
    # poitrine : deux grandes plaques en chevron autour d'un GROS CŒUR À VORTEX (le seul point de lumière du buste), plaque ventrale
    for s in (-1, 1):
        lot.put(M["blind2"], plaque((3.2 + 0.6 * lean, s * 2.3, 22.4), G.norm((1.0, s * 0.45, 0.3)), 2.8, 3.4, 0.4, up=(0, 0, 1)))
    lunette_vortex(lot, M, (3.5 + 0.6 * lean, 0.0, 21.4), (1.0, 0.0, 0.35), 2.0, pales=6)
    lot.put(M["blind2"], plaque((3.0 + 0.3 * lean, 0.0, 18.4), (1.0, 0.0, 0.2), 3.8, 2.0, 0.4))
    # anneau de LÉVITATION magnétique horizontal autour des hanches : cadre blindé, tore lumineux, quatre émetteurs
    zr = 16.0
    lot.put(M["blind2"], anneau((0.0, 0.0, zr), "z", 4.3, 0.55, 0.22))
    lot.put(M["anneau"], anneau((0.0, 0.0, zr - 0.1), "z", 4.0, 0.35, 0.14))
    for k in range(4):
        a = G.TAU * (k + 0.5) / 4
        lot.put(M["struct"], G.tube([(2.0 * math.cos(a), 2.0 * math.sin(a), zr + 0.3), (4.3 * math.cos(a), 4.3 * math.sin(a), zr)], 0.2, 6))
        lot.put(M["coeur"], G.sphere((4.9 * math.cos(a), 4.9 * math.sin(a), zr), 0.3, 8, 4))
    # épaulières (stage 2 : étagées, stage 3 : cristaux)
    for s in (-1, 1):
        c = (0.3 + 0.7 * lean, s * 6.9, 24.4)
        lot.put(M["blind"], R.pose(G.prisme([(-2.2, -1.9), (2.4, -1.9), (2.9, 0.0), (2.4, 1.9), (-2.2, 1.9), (-2.7, 0.4)], 0.0, 1.5, 0.75), c, G.norm((0.0, s * 0.35, 1.0)), (1, 0, 0)))
        lot.put(M["conduit"], hexseg(G.add(c, (-1.0, s * 0.4, 1.2)), G.add(c, (1.4, s * 0.4, 1.2)), 0.1, 0.1))
        if stage >= 2:
            lot.put(M["blind2"], R.pose(G.prisme([(-1.2, -1.1), (1.4, -1.1), (1.7, 0.0), (1.4, 1.1), (-1.2, 1.1)], 0.0, 0.9, 0.8), G.add(c, (0.2, s * 0.8, 1.1)), G.norm((0.1, s * 0.5, 1.0)), (1, 0, 0)))
        if stage >= 3:
            for k in range(2):
                lot.put(M["cristal"], pointe(G.add(c, (-0.5 + 1.0 * k, s * 1.2, 2.2)), G.norm((-0.3 + 0.2 * k, s * 0.5, 1.0)), 2.2 - 0.4 * k, 0.34))
    # tête : orbe lumineux dans une coque ouverte, halo de 4 segments flottants au-dessus
    C = (1.2 + 0.8 * lean, 0.0, 26.6)
    lot.put(M["coeur"], G.sphere(C, 0.75, 14, 7))
    lot.put(M["halo"], G.sphere(C, 1.3, 14, 7))
    lot.put(M["blind2"], G.loft([[(C[0] - 1.0, -0.9, C[2] - 0.9), (C[0] + 0.4, -1.0, C[2] - 0.9), (C[0] + 0.4, 1.0, C[2] - 0.9), (C[0] - 1.0, 0.9, C[2] - 0.9)],
                                [(C[0] - 1.2, -1.1, C[2] + 0.1), (C[0] - 0.2, -1.2, C[2] + 0.1), (C[0] - 0.2, 1.2, C[2] + 0.1), (C[0] - 1.2, 1.1, C[2] + 0.1)]], True, False))
    # halo : anneau fin flottant au-dessus de l'orbe et quatre segments de blindage qui l'entourent (le concept)
    lot.put(M["anneau"], anneau((C[0], C[1], C[2] + 1.5), "z", 1.7, 0.32, 0.1))
    lot.put(M["turq"], rainure((C[0], C[1], C[2] + 1.62), "z", 2.1, 0.05))
    for k in range(4):
        a = G.TAU * (k + 0.5) / 4
        lot.put(M["blind2"], G.boite((C[0] + 2.4 * math.cos(a), C[1] + 2.4 * math.sin(a), C[2] + 0.9), (0.55, 0.3, 0.7), rz=a))
    # cœur dorsal et son anneau
    D = (-2.6, 0.0, 21.6)
    lot.put(M["coeur"], G.sphere(D, 1.0, 14, 7))
    lot.put(M["halo"], G.sphere(D, 1.7, 14, 7))
    lot.put(M["anneau"], anneau((D[0] - 0.7, 0.0, D[2]), "x", 2.3, 0.45, 0.18))
    lot.put(M["turq"], rainure((D[0] - 0.9, 0.0, D[2]), "x", 2.5, 0.07))
    # ailes-lames dorsales : deux grandes lames plates inclinées vers l'arrière et l'extérieur, gravées de cercles lumineux
    hl = 7.0 + 1.6 * (stage - 1)
    for s in (-1, 1):
        base = (-1.8, s * 3.4, 23.0)
        n = G.norm((-0.55, s * 0.25, 0.0))
        up = G.norm((-0.35, s * 0.45, 1.0))
        poly = [(-1.4, 0.0), (1.4, 0.0), (1.1, hl * 0.55), (0.3, hl), (-0.6, hl * 0.8), (-1.3, hl * 0.3)]
        lot.put(M["blind"], R.pose(G.prisme(poly, -0.16, 0.16, top_scale=0.96), base, n, up))
        for k in range(2):
            c = G.add(base, G.add(G.mul(up, hl * (0.35 + 0.3 * k)), G.mul(n, 0.2)))
            lot.put(M["turq"], G.oriente(rainure((0.0, 0.0, 0.0), "z", 0.7 - 0.2 * k, 0.05), c, n))
            lot.put(M["anneau"], G.oriente(G.tour([(-0.05, 0.3), (0.05, 0.3), (0.05, 0.42), (-0.05, 0.42), (-0.05, 0.3)], 12, "z"), c, n))
        lot.put(M["conduit"], G.tube([G.add(base, G.mul(up, 0.5)), G.add(base, G.mul(up, hl * 0.9))], 0.08, 6))
        if stage >= 3:
            lot.put(M["cristal"], pointe(G.add(base, G.mul(up, hl)), up, 2.4, 0.3))
            lot.put(M["cristal"], pointe(G.add(base, G.add(G.mul(up, hl * 0.6), (0.0, s * 1.2, 0.0))), G.norm(G.add(up, (0.0, s * 0.6, 0.0))), 1.6, 0.24))
    # tuyères dorsales
    for s in (-1, 1):
        lot.put(M["canon"], G.tour([(23.2, 0.45), (25.4, 0.42), (25.9, 0.5), (26.0, 0.38)], 10, "z", (-1.2, s * 1.4, 0.0), cap0=True))
        lot.put(M["turq"], G.tour([(25.8, 0.34), (25.85, 0.0)], 10, "z", (-1.2, s * 1.4, 0.0)))


def bras_gatling(lot, M, stage, swing, charge, recul, eclair):
    """Bras gauche : épaule, bras, canon GATLING à six tubes sous trois anneaux de focalisation, éclair de bouche à la rafale."""
    s = 1
    S_ = (0.5, s * 6.6, 23.2)
    E0 = (1.2, s * 8.0, 19.0)
    M0 = (6.8, s * 8.2, 17.0)
    E = G.rot_y(E0, swing, S_)
    Mz = G.rot_y(M0, swing, S_)
    d = G.norm(G.sub(Mz, E))
    if recul > 0:
        E, Mz = G.add(E, G.mul(d, -0.5 * recul)), G.add(Mz, G.mul(d, -0.5 * recul))
    lot.put(M["struct"], G.sphere(S_, 1.05, 10, 5))
    lot.put(M["accent"], G.boite(G.add(S_, (0.7, s * 0.7, -0.2)), (0.3, 0.18, 0.18)))
    lot.put(M["blind"], hexseg(S_, E, 1.55, 1.2, 6, 0.2))
    lot.put(M["struct"], G.sphere(E, 0.9, 10, 5))
    lot.put(M["canon"], hexseg(E, G.lerp(E, Mz, 0.3), 1.0, 1.15, 8))
    fr = G._frames([E, Mz])[0]
    for k in range(6):
        a = G.TAU * k / 6 + 0.6 * charge
        off = G.add(G.mul(fr[1], 0.62 * math.cos(a)), G.mul(fr[2], 0.62 * math.sin(a)))
        lot.put(M["canon"], G.tube([G.add(G.lerp(E, Mz, 0.28), off), G.add(Mz, off)], 0.22, 8))
    lot.put(M["struct"], G.tube([G.lerp(E, Mz, 0.28), G.add(Mz, G.mul(d, -0.2))], 0.32, 8))
    for k in range(3):
        t = 0.45 + 0.16 * k + 0.12 * charge
        c = G.lerp(E, Mz, t)
        ra = 1.5 + 0.25 * k
        lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", ra, 0.38, 0.14), c, d))
        lot.put(M["turq"], G.oriente(rainure((0.0, 0.0, 0.0), "z", ra + 0.2, 0.06), c, d))
    lot.put(M["halo"], G.sphere(G.add(Mz, G.mul(d, 0.3)), 0.9 + 0.6 * charge, 12, 6))
    # TITANS2 : couronnes de focalisation FLOTTANTES détachées devant la bouche (1, 2, 3 selon le stade ; créneaux, gorge cyan, arc d'énergie)
    prev = G.add(Mz, G.mul(d, 0.4))
    for k in range(stage):
        c = G.add(Mz, G.mul(d, 1.0 + 0.75 * k + (0.2 + 0.15 * k) * charge))
        ra = 1.4 - 0.28 * k
        lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", ra, 0.26, 0.15), c, d))
        lot.put(M["turq"], G.oriente(rainure((0.0, 0.0, 0.0), "z", ra - 0.03, 0.1), c, d))
        for q in range(8):
            a = G.TAU * q / 8
            lot.put(M["blind2"], G.oriente(G.boite((ra + 0.3, 0.0, 0.0), (0.2, 0.17, 0.2), rz=a), c, d))
        sg = 1 if k % 2 else -1
        lot.put(M["conduit"], G.tube([prev, G.add(G.lerp(prev, c, 0.5), G.mul(fr[1], 0.25 * sg)), c], 0.05, 4))
        prev = c
    bague(lot, M, E, G.norm(G.sub(E, S_)), 1.25)
    if eclair > 0:
        lot.put(M["coeur"], G.oriente(G.tour([(0.0, 0.0), (0.1, 0.7), (2.2 * eclair, 0.35), (3.2 * eclair, 0.0)], 10, "z", cap0=True), G.add(Mz, G.mul(d, 0.2)), d))
    lot.put(M["blind2"], R.pose(G.prisme([(-1.0, -0.6), (1.3, -0.6), (1.6, 0.0), (1.3, 0.6), (-1.0, 0.6)], 0.0, 0.6, 0.8), G.add(G.lerp(E, Mz, 0.25), (0.0, 0.0, 1.1)), (0, 0, 1), (1, 0, 0)))


def bras_lames(lot, M, stage, swing, tendu):
    """Bras droit : bras, avant-bras blindé, main-garde et TROIS longues lames de cristal (quatre au stade 3) ; `tendu` : elles se déploient."""
    s = -1
    S_ = (0.5, s * 6.6, 23.2)
    E = G.rot_y((1.0, s * 7.8, 19.1), swing, S_)
    W = G.rot_y((3.2, s * 7.6, 15.6), swing, S_)
    lot.put(M["struct"], G.sphere(S_, 1.05, 10, 5))
    lot.put(M["blind"], hexseg(S_, E, 1.55, 1.2, 6, 0.2))
    lot.put(M["struct"], G.sphere(E, 1.0, 10, 5))
    lot.put(M["blind2"], hexseg(E, W, 1.35, 1.1, 6, 0.1))
    lot.put(M["conduit"], hexseg(G.add(E, (0.9, s * 0.7, 0.2)), G.add(W, (0.7, s * 0.7, 0.5)), 0.12, 0.12))
    lot.put(M["struct"], G.sphere(W, 0.72, 10, 5))
    bague(lot, M, E, G.norm(G.sub(W, E)), 1.4)
    lot.put(M["blind"], plaque(G.add(W, (0.4, s * 0.4, 0.2)), G.norm((0.4, s * 1.0, 0.2)), 1.5, 1.4, 0.26, up=(0, 0, 1)))
    d0 = G.norm(G.rot_y((0.75 + 0.3 * tendu, 0.0, -0.75 + 0.3 * tendu), swing))
    n_l = 3 if stage < 3 else 4
    for k in range(n_l):
        q = (k - (n_l - 1) / 2.0) * 0.45
        dd = G.norm(G.add(d0, (0.0, q * 0.5, 0.0)))
        lot.put(M["struct"], hexseg(G.add(W, (0.2, q, -0.2)), G.add(W, G.add(G.mul(dd, 1.0), (0.0, q, 0.0))), 0.22, 0.17, 6))
        lot.put(M["cristal"], pointe(G.add(W, G.add(G.mul(dd, 0.9), (0.0, q, 0.0))), dd, 5.4 - 0.5 * abs(q) * 2, 0.3))
    lot.put(M["turq"], G.tube([G.add(W, (0.3, s * 0.3, 0.3)), G.add(W, G.mul(d0, 1.6))], 0.06, 6))


def build(S, lot, stage=1, u=None, attaque=None):
    """Construit le Ravageur au stade `stage` (1 à 3) : marche (u) ou rafale (attaque), repère local (8 directions)."""
    M = V3.matieres(S, PREFIX, GRIS)
    R.raz()
    if attaque is not None:
        i = int(round(attaque * SERIE["attaque"])) % SERIE["attaque"]
        charge, recul, eclair = ATTAQUE[i]
        swing_g, swing_l, tendu = -0.3, -0.5, 1.0
        phases, bob, lean = (0.15, 0.45), 0.0, 0.5
    elif u is not None:
        charge, recul, eclair = 0.0, 0.0, 0.0
        swing_g, swing_l, tendu = 0.16 * math.sin(G.TAU * u), -0.16 * math.sin(G.TAU * u), 0.0
        phases, bob, lean = (u, u + 0.5), 0.3 * abs(math.sin(G.TAU * u)), 0.25
    else:
        charge, recul, eclair = 0.0, 0.0, 0.0
        swing_g, swing_l, tendu, phases, bob, lean = 0.0, 0.0, 0.0, (0.0, 0.5), 0.0, 0.2
    lot.xf = (lambda v: XF0((v[0], v[1], v[2] + bob))) if bob else XF0
    torse(lot, M, stage, lean)
    bras_gatling(lot, M, stage, swing_g, charge, recul, eclair)
    bras_lames(lot, M, stage, swing_l, tendu)
    lot.xf = XF0
    for s, ph in ((1, phases[0]), (-1, phases[1])):
        jambe(lot, M, s, stage, ph, bob)
    return {"stage": stage, "pieces": lot.n, "u": u, "attaque": attaque}


def build_anime(S, lot, stage, u, attaque):
    """Entrée commune des titans animés (batch_titans.anime) : stade, phase de course ou de rafale."""
    return build(S, lot, stage, u=u if attaque is None else None, attaque=attaque)
