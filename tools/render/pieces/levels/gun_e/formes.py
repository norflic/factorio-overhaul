"""FORMES COMMUNES de la mitrailleuse (lot V3-E, quatrième passe, 23/10) : aides de géométrie génériques, utilisées
par plusieurs époques. S'exécute DANS Blender. FICHIER GELÉ pour les constructeurs (une forme propre à une époque se
met dans son epNN.py ; un besoin commun se décrit dans le retour du constructeur).

Reprises MOT POUR MOT des deux plages de la passe 3 (outil de portage ; code d'origine au commit 4c57982) :
  plage basse (gun_e_bas/parts4.py, ages.py, design.py) : repères (Ry, Rz, Rd), prisme vertical, sphère, couronnes de
    rivets, anneau lumineux, oreilles de frein, rosace, trèfle, groupe de voyants, armoire, sol d'époque (deck_e),
    garde-corps, chaîne, conduit d'air, lanterne, briques, blocs, cristal, volant, tonneau, fût, bague de danger,
    poteau d'isolateurs, fentes de jupe ;
  plage haute (gun_e_haut/armes.py, ages.py, design.py) : directions radiales et repère axial (ring_dirs, Rax), échelle
    d'arme (k_arme), tubes, collier, anneau de bouche, prisme le long de y (prism_y), octogones, parabole, volumes
    balayés le long de y et de z, bouts de tubes, nappe de câbles, trappes rapportées, plinthe, fentes groupées,
    anneaux segmentés, hublots de réservoir.
Conventions : 1 unité = une tuile en X ; +Y nord (1,414 unité par tuile de jeu) ; +Z haut.
"""
import math

from mathutils import Matrix, Vector

import parts as PT
import parts2 as P2
import parts3 as P3
from kit import SQ2, TAU, axv, basis

V = Vector


# ================================================================================================
# Plage basse : parts4.py
# ================================================================================================
def Ry(d):
    """Rotation dont l'axe y local suit d."""
    a, u, w = basis(V(d))
    return Matrix((u, a, w)).transposed()


def Rz(a):
    return Matrix.Rotation(a, 3, "Z")


def prism(g, pts, z0, z1, mat, style="hard", what="prisme"):
    """Polygone convexe (x, y) extrudé de z0 à z1 (sens direct vu de dessus)."""
    n = len(pts)
    vs = [(p[0], p[1], z0) for p in pts] + [(p[0], p[1], z1) for p in pts]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    g._add(mat, style, vs, fs, what)


def sphere(g, c, r, mat, n=24, m=12, sz=1.0, style="smooth", what="sphere"):
    c = V(c)
    vs = [(c.x, c.y, c.z - r * sz)]
    for k in range(1, m):
        ph = -math.pi / 2 + math.pi * k / m
        for j in range(n):
            th = TAU * j / n
            vs.append((c.x + r * math.cos(ph) * math.cos(th), c.y + r * math.cos(ph) * math.sin(th),
                       c.z + r * sz * math.sin(ph)))
    vs.append((c.x, c.y, c.z + r * sz))
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
    g._add(mat, style, vs, fs, what)


def bolts_ring(g, c, axis, R, n, mat, r=0.016, phase=0.0, skip_down=None):
    a, u, w = basis(V(axis))
    c = V(c)
    for k in range(n):
        ang = phase + TAU * k / n
        d = u * math.cos(ang) + w * math.sin(ang)
        if skip_down is not None and d.z < skip_down:
            continue
        g.dome(c + d * R, a, r, mat)


def lit_ring(g, c, axis, r, emat, w=0.026, t=0.012):
    """Anneau lumineux (pourtour de bouche, catalogue §A.6 : ≥ 8 × 8 px hr, < 0,03 t²) : 1,5 px hr de large au
    moins, sinon il ne se voit pas (F37)."""
    g.tube_shell(c, axis, r, r - w, t, emat, n=28, what="anneau_bouche")


def ears(g, x, y, z, rx, L, h, mat, vent=True):
    """Oreilles latérales du frein de bouche (évents sur les flancs) : en pose N, elles font du bout du canon un
    « T » horizontal, jamais le chapeau rond d'une cheminée (défaut relevé par les juges)."""
    M = g.M
    for s in (-1, 1):
        g.box((x + s * rx, y, z), (0.07, L, h), mat, "hard", what="oreille")
        if vent:
            for k in range(2):
                g.box((x + s * (rx + 0.036), y - L * 0.22 + k * L * 0.44, z), (0.006, L * 0.26, h * 0.62), M["void"],
                      "flat", what="event")
        g.dome((x + s * rx, y, z + h / 2 + 0.002), (0, 0, 1), 0.015, M["rivet"])


def polyline_pts(ctrl):
    return [V(p) for p in ctrl]


def bores(g, x, y, z, pos, rb, rim_mat):
    """Rosace : bouts de tubes sombres cerclés sur la face avant d'un frein ou d'une couronne."""
    M = g.M
    for bx, bz in pos:
        g.cyl((bx, y + 0.004, bz), "y", rb * 0.66, 0.008, M["void"], n=10, style="flat", what="bouche")
        g.tube_shell((bx, y + 0.002, bz), "y", rb * 0.98, rb * 0.66, 0.012, rim_mat, n=12, what="levre")


def trefoil(g, c, nrm, r):
    """Trèfle de radioactivité (≤ 0,02 t²) : disque jaune, 3 secteurs et centre noirs."""
    M = g.M
    a, u, w = basis(V(nrm))
    c = V(c)
    g.cyl(c, a, r, 0.006, M["hazy"], n=20, style="flat", what="trefle")
    g.cyl(c + a * 0.004, a, r * 0.18, 0.004, M["hazk"], n=10, style="flat", what="trefle")
    for k in range(3):
        ang = math.pi / 2 + TAU * k / 3
        d = u * math.cos(ang) + w * math.sin(ang)
        g.cyl(c + a * 0.004 + d * r * 0.55, a, r * 0.3, 0.004, M["hazk"], n=10, style="flat", what="trefle")


def lamp_group(g, p, along, nrm, emat, n=3, sizes=(0.028, 0.02, 0.024), gaps=(0.07, 0.045)):
    M = g.M
    a, u, w = basis(V(nrm))
    t = V(along).normalized()
    p = V(p)
    off = 0.0
    for i in range(min(3, n)):
        q = p + t * off
        s = sizes[i % len(sizes)]
        if i == 1:
            Rr = Matrix((t, a.cross(t).normalized(), a)).transposed()
            g.box(q + a * 0.012, (s * 2.2, s * 1.1, 0.02), M["steel_dk"], "hard", R=Rr, what="bague")
            g.box(q + a * 0.024, (s * 1.6, s * 0.6, 0.006), emat, "flat", R=Rr, what="voyant")
        else:
            g.cyl(q + a * 0.01, a, s * 0.95, 0.02, M["steel_dk"], n=10, style="hard", what="bague")
            g.cyl(q + a * 0.022, a, s * 0.62, 0.006, emat, n=10, style="flat", what="voyant")
        off += gaps[i % len(gaps)]


def deck_mat(e):
    """Tablier bas continu : la matière du sol de la machine dit aussi l'âge (catalogue §A.6 pour le tablier ;
    habillage seulement) : planches (forge), tôles rivetées (vapeur), caillebotis galvanisé (pétrole), dalles de
    fonte (volcan), caillebotis (électricité), dalles de pierre (cristal), caillebotis de bois sur caoutchouc
    (marais), dalles de béton (atome)."""
    return {2: "wood2", 3: "rawiron", 4: "galva", 5: "castiron", 6: "tread", 7: "stone2", 8: "wood2", 9: "concrete"}[e]


def deck_e(g, e, x0, x1, y0, y1, z=0.05):
    """Tablier d'époque sur le rectangle (x0..x1, y0..y1) : jamais de jour au travers (fond plein)."""
    M = g.M
    m = M[deck_mat(e)]
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, z - 0.035), (x1 - x0, y1 - y0, 0.02), M["void"], "flat", what="fond")
    if e == 4:
        P2.grating(g, x0, x1, y0, y1, z, M, frame=False)
        if e == 4:  # lames galvanisées par-dessus le caillebotis de la lignée
            n = max(1, int((y1 - y0) / 0.17))
            for i in range(n):
                yy = y0 + (y1 - y0) * (i + 0.5) / n
                g.box(((x0 + x1) / 2, yy, z - 0.004), (x1 - x0 - 0.03, 0.03, 0.016), m, "flat", what="lame")
        return
    if e in (2, 8):  # planches (forge) ou caillebotis de bois (marais), clous, joints sombres
        pitch = 0.15 if e == 2 else 0.07
        n = max(1, int((y1 - y0) / pitch))
        for i in range(n):
            yy = y0 + (y1 - y0) * (i + 0.5) / n
            mm = (M["wood"] if (i * 7) % 3 else M["wood2"]) if e == 2 else (M["leather"] if (i * 7) % 3 else M["rubber"])
            g.box(((x0 + x1) / 2, yy, z - 0.012), (x1 - x0 - 0.02, pitch * 0.78, 0.035), mm, "hard", what="planche")
        nc = max(1, int((x1 - x0) / 0.32))
        for i in range(1, nc):
            xx = x0 + (x1 - x0) * i / nc
            g.box((xx, (y0 + y1) / 2, z + 0.008), (0.03, y1 - y0 - 0.02, 0.012),
                  M["rawiron"] if e == 2 else M["rubber"], "hard", what="traverse")
            if e == 8:  # clous de laiton à chaque croisement planche-traverse
                for j in range(n):
                    g.dome((xx, y0 + (y1 - y0) * (j + 0.5) / n, z + 0.016), (0, 0, 1), 0.012, M["brass"])
        return
    # dalles (tôle rivetée, fonte, pierre, béton) : plaques séparées par des joints sombres
    size = {3: 0.2, 5: 0.26, 6: 0.3, 7: 0.34, 9: 0.42}[e]
    nu = max(1, int(round((x1 - x0) / size)))
    nv = max(1, int(round((y1 - y0) / (size * SQ2))))
    q = [V((x0, y0, z - 0.03)), V((x1, y0, z - 0.03)), V((x1, y1, z - 0.03)), V((x0, y1, z - 0.03))]
    g.panels(q, nu, nv, m, t=0.03, gap=0.022, rivet_mat=(M["rivet"] if e in (3, 5, 6) else None), mats=[m],
             rivet_step=0.14, jitter=0.25 if e in (7, 9) else 0.1)
    if e == 5:
        # quelques joints de dalle rougeoyants (braise sous la fonte), segments courts, jamais une coulée
        for i in range(1, nu):
            for j in range(nv):
                if (i * 5 + j * 3) % 4:
                    continue
                xx = x0 + (x1 - x0) * i / nu
                yy = y0 + (y1 - y0) * (j + 0.5) / nv
                g.box((xx, yy, z - 0.026), (0.014, (y1 - y0) / nv * 0.7, 0.01), M["emit"], "flat", what="braise")


def rail(g, pts, h):
    """Garde-corps : montants et lisses fines (lignes fines, en plus de la masse)."""
    M = g.M
    P = polyline_pts(pts)
    for i in range(len(P) - 1):
        a, b = P[i], P[i + 1]
        d = b - a
        n = max(1, int(d.length / 0.2))
        for k in range(n + 1):
            q = a + d * (k / n)
            g.cyl(q + V((0, 0, h / 2)), "z", 0.01, h, M["hazy"], n=6, what="montant")
        for zz in (h, h * 0.55):
            g.cyl((a + b) / 2 + V((0, 0, zz)), d, 0.009, d.length, M["hazy"], n=6, what="lisse")


def chain(g, p0, p1, sag=0.05):
    """Chaîne de transmission (forge) : maillons alternés."""
    M = g.M
    p0, p1 = V(p0), V(p1)
    n = max(4, int((p1 - p0).length / 0.035))
    for i in range(n):
        t = (i + 0.5) / n
        p = p0.lerp(p1, t)
        p.z -= sag * 4 * t * (1 - t)
        d = (p1 - p0).normalized()
        if i % 2:
            g.torus(p, d.cross(V((0, 0, 1))), 0.016, 0.006, M["blackiron"], n=8, m=4, what="maillon")
        else:
            g.torus(p, V((0, 0, 1)), 0.016, 0.006, M["blackiron"], n=8, m=4, what="maillon")


def duct(g, pts, w, h):
    """Conduit d'air rectangulaire en tôle rivetée (forge, venu d'un soufflet)."""
    M = g.M
    P = polyline_pts(pts)
    for i in range(len(P) - 1):
        a, b = P[i], P[i + 1]
        d = b - a
        Rr = Ry(d)
        g.box((a + b) / 2, (w, d.length + w * 0.5, h), M["rawiron"], "hard", R=Rr, what="conduit")
        n = max(2, int(d.length / 0.11))
        for k in range(n):
            q = a + d * ((k + 0.5) / n)
            for s in (-1, 1):
                g.dome(q + Rr @ V((s * w * 0.38, 0, h / 2 + 0.002)), (0, 0, 1), 0.013, M["rivet"])
        g.box(b, (w + 0.03, 0.03, h + 0.03), M["blackiron"], "hard", R=Rr, what="bride")


def lantern(g, c, emat):
    """Lanterne à huile (nuit seulement) : cage de fer, verre, anse."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + 0.01), "z", 0.03, 0.02, M["rawiron"], n=10, what="pied")
    g.cyl((x, y, z + 0.05), "z", 0.022, 0.06, emat, n=10, what="verre")
    for k in range(4):
        a = TAU * k / 4 + 0.4
        g.box((x + math.cos(a) * 0.024, y + math.sin(a) * 0.024, z + 0.05), (0.008, 0.008, 0.07), M["rawiron"], "hard",
              what="cage")
    g.cyl((x, y, z + 0.09), "z", 0.028, 0.02, M["rawiron"], n=10, r2=0.012, what="chapeau")
    g.torus((x, y, z + 0.115), (1, 0, 0), 0.02, 0.005, M["rawiron"], n=10, m=4, what="anse")


def voyants_tete(g, H, n):
    """Voyants isolés de la tête (un foyer chacun, jamais en rangée ; plage basse de la passe 3, design.head_lamps) :
    n voyants pris dans l'ordre sur 18 emplacements (culasses, bras, nacelle), en alternant les côtés ; formes mêlées
    (rond, fente, rond plus petit) par paires. H : cotes de la tête (corps.Ctx.H)."""
    M = g.M
    if not n:
        return
    y0, y1 = H["recv"]
    zg, hr, wr, R = H["zg"], H["hr"], H["wr"], H["R"]
    cands = []
    for sx in (1, -1):
        x = sx * H["gx"]
        xa, xb = sorted((sx * R * 0.8, x - sx * wr / 2))
        cands += [((x + sx * wr * 0.22, y0 + (y1 - y0) * 0.72, zg + hr + 0.035), (0, 0, 1)),
                  (((xa + xb) / 2, y0 + 0.2, zg + hr * 0.55 + 0.01), (0, 0, 1)),
                  ((x - sx * wr * 0.3, y1 + 0.02, zg + hr * 1.35 + 0.01), (0, 0.3, 1)),
                  ((x + sx * wr * 0.2, y0 + (y1 - y0) * 0.3, zg + hr + 0.035), (0, 0, 1)),
                  ((x, y0 - 0.06, zg + hr * 0.8), (0, -0.5, 1)),
                  (((xa + xb) / 2 + sx * 0.06, y1 - 0.2, zg + hr * 0.55 + 0.01), (0, 0, 1)),
                  ((sx * R * 0.5, -R - 0.2, H["zs"] + H["rz"] * 0.42 + 0.005), (0, 0, 1)),
                  ((x - sx * wr * 0.32, y0 + (y1 - y0) * 0.5, zg + hr + 0.035), (0, 0, 1)),
                  ((sx * R * 0.55, -R * 0.85, H["zs"] + H["rz"] * 0.42 + 0.005), (0, 0, 1))]
    # ordre : on alterne les côtés pour rester symétrique
    h = len(cands) // 2
    order = [c for pair in zip(cands[:h], cands[h:]) for c in pair]
    for k, (p, nrm) in enumerate(order[:n]):
        shape = k // 2 % 3
        if shape == 1:
            lamp_group(g, p, (1, 0, 0), nrm, M["emit"], n=1, sizes=(0.046,))
        else:
            PT.lamp(g, p, nrm, 0.03 if shape == 0 else 0.026, M["emit"], cage=False)


# ================================================================================================
# Plage basse : ages.py (aides de forme)
# ================================================================================================
def Rd(d):
    """Repère dont l'axe z local suit d (pour poser des boîtes le long d'une direction)."""
    a, u, w = basis(V(d))
    return Matrix((u, w, a)).transposed()


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
    bolts_ring(g, c + a * w * 0.66, a, R * 0.13, 6, M["rivet"], r=0.012)


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
        globals()["trefoil"](g, (x - r * 0.05, y + r * 0.1, z + h + 0.006), (0, 0, 1), r * 0.5)


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
# Plage basse : design.py (fentes lumineuses de jupe à visière)
# ================================================================================================
def slits(g, R, z, n, emat, a0=math.pi / 2 + 0.8, span=TAU - 1.6):
    for k in range(n):
        a = a0 + span * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0.0))
        t = V((-math.sin(a), math.cos(a), 0.0))
        R3 = Matrix((t, d, V((0, 0, 1)))).transposed()
        g.box(d * (R + 0.045) + V((0, 0, z)), (0.1, 0.012, 0.03), emat, "flat", R=R3, what="fente")
        g.box(d * (R + 0.05) + V((0, 0, z + 0.032)), (0.13, 0.022, 0.02), g.M["steel_dk"], "hard", R=R3,
              what="visiere")


# ================================================================================================
# Plage haute : armes.py (outils communs des armes)
# ================================================================================================
def ring_dirs(n, phase=0.0, skip_down=-0.55):
    """Directions radiales autour de l'axe y (dans le plan xz), sans celles qui pointent vers le sol."""
    out = []
    for k in range(n):
        a = phase + TAU * k / n
        d = V((math.cos(a), 0.0, math.sin(a)))
        if d.z < skip_down:
            continue
        out.append(d)
    return out


def Rax(d):
    """Repère (x = tangente, y = axe du canon, z = radiale d)."""
    y = V((0, 1, 0))
    return Matrix((y.cross(d).normalized(), y, d)).transposed()


def k_arme(rb, rr):
    """Échelle de l'arme par rapport au canon de flanc de l'ère IV (rr + rb = 0,205)."""
    return (rr + rb) / 0.205


def tubes(g, x, y0, z, L, nb, rb, rr, phase=0.3, core=True):
    M = g.M
    for i in range(nb):
        a = phase + TAU * i / nb
        bx, bz = x + rr * math.cos(a), z + rr * math.sin(a)
        g.cyl((bx, y0 + L / 2, bz), "y", rb, L, M["gun"], n=10, what="canon")
        g.cyl((bx, y0 + L + 0.003, bz), "y", rb * 0.62, 0.008, M["void"], n=8, style="flat", what="bouche")
    if core:
        g.cyl((x, y0 + L * 0.5, z), "y", max(rr * 0.42, rr - rb * 0.7), L * 0.97, M["steel_dk"], n=12, what="axe")


def collar(g, x, yy, z, ro, ri, w, mat, nriv=6):
    M = g.M
    g.tube_shell((x, yy, z), "y", ro, ri, w, mat, n=28, what="collier")
    for d in ring_dirs(nriv, 0.2, -0.3):
        g.dome(V((x, yy, z)) + d * (ro + 0.002), d, 0.015, M["rivet"])


def muzzle_glow(g, x, y, z, r, mat=None):
    """Anneau lumineux fin autour de la bouche (couleur d'époque, < 0,03 t²)."""
    g.tube_shell((x, y, z), "y", r, r * 0.78, 0.012, mat or g.M["emit"], n=28, what="bouche_lum")


def prism_y(g, x, z, ya, yb, poly, mat, style="hard", what="carenage"):
    """Prisme le long de y, de section `poly` (liste de (u, w) en x, z autour de (x, z))."""
    n = len(poly)
    vs = [(x + u, ya, z + w) for u, w in poly] + [(x + u, yb, z + w) for u, w in poly]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    g._add(mat, style, vs, fs, what)


def oct8(hw, hh, c):
    return [(-hw + c, -hh), (hw - c, -hh), (hw, -hh + c), (hw, hh - c), (hw - c, hh), (-hw + c, hh), (-hw, hh - c),
            (-hw, -hh + c)]


def scale_poly(poly, s):
    return [(u * s, w * s) for u, w in poly]


def dish(g, c, r, depth, mat_in, mat_out, rx=0.0, rz=0.0, horn=True):
    """Parabole (coupelle, dos, lèvre, 3 haubans, cornet) ; axe local +z tourné de rx puis rz."""
    M = g.M
    g.push(c, rz=rz, rx=rx)
    n = 24
    vs, fs = [], []
    for i in range(5):
        rr = r * i / 4
        for j in range(n):
            a = TAU * j / n
            vs.append((rr * math.cos(a), rr * math.sin(a), depth * (rr / r) ** 2))
    for i in range(4):
        for j in range(n):
            j2 = (j + 1) % n
            fs.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
    g._add(mat_in, "flat", vs, fs, "coupelle")
    g._add(mat_out, "smooth", [(v[0], v[1], v[2] - 0.016) for v in vs], [f[::-1] for f in fs], "coupelle_dos")
    g.torus((0, 0, depth), "z", r, 0.012, M["steel_dk"], n=32, m=6, what="levre")
    if horn:
        g.cyl((0, 0, depth + r * 0.4), "z", max(0.012, r * 0.05), r * 0.8, M["steel_dk"], n=8, what="tige")
        g.cyl((0, 0, depth + r * 0.75), "z", r * 0.13, r * 0.25, M["steel_dk"], n=10, what="cornet")
    g.pop()


def loft(g, x, z, secs, mat, style="hard", what="carenage"):
    """Volume balayé le long de y : secs = [(y, poly)] (même nombre de sommets), bouts fermés."""
    n = len(secs[0][1])
    vs = []
    for y, poly in secs:
        vs += [(x + u, y, z + w) for u, w in poly]
    fs = [tuple(range(n))[::-1]]
    m = len(secs)
    for s in range(m - 1):
        for i in range(n):
            j = (i + 1) % n
            fs.append((s * n + i, s * n + j, (s + 1) * n + j, (s + 1) * n + i))
    fs.append(tuple(range((m - 1) * n, m * n)))
    g._add(mat, style, vs, fs, what)


def stub_tips(g, x, ya, yb, z, nb, rb, rr, phase=0.3):
    """Bouts de tubes (rosace de bouche) entre ya et yb, âme pleine."""
    M = g.M
    for i in range(nb):
        a = phase + TAU * i / nb
        bx, bz = x + rr * math.cos(a), z + rr * math.sin(a)
        g.cyl((bx, (ya + yb) / 2, bz), "y", rb, yb - ya, M["gun"], n=10, what="canon")
        g.cyl((bx, yb + 0.003, bz), "y", rb * 0.62, 0.008, M["void"], n=8, style="flat", what="bouche")
    g.cyl((x, (ya + yb) / 2, z), "y", max(rr * 0.42, rr - rb * 0.7), (yb - ya) * 0.97, M["steel_dk"], n=12,
          what="axe")


def ribbon(g, ctrl, w, mat, step=0.03, t=0.008):
    """Nappe de câbles plate (haute technologie) le long d'une courbe."""
    P = g.resample(g.spline(ctrl, 12), step)
    T, _ = g.frames(P)
    for i, p in enumerate(P):
        tt = T[i]
        side = tt.cross(V((0, 0, 1)))
        if side.length < 1e-3:
            side = V((1, 0, 0))
        side.normalize()
        up = side.cross(tt).normalized()
        g.box(p, (w, step * 1.05, t), mat, "flat", R=Matrix((side, tt, up)).transposed(), what="nappe")


# ================================================================================================
# Plage haute : ages.py (aides de forme des grands volumes)
# ================================================================================================
def octz(hx, hy, c):
    """Octogone dans le plan xy (section horizontale d'un caisson chanfreiné)."""
    return [(-hx + c, -hy), (hx - c, -hy), (hx, -hy + c), (hx, hy - c), (hx - c, hy), (-hx + c, hy), (-hx, hy - c),
            (-hx, -hy + c)]


def loft_z(g, cx, cy, secs, mat, style="soft", what="carenage"):
    """Volume balayé le long de z : secs = [(z, poly xy)] (même nombre de sommets), bouts fermés."""
    n = len(secs[0][1])
    vs = []
    for z, poly in secs:
        vs += [(cx + u, cy + w, z) for u, w in poly]
    fs = [tuple(range(n))[::-1]]
    m = len(secs)
    for s in range(m - 1):
        for i in range(n):
            j = (i + 1) % n
            fs.append((s * n + i, s * n + j, (s + 1) * n + j, (s + 1) * n + i))
    fs.append(tuple(range((m - 1) * n, m * n)))
    g._add(mat, style, vs, fs, what)


def hatches(g, p0, p1, n, nrm, mat, size=(0.09, 0.07), t=0.014, frame=None):
    """Petites trappes rapportées (pièces lisibles au zoom 2, 4 à 60 px) le long d'un segment, sur une face de
    normale nrm ; cadre sombre facultatif."""
    M = g.M
    p0, p1 = V(p0), V(p1)
    a = V(nrm).normalized()
    al = (p1 - p0).normalized()
    Rr = Matrix((al, a.cross(al).normalized(), a)).transposed()
    for i in range(n):
        q = p0.lerp(p1, (i + 0.5) / n)
        if frame is not None:
            g.box(q + a * (t * 0.5), (size[0] + 0.03, size[1] + 0.03, t), frame, "hard", R=Rr, what="cadre_trappe")
        g.box(q + a * (t * 1.2), (size[0], size[1], t), mat, "hard", R=Rr, what="trappe")


def plinth(g, x0, x1, y0, y1, h):
    M = g.M
    PT.hull(g, x0, x1, y0, y1, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.3, mats=[M["steel_dk"], M["olive"]],
            rivet_step=0.12)


# ================================================================================================
# Plage haute : design.py (foyers groupés, anneaux segmentés, hublots de réservoir)
# ================================================================================================
def slits_grouped(g, R, z, groups, emat, a0=0.0, span=TAU, per=(2, 3), visor=True):
    """Fentes lumineuses autour d'un fût, PAR GROUPES de 2 ou 3 (écarts irréguliers), jamais en rangée continue."""
    k = 0
    for gi in range(groups):
        n = per[gi % len(per)]
        ac = a0 + span * (gi + 0.5) / groups
        for j in range(n):
            a = ac + (j - (n - 1) / 2) * 0.085 * (1.0 + 0.25 * (j % 2)) * 1.3 / max(1.0, R)
            d = V((math.cos(a), math.sin(a), 0.0))
            t = V((-math.sin(a), math.cos(a), 0.0))
            R3 = Matrix((t, d, V((0, 0, 1)))).transposed()
            w = 0.1 if (j + gi) % 3 else 0.06
            g.box(d * (R + 0.045) + V((0, 0, z)), (w, 0.012, 0.035), emat, "flat", R=R3, what="fente")
            if visor:
                g.box(d * (R + 0.05) + V((0, 0, z + 0.035)), (w + 0.03, 0.022, 0.02), g.M["steel_hi"], "hard", R=R3,
                      what="visiere")
            k += 1
    return k


def seg_ring(g, x, y, R, z, n, emat):
    """Anneau lumineux SEGMENTÉ (n segments courts ≤ 0,03 t², pattes sombres entre eux)."""
    for k in range(n):
        a = TAU * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0))
        Rr = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
        if d.y > 0.7:
            continue
        g.box(V((x, y, z)) + d * R, (TAU * R / n * 0.8, 0.014, 0.03), emat, "flat", R=Rr, what="segment")
        a2 = TAU * k / n
        d2 = V((math.cos(a2), math.sin(a2), 0))
        Rr2 = Matrix((V((-d2.y, d2.x, 0)), d2, V((0, 0, 1)))).transposed()
        g.box(V((x, y, z)) + d2 * (R - 0.004), (0.035, 0.03, 0.05), g.M["steel_dk"], "hard", R=Rr2, what="patte")


def seg_ring_y(g, x, y, z, R, n, emat):
    for k in range(n):
        a = TAU * (k + 0.5) / n + 0.3
        d = V((math.cos(a), 0, math.sin(a)))
        if d.z < -0.5:
            continue
        g.box(V((x, y, z)) + d * R, (0.06, 0.008, 0.02), emat, "flat",
              R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed() @ Matrix.Rotation(math.pi / 2, 3, "X"),
              what="segment")


def tank_lights(g, x, y, r, h, e):
    """Petits foyers d'un réservoir (hublots ou fentes) : groupe de 2 à 3, côté sud."""
    M = g.M
    for k, a in enumerate((-1.25, -1.6, -2.15)):
        d = V((math.cos(a), math.sin(a), 0))
        p = V((x, y, h * (0.32 + 0.1 * (k % 2))))
        g.cyl(p + d * (r + 0.01), d, 0.034, 0.03, M["steel_dk"], n=12, what="hublot")
        g.cyl(p + d * (r + 0.027), d, 0.022, 0.006, M["emit"], n=12, style="flat", what="hublot_lum")
