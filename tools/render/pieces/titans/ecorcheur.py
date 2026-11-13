"""ÉCORCHEUR, second titan ENNEMI (lot KAIJUS-MUTANTS, 10/11 ; concept du DC : bipède charnel à bras-canon, Gemini_Generated_Image_ik0n6r…) :
théropode cyber-organique dressé, chair mauve écorchée à conduits turquoise, crâne à crête de plaques et quatre yeux, mâchoire béante au
cœur lumineux (vortex), bras droit terminé par un CANON organique, bras gauche à longues griffes d'os et tentacules, épines de cristal bleu
glacier le long du dos, longue queue à anneaux flottants, pieds-racines (tentacules). Un SAC VENTRAL lumineux : la PONTE (les Écorchés,
mordeurs mutants, en sortent : shared/robots/titans.lua T.ECORCHEUR.ponte).

Modèle paramétrique low-poly (kit des géants, geo.py) ANIMÉ comme le Kaiju (kaiju.py) : `build(S, lot, u, attaque=None)` : pose de course
u dans [0, 1[ (bipède : pieds en opposition de phase, balancement des bras et de la queue), ou d'attaque (le canon se lève, charge, éclair de
bouche et recul ; la gueule s'ouvre, le sac ventral gonfle). Le rendu tourne le modèle sur 8 directions (batch_titans.anime). Repère LOCAL :
+x = avant, +y = gauche, +z = haut ; origine = sous le bassin, au sol. Environ 18 tuiles du museau au bout de la queue, 11 tuiles de haut.

Refonte s43 (13/11, pilier D) : l'Écorcheur se DÉTACHE de la famille des Écorchés (mauves à collerette) et du Kaiju (cristaux bleus) :
muscle ÉCORCHÉ rouge sang luisant, carapace d'OS ivoire (plaques, CAGE THORACIQUE ouverte sur le sac de ponte), épines d'os au lieu des
cristaux, griffes noires ; plus d'anneaux flottants (queue, canon) : des vertèbres et des bagues d'os. Silhouette voûtée, plus massive.
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
from juggernaut import hexseg, pointe, plaque, anneau, rainure  # noqa: E402
from kaiju import pas, ik2, ellipse  # noqa: E402

PREFIX = "ec_"
GRIS = os.environ.get("FO_GRIS", "") == "1"
# Série (batch_titans, feuilles_titans) : images par animation, densité (px par tuile), rayon au sol et hauteur englobants, sol du rendu.
SERIE = {"course": 8, "attaque": 4, "densite": 24.0, "R": 11.5, "zmax": 12.0, "sol": 120.0}
AO = 0.6
GLOW_BLANC = True         # la lueur est rendue BLANCHE : le prototype la teinte par ère
AMP = 2.2                 # amplitude du pas (unités) : le pied va de +AMP à -AMP au sol
FOULEE = 2 * 2.2          # tuiles par cycle = 2 × AMP (distance_per_frame du prototype = FOULEE / images)
ATTAQUE = ((0.0, 0.0, 0.0), (0.6, 0.0, 0.3), (1.0, 0.5, 1.0), (0.4, 0.2, 0.3))   # par image : charge, recul, éclair


def spine(u, bob, lunge):
    """Colonne du bassin à la tête (x croissant) : dressée, penchée en avant ; `lunge` : la tête plonge (attaque)."""
    z = bob
    sw = 0.12 * math.sin(G.TAU * u)
    return [(-0.6, 0.0, 5.3 + z), (0.6, sw * 0.3, 6.4 + z), (2.0, sw * 0.5, 7.2 + z), (3.4, sw * 0.6, 7.6 + z),
            (4.8, sw * 0.4, 7.9 + z - 0.6 * lunge), (6.0, 0.0, 8.0 + z - 1.3 * lunge)]


def matieres(S):
    """Jeu commun des titans + palette PROPRE de l'Écorcheur (s43) : chair = muscle rouge sang luisant, peau = tendons sombres,
    blind/blind2 = os ivoire (carapace), cristal = épines d'os (pas d'émission), os = griffes et dents noires, anneau = bague d'os."""
    M = TM.matieres(S, PREFIX, GRIS)
    if GRIS:
        return M
    import mat as MT
    M["chair"] = MT.surface(PREFIX + "muscle", (0.26, 0.022, 0.030), rough=0.34, met=0.08, tole=(0.25, 0.9), joint=0.35, joint_l=0.03,
                            var=0.25, usure=0.2, nu=(0.55, 0.10, 0.10), crasse=0.45, crasse_col=(0.05, 0.005, 0.008), relief=0.9, graine=41)
    M["peau"] = MT.surface(PREFIX + "tendon", (0.09, 0.018, 0.024), rough=0.45, met=0.05, tole=(0.3, 0.6), joint=0.3, joint_l=0.03,
                           var=0.2, usure=0.2, nu=(0.35, 0.08, 0.08), crasse=0.5, crasse_col=(0.02, 0.003, 0.004), relief=0.8, graine=42)
    M["blind"] = MT.surface(PREFIX + "os_ivoire", (0.60, 0.53, 0.40), rough=0.5, met=0.0, tole=(0.7, 0.5), joint=0.2, joint_l=0.02, var=0.15,
                            usure=0.3, nu=(0.80, 0.75, 0.62), crasse=0.6, crasse_col=(0.12, 0.05, 0.03), relief=0.9, graine=43)
    M["blind2"] = MT.surface(PREFIX + "os_jauni", (0.44, 0.36, 0.24), rough=0.55, met=0.0, tole=(0.5, 0.4), joint=0.2, joint_l=0.02, var=0.15,
                             usure=0.3, nu=(0.70, 0.62, 0.48), crasse=0.65, crasse_col=(0.10, 0.03, 0.02), relief=0.9, graine=44)
    M["cristal"] = M["blind"]
    M["anneau"] = M["blind2"]
    M["os"] = MT.surface(PREFIX + "griffe", (0.035, 0.028, 0.026), rough=0.28, met=0.2, usure=0.3, nu=(0.30, 0.26, 0.22), crasse=0.3,
                         crasse_col=(0.01, 0.01, 0.01), graine=45)
    return M


def queue(u, bob):
    """Queue du bassin vers l'arrière, qui ondule et retombe presque au sol ; le bout remonte (anneaux)."""
    sw = 0.45 * math.sin(G.TAU * u + 1.0)
    return [(-0.4, 0.0, 5.0 + bob), (-2.4, -sw * 0.6, 4.6 + bob * 0.6), (-4.6, -sw * 1.4, 3.6), (-6.8, -sw * 2.2, 2.4),
            (-8.8, -sw * 2.6, 1.9), (-10.6, -sw * 2.4, 2.6), (-11.8, -sw * 1.8, 3.6)]


def tronc(lot, M, u, bob, lunge, sac):
    """Tronc : loft de la colonne (chair écorchée), plaques pectorales sombres, épines de cristal dorsales, conduits, sac ventral (ponte)."""
    ctrl = spine(u, bob, lunge)
    pts = G.catmull(ctrl, 5)
    n = len(pts)
    rings, prof = [], []
    for i, p in enumerate(pts):
        t = i / float(n - 1)
        if t < 0.3:
            w, h = 1.6 + 0.9 * (t / 0.3), 1.4 + 0.8 * (t / 0.3)          # bassin -> ventre large
        elif t < 0.7:
            k = (t - 0.3) / 0.4
            w, h = 2.5 - 0.3 * k, 2.2 + 0.2 * math.sin(math.pi * k)       # poitrail
        else:
            k = (t - 0.7) / 0.3
            w, h = 2.2 - 1.3 * k, 2.1 - 1.2 * k                           # cou
        w, h = w * 1.15, h * 1.1                                          # s43 : tronc plus massif, voûté
        rings.append(ellipse(p, w, h, 10))
        prof.append((p, w, h, t))
    lot.put(M["chair"], G.loft(rings, True, True))
    # côtes et faisceaux musculaires : plaques sombres étroites sur les flancs (peau), conduits turquoise entre elles
    for i in range(2, n - 3, 2):
        p, w, h, t = prof[i]
        d = G.norm(G.sub(pts[i + 1], pts[i - 1]))
        for s in (-1, 1):
            lot.put(M["peau"], plaque((p[0], p[1] + s * w * 0.82, p[2] + h * 0.25), G.norm((0.0, s * 0.9, 0.45)), 0.9, 1.6 + 0.4 * (t < 0.6), 0.16, up=d, coins=0.6))
            if i % 4 == 2:
                lot.put(M["turq"], G.tube([(p[0] - 0.4, p[1] + s * w * 0.95, p[2] - h * 0.1), (p[0] + 0.6, p[1] + s * w * 0.9, p[2] + h * 0.5)], 0.08, 6))
    # plaques pectorales et dorsales (blindage sombre iridescent)
    for i in range(3, n - 2, 3):
        p, w, h, t = prof[i]
        d = G.norm(G.sub(pts[i + 1], pts[i - 1]))
        lot.put(M["blind2"], plaque((p[0] + w * 0.2, p[1], p[2] - h * 0.85), (0.1, 0.0, -1.0), w * 1.3, 1.1, 0.18, up=d, coins=0.65))
        lot.put(M["blind"], plaque((p[0], p[1], p[2] + h * 0.9), (0.0, 0.0, 1.0), w * 0.9, 1.0, 0.2, up=d, coins=0.7))
    # épines de cristal dorsales, inclinées vers l'arrière, grandes aux épaules
    for i in range(1, n - 2, 2):
        p, w, h, t = prof[i]
        L = 0.8 + 2.6 * math.sin(math.pi * min(1.0, max(0.0, (t - 0.05) / 0.9))) ** 1.2
        d = G.norm(G.sub(pts[i + 1], pts[i - 1]))
        lot.put(M["cristal"], pointe((p[0], p[1], p[2] + h * 0.95), G.norm((-0.7 * d[0], 0.0, 1.0)), L, 0.18 + 0.1 * L / 3.0))
        if i % 4 == 1:
            for s in (-1, 1):
                lot.put(M["cristal"], pointe((p[0] - 0.2, p[1] + s * w * 0.5, p[2] + h * 0.8), G.norm((-0.5, s * 0.8, 0.7)), L * 0.45, 0.16))
    # conduits lumineux le long de la colonne (deux lignes) : du bassin au cou
    for s in (-1, 1):
        line = [(pts[i][0], pts[i][1] + s * prof[i][1] * 0.55, pts[i][2] + prof[i][2] * 0.98) for i in range(0, n - 2, 2)]
        lot.put(M["conduit"], G.tube(line, 0.1, 6))
    # s43 : CAGE THORACIQUE d'os ouverte : côtes qui partent de la colonne et s'arc-boutent autour du ventre, au-dessus du sac
    for i in range(int(n * 0.2), int(n * 0.72), 2):
        p, w, h, t = prof[i]
        for s in (-1, 1):
            arc = [(p[0] + 0.25 * math.sin(a), p[1] + s * (w + 0.35) * math.sin(a), p[2] + (h + 0.3) * math.cos(a)) for a in
                   (0.25, 0.8, 1.35, 1.9, 2.35)]
            arc.append((p[0] + 0.7, p[1] + s * 0.5, p[2] - h - 0.55))
            lot.put(M["blind"], G.tube(arc, 0.17, 6))
    # sac ventral lumineux (ponte) : sphère-cœur sous le ventre, halo ; gonfle avec `sac`
    pv = prof[int(n * 0.28)][0]
    rs = 0.9 + 0.5 * sac
    lot.put(M["coeur"], G.sphere((pv[0] + 0.6, pv[1], pv[2] - 1.3 - 0.3 * sac), rs, 12, 6))
    lot.put(M["halo"], G.sphere((pv[0] + 0.6, pv[1], pv[2] - 1.3 - 0.3 * sac), rs * 1.6, 12, 6))
    for k in range(5):
        a = G.TAU * k / 5
        lot.put(M["chair"], G.tube([(pv[0] + 0.6 + 0.8 * math.cos(a), pv[1] + 0.9 * math.sin(a), pv[2] - 0.5), (pv[0] + 0.6 + 1.1 * math.cos(a), pv[1] + 1.2 * math.sin(a), pv[2] - 1.9)], 0.12, 6))
    return pts, prof


def tail(lot, M, u, bob):
    """Queue : loft effilé de chair, épines, trois anneaux flottants, pointes de cristal au bout."""
    ctrl = queue(u, bob)
    pts = G.catmull(ctrl, 5)
    n = len(pts)
    rings = []
    for i, p in enumerate(pts):
        t = i / float(n - 1)
        r = 1.3 * (1.0 - t) ** 1.1 + 0.18
        rings.append(ellipse(p, r, r * 0.9, 8))
    lot.put(M["chair"], G.loft(rings, True, True))
    for i in range(2, n - 2, 3):
        p = pts[i]
        t = i / float(n - 1)
        d = G.norm(G.sub(pts[i + 1], pts[i - 1]))
        lot.put(M["peau"], plaque((p[0], p[1], p[2] + 1.2 * (1 - t) + 0.1), (0.0, 0.0, 1.0), 0.9, 0.9, 0.14, up=d, coins=0.6))
        lot.put(M["cristal"], pointe((p[0], p[1], p[2] + 1.25 * (1 - t) + 0.15), G.norm((-0.6, 0.0, 1.0)), 0.9 + 0.6 * (1 - t), 0.16))
    for k, i in enumerate((int(n * 0.55), int(n * 0.75), int(n * 0.92))):
        p = pts[i]
        d = G.norm(G.sub(pts[i + 1], pts[i - 1]))
        # s43 : vertèbres d'os en collier (plus d'anneaux flottants) : trois pointes rayonnantes par vertèbre
        for q in range(3):
            a = G.TAU * q / 3 + 0.5
            lot.put(M["blind"], pointe(p, G.norm((-0.4, 0.9 * math.cos(a), 0.9 * math.sin(a) + 0.2)), 1.3 - 0.25 * k, 0.2, 5))
    tip = pts[-1]
    lot.put(M["cristal"], pointe(tip, G.norm(G.sub(tip, pts[-3])), 1.6, 0.22))
    for s in (-1, 1):
        lot.put(M["os"], pointe((tip[0] + 0.4, tip[1] + s * 0.3, tip[2]), G.norm((-0.7, s * 0.9, 0.5)), 1.0, 0.14, 5))


def jambe(lot, M, s, u, bob):
    """Jambe digitigrade du côté s : hanche, cuisse (chair + plaque), tibia (os blindé), métatarse, trois tentacules-racines en guise d'orteils."""
    H = (0.0, s * 1.7, 5.1 + bob)
    K0 = (2.2, s * 2.0, 3.3)
    A0 = (0.2, s * 2.1, 1.5)
    T0 = (1.5, s * 2.2, 0.35)
    dx, dz = pas(u, AMP, 0.9)
    T = (T0[0] + dx, T0[1], T0[2] + dz)
    A = G.add(T, G.sub(A0, T0))
    l1, l2 = G.length(G.sub(K0, (0.0, s * 1.7, 5.1))), G.length(G.sub(A0, K0))
    K = ik2(H, A, l1, l2, (1.0, 0.0, 0.25))
    lot.put(M["chair"], G.sphere(H, 0.95, 10, 5))
    lot.put(M["chair"], hexseg(H, K, 1.05, 0.7, 7, 0.2))
    lot.put(M["peau"], plaque(G.add(G.lerp(H, K, 0.45), (0.5, s * 0.75, 0.3)), G.norm((0.6, s * 0.8, 0.4)), 1.0, 1.9, 0.16, up=G.norm(G.sub(K, H))))
    lot.put(M["turq"], hexseg(G.add(H, (0.4, s * 0.9, -0.3)), G.add(K, (0.3, s * 0.6, 0.2)), 0.09, 0.08))
    lot.put(M["struct"], G.sphere(K, 0.62, 8, 4))
    lot.put(M["blind2"], hexseg(K, A, 0.62, 0.45, 7, 0.1))
    lot.put(M["os"], pointe(G.add(K, (-0.3, s * 0.2, 0.3)), (-0.8, 0.0, 0.5), 1.0, 0.16, 5))
    lot.put(M["struct"], G.sphere(A, 0.48, 8, 4))
    lot.put(M["peau"], hexseg(A, T, 0.5, 0.38, 6, 0.1))
    lot.put(M["conduit"], G.boite(G.add(A, (0.3, s * 0.4, 0.0)), (0.12, 0.08, 0.3)))
    # orteils : trois tentacules-racines vers l'avant (tubes qui s'étalent), un ergot d'os
    for ay in (0.0, 0.75, -0.75):
        p0 = (T[0] + 0.2, T[1] + ay * 0.25, T[2] + 0.1)
        p1 = (T[0] + 1.0, T[1] + ay * 0.6, max(0.05, T[2] - 0.2))
        p2 = (T[0] + 1.7, T[1] + ay * 0.9, max(0.02, T[2] - 0.3))
        lot.put(M["chair"], G.tube([p0, p1, p2], 0.16, 6, rfun=None))
        lot.put(M["os"], pointe(p2, G.norm((0.8, ay * 0.4, -0.3)), 0.5, 0.1, 4))
    lot.put(M["os"], pointe(G.add(A, (-0.4, 0.0, -0.3)), (-0.8, 0.0, -0.4), 0.8, 0.14, 5))


def bras_canon(lot, M, S_, charge, recul, eclair, lever):
    """Bras droit : épaule charnue, bras, avant-bras-canon (fût d'os blindé à anneaux), vortex à la bouche ; `lever` : le bras monte."""
    s = -1
    E0 = (1.6, s * 3.4, 5.2)
    M0 = (5.4, s * 3.8, 4.3)
    E = G.rot_y(E0, -lever, S_)
    Mz = G.rot_y(M0, -lever, S_)
    d = G.norm(G.sub(Mz, E))
    if recul > 0:
        E, Mz = G.add(E, G.mul(d, -0.6 * recul)), G.add(Mz, G.mul(d, -0.6 * recul))
    lot.put(M["chair"], G.sphere(S_, 1.0, 10, 5))
    lot.put(M["chair"], hexseg(S_, E, 0.85, 0.6, 7, 0.2))
    lot.put(M["peau"], plaque(G.lerp(S_, E, 0.5), G.norm((0.4, s * 1.0, 0.3)), 0.9, 1.6, 0.14, up=G.norm(G.sub(E, S_))))
    lot.put(M["struct"], G.sphere(E, 0.62, 8, 4))
    # fût du canon : os blindé cannelé, trois anneaux, bouche à vortex
    lot.put(M["blind2"], hexseg(E, G.lerp(E, Mz, 0.4), 0.7, 0.75, 8))
    lot.put(M["canon"], hexseg(G.lerp(E, Mz, 0.38), Mz, 0.62, 0.5, 8))
    lot.put(M["struct"], G.tube([G.lerp(E, Mz, 0.9), G.add(Mz, G.mul(d, 0.15))], 0.3, 8))
    for k in range(3):
        c = G.lerp(E, Mz, 0.5 + 0.17 * k + 0.08 * charge)
        rr = 0.95 - 0.12 * k
        lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", rr, 0.22, 0.08), c, d))
        lot.put(M["turq"], G.oriente(rainure((0.0, 0.0, 0.0), "z", rr + 0.14, 0.04), c, d))
    rv = 0.4 + 0.45 * charge
    lot.put(M["coeur"], G.oriente(G.tour([(0.0, 0.0), (0.04, rv)], 12, "z", cap1=True), G.add(Mz, G.mul(d, 0.1)), d))
    lot.put(M["halo"], G.sphere(G.add(Mz, G.mul(d, 0.3)), 0.8 + 0.7 * charge, 12, 6))
    if eclair > 0:
        lot.put(M["coeur"], G.oriente(G.tour([(0.0, 0.0), (0.08, 0.55), (2.4 * eclair, 0.3), (3.4 * eclair, 0.0)], 10, "z", cap0=True), G.add(Mz, G.mul(d, 0.2)), d))
        lot.put(M["halo"], G.sphere(G.add(Mz, G.mul(d, 1.5 * eclair)), 0.7 + 0.6 * eclair, 10, 5))
    # tendons et conduit du bras, tentacule qui pend sous le canon
    lot.put(M["turq"], G.tube([G.add(S_, (0.5, s * 0.6, -0.3)), G.add(E, (0.3, s * 0.4, 0.2)), G.add(G.lerp(E, Mz, 0.6), (0.0, s * 0.5, -0.4))], 0.08, 6))
    lot.put(M["chair"], G.tube([G.lerp(E, Mz, 0.55), G.add(G.lerp(E, Mz, 0.6), (0.2, s * 0.3, -1.4)), G.add(G.lerp(E, Mz, 0.75), (0.6, s * 0.1, -2.3))], 0.12, 6))


def bras_griffes(lot, M, S_, swing):
    """Bras gauche : bras, avant-bras, main à trois longues griffes d'os et deux tentacules."""
    s = 1
    E = G.rot_y((1.2, s * 3.3, 5.0), swing, S_)
    W = G.rot_y((2.6, s * 3.5, 2.4), swing, S_)
    lot.put(M["chair"], G.sphere(S_, 1.0, 10, 5))
    lot.put(M["chair"], hexseg(S_, E, 0.85, 0.6, 7, 0.2))
    lot.put(M["peau"], plaque(G.lerp(S_, E, 0.5), G.norm((0.3, s * 1.0, 0.3)), 0.9, 1.6, 0.14, up=G.norm(G.sub(E, S_))))
    lot.put(M["struct"], G.sphere(E, 0.6, 8, 4))
    lot.put(M["peau"], hexseg(E, W, 0.58, 0.42, 7, 0.1))
    lot.put(M["conduit"], hexseg(G.add(E, (0.3, s * 0.5, 0.0)), G.add(W, (0.3, s * 0.4, 0.3)), 0.08, 0.07))
    lot.put(M["struct"], G.sphere(W, 0.5, 8, 4))
    d0 = G.norm(G.rot_y((0.6, 0.0, -0.8), swing))
    for k in range(3):
        q = (k - 1) * 0.45
        dd = G.norm(G.add(d0, (0.0, q * 0.6, 0.0)))
        lot.put(M["os"], pointe(G.add(W, (0.1, q, -0.1)), dd, 2.6 - 0.5 * abs(k - 1), 0.2, 5))
    for q in (-0.5, 0.5):
        lot.put(M["chair"], G.tube([G.add(W, (-0.2, q * 0.8, -0.2)), G.add(W, (-0.9, q * 1.6, -1.2)), G.add(W, (-1.0, q * 2.2, -2.2))], 0.1, 6))


def tete(lot, M, base, ouverture, lunge):
    """Tête : crâne allongé (loft anguleux), crête de plaques sombres, quatre yeux, mâchoire articulée, cœur lumineux dans la gueule, dents."""
    bx, by, bz = base
    pitch = -0.35 * lunge
    def P(x, y, z):
        return (bx + x * math.cos(pitch) - z * math.sin(pitch), by + y, bz + x * math.sin(pitch) + z * math.cos(pitch))
    def sect(x, w, h, zc):
        return [P(x, -w, zc - h * 0.55), P(x, -w * 0.7, zc + h * 0.75), P(x, 0.0, zc + h), P(x, w * 0.7, zc + h * 0.75), P(x, w, zc - h * 0.55),
                P(x, w * 0.45, zc - h * 0.7), P(x, -w * 0.45, zc - h * 0.7)]
    lot.put(M["peau"], G.loft([sect(-0.6, 0.95, 0.85, 0.2), sect(0.6, 1.05, 0.9, 0.3), sect(1.8, 0.85, 0.7, 0.25), sect(2.9, 0.55, 0.4, 0.1),
                              sect(3.5, 0.3, 0.18, 0.0)], True, True))
    # crête : plaques sombres en écailles vers l'arrière, pointes d'os
    for k in range(3):
        lot.put(M["blind2"], plaque(P(-0.5 - 0.5 * k, 0.0, 1.0 + 0.1 * k), G.norm((-0.5, 0.0, 1.0)), 1.2 - 0.2 * k, 0.9, 0.14, up=(1, 0, 0), coins=0.6))
    for s in (-1, 1):
        lot.put(M["os"], pointe(P(-0.3, s * 0.8, 0.9), G.norm((-0.8, s * 0.5, 0.7)), 1.3, 0.15, 5))
        lot.put(M["cristal"], pointe(P(-0.9, s * 0.5, 1.1), G.norm((-0.9, s * 0.3, 0.6)), 1.1, 0.15))
        # yeux : deux par côté (quatre), petits blocs lumineux
        lot.put(M["conduit"], G.boite(P(1.0, s * 0.95, 0.45), (0.22, 0.08, 0.12)))
        lot.put(M["conduit"], G.boite(P(0.3, s * 1.0, 0.6), (0.16, 0.08, 0.1)))
    # mâchoire inférieure articulée (pivot x = 0,2), s'ouvre vers le bas ; dents sur les deux
    ang = 0.7 * ouverture
    def J(x, y, z):
        xx = x - 0.2
        return P(0.2 + xx * math.cos(ang) + z * math.sin(ang), y, -xx * math.sin(ang) + z * math.cos(ang))
    jaw = [[J(0.2, -0.8, -0.35), J(0.2, 0.8, -0.35), J(0.2, 0.55, -0.8), J(0.2, -0.55, -0.8)],
           [J(1.8, -0.65, -0.4), J(1.8, 0.65, -0.4), J(1.8, 0.4, -0.75), J(1.8, -0.4, -0.75)],
           [J(3.1, -0.3, -0.3), J(3.1, 0.3, -0.3), J(3.1, 0.2, -0.5), J(3.1, -0.2, -0.5)]]
    lot.put(M["peau"], G.loft(jaw, True, True))
    for k in range(4):
        x = 0.7 + 0.65 * k
        for s in (-1, 1):
            lot.put(M["os"], pointe(P(x, s * (0.7 - 0.1 * k), -0.35), (0.0, 0.0, -1.0), 0.5, 0.1, 4))
            lot.put(M["os"], pointe(J(x, s * (0.55 - 0.08 * k), -0.4), (0.0, 0.0, 1.0), 0.4, 0.09, 4))
    # cœur lumineux au fond de la gueule (grossit quand elle s'ouvre)
    rv = 0.3 + 0.35 * ouverture
    lot.put(M["coeur"], G.sphere(P(0.9, 0.0, -0.3 - 0.25 * ouverture), rv, 10, 5))
    lot.put(M["halo"], G.sphere(P(1.1, 0.0, -0.3 - 0.25 * ouverture), rv * 1.8, 10, 5))


def build(S, lot, u=0.0, attaque=None):
    """Pose de l'Écorcheur : u = phase de course ; attaque = phase d'attaque (0 à 1) ou None."""
    M = matieres(S)
    R.raz()
    if attaque is not None:
        i = int(round(attaque * SERIE["attaque"])) % SERIE["attaque"]
        charge, recul, eclair = ATTAQUE[i]
        lever, swing, lunge, ouverture, sac = 0.55, 0.3, 0.6 + 0.3 * charge, 1.0, 0.3 + 0.7 * charge
        ph = (0.1, 0.4)
        bob, u = 0.0, 0.0
    else:
        charge, recul, eclair = 0.0, 0.0, 0.0
        lever, lunge, ouverture, sac = 0.1 + 0.05 * math.sin(G.TAU * u), 0.0, 0.2, 0.0
        swing = 0.35 * math.sin(G.TAU * u)
        ph = (u, u + 0.5)
        bob = 0.18 * abs(math.sin(G.TAU * u))
    pts, prof = tronc(lot, M, u, bob, lunge, sac)
    tail(lot, M, u, bob)
    for s, p in ((1, ph[0]), (-1, ph[1])):
        jambe(lot, M, s, p, bob)
    sh = pts[int(len(pts) * 0.62)]
    bras_canon(lot, M, (sh[0] + 0.3, -2.4, sh[2] + 0.4), charge, recul, eclair, lever)
    bras_griffes(lot, M, (sh[0] + 0.3, 2.4, sh[2] + 0.4), swing)
    hd = pts[-1]
    tete(lot, M, (hd[0] + 0.3, hd[1], hd[2] + 0.1), ouverture, lunge)
    return {"pieces": lot.n, "u": u, "attaque": attaque}


def build_anime(S, lot, stage, u, attaque):
    """Entrée commune des titans animés (batch_titans.anime) : pas de stade (un prototype par ère : l'échelle vient du jeu)."""
    return build(S, lot, u, attaque)
