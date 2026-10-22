"""Ère I industrielle (époques 1 à 3) : boîtes basses, matériaux bruts, premières verticales (bible §1.2, §5).

Chaque fonction reçoit un centre_kit.Kit (repère de jeu : x est, ty sud, z haut).
Correction V3 du 22/10 (vérification adverse) : matières patinées (politique du kit), détail de surface sur les
grandes faces (plaques, goujons, lattes), lanterne et fenêtre de l'époque 1 visibles de nuit, époque 3
différenciée de l'époque 2 (IoU 0,843 -> cible <= 0,80 : façade en retrait, chaudière verticale à l'ouest,
réservoir sur pilotis à l'est) et élargie vers l'enveloppe (L 3,16 -> 3,48).
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
    déterministe) ; les sacs se chevauchent d'environ 10 % pour former un rempart continu."""
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
    fer = k.metal("fer", "#4E4A46", rough=0.36, metallic=0.65, rust="#5E3E2A", rust_amount=0.3, dirt=0.55)
    clou = k.metal("clou", "#8A8278", rough=0.3, metallic=0.85, clean=True)
    bois = k.matte("bois", "#6B4F35", grain=0.32, grain_scale=34.0)
    bois_g = k.matte("bois_gris", "#5E5244", grain=0.32, grain_scale=34.0)
    bois_c = k.matte("bois_clair", "#7A6040", grain=0.3, grain_scale=34.0)
    toile = k.matte("toile", "#7A6C50", rough=0.92, grain=0.26, grain_scale=25.0, gain=1.45)
    corde = k.matte("corde", "#8A7650", rough=0.9, grain=0.3, gain=1.2)
    drap = k.matte("drapeau", "#7A3A2C", rough=0.85, grain=0.24)
    # lumière de nuit (draw_as_light) : plus forte qu'avant (planche de nuit du 22/10 : lanterne invisible)
    # 2e correction du 22/10 : une couche draw_as_light ne fait que RÉVÉLER la couleur de jour (maquette : nuit =
    # mix(LUT nuit, jour, lumière)) ; la lanterne et la fenêtre « éteintes » étaient sombres, donc ternes de nuit.
    # Verre de lanterne et vitre chauds et clairs de jour (mèche, intérieur éclairé), sans lueur de jour (§5).
    lant = k.emit("lanterne", "#FFB060", strength=4.0, off_hex="#F0C878")
    fen = k.emit("fenetre", "#FFB060", strength=1.6, off_hex="#B89060")

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
    # bouts de rondins croisés aux angles (assemblage à mi-bois) : dépassent de la façade sud
    ends = []
    for c in range(7):
        z = z_base + r_log + c * step
        for x in (-1.25, 1.25):
            ends.append(k.hcyl("y", 0.36, 0.50, x, 0, z + 0.06, r_log * 1.02, bois_c, "about_%d_%d" % (c, int(x * 10)),
                               verts=12, bevel=0))
    k.join(ends, "abouts")

    # --- toit de tôle ondulée à deux pans, faîtage est-ouest ---
    z_r, ty_r = 1.50, -0.62
    s = (z_r - 1.05) / (0.40 - ty_r)
    _corrugated(k, "toit_av", -1.42, 1.42, ty_r, z_r, 0.50, z_r - s * (0.50 - ty_r), fer)
    _corrugated(k, "toit_ar", -1.42, 1.42, ty_r, z_r, -1.72, z_r - s * (ty_r + 1.72), fer)
    k.hcyl("x", -1.44, 1.44, 0, ty_r, z_r + 0.035, 0.04, fer, "faitiere", verts=12, bevel=0)
    # tôles de recouvrement, chevrons cloués et pierres de lest posées sur le pan avant
    pts = []
    for j, t in enumerate((0.22, 0.5, 0.78)):
        ty = ty_r + (0.50 - ty_r) * t
        z = z_r - s * (ty - ty_r) + 0.03
        k.hcyl("x", -1.40, 1.40, 0, ty, z, 0.016, bois_g, "liteau_%d" % j, verts=8, bevel=0)
        for i in range(9):
            x = -1.3 + i * 0.325
            px, py, _ = k.P(x, ty, 0)
            pts.append(((px, py, z + 0.012), (0.0, 0.0, 1.0)))
    k.studs(pts, 0.014, clou, "clous_toit")
    for j, (x, t) in enumerate(((-0.95, 0.35), (0.35, 0.62), (1.05, 0.3))):
        ty = ty_r + (0.50 - ty_r) * t
        st = k.sphere(x, ty, z_r - s * (ty - ty_r) + 0.05, 0.06, bois_g, "lest_%d" % j, seg=10, rings=6)
        if st is not None:
            st.scale = (1.3, 1.0, 0.7)
    for x, nm in ((-1.27, "o"), (1.27, "e")):
        y0, y1 = -0.40 * R2, 1.60 * R2
        yr = -ty_r * R2
        verts = []
        for dx in (-0.03, 0.03):
            verts += [(x + dx, y0, 1.05), (x + dx, y1, 1.05), (x + dx, yr, z_r)]
        k.mesh("pignon_" + nm, verts, [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], bois_c)

    # --- porte (vantail en planches, pentures de fer) et fenêtre ---
    k.door(-0.27, 0.27, 0.36, 0.72, bois_c, bois, name="porte")
    for i, x in enumerate((-0.135, 0.0, 0.135)):
        k.box(x - 0.006, x + 0.006, 0.43, 0.44, 0.03, 0.70, bois_g, "porte_joint_%d" % i, bevel=0)
    for z in (0.24, 0.58):
        k.box(-0.25, 0.20, 0.43, 0.445, z, z + 0.035, fer, "penture_%d" % int(z * 100), bevel=0)
        k.stud_row(-0.22, 0.17, 0.445, z + 0.018, 4, 0.012, clou, "penture_clous_%d" % int(z * 100))
    k.box(-0.88, -0.48, 0.355, 0.39, 0.35, 0.69, bois_c, "fenetre_cadre", bevel=0.006)
    k.box(-0.85, -0.51, 0.37, 0.40, 0.38, 0.66, fen, "fenetre_vitre", bevel=0)
    k.box(-0.69, -0.67, 0.40, 0.41, 0.38, 0.66, bois_c, "fenetre_croisillon", bevel=0)
    k.box(-0.85, -0.51, 0.40, 0.41, 0.515, 0.53, bois_c, "fenetre_traverse", bevel=0)
    k.box(-0.92, -0.44, 0.36, 0.44, 0.33, 0.36, bois_c, "fenetre_appui", bevel=0)

    # --- lanterne de porte (lumière de nuit seulement), agrandie ---
    k.rod(k.P(0.36, 0.37, 0.80), k.P(0.44, 0.49, 0.80), 0.012, fer, "potence_lanterne", role="tige")
    k.box(0.37, 0.51, 0.44, 0.56, 0.76, 0.80, fer, "lanterne_toit", bevel=0)
    k.box(0.385, 0.495, 0.45, 0.55, 0.57, 0.76, lant, "lanterne_verre", bevel=0)
    k.box(0.37, 0.51, 0.44, 0.56, 0.54, 0.57, fer, "lanterne_pied", bevel=0)

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
    # ligatures des sacs (corde) : petits liens sombres qui découpent le rempart
    ties = []
    for side in (-1, 1):
        for j in range(4):
            ty = 0.62 + j * 0.255 + 0.12
            ties.append(k.box(side * 0.98 - 0.13, side * 0.98 + 0.13, ty - 0.008, ty + 0.008, 0.38, 0.40, corde,
                              "lien_%d_%d" % (side, j), bevel=0))
    k.join(ties, "liens_sacs")

    # --- caisses en bois (flanc est) et pile de rondins (flanc ouest) ---
    k.box(1.34, 1.64, -0.30, 0.10, 0.11, 0.43, bois_c, "caisse_1", bevel=0.01)
    k.box(1.38, 1.60, -0.22, 0.04, 0.43, 0.66, bois, "caisse_2", bevel=0.01)
    for j, (ty0, ty1) in enumerate(((-0.305, -0.28), (0.075, 0.105))):
        k.box(1.335, 1.645, ty0, ty1, 0.11, 0.43, fer, "caisse_feuillard_%d" % j, bevel=0)
    for j, z in enumerate((0.20, 0.33)):
        k.box(1.34, 1.64, 0.10, 0.11, z, z + 0.012, bois_g, "caisse_planche_%d" % j, bevel=0)
    pile = []
    for j, (x, z) in enumerate(((-1.62, 0.18), (-1.48, 0.18), (-1.55, 0.30))):
        pile.append(k.hcyl("y", -0.95, 0.05 + 0.04 * j, x, 0, z, 0.068, bois, "buche_%d" % j, verts=12, bevel=0))
    k.join(pile, "pile_rondins")
    k.cyl(-1.55, 0.25, 0.09, 0.11, 0.36, fer, "tonneau", verts=16)
    k.bands(-1.55, 0.25, 0.09, (0.16, 0.31), fer, "tonneau_cercles", minor=0.012)

    # --- mât de drapeau en bois, arrière gauche (tige, point le plus haut) ---
    k.mast(-1.50, -1.66, 0.09, 2.32, 0.032, bois, "mat_drapeau")
    k.sphere(-1.50, -1.66, 2.34, 0.04, bois_c, "mat_pommeau", seg=12, rings=6, role="tige")
    k.flag(-1.50, -1.66, 2.28, 0.46, 0.28, drap, "drapeau", side=1)
    k.rod(k.P(-1.50, -1.66, 2.0), k.P(-1.15, -1.55, 0.11), 0.007, corde, "hauban", role="tige")


# ----------------------------------------------------------------------------------------------------------
# Époque 2 · Bastion d'acier : bloc carré à 2 étages en plaques boulonnées, cerclé ; porte blindée centrale ;
# 2 échauguettes trapues aux coins avant ; créneaux d'acier ; mât en treillis (tige).
# ----------------------------------------------------------------------------------------------------------
def build_e02(k):
    acier = k.metal("acier", "#5C6168", rough=0.38, metallic=0.7, rust="#5A3A26", rust_amount=0.3, dirt=0.55)
    plaque = k.metal("plaque", "#6A7078", rough=0.30, metallic=0.75, dirt=0.5)
    cercl = k.metal("cerclage", "#2E2C2A", rough=0.45, metallic=0.6, dirt=0.4)
    laiton = k.metal("laiton", "#A08850", rough=0.24, metallic=0.95, clean=True)
    boulon = k.metal("boulon", "#8E9096", rough=0.25, metallic=0.95, clean=True)
    toit = k.metal("toit", "#46494E", rough=0.5, metallic=0.5, dirt=0.55)
    forge = k.emit("forge", "#FF6A20", strength=2.0, off_hex="#4A2E22")
    fanion = k.matte("fanion", "#6E2E26", rough=0.85)

    # --- étage bas : bloc cerclé ---
    # Correction V3 du 22/10 : façade avant reculée de 0,15 tuile (corps moins profond que les corps pleins des
    # ères II et III : IoU des corps 0,83 à 0,86 avec E5, E7, E9)
    k.box(-1.55, 1.55, -1.45, 1.0, 0.0, 0.78, acier, "bloc_bas", bevel=0.015)
    for z0, z1 in ((0.07, 0.15), (0.66, 0.74)):
        k.box(-1.57, 1.57, 0.97, 1.03, z0, z1, cercl, "cerclage_av_%d" % int(z0 * 100), bevel=0.005)
        for s in (-1, 1):
            k.box(s * 1.53, s * 1.58, -1.47, 1.02, z0, z1, cercl, "cerclage_cote_%d_%d" % (s, int(z0 * 100)), bevel=0.005)
        k.stud_row(-1.5, 1.5, 1.03, (z0 + z1) / 2, 26, 0.016, boulon, "cerclage_boulons_%d" % int(z0 * 100))
    # plaques boulonnées de la façade sud (le vantail central est à part)
    for j, (x0, x1) in enumerate(((-1.42, -0.92), (-0.86, -0.38), (0.38, 0.86), (0.92, 1.42))):
        k.box(x0, x1, 1.0, 1.02, 0.18, 0.62, plaque, "plaque_%d" % j, bevel=0.006)
        k.box((x0 + x1) / 2 - 0.006, (x0 + x1) / 2 + 0.006, 1.02, 1.03, 0.18, 0.62, cercl, "plaque_joint_%d" % j, bevel=0)
        for z in (0.22, 0.40, 0.58):
            k.stud_row(x0 + 0.02, x1 - 0.02, 1.025, z, 6, 0.017, laiton, "rivets_%d_%d" % (j, int(z * 100)))
    # parapet bas et merlons sur le toit de l'étage bas (créneaux d'acier, signature de l'époque 2)
    k.box(-1.0, 1.0, 0.85, 1.0, 0.78, 0.86, acier, "parapet_av", bevel=0.008)
    for x in (-0.8, -0.4, 0.0, 0.4, 0.8):
        k.box(x - 0.1, x + 0.1, 0.85, 1.0, 0.86, 1.02, acier, "merlon_av_%d" % int((x + 1) * 10), bevel=0.008)
        k.stud_row(x - 0.07, x + 0.07, 1.0, 0.94, 2, 0.014, boulon, "merlon_av_b_%d" % int((x + 1) * 10))
    for s in (-1, 1):
        k.box(s * 1.42, s * 1.55, -1.45, 0.55, 0.78, 0.86, acier, "parapet_cote_%d" % s, bevel=0.008)
        for ty in (-1.25, -0.8, -0.35, 0.1):
            k.box(s * 1.42, s * 1.55, ty - 0.1, ty + 0.1, 0.86, 1.02, acier, "merlon_cote_%d_%d" % (s, int((ty + 2) * 10)),
                  bevel=0.008)
    # terrasse de l'étage bas : tôles boulonnées
    k.panels(-1.40, 1.40, 0.10, 0.83, 0.0, 0.78, plaque, "terrasse", top=(6, 2), south=None, gap=0.03, thick=0.012)

    # --- étage haut en retrait ---
    k.box(-1.1, 1.1, -1.45, 0.05, 0.78, 1.55, acier, "bloc_haut", bevel=0.015)
    k.panels(-1.06, 1.06, -1.45, 0.05, 0.80, 1.38, plaque, "bloc_haut_plaques", top=None, south=(4, 2), gap=0.03,
             skip=lambda f, xa, xb, a, b: f == "south" and xb > -0.95 and xa < 0.95 and b > 0.98 and a < 1.32)
    k.box(-1.12, 1.12, 0.03, 0.08, 1.40, 1.47, cercl, "cerclage_haut", bevel=0.004)
    k.stud_row(-1.08, 1.08, 0.08, 1.435, 18, 0.014, boulon, "cerclage_haut_boulons")
    k.box(-1.04, 1.04, -1.39, -0.01, 1.55, 1.57, toit, "toit_haut", bevel=0)
    k.panels(-1.02, 1.02, -1.37, -0.03, 1.40, 1.57, plaque, "toit_plaques", top=(4, 3), south=None, gap=0.03, thick=0.012)
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
        x, ty = s * 1.36, 0.78
        k.ngon(x, ty, 0.34, 8, 0.0, 1.02, acier, "echauguette_%d" % s, rot=math.pi / 8, bevel=0.01)
        for z0 in (0.10, 0.62):
            k.ngon(x, ty, 0.355, 8, z0, z0 + 0.07, cercl, "echauguette_cercle_%d_%d" % (s, int(z0 * 100)), rot=math.pi / 8,
                   bevel=0.004)
            k.ring_studs(x, ty, 0.36, z0 + 0.035, 5, 0.014, boulon, "echauguette_boulons_%d_%d" % (s, int(z0 * 100)))
        k.ngon(x, ty, 0.33, 8, 0.96, 1.04, acier, "echauguette_encorbellement_%d" % s, r_top=0.41, rot=math.pi / 8, bevel=0.006)
        k.ngon(x, ty, 0.41, 8, 1.04, 1.12, acier, "echauguette_couronne_%d" % s, rot=math.pi / 8, bevel=0.006)
        k.ngon(x, ty, 0.40, 8, 1.12, 1.46, toit, "echauguette_toit_%d" % s, r_top=0.0, rot=math.pi / 8, bevel=0.006)
        k.sphere(x, ty, 1.48, 0.035, laiton, "echauguette_epi_%d" % s, seg=12, rings=6)
        k.box(x - 0.045, x + 0.045, 0.995, 1.02, 0.42, 0.66, forge, "echauguette_fente_%d" % s, bevel=0)

    # --- porte blindée centrale, grille de forge au-dessus ---
    k.door(-0.32, 0.32, 1.0, 0.6, cercl, plaque, name="porte_blindee", depth=0.05)
    for z in (0.14, 0.33, 0.52):
        k.box(-0.30, 0.30, 1.06, 1.085, z - 0.025, z + 0.025, cercl, "porte_bande_%d" % int(z * 100), bevel=0)
        k.stud_row(-0.27, 0.27, 1.09, z, 5, 0.016, laiton, "porte_rivets_%d" % int(z * 100))
    k.box(-0.24, 0.24, 1.0, 1.03, 0.64, 0.73, forge, "grille_forge", bevel=0)
    bars = [k.box(x - 0.012, x + 0.012, 1.03, 1.05, 0.64, 0.73, cercl, "grille_barreau_%d" % i, bevel=0)
            for i, x in enumerate((-0.18, -0.09, 0.0, 0.09, 0.18))]
    k.join(bars, "grille_barreaux")

    # --- mât en treillis d'acier (tige) et fanion ---
    k.lattice_mast(0.75, -1.15, 1.55, 3.45, 0.22, 0.06, cercl, "mat_treillis", panels=7)
    k.mast(0.75, -1.15, 3.40, 3.62, 0.012, cercl, "mat_pointe")
    k.flag(0.75, -1.15, 3.52, 0.40, 0.17, fanion, "fanion", side=-1)


# ----------------------------------------------------------------------------------------------------------
# Époque 3 · Hôtel de la vapeur : 2 étages en brique bardée de cuivre ; 2 hautes cheminées rondes à
# l'arrière ; grand cadran-manomètre en façade (1re lueur de jour) ; tuyauterie extérieure ; mât.
# Correction V3 du 22/10 : façade en RETRAIT (ty 0,62 au lieu de 0,95) derrière un avant-corps central, chaudière
# verticale rivetée hors œuvre à l'ouest, réservoir d'eau sur pilotis à l'est : silhouette asymétrique, qui ne
# se lit plus comme le bloc de l'époque 2 (IoU 0,843), et L porté vers l'enveloppe (3,48).
# ----------------------------------------------------------------------------------------------------------
def build_e03(k):
    brique = k.matte("brique", "#6E4434", grain=0.32, grain_scale=60.0)
    joint = k.matte("joint", "#3A2C26", grain=0.2)
    cuivre = k.metal("cuivre", "#8A5A3A", rough=0.30, metallic=0.85, rust="#3F5A4A", rust_amount=0.3, dirt=0.45)
    cuivre_p = k.metal("cuivre_poli", "#B07A4A", rough=0.22, metallic=0.95, clean=True)
    laiton = k.metal("laiton", "#9C7E45", rough=0.24, metallic=0.95, clean=True)
    fonte = k.metal("fonte", "#3A3634", rough=0.5, metallic=0.5, rust="#4A2E22", rust_amount=0.32, dirt=0.55)
    ambre = k.emit("ambre", "#FFC060", strength=1.0)
    ambre_doux = k.emit("ambre_doux", "#FFC060", strength=0.85)
    vitre = k.glass("vitre", "#2C2A28")
    fanion = k.matte("fanion", "#7A4A2A", rough=0.85)
    ardoise = k.matte("ardoise", "#3A3E46", rough=0.5, grain=0.3, grain_scale=70.0, dirt=0.5)

    # passe 3 du 22/10 : façade à 0,50 et corps de ±1,40 (IoU des corps avec E9 et E10 : 0,815 et 0,812)
    tf = 0.42          # façade sud du corps (en retrait ; passe 4 : 0,50 -> 0,42)
    # --- corps à 2 étages ---
    k.box(-1.40, 1.40, -1.3, tf, 0.0, 1.05, brique, "corps", bevel=0.01)
    k.box(-1.43, 1.43, -1.33, tf + 0.03, 0.0, 0.1, fonte, "soubassement", bevel=0.006)
    # assises de briques : joints horizontaux en léger creux sur la façade (relief qui accroche la lumière)
    for i in range(9):
        z = 0.16 + i * 0.1
        if 0.48 < z < 0.58:
            continue
        k.box(-1.39, 1.39, tf, tf + 0.006, z, z + 0.012, joint, "assise_%d" % i, bevel=0)
    k.box(-1.43, 1.43, tf - 0.02, tf + 0.04, 0.50, 0.56, cuivre, "bandeau_etage", bevel=0.004)
    for s in (-1, 1):
        k.box(s * 1.39, s * 1.44, -1.31, tf + 0.02, 0.50, 0.56, cuivre, "bandeau_cote_%d" % s, bevel=0.004)
        k.box(s * 1.30, s * 1.45, tf - 0.1, tf + 0.05, 0.0, 1.08, cuivre, "pilastre_av_%d" % s, bevel=0.006)
        k.box(s * 1.30, s * 1.45, -1.30, -1.2, 0.0, 1.08, cuivre, "pilastre_ar_%d" % s, bevel=0.006)
        k.stud_row(s * 1.31, s * 1.44, tf + 0.05, 0.3, 2, 0.015, laiton, "pilastre_rivets_b_%d" % s)
        k.stud_row(s * 1.31, s * 1.44, tf + 0.05, 0.8, 2, 0.015, laiton, "pilastre_rivets_h_%d" % s)
    k.box(-1.48, 1.48, -1.38, tf + 0.08, 1.02, 1.12, cuivre, "corniche", bevel=0.008)
    k.stud_row(-1.43, 1.43, tf + 0.08, 1.07, 24, 0.013, laiton, "corniche_rivets")
    # toit à quatre pans en ardoise, faîtage de cuivre, lucarnes à fenêtre ambrée (lueur de jour)
    k.prism([(-1.37, -1.27), (1.37, -1.27), (1.37, tf - 0.03), (-1.37, tf - 0.03)], 1.12, 1.76, ardoise, "toit_pans",
            top_poly_game=[(-0.62, -0.42), (0.62, -0.42), (0.62, -0.38), (-0.62, -0.38)], bevel=0.01)
    # rangs d'ardoises (lattes en relief sur le pan avant)
    for j in range(5):
        t = (j + 0.5) / 5
        ty = (tf - 0.03) + (-0.40 - (tf - 0.03)) * t
        z = 1.12 + (1.76 - 1.12) * t
        w = 1.37 + (0.62 - 1.37) * t
        k.box(-w + 0.02, w - 0.02, ty - 0.02, ty + 0.01, z - 0.005, z + 0.014, ardoise, "ardoise_rang_%d" % j, bevel=0)
    k.hcyl("x", -0.66, 0.66, 0, -0.40, 1.765, 0.035, cuivre, "faitage", verts=12, bevel=0)
    for s in (-1, 1):
        x, ty = s * 0.68, 0.18
        k.box(x - 0.17, x + 0.17, ty - 0.22, ty + 0.10, 1.25, 1.55, brique, "lucarne_%d" % s, bevel=0.006)
        k.prism([(x - 0.2, ty - 0.24), (x + 0.2, ty - 0.24), (x + 0.2, ty + 0.13), (x - 0.2, ty + 0.13)], 1.55, 1.70, ardoise,
                "lucarne_toit_%d" % s, top_poly_game=[(x - 0.01, ty - 0.24), (x + 0.01, ty - 0.24), (x + 0.01, ty + 0.13),
                                                        (x - 0.01, ty + 0.13)], bevel=0.004)
        k.box(x - 0.13, x + 0.13, ty + 0.10, ty + 0.115, 1.29, 1.51, cuivre, "lucarne_cadre_%d" % s, bevel=0)
        k.box(x - 0.11, x + 0.11, ty + 0.11, ty + 0.125, 1.31, 1.44, ambre_doux, "lucarne_vitre_%d" % s, bevel=0)

    # --- fenêtres : rang haut éclairé (ambre), rang bas en verre sombre ---
    for x in (-1.08, -0.78, 0.78, 1.08):
        k.box(x - 0.12, x + 0.12, tf, tf + 0.025, 0.60, 0.88, cuivre, "fen_h_cadre_%d" % int((x + 2) * 100), bevel=0.004)
        k.box(x - 0.095, x + 0.095, tf + 0.02, tf + 0.035, 0.625, 0.855, ambre_doux, "fen_h_%d" % int((x + 2) * 100), bevel=0)
        k.box(x - 0.12, x + 0.12, tf, tf + 0.025, 0.14, 0.42, cuivre, "fen_b_cadre_%d" % int((x + 2) * 100), bevel=0.004)
        k.box(x - 0.095, x + 0.095, tf + 0.02, tf + 0.035, 0.165, 0.395, vitre, "fen_b_%d" % int((x + 2) * 100), bevel=0)
        k.box(x - 0.006, x + 0.006, tf + 0.03, tf + 0.04, 0.165, 0.395, cuivre, "fen_b_meneau_%d" % int((x + 2) * 100), bevel=0)

    # --- avant-corps central (en saillie) : porte, imposte en éventail, grand cadran-manomètre ---
    ta = 1.12
    k.box(-0.55, 0.55, tf - 0.05, ta, 0.0, 1.32, brique, "avant_corps", bevel=0.01)
    for i in range(12):
        z = 0.16 + i * 0.1
        if z > 1.25:
            break
        k.box(-0.54, 0.54, ta, ta + 0.006, z, z + 0.012, joint, "ac_assise_%d" % i, bevel=0)
    k.hcyl("y", tf - 0.05, ta, 0.0, 0, 1.32, 0.55, brique, "avant_corps_arc", verts=48, bevel=0.006)
    k.box(-0.6, 0.6, tf - 0.05, ta + 0.03, 1.26, 1.34, cuivre, "avant_corps_corniche", bevel=0.005)
    k.door(-0.25, 0.25, ta, 0.6, laiton, fonte, name="porte_double")
    k.box(-0.006, 0.006, ta + 0.06, ta + 0.08, 0.03, 0.58, laiton, "porte_joint", bevel=0)
    for z in (0.15, 0.45):
        k.stud_row(-0.22, 0.22, ta + 0.08, z, 6, 0.014, laiton, "porte_clous_%d" % int(z * 100))
    k.hcyl("y", ta - 0.005, ta + 0.015, 0.0, 0, 0.64, 0.2, ambre, "imposte", verts=32, bevel=0)
    k.box(-0.24, 0.24, ta - 0.02, ta + 0.03, 0.43, 0.64, brique, "imposte_cache", bevel=0)
    zc, ty_f = 1.06, ta + 0.01
    k.torus(0.0, ty_f + 0.02, zc, 0.31, 0.04, laiton, "cadran_bague", rot=(math.pi / 2, 0, 0), minor_seg=12)
    k.hcyl("y", ty_f - 0.01, ty_f + 0.012, 0.0, 0, zc, 0.29, ambre, "cadran_face", verts=48, bevel=0)
    k.bbox(0.06, ty_f + 0.03, zc + 0.06, 0.2, 0.012, 0.025, fonte, "cadran_aiguille", rot=(0, -0.6, 0), bevel=0)
    k.sphere(0.0, ty_f + 0.03, zc, 0.03, fonte, "cadran_axe", seg=12, rings=6)
    # graduations du cadran (petites barres sombres sur l'ambre)
    gr = []
    for i in range(12):
        a = math.radians(-120 + i * 22)
        px, pz = 0.24 * math.sin(a), zc + 0.24 * math.cos(a)
        gr.append(k.bbox(px, ty_f + 0.016, pz, 0.012, 0.01, 0.05, fonte, "graduation_%d" % i, rot=(0, a, 0), bevel=0))
    k.join(gr, "graduations")
    # marches de l'avant-corps
    for i, (t0, t1, z1) in enumerate(((ta, ta + 0.12, 0.10), (ta + 0.12, ta + 0.24, 0.05))):
        k.box(-0.42, 0.42, t0, t1, 0.0, z1, fonte, "marche_%d" % i, bevel=0.006)

    # --- 2 hautes cheminées rondes à l'arrière ---
    for s in (-1, 1):
        x, ty = s * 0.95, -0.9
        k.cyl(x, ty, 0.27, 1.12, 1.24, fonte, "chem_bride_%d" % s, verts=40)
        k.ring_studs(x, ty, 0.27, 1.18, 8, 0.015, laiton, "chem_bride_boulons_%d" % s)
        k.cyl(x, ty, 0.2, 1.24, 2.42, fonte, "chem_fut_%d" % s, verts=40, r2=0.185)
        k.bands(x, ty, 0.19, (1.5, 1.85, 2.2), cuivre, "chem_cercle_%d" % s, minor=0.022)
        for z in (1.5, 1.85, 2.2):
            k.ring_studs(x, ty, 0.205, z, 7, 0.012, laiton, "chem_rivets_%d_%d" % (s, int(z * 10)))
        k.cyl(x, ty, 0.185, 2.42, 2.55, cuivre, "chem_levre_%d" % s, verts=40, r2=0.24, caps=False)
        k.torus(x, ty, 2.55, 0.24, 0.022, laiton, "chem_bourrelet_%d" % s, minor_seg=10)
        k.cyl(x, ty, 0.18, 2.46, 2.47, fonte, "chem_gueule_%d" % s, verts=40, bevel=0)

    # --- chaudière verticale rivetée hors œuvre (ouest) ---
    bx, bty = -1.50, 0.0
    k.cyl(bx, bty, 0.25, 0.0, 0.12, fonte, "chaudiere_socle", verts=32)
    k.cyl(bx, bty, 0.23, 0.12, 1.42, cuivre, "chaudiere_fut", verts=40)
    k.bands(bx, bty, 0.23, (0.3, 0.7, 1.1), fonte, "chaudiere_cercles", minor=0.02)
    for z in (0.3, 0.7, 1.1):
        k.ring_studs(bx, bty, 0.245, z, 7, 0.012, laiton, "chaudiere_rivets_%d" % int(z * 10))
    k.lathe(bx, bty, [(0.23, 1.42), (0.21, 1.52), (0.15, 1.6), (0.0, 1.64)], cuivre, "chaudiere_dome", segs=32)
    k.cyl(bx, bty, 0.035, 1.6, 1.82, laiton, "chaudiere_soupape", verts=10, role="tige")
    k.sphere(bx, bty, 1.84, 0.04, laiton, "chaudiere_soupape_tete", seg=10, rings=6, role="tige")
    k.hcyl("y", bty + 0.12, bty + 0.2, bx, 0, 0.42, 0.11, fonte, "chaudiere_foyer", verts=20)
    k.hcyl("y", bty + 0.19, bty + 0.21, bx, 0, 0.42, 0.075, ambre, "chaudiere_hublot", verts=20, bevel=0)
    k.hcyl("x", bx + 0.2, -1.37, 0, bty, 1.2, 0.045, cuivre, "chaudiere_conduite", verts=12, bevel=0)

    # --- réservoir d'eau sur pilotis (est) ---
    wx, wty = 1.46, -0.55
    for dx in (-0.12, 0.12):
        for dty in (-0.1, 0.1):
            k.cyl(wx + dx, wty + dty, 0.025, 0.0, 0.92, fonte, "pilotis_%d_%d" % (int(dx * 100), int(dty * 100)), verts=8,
                  role="tige")
    k.cyl(wx, wty, 0.21, 0.92, 1.42, cuivre, "reservoir", verts=32)
    k.ribs(wx, wty, 0.21, 0.92, 1.42, 6, fonte, "reservoir_douelles", w=0.025, d=0.012)
    k.bands(wx, wty, 0.21, (1.0, 1.32), fonte, "reservoir_cercles", minor=0.016)
    k.lathe(wx, wty, [(0.22, 1.42), (0.14, 1.52), (0.0, 1.56)], fonte, "reservoir_toit", segs=32)
    k.hcyl("x", 1.35, wx - 0.15, 0, wty, 0.98, 0.035, cuivre, "reservoir_conduite", verts=12, bevel=0)

    # --- tuyauterie extérieure (cuivre) et vannes ---
    pipes = []
    for s in (-1, 1):
        pipes.append(k.hcyl("x", s * 0.58, s * 1.31, 0, tf + 0.08, 0.95, 0.042, cuivre_p, "tuyau_h_%d" % s, verts=14, bevel=0))
        pipes.append(k.cyl(s * 1.31, tf + 0.08, 0.042, 0.1, 0.95, cuivre_p, "tuyau_v_%d" % s, verts=14, bevel=0))
        pipes.append(k.sphere(s * 1.31, tf + 0.08, 0.95, 0.05, cuivre_p, "tuyau_coude_%d" % s, seg=12, rings=6))
    k.join(pipes, "tuyauterie")
    for s in (-1, 1):
        k.torus(s * 1.0, tf + 0.14, 0.95, 0.07, 0.012, laiton, "vanne_%d" % s, rot=(math.pi / 2, 0, 0), minor_seg=8)
        k.cyl(s * 1.31, tf + 0.08, 0.06, 0.55, 0.62, laiton, "manchon_%d" % s, verts=14, bevel=0)

    # --- régulateur à boules (Watt) sur le toit ---
    k.cyl(1.0, 0.30, 0.02, 1.25, 1.62, laiton, "regulateur_axe", verts=10, bevel=0, role="tige")
    for s in (-1, 1):
        k.sphere(1.0 + s * 0.09, 0.30, 1.5, 0.05, laiton, "regulateur_boule_%d" % s, seg=12, rings=6)

    # --- mât (tige, point le plus haut) et fanion, planté dans le faîtage ---
    k.mast(0.0, -0.40, 1.74, 3.5, 0.026, fonte, "mat")
    k.sphere(0.0, -0.40, 3.52, 0.045, laiton, "mat_pommeau", seg=12, rings=6, role="tige")
    k.flag(0.0, -0.40, 3.42, 0.38, 0.16, fanion, "fanion", side=1)
