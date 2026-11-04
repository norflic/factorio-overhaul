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
    # L : jusqu'à l'organe que le tronçon rejoint (corps de la variante a) ; nord dessiné DERRIÈRE le corps, il peut être long
    "bobineuse": {"mat": "givre", "z": 0.32, "L": {"n": 0.75, "e": 0.3, "s": 0.62, "o": 0.14}, "givre": True},
    "torchere": {"mat": "car2", "z": 0.3, "L": {"n": 1.35, "e": 0.48, "s": 0.27, "o": 0.31}, "givre": False},
    "taillerie": {"mat": "bleu", "z": 0.3, "L": {"n": 0.45, "e": 0.2, "s": 0.45, "o": 0.2}, "givre": False},
}


# Gabarit du tuyau vanilla (mesuré sur hr-pipe-straight-horizontal.png, 3/11) : corps de 36 px HR de haut centré 2 px au-dessus du
# centre de la tuile, soit un rayon de 0,28 tuile ; dessin « à plat ». Le tronçon est modelé à l'axe z = R_VAN, puis décalé de DY_VAN
# vers le sud pour que sa projection tombe où le moteur dessine le tuyau vanilla (y + z = 0,044 unité, soit 2 px).
R_VAN = 0.28
DY_VAN = 0.044 - R_VAN


def raccord(S, k, bat, d):
    """Tronçon du bâtiment bat pour la direction d (n, e, s, o), au gabarit vanilla : bride et gros tuyau au bord de l'emprise (le
    tuyau vanilla voisin s'y raccorde), réduction conique, puis tuyau de la machine jusqu'à l'organe qu'il rejoint."""
    k.M = CO.matieres(S, v2=True)
    t = TRONCONS[bat]
    ux, uy = VERS[d]
    L, mat = t["L"][d], t["mat"]
    z = R_VAN
    lot = k.lot

    class _Decale:
        def __init__(self, lot):
            self.l = lot

        def put(self, m, mesh):
            v, f, u = mesh
            self.l.put(m, ([(p[0], p[1] + DY_VAN, p[2]) for p in v], f, u))

        def __getattr__(self, n):
            return getattr(self.l, n)

    k.lot = k.fixe = _Decale(lot)

    def P(s, zz=z):
        return (ux * s, Y(uy * s), zz)
    n = G.norm((ux, Y(uy), 0.0))
    k.axe("acier", P(0.47), P(0.64), R_VAN - 0.01, 24)                     # gros tuyau au gabarit vanilla
    k.collier("acier", P(0.5), n, R_VAN - 0.01, e=0.035, h=0.03)           # bride de raccord
    k.put("acier", G.oriente(G.tour([(0.0, R_VAN - 0.01), (0.12, 0.09)], 24, "z"), P(0.64), n))  # réduction
    r = 0.08
    fin = max(0.5 + L, 0.78)
    if fin > 0.8:
        k.axe(mat, P(0.7), P(fin), r, 16)
    k.collier("acier", P(fin), n, r + 0.01, e=0.025, h=0.03)
    if t["givre"]:
        for f in (0.82, 0.5 + L * 0.7):
            if f < 0.5 + L:
                k.collier("acier", P(f), n, r + 0.004, e=0.012, h=0.015)
    elif L > 0.35:
        k.vanne("acier", "rouge", P(0.5 + L * 0.7), 0.045, 0.08)
    k.bz("fonte", P(fin)[0], P(fin)[1], 0.0, 0.12, 0.12, z - r)
    k.lot = k.fixe = lot
