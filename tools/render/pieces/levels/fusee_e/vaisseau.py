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
KX, DX = 0.9, -0.45          # compression en x et décalage : le vaisseau (x de -3,9 à 4,9) tient dans l'emprise (x de -4 à 4)
XC, HX = 0.5, 4.44           # centre et demi-longueur de l'aire dans le repère local (avant compression)


def ty(t):
    return t * SQ2


def rprof(x):
    if x <= X_NEZ:
        return 0.0
    if x < -1.4:
        t = (-1.4 - x) / (-1.4 - X_NEZ)
        return R * (1 - t ** 1.6) ** 0.6
    if x <= 1.6:
        return R
    if x <= 3.0:
        return R * (1 - 0.3 * (x - 1.6) / 1.4)
    return 0.7 * R


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


def box(g, x0, x1, y0, y1, z0, z1, m, what="bloc", style="soft"):
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
    0: dict(peau=("peau_prop",), bande=("hazk",), os=("rawiron",), aile=("hazy",), tuy=("armor2",), mur=("armor",),
            mur2=("rawiron",), toit=("wood2",), pad=("concrete",), pad2=("armor2",), acc=("redpaint",), vit=("glass_dk",)),
    1: dict(peau=("peau_prop",), bande=("armor2",), os=("wood",), aile=("redpaint",), tuy=("rawiron",), mur=("wood",),
            mur2=("wood2",), toit=("canvas",), pad=("wood2",), pad2=("wood",), acc=("cream",), vit=("emit_soft",)),
    4: dict(peau=("peau_prop",), bande=("noir_capot",), os=("noir_capot",), aile=("redpaint",), tuy=("galva",),
            mur=("jaune_capot",), mur2=("noir_capot",), toit=("noir_capot",), pad=("concrete",),
            pad2=("noir_capot",), acc=("noir_capot",), vit=("emit_soft",)),
    8: dict(peau=("peau_prop",), bande=("cuivre_terni",), os=("steel_dk",), aile=("vdg_capot",),
            tuy=("steel_dk",), mur=("bois_mouille",), mur2=("bois_mousse",), toit=("vdg_capot",),
            pad=("bois_mouille",), pad2=("bois_mousse",), acc=("cuivre_terni",), vit=("verre_toxique",)),
    15: dict(peau=("peau_prop",), bande=("noir_chaud",), os=("or_blanc_chaud",), aile=("noir_chaud2",),
             tuy=("or_chauffe",), mur=("noir_chaud",), mur2=("noir_chaud2",), toit=("noir_chaud2",),
             pad=("concrete",), pad2=("noir_chaud2",), acc=("or_vif",), vit=("noir_profond",)),
}


class Ctx:
    def __init__(self, g, e):
        self.g, self.M, self.e, self.rng = g, g.M, e, g.rng
        self.P = {k: mk(g.M, *v) for k, v in (PAL[e] if e in PAL else pal_gen(e, g.M)).items()}

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
            if k % 2 == 1 and rb > 0.5:
                g.torus((xb, 0, Z0), "x", rb + 0.004, 0.012, M["seam"], n=28, m=5, what="joint")
                for j in range(28):
                    a = TAU * (j + 0.5) / 28
                    g.dome((xb - 0.07, rb * math.cos(a), Z0 + rb * math.sin(a)), (0, math.cos(a), math.sin(a)), 0.016, M["rivet"], n=6)
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
    # verrière du cockpit : bulle de verre sombre sertie d'un cadre d'acier, sur le dessus du crâne
    r = rprof(-2.6)
    g.sphere((-2.6, 0, Z0 + r - 0.1), 0.6, M["glass_dk"], n=24, m=12, scale=(1.35, 0.75, 0.5), what="verriere")
    for dx in (-0.45, 0.0, 0.45):
        poutre(g, (-2.6 + dx, -0.42, Z0 + r - 0.08), (-2.6 + dx, 0.42, Z0 + r - 0.08), 0.03, M["steel_hi"], "meneau", h=0.5)
    g.dome((-2.2, -0.2, Z0 + r + 0.08), (0, 0, 1), 0.05, M["emit_soft"], n=6, what="voyant_cockpit")


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


def ailes(c, portee=2.75, ep=0.14, z=None, mat=None, perdues=()):
    g = c.g
    z = Z0 - 0.3 if z is None else z
    for sg in (-1, 1):
        if sg in perdues:
            continue
        pts = [(-2.3, sg * R * 0.8), (3.1, sg * R * 0.8), (3.5, sg * portee), (2.3, sg * portee)]
        lo = [(x, y, z - ep / 2) for x, y in pts]
        hi = [(x, y, z + ep / 2) for x, y in pts]
        g.hexa(lo + hi, mat or c["aile"], "hard", "aile")
        poutre(g, (2.3, sg * portee, z), (-2.3, sg * R * 0.8, z), 0.09, c["acc"], "chant_aile", h=ep + 0.03)
        poutre(g, (3.5, sg * portee, z), (3.1, sg * R * 0.8, z), 0.07, c["bande"], "bord_fuite", h=0.17)
        g.cyl((3.0, sg * (portee - 0.35), z + 0.1), "x", 0.17, 0.9, c["tuy"], n=14, r2=0.22, style="smooth", what="nacelle")
    for sg in (-1, 1):
        if sg in perdues:
            continue
        # canards près du nez
        cp = [(-1.9, sg * 0.95), (-1.35, sg * 0.95), (-1.65, sg * 1.95), (-2.45, sg * 1.95)]
        g.hexa([(x, y, Z0 - 0.15) for x, y in cp] + [(x, y, Z0 - 0.03) for x, y in cp], mat or c["aile"], "hard", "canard")
        # dérive d'extrémité (winglet)
        xs_ = [(2.3, 0.0), (3.5, 0.0), (3.5, 0.95), (2.9, 0.95)]
        g.hexa([(x, sg * portee - 0.05, z + h_) for x, h_ in xs_] + [(x, sg * portee + 0.05, z + h_) for x, h_ in xs_],
               mat or c["aile"], "hard", "winglet")
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
    surf(g, x, th, 0.78, 0.82, 0.04, c["mur2"] if c.e else M["void"], "vantail", dr=0.05)
    if c.e:
        surf(g, x, math.radians(70), 0.4, 0.22, 0.03, M["emit_soft"], "oculus_porte", dr=0.09)
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


def joints_aire(c, x0, x1, y, z, pas=1.0):
    """Joints de dalles sur une aire : un trait sombre tous les `pas` en x et en y (pas constant, grille régulière)."""
    g, M = c.g, c.M
    n = int((x1 - x0) / pas)
    for k in range(1, n):
        x = x0 + k * (x1 - x0) / n
        box(g, x - 0.012, x + 0.012, -y + 0.05, y - 0.05, z, z + 0.012, M["seam"], "joint_aire", style="flat")
    m = int(2 * y / pas)
    for k in range(1, m):
        yy = -y + k * 2 * y / m
        box(g, x0 + 0.05, x1 - 0.05, yy - 0.012, yy + 0.012, z, z + 0.012, M["seam"], "joint_aire", style="flat")


def aire(c, x0=XC - HX, x1=XC + HX, y=None, z=0.1, plan="rect"):
    g = c.g
    y = y if y is not None else ty(2.0) - 0.05
    box(g, x0, x1, -y, y, 0.0, z, c["pad"], "aire")
    for sy in (-1, 1):
        box(g, x0, x1, sy * (y - 0.05), sy * y, z, z + 0.05, c["pad2"], "bord_aire")
    for xe in (x0, x1):
        box(g, xe - 0.025, xe + 0.025, -y, y, z, z + 0.05, c["pad2"], "bord_aire")
    joints_aire(c, x0, x1, y, z)


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
    longerons(c, -3.0, 1.2, 6)
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
        box(g, x0, x1, -0.6, 0.6, Z0 + 0.8, zb + h, M["wood"], "cabane")
        pans(g, x0, x1, -0.6, 0.6, zb + h, 0.55, M["canvas"], "toit_cabane", debord=0.1)
        poutre(g, (x0 - 0.1, 0, zb + h + 0.55), (x1 + 0.1, 0, zb + h + 0.55), 0.07, M["wood"], "faitage", h=0.07)
        n = max(3, int((x1 - x0) / 0.3))
        for k in range(n + 1):
            xr = x0 - 0.1 + (x1 - x0 + 0.2) * k / n
            for sg in (-1, 1):
                poutre(g, (xr, sg * 0.7, zb + h - 0.03), (xr, 0, zb + h + 0.55), 0.04, M["wood"], "chevron", h=0.04)
        xm = (x0 + x1) / 2
        box(g, xm - 0.26, xm + 0.26, -0.64, -0.6, zb + 0.2, zb + 0.66, M["wood2"], "cadre_fenetre")
        box(g, xm - 0.2, xm + 0.2, -0.66, -0.62, zb + 0.26, zb + 0.6, M["emit_soft"], "fenetre", style="flat")
        box(g, xm - 0.01, xm + 0.01, -0.67, -0.63, zb + 0.26, zb + 0.6, M["wood2"], "croisillon")
    g.cyl((0.8, 0.3, Z0 + R + 1.35), "z", 0.08, 0.5, M["blackiron"], n=8, style="smooth", what="cheminee")
    # passerelle de bois le long du flanc sud, poteaux, garde-corps, rampe vers le sol
    ys = -(R + 0.55)
    zp = Z0 - 0.55
    box(g, -2.3, 1.7, ys - 0.3, ys + 0.3, zp, zp + 0.07, M["wood2"], "passerelle")
    for x in (-2.2, -1.0, 0.2, 1.4):
        poutre(g, (x, ys - 0.27, 0.1), (x, ys - 0.27, zp + 0.6), 0.07, M["wood"], "poteau")
        g.cyl((x, ys - 0.27, zp + 0.72), "z", 0.07, 0.14, M["emit"], n=8, style="flat", what="lanterne")
        g.halo((x, ys - 0.5, zp + 0.7), M["_emit_rgb"], 3.0)
    poutre(g, (-2.3, ys - 0.27, zp + 0.5), (1.7, ys - 0.27, zp + 0.5), 0.07, M["wood"], "lisse")
    poutre(g, (-2.3, ys, zp + 0.03), (-3.3, ys - 0.1, 0.12), 0.06, M["wood"], "rampe", h=0.28)
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
    cotes(c, [-1.7, -0.9, -0.1, 0.7, 1.5, -2.6, 2.4], mat=M["steel_hi"], ep=0.13)
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
    for x in (-1.7, -0.9, -0.1, 0.7, 1.5):
        box(g, x - 0.03, x + 0.03, -1.16, -1.1, 0.7, 1.25, M["noir_capot"], "montant")
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
    for zb_ in (1.0, 2.0, 3.0):                       # bras de liaison portique -> halle et côtes, avec consoles inclinées
        poutre(g, (-2.35, 1.7, zb_), (-1.95, 1.12, zb_), 0.12, M["noir_capot"], "bras_portique", h=0.14)
        poutre(g, (-2.6, 1.9, zb_ - 0.6), (-2.0, 1.15, zb_ - 0.05), 0.07, M["noir_capot"], "console_portique")
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
            box(g, x + dx - 0.06, x + dx + 0.06, y - 0.3, y + 0.3, 0.14, 0.34, M["noir_capot"], "cale")
        g.pipe([(x, y + 0.4, 0.8), (x + 0.1, -1.7, 1.0), (x + 0.1, -1.14, 1.1)], 0.05, M["noir_capot"], fl_mat=M["steel"],
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
    box(g, XC - HX, XC + HX, -2.75, 2.75, hp, zb, M["bois_mouille"], "plateforme")
    for sy in (-1, 1):
        box(g, XC - HX, XC + HX, sy * 2.7, sy * 2.75, zb, zb + 0.06, M["bois_mousse"], "bord")
    for x in [XC - HX + 0.2 + 0.8 * k for k in range(12)]:
        for y in (-2.65, 0.0, 2.65):
            g.cyl((x, y, hp / 2), "z", 0.08, hp, M["bois_mouille"], n=8, style="smooth", what="pilotis")
    g.push((0, 0, hp + 0.0))
    peau(c, [(X_NEZ, -2.4), (2.5, 3.5)])
    # côtes qui dépassent du toit : anneaux pleins sur toute la halle
    cotes(c, [-1.9, -1.1, -0.3, 0.5, 1.3, 2.1], k=1.0)
    cotes(c, [-2.7, 2.9])
    epine(c, X_NEZ + 0.1, 3.3, mat=M["steel_hi"], w=0.18)
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
    for k in range(5):
        x = -1.5 + k * 0.8
        box(g, x - 0.22, x + 0.22, -1.8, -1.75, zb + 0.45, zb + 1.05, M["emit_soft"], "fenetre", style="flat")
        box(g, x - 0.26, x + 0.26, -1.82, -1.78, zb + 0.42, zb + 0.46, M["bois_mousse"], "appui")
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
        g.cyl((3.0, sg * 2.3, z + 0.55), "z", 0.36, 1.0, M["verre_toxique"], n=20, style="smooth", what="bocal")
        g.cyl((3.0, sg * 2.3, z + 0.4), "z", 0.3, 0.7, M["emit"], n=20, style="flat", what="liquide")
        g.cyl((3.0, sg * 2.3, z + 1.08), "z", 0.38, 0.06, M["cuivre_terni"], n=20, style="hard", what="couvercle")
        g.halo((3.0, sg * 2.3 - 0.4, z + 0.6), M["_emit_rgb"], 4.0)
    # escalier du sud
    for k in range(5):
        box(g, -0.4, 0.5, -2.75 - 0.2 * (k + 1), -2.75 - 0.2 * k, hp - 0.1 * (k + 1) + 0.0, hp + 0.0 - 0.1 * k + 0.06, M["bois_mouille"], "marche")


def age15(c):
    """Citadelle : halle noire à créneaux et bandes d'or, donjon étagé au centre, tours aux bouts d'aile ; côtes en grandes
    arches d'or, épine en faîtière d'or, crâne noir en proue, tuyères d'or en pied ; sphère noire sur le donjon."""
    g, M = c.g, c.M
    # aire noire à liserés incandescents
    box(g, XC - HX, XC + HX, -2.8, 2.8, 0.0, 0.16, M["concrete"], "aire")
    for sy in (-1, 1):
        box(g, XC - HX + 0.05, XC + HX - 0.05, sy * 2.7, sy * 2.74, 0.16, 0.19, M["emit"], "lisere", style="flat")
    for sx in (-1, 1):
        box(g, XC + sx * (HX - 0.05), XC + sx * (HX - 0.05) + 0.04 * sx, -2.74, 2.74, 0.16, 0.19, M["emit"], "lisere", style="flat")
    peau(c, [(X_NEZ, -2.5), (3.0, 3.5)])
    cotes(c, [-3.0, 3.1])
    queue(c)
    hublots(c, -3.4, -2.8, 0.4, vitre=M["emit_soft"])
    # grandes arches d'or : les côtes, plus grandes que la coque, à cheval sur la halle
    for x in (-1.8, -0.8, 0.2, 1.2, 2.2):
        g.tube_shell((x, 0, Z0), "x", 1.95, 1.8, 0.17, M["or_chauffe"], n=36, what="arche")
        for sy in (-1, 1):                      # consoles : l'arche repose sur le mur par un sabot d'or visible
            box(g, x - 0.17, x + 0.17, sy * 1.74, sy * 2.08, 1.95, 2.45, M["or_blanc_chaud"], "console")
            box(g, x - 0.24, x + 0.24, sy * 1.7, sy * 2.12, 2.4, 2.5, M["or_chauffe"], "sabot")
    # épine : faîtière d'or posée sur le sommet des arches (de la première à la dernière), puis crête vers le crâne
    poutre(g, (-1.8, 0, Z0 + 1.95), (2.2, 0, Z0 + 1.95), 0.3, M["or_blanc_chaud"], "epine", h=0.24)
    poutre(g, (-3.7, 0, Z0 + 0.2 * R), (-1.8, 0, Z0 + 1.95), 0.16, M["or_chauffe"], "epine_crane", h=0.16)
    for x in (-2.8, -2.3):
        zc = Z0 + 0.2 * R + (Z0 + 1.95 - Z0 - 0.2 * R) * (x + 3.7) / 1.9
        poutre(g, (x, 0, 2.0), (x, 0, zc - 0.05), 0.1, M["or_chauffe"], "pilier_epine")
    # halle noire à créneaux
    box(g, -2.3, 2.8, -1.85, 1.85, 0.16, 2.2, M["noir_chaud"], "halle")
    for z in (0.7, 1.6):
        box(g, -2.32, 2.82, -1.87, 1.87, z, z + 0.1, M["or_chauffe"], "bande_or")
    box(g, -2.3, 2.8, -1.9, -1.84, 1.0, 1.4, M["emit_soft"], "meurtriere", style="flat")
    for k in range(11):
        x = -2.05 + 0.5 * k
        box(g, x - 0.02, x + 0.02, -1.92, -1.84, 1.0, 1.4, M["noir_profond"], "montant")
    for k in range(10):
        x = -2.3 + 0.5 * k
        for sy in (-1, 1):
            box(g, x, x + 0.25, sy * 1.7, sy * 1.85, 2.2, 2.5, M["noir_chaud2"], "creneau")
    box(g, -0.4, 0.6, -1.95, -1.84, 0.16, 1.3, M["noir_profond"], "porte")
    box(g, -0.5, 0.7, -1.97, -1.9, 1.3, 1.4, M["or_chauffe"], "linteau")
    # contreforts clairs sur la façade sud de la halle
    for x in (-1.8, -0.8, 0.2, 1.2, 2.2):
        box(g, x - 0.1, x + 0.1, -2.05, -1.84, 0.16, 2.2, M["or_blanc_chaud"], "pilastre")
    # donjon étagé (octogonal) sur la halle
    for (r, z0_, z1_, m) in ((1.45, 2.2, 3.2, "or_chauffe"), (1.05, 3.2, 4.0, "noir_chaud2"), (0.65, 4.0, 4.6, "or_chauffe")):
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
        g.cyl((3.0, sg * 2.3, 1.3), "z", 0.42, 2.3, M["noir_chaud2"], n=10, style="hard", what="tour")
        g.tube_shell((3.0, sg * 2.3, 2.45), "z", 0.5, 0.38, 0.14, M["or_chauffe"], n=10, what="corniche_tour")
        g.cyl((3.0, sg * 2.3, 3.0), "z", 0.5, 0.9, M["or_chauffe"], n=10, r2=0.0, style="hard", what="toit_tour")
        g.dome((3.0, sg * 2.3, 3.45), (0, 0, 1), 0.07, M["emit"], n=6, what="feu_tour")
        g.halo((3.0, sg * 2.3 - 0.3, 2.0), M["_emit_rgb"], 3.0)
    # crâne : proue noire, anneau d'or
    g.torus((-3.0, 0, Z0), "x", rprof(-3.0) + 0.04, 0.03, M["or_chauffe"], n=28, m=6, what="collier_proue")
    # obélisques d'or aux quatre coins
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = XC + sx * (HX - 0.4), sy * 2.5
            g.cyl((x, y, 0.16 + 0.75), "z", 0.17, 1.5, M["or_chauffe"], n=4, r2=0.05, phase=math.pi / 4, style="hard", what="obelisque")
            g.dome((x, y, 1.7), (0, 0, 1), 0.06, M["emit"], n=6, what="pointe")


# ------------------------------------------------------------------------------------------------
# Âges génériques (2, 3, 5, 6, 7, 9 à 14) : une halle sur la carcasse, un module propre à l'âge
# ------------------------------------------------------------------------------------------------
# a : demi-longueur de la halle (la peau du ventre manque de -a à a) ; hw : demi-largeur ; h : hauteurs des niveaux
# (le niveau suivant est plus étroit) ; toit ; ailes ; ra : rayon des côtes (> R : arches sur consoles) ; zrib : côtes
GEN = {
    2: dict(a=0.0, hw=0.0, h=(), toit="pans", ailes="delta", ra=R),
    3: dict(a=1.0, hw=1.0, h=(1.4,), toit="pans", ailes="delta", ra=R),
    5: dict(a=2.2, hw=1.2, h=(1.9, 0.7), toit="crenele", ailes="delta", ra=R),
    6: dict(a=2.3, hw=1.3, h=(2.0, 0.7), toit="plat", ailes="galerie", ra=R),
    7: dict(a=2.4, hw=1.4, h=(1.8, 0.6, 0.5), toit="gradins", ailes="galerie", ra=R),
    9: dict(a=2.5, hw=1.55, h=(2.0, 0.7), toit="coupole", ailes="galerie", ra=R),
    10: dict(a=2.6, hw=1.65, h=(2.1, 0.8), toit="plat", ailes="galerie", ra=R),
    11: dict(a=2.7, hw=1.7, h=(2.1, 0.8), toit="plat", ailes="galerie", ra=R),
    12: dict(a=2.8, hw=1.75, h=(2.15, 0.8), toit="coupole", ailes="contrefort", ra=1.7, toit_mat="noir_miroir"),
    13: dict(a=2.8, hw=1.8, h=(2.2, 0.8), toit="plat", ailes="contrefort", ra=1.85),
    14: dict(a=2.9, hw=1.85, h=(2.2, 0.9), toit="plat", ailes="contrefort", ra=1.95),
}


def ribs_gen(c, a, ra, zroof, mat, console=None):
    """Côtes à pas constant 0,8 sur toute la halle (anneaux ; arches sur consoles quand ra > R)."""
    g, M = c.g, c.M
    xs = []
    x = -a + 0.4
    while x <= a - 0.4 + 1e-6:
        xs.append(round(x, 3))
        x += 0.8
    for x in xs:
        g.tube_shell((x, 0, Z0), "x", ra + 0.08, ra - 0.04, 0.13 if ra == R else 0.17, mat, n=36, what="cote")
        if console is not None and ra > R + 0.05 and abs(zroof - Z0) < ra:
            yc = math.sqrt(ra * ra - (zroof - Z0) ** 2)
            for sy in (-1, 1):
                box(g, x - 0.2, x + 0.2, sy * (yc - 0.22), sy * (yc + 0.22), zroof - 0.3, zroof + 0.3, console, "console")
                box(g, x - 0.27, x + 0.27, sy * (yc - 0.28), sy * (yc + 0.28), zroof + 0.28, zroof + 0.38, c["bande"], "sabot")
    return xs


def ailes_galerie(c, S, tours=False, xs=()):
    """Flancs devenus galeries : un pont plat le long de la halle (poteaux et balustres au pas de 0,8, main courante),
    puis, aux âges 12 à 14, contreforts pleins aux côtes et tours d'angle."""
    g, M = c.g, c.M
    a, hw, h0 = S["a"], S["hw"], S["h"][0]
    zd = 0.14 + h0 * 0.55
    y0, y1 = hw + 0.02, hw + 0.72
    x0, x1 = -a + 0.1, a
    n = max(1, int(round((x1 - x0) / 0.8)))
    for sg in (-1, 1):
        box(g, x0, x1, min(sg * y0, sg * y1), max(sg * y0, sg * y1), zd - 0.1, zd, c["mur2"], "pont_galerie")
        for k in range(n + 1):
            x = x0 + k * (x1 - x0) / n
            poutre(g, (x, sg * (y1 - 0.07), 0.14), (x, sg * (y1 - 0.07), zd - 0.1), 0.1, c["os"], "pilier_galerie")
            poutre(g, (x, sg * (y1 - 0.07), zd), (x, sg * (y1 - 0.07), zd + 0.42), 0.05, c["os"], "balustre")
        poutre(g, (x0, sg * (y1 - 0.07), zd + 0.44), (x1, sg * (y1 - 0.07), zd + 0.44), 0.07, c["os"], "main_courante", h=0.05)
        if tours:
            for x in xs:
                box(g, x - 0.12, x + 0.12, min(sg * y0, sg * y1), max(sg * y0, sg * y1), 0.14, zd - 0.1, c["mur"], "contrefort")
            xt = x1 + 0.35
            g.cyl((xt, sg * (y1 - 0.2), 1.3), "z", 0.38, 2.3, c["mur2"], n=10, style="hard", what="tour_aile")
            g.tube_shell((xt, sg * (y1 - 0.2), 2.4), "z", 0.46, 0.34, 0.12, c["bande"], n=10, what="corniche_tour")
            g.cyl((xt, sg * (y1 - 0.2), 2.9), "z", 0.46, 0.8, c["toit"], n=10, r2=0.0, style="hard", what="toit_tour")


def halle_gen(c, e, S, pilotis=0.0):
    """La halle : niveaux étagés (plus étroits), bandes, fenêtres alignées sur les côtes, porte, toit de l'âge. Rend
    (z du toit, demi-largeur du dernier niveau)."""
    g, M = c.g, c.M
    a, hw = S["a"], S["hw"]
    z = 0.14 + pilotis
    for i, h in enumerate(S["h"]):
        k = (1.0, 0.72, 0.5)[i]
        ai, hi_ = a * (1.0 if i == 0 else (0.7 if i == 1 else 0.42)), hw * k
        mur = c["mur"] if i % 2 == 0 else c["mur2"]
        box(g, -ai, ai, -hi_, hi_, z, z + h, mur, "niveau")
        box(g, -ai - 0.03, ai + 0.03, -hi_ - 0.03, hi_ + 0.03, z + h - 0.12, z + h, c["bande"], "bande")
        box(g, -ai - 0.03, ai + 0.03, -hi_ - 0.03, hi_ + 0.03, z, z + 0.1, c["bande"], "soubassement")
        x = -ai + 0.4
        while x <= ai - 0.4 + 1e-6:
            box(g, x - 0.2, x + 0.2, -hi_ - 0.05, -hi_ - 0.01, z + h * 0.35, z + h * 0.72, M["emit_soft"], "fenetre", style="flat")
            box(g, x - 0.24, x + 0.24, -hi_ - 0.07, -hi_ - 0.03, z + h * 0.32, z + h * 0.35, c["bande"], "appui")
            x += 0.8
        if i == 0:
            box(g, -0.3, 0.5, -hi_ - 0.08, -hi_ - 0.01, z, z + 0.9, M["void"], "porte")
            box(g, -0.4, 0.6, -hi_ - 0.1, -hi_ - 0.03, z + 0.9, z + 1.0, c["bande"], "linteau")
        z += h
    return z, hw * (1.0, 0.72, 0.5)[len(S["h"]) - 1]


def toit_gen(c, S, z, hw, x0=None):
    g, M = c.g, c.M
    a = S["a"] * (1.0, 0.7, 0.42)[len(S["h"]) - 1]
    kind = S["toit"]
    if kind == "plat":
        for sy in (-1, 1):
            box(g, -a, a, sy * (hw - 0.08), sy * hw, z, z + 0.2, c["bande"], "parapet")
        for sx in (-1, 1):
            box(g, sx * a - 0.04, sx * a + 0.04, -hw, hw, z, z + 0.2, c["bande"], "parapet")
    elif kind == "pans":
        pans(g, -a, a, -hw, hw, z, 0.7 + 0.0 * hw, c["toit"], "toit", debord=0.12)
        poutre(g, (-a - 0.12, 0, z + 0.7), (a + 0.12, 0, z + 0.7), 0.08, c["bande"], "faitage", h=0.08)
    elif kind == "crenele":
        n = int(2 * a / 0.5)
        for k in range(n):
            x = -a + 0.5 * k
            for sy in (-1, 1):
                box(g, x, x + 0.26, sy * (hw - 0.14), sy * hw, z, z + 0.3, c["bande"], "creneau")
    elif kind == "gradins":
        box(g, -a, a, -hw, hw, z, z + 0.05, c["bande"], "assise")
    elif kind == "coupole":
        g.sphere((0, 0, z - 0.1), 1.0, M[S["toit_mat"]] if "toit_mat" in S else c["toit"], n=32, m=14, scale=(a * 0.97, hw * 0.97, 0.9), what="coupole")


def age_generique(c, e):
    """Âges 2, 3, 5, 6, 7, 9 à 14 : la carcasse (crâne, épine, côtes, queue, flancs) garde la silhouette, la halle de
    l'âge pousse dessus, un module propre à l'âge (forge, Tesla, cristaux, radôme, paraboles, radar, anneau, cuve, porte)."""
    g, M = c.g, c.M
    S = GEN[e]
    a, hw = S["a"], S["hw"]
    aire(c, z=0.14)
    # peau : nez et queue seulement quand la halle remplace le ventre
    if a > 0:
        peau(c, [(X_NEZ, -a), (a, 3.5)])
    else:
        peau(c, [(X_NEZ, 3.5)])
    hublots(c, -3.4, -2.8 if a >= 2.3 else -0.9, 0.4 if a >= 2.3 else 0.46, vitre=M["emit_soft"])
    queue(c)
    if S["ailes"] == "delta":
        ailes(c)
    if a > 0:
        z, hwt = halle_gen(c, e, S)
        epine(c, X_NEZ + 0.1, 3.3, mat=c["os"], w=0.18)
        xs = ribs_gen(c, a, S["ra"], 0.14 + S["h"][0], M["steel_hi"], console=M["steel_hi"] if S["ra"] > R else None)
        if S["ailes"] == "galerie":
            ailes_galerie(c, S)
        elif S["ailes"] == "contrefort":
            ailes_galerie(c, S, tours=True, xs=xs)
        toit_gen(c, S, z, hwt)
        zr = z + (0.2 if S["toit"] == "plat" else 0.0) + 0.3
        poutre(g, (-a, 0, zr), (a, 0, zr), 0.2, c["os"], "epine_halle", h=0.16)
        for x in xs:
            poutre(g, (x, 0, z), (x, 0, zr), 0.1, c["os"], "pilier_epine")
        poutre(g, (-a, 0, Z0 + R + 0.05), (-a + 0.3, 0, zr), 0.14, c["os"], "raccord_epine", h=0.14)
        MODULE_GEN[e](c, e, S, z, hwt)
    else:
        cotes(c, [-2.6, -1.8, -1.0, -0.2, 0.6, 1.4, 2.2])
        epine(c, X_NEZ + 0.1, 3.3, mat=c["os"], w=0.16)
        MODULE_GEN[e](c, e, S, 0.14, 0.0)


# --- modules propres à l'âge --------------------------------------------------------------------
def mod02(c, e, S, z, hw):
    """Forge : annexe de briques accolée au flanc sud, toit à deux pans, grande cheminée, gueule de forge incandescente."""
    g, M = c.g, c.M
    box(g, -1.4, 0.9, -2.3, -1.3, 0.14, 1.3, M["brique"], "forge")
    pans(g, -1.4, 0.9, -2.3, -1.3, 1.3, 0.6, M["brick2"], "toit_forge", debord=0.1)
    box(g, -0.7, 0.1, -2.34, -2.3, 0.14, 0.9, M["void"], "gueule")
    box(g, -0.55, -0.05, -2.36, -2.33, 0.2, 0.55, M["emit"], "braise_forge", style="flat")
    g.halo((-0.3, -2.7, 0.5), M["_emit_rgb"], 5.0)
    g.cyl((0.45, -1.8, 2.3), "z", 0.2, 2.2, M["brique"], n=14, r2=0.15, style="smooth", what="cheminee")
    g.tube_shell((0.45, -1.8, 3.4), "z", 0.23, 0.12, 0.1, M["fer_noir"], n=14, what="collet")
    g.dome((0.45, -1.8, 3.4), (0, 0, 1), 0.12, M["emit"], n=7, what="feu_cheminee")
    box(g, 1.5, 2.1, -2.2, -1.6, 0.14, 0.34, M["fer_noir"], "enclume_socle")
    box(g, 1.55, 2.05, -2.15, -1.65, 0.34, 0.5, M["fer_martele"], "enclume")
    for x in (-1.2, -0.4, 0.4):
        poutre(g, (x, -2.3, 0.14), (x, -2.3, 1.3), 0.08, M["fer_noir"], "montant_forge")


def mod03(c, e, S, z, hw):
    """Vapeur : chaudière de cuivre sur le flanc sud, dôme et sifflet, cheminée de laiton qui fume."""
    g, M = c.g, c.M
    g.cyl((0.3, -2.0, 0.14 + 0.5), "x", 0.5, 2.4, M["cuivre_capot"], n=26, style="smooth", what="chaudiere")
    for x in (-0.6, 0.3, 1.2):
        g.tube_shell((x, -2.0, 0.64), "x", 0.52, 0.48, 0.08, M["laiton_capot"], n=26, what="cercle_chaudiere")
    g.sphere((1.5, -2.0, 0.64), 0.5, M["cuivre_capot"], n=18, m=10, scale=(0.35, 1.0, 1.0), what="fond_chaudiere")
    g.sphere((-0.9, -2.0, 0.64), 0.5, M["cuivre_capot"], n=18, m=10, scale=(0.35, 1.0, 1.0), what="fond_chaudiere")
    g.sphere((0.3, -2.0, 1.2), 0.22, M["laiton_capot"], n=14, m=8, what="dome_vapeur")
    g.cyl((0.9, -2.0, 1.6), "z", 0.04, 0.8, M["laiton_capot"], n=8, style="smooth", what="sifflet")
    for sx in (-0.3, 0.9):
        box(g, sx - 0.06, sx + 0.06, -2.4, -1.6, 0.14, 0.3, M["fonte_noire"] if "fonte_noire" in M else M["steel_dk"], "cale")
    g.cyl((-0.2, 1.7, 2.1), "z", 0.22, 3.4, M["laiton_capot"], n=16, r2=0.16, style="smooth", what="cheminee_vapeur")
    g.sphere((-0.2, 1.7, 4.0), 0.3, M["amber"], n=12, m=8, what="panache")
    g.halo((-0.2, 1.4, 3.8), M["_emit_rgb"], 3.0)


def mod05(c, e, S, z, hw):
    """Volcan : cône de basalte à cratère rougeoyant au sud-est, d'où part une coulée de lave dans un LIT de basalte
    (deux bords relevés), qui longe la halle jusqu'au bord ouest de l'aire."""
    g, M = c.g, c.M
    xc, yc = 3.0, -2.0
    g.cyl((xc, yc, 0.14 + 0.75), "z", 0.85, 1.5, M["basalte_capot"], n=14, r2=0.35, style="hard", what="cone_volcan")
    g.cyl((xc, yc, 1.62), "z", 0.34, 0.06, M["emit"], n=14, style="flat", what="cratere")
    g.halo((xc, yc - 0.3, 1.9), M["_emit_rgb"], 5.0)
    # lit : fond et deux bords en basalte, lave en retrait entre les bords
    box(g, -2.2, 2.3, -2.55, -2.05, 0.14, 0.26, M["basalte_capot"], "lit_lave")
    for yb in (-2.55, -2.1):
        box(g, -2.2, 2.3, yb - 0.02, yb + 0.07, 0.26, 0.38, M["fonte_v"], "bord_lit")
    box(g, -2.18, 2.3, -2.46, -2.14, 0.26, 0.29, M["emit"], "lave", style="flat")
    box(g, -2.26, -2.16, -2.55, -2.05, 0.26, 0.38, M["fonte_v"], "butee_lit")
    g.halo((0.0, -2.9, 0.4), M["_emit_rgb"], 5.0)
    for k in range(6):
        a_ = TAU * k / 6
        g.sphere((xc + 0.95 * math.cos(a_), yc + 0.95 * math.sin(a_) * 0.7, 0.3), 0.18 + 0.06 * (k % 3), M["basalte_capot"], n=8, m=5,
                 scale=(1, 1, 0.7), what="bloc_basalte")


def mod06(c, e, S, z, hw):
    """Électricité : quatre pylônes Tesla (mât, deux anneaux, sphère bleue) aux coins de la halle."""
    g, M = c.g, c.M
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * 2.55, sy * 2.15
            g.cyl((x, y, 0.14 + 0.15), "z", 0.28, 0.3, M["fonte_bleue"], n=12, style="hard", what="pied_tesla")
            poutre(g, (x, y, 0.3), (x, y, 3.0), 0.12, M["porcelaine_capot"], "mat_tesla")
            for zz in (1.2, 1.9, 2.5):
                g.torus((x, y, zz), "z", 0.3, 0.04, M["bleu_machine"], n=20, m=6, what="anneau_tesla")
            g.sphere((x, y, 3.15), 0.2, M["emit"], n=16, m=10, what="sphere_tesla")
            g.halo((x, y - 0.2, 3.1), M["_emit_rgb"], 4.0)


def mod07(c, e, S, z, hw):
    """Cristal : amas de cristaux violets sur les gradins et au pied de la halle, base de bronze."""
    g, M = c.g, c.M
    cles = [("emit", 1.0), ("crystal", 0.8)]
    pts = [(-1.5, 0.6, z), (-0.5, -0.5, z), (0.7, 0.4, z), (1.6, -0.3, z), (2.9, -2.0, 0.14), (3.3, 1.7, 0.14), (-3.0, 2.0, 0.14)]
    for i, (x, y, z0_) in enumerate(pts):
        for k in range(4):
            a_ = TAU * k / 4 + i
            hh = 0.5 + 0.4 * ((i + k) % 3) * 0.5 if z0_ > 1 else 0.9 + 0.5 * ((i + k) % 3)
            g.cyl((x + 0.16 * math.cos(a_), y + 0.16 * math.sin(a_), z0_ + hh / 2), "z", 0.1, hh, M["emit"] if k == 0 else M["crystal"],
                  n=6, r2=0.0, style="hard", what="cristal")
        g.cyl((x, y, z0_ + 0.04), "z", 0.28, 0.08, M["bronze_capot"], n=10, style="hard", what="socle_cristal")
        g.halo((x, y - 0.2, z0_ + 0.5), M["_emit_rgb"], 3.0)


def mod09(c, e, S, z, hw):
    """Atome : radôme blanc sur la coupole, antenne, bandes de danger, cheminée de ventilation plombée."""
    g, M = c.g, c.M
    g.sphere((0.3, 0.0, z + 0.65), 0.55, M["beton_capot"], n=28, m=14, what="radome")
    g.torus((0.3, 0.0, z + 0.65), "z", 0.57, 0.02, M["lead"], n=28, m=6, what="equateur_radome")
    g.cyl((0.3, 0.0, z + 1.35), "z", 0.02, 0.8, M["steel"], n=8, r2=0.01, what="antenne")
    g.dome((0.3, 0.0, z + 1.75), (0, 0, 1), 0.05, M["emit"], n=6, what="feu_atome")
    g.halo((0.3, -0.3, z + 1.7), M["_emit_rgb"], 3.5)
    for k in range(9):
        box(g, -2.1 + 0.55 * k, -2.1 + 0.55 * k + 0.28, -1.95, -1.9, 0.5, 0.9, M["hazy"] if k % 2 else M["hazk"], "danger_atome", style="flat")
    g.cyl((-2.4, 1.6, 1.9), "z", 0.25, 3.6, M["lead"], n=16, style="smooth", what="ventilation")
    g.cyl((-2.4, 1.6, 3.75), "z", 0.3, 0.1, M["steel_dk"], n=16, style="hard", what="collet")


def mod10(c, e, S, z, hw):
    """Haute technologie : deux paraboles orientables sur le toit, bande vitrée continue, mât de télécom."""
    g, M = c.g, c.M
    for (x, y) in ((-1.2, 0.0), (1.2, 0.3)):
        poutre(g, (x, y, z), (x, y, z + 0.5), 0.1, M["gris_tech"], "pied_parabole")
        g.cyl((x, y - 0.12, z + 0.85), "y", 0.62, 0.12, M["blanc_casse"], n=28, r2=0.1, style="smooth", what="parabole")
        g.cyl((x, y - 0.38, z + 0.85), "y", 0.04, 0.5, M["steel"], n=8, what="alimentation")
        g.dome((x, y - 0.66, z + 0.85), (0, -1, 0), 0.06, M["emit"], n=6, what="feu_parabole")
    poutre(g, (2.0, -0.8, z), (2.0, -0.8, z + 1.8), 0.06, M["steel_hi"], "mat_telecom")
    g.dome((2.0, -0.8, z + 1.85), (0, 0, 1), 0.05, M["emit"], n=6, what="feu_telecom")
    g.halo((2.0, -1.0, z + 1.8), M["_emit_rgb"], 3.0)


def mod11(c, e, S, z, hw):
    """Titane : radar sur socle (bras de 1,8 et réflecteur), ailerons orange aux bords du toit."""
    g, M = c.g, c.M
    g.cyl((0.2, 0.0, z + 0.3), "z", 0.35, 0.6, M["titane_dk"], n=18, r2=0.28, style="hard", what="socle_radar")
    poutre(g, (-0.7, 0.0, z + 0.75), (1.1, 0.0, z + 0.75), 0.16, M["titane_cl"], "bras_radar", h=0.12)
    box(g, -0.8, -0.6, -0.55, 0.55, z + 0.75, z + 1.45, M["titane_cl"], "reflecteur")
    g.dome((1.1, 0.0, z + 0.85), (0, 0, 1), 0.07, M["emit"], n=6, what="feu_radar")
    for sx in (-1, 1):
        for sy in (-1, 1):
            pts = [(sx * (S["a"] - 0.5), sy * hw), (sx * (S["a"] - 0.1), sy * hw), (sx * (S["a"] - 0.1), sy * hw), (sx * (S["a"] - 0.5), sy * hw)]
            box(g, sx * (S["a"] - 0.3) - 0.1, sx * (S["a"] - 0.3) + 0.1, sy * hw - 0.04, sy * hw + 0.04, z, z + 0.7, M["amber"], "aileron_orange")
    g.halo((0.2, -0.3, z + 1.0), M["_emit_rgb"], 3.0)


def mod12(c, e, S, z, hw):
    """Supraconducteurs : anneau givré incandescent cyan autour de la halle, sur deux pieds, voyants cyan."""
    g, M = c.g, c.M
    g.torus((0.4, 0, Z0 + 0.5), "x", 2.1, 0.14, M["frost"], n=48, m=10, what="anneau_supra")
    g.torus((0.4, 0, Z0 + 0.5), "x", 2.1, 0.07, M["emit"], n=48, m=8, what="coeur_supra")
    for sy in (-1, 1):
        poutre(g, (0.4, sy * 1.9, 0.14), (0.4, sy * 1.9, 1.25), 0.2, M["noir_miroir"], "pied_anneau")
    g.halo((0.4, -2.2, 2.2), M["_emit_rgb"], 5.0)
    g.halo((0.4, 2.2, 2.2), M["_emit_rgb"], 4.0)


def mod13(c, e, S, z, hw):
    """Antimatière : cuve de confinement sur le toit, quatre bouteilles couchées, éclairs violets entre deux pointes."""
    g, M = c.g, c.M
    g.cyl((0.3, 0.0, z + 0.05), "z", 0.95, 0.1, M["steel_dk"], n=26, style="hard", what="embase_cuve")
    g.cyl((0.3, 0.0, z + 0.6), "z", 0.75, 1.2, M["acier_canon"], n=26, style="smooth", what="cuve_confinement")
    for dz in (0.2, 1.0):
        g.tube_shell((0.3, 0.0, z + dz), "z", 0.78, 0.7, 0.1, M["cuivre_bobine"], n=26, what="bobine")
    g.dome((0.3, 0.0, z + 1.25), (0, 0, 1), 0.3, M["emit"], n=12, h=0.5, what="coeur_cuve")
    for k in range(4):
        x = -1.8 + 1.2 * k
        yb = -0.6 if k % 2 == 0 else 0.6
        g.cyl((x, yb, z + 0.3), "y", 0.25, 1.2, M["acier_noir"], n=16, style="smooth", what="bouteille")
        for dy in (-0.4, 0.4):                              # berceaux : deux selles à l'aplomb de chaque bouteille
            box(g, x - 0.18, x + 0.18, yb + dy - 0.07, yb + dy + 0.07, z, z + 0.2, M["steel_dk"], "berceau")
            box(g, x - 0.1, x + 0.1, yb + dy - 0.07, yb + dy + 0.07, z + 0.2, z + 0.27, M["steel_dk"], "selle")
        g.dome((x, (-1.2 if k % 2 == 0 else 1.2), z + 0.3), (0, -1 if k % 2 == 0 else 1, 0), 0.2, M["emit"], n=8, what="cap_bouteille")
    for sx in (-1, 1):
        poutre(g, (0.3 + sx * 1.3, 0.0, z), (0.3 + sx * 1.3, 0.0, z + 1.9), 0.05, M["steel"], "pointe_eclair")
        g.dome((0.3 + sx * 1.3, 0.0, z + 1.9), (0, 0, 1), 0.07, M["emit"], n=6, what="bout_eclair")
    poutre(g, (-1.0, 0.0, z + 1.85), (1.6, 0.0, z + 1.85), 0.03, M["emit"], "eclair", h=0.03)
    g.halo((0.3, -0.5, z + 1.2), M["_emit_rgb"], 5.0)


def mod14(c, e, S, z, hw):
    """La Porte : grand anneau blanc debout (axe y, face au sud) planté sur l'aire DEVANT la porte de la halle, sur deux
    piliers et une plaque ; liseré lumineux ; semis d'étoiles sur la plaque."""
    g, M = c.g, c.M
    xc, yc, zc = 0.1, -2.35, 1.75
    box(g, xc - 1.7, xc + 1.7, yc - 0.35, yc + 0.35, 0.14, 0.24, M["blanc_lunaire"], "plaque_porte")
    g.torus((xc, yc, zc), "y", 1.35, 0.15, M["blanc_lunaire"], n=48, m=10, what="anneau_porte")
    g.torus((xc, yc - 0.06, zc), "y", 1.2, 0.05, M["emit"], n=48, m=8, what="lisere_porte")
    for sx in (-1, 1):
        box(g, xc + sx * 1.15 - 0.22, xc + sx * 1.15 + 0.22, yc - 0.28, yc + 0.28, 0.24, zc - 0.5, M["blanc_lunaire"], "pilier_porte")
    for k in range(16):
        a_ = TAU * k / 16
        g.dome((xc + 0.95 * math.cos(a_), yc - 0.08, zc + 0.95 * math.sin(a_)), (0, -1, 0), 0.045, M["emit"], n=5, what="etoile")
    g.halo((xc, yc - 0.6, zc), M["_emit_rgb"], 5.0)


MODULE_GEN = {2: mod02, 3: mod03, 5: mod05, 6: mod06, 7: mod07, 9: mod09, 10: mod10, 11: mod11, 12: mod12, 13: mod13, 14: mod14}
for _e in MODULE_GEN:
    pass


PAD_GEN = {3: ("verdigris", "cuivre_sombre"), 14: ("concrete", "indigo_nuit")}


def pal_gen(e, M):
    """Palette d'un âge générique : tirée de ages.palette (dominante, secondaire, pont, acier)."""
    import ages
    p = ages.palette(e)
    dom = (p.get("dominante") or ("armor",))[0] if isinstance(p.get("dominante"), tuple) else (p.get("dominante") or "armor")
    sec = (p.get("secondaire") or ("armor2",))[0] if isinstance(p.get("secondaire"), tuple) else (p.get("secondaire") or "armor2")
    pont = p["pont"]
    pad, pad2 = PAD_GEN.get(e, (pont.get("mat") or "concrete", pont.get("mat2") or "armor2"))
    return dict(peau=("peau_prop",), bande=(sec,), os=(p.get("acier") or "steel_dk",), aile=(dom,), tuy=(sec,), mur=(dom,),
                mur2=(sec,), toit=(dom,), pad=(pad,), pad2=(pad2,),
                acc=(sec,), vit=("emit_soft",))


MODULES = {0: epave, 1: age01, 4: age04, 8: age08, 15: age15}
for _e in MODULE_GEN:
    MODULES[_e] = lambda c, _e=_e: age_generique(c, _e)
LARGEUR_AGE = {0: 4, 1: 4, 2: 4, 3: 4, 4: 5, 5: 5, 6: 5, 7: 6, 8: 6, 9: 6, 10: 7, 11: 7, 12: 7, 13: 8, 14: 8, 15: 8}


class SafeM(dict):
    """Dictionnaire de matières qui ne plante pas sur une clé absente (retombe sur « armor » et la note)."""
    manque = set()

    def __missing__(self, k):
        SafeM.manque.add(k)
        return dict.__getitem__(self, "armor")


def vaisseau(g, e):
    g.M = SafeM(g.M)
    c = Ctx(g, e)
    s = LARGEUR_AGE[e] / LARGEUR
    g.push((0, 0, 0))
    g.stack[-1] = (g.stack[-1] @ Matrix.Diagonal((s, s, 1.0 + 0.6 * (s - 1.0), 1.0)) @ Matrix.Translation((DX, 0, 0))
                    @ Matrix.Diagonal((KX, 1.0, 1.0, 1.0)))
    MODULES[e](c)
    g.pop()
    if SafeM.manque:
        print("[FO-RENDER] MATIERES ABSENTES (remplacees par armor) : %s" % ", ".join(sorted(SafeM.manque)), flush=True)
        SafeM.manque.clear()
