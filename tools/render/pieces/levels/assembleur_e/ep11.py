"""Assembleur · Âge 11 · Titane (ère IV, 6×6, niveaux 21 et 22). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge 11. Dans
Blender.

En 3 mots : « aile, gabarit, chevrons orange ». Un HANGAR d'aéronautique : dos à toit à deux pans de titane bleu, portes
de hangar à CHEVRONS ORANGE, dérives (ailerons) dressées aux deux bouts du faîtage. Sur la table, une AILE en flèche
(bord d'attaque arrondi, nervures, saumon orange) tenue par un GABARIT de quatre tours à mâchoires orange ; le chariot
du portique porte une tête de rivetage orange à bras télescopique et une barre de lumière bleu-blanc.
Palette 60/30/10 (ages.PALETTE[11]) : bleu titane / alliage clair et bleu nuit / orange aéronautique ; lumière
bleu-blanc.
"""
from mathutils import Matrix, Vector

import ages
import corps
from corps import B, halo
from kit import SQ2

V = Vector

EPOQUE = 11
NOM = ages.NOMS[11]
TRIPLET = ("aile", "gabarit", "chevrons orange")
FOYER = ages.FOYER[11]
TRAVAIL = dict(couches=2, images=24, organe="chariot qui court le long de la poutre et tête de rivetage qui pique (24 "
                                           "images) ; éclair du rivet et barre de lumière (couche glow)")
HABILLAGE = dict(ages.CORPS[11], forme_embase='chanfrein', forme_dos='pans', forme_joues='caisson',
                 forme_portique='poutre', mat_portique='titane_dk')


def matieres(metal, M):
    ages.matieres(11, metal, M)


def _chevrons(g, x0, x1, yn, z0, z1, n):
    """Chevrons orange (V pointés vers le haut) sur une face sud."""
    M = g.M
    w = (x1 - x0) / n
    for k in range(n):
        xc = x0 + w * (k + 0.5)
        for s in (-1, 1):
            g.box(B(xc + s * w * 0.22, yn - 0.03, (z0 + z1) / 2), (w * 0.12, 0.02, (z1 - z0) * 0.9), M["orange_aero"],
                  "flat", R=Matrix.Rotation(-s * 0.55, 3, "Y"), what="chevron")


def _derive(g, x, yn, z, hgt, L, mat):
    """Dérive (aileron) dressée dans le plan nord-sud : bord d'attaque en flèche."""
    vs = [(x - 0.03, B(0, yn - L / 2).y, z), (x - 0.03, B(0, yn + L / 2).y, z), (x - 0.03, B(0, yn + L / 2).y, z + hgt),
          (x - 0.03, B(0, yn + L * 0.05).y, z + hgt), (x + 0.03, B(0, yn - L / 2).y, z),
          (x + 0.03, B(0, yn + L / 2).y, z), (x + 0.03, B(0, yn + L / 2).y, z + hgt),
          (x + 0.03, B(0, yn + L * 0.05).y, z + hgt)]
    fs = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    g._add(mat, "hard", vs, fs, "derive")


def socle(g, c):
    M = g.M
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    zw = c.zw_pans
    ze = c.zs           # troisième jet : sol de la baie = dessus du plateau
    ym = (yb + h - 0.02) / 2.0
    # portes de hangar à chevrons orange, rails, bandeau bleu nuit
    for sx in (-1, 1):
        x0, x1 = (-c.xb + 0.05, -0.1) if sx < 0 else (0.1, c.xb - 0.05)
        g.box(B((x0 + x1) / 2, yb - 0.02, (ze + zw) / 2), (x1 - x0, 0.03, zw - ze - 0.1), M["titane_md"], "hard",
              what="porte_hangar")
        _chevrons(g, x0 + 0.1, x1 - 0.1, yb - 0.01, (ze + zw) / 2, zw - 0.08, 3)
        for k in range(5):
            g.box(B(x0 + (x1 - x0) * (k + 0.5) / 5, yb - 0.035, (ze + zw) / 2 - 0.1), (0.02, 0.02, (zw - ze) * 0.4),
                  M["titane_dk"], "hard", what="raidisseur")
    g.box(B(0, yb - 0.05, zw - 0.03), (2 * h, 0.04, 0.07), M["bleu_nuit"], "hard", what="bandeau")
    for k in range(9):
        x = -h + 0.3 + (2 * h - 0.6) * k / 8
        corps.lampe_face(g, x, yb - 0.03, zw - 0.03, 0.03, M["emit"], M["titane_dk"])
    halo(g, 0, yb - 0.3, zw, 1.0)
    # dérives aux deux bouts du faîtage, feux de bout d'aile
    for sx in (-1, 1):
        x = sx * (h - 0.35)
        _derive(g, x, ym, Hd - 0.05, 0.75, 0.9, M["titane_cl"])
        g.box(B(x, ym + 0.38, Hd + 0.5), (0.07, 0.06 * SQ2, 0.22), M["orange_aero"], "hard", what="bout_derive")
        corps.lampe(g, B(x, ym + 0.42, Hd + 0.62), 0.04, M["emit"])
        halo(g, x, ym + 0.3, Hd + 0.65, 0.5)
    # chevrons orange au sol de la baie (sens de sortie)
    for sx in (-1, 1):
        for k in range(3):
            corps.chevron(g, sx * 1.2, -2.3 + 0.25 * k, c.zs + 0.03, sx, M["orange_aero"], k=0.18)


def outil(g, c):
    """Tête de rivetage orange sur le chariot, bras télescopique, barre de lumière."""
    M = g.M
    yt, zt, zp, bp = c.yt, c.zt, c.zp, c.bp
    top = zp + bp
    x = 0.35
    g.box(B(x, yt, top + 0.15), (0.5, 0.36 * SQ2, 0.22), M["orange_aero"], "hard", what="tete_rivetage")
    g.box(B(x, yt - 0.2, top + 0.15), (0.4, 0.02, 0.06), M["titane_dk"], "hard", what="grille")
    for k, (r, z0) in enumerate(((0.07, zp - 0.25), (0.055, zp - 0.6), (0.04, zp - 0.9))):
        g.cyl(B(x, yt, z0 + 0.15), "z", r, 0.34, M["ring"] if k % 2 else M["titane_dk"], n=14, what="telescope")
    g.cyl(B(x, yt, zt + 0.52), "z", 0.06, 0.08, M["orange_aero"], n=14, what="bouterolle")
    corps.lampe(g, B(x, yt - 0.02, zt + 0.46), 0.03, M["emit"])
    g.box(B(-0.5, yt - 0.08, zp - 0.06), (1.4, 0.06 * SQ2, 0.05), M["titane_dk"], "hard", what="barre")
    g.box(B(-0.5, yt - 0.13, zp - 0.08), (1.3, 0.02, 0.02), M["emit"], "flat", what="barre_lumiere")
    halo(g, -0.5, yt - 0.2, zp - 0.2, 1.0)
    halo(g, x, yt, zt + 0.4, 0.6)


def ouvrage(g, c):
    """Aile en flèche tenue par le gabarit : 4 tours à mâchoires orange, nervures, saumon orange."""
    M = g.M
    yt, zt = c.yt, c.zt
    za = zt + 0.36
    root, tip = (-1.25, 0.42), (1.25, 0.22)        # (x, corde) emplanture à l'ouest, saumon à l'est
    fl = 0.28                                        # flèche (yn du bord d'attaque au saumon)
    le0, le1 = yt - 0.1, yt - 0.1 + fl
    pts_b = [B(root[0], le0, za), B(tip[0], le1, za), B(tip[0], le1 + tip[1], za), B(root[0], le0 + root[1], za)]
    pts_t = [p + V((0, 0, 0.07 if i in (0, 3) else 0.04)) for i, p in enumerate(pts_b)]
    g.hexa(pts_b + pts_t, M["titane_cl"], "soft", "aile")
    g.tube([B(root[0], le0, za + 0.035), B(tip[0], le1, za + 0.02)], 0.04, M["ring"], n=10, what="bord_attaque")
    for k in range(7):
        t = (k + 0.5) / 7
        x = root[0] + (tip[0] - root[0]) * t
        y0 = le0 + (le1 - le0) * t
        ch = root[1] + (tip[1] - root[1]) * t
        g.box(B(x, y0 + ch / 2, za + 0.065 - 0.025 * t), (0.025, ch * SQ2 * 0.9, 0.012), M["titane_md"], "hard",
              what="nervure")
    g.box(B(tip[0] - 0.08, le1 + tip[1] / 2, za + 0.03), (0.16, tip[1] * SQ2, 0.06), M["orange_aero"], "hard",
          what="saumon")
    for (x, yy) in ((root[0] + 0.3, le0 - 0.08), (root[0] + 0.3, le0 + root[1] + 0.06), (0.7, le1 - 0.12),
                    (0.7, le1 + 0.36)):
        g.box(B(x, yy, (zt + za) / 2), (0.1, 0.1 * SQ2, za - zt), M["titane_dk"], "hard", what="tour_gabarit")
        g.box(B(x, yy, za + 0.06), (0.14, 0.12 * SQ2, 0.08), M["orange_aero"], "hard", what="machoire")


def piece(g, c):
    """Niveau 22 : dérives de rechange sur chevalets (coins avant)."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        x, yn, z = p["x"], p["yn"] + 0.05, p["z_sol"]
        for s in (-1, 1):
            g.box(B(x + s * 0.3, yn, z + 0.16), (0.06, 0.4 * SQ2, 0.32), M["titane_dk"], "hard", what="chevalet")
        g.box(B(x, yn, z + 0.34), (0.8, 0.5 * SQ2, 0.05), M["titane_cl"], "soft", R=Matrix.Rotation(0.1, 3, "X"),
              what="panneau")
        g.box(B(x + 0.3, yn, z + 0.38), (0.18, 0.5 * SQ2, 0.04), M["orange_aero"], "hard", what="bout")
        corps.chevron(g, x - 0.1, yn - 0.05, z + 0.37, 1, M["orange_aero"], k=0.14)
