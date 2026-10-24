"""Laser · Âge 15 · Néant (ère V cosmique, 6×6, niveaux 29 et 30) : le SOMMET de la suite. EXEMPLE du kit laser_e
(lot F1-A, aperçu d'essai) ; fiche : fo-logs/2026-10-24_F1/FICHES_LASER.md, âge 15 (fait foi). S'exécute DANS Blender.

En 3 mots : « sphère noire, disque d'accrétion, griffes d'or ». Consigne du DC (23/10, 12 h 40 : « big bang ou maîtrise
cosmique du néant ») transposée au laser : l'émetteur est un HORIZON NOIR (sphère lisse, seul vrai noir) ceint d'un
DISQUE D'ACCRÉTION segmenté blanc-or vers orange, INCLINÉ (penché de 25° vers l'arrière : il ne se lit ni comme l'anneau
vertical de La Porte ni comme le disque couché de la mitrailleuse 15), tenu par TROIS GRIFFES D'OR qui montent de la
platine (« un Big Bang tenu en laisse ») ; un point blanc-or à l'avant de la sphère est la lentille.
Affût en PUITS DE GRAVITÉ : 4 gradins en cône de noir chaud, liserés de pleine lumière sur chaque arête ; 16 piliers
d'horizon (condensateurs) noirs cerclés d'or, pointe incandescente ; coins arrière : deux micro-singularités dans des
griffes d'or ; liaisons en conduits d'or en arc.
Palette 60/30/10 (ages.PALETTE[15]) : noir chaud / or chauffé / lumière incandescente blanc-or vers orange.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
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
HABILLAGE = dict(ages.CORPS[15],
                 cerclages="or_chauffe",
                 forme_affut=dict(gradins=4, profil="cone", flanc="noir_chaud", flanc2="cendre", lisere="emit",
                                  rapport=0.8),
                 forme_tete="fourche")
INCLINAISON = math.radians(25.0)
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
    """Micro-singularité : sphère d'horizon dans 3 griffes d'or sur un socle rond de noir chaud à jonc d'or."""
    with at(g, x, yn):
        g.cyl((0, 0, 0.09), "z", r * 1.2, 0.18, M["noir_chaud"], n=32, style="soft", what="socle")
        g.torus((0, 0, 0.18), "z", r * 1.2, 0.02, M["or_chauffe"], n=32, m=6, what="jonc")
        zc = 0.18 + r * 1.25
        g.sphere((0, 0, zc), r, M["horizon"], n=24, m=12, what="horizon")
        g.torus((0, 0, zc), "z", r * 1.12, 0.022, M["emit"], n=32, m=6, what="photons")
        for k in range(3):
            a = math.pi / 2 + TAU * k / 3
            d = V((math.cos(a), math.sin(a), 0))
            # griffes collées à l'horizon (aucun jour entre la griffe et la sphère : trou enfermé sinon)
            pts = [d * r * 1.0 + V((0, 0, 0.18)), d * r * 1.04 + V((0, 0, zc - 0.2 * r)),
                   d * r * 0.98 + V((0, 0, zc + 0.45 * r)), d * r * 0.55 + V((0, 0, zc + 0.9 * r))]
            griffe(g, pts, 0.07, 0.06, M["or_chauffe"])


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
    for (x, yn, pw) in ((0.0, -2.7, 16.0), (-2.4, -1.4, 12.0), (2.4, -1.4, 12.0), (-2.2, 2.2, 14.0), (2.2, 2.2, 14.0)):
        g.halo((x, Y(yn), 0.6), M["_emit_rgb"], pw)


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
    for k in range(4):
        r = (0.32 - 0.05 * k) * (y1 - y0)
        g.cyl((0, yc, zz + 0.05 + 0.1 * k), "z", r, 0.07, M["noir_profond"] if k % 2 == 0 else M["or_chauffe"], n=32,
              style="soft", what="disque")
    g.sphere((0, yc, zz + 0.5), 0.07, M["emit"], n=12, m=6, what="feu")


def emetteur(g, c):
    """HORIZON NOIR (sphère de rayon 0,7 re), DISQUE D'ACCRÉTION incliné de 25° (anneau segmenté de lumière, bords d'or),
    trois GRIFFES D'OR de la platine au disque, point blanc-or à l'avant (lentille)."""
    M = g.M
    re, zh = c.re, c.zh
    t = c.T["tete"]
    rs = 0.7 * re
    g.sphere((0, 0, zh), rs, M["horizon"], n=40, m=20, what="horizon")
    # disque d'accrétion : anneau plat dans le plan perpendiculaire au faisceau, penché vers l'arrière
    g.push((0, 0, zh), rx=-(math.pi / 2 - INCLINAISON))
    Rin, Rout = rs * 1.12, re * 1.0
    nseg = 28
    for k in range(nseg):
        a0 = TAU * k / nseg + 0.02
        a1 = TAU * (k + 1) / nseg - 0.02
        for (ra, rb, m, z0, z1) in ((Rin, Rout * 0.82, M["emit"], -0.012, 0.012),
                                     (Rout * 0.82, Rout, M["emit_soft"] if k % 2 else M["emit2"], -0.01, 0.01)):
            q = [V((ra * math.cos(a0), ra * math.sin(a0), z0)), V((rb * math.cos(a0), rb * math.sin(a0), z0)),
                 V((rb * math.cos(a1), rb * math.sin(a1), z0)), V((ra * math.cos(a1), ra * math.sin(a1), z0))]
            g.hexa(q + [p + V((0, 0, z1 - z0)) for p in q], m, "flat", "segment")
    g.torus((0, 0, 0), "z", Rout + 0.012, 0.022, M["or_chauffe"], n=56, m=6, what="bord")
    g.torus((0, 0, 0), "z", Rin - 0.01, 0.014, M["or_chauffe"], n=48, m=6, what="bord")
    g.pop()
    # griffes : de la platine au bord du disque (3, à 120°, dans le repère incliné)
    zb = t["z0"] + t["hpl"]
    # colonne d'horizon : porte la sphère depuis la platine (courte et large : jamais une cheminée)
    g.cyl((0, 0, (zb + zh - rs * 0.6) / 2), "z", 0.3 * re, zh - rs * 0.6 - zb, M["noir_chaud"], n=32, style="soft",
          what="colonne")
    for f in (0.25, 0.75):
        g.tube_shell((0, 0, zb + f * (zh - rs * 0.6 - zb)), "z", 0.3 * re + 0.02, 0.3 * re - 0.01, 0.035,
                     M["or_chauffe"], n=32, what="cerclage")
    for k in range(3):
        a = math.pi / 2 + TAU * k / 3
        cx, cy = math.cos(a) * (re * 1.0), math.sin(a) * (re * 1.0)
        # point du bord du disque dans le repère de la tête (rotation rx autour de x :
        # (x, y, z) -> (x, y cos rx − z sin rx, y sin rx + z cos rx), z local = 0)
        rx = -(math.pi / 2 - INCLINAISON)
        px, py, pz = cx, cy * math.cos(rx), cy * math.sin(rx)
        tip = V((px, py, zh + pz))
        base = V((px * 0.5, py * 0.4 - 0.2 * re, zb + 0.02))
        mid = base.lerp(tip, 0.55) + V((px * 0.35, 0, 0.1 * re))
        if tip.z < zb + 0.1:
            tip = V((tip.x, tip.y, zb + 0.1))
        griffe(g, [base, mid, tip, tip + (V((0, 0, zh)) - tip) * 0.12], 0.09 + 0.01 * c.side, 0.07, M["or_chauffe"])
    # lentille : point blanc-or à l'avant de l'horizon
    g.sphere((0, rs * 0.98, zh), 0.09, M["emit2"], n=14, m=7, what="lentille")
    F.lit_ring(g, (0, rs * 0.94, zh), "y", 0.16, M["emit"], w=0.03)
