"""Époque 6 · Électricité (ère II, 3×3, niveaux 11 et 12). Constructeur : PLAGE BASSE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 6) : « bobines, isolateurs, arcs ».
PORTÉ TEL QUEL de la passe 3 (gun_e_bas, commit 4c57982 : design.py, ages.py, parts4.py ; outil de portage, code d'origine mot pour
mot) sur le kit commun gun_e : seul le CORPS a changé (corps.py, kit.py). Aucune correction de design d'époque.
Emplacements remplis : arme (CANON-BOBINE : tube central gainé de 5 grosses bobines de cuivre et d'isolateurs, bouche
à électrodes, moteur bobiné, tambour), mitrailleuse coaxiale, grands volumes du socle (tour de Tesla, transformateur
à traversées, touret de câble, sphère de décharge, condensateurs), liaisons (câbles sur isolateurs), nacelle (tour
de Tesla dorsale et arcs), spires de cuivre sur la coupole, foyers cyan, pièce paire (2 piles à éclateur).
Défaut relevé par les juges (à corriger par le constructeur, RÈGLE D'OR 1) : les cylindres bobinés pleins cachent
les tubes.
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

EPOQUE = 6
NOM = "Électricité"
KIN = 2   # rang dans l'ère II
FOYER = dict(rgb=(0.376, 0.816, 1.0))
CANON = dict(L=1.35, nb=4, rb=0.045, rr=0.1)
HABILLAGE = dict(jupe_cerclage="copper", tremie="ochre", pochoirs=True, munitions=("copper", "steel_hi"),
                 chapeau="copper")
ST = dict(jacket="coils", brake="insul", drive="coil", band="copper", recv_mats=("ochre", "olive"), feed="drum",
          skirt="copper", appl="ochre", gmask=("ochre", "olive"), arm=("olive", "steel_dk"), cap="copper",
          col=("olive", "steel_dk"), nac=("olive", "ochre"), coax=True)


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle : tour de Tesla, transformateur, touret de câble, sphère de décharge
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    F.lamp_group(g, (x0 + 0.07, y0 - 0.03, h * 0.62), (1, 0, 0), (0, -1, 0), M["emit"], n=3)
    socle_electric(g, KIN)
    corps.collecteur(g, c, lambda g_, pts, r: link(g_, EPOQUE, pts, r))


def tesla_tower(g, x, yn, h, M, E, s=1.0):
    y = Y(yn)
    PT.hull(g, x - 0.2 * s, x + 0.2 * s, y - 0.2 * s, y + 0.2 * s, 0.0, 0.18, ins=(0.03, 0.03, 0.03), panel=0.2,
            mats=[M["olive"], M["steel_dk"]], rivet_step=0.1)
    g.box((x, y - 0.2 * s - 0.006, 0.1), (0.14, 0.012, 0.07), M["hazy"], "flat", what="haute_tension")
    n = max(4, int((h - 0.24) / 0.05))
    zt = PT.insulators(g, (x, y, 0.18), n, 0.075 * s, h=0.05)
    g.torus((x, y, zt + 0.04), "z", 0.15 * s, 0.05 * s, M["copper"], n=32, m=10, what="tore")
    g.cyl((x, y, zt + 0.04), "z", 0.15 * s, 0.06, M["steel_dk"], n=24, what="ame_tore")
    F.sphere(g, (x, y, zt + 0.12), 0.055 * s, M["steel_hi"], n=16, m=10, what="boule")
    return zt + 0.04


def socle_electric(g, k):
    M = g.M
    E = M["emit"]
    t1 = tesla_tower(g, -1.12, 1.08, 0.86, M, E)
    # nord-est : batterie de condensateurs BASSE (une tour à cet endroit traverse le canon nord en pose E : jour enfermé)
    PT.hull(g, 0.78, 1.46, Y(0.72), Y(1.18), 0.0, 0.06, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["olive"], M["steel_dk"]], rivet_step=0.1)
    PT.capacitors(g, (1.12, Y(0.95), 0.06), 3, 2, 0.07, 0.16, E)
    for x in (-1.12,):  # arc vers une pointe de terre
        g.cyl((x - 0.18 * (1 if x > 0 else -1), Y(1.08) - 0.12, t1 - 0.12), (x, 0, 1.2), 0.008, 0.18, E, n=6,
              style="flat", what="arc")
    # ouest : transformateur (cuve à ailettes, 3 traversées isolées, bornes de cuivre)
    for (xx, yn) in ((-0.62, -1.3), (0.62, -1.3), (-0.5, -0.95), (0.5, -0.95)):
        F.post_insulator(g, (xx, Y(yn), 0.0), 4, 0.04, h=0.045)
    for yn in (-0.8, 0.82):
        F.post_insulator(g, (-1.2, Y(yn), 0.0), 5, 0.045, h=0.045)
    PT.hull(g, -1.49, -0.86, Y(-0.72), Y(0.72), 0.0, 0.58, ins=(0.02, 0.02, 0.02), panel=0.24,
            mats=[M["olive"], M["steel_dk"]], rivet_step=0.12)
    for i in range(7):  # ailettes de refroidissement sur la face sud et le dessus
        yy = Y(-0.5) + i * 0.13
        g.box((-1.18, yy, 0.6), (0.5, 0.026, 0.05), M["steel_dk"], "hard", what="ailette")
    for i, yn in enumerate((-0.35, 0.0, 0.35)):
        zt = F.post_insulator(g, (-1.18, Y(yn), 0.62), 7, 0.06, h=0.045)
        g.cyl((-1.18, Y(yn), zt + 0.02), "z", 0.03, 0.04, M["copper"], n=10, what="borne")
    g.box((-1.18, Y(-0.72) - 0.03, 0.3), (0.22, 0.012, 0.12), M["hazy"], "flat", what="plaque_danger")
    g.box((-1.18, Y(-0.72) - 0.036, 0.3), (0.06, 0.012, 0.08), M["hazk"], "flat", what="eclair")
    # est : touret de câble de cuivre (flasques face au sud), sur chevalet
    xr, yr, zr = 1.16, Y(0.0), 0.42
    for s in (-1, 1):
        g.cyl((xr, yr + s * 0.14, zr), (0, 1, 0), 0.4, 0.04, M["wood"], n=36, style="soft", what="flasque")
        F.bolts_ring(g, (xr, yr + s * 0.14 - 0.024 * (s < 0), zr), (0, -1, 0), 0.3, 10, M["rivet"], r=0.013)
        g.box((xr, yr + s * 0.2, 0.21), (0.08, 0.04, 0.42), M["steel_dk"], "hard", what="chevalet")
    for kk in range(8):
        g.torus((xr, yr - 0.105 + kk * 0.03, zr), (0, 1, 0), 0.28, 0.016, M["copper"], n=32, m=6, what="spire")
    g.cyl((xr, yr - 0.16, zr), (0, 1, 0), 0.06, 0.03, M["steel_dk"], n=14, what="moyeu")
    # sud-est du touret : sphère de décharge sur poteau isolé
    zt = F.post_insulator(g, (0.95, Y(-0.72), 0.0), 6, 0.05, h=0.05)
    F.sphere(g, (0.95, Y(-0.72), zt + 0.1), 0.1, M["steel_hi"], n=20, m=12, what="sphere")
    # câbles sur isolateurs, jeu de barres
    link(g, 6, [(-0.9, Y(0.2), 0.4), (-0.84, Y(0.2), 0.52), (-0.66, Y(0.16), 0.58)], 0.06)
    link(g, 6, [(-1.0, Y(1.0), 0.3), (-0.6, Y(0.9), 0.5), (-0.3, Y(0.7), 0.6)], 0.06)
    link(g, 6, [(0.9, Y(0.7), 0.2), (0.7, Y(0.62), 0.32), (0.5, Y(0.52), 0.4)], 0.06)
    for i in range(2):
        g.box((0.82 + i * 0.07, Y(0.42), 0.36), (0.03, 0.4, 0.03), M["copper"], "hard", what="barre")
    for s in (0.82, 0.89):
        PT.insulators(g, (s, Y(0.52), 0.18), 3, 0.03, h=0.06)
    g.halo((-1.12, Y(1.08), 1.0), M["_emit_rgb"], 12.0)
    PT.hull(g, -0.62, 0.22, Y(0.92), Y(1.36), 0.0, 0.08, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["olive"], M["steel_dk"]], rivet_step=0.1)
    PT.capacitors(g, (-0.2, Y(1.14), 0.08), 4, 2, 0.065, 0.16, E)
    for (xx, yn) in ((-1.45, -0.7), (-0.95, -0.7), (1.45, 0.45), (0.85, -0.45)):
        PT.lamp(g, (xx, Y(yn), 0.06), (0, -0.3, 1), 0.03, E, cage=True)
    g.halo((1.12, Y(1.12), 0.4), M["_emit_rgb"], 10.0)
    g.halo((0.95, Y(-0.72), 0.6), M["_emit_rgb"], 8.0)


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : câbles torsadés sur isolateurs (en l'air : isolateurs enfilés sur le faisceau)
# ------------------------------------------------------------------------------------------------
def link(g, e, ctrl, r=0.05, kind=None):
    """Liaison d'une machine à la colonne (catalogue, rubrique « Tuyaux » de l'électricité)."""
    M = g.M
    P = F.polyline_pts(ctrl)
    PT.cable_run(g, P, 3, 0.02, 0.045, [M["rubber"], M["redcable"], M["rubber"]])
    if kind != "arch":
        for p in P[1:-1]:
            zz = p.z
            g.cyl((p.x, p.y, zz - 0.07), "z", 0.02, 0.1, M["steel_dk"], n=8, what="support")
            PT.insulators(g, (p.x, p.y, zz - 0.02), 2, 0.032, h=0.026)
    else:  # en l'air : isolateurs enfilés sur le faisceau, aucune pièce qui pend dans le vide
        for p in P[1:-1]:
            g.cyl(p, "z", 0.05, 0.03, M["accent"], n=14, style="soft", what="isolateur")
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
# Pièce du niveau 12 : 2 piles de condensateurs à éclateur coiffées d'un tore de Tesla, arc entre les pointes
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    M = g.M
    E = M["emit"]
    side = c.side
    cx = c.T["piece"]["x"]
    cy = -cx
    for sx in (-1, 1):
        xa, xb = sorted((sx * (cx - 0.3 - 0.07 * side), sx * (cx + 0.2 + 0.03 * side)))
        corps.dalle(g, xa, xb, Y(cy - 0.24 - 0.02 * side), Y(cy + 0.34 + 0.06 * side))
    for sx in (-1, 1):
        x, y = sx * cx, Y(cy)
        zt = spark_stack(g, (x, y, 0.0), E, 1.5)
        g.box((x - sx * 0.1, y, zt + 0.02), (0.12, 0.016, 0.016), E, "flat", what="arc")
    _halo(g, [(-cx, Y(cy), 0.5), (cx, Y(cy), 0.5)], 10.0)


def spark_stack(g, c, emat, s=1.0):
    """Pile de condensateurs à éclateur (électricité) : colonne d'isolateurs trapue coiffée d'un tore de Tesla."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + 0.04), "z", 0.12 * s, 0.08, M["steel_dk"], n=20, style="soft", what="embase")
    F.bolts_ring(g, (x, y, z + 0.08), (0, 0, 1), 0.1 * s, 6, M["rivet"], r=0.013)
    g.cyl((x, y, z + 0.08 + 0.07 * s), "z", 0.08 * s, 0.14 * s, M["olive"], n=18, what="condensateur")
    g.tube_shell((x, y, z + 0.12 + 0.07 * s), "z", 0.088 * s, 0.07 * s, 0.025, M["brass"], n=18, what="cerclage")
    zt = PT.insulators(g, (x, y, z + 0.08 + 0.14 * s), 4, 0.06 * s, h=0.035)
    g.torus((x, y, zt + 0.03), "z", 0.075 * s, 0.024 * s, M["copper"], n=24, m=8, what="tore")
    # âme pleine du tore (sinon le sol se voit par son trou : contrôle des trous enfermés)
    g.cyl((x, y, zt + 0.03), "z", 0.075 * s, 0.03, M["steel_dk"], n=20, what="ame_tore")
    g.cyl((x, y, zt + 0.045), "z", 0.035, 0.05, M["copper"], n=10, what="borne")
    return zt + 0.06


# ------------------------------------------------------------------------------------------------
# Arme (E1) : canon-bobine
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    M = g.M
    H = c.H
    w_coil(g, ST, H, x, sx)
    y0 = H["recv"][0]
    PT.lamp(g, (x - sx * H["wr"] * 0.25, y0 + 0.1, H["zg"] + H["hr"] + 0.03), (0, 0.4, 1), 0.026, M["emit"], cage=True)


def w_coil(g, st, H, x, sx):
    """Époque 6 : CANON-BOBINE : un tube central gainé de 5 GROSSES BOBINES de cuivre séparées par des disques
    isolateurs en céramique, bouche à anneau isolateur et 2 électrodes (arc), batterie de condensateurs."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    breech(g, st, x, y0, y1, zg - hr, zg + hr, wr)
    Ld = 0.26 + hr * 0.6
    drive(g, st, (x, y0 - Ld / 2 + 0.03, zg), hr * 0.78, Ld)
    L = H["L"]
    g.cyl((x, y1 + L / 2, zg), "y", 0.09, L, M["gun"], n=16, what="tube")
    g.box((x, y1 + L * 0.43, zg - 0.1), (0.14, L * 0.92, 0.16), M["steel_dk"], "hard", what="quille")
    PT.hull(g, x - 0.15, x + 0.15, y1 - 0.02, y1 + 0.1, zg - 0.15, zg + 0.15, ins=(0.02, 0.0, 0.02), panel=0.2,
            mats=[M["olive"], M["steel_dk"]], rivet_step=0.1)
    g.cyl((x, y1 + 0.02, zg), "y", 0.15, 0.04, M["steel_dk"], n=24, style="soft", what="plaque")
    nc = 5
    span = L * 0.82
    pitch = span / nc
    for i in range(nc):
        yc = y1 + 0.05 + pitch * (i + 0.5)
        lc = pitch * 0.72
        g.cyl((x, yc, zg), "y", 0.122, pitch, M["steel_dk"], n=24, what="noyau")
        nt = max(4, int(lc / 0.024))
        for t in range(nt):
            g.torus((x, yc - lc / 2 + lc * (t + 0.5) / nt, zg), "y", 0.126, 0.014, M["copper"], n=28, m=6,
                    what="spire")
        g.tube_shell((x, yc + pitch / 2, zg), "y", 0.15, 0.05, 0.026, M["accent"], n=24, what="isolateur")
    g.tube_shell((x, y1 + 0.05, zg), "y", 0.15, 0.05, 0.026, M["accent"], n=24, what="isolateur")
    # barres d'alimentation de cuivre le long des bobines (dessus)
    for s in (-1, 1):
        g.box((x + s * 0.06, y1 + 0.015 + span / 2, zg + 0.125), (0.026, span + 0.07, 0.03), M["copper"], "hard",
              what="barre")
    yb = y1 + L
    g.cyl((x, yb - 0.03, zg), "y", 0.09, 0.08, M["steel"], n=24, style="soft", what="bouche")
    g.tube_shell((x, yb - 0.075, zg), "y", 0.12, 0.05, 0.03, M["accent"], n=24, what="isolateur")
    g.cyl((x, yb + 0.012, zg), "y", 0.04, 0.008, M["void"], n=14, style="flat", what="ame")
    F.lit_ring(g, (x, yb + 0.014, zg), "y", 0.07, M["emit"], w=0.02)
    for s in (-1, 1):
        p0 = V((x + s * 0.09, yb - 0.02, zg + 0.03))
        g.cyl(p0 + V((0, 0.05, 0)), (0, 1, 0), 0.014, 0.12, M["copper"], n=8, what="electrode")
        F.sphere(g, p0 + V((0, 0.12, 0)), 0.022, M["copper"], n=10, m=6, what="pointe")

    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.03, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.02), panel=0.2, mats=[M[k] for k in st["gmask"]], rivet_step=0.11)
    xo = x + sx * (wr / 2 - 0.005)
    feed(g, st, H, x, sx, xo)


def breech(g, st, x, y0, y1, z0, z1, w):
    """Culasse blindée (lignée PT.receiver) ocre et kaki."""
    M = g.M
    mats = [M[k] for k in st["recv_mats"]]
    return PT.receiver(g, x, y0, y1, z0, z1, w, mats=mats)


def drive(g, st, c, r, L):
    """Organe arrière du canon : moteur à BOBINAGE de cuivre apparent (lignée)."""
    M = g.M
    x, y, z = c
    body = M[st.get("drive_mat", "steel_dk")]
    g.cyl((x, y, z), "y", r, L, body, n=28, style="soft", phase=math.pi / 8, what="moteur")
    nf = int((L * 0.5) / 0.045)
    fm = M[st.get("fin_mat", "steel_hi")]
    for kk in range(nf):
        g.tube_shell((x, y - L / 2 + 0.04 + kk * 0.045, z), "y", r + 0.026, r - 0.01, 0.014, fm, n=28, what="ailette")
    for kk in range(4):
        g.torus((x, y + L / 2 - 0.05 - kk * 0.034, z), "y", r + 0.006, 0.017, M["copper"], n=28, m=6,
                what="bobinage")
    g.cyl((x, y - L / 2 - 0.03, z), "y", r * 0.85, 0.06, M[st.get("flange_mat", "olive")], n=24, style="soft",
          what="flasque")
    F.bolts_ring(g, (x, y - L / 2 - 0.06, z), (0, -1, 0), r * 0.66, 8, M["rivet"], r=0.016)
    g.cyl((x, y - L / 2 - 0.08, z), "y", r * 0.3, 0.05, M[st["band"]], n=12, what="moyeu")


def feed(g, st, H, x, sx, xo):
    """Alimentation : tambour de la lignée et bande."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    c = (xo + sx * 0.066, y0 + 0.12, zg - 0.02)
    r = 0.13 if H["R"] < 0.5 else 0.17
    g.cyl(c, (1, 0, 0), r, 0.13, M[st.get("drum_mat", "armor2")], n=32, style="soft", what="tambour")
    for s in (-1, 1):
        g.tube_shell(V(c) + V((s * 0.055, 0, 0)), (1, 0, 0), r + 0.016, r - 0.03, 0.026, M["brass"], n=32,
                     what="flasque")
        g.cyl(V(c) + V((s * 0.075, 0, 0)), (1, 0, 0), r * 0.32, 0.03, M["brass"], n=12, what="moyeu")
    F.bolts_ring(g, V(c) + V((sx * 0.08, 0, 0)), (sx, 0, 0), r - 0.025, 8, M["rivet"], r=0.014)
    PT.belt(g, [(xo + sx * 0.08, y0 + 0.2, zg + r * 0.9), (xo, y0 + 0.3, zg + r + 0.04),
                (x + sx * wr * 0.3, y0 + 0.36, zg + hr + 0.02)], scale=0.85)


# ------------------------------------------------------------------------------------------------
# Masque, nacelle, tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=ST["gmask"], fentes=((0.0, 1.1),), visiere=("steel_dk", 0.03),
                        coax=dict(fut="gun", manchon=ST["band"], manchon_y=0.3, manchon_r=0.046, manchon_L=0.12,
                                  anneau=True))


def nacelle(g, c):
    """Tour de Tesla dorsale : pile d'isolateurs, tore de cuivre, deux piles latérales, arcs cyan."""
    M = g.M
    bx, yb0, yb1, ztop, yc = c.nac
    zt6 = PT.insulators(g, (0.0, yc, ztop), 5, 0.05, h=0.036)
    g.torus((0.0, yc, zt6 + 0.03), "z", 0.1, 0.03, M["copper"], n=28, m=8, what="tore")
    g.cyl((0.0, yc, zt6 + 0.03), "z", 0.06, 0.05, M["copper"], n=14, what="borne")
    for sx in (-1, 1):
        zs6 = PT.insulators(g, (sx * bx * 0.62, yc - 0.02, ztop), 3, 0.036, h=0.032)
        g.cyl((sx * bx * 0.62, yc - 0.02, zs6 + 0.01), "z", 0.03, 0.03, M["copper"], n=10, what="borne")
        p0 = V((sx * bx * 0.62, yc - 0.02, zs6 + 0.03))
        p1 = V((sx * 0.1, yc, zt6 + 0.03))
        g.cyl((p0 + p1) / 2, p1 - p0, 0.009, (p1 - p0).length, M["emit"], n=6, style="flat", what="arc")


def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    zs, rz = H["zs"], H["rz"]
    side = c.side
    k = KIN
    F.slits(g, R, c.rt + 0.1 + 0.02 * side, 7, M["emit"], a0=math.pi * 0.62, span=math.pi * 1.76)
    F.voyants_tete(g, H, 12)
    zt = H["zs"] + H["rz"] * 0.42
    for sx in (-1, 1):
        arch_hose(g, EPOQUE, (sx * 0.15, -R - 0.06, zt + 0.02),
                  (sx * (H["gx"] - 0.03), H["recv"][0] + 0.1, H["zg"] + H["hr"] + 0.03),
                  0.1 + 0.03 * (side - 2), 0.034 + 0.008 * (side - 2))
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

    def rad_at(z):
        t = max(0.0, min(1.0, (z - zs) / rz))
        return R * math.sqrt(max(0.0, 1 - t * t))
    # signature de coupole : ceinture de spires de cuivre, pile d'isolateurs et boule
    for t in range(6):
        z = zs + 0.03 + t * 0.032
        g.torus((0, 0, z), "z", rad_at(z) * 1.03 + 0.012, 0.016, M["copper"], n=48, m=6, what="spire")
    zt = PT.insulators(g, (R * 0.25, -R * 0.35, zs + rz * 0.9), 3, 0.05, h=0.04)
    F.sphere(g, (R * 0.25, -R * 0.35, zt + 0.06), 0.06, M["copper"], n=16, m=10, what="boule")
