"""Assembleur · Âge 1 · Pionnier (ère I, 3×3, niveaux 1 et 2). Kit assembleur_e (lot F3-A). S'exécute DANS Blender.

Le niveau 1 est l'ASSEMBLEUR 2 VANILLA, jamais retouché ; ce module ne fournit que la pièce du niveau 2 (variante
e01-piece), posée PAR-DESSUS le vanilla aux deux coins AVANT (une pièce dessinée dessous serait cachée, F42). Foyer de
NUIT seulement (lanterne). En 3 mots : « caisses clouées, établi, rouleaux de fil » : au coin avant gauche un ÉTABLI de
bois (étau, marteau, clé, boîte de vis), au coin avant droit une pile de CAISSES CLOUÉES et deux ROULEAUX DE FIL de
cuivre (tourets de bois), une lanterne pendue. Fiche : fo-logs/2026-10-25_F3/FICHES_ASSEMBLEUR.md, âge 1.
"""
import math

from mathutils import Matrix

import ages
import corps
import formes as F
from corps import B
from kit import SQ2

EPOQUE = 1
NOM = ages.NOMS[1]
TRIPLET = ("caisses clouées", "établi", "rouleaux de fil")
FOYER = ages.FOYER[1]
TRAVAIL = dict(couches=0, images=0, organe="aucune (le niveau 2 garde l'animation du vanilla ; la pièce est fixe)")


def _etabli(g, x, yn, z, w, d):
    M = g.M
    hp = 0.24
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.box(B(x + sx * (w / 2 - 0.03), yn + sy * (d / 2 - 0.03), z + hp / 2), (0.04, 0.04 * SQ2, hp), M["wood2"],
                  "hard", what="pied")
    g.box(B(x, yn, z + hp + 0.02), (w, d * SQ2, 0.04), M["wood"], "hard", what="plateau")
    g.box(B(x, yn, z + 0.07), (w * 0.9, d * SQ2 * 0.9, 0.02), M["wood2"], "hard", what="tablette")
    # étau, marteau, clé, boîte de vis, planche
    g.box(B(x - w * 0.3, yn - d * 0.25, z + hp + 0.08), (0.08, 0.06 * SQ2, 0.08), M["blackiron"], "hard", what="etau")
    g.cyl(B(x - w * 0.3, yn - d * 0.38, z + hp + 0.1), "y", 0.012, 0.12, M["steel_hi"], n=6, what="vis_etau")
    g.box(B(x + w * 0.1, yn, z + hp + 0.055), (0.16, 0.02 * SQ2, 0.016), M["wood2"], "hard",
          R=Matrix.Rotation(0.5, 3, "Z"), what="manche")
    g.box(B(x + w * 0.1 + 0.06, yn + 0.04, z + hp + 0.06), (0.03, 0.06 * SQ2, 0.03), M["blackiron"], "hard",
          what="marteau")
    g.box(B(x + w * 0.28, yn + d * 0.2, z + hp + 0.065), (0.08, 0.06 * SQ2, 0.05), M["redpaint"], "hard", what="boite")
    g.box(B(x + w * 0.05, yn - d * 0.3, z + hp + 0.05), (0.2, 0.05 * SQ2, 0.012), M["steel"], "hard",
          R=Matrix.Rotation(-0.3, 3, "Z"), what="cle")
    corps.caisse(g, None, x - w * 0.25, yn + d * 0.05, z + 0.08, 0.1, M["wood2"])


def _touret(g, x, yn, z, r, w):
    """Rouleau de fil de cuivre sur touret de bois couché (axe est-ouest)."""
    M = g.M
    for s in (-1, 1):
        g.cyl(B(x + s * w / 2, yn, z + r), "x", r, 0.025, M["wood"], n=18, style="hard", what="joue_touret")
    g.cyl(B(x, yn, z + r), "x", r * 0.78, w - 0.02, M["copper"], n=18, what="fil")
    for k in range(5):
        g.torus(B(x - w / 2 + 0.03 + (w - 0.06) * k / 4, yn, z + r), "x", r * 0.78, 0.008, M["copper_pol"], n=18, m=4,
                what="spire")


def piece(g, c):
    """Niveau 2 : établi au coin avant gauche, caisses clouées et rouleaux de fil au coin avant droit, lanterne."""
    M = g.M
    po, pe = corps.place(c, "coin_SO"), corps.place(c, "coin_SE")
    z = 0.0
    _etabli(g, po["x"] + 0.02, po["yn"] + 0.02, z, 0.5, 0.34)
    x, yn = pe["x"], pe["yn"]
    corps.caisse(g, c, x + 0.08, yn + 0.08, z, 0.24, M["wood"])
    corps.caisse(g, c, x + 0.1, yn + 0.1, z + 0.25, 0.18, M["wood2"])
    corps.caisse(g, c, x - 0.16, yn + 0.12, z, 0.18, M["wood2"])
    _touret(g, x - 0.12, yn - 0.16, z, 0.1, 0.16)
    _touret(g, x + 0.17, yn - 0.18, z, 0.08, 0.13)
    # planches appuyées et sacs
    for k in range(3):
        g.box(B(x - 0.28 + 0.03 * k, yn + 0.22, z + 0.16), (0.05, 0.02 * SQ2, 0.32), M["wood"], "hard",
              R=Matrix.Rotation(0.18, 3, "X"), what="planche")
    F.lantern(g, tuple(B(po["x"] + 0.2, po["yn"] - 0.1, 0.27)), M["emit"])
    g.halo(tuple(B(po["x"] + 0.2, po["yn"] - 0.1, 0.36)), M["_emit_rgb"], 6.0)
    F.lantern(g, tuple(B(x + 0.1, yn + 0.1, 0.43)), M["emit"])
    g.halo(tuple(B(x + 0.1, yn + 0.1, 0.52)), M["_emit_rgb"], 4.0)
