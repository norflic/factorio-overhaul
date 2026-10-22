"""Époque 10 · Haute technologie (ère IV, 5×5, niveaux 19 et 20). Constructeur : PLAGE HAUTE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 10) : « caréné, câbles, voyants ».
PORTÉ TEL QUEL de la passe 3 (gun_e_haut, commit 4c57982 : design.py, armes.py, ages.py ; outil de portage, code d'origine mot pour
mot ; les aiguillages par époque sont réduits à la branche de l'époque 10) sur le kit commun gun_e : seul le CORPS a
changé (corps.py : bras de tourillon à berceaux de la lignée, cotes communes ; kit.py : palette et règles de reflets
communes). Aucune correction de design d'époque.
Emplacements remplis : arme (NACELLE CARÉNÉE FERMÉE gris clair, 3 déflecteurs, radôme, capteur optique, chargeurs à
cassettes et nappes de câbles), grands volumes du socle (caissons carénés à l'ouest, à l'est et au nord-ouest), tourelle
secondaire, liaisons (gaines lisses à colliers et faisceaux rouges et bleus), antenne-réseau radar au sommet, écrans,
foyers bleus, pièce paire (2 radômes de conduite de tir).
Défauts relevés par les juges (à corriger par le constructeur) : la nacelle fermée SUPPRIME la rosette de tubes que
le Directeur Créatif aimait (RÈGLE D'OR 1) ; foyers mesurés cyan (197°, famille « bleu électronique » 204 à 228°).
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

EPOQUE = 10
NOM = "Haute technologie"
FOYER = dict(rgb=(0.227, 0.659, 1.0), rgb2=(0.227, 0.659, 1.0))
CANON = dict(L=2.0, nb=6, rb=0.06, rr=0.145)
PLATEFORME = dict(chanfrein=1.15)
HABILLAGE = dict(jupe_cerclage="ring", chapeau="ring")
RECV = ("matte", "jacket")


def matieres(metal, M):
    """Haute technologie : carénage gris clair patiné, noir mat, câbles rouges et bleus, écrans."""
    rust = (0.24, 0.085, 0.03)
    metal("jacket", (0.4, 0.4, 0.39), rough=0.42, met=0.3, grain=0.1, gscale=30.0, rust=rust, ra=0.08,
          dirt=0.9, stain=0.7, sscale=6.0, wear=1.2, streak=0.5, mottle=0.3)
    M["ring"] = M["matte"]
    M["trim"] = M["jacket"]
    metal("pipe", (0.11, 0.108, 0.104), rough=0.5, met=0.2, grain=0.1, dirt=0.6, stain=0.4, wear=1.0)
    M["pipe2"] = M["steel_hi"]
    M["cable_a"] = M["redcable"]
    metal("cable_b", (0.02, 0.06, 0.2), rough=0.5, met=0.0, grain=0.12, dirt=0.4, stain=0.0)
    metal("spec", (0.012, 0.03, 0.05), rough=0.15, met=0.3, grain=0.05, dirt=0.2, stain=0.0)       # écrans
    M["accent"] = M["trim"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 21 de l'industriel ; 10 : sans la paire de caisses du nord)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    # foyers de la colonne : fentes groupées (jamais de rangée continue)
    ng = 4
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, ng, M["emit"], a0=math.pi + 0.2, span=math.pi - 0.4)
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, ng - 1, M["emit"], a0=math.pi + 0.35, span=math.pi - 0.7,
                    per=(3, 2))
    P2.grating(g, 1.35, 1.75, Y(-1.15), Y(1.3), 0.07, M)
    P2.grating(g, -1.55, -1.3, Y(-1.0), Y(-0.3), 0.07, M)
    # sud : caisses ouvertes en biais, tourelle secondaire
    with at(g, -1.5, -1.72, 0.42):
        P2.open_crate(g, (0, 0, 0), 0.78, 0.72, 0.3, M)
    with at(g, -1.05, -2.35, 0.08):
        P2.open_crate(g, (0, 0, 0), 0.6, 0.5, 0.22, M, paint=M["ochre"])
    for (x, yn, rz) in [(1.78, -1.82, 0.0)]:
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.42, 0.0, 0.28, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            mini_turret(g, (0, 0, 0.28), 0.95, rz)
    # ouest : groupe sous carénage ; liaisons d'énergie vers la colonne
    west(g)
    conduit(g, [(-1.62, Y(0.55), 0.4), (-1.42, Y(0.6), 0.62), (-1.2, Y(0.5), 0.72)], 0.045)
    cables(g, [(-1.62, Y(-0.25), 0.4), (-1.42, Y(-0.3), 0.6), (-1.18, Y(-0.35), 0.68)])
    # nord-ouest : caisson caréné posé en biais
    with at(g, -1.72, 2.02, -0.55):
        faired_box(g, -0.42, 0.42, -0.32, 0.32, 0.4, louvers=1, cables=False)
    # est : caisson caréné (à la place des réservoirs)
    faired_box(g, 1.74, 2.36, Y(-0.6), Y(1.15), 0.74, louvers=0)
    # sud-ouest : armoire de commande
    P3.cabinet(g, -2.45, -2.02, -2.3, -1.66, 0.0, 0.5, M, E, screen_=True)
    PT.hull(g, 1.68, 2.36, Y(-1.18), Y(-0.85), 0.0, 0.3, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["redpaint"], M["steel_dk"]], rivet_step=0.12)
    P2.handwheel(g, (2.02, Y(-1.18) - 0.08, 0.2), (0, -1, 0.3), 0.08, M)
    pipe(g, [(1.68, Y(-1.0), 0.2), (1.45, Y(-1.05), 0.22), (1.25, Y(-0.85), 0.4)], 0.05,
         valve_at=((1.47, Y(-1.04), 0.22), (0, -1, 0.5)))
    hose(g, [(1.7, Y(1.05), 0.62), (1.45, Y(0.95), 0.98), (1.15, Y(0.75), 0.82)], 0.06)
    # nord-est : armoire de commande ; nord : caisse de réserve
    P3.cabinet(g, 1.25, 2.25, Y(1.95), Y(2.42), 0.0, 0.56, M, E, screen_=True)
    signature(g, (1.55, Y(2.18), 0.6))
    PT.crate(g, (0.4, Y(1.95), 0.0), (0.66, 0.6, 0.28), mat=M["ochre"])
    signature(g, (0.4, Y(1.95), 0.3), 1)
    signature(g, (-2.24, -1.98, 0.53), 2)
    for x in (-0.68, 0.68):
        PT.lamp(g, (x, Y(-2.4) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    _halo(g, [(-2.0, Y(-1.1), 0.5), (1.78, Y(-2.1), 0.6), (0.0, Y(-2.5), 0.5), (2.0, Y(0.3), 0.5),
              (1.75, Y(1.8), 0.5)], 20.0)


def west(g):
    """Groupe de l'ouest : caisson caréné (même emprise que le groupe électrogène de la lignée), antenne-fouet."""
    M = g.M
    x0, x1, y0, y1, h = -2.42, -1.62, Y(-0.95), Y(1.25), 0.52
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    faired_box(g, x0 + 0.02, x1 - 0.02, y0, y1, h + 0.08, louvers=1, cables=False)
    # antenne-fouet et boîtier sur le toit (fine, hors masse)
    g.box((cx - 0.15, y1 - 0.3, h + 0.13), (0.14, 0.12, 0.08), M["matte"], "hard", what="boitier")
    g.cyl((cx - 0.15, y1 - 0.3, h + 0.4), "z", 0.006, 0.46, M["steel_dk"], n=6, what="antenne")


def faired_box(g, x0, x1, y0, y1, h, louvers=3, cables=True):
    M = g.M
    E = M["emit"]
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2, (y1 - y0) / 2
    c = min(hx, hy) * 0.3
    F.plinth(g, x0 - 0.04, x1 + 0.04, y0 - 0.04, y1 + 0.04, 0.08)
    F.loft_z(g, cx, cy, [(0.08, F.octz(hx, hy, c)), (h * 0.72, F.octz(hx, hy, c)), (h, F.octz(hx - 0.1, hy - 0.1, c))],
           M["jacket"], "soft", "carenage")
    # joints de panneaux verticaux (noir mat) sur les faces sud et ouest/est
    nseg = max(2, int((y1 - y0) / 0.55))
    for i in range(1, nseg):
        yy = y0 + (y1 - y0) * i / nseg
        for s in (-1, 1):
            g.box((cx + s * (hx + 0.002), yy, h * 0.4), (0.01, 0.02, h * 0.6), M["matte"], "flat", what="joint")
        g.box((cx, yy, h + 0.003), (2 * (hx - 0.12), 0.02, 0.008), M["matte"], "flat", what="joint")
    # grilles d'aération sur le toit (cadre noir, lames)
    for i in range(louvers):
        yy = y0 + (y1 - y0) * (i + 0.5) / louvers
        q = [V((cx - hx * 0.5, yy - 0.12, h + 0.004)), V((cx + hx * 0.2, yy - 0.12, h + 0.004)),
             V((cx + hx * 0.2, yy + 0.12, h + 0.004)), V((cx - hx * 0.5, yy + 0.12, h + 0.004))]
        g.grille(q, 6, depth=0.02, slat_mat=M["steel_dk"])
        for (u, v) in ((-0.5, -0.12), (0.2, -0.12), (0.2, 0.12), (-0.5, 0.12)):
            g.dome((cx + hx * u, yy + v * 1.15, h + 0.01), (0, 0, 1), 0.012, M["rivet"])
    # nappes de câbles rouges et bleus dans une goulotte sur le toit, côté est
    if cables:
        g.box((cx + hx * 0.55, cy, h + 0.02), (0.14, 2 * hy * 0.92, 0.03), M["matte"], "hard", what="goulotte")
        F.ribbon(g, [(cx + hx * 0.52, y0 + 0.1, h + 0.04), (cx + hx * 0.52, y1 - 0.1, h + 0.04)], 0.05, M["cable_a"])
        F.ribbon(g, [(cx + hx * 0.6, y0 + 0.1, h + 0.041), (cx + hx * 0.6, y1 - 0.1, h + 0.041)], 0.04, M["cable_b"])
    # voyants par groupes, petit écran, face sud
    P3.lamp_group(g, (cx - hx * 0.6, y0 - 0.005, h * 0.55), (1, 0, 0), (0, -1, 0), E, M, n=3)
    P3.screen(g, (cx + hx * 0.35, y0 - 0.005, h * 0.5), (0, -1, 0), 0.14, 0.08, M, E)
    return (cx, cy, h)


def radar_array(g, c, w, hgt, tilt=0.4):
    """Antenne-réseau de radar sur mât (cadre, lattes, treillis arrière), tournée vers l'avant (+y)."""
    M = g.M
    E = M["emit"]
    g.cyl(V(c) + V((0, 0, 0.1)), "z", 0.06, 0.2, M["matte"], n=16, what="mat")
    g.cyl(V(c) + V((0, 0, 0.02)), "z", 0.12, 0.05, M["steel_dk"], n=24, what="pivot")
    g.push(V(c) + V((0, 0, 0.2 + hgt / 2)), rx=tilt)
    g.box((0, 0, 0), (w, 0.05, hgt), M["jacket"], "hard", what="reseau")
    g.box((0, -0.035, 0), (w + 0.04, 0.02, hgt + 0.04), M["matte"], "hard", what="cadre")
    n = int(w / 0.09)
    for i in range(n):
        xx = -w / 2 + w * (i + 0.5) / n
        g.box((xx, 0.03, 0), (0.016, 0.02, hgt * 0.92), M["steel_dk"], "hard", what="latte")
    for zz in (-hgt * 0.3, hgt * 0.3):
        g.box((0, -0.06, zz), (w * 0.9, 0.03, 0.03), M["steel_dk"], "hard", what="treillis")
    g.box((-w * 0.4, 0.045, hgt * 0.38), (0.03, 0.006, 0.02), E, "flat", what="voyant")
    g.box((w * 0.33, 0.045, -hgt * 0.38), (0.03, 0.006, 0.02), E, "flat", what="voyant")
    g.pop()


def signature(g, p, kind=0):
    """Petite pièce de signature posée sur un toit de machine : antenne fouet courte sur embase, boîtier."""
    M = g.M
    p = V(p)
    g.box(p + V((0, 0, 0.03)), (0.12, 0.1, 0.06), M["matte"], "hard", what="boitier")
    g.cyl(p + V((-0.04, 0.03, 0.07)), "z", 0.018, 0.04, M["steel_hi"], n=8, what="embase")
    g.cyl(p + V((-0.04, 0.03, 0.18)), "z", 0.006, 0.2, M["steel_dk"], n=6, what="antenne")
    g.cyl(p + V((-0.03, 0, 0.065)), "z", 0.012, 0.012, M["emit"], n=8, style="flat", what="voyant")


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
        _gun10(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
    PT.lamp(g, (0.0, 0.12 * s, 0.4 * s + 0.01), (0, 0.35, 1), 0.035, E, cage=False)
    PT.hatch(g, (0.0, -0.12 * s, 0.4 * s), 0.09 * s)
    g.pop()


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : gaines lisses à colliers, faisceaux de câbles rouges et bleus, conduits à bagues lumineuses
# ------------------------------------------------------------------------------------------------
def hose(g, ctrl, r):
    """Gaine lisse à colliers clairs, faisceau de câbles rouge et bleu posé dessus."""
    M = g.M
    P, T = g.tube(g.spline(ctrl, 10), r * 0.85, M["pipe"], n=12, what="gaine")
    for i in range(2, len(P) - 1, 5):
        g.cyl(P[i], T[i], r * 0.85 + 0.014, 0.03, M["steel_hi"], n=12, style="hard", what="collier")
    PT.cable_run(g, [V(p) + V((0, 0, r + 0.03)) for p in ctrl], 2, 0.016, 0.04, [M["cable_a"], M["cable_b"]])


def cables(g, ctrl, n=3):
    """Faisceau de 4 câbles rouges et bleus."""
    M = g.M
    mats = [M["cable_a"], M["cable_b"], M["cable_a"], M["cable_b"]]
    PT.cable_run(g, ctrl, 4, 0.026, 0.055, mats)


def conduit(g, ctrl, r):
    """Conduit d'énergie : bagues lumineuses PAR GROUPES (chenillard), colliers en matière d'époque."""
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
    g.pipe(ctrl, r, M["pipe"], fl_mat=M["pipe2"], bolt_mat=M["rivet"])
    if valve_at is not None:
        p, ax = valve_at
        g.box(p, (r * 3.2, r * 3.2, r * 3.2), M["steel_dk"], "hard", what="corps_vanne")
        P2.handwheel(g, V(p) + V(ax).normalized() * (r * 1.6 + 0.06), ax, 0.07, M)


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 20 : 2 radômes de conduite de tir sur affût blindé
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.5, Y(-2.64), sx)
    _halo(g, [(-1.5, Y(-2.9), 0.4), (1.5, Y(-2.9), 0.4)], 16.0)


def even_piece(g, x, yb, sx):
    """Une des deux pièces paires, posée en (x, yb Blender) au sol, côté sx : RADÔME de conduite de tir sur affût
    blindé (embase à armoire), antenne courte."""
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


# ------------------------------------------------------------------------------------------------
# Arme (E1) : nacelle carénée fermée
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse, moteur arrière, arme d'époque, masque de canon,
    capteur optique, alimentation, voyants d'état, capot de culasse."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _gun10(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    # capteur optique sur le masque de canon
    cc = V((x + wr * 0.45, y1 + 0.02, zg + hr * 1.35 + 0.06))
    g.box(cc, (0.12, 0.12, 0.1), M["matte"], "hard", what="capteur")
    g.cyl(cc + V((0, 0.07, 0.0)), "y", 0.035, 0.03, M["steel_hi"], n=14, what="capteur_bague")
    g.cyl(cc + V((0, 0.088, 0.0)), "y", 0.025, 0.006, M["emit"], n=12, style="flat", what="lentille")
    g.box(cc + V((0, -0.02, 0.06)), (0.08, 0.06, 0.02), M["jacket"], "hard", what="visiere")
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    # voyants d'état sur la culasse : 2 segments courts (pas de bande continue)
    for f in (0.28, 0.5):
        g.box((x - sx * wr * 0.22, y0 + (y1 - y0) * f, zg + hr + 0.012), (0.03, (y1 - y0) * 0.12, 0.012), M["emit"],
              "flat", what="etat")
    # capot noir mat à petit écran et nappe de câbles
    zt = zg + hr + 0.012
    g.box((x, (y0 + y1) / 2 + 0.05, zt + 0.03), (wr * 0.6, (y1 - y0) * 0.36, 0.04), M["matte"], "hard", what="capot")
    P3.screen(g, (x, (y0 + y1) / 2 + 0.05, zt + 0.052), (0, 0, 1), wr * 0.4, 0.07, M, M["emit"])


def _gun10(g, x, y0, z, L, nb, rb, rr):
    """Troisième passe (19 h 05) : le canon n'est plus un faisceau habillé d'un manchon, c'est un CAISSON LISSE
    FERMÉ gris clair (carénage à pans coupés, nez effilé) d'où ne sortent que les 6 bouches. De dessus : un gros
    pavé clair à fentes sombres, sans bague ; de face : un écran plat à 6 trous et 3 déflecteurs."""
    M = g.M
    E = M["emit"]
    k = F.k_arme(rb, rr)
    R0 = rr + rb
    hw, hh, c = R0 + 0.13 * k, R0 + 0.06 * k, 0.12 * k
    Lf = 0.84 * L
    sec = F.oct8(hw, hh, c)
    F.loft(g, x, z, [(y0 - 0.02, F.scale_poly(sec, 0.92)), (y0 + 0.08 * k, sec), (y0 + Lf - 0.3 * k, sec),
                   (y0 + Lf, F.scale_poly(sec, 0.74))], M["jacket"], "soft", "carenage")
    # joints de panneaux (3 panneaux), fentes de ventilation longitudinales, rivets fins
    for f in (0.3, 0.58):
        yy = y0 + f * Lf
        F.prism_y(g, x, z, yy - 0.012, yy + 0.012, F.scale_poly(sec, 1.02), M["matte"], what="joint")
    for i, (a, b) in enumerate(((0.06, 0.27), (0.33, 0.55), (0.61, 0.8))):
        ya, yb = y0 + a * Lf, y0 + b * Lf
        ym, ly = (ya + yb) / 2, yb - ya
        for u in ((-hw * 0.45, hw * 0.45) if i != 1 else (-hw * 0.45, 0.0, hw * 0.45)):
            g.box((x + u, ym, z + hh + 0.002), (0.03 * k, ly, 0.006), M["void"], "flat", what="fente")
            g.box((x + u + 0.024 * k, ym, z + hh + 0.006), (0.01, ly, 0.01), M["steel_hi"], "hard", what="levre")
        for s in (-1, 1):
            g.box((x + s * (hw + 0.002), ym, z), (0.006, ly, 0.03 * k), M["void"], "flat", what="fente")
        for yy in (ya - 0.02, yb + 0.02):
            for u in (-hw + c + 0.03, hw - c - 0.03):
                g.dome((x + u, yy, z + hh), (0, 0, 1), 0.012, M["rivet"])
    # dos : nappe de câbles rouges et bleus dans une goulotte noire, antenne fouet et radôme de visée
    g.box((x, y0 + Lf * 0.4, z + hh + 0.025), (0.12 * k, Lf * 0.62, 0.035), M["matte"], "hard", what="goulotte")
    g.box((x - 0.025 * k, y0 + Lf * 0.41, z + hh + 0.046), (0.04 * k, Lf * 0.58, 0.01), M["cable_a"], "soft",
          what="nappe")
    g.box((x + 0.03 * k, y0 + Lf * 0.41, z + hh + 0.047), (0.035 * k, Lf * 0.58, 0.01), M["cable_b"], "soft",
          what="nappe")
    yr = y0 + Lf * 0.82
    g.cyl((x, yr, z + hh + 0.03), "z", 0.1 * k, 0.05, M["matte"], n=20, what="embase")
    g.sphere((x, yr, z + hh + 0.07), 0.11 * k, M["jacket"], n=24, m=12, scale=(1, 1, 0.8), what="radome")
    g.torus((x, yr, z + hh + 0.07), "z", 0.11 * k, 0.01, M["matte"], n=24, m=6, what="joint")
    g.cyl((x + 0.12 * k, y0 + Lf * 0.2, z + hh + 0.2), "z", 0.006, 0.36, M["steel_dk"], n=6, what="antenne")
    g.cyl((x + 0.12 * k, y0 + Lf * 0.2, z + hh + 0.025), "z", 0.02, 0.04, M["steel_hi"], n=8, what="embase")
    # face avant plate du carénage : bouches, voyants par 2
    yf = y0 + Lf
    F.stub_tips(g, x, yf - 0.05, y0 + L, z, nb, rb, rr)
    F.collar(g, x, yf + (y0 + L - yf) * 0.5, z, R0 + 0.02, rr * 0.3, 0.045, M["matte"])
    for s in (-1, 1):
        g.box((x + s * hw * 0.55, yf + 0.004, z + hh * 0.45), (0.04, 0.008, 0.025), E, "flat", what="voyant")
    # frein à 3 DÉFLECTEURS plus large que la nacelle
    yb = y0 + L + 0.14 * k
    g.cyl((x, yb, z), "y", rr * 0.95, 0.28 * k, M["matte"], n=20, what="frein_noyau")
    for i, dy in enumerate((-0.1, 0.0, 0.1)):
        g.box((x, yb + dy * k, z), (2 * hw + 0.1 * k - 0.06 * i * k, 0.045 * k, 2 * hh * 0.8), M["jacket"], "hard",
              what="deflecteur")
    g.box((x, yb, z + hh * 0.8), (hw * 0.7, 0.26 * k, 0.024), M["matte"], "hard", what="longeron")
    F.muzzle_glow(g, x, yb + 0.145 * k, z, rr * 0.62)
    return yb + 0.145 * k


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisse (volume de la lignée) noir mat et gris, chargeurs à CASSETTES rectangulaires et
    NAPPES de câbles rouges et bleues, voyants."""
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
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=[M["matte"], M["jacket"]],
            rivet_step=0.11)
    ztop = zb1 + 0.015
    g.hazard(PT.lift([V((bx0, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.2, zb1)),
                      V((bx0, yb0 + bl * 0.2, zb1))], 0.012), 4, t=0.01)
    for k in range(3):
        yy = yb0 + bl * (0.3 + 0.2 * k)
        g.box((bc, yy, ztop + 0.05), (bw * 0.8, bl * 0.15, 0.1), M["jacket"], "hard", what="cassette")
        g.box((bc + sx * bw * 0.28, yy, ztop + 0.102), (0.05, bl * 0.08, 0.006), E if k != 1 else M["amber"],
              "flat", what="voyant")
        g.box((bc - sx * bw * 0.1, yy, ztop + 0.101), (bw * 0.3, bl * 0.1, 0.004), M["matte"], "flat",
              what="etiquette")
    F.ribbon(g, [(bc - sx * 0.04, yb0 + bl * 0.85, ztop + 0.09), (bc - sx * 0.1, y0 + bl * 0.75, zg + bh * 0.7),
                 (x + sx * wr * 0.25, y0 + bl * 0.62, zg + hr + 0.05)], 0.06, M["cable_a"])
    F.ribbon(g, [(bc + sx * 0.02, yb0 + bl * 0.85, ztop + 0.1), (bc - sx * 0.04, y0 + bl * 0.8, zg + bh * 0.75),
                 (x + sx * wr * 0.32, y0 + bl * 0.68, zg + hr + 0.06)], 0.05, M["cable_b"])
    P3.lamp_group(g, (bc + sx * bw * 0.3, yb0 + bl * 0.08, ztop - 0.005), (0, 1, 0), (0, 0, 1),
                  E, M, n=2, shapes=("rond", "carre", "fente"))
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
    F.slits_grouped(g, R, z0 + 0.2, 4, M["emit"])
    for sx in (-1, 1):
        # liaisons nacelle -> bras de tourillon : elles passent SUR la coupole et finissent SUR le bras
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, H["zs"] + 0.25), (sx * R * 0.62, -R * 0.42, H["zs"] + H["rz"] * 0.55),
              (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
    # plaques rapportées (blindage) : 1re rangée qui se complète (catalogue §A.5)
    row1 = (0.6, 1.2, math.pi - 0.6, math.pi - 1.2)
    ph1, w1, h1 = (0.32, 0.28, 0.22)
    for i, th in enumerate(row1):
        mat = M["trim"] if i % 3 == 1 else (M["ochre"] if i % 2 else M["steel_dk"])
        P2.applique(g, c.Pf, c.Nf, th, ph1, w1, h1, mat, M)
    # radôme de visée sur le tourelleau, antennes fouet courtes, petit écran sur la nacelle
    for (ax, ay) in ((-0.5, -0.3), (0.55, -0.55)):
        g.cyl((ax * R, ay * R, H["zs"] + H["rz"] * 0.65), "z", 0.02, 0.05, M["steel_hi"], n=8, what="embase")
        g.cyl((ax * R, ay * R, H["zs"] + H["rz"] * 0.65 + 0.2), "z", 0.006, 0.36, M["steel_dk"], n=6,
              what="antenne")
    bx, yb0, yb1 = c.nac[:3]
    P3.screen(g, (bx * 0.5, (yb0 + yb1) / 2, H["zs"] + H["rz"] * 0.42 + 0.03), (0, 0, 1), 0.14, 0.09, M, M["emit"])
    P3.lamp_group(g, (-bx * 0.6, (yb0 + yb1) / 2 - 0.05, H["zs"] + H["rz"] * 0.42 + 0.005), (1, 0, 0), (0, 0, 1),
                  M["emit"], M, n=3)
    # sommet de la tête : antenne-réseau de radar sur le tourelleau
    radar_array(g, c.tour, 1.25, 0.46, tilt=0.95)
    PT.sight(g, (-R * 0.6, R * 0.32, H["zs"] + H["rz"] * 0.5), 0.2, 0.2, 0.12, M["emit"], lenses=2)
