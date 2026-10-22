"""Mitrailleuse, lot V3-E, époques 10 à 15 (ères IV et V) : socles et têtes. S'exécute DANS Blender.

Lignée retenue par le Directeur Créatif (verdict du 22/10, 16 h 45) : celle de l'industriel lourd
(gun_s_industriel, branche worktree-wf_483106c7-c7f-2, commit 265574d). Le CORPS ne change pas d'une époque à
l'autre (colonne à goussets, couronne dentée à bandes de danger, trémie et caisses ouvertes au sud, groupe
électrogène à l'ouest, réservoirs à l'est, radiateur au nord, armoires, tourelles secondaires ; tête : jupe
blindée, coupole rivetée, masque, nacelle, tourelleau, 2 canons de flanc). Ce qui change (catalogue
fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §A.2) : E1 canons (armes.py), E2 tuyaux et liaisons, E3
accents, E4 matières d'accent (kit.materials), E5 foyers, E6 petites pièces de signature et pièce du niveau pair.

Emprises (Q-S1, shared/levels/config.lua, L.footprints.gun) : ère IV (époques 10 à 12) 5×5, corps du niveau 21
de l'industriel ; ère V (époques 13 à 15) 6×6, corps du niveau 29.
Puissance à l'intérieur d'une ère (catalogue §A.5) : tubes plus longs, une machine de plus à la 2e époque, une
arme de plus à la 3e (télémètre, canon de coupole, tourelle secondaire), tablier plus plein, plus de foyers.
Corrections des juges (§A.6) faites en passant : tablier bas continu (aucun trou enfermé, aucune pièce isolée),
groupes de voyants (≤ 3), fentes lumineuses par groupes, bagues non blanches, freins de bouche lisibles en pose N.

Conventions : 1 unité = une tuile en X ; une tuile de jeu vers le nord = 1,414 unité en Y (Y()) ; +Z haut.
"""
import math

from mathutils import Matrix, Vector

import ages as AG
import armes as A
import parts as PT
import parts2 as P2
import parts3 as P3
from kit import SQ2, TAU

V = Vector
ERA = {10: 4, 11: 4, 12: 4, 13: 5, 14: 5, 15: 5}
SIDE = {10: 5, 11: 5, 12: 5, 13: 6, 14: 6, 15: 6}
NAME = {10: "Haute technologie", 11: "Titane", 12: "Supraconducteurs", 13: "Fusion", 14: "Orbite", 15: "Légende"}


def Y(yn):
    """y de jeu en tuiles, vers le NORD -> Y Blender."""
    return yn * SQ2


SYSTEMS = {
    10: ["tête à canons (2 × 6 tubes carénés)", "alimentation (cassettes, nappes)", "socle pivotant",
         "blindage frontal (masque, jupe)", "refroidissement (2 réservoirs, radiateur à ventilateurs)",
         "canons jumelés", "chargeur automatique (goulotte)", "conduits et câblage (faisceaux rouges et bleus)",
         "conduite de tir (radôme, capteurs optiques)", "générateur (5 cylindres)", "tourelle secondaire"],
    11: ["tête à canons (2 × 6 tubes à ailerons)", "alimentation", "socle pivotant", "blindage frontal et latéral",
         "refroidissement", "canons jumelés", "chargeur automatique", "conduits et câblage", "viseur et télémètre",
         "générateur", "tourelle secondaire", "radiateurs", "armoires de commande"],
    12: ["tête à canons (2 × 6 tubes à anneaux)", "canon de coupole (4 tubes)", "alimentation (cellules cryogéniques)",
         "socle pivotant", "blindage", "refroidissement cryogénique (dewars)", "canons jumelés", "chargeur automatique",
         "conduits cryogéniques et câblage", "générateur", "tourelles secondaires (2)", "radiateurs",
         "armoires de commande"],
    13: ["tête à canons à plasma (2 × 6 tubes)", "chambres de confinement", "canon de coupole (6 tubes)",
         "alimentation (injecteurs)", "socle pivotant", "blindage", "sphères de confinement", "canons jumelés",
         "chargeur automatique", "gaines de cuivre", "générateur (6 cylindres)", "tourelles secondaires (2)",
         "réserve d'énergie (condensateurs)"],
    14: ["tête à canons longue portée (2 × 6 tubes)", "canon de coupole", "alimentation (bras articulés)",
         "socle pivotant", "blindage", "réservoirs sphériques dorés", "canons jumelés", "chargeur automatique",
         "câbles gainés d'or", "conduite de tir (paraboles)", "générateur", "tourelles secondaires (3)",
         "réserve d'énergie", "panneaux solaires repliés"],
    15: ["tête à canons (2 × 6 tubes lourds)", "canon de coupole", "alimentation (cellules couronnées)",
         "socle pivotant", "blindage à plaques multiples", "refroidissement", "canons jumelés",
         "chargeur automatique", "conduits nacrés et conduits lumineux", "viseur", "générateur (6 cylindres)",
         "tourelles secondaires (3)", "réserve d'énergie visible"],
}
BASE = {4: dict(R=1.3, h=0.98, rh=0.12), 5: dict(R=1.6, h=1.16, rh=0.14)}
HEADS = {
    4: dict(R=1.12, zs=1.55, rz=0.62, gx=1.5, zg=1.74, nb=6, rb=0.06, rr=0.145, recv=(-0.6, 0.8), wr=0.44, hr=0.25),
    5: dict(R=1.38, zs=1.8, rz=0.74, gx=1.84, zg=2.0, nb=6, rb=0.072, rr=0.175, recv=(-0.74, 0.95), wr=0.52, hr=0.3),
}
LGUN = {10: 2.0, 11: 2.1, 12: 2.2, 13: 2.3, 14: 2.4, 15: 2.5}


def head_params(e):
    H = dict(HEADS[ERA[e]])
    H["L"] = LGUN[e]
    return H


def ring_top(e):
    B = BASE[ERA[e]]
    return B["h"] + B["rh"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


class at:
    """Repère local posé en (x, y de jeu vers le nord, z), tourné de rz : `with at(g, x, yn, rz): ...`."""

    def __init__(self, g, x, yn, rz=0.0, z=0.0):
        self.g, self.a = g, ((x, Y(yn), z), rz)

    def __enter__(self):
        self.g.push(self.a[0], rz=self.a[1])
        return self.g

    def __exit__(self, *exc):
        self.g.pop()


# ------------------------------------------------------------------------------------------------
# Foyers groupés (correction « fenêtres »)
# ------------------------------------------------------------------------------------------------
def slits_grouped(g, R, z, groups, emat, a0=0.0, span=TAU, per=(2, 3), visor=True):
    """Fentes lumineuses autour d'un fût, PAR GROUPES de 2 ou 3 (écarts irréguliers), jamais en rangée continue."""
    k = 0
    for gi in range(groups):
        n = per[gi % len(per)]
        ac = a0 + span * (gi + 0.5) / groups
        for j in range(n):
            a = ac + (j - (n - 1) / 2) * 0.085 * (1.0 + 0.25 * (j % 2)) * 1.3 / max(1.0, R)
            d = V((math.cos(a), math.sin(a), 0.0))
            t = V((-math.sin(a), math.cos(a), 0.0))
            R3 = Matrix((t, d, V((0, 0, 1)))).transposed()
            w = 0.1 if (j + gi) % 3 else 0.06
            g.box(d * (R + 0.045) + V((0, 0, z)), (w, 0.012, 0.035), emat, "flat", R=R3, what="fente")
            if visor:
                g.box(d * (R + 0.05) + V((0, 0, z + 0.035)), (w + 0.03, 0.022, 0.02), g.M["steel_hi"], "hard", R=R3,
                      what="visiere")
            k += 1
    return k


# ------------------------------------------------------------------------------------------------
# Tablier bas continu (correction des trous enfermés, catalogue §A.6)
# ------------------------------------------------------------------------------------------------
def apron(g, side, cf, cb, inset=0.12, z=0.045, front=None):
    """Caillebotis bas (4,5 cm) qui relie TOUS les volumes du socle : aucun jour entre les machines, aucune pièce
    isolée. Octogone chanfreiné (cf à l'avant, cb à l'arrière, en tuiles de jeu), rentré de `inset` : le contour
    du bâtiment reste fait par les volumes qui le débordent. Lames sur chant au pas de 0,09, cornières boulonnées."""
    M = g.M
    hx = side / 2.0 - inset
    hy = side / 2.0 - inset
    fy = front if front is not None else hy
    poly = [(-hx + cf, -fy), (hx - cf, -fy), (hx, -fy + cf), (hx, hy - cb), (hx - cb, hy), (-hx + cb, hy),
            (-hx, hy - cb), (-hx, -fy + cf)]
    P = [(x, Y(y)) for x, y in poly]
    n = len(P)
    vs = [(x, y, 0.0) for x, y in P] + [(x, y, z * 0.45) for x, y in P]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    g._add(M["void"], "flat", vs, fs, "tablier")
    nb = int((2 * hx - 0.1) / 0.09)
    for i in range(nb):
        x = -hx + 0.05 + (i + 0.5) * (2 * hx - 0.1) / nb
        ys = []
        for j in range(n):
            (x0, y0), (x1, y1) = P[j], P[(j + 1) % n]
            if (x0 - x) * (x1 - x) <= 0 and x0 != x1:
                ys.append(y0 + (y1 - y0) * (x - x0) / (x1 - x0))
        if len(ys) < 2:
            continue
        ya, yb = min(ys) + 0.07, max(ys) - 0.07
        if yb > ya:
            g.box((x, (ya + yb) / 2, z * 0.45 + 0.012), (0.03, yb - ya, 0.024), M["grate"], "flat", what="lame")
    for i in range(n):
        p0, p1 = V((P[i][0], P[i][1], 0)), V((P[(i + 1) % n][0], P[(i + 1) % n][1], 0))
        d = p1 - p0
        L = d.length
        if L < 0.05:
            continue
        d.normalize()
        nrm = V((d.y, -d.x, 0))
        R = Matrix((d, V((-d.y, d.x, 0)), V((0, 0, 1)))).transposed()
        g.box((p0 + p1) / 2 - nrm * 0.04 + V((0, 0, z * 0.5)), (L, 0.08, z), M["steel_dk"], "hard", R=R,
              what="corniere")
        k = max(2, int(L / 0.3))
        for j in range(k):
            q = p0 + d * (L * (j + 0.5) / k) - nrm * 0.04 + V((0, 0, z))
            g.bolt(q, (0, 0, 1), 0.016, M["steel_hi"])
    return poly


# ------------------------------------------------------------------------------------------------
# Liaisons d'époque (E2)
# ------------------------------------------------------------------------------------------------
def hose_e(g, e, ctrl, r):
    """Gaine ou conduit souple, habillé par époque."""
    M = g.M
    if e == 10:
        P, T = g.tube(g.spline(ctrl, 10), r * 0.85, M["pipe"], n=12, what="gaine")
        for i in range(2, len(P) - 1, 5):
            g.cyl(P[i], T[i], r * 0.85 + 0.014, 0.03, M["steel_hi"], n=12, style="hard", what="collier")
        PT.cable_run(g, [V(p) + V((0, 0, r + 0.03)) for p in ctrl], 2, 0.016, 0.04, [M["cable_a"], M["cable_b"]])
    elif e == 11:
        PT.cable_run(g, ctrl, 3, r * 0.42, r * 0.95, [M["jacket"]])
        P = g.spline(ctrl, 10)
        T, _ = g.frames(P)
        for i in range(2, len(P) - 1, 6):
            g.cyl(P[i], T[i], r * 1.55, 0.04, M["ring"], n=12, style="hard", what="collier")
    elif e == 12:
        P, T = g.tube(g.spline(ctrl, 10), r * 1.3, M["pipe"], n=12, what="mousse")
        for i in (0, len(P) - 1):
            g.hose([tuple(P[i] - T[i] * 0.06), tuple(P[i] + T[i] * 0.06)], r * 1.4, M["ring"], step=0.025)
        for i in range(3, len(P) - 2, 7):
            g.cyl(P[i], T[i], r * 1.42, 0.025, M["trim"], n=12, style="flat", what="givre")
    elif e == 13:
        g.hose(ctrl, r * 1.35, M["copper"], step=0.048, n=12)
    elif e == 14:
        P, T = g.tube(g.spline(ctrl, 10), r * 1.05, M["jacket"], n=10, style="flat", what="gaine_or")
        for i in range(2, len(P) - 1, 5):
            g.cyl(P[i], T[i], r * 1.05 + 0.014, 0.03, M["ring"], n=12, style="hard", what="sangle")
    else:
        P, T = g.tube(g.spline(ctrl, 10), r, M["trim"], n=12, what="conduit_nacre")
        for i in range(2, len(P) - 1, 5):
            g.tube_shell(P[i], T[i], r + 0.016, r - 0.01, 0.035, M["jacket"], n=14, what="bague_or")


def cables_e(g, e, ctrl, n=3):
    M = g.M
    mats = {10: [M["cable_a"], M["cable_b"], M["cable_a"], M["cable_b"]], 11: [M["rubber"], M["redcable"], M["rubber"]],
            12: [M["cable_a"], M["cable_a"]], 13: [M["rubber"], M["redcable"], M["rubber"]],
            14: [M["jacket"], M["rubber"], M["jacket"]], 15: [M["rubber"], M["redcable"], M["rubber"]]}[e]
    if e == 10:
        n = 4
    if e == 12:
        PT.cable_run(g, ctrl, 2, 0.032, 0.075, mats)
    elif e == 10:
        PT.cable_run(g, ctrl, 4, 0.026, 0.055, mats)
    else:
        PT.cable_run(g, ctrl, n, 0.02, 0.045, mats)


def conduit_e(g, e, ctrl, r):
    """Conduit d'énergie : bagues lumineuses PAR GROUPES (chenillard), colliers en matière d'époque."""
    M = g.M
    if e == 13:
        g.hose(ctrl, r * 1.5, M["copper"], step=0.048, n=12)
        return
    P = g.spline(ctrl, 10)
    P, T = g.tube(P, r, M["jacket"] if e in (12, 14) else M["steel_dk"], n=10, what="conduit")
    R = g.resample(P, 0.075)
    T2, _ = g.frames(R)
    for i in range(1, len(R) - 1):
        if i % 4 in (1, 2):
            g.tube_shell(R[i], T2[i], r + 0.008, r * 0.5, 0.03, M["emit"], n=12, what="bague_lum")
        elif i % 4 == 3:
            g.tube_shell(R[i], T2[i], r + 0.016, r * 0.5, 0.03, M["pipe2"], n=12, what="collier")


def pipe_e(g, e, ctrl, r, valve_at=None):
    M = g.M
    mat = {10: M["pipe"], 11: M["jacket"], 12: M["ring"], 13: M["copper"], 14: M["ring"], 15: M["trim"]}[e]
    g.pipe(ctrl, r, mat, fl_mat=M["pipe2"] if e != 13 else M["brass"], bolt_mat=M["rivet"])
    if valve_at is not None:
        p, ax = valve_at
        g.box(p, (r * 3.2, r * 3.2, r * 3.2), M["steel_dk"], "hard", what="corps_vanne")
        P2.handwheel(g, V(p) + V(ax).normalized() * (r * 1.6 + 0.06), ax, 0.07, M)


# ------------------------------------------------------------------------------------------------
# Réservoirs d'époque (même place, même masse)
# ------------------------------------------------------------------------------------------------
def tank_e(g, e, x, y, r, h, ladder_dir, stub_dir, gauges=2, rings=1):
    M = g.M
    E = M["emit"]
    if e in (10, 11, 15):
        paint = {10: M["jacket"], 11: M["jacket"], 15: M["cream"]}[e]
        band = {10: M["matte"], 11: M["ring"], 15: M["jacket"]}[e]
        P3.vtank(g, x, y, r, h, M, paint=paint, emat=E, ladder_dir=ladder_dir, stub_dir=stub_dir, gauges=gauges,
                 glow_gauges=True, glow_rings=0, band=band)
        _tank_lights(g, x, y, r, h, e)
        if e == 11:
            # 3 grands ailerons d'alliage blanc patiné (profil de fusée), nervure et rivets
            for a in (0.0, -0.8, 0.8):
                d = V((math.cos(a), math.sin(a), 0))
                t = V((-d.y, d.x, 0)) * 0.03
                c = V((x, y, 0))
                P2.wedge(g, c + d * (r - 0.01) + V((0, 0, 0.1)), c + d * (r - 0.01) + V((0, 0, h * 0.82)),
                         c + d * (r + 0.2) + V((0, 0, 0.12)), t, M["ring"], what="aileron")
                g.box(c + d * (r + 0.06) + V((0, 0, 0.32)), (0.05, 0.05, 0.4), M["steel_dk"], "hard",
                      R=Matrix.Rotation(a, 3, "Z"), what="nervure")
                for zz in (0.16, 0.3, 0.44, 0.58):
                    for s_ in (-1, 1):
                        g.dome(c + d * (r + 0.035) + V((0, 0, zz)) + t * s_ * 0.6, t * s_, 0.012, M["rivet"])
        if e == 10:
            # carénages gris clair rapportés, antenne fouet, fenêtre de niveau bleue
            for a in (-1.35, -2.05):
                d = V((math.cos(a), math.sin(a), 0))
                Rr = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
                g.box(V((x, y, h * 0.55)) + d * (r + 0.012), (0.26, 0.024, h * 0.5), M["matte"], "hard", R=Rr,
                      what="carenage")
                g.box(V((x, y, h * 0.55)) + d * (r + 0.026), (0.03, 0.006, h * 0.4), M["emit"], "flat", R=Rr,
                      what="niveau")
            g.cyl((x, y, h + r * 0.42 + 0.2), "z", 0.006, 0.4, M["steel_dk"], n=6, what="antenne")
        if e == 15:
            # bande ciselée : losanges d'or blanc sertis de nacre sur la virole (face visible)
            for k in range(14):
                a = -math.pi * 0.05 - math.pi * 0.9 * k / 13
                d = V((math.cos(a), math.sin(a), 0))
                Rr = Matrix((V((-d.y, d.x, 0)), V((0, 0, 1)), d)).transposed() @ Matrix.Rotation(math.pi / 4, 3, "Z")
                for zz in (h * 0.56, h * 0.7):
                    g.box(V((x, y, zz)) + d * (r + 0.012), (0.045, 0.045, 0.014), M["jacket"], "hard", R=Rr,
                          what="ciselure")
                    g.box(V((x, y, zz)) + d * (r + 0.02), (0.02, 0.02, 0.008), M["trim"], "hard", R=Rr,
                          what="ciselure")
            zt = h + r * 0.42
            for k in range(5):
                a = TAU * k / 5 + 0.3
                d = V((math.cos(a), math.sin(a), 0))
                c = V((x, y, h + r * 0.2)) + d * r * 0.55
                P2.wedge(g, c, c + d * 0.05, c + d * 0.02 + V((0, 0, 0.13)), V((-d.y, d.x, 0)) * 0.02, M["jacket"],
                         what="fleche")
        return
    if e == 12:
        # DEWAR : cuve double à col, virole noire, cerclages chromés givrés, anneau cyan segmenté
        P3.vtank(g, x, y, r, h, M, paint=M["jacket"], emat=E, ladder_dir=ladder_dir, stub_dir=stub_dir,
                 gauges=gauges, glow_gauges=True, glow_rings=0, band=M["ring"])
        zt = h + r * 0.42
        g.cyl((x, y, zt + 0.06), "z", r * 0.32, 0.14, M["ring"], n=24, what="col")
        g.cyl((x, y, zt + 0.15), "z", r * 0.38, 0.05, M["jacket"], n=24, what="col_bride")
        g.tube_shell((x, y, zt + 0.02), "z", r * 0.36, r * 0.3, 0.03, M["trim"], n=24, what="givre")
        _seg_ring(g, x, y, r + 0.02, h * 0.45, 5, E)
        _tank_lights(g, x, y, r, h, e)
        return
    if e == 13:
        # SPHÈRE DE CONFINEMENT sur trépied court, céramique patinée, cerclages de cuivre, tore magenta segmenté
        rs = r * 1.12
        zc = 0.12 + rs * 0.95
        for k in range(3):
            a = TAU * k / 3 + 0.5
            d = V((math.cos(a), math.sin(a), 0))
            g.box(V((x, y, zc * 0.5)) + d * rs * 0.55, (0.07, 0.07, zc - 0.05), M["steel_dk"], "hard",
                  R=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(-0.25, 3, "Y"), what="pied")
            g.box(V((x, y, 0.04)) + d * rs * 0.72, (0.16, 0.16, 0.08), M["steel_dk"], "hard", what="semelle")
        g.cyl((x, y, 0.06), "z", r * 0.8, 0.12, M["steel_dk"], n=24, style="soft", what="socle")
        g.sphere((x, y, zc), rs, M["jacket"], n=32, m=16)
        for zz_, nn in ((0.18, 14), (0.62, 10), (-0.2, 12)):
            rr_ = rs * math.sqrt(1 - zz_ * zz_)
            for k in range(nn):
                a = TAU * (k + 0.5) / nn
                d = V((math.cos(a) * math.sqrt(1 - zz_ * zz_), math.sin(a) * math.sqrt(1 - zz_ * zz_), zz_))
                g.push_frame(V((x, y, zc)) + d * (rs + 0.004), d)
                g.box((0, 0, 0.006), (0.06, 0.06, 0.014), M["steel_dk"], "hard", what="trappe")
                g.pop()
        for zz in (-0.35, 0.0, 0.4):
            rr = rs * math.cos(math.asin(max(-0.99, min(0.99, zz))))
            g.torus((x, y, zc + rs * zz), "z", rr + 0.006, 0.016, M["copper"], n=40, m=6, what="cerclage")
        _seg_ring(g, x, y, rs + 0.03, zc, 6, E)
        for a in (-1.2, -1.9):
            d = V((math.cos(a), math.sin(a), 0.25)).normalized()
            p = V((x, y, zc)) + d * rs
            g.cyl(p, d, 0.06, 0.04, M["steel_dk"], n=16, what="hublot")
            g.cyl(p + d * 0.022, d, 0.042, 0.006, M["emit2"], n=14, style="flat", what="hublot_lum")
        g.cyl((x, y, zc + rs + 0.03), "z", rs * 0.3, 0.08, M["copper"], n=18, what="bride")
        if stub_dir is not None:
            d = V((stub_dir[0], stub_dir[1], 0)).normalized()
            g.hose([tuple(V((x, y, zc)) + d * rs * 0.9), tuple(V((x, y, zc * 0.6)) + d * (rs + 0.25)),
                    tuple(V((x, y, 0.3)) + d * (rs + 0.4))], 0.05, M["copper"], step=0.034)
        return
    # 14 : RÉSERVOIR SPHÉRIQUE DORÉ (feuille d'or froissée), ceinture blanc cassé, balise rouge
    rs = r * 1.1
    zc = 0.1 + rs * 0.98
    for k in range(4):
        a = TAU * (k + 0.5) / 4
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((x, y, zc * 0.45)) + d * rs * 0.72, (0.07, 0.07, zc * 0.9), M["ring"], "hard", what="pied")
        g.box(V((x, y, 0.035)) + d * rs * 0.72, (0.14, 0.14, 0.07), M["steel_dk"], "hard", what="semelle")
    g.cyl((x, y, 0.06), "z", r * 0.7, 0.12, M["steel_dk"], n=24, style="soft", what="socle")
    for k in range(6):
        z0 = zc - rs + 2 * rs * k / 6
        z1 = z0 + 2 * rs / 6
        zm = (z0 + z1) / 2
        rm = rs * math.sqrt(max(0.05, 1 - ((zm - zc) / rs) ** 2))
        g.crumple((x, y, zm), "z", rm, z1 - z0 + 0.01, M["jacket"], n=24, k=2, amp=0.012)
    g.torus((x, y, zc), "z", rs + 0.01, 0.03, M["ring"], n=48, m=8, what="ceinture")
    for k in range(24):
        a = TAU * k / 24
        g.dome((x + (rs + 0.04) * math.cos(a), y + (rs + 0.04) * math.sin(a), zc), (math.cos(a), math.sin(a), 0),
               0.015, M["rivet"])
    for zz in (-0.45, 0.45):
        rr_ = rs * math.sqrt(1 - zz * zz)
        g.torus((x, y, zc + rs * zz), "z", rr_ + 0.006, 0.014, M["ring"], n=40, m=6, what="sangle")
        for k in range(12):
            a = TAU * (k + 0.5) / 12
            g.box((x + (rr_ + 0.02) * math.cos(a), y + (rr_ + 0.02) * math.sin(a), zc + rs * zz), (0.03, 0.03, 0.03),
                  M["steel_hi"], "hard", what="boucle")
    g.cyl((x, y, zc + rs + 0.02), "z", 0.06, 0.06, M["steel_dk"], n=14, what="bride")
    g.cyl((x, y, zc + rs + 0.07), "z", 0.025, 0.035, M["emit"], n=10, style="flat", what="balise")
    _halo(g, [(x, y, zc + rs + 0.1)], 6.0, g.M["_emit_rgb"])
    for a in (-1.3, -1.85):
        d = V((math.cos(a), math.sin(a), 0.1)).normalized()
        p = V((x, y, zc)) + d * (rs + 0.01)
        g.cyl(p, d, 0.04, 0.03, M["steel_dk"], n=12, what="voyant_pied")
        g.cyl(p + d * 0.016, d, 0.026, 0.005, M["emit2"], n=12, style="flat", what="voyant")
    if stub_dir is not None:
        d = V((stub_dir[0], stub_dir[1], 0)).normalized()
        hose_e(g, 14, [tuple(V((x, y, zc * 0.7)) + d * rs * 0.95), tuple(V((x, y, 0.4)) + d * (rs + 0.25)),
                       tuple(V((x, y, 0.25)) + d * (rs + 0.4))], 0.045)


def _seg_ring(g, x, y, R, z, n, emat):
    """Anneau lumineux SEGMENTÉ (n segments courts ≤ 0,03 t², pattes sombres entre eux)."""
    for k in range(n):
        a = TAU * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0))
        Rr = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
        if d.y > 0.7:
            continue
        g.box(V((x, y, z)) + d * R, (TAU * R / n * 0.8, 0.014, 0.03), emat, "flat", R=Rr, what="segment")
        a2 = TAU * k / n
        d2 = V((math.cos(a2), math.sin(a2), 0))
        Rr2 = Matrix((V((-d2.y, d2.x, 0)), d2, V((0, 0, 1)))).transposed()
        g.box(V((x, y, z)) + d2 * (R - 0.004), (0.035, 0.03, 0.05), g.M["steel_dk"], "hard", R=Rr2, what="patte")


def _tank_lights(g, x, y, r, h, e):
    """Petits foyers d'un réservoir (hublots ou fentes) : groupe de 2 à 3, côté sud."""
    M = g.M
    for k, a in enumerate((-1.25, -1.6, -2.15)):
        d = V((math.cos(a), math.sin(a), 0))
        p = V((x, y, h * (0.32 + 0.1 * (k % 2))))
        g.cyl(p + d * (r + 0.01), d, 0.034, 0.03, M["steel_dk"], n=12, what="hublot")
        g.cyl(p + d * (r + 0.027), d, 0.022, 0.006, M["emit"], n=12, style="flat", what="hublot_lum")


# ------------------------------------------------------------------------------------------------
# Petites pièces de signature (E6, ≤ 0,08 t² chacune)
# ------------------------------------------------------------------------------------------------
def signature(g, e, p, kind=0):
    """Petite pièce de signature posée sur un toit de machine (p = point du toit)."""
    M = g.M
    p = V(p)
    if e == 10:
        # antenne fouet courte sur embase, boîtier de connexion
        g.box(p + V((0, 0, 0.03)), (0.12, 0.1, 0.06), M["matte"], "hard", what="boitier")
        g.cyl(p + V((-0.04, 0.03, 0.07)), "z", 0.018, 0.04, M["steel_hi"], n=8, what="embase")
        g.cyl(p + V((-0.04, 0.03, 0.18)), "z", 0.006, 0.2, M["steel_dk"], n=6, what="antenne")
        g.cyl(p + V((-0.03, 0, 0.065)), "z", 0.012, 0.012, M["emit"], n=8, style="flat", what="voyant")
    elif e == 11:
        for s in (-1, 1):
            P2.wedge(g, p + V((s * 0.08, -0.08, 0)), p + V((s * 0.08, 0.1, 0)), p + V((s * 0.08, -0.06, 0.12)),
                     V((0.02, 0, 0)), M["ring"], what="aileron")
    elif e == 12:
        # petite bobine supraconductrice chromée sur colonnettes, givre
        for s in (-1, 1):
            g.cyl(p + V((s * 0.08, 0, 0.06)), "z", 0.015, 0.12, M["steel_dk"], n=8, what="colonnette")
        g.torus(p + V((0, 0, 0.13)), "x", 0.07, 0.022, M["ring"], n=24, m=8, what="bobine")
        g.cyl(p + V((0, 0, 0.13)), "x", 0.03, 0.18, M["jacket"], n=12, what="noyau")
        g.box(p + V((0, -0.06, 0.02)), (0.16, 0.03, 0.03), M["trim"], "flat", what="givre")
    elif e == 13:
        for s in (-1, 1):
            c = p + V((s * 0.06, 0, 0.08))
            g.cyl(c, "z", 0.035, 0.16, M["jacket"], n=14, what="injecteur")
            g.tube_shell(c + V((0, 0, 0.03)), "z", 0.042, 0.03, 0.016, M["copper"], n=14, what="bague")
            g.cyl(c + V((0, 0, 0.085)), "z", 0.02, 0.01, M["emit2"], n=10, style="flat", what="coeur")
    elif e == 14:
        # petit panneau solaire bleu nuit encadré (≤ 5 %), balise rouge
        R = Matrix.Rotation(-0.5, 3, "X")
        g.box(p + V((0, 0, 0.06)), (0.2, 0.16, 0.02), M["ring"], "hard", R=R, what="cadre")
        g.box(p + V((0, -0.004, 0.072)), (0.17, 0.13, 0.006), M["spec"], "flat", R=R, what="cellules")
        g.cyl(p + V((0, 0.04, 0.03)), "z", 0.012, 0.06, M["steel_dk"], n=6, what="pied")
        g.cyl(p + V((0.12, 0.05, 0.03)), "z", 0.016, 0.06, M["steel_dk"], n=8, what="balise_pied")
        g.cyl(p + V((0.12, 0.05, 0.07)), "z", 0.014, 0.02, M["emit"], n=8, style="flat", what="balise")
    else:
        # petite couronne de flèches d'or blanc
        g.cyl(p + V((0, 0, 0.02)), "z", 0.07, 0.04, M["trim"], n=16, what="socle_couronne")
        for k in range(5):
            a = TAU * k / 5
            d = V((math.cos(a), math.sin(a), 0))
            c = p + d * 0.055 + V((0, 0, 0.04))
            P2.wedge(g, c - V((-d.y, d.x, 0)) * 0.02, c + V((-d.y, d.x, 0)) * 0.02, c + d * 0.01 + V((0, 0, 0.1)),
                     d * 0.016, M["jacket"], what="fleche")


# ------------------------------------------------------------------------------------------------
# Pièce du niveau pair (E6 : ≥ 0,10 t² de masque nouveau, en paire aux coins avant)
# ------------------------------------------------------------------------------------------------
def even_piece(g, e, x, yb, sx):
    """Une des deux pièces paires, posée en (x, yb Blender) au sol, côté sx."""
    M = g.M
    E = M["emit"]
    # plinthe commune : caisson blindé bas à bande de danger (toujours posé sur le tablier)
    w, d = 0.62, 0.6
    PT.hull(g, x - w / 2, x + w / 2, yb - d / 2, yb + d / 2, 0.0, 0.14, ins=(0.02, 0.02, 0.02), panel=0.3,
            mats=[M["steel_dk"]], rivet_step=0.12)
    g.hazard([V((x - w / 2, yb - d / 2 - 0.02, 0.02)), V((x + w / 2, yb - d / 2 - 0.02, 0.02)),
              V((x + w / 2, yb - d / 2 - 0.02, 0.12)), V((x - w / 2, yb - d / 2 - 0.02, 0.12))], 6, t=0.012, skew=0.6)
    z0 = 0.14
    P3.lamp_group(g, (x - w / 2 + 0.06, yb - d / 2 - 0.025, 0.07), (1, 0, 0), (0, -1, 0), E, M, n=2,
                  shapes=("rond", "fente"))
    if e == 10:
        # RADÔME de conduite de tir sur affût blindé (embase à armoire), antenne courte
        PT.hull(g, x - 0.22, x + 0.22, yb - 0.24, yb + 0.2, z0, z0 + 0.26, ins=(0.02, 0.02, 0.02), panel=0.22,
                mats=[M["olive"], M["matte"]], rivet_step=0.11)
        P3.lamp_group(g, (x - 0.12, yb - 0.26, z0 + 0.18), (1, 0, 0), (0, -1, 0), E, M, n=3)
        g.cyl((x, yb, z0 + 0.3), "z", 0.19, 0.06, M["steel_dk"], n=28, style="soft", what="embase")
        g.sphere((x, yb, z0 + 0.33), 0.2, M["jacket"], n=32, m=16, scale=(1, 1, 0.92))
        for zz in (0.33, 0.43):
            rr = 0.2 * math.cos(math.asin(min(0.95, (zz - 0.33) / 0.184)))
            g.torus((x, yb, z0 + zz), "z", rr + 0.004, 0.012, M["matte"], n=32, m=6, what="joint")
        g.cyl((x + 0.08, yb + 0.06, z0 + 0.62), "z", 0.006, 0.22, M["steel_dk"], n=6, what="antenne")
        g.cyl((x - 0.1, yb - 0.1, z0 + 0.48), "z", 0.014, 0.012, E, n=8, style="flat", what="voyant")
    elif e == 11:
        # LANCE-MISSILES À AILERONS : caisson 2 × 2 cellules incliné, nez des missiles, ailerons arrière
        g.cyl((x, yb, z0 + 0.04), "z", 0.24, 0.08, M["steel_dk"], n=28, style="soft", what="couronne")
        P3.lamp_group(g, (x - 0.28, yb - 0.31, 0.08), (1, 0, 0), (0, -1, 0), E, M, n=2, shapes=("fente", "rond"))
        P3.lamp_group(g, (x + 0.12, yb - 0.31, 0.08), (1, 0, 0), (0, -1, 0), E, M, n=1, shapes=("carre",))
        g.push((x, yb, z0 + 0.1), rz=0.0, rx=0.3)
        PT.hull(g, -0.24, 0.24, -0.22, 0.22, 0.0, 0.36, ins=(0.01, 0.01, 0.01), panel=0.24,
                mats=[M["olive"], M["jacket"]], rivet_step=0.11, faces="tsewn")
        for i in range(2):
            for j in range(2):
                cx, cz = -0.11 + 0.22 * i, 0.1 + 0.16 * j
                g.cyl((cx, -0.225, cz), "y", 0.072, 0.02, M["void"], n=16, style="flat", what="cellule")
                g.cyl((cx, -0.2, cz), "y", 0.052, 0.12, M["ring"], n=14, r2=0.012, what="nez")
                g.cyl((cx, -0.262, cz), "y", 0.016, 0.006, E, n=8, style="flat", what="pointe")
        for s in (-1, 1):
            P2.wedge(g, V((s * 0.24, 0.0, 0.1)), V((s * 0.24, 0.22, 0.1)), V((s * 0.36, 0.2, 0.06)),
                     V((0, 0, 0.02)), M["ring"], what="aileron")
            P2.wedge(g, V((s * 0.1, 0.1, 0.36)), V((s * 0.1, 0.22, 0.36)), V((s * 0.1, 0.22, 0.47)),
                     V((0.02, 0, 0)), M["ring"], what="aileron")
        g.pop()
    elif e == 12:
        # BOBINE D'ACCÉLÉRATION SUR PYLÔNE : 2 anneaux chromés tenus par un pylône à pinces, noyau noir
        PT.hull(g, x - 0.12, x + 0.12, yb - 0.12, yb + 0.12, z0, z0 + 0.5, ins=(0.03, 0.03, 0.03), panel=0.25,
                mats=[M["steel_dk"], M["jacket"]], rivet_step=0.11)
        zc = z0 + 0.42
        g.cyl((x, yb, zc), "y", 0.06, 0.5, M["jacket"], n=16, what="noyau")
        for dy in (-0.14, 0.12):
            g.tube_shell((x, yb + dy, zc), "y", 0.23, 0.15, 0.07, M["ring"], n=40, what="anneau")
            _seg_ring_y(g, x, yb + dy - 0.037, zc, 0.19, 5, E)
            for s in (-1, 1):
                g.box((x + s * 0.17, yb + dy, zc - 0.13), (0.05, 0.09, 0.14), M["steel_dk"], "hard", what="pince")
        g.box((x, yb, zc - 0.21), (0.44, 0.1, 0.05), M["steel_dk"], "hard", what="traverse")
        g.box((x, yb + 0.2, zc + 0.2), (0.12, 0.05, 0.03), M["trim"], "flat", what="givre")
    elif e == 13:
        # INJECTEUR-CONDENSATEUR À PLASMA : cylindre vertical cerclé de cuivre, tore segmenté, câblage
        c = V((x, yb, z0))
        g.cyl(c + V((0, 0, 0.3)), "z", 0.17, 0.6, M["jacket"], n=28, style="smooth", what="cylindre")
        for zz in (0.06, 0.24, 0.42, 0.58):
            g.tube_shell(c + V((0, 0, zz)), "z", 0.185, 0.16, 0.035, M["copper"], n=28, what="cerclage")
        _seg_ring(g, x, yb, 0.22, z0 + 0.33, 6, E)
        g.cyl(c + V((0, 0, 0.64)), "z", 0.12, 0.06, M["copper"], n=20, what="chapeau")
        g.cyl(c + V((0, 0, 0.68)), "z", 0.06, 0.02, M["emit2"], n=16, style="flat", what="coeur")
        for a in (-1.1, -2.0):
            dd = V((math.cos(a), math.sin(a), 0))
            g.cyl(c + V((0, 0, 0.14)) + dd * 0.17, dd, 0.03, 0.03, M["steel_dk"], n=12, what="hublot")
            g.cyl(c + V((0, 0, 0.14)) + dd * 0.186, dd, 0.02, 0.005, M["emit2"], n=10, style="flat", what="hublot_lum")
        g.hose([tuple(c + V((-sx * 0.15, 0.1, 0.5))), tuple(c + V((-sx * 0.35, 0.3, 0.4))),
                tuple(c + V((-sx * 0.42, 0.55, 0.15)))], 0.04, M["copper"], step=0.03)
    elif e == 14:
        # PARABOLE DE CONDUITE DE TIR DORÉE sur affût blindé : coupelle 0,30, bras, armoire
        PT.hull(g, x - 0.2, x + 0.2, yb - 0.2, yb + 0.2, z0, z0 + 0.22, ins=(0.02, 0.02, 0.02), panel=0.22,
                mats=[M["ring"], M["olive"]], rivet_step=0.11)
        g.cyl((x, yb, z0 + 0.34), "z", 0.045, 0.24, M["steel_dk"], n=12, what="mat")
        g.push((x, yb - 0.02, z0 + 0.5), rx=-0.7)
        n = 28
        vs, fs = [], []
        for i in range(5):
            rr = 0.29 * i / 4
            zz = 0.15 * (rr / 0.29) ** 2
            for j in range(n):
                a = TAU * j / n
                vs.append((rr * math.cos(a), rr * math.sin(a), zz))
        for i in range(4):
            for j in range(n):
                j2 = (j + 1) % n
                fs.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
        g._add(M["jacket"], "flat", vs, fs, "coupelle")
        vs2 = [(v[0], v[1], v[2] - 0.02) for v in vs]
        g._add(M["steel_dk"], "smooth", vs2, [f[::-1] for f in fs], "coupelle_dos")
        g.torus((0, 0, 0.15), "z", 0.29, 0.016, M["ring"], n=40, m=6, what="levre")
        for k in range(3):
            a = TAU * k / 3
            g.cyl((0.15 * math.cos(a), 0.15 * math.sin(a), 0.2), (-math.cos(a), -math.sin(a), 1.3), 0.008, 0.26,
                  M["steel_dk"], n=6, what="hauban")
        g.cyl((0, 0, 0.31), "z", 0.03, 0.05, M["steel_dk"], n=10, what="cornet")
        g.cyl((0, 0, 0.338), "z", 0.02, 0.008, E, n=8, style="flat", what="balise")
        g.pop()
    else:
        # CELLULE D'ÉNERGIE COURONNÉE (niveau 30 témoin, agrandie à 0,10 t²) et couronne de flèches
        P2.power_cell(g, (x, yb, z0), 0.27, 0.66, E, M)
        c = V((x, yb, z0 + 0.66 + 0.12))
        for k in range(5):
            a = TAU * k / 5 + 0.3
            d = V((math.cos(a), math.sin(a), 0))
            q = c + d * 0.18
            P2.wedge(g, q - V((-d.y, d.x, 0)) * 0.035, q + V((-d.y, d.x, 0)) * 0.035, q + d * 0.02 + V((0, 0, 0.17)),
                     d * 0.025, M["jacket"], what="fleche")
        g.torus(c, "z", 0.2, 0.025, M["jacket"], n=36, m=8, what="couronne")


def _seg_ring_y(g, x, y, z, R, n, emat):
    for k in range(n):
        a = TAU * (k + 0.5) / n + 0.3
        d = V((math.cos(a), 0, math.sin(a)))
        if d.z < -0.5:
            continue
        g.box(V((x, y, z)) + d * R, (0.06, 0.008, 0.02), emat, "flat",
              R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed() @ Matrix.Rotation(math.pi / 2, 3, "X"),
              what="segment")


# ------------------------------------------------------------------------------------------------
# Socle
# ------------------------------------------------------------------------------------------------
def column(g, e, ladder_ang):
    M = g.M
    B = BASE[ERA[e]]
    P2.pedestal(g, B["R"], 0.0, B["h"], 16, M, [M["olive"], M["steel_dk"], M["olive"], M["redpaint"]],
                ladder_at=ladder_ang)
    PT.slewing_ring(g, B["R"] - 0.02, B["h"], B["rh"])
    ring_lights(g, e, B["R"] - 0.08, B["h"] + B["rh"] + 0.02)
    ng = {10: 4, 11: 7, 12: 8, 13: 4, 14: 9, 15: 11}[e]
    slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, ng, M["emit"], a0=math.pi + 0.2, span=math.pi - 0.4)
    slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, ng - 1, M["emit"], a0=math.pi + 0.35, span=math.pi - 0.7,
                  per=(3, 2))


def ring_lights(g, e, R, z):
    """Feux de couronne, sur la face sud de la couronne d'orientation (la moitié nord est sous la tête) :
    11 chenillard bleu-blanc (segments courts), 14 balises rouges, 15 « particules » or blanc sur poteaux de nacre.
    Chaque feu est un foyer séparé (espacement > 20 px hr)."""
    n = {11: 13, 14: 20, 15: 22}.get(e, 0)
    M = g.M
    for k in range(n):
        a = math.pi + math.pi * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0))
        t = V((-d.y, d.x, 0))
        Rr = Matrix((t, d, V((0, 0, 1)))).transposed()
        p = V((0, 0, z)) + d * R
        if e == 11:
            g.box(p, (0.1, 0.04, 0.03), M["steel_dk"], "hard", R=Rr, what="support")
            g.box(p + V((0, 0, 0.018)), (0.075, 0.018, 0.008), M["emit"], "flat", R=Rr, what="chenillard")
        elif e == 14:
            g.cyl(p + V((0, 0, 0.02)), "z", 0.028, 0.04, M["steel_dk"], n=10, what="balise_pied")
            g.cyl(p + V((0, 0, 0.048)), "z", 0.019, 0.018, M["emit"], n=10, style="flat", what="balise")
        else:
            g.cyl(p + V((0, 0, 0.035)), "z", 0.016, 0.07, M["trim"], n=8, what="poteau")
            g.sphere(p + V((0, 0, 0.085)), 0.02, M["emit"], n=10, m=6, what="particule")


def socle(g, e, piece=False):
    if ERA[e] == 4:
        _socle_iv(g, e, piece)
    else:
        _socle_v(g, e, piece)


def _socle_iv(g, e, piece):
    """Ère IV (5×5) : corps du niveau 21 de l'industriel. 10 : sans la paire de caisses du nord ; 11 : témoin ;
    12 : + 2e tourelle secondaire et réservoirs plus hauts (catalogue §A.5)."""
    M = g.M
    E = M["emit"]
    cf = {10: 1.15, 11: 0.55, 12: 0.4}[e]
    apron(g, 5, cf, cf * 0.8, inset=0.14, front=2.44)
    column(g, e, -math.pi * 0.7)
    P2.grating(g, 1.35, 1.75, Y(-1.15), Y(1.3), 0.07, M)
    P2.grating(g, -1.55, -1.3, Y(-1.0), Y(-0.3), 0.07, M)
    # sud : trémie, goulotte, caisses ouvertes en biais, tourelle(s) secondaire(s)
    out = P3.hopper_top(g, -0.46, 0.46, Y(-2.4), -1.62, 0.0, 0.66, M)
    P2.feed_chute(g, [tuple(out), (0.0, -1.42, 0.92), (0.0, -1.1, 1.08)], 0.18, M)
    with at(g, -1.5, -1.72, 0.42):
        P2.open_crate(g, (0, 0, 0), 0.78, 0.72, 0.3, M)
    with at(g, -1.05, -2.35, 0.08):
        P2.open_crate(g, (0, 0, 0), 0.6, 0.5, 0.22, M, paint=M["ochre"])
    turrets = [(1.78, -1.82, 0.0)] + ([(-2.0, -2.28, 0.25)] if e >= 12 else [])
    for (x, yn, rz) in turrets:
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.42, 0.0, 0.28, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            _turret_legs(g, e, 0.42, 0.28)
            AG.mini_turret(g, e, (0, 0, 0.28), 0.95, rz)
            if e == 11:
                signature(g, 11, (0.0, -0.18, 0.28 + 0.4 * 0.95))
    # ouest : groupe électrogène à 5 cylindres, liaisons d'énergie vers la colonne
    AG.west(g, e)
    conduit_e(g, e, [(-1.62, Y(0.55), 0.4), (-1.42, Y(0.6), 0.62), (-1.2, Y(0.5), 0.72)], 0.045)
    cables_e(g, e, [(-1.62, Y(-0.25), 0.4), (-1.42, Y(-0.3), 0.6), (-1.18, Y(-0.35), 0.68)])
    # nord-ouest : radiateur à ventilateurs posé en biais
    with at(g, -1.72, 2.02, -0.55):
        AG.nw_iv(g, e)
    # est : deux réservoirs (habillés par époque), pompe à vannes, tuyaux, gaines
    AG.east(g, e, tank_e)
    # sud-ouest : armoire de commande
    P3.cabinet(g, -2.45, -2.02, -2.3, -1.66, 0.0, 0.5, M, E, screen_=(e == 10))
    PT.hull(g, 1.68, 2.36, Y(-1.18), Y(-0.85), 0.0, 0.3, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["redpaint"], M["steel_dk"]], rivet_step=0.12)
    P2.handwheel(g, (2.02, Y(-1.18) - 0.08, 0.2), (0, -1, 0.3), 0.08, M)
    pipe_e(g, e, [(1.68, Y(-1.0), 0.2), (1.45, Y(-1.05), 0.22), (1.25, Y(-0.85), 0.4)], 0.05,
           valve_at=((1.47, Y(-1.04), 0.22), (0, -1, 0.5)))
    hose_e(g, e, [(1.7, Y(1.05), 0.62), (1.45, Y(0.95), 0.98), (1.15, Y(0.75), 0.82)], 0.06)
    # nord-est : armoire de commande ; nord : caisses de réserve (2 dès l'époque 11)
    P3.cabinet(g, 1.25, 2.25, Y(1.95), Y(2.42), 0.0, 0.56, M, E, screen_=(e == 10))
    signature(g, e, (1.55, Y(2.18), 0.6))
    if e >= 11:
        PT.crate(g, (-0.4, Y(1.95), 0.0), (0.66, 0.6, 0.28), mat=M["olive"])
    PT.crate(g, (0.4, Y(1.95), 0.0), (0.66, 0.6, 0.28), mat=M["ochre"])
    signature(g, e, (0.4, Y(1.95), 0.3), 1)
    signature(g, e, (-2.24, -1.98, 0.53), 2)
    if e == 11:
        for p in ((1.75, Y(2.18), 0.6), (-0.4, Y(1.95), 0.3), (2.02, Y(-1.02), 0.3),
                  (-1.95, Y(-1.5), 0.45), (0.0, Y(-2.0), 0.68), (-0.95, Y(-2.35), 0.24)):
            signature(g, 11, p)
    for x in (-0.68, 0.68):
        PT.lamp(g, (x, Y(-2.4) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    if piece:
        for sx in (-1, 1):
            even_piece(g, e, sx * 1.5, Y(-2.64), sx)
        _halo(g, [(-1.5, Y(-2.9), 0.4), (1.5, Y(-2.9), 0.4)], 16.0)
    _halo(g, [(-2.0, Y(-1.1), 0.5), (1.78, Y(-2.1), 0.6), (0.0, Y(-2.5), 0.5), (2.0, Y(0.3), 0.5),
              (1.75, Y(1.8), 0.5)], 20.0)


def _turret_legs(g, e, R, h):
    """Pieds en V (époque 11) ou trépied (13) SOUS les tourelles secondaires, posés sur le tablier plein."""
    M = g.M
    if e == 11:
        for k in range(4):
            a = TAU * (k + 0.5) / 4
            d = V((math.cos(a), math.sin(a), 0))
            for s in (-1, 1):
                t = V((-d.y, d.x, 0))
                g.box(d * (R + 0.08) + t * s * 0.06 + V((0, 0, h * 0.45)), (0.04, 0.04, h * 0.95), M["jacket"], "hard",
                      R=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(s * 0.3, 3, "X"), what="pied_v")
    elif e == 13:
        for k in range(3):
            a = TAU * k / 3 + 0.3
            d = V((math.cos(a), math.sin(a), 0))
            g.box(d * (R + 0.1) + V((0, 0, h * 0.45)), (0.06, 0.06, h * 0.95), M["jacket"], "hard",
                  R=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(-0.35, 3, "Y"), what="trepied")
            g.box(d * (R + 0.18) + V((0, 0, 0.03)), (0.12, 0.12, 0.06), M["steel_dk"], "hard", what="semelle")


def _socle_v(g, e, piece):
    """Ère V (6×6) : corps du niveau 29 de l'industriel. 13 : 2 tourelles secondaires, sans l'armoire nord-est ;
    14 : 3 tourelles (corps du niveau 29) ; 15 : témoin, réservoirs plus hauts (catalogue §A.5)."""
    M = g.M
    E = M["emit"]
    cf = {13: 0.95, 14: 0.7, 15: 0.5}[e]
    apron(g, 6, cf, cf * 0.8, inset=0.16, front=2.78)
    column(g, e, -math.pi * 0.68)
    P2.grating(g, 1.65, 1.95, Y(-1.3), Y(1.45), 0.07, M)
    P2.grating(g, -1.95, -1.65, Y(-1.1), Y(1.1), 0.07, M)
    out = P3.hopper_top(g, -0.54, 0.54, Y(-2.75), -1.95, 0.0, 0.78, M)
    P2.feed_chute(g, [tuple(out), (0.0, -1.75, 1.08), (0.0, -1.38, 1.28)], 0.2, M)
    with at(g, -1.45, -1.95, 0.45):
        P2.open_crate(g, (0, 0, 0), 0.84, 0.78, 0.32, M)
    with at(g, 1.45, -1.95, -0.45):
        P2.open_crate(g, (0, 0, 0), 0.84, 0.78, 0.32, M, paint=M["ochre"])
    turrets = [(-2.4, -2.5, -0.3), (2.4, -2.5, 0.3)] + ([(2.4, 2.45, 1.25 if e == 14 else -0.4)] if e >= 14 else [])
    for (x, yn, rz) in turrets:
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.46, 0.0, 0.32, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            _turret_legs(g, e, 0.46, 0.32)
            AG.mini_turret(g, e, (0, 0, 0.32), 1.02, rz)
            if e == 15:
                signature(g, 15, (0.0, -0.12, 0.32 + 0.4 * 1.02 + 0.01))
            if e == 14:
                signature(g, 14, (0.18, 0.2, 0.32 + 0.4 * 1.02 - 0.02))
    # ouest : groupe électrogène à 6 cylindres ; liaisons
    AG.west(g, e)
    conduit_e(g, e, [(-1.98, Y(0.7), 0.45), (-1.78, Y(0.75), 0.72), (-1.52, Y(0.62), 0.86)], 0.05)
    conduit_e(g, e, [(-1.98, Y(-0.6), 0.45), (-1.78, Y(-0.65), 0.72), (-1.52, Y(-0.55), 0.86)], 0.05)
    cables_e(g, e, [(-1.98, Y(0.05), 0.45), (-1.75, Y(0.02), 0.7), (-1.5, Y(0.0), 0.8)])
    if e == 13:
        signature(g, 13, (-2.43, Y(0.35), 0.6))
    # nord-ouest : banc de condensateurs en biais (réserve d'énergie visible)
    with at(g, -2.05, 2.25, -0.6):
        PT.hull(g, -0.62, 0.62, -0.5, 0.5, 0.0, 0.14, ins=(0.02, 0.02, 0.02), panel=0.3, mats=[M["steel_dk"]],
                rivet_step=0.13)
        PT.capacitors(g, (0.0, 0.0, 0.14), 3, 2, 0.14, 0.48, E)
        P3.lamp_group(g, (-0.5, -0.52, 0.09), (1, 0, 0), (0, -1, 0), E, M, n=3)
        P3.lamp_group(g, (0.2, -0.52, 0.09), (1, 0, 0), (0, -1, 0), M["amber"], M, n=2, shapes=("carre", "fente"))
    conduit_e(g, e, [(-1.6, Y(1.95), 0.5), (-1.35, Y(1.6), 0.8), (-1.1, Y(1.25), 0.95)], 0.05)
    # est : deux réservoirs (habillés par époque), pompe, tuyaux, gaines
    AG.east(g, e, tank_e)
    P3.cabinet(g, -2.85, -2.08, -2.85, -2.2, 0.0, 0.55, M, E)
    if e >= 14:
        P3.cabinet(g, 1.95, 2.85, 2.02, 2.5, 0.0, 0.5, M, E)
    PT.hull(g, 1.98, 2.85, Y(-1.55), Y(-1.18), 0.0, 0.34, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["redpaint"], M["steel_dk"]], rivet_step=0.12)
    for x in (2.15, 2.65):
        P2.handwheel(g, (x, Y(-1.55) - 0.08, 0.22), (0, -1, 0.3), 0.08, M)
    pipe_e(g, e, [(1.98, Y(-1.35), 0.24), (1.75, Y(-1.4), 0.26), (1.55, Y(-1.15), 0.48)], 0.055,
           valve_at=((1.77, Y(-1.39), 0.26), (0, -1, 0.5)))
    if e not in (13, 14):
        hose_e(g, e, [(2.0, Y(1.1), 0.7), (1.72, Y(1.0), 1.12), (1.4, Y(0.8), 0.95)], 0.065)
        hose_e(g, e, [(2.0, Y(-0.45), 0.7), (1.72, Y(-0.5), 1.1), (1.42, Y(-0.4), 0.95)], 0.065)
    else:
        hose_e(g, e, [(1.95, Y(1.0), 0.95), (1.68, Y(0.95), 1.15), (1.4, Y(0.8), 0.95)], 0.06)
        hose_e(g, e, [(1.95, Y(-0.55), 0.95), (1.68, Y(-0.55), 1.12), (1.42, Y(-0.4), 0.95)], 0.06)
    # nord : radiateur à trois ventilateurs ; armoires de commande
    if e == 13:
        AG.torus_bank(g, -1.3, 1.3, Y(2.05), Y(2.78), 0.42)
    elif e == 14:
        AG.solar_array(g, -1.3, 1.3, Y(2.05), Y(2.78), 0.42)
    else:
        P2.fan_radiator(g, -1.3, 1.3, Y(2.05), Y(2.78), 0.0, 0.42, 3, M, emat=E)
    P3.cabinet(g, -1.15, -0.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    P3.cabinet(g, 0.35, 1.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    if e == 15:
        for x in (-2.75, -2.35, 2.05, 2.55):
            g.sphere((x, Y(-2.97) + 0.12, 0.09), 0.022, E, n=10, m=6, what="pierre")
            g.cyl((x, Y(-2.97) + 0.12, 0.04), "z", 0.035, 0.07, M["ring"], n=10, what="pierre_pied")
    signature(g, e, (-0.7, Y(1.79), 0.54))
    signature(g, e, (0.8, Y(1.79), 0.54), 1)
    P2.anchor(g, -2.6, Y(0.0), 0.26, M)
    for x in (-0.8, 0.8):
        PT.lamp(g, (x, Y(-2.75) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    P3.lamp_group(g, (-0.4, Y(-2.75) - 0.03, 0.58), (1, 0, 0), (0, -1, 0), E, M, n=3)
    P3.lamp_group(g, (0.2, Y(-2.75) - 0.03, 0.47), (1, 0, 0), (0, -1, 0), E, M, n=2, shapes=("fente", "rond"))
    if piece:
        for sx in (-1, 1):
            even_piece(g, e, sx * 1.22, Y(-2.97), sx)
        _halo(g, [(-1.22, Y(-3.1), 0.4), (1.22, Y(-3.1), 0.4)], 18.0)
    _halo(g, [(-2.4, Y(-1.2), 0.6), (2.4, Y(-2.7), 0.7), (-2.4, Y(-2.7), 0.7), (0.0, Y(-2.85), 0.5),
              (-2.05, Y(2.25), 0.8), (2.4, Y(0.2), 0.6)], 22.0)
    if e == 13:
        _halo(g, [(2.4, Y(1.0), 0.9), (2.4, Y(-0.55), 0.9)], 10.0, g.M["_emit2_rgb"])


# ------------------------------------------------------------------------------------------------
# Tête (repère de la tête : canons vers +Y)
# ------------------------------------------------------------------------------------------------
def motor(g, c, r, L):
    """Moteur d'entraînement bobiné : carter à ailettes, bobinage de cuivre apparent, flasque boulonnée."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z), "y", r, L, M["steel_dk"], n=28, style="soft", what="moteur")
    nf = int((L * 0.5) / 0.04)
    for k in range(nf):
        g.tube_shell((x, y - L / 2 + 0.04 + k * 0.04, z), "y", r + 0.03, r - 0.01, 0.016, M["steel_hi"], n=28,
                     what="ailette")
    for k in range(4):
        g.torus((x, y + L / 2 - 0.05 - k * 0.034, z), "y", r + 0.006, 0.017, M["copper"], n=28, m=6, what="bobinage")
    g.cyl((x, y - L / 2 - 0.03, z), "y", r * 0.85, 0.06, M["olive"], n=24, style="soft", what="flasque")
    for k in range(8):
        a = TAU * k / 8
        d = V((math.cos(a), 0, math.sin(a)))
        g.dome(V((x, y - L / 2 - 0.06, z)) + d * r * 0.66, V((0, -1, 0)), 0.016, M["rivet"])
    g.cyl((x, y - L / 2 - 0.08, z), "y", r * 0.3, 0.05, M["ring"], n=12, what="moyeu")


def skirt(g, R, z0, z1, mats, nstrips, band_mat):
    """Jupe blindée : âme, bandes de blindage verticales rivetées, cerclages."""
    M = g.M
    g.cyl((0, 0, (z0 + z1) / 2), "z", R, z1 - z0, M["seam"], n=64, style="smooth", what="ame")
    h = z1 - z0
    w = TAU * R / nstrips
    for k in range(nstrips):
        a = TAU * (k + 0.5) / nstrips
        d = V((math.cos(a), math.sin(a), 0.0))
        t = V((-math.sin(a), math.cos(a), 0.0))
        R3 = Matrix((t, d, V((0, 0, 1)))).transposed()
        m = mats[g.rng.randrange(len(mats))]
        th = 0.034 * (1 + 0.3 * (g.rng.random() - 0.5))
        g.box(d * (R + th / 2 - 0.004) + V((0, 0, z0 + h * 0.5)), (w * 0.9, th, h * 0.76), m, "hard", R=R3,
              what="bande")
        for s in (-1, 1):
            g.dome(d * (R + th) + t * (s * w * 0.34) + V((0, 0, z0 + h * 0.78)), d, 0.018, M["rivet"])
    for zz in (z0 + 0.03, z1 - 0.03):
        g.tube_shell((0, 0, zz), "z", R + 0.05, R - 0.02, 0.06, band_mat, n=64, what="cerclage")


def gun_side(g, e, sx, H):
    """Canon rotatif lourd en flanc (lignée) : bras de tourillon, culasse, moteur arrière, faisceau d'époque,
    masque de canon, alimentation d'époque."""
    M = g.M
    x = sx * H["gx"]
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    R = H["R"]
    xa, xb = sorted((sx * R * 0.8, x - sx * wr / 2))
    PT.hull(g, xa, xb, y0 + 0.12, y1 - 0.03, zg - hr * 0.7, zg + hr * 0.55, ins=(0.0, 0.02, 0.02), panel=0.22,
            mats=[M["olive"], M["steel_dk"]], faces="tsn", rivet_step=0.12)
    g.cyl(((xa + xb) / 2, (y0 + y1) / 2 - 0.04, zg - hr * 0.1), "x", hr * 0.62, abs(xb - xa) + 0.12, M["steel_dk"],
          n=20, what="tourillon")
    g.cyl((x + sx * (wr / 2 + 0.03), (y0 + y1) / 2 - 0.04, zg - hr * 0.1), "x", hr * 0.5, 0.06, M["ring"], n=16,
          style="hard", what="chapeau")
    for k in range(6):
        a = TAU * k / 6
        g.dome(V((x + sx * (wr / 2 + 0.065), (y0 + y1) / 2 - 0.04 + math.cos(a) * hr * 0.36,
                  zg - hr * 0.1 + math.sin(a) * hr * 0.36)), (sx, 0, 0), 0.015, M["rivet"])
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=A.recv_mats(g, e))
    motor(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6)
    A.barrel(g, e, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"], H["L"] * 0.5)
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    A.mantle_extra(g, e, x, y1, zg, wr, hr)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    A.feed(g, e, x, sx, H, xo)
    # voyants d'état sur la culasse : 2 segments courts (pas de bande continue)
    for f in (0.28, 0.5):
        g.box((x - sx * wr * 0.22, y0 + (y1 - y0) * f, zg + hr + 0.012), (0.03, (y1 - y0) * 0.12, 0.012), M["emit"],
              "flat", what="etat")
    A.breech_extra(g, e, x, sx, y0, y1, zg, wr, hr)


def head_core(g, e, H):
    """Collier, jupe, coupole rivetée, masque avant, nacelle arrière, tourelleau (lignée, ères IV et V)."""
    M = g.M
    R, zs, rz = H["R"], H["zs"], H["rz"]
    z0 = ring_top(e)
    g.cyl((0, 0, z0 + 0.035), "z", R + 0.07, 0.07, M["steel_dk"], n=56, style="soft", what="collier")
    nb = int(TAU * (R + 0.04) / 0.16)
    for k in range(nb):
        a = TAU * k / nb
        g.dome(((R + 0.04) * math.cos(a), (R + 0.04) * math.sin(a), z0 + 0.07), (0, 0, 1), 0.016, M["rivet"])
    skirt(g, R, z0 + 0.07, zs, [M["olive"], M["olive"], M["steel_dk"]], max(14, int(TAU * R / 0.26)), M["ring"])
    Pf, Nf = P2.dome_hull(g, (0, 0, zs), R, R * 1.06, rz, M["olive"], M, seams=max(12, int(TAU * R / 0.3)),
                          band_mat=M["steel_dk"], ring_seams=(0.5, 0.95))
    mw = R * 0.5
    PT.hull(g, -mw, mw, R * 0.55, R + 0.22, zs - 0.18, zs + rz * 0.5, ins=(0.04, 0.02, R * 0.26), panel=0.22,
            mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    for s, w in ((-1, 0.34), (1, 0.22)):
        g.box((s * mw * 0.42, R + 0.235, zs + 0.02), (mw * w, 0.02, 0.04), M["emit"], "flat", what="fente")
    g.box((0, R + 0.2, zs + 0.065), (mw * 1.3, 0.13, 0.025), M["steel_hi"], "hard", what="visiere")
    g.cyl((mw * 0.45, R + 0.2 + 0.18, zs - 0.06), "y", 0.03, 0.4, M["steel_dk"], n=10, what="coax")
    g.cyl((mw * 0.45, R + 0.2 + 0.28, zs - 0.06), "y", 0.045, 0.16, M["ring"], n=12, what="coax_manchon")
    bx = R * 0.62
    yb0, yb1 = -R - 0.4, -R * 0.5
    T = PT.hull(g, -bx, bx, yb0, yb1, zs - 0.22, zs + rz * 0.42, ins=(0.03, 0.04, 0.0), panel=0.24,
                mats=[M["olive"], M["ochre"]], rivet_step=0.11)
    back = [V((-bx, yb0, zs - 0.22)), V((bx, yb0, zs - 0.22)), T[1], T[0]]
    for (s0, s1) in ((0.08, 0.46), (0.54, 0.92)):
        PT.glow_grille(g, PT.lift(PT.face_quad(back, s0, s1, 0.2, 0.8), 0.03), 4, M["emit_soft"])
    for sx in (-1, 1):
        PT.exhaust(g, (sx * bx * 0.7, (yb0 + yb1) / 2 - 0.05, zs + rz * 0.42), 0.065, 0.28)
    cx, cy = -R * 0.32, -R * 0.12
    zc = zs + rz * math.sqrt(max(0.0, 1 - (cx / R) ** 2 - (cy / (R * 1.06)) ** 2)) - 0.03
    hc, rc = 0.18, 0.22
    g.cyl((cx, cy, zc + hc / 2), "z", rc, hc, M["ochre"], n=24, style="soft", what="tourelleau")
    g.torus((cx, cy, zc + hc), "z", rc - 0.02, 0.018, M["steel_dk"], n=24, m=6, what="jonc")
    nper = 4 + (ERA[e] == 5)
    for k in range(nper):
        a = math.pi / 2 + (k - (nper - 1) / 2) * 0.55
        d = V((math.cos(a), math.sin(a), 0))
        Rr = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
        g.box(V((cx, cy, zc + hc * 0.6)) + d * rc, (0.07, 0.05, 0.06), M["steel_dk"], "hard", R=Rr, what="periscope")
        g.box(V((cx, cy, zc + hc * 0.6)) + d * (rc + 0.028), (0.05, 0.008, 0.03), M["emit"], "flat", R=Rr,
              what="lentille")
    hx, hy = R * 0.34, -R * 0.2
    zh = zs + rz * math.sqrt(max(0.0, 1 - (hx / R) ** 2 - (hy / (R * 1.06)) ** 2)) - 0.02
    PT.hatch(g, (hx, hy, zh), 0.16)
    return Pf, Nf, (cx, cy, zc + hc), (bx, yb0, yb1)


def dome_gun(g, e, H, nb, L, s=1.0):
    """Canon de coupole sur berceau blindé (lignée _tete15), faisceau et frein de l'époque."""
    M = g.M
    zr = H["zs"] + H["rz"] * 0.92
    zc = zr + 0.3 * s
    PT.hull(g, -0.38 * s, 0.38 * s, -0.22 * s, 0.66 * s, zr - 0.04, zr + 0.2 * s, ins=(0.04, 0.04, 0.1),
            panel=0.22, mats=[M["olive"], M["ochre"]], rivet_step=0.11)
    PT.receiver(g, 0.0, -0.22 * s, 0.66 * s, zc - 0.18 * s, zc + 0.16 * s, 0.36 * s, mats=A.recv_mats(g, e))
    rb, rr = 0.052 * s, 0.125 * s * (1.0 if nb == 6 else 0.85)
    A.barrel(g, e, 0.0, 0.66 * s, zc, L, nb, rb, rr, L * 0.4)
    if e == 12:
        # petit canon à rails de coupole : caisson d'accélérateur plein entre les anneaux (aucun jour enfermé sous le
        # canon de flanc, qui le recouvre en pose E)
        kk = (rb + rr) / 0.205
        ro = 0.42 * kk
        ya, yb = 0.66 * s + 0.33 * L, 0.66 * s + 0.98 * L
        g.box((0.0, (ya + yb) / 2, zc + ro * 0.12), (2 * ro * 0.86, yb - ya, 2 * ro * 1.0), M["jacket"], "hard",
              what="caisson")
        for f in (0.2, 0.5, 0.8):
            g.box((0.0, ya + (yb - ya) * f, zc + ro * 0.87), (ro * 1.2, 0.05, 0.012), M["ring"], "hard", what="plaque")
    for sx in (-1, 1):
        PT.piston(g, (sx * 0.26 * s, 0.3 * s, zr + 0.02), (sx * 0.32 * s, 0.6 * s, zr + 0.2 * s), 0.026)
    P2.feed_chute(g, [(0.45 * s, -0.38 * s, zr + 0.05), (0.4 * s, -0.06 * s, zc + 0.12 * s),
                      (0.15 * s, 0.1 * s, zc + 0.17 * s)], 0.12 * s, M)
    if e == 15:
        # petite couronne de flèches sur le berceau
        for k in range(5):
            a = -0.9 + 0.45 * k
            d = V((math.sin(a), -math.cos(a), 0))
            c = V((0, 0.05 * s, zc + 0.16 * s)) + d * 0.2 * s
            P2.wedge(g, c - V((-d.y, d.x, 0)) * 0.025, c + V((-d.y, d.x, 0)) * 0.025, c + V((0, 0, 0.12)),
                     d * 0.018, M["jacket"], what="fleche")
    return zc


def tete(g, e):
    M = g.M
    H = head_params(e)
    Pf, Nf, top_turret, nac = head_core(g, e, H)
    R = H["R"]
    z0 = ring_top(e)
    era5 = ERA[e] == 5
    slits_grouped(g, R, z0 + 0.2, {10: 4, 11: 8, 12: 9, 13: 4, 14: 10, 15: 12}[e], M["emit"])
    if era5:
        slits_grouped(g, R, z0 + 0.36, {13: 3, 14: 10, 15: 12}[e], M["emit"], a0=0.3, per=(3, 2))
    for sx in (-1, 1):
        gun_side(g, e, sx, H)
        # liaisons nacelle -> bras de tourillon : elles passent SUR la coupole et finissent SUR le bras (aucune
        # boucle au-dessus du sol : contrôle des trous enfermés)
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        c = [(sx * 0.3, -R - 0.3, H["zs"] + 0.25), (sx * R * 0.62, -R * 0.42, H["zs"] + H["rz"] * 0.55),
             (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables_e(g, e, c)
        if era5:
            conduit_e(g, e, [(sx * 0.6, -R - 0.3, H["zs"] + 0.2), (sx * R * 0.72, -R * 0.5, H["zs"] + H["rz"] * 0.4),
                             (xe, ye + 0.2, H["zg"] + H["hr"] * 0.55)], 0.04)
    # plaques rapportées (blindage) : 1re rangée qui se complète, puis 2e rangée (catalogue §A.5)
    row1 = {10: (0.6, 1.2, math.pi - 0.6, math.pi - 1.2), 11: (0.5, 0.95, 1.4, math.pi - 0.5, math.pi - 0.95,
                                                                  math.pi - 1.4),
            12: (0.5, 0.95, 1.4, math.pi - 0.5, math.pi - 0.95, math.pi - 1.4),
            13: (0.35, 0.75, 1.15, 2.0, 2.4, 2.8, -0.35), 14: (0.35, 0.75, 1.15, 1.6, 2.0, 2.4, 2.8, -0.35, -0.75,
                                                                 -2.4, -2.8),
            15: (0.35, 0.75, 1.15, 1.6, 2.0, 2.4, 2.8, -0.35, -0.75, -2.4, -2.8)}[e]
    row2 = {12: (0.75, math.pi - 0.75, 1.57), 15: (0.6, 1.25, 1.9, 2.55)}.get(e, ())
    ph1, w1, h1 = (0.32, 0.28, 0.22) if not era5 else (0.3, 0.32, 0.26)
    for i, th in enumerate(row1):
        mat = M["trim"] if (i % 3 == 1 and e != 12) else (M["ochre"] if i % 2 else M["steel_dk"])
        if e == 12:
            mat = M["jacket"] if i % 2 else M["steel_dk"]
        P2.applique(g, Pf, Nf, th, ph1, w1, h1, mat, M)
    for th in row2:
        P2.applique(g, Pf, Nf, th, 0.75, 0.26, 0.22, M["ochre"] if e == 15 else M["jacket"], M)
        if e == 15:
            p = Pf(th, 0.75, 1.0)
            n = Nf(th, 0.75)
            g.push_frame(p + n * 0.066, n, V((-math.sin(th), math.cos(th), 0)))
            g.box((0, 0, 0), (0.27, 0.012, 0.01), M["jacket"], "hard", what="lisere")
            g.box((0, 0.105, 0), (0.27, 0.012, 0.01), M["jacket"], "hard", what="lisere")
            g.pop()
    zt = H["zs"] + H["rz"] * 0.86
    if e == 10:
        # radôme de visée sur le tourelleau, antennes fouet courtes, petit écran sur la nacelle
        for (ax, ay) in ((-0.5, -0.3), (0.55, -0.55)):
            g.cyl((ax * R, ay * R, H["zs"] + H["rz"] * 0.65), "z", 0.02, 0.05, M["steel_hi"], n=8, what="embase")
            g.cyl((ax * R, ay * R, H["zs"] + H["rz"] * 0.65 + 0.2), "z", 0.006, 0.36, M["steel_dk"], n=6,
                  what="antenne")
        bx, yb0, yb1 = nac
        P3.screen(g, (bx * 0.5, (yb0 + yb1) / 2, H["zs"] + H["rz"] * 0.42 + 0.03), (0, 0, 1), 0.14, 0.09, M, M["emit"])
        P3.lamp_group(g, (-bx * 0.6, (yb0 + yb1) / 2 - 0.05, H["zs"] + H["rz"] * 0.42 + 0.005), (1, 0, 0), (0, 0, 1),
                      M["emit"], M, n=3)
    if e == 11:
        g.box((0.0, R * 0.32, zt), (R * 1.25, 0.1, 0.1), M["jacket"], "hard", what="telemetre")
        for sx in (-1, 1):
            g.cyl((sx * R * 0.64, R * 0.32, zt), "x", 0.07, 0.09, M["steel_dk"], n=14, what="telemetre_bout")
            g.cyl((sx * R * 0.64, R * 0.32 + 0.065, zt), "y", 0.045, 0.012, M["emit"], n=12, style="flat",
                  what="lentille")
            g.box((sx * R * 0.3, R * 0.32, zt - 0.1), (0.05, 0.05, 0.12), M["steel_dk"], "hard", what="support")
            P2.wedge(g, V((sx * R * 0.62, R * 0.32 - 0.05, zt + 0.05)), V((sx * R * 0.62, R * 0.32 + 0.05, zt + 0.05)),
                     V((sx * R * 0.62, R * 0.32 - 0.04, zt + 0.15)), V((0.02, 0, 0)), M["ring"], what="aileron")
    if e >= 12:
        nbd = 4 if e == 12 else 6
        s = 0.85 if e == 12 else 1.0
        dome_gun(g, e, H, nbd, 1.02 if e == 12 else 1.7, s)
    if e == 14:
        # petite parabole sur le tourelleau, 2 panneaux dorés repliés le long de la nacelle
        bx, yb0, yb1 = nac
        for sx in (-1, 1):
            xx = sx * (bx + 0.03)
            Rr = Matrix.Rotation(sx * 0.25, 3, "Y")
            g.box((xx, (yb0 + yb1) / 2, H["zs"] + 0.05), (0.03, (yb1 - yb0) * 0.9, 0.3), M["ring"], "hard", R=Rr,
                  what="panneau_cadre")
            for k in range(3):
                g.box((xx + sx * 0.018, yb0 + (yb1 - yb0) * (0.2 + 0.3 * k), H["zs"] + 0.05),
                      (0.006, (yb1 - yb0) * 0.25, 0.24), M["spec"] if k != 1 else M["jacket"], "flat", R=Rr,
                      what="cellules")
            g.cyl((xx, yb0 + 0.05, H["zs"] + 0.24), "z", 0.016, 0.03, M["emit"], n=8, style="flat", what="balise")

    def zsurf(x, y):
        return H["zs"] + H["rz"] * math.sqrt(max(0.0, 1 - (x / R) ** 2 - (y / (R * 1.06)) ** 2))
    AG.dome_top(g, e, H, top_turret, nac, Pf, Nf, zsurf)
    if era5:
        PT.capacitors(g, (0.0, -R - 0.14, H["zs"] + H["rz"] * 0.42), 4, 1, 0.1, 0.22, M["emit"])
        PT.sight(g, (-R * 0.64, R * 0.3, H["zs"] + H["rz"] * 0.5), 0.26, 0.26, 0.15, M["emit"], lenses=2)
    else:
        PT.sight(g, (-R * 0.6, R * 0.32, H["zs"] + H["rz"] * 0.5), 0.2, 0.2, 0.12, M["emit"], lenses=2)
