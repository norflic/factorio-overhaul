"""Assembleur · Âge 14 · La Porte (ère V, 6×6, niveaux 27 et 28). Lot F3-A, ronde F3-A2 ; fiche FICHES_ASSEMBLEUR.md, âge
14. Dans Blender.

En 3 mots : « porte étoilée, ombilicaux, nuit indigo ». Plan OCTOGONAL : tambour de NUIT INDIGO, croissant à hublots
d'horizon étoilé, mâts relais. Au centre, la PORTE ÉTOILÉE est COUCHÉE dans le lit (un puits d'horizon semé d'étoiles,
cerclé de blanc lunaire et de chevrons lumineux) : la capsule en sort, tenue par une pince qui pend du moyeu ; de gros
OMBILICAUX noirs à colliers blancs relient le croissant au moyeu. (Le four de la Porte a un anneau DRESSÉ : ici, il est
couché.)
Palette 60/30/10 (ages.PALETTE[14]) : indigo de nuit / blanc lunaire / blanc d'étoile en points ; ni or ni orange.
"""
import math
import random

from mathutils import Matrix, Vector

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
TRAVAIL = dict(couches=2, images=24, organe="étoiles du puits qui tournent autour du centre (24 images), capsule qui "
                                           "monte ; chevrons et liseré qui pulsent (couche glow)")
HABILLAGE = dict(ages.CORPS[14], plan='octo', forme_embase='carre', forme_dos='plat', forme_joues='caisson',
                 forme_portique='aucun')
DENSITE = dict(p=0.55, lampes=0.08)


def matieres(metal, M):
    ages.matieres(14, metal, M)


def _etoiles_disque(g, ctr, rmax, n, seed, z_off=0.012):
    """Étoiles sur un disque HORIZONTAL (Blender) centré en ctr."""
    M = g.M
    rng = random.Random(seed)
    for k in range(n):
        r = rmax * math.sqrt(rng.random())
        a = rng.random() * TAU
        s = 0.012 + 0.016 * rng.random() ** 3
        g.sphere(ctr + V((r * math.cos(a), r * math.sin(a), z_off)), s, M["emit"], n=6, m=4, what="etoile")


def _hublot(g, x, yn, z, r):
    M = g.M
    g.cyl(B(x, yn - 0.02, z), "y", r + 0.04, 0.04, M["blanc_lunaire"], n=20, what="bague_hublot")
    g.cyl(B(x, yn - 0.04, z), "y", r, 0.02, M["horizon_porte"], n=20, what="horizon")
    rng = random.Random(int(abs(x) * 100) + 7)
    for k in range(9):
        rr = r * 0.9 * math.sqrt(rng.random())
        a = rng.random() * TAU
        g.sphere(B(x + rr * math.cos(a), yn - 0.055, z + rr * math.sin(a)), 0.012, M["emit"], n=6, m=4, what="etoile")


def socle(g, c):
    """Hublots étoilés du croissant, mâts relais, étoiles semées sur le tambour, filets blancs."""
    M = g.M
    Rd = c.Rb - 0.06
    R0 = Rd - c.ep_cr
    for ad in (50, 75, 105, 130):
        a = math.radians(ad)
        _hublot(g, (R0 - 0.02) * math.cos(a), (R0 - 0.02) * math.sin(a), (c.zr + c.Hc) / 2 + 0.1, 0.2)
    halo(g, 0, R0 - 0.3, (c.zr + c.Hc) / 2, 1.0)
    Rm = (R0 + Rd) / 2.0
    for ad in (35, 90, 145):
        a = math.radians(ad)
        x, y = Rm * math.cos(a), Rm * math.sin(a)
        g.cyl(B(x, y, c.Hc + 0.35), "z", 0.035, 0.7, M["blanc_lunaire"], n=8, what="mat_relais")
        g.torus(B(x, y, c.Hc + 0.72), "y", 0.14, 0.022, M["blanc_lunaire"], n=20, m=6, what="anneau_relais")
        g.cyl(B(x, y + 0.01, c.Hc + 0.72), "y", 0.13, 0.02, M["horizon_porte"], n=20, what="miroir_relais")
        corps.lampe(g, B(x, y, c.Hc + 0.88), 0.03, M["emit"])
        c.reserves.append((x, y, 0.2))
    rng = random.Random(14)
    for k in range(60):
        a = math.radians(200 + 140 * rng.random())
        r = c.tr + 0.15 + (Rd - c.tr - 0.2) * rng.random()
        x, y = r * math.cos(a), r * math.sin(a)
        z = c.Ha if r > Rd - c.ep_an else c.zr
        g.sphere(B(x, y, z + 0.02), 0.012 + 0.01 * rng.random(), M["emit"], n=6, m=4, what="etoile_sol")
    # ombilicaux du croissant au moyeu
    for sx in (-1, 1):
        a = math.radians(90 + sx * 40)
        p0 = B((R0 + 0.15) * math.cos(a), (R0 + 0.15) * math.sin(a), c.Hc + 0.05)
        p2 = c.hub + V((sx * 0.2, 0, -0.05))
        p1 = p0.lerp(p2, 0.5) - V((0, 0, 0.35))
        g.hose([p0, p1, p2], 0.08, M["noir_spatial"], step=0.08, n=12)
        for f in (0.25, 0.5, 0.75):
            q = p0.lerp(p1, f * 2) if f < 0.5 else p1.lerp(p2, (f - 0.5) * 2)
            g.sphere(q, 0.095, M["blanc_lunaire"], n=12, m=6, scale=(1, 1, 0.6), what="collier")


def outil(g, c):
    """Pince qui pend du moyeu (câbles, palonnier, griffes blanches) et tient la capsule."""
    M = g.M
    zc = c.zt + 0.55
    pc = B(0, c.cy, zc)
    g.box(c.hub - V((0, 0, 0.2)), (0.5, 0.18, 0.08), M["blanc_lunaire"], "hard", what="palonnier")
    for sx in (-1, 1):
        g.cable(c.hub - V((sx * 0.22, 0, 0.24)), pc + V((sx * 0.18, 0, 0.3)), 0.02, 0.015, M["noir_spatial"])
        g.tube([pc + V((sx * 0.18, 0, 0.3)), pc + V((sx * 0.24, 0, 0.12)), pc + V((sx * 0.17, 0, -0.05))], 0.03,
               M["blanc_lunaire"], n=8, what="griffe")
    corps.lampe(g, c.hub - V((0, 0.12, 0.2)), 0.03, M["emit"])


def ouvrage(g, c):
    """Puits de la Porte couché dans le lit (horizon étoilé, liseré, chevrons) et capsule qui en sort."""
    M = g.M
    zt = c.zt
    ctr = B(0, c.cy, zt + 0.01)
    R = c.tr - 0.06
    g.cyl(ctr, "z", R, 0.03, M["horizon_porte"], n=48, what="puits")
    _etoiles_disque(g, ctr + V((0, 0, 0.015)), R - 0.05, 90, 7)
    g.torus(ctr + V((0, 0, 0.03)), "z", R + 0.03, 0.05, M["blanc_lunaire"], n=56, m=10, what="bord_porte")
    F.lit_ring(g, ctr + V((0, 0, 0.05)), "z", R - 0.01, M["emit_soft"], w=0.035, t=0.015)
    for k in range(12):
        a = TAU * k / 12
        g.box(ctr + V(((R + 0.03) * math.cos(a), (R + 0.03) * math.sin(a), 0.09)), (0.06, 0.06, 0.03), M["emit"],
              "flat", R=Matrix.Rotation(a, 3, "Z"), what="chevron")
    halo(g, 0, c.cy, zt + 0.3, 1.6)
    # capsule blanche à bandes indigo, à moitié sortie, penchée
    pc = B(0, c.cy, zt + 0.42)
    R3 = Matrix.Rotation(0.35, 3, "X")
    ax = R3 @ V((0, 0, 1))
    g.cyl(pc, ax, 0.17, 0.5, M["blanc_lunaire"], n=24, what="capsule")
    g.sphere(pc + ax * 0.25, 0.17, M["blanc_lunaire"], n=20, m=10, what="nez")
    for f in (-0.12, 0.08):
        g.tube_shell(pc + ax * f, ax, 0.178, 0.16, 0.04, M["indigo_nuit"], n=24, what="bande")


def entree(g, c, p):
    """Caisson de fret lunaire ouvert : météorites (entrée)."""
    M = g.M
    corps.bac(g, c, p, M["blanc_lunaire"], M["roche"], forme="sphere")


def sortie(g, c, p):
    """Berceau noir : capsules finies à bandes indigo (sortie)."""
    M = g.M
    g.box(B(p["x"], p["yn"], p["z"] + 0.05), (2 * p["r"], 1.4 * p["r"] * SQ2, 0.1), M["noir_spatial"], "hard",
          what="berceau")
    for s in (-1, 1):
        q = B(p["x"] + s * p["r"] * 0.45, p["yn"], p["z"] + 0.18)
        g.cyl(q, "y", 0.08, 1.2 * p["r"] * SQ2, M["blanc_lunaire"], n=16, what="capsule")
        g.tube_shell(q, "y", 0.085, 0.07, 0.03, M["indigo_nuit"], n=16, what="bande")


def piece(g, c):
    """Niveau 28 (plus grande, hors du tambour) : conteneurs de fret blancs à bandes indigo empilés et mât relais (coins
    avant)."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        x, yn, z = p["x"], p["yn"], p["z_sol"]
        for k, (dx, dz, w) in enumerate(((-0.17, 0.0, 0.34), (0.19, 0.0, 0.3), (0.0, 0.34, 0.4))):
            g.box(B(x + dx, yn, z + dz + 0.17), (w, 0.48 * SQ2, 0.32), M["blanc_lunaire"], "soft", what="conteneur")
            g.box(B(x + dx, yn - 0.24 - 0.004, z + dz + 0.17), (w * 0.9, 0.01, 0.06), M["indigo_nuit"], "flat",
                  what="bande")
            corps.lampe_face(g, x + dx + w * 0.35, yn - 0.24, z + dz + 0.28, 0.02, M["emit"], M["noir_spatial"])
        g.cyl(B(x + 0.25, yn + 0.2, z + 0.55), "z", 0.025, 1.1, M["blanc_lunaire"], n=8, what="mat")
        g.torus(B(x + 0.25, yn + 0.2, z + 1.1), "y", 0.1, 0.018, M["blanc_lunaire"], n=16, m=5, what="anneau")
        g.cyl(B(x + 0.25, yn + 0.21, z + 1.1), "y", 0.09, 0.02, M["horizon_porte"], n=16, what="miroir")
        halo(g, x, yn - 0.3, z + 0.4, 0.5)
