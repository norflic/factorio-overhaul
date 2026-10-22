"""Époque 0 : la LIGNÉE SEULE (témoin du kit, variantes kS-socle, kS-tete-N|E, S = 2 à 6). FICHIER GELÉ (kit).

Sert à voir le corps commun et le canon de lignée corrigé pour la pose N (corps.canon_lignee) à chaque taille, sans
aucun organe d'époque : c'est la base sur laquelle chaque époque AJOUTE son organe (règle d'or 1).
"""
import corps

EPOQUE = 0
NOM = "Lignée seule"
# orange des foyers de la lignée V3-S (industriel) ; l'époque 0 n'a pas de famille (elle n'est pas une époque du jeu)
FOYER = dict(rgb=(1.0, 0.6, 0.2))
# canons de la lignée par taille (interpolés entre les témoins n11, n21 et n29 de la première passe)
CANON_PAR_COTE = {2: dict(L=0.9, nb=4, rb=0.04, rr=0.075), 3: dict(L=1.35, nb=4, rb=0.045, rr=0.1),
                  4: dict(L=1.7, nb=6, rb=0.05, rr=0.125), 5: dict(L=2.1, nb=6, rb=0.06, rr=0.145),
                  6: dict(L=2.5, nb=6, rb=0.072, rr=0.175)}


def socle(g, c):
    """Rien de plus que la lignée (plateforme, colonne, trémie)."""
    corps.collecteur(g, c, lambda g_, pts, r: g_.hose(pts, r, g_.M["rubber"]))


def piece(g, c):
    """Dalles de caillebotis aux coins avant (emplacement de la pièce du niveau pair)."""
    P = c.T["piece"]
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (P["x"] - 0.3), sx * (P["x"] + 0.3)))
        corps.dalle(g, x0, x1, corps.Y(P["yn"] - 0.3), corps.Y(P["yn"] + 0.3))


def arme(g, c, x, sx):
    corps.canon_lignee(g, c, x, sx)


def tete(g, c):
    """Rien de plus que la lignée."""
    return None
