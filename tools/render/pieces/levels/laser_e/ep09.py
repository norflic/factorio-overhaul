"""Laser · Âge 9 · Atome (ère III, 4×4, niveaux 17 et 18). EXEMPLE du kit laser_e (lot F1-A, aperçu d'essai) ; fiche :
fo-logs/2026-10-24_F1/FICHES_LASER.md, âge 9 (fait foi). S'exécute DANS Blender.

En 3 mots : « trèfle de béton, cœur vert, fûts de plomb » (correction F1-A, M-2 : « tête octogonale » nommait
la face avant, cachée en pose E). L'émetteur est un CAISSON OCTOGONAL de plomb (prisme à 8 pans dont
l'axe est le faisceau, aussi long que large), percé à l'avant d'un grand HUBLOT sur un CŒUR VERT d'uranium, deux
hublots latéraux, trèfles ; porté par un étrier de béton. Affût EN TRÈFLE (3 lobes) à 3 gradins chanfreinés de béton presque
blanc, dalles de béton à liseré vert ; condensateurs = FÛTS DE PLOMB à hublot vert et trèfle ; liaisons en gaines
annelées de plomb. Coins arrière : blocs de blindage de plomb à évents.
Palette 60/30/10 (ages.PALETTE[9]) : béton blanc cassé / plomb gris-bleu / vert uranium.
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

EPOQUE = 9
NOM = ages.NOMS[9]
TRIPLET = ("trèfle de béton", "cœur vert", "fûts de plomb")
FOYER = ages.FOYER[9]
FAISCEAU = dict(rgb=(0.36, 1.0, 0.29), forme="trait vert uranium épais, halo pulsé, étincelles vertes", largeur=1.3)
# affût en TRÈFLE (quatrième jet, M-6 : 3 lobes chanfreinés, epoques.MAQUETTES[9]) ; avant : octogone chanfreiné, la
# même silhouette que l'âge 7 (temple octogonal)
HABILLAGE = dict(ages.CORPS[9], **E_.MAQUETTES[9])
# LOT F1-C ronde 3c (critique : en pose N, joues claires lues « poteaux dressés ») : joues et paliers SOMBRES (corps.support)
JOUES = ("plomb_sombre", "lead")


def matieres(metal, M):
    ages.matieres(9, metal, M)
    M["caisson"] = M["lead"]


def tete(g, c):
    """Lot F1-B : petits châteaux de plomb à hublot vert à l'arrière de la platine."""
    M = g.M
    zb = O.zb(c)
    for (x, y, w) in O.pods(c):
        g.cyl((x, y, zb + w * 0.8), "z", w * 0.9, w * 1.6, M["lead"], n=14, style="soft", what="chateau")
        g.tube_shell((x, y, zb + w * 1.2), "z", w * 0.98, w * 0.8, 0.03, M["plomb_sombre"], n=14, what="cerclage")
        g.cyl((x, y, zb + w * 1.65), "z", w * 0.95, 0.04, M["beton_capot"], n=14, style="soft", what="couvercle")
        g.cyl((x, y - w * 0.9, zb + w * 0.8), "y", w * 0.3, 0.02, M["emit"], n=10, style="flat", what="hublot")


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
    # LOT F1-C ronde 3b (critique : disques verts « autocollants plats ») : lunette en relief et grille de barreaux
    # devant le cœur (hublot ENFONCÉ)
    g.tube_shell(p + a * 0.045, a, r + 0.012, r - 0.004, 0.03, M["plomb_sombre"], n=20, what="lunette")
    u = a.orthogonal().normalized()
    for j in (-1, 0, 1):
        g.cyl(p + a * 0.05 + u * (j * r * 0.5), a.cross(u), 0.008, 2 * r * (0.95 if j == 0 else 0.8), M["plomb_sombre"],
              n=6, what="barreau")


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
        # LOT F1-C (« la tête reste une boîte entre deux gros blocs de plomb carrés », lecteur de la ronde 2) : le bloc
        # devient une AIRE DE STOCKAGE : socle de plomb bas à évents, et dessus TROIS CHÂTEAUX de combustible (fûts de
        # plomb cerclés, couvercles de béton boulonnés, trèfle) ; plus haut que le bloc (masse)
        PT.hull(g, x - w, x + w, Y(yn - w), Y(yn + w), 0.0, 0.2, ins=(0.04, 0.04, 0.04), panel=0.26,
                mats=[M["lead"], M["plomb_sombre"]], rivet_step=0.12)
        for k in range(2):
            g.box((x, Y(yn - w) - 0.005, 0.06 + 0.08 * k), (w * 1.5, 0.02, 0.04), M["plomb_sombre"], "hard",
                  what="event")
        for j, (dx, dy) in enumerate(((-0.4, -0.36), (0.4, -0.36), (0.0, 0.36))):
            cx, cy = x + dx * w, yn + dy * w
            r, h = 0.215, 0.98       # ronde 3b : plus hauts (masse), serrés (aucun jour entre deux châteaux) ; 3c : 0,98
            g.cyl((cx, Y(cy), 0.2 + h / 2), "z", r, h, M["lead"], n=24, style="soft", what="chateau")
            for f in (0.12, 0.5, 0.88):
                g.tube_shell((cx, Y(cy), 0.2 + h * f), "z", r + 0.016, r - 0.01, 0.045, M["plomb_sombre"], n=24,
                             what="cerclage")
            g.cyl((cx, Y(cy), 0.2 + h + 0.025), "z", r * 1.06, 0.05, M["beton_capot"], n=24, style="soft",
                  what="couvercle")
            F.bolts_ring(g, (cx, Y(cy), 0.2 + h + 0.051), (0, 0, 1), r * 0.85, 8, M["plomb_sombre"], r=0.012)
            if j < 2:
                _hublot(g, (cx, Y(cy) - r, 0.2 + h * 0.55), (0, -1, 0), 0.06, M)
        F.trefoil(g, (x, Y(yn - w) - 0.02, 0.12), (0, -1, 0.15), 0.06)
        # lot F1-B : la gaine ne monte plus au-dessus de l'affût (trou enfermé de 16 à 35 px entre le bloc de plomb, la
        # gaine et le gradin, essais r0b et correction du lot F1-A) : elle suit les dessus des gradins
        g1 = c.gradins[1][3]
        liaison(g, [(x - sx * 0.25, Y(yn - 0.35), 0.3), (x * 0.62, Y(yn * 0.6), g1 + 0.06),
                    (x * 0.4, Y(yn * 0.36), zp + 0.05)], 0.05)
        # lampe verte et pancarte de danger sur la face sud du bloc
        O.lampe(g, (x + w * 0.72, Y(yn - w) - 0.01, 0.12), (0, -1, 0), 0.026, M["emit"], M["plomb_sombre"])   # LOT F1-C : sur le socle bas
    # lot F1-B (enrichissement) : conduite de plomb qui ceint le premier gradin, plaques de danger au trèfle, voyants
    # verts, fûts de déchets et regards sur les dessus
    O.ceinture(g, c, 0, 0.3, 0.022, M["lead"], colliers=M["plomb_sombre"], pas=0.4)
    O.ceinture(g, c, 1, 0.4, 0.018, M["lead"], colliers=M["plomb_sombre"], pas=0.35)
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (205, 245, 295, 335)], _pancarte, f=0.62, dr=0.006)
    # ronde 3c (critique : « aucun signe radioactif lisible ») : trois GRANDS trèfles jaune et noir sur le flanc avant
    for a in (232, 270, 308):
        p, nrm, _ = O.flanc(c, 0, math.radians(a), 0.5, 0.012)
        F.trefoil(g, p, nrm + V((0, 0, 0.35)), 0.15)
    O.sur_flanc(g, c, 1, [math.radians(a) for a in (230, 270, 310)], _pancarte, f=0.55, dr=0.006)
    O.sur_dessus(g, c, 1, [math.radians(a) for a in (200, 235, 270, 305, 340)], _dessus2)
    O.sur_dessus(g, c, 0, O.visibles(O.entre_condensateurs(c), nord=0.2), _regard, t=0.5)
    # LOT F1-C (masse sous l'âge 8 en ronde 2) : dans les TROIS CREUX du trèfle, au sol, fûts de déchets de plomb et
    # blindages bas (le trèfle se lit toujours d'en haut : ils restent sous le premier gradin)
    R1 = c.gradins[0][0]
    z1 = c.gradins[0][3]
    for av in (30.0, 150.0, 270.0):
        a = math.radians(av)
        rv = R1 * 0.7
        for j, (dr, dt) in enumerate(((0.28, 0.0), (0.2, -0.36), (0.2, 0.36), (0.5, -0.18), (0.5, 0.18))):
            rr = rv + dr
            aa = a + dt / max(rr, 0.5)
            x, yn = rr * math.cos(aa), rr * math.sin(aa)
            if not corps._hors_coins(c, x, yn, 0.12):
                continue
            if j < 3:
                F.drum(g, (x, Y(yn), 0.0), 0.15, min(0.36, z1 * 1.5), M["lead"], M["plomb_sombre"],
                       top=M["beton_capot"], trefoil=(j == 0))
            else:
                g.box((x, Y(yn), 0.09), (0.22, 0.16, 0.18), M["plomb_sombre"], "hard", R=Matrix.Rotation(aa, 3, "Z"),
                      what="blindage")
                g.box((x, Y(yn), 0.185), (0.18, 0.12, 0.012), M["lead"], "flat", R=Matrix.Rotation(aa, 3, "Z"),
                      what="couvercle_blindage")
    for (x, yn) in ((0.0, -1.7), (-1.5, -0.6), (1.5, -0.6)):
        g.halo((x, Y(yn), 0.5), M["_emit_rgb"], 12.0)


def _pancarte(g, k, h):
    """Plaque de danger jaune patiné au trèfle et voyant vert (repère du flanc)."""
    M = g.M
    g.box((0, 0, 0.006), (0.16, h * 0.5, 0.012), M["plomb_sombre"], "hard", what="cadre")
    g.box((0, 0, 0.013), (0.13, h * 0.4, 0.004), M["beton_capot"], "flat", what="pancarte")
    F.trefoil(g, (0, 0, 0.016), (0, 0, 1), 0.04)
    O.lampe(g, (0.12, h * 0.1, 0.0), (0, 0, 1), 0.02, M["emit"], M["plomb_sombre"])


def _dessus2(g, k, w):
    """Second gradin : fût de déchets à trèfle ou regard de contrôle vert."""
    M = g.M
    if k % 2 == 0:
        F.drum(g, (0, 0, 0), 0.08, 0.2, M["lead"], M["plomb_sombre"], trefoil=True)
    else:
        _regard(g, k, w)


def _regard(g, k, w):
    """Regard de contrôle : tampon de béton, hublot vert, poignées."""
    M = g.M
    g.cyl((0, 0, 0.02), "z", 0.07, 0.04, M["beton_capot"], n=14, style="soft", what="tampon")
    g.cyl((0, 0, 0.042), "z", 0.035, 0.006, M["emit_soft"], n=12, style="flat", what="hublot")
    for s in (-1, 1):
        g.box((s * 0.055, 0, 0.045), (0.012, 0.04, 0.012), M["plomb_sombre"], "hard", what="poignee")


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
    # pan du dessus, hublots sur les deux pans DIAGONAUX du haut (correction F1-A, m-4 : sur les pans latéraux, ils
    # étaient cachés derrière les joues de l'étrier ; un pan diagonal du haut regarde la caméra en pose E)
    for sx in (-1, 1):
        k = 0.93 * math.cos(math.pi / 4)
        _hublot(g, (sx * R * k, 0.15 * re, zh + R * k), (sx, 0, 1), 0.18 * re, M)   # ronde 3b : 0,24 → 0,18
    _hublot(g, (0, 0.15 * re, zh + R * 0.93), (0, 0, 1), 0.22 * re, M)               # ronde 3b : 0,30 → 0,22
    F.trefoil(g, (0, -0.5 * re, zh + R * 0.93), (0, 0, 1), 0.1)
