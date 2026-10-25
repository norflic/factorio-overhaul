"""Assembleur · Âge 7 · Cristal (ère III, 5×5, niveaux 13 et 14). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge 7. Dans
Blender.

En 3 mots : « fronton, prismes, rayon violet ». Un TEMPLE : perron de pierre claire à deux marches, joues en colonnade,
dos à toit de bronze à deux pans précédé d'un FRONTON triangulaire (cristal violet dans le tympan, acrotères de
cristaux). Une ARCHE de bronze enjambe la baie ; à sa clef, une couronne tient trois PRISMES de cristal pointés vers la
table, d'où tombe un RAYON VIOLET qui taille la gemme posée sur un support de bronze. Vasques à cristaux dans la baie.
Palette 60/30/10 (ages.PALETTE[7]) : bronze doré / pierre claire / violet des cristaux.
"""
import math

from mathutils import Vector

import ages
import corps
import formes as F
from corps import B, halo, prisme_x
from kit import SQ2, TAU

V = Vector

EPOQUE = 7
NOM = ages.NOMS[7]
TRIPLET = ("fronton", "prismes", "rayon violet")
FOYER = ages.FOYER[7]
TRAVAIL = dict(couches=2, images=16, organe="couronne de prismes qui tourne lentement (16 images) ; rayon violet qui "
                                           "pulse et éclats de la gemme (couche glow)")
HABILLAGE = dict(ages.CORPS[7], plan='carre', forme_embase='gradins', forme_dos='pans', forme_joues='colonnes',
                 forme_portique='arche', mat_dos='bronze_capot', mat_joues='pierre_claire', mat_portique='bronze_capot')
DENSITE = dict(p=0.55, lampes=0.06)


def matieres(metal, M):
    ages.matieres(7, metal, M)


def _vasque(g, x, yn, z, r):
    M = g.M
    g.cyl(B(x, yn, z + 0.12), "z", 0.04, 0.24, M["bronze_sombre"], n=10, what="pied_vasque")
    g.cyl(B(x, yn, z + 0.27), "z", r, 0.08, M["bronze_capot"], n=16, r2=r * 1.25, what="vasque")
    for k in range(5):
        a = 2 * math.pi * k / 5
        d = V((0.35 * math.cos(a), 0.35 * math.sin(a), 1.0))
        F.crystal(g, B(x + 0.3 * r * math.cos(a), yn + 0.3 * r * math.sin(a), z + 0.3), d, 0.03, 0.12 + 0.03 * (k % 2),
                  M["emit_soft"] if k % 2 else M["crystal"])
    halo(g, x, yn, z + 0.4, 0.7)


def socle(g, c):
    M = g.M
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    zw = c.zw_pans
    zs = c.zs
    # pilastres de pierre sur la face, niches à flamme violette
    n = 6
    for k in range(n + 1):
        x = -h + 0.2 + (2 * h - 0.4) * k / n
        g.box(B(x, yb - 0.06, (zs + zw) / 2), (0.14, 0.08 * SQ2, zw - zs - 0.04), M["pierre_claire"], "hard",
              what="pilastre")
        g.box(B(x, yb - 0.08, zw - 0.06), (0.2, 0.1 * SQ2, 0.06), M["bronze_clair"], "hard", what="chapiteau")
        if k < n and k % 2 == 0:
            xm = x + (2 * h - 0.4) / n / 2
            g.box(B(xm, yb - 0.03, zs + 0.22), (0.2, 0.03, 0.3), M["joint_violet"], "flat", what="niche")
            F.crystal(g, B(xm, yb - 0.08, zs + 0.09), (0, 0, 1), 0.035, 0.18, M["emit"])
            halo(g, xm, yb - 0.2, zs + 0.22, 0.6)
    # FRONTON : triangle de pierre face au sud, corniche de bronze, cristal dans le tympan
    wf = 2 * h * 0.62
    hf = (Hd - zw) * 1.05
    yf0 = yb - 0.12
    tri = [(B(0, yf0).y - 0.02, zw), (B(0, yf0).y + 0.25, zw), (B(0, yf0).y + 0.25, zw + hf), (B(0, yf0).y - 0.02, zw + hf)]
    # prisme d'axe Y : triangle (x, z) extrudé en Y
    vs, fs = [], []
    for y in (tri[0][0], tri[1][0]):
        vs += [(-wf / 2, y, zw), (wf / 2, y, zw), (0.0, y, zw + hf)]
    fs = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    g._add(M["pierre_claire"], "hard", vs, fs, "fronton")
    for s in (-1, 1):
        a = V((s * wf / 2, tri[0][0] - 0.03, zw)), V((0, tri[0][0] - 0.03, zw + hf + 0.04))
        g.tube([a[0], a[1]], 0.035, M["bronze_capot"], n=6, what="corniche")
    g.box(V((0, tri[0][0] - 0.03, zw + 0.02)), (wf + 0.1, 0.06, 0.05), M["bronze_capot"], "hard", what="architrave")
    F.crystal(g, V((0, tri[0][0] - 0.06, zw + 0.06)), (0, 0, 1), 0.07, hf * 0.62, M["emit"], n=6)
    halo(g, 0, yf0 - 0.1, zw + hf * 0.3, 1.0)
    for s in (-1, 0, 1):
        x = s * wf / 2
        z = zw + (hf + 0.04 if s == 0 else 0.04)
        F.crystal(g, V((x, tri[0][0] + 0.05, z)), (0, 0, 1), 0.05, 0.22, M["crystal"], n=6)
    # crête de cristaux le long du faîtage
    ym = (yb + h - 0.02) / 2.0
    for k in range(9):
        x = -h + 0.35 + (2 * h - 0.7) * k / 8
        F.crystal(g, B(x, ym, Hd + 0.02), (0.15 * math.sin(k), 0, 1), 0.035, 0.12 + 0.05 * (k % 3), M["crystal"])
    # vasques à cristaux aux coins avant de la baie
    for sx in (-1, 1):
        _vasque(g, sx * (c.xb - 0.3), c.yt - c.T["table"]["ty"] - 0.35, zs, 0.13)
    _ = prisme_x


def outil(g, c):
    """Couronne de bronze à la clef de l'arche, trois prismes pointés vers la table, rayon violet."""
    M = g.M
    yt, zt = c.yt, c.zt
    top = c.zp + c.bp
    zc = top - 0.25
    g.torus(B(0, yt, zc), "z", 0.22, 0.04, M["bronze_capot"], n=24, m=8, what="couronne")
    g.cyl(B(0, yt, (zc + top) / 2), "z", 0.04, top - zc, M["bronze_sombre"], n=10, what="tige")
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        x, y = 0.2 * math.cos(a), 0.2 * math.sin(a) / SQ2
        base = B(x, yt + y, zc + 0.02)
        d = (B(0, yt, zt + 0.2) - base).normalized()
        F.crystal(g, base, d, 0.06, 0.34, M["crystal"], n=6)
        g.box(base + V((0, 0, 0.03)), (0.08, 0.08, 0.06), M["bronze_clair"], "hard", what="griffe")
    F.crystal(g, B(0, yt, zc - 0.02), (0, 0, -1), 0.075, 0.42, M["emit_soft"], n=6)
    g.cyl(B(0, yt, (zc - 0.45 + zt + 0.22) / 2), "z", 0.028, zc - 0.45 - zt - 0.22, M["emit"], n=10, what="rayon")
    halo(g, 0, yt, zt + 0.5, 1.4)


def ouvrage(g, c):
    """Gemme taillée sur un support de bronze, éclats de cristal."""
    M = g.M
    yt, zt = c.yt, c.zt
    g.cyl(B(0, yt, zt + 0.06), "z", 0.22, 0.12, M["bronze_sombre"], n=8, style="hard", what="support")
    g.cyl(B(0, yt, zt + 0.14), "z", 0.13, 0.06, M["crystal"], n=8, r2=0.17, style="hard", what="gemme")
    g.cyl(B(0, yt, zt + 0.19), "z", 0.17, 0.04, M["emit_soft"], n=8, r2=0.1, style="hard", what="table_gemme")
    for k in range(6):
        a = 2 * math.pi * k / 6
        F.crystal(g, B(0.4 * math.cos(a), yt + 0.25 * math.sin(a), zt), (0.3 * math.cos(a), 0.3 * math.sin(a), 1), 0.03,
                  0.1, M["crystal"])


def entree(g, c, p):
    """Vasque de pierre pleine de cristaux bruts (entrée)."""
    M = g.M
    g.cyl(B(p["x"], p["yn"], p["z"] + 0.08), "z", p["r"], 0.16, M["pierre_claire"], n=8, r2=p["r"] * 1.1,
          style="hard", what="vasque")
    for k in range(6):
        a = TAU * k / 6
        F.crystal(g, B(p["x"] + 0.35 * p["r"] * math.cos(a), p["yn"] + 0.3 * p["r"] * math.sin(a), p["z"] + 0.14),
                  (0.3 * math.cos(a), 0.3 * math.sin(a), 1), 0.035, 0.14, M["crystal"])


def sortie(g, c, p):
    """Reliquaire de bronze : gemmes taillées violettes (sortie)."""
    corps.bac(g, c, p, g.M["bronze_capot"], g.M["emit_soft"], forme="sphere")


def piece(g, c):
    """Niveau 14 (plus grande) : deux obélisques HAUTS de pierre à pointe de cristal, socle de bronze à degrés, vasque
    de cristaux au pied (coins avant, en retrait du perron)."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        x, yn, z = p["x"], p["yn"] + 0.2, c.ze
        g.box(B(x, yn, z + 0.06), (0.56, 0.56 * SQ2, 0.12), M["bronze_sombre"], "hard", what="socle_obelisque")
        g.box(B(x, yn, z + 0.16), (0.42, 0.42 * SQ2, 0.08), M["pierre_claire2"], "hard", what="degre")
        g.cyl(B(x, yn, z + 0.6), "z", 0.16, 0.8, M["pierre_claire"], n=4, r2=0.1, style="hard", phase=0.785,
              what="obelisque")
        F.crystal(g, B(x, yn, z + 1.0), (0, 0, 1), 0.1, 0.34, M["emit"], n=4)
        g.box(B(x, yn, z + 0.24), (0.36, 0.36 * SQ2, 0.04), M["bronze_capot"], "hard", what="bague")
        for k in range(3):
            g.box(B(x, yn - 0.163, z + 0.38 + 0.15 * k), (0.12, 0.01, 0.04), M["emit_soft"], "flat", what="glyphe")
        halo(g, x, yn, z + 1.1, 1.0)
