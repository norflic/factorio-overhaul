"""Assembleur · Âge 14 · La Porte (ère V, 6×6, niveaux 27 et 28). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge 14. Dans
Blender.

En 3 mots : « porte étoilée, ombilicaux, nuit indigo ». Aucun portique : une PORTE ÉTOILÉE se dresse face au sud
au-dessus de la table (anneau blanc lunaire à chevrons, horizon de nuit semé d'étoiles, liseré blanc) ; la pièce en
sort sur un berceau. De gros OMBILICAUX noirs à colliers blancs la relient au dos. Dos et joues en NUIT INDIGO, hublots
d'horizon étoilé sur la face, mâts relais sur le toit, étoiles semées sur le sol de tôles.
Palette 60/30/10 (ages.PALETTE[14]) : indigo de nuit / blanc lunaire / blanc d'étoile en points ; ni or ni orange.
"""
import math
import random

from mathutils import Vector

import ages
import corps
import formes as F
from corps import B, halo
from kit import SQ2, TAU

V = Vector

EPOQUE = 14
NOM = ages.NOMS[14]
TRIPLET = ("porte étoilée", "ombilicaux", "nuit indigo")
FOYER = ages.FOYER[14]
TRAVAIL = dict(couches=2, images=24, organe="étoiles de l'horizon qui tournent lentement autour du centre de la Porte "
                                           "(24 images) et berceau qui sort ; liseré qui pulse (couche glow)")
HABILLAGE = dict(ages.CORPS[14], forme_embase='chanfrein', forme_dos='plat', forme_joues='pente',
                 forme_portique='aucun', mat_dos='indigo_nuit')


def matieres(metal, M):
    ages.matieres(14, metal, M)


def _etoiles(g, ctr, rmax, n, seed, y_off=-0.02):
    """Étoiles (points lumineux) semées sur un disque du plan XZ centré en ctr (face au sud)."""
    M = g.M
    rng = random.Random(seed)
    for k in range(n):
        r = rmax * math.sqrt(rng.random())
        a = rng.random() * TAU
        s = 0.012 + 0.016 * rng.random() ** 3
        g.sphere(ctr + V((r * math.cos(a), y_off, r * math.sin(a))), s, M["emit"], n=6, m=4, what="etoile")


def _hublot(g, x, yn, z, r):
    M = g.M
    g.cyl(B(x, yn - 0.02, z), "y", r + 0.04, 0.04, M["blanc_lunaire"], n=20, what="bague_hublot")
    g.cyl(B(x, yn - 0.04, z), "y", r, 0.02, M["horizon_porte"], n=20, what="horizon")
    _etoiles(g, B(x, yn - 0.055, z), r * 0.9, 9, int(x * 100) % 97)


def socle(g, c):
    M = g.M
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    ym = (yb + h) / 2.0
    # hublots d'horizon étoilé et filets blancs sur la face
    ze = c.zs           # troisième jet : sol de la baie = dessus du plateau
    for x in (-1.25, -0.6, 0.6, 1.25):
        _hublot(g, x, yb, (ze + Hd) / 2 + 0.05, 0.2)
    for z in (ze + 0.1, Hd - 0.08):
        g.box(B(0, yb - 0.03, z), (2 * h - 0.1, 0.03, 0.04), M["blanc_lunaire"], "hard", what="filet")
    halo(g, 0, yb - 0.3, (ze + Hd) / 2, 1.0, rgb=M["_emit_rgb"])
    # mâts relais et anneaux sur le toit
    for x in (-2.0, 0.0, 2.0):
        g.cyl(B(x, ym, Hd + 0.3), "z", 0.03, 0.6, M["blanc_lunaire"], n=8, what="mat_relais")
        g.torus(B(x, ym, Hd + 0.62), "y", 0.12, 0.02, M["blanc_lunaire"], n=20, m=6, what="anneau_relais")
        corps.lampe(g, B(x, ym, Hd + 0.75), 0.03, M["emit"])
    # étoiles semées sur le sol de la baie et sur les joues
    rng = random.Random(14)
    for k in range(40):
        x = (rng.random() - 0.5) * 2 * c.xb
        yn = -h + 0.1 + rng.random() * (c.yb - 0.2 + h)
        if abs(x) < c.T["table"]["tx"] + 0.1 and abs(yn - c.yt) < c.T["table"]["ty"] + 0.1:
            continue
        g.sphere(B(x, yn, ze + 0.03), 0.012 + 0.01 * rng.random(), M["emit"], n=6, m=4, what="etoile_sol")
    # ombilicaux du dos vers la Porte
    for sx in (-1, 1):
        p0 = B(sx * 0.95, yb - 0.05, ze + 0.5)
        p1 = B(sx * 1.05, (yb + c.yt) / 2, ze + 0.12)
        p2 = B(sx * 0.95, c.yt + 0.15, c.zt + 0.6)
        g.hose([p0, p1, p2], 0.07, M["noir_spatial"], step=0.08, n=12)
        for f in (0.25, 0.55, 0.85):
            q = p0.lerp(p1, f) if f < 0.5 else p1.lerp(p2, (f - 0.5) * 2)
            g.sphere(q, 0.085, M["blanc_lunaire"], n=12, m=6, scale=(1, 1, 0.6), what="collier")


def outil(g, c):
    """Porte étoilée face au sud : anneau blanc lunaire à chevrons, horizon semé d'étoiles, liseré, pieds."""
    M = g.M
    yt, zt = c.yt, c.zt
    R = 0.9
    ctr = B(0, yt + 0.2, zt + R + 0.12)
    g.torus(ctr, "y", R, 0.12, M["blanc_lunaire"], n=56, m=12, what="porte")
    g.cyl(ctr + V((0, 0.03, 0)), "y", R - 0.06, 0.04, M["horizon_porte"], n=48, what="horizon")
    F.lit_ring(g, ctr - V((0, 0.03, 0)), "y", R - 0.05, M["emit_soft"], w=0.035, t=0.02)
    _etoiles(g, ctr, R - 0.12, 70, 7, y_off=-0.025)
    for k in range(9):
        a = math.pi * (0.1 + 0.8 * k / 8)
        p = ctr + V((R * math.cos(a) * 1.0, -0.12, R * math.sin(a)))
        g.box(p, (0.07, 0.03, 0.1), M["emit"], "flat", what="chevron")
    for sx in (-1, 1):
        g.box(B(sx * (R + 0.05), yt + 0.2, (c.zs + ctr.z - R * 0.6) / 2), (0.18, 0.3 * SQ2, ctr.z - R * 0.6 - c.zs),
              M["indigo_nuit2"], "hard", what="pied_porte")
        g.box(B(sx * (R + 0.05), yt + 0.2, ctr.z - R * 0.6), (0.24, 0.34 * SQ2, 0.06), M["blanc_lunaire"], "hard",
              what="chapeau_pied")
    halo(g, 0, yt, zt + R, 1.8)


def ouvrage(g, c):
    """Capsule blanche qui sort de la Porte sur un berceau à rails."""
    M = g.M
    yt, zt = c.yt, c.zt
    for sx in (-1, 1):
        g.box(B(sx * 0.2, yt - 0.1, zt + 0.02), (0.05, 0.9 * SQ2, 0.04), M["blanc_lunaire"], "hard", what="rail")
    g.box(B(0, yt - 0.1, zt + 0.07), (0.5, 0.42 * SQ2, 0.06), M["noir_spatial"], "hard", what="berceau")
    g.cyl(B(0, yt - 0.12, zt + 0.22), "y", 0.15, 0.42 * SQ2, M["blanc_lunaire"], n=24, what="capsule")
    g.sphere(B(0, yt - 0.42, zt + 0.22), 0.15, M["blanc_lunaire"], n=20, m=10, scale=(1, 0.8, 1), what="nez")
    for f in (-0.1, 0.1):
        g.tube_shell(B(0, yt - 0.12 + f, zt + 0.22), "y", 0.158, 0.14, 0.04, M["indigo_nuit"], n=24, what="bande")


def piece(g, c):
    """Niveau 28 : conteneurs de fret blancs à bandes indigo, empilés (coins avant)."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        x, yn, z = p["x"], p["yn"] + 0.05, p["z_sol"]
        for k, (dx, dz, w) in enumerate(((-0.17, 0.0, 0.36), (0.2, 0.0, 0.32), (0.0, 0.34, 0.4))):
            g.box(B(x + dx, yn, z + dz + 0.17), (w, 0.5 * SQ2, 0.32), M["blanc_lunaire"], "soft", what="conteneur")
            g.box(B(x + dx, yn - 0.25 - 0.004, z + dz + 0.17), (w * 0.9, 0.01, 0.06), M["indigo_nuit"], "flat",
                  what="bande")
            corps.lampe_face(g, x + dx + w * 0.35, yn - 0.25, z + dz + 0.28, 0.02, M["emit"], M["noir_spatial"])
        halo(g, x, yn - 0.3, z + 0.4, 0.4)
