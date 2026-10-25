"""Laser · Âge 15 · Néant (ère V cosmique, 6×6, niveaux 29 et 30) : le SOMMET de la suite. EXEMPLE du kit laser_e
(lot F1-A, aperçu d'essai) ; fiche : fo-logs/2026-10-24_F1/FICHES_LASER.md, âge 15 (fait foi). S'exécute DANS Blender.

En 3 mots : « sphère noire, disque d'accrétion, griffes d'or ». Consigne du DC (23/10, 12 h 40 : « big bang ou maîtrise
cosmique du néant ») transposée au laser : l'émetteur est un HORIZON NOIR (sphère lisse, seul vrai noir) ceint d'un
DISQUE D'ACCRÉTION segmenté blanc-or vers orange, OBLIQUE, tenu par TROIS GRIFFES D'OR qui montent de la platine (« un
Big Bang tenu en laisse ») ; un point blanc-or à l'avant de la sphère est la lentille.
Correction F1-A (24/10, défaut M-3) : le premier essai penchait le disque de 25° vers l'ARRIÈRE ; en pose N (caméra au
sud, en hauteur) il se lisait alors comme une ellipse couchée sur l'équateur de la sphère, c'est-à-dire le motif de la
mitrailleuse 15 que la fiche interdit. Le disque est désormais OBLIQUE (NORMALE_DISQUE : normale penchée de 25° de la
verticale, vers l'arrière et vers la droite) : rapport des axes de l'ellipse (petit / grand) 0,92 en N, 0,74 en E
(grand axe penché de 36°), 0,36 au plus bas (poses S et SO) ; calcul : RONDES.md, fo-logs/2026-10-24_F1/NOTES.md (E84).
Affût en PUITS DE GRAVITÉ : 4 gradins en cône de noir chaud, liserés de pleine lumière sur chaque arête ; 16 piliers
d'horizon (condensateurs) noirs cerclés d'or, pointe incandescente ; coins arrière : deux micro-singularités dans des
griffes d'or ; liaisons en conduits d'or en arc.
Palette 60/30/10 (ages.PALETTE[15]) : noir chaud / or chauffé / lumière incandescente blanc-or vers orange.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import epoques as E_
import formes as F
import orne as O
import parts as PT
from kit import SQ2, TAU
from repere import Y, at

V = Vector

EPOQUE = 15
NOM = ages.NOMS[15]
TRIPLET = ("sphère noire", "disque d'accrétion", "griffes d'or")
FOYER = ages.FOYER[15]
FAISCEAU = dict(rgb=(1.0, 0.9, 0.66), rgb2=(1.0, 0.64, 0.28),
                forme="trait blanc-or très fin à gaine orange, lentille gravitationnelle (le fond se courbe) à l'impact",
                largeur=0.7)
HABILLAGE = dict(ages.CORPS[15], **E_.MAQUETTES[15])
# lot F1-B : liserés de la lignée (anneaux CONTINUS de pleine lumière blanc-or) retirés ; l'âge pose ses propres
# liserés EN TIRETS, orange et blanc-or (socle) : la lumière de l'essai r0b était trop blanche (saturation 0,20, HORS de
# la famille 0,2 à 0,7) et ses foyers trop grands (L2 0,98 à 1,30 t², plafond 0,45). La silhouette ne change pas.
HABILLAGE["forme_affut"] = dict(HABILLAGE["forme_affut"], lisere=None)
# normale du disque dans le repère de la tête (faisceau vers +Y) : azimut 290°, élévation 65° (correction M-3)
_AZ, _EL = math.radians(290.0), math.radians(65.0)
NORMALE_DISQUE = (math.cos(_EL) * math.cos(_AZ), math.cos(_EL) * math.sin(_AZ), math.sin(_EL))
# l'horizon n'est pas traversé par l'axe des tourillons (il couperait le disque) : il est porté par une colonne et
# tenu par les griffes ; les bras de la fourche serrent le bord du disque
AXE = False


def matieres(metal, M):
    ages.matieres(15, metal, M)
    M["griffe"] = M["or_chauffe"]


def liaison(g, pts, r):
    """Conduit d'or chauffé à bagues de noir profond (arc)."""
    M = g.M
    P = g.tube(g.spline(pts, 10), r, M["or_chauffe"], n=12, what="conduit")[0]
    for i in range(2, len(P) - 1, 4):
        a = (P[min(len(P) - 1, i + 1)] - P[i - 1]).normalized()
        g.cyl(P[i], a, r * 1.35, r * 0.8, M["noir_profond"], n=12, style="hard", what="bague")


def griffe(g, pts, w, t, mat):
    """Griffe d'or : chaîne de blocs pleins le long d'une courbe, qui s'amincit vers la pointe."""
    P = [V(p) for p in pts]
    n = len(P) - 1
    for i in range(n):
        a, b = P[i], P[i + 1]
        d = b - a
        if d.length < 1e-5:
            continue
        f = 1.0 - 0.55 * i / max(1, n)
        dn = d.normalized()
        up = V((0, 0, 1)) if abs(dn.z) < 0.9 else V((1, 0, 0))
        x = dn.cross(up).normalized()
        z = x.cross(dn).normalized()
        R = Matrix((x, dn, z)).transposed()
        g.box((a + b) / 2, (w * f, d.length + t * 0.5, t * f), mat, "hard", R=R, what="griffe")


def condensateur(g, c, x, y, z, r, h):
    """Pilier d'horizon : fût de noir profond lisse, trois cerclages d'or, pointe incandescente blanc-or."""
    M = g.M
    hh = h * 1.15
    g.cyl((x, y, z + hh / 2), "z", r * 0.9, hh, M["noir_chaud"], n=20, style="soft", what="pilier")
    for f in (0.1, 0.55, 0.9):
        g.tube_shell((x, y, z + hh * f), "z", r * 0.9 + 0.014, r * 0.9 - 0.01, 0.03, M["or_chauffe"], n=20,
                     what="cerclage")
    g.cyl((x, y, z + hh + 0.04), "z", r * 0.55, 0.08, M["or_chauffe"], n=16, r2=r * 0.3, style="soft", what="pointe")
    g.sphere((x, y, z + hh + 0.1), r * 0.26, M["emit"], n=12, m=6, what="feu")


def _singularite(g, c, x, yn, r, M):
    """Micro-singularité : sphère d'horizon posée dans une COUPE de noir chaud (pleine jusqu'au socle), anneau de photons
    qui touche l'horizon, 3 griffes d'or ENFONCÉES dans la sphère, socle rond à jonc d'or.
    Lot F1-B : l'anneau de photons (rayon 1,12 r) et les griffes (posées à 1,0 à 1,04 r) laissaient, vus de la caméra,
    des jours enfermés entre eux et la sphère (e15-socle : 13 px à l'îlotage, 85 px au post-traitement, lot F1-A) :
    anneau à 1,0 r (son bord intérieur passe dans la sphère), griffes à 0,92 r et moins, coupe sous la sphère."""
    with at(g, x, yn):
        g.cyl((0, 0, 0.09), "z", r * 1.2, 0.18, M["noir_chaud"], n=32, style="soft", what="socle")
        g.torus((0, 0, 0.18), "z", r * 1.2, 0.02, M["or_chauffe"], n=32, m=6, what="jonc")
        zc = 0.18 + r * 1.1
        g.cyl((0, 0, 0.18 + r * 0.45), "z", r * 0.95, r * 0.9, M["noir_chaud2"], n=32, r2=r * 0.6, style="soft",
              what="coupe")
        g.sphere((0, 0, zc), r, M["horizon"], n=24, m=12, what="horizon")
        g.torus((0, 0, zc), "z", r * 1.0, 0.026, M["emit2"], n=40, m=6, what="photons")
        for k in range(3):
            a = math.pi / 2 + TAU * k / 3
            d = V((math.cos(a), math.sin(a), 0))
            pts = [d * r * 1.05 + V((0, 0, 0.18)), d * r * 0.92 + V((0, 0, zc - 0.35 * r)),
                   d * r * 0.9 + V((0, 0, zc + 0.35 * r)), d * r * 0.5 + V((0, 0, zc + 0.8 * r))]
            griffe(g, pts, 0.07, 0.06, M["or_chauffe"])


def _port(g, k, h):
    """Port de potentiel sur le flanc (repère du flanc) : plaque hexagonale de noir profond, cerclage d'or, point
    incandescent, rivets de cendre (lot F1-B : détail fin, la charte mesurait D3 = 20 petites pièces par t²)."""
    M = g.M
    g.cyl((0, 0, 0.012), "z", 0.085, 0.024, M["noir_profond"], n=6, style="hard", phase=math.pi / 6, what="port")
    g.tube_shell((0, 0, 0.022), "z", 0.07, 0.055, 0.012, M["or_chauffe"], n=24, what="cerclage")
    g.sphere((0, 0, 0.026), 0.022, M["emit2"] if k % 2 else M["emit"], n=8, m=5, what="point")
    for j in range(6):
        a = TAU * j / 6
        g.bolt((0.1 * math.cos(a), 0.1 * math.sin(a), 0.004), (0, 0, 1), 0.012, M["cendre"])


def _lisere_tirets(g, c, i, n):
    """Liseré EN TIRETS au sommet du flanc du gradin i : segments de lumière orange et blanc-or séparés par des
    joints sombres (foyers petits : L2 ; lumière plus orange : famille de l'âge)."""
    M = g.M
    R = c.gradins[i][0]
    for k in range(n):
        a0 = TAU * (k + 0.1) / n
        a1 = TAU * (k + 0.75) / n
        p0, nrm0, _ = O.flanc(c, i, a0, 0.93, 0.006)
        p1, nrm1, _ = O.flanc(c, i, a1, 0.93, 0.006)
        d = p1 - p0
        nrm = (nrm0 + nrm1).normalized()
        Rr = Matrix((d.normalized(), nrm.cross(d.normalized()), nrm)).transposed()
        g.box((p0 + p1) / 2, (d.length, 0.03, 0.012), M["emit2"] if k % 3 else M["emit"], "flat", R=Rr,
              what="lisere")


def socle(g, c):
    """Deux micro-singularités tenues en laisse aux coins arrière, conduits d'or vers le pivot, halos."""
    M = g.M
    zp = c.gradins[-1][3]
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        p = corps.place(c, nom)
        x, yn = p["x"] - sx * 0.1, p["yn"] - 0.1
        _singularite(g, c, x, yn, 0.34, M)
        liaison(g, [(x - sx * 0.3, Y(yn - 0.3), 0.15), (x * 0.55, Y(yn * 0.55), zp + 0.6),
                    (x * 0.25, Y(yn * 0.25), zp + 0.12)], 0.06)
    # lot F1-B : liserés en tirets, ports de potentiel et rivets de cendre sur les flancs du puits, anneaux de cendre
    for i in range(4):
        _lisere_tirets(g, c, i, 40 - 6 * i)
        O.rivets_flanc(g, c, i, 0.35, M["cendre"], pas=0.11, r=0.013)
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (196, 222, 248, 292, 318, 344)], _port, f=0.55, dr=0.006)
    O.sur_flanc(g, c, 1, [math.radians(a) for a in (210, 240, 270, 300, 330)], _port, f=0.55, dr=0.006)
    O.sur_flanc(g, c, 2, [math.radians(a) for a in (225, 270, 315)], _port, f=0.55, dr=0.006)
    O.ceinture(g, c, 0, 0.08, 0.022, M["noir_profond"], colliers=M["or_chauffe"], pas=0.6)
    for (x, yn, pw) in ((0.0, -2.7, 16.0), (-2.4, -1.4, 12.0), (2.4, -1.4, 12.0), (-2.2, 2.2, 14.0), (2.2, 2.2, 14.0)):
        g.halo((x, Y(yn), 0.6), M["_emit2_rgb"], pw)


def tete(g, c):
    """Lot F1-B : deux petites singularités dans des coupes d'or à l'arrière de la platine."""
    M = g.M
    zb = O.zb(c)
    for (x, y, w) in O.pods(c):
        g.cyl((x, y, zb + w * 0.45), "z", w * 1.0, w * 0.9, M["noir_chaud"], n=20, r2=w * 0.7, style="soft",
              what="coupe")
        g.tube_shell((x, y, zb + w * 0.9), "z", w * 0.95, w * 0.7, 0.025, M["or_chauffe"], n=20, what="jonc")
        g.sphere((x, y, zb + w * 1.35), w * 0.62, M["horizon"], n=16, m=8, what="horizon")
        g.torus((x, y, zb + w * 1.35), "z", w * 0.62, 0.016, M["emit2"], n=24, m=4, what="photons")


def piece(g, c):
    """Niveau 30 : deux LENTILLES DE CASIMIR aux coins avant : disques d'horizon dressés face au sud dans un cadre d'or
    à griffes, pointe incandescente, sur un patin de dalles noires relié au premier gradin."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * p["x"], p["yn"]
        corps.patin(g, c, x - sx * 0.12, yn + 0.12, 1.25, 1.25, rz=sx * 0.785)
        with at(g, x, yn, z=0.035):
            g.cyl((0, 0, 0.08), "z", 0.42, 0.16, M["noir_chaud"], n=32, style="soft", what="socle")
            g.torus((0, 0, 0.16), "z", 0.42, 0.022, M["or_chauffe"], n=32, m=6, what="jonc")
            zc = 0.62
            g.cyl((0, 0, zc), "y", 0.36, 0.1, M["horizon"], n=40, what="disque")
            g.tube_shell((0, 0, zc), "y", 0.42, 0.35, 0.12, M["or_chauffe"], n=40, what="cadre")
            F.lit_ring(g, (0, -0.065, zc), "y", 0.33, M["emit"], w=0.03)
            for k in range(3):
                a = -math.pi / 2 + (k - 1) * 1.1
                d = V((math.cos(a), 0, math.sin(a)))
                pts = [V((0, 0, 0.16)) + V((d.x, 0, 0)) * 0.25, V((d.x * 0.5, 0.0, zc + d.z * 0.5)),
                       V((d.x * 0.4, -0.05, zc + d.z * 0.38))]
                griffe(g, pts, 0.07, 0.06, M["or_chauffe"])
            g.sphere((0, -0.07, zc), 0.06, M["emit2"], n=12, m=6, what="point")
        g.halo((x, Y(yn - 0.4), 0.6), M["_emit_rgb"], 14.0)


def arriere(g, c):
    """Caisson arrière en noir chaud à arêtes d'or : stabilisateur de Casimir (empilement de disques noirs et or)."""
    M = g.M
    t = c.T["tete"]
    zb = t["z0"] + t["hpl"]
    bx, y0, y1, z1 = t["bx"], t["yb0"], t["yb1"], t["zb1"]
    PT.hull(g, -bx, bx, y0, y1, zb, zb + 0.3 * (z1 - zb), ins=(0.04, 0.05, 0.0), panel=0.3,
                  mats=[M["noir_chaud"], M["noir_chaud2"]], rivet_step=0.14)
    yc = (y0 + y1) / 2
    zz = zb + 0.3 * (z1 - zb)
    # lot F1-B (« stabilisateur arrière banal ») : pile de Casimir plus large et plus basse, plaques de noir profond
    # séparées par des jours INCANDESCENTS (le vide entre les plaques), trois griffes d'or qui la tiennent, feu au sommet
    rs = 0.4 * (y1 - y0)
    for k in range(5):
        r = rs * (1.0 - 0.1 * k)
        g.cyl((0, yc, zz + 0.04 + 0.085 * k), "z", r, 0.06, M["noir_profond"] if k % 2 == 0 else M["noir_chaud2"],
              n=40, style="soft", what="plaque_casimir")
        g.cyl((0, yc, zz + 0.04 + 0.085 * k + 0.042), "z", r * 0.97, 0.022, M["emit2"] if k % 2 else M["emit"], n=40,
              style="flat", what="jour_casimir")
        g.tube_shell((0, yc, zz + 0.04 + 0.085 * k), "z", r + 0.012, r - 0.02, 0.02, M["or_chauffe"], n=40,
                     what="cerclage")
    ztop = zz + 0.04 + 0.085 * 4 + 0.03
    for k in range(3):
        a = math.pi / 2 + TAU * k / 3
        d = V((math.cos(a), math.sin(a), 0))
        griffe(g, [V((0, yc, zz)) + d * rs * 1.15, V((0, yc, zz + 0.2)) + d * rs * 1.05,
                   V((0, yc, ztop)) + d * rs * 0.75], 0.06, 0.05, M["or_chauffe"])
    g.sphere((0, yc, ztop + 0.05), 0.07, M["emit2"], n=12, m=6, what="feu")


def _repere_disque():
    """(n, ex, ey) : normale du disque et deux axes de son plan (ex : direction +x projetée), repère de la tête."""
    n = V(NORMALE_DISQUE).normalized()
    ex = (V((1.0, 0.0, 0.0)) - n * n.x).normalized()
    ey = n.cross(ex).normalized()
    return n, ex, ey


def emetteur(g, c):
    """HORIZON NOIR (sphère de rayon 0,7 re), DISQUE D'ACCRÉTION OBLIQUE (anneau segmenté de lumière, bords d'or ;
    normale NORMALE_DISQUE), trois GRIFFES D'OR de la platine au bord du disque, deux pinces d'or des bras de la fourche
    au bord du disque, point blanc-or à l'avant (lentille)."""
    M = g.M
    re, zh = c.re, c.zh
    t = c.T["tete"]
    rs = 0.7 * re
    g.sphere((0, 0, zh), rs, M["horizon"], n=40, m=20, what="horizon")
    n, ex, ey = _repere_disque()
    # le bord intérieur du disque TOUCHE l'horizon (aucun jour entre le disque et la sphère) et une couronne pleine de
    # noir profond passe sous les segments (aucun jour entre deux segments) : trous enfermés de 1 399 px en pose N au
    # premier rendu du disque oblique (r0c, 24/10)
    Rin, Rout = rs * 1.0, re * 1.05
    g.push_frame((0, 0, zh), n, ex)
    corps.anneau_plat(g, Rout * 0.99, Rin, -0.008, 0.008, M["noir_profond"], n=56, rond=False, what="fond_disque")
    # lot F1-B : segments séparés par des joints plus larges (0,05 rad de chaque côté) et deux bandes séparées par un
    # anneau sombre ; bande intérieure orange et blanc-or alternés (lumière plus orange, foyers plus petits : L2)
    nseg = 28
    g.torus((0, 0, 0), "z", Rout * 0.82, 0.016, M["noir_profond"], n=56, m=6, what="joint_disque")
    for k in range(nseg):
        a0 = TAU * k / nseg + 0.05
        a1 = TAU * (k + 1) / nseg - 0.05
        for (ra, rb, m, z0, z1) in ((Rin + 0.02, Rout * 0.8, M["emit2"] if k % 2 else M["emit"], -0.012, 0.012),
                                     (Rout * 0.84, Rout, M["emit_soft"] if k % 2 else M["emit2"], -0.01, 0.01)):
            q = [V((ra * math.cos(a0), ra * math.sin(a0), z0)), V((rb * math.cos(a0), rb * math.sin(a0), z0)),
                 V((rb * math.cos(a1), rb * math.sin(a1), z0)), V((ra * math.cos(a1), ra * math.sin(a1), z0))]
            g.hexa(q + [p + V((0, 0, z1 - z0)) for p in q], m, "flat", "segment")
    g.torus((0, 0, 0), "z", Rout + 0.012, 0.022, M["or_chauffe"], n=56, m=6, what="bord")
    g.torus((0, 0, 0), "z", Rin - 0.01, 0.014, M["or_chauffe"], n=48, m=6, what="bord")
    g.pop()
    zb = t["z0"] + t["hpl"]
    # colonne d'horizon : porte la sphère depuis la platine (courte et large : jamais une cheminée)
    g.cyl((0, 0, (zb + zh - rs * 0.6) / 2), "z", 0.3 * re, zh - rs * 0.6 - zb, M["noir_chaud"], n=32, style="soft",
          what="colonne")
    for f in (0.25, 0.75):
        g.tube_shell((0, 0, zb + f * (zh - rs * 0.6 - zb)), "z", 0.3 * re + 0.02, 0.3 * re - 0.01, 0.035,
                     M["or_chauffe"], n=32, what="cerclage")

    def bord(phi, r=Rout):
        return V((0, 0, zh)) + (ex * math.cos(phi) + ey * math.sin(phi)) * r
    # griffes : de la platine au bord du disque (3, à 120°, vers l'arrière et les côtés)
    for k in range(3):
        tip = bord(-math.pi / 2 + TAU * k / 3)
        base = V((tip.x * 0.5, tip.y * 0.4 - 0.2 * re, zb + 0.02))
        mid = base.lerp(tip, 0.55) + V((tip.x * 0.35, 0, 0.1 * re))
        if tip.z < zb + 0.1:
            tip = V((tip.x, tip.y, zb + 0.1))
        griffe(g, [base, mid, tip, tip + (V((0, 0, zh)) - tip) * 0.12], 0.09 + 0.01 * c.side, 0.07, M["or_chauffe"])
    # pinces : du bout de chaque bras de la fourche au point du bord du disque le plus proche ; PLAQUES pleines (reprise
    # de la correction F1-A, 24/10) : la pince en griffe mince laissait, en pose N, un jour enfermé entre le bras, la
    # pince et le bord du disque (59 px, 2 groupes, rendu r0c de 11 h 53) ; la plaque va du bras au bord du disque, du
    # point le plus proche jusqu'à la pointe de la griffe voisine (30° plus loin) : aucun jour entre bras, pince,
    # griffe et disque (370 px en pose S avec une plaque étroite, rendu final de 13 h 20)
    xa = t["xc"] + t["tc"] * 0.4
    ep = 0.03 + 0.004 * c.side
    for sx in (-1, 1):
        phi0 = 0.0 if sx > 0 else math.pi
        a_hi = V((sx * xa, 0.05 * re, zh + 0.06))
        a_lo = V((sx * xa, 0.0, zh - 0.3 * re))
        b_lo = bord(phi0 - sx * 0.2, Rout * 0.98)
        b_hi = bord(phi0 + sx * math.pi / 6, Rout * 0.98)
        q = [a_lo, b_lo, b_hi, a_hi]
        g.hexa([p - V((0, ep, 0)) for p in q] + [p + V((0, ep, 0)) for p in q], M["or_chauffe"], "hard", "pince")
    # lentille : point blanc-or à l'avant de l'horizon
    g.sphere((0, rs * 0.98, zh), 0.09, M["emit2"], n=14, m=7, what="lentille")
    F.lit_ring(g, (0, rs * 0.94, zh), "y", 0.16, M["emit"], w=0.03)
