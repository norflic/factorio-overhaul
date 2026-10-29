"""LA FUSÉE DE DÉPART (lot CENTRE-FUSEE, 29/10, premier jet de concept). S'exécute DANS Blender (mathutils).

Une seule fusée, des états : `fusee(g, e, side)` dessine, selon l'âge e :
  e = 0   l'ÉPAVE : la fusée couchée dans son cratère, étage haut éventré, ogive arrachée, une ailette perdue ;
  e >= 1  la fusée RÉPARÉE, DEBOUT sur son aire (la silhouette ne change plus), puis AMÉLIORÉE : la coque, les bandes,
          les ailettes, les tuyères et le nez prennent la matière de l'âge ; les modules de l'âge se posent AUTOUR
          (échafaudage, portique, cuves, serre, disque), jamais à la place de la fusée.
Repère : x est, y nord, z haut, unités Blender vraies (un cercle est un cercle ; 1 tuile de jeu vers le sud = 1,414 en
y, d'où `ty`). Origine : le pied de l'entité, au sol. La caméra regarde du sud, la porte de la fusée est au sud.
Silhouette fixe (tous âges) : tuyères (3) sous un jupon, coque basse, anneau d'inter-étage, coque haute, ogive et
antenne ; 4 ailettes en diagonale (2 visibles à l'avant) posées sur 4 pieds ; porte éclairée au sud ; hublots au sud.
"""
import math

from mathutils import Matrix, Vector

from kit import SQ2, TAU

V = Vector


def ty(t):
    """Tuiles de jeu vers le nord -> unités Blender en y."""
    return t * SQ2


def pol(r, a, z=0.0):
    return (r * math.cos(a), r * math.sin(a), z)


def poutre(g, p0, p1, w, m, what="poutre", h=None):
    p0, p1 = V(p0), V(p1)
    d = p1 - p0
    if d.length < 1e-6:
        return
    d.normalize()
    u = d.cross(V((0, 0, 1)))
    if u.length < 1e-4:
        u = V((1, 0, 0))
    u.normalize()
    w2 = d.cross(u).normalized()
    a, b = w / 2.0, (h if h is not None else w) / 2.0
    cs = [(-a, -b), (a, -b), (a, b), (-a, b)]
    pts = [p0 + u * x + w2 * y for x, y in cs] + [p1 + u * x + w2 * y for x, y in cs]
    g.hexa(pts, m, "hard", what)


def tang(g, r, a, z, w, h, t, m, what="plaque"):
    """Plaque tangente à une coque de rayon r, à l'angle a : w large (tangent), h haut, t épaisse (radial)."""
    R = Matrix.Rotation(a - math.pi / 2, 3, "Z")
    g.box(pol(r, a, z), (w, t, h), m, "hard", R=R, what=what)


def mk(M, *cles):
    """Première matière existante de la liste (retombée sur « armor »)."""
    for c in cles:
        if c in M:
            return M[c]
    return M["armor"]


# ------------------------------------------------------------------------------------------------
# Palettes des états : clés de matières du kit commun (ages.py)
# ------------------------------------------------------------------------------------------------
PAL = {
    0: dict(bas=("burnrust", "soot"), haut=("hazy",), bande=("hazk",), aile=("hazy",), tuy=("armor2",),
            nez=("hazy",), os=("rawiron",), rivet=("rivet",), pad=("concrete",), pad2=("armor2",), acc=("redpaint",)),
    1: dict(bas=("hazy",), haut=("hazy",), bande=("armor2",), aile=("redpaint",), tuy=("rawiron",), nez=("redpaint",),
            os=("wood",), rivet=("rivet",), pad=("wood2",), pad2=("wood",), acc=("redpaint",)),
    4: dict(bas=("jaune_capot",), haut=("jaune_capot",), bande=("noir_capot",), aile=("noir_capot",), tuy=("galva",),
            nez=("noir_capot",), os=("steel_dk",), rivet=("rivet",), pad=("tole_larmee",), pad2=("noir_capot",),
            acc=("redpaint",)),
    8: dict(bas=("vdg_capot",), haut=("vdg_capot",), bande=("cuivre_terni",), aile=("cuivre_terni",),
            tuy=("cuivre_terni",), nez=("vdg_capot",), os=("bois_mouille",), rivet=("rivet",), pad=("bois_mouille",),
            pad2=("bois_mousse",), acc=("cuivre_terni",)),
    15: dict(bas=("noir_chaud",), haut=("noir_chaud",), bande=("or_chauffe",), aile=("noir_chaud2",),
             tuy=("or_chauffe",), nez=("noir_profond",), os=("or_chauffe",), rivet=("or_rivet",), pad=("noir_chaud",),
             pad2=("noir_chaud2",), acc=("or_vif",)),
}


KS = 1.15   # échelle de la fusée et de ses modules (l'aire garde l'emprise : elle est dessinée à side / KS)
RISE = {0: 0.0, 1: 0.07, 4: 0.11, 8: 0.64, 15: 0.13}   # cote du pied de la fusée au-dessus du sol (dessus de l'aire)


class Ctx:
    def __init__(self, g, e, side):
        self.g, self.M, self.e, self.side = g, g.M, e, side
        self.rise = RISE.get(e, 0.1)
        pal = PAL.get(e) or PAL[min(PAL, key=lambda k: abs(k - e) if k else 99)]
        self.P = {k: mk(g.M, *v) for k, v in pal.items()}
        self.rng = g.rng

    def __getitem__(self, k):
        return self.P[k]


# ------------------------------------------------------------------------------------------------
# La fusée elle-même
# ------------------------------------------------------------------------------------------------
Z_JUPON = (0.86, 1.34)
Z_BAS = (1.34, 3.36)
Z_INTER = (3.36, 3.56)
Z_HAUT = (3.56, 4.58)
R_BAS, R_HAUT = 0.74, 0.66


def tuyeres(c, ruine=False):
    g, M = c.g, c.M
    for k, a in enumerate((math.radians(270), math.radians(30), math.radians(150))):
        if ruine and k == 1:
            continue
        x, y, _ = pol(0.36, a)
        g.cyl((x, y, 0.58), "z", 0.36, 0.62, c["tuy"], n=20, r2=0.2, style="smooth", what="tuyere")
        g.tube_shell((x, y, 0.27), "z", 0.375, 0.3, 0.07, c["bande"], n=20, what="levre_tuyere")
        g.cyl((x, y, 0.3), "z", 0.3, 0.03, M["void"], n=20, style="flat", what="gorge")
    g.cyl((0, 0, 1.1), "z", 0.62, 0.5, c["bande"], n=28, r2=0.7, style="smooth", what="jupon")
    g.tube_shell((0, 0, 0.9), "z", 0.66, 0.5, 0.06, M["steel_dk"], n=28, what="collier_jupon")


def coque(c, ruine=False):
    g, M = c.g, c.M
    # coque basse
    g.cyl((0, 0, sum(Z_BAS) / 2), "z", R_BAS, Z_BAS[1] - Z_BAS[0], c["bas"], n=36, style="smooth", what="coque_basse")
    # anneau d'inter-étage
    g.cyl((0, 0, sum(Z_INTER) / 2), "z", R_BAS + 0.03, Z_INTER[1] - Z_INTER[0], c["bande"], n=36, r2=R_HAUT + 0.03,
          style="smooth", what="anneau_inter")
    for z in (Z_INTER[0], Z_INTER[1]):
        g.torus((0, 0, z), "z", R_BAS + 0.03 if z == Z_INTER[0] else R_HAUT + 0.03, 0.022, M["steel_dk"], n=36, m=6,
                what="cordon")
    # joints de panneaux (anneaux sombres) et bande de danger
    for z in (1.95, 2.55):
        g.torus((0, 0, z), "z", R_BAS + 0.003, 0.012, M["seam"], n=36, m=5, what="joint_h")
    if not ruine:
        # joints verticaux
        for k in range(10):
            a = TAU * k / 10 + 0.15
            tang(g, R_BAS, a, (Z_BAS[0] + Z_BAS[1]) / 2, 0.016, Z_BAS[1] - Z_BAS[0] - 0.1, 0.012, M["seam"], "joint_v")
    # bande de danger sous l'inter-étage
    n = 22
    for k in range(n):
        a = TAU * k / n
        tang(g, R_BAS + 0.01, a, 3.12, TAU * R_BAS / n * 1.02, 0.2, 0.025, M["hazy"] if k % 2 else M["hazk"], "danger")
    # rivets : deux rangées
    for z in (1.5, 3.25):
        for k in range(30):
            a = TAU * (k + 0.5) / 30
            x, y, _ = pol(R_BAS + 0.005, a)
            g.dome((x, y, z), (math.cos(a), math.sin(a), 0), 0.02, c["rivet"], n=6)
    # coque haute
    if ruine:
        zt = 4.14
        g.cyl((0, 0, (Z_HAUT[0] + zt) / 2), "z", R_HAUT, zt - Z_HAUT[0], c["haut"], n=36, r2=R_HAUT, style="smooth",
              what="coque_haute_cassee")
        # bord déchiqueté : dents de tôle arrachées
        for k in range(16):
            a = TAU * k / 16 + 0.1
            hh = 0.12 + 0.38 * c.rng.random()
            tang(g, R_HAUT + 0.01, a, zt + hh / 2 - 0.03, TAU * R_HAUT / 16 * 0.8, hh, 0.035, c["haut"], "dent")
        # intérieur éventré : fond noir, nervures
        g.cyl((0, 0, zt + 0.01), "z", R_HAUT - 0.03, 0.02, M["void"], n=32, style="flat", what="vide")
        for z in (3.75, 4.0):
            g.tube_shell((0, 0, z), "z", R_HAUT - 0.005, R_HAUT - 0.05, 0.035, c["os"], n=32, what="nervure")
        for k in range(5):
            a = TAU * k / 5 + 0.4
            poutre(g, pol(R_HAUT - 0.03, a, Z_HAUT[0]), pol(R_HAUT - 0.03, a, zt + 0.5), 0.035, c["os"], "longeron")
    else:
        g.cyl((0, 0, sum(Z_HAUT) / 2), "z", R_HAUT + 0.02, Z_HAUT[1] - Z_HAUT[0], c["haut"], n=36, r2=R_HAUT - 0.03,
              style="smooth", what="coque_haute")
        g.torus((0, 0, 4.1), "z", R_HAUT - 0.005, 0.012, M["seam"], n=36, m=5, what="joint_h")
        # ogive
        g.sphere((0, 0, Z_HAUT[1] - 0.04), R_HAUT - 0.05, c["nez"], n=36, m=18, scale=(1.0, 1.0, 2.15), what="ogive")
        g.torus((0, 0, Z_HAUT[1] + 0.02), "z", R_HAUT - 0.052, 0.018, c["bande"], n=36, m=6, what="collier_nez")
        # antenne et feu
        g.cyl((0, 0, 5.9), "z", 0.03, 0.5, M["steel"], n=8, r2=0.012, style="smooth", what="antenne")
        g.dome((0, 0, 6.15), (0, 0, 1), 0.04, M["amber"], what="feu_nez")
    # hublots au sud (angle 270) : trois, cadre clair
    for da in (-0.62, 0.0, 0.62):
        a = math.radians(270) + da
        z = 4.02 if da == 0.0 else 3.94
        p = pol(R_HAUT - 0.01 if not ruine else R_HAUT, a, z)
        ax = (math.cos(a), math.sin(a), 0)
        if ruine and da != 0.0:
            continue
        g.cyl(V(p) + V(ax) * 0.02, ax, 0.125, 0.03, M["steel_dk"], n=16, style="hard", what="cadre_hublot")
        g.cyl(V(p) + V(ax) * 0.045, ax, 0.095, 0.03, M["emit_soft"] if not ruine else M["glass_dk"], n=16, style="flat",
              what="hublot")


def porte(c, ruine=False):
    """Porte éclairée au sud (signal de jeu fixe, comme les autres bâtiments) : cadre, vantail, voyant."""
    g, M = c.g, c.M
    a = math.radians(270)
    z0, z1 = 1.62, 2.52
    zc = (z0 + z1) / 2
    w = 0.52
    tang(g, R_BAS + 0.015, a, zc, w + 0.12, z1 - z0 + 0.12, 0.035, M["steel_dk"], "cadre_porte")
    tang(g, R_BAS + 0.04, a, zc, w, z1 - z0, 0.02, M["void"] if ruine else c["bande"], "vantail")
    if not ruine:
        tang(g, R_BAS + 0.055, a, zc + 0.1, w * 0.6, 0.22, 0.012, M["emit_soft"], "voyant_porte")
        for k in range(8):
            tang(g, R_BAS + 0.058, a, z0 + 0.04, w / 8 * 0.9, 0.06, 0.012, M["hazy"] if k % 2 else M["hazk"], "seuil")
        c.g.halo(pol(R_BAS + 0.5, a, zc), M["_emit_rgb"], 3.0)


def ailettes(c, ruine=False, perdues=()):
    g, M = c.g, c.M
    t = 0.075
    for a_deg in (45, 135, 225, 315):
        if a_deg in perdues:
            continue
        a = math.radians(a_deg)
        ca, sa = math.cos(a), math.sin(a)
        tn = (-sa, ca)
        prof = [(0.70, 1.30), (1.62, 0.94), (1.62, 1.46), (0.70, 3.02)]
        lo = [(r * ca - tn[0] * t / 2, r * sa - tn[1] * t / 2, z) for r, z in prof]
        hi = [(r * ca + tn[0] * t / 2, r * sa + tn[1] * t / 2, z) for r, z in prof]
        g.hexa(lo + hi, c["aile"], "hard", "ailette")
        # chant d'attaque et pied d'atterrissage
        poutre(g, pol(1.62, a, 1.46), pol(0.7, a, 3.02), 0.05, c["bande"], "chant", h=0.095)
        poutre(g, pol(1.6, a, 0.96), pol(1.8, a, 0.12), 0.085, c["os"], "jambe")
        poutre(g, pol(1.1, a, 1.12), pol(1.75, a, 0.4), 0.04, c["os"], "contrefiche")
        g.cyl(pol(1.8, a, 0.07), "z", 0.18, 0.06, M["steel_dk"], n=14, style="hard", what="patin")


def tuyauterie(c):
    g, M = c.g, c.M
    a = math.radians(200)
    ctrl = [pol(0.78, a, 1.4), pol(0.86, a - 0.12, 2.0), pol(0.8, a - 0.1, 2.8), pol(0.76, a - 0.05, 3.3)]
    g.pipe(ctrl, 0.035, M["steel_dk"], fl_mat=M["steel"], bolt_mat=None, flanges=True, what="conduit")


def fusee_corps(c, ruine=False, perdues=()):
    tuyeres(c, ruine)
    coque(c, ruine)
    porte(c, ruine)
    ailettes(c, ruine, perdues)
    if not ruine:
        tuyauterie(c)


# ------------------------------------------------------------------------------------------------
# L'épave
# ------------------------------------------------------------------------------------------------
def epave(c, side):
    g, M = c.g, c.M
    rng = c.rng
    # cuvette : sol roussi et bourrelet de roches autour du pied
    g.cyl((0.3, -0.1, 0.012), "z", 2.55, 0.024, M["soot"], n=40, style="flat", what="roussi")
    for k in range(18):
        a = TAU * k / 18 + 0.2
        r = 2.2 + 0.4 * rng.random()
        s = 0.28 + 0.3 * rng.random()
        g.sphere((r * math.cos(a) + 0.2, r * math.sin(a) * 0.8 - 0.1, 0.1), s, M["stone2"] if k % 3 else M["basalt"],
                 n=10, m=6, scale=(1.0, 0.85, 0.5), what="roche")
    # la fusée couchée : axe vers l'est-sud-est, pied dans la cuvette à l'ouest
    g.push(loc=(-1.9, 0.35, 0.58), rz=-0.28, ry=1.37)
    c.g.stack[-1] = c.g.stack[-1] @ Matrix.Scale(1.0, 4)
    fusee_corps(c, ruine=True, perdues=(225,))
    g.pop()
    # l'ogive arrachée, posée plus loin
    g.push(loc=(2.35, -1.3, 0.5), rz=0.62, ry=1.5)
    g.sphere((0, 0, 0), 0.55, c["nez"], n=28, m=14, scale=(1.0, 1.0, 2.1), what="ogive_arrachee")
    g.torus((0, 0, -0.1), "z", 0.56, 0.02, c["bande"], n=28, m=6, what="collier")
    for z in (-0.08,):
        for k in range(10):
            a = TAU * k / 10
            tang(g, 0.55, a, z - 0.05, 0.2, 0.2, 0.03, c["nez"], "dent_ogive")
    g.pop()
    # ailette arrachée, plate dans les cailloux
    g.push(loc=(-1.0, -2.0, 0.07), rz=0.5)
    prof = [(0.0, 0.0), (1.1, -0.35), (1.1, 0.2), (0.0, 0.9)]
    pts = [(x, y, 0.0) for x, y in prof] + [(x, y, 0.07) for x, y in prof]
    g.hexa(pts, c["aile"], "hard", "ailette_perdue")
    g.pop()
    # débris : tôles, tuyau, tuyère
    mats = [c["haut"], c["bas"], c["os"], M["armor"], c["bande"]]
    for k in range(16):
        a = rng.random() * TAU
        r = 0.9 + 1.9 * rng.random()
        s = (0.15 + 0.35 * rng.random(), 0.12 + 0.3 * rng.random(), 0.025)
        R = Matrix.Rotation(rng.random() * TAU, 3, "Z") @ Matrix.Rotation((rng.random() - 0.5) * 0.5, 3, "X")
        g.box((r * math.cos(a) + 0.4, r * math.sin(a) * 0.85 - 0.2, 0.06), s, mats[k % len(mats)], "hard", R=R, what="tole")
    g.push(loc=(1.0, 1.7, 0.2), rz=1.1, ry=1.45)
    g.cyl((0, 0, 0), "z", 0.34, 0.6, c["tuy"], n=18, r2=0.2, what="tuyere_perdue")
    g.pop()
    # braises dans la cuvette (foyer éteint à demi) et voyant mort
    for (x, y) in ((-2.1, -0.3), (-2.4, 0.5), (-1.7, 0.9)):
        g.dome((x, y, 0.1), (0, 0, 1), 0.07, M["emit"], n=7, what="braise")
        g.halo((x, y - 0.2, 0.15), M["_emit_rgb"], 2.0)
    # fumée figée : fines colonnes sombres sur le pied
    for k in range(3):
        g.sphere((-1.9 + 0.1 * k, 0.4 + 0.05 * k, 1.35 + 0.35 * k), 0.17 + 0.05 * k, M["soot"], n=10, m=6, what="suie")


# ------------------------------------------------------------------------------------------------
# L'aire de la fusée (emprise `side` tuiles, y étiré)
# ------------------------------------------------------------------------------------------------
def aire(c, side, bord=0.1, z=0.12, plan="carre", pilotis=0.0):
    g, M = c.g, c.M
    hx, hy = side / 2.0 - 0.1, ty(side / 2.0 - 0.1)
    if plan == "octo":
        pts = []
        k = 0.34 * hx
        for q in range(4):
            for p in ((hx, -(hx - k)), (hx, hx - k)):
                x, y = p
                for _ in range(q):
                    x, y = -y, x
                pts.append((x, y * SQ2))
        n = len(pts)
        vs = [(x, y, pilotis) for x, y in pts] + [(x, y, pilotis + z) for x, y in pts]
        fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
        for i in range(n):
            j = (i + 1) % n
            fs.append((i, j, n + j, n + i))
        g._add(c["pad"], "hard", vs, fs, "aire_octo")
        return
    g.box((0, 0, pilotis + z / 2), (2 * hx, 2 * hy, z), c["pad"], "hard", what="aire")
    # liserés de bordure
    for sx in (-1, 1):
        g.box((sx * hx, 0, pilotis + z + 0.02), (0.1, 2 * hy, 0.05), c["pad2"], "hard", what="bord")
    for sy in (-1, 1):
        g.box((0, sy * hy, pilotis + z + 0.02), (2 * hx, 0.1 * SQ2, 0.05), c["pad2"], "hard", what="bord")


def disque_pied(c, z=0.14):
    """Plaque de pied sous la fusée : cercle d'acier clair, rivets (toujours le même repère de la silhouette)."""
    g, M = c.g, c.M
    g.cyl((0, 0, z + 0.012), "z", 2.1, 0.025, M["steel"], n=48, style="hard", what="plaque_pied")
    g.torus((0, 0, z + 0.03), "z", 2.1, 0.025, M["steel_hi"], n=48, m=6, what="cerclage_pied")
    for k in range(24):
        a = TAU * (k + 0.5) / 24
        x, y, _ = pol(1.96, a)
        g.dome((x, y, z + 0.03), (0, 0, 1), 0.035, M["rivet"], n=6)


# ------------------------------------------------------------------------------------------------
# Modules d'âge (autour de la fusée)
# ------------------------------------------------------------------------------------------------
def rail_circ(c, r, z, h, m, n=28, ep=0.03, ouvert=None):
    g = c.g
    g.tube_shell((0, 0, z), "z", r + ep, r - 0.002, h, m, n=n, what="lisse")


def age01(c, side):
    """Pionnier : aire de planches, échafaudage de bois autour de la fusée, rampe, bâches et lanternes, fanion."""
    g, M = c.g, c.M
    rng = c.rng
    aire(c, side, z=0.1)
    g.push((0, 0, c.rise))
    # coque rapiécée : pièces de tôle, bâche, cordage
    for k, (a_deg, z, w, h, mi) in enumerate(((330, 2.9, 0.5, 0.42, "rawiron"), (95, 2.2, 0.42, 0.55, "ochre"),
                                              (200, 1.75, 0.55, 0.38, "canvas"), (20, 2.45, 0.34, 0.5, "armor"),
                                              (150, 4.0, 0.4, 0.34, "rawiron"), (60, 3.9, 0.36, 0.3, "canvas2"))):
        r = R_BAS + 0.018 if z < 3.3 else R_HAUT + 0.0
        tang(g, r, math.radians(a_deg), z, w, h, 0.03, M[mi], "piece")
        for dx in (-w / 2 + 0.04, w / 2 - 0.04):
            for dz in (-h / 2 + 0.04, h / 2 - 0.04):
                a2 = math.radians(a_deg) + dx / r
                x, y, _ = pol(r + 0.03, a2)
                g.dome((x, y, z + dz), (math.cos(a2), math.sin(a2), 0), 0.018, M["rivet"], n=6)
    for z in (1.55, 3.9):
        g.torus((0, 0, z), "z", (R_BAS if z < 3 else R_HAUT) + 0.04, 0.02, M["canvas2"], n=36, m=6, what="cordage")
    g.pop()
    # échafaudage léger : trois poteaux (E, N, O), un chemin de ronde annulaire sous l'inter-étage, lisses et croix
    for a_deg in (0, 90, 180):
        a = math.radians(a_deg)
        x, y, _ = pol(1.62, a)
        poutre(g, (x, y, 0.1), (x, y, 4.3), 0.1, M["wood"], "poteau")
        g.cyl((x, y, 4.35), "z", 0.09, 0.12, M["wood2"], n=8, r2=0.0, style="hard", what="pointe_poteau")
    zp, ri, ro = 3.05 + c.rise, 0.76, 1.62
    g.tube_shell((0, 0, zp), "z", ro, ri, 0.07, M["wood2"], n=32, style="hard", what="chemin_de_ronde")
    for k in range(26):
        a = TAU * k / 26
        poutre(g, pol(ri, a, zp + 0.04), pol(ro, a, zp + 0.04), 0.012, M["seam"], "joint_planche", h=0.012)
    rail_circ(c, ro, zp + 0.36, 0.05, M["wood"], n=32)
    rail_circ(c, ro, zp + 0.14, 0.04, M["wood"], n=32)
    for a_deg in (0, 90, 180):
        a = math.radians(a_deg)
        poutre(g, pol(1.62, a, 0.1), pol(1.62, a + math.radians(45), zp), 0.06, M["wood"], "croix")
        poutre(g, pol(1.62, a, 0.1), pol(1.62, a - math.radians(45), zp), 0.06, M["wood"], "croix")
    rail_circ(c, 1.62, 4.2, 0.05, M["wood"], n=32)
    # rampe de planches vers la porte (sud) : plan incliné
    p0 = V((0, -ty(1.95), 0.1))
    p1 = V((0, -1.8, 1.58))
    poutre(g, p0 + V((-0.34, 0, 0)), p1 + V((-0.34, 0, 0)), 0.07, M["wood"], "rampe_l", h=0.07)
    poutre(g, p0 + V((0.34, 0, 0)), p1 + V((0.34, 0, 0)), 0.07, M["wood"], "rampe_r", h=0.07)
    for k in range(9):
        t = (k + 0.5) / 9
        q = p0.lerp(p1, t)
        g.box(q + V((0, 0, 0.05)), (0.7, 0.18, 0.04), M["wood2"], "hard", R=Matrix.Rotation(-0.32, 3, "X"), what="marche")
    # lanternes sur les poteaux et au plancher haut
    for a_deg, z in ((0, 3.75), (90, 3.75), (180, 3.75), (0, 1.95)):
        a = math.radians(a_deg)
        x, y, _ = pol(1.72, a)
        g.cyl((x, y - 0.18, z), "z", 0.1, 0.16, M["emit"], n=8, style="flat", what="lanterne")
        g.cyl((x, y - 0.18, z + 0.1), "z", 0.12, 0.03, M["blackiron"], n=8, what="chapeau")
        g.halo((x, y - 0.4, z), M["_emit_rgb"], 3.5)
    # fanion rouge au bout de l'antenne
    g.box((0.16, 0, 5.98 + c.rise), (0.3, 0.012, 0.15), M["redpaint"], "hard", what="fanion")
    # caisses de ravitaillement et tonneaux sur l'aire
    for (x, y, s) in ((1.5, -ty(1.1), 0.34), (-1.45, -ty(1.2), 0.3), (1.2, ty(1.3), 0.3)):
        g.box((x, y, 0.1 + s / 2), (s, s, s), M["wood"], "hard", what="caisse")
        g.box((x, y, 0.1 + s + 0.02), (s * 0.9, s * 0.9, 0.03), M["wood2"], "hard", what="couvercle")


def age04(c, side):
    """Pétrole : tôle larmée jaune et noire, portique d'acier à l'ouest, cuves et tuyaux à l'est, torchère, mât radio."""
    g, M = c.g, c.M
    aire(c, side, z=0.14)
    disque_pied(c)
    g.push((0, 0, c.rise))
    # bandes de la coque : noir sur le jaune
    for z, h in ((1.45, 0.16), (2.9, 0.1), (4.35, 0.12)):
        r = R_BAS + 0.012 if z < 3.3 else R_HAUT + 0.0
        g.tube_shell((0, 0, z), "z", r + 0.015, r - 0.005, h, c["bande"], n=36, style="hard", what="bande_noire")
    # mât radio sur l'antenne : trois paliers, feux rouges
    for z, r in ((5.75, 0.17), (6.05, 0.13), (6.35, 0.1)):
        g.cyl((0, 0, z), "z", r, 0.025, M["noir_capot"], n=12, style="hard", what="palier_mat")
        for k in range(4):
            x, y, _ = pol(r * 0.95, TAU * k / 4)
            g.dome((x, y, z + 0.02), (0, 0, 1), 0.022, M["redpaint"], n=6)
    g.cyl((0, 0, 6.6), "z", 0.025, 0.5, M["steel"], n=8, r2=0.01, what="mat_haut")
    g.dome((0, 0, 6.85), (0, 0, 1), 0.04, M["emit"], what="feu_sommet")
    g.halo((0, -0.15, 6.8), M["_emit_rgb"], 2.5)
    g.pop()
    # portique à l'ouest : 4 montants en caisson, croisillons, passerelle vers la porte, plateformes
    gx = -1.75
    haut = 5.0
    cols = [(gx - 0.42, -0.5), (gx + 0.42, -0.5), (gx - 0.42, 0.5), (gx + 0.42, 0.5)]
    for (x, y) in cols:
        poutre(g, (x, y, 0.14), (x, y, haut), 0.11, M["steel_dk"], "montant")
    for k in range(5):
        z0, z1 = 0.14 + k * (haut - 0.14) / 5, 0.14 + (k + 1) * (haut - 0.14) / 5
        for (xa, ya, xb, yb) in ((cols[0][0], cols[0][1], cols[2][0], cols[2][1]), (cols[1][0], cols[1][1], cols[3][0], cols[3][1]),
                                 (cols[2][0], cols[2][1], cols[3][0], cols[3][1]), (cols[0][0], cols[0][1], cols[1][0], cols[1][1])):
            poutre(g, (xa, ya, z0), (xb, yb, z1 if k % 2 == 0 else z0 + 0.0), 0.05, M["steel_dk"], "croisillon")
            poutre(g, (xa, ya, z0), (xb, yb, z0), 0.07, M["steel_dk"], "entretoise")
        g.box((gx, 0, z0 + 0.02), (1.0, 1.1, 0.03), M["tole_larmee"], "hard", what="plateforme") if k in (2, 4) else None
    # bras de service vers la coque (z 3,45) et passerelle
    g.push((0, 0, c.rise))
    poutre(g, (gx + 0.42, 0, 3.4), (-R_BAS - 0.04, 0, 3.4), 0.2, M["jaune_capot"], "bras_service", h=0.12)
    for sy in (-1, 1):
        poutre(g, (gx + 0.42, sy * 0.1, 3.5), (-R_BAS - 0.04, sy * 0.1, 3.5), 0.03, M["noir_capot"], "garde_corps", h=0.03)
    g.pop()
    # bandes de danger sur les montants
    for (x, y) in cols[:2]:
        for z in (0.5, 0.8):
            g.box((x, y - 0.0, z), (0.125, 0.125, 0.12), M["hazy"], "hard", what="danger_montant")
    # cuves horizontales à l'est : jaune, cerclées de noir, liées à la fusée par un tuyau
    for sy in (-0.95, 0.95):
        y = ty(sy * 1.0) * 0.55
        cx = 1.7
        g.cyl((cx, y, 0.14 + 0.38), "y", 0.38, 1.5, M["jaune_capot"], n=24, style="smooth", what="cuve")
        for dy in (-0.5, 0.5):
            g.tube_shell((cx, y + dy, 0.14 + 0.38), "y", 0.395, 0.37, 0.07, M["noir_capot"], n=24, what="cercle_cuve")
        g.sphere((cx, y + 0.75, 0.52), 0.38, M["jaune_capot"], n=18, m=10, scale=(1, 0.35, 1), what="fond_cuve")
        g.sphere((cx, y - 0.75, 0.52), 0.38, M["jaune_capot"], n=18, m=10, scale=(1, 0.35, 1), what="fond_cuve")
        g.pipe([(cx - 0.3, y, 0.95), (1.3, y * 0.6, 1.25), (0.95, y * 0.2, 1.1), (R_BAS * 0.9, 0.0, 1.05)], 0.05, M["noir_capot"],
               fl_mat=M["steel"], bolt_mat=None, flanges=True, what="tuyau_carburant")
    # torchère : pied de tuyau et flamme ambre (coin nord-est)
    tx, tyv = 1.55, ty(1.75)
    poutre(g, (tx, tyv, 0.14), (tx, tyv, 1.9), 0.07, M["noir_capot"], "mat_torchere")
    g.cyl((tx, tyv, 2.2), "z", 0.13, 0.5, M["amber"], n=10, r2=0.0, style="flat", what="flamme")
    g.halo((tx, tyv - 0.2, 2.2), M["_emit_rgb"], 4.0)
    # voyants d'aire aux quatre coins
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.dome((sx * (side / 2 - 0.25), sy * ty(side / 2 - 0.25), 0.2), (0, 0, 1), 0.07, M["amber"], n=7, what="feu_aire")


def age08(c, side):
    """Marais : fusée sur pilotis, entretoises de bois, bocal vert et serre de verre, tuyaux de cuivre vert-de-grisés."""
    g, M = c.g, c.M
    h_p = 0.55
    aire(c, side, z=0.12, pilotis=h_p)
    # pilotis sous l'aire
    hx, hy = side / 2.0 - 0.2, ty(side / 2.0 - 0.2)
    for sx in (-1, -0.5, 0, 0.5, 1):
        for sy in (-1, 1):
            g.cyl((sx * hx, sy * hy, h_p / 2), "z", 0.07, h_p, M["bois_mouille"], n=8, style="smooth", what="pilotis")
    for sy in (-0.5, 0.0, 0.5):
        for sx in (-1, 1):
            g.cyl((sx * hx, sy * hy * 2, h_p / 2), "z", 0.07, h_p, M["bois_mouille"], n=8, style="smooth", what="pilotis")
    # disque de pied et escalier de bois sud
    disque_pied(c, z=h_p + 0.12)
    for k in range(5):
        g.box((0.0, -(hy + 0.02 + 0.2 * (4 - k) * 0.5), h_p - 0.1 * k + 0.02), (0.9, 0.34, 0.06), M["bois_mouille"], "hard", what="marche")
    # bandes de cuivre sur la coque
    z0 = h_p + 0.12
    g.push((0, 0, c.rise))
    for z, h in ((1.5, 0.14), (2.85, 0.1), (4.35, 0.1)):
        r = R_BAS + 0.012 if z < 3.3 else R_HAUT
        g.tube_shell((0, 0, z), "z", r + 0.018, r - 0.005, h, M["cuivre_terni"], n=36, style="hard", what="bande_cuivre")
    # antenne : bocal de la pointe
    g.cyl((0, 0, 5.98), "z", 0.1, 0.3, M["verre_toxique"], n=18, style="smooth", what="bocal_nez")
    g.cyl((0, 0, 5.96), "z", 0.075, 0.2, M["emit"], n=18, style="flat", what="liquide_nez")
    g.cyl((0, 0, 6.15), "z", 0.115, 0.04, M["cuivre_terni"], n=18, style="hard", what="couvercle_nez")
    g.halo((0, -0.2, 5.98), M["_emit_rgb"], 3.0)
    # arcs-boutants de bois (4 diagonales) entre le sol et la coque haute
    for a_deg in (0, 90, 180, 270):
        a = math.radians(a_deg)
        if a_deg == 270:
            continue
        poutre(g, pol(2.05, a, 0.1), pol(R_BAS - 0.02, a, 3.0), 0.14, M["bois_mouille"], "arc_boutant")
        g.cyl(pol(R_BAS + 0.06, a, 3.0), "z", 0.1, 0.1, M["cuivre_terni"], n=10, what="collier_arc")
    g.pop()
    # serre de verre à l'est
    sx, sy = 1.6, -0.75
    g.sphere((sx, sy, h_p + 0.1), 0.95, M["verre_toxique"], n=24, m=12, scale=(1.0, 1.0, 0.8), what="serre")
    for k in range(10):
        a = TAU * k / 10
        poutre(g, (sx + 0.95 * math.cos(a), sy + 0.95 * math.sin(a), h_p + 0.1), (sx, sy, h_p + 0.9), 0.025, M["cuivre_terni"], "arceau")
    g.dome((sx, sy, h_p + 0.9), (0, 0, 1), 0.07, M["cuivre_terni"], n=8, what="clef_serre")
    for k in range(7):                                  # plantes : cônes verts lumineux dans la serre
        a = TAU * k / 7
        r = 0.4 if k else 0.0
        g.cyl((sx + r * math.cos(a), sy + r * math.sin(a), h_p + 0.3 + 0.1 * (k % 3)), "z", 0.13, 0.4, M["emit"], n=7,
              r2=0.0, style="flat", what="pousse")
    g.halo((sx, sy - 0.5, h_p + 0.5), M["_emit_rgb"], 5.0)
    # grand bocal vert à l'ouest
    bx, by = -1.85, -0.6
    g.cyl((bx, by, h_p + 0.78), "z", 0.38, 1.3, M["verre_toxique"], n=22, style="smooth", what="bocal")
    g.cyl((bx, by, h_p + 0.62), "z", 0.33, 0.95, M["emit"], n=22, style="flat", what="liquide")
    g.cyl((bx, by, h_p + 1.47), "z", 0.4, 0.07, M["cuivre_terni"], n=22, style="hard", what="couvercle")
    g.cyl((bx, by, h_p + 0.16), "z", 0.42, 0.1, M["cuivre_terni"], n=22, style="hard", what="socle_bocal")
    g.halo((bx, by - 0.3, h_p + 0.8), M["_emit_rgb"], 5.0)
    g.pipe([(bx + 0.3, by, h_p + 1.2), (-1.4, by * 0.4, h_p + 1.6), (-1.0, 0.0, h_p + 1.9), (-R_BAS, 0.0, h_p + 1.9)], 0.045,
           M["cuivre_terni"], fl_mat=M["cuivre_terni"], bolt_mat=None, flanges=True, what="tuyau_cuivre")
    # roseaux : touffes de cônes vert sombre au pied de l'aire
    rng = c.rng
    for k in range(22):
        a = rng.random() * TAU
        r = 2.4 + 0.5 * rng.random()
        x, y = r * math.cos(a), ty(r * 0.75) * math.sin(a)
        g.cyl((x, y, 0.28), "z", 0.035, 0.56, M["bois_mousse"], n=5, r2=0.005, style="smooth", what="roseau")


def age15(c, side):
    """Néant : aire octogonale noire à liserés incandescents, fusée noire à bandes d'or, disque segmenté en lévitation
    sur des entretoises d'or autour de la coque haute, sphère noire flottant au-dessus du nez, obélisques d'or."""
    g, M = c.g, c.M
    aire(c, side, z=0.16, plan="octo")
    # liserés incandescents de l'aire : deux anneaux et huit rayons
    g.torus((0, 0, 0.175), "z", 2.9, 0.012, M["emit"], n=64, m=6, what="lisere_aire")
    for k in range(8):
        a = TAU * k / 8 + math.pi / 8
        poutre(g, pol(2.2, a, 0.18), pol(2.9, a, 0.18), 0.02, M["emit"], "rayon", h=0.008)
    disque_pied(c, z=0.16)
    g.push((0, 0, c.rise))
    # bandes d'or et veines incandescentes de la coque
    for z, h in ((1.5, 0.12), (2.9, 0.08), (4.3, 0.08)):
        r = R_BAS + 0.012 if z < 3.3 else R_HAUT
        g.tube_shell((0, 0, z), "z", r + 0.017, r - 0.005, h, M["or_chauffe"], n=40, style="hard", what="bande_or")
    for k in range(6):
        a = TAU * (k + 0.5) / 6
        tang(g, R_BAS + 0.012, a, 2.2, 0.03, 1.0, 0.012, M["emit"], "veine")
    # disque segmenté en lévitation autour de la coque haute (12 segments, alternés) sur 6 entretoises d'or
    zs, R0, R1 = 4.05, 0.95, 1.85
    for k in range(12):
        a0, a1 = TAU * k / 12 + 0.01, TAU * (k + 1) / 12 - 0.01
        quad = [(R0 * math.cos(a0), R0 * math.sin(a0)), (R1 * math.cos(a0), R1 * math.sin(a0)),
                (R1 * math.cos(a1), R1 * math.sin(a1)), (R0 * math.cos(a1), R0 * math.sin(a1))]
        vs = [(x, y, zs - 0.05) for x, y in quad] + [(x, y, zs + 0.05) for x, y in quad]
        fs = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        g._add(M["or_chauffe"] if k % 2 else M["noir_chaud2"], "hard", vs, fs, "segment")
        am = (a0 + a1) / 2
        if k % 2:
            poutre(g, pol(R0, am, zs - 0.05), pol(R_HAUT + 0.02, am, 3.5), 0.05, M["or_chauffe"], "entretoise")
    g.torus((0, 0, zs + 0.06), "z", R1 - 0.02, 0.012, M["emit2"], n=64, m=6, what="bord_disque")
    # sphère noire flottante au-dessus du nez et son anneau d'or
    g.sphere((0, 0, 6.75), 0.3, M["noir_profond"], n=32, m=16, what="sphere_noire")
    g.torus((0, 0, 6.75), "z", 0.32, 0.015, M["emit"], n=40, m=6, what="equateur")
    g.torus((0, 0, 6.75), (1, 0, 0.3), 0.42, 0.012, M["or_vif"], n=40, m=6, what="orbite")
    g.halo((0, -0.4, 6.75), M["_emit_rgb"], 5.0)
    g.pop()
    # obélisques d'or aux quatre coins de l'aire
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * 3.0, sy * ty(2.75) * 0.85
            g.cyl((x, y, 0.16 + 0.7), "z", 0.16, 1.4, M["or_chauffe"], n=4, r2=0.05, phase=math.pi / 4, style="hard", what="obelisque")
            g.dome((x, y, 0.16 + 1.42), (0, 0, 1), 0.06, M["emit"], n=6, what="pointe_obelisque")
            g.halo((x, y - 0.2, 1.4), M["_emit_rgb"], 3.0)


MODULES = {1: age01, 4: age04, 8: age08, 15: age15}


def fusee(g, e, side):
    c = Ctx(g, e, side)
    if e == 0:
        epave(c, side)
        return
    g.push((0, 0, 0))
    g.stack[-1] = g.stack[-1] @ Matrix.Scale(KS, 4)
    g.push((0, 0, c.rise))
    fusee_corps(c)
    g.pop()
    mod = MODULES.get(e)
    if mod is None:
        raise SystemExit("fusee : l'âge %d n'a pas encore de module (premier jet : 1, 4, 8 et 15)" % e)
    mod(c, side / KS)
    g.pop()
