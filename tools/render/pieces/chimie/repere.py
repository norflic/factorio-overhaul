"""REPÈRE TOURNÉ du kit chimie (lot DA-CHIMIE, 3/11) : une machine à fluides se rend dans les 4 directions (comme l'usine
chimique vanilla). Le modèle est écrit UNE fois dans un repère local, en TUILES, pour la machine posée « nord » :
u vers l'est, v vers le SUD (comme les positions du jeu), z en unités Blender (hauteur). Rep(k, d) tourne ce repère d'un
quart de tour HORAIRE par pas de d (0 nord, 1 est, 2 sud, 3 ouest : sens des boîtes de fluide du jeu), puis convertit en
Blender (une tuile vers le sud = D unités en Y). Positions et EMPRISES tournent (une boîte de 2 × 1 tuiles devient 1 × 2) ;
les rayons et les hauteurs ne changent pas : un cylindre vertical reste rond.

Les faces visibles (dessus et face SUD absolue) s'habillent dans le repère ABSOLU : bornes() rend l'emprise absolue
d'une boîte locale, sud_y() la coordonnée Blender de sa face sud ; les organes « face sud » d'organes.Kit s'y posent tels
quels.
"""
import math

import geo as G

D = 1.0 / math.cos(math.radians(45.0))
TAU = 2.0 * math.pi
DIRS = ("n", "e", "s", "w")


class Rep:
    def __init__(self, k, d):
        self.k, self.d = k, d % 4

    # ------------------------------------------------------------------------------------------- conversions
    def t(self, u, v):
        """Local (u, v) en tuiles -> absolu (x, y) en tuiles (y vers le sud)."""
        for _ in range(self.d):
            u, v = -v, u
        return u, v

    def p(self, u, v, z=0.0):
        x, y = self.t(u, v)
        return (x, -y * D, z)

    def pts(self, pts):
        return [self.p(*q) for q in pts]

    def emp(self, su, sv):
        return (sv, su) if self.d % 2 else (su, sv)

    def axe_abs(self, a):
        """Axe local « u » ou « v » -> axe Blender « x » ou « y »."""
        if self.d % 2:
            return "y" if a == "u" else "x"
        return "x" if a == "u" else "y"

    def long_abs(self, a, L):
        """Longueur en tuiles le long de l'axe local a -> unités Blender."""
        return L * D if self.axe_abs(a) == "y" else L

    def bornes(self, u, v, su, sv):
        """Emprise absolue (x0, x1, y0, y1) en tuiles d'une boîte locale centrée en (u, v)."""
        x, y = self.t(u, v)
        a, b = self.emp(su, sv)
        return x - a / 2.0, x + a / 2.0, y - b / 2.0, y + b / 2.0

    @staticmethod
    def sud_y(y1):
        """Coordonnée Blender de la face sud d'une emprise qui finit en y1 (tuiles)."""
        return -y1 * D

    # ------------------------------------------------------------------------------------------- volumes
    def box(self, mat, u, v, z0, su, sv, h, rz=0.0):
        x, y, _ = self.p(u, v)
        a, b = self.emp(su, sv)
        self.k.bz(mat, x, y, z0, a, b * D, h)

    def caisson(self, mat, u, v, z0, su, sv, h, ch=0.05):
        x, y, _ = self.p(u, v)
        a, b = self.emp(su, sv)
        self.k.caisson(mat, x, y, z0, a, b * D, h, ch)

    def prisme(self, mat, u, v, z0, z1, su, sv, k=1.0):
        """Tronc de pyramide (hotte) sur l'emprise locale su × sv."""
        x, y, _ = self.p(u, v)
        a, b = self.emp(su, sv)
        bb = b * D
        c = [(x - a / 2, y - bb / 2), (x + a / 2, y - bb / 2), (x + a / 2, y + bb / 2), (x - a / 2, y + bb / 2)]
        self.k.put(mat, G.prisme(c, z0, z1, k))

    def cyl(self, mat, u, v, z0, z1, r, segs=28):
        x, y, _ = self.p(u, v)
        self.k.cyl(mat, x, y, z0, z1, r, segs)

    def rev(self, mat, u, v, prof, segs=28, cap=True):
        x, y, _ = self.p(u, v)
        self.k.rev(mat, x, y, prof, segs, cap=cap)

    def cuve(self, mat, u, v, z0, z1, r, tete=0.35, segs=32):
        x, y, _ = self.p(u, v)
        self.k.cuve(mat, x, y, z0, z1, r, tete, segs)

    def dome(self, mat, u, v, z0, r, kz=1.0, segs=36):
        x, y, _ = self.p(u, v)
        self.k.dome(mat, x, y, z0, r, kz, segs)

    def tore(self, mat, u, v, z, R, r, seg=48, minor=10):
        x, y, _ = self.p(u, v)
        self.k.tore(mat, x, y, z, R, r, seg, minor)

    def cerclages(self, mat, u, v, zs, r, e=0.018, h=0.03):
        x, y, _ = self.p(u, v)
        self.k.cerclages(mat, x, y, zs, r, e, h)

    def axe(self, mat, a, b, r, segs=14, cap=True):
        self.k.axe(mat, self.p(*a), self.p(*b), r, segs, cap)

    def tuyau(self, mat, pts, r=0.07, coude=0.14, brides=None, bride_mat=None, segs=14):
        P = self.pts(pts)
        br = None if brides is None else [self.p(*q) for q in brides]
        self.k.tuyau(mat, P, r, coude, br, bride_mat, segs)

    def vanne(self, corps, volant, q, r=0.05, hauteur=0.1):
        self.k.vanne(corps, volant, self.p(*q), r, hauteur)

    def echangeur(self, u, v, z0, L, r, mat, bride="acier", axe="u", tetes=True, cerc=4):
        x, y, _ = self.p(u, v)
        self.k.echangeur(x, y, z0, self.long_abs(axe, L), r, mat, bride, self.axe_abs(axe), tetes, cerc)

    def moteur(self, mat, u, v, z, L, r, ailette="noir", axe="u"):
        x, y, _ = self.p(u, v)
        self.k.moteur(mat, x, y, z, self.long_abs(axe, L), r, ailette, self.axe_abs(axe))

    def ventilo(self, u, v, z, R, **kw):
        x, y, _ = self.p(u, v)
        self.k.ventilo(x, y, z, R, **kw)

    def voyant_h(self, mat, u, v, z, r=0.025):
        x, y, _ = self.p(u, v)
        self.k.voyant_h(mat, x, y, z, r)

    def boulons_rond(self, mat, u, v, z, R, n, r=0.016):
        x, y, _ = self.p(u, v)
        self.k.boulons_rond(mat, x, y, z, R, n, r)

    def collier(self, mat, q, n_local, r, e=0.022, h=0.03):
        """Collier (bride) au point local q, axe le long de la normale locale (nu, nv, nz)."""
        nu, nv, nz = n_local
        x, y = self.t(nu, nv)
        self.k.collier(mat, self.p(*q), G.norm((x, -y * D, nz)), r, e, h)

    # ------------------------------------------------------------------------------------------- raccords
    def raccord(self, col, bord, z=0.22, r=0.15, L=0.34, mat="acier", bride="acier_clair", riv="riv", vers=None,
                r_suite=0.085, mat_suite=None):
        """Raccord de boîte de fluide : tronçon de tuyau horizontal du bord de l'emprise (mi-bord local, colonne col,
        bord « n » ou « s ») vers l'intérieur, bride boulonnée au ras du bord (le tuyau du joueur s'y raccorde) et
        contre-bride côté machine. vers : points locaux où la ligne continue (rayon r_suite, coudes compris)."""
        sg = -1.0 if bord == "n" else 1.0
        e = 1.5 * sg
        a = (col, e - sg * 0.02, z)
        b = (col, e - sg * L, z)
        self.tuyau(mat, [a, b], r, 0.16, brides=[], segs=16)
        if vers:
            self.tuyau(mat_suite or mat, [(col, e - sg * (L - 0.06), z)] + list(vers), r_suite, 0.14, brides=[], segs=14)
        nrm = (0.0, sg, 0.0)
        self.collier(bride, (col, e - sg * 0.035, z), nrm, r + 0.005, e=0.075, h=0.03)
        self.collier(bride, (col, e - sg * (L - 0.04), z), nrm, r + 0.003, e=0.05, h=0.022)
        # boulons de la bride : couronne vue de face (posés sur la tranche, normale le long du tuyau)
        x0, y0, z0 = self.p(col, e - sg * 0.006, z)
        nb = self.t(0.0, sg)
        nB = G.norm((nb[0], -nb[1], 0.0))
        side = G.norm(G.cross(nB, (0.0, 0.0, 1.0)))
        pts_b = []
        for i in range(8):
            a_ = TAU * (i + 0.5) / 8
            off = G.add(G.mul(side, math.cos(a_) * (r + 0.048)), (0.0, 0.0, math.sin(a_) * (r + 0.048)))
            pts_b.append(G.add((x0, y0, z0), off))
        self.k.rivets(riv, pts_b, nB, 0.014)
