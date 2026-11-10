"""Icônes des MÉTAUX (s'exécute dans Blender, lot ICONES-DISTINCTES). Chaque fonction modèle un objet d'environ 5,5 unités
de large (règle d'échelle de calcul/scene_base : 1 unité = 11 px à 64 px). Cinq silhouettes DIFFÉRENTES, là où le jeu
montrait cinq copies teintées de la plaque d'acier vanilla : pile feuilletée, lingot moulé (fer, cuivre), barreau carré
fretté, plaques hexagonales."""
import math

import scene_base as P
from scene_base import B, CY, lathe


def _tronc(nom, bx, by, tx, ty, h, m, bev=0.07):
    """Tronc de pyramide rectangulaire (lingot moulé) : base bx × by, sommet tx × ty, hauteur h ; base à z = 0."""
    vs = [(-bx / 2, -by / 2, 0), (bx / 2, -by / 2, 0), (bx / 2, by / 2, 0), (-bx / 2, by / 2, 0),
          (-tx / 2, -ty / 2, h), (tx / 2, -ty / 2, h), (tx / 2, ty / 2, h), (-tx / 2, ty / 2, h)]
    fs = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    o = P._maille(nom, vs, fs, m, lisse=False)
    P.S.bevel(o, bev, segments=3)
    return o


def ic_tole_magnetique():
    """Pile de tôles fines décalées (feuilleté) ; entre chaque tôle, un liseré d'induction cyan sur les deux chants vus."""
    n, ep, jeu = 4, 0.30, 0.13
    lx, ly = 4.9, 2.9
    for i in range(n):
        dx, dy = 0.14 * (i - n / 2), -0.10 * (i - n / 2)
        z = i * (ep + jeu)
        B(lx, ly, ep, dx, dy, z, "mx_tole", bev=0.02)
        if i < n - 1:
            zl = z + ep
            B(lx - 0.10, 0.10, jeu, dx + 0.02, dy - ly / 2 + 0.03, zl, "mx_induction", bev=0.0)
            B(0.10, ly - 0.10, jeu, dx - lx / 2 + 0.03, dy + 0.02, zl, "mx_induction", bev=0.0)
    ztop = n * (ep + jeu) - jeu
    for sx in (-1, 1):   # deux boulons de serrage du paquet de tôles
        CY(0.32, 0.16, sx * 1.75 + 0.14 * (n / 2 - 1), -0.10 * (n / 2 - 1), ztop, "mx_vis", verts=6, bev=0.02)
        CY(0.17, 0.20, sx * 1.75 + 0.14 * (n / 2 - 1), -0.10 * (n / 2 - 1), ztop, "mx_isolant", verts=24, bev=0.01)


def _billette(metal, marque):
    """Lingot industriel moulé : tronc de pyramide aux arêtes adoucies, cartouche frappé sur le dessus, deux rainures de
    préhension sur les flancs."""
    h = 1.30
    _tronc("lingot", 4.9, 2.35, 4.25, 1.72, h, metal)
    B(2.1, 0.86, 0.05, 0.0, 0.0, h - 0.02, marque, bev=0.02)
    B(1.5, 0.18, 0.06, 0.0, 0.0, h + 0.02, metal, bev=0.02)
    for sx in (-1, 1):
        B(0.10, 2.0, 0.18, sx * 1.55, 0.0, 0.45, marque, bev=0.01)


def ic_billette_fer():
    _billette("mx_fer", "mx_fer_marque")


def ic_billette_cuivre():
    _billette("mx_cuivre", "mx_cuivre_marque")


def ic_billette_tungstene():
    """Barreau carré, dense et sombre, aux bouts chanfreinés, tenu par deux frettes : lourd, jamais une plaque."""
    s = 1.75
    B(5.1, s, s, 0.0, 0.0, 0.0, "mx_tungstene", bev=0.16)
    for sx in (-1, 1):
        B(0.34, s + 0.12, s + 0.12, sx * 1.45, 0.0, -0.06, "mx_tungstene_frette", bev=0.05)
    B(1.2, 0.5, 0.05, 0.0, 0.0, s - 0.02, "mx_tungstene_frette", bev=0.02)


def ic_plaques_titane():
    """Deux plaques HEXAGONALES biseautées, polies miroir, la seconde décalée sous la première."""
    prof = [(0.0, 0.0), (2.55, 0.0), (2.55, 0.20), (2.28, 0.40), (0.0, 0.40)]
    lathe(prof, 0.55, 0.45, 0.0, "mx_titane_bord", verts=6, lisse=False, bev=0.03, phase=math.radians(12))
    lathe(prof, -0.25, -0.20, 0.42, "mx_titane", verts=6, lisse=False, bev=0.03, phase=math.radians(30))
