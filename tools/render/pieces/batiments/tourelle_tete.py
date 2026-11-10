"""TÊTES TOURNANTES des tourelles à munitions refaites (lot POLISSAGE-3, 10/11, axe 3 du Mode Démon) : outils communs.

Une tête est modelée dans le repère du MONDE (x est, y NORD, en tuiles, sans l'étirement D des emprises ; z en unités du kit), le canon
pointé vers le nord (direction 0 du moteur). batch_tetes.py la tourne de -θ autour de z (sens horaire vu de dessus : direction k = k/64
de tour à partir du nord, comme les RotatedAnimation du moteur) PUIS l'étire de D en y (objets enfants d'un vide d'échelle (1, D, 1)) :
la bouche décrit alors à l'écran exactement le cercle que le moteur parcourt pour l'origine des projectiles,
    origine = projectile_center + projectile_creation_distance × (sin θ, -cos θ),
d'où, pour une bouche modelée en (0, L, zb) : projectile_creation_distance = L et projectile_center = (0, -zb × sin 45°) (fo_calib).
"""
import math

import geo as G

SIN_T = math.sin(math.radians(45.0))


def bouche(p):
    """Paramètres d'attaque lus du modèle (tuiles) pour une bouche p = (0, L, zb) : distance et centre de création des projectiles."""
    return {"distance": round(p[1], 4), "centre": [0.0, round(-p[2] * SIN_T, 4)]}


def fut_y(k, mat, x, z, prof, segs=16):
    """Fût le long de +y (axe en (x, ., z)) : prof = [(y, rayon)]."""
    k.put(mat, G.tour(prof, segs, "y", (x, 0.0, z)))


def fut_x(k, mat, y, z, prof, segs=16):
    """Fût le long de +x (axe en (., y, z)) : prof = [(x, rayon)]."""
    k.put(mat, G.tour(prof, segs, "x", (0.0, y, z)))


def couronne(k, zt, r):
    """Couronne d'orientation (tourne avec la tête) : collier sombre, bague argent, liseré cyan. Rend le dessus de la bague."""
    k.rev("struct", 0.0, 0.0, [(zt, r * 1.02), (zt + 0.03, r * 1.02)], 40)
    k.rev("blind2", 0.0, 0.0, [(zt + 0.03, r), (zt + 0.07, r), (zt + 0.09, r * 0.92)], 40)
    k.tore("conduit", 0.0, 0.0, zt + 0.05, r * 1.005, 0.008, 64, 6)
    return zt + 0.09
