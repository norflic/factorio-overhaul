"""LE VAISSEAU DE DÉPART = CENTRE DE COMMANDEMENT, v2 (lot CENTRE-FUSEE, 29/10 ; forme tranchée par le DC : « vaisseau
couché, long », qui « se métamorphose en bâtiment » comme « un bâtiment construit sur une carcasse de dinosaure »).
S'exécute DANS Blender (mathutils). Remplace fusee.py (fusée debout, REFUSÉE ; gardé comme essai).

Repère « unités de base » (empreinte de base 8 × 4 tuiles = x ± 4, y ± 2,83) : x est (l'arrière, les réacteurs), y nord, z
haut ; le NEZ est à l'OUEST (x = -3,9), les réacteurs à l'EST (x = +4,5). Tout est dessiné à l'échelle de base puis
agrandi de s = largeur / 4 (largeur de l'empreinte : 4 à 8 tuiles, longueur = 2 × largeur). Axe du vaisseau : z = Z0.

LA CARCASSE (reste à tous les âges) : CRÂNE = le nez (ogive, hublots) ; ÉPINE = la quille (poutre sur le dos) ; CÔTES =
les anneaux de coque ; QUEUE = la collerette et les 3 tuyères de l'arrière ; FLANCS = les 2 ailes. LE BÂTIMENT pousse
dessus : 0 épave ; 1 vaisseau réparé + cabanes ; 4 moitié-moitié (le ventre est un bâtiment, nez et queue de vaisseau) ;
8 bâtiment, coque visible aux deux bouts et côtes qui dépassent du toit ; 15 citadelle, côtes en grandes arches d'or,
épine en faîtière d'or, crâne noir en proue, tuyères en pied.
"""
import math

from mathutils import Matrix, Vector

from kit import SQ2, TAU

V = Vector
R = 1.5          # rayon de la coque
Z0 = 1.7        # hauteur de l'axe
X_NEZ, X_TUY = -3.9, 4.5
LARGEUR = 4.0    # largeur de base de l'emprise (tuiles)


def ty(t):
    return t * SQ2


def rprof(x):
    if x <= X_NEZ:
        return 0.0
    if x < -2.0:
        t = (-2.0 - x) / (-2.0 - X_NEZ)
        return R * math.sqrt(max(0.0, 1 - t * t))
    if x <= 2.0:
        return R
    if x <= 3.3:
        return R * (1 - 0.25 * (x - 2.0) / 1.3)
    return 0.75 * R


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


def box(g, x0, x1, y0, y1, z0, z1, m, what="bloc", style="hard"):
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), m, style, what=what)


def surf(g, x, th, w, h, t, m, what="plaque", dr=0.0):
    """Plaque sur le flanc SUD de la coque : x, angle th depuis le dessus vers le sud (rad), w le long de x, h tangent."""
    r = rprof(x) + dr
    p = (x, -r * math.sin(th), Z0 + r * math.cos(th))
    g.box(p, (w, h, t), m, "hard", R=Matrix.Rotation(th, 3, "X"), what=what)


def pans(g, x0, x1, y0, y1, z, h, m, what="toit", debord=0.0):
    """Toit à deux pans (faîtage le long de x)."""
    x0, x1, y0, y1 = x0 - debord, x1 + debord, y0 - debord, y1 + debord
    ym = (y0 + y1) / 2
    vs = [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z), (x0, ym, z + h), (x1, ym, z + h)]
    fs = [(0, 3, 2, 1), (0, 1, 5, 4), (3, 4, 5, 2), (0, 4, 3), (1, 2, 5)]
    g._add(m, "hard", vs, fs, what)


def mk(M, *cles):
    for c in cles:
        if c in M:
            return M[c]
    return M["armor"]


PAL = {
    0: dict(peau=("hazy",), bande=("hazk",), os=("rawiron",), aile=("hazy",), tuy=("armor2",), mur=("armor",),
            mur2=("rawiron",), toit=("wood2",), pad=("concrete",), pad2=("armor2",), acc=("redpaint",), vit=("glass_dk",)),
    1: dict(peau=("hazy",), bande=("armor2",), os=("wood",), aile=("redpaint",), tuy=("rawiron",), mur=("wood",),
            mur2=("wood2",), toit=("canvas",), pad=("wood2",), pad2=("wood",), acc=("cream",), vit=("emit_soft",)),
    4: dict(peau=("jaune_capot",), bande=("noir_capot",), os=("noir_capot",), aile=("noir_capot",), tuy=("galva",),
            mur=("jaune_capot",), mur2=("noir_capot",), toit=("noir_capot",), pad=("tole_larmee",),
            pad2=("noir_capot",), acc=("redpaint",), vit=("emit_soft",)),
    8: dict(peau=("vdg_capot",), bande=("cuivre_terni",), os=("cuivre_terni",), aile=("vdg_capot",),
            tuy=("cuivre_terni",), mur=("bois_mouille",), mur2=("bois_mousse",), toit=("vdg_capot",),
            pad=("bois_mouille",), pad2=("bois_mousse",), acc=("cuivre_terni",), vit=("verre_toxique",)),
    15: dict(peau=("or_blanc_chaud",), bande=("noir_chaud",), os=("or_blanc_chaud",), aile=("noir_chaud2",),
             tuy=("or_chauffe",), mur=("noir_chaud",), mur2=("noir_chaud2",), toit=("noir_chaud2",),
             pad=("concrete",), pad2=("noir_chaud2",), acc=("or_vif",), vit=("noir_profond",)),
}


class Ctx:
    def __init__(self, g, e):
        self.g, self.M, self.e, self.rng = g, g.M, e, g.rng
        self.P = {k: mk(g.M, *v) for k, v in PAL[e].items()}

    def __getitem__(self, k):
        return self.P[k]


# ------------------------------------------------------------------------------------------------
# La carcasse
# ------------------------------------------------------------------------------------------------
def peau(c, plages, pas=0.38):
    """Peau de la coque (tronçons de cône le long de x) sur les plages (x0, x1) ; joints de panneaux."""
    g, M = c.g, c.M
    x = X_NEZ
    k = 0
    while x < 3.5 - 1e-6:
        xb = min(x + pas, 3.5)
        xm = (x + xb) / 2
        if any(a - 1e-6 <= xm <= b + 1e-6 for a, b in plages):
            ra, rb = rprof(x) + 0.001, rprof(xb) + 0.001
            g.cyl((xm, 0, Z0), "x", ra, xb - x, c["peau"], n=28, r2=rb, style="smooth", what="peau")
            if k % 3 == 2:
                g.torus((xb, 0, Z0), "x", rb + 0.004, 0.012, M["seam"], n=28, m=5, what="joint")
        x = xb
        k += 1


def cotes(c, xs, mat=None, k=1.0, z0=None, ep=0.09):
    g = c.g
    for x in xs:
        r = rprof(x) * k if x > -3.2 else rprof(x)
        if r < 0.2:
            continue
        g.tube_shell((x, 0, Z0 if z0 is None else z0), "x", r + 0.07, r - 0.03, ep, mat or c["os"], n=32, what="cote")


def longerons(c, x0, x1, n=9):
    """Longerons (ossature nue) entre deux côtes, là où la peau manque."""
    g = c.g
    for k in range(n):
        a = TAU * k / n + 0.2
        pa = (x0, (rprof(x0)) * math.cos(a), Z0 + rprof(x0) * math.sin(a))
        pb = (x1, (rprof(x1)) * math.cos(a), Z0 + rprof(x1) * math.sin(a))
        poutre(g, pa, pb, 0.05, c["os"], "longeron")


def epine(c, x0, x1, mat=None, k=1.0, w=0.16, dz=0.05, haut=None):
    """ÉPINE : la quille sur le dos de la coque."""
    g = c.g
    mat = mat or c["bande"]
    x = x0
    while x < x1 - 1e-6:
        xb = min(x + 0.4, x1)
        za = Z0 + rprof(x) * k + dz
        zb = Z0 + rprof(xb) * k + dz
        if haut is not None:
            za = zb = haut
        poutre(g, (x, 0, za), (xb, 0, zb), w, mat, "epine", h=w * 1.2)
        x = xb


def hublots(c, x0=-3.2, x1=-0.9, pas=0.46, vitre=None):
    g, M = c.g, c.M
    vit = vitre or M["emit_soft"]
    x = x0
    while x <= x1 + 1e-6:
        r = rprof(x)
        th = math.radians(62)
        p = V((x, -r * math.sin(th), Z0 + r * math.cos(th)))
        n = V((0, -math.sin(th), math.cos(th)))
        g.cyl(p + n * 0.02, n, 0.14 * min(1.0, r / R + 0.2), 0.04, M["steel_dk"], n=14, style="hard", what="cadre_hublot")
        g.cyl(p + n * 0.045, n, 0.1 * min(1.0, r / R + 0.2), 0.03, vit, n=14, style="flat", what="hublot")
        x += pas
    # verrière du cockpit sur le dessus du crâne
    r = rprof(-3.0)
    g.box((-3.0, 0, Z0 + r + 0.01), (0.7, 0.55, 0.05), M["steel_dk"], "hard", R=Matrix.Rotation(0.0, 3, "Y"), what="cadre_verriere")
    g.box((-3.0, 0, Z0 + r + 0.04), (0.6, 0.45, 0.03), vit, "flat", what="verriere")
    g.halo((-3.0, -0.4, Z0 + r + 0.2), M["_emit_rgb"], 2.5)


def queue(c, k=1.0, intacte=True):
    """QUEUE : collerette et trois tuyères à l'arrière (est)."""
    g, M = c.g, c.M
    g.cyl((3.5, 0, Z0), "x", 0.75 * R + 0.02, 0.4, c["bande"], n=28, r2=0.72 * R, style="smooth", what="collerette")
    g.tube_shell((3.32, 0, Z0), "x", 0.75 * R + 0.06, 0.75 * R - 0.02, 0.07, M["steel_dk"], n=28, what="collier")
    pos = [(0.0, Z0 + 0.4), (-0.52, Z0 - 0.36), (0.52, Z0 - 0.36)]
    for i, (y, z) in enumerate(pos):
        if not intacte and i == 2:
            continue
        g.cyl((4.05, y, z), "x", 0.2, 0.9, c["tuy"], n=18, r2=0.37, style="smooth", what="tuyere")
        g.tube_shell((4.48, y, z), "x", 0.39, 0.32, 0.06, c["bande"], n=18, what="levre")
        g.cyl((4.5, y, z), "x", 0.32, 0.03, M["void"], n=18, style="flat", what="gorge")
        g.dome((4.46, y, z), (1, 0, 0), 0.14, M["emit"], n=7, what="feu_tuyere")
    g.halo((4.9, -0.3, Z0), M["_emit_rgb"], 3.0)


def ailes(c, portee=3.3, ep=0.14, z=None, mat=None, perdues=()):
    g = c.g
    z = Z0 - 0.3 if z is None else z
    for sg in (-1, 1):
        if sg in perdues:
            continue
        pts = [(-2.3, sg * R * 0.8), (3.1, sg * R * 0.8), (3.5, sg * portee), (2.3, sg * portee)]
        lo = [(x, y, z - ep / 2) for x, y in pts]
        hi = [(x, y, z + ep / 2) for x, y in pts]
        g.hexa(lo + hi, mat or c["aile"], "hard", "aile")
        poutre(g, (2.3, sg * portee, z), (-2.3, sg * R * 0.8, z), 0.09, c["acc"], "chant_aile", h=0.2)
        poutre(g, (3.5, sg * portee, z), (3.1, sg * R * 0.8, z), 0.07, c["bande"], "bord_fuite", h=0.17)
        g.cyl((3.0, sg * (portee - 0.35), z + 0.1), "x", 0.17, 0.9, c["tuy"], n=14, r2=0.22, style="smooth", what="nacelle")
    # dérive sur le dos, à l'arrière
    zt = Z0 + 0.8 * R * 0.97
    pts = [(1.3, zt + 0.05), (3.4, zt - 0.1), (3.8, zt + 1.9), (2.8, zt + 1.9)]
    lo = [(x, -0.05, z_) for x, z_ in pts]
    hi = [(x, 0.05, z_) for x, z_ in pts]
    g.hexa(lo + hi, mat or c["aile"], "hard", "derive")


def pieds(c, xs=(-2.0, 1.6), hauteur=None):
    g, M = c.g, c.M
    for x in xs:
        for sg in (-1, 1):
            poutre(g, (x, sg * 0.75, Z0 - 1.0), (x, sg * 1.2, 0.13), 0.1, c["os"], "jambe")
            g.cyl((x, sg * 1.2, 0.1), "z", 0.22, 0.06, M["steel_dk"], n=14, style="hard", what="patin")
        poutre(g, (x, -0.75, Z0 - 1.0), (x, 0.75, Z0 - 1.0), 0.08, c["os"], "traverse")


def porte(c, x=0.3):
    g, M = c.g, c.M
    th = math.radians(78)
    surf(g, x, th, 0.9, 0.95, 0.05, M["steel_dk"], "cadre_porte", dr=0.02)
    surf(g, x, th, 0.78, 0.82, 0.04, c["vit"] if c.e else M["void"], "vantail", dr=0.05)
    for k in range(6):
        surf(g, x - 0.4 + 0.16 * k + 0.08, math.radians(100), 0.14, 0.12, 0.03, M["hazy"] if k % 2 else M["hazk"], "seuil", dr=0.05)
    g.halo((x, -rprof(x) - 0.5, Z0 + 0.2), M["_emit_rgb"], 3.0)


def rapiece(c, liste):
    """Pièces de tôle, bâche, rivets sur la peau : (x, angle°, largeur, hauteur, matière)."""
    g, M = c.g, c.M
    for (x, a, w, h, mi) in liste:
        th = math.radians(a)
        surf(g, x, th, w, h, 0.035, M[mi], "piece", dr=0.01)
        for dx in (-w / 2 + 0.05, w / 2 - 0.05):
            for dh in (-h / 2 + 0.05, h / 2 - 0.05):
                r = rprof(x) + 0.05
                a2 = th + dh / max(r, 0.3)
                g.dome((x + dx, -r * math.sin(a2), Z0 + r * math.cos(a2)), (0, -math.sin(a2), math.cos(a2)), 0.02, M["rivet"], n=6)


def aire(c, x0=-4.0, x1=4.0, y=None, z=0.1, plan="rect"):
    g = c.g
    y = y if y is not None else ty(2.0) - 0.05
    box(g, x0, x1, -y, y, 0.0, z, c["pad"], "aire")
    for sy in (-1, 1):
        box(g, x0, x1, sy * (y - 0.05), sy * y, z, z + 0.05, c["pad2"], "bord_aire")
    for sx in (-1, 1):
        box(g, sx * x1 - 0.05 * sx, sx * x1, -y, y, z, z + 0.05, c["pad2"], "bord_aire")


# ------------------------------------------------------------------------------------------------
# Les états
# ------------------------------------------------------------------------------------------------
def epave(c):
    g, M, rng = c.g, c.M, c.rng
    # cratère roussi, roches
    g.cyl((0.4, 0, 0.012), "z", 3.6, 0.024, M["soot"], n=48, style="flat", what="roussi")
    for k in range(26):
        a = TAU * k / 26 + 0.1
        r = 3.6 + 0.5 * rng.random()
        s = 0.3 + 0.35 * rng.random()
        g.sphere((0.4 + r * math.cos(a) * 1.1, r * math.sin(a) * 0.55, 0.1), s, M["stone2"] if k % 3 else M["basalt"], n=10, m=6,
                 scale=(1.0, 0.85, 0.5), what="roche")
    # le vaisseau, enfoncé de biais, nez au sol à l'ouest
    g.push(loc=(0.0, 0.0, -0.55), rz=0.0, ry=0.0)
    g.stack[-1] = g.stack[-1] @ Matrix.Rotation(0.09, 4, "Y") @ Matrix.Rotation(0.07, 4, "X")
    peau(c, [(1.2, 3.5), (-3.9, -3.0)])           # peau gardée : l'arrière et un morceau de crâne
    cotes(c, [-2.6, -1.8, -1.0, -0.2, 0.6, 1.4, 2.2, 3.0])
    longerons(c, -3.0, 1.2, 8)
    queue(c, intacte=False)
    ailes(c, perdues=(-1,))
    # entrailles : caisses et tuyaux noircis dans la coque ouverte
    for (x, y, z, sx, sy, sz, m) in ((-1.4, 0.2, Z0 - 0.7, 0.8, 0.7, 0.5, "armor2"), (0.0, -0.3, Z0 - 0.6, 0.6, 0.5, 0.7, "rawiron"),
                                      (-2.2, 0.1, Z0 - 0.8, 0.5, 0.5, 0.35, "armor")):
        g.box((x, y, z), (sx, sy, sz), M[m], "hard", what="entrailles")
    g.pipe([(-2.5, 0.4, Z0 - 0.3), (-1.7, 0.2, Z0 + 0.3), (-0.8, 0.5, Z0 + 0.1), (0.2, 0.3, Z0 - 0.2)], 0.05, M["steel_dk"],
           fl_mat=M["steel"], flanges=True, what="conduit")
    # dents de tôle au bord de la déchirure
    for k in range(12):
        a = TAU * (0.05 + 0.35 * k / 12)
        for x in (1.2, -3.0):
            hh = 0.12 + 0.3 * rng.random()
            r = rprof(x)
            g.box((x, r * math.cos(a), Z0 + r * math.sin(a)), (0.06, 0.22, hh), c["peau"], "hard", what="dent")
    # hublots du crâne restant
    hublots(c, -3.4, -3.0, 0.4, vitre=M["glass_dk"])
    g.pop()
    # le crâne arraché, plus loin au sud
    g.push(loc=(-1.2, -2.6, 0.5), rz=0.35)
    g.stack[-1] = g.stack[-1] @ Matrix.Rotation(0.1, 4, "X")
    xs = [X_NEZ + k * 0.38 for k in range(0, 5)]
    for i in range(len(xs) - 1):
        g.cyl(((xs[i] + xs[i + 1]) / 2 + 0.0, 0, 0), "x", rprof(xs[i]) * 0.9 + 0.001, xs[i + 1] - xs[i], c["peau"], n=24,
              r2=rprof(xs[i + 1]) * 0.9 + 0.001, style="smooth", what="crane")
    g.pop()
    # ailerons, tôles, tuyère perdue
    mats = [c["peau"], c["aile"], c["os"], M["armor"], c["bande"]]
    for k in range(22):
        a = rng.random() * TAU
        r = 1.2 + 3.0 * rng.random()
        s = (0.15 + 0.4 * rng.random(), 0.12 + 0.3 * rng.random(), 0.025)
        Rm = Matrix.Rotation(rng.random() * TAU, 3, "Z") @ Matrix.Rotation((rng.random() - 0.5) * 0.5, 3, "X")
        g.box((0.3 + r * math.cos(a), r * math.sin(a) * 0.55, 0.06), s, mats[k % len(mats)], "hard", R=Rm, what="tole")
    g.push(loc=(5.0, 1.8, 0.3), rz=0.8, ry=1.5)
    g.cyl((0, 0, 0), "z", 0.37, 0.8, c["tuy"], n=18, r2=0.2, what="tuyere_perdue")
    g.pop()
    for (x, y) in ((3.9, 0.3), (3.4, -0.5), (-0.6, 0.6)):
        g.dome((x, y, 0.12), (0, 0, 1), 0.08, M["emit"], n=7, what="braise")
        g.halo((x, y - 0.2, 0.2), M["_emit_rgb"], 2.0)
    for k in range(4):
        g.sphere((3.3 + 0.12 * k, 0.1, 1.4 + 0.4 * k), 0.2 + 0.05 * k, M["soot"], n=10, m=6, what="suie")


def age01(c):
    """Vaisseau RÉPARÉ : coque entière rapiécée, ailes, réacteurs ; cabanes de bois sur le dos, passerelle, rampe, fanion."""
    g, M, rng = c.g, c.M, c.rng
    aire(c)
    peau(c, [(X_NEZ, 3.5)])
    cotes(c, [-2.6, -1.4, -0.2, 1.0, 2.2], mat=c["os"])
    epine(c, X_NEZ + 0.1, 3.3, mat=M["wood"])
    queue(c)
    ailes(c)
    pieds(c)
    hublots(c)
    porte(c, 0.4)
    rapiece(c, ((-1.6, 45, 0.7, 0.55, "rawiron"), (1.2, 40, 0.8, 0.6, "canvas"), (2.5, 55, 0.55, 0.5, "ochre"),
                (-0.5, 12, 0.6, 0.5, "armor"), (0.2, 20, 0.5, 0.45, "canvas2"), (-2.4, 70, 0.5, 0.4, "rawiron")))
    # cabanes de bois sur le dos (entre les côtes) : parois, toit à deux pans, cheminée
    for (x0, x1, h) in ((-1.9, -0.35, 0.95), (0.35, 1.5, 0.75)):
        zb = Z0 + R - 0.08
        box(g, x0, x1, -0.6, 0.6, zb, zb + h, M["wood"], "cabane")
        pans(g, x0, x1, -0.6, 0.6, zb + h, 0.55, M["canvas"], "toit_cabane", debord=0.1)
        box(g, (x0 + x1) / 2 - 0.2, (x0 + x1) / 2 + 0.2, -0.62, -0.58, zb + 0.25, zb + 0.6, M["emit_soft"], "fenetre", style="flat")
    g.cyl((0.8, 0.3, Z0 + R + 1.35), "z", 0.08, 0.5, M["blackiron"], n=8, style="smooth", what="cheminee")
    # passerelle de bois le long du flanc sud, poteaux, garde-corps, rampe vers le sol
    ys = -(R + 0.55)
    zp = Z0 - 0.55
    box(g, -2.3, 1.7, ys - 0.3, ys + 0.3, zp, zp + 0.07, M["wood2"], "passerelle")
    for x in (-2.2, -1.0, 0.2, 1.4):
        poutre(g, (x, ys - 0.27, 0.1), (x, ys - 0.27, zp + 0.6), 0.07, M["wood"], "poteau")
        g.cyl((x, ys - 0.27, zp + 0.72), "z", 0.07, 0.14, M["emit"], n=8, style="flat", what="lanterne")
        g.halo((x, ys - 0.5, zp + 0.7), M["_emit_rgb"], 3.0)
    poutre(g, (-2.3, ys - 0.27, zp + 0.5), (1.7, ys - 0.27, zp + 0.5), 0.04, M["wood"], "lisse")
    poutre(g, (1.7, ys, zp + 0.03), (2.7, ys - 0.2, 0.12), 0.06, M["wood"], "rampe", h=0.28)
    # mât et fanion à l'avant, sur l'épine
    poutre(g, (-2.2, 0, Z0 + R), (-2.2, 0, Z0 + R + 1.4), 0.06, M["wood"], "mat")
    g.box((-2.05, 0, Z0 + R + 1.25), (0.3, 0.012, 0.16), M["redpaint"], "hard", what="fanion")
    for (x, y, s) in ((-3.0, -ty(1.4), 0.4), (3.2, -ty(1.5), 0.34), (2.2, ty(1.4), 0.34)):
        g.box((x, y, 0.1 + s / 2), (s, s, s), M["wood"], "hard", what="caisse")


def age04(c):
    """Moitié-moitié : crâne et queue de vaisseau, VENTRE en bâtiment industriel jaune et noir, côtes et épine dehors."""
    g, M = c.g, c.M
    aire(c, z=0.14)
    peau(c, [(X_NEZ, -2.1), (2.1, 3.5)])
    cotes(c, [-1.7, -0.9, -0.1, 0.7, 1.5, -2.6, 2.4])
    longerons(c, -2.1, 2.1, 6)
    epine(c, X_NEZ + 0.1, 3.3)
    queue(c)
    ailes(c)
    hublots(c)
    # le bâtiment : rez et étage, parapets, bandes noires, vitrines éclairées, porte à bandes de danger au sud
    box(g, -2.1, 2.1, -1.12, 1.12, 0.14, 2.1, M["jaune_capot"], "rez")
    for z in (0.45, 1.5):
        box(g, -2.12, 2.12, -1.14, 1.14, z, z + 0.12, M["noir_capot"], "bande_noire")
    box(g, -2.1, 2.1, -1.14, -1.1, 0.7, 1.25, M["emit_soft"], "vitrine", style="flat")
    for k in range(8):
        x = -1.9 + k * 0.55
        box(g, x - 0.02, x + 0.02, -1.16, -1.1, 0.7, 1.25, M["noir_capot"], "montant")
    box(g, -2.15, 2.15, -1.18, 1.18, 2.1, 2.22, M["noir_capot"], "parapet")
    box(g, -1.4, 1.3, -0.8, 0.8, 2.22, 2.85, M["jaune_capot"], "etage")
    box(g, -1.42, 1.32, -0.82, 0.82, 2.85, 2.95, M["noir_capot"], "toit_etage")
    box(g, -1.4, 1.3, -0.84, -0.8, 2.4, 2.7, M["emit_soft"], "vitrine_haute", style="flat")
    box(g, -0.3, 0.7, -1.2, -1.14, 0.14, 1.0, M["noir_capot"], "porte_sud")
    for k in range(7):
        box(g, -0.3 + k * 0.14, -0.3 + (k + 1) * 0.14, -1.22, -1.18, 0.14, 0.35, M["hazy"] if k % 2 else M["hazk"], "danger")
    # portique : tour d'acier à l'arrière-nord, mât radio et feux
    for sx in (-1, 1):
        for sy in (-1, 1):
            poutre(g, (-2.6 + sx * 0.3, 1.9 + sy * 0.3, 0.14), (-2.6 + sx * 0.3, 1.9 + sy * 0.3, 4.2), 0.09, M["steel_dk"], "montant")
    for z in (1.0, 2.0, 3.0, 4.0):
        for (a, b) in (((-0.3, -0.3), (0.3, -0.3)), ((0.3, -0.3), (0.3, 0.3)), ((0.3, 0.3), (-0.3, 0.3)), ((-0.3, 0.3), (-0.3, -0.3))):
            poutre(g, (-2.6 + a[0], 1.9 + a[1], z), (-2.6 + b[0], 1.9 + b[1], z + 0.0), 0.06, M["steel_dk"], "entretoise")
        poutre(g, (-2.9, 1.6, z - 1.0), (-2.3, 2.2, z), 0.04, M["steel_dk"], "croisillon")
    poutre(g, (-2.6, 1.9, 4.2), (-2.6, 1.9, 5.0), 0.05, M["steel"], "mat_radio")
    g.dome((-2.6, 1.9, 5.05), (0, 0, 1), 0.05, M["emit"], what="feu_mat")
    # torchère à l'est, côté nord
    poutre(g, (2.8, 2.2, 0.14), (2.8, 2.2, 2.3), 0.07, M["noir_capot"], "mat_torchere")
    g.cyl((2.8, 2.2, 2.6), "z", 0.14, 0.55, M["amber"], n=10, r2=0.0, style="flat", what="flamme")
    g.halo((2.8, 2.0, 2.6), M["_emit_rgb"], 4.0)
    # deux cuves au sud, jaunes cerclées de noir, tuyaux vers le bâtiment
    for k, x in enumerate((-1.3, 0.9)):
        y = -2.2
        g.cyl((x, y, 0.14 + 0.4), "x", 0.4, 1.7, M["jaune_capot"], n=24, style="smooth", what="cuve")
        for dx in (-0.55, 0.55):
            g.tube_shell((x + dx, y, 0.54), "x", 0.415, 0.39, 0.07, M["noir_capot"], n=24, what="cercle_cuve")
        g.pipe([(x, y + 0.4, 0.8), (x + 0.1, -1.6, 1.0), (x + 0.1, -1.25, 1.1)], 0.05, M["noir_capot"], fl_mat=M["steel"],
               flanges=True, what="tuyau")
    # hangars sur les ailes : boîtes jaunes
    for sg in (-1, 1):
        box(g, 1.6, 2.5, sg * 1.7, sg * 2.3, Z0 - 0.23, Z0 + 0.45, M["jaune_capot"], "hangar_aile")
        box(g, 1.55, 2.55, sg * 1.65, sg * 2.35, Z0 + 0.45, Z0 + 0.55, M["noir_capot"], "toit_hangar")
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.dome((sx * 3.8, sy * 2.5, 0.2), (0, 0, 1), 0.08, M["amber"], n=7, what="feu_aire")


def age08(c):
    """Bâtiment, coque visible aux deux bouts : grande halle de bois et de vert-de-gris sur pilotis, côtes en arches au-dessus
    du toit, épine en faîtière ; crâne vitré, tuyères en pied ; ailes devenues galeries, bocaux verts aux bouts d'aile."""
    g, M = c.g, c.M
    hp = 0.55
    zb = hp + 0.12
    # plate-forme sur pilotis
    box(g, -4.0, 4.0, -2.75, 2.75, hp, zb, M["bois_mouille"], "plateforme")
    for sy in (-1, 1):
        box(g, -4.0, 4.0, sy * 2.7, sy * 2.75, zb, zb + 0.06, M["bois_mousse"], "bord")
    for x in [-3.8 + 0.95 * k for k in range(9)]:
        for y in (-2.65, 0.0, 2.65):
            g.cyl((x, y, hp / 2), "z", 0.08, hp, M["bois_mouille"], n=8, style="smooth", what="pilotis")
    g.push((0, 0, hp + 0.0))
    peau(c, [(X_NEZ, -2.4), (2.5, 3.5)])
    # côtes qui dépassent du toit : anneaux pleins sur toute la halle
    cotes(c, [-1.9, -1.1, -0.3, 0.5, 1.3, 2.1], k=1.0)
    cotes(c, [-2.7, 2.9])
    epine(c, X_NEZ + 0.1, 3.3, mat=M["cuivre_terni"], w=0.2)
    queue(c)
    hublots(c, -3.4, -2.6, 0.4, vitre=M["verre_toxique"])
    g.pop()
    # halle : parois de bois flotté, étage de vert-de-gris, toit à deux pans, galerie sud sur pilotis
    box(g, -2.4, 2.6, -1.75, 1.75, zb, zb + 1.25, M["bois_mouille"], "halle")
    box(g, -2.45, 2.65, -1.8, 1.8, zb + 1.25, zb + 1.35, M["cuivre_terni"], "corniche")
    pans(g, -2.4, 2.6, -1.75, 1.75, zb + 1.35, 0.8, M["brick2"], "toit_halle", debord=0.12)
    for k in range(18):
        x = -2.35 + 0.28 * k
        for sg in (-1, 1):
            poutre(g, (x, sg * 1.87, zb + 1.33), (x, 0.0, zb + 2.17), 0.02, M["seam"], "ligne_tuile", h=0.02)
    poutre(g, (-2.52, 0, zb + 2.17), (2.72, 0, zb + 2.17), 0.1, M["brick"], "faitage", h=0.1)
    for (x, y) in ((-1.2, 0.7), (1.6, -0.6)):
        box(g, x - 0.18, x + 0.18, y - 0.18, y + 0.18, zb + 1.5, zb + 2.55, M["brick"], "cheminee")
        box(g, x - 0.22, x + 0.22, y - 0.22, y + 0.22, zb + 2.55, zb + 2.65, M["steel_dk"], "chapeau_cheminee")
    for k in range(8):
        x = -2.0 + k * 0.62
        box(g, x - 0.17, x + 0.17, -1.8, -1.75, zb + 0.45, zb + 1.05, M["emit_soft"], "fenetre", style="flat")
    box(g, -0.3, 0.5, -1.82, -1.74, zb, zb + 0.9, M["bois_mousse"], "porte")
    box(g, -2.4, 2.6, -2.35, -1.75, zb + 0.5, zb + 0.56, M["bois_mousse"], "galerie")
    for x in [-2.3 + 0.5 * k for k in range(11)]:
        poutre(g, (x, -2.3, zb), (x, -2.3, zb + 0.5), 0.05, M["bois_mouille"], "pieu_galerie")
    poutre(g, (-2.4, -2.3, zb + 1.0), (2.6, -2.3, zb + 1.0), 0.04, M["bois_mouille"], "lisse")
    # serre de verre sur le faîte
    g.sphere((0.1, 0.0, zb + 2.0), 0.75, M["verre_toxique"], n=24, m=12, scale=(1.3, 0.9, 0.8), what="serre")
    for k in range(6):
        g.cyl((0.1 + 0.3 * math.cos(TAU * k / 6), 0.25 * math.sin(TAU * k / 6), zb + 1.7), "z", 0.1, 0.4, M["emit"], n=7, r2=0.0, style="flat", what="pousse")
    g.halo((0.1, -0.5, zb + 1.9), M["_emit_rgb"], 5.0)
    # ailes en galeries : pont de bois, balustrade, bocal vert au bout
    for sg in (-1, 1):
        z = zb + 0.0
        box(g, 0.8, 2.6, sg * 1.8, sg * 2.5, z, z + 0.2, M["bois_mouille"], "galerie_aile")
        box(g, 0.8, 2.6, sg * 2.45, sg * 2.5, z + 0.2, z + 0.5, M["bois_mousse"], "garde_corps")
        g.cyl((3.0, sg * 2.5, z + 0.55), "z", 0.36, 1.0, M["verre_toxique"], n=20, style="smooth", what="bocal")
        g.cyl((3.0, sg * 2.5, z + 0.4), "z", 0.3, 0.7, M["emit"], n=20, style="flat", what="liquide")
        g.cyl((3.0, sg * 2.5, z + 1.08), "z", 0.38, 0.06, M["cuivre_terni"], n=20, style="hard", what="couvercle")
        g.halo((3.0, sg * 2.5 - 0.4, z + 0.6), M["_emit_rgb"], 4.0)
    # roseaux au pied de la plate-forme
    for k in range(30):
        a = c.rng.random() * TAU
        r = 4.3 + 0.4 * c.rng.random()
        g.cyl((r * math.cos(a), r * math.sin(a) * 0.62, 0.25), "z", 0.035, 0.5, M["bois_mousse"], n=5, r2=0.005, what="roseau")
    # escalier du sud
    for k in range(5):
        box(g, -0.4, 0.5, -2.75 - 0.2 * (k + 1), -2.75 - 0.2 * k, hp - 0.1 * (k + 1) + 0.0, hp + 0.0 - 0.1 * k + 0.06, M["bois_mouille"], "marche")


def age15(c):
    """Citadelle : halle noire à créneaux et bandes d'or, donjon étagé au centre, tours aux bouts d'aile ; côtes en grandes
    arches d'or, épine en faîtière d'or, crâne noir en proue, tuyères d'or en pied ; sphère noire sur le donjon."""
    g, M = c.g, c.M
    # aire noire à liserés incandescents
    box(g, -4.0, 4.0, -2.8, 2.8, 0.0, 0.16, M["concrete"], "aire")
    for sy in (-1, 1):
        box(g, -3.95, 3.95, sy * 2.7, sy * 2.74, 0.16, 0.19, M["emit"], "lisere", style="flat")
    for sx in (-1, 1):
        box(g, sx * 3.95, sx * 3.95 + 0.04 * sx, -2.74, 2.74, 0.16, 0.19, M["emit"], "lisere", style="flat")
    peau(c, [(X_NEZ, -2.5), (3.0, 3.5)])
    cotes(c, [-3.0, 3.1])
    queue(c)
    hublots(c, -3.4, -2.8, 0.4, vitre=M["emit_soft"])
    # grandes arches d'or : les côtes, plus grandes que la coque, à cheval sur la halle
    for x in (-1.8, -0.8, 0.2, 1.2, 2.2):
        g.tube_shell((x, 0, Z0), "x", 2.15, 2.0, 0.17, M["or_blanc_chaud"], n=36, what="arche")
    # épine : faîtière d'or sur les arches
    poutre(g, (-2.3, 0, Z0 + 2.15), (2.6, 0, Z0 + 2.15), 0.3, M["or_blanc_chaud"], "epine", h=0.24)
    poutre(g, (-3.8, 0, Z0 + 0.15 * R), (-2.3, 0, Z0 + 2.15), 0.14, M["or_chauffe"], "epine_crane", h=0.14)
    # halle noire à créneaux
    box(g, -2.3, 2.8, -1.85, 1.85, 0.16, 2.2, M["noir_chaud"], "halle")
    for z in (0.7, 1.6):
        box(g, -2.32, 2.82, -1.87, 1.87, z, z + 0.1, M["or_chauffe"], "bande_or")
    box(g, -2.3, 2.8, -1.9, -1.84, 1.0, 1.4, M["emit_soft"], "meurtriere", style="flat")
    for k in range(12):
        x = -2.2 + 0.43 * k
        box(g, x - 0.02, x + 0.02, -1.92, -1.84, 1.0, 1.4, M["noir_profond"], "montant")
    for k in range(13):
        x = -2.3 + 0.4 * k
        for sy in (-1, 1):
            box(g, x, x + 0.22, sy * 1.7, sy * 1.85, 2.2, 2.5, M["noir_chaud2"], "creneau")
    box(g, -0.4, 0.6, -1.95, -1.84, 0.16, 1.3, M["noir_profond"], "porte")
    box(g, -0.5, 0.7, -1.97, -1.9, 1.3, 1.4, M["or_chauffe"], "linteau")
    # contreforts clairs sur la façade sud de la halle
    for k in range(7):
        x = -2.1 + 0.8 * k
        box(g, x - 0.1, x + 0.1, -2.05, -1.84, 0.16, 2.2, M["or_blanc_chaud"], "pilastre")
    # donjon étagé (octogonal) sur la halle
    for (r, z0_, z1_, m) in ((1.45, 2.2, 3.2, "or_chauffe"), (1.05, 3.2, 4.0, "noir_chaud2"), (0.65, 4.0, 4.6, "or_blanc_chaud")):
        g.cyl((0.35, 0, (z0_ + z1_) / 2), "z", r, z1_ - z0_, M[m], n=8, style="hard", phase=math.pi / 8, what="donjon")
        g.tube_shell((0.35, 0, z1_), "z", r + 0.07, r - 0.02, 0.12, M["or_chauffe"], n=8, what="corniche_donjon")
    for k in range(8):
        a = TAU * k / 8
        g.box((0.35 + 1.46 * math.cos(a) * 0.93, 1.46 * math.sin(a) * 0.93, 2.9), (0.05, 0.3, 0.5), M["emit_soft"], "flat",
              R=Matrix.Rotation(a, 3, "Z"), what="fente")
    poutre(g, (0.35, 0, 4.6), (0.35, 0, 5.2), 0.1, M["or_chauffe"], "fleche")
    g.sphere((0.35, 0, 5.5), 0.33, M["noir_profond"], n=28, m=14, what="sphere_noire")
    g.torus((0.35, 0, 5.5), "z", 0.36, 0.016, M["emit"], n=36, m=6, what="equateur")
    g.halo((0.35, -0.5, 5.45), M["_emit_rgb"], 5.0)
    # tours aux bouts d'aile (nord et sud), reliées par un mur de contrefort
    for sg in (-1, 1):
        box(g, -0.2, 2.8, sg * 1.85, sg * 2.2, 0.16, 1.5, M["noir_chaud2"], "contrefort")
        box(g, -0.2, 2.8, sg * 1.83, sg * 2.22, 1.5, 1.6, M["or_chauffe"], "bande_contrefort")
        g.cyl((3.0, sg * 2.45, 1.3), "z", 0.42, 2.3, M["noir_chaud2"], n=10, style="hard", what="tour")
        g.tube_shell((3.0, sg * 2.45, 2.45), "z", 0.5, 0.38, 0.14, M["or_chauffe"], n=10, what="corniche_tour")
        g.cyl((3.0, sg * 2.45, 3.0), "z", 0.5, 0.9, M["or_chauffe"], n=10, r2=0.0, style="hard", what="toit_tour")
        g.dome((3.0, sg * 2.45, 3.45), (0, 0, 1), 0.07, M["emit"], n=6, what="feu_tour")
        g.halo((3.0, sg * 2.45 - 0.3, 2.0), M["_emit_rgb"], 3.0)
    # crâne : proue noire, anneau d'or
    g.torus((-3.0, 0, Z0), "x", rprof(-3.0) + 0.04, 0.03, M["or_chauffe"], n=28, m=6, what="collier_proue")
    # obélisques d'or aux quatre coins
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * 3.75, sy * 2.55
            g.cyl((x, y, 0.16 + 0.75), "z", 0.17, 1.5, M["or_chauffe"], n=4, r2=0.05, phase=math.pi / 4, style="hard", what="obelisque")
            g.dome((x, y, 1.7), (0, 0, 1), 0.06, M["emit"], n=6, what="pointe")


MODULES = {0: epave, 1: age01, 4: age04, 8: age08, 15: age15}
LARGEUR_AGE = {0: 4, 1: 4, 4: 5, 8: 6, 15: 8}


def vaisseau(g, e):
    c = Ctx(g, e)
    s = LARGEUR_AGE[e] / LARGEUR
    g.push((0, 0, 0))
    g.stack[-1] = g.stack[-1] @ Matrix.Diagonal((s, s, 1.0 + 0.6 * (s - 1.0), 1.0))
    MODULES[e](c)
    g.pop()
