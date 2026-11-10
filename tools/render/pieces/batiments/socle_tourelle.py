"""SOCLE COMMUN des tourelles électriques refaites (lot POLISSAGE-2, 10/11) : plinthe octogonale blindée argent à deux gradins qui
occupe l'emprise (octogone étiré de D en Y, méthode de la cuve F469), quatre contreforts d'angle à pied sombre, conduits cyan qui
montent des contreforts vers le plateau, liseré magenta et voyants sur la face sud. Les tourelles sont des émetteurs à symétrie de
révolution : UNE direction suffit (la tête ne tourne pas à l'écran, comme la tour à arc de prototypes/arsenal_special.lua).
Lot VISUELS-DISTINCTS (10/11) : les tourelles à MUNITIONS passent une FORME (marques.py) : « carre » (carré à pans coupés, Bastion I),
« hexa » (hexagone à six contreforts, lourde), « rond » (plinthe ronde sur deux rails, canon), « etoile » (moyeu rond et quatre bras
à vérins et patins, mortier), et un LISERÉ de leur couleur de fonction (matière « lisere ») sur le gradin. La forme « octo » (défaut)
garde à l'identique le socle des tourelles électriques."""
import math

import geo as G
import organes as O

D = O.D


def octo(r, rot=math.pi / 8, n=8, ky=None):
    ky = D if ky is None else ky
    return [(r * math.cos(rot + 2 * math.pi * i / n), r * math.sin(rot + 2 * math.pi * i / n) * ky) for i in range(n)]


def contour(forme, r):
    """Contour d'une plinthe de forme `forme` (rayon r, étiré de D en y), sens trigonométrique."""
    if forme == "octo":
        return octo(r)
    if forme == "carre":      # carré à pans coupés : côtés longs, petits pans aux angles (parent de l'octogone)
        c, a = r * 0.92, r * 0.92 * 0.42
        return [(x, y * D) for x, y in ((c, -c + a), (c, c - a), (c - a, c), (-c + a, c), (-c, c - a), (-c, -c + a), (-c + a, -c), (c - a, -c))]
    if forme == "hexa":       # hexagone à plat en haut et en bas
        return octo(r, rot=0.0, n=6)
    if forme == "rond":
        return octo(r * 0.98, rot=0.0, n=40)
    if forme == "etoile":     # moyeu rond (les bras sont posés à part)
        return octo(r * 0.62, rot=0.0, n=32)
    raise ValueError("forme de socle inconnue : %s" % forme)


def socle(k, R, H, voyants=True, contreforts=True, forme="octo"):
    """Plinthe : semelle sombre, gradin bas argent, gradin haut (blind2), plateau sombre. Rend la hauteur du plateau. `forme` autre
    que « octo » (tourelles à munitions, marques.py) : contour propre, appuis propres (contreforts, rails ou bras) et liseré de
    fonction (matière « lisere ») sur le gradin."""
    if forme != "octo":
        return socle_marque(k, R, H, forme)
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


def socle_marque(k, R, H, forme):
    """Socle d'une tourelle à munitions marquée : mêmes gradins que l'octogone, contour et appuis de la forme, liseré de fonction."""
    lis = "lisere" if "lisere" in k.M else "turq"
    if forme == "etoile":
        # quatre bras en X jusqu'aux angles de l'emprise : poutre argent, vérin sombre, patin, voyant de fonction au bout
        for sx in (-1, 1):
            for sy in (-1, 1):
                x1, y1 = sx * R * 1.0, sy * R * 1.0 * D
                x0, y0 = sx * R * 0.4, sy * R * 0.4 * D
                k.axe("blind", (x0, y0, H * 0.35), (x1 * 0.9, y1 * 0.9, H * 0.2), 0.11, 8)
                k.axe("struct", (x1 * 0.9, y1 * 0.9, H * 0.22), (x1 * 0.9, y1 * 0.9, 0.0), 0.07, 10)
                k.bz("struct", x1 * 0.9, y1 * 0.9, 0.0, 0.3, 0.3 * D, 0.05)
                k.axe(lis, (x0 * 1.15, y0 * 1.15, H * 0.36 + 0.1), (x1 * 0.86, y1 * 0.86, H * 0.21 + 0.1), 0.028, 6)
                k.sph(lis, (x1 * 0.9, y1 * 0.9, H * 0.3), 0.06, 10, 5)
    pts = contour(forme, R + 0.04)
    k.poly("struct", pts, 0.0, 0.06)
    k.poly("blind", contour(forme, R), 0.06, H * 0.55, 0.96)
    # liseré de fonction : bande sur le gradin bas, vue de haut entre le gradin haut et le bord
    k.poly(lis, contour(forme, R * 0.95), H * 0.55, H * 0.55 + 0.014)
    k.poly("blind2", contour(forme, R * 0.84), H * 0.55, H, 0.95)
    k.poly("struct", contour(forme, R * 0.70), H, H + 0.04)
    if forme == "hexa":
        # six contreforts massifs aux sommets, conduit de fonction au dos
        for x, y in octo(R * 0.98, rot=0.0, n=6):
            k.axe("blind2", (x, y, 0.06), (x * 0.8, y * 0.8, H * 0.92), 0.08, 8)
            k.axe(lis, (x * 1.02, y * 1.02, 0.1), (x * 0.82, y * 0.82, H * 0.88), 0.02, 6)
    elif forme == "carre":
        # bornes d'angle sur les pans (parenté avec les contreforts des Bastion II à IV)
        c = R * 0.92 * 0.79
        for sx in (-1, 1):
            for sy in (-1, 1):
                x, y = sx * c, sy * c * D
                k.bz("struct", x, y, 0.0, 0.18, 0.18 * D, 0.1)
                k.axe("blind2", (x, y, 0.08), (x * 0.86, y * 0.86, H * 0.9), 0.055, 4)
                k.axe("conduit", (x * 1.01, y * 1.01, 0.12), (x * 0.87, y * 0.87, H * 0.86), 0.016, 6)
    elif forme == "rond":
        # deux rails est-ouest qui débordent de la plinthe, traverses sombres, filet de fonction sur chaque rail
        for sy in (-1, 1):
            y = sy * R * 0.62 * D
            k.bz("struct", 0.0, y, 0.0, R * 2.1, 0.16, 0.08)
            k.bz("canon", 0.0, y, 0.08, R * 2.06, 0.07, 0.05)
            k.b(lis, (0.0, y, 0.135), (R * 2.0, 0.025, 0.012))
        for i in range(-3, 4):
            k.bz("struct", i * R * 0.3, 0.0, 0.0, 0.07, R * 1.5 * D, 0.04)
    ys = -R * D * 0.93 if forme != "etoile" else -R * 0.62 * D * 0.98
    k.b(lis, (0.0, ys - 0.004, 0.1), ((R if forme != "etoile" else R * 0.62) * 0.9, 0.008, 0.026))
    k.voyant(lis, -R * 0.3, ys, H * 0.32, 0.024)
    k.voyant(lis, R * 0.3, ys, H * 0.32, 0.024)
    return H + 0.04
