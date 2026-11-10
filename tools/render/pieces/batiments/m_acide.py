"""PULVÉRISATEUR D'ACIDE (fo-acid-sprayer, fluid-turret 2×3, lot MURS-ACIDE, 10/11, sprint final du DC) : « le cracheur ».

Dernière tourelle de défense encore copiée de vanilla (lance-flammes teinté + usine chimique réduite collée à l'arrière). Silhouette
propre, distincte des quatre tourelles à munitions (socles carré, hexagone, rond, étoile : marques.py) : plinthe RECTANGULAIRE longue
à pans coupés (2×3, l'emprise vanilla), CITERNE horizontale à l'arrière (côté des deux arrivées de tuyau du moteur, en (±1,5 ; 1,0)
dans le repère nord), hublot d'acide en lueur de FONCTION (vert acide, marques.py « acide »), pompe et deux flexibles qui montent vers
la sellette avant. Le socle a une DIRECTION (fluid-turret : turret_base_has_direction) : quatre variantes acide_n, acide_e, acide_s,
acide_w, même modèle tourné de 0, 90, 180, 270 degrés (sens horaire vu de dessus) ; la sellette est à PIVOT tuiles vers l'avant.

TÊTE TOURNANTE (64 directions, tourelle_tete.py, rendue par batch_tetes.py) : couronne, carter de pompe blindé, deux bonbonnes d'acide
en lueur de fonction, lance longue à bague verte, motif de toit « vague ». Une image (le jet est un stream du moteur).

Repère du socle (organes.py) : x est, y NORD en unités du kit (une tuile vaut D unités en y), z vers le haut. Le modèle est écrit en
coordonnées de JEU (gx est, gy SUD, en tuiles) puis tourné et converti par P().
"""
import marques as MQ
import organes as O
import socle_tourelle as St
import tourelle_tete as T

D = O.D
IMAGES = 1
ZT = 0.38          # dessus de la sellette : pied de la tête
PIVOT = 0.35       # la sellette est à 0,35 tuile vers l'avant du centre de l'emprise
DIRECTIONNEL = True
# rotation (sens horaire vu de dessus) d'un point de jeu du repère nord vers la direction du socle
ROT = {"n": lambda x, y: (x, y), "e": lambda x, y: (-y, x), "s": lambda x, y: (-x, -y), "w": lambda x, y: (y, -x)}
# position de la sellette (tuiles de jeu, relative au centre) par direction : lue par feuilles.py (décalage de la tête)
PIVOTS = {d: ROT[d](0.0, -PIVOT) for d in ROT}


def direction_de(variant):
    d = variant.rsplit("_", 1)[-1]
    if d not in ROT:
        raise ValueError("variante de pulvérisateur sans direction : %s" % variant)
    return d


class Rep:
    """Primitives du kit en coordonnées de jeu tournées vers la direction d."""

    def __init__(self, k, d):
        self.k, self.d, self.r = k, d, ROT[d]
        self.swap = d in ("e", "w")

    def P(self, gx, gy):
        x, y = self.r(gx, gy)
        return (x, -y * D)

    def P3(self, gx, gy, z):
        x, y = self.P(gx, gy)
        return (x, y, z)

    def bz(self, mat, gx, gy, z0, sx, sy, sz):
        x, y = self.P(gx, gy)
        if self.swap:
            sx, sy = sy, sx
        self.k.bz(mat, x, y, z0, sx, sy * D, sz)

    def seg(self, mat, a, b, r, segs=16):
        self.k.axe(mat, self.P3(*a), self.P3(*b), r, segs)

    def poly(self, mat, pts, z0, z1, kk=1.0):
        self.k.poly(mat, [self.P(x, y) for x, y in pts], z0, z1, kk)

    def anneau(self, mat, gx, gy, r, z0, z1, n=40):
        """Anneau de sol rond VU DE HAUT (étiré de D en y, comme la couronne de la tête) : sellette."""
        x, y = self.P(gx, gy)
        self.k.poly(mat, [(x + px, y + py) for px, py in St.octo(r, rot=0.0, n=n)], z0, z1)

    def voyant(self, mat, gx, gy, z, r=0.024):
        x, y = self.P(gx, gy)
        self.k.voyant(mat, x, y, z, r)


def rect_pans(hx, hy, c):
    """Rectangle à pans coupés (repère de jeu, y sud) ; ordre choisi pour être TRIGONOMÉTRIQUE dans le repère du kit (y nord, comme
    socle_tourelle.octo) après P() : les rotations le gardent."""
    pts = [(hx, -hy + c), (hx, hy - c), (hx - c, hy), (-hx + c, hy), (-hx, hy - c), (-hx, -hy + c), (-hx + c, -hy), (hx - c, -hy)]
    return pts[::-1]


def build(S, k, M, variant):
    d = direction_de(variant)
    R = Rep(k, d)
    lis = "lisere" if "lisere" in k.M else "turq"
    H = 0.3
    # plinthe rectangulaire 2×3 à pans coupés : semelle sombre, gradin argent, liseré vert, gradin haut, plateau
    R.poly("struct", rect_pans(0.97, 1.47, 0.22), 0.0, 0.06)
    R.poly("blind", rect_pans(0.93, 1.43, 0.2), 0.06, H * 0.55, 0.97)
    R.poly(lis, rect_pans(0.89, 1.39, 0.19), H * 0.55, H * 0.55 + 0.014)
    R.poly("blind2", rect_pans(0.82, 1.32, 0.17), H * 0.55, H, 0.96)
    R.poly("struct", rect_pans(0.74, 1.24, 0.15), H, H + 0.03)
    zp = H + 0.03
    # pare-chocs avant et patins d'angle
    R.bz("struct", 0.0, -1.38, 0.0, 1.3, 0.14, 0.12)
    for sx in (-1, 1):
        for sy in (-1, 1):
            R.bz("struct", sx * 0.78, sy * 1.18, 0.0, 0.22, 0.26, 0.1)
    # CITERNE horizontale à l'arrière (est-ouest dans le repère nord), cerclages, hublot d'acide
    yc, zc, rc = 0.82, zp + 0.3, 0.27
    for sx in (-1, 1):
        R.bz("struct", sx * 0.42, yc, zp, 0.12, 0.5, 0.16)
    R.seg("blind2", (-0.7, yc, zc), (0.7, yc, zc), rc, 28)
    for gx in (-0.72, -0.36, 0.0, 0.36, 0.72):
        R.seg("struct", (gx - 0.025, yc, zc), (gx + 0.025, yc, zc), rc + 0.02, 28)
    R.seg(lis, (-0.3, yc, zc + rc - 0.01), (0.3, yc, zc + rc - 0.01), 0.045, 12)
    R.seg(lis, (-0.68, yc - 0.05, zc), (0.68, yc - 0.05, zc), 0.012, 6)
    # arrivées de tuyau du moteur : (±1,5 ; 1,0) -> manchettes jusqu'au bord de l'emprise, brides sombres
    for sx in (-1, 1):
        R.seg("canon", (sx * 0.7, yc, zc - 0.08), (sx * 0.96, 1.0, 0.22), 0.085, 14)
        R.bz("struct", sx * 0.95, 1.0, 0.1, 0.08, 0.26, 0.24)
        R.bz("blind2", sx * 0.62, yc, zc - 0.2, 0.1, 0.34, 0.4)
    # pompe entre la citerne et la sellette, deux flexibles verts qui montent vers la sellette
    k.caisson("blind", *R.P(0.0, 0.18), zp, *((0.4, 0.62 * D) if R.swap else (0.62, 0.4 * D)), 0.24, ch=0.05)
    R.voyant("accent", 0.0, 0.39, zp + 0.12)
    for sx in (-1, 1):
        R.seg(lis, (sx * 0.16, yc - 0.2, zc - 0.1), (sx * 0.14, 0.05, zp + 0.26), 0.022, 8)
        R.seg(lis, (sx * 0.14, 0.05, zp + 0.26), (sx * 0.12, -PIVOT + 0.2, ZT - 0.02), 0.022, 8)
    # sellette avant (pied de la tête tournante), bague verte
    R.anneau("struct", 0.0, -PIVOT, 0.5, zp, ZT - 0.03)
    R.anneau(lis, 0.0, -PIVOT, 0.52, ZT - 0.045, ZT - 0.03)
    R.anneau("blind2", 0.0, -PIVOT, 0.46, ZT - 0.03, ZT)
    # voyants de fonction à l'avant, bande magenta à l'arrière (signature de la gamme)
    for sx in (-1, 1):
        R.voyant(lis, sx * 0.55, -1.3, 0.1)
    R.bz("accent", 0.0, 1.36, 0.06, 0.9, 0.02, 0.03)
    return {}


def tete(k, M, image):
    lis = "lisere" if "lisere" in k.M else "accent"
    zt = T.couronne(k, ZT, 0.42)
    pts = [(-0.27, -0.3), (0.27, -0.3), (0.32, -0.02), (0.2, 0.24), (-0.2, 0.24), (-0.32, -0.02)]
    k.poly("blind", pts, zt, zt + 0.2, 0.86)
    k.poly("blind2", [(x * 0.72, y * 0.72 - 0.02) for x, y in pts], zt + 0.2, zt + 0.25, 0.88)
    T.toit(k, MQ.marque("acide")["toit"], 0.0, -0.03, zt + 0.252, 0.3)
    # deux bonbonnes d'acide à l'arrière (lueur de fonction), capots sombres
    for sx in (-1, 1):
        x = sx * 0.2
        k.cyl(lis, x, -0.27, zt + 0.04, zt + 0.3, 0.085, 20)
        k.cyl("struct", x, -0.27, zt + 0.3, zt + 0.33, 0.09, 20)
        k.cyl("struct", x, -0.27, zt + 0.02, zt + 0.06, 0.095, 20)
    # lance (le long de +y) : manchon sombre, tube argent, bague verte, buse évasée
    zb = zt + 0.13
    T.fut_y(k, "struct", 0.0, zb, [(0.18, 0.09), (0.32, 0.09)], 18)
    T.fut_y(k, "canon", 0.0, zb, [(0.3, 0.06), (0.62, 0.05), (0.64, 0.0)], 16)
    T.fut_y(k, lis, 0.0, zb, [(0.5, 0.062), (0.55, 0.062)], 16)
    T.fut_y(k, "canon", 0.0, zb, [(0.62, 0.05), (0.7, 0.07), (0.74, 0.075), (0.75, 0.0)], 16)
    k.axe("struct", (0.08, 0.18, zb - 0.07), (0.04, 0.5, zb - 0.04), 0.016, 6)
    return {"bouche": (0.0, 0.75, zb)}
