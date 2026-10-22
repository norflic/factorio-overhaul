"""Époque 14 · Orbite (ère V, 6×6, niveaux 27 et 28). Constructeur : PLAGE HAUTE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 14) : « or, paraboles, balises ».
PORTÉ TEL QUEL de la passe 3 (gun_e_haut, commit 4c57982 : design.py, armes.py, ages.py ; outil de portage, code d'origine mot pour
mot ; les aiguillages par époque sont réduits à la branche de l'époque 14) sur le kit commun gun_e : seul le CORPS a
changé (corps.py, kit.py ; la règle commune de reflets rend la feuille d'or un peu plus satinée). Aucune correction
de design d'époque.
Emplacements remplis : arme (canon-ÉMETTEUR : corps en feuille d'or sanglé, panneau doré replié, fût à colliers
isolants, grande COUPELLE d'émission, balises), canon de coupole, 3 tourelles secondaires, grands volumes du socle
(batterie dorée et panneaux à l'ouest, 2 grandes paraboles à l'est, champ de panneaux au nord), liaisons (câbles
gainés de feuille d'or, sangles), grande parabole au sommet, panneaux repliés sur la nacelle, balises rouges, pièce
paire (2 paraboles de conduite de tir).
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

EPOQUE = 14
NOM = "Orbite"
FOYER = dict(rgb=(1.0, 0.165, 0.165), rgb2=(0.184, 0.42, 1.0))
CANON = dict(L=2.4, nb=6, rb=0.072, rr=0.175)
PLATEFORME = dict(chanfrein=0.7)
HABILLAGE = dict(jupe_cerclage="ring", chapeau="ring")
RECV = ("ring", "olive")


def matieres(metal, M):
    """Orbite : feuille d'or froissée, blanc cassé patiné, cellules bleu nuit (≤ 5 %)."""
    metal("jacket", (0.6, 0.4, 0.08), rough=0.3, met=1.0, grain=0.45, gscale=22.0, rust=(0.25, 0.14, 0.04),
          ra=0.12, dirt=0.75, stain=0.5, sscale=7.0, wear=0.4)
    metal("ring", (0.44, 0.42, 0.37), rough=0.5, met=0.05, grain=0.14, gscale=30.0, rust=(0.2, 0.1, 0.05),
          ra=0.12, dirt=0.95, stain=0.7, sscale=5.0, wear=0.8, streak=0.6)
    M["trim"] = M["jacket"]
    M["pipe"] = M["jacket"]
    M["pipe2"] = M["ring"]
    M["cable_a"], M["cable_b"] = M["rubber"], M["redcable"]
    metal("spec", (0.012, 0.02, 0.075), rough=0.14, met=0.6, grain=0.05, dirt=0.3, stain=0.0)      # cellules
    M["accent"] = M["trim"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 29 de l'industriel ; 14 : 3 tourelles secondaires)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    ring_lights(g, B["R"] - 0.08, B["h"] + B["rh"] + 0.02)
    ng = 9
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, ng, M["emit"], a0=math.pi + 0.2, span=math.pi - 0.4)
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, ng - 1, M["emit"], a0=math.pi + 0.35, span=math.pi - 0.7,
                    per=(3, 2))
    P2.grating(g, 1.65, 1.95, Y(-1.3), Y(1.45), 0.07, M)
    P2.grating(g, -1.95, -1.65, Y(-1.1), Y(1.1), 0.07, M)
    with at(g, -1.45, -1.95, 0.45):
        P2.open_crate(g, (0, 0, 0), 0.84, 0.78, 0.32, M)
    with at(g, 1.45, -1.95, -0.45):
        P2.open_crate(g, (0, 0, 0), 0.84, 0.78, 0.32, M, paint=M["ochre"])
    for (x, yn, rz) in [(-2.4, -2.5, -0.3), (2.4, -2.5, 0.3), (2.4, 2.45, 1.25)]:
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.46, 0.0, 0.32, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            mini_turret(g, (0, 0, 0.32), 1.02, rz)
            signature(g, (0.18, 0.2, 0.32 + 0.4 * 1.02 - 0.02))
    # ouest : batterie dorée et panneaux ; liaisons
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
    hose(g, [(1.95, Y(1.0), 0.95), (1.68, Y(0.95), 1.15), (1.4, Y(0.8), 0.95)], 0.06)
    hose(g, [(1.95, Y(-0.55), 0.95), (1.68, Y(-0.55), 1.12), (1.42, Y(-0.4), 0.95)], 0.06)
    # nord : champ de panneaux ; armoires de commande
    solar_array(g, -1.3, 1.3, Y(2.05), Y(2.78), 0.42)
    P3.cabinet(g, -1.15, -0.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    P3.cabinet(g, 0.35, 1.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
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
    """Feux de couronne (face sud de la couronne d'orientation) : BALISES rouges, chaque feu un foyer séparé."""
    n = 20
    M = g.M
    for k in range(n):
        a = math.pi + math.pi * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0))
        p = V((0, 0, z)) + d * R
        g.cyl(p + V((0, 0, 0.02)), "z", 0.028, 0.04, M["steel_dk"], n=10, what="balise_pied")
        g.cyl(p + V((0, 0, 0.048)), "z", 0.019, 0.018, M["emit"], n=10, style="flat", what="balise")


def west(g):
    """Groupe de l'ouest : BATTERIE en feuille d'or et 2 PANNEAUX solaires inclinés (cellules ≤ 5 %), balises."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1, h = -2.88, -1.98, Y(-1.35), Y(1.35), 0.6
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    F.plinth(g, x0, x1, y0, y1, 0.16)
    r = (x1 - x0) * 0.26
    zc = 0.16 + r + 0.02
    for i in range(4):
        g.crumple((cx - (x1 - x0) * 0.18, y0 + 0.2 + (y1 - y0 - 0.4) * (i + 0.5) / 4, zc), "y", r,
                  (y1 - y0 - 0.4) / 4 - 0.02, M["jacket"], n=20, k=3, amp=0.014)
    for i in range(5):
        yy = y0 + 0.2 + (y1 - y0 - 0.4) * i / 4
        g.tube_shell((cx - (x1 - x0) * 0.18, yy, zc), "y", r + 0.02, r - 0.03, 0.04, M["ring"], n=24, what="sangle")
        for kk in range(7):
            a = TAU * (kk + 0.5) / 7
            d = V((math.cos(a), 0, math.sin(a)))
            if d.z < -0.3:
                continue
            g.dome(V((cx - (x1 - x0) * 0.18, yy, zc)) + d * (r + 0.022), d, 0.012, M["rivet"])
    F.hatches(g, (cx - (x1 - x0) * 0.18 - r * 0.45, y0 + 0.2, zc + r * 0.92),
              (cx - (x1 - x0) * 0.18 - r * 0.45, y1 - 0.2, zc + r * 0.92), 14, (-0.4, 0, 0.92), M["steel_hi"],
              size=(0.05, 0.06))
    F.hatches(g, (x0 + 0.05, y0 + 0.3, 0.16), (x0 + 0.05, y1 - 0.3, 0.16), 14, (0, 0, 1), M["ring"],
              size=(0.06, 0.06), frame=M["steel_dk"])
    P3.lamp_group(g, (x0 + 0.08, y0 - 0.02, 0.1), (1, 0, 0), (0, -1, 0), E, M, n=3)
    for (bx_, by_) in ((x1 - 0.06, y0 + 0.08), (x1 - 0.06, y1 - 0.08), (x1 - 0.06, cy)):
        g.cyl((bx_, by_, 0.19), "z", 0.024, 0.06, M["steel_dk"], n=10, what="balise_pied")
        g.cyl((bx_, by_, 0.226), "z", 0.018, 0.014, E, n=10, style="flat", what="balise")
    P3.lamp_group(g, (x0 + 0.08, y1 + 0.02, 0.1), (1, 0, 0), (0, 1, 0), M["emit2"], M, n=2)
    for j, (ya, yb) in enumerate(((y0 + 0.15, cy - 0.06), (cy + 0.06, y1 - 0.15))):
        xp = cx + (x1 - x0) * 0.24
        Rr = Matrix.Rotation(0.5, 3, "Y")
        g.box((xp, (ya + yb) / 2, 0.42), (0.34, yb - ya, 0.035), M["ring"], "hard", R=Rr, what="panneau_cadre")
        for k in range(3):
            yy0 = ya + 0.04 + (yb - ya - 0.08) * k / 3
            yy1 = yy0 + (yb - ya - 0.08) / 3 - 0.03
            g.box((xp - 0.002, (yy0 + yy1) / 2, 0.44), (0.27, yy1 - yy0, 0.006),
                  M["spec"] if k != 1 else M["jacket"], "flat", R=Rr, what="cellules")
        g.box((xp + 0.12, (ya + yb) / 2, 0.24), (0.06, 0.06, 0.24), M["steel_dk"], "hard", what="pied")
    for yy in (y0 + 0.12, cy - 0.5, cy + 0.5, y1 - 0.12):
        g.cyl((cx - (x1 - x0) * 0.18, yy, zc + r + 0.04), "z", 0.025, 0.05, M["steel_dk"], n=10, what="balise_pied")
        g.cyl((cx - (x1 - x0) * 0.18, yy, zc + r + 0.07), "z", 0.018, 0.016, E, n=10, style="flat", what="balise")


def east(g):
    """Est : deux GRANDES PARABOLES dorées sur affût blindé (à la place des réservoirs), tournées vers le haut et le
    sud ; coffre et balise."""
    M = g.M
    for (x, y, rz) in ((2.4, Y(1.0), 0.35), (2.4, Y(-0.55), -0.25)):
        PT.hull(g, x - 0.4, x + 0.4, y - 0.4, y + 0.4, 0.0, 0.3, ins=(0.04, 0.04, 0.04), panel=0.26,
                mats=[M["steel_dk"], M["olive"]], rivet_step=0.12)
        F.hatches(g, (x - 0.32, y - 0.405, 0.15), (x + 0.32, y - 0.405, 0.15), 6, (0, -1, 0), M["ring"],
                  size=(0.08, 0.06), frame=M["steel_dk"])
        g.cyl((x, y, 0.36), "z", 0.22, 0.12, M["ring"], n=28, what="pivot")
        g.cyl((x, y, 0.55), "z", 0.07, 0.3, M["steel_dk"], n=16, what="mat")
        for sx in (-1, 1):
            g.box((x + sx * 0.12, y, 0.66), (0.04, 0.12, 0.2), M["ring"], "hard", what="etrier")
        F.dish(g, (x, y, 0.78), 0.56, 0.16, M["jacket"], M["ring"], rx=0.62, rz=rz, horn=False)
        g.push((x, y, 0.78), rz=rz, rx=0.62)
        g.cyl((0, 0, 0.16 + 0.14), "z", 0.035, 0.28, M["steel_dk"], n=12, what="emetteur")
        g.cyl((0, 0, 0.16 + 0.3), "z", 0.06, 0.05, M["ring"], n=14, what="emetteur_tete")
        g.cyl((0, 0, 0.16 + 0.33), "z", 0.03, 0.006, M["emit2"], n=10, style="flat", what="lentille")
        g.pop()
        for s_ in (-1, 1):
            F.hatches(g, (x + s_ * 0.405, y - 0.3, 0.15), (x + s_ * 0.405, y + 0.3, 0.15), 5, (s_, 0, 0),
                      M["ring"], size=(0.07, 0.06), frame=M["steel_dk"])
        F.hatches(g, (x - 0.3, y - 0.3, 0.305), (x + 0.3, y - 0.3, 0.305), 5, (0, 0, 1), M["steel_hi"],
                  size=(0.05, 0.05))
        P3.lamp_group(g, (x - 0.3, y - 0.42, 0.24), (1, 0, 0), (0, -1, 0), M["emit"], M, n=2,
                      shapes=("rond", "fente"))
        g.cyl((x + 0.33, y - 0.33, 0.33), "z", 0.024, 0.06, M["steel_dk"], n=10, what="balise_pied")
        g.cyl((x + 0.33, y - 0.33, 0.37), "z", 0.018, 0.014, M["emit"], n=10, style="flat", what="balise")
    x, y = 2.74, Y(0.22)
    g.box((x, y, 0.06), (0.24, 0.24, 0.12), M["steel_dk"], "hard", what="semelle")
    g.box((x - 0.2, y, 0.1), (0.3, 0.6, 0.2), M["steel_dk"], "hard", what="coffre")
    g.cyl((x - 0.2, y - 0.31, 0.12), "z", 0.018, 0.014, M["emit"], n=10, style="flat", what="balise")


def solar_array(g, x0, x1, y0, y1, h):
    """Champ de panneaux (orbite) : cadres blanc cassé, feuille d'or, cellules bleu nuit en petites bandes."""
    M = g.M
    E = M["emit"]
    F.plinth(g, x0, x1, y0, y1, 0.12)
    F.hatches(g, (x0 + 0.1, y0 - 0.005, 0.06), (x1 - 0.1, y0 - 0.005, 0.06), 14, (0, -1, 0), M["ring"], size=(0.06, 0.05),
            frame=M["steel_dk"])
    n = 3
    for i in range(n):
        xa = x0 + 0.05 + (x1 - x0 - 0.1) * i / n
        xb = xa + (x1 - x0 - 0.1) / n - 0.06
        Rr = Matrix.Rotation(-0.55, 3, "X")
        c = V(((xa + xb) / 2, (y0 + y1) / 2, 0.36))
        g.box(c, (xb - xa, (y1 - y0) * 0.86, 0.035), M["ring"], "hard", R=Rr, what="panneau_cadre")
        for j in range(4):
            v = -0.32 + 0.21 * j
            q = c + Rr @ V((0, v * (y1 - y0), 0.022))
            g.box(q, ((xb - xa) * 0.86, (y1 - y0) * 0.17, 0.006), M["spec"] if (i + j) % 3 == 0 else M["jacket"],
                  "flat", R=Rr, what="cellules")
        g.box(((xa + xb) / 2, (y0 + y1) / 2 + 0.08, 0.2), (0.06, 0.06, 0.2), M["steel_dk"], "hard", what="pied")
        g.cyl((xb - 0.04, y0 + 0.06, 0.16), "z", 0.018, 0.014, E, n=8, style="flat", what="balise")
        g.cyl((xa + 0.04, y1 - 0.06, 0.16), "z", 0.018, 0.014, E, n=8, style="flat", what="balise")


def signature(g, p, kind=0):
    """Petite pièce de signature : petit panneau solaire bleu nuit encadré (≤ 5 %), balise rouge."""
    M = g.M
    p = V(p)
    R = Matrix.Rotation(-0.5, 3, "X")
    g.box(p + V((0, 0, 0.06)), (0.2, 0.16, 0.02), M["ring"], "hard", R=R, what="cadre")
    g.box(p + V((0, -0.004, 0.072)), (0.17, 0.13, 0.006), M["spec"], "flat", R=R, what="cellules")
    g.cyl(p + V((0, 0.04, 0.03)), "z", 0.012, 0.06, M["steel_dk"], n=6, what="pied")
    g.cyl(p + V((0.12, 0.05, 0.03)), "z", 0.016, 0.06, M["steel_dk"], n=8, what="balise_pied")
    g.cyl(p + V((0.12, 0.05, 0.07)), "z", 0.014, 0.02, M["emit"], n=8, style="flat", what="balise")


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
        _gun14(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
    PT.lamp(g, (0.0, 0.12 * s, 0.4 * s + 0.01), (0, 0.35, 1), 0.035, E, cage=False)
    PT.hatch(g, (0.0, -0.12 * s, 0.4 * s), 0.09 * s)
    g.pop()


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : câbles gainés de feuille d'or et sanglés, conduits isolés
# ------------------------------------------------------------------------------------------------
def hose(g, ctrl, r):
    """Gaine de feuille d'or (facettes plates) sanglée de blanc cassé."""
    M = g.M
    P, T = g.tube(g.spline(ctrl, 10), r * 1.05, M["jacket"], n=10, style="flat", what="gaine_or")
    for i in range(2, len(P) - 1, 5):
        g.cyl(P[i], T[i], r * 1.05 + 0.014, 0.03, M["ring"], n=12, style="hard", what="sangle")


def cables(g, ctrl, n=3):
    M = g.M
    PT.cable_run(g, ctrl, n, 0.02, 0.045, [M["jacket"], M["rubber"], M["jacket"]])


def conduit(g, ctrl, r):
    """Conduit d'énergie en feuille d'or : bagues lumineuses PAR GROUPES, colliers blanc cassé."""
    M = g.M
    P = g.spline(ctrl, 10)
    P, T = g.tube(P, r, M["jacket"], n=10, what="conduit")
    R = g.resample(P, 0.075)
    T2, _ = g.frames(R)
    for i in range(1, len(R) - 1):
        if i % 4 in (1, 2):
            g.tube_shell(R[i], T2[i], r + 0.008, r * 0.5, 0.03, M["emit"], n=12, what="bague_lum")
        elif i % 4 == 3:
            g.tube_shell(R[i], T2[i], r + 0.016, r * 0.5, 0.03, M["pipe2"], n=12, what="collier")


def pipe(g, ctrl, r, valve_at=None):
    M = g.M
    g.pipe(ctrl, r, M["ring"], fl_mat=M["pipe2"], bolt_mat=M["rivet"])
    if valve_at is not None:
        p, ax = valve_at
        g.box(p, (r * 3.2, r * 3.2, r * 3.2), M["steel_dk"], "hard", what="corps_vanne")
        P2.handwheel(g, V(p) + V(ax).normalized() * (r * 1.6 + 0.06), ax, 0.07, M)


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 28 : 2 paraboles de conduite de tir dorées sur affût blindé
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.22, Y(-2.97), sx)
    _halo(g, [(-1.22, Y(-3.1), 0.4), (1.22, Y(-3.1), 0.4)], 18.0)


def even_piece(g, x, yb, sx):
    """PARABOLE DE CONDUITE DE TIR DORÉE sur affût blindé : coupelle 0,30, bras, armoire, sur la plinthe commune
    (caisson blindé bas à bande de danger)."""
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
    PT.hull(g, x - 0.2, x + 0.2, yb - 0.2, yb + 0.2, z0, z0 + 0.22, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["ring"], M["olive"]], rivet_step=0.11)
    g.cyl((x, yb, z0 + 0.34), "z", 0.045, 0.24, M["steel_dk"], n=12, what="mat")
    for s_ in (-1, 1):
        g.cyl((x + s_ * 0.17, yb - 0.17, z0 + 0.25), "z", 0.018, 0.014, E, n=8, style="flat", what="balise")
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


# ------------------------------------------------------------------------------------------------
# Arme (E1) : canon-émetteur
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse, moteur arrière, arme d'époque, masque de canon,
    alimentation, voyants d'état, couverture d'or sur la culasse."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _gun14(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    for f in (0.28, 0.5):
        g.box((x - sx * wr * 0.22, y0 + (y1 - y0) * f, zg + hr + 0.012), (0.03, (y1 - y0) * 0.12, 0.012), M["emit"],
              "flat", what="etat")
    # couverture d'or froissée sur la culasse, sangles
    zt = zg + hr + 0.012
    g.crumple((x, (y0 + y1) / 2, zt + 0.04), "y", wr * 0.32, (y1 - y0) * 0.7, M["jacket"], n=14, k=3,
              amp=0.012)
    for f in (0.25, 0.75):
        g.box((x, y0 + (y1 - y0) * (0.15 + 0.7 * f), zt + 0.04), (wr * 0.7, 0.035, 0.05), M["ring"], "hard",
              what="sangle")


def _gun14(g, x, y0, z, L, nb, rb, rr):
    """Troisième passe : le canon est un ÉMETTEUR. Corps cylindrique enveloppé de feuille d'or froissée et sanglé,
    flanqué d'un PANNEAU doré replié (cadre blanc cassé, cellules bleu nuit en petites bandes), fût d'émission
    sombre à colliers isolants, et une grande COUPELLE d'émission dorée tournée vers l'avant (0,7 tuile de
    diamètre), à pointe d'émission et balise rouge. De dessus : un long corps doré terminé en T ; de face : des
    disques dorés."""
    M = g.M
    E, E2 = M["emit"], M["emit2"]
    k = F.k_arme(rb, rr)
    R0 = rr + rb
    rbody = R0 + 0.05 * k
    Lb = 0.6 * L
    nseg = 5
    for i in range(nseg):
        g.crumple((x, y0 + Lb * (i + 0.5) / nseg, z), "y", rbody, Lb / nseg - 0.015, M["jacket"], n=22, k=3,
                  amp=0.016)
    g.cyl((x, y0 + Lb / 2, z), "y", rbody - 0.02, Lb, M["steel_dk"], n=20, what="ame")
    for i in range(nseg + 1):
        yy = y0 + Lb * i / nseg
        g.tube_shell((x, yy, z), "y", rbody + 0.022, rbody - 0.03, 0.04, M["ring"], n=30, what="sangle")
        g.box((x + rbody * 0.5, yy, z + rbody * 0.84), (0.04, 0.055, 0.03), M["steel_hi"], "hard", what="boucle")
    # panneau doré replié côté extérieur (et un plus petit côté intérieur), charnières sur le corps
    sx = 1.0 if x >= 0 else -1.0
    for side, span in ((sx, 0.34 * k), (-sx, 0.14 * k)):
        x_in = x + side * (rbody + 0.01)
        x_out = x_in + side * span
        ya, yb = y0 + 0.06, y0 + Lb - 0.06
        zz = z + 0.02
        g.box(((x_in + x_out) / 2, (ya + yb) / 2, zz), (span, yb - ya, 0.035), M["ring"], "hard", what="panneau_cadre")
        nc = 4
        for j in range(nc):
            yy0 = ya + 0.03 + (yb - ya - 0.06) * j / nc
            yy1 = ya + 0.03 + (yb - ya - 0.06) * (j + 1) / nc - 0.025
            g.box(((x_in + x_out) / 2, (yy0 + yy1) / 2, zz + 0.02), (span * 0.82, yy1 - yy0, 0.006),
                  M["spec"] if j % 2 == 0 else M["jacket"], "flat", what="cellules")
        for f in (0.2, 0.8):
            g.cyl((x_in, ya + (yb - ya) * f, zz), "y", 0.03, 0.08, M["steel_dk"], n=10, what="charniere")
    # fût d'émission : tube sombre, colliers isolants blanc cassé
    yf0, yf1 = y0 + Lb, y0 + L - 0.1 * k
    rf = R0 * 0.55
    g.cyl((x, (yf0 + yf1) / 2, z), "y", rf, yf1 - yf0, M["gun"], n=20, what="fut")
    g.cyl((x, yf0 + 0.04, z), "y", rbody * 0.8, 0.1, M["steel_dk"], n=24, r2=rf, what="cone")
    for f in (0.25, 0.5, 0.75):
        yy = yf0 + (yf1 - yf0) * f
        g.tube_shell((x, yy, z), "y", rf + 0.045 * k, rf - 0.01, 0.05, M["ring"], n=24, what="collier_isolant")
    # grande coupelle d'émission tournée vers l'avant ET vers le haut (55°) : de dessus on voit son intérieur doré
    # (ellipse), de face un disque ; rotule et étrier sur le bout du fût, pointe d'émission, balise rouge
    rd = 0.34 * k
    dd = 0.12 * k
    yd = yf1 + 0.04
    g.sphere((x, yd, z), 0.07 * k, M["steel_dk"], n=16, m=8, what="rotule")
    for s in (-1, 1):
        g.box((x + s * 0.075 * k, yd, z + 0.03), (0.025, 0.1 * k, 0.14 * k), M["ring"], "hard", what="etrier")
    F.dish(g, (x, yd + 0.03, z + 0.05), rd, dd, M["jacket"], M["steel_dk"], rx=-0.96, horn=False)
    ax = V((0, 0.82, 0.57))
    g.cyl(V((x, yd + 0.03, z + 0.05)) + ax * (dd + 0.1 * k), ax, 0.03 * k, 0.22 * k, M["steel_dk"], n=12, what="emetteur")
    g.cyl(V((x, yd + 0.03, z + 0.05)) + ax * (dd + 0.215 * k), ax, 0.045 * k, 0.03, M["ring"], n=14, what="emetteur_tete")
    g.torus((x, yd + 0.03, z + 0.05), "y", 0.06 * k, 0.018, M["ring"], n=16, m=6, what="collier")
    g.cyl((x, yd - 0.02, z + 0.07 * k + 0.12 * k), "z", 0.02, 0.05, M["steel_dk"], n=8, what="balise_pied")
    g.cyl((x, yd - 0.02, z + 0.07 * k + 0.15 * k), "z", 0.016, 0.014, E, n=8, style="flat", what="balise")
    for s in (-1, 1):
        g.cyl((x + s * (rbody + 0.02), y0 + Lb * 0.5, z + rbody * 0.3), "z", 0.018, 0.016, E, n=8, style="flat",
              what="balise")
    g.cyl((x, yd + 0.03 + dd * 0.5, z + 0.05 + dd * 0.4), (0, 0.82, 0.57), 0.03 * k, 0.006, E2, n=12, style="flat",
          what="lentille")
    F.muzzle_glow(g, x, yf1 - 0.02, z, rf + 0.05 * k, E2)
    return yd + rd * 0.6


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisse (volume de la lignée) blanc cassé et kaki, BRAS ARTICULÉ de chargement à vérin,
    plaque de feuille d'or, goulotte, voyants."""
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
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=[M["ring"], M["olive"]],
            rivet_step=0.11)
    ztop = zb1 + 0.015
    g.hazard(PT.lift([V((bx0, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.2, zb1)),
                      V((bx0, yb0 + bl * 0.2, zb1))], 0.012), 4, t=0.01)
    cw = 0.12 * wr / 0.4 + 0.04
    pa = V((bc, yb0 + bl * 0.55, ztop + 0.02))
    pm = V((bc - sx * 0.04, y0 + bl * 0.45, zg + hr + 0.32))
    pb = V((x + sx * wr * 0.2, y0 + bl * 0.4, zg + hr + 0.06))
    for (p, q) in ((pa, pm), (pm, pb)):
        d = q - p
        g.cyl((p + q) / 2, d, 0.03, d.length, M["ring"], n=12, what="bras")
    for p in (pa, pm, pb):
        g.cyl(p, (1, 0, 0), 0.045, 0.07, M["steel_dk"], n=14, what="articulation")
    PT.piston(g, tuple(pa + V((0, 0.1, 0))), tuple(pm + V((0, 0.06, -0.08))), 0.018)
    g.crumple((bc, yb0 + bl * 0.25, ztop + 0.03), "x", 0.05, bw * 0.8, M["jacket"], n=12, k=3, amp=0.01)
    P2.feed_chute(g, [(bc, yb0 + bl * 0.75, ztop + 0.005), (bc - sx * 0.05, y0 + bl * 0.7, zg + bh * 0.62),
                      (x + sx * wr * 0.3, y0 + bl * 0.62, zg + hr + 0.06)], cw * 0.8, M)
    P3.lamp_group(g, (bc + sx * bw * 0.3, yb0 + bl * 0.08, ztop - 0.005), (0, 1, 0), (0, 0, 1),
                  E, M, n=3, shapes=("rond", "carre", "fente"))
    return bc


def dome_gun(g, H, nb, L, s=1.0):
    """Canon de coupole sur berceau blindé (lignée _tete15), arme de l'époque."""
    M = g.M
    zr = H["zs"] + H["rz"] * 0.92
    zc = zr + 0.3 * s
    PT.hull(g, -0.38 * s, 0.38 * s, -0.22 * s, 0.66 * s, zr - 0.04, zr + 0.2 * s, ins=(0.04, 0.04, 0.1),
            panel=0.22, mats=[M["olive"], M["ochre"]], rivet_step=0.11)
    PT.receiver(g, 0.0, -0.22 * s, 0.66 * s, zc - 0.18 * s, zc + 0.16 * s, 0.36 * s, mats=[M[k] for k in RECV])
    rb, rr = 0.052 * s, 0.125 * s * (1.0 if nb == 6 else 0.85)
    _gun14(g, 0.0, 0.66 * s, zc, L, nb, rb, rr)
    for sx in (-1, 1):
        PT.piston(g, (sx * 0.26 * s, 0.3 * s, zr + 0.02), (sx * 0.32 * s, 0.6 * s, zr + 0.2 * s), 0.026)
    P2.feed_chute(g, [(0.45 * s, -0.38 * s, zr + 0.05), (0.4 * s, -0.06 * s, zc + 0.12 * s),
                      (0.15 * s, 0.1 * s, zc + 0.17 * s)], 0.12 * s, M)
    return zc


# ------------------------------------------------------------------------------------------------
# Masque et tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=("ochre", "olive"), fentes=((-0.42, 0.34), (0.42, 0.22)), visiere=("steel_hi", 0.13),
                        coax=dict(fut="steel_dk", manchon="ring", manchon_y=0.28, manchon_r=0.045, manchon_L=0.16))


def tete(g, c):
    M = g.M
    E = M["emit"]
    H = c.H
    R = H["R"]
    z0 = c.rt
    F.slits_grouped(g, R, z0 + 0.2, 10, M["emit"])
    F.slits_grouped(g, R, z0 + 0.36, 10, M["emit"], a0=0.3, per=(3, 2))
    for sx in (-1, 1):
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, H["zs"] + 0.25), (sx * R * 0.62, -R * 0.42, H["zs"] + H["rz"] * 0.55),
              (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
        conduit(g, [(sx * 0.6, -R - 0.3, H["zs"] + 0.2), (sx * R * 0.72, -R * 0.5, H["zs"] + H["rz"] * 0.4),
                    (xe, ye + 0.2, H["zg"] + H["hr"] * 0.55)], 0.04)
    row1 = (0.35, 0.75, 1.15, 1.6, 2.0, 2.4, 2.8, -0.35, -0.75, -2.4, -2.8)
    ph1, w1, h1 = (0.3, 0.32, 0.26)
    for i, th in enumerate(row1):
        mat = M["trim"] if i % 3 == 1 else (M["ochre"] if i % 2 else M["steel_dk"])
        P2.applique(g, c.Pf, c.Nf, th, ph1, w1, h1, mat, M)
    dome_gun(g, H, 6, 1.7, 1.0)
    # 2 panneaux dorés repliés le long de la nacelle
    bx, yb0, yb1 = c.nac[:3]
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
    # sommet de la tête : GRANDE PARABOLE dorée sur mât, au-dessus du tourelleau
    cx, cy, ztop = c.tour
    g.cyl((cx, cy, ztop + 0.16), "z", 0.06, 0.32, M["ring"], n=16, what="mat")
    g.cyl((cx, cy, ztop + 0.03), "z", 0.13, 0.06, M["steel_dk"], n=24, what="pivot")
    F.dish(g, (cx, cy, ztop + 0.36), 0.62, 0.16, M["jacket"], M["ring"], rx=-0.75, horn=False)
    g.push((cx, cy, ztop + 0.36), rx=-0.75)
    g.cyl((0, 0, 0.16 + 0.12), "z", 0.04, 0.24, M["steel_dk"], n=12, what="emetteur")
    g.cyl((0, 0, 0.16 + 0.25), "z", 0.06, 0.04, M["ring"], n=14, what="emetteur_tete")
    g.pop()
    g.cyl((cx, cy + 0.02, ztop + 0.36), "z", 0.016, 0.018, E, n=8, style="flat", what="balise")
    PT.capacitors(g, (0.0, -R - 0.14, H["zs"] + H["rz"] * 0.42), 4, 1, 0.1, 0.22, M["emit"])
    PT.sight(g, (-R * 0.64, R * 0.3, H["zs"] + H["rz"] * 0.5), 0.26, 0.26, 0.15, M["emit"], lenses=2)
