"""Centre de commandement · Âge 14 · La Porte (8×8, niveau 14). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« anneau de la Porte, horizon étoilé, pieds lunaires » : tambour indigo et blanc lunaire, grand anneau
vertical de la Porte face au sud sur deux pieds, fermé par l'horizon étoilé.
"""
import math

import ages
import corps as cp

EPOQUE = 14
NOM = ages.NOMS[14]
TRIPLET = ('anneau de la Porte', 'horizon étoilé', 'pieds lunaires')
FOYER = ages.FOYER[14]
HABILLAGE = dict(ages.CORPS[14], plan="rond", etages=2, toit="plat", mat_e1="indigo_nuit", mat_e2="blanc_lunaire")

RAYON_MAT = 1.12   # rayon du pied du mât (avant échelle) : borne de l'échelle du mât (corps.centre)

ARCHI = True   # ronde F5-A2 : contreforts, baies, balcon, verrière (corps.architecture)


def matieres(metal, M):
    ages.matieres(14, metal, M)

def mat(g, c, z):
    M = g.M
    R, r = 0.85, 0.14
    zr = z + R + 0.3
    # ronde F5-A2 : l'anneau se lisait comme un PUITS (face au sud, vu d'en haut : ellipse aplatie). Tourné de 35° vers
    # le sud-ouest, il se lit DEBOUT (ellipse étroite) ; socle à degrés et deux pylônes qui le tiennent
    cp.dalle(g, -R - 0.25, -0.35, R + 0.25, 0.35, z, z + 0.08, M["blanc_lunaire"], what="socle_anneau")
    cp.dalle(g, -R - 0.12, -0.25, R + 0.12, 0.25, z + 0.08, z + 0.16, M["indigo_nuit2"], what="socle_anneau")
    g.push((0, 0, 0), rz=math.radians(-35))
    for s in (-1, 1):
        g.cyl((s * (R + 0.1), 0, z + 0.16 + (zr - z) * 0.5), "z", 0.13, zr - z + 0.1, M["blanc_lunaire"], n=4, r2=0.08,
              phase=math.pi / 4, style="hard", what="pylone")
        g.dome((s * (R + 0.1), 0, zr + 0.25), (0, 0, 1), 0.05, M["emit"], what="feu_pylone")
    g.torus((0, 0, zr), "y", R, r, M["blanc_lunaire"], n=56, m=12, what="anneau")
    g.cyl((0, 0, zr), "y", R - r * 0.3, 0.05, M["horizon_porte"], n=56, what="horizon")
    for i in range(24):
        a = math.tau * i / 24
        g.box((R * math.cos(a), 0, zr + R * math.sin(a)), (0.08, 0.13, 0.08), M["indigo_nuit"], "hard", what="chevron")
    rng = 17
    for i in range(70):
        rng = (rng * 1103515245 + 12345) % 2147483648
        a = math.tau * (rng % 1000) / 1000.0
        rr = (R - 0.18) * math.sqrt(((rng // 1000) % 1000) / 1000.0)
        g.dome((rr * math.cos(a), -0.03, zr + rr * math.sin(a)), (0, -1, 0), 0.02, M["emit"], n=6)
    g.pop()
    cp.halo(g, (0, -0.6, zr), M, 4.0)
