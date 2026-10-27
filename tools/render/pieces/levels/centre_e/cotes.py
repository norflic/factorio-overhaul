"""COTES DE LA LIGNÉE DU CENTRE par taille d'emprise (lot F5-A, 27/10). Python pur. Repère des tuiles : x vers l'est,
y vers le nord, z vers le haut, origine au centre de l'emprise (corps.repere étire y de √2 pour la vue de trois quarts du
kit, comme la foreuse)."""


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
