"""Icônes des TECHNOLOGIES (s'exécute dans Blender) : 7 scènes différentes, une par étape de la chaîne."""
import math
import random

import scene_base as P
import scene_baies as Z
from scene_base import B, CY, CYX, SPH, TOR, capte, lathe, pivoter, roche, tube
import scene_objets as O


def tech_wafer_fab():
    """Le lingot qu'on tranche : gros lingot couché, vu de sa face coupée ; tranches qui s'en détachent, faces visibles."""
    o = capte(O.lingot, 6.2, 1.5)
    pivoter(o, rot=(0, 90, 0), loc=(-2.7, 0, 1.6))
    TOR(1.56, 0.06, 0.25, 0, 1.6, "voyant_bleu", rot=(0, 90, 0), minor=10)
    for i in range(4):
        d = capte(O.galette, 1.48, 0.10, "silicium_poli")
        pivoter(d, rot=(0, 90 - 5 * i, 0), loc=(1.15 + i * 1.02, 0, 1.6 + 0.02 * i * i))


def tech_chip_foundry():
    """La fonderie : grande tranche gravée inclinée, et devant elle les 3 puces qu'elle donne."""
    t = capte(O.tranche_gravee, 3.6, 0.94)
    pivoter(t, rot=(62, 0, 0), loc=(0, 1.2, 3.0))
    pivoter(capte(O.puce_logique), rot=(0, 0, 22), loc=(-2.7, -2.1, 0.0), s=0.52)
    pivoter(capte(O.puce_dram), rot=(0, 0, -10), loc=(0.15, -2.75, 0.0), s=0.52)
    pivoter(capte(O.puce_sram), rot=(0, 0, 45), loc=(2.85, -1.75, 0.0), s=0.50)


def tech_data_centers():
    """Centres de calcul : allée de 3 armoires à voyants bleus, chemin de câbles, un tiroir de serveur tiré."""
    for i, fn in enumerate((Z.ic_memory_rack, Z.ic_server_blade, Z.ic_storage_rack)):
        pivoter(capte(fn), loc=(-3.9 + i * 3.9, 0, 0))
    B(11.6, 0.8, 0.18, 0, 0, 5.85, "titane_sombre", bev=0.03)
    for i in range(5):
        CYX(0.11, 11.2, 0, -0.26 + i * 0.13, 6.15, "cable_bleu" if i % 2 else "cable_jaune", verts=12, axe="x")
    # tiroir tiré de l'armoire du milieu, sur ses glissières
    zb, yc, LX, LY = 2.2, -2.9, 2.5, 2.9
    for s in (-1, 1):
        B(0.10, LY + 0.7, 0.14, s * (LX / 2 + 0.06), yc + 0.4, zb + 0.08, "titane_sombre", bev=0.01)
    B(LX, LY, 0.10, 0, yc, zb, "carenage_clair", bev=0.02)
    for s in (-1, 1):
        B(0.08, LY, 0.40, s * (LX / 2 - 0.04), yc, zb, "carenage_clair", bev=0.015)
    B(LX - 0.2, LY - 0.3, 0.05, 0, yc + 0.05, zb + 0.10, "pcb_vert", bev=0.008)
    for s in (-1, 1):
        B(0.84, 0.90, 0.06, s * 0.58, yc - 0.45, zb + 0.15, "alu_sombre", bev=0.01)
        for k in range(6):
            B(0.84, 0.08, 0.40, s * 0.58, yc - 0.82 + k * 0.15, zb + 0.21, "alu_brosse", bev=0.008)
    for k in range(4):
        B(2.0, 0.09, 0.32, 0, yc + 0.35 + k * 0.22, zb + 0.15, "puce_noire", bev=0.008)
        B(1.9, 0.05, 0.018, 0, yc + 0.35 + k * 0.22, zb + 0.47, "voyant_teal", bev=0)
    fy = yc - LY / 2 - 0.05
    B(LX + 0.1, 0.10, 0.52, 0, fy, zb, "carenage_clair", bev=0.02)
    for s in (-1, 1):
        B(0.10, 0.20, 0.34, s * (LX / 2 - 0.22), fy - 0.12, zb + 0.09, "titane_sombre", bev=0.015)
    for k in range(4):
        B(0.16, 0.02, 0.10, 0.1 + k * 0.22, fy - 0.055, zb + 0.28, "voyant_bleu", bev=0)


def tech_gpu_computing():
    """Calcul accéléré : 3 cartes graphiques empilées en biais, la première bien en vue."""
    for i in range(3):
        pivoter(capte(O.carte_graphique, 6.4, 3.3), rot=(0, 0, 28), loc=(1.25 - i * 1.25, 1.3 - i * 1.3, 2.1 - i * 1.05))


def tech_data_centers_2():
    """Centres de calcul refroidis : armoire à plaques froides, gros tuyaux bleus, réservoir d'azote liquide givré."""
    pivoter(capte(Z.ic_gpu_blade), loc=(-2.5, 0, 0))
    pivoter(capte(Z.ic_server_blade), loc=(1.45, 0, 0), s=1.0)
    # réservoir (dewar) à droite
    x, y = 5.3, -0.4
    lathe([(0, 0), (1.5, 0), (1.72, 0.25), (1.72, 3.9), (1.45, 4.55), (0.75, 4.9), (0.5, 4.95), (0.5, 5.4), (0, 5.4)], x, y, -0.26, "dewar", verts=72)
    TOR(1.72, 0.08, x, y, 0.75, "tuyau_froid", minor=10)
    TOR(1.72, 0.08, x, y, 3.35, "tuyau_froid", minor=10)
    CY(1.74, 0.5, x, y, 1.4, "givre", verts=72, bev=0.02)
    # givre au pied et sur le tuyau, en éclats
    rng = random.Random(9)
    # conduite bleue sur le toit, reliée au réservoir et aux armoires
    z1 = Z.H + 0.72
    tube([(x, y, 5.0), (x - 0.2, y + 0.2, 5.9), (3.4, 0.2, z1 + 0.25), (-3.8, 0.2, z1 + 0.25)], 0.3, "tuyau_froid")
    for xx in (-2.5, 1.45):
        CY(0.40, 0.38, xx, 0.2, Z.H + 0.26, "alu_sombre", verts=24, bev=0.02)
        CY(0.18, 0.44, xx, 0.2, Z.H + 0.56, "alu_brosse", verts=16, bev=0.01)
    for i in range(9):
        xx = -3.4 + i * 0.85
        lathe([(0.18, 0.0), (0.0, 0.42 + rng.uniform(0, 0.26))], xx, 0.0 - 0.22, z1 + 0.03, "givre", verts=6, lisse=False,
              phase=rng.uniform(0, 1)).rotation_euler = (math.radians(180), 0, 0)
    # panache froid qui sort de la soupape
    voile = P.mat_lum("froid", (0.86, 0.97, 1.0), (0.36, 0.72, 0.96), 0.62, mode="z", z0=5.0, z1=7.2)
    tube([(x + 0.1, y, 5.1), (x + 0.5, y, 5.8), (x + 0.2, y, 6.5), (x + 0.75, y, 7.1)], 0.16, voile, rayons=(0.5, 1.2, 1.6, 0.4))


def tech_regolith_degassing():
    """Dégazage du régolithe : creuset chauffé plein de roche lunaire, foyer entre les blocs, atomes d'hélium-3 qui
    s'échappent vers le haut."""
    lathe([(2.95, 0.0), (3.0, 0.15), (3.05, 1.65), (3.35, 1.8), (3.35, 2.3), (2.65, 2.3), (2.55, 1.0), (0.0, 1.0), (0.0, 0.0)], 0, 0, 0, "acier_creuset", verts=96)
    # résistances chauffantes autour du creuset
    TOR(3.10, 0.13, 0, 0, 0.55, "foyer", minor=10)
    TOR(3.12, 0.13, 0, 0, 1.15, "foyer", minor=10)
    # lit lumineux
    fy = P.mat_lum("foyer_d", P.K.LUM["foyer"][0], P.K.LUM["foyer"][1], 1.05)
    CY(2.56, 0.04, 0, 0, 1.75, fy, verts=64, bev=0)
    rng = random.Random(8)
    pos = []
    for r, n in ((0.0, 1), (1.05, 6), (1.95, 9)):
        for i in range(n):
            a = 2 * math.pi * i / max(n, 1) + r
            pos.append((r * math.cos(a), r * math.sin(a), 0.72 - r * 0.12))
    for i, (x, y, s) in enumerate(pos):
        roche(s + rng.uniform(-0.05, 0.1), x, y, 2.15 - abs(x) * 0.02 + (0.5 if i == 0 else 0.0), "regolithe", 90 + i, ecrase=0.86, rugueux=0.2)
    # atomes qui montent : 2 protons et 1 neutron pour le plus gros, billes pour les autres
    pr = P.mat_goutte("p_", (0.85, 0.05, 0.46), (0.26, 0.006, 0.16), rough=0.14, met=0.2)
    ne = P.mat_goutte("n_", (0.70, 0.72, 0.76), (0.12, 0.13, 0.15), rough=0.14, met=0.2)
    for (cx, cy, cz, s) in ((-0.5, 0, 6.3, 0.62), (1.55, 0, 4.85, 0.46), (-1.85, 0, 4.35, 0.34), (0.55, 0, 3.8, 0.26)):
        SPH(s, cx - s * 0.56, cy, cz, pr)
        SPH(s, cx + s * 0.60, cy - s * 0.1, cz + s * 0.2, pr)
        SPH(s * 0.96, cx, cy - s * 0.5, cz - s * 0.68, ne)


def tech_quantum_computing():
    """Calcul quantique : le grand lustre de dilution, puce magenta allumée en bas, couronne de lignes de câbles."""
    zb = O.lustre(rs=(3.05, 2.6, 2.15, 1.7), pas=1.42)
    CY(0.28, 0.8, 0, 0, zb - 0.8, "or_sombre", verts=20, bev=0.01)
    B(1.7, 1.7, 0.18, 0, 0, zb - 0.98, "cuivre", bev=0.03)
    B(1.3, 1.3, 0.10, 0, 0, zb - 1.08, "saphir", bev=0.02)
    coeur = P.mat_lum("q_coeur", P.K.LUM["plasma_fort"][0], (0.60, 0.02, 0.40), 1.45)
    SPH(0.62, 0, 0, zb - 1.72, coeur)
    TOR(1.12, 0.09, 0, 0, zb - 1.72, "plasma", rot=(14, 0, 0), minor=10)
    # câbles coaxiaux, le long des étages, côté devant
    for k in range(5):
        a = math.radians(-125 + k * 18)
        r0, r1, r2 = 2.75, 2.35, 1.5
        z0 = 4.75
        pts = [(r0 * math.cos(a), r0 * math.sin(a), z0 - 0.3), (r1 * math.cos(a), r1 * math.sin(a), z0 - 1.5), (r2 * math.cos(a), r2 * math.sin(a), z0 - 3.0),
               (0.72 * math.cos(a), 0.72 * math.sin(a), zb - 0.6)]
        tube(pts, 0.05, "cuivre" if k % 2 else "alu_brosse", res=12)
