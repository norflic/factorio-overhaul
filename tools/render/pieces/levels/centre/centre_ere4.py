"""Ère IV haute technologie (époques 10 à 12) : lisse, élancé, sur pieds, premières pièces flottantes ; les vides
apparaissent (V ≥ 4 à 12 % du masque du niveau 1 ; bible §1.2, §4, §5 ; Q8 : ajourer = changer la forme)."""
import math

R2 = 2.0 ** 0.5


def _h(i, a=0.0):
    return math.sin(i * 12.9898 + a * 78.233) * 0.5 + math.sin(i * 4.1414 + a * 1.618) * 0.5


def _dish(k, tx, ty, z, R, depth, tilt, azim, mat, name, role="mass"):
    """Parabole (coque mince) d'axe incliné de `tilt` vers la direction `azim` (Blender), pied en (tx, ty, z)."""
    prof = [(0.0, 0.0)] + [(R * t, depth * t * t) for t in (0.25, 0.5, 0.75, 1.0)]
    o = k.lathe(0.0, 0.0, prof, mat, name, segs=40, role=role)
    if o is None:
        return None
    m = o.modifiers.new("epais", "SOLIDIFY")
    m.thickness = 0.025
    from mathutils import Matrix, Vector
    axis = Vector((-math.sin(azim), math.cos(azim), 0.0))
    o.rotation_euler = Matrix.Rotation(tilt, 4, axis).to_euler()
    o.location = k.P(tx, ty, z)
    return o


# ----------------------------------------------------------------------------------------------------------
# Époque 10 · QG radar : coque lisse arrondie sur pieds courts ; grand radôme ; antenne fouet très haute
# (tige) ; parabole (tournante par script en phase 2) ; voyants bleus.
# ----------------------------------------------------------------------------------------------------------
def build_e10(k):
    caren = k.metal("carenage", "#A8ADB3", rough=0.32, metallic=0.35, grain=0.06, dirt=0.4)
    noir = k.metal("noir_mat", "#222428", rough=0.65, metallic=0.2, grain=0.06, dirt=0.25)
    radome = k.matte("radome", "#C4C6C8", rough=0.45, grain=0.05, dirt=0.35, gain=1.1)
    acier = k.metal("acier", "#6E737A", rough=0.35, metallic=0.8, grain=0.08, dirt=0.4)
    bleu = k.emit("bleu", "#3AA8FF", strength=0.8)
    ecran = k.emit("ecran", "#3AA8FF", strength=0.45)

    # --- pieds courts (vide sous la coque) ---
    for sx in (-1, 1):
        for ty in (0.72, -0.82):
            k.cyl(sx * 1.18, ty, 0.2, 0.0, 0.05, noir, "patin_%d_%d" % (sx, int(ty * 10)), verts=24)
            k.cyl(sx * 1.18, ty, 0.1, 0.05, 0.42, acier, "pied_%d_%d" % (sx, int(ty * 10)), verts=20)
    # --- coque lisse arrondie ---
    hull = k.box(-1.55, 1.55, -1.2, 1.05, 0.38, 1.25, caren, "coque", bevel=0)
    if hull is not None:
        k.S.bevel(hull, 0.2, segments=5)
    band = k.box(-1.565, 1.565, -1.1, 1.065, 0.80, 0.98, noir, "bandeau_noir", bevel=0)
    if band is not None:
        k.S.bevel(band, 0.08, segments=3)
    for i, x in enumerate((-1.25, -0.95, -0.65, 0.65, 0.95, 1.25)):
        k.box(x - 0.08, x + 0.08, 1.06, 1.08, 0.81, 0.97, bleu if i % 2 == 0 else ecran, "voyant_%d" % i, bevel=0)
    # porte et rampe d'accès
    k.box(-0.36, 0.36, 1.0, 1.09, 0.38, 0.98, noir, "porte_cadre", bevel=0.01)
    k.box(-0.27, 0.27, 1.05, 1.1, 0.42, 0.94, acier, "porte", bevel=0.006)
    k.box(-0.3, 0.3, 1.09, 1.11, 0.95, 0.975, bleu, "porte_feu", bevel=0)
    for i, (ty0, z1) in enumerate(((1.05, 0.33), (1.22, 0.22), (1.38, 0.11))):
        k.box(-0.32, 0.32, ty0, ty0 + 0.17, 0.0, z1, noir, "marche_%d" % i, bevel=0.006)
    k.box(0.7, 1.35, 1.0, 1.06, 0.45, 0.72, ecran, "ecran_facade", bevel=0)

    # --- tour et grand radôme ---
    rx, rty = 0.45, -0.65
    k.cyl(rx, rty, 0.32, 1.2, 3.1, noir, "tour_radome", verts=40)
    k.cyl(rx, rty, 0.42, 1.2, 1.4, acier, "tour_pied", verts=40)
    k.cyl(rx, rty, 0.40, 2.95, 3.12, acier, "tour_collier", verts=40)
    k.sphere(rx, rty, 3.97, 1.0, radome, "radome", seg=64, rings=32)
    k.torus(rx, rty, 3.97, 1.003, 0.012, acier, "radome_couture_eq", minor_seg=8)
    for a in (0.45, -0.45):
        k.torus(rx, rty, 3.97, 1.003, 0.01, acier, "radome_couture_%d" % int(a * 100), rot=(0, a, 0.6), minor_seg=8)
    k.sphere(rx, rty, 3.97 - 0.9, 0.06, bleu, "radome_feu", seg=16, rings=8)

    # --- parabole (pose de référence) ---
    k.cyl(-0.95, -0.4, 0.12, 1.2, 1.7, acier, "parabole_pied", verts=20)
    _dish(k, -0.95, -0.4, 1.68, 0.6, 0.22, math.radians(40), math.radians(-60), caren, "parabole")
    k.rod(k.P(-0.95, -0.4, 1.7), k.P(-0.95 + 0.18, -0.4 + 0.22, 2.12), 0.018, acier, "parabole_source", role="tige")

    # --- antenne fouet (tige, point le plus haut) ---
    k.cyl(-1.3, -0.95, 0.06, 1.2, 1.45, acier, "fouet_embase", verts=16)
    k.cyl(-1.3, -0.95, 0.018, 1.45, 6.75, acier, "fouet", verts=8, bevel=0, r2=0.008, role="tige")
    k.sphere(-1.3, -0.95, 6.77, 0.045, bleu, "fouet_feu", seg=12, rings=6, role="tige")


# ----------------------------------------------------------------------------------------------------------
# Époque 11 · Tour blanche : tour effilée ; 4 ailerons triangulaires ; posée sur 4 pieds en V (vides au sol) ;
# flèche ; lignes lumineuses bleu-blanc (chenillard par script en phase 2).
# ----------------------------------------------------------------------------------------------------------
def build_e11(k):
    blanc = k.metal("alliage_blanc", "#C9C6BE", rough=0.35, metallic=0.3, grain=0.07, dirt=0.5)
    titane = k.metal("titane", "#8E9AA6", rough=0.3, metallic=0.85, grain=0.08, dirt=0.4)
    sombre = k.metal("sombre", "#30343A", rough=0.5, metallic=0.5, dirt=0.3)
    ligne = k.emit("ligne", "#BFE6FF", strength=0.6)

    cty = -0.35
    # --- plate-forme octogonale sur 4 pieds en V ---
    k.ngon(0.0, -0.2, 1.08, 8, 0.82, 1.12, titane, "plate_forme", rot=math.pi / 8, sy=1.2, bevel=0.012)
    k.ngon(0.0, -0.2, 1.12, 8, 1.08, 1.14, ligne, "plate_forme_liseré", rot=math.pi / 8, sy=1.2, bevel=0)
    feet = [(-1.55, 1.38), (1.55, 1.38), (-1.5, -1.55), (1.5, -1.55)]
    tops = [((-0.55, 0.42), (-0.95, -0.05)), ((0.55, 0.42), (0.95, -0.05)),
            ((-0.95, -0.4), (-0.5, -0.85)), ((0.95, -0.4), (0.5, -0.85))]
    for i, ((fx, fty), pair) in enumerate(zip(feet, tops)):
        k.cyl(fx, fty, 0.16, 0.0, 0.06, sombre, "patin_%d" % i, verts=20)
        for j, (px, pty) in enumerate(pair):
            k.rod(k.P(fx, fty, 0.05), k.P(px, pty, 0.86), 0.075, blanc, "pied_%d_%d" % (i, j), verts=12)
    # rampe d'accès au sud
    a0, a1 = 1.65, 0.62
    k.loft([[k.P(-0.24, a0, 0.0), k.P(0.24, a0, 0.0), k.P(0.24, a1, 0.0), k.P(-0.24, a1, 0.0)],
            [k.P(-0.24, a0, 0.04), k.P(0.24, a0, 0.04), k.P(0.24, a1, 0.86), k.P(-0.24, a1, 0.86)]], titane, "rampe")

    # --- tour effilée ---
    k.ngon(0.0, cty, 0.72, 8, 1.12, 5.85, blanc, "tour", r_top=0.27, rot=math.pi / 8, bevel=0.01)
    for i, z in enumerate((1.9, 2.9, 3.9, 4.9)):
        t = (z - 1.12) / (5.85 - 1.12)
        r = 0.72 + (0.27 - 0.72) * t
        k.ngon(0.0, cty, r + 0.02, 8, z, z + 0.08, titane, "tour_bague_%d" % i, rot=math.pi / 8, bevel=0.004)
    # porte au pied de la tour (face sud)
    k.box(-0.2, 0.2, 0.12, 0.2, 1.12, 1.66, sombre, "porte", bevel=0.006)
    k.box(-0.24, 0.24, 0.14, 0.18, 1.66, 1.72, ligne, "porte_feu", bevel=0)
    # lignes lumineuses verticales sur la face sud de la tour
    for s in (-1, 1):
        a = k.P(s * 0.2, cty + 0.66, 1.75)
        b = k.P(s * 0.08, cty + 0.25, 5.6)
        k.rod(a, b, 0.03, ligne, "tour_ligne_%d" % s, verts=8, role="tige")

    # --- 4 ailerons triangulaires (plans verticaux, en X autour de la tour) ---
    for i, az in enumerate((35, 145, 215, 325)):
        a = math.radians(az)
        d = (math.cos(a), math.sin(a))
        nrm = (-d[1] * 0.035, d[0] * 0.035)
        cx, cy, _ = k.P(0.0, cty, 0)
        p_in0 = (cx + 0.62 * d[0], cy + 0.62 * d[1], 1.12)
        p_out = (cx + 1.78 * d[0], cy + 1.78 * d[1], 1.12)
        p_top = (cx + 0.42 * d[0], cy + 0.42 * d[1], 3.95)
        ring0 = [(p[0] - nrm[0], p[1] - nrm[1], p[2]) for p in (p_in0, p_out, p_top)]
        ring1 = [(p[0] + nrm[0], p[1] + nrm[1], p[2]) for p in (p_in0, p_out, p_top)]
        k.loft([ring0, ring1], blanc, "aileron_%d" % i, bevel=0.008)
        # bord d'attaque lumineux
        k.rod((p_out[0], p_out[1], p_out[2] + 0.05), (p_top[0] + 0.06 * d[0], p_top[1] + 0.06 * d[1], p_top[2] - 0.05), 0.032,
              ligne, "aileron_ligne_%d" % i, verts=8, role="tige")
        k.rod(p_out, (p_out[0], p_out[1], p_out[2] - 0.32), 0.05, titane, "aileron_jambe_%d" % i, verts=10)

    # --- flèche (tige, point le plus haut) ---
    k.cyl(0.0, cty, 0.06, 5.85, 7.3, titane, "fleche", verts=12, r2=0.008, bevel=0, role="tige")
    k.sphere(0.0, cty, 6.2, 0.07, ligne, "fleche_feu", seg=16, rings=8, role="tige")


# ----------------------------------------------------------------------------------------------------------
# Époque 12 · Nexus : noyau noir vertical ; 3 anneaux chromés horizontaux en lévitation, espacés (vides) ;
# 4 pylônes ; givre ; anneaux cyan (rotation par script en phase 2).
# ----------------------------------------------------------------------------------------------------------
def build_e12(k):
    # gain propre : à 1,6 le noir donnait une L50 de 40 pour une cible de 60 (aperçu du 21/10)
    noir = k.metal("noir_profond", "#26282E", rough=0.3, metallic=0.6, grain=0.06, dirt=0.3, gain=3.0)
    chrome = k.metal("chrome", "#9AA3AD", rough=0.12, metallic=1.0, grain=0.04, dirt=0.25)
    givre = k.matte("givre", "#DDEEFF", rough=0.6, grain=0.25, grain_scale=80.0, dirt=0.2, gain=0.95)
    cyan = k.emit("cyan", "#4AF0FF", strength=0.6)

    cty = -0.3
    # --- dalle au sol (couche plate) ---
    k.ngon(0.0, 0.0, 1.78, 8, 0.0, 0.1, noir, "dalle", rot=math.pi / 8, sy=1.31, bevel=0.006, role="flat")
    k.ngon(0.0, 0.0, 1.8, 8, 0.0, 0.03, chrome, "dalle_bord", rot=math.pi / 8, sy=1.31, bevel=0, role="flat")
    # --- noyau noir vertical (hexagonal) ---
    k.ngon(0.0, cty, 0.48, 6, 0.1, 6.05, noir, "noyau", rot=math.pi / 6, bevel=0.01)
    k.ngon(0.0, cty, 0.48, 6, 6.05, 6.45, chrome, "noyau_pointe", r_top=0.0, rot=math.pi / 6, bevel=0.006)
    k.ngon(0.0, cty, 0.55, 6, 0.1, 0.42, givre, "noyau_givre", r_top=0.5, rot=math.pi / 6, bevel=0.01)
    cx, cy, _ = k.P(0.0, cty, 0)
    for i in range(6):
        a = math.pi / 6 + 2 * math.pi * i / 6
        px, py = cx + 0.485 * math.cos(a), cy + 0.485 * math.sin(a)
        k.rod((px, py, 0.42), (px, py, 6.0), 0.022, chrome, "noyau_arete_%d" % i, verts=8, role="tige")
    for i, z in enumerate((1.0, 2.25, 3.55, 4.85)):
        k.ngon(0.0, cty, 0.49, 6, z, z + 0.06, cyan, "noyau_joint_%d" % i, rot=math.pi / 6, bevel=0)

    # --- 3 anneaux chromés en lévitation (aucun support : vides) ---
    for i, (R, z) in enumerate(((1.45, 1.55), (1.2, 2.9), (0.95, 4.2))):
        k.torus(0.0, cty, z, R, 0.11, chrome, "anneau_%d" % i, minor_seg=18)
        k.torus(0.0, cty, z, R - 0.1, 0.045, cyan, "anneau_lueur_%d" % i, minor_seg=10)

    # --- entrée (porte au sud) ---
    k.box(-0.42, 0.42, -0.05, 0.72, 0.1, 0.66, noir, "entree", bevel=0.012)
    k.box(-0.24, 0.24, 0.7, 0.75, 0.1, 0.56, chrome, "porte", bevel=0.006)
    k.box(-0.3, 0.3, 0.71, 0.76, 0.58, 0.63, cyan, "porte_feu", bevel=0)
    for s in (-1, 1):
        k.box(s * 0.3 - 0.03, s * 0.3 + 0.03, 0.71, 0.76, 0.1, 0.58, cyan, "porte_montant_%d" % s, bevel=0)

    # --- 4 pylônes aux coins (pointes cyan) ---
    for sx in (-1, 1):
        for ty, h in ((1.3, 1.25), (-1.38, 1.7)):
            x = sx * 1.42
            k.box(x - 0.13, x + 0.13, ty - 0.13, ty + 0.13, 0.1, h, noir, "pylone_%d_%d" % (sx, int(ty * 10)), bevel=0.012)
            k.box(x - 0.15, x + 0.15, ty - 0.15, ty + 0.15, 0.1, 0.3, givre, "pylone_givre_%d_%d" % (sx, int(ty * 10)), bevel=0.012)
            k.box(x - 0.15, x + 0.15, ty - 0.15, ty + 0.15, h, h + 0.06, chrome, "pylone_chapeau_%d_%d" % (sx, int(ty * 10)),
                  bevel=0.006)
            k.ngon(x, ty, 0.09, 4, h + 0.06, h + 0.3, cyan, "pylone_pointe_%d_%d" % (sx, int(ty * 10)), r_top=0.0,
                   rot=math.pi / 4, bevel=0)

    # --- antenne de pointe (tige, point le plus haut) ---
    k.cyl(0.0, cty, 0.03, 6.4, 7.05, chrome, "pointe_antenne", verts=10, r2=0.006, bevel=0, role="tige")
