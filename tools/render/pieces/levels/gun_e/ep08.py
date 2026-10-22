"""Époque 8 · Marais (ère III, 4×4, niveaux 15 et 16). Constructeur : PLAGE BASSE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 8) : « verre, bulles, toxique ».
PORTÉ TEL QUEL de la passe 3 (gun_e_bas, commit 4c57982 : design.py, ages.py, parts4.py ; outil de portage, code d'origine mot pour
mot) sur le kit commun gun_e : seul le CORPS a changé (corps.py, kit.py). Aucune correction de design d'époque.
Emplacements remplis : arme (gatling de vert-de-gris à buse en cloche portant une CUVE DE VERRE couchée, manchon à
fenêtres de liquide, boîte d'alimentation à tuyaux souples), mitrailleuse coaxiale, grands volumes du socle (cuves de
verre, globe, bonbonnes clissées, bocaux), liaisons (caoutchouc annelé à tronçon de verre), nacelle (bulbe de verre
dorsal relié aux canons), lanterneau de verre sur la coupole, foyers vert-jaune, pièce paire (2 bonbonnes de verre).
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

EPOQUE = 8
NOM = "Marais"
KIN = 1   # rang dans l'ère III
FOYER = dict(rgb=(0.659, 1.0, 0.227), doux=dict(force=0.45, base=(0.05, 0.085, 0.022)))
CANON = dict(L=1.7, nb=6, rb=0.052, rr=0.128)
HABILLAGE = dict(jupe_cerclage="rubber", tremie="olive", pochoirs=True, munitions=("verdigris", "emit_soft"),
                 chapeau="brass")
ST = dict(jacket="marsh", brake="nozzle", drive="motor", drive_mat="verdigris", fin_mat="steel_dk",
          band="verdigris", recv_mats=("verdigris", "olive"), feed="hoses", skirt="rubber", appl="verdigris",
          gmask=("olive", "verdigris"), arm=("olive", "steel_dk"), cap="brass", col=("olive", "verdigris"),
          nac=("olive", "verdigris"), coax=True)


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle : cuves de verre, globe, bonbonnes clissées, bocaux
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    F.lamp_group(g, (x0 + 0.07, y0 - 0.03, h * 0.62), (1, 0, 0), (0, -1, 0), M["emit"], n=3)
    socle_marsh(g, KIN)
    corps.collecteur(g, c, lambda g_, pts, r: link(g_, EPOQUE, pts, r))


def glass_vat(g, x, y, r, h, M, E):
    """Cuve de verre debout : embase de vert-de-gris boulonnée, liquide visible entre 8 côtes, cerclages laiton,
    dôme de verre et couronne, bulles. Chaque panneau de liquide est un foyer de moins de 0,05 t²."""
    g.cyl((x, y, 0.05), "z", r + 0.06, 0.1, M["verdigris"], n=24, style="soft", what="embase")
    F.bolts_ring(g, (x, y, 0.1), (0, 0, 1), r + 0.035, 12, M["brass"], r=0.014)
    zb, zt = 0.1, h
    g.cyl((x, y, (zb + zt) / 2), "z", r - 0.012, zt - zb, M["emit_soft"], n=32, what="liquide")
    nrib = 10
    for kk in range(nrib):
        a = TAU * (kk + 0.5) / nrib
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((x, y, (zb + zt) / 2)) + d * (r - 0.004), (0.035, 0.03, zt - zb), M["verdigris"], "hard",
              R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="cote")
    for f in (0.04, 0.5, 0.96):
        g.tube_shell((x, y, zb + (zt - zb) * f), "z", r + 0.02, r - 0.02, 0.04, M["brass"], n=32, what="cerclage")
    for i in range(14):
        a = -math.pi / 2 + 1.6 * ((i * 7) % 14 / 13.0 - 0.5)
        g.dome((x + math.cos(a) * r * 0.99, y + math.sin(a) * r * 0.99, zb + (zt - zb) * (0.12 + 0.055 * i)),
               (math.cos(a), math.sin(a), 0), 0.018, E, what="bulle")
    F.sphere(g, (x, y, zt), r * 0.86, M["glass"], n=24, m=12, sz=0.55, what="dome_verre")
    g.tube_shell((x, y, zt + 0.005), "z", r + 0.01, r * 0.8, 0.03, M["verdigris"], n=28, what="couronne")
    for kk in range(4):
        a = TAU * kk / 4 + 0.4
        g.box((x + math.cos(a) * r * 0.45, y + math.sin(a) * r * 0.45, zt + r * 0.3), (0.025, 0.025, r * 0.55),
              M["verdigris"], "hard", R=Matrix.Rotation(0.0, 3, "Z"), what="arceau")
    g.cyl((x, y, zt + r * 0.5), "z", 0.05, 0.06, M["brass"], n=12, what="col")
    P2.gauge(g, (x, y - r - 0.03, zb + (zt - zb) * 0.25), (0, -1, 0.3), 0.045, M)


def wicker(g, c, r, M):
    x, y, z = c
    g.cyl((x, y, z + r * 0.9), "z", r, r * 1.8, M["wicker"], n=16, r2=r * 0.85, what="panier")
    for f in (0.2, 0.5, 0.8):
        g.tube_shell((x, y, z + r * 1.8 * f), "z", r * (1.0 - 0.15 * f) + 0.008, r * 0.8, 0.014, M["wood2"], n=16,
                     what="cercle")
    g.cyl((x, y, z + r * 1.8 + 0.05), "z", r * 0.35, 0.1, M["emit_soft"], n=12, r2=r * 0.25, what="col")
    g.cyl((x, y, z + r * 1.8 + 0.11), "z", r * 0.28, 0.025, M["rubber"], n=10, what="bouchon")


def socle_marsh(g, k):
    M = g.M
    E = M["emit"]
    glass_vat(g, 1.5, Y(0.55), 0.3, 0.82, M, E)
    glass_vat(g, 1.5, Y(-0.45), 0.27, 0.7, M, E)
    # nord-ouest : grand globe de verre en cage, sur pompe
    x, y = -1.42, Y(1.28)
    PT.hull(g, x - 0.34, x + 0.34, y - 0.3, y + 0.3, 0.0, 0.16, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["verdigris"], M["olive"]], rivet_step=0.1)
    rG = 0.33
    zc = 0.16 + rG * 0.95
    F.sphere(g, (x, y, zc), rG, M["emit_soft"], n=28, m=14, what="globe")
    for kk in range(8):
        a = TAU * kk / 8
        g.box((x + math.cos(a) * (rG + 0.012), y + math.sin(a) * (rG + 0.012), zc), (0.03, 0.03, rG * 1.9),
              M["verdigris"], "hard", what="cage")
    g.torus((x, y, zc), "z", rG + 0.01, 0.022, M["brass"], n=32, m=6, what="ceinture")
    g.cyl((x, y, zc + rG + 0.03), "z", 0.07, 0.07, M["brass"], n=14, what="col")
    # ouest : station de pompage (2 corps de pompe, bonbonnes clissées)
    PT.hull(g, -1.92, -1.3, Y(-0.7), Y(0.55), 0.0, 0.36, ins=(0.03, 0.03, 0.03), panel=0.24,
            mats=[M["verdigris"], M["olive"]], rivet_step=0.12)
    for yn in (-0.35, 0.25):
        g.cyl((-1.61, Y(yn), 0.5), "z", 0.1, 0.28, M["olive"], n=18, what="pompe")
        g.cyl((-1.61, Y(yn), 0.66), "z", 0.07, 0.04, M["brass"], n=14, what="chapeau")
        P2.gauge(g, (-1.61, Y(yn) - 0.1, 0.52), (0, -1, 0.3), 0.04, M)
    for (xx, yn) in ((-1.25, -0.95), (-1.05, -1.0)):
        wicker(g, (xx, Y(yn), 0.0), 0.11, M)
    for yn in (-0.6, -0.05, 0.45):
        P2.handwheel(g, (-1.36, Y(yn), 0.42), (1, 0, 0.3), 0.05, M, mat=M["brass"])
        P2.gauge(g, (-1.8, Y(yn), 0.38), (0, 0, 1), 0.04, M)
    # gros conduits de caoutchouc annelé (pompes -> globe, cuves -> colonne), tronçons de verre lumineux
    g.hose([(-1.61, Y(0.25), 0.62), (-1.6, Y(0.8), 0.7), (-1.45, Y(1.05), 0.4)], 0.05, M["rubber"], step=0.035)
    link(g, 8, [(1.2, Y(0.55), 0.4), (1.05, Y(0.5), 0.65), (0.86, Y(0.4), 0.78)], 0.07)
    link(g, 8, [(1.22, Y(-0.45), 0.35), (1.05, Y(-0.4), 0.6), (0.9, Y(-0.3), 0.72)], 0.07)
    link(g, 8, [(-1.3, Y(0.1), 0.3), (-1.15, Y(0.1), 0.6), (-0.96, Y(0.06), 0.74)], 0.07)
    link(g, 8, [(-1.15, Y(1.1), 0.3), (-0.9, Y(0.9), 0.6), (-0.66, Y(0.66), 0.78)], 0.06)
    for (xx, yn) in ((-0.95, -0.95), (-0.75, -1.05), (0.9, -0.95), (1.05, -1.05), (-1.6, 0.75), (-1.25, 0.8),
                     (0.6, 1.7), (-0.4, 1.75), (1.15, 1.55), (1.75, 1.2), (-1.85, -0.9), (0.95, 0.95),
                     (-0.6, -1.3), (-1.0, -1.7), (1.85, -0.85), (1.8, 0.15), (-0.6, -1.85), (0.25, 1.9)):
        jar(g, (xx, Y(yn), 0.04), 0.045, 0.11)
    g.halo((1.5, Y(0.05), 0.6), M["_emit_rgb"], 14.0)
    g.halo((-1.42, Y(1.28), 0.6), M["_emit_rgb"], 12.0)
def jar(g, c, r, h):
    """Bocal de prélèvement (marais) : verre lumineux, couvercle et cerclage laiton."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + h / 2), "z", r, h, M["emit_soft"], n=14, what="bocal")
    g.cyl((x, y, z + h + 0.012), "z", r + 0.008, 0.024, M["brass"], n=14, what="couvercle")
    g.tube_shell((x, y, z + 0.01), "z", r + 0.008, r - 0.004, 0.02, M["brass"], n=14, what="cerclage")
    g.box((x + r, y, z + h / 2), (0.02, 0.02, h), M["steel_dk"], "hard", what="patte")


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : conduit toxique en caoutchouc annelé, tronçon de tube de verre à viroles de laiton
# ------------------------------------------------------------------------------------------------
def link(g, e, ctrl, r=0.05, kind=None):
    """Liaison d'une machine à la colonne (catalogue, rubrique « Tuyaux » du marais)."""
    M = g.M
    P = F.polyline_pts(ctrl)
    S_ = g.hose(P, r * 0.9, M["rubber"], step=0.03)
    mid = len(S_) // 2
    if len(S_) > 6:
        a, b = S_[mid - 3], S_[mid + 3]
        d = b - a
        g.cyl((a + b) / 2, d, r * 0.95, d.length, M["emit_soft"], n=14, what="tube_verre")
        for q in (a, b):
            g.cyl(q, d, r * 1.25, 0.03, M["brass"], n=14, style="hard", what="virole")
    return P


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 16 : 2 bonbonnes de verre sur berceau à pompe
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    M = g.M
    side = c.side
    cx = c.T["piece"]["x"]
    cy = -cx
    s = c.T["piece"]["s"]
    for sx in (-1, 1):
        xa, xb = sorted((sx * (cx - 0.3 - 0.07 * side), sx * (cx + 0.2 + 0.03 * side)))
        corps.dalle(g, xa, xb, Y(cy - 0.24 - 0.02 * side), Y(cy + 0.34 + 0.06 * side))
    for sx in (-1, 1):
        demijohn(g, (sx * cx, Y(cy), 0.0), M["emit_soft"], 1.5 * s)
    _halo(g, [(-cx, Y(cy), 0.4), (cx, Y(cy), 0.4)], 12.0)


def demijohn(g, c, emat, s=1.0):
    """Bonbonne de verre sur berceau à pompe (marais) : sphère cerclée, cage, manomètre."""
    M = g.M
    x, y, z = c
    r = 0.13 * s
    g.box((x, y, z + 0.035), (0.3 * s, 0.3 * s * SQ2 * 0.8, 0.07), M["steel_dk"], "hard", what="berceau")
    zc = z + 0.07 + r * 0.95
    F.sphere(g, (x, y, zc), r, emat, n=20, m=12, what="bonbonne")
    g.torus((x, y, zc), "z", r + 0.004, 0.012, M["brass"], n=24, m=6, what="cerclage")
    for k in range(6):
        a = TAU * k / 6
        g.box((x + math.cos(a) * (r + 0.012), y + math.sin(a) * (r + 0.012), zc), (0.016, 0.016, r * 2.0),
              M["verdigris"], "hard", what="cage")
    g.cyl((x, y, zc + r + 0.025), "z", 0.04, 0.05, M["brass"], n=12, what="col")
    g.cyl((x + 0.12 * s, y - 0.06 * s, z + 0.13), "z", 0.035, 0.12, M["olive"], n=12, what="pompe")
    P2.gauge(g, (x + 0.12 * s, y - 0.06 * s - 0.036, z + 0.16), (0, -1, 0.3), 0.032, M)
    g.hose([(x + 0.12 * s, y - 0.06 * s, z + 0.19), (x + 0.08 * s, y - 0.02, zc + r * 0.7), (x, y, zc + r + 0.04)],
           0.016, M["rubber"], step=0.02)


# ------------------------------------------------------------------------------------------------
# Arme (E1) : gatling de vert-de-gris à cuve de verre couchée
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    M = g.M
    H = c.H
    w_marsh(g, ST, H, x, sx)
    y0 = H["recv"][0]
    PT.lamp(g, (x - sx * H["wr"] * 0.25, y0 + 0.1, H["zg"] + H["hr"] + 0.03), (0, 0.4, 1), 0.026, M["emit"], cage=True)


def w_gatling(g, st, H, x, sx):
    """Faisceau rotatif de la lignée, habillé par l'époque (jaquette, bouche, entraînement, alimentation)."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    breech(g, st, x, y0, y1, zg - hr, zg + hr, wr)
    Ld = 0.26 + hr * 0.6
    drive(g, st, (x, y0 - Ld / 2 + 0.03, zg), hr * 0.78, Ld)
    gun_e(g, st, H, x, sx)
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M[k] for k in st["gmask"]], rivet_step=0.11)
    xo = x + sx * (wr / 2 - 0.005)
    feed(g, st, H, x, sx, xo)


def w_marsh(g, st, H, x, sx):
    """Époque 8 : gatling de vert-de-gris à buse en cloche, portant une CUVE DE VERRE couchée (liquide vert,
    côtes, fonds de laiton) reliée à la culasse par un tuyau de caoutchouc."""
    M = g.M
    w_gatling(g, st, H, x, sx)
    y0, y1 = H["recv"]
    zg, hr = H["zg"], H["hr"]
    rs = H["rr"] + H["rb"] + 0.028
    r = 0.16
    Lv = H["L"] * 0.6
    c = V((x, y1 + 0.06 + Lv / 2, zg + rs + r + 0.03))
    for f in (-0.34, 0.34):
        g.box(c + V((0, f * Lv, -r - 0.02)), (0.06, 0.05, 0.07), M["verdigris"], "hard", what="patte")
    g.cyl(c, "y", r - 0.008, Lv, M["emit_soft"], n=24, what="liquide")
    for kk in range(6):
        a = TAU * (kk + 0.5) / 6
        d = V((math.cos(a), 0, math.sin(a)))
        g.box(c + d * (r - 0.004), (0.024, Lv, 0.022), M["verdigris"], "hard",
              R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed(), what="cote")
    for f in (-0.5, 0.0, 0.5):
        g.tube_shell(c + V((0, f * Lv, 0)), "y", r + 0.018, r - 0.02, 0.035, M["brass"], n=24, what="cerclage")
    for f in (-1, 1):
        g.cyl(c + V((0, f * (Lv / 2 + 0.03), 0)), "y", r * 0.85, 0.05, M["brass"], n=24, r2=r * 0.5, what="fond")
    for i in range(7):
        g.dome(c + V((0.045 * ((i % 3) - 1), -Lv * 0.42 + i * Lv * 0.14, r - 0.01)), (0, 0, 1), 0.016, M["emit"],
               what="bulle")
    g.hose([c + V((0, -Lv / 2 - 0.05, 0)), V((x, y0 + 0.2, zg + hr + 0.12)), V((x, y0 + 0.08, zg + hr + 0.02))],
           0.03, M["rubber"], step=0.03)


def gun_e(g, st, H, x, side):
    """Faisceau de la lignée (corps.rosette), manchon à fenêtres et buse en cloche ; renvoie le rayon de jaquette."""
    M = g.M
    y1 = H["recv"][1]
    L, nb, rb, rr = H["L"], H["nb"], H["rb"], H["rr"]
    zg = H["zg"]
    rs = rr + rb + 0.028
    pos = corps.rosette(g, x, y1, zg, L, nb, rb, rr, mat=M[st.get("barrel", "gun")], collier_mat=M[st["band"]],
                        colliers=st.get("collars", (0.8,)), bouts=False)
    Lj = L * st.get("jacket_f", 0.62)
    jk_marsh(g, st, x, y1, zg, Lj, rs, H)
    br_nozzle(g, st, x, y1 + L, zg, rs, pos, H)
    return rs


def jk_marsh(g, st, x, y0, z, Lj, rs, H):
    """Époque 8 : manchon de vert-de-gris à 2 fenêtres de verre longues (liquide vert-jaune, bulles)."""
    M = g.M
    g.cyl((x, y0 + Lj / 2, z), "y", rs, Lj, M["verdigris"], n=28, what="jaquette")
    for a in (math.pi * 0.5 + 0.55, math.pi * 0.5 - 0.55):
        d = V((math.cos(a), 0, math.sin(a)))
        Rr = Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed()
        c = V((x, y0 + Lj * 0.52, z)) + d * (rs + 0.004)
        g.box(c, (0.07, Lj * 0.7, 0.012), M["emit_soft"], "flat", R=Rr, what="fenetre")
        for s in (-1, 1):
            g.box(c + Rr @ V((s * 0.045, 0, 0.006)), (0.02, Lj * 0.74, 0.02), M["brass"], "hard", R=Rr,
                  what="cadre")
        for t in range(4):
            g.box(c + Rr @ V((0, (t - 1.5) * Lj * 0.17, 0.007)), (0.09, 0.016, 0.014), M["verdigris"], "hard", R=Rr,
                  what="barreau")
        for t in range(3):
            g.dome(c + Rr @ V((0.015 * ((t % 2) * 2 - 1), (t - 1) * Lj * 0.2 + 0.03, 0.008)), d, 0.011, M["emit"])
    for yy in (y0 + 0.025, y0 + Lj - 0.02):
        g.tube_shell((x, yy, z), "y", rs + 0.03, rs - 0.01, 0.05, M["rubber"], n=28, what="joint")
        F.bolts_ring(g, (x, yy, z), (0, 1, 0), rs + 0.031, 6, M["brass"], r=0.014, skip_down=-0.3)


def br_nozzle(g, st, x, yb, z, rs, pos, H):
    """Époque 8 : buse à collerette de caoutchouc et anneau de joint, plus large que le faisceau."""
    M = g.M
    rb = H["rb"]
    # buse en CLOCHE nettement plus large que le faisceau (silhouette du marais, poses E et N)
    g.cyl((x, yb + 0.06, z), "y", rs + 0.01, 0.14, M["verdigris"], n=28, r2=rs + 0.085, what="buse")
    g.torus((x, yb + 0.13, z), "y", rs + 0.085, 0.026, M["rubber"], n=28, m=8, what="collerette")
    g.cyl((x, yb + 0.128, z), "y", rs + 0.07, 0.01, M["glass_dk"], n=28, what="fond_cloche")
    g.torus((x, yb - 0.01, z), "y", rs + 0.012, 0.016, M["rubber"], n=28, m=8, what="joint")
    F.bolts_ring(g, (x, yb + 0.03, z), (0, 1, 0), rs + 0.024, 6, M["brass"], r=0.014, skip_down=-0.3)
    g.cyl((x, yb + 0.134, z), "y", rs + 0.035, 0.012, M["verdigris"], n=28, what="face")
    F.bores(g, x, yb + 0.14, z, pos, rb, M["brass"])
    F.lit_ring(g, (x, yb + 0.142, z), "y", rs + 0.03, M["emit"])


def breech(g, st, x, y0, y1, z0, z1, w):
    """Culasse blindée (lignée PT.receiver) de vert-de-gris et kaki."""
    M = g.M
    mats = [M[k] for k in st["recv_mats"]]
    return PT.receiver(g, x, y0, y1, z0, z1, w, mats=mats)


def drive(g, st, c, r, L):
    """Organe arrière du canon : moteur de la lignée en vert-de-gris, ailettes d'acier sombre."""
    M = g.M
    x, y, z = c
    body = M[st.get("drive_mat", "steel_dk")]
    g.cyl((x, y, z), "y", r, L, body, n=28, style="soft", phase=math.pi / 8, what="moteur")
    nf = int((L * 0.5) / 0.045)
    fm = M[st.get("fin_mat", "steel_hi")]
    for kk in range(nf):
        g.tube_shell((x, y - L / 2 + 0.04 + kk * 0.045, z), "y", r + 0.026, r - 0.01, 0.014, fm, n=28, what="ailette")
    g.cyl((x, y - L / 2 - 0.03, z), "y", r * 0.85, 0.06, M[st.get("flange_mat", "olive")], n=24, style="soft",
          what="flasque")
    F.bolts_ring(g, (x, y - L / 2 - 0.06, z), (0, -1, 0), r * 0.66, 8, M["rivet"], r=0.016)
    g.cyl((x, y - L / 2 - 0.08, z), "y", r * 0.3, 0.05, M[st["band"]], n=12, what="moyeu")


def feed(g, st, H, x, sx, xo):
    """Alimentation : petite boîte à raccord de laiton (tuyaux souples depuis le bulbe dorsal), manomètre."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    bw, bl, bh = 0.18, H["L"] * 0.3, 0.2
    bx0, bx1 = sorted((xo, xo + sx * bw))
    PT.hull(g, bx0, bx1, y0 - 0.05, y0 - 0.05 + bl, zg - bh * 0.6, zg + bh * 0.4, ins=(0.015, 0.015, 0.015),
            panel=0.24, mats=[M["verdigris"], M["olive"]], rivet_step=0.11)
    bc = (bx0 + bx1) / 2
    g.cyl((bc, y0 + bl * 0.4, zg + bh * 0.4 + 0.03), "z", 0.05, 0.06, M["brass"], n=16, what="raccord")
    P2.gauge(g, (bc, y0 - 0.06, zg), (0, -1, 0.3), 0.04, M)


# ------------------------------------------------------------------------------------------------
# Masque, nacelle, tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=ST["gmask"], fentes=((0.0, 1.1),), visiere=("steel_dk", 0.03),
                        coax=dict(fut="gun", manchon=ST["band"], manchon_y=0.3, manchon_r=0.046, manchon_L=0.12,
                                  anneau=True))


def nacelle(g, c):
    """Bulbe de verre dorsal (réservoir rond lumineux), cerclé, en cage, relié aux canons par des tuyaux souples."""
    M = g.M
    H = c.H
    bx, yb0, yb1, ztop, yc = c.nac
    rB = 0.17
    F.sphere(g, (0.0, yc, ztop + rB * 0.9), rB, M["emit_soft"], n=24, m=12)
    g.torus((0.0, yc, ztop + rB * 0.9), "z", rB + 0.005, 0.016, M["brass"], n=28, m=6, what="cerclage")
    for k in range(6):
        a = TAU * k / 6
        g.box((math.cos(a) * (rB + 0.012), yc + math.sin(a) * (rB + 0.012), ztop + rB * 0.9), (0.02, 0.02, rB * 1.9),
              M["verdigris"], "hard", what="cage")
    g.cyl((0.0, yc, ztop + 0.03), "z", rB * 0.85, 0.06, M["verdigris"], n=20, what="embase")
    g.cyl((0.0, yc, ztop + rB * 1.9 + 0.02), "z", 0.04, 0.05, M["brass"], n=12, what="col")
    for sx in (-1, 1):
        g.hose([(sx * rB * 0.7, yc + 0.05, ztop + 0.12), (sx * H["gx"] * 0.6, -0.2, H["zg"] + H["hr"] + 0.12),
                (sx * H["gx"], H["recv"][0] + 0.2, H["zg"] + H["hr"] + 0.04)], 0.032, M["rubber"], step=0.03)


def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    zs, rz = H["zs"], H["rz"]
    side = c.side
    k = KIN
    F.slits(g, R, c.rt + 0.1 + 0.02 * side, 11, M["emit"], a0=math.pi * 0.62, span=math.pi * 1.76)
    F.voyants_tete(g, H, 16)
    PT.sight(g, (R * 0.2, R * 0.45, H["zs"] + H["rz"] * 0.6), 0.16 + 0.04 * (side - 3), 0.18, 0.1, M["emit"],
             lenses=side - 2)
    appl = M[ST["appl"]]
    n1 = {0: 3, 1: 6, 2: 8}[k] + (side - 2)
    for i in range(n1):
        th = 0.45 + (math.pi - 0.9) * (i + 0.5) / n1
        P2.applique(g, c.Pf, c.Nf, th, 0.3, 0.22 + 0.03 * (side - 2), 0.18 + 0.03 * (side - 2), appl, M)
    n2 = 2 + 2 * k
    for i in range(n2):
        th = 0.7 + (math.pi - 1.4) * (i + 0.5) / n2
        P2.applique(g, c.Pf, c.Nf, th, 0.72, 0.2, 0.16, appl, M)
    # signature de coupole : lanterneau de verre à côtes de vert-de-gris
    rG = R * 0.36
    zc = zs + rz * 0.82
    F.sphere(g, (0, -R * 0.1, zc), rG, M["emit_soft"], n=24, m=12, sz=0.75, what="lanterneau")
    for k_ in range(6):
        a = TAU * k_ / 6
        g.tube([V((math.cos(a) * rG * 1.02, -R * 0.1 + math.sin(a) * rG * 1.02, zc - 0.02)),
                V((math.cos(a) * rG * 0.7, -R * 0.1 + math.sin(a) * rG * 0.7, zc + rG * 0.55)),
                V((0, -R * 0.1, zc + rG * 0.77))], 0.014, M["verdigris"], n=6, what="cote")
    g.torus((0, -R * 0.1, zc), "z", rG * 1.01, 0.02, M["brass"], n=28, m=6, what="cerclage")
