"""Époque 15 · Légende (ère V, 6×6, niveaux 29 et 30). Constructeur : PLAGE HAUTE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 15) : « couronnes, or blanc, lumière ».
PORTÉ TEL QUEL de la passe 3 (gun_e_haut, commit 4c57982 : design.py, armes.py, ages.py ; outil de portage, code d'origine mot pour
mot ; les aiguillages par époque sont réduits à la branche de l'époque 15) sur le kit commun gun_e : seul le CORPS a
changé (corps.py, kit.py). Aucune correction de design d'époque.
Emplacements remplis : arme (faisceau rotatif LOURD à 6 tubes, jaquette ciselée or blanc et nacre, frein EN COURONNE
de 5 grandes flèches à pierres lumineuses), canon de coupole couronné, 3 tourelles secondaires, grands volumes du
socle (groupe électrogène du témoin n29 ciselé, réservoirs ciselés à flèches, radiateur à 3 ventilateurs), liaisons
(conduits nacrés à bagues d'or blanc), particules sur la couronne d'orientation, COURONNE au-dessus de la tête,
foyers blanc doré, pièce paire (2 cellules d'énergie couronnées).
Défaut relevé par les juges (à corriger par le constructeur) : lue « railgun », rangée SOUS 13 et 14 (progression).
"""
import math

from mathutils import Matrix, Vector

import corps
import formes as F
import parts as PT
import parts2 as P2
import parts3 as P3
from corps import Y, at
from kit import SQ2, TAU, axv, basis

V = Vector

EPOQUE = 15
NOM = "Légende"
FOYER = dict(rgb=(1.0, 0.949, 0.753), rgb2=(1.0, 0.949, 0.753))
CANON = dict(L=2.5, nb=6, rb=0.072, rr=0.175)
PLATEFORME = dict(chanfrein=0.5)
HABILLAGE = dict(jupe_cerclage="ring", chapeau="ring")
RECV = ("ochre", "olive")


def matieres(metal, M):
    """Légende : or blanc patiné, nacre."""
    metal("jacket", (0.6, 0.52, 0.32), rough=0.26, met=0.95, grain=0.14, gscale=40.0, rust=(0.25, 0.12, 0.05),
          ra=0.1, dirt=0.85, stain=0.35, sscale=6.0, wear=0.5)
    # bagues, flèches de couronne : or blanc PATINÉ, plus rugueux (aucun éclat blanc franc : « pas de bague blanche »)
    metal("ring", (0.46, 0.39, 0.22), rough=0.42, met=0.9, grain=0.18, gscale=36.0, rust=(0.25, 0.12, 0.05),
          ra=0.14, dirt=0.9, stain=0.5, sscale=6.0, wear=0.6)
    metal("trim", (0.5, 0.47, 0.42), rough=0.3, met=0.15, grain=0.12, gscale=30.0, dirt=0.9, stain=0.5,
          sscale=5.0, wear=0.6, streak=0.4)                                                        # nacre
    M["pipe"] = M["trim"]
    M["pipe2"] = M["jacket"]
    M["cable_a"], M["cable_b"] = M["rubber"], M["redcable"]
    M["spec"] = M["trim"]
    M["accent"] = M["trim"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 29 de l'industriel, témoin ; 15 : réservoirs plus hauts)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    ring_lights(g, B["R"] - 0.08, B["h"] + B["rh"] + 0.02)
    ng = 11
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, ng, M["emit"], a0=math.pi + 0.2, span=math.pi - 0.4)
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, ng - 1, M["emit"], a0=math.pi + 0.35, span=math.pi - 0.7,
                    per=(3, 2))
    P2.grating(g, 1.65, 1.95, Y(-1.3), Y(1.45), 0.07, M)
    P2.grating(g, -1.95, -1.65, Y(-1.1), Y(1.1), 0.07, M)
    with at(g, -1.45, -1.95, 0.45):
        P2.open_crate(g, (0, 0, 0), 0.84, 0.78, 0.32, M)
    with at(g, 1.45, -1.95, -0.45):
        P2.open_crate(g, (0, 0, 0), 0.84, 0.78, 0.32, M, paint=M["ochre"])
    for (x, yn, rz) in [(-2.4, -2.5, -0.3), (2.4, -2.5, 0.3), (2.4, 2.45, -0.4)]:
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.46, 0.0, 0.32, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            mini_turret(g, (0, 0, 0.32), 1.02, rz)
            signature(g, (0.0, -0.12, 0.32 + 0.4 * 1.02 + 0.01))
    # ouest : groupe électrogène à 6 cylindres ; liaisons
    west(g)
    conduit(g, [(-1.98, Y(0.7), 0.45), (-1.78, Y(0.75), 0.72), (-1.52, Y(0.62), 0.86)], 0.05)
    conduit(g, [(-1.98, Y(-0.6), 0.45), (-1.78, Y(-0.65), 0.72), (-1.52, Y(-0.55), 0.86)], 0.05)
    cables(g, [(-1.98, Y(0.05), 0.45), (-1.75, Y(0.02), 0.7), (-1.5, Y(0.0), 0.8)])
    # nord-ouest : banc de condensateurs en biais (réserve d'énergie visible)
    with at(g, -2.05, 2.25, -0.6):
        PT.hull(g, -0.62, 0.62, -0.5, 0.5, 0.0, 0.14, ins=(0.02, 0.02, 0.02), panel=0.3, mats=[M["steel_dk"]],
                rivet_step=0.13)
        PT.capacitors(g, (0.0, 0.0, 0.14), 3, 2, 0.14, 0.48, E)
        P3.lamp_group(g, (-0.5, -0.52, 0.09), (1, 0, 0), (0, -1, 0), E, M, n=3)
        P3.lamp_group(g, (0.2, -0.52, 0.09), (1, 0, 0), (0, -1, 0), M["amber"], M, n=2, shapes=("carre", "fente"))
    conduit(g, [(-1.6, Y(1.95), 0.5), (-1.35, Y(1.6), 0.8), (-1.1, Y(1.25), 0.95)], 0.05)
    east(g)
    P3.cabinet(g, -2.85, -2.08, -2.85, -2.2, 0.0, 0.55, M, E)
    P3.cabinet(g, 1.95, 2.85, 2.02, 2.5, 0.0, 0.5, M, E)
    PT.hull(g, 1.98, 2.85, Y(-1.55), Y(-1.18), 0.0, 0.34, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["redpaint"], M["steel_dk"]], rivet_step=0.12)
    for x in (2.15, 2.65):
        P2.handwheel(g, (x, Y(-1.55) - 0.08, 0.22), (0, -1, 0.3), 0.08, M)
    pipe(g, [(1.98, Y(-1.35), 0.24), (1.75, Y(-1.4), 0.26), (1.55, Y(-1.15), 0.48)], 0.055,
         valve_at=((1.77, Y(-1.39), 0.26), (0, -1, 0.5)))
    hose(g, [(2.0, Y(1.1), 0.7), (1.72, Y(1.0), 1.12), (1.4, Y(0.8), 0.95)], 0.065)
    hose(g, [(2.0, Y(-0.45), 0.7), (1.72, Y(-0.5), 1.1), (1.42, Y(-0.4), 0.95)], 0.065)
    # nord : radiateur à trois ventilateurs ; armoires de commande
    P2.fan_radiator(g, -1.3, 1.3, Y(2.05), Y(2.78), 0.0, 0.42, 3, M, emat=E)
    P3.cabinet(g, -1.15, -0.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    P3.cabinet(g, 0.35, 1.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    for x in (-2.75, -2.35, 2.05, 2.55):
        g.sphere((x, Y(-2.97) + 0.12, 0.09), 0.022, E, n=10, m=6, what="pierre")
        g.cyl((x, Y(-2.97) + 0.12, 0.04), "z", 0.035, 0.07, M["ring"], n=10, what="pierre_pied")
    signature(g, (-0.7, Y(1.79), 0.54))
    signature(g, (0.8, Y(1.79), 0.54), 1)
    P2.anchor(g, -2.6, Y(0.0), 0.26, M)
    for x in (-0.8, 0.8):
        PT.lamp(g, (x, Y(-2.75) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    P3.lamp_group(g, (-0.4, Y(-2.75) - 0.03, 0.58), (1, 0, 0), (0, -1, 0), E, M, n=3)
    P3.lamp_group(g, (0.2, Y(-2.75) - 0.03, 0.47), (1, 0, 0), (0, -1, 0), E, M, n=2, shapes=("fente", "rond"))
    _halo(g, [(-2.4, Y(-1.2), 0.6), (2.4, Y(-2.7), 0.7), (-2.4, Y(-2.7), 0.7), (0.0, Y(-2.85), 0.5),
              (-2.05, Y(2.25), 0.8), (2.4, Y(0.2), 0.6)], 22.0)


def ring_lights(g, R, z):
    """Feux de couronne (face sud de la couronne d'orientation) : « particules » or blanc sur poteaux de nacre, chaque
    feu un foyer séparé."""
    n = 22
    M = g.M
    for k in range(n):
        a = math.pi + math.pi * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0))
        p = V((0, 0, z)) + d * R
        g.cyl(p + V((0, 0, 0.035)), "z", 0.016, 0.07, M["trim"], n=8, what="poteau")
        g.sphere(p + V((0, 0, 0.085)), 0.02, M["emit"], n=10, m=6, what="particule")


def west(g):
    """Groupe de l'ouest : groupe électrogène à 6 cylindres du témoin n29, trappes de nacre cerclées d'or blanc,
    pierres lumineuses."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1, h = -2.88, -1.98, Y(-1.35), Y(1.35), 0.6
    P2.engine(g, x0, x1, y0, y1, 0.0, h, 6, M, emat=E)
    F.hatches(g, (x0 - 0.005, y0 + 0.2, h * 0.25), (x0 - 0.005, y1 - 0.2, h * 0.25), 10, (-1, 0, 0), M["trim"],
              size=(0.07, 0.05), frame=M["ring"])
    F.hatches(g, (x1 + 0.005, y0 + 0.2, h * 0.3), (x1 + 0.005, y1 - 0.2, h * 0.3), 10, (1, 0, 0), M["trim"],
              size=(0.07, 0.05), frame=M["ring"])
    for yy in (y0 + 0.3, y1 - 0.3):
        g.sphere((x0 + 0.08, yy, h + 0.03), 0.022, E, n=10, m=6, what="pierre")


def east(g):
    """Est : deux réservoirs debout ciselés (habillés par l'époque), trappes de nacre et d'or blanc, pierres."""
    M = g.M
    tank(g, 2.4, Y(1.0), 0.44, 1.1, (1, 0.2), (-1, 0), gauges=3)
    tank(g, 2.4, Y(-0.55), 0.44, 1.1, (1, -0.2), (-1, 0), gauges=3)
    for (cx_, cy_) in ((2.4, Y(1.0)), (2.4, Y(-0.55))):
        for kk in range(9):
            a = math.pi + math.pi * (kk + 0.5) / 9
            d = V((math.cos(a), math.sin(a), 0))
            F.hatches(g, V((cx_, cy_, 0.25)) + d * 0.43, V((cx_, cy_, 0.29)) + d * 0.43, 1, d, M["trim"],
                      size=(0.07, 0.05))
            F.hatches(g, V((cx_, cy_, 0.86)) + d * 0.43, V((cx_, cy_, 0.9)) + d * 0.43, 1, d, M["ring"],
                      size=(0.06, 0.05))
        for (bx_, by_) in ((cx_ - 0.6, cy_ - 0.2), (cx_ + 0.3, cy_ - 0.5)):
            g.sphere((bx_, by_, 0.1), 0.02, M["emit"], n=10, m=6, what="pierre")
            g.cyl((bx_, by_, 0.05), "z", 0.035, 0.07, M["ring"], n=10, what="pierre_pied")


def tank(g, x, y, r, h, ladder_dir, stub_dir, gauges=2, rings=1):
    """Réservoir debout de la lignée (P3.vtank) crème cerclé d'or blanc, hublots ; bande ciselée de losanges d'or
    blanc sertis de nacre, 5 flèches sur le fond bombé."""
    M = g.M
    E = M["emit"]
    P3.vtank(g, x, y, r, h, M, paint=M["cream"], emat=E, ladder_dir=ladder_dir, stub_dir=stub_dir, gauges=gauges,
             glow_gauges=True, glow_rings=0, band=M["jacket"])
    F.tank_lights(g, x, y, r, h, EPOQUE)
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
    for k in range(5):
        a = TAU * k / 5 + 0.3
        d = V((math.cos(a), math.sin(a), 0))
        c = V((x, y, h + r * 0.2)) + d * r * 0.55
        P2.wedge(g, c, c + d * 0.05, c + d * 0.02 + V((0, 0, 0.13)), V((-d.y, d.x, 0)) * 0.02, M["jacket"],
                 what="fleche")


def crown(g, c, R, n=10, h=0.26, gems_all=False):
    """Couronne d'or blanc au-dessus de la tête : bandeau, fleurons en flèche, pierres lumineuses, tenue par 5 montants
    posés sur la coupole (rien ne flotte)."""
    M = g.M
    E = M["emit"]
    c = V(c)
    g.tube_shell(c, "z", R + 0.03, R - 0.03, 0.1, M["ring"], n=64, what="bandeau")
    g.torus(c + V((0, 0, 0.05)), "z", R + 0.03, 0.014, M["jacket"], n=64, m=6, what="jonc")
    g.torus(c - V((0, 0, 0.05)), "z", R + 0.03, 0.014, M["jacket"], n=64, m=6, what="jonc")
    for k in range(n):
        a = TAU * k / n
        d = V((math.cos(a), math.sin(a), 0))
        t = V((-d.y, d.x, 0))
        p = c + d * (R + 0.01) + V((0, 0, 0.05))
        hk = h * (1.0 if k % 2 == 0 else 0.62)
        P2.wedge(g, p - t * 0.075, p + t * 0.075, p + V((0, 0, hk)), d * 0.03, M["jacket"], what="fleuron")
        if k % 2 == 0 or gems_all:
            g.sphere(p + V((0, 0, hk + 0.02)) + d * 0.004, 0.022, E, n=10, m=6, what="pierre")
        a3 = a + TAU / n * 0.5
        d3 = V((math.cos(a3), math.sin(a3), 0))
        g.box(c + d3 * (R + 0.036), (0.07, 0.016, 0.05), M["trim"], "hard", R=Matrix.Rotation(a3 + math.pi / 2, 3, "Z"),
              what="nacre")
        for j in range(3):
            a2 = a + TAU / n * (j + 0.5) / 3
            d2 = V((math.cos(a2), math.sin(a2), 0))
            g.dome(c + d2 * (R + 0.032), d2, 0.012, M["rivet"])
        g.box(c + d * (R + 0.035) - V((0, 0, 0.0)), (0.02, 0.02, 0.02), M["trim"], "hard", R=Matrix.Rotation(a, 3, "Z"),
              what="sertissure")


def signature(g, p, kind=0):
    """Petite pièce de signature : petite couronne de flèches d'or blanc sur socle de nacre."""
    M = g.M
    p = V(p)
    g.cyl(p + V((0, 0, 0.02)), "z", 0.07, 0.04, M["trim"], n=16, what="socle_couronne")
    for k in range(5):
        a = TAU * k / 5
        d = V((math.cos(a), math.sin(a), 0))
        c = p + d * 0.055 + V((0, 0, 0.04))
        P2.wedge(g, c - V((-d.y, d.x, 0)) * 0.02, c + V((-d.y, d.x, 0)) * 0.02, c + d * 0.01 + V((0, 0, 0.1)),
                 d * 0.016, M["jacket"], what="fleche")


def mini_turret(g, c, s, rz):
    """Tourelle secondaire : couronne et caisson de la lignée, les DEUX ARMES sont celles de l'époque."""
    M = g.M
    E = M["emit"]
    g.push(c, rz=rz)
    g.cyl((0, 0, 0.05 * s), "z", 0.36 * s, 0.1 * s, M["armor2"], n=32, style="soft", what="couronne")
    nb = int(TAU * 0.32 * s / 0.1)
    for k in range(nb):
        a = TAU * k / nb
        g.dome((0.31 * s * math.cos(a), 0.31 * s * math.sin(a), 0.1 * s), (0, 0, 1), 0.016, M["rivet"])
    PT.hull(g, -0.24 * s, 0.24 * s, -0.3 * s, 0.24 * s, 0.1 * s, 0.4 * s, ins=(0.04 * s, 0.03 * s, 0.1 * s), panel=0.22,
            mats=[M["armor"], M["khaki"]])
    for sx in (-1, 1):
        PT.receiver(g, sx * 0.31 * s, -0.16 * s, 0.22 * s, 0.16 * s, 0.36 * s, 0.13 * s, mats=[M[k] for k in RECV])
        _gun15(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
    PT.lamp(g, (0.0, 0.12 * s, 0.4 * s + 0.01), (0, 0.35, 1), 0.035, E, cage=False)
    PT.hatch(g, (0.0, -0.12 * s, 0.4 * s), 0.09 * s)
    g.pop()


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : conduits nacrés à bagues d'or blanc, conduits lumineux
# ------------------------------------------------------------------------------------------------
def hose(g, ctrl, r):
    """Conduit nacré à bagues d'or blanc."""
    M = g.M
    P, T = g.tube(g.spline(ctrl, 10), r, M["trim"], n=12, what="conduit_nacre")
    for i in range(2, len(P) - 1, 5):
        g.tube_shell(P[i], T[i], r + 0.016, r - 0.01, 0.035, M["jacket"], n=14, what="bague_or")


def cables(g, ctrl, n=3):
    M = g.M
    PT.cable_run(g, ctrl, n, 0.02, 0.045, [M["rubber"], M["redcable"], M["rubber"]])


def conduit(g, ctrl, r):
    """Conduit d'énergie : bagues lumineuses PAR GROUPES (chenillard), colliers d'or blanc."""
    M = g.M
    P = g.spline(ctrl, 10)
    P, T = g.tube(P, r, M["steel_dk"], n=10, what="conduit")
    R = g.resample(P, 0.075)
    T2, _ = g.frames(R)
    for i in range(1, len(R) - 1):
        if i % 4 in (1, 2):
            g.tube_shell(R[i], T2[i], r + 0.008, r * 0.5, 0.03, M["emit"], n=12, what="bague_lum")
        elif i % 4 == 3:
            g.tube_shell(R[i], T2[i], r + 0.016, r * 0.5, 0.03, M["pipe2"], n=12, what="collier")


def pipe(g, ctrl, r, valve_at=None):
    M = g.M
    g.pipe(ctrl, r, M["trim"], fl_mat=M["pipe2"], bolt_mat=M["rivet"])
    if valve_at is not None:
        p, ax = valve_at
        g.box(p, (r * 3.2, r * 3.2, r * 3.2), M["steel_dk"], "hard", what="corps_vanne")
        P2.handwheel(g, V(p) + V(ax).normalized() * (r * 1.6 + 0.06), ax, 0.07, M)


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 30 : 2 cellules d'énergie couronnées (témoin n30, agrandies)
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.22, Y(-2.97), sx)
    _halo(g, [(-1.22, Y(-3.1), 0.4), (1.22, Y(-3.1), 0.4)], 18.0)


def even_piece(g, x, yb, sx):
    """CELLULE D'ÉNERGIE COURONNÉE (niveau 30 témoin, agrandie à 0,10 t²) et couronne de flèches, sur la plinthe
    commune (caisson blindé bas à bande de danger)."""
    M = g.M
    E = M["emit"]
    w, d = 0.62, 0.6
    PT.hull(g, x - w / 2, x + w / 2, yb - d / 2, yb + d / 2, 0.0, 0.14, ins=(0.02, 0.02, 0.02), panel=0.3,
            mats=[M["steel_dk"]], rivet_step=0.12)
    g.hazard([V((x - w / 2, yb - d / 2 - 0.02, 0.02)), V((x + w / 2, yb - d / 2 - 0.02, 0.02)),
              V((x + w / 2, yb - d / 2 - 0.02, 0.12)), V((x - w / 2, yb - d / 2 - 0.02, 0.12))], 6, t=0.012, skew=0.6)
    z0 = 0.14
    P3.lamp_group(g, (x - w / 2 + 0.06, yb - d / 2 - 0.025, 0.07), (1, 0, 0), (0, -1, 0), E, M, n=2,
                  shapes=("rond", "fente"))
    P2.power_cell(g, (x, yb, z0), 0.27, 0.66, E, M)
    c = V((x, yb, z0 + 0.66 + 0.12))
    for k in range(5):
        a = TAU * k / 5 + 0.3
        d_ = V((math.cos(a), math.sin(a), 0))
        q = c + d_ * 0.18
        P2.wedge(g, q - V((-d_.y, d_.x, 0)) * 0.035, q + V((-d_.y, d_.x, 0)) * 0.035, q + d_ * 0.02 + V((0, 0, 0.17)),
                 d_ * 0.025, M["jacket"], what="fleche")
    g.torus(c, "z", 0.2, 0.025, M["jacket"], n=36, m=8, what="couronne")


# ------------------------------------------------------------------------------------------------
# Arme (E1) : faisceau lourd ciselé, frein en couronne
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse, moteur arrière, arme d'époque, masque de canon,
    alimentation, voyants d'état, chapeau de nacre et petite couronne sur la culasse."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _gun15(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    for f in (0.28, 0.5):
        g.box((x - sx * wr * 0.22, y0 + (y1 - y0) * f, zg + hr + 0.012), (0.03, (y1 - y0) * 0.12, 0.012), M["emit"],
              "flat", what="etat")
    # chapeau de nacre, liseré d'or blanc et petite couronne de 5 flèches sur la culasse
    zt = zg + hr + 0.012
    g.box((x, (y0 + y1) / 2, zt + 0.018), (wr * 0.7, (y1 - y0) * 0.5, 0.025), M["trim"], "hard", what="nacre")
    g.box((x, (y0 + y1) / 2, zt + 0.034), (wr * 0.74, 0.02, 0.012), M["jacket"], "hard", what="liseré")
    cc = V((x, (y0 + y1) / 2 + 0.12, zt + 0.03))
    for kk in range(5):
        a = TAU * kk / 5
        d = V((math.cos(a), math.sin(a), 0))
        P2.wedge(g, cc + d * 0.07, cc + d * 0.08 + V((-d.y, d.x, 0)) * 0.03, cc + d * 0.075 + V((0, 0, 0.11)),
                 V((-d.y, d.x, 0)) * 0.02, M["jacket"], what="fleche")
    g.cyl(cc + V((0, 0, 0.01)), "z", 0.07, 0.02, M["jacket"], n=20, what="socle_couronne")


def _gun15(g, x, y0, z, L, nb, rb, rr):
    M = g.M
    E = M["emit"]
    k = F.k_arme(rb, rr)
    rb2, rr2 = rb * 1.12, rr * 1.04
    F.tubes(g, x, y0, z, L, nb, rb2, rr2)
    R0 = rr2 + rb2
    rs = R0 + 0.028
    Ls = 0.52 * L
    yc = y0 + Ls / 2
    g.cyl((x, yc, z), "y", rs, Ls, M["jacket"], n=32, style="smooth", what="jaquette")
    for f in (0.03, 0.97):
        g.tube_shell((x, y0 + f * Ls, z), "y", rs + 0.028, rs - 0.01, 0.065, M["ring"], n=32, what="bague")
    for f in (0.3, 0.64):
        g.tube_shell((x, y0 + f * Ls, z), "y", rs + 0.03, rs - 0.01, 0.1, M["trim"], n=32, what="bande_nacre")
        for d in F.ring_dirs(10, 0.0, -0.5):
            R = F.Rax(d) @ Matrix.Rotation(math.pi / 4, 3, "Z")
            for dy in (-0.035, 0.035):
                g.box(V((x, y0 + f * Ls + dy, z)) + d * (rs + 0.03), (0.028, 0.028, 0.01), M["jacket"], "hard", R=R,
                      what="ciselure")
    for i in range(3):
        yy = y0 + Ls * (0.13 + 0.34 * i) + 0.02
        for d in F.ring_dirs(9, 0.35 * (i % 2), -0.45):
            R = F.Rax(d) @ Matrix.Rotation(math.pi / 4, 3, "Z")
            g.box(V((x, yy, z)) + d * (rs + 0.004), (0.05, 0.05, 0.014), M["trim"], "hard", R=R, what="ciselure")
            g.box(V((x, yy, z)) + d * (rs + 0.012), (0.024, 0.024, 0.008), M["jacket"], "hard", R=R, what="ciselure")
    for f in (0.66, 0.88):
        F.collar(g, x, y0 + f * L, z, R0 + 0.024, rr2 * 0.3, 0.05, M["ring"])
    # frein EN COURONNE : bague, 5 grandes flèches évasées, 5 flèches de nacre, pierres lumineuses
    yb = y0 + L + 0.06
    g.tube_shell((x, yb, z), "y", rs + 0.05, rr2 * 0.4, 0.15, M["ring"], n=36, what="couronne")
    g.tube_shell((x, yb + 0.076, z), "y", rs + 0.03, rs, 0.012, E, n=36, what="liseré_lum")
    for d in F.ring_dirs(5, math.pi / 2 + math.pi / 5, -0.95):
        R = F.Rax(d)
        t = R.col[0] * 0.034 * k
        c = V((x, 0, z))
        # flèche en feuille : base large (arrière), pointe évasée vers l'avant
        pa = c + d * (rs - 0.01) + V((0, yb - 0.1, 0))
        pb = c + d * (rs + 0.13 * k) + V((0, yb - 0.02, 0))
        pt = c + d * (rs + 0.27 * k) + V((0, yb + 0.32 * k, 0))
        pi_ = c + d * (rs + 0.02) + V((0, yb + 0.14 * k, 0))
        P2.wedge(g, pa, pb, pt, t * 2.2, M["ring"], what="fleche")
        P2.wedge(g, pa, pt, pi_, t * 2.2, M["ring"], what="fleche")
        P2.wedge(g, c + d * (rs - 0.02) + V((0, yb, 0)), c + d * (rs + 0.05 * k) + V((0, yb, 0)),
                 c + d * (rs + 0.06 * k) + V((0, yb + 0.2 * k, 0)), t * 1.3, M["trim"], what="fleche")
        g.sphere(c + d * (rs + 0.23 * k) + V((0, yb + 0.28 * k, 0)), 0.02 * k, E, n=10, m=6, what="pierre")
        g.dome(c + d * (rs + 0.1 * k) + V((0, yb + 0.05, 0)) + t * 0.6, R.col[0], 0.013, M["rivet"])
    F.muzzle_glow(g, x, yb + 0.077, z, rr2 * 0.62)
    return yb + 0.3 * k


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisse (volume de la lignée) kaki et ocre, CELLULE D'ÉNERGIE à couronne lumineuse,
    goulotte, voyants."""
    M = g.M
    E = M["emit"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    y0, y1 = H["recv"]
    bw, bl, bh = 0.32 * wr / 0.4, 0.75 * H["L"] / 1.95, 0.5 * hr / 0.23
    bl = min(bl, 0.95)
    bx0, bx1 = sorted((xo + sx * 0.02, xo + sx * (0.02 + bw)))
    bc = (bx0 + bx1) / 2
    yb0, yb1 = y0 - 0.1, y0 - 0.1 + bl
    zb0, zb1 = zg - bh * 0.62, zg + bh * 0.42
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=[M["olive"], M["ochre"]],
            rivet_step=0.11)
    ztop = zb1 + 0.015
    g.hazard(PT.lift([V((bx0, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.2, zb1)),
                      V((bx0, yb0 + bl * 0.2, zb1))], 0.012), 4, t=0.01)
    cw = 0.12 * wr / 0.4 + 0.04
    c = V((bc, yb0 + bl * 0.3, ztop))
    g.cyl(c + V((0, 0, 0.08)), "z", 0.07, 0.16, M["steel_dk"], n=20, what="cellule")
    for zz in (0.03, 0.13):
        g.tube_shell(c + V((0, 0, zz)), "z", 0.078, 0.06, 0.02, M["jacket"], n=20, what="cerclage")
    g.tube_shell(c + V((0, 0, 0.165)), "z", 0.055, 0.042, 0.016, E, n=20, what="couronne_lum")
    for k in range(5):
        a = TAU * k / 5
        d = V((math.cos(a), math.sin(a), 0))
        P2.wedge(g, c + d * 0.06 + V((0, 0, 0.16)), c + d * 0.07 + V((0, 0, 0.16)),
                 c + d * 0.065 + V((0, 0, 0.23)), V((-d.y, d.x, 0)) * 0.018, M["jacket"], what="fleche")
    P2.feed_chute(g, [(bc, yb0 + bl * 0.7, ztop + 0.005), (bc - sx * 0.05, y0 + bl * 0.65, zg + bh * 0.62),
                      (x + sx * wr * 0.25, y0 + bl * 0.55, zg + hr + 0.06)], cw, M)
    P3.lamp_group(g, (bc + sx * bw * 0.3, yb0 + bl * 0.08, ztop - 0.005), (0, 1, 0), (0, 0, 1),
                  E, M, n=3, shapes=("rond", "carre", "fente"))
    return bc


def dome_gun(g, H, nb, L, s=1.0):
    """Canon de coupole sur berceau blindé (lignée _tete15), arme de l'époque, petite couronne de flèches."""
    M = g.M
    zr = H["zs"] + H["rz"] * 0.92
    zc = zr + 0.3 * s
    PT.hull(g, -0.38 * s, 0.38 * s, -0.22 * s, 0.66 * s, zr - 0.04, zr + 0.2 * s, ins=(0.04, 0.04, 0.1),
            panel=0.22, mats=[M["olive"], M["ochre"]], rivet_step=0.11)
    PT.receiver(g, 0.0, -0.22 * s, 0.66 * s, zc - 0.18 * s, zc + 0.16 * s, 0.36 * s, mats=[M[k] for k in RECV])
    rb, rr = 0.052 * s, 0.125 * s * (1.0 if nb == 6 else 0.85)
    _gun15(g, 0.0, 0.66 * s, zc, L, nb, rb, rr)
    for sx in (-1, 1):
        PT.piston(g, (sx * 0.26 * s, 0.3 * s, zr + 0.02), (sx * 0.32 * s, 0.6 * s, zr + 0.2 * s), 0.026)
    P2.feed_chute(g, [(0.45 * s, -0.38 * s, zr + 0.05), (0.4 * s, -0.06 * s, zc + 0.12 * s),
                      (0.15 * s, 0.1 * s, zc + 0.17 * s)], 0.12 * s, M)
    # petite couronne de flèches sur le berceau
    for k in range(5):
        a = -0.9 + 0.45 * k
        d = V((math.sin(a), -math.cos(a), 0))
        c = V((0, 0.05 * s, zc + 0.16 * s)) + d * 0.2 * s
        P2.wedge(g, c - V((-d.y, d.x, 0)) * 0.025, c + V((-d.y, d.x, 0)) * 0.025, c + V((0, 0, 0.12)),
                 d * 0.018, M["jacket"], what="fleche")
    return zc


# ------------------------------------------------------------------------------------------------
# Masque et tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=("ochre", "olive"), fentes=((-0.42, 0.34), (0.42, 0.22)), visiere=("steel_hi", 0.13),
                        coax=dict(fut="steel_dk", manchon="ring", manchon_y=0.28, manchon_r=0.045, manchon_L=0.16))


def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    z0 = c.rt
    F.slits_grouped(g, R, z0 + 0.2, 12, M["emit"])
    F.slits_grouped(g, R, z0 + 0.36, 12, M["emit"], a0=0.3, per=(3, 2))
    for sx in (-1, 1):
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, H["zs"] + 0.25), (sx * R * 0.62, -R * 0.42, H["zs"] + H["rz"] * 0.55),
              (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
        conduit(g, [(sx * 0.6, -R - 0.3, H["zs"] + 0.2), (sx * R * 0.72, -R * 0.5, H["zs"] + H["rz"] * 0.4),
                    (xe, ye + 0.2, H["zg"] + H["hr"] * 0.55)], 0.04)
    # blindage à plaques multiples : deux rangées de plaques rapportées, liserés d'or blanc
    row1 = (0.35, 0.75, 1.15, 1.6, 2.0, 2.4, 2.8, -0.35, -0.75, -2.4, -2.8)
    ph1, w1, h1 = (0.3, 0.32, 0.26)
    for i, th in enumerate(row1):
        mat = M["trim"] if i % 3 == 1 else (M["ochre"] if i % 2 else M["steel_dk"])
        P2.applique(g, c.Pf, c.Nf, th, ph1, w1, h1, mat, M)
    for th in (0.6, 1.25, 1.9, 2.55):
        P2.applique(g, c.Pf, c.Nf, th, 0.75, 0.26, 0.22, M["ochre"], M)
        p = c.Pf(th, 0.75, 1.0)
        n = c.Nf(th, 0.75)
        g.push_frame(p + n * 0.066, n, V((-math.sin(th), math.cos(th), 0)))
        g.box((0, 0, 0), (0.27, 0.012, 0.01), M["jacket"], "hard", what="lisere")
        g.box((0, 0.105, 0), (0.27, 0.012, 0.01), M["jacket"], "hard", what="lisere")
        g.pop()
    dome_gun(g, H, 6, 1.7, 1.0)

    def zsurf(x, y):
        return H["zs"] + H["rz"] * math.sqrt(max(0.0, 1 - (x / R) ** 2 - (y / (R * 1.06)) ** 2))
    # sommet de la tête : COURONNE d'or blanc tenue par 5 montants posés sur la coupole (rien ne flotte)
    rc = 0.92
    zr = H["zs"] + H["rz"] * math.sqrt(max(0.0, 1 - (rc / R) ** 2)) + 0.16
    for k in range(5):
        a = TAU * (k + 0.5) / 5 + math.pi / 2
        d = V((math.cos(a), math.sin(a), 0))
        p = V((0, -0.1, 0)) + d * rc
        zb = zsurf(p.x, p.y)
        g.box(V((p.x, p.y, (zb + zr) / 2)), (0.06, 0.06, zr - zb + 0.04), M["ring"], "hard",
              R=Matrix.Rotation(a, 3, "Z"), what="montant")
        g.cyl(V((p.x, p.y, zb + 0.015)), "z", 0.06, 0.03, M["steel_dk"], n=12, what="semelle")
        g.sphere(V((p.x, p.y, zb + 0.05)) + d * 0.07, 0.02, M["emit"], n=10, m=6, what="pierre")
    crown(g, (0, -0.1, zr), rc, n=12, h=0.3, gems_all=True)
    PT.capacitors(g, (0.0, -R - 0.14, H["zs"] + H["rz"] * 0.42), 4, 1, 0.1, 0.22, M["emit"])
    PT.sight(g, (-R * 0.64, R * 0.3, H["zs"] + H["rz"] * 0.5), 0.26, 0.26, 0.15, M["emit"], lenses=2)
