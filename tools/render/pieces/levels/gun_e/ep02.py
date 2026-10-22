"""Époque 2 · Forge (ère I, 2×2, niveaux 3 et 4). Constructeur : PLAGE BASSE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 2) : « fer, boulons, bouclier ».
PORTÉ TEL QUEL de la passe 3 (gun_e_bas, commit 4c57982 : design.py, ages.py, parts4.py ; outil de portage, code d'origine mot pour
mot) sur le kit commun gun_e : seul le CORPS a changé (corps.py : plateforme de caillebotis, colonne, coupole, nacelle
et masque de la lignée ; kit.py : palette et règles de reflets communes). Aucune correction de design d'époque.
Emplacements remplis : arme (canon forgé unique par flanc, culasse à levier, manivelle, caisse cerclée et bande),
masque (bouclier courbe crénelé), grands volumes du socle (foyer de briques à hotte, soufflet, enclume, râtelier,
baquet), liaisons (fer noir à brides carrées), plaques rapportées, foyers de nuit, pièce paire (2 mantelets).
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

EPOQUE = 2
NOM = "Forge"
KIN = 1   # rang dans l'ère I (0, 1, 2) : puissance croissante dans l'ère (catalogue §A.5)
FOYER = dict(rgb=(1.0, 0.416, 0.125))
CANON = dict(L=0.85, nb=3, rb=0.046, rr=0.072)
HABILLAGE = dict(jupe_cerclage="blackiron", tremie="bolted", pochoirs=False, munitions=("brass", "rawiron"),
                 chapeau="brass")
# style d'époque de la passe 3 (emplacements E1 à E5) : noms de matières de kit.materials
ST = dict(jacket="forge", brake="crown", drive="crank", band="blackiron", recv_mats=("bolted", "rawiron"),
          recv_sig="lever", feed="crate_belt", skirt="blackiron", appl="bolted", gmask=("bolted", "rawiron"),
          arm=("bolted", "blackiron"), cap="brass", mask="shield", jacket_f=0.6, col=("bolted", "blackiron"),
          nac=("bolted", "rawiron"), arr="row", barrel="blackiron")


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle : grands volumes de l'âge (foyer de briques à hotte et conduit carré, soufflet, enclume, râtelier)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    # voyants de la trémie (petit groupe, jamais en rangée)
    F.lamp_group(g, (x0 + 0.07, y0 - 0.03, h * 0.62), (1, 0, 0), (0, -1, 0), M["emit"], n=2)
    socle_forge(g)
    # collecteur au pied de la colonne, dans la liaison de l'âge
    corps.collecteur(g, c, lambda g_, pts, r: link(g_, EPOQUE, pts, r))


def _bellows(g, x, yn0, yn1, w, M):
    """Soufflet de forge : planche basse sur tréteaux, plis de cuir en accordéon, planche haute inclinée (charnière
    côté tuyère, au nord), levier de bois, tuyère de fer vers le foyer."""
    y0, y1 = Y(yn0), Y(yn1)
    L = y1 - y0
    # contour en poire (large au sud, pointe au nord vers la tuyère) dans le repère (x local, y local depuis y0)
    out = [(-w / 2, 0.0), (w / 2, 0.0), (w * 0.5, L * 0.45), (w * 0.2, L * 0.92), (-w * 0.2, L * 0.92),
           (-w * 0.5, L * 0.45)]
    zl = 0.12

    def zu(yl, f):  # plan de la planche haute : 0,1 au nord (charnière), 0,3 au sud
        return zl + f * (0.07 + 0.2 * (1 - yl / L))

    def layer(f0, f1, k, mat, what):
        vs = [(x + px * k, y0 + py, zu(py, f0)) for px, py in out] + \
             [(x + px * k, y0 + py, zu(py, f1)) for px, py in out]
        n = len(out)
        fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
        for i in range(n):
            j = (i + 1) % n
            fs.append((i, j, n + j, n + i))
        g._add(mat, "soft", vs, fs, what)
    # tréteaux
    for f in (0.2, 0.7):
        for s in (-1, 1):
            g.box((x + s * w * 0.36, y0 + L * f, zl / 2 - 0.01), (0.04, 0.04, zl - 0.02), M["wood2"], "hard",
                  what="pied")
        g.box((x, y0 + L * f, zl - 0.03), (w * 0.86, 0.05, 0.03), M["wood"], "hard", what="traverse")
    # planche basse
    vs = [(x + px, y0 + py, zl - 0.03) for px, py in out] + [(x + px, y0 + py, zl) for px, py in out]
    n = len(out)
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    g._add(M["wood"], "hard", vs, fs, "planche")
    # plis de cuir (accordéon : alternance large / rentré)
    nf = 6
    for k in range(nf):
        layer(k / nf, (k + 1) / nf, 1.0 if k % 2 == 0 else 0.86, M["leather"], "pli")
    # planche haute (bois, ferrures)
    layer(1.0, 1.0, 1.0, M["wood"], "planche_haute")
    vs = [(x + px * 1.02, y0 + py, zu(py, 1.0)) for px, py in out] + \
         [(x + px * 1.02, y0 + py, zu(py, 1.0) + 0.03) for px, py in out]
    g._add(M["wood"], "hard", vs, fs, "planche_haute")
    for f in (0.18, 0.46, 0.74):
        yy = y0 + L * f
        g.box((x, yy, zu(L * f, 1.0) + 0.036), (w * (0.96 if f < 0.5 else 0.9), 0.04, 0.012), M["rawiron"], "hard",
              R=Matrix.Rotation(math.atan2(0.2, L), 3, "X"), what="ferrure")
        for s in (-1, 1):
            g.dome((x + s * w * 0.36, yy, zu(L * f, 1.0) + 0.044), (0, 0, 1), 0.015, M["rivet"])
    # levier : perche de bois du bout sud vers le haut, poignée transversale
    p0 = V((x, y0 + 0.04, zu(0.04, 1.0) + 0.03))
    p1 = V((x - 0.03, y0 - 0.08, zu(0.04, 1.0) + 0.05))
    g.cyl(p0, (1, 0, 0), 0.026, 0.06, M["rawiron"], n=10, what="charniere")
    # tuyère de fer au nord
    tip = V((x, y0 + L * 0.92, zl + 0.08))
    g.cyl(tip + V((0, 0.07, 0)), (0, 1, 0), 0.06, 0.14, M["rawiron"], n=12, r2=0.032, style="soft", what="tuyere")
    return tip + V((0, 0.14, 0))


def _hearth(g, x0, x1, yn0, yn1, h, M, E, flue=0.2):
    """Foyer de forge en briques : cornières de fer, bac à charbon rougeoyant (la nuit), hotte en tronc de pyramide
    sur 4 poteaux, conduit CARRÉ (pas de cheminée ronde : elle appartient à la vapeur)."""
    y0, y1 = Y(yn0), Y(yn1)
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, h / 2), (x1 - x0, y1 - y0, h), M["seam"], "flat", what="massif")
    B = [V((x0, y0, 0.0)), V((x1, y0, 0.0)), V((x1, y1, 0.0)), V((x0, y1, 0.0))]
    T = [V((x0, y0, h)), V((x1, y0, h)), V((x1, y1, h)), V((x0, y1, h))]
    for q in ([B[0], B[1], T[1], T[0]], [B[1], B[2], T[2], T[1]], [B[3], B[0], T[0], T[3]]):
        F.courses(g, q, [M["brick"], M["brick2"], M["brick"]])
    # margelle de briques posées à plat, bac à charbon au centre
    rim = 0.09
    for (a, b, c, d) in ((x0, x1, y0, y0 + rim), (x0, x1, y1 - rim, y1), (x0, x0 + rim, y0, y1), (x1 - rim, x1, y0, y1)):
        F.courses(g, [V((a, c, h)), V((b, c, h)), V((b, d, h)), V((a, d, h))], [M["brick2"], M["brick"]],
                bw=0.13, bh=0.065)
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, h - 0.01), (x1 - x0 - 2 * rim, y1 - y0 - 2 * rim, 0.02), M["void"], "flat",
          what="bac")
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    for i in range(9):
        a = TAU * i / 9 + 0.3
        rr = 0.06 + 0.05 * (i % 3) / 2
        F.lump(g, (cx + math.cos(a) * rr * 1.4, cy + math.sin(a) * rr * 1.6, h + 0.005), 0.032, M["basalt"], sz=0.7,
             n=7, m=4, what="charbon")
    for i in range(3):
        g.box((cx - 0.06 + i * 0.06, cy + (i - 1) * 0.05, h + 0.004), (0.035, 0.03, 0.01), E, "flat", what="braise")
    # cornières de fer aux arêtes verticales, ceinture boulonnée
    for (px, py) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1)):
        g.box((px, py, h / 2), (0.04, 0.04, h + 0.01), M["rawiron"], "hard", what="corniere")
    for zz in (0.07, h - 0.05):
        g.box(((x0 + x1) / 2, y0 - 0.008, zz), (x1 - x0 + 0.02, 0.016, 0.035), M["rawiron"], "hard", what="ceinture")
        for k in range(4):
            g.dome((x0 + (x1 - x0) * (k + 0.5) / 4, y0 - 0.018, zz), (0, -1, 0), 0.015, M["rivet"])
    # hotte sur 4 poteaux, conduit carré
    zh0, zh1 = h + 0.15, h + 0.32
    ins = 0.05
    for (px, py) in ((x0 + ins, y0 + ins), (x1 - ins, y0 + ins), (x1 - ins, y1 - ins), (x0 + ins, y1 - ins)):
        g.cyl((px, py, (h + zh0) / 2 + 0.005), "z", 0.018, zh0 - h + 0.01, M["blackiron"], n=8, what="poteau")
    T2 = PT.hull(g, x0 + 0.02, x1 - 0.02, y0 + 0.02, y1 - 0.02, zh0, zh1, ins=((x1 - x0) * 0.3, (y1 - y0) * 0.3,
                 (y1 - y0) * 0.3), panel=0.22, mats=[M["rawiron"], M["blackiron"]], rivet_step=0.1)
    g.box((cx, cy, zh0 + 0.015), (x1 - x0 + 0.01, y1 - y0 + 0.01, 0.03), M["blackiron"], "hard", what="rebord")
    fw = 0.13
    PT.hull(g, cx - fw / 2, cx + fw / 2, cy - fw / 2, cy + fw / 2, zh1 - 0.01, zh1 + flue, ins=(0.0, 0.0, 0.0),
            panel=0.2, mats=[M["blackiron"], M["rawiron"]], faces="tsew", rivet_step=0.1)
    for zz in (zh1 + flue * 0.45, zh1 + flue * 0.85):
        g.box((cx, cy, zz), (fw + 0.025, fw + 0.025, 0.03), M["rawiron"], "hard", what="frette")
    g.box((cx, cy, zh1 + flue + 0.01), (fw + 0.05, fw + 0.05, 0.03), M["rawiron"], "hard", what="chapeau")
    g.box((cx, cy, zh1 + flue + 0.026), (fw - 0.03, fw - 0.03, 0.006), M["soot"], "flat", what="suie")
    return (cx, y0, 0.1)


def _anvil(g, x, yn, M, k=1.0):
    """Enclume sur billot cerclé, marteau posé (k : échelle)."""
    y = Y(yn)
    g.cyl((x, y, 0.1 * k), "z", 0.15 * k, 0.2 * k, M["wood"], n=14, style="soft", what="billot")
    g.tube_shell((x, y, 0.16 * k), "z", 0.15 * k + 0.012, 0.13 * k, 0.03, M["rawiron"], n=24, what="cercle")
    z = 0.2 * k
    g.box((x, y, z + 0.03 * k), (0.2 * k, 0.15 * k, 0.06 * k), M["blackiron"], "soft", what="semelle")
    g.box((x, y, z + 0.08 * k), (0.12 * k, 0.09 * k, 0.05 * k), M["blackiron"], "soft", what="taille")
    g.box((x - 0.01 * k, y, z + 0.13 * k), (0.26 * k, 0.12 * k, 0.06 * k), M["blackiron"], "soft", what="table")
    g.box((x - 0.01 * k, y, z + 0.163 * k), (0.24 * k, 0.1 * k, 0.008), M["steel_hi"], "flat", what="face")
    g.cyl((x + 0.18 * k, y, z + 0.135 * k), (1, 0, 0), 0.05 * k, 0.14 * k, M["blackiron"], n=12, r2=0.008,
          style="soft", what="bigorne")
    g.box((x - 0.07 * k, y, z + 0.167 * k), (0.025, 0.025, 0.004), M["void"], "flat", what="trou")
    g.box((x + 0.02 * k, y - 0.02 * k, z + 0.185 * k), (0.08 * k, 0.04 * k, 0.035 * k), M["steel"], "hard",
          what="marteau")
    g.cyl((x - 0.06 * k, y - 0.09 * k, z + 0.18 * k), (-0.8, -0.6, 0.0), 0.012, 0.2 * k, M["wood"], n=6, what="manche")


def plate_rack(g, x, yn, M):
    """Râtelier en A de plaques de blindage forgées, debout (pièce haute, lisible au-dessus de la tête)."""
    y = Y(yn)
    for s in (-1, 1):
        g.box((x + s * 0.16, y + 0.04, 0.25), (0.04, 0.04, 0.5), M["wood2"], "hard", R=Matrix.Rotation(0.22, 3, "X"),
              what="montant")
    g.box((x, y - 0.1, 0.03), (0.42, 0.24, 0.06), M["wood2"], "hard", what="semelle")
    for i in range(3):
        g.box((x + 0.01 * i, y - 0.06 + i * 0.045, 0.26), (0.34 - 0.03 * i, 0.03, 0.46 - 0.04 * i),
              M["bolted"] if i % 2 else M["rawiron"], "soft", R=Matrix.Rotation(0.22, 3, "X"), what="plaque_forgee")
        for sx_ in (-1, 1):
            for zz in (0.12, 0.38):
                g.dome((x + 0.01 * i + sx_ * (0.13 - 0.015 * i), y - 0.077 + i * 0.045 + (zz - 0.26) * 0.22,
                        zz - 0.02 * i), (0, -1, 0.22), 0.015, M["rivet"])


def socle_forge(g):
    M = g.M
    E = M["emit"]
    # ouest (toujours visible, à toutes les poses) : FOYER de briques, hotte et conduit carré haut
    _hearth(g, -0.99, -0.55, -0.46, 0.34, 0.32, M, E, flue=0.36)
    # nord-ouest : soufflet de cuir, tuyère au sud dans le foyer
    g.push((-0.74, Y(0.66), 0.0), rz=math.pi)
    tip = _bellows(g, 0.0, -0.3, 0.3, 0.42, M)
    g.pop()
    # est : enclume sur billot (grande, face d'acier claire), baquet de trempe ; nord-est : râtelier de plaques
    _anvil(g, 0.76, -0.02, M, k=1.3)
    g.box((0.72, Y(-0.02) - 0.03, 0.485), (0.12, 0.05, 0.02), E, "flat", what="lingot")
    for xx in (-0.9, -0.64):
        g.box((xx, Y(-0.46) - 0.024, 0.16), (0.08, 0.01, 0.065), E, "flat", what="gueule")
        g.box((xx, Y(-0.46) - 0.03, 0.2), (0.11, 0.025, 0.02), M["rawiron"], "hard", what="linteau")
    F.stave_barrel(g, (0.8, Y(-0.4), 0.0), 0.14, 0.2, M["wood"], M["rawiron"], open_top=M["glass_dk"])
    g.cyl((0.76, Y(-0.4), 0.24), (0.3, 0.2, 1), 0.01, 0.16, M["rawiron"], n=6, what="tenaille")
    plate_rack(g, 0.62, 0.66, M)
    # lanterne de nuit sur le foyer
    F.lantern(g, (0.58, Y(-0.22), 0.0), E)
    g.halo((-0.77, Y(-0.06), 0.5), M["_emit_rgb"], 10.0)
    g.halo((0.58, Y(-0.22), 0.15), M["_emit_rgb"], 6.0)


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : tuyau de fer noir à brides CARRÉES à 4 boulons (aucun cuivre)
# ------------------------------------------------------------------------------------------------
def link(g, e, ctrl, r=0.05, kind=None):
    """Liaison d'une machine à la colonne (catalogue, rubrique « Tuyaux » de la forge)."""
    M = g.M
    P = F.polyline_pts(ctrl)
    S_ = g.spline(P, 8)
    S_, T = g.tube(S_, r * 0.8, M["blackiron"], n=12, what="tuyau")
    for i in (0, len(S_) // 2, len(S_) - 1):
        Rr = F.Ry(T[i])
        g.box(S_[i], (r * 2.6, 0.03, r * 2.6), M["rawiron"], "hard", R=Rr, what="bride")
        for sx_ in (-1, 1):
            for sz_ in (-1, 1):
                g.dome(S_[i] + Rr @ V((sx_ * r * 0.9, 0.016, sz_ * r * 0.9)), T[i], 0.014, M["brass"])
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
# Pièce du niveau 4 : 2 mantelets d'acier appuyés chacun contre une pile de 2 caisses cerclées
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    M = g.M
    side = c.side
    cx = c.T["piece"]["x"]
    cy = -cx
    # dalle sous chaque pièce, raccordée à la plateforme : aucun jour enfermé entre la pièce, les caisses et la trémie
    for sx in (-1, 1):
        xa, xb = sorted((sx * (cx - 0.3 - 0.07 * side), sx * (cx + 0.2 + 0.03 * side)))
        corps.dalle(g, xa, xb, Y(cy - 0.24 - 0.02 * side), Y(cy + 0.34 + 0.06 * side))
    for sx in (-1, 1):
        with at(g, sx * (cx + 0.06), cy - 0.08, sx * -0.4):
            PT.crate(g, (0.0, 0.2, 0.0), (0.36, 0.26, 0.18), mat=M["wood"])
            PT.crate(g, (0.01, 0.2, 0.185), (0.3, 0.22, 0.15), mat=M["wood2"])
            mantlet(g, (0.0, -0.04, 0.0), 0.0, w=0.54, h=0.4)
    _halo(g, [(-cx, Y(cy), 0.3), (cx, Y(cy), 0.3)], 6.0)


def mantlet(g, c, rz, w=0.36, h=0.28):
    """Mantelet d'acier (forge) : bouclier plat sur pieds, riveté, à créneau de visée, appuyé contre 2 caisses."""
    M = g.M
    g.push(c, rz=rz)
    t = 0.04
    PT.hull(g, -w / 2, w / 2, -t / 2, t / 2, 0.0, h, ins=(0.0, 0.0, 0.0), panel=0.2, mats=[M["bolted"], M["rawiron"]],
            faces="tsn", rivet_step=0.1)
    g.box((0, -t / 2 - 0.004, h * 0.72), (0.07, 0.01, 0.04), M["void"], "flat", what="creneau")
    for s in (-1, 1):
        g.box((s * w * 0.36, t / 2 + 0.07, h * 0.3), (0.03, 0.16, 0.025), M["blackiron"], "hard",
              R=Matrix.Rotation(0.75, 3, "X"), what="bequille")
        g.box((s * w * 0.36, t / 2 + 0.13, 0.015), (0.06, 0.06, 0.03), M["blackiron"], "hard", what="semelle")
    g.box((0, -t / 2 - 0.01, h - 0.02), (w + 0.02, 0.02, 0.035), M["rawiron"], "hard", what="rebord")
    g.pop()


# ------------------------------------------------------------------------------------------------
# Arme (E1) : UN canon forgé par flanc
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    w_forge(g, ST, c.H, x, sx)


def w_forge(g, st, H, x, sx):
    """Époque 2 : UN gros canon d'acier forgé par flanc (pas de faisceau) : fût conique, frettes boulonnées, renfort
    de culasse, bourrelet de bouche, frein hydraulique sous le fût ; culasse carrée rivetée à levier."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    breech(g, st, x, y0, y1, zg - hr, zg + hr, wr)
    Ld = 0.26 + hr * 0.6
    drive(g, st, (x, y0 - Ld / 2 + 0.03, zg), hr * 0.78, Ld)
    L = H["L"]
    r0, r1 = 0.088, 0.066
    g.cyl((x, y1 + L / 2, zg), "y", r0, L, M["steel"], n=28, r2=r1, what="fut")
    # renfort de culasse (manchon épais à 8 boulons)
    g.tube_shell((x, y1 + 0.07, zg), "y", r0 + 0.03, r0 - 0.02, 0.14, M["rawiron"], n=28, what="renfort")
    F.bolts_ring(g, (x, y1 + 0.145, zg), (0, 1, 0), r0 + 0.012, 8, M["brass"], r=0.015)
    # frettes boulonnées
    for f in (0.36, 0.6):
        rr = r0 + (r1 - r0) * f
        g.tube_shell((x, y1 + L * f, zg), "y", rr + 0.022, rr - 0.01, 0.045, M["rawiron"], n=28, what="frette")
        F.bolts_ring(g, (x, y1 + L * f, zg), (0, 1, 0), rr + 0.023, 4, M["brass"], r=0.014, phase=0.785,
                      skip_down=-0.2)
    # bourrelet et couronne de bouche, âme noire, pourtour éclairé (la nuit)
    yb = y1 + L
    g.cyl((x, yb - 0.04, zg), "y", r1 + 0.04, 0.08, M["blackiron"], n=28, style="soft", what="bourrelet")
    # oreilles de bouche : en pose N, le bout du canon fait un « T » horizontal, jamais un chapeau de cheminée
    F.ears(g, x, yb - 0.04, zg, r1 + 0.06, 0.08, r1 * 1.3, M["rawiron"], vent=False)
    g.tube_shell((x, yb + 0.004, zg), "y", r1 + 0.03, r1 - 0.025, 0.02, M["rawiron"], n=28, what="couronne")
    g.cyl((x, yb + 0.006, zg), "y", r1 - 0.026, 0.01, M["void"], n=18, style="flat", what="ame")
    F.lit_ring(g, (x, yb + 0.016, zg), "y", r1 - 0.004, M["emit"], w=0.018)
    for k in range(4):
        a = 0.785 + TAU * k / 4
        g.bolt(V((x, yb + 0.012, zg)) + V((math.cos(a), 0, math.sin(a))) * (r1 + 0.012), (0, 1, 0), 0.012,
               M["steel_hi"])
    # frein hydraulique sous le fût (cylindre et collier avant)
    zr = zg - r0 - 0.035
    g.cyl((x, y1 + 0.2, zr), "y", 0.035, 0.38, M["blackiron"], n=14, what="frein_recul")
    g.box((x, y1 + 0.36, (zr + zg) / 2 - 0.01), (0.05, 0.04, r0 + 0.02), M["rawiron"], "hard", what="collier")
    # masque de canon : plaque de fer forgé rivetée
    PT.hull(g, x - wr * 0.75, x + wr * 0.75, y1 - 0.04, y1 + 0.06, zg - hr * 1.3, zg + hr * 1.4, ins=(0.02, 0.01, 0.03),
            panel=0.2, mats=[M["bolted"], M["rawiron"]], rivet_step=0.1)
    xo = x + sx * (wr / 2 - 0.005)
    feed(g, st, H, x, sx, xo)


def breech(g, st, x, y0, y1, z0, z1, w):
    """Culasse blindée (lignée PT.receiver) habillée par l'époque : levier d'armement à pommeau de laiton."""
    M = g.M
    mats = [M[k] for k in st["recv_mats"]]
    T = PT.receiver(g, x, y0, y1, z0, z1, w, mats=mats)
    g.box((x + w * 0.52, (y0 + y1) / 2 - 0.08, (z0 + z1) / 2), (0.02, 0.2, 0.02), M["blackiron"], "hard",
          R=Matrix.Rotation(0.5, 3, "X"), what="levier")
    g.cyl((x + w * 0.52, (y0 + y1) / 2 - 0.16, z1 + 0.03), "x", 0.02, 0.04, M["brass"], n=8, what="pommeau")
    return T


def drive(g, st, c, r, L):
    """Organe arrière du canon : MANIVELLE (carter de fer noirci à nervures, flasque, bras et poignée de laiton)."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z), "y", r, L, M["blackiron"], n=20, style="soft", what="carter")
    for k in range(3):
        g.tube_shell((x, y - L / 2 + 0.04 + k * (L - 0.08) / 2, z), "y", r + 0.015, r - 0.01, 0.025,
                     M["rawiron"], n=20, what="nervure")
    g.cyl((x, y - L / 2 - 0.025, z), "y", r * 0.8, 0.05, M["rawiron"], n=20, style="soft", what="flasque")
    F.bolts_ring(g, (x, y - L / 2 - 0.05, z), (0, -1, 0), r * 0.6, 6, M["brass"], r=0.015)
    # manivelle : bras, poignée laiton
    g.box((x, y - L / 2 - 0.07, z - r * 0.4), (0.03, 0.02, r * 1.2), M["blackiron"], "hard", what="bras")
    g.cyl((x + 0.04, y - L / 2 - 0.07, z - r), "x", 0.016, 0.09, M["brass"], n=8, what="poignee")


def feed(g, st, H, x, sx, xo):
    """Alimentation : caisse cerclée de fer posée sur le bras, bande de cartouches laiton."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    c = V((xo + sx * 0.08, y0 + 0.12, zg - hr * 0.6))
    PT.crate(g, tuple(c), (0.16, 0.2, 0.14), mat=M["wood"])
    PT.belt(g, [(xo + sx * 0.08, y0 + 0.16, zg - hr * 0.6 + 0.16), (xo, y0 + 0.24, zg + 0.1),
                (x + sx * wr * 0.3, y0 + 0.3, zg + hr + 0.02)], scale=0.8)


# ------------------------------------------------------------------------------------------------
# Masque (remplace celui de la lignée) : BOUCLIER COURBE CRÉNELÉ
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    """Bouclier courbe crénelé qui enveloppe l'avant de la coupole entre les deux canons, incliné vers l'extérieur (sa
    face rivetée se voit d'en haut à toutes les poses), merlons d'acier, fentes de visée, console annulaire rivetée qui
    le relie à la jupe (aucune pièce qui flotte)."""
    M = g.M
    H = c.H
    R, zs, rz = H["R"], H["zs"], H["rz"]
    Rs = R + 0.1
    z0s, z1s = zs - 0.24, zs + rz + 0.1
    half = math.asin(min(0.98, (H["gx"] - H["wr"] * 0.6) / Rs))
    n = 9
    segw = 2 * Rs * math.sin(half / n) * 1.04
    for i in range(n):
        a = math.pi / 2 - half + 2 * half * (i + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0.0))
        t = V((-math.sin(a), math.cos(a), 0.0))
        R3 = Matrix((t, d, V((0, 0, 1)))).transposed() @ Matrix.Rotation(-0.32, 3, "X")
        c_ = d * Rs + V((0, 0, (z0s + z1s) / 2))
        g.box(c_, (segw, 0.04, z1s - z0s), M["steel"] if i % 2 else M["bolted"], "hard", R=R3, what="bouclier")
        for zz in (0.42,):
            for s_ in (-1, 1):
                g.dome(c_ + R3 @ V((s_ * segw * 0.32, 0.022, (zz - 0.5) * (z1s - z0s) * 1.6)), R3 @ V((0, 1, 0)),
                       0.016, M["rivet"])
        if i % 2 == 0:
            g.box(c_ + R3 @ V((0, 0.0, (z1s - z0s) / 2 + 0.045)), (segw * 0.8, 0.044, 0.09), M["rawiron"], "hard",
                  R=R3, what="merlon")
        if i in (2, 6):
            g.box(c_ + R3 @ V((0, 0.022, (z1s - z0s) * 0.22)), (segw * 0.5, 0.008, 0.028), M["void"], "flat", R=R3,
                  what="visee")
    # rebord haut et console annulaire (jupe -> bouclier)
    for i in range(n):
        a = math.pi / 2 - half + 2 * half * (i + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0.0))
        t = V((-math.sin(a), math.cos(a), 0.0))
        R3 = Matrix((t, d, V((0, 0, 1)))).transposed()
        g.box(d * (R + Rs) / 2 + V((0, 0, z0s + 0.02)), (segw * 1.05, Rs - R + 0.06, 0.05), M["blackiron"], "hard",
              R=R3, what="console")
        g.dome(d * ((R + Rs) / 2) + V((0, 0, z0s + 0.05)), (0, 0, 1), 0.015, M["brass"])


# ------------------------------------------------------------------------------------------------
# Tête : liaisons en arc, plaques rapportées
# ------------------------------------------------------------------------------------------------
def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    side = c.side
    # liaisons de la tête (nacelle -> canons) : elles passent EN ARC au-dessus de la tête
    zt = H["zs"] + H["rz"] * 0.42
    for sx in (-1, 1):
        arch_hose(g, EPOQUE, (sx * 0.15, -R - 0.06, zt + 0.02),
                  (sx * (H["gx"] - 0.03), H["recv"][0] + 0.1, H["zg"] + H["hr"] + 0.03),
                  0.1 + 0.03 * (side - 2), 0.034 + 0.008 * (side - 2))
    # plaques rapportées de la coupole (ère I : moins de pièces, plus grosses)
    appl = M[ST["appl"]]
    n1 = 2
    for i in range(n1):
        th = 0.45 + (math.pi - 0.9) * (i + 0.5) / n1
        P2.applique(g, c.Pf, c.Nf, th, 0.3, 0.22 + 0.03 * (side - 2), 0.18 + 0.03 * (side - 2), appl, M)
