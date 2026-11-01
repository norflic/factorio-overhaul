"""OUTILS COMMUNS de la famille des expérimentaux (lot EXP2, 1/11) : profils de révolution, plaques courbes, fentes lumineuses à dégradé,
rangées de baies, anneaux. Règle de la critique du 1/11 : aucune surface émissive sans dégradé (bord sombre, milieu, cœur clair).
Repère Blender : +Y nord, +Z haut ; seul le côté sud est vu : le détail fin ne va que là (vu()).
"""
import math
import os

import geo as G
import greb as R
import mat as MT

GRIS = os.environ.get("FO_GRIS", "") == "1"


def vu(az, m=0.55):
    return math.sin(az) < m


class Prof:
    """Profil de révolution : points (z, r) ; rz(z), normale, point sur la surface."""

    def __init__(self, pts, lisse=True):
        if lisse:
            c = G.catmull([(p[0], p[1], 0.0) for p in pts], 8)
            self.pts = [(p[0], max(0.0, p[1])) for p in c]
        else:
            self.pts = list(pts)

    def rz(self, z):
        p = self.pts
        if z <= p[0][0]:
            return p[0][1]
        for i in range(1, len(p)):
            if z <= p[i][0]:
                a, b = p[i - 1], p[i]
                return a[1] + (b[1] - a[1]) * (z - a[0]) / max(1e-6, b[0] - a[0])
        return p[-1][1]

    def n(self, az, z):
        dr = (self.rz(z + 0.15) - self.rz(z - 0.15)) / 0.3
        return G.norm((math.cos(az), math.sin(az), -dr))

    def pt(self, az, z, d=0.0, c=(0.0, 0.0)):
        r = self.rz(z) + d
        return (c[0] + r * math.cos(az), c[1] + r * math.sin(az), z)


def patch(P, az0, az1, z0, z1, d0, d1, c=(0.0, 0.0), n=None):
    """Plaque courbe fermée sur le profil P, entre 2 azimuts et 2 hauteurs, épaisseur d0..d1 au-dessus de la surface."""
    rmax = max(P.rz(z0), P.rz(z1), 0.2)
    n = n or max(2, int(abs(az1 - az0) * rmax / 0.7) + 1)
    rings = []
    for i in range(n + 1):
        a = az0 + (az1 - az0) * i / float(n)
        rings.append([P.pt(a, z0, d0, c), P.pt(a, z0, d1, c), P.pt(a, z1, d1, c), P.pt(a, z1, d0, c)])
    return G.loft(rings, True, True)


def blindage(lot, mats, P, z0, z1, nz, naz, rnd, e=(0.08, 0.34), gap=0.012, vis=0.65, az_dec=0.0, c=(0.0, 0.0), poids=None, Mdet=None):
    """Blindage en plaques sur P : bandes de hauteur inégale, plaques de largeur et d'épaisseur inégales, jamais 2 pareilles."""
    cuts = sorted([0.0, 1.0] + [(i + rnd.f(0.25, 0.75)) / nz for i in range(1, nz)])
    for b in range(len(cuts) - 1):
        za = z0 + (z1 - z0) * cuts[b] + gap * 3
        zb = z0 + (z1 - z0) * cuts[b + 1] - gap * 3
        for k in range(naz):
            th0 = az_dec + G.TAU * k / naz
            if not vu(th0 + G.TAU / naz / 2, vis):
                continue
            n = rnd.i(1, 3)
            cu = sorted([0.0, 1.0] + [rnd.f(0.2, 0.8) for _ in range(n - 1)])
            for i in range(len(cu) - 1):
                a0 = th0 + G.TAU / naz * cu[i] + gap
                a1 = th0 + G.TAU / naz * cu[i + 1] - gap
                x = rnd.f()
                s = 0.0
                m = mats[-1]
                pp = poids or [1.0 / len(mats)] * len(mats)
                for q, pk in enumerate(pp):
                    s += pk
                    if x <= s:
                        m = mats[q]
                        break
                ep = rnd.f(e[0], e[1])
                lot.put(m, patch(P, a0, a1, za, zb, -0.05, ep, c))
                if Mdet is not None and ep > (e[0] + e[1]) * 0.6 and rnd.f() < 0.5:
                    am = (a0 + a1) / 2
                    q = P.pt(am, (za + zb) / 2, ep, c)
                    lot.put(Mdet, R.pose(G.boite((0, 0, 0.03), (min(0.6, (a1 - a0) * P.rz(za) * 0.4), (zb - za) * 0.4, 0.06)), q, P.n(am, (za + zb) / 2)))


def anneau(lot, m, z, r0, r1, h, n=128, c=(0.0, 0.0), a0=0.0, a1=G.TAU):
    """Anneau de section rectangulaire, horizontal."""
    lot.put(m, G.tour([(z - h / 2, r0), (z - h / 2, r1), (z + h / 2, r1), (z + h / 2, r0), (z - h / 2, r0)], n, "z", (c[0], c[1], 0.0), a0=a0, a1=a1))


def fente(lot, T, P, z, az0, az1, demi, Mcadre=None, c=(0.0, 0.0), d=0.04):
    """Fente lumineuse sur P : cadre sombre, bord sombre, milieu, cœur clair (3 couches emboîtées)."""
    e, m_, co = T
    da = 0.08 / max(1.0, P.rz(z))
    if Mcadre is not None:
        lot.put(Mcadre, patch(P, az0 - da, az1 + da, z - demi - 0.08, z + demi + 0.08, -0.03, d, c))
    lot.put(e, patch(P, az0, az1, z - demi, z + demi, 0.0, d + 0.03, c))
    lot.put(m_, patch(P, az0 + da, az1 - da, z - demi * 0.6, z + demi * 0.6, 0.0, d + 0.06, c))
    lot.put(co, patch(P, az0 + 2.2 * da, az1 - 2.2 * da, z - demi * 0.24, z + demi * 0.24, 0.0, d + 0.09, c))


def fentes(lot, T, P, z, n, plein, demi, Mcadre=None, vis=0.6, dec=0.0, c=(0.0, 0.0)):
    """Couronne de n fentes qui remplissent la part `plein` de leur secteur."""
    for k in range(n):
        a0 = dec + G.TAU * k / n
        if not vu(a0, vis):
            continue
        fente(lot, T, P, z, a0, a0 + G.TAU / n * plein, demi, Mcadre, c)


def trio(S, pre, col, force=1.0, clair=(1.0, 0.8, 0.9)):
    """Les 3 matières d'une lumière à dégradé ; pre : préfixe du groupe de lueur."""
    e = S.mat_emissive(pre + "_e", tuple(x * 0.5 for x in col), strength=0.6 * force, base=tuple(x * 0.04 for x in col), main_scale=0.2)
    m = S.mat_emissive(pre + "_m", col, strength=1.0 * force, base=tuple(x * 0.08 for x in col), main_scale=0.22, crust=(1.3, 0.35, 1))
    c = S.mat_emissive(pre + "_c", clair, strength=1.2 * force, base=tuple(x * 0.2 for x in clair), main_scale=0.35)
    return (e, m, c)


def baies(lot, Mcad, Mlum, Mv, P, z, n, rnd, t=(0.14, 0.2), ouvert=0.7, vis=0.5, c=(0.0, 0.0)):
    """Rangée de petites baies (l'échelle d'un personnage), toutes différentes."""
    formes = ["ogive", "carre", "fente", "double", "rond", "octo"]
    for i in range(n):
        az = G.TAU * i / n
        if not vu(az, vis) or rnd.f() > ouvert:
            continue
        R.hublot(lot, Mcad, Mlum if rnd.f() < 0.72 else Mv, P.pt(az, z, 0.02, c), P.n(az, z), formes[rnd.i(0, 5)], t=rnd.f(t[0], t[1]))


def rail(lot, M, r, z, c=(0.0, 0.0), n=40, h=0.42, vis=0.7):
    """Garde-corps circulaire, côté vu."""
    pts = []
    for i in range(n + 1):
        a = G.TAU * i / n
        if vu(a, vis):
            pts.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a), z))
        else:
            if len(pts) > 1:
                R.garde_corps(lot, M, pts, h=h, pas=0.55, r=0.03)
            pts = []
    if len(pts) > 1:
        R.garde_corps(lot, M, pts, h=h, pas=0.55, r=0.03)


def eclat_cristal(lot, m, base, d, L, r, rnd, faces=6):
    """Cristal : prisme à pointe, base posée en `base`, direction d."""
    d = G.norm(d)
    prof = [(0.0, r * 0.7), (0.15 * L, r), (0.72 * L, r * rnd.f(0.8, 1.0)), (L, 0.0)]
    lot.put(m, G.oriente(G.tour(prof, faces, "z", cap0=True), base, d))


def surf_de(pre):
    """Fabrique de matières d'un robot : masses grises si FO_GRIS."""
    def surf(name, col, **kw):
        if GRIS:
            return MT.surface(pre + "g_" + name, (0.2, 0.2, 0.2), rough=0.6, met=0.1, usure=0.3, crasse=0.6, graine=kw.get("graine", 0))
        return MT.surface(pre + "_" + name, col, **kw)
    return surf


def patine(ta=0.15, ra=0.2, ec=0.35, nu_k=1.3, ec_col=(0.03, 0.02, 0.012), sans=()):
    MT.ECH[0] = 3.0
    MT.PATINE.clear()
    MT.PATINE.update(ta=ta, ra=ra, ec=ec, nu_k=nu_k, ec_col=ec_col, sans=sans)
