"""Foreuse · Âge 4 · Pétrole (ère II, 4×4, niveaux 7 et 8). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « derrick, râtelier de tiges, torchère ». Un DERRICK jaune de signalisation (4 jambes en treillis, croix de
Saint-André noires, plancher d'accrochage à mi-hauteur, moufle noire au sommet) ; à l'avant gauche un RÂTELIER de tiges de
forage galvanisées couchées ; à l'arrière gauche une TORCHÈRE (fût noir, flamme orange). Volants de vannes rouges.
Palette (ages.PALETTE[4]) : jaune / noir et tôles larmées / rouge des volants ; lumière flamme orange.
"""
import math

import ages
import corps as cp

EPOQUE = 4
NOM = ages.NOMS[4]
TRIPLET = ("derrick", "râtelier de tiges", "torchère")
FOYER = ages.FOYER[4]
HABILLAGE = dict(ages.CORPS[4])
PIED = 1.15


def TORCHERE(a):
    """Place de la torchère (ronde F4-A2 : arrière droit ; à l'arrière gauche elle tombait sur l'ancre d'un hauban)."""
    return a * 0.55, a * 0.78


# ronde F4-A2 (un seul corps) : haubans du derrick aux ancres des angles, pas d'embase (les jambes portent sur patins)
EMBASE = dict(r=0.0, contreforts=0, haubans=4, hphase=45.0, zh=0.9, rh=0.3, conduites=2)


def occupe(c):
    """Râtelier de tiges, torchère, vannes."""
    a = c.a
    x0, y0 = -a * 0.72, -a * 0.38
    tx, ty = TORCHERE(a)
    return [(x0 - 0.32, y0 - 0.52, x0 + 0.32, y0 + 0.56), (tx - 0.16, ty - 0.16, tx + 0.16, ty + 0.16),
            (-a + 0.45, 0.35, -a + 0.65, 0.65), (a - 0.65, 0.35, a - 0.45, 0.65)]


def matieres(metal, M):
    ages.matieres(4, metal, M)


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    hb = min(H - 0.30, c.T["z_treillis_max"])
    rb, rh = rt * 1.02, rt * 0.24
    w = 0.08

    def r_at(z):
        return rb + (rh - rb) * (z - zt) / (hb - zt)
    for k in range(4):
        p0 = cp.quart((rb, rb, zt), k)
        p1 = cp.quart((rh, rh, hb), k)
        cp.poutre(g, p0, p1, w, M["jaune_capot"], "jambe")
        g.box((p0[0], p0[1], zt + 0.05), (0.2, 0.2, 0.1), M["noir_capot"], "hard", what="patin")
    niveaux = [zt + (hb - zt) * t for t in (0.0, 0.22, 0.44, 0.64, 0.82, 1.0)]
    for i in range(len(niveaux) - 1):
        z0, z1 = niveaux[i], niveaux[i + 1]
        r0, r1 = r_at(z0), r_at(z1)
        for k in range(4):
            a0, b0 = cp.quart((r0, r0, z0), k), cp.quart((r0, -r0, z0), k)
            a1, b1 = cp.quart((r1, r1, z1), k), cp.quart((r1, -r1, z1), k)
            if i > 0:
                cp.poutre(g, a0, b0, w * 0.75, M["jaune_capot"], "entretoise")
            cp.poutre(g, a0, b1, w * 0.5, M["noir_capot"], "croix")
            cp.poutre(g, b0, a1, w * 0.5, M["noir_capot"], "croix")
    # plancher d'accrochage (tôle larmée) à mi-hauteur
    zp = niveaux[3]
    rp = r_at(zp)
    cp.dalle(g, -rp - 0.12, -rp - 0.12, rp + 0.12, rp + 0.12, zp - 0.03, zp + 0.03, M["tole_larmee"], what="plancher")
    for k in range(4):
        a, b = cp.quart((rp + 0.12, rp + 0.12, zp + 0.14), k), cp.quart((rp + 0.12, -rp - 0.12, zp + 0.14), k)
        cp.poutre(g, a, b, 0.025, M["jaune_capot"], "garde_corps")
    # moufle (bloc couronne) noir, plein, au sommet ; poulies jaunes
    cp.dalle(g, -rh - 0.12, -rh - 0.12, rh + 0.12, rh + 0.12, hb, hb + 0.14, M["noir_capot"], what="couronne")
    g.cyl((0, 0, hb + 0.24), "x", 0.13, 0.30, M["jaune_capot"], n=16, what="poulies")
    cp.colonne(g, 0, 0, hb + 0.14, H, 0.09, M["noir_capot"], n=12, what="sommet")
    # câble de levage et crochet jaune au-dessus du puits
    g.tube([(0, 0, hb), (0, 0, (hb + zt) * 0.55), (0, 0, zt + 0.9)], 0.014, M["steel_hi"], n=6, what="cable")
    g.box((0, 0, zt + 0.82), (0.16, 0.10, 0.16), M["jaune_capot"], "hard", what="moufle_mobile")


def socle(g, c):
    M = g.M
    a, zt = c.a, c.zt
    # râtelier de tiges (avant gauche) : berceaux noirs, tiges galvanisées couchées le long de y
    x0, y0 = -a * 0.72, -a * 0.38
    for dy in (-0.32, 0.32):
        cp.dalle(g, x0 - 0.30, y0 + dy - 0.04, x0 + 0.30, y0 + dy + 0.04, zt, zt + 0.16, M["noir_capot"], what="berceau")
    for i in range(5):
        for j in range(2 if i % 2 == 0 else 1):
            x = x0 - 0.24 + 0.12 * i
            z = zt + 0.22 + 0.10 * j
            g.cyl((x, y0, z), "y", 0.05, 0.95, M["galva"], n=10, what="tige")
            g.cyl((x, y0 + 0.48, z), "y", 0.058, 0.06, M["galva_sombre"], n=10, what="manchon")
    # torchère (arrière gauche) : fût noir haubané, flamme orange
    tx, ty = TORCHERE(a)
    cp.colonne(g, tx, ty, zt, zt + 1.15, 0.07, M["noir_capot"], n=12, what="torchere")
    cp.bague(g, tx, ty, zt + 0.5, 0.07, 0.05, M["jaune_capot"], ep=0.02, n=12, what="bande")
    cp.colonne(g, tx, ty, zt + 1.15, zt + 1.22, 0.10, M["noir_capot"], n=12, what="bec")
    g.cyl((tx, ty, zt + 1.36), "z", 0.09, 0.30, M["emit"], n=10, r2=0.015, style="flat", what="flamme")
    g.cyl((tx, ty, zt + 1.30), "z", 0.06, 0.16, M["amber"], n=10, r2=0.02, style="flat", what="coeur")
    cp.halo(g, (tx, ty - 0.2, zt + 1.3), M, 5.0)
    # vannes à volant rouge sur les départs de fluide
    for (x, y) in ((-a + 0.55, c.T["raccords"]["O"][1]), (a - 0.55, c.T["raccords"]["E"][1])):
        cp.colonne(g, x, y, zt, zt + 0.32, 0.04, M["noir_capot"], n=8, what="tige_vanne")
        g.torus((x, y, zt + 0.34), "z", 0.09, 0.016, M["redpaint"], n=16, m=6, what="volant")


def liaison(g, pts, r):
    M = g.M
    g.pipe(pts, r, M["noir_capot"], fl_mat=M["jaune_capot"], bolt_mat=M["galva_capot"], what="raccord")


def piece(g, c):
    """Gyrophare orange sur une plateforme jaune au sommet du derrick."""
    M = g.M
    z = c.H
    cp.dalle(g, -0.2, -0.2, 0.2, 0.2, z, z + 0.05, M["jaune_capot"], what="plateau")
    for (x, y) in cp.sym4((0.2, 0.2)):
        cp.colonne(g, x, y, z + 0.05, z + 0.2, 0.015, M["noir_capot"], n=6, what="potelet")
    cp.colonne(g, 0, 0, z + 0.05, z + 0.12, 0.10, M["noir_capot"], n=16, what="embase")
    cp.colonne(g, 0, 0, z + 0.12, z + 0.30, 0.085, M["emit"], n=16, style="flat", what="gyrophare")
    g.sphere((0, 0, z + 0.30), 0.085, M["noir_capot"], n=16, m=6, scale=(1, 1, 0.4), what="calotte")
    cp.halo(g, (0, -0.15, z + 0.22), M, 4.0)
