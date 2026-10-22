"""Ère IV haute technologie (époques 10 à 12) : lisse, élancé, sur pieds, premières pièces flottantes ; les vides
apparaissent (V >= 4 à 12 % du masque du niveau 1 ; bible §1.2, §4, §5 ; Q8 : ajourer = changer la forme).

Correction V3 du 22/10 (vérification adverse) :
  - époque 10 : coque à profil ARRONDI (superellipsoïde, plus une boîte biseautée), radôme plus large et posé
    bas sur un piédestal trapu (plus de « manche à balai »), L porté vers l'enveloppe (3,12 -> 3,73), panneaux,
    trappes, grilles et goujons sur la coque ;
  - époque 11 : tour plus large, nacelle d'observation, ailerons agrandis : le centre domine de nouveau ;
  - époque 12 : noyau plus gros, anneaux plus grands et plus épais, blocs flottants, pylônes plus hauts.
Salissure légère obligatoire sur les matières claires (politique du kit).
"""
import math

R2 = 2.0 ** 0.5


def _h(i, a=0.0):
    return math.sin(i * 12.9898 + a * 78.233) * 0.5 + math.sin(i * 4.1414 + a * 1.618) * 0.5


def _sgnpow(v, e):
    return math.copysign(abs(v) ** e, v)


def _dish(k, tx, ty, z, R, depth, tilt, azim, mat, name, role="mass"):
    """Parabole (coque mince) d'axe incliné de `tilt` vers la direction `azim` (Blender), pied en (tx, ty, z)."""
    prof = [(0.0, 0.0)] + [(R * t, depth * t * t) for t in (0.25, 0.5, 0.75, 1.0)]
    o = k.lathe(0.0, 0.0, prof, mat, name, segs=40, role=role)
    if o is None:
        return None
    m = o.modifiers.new("epais", "SOLIDIFY")
    m.thickness = 0.025
    from mathutils import Matrix
    from mathutils import Vector
    axis = Vector((-math.sin(azim), math.cos(azim), 0.0))
    o.rotation_euler = Matrix.Rotation(tilt, 4, axis).to_euler()
    o.location = k.P(tx, ty, z)
    return o


# Décalage « derrière » à l'écran (le long de la visée de la caméra, 45° depuis le sud) : une pièce ainsi décalée
# garde la même projection mais passe derrière. Sert aux fonds sombres des lueurs fines (passe 6 du 22/10 : le
# bord d'une lueur fine posée sur un corps clair donnait des pixels blancs au composite, époques 11 et 12).
BEHIND = (0.0, 0.7071, -0.7071)


def lit_rod(k, a, b, r, glow, dark, name, back=0.05):
    """Barre lumineuse sur fond sombre : un jonc sombre plus gros, décalé derrière, borde la lueur."""
    k.rod(a, b, r, glow, name, verts=8, role="tige")
    off = tuple(back * c for c in BEHIND)
    k.rod(tuple(p + o for p, o in zip(a, off)), tuple(p + o for p, o in zip(b, off)), r * 1.5, dark, name + "_fond", verts=8,
          role="tige")


def superhull_pt(tx, ty, A, B, z0, z1, theta, phi, p=3.2, q=3.0):
    """Point (Blender) d'une coque superellipsoïde : section |x/A|^p + |y/B|^p = 1 (A en tuiles, B en tuiles de
    jeu vers le sud), profil vertical arrondi d'exposant q ; theta : angle dans le plan, phi : de -pi/2 à pi/2."""
    zc, hz = (z0 + z1) / 2.0, (z1 - z0) / 2.0
    s = _sgnpow(math.cos(phi), 2.0 / q) if abs(math.cos(phi)) > 1e-9 else 0.0
    z = zc + hz * _sgnpow(math.sin(phi), 2.0 / q)
    x = tx + A * s * _sgnpow(math.cos(theta), 2.0 / p)
    y = -ty * R2 + B * R2 * s * _sgnpow(math.sin(theta), 2.0 / p)
    return (x, y, z)


def superhull(k, tx, ty, A, B, z0, z1, mat, name, n=64, rings=16, p=3.2, q=3.0, phi0=-math.pi / 2, phi1=math.pi / 2,
              grow=0.0, role="mass"):
    """Coque arrondie (loft d'anneaux superellipses) entre les latitudes phi0 et phi1 ; grow : rayon ajouté
    (bandeau légèrement en saillie)."""
    rs = []
    for j in range(rings + 1):
        phi = phi0 + (phi1 - phi0) * j / rings
        if abs(abs(phi) - math.pi / 2) < 1e-6:
            rs.append([(tx, -ty * R2, superhull_pt(tx, ty, A, B, z0, z1, 0.0, phi, p, q)[2])])
            continue
        ring = []
        for i in range(n):
            th = 2 * math.pi * i / n
            x, y, z = superhull_pt(tx, ty, A + grow, B + grow / R2, z0, z1, th, phi, p, q)
            ring.append((x, y, z))
        rs.append(ring)
    return k.loft(rs, mat, name, smooth=70, role=role, cap0=(phi0 > -math.pi / 2 + 1e-6),
                  cap1=(phi1 < math.pi / 2 - 1e-6))


# ----------------------------------------------------------------------------------------------------------
# Époque 10 · QG radar : coque lisse ARRONDIE sur pieds courts ; grand radôme posé bas ; antenne fouet très haute
# (tige) ; parabole (tournante par script en phase 2) ; voyants bleus.
# ----------------------------------------------------------------------------------------------------------
def build_e10(k):
    caren = k.metal("carenage", "#A8ADB3", rough=0.3, metallic=0.4, dirt=0.55)
    noir = k.metal("noir_mat", "#222428", rough=0.6, metallic=0.25)
    radome = k.matte("radome", "#C4C6C8", rough=0.42, grain=0.26, dirt=0.5, gain=1.0)
    acier = k.metal("acier", "#6E737A", rough=0.3, metallic=0.8, dirt=0.5)
    vis = k.metal("vis", "#B0B4BA", rough=0.2, metallic=0.95, clean=True)
    bleu = k.emit("bleu", "#3AA8FF", strength=1.0)

    # Correction V3 du 22/10 : coque relevée (pieds visibles, vide sous la coque) et moins profonde
    hx, hty, A, B, z0, z1 = 0.0, -0.08, 1.86, 0.88, 0.60, 1.82
    # --- pieds télescopiques courts (vide sous la coque) ---
    for sx in (-1, 1):
        for ty in (0.55, -0.65):
            x = sx * 1.25
            k.cyl(x, ty, 0.2, 0.0, 0.05, noir, "patin_%d_%d" % (sx, int(ty * 10)), verts=24)
            k.cyl(x, ty, 0.11, 0.05, 0.30, acier, "pied_%d_%d" % (sx, int(ty * 10)), verts=20)
            k.cyl(x, ty, 0.085, 0.30, 0.72, caren, "pied_tube_%d_%d" % (sx, int(ty * 10)), verts=20)
            k.bands(x, ty, 0.11, (0.28,), noir, "pied_bague_%d_%d" % (sx, int(ty * 10)), minor=0.016)
    # --- coque lisse arrondie (superellipsoïde) et bandeau noir en saillie ---
    superhull(k, hx, hty, A, B, z0, z1, caren, "coque")
    # bandeau noir : tranche de la même coque, un peu plus grande, autour de la ceinture
    superhull(k, hx, hty, A, B, z0, z1, noir, "bandeau_noir", phi0=-0.05, phi1=0.30, grow=0.012, rings=4)
    superhull(k, hx, hty, A, B, z0, z1, acier, "liseré_bas", phi0=-0.62, phi1=-0.55, grow=0.008, rings=1)
    # coutures de panneaux : méridiens fins sur la demi-coque sud et le dessus
    seams = []
    for i in range(9):
        th = math.pi + math.pi * (i + 0.5) / 9
        pts = [superhull_pt(hx, hty, A + 0.006, B + 0.004, z0, z1, th, phi) for phi in
               [-0.5 + (1.45 + 0.5) * j / 10 for j in range(11)]]
        seams += [k.rod(pts[j], pts[j + 1], 0.009, noir, "couture_%d_%d" % (i, j), verts=5) for j in range(10)]
    k.join(seams, "coutures")
    # goujons le long du bandeau
    pts = []
    for i in range(36):
        th = math.pi + math.pi * (i + 0.5) / 36
        for phi in (-0.12, 0.38):
            x, y, z = superhull_pt(hx, hty, A + 0.01, B + 0.008, z0, z1, th, phi)
            nx, ny = math.cos(th), math.sin(th)
            pts.append(((x, y, z), (nx, ny, 0.35)))
    k.studs([((p[0], p[1], p[2]), tuple(c / math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2) for c in n)) for p, n in pts],
            0.013, vis, "goujons_bandeau")
    # voyants bleus dans le bandeau (façade sud) et écran
    for i, x in enumerate((-1.35, -1.05, -0.75, 0.75, 1.05, 1.35)):
        ty = hty + B * (1 - (abs(x) / A) ** 3.2) ** (1 / 3.2) + 0.012
        k.box(x - 0.09, x + 0.09, ty - 0.04, ty + 0.012, 1.18, 1.30, bleu, "voyant_%d" % i, bevel=0)
    # trappes et grilles posées sur le dessus arrondi de la coque (hauteur de la surface calculée)
    def hull_z(x, ty):
        sx = (abs(x - hx) / A) ** 3.2 + (abs(ty - hty) / B) ** 3.2
        s = min(1.0, sx ** (1 / 3.2))
        return (z0 + z1) / 2 + (z1 - z0) / 2 * max(0.0, 1 - s ** 3.0) ** (1 / 3.0)
    for i, (x, ty, w, d) in enumerate(((-1.0, 0.35, 0.18, 0.14), (-0.62, 0.35, 0.18, 0.14), (-0.82, 0.05, 0.38, 0.1),
                                       (1.25, 0.3, 0.2, 0.16))):
        z = hull_z(x, ty)
        k.box(x - w, x + w, ty - d, ty + d, z - 0.05, z + 0.025, acier if i < 3 else noir, "trappe_%d" % i, bevel=0.012)
        if i == 3:
            k.louvres(x - w + 0.03, x + w - 0.03, ty + d, z - 0.04, z + 0.02, 3, acier, "grille_lames", depth=0.012)
        else:
            k.stud_row(x - w + 0.03, x + w - 0.03, ty + d, z + 0.005, 3, 0.012, vis, "trappe_vis_%d" % i)
    # porte (sas) et rampe d'accès
    ty_d = hty + B - 0.03
    k.box(-0.36, 0.36, ty_d - 0.12, ty_d + 0.08, 0.60, 1.43, noir, "porte_cadre", bevel=0.03)
    k.box(-0.27, 0.27, ty_d + 0.04, ty_d + 0.1, 0.64, 1.36, acier, "porte", bevel=0.02)
    k.box(-0.012, 0.012, ty_d + 0.1, ty_d + 0.11, 0.64, 1.36, noir, "porte_joint", bevel=0)
    k.box(-0.3, 0.3, ty_d + 0.08, ty_d + 0.11, 1.37, 1.41, bleu, "porte_feu", bevel=0)
    for i, (ty0, z1s) in enumerate(((ty_d + 0.05, 0.56), (ty_d + 0.2, 0.42), (ty_d + 0.35, 0.28), (ty_d + 0.5, 0.14))):
        k.box(-0.32, 0.32, ty0, ty0 + 0.17, 0.0, z1s, noir, "marche_%d" % i, bevel=0.006)

    # --- grand radôme posé bas sur un piédestal trapu ---
    rx, rty, R, rz = 0.5, -0.80, 1.18, 3.50
    k.cyl(rx, rty, 0.7, z1 - 0.2, z1 + 0.1, acier, "piedestal_embase", verts=48)
    k.ring_studs(rx, rty, 0.7, z1, 12, 0.016, vis, "piedestal_boulons")
    k.cyl(rx, rty, 0.66, z1 + 0.1, rz - R + 0.25, noir, "piedestal", verts=48, r2=0.5)
    k.ribs(rx, rty, 0.6, z1 + 0.12, rz - R + 0.2, 8, acier, "piedestal_nervures", w=0.04, d=0.02)
    k.sphere(rx, rty, rz, R, radome, "radome", seg=64, rings=32)
    k.sphere_seams(rx, rty, rz, R, acier, "radome_coutures", lats=(-0.35, 0.05, 0.45, 0.85), mers=8, minor=0.011)
    k.sphere(rx, rty + 0.6, rz - 0.6, 0.06, bleu, "radome_feu", seg=16, rings=8)

    # --- parabole (pose de référence) ---
    k.cyl(-1.05, -0.45, 0.13, z1 - 0.1, z1 + 0.35, acier, "parabole_pied", verts=20)
    _dish(k, -1.05, -0.45, z1 + 0.33, 0.62, 0.22, math.radians(40), math.radians(-60), caren, "parabole")
    k.rod(k.P(-1.05, -0.45, z1 + 0.35), k.P(-1.05 + 0.18, -0.45 + 0.22, z1 + 0.78), 0.018, acier, "parabole_source", role="tige")

    # --- antenne fouet (tige, point le plus haut) ---
    k.cyl(-1.35, -0.75, 0.07, z1 - 0.1, z1 + 0.2, acier, "fouet_embase", verts=16)
    k.cyl(-1.35, -0.75, 0.018, z1 + 0.2, 6.75, acier, "fouet", verts=8, bevel=0, r2=0.008, role="tige")
    k.sphere(-1.35, -0.75, 6.77, 0.05, bleu, "fouet_feu", seg=12, rings=6, role="tige")


# ----------------------------------------------------------------------------------------------------------
# Époque 11 · Tour blanche : tour effilée ; 4 ailerons triangulaires ; posée sur 4 pieds en V (vides au sol) ;
# nacelle d'observation ; flèche ; lignes lumineuses bleu-blanc (chenillard par script en phase 2).
# ----------------------------------------------------------------------------------------------------------
def build_e11(k):
    blanc = k.metal("alliage_blanc", "#C9C6BE", rough=0.3, metallic=0.35, dirt=0.55)
    titane = k.metal("titane", "#8E9AA6", rough=0.26, metallic=0.85, dirt=0.5)
    sombre = k.metal("sombre", "#30343A", rough=0.45, metallic=0.5)
    vis = k.metal("vis", "#B8BCC2", rough=0.2, metallic=0.95, clean=True)
    ligne = k.emit("ligne", "#BFE6FF", strength=1.0)

    cty = -0.35
    # --- plate-forme octogonale sur 4 pieds en V ---
    k.ngon(0.0, -0.2, 1.15, 8, 0.82, 1.12, titane, "plate_forme", rot=math.pi / 8, sy=1.2, bevel=0.012)
    k.ngon(0.0, -0.2, 1.17, 8, 1.06, 1.12, sombre, "plate_forme_bord", rot=math.pi / 8, sy=1.2, bevel=0)
    pcx, pcy, _ = k.P(0.0, -0.2, 0)
    pts = []
    for i in range(24):
        a = math.pi + math.pi * (i + 0.5) / 24
        pts.append(((pcx + 1.1 * math.cos(a), pcy + 1.2 * 1.1 * math.sin(a), 0.95), (math.cos(a), math.sin(a), 0.0)))
    k.studs(pts, 0.016, vis, "plate_forme_vis")
    feet = [(-1.55, 1.38), (1.55, 1.38), (-1.5, -1.55), (1.5, -1.55)]
    tops = [((-0.55, 0.42), (-0.95, -0.05)), ((0.55, 0.42), (0.95, -0.05)),
            ((-0.95, -0.4), (-0.5, -0.85)), ((0.95, -0.4), (0.5, -0.85))]
    for i, ((fx, fty), pair) in enumerate(zip(feet, tops)):
        k.cyl(fx, fty, 0.17, 0.0, 0.06, sombre, "patin_%d" % i, verts=20)
        for j, (px, pty) in enumerate(pair):
            k.rod(k.P(fx, fty, 0.05), k.P(px, pty, 0.86), 0.08, blanc, "pied_%d_%d" % (i, j), verts=12)
        k.sphere(fx, fty, 0.1, 0.1, titane, "rotule_%d" % i, seg=16, rings=8)
    # rampe d'accès au sud
    a0, a1 = 1.65, 0.62
    k.loft([[k.P(-0.26, a0, 0.0), k.P(0.26, a0, 0.0), k.P(0.26, a1, 0.0), k.P(-0.26, a1, 0.0)],
            [k.P(-0.26, a0, 0.04), k.P(0.26, a0, 0.04), k.P(0.26, a1, 0.86), k.P(-0.26, a1, 0.86)]], titane, "rampe")
    for i in range(6):
        t = (i + 0.5) / 6
        ty = a0 + (a1 - a0) * t
        z = 0.04 + (0.86 - 0.04) * t
        k.box(-0.24, 0.24, ty - 0.012, ty + 0.012, z, z + 0.012, sombre, "rampe_strie_%d" % i, bevel=0)

    # --- tour effilée (plus large) et nacelle d'observation ---
    zt = 5.85
    k.ngon(0.0, cty, 0.84, 8, 1.12, zt, blanc, "tour", r_top=0.30, rot=math.pi / 8, bevel=0.01)
    for i, z in enumerate((1.7, 2.5, 3.3, 5.0)):
        t = (z - 1.12) / (zt - 1.12)
        r = 0.84 + (0.30 - 0.84) * t
        k.ngon(0.0, cty, r + 0.02, 8, z, z + 0.08, titane, "tour_bague_%d" % i, rot=math.pi / 8, bevel=0.004)
    # panneaux de la tour : joints verticaux (arêtes de titane) sur les pans
    tcx, tcy, _ = k.P(0.0, cty, 0)
    ed = []
    for i in range(8):
        a = math.pi / 8 + 2 * math.pi * i / 8
        if math.sin(a) > 0.3:
            continue
        ed.append(k.rod((tcx + 0.85 * math.cos(a), tcy + 0.85 * math.sin(a), 1.12),
                        (tcx + 0.31 * math.cos(a), tcy + 0.31 * math.sin(a), zt), 0.016, titane, "tour_arete_%d" % i, verts=6))
    k.join(ed, "tour_aretes")
    zn = 4.05
    rn = 0.84 + (0.30 - 0.84) * (zn - 1.12) / (zt - 1.12)
    k.ngon(0.0, cty, rn, 8, zn - 0.05, zn, titane, "nacelle_fond", r_top=0.78, rot=math.pi / 8, bevel=0.006)
    k.ngon(0.0, cty, 0.78, 8, zn, zn + 0.32, blanc, "nacelle", r_top=0.72, rot=math.pi / 8, bevel=0.01)
    k.ngon(0.0, cty, 0.795, 8, zn + 0.12, zn + 0.22, sombre, "nacelle_vitrage", r_top=0.775, rot=math.pi / 8, bevel=0)
    k.ngon(0.0, cty, 0.72, 8, zn + 0.32, zn + 0.40, titane, "nacelle_toit", r_top=0.45, rot=math.pi / 8, bevel=0.006)
    # porte au pied de la tour (face sud)
    k.box(-0.22, 0.22, 0.2, 0.28, 1.12, 1.68, sombre, "porte", bevel=0.006)
    k.box(-0.26, 0.26, 0.22, 0.27, 1.68, 1.74, ligne, "porte_feu", bevel=0)
    # lignes lumineuses verticales sur la face sud de la tour
    for s in (-1, 1):
        a = k.P(s * 0.24, cty + 0.78, 1.8)
        b = k.P(s * 0.1, cty + 0.25, 5.6)
        lit_rod(k, a, b, 0.045, ligne, sombre, "tour_ligne_%d" % s)
    # hublot lumineux de la tour (face sud) : zone de lueur d'au moins 8 × 8 px hr (D2-1 ; absente à la passe 5)
    k.box(-0.15, 0.15, 0.10, 0.145, 1.95, 2.30, sombre, "hublot_cadre", bevel=0.008)
    k.box(-0.12, 0.12, 0.13, 0.155, 1.98, 2.27, ligne, "hublot", bevel=0)

    # --- 4 ailerons triangulaires (plans verticaux, en X autour de la tour), agrandis ---
    for i, az in enumerate((24, 156, 204, 336)):
        a = math.radians(az)
        d = (math.cos(a), math.sin(a))
        nrm = (-d[1] * 0.04, d[0] * 0.04)
        cx, cy, _ = k.P(0.0, cty, 0)
        p_in0 = (cx + 0.7 * d[0], cy + 0.7 * d[1], 1.12)
        p_out = (cx + 1.97 * d[0], cy + 1.97 * d[1], 1.12)
        p_top = (cx + 0.45 * d[0], cy + 0.45 * d[1], 4.25)
        ring0 = [(p[0] - nrm[0], p[1] - nrm[1], p[2]) for p in (p_in0, p_out, p_top)]
        ring1 = [(p[0] + nrm[0], p[1] + nrm[1], p[2]) for p in (p_in0, p_out, p_top)]
        k.loft([ring0, ring1], blanc, "aileron_%d" % i, bevel=0.008)
        # nervure médiane de l'aileron (titane)
        mid0 = ((p_in0[0] + p_out[0]) / 2, (p_in0[1] + p_out[1]) / 2, 1.12)
        k.rod(mid0, (p_top[0], p_top[1], p_top[2] - 0.3), 0.02, titane, "aileron_nervure_%d" % i, verts=6)
        # bord d'attaque lumineux
        lit_rod(k, (p_out[0], p_out[1], p_out[2] + 0.05), (p_top[0] + 0.06 * d[0], p_top[1] + 0.06 * d[1], p_top[2] - 0.05),
                0.04, ligne, sombre, "aileron_ligne_%d" % i)
        k.rod(p_out, (p_out[0], p_out[1], p_out[2] - 0.34), 0.055, titane, "aileron_jambe_%d" % i, verts=10)

    # --- flèche (tige, point le plus haut) ---
    k.cyl(0.0, cty, 0.06, zt, 7.3, titane, "fleche", verts=12, r2=0.008, bevel=0, role="tige")
    k.sphere(0.0, cty, 6.2, 0.07, ligne, "fleche_feu", seg=16, rings=8, role="tige")


# ----------------------------------------------------------------------------------------------------------
# Époque 12 · Nexus : noyau noir vertical ; 3 anneaux chromés horizontaux en lévitation, espacés (vides) ;
# 4 pylônes ; blocs flottants ; givre ; anneaux cyan (rotation par script en phase 2).
# ----------------------------------------------------------------------------------------------------------
def build_e12(k):
    noir = k.metal("noir_profond", "#26282E", rough=0.28, metallic=0.65, dirt=0.5, gain=3.6)
    chrome = k.metal("chrome", "#9AA3AD", rough=0.12, metallic=1.0, clean=True, bump=0.2)
    givre = k.matte("givre", "#DDEEFF", rough=0.6, grain=0.3, grain_scale=80.0, dirt=0.5, gain=0.85)
    cyan = k.emit("cyan", "#4AF0FF", strength=1.0)

    cty = -0.3
    # --- dalle au sol (couche plate) ---
    k.ngon(0.0, 0.0, 1.78, 8, 0.0, 0.1, noir, "dalle", rot=math.pi / 8, sy=1.31, bevel=0.006, role="flat")
    k.ngon(0.0, 0.0, 1.8, 8, 0.0, 0.03, chrome, "dalle_bord", rot=math.pi / 8, sy=1.31, bevel=0, role="flat")
    # --- noyau noir vertical (hexagonal), élargi ---
    rc = 0.62
    # face plate tournée vers le sud (rot = 0 : sommets à 0°, 60°, ... ; face à 270°, apothème rc·cos 30°)
    k.ngon(0.0, cty, rc, 6, 0.1, 6.05, noir, "noyau", rot=0.0, bevel=0.01)
    k.ngon(0.0, cty, rc, 6, 6.05, 6.45, chrome, "noyau_pointe", r_top=0.0, rot=0.0, bevel=0.006)
    k.ngon(0.0, cty, rc + 0.08, 6, 0.1, 0.5, givre, "noyau_givre", r_top=rc + 0.02, rot=0.0, bevel=0.01)
    cx, cy, _ = k.P(0.0, cty, 0)
    for i in range(6):
        a = 2 * math.pi * i / 6
        px, py = cx + (rc + 0.005) * math.cos(a), cy + (rc + 0.005) * math.sin(a)
        k.rod((px, py, 0.5), (px, py, 6.0), 0.024, chrome, "noyau_arete_%d" % i, verts=8, role="tige")
    for i, z in enumerate((1.0, 2.25, 3.55, 4.85)):
        k.ngon(0.0, cty, rc + 0.01, 6, z, z + 0.06, cyan, "noyau_joint_%d" % i, rot=0.0, bevel=0)
    # plaques et grilles du noyau (faces sud), entre les joints
    for j, (za, zb) in enumerate(((0.55, 0.95), (1.1, 2.2), (2.35, 3.5), (3.65, 4.8), (4.95, 5.95))):
        tf = cty + rc * math.cos(math.pi / 6) / R2
        for s in (-1, 1):
            k.box(s * 0.17 - 0.1, s * 0.17 + 0.1, tf - 0.01, tf + 0.02, za + 0.05, zb - 0.05, chrome,
                  "noyau_plaque_%d_%d" % (j, s), bevel=0.01)
        k.louvres(-0.05, 0.05, tf + 0.01, za + 0.1, zb - 0.1, max(2, int((zb - za) / 0.12)), noir, "noyau_grille_%d" % j,
                  depth=0.015)

    # --- 3 anneaux chromés en lévitation (aucun support : vides), agrandis ---
    for i, (R, z) in enumerate(((1.74, 1.55), (1.45, 2.9), (1.15, 4.2))):
        k.torus(0.0, cty, z, R, 0.14, chrome, "anneau_%d" % i, minor_seg=18)
        k.torus(0.0, cty, z, R - 0.13, 0.07, cyan, "anneau_lueur_%d" % i, minor_seg=10)
        k.torus(0.0, cty - 0.05 * 0.7071 / R2, z - 0.05 * 0.7071, R - 0.13, 0.095, noir, "anneau_lueur_fond_%d" % i,
                minor_seg=10)
        tp = []
        for j in range(18):
            a = math.pi + math.pi * (j + 0.5) / 18
            tp.append(((cx + R * math.cos(a), cy + R * math.sin(a), z + 0.135), (0.0, 0.0, 1.0)))
        k.studs(tp, 0.02, noir, "anneau_bobines_%d" % i)

    # --- blocs flottants (kit de l'époque) autour du haut du noyau ---
    for i in range(5):
        a = math.pi * 1.1 + 2 * math.pi * i / 5
        x, y = cx + 0.98 * math.cos(a), cy + 0.98 * math.sin(a)
        z = 3.5 + 0.25 * _h(i, 4)
        b = k.bbox(x, -y / R2, z, 0.26, 0.26, 0.32, noir, "bloc_flottant_%d" % i, rot=(0.0, 0.0, a), bevel=0.02)
        k.bbox(x, -y / R2, z + 0.17, 0.2, 0.2, 0.025, cyan, "bloc_lueur_%d" % i, rot=(0.0, 0.0, a), bevel=0)

    # --- entrée (porte au sud) ---
    k.box(-0.46, 0.46, -0.05, 0.74, 0.1, 0.7, noir, "entree", bevel=0.012)
    k.panels(-0.46, 0.46, -0.05, 0.74, 0.1, 0.7, chrome, "entree_plaques", top=(2, 2), south=None, gap=0.03, thick=0.012)
    k.box(-0.26, 0.26, 0.72, 0.77, 0.1, 0.58, chrome, "porte", bevel=0.006)
    k.box(-0.32, 0.32, 0.73, 0.78, 0.60, 0.66, cyan, "porte_feu", bevel=0)
    for s in (-1, 1):
        k.box(s * 0.32 - 0.035, s * 0.32 + 0.035, 0.73, 0.78, 0.1, 0.60, cyan, "porte_montant_%d" % s, bevel=0)

    # --- 4 pylônes aux coins (pointes cyan), rehaussés ---
    for sx in (-1, 1):
        for ty, h in ((1.3, 1.6), (-1.38, 2.1)):
            x = sx * 1.42
            nm = "%d_%d" % (sx, int(ty * 10))
            k.box(x - 0.14, x + 0.14, ty - 0.14, ty + 0.14, 0.1, h, noir, "pylone_" + nm, bevel=0.012)
            k.box(x - 0.16, x + 0.16, ty - 0.16, ty + 0.16, 0.1, 0.36, givre, "pylone_givre_" + nm, bevel=0.012)
            k.box(x - 0.16, x + 0.16, ty - 0.16, ty + 0.16, h, h + 0.07, chrome, "pylone_chapeau_" + nm, bevel=0.006)
            for z in (0.6, 1.0, 1.4):
                if z < h - 0.1:
                    k.box(x - 0.15, x + 0.15, ty - 0.15, ty + 0.15, z, z + 0.04, chrome, "pylone_bague_%s_%d" % (nm, int(z * 10)),
                          bevel=0)
            k.ngon(x, ty, 0.1, 4, h + 0.07, h + 0.36, cyan, "pylone_pointe_" + nm, r_top=0.0, rot=math.pi / 4, bevel=0)

    # --- antenne de pointe (tige, point le plus haut) ---
    k.cyl(0.0, cty, 0.03, 6.4, 7.05, chrome, "pointe_antenne", verts=10, r2=0.006, bevel=0, role="tige")
