"""Âge 0 : la LIGNÉE SEULE du laser (témoin du kit, variantes kS-socle, kS-tete-N|E, S = 2 à 6). FICHIER GELÉ (kit).

Sert à voir le corps commun du laser à chaque taille, sans organe d'âge : affût rond à 2 ou 3 gradins, couronne de
condensateurs, pivot, liaisons radiales en gaine de caoutchouc ; tête : platine, étrier, caisson arrière, émetteur de
lignée (boîtier rond à ailettes et lentille).
"""
import corps

EPOQUE = 0
NOM = "Lignée seule"
TRIPLET = None
# orange des foyers de la lignée V3-S (comme gun_e/ep00) ; l'âge 0 n'a pas de famille (ce n'est pas un âge du jeu)
FOYER = dict(rgb=(1.0, 0.6, 0.2))
FAISCEAU = dict(rgb=(1.0, 0.25, 0.2), forme="vanilla", largeur=1.0)


def socle(g, c):
    """Rien de plus que la lignée."""
    return None


def piece(g, c):
    """Patins aux coins avant (emplacement de la pièce du niveau pair)."""
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        corps.patin(g, c, sx * p["x"], p["yn"], 1.2 * p["r"], 1.2 * p["r"])


def emetteur(g, c):
    corps.emetteur_lignee(g, c)
