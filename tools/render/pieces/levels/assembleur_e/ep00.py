"""Âge 0 : la LIGNÉE SEULE de l'assembleur (témoin du kit, variantes kS-machine, S = 3 à 6).

Sert à voir le corps commun à chaque taille, sans organe d'âge : embase carrée à tôles, dos plat, joues en caisson,
table, portique à poutre et chariot, brides N et S, trémie d'entrée, bac de sortie ; un vérin simple sous le chariot et
un engrenage sur la table.
"""
import corps
from corps import B

EPOQUE = 0
NOM = "Lignée seule"
TRIPLET = None
FOYER = dict(rgb=(1.0, 0.6, 0.2))
TRAVAIL = dict(couches=1, images=16, organe="vérin du chariot (descente et remontée)")


def socle(g, c):
    return None


def outil(g, c):
    M = g.M
    zb = c.zp + c.bp
    g.cyl(B(0, c.yt, (zb + c.zt + 0.18) / 2), "z", 0.05, zb - c.zt - 0.18, M["steel_hi"], n=12, what="tige")
    g.cyl(B(0, c.yt, c.zt + 0.14), "z", 0.11, 0.08, M["steel_dk"], n=16, style="hard", what="tete_verin")


def ouvrage(g, c):
    M = g.M
    g.cyl(B(0, c.yt, c.zt + 0.02), "z", 0.16, 0.04, M["steel"], n=20, style="hard", what="engrenage")


def piece(g, c):
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        corps.caisse(g, c, p["x"], p["yn"], p["z_sol"], 1.2 * p["r"], g.M["wood"])
