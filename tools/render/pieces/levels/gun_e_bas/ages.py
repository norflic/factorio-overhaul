"""Mitrailleuse, lot V3-E, époques 2 à 9 : les GRANDS VOLUMES d'époque (troisième passe, 22/10, 19 h). S'exécute
DANS Blender.

Pourquoi ce module (arrêt de la deuxième passe par l'orchestrateur, 19 h 00) : au zoom 1, d'une époque à l'autre de
même taille, le corps, la disposition, les grands volumes et la FORME des canons restaient les mêmes ; seules la
couleur des foyers et la texture des jaquettes changeaient. Exigences bloquantes :
  (a) l'ARME change de TYPE à chaque époque (canon forgé unique, gatling à vapeur, gatling à fûts, obusier,
      canon-bobine, gatling à prisme, gatling à cuve de verre, gatling plombé à ailettes) ;
  (b) ce qui porte l'âge fait au moins une demi-tuile dans sa plus petite dimension ;
  (c) les grands volumes annexes (réservoirs, cuves, caissons, foyers, tours) suivent l'âge : au moins 25 % de la
      silhouette change de forme entre deux époques voisines ;
  (e) en 2×2 : moins de pièces, plus grosses.
Ce qui RESTE de la lignée (design.py) : tablier continu, colonne à goussets et couronne dentée, trémie au sud,
collecteur au pied de la colonne ; tête : collier, jupe, coupole rivetée, nacelle, tourelleau, bras de tourillon.
La taille des petits détails reste celle de la lignée (rivets 0,013 à 0,02, tôles de 0,22 à 0,30, briques de
0,13) : une grande époque porte plus de pièces, jamais de plus grosses.

Conventions : x en tuiles ; yn = y de jeu en tuiles vers le NORD (Y() le convertit) ; +Z haut.
"""
import math
import random

from mathutils import Matrix, Vector

import parts as PT
import parts2 as P2
import parts3 as P3
import parts4 as P4
from kit import SQ2, TAU, axv, basis

V = Vector


def Y(yn):
    return yn * SQ2


def Rd(d):
    """Repère dont l'axe z local suit d (pour poser des boîtes le long d'une direction)."""
    a, u, w = basis(V(d))
    return Matrix((u, w, a)).transposed()


# ================================================================================================
# Aides de forme
# ================================================================================================
def courses(g, q, mats, bw=0.13, bh=0.062, t=0.016, what="brique"):
    """Briques en rangs décalés sur le quadrilatère q (p00, p10, p11, p01), joints sombres (fond du caisson)."""
    q = [V(p) for p in q]
    nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
    lu, lv = (q[1] - q[0]).length, (q[3] - q[0]).length
    nv = max(1, int(round(lv / bh)))
    gap = 0.012

    def P(s, t_):
        return q[0].lerp(q[1], s).lerp(q[3].lerp(q[2], s), t_)
    for j in range(nv):
        t0, t1 = j / nv + gap / lv / 2, (j + 1) / nv - gap / lv / 2
        off = 0.5 * bw if j % 2 else 0.0
        x = -off
        k = 0
        while x < lu - 1e-6:
            a, b = max(0.0, x), min(lu, x + bw)
            if b - a > 0.03:
                s0, s1 = a / lu + gap / lu / 2, b / lu - gap / lu / 2
                m = mats[(j * 3 + k * 7) % len(mats)]
                th = t * (1.0 + 0.3 * (g.rng.random() - 0.5))
                g.slab([P(s0, t0), P(s1, t0), P(s1, t1), P(s0, t1)], nrm, th, m, "hard", what)
            x += bw
            k += 1


def lump(g, c, r, mat, sz=0.6, n=10, m=6, jit=0.25, what="bloc"):
    """Bloc irrégulier (scorie, charbon, roche) : sphère aplatie aux rayons tirés au sort."""
    c = V(c)
    rad = [[1.0 + jit * (g.rng.random() - 0.5) * 2 for _ in range(n)] for _ in range(m - 1)]
    vs = [(c.x, c.y, c.z - r * sz * 0.2)]
    for k in range(1, m):
        ph = -math.pi / 2 + math.pi * k / m
        for j in range(n):
            th = TAU * j / n
            rr = r * rad[k - 1][j]
            vs.append((c.x + rr * math.cos(ph) * math.cos(th), c.y + rr * math.cos(ph) * math.sin(th),
                       c.z + max(-r * sz * 0.2, rr * sz * math.sin(ph))))
    vs.append((c.x, c.y, c.z + r * sz * (1.0 + jit * (g.rng.random() - 0.5))))
    fs = []
    for j in range(n):
        fs.append((0, 1 + (j + 1) % n, 1 + j))
    for k in range(m - 2):
        for j in range(n):
            a = 1 + k * n + j
            b = 1 + k * n + (j + 1) % n
            fs.append((a, b, b + n, a + n))
    top = len(vs) - 1
    for j in range(n):
        a = 1 + (m - 2) * n + j
        b = 1 + (m - 2) * n + (j + 1) % n
        fs.append((a, b, top))
    g._add(mat, "hard", vs, fs, what)


def crystal(g, base, d, r, h, mat, tip=0.32, n=6, what="cristal"):
    """Prisme de cristal taillé (n pans) de rayon r et de longueur h le long de d, pointe pyramidale."""
    d = V(d).normalized()
    base = V(base)
    hb = h * (1 - tip)
    g.cyl(base + d * hb / 2, d, r, hb, mat, n=n, style="hard", what=what)
    g.cyl(base + d * (hb + h * tip / 2), d, r, h * tip, mat, n=n, r2=r * 0.08, style="hard", what="pointe")


def disc_wheel(g, c, axis, R, w, mat, rim_mat, spokes=6, hub_mat=None, what="volant"):
    """Volant à rayons (jante épaisse, moyeu, rayons) : se lit au zoom 1 comme un grand cercle ajouré PLEIN au
    centre (un voile mince ferme les jours entre les rayons : aucun trou enfermé)."""
    M = g.M
    a, u, w_ = basis(axv(axis))
    c = V(c)
    g.cyl(c, a, R * 0.86, w * 0.3, M["seam"], n=32, what="voile")
    g.tube_shell(c, a, R, R * 0.84, w, rim_mat, n=40, what="jante")
    for k in range(spokes):
        ang = TAU * k / spokes
        dd = u * math.cos(ang) + w_ * math.sin(ang)
        g.box(c + dd * R * 0.45, (0.035, 0.035, R * 0.8), mat, "hard", R=Rd(dd) @ Matrix.Rotation(0.0, 3, "Z"),
              what="rayon")
    g.cyl(c, a, R * 0.2, w * 1.3, hub_mat or mat, n=16, style="soft", what="moyeu")
    P4.bolts_ring(g, c + a * w * 0.66, a, R * 0.13, 6, M["rivet"], r=0.012)


def stave_barrel(g, c, r, h, mat, hoop, open_top=None, what="tonneau"):
    """Tonneau à douelles (bois) cerclé de fer ; open_top : matière du dessus (eau, charbon) ou None (fond)."""
    M = g.M
    x, y, z = c
    n = 14
    for k in range(n):
        a = TAU * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((x, y, z + h / 2)) + d * (r - 0.012), (TAU * r / n * 0.92, 0.026, h), mat if k % 3 else M["wood2"],
              "hard", R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="douelle")
    g.cyl((x, y, z + h * 0.5), "z", r - 0.02, h * 0.98, M["seam"], n=n, what="ame")
    for f in (0.18, 0.82):
        g.tube_shell((x, y, z + h * f), "z", r + 0.012, r - 0.01, 0.028, hoop, n=28, what="cercle")
    g.cyl((x, y, z + h - 0.02), "z", r - 0.02, 0.012, open_top or M["wood2"], n=n, style="flat", what="dessus")


def drum(g, c, r, h, paint, band, top=None, trefoil=False, what="fut"):
    """Fût debout de 200 L : virole peinte, 2 bourrelets de roulement, fond, 2 bondes."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + h / 2), "z", r, h, paint, n=22, what=what)
    for f in (0.33, 0.67):
        g.tube_shell((x, y, z + h * f), "z", r + 0.012, r - 0.01, 0.026, band, n=22, what="bourrelet")
    g.tube_shell((x, y, z + h - 0.008), "z", r + 0.006, r - 0.02, 0.02, M["steel_dk"], n=22, what="sertissage")
    g.cyl((x, y, z + h - 0.004), "z", r - 0.012, 0.01, top or paint, n=22, what="fond")
    g.cyl((x + r * 0.5, y + r * 0.1, z + h + 0.008), "z", 0.022, 0.018, M["brass"], n=8, what="bonde")
    g.cyl((x - r * 0.45, y - r * 0.25, z + h + 0.006), "z", 0.014, 0.014, M["steel_hi"], n=8, what="bonde")
    if trefoil:
        P4.trefoil(g, (x - r * 0.05, y + r * 0.1, z + h + 0.006), (0, 0, 1), r * 0.5)


def hazard_ring(g, c, axis, r, w, n=10, t=0.012):
    """Bague de danger jaune et noire autour d'un cylindre : n secteurs alternés (lisibles en gris)."""
    M = g.M
    a, u, w_ = basis(axv(axis))
    c = V(c)
    for k in range(n):
        ang = TAU * (k + 0.5) / n
        d = u * math.cos(ang) + w_ * math.sin(ang)
        R3 = Matrix((d.cross(a).normalized(), a, d)).transposed()
        g.box(c + d * (r + t / 2), (TAU * r / n * 1.02, w, t), M["hazy"] if k % 2 else M["hazk"], "hard", R=R3,
              what="danger")


def post_insulator(g, c, n, r, h=0.034, base=None):
    """Poteau d'isolateurs sur semelle (électricité)."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + 0.03), "z", r * 1.5, 0.06, base or M["steel_dk"], n=12, style="soft", what="semelle")
    return PT.insulators(g, (x, y, z + 0.06), n, r, h=h)


# ================================================================================================
# Époque 2 · Forge (2×2) : FOYER de briques à hotte, SOUFFLET de cuir, ENCLUME, râtelier de canons bruts
# ================================================================================================
def _bellows(g, x, yn0, yn1, w, M):
    """Soufflet de forge : planche basse sur tréteaux, plis de cuir en accordéon, planche haute inclinée (charnière
    côté tuyère, au nord), levier de bois, tuyère de fer vers le foyer."""
    y0, y1 = Y(yn0), Y(yn1)
    L = y1 - y0
    # contour en poire (large au sud, pointe au nord vers la tuyère) dans le repère (x local, y local depuis y0)
    out = [(-w / 2, 0.0), (w / 2, 0.0), (w * 0.5, L * 0.45), (w * 0.2, L * 0.92), (-w * 0.2, L * 0.92),
           (-w * 0.5, L * 0.45)]
    zl = 0.12

    def zu(yl, f):  # plan de la planche haute : 0,1 au nord (charnière), 0,3 au sud
        return zl + f * (0.07 + 0.2 * (1 - yl / L))

    def layer(f0, f1, k, mat, what):
        vs = [(x + px * k, y0 + py, zu(py, f0)) for px, py in out] + \
             [(x + px * k, y0 + py, zu(py, f1)) for px, py in out]
        n = len(out)
        fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
        for i in range(n):
            j = (i + 1) % n
            fs.append((i, j, n + j, n + i))
        g._add(mat, "soft", vs, fs, what)
    # tréteaux
    for f in (0.2, 0.7):
        for s in (-1, 1):
            g.box((x + s * w * 0.36, y0 + L * f, zl / 2 - 0.01), (0.04, 0.04, zl - 0.02), M["wood2"], "hard",
                  what="pied")
        g.box((x, y0 + L * f, zl - 0.03), (w * 0.86, 0.05, 0.03), M["wood"], "hard", what="traverse")
    # planche basse
    vs = [(x + px, y0 + py, zl - 0.03) for px, py in out] + [(x + px, y0 + py, zl) for px, py in out]
    n = len(out)
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    g._add(M["wood"], "hard", vs, fs, "planche")
    # plis de cuir (accordéon : alternance large / rentré)
    nf = 6
    for k in range(nf):
        layer(k / nf, (k + 1) / nf, 1.0 if k % 2 == 0 else 0.86, M["leather"], "pli")
    # planche haute (bois, ferrures)
    layer(1.0, 1.0, 1.0, M["wood"], "planche_haute")
    vs = [(x + px * 1.02, y0 + py, zu(py, 1.0)) for px, py in out] + \
         [(x + px * 1.02, y0 + py, zu(py, 1.0) + 0.03) for px, py in out]
    g._add(M["wood"], "hard", vs, fs, "planche_haute")
    for f in (0.18, 0.46, 0.74):
        yy = y0 + L * f
        g.box((x, yy, zu(L * f, 1.0) + 0.036), (w * (0.96 if f < 0.5 else 0.9), 0.04, 0.012), M["rawiron"], "hard",
              R=Matrix.Rotation(math.atan2(0.2, L), 3, "X"), what="ferrure")
        for s in (-1, 1):
            g.dome((x + s * w * 0.36, yy, zu(L * f, 1.0) + 0.044), (0, 0, 1), 0.015, M["rivet"])
    # levier : perche de bois du bout sud vers le haut, poignée transversale
    p0 = V((x, y0 + 0.04, zu(0.04, 1.0) + 0.03))
    p1 = V((x - 0.03, y0 - 0.08, zu(0.04, 1.0) + 0.05))
    g.cyl(p0, (1, 0, 0), 0.026, 0.06, M["rawiron"], n=10, what="charniere")
    # tuyère de fer au nord
    tip = V((x, y0 + L * 0.92, zl + 0.08))
    g.cyl(tip + V((0, 0.07, 0)), (0, 1, 0), 0.06, 0.14, M["rawiron"], n=12, r2=0.032, style="soft", what="tuyere")
    return tip + V((0, 0.14, 0))


def _hearth(g, x0, x1, yn0, yn1, h, M, E, flue=0.2):
    """Foyer de forge en briques : cornières de fer, bac à charbon rougeoyant (la nuit), hotte en tronc de pyramide
    sur 4 poteaux, conduit CARRÉ (pas de cheminée ronde : elle appartient à la vapeur)."""
    y0, y1 = Y(yn0), Y(yn1)
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, h / 2), (x1 - x0, y1 - y0, h), M["seam"], "flat", what="massif")
    B = [V((x0, y0, 0.0)), V((x1, y0, 0.0)), V((x1, y1, 0.0)), V((x0, y1, 0.0))]
    T = [V((x0, y0, h)), V((x1, y0, h)), V((x1, y1, h)), V((x0, y1, h))]
    for q in ([B[0], B[1], T[1], T[0]], [B[1], B[2], T[2], T[1]], [B[3], B[0], T[0], T[3]]):
        courses(g, q, [M["brick"], M["brick2"], M["brick"]])
    # margelle de briques posées à plat, bac à charbon au centre
    rim = 0.09
    for (a, b, c, d) in ((x0, x1, y0, y0 + rim), (x0, x1, y1 - rim, y1), (x0, x0 + rim, y0, y1), (x1 - rim, x1, y0, y1)):
        courses(g, [V((a, c, h)), V((b, c, h)), V((b, d, h)), V((a, d, h))], [M["brick2"], M["brick"]],
                bw=0.13, bh=0.065)
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, h - 0.01), (x1 - x0 - 2 * rim, y1 - y0 - 2 * rim, 0.02), M["void"], "flat",
          what="bac")
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    for i in range(9):
        a = TAU * i / 9 + 0.3
        rr = 0.06 + 0.05 * (i % 3) / 2
        lump(g, (cx + math.cos(a) * rr * 1.4, cy + math.sin(a) * rr * 1.6, h + 0.005), 0.032, M["basalt"], sz=0.7,
             n=7, m=4, what="charbon")
    for i in range(3):
        g.box((cx - 0.06 + i * 0.06, cy + (i - 1) * 0.05, h + 0.004), (0.035, 0.03, 0.01), E, "flat", what="braise")
    # cornières de fer aux arêtes verticales, ceinture boulonnée
    for (px, py) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1)):
        g.box((px, py, h / 2), (0.04, 0.04, h + 0.01), M["rawiron"], "hard", what="corniere")
    for zz in (0.07, h - 0.05):
        g.box(((x0 + x1) / 2, y0 - 0.008, zz), (x1 - x0 + 0.02, 0.016, 0.035), M["rawiron"], "hard", what="ceinture")
        for k in range(4):
            g.dome((x0 + (x1 - x0) * (k + 0.5) / 4, y0 - 0.018, zz), (0, -1, 0), 0.015, M["rivet"])
    # hotte sur 4 poteaux, conduit carré
    zh0, zh1 = h + 0.15, h + 0.32
    ins = 0.05
    for (px, py) in ((x0 + ins, y0 + ins), (x1 - ins, y0 + ins), (x1 - ins, y1 - ins), (x0 + ins, y1 - ins)):
        g.cyl((px, py, (h + zh0) / 2 + 0.005), "z", 0.018, zh0 - h + 0.01, M["blackiron"], n=8, what="poteau")
    T2 = PT.hull(g, x0 + 0.02, x1 - 0.02, y0 + 0.02, y1 - 0.02, zh0, zh1, ins=((x1 - x0) * 0.3, (y1 - y0) * 0.3,
                 (y1 - y0) * 0.3), panel=0.22, mats=[M["rawiron"], M["blackiron"]], rivet_step=0.1)
    g.box((cx, cy, zh0 + 0.015), (x1 - x0 + 0.01, y1 - y0 + 0.01, 0.03), M["blackiron"], "hard", what="rebord")
    fw = 0.13
    PT.hull(g, cx - fw / 2, cx + fw / 2, cy - fw / 2, cy + fw / 2, zh1 - 0.01, zh1 + flue, ins=(0.0, 0.0, 0.0),
            panel=0.2, mats=[M["blackiron"], M["rawiron"]], faces="tsew", rivet_step=0.1)
    for zz in (zh1 + flue * 0.45, zh1 + flue * 0.85):
        g.box((cx, cy, zz), (fw + 0.025, fw + 0.025, 0.03), M["rawiron"], "hard", what="frette")
    g.box((cx, cy, zh1 + flue + 0.01), (fw + 0.05, fw + 0.05, 0.03), M["rawiron"], "hard", what="chapeau")
    g.box((cx, cy, zh1 + flue + 0.026), (fw - 0.03, fw - 0.03, 0.006), M["soot"], "flat", what="suie")
    return (cx, y0, 0.1)


def _anvil(g, x, yn, M, k=1.0):
    """Enclume sur billot cerclé, marteau posé (k : échelle)."""
    y = Y(yn)
    g.cyl((x, y, 0.1 * k), "z", 0.15 * k, 0.2 * k, M["wood"], n=14, style="soft", what="billot")
    g.tube_shell((x, y, 0.16 * k), "z", 0.15 * k + 0.012, 0.13 * k, 0.03, M["rawiron"], n=24, what="cercle")
    z = 0.2 * k
    g.box((x, y, z + 0.03 * k), (0.2 * k, 0.15 * k, 0.06 * k), M["blackiron"], "soft", what="semelle")
    g.box((x, y, z + 0.08 * k), (0.12 * k, 0.09 * k, 0.05 * k), M["blackiron"], "soft", what="taille")
    g.box((x - 0.01 * k, y, z + 0.13 * k), (0.26 * k, 0.12 * k, 0.06 * k), M["blackiron"], "soft", what="table")
    g.box((x - 0.01 * k, y, z + 0.163 * k), (0.24 * k, 0.1 * k, 0.008), M["steel_hi"], "flat", what="face")
    g.cyl((x + 0.18 * k, y, z + 0.135 * k), (1, 0, 0), 0.05 * k, 0.14 * k, M["blackiron"], n=12, r2=0.008,
          style="soft", what="bigorne")
    g.box((x - 0.07 * k, y, z + 0.167 * k), (0.025, 0.025, 0.004), M["void"], "flat", what="trou")
    g.box((x + 0.02 * k, y - 0.02 * k, z + 0.185 * k), (0.08 * k, 0.04 * k, 0.035 * k), M["steel"], "hard",
          what="marteau")
    g.cyl((x - 0.06 * k, y - 0.09 * k, z + 0.18 * k), (-0.8, -0.6, 0.0), 0.012, 0.2 * k, M["wood"], n=6, what="manche")


def plate_rack(g, x, yn, M):
    """Râtelier en A de plaques de blindage forgées, debout (pièce haute, lisible au-dessus de la tête)."""
    y = Y(yn)
    for s in (-1, 1):
        g.box((x + s * 0.16, y + 0.04, 0.25), (0.04, 0.04, 0.5), M["wood2"], "hard", R=Matrix.Rotation(0.22, 3, "X"),
              what="montant")
    g.box((x, y - 0.1, 0.03), (0.42, 0.24, 0.06), M["wood2"], "hard", what="semelle")
    for i in range(3):
        g.box((x + 0.01 * i, y - 0.06 + i * 0.045, 0.26), (0.34 - 0.03 * i, 0.03, 0.46 - 0.04 * i),
              M["bolted"] if i % 2 else M["rawiron"], "soft", R=Matrix.Rotation(0.22, 3, "X"), what="plaque_forgee")
        for sx_ in (-1, 1):
            for zz in (0.12, 0.38):
                g.dome((x + 0.01 * i + sx_ * (0.13 - 0.015 * i), y - 0.077 + i * 0.045 + (zz - 0.26) * 0.22,
                        zz - 0.02 * i), (0, -1, 0.22), 0.015, M["rivet"])


def socle_forge(g):
    M = g.M
    E = M["emit"]
    # ouest (toujours visible, à toutes les poses) : FOYER de briques, hotte et conduit carré haut
    _hearth(g, -0.99, -0.55, -0.46, 0.34, 0.32, M, E, flue=0.36)
    # nord-ouest : soufflet de cuir, tuyère au sud dans le foyer
    g.push((-0.74, Y(0.66), 0.0), rz=math.pi)
    tip = _bellows(g, 0.0, -0.3, 0.3, 0.42, M)
    g.pop()
    # est : enclume sur billot (grande, face d'acier claire), baquet de trempe ; nord-est : râtelier de plaques
    _anvil(g, 0.76, -0.02, M, k=1.3)
    g.box((0.72, Y(-0.02) - 0.03, 0.485), (0.12, 0.05, 0.02), E, "flat", what="lingot")
    for xx in (-0.9, -0.64):
        g.box((xx, Y(-0.46) - 0.024, 0.16), (0.08, 0.01, 0.065), E, "flat", what="gueule")
        g.box((xx, Y(-0.46) - 0.03, 0.2), (0.11, 0.025, 0.02), M["rawiron"], "hard", what="linteau")
    stave_barrel(g, (0.8, Y(-0.4), 0.0), 0.14, 0.2, M["wood"], M["rawiron"], open_top=M["glass_dk"])
    g.cyl((0.76, Y(-0.4), 0.24), (0.3, 0.2, 1), 0.01, 0.16, M["rawiron"], n=6, what="tenaille")
    plate_rack(g, 0.62, 0.66, M)
    # lanterne de nuit sur le foyer
    P4.lantern(g, (0.58, Y(-0.22), 0.0), E)
    g.halo((-0.77, Y(-0.06), 0.5), M["_emit_rgb"], 10.0)
    g.halo((0.58, Y(-0.22), 0.15), M["_emit_rgb"], 6.0)


# ================================================================================================
# Époque 3 · Vapeur (2×2) : CHAUDIÈRE verticale et cheminée (style de la cheminée V0 validée), machine à vapeur à
# VOLANT, soute à charbon, bâche alimentaire, gros tuyaux de cuivre et manomètres
# ================================================================================================
def boiler(g, x, y, r, h, M, E, chim_h=0.5, chim_r=0.075):
    """Chaudière verticale rivetée (tôle brune rouillée et cerclages laiton de la cheminée V0), porte de foyer
    ambrée au sud, dôme de vapeur en cuivre, soupape, sifflet, niveau d'eau, grand manomètre, cheminée à
    collerette."""
    g.cyl((x, y, 0.04), "z", r + 0.06, 0.08, M["castiron"], n=28, style="soft", what="socle")
    P4.bolts_ring(g, (x, y, 0.08), (0, 0, 1), r + 0.035, 12, M["rivet"], r=0.014)
    zb, zt = 0.08, h
    g.cyl((x, y, (zb + zt) / 2), "z", r, zt - zb, M["armor"], n=36, what="virole")
    for f in (0.22, 0.6, 0.95):
        zz = zb + (zt - zb) * f
        g.tube_shell((x, y, zz), "z", r + 0.022, r - 0.01, 0.04, M["brass"], n=36, what="cerclage")
    nr = int(TAU * r / 0.1)
    for f in (0.41, 0.78):
        zz = zb + (zt - zb) * f
        for k in range(nr):
            a = TAU * (k + 0.5) / nr
            d = V((math.cos(a), math.sin(a), 0))
            if d.y > 0.55:
                continue
            g.dome(V((x, y, zz)) + d * (r + 0.003), d, 0.014, M["rivet"])
    # fond bombé riveté
    P2.dome_hull(g, (x, y, zt), r, r, r * 0.35, M["armor"], M, n=32, m=6, seams=8, band_mat=M["brass"],
                 rivet_step=0.1)
    # porte de foyer (sud) : cadre de fonte, 3 fentes ambrées, loquet laiton
    d = V((0.0, -1.0, 0.0))
    c = V((x, y, 0.2)) + d * (r + 0.01)
    g.box(c, (0.2, 0.03, 0.15), M["castiron"], "soft", what="porte")
    for i in range(3):
        g.box(c + V((-0.05 + i * 0.05, -0.017, 0.0)), (0.026, 0.006, 0.09), E, "flat", what="fente_foyer")
    g.box(c + V((0.11, -0.02, 0.0)), (0.03, 0.012, 0.02), M["brass"], "hard", what="loquet")
    for s in (-1, 1):
        g.cyl(c + V((s * 0.105, 0.0, 0.0)), "z", 0.014, 0.12, M["steel_dk"], n=8, what="gond")
    # grand manomètre (cadran crème lisible), niveau d'eau
    P2.gauge(g, V((x, y, h * 0.7)) + V((-0.5, -0.85, 0)).normalized() * (r + 0.02), (-0.5, -0.85, 0.25), 0.06, M)
    p = V((x, y, h * 0.55)) + V((0.6, -0.8, 0)).normalized() * (r + 0.03)
    g.cyl(p, "z", 0.016, 0.2, M["emit_soft"], n=8, what="niveau")
    for zz in (-0.11, 0.11):
        g.cyl(p + V((0, 0, zz)), "z", 0.026, 0.03, M["brass"], n=10, what="robinet")
    # dôme de vapeur en cuivre, soupape, sifflet
    dz = zt + r * 0.3
    g.cyl((x + r * 0.35, y - r * 0.2, dz), "z", r * 0.3, r * 0.3, M["copper_pol"], n=22, what="dome_vapeur")
    P2.dome_hull(g, (x + r * 0.35, y - r * 0.2, dz + r * 0.15), r * 0.3, r * 0.3, r * 0.22, M["copper_pol"], M,
                 n=22, m=5, seams=0, band_mat=M["brass"], rivet_step=0.1)
    g.cyl((x - r * 0.4, y - r * 0.25, dz + 0.04), "z", 0.02, 0.12, M["brass"], n=10, what="soupape")
    g.box((x - r * 0.4 + 0.06, y - r * 0.25, dz + 0.1), (0.12, 0.014, 0.014), M["steel_hi"], "hard", what="levier")
    g.cyl((x - r * 0.4 + 0.12, y - r * 0.25, dz + 0.08), "z", 0.022, 0.04, M["castiron"], n=8, what="contrepoids")
    # cheminée (fût riveté, 2 cerclages laiton, collerette évasée, suie)
    cx, cy = x - r * 0.05, y + r * 0.35
    z0 = zt + r * 0.25
    g.cyl((cx, cy, z0 + 0.02), "z", chim_r * 1.45, 0.05, M["castiron"], n=20, style="soft", what="embase")
    g.cyl((cx, cy, z0 + chim_h / 2), "z", chim_r, chim_h, M["armor"], n=22, r2=chim_r * 0.94, what="cheminee")
    for f in (0.35, 0.72):
        g.tube_shell((cx, cy, z0 + chim_h * f), "z", chim_r + 0.016, chim_r - 0.01, 0.028, M["brass"], n=22,
                     what="cerclage")
    g.cyl((cx, cy, z0 + chim_h + 0.03), "z", chim_r * 0.96, 0.06, M["castiron"], n=22, r2=chim_r * 1.4, caps=False,
          what="couronne")
    g.torus((cx, cy, z0 + chim_h + 0.06), "z", chim_r * 1.4, 0.014, M["castiron"], n=22, m=6, what="bourrelet")
    g.cyl((cx, cy, z0 + chim_h + 0.03), "z", chim_r * 0.9, 0.05, M["soot"], n=18, what="suie")
    return V((x, y, zt + 0.05))


def steam_engine(g, x0, x1, yn, M, E):
    """Machine à vapeur horizontale (cylindre d'est en ouest), crosse, bielle, VOLANT à rayons face au sud."""
    y = Y(yn)
    # bâti de fonte
    PT.hull(g, x0, x1, y - 0.16, y + 0.16, 0.0, 0.1, ins=(0.02, 0.02, 0.02), panel=0.24,
            mats=[M["castiron"], M["olive"]], rivet_step=0.1)
    xc = x0 + 0.14
    zc = 0.22
    g.cyl((xc, y, zc), "x", 0.1, 0.22, M["castiron"], n=22, style="soft", what="cylindre")
    for xx in (xc - 0.1, xc + 0.1):
        g.cyl((xx, y, zc), "x", 0.118, 0.03, M["brass"], n=22, style="hard", what="bride")
        P4.bolts_ring(g, (xx + (0.016 if xx > xc else -0.016), y, zc), (1 if xx > xc else -1, 0, 0), 0.105, 8,
                      M["rivet"], r=0.012)
    g.box((xc, y, zc + 0.12), (0.18, 0.12, 0.06), M["castiron"], "soft", what="boite_tiroir")
    g.cyl((xc + 0.04, y, zc + 0.17), "z", 0.02, 0.04, M["brass"], n=10, what="graisseur")
    for s in (-1, 1):
        g.box((xc + 0.1 + 0.11, y + s * 0.045, zc - 0.02), (0.22, 0.016, 0.016), M["steel_hi"], "hard",
              what="glissiere")
    g.box((xc + 0.22, y, zc), (0.05, 0.07, 0.06), M["brass"], "hard", what="crosse")
    g.cyl((xc + 0.16, y, zc), "x", 0.014, 0.12, M["steel_hi"], n=8, what="tige")
    xw = x1 - 0.05
    disc_wheel(g, (xw, y - 0.08, 0.27), (0, 1, 0), 0.25, 0.05, M["castiron"], M["castiron"], spokes=6,
               hub_mat=M["brass"])
    g.box(((xc + 0.22 + xw) / 2, y - 0.03, zc + 0.02), ((xw - xc - 0.22), 0.02, 0.022), M["steel_hi"], "hard",
          what="bielle")
    for s in (-1, 1):
        g.box((xw, y + s * 0.07 + 0.02, 0.14), (0.06, 0.04, 0.28), M["castiron"], "hard", what="palier")
    # régulateur à boules
    zb = zc + 0.16
    g.cyl((xc - 0.04, y + 0.02, zb + 0.07), "z", 0.012, 0.18, M["steel_hi"], n=8, what="axe")
    for s in (-1, 1):
        P4.sphere(g, (xc - 0.04 + s * 0.07, y + 0.02, zb + 0.08), 0.032, M["brass"], n=12, m=8, what="boule")
        g.cyl((xc - 0.04 + s * 0.035, y + 0.02, zb + 0.12), (s, 0, 0.9), 0.007, 0.09, M["steel_hi"], n=6, what="bras")


def vertical_engine(g, x, yn0, yn1, M):
    """Machine à vapeur VERTICALE (pilon) : bâti de fonte, cylindre debout sur 4 colonnes, tige et bielle vers le
    vilebrequin, GRAND VOLANT à rayons face au sud, régulateur à boules sur le cylindre."""
    y0, y1 = Y(yn0), Y(yn1)
    PT.hull(g, x - 0.19, x + 0.19, y0, y1, 0.0, 0.1, ins=(0.02, 0.02, 0.02), panel=0.26,
            mats=[M["castiron"], M["olive"]], rivet_step=0.12)
    yc = y1 - 0.2
    zc0, zc1 = 0.44, 0.68
    for sx_ in (-1, 1):
        for sy_ in (-1, 1):
            g.cyl((x + sx_ * 0.075, yc + sy_ * 0.075, (0.1 + zc0) / 2), "z", 0.02, zc0 - 0.1, M["castiron"], n=8,
                  what="colonne")
    g.cyl((x, yc, (zc0 + zc1) / 2), "z", 0.105, zc1 - zc0, M["castiron"], n=22, style="soft", what="cylindre")
    for zz in (zc0 + 0.015, zc1 - 0.015):
        g.cyl((x, yc, zz), "z", 0.125, 0.03, M["brass"], n=22, style="hard", what="bride")
        P4.bolts_ring(g, (x, yc, zz + 0.016), (0, 0, 1), 0.112, 8, M["rivet"], r=0.012)
    g.box((x + 0.12, yc, (zc0 + zc1) / 2), (0.06, 0.12, 0.18), M["castiron"], "soft", what="boite_tiroir")
    g.cyl((x, yc, zc0 - 0.08), "z", 0.014, 0.16, M["steel_hi"], n=8, what="tige")
    g.box((x, yc, zc0 - 0.16), (0.07, 0.05, 0.04), M["brass"], "hard", what="crosse")
    zk = 0.24
    yw = y0 + 0.08
    g.cyl((x, (yc + yw) / 2, zk), "y", 0.022, yc - yw + 0.06, M["steel_hi"], n=10, what="vilebrequin")
    g.box((x + 0.02, yc, (zk + zc0 - 0.16) / 2), (0.022, 0.022, zc0 - 0.16 - zk), M["steel_hi"], "hard",
          what="bielle")
    for yy in (yc - 0.05, (yc + yw) / 2):
        g.box((x, yy, (0.1 + zk) / 2 + 0.01), (0.12, 0.05, zk - 0.08), M["castiron"], "hard", what="palier")
    disc_wheel(g, (x, yw, zk + 0.02), (0, 1, 0), 0.23, 0.05, M["castiron"], M["castiron"], spokes=6,
               hub_mat=M["brass"])
    zb = zc1 + 0.02
    g.cyl((x - 0.03, yc, zb + 0.08), "z", 0.012, 0.16, M["steel_hi"], n=8, what="axe")
    for sx_ in (-1, 1):
        P4.sphere(g, (x - 0.03 + sx_ * 0.065, yc, zb + 0.09), 0.03, M["brass"], n=12, m=8, what="boule")
        g.cyl((x - 0.03 + sx_ * 0.032, yc, zb + 0.13), (sx_, 0, 0.9), 0.007, 0.08, M["steel_hi"], n=6, what="bras")
    return V((x, yc, zc1))


def socle_steam(g):
    M = g.M
    E = M["emit"]
    # est (toujours visible) : CHAUDIÈRE verticale et cheminée (style de la cheminée V0 validée)
    top = boiler(g, 0.74, Y(-0.12), 0.25, 0.58, M, E, chim_h=0.5)
    # ouest : machine à vapeur verticale, grand volant face au sud
    cyl_top = vertical_engine(g, -0.8, -0.44, 0.34, M)
    # nord-ouest : soute à charbon rivetée et pelle
    PT.hull(g, -0.98, -0.42, Y(0.46), Y(0.95), 0.0, 0.24, ins=(0.02, 0.02, 0.02), panel=0.26,
            mats=[M["castiron"], M["rawiron"]], faces="tsew", rivet_step=0.12)
    for i in range(9):
        lump(g, (-0.7 + 0.12 * math.cos(i * 2.4) * (1 + i % 2), Y(0.7) + 0.16 * math.sin(i * 2.4) * (0.6 + 0.3 * (i % 3)),
                 0.23), 0.05, M["basalt"], sz=0.7, n=7, m=4, what="charbon")
    g.cyl((-0.52, Y(0.6), 0.34), (0.2, -0.3, 1), 0.012, 0.3, M["wood"], n=6, what="pelle_manche")
    # nord-est : bâche alimentaire couchée (rivetée, verre de niveau), pompe à balancier
    P2.tank(g, (0.62, Y(0.66), 0.2), 0.15, 0.62, (1, 0, 0), M, paint=M["armor"], band=M["brass"], gauges=1)
    g.cyl((0.88, Y(0.36), 0.14), "z", 0.04, 0.28, M["castiron"], n=12, what="pompe")
    g.box((0.88, Y(0.36) - 0.06, 0.3), (0.02, 0.16, 0.02), M["steel_hi"], "hard", R=Matrix.Rotation(0.4, 3, "X"),
          what="balancier")
    # gros tuyaux de cuivre : chaudière -> cylindre (par le nord), chaudière -> colonne, bâche -> chaudière
    g.pipe([top + V((-0.1, 0.06, 0.04)), V((0.62, Y(0.2), 0.62)), V((0.42, Y(0.24), 0.5))], 0.042, M["copper_pol"],
           fl_mat=M["brass"], bolt_mat=M["rivet"])
    g.pipe([cyl_top + V((0.02, 0.0, 0.03)), V((-0.66, Y(0.2), 0.62)), V((-0.42, Y(0.24), 0.5))], 0.042,
           M["copper_pol"], fl_mat=M["brass"], bolt_mat=M["rivet"])
    P2.gauge(g, (0.6, Y(0.2) - 0.06, 0.66), (0, -0.6, 0.6), 0.06, M)
    P2.handwheel(g, (-0.62, Y(0.2), 0.7), (0, 0, 1), 0.06, M, mat=M["brass"])
    P4.link(g, 3, [(0.52, Y(-0.06), 0.24), (0.46, Y(-0.04), 0.4), (0.36, Y(0.0), 0.42)], 0.05)
    P4.link(g, 3, [(0.62, Y(0.5), 0.2), (0.7, Y(0.3), 0.32), (0.74, Y(0.12), 0.4)], 0.04)
    # échappement de la machine : tuyau calorifugé (toile cerclée de laiton) vers la colonne
    lag = [V((-0.66, Y(0.14), 0.56)), V((-0.56, Y(0.06), 0.5)), V((-0.4, Y(0.0), 0.42))]
    S_, T = g.tube(g.spline(lag, 8), 0.034, M["canvas"], n=10, what="calorifuge")
    for i in range(1, len(S_) - 1, 3):
        g.tube_shell(S_[i], T[i], 0.042, 0.03, 0.016, M["brass"], n=12, what="cerclage")
    P2.gauge(g, (-0.8, Y(-0.44) - 0.02, 0.07), (0, -1, 0.3), 0.04, M)
    P2.ladder(g, V((0.74, Y(-0.12), 0.0)) + V((1, 0.2, 0)).normalized() * 0.29, V((1, 0.2, 0)), 0.08, 0.56, 0.12, M)
    for (px_, pyn) in ((0.5, 0.3), (-0.5, 0.42)):
        g.pipe([V((px_, Y(pyn), 0.12)), V((px_ * 0.9, Y(pyn) - 0.02, 0.3)), V((px_ * 0.7, Y(pyn * 0.7), 0.4))], 0.03,
               M["copper_pol"], fl_mat=M["brass"], bolt_mat=M["rivet"])
    for (gx_, gyn, gz) in ((0.52, -0.3, 0.3), (0.92, -0.32, 0.42), (-0.62, 0.62, 0.34)):
        P2.gauge(g, (gx_, Y(gyn), gz), (0, -1, 0.4), 0.038, M)
    P2.handwheel(g, (0.5, Y(0.02), 0.5), (0, 0, 1), 0.045, M, mat=M["brass"])
    P4.lamp_group(g, (0.62, Y(-0.4) - 0.02, 0.36), (1, 0, 0), (0, -1, 0), E, n=2)
    P4.lamp_group(g, (-0.95, Y(-0.3), 0.12), (0, 1, 0), (-1, 0, 0), E, n=2)
    g.halo((0.74, Y(-0.4), 0.25), M["_emit_rgb"], 10.0)
    g.halo((0.74, Y(-0.12), 0.9), M["_emit_rgb"], 6.0)


# ================================================================================================
# Époque 4 · Pétrole (3×3) : 2 GRANDES CUVES COUCHÉES jaunes à bandes noires, passerelle, fûts, torchère, vannes
# ================================================================================================
def fuel_tank(g, x, yn0, yn1, r, M, E, ladder=True, catwalk=True):
    """Cuve couchée de carburant (nord-sud) : virole jaune délavé, bagues de danger jaune et noire, berceaux,
    passerelle et garde-corps pleins sur le dessus, échelle au sud, jauge de niveau, trou d'homme."""
    y0, y1 = Y(yn0), Y(yn1)
    L = y1 - y0
    zc = 0.1 + r
    P2.tank(g, (x, (y0 + y1) / 2, zc), r, L, (0, 1, 0), M, paint=M["yellowpaint"], band=M["galva"], gauges=1)
    for f in (-0.3, 0.05, 0.38):
        hazard_ring(g, (x, (y0 + y1) / 2 + f * L, zc), (0, 1, 0), r + 0.004, 0.09, n=14)
    if catwalk:
        g.box((x, (y0 + y1) / 2, zc + r + 0.025), (0.2, L * 0.86, 0.03), M["grate"], "hard", what="passerelle")
        for s in (-1, 1):
            g.box((x + s * 0.11, (y0 + y1) / 2, zc + r + 0.075), (0.016, L * 0.82, 0.07), M["galva"], "hard",
                  what="plinthe")
            g.hazard([V((x + s * 0.12, y0 + L * 0.1, zc + r + 0.05)), V((x + s * 0.12, y1 - L * 0.1, zc + r + 0.05)),
                      V((x + s * 0.12, y1 - L * 0.1, zc + r + 0.1)), V((x + s * 0.12, y0 + L * 0.1, zc + r + 0.1))][::s],
                     12, t=0.004)
    if ladder:
        P2.ladder(g, V((x, y0 - r * 0.6, 0.0)), V((0, -1, 0)), 0.0, zc + r + 0.03, 0.14, M)
    # jauge de niveau verticale (verre ambré) au sud-ouest, vanne à volant rouge à l'extrémité nord
    p = V((x - r * 0.75, y0 + 0.12, zc))
    g.box(p, (0.02, 0.05, r * 1.3), M["emit_soft"], "flat", what="jauge")
    for s in (-1, 1):
        g.box(p + V((-0.006, s * 0.035, 0)), (0.024, 0.016, r * 1.4), M["steel_hi"], "hard", what="cadre")
    g.cyl((x, y1 + r * 0.25 + 0.06, zc - r * 0.4), (0, 1, 0), 0.04, 0.12, M["galva"], n=12, what="piquage")
    P2.handwheel(g, (x, y1 + r * 0.25 + 0.06, zc - r * 0.4 + 0.1), (0, 0, 1), 0.07, M, mat=M["redpaint"])


def socle_petrol(g, k):
    M = g.M
    E = M["emit"]
    fuel_tank(g, -1.12, -0.7, 0.86, 0.3, M, E)
    fuel_tank(g, 1.14, -0.42, 0.36, 0.27, M, E, ladder=False)
    # sud-est (devant la 2e cuve) : fûts debout et couchés
    for i, (x, yn) in enumerate(((1.0, -0.66), (1.24, -0.62), (1.12, -0.86))):
        drum(g, (x, Y(yn), 0.0), 0.11, 0.3, M["yellowpaint"] if i != 1 else M["galva"], M["hazk"])
    # nord-ouest : groupe de pompage (moteur, 2 vannes à volant rouge)
    PT.hull(g, -1.42, -0.86, Y(1.0), Y(1.4), 0.0, 0.3, ins=(0.03, 0.03, 0.03), panel=0.24,
            mats=[M["yellowpaint"], M["steel_dk"]], rivet_step=0.12)
    g.cyl((-1.14, Y(1.2), 0.4), "x", 0.1, 0.4, M["galva"], n=20, what="moteur")
    for kk in range(6):
        g.tube_shell((-1.3 + kk * 0.06, Y(1.2), 0.4), "x", 0.118, 0.09, 0.014, M["steel_hi"], n=20, what="ailette")
    for xx in (-1.36, -0.92):
        P2.handwheel(g, (xx, Y(1.0) - 0.05, 0.36), (0, -1, 0.2), 0.075, M, mat=M["redpaint"])
    # nord : rampe de 3 conduites galvanisées sur supports, vannes rouges
    for i in range(3):
        yy = Y(1.22) + (i - 1) * 0.1
        g.cyl((0.0, yy, 0.22), "x", 0.038, 1.5, M["galva"], n=12, what="conduite")
    g.box((0.0, Y(1.22), 0.08), (1.5, 0.3, 0.16), M["steel_dk"], "hard", what="massif")
    for xx in (-0.6, 0.0, 0.6):
        g.box((xx, Y(1.22), 0.1), (0.05, 0.34, 0.2), M["steel_dk"], "hard", what="support")
    P2.handwheel(g, (0.3, Y(1.22) - 0.1, 0.32), (0, 0, 1), 0.065, M, mat=M["redpaint"])
    # liaisons galvanisées (vannes rouges)
    P4.link(g, 4, [(-0.82, Y(0.1), 0.3), (-0.8, Y(0.06), 0.46), (-0.66, Y(0.04), 0.56)], 0.06)
    P4.link(g, 4, [(0.87, Y(0.2), 0.3), (0.8, Y(0.24), 0.48), (0.66, Y(0.2), 0.56)], 0.06)
    g.hose([(1.0, Y(-0.55), 0.3), (0.9, Y(-0.4), 0.42), (0.7, Y(-0.38), 0.5)], 0.035, M["rubber"])
    P4.lamp_group(g, (-1.36, Y(1.0) - 0.02, 0.22), (1, 0, 0), (0, -1, 0), E, n=2)

    g.halo((-1.1, Y(1.0), 0.4), M["_emit_rgb"], 10.0)


# ================================================================================================
# Époque 5 · Volcan (3×3) : BUNKERS en tronc de pyramide (tungstène, gros rivets, fentes de braise), TAS DE
# SCORIES rougeoyants, évent de lave ; aucun cylindre de réservoir
# ================================================================================================
def bunker(g, x0, x1, yn0, yn1, h, M, E, ins=0.12, slits=3, spikes=2):
    T = PT.hull(g, x0, x1, Y(yn0), Y(yn1), 0.0, h, ins=(ins, ins * 0.8, ins * 1.2), panel=0.24,
                mats=[M["tungsten"], M["burnrust"], M["tungsten"]], rivet_step=0.1)
    # rivets lourds sur les arêtes du dessus
    for i in range(4):
        a, b = T[i], T[(i + 1) % 4]
        n = max(2, int((b - a).length / 0.14))
        for kk in range(n):
            g.dome(a.lerp(b, (kk + 0.5) / n) + V((0, 0, 0.032)), (0, 0, 1), 0.022, M["rivet"])
    # fentes de braise au sud (meurtrières rougeoyantes)
    y0 = Y(yn0)
    for i in range(slits):
        xx = x0 + (x1 - x0) * (i + 0.5) / slits
        yf = y0 + ins * 0.8 * 0.45 - 0.04
        g.box((xx, yf, h * 0.45), (0.12, 0.012, 0.045), E, "flat", what="braise")
        g.box((xx, yf - 0.01, h * 0.45 + 0.035), (0.15, 0.04, 0.022), M["tungsten"], "hard",
              R=Matrix.Rotation(-0.6, 3, "X"), what="visiere")
        for s_ in (-1, 1):
            g.box((xx + s_ * 0.075, yf + 0.01, h * 0.45), (0.022, 0.05, 0.07), M["burnrust"], "hard", what="joue")
    # grille de braise sur le dessus (foyer de 0,1 t² environ, barreaux sombres par-dessus)
    cx_, cy_ = (T[0].x + T[2].x) / 2, (T[0].y + T[2].y) / 2
    gw, gl = (T[1].x - T[0].x) * 0.55, (T[2].y - T[1].y) * 0.4
    g.box((cx_, cy_, h + 0.045), (gw, gl, 0.01), E, "flat", what="braise")
    for kk in range(4):
        g.box((cx_, cy_ - gl / 2 + gl * (kk + 0.5) / 4, h + 0.065), (gw + 0.04, 0.022, 0.03), M["tungsten"], "hard",
              what="barreau")
    for s_ in (-1, 1):
        g.box((cx_ + s_ * (gw / 2 + 0.03), cy_, h + 0.05), (0.05, gl + 0.06, 0.07), M["burnrust"], "hard", what="cadre")
        g.box((cx_, cy_ + s_ * (gl / 2 + 0.03), h + 0.05), (gw + 0.1, 0.05, 0.07), M["burnrust"], "hard", what="cadre")
    # pointes de basalte aux coins du dessus
    for i in range(spikes):
        p = T[(2 + i) % 4]
        g.cyl(p + V((0, 0, 0.08)), (0.25 * (1 if p.x > (x0 + x1) / 2 else -1), 0.15, 1), 0.04, 0.17, M["basalt"],
              n=5, r2=0.004, style="hard", what="pointe")
    return T


def slag_heap(g, x, yn, r, M, E, n=7):
    """Tas de scories : blocs de basalte entassés, fissures de braise courtes."""
    y = Y(yn)
    for i in range(n):
        a = TAU * i / n + 0.4
        rr = r * (0.45 + 0.25 * (i % 2))
        lump(g, (x + math.cos(a) * rr, y + math.sin(a) * rr * 1.2, 0.0), r * (0.42 - 0.04 * (i % 3)), M["basalt"],
             sz=0.5, n=9, m=5, jit=0.3, what="scorie")
    lump(g, (x, y, 0.06), r * 0.55, M["burnrust"], sz=0.6, n=10, m=6, jit=0.25, what="scorie")
    for i in range(3):
        a = TAU * i / 3 + 1.0
        g.box((x + math.cos(a) * r * 0.3, y + math.sin(a) * r * 0.35, r * 0.3), (0.09, 0.016, 0.01), E, "flat",
              R=Matrix.Rotation(a, 3, "Z"), what="fissure")


def socle_volcano(g, k):
    M = g.M
    E = M["emit"]
    # ouest et est : bunkers blindés en tronc de pyramide (plus hauts et plus longs que les cuves du pétrole)
    bunker(g, -1.5, -0.78, -0.8, 0.92, 0.56, M, E, slits=4)
    bunker(g, 0.78, 1.5, -0.66, 0.8, 0.6, M, E, slits=3)
    # bouche de lave de l'est (gueule rougeoyante au sud, sur le flanc du bunker)
    g.box((1.17, Y(-0.6) + 0.1, 0.16), (0.26, 0.02, 0.1), E, "flat", what="gueule")
    PT.hull(g, 1.0, 1.34, Y(-0.6) - 0.02, Y(-0.6) + 0.1, 0.22, 0.3, ins=(0.02, 0.0, 0.02), panel=0.2,
            mats=[M["tungsten"]], rivet_step=0.1)
    # nord : tas de scories (nord-ouest), évent pyramidal de braise (nord-est)
    slag_heap(g, -1.05, 1.15, 0.42, M, E, n=9)
    slag_heap(g, -0.35, 1.3, 0.3, M, E, n=6)
    P4.prism(g, [(0.68, Y(0.96)), (1.36, Y(0.96)), (1.36, Y(1.42)), (0.68, Y(1.42))], 0.0, 0.08, M["tungsten"])
    PT.hull(g, 0.72, 1.32, Y(1.0), Y(1.38), 0.08, 0.42, ins=(0.2, 0.16, 0.16), panel=0.22,
            mats=[M["tungsten"], M["burnrust"]], rivet_step=0.1)
    g.box((1.02, Y(1.19), 0.43), (0.16, 0.16, 0.012), E, "flat", what="event_braise")
    g.box((1.02, Y(1.19), 0.45), (0.2, 0.03, 0.02), M["tungsten"], "hard", what="grille")
    # conduits de fonte à coudes vifs (fentes de braise sur les coudes)
    P4.link(g, 5, [(-0.88, Y(0.3), 0.3), (-0.8, Y(0.3), 0.5), (-0.66, Y(0.24), 0.5)], 0.06)
    P4.link(g, 5, [(0.88, Y(0.1), 0.3), (0.8, Y(0.1), 0.5), (0.66, Y(0.08), 0.5)], 0.06)
    P4.link(g, 5, [(0.9, Y(1.18), 0.3), (0.6, Y(1.0), 0.45), (0.3, Y(0.8), 0.55)], 0.055)
    for (xx, yn) in ((-1.35, 0.95), (-1.45, 1.4), (0.75, 0.9), (1.32, 0.9)):
        g.box((xx, Y(yn), 0.12), (0.09, 0.07, 0.02), E, "flat", what="braise")
        g.box((xx, Y(yn) + 0.045, 0.13), (0.11, 0.02, 0.03), M["basalt"], "hard", what="levre")
    g.halo((-1.05, Y(1.15), 0.3), M["_emit_rgb"], 12.0)
    g.halo((1.17, Y(-0.7), 0.25), M["_emit_rgb"], 12.0)
    g.halo((1.02, Y(1.19), 0.6), M["_emit_rgb"], 8.0)


# ================================================================================================
# Époque 6 · Électricité (3×3) : 2 TOURS DE TESLA (piles d'isolateurs, tores), TRANSFORMATEUR à traversées,
# TOURET de câble de cuivre, sphère de décharge, câbles sur isolateurs
# ================================================================================================
def tesla_tower(g, x, yn, h, M, E, s=1.0):
    y = Y(yn)
    PT.hull(g, x - 0.2 * s, x + 0.2 * s, y - 0.2 * s, y + 0.2 * s, 0.0, 0.18, ins=(0.03, 0.03, 0.03), panel=0.2,
            mats=[M["olive"], M["steel_dk"]], rivet_step=0.1)
    g.box((x, y - 0.2 * s - 0.006, 0.1), (0.14, 0.012, 0.07), M["hazy"], "flat", what="haute_tension")
    n = max(4, int((h - 0.24) / 0.05))
    zt = PT.insulators(g, (x, y, 0.18), n, 0.075 * s, h=0.05)
    g.torus((x, y, zt + 0.04), "z", 0.15 * s, 0.05 * s, M["copper"], n=32, m=10, what="tore")
    g.cyl((x, y, zt + 0.04), "z", 0.15 * s, 0.06, M["steel_dk"], n=24, what="ame_tore")
    P4.sphere(g, (x, y, zt + 0.12), 0.055 * s, M["steel_hi"], n=16, m=10, what="boule")
    return zt + 0.04


def socle_electric(g, k):
    M = g.M
    E = M["emit"]
    t1 = tesla_tower(g, -1.12, 1.08, 0.86, M, E)
    # nord-est : batterie de condensateurs BASSE (une tour à cet endroit traverse le canon nord en pose E : jour enfermé)
    PT.hull(g, 0.78, 1.46, Y(0.72), Y(1.18), 0.0, 0.06, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["olive"], M["steel_dk"]], rivet_step=0.1)
    PT.capacitors(g, (1.12, Y(0.95), 0.06), 3, 2, 0.07, 0.16, E)
    for x in (-1.12,):  # arc vers une pointe de terre
        g.cyl((x - 0.18 * (1 if x > 0 else -1), Y(1.08) - 0.12, t1 - 0.12), (x, 0, 1.2), 0.008, 0.18, E, n=6,
              style="flat", what="arc")
    # ouest : transformateur (cuve à ailettes, 3 traversées isolées, bornes de cuivre)
    for (xx, yn) in ((-0.62, -1.3), (0.62, -1.3), (-0.5, -0.95), (0.5, -0.95)):
        post_insulator(g, (xx, Y(yn), 0.0), 4, 0.04, h=0.045)
    for yn in (-0.8, 0.82):
        post_insulator(g, (-1.2, Y(yn), 0.0), 5, 0.045, h=0.045)
    PT.hull(g, -1.49, -0.86, Y(-0.72), Y(0.72), 0.0, 0.58, ins=(0.02, 0.02, 0.02), panel=0.24,
            mats=[M["olive"], M["steel_dk"]], rivet_step=0.12)
    for i in range(7):  # ailettes de refroidissement sur la face sud et le dessus
        yy = Y(-0.5) + i * 0.13
        g.box((-1.18, yy, 0.6), (0.5, 0.026, 0.05), M["steel_dk"], "hard", what="ailette")
    for i, yn in enumerate((-0.35, 0.0, 0.35)):
        zt = post_insulator(g, (-1.18, Y(yn), 0.62), 7, 0.06, h=0.045)
        g.cyl((-1.18, Y(yn), zt + 0.02), "z", 0.03, 0.04, M["copper"], n=10, what="borne")
    g.box((-1.18, Y(-0.72) - 0.03, 0.3), (0.22, 0.012, 0.12), M["hazy"], "flat", what="plaque_danger")
    g.box((-1.18, Y(-0.72) - 0.036, 0.3), (0.06, 0.012, 0.08), M["hazk"], "flat", what="eclair")
    # est : touret de câble de cuivre (flasques face au sud), sur chevalet
    xr, yr, zr = 1.16, Y(0.0), 0.42
    for s in (-1, 1):
        g.cyl((xr, yr + s * 0.14, zr), (0, 1, 0), 0.4, 0.04, M["wood"], n=36, style="soft", what="flasque")
        P4.bolts_ring(g, (xr, yr + s * 0.14 - 0.024 * (s < 0), zr), (0, -1, 0), 0.3, 10, M["rivet"], r=0.013)
        g.box((xr, yr + s * 0.2, 0.21), (0.08, 0.04, 0.42), M["steel_dk"], "hard", what="chevalet")
    for kk in range(8):
        g.torus((xr, yr - 0.105 + kk * 0.03, zr), (0, 1, 0), 0.28, 0.016, M["copper"], n=32, m=6, what="spire")
    g.cyl((xr, yr - 0.16, zr), (0, 1, 0), 0.06, 0.03, M["steel_dk"], n=14, what="moyeu")
    # sud-est du touret : sphère de décharge sur poteau isolé
    zt = post_insulator(g, (0.95, Y(-0.72), 0.0), 6, 0.05, h=0.05)
    P4.sphere(g, (0.95, Y(-0.72), zt + 0.1), 0.1, M["steel_hi"], n=20, m=12, what="sphere")
    # câbles sur isolateurs, jeu de barres
    P4.link(g, 6, [(-0.9, Y(0.2), 0.4), (-0.84, Y(0.2), 0.52), (-0.66, Y(0.16), 0.58)], 0.06)
    P4.link(g, 6, [(-1.0, Y(1.0), 0.3), (-0.6, Y(0.9), 0.5), (-0.3, Y(0.7), 0.6)], 0.06)
    P4.link(g, 6, [(0.9, Y(0.7), 0.2), (0.7, Y(0.62), 0.32), (0.5, Y(0.52), 0.4)], 0.06)
    for i in range(2):
        g.box((0.82 + i * 0.07, Y(0.42), 0.36), (0.03, 0.4, 0.03), M["copper"], "hard", what="barre")
    for s in (0.82, 0.89):
        PT.insulators(g, (s, Y(0.52), 0.18), 3, 0.03, h=0.06)
    g.halo((-1.12, Y(1.08), 1.0), M["_emit_rgb"], 12.0)
    PT.hull(g, -0.62, 0.22, Y(0.92), Y(1.36), 0.0, 0.08, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["olive"], M["steel_dk"]], rivet_step=0.1)
    PT.capacitors(g, (-0.2, Y(1.14), 0.08), 4, 2, 0.065, 0.16, E)
    for (xx, yn) in ((-1.45, -0.7), (-0.95, -0.7), (1.45, 0.45), (0.85, -0.45)):
        PT.lamp(g, (xx, Y(yn), 0.06), (0, -0.3, 1), 0.03, E, cage=True)
    g.halo((1.12, Y(1.12), 0.4), M["_emit_rgb"], 10.0)
    g.halo((0.95, Y(-0.72), 0.6), M["_emit_rgb"], 8.0)


# ================================================================================================
# Époque 7 · Cristal (4×4) : 2 GRANDES GRAPPES DE CRISTAL sur socles de pierre, RÉSONATEUR de pierre à lentille,
# bassins de bronze où poussent des cristaux, guides d'onde de bronze
# ================================================================================================
def cluster(g, x, y, s, M, seed=0, plinth=True, n=6):
    """Grappe de cristaux taillés (matière cristal opaque violet sombre, cœurs lumineux étroits) sur socle de
    pierre octogonal à couronne de bronze et griffes."""
    rng = random.Random(seed)
    if plinth:
        g.cyl((x, y, 0.06), "z", 0.42 * s, 0.12, M["stone"], n=8, style="hard", phase=math.pi / 8, what="socle")
        g.tube_shell((x, y, 0.14), "z", 0.36 * s, 0.26 * s, 0.05, M["bronze"], n=8, what="couronne")
        for kk in range(8):
            a = TAU * kk / 8
            g.dome((x + math.cos(a) * 0.31 * s, y + math.sin(a) * 0.31 * s, 0.17), (0, 0, 1), 0.02, M["brass"])
    z0 = 0.14 if plinth else 0.0
    g.cyl((x, y, z0 + 0.03), "z", 0.26 * s, 0.06, M["stone"], n=8, style="hard", what="gangue")
    specs = [(0.0, 0.0, 0.95, 0.12, 0.0, 0.0)]
    for i in range(1, n):
        a = TAU * i / (n - 1) + rng.uniform(-0.3, 0.3)
        specs.append((math.cos(a) * 0.15, math.sin(a) * 0.15, rng.uniform(0.42, 0.7), rng.uniform(0.06, 0.09), a,
                      rng.uniform(0.3, 0.55)))
    for dx, dy, h, r, a, tilt in specs:
        d = V((math.cos(a) * math.sin(tilt), math.sin(a) * math.sin(tilt), math.cos(tilt)))
        base = V((x + dx * s, y + dy * s, z0 + 0.02))
        # cristaux hauts : lumière douce violette (chacun < 0,1 t², catalogue : ≤ 0,45 t²) ; les petits restent sombres
        crystal(g, base, d, r * s, h * s, M["emit_soft"] if h > 0.5 else M["crystal"])


def socle_crystal(g, k):
    M = g.M
    E = M["emit"]
    cluster(g, -1.42, Y(1.3), 1.0, M, seed=7)
    cluster(g, 1.42, Y(1.3), 0.9, M, seed=11, n=5)
    # ouest : résonateur (bloc de pierre taillée, arche de bronze, lentille-cristal couchée)
    PT.hull(g, -1.92, -1.3, Y(-0.7), Y(0.6), 0.0, 0.3, ins=(0.03, 0.03, 0.03), panel=0.28,
            mats=[M["stone"], M["stone"]], rivets=False, rivet_step=0.2)
    for s in (-1, 1):
        g.box((-1.61, Y(-0.05) + s * 0.55, 0.48), (0.08, 0.08, 0.36), M["bronze"], "hard", what="montant")
        g.dome((-1.61, Y(-0.05) + s * 0.55, 0.67), (0, 0, 1), 0.03, M["brass"])
    g.box((-1.61, Y(-0.05), 0.62), (0.1, 1.18, 0.06), M["bronze"], "hard", what="linteau")
    crystal(g, (-1.61, Y(-0.05) - 0.45, 0.46), (0, 1, 0), 0.11, 0.9, M["emit_soft"], tip=0.25, n=6)
    for s in (-1, 1):
        g.tube_shell((-1.61, Y(-0.05) + s * 0.22, 0.46), (0, 1, 0), 0.14, 0.1, 0.05, M["bronze"], n=6, what="bague")
    # est : 2 bassins octogonaux de bronze, cristaux qui y poussent
    for (yn, sd) in ((0.55, 3), (-0.45, 5)):
        g.cyl((1.55, Y(yn), 0.1), "z", 0.3, 0.2, M["bronze"], n=8, style="hard", phase=math.pi / 8, what="bassin")
        g.tube_shell((1.55, Y(yn), 0.2), "z", 0.32, 0.25, 0.04, M["brass"], n=8, what="levre")
        g.cyl((1.55, Y(yn), 0.195), "z", 0.25, 0.01, M["stone"], n=8, style="flat", what="lit")
        cluster(g, 1.55, Y(yn), 0.62, M, seed=sd, plinth=False, n=5)
    # guides d'onde de bronze vers la colonne
    P4.link(g, 7, [(-1.2, Y(1.1), 0.3), (-1.0, Y(0.9), 0.6), (-0.8, Y(0.66), 0.8)], 0.06)
    P4.link(g, 7, [(1.2, Y(1.1), 0.3), (1.0, Y(0.9), 0.6), (0.8, Y(0.66), 0.8)], 0.06)
    P4.link(g, 7, [(-1.3, Y(0.0), 0.3), (-1.2, Y(0.0), 0.6), (-1.0, Y(-0.05), 0.72)], 0.06)
    P4.link(g, 7, [(1.3, Y(0.05), 0.3), (1.22, Y(0.05), 0.6), (1.02, Y(0.05), 0.72)], 0.06)
    for i, (xx, yn) in enumerate(((-1.0, -0.95), (1.0, -0.95), (-1.6, 0.75), (1.62, 0.95), (-0.7, 1.7),
                                  (0.7, 1.7), (-1.75, -0.95), (1.25, -0.2), (-1.15, 0.7), (0.3, 1.75), (-0.55, -1.75),
                                  (0.6, -1.8), (1.85, -0.3))):
        g.cyl((xx, Y(yn), 0.06), "z", 0.06, 0.04, M["bronze"], n=6, style="hard", what="sertissure")
        crystal(g, V((xx, Y(yn), 0.07)), (0.2 * ((i % 3) - 1), 0.15, 1), 0.035, 0.16, M["emit_soft"], tip=0.4)
        for k in range(3):
            a = TAU * k / 3
            g.dome((xx + math.cos(a) * 0.05, Y(yn) + math.sin(a) * 0.05, 0.085), (0, 0, 1), 0.013, M["brass"])
    g.halo((-1.42, Y(1.3), 0.8), M["_emit_rgb"], 14.0)
    g.halo((1.42, Y(1.3), 0.8), M["_emit_rgb"], 12.0)
    g.halo((1.55, Y(0.05), 0.5), M["_emit_rgb"], 10.0)


# ================================================================================================
# Époque 8 · Marais (4×4) : 2 GRANDES CUVES DE VERRE (liquide vert, bulles, côtes de vert-de-gris), GLOBE DE VERRE
# en cage, station de pompage, gros conduits de caoutchouc annelé, bonbonnes clissées
# ================================================================================================
def glass_vat(g, x, y, r, h, M, E):
    """Cuve de verre debout : embase de vert-de-gris boulonnée, liquide visible entre 8 côtes, cerclages laiton,
    dôme de verre et couronne, bulles. Chaque panneau de liquide est un foyer de moins de 0,05 t²."""
    g.cyl((x, y, 0.05), "z", r + 0.06, 0.1, M["verdigris"], n=24, style="soft", what="embase")
    P4.bolts_ring(g, (x, y, 0.1), (0, 0, 1), r + 0.035, 12, M["brass"], r=0.014)
    zb, zt = 0.1, h
    g.cyl((x, y, (zb + zt) / 2), "z", r - 0.012, zt - zb, M["emit_soft"], n=32, what="liquide")
    nrib = 10
    for kk in range(nrib):
        a = TAU * (kk + 0.5) / nrib
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((x, y, (zb + zt) / 2)) + d * (r - 0.004), (0.035, 0.03, zt - zb), M["verdigris"], "hard",
              R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="cote")
    for f in (0.04, 0.5, 0.96):
        g.tube_shell((x, y, zb + (zt - zb) * f), "z", r + 0.02, r - 0.02, 0.04, M["brass"], n=32, what="cerclage")
    for i in range(14):
        a = -math.pi / 2 + 1.6 * ((i * 7) % 14 / 13.0 - 0.5)
        g.dome((x + math.cos(a) * r * 0.99, y + math.sin(a) * r * 0.99, zb + (zt - zb) * (0.12 + 0.055 * i)),
               (math.cos(a), math.sin(a), 0), 0.018, E, what="bulle")
    P4.sphere(g, (x, y, zt), r * 0.86, M["glass"], n=24, m=12, sz=0.55, what="dome_verre")
    g.tube_shell((x, y, zt + 0.005), "z", r + 0.01, r * 0.8, 0.03, M["verdigris"], n=28, what="couronne")
    for kk in range(4):
        a = TAU * kk / 4 + 0.4
        g.box((x + math.cos(a) * r * 0.45, y + math.sin(a) * r * 0.45, zt + r * 0.3), (0.025, 0.025, r * 0.55),
              M["verdigris"], "hard", R=Matrix.Rotation(0.0, 3, "Z"), what="arceau")
    g.cyl((x, y, zt + r * 0.5), "z", 0.05, 0.06, M["brass"], n=12, what="col")
    P2.gauge(g, (x, y - r - 0.03, zb + (zt - zb) * 0.25), (0, -1, 0.3), 0.045, M)


def socle_marsh(g, k):
    M = g.M
    E = M["emit"]
    glass_vat(g, 1.5, Y(0.55), 0.3, 0.82, M, E)
    glass_vat(g, 1.5, Y(-0.45), 0.27, 0.7, M, E)
    # nord-ouest : grand globe de verre en cage, sur pompe
    x, y = -1.42, Y(1.28)
    PT.hull(g, x - 0.34, x + 0.34, y - 0.3, y + 0.3, 0.0, 0.16, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["verdigris"], M["olive"]], rivet_step=0.1)
    rG = 0.33
    zc = 0.16 + rG * 0.95
    P4.sphere(g, (x, y, zc), rG, M["emit_soft"], n=28, m=14, what="globe")
    for kk in range(8):
        a = TAU * kk / 8
        g.box((x + math.cos(a) * (rG + 0.012), y + math.sin(a) * (rG + 0.012), zc), (0.03, 0.03, rG * 1.9),
              M["verdigris"], "hard", what="cage")
    g.torus((x, y, zc), "z", rG + 0.01, 0.022, M["brass"], n=32, m=6, what="ceinture")
    g.cyl((x, y, zc + rG + 0.03), "z", 0.07, 0.07, M["brass"], n=14, what="col")
    # ouest : station de pompage (2 corps de pompe, bonbonnes clissées)
    PT.hull(g, -1.92, -1.3, Y(-0.7), Y(0.55), 0.0, 0.36, ins=(0.03, 0.03, 0.03), panel=0.24,
            mats=[M["verdigris"], M["olive"]], rivet_step=0.12)
    for yn in (-0.35, 0.25):
        g.cyl((-1.61, Y(yn), 0.5), "z", 0.1, 0.28, M["olive"], n=18, what="pompe")
        g.cyl((-1.61, Y(yn), 0.66), "z", 0.07, 0.04, M["brass"], n=14, what="chapeau")
        P2.gauge(g, (-1.61, Y(yn) - 0.1, 0.52), (0, -1, 0.3), 0.04, M)
    for (xx, yn) in ((-1.25, -0.95), (-1.05, -1.0)):
        wicker(g, (xx, Y(yn), 0.0), 0.11, M)
    for yn in (-0.6, -0.05, 0.45):
        P2.handwheel(g, (-1.36, Y(yn), 0.42), (1, 0, 0.3), 0.05, M, mat=M["brass"])
        P2.gauge(g, (-1.8, Y(yn), 0.38), (0, 0, 1), 0.04, M)
    # gros conduits de caoutchouc annelé (pompes -> globe, cuves -> colonne), tronçons de verre lumineux
    g.hose([(-1.61, Y(0.25), 0.62), (-1.6, Y(0.8), 0.7), (-1.45, Y(1.05), 0.4)], 0.05, M["rubber"], step=0.035)
    P4.link(g, 8, [(1.2, Y(0.55), 0.4), (1.05, Y(0.5), 0.65), (0.86, Y(0.4), 0.78)], 0.07)
    P4.link(g, 8, [(1.22, Y(-0.45), 0.35), (1.05, Y(-0.4), 0.6), (0.9, Y(-0.3), 0.72)], 0.07)
    P4.link(g, 8, [(-1.3, Y(0.1), 0.3), (-1.15, Y(0.1), 0.6), (-0.96, Y(0.06), 0.74)], 0.07)
    P4.link(g, 8, [(-1.15, Y(1.1), 0.3), (-0.9, Y(0.9), 0.6), (-0.66, Y(0.66), 0.78)], 0.06)
    for (xx, yn) in ((-0.95, -0.95), (-0.75, -1.05), (0.9, -0.95), (1.05, -1.05), (-1.6, 0.75), (-1.25, 0.8),
                     (0.6, 1.7), (-0.4, 1.75), (1.15, 1.55), (1.75, 1.2), (-1.85, -0.9), (0.95, 0.95),
                     (-0.6, -1.3), (-1.0, -1.7), (1.85, -0.85), (1.8, 0.15), (-0.6, -1.85), (0.25, 1.9)):
        P4.jar(g, (xx, Y(yn), 0.04), 0.045, 0.11)
    g.halo((1.5, Y(0.05), 0.6), M["_emit_rgb"], 14.0)
    g.halo((-1.42, Y(1.28), 0.6), M["_emit_rgb"], 12.0)


def wicker(g, c, r, M):
    x, y, z = c
    g.cyl((x, y, z + r * 0.9), "z", r, r * 1.8, M["wicker"], n=16, r2=r * 0.85, what="panier")
    for f in (0.2, 0.5, 0.8):
        g.tube_shell((x, y, z + r * 1.8 * f), "z", r * (1.0 - 0.15 * f) + 0.008, r * 0.8, 0.014, M["wood2"], n=16,
                     what="cercle")
    g.cyl((x, y, z + r * 1.8 + 0.05), "z", r * 0.35, 0.1, M["emit_soft"], n=12, r2=r * 0.25, what="col")
    g.cyl((x, y, z + r * 1.8 + 0.11), "z", r * 0.28, 0.025, M["rubber"], n=10, what="bouchon")


# ================================================================================================
# Époque 9 · Atome (4×4) : TOUR DE REFROIDISSEMENT hyperboloïde, SPHÈRE plombée à hublots verts, parc de FÛTS
# plombés à trèfles, blocs de béton à bandes de danger, gaines annelées de cuivre
# ================================================================================================
def cooling_tower(g, x, y, r, h, M):
    prof = [(0.0, 1.0), (0.18, 0.86), (0.4, 0.72), (0.62, 0.68), (0.82, 0.72), (1.0, 0.8)]
    for i in range(len(prof) - 1):
        z0_, r0 = prof[i]
        z1_, r1 = prof[i + 1]
        g.cyl((x, y, h * (z0_ + z1_) / 2), "z", r * r0, h * (z1_ - z0_), M["concrete"], n=40, r2=r * r1,
              caps=(i == 0), what="tour")
    g.cyl((x, y, h - 0.01), "z", r * 0.8 - 0.02, 0.02, M["void"], n=32, style="flat", what="bouche")
    g.tube_shell((x, y, h), "z", r * 0.84, r * 0.74, 0.04, M["steel_dk"], n=40, what="levre")
    hazard_ring(g, (x, y, h * 0.14), "z", r * 0.88, 0.07, n=20)
    for zf in (0.4, 0.62):
        g.tube_shell((x, y, h * zf), "z", r * (0.73 if zf < 0.5 else 0.69) + 0.012, r * 0.6, 0.02, M["concrete"],
                     n=40, what="ceinture")
    for kk in range(12):
        a = TAU * kk / 12
        g.box((x + math.cos(a) * r * 0.98, y + math.sin(a) * r * 0.98, 0.05), (0.05, 0.05, 0.1), M["concrete"],
              "hard", R=Matrix.Rotation(a, 3, "Z"), what="pied")
    P2.ladder(g, V((x, y - r * 0.95, 0.0)), V((0, -1, 0)), 0.0, h * 0.5, 0.12, M)


def socle_atom(g, k):
    M = g.M
    E = M["emit"]
    cooling_tower(g, 1.32, Y(1.22), 0.5, 1.0, M)
    P4.sphere_tank(g, 1.55, Y(0.0), 0.36, 0.9, E, ladder_dir=(1, -0.2))
    # ouest : parc de fûts plombés à trèfles sur dalle de béton, blocs de protection
    P4.prism(g, [(-1.94, Y(-1.12)), (-1.28, Y(-1.12)), (-1.28, Y(0.62)), (-1.94, Y(0.62))], 0.0, 0.06,
             M["concrete"])
    for i, (xx, yn) in enumerate(((-1.78, -0.55), (-1.52, -0.58), (-1.78, -0.25), (-1.52, -0.28), (-1.78, 0.05),
                                  (-1.52, 0.02))):
        drum(g, (xx, Y(yn), 0.06), 0.11, 0.3, M["lead"], M["hazy"], trefoil=(i % 2 == 0))
    PT.hull(g, -1.94, -1.3, Y(0.18), Y(0.62), 0.06, 0.4, ins=(0.02, 0.02, 0.02), panel=0.3,
            mats=[M["concrete"], M["concrete"]], rivets=False)
    g.hazard([V((-1.92, Y(0.18) - 0.004, 0.1)), V((-1.32, Y(0.18) - 0.004, 0.1)), V((-1.32, Y(0.18) - 0.004, 0.2)),
              V((-1.92, Y(0.18) - 0.004, 0.2))], 8, t=0.008)
    P4.trefoil(g, (-1.62, Y(0.4), 0.405), (0, 0, 1), 0.08)
    # balises de radiation
    for (xx, yn) in ((-1.78, -0.55), (-1.52, -0.28), (-1.78, 0.05)):
        PT.lamp(g, (xx + 0.04, Y(yn) - 0.04, 0.37), (0, -0.2, 1), 0.026, E, cage=False)
    for (xx, yn) in ((-0.9, -1.3), (0.9, -1.3), (1.9, 0.6), (-0.6, -1.0), (0.6, -1.0), (1.9, -0.6),
                     (-1.9, 0.85), (0.75, 1.8), (1.9, 1.85), (-0.4, 1.85)):
        PT.lamp(g, (xx, Y(yn), 0.06), (0, -0.3, 1), 0.03, E, cage=True)
    for (xx, yn) in ((-1.9, -0.95), (0.9, 1.85)):
        g.cyl((xx, Y(yn), 0.15), "z", 0.018, 0.3, M["steel_dk"], n=8, what="poteau")
        g.cyl((xx, Y(yn), 0.32), "z", 0.04, 0.05, E, n=12, what="feu")
        g.cyl((xx, Y(yn), 0.355), "z", 0.045, 0.015, M["steel_dk"], n=12, what="chapeau")
        g.box((xx, Y(yn), 0.02), (0.1, 0.1, 0.04), M["concrete"], "hard", what="semelle")
    # gaines annelées de cuivre épaisses (réacteur vanilla)
    P4.link(g, 9, [(1.2, Y(0.0), 0.4), (1.05, Y(0.0), 0.62), (0.9, Y(-0.05), 0.76)], 0.07)
    P4.link(g, 9, [(1.0, Y(1.0), 0.3), (0.82, Y(0.86), 0.5), (0.66, Y(0.7), 0.6)], 0.07)
    P4.link(g, 9, [(-1.3, Y(-0.2), 0.3), (-1.15, Y(-0.2), 0.6), (-0.96, Y(-0.2), 0.74)], 0.07)
    g.halo((1.55, Y(0.0), 0.5), M["_emit_rgb"], 14.0)
    g.halo((-1.6, Y(-0.2), 0.5), M["_emit_rgb"], 10.0)


SOCLE = {2: lambda g, k: socle_forge(g), 3: lambda g, k: socle_steam(g), 4: socle_petrol, 5: socle_volcano,
         6: socle_electric, 7: socle_crystal, 8: socle_marsh, 9: socle_atom}


# ================================================================================================
# ARMES (une par époque, posées sur le bras de tourillon de la lignée ; repère de la tête : canons vers +Y)
# ================================================================================================
def w_forge(g, st, H, x, sx):
    """Époque 2 : UN gros canon d'acier forgé par flanc (pas de faisceau) : fût conique, frettes boulonnées, renfort
    de culasse, bourrelet de bouche, frein hydraulique sous le fût ; culasse carrée rivetée à levier."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    P4.breech(g, st, x, y0, y1, zg - hr, zg + hr, wr)
    Ld = 0.26 + hr * 0.6
    P4.drive(g, st, (x, y0 - Ld / 2 + 0.03, zg), hr * 0.78, Ld)
    L = H["L"]
    r0, r1 = 0.088, 0.066
    g.cyl((x, y1 + L / 2, zg), "y", r0, L, M["steel"], n=28, r2=r1, what="fut")
    # renfort de culasse (manchon épais à 8 boulons)
    g.tube_shell((x, y1 + 0.07, zg), "y", r0 + 0.03, r0 - 0.02, 0.14, M["rawiron"], n=28, what="renfort")
    P4.bolts_ring(g, (x, y1 + 0.145, zg), (0, 1, 0), r0 + 0.012, 8, M["brass"], r=0.015)
    # frettes boulonnées
    for f in (0.36, 0.6):
        rr = r0 + (r1 - r0) * f
        g.tube_shell((x, y1 + L * f, zg), "y", rr + 0.022, rr - 0.01, 0.045, M["rawiron"], n=28, what="frette")
        P4.bolts_ring(g, (x, y1 + L * f, zg), (0, 1, 0), rr + 0.023, 4, M["brass"], r=0.014, phase=0.785,
                      skip_down=-0.2)
    # bourrelet et couronne de bouche, âme noire, pourtour éclairé (la nuit)
    yb = y1 + L
    g.cyl((x, yb - 0.04, zg), "y", r1 + 0.04, 0.08, M["blackiron"], n=28, style="soft", what="bourrelet")
    # oreilles de bouche : en pose N, le bout du canon fait un « T » horizontal, jamais un chapeau de cheminée
    P4.ears(g, x, yb - 0.04, zg, r1 + 0.06, 0.08, r1 * 1.3, M["rawiron"], vent=False)
    g.tube_shell((x, yb + 0.004, zg), "y", r1 + 0.03, r1 - 0.025, 0.02, M["rawiron"], n=28, what="couronne")
    g.cyl((x, yb + 0.006, zg), "y", r1 - 0.026, 0.01, M["void"], n=18, style="flat", what="ame")
    P4.lit_ring(g, (x, yb + 0.016, zg), "y", r1 - 0.004, M["emit"], w=0.018)
    for k in range(4):
        a = 0.785 + TAU * k / 4
        g.bolt(V((x, yb + 0.012, zg)) + V((math.cos(a), 0, math.sin(a))) * (r1 + 0.012), (0, 1, 0), 0.012,
               M["steel_hi"])
    # frein hydraulique sous le fût (cylindre et collier avant)
    zr = zg - r0 - 0.035
    g.cyl((x, y1 + 0.2, zr), "y", 0.035, 0.38, M["blackiron"], n=14, what="frein_recul")
    g.box((x, y1 + 0.36, (zr + zg) / 2 - 0.01), (0.05, 0.04, r0 + 0.02), M["rawiron"], "hard", what="collier")
    # masque de canon : plaque de fer forgé rivetée
    PT.hull(g, x - wr * 0.75, x + wr * 0.75, y1 - 0.04, y1 + 0.06, zg - hr * 1.3, zg + hr * 1.4, ins=(0.02, 0.01, 0.03),
            panel=0.2, mats=[M["bolted"], M["rawiron"]], rivet_step=0.1)
    xo = x + sx * (wr / 2 - 0.005)
    P4.feed(g, st, H, x, sx, xo)


def w_gatling(g, st, H, x, sx):
    """Faisceau rotatif de la lignée, habillé par l'époque (jaquette, bouche, entraînement, alimentation)."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    P4.breech(g, st, x, y0, y1, zg - hr, zg + hr, wr)
    Ld = 0.26 + hr * 0.6
    P4.drive(g, st, (x, y0 - Ld / 2 + 0.03, zg), hr * 0.78, Ld)
    P4.gun_e(g, st, H, x, sx)
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M[k] for k in st["gmask"]], rivet_step=0.11)
    xo = x + sx * (wr / 2 - 0.005)
    P4.feed(g, st, H, x, sx, xo)


def w_steam(g, st, H, x, sx):
    w_gatling(g, st, H, x, sx)


def w_petrol(g, st, H, x, sx):
    """Époque 4 : gatling à jaquette galvanisée perforée, alimentée par un GROS FÛT-CHARGEUR couché le long du flanc
    extérieur (jaune délavé, bagues de danger jaune et noire, sangles, bouchon), flexible noir vers la culasse."""
    M = g.M
    st2 = dict(st, feed="none")
    w_gatling(g, st2, H, x, sx)
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    r = 0.155
    Lb = H["L"] * 0.62
    rs = H["rr"] + H["rb"] + 0.028
    c = V((x + sx * (max(wr / 2, rs + 0.03) + r + 0.005), y0 + 0.05 + Lb / 2, zg + 0.01))
    g.box(c - V((sx * r * 0.45, 0, r * 0.55)), (r * 1.7, Lb * 0.9, r * 0.95), M["steel_dk"], "hard", what="berceau")
    g.cyl(c, "y", r, Lb, M["yellowpaint"], n=28, what="fut")
    for f in (-0.5, 0.5):
        g.cyl(c + V((0, f * (Lb + 0.02), 0)), "y", r * 0.9, 0.03, M["yellowpaint"], n=28, what="fond")
        g.tube_shell(c + V((0, f * Lb, 0)), "y", r + 0.012, r - 0.01, 0.028, M["steel_dk"], n=28, what="sertissage")
    for f in (-0.22, 0.22):
        hazard_ring(g, c + V((0, f * Lb, 0)), (0, 1, 0), r + 0.002, 0.07, n=12)
    for f in (-0.38, 0.0, 0.38):
        g.tube_shell(c + V((0, f * Lb, 0)), "y", r + 0.018, r + 0.002, 0.022, M["steel_dk"], n=28, what="sangle")
    g.cyl(c + V((sx * r * 0.3, Lb / 2 + 0.03, r * 0.45)), "y", 0.026, 0.04, M["brass"], n=10, what="bouchon")
    g.box(c + V((0, 0, r + 0.025)), (0.035, Lb * 0.34, 0.025), M["steel_hi"], "hard", what="poignee")
    g.hose([c + V((-sx * r * 0.6, -Lb / 2 + 0.03, r * 0.2)), V((x + sx * wr * 0.55, y0 + 0.02, zg + 0.03)),
            V((x + sx * wr * 0.4, y0 + 0.08, zg + 0.04))], 0.03, M["rubber"], step=0.03)


def w_howitzer(g, st, H, x, sx):
    """Époque 5 : OBUSIER court et massif par flanc : une seule âme de gros calibre, manchon blindé à pans de
    tungstène, 2 cylindres de recul (dessus et dessous), frein de bouche en coin à évents de braise ; culasse à
    écailles, caisson blindé incliné."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    P4.breech(g, st, x, y0, y1, zg - hr * 1.15, zg + hr * 1.15, wr * 1.12)
    Ld = 0.26 + hr * 0.6
    P4.drive(g, st, (x, y0 - Ld / 2 + 0.03, zg), hr * 0.85, Ld)
    L = H["L"] * 0.62
    R6 = 0.19
    rb = 0.072
    Lj = L * 0.62
    g.cyl((x, y1 + Lj / 2, zg), "y", R6, Lj, M["tungsten"], n=6, style="hard", phase=math.pi / 6, what="manchon")
    for f in range(6):
        a = math.pi / 6 + TAU * f / 6 + TAU / 12
        d = V((math.cos(a), 0, math.sin(a)))
        if d.z < -0.3:
            continue
        for i in range(3):
            g.dome(V((x, y1 + Lj * (0.2 + 0.3 * i), zg)) + d * (R6 * math.cos(math.pi / 6) + 0.004), d, 0.022,
                   M["rivet"])
    for yy in (y1 + 0.03, y1 + Lj - 0.03):
        g.cyl((x, yy, zg), "y", R6 + 0.026, 0.06, M["burnrust"], n=6, style="hard", phase=math.pi / 6, what="bague")
    g.cyl((x, y1 + Lj + (L - Lj) / 2, zg), "y", rb + 0.03, L - Lj, M["gun"], n=20, what="ame")
    for s in (-1, 1):
        zr = zg + s * (R6 + 0.045)
        g.cyl((x, y1 + Lj * 0.45, zr), "y", 0.04, Lj * 0.9, M["burnrust"], n=14, what="recul")
        g.cyl((x, y1 + Lj * 0.92, zr), "y", 0.05, 0.05, M["tungsten"], n=14, what="tete_recul")
    # fentes de braise sur le dessus du manchon
    for i in range(2):
        g.box((x, y1 + Lj * (0.3 + 0.38 * i), zg + R6 * math.cos(math.pi / 6) + 0.003), (0.05, 0.1, 0.008),
              M["emit"], "flat", what="braise")
    P4.br_wedge(g, st, x, y1 + L, zg, rb + 0.06, [(x, zg)], dict(H, rb=rb))
    PT.hull(g, x - wr * 0.8, x + wr * 0.8, y1 - 0.04, y1 + 0.07, zg - hr * 1.4, zg + hr * 1.5,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["tungsten"], M["burnrust"]], rivet_step=0.1)
    xo = x + sx * (wr * 0.56 - 0.005)
    P4.feed(g, st, H, x, sx, xo)


def w_coil(g, st, H, x, sx):
    """Époque 6 : CANON-BOBINE : un tube central gainé de 5 GROSSES BOBINES de cuivre séparées par des disques
    isolateurs en céramique, bouche à anneau isolateur et 2 électrodes (arc), batterie de condensateurs."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    P4.breech(g, st, x, y0, y1, zg - hr, zg + hr, wr)
    Ld = 0.26 + hr * 0.6
    P4.drive(g, st, (x, y0 - Ld / 2 + 0.03, zg), hr * 0.78, Ld)
    L = H["L"]
    g.cyl((x, y1 + L / 2, zg), "y", 0.09, L, M["gun"], n=16, what="tube")
    g.box((x, y1 + L * 0.43, zg - 0.1), (0.14, L * 0.92, 0.16), M["steel_dk"], "hard", what="quille")
    PT.hull(g, x - 0.15, x + 0.15, y1 - 0.02, y1 + 0.1, zg - 0.15, zg + 0.15, ins=(0.02, 0.0, 0.02), panel=0.2,
            mats=[M["olive"], M["steel_dk"]], rivet_step=0.1)
    g.cyl((x, y1 + 0.02, zg), "y", 0.15, 0.04, M["steel_dk"], n=24, style="soft", what="plaque")
    nc = 5
    span = L * 0.82
    pitch = span / nc
    for i in range(nc):
        yc = y1 + 0.05 + pitch * (i + 0.5)
        lc = pitch * 0.72
        g.cyl((x, yc, zg), "y", 0.122, pitch, M["steel_dk"], n=24, what="noyau")
        nt = max(4, int(lc / 0.024))
        for t in range(nt):
            g.torus((x, yc - lc / 2 + lc * (t + 0.5) / nt, zg), "y", 0.126, 0.014, M["copper"], n=28, m=6,
                    what="spire")
        g.tube_shell((x, yc + pitch / 2, zg), "y", 0.15, 0.05, 0.026, M["accent"], n=24, what="isolateur")
    g.tube_shell((x, y1 + 0.05, zg), "y", 0.15, 0.05, 0.026, M["accent"], n=24, what="isolateur")
    # barres d'alimentation de cuivre le long des bobines (dessus)
    for s in (-1, 1):
        g.box((x + s * 0.06, y1 + 0.015 + span / 2, zg + 0.125), (0.026, span + 0.07, 0.03), M["copper"], "hard",
              what="barre")
    yb = y1 + L
    g.cyl((x, yb - 0.03, zg), "y", 0.09, 0.08, M["steel"], n=24, style="soft", what="bouche")
    g.tube_shell((x, yb - 0.075, zg), "y", 0.12, 0.05, 0.03, M["accent"], n=24, what="isolateur")
    g.cyl((x, yb + 0.012, zg), "y", 0.04, 0.008, M["void"], n=14, style="flat", what="ame")
    P4.lit_ring(g, (x, yb + 0.014, zg), "y", 0.07, M["emit"], w=0.02)
    for s in (-1, 1):
        p0 = V((x + s * 0.09, yb - 0.02, zg + 0.03))
        g.cyl(p0 + V((0, 0.05, 0)), (0, 1, 0), 0.014, 0.12, M["copper"], n=8, what="electrode")
        P4.sphere(g, p0 + V((0, 0.12, 0)), 0.022, M["copper"], n=10, m=6, what="pointe")

    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.03, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.02), panel=0.2, mats=[M[k] for k in st["gmask"]], rivet_step=0.11)
    xo = x + sx * (wr / 2 - 0.005)
    P4.feed(g, st, H, x, sx, xo)


def w_crystal(g, st, H, x, sx):
    """Époque 7 : gatling de bronze à 6 tubes, terminée par un GROS PRISME DE CRISTAL tenu par 3 griffes."""
    M = g.M
    st2 = dict(st, brake="none")
    w_gatling(g, st2, H, x, sx)
    zg = H["zg"]
    rs = H["rr"] + H["rb"] + 0.028
    yb = H["recv"][1] + H["L"]
    ro = rs + 0.03
    g.tube_shell((x, yb + 0.02, zg), "y", ro, H["rr"] * 0.3, 0.1, M["bronze"], n=28, what="couronne")
    g.tube_shell((x, yb + 0.075, zg), "y", ro + 0.012, ro - 0.025, 0.02, M["brass"], n=28, what="levre")
    pos = [(x + H["rr"] * math.cos(0.3 + TAU * i / H["nb"]), zg + H["rr"] * math.sin(0.3 + TAU * i / H["nb"]))
           for i in range(H["nb"])]
    P4.bores(g, x, yb + 0.072, zg, pos, H["rb"], M["bronze"])
    P4.lit_ring(g, (x, yb + 0.087, zg), "y", ro + 0.006, M["emit"])
    rc = 0.17
    ly = yb + 0.12
    g.cyl((x, (yb + 0.08 + ly + 0.04) / 2, zg), "y", ro - 0.02, ly + 0.04 - (yb + 0.08), M["bronze"], n=12,
          r2=rc * 0.95, what="nez")
    g.cyl((x, ly + 0.02, zg), "y", rc * 0.85, 0.06, M["stone"], n=6, style="hard", what="sertissure")
    crystal(g, V((x, ly + 0.04, zg)), (0, 1, 0), rc, 0.52, M["emit_soft"], tip=0.35, n=6, what="prisme")

    for k in range(3):
        a = math.pi / 2 + TAU * k / 3
        d = V((math.cos(a), 0, math.sin(a)))
        p0 = V((x, yb + 0.07, zg)) + d * (ro - 0.01)
        p1 = V((x, ly + 0.2, zg)) + d * (rc * 0.95)
        g.cyl((p0 + p1) / 2, p1 - p0, 0.022, (p1 - p0).length, M["bronze"], n=6, style="hard", what="griffe")
        g.dome(p1, d, 0.024, M["brass"])


def w_marsh(g, st, H, x, sx):
    """Époque 8 : gatling de vert-de-gris à buse en cloche, portant une CUVE DE VERRE couchée (liquide vert,
    côtes, fonds de laiton) reliée à la culasse par un tuyau de caoutchouc."""
    M = g.M
    w_gatling(g, st, H, x, sx)
    y0, y1 = H["recv"]
    zg, hr = H["zg"], H["hr"]
    rs = H["rr"] + H["rb"] + 0.028
    r = 0.16
    Lv = H["L"] * 0.6
    c = V((x, y1 + 0.06 + Lv / 2, zg + rs + r + 0.03))
    for f in (-0.34, 0.34):
        g.box(c + V((0, f * Lv, -r - 0.02)), (0.06, 0.05, 0.07), M["verdigris"], "hard", what="patte")
    g.cyl(c, "y", r - 0.008, Lv, M["emit_soft"], n=24, what="liquide")
    for kk in range(6):
        a = TAU * (kk + 0.5) / 6
        d = V((math.cos(a), 0, math.sin(a)))
        g.box(c + d * (r - 0.004), (0.024, Lv, 0.022), M["verdigris"], "hard",
              R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed(), what="cote")
    for f in (-0.5, 0.0, 0.5):
        g.tube_shell(c + V((0, f * Lv, 0)), "y", r + 0.018, r - 0.02, 0.035, M["brass"], n=24, what="cerclage")
    for f in (-1, 1):
        g.cyl(c + V((0, f * (Lv / 2 + 0.03), 0)), "y", r * 0.85, 0.05, M["brass"], n=24, r2=r * 0.5, what="fond")
    for i in range(7):
        g.dome(c + V((0.045 * ((i % 3) - 1), -Lv * 0.42 + i * Lv * 0.14, r - 0.01)), (0, 0, 1), 0.016, M["emit"],
               what="bulle")
    g.hose([c + V((0, -Lv / 2 - 0.05, 0)), V((x, y0 + 0.2, zg + hr + 0.12)), V((x, y0 + 0.08, zg + hr + 0.02))],
           0.03, M["rubber"], step=0.03)


def w_atom(g, st, H, x, sx):
    """Époque 9 : gatling à 6 tubes sous fourreau OCTOGONAL de plomb, 3 paquets d'AILETTES de refroidissement
    radiales (disques octogonaux), plaques de danger jaune et noire, hublot vert, frein octogonal."""
    M = g.M
    w_gatling(g, st, H, x, sx)
    y1 = H["recv"][1]
    zg = H["zg"]
    rs = H["rr"] + H["rb"] + 0.028
    R8 = rs * 1.12
    Lj = H["L"] * st.get("jacket_f", 0.62)
    for f in (0.5,):
        for t in range(int(Lj * 0.6 / 0.035)):
            yy = y1 + Lj * 0.13 + t * 0.035
            g.cyl((x, yy, zg), "y", R8 + 0.11, 0.016, M["steel_hi"] if t % 2 else M["lead"], n=8, style="hard",
                  phase=math.pi / 8, what="ailette")
    g.box((x, y1 + Lj * 0.46, zg - R8 * 0.62), (2 * (R8 + 0.09), Lj * 0.84, R8 * 0.9), M["lead"], "hard",
          what="quille")
    for s in (-1, 1):  # plaques de danger sur les flancs
        g.box((x + s * (R8 * math.cos(math.pi / 8) + 0.012), y1 + Lj * 0.84, zg), (0.008, 0.16, 0.1), M["hazy"],
              "flat", what="plaque")
        g.hazard([V((x + s * (R8 * 0.93 + 0.018), y1 + Lj * 0.84 - 0.07, zg - 0.045)),
                  V((x + s * (R8 * 0.93 + 0.018), y1 + Lj * 0.84 + 0.07, zg - 0.045)),
                  V((x + s * (R8 * 0.93 + 0.018), y1 + Lj * 0.84 + 0.07, zg + 0.045)),
                  V((x + s * (R8 * 0.93 + 0.018), y1 + Lj * 0.84 - 0.07, zg + 0.045))][::s], 5, t=0.004)


WEAPON = {2: w_forge, 3: w_steam, 4: w_petrol, 5: w_howitzer, 6: w_coil, 7: w_crystal, 8: w_marsh, 9: w_atom}
