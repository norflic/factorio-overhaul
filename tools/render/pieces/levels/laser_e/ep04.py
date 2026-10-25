"""Laser · Âge 4 · Pétrole (ère II, 3×3, niveaux 7 et 8). Lot F1-B (25/10) ; fiche : fo-logs/2026-10-24_F1/FICHES_LASER.md,
âge 4 (fait foi). S'exécute DANS Blender.

En 3 mots : « cuve couchée, bidons, volants rouges ». Un laser « au mazout » : l'émetteur est une CUVE JAUNE COUCHÉE EN
TRAVERS du faisceau (fonds bombés, cerclages noirs), un grand HUBLOT de flamme sur sa face avant, deux VOLANTS ROUGES sur
le dessus, aux deux bouts, et un niveau à glace ; derrière, une pompe à huile à volant rouge. Affût en PLATE-FORME :
octogone à 2 gradins jaune et noir sur 4 contreforts, tuyauterie noire à brides jaunes qui ceint le premier gradin,
vannes rouges, bandes de danger ; 12 bidons de 200 L debout ; deux cuves debout à échelle aux coins arrière.
Palette 60/30/10 (ages.PALETTE[4]) : jaune de signalisation / noir (tôle larmée, structure) / rouge des volants ;
flamme orange.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import epoques as E_
import formes as F
import orne as O
import parts as PT
import parts2 as P2
import parts3 as P3
from kit import TAU
from repere import Y, at

V = Vector

EPOQUE = 4
NOM = ages.NOMS[4]
TRIPLET = ("cuve couchée", "bidons", "volants rouges")
FOYER = ages.FOYER[4]
FAISCEAU = dict(rgb=(1.0, 0.55, 0.15), rgb2=(1.0, 0.42, 0.1), forme="trait orange épais, traîne de fumée noire le "
                "long du trait (laser au mazout)", largeur=1.3)
HABILLAGE = dict(ages.CORPS[4], **E_.MAQUETTES[4])


def matieres(metal, M):
    ages.matieres(4, metal, M)
    M["cuve"] = M["jaune_capot"]


def liaison(g, pts, r):
    """Conduite noire à brides jaunes boulonnées."""
    M = g.M
    g.pipe(pts, r, M["noir_capot"], fl_mat=M["jaune_capot"], bolt_mat=M["galva_capot"])


def condensateur(g, c, x, y, z, r, h):
    """Bidon de 200 L debout : virole jaune, deux nervures noires, bonde rouge."""
    M = g.M
    F.drum(g, (x, y, z), r * 0.95, h * 0.9, M["yellowpaint"], M["noir_capot"])
    g.cyl((x - r * 0.3, y + r * 0.2, z + h * 0.9 + 0.012), "z", 0.026, 0.024, M["redpaint"], n=8, what="bonde")


def _danger(g, k, h):
    """Bande de danger jaune et noir (repère du flanc : x tangente, y haut, z sortant)."""
    M = g.M
    w = 0.34
    g.box((0, 0, 0.004), (w, h * 0.22, 0.008), M["noir_capot"], "flat", what="danger_fond")
    for i in range(5):
        g.box((-w / 2 + (i + 0.5) * w / 5, 0, 0.01), (0.03, h * 0.3, 0.006), M["jaune_capot"], "flat",
              R=Matrix.Rotation(0.6, 3, "Z"), what="danger")


def _vanne(g, k, h):
    """Vanne à volant rouge piquée sur la tuyauterie du flanc."""
    M = g.M
    g.cyl((0, 0, 0.03), "z", 0.035, 0.06, M["noir_capot"], n=10, what="corps_vanne")
    P2.handwheel(g, (0, 0, 0.08), (0, 0, 1), 0.06, M)


def _lampes(g, k, h):
    O.lampe(g, (0, 0, 0), (0, 0, 1), 0.022, g.M["emit"], g.M["noir_capot"])


def _dessus1(g, k, w):
    """Entre deux bidons, sur le premier gradin : jerricans, boîtes à outils, vannes."""
    M = g.M
    if k % 3 == 0:
        g.box((0, 0, 0.05), (0.07, 0.11, 0.1), M["redpaint"], "soft", what="jerrican")
        g.box((0, 0.03, 0.105), (0.03, 0.03, 0.012), M["noir_capot"], "hard", what="bouchon")
    elif k % 3 == 1:
        g.box((0, 0, 0.03), (0.08, 0.13, 0.06), M["noir_capot"], "hard", what="boite")
        g.box((0, 0, 0.064), (0.02, 0.1, 0.01), M["jaune_capot"], "hard", what="poignee")
    else:
        P2.handwheel(g, (0, 0, 0.06), (0, 0, 1), 0.045, M)


def _dessus2(g, k, w):
    """Second gradin : petits fûts et collecteur."""
    M = g.M
    if k % 2 == 0:
        F.drum(g, (0, 0, 0), 0.07, 0.17, M["yellowpaint"], M["noir_capot"])
    else:
        g.cyl((0, 0, 0.05), "x", 0.035, 0.18, M["noir_capot"], n=12, what="collecteur")
        for s in (-1, 1):
            g.cyl((s * 0.07, 0, 0.09), "z", 0.02, 0.06, M["galva_capot"], n=8, what="piquage")
        P2.handwheel(g, (0, 0, 0.11), (0, 0, 1), 0.04, M)


def socle(g, c):
    """Tuyauterie noire à brides qui ceint le premier gradin, vannes rouges, bandes de danger, voyants orange, cuves
    debout à échelle (coins arrière), conduites vers le pivot, jerricans et fûts sur les gradins."""
    M = g.M
    zp = c.gradins[-1][3]
    O.ceinture(g, c, 0, 0.36, 0.03, M["noir_capot"], colliers=M["jaune_capot"], pas=0.35)
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (232, 308)], _vanne, f=0.36, dr=0.04)
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (205, 255, 285, 335)], _danger, f=0.82, dr=0.006)
    O.ceinture(g, c, 1, 0.3, 0.022, M["noir_capot"], colliers=M["galva_capot"], pas=0.3)
    O.rivets_flanc(g, c, 1, 0.8, M["galva_capot"], pas=0.12, r=0.012)
    O.sur_flanc(g, c, 1, [math.radians(a) for a in (215, 270, 325)], _lampes, f=0.62, dr=0.004)
    O.sur_dessus(g, c, 0, O.visibles(O.entre_condensateurs(c), nord=0.2), _dessus1)
    O.sur_dessus(g, c, 1, [math.radians(a) for a in (200, 240, 300, 340)], _dessus2)
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        p = corps.place(c, nom)
        x, yn = p["x"] - sx * 0.04, p["yn"] - 0.04
        P3.vtank(g, x, Y(yn), 0.2, 0.62, M, paint=M["jaune_capot"], emat=M["emit"], ladder_dir=(sx, 0.0), gauges=1,
                 band=M["noir_capot"])
        P2.handwheel(g, (x - sx * 0.12, Y(yn) - 0.16, 0.42), (0, -1, 0.3), 0.06, M)
        liaison(g, [(x - sx * 0.1, Y(yn - 0.22), 0.2), (x * 0.66, Y(yn * 0.62), c.gradins[0][3] + 0.1),
                    (x * 0.42, Y(yn * 0.4), zp + 0.06)], 0.035)
        g.halo((x, Y(yn - 0.3), 0.2), M["_emit_rgb"], 3.0)
    g.halo((0.0, Y(-1.3), 0.3), M["_emit_rgb"], 4.0)


def piece(g, c):
    """Niveau 8 : deux PALETTES DE TROIS BIDONS avec une pompe à main, aux coins avant, sur un patin relié au premier
    gradin."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * p["x"], p["yn"]
        corps.patin(g, c, x - sx * 0.1, yn + 0.1, 0.62, 0.62, rz=sx * 0.785)
        with at(g, x, yn, sx * 0.3, z=0.035):
            for i in range(4):
                g.box((0, (i - 1.5) * 0.12, 0.02), (0.46, 0.08, 0.03), M["wood"], "hard", what="palette")
            for i in range(2):
                g.box(((i - 0.5) * 0.36, 0, 0.045), (0.06, 0.46, 0.03), M["wood"], "hard", what="traverse")
            for k, (dx, dy) in enumerate(((-0.11, -0.1), (0.11, -0.1), (0.0, 0.11))):
                F.drum(g, (dx, dy, 0.06), 0.1, 0.3, M["yellowpaint"] if k != 2 else M["redpaint"], M["noir_capot"])
            g.cyl((0.0, 0.11, 0.42), "z", 0.02, 0.1, M["noir_capot"], n=8, what="pompe")
            g.box((0.04, 0.11, 0.47), (0.12, 0.014, 0.014), M["redpaint"], "hard", what="levier")
            g.tube([V((0.0, 0.11, 0.4)), V((-0.08, 0.02, 0.4)), V((-0.12, -0.08, 0.38))], 0.012, M["rubber"], n=6,
                   what="tuyau")
        g.halo((x, Y(yn), 0.3), M["_emit_rgb"], 3.0)


def arriere(g, c):
    """Pompe à huile : moteur noir couché, volant rouge, radiateur à huile."""
    M = g.M
    t = c.T["tete"]
    zb = O.zb(c)
    bx, y0, y1, z1 = t["bx"], t["yb0"], t["yb1"], t["zb1"]
    yc = (y0 + y1) / 2
    g.box((0, yc, zb + 0.03), (2 * bx, y1 - y0, 0.06), M["noir_capot"], "hard", what="semelle")
    rm = min(0.13, (z1 - zb) * 0.4)
    g.cyl((-0.05, yc, zb + 0.06 + rm), "x", rm, 2 * bx * 0.75, M["noir_capot"], n=20, style="soft", what="moteur")
    for k in range(5):
        g.tube_shell((-0.05 - bx * 0.6 + k * bx * 0.3, yc, zb + 0.06 + rm), "x", rm + 0.012, rm - 0.01, 0.02,
                     M["galva_capot"], n=20, what="ailette")
    F.disc_wheel(g, (bx * 0.85, yc, zb + 0.06 + rm), "x", rm * 1.15, 0.04, M["redpaint"], M["redpaint"], spokes=5)
    PT.radiator(g, (-bx * 0.1, y0 + 0.05, zb + 0.06), 2 * bx * 0.8, (z1 - zb) * 0.7, 0.05, fin_mat=M["noir_capot"])


def tete(g, c):
    """Burette d'huile et manomètre sur poteau à l'arrière de la platine ; tuyau d'huile vers la cuve."""
    M = g.M
    zb = O.zb(c)
    (xl, yl, wl), (xr, yr, wr) = O.pods(c)
    F.drum(g, (xl, yl, zb), wl, wl * 2.2, M["yellowpaint"], M["noir_capot"])
    g.cyl((xr, yr, zb + 0.06), "z", 0.02, 0.12, M["noir_capot"], n=8, what="poteau")
    P2.gauge(g, (xr, yr - 0.03, zb + 0.13), (0, -1, 0.3), 0.04, M, face=M["emit_soft"])
    g.hose([(xl, yl + wl, zb + 0.1), (xl * 0.7, yl * 0.3, zb + 0.14), (xl * 0.5, 0.0, c.zh - 0.45 * c.re)], 0.016,
           M["rubber"], step=0.03, n=8, what="durite")


def emetteur(g, c):
    """CUVE JAUNE COUCHÉE EN TRAVERS (axe x, fonds bombés, cerclages noirs, trou d'homme), HUBLOT de flamme sur la face
    avant (la lentille), deux VOLANTS ROUGES sur le dessus aux deux bouts, niveau à glace, bandes de danger."""
    M = g.M
    re, zh = c.re, c.zh
    r = 0.7 * re
    L = 1.5 * re
    g.cyl((0, 0, zh), "x", r, L, M["jaune_capot"], n=32, style="soft", what="cuve")
    for sx in (-1, 1):
        g.sphere((sx * L / 2, 0, zh), r, M["jaune_capot"], n=32, m=12, scale=(0.32, 1.0, 1.0), what="fond")
        g.tube_shell((sx * L * 0.48, 0, zh), "x", r + 0.014, r - 0.01, 0.04, M["noir_capot"], n=32, what="cerclage")
        # volants rouges sur le dessus, près des bouts, tournés vers le haut
        P2.handwheel(g, (sx * L * 0.33, -0.05 * re, zh + r + 0.06), (0, -0.25, 1), 0.2 * re, M)
    g.tube_shell((0, 0, zh), "x", r + 0.014, r - 0.01, 0.04, M["noir_capot"], n=32, what="cerclage")
    # trou d'homme boulonné sur le dessus
    g.cyl((0, -0.15 * re, zh + r + 0.01), "z", 0.16 * re, 0.04, M["noir_capot"], n=16, style="hard", what="trou_homme")
    F.bolts_ring(g, (0, -0.15 * re, zh + r + 0.032), (0, 0, 1), 0.12 * re, 8, M["galva_capot"], r=0.012)
    # hublot de flamme (lentille) sur une collerette de la face avant
    g.cyl((0, r * 0.8, zh), "y", 0.36 * re, 0.4 * r, M["noir_capot"], n=24, style="soft", what="collerette")
    corps.lentille(g, c, r + 0.04, 0.3 * re, verre=M["glass_dk"], cercle=M["noir_capot"])
    # niveau à glace (tube de verre court, sur le flanc avant)
    g.cyl((0.4 * L, r * 0.86, zh - 0.25 * r), "x", 0.03, 0.22 * L, M["glass_dk"], n=10, style="smooth", what="niveau")
    g.box((0.4 * L, r * 0.88, zh - 0.25 * r), (0.2 * L, 0.012, 0.024), M["emit"], "flat", what="huile_vue")
    for s in (-1, 1):
        g.box((0.4 * L + s * 0.12 * L, r * 0.84, zh - 0.25 * r), (0.025, 0.05, 0.06), M["noir_capot"], "hard",
              what="robinet")
    # bandes de danger sur la virole, au-dessus du hublot
    for i in range(6):
        g.box(((i - 2.5) * 0.06, r * 0.72, zh + r * 0.62), (0.03, 0.03, 0.06), M["noir_capot"], "flat",
              R=Matrix.Rotation(0.6, 3, "Y") @ Matrix.Rotation(-0.85, 3, "X"), what="danger")
