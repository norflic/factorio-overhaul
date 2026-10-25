"""Assembleur · Âge 5 · Volcan (ère II, 4×4, niveaux 9 et 10). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge 5. Dans Blender.

En 3 mots : « poche de coulée, moules, pyramide de basalte ». Le dos est une PYRAMIDE DE BASALTE à trois gradins, coulées
de lave entre les assises et cratère rougeoyant au sommet. Une ARCHE de fonte noire enjambe la baie ; à sa clef pend la
POCHE DE COULÉE, penchée, qui verse un filet de lave dans les MOULES à lingots posés sur la table. Joues en pente,
embase chanfreinée de dalles de basalte, rigole de lave dans le sol.
Palette 60/30/10 (ages.PALETTE[5]) : basalte noir / rouille brûlée (fonte) / lave orange.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
from corps import B, halo
from kit import SQ2

V = Vector

EPOQUE = 5
NOM = ages.NOMS[5]
TRIPLET = ("poche de coulée", "moules", "pyramide de basalte")
FOYER = ages.FOYER[5]
TRAVAIL = dict(couches=2, images=16, organe="poche qui bascule (0 à 25°) et filet de lave qui coule ; surface de lave "
                                           "des moules et du cratère qui ondule (couche glow)")
HABILLAGE = dict(ages.CORPS[5], forme_embase='chanfrein', forme_dos='gradins', forme_joues='pente',
                 forme_portique='arche', mat_dos='basalte_capot', mat_portique='fonte_noire')
PENTE = 0.42      # bascule de la poche (radians)


def matieres(metal, M):
    ages.matieres(5, metal, M)


def socle(g, c):
    M = g.M
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    y1 = h - 0.02
    hs = c.hs_gradins
    ze = c.zs           # troisième jet : sol de la baie = dessus du plateau
    # coulées de lave au pied de chaque contremarche
    for k in range(3):
        yy = yb + (y1 - yb) * k / 3.0
        ins = 0.06 * k
        z0 = ze if k == 0 else hs[k - 1]
        g.box(B(0, yy - 0.035, z0 + 0.02), (2 * (h - ins) - 0.2, 0.025, 0.035), M["emit"], "soft", what="filet_lave")
        for j in range(3 + k):
            x = -h + ins + 0.3 + (2 * (h - ins) - 0.6) * (j + 0.5) / (3 + k)
            g.box(B(x, yy - 0.03, (z0 + hs[k]) / 2), (0.05, 0.02, hs[k] - z0 - 0.06), M["emit_soft"], "soft",
                  what="coulee")
    # cratère au sommet
    yc = yb + (y1 - yb) * 5 / 6.0
    g.tube_shell(B(0, yc, Hd + 0.06), "z", 0.36, 0.26, 0.12, M["basalte_capot"], n=24, what="levre")
    g.cyl(B(0, yc, Hd + 0.04), "z", 0.27, 0.04, M["emit"], n=24, what="lave_cratere")
    halo(g, 0, yc, Hd + 0.2, 2.0)
    # orgues de basalte aux coins du sommet
    for sx in (-1, 1):
        for k in range(5):
            x = sx * (h - 0.25 - 0.09 * k)
            g.cyl(B(x, yc + 0.1 * (k % 2), Hd + 0.08 + 0.04 * (k % 3)), "z", 0.05, 0.16 + 0.08 * (k % 3),
                  M["basalte_capot"], n=6, style="hard", what="orgue")
    # rigole de lave dans le sol, de la face vers l'avant (côté est), blocs et scories
    g.box(B(0.75, (c.yt + yb) / 2 - 0.3, ze + 0.008), (0.1, (yb - c.yt + 0.4) * SQ2, 0.016), M["emit"], "soft",
          what="rigole")
    for yy in (yb - 0.1, -0.3, -0.9):
        F.lump(g, B(0.92, yy, ze), 0.08, M["basalte_capot"])
        F.lump(g, B(0.58, yy - 0.15, ze), 0.06, M["fonte_noire"])
    halo(g, 0.75, -0.2, ze + 0.1, 0.8)
    for k in range(5):
        F.lump(g, B(-0.75 + 0.1 * k, -1.55 + 0.04 * (k % 2), ze), 0.07, M["braise_sombre"])


def outil(g, c):
    """Poche de coulée pendue à la clef de l'arche, penchée vers les moules ; filet de lave."""
    M = g.M
    yt, zt = c.yt, c.zt
    top = c.zp + c.bp
    cx, cz = -0.12, zt + 0.62
    R = Matrix.Rotation(-PENTE, 3, "Y")
    a = V((0, 0, 1))
    up = R @ a
    p = B(cx, yt, cz)
    g.cyl(p, up, 0.2, 0.3, M["fonte_noire"], n=24, r2=0.24, what="poche")
    g.tube_shell(p + up * 0.15, up, 0.25, 0.2, 0.04, M["fonte_v"], n=24, what="bec")
    g.cyl(p + up * 0.14, up, 0.2, 0.02, M["emit"], n=24, what="lave_poche")
    for s in (-1, 1):
        g.cyl(p + V((0, s * 0.27, 0)), "y", 0.04, 0.08, M["fonte_v"], n=10, what="tourillon")
    # anse et chaînes jusqu'à la clef
    g.tube([p + V((0, -0.3, 0)), p + V((0, -0.3, 0.38)), p + V((0, 0.3, 0.38)), p + V((0, 0.3, 0))], 0.022,
           M["fonte_noire"], n=8, what="anse")
    F.chain(g, p + V((0, 0, 0.4)), B(0, yt, top - 0.05), sag=0.02)
    # filet de lave vers le moule
    lip = p + up * 0.17 + R @ V((0.24, 0, 0))
    g.tube([lip, lip + V((0.05, 0, -0.08)), B(0.1, yt, zt + 0.12)], 0.025, M["emit"], n=8, what="filet")
    halo(g, 0.08, yt, zt + 0.3, 1.4)


def ouvrage(g, c):
    """Quatre moules à lingots de fonte : deux pleins de lave, deux refroidis (tungstène)."""
    M = g.M
    yt, zt = c.yt, c.zt
    for k in range(4):
        x = -0.36 + 0.24 * k + 0.12
        g.box(B(x, yt, zt + 0.06), (0.2, 0.34 * SQ2, 0.12), M["fonte_v"], "hard", what="moule")
        g.box(B(x, yt, zt + 0.115), (0.13, 0.26 * SQ2, 0.02), M["emit"] if k in (1, 2) else M["tungsten"], "soft",
              what="lingot")
    g.box(B(0, yt + 0.25, zt + 0.03), (1.0, 0.06 * SQ2, 0.06), M["fonte_noire"], "hard", what="rail_moules")


def piece(g, c):
    """Niveau 10 : pile de lingots de tungstène encore chauds (coin avant gauche), wagonnet de scories (coin avant
    droit)."""
    M = g.M
    po, pe = corps.place(c, "coin_SO"), corps.place(c, "coin_SE")
    z = po["z_sol"]
    for lvl in range(3):
        for k in range(4 - lvl):
            x = po["x"] - 0.2 + 0.13 * k + 0.065 * lvl
            g.box(B(x, po["yn"], z + 0.04 + 0.075 * lvl), (0.11, 0.36 * SQ2, 0.07),
                  M["tungsten"] if (k + lvl) % 3 else M["braise_sombre"], "hard", what="lingot")
    g.box(B(po["x"], po["yn"] - 0.19, z + 0.2), (0.24, 0.02, 0.025), M["emit"], "soft", what="tranche_chaude")
    halo(g, po["x"], po["yn"] - 0.2, z + 0.25, 0.6)
    # wagonnet
    xe, ye = pe["x"], pe["yn"]
    g.hexa([B(xe - 0.22, ye - 0.15, z + 0.1), B(xe + 0.22, ye - 0.15, z + 0.1), B(xe + 0.22, ye + 0.15, z + 0.1),
            B(xe - 0.22, ye + 0.15, z + 0.1), B(xe - 0.28, ye - 0.2, z + 0.34), B(xe + 0.28, ye - 0.2, z + 0.34),
            B(xe + 0.28, ye + 0.2, z + 0.34), B(xe - 0.28, ye + 0.2, z + 0.34)], M["fonte_noire"], "hard", "wagonnet")
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.cyl(B(xe + sx * 0.17, ye + sy * 0.12, z + 0.07), "x", 0.07, 0.04, M["fonte_v"], n=12, what="roue")
    for k in range(6):
        F.lump(g, B(xe - 0.15 + 0.06 * k, ye + 0.03 * (k % 2), z + 0.32), 0.07,
               M["braise_sombre"] if k % 2 else M["basalte_capot"])
    g.box(B(xe, ye - 0.05, z + 0.37), (0.12, 0.08 * SQ2, 0.02), M["emit_soft"], "soft", what="scorie_chaude")
    _ = math
