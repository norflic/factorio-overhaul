"""COTES DE LA LIGNÉE DU CENTRE par taille d'emprise (lot F5-A, 27/10). Python pur. Repère des tuiles : x vers l'est,
y vers le nord, z vers le haut, origine au centre de l'emprise (corps.repere étire y de √2 pour la vue de trois quarts du
kit, comme la foreuse)."""
import math

SQ2 = math.sqrt(2.0)


def taille(side):
    s = float(side)
    dd = s / 2.0 - 0.08                     # demi-côté du socle
    zt = 0.10 + 0.015 * s                    # dessus du socle
    h1 = 0.36 * s                            # demi-côté du 1er étage
    H1 = 0.42 + 0.07 * s                     # hauteur du 1er étage
    h2 = 0.62 * h1
    H2 = 0.78 * H1
    h3 = 0.62 * h2
    H3 = 0.72 * H2
    return dict(side=s, dd=dd, zt=zt, h=(h1, h2, h3), H=(H1, H2, H3),
                porte=dict(w=0.2 + 0.035 * s, h=0.34 + 0.04 * s),
                sat=dict(r=0.12 + 0.025 * s, retrait=0.36 + 0.02 * s),
                parapet=0.07 + 0.006 * s)


def coins_satellites(side, plan):
    """(avant, arrière) : positions (x, y) en tuiles des satellites, au milieu de la bande libre entre le premier étage
    et le bord du socle, sur les diagonales. Avant : sud-ouest puis sud-est (les mitrailleuses de l'âge, composées après
    le rendu par satellites.py, ronde F5-A2) ; arrière (emprises de 6 et plus) : projecteurs."""
    T = taille(side)
    h1, dd = T["h"][0], T["dd"]
    if plan == "rond":
        d = (h1 + dd) / 2.0 / SQ2
    elif plan == "octo":
        d = 1.188 * (h1 + dd) / 2.0 / SQ2     # distance des pans diagonaux : 1,188 × le demi-côté
    else:
        d = (h1 + dd) / 2.0
    avant = [(-d, -d), (d, -d)]
    arriere = [(d, d), (-d, d)] if side >= 6 else []
    return avant, arriere


def cote_satellite(side):
    """Côté (tuiles) de la mitrailleuse posée en satellite : 0,2 × l'emprise + 0,2 (1 t à 4×4, 1,8 t à 8×8 ; ronde F5-A2,
    essai : à 0,22 S + 0,25 les mitrailleuses débordaient du socle des 4×4)."""
    return 0.2 * side + 0.2
