"""SOCLE COMMUN des tourelles électriques refaites (lot POLISSAGE-2, 10/11) : plinthe octogonale blindée argent à deux gradins qui
occupe l'emprise (octogone étiré de D en Y, méthode de la cuve F469), quatre contreforts d'angle à pied sombre, conduits cyan qui
montent des contreforts vers le plateau, liseré magenta et voyants sur la face sud. Les tourelles sont des émetteurs à symétrie de
révolution : UNE direction suffit (la tête ne tourne pas à l'écran, comme la tour à arc de prototypes/arsenal_special.lua)."""
import math

import geo as G
import organes as O

D = O.D


def octo(r, rot=math.pi / 8, n=8, ky=None):
    ky = D if ky is None else ky
    return [(r * math.cos(rot + 2 * math.pi * i / n), r * math.sin(rot + 2 * math.pi * i / n) * ky) for i in range(n)]


def socle(k, R, H, voyants=True, contreforts=True):
    """Plinthe : semelle sombre, gradin bas argent, gradin haut (blind2), plateau sombre. Rend la hauteur du plateau."""
    k.poly("struct", octo(R + 0.04), 0.0, 0.06)
    k.poly("blind", octo(R), 0.06, H * 0.55, 0.96)
    k.poly("blind2", octo(R * 0.86), H * 0.55, H, 0.95)
    k.poly("struct", octo(R * 0.72), H, H + 0.04)
    # joints verticaux du gradin bas (sombres), un par face
    pts = octo(R + 0.002)
    for i in range(8):
        a, b = pts[i], pts[(i + 1) % 8]
        x, y = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
        k.put("struct", G.boite((x, y, H * 0.3), (0.025, 0.025, H * 0.42)))
    if contreforts:
        for sx in (-1, 1):
            for sy in (-1, 1):
                x, y = sx * R * 0.78, sy * R * 0.78 * D
                k.bz("struct", x, y, 0.0, 0.2, 0.2 * D, 0.1)
                k.axe("blind2", (x, y, 0.08), (x * 0.82, y * 0.82, H * 0.9), 0.06, 10)
                k.axe("conduit", (x * 1.01, y * 1.01, 0.12), (x * 0.83, y * 0.83, H * 0.86), 0.018, 6)
    ys = -R * D * 0.93
    k.b("accent", (0.0, ys - 0.004, 0.1), (R * 0.9, 0.008, 0.022))
    if voyants:
        k.voyant("turq", -R * 0.32, ys, H * 0.32, 0.022)
        k.voyant("accent", R * 0.32, ys, H * 0.32, 0.022)
    return H + 0.04
