"""Centre de commandement · Âge 1 · Pionnier (4×4, niveau 1). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« palissade, tour de guet, fanion » : fort de rondins, toit à deux pans de planches, tour de guet de bois sur
le faîte, fanion rouge et lanterne.
"""
import math

import ages
import corps as cp
from corps import halo

EPOQUE = 1
NOM = ages.NOMS[1]
TRIPLET = ('palissade', 'tour de guet', 'fanion')
FOYER = ages.FOYER[1]
HABILLAGE = dict(plan="carre", etages=2, toit="pans", mat_e1="wood", mat_e2="wood2", mat_toit="wood2",
                 plateforme=dict(motif="planches", mat="wood", mat2="wood2", pas=0.17))

RAYON_MAT = 0.46   # rayon du pied du mât (avant échelle) : borne de l'échelle du mât (corps.centre)

FENETRES = "emit"   # ronde F5-A2 : nuit de l'âge 1


def matieres(metal, M):
    ages.matieres(1, metal, M)

def facade(g, c):
    """Palissade : rondins verticaux devant les faces sud et est du premier étage (hors porte)."""
    M = g.M
    h1, H1 = c.T["h"][0], c.T["H"][0]
    z0 = c.zt
    w = c.T["porte"]["w"] / 2 + 0.1
    t = -h1 + 0.04
    while t < h1:
        if abs(t) > w:
            cp.colonne(g, t, -h1 - 0.05, z0, z0 + H1 + 0.08, 0.05, M["wood"], n=8, what="rondin")
            g.dome((t, -h1 - 0.05, z0 + H1 + 0.08), (0, 0, 1), 0.05, M["wood2"], what="pointe")
            if int(round((t + h1) / 0.105)) % 4 == 2:     # ronde F5-A2 : falots sur la palissade (nuit)
                g.cyl((t, -h1 - 0.13, z0 + H1 * 0.7), "z", 0.065, 0.13, M["emit"], n=8, style="flat", what="falot")   # 2c : 0,04 → 0,065
                halo(g, (t, -h1 - 0.3, z0 + H1 * 0.7), M, 2.6)   # ronde 2b : 1,2 → 2,6
        cp.colonne(g, h1 + 0.05, t, z0, z0 + H1 + 0.08, 0.05, M["wood"], n=8, what="rondin")
        t += 0.105
    # ronde 2b (nuit de l'âge 1, presque noire en ronde 2) : deux lanternes sur poteaux de part et d'autre de la porte
    for s_ in (-1, 1):
        xl, yl = s_ * (w + 0.06), -h1 - 0.24
        cp.colonne(g, xl, yl, z0, z0 + H1 * 0.95, 0.03, M["wood"], n=8, what="poteau_lanterne")
        g.cyl((xl, yl, z0 + H1 * 0.95 + 0.07), "z", 0.085, 0.14, M["emit"], n=8, style="flat", what="lanterne_porte")
        g.cyl((xl, yl, z0 + H1 * 0.95 + 0.15), "z", 0.1, 0.025, M["blackiron"], n=8, what="chapeau")
        halo(g, (xl, yl - 0.25, z0 + H1 * 0.95), M, 4.0)


def mat(g, c, z):
    """Tour de guet de bois sur le faîte : 4 poteaux, plancher, garde-corps plein, toit en pointe, fanion, lanterne."""
    M = g.M
    a = 0.34          # ronde F5-A2 : 0,22 → 0,34 (organe plus large)
    hp = 0.7
    for (x, y) in cp.sym4((a, a)):
        cp.colonne(g, x, y, z - 0.1, z + hp, 0.035, M["wood"], n=8, what="poteau_guet")
    cp.dalle(g, -a - 0.06, -a - 0.06, a + 0.06, a + 0.06, z + hp - 0.04, z + hp, M["wood2"], what="plancher")
    for k in range(4):
        x0, y0 = cp.quart((-a - 0.06, -a - 0.06), k)[:2]
        x1, y1 = cp.quart((a + 0.06, -a - 0.06), k)[:2]
        cp.poutre(g, (x0, y0, z + hp + 0.09), (x1, y1, z + hp + 0.09), 0.03, M["wood"], "planche", h=0.18)
    g.cyl((0, 0, z + hp + 0.3), "z", 0.52, 0.3, M["wood2"], n=4, r2=0.0, phase=math.pi / 4, style="hard",
          what="toit_guet")
    cp.colonne(g, 0, 0, z + hp + 0.4, z + hp + 0.95, 0.018, M["wood"], n=6, what="hampe")
    g.box((0.13, 0, z + hp + 0.86), (0.24, 0.012, 0.13), M["redpaint"], "hard", what="fanion")
    g.cyl((0, -a - 0.11, z + hp - 0.17), "z", 0.075, 0.13, M["emit"], n=8, style="flat", what="lanterne")   # 2c : 0,05 → 0,075
    g.cyl((0, -a - 0.1, z + hp - 0.1), "z", 0.06, 0.02, M["blackiron"], n=8, what="chapeau")
    cp.halo(g, (0, -a - 0.3, z + hp - 0.15), M, 5.0)   # ronde 2b : 3 → 5
