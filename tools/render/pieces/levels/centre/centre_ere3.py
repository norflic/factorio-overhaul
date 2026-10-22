"""Ère III exotique (époques 7 à 9) : formes organiques ou rondes, pointes, bulbes, octogones (bible §1.2, §5).

Correction V3 du 22/10 (vérification adverse) :
  - époque 7 : la lueur ne couvre plus que les faces avant du grand cristal et les pointes (part émissive
    34,8 % -> proche de la proposition de 5 % de la bible §1.6) ; joints de pierre, armature de bronze ;
  - époque 8 : le corps n'est plus une boîte (problème majeur 4) : un grand BALLON de verre bombé sur une cuve
    ronde, empli de liquide luminescent jusqu'à sa panse, verre TRANSLUCIDE au-dessus (on voit le serpentin et
    le plateau de cuivre à travers : problème mineur 6), montants de serre en cuivre, 2 ballons plus petits ;
  - époque 9 : tours de refroidissement écartées (L 3,39 -> enveloppe 3,69), coutures, bandes, évents.
"""
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
    pierre = k.matte("pierre", "#4A4038", rough=0.75, grain=0.34, grain_scale=30.0)
    pierre_c = k.matte("pierre_claire", "#5C5046", rough=0.75, grain=0.34, grain_scale=30.0)
    joint = k.matte("joint", "#2A2420", grain=0.2)
    bronze = k.metal("bronze", "#6A5236", rough=0.28, metallic=0.9, rust="#3F5E4E", rust_amount=0.32, dirt=0.45)
    bronze_p = k.metal("bronze_poli", "#9A7A48", rough=0.22, metallic=0.95, clean=True)
    cristal = k.metal("cristal", "#5E4A86", rough=0.1, metallic=0.0, clean=True, bump=0.25, stain=0.12)
    lueur = k.emit("cristal_lueur", "#B070FF", strength=1.0)

    # --- socle de pierre taillée (deux gradins octogonaux) et escalier sud ---
    # Correction V3 du 22/10 : socle RÉDUIT (rayon 1,78 -> 1,40) ; les éclats satellites jaillissent du SOL aux
    # angles : le corps ne remplit plus l'emprise comme les blocs des ères I et II (IoU des corps 0,83 avec E2 et E5)
    R1, R2s = 1.40, 1.15
    k.ngon(0.0, 0.0, R1, 8, 0.0, 0.3, pierre, "socle_1", rot=math.pi / 8, sy=1.30, bevel=0.012)
    k.ngon(0.0, -0.1, R2s, 8, 0.3, 0.5, pierre_c, "socle_2", rot=math.pi / 8, sy=1.30, bevel=0.012)
    # joints de taille : lits horizontaux et joints montants sur les pans visibles des gradins
    k.ngon(0.0, 0.0, R1 + 0.005, 8, 0.145, 0.158, joint, "socle_1_lit", rot=math.pi / 8, sy=1.30, bevel=0)
    k.ngon(0.0, -0.1, R2s + 0.005, 8, 0.395, 0.405, joint, "socle_2_lit", rot=math.pi / 8, sy=1.30, bevel=0)
    k.ngon(0.0, -0.1, R2s + 0.02, 8, 0.48, 0.52, bronze, "socle_2_liseré", rot=math.pi / 8, sy=1.30, bevel=0.004)
    cx0, cy0, _ = k.P(0.0, 0.0, 0)
    jts = []
    for i in range(24):
        a = math.pi + math.pi * (i + 0.5) / 24
        for z0, z1 in ((0.02, 0.145), (0.158, 0.29)):
            off = 0.5 if z0 > 0.1 else 0.0
            aa = math.pi + math.pi * (i + off) / 24
            xx, yy = R1 * 0.945 * math.cos(aa), 1.30 * R1 * 0.945 * math.sin(aa)
            jts.append(k.rod((cx0 + xx, cy0 + yy, z0), (cx0 + xx, cy0 + yy, z1), 0.008, joint, "joint_%d_%d" % (i, int(z0 * 100))))
    k.join(jts, "joints_montants")
    # dallage du palier des deux gradins (joints creux entre les dalles ; passe 3 : Laplacien 22,4 -> détail)
    def in_oct(xa, xb, a, b, R, cty):
        for x, ty in ((xa, a), (xb, a), (xa, b), (xb, b)):
            if (x / (R * 0.92)) ** 2 + ((ty - cty) * R2 / (1.30 * R * 0.92)) ** 2 > 1.0:
                return False
        return True
    k.panels(-R1, R1, -R1 * 1.3 / R2, R1 * 1.3 / R2, 0.0, 0.3, pierre_c, "dallage_1", top=(9, 7), south=None, gap=0.03,
             thick=0.014, skip=lambda f, xa, xb, a, b: not in_oct(xa, xb, a, b, R1, 0.0))
    k.panels(-R2s, R2s, -0.1 - R2s * 1.3 / R2, -0.1 + R2s * 1.3 / R2, 0.0, 0.5, pierre, "dallage_2", top=(7, 6), south=None,
             gap=0.03, thick=0.012, skip=lambda f, xa, xb, a, b: not in_oct(xa, xb, a, b, R2s, -0.1))
    for i, (ty0, ty1, z1) in enumerate(((1.12, 1.50, 0.14), (0.98, 1.30, 0.28), (0.86, 1.10, 0.42))):
        k.box(-0.32, 0.32, ty0, ty1, 0.0, z1, pierre_c, "marche_%d" % i, bevel=0.006)
    # 4 bornes de bronze aux angles, posées au sol (braseros éteints)
    for i, (x, ty) in enumerate(((-1.05, 1.05), (1.05, 1.05), (-1.5, -0.2), (1.5, -0.2))):
        k.cyl(x, ty, 0.09, 0.0, 0.46, bronze, "borne_%d" % i, verts=16)
        k.cyl(x, ty, 0.12, 0.46, 0.52, bronze_p, "borne_coupe_%d" % i, verts=16)

    # --- sanctuaire (porte au sud), toit pyramidal ---
    t0, t1 = 0.25, 0.86
    k.box(-0.6, 0.6, t0, t1, 0.5, 1.12, pierre, "sanctuaire", bevel=0.01)
    for i, z in enumerate((0.66, 0.82, 0.98)):
        k.box(-0.6, 0.6, t1, t1 + 0.006, z, z + 0.012, joint, "sanctuaire_assise_%d" % i, bevel=0)
    k.prism([(-0.68, t0 - 0.07), (0.68, t0 - 0.07), (0.68, t1 + 0.07), (-0.68, t1 + 0.07)], 1.12, 1.46, bronze,
            "sanctuaire_toit", top_poly_game=[(-0.05, 0.53), (0.05, 0.53), (0.05, 0.58), (-0.05, 0.58)], bevel=0.008)
    k.stud_row(-0.62, 0.62, t1 + 0.07, 1.14, 10, 0.014, bronze_p, "sanctuaire_toit_rivets")
    _panel_xz(k, [(x, z + 0.5) for x, z in _ogive(0.21, 0.28, 0.5)], t1, t1 + 0.02, bronze, "porte_cadre")
    _panel_xz(k, [(x, z + 0.52) for x, z in _ogive(0.16, 0.25, 0.44)], t1 + 0.015, t1 + 0.035, pierre, "porte_vantail")
    _crystal(k, 0.0, t1 + 0.03, 1.04, 0.1, 0.075, 0.0, 0.0, cristal, lueur, "porte_cristal", tip=1.4, south=0.5)

    # --- grand cristal central (point le plus haut) : seules ses faces AVANT et sa pointe luisent ---
    cx, cty = 0.05, -0.55
    _crystal(k, cx, cty, 0.45, 3.35, 0.46, math.radians(6), math.radians(20), cristal, lueur, "grand_cristal", tip=1.55,
             rot=0.25, south=-0.90)
    k.torus(cx, cty, 0.82, 0.52, 0.06, bronze, "sertissure_basse", minor_seg=12)
    k.torus(cx + 0.03, cty, 1.55, 0.5, 0.045, bronze, "sertissure_haute", minor_seg=12)
    for z in (0.82, 1.55):
        k.ring_studs(cx, cty, 0.55, z, 9, 0.016, bronze_p, "sertissure_rivets_%d" % int(z * 100))
    # armature de bronze : 4 griffes courbes du socle à la sertissure haute (tiges)
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        a = k.P(cx + sx * 0.82, cty + sy * 0.55, 0.5)
        b = k.P(cx + sx * 0.36, cty + sy * 0.26, 1.55)
        c = (a[0] * 0.55 + b[0] * 0.45 + sx * 0.25, a[1] * 0.55 + b[1] * 0.45 - sy * 0.25, 1.35)
        pts = []
        for j in range(9):
            t = j / 8
            pts.append(tuple((1 - t) ** 2 * a[q] + 2 * (1 - t) * t * c[q] + t * t * b[q] for q in range(3)))
        segs = [k.rod(pts[j], pts[j + 1], 0.04, bronze, "griffe_%d_%d" % (i, j), verts=8, role="tige") for j in range(8)]
        k.join(segs, "griffe_%d" % i)

    # --- 4 éclats satellites, inclinés vers l'extérieur, et petites grappes (pointes seules lumineuses) ---
    shards = [(-1.16, -1.05, 1.95, 0.22, 140), (1.20, -0.95, 1.6, 0.2, 40), (-1.12, 0.5, 1.25, 0.18, 215),
              (1.10, 0.55, 1.05, 0.17, 320)]
    for i, (x, ty, h, r, az) in enumerate(shards):
        # amas de roche au pied de l'éclat (il jaillit du sol, hors du socle)
        k.ngon(x, ty, 0.28, 7, 0.0, 0.2, pierre, "eclat_roche_%d" % i, r_top=0.17, rot=0.3 * i, bevel=0.01)
        _crystal(k, x, ty, 0.12, h + 0.18, r, math.radians(17), math.radians(az), cristal, lueur, "eclat_%d" % i, tip=1.5,
                 rot=0.4 * i, south=-0.97)
        for j in range(2):
            ang = math.radians(az + 70 * (j * 2 - 1))
            dx, dy = 0.22 * math.cos(ang), 0.22 * math.sin(ang) / R2
            _crystal(k, x + dx, ty - dy, 0.1, h * (0.32 + 0.1 * j) + 0.15, r * 0.45, math.radians(28),
                     ang, cristal, lueur, "grappe_%d_%d" % (i, j), tip=1.4, rot=0.7 * j, south=-2.0)


# ----------------------------------------------------------------------------------------------------------
# Époque 8 · Serre-laboratoire : grand BALLON de verre bombé (corps) sur une cuve ronde, empli de liquide
# luminescent jusqu'à la panse (lueur de jour), verre translucide au-dessus avec montants de serre en cuivre ;
# 2 ballons plus petits (3 dômes de tailles décroissantes) ; vestibule d'entrée au sud ; conduits ; bulles
# animées par script en phase 2.
# ----------------------------------------------------------------------------------------------------------
def _flask(k, tx, ty, r_base, z_base, liquid, glass, neck_top, mats, name, coil=True, mers=8):
    """Ballon : cuve (z 0 -> z_base), liquide lumineux (profil `liquid`, visible directement : le verre y est
    plaqué), plateau de cuivre au niveau du liquide, verre translucide (profil `glass`) jusqu'au col, montants
    de serre (méridiens) et serpentin intérieur."""
    drum, verre, liq, cuivre, laiton = mats
    k.cyl(tx, ty, r_base, 0.0, z_base, drum, name + "_cuve", verts=48)
    k.ribs(tx, ty, r_base, 0.04, z_base - 0.04, max(6, int(r_base * 10)), cuivre, name + "_cuve_nervures", w=0.03, d=0.016)
    k.ring_studs(tx, ty, r_base, z_base - 0.06, max(8, int(r_base * 14)), 0.014, laiton, name + "_cuve_rivets")
    k.lathe(tx, ty, liquid, liq, name + "_liquide", segs=48)
    zl, rl = liquid[-1][1], liquid[-1][0]
    k.cyl(tx, ty, rl - 0.01, zl, zl + 0.03, cuivre, name + "_plateau", verts=48, bevel=0)
    k.torus(tx, ty, zl + 0.01, rl + 0.006, 0.03, cuivre, name + "_bague", minor_seg=10)
    k.torus(tx, ty, liquid[0][1] + 0.02, liquid[0][0] + 0.006, 0.026, cuivre, name + "_bague_basse", minor_seg=10)
    k.lathe(tx, ty, glass, verre, name + "_verre", segs=48)
    if coil:
        zt = glass[-1][1]
        turns = [k.torus(tx, ty, zl + 0.15 + i * 0.16, max(0.12, rl * 0.42 - i * 0.03), 0.022, cuivre,
                         "%s_serpentin_%d" % (name, i), minor_seg=8) for i in range(int((zt - zl - 0.4) / 0.16))]
        k.join(turns, name + "_serpentin")
        k.cyl(tx, ty, 0.04, zl, zt, laiton, name + "_axe", verts=10, bevel=0)
    # montants de serre : méridiens de cuivre plaqués sur le verre (demi-face sud et côtés)
    cx, cy, _ = k.P(tx, ty, 0)
    prof = [(r + 0.012, z) for r, z in glass]
    rods = []
    for j in range(mers):
        a = math.pi * (j + 0.5) / mers + math.pi
        for (r0, z0), (r1, z1) in zip(prof[:-1], prof[1:]):
            rods.append(k.rod((cx + r0 * math.cos(a), cy + r0 * math.sin(a), z0), (cx + r1 * math.cos(a), cy + r1 * math.sin(a), z1),
                              0.016, cuivre, "%s_montant_%d" % (name, j), verts=6))
    k.join(rods, name + "_montants")
    for i in range(1, len(glass) - 1):
        r, z = glass[i]
        k.torus(tx, ty, z, r + 0.01, 0.014, cuivre, "%s_traverse_%d" % (name, i), minor_seg=6)
        if i < len(glass) - 2:
            r2, z2 = glass[i + 1]
            k.torus(tx, ty, (z + z2) / 2, (r + r2) / 2 + 0.012, 0.009, cuivre, "%s_traverse_m%d" % (name, i), minor_seg=6)
    rn, zn = glass[-1]
    k.cyl(tx, ty, rn + 0.04, zn, neck_top, cuivre, name + "_col", verts=24)
    k.bands(tx, ty, rn + 0.04, (zn + 0.06, neck_top - 0.06), laiton, name + "_col_bagues", minor=0.016)


def build_e08(k):
    vdg = k.metal("vert_de_gris", "#4F6B5A", rough=0.4, metallic=0.55, dirt=0.55)
    vdg_s = k.metal("vert_de_gris_sombre", "#3C5246", rough=0.45, metallic=0.5, dirt=0.55)
    cuivre = k.metal("cuivre", "#8A6A48", rough=0.3, metallic=0.85, rust="#4F6B5A", rust_amount=0.35, dirt=0.45)
    laiton = k.metal("laiton", "#A08650", rough=0.22, metallic=0.95, clean=True)
    caout = k.matte("caoutchouc", "#2A2A28", rough=0.65, grain=0.26)
    verre = k.clear_glass("verre", "#8FBF4A", transp=0.40)
    liq = k.emit("liquide", "#A8FF3A", strength=1.0)
    mats = (vdg, verre, liq, cuivre, laiton)

    # --- grand ballon (corps) ---
    bx, bty = -0.05, -0.55
    _flask(k, bx, bty, 1.12, 0.40,
           [(1.12, 0.40), (1.24, 0.75), (1.28, 1.10), (1.24, 1.42)],
           [(1.24, 1.42), (1.16, 1.85), (0.98, 2.35), (0.72, 2.8), (0.46, 3.2), (0.32, 3.5)],
           4.45, mats, "grand_ballon", mers=15)
    k.lathe(bx, bty, [(0.40, 4.45), (0.38, 4.55), (0.26, 4.65), (0.0, 4.70)], cuivre, "grand_ballon_chapeau", segs=24)
    # --- ballon moyen (est) et petit ballon (ouest, devant) ---
    _flask(k, 1.33, -0.25, 0.46, 0.30,
           [(0.46, 0.30), (0.50, 0.50), (0.48, 0.70)],
           [(0.48, 0.70), (0.44, 0.92), (0.32, 1.12), (0.16, 1.28)],
           1.55, mats, "ballon_moyen", coil=False, mers=5)
    _flask(k, -1.40, 0.62, 0.36, 0.26,
           [(0.36, 0.26), (0.40, 0.42), (0.38, 0.58)],
           [(0.38, 0.58), (0.34, 0.76), (0.24, 0.92), (0.12, 1.02)],
           1.22, mats, "petit_ballon", coil=False, mers=5)

    # --- vestibule d'entrée (porte au sud), relié au grand ballon ---
    v0, v1 = 0.25, 1.30
    k.box(-0.46, 0.46, v0, v1, 0.0, 0.66, vdg_s, "vestibule", bevel=0.015)
    k.panels(-0.46, 0.46, v0, v1, 0.0, 0.66, vdg, "vestibule_plaques", top=(2, 3), south=(4, 2), gap=0.03,
             skip=lambda f, xa, xb, a, b: f == "south" and xb > -0.3 and xa < 0.3)
    k.prism([(-0.52, v0 - 0.02), (0.52, v0 - 0.02), (0.52, v1 + 0.06), (-0.52, v1 + 0.06)], 0.66, 0.74, cuivre,
            "vestibule_corniche", top_poly_game=[(-0.48, v0), (0.48, v0), (0.48, v1 + 0.02), (-0.48, v1 + 0.02)], bevel=0.006)
    k.door(-0.26, 0.26, v1, 0.54, cuivre, vdg_s, name="porte")
    k.box(-0.20, 0.20, v1 + 0.04, v1 + 0.07, 0.57, 0.64, liq, "porte_imposte", bevel=0)
    for s in (-1, 1):
        k.hcyl("y", v1 - 0.01, v1 + 0.03, s * 0.36, 0, 0.42, 0.07, laiton, "hublot_cadre_%d" % s, verts=20, bevel=0)
        k.hcyl("y", v1 + 0.01, v1 + 0.045, s * 0.36, 0, 0.42, 0.05, liq, "hublot_%d" % s, verts=20, bevel=0)

    # --- conduits (cuivre) et tuyau souple ---
    pipes = []
    a, b = k.P(bx + 0.30, bty, 3.4), k.P(1.33, -0.25, 1.40)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 3.2)
    pts = [tuple((1 - t) ** 2 * a[q] + 2 * (1 - t) * t * mid[q] + t * t * b[q] for q in range(3)) for t in [j / 8 for j in range(9)]]
    pipes += [k.rod(pts[j], pts[j + 1], 0.055, cuivre, "conduit_ballons_%d" % j, verts=12) for j in range(8)]
    pipes.append(k.hcyl("x", -1.25, -0.9, 0, 0.2, 0.25, 0.05, vdg_s, "conduit_bas", verts=12, bevel=0))
    k.join(pipes, "conduits")
    hose = []
    a, b = k.P(-1.40 + 0.2, 0.62, 0.9), k.P(bx - 0.9, bty + 0.6, 1.3)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 0.75)
    pts = [tuple((1 - t) ** 2 * a[q] + 2 * (1 - t) * t * mid[q] + t * t * b[q] for q in range(3)) for t in [j / 6 for j in range(7)]]
    hose += [k.rod(pts[j], pts[j + 1], 0.04, caout, "tuyau_souple_%d" % j, verts=10) for j in range(6)]
    k.join(hose, "tuyau_souple")

    # --- antenne de cuivre au sommet du grand ballon (tige, point le plus haut) ---
    k.mast(bx, bty, 4.68, 5.35, 0.02, cuivre, "antenne")
    k.sphere(bx, bty, 5.38, 0.06, liq, "antenne_bulbe", seg=16, rings=8, role="tige")


# ----------------------------------------------------------------------------------------------------------
# Époque 9 · Bunker atomique : corps octogonal chanfreiné ; 2 tours de refroidissement ; dôme de confinement ;
# hublots vert uranium (lueur de jour) ; trèfle ; balise de radiation au sommet (tige).
# ----------------------------------------------------------------------------------------------------------
def build_e09(k):
    plomb = k.metal("plomb", "#4A5058", rough=0.42, metallic=0.65, dirt=0.6)
    beton = k.matte("beton", "#7A7670", rough=0.85, grain=0.3, grain_scale=35.0, dirt=0.6, gain=1.15)
    jaune = k.metal("jaune", "#C9A227", rough=0.45, metallic=0.25, dirt=0.5, gain=1.05)
    noir = k.metal("noir", "#1E1E1E", rough=0.55, metallic=0.3)
    boulon = k.metal("boulon", "#9AA0A8", rough=0.22, metallic=0.95, clean=True)
    sombre = k.matte("gueule", "#141414", rough=0.9, grain=0.1)
    vert = k.emit("vert", "#5CFF4A", strength=1.0)

    # Correction V3 du 22/10 : octogone RÉDUIT (rayon 1,68 -> 1,42), tours aux angles arrière : le corps ne se
    # confond plus avec les blocs des ères I et II (IoU des corps 0,86 avec E2, 0,85 avec E5)
    oct_rot, sy, RO = math.pi / 8, 1.31, 1.42
    k.ngon(0.0, 0.05, RO + 0.02, 8, 0.0, 0.1, jaune, "bande_pied", rot=oct_rot, sy=sy, bevel=0.004)
    # chevrons noirs sur la bande de pied (avertissement)
    cx0, cy0, _ = k.P(0.0, 0.05, 0)
    chev = []
    for i in range(18):
        a = math.pi + math.pi * (i + 0.5) / 18
        x, y = (RO + 0.04) * math.cos(a), sy * (RO + 0.04) * math.sin(a) * 0.93
        chev.append(k.rod((cx0 + x - 0.04, cy0 + y, 0.01), (cx0 + x + 0.04, cy0 + y, 0.09), 0.016, noir, "chevron_%d" % i, verts=6))
    k.join(chev, "chevrons")
    k.ngon(0.0, 0.05, RO, 8, 0.1, 0.85, plomb, "corps", rot=oct_rot, sy=sy, bevel=0.012)
    k.ngon(0.0, 0.05, RO, 8, 0.85, 1.12, plomb, "chanfrein", r_top=RO - 0.26, rot=oct_rot, sy=sy, bevel=0.012)
    # plaques boulonnées : joints verticaux et rangées de boulons sur les pans visibles du corps
    pts = []
    for i in range(40):
        a = math.pi + math.pi * (i + 0.5) / 40
        x, y = (RO + 0.01) * math.cos(a) * 0.95, sy * (RO + 0.01) * math.sin(a) * 0.95
        for z in (0.2, 0.75):
            pts.append(((cx0 + x, cy0 + y, z), (math.cos(a), math.sin(a), 0.0)))
    k.studs(pts, 0.018, boulon, "corps_boulons")
    k.ngon(0.0, 0.05, RO + 0.02, 8, 0.46, 0.50, noir, "corps_joint", rot=oct_rot, sy=sy, bevel=0)
    k.ngon(0.0, 0.05, RO + 0.02, 8, 0.83, 0.87, jaune, "corps_liseré", rot=oct_rot, sy=sy, bevel=0)

    # --- 2 tours de refroidissement hyperboloïdes (arrière), écartées ---
    for s, x, ty, ztop in ((-1, -1.20, -1.12, 3.95), (1, 1.20, -1.02, 3.5)):
        prof = [(0.62, 0.0), (0.54, 0.8), (0.46, 1.8), (0.42, ztop * 0.72), (0.45, ztop * 0.9), (0.5, ztop)]
        k.lathe(x, ty, prof, beton, "tour_refroid_%d" % s, segs=48)
        k.cyl(x, ty, 0.47, ztop - 0.08, ztop - 0.06, sombre, "tour_gueule_%d" % s, verts=40, bevel=0)
        k.torus(x, ty, ztop, 0.5, 0.025, plomb, "tour_levre_%d" % s, minor_seg=10)
        k.torus(x, ty, 0.5, 0.585, 0.03, jaune, "tour_bande_%d" % s, minor_seg=10)
        # cerclages de coffrage (anneaux fins) et pieds en V à la base
        for j, z in enumerate((0.75, 1.05, 1.35, 1.65, 1.95, 2.25, 2.55, 2.85, 3.15)):
            if z < ztop - 0.3:
                t = z / ztop
                rr = 0.62 + (0.42 - 0.62) * min(1.0, t / 0.72) if t < 0.72 else 0.42 + (0.5 - 0.42) * (t - 0.72) / 0.28
                k.torus(x, ty, z, rr + 0.004, 0.012, plomb, "tour_cercle_%d_%d" % (s, j), minor_seg=6)
        k.ring_studs(x, ty, 0.62, 0.12, 9, 0.03, beton, "tour_pieds_%d" % s)
        # échelle à crinoline sur la face sud de la tour (tige)
        rungs = []
        for j in range(16):
            z = 0.3 + j * (ztop - 0.6) / 16
            rz = next(r0 + (r1 - r0) * (z - z0) / (z1 - z0) for (r0, z0), (r1, z1) in zip(prof[:-1], prof[1:]) if z0 <= z <= z1)
            tyl = ty + (rz + 0.03) / R2
            rungs.append(k.box(x - 0.08, x + 0.08, tyl, tyl + 0.012, z, z + 0.012, plomb, "echelon_%d_%d" % (s, j), bevel=0,
                               role="tige"))
        k.join(rungs, "echelle_%d" % s)

    # --- dôme de confinement ---
    dty = -0.05
    k.cyl(0.0, dty, 0.95, 1.1, 1.4, beton, "dome_tambour", verts=64)
    k.cyl(0.0, dty, 0.958, 1.2, 1.3, vert, "dome_bande_verte", verts=64, bevel=0, caps=False)
    prof = [(0.92, 1.4)] + [(0.92 * math.cos(a), 1.4 + 0.92 * math.sin(a)) for a in [math.radians(d) for d in range(10, 91, 10)]]
    prof[-1] = (0.0, 2.32)
    k.lathe(0.0, dty, prof, plomb, "dome", segs=64)
    k.sphere_seams(0.0, dty, 1.4, 0.925, noir, "dome_coutures", lats=(0.35, 0.8), mers=6, minor=0.011)
    k.torus(0.0, dty, 1.42, 0.93, 0.035, jaune, "dome_bague", minor_seg=10)
    k.ring_studs(0.0, dty, 0.95, 1.15, 14, 0.016, boulon, "dome_tambour_boulons")
    # évents annelés sur le chanfrein
    for i, x in enumerate((-0.85, 0.85)):
        k.cyl(x, 0.55, 0.12, 0.9, 1.25, plomb, "event_%d" % i, verts=20)
        k.bands(x, 0.55, 0.12, (0.98, 1.06, 1.14), noir, "event_anneaux_%d" % i, minor=0.014)
        k.cyl(x, 0.55, 0.15, 1.25, 1.3, plomb, "event_chapeau_%d" % i, verts=20)

    # --- façade sud : porte blindée, hublots verts, trèfle ---
    ty_f = 0.05 + RO * math.cos(math.pi / 8) * sy / R2
    k.box(-0.36, 0.36, ty_f - 0.03, ty_f + 0.05, 0.1, 0.68, jaune, "porte_cadre", bevel=0.006)
    k.box(-0.27, 0.27, ty_f, ty_f + 0.07, 0.12, 0.62, plomb, "porte_vantail", bevel=0.006)
    for i, z in enumerate((0.25, 0.45)):
        k.box(-0.27, 0.27, ty_f + 0.07, ty_f + 0.08, z - 0.02, z + 0.02, noir, "porte_chevron_%d" % i, bevel=0)
    k.stud_row(-0.24, 0.24, ty_f + 0.08, 0.56, 6, 0.014, boulon, "porte_boulons")
    for s in (-1, 1):
        k.hcyl("y", ty_f - 0.01, ty_f + 0.03, s * 0.55, 0, 0.45, 0.16, plomb, "hublot_cadre_%d" % s, verts=32, bevel=0.006)
        k.hcyl("y", ty_f + 0.01, ty_f + 0.045, s * 0.55, 0, 0.45, 0.12, vert, "hublot_%d" % s, verts=32, bevel=0)
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
