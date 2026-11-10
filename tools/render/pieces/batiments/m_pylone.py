"""PYLÔNE HAUTE TENSION (fo-ht-pylon, electric-pole 2×2, fil de 64 tuiles) : tour en treillis à quatre pieds qui se resserre, trois
ceintures de croisillons, traverse supérieure en blindage argent avec trois isolateurs-cristaux (bleu glacier translucide) qui portent
les fils, conduit cyan qui grimpe le long d'un montant jusqu'à une balise-cœur au sommet, accents magenta. Même hauteur à l'écran que le
grand poteau vanilla (sommet à 5,4 unités : fil de cuivre à ≈ 246 px HR au-dessus du pied). Symétrie carrée : UNE direction suffit.
Rend les ANCRAGES des fils (repère Blender) : cuivre au sommet, rouge et vert aux bouts de la traverse."""
import math

import organes as O

D = O.D
H = 5.4            # sommet de la tour (unités)
HT = 4.85          # traverse


def _leg(k, p0, p1, r=0.045):
    k.axe("struct", p0, p1, r, 8)
    k.axe("blind2", p0, p1, r * 0.72, 8)


def build(S, k, M):
    a0, a1 = 0.72, 0.22                      # demi-écart des pieds au sol et au sommet (x) ; y suit D
    # semelles et pieds
    legs = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            p0 = (sx * a0, sy * a0 * D, 0.0)
            p1 = (sx * a1, sy * a1 * D, H)
            k.bz("blind", p0[0], p0[1], 0.0, 0.34, 0.34 * D, 0.08)
            k.b("struct", (p0[0], p0[1], 0.12), (0.16, 0.16, 0.1))
            _leg(k, (p0[0], p0[1], 0.1), p1)
            legs.append((p0, p1))
    # ceintures de croisillons (3 niveaux) entre pieds voisins
    def at(leg, z):
        p0, p1 = leg
        t = z / H
        return (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, z)
    pairs = [(0, 1), (1, 3), (3, 2), (2, 0)]   # ordre des pieds : (-,-), (-,+), (+,-), (+,+)
    for z0, z1 in ((0.5, 1.7), (1.9, 3.1), (3.3, 4.4)):
        for i, j in pairs:
            a, b = at(legs[i], z0), at(legs[j], z0)
            c, d = at(legs[i], z1), at(legs[j], z1)
            k.axe("struct", a, b, 0.02, 6)
            k.axe("struct", a, d, 0.016, 5)
            k.axe("struct", b, c, 0.016, 5)
        # collier argenté au sommet de la ceinture
        for i in range(4):
            k.sph("blind", at(legs[i], z1), 0.05, 10, 6)
    # plateforme et traverse supérieure
    k.caisson("blind", 0.0, 0.0, H - 0.1, 2 * a1 + 0.3, (2 * a1 + 0.3) * D, 0.12, 0.03)
    k.caisson("blind2", 0.0, 0.0, HT - 0.07, 2.4, 0.22 * D, 0.14, 0.03)
    k.b("struct", (0.0, 0.0, HT - 0.12), (2.3, 0.1 * D, 0.04))
    for sx in (-1, 1):                         # jambes de force de la traverse
        k.axe("struct", (sx * 1.05, 0.0, HT - 0.05), (sx * 0.3, 0.0, HT - 0.55), 0.022, 6)
    k.b("accent", (0.0, -0.11 * D - 0.004, HT), (2.2, 0.008, 0.03))
    # conduit cyan qui grimpe un montant (pied sud-est, côté caméra)
    leg = legs[2]
    pts = [at(leg, z) for z in (0.15, 1.2, 2.4, 3.6, H - 0.15)]
    pts = [(p[0] + 0.05, p[1] - 0.05, p[2]) for p in pts]
    k.put("conduit", __import__("geo").tube(pts, 0.02, 6))
    # isolateurs : empilements de disques argent et cristaux bleu glacier, fils d'attache ; ancrages
    anc = {}
    for nom, x, z in (("green", -1.05, HT), ("red", 1.05, HT), ("copper", 0.0, H)):
        zb = z + 0.02
        k.cyl("blind", x, 0.0, zb, zb + 0.05, 0.1, 12)
        for i in range(3):
            zz = zb + 0.06 + i * 0.11
            k.rev("cristal", x, 0.0, [(zz, 0.03), (zz + 0.02, 0.1), (zz + 0.08, 0.1), (zz + 0.1, 0.035)], 14)
        top = zb + 0.06 + 3 * 0.11
        k.cyl("canon", x, 0.0, top, top + 0.12, 0.03, 8)
        k.sph("conduit", (x, 0.0, top + 0.14), 0.04, 12, 6)
        anc[nom] = (x, 0.0, top + 0.16)
    # balise-cœur au sommet (cyan, halo) et antenne
    k.cyl("canon", 0.0, 0.0, H + 0.02, H + 0.9, 0.025, 8)
    k.sph("coeur", (0.0, 0.0, H + 0.62), 0.09, 16, 8)
    k.sph("halo", (0.0, 0.0, H + 0.62), 0.15, 16, 8)
    k.tore("anneau", 0.0, 0.0, H + 0.62, 0.2, 0.012, 32, 6)
    k.b("accent", (0.0, -0.12, H + 0.3), (0.18, 0.012, 0.05))
    return anc
