"""BASTION III (fo-bastion-3, electric-turret 2×2, âge 3, mode arc en chaîne) : « la couronne d'électrodes ». Sur le socle commun,
une pile d'isolateurs-cristaux (disques bleu glacier) porte une sphère-cœur cyan ; trois électrodes en col de cygne (argent, pointes
turquoise) se courbent au-dessus d'elle et un tore lumineux l'entoure ; bobines sombres cerclées au pied. L'arc part de la sphère :
ANCRAGE « emetteur »."""
import math

import socle_tourelle as St

D = St.D


def build(S, k, M):
    z = St.socle(k, 0.86, 0.3)
    k.cyl("struct", 0.0, 0.0, z, z + 0.12, 0.3, 24)
    k.cerclages("blind", 0.0, 0.0, (z + 0.06,), 0.3, 0.02, 0.03, 24)
    # pile d'isolateurs-cristaux
    zz = z + 0.12
    for i in range(4):
        k.rev("cristal", 0.0, 0.0, [(zz, 0.08), (zz + 0.03, 0.22 - 0.015 * i), (zz + 0.12, 0.22 - 0.015 * i), (zz + 0.15, 0.08)], 16)
        zz += 0.15
    k.cyl("canon", 0.0, 0.0, zz, zz + 0.1, 0.05, 10)
    zs = zz + 0.24
    k.sph("halo", (0.0, 0.0, zs), 0.29, 20, 10)
    k.sph("coeur", (0.0, 0.0, zs), 0.21, 20, 10)
    k.tore("anneau", 0.0, 0.0, zs, 0.42, 0.024, 48, 8)
    # trois électrodes en col de cygne
    for i in range(3):
        a = -math.pi / 2 + 2 * math.pi * i / 3 + math.pi / 3
        c, s = math.cos(a), math.sin(a)
        b0 = (0.62 * c, 0.62 * s * D, z - 0.02)
        k.cyl("blind2", b0[0], b0[1], z - 0.05, z + 0.1, 0.09, 12)
        pts = [(b0[0], b0[1], z + 0.08), (0.64 * c, 0.64 * s * D, zs - 0.05), (0.52 * c, 0.52 * s * D, zs + 0.34),
               (0.3 * c, 0.3 * s * D, zs + 0.44)]
        for p, q in zip(pts[:-1], pts[1:]):
            k.axe("blind", p, q, 0.045, 10)
        k.sph("turq", pts[-1], 0.06, 12, 6)
        k.cerclages("struct", b0[0], b0[1], (z + 0.18, z + 0.3), 0.045, 0.012, 0.018, 10)
    return {"emetteur": (0.0, 0.0, zs)}
