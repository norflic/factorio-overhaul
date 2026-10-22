"""Composants mécaniques (« vocabulaire visuel de Factorio », charte DA_FACTORIO §4) pour l'exploration
hybride de la mitrailleuse. Python PUR : tout passe par geo.Geo.

Chaque composant a une FONCTION lisible (charte §4.1) et porte ses petites pièces (boulons, joints, colliers) :
c'est la densité de détail par tuile (loi vanilla : environ 29 petites pièces par tuile² de corps, D3) qui doit
rester constante quand la taille grandit (« avec la taille […] on augmente aussi les détails »).

Clés de matériau attendues (définies par époque dans design.MATS) : voir `M` en paramètre (dictionnaire de
noms) ; les composants reçoivent des clés de matériau, jamais des matériaux Blender.
"""
import math
import random

from geo import TAU, MIN_T, basis_from_z, catmull, resample, v_add, v_sub, v_mul, v_norm, v_len, v_cross


# ------------------------------------------------------------------------------------------------
# Boulonnerie
# ------------------------------------------------------------------------------------------------
def bolt(g, mat, p, n=(0, 0, 1), r=0.026, h=0.02, washer=None):
    """Boulon à tête hexagonale (et rondelle facultative) posé sur une face de normale n."""
    g.push()
    g.frame(p, basis_from_z(n))
    if washer:
        g.cyl(washer, r * 1.35, 0.008, (0, 0, 0.004), n=12)
        g.cyl(mat, r, h, (0, 0, 0.008 + h / 2), n=6, ch=min(0.006, h * 0.3))
    else:
        g.cyl(mat, r, h, (0, 0, h / 2), n=6, ch=min(0.006, h * 0.3))
    g.pop()
    g.count("boulon")


def rivet(g, mat, p, n=(0, 0, 1), r=0.022):
    g.dome(mat, r, p, axis=n, n=8, rings=2, squash=0.7)
    g.count("rivet")


def bolts_line(g, mat, p0, p1, k, n=(0, 0, 1), r=0.026, ends=True, kind="bolt"):
    """k boulons (ou rivets) de p0 à p1 ; ends=False : pas aux extrémités."""
    for i in range(k):
        t = i / max(1, k - 1) if ends else (i + 0.5) / k
        p = v_add(p0, v_mul(v_sub(p1, p0), t))
        if kind == "rivet":
            rivet(g, mat, p, n, r)
        else:
            bolt(g, mat, p, n, r)


def bolts_ring(g, mat, c, R, k, axis="z", r=0.024, phase=0.0, kind="bolt"):
    """Couronne de k boulons de rayon R autour de l'axe (boulons sur la face perpendiculaire à l'axe)."""
    B = basis_from_z({"z": (0, 0, 1), "x": (1, 0, 0), "y": (0, 1, 0), "-y": (0, -1, 0), "-x": (-1, 0, 0)}[axis]
                     if isinstance(axis, str) else axis)
    for i in range(k):
        a = phase + TAU * i / k
        lp = (R * math.cos(a), R * math.sin(a), 0.0)
        p = v_add(c, (B[0][0] * lp[0] + B[0][1] * lp[1], B[1][0] * lp[0] + B[1][1] * lp[1],
                      B[2][0] * lp[0] + B[2][1] * lp[1]))
        n = (B[0][2], B[1][2], B[2][2])
        if kind == "rivet":
            rivet(g, mat, p, n, r)
        else:
            bolt(g, mat, p, n, r)


def radial_rivets(g, mat, c, R, z, k, r=0.02, phase=0.0):
    """Rivets sur la paroi d'un cylindre vertical (normale radiale)."""
    for i in range(k):
        a = phase + TAU * i / k
        rivet(g, mat, (c[0] + R * math.cos(a), c[1] + R * math.sin(a), z), (math.cos(a), math.sin(a), 0), r)


# ------------------------------------------------------------------------------------------------
# Tôlerie
# ------------------------------------------------------------------------------------------------
def plate(g, mat, bolt_mat, size, c, spacing=0.22, inset=0.045, r=0.024, ch=0.016, corners_only=False):
    """Plaque (boîte plate, face utile vers +z local) boulonnée sur son pourtour."""
    sx, sy, sz = size
    g.box(mat, size, c, ch)
    if bolt_mat is None:
        return
    z = c[2] + sz / 2
    x0, x1 = c[0] - sx / 2 + inset, c[0] + sx / 2 - inset
    y0, y1 = c[1] - sy / 2 + inset, c[1] + sy / 2 - inset
    if corners_only or (x1 - x0) < 0.1 or (y1 - y0) < 0.1:
        for x in (x0, x1):
            for y in (y0, y1):
                bolt(g, bolt_mat, (x, y, z), r=r)
        return
    kx = max(2, int(round((x1 - x0) / spacing)) + 1)
    ky = max(2, int(round((y1 - y0) / spacing)) + 1)
    bolts_line(g, bolt_mat, (x0, y0, z), (x1, y0, z), kx, r=r)
    bolts_line(g, bolt_mat, (x0, y1, z), (x1, y1, z), kx, r=r)
    if ky > 2:
        for i in range(1, ky - 1):
            t = i / (ky - 1)
            bolt(g, bolt_mat, (x0, y0 + (y1 - y0) * t, z), r=r)
            bolt(g, bolt_mat, (x1, y0 + (y1 - y0) * t, z), r=r)


def plated_face(g, core, plate_mat, bolt_mat, u_range, v_range, nu, nv, gap=0.034, t=0.035, spacing=0.24,
                r=0.022, seed=0, jitter=0.0):
    """Face plane (repère local : u = x, v = y, normale +z, surface du noyau à z = 0) couverte de plaques
    séparées par des joints sombres (le noyau se voit au fond du joint). Les plaques ont une épaisseur t
    (elles dépassent de t) ; boulons au pourtour de chaque plaque."""
    rnd = random.Random(seed)
    u0, u1 = u_range
    v0, v1 = v_range
    du = (u1 - u0) / nu
    dv = (v1 - v0) / nv
    for i in range(nu):
        for j in range(nv):
            a0 = u0 + i * du + gap / 2
            a1 = u0 + (i + 1) * du - gap / 2
            b0 = v0 + j * dv + gap / 2
            b1 = v0 + (j + 1) * dv - gap / 2
            tt = t * (1.0 + jitter * (rnd.random() - 0.5))
            pm = plate_mat[rnd.randrange(len(plate_mat))] if isinstance(plate_mat, (list, tuple)) else plate_mat
            plate(g, pm, bolt_mat, (a1 - a0, b1 - b0, tt), ((a0 + a1) / 2, (b0 + b1) / 2, tt / 2),
                  spacing=spacing, r=r)


def plate_variants(M, base="tole"):
    """Plaques de teinte variée (tôle, tôle claire, tôle rouillée) : la patine varie d'une plaque à l'autre comme
    sur les sprites vanilla (variance basse fréquence P2 de la charte)."""
    return [M[k] for k in (base, base + "_b", base + "_r") if k in M]


def armor_box(g, M, size, c, div_top=(2, 2), div_side=(2, 1), faces=("top", "n", "s", "e", "w"), gap=0.034,
              t=0.035, spacing=0.24, r=0.022, seed=0, core=None, plate_mat=None, bolt_mat=None):
    """Caisson blindé : noyau sombre + plaques jointives boulonnées sur les faces demandées.
    `size` est la taille EXTÉRIEURE (plaques comprises)."""
    core = core or M["joint"]
    plate_mat = plate_mat or plate_variants(M)
    bolt_mat = bolt_mat or M["boulon"]
    sx, sy, sz = size
    cx, cy, cz = c
    ins = {k: (t if k in faces else 0.0) for k in ("top", "n", "s", "e", "w")}
    core_size = (sx - ins["e"] - ins["w"], sy - ins["n"] - ins["s"], sz - ins["top"])
    core_c = (cx + (ins["w"] - ins["e"]) / 2, cy + (ins["s"] - ins["n"]) / 2, cz - ins["top"] / 2)
    g.box(core, core_size, core_c, 0.008)
    hx, hy, hz = core_size[0] / 2, core_size[1] / 2, core_size[2] / 2
    x0, x1 = core_c[0] - hx, core_c[0] + hx
    y0, y1 = core_c[1] - hy, core_c[1] + hy
    z0, z1 = core_c[2] - hz, core_c[2] + hz
    k = 0
    if "top" in faces:
        g.push(); g.move((0, 0, z1))
        plated_face(g, core, plate_mat, bolt_mat, (x0, x1), (y0, y1), div_top[0], div_top[1], gap, t, spacing, r, seed + k)
        g.pop(); k += 1
    # faces latérales : repère local (u, v, n)
    side = {"s": ((x0, x1), (z0, z1), ((1, 0, 0), (0, 0, 1), (0, -1, 0)), (0, y0, 0)),
            "n": ((-x1, -x0), (z0, z1), ((-1, 0, 0), (0, 0, 1), (0, 1, 0)), (0, y1, 0)),
            "e": ((y0, y1), (z0, z1), ((0, 1, 0), (0, 0, 1), (1, 0, 0)), (x1, 0, 0)),
            "w": ((-y1, -y0), (z0, z1), ((0, -1, 0), (0, 0, 1), (-1, 0, 0)), (x0, 0, 0))}
    for f in ("s", "n", "e", "w"):
        if f not in faces:
            continue
        ur, vr, (U, V, N), o = side[f]
        B = ((U[0], V[0], N[0]), (U[1], V[1], N[1]), (U[2], V[2], N[2]))
        g.push(); g.frame(o, B)
        nu = div_side[0] if f in ("s", "n") else max(1, div_side[0] * int(round(sy / max(sx, 0.01))) or 1)
        plated_face(g, core, plate_mat, bolt_mat, ur, vr, nu, div_side[1], gap, t, spacing, r, seed + k)
        g.pop(); k += 1


def tread_plate(g, mat, x_range, y_range, z, pitch=0.16, seed=0):
    """Tôle larmée (caillebotis plein) : petites larmes en relief en quinconce, sur une plaque."""
    x0, x1 = x_range
    y0, y1 = y_range
    g.box(mat, (x1 - x0, y1 - y0, 0.02), ((x0 + x1) / 2, (y0 + y1) / 2, z + 0.01), 0.004)
    j = 0
    y = y0 + pitch / 2
    while y < y1 - pitch / 3:
        x = x0 + pitch / 2 + (pitch / 2 if j % 2 else 0)
        while x < x1 - pitch / 3:
            g.push(); g.move((x, y, z + 0.02)); g.turn("z", math.pi / 4 if (j % 2) else -math.pi / 4)
            g.box(mat, (0.075, 0.034, 0.012), (0, 0, 0.006), 0.004)
            g.pop()
            g.count("larme")
            x += pitch
        y += pitch * 0.75
        j += 1


def hazard_band(g, yel, blk, p0, p1, width, h, stripe=0.11, n_up=(0, 0, 1)):
    """Bande de danger jaune et noir (charte §4.5) : parallélogrammes alternés sur une face plane.
    p0 -> p1 : axe de la bande ; width : largeur ; h : épaisseur (relief)."""
    L = v_len(v_sub(p1, p0))
    u = v_norm(v_sub(p1, p0))
    n = v_norm(n_up)
    w = v_cross(n, u)
    B = ((u[0], w[0], n[0]), (u[1], w[1], n[1]), (u[2], w[2], n[2]))
    g.push(); g.frame(p0, B)
    k = int(L / stripe)
    sk = width * 0.6
    for i in range(k):
        a = i * stripe
        b = min(L, a + stripe)
        poly = [(a, -width / 2), (b, -width / 2), (min(L, b + sk), width / 2), (min(L, a + sk), width / 2)]
        if poly[3][0] - poly[2][0] == 0 and a + sk > L:
            poly = poly[:3]
        g.prism(yel if i % 2 == 0 else blk, poly, 0.0, h)
        g.count("bande_danger")
    g.pop()


def grille(g, frame_mat, slat_mat, w, h, c, n_slats=None, depth=0.04, normal=(0, -1, 0), deep_mat=None):
    """Grille d'aération à lamelles inclinées dans un cadre (face de normale `normal`) ; le fond est sombre
    (deep_mat) : les ouvertures montrent un mécanisme sombre, jamais du vide (charte §4.4)."""
    n_slats = n_slats or max(3, int(h / 0.075))
    g.push()
    g.frame(c, basis_from_z(normal))
    # repère local : z = normale ; x, y dans le plan (x horizontal si possible)
    if deep_mat:
        g.box(deep_mat, (w, h, 0.02), (0, 0, -0.01), 0.0)
    fw = 0.036
    g.box(frame_mat, (w, fw, depth), (0, h / 2 - fw / 2, depth / 2), 0.006)
    g.box(frame_mat, (w, fw, depth), (0, -h / 2 + fw / 2, depth / 2), 0.006)
    g.box(frame_mat, (fw, h, depth), (w / 2 - fw / 2, 0, depth / 2), 0.006)
    g.box(frame_mat, (fw, h, depth), (-w / 2 + fw / 2, 0, depth / 2), 0.006)
    inner = h - 2 * fw
    for i in range(n_slats):
        y = -inner / 2 + (i + 0.5) * inner / n_slats
        g.push(); g.move((0, y, depth * 0.45)); g.turn("x", 0.6)
        g.box(slat_mat, (w - 2 * fw, MIN_T, inner / n_slats * 1.05), (0, 0, 0), 0.0)
        g.pop()
        g.count("lamelle")
    g.pop()


def fins(g, mat, base_mat, length, height, depth, n, c, axis="x", fin_t=0.034):
    """Radiateur à ailettes : n ailettes parallèles le long de `axis` sur un sommier (base_mat)."""
    cx, cy, cz = c
    if axis == "x":
        g.box(base_mat, (length, depth, 0.06), (cx, cy, cz + 0.03), 0.01)
        for i in range(n):
            x = cx - length / 2 + (i + 0.5) * length / n
            g.box(mat, (fin_t, depth * 0.94, height), (x, cy, cz + 0.06 + height / 2), 0.006)
    else:
        g.box(base_mat, (depth, length, 0.06), (cx, cy, cz + 0.03), 0.01)
        for i in range(n):
            y = cy - length / 2 + (i + 0.5) * length / n
            g.box(mat, (depth * 0.94, fin_t, height), (cx, y, cz + 0.06 + height / 2), 0.006)
    g.count("ailette", n)


# ------------------------------------------------------------------------------------------------
# Tuyauterie et câblage
# ------------------------------------------------------------------------------------------------
def pipe(g, mat, flange_mat, bolt_mat, pts, r, flanges=True, clamp_every=0.0, bend=True):
    """Tuyau le long d'une polyligne (coudes arrondis), brides boulonnées aux extrémités et aux coudes."""
    P = [tuple(p) for p in pts]
    if bend and len(P) > 2:
        Q = [P[0]]
        for i in range(1, len(P) - 1):
            a, b, c = P[i - 1], P[i], P[i + 1]
            da, db = v_norm(v_sub(a, b)), v_norm(v_sub(c, b))
            rr = min(r * 2.2, 0.45 * v_len(v_sub(a, b)), 0.45 * v_len(v_sub(c, b)))
            p0, p1 = v_add(b, v_mul(da, rr)), v_add(b, v_mul(db, rr))
            for k in range(5):
                t = k / 4.0
                q = v_add(v_add(v_mul(p0, (1 - t) ** 2), v_mul(b, 2 * t * (1 - t))), v_mul(p1, t * t))
                Q.append(q)
        Q.append(P[-1])
        P = Q
    g.path_tube(mat, P, r, n=14)
    if flanges and flange_mat:
        ends = [(pts[0], v_norm(v_sub(pts[1], pts[0]))), (pts[-1], v_norm(v_sub(pts[-1], pts[-2])))]
        for p, d in ends:
            g.cyl(flange_mat, r * 1.6, max(MIN_T, r * 0.55), v_add(p, v_mul(d, -0.02 if p is pts[-1] else 0.02)),
                  axis=d, n=16, ch=0.006)
            if bolt_mat:
                B = basis_from_z(d)
                for i in range(6):
                    a = TAU * i / 6
                    lp = (r * 1.3 * math.cos(a), r * 1.3 * math.sin(a), 0.0)
                    q = v_add(p, (B[0][0] * lp[0] + B[0][1] * lp[1], B[1][0] * lp[0] + B[1][1] * lp[1],
                                  B[2][0] * lp[0] + B[2][1] * lp[1]))
                    g.cyl(bolt_mat, 0.014, max(MIN_T, r * 0.75), q, axis=d, n=6)
        g.count("bride", 2)
    if clamp_every > 0:
        for p, d in resample(P, clamp_every)[1:-1]:
            g.cyl(flange_mat or mat, r * 1.28, MIN_T + 0.004, p, axis=d, n=14)
            g.count("collier")


def cable(g, mat, ctrl, r=0.022, ties=None, tie_every=0.22, per_seg=6):
    """Câble souple (spline) ; colliers sombres réguliers (ties) : chaque collier est une petite pièce."""
    pts = catmull(ctrl, per_seg)
    g.path_tube(mat, pts, r, n=8)
    if ties:
        for p, d in resample(pts, tie_every)[1:-1]:
            g.cyl(ties, r * 1.5, MIN_T, p, axis=d, n=8)
            g.count("collier")
    g.count("cable")


def cable_bundle(g, mats, ctrl, spread=0.05, r=0.02, ties=None, tie_every=0.25, up=(0, 0, 1)):
    """Faisceau de câbles parallèles (rouges, noirs, cuivre) suivant la même trajectoire."""
    n = len(mats)
    pts = catmull(ctrl, 6)
    for k, m in enumerate(mats):
        off = (k - (n - 1) / 2.0) * spread
        P = []
        for i, p in enumerate(pts):
            d = v_norm(v_sub(pts[min(i + 1, len(pts) - 1)], pts[max(0, i - 1)]))
            side = v_norm(v_cross(d, up))
            P.append(v_add(p, v_mul(side, off)))
        g.path_tube(m, P, r, n=8)
        g.count("cable")
    if ties:
        for p, d in resample(pts, tie_every)[1:-1]:
            g.cyl(ties, (n * spread) / 2 + r + 0.012, MIN_T + 0.006, p, axis=d, n=12)
            g.count("collier")


def cable_tray(g, tray_mat, cable_mats, p0, p1, w=0.16, h=0.06, z_up=(0, 0, 1), seed=0):
    """Chemin de câbles (goulotte en U) avec câbles posés dedans."""
    u = v_norm(v_sub(p1, p0))
    n = v_norm(z_up)
    w_ax = v_cross(n, u)
    L = v_len(v_sub(p1, p0))
    B = ((u[0], w_ax[0], n[0]), (u[1], w_ax[1], n[1]), (u[2], w_ax[2], n[2]))
    g.push(); g.frame(p0, B)
    g.box(tray_mat, (L, w, 0.02), (L / 2, 0, 0.01), 0.004)
    g.box(tray_mat, (L, MIN_T, h), (L / 2, w / 2, h / 2), 0.004)
    g.box(tray_mat, (L, MIN_T, h), (L / 2, -w / 2, h / 2), 0.004)
    k = len(cable_mats)
    for i, m in enumerate(cable_mats):
        y = -w / 2 + 0.035 + i * (w - 0.07) / max(1, k - 1)
        g.cyl(m, 0.022, L - 0.02, (L / 2, y, 0.04), axis="x", n=8)
    for i in range(int(L / 0.3)):
        g.box(tray_mat, (MIN_T, w + 0.02, 0.03), (0.15 + i * 0.3, 0, h + 0.005), 0.004)
        g.count("collier")
    g.pop()


# ------------------------------------------------------------------------------------------------
# Électricité (ère II à V)
# ------------------------------------------------------------------------------------------------
def insulator_stack(g, disc_mat, cap_mat, p, n, r_big=0.09, r_small=0.055, hd=0.045, base_mat=None):
    """Pile d'isolateurs (époque 6, bible : colonnes « crantées ») : disques alternés, embase et chapeau."""
    x, y, z = p
    if base_mat:
        g.cyl(base_mat, r_big * 1.25, 0.05, (x, y, z + 0.025), n=16, ch=0.008)
        z += 0.05
    for i in range(n):
        rr = r_big if i % 2 == 0 else r_small
        g.cyl(disc_mat, rr, hd, (x, y, z + hd / 2), n=18, ch=0.008)
        z += hd
    g.cyl(cap_mat, r_small * 0.9, 0.05, (x, y, z + 0.025), n=14, ch=0.008)
    g.dome(cap_mat, r_small * 0.55, (x, y, z + 0.05), n=10, rings=3)
    g.count("isolateur", n)
    return z + 0.05


def coil(g, cu, core, c, R, length, axis="y", turns=9, wire=0.03, flange=None):
    """Bobine : noyau, spires de cuivre (tores serrés), joues d'extrémité."""
    g.cyl(core, R - wire * 0.8, length, c, axis=axis, n=24)
    d = {"x": (1, 0, 0), "y": (0, 1, 0), "z": (0, 0, 1)}[axis] if isinstance(axis, str) else v_norm(axis)
    for i in range(turns):
        t = -length / 2 + (i + 0.5) * length / turns
        g.torus(cu, R, wire, v_add(c, v_mul(d, t)), axis=axis, n=28, m=6)
    if flange:
        for s in (-1, 1):
            g.cyl(flange, R * 1.18, MIN_T + 0.01, v_add(c, v_mul(d, s * (length / 2 + 0.02))), axis=axis, n=24,
                  ch=0.006)
    g.count("spire", turns)


def capacitor_bank(g, M, c, nx, ny, r=0.12, h=0.5, pitch=0.3, emit=None, cap="laiton"):
    """Batterie de condensateurs / accumulateurs : cylindres serrés, bornes, barres de liaison."""
    cx, cy, cz = c
    for i in range(nx):
        for j in range(ny):
            x = cx + (i - (nx - 1) / 2) * pitch
            y = cy + (j - (ny - 1) / 2) * pitch
            g.cyl(M["acier"], r, h, (x, y, cz + h / 2), n=20, ch=0.012)
            g.torus(M["joint"], r + 0.004, 0.012, (x, y, cz + h * 0.25), n=24, m=5)
            g.cyl(M[cap], r * 0.82, 0.04, (x, y, cz + h + 0.02), n=18, ch=0.008)
            for s in (-1, 1):
                g.cyl(M["cuivre"], 0.022, 0.06, (x + s * r * 0.45, y, cz + h + 0.07), n=8)
                g.dome(M["cuivre"], 0.024, (x + s * r * 0.45, y, cz + h + 0.1), n=8, rings=2)
            if emit:
                g.box(emit, (0.07, MIN_T, h * 0.38), (x, y - r - 0.002, cz + h * 0.55), 0.0)
            g.count("condensateur")
    # barres de liaison de cuivre
    for j in range(ny):
        y = cy + (j - (ny - 1) / 2) * pitch
        g.box(M["cuivre"], ((nx - 1) * pitch + 0.08, 0.035, MIN_T), (cx, y, cz + h + 0.105), 0.006)


# ------------------------------------------------------------------------------------------------
# Armement
# ------------------------------------------------------------------------------------------------
def gatling(g, M, n, ring_r, br, y0, y1, x=0.0, z=0.0, phase=0.0, rings=(0.08, 0.42, 0.78, 0.97), jacket=None,
            muzzle=True, hub_r=None, barrel="canon", clamp="acier", bolt_mat="boulon"):
    """Canons rotatifs (identité « tête à plusieurs canons ») : n tubes autour d'un axe, frettes, moyeu,
    frein de bouche ; jacket = (y_a, y_b, r) manchon de refroidissement à évents."""
    L = y1 - y0
    ym = (y0 + y1) / 2
    for i in range(n):
        a = phase + TAU * i / n
        g.cyl(M[barrel], br, L, (x + ring_r * math.cos(a), ym, z + ring_r * math.sin(a)), axis="y", n=12)
        # bouche percée (anneau sombre)
        g.cyl(M["joint"], br * 0.55, MIN_T, (x + ring_r * math.cos(a), y1 + 0.004, z + ring_r * math.sin(a)),
              axis="y", n=8)
    g.cyl(M["acier"], hub_r or ring_r * 0.55, L * 0.96, (x, ym, z), axis="y", n=14)
    for t in rings:
        g.cyl(M[clamp], ring_r + br + 0.02, max(MIN_T, 0.045), (x, y0 + t * L, z), axis="y", n=24, ch=0.008)
        g.count("frette")
    if jacket:
        ya, yb, rj = jacket
        g.cyl(M["acier"], rj, yb - ya, (x, (ya + yb) / 2, z), axis="y", n=28, ch=0.01)
        # évents : rangées de fentes sombres sur le manchon (pièces nombreuses, lecture « refroidi »)
        k = int((yb - ya) / 0.09)
        for i in range(k):
            yy = ya + (i + 0.5) * (yb - ya) / k
            for a in (0.0, math.pi / 2, math.pi, 1.5 * math.pi, math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4,
                      7 * math.pi / 4):
                g.push(); g.move((x + rj * math.cos(a), yy, z + rj * math.sin(a))); g.turn("y", -a)
                g.box(M["joint"], (0.012, 0.05, 0.034), (0, 0, 0), 0.0)
                g.pop()
                g.count("event")
        for yy in (ya, yb):
            g.cyl(M[clamp], rj + 0.02, 0.05, (x, yy, z), axis="y", n=28, ch=0.008)
    if muzzle:
        g.cyl(M[clamp], ring_r + br + 0.035, 0.08, (x, y1 - 0.06, z), axis="y", n=24, ch=0.012)
        bolts_ring(g, M[bolt_mat], (x, y1 - 0.02, z), ring_r + br + 0.012, 6, axis="y", r=0.014)
    g.count("canon", n)


def ammo_belt(g, brass, link, pts, pitch=0.05, length=0.075, r=0.017):
    """Bande de cartouches (laiton) le long d'une trajectoire : cartouches perpendiculaires, maillons sombres."""
    P = catmull(pts, 8)
    up = (0, 0, 1)
    for p, d in resample(P, pitch):
        side = v_norm(v_cross(d, up))
        if v_len(side) < 0.5:
            side = (1, 0, 0)
        g.cyl(brass, r, length, p, axis=side, n=8)
        g.cyl(link, r * 1.15, MIN_T * 0.9, v_add(p, v_mul(side, length * 0.18)), axis=side, n=8)
        g.dome(link, r * 0.8, v_add(p, v_mul(side, length / 2)), axis=side, n=6, rings=2)
        g.count("cartouche")


# ------------------------------------------------------------------------------------------------
# Accessoires
# ------------------------------------------------------------------------------------------------
def lamp(g, emit_mat, housing, p, n=(0, -1, 0), size=0.07, cage=None):
    """Voyant encastré : boîtier, lentille lumineuse (petit foyer : la couleur d'époque vit ICI), grille."""
    g.push()
    g.frame(p, basis_from_z(n))
    g.cyl(housing, size * 1.05, 0.04, (0, 0, 0.02), n=14, ch=0.006)
    g.dome(emit_mat, size * 0.75, (0, 0, 0.04), n=12, rings=3, squash=0.8)
    if cage:
        for a in (0.0, math.pi / 2):
            g.push(); g.turn("z", a)
            g.box(cage, (size * 1.7, MIN_T, MIN_T), (0, 0, 0.04 + size * 0.55), 0.0)
            g.pop()
    g.pop()
    g.count("voyant")


def slit_light(g, emit_mat, frame, p, w, h, n=(0, -1, 0), bars=0):
    """Fente lumineuse derrière un cadre (et barreaux) : foyer petit et lisible."""
    g.push()
    g.frame(p, basis_from_z(n))
    g.box(frame, (w + 0.06, h + 0.06, 0.03), (0, 0, 0.0), 0.006)
    g.box(emit_mat, (w, h, 0.02), (0, 0, 0.012), 0.0)
    for i in range(bars):
        x = -w / 2 + (i + 1) * w / (bars + 1)
        g.box(frame, (MIN_T, h + 0.02, 0.03), (x, 0, 0.02), 0.0)
    g.pop()
    g.count("fente")


def hatch(g, mat, hinge, bolt_mat, size, c, n=(0, 0, 1)):
    """Trappe d'accès : plaque, 2 charnières, poignée, 4 boulons."""
    w, h, t = size
    g.push()
    g.frame(c, basis_from_z(n))
    g.box(mat, (w, h, t), (0, 0, t / 2), 0.008)
    for s in (-1, 1):
        g.cyl(hinge, 0.024, 0.1, (s * w * 0.3, h / 2 + 0.005, t / 2), axis="x", n=8)
    g.box(hinge, (w * 0.35, MIN_T, MIN_T + 0.01), (0, -h * 0.28, t + 0.02), 0.004)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bolt(g, bolt_mat, (sx * (w / 2 - 0.035), sy * (h / 2 - 0.035), t), r=0.018)
    g.pop()
    g.count("trappe")


def ladder(g, mat, p0, height, w=0.2, n=(0, -1, 0), rung=0.14):
    """Échelle à crinoline réduite (repère humain) : montants et barreaux de 2 px au moins."""
    x, y, z = p0
    dn = v_norm(n)
    off = v_mul(dn, 0.04)
    side = v_norm(v_cross((0, 0, 1), dn))
    for s in (-1, 1):
        q = v_add(v_add(p0, v_mul(side, s * w / 2)), off)
        g.box(mat, (MIN_T, MIN_T, height), (q[0], q[1], z + height / 2), 0.0)
    k = int(height / rung)
    for i in range(k):
        q = v_add(p0, off)
        g.push(); g.move((q[0], q[1], z + (i + 0.6) * rung)); g.turn("z", math.atan2(side[1], side[0]))
        g.box(mat, (w, MIN_T, MIN_T), (0, 0, 0), 0.0)
        g.pop()
    g.count("echelle")


def handrail(g, mat, pts, h=0.22, post_every=0.35):
    """Garde-corps : main courante (tube) et poteaux."""
    top = [(p[0], p[1], p[2] + h) for p in pts]
    g.path_tube(mat, top, 0.018, n=8)
    for p, d in resample([tuple(p) for p in pts], post_every):
        g.cyl(mat, 0.017, h, (p[0], p[1], p[2] + h / 2), n=8)
    g.count("garde_corps")


def piston(g, body, rod, p0, p1, r=0.05):
    """Vérin hydraulique : corps, tige chromée, chapes."""
    d = v_sub(p1, p0)
    L = v_len(d)
    u = v_norm(d)
    mid_body = v_add(p0, v_mul(u, L * 0.3))
    g.cyl(body, r, L * 0.6, mid_body, axis=u, n=14, ch=0.008)
    g.cyl(rod, r * 0.45, L * 0.5, v_add(p0, v_mul(u, L * 0.72)), axis=u, n=10)
    for q in (p0, p1):
        g.cyl(body, r * 0.9, r * 1.6, q, axis=v_norm(v_cross(u, (0, 0, 1))) if abs(u[2]) < 0.9 else (1, 0, 0), n=12)
    g.count("verin")


def crate(g, M, size, c, seed=0, mat="bois", band="acier", stencil=None):
    """Caisse de munitions cerclée : planches (joints), cornières, ferrures, boulons."""
    sx, sy, sz = size
    cx, cy, cz = c
    g.box(M["joint"], (sx - 0.02, sy - 0.02, sz - 0.01), (cx, cy, cz + sz / 2 - 0.005), 0.0)
    k = max(2, int(sz / 0.09))
    for i in range(k):
        z = cz + (i + 0.5) * sz / k
        g.box(M[mat], (sx, sy, sz / k - 0.012), (cx, cy, z), 0.006)
    g.box(M[mat], (sx - 0.03, sy - 0.03, 0.03), (cx, cy, cz + sz + 0.0), 0.006)
    for x in (cx - sx / 2, cx + sx / 2):
        for y in (cy - sy / 2, cy + sy / 2):
            g.box(M[band], (0.05, 0.05, sz + 0.01), (x, y, cz + sz / 2), 0.006)
    for z in (cz + 0.06, cz + sz - 0.06):
        g.box(M[band], (sx + 0.012, sy + 0.012, 0.036), (cx, cy, z), 0.004)
    for x in (cx - sx / 4, cx + sx / 4):
        bolt(g, M["boulon"], (x, cy - sy / 2 - 0.006, cz + sz * 0.5), (0, -1, 0), 0.016)
    if stencil:
        g.box(M[stencil], (sx * 0.4, 0.006, sz * 0.22), (cx, cy - sy / 2 - 0.003, cz + sz * 0.62), 0.0)
    g.count("caisse")


def exhaust(g, M, p, r, h, soot="suie"):
    """Échappement court : tube, collerette, chapeau pare-pluie, suie."""
    x, y, z = p
    g.cyl(M["acier"], r, h, (x, y, z + h / 2), n=16, ch=0.008)
    g.cyl(M["laiton"], r * 1.2, 0.04, (x, y, z + h * 0.3), n=16, ch=0.006)
    g.cyl(M[soot], r * 0.8, 0.02, (x, y, z + h + 0.005), n=14)
    g.cyl(M["acier"], r * 1.35, MIN_T, (x, y, z + h + 0.08), n=16, ch=0.006)
    for a in (0.0, TAU / 3, 2 * TAU / 3):
        g.box(M["acier"], (MIN_T, MIN_T, 0.08), (x + r * 0.9 * math.cos(a), y + r * 0.9 * math.sin(a), z + h + 0.04), 0.0)
    g.count("echappement")


def sensor(g, M, c, w=0.3, d=0.22, h=0.18, lens_emit=None):
    """Viseur / capteur : boîtier boulonné, deux optiques (verre sombre, lueur au fond), pare-soleil."""
    cx, cy, cz = c
    g.box(M["acier"], (w, d, h), (cx, cy, cz + h / 2), 0.012)
    g.box(M["tole"], (w + 0.03, d * 0.6, MIN_T), (cx, cy + d * 0.25, cz + h + 0.016), 0.006)
    for s in (-1, 1):
        g.cyl(M["joint"], h * 0.28, 0.06, (cx + s * w * 0.24, cy + d / 2 + 0.02, cz + h * 0.5), axis="y", n=14)
        g.cyl(M["verre"], h * 0.2, 0.02, (cx + s * w * 0.24, cy + d / 2 + 0.05, cz + h * 0.5), axis="y", n=14)
        if lens_emit:
            g.cyl(lens_emit, h * 0.08, 0.012, (cx + s * w * 0.24, cy + d / 2 + 0.062, cz + h * 0.5), axis="y", n=10)
    bolt(g, M["boulon"], (cx - w * 0.35, cy - d * 0.3, cz + h), r=0.016)
    bolt(g, M["boulon"], (cx + w * 0.35, cy - d * 0.3, cz + h), r=0.016)
    g.count("capteur")


def light_strip(g, emit_mat, frame, p0, p1, w=0.05, n=(0, 0, 1), cells=0):
    """Ligne lumineuse (« chenillard ») le long de p0 -> p1 sur une face de normale n : gorge, bande lumineuse,
    rebords ; cells > 0 : bande coupée en cellules (animation de chenillard ; chaque cellule est un petit foyer)."""
    u = v_norm(v_sub(p1, p0))
    z = v_norm(n)
    v = v_cross(z, u)
    L = v_len(v_sub(p1, p0))
    B = ((u[0], v[0], z[0]), (u[1], v[1], z[1]), (u[2], v[2], z[2]))
    g.push()
    g.frame(p0, B)
    g.box(frame, (L + 0.05, w + 0.07, 0.03), (L / 2, 0, 0.0), 0.008)
    if cells:
        cl = L / cells
        for i in range(cells):
            g.box(emit_mat, (cl - 0.035, w, 0.02), ((i + 0.5) * cl, 0, 0.012), 0.0)
    else:
        g.box(emit_mat, (L, w, 0.02), (L / 2, 0, 0.012), 0.0)
    for s in (-1, 1):
        g.box(frame, (L + 0.05, MIN_T, 0.03), (L / 2, s * (w / 2 + 0.02), 0.02), 0.004)
    g.pop()
    g.count("ligne_lumineuse")
