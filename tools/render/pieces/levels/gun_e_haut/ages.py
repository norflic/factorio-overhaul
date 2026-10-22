"""Grands volumes d'époque (lot V3-E, troisième passe du 22/10, 19 h 05), époques 10 à 15. S'exécute DANS Blender.

Pourquoi ce module : la deuxième passe changeait surtout la COULEUR des petits foyers et la texture des jaquettes ;
au zoom 1, les époques de même taille gardaient le même corps, la même disposition et les mêmes grands volumes
(orchestrateur, 19 h 00). Exigence (c) : entre deux époques voisines de même taille, au moins 25 % de la surface
visible doit changer de FORME. On garde la plateforme, la colonne, la couronne, la trémie, les caisses, les armoires,
la jupe, la coupole, la nacelle et les tourelles secondaires (la lignée) ; on change de FORME, par époque :
  - le sommet de la coupole (dome_top) : 10 radar à antenne-réseau, 11 dérive et plaques anguleuses, 12 dewars
    cryogéniques, 13 chambre de confinement sphérique, 14 grande parabole dorée, 15 couronne au-dessus de la tête ;
  - les réservoirs de l'est (east) : 10 caisson caréné, 11 réservoirs-fusées à ogive et ailerons, 12 portique à
    grands anneaux magnétiques, 13 sphères de confinement, 14 sphères dorées et parabole, 15 réservoirs ciselés ;
  - le groupe de l'ouest (west) : 10 groupe sous carénage, 11 turbine de titane, 12 compresseurs cryogéniques,
    13 banc d'injecteurs, 14 batterie dorée et panneaux, 15 groupe électrogène du témoin n29.
Les petites pièces gardent la taille absolue de la lignée (rivets 0,012 à 0,016, pas de 0,11 à 0,13).
Aucune pièce ne flotte : tout repose sur le tablier ou sur un support visible.
"""
import math

from mathutils import Matrix, Vector

import armes as A
import parts as PT
import parts2 as P2
import parts3 as P3
from kit import SQ2, TAU

V = Vector


def Y(yn):
    return yn * SQ2


def _octz(hx, hy, c):
    """Octogone dans le plan xy (section horizontale d'un caisson chanfreiné)."""
    return [(-hx + c, -hy), (hx - c, -hy), (hx, -hy + c), (hx, hy - c), (hx - c, hy), (-hx + c, hy), (-hx, hy - c),
            (-hx, -hy + c)]


def loft_z(g, cx, cy, secs, mat, style="soft", what="carenage"):
    """Volume balayé le long de z : secs = [(z, poly xy)] (même nombre de sommets), bouts fermés."""
    n = len(secs[0][1])
    vs = []
    for z, poly in secs:
        vs += [(cx + u, cy + w, z) for u, w in poly]
    fs = [tuple(range(n))[::-1]]
    m = len(secs)
    for s in range(m - 1):
        for i in range(n):
            j = (i + 1) % n
            fs.append((s * n + i, s * n + j, (s + 1) * n + j, (s + 1) * n + i))
    fs.append(tuple(range((m - 1) * n, m * n)))
    g._add(mat, style, vs, fs, what)


def _sc(poly, s):
    return [(u * s, w * s) for u, w in poly]


def hatches(g, p0, p1, n, nrm, mat, size=(0.09, 0.07), t=0.014, frame=None):
    """Petites trappes rapportées (pièces lisibles au zoom 2, 4 à 60 px) le long d'un segment, sur une face de
    normale nrm ; cadre sombre facultatif."""
    M = g.M
    p0, p1 = V(p0), V(p1)
    a = V(nrm).normalized()
    al = (p1 - p0).normalized()
    Rr = Matrix((al, a.cross(al).normalized(), a)).transposed()
    for i in range(n):
        q = p0.lerp(p1, (i + 0.5) / n)
        if frame is not None:
            g.box(q + a * (t * 0.5), (size[0] + 0.03, size[1] + 0.03, t), frame, "hard", R=Rr, what="cadre_trappe")
        g.box(q + a * (t * 1.2), (size[0], size[1], t), mat, "hard", R=Rr, what="trappe")


def plinth(g, x0, x1, y0, y1, h):
    M = g.M
    PT.hull(g, x0, x1, y0, y1, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.3, mats=[M["steel_dk"], M["olive"]],
            rivet_step=0.12)


# ------------------------------------------------------------------------------------------------
# Caisson caréné (époque 10) : gris clair patiné, arêtes chanfreinées, grilles d'aération, nappes de câbles
# ------------------------------------------------------------------------------------------------
def faired_box(g, x0, x1, y0, y1, h, louvers=3, cables=True):
    M = g.M
    E = M["emit"]
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2, (y1 - y0) / 2
    c = min(hx, hy) * 0.3
    plinth(g, x0 - 0.04, x1 + 0.04, y0 - 0.04, y1 + 0.04, 0.08)
    loft_z(g, cx, cy, [(0.08, _octz(hx, hy, c)), (h * 0.72, _octz(hx, hy, c)), (h, _octz(hx - 0.1, hy - 0.1, c))],
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
        A.ribbon(g, [(cx + hx * 0.52, y0 + 0.1, h + 0.04), (cx + hx * 0.52, y1 - 0.1, h + 0.04)], 0.05, M["cable_a"])
        A.ribbon(g, [(cx + hx * 0.6, y0 + 0.1, h + 0.041), (cx + hx * 0.6, y1 - 0.1, h + 0.041)], 0.04, M["cable_b"])
    # voyants par groupes, petit écran, face sud
    P3.lamp_group(g, (cx - hx * 0.6, y0 - 0.005, h * 0.55), (1, 0, 0), (0, -1, 0), E, M, n=3)
    P3.screen(g, (cx + hx * 0.35, y0 - 0.005, h * 0.5), (0, -1, 0), 0.14, 0.08, M, E)
    return (cx, cy, h)


# ------------------------------------------------------------------------------------------------
# Réservoir-fusée (époque 11) : virole de titane, ogive, 4 ailerons d'alliage clair, chenillard
# ------------------------------------------------------------------------------------------------
def rocket_tank(g, x, y, r, h):
    M = g.M
    E = M["emit"]
    g.cyl((x, y, 0.05), "z", r + 0.08, 0.1, M["steel_dk"], n=32, style="soft", what="socle")
    nb = int(TAU * (r + 0.05) / 0.12)
    for k in range(nb):
        a = TAU * k / nb
        g.bolt((x + (r + 0.05) * math.cos(a), y + (r + 0.05) * math.sin(a), 0.1), (0, 0, 1), 0.016, M["steel_hi"])
    hexr = [(math.cos(TAU * i / 8 + TAU / 16), math.sin(TAU * i / 8 + TAU / 16)) for i in range(8)]
    loft_z(g, x, y, [(0.1, _sc(hexr, r)), (h, _sc(hexr, r)), (h + r * 1.1, _sc(hexr, r * 0.3)),
                     (h + r * 1.35, _sc(hexr, 0.04))], M["jacket"], "hard", "ogive")
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
        hatches(g, V((x, y, 0.42)) + d * (r * 0.93), V((x, y, 0.62)) + d * (r * 0.93), 2, d, M["matte"],
                size=(0.06, 0.07), frame=M["ring"])
    for a in (-0.7, -1.3, -1.9, -2.5):
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((x, y, 0.105)) + d * (r + 0.07), (0.07, 0.07, 0.014), M["steel_hi"], "hard", R=Matrix.Rotation(a, 3, "Z"),
              what="trappe")
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        d = V((math.cos(a), math.sin(a), 0))
        hatches(g, V((x, y, h + r * 0.35)) + d * (r * 0.78), V((x, y, h + r * 0.45)) + d * (r * 0.72), 1,
                (d.x * 0.8, d.y * 0.8, 0.6), M["steel_dk"], size=(0.05, 0.05))
    for k, a in enumerate((-1.3, -1.75)):
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((x, y, h * 0.45 + 0.08 * k)) + d * (r + 0.01), (0.09, 0.02, 0.03), E, "flat",
              R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="chenillard")


# ------------------------------------------------------------------------------------------------
# Portique à grands anneaux magnétiques (époque 12)
# ------------------------------------------------------------------------------------------------
def ring_gantry(g, x, y0, y1, R, zc):
    """Âme noire couchée le long de y, 3 GRANDS anneaux chromés debout (rayon R), tenus par des pinces et un berceau ;
    givre aux joints ; segments cyan. Aucun anneau ne flotte : chaque anneau repose sur un berceau boulonné."""
    M = g.M
    E = M["emit"]
    L = y1 - y0
    plinth(g, x - R * 0.85, x + R * 0.85, y0 - 0.05, y1 + 0.05, 0.1)
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
        for d in A._ring_dirs(4, math.pi / 4, -2):
            g.box(V((x, yy, zc)) + d * (R * 0.55), (0.05, 0.07, R * 0.42), M["steel_dk"], "hard", R=A._Rax(d),
                  what="entretoise")
        for d in A._ring_dirs(3, 0.5, -0.3):
            g.box(V((x, yy - 0.068, zc)) + d * (R * 0.87), (0.07, 0.004, 0.024), E, "flat", R=A._Rax(d),
                  what="segment_lum")
        g.box((x - R * 0.5, yy + 0.07, zc + R * 0.75), (0.08, 0.03, 0.02), M["trim"], "flat", what="givre")


# ------------------------------------------------------------------------------------------------
# Est
# ------------------------------------------------------------------------------------------------
def east(g, e, tank_fn):
    """Réservoirs de l'est, par époque (même emplacement que la lignée)."""
    M = g.M
    if e == 10:
        faired_box(g, 1.74, 2.36, Y(-0.6), Y(1.15), 0.74, louvers=0)
    elif e == 11:
        rocket_tank(g, 2.02, Y(0.95), 0.37, 0.92)
        rocket_tank(g, 2.02, Y(-0.4), 0.37, 0.92)
    elif e == 12:
        ring_gantry(g, 2.0, Y(-0.6), Y(1.15), 0.42, 0.56)
    elif e == 13:
        tank_fn(g, e, 2.4, Y(1.0), 0.44, 0.98, (1, 0.2), (-1, 0), gauges=3)
        tank_fn(g, e, 2.4, Y(-0.55), 0.44, 0.98, (1, -0.2), (-1, 0), gauges=3)
    elif e == 14:
        # deux GRANDES PARABOLES dorées sur affût blindé (à la place des réservoirs), tournées vers le haut et le sud
        for (x, y, rz) in ((2.4, Y(1.0), 0.35), (2.4, Y(-0.55), -0.25)):
            PT.hull(g, x - 0.4, x + 0.4, y - 0.4, y + 0.4, 0.0, 0.3, ins=(0.04, 0.04, 0.04), panel=0.26,
                    mats=[M["steel_dk"], M["olive"]], rivet_step=0.12)
            hatches(g, (x - 0.32, y - 0.405, 0.15), (x + 0.32, y - 0.405, 0.15), 6, (0, -1, 0), M["ring"],
                    size=(0.08, 0.06), frame=M["steel_dk"])
            g.cyl((x, y, 0.36), "z", 0.22, 0.12, M["ring"], n=28, what="pivot")
            g.cyl((x, y, 0.55), "z", 0.07, 0.3, M["steel_dk"], n=16, what="mat")
            for sx in (-1, 1):
                g.box((x + sx * 0.12, y, 0.66), (0.04, 0.12, 0.2), M["ring"], "hard", what="etrier")
            A.dish(g, (x, y, 0.78), 0.56, 0.16, M["jacket"], M["ring"], rx=0.62, rz=rz, horn=False)
            g.push((x, y, 0.78), rz=rz, rx=0.62)
            g.cyl((0, 0, 0.16 + 0.14), "z", 0.035, 0.28, M["steel_dk"], n=12, what="emetteur")
            g.cyl((0, 0, 0.16 + 0.3), "z", 0.06, 0.05, M["ring"], n=14, what="emetteur_tete")
            g.cyl((0, 0, 0.16 + 0.33), "z", 0.03, 0.006, M["emit2"], n=10, style="flat", what="lentille")
            g.pop()
            for s_ in (-1, 1):
                hatches(g, (x + s_ * 0.405, y - 0.3, 0.15), (x + s_ * 0.405, y + 0.3, 0.15), 5, (s_, 0, 0),
                        M["ring"], size=(0.07, 0.06), frame=M["steel_dk"])
            hatches(g, (x - 0.3, y - 0.3, 0.305), (x + 0.3, y - 0.3, 0.305), 5, (0, 0, 1), M["steel_hi"],
                    size=(0.05, 0.05))
            P3.lamp_group(g, (x - 0.3, y - 0.42, 0.24), (1, 0, 0), (0, -1, 0), M["emit"], M, n=2,
                          shapes=("rond", "fente"))
            g.cyl((x + 0.33, y - 0.33, 0.33), "z", 0.024, 0.06, M["steel_dk"], n=10, what="balise_pied")
            g.cyl((x + 0.33, y - 0.33, 0.37), "z", 0.018, 0.014, M["emit"], n=10, style="flat", what="balise")
        x, y = 2.74, Y(0.22)
        g.box((x, y, 0.06), (0.24, 0.24, 0.12), M["steel_dk"], "hard", what="semelle")
        g.box((x - 0.2, y, 0.1), (0.3, 0.6, 0.2), M["steel_dk"], "hard", what="coffre")
        g.cyl((x - 0.2, y - 0.31, 0.12), "z", 0.018, 0.014, M["emit"], n=10, style="flat", what="balise")
    else:
        tank_fn(g, e, 2.4, Y(1.0), 0.44, 1.1, (1, 0.2), (-1, 0), gauges=3)
        tank_fn(g, e, 2.4, Y(-0.55), 0.44, 1.1, (1, -0.2), (-1, 0), gauges=3)
        for (cx_, cy_) in ((2.4, Y(1.0)), (2.4, Y(-0.55))):
            for kk in range(9):
                a = math.pi + math.pi * (kk + 0.5) / 9
                d = V((math.cos(a), math.sin(a), 0))
                hatches(g, V((cx_, cy_, 0.25)) + d * 0.43, V((cx_, cy_, 0.29)) + d * 0.43, 1, d, M["trim"],
                        size=(0.07, 0.05))
                hatches(g, V((cx_, cy_, 0.86)) + d * 0.43, V((cx_, cy_, 0.9)) + d * 0.43, 1, d, M["ring"],
                        size=(0.06, 0.05))
            for (bx_, by_) in ((cx_ - 0.6, cy_ - 0.2), (cx_ + 0.3, cy_ - 0.5)):
                g.sphere((bx_, by_, 0.1), 0.02, M["emit"], n=10, m=6, what="pierre")
                g.cyl((bx_, by_, 0.05), "z", 0.035, 0.07, M["ring"], n=10, what="pierre_pied")


# ------------------------------------------------------------------------------------------------
# Ouest
# ------------------------------------------------------------------------------------------------
def west(g, e):
    """Groupe de l'ouest, par époque (même emprise que le groupe électrogène de la lignée)."""
    M = g.M
    E = M["emit"]
    if e in (10, 11, 12):
        x0, x1, y0, y1, h = -2.42, -1.62, Y(-0.95), Y(1.25), 0.52
    else:
        x0, x1, y0, y1, h = -2.88, -1.98, Y(-1.35), Y(1.35), 0.6
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    if e == 10:
        faired_box(g, x0 + 0.02, x1 - 0.02, y0, y1, h + 0.08, louvers=1, cables=False)
        # antenne-fouet et boîtier sur le toit (fine, hors masse)
        g.box((cx - 0.15, y1 - 0.3, h + 0.13), (0.14, 0.12, 0.08), M["matte"], "hard", what="boitier")
        g.cyl((cx - 0.15, y1 - 0.3, h + 0.4), "z", 0.006, 0.46, M["steel_dk"], n=6, what="antenne")
    elif e == 11:
        # TURBINE de titane couchée : entrée d'air en cône au nord, tuyère au sud, aubes, berceaux
        plinth(g, x0, x1, y0, y1, 0.1)
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
            t = A._Rax(d).col[0] * 0.026
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
            hatches(g, V((cx, ya + 0.12, zc)) + d * r * 0.93, V((cx, yb - 0.12, zc)) + d * r * 0.93, 7, d, M["ring"],
                    size=(0.07, 0.1), frame=M["steel_dk"])
        hatches(g, (x0 + 0.06, y0 + 0.25, 0.1), (x0 + 0.06, y1 - 0.25, 0.1), 6, (0, 0, 1), M["steel_hi"],
                size=(0.06, 0.06))
        for s in (-1, 1):
            d = V((s * 0.9, 0, 0.44)).normalized()
            hatches(g, V((cx, ya + 0.15, zc)) + d * r * 0.93, V((cx, yb - 0.15, zc)) + d * r * 0.93, 8, d, M["steel_dk"],
                    size=(0.06, 0.08), frame=M["ring"])
    elif e == 12:
        # COMPRESSEURS CRYOGÉNIQUES : 3 dewars noirs à cols chromés, givre, tuyaux de mousse
        plinth(g, x0, x1, y0, y1, 0.18)
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
    elif e == 13:
        # BANC D'INJECTEURS : 2 × 4 cylindres de céramique à bagues de cuivre, collecteur de cuivre
        plinth(g, x0, x1, y0, y1, 0.22)
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
                    hatches(g, V((xx, yy, 0.22 + hh * 0.3)) + d * 0.125, V((xx, yy, 0.22 + hh * 0.42)) + d * 0.125, 1,
                            d, M["steel_dk"], size=(0.05, 0.05))
        g.hose([(cx, y0 + 0.1, 0.3), (cx, cy, 0.42), (cx, y1 - 0.1, 0.3)], 0.06, M["copper"], step=0.05, n=12)
    elif e == 14:
        # BATTERIE en feuille d'or et 2 PANNEAUX solaires inclinés (cellules ≤ 5 %), balises
        plinth(g, x0, x1, y0, y1, 0.16)
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
        hatches(g, (cx - (x1 - x0) * 0.18 - r * 0.45, y0 + 0.2, zc + r * 0.92),
                (cx - (x1 - x0) * 0.18 - r * 0.45, y1 - 0.2, zc + r * 0.92), 14, (-0.4, 0, 0.92), M["steel_hi"],
                size=(0.05, 0.06))
        hatches(g, (x0 + 0.05, y0 + 0.3, 0.16), (x0 + 0.05, y1 - 0.3, 0.16), 14, (0, 0, 1), M["ring"], size=(0.06, 0.06),
                frame=M["steel_dk"])
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
    else:
        P2.engine(g, x0, x1, y0, y1, 0.0, h, 6, M, emat=E)
        hatches(g, (x0 - 0.005, y0 + 0.2, h * 0.25), (x0 - 0.005, y1 - 0.2, h * 0.25), 10, (-1, 0, 0), M["trim"],
                size=(0.07, 0.05), frame=M["ring"])
        hatches(g, (x1 + 0.005, y0 + 0.2, h * 0.3), (x1 + 0.005, y1 - 0.2, h * 0.3), 10, (1, 0, 0), M["trim"],
                size=(0.07, 0.05), frame=M["ring"])
        for yy in (y0 + 0.3, y1 - 0.3):
            g.sphere((x0 + 0.08, yy, h + 0.03), 0.022, E, n=10, m=6, what="pierre")


# ------------------------------------------------------------------------------------------------
# Sommet de la tête
# ------------------------------------------------------------------------------------------------
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


def crown(g, c, R, n=10, h=0.26, gems_all=False):
    """Couronne d'or blanc au-dessus de la tête : bandeau, fleurons en flèche, pierres lumineuses, tenue par 5 montants
    posés sur la coupole (rien ne flotte)."""
    M = g.M
    E = M["emit"]
    c = V(c)
    g.tube_shell(c, "z", R + 0.03, R - 0.03, 0.1, M["ring"], n=64, what="bandeau")
    g.torus(c + V((0, 0, 0.05)), "z", R + 0.03, 0.014, M["jacket"], n=64, m=6, what="jonc")
    g.torus(c - V((0, 0, 0.05)), "z", R + 0.03, 0.014, M["jacket"], n=64, m=6, what="jonc")
    for k in range(n):
        a = TAU * k / n
        d = V((math.cos(a), math.sin(a), 0))
        t = V((-d.y, d.x, 0))
        p = c + d * (R + 0.01) + V((0, 0, 0.05))
        hk = h * (1.0 if k % 2 == 0 else 0.62)
        P2.wedge(g, p - t * 0.075, p + t * 0.075, p + V((0, 0, hk)), d * 0.03, M["jacket"], what="fleuron")
        if k % 2 == 0 or gems_all:
            g.sphere(p + V((0, 0, hk + 0.02)) + d * 0.004, 0.022, E, n=10, m=6, what="pierre")
        a3 = a + TAU / n * 0.5
        d3 = V((math.cos(a3), math.sin(a3), 0))
        g.box(c + d3 * (R + 0.036), (0.07, 0.016, 0.05), M["trim"], "hard", R=Matrix.Rotation(a3 + math.pi / 2, 3, "Z"),
              what="nacre")
        for j in range(3):
            a2 = a + TAU / n * (j + 0.5) / 3
            d2 = V((math.cos(a2), math.sin(a2), 0))
            g.dome(c + d2 * (R + 0.032), d2, 0.012, M["rivet"])
        g.box(c + d * (R + 0.035) - V((0, 0, 0.0)), (0.02, 0.02, 0.02), M["trim"], "hard", R=Matrix.Rotation(a, 3, "Z"),
              what="sertissure")


def dome_top(g, e, H, top_turret, nac, Pf, Nf, zsurf):
    """Grand élément d'époque au sommet de la tête. zsurf(x, y) : hauteur de la coupole en (x, y)."""
    M = g.M
    E = M["emit"]
    R = H["R"]
    cx, cy, ztop = top_turret
    bx, yb0, yb1 = nac
    znac = H["zs"] + H["rz"] * 0.42
    if e == 10:
        radar_array(g, (cx, cy, ztop), 1.25, 0.46, tilt=0.95)
    elif e == 11:
        # grande DÉRIVE en flèche sur la nacelle, 2 dérives latérales inclinées, plaques anguleuses de titane
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
            P2.applique(g, Pf, Nf, th, 0.42, 0.5, 0.34, M["ring"], M, bolts=4)
    elif e == 12:
        # 2 DEWARS cryogéniques debout sur la nacelle, cols chromés, givre, tuyau de mousse vers la coupole
        for s in (-1, 1):
            x = s * bx * 0.55
            y = (yb0 + yb1) / 2 - 0.05
            g.cyl((x, y, znac + 0.22), "z", 0.13, 0.44, M["jacket"], n=24, what="dewar")
            for zz in (0.08, 0.3):
                g.tube_shell((x, y, znac + zz), "z", 0.15, 0.12, 0.04, M["ring"], n=24, what="collier")
            g.cyl((x, y, znac + 0.48), "z", 0.06, 0.08, M["ring"], n=16, what="col")
            g.tube_shell((x, y, znac + 0.445), "z", 0.075, 0.06, 0.02, M["trim"], n=16, what="givre")
            g.box((x, y - 0.135, znac + 0.25), (0.05, 0.006, 0.02), E, "flat", what="voyant")
    elif e == 13:
        # CHAMBRE DE CONFINEMENT sphérique sur la nacelle (céramique, cerclages de cuivre, tore segmenté, hublots)
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
    elif e == 14:
        # GRANDE PARABOLE dorée sur mât, au-dessus du tourelleau
        g.cyl((cx, cy, ztop + 0.16), "z", 0.06, 0.32, M["ring"], n=16, what="mat")
        g.cyl((cx, cy, ztop + 0.03), "z", 0.13, 0.06, M["steel_dk"], n=24, what="pivot")
        A.dish(g, (cx, cy, ztop + 0.36), 0.62, 0.16, M["jacket"], M["ring"], rx=-0.75, horn=False)
        g.push((cx, cy, ztop + 0.36), rx=-0.75)
        g.cyl((0, 0, 0.16 + 0.12), "z", 0.04, 0.24, M["steel_dk"], n=12, what="emetteur")
        g.cyl((0, 0, 0.16 + 0.25), "z", 0.06, 0.04, M["ring"], n=14, what="emetteur_tete")
        g.pop()
        g.cyl((cx, cy + 0.02, ztop + 0.36), "z", 0.016, 0.018, E, n=8, style="flat", what="balise")
    elif e == 15:
        zc = zsurf(0.0, -0.1)
        rc = 0.92
        zr = H["zs"] + H["rz"] * math.sqrt(max(0.0, 1 - (rc / R) ** 2)) + 0.16
        for k in range(5):
            a = TAU * (k + 0.5) / 5 + math.pi / 2
            d = V((math.cos(a), math.sin(a), 0))
            p = V((0, -0.1, 0)) + d * rc
            zb = zsurf(p.x, p.y)
            g.box(V((p.x, p.y, (zb + zr) / 2)), (0.06, 0.06, zr - zb + 0.04), M["ring"], "hard",
                  R=Matrix.Rotation(a, 3, "Z"), what="montant")
            g.cyl(V((p.x, p.y, zb + 0.015)), "z", 0.06, 0.03, M["steel_dk"], n=12, what="semelle")
            g.sphere(V((p.x, p.y, zb + 0.05)) + d * 0.07, 0.02, M["emit"], n=10, m=6, what="pierre")
        crown(g, (0, -0.1, zr), rc, n=12, h=0.3, gems_all=True)
        _ = zc


# ------------------------------------------------------------------------------------------------
# Tourelles secondaires : même couronne et même caisson que la lignée, mais les DEUX ARMES sont celles de l'époque
# ------------------------------------------------------------------------------------------------
def mini_turret(g, e, c, s, rz):
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
        PT.receiver(g, sx * 0.31 * s, -0.16 * s, 0.22 * s, 0.16 * s, 0.36 * s, 0.13 * s, mats=A.recv_mats(g, e))
        A.barrel(g, e, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
    PT.lamp(g, (0.0, 0.12 * s, 0.4 * s + 0.01), (0, 0.35, 1), 0.035, E, cage=False)
    PT.hatch(g, (0.0, -0.12 * s, 0.4 * s), 0.09 * s)
    g.pop()


# ------------------------------------------------------------------------------------------------
# Nord-ouest (ère IV) et nord (ère V) : le bloc radiateur de la lignée devient la machine de l'époque
# ------------------------------------------------------------------------------------------------
def fin_exchanger(g, x0, x1, y0, y1, h, nfin=7):
    """Échangeur de titane : socle, rangée d'AILETTES verticales anguleuses en alliage clair, collecteurs."""
    M = g.M
    plinth(g, x0, x1, y0, y1, 0.12)
    for i in range(nfin):
        x = x0 + 0.08 + (x1 - x0 - 0.16) * (i + 0.5) / nfin
        P2.wedge(g, V((x, y0 + 0.06, 0.12)), V((x, y1 - 0.06, 0.12)), V((x, y0 + 0.12, h)), V((0.035, 0, 0)), M["ring"],
                 what="ailette")
        g.box((x, (y0 + y1) / 2, 0.16), (0.05, y1 - y0 - 0.1, 0.06), M["steel_dk"], "hard", what="pied")
    for yy in (y0 + 0.1, y1 - 0.12):
        g.cyl(((x0 + x1) / 2, yy, 0.2), "x", 0.04, x1 - x0 - 0.06, M["jacket"], n=10, what="collecteur")
    hatches(g, (x0 + 0.06, y0 - 0.005, 0.07), (x1 - 0.06, y0 - 0.005, 0.07), 4, (0, -1, 0), M["steel_hi"],
            size=(0.06, 0.04))
    for f in (0.2, 0.6):
        g.box((x0 + (x1 - x0) * f, y0 + 0.02, 0.135), (0.08, 0.02, 0.025), M["emit"], "flat", what="chenillard")


def torus_bank(g, x0, x1, y0, y1, h):
    """Banc de bobines toriques (fusion) : 3 gros tores couchés en céramique et cuivre, segments magenta, barre."""
    M = g.M
    E = M["emit"]
    plinth(g, x0, x1, y0, y1, 0.14)
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


def solar_array(g, x0, x1, y0, y1, h):
    """Champ de panneaux (orbite) : cadres blanc cassé, feuille d'or, cellules bleu nuit en petites bandes."""
    M = g.M
    E = M["emit"]
    plinth(g, x0, x1, y0, y1, 0.12)
    hatches(g, (x0 + 0.1, y0 - 0.005, 0.06), (x1 - 0.1, y0 - 0.005, 0.06), 14, (0, -1, 0), M["ring"], size=(0.06, 0.05),
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


def nw_iv(g, e):
    """Bloc nord-ouest de l'ère IV (même place que le radiateur de la lignée, posé en biais)."""
    M = g.M
    if e == 10:
        faired_box(g, -0.42, 0.42, -0.32, 0.32, 0.4, louvers=1, cables=False)
    elif e == 11:
        fin_exchanger(g, -0.55, 0.55, -0.42, 0.42, 0.62)
    else:
        ring_gantry(g, 0.0, -0.38, 0.38, 0.34, 0.42)
