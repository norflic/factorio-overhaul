"""Icônes des FLUIDES (s'exécute dans Blender) : gouttes et atomes brillants, comme les fluides vanilla. Chacun a un
attribut de silhouette en plus de sa couleur : givre, vapeur, flaque, noyau et orbite, deux phases et bulles."""
import math
import random

import scene_base as P
from scene_base import SPH, TOR, lathe, profil_goutte, roche, tube


def goutte(H, R, coeur, bord, x=0.0, y=0.0, z=0.0, m=1.8, met=0.55):
    return lathe(profil_goutte(H, R, m=m), x, y, z, P.mat_goutte("goutte%f" % (H + R + x + coeur[0]), coeur, bord, met=met), verts=72)


def ic_chilled_water():
    """Eau glacée : goutte cyan pâle, couronne de cristaux de givre à son pied."""
    goutte(5.0, 1.62, (0.08, 0.52, 0.90), (0.006, 0.11, 0.36), z=0.15)
    rng = random.Random(23)
    for i, (a, d, h, r) in enumerate(((200, 1.70, 1.45, 0.34), (240, 1.60, 1.05, 0.30), (290, 1.55, 1.25, 0.32), (330, 1.72, 1.60, 0.36),
                                      (20, 1.80, 1.10, 0.30), (160, 1.86, 1.00, 0.28), (262, 1.05, 0.72, 0.26))):
        x, y = d * math.cos(math.radians(a)), d * math.sin(math.radians(a))
        o = lathe([(r * 0.7, 0.0), (r, h * 0.2), (r * 0.82, h * 0.72), (0.0, h)], x, y, -0.05, "givre", verts=6, lisse=False, bev=0.012,
                  phase=rng.uniform(0, 1))
        o.rotation_euler = (rng.uniform(-0.28, 0.28), rng.uniform(-0.28, 0.28), 0)


def ic_warm_water():
    """Eau chaude : goutte corail, plus basse, et 2 volutes de vapeur de chaque côté de sa pointe d'elle."""
    goutte(4.5, 1.60, (0.95, 0.14, 0.05), (0.34, 0.008, 0.008), z=0.0, m=1.7, met=0.3)
    voile = P.mat_lum("vapeur", (0.96, 0.90, 0.84), (0.72, 0.52, 0.44), 0.78, mode="z", z0=3.2, z1=6.2)
    for (x, ph, h, z0) in ((-1.28, 0.0, 2.3, 3.05), (1.28, 3.4, 2.1, 3.05)):
        pts, ray = [], []
        n = 7
        for i in range(n):
            t = i / (n - 1)
            pts.append((x + 0.26 * math.sin(ph + t * 8.0), 0.0, z0 + t * h))
            ray.append(0.2 + 1.0 * math.sin(t * math.pi) ** 0.7)
        tube(pts, 0.13, voile, rayons=ray)


def ic_photoresist():
    """Résine photosensible : goutte ambre dense qui tombe sur sa flaque, étalée sur une tranche sombre."""
    R = 2.75
    lathe([(0, 0), (R - 0.03, 0), (R, 0.03), (R, 0.13), (R - 0.03, 0.16), (0, 0.16)], 0, 0, 0, "silicium", verts=96)
    TOR(R - 0.02, 0.05, 0, 0, 0.08, "alu_brosse")
    flaque = P.mat_goutte("flaque", (0.88, 0.27, 0.012), (0.34, 0.07, 0.006), rough=0.08, met=0.3)
    lathe([(0.0, 0.40), (0.55, 0.38), (1.15, 0.30), (1.70, 0.20), (1.92, 0.10), (1.96, 0.0), (0.0, 0.0)], 0, 0, 0.16, flaque, verts=72)
    goutte(4.0, 1.20, (0.88, 0.27, 0.012), (0.30, 0.05, 0.004), z=0.75, m=1.9, met=0.3)


def ic_helium_3():
    """Hélium-3 : noyau à 2 protons magenta et 1 neutron, orbite dorée et son électron ; billes comme les molécules vanilla."""
    prot = P.mat_goutte("proton", (0.85, 0.05, 0.46), (0.26, 0.006, 0.16), rough=0.14, met=0.2)
    neut = P.mat_goutte("neutron", (0.66, 0.68, 0.72), (0.12, 0.13, 0.15), rough=0.14, met=0.2)
    SPH(1.24, -0.72, -0.28, 0.34, prot)
    SPH(1.24, 0.82, 0.05, 0.52, prot)
    SPH(1.20, 0.05, 0.42, -0.86, neut)
    TOR(2.85, 0.10, 0, 0, 0, "or", rot=(70, 0, 28), minor=12)
    # électron sur l'orbite (rot x 70° puis z 28°)
    a = math.radians(205)
    rx = math.radians(70)
    rz = math.radians(28)
    x0, y0 = 2.85 * math.cos(a), 2.85 * math.sin(a)
    y1, z1 = y0 * math.cos(rx), y0 * math.sin(rx)
    x2, y2 = x0 * math.cos(rz) - y1 * math.sin(rz), x0 * math.sin(rz) + y1 * math.cos(rz)
    SPH(0.36, x2, y2, z1, P.mat_goutte("electron", (0.32, 0.86, 0.98), (0.03, 0.22, 0.42), rough=0.1, met=0.3))


def ic_dilution_mix():
    """Mélange hélium-3 / hélium-4 : goutte à DEUX PHASES (magenta dessus, bleu pâle dessous, comme dans un vrai
    réfrigérateur), interface lumineuse, deux bulles échappées."""
    prof = profil_goutte(5.5, 1.74, m=1.8)
    zi = 2.25
    bas = [p for p in prof if p[1] <= zi]
    haut = [p for p in prof if p[1] >= zi]
    ri = max(p[0] for p in bas if abs(p[1] - bas[-1][1]) < 1e-6)
    m_bas = P.mat_goutte("phase_bas", (0.34, 0.68, 0.98), (0.03, 0.14, 0.40), met=0.4)
    m_haut = P.mat_goutte("phase_haut", (0.74, 0.025, 0.40), (0.20, 0.003, 0.13), met=0.3)
    lathe(bas + [(0.0, bas[-1][1])], 0, 0, 0, m_bas, verts=72)
    lathe([(0.0, haut[0][1] + 0.05)] + [(r, z + 0.05) for r, z in haut], 0, 0, 0, m_haut, verts=72)
    TOR(ri + 0.005, 0.085, 0, 0, zi + 0.025, "plasma_fort", minor=10)
    SPH(0.46, 2.02, -0.2, 3.25, m_bas)
    SPH(0.34, -2.02, -0.2, 3.75, m_haut)
    SPH(0.25, 1.72, -0.2, 4.35, m_haut)
