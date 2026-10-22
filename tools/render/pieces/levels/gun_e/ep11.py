"""Époque 11 · Titane (ère IV, 5×5, niveaux 21 et 22). Constructeur : PLAGE HAUTE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 11) : « ailerons, effilé, titane ».
PORTÉ TEL QUEL de la passe 3 (gun_e_haut, commit 4c57982 : design.py, armes.py, ages.py ; outil de portage, code d'origine mot pour
mot ; les aiguillages par époque sont réduits à la branche de l'époque 11) sur le kit commun gun_e : seul le CORPS a
changé (corps.py, kit.py). Aucune correction de design d'époque.
Emplacements remplis : arme (canon LONG et FIN, manchon à pans anguleux, grand EMPENNAGE en flèche, frein en pointe
de flèche, culasse en flèche), télémètre à ailerons, grands volumes du socle (turbine de titane à l'ouest,
réservoirs-fusées à ogive à l'est, échangeur à ailettes au nord-ouest), tourelle secondaire sur pieds en V, liaisons
(conduits fins de titane groupés à colliers clairs), chenillard bleu-blanc, dérives au sommet, foyers bleu-blanc,
pièce paire (2 lance-missiles à ailerons).
Défaut relevé par les juges (à corriger par le constructeur) : lu « industrie lourde blindée » ; pose N lue comme des
cheminées.
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

EPOQUE = 11
NOM = "Titane"
FOYER = dict(rgb=(0.749, 0.902, 1.0), rgb2=(0.749, 0.902, 1.0))
CANON = dict(L=2.1, nb=6, rb=0.06, rr=0.145)
PLATEFORME = dict(chanfrein=0.55)
HABILLAGE = dict(jupe_cerclage="ring", chapeau="ring")
RECV = ("jacket", "olive")


def matieres(metal, M):
    """Titane : titane patiné, alliage blanc patiné (ailerons, colliers)."""
    rust = (0.24, 0.085, 0.03)
    metal("jacket", (0.31, 0.315, 0.32), rough=0.3, met=0.88, grain=0.14, gscale=40.0, rust=rust, ra=0.06,
          dirt=0.8, stain=0.45, sscale=6.0, wear=1.0, streak=0.4)
    metal("ring", (0.42, 0.4, 0.36), rough=0.3, met=0.7, grain=0.14, gscale=30.0, rust=(0.2, 0.1, 0.05),
          ra=0.1, dirt=0.9, stain=0.6, sscale=5.0, wear=0.8, streak=0.5)
    M["trim"] = M["ring"]
    M["pipe"] = M["jacket"]
    M["pipe2"] = M["ring"]
    M["cable_a"], M["cable_b"] = M["redcable"], M["rubber"]
    M["spec"] = M["ring"]
    M["accent"] = M["trim"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 21 de l'industriel, témoin)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    ring_lights(g, B["R"] - 0.08, B["h"] + B["rh"] + 0.02)
    ng = 7
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, ng, M["emit"], a0=math.pi + 0.2, span=math.pi - 0.4)
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, ng - 1, M["emit"], a0=math.pi + 0.35, span=math.pi - 0.7,
                    per=(3, 2))
    P2.grating(g, 1.35, 1.75, Y(-1.15), Y(1.3), 0.07, M)
    P2.grating(g, -1.55, -1.3, Y(-1.0), Y(-0.3), 0.07, M)
    with at(g, -1.5, -1.72, 0.42):
        P2.open_crate(g, (0, 0, 0), 0.78, 0.72, 0.3, M)
    with at(g, -1.05, -2.35, 0.08):
        P2.open_crate(g, (0, 0, 0), 0.6, 0.5, 0.22, M, paint=M["ochre"])
    for (x, yn, rz) in [(1.78, -1.82, 0.0)]:
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.42, 0.0, 0.28, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            turret_legs(g, 0.42, 0.28)
            mini_turret(g, (0, 0, 0.28), 0.95, rz)
            signature(g, (0.0, -0.18, 0.28 + 0.4 * 0.95))
    # ouest : turbine de titane ; liaisons d'énergie vers la colonne
    west(g)
    conduit(g, [(-1.62, Y(0.55), 0.4), (-1.42, Y(0.6), 0.62), (-1.2, Y(0.5), 0.72)], 0.045)
    cables(g, [(-1.62, Y(-0.25), 0.4), (-1.42, Y(-0.3), 0.6), (-1.18, Y(-0.35), 0.68)])
    # nord-ouest : échangeur à ailettes posé en biais
    with at(g, -1.72, 2.02, -0.55):
        fin_exchanger(g, -0.55, 0.55, -0.42, 0.42, 0.62)
    # est : deux réservoirs-fusées à ogive et ailerons
    rocket_tank(g, 2.02, Y(0.95), 0.37, 0.92)
    rocket_tank(g, 2.02, Y(-0.4), 0.37, 0.92)
    P3.cabinet(g, -2.45, -2.02, -2.3, -1.66, 0.0, 0.5, M, E, screen_=False)
    PT.hull(g, 1.68, 2.36, Y(-1.18), Y(-0.85), 0.0, 0.3, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["redpaint"], M["steel_dk"]], rivet_step=0.12)
    P2.handwheel(g, (2.02, Y(-1.18) - 0.08, 0.2), (0, -1, 0.3), 0.08, M)
    pipe(g, [(1.68, Y(-1.0), 0.2), (1.45, Y(-1.05), 0.22), (1.25, Y(-0.85), 0.4)], 0.05,
         valve_at=((1.47, Y(-1.04), 0.22), (0, -1, 0.5)))
    hose(g, [(1.7, Y(1.05), 0.62), (1.45, Y(0.95), 0.98), (1.15, Y(0.75), 0.82)], 0.06)
    P3.cabinet(g, 1.25, 2.25, Y(1.95), Y(2.42), 0.0, 0.56, M, E, screen_=False)
    signature(g, (1.55, Y(2.18), 0.6))
    PT.crate(g, (-0.4, Y(1.95), 0.0), (0.66, 0.6, 0.28), mat=M["olive"])
    PT.crate(g, (0.4, Y(1.95), 0.0), (0.66, 0.6, 0.28), mat=M["ochre"])
    signature(g, (0.4, Y(1.95), 0.3), 1)
    signature(g, (-2.24, -1.98, 0.53), 2)
    for p in ((1.75, Y(2.18), 0.6), (-0.4, Y(1.95), 0.3), (2.02, Y(-1.02), 0.3),
              (-1.95, Y(-1.5), 0.45), (0.0, Y(-2.0), 0.68), (-0.95, Y(-2.35), 0.24)):
        signature(g, p)
    for x in (-0.68, 0.68):
        PT.lamp(g, (x, Y(-2.4) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    _halo(g, [(-2.0, Y(-1.1), 0.5), (1.78, Y(-2.1), 0.6), (0.0, Y(-2.5), 0.5), (2.0, Y(0.3), 0.5),
              (1.75, Y(1.8), 0.5)], 20.0)


def ring_lights(g, R, z):
    """Feux de couronne (face sud de la couronne d'orientation) : CHENILLARD bleu-blanc en segments courts, chaque feu
    un foyer séparé (espacement > 20 px hr)."""
    n = 13
    M = g.M
    for k in range(n):
        a = math.pi + math.pi * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0))
        t = V((-d.y, d.x, 0))
        Rr = Matrix((t, d, V((0, 0, 1)))).transposed()
        p = V((0, 0, z)) + d * R
        g.box(p, (0.1, 0.04, 0.03), M["steel_dk"], "hard", R=Rr, what="support")
        g.box(p + V((0, 0, 0.018)), (0.075, 0.018, 0.008), M["emit"], "flat", R=Rr, what="chenillard")


def turret_legs(g, R, h):
    """Pieds en V SOUS la tourelle secondaire, posés sur le tablier plein."""
    M = g.M
    for k in range(4):
        a = TAU * (k + 0.5) / 4
        d = V((math.cos(a), math.sin(a), 0))
        for s in (-1, 1):
            t = V((-d.y, d.x, 0))
            g.box(d * (R + 0.08) + t * s * 0.06 + V((0, 0, h * 0.45)), (0.04, 0.04, h * 0.95), M["jacket"], "hard",
                  R=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(s * 0.3, 3, "X"), what="pied_v")


def west(g):
    """Groupe de l'ouest : TURBINE de titane couchée (entrée d'air en cône au nord, tuyère au sud, aubes, berceaux)."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1, h = -2.42, -1.62, Y(-0.95), Y(1.25), 0.52
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    F.plinth(g, x0, x1, y0, y1, 0.1)
    r = (x1 - x0) * 0.46
    zc = 0.1 + r + 0.04
    ya, yb = y0 + 0.3, y1 - 0.35
    g.cyl((cx, (ya + yb) / 2, zc), "y", r, yb - ya, M["jacket"], n=8, style="hard", phase=TAU / 16, what="carter")
    for f in (0.12, 0.38, 0.64, 0.9):
        g.tube_shell((cx, ya + (yb - ya) * f, zc), "y", r * 1.08 + 0.01, r * 0.95, 0.05, M["ring"], n=8,
                     style="hard", what="cerclage")
        for kk in range(8):
            a = TAU * (kk + 0.5) / 8
            d = V((math.cos(a), 0, math.sin(a)))
            if d.z < -0.4:
                continue
            for dy in (-0.05, 0.05):
                g.dome(V((cx, ya + (yb - ya) * f + dy, zc)) + d * (r * 0.97 + 0.004), d, 0.012, M["rivet"])
    for kk in range(3):
        a = math.pi / 2 + (kk - 1) * 0.8
        d = V((math.cos(a), 0, math.sin(a)))
        for f in range(9):
            yy = ya + 0.08 + (yb - ya - 0.16) * f / 8
            g.dome(V((cx, yy, zc)) + d * (r * 0.95 + 0.004), d, 0.011, M["rivet"])
    g.cyl((cx, yb + 0.15, zc), "y", r * 1.15, 0.3, M["ring"], n=24, r2=r * 0.95, what="entree")
    g.cyl((cx, yb + 0.302, zc), "y", r * 0.95, 0.006, M["void"], n=24, style="flat", what="entree_fond")
    g.cyl((cx, yb + 0.31, zc), "y", r * 0.3, 0.12, M["steel_hi"], n=16, r2=0.02, what="cone")
    g.cyl((cx, ya - 0.15, zc), "y", r * 0.7, 0.3, M["steel_dk"], n=20, r2=r * 0.95, what="tuyere")
    g.cyl((cx, ya - 0.302, zc), "y", r * 0.68, 0.006, M["soot"], n=20, style="flat", what="tuyere_fond")
    for a in (0.0, math.pi / 2, math.pi, -math.pi / 2):
        d = V((math.cos(a), 0, math.sin(a)))
        if d.z < -0.5:
            continue
        t = F.Rax(d).col[0] * 0.026
        c = V((cx, 0, zc))
        P2.wedge(g, c + d * r + V((0, ya + 0.02, 0)), c + d * r + V((0, ya + 0.42, 0)),
                 c + d * (r + 0.2) + V((0, ya + 0.04, 0)), t, M["ring"], what="aileron")
    for f in (0.22, 0.78):
        yy = ya + (yb - ya) * f
        g.box((cx, yy, (zc - r * 0.6 + 0.1) / 2 + 0.05), (r * 1.6, 0.12, zc - r * 0.6), M["steel_dk"], "hard",
              what="berceau")
    for f in (0.3, 0.6):
        g.box((cx + r * 0.68, ya + (yb - ya) * f, zc + r * 0.7), (0.09, 0.02, 0.03), E, "flat", what="chenillard")
    for s in (-1, 1):
        d = V((s * 0.38, 0, 0.92)).normalized()
        F.hatches(g, V((cx, ya + 0.12, zc)) + d * r * 0.93, V((cx, yb - 0.12, zc)) + d * r * 0.93, 7, d, M["ring"],
                  size=(0.07, 0.1), frame=M["steel_dk"])
    F.hatches(g, (x0 + 0.06, y0 + 0.25, 0.1), (x0 + 0.06, y1 - 0.25, 0.1), 6, (0, 0, 1), M["steel_hi"],
              size=(0.06, 0.06))
    for s in (-1, 1):
        d = V((s * 0.9, 0, 0.44)).normalized()
        F.hatches(g, V((cx, ya + 0.15, zc)) + d * r * 0.93, V((cx, yb - 0.15, zc)) + d * r * 0.93, 8, d,
                  M["steel_dk"], size=(0.06, 0.08), frame=M["ring"])


def rocket_tank(g, x, y, r, h):
    M = g.M
    E = M["emit"]
    g.cyl((x, y, 0.05), "z", r + 0.08, 0.1, M["steel_dk"], n=32, style="soft", what="socle")
    nb = int(TAU * (r + 0.05) / 0.12)
    for k in range(nb):
        a = TAU * k / nb
        g.bolt((x + (r + 0.05) * math.cos(a), y + (r + 0.05) * math.sin(a), 0.1), (0, 0, 1), 0.016, M["steel_hi"])
    hexr = [(math.cos(TAU * i / 8 + TAU / 16), math.sin(TAU * i / 8 + TAU / 16)) for i in range(8)]
    F.loft_z(g, x, y, [(0.1, F.scale_poly(hexr, r)), (h, F.scale_poly(hexr, r)), (h + r * 1.1, F.scale_poly(hexr, r * 0.3)),
                     (h + r * 1.35, F.scale_poly(hexr, 0.04))], M["jacket"], "hard", "ogive")
    for zz in (0.3, h * 0.62, h):
        g.tube_shell((x, y, zz), "z", r * 1.02 + 0.018, r - 0.01, 0.04, M["ring"], n=8, style="hard", what="cerclage")
        for kk in range(10):
            a = TAU * (kk + 0.5) / 10
            d = V((math.cos(a), math.sin(a), 0))
            if d.y > 0.5:
                continue
            g.dome(V((x, y, zz - 0.045)) + d * (r * 0.96 + 0.004), d, 0.012, M["rivet"])
    for a in (math.pi * 0.25, math.pi * 0.75, math.pi * 1.25, math.pi * 1.75):
        d = V((math.cos(a), math.sin(a), 0))
        t = V((-d.y, d.x, 0)) * 0.03
        c = V((x, y, 0))
        P2.wedge(g, c + d * (r - 0.01) + V((0, 0, 0.12)), c + d * (r - 0.01) + V((0, 0, h * 0.75)),
                 c + d * (r + 0.24) + V((0, 0, 0.12)), t, M["ring"], what="aileron")
        g.box(c + d * (r + 0.08) + V((0, 0, 0.3)), (0.045, 0.045, 0.36), M["steel_dk"], "hard",
              R=Matrix.Rotation(a, 3, "Z"), what="nervure")
        for zz in (0.2, 0.34, 0.48):
            g.dome(c + d * (r + 0.04) + V((0, 0, zz)) + t * 0.7, t, 0.012, M["rivet"])
    for a in (-1.1, -1.55, -2.0, -2.45):
        d = V((math.cos(a), math.sin(a), 0))
        F.hatches(g, V((x, y, 0.42)) + d * (r * 0.93), V((x, y, 0.62)) + d * (r * 0.93), 2, d, M["matte"],
                size=(0.06, 0.07), frame=M["ring"])
    for a in (-0.7, -1.3, -1.9, -2.5):
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((x, y, 0.105)) + d * (r + 0.07), (0.07, 0.07, 0.014), M["steel_hi"], "hard", R=Matrix.Rotation(a, 3, "Z"),
              what="trappe")
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        d = V((math.cos(a), math.sin(a), 0))
        F.hatches(g, V((x, y, h + r * 0.35)) + d * (r * 0.78), V((x, y, h + r * 0.45)) + d * (r * 0.72), 1,
                (d.x * 0.8, d.y * 0.8, 0.6), M["steel_dk"], size=(0.05, 0.05))
    for k, a in enumerate((-1.3, -1.75)):
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((x, y, h * 0.45 + 0.08 * k)) + d * (r + 0.01), (0.09, 0.02, 0.03), E, "flat",
              R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="chenillard")


def fin_exchanger(g, x0, x1, y0, y1, h, nfin=7):
    """Échangeur de titane : socle, rangée d'AILETTES verticales anguleuses en alliage clair, collecteurs."""
    M = g.M
    F.plinth(g, x0, x1, y0, y1, 0.12)
    for i in range(nfin):
        x = x0 + 0.08 + (x1 - x0 - 0.16) * (i + 0.5) / nfin
        P2.wedge(g, V((x, y0 + 0.06, 0.12)), V((x, y1 - 0.06, 0.12)), V((x, y0 + 0.12, h)), V((0.035, 0, 0)), M["ring"],
                 what="ailette")
        g.box((x, (y0 + y1) / 2, 0.16), (0.05, y1 - y0 - 0.1, 0.06), M["steel_dk"], "hard", what="pied")
    for yy in (y0 + 0.1, y1 - 0.12):
        g.cyl(((x0 + x1) / 2, yy, 0.2), "x", 0.04, x1 - x0 - 0.06, M["jacket"], n=10, what="collecteur")
    F.hatches(g, (x0 + 0.06, y0 - 0.005, 0.07), (x1 - 0.06, y0 - 0.005, 0.07), 4, (0, -1, 0), M["steel_hi"],
            size=(0.06, 0.04))
    for f in (0.2, 0.6):
        g.box((x0 + (x1 - x0) * f, y0 + 0.02, 0.135), (0.08, 0.02, 0.025), M["emit"], "flat", what="chenillard")


def signature(g, p, kind=0):
    """Petite pièce de signature posée sur un toit de machine : 2 ailerons d'alliage clair."""
    M = g.M
    p = V(p)
    for s in (-1, 1):
        P2.wedge(g, p + V((s * 0.08, -0.08, 0)), p + V((s * 0.08, 0.1, 0)), p + V((s * 0.08, -0.06, 0.12)),
                 V((0.02, 0, 0)), M["ring"], what="aileron")


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
        _gun11(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
    PT.lamp(g, (0.0, 0.12 * s, 0.4 * s + 0.01), (0, 0.35, 1), 0.035, E, cage=False)
    PT.hatch(g, (0.0, -0.12 * s, 0.4 * s), 0.09 * s)
    g.pop()


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : conduits fins de titane groupés par 3, colliers d'alliage clair, conduits à bagues lumineuses
# ------------------------------------------------------------------------------------------------
def hose(g, ctrl, r):
    """Trois conduits fins de titane serrés, colliers d'alliage blanc patiné."""
    M = g.M
    PT.cable_run(g, ctrl, 3, r * 0.42, r * 0.95, [M["jacket"]])
    P = g.spline(ctrl, 10)
    T, _ = g.frames(P)
    for i in range(2, len(P) - 1, 6):
        g.cyl(P[i], T[i], r * 1.55, 0.04, M["ring"], n=12, style="hard", what="collier")


def cables(g, ctrl, n=3):
    M = g.M
    PT.cable_run(g, ctrl, n, 0.02, 0.045, [M["rubber"], M["redcable"], M["rubber"]])


def conduit(g, ctrl, r):
    """Conduit d'énergie : bagues lumineuses PAR GROUPES (chenillard), colliers d'alliage clair."""
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
    g.pipe(ctrl, r, M["jacket"], fl_mat=M["pipe2"], bolt_mat=M["rivet"])
    if valve_at is not None:
        p, ax = valve_at
        g.box(p, (r * 3.2, r * 3.2, r * 3.2), M["steel_dk"], "hard", what="corps_vanne")
        P2.handwheel(g, V(p) + V(ax).normalized() * (r * 1.6 + 0.06), ax, 0.07, M)


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 22 : 2 lance-missiles à ailerons
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.5, Y(-2.64), sx)
    _halo(g, [(-1.5, Y(-2.9), 0.4), (1.5, Y(-2.9), 0.4)], 16.0)


def even_piece(g, x, yb, sx):
    """LANCE-MISSILES À AILERONS : caisson 2 × 2 cellules incliné, nez des missiles, ailerons arrière, sur la plinthe
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


# ------------------------------------------------------------------------------------------------
# Arme (E1) : canon long à empennage
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse, moteur arrière, arme d'époque, masque de canon,
    alimentation, voyants d'état, culasse en flèche."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _gun11(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    for f in (0.28, 0.5):
        g.box((x - sx * wr * 0.22, y0 + (y1 - y0) * f, zg + hr + 0.012), (0.03, (y1 - y0) * 0.12, 0.012), M["emit"],
              "flat", what="etat")
    # culasse EN FLÈCHE : capot effilé vers l'arrière (alliage blanc patiné), rivets
    zt = zg + hr + 0.012
    b = [V((x - wr * 0.4, y0 + 0.12, zt)), V((x + wr * 0.4, y0 + 0.12, zt)), V((x + wr * 0.4, y1 - 0.22, zt)),
         V((x - wr * 0.4, y1 - 0.22, zt))]
    t = [V((x - 0.02, y0 - 0.12, zt + 0.015)), V((x + 0.02, y0 - 0.12, zt + 0.015)),
         V((x + wr * 0.3, y1 - 0.26, zt + 0.045)), V((x - wr * 0.3, y1 - 0.26, zt + 0.045))]
    g.hexa(b + t, M["ring"], "hard", what="coin")
    g.box((x, (y0 + y1) / 2 - 0.1, zt + 0.04), (0.014, (y1 - y0) * 0.6, 0.012), M["steel_dk"], "hard",
          what="arete")
    for k in range(4):
        for s_ in (-1, 1):
            g.dome((x + s_ * wr * (0.08 + 0.05 * k), y0 + 0.02 + k * 0.17, zt + 0.02 + 0.008 * k), (0, 0, 1),
                   0.013, M["rivet"])


def _gun11(g, x, y0, z, L, nb, rb, rr):
    """Troisième passe : un canon LONG (1,25 × la longueur de l'époque) et FIN (faisceau de 6 tubes serrés, 0,27 de
    large), manchon arrière à PANS ANGULEUX en titane, et deux paires d'AILERONS en flèche en alliage clair patiné
    (empennage horizontal de 0,5 tuile d'envergure) : de dessus, une flèche empennée ; de face, une croix."""
    M = g.M
    E = M["emit"]
    k = F.k_arme(rb, rr)
    L2 = L * 1.25
    rb2, rr2 = rb * 0.72, rr * 0.6
    R0 = rr2 + rb2
    F.tubes(g, x, y0, z, L2, nb, rb2, rr2)
    # manchon à pans anguleux (hexagone allongé, effilé vers l'avant), plaques de titane rivetées
    Ls = 0.46 * L2
    hexs = [(0.0, 1.0), (0.87, 0.5), (0.87, -0.5), (0.0, -1.0), (-0.87, -0.5), (-0.87, 0.5)]
    r_a, r_b = R0 + 0.12 * k, R0 + 0.035
    F.loft(g, x, z, [(y0 - 0.02, F.scale_poly(hexs, r_a * 0.9)), (y0 + 0.1, F.scale_poly(hexs, r_a)),
                   (y0 + Ls, F.scale_poly(hexs, r_b))], M["jacket"], "hard", "manchon")
    for f in (0.25, 0.5, 0.75):
        rr_ = r_a + (r_b - r_a) * (f * Ls - 0.1) / (Ls - 0.1)
        F.loft(g, x, z, [(y0 + f * Ls - 0.015, F.scale_poly(hexs, rr_ * 1.04)), (y0 + f * Ls + 0.015, F.scale_poly(hexs, rr_ * 1.04))],
             M["steel_dk"], "hard", "joint")
        for (u, w) in hexs[:3] + hexs[5:]:
            g.dome((x + u * rr_ * 0.98, y0 + f * Ls + 0.04, z + w * rr_ * 0.98), (u, 0, w), 0.012, M["rivet"])
    # EMPENNAGE : 2 grands ailerons horizontaux (vers l'extérieur et vers l'intérieur) et 1 dorsal, bord d'attaque
    # en flèche ; nervure et rivets ; un 2e empennage plus petit à mi-longueur
    sx = 1.0 if x >= 0 else -1.0
    for (yy, span, chord, inner) in ((y0 + 0.36, 0.5 * k, 0.62 * k, 0.32 * k), (y0 + Ls + 0.1, 0.26 * k, 0.32 * k,
                                                                                0.2 * k)):
        r0 = (r_a + (r_b - r_a) * (yy - y0 - 0.1) / (Ls - 0.1)) if yy < y0 + 0.5 else r_b
        # pas d'aileron côté coupole : il fermait un jour avec le socle en pose N (contrôle des trous)
        for d, sp in (((V((sx, 0, 0)), span), (V((0, 0, 1)), span * 0.7)) if yy < y0 + 0.5 else ((V((0, 0, 1)), span),)):
            t = F.Rax(d).col[0] * 0.026
            c = V((x, 0, z))
            # emplanture prolongée vers l'arrière (virure) sur le grand empennage : ferme le jour avec le socle
            p0 = c + d * (r0 - 0.01) + V((0, yy - (0.15 * k if yy < y0 + 0.5 else 0.0), 0))
            p1 = c + d * (r0 - 0.01) + V((0, yy + chord, 0))
            p2 = c + d * (r0 + sp) + V((0, yy + 0.02, 0))
            P2.wedge(g, p0, p1, p2, t, M["ring"], what="aileron")
            g.box(c + d * (r0 + sp * 0.45) + V((0, yy + 0.06, 0)), (0.026, 0.05, sp * 0.85), M["steel_dk"], "hard",
                  R=F.Rax(d), what="nervure")
            for f in (0.3, 0.6):
                g.dome(c + d * (r0 + sp * f * 0.8) + V((0, yy + chord * (1 - f) * 0.7, 0)) + F.Rax(d).col[0] * 0.014,
                       F.Rax(d).col[0], 0.012, M["rivet"])
    # conduits fins jumelés en titane sur le dos (chenillard bleu-blanc en segments)
    for s in (-1, 1):
        p0 = V((x + s * 0.04 * k, y0 + Ls + 0.02, z + R0 + 0.02))
        p1 = V((x + s * 0.04 * k, y0 + L2 * 0.88, z + R0 + 0.02))
        g.tube([p0, p1], 0.014 * k, M["jacket"], n=8, what="conduit")
        for f in (0.2, 0.55, 0.9):
            g.cyl(p0.lerp(p1, f), "y", 0.022 * k, 0.025, M["ring"], n=10, style="hard", what="collier")
        g.cyl(p0.lerp(p1, 0.38) + V((0, 0, 0.004)), "y", 0.017 * k, 0.04, E, n=8, style="flat", what="segment_lum")
    for f in (0.62, 0.8):
        F.collar(g, x, y0 + f * L2, z, R0 + 0.018, rr2 * 0.3, 0.04, M["ring"])
    # frein EFFILÉ en pointe de flèche, évents obliques, 4 petits ailerons
    yb0 = y0 + L2
    lb = 0.4 * k
    g.tube_shell((x, yb0 + 0.02, z), "y", R0 + 0.06, rr2 * 0.4, 0.05, M["ring"], n=28, what="bague")
    g.cyl((x, yb0 + lb / 2, z), "y", R0 + 0.06, lb, M["jacket"], n=6, r2=rr2 * 0.7, style="hard", phase=math.pi / 2,
          what="frein")
    for s in (-1, 1):
        for i in range(3):
            d = V((s, 0, 0))
            g.box(V((x, yb0 + lb * (0.22 + 0.22 * i), z)) + d * (R0 + 0.04 - i * 0.045 * k),
                  (0.016, 0.07, 0.045), M["void"], "flat", R=Matrix.Rotation(s * 0.5, 3, "Z") @ F.Rax(d), what="event")
    for d in F.ring_dirs(4, math.pi / 4, -0.9):
        t = F.Rax(d).col[0] * 0.02
        c = V((x, 0, z))
        P2.wedge(g, c + d * (R0 + 0.04) + V((0, yb0, 0)), c + d * (rr2 * 0.8) + V((0, yb0 + lb * 0.8, 0)),
                 c + d * (R0 + 0.15 * k) + V((0, yb0 + 0.01, 0)), t, M["ring"], what="aileron")
    g.cyl((x, yb0 + lb + 0.002, z), "y", rr2 * 0.6, 0.006, M["void"], n=16, style="flat", what="bouche")
    F.muzzle_glow(g, x, yb0 + lb + 0.004, z, rr2 * 0.75)
    return yb0 + lb


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisse (volume de la lignée) titane et kaki, goulotte, 2 ailerons, voyants."""
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
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=[M["jacket"], M["olive"]],
            rivet_step=0.11)
    ztop = zb1 + 0.015
    g.hazard(PT.lift([V((bx0, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.2, zb1)),
                      V((bx0, yb0 + bl * 0.2, zb1))], 0.012), 4, t=0.01)
    chute = [(bc, yb0 + bl * 0.6, ztop + 0.005), (bc - sx * 0.05, y0 + bl * 0.55, zg + bh * 0.62),
             (x + sx * wr * 0.2, y0 + bl * 0.5, zg + hr + 0.06)]
    cw = 0.12 * wr / 0.4 + 0.04
    P2.feed_chute(g, chute, cw, M)
    for k in range(2):
        yy = yb0 + bl * (0.35 + 0.35 * k)
        P2.wedge(g, V((bc, yy - 0.1, ztop)), V((bc, yy + 0.08, ztop)), V((bc, yy - 0.08, ztop + 0.13)),
                 V((0.02, 0, 0)), M["ring"], what="aileron")
    P3.lamp_group(g, (bc + sx * bw * 0.32, yb0 + bl * 0.4, ztop - 0.005), (0, 1, 0), (0, 0, 1), E, M, n=2,
                  shapes=("fente", "rond"))
    return bc


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
    F.slits_grouped(g, R, z0 + 0.2, 8, M["emit"])
    for sx in (-1, 1):
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, H["zs"] + 0.25), (sx * R * 0.62, -R * 0.42, H["zs"] + H["rz"] * 0.55),
              (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
    row1 = (0.5, 0.95, 1.4, math.pi - 0.5, math.pi - 0.95, math.pi - 1.4)
    ph1, w1, h1 = (0.32, 0.28, 0.22)
    for i, th in enumerate(row1):
        mat = M["trim"] if i % 3 == 1 else (M["ochre"] if i % 2 else M["steel_dk"])
        P2.applique(g, c.Pf, c.Nf, th, ph1, w1, h1, mat, M)
    # télémètre à ailerons
    zt = H["zs"] + H["rz"] * 0.86
    g.box((0.0, R * 0.32, zt), (R * 1.25, 0.1, 0.1), M["jacket"], "hard", what="telemetre")
    for sx in (-1, 1):
        g.cyl((sx * R * 0.64, R * 0.32, zt), "x", 0.07, 0.09, M["steel_dk"], n=14, what="telemetre_bout")
        g.cyl((sx * R * 0.64, R * 0.32 + 0.065, zt), "y", 0.045, 0.012, M["emit"], n=12, style="flat",
              what="lentille")
        g.box((sx * R * 0.3, R * 0.32, zt - 0.1), (0.05, 0.05, 0.12), M["steel_dk"], "hard", what="support")
        P2.wedge(g, V((sx * R * 0.62, R * 0.32 - 0.05, zt + 0.05)), V((sx * R * 0.62, R * 0.32 + 0.05, zt + 0.05)),
                 V((sx * R * 0.62, R * 0.32 - 0.04, zt + 0.15)), V((0.02, 0, 0)), M["ring"], what="aileron")
    # sommet de la tête : grande DÉRIVE en flèche sur la nacelle, 2 dérives latérales inclinées, plaques anguleuses
    bx, yb0, yb1 = c.nac[:3]
    znac = H["zs"] + H["rz"] * 0.42
    for s, ang, sc in ((0, 0.0, 1.0), (-1, -0.5, 0.6), (1, 0.5, 0.6)):
        x = s * bx * 0.75
        g.push((x, 0, znac), ry=ang)
        P2.wedge(g, V((0, yb0 + 0.05, 0)), V((0, yb1 - 0.05, 0)), V((0, yb0 - 0.12, 0.55 * sc)), V((0.04, 0, 0)),
                 M["ring"], what="derive")
        g.box((0, (yb0 + yb1) / 2 - 0.05, 0.08 * sc), (0.06, (yb1 - yb0) * 0.6, 0.06), M["steel_dk"], "hard",
              what="nervure")
        for f in (0.25, 0.5):
            g.dome((0.022, yb0 + (yb1 - yb0) * (0.6 - f), 0.4 * sc * f + 0.05), (1, 0, 0), 0.012, M["rivet"])
        g.pop()
    for th in (math.pi / 2 - 0.55, math.pi / 2 + 0.55):
        P2.applique(g, c.Pf, c.Nf, th, 0.42, 0.5, 0.34, M["ring"], M, bolts=4)
    PT.sight(g, (-R * 0.6, R * 0.32, H["zs"] + H["rz"] * 0.5), 0.2, 0.2, 0.12, M["emit"], lenses=2)
