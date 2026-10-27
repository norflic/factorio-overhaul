"""Foreuse · Âge 1 · Pionnier (ère I, 3×3, niveaux 1 et 2). Lot F4-A (25/10). S'exécute DANS Blender.

Niveau 1 : la foreuse vanilla, inchangée. Niveau 2 : une CHÈVRE DE BOIS (trépied de perches liées) posée SUR la foreuse,
POULIE de fer au sommet, corde jusqu'au centre, LANTERNE à huile pendue sous la poulie (foyer de NUIT, #FFB060). La
pièce dépasse la silhouette vanilla par le haut (F42) ; une seule image pour les 4 directions (trépied rond).
"""
import math

import ages
import corps as cp

EPOQUE = 1
NOM = ages.NOMS[1]
TRIPLET = ("chèvre de bois", "poulie", "lanterne")
FOYER = ages.FOYER[1]
HABILLAGE = {}


def matieres(metal, M):
    ages.matieres(1, metal, M)
    # ronde F4-A2 (DC : « âge 1 lisible ») : bois de perche CLAIR (écorcé), qui se détache du métal sombre de la foreuse
    # vanilla ; matière propre de l'âge 1, créée APRÈS ages.matieres (aucune graine décalée : l'âge 1 n'en a pas)
    metal("bois_clair", (0.46, 0.31, 0.16), rough=0.7, met=0.0, grain=0.5, gscale=40.0, dirt=0.7, stain=0.4, wear=0.6,
          streak=0.4)


ECHELLE = 1.15      # pièce un peu agrandie (1,6 ferait sortir le trépied de la silhouette vanilla : trous enfermés)


def piece(g, c):
    M = g.M
    # ronde 2 : trépied resserré (rayon 1,22 → 0,55) et plus bas (2,15 → 1,95) : large, il enfermait le sol entre ses
    # perches et le corps vanilla (ilots : trou de 4 418 px en pose E) ; resserré, il reste dans la silhouette vanilla.
    # Ronde F4-A2 : perches épaisses en bois clair, grande poulie à rayons, sacs de sable aux pieds, lanterne plus grosse.
    za = 1.95
    R = 0.55
    for k in range(3):
        a = math.radians(90 + 120 * k + 30)
        p0 = (R * math.cos(a), R * math.sin(a), 0.62)
        p1 = (0.10 * math.cos(a), 0.10 * math.sin(a), za)
        g.tube([p0, ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2), p1], 0.075, M["bois_clair"],
               n=10, radii=[0.08, 0.07, 0.06], what="perche")
        g.cyl(p0, "z", 0.1, 0.1, M["wood2"], n=8, style="hard", what="sabot")
        for t in (0.3, 0.55, 0.8):
            q = (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, p0[2] + (p1[2] - p0[2]) * t)
            g.cyl(q, (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]), 0.085, 0.04, M["canvas"], n=8, what="ligature")
        # sacs de sable au pied de chaque perche
        for j in (-1, 1):
            b = a + j * 0.45
            g.sphere((R * 1.05 * math.cos(b), R * 1.05 * math.sin(b), 0.6), 0.11, M["canvas2"], n=10, m=6,
                     scale=(1.2, 0.8, 0.55), what="sac")
    # tête liée et grande poulie à rayons
    g.cyl((0, 0, za + 0.03), "z", 0.16, 0.14, M["canvas2"], n=10, what="liure")
    g.torus((0, 0, za - 0.16), "x", 0.19, 0.035, M["rawiron"], n=24, m=6, what="poulie")
    for k in range(6):
        t = math.tau * k / 6
        cp.poutre(g, (0, 0, za - 0.16), (0, 0.19 * math.cos(t), za - 0.16 + 0.19 * math.sin(t)), 0.025,
                  M["blackiron"], "rayon")
    g.cyl((0, 0, za - 0.16), "x", 0.05, 0.12, M["blackiron"], n=8, what="axe")
    # corde et lanterne
    g.tube([(0.0, 0.0, za - 0.35), (0.0, 0.0, 1.6), (0.0, 0.0, 1.38)], 0.02, M["canvas2"], n=6, what="corde")
    g.cyl((0, 0, 1.27), "z", 0.12, 0.22, M["emit"], n=10, style="flat", what="lanterne")
    g.cyl((0, 0, 1.385), "z", 0.12, 0.035, M["blackiron"], n=10, what="chapeau")
    g.cyl((0, 0, 1.155), "z", 0.11, 0.035, M["blackiron"], n=10, what="fond")
    for k in range(4):
        a = math.radians(45 + 90 * k)
        g.cyl((0.105 * math.cos(a), 0.105 * math.sin(a), 1.27), "z", 0.015, 0.23, M["blackiron"], n=5, what="barreau")
    # ronde F4-A3 : la nuit de l'âge 1 était presque noire : lanterne plus grosse, halo × 1,8, falots sur les sacs
    cp.halo(g, (0, -0.15, 1.2), M, 9.0)
    for k in range(3):
        a = math.radians(90 + 120 * k + 30)
        x, y = 0.55 * 1.05 * math.cos(a + 0.45), 0.55 * 1.05 * math.sin(a + 0.45)
        g.cyl((x, y, 0.70), "z", 0.04, 0.08, M["emit"], n=8, style="flat", what="falot")
        g.cyl((x, y, 0.75), "z", 0.05, 0.02, M["blackiron"], n=8, what="falot_chapeau")
        cp.halo(g, (x, y - 0.05, 0.8), M, 1.5)
