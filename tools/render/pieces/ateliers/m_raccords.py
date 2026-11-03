"""RACCORDS DE FLUIDE des bâtiments d'atelier (lot DA-ATELIERS, phase 3) : un tronçon par direction, rendu à part et branché en
`pipe_picture` (Sprite4Way, comme l'assembleur 2 vanilla, data/base/prototypes/entity/assemblerpipes.lua). La vue du corps est
unique ; quand le joueur tourne la machine, le moteur déplace la connexion et dessine le tronçon de la direction (le nord
derrière le corps : `secondary_draw_orders = { north = -1 }`).

Repère : ORIGINE = point de connexion du prototype (centre de la tuile voisine, hors emprise), comme l'ancre d'un pipe_picture.
Le bord de l'emprise est à 0,5 tuile de l'origine, côté machine ; le tronçon part de ce bord (bride qui reçoit le tuyau vanilla)
et entre dans l'emprise de L tuiles jusqu'à un collier contre l'organe de la machine.

Positions de connexion (prototypes/crafts.lua, fluid_box, direction nord ; le moteur les tourne avec la machine) :
2×2, dx = −0,5 : N (−0,5 ; −1,5), E (1,5 ; −0,5), S (0,5 ; 1,5), O (−1,5 ; 0,5) ; 3×3, dx = 0 : N (0 ; −2), E (2 ; 0), S (0 ; 2), O (−2 ; 0).
"""
import math

import communs as CO
import geo as G

Y = CO.Y

# direction : vecteur unitaire (tuiles, nord +) de l'origine vers la machine
VERS = {"n": (0.0, -1.0), "e": (-1.0, 0.0), "s": (0.0, 1.0), "o": (1.0, 0.0)}
# longueur du tronçon dans l'emprise (tuiles), hauteur de l'axe (unités), matière, par bâtiment et direction
TRONCONS = {
    "bobineuse": {"mat": "givre", "z": 0.32, "L": {"n": 0.55, "e": 0.45, "s": 0.35, "o": 0.45}, "givre": True},
    "torchere": {"mat": "car2", "z": 0.3, "L": {"n": 0.6, "e": 0.5, "s": 0.35, "o": 0.5}, "givre": False},
    "taillerie": {"mat": "bleu", "z": 0.3, "L": {"n": 0.45, "e": 0.55, "s": 0.4, "o": 0.55}, "givre": False},
}


def raccord(S, k, bat, d):
    """Tronçon du bâtiment bat pour la direction d (n, e, s, o) : bride au bord, tuyau, collier, petite vanne sur le flanc."""
    k.M = CO.matieres(S)
    t = TRONCONS[bat]
    ux, uy = VERS[d]
    z, L, mat = t["z"], t["L"][d], t["mat"]
    a = (ux * 0.5, Y(uy * 0.5), z)                    # bord de l'emprise
    b = (ux * (0.5 + L), Y(uy * (0.5 + L)), z)        # collier contre la machine
    r = 0.075 if t["givre"] else 0.07
    k.axe(mat, (ux * 0.47, Y(uy * 0.47), z), b, r, 16)
    n = G.norm((b[0] - a[0], b[1] - a[1], 0.0))
    k.collier("acier", a, n, r + 0.012, e=0.03, h=0.035)
    k.collier("acier", b, n, r + 0.008, e=0.025, h=0.03)
    m = (a[0] + (b[0] - a[0]) * 0.5, a[1] + (b[1] - a[1]) * 0.5, z)
    if t["givre"]:
        for f in (0.3, 0.7):
            k.collier("acier", (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, z), n, r + 0.004, e=0.012, h=0.015)
    else:
        k.vanne("acier", "rouge", m, 0.04, 0.08)
    # support au sol sous le collier
    k.bz("fonte", b[0], b[1], 0.0, 0.1, 0.1, z - r)
