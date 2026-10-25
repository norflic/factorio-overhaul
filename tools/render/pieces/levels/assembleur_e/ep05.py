"""Assembleur · Âge 5 · Volcan (ère II, 4×4, niveaux 9 et 10). Lot F3-A, ronde F3-A2 ; fiche FICHES_ASSEMBLEUR.md, âge 5.
Dans Blender.

En 3 mots : « poche de coulée, moules, pyramide de basalte ». Plan OCTOGONAL : tambour de dalles de basalte et, au nord,
un croissant à deux GRADINS de basalte (la pyramide) fendu de coulées de lave, cratère rougeoyant et orgues au sommet.
Trois rayons de fonte noire montent du croissant au moyeu ; la POCHE DE COULÉE y pend, penchée, et verse un filet de lave
dans les MOULES posés en couronne sur le lit rond. Rigoles de lave dans le sol.
Palette 60/30/10 (ages.PALETTE[5]) : basalte noir / rouille brûlée (fonte) / lave orange.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
from corps import B, halo
from kit import SQ2, TAU

V = Vector

EPOQUE = 5
NOM = ages.NOMS[5]
TRIPLET = ("poche de coulée", "moules", "pyramide de basalte")
FOYER = ages.FOYER[5]
TRAVAIL = dict(couches=2, images=16, organe="poche qui bascule (0 à 25°) et filet de lave qui coule ; surface de lave "
                                           "des moules et du cratère qui ondule (couche glow)")
HABILLAGE = dict(ages.CORPS[5], capots=("basalte_capot", "fonte_v"), plan='octo', forme_embase='carre',
                 forme_dos='plat', forme_joues='caisson', forme_portique='aucun')
DENSITE = dict(p=0.5, lampes=0.0)
PENTE = 0.42


def matieres(metal, M):
    ages.matieres(5, metal, M)


def socle(g, c):
    """Second gradin du croissant, coulées de lave, cratère, orgues, rigoles, blocs."""
    M = g.M
    R1 = c.Rb - 0.06
    R0 = R1 - c.ep_cr
    Rm = R0 + 0.45 * c.ep_cr
    H2 = c.Hc + 0.28
    for k in range(4):
        t0 = math.pi / 8 + k * math.pi / 4
        t1 = t0 + math.pi / 4
        p = [(R1 * 0.97 * math.cos(t0), R1 * 0.97 * math.sin(t0)), (R1 * 0.97 * math.cos(t1), R1 * 0.97 * math.sin(t1)),
             (Rm * math.cos(t1), Rm * math.sin(t1)), (Rm * math.cos(t0), Rm * math.sin(t0))]
        g.hexa([B(x, y, c.Hc) for x, y in p] + [B(x, y, H2) for x, y in p], M["basalte_capot"], "hard", "gradin")
        # filets de lave au pied de chaque contremarche
        qa, qb = (R0 * math.cos(t1), R0 * math.sin(t1)), (R0 * math.cos(t0), R0 * math.sin(t0))
        g.box((B(*qa, c.zr + 0.03) + B(*qb, c.zr + 0.03)) / 2 - V((0, 0.03, 0)),
              ((B(*qa) - B(*qb)).length * 0.9, 0.025, 0.03), M["emit"], "soft",
              R=Matrix.Rotation(math.atan2(B(*qa).y - B(*qb).y, B(*qa).x - B(*qb).x), 3, "Z"), what="filet_lave")
        ma, mb = (Rm * math.cos(t1), Rm * math.sin(t1)), (Rm * math.cos(t0), Rm * math.sin(t0))
        g.box((B(*ma, c.Hc + 0.02) + B(*mb, c.Hc + 0.02)) / 2 - V((0, 0.03, 0)),
              ((B(*ma) - B(*mb)).length * 0.9, 0.022, 0.03), M["emit"], "soft",
              R=Matrix.Rotation(math.atan2(B(*ma).y - B(*mb).y, B(*ma).x - B(*mb).x), 3, "Z"), what="filet_lave")
        # coulées verticales sur la face du croissant
        for f in (0.3, 0.7):
            t = t0 + f * (t1 - t0)
            g.box(B(R0 * math.cos(t), R0 * math.sin(t) - 0.02, (c.zr + c.Hc) / 2), (0.05, 0.02, c.Hc - c.zr - 0.1),
                  M["emit_soft"], "soft", what="coulee")
    # cratère sur le gradin nord, orgues de basalte
    yc = (R1 + Rm) / 2.0 * 0.95
    g.tube_shell(B(0, yc, H2 + 0.06), "z", 0.34, 0.24, 0.12, M["basalte_capot"], n=24, what="levre")
    g.cyl(B(0, yc, H2 + 0.04), "z", 0.25, 0.04, M["emit"], n=24, what="lave_cratere")
    halo(g, 0, yc, H2 + 0.2, 1.6)
    for sx in (-1, 1):
        for k in range(6):
            t = math.radians(90 + sx * (35 + 9 * k))
            g.cyl(B(Rm * 1.08 * math.cos(t), Rm * 1.08 * math.sin(t), H2 + 0.08 + 0.04 * (k % 3)), "z", 0.05,
                  0.16 + 0.08 * (k % 3), M["basalte_capot"], n=6, style="hard", what="orgue")
    c.reserves.append((0, yc, 0.5))
    # rigoles de lave dans le dessus du tambour, blocs et scories
    for sx in (-1, 1):
        g.box(B(sx * 0.95, c.cy - 0.35, c.zr + 0.008), (0.08, 0.6 * SQ2, 0.016), M["emit"], "soft", what="rigole")
        F.lump(g, B(sx * 0.8, c.cy - 0.62, c.zr), 0.09, M["basalte_capot"])
        F.lump(g, B(sx * 0.5, c.cy - 0.78, c.zr), 0.07, M["fonte_noire"])
        c.reserves.append((sx * 1.0, c.cy - 0.6, 0.3))
    halo(g, 0, c.cy - 0.5, c.zr + 0.1, 0.8)


def outil(g, c):
    """Poche de coulée pendue au moyeu, penchée vers les moules ; filet de lave."""
    M = g.M
    zt = c.zt
    hub = c.hub
    cx, cz = -0.1, zt + 0.55
    R = Matrix.Rotation(-PENTE, 3, "Y")
    up = R @ V((0, 0, 1))
    p = B(cx, c.cy, cz)
    g.cyl(p, up, 0.19, 0.3, M["fonte_noire"], n=24, r2=0.23, what="poche")
    g.tube_shell(p + up * 0.15, up, 0.24, 0.19, 0.04, M["fonte_v"], n=24, what="bec")
    g.cyl(p + up * 0.14, up, 0.19, 0.02, M["emit"], n=24, what="lave_poche")
    for s in (-1, 1):
        g.cyl(p + V((0, s * 0.26, 0)), "y", 0.04, 0.08, M["fonte_v"], n=10, what="tourillon")
    g.tube([p + V((0, -0.29, 0)), p + V((0, -0.29, 0.36)), p + V((0, 0.29, 0.36)), p + V((0, 0.29, 0))], 0.022,
           M["fonte_noire"], n=8, what="anse")
    F.chain(g, p + V((0, 0, 0.38)), hub - V((0, 0, 0.08)), sag=0.02)
    lip = p + up * 0.17 + R @ V((0.23, 0, 0))
    g.tube([lip, lip + V((0.05, 0, -0.08)), B(0.12, c.cy, zt + 0.12)], 0.024, M["emit"], n=8, what="filet")
    halo(g, 0.08, c.cy, zt + 0.3, 1.2)


def ouvrage(g, c):
    """Six moules à lingots en couronne sur le lit : deux pleins de lave, quatre refroidis (tungstène)."""
    M = g.M
    zt = c.zt
    for k in range(6):
        a = math.radians(200 + 28 * k)
        x, y = 0.42 * math.cos(a), c.cy + 0.3 * math.sin(a)
        R = Matrix.Rotation(a, 3, "Z")
        g.box(B(x, y, zt + 0.05), (0.16, 0.24 * SQ2, 0.1), M["fonte_v"], "hard", R=R, what="moule")
        g.box(B(x, y, zt + 0.1), (0.1, 0.17 * SQ2, 0.02), M["emit"] if k in (2, 3) else M["tungsten"], "soft", R=R,
              what="lingot")
    g.cyl(B(0.12, c.cy, zt + 0.05), "z", 0.13, 0.1, M["fonte_v"], n=16, what="moule_central")
    g.cyl(B(0.12, c.cy, zt + 0.1), "z", 0.1, 0.02, M["emit"], n=16, what="lave_moule")
    _ = TAU


def entree(g, c, p):
    """Creuset de basalte plein de minerai de tungstène (entrée)."""
    M = g.M
    g.cyl(B(p["x"], p["yn"], p["z"] + 0.1), "z", p["r"] * 0.8, 0.2, M["basalte_capot"], n=12, r2=p["r"], what="creuset")
    for k in range(6):
        F.lump(g, B(p["x"] - 0.06 + 0.025 * k, p["yn"] + 0.02 * (k % 2), p["z"] + 0.2), 0.04, M["tungsten"])


def sortie(g, c, p):
    """Plaque de fonte chargée de lingots de tungstène (sortie)."""
    corps.bac(g, c, p, g.M["fonte_noire"], g.M["tungsten"], forme="lingot")


def piece(g, c):
    """Niveau 10 (plus grande, hors du tambour) : pile de lingots de tungstène encore chauds (coin avant gauche),
    wagonnet de scories (coin avant droit)."""
    M = g.M
    po, pe = corps.place(c, "coin_SO"), corps.place(c, "coin_SE")
    z = po["z_sol"]
    for lvl in range(4):
        for k in range(4 - lvl):
            x = po["x"] - 0.21 + 0.14 * k + 0.07 * lvl
            g.box(B(x, po["yn"], z + 0.04 + 0.075 * lvl), (0.12, 0.4 * SQ2, 0.07),
                  M["tungsten"] if (k + lvl) % 3 else M["braise_sombre"], "hard", what="lingot")
    g.box(B(po["x"], po["yn"] - 0.21, z + 0.2), (0.26, 0.02, 0.03), M["emit"], "soft", what="tranche_chaude")
    halo(g, po["x"], po["yn"] - 0.22, z + 0.25, 0.6)
    xe, ye = pe["x"], pe["yn"]
    g.hexa([B(xe - 0.24, ye - 0.16, z + 0.12), B(xe + 0.24, ye - 0.16, z + 0.12), B(xe + 0.24, ye + 0.16, z + 0.12),
            B(xe - 0.24, ye + 0.16, z + 0.12), B(xe - 0.3, ye - 0.22, z + 0.4), B(xe + 0.3, ye - 0.22, z + 0.4),
            B(xe + 0.3, ye + 0.22, z + 0.4), B(xe - 0.3, ye + 0.22, z + 0.4)], M["fonte_noire"], "hard", "wagonnet")
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.cyl(B(xe + sx * 0.18, ye + sy * 0.13, z + 0.08), "x", 0.08, 0.04, M["fonte_v"], n=12, what="roue")
    for k in range(6):
        F.lump(g, B(xe - 0.16 + 0.065 * k, ye + 0.03 * (k % 2), z + 0.38), 0.07,
               M["braise_sombre"] if k % 2 else M["basalte_capot"])
    g.box(B(xe, ye - 0.05, z + 0.43), (0.14, 0.09 * SQ2, 0.02), M["emit_soft"], "soft", what="scorie_chaude")
