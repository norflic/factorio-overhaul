"""Ère III exotique (époques 7 à 9) : formes organiques ou rondes, pointes, bulbes, octogones (bible §1.2, §5)."""
import math

from centre_ere2 import _ogive, _panel_xz

R2 = 2.0 ** 0.5


def _h(i, a=0.0):
    return math.sin(i * 12.9898 + a * 78.233) * 0.5 + math.sin(i * 4.1414 + a * 1.618) * 0.5


def _crystal(k, tx, ty, z0, h, r, tilt, azim, body, glow, name, tip=1.6, n=6, rot=0.0, south=-0.25):
    """Cristal : prisme à n pans terminé en pointe, incliné de `tilt` vers la direction `azim` (Blender).
    Pans tournés vers la caméra (normale y < south) et pointe en matière lumineuse."""
    from mathutils import Matrix, Vector
    axis = Vector((-math.sin(azim), math.cos(azim), 0.0))
    R = Matrix.Rotation(tilt, 3, axis)
    base = Vector(k.P(tx, ty, z0))

    def ring(rr, z):
        return [tuple(R @ Vector((rr * math.cos(rot + 2 * math.pi * i / n), rr * math.sin(rot + 2 * math.pi * i / n), z)) + base)
                for i in range(n)]
    apex = tuple(R @ Vector((0, 0, h + tip * r)) + base)
    o = k.loft([ring(r * 0.82, 0.0), ring(r, h * 0.18), ring(r * 0.92, h), [apex]], body, name, bevel=0.006)
    if o is not None and glow is not None:
        o.data.materials.append(glow)
        for p in o.data.polygons:
            c = p.center
            if p.normal.y < south or (c.z > base.z + h * 0.98):
                p.material_index = 1
    return o


# ----------------------------------------------------------------------------------------------------------
# Époque 7 · Sanctuaire de résonance : socle de pierre taillée ; grand cristal central (point le plus haut) ;
# 4 éclats satellites ; armature de bronze ; cristaux qui respirent (script, phase 2).
# ----------------------------------------------------------------------------------------------------------
def build_e07(k):
    pierre = k.matte("pierre", "#4A4038", rough=0.8, grain=0.3, grain_scale=30.0)
    pierre_c = k.matte("pierre_claire", "#5C5046", rough=0.8, grain=0.3, grain_scale=30.0)
    bronze = k.metal("bronze", "#6A5236", rough=0.32, metallic=0.9, rust="#3F5E4E", rust_amount=0.3, dirt=0.4)
    cristal = k.glass("cristal", "#5E4A86")
    lueur = k.emit("cristal_lueur", "#B070FF", strength=1.35)

    # --- socle de pierre taillée (deux gradins octogonaux) et escalier sud ---
    k.ngon(0.0, 0.0, 1.78, 8, 0.0, 0.3, pierre, "socle_1", rot=math.pi / 8, sy=1.30, bevel=0.012)
    k.ngon(0.0, -0.1, 1.48, 8, 0.3, 0.5, pierre_c, "socle_2", rot=math.pi / 8, sy=1.30, bevel=0.012)
    for i, (ty0, ty1, z1) in enumerate(((1.25, 1.75, 0.12), (1.25, 1.62, 0.24), (1.2, 1.5, 0.36))):
        k.box(-0.32, 0.32, ty0, ty1, 0.0, z1, pierre_c, "marche_%d" % i, bevel=0.006)

    # --- sanctuaire (porte au sud), toit pyramidal ---
    k.box(-0.6, 0.6, 0.55, 1.2, 0.5, 1.12, pierre, "sanctuaire", bevel=0.01)
    k.prism([(-0.68, 0.48), (0.68, 0.48), (0.68, 1.27), (-0.68, 1.27)], 1.12, 1.46, bronze, "sanctuaire_toit",
            top_poly_game=[(-0.05, 0.85), (0.05, 0.85), (0.05, 0.9), (-0.05, 0.9)], bevel=0.008)
    _panel_xz(k, [(x, z + 0.5) for x, z in _ogive(0.21, 0.28, 0.5)], 1.2, 1.22, bronze, "porte_cadre")
    _panel_xz(k, [(x, z + 0.52) for x, z in _ogive(0.16, 0.25, 0.44)], 1.215, 1.235, pierre, "porte_vantail")
    _crystal(k, 0.0, 1.23, 1.04, 0.1, 0.075, 0.0, 0.0, cristal, lueur, "porte_cristal", tip=1.4, south=0.5)

    # --- grand cristal central (point le plus haut) ---
    cx, cty = 0.05, -0.55
    _crystal(k, cx, cty, 0.45, 3.35, 0.46, math.radians(6), math.radians(20), cristal, lueur, "grand_cristal", tip=1.55,
             rot=0.25)
    k.torus(cx, cty, 0.82, 0.52, 0.06, bronze, "sertissure_basse", minor_seg=12)
    k.torus(cx + 0.03, cty, 1.55, 0.5, 0.045, bronze, "sertissure_haute", minor_seg=12)
    # armature de bronze : 4 griffes courbes du socle à la sertissure haute (tiges)
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        a = k.P(cx + sx * 1.05, cty + sy * 0.75, 0.5)
        b = k.P(cx + sx * 0.36, cty + sy * 0.26, 1.55)
        c = (a[0] * 0.55 + b[0] * 0.45 + sx * 0.25, a[1] * 0.55 + b[1] * 0.45 - sy * 0.25, 1.35)
        pts = []
        for j in range(9):
            t = j / 8
            pts.append(tuple((1 - t) ** 2 * a[q] + 2 * (1 - t) * t * c[q] + t * t * b[q] for q in range(3)))
        segs = [k.rod(pts[j], pts[j + 1], 0.04, bronze, "griffe_%d_%d" % (i, j), verts=8, role="tige") for j in range(8)]
        k.join(segs, "griffe_%d" % i)

    # --- 4 éclats satellites, inclinés vers l'extérieur, et petites grappes ---
    shards = [(-1.22, -1.05, 1.95, 0.22, 140), (1.28, -0.95, 1.6, 0.2, 40), (-1.2, 0.5, 1.25, 0.18, 215),
              (1.18, 0.55, 1.05, 0.17, 320)]
    for i, (x, ty, h, r, az) in enumerate(shards):
        _crystal(k, x, ty, 0.3, h, r, math.radians(17), math.radians(az), cristal, lueur, "eclat_%d" % i, tip=1.5, rot=0.4 * i)
        for j in range(2):
            ang = math.radians(az + 70 * (j * 2 - 1))
            dx, dy = 0.22 * math.cos(ang), 0.22 * math.sin(ang) / R2
            _crystal(k, x + dx, ty - dy, 0.3, h * (0.32 + 0.1 * j), r * 0.45, math.radians(28),
                     ang, cristal, lueur, "grappe_%d_%d" % (i, j), tip=1.4, rot=0.7 * j)


# ----------------------------------------------------------------------------------------------------------
# Époque 8 · Serre-laboratoire : bâtiment bas ; 3 bulbes de verre de tailles décroissantes ; conduits ; liquide
# luminescent (lueur de jour) ; bulles animées par script en phase 2.
# ----------------------------------------------------------------------------------------------------------
def _bulb(k, tx, ty, z_drum0, z_drum1, r_drum, liquid, glass_prof, drum_mat, verre, liq_mat, cuivre, name):
    k.cyl(tx, ty, r_drum, z_drum0, z_drum1, drum_mat, name + "_tambour", verts=48)
    k.torus(tx, ty, z_drum1 - 0.04, r_drum + 0.01, 0.03, cuivre, name + "_cercle_haut", minor_seg=10)
    k.torus(tx, ty, z_drum0 + 0.12, r_drum + 0.01, 0.03, cuivre, name + "_cercle_bas", minor_seg=10)
    k.lathe(tx, ty, liquid, liq_mat, name + "_liquide", segs=48)
    k.lathe(tx, ty, glass_prof, verre, name + "_verre", segs=48)
    zl = liquid[-1][1]
    k.torus(tx, ty, zl, liquid[-1][0] + 0.005, 0.025, cuivre, name + "_joint", minor_seg=10)


def build_e08(k):
    vdg = k.metal("vert_de_gris", "#4F6B5A", rough=0.45, metallic=0.55, grain=0.2, dirt=0.5)
    vdg_s = k.metal("vert_de_gris_sombre", "#3C5246", rough=0.5, metallic=0.5, grain=0.2, dirt=0.5)
    cuivre = k.metal("cuivre", "#8A6A48", rough=0.35, metallic=0.85, rust="#4F6B5A", rust_amount=0.35, dirt=0.4)
    caout = k.matte("caoutchouc", "#2A2A28", rough=0.7, grain=0.1)
    verre = k.glass("verre", "#6F9A3E")
    liq = k.emit("liquide", "#A8FF3A", strength=1.0)
    liq_v = k.emit("liquide_vif", "#A8FF3A", strength=1.5)

    # --- bâtiment bas (laboratoire) ---
    k.box(-1.65, 1.65, 0.05, 1.4, 0.0, 0.62, vdg, "labo", bevel=0.012)
    k.box(-1.68, 1.68, 0.02, 1.43, 0.55, 0.66, vdg_s, "labo_corniche", bevel=0.006)
    k.box(-1.6, 1.6, -1.45, 0.1, 0.0, 0.32, vdg_s, "annexe_basse", bevel=0.01)
    k.door(-0.3, 0.3, 1.41, 0.5, cuivre, vdg_s, name="porte")
    for x in (-1.2, -0.75, 0.75, 1.2):
        k.box(x - 0.12, x + 0.12, 1.39, 1.42, 0.2, 0.44, cuivre, "fen_cadre_%d" % int((x + 2) * 100), bevel=0.004)
        k.box(x - 0.1, x + 0.1, 1.41, 1.43, 0.22, 0.42, liq if abs(x) > 1 else verre, "fen_%d" % int((x + 2) * 100), bevel=0)

    # --- grand bulbe (arrière gauche) ---
    _bulb(k, -0.3, -0.85, 0.0, 1.75, 0.78,
          [(0.78, 1.75), (0.92, 2.0), (0.97, 2.45)],
          [(0.97, 2.45), (0.94, 2.9), (0.82, 3.35), (0.6, 3.72), (0.3, 3.95), (0.0, 4.02)],
          vdg, verre, liq_v, cuivre, "grand_bulbe")
    for i, z in enumerate((1.0, 1.42)):
        k.hcyl("y", -0.33, -0.27, -0.3, 0, z, 0.15, cuivre, "hublot_cadre_%d" % i, verts=24, bevel=0.004)
        k.hcyl("y", -0.30, -0.255, -0.3, 0, z, 0.115, liq, "hublot_%d" % i, verts=24, bevel=0)
    # --- bulbe moyen (arrière droit) ---
    _bulb(k, 1.25, -0.5, 0.0, 1.05, 0.5,
          [(0.5, 1.05), (0.6, 1.22), (0.63, 1.45)],
          [(0.63, 1.45), (0.6, 1.75), (0.5, 2.02), (0.32, 2.25), (0.0, 2.33)],
          vdg, verre, liq, cuivre, "bulbe_moyen")
    # --- petit bulbe (sur le toit du labo, à gauche) ---
    _bulb(k, -1.15, 0.65, 0.62, 0.85, 0.3,
          [(0.3, 0.85), (0.37, 0.95), (0.39, 1.1)],
          [(0.39, 1.1), (0.37, 1.3), (0.28, 1.47), (0.14, 1.57), (0.0, 1.6)],
          vdg, verre, liq, cuivre, "petit_bulbe")

    # --- conduits (vert-de-gris) et tuyaux de caoutchouc ---
    pipes = []
    a, b = k.P(0.3, -0.85, 3.45), k.P(1.25, -0.5, 2.3)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 3.35)
    pts = [tuple((1 - t) ** 2 * a[q] + 2 * (1 - t) * t * mid[q] + t * t * b[q] for q in range(3)) for t in [j / 8 for j in range(9)]]
    pipes += [k.rod(pts[j], pts[j + 1], 0.06, cuivre, "conduit_bulbes_%d" % j, verts=12) for j in range(8)]
    pipes.append(k.hcyl("y", -0.85, 0.3, 0.55, 0, 0.42, 0.06, vdg_s, "conduit_labo_1", verts=14, bevel=0))
    pipes.append(k.cyl(0.55, -0.85 + 0.1, 0.06, 0.32, 0.9, vdg_s, "conduit_labo_v", verts=14, bevel=0))
    k.join(pipes, "conduits")
    hose = []
    a, b = k.P(-1.15 + 0.3, 0.65, 0.75), k.P(-0.3 - 0.6, -0.85 + 0.5, 1.0)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 0.55)
    pts = [tuple((1 - t) ** 2 * a[q] + 2 * (1 - t) * t * mid[q] + t * t * b[q] for q in range(3)) for t in [j / 6 for j in range(7)]]
    hose += [k.rod(pts[j], pts[j + 1], 0.045, caout, "tuyau_souple_%d" % j, verts=10) for j in range(6)]
    k.join(hose, "tuyau_souple")

    # --- antenne de cuivre au sommet du grand bulbe (tige, point le plus haut) ---
    k.mast(-0.3, -0.85, 4.0, 4.85, 0.02, cuivre, "antenne")
    k.sphere(-0.3, -0.85, 4.87, 0.05, liq_v, "antenne_bulbe", seg=16, rings=8, role="tige")


# ----------------------------------------------------------------------------------------------------------
# Époque 9 · Bunker atomique : corps octogonal chanfreiné ; 2 tours de refroidissement ; dôme de confinement ;
# hublots vert uranium (lueur de jour) ; trèfle ; balise de radiation au sommet (tige).
# ----------------------------------------------------------------------------------------------------------
def build_e09(k):
    plomb = k.metal("plomb", "#4A5058", rough=0.5, metallic=0.6, grain=0.18, dirt=0.55)
    beton = k.matte("beton", "#7A7670", rough=0.85, grain=0.22, grain_scale=35.0, dirt=0.55, gain=1.25)
    jaune = k.metal("jaune", "#C9A227", rough=0.5, metallic=0.25, grain=0.12, dirt=0.45, gain=1.1)
    noir = k.metal("noir", "#1E1E1E", rough=0.6, metallic=0.3, dirt=0.2)
    sombre = k.matte("gueule", "#141414", rough=0.9, grain=0.05)
    vert = k.emit("vert", "#5CFF4A", strength=1.4)

    oct_rot, sy = math.pi / 8, 1.31
    k.ngon(0.0, 0.05, 1.70, 8, 0.0, 0.1, jaune, "bande_pied", rot=oct_rot, sy=sy, bevel=0.004)
    k.ngon(0.0, 0.05, 1.68, 8, 0.1, 0.85, plomb, "corps", rot=oct_rot, sy=sy, bevel=0.012)
    k.ngon(0.0, 0.05, 1.68, 8, 0.85, 1.12, plomb, "chanfrein", r_top=1.40, rot=oct_rot, sy=sy, bevel=0.012)

    # --- 2 tours de refroidissement hyperboloïdes (arrière) ---
    for s, x, ty, ztop in ((-1, -1.05, -1.12, 3.95), (1, 1.1, -1.02, 3.5)):
        prof = [(0.62, 0.0), (0.54, 0.8), (0.46, 1.8), (0.42, ztop * 0.72), (0.45, ztop * 0.9), (0.5, ztop)]
        k.lathe(x, ty, prof, beton, "tour_refroid_%d" % s, segs=48)
        k.cyl(x, ty, 0.47, ztop - 0.08, ztop - 0.06, sombre, "tour_gueule_%d" % s, verts=40, bevel=0)
        k.torus(x, ty, ztop, 0.5, 0.025, plomb, "tour_levre_%d" % s, minor_seg=10)
        k.torus(x, ty, 0.5, 0.585, 0.03, jaune, "tour_bande_%d" % s, minor_seg=10)

    # --- dôme de confinement ---
    dty = -0.05
    k.cyl(0.0, dty, 0.95, 1.1, 1.4, beton, "dome_tambour", verts=64)
    k.cyl(0.0, dty, 0.955, 1.2, 1.3, vert, "dome_bande_verte", verts=64, bevel=0, caps=False)
    prof = [(0.92, 1.4)] + [(0.92 * math.cos(a), 1.4 + 0.92 * math.sin(a)) for a in [math.radians(d) for d in range(10, 91, 10)]]
    prof[-1] = (0.0, 2.32)
    k.lathe(0.0, dty, prof, plomb, "dome", segs=64)
    k.torus(0.0, dty, 1.42, 0.93, 0.035, jaune, "dome_bague", minor_seg=10)

    # --- façade sud : porte blindée, hublots verts, trèfle ---
    ty_f = 1.487
    k.box(-0.36, 0.36, ty_f - 0.03, ty_f + 0.05, 0.1, 0.68, jaune, "porte_cadre", bevel=0.006)
    k.box(-0.27, 0.27, ty_f, ty_f + 0.07, 0.12, 0.62, plomb, "porte_vantail", bevel=0.006)
    for i, z in enumerate((0.25, 0.45)):
        k.box(-0.27, 0.27, ty_f + 0.07, ty_f + 0.08, z - 0.02, z + 0.02, noir, "porte_chevron_%d" % i, bevel=0)
    for s in (-1, 1):
        k.hcyl("y", ty_f - 0.01, ty_f + 0.03, s * 0.5, 0, 0.45, 0.15, plomb, "hublot_cadre_%d" % s, verts=32, bevel=0.006)
        k.hcyl("y", ty_f + 0.01, ty_f + 0.045, s * 0.5, 0, 0.45, 0.115, vert, "hublot_%d" % s, verts=32, bevel=0)
    k.hcyl("y", ty_f - 0.01, ty_f + 0.03, 0.0, 0, 0.84, 0.17, jaune, "trefle_disque", verts=40, bevel=0)
    blades = []
    for i in range(3):
        a0 = math.radians(90 + 120 * i - 30)
        a1 = math.radians(90 + 120 * i + 30)
        pts = [(0.035 * math.cos(a0), 0.035 * math.sin(a0)), (0.15 * math.cos(a0), 0.15 * math.sin(a0)),
               (0.15 * math.cos((a0 + a1) / 2), 0.15 * math.sin((a0 + a1) / 2)), (0.15 * math.cos(a1), 0.15 * math.sin(a1)),
               (0.035 * math.cos(a1), 0.035 * math.sin(a1))]
        blades.append(_panel_xz(k, [(x, 0.84 + z) for x, z in pts], ty_f + 0.03, ty_f + 0.04, noir, "trefle_pale_%d" % i))
    k.join(blades, "trefle_pales")

    # --- balise de radiation au sommet (tige, point le plus haut) ---
    k.mast(0.0, dty, 2.3, 6.2, 0.028, plomb, "balise_mat")
    for z in (3.4, 4.6):
        k.cyl(0.0, dty, 0.06, z, z + 0.05, jaune, "balise_bague_%d" % int(z * 10), verts=12, bevel=0, role="tige")
    k.sphere(0.0, dty, 6.25, 0.07, vert, "balise_feu", seg=16, rings=8, role="tige")
