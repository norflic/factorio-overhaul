"""Centre de commandement · Âge 4 · Pétrole (5×5, niveau 4). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« QG jaune, mât radio, torchère » : bureaux d'acier jaune et noir sur trois étages, mât radio effilé à trois
paliers et feux rouges, torchère qui brûle sur un angle du toit.
"""
import math

import ages
import corps as cp

EPOQUE = 4
NOM = ages.NOMS[4]
TRIPLET = ('QG jaune', 'mât radio', 'torchère')
FOYER = ages.FOYER[4]
HABILLAGE = dict(ages.CORPS[4], plan="carre", etages=3, toit="plat", mat_e1="jaune_capot", mat_e2="noir_capot",
                 mat_e3="jaune_capot")

RAYON_MAT = 0.46   # rayon du pied du mât (avant échelle) : borne de l'échelle du mât (corps.centre)


def matieres(metal, M):
    ages.matieres(4, metal, M)

def mat(g, c, z):
    M = g.M
    hm = 1.35
    # ronde F5-A2 : salle radio au pied du mât (organe plus large), vitrée, éclairée la nuit
    g.box((0, 0, z + 0.14), (0.62, 0.46, 0.28), M["jaune_capot"], "hard", what="salle_radio")
    g.box((0, -0.235, z + 0.17), (0.5, 0.012, 0.09), M["emit_soft"], "flat", what="vitres_radio")
    g.box((0, 0, z + 0.29), (0.68, 0.52, 0.03), M["noir_capot"], "hard", what="toit_radio")
    z = z + 0.3
    cp.colonne(g, 0, 0, z, z + 0.08, 0.2, M["noir_capot"], n=8, style="hard", what="pied_mat")
    cp.colonne(g, 0, 0, z + 0.08, z + hm, 0.1, M["jaune_capot"], n=12, r2=0.04, what="mat_radio")
    for i, f in enumerate((0.3, 0.55, 0.8)):
        zz = z + hm * f
        rr = 0.24 - 0.04 * i
        cp.colonne(g, 0, 0, zz, zz + 0.03, rr, M["noir_capot"], n=12, style="hard", what="palier")
        for k in range(4):
            x, y = cp.quart((rr * 0.95, 0.0), k)[:2]
            g.dome((x, y, zz + 0.03), (0, 0, 1), 0.025, M["redpaint"], what="feu_rouge")
    g.dome((0, 0, z + hm), (0, 0, 1), 0.04, M["emit"], what="feu_sommet")
    cp.halo(g, (0, -0.1, z + hm + 0.05), M, 2.0)
    x, y = 0.36, -0.3          # coordonnées avant l'échelle du mât (corps.centre)
    cp.colonne(g, x, y, z, z + 0.5, 0.028, M["noir_capot"], n=8, what="torchere")
    g.cyl((x, y, z + 0.62), "z", 0.09, 0.28, M["amber"], n=8, r2=0.0, style="flat", what="flamme")
    cp.halo(g, (x, y - 0.1, z + 0.6), M, 2.5)
