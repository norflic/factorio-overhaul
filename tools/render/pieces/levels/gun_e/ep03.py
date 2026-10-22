"""Époque 3 · Vapeur (ère I, 2×2, niveaux 5 et 6). Constructeur : PLAGE BASSE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 3) : « cuivre, vapeur, manomètres ».
PORTÉ TEL QUEL de la passe 3 (gun_e_bas, commit 4c57982 : design.py, ages.py, parts4.py ; outil de portage, code d'origine mot pour
mot) sur le kit commun gun_e : seul le CORPS a changé (corps.py, kit.py). Aucune correction de design d'époque.
Emplacements remplis : arme (gatling à manchon de cuivre à ailettes, frein de laiton à évents, cylindre à vapeur à
bielle, tambour de laiton), grands volumes du socle (chaudière verticale et cheminée, machine à vapeur verticale à
volant, soute à charbon), liaisons (cuivre à brides de laiton et manomètre), nacelle (chaudière dorsale et cheminée
courte), manomètres, foyers ambre, pièce paire (2 réservoirs de vapeur).
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

EPOQUE = 3
NOM = "Vapeur"
KIN = 2   # rang dans l'ère I
FOYER = dict(rgb=(1.0, 0.753, 0.376))
CANON = dict(L=0.95, nb=4, rb=0.04, rr=0.078)
HABILLAGE = dict(jupe_cerclage="brass", tremie="castiron", pochoirs=False, munitions=("brass", "copper"),
                 grille_nacelle="copper_pol", chapeau="brass")
ST = dict(jacket="steam", brake="steam", drive="steam", band="brass", recv_mats=("castiron", "castiron"),
          jacket_f=0.72, feed="drum", drum_mat="brass", skirt="brass", appl="copper_pol", gmask=("castiron", "olive"),
          arm=("olive", "castiron"), cap="brass", col=("olive", "castiron"), nac=("castiron", "olive"))


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle : chaudière verticale et cheminée, machine à vapeur verticale à volant, soute à charbon
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    F.lamp_group(g, (x0 + 0.07, y0 - 0.03, h * 0.62), (1, 0, 0), (0, -1, 0), M["emit"], n=2)
    socle_steam(g)
    corps.collecteur(g, c, lambda g_, pts, r: link(g_, EPOQUE, pts, r))


def boiler(g, x, y, r, h, M, E, chim_h=0.5, chim_r=0.075):
    """Chaudière verticale rivetée (tôle brune rouillée et cerclages laiton de la cheminée V0), porte de foyer
    ambrée au sud, dôme de vapeur en cuivre, soupape, sifflet, niveau d'eau, grand manomètre, cheminée à
    collerette."""
    g.cyl((x, y, 0.04), "z", r + 0.06, 0.08, M["castiron"], n=28, style="soft", what="socle")
    F.bolts_ring(g, (x, y, 0.08), (0, 0, 1), r + 0.035, 12, M["rivet"], r=0.014)
    zb, zt = 0.08, h
    g.cyl((x, y, (zb + zt) / 2), "z", r, zt - zb, M["armor"], n=36, what="virole")
    for f in (0.22, 0.6, 0.95):
        zz = zb + (zt - zb) * f
        g.tube_shell((x, y, zz), "z", r + 0.022, r - 0.01, 0.04, M["brass"], n=36, what="cerclage")
    nr = int(TAU * r / 0.1)
    for f in (0.41, 0.78):
        zz = zb + (zt - zb) * f
        for k in range(nr):
            a = TAU * (k + 0.5) / nr
            d = V((math.cos(a), math.sin(a), 0))
            if d.y > 0.55:
                continue
            g.dome(V((x, y, zz)) + d * (r + 0.003), d, 0.014, M["rivet"])
    # fond bombé riveté
    P2.dome_hull(g, (x, y, zt), r, r, r * 0.35, M["armor"], M, n=32, m=6, seams=8, band_mat=M["brass"],
                 rivet_step=0.1)
    # porte de foyer (sud) : cadre de fonte, 3 fentes ambrées, loquet laiton
    d = V((0.0, -1.0, 0.0))
    c = V((x, y, 0.2)) + d * (r + 0.01)
    g.box(c, (0.2, 0.03, 0.15), M["castiron"], "soft", what="porte")
    for i in range(3):
        g.box(c + V((-0.05 + i * 0.05, -0.017, 0.0)), (0.026, 0.006, 0.09), E, "flat", what="fente_foyer")
    g.box(c + V((0.11, -0.02, 0.0)), (0.03, 0.012, 0.02), M["brass"], "hard", what="loquet")
    for s in (-1, 1):
        g.cyl(c + V((s * 0.105, 0.0, 0.0)), "z", 0.014, 0.12, M["steel_dk"], n=8, what="gond")
    # grand manomètre (cadran crème lisible), niveau d'eau
    P2.gauge(g, V((x, y, h * 0.7)) + V((-0.5, -0.85, 0)).normalized() * (r + 0.02), (-0.5, -0.85, 0.25), 0.06, M)
    p = V((x, y, h * 0.55)) + V((0.6, -0.8, 0)).normalized() * (r + 0.03)
    g.cyl(p, "z", 0.016, 0.2, M["emit_soft"], n=8, what="niveau")
    for zz in (-0.11, 0.11):
        g.cyl(p + V((0, 0, zz)), "z", 0.026, 0.03, M["brass"], n=10, what="robinet")
    # dôme de vapeur en cuivre, soupape, sifflet
    dz = zt + r * 0.3
    g.cyl((x + r * 0.35, y - r * 0.2, dz), "z", r * 0.3, r * 0.3, M["copper_pol"], n=22, what="dome_vapeur")
    P2.dome_hull(g, (x + r * 0.35, y - r * 0.2, dz + r * 0.15), r * 0.3, r * 0.3, r * 0.22, M["copper_pol"], M,
                 n=22, m=5, seams=0, band_mat=M["brass"], rivet_step=0.1)
    g.cyl((x - r * 0.4, y - r * 0.25, dz + 0.04), "z", 0.02, 0.12, M["brass"], n=10, what="soupape")
    g.box((x - r * 0.4 + 0.06, y - r * 0.25, dz + 0.1), (0.12, 0.014, 0.014), M["steel_hi"], "hard", what="levier")
    g.cyl((x - r * 0.4 + 0.12, y - r * 0.25, dz + 0.08), "z", 0.022, 0.04, M["castiron"], n=8, what="contrepoids")
    # cheminée (fût riveté, 2 cerclages laiton, collerette évasée, suie)
    cx, cy = x - r * 0.05, y + r * 0.35
    z0 = zt + r * 0.25
    g.cyl((cx, cy, z0 + 0.02), "z", chim_r * 1.45, 0.05, M["castiron"], n=20, style="soft", what="embase")
    g.cyl((cx, cy, z0 + chim_h / 2), "z", chim_r, chim_h, M["armor"], n=22, r2=chim_r * 0.94, what="cheminee")
    for f in (0.35, 0.72):
        g.tube_shell((cx, cy, z0 + chim_h * f), "z", chim_r + 0.016, chim_r - 0.01, 0.028, M["brass"], n=22,
                     what="cerclage")
    g.cyl((cx, cy, z0 + chim_h + 0.03), "z", chim_r * 0.96, 0.06, M["castiron"], n=22, r2=chim_r * 1.4, caps=False,
          what="couronne")
    g.torus((cx, cy, z0 + chim_h + 0.06), "z", chim_r * 1.4, 0.014, M["castiron"], n=22, m=6, what="bourrelet")
    g.cyl((cx, cy, z0 + chim_h + 0.03), "z", chim_r * 0.9, 0.05, M["soot"], n=18, what="suie")
    return V((x, y, zt + 0.05))


def vertical_engine(g, x, yn0, yn1, M):
    """Machine à vapeur VERTICALE (pilon) : bâti de fonte, cylindre debout sur 4 colonnes, tige et bielle vers le
    vilebrequin, GRAND VOLANT à rayons face au sud, régulateur à boules sur le cylindre."""
    y0, y1 = Y(yn0), Y(yn1)
    PT.hull(g, x - 0.19, x + 0.19, y0, y1, 0.0, 0.1, ins=(0.02, 0.02, 0.02), panel=0.26,
            mats=[M["castiron"], M["olive"]], rivet_step=0.12)
    yc = y1 - 0.2
    zc0, zc1 = 0.44, 0.68
    for sx_ in (-1, 1):
        for sy_ in (-1, 1):
            g.cyl((x + sx_ * 0.075, yc + sy_ * 0.075, (0.1 + zc0) / 2), "z", 0.02, zc0 - 0.1, M["castiron"], n=8,
                  what="colonne")
    g.cyl((x, yc, (zc0 + zc1) / 2), "z", 0.105, zc1 - zc0, M["castiron"], n=22, style="soft", what="cylindre")
    for zz in (zc0 + 0.015, zc1 - 0.015):
        g.cyl((x, yc, zz), "z", 0.125, 0.03, M["brass"], n=22, style="hard", what="bride")
        F.bolts_ring(g, (x, yc, zz + 0.016), (0, 0, 1), 0.112, 8, M["rivet"], r=0.012)
    g.box((x + 0.12, yc, (zc0 + zc1) / 2), (0.06, 0.12, 0.18), M["castiron"], "soft", what="boite_tiroir")
    g.cyl((x, yc, zc0 - 0.08), "z", 0.014, 0.16, M["steel_hi"], n=8, what="tige")
    g.box((x, yc, zc0 - 0.16), (0.07, 0.05, 0.04), M["brass"], "hard", what="crosse")
    zk = 0.24
    yw = y0 + 0.08
    g.cyl((x, (yc + yw) / 2, zk), "y", 0.022, yc - yw + 0.06, M["steel_hi"], n=10, what="vilebrequin")
    g.box((x + 0.02, yc, (zk + zc0 - 0.16) / 2), (0.022, 0.022, zc0 - 0.16 - zk), M["steel_hi"], "hard",
          what="bielle")
    for yy in (yc - 0.05, (yc + yw) / 2):
        g.box((x, yy, (0.1 + zk) / 2 + 0.01), (0.12, 0.05, zk - 0.08), M["castiron"], "hard", what="palier")
    F.disc_wheel(g, (x, yw, zk + 0.02), (0, 1, 0), 0.23, 0.05, M["castiron"], M["castiron"], spokes=6,
               hub_mat=M["brass"])
    zb = zc1 + 0.02
    g.cyl((x - 0.03, yc, zb + 0.08), "z", 0.012, 0.16, M["steel_hi"], n=8, what="axe")
    for sx_ in (-1, 1):
        F.sphere(g, (x - 0.03 + sx_ * 0.065, yc, zb + 0.09), 0.03, M["brass"], n=12, m=8, what="boule")
        g.cyl((x - 0.03 + sx_ * 0.032, yc, zb + 0.13), (sx_, 0, 0.9), 0.007, 0.08, M["steel_hi"], n=6, what="bras")
    return V((x, yc, zc1))


def socle_steam(g):
    M = g.M
    E = M["emit"]
    # est (toujours visible) : CHAUDIÈRE verticale et cheminée (style de la cheminée V0 validée)
    top = boiler(g, 0.74, Y(-0.12), 0.25, 0.58, M, E, chim_h=0.5)
    # ouest : machine à vapeur verticale, grand volant face au sud
    cyl_top = vertical_engine(g, -0.8, -0.44, 0.34, M)
    # nord-ouest : soute à charbon rivetée et pelle
    PT.hull(g, -0.98, -0.42, Y(0.46), Y(0.95), 0.0, 0.24, ins=(0.02, 0.02, 0.02), panel=0.26,
            mats=[M["castiron"], M["rawiron"]], faces="tsew", rivet_step=0.12)
    for i in range(9):
        F.lump(g, (-0.7 + 0.12 * math.cos(i * 2.4) * (1 + i % 2), Y(0.7) + 0.16 * math.sin(i * 2.4) * (0.6 + 0.3 * (i % 3)),
                 0.23), 0.05, M["basalt"], sz=0.7, n=7, m=4, what="charbon")
    g.cyl((-0.52, Y(0.6), 0.34), (0.2, -0.3, 1), 0.012, 0.3, M["wood"], n=6, what="pelle_manche")
    # nord-est : bâche alimentaire couchée (rivetée, verre de niveau), pompe à balancier
    P2.tank(g, (0.62, Y(0.66), 0.2), 0.15, 0.62, (1, 0, 0), M, paint=M["armor"], band=M["brass"], gauges=1)
    g.cyl((0.88, Y(0.36), 0.14), "z", 0.04, 0.28, M["castiron"], n=12, what="pompe")
    g.box((0.88, Y(0.36) - 0.06, 0.3), (0.02, 0.16, 0.02), M["steel_hi"], "hard", R=Matrix.Rotation(0.4, 3, "X"),
          what="balancier")
    # gros tuyaux de cuivre : chaudière -> cylindre (par le nord), chaudière -> colonne, bâche -> chaudière
    g.pipe([top + V((-0.1, 0.06, 0.04)), V((0.62, Y(0.2), 0.62)), V((0.42, Y(0.24), 0.5))], 0.042, M["copper_pol"],
           fl_mat=M["brass"], bolt_mat=M["rivet"])
    g.pipe([cyl_top + V((0.02, 0.0, 0.03)), V((-0.66, Y(0.2), 0.62)), V((-0.42, Y(0.24), 0.5))], 0.042,
           M["copper_pol"], fl_mat=M["brass"], bolt_mat=M["rivet"])
    P2.gauge(g, (0.6, Y(0.2) - 0.06, 0.66), (0, -0.6, 0.6), 0.06, M)
    P2.handwheel(g, (-0.62, Y(0.2), 0.7), (0, 0, 1), 0.06, M, mat=M["brass"])
    link(g, 3, [(0.52, Y(-0.06), 0.24), (0.46, Y(-0.04), 0.4), (0.36, Y(0.0), 0.42)], 0.05)
    link(g, 3, [(0.62, Y(0.5), 0.2), (0.7, Y(0.3), 0.32), (0.74, Y(0.12), 0.4)], 0.04)
    # échappement de la machine : tuyau calorifugé (toile cerclée de laiton) vers la colonne
    lag = [V((-0.66, Y(0.14), 0.56)), V((-0.56, Y(0.06), 0.5)), V((-0.4, Y(0.0), 0.42))]
    S_, T = g.tube(g.spline(lag, 8), 0.034, M["canvas"], n=10, what="calorifuge")
    for i in range(1, len(S_) - 1, 3):
        g.tube_shell(S_[i], T[i], 0.042, 0.03, 0.016, M["brass"], n=12, what="cerclage")
    P2.gauge(g, (-0.8, Y(-0.44) - 0.02, 0.07), (0, -1, 0.3), 0.04, M)
    P2.ladder(g, V((0.74, Y(-0.12), 0.0)) + V((1, 0.2, 0)).normalized() * 0.29, V((1, 0.2, 0)), 0.08, 0.56, 0.12, M)
    for (px_, pyn) in ((0.5, 0.3), (-0.5, 0.42)):
        g.pipe([V((px_, Y(pyn), 0.12)), V((px_ * 0.9, Y(pyn) - 0.02, 0.3)), V((px_ * 0.7, Y(pyn * 0.7), 0.4))], 0.03,
               M["copper_pol"], fl_mat=M["brass"], bolt_mat=M["rivet"])
    for (gx_, gyn, gz) in ((0.52, -0.3, 0.3), (0.92, -0.32, 0.42), (-0.62, 0.62, 0.34)):
        P2.gauge(g, (gx_, Y(gyn), gz), (0, -1, 0.4), 0.038, M)
    P2.handwheel(g, (0.5, Y(0.02), 0.5), (0, 0, 1), 0.045, M, mat=M["brass"])
    F.lamp_group(g, (0.62, Y(-0.4) - 0.02, 0.36), (1, 0, 0), (0, -1, 0), E, n=2)
    F.lamp_group(g, (-0.95, Y(-0.3), 0.12), (0, 1, 0), (-1, 0, 0), E, n=2)
    g.halo((0.74, Y(-0.4), 0.25), M["_emit_rgb"], 10.0)
    g.halo((0.74, Y(-0.12), 0.9), M["_emit_rgb"], 6.0)


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : tuyau de cuivre coudé à brides de laiton, manomètre piqué au milieu
# ------------------------------------------------------------------------------------------------
def link(g, e, ctrl, r=0.05, kind=None):
    """Liaison d'une machine à la colonne (catalogue, rubrique « Tuyaux » de la vapeur)."""
    M = g.M
    P = F.polyline_pts(ctrl)
    g.pipe(P, r * 0.85, M["copper_pol"], fl_mat=M["brass"], bolt_mat=M["rivet"])
    S_ = g.spline(P, 8)
    i = len(S_) // 2
    P2.gauge(g, S_[i] + V((0, 0, r * 0.85 + 0.03)), (0, -0.4, 1), max(0.034, r * 0.75), M)
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
# Pièce du niveau 6 : 2 réservoirs de vapeur debout (rivetés, dôme de cuivre, grand manomètre)
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
        P3.vtank(g, x, y, 0.17, 0.56, M, paint=M["rawiron"], emat=E, ladder_dir=(sx, -0.3), gauges=0)
        for zz in (0.2, 0.44):
            g.tube_shell((x, y, zz), "z", 0.194, 0.16, 0.03, M["brass"], n=32, what="cerclage")
        g.cyl((x, y, 0.56 + 0.1), "z", 0.07, 0.08, M["copper_pol"], n=18, what="dome_vapeur")
        P2.gauge(g, (x - sx * 0.04, y - 0.185, 0.34), (-sx * 0.3, -1, 0.3), 0.075, M)
        link(g, 3, [(x - sx * 0.13, y + 0.06, 0.14), (x - sx * 0.25, y + 0.2, 0.18),
                    (sx * 0.4, Y(-0.8), 0.18)], 0.034)
    _halo(g, [(-cx, Y(cy), 0.3), (cx, Y(cy), 0.3)], 8.0)


# ------------------------------------------------------------------------------------------------
# Arme (E1) : gatling à vapeur
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    M = g.M
    H = c.H
    w_steam(g, ST, H, x, sx)
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


def w_steam(g, st, H, x, sx):
    w_gatling(g, st, H, x, sx)


def gun_e(g, st, H, x, side):
    """Faisceau de la lignée (corps.rosette), jaquette et bouche de l'époque ; renvoie le rayon de jaquette."""
    M = g.M
    y1 = H["recv"][1]
    L, nb, rb, rr = H["L"], H["nb"], H["rb"], H["rr"]
    zg = H["zg"]
    rs = rr + rb + 0.028
    pos = corps.rosette(g, x, y1, zg, L, nb, rb, rr, mat=M[st.get("barrel", "gun")], collier_mat=M[st["band"]],
                        colliers=st.get("collars", (0.8,)), bouts=False)
    # la jaquette d'époque couvre près des 2/3 du faisceau : les tubes restent visibles, séparés, sur le tiers avant
    Lj = L * st.get("jacket_f", 0.62)
    jk_steam(g, st, x, y1, zg, Lj, rs, H)
    br_steam(g, st, x, y1 + L, zg, rs, pos, H)
    return rs


def jk_steam(g, st, x, y0, z, Lj, rs, H):
    """Époque 3 : manchon de cuivre à ailettes annulaires rapprochées, cerclé de laiton."""
    M = g.M
    g.cyl((x, y0 + Lj / 2, z), "y", rs - 0.006, Lj, M["copper_pol"], n=28, what="jaquette")
    n = max(6, int((Lj - 0.08) / 0.028))
    for i in range(n):
        yy = y0 + 0.05 + (Lj - 0.1) * (i + 0.5) / n
        g.tube_shell((x, yy, z), "y", rs + 0.022, rs - 0.01, 0.011, M["copper_pol"], n=28, what="ailette")
    for yy in (y0 + 0.025, y0 + Lj - 0.02):
        g.tube_shell((x, yy, z), "y", rs + 0.03, rs - 0.01, 0.04, M["brass"], n=28, what="cerclage")
        F.bolts_ring(g, (x, yy, z), (0, 1, 0), rs + 0.031, 6, M["rivet"], r=0.014, skip_down=-0.3)


def br_steam(g, st, x, yb, z, rs, pos, H):
    """Époque 3 : frein de bouche en laiton à 4 évents ronds, plus large que le faisceau."""
    M = g.M
    rb = H["rb"]
    ro = rs + 0.036
    g.tube_shell((x, yb + 0.04, z), "y", ro, H["rr"] * 0.4, 0.15, M["brass"], n=28, what="frein")
    for a in (math.pi * 0.25, math.pi * 0.75, -math.pi * 0.25, -math.pi * 0.75, math.pi * 0.5):
        d = V((math.cos(a), 0, math.sin(a)))
        g.cyl(V((x, yb + 0.05, z)) + d * (ro - 0.002), d, 0.024, 0.01, M["void"], n=10, style="flat", what="event")
    g.tube_shell((x, yb + 0.115, z), "y", ro + 0.008, ro - 0.02, 0.02, M["copper_pol"], n=28, what="levre")
    g.cyl((x, yb + 0.1, z), "y", ro - 0.012, 0.02, M["brass"], n=28, what="face")
    for s in (-1, 1):  # évents latéraux en tubulures de laiton
        g.cyl((x + s * (ro + 0.03), yb + 0.05, z), "x", 0.03, 0.07, M["brass"], n=12, what="tubulure")
        g.cyl((x + s * (ro + 0.066), yb + 0.05, z), "x", 0.02, 0.004, M["void"], n=10, style="flat", what="event")
    F.bores(g, x, yb + 0.112, z, pos, rb, M["brass"])
    F.lit_ring(g, (x, yb + 0.126, z), "y", ro - 0.002, M["emit"])


def breech(g, st, x, y0, y1, z0, z1, w):
    """Culasse blindée (lignée PT.receiver) en fonte."""
    M = g.M
    mats = [M[k] for k in st["recv_mats"]]
    return PT.receiver(g, x, y0, y1, z0, z1, w, mats=mats)


def drive(g, st, c, r, L):
    """Organe arrière du canon : CYLINDRE À VAPEUR horizontal, tige de piston, crosse et bielle apparente vers un
    plateau-manivelle, admission de cuivre, manomètre."""
    M = g.M
    x, y, z = c
    g.cyl((x, y - L * 0.1, z), "y", r, L * 0.8, M["castiron"], n=22, style="soft", what="cylindre")
    for yy in (y - L * 0.5, y + L * 0.3):
        g.tube_shell((x, yy, z), "y", r + 0.02, r - 0.01, 0.04, M["brass"], n=22, what="bride")
        F.bolts_ring(g, (x, yy, z), (0, 1, 0), r + 0.02, 8, M["rivet"], r=0.013)
    g.cyl((x, y - L * 0.55, z), "y", r * 0.7, 0.05, M["castiron"], n=18, what="fond")
    P2.gauge(g, (x + r * 0.3, y - L * 0.2, z + r + 0.005), (0.3, 0, 1), 0.04, M)
    g.cyl((x, y + L * 0.42, z), "y", 0.016, L * 0.22, M["steel_hi"], n=8, what="tige")
    g.box((x, y + L * 0.55, z), (0.06, 0.05, 0.06), M["brass"], "hard", what="crosse")
    g.box((x + r * 0.55, y + L * 0.62, z + r * 0.35), (0.022, L * 0.34, 0.022), M["steel_hi"], "hard",
          R=Matrix.Rotation(0.35, 3, "Y"), what="bielle")
    g.tube([V((x, y - L * 0.2, z + r)), V((x + r * 0.8, y - L * 0.25, z + r + 0.06)),
            V((x + r * 1.2, y - L * 0.45, z + 0.02))], 0.017, M["copper_pol"], n=8, what="admission")


def feed(g, st, H, x, sx, xo):
    """Alimentation : TAMBOUR à cartouches en laiton, bande."""
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
    corps.masque_lignee(g, c, mats=ST["gmask"], fentes=((0.0, 1.1),), visiere=("steel_dk", 0.03))


def nacelle(g, c):
    """Chaudière dorsale compacte et UNE cheminée ronde courte à collerette, à l'arrière gauche ; manomètre."""
    M = g.M
    bx, yb0, yb1, ztop, yc = c.nac
    g.cyl((0.05, yc, ztop + 0.08), "x", 0.09, bx * 1.3, M["rawiron"], n=22, what="chaudiere")
    for f in (-0.4, 0.0, 0.4):
        g.tube_shell((0.05 + f * bx * 0.65, yc, ztop + 0.08), "x", 0.102, 0.08, 0.025, M["brass"], n=22,
                     what="cerclage")
    c_ = V((0.05 + bx * 0.65 + 0.004, yc, ztop + 0.08))
    g.cyl(c_, "x", 0.05, 0.016, M["brass"], n=14, what="hublot_cadre")
    g.cyl(c_ + V((0.008, 0, 0)), "x", 0.034, 0.006, M["emit"], n=14, style="flat", what="hublot")
    chimney(g, (-bx * 0.62, yb0 + 0.08, ztop), 0.056, 0.24)
    P2.gauge(g, (bx * 0.5, yb1 - 0.02, ztop + 0.04), (0, 0.5, 1), 0.035, M)


def chimney(g, c, r, h, emat=None):
    """Cheminée ronde courte à collerette (vapeur) : fût riveté, cerclages laiton, collerette, suie."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + 0.03), "z", r * 1.35, 0.06, M["castiron"], n=20, style="soft", what="embase")
    F.bolts_ring(g, (x, y, z + 0.06), (0, 0, 1), r * 1.15, 8, M["rivet"], r=0.012)
    g.cyl((x, y, z + h / 2), "z", r, h, M["bolted"], n=20, r2=r * 0.92, what="fut")
    for f in (0.35, 0.75):
        g.tube_shell((x, y, z + h * f), "z", r + 0.014, r - 0.01, 0.025, M["brass"], n=20, what="cerclage")
    g.tube_shell((x, y, z + h + 0.01), "z", r * 1.45, r * 0.8, 0.03, M["steel_dk"], n=20, what="collerette")
    g.cyl((x, y, z + h + 0.002), "z", r * 0.8, 0.01, M["soot"], n=16, style="flat", what="suie")


def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    side = c.side
    F.voyants_tete(g, H, 4)
    zt = H["zs"] + H["rz"] * 0.42
    for sx in (-1, 1):
        arch_hose(g, EPOQUE, (sx * 0.15, -R - 0.06, zt + 0.02),
                  (sx * (H["gx"] - 0.03), H["recv"][0] + 0.1, H["zg"] + H["hr"] + 0.03),
                  0.1 + 0.03 * (side - 2), 0.034 + 0.008 * (side - 2))
    P2.gauge(g, (R * 0.3, R * 0.5, H["zs"] + H["rz"] * 0.55), (0, 0.6, 1), 0.04, M)
    appl = M[ST["appl"]]
    n1 = 6
    for i in range(n1):
        th = 0.45 + (math.pi - 0.9) * (i + 0.5) / n1
        P2.applique(g, c.Pf, c.Nf, th, 0.3, 0.22 + 0.03 * (side - 2), 0.18 + 0.03 * (side - 2), appl, M)
