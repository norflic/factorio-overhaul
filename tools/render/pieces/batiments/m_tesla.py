"""TOUR À ARC (fo-tesla-turret, electric-turret 2×2) : une vraie bobine Tesla dans la direction des titans. Socle commun, trois
condensateurs-tambours argent autour du pied, bobine primaire (spires cyan sur fût sombre), colonne secondaire à enroulement serré
(cerclages acier), tore de tête argent à liseré lumineux et pointe-cœur cyan. L'arc part du tore : ANCRAGE « emetteur »."""
import math

import socle_tourelle as St

D = St.D


def build(S, k, M):
    z = St.socle(k, 0.86, 0.28, contreforts=False)
    # condensateurs-tambours
    for i in range(3):
        a = -math.pi / 2 + 2 * math.pi * i / 3 + math.pi / 3
        x, y = 0.55 * math.cos(a), 0.55 * math.sin(a) * D
        k.cuve("blind", x, y, z, z + 0.5, 0.16, 0.3, 20)
        k.cerclages("struct", x, y, (z + 0.12, z + 0.34), 0.16, 0.018, 0.022, 20)
        k.sph("turq", (x, y, z + 0.55), 0.04, 10, 5)
        k.axe("conduit", (x * 0.8, y * 0.8, z + 0.36), (0.12 * math.cos(a), 0.12 * math.sin(a), z + 0.3), 0.014, 6)
    # bobine primaire
    k.cyl("struct", 0.0, 0.0, z, z + 0.34, 0.24, 24)
    k.cerclages("conduit", 0.0, 0.0, (z + 0.08, z + 0.15, z + 0.22, z + 0.29), 0.24, 0.016, 0.012, 24)
    # colonne secondaire
    z1 = z + 1.5
    k.cyl("struct", 0.0, 0.0, z + 0.34, z1, 0.13, 18)
    k.cerclages("canon", 0.0, 0.0, [z + 0.4 + 0.06 * i for i in range(18)], 0.13, 0.014, 0.017, 18)
    k.cerclages("blind2", 0.0, 0.0, (z + 0.36, z1 - 0.02), 0.13, 0.03, 0.035, 18)
    # tore de tête
    k.tore("blind", 0.0, 0.0, z1 + 0.08, 0.32, 0.11, 48, 14)
    k.tore("anneau", 0.0, 0.0, z1 + 0.08, 0.43, 0.018, 48, 6)
    k.cyl("canon", 0.0, 0.0, z1, z1 + 0.24, 0.05, 10)
    k.sph("halo", (0.0, 0.0, z1 + 0.28), 0.1, 14, 7)
    k.sph("coeur", (0.0, 0.0, z1 + 0.28), 0.065, 12, 6)
    k.b("accent", (0.0, -0.11, z + 0.27), (0.12, 0.01, 0.03))
    return {"emetteur": (0.0, 0.0, z1 + 0.2)}
