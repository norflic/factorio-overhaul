"""Volumes mécaniques du socle et de la tête, reprise de l'exploration « hybride » (lot V3-S, 22/10/2026, après midi).

Pourquoi ce module (critique de l'orchestrateur sur les essais de 8 h 50) : les socles précédents remplissaient
l'emprise avec un PONT PLAT (dalle carrée à coins coupés) ; au zoom 1 ils se lisaient comme des bunkers vus de
dessus. Le vanilla avancé (réacteur, silo, centrifugeuse) remplit son emprise avec des VOLUMES qui ont de la
hauteur : cuves, réservoirs, moteurs, gaines annelées, carters. Chaque fonction ci-dessous pose UN tel volume,
avec sa petite visserie (densité de détail, charte §3.2) et une fonction lisible (charte §4.1).

Python PUR (geo, kit). Repère : geo.py (1 unité = 1 tuile en X ; 1,414 unité = 1 tuile en Y ; +Z haut ; on voit
les faces SUD et le DESSUS ; le soleil vient de l'OUEST).
"""
import math

import kit as K
from geo import MIN_T, TAU, basis_from_z, catmull, resample, v_add, v_mul, v_norm, v_sub, v_len


# ------------------------------------------------------------------------------------------------
# Gaines et conduites
# ------------------------------------------------------------------------------------------------
def hose(g, mat, ring_mat, ctrl, r=0.05, pitch=0.042, per_seg=8, collar=None, bolt_mat=None):
    """Gaine annelée (réacteur et silo vanilla) : tube et anneaux serrés (chaque anneau attrape un reflet : c'est
    la lecture « tuyau souple » au zoom 1), colliers boulonnés aux deux bouts."""
    pts = catmull(ctrl, per_seg)
    g.path_tube(mat, pts, r * 0.92, n=12)
    for p, d in resample(pts, pitch)[1:-1]:
        g.torus(ring_mat, r * 0.93, r * 0.2, p, axis=d, n=14, m=4)
    g.count("anneau", max(0, len(resample(pts, pitch)) - 2))
    if collar:
        for p, d in ((pts[0], v_norm(v_sub(pts[1], pts[0]))), (pts[-1], v_norm(v_sub(pts[-1], pts[-2])))):
            g.cyl(collar, r * 1.45, 0.07, p, axis=d, n=16, ch=0.01)
            if bolt_mat:
                B = basis_from_z(d)
                for i in range(6):
                    a = TAU * i / 6
                    lp = (r * 1.45 * math.cos(a), r * 1.45 * math.sin(a), 0.0)
                    q = v_add(p, (B[0][0] * lp[0] + B[0][1] * lp[1], B[1][0] * lp[0] + B[1][1] * lp[1],
                                  B[2][0] * lp[0] + B[2][1] * lp[1]))
                    g.cyl(bolt_mat, 0.016, 0.09, q, axis=d, n=6)
    g.count("gaine")


def valve(g, M, c, axis="x", r=0.06):
    """Vanne : corps, volant à rayons (laiton), chapeau boulonné."""
    x, y, z = c
    g.cyl(M["acier"], r * 1.25, r * 2.2, c, axis=axis, n=16, ch=0.01)
    g.cyl(M["acier"], r * 0.5, r * 2.4, (x, y, z + r * 1.3), n=10)
    g.torus(M["laiton_tore"], r * 1.4, 0.016, (x, y, z + r * 2.5), n=24, m=5)
    for a in (0.0, math.pi / 2):
        g.push(); g.move((x, y, z + r * 2.5)); g.turn("z", a)
        g.box(M["laiton"], (r * 2.8, MIN_T, MIN_T), (0, 0, 0), 0.0)
        g.pop()
    K.bolts_ring(g, M["boulon"], (x, y, z + r * 1.25), r * 0.95, 6, r=0.013)
    g.count("vanne")


def gauge(g, M, c, n=(0, -1, 0), r=0.055):
    """Manomètre : boîtier laiton, cadran clair (petit), aiguille."""
    g.push()
    g.frame(c, basis_from_z(n))
    g.cyl(M["laiton"], r, 0.03, (0, 0, 0.015), n=16, ch=0.006)
    g.cyl(M["ivoire"], r * 0.78, 0.008, (0, 0, 0.032), n=16)
    g.box(M["noir"], (r * 0.9, MIN_T * 0.7, 0.006), (r * 0.2, r * 0.15, 0.038), 0.0)
    g.pop()
    g.count("manometre")


# ------------------------------------------------------------------------------------------------
# Cuves et réservoirs
# ------------------------------------------------------------------------------------------------
def tank_h(g, M, c, R, L, axis="x", body="tole", band="laiton_tore", n_bands=3, saddles=2, rivet_rows=6,
           cap_mat=None, manhole=True, saddle_mat="tole_sombre", gauge_side=None):
    """Réservoir couché (eau, vapeur, carburant) : virole, fonds bombés, cerclages, rangées de rivets, berceaux,
    trou d'homme, manomètre. axis : 'x' ou 'y'."""
    cx, cy, cz = c
    ax = (1, 0, 0) if axis == "x" else (0, 1, 0)
    g.cyl(M[body], R, L, c, axis=axis, n=40, ch=0.02)
    for s in (-1, 1):
        e = v_add(c, v_mul(ax, s * L / 2))
        g.dome(M[cap_mat or body], R * 0.97, e, axis=v_mul(ax, s), n=32, rings=5, squash=0.42)
        g.torus(M[band], R * 0.99, 0.022, v_add(c, v_mul(ax, s * (L / 2 - 0.03))), axis=axis, n=48, m=6)
        # rivets du fond
        K.bolts_ring(g, M["boulon"], v_add(e, v_mul(ax, s * R * 0.3)), R * 0.62, 12, axis=v_mul(ax, s), r=0.016,
                     kind="rivet")
    for i in range(n_bands):
        t = -L / 2 + (i + 1) * L / (n_bands + 1)
        g.torus(M[band], R + 0.008, 0.026, v_add(c, v_mul(ax, t)), axis=axis, n=48, m=6)
    # rangées de rivets longitudinales (visibles : dessus et face sud)
    for k in range(rivet_rows):
        a = -0.35 * math.pi + k * (1.15 * math.pi) / max(1, rivet_rows - 1)   # de l'avant-bas au dessus-arrière
        nrm = (0.0, -math.cos(a), math.sin(a)) if axis == "x" else (-math.cos(a), 0.0, math.sin(a))
        p0 = v_add(v_add(c, v_mul(nrm, R + 0.004)), v_mul(ax, -L / 2 + 0.08))
        p1 = v_add(v_add(c, v_mul(nrm, R + 0.004)), v_mul(ax, L / 2 - 0.08))
        K.bolts_line(g, M["boulon"], p0, p1, max(3, int(L / 0.13)), n=nrm, r=0.017, kind="rivet")
    if saddles:
        for i in range(saddles):
            t = -L / 2 + (i + 0.5) * L / saddles
            p = v_add(c, v_mul(ax, t))
            prof = [(-R * 0.95, 0.0), (R * 0.95, 0.0), (R * 0.82, cz - R * 0.5), (-R * 0.82, cz - R * 0.5)]
            if axis == "x":
                g.slab_x(M[saddle_mat], [(cy + u, w) for u, w in prof], p[0] - 0.06, p[0] + 0.06)
                for s in (-1, 1):
                    K.bolt(g, M["boulon"], (p[0], cy + s * R * 0.8, 0.05), (0, 0, 1), 0.018)
            else:
                g.slab(M[saddle_mat], [(cx + u, w) for u, w in prof], p[1] - 0.06, p[1] + 0.06)
                for s in (-1, 1):
                    K.bolt(g, M["boulon"], (cx + s * R * 0.8, p[1], 0.05), (0, 0, 1), 0.018)
    if manhole:
        g.cyl(M["acier"], R * 0.28, 0.06, (cx, cy, cz + R + 0.01), n=24, ch=0.01)
        K.bolts_ring(g, M["boulon"], (cx, cy, cz + R + 0.04), R * 0.22, 8, r=0.014)
    if gauge_side is not None:
        gauge(g, M, gauge_side, (0, -1, 0))
    g.count("reservoir")


def tank_v(g, M, c, R, H, body="tole", band="laiton_tore", n_bands=3, seams=10, top="dome", ladder=True):
    """Réservoir debout : virole, couvre-joints rivetés, cerclages, toit bombé, échelle côté sud-est."""
    cx, cy, cz = c
    g.cyl(M[body], R, H, (cx, cy, cz + H / 2), n=40, ch=0.02)
    for i in range(n_bands):
        z = cz + (i + 1) * H / (n_bands + 1)
        g.torus(M[band], R + 0.01, 0.026, (cx, cy, z), n=48, m=6)
    for i in range(seams):
        a = TAU * (i + 0.5) / seams
        if math.sin(a) > 0.55:          # face nord, invisible
            continue
        g.push(); g.move((cx + (R + 0.012) * math.cos(a), cy + (R + 0.012) * math.sin(a), cz + H / 2)); g.turn("z", a)
        g.box(M["tole_sombre"], (0.026, 0.07, H * 0.96), (0, 0, 0), 0.006)
        g.pop()
        K.bolts_line(g, M["boulon"], (cx + (R + 0.03) * math.cos(a), cy + (R + 0.03) * math.sin(a), cz + 0.08),
                     (cx + (R + 0.03) * math.cos(a), cy + (R + 0.03) * math.sin(a), cz + H - 0.08),
                     max(3, int(H / 0.12)), n=(math.cos(a), math.sin(a), 0), r=0.015, kind="rivet")
    if top == "dome":
        g.dome(M[body], R * 0.99, (cx, cy, cz + H), n=40, rings=5, squash=0.35)
        K.radial_rivets(g, M["boulon"], (cx, cy), R * 0.98, cz + H + 0.02, 20, r=0.015)
        g.cyl(M["acier"], R * 0.22, 0.08, (cx, cy, cz + H + R * 0.35 + 0.02), n=20, ch=0.01)
        K.bolts_ring(g, M["boulon"], (cx, cy, cz + H + R * 0.35 + 0.06), R * 0.17, 8, r=0.013)
    else:
        g.cyl(M["tole_sombre"], R * 1.02, 0.05, (cx, cy, cz + H + 0.025), n=40, ch=0.01)
        K.radial_rivets(g, M["boulon"], (cx, cy), R * 0.9, cz + H + 0.055, 18, r=0.015)
    if ladder:
        a = -0.35 * math.pi
        K.ladder(g, M["acier"], (cx + R * math.cos(a), cy + R * math.sin(a), cz), H * 0.95, w=0.14,
                 n=(math.cos(a), math.sin(a), 0))
    g.count("reservoir")


def chimney(g, M, c, r, h, ember=None, rings=4):
    """Cheminée rivetée à cerclages laiton et braises (ancre de style validée, cheminée V0)."""
    x, y, z = c
    g.cyl(M["tole_r"], r * 1.25, 0.12, (x, y, z + 0.06), n=24, ch=0.012)
    K.bolts_ring(g, M["boulon"], (x, y, z + 0.12), r * 1.08, 10, r=0.015)
    g.cyl(M["tole"], r, h, (x, y, z + h / 2), n=28, r2=r * 0.9, ch=0.01)
    for i in range(rings):
        zz = z + 0.2 + i * (h - 0.3) / max(1, rings - 1)
        rr = r - (r * 0.1) * (zz - z) / h
        g.torus(M["laiton_tore"], rr + 0.006, 0.02, (x, y, zz), n=32, m=6)
        K.radial_rivets(g, M["boulon"], (x, y), rr + 0.004, zz + 0.05, 12, r=0.013, phase=0.2 * i)
    g.cyl(M["acier"], r * 1.12, 0.07, (x, y, z + h), n=28, ch=0.012)
    g.cyl(M["suie"], r * 0.78, 0.02, (x, y, z + h + 0.03), n=20)
    if ember:
        g.cyl(M[ember], r * 0.6, 0.012, (x, y, z + h + 0.04), n=18)
        g.light((x, y, z + h + 0.12), (1.0, 0.45, 0.08), 3.0)
    g.count("cheminee")


# ------------------------------------------------------------------------------------------------
# Électricité et énergie
# ------------------------------------------------------------------------------------------------
def dynamo(g, M, c, R, L, axis="x", turns=10, body="tole_sombre"):
    """Dynamo / moteur bobiné couché : bobine de cuivre, cloches d'extrémité ajourées, socle boulonné, borne."""
    cx, cy, cz = c
    ax = (1, 0, 0) if axis == "x" else (0, 1, 0)
    K.coil(g, M["cuivre"], M["acier"], c, R, L, axis=axis, turns=turns, wire=0.03, flange=M[body])
    for s in (-1, 1):
        e = v_add(c, v_mul(ax, s * (L / 2 + 0.1)))
        g.cyl(M[body], R * 1.05, 0.16, e, axis=axis, n=32, ch=0.02)
        g.dome(M[body], R * 0.9, v_add(e, v_mul(ax, s * 0.08)), axis=v_mul(ax, s), n=24, rings=4, squash=0.35)
        K.bolts_ring(g, M["boulon"], v_add(e, v_mul(ax, s * 0.081)), R * 0.92, 10, axis=v_mul(ax, s), r=0.015)
        # fentes de ventilation sur la cloche (face sud)
        for k in range(5):
            a = -0.5 * math.pi + (k - 2) * 0.28
            p = v_add(e, (0.0, R * 1.06 * math.cos(a), R * 1.06 * math.sin(a))) if axis == "x" else \
                v_add(e, (R * 1.06 * math.cos(a), 0.0, R * 1.06 * math.sin(a)))
            g.box(M["joint"], (0.1 if axis == "x" else 0.03, 0.03 if axis == "x" else 0.1, 0.03), p, 0.0)
    # socle
    if axis == "x":
        g.box(M["tole_sombre"], (L + 0.3, R * 1.5, 0.08), (cx, cy, 0.04), 0.012)
        for sx in (-1, 1):
            g.slab_x(M["tole"], [(cy - R * 0.7, 0.08), (cy + R * 0.7, 0.08), (cy + R * 0.5, cz - R * 0.4),
                                 (cy - R * 0.5, cz - R * 0.4)], cx + sx * (L / 2 + 0.1) - 0.05, cx + sx * (L / 2 + 0.1) + 0.05)
            for sy in (-1, 1):
                K.bolt(g, M["boulon"], (cx + sx * (L / 2 + 0.1), cy + sy * R * 0.62, 0.08), (0, 0, 1), 0.017)
    # boîte à bornes
    g.box(M["acier"], (0.2, 0.16, 0.14), (cx, cy - R * 0.2, cz + R + 0.05), 0.012)
    for s in (-1, 1):
        g.cyl(M["cuivre"], 0.02, 0.08, (cx + s * 0.05, cy - R * 0.2, cz + R + 0.16), n=8)
    g.count("dynamo")


def generator(g, M, c, R, L, axis="x", cap="creme", fins=14, body="tole_sombre"):
    """Groupe générateur (ère IV-V, à la manière du réacteur vanilla) : carter cylindrique couché, fonds peints
    patinés, ailettes de refroidissement circulaires, boîte à bornes, colliers."""
    cx, cy, cz = c
    ax = (1, 0, 0) if axis == "x" else (0, 1, 0)
    g.cyl(M[body], R, L, c, axis=axis, n=48, ch=0.02)
    for i in range(fins):
        t = -L * 0.32 + i * (L * 0.64) / max(1, fins - 1)
        g.cyl(M["acier"], R * 1.13, 0.03, v_add(c, v_mul(ax, t)), axis=axis, n=40, ch=0.008)
    g.count("ailette", fins)
    for s in (-1, 1):
        e = v_add(c, v_mul(ax, s * L / 2))
        g.cyl(M[cap], R * 1.06, 0.2, v_add(e, v_mul(ax, s * 0.02)), axis=axis, n=48, ch=0.03)
        g.dome(M[cap], R * 0.96, v_add(e, v_mul(ax, s * 0.12)), axis=v_mul(ax, s), n=40, rings=6, squash=0.38)
        K.bolts_ring(g, M["boulon"], v_add(e, v_mul(ax, s * 0.125)), R * 0.98, 18, axis=v_mul(ax, s), r=0.017)
        K.bolts_ring(g, M["boulon"], v_add(e, v_mul(ax, s * (0.12 + R * 0.3))), R * 0.5, 8, axis=v_mul(ax, s),
                     r=0.016)
        g.cyl(M["acier"], R * 0.2, 0.12, v_add(e, v_mul(ax, s * (0.12 + R * 0.38))), axis=axis, n=20, ch=0.01)
    # berceaux
    for s in (-1, 1):
        p = v_add(c, v_mul(ax, s * L * 0.38))
        prof = [(-R * 0.95, 0.0), (R * 0.95, 0.0), (R * 0.8, cz - R * 0.45), (-R * 0.8, cz - R * 0.45)]
        if axis == "x":
            g.slab_x(M["tole"], [(cy + u, w) for u, w in prof], p[0] - 0.07, p[0] + 0.07)
        else:
            g.slab(M["tole"], [(cx + u, w) for u, w in prof], p[1] - 0.07, p[1] + 0.07)
    # boîte à bornes sur le dessus et isolateurs
    g.box(M["acier"], (0.42, 0.3, 0.2), (cx, cy - R * 0.15, cz + R + 0.08), 0.014)
    K.bolts_line(g, M["boulon"], (cx - 0.17, cy - R * 0.15 - 0.15, cz + R + 0.16), (cx + 0.17, cy - R * 0.15 - 0.15,
                 cz + R + 0.16), 4, n=(0, -1, 0), r=0.014)
    for s in (-1, 0, 1):
        K.insulator_stack(g, M["porcelaine"], M["laiton"], (cx + s * 0.13, cy - R * 0.15, cz + R + 0.18), 3, 0.045,
                          0.03, 0.03)
    g.count("generateur")


def capacitors(g, M, c, nx, ny, r=0.11, h=0.42, pitch=0.27, emit=None):
    """Batterie de condensateurs sur un sommier boulonné."""
    cx, cy, cz = c
    w, d = nx * pitch + 0.1, ny * pitch + 0.1
    g.box(M["tole_sombre"], (w, d, 0.1), (cx, cy, cz + 0.05), 0.014)
    K.bolts_line(g, M["boulon"], (cx - w / 2 + 0.05, cy - d / 2 - 0.002, cz + 0.05), (cx + w / 2 - 0.05, cy - d / 2 - 0.002,
                 cz + 0.05), max(3, int(w / 0.14)), n=(0, -1, 0), r=0.014)
    K.capacitor_bank(g, M, (cx, cy, cz + 0.1), nx, ny, r=r, h=h, pitch=pitch, emit=emit)


def cell_tower(g, M, c, w, d, n, cell_h=0.22, emit=None, frame="tole_sombre", cap="or_blanc"):
    """Réserve d'énergie visible (ère V) : pile de cellules dans un cadre à montants, une petite fenêtre lumineuse
    par cellule (on AJOUTE des foyers, on ne les agrandit pas), barres de liaison, chapeau."""
    cx, cy, cz = c
    z = cz
    g.box(M[frame], (w + 0.1, d + 0.1, 0.1), (cx, cy, z + 0.05), 0.014)
    z += 0.1
    for i in range(n):
        g.box(M["acier"] if i % 2 else M["tole"], (w, d, cell_h - 0.03), (cx, cy, z + cell_h / 2), 0.014)
        g.box(M["joint"], (w + 0.02, d + 0.02, 0.03), (cx, cy, z + cell_h - 0.015), 0.004)
        if emit:
            # une bande de charge par cellule (pile de batterie), pas une grille de fenêtres
            K.slit_light(g, M[emit], M["acier"], (cx, cy - d / 2 - 0.012, z + cell_h * 0.5), w * 0.62, 0.05,
                         (0, -1, 0), bars=3)
            K.slit_light(g, M[emit], M["acier"], (cx - w / 2 - 0.012, cy, z + cell_h * 0.5), d * 0.5, 0.05,
                         (-1, 0, 0), bars=2)
        for s in (-1, 1):
            K.bolt(g, M["boulon"], (cx + s * (w / 2 - 0.04), cy - d / 2, z + cell_h * 0.2), (0, -1, 0), 0.014)
        g.count("cellule")
        z += cell_h
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.box(M[frame], (0.06, 0.06, z - cz), (cx + sx * (w / 2 + 0.02), cy + sy * (d / 2 + 0.02), cz + (z - cz) / 2),
                  0.01)
    g.box(M[cap], (w + 0.14, d + 0.14, 0.07), (cx, cy, z + 0.035), 0.02)
    K.bolts_ring(g, M["boulon"], (cx, cy, z + 0.07), min(w, d) * 0.38, 8, r=0.014)
    for s in (-1, 1):
        g.cyl(M["cuivre"], 0.03, 0.1, (cx + s * w * 0.25, cy, z + 0.12), n=10)
        g.dome(M["cuivre"], 0.032, (cx + s * w * 0.25, cy, z + 0.17), n=8, rings=2)
    g.count("tour_cellules")
    return z + 0.07


def radiator(g, M, c, w, d, h, n_fins=14, axis="x", grille_s=True):
    """Radiateur : caisson, ailettes sur le dessus, grille sud, collecteurs et bouchons."""
    cx, cy, cz = c
    g.box(M["tole_sombre"], (w, d, h), (cx, cy, cz + h / 2), 0.016)
    K.fins(g, M["acier"], M["tole"], w * 0.9 if axis == "x" else d * 0.9, 0.14, d * 0.8 if axis == "x" else w * 0.8,
           n_fins, (cx, cy, cz + h), axis=axis)
    if grille_s:
        K.grille(g, M["acier"], M["tole_sombre"], w * 0.8, h * 0.62, (cx, cy - d / 2 - 0.004, cz + h * 0.5),
                 normal=(0, -1, 0), deep_mat=M["joint"])
    for s in (-1, 1):
        g.cyl(M["cuivre"], 0.045, d * 0.9, (cx + s * (w / 2 + 0.03), cy, cz + h * 0.75), axis="y", n=12)
        g.cyl(M["laiton"], 0.06, 0.04, (cx + s * (w / 2 + 0.03), cy - d * 0.45, cz + h * 0.75), axis="y", n=12)
    K.bolts_line(g, M["boulon"], (cx - w / 2 + 0.05, cy - d / 2, cz + h - 0.04), (cx + w / 2 - 0.05, cy - d / 2, cz + h - 0.04),
                 max(3, int(w / 0.13)), n=(0, -1, 0), r=0.014)
    g.count("radiateur")


# ------------------------------------------------------------------------------------------------
# Structure
# ------------------------------------------------------------------------------------------------
def foot(g, M, c, w=0.42, d=0.42, h=0.12, gusset=True):
    """Semelle d'ancrage (connecteurs d'angle du réacteur vanilla) : plaque, goussets, 4 boulons d'ancrage."""
    cx, cy, cz = c
    g.box(M["tole_sombre"], (w, d, h), (cx, cy, cz + h / 2), 0.016)
    g.box(M["acier"], (w * 0.6, d * 0.6, 0.06), (cx, cy, cz + h + 0.03), 0.012)
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.bolt(g, M["boulon"], (cx + sx * (w / 2 - 0.06), cy + sy * (d / 2 - 0.06), cz + h), (0, 0, 1), 0.022,
                   washer=M["acier"])
    if gusset:
        for a in (0, 1):
            if a == 0:
                g.slab_x(M["tole"], [(cy - d * 0.3, cz + h), (cy + d * 0.3, cz + h), (cy, cz + h + 0.18)], cx - 0.02, cx + 0.02)
            else:
                g.slab(M["tole"], [(cx - w * 0.3, cz + h), (cx + w * 0.3, cz + h), (cx, cz + h + 0.18)], cy - 0.02, cy + 0.02)
    g.count("semelle")


def ring_drum(g, M, R, z0, z1, n_butt=12, butt_out=0.22, body="tole_sombre", emit=None, seed=0, bays=True,
              band="laiton_tore", hazard=True, r_in=None):
    """Couronne de soubassement (ère IV-V) : fût bas, contreforts rayonnants (volumes en saillie, ombres internes),
    entre les contreforts des baies (trappes, grilles, voyants) ; bande de danger au pied."""
    h = z1 - z0
    g.cyl(M[body], R, h, (0, 0, z0 + h / 2), n=72, ch=0.02)
    g.cyl(M["acier"], R + 0.03, 0.06, (0, 0, z1 - 0.03), n=72, ch=0.012)
    K.radial_rivets(g, M["boulon"], (0, 0), R + 0.035, z1 - 0.03, int(R * 22), r=0.014)
    if band:
        g.torus(M[band], R + 0.012, 0.026, (0, 0, z0 + h * 0.62), n=96, m=6)
    for i in range(n_butt):
        a = TAU * (i + 0.5) / n_butt
        g.push(); g.move((R * math.cos(a), R * math.sin(a), z0)); g.turn("z", a)
        prof = [(-0.02, 0.0), (butt_out, 0.0), (butt_out, h * 0.32), (0.02, h + 0.02), (-0.02, h + 0.02)]
        g.slab(M["tole"], prof, -0.07, 0.07)
        K.bolts_line(g, M["boulon"], (butt_out * 0.4, -0.072, 0.06), (butt_out * 0.4, -0.072, h * 0.55), 3, n=(0, -1, 0),
                     r=0.014)
        g.box(M["acier"], (butt_out + 0.06, 0.2, 0.04), (butt_out / 2, 0, 0.02), 0.008)
        g.pop()
        if bays:
            b = TAU * i / n_butt
            if math.sin(b) > 0.45:
                continue
            g.push(); g.move(((R + 0.012) * math.cos(b), (R + 0.012) * math.sin(b), z0 + h * 0.5)); g.turn("z", b)
            k = (i + seed) % 3
            if k == 0:
                K.grille(g, M["acier"], M["tole_sombre"], 0.34, h * 0.55, (0, 0, 0), normal=(1, 0, 0), deep_mat=M["joint"])
            elif k == 1:
                K.hatch(g, M["tole_b"], M["acier"], M["boulon"], (0.32, h * 0.5, 0.03), (0, 0, 0), n=(1, 0, 0))
            else:
                g.box(M["tole_r"], (0.03, 0.34, h * 0.55), (0.0, 0, 0), 0.008)
                for dy in (-0.13, 0.13):
                    for dz in (-h * 0.2, h * 0.2):
                        K.bolt(g, M["boulon"], (0.015, dy, dz), (1, 0, 0), 0.014)
                if emit:
                    K.lamp(g, M[emit], M["acier"], (0.02, 0, h * 0.05), (1, 0, 0), 0.04)
            g.pop()
    if hazard:
        k = int(TAU * R / 0.12)
        for i in range(k):
            if i % 2:
                continue
            a0 = TAU * i / k
            a1 = TAU * (i + 1) / k
            poly = [((R + 0.005) * math.cos(a0), (R + 0.005) * math.sin(a0)),
                    ((R + 0.005) * math.cos(a1), (R + 0.005) * math.sin(a1)),
                    ((R + 0.03) * math.cos(a1), (R + 0.03) * math.sin(a1)),
                    ((R + 0.03) * math.cos(a0), (R + 0.03) * math.sin(a0))]
            g.prism(M["jaune"], poly, z0 + 0.03, z0 + 0.11)
        g.cyl(M["noir"], R + 0.012, 0.08, (0, 0, z0 + 0.07), n=96)
        g.count("bande_danger", k // 2)
    if r_in:
        # dessus : secteurs de tôle boulonnés (joints rayonnants) entre le fût supérieur et le bord
        ns = n_butt * 2
        mats = [M["tole"], M["tole_b"], M["tole_r"], M[body]]
        for i in range(ns):
            a0 = TAU * i / ns + 0.012
            a1 = TAU * (i + 1) / ns - 0.012
            r0, r1 = r_in + 0.02, R - 0.05
            poly = [(r0 * math.cos(a0), r0 * math.sin(a0)), (r1 * math.cos(a0), r1 * math.sin(a0)),
                    (r1 * math.cos(a1), r1 * math.sin(a1)), (r0 * math.cos(a1), r0 * math.sin(a1))]
            g.prism(mats[(i * 3 + seed) % len(mats)], poly, z1, z1 + 0.022)
            if math.sin((a0 + a1) / 2) > 0.7:
                continue
            for rr, aa in ((r1 - 0.05, a0 + 0.04), (r1 - 0.05, a1 - 0.04), (r0 + 0.05, (a0 + a1) / 2)):
                K.bolt(g, M["boulon"], (rr * math.cos(aa), rr * math.sin(aa), z1 + 0.022), (0, 0, 1), 0.016)
            if i % 4 == 1:
                am = (a0 + a1) / 2
                rm = (r0 + r1) / 2
                g.push(); g.move((rm * math.cos(am), rm * math.sin(am), z1 + 0.022)); g.turn("z", am)
                g.box(M["acier"], (0.12, 0.16, 0.08), (0, 0, 0.04), 0.01)
                g.cyl(M["cuivre"], 0.018, 0.1, (0.0, 0.0, 0.1), n=8)
                g.pop()
                g.count("boite_derivation")
    g.count("couronne")


def crate_stack(g, M, c, sizes, seed=0, stencil="jaune"):
    """Pile de caisses de munitions (bois cerclé, ferrures) posées en quinconce."""
    cx, cy, cz = c
    z = cz
    for i, (sx, sy, sz, dx, dy) in enumerate(sizes):
        K.crate(g, M, (sx, sy, sz), (cx + dx, cy + dy, z if dx == 0 and dy == 0 else cz + (sz if i > 1 else 0)), seed=seed + i,
                stencil=stencil)
    g.count("pile_caisses")


def ammo_box(g, M, size, c, belt_slot=True, stencil="jaune", body="peint"):
    """Coffre à munitions métallique (ère II à V) : coffre peint, couvercle à charnières, poignées, pochoir."""
    sx, sy, sz = size
    cx, cy, cz = c
    g.box(M[body], (sx, sy, sz), (cx, cy, cz + sz / 2), 0.016)
    g.box(M["acier"], (sx + 0.02, sy + 0.02, 0.05), (cx, cy, cz + sz - 0.02), 0.01)
    for s in (-1, 1):
        g.box(M["acier"], (sx + 0.03, 0.04, sz * 0.9), (cx, cy + s * sy * 0.32, cz + sz * 0.46), 0.006)
    g.box(M["acier"], (sx * 0.3, 0.03, 0.03), (cx, cy - sy / 2 - 0.02, cz + sz * 0.72), 0.006)
    if stencil:
        g.box(M[stencil], (sx * 0.42, 0.006, sz * 0.18), (cx, cy - sy / 2 - 0.003, cz + sz * 0.42), 0.0)
    for s in (-1, 1):
        K.bolt(g, M["boulon"], (cx + s * (sx / 2 - 0.05), cy - sy / 2, cz + sz * 0.15), (0, -1, 0), 0.015)
        K.bolt(g, M["boulon"], (cx + s * (sx / 2 - 0.05), cy - sy / 2, cz + sz * 0.62), (0, -1, 0), 0.015)
    if belt_slot:
        g.box(M["joint"], (sx * 0.5, sy * 0.3, 0.02), (cx, cy, cz + sz + 0.01), 0.0)
    g.count("coffre_munitions")


# ------------------------------------------------------------------------------------------------
# Coque blindée lissée (tête des ères IV-V : tourelle de char, pas de cadre ouvert)
# ------------------------------------------------------------------------------------------------
def _ccw(poly):
    a = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    return poly if a > 0 else poly[::-1]


def loft(g, mat, poly0, z0, poly1, z1, caps=(True, True)):
    """Solide convexe entre deux polygones (même nombre de sommets, même ordre) aux hauteurs z0 et z1."""
    poly0, poly1 = _ccw(poly0), _ccw(poly1)
    n = len(poly0)
    v = [(x, y, z0) for x, y in poly0] + [(x, y, z1) for x, y in poly1]
    c = (sum(p[0] for p in v) / len(v), sum(p[1] for p in v) / len(v), (z0 + z1) / 2.0)
    f = []
    if caps[0]:
        f.append(list(range(n)))
    if caps[1]:
        f.append(list(range(n, 2 * n)))
    f += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    g.add(mat, v, f, False, ref=c)
    g.count("coque")


def point_in_poly(x, y, poly):
    ins = False
    n = len(poly)
    for i in range(n):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            ins = not ins
    return ins


def plate_loft(g, M, poly0, z0, poly1, z1, mats, rows=2, col_len=0.42, bolt_mat=None, t=0.032, gap=0.03, skip=None,
               emit=None, emit_every=0, seed=0, top=True, top_div=0.38):
    """Habille un loft de plaques boulonnées : sur chaque face latérale (grille rangées × colonnes, plaques posées
    dans le plan incliné), et sur le dessus (plaques jointives découpées par le polygone). skip(i, normale) -> True :
    face non habillée (arrière invisible). emit : voyants en bas de face, un toutes les emit_every plaques."""
    poly0, poly1 = _ccw(poly0), _ccw(poly1)
    n = len(poly0)
    bolt_mat = bolt_mat or M["boulon"]
    k = seed
    for i in range(n):
        a0, a1 = poly0[i], poly0[(i + 1) % n]
        b0, b1 = poly1[i], poly1[(i + 1) % n]
        P00, P10 = (a0[0], a0[1], z0), (a1[0], a1[1], z0)
        P01, P11 = (b0[0], b0[1], z1), (b1[0], b1[1], z1)
        u = v_sub(P10, P00)
        L = v_len(u)
        if L < 0.15:
            continue
        nrm = v_norm((u[1], -u[0], 0.0))            # extérieur (polygone CCW)
        up = v_sub(v_mul(v_add(P01, P11), 0.5), v_mul(v_add(P00, P10), 0.5))
        nrm3 = v_norm(cross(u, up))
        if nrm3[0] * nrm[0] + nrm3[1] * nrm[1] < 0:
            nrm3 = v_mul(nrm3, -1)
        if skip and skip(i, nrm3):
            continue
        cols = max(1, int(round(L / col_len)))
        for r in range(rows):
            for c in range(cols):
                s0, s1 = (c + 0.0) / cols, (c + 1.0) / cols
                t0, t1 = (r + 0.0) / rows, (r + 1.0) / rows

                def bil(s, tt):
                    bot = v_add(P00, v_mul(v_sub(P10, P00), s))
                    tp = v_add(P01, v_mul(v_sub(P11, P01), s))
                    return v_add(bot, v_mul(v_sub(tp, bot), tt))
                q00, q10, q01 = bil(s0, t0), bil(s1, t0), bil(s0, t1)
                q11 = bil(s1, t1)
                ctr = v_mul(v_add(v_add(q00, q10), v_add(q01, q11)), 0.25)
                uu = v_norm(v_sub(q10, q00))
                vv = v_norm(cross(nrm3, uu))
                w = v_len(v_sub(q10, q00)) - gap
                h = v_len(v_sub(v_mul(v_add(q01, q11), 0.5), v_mul(v_add(q00, q10), 0.5))) - gap
                if w < 0.06 or h < 0.06:
                    continue
                B = ((uu[0], vv[0], nrm3[0]), (uu[1], vv[1], nrm3[1]), (uu[2], vv[2], nrm3[2]))
                g.push(); g.frame(ctr, B)
                m = mats[(k * 7 + r * 3 + c) % len(mats)]
                g.box(m, (w, h, t), (0, 0, t / 2), 0.012)
                for sx in (-1, 1):
                    for sy in (-1, 1):
                        K.bolt(g, bolt_mat, (sx * (w / 2 - 0.04), sy * (h / 2 - 0.04), t), (0, 0, 1), 0.016)
                kb = int((w - 0.08) / 0.12)
                for ib in range(1, kb):
                    xb = -w / 2 + 0.04 + ib * (w - 0.08) / kb
                    for sy in (-1, 1):
                        K.rivet(g, bolt_mat, (xb, sy * (h / 2 - 0.04), t), (0, 0, 1), 0.014)
                if emit and emit_every and r == 0 and (c + k) % emit_every == 0:
                    g.box(emit, (min(0.16, w * 0.45), 0.05, 0.02), (0, -h / 2 + 0.075, t + 0.008), 0.0)
                g.pop()
                g.count("plaque")
        k += 1
    if top:
        xs = [p[0] for p in poly1]
        ys = [p[1] for p in poly1]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        nx = max(1, int(round((x1 - x0) / top_div)))
        ny = max(1, int(round((y1 - y0) / top_div)))
        dx, dy = (x1 - x0) / nx, (y1 - y0) / ny
        for i in range(nx):
            for j in range(ny):
                cx, cy = x0 + (i + 0.5) * dx, y0 + (j + 0.5) * dy
                corners = [(cx + sx * dx * 0.45, cy + sy * dy * 0.45) for sx in (-1, 1) for sy in (-1, 1)]
                if not all(point_in_poly(px, py, poly1) for px, py in corners):
                    continue
                m = mats[(i * 5 + j * 3 + seed) % len(mats)]
                K.plate(g, m, bolt_mat, (dx - gap, dy - gap, t), (cx, cy, z1 + t / 2), spacing=0.2, r=0.017)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def glow_cells_ring(g, M, emit, R, z, n, a0=-math.pi + 0.25, a1=-0.25, w=0.16, h=0.075, frame="acier"):
    """Cellules lumineuses ESPACÉES sur la paroi d'un fût (chacune est un petit foyer distinct : on ajoute des
    foyers, on ne les agrandit pas) ; cadre sombre autour."""
    for i in range(n):
        a = a0 + (a1 - a0) * (i + 0.5) / n
        g.push(); g.move((R * math.cos(a), R * math.sin(a), z)); g.turn("z", a)
        g.box(M[frame], (0.03, w + 0.06, h + 0.05), (0.0, 0, 0), 0.006)
        g.box(M[emit], (0.032, w, h), (0.006, 0, 0), 0.0)
        g.pop()
    g.count("cellule_lumineuse", n)
