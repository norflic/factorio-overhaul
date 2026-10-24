"""Laser · Âge 9 · Atome (ère III, 4×4, niveaux 17 et 18). EXEMPLE du kit laser_e (lot F1-A, aperçu d'essai) ; fiche :
fo-logs/2026-10-24_F1/FICHES_LASER.md, âge 9 (fait foi). S'exécute DANS Blender.

En 3 mots : « tête octogonale, cœur vert, béton ». L'émetteur est un CAISSON OCTOGONAL de plomb (prisme à 8 pans dont
l'axe est le faisceau, aussi long que large), percé à l'avant d'un grand HUBLOT sur un CŒUR VERT d'uranium, deux
hublots latéraux, trèfles ; porté par un étrier de béton. Affût OCTOGONAL à 3 gradins chanfreinés de béton presque
blanc, dalles de béton à liseré vert ; condensateurs = FÛTS DE PLOMB à hublot vert et trèfle ; liaisons en gaines
annelées de plomb. Coins arrière : blocs de blindage de plomb à évents.
Palette 60/30/10 (ages.PALETTE[9]) : béton blanc cassé / plomb gris-bleu / vert uranium.
"""
import math

from mathutils import Vector

import ages
import corps
import formes as F
import parts as PT
from kit import SQ2, TAU
from repere import Y, at

V = Vector

EPOQUE = 9
NOM = ages.NOMS[9]
TRIPLET = ("tête octogonale", "cœur vert", "béton")
FOYER = ages.FOYER[9]
FAISCEAU = dict(rgb=(0.36, 1.0, 0.29), forme="trait vert uranium épais, halo pulsé, étincelles vertes", largeur=1.3)
HABILLAGE = dict(ages.CORPS[9],
                 cerclages="plomb_sombre",
                 forme_affut=dict(gradins=3, pans=8, profil="chanfrein", flanc="beton_capot", flanc2="concrete",
                                  rapport=0.78),
                 forme_tete="etrier")


def matieres(metal, M):
    ages.matieres(9, metal, M)
    M["caisson"] = M["lead"]


def liaison(g, pts, r):
    """Gaine annelée de plomb (gris-bleu)."""
    g.hose(pts, r, g.M["lead"], step=0.035, n=10, what="gaine_plomb")


def _hublot(g, p, nrm, r, M):
    """Hublot épais : sertissure de plomb sombre boulonnée, verre vert lumineux (cœur), croisillon."""
    a = V(nrm).normalized()
    p = V(p)
    g.cyl(p + a * 0.012, a, r + 0.03, 0.03, M["plomb_sombre"], n=20, style="hard", what="sertissure")
    F.bolts_ring(g, p + a * 0.03, a, r + 0.012, 8, M["rivet"], r=0.012)
    g.cyl(p + a * 0.03, a, r, 0.012, M["emit"], n=20, style="flat", what="coeur")


def condensateur(g, c, x, y, z, r, h):
    """Fût de plomb blindé : corps gris-bleu, deux cerclages sombres, couvercle de béton, HUBLOT VERT vers l'extérieur
    (fûts vus de face seulement), trèfle sur le couvercle."""
    M = g.M
    g.cyl((x, y, z + h / 2), "z", r, h, M["lead"], n=20, style="soft", what="fut")
    for f in (0.15, 0.85):
        g.tube_shell((x, y, z + h * f), "z", r + 0.012, r - 0.01, 0.035, M["plomb_sombre"], n=20, what="cerclage")
    g.cyl((x, y, z + h + 0.02), "z", r * 1.04, 0.04, M["beton_capot"], n=20, style="soft", what="couvercle")
    F.trefoil(g, (x, y, z + h + 0.041), (0, 0, 1), r * 0.55)
    d = V((x, y / SQ2, 0)).normalized()
    if d.y < 0.2:
        dd = V((d.x, d.y * SQ2, 0)).normalized()
        _hublot(g, V((x, y, z + h * 0.5)) + dd * r, dd, r * 0.32, M)


def socle(g, c):
    """Coins arrière : blocs de blindage de plomb à évents et trèfles ; gaines vers le pivot ; halos verts."""
    M = g.M
    zp = c.gradins[-1][3]
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        p = corps.place(c, nom)
        x, yn = p["x"] - sx * 0.05, p["yn"] - 0.05
        w = 1.25 * p["r"]
        PT.hull(g, x - w, x + w, Y(yn - w), Y(yn + w), 0.0, 0.55, ins=(0.06, 0.06, 0.06), panel=0.26,
                mats=[M["lead"], M["plomb_sombre"]], rivet_step=0.12)
        for k in range(3):
            g.box((x, Y(yn - w) - 0.005, 0.12 + 0.11 * k), (w * 1.2, 0.02, 0.05), M["plomb_sombre"], "hard",
                  what="event")
        F.trefoil(g, (x, Y(yn - w) - 0.02, 0.44), (0, -1, 0.15), 0.07)
        liaison(g, [(x - sx * 0.2, Y(yn - 0.3), 0.4), (x * 0.5, Y(yn * 0.5), zp + 0.35), (x * 0.25, Y(yn * 0.22),
                    zp + 0.12)], 0.05)
    for (x, yn) in ((0.0, -1.7), (-1.5, -0.6), (1.5, -0.6)):
        g.halo((x, Y(yn), 0.5), M["_emit_rgb"], 12.0)


def piece(g, c):
    """Niveau 18 : deux FÛTS DE COMBUSTIBLE en château de plomb aux coins avant (couvercle de béton, hublot vert,
    trèfle), sur un patin de dalles de béton relié au premier gradin."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * p["x"], p["yn"]
        corps.patin(g, c, x - sx * 0.1, yn + 0.1, 0.9, 0.9, rz=sx * 0.785)
        with at(g, x, yn, z=0.035):
            r, h = 0.26, 0.62
            g.cyl((0, 0, h / 2), "z", r, h, M["lead"], n=28, style="soft", what="chateau")
            for f in (0.1, 0.5, 0.9):
                g.tube_shell((0, 0, h * f), "z", r + 0.016, r - 0.01, 0.05, M["plomb_sombre"], n=28, what="cerclage")
            g.cyl((0, 0, h + 0.03), "z", r * 1.05, 0.06, M["beton_capot"], n=28, style="soft", what="couvercle")
            F.trefoil(g, (0, 0, h + 0.061), (0, 0, 1), 0.12)
            _hublot(g, (0, -r, h * 0.5), (0, -1, 0), 0.08, M)
        g.halo((x, Y(yn - 0.3), 0.4), M["_emit_rgb"], 10.0)


def _octo_y(g, y0, y1, zh, R, mat, chanfrein=0.85):
    """Prisme OCTOGONAL d'axe y (de y0 à y1), centré en (0, zh), rayon R (sommets), faces avant et arrière à pans
    chanfreinés (le dernier dixième rentre de 15 %)."""
    n = 8
    def ring(y, rr):
        return [V((rr * math.cos(math.pi / 8 + TAU * i / n), y, zh + rr * math.sin(math.pi / 8 + TAU * i / n)))
                for i in range(n)]
    L = y1 - y0
    rings = [ring(y0, R * chanfrein), ring(y0 + 0.1 * L, R), ring(y1 - 0.1 * L, R), ring(y1, R * chanfrein)]
    vs = [tuple(p) for rg in rings for p in rg]
    fs = [tuple(range(n)), tuple(range(3 * n, 4 * n))[::-1]]
    for k in range(3):
        for i in range(n):
            j = (i + 1) % n
            fs.append((k * n + j, k * n + i, (k + 1) * n + i, (k + 1) * n + j))
    g._add(mat, "hard", vs, fs, "octogone")
    return rings


def emetteur(g, c):
    """CAISSON OCTOGONAL de plomb (axe = faisceau ; longueur 1,7 re pour 1,85 re de large : jamais dressé), plaques de
    plomb sombre rivetées sur les pans, grand HUBLOT AVANT sur le cœur vert (lentille), deux hublots latéraux, trèfle
    sur le dessus, bague de béton à l'avant."""
    M = g.M
    re, zh = c.re, c.zh
    R = 0.92 * re
    y0, y1 = -0.7 * re, 1.0 * re
    rings = _octo_y(g, y0, y1, zh, R, M["lead"])
    # plaques rivetées sur les pans (sauf le pan du dessous)
    a, b = rings[1], rings[2]
    for i in range(8):
        j = (i + 1) % 8
        mid = (a[i] + a[j]) / 2
        if mid.z < zh - 0.5 * R:
            continue
        q = [a[i].lerp(a[j], 0.1), a[i].lerp(a[j], 0.9), b[i].lerp(b[j], 0.9), b[i].lerp(b[j], 0.1)]
        nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
        if nrm.dot(V((mid.x, 0, mid.z - zh))) < 0:
            q = q[::-1]
        g.panels(q, 1, 2, M["plomb_sombre"], t=0.02, rivet_mat=M["rivet"], rivet_step=0.12)
    g.tube_shell((0, y1 - 0.06, zh), "y", R * 0.9, R * 0.62, 0.1, M["beton_capot"], n=8, what="bague")
    corps.lentille(g, c, y1 + 0.01, 0.55 * re, verre=M["emit"], cercle=M["plomb_sombre"], anneau=False)
    F.lit_ring(g, (0, y1 + 0.05, zh), "y", 0.62 * re, M["emit_soft"], w=0.035)
    # le cœur vert se lit de DESSUS et de CÔTÉ (en pose E, la face avant est vue par la tranche) : grand hublot sur le
    # pan du dessus, hublots sur les pans latéraux
    for sx in (-1, 1):
        _hublot(g, (sx * R * 0.93, 0.15 * re, zh), (sx, 0, 0), 0.24 * re, M)
    _hublot(g, (0, 0.15 * re, zh + R * 0.93), (0, 0, 1), 0.3 * re, M)
    F.trefoil(g, (0, -0.5 * re, zh + R * 0.93), (0, 0, 1), 0.1)
