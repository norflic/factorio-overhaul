"""Laser · Âge 6 · Électricité (ère II, 3×3, niveaux 11 et 12). Lot F1-B (25/10) ; fiche :
fo-logs/2026-10-24_F1/FICHES_LASER.md, âge 6 (fait foi). S'exécute DANS Blender.

En 3 mots : « bobine Tesla, tore, isolateurs ». L'émetteur est une BOBINE TESLA COURTE couchée dans l'axe (cuivre poli
bobiné, flasques de bakélite), coiffée d'un TORE HORIZONTAL de porcelaine (posé à plat, comme le chapeau d'une vraie
bobine Tesla : aucune cheminée), un bec isolant porte la BOULE électrode, des ARCS bleus courent du tore à la boule. Affût
en DYNAMO : roue dentée bleue à 12 dents (3 gradins droits), 12 PILES D'ISOLATEURS de porcelaine à petite bobine sur les
dents, couronne d'isolateurs sur l'arête du dernier gradin, barres de cuivre, interrupteurs à couteau, transformateurs
bleus aux coins arrière, fils nus.
Palette 60/30/10 (ages.PALETTE[6]) : porcelaine blanche / bleu électrique (bleu machine, fonte bleue) / porcelaine des
isolateurs ; cuivre poli des bobines ; arcs bleus.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import epoques as E_
import formes as F
import orne as O
import parts as PT
from kit import SQ2, TAU
from repere import Y, at

V = Vector

EPOQUE = 6
NOM = ages.NOMS[6]
TRIPLET = ("bobine Tesla", "tore", "isolateurs")
FOYER = ages.FOYER[6]
FAISCEAU = dict(rgb=(0.55, 0.8, 1.0), rgb2=(0.25, 0.55, 1.0), forme="ÉCLAIR ramifié bleu-blanc (pas un trait droit)",
                largeur=1.0)
HABILLAGE = dict(ages.CORPS[6], **E_.MAQUETTES[6])
# ronde 1 (F1-B) : avec les flancs « bleu machine » de la maquette, le socle se lisait BLEU au zoom 1, contre la palette
# 60/30/10 de l'âge (porcelaine blanche dominante, bleu en second) : flancs de porcelaine à plaques bleues (même
# silhouette ; matière seulement, écart dit ici)
HABILLAGE["forme_affut"] = dict(HABILLAGE["forme_affut"], flanc="porcelaine_capot", flanc2="bleu_machine")


def matieres(metal, M):
    ages.matieres(6, metal, M)
    M["accent"] = M["porcelaine"]
    # spires sombres des bobines (cuivre verni, plus sombre que le cuivre poli : les spires se lisent au zoom 1)
    metal("cuivre_spire", (0.26, 0.09, 0.035), rough=0.35, met=0.5, grain=0.2, gscale=60.0, dirt=0.5, stain=0.3)


def liaison(g, pts, r):
    """Fil de cuivre nu tendu, isolateur de porcelaine à chaque bout."""
    M = g.M
    p0, p1 = V(pts[0]), V(pts[-1])
    g.cable(p0, p1, 0.04, max(0.014, r * 0.45), M["copper_pol"], n=6, what="fil_nu")
    for p in (p0, p1):
        g.cyl(p, "z", 0.026, 0.04, M["porcelaine"], n=10, style="soft", what="isolateur")


def _bobine(g, x, y, z, r, h, M):
    """Petite bobine de cuivre bobiné (fût, spires, flasques de bakélite)."""
    g.cyl((x, y, z + h / 2), "z", r, h, M["copper_pol"], n=16, style="soft", what="bobine")
    for k in range(4):
        g.tube_shell((x, y, z + h * (0.2 + 0.2 * k)), "z", r + 0.006, r - 0.01, 0.01, M["cuivre_spire"], n=16,
                     what="spire")
    for f in (0.0, 1.0):
        g.cyl((x, y, z + h * f), "z", r * 1.25, 0.018, M["bakelite"], n=16, style="hard", what="flasque")


def condensateur(g, c, x, y, z, r, h):
    """Pile d'isolateurs de porcelaine sur semelle bleue, petite bobine de cuivre au sommet, couronne bleue."""
    M = g.M
    zt = F.post_insulator(g, (x, y, z), 4, r * 0.75, h=h * 0.15, base=M["fonte_bleue"])
    _bobine(g, x, y, zt, r * 0.55, h * 0.28, M)
    g.tube_shell((x, y, zt + h * 0.3), "z", r * 0.5, r * 0.32, 0.014, M["emit_soft"], n=16, what="couronne_lum")


def _armoire(g, k, h):
    """Boîtier de commande de bakélite sur le flanc : voyant bleu, manette, plaque de porcelaine."""
    M = g.M
    g.box((0, 0, 0.03), (0.16, h * 0.62, 0.06), M["bakelite"], "soft", what="boitier")
    g.box((0, h * 0.18, 0.062), (0.12, h * 0.12, 0.006), M["porcelaine"], "flat", what="plaque")
    O.lampe(g, (-0.04, -h * 0.1, 0.06), (0, 0, 1), 0.02, M["emit"], M["fonte_bleue"])
    g.box((0.04, -h * 0.1, 0.075), (0.015, 0.05, 0.015), M["copper_pol"], "hard", R=Matrix.Rotation(0.5, 3, "Z"),
          what="manette")


def _couteau(g, k, w):
    """Interrupteur à couteau sur le dessus : socle de porcelaine, deux lames de cuivre, poignée de bakélite."""
    M = g.M
    g.box((0, 0, 0.012), (min(0.16, w * 0.8), 0.12, 0.024), M["porcelaine"], "soft", what="socle_couteau")
    for s in (-1, 1):
        g.box((0.0, s * 0.03, 0.05), (0.1, 0.012, 0.012), M["copper_pol"], "hard", R=Matrix.Rotation(-0.6, 3, "Y"),
              what="lame")
    g.box((0.04, 0.0, 0.085), (0.02, 0.08, 0.02), M["bakelite"], "hard", what="poignee")


def _petit_isolateur(g, k, w):
    PT.insulators(g, (0, 0, 0.0), 2, 0.03, h=0.03)


def socle(g, c):
    """Barres de cuivre sur colliers de porcelaine, boîtiers de commande, couronne d'isolateurs sur le dernier gradin,
    interrupteurs à couteau, transformateurs bleus à ailettes aux coins arrière, fils nus vers le pivot."""
    M = g.M
    zp = c.gradins[-1][3]
    O.ceinture(g, c, 0, 0.3, 0.014, M["copper_pol"], colliers=M["porcelaine"], pas=0.3)
    O.ceinture(g, c, 0, 0.62, 0.014, M["copper_pol"], colliers=M["porcelaine"], pas=0.3)
    O.ceinture(g, c, 1, 0.5, 0.012, M["copper_pol"], colliers=M["porcelaine"], pas=0.28)
    O.rivets_flanc(g, c, 2, 0.6, M["copper_pol"], pas=0.1, r=0.011)
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (210, 270, 330)], _armoire, f=0.5, dr=0.02)
    O.sur_dessus(g, c, 1, [math.radians(a) for a in (200, 236, 304, 340)], _couteau)
    O.sur_dessus(g, c, 1, [math.radians(a) for a in (182, 218, 254, 286, 322, 358)], _petit_isolateur, t=0.15)
    # couronne d'isolateurs sur l'arête du dernier gradin
    R0, Rt, z0, z1 = c.gradins[-1]
    n = 18
    for k in range(n):
        a = TAU * (k + 0.5) / n
        p = O.dessus(c, len(c.gradins) - 1, a, 0.85)
        PT.insulators(g, (p.x, p.y, p.z), 2, 0.026, h=0.028)
    # transformateurs bleus à ailettes (coins arrière)
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        p = corps.place(c, nom)
        x, y = p["x"] - sx * 0.04, Y(p["yn"] - 0.04)
        w = 0.42
        PT.hull(g, x - w / 2, x + w / 2, y - 0.2, y + 0.2, 0.0, 0.42, ins=(0.02, 0.02, 0.02), panel=0.2,
                mats=[M["bleu_machine"], M["fonte_bleue"]], rivet_step=0.1)
        for s in (-1, 1):
            PT.radiator(g, (x + s * (w / 2 + 0.03), y, 0.05), 0.3, 0.32, 0.05, rz=math.pi / 2,
                        fin_mat=M["fonte_bleue"])
        for j in range(3):
            zt = PT.insulators(g, (x + (j - 1) * 0.12, y, 0.42), 3, 0.035, h=0.03)
            g.sphere((x + (j - 1) * 0.12, y, zt + 0.02), 0.022, M["copper_pol"], n=8, m=5, what="borne")
        O.lampe(g, (x, y - 0.205, 0.3), (0, -1, 0), 0.022, M["emit"], M["fonte_bleue"])
        g.box((x, y - 0.21, 0.18), (0.16, 0.006, 0.08), M["porcelaine"], "flat", what="plaque")
        liaison(g, [(x - sx * 0.12, y, 0.55), (0, 0, 0), (x * 0.45, Y(p["yn"] * 0.42), zp + 0.04)], 0.03)
        g.halo((x, y - 0.3, 0.3), M["_emit_rgb"], 4.0)
    for (x, yn) in ((0.0, -1.35), (-1.15, -0.4), (1.15, -0.4)):
        g.halo((x, Y(yn), 0.3), M["_emit_rgb"], 4.0)


def piece(g, c):
    """Niveau 12 : deux CONDENSATEURS À PLAQUES (piles de disques de cuivre entre deux colonnes d'isolateurs) aux coins
    avant, sur un patin de carreaux."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * p["x"], p["yn"]
        corps.patin(g, c, x - sx * 0.1, yn + 0.1, 0.62, 0.62, rz=sx * 0.785)
        with at(g, x, yn, sx * 0.4, z=0.035):
            g.box((0, 0, 0.03), (0.42, 0.24, 0.06), M["fonte_bleue"], "hard", what="semelle")
            for s in (-1, 1):
                PT.insulators(g, (s * 0.16, 0, 0.06), 5, 0.045, h=0.07)
            for k in range(7):
                g.cyl((0, 0, 0.1 + k * 0.045), "z", 0.12, 0.02, M["copper_pol"], n=20, style="hard", what="plaque")
                g.cyl((0, 0, 0.12 + k * 0.045), "z", 0.1, 0.025, M["porcelaine"], n=20, style="soft", what="dielectrique")
            g.cyl((0, 0, 0.43), "z", 0.13, 0.03, M["bakelite"], n=20, style="hard", what="chapeau")
            g.box((0, 0, 0.46), (0.36, 0.03, 0.02), M["copper_pol"], "hard", what="barre")
            O.lampe(g, (0, -0.13, 0.25), (0, -1, 0), 0.02, M["emit"], M["fonte_bleue"])
        g.halo((x, Y(yn), 0.35), M["_emit_rgb"], 4.0)


def arriere(g, c):
    """TRANSFORMATEUR bleu bas : cuve à ailettes, bornes sur isolateurs."""
    M = g.M
    t = c.T["tete"]
    zb = O.zb(c)
    bx, y0, y1, z1 = t["bx"], t["yb0"], t["yb1"], t["zb1"]
    PT.hull(g, -bx, bx, y0, y1, zb, z1 - 0.06, ins=(0.02, 0.02, 0.0), panel=0.2,
            mats=[M["bleu_machine"], M["fonte_bleue"]], rivet_step=0.1)
    nf = max(4, int((y1 - y0) / 0.05))
    for s in (-1, 1):
        for k in range(nf):
            yy = y0 + 0.03 + k * (y1 - y0 - 0.06) / max(1, nf - 1)
            g.box((s * (bx + 0.02), yy, (zb + z1) / 2 - 0.03), (0.04, 0.014, (z1 - zb) * 0.7), M["fonte_bleue"], "hard",
                  what="ailette")
    for s in (-1, 1):
        PT.insulators(g, (s * bx * 0.5, (y0 + y1) / 2, z1 - 0.06), 2, 0.03, h=0.028)


def tete(g, c):
    """Isolateurs sur les joues, bornes et petite bobine à l'arrière de la platine, fils nus."""
    M = g.M
    t = c.T["tete"]
    zb = O.zb(c)
    for sx in (-1, 1):
        PT.insulators(g, (sx * (t["xc"] + t["tc"] / 2), -0.3 * t["re"], c.zh + 0.72 * t["re"] - 0.02), 2, 0.028,
                      h=0.026)
    (xl, yl, wl), (xr, yr, wr) = O.pods(c)
    _bobine(g, xl, yl, zb, wl * 0.8, wl * 1.8, M)
    zt = PT.insulators(g, (xr, yr, zb), 3, wl * 0.6, h=0.03)
    g.sphere((xr, yr, zt + 0.02), 0.02, M["copper_pol"], n=8, m=5, what="borne")


def emetteur(g, c):
    """BOBINE TESLA courte couchée dans l'axe (cuivre bobiné, flasques), TORE HORIZONTAL de porcelaine posé dessus,
    bec isolant et BOULE électrode à l'avant, ARCS bleus du tore à la boule (collés au bec), lentille."""
    M = g.M
    re, zh = c.re, c.zh
    rb = 0.52 * re
    y0, y1 = -0.5 * re, 0.42 * re
    g.cyl((0, (y0 + y1) / 2, zh), "y", rb, y1 - y0, M["copper_pol"], n=32, style="soft", what="bobine")
    ns = 9
    for k in range(ns):
        yy = y0 + (k + 0.5) * (y1 - y0) / ns
        g.tube_shell((0, yy, zh), "y", rb + 0.01, rb - 0.01, 0.012, M["cuivre_spire"], n=32, what="spire")
    for yy in (y0, y1):
        g.cyl((0, yy, zh), "y", rb * 1.18, 0.04, M["bakelite"], n=32, style="hard", what="flasque")
        F.bolts_ring(g, (0, yy, zh), (0, 1, 0), rb * 1.08, 8, M["copper_pol"], r=0.012)
    # tore horizontal de porcelaine posé à plat SUR la bobine (pied court, bandes bleues)
    zt = zh + rb + 0.12 * re
    g.cyl((0, -0.05 * re, zh + rb * 0.8), "z", 0.22 * re, 0.32 * re, M["porcelaine"], n=16, style="soft", what="pied")
    g.torus((0, -0.05 * re, zt), "z", 0.56 * re, 0.17 * re, M["porcelaine_capot"], n=40, m=12, what="tore")
    g.cyl((0, -0.05 * re, zt), "z", 0.42 * re, 0.2 * re, M["fonte_bleue"], n=32, style="soft", what="coeur_tore")
    for k in range(8):
        a = TAU * k / 8
        g.torus((0.56 * re * math.cos(a), -0.05 * re + 0.56 * re * math.sin(a), zt), (-math.sin(a), math.cos(a), 0),
                0.175 * re, 0.012, M["bleu_machine"], n=16, m=4, what="bande")
    g.torus((0, -0.05 * re, zt + 0.12 * re), "z", 0.56 * re, 0.016, M["emit_soft"], n=40, m=4, what="couronne")
    # bec isolant et boule électrode
    g.cyl((0, y1 + 0.2 * re, zh), "y", 0.34 * re, 0.4 * re, M["porcelaine"], n=24, r2=0.14 * re, style="soft",
          what="bec")
    for k in range(3):
        g.tube_shell((0, y1 + (0.08 + 0.1 * k) * re, zh), "y", (0.36 - 0.06 * k) * re, (0.2 - 0.04 * k) * re, 0.025,
                     M["porcelaine_capot"], n=24, what="jupe")
    g.sphere((0, y1 + 0.52 * re, zh), 0.2 * re, M["copper_pol"], n=20, m=10, what="boule")
    corps.lentille(g, c, y1 + 0.7 * re, 0.12 * re, verre=M["glass_dk"], cercle=M["bakelite"])
    # arcs : du bord avant du tore, le long de la bobine et du bec, jusqu'à la boule (collés aux surfaces)
    for k, sx in enumerate((-0.55, 0.0, 0.55)):
        pts = []
        for j in range(9):
            s = j / 8.0
            yy = (0.2 + 0.5 * s) * re + (y1 - 0.2 * re) * s * 0.5
            rr = (rb + 0.03) * (1 - s) + (0.22 * re) * s
            ang = math.pi / 2 + sx * (1 - s) + 0.18 * (1 if j % 2 else -1) * (1 - s * 0.5)
            pts.append(V((rr * math.cos(ang), yy, zh + rr * math.sin(ang))))
        g.tube(pts, 0.014, M["emit"], n=5, style="flat", what="arc")
