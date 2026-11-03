"""ÉLÉMENTS communs du kit da_energie (lot DA-ENERGIE) : pièces qui reviennent d'un bâtiment à l'autre (trèfle de
radioactivité, cadre à chevrons, pompe verticale, croûte de soufre, matières propres à la famille). Repère des organes
(organes.py) : 1 unité = 1 tuile en X, une tuile vaut D = 1,4142 unités en Y, +Y nord, +Z haut.
"""
import math

import geo as G
import organes as O
import palettes as P

D = O.D
TAU = 2.0 * math.pi


def ty(n):
    """Tuiles vers le nord -> unités Blender en Y."""
    return n * D


def matieres(S, k, ere="hitech"):
    """Palette du kit calcul_o (cohérence avec la chaîne du calcul) + matières de la famille."""
    M = k.M = P.matieres(S, ere)
    sf = P.MT.surface
    cr = (0.008, 0.0065, 0.004)
    M["plomb"] = sf("c_plomb", (0.075, 0.08, 0.095), rough=0.5, met=0.55, tole=(0.5, 0.36), joint=0.55, var=0.08, coulures=0.4,
                    rouille=(0.1, 0.11, 0.13), usure=0.7, nu=(0.42, 0.44, 0.48), crasse=0.85, crasse_col=cr, grain=0.1, graine=41)
    M["soufre"] = sf("c_soufre", (0.62, 0.48, 0.05), rough=0.9, met=0.0, usure=0.0, crasse=0.8, crasse_col=(0.2, 0.13, 0.01),
                     relief=0.6, grain=0.35, graine=42)
    M["cendre"] = sf("c_cendre", (0.07, 0.065, 0.06), rough=0.95, met=0.0, usure=0.0, crasse=0.7, crasse_col=cr, grain=0.3, graine=43)
    M["terre"] = sf("c_terre", (0.2, 0.13, 0.07), rough=0.95, met=0.0, usure=0.0, crasse=0.6, crasse_col=cr, grain=0.3, relief=0.6, graine=44)
    M["alu"] = sf("c_alu", (0.42, 0.43, 0.44), rough=0.3, met=0.9, tole=(0.45, 9.0), joint=0.75, var=0.05, usure=0.2,
                  nu=(0.7, 0.71, 0.72), crasse=0.6, crasse_col=(0.05, 0.045, 0.04), coulures=0.3, rouille=(0.2, 0.18, 0.12), grain=0.04, graine=45)
    M["grille"] = sf("c_grille", (0.06, 0.06, 0.06), rough=0.6, met=0.6, bandes=(0.05, (0.01, 0.01, 0.01), 0.5), usure=0.5,
                     nu=(0.4, 0.4, 0.4), crasse=0.6, crasse_col=cr, graine=46)
    return M


# ------------------------------------------------------------------------------------------------ faces sud
def pose_xz(mesh, cx, yface, cz):
    """Maille modelée dans le plan (u, v) avec une épaisseur w (z) -> posée sur une face sud : x = cx + u, z = cz + v,
    y = yface - w (vers la caméra)."""
    v, f, u = mesh
    return [(cx + p[0], yface - p[2], cz + p[1]) for p in v], f, u


def disque_face(k, mat, cx, yface, cz, r, e=0.012, segs=24):
    k.axe(mat, (cx, yface + 0.002, cz), (cx, yface - e, cz), r, segs)


def trefle(k, cx, yface, cz, R):
    """Trèfle de radioactivité sur une face sud : disque jaune, 3 pales noires, anneau jaune, point noir."""
    disque_face(k, "jaune", cx, yface, cz, R, 0.01, 28)
    for i in range(3):
        a0 = math.radians(90 + 120 * i - 30)
        pts = [(0.0, 0.0)] + [(R * 0.86 * math.cos(a0 + math.radians(60) * j / 6.0), R * 0.86 * math.sin(a0 + math.radians(60) * j / 6.0))
                              for j in range(7)]
        k.put("noir", pose_xz(G.prisme(pts, 0.0, 0.006), cx, yface - 0.01, cz))
    disque_face(k, "jaune", cx, yface - 0.016, cz, R * 0.3, 0.004, 20)
    disque_face(k, "noir", cx, yface - 0.02, cz, R * 0.17, 0.004, 16)


def cadre_chevrons(k, cx, yface, cz, l, h, b=0.07):
    """Cadre à chevrons jaune et noir autour d'une ouverture (face sud) ; cz = bas de l'ouverture."""
    k.b("chevron", (cx, yface - 0.008, cz + h + b / 2.0), (l + 2 * b, 0.018, b))
    for sg in (-1, 1):
        k.b("chevron", (cx + sg * (l / 2.0 + b / 2.0), yface - 0.008, cz + h / 2.0), (b, 0.018, h))


# ------------------------------------------------------------------------------------------------ organes
def pompe_v(k, x, y, z0, r=0.16, h=0.7, corps="car2", moteur="car", ailettes="noir"):
    """Pompe verticale : volute (bol) à brides, lanterne, moteur à ailettes debout, capot de ventilateur."""
    k.cuve(corps, x, y, z0, z0 + h * 0.32, r * 1.25, 0.25, 24)
    k.cerclages("acier", x, y, (z0 + h * 0.06, z0 + h * 0.26), r * 1.25, 0.018, 0.02, 24)
    k.cyl("acier", x, y, z0 + h * 0.32, z0 + h * 0.45, r * 0.55, 16)
    k.cyl(moteur, x, y, z0 + h * 0.45, z0 + h * 0.92, r * 0.9, 24)
    n = 6
    for i in range(n):
        z = z0 + h * 0.48 + (h * 0.4) * i / (n - 1.0)
        k.rev(ailettes, x, y, [(z - 0.008, r * 0.9), (z - 0.008, r * 1.02), (z + 0.008, r * 1.02), (z + 0.008, r * 0.9)], 24, cap=False)
    k.rev(moteur, x, y, [(z0 + h * 0.92, r * 0.92), (z0 + h, r * 0.7), (z0 + h, 0.0)], 24)
    k.voyant_h("voyant_v", x + r * 0.3, y - r * 0.3, z0 + h, 0.016)


def croute(k, mat, x, y, rx, ry, h, seed, bosses=0.4):
    """Croûte (soufre, cendre) posée au sol, contour lisse."""
    k.put(mat, G.butte_polaire((x, y, 0.0), rx, ry, h, G.Rnd(seed), nr=7, na=28, bosses=bosses, bord=0.22, expo=1.2))


def roue_xz(k, mat, cx, cy, cz, R, r=0.03, rayons=8, moyeu="acier", ph=0.0):
    """Roue dans le plan vertical X-Z (face à la caméra) : jante, gorge, rayons, moyeu (molette de chevalement)."""
    n = 40
    for rr in (R, R * 0.9):
        pts = [(cx + rr * math.cos(TAU * i / n), cy, cz + rr * math.sin(TAU * i / n)) for i in range(n + 1)]
        k.put(mat, G.tube(pts, r if rr == R else r * 0.7, 6, False, False))
    for i in range(rayons):
        a = TAU * (i + ph) / rayons
        k.axe(mat, (cx, cy, cz), (cx + R * 0.9 * math.cos(a), cy, cz + R * 0.9 * math.sin(a)), r * 0.55, 5)
    k.axe(moyeu, (cx, cy - 0.06, cz), (cx, cy + 0.06, cz), R * 0.14, 12)


def fenetres(k, mat, x0, x1, yface, z, h, n, cadre="acier"):
    """Rangée de fenêtres éclairées sur une face sud."""
    w = (x1 - x0) / n
    for i in range(n):
        x = x0 + w * (i + 0.5)
        k.b(cadre, (x, yface - 0.004, z + h / 2.0), (w * 0.72, 0.012, h + 0.03))
        k.b(mat, (x, yface - 0.012, z + h / 2.0), (w * 0.6, 0.008, h))


def lueurs(S, M):
    """Lueurs de la famille (dégradé et croûte : jamais un aplat, palettes.lueur)."""
    M["fenetre"] = P.lueur(S, "c_fenetre", (1.0, 0.72, 0.32), 3.2, 0.55, part=0.35, echelle=16.0)
    M["sel"] = P.lueur(S, "c_sel", (1.0, 0.42, 0.06), 5.0, 0.6, part=0.5, echelle=10.0)
    M["forage"] = P.lueur(S, "c_forage", (1.0, 0.3, 0.04), 5.5, 0.5, part=0.7, echelle=7.0)
    M["chaleur"] = P.lueur(S, "c_chaleur", (0.95, 0.22, 0.04), 2.2, 0.5, part=0.5, echelle=12.0)
    M["cristal"] = P.lueur(S, "c_cristal", (0.32, 0.95, 1.0), 4.0, 0.65, part=0.45, echelle=6.0)
    M["cristal_p"] = P.lueur(S, "c_cristal_p", (0.25, 0.8, 1.0), 1.6, 0.6, part=0.5, echelle=9.0)
    return M


def bipyramide(k, mat, x, y, z0, z1, r, segs=6, pointe=0.3, rx=0.0, ry=0.0):
    """Cristal facetté (prisme hexagonal à pointes), axe incliné de rx, ry autour de son pied."""
    h = z1 - z0
    prof = [(0.0, 0.0), (h * pointe, r), (h * (1 - pointe), r * 0.92), (h, 0.0)]
    v, f, u = G.tour(prof, segs, "z")
    out = []
    for p in v:
        q = G.rot_x(p, rx)
        q = G.rot_y(q, ry)
        out.append((q[0] + x, q[1] + y, q[2] + z0))
    k.put(mat, (out, f, u))


def caillebotis(k, x, y, z, sx, sy, pas=0.06, mat="grille", fond="noir"):
    """Caillebotis : barres parallèles à X sur un fond (ou sans fond : la lueur passe)."""
    if fond:
        k.b(fond, (x, y, z - 0.012), (sx, sy, 0.01))
    n = max(2, int(sy / pas))
    for i in range(n):
        yy = y - sy / 2.0 + sy * (i + 0.5) / n
        k.b(mat, (x, yy, z), (sx, pas * 0.38, 0.022))
    for sg in (-1, 1):
        k.b(mat, (x + sg * sx / 2.0, y, z), (0.03, sy, 0.03))
