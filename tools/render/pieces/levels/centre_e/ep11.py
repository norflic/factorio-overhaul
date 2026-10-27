"""Centre de commandement · Âge 11 · Titane (7×7, niveau 11). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« radar tournant, fuseau, ailerons orange » : tambour de titane rond à deux étages, fuseau effilé à quatre
ailerons orange et radar à réflecteur incliné.
"""
import math

import ages
import corps as cp

EPOQUE = 11
NOM = ages.NOMS[11]
TRIPLET = ('radar tournant', 'fuseau', 'ailerons orange')
FOYER = ages.FOYER[11]
HABILLAGE = dict(ages.CORPS[11], plan="rond", etages=2, toit="plat", mat_e1="titane_cl", mat_e2="titane_md")

RAYON_MAT = 0.45   # rayon du pied du mât (avant échelle) : borne de l'échelle du mât (corps.centre)


def matieres(metal, M):
    ages.matieres(11, metal, M)

def mat(g, c, z):
    M = g.M
    hf = 1.5
    cp.colonne(g, 0, 0, z, z + hf * 0.75, 0.16, M["titane_md"], n=20, r2=0.1, what="fuseau")
    g.cyl((0, 0, z + hf * 0.75 + hf * 0.125), "z", 0.1, hf * 0.25, M["titane_cl"], n=20, r2=0.0, what="pointe_fuseau")
    for k in range(4):
        a = math.tau * (k + 0.5) / 4
        u = (math.cos(a), math.sin(a))
        q = [(u[0] * 0.14, u[1] * 0.14, z + 0.05), (u[0] * 0.45, u[1] * 0.45, z + 0.05), (u[0] * 0.14, u[1] * 0.14, z + 0.6)]
        pts = [cp.V(p) for p in q]
        n = cp.V((-u[1], u[0], 0)) * 0.025
        g._add(M["orange_aero"], "hard", [tuple(p - n) for p in pts] + [tuple(p + n) for p in pts],
               [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], "aileron")
    zr = z + hf * 0.45
    cp.colonne(g, 0, 0, zr, zr + 0.06, 0.2, M["titane_dk"], n=16, style="hard", what="pivot_radar")
    g.push((0, 0.05, zr + 0.2), rz=0.0, rx=math.radians(25))
    g.box((0, 0, 0), (0.7, 0.04, 0.28), M["ring"], "hard", what="reflecteur")
    g.pop()
    g.dome((0, 0, z + hf), (0, 0, 1), 0.035, M["emit"], what="feu_fuseau")
    cp.halo(g, (0, -0.35, zr + 0.2), M, 3.0)
