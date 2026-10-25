"""Assembleur · Âge 11 · Titane (ère IV, 6×6, niveaux 21 et 22). Lot F3-A, ronde F3-A2 ; fiche FICHES_ASSEMBLEUR.md, âge
11. Dans Blender.

En 3 mots : « aile, gabarit, chevrons orange ». Plan en PORTIQUE : deux pylônes de titane bleu à CHEVRONS ORANGE,
coiffés chacun d'une DÉRIVE (aileron dressé), portent un pont-caisson d'alliage à barre de lumière bleu-blanc ; la tête de
rivetage orange y pend au bout d'un bras télescopique. Sur le lit, une AILE en flèche (bord d'attaque, nervures, saumon
orange) tenue par le GABARIT : quatre tours à mâchoires orange. Dos bas de titane, chevrons au sol.
Palette 60/30/10 (ages.PALETTE[11]) : bleu titane / alliage clair et bleu nuit / orange aéronautique ; lumière bleu-blanc.
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
TRAVAIL = dict(couches=2, images=24, organe="chariot qui court le long du pont et tête de rivetage qui pique (24 "
                                           "images) ; éclair du rivet et barre de lumière (couche glow)")
HABILLAGE = dict(ages.CORPS[11], plan='portique', forme_embase='chanfrein', forme_dos='bas', forme_joues='socle',
                 forme_portique='aucun')
DENSITE = dict(p=0.6, lampes=0.14)


def matieres(metal, M):
    ages.matieres(11, metal, M)


def _chevrons(g, x0, x1, yn, z0, z1, n):
    M = g.M
    hz = (z1 - z0) / n
    for k in range(n):
        zc = z0 + hz * (k + 0.5)
        for s in (-1, 1):
            g.box(B((x0 + x1) / 2 + s * (x1 - x0) * 0.22, yn - 0.03, zc), ((x1 - x0) * 0.5, 0.02, hz * 0.28),
                  M["orange_aero"], "flat", R=Matrix.Rotation(s * 0.5, 3, "Y"), what="chevron")


def _derive(g, x, yn, z, hgt, L, mat):
    vs = [(x - 0.04, B(0, yn - L / 2).y, z), (x - 0.04, B(0, yn + L / 2).y, z), (x - 0.04, B(0, yn + L / 2).y, z + hgt),
          (x - 0.04, B(0, yn + L * 0.05).y, z + hgt), (x + 0.04, B(0, yn - L / 2).y, z),
          (x + 0.04, B(0, yn + L / 2).y, z), (x + 0.04, B(0, yn + L / 2).y, z + hgt),
          (x + 0.04, B(0, yn + L * 0.05).y, z + hgt)]
    fs = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    g._add(mat, "hard", vs, fs, "derive")


def socle(g, c):
    """Chevrons sur les pylônes, dérives, barre de lumière du pont, feux, chevrons au sol, tôles du dos bas."""
    M = g.M
    y0 = c.yt - c.dp / 2.0
    for sx in (-1, 1):
        x = sx * c.xp
        _chevrons(g, x - c.wp / 2 + 0.08, x + c.wp / 2 - 0.08, y0 - 0.01, c.ze + 0.3, c.zp - 0.2, 5)
        _derive(g, x, c.yt, c.ztop, 0.9, c.dp * 0.95, M["titane_cl"])
        g.box(B(x, c.yt + c.dp * 0.42, c.ztop + 0.6), (0.1, 0.08 * SQ2, 0.24), M["orange_aero"], "hard",
              what="bout_derive")
        corps.lampe(g, B(x, c.yt + c.dp * 0.45, c.ztop + 0.74), 0.04, M["emit"])
        halo(g, x, c.yt + c.dp * 0.3, c.ztop + 0.8, 0.6)
        for k in range(3):
            corps.lampe_face(g, x, y0, c.ze + 0.4 + 0.5 * k, 0.035, M["emit"], M["titane_dk"])
    db = 0.22 * c.side
    L = 2 * (c.xp - c.wp / 2)
    g.box(B(0, c.yt - db / 2 - 0.03, c.zp - 0.04), (L - 0.2, 0.04, 0.05), M["titane_dk"], "hard", what="barre")
    g.box(B(0, c.yt - db / 2 - 0.05, c.zp - 0.06), (L - 0.3, 0.02, 0.02), M["emit"], "flat", what="barre_lumiere")
    halo(g, 0, c.yt - 0.5, c.zp - 0.2, 1.2)
    # chevrons au sol du bâti, tôles et bandeau du dos bas
    for sx in (-1, 1):
        for k in range(3):
            corps.chevron(g, sx * 1.0, -2.3 + 0.25 * k, c.zs + 0.03, sx, M["orange_aero"], k=0.18)
    corps.face_s(g, -c.h + 0.1, c.h - 0.1, c.yb - 0.02, c.zs + 0.02, c.z_bas - 0.02, M["tole_ti"], nu=8, nv=1)
    g.box(B(0, c.yb - 0.05, c.z_bas - 0.05), (2 * c.h - 0.2, 0.04, 0.05), M["bleu_nuit"], "hard", what="bandeau")


def outil(g, c):
    """Chariot sous le pont, bras télescopique, tête de rivetage orange."""
    M = g.M
    yt, zt, zp = c.yt, c.zt, c.zp
    x = 0.35
    g.box(B(x, yt, zp - 0.12), (0.55, 0.4 * SQ2, 0.22), M["orange_aero"], "hard", what="chariot")
    for k, (r, z0) in enumerate(((0.08, zp - 0.45), (0.06, zp - 0.8), (0.045, zp - 1.1))):
        g.cyl(B(x, yt, z0 + 0.15), "z", r, 0.36, M["ring"] if k % 2 else M["titane_dk"], n=14, what="telescope")
    g.box(B(x, yt, zt + 0.62), (0.2, 0.16 * SQ2, 0.14), M["orange_aero"], "hard", what="tete_rivetage")
    g.cyl(B(x, yt, zt + 0.5), "z", 0.04, 0.1, M["steel_hi"], n=10, what="bouterolle")
    corps.lampe(g, B(x, yt - 0.02, zt + 0.43), 0.03, M["emit"])
    halo(g, x, yt, zt + 0.45, 0.8)


def ouvrage(g, c):
    """Aile en flèche tenue par le gabarit : 4 tours à mâchoires orange, nervures, saumon orange."""
    M = g.M
    yt, zt = c.yt, c.zt
    za = zt + 0.36
    root, tip = (-1.3, 0.46), (1.3, 0.24)
    fl = 0.3
    le0, le1 = yt - 0.12, yt - 0.12 + fl
    pts_b = [B(root[0], le0, za), B(tip[0], le1, za), B(tip[0], le1 + tip[1], za), B(root[0], le0 + root[1], za)]
    pts_t = [p + V((0, 0, 0.08 if i in (0, 3) else 0.045)) for i, p in enumerate(pts_b)]
    g.hexa(pts_b + pts_t, M["titane_cl"], "soft", "aile")
    g.tube([B(root[0], le0, za + 0.04), B(tip[0], le1, za + 0.022)], 0.045, M["ring"], n=10, what="bord_attaque")
    for k in range(8):
        t = (k + 0.5) / 8
        x = root[0] + (tip[0] - root[0]) * t
        y0 = le0 + (le1 - le0) * t
        ch = root[1] + (tip[1] - root[1]) * t
        g.box(B(x, y0 + ch / 2, za + 0.075 - 0.03 * t), (0.025, ch * SQ2 * 0.9, 0.012), M["titane_md"], "hard",
              what="nervure")
    g.box(B(tip[0] - 0.08, le1 + tip[1] / 2, za + 0.03), (0.16, tip[1] * SQ2, 0.07), M["orange_aero"], "hard",
          what="saumon")
    for (x, yy) in ((root[0] + 0.3, le0 - 0.1), (root[0] + 0.3, le0 + root[1] + 0.06), (0.75, le1 - 0.14),
                    (0.75, le1 + 0.36)):
        g.box(B(x, yy, (zt + za) / 2), (0.12, 0.12 * SQ2, za - zt), M["titane_dk"], "hard", what="tour_gabarit")
        g.box(B(x, yy, za + 0.06), (0.16, 0.14 * SQ2, 0.09), M["orange_aero"], "hard", what="machoire")


def entree(g, c, p):
    """Pile de tôles de titane sur berceau (entrée)."""
    M = g.M
    g.box(B(p["x"], p["yn"], p["z"] + 0.04), (2 * p["r"], 1.4 * p["r"] * SQ2, 0.08), M["titane_dk"], "hard",
          what="berceau")
    for k in range(6):
        g.box(B(p["x"], p["yn"], p["z"] + 0.1 + 0.025 * k), (1.8 * p["r"], 1.2 * p["r"] * SQ2, 0.02),
              M["tole_ti"] if k % 2 else M["titane_cl"], "hard", what="tole")


def sortie(g, c, p):
    """Chevalet de pièces d'aile finies à saumon orange (sortie)."""
    M = g.M
    corps.bac(g, c, p, M["titane_dk"], M["titane_cl"], forme="plaque")
    g.box(B(p["x"], p["yn"] - p["r"] * 0.5, p["z"] + 0.16), (1.4 * p["r"], 0.04, 0.03), M["orange_aero"], "hard",
          what="liseré")


def piece(g, c):
    """Niveau 22 (plus grande) : dérive de rechange dressée sur chevalet et panneaux d'aile (coins avant)."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        x, yn, z = p["x"], p["yn"] + 0.05, p["z_sol"]
        for s in (-1, 1):
            g.box(B(x + s * 0.35, yn, z + 0.18), (0.07, 0.45 * SQ2, 0.36), M["titane_dk"], "hard", what="chevalet")
        g.box(B(x, yn, z + 0.38), (0.86, 0.5 * SQ2, 0.05), M["titane_cl"], "soft", R=Matrix.Rotation(0.1, 3, "X"),
              what="panneau")
        _derive(g, x, yn, z + 0.42, 0.6, 0.6, M["titane_md"])
        g.box(B(x, yn + 0.27, z + 0.85), (0.1, 0.06 * SQ2, 0.16), M["orange_aero"], "hard", what="bout")
        corps.lampe(g, B(x, yn + 0.28, z + 0.95), 0.03, M["emit"])
