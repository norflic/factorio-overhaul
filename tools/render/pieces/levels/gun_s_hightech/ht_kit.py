"""Kit de modules de l'explorateur « haute technologie » (lot V3-S) : briques mécaniques (Python pur), reprises du
premier essai (coupé à 8 h 55) et complétées. Chaque brique a une fonction lisible (charte §4.1) : cellule, radiateur,
caisse, conduite, pompe, réservoir, gaine annelée, goulotte, chemise de canon, tambour-chargeur, tourelle secondaire,
viseur. Repère : voir ht_geo.py.
"""
import math

import ht_geo as G
from ht_geo import TD, TAU, Rx, Ry, Rz

TONES = ("plate", "plate", "plate_l", "plate2")
AMBER = (1.0, 0.42, 0.04)
EPOCH_GLOW = {6: (0.12, 0.62, 1.0), 11: (0.52, 0.79, 1.0), 15: (1.0, 0.86, 0.50)}
FIN_YZ = G.np.array([[0, 0, 1.0], [1.0, 0, 0], [0, 1.0, 0]])

def capacitor(b, c, r, h, glow_slits=2, terminals=True):
    """Cellule de réserve d'énergie : fût cerclé, fenêtres de jauge lumineuses vers le sud (caméra), couvercle à
    bornes cuivre ; grille de protection sur les fenêtres."""
    x, y, z0 = c
    b.cyl("plate2", (x, y, z0 + 0.04), r + 0.05, 0.08, n=24, bev=0.01)
    b.cyl("body", (x, y, z0 + 0.08 + h / 2), r, h, n=28, bev=0.012)
    for t in (0.12, 0.5, 0.88):
        b.cyl("brass", (x, y, z0 + 0.08 + h * t), r + 0.018, 0.045, n=28, bev=0.006)
    # jauges RONDES (hublots cerclés, 3 par colonne) vers le sud : orifices, pas des fenêtres
    for k in range(glow_slits):
        a = -math.pi / 2 + (k - (glow_slits - 1) / 2) * 0.62
        n_ = G.np.array([math.cos(a), math.sin(a), 0.0])
        for zz in (0.3, 0.5, 0.7):
            p = G.np.array([x, y, z0 + 0.08 + h * zz]) + n_ * r
            b.cyl("steel", p, 0.07, 0.03, axis=n_, n=16, bev=0.005)
            b.cyl("dark", p + n_ * 0.016, 0.056, 0.012, axis=n_, n=14, bev=0)
            b.cyl("glow", p + n_ * 0.02, 0.042, 0.012, axis=n_, n=12, bev=0)
    zt = z0 + 0.08 + h
    b.cyl("plate", (x, y, zt + 0.04), r + 0.02, 0.08, r2=r * 0.8, n=28, bev=0.01)
    nb = 10
    for i in range(nb):
        a = TAU * i / nb
        b.bolt("bolt", (x + math.cos(a) * (r - 0.03), y + math.sin(a) * (r - 0.03), zt + 0.005), r=0.018)
    if terminals:
        for s in (-1, 1):
            b.cyl("copper", (x + s * r * 0.35, y, zt + 0.13), 0.045, 0.1, n=10, bev=0.006)
            b.cyl("dark", (x + s * r * 0.35, y, zt + 0.08), 0.06, 0.03, n=10, bev=0)


def radiator_block(b, c, size, along="x", glow=False, fin_pitch=0.07):
    """Radiateur : caisson, ailettes au-dessus, grilles latérales, tubulures cuivre aux extrémités."""
    x, y, z0 = c
    sx, sy, sz = size
    b.box("plate2", (x, y, z0 + sz * 0.3), (sx, sy, sz * 0.6), bev=0.02)
    b.plates_face("plate", (x, y - sy / 2, z0 + sz * 0.3), (1, 0, 0), (0, 0, 1), max(1, int(sx / 0.5)), 1, sx - 0.04,
                  sz * 0.56, th=0.025, bolt_mat="bolt", tones=TONES)
    n = int((sx if along == "x" else sy) / fin_pitch) - 1
    length = (sy if along == "x" else sx) - 0.08
    b.fins("body", (x, y, z0 + sz * 0.6), along, length, sz * 0.4, n, pitch=fin_pitch, th=0.032, base_mat="plate2")
    # tôle de fond derrière les ailettes (nord) : sans elle, on voit le sol entre les ailettes (contrôle bloquant
    # « trous enfermés » du pipeline, production du 22/10 à 15 h 32)
    if along == "x":
        b.box("plate2", (x, y + sy / 2 - 0.03, z0 + sz * 0.8), (sx - 0.02, 0.04, sz * 0.4), bev=0.008)
    else:
        b.box("plate2", (x, y + sy / 2 - 0.03, z0 + sz * 0.8), (sx - 0.02, 0.04, sz * 0.4), bev=0.008)
    if glow:
        # lueur du cœur sous les ailettes (fente avant)
        k = max(2, int((sx - 0.2) / 0.32))
        for i in range(k):
            b.box("glow", (x - (sx - 0.2) / 2 + (i + 0.5) * (sx - 0.2) / k, y - sy / 2 - 0.004, z0 + sz * 0.45),
                  ((sx - 0.2) / k - 0.08, 0.02, 0.08), bev=0)
    for s in (-1, 1):
        if along == "x":
            b.cyl("copper", (x + s * (sx / 2 + 0.05), y, z0 + sz * 0.45), 0.06, sy * 0.85, axis="y", n=12, bev=0.006)
            for t in (-0.3, 0.3):
                b.cyl("brass", (x + s * (sx / 2 + 0.05), y + t * sy, z0 + sz * 0.45), 0.08, 0.04, axis="y", n=12, bev=0.005)
        else:
            b.cyl("copper", (x, y + s * (sy / 2 + 0.05), z0 + sz * 0.45), 0.06, sx * 0.85, axis="x", n=12, bev=0.006)


def crate(b, c, size, rot=0.0, hazard=True, lid=True):
    """Caisse de munitions blindée : tôles, cornières, bande de danger, poignées, couvercle boulonné."""
    x, y, z0 = c
    sx, sy, sz = size
    R = Rz(rot)
    b.push(R, (x, y, z0))
    b.box("plate2", (0, 0, sz / 2), (sx, sy, sz), bev=0.02)
    for sxx in (-1, 1):
        for syy in (-1, 1):
            b.box("body", (sxx * (sx / 2 - 0.02), syy * (sy / 2 - 0.02), sz / 2), (0.06, 0.06, sz + 0.02), bev=0.008)
    if lid:
        b.box("plate", (0, 0, sz + 0.02), (sx - 0.08, sy - 0.08, 0.04), bev=0.012)
        b.bolts_rect("bolt", -sx / 2 + 0.04, sx / 2 - 0.04, -sy / 2 + 0.04, sy / 2 - 0.04, sz + 0.04, r=0.02, inset=0.05,
                     n=(3, 3))
        b.box("dark", (0, 0, sz + 0.055), (sx * 0.3, 0.04, 0.03), bev=0.004)
    if hazard:
        b.hazard_band("haz_y", "haz_k", (-sx / 2 + 0.06, -sy / 2 - 0.004, sz * 0.62), (sx / 2 - 0.06, -sy / 2 - 0.004,
                      sz * 0.62), width=sz * 0.22, th=0.01, normal="-y")
    for s in (-1, 1):
        b.box("dark", (s * (sx / 2 + 0.02), 0, sz * 0.7), (0.03, sy * 0.35, 0.05), bev=0.004)
    b.bolts_line("bolt", (-sx / 2 + 0.08, -sy / 2 - 0.006, sz * 0.25), (sx / 2 - 0.08, -sy / 2 - 0.006, sz * 0.25),
                 max(2, int(sx / 0.15)), r=0.018, axis="-y", h=0.012)
    b.pop()


def pipe_run(b, p0, p1, r, z, flanges=4, valve=True, supports=3):
    """Conduite rigide sur supports : tube, brides boulonnées, vanne à volant."""
    p0, p1 = G.np.array([p0[0], p0[1], z], float), G.np.array([p1[0], p1[1], z], float)
    d = p1 - p0
    L = float(G.np.linalg.norm(d))
    u = d / L
    b.cyl("body", (p0 + p1) / 2, r, L, axis=u, n=14, bev=0.006)
    for i in range(flanges):
        p = p0 + d * (i + 0.5) / flanges
        b.cyl("plate", p, r * 1.5, 0.05, axis=u, n=14, bev=0.006)
        for k in range(6):
            a = TAU * k / 6
            F = G.frame_from_axis(u)
            q = p + (F[:, 0] * math.cos(a) + F[:, 1] * math.sin(a)) * r * 1.3
            b.cyl("bolt", q, 0.016, 0.07, axis=u, n=6, bev=0)
    for i in range(supports):
        p = p0 + d * (i + 0.5) / supports
        b.box("plate2", (p[0], p[1], z / 2), (0.08, 0.08, z), bev=0.008)
        b.box("body", (p[0], p[1], z - r - 0.02), (0.16, 0.12, 0.04), bev=0.006)
    if valve:
        p = p0 + d * 0.5 + G.np.array([0, 0, r + 0.08])
        b.cyl("plate", p - G.np.array([0, 0, 0.04]), 0.035, 0.08, n=10, bev=0.005)
        b.torus("cable_r", p, 0.085, 0.016, axis="z", n=16, m=6)
        for k in range(3):
            a = TAU * k / 3
            b.box("cable_r", p + G.np.array([math.cos(a) * 0.04, math.sin(a) * 0.04, 0]), (0.08, 0.02, 0.02), R=Rz(a),
                  bev=0)


def stairs(b, x, y_front, width, z_top, n):
    """Marches d'accès (caillebotis) et garde-corps bas, sur le bord avant."""
    step_d = 0.12
    for i in range(n):
        zz = z_top * (i + 1) / (n + 1)
        yy = y_front + (n - i - 0.5) * step_d
        b.box("plate2", (x, yy, zz / 2), (width, step_d, zz), bev=0.006)
        b.box("haz_y" if i == n - 1 else "grille", (x, yy - step_d / 2 + 0.012, zz - 0.004), (width - 0.04, 0.024, 0.012),
              bev=0)
    for s in (-1, 1):
        b.box("body", (x + s * (width / 2 + 0.03), y_front + n * step_d / 2, z_top * 0.5), (0.04, n * step_d, z_top),
              bev=0.006)


def lamp_post(b, c, h, glow="amber"):
    """Borne lumineuse basse (bollard) : fût, cerclage, voyant."""
    x, y, z0 = c
    b.cyl("plate2", (x, y, z0 + h / 2), 0.06, h, n=12, bev=0.006)
    b.cyl("haz_y", (x, y, z0 + h * 0.75), 0.064, h * 0.18, n=12, bev=0)
    b.cyl(glow, (x, y, z0 + h + 0.03), 0.045, 0.06, n=12, bev=0)
    b.cyl("dark", (x, y, z0 + h + 0.07), 0.055, 0.02, n=12, bev=0.004)


def hose_arc(b, p0, p1, lift, r, mat="copper", ring="brass", k=10, pitch=0.075):
    p0, p1 = G.np.asarray(p0, float), G.np.asarray(p1, float)
    pts = []
    for i in range(k + 1):
        t = i / k
        p = p0 + (p1 - p0) * t
        p[2] += lift * 4 * t * (1 - t)
        pts.append(p)
    b.hose(mat, ring, pts, r, pitch=pitch)


def cable_bundle(b, p0, p1, sag, n=3, r=0.022, spread=0.05):
    p0, p1 = G.np.asarray(p0, float), G.np.asarray(p1, float)
    d = p1 - p0
    side = G.np.cross(d, [0, 0, 1.0])
    nn = G.np.linalg.norm(side)
    side = side / nn if nn > 1e-6 else G.np.array([1.0, 0, 0])
    for i in range(n):
        o = (i - (n - 1) / 2) * spread
        mat = "cable_r" if i == n // 2 and n >= 3 else "rubber"
        b.cable(mat, p0 + side * o, p1 + side * o, sag=sag + 0.02 * i, r=r)
    # colliers
    for t in (0.25, 0.5, 0.75):
        p = p0 + d * t
        p[2] -= sag * 4 * t * (1 - t) + 0.01
        b.box("plate", p, (0.05, 0.05, 0.05), bev=0.005)


def barbette(b, R, z0, z1, nplates, rows=2, vents=4, glow_vents=0, vent_rows=1):
    """Barbette (tambour fixe haut et blindé) : fût, rangées de tôles boulonnées, bande de danger sous la
    couronne, grilles d'aération (certaines lumineuses), échelle, chemin de roulement du dessus."""
    h = z1 - z0
    b.cyl("plate2", (0, 0, z0 + h / 2), R, h, n=72, bev=0.02)
    rh = (h - 0.12) / rows
    vent_idx = set()
    front = [i for i in range(nplates) if math.sin(TAU * (i + 0.5) / nplates) < -0.25]
    step = max(1, len(front) // max(1, vents))
    for j, i in enumerate(front[::step][:vents]):
        vent_idx.add(i)
    glow_idx = set(sorted(vent_idx)[:glow_vents])
    for row in range(rows):
        zc = z0 + 0.03 + rh * (row + 0.5)
        off = 0.5 * (row % 2)
        for i in range(nplates):
            a = TAU * (i + 0.5 + off) / nplates
            w = TAU * R / nplates - 0.045
            ca, sa = math.cos(a), math.sin(a)
            Rm = Rz(a + math.pi / 2)
            c = (ca * (R + 0.028), sa * (R + 0.028), zc)
            if row >= rows - vent_rows and i in vent_idx:
                u = G.np.array([-sa, ca, 0.0])
                b.vent_face("plate", "body", "glow" if i in glow_idx else "dark", (ca * (R + 0.01), sa * (R + 0.01), zc),
                            u, (0, 0, 1), w * 0.8, rh * 0.8, max(3, int(rh / 0.07)))
                continue
            b.box("plate", c, (w, 0.055, rh - 0.04), R=Rm, bev=0.012)
            u = G.np.array([-sa, ca, 0.0])
            for s in (-1, 1):
                for zz in (-0.5, 0.5):
                    p = G.np.array(c) + u * s * (w / 2 - 0.045)
                    b.bolt("bolt", (p[0] + ca * 0.03, p[1] + sa * 0.03, zc + zz * (rh - 0.13)), r=0.02, h=0.014,
                           axis=(ca, sa, 0.0))
    # bande de danger sous la couronne (secteur avant, face à la caméra)
    for i in range(nplates):
        a = TAU * (i + 0.5) / nplates
        if math.sin(a) > -0.2:
            continue
        ca, sa = math.cos(a), math.sin(a)
        u = G.np.array([-sa, ca, 0.0])
        w = TAU * R / nplates
        p = G.np.array((ca * (R + 0.01), sa * (R + 0.01), z1 - 0.06))
        b.hazard_band("haz_y", "haz_k", p - u * w / 2, p + u * w / 2, width=0.09, th=0.012, normal=(ca, sa, 0.0), n=2)
    # couronne : bague laiton, joint sombre, rangée de boulons
    b.cyl("body", (0, 0, z1 - 0.02), R + 0.04, 0.05, n=72, bev=0.01)
    b.cyl("brass", (0, 0, z1 + 0.015), R * 0.94, 0.03, n=72, bev=0.008)
    b.cyl("dark", (0, 0, z1 + 0.012), R * 0.87, 0.026, n=72, bev=0)
    nb = int(TAU * R / 0.15)
    for i in range(nb):
        a = TAU * i / nb
        b.bolt("bolt", (math.cos(a) * R * 0.97, math.sin(a) * R * 0.97, z1 + 0.012), r=0.022)
    # échelle sur le flanc avant gauche
    a = math.radians(235)
    ca, sa = math.cos(a), math.sin(a)
    for s in (-1, 1):
        da = s * 0.09 / R
        b.box("body", (math.cos(a + da) * (R + 0.07), math.sin(a + da) * (R + 0.07), z0 + h / 2), (0.034, 0.034, h),
              bev=0)
    for k in range(int(h / 0.14)):
        b.box("body", (ca * (R + 0.07), sa * (R + 0.07), z0 + 0.1 + k * 0.14), (0.2, 0.032, 0.032), R=Rz(a + math.pi / 2),
              bev=0)


def blast_wall(b, x0, x1, y_front, h, depth=0.42, lamps=None):
    """Mur pare-éclats bas (face avant inclinée) : tôles boulonnées sur le talus, chaperon à bande de danger,
    barbacanes d'écoulement."""
    L = x1 - x0
    prof = [(y_front, 0.0), (y_front + depth, 0.0), (y_front + depth, h), (y_front + depth * 0.55, h)]
    b.prism("plate2", [(y, z) for y, z in prof], -L / 2, L / 2, R=G.np.array([[0, 0, 1.0], [1.0, 0, 0], [0, 1.0, 0]]),
            t=((x0 + x1) / 2, 0, 0), bev=0.02)
    # tôles sur le talus incliné
    ang = math.atan2(h, depth * 0.55)
    n = max(2, int(L / 0.45))
    w = L / n - 0.04
    slope_len = math.hypot(h, depth * 0.55)
    for i in range(n):
        cx = x0 + (i + 0.5) * L / n
        cy = y_front + depth * 0.275
        p = (cx, cy - 0.012, h / 2)
        Rm = Rx(-(math.pi / 2 - ang))
        b.box("plate", p, (w, 0.03, slope_len * 0.86), R=Rm, bev=0.01)
        for s in (-1, 1):
            for t in (-0.32, 0.32):
                q = G.np.array(p) + Rm @ G.np.array([s * (w / 2 - 0.05), -0.02, t * slope_len])
                b.bolt("bolt", q, r=0.02, h=0.014, axis=Rm @ G.np.array([0, -1.0, 0]))
        b.box("dark", (cx, y_front - 0.005, 0.05), (0.1, 0.02, 0.05), bev=0)
        if lamps:
            # feu de balisage encastré dans le talus (foyer séparé, face à la caméra)
            q = G.np.array(p) + Rm @ G.np.array([0.0, -0.022, 0.0])
            b.box(lamps, q, (0.1, 0.012, 0.07), R=Rm, bev=0)
    # chaperon
    b.box("body", ((x0 + x1) / 2, y_front + depth * 0.78, h + 0.025), (L, depth * 0.48, 0.05), bev=0.012)
    b.hazard_band("haz_y", "haz_k", (x0 + 0.04, y_front + depth * 0.56, h + 0.052), (x1 - 0.04, y_front + depth * 0.56,
                  h + 0.052), width=0.1, th=0.008, normal="z")


def floor_conduit(b, x0, x1, y, glow=True, w=0.22):
    """Caniveau d'énergie dans le pont : cornières, grille, fond lumineux (petits foyers séparés par les barreaux),
    deux câbles de cuivre."""
    L = x1 - x0
    zc = 0.0
    b.grille_top("body", "grille", "dark", x0, x1, y - w / 2, y + w / 2, zc, int(L / 0.09), along="y")
    if glow:
        # foyers séparés (tronçons de 0,3 tuile, entretoises sombres de 0,1) : jamais une longue plage lumineuse
        k = max(1, int(L / 0.4))
        for i in range(k):
            cx = x0 + (i + 0.5) * L / k
            b.box("glow", (cx, y, zc - 0.004), (L / k - 0.12, w - 0.09, 0.012), bev=0)
    for s in (-1, 1):
        b.cyl("copper", ((x0 + x1) / 2, y + s * w * 0.62, zc + 0.03), 0.03, L, axis="x", n=10, bev=0)


def manifold(b, x0, x1, y, z, r=0.055, n_tees=4):
    """Collecteur de refroidissement couché devant la barbette : 2 conduites parallèles sur berceaux, brides,
    tés montants vers la barbette."""
    for k, dy in enumerate((0.0, 0.17)):
        pipe_run(b, (x0, y + dy), (x1, y + dy), r * (1.0 - 0.15 * k), z + 0.04 * k, flanges=n_tees + 1, valve=(k == 0),
                 supports=n_tees)
    for i in range(n_tees):
        x = x0 + (x1 - x0) * (i + 0.5) / n_tees
        b.cyl("body", (x, y + 0.3, z + 0.1), r * 0.8, 0.26, n=12, bev=0.006)
        b.cyl("plate", (x, y + 0.3, z + 0.24), r * 1.2, 0.04, n=12, bev=0.005)
        b.cyl("body", (x, y + 0.15, z + 0.0), r * 0.8, 0.3, axis="y", n=12, bev=0.006)


def hatch(b, c, w, d):
    """Trappe de visite blindée dans le pont : cadre, couvercle boulonné, poignée, charnières."""
    x, y, z = c
    b.box("body", (x, y, z + 0.015), (w + 0.06, d + 0.06, 0.03), bev=0.006)
    b.box("plate", (x, y, z + 0.035), (w, d, 0.03), bev=0.01)
    b.bolts_rect("bolt", x - w / 2, x + w / 2, y - d / 2, y + d / 2, z + 0.05, r=0.018, inset=0.04, n=(3, 3))
    b.box("dark", (x, y - d * 0.25, z + 0.06), (w * 0.4, 0.03, 0.025), bev=0)
    for s in (-1, 1):
        b.cyl("plate2", (x + s * w * 0.3, y + d / 2 + 0.02, z + 0.04), 0.025, w * 0.18, axis="x", n=8, bev=0)


def tank_h(b, c, r, L):
    """Réservoir couché (fluide de refroidissement) : virole cerclée, fonds bombés, berceaux, manomètre, bande."""
    x, y, z0 = c
    zc = z0 + 0.06 + r
    b.cyl("body", (x, y, zc), r, L, axis="x", n=24, bev=0.01)
    for s in (-1, 1):
        b.sphere("plate", (x + s * L / 2, y, zc), r, n=20, m=10, scale=(0.35, 1, 1))
        b.box("plate2", (x + s * L * 0.3, y, z0 + 0.06 + r * 0.4), (0.08, r * 1.7, r * 0.8 + 0.12), bev=0.01)
    for t in (-0.38, -0.12, 0.12, 0.38):
        b.cyl("brass" if abs(t) > 0.3 else "plate", (x + t * L, y, zc), r + 0.015, 0.035, axis="x", n=24, bev=0.005)
    b.hazard_band("haz_y", "haz_k", (x - L * 0.08, y - r - 0.004, zc), (x + L * 0.08, y - r - 0.004, zc), width=r * 0.6,
                  th=0.01, normal="-y")
    b.cyl("plate", (x + L * 0.25, y, zc + r + 0.03), 0.04, 0.06, n=12, bev=0.004)
    b.cyl("brass", (x + L * 0.25, y - 0.02, zc + r + 0.1), 0.045, 0.02, axis="y", n=14, bev=0)
    b.cyl("body", (x - L * 0.25, y, zc + r + 0.04), 0.035, 0.1, n=10, bev=0.004)
    b.torus("cable_r", (x - L * 0.25, y, zc + r + 0.1), 0.05, 0.012, n=12, m=6)


def spline(pts, k=8):
    """Catmull-Rom par les points de contrôle (gaines souples)."""
    P = [G.np.asarray(p, float) for p in pts]
    P = [P[0]] + P + [P[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for j in range(k):
            t = j / k
            out.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P[-2])
    return out


def big_hose(b, pts, r):
    """Grosse gaine annelée de cuivre (boucle de refroidissement, comme le réacteur et le silo vanilla) : gaine,
    bagues laiton, brides boulonnées aux deux bouts, colliers de fixation au sol."""
    path = spline(pts)
    b.hose("copper", "brass", path, r, pitch=max(0.07, r * 0.85), n=14, ring_r=r * 1.14)
    for end, nxt in ((path[0], path[1]), (path[-1], path[-2])):
        d = G.np.asarray(end) - G.np.asarray(nxt)
        b.cyl("plate", end, r * 1.45, 0.06, axis=d, n=16, bev=0.006)
        F = G.frame_from_axis(d)
        for k in range(6):
            a = TAU * k / 6
            q = G.np.asarray(end) + (F[:, 0] * math.cos(a) + F[:, 1] * math.sin(a)) * r * 1.25
            b.cyl("bolt", q, 0.017, 0.08, axis=d, n=6, bev=0)
    for i in range(1, len(pts) - 1):
        x, y, z = pts[i]
        if z - r > 0.25:
            b.box("plate2", (x, y, (z - r) / 2 + 0.1), (0.07, 0.07, z - r - 0.1), bev=0.006)
        b.box("body", (x, y, z), (r * 2.6, 0.06, r * 2.6), R=Rz(math.atan2(pts[i + 1][1] - pts[i - 1][1],
                                                                          pts[i + 1][0] - pts[i - 1][0]) + math.pi / 2),
              bev=0.01)


def pump(b, c, r, h):
    """Pompe de refroidissement : corps cylindrique bridé, moteur horizontal à ailettes, tubulures."""
    x, y, z0 = c
    b.cyl("plate2", (x, y, z0 + 0.04), r + 0.05, 0.08, n=24, bev=0.01)
    b.cyl("body", (x, y, z0 + 0.08 + h / 2), r, h, n=24, bev=0.012)
    for t in (0.2, 0.8):
        b.cyl("plate", (x, y, z0 + 0.08 + h * t), r + 0.03, 0.05, n=24, bev=0.006)
        for k in range(8):
            a = TAU * k / 8
            b.bolt("bolt", (x + math.cos(a) * (r + 0.02), y + math.sin(a) * (r + 0.02), z0 + 0.08 + h * t + 0.03), r=0.016)
    zt = z0 + 0.08 + h
    b.cyl("plate2", (x, y, zt + 0.04), r * 0.9, 0.08, n=24, bev=0.01)
    b.cyl("body", (x, y, zt + 0.08 + r * 0.55), r * 0.55, r * 1.6, axis="y", n=20, bev=0.01)
    for k in range(7):
        b.cyl("plate", (x, y - r * 0.7 + k * r * 0.23, zt + 0.08 + r * 0.55), r * 0.62, 0.025, axis="y", n=20, bev=0)
    b.cyl("haz_y", (x, y - r * 0.82, zt + 0.08 + r * 0.55), r * 0.4, 0.03, axis="y", n=16, bev=0)
    b.lamp("amber", "plate2", (x + r * 0.7, y - r * 0.3, zt + 0.02), (0.06, 0.05), axis="z")


def conveyor(b, p0, p1, w, h=0.12):
    """Goulotte de munitions inclinée et capotée, fentes de visite (cartouches visibles)."""
    p0, p1 = G.np.asarray(p0, float), G.np.asarray(p1, float)
    d = p1 - p0
    L = float(G.np.linalg.norm(d))
    u = d / L
    side = G.np.cross([0, 0, 1.0], u)
    side /= G.np.linalg.norm(side)
    up = G.np.cross(u, side)
    Rm = G.np.stack([side, u, up], 1)
    b.box("plate2", (p0 + p1) / 2, (w, L, h), R=Rm, bev=0.012)
    k = max(2, int(L / 0.25))
    for i in range(k):
        q = p0 + d * (i + 0.5) / k + up * (h / 2 + 0.004)
        b.box("dark", q, (w * 0.6, 0.12, 0.012), R=Rm, bev=0)
        b.cyl("case", q + up * 0.006, 0.018, w * 0.5, axis=side, n=6, bev=0)
        b.bolts_line("bolt", q - side * w * 0.42 - u * 0.1, q - side * w * 0.42 + u * 0.1, 2, r=0.016, axis=up, h=0.01)
    for s in (0.0, 1.0):
        q = p0 + d * s
        b.box("body", q - up * (h / 2) - G.np.array([0, 0, q[2] / 2 - h / 2]) * 0, (w * 0.4, 0.06, 0.06), R=Rm, bev=0.006)


# ------------------------------------------------------------------------------------------------
# Socles
# ------------------------------------------------------------------------------------------------

def shroud(b, c, r, L, holes_rows=5, holes_per_row=8):
    """Chemise de refroidissement perforée autour d'un faisceau (axe +Y)."""
    x, y0, z = c
    b.cyl("plate", (x, y0 + L / 2, z), r, L, axis="y", n=24, bev=0.008)
    for i in range(holes_rows):
        yy = y0 + L * (i + 0.5) / holes_rows
        for k in range(holes_per_row):
            a = TAU * (k + 0.5 * (i % 2)) / holes_per_row
            # demi-cercle visible du dessus seulement (inutile de percer le dessous)
            if math.sin(a) < -0.3:
                continue
            p = (x + math.cos(a) * (r + 0.002), yy, z + math.sin(a) * (r + 0.002))
            b.cyl("dark", p, 0.028, 0.02, axis=(math.cos(a), 0.0, math.sin(a)), n=8, bev=0)
    for t in (0.0, 1.0):
        b.cyl("body", (x, y0 + L * t, z), r + 0.025, 0.06, axis="y", n=24, bev=0.006)


def trunnion(b, x, y, z, w, h, d):
    """Berceau de canon : bloc, tourillons latéraux boulonnés."""
    b.box("plate2", (x, y, z), (w, d, h), bev=0.02)
    for s in (-1, 1):
        b.cyl("body", (x + s * (w / 2 + 0.03), y, z), h * 0.32, 0.06, axis="x", n=16, bev=0.006)
        for k in range(6):
            a = TAU * k / 6
            b.bolt("bolt", (x + s * (w / 2 + 0.065), y + math.cos(a) * h * 0.22, z + math.sin(a) * h * 0.22), r=0.016,
                   h=0.012, axis=(s, 0.0, 0.0))


def drum_mag(b, c, r, L, belt_to):
    """Tambour-chargeur latéral (axe Y) : fût cerclé, couvercles boulonnés, bande de danger, bande de cartouches."""
    x, y, z = c
    b.cyl("olive", (x, y, z), r, L, axis="y", n=28, bev=0.012)
    for t in (-0.42, -0.14, 0.14, 0.42):
        b.cyl("body", (x, y + t * L, z), r + 0.02, 0.05, axis="y", n=28, bev=0.006)
    # rivets en lignes sur la virole (entre les cerclages)
    for t in (-0.28, 0.0, 0.28):
        for k in range(int(TAU * r / 0.09)):
            a = TAU * k / int(TAU * r / 0.09)
            n_ = G.np.array([math.cos(a), 0.0, math.sin(a)])
            b.cyl("bolt", G.np.array([x, y + t * L, z]) + n_ * (r + 0.003), 0.012, 0.012, axis=n_, n=6, bev=0)
    for s in (-1, 1):
        b.cyl("plate", (x, y + s * (L / 2 + 0.02), z), r * 0.85, 0.04, axis="y", n=24, bev=0.008)
        for k in range(8):
            a = TAU * k / 8
            b.bolt("bolt", (x + math.cos(a) * r * 0.7, y + s * (L / 2 + 0.045), z + math.sin(a) * r * 0.7), r=0.018,
                   h=0.012, axis=(0.0, float(s), 0.0))
    b.hazard_band("haz_y", "haz_k", (x - r * 0.6, y - L * 0.28, z + r + 0.005), (x - r * 0.6, y + L * 0.28, z + r + 0.005),
                  width=r * 0.5, th=0.01, normal="z")
    b.ammo_belt("case", "dark", [(x, y + L * 0.3, z + r * 0.9), belt_to], w=0.11)


def secondary_turret(b, c, scale=1.0):
    """Tourelle secondaire (défense rapprochée) : couronne, caisson, 2 canons, viseur à lueur d'époque."""
    x, y, z = c
    k = scale
    b.cyl("plate2", (x, y, z + 0.05 * k), 0.24 * k, 0.1 * k, n=24, bev=0.008)
    nb = 10
    for i in range(nb):
        a = TAU * i / nb
        b.bolt("bolt", (x + math.cos(a) * 0.2 * k, y + math.sin(a) * 0.2 * k, z + 0.1 * k), r=0.016)
    b.box("plate", (x, y, z + 0.2 * k), (0.34 * k, 0.4 * k, 0.2 * k), bev=0.015)
    b.box("body", (x, y + 0.02 * k, z + 0.31 * k), (0.26 * k, 0.3 * k, 0.04 * k), bev=0.008)
    for s in (-1, 1):
        b.cyl("gun", (x + s * 0.07 * k, y + 0.45 * k, z + 0.2 * k), 0.026 * k, 0.55 * k, axis="y", n=10, bev=0)
        b.cyl("body", (x + s * 0.07 * k, y + 0.26 * k, z + 0.2 * k), 0.045 * k, 0.14 * k, axis="y", n=12, bev=0.005)
        b.cyl("dark", (x + s * 0.07 * k, y + 0.725 * k, z + 0.2 * k), 0.032 * k, 0.03 * k, axis="y", n=10, bev=0)
    b.box("glow", (x + 0.1 * k, y + 0.205 * k, z + 0.25 * k), (0.09 * k, 0.012, 0.06 * k), bev=0)
    b.bolts_rect("bolt", x - 0.15 * k, x + 0.15 * k, y - 0.18 * k, y + 0.18 * k, z + 0.3 * k, r=0.016, inset=0.04)


def sensor(b, c, r, glow=True):
    """Viseur (télémètre) : fût, dôme d'accent, lentille lumineuse vers l'avant, visière."""
    x, y, z = c
    b.cyl("plate2", (x, y, z + 0.06), r, 0.12, n=24, bev=0.01)
    b.sphere("accent", (x, y, z + 0.12), r * 0.92, n=20, m=10, scale=(1, 1, 0.7))
    b.cyl("dark", (x, y + r * 0.8, z + 0.17), r * 0.42, 0.1, axis="y", n=16, bev=0.006)
    if glow:
        b.cyl("glow", (x, y + r * 0.86, z + 0.17), r * 0.28, 0.02, axis="y", n=16, bev=0)
    b.box("plate", (x, y + r * 0.75, z + 0.27), (r * 1.0, r * 0.4, 0.03), R=Rx(-0.3), bev=0.006)
    b.cyl("body", (x - r * 0.6, y - r * 0.4, z + 0.32), 0.03, 0.22, n=8, bev=0.004)


