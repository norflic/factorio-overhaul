"""Four · TÉMOIN DU KIT (lignée seule, variantes kS-…, S = 2 à 6). Lot F2-A (25/10). S'exécute DANS Blender.
Chambre : caisson riveté de la lignée (olive et ocre) ; fumée : cheminée ronde rivetée ; pièce : deux bacs de minerai.
"""
import ages
import corps
from repere import Y

EPOQUE = 0
NOM = ages.NOMS[0]
FOYER = dict(rgb=(1.0, 0.45, 0.12))
HABILLAGE = {}


def matieres(metal, M):
    pass


def chambre(g, c):
    T = c.T
    M = g.M
    zs = T["sole_h"]
    zt = 0.82 * T["H"]
    with corps.habille(g, c):
        corps.boite(g, -T["xa"], T["xa"], T["y_av"], T["y_ar"], zs, zt, [M["olive"], M["olive"], M["ochre"]],
                    ins=(0.04, 0.04, 0.04), panel=0.36, faces="ts")


def fumee(g, c):
    T = c.T
    M = g.M
    f = T["fumee"]
    z0 = 0.82 * T["H"]
    import cotes
    z1 = min(T["zmax"] - 0.15, cotes.z_plafond(T, f["yn"], f["r"] * 0.71 + 0.05))
    y = Y(f["yn"])
    g.cyl((f["x"], y, (z0 + z1) / 2), "z", f["r"], z1 - z0, M["steel_dk"], n=24, what="cheminee")
    for k in range(3):
        z = z0 + (z1 - z0) * (k + 0.5) / 3
        g.tube_shell((f["x"], y, z), "z", f["r"] + 0.02, f["r"] - 0.01, 0.04, M["steel"], n=24, what="bague")
    corps.bouche_fumee(g, c, f["x"], f["yn"], z1, f["r"])


def piece(g, c):
    for nom in ("coin_SO", "coin_SE"):
        corps.bac(g, c, nom)
