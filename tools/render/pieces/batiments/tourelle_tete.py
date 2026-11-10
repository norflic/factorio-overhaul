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


def toit(k, motif, x, y, z, s):
    """Motif de FONCTION peint sur le toit d'une tête (lot VISUELS-DISTINCTS, marques.py « toit ») : matière « lisere » (couche lueur),
    centré en (x, y) au niveau z, taille s (tuiles). chevron : V pointé vers la bouche ; barres : trois barres transverses ; cible :
    anneau et point ; croix : X."""
    m = "lisere" if "lisere" in k.M else "accent"
    e = 0.014
    if motif == "chevron":
        for sx in (-1, 1):
            k.b(m, (x + sx * s * 0.22, y + s * 0.05, z), (s * 0.55, s * 0.13, e), rz=sx * math.radians(-40.0))
    elif motif == "barres":
        for i in (-1, 0, 1):
            k.b(m, (x, y + i * s * 0.3, z), (s * 0.85, s * 0.12, e))
    elif motif == "cible":
        k.tore(m, x, y, z, s * 0.42, s * 0.06, 40, 6)
        k.cyl(m, x, y, z - e / 2, z + e / 2, s * 0.13, 16)
    elif motif == "croix":
        for a in (45.0, -45.0):
            k.b(m, (x, y, z), (s * 0.95, s * 0.13, e), rz=math.radians(a))
    else:
        raise ValueError("motif de toit inconnu : %s" % motif)


def couronne(k, zt, r):
    """Couronne d'orientation (tourne avec la tête) : collier sombre, bague argent, liseré cyan. Rend le dessus de la bague."""
    k.rev("struct", 0.0, 0.0, [(zt, r * 1.02), (zt + 0.03, r * 1.02)], 40)
    k.rev("blind2", 0.0, 0.0, [(zt + 0.03, r), (zt + 0.07, r), (zt + 0.09, r * 0.92)], 40)
    k.tore("conduit", 0.0, 0.0, zt + 0.05, r * 1.005, 0.008, 64, 6)
    return zt + 0.09
