"""Pièces du 3e passage « industriel lourd » (reprise du 22/10) : réservoirs DEBOUT (volumes ronds vus de dessus,
comme le réacteur), armoire de commande à voyants, conduits d'énergie à bagues lumineuses, rangées de voyants,
trémie à trappe ouverte. S'exécute DANS Blender.
"""
import math

from mathutils import Matrix, Vector

import parts as PT
import parts2 as P2
from kit import SQ2, TAU, basis

V = Vector


def vtank(g, x, y, r, h, M, paint=None, emat=None, z0=0.0, ladder_dir=(-1.0, 0.0), gauges=2, stub_dir=None,
          glow_gauges=False, glow_rings=0, band=None):
    """Réservoir debout : socle boulonné, virole peinte cerclée de laiton, fond bombé riveté, trou d'homme,
    évent en col de cygne, échelle, manomètres, fenêtre de niveau lumineuse, piquage à bride."""
    paint = paint or M["cream"]
    band = band or M["brass"]
    g.cyl((x, y, z0 + 0.04), "z", r + 0.07, 0.08, M["steel_dk"], n=32, style="soft", what="socle")
    nb = int(TAU * (r + 0.05) / 0.12)
    for k in range(nb):
        a = TAU * k / nb
        g.bolt((x + (r + 0.045) * math.cos(a), y + (r + 0.045) * math.sin(a), z0 + 0.08), (0, 0, 1), 0.016,
               M["steel_hi"])
    zb, zt = z0 + 0.08, z0 + h
    g.cyl((x, y, (zb + zt) / 2), "z", r, zt - zb, paint, n=40, style="smooth", what="virole")
    nband = max(2, int((zt - zb) / 0.28))
    for i in range(nband):
        zz = zb + (zt - zb) * (i + 0.5) / nband
        g.tube_shell((x, y, zz), "z", r + 0.018, r - 0.01, 0.04, band if i % 2 == 0 else M["steel_dk"], n=40,
                     what="cerclage")
        nr = int(TAU * r / 0.12)
        for k in range(nr):
            a = TAU * (k + 0.5 * (i % 2)) / nr
            d = V((math.cos(a), math.sin(a), 0))
            if d.y > 0.6:
                continue
            g.dome(V((x, y, zz)) + d * (r + 0.02), d, 0.013, M["rivet"])
    # soudures verticales
    for k in range(6):
        a = TAU * (k + 0.25) / 6
        d = V((math.cos(a), math.sin(a), 0))
        if d.y > 0.5:
            continue
        g.box(V((x, y, (zb + zt) / 2)) + d * (r + 0.004), (0.022, 0.012, zt - zb - 0.04), M["steel_dk"], "hard",
              R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="soudure")
    P, N = P2.dome_hull(g, (x, y, zt), r, r, r * 0.42, paint, M, n=40, m=8, seams=8, seam_mat=M["steel_dk"],
                        band_mat=band, rivet_step=0.1)
    g.cyl((x + r * 0.3, y - r * 0.2, zt + r * 0.38), "z", r * 0.24, 0.06, M["steel_dk"], n=16, what="trou_homme")
    for k in range(6):
        a = TAU * k / 6
        g.dome((x + r * 0.3 + r * 0.19 * math.cos(a), y - r * 0.2 + r * 0.19 * math.sin(a), zt + r * 0.41), (0, 0, 1),
               0.013, M["rivet"])
    # évent en col de cygne
    g.tube([V((x - r * 0.25, y + r * 0.25, zt + r * 0.3)), V((x - r * 0.25, y + r * 0.25, zt + r * 0.3 + 0.16)),
            V((x - r * 0.25 + 0.06, y + r * 0.25, zt + r * 0.3 + 0.22)), V((x - r * 0.25 + 0.12, y + r * 0.25,
                                                                           zt + r * 0.3 + 0.16))],
           0.022, M["steel_hi"], n=8, what="event")
    # gousset plein sous le col de cygne (lot V3-E : le sol se voyait sous l'arc, trou enfermé de 9 px hr)
    g.box((x - r * 0.25 + 0.06, y + r * 0.25, zt + r * 0.3 + 0.085), (0.12, 0.016, 0.15), M["steel_dk"], "hard",
          what="gousset")
    ld = V((ladder_dir[0], ladder_dir[1], 0)).normalized()
    P2.ladder(g, V((x, y, 0)) + ld * (r + 0.06), ld, z0 + 0.08, zt + r * 0.2, 0.16, M)
    for k in range(gauges):
        a = -math.pi / 2 + (k - (gauges - 1) / 2) * 0.55
        d = V((math.cos(a), math.sin(a), 0))
        P2.gauge(g, V((x, y, zb + (zt - zb) * 0.62)) + d * (r + 0.03), d, 0.05, M,
                 face=emat if (glow_gauges and emat is not None) else None)
    if emat is not None:
        a = -math.pi / 2 - 0.75
        d = V((math.cos(a), math.sin(a), 0))
        Rr = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
        g.box(V((x, y, (zb + zt) / 2)) + d * (r + 0.006), (0.035, 0.012, (zt - zb) * 0.55), emat, "flat", R=Rr,
              what="niveau")
        for s in (-1, 1):
            g.box(V((x, y, (zb + zt) / 2)) + d * (r + 0.012) + V((-d.y, d.x, 0)) * s * 0.03,
                  (0.02, 0.02, (zt - zb) * 0.6), M["steel_hi"], "hard", R=Rr, what="cadre")
    for i in range(glow_rings):
        # anneau d'état lumineux (énergie visible, ères IV-V), entre deux cerclages
        zz = zb + (zt - zb) * (0.3 + 0.4 * i / max(1, glow_rings - 1)) if glow_rings > 1 else zb + (zt - zb) * 0.45
        g.tube_shell((x, y, zz), "z", r + 0.008, r - 0.01, 0.022, emat, n=40, what="anneau_lum")
    if stub_dir is not None:
        d = V((stub_dir[0], stub_dir[1], 0)).normalized()
        p = V((x, y, z0 + 0.25)) + d * r
        g.cyl(p + d * 0.08, d, 0.05, 0.16, M["copper"], n=12, what="piquage")
        g.cyl(p + d * 0.17, d, 0.075, 0.035, band, n=14, style="hard", what="bride")
    return P, N


def lamp_row(g, p0, p1, n, nrm, emat, M, size=0.034):
    """Rangée de voyants à visière (repère du silo et du roboport vanilla)."""
    p0, p1 = V(p0), V(p1)
    a, u, w = basis(V(nrm))
    for i in range(n):
        p = p0.lerp(p1, (i + 0.5) / n)
        g.cyl(p + a * 0.01, a, size * 0.95, 0.02, M["steel_dk"], n=10, style="hard", what="bague")
        g.cyl(p + a * 0.022, a, size * 0.62, 0.006, emat, n=10, style="flat", what="voyant")


def conduit(g, ctrl, r, M, emat, step=0.2):
    """Conduit d'énergie blindé : gaine sombre, bagues lumineuses régulières (énergie visible), colliers."""
    P = g.spline(ctrl, 10)
    P, T = g.tube(P, r, M["steel_dk"], n=10, what="conduit")
    R = g.resample(P, step)
    T2, _ = g.frames(R)
    for i in range(1, len(R) - 1):
        if i % 2:
            g.tube_shell(R[i], T2[i], r + 0.008, r * 0.5, 0.035, emat, n=12, what="bague_lum")
        else:
            g.tube_shell(R[i], T2[i], r + 0.016, r * 0.5, 0.03, M["brass"], n=12, what="collier")


def lamp_group(g, p, along, nrm, emat, M, n=3, size=0.03, shapes=None, gaps=(0.0, 0.07, 0.16)):
    """Groupe de voyants (catalogue V3-E §A.6 : jamais plus de 3 voyants alignés, espacements inégaux, formes
    mêlées : rond, carré, fente). p : premier voyant ; along : direction de la rangée ; nrm : normale de la face."""
    p = V(p)
    al = V(along).normalized()
    a, u, w = basis(V(nrm))
    shapes = shapes or ("rond", "carre", "fente")
    for i in range(min(3, n)):
        q = p + al * gaps[i] * (size / 0.03)
        sh = shapes[i % len(shapes)]
        Rr = Matrix((al, a.cross(al).normalized(), a)).transposed()
        if sh == "rond":
            g.cyl(q + a * 0.01, a, size * 0.95, 0.02, M["steel_dk"], n=10, style="hard", what="bague")
            g.cyl(q + a * 0.022, a, size * 0.62, 0.006, emat, n=10, style="flat", what="voyant")
        elif sh == "carre":
            g.box(q + a * 0.01, (size * 1.8, size * 1.8, 0.02), M["steel_dk"], "hard", R=Rr, what="bague")
            g.box(q + a * 0.022, (size * 1.1, size * 1.1, 0.006), emat, "flat", R=Rr, what="voyant")
        else:
            g.box(q + a * 0.01, (size * 3.0, size * 1.3, 0.02), M["steel_dk"], "hard", R=Rr, what="bague")
            g.box(q + a * 0.022, (size * 2.3, size * 0.55, 0.006), emat, "flat", R=Rr, what="voyant")


def screen(g, p, nrm, w, h, M, emat=None):
    """Petit écran (haute technologie et après, ≤ 0,02 t²) : cadre noir mat, dalle sombre, 1 ligne lumineuse."""
    p = V(p)
    a, u, w_ = basis(V(nrm))
    up = V((0, 0, 1))
    side = up.cross(a)
    if side.length < 1e-3:
        side = V((1, 0, 0))
    side.normalize()
    upv = a.cross(side).normalized()
    Rr = Matrix((side, upv, a)).transposed()
    g.box(p + a * 0.012, (w + 0.03, h + 0.03, 0.024), M["matte"], "hard", R=Rr, what="ecran_cadre")
    g.box(p + a * 0.026, (w, h, 0.004), M.get("spec", M["seam"]), "flat", R=Rr, what="ecran")
    if emat is not None:
        g.box(p + a * 0.03 + upv * h * 0.2, (w * 0.6, 0.012, 0.003), emat, "flat", R=Rr, what="ecran_ligne")


def cabinet(g, x0, x1, y0, y1, z0, z1, M, emat, rows=2, screen_=False):
    """Armoire de commande : caisson riveté, façade sud à GROUPES de voyants (≤ 3, formes mêlées), manomètres,
    poignées, toit ; écran facultatif (ères IV et V)."""
    PT.hull(g, x0, x1, y0, y1, z0, z1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=[M["olive"], M["steel_dk"]],
            rivet_step=0.12)
    w = x1 - x0
    for k in range(rows):
        zz = z0 + (z1 - z0) * (0.58 + 0.17 * k)
        x = x0 + 0.06 + (0.07 if k % 2 else 0.0)
        lamp_group(g, (x, y0 - 0.02, zz), (1, 0, 0), (0, -1, 0), emat if k == 0 else M["amber"], M,
                   n=3 if k == 0 else 2, shapes=("rond", "fente", "carre") if k == 0 else ("carre", "rond"))
    if screen_:
        screen(g, (x1 - w * 0.28, y0 - 0.015, z0 + (z1 - z0) * 0.66), (0, -1, 0), min(0.14, w * 0.3), 0.08, M, emat)
    P2.gauge(g, (x0 + w * 0.3, y0 - 0.02, z0 + (z1 - z0) * 0.3), (0, -1, 0.2), 0.045, M)
    P2.gauge(g, (x0 + w * 0.7, y0 - 0.02, z0 + (z1 - z0) * 0.3), (0, -1, 0.2), 0.045, M)
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, z1 + 0.02), (w + 0.06, y1 - y0 + 0.06, 0.03), M["steel_dk"], "hard",
          what="toit")


def hopper_top(g, x0, x1, y0, y1, z0, z1, M, slope=0.35, paint=None, stencils=True, belt_mats=None):
    """Trémie : grandes tôles peintes, trappe OUVERTE (bande de cartouches qui en sort), bande de danger,
    nervures, marquages. Renvoie le point de sortie de la bande. belt_mats (lot V3-E) : munitions de l'époque."""
    paint = paint or M["ochre"]
    zl = z1 - slope * (y1 - y0) * 0.4
    B = [V((x0, y0, z0)), V((x1, y0, z0)), V((x1, y1, z0)), V((x0, y1, z0))]
    T = [V((x0, y0, zl)), V((x1, y0, zl)), V((x1, y1, z1)), V((x0, y1, z1))]
    g.hexa(B + T, M["seam"], "flat", "tremie")
    faces = {"s": [B[0], B[1], T[1], T[0]], "e": [B[1], B[2], T[2], T[1]], "w": [B[3], B[0], T[0], T[3]]}
    for f, q in faces.items():
        lu = (q[1] - q[0]).length
        lv = (q[3] - q[0]).length
        g.panels(q, max(1, int(round(lu / 0.45))), max(1, int(round(lv / 0.4))), paint, t=0.026,
                 rivet_mat=M["rivet"], mats=[paint], rivet_step=0.12)
    top = [T[0], T[1], T[2], T[3]]
    nrm = (top[1] - top[0]).cross(top[3] - top[0]).normalized()
    # cadre périphérique du dessus et trappe ouverte au centre
    for qq in (PT.face_quad(top, 0.0, 1.0, 0.0, 0.2), PT.face_quad(top, 0.0, 1.0, 0.8, 1.0),
               PT.face_quad(top, 0.0, 0.2, 0.2, 0.8), PT.face_quad(top, 0.8, 1.0, 0.2, 0.8)):
        g.slab(qq, nrm, 0.03, paint, "hard", "cadre")
        for s, t in ((0.1, 0.5), (0.5, 0.5), (0.9, 0.5)):
            q4 = PT.face_quad(qq, s - 0.05, s + 0.05, t - 0.2, t + 0.2)
            c = (q4[0] + q4[2]) / 2
            g.dome(c + nrm * 0.03, nrm, 0.015, M["rivet"])
    hole = PT.face_quad(top, 0.2, 0.8, 0.2, 0.8)
    g.slab(hole, nrm, 0.004, M["void"], "flat", "trappe_fond")
    # bandes de cartouches couchées dans la trémie (rangées en zigzag)
    nrow = max(2, int((hole[3] - hole[0]).length / 0.085))
    for j in range(nrow):
        t = (j + 0.5) / nrow
        a = hole[0].lerp(hole[3], t) + nrm * 0.022
        b = hole[1].lerp(hole[2], t) + nrm * 0.022
        PT.belt(g, [a + (b - a) * 0.04, (a + b) / 2 + nrm * 0.01, b - (b - a) * 0.04], step=0.05, mats=belt_mats)
    # couvercle relevé vers le nord, charnière
    hn = PT.face_quad(top, 0.2, 0.8, 0.8, 0.84)
    hinge = (hn[0] + hn[1]) / 2
    g.cyl(hinge + nrm * 0.04, (1, 0, 0), 0.02, (x1 - x0) * 0.62, M["brass"], n=8, what="charniere")
    lid_w = (x1 - x0) * 0.6
    lid_d = (y1 - y0) * 0.5
    g.box(hinge + nrm * 0.05 + V((0, 0.03, lid_d * 0.45)), (lid_w, 0.03, lid_d * 0.9), paint, "hard",
          R=Matrix.Rotation(-0.35, 3, "X"), what="couvercle")
    for s in (-1, 1):
        g.box(hinge + nrm * 0.05 + V((s * lid_w * 0.36, 0.0, lid_d * 0.45)), (0.03, 0.05, lid_d * 0.85), M["steel_dk"],
              "hard", R=Matrix.Rotation(-0.35, 3, "X"), what="raidisseur")
    # bande de danger sur la face sud, nervures, porte, marquages
    s = faces["s"]
    g.hazard(PT.lift(PT.face_quad(s, 0.0, 1.0, 0.78, 0.96), 0.03), max(4, int((x1 - x0) / 0.1)))
    nr = max(2, int((x1 - x0) / 0.3))
    for i in range(nr + 1):
        x = x0 + (x1 - x0) * i / nr
        g.box((x, y0 - 0.02, (z0 + zl) / 2), (0.035, 0.04, zl - z0), M["steel_dk"], "hard", what="nervure")
    xd = (x0 + x1) / 2
    g.box((xd, y0 - 0.035, z0 + (zl - z0) * 0.4), ((x1 - x0) * 0.34, 0.02, (zl - z0) * 0.46), M["steel_dk"], "hard",
          what="porte")
    for sx in (-1, 1):
        g.box((xd + sx * (x1 - x0) * 0.12, y0 - 0.06, z0 + (zl - z0) * 0.4), (0.025, 0.03, 0.1), M["steel_hi"],
              "hard", what="poignee")
    if stencils:
        P2.stencil(g, PT.lift(PT.face_quad(s, 0.05, 0.28, 0.5, 0.66), 0.03), 3, M["dial"])
        P2.stencil(g, PT.lift(PT.face_quad(s, 0.72, 0.95, 0.5, 0.66), 0.03), 2, M["dial"])
    c = (hole[0] + hole[2]) / 2
    return c + nrm * 0.02
