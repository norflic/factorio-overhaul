"""Ère I industrielle (époques 1 à 3) : boîtes basses, matériaux bruts, premières verticales (bible §1.2, §5).

Chaque fonction reçoit un centre_kit.Kit (repère de jeu : x est, ty sud, z haut).
"""
import math

R2 = 2.0 ** 0.5


def _h(i, a=0.0):
    """Pseudo-aléatoire déterministe dans [-1, 1] (aucun module random : mêmes octets à chaque rendu)."""
    return math.sin(i * 12.9898 + a * 78.233) * 0.5 + math.sin(i * 4.1414 + a * 1.618) * 0.5


# ----------------------------------------------------------------------------------------------------------
# Époque 1 · Poste de pionnier : cabane en rondins, toit de tôle ondulée, plate-forme de rondins, rempart de
# sacs de sable en U devant la porte sud, mât de drapeau en bois à l'arrière gauche (tige, O ≈ 1,2).
# ----------------------------------------------------------------------------------------------------------
def _corrugated(k, name, x0, x1, ty_a, z_a, ty_b, z_b, mat, waves=28, amp=0.017):
    """Pan de tôle ondulée entre la ligne (ty_a, z_a) et la ligne (ty_b, z_b), de x0 à x1 ; ondes le long de X
    (les plis descendent la pente)."""
    verts, faces = [], []
    n = waves * 4
    ya, yb = -ty_a * R2, -ty_b * R2
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        dz = amp * math.sin(2 * math.pi * i / 4)
        verts.append((x, ya, z_a + dz))
        verts.append((x, yb, z_b + dz))
    for i in range(n):
        a = 2 * i
        faces.append((a, a + 2, a + 3, a + 1))
    o = k.mesh(name, verts, faces, mat, smooth=60)
    if o is not None:
        m = o.modifiers.new("epais", "SOLIDIFY")
        m.thickness = 0.022
    return o


def _sandbag(k, tx, ty, z, along, mat, i, name):
    """Sac de sable : ellipsoïde aplati (0,40 × 0,25 × 0,15 unité), légèrement tourné (variante
    déterministe). Reprise V3 : les sacs du premier modeleur (0,34 × 0,20) se lisaient comme des galets
    séparés ; ils se chevauchent maintenant d'environ 10 % pour former un rempart continu."""
    o = k.sphere(tx, ty, z, 0.115, mat, "%s_%d" % (name, i), seg=16, rings=8)
    if o is None:
        return None
    if along == "x":
        o.scale = (1.75 + 0.08 * _h(i), 1.08, 0.64)
    else:
        o.scale = (1.08, 1.75 + 0.08 * _h(i), 0.64)
    o.rotation_euler = (0, 0, 0.07 * _h(i, 3))
    return o


def build_e01(k):
    fer = k.metal("fer", "#4E4A46", rough=0.42, metallic=0.6, rust="#5E3E2A", rust_amount=0.12, dirt=0.5)
    bois = k.matte("bois", "#6B4F35", grain=0.3)
    bois_g = k.matte("bois_gris", "#5E5244", grain=0.3)
    bois_c = k.matte("bois_clair", "#7A6040", grain=0.25)
    toile = k.matte("toile", "#7A6C50", rough=0.92, grain=0.2, grain_scale=25.0, gain=1.45)
    drap = k.matte("drapeau", "#7A3A2C", rough=0.85, grain=0.15)
    lant = k.emit("lanterne", "#FFB060", strength=1.6, off_hex="#A08860")
    fen = k.emit("fenetre", "#FFB060", strength=0.55, off_hex="#6A5E4A")

    # --- plate-forme de rondins (couche plate posée au sol) ---
    logs = []
    n = 22
    for i in range(n):
        ty = -1.74 + (i + 0.5) * (2.62 / n)
        x0 = -1.52 + 0.05 * _h(i, 1)
        x1 = 1.52 + 0.05 * _h(i, 2)
        logs.append(k.hcyl("x", x0, x1, 0, ty, 0.058, 0.058, bois_g, "plate_%d" % i, verts=12, bevel=0, role="flat"))
    k.join(logs, "plate_forme")

    # --- murs en rondins (7 assises ; porte et fenêtre ménagées dans la façade sud) ---
    z_base, r_log, step = 0.11, 0.064, 0.122
    wall = []
    for c in range(7):
        z = z_base + r_log + c * step
        for ty, nm in ((0.35, "av"), (-1.55, "ar")):
            segs = [(-1.38, 1.38)]
            if nm == "av":
                door = z < 0.74
                win = 0.36 < z < 0.70
                if door and win:
                    segs = [(-1.38, -0.86), (-0.50, -0.27), (0.27, 1.38)]
                elif door:
                    segs = [(-1.38, -0.27), (0.27, 1.38)]
            for j, (a, b) in enumerate(segs):
                wall.append(k.hcyl("x", a, b, 0, ty, z, r_log, bois, "mur_%s_%d_%d" % (nm, c, j), verts=14, bevel=0))
        for x, nm in ((-1.25, "o"), (1.25, "e")):
            wall.append(k.hcyl("y", -1.64, 0.44, x, 0, z + 0.06, r_log, bois, "mur_%s_%d" % (nm, c), verts=14, bevel=0))
    k.join(wall, "murs_rondins")
    k.box(-1.24, 1.24, -1.52, 0.32, 0.11, 1.0, bois_g, "ame_murs", bevel=0)
    k.box(-1.30, 1.30, -1.60, 0.40, 0.98, 1.05, bois_c, "sabliere", bevel=0.006)

    # --- toit de tôle ondulée à deux pans, faîtage est-ouest ---
    z_r, ty_r = 1.50, -0.62
    s = (z_r - 1.05) / (0.40 - ty_r)
    _corrugated(k, "toit_av", -1.42, 1.42, ty_r, z_r, 0.50, z_r - s * (0.50 - ty_r), fer)
    _corrugated(k, "toit_ar", -1.42, 1.42, ty_r, z_r, -1.72, z_r - s * (ty_r + 1.72), fer)
    k.hcyl("x", -1.44, 1.44, 0, ty_r, z_r + 0.035, 0.04, fer, "faitiere", verts=12, bevel=0)
    for x, nm in ((-1.27, "o"), (1.27, "e")):
        y0, y1 = -0.40 * R2, 1.60 * R2
        yr = -ty_r * R2
        verts = []
        for dx in (-0.03, 0.03):
            verts += [(x + dx, y0, 1.05), (x + dx, y1, 1.05), (x + dx, yr, z_r)]
        k.mesh("pignon_" + nm, verts, [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], bois_c)

    # --- porte (vantail en planches, pentures de fer) et fenêtre ---
    k.door(-0.27, 0.27, 0.36, 0.72, bois_c, bois, name="porte")
    for z in (0.24, 0.58):
        k.box(-0.25, 0.20, 0.43, 0.445, z, z + 0.035, fer, "penture_%d" % int(z * 100), bevel=0)
    k.box(-0.86, -0.50, 0.355, 0.39, 0.37, 0.67, bois_c, "fenetre_cadre", bevel=0.006)
    k.box(-0.83, -0.53, 0.37, 0.40, 0.40, 0.64, fen, "fenetre_vitre", bevel=0)
    k.box(-0.69, -0.67, 0.40, 0.41, 0.40, 0.64, bois_c, "fenetre_croisillon", bevel=0)
    k.box(-0.83, -0.53, 0.40, 0.41, 0.515, 0.53, bois_c, "fenetre_traverse", bevel=0)

    # --- lanterne de porte (lumière de nuit seulement) ---
    k.rod(k.P(0.38, 0.37, 0.76), k.P(0.42, 0.47, 0.76), 0.012, fer, "potence_lanterne", role="tige")
    k.box(0.375, 0.465, 0.435, 0.505, 0.70, 0.73, fer, "lanterne_toit", bevel=0)
    k.box(0.385, 0.455, 0.44, 0.50, 0.56, 0.70, lant, "lanterne_verre", bevel=0)
    k.box(0.375, 0.465, 0.435, 0.505, 0.54, 0.56, fer, "lanterne_pied", bevel=0)

    # --- tuyau de poêle à travers le pan avant (tige) ---
    k.cyl(0.78, -0.25, 0.045, 1.25, 1.98, fer, "tuyau_poele", verts=12, bevel=0, role="tige")
    k.cyl(0.78, -0.25, 0.075, 1.98, 2.02, fer, "tuyau_poele_chapeau", verts=12, bevel=0, role="tige")

    # --- rempart de sacs de sable en U devant la porte sud ---
    bags = []
    i = 0
    for c, z in enumerate((0.07, 0.20, 0.33)):
        off = 0.13 if c % 2 else 0.0          # appareil décalé d'une demi-longueur à chaque assise
        for side in (-1, 1):
            for j in range(4 if c < 2 else 3):
                ty = 0.62 + off + j * 0.255
                bags.append(_sandbag(k, side * 0.98, ty, z, "y", toile, i, "sac"))
                i += 1
            for j in range(3 if c < 2 else 2):
                x = side * (0.34 + 0.5 * off + j * 0.34)
                if abs(x) < 0.90:
                    bags.append(_sandbag(k, x, 1.68, z, "x", toile, i, "sac"))
                    i += 1
    k.join(bags, "rempart_sacs")

    # --- caisses en bois (flanc est) et pile de rondins (flanc ouest) ---
    k.box(1.34, 1.64, -0.30, 0.10, 0.11, 0.43, bois_c, "caisse_1", bevel=0.01)
    k.box(1.38, 1.60, -0.22, 0.04, 0.43, 0.66, bois, "caisse_2", bevel=0.01)
    for j, (ty0, ty1) in enumerate(((-0.305, -0.28), (0.075, 0.105))):
        k.box(1.335, 1.645, ty0, ty1, 0.11, 0.43, fer, "caisse_feuillard_%d" % j, bevel=0)
    pile = []
    for j, (x, z) in enumerate(((-1.62, 0.18), (-1.48, 0.18), (-1.55, 0.30))):
        pile.append(k.hcyl("y", -0.95, 0.05 + 0.04 * j, x, 0, z, 0.068, bois, "buche_%d" % j, verts=12, bevel=0))
    k.join(pile, "pile_rondins")

    # --- mât de drapeau en bois, arrière gauche (tige, point le plus haut) ---
    k.mast(-1.50, -1.66, 0.09, 2.32, 0.032, bois, "mat_drapeau")
    k.sphere(-1.50, -1.66, 2.34, 0.04, bois_c, "mat_pommeau", seg=12, rings=6, role="tige")
    k.flag(-1.50, -1.66, 2.28, 0.46, 0.28, drap, "drapeau", side=1)


# ----------------------------------------------------------------------------------------------------------
# Époque 2 · Bastion d'acier : bloc carré à 2 étages en plaques boulonnées, cerclé ; porte blindée centrale ;
# 2 échauguettes trapues aux coins avant ; créneaux d'acier ; mât en treillis (tige).
# ----------------------------------------------------------------------------------------------------------
def build_e02(k):
    acier = k.metal("acier", "#5C6168", rough=0.42, metallic=0.65, rust="#5A3A26", rust_amount=0.25, dirt=0.5)
    plaque = k.metal("plaque", "#646A72", rough=0.38, metallic=0.7, grain=0.14, dirt=0.45)
    cercl = k.metal("cerclage", "#2E2C2A", rough=0.5, metallic=0.6, grain=0.1, dirt=0.3)
    laiton = k.metal("laiton", "#8C7440", rough=0.3, metallic=0.9, grain=0.1, dirt=0.3)
    toit = k.metal("toit", "#46494E", rough=0.6, metallic=0.4, dirt=0.5)
    forge = k.emit("forge", "#FF6A20", strength=1.5, off_hex="#4A2E22")
    fanion = k.matte("fanion", "#6E2E26", rough=0.85)

    # --- étage bas : bloc cerclé ---
    k.box(-1.55, 1.55, -1.45, 1.15, 0.0, 0.78, acier, "bloc_bas", bevel=0.015)
    for z0, z1 in ((0.07, 0.15), (0.66, 0.74)):
        k.box(-1.57, 1.57, 1.12, 1.18, z0, z1, cercl, "cerclage_av_%d" % int(z0 * 100), bevel=0.005)
        for s in (-1, 1):
            k.box(s * 1.53, s * 1.58, -1.47, 1.17, z0, z1, cercl, "cerclage_cote_%d_%d" % (s, int(z0 * 100)), bevel=0.005)
    # plaques boulonnées de la façade sud (le vantail central est à part)
    for j, (x0, x1) in enumerate(((-1.42, -0.92), (-0.86, -0.38), (0.38, 0.86), (0.92, 1.42))):
        k.box(x0, x1, 1.15, 1.17, 0.18, 0.62, plaque, "plaque_%d" % j, bevel=0.006)
        for z in (0.22, 0.58):
            k.rivets_line(k.P(x0 + 0.03, 1.175, z), k.P(x1 - 0.03, 1.175, z), 5, 0.017, laiton, "rivets_%d_%d" % (j, int(z * 100)))
    # parapet bas et merlons sur le toit de l'étage bas (créneaux d'acier, signature de l'époque 2)
    k.box(-1.0, 1.0, 1.0, 1.15, 0.78, 0.86, acier, "parapet_av", bevel=0.008)
    for x in (-0.8, -0.4, 0.0, 0.4, 0.8):
        k.box(x - 0.1, x + 0.1, 1.0, 1.15, 0.86, 1.02, acier, "merlon_av_%d" % int((x + 1) * 10), bevel=0.008)
    for s in (-1, 1):
        k.box(s * 1.42, s * 1.55, -1.45, 0.55, 0.78, 0.86, acier, "parapet_cote_%d" % s, bevel=0.008)
        for ty in (-1.25, -0.8, -0.35, 0.1):
            k.box(s * 1.42, s * 1.55, ty - 0.1, ty + 0.1, 0.86, 1.02, acier, "merlon_cote_%d_%d" % (s, int((ty + 2) * 10)),
                  bevel=0.008)

    # --- étage haut en retrait ---
    k.box(-1.1, 1.1, -1.45, 0.05, 0.78, 1.55, acier, "bloc_haut", bevel=0.015)
    k.box(-1.12, 1.12, 0.03, 0.08, 1.40, 1.47, cercl, "cerclage_haut", bevel=0.004)
    k.box(-1.04, 1.04, -1.39, -0.01, 1.55, 1.57, toit, "toit_haut", bevel=0)
    # Reprise V3 : le toit était un aplat gris sans aucun détail. Joints de tôles rivetés, trappe, et
    # cheminée de forge carrée cerclée (bouche rougeoyante la nuit) à l'arrière gauche.
    for j, ty in enumerate((-1.06, -0.72, -0.38)):
        k.box(-1.02, 1.02, ty - 0.018, ty + 0.018, 1.57, 1.592, cercl, "toit_joint_%d" % j, bevel=0)
        k.rivets_line(k.P(-0.98, ty, 1.594), k.P(0.98, ty, 1.594), 11, 0.013, laiton, "toit_rivets_%d" % j)
    for j, ty in enumerate((0.42, 0.78)):
        k.box(-0.98, 0.98, ty - 0.016, ty + 0.016, 0.78, 0.80, cercl, "terrasse_joint_%d" % j, bevel=0)
    k.box(0.32, 0.66, -0.66, -0.44, 1.57, 1.64, plaque, "trappe", bevel=0.006)
    k.box(0.44, 0.54, -0.47, -0.45, 1.64, 1.67, laiton, "trappe_poignee", bevel=0)
    k.box(-0.58, -0.18, -1.32, -1.02, 1.57, 1.84, acier, "cheminee_forge", bevel=0.01)
    k.box(-0.60, -0.16, -1.335, -1.005, 1.66, 1.72, cercl, "cheminee_forge_cercle", bevel=0.004)
    k.box(-0.62, -0.14, -1.35, -0.99, 1.84, 1.88, cercl, "cheminee_forge_chapeau", bevel=0.004)
    k.box(-0.52, -0.24, -1.29, -1.05, 1.875, 1.885, forge, "cheminee_forge_bouche", bevel=0)
    for x in (-0.9, -0.5, 0.5, 0.9):
        k.box(x - 0.1, x + 0.1, -0.08, 0.05, 1.55, 1.70, acier, "merlon_haut_%d" % int((x + 1) * 10), bevel=0.008)
    for s in (-1, 1):
        for ty in (-1.25, -0.75, -0.25):
            k.box(s * 0.98, s * 1.1, ty - 0.1, ty + 0.1, 1.55, 1.70, acier, "merlon_hc_%d_%d" % (s, int((ty + 2) * 10)),
                  bevel=0.008)
    # meurtrières (lueur de forge la nuit) et écu de laiton
    for x in (-0.75, -0.4, 0.4, 0.75):
        k.box(x - 0.055, x + 0.055, 0.04, 0.07, 1.02, 1.30, forge, "meurtriere_%d" % int((x + 1) * 100), bevel=0)
    k.prism([(-0.17, 0.05), (0.17, 0.05), (0.17, 0.09), (-0.17, 0.09)], 1.0, 1.36, laiton, "ecu",
            top_poly_game=[(-0.2, 0.05), (0.2, 0.05), (0.2, 0.09), (-0.2, 0.09)], bevel=0.006)

    # --- échauguettes trapues aux coins avant ---
    for s in (-1, 1):
        x, ty = s * 1.36, 0.92
        k.ngon(x, ty, 0.34, 8, 0.0, 1.02, acier, "echauguette_%d" % s, rot=math.pi / 8, bevel=0.01)
        for z0 in (0.10, 0.62):
            k.ngon(x, ty, 0.355, 8, z0, z0 + 0.07, cercl, "echauguette_cercle_%d_%d" % (s, int(z0 * 100)), rot=math.pi / 8,
                   bevel=0.004)
        k.ngon(x, ty, 0.33, 8, 0.96, 1.04, acier, "echauguette_encorbellement_%d" % s, r_top=0.41, rot=math.pi / 8, bevel=0.006)
        k.ngon(x, ty, 0.41, 8, 1.04, 1.12, acier, "echauguette_couronne_%d" % s, rot=math.pi / 8, bevel=0.006)
        k.ngon(x, ty, 0.40, 8, 1.12, 1.46, toit, "echauguette_toit_%d" % s, r_top=0.0, rot=math.pi / 8, bevel=0.006)
        k.sphere(x, ty, 1.48, 0.035, laiton, "echauguette_epi_%d" % s, seg=12, rings=6)
        k.box(x - 0.045, x + 0.045, 1.135, 1.16, 0.42, 0.66, forge, "echauguette_fente_%d" % s, bevel=0)

    # --- porte blindée centrale, grille de forge au-dessus ---
    k.door(-0.32, 0.32, 1.15, 0.6, cercl, plaque, name="porte_blindee", depth=0.05)
    for z in (0.14, 0.33, 0.52):
        k.box(-0.30, 0.30, 1.21, 1.235, z - 0.025, z + 0.025, cercl, "porte_bande_%d" % int(z * 100), bevel=0)
        k.rivets_line(k.P(-0.27, 1.24, z), k.P(0.27, 1.24, z), 5, 0.015, laiton, "porte_rivets_%d" % int(z * 100))
    k.box(-0.24, 0.24, 1.15, 1.18, 0.64, 0.73, forge, "grille_forge", bevel=0)
    bars = [k.box(x - 0.012, x + 0.012, 1.18, 1.20, 0.64, 0.73, cercl, "grille_barreau_%d" % i, bevel=0)
            for i, x in enumerate((-0.18, -0.09, 0.0, 0.09, 0.18))]
    k.join(bars, "grille_barreaux")

    # --- mât en treillis d'acier (tige) et fanion ---
    k.lattice_mast(0.75, -1.15, 1.55, 3.45, 0.22, 0.06, cercl, "mat_treillis", panels=7)
    k.mast(0.75, -1.15, 3.40, 3.62, 0.012, cercl, "mat_pointe")
    k.flag(0.75, -1.15, 3.52, 0.40, 0.17, fanion, "fanion", side=-1)


# ----------------------------------------------------------------------------------------------------------
# Époque 3 · Hôtel de la vapeur : 2 étages en brique bardée de cuivre ; 2 hautes cheminées rondes à
# l'arrière ; grand cadran-manomètre en façade (1re lueur de jour) ; tuyauterie extérieure ; mât.
# ----------------------------------------------------------------------------------------------------------
def build_e03(k):
    brique = k.matte("brique", "#6E4434", grain=0.3, grain_scale=60.0)
    cuivre = k.metal("cuivre", "#8A5A3A", rough=0.35, metallic=0.85, rust="#3F5A4A", rust_amount=0.25, dirt=0.4)
    laiton = k.metal("laiton", "#9C7E45", rough=0.28, metallic=0.9, grain=0.1, dirt=0.3)
    fonte = k.metal("fonte", "#3A3634", rough=0.55, metallic=0.5, rust="#4A2E22", rust_amount=0.3, dirt=0.5)
    toit = k.matte("toit", "#3E3A38", rough=0.8)
    ambre = k.emit("ambre", "#FFC060", strength=0.55)
    ambre_doux = k.emit("ambre_doux", "#FFC060", strength=0.4)
    vitre = k.glass("vitre", "#2C2A28")
    fanion = k.matte("fanion", "#7A4A2A", rough=0.85)

    # --- corps à 2 étages ---
    k.box(-1.5, 1.5, -1.3, 0.95, 0.0, 1.05, brique, "corps", bevel=0.01)
    k.box(-1.53, 1.53, -1.33, 0.98, 0.0, 0.1, fonte, "soubassement", bevel=0.006)
    k.box(-1.53, 1.53, 0.93, 0.99, 0.50, 0.56, cuivre, "bandeau_etage", bevel=0.004)
    for s in (-1, 1):
        k.box(s * 1.49, s * 1.54, -1.31, 0.97, 0.50, 0.56, cuivre, "bandeau_cote_%d" % s, bevel=0.004)
        k.box(s * 1.40, s * 1.56, 0.85, 1.0, 0.0, 1.08, cuivre, "pilastre_av_%d" % s, bevel=0.006)
        k.box(s * 1.40, s * 1.56, -1.35, -1.2, 0.0, 1.08, cuivre, "pilastre_ar_%d" % s, bevel=0.006)
    k.box(-1.58, 1.58, -1.38, 1.03, 1.02, 1.12, cuivre, "corniche", bevel=0.008)
    k.box(-1.45, 1.45, -1.25, 0.9, 1.12, 1.14, toit, "toit", bevel=0)
    # Reprise V3 : toit à quatre pans en ardoise (le toit plat du premier modeleur laissait un grand aplat
    # vide sur 60 % de l'image) ; faîtage de cuivre ; 2 lucarnes à fenêtre ambrée (lueur de jour).
    ardoise = k.matte("ardoise", "#3A3E46", rough=0.55, grain=0.28, grain_scale=70.0, dirt=0.45)
    k.prism([(-1.47, -1.27), (1.47, -1.27), (1.47, 0.92), (-1.47, 0.92)], 1.12, 1.76, ardoise, "toit_pans",
            top_poly_game=[(-0.66, -0.37), (0.66, -0.37), (0.66, -0.33), (-0.66, -0.33)], bevel=0.01)
    k.hcyl("x", -0.70, 0.70, 0, -0.35, 1.765, 0.035, cuivre, "faitage", verts=12, bevel=0)
    for s in (-1, 1):
        x, ty = s * 0.62, 0.42
        k.box(x - 0.17, x + 0.17, ty - 0.22, ty + 0.10, 1.25, 1.55, brique, "lucarne_%d" % s, bevel=0.006)
        k.prism([(x - 0.2, ty - 0.24), (x + 0.2, ty - 0.24), (x + 0.2, ty + 0.13), (x - 0.2, ty + 0.13)], 1.55, 1.70, ardoise,
                "lucarne_toit_%d" % s, top_poly_game=[(x - 0.01, ty - 0.24), (x + 0.01, ty - 0.24), (x + 0.01, ty + 0.13),
                                                        (x - 0.01, ty + 0.13)], bevel=0.004)
        k.box(x - 0.13, x + 0.13, ty + 0.10, ty + 0.115, 1.29, 1.51, cuivre, "lucarne_cadre_%d" % s, bevel=0)
        k.box(x - 0.11, x + 0.11, ty + 0.11, ty + 0.125, 1.31, 1.49, ambre_doux, "lucarne_vitre_%d" % s, bevel=0)

    # --- fenêtres : rang haut éclairé (ambre), rang bas en verre sombre ---
    for x in (-1.15, -0.8, 0.8, 1.15):
        k.box(x - 0.12, x + 0.12, 0.95, 0.975, 0.60, 0.88, cuivre, "fen_h_cadre_%d" % int((x + 2) * 100), bevel=0.004)
        k.box(x - 0.095, x + 0.095, 0.97, 0.985, 0.625, 0.855, ambre_doux, "fen_h_%d" % int((x + 2) * 100), bevel=0)
        k.box(x - 0.12, x + 0.12, 0.95, 0.975, 0.14, 0.42, cuivre, "fen_b_cadre_%d" % int((x + 2) * 100), bevel=0.004)
        k.box(x - 0.095, x + 0.095, 0.97, 0.985, 0.165, 0.395, vitre, "fen_b_%d" % int((x + 2) * 100), bevel=0)

    # --- avant-corps central : porte, imposte en éventail, grand cadran-manomètre ---
    k.box(-0.55, 0.55, 0.9, 1.12, 0.0, 1.32, brique, "avant_corps", bevel=0.01)
    k.hcyl("y", 0.9, 1.12, 0.0, 0, 1.32, 0.55, brique, "avant_corps_arc", verts=48, bevel=0.006)
    k.box(-0.6, 0.6, 0.9, 1.15, 1.26, 1.34, cuivre, "avant_corps_corniche", bevel=0.005)
    k.door(-0.25, 0.25, 1.12, 0.6, laiton, fonte, name="porte_double")
    k.box(-0.006, 0.006, 1.18, 1.20, 0.03, 0.58, laiton, "porte_joint", bevel=0)
    imposte = k.hcyl("y", 1.115, 1.135, 0.0, 0, 0.64, 0.2, ambre, "imposte", verts=32, bevel=0)
    if imposte is not None:
        imposte.scale = (1.0, 1.0, 1.0)
    k.box(-0.24, 0.24, 1.10, 1.15, 0.43, 0.64, brique, "imposte_cache", bevel=0)   # moitié basse du disque
    zc, ty_f = 1.06, 1.13
    k.torus(0.0, ty_f + 0.02, zc, 0.31, 0.04, laiton, "cadran_bague", rot=(math.pi / 2, 0, 0), minor_seg=12)
    k.hcyl("y", ty_f - 0.01, ty_f + 0.012, 0.0, 0, zc, 0.29, ambre, "cadran_face", verts=48, bevel=0)
    aig = k.bbox(0.06, ty_f + 0.03, zc + 0.06, 0.2, 0.012, 0.025, fonte, "cadran_aiguille", rot=(0, -0.6, 0), bevel=0)
    k.sphere(0.0, ty_f + 0.03, zc, 0.03, fonte, "cadran_axe", seg=12, rings=6)

    # --- 2 hautes cheminées rondes à l'arrière ---
    for s in (-1, 1):
        x, ty = s * 0.95, -0.9
        k.cyl(x, ty, 0.27, 1.12, 1.24, fonte, "chem_bride_%d" % s, verts=40)
        k.cyl(x, ty, 0.2, 1.24, 2.42, fonte, "chem_fut_%d" % s, verts=40, r2=0.185)
        for z in (1.5, 1.85, 2.2):
            k.torus(x, ty, z, 0.198 - 0.012 * (z - 1.5), 0.022, cuivre, "chem_cercle_%d_%d" % (s, int(z * 10)), minor_seg=10)
        k.cyl(x, ty, 0.185, 2.42, 2.55, cuivre, "chem_levre_%d" % s, verts=40, r2=0.24, caps=False)
        k.torus(x, ty, 2.55, 0.24, 0.022, laiton, "chem_bourrelet_%d" % s, minor_seg=10)
        k.cyl(x, ty, 0.18, 2.46, 2.47, fonte, "chem_gueule_%d" % s, verts=40, bevel=0)

    # --- tuyauterie extérieure (cuivre) et vannes ---
    pipes = []
    for s in (-1, 1):
        pipes.append(k.hcyl("x", s * 0.62, s * 1.42, 0, 1.0, 0.95, 0.042, cuivre, "tuyau_h_%d" % s, verts=14, bevel=0))
        pipes.append(k.cyl(s * 1.42, 1.0, 0.042, 0.1, 0.95, cuivre, "tuyau_v_%d" % s, verts=14, bevel=0))
        pipes.append(k.sphere(s * 1.42, 1.0, 0.95, 0.05, cuivre, "tuyau_coude_%d" % s, seg=12, rings=6))
    k.join(pipes, "tuyauterie")
    for s in (-1, 1):
        k.torus(s * 1.05, 1.06, 0.95, 0.07, 0.012, laiton, "vanne_%d" % s, rot=(math.pi / 2, 0, 0), minor_seg=8)
        k.cyl(s * 1.42, 1.0, 0.06, 0.55, 0.62, laiton, "manchon_%d" % s, verts=14, bevel=0)

    # --- régulateur à boules (Watt) sur le toit ---
    k.cyl(1.08, 0.55, 0.02, 1.25, 1.62, laiton, "regulateur_axe", verts=10, bevel=0, role="tige")
    for s in (-1, 1):
        k.sphere(1.08 + s * 0.09, 0.55, 1.5, 0.05, laiton, "regulateur_boule_%d" % s, seg=12, rings=6)

    # --- mât (tige, point le plus haut) et fanion, planté dans le faîtage ---
    k.mast(0.0, -0.35, 1.74, 3.5, 0.026, fonte, "mat")
    k.sphere(0.0, -0.35, 3.52, 0.045, laiton, "mat_pommeau", seg=12, rings=6, role="tige")
    k.flag(0.0, -0.35, 3.42, 0.38, 0.16, fanion, "fanion", side=1)
