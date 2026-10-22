"""Époque 13 · Fusion (ère V, 6×6, niveaux 25 et 26). Constructeur : PLAGE HAUTE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 13) : « plasma, céramique, injecteurs ».
PORTÉ TEL QUEL de la passe 3 (gun_e_haut, commit 4c57982 : design.py, armes.py, ages.py ; outil de portage, code d'origine mot pour
mot ; les aiguillages par époque sont réduits à la branche de l'époque 13) sur le kit commun gun_e : seul le CORPS a
changé (corps.py, kit.py). Aucune correction de design d'époque.
Emplacements remplis : arme (canon à plasma : CHAMBRE SPHÉRIQUE de céramique au pied, 7 ANNEAUX TORIQUES empilés,
buse évasée à cœur orange, injecteurs), canon de coupole à 6 tubes, 2 tourelles secondaires sur trépied, grands
volumes du socle (banc d'injecteurs à l'ouest, sphères de confinement à l'est, banc de bobines toriques au nord,
condensateurs), liaisons (gaines annelées de cuivre), chambre de confinement sur la nacelle, foyers magenta et cœurs
orange, pièce paire (2 injecteurs-condensateurs).
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

EPOQUE = 13
NOM = "Fusion"
FOYER = dict(rgb=(1.0, 0.31, 0.847), rgb2=(1.0, 0.604, 0.227))
CANON = dict(L=2.3, nb=6, rb=0.072, rr=0.175)
PLATEFORME = dict(chanfrein=1.3)
HABILLAGE = dict(jupe_cerclage="ring", chapeau="ring")
RECV = ("olive", "steel_dk")


def matieres(metal, M):
    """Fusion : céramique blanche patinée (buses, chambres, injecteurs), cuivre."""
    metal("jacket", (0.48, 0.46, 0.41), rough=0.55, met=0.0, grain=0.14, gscale=34.0, rust=(0.22, 0.12, 0.06),
          ra=0.12, dirt=0.95, stain=0.7, sscale=5.0, wear=0.6, streak=0.55, mottle=0.25)
    # cuivre des gaines et cerclages : plus rugueux et plus sombre (reflets saturés comptés comme foyers sinon)
    metal("copper13", (0.46, 0.2, 0.085), rough=0.42, met=0.9, grain=0.2, rust=(0.12, 0.2, 0.12), ra=0.12,
          dirt=0.7, stain=0.35, wear=0.8)
    M["copper"] = M["copper13"]
    M["ring"] = M["copper"]
    M["trim"] = M["jacket"]
    M["pipe"] = M["copper"]
    M["pipe2"] = M["jacket"]
    M["cable_a"], M["cable_b"] = M["rubber"], M["redcable"]
    M["spec"] = M["jacket"]
    M["accent"] = M["trim"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 29 de l'industriel ; 13 : 2 tourelles secondaires, sans l'armoire nord-est)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    ng = 4
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, ng, M["emit"], a0=math.pi + 0.2, span=math.pi - 0.4)
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, ng - 1, M["emit"], a0=math.pi + 0.35, span=math.pi - 0.7,
                    per=(3, 2))
    P2.grating(g, 1.65, 1.95, Y(-1.3), Y(1.45), 0.07, M)
    P2.grating(g, -1.95, -1.65, Y(-1.1), Y(1.1), 0.07, M)
    with at(g, -1.45, -1.95, 0.45):
        P2.open_crate(g, (0, 0, 0), 0.84, 0.78, 0.32, M)
    with at(g, 1.45, -1.95, -0.45):
        P2.open_crate(g, (0, 0, 0), 0.84, 0.78, 0.32, M, paint=M["ochre"])
    for (x, yn, rz) in [(-2.4, -2.5, -0.3), (2.4, -2.5, 0.3)]:
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.46, 0.0, 0.32, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            turret_legs(g, 0.46, 0.32)
            mini_turret(g, (0, 0, 0.32), 1.02, rz)
    # ouest : banc d'injecteurs ; liaisons
    west(g)
    conduit(g, [(-1.98, Y(0.7), 0.45), (-1.78, Y(0.75), 0.72), (-1.52, Y(0.62), 0.86)], 0.05)
    conduit(g, [(-1.98, Y(-0.6), 0.45), (-1.78, Y(-0.65), 0.72), (-1.52, Y(-0.55), 0.86)], 0.05)
    cables(g, [(-1.98, Y(0.05), 0.45), (-1.75, Y(0.02), 0.7), (-1.5, Y(0.0), 0.8)])
    signature(g, (-2.43, Y(0.35), 0.6))
    # nord-ouest : banc de condensateurs en biais (réserve d'énergie visible)
    with at(g, -2.05, 2.25, -0.6):
        PT.hull(g, -0.62, 0.62, -0.5, 0.5, 0.0, 0.14, ins=(0.02, 0.02, 0.02), panel=0.3, mats=[M["steel_dk"]],
                rivet_step=0.13)
        PT.capacitors(g, (0.0, 0.0, 0.14), 3, 2, 0.14, 0.48, E)
        P3.lamp_group(g, (-0.5, -0.52, 0.09), (1, 0, 0), (0, -1, 0), E, M, n=3)
        P3.lamp_group(g, (0.2, -0.52, 0.09), (1, 0, 0), (0, -1, 0), M["amber"], M, n=2, shapes=("carre", "fente"))
    conduit(g, [(-1.6, Y(1.95), 0.5), (-1.35, Y(1.6), 0.8), (-1.1, Y(1.25), 0.95)], 0.05)
    # est : deux sphères de confinement sur trépied
    tank(g, 2.4, Y(1.0), 0.44, 0.98, (1, 0.2), (-1, 0), gauges=3)
    tank(g, 2.4, Y(-0.55), 0.44, 0.98, (1, -0.2), (-1, 0), gauges=3)
    P3.cabinet(g, -2.85, -2.08, -2.85, -2.2, 0.0, 0.55, M, E)
    PT.hull(g, 1.98, 2.85, Y(-1.55), Y(-1.18), 0.0, 0.34, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["redpaint"], M["steel_dk"]], rivet_step=0.12)
    for x in (2.15, 2.65):
        P2.handwheel(g, (x, Y(-1.55) - 0.08, 0.22), (0, -1, 0.3), 0.08, M)
    pipe(g, [(1.98, Y(-1.35), 0.24), (1.75, Y(-1.4), 0.26), (1.55, Y(-1.15), 0.48)], 0.055,
         valve_at=((1.77, Y(-1.39), 0.26), (0, -1, 0.5)))
    hose(g, [(1.95, Y(1.0), 0.95), (1.68, Y(0.95), 1.15), (1.4, Y(0.8), 0.95)], 0.06)
    hose(g, [(1.95, Y(-0.55), 0.95), (1.68, Y(-0.55), 1.12), (1.42, Y(-0.4), 0.95)], 0.06)
    # nord : banc de bobines toriques ; armoires de commande
    torus_bank(g, -1.3, 1.3, Y(2.05), Y(2.78), 0.42)
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
    _halo(g, [(2.4, Y(1.0), 0.9), (2.4, Y(-0.55), 0.9)], 10.0, g.M["_emit2_rgb"])


def turret_legs(g, R, h):
    """Trépied SOUS la tourelle secondaire, posé sur le tablier plein."""
    M = g.M
    for k in range(3):
        a = TAU * k / 3 + 0.3
        d = V((math.cos(a), math.sin(a), 0))
        g.box(d * (R + 0.1) + V((0, 0, h * 0.45)), (0.06, 0.06, h * 0.95), M["jacket"], "hard",
              R=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(-0.35, 3, "Y"), what="trepied")
        g.box(d * (R + 0.18) + V((0, 0, 0.03)), (0.12, 0.12, 0.06), M["steel_dk"], "hard", what="semelle")


def west(g):
    """Groupe de l'ouest : BANC D'INJECTEURS (2 × 4 cylindres de céramique à bagues de cuivre, collecteur de cuivre)."""
    M = g.M
    x0, x1, y0, y1, h = -2.88, -1.98, Y(-1.35), Y(1.35), 0.6
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    F.plinth(g, x0, x1, y0, y1, 0.22)
    for col, xx in enumerate((cx - (x1 - x0) * 0.22, cx + (x1 - x0) * 0.22)):
        for i in range(4):
            yy = y0 + (y1 - y0) * (i + 0.5) / 4
            hh = 0.5 + 0.08 * ((i + col) % 2)
            g.cyl((xx, yy, 0.22 + hh / 2), "z", 0.13, hh, M["jacket"], n=20, what="injecteur")
            for zz in (0.32, 0.22 + hh * 0.55, 0.22 + hh - 0.05):
                g.tube_shell((xx, yy, zz), "z", 0.145, 0.12, 0.035, M["copper"], n=20, what="bague")
            g.cyl((xx, yy, 0.22 + hh + 0.02), "z", 0.07, 0.04, M["copper"], n=14, what="chapeau")
            g.cyl((xx, yy, 0.22 + hh + 0.042), "z", 0.04, 0.005, M["emit2"], n=12, style="flat", what="coeur")
            for kk in range(4):
                a = -math.pi / 2 + (kk - 1.5) * 0.7
                d = V((math.cos(a), math.sin(a), 0))
                F.hatches(g, V((xx, yy, 0.22 + hh * 0.3)) + d * 0.125, V((xx, yy, 0.22 + hh * 0.42)) + d * 0.125, 1,
                          d, M["steel_dk"], size=(0.05, 0.05))
    g.hose([(cx, y0 + 0.1, 0.3), (cx, cy, 0.42), (cx, y1 - 0.1, 0.3)], 0.06, M["copper"], step=0.05, n=12)


def torus_bank(g, x0, x1, y0, y1, h):
    """Banc de bobines toriques (fusion) : 3 gros tores couchés en céramique et cuivre, segments magenta, barre."""
    M = g.M
    E = M["emit"]
    F.plinth(g, x0, x1, y0, y1, 0.14)
    cy = (y0 + y1) / 2
    R = min((x1 - x0) / 3, (y1 - y0)) * 0.36
    for i in range(3):
        cx = x0 + (x1 - x0) * (i + 0.5) / 3
        g.cyl((cx, cy, 0.14 + 0.05), "z", R * 0.75, 0.1, M["copper"], n=24, what="embase")
        g.torus((cx, cy, 0.14 + 0.1 + R * 0.32), "z", R, R * 0.32, M["jacket"], n=40, m=14, what="tore")
        g.tube_shell((cx, cy, 0.14 + 0.1 + R * 0.32), "z", R * 0.72, R * 0.3, R * 0.5, M["steel_dk"], n=24,
                     what="moyeu")
        g.cyl((cx, cy, 0.14 + 0.1 + R * 0.32), "z", R * 0.32, R * 0.55, M["steel_dk"], n=16, what="noyau")
        for k in range(10):
            a = TAU * (k + 0.25) / 10
            d = V((math.cos(a), math.sin(a), 0))
            g.box(V((cx, cy, 0.14 + 0.1 + R * 0.62)) + d * (R * 0.86), (0.05, 0.05, 0.014), M["steel_dk"], "hard",
                  R=Matrix.Rotation(a, 3, "Z"), what="bride")
        for k in range(6):
            a = TAU * (k + 0.5) / 6
            d = V((math.cos(a), math.sin(a), 0))
            g.torus(V((cx, cy, 0.14 + 0.1 + R * 0.32)) + d * R, d.cross(V((0, 0, 1))), R * 0.34, 0.018, M["copper"],
                    n=16, m=4, what="cerclage")
            if d.y < -2:
                g.box(V((cx, cy, 0.14 + 0.1 + R * 0.62)) + d * R, (0.07, 0.025, 0.012), E, "flat",
                      R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="segment_lum")
    g.box(((x0 + x1) / 2, y1 - 0.08, 0.2), (x1 - x0 - 0.1, 0.06, 0.08), M["copper"], "hard", what="barre")


def tank(g, x, y, r, h, ladder_dir, stub_dir, gauges=2, rings=1):
    """SPHÈRE DE CONFINEMENT sur trépied court (même place et même masse que le réservoir debout de la lignée) :
    céramique patinée, cerclages de cuivre, tore magenta segmenté, hublots à cœur orange, gaine de cuivre."""
    M = g.M
    E = M["emit"]
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
    for zz_, nn in ((0.18, 14), (0.62, 10)):
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
    F.seg_ring(g, x, y, rs + 0.03, zc, 6, E)
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


def signature(g, p, kind=0):
    """Petite pièce de signature : 2 injecteurs de céramique à bague de cuivre et cœur orange."""
    M = g.M
    p = V(p)
    for s in (-1, 1):
        c = p + V((s * 0.06, 0, 0.08))
        g.cyl(c, "z", 0.035, 0.16, M["jacket"], n=14, what="injecteur")
        g.tube_shell(c + V((0, 0, 0.03)), "z", 0.042, 0.03, 0.016, M["copper"], n=14, what="bague")
        g.cyl(c + V((0, 0, 0.085)), "z", 0.02, 0.01, M["emit2"], n=10, style="flat", what="coeur")


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
        _gun13(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
    PT.lamp(g, (0.0, 0.12 * s, 0.4 * s + 0.01), (0, 0.35, 1), 0.035, E, cage=False)
    PT.hatch(g, (0.0, -0.12 * s, 0.4 * s), 0.09 * s)
    g.pop()


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : gaines annelées de cuivre nombreuses et épaisses
# ------------------------------------------------------------------------------------------------
def hose(g, ctrl, r):
    M = g.M
    g.hose(ctrl, r * 1.35, M["copper"], step=0.048, n=12)


def cables(g, ctrl, n=3):
    M = g.M
    PT.cable_run(g, ctrl, n, 0.02, 0.045, [M["rubber"], M["redcable"], M["rubber"]])


def conduit(g, ctrl, r):
    """Conduit d'énergie : grosse gaine annelée de cuivre."""
    M = g.M
    g.hose(ctrl, r * 1.5, M["copper"], step=0.048, n=12)


def pipe(g, ctrl, r, valve_at=None):
    M = g.M
    g.pipe(ctrl, r, M["copper"], fl_mat=M["brass"], bolt_mat=M["rivet"])
    if valve_at is not None:
        p, ax = valve_at
        g.box(p, (r * 3.2, r * 3.2, r * 3.2), M["steel_dk"], "hard", what="corps_vanne")
        P2.handwheel(g, V(p) + V(ax).normalized() * (r * 1.6 + 0.06), ax, 0.07, M)


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 26 : 2 injecteurs-condensateurs à plasma
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.22, Y(-2.97), sx)
    _halo(g, [(-1.22, Y(-3.1), 0.4), (1.22, Y(-3.1), 0.4)], 18.0)


def even_piece(g, x, yb, sx):
    """INJECTEUR-CONDENSATEUR À PLASMA : cylindre vertical cerclé de cuivre, tore segmenté, câblage, sur la plinthe
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
    c = V((x, yb, z0))
    g.cyl(c + V((0, 0, 0.3)), "z", 0.17, 0.6, M["jacket"], n=28, style="smooth", what="cylindre")
    for zz in (0.06, 0.24, 0.42, 0.58):
        g.tube_shell(c + V((0, 0, zz)), "z", 0.185, 0.16, 0.035, M["copper"], n=28, what="cerclage")
    F.seg_ring(g, x, yb, 0.22, z0 + 0.33, 6, E)
    g.cyl(c + V((0, 0, 0.64)), "z", 0.12, 0.06, M["copper"], n=20, what="chapeau")
    g.cyl(c + V((0, 0, 0.68)), "z", 0.06, 0.02, M["emit2"], n=16, style="flat", what="coeur")
    for a in (-1.1, -2.0):
        dd = V((math.cos(a), math.sin(a), 0))
        g.cyl(c + V((0, 0, 0.14)) + dd * 0.17, dd, 0.03, 0.03, M["steel_dk"], n=12, what="hublot")
        g.cyl(c + V((0, 0, 0.14)) + dd * 0.186, dd, 0.02, 0.005, M["emit2"], n=10, style="flat", what="hublot_lum")
    g.hose([tuple(c + V((-sx * 0.15, 0.1, 0.5))), tuple(c + V((-sx * 0.35, 0.3, 0.4))),
            tuple(c + V((-sx * 0.42, 0.55, 0.15)))], 0.04, M["copper"], step=0.03)


# ------------------------------------------------------------------------------------------------
# Arme (E1) : canon à plasma
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse, moteur arrière, arme d'époque, masque de canon,
    alimentation, voyants d'état, collecteur d'injecteurs sur la culasse."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _gun13(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    for f in (0.28, 0.5):
        g.box((x - sx * wr * 0.22, y0 + (y1 - y0) * f, zg + hr + 0.012), (0.03, (y1 - y0) * 0.12, 0.012), M["emit"],
              "flat", what="etat")
    # collecteur de cuivre à 2 injecteurs debout
    zt = zg + hr + 0.012
    g.box((x, (y0 + y1) / 2, zt + 0.03), (wr * 0.5, (y1 - y0) * 0.5, 0.05), M["copper"], "hard", what="collecteur")
    for f in (0.35, 0.65):
        cc = V((x, y0 + (y1 - y0) * f, zt + 0.13))
        g.cyl(cc, "z", 0.04, 0.14, M["jacket"], n=14, what="injecteur")
        g.tube_shell(cc + V((0, 0, 0.03)), "z", 0.047, 0.035, 0.016, M["copper"], n=14, what="bague")
        g.cyl(cc + V((0, 0, 0.075)), "z", 0.02, 0.008, M["copper"], n=10, style="flat", what="embout")


def _gun13(g, x, y0, z, L, nb, rb, rr):
    """Troisième passe : canon à plasma = une grosse CHAMBRE DE CONFINEMENT sphérique en céramique au pied (cerclages
    de cuivre, injecteurs, tore segmenté), puis un empilement de 7 ANNEAUX TORIQUES épais (céramique et cuivre en
    alternance, 0,6 tuile de diamètre) sur une âme sombre, puis une BUSE évasée à cœur orange. De dessus : une boule
    suivie d'un chapelet de perles ; de face : des cercles empilés."""
    M = g.M
    E, E2 = M["emit"], M["emit2"]
    k = F.k_arme(rb, rr)
    rs = 0.3 * k
    cy = y0 + rs * 0.85
    C = V((x, cy, z))
    g.sphere(C, rs, M["jacket"], n=32, m=16, what="chambre")
    for f in (-0.55, 0.0, 0.55):
        rr_ = rs * math.sqrt(1 - f * f)
        g.torus(C + V((0, f * rs, 0)), "y", rr_ + 0.004, 0.016, M["copper"], n=36, m=6, what="cerclage")
        for d in F.ring_dirs(8, 0.2, -0.4):
            g.dome(C + V((0, f * rs, 0)) + d * (rr_ + 0.018), d, 0.012, M["rivet"])
    for d in F.ring_dirs(7, 0.25, -0.5):
        R = F.Rax(d)
        g.box(C + V((0, -0.3 * rs, 0)) + d * (rs * 0.95 + 0.02), (0.07 * k, 0.03, 0.022), E, "flat", R=R,
              what="tore_seg")
    for dv in (V((0, -0.5, 0.86)), V((0.82, -0.5, 0.3)), V((-0.82, -0.5, 0.3))):
        d = dv.normalized()
        p = C + d * (rs + 0.06 * k)
        g.cyl(p, d, 0.045 * k, 0.16 * k, M["jacket"], n=14, what="injecteur")
        g.cyl(p - d * 0.03 * k, d, 0.052 * k, 0.02, M["copper"], n=14, style="hard", what="bague")
        g.cyl(p + d * 0.085 * k, d, 0.018 * k, 0.005, E2, n=10, style="flat", what="coeur")
    # âme et anneaux toriques empilés
    ys, ye = cy + rs * 0.8, y0 + 0.86 * L
    rC = 0.1 * k
    g.cyl((x, (ys + ye) / 2, z), "y", rC, ye - ys + 0.04, M["steel_dk"], n=20, what="ame")
    Rt, rt = 0.18 * k, 0.075 * k
    nt = 7
    for i in range(nt):
        yy = ys + rt + (ye - ys - 2 * rt) * i / (nt - 1)
        mat = M["jacket"] if i % 2 == 0 else M["copper"]
        g.torus((x, yy, z), "y", Rt, rt if i % 2 == 0 else rt * 0.8, mat, n=40, m=12, what="anneau_torique")
        g.tube_shell((x, yy, z), "y", Rt, rC - 0.005, rt * 1.2, M["steel_dk"], n=24, what="moyeu")
        if k >= 0.9:
            for d in F.ring_dirs(5, 0.2 + i * 0.4, -0.3):
                g.box(V((x, yy, z)) + d * (Rt + rt * 0.98), (0.05, 0.045, 0.014), M["steel_dk"], "hard", R=F.Rax(d),
                      what="bride")
        if i in (2, 4) and k >= 0.9:
            for d in F.ring_dirs(4, 0.4 + i * 0.3, -0.5):
                g.box(V((x, yy, z)) + d * (Rt + rt * 0.92), (0.05 * k, 0.04, 0.008), E, "flat", R=F.Rax(d),
                      what="segment_lum")
    # tirants de cuivre le long de l'empilement (relient les anneaux : aucun jour enfermé)
    for d in (V((0, 0, 1)), V((1, 0, 0)), V((-1, 0, 0))):
        p0 = V((x, ys, z)) + d * (Rt - rt * 0.4)
        p1 = V((x, ye, z)) + d * (Rt - rt * 0.4)
        g.tube([p0, p1], 0.022 * k, M["copper"], n=8, what="tirant")
    # buse évasée en céramique, ailettes, cœur orange
    lb = 0.28 * k
    g.tube_shell((x, ye + 0.02, z), "y", Rt + 0.02, rC * 0.6, 0.05, M["copper"], n=30, what="bague")
    g.cyl((x, ye + lb / 2 + 0.03, z), "y", Rt * 0.9, lb, M["jacket"], n=30, r2=Rt * 1.45, style="smooth", what="buse")
    for d in F.ring_dirs(6, 0.0, -0.6):
        g.box(V((x, ye + lb / 2 + 0.03, z)) + d * (Rt * 1.22), (0.022, lb * 0.85, 0.08 * k), M["jacket"], "hard",
              R=F.Rax(d), what="ailette")
    yt = ye + lb + 0.03
    g.cyl((x, yt + 0.002, z), "y", Rt * 1.3, 0.008, M["void"], n=28, style="flat", what="fond")
    g.cyl((x, yt + 0.006, z), "y", Rt * 0.55, 0.006, E2, n=20, style="flat", what="coeur")
    F.muzzle_glow(g, x, yt + 0.007, z, Rt * 1.38, E)
    return yt


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisse (volume de la lignée) kaki et sombre, INJECTEURS debout (céramique, bagues de
    cuivre) reliés à la chambre de confinement par du cuivre annelé, voyants."""
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
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=[M["olive"], M["steel_dk"]],
            rivet_step=0.11)
    ztop = zb1 + 0.015
    g.hazard(PT.lift([V((bx0, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.2, zb1)),
                      V((bx0, yb0 + bl * 0.2, zb1))], 0.012), 4, t=0.01)
    for k in range(3):
        yy = yb0 + bl * (0.22 + 0.28 * k)
        c = V((bc, yy, ztop + 0.09))
        g.cyl(c, "z", 0.045, 0.18, M["jacket"], n=16, what="injecteur")
        for zz in (-0.06, 0.0, 0.06):
            g.tube_shell(c + V((0, 0, zz)), "z", 0.052, 0.04, 0.018, M["copper"], n=16, what="bague")
        g.cyl(c + V((0, 0, 0.1)), "z", 0.025, 0.03, M["emit2"], n=10, style="flat", what="coeur")
    rs = H["rb"] + H["rr"] + 0.07 * F.k_arme(H["rb"], H["rr"])
    g.hose([(bc, yb0 + bl * 0.75, ztop + 0.12), (x + sx * wr * 0.3, yb0 + bl * 0.85, zg + hr + 0.1),
            (x + sx * wr * 0.15, y1 - 0.02, zg + hr + 0.08), (x, y1 + rs * 0.6, zg + rs * 0.85)], 0.03,
           M["copper"], step=0.03)
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
    _gun13(g, 0.0, 0.66 * s, zc, L, nb, rb, rr)
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
    F.slits_grouped(g, R, z0 + 0.2, 4, M["emit"])
    F.slits_grouped(g, R, z0 + 0.36, 3, M["emit"], a0=0.3, per=(3, 2))
    for sx in (-1, 1):
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, H["zs"] + 0.25), (sx * R * 0.62, -R * 0.42, H["zs"] + H["rz"] * 0.55),
              (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
        conduit(g, [(sx * 0.6, -R - 0.3, H["zs"] + 0.2), (sx * R * 0.72, -R * 0.5, H["zs"] + H["rz"] * 0.4),
                    (xe, ye + 0.2, H["zg"] + H["hr"] * 0.55)], 0.04)
    row1 = (0.35, 0.75, 1.15, 2.0, 2.4, 2.8, -0.35)
    ph1, w1, h1 = (0.3, 0.32, 0.26)
    for i, th in enumerate(row1):
        mat = M["trim"] if i % 3 == 1 else (M["ochre"] if i % 2 else M["steel_dk"])
        P2.applique(g, c.Pf, c.Nf, th, ph1, w1, h1, mat, M)
    dome_gun(g, H, 6, 1.7, 1.0)
    # sommet de la tête : CHAMBRE DE CONFINEMENT sphérique sur la nacelle (céramique, cuivre, tore segmenté)
    bx, yb0, yb1 = c.nac[:3]
    znac = H["zs"] + H["rz"] * 0.42
    rs = 0.3
    C = V((0, (yb0 + yb1) / 2 - 0.05, znac + rs * 0.9))
    g.cyl(C - V((0, 0, rs * 0.75)), "z", rs * 0.75, 0.12, M["copper"], n=24, what="embase")
    g.sphere(C, rs, M["jacket"], n=32, m=16, what="chambre")
    for zz in (-0.4, 0.0, 0.45):
        rr = rs * math.sqrt(1 - zz * zz)
        g.torus(C + V((0, 0, rs * zz)), "z", rr + 0.005, 0.016, M["copper"], n=40, m=6, what="cerclage")
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        d = V((math.cos(a), math.sin(a), 0))
        g.box(C + V((0, 0, rs * 0.2)) + d * (rs * 0.98 + 0.012), (0.07, 0.01, 0.025), E, "flat",
              R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="tore_seg")
    g.cyl(C + V((0, 0, rs + 0.03)), "z", 0.08, 0.06, M["copper"], n=16, what="bride")
    for k in range(12):
        a = TAU * (k + 0.5) / 12
        d = V((math.cos(a) * 0.94, math.sin(a) * 0.94, 0.34))
        g.push_frame(C + d * (rs + 0.003), d)
        g.box((0, 0, 0.006), (0.05, 0.05, 0.014), M["steel_dk"], "hard", what="trappe")
        g.pop()
    g.cyl(C + V((0, 0, rs + 0.065)), "z", 0.04, 0.006, M["emit2"], n=12, style="flat", what="coeur")
    for k in range(10):
        a = TAU * k / 10
        d = V((math.cos(a), math.sin(a), 0))
        g.dome(C + d * (rs + 0.022), d, 0.012, M["rivet"])
        g.dome(C + V((0, 0, rs * 0.45)) + d * (rs * 0.893 + 0.02), d, 0.012, M["rivet"])
    for s in (-1, 1):
        g.hose([tuple(C + V((s * rs * 0.7, 0.0, -rs * 0.55))), tuple(C + V((s * (rs + 0.12), -0.05, -rs * 0.8))),
                tuple(C + V((s * (rs + 0.2), -0.1, -rs * 0.9 - 0.02)))], 0.045, M["copper"], step=0.04, n=10)
    PT.capacitors(g, (0.0, -R - 0.14, H["zs"] + H["rz"] * 0.42), 4, 1, 0.1, 0.22, M["emit"])
    PT.sight(g, (-R * 0.64, R * 0.3, H["zs"] + H["rz"] * 0.5), 0.26, 0.26, 0.15, M["emit"], lenses=2)
