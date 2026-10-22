"""Pièces mécaniques, 2e passage du style « industriel lourd » (reprise du 22/10). S'exécute DANS Blender.

Pourquoi ce module : la critique des essais de 8 h 50 (dalles carrées vues de dessus, tête qui se perd, gris
uniforme, relief plat). Les pièces ci-dessous sont des VOLUMES fonctionnels du vocabulaire vanilla (réacteur,
silo, artillerie, centrifugeuse) : poutres en I, caillebotis, colonne à goussets, coupole rivetée, moteur à
cylindres et volant, réservoirs, radiateurs à ventilateur vus de dessus, trémie, caisses ouvertes pleines de
cartouches, vannes à volant, manomètres, échelles, goulottes articulées. La taille des petits détails (rivets,
boulons, cartouches, lamelles) est CONSTANTE : un grand bâtiment en porte plus, jamais de plus gros.
"""
import math

from mathutils import Matrix, Vector

import parts as PT
from kit import SQ2, TAU, basis

V = Vector


def Rm(d, up=(0.0, 0.0, 1.0)):
    """Matrice de rotation dont l'axe x local suit d (horizontal en général), z local proche de up."""
    d = V(d).normalized()
    u = V(up)
    s = u.cross(d)
    if s.length < 1e-6:
        s = V((0.0, 1.0, 0.0)).cross(d)
    s.normalize()
    z = d.cross(s).normalized()
    return Matrix((d, s, z)).transposed()


def wedge(g, p0, p1, p2, thick_dir, mat, style="hard", what="gousset"):
    """Prisme triangulaire (gousset) : triangle p0 p1 p2 extrudé de thick_dir (centré)."""
    t = V(thick_dir) * 0.5
    P = [V(p0) - t, V(p1) - t, V(p2) - t, V(p0) + t, V(p1) + t, V(p2) + t]
    faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    g._add(mat, style, [tuple(p) for p in P], faces, what)


def ibeam(g, a, b, h, w, mat, rivet_mat=None, stiff=0.32, what="poutre"):
    """Poutre en I horizontale de a à b (points au pied) : semelles, âme, raidisseurs, rivets."""
    a, b = V(a), V(b)
    d = b - a
    L = d.length
    d.normalize()
    R = Rm(d)
    s = R.col[1]
    m = (a + b) / 2
    tf = 0.03
    g.box(m + V((0, 0, tf / 2)), (L, w, tf), mat, "hard", R=R, what=what)
    g.box(m + V((0, 0, h - tf / 2)), (L, w, tf), mat, "hard", R=R, what=what)
    g.box(m + V((0, 0, h / 2)), (L, 0.032, h - 2 * tf), mat, "hard", R=R, what=what)
    n = max(1, int(L / stiff))
    for i in range(n + 1):
        p = a + d * (0.04 + (L - 0.08) * i / n)
        for sg in (-1, 1):
            g.box(p + s * sg * w * 0.26 + V((0, 0, h / 2)), (0.03, w * 0.44, h - 2 * tf), mat, "hard", R=R,
                  what="raidisseur")
    if rivet_mat is not None:
        k = max(2, int(L / 0.11))
        for i in range(k):
            p = a + d * (0.05 + (L - 0.1) * (i + 0.5) / k)
            for sg in (-1, 1):
                g.dome(p + s * sg * w * 0.33 + V((0, 0, h)), (0, 0, 1), 0.016, rivet_mat)


def grating(g, x0, x1, y0, y1, z, M, pitch=0.085, along="x", frame=True):
    """Caillebotis : fond noir, lames sur chant, entretoises, cadre boulonné (plancher du silo vanilla)."""
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, z - 0.035), (x1 - x0, y1 - y0, 0.02), M["void"], "flat", what="fond")
    if along == "x":
        n = max(1, int((y1 - y0) / pitch))
        for i in range(n):
            y = y0 + (y1 - y0) * (i + 0.5) / n
            g.box(((x0 + x1) / 2, y, z - 0.012), (x1 - x0 - 0.02, 0.028, 0.04), M["grate"], "flat", what="lame")
        nc = max(1, int((x1 - x0) / 0.3))
        for i in range(1, nc):
            x = x0 + (x1 - x0) * i / nc
            g.box((x, (y0 + y1) / 2, z - 0.02), (0.022, y1 - y0 - 0.02, 0.03), M["grate"], "flat", what="entretoise")
    else:
        n = max(1, int((x1 - x0) / pitch))
        for i in range(n):
            x = x0 + (x1 - x0) * (i + 0.5) / n
            g.box((x, (y0 + y1) / 2, z - 0.012), (0.028, y1 - y0 - 0.02, 0.04), M["grate"], "flat", what="lame")
        nc = max(1, int((y1 - y0) / 0.3))
        for i in range(1, nc):
            y = y0 + (y1 - y0) * i / nc
            g.box(((x0 + x1) / 2, y, z - 0.02), (x1 - x0 - 0.02, 0.022, 0.03), M["grate"], "flat", what="entretoise")
    if frame:
        for (cx, cy, sx, sy) in (((x0 + x1) / 2, y0, x1 - x0, 0.04), ((x0 + x1) / 2, y1, x1 - x0, 0.04),
                                 (x0, (y0 + y1) / 2, 0.04, y1 - y0), (x1, (y0 + y1) / 2, 0.04, y1 - y0)):
            g.box((cx, cy, z), (sx, sy, 0.05), M["steel_dk"], "hard", what="cadre")


def pedestal(g, R, z0, z1, n, M, mats, gussets=True, ladder_at=None):
    """Colonne-socle à n pans (plaques rivetées), goussets aux arêtes, semelle boulonnée, ceinture haute."""
    pts_b = [V((R * math.cos(TAU * (i + 0.5) / n), R * math.sin(TAU * (i + 0.5) / n), z0)) for i in range(n)]
    pts_t = [p + V((0, 0, z1 - z0)) for p in pts_b]
    PT.octo_frustum(g, pts_b, pts_t, panel=0.36, mats=mats, rivet_step=0.15)
    # semelle et boulons
    g.cyl((0, 0, z0 + 0.04), "z", R + 0.16, 0.08, M["steel_dk"], n=4 * n, style="soft", what="semelle")
    nb = int(TAU * (R + 0.1) / 0.2)
    for k in range(nb):
        a = TAU * k / nb
        g.bolt(((R + 0.1) * math.cos(a), (R + 0.1) * math.sin(a), z0 + 0.08), (0, 0, 1), 0.02, M["steel_hi"])
    # ceinture haute
    g.tube_shell((0, 0, z1 - 0.05), "z", R + 0.05, R - 0.04, 0.1, M["steel_dk"], n=4 * n, what="ceinture")
    nb = int(TAU * R / 0.18)
    for k in range(nb):
        a = TAU * k / nb
        d = V((math.cos(a), math.sin(a), 0))
        g.dome(d * (R + 0.05) + V((0, 0, z1 - 0.05)), d, 0.016, M["rivet"])
    if gussets:
        hg = min(0.42, (z1 - z0) * 0.55)
        for i in range(n):
            a = TAU * i / n
            d = V((math.cos(a), math.sin(a), 0))
            t = V((-d.y, d.x, 0)) * 0.032
            r0 = R * math.cos(math.pi / n)
            wedge(g, d * r0 + V((0, 0, z0 + 0.08)), d * (R + 0.15) + V((0, 0, z0 + 0.08)),
                  d * r0 + V((0, 0, z0 + 0.08 + hg)), t, M["steel_dk"])
    if ladder_at is not None:
        a = ladder_at
        d = V((math.cos(a), math.sin(a), 0))
        ladder(g, d * (R * math.cos(math.pi / n) + 0.06), d, z0 + 0.08, z1, 0.22, M)


def ladder(g, base, out, z0, z1, w, M):
    """Échelle à crinoline simplifiée : montants, barreaux tous les 0,09."""
    out = V(out).normalized()
    t = V((-out.y, out.x, 0))
    base = V(base)
    for s in (-1, 1):
        g.box(base + t * s * w / 2 + V((0, 0, (z0 + z1) / 2)), (0.03, 0.03, z1 - z0), M["steel_hi"], "hard",
              R=Rm(t), what="montant")
    n = max(2, int((z1 - z0) / 0.09))
    for i in range(1, n):
        z = z0 + (z1 - z0) * i / n
        g.cyl(base + V((0, 0, z)), t, 0.016, w, M["steel_hi"], n=6, style="hard", what="barreau")


def handwheel(g, c, axis, r, M, mat=None):
    """Vanne à volant : tige, volant (tore), rayons, moyeu."""
    a, u, w = basis(V(axis))
    c = V(c)
    g.cyl(c - a * 0.05, a, 0.022, 0.1, M["steel_dk"], n=8, what="tige")
    g.torus(c, a, r, max(0.016, r * 0.18), mat or M["redpaint"], n=20, m=6, what="volant")
    for k in range(3):
        ang = TAU * k / 3 + 0.3
        d = u * math.cos(ang) + w * math.sin(ang)
        g.cyl(c + d * r / 2, d, 0.012, r, mat or M["redpaint"], n=6, what="rayon")
    g.cyl(c, a, 0.025, 0.04, M["brass"], n=8, what="moyeu")


def gauge(g, p, nrm, r, M, face=None):
    """Manomètre : boîtier laiton, cadran clair (ou lumineux), aiguille."""
    a, u, w = basis(V(nrm))
    p = V(p)
    g.cyl(p + a * 0.015, a, r, 0.03, M["brass"], n=14, style="hard", what="manometre")
    g.cyl(p + a * 0.032, a, r * 0.78, 0.006, face or M["dial"], n=14, style="flat", what="cadran")
    g.box(p + a * 0.037 + (u * 0.4 + w * 0.3) * r * 0.5, (r * 0.7, 0.014, 0.006), M["seam"], "flat",
          R=Matrix((u * 0.8 + w * 0.6, a.cross(u * 0.8 + w * 0.6), a)).transposed(), what="aiguille")


def stencil(g, q, n, mat, t=0.004):
    """Marquages au pochoir (rangée de n petits blocs) sur une face q (vers l'extérieur)."""
    q = [V(x) for x in q]
    for i in range(n):
        s0 = (i + 0.15) / n
        s1 = (i + 0.8) / n
        g.slab(PT.face_quad(q, s0, s1, 0.2, 0.8), (q[1] - q[0]).cross(q[3] - q[0]), t, mat, "flat", "pochoir")


def dome_hull(g, c, rx, ry, rz, mat, M, n=56, m=12, seams=12, seam_mat=None, band_mat=None, rivet_step=0.11,
              skip_seams=(), ring_seams=()):
    """Coupole rivetée (demi-ellipsoïde) : coque, nervures méridiennes rivetées, bourrelet à l'équateur.
    Le dégradé de lumière d'une coque ronde donne le volume (réacteur vanilla)."""
    c = V(c)
    vs, fs = [], []
    for k in range(m):
        ph = (math.pi / 2) * k / m
        for j in range(n):
            th = TAU * j / n
            vs.append((c.x + rx * math.cos(ph) * math.cos(th), c.y + ry * math.cos(ph) * math.sin(th),
                       c.z + rz * math.sin(ph)))
    vs.append((c.x, c.y, c.z + rz))
    top = len(vs) - 1
    for k in range(m - 1):
        for j in range(n):
            j2 = (j + 1) % n
            fs.append((k * n + j, k * n + j2, (k + 1) * n + j2, (k + 1) * n + j))
    for j in range(n):
        j2 = (j + 1) % n
        fs.append(((m - 1) * n + j, (m - 1) * n + j2, top))
    fs.append(tuple(range(n))[::-1])
    g._add(mat, "smooth", vs, fs, "coupole")

    def P(th, ph, k=1.0):
        return c + V((rx * k * math.cos(ph) * math.cos(th), ry * k * math.cos(ph) * math.sin(th), rz * k * math.sin(ph)))

    def N(th, ph):
        q = P(th, ph) - c
        return V((q.x / rx ** 2, q.y / ry ** 2, q.z / rz ** 2)).normalized()
    sm = seam_mat or M["steel_dk"]
    for j in range(seams):
        if j in skip_seams:
            continue
        th = TAU * (j + 0.5) / seams
        pts = [P(th, 1.38 * i / 16, 1.006) for i in range(17)]
        g.tube(pts, 0.016, sm, n=6, what="nervure")
        L = sum((pts[i + 1] - pts[i]).length for i in range(16))
        k = max(3, int(L / rivet_step))
        for i in range(k):
            ph = 1.3 * (i + 0.5) / k
            g.dome(P(th, ph, 1.006) + N(th, ph) * 0.012, N(th, ph), 0.016, M["rivet"])
    # ceinture rivetée à mi-hauteur
    for phr in ring_seams:
        pts = [P(TAU * i / 64, phr, 1.008) for i in range(65)]
        g.tube(pts, 0.014, sm, n=6, caps=False, what="ceinture")
        nb = int(TAU * rx * math.cos(phr) / 0.12)
        for i in range(nb):
            th = TAU * (i + 0.5) / nb
            g.dome(P(th, phr, 1.008) + N(th, phr) * 0.012, N(th, phr), 0.015, M["rivet"])
    # bourrelet de l'équateur
    pts = [P(TAU * i / 64, 0.04, 1.01) for i in range(65)]
    g.tube(pts, 0.03, band_mat or M["steel_dk"], n=8, caps=False, what="bourrelet")
    nb = int(TAU * rx / 0.14)
    for i in range(nb):
        th = TAU * (i + 0.5) / nb
        g.dome(P(th, 0.04, 1.04), N(th, 0.04), 0.016, M["rivet"])
    return P, N


def applique(g, P, N, th, ph, w, h, mat, M, bolts=4):
    """Plaque de blindage rapportée sur une coque (repère tangent), boulonnée aux coins."""
    p = P(th, ph, 1.0)
    n = N(th, ph)
    tdir = V((-math.sin(th), math.cos(th), 0.0))
    g.push_frame(p + n * 0.02, n, tdir)
    g.box((0, 0, 0.02), (w, h, 0.045), mat, "hard", what="applique")
    if bolts:
        for sx in (-1, 1):
            for sy in (-1, 1):
                g.bolt((sx * (w / 2 - 0.045), sy * (h / 2 - 0.045), 0.042), (0, 0, 1), 0.018, M["steel_hi"])
    g.pop()


def tank(g, c, r, L, axis, M, paint=None, band=None, gauges=None, window=None):
    """Réservoir horizontal cerclé : virole peinte, fonds bombés, cerclages laiton, berceaux, trou d'homme,
    manomètre, fenêtre de niveau (lumineuse)."""
    a = V(axis).normalized()
    c = V(c)
    paint = paint or M["cream"]
    g.cyl(c, a, r, L, paint, n=32, style="smooth", what="reservoir")
    for s in (-1, 1):
        g.cyl(c + a * s * (L / 2 + r * 0.12), a * s, r * 0.94, r * 0.24, paint, n=32, r2=r * 0.5, style="smooth",
              what="fond")
        g.tube_shell(c + a * s * (L / 2 - 0.02), a, r + 0.018, r - 0.02, 0.05, M["steel_dk"], n=32, what="bride")
        nb = 10
        _, u, w = basis(a)
        for k in range(nb):
            ang = TAU * k / nb
            d = u * math.cos(ang) + w * math.sin(ang)
            if d.z < -0.3:
                continue
            g.dome(c + a * s * (L / 2 - 0.02) + d * (r + 0.02), d, 0.015, M["rivet"])
    nbands = max(2, int(L / 0.45))
    for i in range(nbands):
        f = -0.5 + (i + 0.5) / nbands
        g.tube_shell(c + a * f * L, a, r + 0.02, r - 0.02, 0.045, band or M["brass"], n=32, what="cerclage")
    side = V((0, 0, 1)).cross(a).normalized()
    for f in (-0.33, 0.33):
        p = c + a * f * L
        g.box(p - V((0, 0, r * 0.7)), (0.07 if abs(a.x) < 0.5 else r * 1.7, r * 1.7 if abs(a.x) < 0.5 else 0.07,
                                         (c.z - r * 0.7) * 2 if c.z > r * 0.7 else 0.1),
              M["steel_dk"], "hard", what="berceau")
    g.cyl(c + V((0, 0, r + 0.03)) + a * L * 0.12, (0, 0, 1), r * 0.3, 0.07, M["steel_dk"], n=14, what="trou_homme")
    for k in range(8):
        ang = TAU * k / 8
        g.dome(c + V((0, 0, r + 0.067)) + a * L * 0.12 + V((math.cos(ang), math.sin(ang), 0)) * r * 0.24,
               (0, 0, 1), 0.014, M["rivet"])
    for k in range(gauges or 0):
        p = c + a * (-L * 0.32 + k * 0.2) + V((0, 0, r + 0.05))
        g.cyl(p - V((0, 0, 0.03)), (0, 0, 1), 0.015, 0.06, M["steel_dk"], n=6, what="piquage")
        gauge(g, p + V((0, 0, 0.02)), (0, -0.6, 0.8), 0.045, M)
    if window is not None:
        # fenêtre de niveau : fente lumineuse le long de l'axe, sur le flanc ouest (éclairé), cadre acier
        s = a.cross(V((0, 0, 1))).normalized()
        if s.x > 0:
            s = -s
        p = c + s * (r + 0.004) + a * L * 0.18
        g.box(p, (L * 0.36, 0.014, 0.04), window, "flat", R=Rm(a), what="niveau")
        g.box(p + s * 0.006 + V((0, 0, 0.035)), (L * 0.4, 0.02, 0.022), M["steel_hi"], "hard", R=Rm(a), what="cadre")
        g.box(p + s * 0.006 - V((0, 0, 0.035)), (L * 0.4, 0.02, 0.022), M["steel_hi"], "hard", R=Rm(a), what="cadre")


def engine(g, x0, x1, y0, y1, z0, z1, ncyl, M, axis="y", flywheel=True, emat=None):
    """Groupe électrogène : carter à plaques, rangée de culasses peintes (cache-culbuteurs nervurés),
    collecteur d'échappement vers un silencieux et une cheminée courte, volant à rayons, rampe d'injection."""
    PT.hull(g, x0, x1, y0, y1, z0, z1, ins=(0.05, 0.03, 0.03), panel=0.32, mats=[M["olive"], M["steel_dk"]],
            rivet_step=0.14)
    cx = (x0 + x1) / 2
    wx = x1 - x0
    L = (y1 - y0) - 0.24
    pitch = L / ncyl
    zt = z1
    for i in range(ncyl):
        y = y0 + 0.12 + pitch * (i + 0.5)
        g.box((cx - wx * 0.08, y, zt + 0.06), (wx * 0.42, pitch * 0.78, 0.12), M["redpaint"], "soft", what="culasse")
        for k in range(3):
            g.box((cx - wx * 0.08 + (k - 1) * wx * 0.12, y, zt + 0.125), (0.03, pitch * 0.66, 0.02), M["redpaint"],
                  "hard", what="nervure")
        for sy in (-1, 1):
            g.bolt((cx - wx * 0.28, y + sy * pitch * 0.3, zt + 0.12), (0, 0, 1), 0.016, M["steel_hi"])
        # tubulure d'échappement vers l'est (côté x1)
        g.tube([V((cx + wx * 0.12, y, zt + 0.06)), V((cx + wx * 0.24, y, zt + 0.12)), V((cx + wx * 0.3, y, zt + 0.2))],
               0.03, M["soot"], n=8, what="tubulure")
        # injecteur + tuyau vers la rampe
        g.cyl((cx - wx * 0.3, y, zt + 0.1), "z", 0.018, 0.08, M["brass"], n=6, what="injecteur")
    g.cyl((cx - wx * 0.38, (y0 + y1) / 2, zt + 0.08), "y", 0.022, L, M["copper"], n=8, what="rampe")
    # silencieux le long de l'axe, cheminée courte à chapeau
    zm = zt + 0.26
    g.cyl((cx + wx * 0.3, (y0 + y1) / 2, zm), "y", 0.1, L * 0.92, M["soot"], n=20, style="smooth", what="silencieux")
    for f in (-0.36, 0.0, 0.36):
        g.tube_shell((cx + wx * 0.3, (y0 + y1) / 2 + f * L, zm), "y", 0.118, 0.08, 0.035, M["steel_dk"], n=20,
                     what="collier")
    ys = y1 - 0.25
    g.cyl((cx + wx * 0.3, ys, zm + 0.2), "z", 0.06, 0.32, M["soot"], n=14, what="cheminee")
    g.tube_shell((cx + wx * 0.3, ys, zm + 0.3), "z", 0.075, 0.05, 0.04, M["brass"], n=14, what="bague")
    g.box((cx + wx * 0.3, ys, zm + 0.39), (0.16, 0.16, 0.02), M["steel_dk"], "hard", what="chapeau")
    # trappes de visite boulonnées sur le flanc ouest
    for i in range(max(1, ncyl // 2)):
        y = y0 + 0.2 + (L - 0.1) * (i + 0.5) / max(1, ncyl // 2)
        g.box((x0 - 0.012, y, (z0 + z1) * 0.5), (0.03, 0.26, (z1 - z0) * 0.45), M["steel_dk"], "hard", what="trappe")
        for sy in (-1, 1):
            for sz in (-1, 1):
                g.dome((x0 - 0.03, y + sy * 0.1, (z0 + z1) * 0.5 + sz * (z1 - z0) * 0.17), (-1, 0, 0), 0.014,
                       M["rivet"])
    if emat is not None:
        for i in range(ncyl):
            y = y0 + 0.12 + pitch * (i + 0.5)
            g.cyl((cx - wx * 0.3, y + pitch * 0.25, zt + 0.15), "z", 0.026, 0.012, emat, n=10, style="flat",
                  what="voyant")
        g.box((cx, y0 - 0.006, (z0 + z1) * 0.78), (wx * 0.6, 0.012, 0.03), emat, "flat", what="fente")
    if flywheel:
        yf = y0 - 0.08
        g.cyl((cx, yf, (z0 + z1) * 0.55), "y", (z1 - z0) * 0.48, 0.08, M["steel_dk"], n=36, style="soft",
              what="volant")
        g.tube_shell((cx, yf - 0.01, (z0 + z1) * 0.55), "y", (z1 - z0) * 0.48, (z1 - z0) * 0.4, 0.1, M["steel_hi"],
                     n=36, what="jante")
        for k in range(6):
            ang = TAU * k / 6
            d = V((math.cos(ang), 0, math.sin(ang)))
            g.box(V((cx, yf - 0.05, (z0 + z1) * 0.55)) + d * (z1 - z0) * 0.22, (0.04, 0.03, (z1 - z0) * 0.4),
                  M["steel_dk"], "hard", R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed(), what="rayon")
        g.cyl((cx, yf - 0.07, (z0 + z1) * 0.55), "y", 0.06, 0.06, M["brass"], n=12, what="moyeu")


def fan_radiator(g, x0, x1, y0, y1, z0, z1, nfan, M, fin_mat=None, emat=None):
    """Bloc radiateur à ventilateurs VUS DE DESSUS : caisson à ailettes, viroles, pales, grille de garde."""
    PT.hull(g, x0, x1, y0, y1, z0, z1, ins=(0.02, 0.02, 0.02), panel=0.3, mats=[M["steel_dk"], M["olive"]],
            faces="sewn", rivet_step=0.14)
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, z1 - 0.01), (x1 - x0 - 0.02, y1 - y0 - 0.02, 0.02), M["void"], "flat",
          what="fond")
    # ailettes sur la face sud
    n = int((x1 - x0 - 0.1) / 0.045)
    for i in range(n):
        x = x0 + 0.05 + (x1 - x0 - 0.1) * (i + 0.5) / n
        g.box((x, y0 - 0.02, (z0 + z1) / 2), (0.016, 0.04, (z1 - z0) * 0.7), fin_mat or M["steel_hi"], "hard",
              what="ailette")
    along_x = (x1 - x0) >= (y1 - y0)
    for k in range(nfan):
        if along_x:
            cx = x0 + (x1 - x0) * (k + 0.5) / nfan
            cy = (y0 + y1) / 2
            r = min((x1 - x0) / nfan, (y1 - y0)) * 0.42
        else:
            cx = (x0 + x1) / 2
            cy = y0 + (y1 - y0) * (k + 0.5) / nfan
            r = min((y1 - y0) / nfan, (x1 - x0)) * 0.42
        g.tube_shell((cx, cy, z1 + 0.03), "z", r + 0.04, r, 0.08, M["steel_dk"], n=36, what="virole")
        for b in range(7):
            ang = TAU * b / 7 + 0.2 * k
            d = V((math.cos(ang), math.sin(ang), 0))
            R = Matrix((d, V((-d.y, d.x, 0)), V((0, 0, 1)))).transposed() @ Matrix.Rotation(0.5, 3, "X")
            g.box(V((cx, cy, z1 + 0.02)) + d * r * 0.55, (r * 0.85, r * 0.3, 0.012), M["steel_hi"], "hard", R=R,
                  what="pale")
        g.cyl((cx, cy, z1 + 0.04), "z", r * 0.2, 0.05, M["redpaint"], n=16, what="moyeu")
        if emat is not None:
            g.cyl((cx, cy, z1 + 0.068), "z", r * 0.08, 0.008, emat, n=10, style="flat", what="voyant")
        for ang in (0.0, math.pi / 2):
            d = V((math.cos(ang), math.sin(ang), 0))
            g.box((cx, cy, z1 + 0.075), (2 * r + 0.06, 0.022, 0.018), M["steel_dk"], "hard", R=Rm(d), what="garde")
        g.torus((cx, cy, z1 + 0.075), "z", r * 0.62, 0.012, M["steel_dk"], n=24, m=4, what="garde")
    for xx in (x0 + 0.05, x1 - 0.05):
        g.cyl((xx, (y0 + y1) / 2, z1 + 0.02), "y", 0.035, y1 - y0, M["copper"], n=10, what="collecteur")


def hopper(g, x0, x1, y0, y1, z0, z1, M, slope=0.35, paint=None):
    """Trémie à munitions : caisson peint à dessus incliné vers le nord, nervures, bande de danger, porte,
    marquages."""
    paint = paint or M["ochre"]
    zl = z1 - slope * (y1 - y0) * 0.4
    B = [V((x0, y0, z0)), V((x1, y0, z0)), V((x1, y1, z0)), V((x0, y1, z0))]
    T = [V((x0, y0, zl)), V((x1, y0, zl)), V((x1, y1, z1)), V((x0, y1, z1))]
    g.hexa(B + T, M["seam"], "flat", "tremie")
    faces = {"s": [B[0], B[1], T[1], T[0]], "e": [B[1], B[2], T[2], T[1]], "w": [B[3], B[0], T[0], T[3]],
             "t": [T[0], T[1], T[2], T[3]]}
    for f, q in faces.items():
        lu = (q[1] - q[0]).length
        lv = (q[3] - q[0]).length
        g.panels(q, max(1, int(round(lu / 0.3))), max(1, int(round(lv / 0.3))), paint, t=0.026,
                 rivet_mat=M["rivet"], mats=[paint, paint, M["olive"]], rivet_step=0.13)
    # bande de danger en haut de la face sud
    s = faces["s"]
    g.hazard(PT.lift(PT.face_quad(s, 0.0, 1.0, 0.8, 0.97), 0.03), max(4, int((x1 - x0) / 0.1)))
    # nervures verticales
    nr = max(2, int((x1 - x0) / 0.28))
    for i in range(nr + 1):
        x = x0 + (x1 - x0) * i / nr
        g.box((x, y0 - 0.02, (z0 + zl) / 2), (0.035, 0.04, zl - z0), M["steel_dk"], "hard", what="nervure")
    # porte de visite + poignées, marquages
    xd = (x0 + x1) / 2
    g.box((xd, y0 - 0.035, z0 + (zl - z0) * 0.42), ((x1 - x0) * 0.36, 0.02, (zl - z0) * 0.5), M["steel_dk"], "hard",
          what="porte")
    for sx in (-1, 1):
        g.box((xd + sx * (x1 - x0) * 0.12, y0 - 0.06, z0 + (zl - z0) * 0.42), (0.025, 0.03, 0.1), M["steel_hi"],
              "hard", what="poignee")
    stencil(g, PT.lift(PT.face_quad(s, 0.06, 0.3, 0.5, 0.66), 0.03), 3, M["dial"])
    return T


def open_crate(g, c, sx, sy, sz, M, paint=None, pitch=0.07):
    """Caisse de munitions OUVERTE : parois peintes cerclées, rangées de cartouches laiton à pointe cuivre
    (des dizaines de petites pièces, lisibles comme « munitions » au premier regard)."""
    paint = paint or M["olive"]
    cx, cy, cz = c
    t = 0.035
    for (px, py, w, d) in ((cx, cy - sy / 2 + t / 2, sx, t), (cx, cy + sy / 2 - t / 2, sx, t),
                           (cx - sx / 2 + t / 2, cy, t, sy), (cx + sx / 2 - t / 2, cy, t, sy)):
        g.box((px, py, cz + sz / 2), (w, d, sz), paint, "hard", what="paroi")
    g.box((cx, cy, cz + sz * 0.45), (sx - 2 * t, sy - 2 * t, sz * 0.9), M["seam"], "flat", what="fond")
    for yy in (cy - sy / 2 - 0.008, cy + sy / 2 + 0.008):
        for zz in (cz + 0.05, cz + sz - 0.05):
            g.box((cx, yy, zz), (sx * 1.0, 0.016, 0.03), M["steel_dk"], "hard", what="cerclage")
    nx = max(1, int((sx - 2 * t - 0.01) / pitch))
    ny = max(1, int((sy - 2 * t - 0.01) / pitch))
    for i in range(nx):
        for j in range(ny):
            x = cx - (nx - 1) * pitch / 2 + i * pitch
            y = cy - (ny - 1) * pitch / 2 + j * pitch
            z = cz + sz * 0.9 - 0.02 + 0.012 * ((i * 7 + j * 3) % 3)
            g.cyl((x, y, z), "z", 0.022, 0.06, M["brass"], n=8, what="etui")
            g.cyl((x, y, z + 0.045), "z", 0.017, 0.03, M["copper"], n=8, r2=0.006, what="balle")
    # couvercle rabattu contre la face nord
    g.box((cx, cy + sy / 2 + 0.03, cz + sz + 0.12), (sx * 0.96, 0.03, 0.26), paint, "hard",
          R=Matrix.Rotation(-0.25, 3, "X"), what="couvercle")
    g.cyl((cx, cy + sy / 2 + 0.01, cz + sz), "x", 0.016, sx * 0.8, M["brass"], n=8, what="charniere")
    for sxn in (-1, 1):
        g.box((cx + sxn * (sx / 2 + 0.015), cy, cz + sz * 0.62), (0.025, sy * 0.36, 0.035), M["steel_hi"], "hard",
              what="poignee")


def feed_chute(g, ctrl, w, M, step=0.06):
    """Goulotte articulée (alimentation de bande) : maillons en U le long d'une courbe, cartouches visibles."""
    P = g.resample(g.spline(ctrl, 14), step)
    T, _ = g.frames(P)
    for i, p in enumerate(P):
        t = T[i]
        side = t.cross(V((0, 0, 1)))
        if side.length < 1e-3:
            side = V((1, 0, 0))
        side.normalize()
        up = side.cross(t).normalized()
        R = Matrix((side, t, up)).transposed()
        g.box(p - up * 0.03, (w, step * 0.8, 0.02), M["steel_dk"], "hard", R=R, what="maillon")
        for s in (-1, 1):
            g.box(p + side * s * (w / 2), (0.022, step * 0.82, 0.08), M["steel_dk"] if i % 2 else M["olive"], "hard",
                  R=R, what="joue")
        g.cyl(p + up * 0.005, side, 0.02, w * 0.8, M["brass"], n=6, what="cartouche")
        if i % 3 == 0:
            g.dome(p + side * (w / 2 + 0.012), side, 0.013, M["rivet"])
            g.dome(p - side * (w / 2 + 0.012), -side, 0.013, M["rivet"])


def anchor(g, x, y, s, M):
    """Patin d'ancrage boulonné au sol."""
    g.box((x, y, 0.035), (s, s * SQ2, 0.07), M["steel_dk"], "hard", what="patin")
    for kx in (-1, 1):
        for ky in (-1, 1):
            g.bolt((x + kx * s * 0.34, y + ky * s * SQ2 * 0.34, 0.07), (0, 0, 1), 0.024, M["steel_hi"])


def cable_tray(g, ctrl, n, M, mats):
    """Chemin de câbles : goulotte, faisceau de câbles, colliers."""
    PT.cable_run(g, ctrl, n, 0.02, 0.045, mats)


def pipe_valve(g, ctrl, r, M, valve_at=None, mat=None):
    """Tuyauterie à brides boulonnées, vanne à volant facultative."""
    g.pipe(ctrl, r, mat or M["copper"], fl_mat=M["brass"], bolt_mat=M["rivet"])
    if valve_at is not None:
        p, ax = valve_at
        g.box(p, (r * 3.2, r * 3.2, r * 3.2), M["steel_dk"], "hard", what="corps_vanne")
        handwheel(g, V(p) + V(ax).normalized() * (r * 1.6 + 0.06), ax, 0.07, M)


def capacitor_bank(g, c, nx, ny, r, h, emat, M):
    """Réserve d'énergie visible (ère V) : condensateurs debout cerclés laiton, couronne lumineuse, barres."""
    PT.capacitors(g, c, nx, ny, r, h, emat)


def power_cell(g, c, r, h, emat, M):
    """Cellule d'énergie blindée (pièce du niveau 30) : fût cerclé à hublots lumineux, cage, câbles, danger."""
    x, y, z = c
    g.cyl((x, y, z + h / 2), "z", r, h, M["steel_dk"], n=28, style="soft", what="cellule")
    for f in (0.06, 0.5, 0.94):
        g.tube_shell((x, y, z + h * f), "z", r + 0.022, r - 0.01, 0.05, M["brass"], n=28, what="cerclage")
    for k in range(6):
        ang = TAU * (k + 0.5) / 6
        d = V((math.cos(ang), math.sin(ang), 0))
        if d.y > 0.5:
            continue
        g.box(V((x, y, z + h * 0.28)) + d * (r + 0.004), (0.06, 0.012, h * 0.3), emat, "flat",
              R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="hublot")
        g.box(V((x, y, z + h * 0.72)) + d * (r + 0.004), (0.06, 0.012, h * 0.3), emat, "flat",
              R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="hublot")
    for k in range(8):
        ang = TAU * k / 8
        d = V((math.cos(ang), math.sin(ang), 0))
        g.box(V((x, y, z + h / 2)) + d * (r + 0.035), (0.03, 0.03, h * 0.98), M["steel_hi"], "hard", what="cage")
    g.cyl((x, y, z + h + 0.03), "z", r * 0.8, 0.06, M["olive"], n=24, style="soft", what="chapeau")
    g.hazard([V((x - r, y - r - 0.05, z + h + 0.062)), V((x + r, y - r - 0.05, z + h + 0.062)),
              V((x + r, y - r * 0.2, z + h + 0.062)), V((x - r, y - r * 0.2, z + h + 0.062))], 5, t=0.012)
    g.cyl((x, y, z + h + 0.09), "z", r * 0.25, 0.06, M["copper"], n=10, what="borne")
