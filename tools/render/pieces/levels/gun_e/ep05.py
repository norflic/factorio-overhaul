"""Époque 5 · Volcan (ère II, 3×3, niveaux 9 et 10). Constructeur : PLAGE BASSE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 5) : « blindé, sombre, braise ».
PORTÉ TEL QUEL de la passe 3 (gun_e_bas, commit 4c57982 : design.py, ages.py, parts4.py ; outil de portage, code d'origine mot pour
mot) sur le kit commun gun_e : seul le CORPS a changé (corps.py, kit.py). Aucune correction de design d'époque.
Emplacements remplis : arme (OBUSIER court et massif : manchon blindé à pans, cylindres de recul, frein en coin à
évents de braise, culasse à écailles, caisson blindé incliné), masque (glacis en écailles), grands volumes du socle
(bunkers en tronc de pyramide, tas de scories rougeoyants), liaisons (fonte à coudes vifs et fentes de braise),
fentes de braise sur la coupole, foyers braise, pièce paire (2 mortiers blindés).
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

EPOQUE = 5
NOM = "Volcan"
KIN = 1   # rang dans l'ère II
FOYER = dict(rgb=(1.0, 0.29, 0.063))
CANON = dict(L=1.28, nb=4, rb=0.054, rr=0.115)
HABILLAGE = dict(jupe_cerclage="burnrust", tremie="tungsten", pochoirs=True, munitions=("tungsten", "burnrust"),
                 tourelleau="tungsten", chapeau="burnrust")
ST = dict(jacket="hex", brake="wedge", drive="scale", drive_mat="tungsten", fin_mat="burnrust", band="burnrust",
          recv_mats=("tungsten", "burnrust"), recv_sig="scales", feed="armored", skirt="burnrust", appl="tungsten",
          gmask=("tungsten", "burnrust"), arm=("tungsten", "olive"), cap="burnrust", mask="glacis",
          col=("tungsten", "olive"), nac=("tungsten", "burnrust"), flange_mat="burnrust")


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle : bunkers en tronc de pyramide, tas de scories
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    F.lamp_group(g, (x0 + 0.07, y0 - 0.03, h * 0.62), (1, 0, 0), (0, -1, 0), M["emit"], n=2)
    socle_volcano(g, KIN)
    corps.collecteur(g, c, lambda g_, pts, r: link(g_, EPOQUE, pts, r))


def bunker(g, x0, x1, yn0, yn1, h, M, E, ins=0.12, slits=3, spikes=2):
    T = PT.hull(g, x0, x1, Y(yn0), Y(yn1), 0.0, h, ins=(ins, ins * 0.8, ins * 1.2), panel=0.24,
                mats=[M["tungsten"], M["burnrust"], M["tungsten"]], rivet_step=0.1)
    # rivets lourds sur les arêtes du dessus
    for i in range(4):
        a, b = T[i], T[(i + 1) % 4]
        n = max(2, int((b - a).length / 0.14))
        for kk in range(n):
            g.dome(a.lerp(b, (kk + 0.5) / n) + V((0, 0, 0.032)), (0, 0, 1), 0.022, M["rivet"])
    # fentes de braise au sud (meurtrières rougeoyantes)
    y0 = Y(yn0)
    for i in range(slits):
        xx = x0 + (x1 - x0) * (i + 0.5) / slits
        yf = y0 + ins * 0.8 * 0.45 - 0.04
        g.box((xx, yf, h * 0.45), (0.12, 0.012, 0.045), E, "flat", what="braise")
        g.box((xx, yf - 0.01, h * 0.45 + 0.035), (0.15, 0.04, 0.022), M["tungsten"], "hard",
              R=Matrix.Rotation(-0.6, 3, "X"), what="visiere")
        for s_ in (-1, 1):
            g.box((xx + s_ * 0.075, yf + 0.01, h * 0.45), (0.022, 0.05, 0.07), M["burnrust"], "hard", what="joue")
    # grille de braise sur le dessus (foyer de 0,1 t² environ, barreaux sombres par-dessus)
    cx_, cy_ = (T[0].x + T[2].x) / 2, (T[0].y + T[2].y) / 2
    gw, gl = (T[1].x - T[0].x) * 0.55, (T[2].y - T[1].y) * 0.4
    g.box((cx_, cy_, h + 0.045), (gw, gl, 0.01), E, "flat", what="braise")
    for kk in range(4):
        g.box((cx_, cy_ - gl / 2 + gl * (kk + 0.5) / 4, h + 0.065), (gw + 0.04, 0.022, 0.03), M["tungsten"], "hard",
              what="barreau")
    for s_ in (-1, 1):
        g.box((cx_ + s_ * (gw / 2 + 0.03), cy_, h + 0.05), (0.05, gl + 0.06, 0.07), M["burnrust"], "hard", what="cadre")
        g.box((cx_, cy_ + s_ * (gl / 2 + 0.03), h + 0.05), (gw + 0.1, 0.05, 0.07), M["burnrust"], "hard", what="cadre")
    # pointes de basalte aux coins du dessus
    for i in range(spikes):
        p = T[(2 + i) % 4]
        g.cyl(p + V((0, 0, 0.08)), (0.25 * (1 if p.x > (x0 + x1) / 2 else -1), 0.15, 1), 0.04, 0.17, M["basalt"],
              n=5, r2=0.004, style="hard", what="pointe")
    return T


def slag_heap(g, x, yn, r, M, E, n=7):
    """Tas de scories : blocs de basalte entassés, fissures de braise courtes."""
    y = Y(yn)
    for i in range(n):
        a = TAU * i / n + 0.4
        rr = r * (0.45 + 0.25 * (i % 2))
        F.lump(g, (x + math.cos(a) * rr, y + math.sin(a) * rr * 1.2, 0.0), r * (0.42 - 0.04 * (i % 3)), M["basalt"],
             sz=0.5, n=9, m=5, jit=0.3, what="scorie")
    F.lump(g, (x, y, 0.06), r * 0.55, M["burnrust"], sz=0.6, n=10, m=6, jit=0.25, what="scorie")
    for i in range(3):
        a = TAU * i / 3 + 1.0
        g.box((x + math.cos(a) * r * 0.3, y + math.sin(a) * r * 0.35, r * 0.3), (0.09, 0.016, 0.01), E, "flat",
              R=Matrix.Rotation(a, 3, "Z"), what="fissure")


def socle_volcano(g, k):
    M = g.M
    E = M["emit"]
    # ouest et est : bunkers blindés en tronc de pyramide (plus hauts et plus longs que les cuves du pétrole)
    bunker(g, -1.5, -0.78, -0.8, 0.92, 0.56, M, E, slits=4)
    bunker(g, 0.78, 1.5, -0.66, 0.8, 0.6, M, E, slits=3)
    # bouche de lave de l'est (gueule rougeoyante au sud, sur le flanc du bunker)
    g.box((1.17, Y(-0.6) + 0.1, 0.16), (0.26, 0.02, 0.1), E, "flat", what="gueule")
    PT.hull(g, 1.0, 1.34, Y(-0.6) - 0.02, Y(-0.6) + 0.1, 0.22, 0.3, ins=(0.02, 0.0, 0.02), panel=0.2,
            mats=[M["tungsten"]], rivet_step=0.1)
    # nord : tas de scories (nord-ouest), évent pyramidal de braise (nord-est)
    slag_heap(g, -1.05, 1.15, 0.42, M, E, n=9)
    slag_heap(g, -0.35, 1.3, 0.3, M, E, n=6)
    F.prism(g, [(0.68, Y(0.96)), (1.36, Y(0.96)), (1.36, Y(1.42)), (0.68, Y(1.42))], 0.0, 0.08, M["tungsten"])
    PT.hull(g, 0.72, 1.32, Y(1.0), Y(1.38), 0.08, 0.42, ins=(0.2, 0.16, 0.16), panel=0.22,
            mats=[M["tungsten"], M["burnrust"]], rivet_step=0.1)
    g.box((1.02, Y(1.19), 0.43), (0.16, 0.16, 0.012), E, "flat", what="event_braise")
    g.box((1.02, Y(1.19), 0.45), (0.2, 0.03, 0.02), M["tungsten"], "hard", what="grille")
    # conduits de fonte à coudes vifs (fentes de braise sur les coudes)
    link(g, 5, [(-0.88, Y(0.3), 0.3), (-0.8, Y(0.3), 0.5), (-0.66, Y(0.24), 0.5)], 0.06)
    link(g, 5, [(0.88, Y(0.1), 0.3), (0.8, Y(0.1), 0.5), (0.66, Y(0.08), 0.5)], 0.06)
    link(g, 5, [(0.9, Y(1.18), 0.3), (0.6, Y(1.0), 0.45), (0.3, Y(0.8), 0.55)], 0.055)
    for (xx, yn) in ((-1.35, 0.95), (-1.45, 1.4), (0.75, 0.9), (1.32, 0.9)):
        g.box((xx, Y(yn), 0.12), (0.09, 0.07, 0.02), E, "flat", what="braise")
        g.box((xx, Y(yn) + 0.045, 0.13), (0.11, 0.02, 0.03), M["basalt"], "hard", what="levre")
    g.halo((-1.05, Y(1.15), 0.3), M["_emit_rgb"], 12.0)
    g.halo((1.17, Y(-0.7), 0.25), M["_emit_rgb"], 12.0)
    g.halo((1.02, Y(1.19), 0.6), M["_emit_rgb"], 8.0)


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : conduit trapu en fonte à coudes VIFS, brides lourdes à 6 boulons, fente de braise sur le coude
# ------------------------------------------------------------------------------------------------
def link(g, e, ctrl, r=0.05, kind=None):
    """Liaison d'une machine à la colonne (catalogue, rubrique « Tuyaux » du volcan)."""
    M = g.M
    P = F.polyline_pts(ctrl)
    for i in range(len(P) - 1):
        a, b = P[i], P[i + 1]
        d = b - a
        g.cyl((a + b) / 2, d, r * 1.05, d.length, M["castiron"], n=12, style="hard", what="conduit")
    for i, p in enumerate(P):
        g.box(p, (r * 2.4, r * 2.4, r * 2.4), M["tungsten"], "hard", what="coude")
        if 0 < i < len(P) - 1:
            g.box(p + V((0, -r * 1.21, 0)), (r * 1.4, 0.008, r * 0.4), M["emit"], "flat", what="braise")
        for k in range(6):
            ang = TAU * k / 6
            g.dome(p + V((math.cos(ang) * r * 0.9, -r * 1.2, math.sin(ang) * r * 0.9)), (0, -1, 0), 0.015,
                   M["rivet"])
    return P


def arch_hose(g, e, p0, p1, lift, r):
    """Liaison de la tête qui PASSE PAR-DESSUS la coupole (visible à toutes les poses), dans le style d'époque."""
    p0, p1 = V(p0), V(p1)
    m = (p0 + p1) / 2
    m.z = max(p0.z, p1.z) + lift
    q0 = p0.lerp(m, 0.5)
    q0.z = m.z - lift * 0.25
    q1 = m.lerp(p1, 0.5)
    q1.z = m.z - lift * 0.25
    return link(g, e, [p0, q0, m, q1, p1], r, kind="arch")


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 10 : 2 mortiers trapus blindés
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    side = c.side
    cx = c.T["piece"]["x"]
    cy = -cx
    s = c.T["piece"]["s"]
    for sx in (-1, 1):
        xa, xb = sorted((sx * (cx - 0.3 - 0.07 * side), sx * (cx + 0.2 + 0.03 * side)))
        corps.dalle(g, xa, xb, Y(cy - 0.24 - 0.02 * side), Y(cy + 0.34 + 0.06 * side))
    for sx in (-1, 1):
        with at(g, sx * cx, cy, sx * -0.3):
            mortar(g, (0, 0, 0), 0.0, 1.5 * s)
    _halo(g, [(-cx, Y(cy) + 0.1, 0.4), (cx, Y(cy) + 0.1, 0.4)], 10.0)


def mortar(g, c, rz, s=1.0):
    """Mortier trapu blindé (volcan) : tube court et gros incliné vers l'avant, affût à écailles."""
    M = g.M
    g.push(c, rz=rz)
    F.prism(g, [(-0.17 * s, -0.17 * s), (0.17 * s, -0.17 * s), (0.17 * s, 0.17 * s), (-0.17 * s, 0.17 * s)], 0.0,
          0.06 * s, M["tungsten"])
    g.cyl((0, 0, 0.1 * s), "z", 0.14 * s, 0.08 * s, M["burnrust"], n=8, style="hard", what="affut")
    for k in range(6):
        a = TAU * k / 6
        d = V((math.cos(a), math.sin(a), 0))
        g.box(d * 0.13 * s + V((0, 0, 0.12 * s)), (0.09 * s, 0.02, 0.06 * s), M["tungsten"], "hard",
              R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed() @ Matrix.Rotation(-0.35, 3, "X"),
              what="ecaille")
    d = V((0, -0.55, 1)).normalized()
    p = V((0, 0.02, 0.18 * s))
    g.cyl(p + d * 0.1 * s, d, 0.075 * s, 0.24 * s, M["tungsten"], n=16, what="tube")
    g.tube_shell(p + d * 0.2 * s, d, 0.09 * s, 0.06 * s, 0.05 * s, M["burnrust"], n=16, what="bague")
    g.cyl(p + d * 0.225 * s, d, 0.05 * s, 0.01, M["void"], n=14, style="flat", what="bouche")
    g.tube_shell(p + d * 0.228 * s, d, 0.07 * s, 0.05 * s, 0.01, M["emit"], n=16, what="levre")
    for sx in (-1, 1):
        g.box((sx * 0.1 * s, 0.0, 0.2 * s), (0.03, 0.12 * s, 0.1 * s), M["tungsten"], "hard", what="tourillon")
        g.dome((sx * 0.117 * s, 0.0, 0.21 * s), (sx, 0, 0), 0.02, M["rivet"])
    g.pop()


# ------------------------------------------------------------------------------------------------
# Arme (E1) : obusier
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    M = g.M
    H = c.H
    w_howitzer(g, ST, H, x, sx)
    y0 = H["recv"][0]
    PT.lamp(g, (x - sx * H["wr"] * 0.25, y0 + 0.1, H["zg"] + H["hr"] + 0.03), (0, 0.4, 1), 0.026, M["emit"], cage=True)


def w_howitzer(g, st, H, x, sx):
    """Époque 5 : OBUSIER court et massif par flanc : une seule âme de gros calibre, manchon blindé à pans de
    tungstène, 2 cylindres de recul (dessus et dessous), frein de bouche en coin à évents de braise ; culasse à
    écailles, caisson blindé incliné."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    breech(g, st, x, y0, y1, zg - hr * 1.15, zg + hr * 1.15, wr * 1.12)
    Ld = 0.26 + hr * 0.6
    drive(g, st, (x, y0 - Ld / 2 + 0.03, zg), hr * 0.85, Ld)
    L = H["L"] * 0.62
    R6 = 0.19
    rb = 0.072
    Lj = L * 0.62
    g.cyl((x, y1 + Lj / 2, zg), "y", R6, Lj, M["tungsten"], n=6, style="hard", phase=math.pi / 6, what="manchon")
    for f in range(6):
        a = math.pi / 6 + TAU * f / 6 + TAU / 12
        d = V((math.cos(a), 0, math.sin(a)))
        if d.z < -0.3:
            continue
        for i in range(3):
            g.dome(V((x, y1 + Lj * (0.2 + 0.3 * i), zg)) + d * (R6 * math.cos(math.pi / 6) + 0.004), d, 0.022,
                   M["rivet"])
    for yy in (y1 + 0.03, y1 + Lj - 0.03):
        g.cyl((x, yy, zg), "y", R6 + 0.026, 0.06, M["burnrust"], n=6, style="hard", phase=math.pi / 6, what="bague")
    g.cyl((x, y1 + Lj + (L - Lj) / 2, zg), "y", rb + 0.03, L - Lj, M["gun"], n=20, what="ame")
    for s in (-1, 1):
        zr = zg + s * (R6 + 0.045)
        g.cyl((x, y1 + Lj * 0.45, zr), "y", 0.04, Lj * 0.9, M["burnrust"], n=14, what="recul")
        g.cyl((x, y1 + Lj * 0.92, zr), "y", 0.05, 0.05, M["tungsten"], n=14, what="tete_recul")
    # fentes de braise sur le dessus du manchon
    for i in range(2):
        g.box((x, y1 + Lj * (0.3 + 0.38 * i), zg + R6 * math.cos(math.pi / 6) + 0.003), (0.05, 0.1, 0.008),
              M["emit"], "flat", what="braise")
    br_wedge(g, st, x, y1 + L, zg, rb + 0.06, [(x, zg)], dict(H, rb=rb))
    PT.hull(g, x - wr * 0.8, x + wr * 0.8, y1 - 0.04, y1 + 0.07, zg - hr * 1.4, zg + hr * 1.5,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["tungsten"], M["burnrust"]], rivet_step=0.1)
    xo = x + sx * (wr * 0.56 - 0.005)
    feed(g, st, H, x, sx, xo)
def br_wedge(g, st, x, yb, z, rs, pos, H):
    """Époque 5 : frein de bouche en coin (bloc trapézoïdal à évents obliques), lèvres de braise dans les évents."""
    M = g.M
    rb = H["rb"]
    w0, w1 = rs * 2.2, rs * 2.6
    h0, h1 = rs * 1.7, rs * 1.25
    y0, y1 = yb - 0.03, yb + 0.2
    pts = [V((x - w0 / 2, y0, z - h0 / 2)), V((x + w0 / 2, y0, z - h0 / 2)), V((x + w1 / 2, y1, z - h1 / 2)),
           V((x - w1 / 2, y1, z - h1 / 2)),
           V((x - w0 / 2, y0, z + h0 / 2)), V((x + w0 / 2, y0, z + h0 / 2)), V((x + w1 / 2, y1, z + h1 / 2)),
           V((x - w1 / 2, y1, z + h1 / 2))]
    g.hexa(pts, M["tungsten"], "hard", what="frein")
    for s in (-1, 1):
        for k in range(3):
            yy = y0 + 0.05 + k * 0.06
            xx = x + s * (w0 / 2 + (w1 - w0) / 2 * (yy - y0) / (y1 - y0)) + s * 0.002
            Rr = Matrix.Rotation(s * 0.5, 3, "Z")
            g.box((xx, yy, z + 0.01), (0.016, 0.044, h1 * 0.78), M["emit"], "flat", R=Rr, what="braise")
            g.box((xx + s * 0.006, yy + 0.026, z + 0.01), (0.016, 0.012, h1 * 0.86), M["tungsten"], "hard", R=Rr,
                  what="lame")
    # évents supérieurs rougeoyants (lisibles d'en haut, poses E et N) et oreilles : jamais un chapeau de cheminée
    for k in range(3):
        yy = y0 + 0.05 + k * 0.06
        hz = h0 / 2 + (h1 - h0) / 2 * (yy - y0) / (y1 - y0)
        g.box((x, yy, z + hz + 0.002), (w0 * 0.62, 0.02, 0.008), M["emit"], "flat", what="braise")
    F.ears(g, x, yb + 0.08, z, w1 / 2 + 0.03, 0.14, h1 * 0.8, M["tungsten"])
    for k in range(4):
        g.dome((x - w1 * 0.3 + k * w1 * 0.2, y0 + 0.11, z + (h0 + h1) / 4 + 0.006), (0, 0, 1), 0.02, M["rivet"])
    g.cyl((x, y1 + 0.004, z), "y", rs * 0.95, 0.01, M["burnrust"], n=24, what="face")
    F.bores(g, x, y1 + 0.01, z, pos, rb, M["burnrust"])
    F.lit_ring(g, (x, y1 + 0.012, z), "y", rs * 0.95, M["emit"])


def breech(g, st, x, y0, y1, z0, z1, w):
    """Culasse blindée (lignée PT.receiver) à ÉCAILLES de blindage."""
    M = g.M
    mats = [M[k] for k in st["recv_mats"]]
    T = PT.receiver(g, x, y0, y1, z0, z1, w, mats=mats)
    zc = z1 + 0.012
    for i in range(3):
        for j in range(2):
            yy = y0 + 0.08 + (y1 - y0 - 0.16) * i / 2
            g.box((x + (j - 0.5) * w * 0.45, yy, zc + 0.02 + 0.006 * i), (w * 0.44, 0.13, 0.016), M["tungsten"],
                  "hard", R=Matrix.Rotation(-0.18, 3, "X"), what="ecaille")
    return T


def drive(g, st, c, r, L):
    """Organe arrière du canon : moteur de tungstène à ailettes de rouille brûlée, ÉCAILLES sur le dessus."""
    M = g.M
    x, y, z = c
    body = M[st.get("drive_mat", "steel_dk")]
    g.cyl((x, y, z), "y", r, L, body, n=28, style="soft", phase=math.pi / 8, what="moteur")
    nf = int((L * 0.5) / 0.045)
    fm = M[st.get("fin_mat", "steel_hi")]
    for kk in range(nf):
        g.tube_shell((x, y - L / 2 + 0.04 + kk * 0.045, z), "y", r + 0.026, r - 0.01, 0.014, fm, n=28, what="ailette")
    for kk in range(5):
        a = math.pi / 2 + (kk - 2) * 0.55
        d = V((math.cos(a), 0, math.sin(a)))
        g.box(V((x, y + L * 0.25, z)) + d * (r + 0.012), (0.08, L * 0.42, 0.018), M["tungsten"], "hard",
              R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed() @ Matrix.Rotation(0.12, 3, "X"),
              what="ecaille")
    g.cyl((x, y - L / 2 - 0.03, z), "y", r * 0.85, 0.06, M[st.get("flange_mat", "olive")], n=24, style="soft",
          what="flasque")
    F.bolts_ring(g, (x, y - L / 2 - 0.06, z), (0, -1, 0), r * 0.66, 8, M["rivet"], r=0.016)
    g.cyl((x, y - L / 2 - 0.08, z), "y", r * 0.3, 0.05, M[st["band"]], n=12, what="moyeu")


def feed(g, st, H, x, sx, xo):
    """Alimentation : CAISSON BLINDÉ incliné à goulotte, écailles, fente de braise."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    bw, bl, bh = 0.2, H["L"] * 0.36, 0.22
    bx0, bx1 = sorted((xo, xo + sx * bw))
    PT.hull(g, bx0, bx1, y0 - 0.05, y0 - 0.05 + bl, zg - bh * 0.7, zg + bh * 0.35, ins=(0.02, 0.03, 0.06),
            panel=0.24, mats=[M["tungsten"], M["burnrust"]], rivet_step=0.11)
    for k in range(3):
        g.box(((bx0 + bx1) / 2, y0 + bl * (0.2 + 0.25 * k), zg + bh * 0.35 + 0.012), (bw * 0.9, 0.1, 0.016),
              M["tungsten"], "hard", R=Matrix.Rotation(-0.2, 3, "X"), what="ecaille")
    bc = (bx0 + bx1) / 2
    P2.feed_chute(g, [(bc, y0 + bl * 0.6, zg + bh * 0.35 + 0.03), (bc - sx * 0.05, y0 + bl * 0.55, zg + hr + 0.05),
                      (x + sx * wr * 0.2, y0 + bl * 0.5, zg + hr + 0.06)], 0.12, M)
    g.box((bc + sx * (bw / 2 + 0.004), y0 + bl * 0.4, zg), (0.01, 0.06, 0.02), M["emit"], "flat", what="braise")


# ------------------------------------------------------------------------------------------------
# Masque (remplace celui de la lignée) : GLACIS en écailles incliné
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    M = g.M
    H = c.H
    R, zs, rz = H["R"], H["zs"], H["rz"]
    mw = R * 0.5
    PT.hull(g, -mw, mw, R * 0.55, R + 0.24, zs - 0.18, zs + rz * 0.55, ins=(0.04, 0.02, R * 0.32), panel=0.22,
            mats=[M["tungsten"], M["burnrust"]], rivet_step=0.11)
    for i in range(3):
        for j in range(3):
            yy = R * 0.62 + (R * 0.5) * (i / 2.0)
            zz = zs + rz * 0.5 - (rz * 0.5 + 0.12) * (i / 2.0) + 0.03
            g.box(((j - 1) * mw * 0.62, yy, zz), (mw * 0.66, 0.14, 0.018), M["tungsten"], "hard",
                  R=Matrix.Rotation(-0.55, 3, "X"), what="ecaille")
            g.dome(((j - 1) * mw * 0.62, yy + 0.04, zz + 0.022), (0, 0.4, 1), 0.017, M["rivet"])
    g.box((0, R + 0.25, zs - 0.06), (mw * 1.1, 0.012, 0.03), M["emit"], "flat", what="fente")


def nacelle(g, c):
    """Deux échappements de la lignée, bouches de braise."""
    M = g.M
    bx, yb0, yb1, ztop, yc = c.nac
    re, he = c.T["echap"]
    for sx in (-1, 1):
        PT.exhaust(g, (sx * bx * 0.7, yc - 0.05, ztop), re, he)
    for sx in (-1, 1):
        g.cyl((sx * bx * 0.7, yc - 0.05, ztop + he + 0.012), "z", re - 0.027, 0.008, M["emit"], n=14,
              style="flat", what="braise")


def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    side = c.side
    k = KIN
    F.slits(g, R, c.rt + 0.1 + 0.02 * side, 6, M["emit"], a0=math.pi * 0.62, span=math.pi * 1.76)
    F.voyants_tete(g, H, 6)
    zt = H["zs"] + H["rz"] * 0.42
    for sx in (-1, 1):
        arch_hose(g, EPOQUE, (sx * 0.15, -R - 0.06, zt + 0.02),
                  (sx * (H["gx"] - 0.03), H["recv"][0] + 0.1, H["zg"] + H["hr"] + 0.03),
                  0.1 + 0.03 * (side - 2), 0.034 + 0.008 * (side - 2))
    PT.sight(g, (R * 0.2, R * 0.45, H["zs"] + H["rz"] * 0.6), 0.16 + 0.04 * (side - 3), 0.18, 0.1, M["emit"],
             lenses=side - 2)
    # plaques rapportées : écailles de tungstène qui se chevauchent (2 par position), puis 2e rangée
    appl = M[ST["appl"]]
    n1 = {0: 3, 1: 6, 2: 8}[k] + (side - 2)
    for i in range(n1):
        th = 0.45 + (math.pi - 0.9) * (i + 0.5) / n1
        for j in range(2):
            P2.applique(g, c.Pf, c.Nf, th + 0.12 * j, 0.25 + 0.15 * j, 0.24, 0.16, M["tungsten"], M, bolts=0)
    n2 = 2 + 2 * k
    for i in range(n2):
        th = 0.7 + (math.pi - 1.4) * (i + 0.5) / n2
        P2.applique(g, c.Pf, c.Nf, th, 0.72, 0.2, 0.16, appl, M)
    # signature de coupole : fentes de braise à visière
    for i in range(7):
        th = math.pi * 0.2 + math.pi * 0.6 * i / 6
        p, nrm = c.Pf(th, 0.55, 1.012), c.Nf(th, 0.55)
        g.push_frame(p, nrm, xdir=(math.cos(th + math.pi / 2), math.sin(th + math.pi / 2), 0))
        g.box((0, 0, 0.004), (0.12, 0.022, 0.01), M["emit"], "flat", what="braise")
        g.box((0, 0.024, 0.014), (0.15, 0.025, 0.02), M["tungsten"], "hard", what="visiere")
        g.pop()
