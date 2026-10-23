"""Pièces mécaniques réutilisables du style « industriel lourd » (lot V3-S). S'exécute DANS Blender.

Chaque fonction ajoute de la géométrie à un kit.Geo (g) dans le repère courant. La taille des détails (rivets,
boulons, lamelles, cartouches, plaques) est CONSTANTE quelle que soit la taille du bâtiment : un grand
bâtiment porte plus de pièces, jamais des pièces plus grosses (loi vanilla de la charte §3.2).
"""
import math

from mathutils import Matrix, Vector

from kit import SQ2, TAU, basis

V = Vector


def hull(g, x0, x1, y0, y1, z0, z1, ins=(0.08, 0.06, 0.06), panel=0.4, mats=None, rivets=True, faces="tsnew",
         t=0.03, core=None, rivet_step=0.17):
    """Caisson blindé en tronc de pyramide (bas : x0..x1 × y0..y1 à z0 ; haut rentré de ins = (côtés, arrière y0,
    avant y1)), chaque face visible habillée de plaques rivetées. Renvoie les 4 coins du haut."""
    M = g.M
    ix, ib, iff = ins
    B = [V((x0, y0, z0)), V((x1, y0, z0)), V((x1, y1, z0)), V((x0, y1, z0))]
    T = [V((x0 + ix, y0 + ib, z1)), V((x1 - ix, y0 + ib, z1)), V((x1 - ix, y1 - iff, z1)), V((x0 + ix, y1 - iff, z1))]
    g.hexa(B + T, core or M["seam"], "flat", "caisson")
    quads = {"s": [B[0], B[1], T[1], T[0]], "e": [B[1], B[2], T[2], T[1]], "n": [B[2], B[3], T[3], T[2]],
             "w": [B[3], B[0], T[0], T[3]], "t": [T[0], T[1], T[2], T[3]]}
    mats = mats or [M["armor"]]
    for f in faces:
        q = quads[f]
        lu = (q[1] - q[0]).length
        lv = (q[3] - q[0]).length
        if lu < 0.05 or lv < 0.05:
            continue
        nu = max(1, int(round(lu / panel)))
        nv = max(1, int(round(lv / panel)))
        g.panels(q, nu, nv, mats[0], t=t, rivet_mat=M["rivet"] if rivets else None, mats=mats, rivet_step=rivet_step)
    return T


def face_quad(q, s0, s1, t0, t1):
    """Sous-quadrilatère d'un quadrilatère q (coordonnées relatives)."""
    def P(s, t):
        a = q[0].lerp(q[1], s)
        b = q[3].lerp(q[2], s)
        return a.lerp(b, t)
    return [P(s0, t0), P(s1, t0), P(s1, t1), P(s0, t1)]


def lift(q, d):
    nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
    return [p + nrm * d for p in q]


def slewing_ring(g, r, z0, h):
    """Couronne d'orientation : fût, denture, anneau de danger, couronne de boulons."""
    M = g.M
    g.cyl((0, 0, z0 + h / 2), "z", r, h, M["armor2"], n=72, style="soft", what="couronne")
    nt = int(TAU * r / 0.12)
    for i in range(nt):
        a = TAU * i / nt
        R = Matrix.Rotation(a, 3, "Z")
        g.box((math.cos(a) * (r + 0.016), math.sin(a) * (r + 0.016), z0 + h * 0.42), (0.036, 0.032, h * 0.62),
              M["steel"], "hard", R=R, what="dent")
    nseg = 2 * int(TAU * r / 0.3)
    ro, ri = r - 0.015, r - 0.12
    zt = z0 + h
    for i in range(nseg):
        a0, a1 = TAU * i / nseg, TAU * (i + 1) / nseg
        bot = [V((ri * math.cos(a0), ri * math.sin(a0), zt)), V((ro * math.cos(a0 + 0.03), ro * math.sin(a0 + 0.03), zt)),
               V((ro * math.cos(a1 + 0.03), ro * math.sin(a1 + 0.03), zt)), V((ri * math.cos(a1), ri * math.sin(a1), zt))]
        g.hexa(bot + [p + V((0, 0, 0.02)) for p in bot], M["hazy"] if i % 2 else M["hazk"], "flat", "danger")
    nb = int(TAU * (r - 0.19) / 0.17)
    for i in range(nb):
        a = TAU * i / nb
        g.dome(((r - 0.18) * math.cos(a), (r - 0.18) * math.sin(a), zt), (0, 0, 1), 0.024, M["rivet"])
    g.cyl((0, 0, zt + 0.006), "z", r - 0.24, 0.012, M["seam"], n=64, style="flat", what="couronne_fond")


def gatling(g, x, y0, z, L, nb, rb, rr, shroud_L, mats=None, phase=0.3, hole_mat=None, brake=False, coil=None):
    """Canon rotatif : nb canons autour d'un axe, jaquette perforée, bagues boulonnées, bouches visibles."""
    M = g.M
    for i in range(nb):
        a = phase + TAU * i / nb
        bx, bz = x + rr * math.cos(a), z + rr * math.sin(a)
        g.cyl((bx, y0 + L / 2, bz), "y", rb, L, M["gun"], n=10, what="canon")
        g.cyl((bx, y0 + L + 0.003, bz), "y", rb * 0.6, 0.008, M["void"], n=8, style="flat", what="bouche")
    g.cyl((x, y0 + L * 0.5, z), "y", rr * 0.42, L * 0.97, M["steel"], n=10, what="axe")
    rs = rr + rb + 0.028
    g.cyl((x, y0 + shroud_L / 2, z), "y", rs, shroud_L, M["steel"], n=28, style="smooth", what="jaquette")
    nh_ax = max(2, int((shroud_L - 0.1) / 0.06))
    nh_ang = max(8, int(TAU * rs / 0.07))
    for i in range(nh_ax):
        for j in range(nh_ang):
            a = TAU * j / nh_ang + (0.5 * TAU / nh_ang if i % 2 else 0.0)
            d = V((math.cos(a), 0.0, math.sin(a)))
            if d.z < -0.45:
                continue
            p = V((x, y0 + 0.07 + (shroud_L - 0.14) * (i + 0.5) / nh_ax, z)) + d * (rs + 0.002)
            g.cyl(p, d, 0.017, 0.006, hole_mat or M["void"], n=6, style="flat", what="trou")
    for f, m in ((0.0, "steel"), (shroud_L / L, "steel"), (0.6, "brass"), (0.93, "steel")):
        yy = y0 + f * L + (0.03 if f == 0.0 else 0.0)
        g.tube_shell((x, yy, z), "y", rs + 0.022, rr * 0.3, 0.05, M[m], n=28, what="bague")
        for k in range(6):
            a = TAU * k / 6 + 0.2
            d = V((math.cos(a), 0.0, math.sin(a)))
            if d.z < -0.3:
                continue
            g.dome(V((x, yy, z)) + d * (rs + 0.024), d, 0.016, M["rivet"])
    if coil is not None:
        # bobines de puissance : deux anneaux lumineux étroits, en avant de la jaquette
        for f in (0.68, 0.76):
            g.tube_shell((x, y0 + f * L, z), "y", rr + rb + 0.012, rr * 0.5, 0.03, coil, n=28, what="bobine")
    if brake:
        # frein de bouche : manchon à évents, en avant des bouches
        yb = y0 + L + 0.09
        g.tube_shell((x, yb, z), "y", rs + 0.035, rr * 0.55, 0.16, M["steel"], n=28, what="frein")
        for k in range(8):
            a = TAU * k / 8 + 0.2
            d = V((math.cos(a), 0.0, math.sin(a)))
            if d.z < -0.5:
                continue
            g.box(V((x, yb, z)) + d * (rs + 0.036), (0.04, 0.1, 0.02), M["void"], "flat",
                  R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed(), what="event")
    return rs


def receiver(g, x, y0, y1, z0, z1, w, mats=None):
    """Culasse blindée (boîte de mécanisme) + capot de chargement + boulons."""
    M = g.M
    T = hull(g, x - w / 2, x + w / 2, y0, y1, z0, z1, ins=(0.03, 0.03, 0.05), panel=0.3, mats=mats or [M["armor2"], M["armor"]])
    # capot de chargement charnière
    zc = z1 + 0.012
    g.box((x, (y0 + y1) / 2 - 0.05, zc + 0.02), (w * 0.62, (y1 - y0) * 0.42, 0.04), M["steel"], "hard", what="capot")
    g.cyl((x, (y0 + y1) / 2 - 0.05 - (y1 - y0) * 0.21, zc + 0.03), "x", 0.018, w * 0.66, M["brass"], n=8, what="charniere")
    return T


def belt(g, ctrl, step=0.05, scale=1.0, mats=None):
    """Bande de cartouches (maillons sombres, étuis laiton, balles cuivre) le long d'une courbe.
    mats (lot V3-E) : (étui, balle) de l'époque ; None = laiton et cuivre (lignée)."""
    M = g.M
    case_m, tip_m = mats or (M["brass"], M["copper"])
    P = g.resample(g.spline(ctrl, 12), step * scale)
    T, _ = g.frames(P)
    for i, p in enumerate(P):
        t = T[i]
        side = t.cross(V((0, 0, 1)))
        if side.length < 1e-3:
            side = V((1, 0, 0))
        side.normalize()
        up = side.cross(t).normalized()
        R = Matrix((side, t, up)).transposed()
        g.box(p, (0.1 * scale, 0.026 * scale, 0.02 * scale), M["steel"], "flat", R=R, what="maillon")
        g.cyl(p + up * 0.022 * scale, side, 0.017 * scale, 0.085 * scale, case_m, n=6, what="cartouche")
        g.cyl(p + up * 0.022 * scale + side * 0.055 * scale, side, 0.013 * scale, 0.028 * scale, tip_m, n=6,
              r2=0.005 * scale, what="balle")


def crate(g, c, size, rz=0.0, mat=None, lid=True):
    """Caisse de munitions cerclée : plaques, nervures, couvercle à charnières, poignées, loquet laiton."""
    M = g.M
    sx, sy, sz = size
    g.push(c, rz=rz)
    hull(g, -sx / 2, sx / 2, -sy / 2, sy / 2, 0, sz, ins=(0.012, 0.012, 0.012), panel=0.6, rivets=False,
         mats=[mat or M["khaki"]], t=0.02)
    nr = max(2, int(sx / 0.16))
    for i in range(nr + 1):
        x = -sx / 2 + 0.03 + (sx - 0.06) * i / nr
        g.box((x, -sy / 2 - 0.008, sz / 2), (0.028, 0.02, sz * 0.96), M["steel"], "hard", what="nervure")
        g.box((x, sy / 2 + 0.008, sz / 2), (0.028, 0.02, sz * 0.96), M["steel"], "hard", what="nervure")
    for yy in (-sy / 2 + 0.04, sy / 2 - 0.04):
        g.box((0, yy, sz + 0.012), (sx * 0.98, 0.03, 0.02), M["steel"], "hard", what="cerclage")
    if lid:
        g.box((0, 0, sz + 0.016), (sx * 0.86, sy * 0.7, 0.025), mat or M["khaki"], "hard", what="couvercle")
        g.cyl((0, sy * 0.36, sz + 0.02), "x", 0.015, sx * 0.7, M["brass"], n=8, what="charniere")
        g.box((0, -sy * 0.36, sz + 0.03), (0.08, 0.04, 0.04), M["brass"], "hard", what="loquet")
    for sxn in (-1, 1):
        g.box((sxn * (sx / 2 + 0.012), 0, sz * 0.62), (0.025, sy * 0.4, 0.035), M["steel"], "hard", what="poignee")
    g.pop()


def drum(g, c, axis, r, h):
    """Tambour à munitions : flasques, nervures rayonnantes, moyeu, boulons."""
    M = g.M
    a, u, w = basis(V(axis))
    c = V(c)
    g.cyl(c, a, r, h, M["armor2"], n=32, style="soft", what="tambour")
    for s in (-1, 1):
        g.tube_shell(c + a * s * (h / 2 - 0.012), a, r + 0.018, r - 0.04, 0.03, M["steel"], n=32, what="flasque")
        g.cyl(c + a * s * (h / 2 + 0.01), a, r * 0.32, 0.03, M["brass"], n=12, what="moyeu")
        for k in range(8):
            ang = TAU * k / 8
            d = u * math.cos(ang) + w * math.sin(ang)
            g.box(c + a * s * (h / 2 + 0.006) + d * r * 0.62, (0.03, 0.03, 0.03), M["steel"], "hard",
                  R=Matrix((d, d.cross(a), a)).transposed(), what="rayon")
            g.dome(c + a * s * (h / 2 + 0.015) + d * (r - 0.02), a * s, 0.016, M["rivet"])


def insulators(g, c, n, r, h=0.034):
    """Pile d'isolateurs (céramique patinée, accent de l'époque 6) avec chapeau laiton."""
    M = g.M
    x, y, z = c
    for i in range(n):
        rr = r if i % 2 == 0 else r * 0.6
        g.cyl((x, y, z + h * i + h / 2), "z", rr, h * 0.9, M["accent"], n=16, style="soft", what="isolateur")
    zt = z + h * n
    g.cyl((x, y, zt + 0.02), "z", r * 0.55, 0.04, M["brass"], n=12, style="hard", what="chapeau")
    return zt + 0.04


def lamp(g, p, nrm, r, emat, cage=True):
    """Voyant : boîtier sombre, verre lumineux, visière."""
    M = g.M
    a, u, w = basis(V(nrm))
    p = V(p)
    g.cyl(p + a * 0.02, a, r * 1.4, 0.04, M["armor2"], n=12, style="hard", what="lampe")
    g.cyl(p + a * 0.044, a, r, 0.014, emat, n=12, style="flat", what="verre")
    if cage:
        for d in (u, w):
            R = Matrix((d, d.cross(a).normalized(), a)).transposed()
            g.box(p + a * 0.058, (r * 2.6, 0.022, 0.022), M["steel"], "hard", R=R, what="cage")


def radiator(g, c, w, h, d, rz=0.0, fin_mat=None, step=0.045, glow=None):
    """Radiateur : cadre, ailettes serrées (accent d'époque possible), collecteurs haut et bas."""
    M = g.M
    g.push(c, rz=rz)
    g.box((0, -d / 2, h / 2), (w, d * 0.5, h * 0.86), glow or M["void"], "flat", what="radiateur_fond")
    n = max(3, int((w - 0.06) / step))
    fm = fin_mat or M["steel"]
    for i in range(n):
        x = -w / 2 + 0.04 + (w - 0.08) * (i + 0.5) / n
        g.box((x, -d / 2, h / 2), (0.016, d, h * 0.9), fm, "hard", what="ailette")
    for zz in (0.02, h - 0.02):
        g.cyl((0, -d / 2, zz), "x", 0.035, w + 0.04, M["copper"], n=12, what="collecteur")
    for xx in (-w / 2, w / 2):
        g.box((xx, -d / 2, h / 2), (0.04, d * 1.05, h + 0.04), M["armor2"], "hard", what="cadre")
    g.pop()


def capacitors(g, c, nx, ny, r, h, emat, rz=0.0):
    """Réserve d'énergie visible : condensateurs en rang, couronne lumineuse au sommet, bornes et barres."""
    M = g.M
    g.push(c, rz=rz)
    px, py = 2 * r + 0.05, 2 * r + 0.05
    for i in range(nx):
        for j in range(ny):
            x = (i - (nx - 1) / 2) * px
            y = (j - (ny - 1) / 2) * py
            g.cyl((x, y, h / 2), "z", r, h, M["armor2"], n=20, style="soft", what="condensateur")
            for zz in (0.08, h - 0.1):
                g.tube_shell((x, y, zz), "z", r + 0.014, r - 0.01, 0.03, M["brass"], n=20, what="cerclage")
            g.tube_shell((x, y, h + 0.012), "z", r * 0.7, r * 0.56, 0.02, emat, n=20, what="couronne_lum")
            g.cyl((x, y, h + 0.006), "z", r * 0.5, 0.016, M["seam"], n=16, style="flat")
            g.cyl((x, y, h + 0.04), "z", r * 0.22, 0.06, M["copper"], n=8, what="borne")
    for j in range(ny):
        y = (j - (ny - 1) / 2) * py
        g.box((0, y, h + 0.075), ((nx - 1) * px + 0.08, 0.04, 0.025), M["copper"], "hard", what="barre")
    g.pop()


def hatch(g, c, r):
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + 0.015), "z", r, 0.03, M["armor2"], n=24, style="soft", what="trappe")
    g.torus((x, y, z + 0.03), "z", r - 0.02, 0.016, M["steel"], n=24, m=6, what="jonc")
    g.box((x, y + r * 0.95, z + 0.035), (r * 0.8, 0.05, 0.04), M["steel"], "hard", what="charniere")
    for s in (-1, 1):
        g.box((x + s * r * 0.35, y - r * 0.2, z + 0.05), (0.03, r * 0.5, 0.03), M["brass"], "hard", what="poignee")
    for k in range(8):
        a = TAU * k / 8 + 0.2
        g.dome((x + (r - 0.04) * math.cos(a), y + (r - 0.04) * math.sin(a), z + 0.03), (0, 0, 1), 0.016, M["rivet"])


def exhaust(g, c, r, h):
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + h / 2), "z", r, h, M["soot"], n=18, style="soft", what="echappement")
    for f in (0.25, 0.6, 0.95):
        g.tube_shell((x, y, z + h * f), "z", r + 0.018, r - 0.01, 0.035, M["brass"] if f == 0.6 else M["steel"], n=18,
                     what="bague")
    g.tube_shell((x, y, z + h + 0.02), "z", r + 0.01, r - 0.025, 0.04, M["seam"], n=18, what="levre")
    g.cyl((x, y, z + h + 0.005), "z", r - 0.03, 0.01, M["void"], n=16, style="flat")


def piston(g, p0, p1, r):
    M = g.M
    p0, p1 = V(p0), V(p1)
    d = p1 - p0
    m = p0.lerp(p1, 0.58)
    g.cyl((p0 + m) / 2, d, r, (m - p0).length, M["steel"], n=12, what="verin")
    g.cyl((m + p1) / 2, d, r * 0.55, (p1 - m).length, M["brass"], n=10, what="tige")
    for p in (p0, p1):
        g.cyl(p, V((1, 0, 0)), r * 1.2, r * 1.6, M["armor2"], n=10, what="chape")


def cable_run(g, ctrl, n, r, gap, mats):
    """Faisceau de n câbles parallèles le long d'une courbe, avec colliers."""
    M = g.M
    P = g.spline(ctrl, 10)
    T, U = g.frames(P)
    for k in range(n):
        off = (k - (n - 1) / 2) * gap
        pts = []
        for i, p in enumerate(P):
            side = T[i].cross(V((0, 0, 1)))
            if side.length < 1e-3:
                side = V((1, 0, 0))
            pts.append(p + side.normalized() * off)
        g.tube(pts, r, mats[k % len(mats)], n=8, what="cable")
    for i in range(2, len(P) - 2, 6):
        g.cyl(P[i], T[i], n * gap * 0.62 + r * 1.5, 0.03, M["steel"], n=10, style="hard", what="collier")


def mini_turret(g, c, s, rz, emat):
    """Tourelle secondaire (ère IV et V) : couronne, caisson, deux canons à 4 tubes, caisse, voyant."""
    M = g.M
    g.push(c, rz=rz)
    g.cyl((0, 0, 0.05 * s), "z", 0.36 * s, 0.1 * s, M["armor2"], n=32, style="soft", what="couronne")
    nb = int(TAU * 0.32 * s / 0.1)
    for k in range(nb):
        a = TAU * k / nb
        g.dome((0.31 * s * math.cos(a), 0.31 * s * math.sin(a), 0.1 * s), (0, 0, 1), 0.016, M["rivet"])
    hull(g, -0.24 * s, 0.24 * s, -0.3 * s, 0.24 * s, 0.1 * s, 0.4 * s, ins=(0.04 * s, 0.03 * s, 0.1 * s), panel=0.22,
         mats=[M["armor"], M["khaki"]])
    for sx in (-1, 1):
        receiver(g, sx * 0.31 * s, -0.16 * s, 0.22 * s, 0.16 * s, 0.36 * s, 0.13 * s)
        gatling(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 4, max(0.017, 0.024 * s), 0.045 * s, 0.22 * s)
    lamp(g, (0.0, 0.12 * s, 0.4 * s + 0.01), (0, 0.35, 1), 0.035, emat, cage=False)
    hatch(g, (0.0, -0.12 * s, 0.4 * s), 0.09 * s)
    g.pop()


def sight(g, c, w, d, h, emat, lenses=2):
    """Viseur blindé : boîte, capuchons, lentilles lumineuses vers l'avant, câble."""
    M = g.M
    x, y, z = c
    hull(g, x - w / 2, x + w / 2, y - d / 2, y + d / 2, z, z + h, ins=(0.02, 0.02, 0.05), panel=0.25,
         mats=[M["armor2"]])
    for k in range(lenses):
        lx = x + (k - (lenses - 1) / 2) * (w * 0.45)
        g.cyl((lx, y + d / 2 + 0.03, z + h * 0.55), "y", 0.055, 0.08, M["steel"], n=14, what="capuchon")
        g.cyl((lx, y + d / 2 + 0.072, z + h * 0.55), "y", 0.04, 0.01, emat, n=14, style="flat", what="lentille")
    g.box((x, y - d * 0.1, z + h + 0.03), (w * 0.5, d * 0.5, 0.05), M["steel"], "hard", what="capot")


def octo(hx, hy, c, z):
    """Octogone « carré à l'écran » (chanfrein c en X, c·1,414 en Y), sens direct vu de dessus, départ sud-ouest."""
    cy = c * SQ2
    return [V((-hx + c, -hy, z)), V((hx - c, -hy, z)), V((hx, -hy + cy, z)), V((hx, hy - cy, z)),
            V((hx - c, hy, z)), V((-hx + c, hy, z)), V((-hx, hy - cy, z)), V((-hx, -hy + cy, z))]


def octo_frustum(g, b, t, panel=0.5, mats=None, rivets=True, skip=(), rivet_step=0.18, t_pl=0.03):
    """Tronc de pyramide octogonal (anneaux b et t de 8 points), faces latérales habillées de plaques rivetées,
    dessus en tôle sombre. skip : indices de faces non habillées (cachées)."""
    M = g.M
    mats = mats or [M["armor"]]
    n = len(b)
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    g._add(M["seam"], "flat", [tuple(p) for p in b + t], faces, "caisson")
    for i in range(n):
        if i in skip:
            continue
        j = (i + 1) % n
        q = [b[i], b[j], t[j], t[i]]
        lu = (q[1] - q[0]).length
        lv = (q[3] - q[0]).length
        if lu < 0.08 or lv < 0.05:
            continue
        g.panels(q, max(1, int(round(lu / panel))), max(1, int(round(lv / panel))), mats[0], t=t_pl,
                 rivet_mat=M["rivet"] if rivets else None, mats=mats, rivet_step=rivet_step)
    return [b[i] for i in range(n)], [t[i] for i in range(n)]


def side_quad(b, t, i):
    j = (i + 1) % len(b)
    return [b[i], b[j], t[j], t[i]]


def glow_grille(g, q, n, emat, depth=0.03):
    """Grille éclairée de l'intérieur (énergie visible) : fond lumineux, lamelles sombres devant."""
    M = g.M
    q = [V(p) for p in q]
    nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
    g.slab(q, nrm, 0.006, emat, "flat", "grille_lum")
    lu = (q[1] - q[0]).length
    lv = (q[3] - q[0]).length
    fu, fv = 0.03 / lu, 0.03 / lv
    for quad in (face_quad(q, 0, 1, 0, fv), face_quad(q, 0, 1, 1 - fv, 1), face_quad(q, 0, fu, fv, 1 - fv),
                 face_quad(q, 1 - fu, 1, fv, 1 - fv)):
        g.slab(quad, nrm, depth, M["armor2"], "hard", "grille_cadre")
    for i in range(n):
        t0 = fv + (1 - 2 * fv) * (i + 0.45) / n
        t1 = fv + (1 - 2 * fv) * (i + 0.95) / n
        g.slab(face_quad(q, fu, 1 - fu, t0, t1), nrm, depth * 0.8, M["seam"], "hard", "lamelle")


def steps(g, x, y0, z0, z1, w, n, mat=None):
    """Marches d'accès (vers le sud) de z0 à z1, nez de marche laiton usé."""
    M = g.M
    dz = (z1 - z0) / n
    for k in range(n):
        zz = z0 + dz * (k + 1)
        yy = y0 + 0.11 * k
        g.box((x, yy + 0.06, zz - dz / 2), (w, 0.13, dz), mat or M["armor2"], "hard", what="marche")
        g.box((x, yy + 0.0, zz - 0.006), (w * 0.96, 0.025, 0.014), M["hazy"] if k % 2 else M["brass"], "hard",
              what="nez")
