"""GARNITURE DE LA LIGNÉE de l'assembleur (lot F3-A, ronde 4, 25/10). S'exécute DANS Blender.

Après la ronde 3 (bâti haut) : à côté de la mitrailleuse du même âge, l'assembleur garde de GRANDES SURFACES NUES (dessus
des joues, face sud du bâti) : la mitrailleuse est dense de petites pièces, l'assembleur non. La garniture pose, dans la
zone habillée de l'âge (matières de son acier, de ses rivets, de ses capots), des petites pièces de taille CONSTANTE
(règle des kits : une grande machine en porte plus, jamais de plus grosses) :
  « bati »  : face sud du bâti : collecteur horizontal à brides, raidisseurs entre les portes, plaques de marquage ;
  « joues » : dessus des joues, devant le montant du portique : trappes de visite, grilles d'aération, boîtes à bornes ;
              face sud des joues : grille et rangée de rivets.
Un âge choisit ses zones par GARNIR = ("bati", "joues") (défaut) ; () : aucune. Le dessus du dos n'est jamais garni (les
âges y posent leurs grands organes).
"""
import math

from mathutils import Vector

import parts as PT
from habillage import habille
from kit import SQ2

V = Vector


def _B(x, yn, z=0.0):
    return V((x, yn * SQ2, z))


def bati(g, c):
    M = g.M
    xb, h, ze, zs = c.xb, c.h, c.ze, c.zs
    y0 = -h + 0.02
    zc = ze + (zs - ze) * 0.82
    r = 0.035 + 0.004 * c.side
    # collecteur horizontal à brides le long du haut de la face (interrompu au milieu : bride du port S plus bas)
    for sx in (-1, 1):
        xa, xz = sx * 0.3, sx * (xb - 0.08)
        xa, xz = min(xa, xz), max(xa, xz)
        g.cyl(_B((xa + xz) / 2, y0 - 0.05, zc), "x", r, xz - xa, M["steel_dk"], n=12, what="collecteur")
        n = max(2, int((xz - xa) / 0.45))
        for k in range(n + 1):
            x = xa + (xz - xa) * k / n
            g.cyl(_B(x, y0 - 0.05, zc), "x", r * 1.5, 0.035, M["steel"], n=12, style="hard", what="bride")
            g.box(_B(x, y0 - 0.02, zc - r - 0.03), (0.03, 0.04, 0.06), M["steel_dk"], "hard", what="patte")
    # raidisseurs verticaux et rivets en rangée basse
    nr = max(4, int(2 * xb / 0.4))
    for k in range(nr + 1):
        x = -xb + 0.04 + (2 * xb - 0.08) * k / nr
        wd = min(0.5, xb * 0.5)      # portes de visite du bâti (corps.plateau) : pas de raidisseur dessus
        if abs(x) < 0.25 or abs(abs(x) - xb * 0.55) < wd / 2 + 0.03:
            continue
        g.box(_B(x, y0 - 0.015, (ze + zs) / 2), (0.03, 0.03, (zs - ze) * 0.9), M["steel_dk"], "hard", what="raidisseur")
    for k in range(int(2 * xb / 0.12)):
        x = -xb + 0.06 + 0.12 * k
        g.dome(_B(x, y0 - 0.012, ze + 0.05), (0, -1, 0), 0.014, M["rivet"])


def joues(g, c):
    M = g.M
    ytp = c.yt - c.wm * 0.8          # devant le montant du portique
    zf0 = c.zs + 0.1 * (c.Hj - c.zs)

    def zj_a(yn):
        if c.f_joues != "pente":
            return c.z_joue
        return zf0 + (c.Hj - zf0) * (yn - c.yf) / (c.yb - c.yf)
    for sx in (-1, 1):
        xc = sx * (c.xb + c.wj / 2)
        y0, y1 = c.yf + 0.12, ytp - 0.08
        if y1 - y0 < 0.25:
            continue
        L = y1 - y0
        # trappe de visite, grille, boîte à bornes, alignées du sud au nord
        PT.hatch(g, tuple(_B(xc - sx * c.wj * 0.15, y0 + L * 0.22, zj_a(y0 + L * 0.22))), min(0.12, c.wj * 0.22))
        w = min(0.32, c.wj * 0.55)
        za, zb = zj_a(y0 + L * 0.5) + 0.012, zj_a(y0 + L * 0.72) + 0.012
        q = [_B(xc - w / 2, y0 + L * 0.5, za), _B(xc + w / 2, y0 + L * 0.5, za),
             _B(xc + w / 2, y0 + L * 0.72, zb), _B(xc - w / 2, y0 + L * 0.72, zb)]
        g.grille(q, 5, depth=0.025)
        zbo = zj_a(y0 + L * 0.9)
        g.box(_B(xc + sx * c.wj * 0.18, y0 + L * 0.9, zbo + 0.05), (0.14, 0.1 * SQ2, 0.1), M["steel_dk"], "hard",
              what="boite_bornes")
        g.cyl(_B(xc + sx * c.wj * 0.18, y0 + L * 0.9 - 0.05, zbo + 0.06), "y", 0.02, 0.06, M["steel"], n=8,
              what="presse_etoupe")
        # face sud de la joue : grille et rivets
        ze = c.ze
        zf = zj_a(c.yf)
        if zf - ze > 0.25:
            gw = min(0.3, c.wj * 0.5)
            q2 = [_B(xc - gw / 2, c.yf - 0.025, ze + (zf - ze) * 0.35), _B(xc + gw / 2, c.yf - 0.025, ze + (zf - ze) * 0.35),
                  _B(xc + gw / 2, c.yf - 0.025, ze + (zf - ze) * 0.75), _B(xc - gw / 2, c.yf - 0.025, ze + (zf - ze) * 0.75)]
            g.grille(q2, 4, depth=0.02)


def garnir(g, c):
    zones = getattr(c.ep, "GARNIR", ("bati", "joues"))
    with habille(g, c):
        if "bati" in zones:
            bati(g, c)
        if "joues" in zones and c.f_joues in ("caisson", "basses", "pente"):
            joues(g, c)
    _ = math
