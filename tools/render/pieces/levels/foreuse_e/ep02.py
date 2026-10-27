"""Foreuse · Âge 2 · Forge (ère I, 3×3, niveaux 3 et 4). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « balancier, massif de briques, foyer rouge ». Foreuse à BATTAGE : un MASSIF DE BRIQUES carré (assises
décalées, chaînes d'angle de fer noir) couvre le puits ; une GUEULE DE FOYER rougeoie au pied de chacune des 4 faces ;
sur le massif, un chevalet de fer forgé porte le BALANCIER (poutre de fer martelé à tête de cheval), qui lève et laisse
tomber le trépan. Palette 60/30/10 (ages.PALETTE[2]) : fer martelé / brique rouge / braise rouge.
"""
import math

import ages
import corps as cp
from habillage import habille

EPOQUE = 2
NOM = ages.NOMS[2]
TRIPLET = ("balancier", "massif de briques", "foyer rouge")
FOYER = ages.FOYER[2]
HABILLAGE = dict(ages.CORPS[2])
PIED = 1.25
# ronde F4-A2 (un seul corps) : embase de fer sous le massif, une conduite (le 3×3 est plein : charbon, enclume, moteur)
EMBASE = dict(r=1.32, contreforts=0, haubans=0, conduites=1, cdphase=62.0)


def occupe(c):
    """Accents du tablier (la garniture de lignée les évite) : charbon, enclume."""
    a, my = c.a, c.T["moteur"]["y"]
    return [(-0.42 * a - 0.28, my - 0.22, -0.42 * a + 0.28, my + 0.22),
            (-0.55 * a - 0.2, 0.55 * a - 0.12, -0.55 * a + 0.2, 0.55 * a + 0.12)]


def matieres(metal, M):
    ages.matieres(2, metal, M)


def _assises(g, c, x0, x1, y0, y1, z0, z1, n):
    """Massif de briques en assises (une assise sur deux décalée, mortier en retrait)."""
    M = g.M
    h = (z1 - z0) / n
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0 - 0.03, y1 - y0 - 0.03, z1 - z0), M["mortier"],
          "hard", what="mortier")
    for i in range(n):
        za = z0 + h * i + h / 2
        m = M["brique"] if i % 2 else M["brique_pave"]
        e = 0.012 if i % 2 else 0.0
        g.box(((x0 + x1) / 2, (y0 + y1) / 2, za), (x1 - x0 + e, y1 - y0 - e, h * 0.82), m, "hard", what="assise")


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt * 1.14, c.zt, c.H      # ronde F4-A2 : massif plus grand dans son 3×3 (DC : « âges 2 et 3 plus grands »)
    zm = zt + 0.56 * H
    _assises(g, c, -rt, rt, -rt, rt, zt, zm, 9)
    # chaînes d'angle et ceinture de fer
    for (x, y) in cp.sym4((rt, rt)):
        cp.dalle(g, x - 0.05, y - 0.05, x + 0.05, y + 0.05, zt, zm + 0.02, M["fer_noir"], what="chaine")
    cp.bague(g, 0, 0, zm - 0.06, rt * 1.0, 0.05, M["fer_noir"], ep=0.03, n=4, what="ceinture")
    # couronnement : dessus de briques (le massif se lit BRIQUE vu de haut), cadre de fer forgé riveté
    for i in range(5):
        y0 = -rt + 2 * rt * i / 5.0
        m = M["brique"] if i % 2 else M["brique_pave2"]
        cp.dalle(g, -rt + 0.06, y0 + 0.012, rt - 0.06, y0 + 2 * rt / 5.0 - 0.012, zm, zm + 0.05, m, what="dessus")
    for k in range(4):
        a, b = cp.quart((-rt - 0.04, rt - 0.02, zm + 0.04), k), cp.quart((rt + 0.04, rt - 0.02, zm + 0.04), k)
        cp.poutre(g, a, b, 0.08, M["fer_noir"], "cadre", h=0.09)
    for (x, y) in cp.sym4((rt - 0.02, 0.0)) + cp.sym4((rt - 0.02, rt * 0.6)) + cp.sym4((rt - 0.02, -rt * 0.6)):
        g.dome((x, y, zm + 0.09), (0, 0, 1), 0.02, M["fer_clair_f"])
    # cheminée de foyer à l'angle arrière droit du massif (silhouette)
    cp.dalle(g, rt * 0.45, -rt * 0.95, rt * 0.95, -rt * 0.45, zm, zm + 0.35 * H, M["brique"], what="cheminee")
    cp.dalle(g, rt * 0.40, -rt * 1.0, rt * 1.0, -rt * 0.40, zm + 0.35 * H, zm + 0.35 * H + 0.06, M["fer_noir"],
             what="chapeau")
    g.box((rt * 0.7, -rt * 0.7, zm + 0.35 * H + 0.065), (rt * 0.32, rt * 0.32, 0.01), M["emit"], "flat", what="braise")
    # gueules de foyer au pied des 4 faces (foyer rouge)
    for k in range(4):
        x, y = cp.quart((0.0, -rt - 0.005), k)
        w, hh = rt * 0.75, 0.26
        sx, sy = (w, 0.02) if k % 2 == 0 else (0.02, w)
        g.box((x, y, zt + 0.17), (sx, sy, hh), M["emit"], "flat", what="gueule")
        fx, fy = cp.quart((0.0, -rt - 0.03), k)
        g.box((fx, fy, zt + 0.32), (sx + 0.08 if k % 2 == 0 else 0.05, sy + 0.08 if k % 2 else 0.05, 0.05),
              M["fer_noir"], "hard", what="linteau")
        cp.halo(g, (x * 1.25, y * 1.25, zt + 0.2), M, 3.0)
    # chevalet (deux A de fer) et balancier le long de l'axe de sortie
    zp = zt + 0.86 * H
    for sx in (-1, 1):
        for sy in (-1, 1):
            cp.poutre(g, (sx * rt * 0.32, sy * rt * 0.28, zm + 0.05), (sx * 0.09, 0.0, zp), 0.07, M["fer_noir"], "pied")
    g.cyl((0, 0, zp), "x", 0.07, 0.26, M["fer_clair_f"], n=12, what="pivot")
    L0, L1 = -rt * 1.25, rt * 1.35
    cp.poutre(g, (0, L0, zp + 0.06), (0, L1, zp + 0.10), 0.12, M["fer_martele"], "balancier", h=0.16)
    # tête de cheval (avant) et contrepoids (arrière)
    g.cyl((0, L1, zp + 0.02), "x", 0.17, 0.12, M["fer_martele"], n=16, what="tete_cheval")
    cp.dalle(g, -0.11, L0 - 0.12, 0.11, L0 + 0.12, zp - 0.14, zp + 0.04, M["fer_noir"], what="contrepoids")
    for t in (0.2, 0.45, 0.7):
        y = L0 + (L1 - L0) * t
        g.dome((0.0, y, zp + 0.19), (0, 0, 1), 0.022, M["fer_clair_f"])
    # tige de battage pendue à la tête de cheval
    g.tube([(0.0, L1 + 0.14, zp - 0.05), (0.0, L1 + 0.14, zm + 0.30), (0.0, L1 + 0.14, zm + 0.10)], 0.018, M["fer_noir"],
           n=6, what="tige_battage")
    # sommet invariant : chapeau du pivot (la pièce paire s'y pose)
    cp.colonne(g, 0, 0, zp + 0.10, H, 0.10, M["fer_noir"], n=12, what="sommet")


def trepan(g, c):
    """Le trépan de battage est sous le massif : seul son guide dépasse la margelle."""
    M = g.M
    cp.colonne(g, 0, 0, c.zt, c.zt + 0.12, c.rw * 0.6, M["fer_noir"], n=16, what="guide")


def socle(g, c):
    M = g.M
    # tas de charbon et pelle près du moteur, enclume à l'angle avant gauche
    x, y = -0.42 * c.a, c.T["moteur"]["y"]
    for i, (dx, dy, r) in enumerate(((0, 0, 0.16), (0.12, 0.06, 0.11), (-0.1, 0.08, 0.1), (0.04, -0.1, 0.09))):
        g.sphere((x + dx, y + dy, c.zt + r * 0.35), r, M["soot"], n=8, m=5, scale=(1, 1, 0.55), what="charbon")
    g.box((-c.a * 0.55, c.a * 0.55, c.zt + 0.12), (0.22, 0.14, 0.24), M["fer_noir"], "hard", what="enclume")
    g.box((-c.a * 0.55, c.a * 0.55, c.zt + 0.27), (0.32, 0.12, 0.06), M["fer_martele"], "hard", what="table_enclume")


def montant(g, c, x, y):
    """Montants : piliers de briques à chapeau de fer."""
    M = g.M
    T = c.T["montant"]
    w, h = T["w"] * 1.2, T["h"]
    _assises(g, c, x - w / 2, x + w / 2, y - w / 2, y + w / 2, 0.0, h, 4)
    g.box((x, y, h + 0.03), (w * 1.15, w * 1.15, 0.06), M["fer_noir"], "hard", what="chapeau")


def piece(g, c):
    """Braséro de fer forgé sur le pivot : corbeille à barreaux, braise rouge."""
    M = g.M
    z = c.H
    cp.colonne(g, 0, 0, z, z + 0.14, 0.05, M["fer_noir"], n=8, what="tige")
    cp.colonne(g, 0, 0, z + 0.14, z + 0.38, 0.17, M["emit"], n=12, r2=0.21, style="flat", what="braise")
    for k in range(8):
        a = math.tau * k / 8
        cp.poutre(g, (0.17 * math.cos(a), 0.17 * math.sin(a), z + 0.12), (0.23 * math.cos(a), 0.23 * math.sin(a),
                                                                        z + 0.42), 0.03, M["fer_noir"], "barreau")
    cp.bague(g, 0, 0, z + 0.40, 0.22, 0.04, M["fer_martele"], ep=0.02, n=16, what="cerclage")
    cp.bague(g, 0, 0, z + 0.16, 0.18, 0.04, M["fer_martele"], ep=0.02, n=16, what="cerclage")
    cp.halo(g, (0, -0.2, z + 0.35), M, 4.0)
