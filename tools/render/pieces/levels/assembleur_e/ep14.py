"""Assembleur · Âge 14 · La Porte (ère V, 6×6, niveaux 27 et 28). Lot F3-A, rondes F3-A2 et F3-A3 ; fiche
FICHES_ASSEMBLEUR.md, âge 14. Dans Blender.

En 3 mots : « porte étoilée, ombilicaux, nuit indigo ». Ronde F3-A3 : plan en CROIX (l'octogone indigo à puits étoilé
de la ronde F3-A2 se confondait avec la foreuse de la Porte, ronde, à puits étoilé et arceau, lot F4). La PORTE ÉTOILÉE
est COUCHÉE sur la table de la croisée (puits d'horizon semé d'étoiles, cerclé de blanc lunaire et de chevrons
lumineux) ; une POUTRE blanche d'un bras à l'autre porte la pince qui tient la capsule ; de gros OMBILICAUX noirs à
colliers blancs descendent des bras vers le moyeu de la poutre. Bras nord : hublots d'horizon ; bouts des bras : mâts
relais. Les quatre coins sont du sol (la pièce paire s'y pose).
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
HABILLAGE = dict(ages.CORPS[14], plan='croix', forme_embase='carre', forme_dos='plat', forme_joues='caisson',
                 forme_portique='poutre', mat_portique='blanc_lunaire')
DENSITE = dict(p=0.6, lampes=0.1)


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
    """Hublot d'horizon étoilé sur une face sud (plan yn)."""
    M = g.M
    g.cyl(B(x, yn - 0.02, z), "y", r + 0.04, 0.04, M["blanc_lunaire"], n=20, what="bague_hublot")
    g.cyl(B(x, yn - 0.04, z), "y", r, 0.02, M["horizon_porte"], n=20, what="horizon")
    rng = random.Random(int(abs(x) * 100) + 7)
    for k in range(9):
        rr = r * 0.9 * math.sqrt(rng.random())
        a = rng.random() * TAU
        g.sphere(B(x + rr * math.cos(a), yn - 0.055, z + rr * math.sin(a)), 0.012, M["emit"], n=6, m=4, what="etoile")


def _relais(g, c, x, yn, z):
    """Mât relais : fût blanc, anneau à miroir d'horizon (plein : pas de jour enfermé), feu."""
    M = g.M
    g.box(B(x, yn, z + 0.04), (0.26, 0.26 * SQ2, 0.08), M["noir_spatial"], "hard", what="pied_relais")
    g.cyl(B(x, yn, z + 0.45), "z", 0.035, 0.8, M["blanc_lunaire"], n=8, what="mat_relais")
    g.torus(B(x, yn, z + 0.92), "y", 0.15, 0.024, M["blanc_lunaire"], n=20, m=6, what="anneau_relais")
    g.cyl(B(x, yn + 0.01, z + 0.92), "y", 0.14, 0.02, M["horizon_porte"], n=20, what="miroir_relais")
    corps.lampe(g, B(x, yn, z + 1.09), 0.03, M["emit"])
    halo(g, x, yn - 0.1, z + 1.0, 0.5)
    c.reserves.append((x, yn, 0.2))


def socle(g, c):
    """Hublots du bras nord, mâts relais aux bouts des bras, filets blancs, étoiles semées sur le bâti, ombilicaux."""
    M = g.M
    a, h = c.a, c.h
    zs, Hd, zj = c.zs, c.Hd, c.z_joue
    # hublots d'horizon sur la face sud du bras nord
    for x in (-1.1, -0.37, 0.37, 1.1):
        _hublot(g, x, c.yb, (zs + Hd) / 2 + 0.05, 0.2)
    halo(g, 0, c.yb - 0.35, (zs + Hd) / 2, 1.0)
    g.box(B(0, c.yb - 0.03, zs + 0.08), (2 * a - 0.1, 0.03, 0.04), M["emit_soft"], "flat", what="filet_blanc")
    # mâts relais : bout du bras nord, bouts des bras est et ouest (moitié sud : l'entrée et la sortie sont au nord)
    _relais(g, c, 0.0, h - 0.3, Hd)
    for sx in (-1, 1):
        _relais(g, c, sx * (h - 0.3), -1.15, zj)
    # étoiles semées sur le bâti autour de la table
    rng = random.Random(14)
    for k in range(40):
        x = (rng.random() * 2 - 1) * (a - 0.1)
        y = -h + 0.3 + rng.random() * (h - 0.3 - 1.1)
        g.sphere(B(x, y, zs + 0.02), 0.012 + 0.01 * rng.random(), M["emit"], n=6, m=4, what="etoile_sol")
    # ombilicaux : du bras nord et des bras est et ouest au moyeu de la poutre
    hub = B(0, c.yt, c.zp)
    for (p0, sx) in ((B(-0.5, c.yb + 0.3, Hd + 0.05), -1), (B(0.5, c.yb + 0.3, Hd + 0.05), 1),
                     (B(-(a + 0.35), -0.6, zj + 0.05), -1), (B(a + 0.35, -0.6, zj + 0.05), 1)):
        p2 = hub + V((sx * 0.22, 0, 0.0))
        p1 = p0.lerp(p2, 0.5) - V((0, 0, 0.3))
        g.hose([p0, p1, p2], 0.07, M["noir_spatial"], step=0.08, n=12)
        g.cyl(p0 + V((0, 0, 0.04)), "z", 0.11, 0.08, M["blanc_lunaire"], n=14, what="prise")
        for f in (0.25, 0.5, 0.75):
            q = p0.lerp(p1, f * 2) if f < 0.5 else p1.lerp(p2, (f - 0.5) * 2)
            g.sphere(q, 0.085, M["blanc_lunaire"], n=12, m=6, scale=(1, 1, 0.6), what="collier")
        c.reserves.append(((p0.x), p0.y / SQ2, 0.16))


def outil(g, c):
    """Moyeu sous la poutre, pince qui pend (câbles, palonnier, griffes blanches) et tient la capsule."""
    M = g.M
    hub = B(0, c.yt, c.zp)
    g.box(hub - V((0, 0, 0.06)), (0.5, 0.36 * SQ2, 0.14), M["noir_spatial"], "hard", what="moyeu")
    corps.lampe(g, hub - V((0, 0.26, 0.06)), 0.03, M["emit"])
    zc = c.zt + 0.55
    pc = B(0, c.yt, zc)
    g.box(hub - V((0, 0, 0.24)), (0.5, 0.18, 0.08), M["blanc_lunaire"], "hard", what="palonnier")
    for sx in (-1, 1):
        g.cable(hub - V((sx * 0.22, 0, 0.28)), pc + V((sx * 0.18, 0, 0.3)), 0.02, 0.015, M["noir_spatial"])
        g.tube([pc + V((sx * 0.18, 0, 0.3)), pc + V((sx * 0.24, 0, 0.12)), pc + V((sx * 0.17, 0, -0.05))], 0.03,
               M["blanc_lunaire"], n=8, what="griffe")


def ouvrage(g, c):
    """Puits de la Porte couché sur la table (horizon étoilé, liseré, chevrons) et capsule qui en sort."""
    M = g.M
    zt = c.zt
    ctr = B(0, c.yt, zt + 0.01)
    R = c.T["table"]["ty"] * 0.92
    g.cyl(ctr, "z", R, 0.03, M["horizon_porte"], n=48, what="puits")
    _etoiles_disque(g, ctr + V((0, 0, 0.015)), R - 0.05, 90, 7)
    g.torus(ctr + V((0, 0, 0.03)), "z", R + 0.03, 0.05, M["blanc_lunaire"], n=56, m=10, what="bord_porte")
    F.lit_ring(g, ctr + V((0, 0, 0.05)), "z", R - 0.01, M["emit_soft"], w=0.035, t=0.015)
    for k in range(12):
        an = TAU * k / 12
        g.box(ctr + V(((R + 0.03) * math.cos(an), (R + 0.03) * math.sin(an), 0.09)), (0.06, 0.06, 0.03), M["emit"],
              "flat", R=Matrix.Rotation(an, 3, "Z"), what="chevron")
    halo(g, 0, c.yt, zt + 0.3, 1.6)
    # capsule blanche à bandes indigo, à moitié sortie, penchée
    pc = B(0, c.yt, zt + 0.42)
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
    """Niveau 28 (plus grande) : conteneurs de fret blancs à bandes indigo empilés et mât relais, sur le SOL des coins
    avant de la croix."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        # rendu a4 : pile collée au bras sud (un jour de sol entre elle et le bras faisait une poche de 17 px)
        sgn = 1 if p["x"] > 0 else -1
        x, yn, z = p["x"] - sgn * 0.19, p["yn"], p["z_sol"]
        for k, (dx, dz, w) in enumerate(((-0.19, 0.0, 0.38), (0.2, 0.0, 0.34), (0.0, 0.38, 0.46))):
            g.box(B(x + dx, yn, z + dz + 0.19), (w, 0.52 * SQ2, 0.36), M["blanc_lunaire"], "soft", what="conteneur")
            g.box(B(x + dx, yn - 0.26 - 0.004, z + dz + 0.19), (w * 0.9, 0.01, 0.07), M["indigo_nuit"], "flat",
                  what="bande")
            corps.lampe_face(g, x + dx + w * 0.35, yn - 0.26, z + dz + 0.31, 0.022, M["emit"], M["noir_spatial"])
        # mât SORTANT du conteneur du haut (contrôle d'îlots a3 : un mât à côté laissait une poche fermée)
        g.cyl(B(x + 0.12, yn + 0.1, z + 0.75), "z", 0.028, 1.5, M["blanc_lunaire"], n=8, what="mat")
        g.torus(B(x + 0.12, yn + 0.1, z + 1.5), "y", 0.12, 0.02, M["blanc_lunaire"], n=16, m=5, what="anneau")
        g.cyl(B(x + 0.12, yn + 0.11, z + 1.5), "y", 0.11, 0.02, M["horizon_porte"], n=16, what="miroir")
        corps.lampe(g, B(x + 0.12, yn + 0.1, z + 1.64), 0.03, M["emit"])
        halo(g, x, yn - 0.3, z + 0.5, 0.6)
