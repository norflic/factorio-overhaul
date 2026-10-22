"""Époque 12 · Supraconducteurs (ère IV, 5×5, niveaux 23 et 24). Constructeur : PLAGE HAUTE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 12) : « chrome, givre, anneaux ».
PORTÉ TEL QUEL de la passe 3 (gun_e_haut, commit 4c57982 : design.py, armes.py, ages.py ; outil de portage, code d'origine mot pour
mot ; les aiguillages par époque sont réduits à la branche de l'époque 12) sur le kit commun gun_e : seul le CORPS a
changé (corps.py, kit.py ; la règle commune de reflets plafonne aussi le chrome : rugosité >= 0,38). Aucune
correction de design d'époque.
Emplacements remplis : arme (CANON À RAILS dans 4 GRANDS ANNEAUX magnétiques chromés, culasse cryogénique, bouche en
cadre à fente cyan), canon de coupole à 4 tubes (rails), 2 tourelles secondaires, grands volumes du socle
(compresseurs cryogéniques à l'ouest, portiques à grands anneaux à l'est et au nord-ouest), liaisons (mousse
givrée, tuyaux chromés à soufflets), dewars sur la nacelle, foyers cyan glacé, pièce paire (2 bobines sur pylône).
Défaut relevé par les juges (à corriger par le constructeur, RÈGLE D'OR 1) : plus de faisceau rotatif du tout.
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

EPOQUE = 12
NOM = "Supraconducteurs"
FOYER = dict(rgb=(0.29, 0.94, 1.0), rgb2=(0.29, 0.94, 1.0))
CANON = dict(L=2.2, nb=6, rb=0.06, rr=0.145)
PLATEFORME = dict(chanfrein=0.4)
HABILLAGE = dict(jupe_cerclage="ring", chapeau="ring")
RECV = ("jacket", "steel_dk")


def matieres(metal, M):
    """Supraconducteurs : noir profond, chrome (reflets francs dans la limite commune), givre (≤ 3 %)."""
    metal("jacket", (0.034, 0.035, 0.038), rough=0.3, met=0.6, grain=0.1, gscale=40.0, dirt=0.5, stain=0.3,
          wear=1.5)
    metal("ring", (0.8, 0.81, 0.83), rough=0.16, met=1.0, grain=0.06, gscale=60.0, dirt=0.5, stain=0.12,
          wear=0.3)
    metal("trim", (0.55, 0.6, 0.64), rough=0.85, met=0.0, grain=0.3, gscale=80.0, dirt=0.3, stain=0.3)  # givre
    metal("pipe", (0.38, 0.37, 0.34), rough=0.9, met=0.0, grain=0.35, gscale=50.0, rust=(0.2, 0.18, 0.15),
          ra=0.15, dirt=0.8, stain=0.6, sscale=5.0, streak=0.5)                                   # mousse givrée
    M["pipe2"] = M["ring"]
    metal("cable_a", (0.018, 0.018, 0.02), rough=0.55, met=0.0, grain=0.1, dirt=0.3, stain=0.0)
    M["cable_b"] = M["cable_a"]
    M["spec"] = M["trim"]
    M["accent"] = M["trim"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 21 de l'industriel ; 12 : 2e tourelle secondaire)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    ng = 8
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, ng, M["emit"], a0=math.pi + 0.2, span=math.pi - 0.4)
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, ng - 1, M["emit"], a0=math.pi + 0.35, span=math.pi - 0.7,
                    per=(3, 2))
    P2.grating(g, 1.35, 1.75, Y(-1.15), Y(1.3), 0.07, M)
    P2.grating(g, -1.55, -1.3, Y(-1.0), Y(-0.3), 0.07, M)
    with at(g, -1.5, -1.72, 0.42):
        P2.open_crate(g, (0, 0, 0), 0.78, 0.72, 0.3, M)
    with at(g, -1.05, -2.35, 0.08):
        P2.open_crate(g, (0, 0, 0), 0.6, 0.5, 0.22, M, paint=M["ochre"])
    for (x, yn, rz) in [(1.78, -1.82, 0.0), (-2.0, -2.28, 0.25)]:
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.42, 0.0, 0.28, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            mini_turret(g, (0, 0, 0.28), 0.95, rz)
    west(g)
    conduit(g, [(-1.62, Y(0.55), 0.4), (-1.42, Y(0.6), 0.62), (-1.2, Y(0.5), 0.72)], 0.045)
    cables(g, [(-1.62, Y(-0.25), 0.4), (-1.42, Y(-0.3), 0.6), (-1.18, Y(-0.35), 0.68)])
    # nord-ouest : portique à grands anneaux posé en biais
    with at(g, -1.72, 2.02, -0.55):
        ring_gantry(g, 0.0, -0.38, 0.38, 0.34, 0.42)
    # est : portique à grands anneaux magnétiques (à la place des réservoirs)
    ring_gantry(g, 2.0, Y(-0.6), Y(1.15), 0.42, 0.56)
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
    for x in (-0.68, 0.68):
        PT.lamp(g, (x, Y(-2.4) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    _halo(g, [(-2.0, Y(-1.1), 0.5), (1.78, Y(-2.1), 0.6), (0.0, Y(-2.5), 0.5), (2.0, Y(0.3), 0.5),
              (1.75, Y(1.8), 0.5)], 20.0)


def west(g):
    """Groupe de l'ouest : COMPRESSEURS CRYOGÉNIQUES (3 dewars noirs à cols chromés, givre, tuyaux de mousse)."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1, h = -2.42, -1.62, Y(-0.95), Y(1.25), 0.52
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    F.plinth(g, x0, x1, y0, y1, 0.18)
    r = (x1 - x0) * 0.32
    ys = [y0 + (y1 - y0) * f for f in (0.18, 0.5, 0.82)]
    for i, yy in enumerate(ys):
        hh = 0.62 + 0.06 * (i % 2)
        g.cyl((cx, yy, 0.18 + hh / 2), "z", r, hh, M["jacket"], n=28, what="dewar")
        for zz in (0.3, 0.18 + hh * 0.7):
            g.tube_shell((cx, yy, zz), "z", r + 0.02, r - 0.01, 0.05, M["ring"], n=28, what="collier")
        g.cyl((cx, yy, 0.18 + hh + 0.06), "z", r * 0.42, 0.12, M["ring"], n=20, what="col")
        g.tube_shell((cx, yy, 0.18 + hh + 0.01), "z", r * 0.5, r * 0.4, 0.03, M["trim"], n=20, what="givre")
        g.box((cx - r * 0.7, yy - r * 0.7, 0.4), (0.06, 0.03, 0.12), M["trim"], "flat", what="givre")
        P3.lamp_group(g, (cx + r * 0.2, yy - r - 0.005, 0.45), (1, 0, 0), (0, -1, 0), E, M, n=2,
                      shapes=("fente", "rond"))
    g.tube([V((cx + r * 0.6, ys[0], 0.75)), V((cx + r * 0.9, (ys[0] + ys[1]) / 2, 0.85)),
            V((cx + r * 0.6, ys[1], 0.78))], 0.04, M["pipe"], n=10, what="mousse")
    g.tube([V((cx + r * 0.6, ys[1], 0.78)), V((cx + r * 0.9, (ys[1] + ys[2]) / 2, 0.88)),
            V((cx + r * 0.6, ys[2], 0.75))], 0.04, M["pipe"], n=10, what="mousse")


def ring_gantry(g, x, y0, y1, R, zc):
    """Âme noire couchée le long de y, 3 GRANDS anneaux chromés debout (rayon R), tenus par des pinces et un berceau ;
    givre aux joints ; segments cyan. Aucun anneau ne flotte : chaque anneau repose sur un berceau boulonné."""
    M = g.M
    E = M["emit"]
    L = y1 - y0
    F.plinth(g, x - R * 0.85, x + R * 0.85, y0 - 0.05, y1 + 0.05, 0.1)
    g.cyl((x, (y0 + y1) / 2, zc), "y", R * 0.34, L, M["jacket"], n=24, what="ame")
    for f in (0.0, 1.0):
        g.cyl((x, y0 + f * L, zc), "y", R * 0.4, 0.06, M["ring"], n=24, what="bride")
    for i in range(3):
        yy = y0 + L * (0.2 + 0.3 * i)
        g.tube_shell((x, yy, zc), "y", R, R * 0.74, 0.13, M["ring"], n=56, what="anneau")
        g.torus((x, yy, zc), "y", R, 0.014, M["steel_dk"], n=56, m=6, what="jonc")
        # berceau : 2 jambes vers le socle + traverse (l'anneau y repose)
        for s in (-1, 1):
            a = -math.pi / 2 + s * 0.6
            d = V((math.cos(a), 0, math.sin(a)))
            p = V((x, yy, zc)) + d * R
            g.box(((p.x + x + s * R * 0.7) / 2, yy, p.z / 2 + 0.05), (0.08, 0.1, p.z - 0.02), M["steel_dk"], "hard",
                  what="jambe")
        g.box((x, yy, 0.16), (R * 1.4, 0.16, 0.08), M["steel_dk"], "hard", what="traverse")
        # entretoises de l'âme à l'anneau (jour de « lévitation » fermé)
        for d in F.ring_dirs(4, math.pi / 4, -2):
            g.box(V((x, yy, zc)) + d * (R * 0.55), (0.05, 0.07, R * 0.42), M["steel_dk"], "hard", R=F.Rax(d),
                  what="entretoise")
        for d in F.ring_dirs(3, 0.5, -0.3):
            g.box(V((x, yy - 0.068, zc)) + d * (R * 0.87), (0.07, 0.004, 0.024), E, "flat", R=F.Rax(d),
                  what="segment_lum")
        g.box((x - R * 0.5, yy + 0.07, zc + R * 0.75), (0.08, 0.03, 0.02), M["trim"], "flat", what="givre")


def signature(g, p, kind=0):
    """Petite pièce de signature : petite bobine supraconductrice chromée sur colonnettes, givre."""
    M = g.M
    p = V(p)
    for s in (-1, 1):
        g.cyl(p + V((s * 0.08, 0, 0.06)), "z", 0.015, 0.12, M["steel_dk"], n=8, what="colonnette")
    g.torus(p + V((0, 0, 0.13)), "x", 0.07, 0.022, M["ring"], n=24, m=8, what="bobine")
    g.cyl(p + V((0, 0, 0.13)), "x", 0.03, 0.18, M["jacket"], n=12, what="noyau")
    g.box(p + V((0, -0.06, 0.02)), (0.16, 0.03, 0.03), M["trim"], "flat", what="givre")


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
        _gun12(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
    PT.lamp(g, (0.0, 0.12 * s, 0.4 * s + 0.01), (0, 0.35, 1), 0.035, E, cage=False)
    PT.hatch(g, (0.0, -0.12 * s, 0.4 * s), 0.09 * s)
    g.pop()


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : conduits cryogéniques gainés de mousse givrée, soufflets chromés, câbles noirs épais
# ------------------------------------------------------------------------------------------------
def hose(g, ctrl, r):
    """Conduit cryogénique : gaine de mousse givrée, soufflets chromés aux bouts, bagues de givre."""
    M = g.M
    P, T = g.tube(g.spline(ctrl, 10), r * 1.3, M["pipe"], n=12, what="mousse")
    for i in (0, len(P) - 1):
        g.hose([tuple(P[i] - T[i] * 0.06), tuple(P[i] + T[i] * 0.06)], r * 1.4, M["ring"], step=0.025)
    for i in range(3, len(P) - 2, 7):
        g.cyl(P[i], T[i], r * 1.42, 0.025, M["trim"], n=12, style="flat", what="givre")


def cables(g, ctrl, n=3):
    """Deux câbles noirs épais."""
    M = g.M
    PT.cable_run(g, ctrl, 2, 0.032, 0.075, [M["cable_a"], M["cable_a"]])


def conduit(g, ctrl, r):
    """Conduit d'énergie noir : bagues lumineuses PAR GROUPES (chenillard), colliers chromés."""
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
# Pièce du niveau 24 : 2 bobines d'accélération sur pylône
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.5, Y(-2.64), sx)
    _halo(g, [(-1.5, Y(-2.9), 0.4), (1.5, Y(-2.9), 0.4)], 16.0)


def even_piece(g, x, yb, sx):
    """BOBINE D'ACCÉLÉRATION SUR PYLÔNE : 2 anneaux chromés tenus par un pylône à pinces, noyau noir, sur la plinthe
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
    PT.hull(g, x - 0.12, x + 0.12, yb - 0.12, yb + 0.12, z0, z0 + 0.5, ins=(0.03, 0.03, 0.03), panel=0.25,
            mats=[M["steel_dk"], M["jacket"]], rivet_step=0.11)
    zc = z0 + 0.42
    g.cyl((x, yb, zc), "y", 0.06, 0.5, M["jacket"], n=16, what="noyau")
    for dy in (-0.14, 0.12):
        g.tube_shell((x, yb + dy, zc), "y", 0.23, 0.15, 0.07, M["ring"], n=40, what="anneau")
        F.seg_ring_y(g, x, yb + dy - 0.037, zc, 0.19, 5, E)
        for s in (-1, 1):
            g.box((x + s * 0.17, yb + dy, zc - 0.13), (0.05, 0.09, 0.14), M["steel_dk"], "hard", what="pince")
    g.box((x, yb, zc - 0.21), (0.44, 0.1, 0.05), M["steel_dk"], "hard", what="traverse")
    g.box((x, yb + 0.2, zc + 0.2), (0.12, 0.05, 0.03), M["trim"], "flat", what="givre")


# ------------------------------------------------------------------------------------------------
# Arme (E1) : canon à rails dans de grands anneaux
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse, moteur arrière, arme d'époque, masque de canon,
    alimentation, voyants d'état, bandes chromées de culasse."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _gun12(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    for f in (0.28, 0.5):
        g.box((x - sx * wr * 0.22, y0 + (y1 - y0) * f, zg + hr + 0.012), (0.03, (y1 - y0) * 0.12, 0.012), M["emit"],
              "flat", what="etat")
    # 2 bandes chromées en travers de la culasse, givre aux joints
    zt = zg + hr + 0.012
    for f in (0.3, 0.62):
        yy = y0 + (y1 - y0) * f
        g.box((x, yy, zt + 0.01), (wr * 0.98, 0.06, 0.03), M["ring"], "hard", what="bande")
        g.box((x - wr * 0.3, yy - 0.04, zt + 0.004), (0.08, 0.025, 0.012), M["trim"], "flat", what="givre")


def _gun12(g, x, y0, z, L, nb, rb, rr):
    """Troisième passe : plus de faisceau rotatif. Deux RAILS noirs à arête chromée et conducteur de cuivre, sur une
    âme noire ; 4 GRANDS ANNEAUX chromés (0,8 tuile de diamètre à l'ère IV) enfilés autour, « en lévitation » : un
    jour étroit entre anneau et rails, FERMÉ par des entretoises à pinces (aucune pièce qui flotte). Culasse
    cryogénique (2 cellules givrées) ; bouche en cadre chromé à fente cyan. De dessus : une tige noire barrée de
    4 grandes barres chromées ; de face : 4 cercles concentriques autour de 2 rails."""
    M = g.M
    E = M["emit"]
    k = F.k_arme(rb, rr)
    hwr, hhr, sep = 0.05 * k, 0.17 * k, 0.15 * k
    for s in (-1, 1):
        xr = x + s * sep
        g.box((xr, y0 + L / 2, z), (2 * hwr, L, 2 * hhr), M["jacket"], "hard", what="rail")
        g.box((xr, y0 + L / 2, z + hhr + 0.004), (2 * hwr * 0.7, L * 0.99, 0.012), M["ring"], "hard", what="arete")
        g.box((xr - s * (hwr + 0.004), y0 + L / 2, z), (0.008, L * 0.97, hhr * 1.1), M["copper"], "hard",
              what="conducteur")
        for i in range(int(L * 0.9 / 0.11)):
            g.dome((xr + s * (hwr + 0.002), y0 + 0.08 + i * 0.11, z + hhr * 0.55), (s, 0, 0), 0.013, M["rivet"])
    g.box((x, y0 + L * 0.5, z - hhr * 0.25), (2 * (sep - hwr) + 0.02, L * 0.98, hhr * 1.4), M["jacket"], "hard",
          what="ame")
    g.box((x, y0 + L * 0.5, z + hhr * 0.35), (2 * (sep - hwr) - 0.01, L * 0.96, 0.01), E, "flat", what="fente_lum")
    # culasse cryogénique : 2 cellules givrées couchées sur l'arrière des rails
    for s in (-1, 1):
        c = V((x + s * (sep + hwr + 0.07 * k), y0 + 0.24 * k, z + 0.02))
        g.cyl(c, "y", 0.07 * k, 0.36 * k, M["jacket"], n=18, what="cellule")
        for t in (-0.15, 0.15):
            g.cyl(c + V((0, t * k, 0)), "y", 0.076 * k, 0.03, M["ring"], n=18, what="chapeau")
        g.tube_shell(c, "y", 0.078 * k, 0.06 * k, 0.05, M["trim"], n=18, what="givre")
    # grands anneaux magnétiques, entretoises et pinces, segments cyan sur la face avant
    ro, ri, w = 0.42 * k, 0.3 * k, 0.15 * k
    for f in (0.36, 0.53, 0.7, 0.87):
        yy = y0 + f * L
        # anneau ÉPAIS (tore chromé de 0,15 de section sur une âme annulaire) : lisible de dessus au zoom 1
        g.tube_shell((x, yy, z), "y", ro - 0.05 * k, ri, w * 0.8, M["jacket"], n=48, what="anneau_ame")
        g.torus((x, yy, z), "y", ro - 0.07 * k, 0.07 * k, M["ring"], n=48, m=12, what="anneau")
        g.tube_shell((x, yy, z), "y", ro - 0.12 * k, ri, w * 0.95, M["steel_dk"], n=36, what="jonc")
        g.cyl((x, yy, z), "y", ri + 0.01, w * 0.45, M["jacket"], n=36, what="flasque")
        for d in F.ring_dirs(4, math.pi / 4, -2):
            R = F.Rax(d)
            # entretoise : de l'anneau aux rails (ferme le jour de « lévitation »)
            g.box(V((x, yy, z)) + d * ((ri + 0.17 * k) / 2), (0.04 * k, w * 0.7, ri - 0.15 * k), M["steel_dk"], "hard",
                  R=R, what="entretoise")
            g.box(V((x, yy, z)) + d * (ro + 0.01), (0.06 * k, w * 1.3, 0.04), M["steel_dk"], "hard", R=R, what="pince")
            g.dome(V((x, yy, z)) + d * (ro + 0.032), d, 0.013, M["rivet"])
        for d in F.ring_dirs(5, 0.0, -0.4):
            g.box(V((x, yy + w / 2 + 0.002, z)) + d * ((ri + ro) / 2), (0.06 * k, 0.004, 0.022), E, "flat", R=F.Rax(d),
                  what="segment_lum")
        g.box(V((x - ro * 0.6, yy - w * 0.4, z + ro * 0.62)), (0.06, 0.03, 0.02), M["trim"], "flat", what="givre")
    # culasse magnétique dorsale et quille : plaques fines dans l'axe, de l'anneau 1 au dernier (aucun jour enfermé
    # entre les anneaux, vus de dessus comme de face)
    ya_, yb_ = y0 + 0.36 * L, y0 + 0.87 * L
    g.box((x, (ya_ + yb_) / 2, z + (hhr + ro * 0.92) / 2), (0.05 * k, yb_ - ya_, ro * 0.92 - hhr), M["jacket"], "hard",
          what="culasse_dorsale")
    g.box((x, (ya_ + yb_) / 2, z + ro * 0.9), (0.08 * k, yb_ - ya_, 0.025), M["ring"], "hard", what="arete")
    g.box((x, (ya_ + yb_) / 2, z - (hhr + ro * 0.92) / 2), (0.05 * k, yb_ - ya_ + 0.1, ro * 0.92 - hhr), M["jacket"],
          "hard", what="quille")
    if k < 0.9:
        # petit canon à rails (coupole, tourelles secondaires) : caisson d'accélérateur plein entre les anneaux
        g.box((x, (ya_ + yb_) / 2 + 0.05 * L, z + ro * 0.12), (2 * ro * 0.86, yb_ - ya_ + 0.1 * L, 2 * ro), M["jacket"],
              "hard", what="caisson")
        for f in (0.2, 0.5, 0.8):
            g.box((x, ya_ + (yb_ - ya_) * f, z + ro * 1.12), (ro * 1.2, 0.05, 0.012), M["ring"], "hard", what="plaque")
    # bouche : cadre chromé à fente cyan
    ym = y0 + L + 0.04
    ow = sep + hwr + 0.05
    g.box((x, ym, z + hhr + 0.035), (2 * ow + 0.05, 0.08, 0.05), M["ring"], "hard", what="cadre")
    g.box((x, ym, z - hhr - 0.03), (2 * ow + 0.05, 0.08, 0.04), M["ring"], "hard", what="cadre")
    for s in (-1, 1):
        g.box((x + s * ow, ym, z), (0.05, 0.08, 2 * hhr + 0.09), M["ring"], "hard", what="cadre")
    g.box((x, ym - 0.02, z), (2 * ow, 0.03, 2 * hhr + 0.06), M["jacket"], "hard", what="fond_cadre")
    g.box((x, ym + 0.042, z), (2 * (sep - hwr), 0.006, hhr * 1.4), E, "flat", what="bouche_lum")
    return ym + 0.05


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisse (volume de la lignée) noire et sombre, CELLULES CRYOGÉNIQUES cylindriques
    couchées à chapeaux chromés et givre, tuyau cryogénique, voyants."""
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
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=[M["jacket"], M["steel_dk"]],
            rivet_step=0.11)
    ztop = zb1 + 0.015
    g.hazard(PT.lift([V((bx0, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.2, zb1)),
                      V((bx0, yb0 + bl * 0.2, zb1))], 0.012), 4, t=0.01)
    for k, yy in enumerate((yb0 + bl * 0.32, yb0 + bl * 0.68)):
        c = V((bc, yy, ztop + 0.07))
        g.cyl(c, "x", 0.07, bw * 0.9, M["jacket"], n=20, what="cellule")
        for s in (-1, 1):
            g.cyl(c + V((s * bw * 0.45, 0, 0)), "x", 0.075, 0.03, M["ring"], n=20, what="chapeau")
        g.tube_shell(c, "x", 0.078, 0.06, 0.03, M["trim"], n=20, what="givre")
        g.box(c + V((0, -0.05, 0.05)), (0.05, 0.02, 0.006), E, "flat", what="voyant")
    g.tube([V((bc, yb0 + bl * 0.5, ztop + 0.08)), V((x + sx * wr * 0.35, yb0 + bl * 0.6, zg + hr + 0.07)),
            V((x + sx * wr * 0.2, y1 - 0.12, zg + hr + 0.04))], 0.026, M["pipe"], n=10, what="cryo")
    P3.lamp_group(g, (bc + sx * bw * 0.3, yb0 + bl * 0.08, ztop - 0.005), (0, 1, 0), (0, 0, 1),
                  E, M, n=2, shapes=("rond", "carre", "fente"))
    return bc


def dome_gun(g, H, nb, L, s=1.0):
    """Canon de coupole sur berceau blindé (lignée _tete15), arme de l'époque (petit canon à rails à caisson plein)."""
    M = g.M
    zr = H["zs"] + H["rz"] * 0.92
    zc = zr + 0.3 * s
    PT.hull(g, -0.38 * s, 0.38 * s, -0.22 * s, 0.66 * s, zr - 0.04, zr + 0.2 * s, ins=(0.04, 0.04, 0.1),
            panel=0.22, mats=[M["olive"], M["ochre"]], rivet_step=0.11)
    PT.receiver(g, 0.0, -0.22 * s, 0.66 * s, zc - 0.18 * s, zc + 0.16 * s, 0.36 * s, mats=[M[k] for k in RECV])
    rb, rr = 0.052 * s, 0.125 * s * (1.0 if nb == 6 else 0.85)
    _gun12(g, 0.0, 0.66 * s, zc, L, nb, rb, rr)
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
    F.slits_grouped(g, R, z0 + 0.2, 9, M["emit"])
    for sx in (-1, 1):
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, H["zs"] + 0.25), (sx * R * 0.62, -R * 0.42, H["zs"] + H["rz"] * 0.55),
              (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
    # plaques rapportées : 1re rangée, puis 2e rangée (catalogue §A.5)
    row1 = (0.5, 0.95, 1.4, math.pi - 0.5, math.pi - 0.95, math.pi - 1.4)
    ph1, w1, h1 = (0.32, 0.28, 0.22)
    for i, th in enumerate(row1):
        mat = M["jacket"] if i % 2 else M["steel_dk"]
        P2.applique(g, c.Pf, c.Nf, th, ph1, w1, h1, mat, M)
    for th in (0.75, math.pi - 0.75, 1.57):
        P2.applique(g, c.Pf, c.Nf, th, 0.75, 0.26, 0.22, M["jacket"], M)
    dome_gun(g, H, 4, 1.02, 0.85)
    # sommet de la tête : 2 DEWARS cryogéniques debout sur la nacelle, cols chromés, givre
    bx, yb0, yb1 = c.nac[:3]
    znac = H["zs"] + H["rz"] * 0.42
    for s in (-1, 1):
        x = s * bx * 0.55
        y = (yb0 + yb1) / 2 - 0.05
        g.cyl((x, y, znac + 0.22), "z", 0.13, 0.44, M["jacket"], n=24, what="dewar")
        for zz in (0.08, 0.3):
            g.tube_shell((x, y, znac + zz), "z", 0.15, 0.12, 0.04, M["ring"], n=24, what="collier")
        g.cyl((x, y, znac + 0.48), "z", 0.06, 0.08, M["ring"], n=16, what="col")
        g.tube_shell((x, y, znac + 0.445), "z", 0.075, 0.06, 0.02, M["trim"], n=16, what="givre")
        g.box((x, y - 0.135, znac + 0.25), (0.05, 0.006, 0.02), E, "flat", what="voyant")
    PT.sight(g, (-R * 0.6, R * 0.32, H["zs"] + H["rz"] * 0.5), 0.2, 0.2, 0.12, M["emit"], lenses=2)
