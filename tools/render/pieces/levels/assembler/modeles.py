"""Modèles paramétriques des niveaux 2 à 30 de la machine d'assemblage 2 (lot V3, phase 1). S'exécute DANS Blender.

Une fonction par époque (bible docs/DESIGN_EPOQUES.md §5, ligne « Assembleur 2 ») : le niveau impair 2e-1 est la
silhouette de l'époque, le niveau pair 2e ajoute la pièce (module « piece », couche séparée en phase 2).
Le niveau 1 est le sprite vanilla (Q11) : rien à modéliser. Le niveau 2 ne modélise que la pièce de l'époque 1,
posée sur le sprite vanilla et masquée au pixel par son alpha au post-traitement (variante « four » de V0).

Repère : voir kit.py (tuiles de jeu, y vers le sud ; écran y = ty - 0,7071·z). Paramètre t (0 à 1) : phase du
mécanisme animé (32 images en phase 2) ; la phase 1 ne rend que t = 0 (pose de référence, image 0).
"""
import math

from kit import Kit, P, R2, lin  # noqa: F401

TAU = 2.0 * math.pi


# ------------------------------------------------------------------------------------------------
# Aides communes
# ------------------------------------------------------------------------------------------------
def H(K, tx, ty, z, hexcol, frac):
    """Source du halo de nuit (passe halo seulement), fraction `frac` de la puissance du niveau."""
    K.halo(tx, ty, z, hexcol, K.power * frac, radius=0.05)
    K.halo_pts.append((tx, ty, z))


def octo(x0, x1, y0, y1, c):
    """Octogone (plan, tuiles) : rectangle aux coins chanfreinés de c."""
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c),
            (x0, y0 + c)]


def slope_strip(K, x0, x1, a, b, f0, f1, mat, name="fente", off=0.012):
    """Bande (quadrilatère sans épaisseur) posée sur une face inclinée nord-sud : arête de a=(ty, z) à b=(ty, z),
    entre les fractions f0 et f1, de x0 à x1, avancée de `off` tuile vers le sud."""
    def pt(x, f):
        return P(x, a[0] + (b[0] - a[0]) * f + off, a[1] + (b[1] - a[1]) * f + off * 0.5)
    verts = [pt(x0, f0), pt(x1, f0), pt(x1, f1), pt(x0, f1)]
    return K.mesh(verts, [(0, 1, 2, 3)], mat, name, bevel=0)


def flask_profile(Rb, rn, top, base_r=None):
    """Profil (z, r) d'une fiole à fond rond : pied, bulbe sphérique, col droit, lèvre."""
    zc = Rb * 0.92
    pts = [(0.0, base_r or Rb * 0.55)]
    for deg in (-62, -45, -25, 0, 25, 45, 62):
        th = math.radians(deg)
        pts.append((zc + Rb * math.sin(th), Rb * math.cos(th)))
    zneck = zc + math.sqrt(max(Rb * Rb - rn * rn, 0.0))
    pts += [(zneck, rn), (top - 0.07, rn), (top - 0.05, rn * 1.45), (top, rn * 1.45)]
    return pts


def T(v):
    """Vecteur Blender -> coordonnées de jeu (tx, ty, z)."""
    return (v.x, -v.y / R2, v.z)


# ------------------------------------------------------------------------------------------------
# Époque 1 · Pionnier : niveau 1 = vanilla ; niveau 2 = potence de levage en bois avec palan (pièce seule)
# ------------------------------------------------------------------------------------------------
def e01(K, t, piece):
    if not piece:
        return
    K.module = "piece"
    bois = K.metal("e1_bois", "#6B4F35", k=1.55, rough=0.78, metallic=0.0, grain=0.35, grain_scale=28.0, dirt=0.5,
                   seed=11)
    fer = K.metal("e1_fer", "#5A5048", k=1.9, rough=0.45, metallic=0.65, grain=0.2, rust="#6A3418", rust_amount=0.45,
                  dirt=0.4, seed=12)
    corde = K.flat("e1_corde", "#8A7A5A", k=1.1, rough=0.9)
    lampe = K.emit("e1_lanterne", "#FFB060", strength=1.4, base="#4A3A20", night_only=True)
    X, Y = 1.335, -1.02                 # pied du mât : coin arrière droit, hors du corps vanilla (x ≤ 1,28)
    K.box(X - 0.15, X + 0.15, Y - 0.045, Y + 0.045, 0.0, 0.07, bois, "semelle", bevel=0.006)
    K.box(X - 0.045, X + 0.045, Y - 0.15, Y + 0.15, 0.0, 0.07, bois, "semelle", bevel=0.006)
    K.box(X - 0.045, X + 0.045, Y - 0.032, Y + 0.032, 0.0, 1.48, bois, "mat", bevel=0.008)
    K.beam((X + 0.05, Y, 1.41), (0.40, Y, 1.41), 0.07, 0.08, bois, "fleche")
    K.beam((X - 0.02, Y, 0.92), (X - 0.45, Y, 1.39), 0.05, 0.05, bois, "jambe_de_force")
    for z in (0.88, 1.32):
        K.box(X - 0.055, X + 0.055, Y - 0.042, Y + 0.042, z, z + 0.06, fer, "ferrure", bevel=0.004)
    K.box(0.40, 0.52, Y - 0.045, Y + 0.045, 1.36, 1.46, fer, "sabot_fleche", bevel=0.004)
    xp = 0.50
    K.rod((xp, Y - 0.035, 1.32), (xp, Y + 0.035, 1.32), 0.05, fer, "poulie", verts=20)
    K.module = "meca"
    for dx in (-0.045, 0.045):
        K.rod((xp + dx, Y, 1.31), (xp + dx, Y, 1.05), 0.006, corde, "corde")
    K.box(xp - 0.075, xp + 0.075, Y - 0.032, Y + 0.032, 0.94, 1.05, fer, "moufle", bevel=0.006)
    K.torus(xp, Y, 0.89, 0.035, 0.011, fer, "crochet", axis="y")
    K.module = "piece"
    K.box(X - 0.012, X + 0.012, Y, Y + 0.10, 1.17, 1.19, fer, "potence_lanterne", bevel=0)
    K.cyl(X, Y + 0.10, 1.12, 1.165, 0.038, fer, "lanterne_toit", r2=0.012)
    K.cyl(X, Y + 0.10, 1.03, 1.12, 0.042, lampe, "lanterne_verre", verts=16)
    K.cyl(X, Y + 0.10, 1.01, 1.03, 0.047, fer, "lanterne_pied")
    H(K, X - 0.02, Y + 0.16, 1.07, "#FFB060", 1.0)


# ------------------------------------------------------------------------------------------------
# Époque 2 · Forge : caisse rivetée cerclée, volant d'inertie à droite, arbre de transmission au toit
# ------------------------------------------------------------------------------------------------
def e02(K, t, piece):
    acier = K.metal("e2_acier", "#5C6168", k=1.55, rough=0.40, metallic=0.55, grain=0.14, rust="#4A3020",
                    rust_amount=0.22, dirt=0.5, seed=21)
    cercle = K.metal("e2_cerclage", "#2E2C2A", k=1.6, rough=0.45, metallic=0.65, grain=0.2, dirt=0.35, seed=22)
    laiton = K.metal("e2_laiton", "#8C7440", k=2.0, rough=0.26, metallic=0.9, grain=0.1, dirt=0.2, seed=23)
    forge = K.emit("e2_forge", "#FF6A20", strength=1.5, base="#180C06", night_only=True)
    K.module = "corps"
    K.box(-1.22, 1.22, -0.62, 1.40, 0.0, 0.22, cercle, "socle", bevel=0.02)
    K.box(-1.16, 0.70, -0.55, 1.33, 0.22, 1.02, acier, "caisse", bevel=0.025)
    for z in (0.28, 0.92):
        K.box(-1.18, 0.72, -0.57, 1.35, z, z + 0.06, cercle, "cerclage", bevel=0.008)
    for x in (-1.16, 0.70):
        for y in (-0.55, 1.33):
            K.box(x - 0.04, x + 0.04, y - 0.03, y + 0.03, 0.22, 1.04, cercle, "corniere", bevel=0.006)
    for z in (0.31, 0.95):
        K.rivets((-1.12, 1.358, z), (0.66, 1.358, z), 14, 0.017, laiton, "rivets_face")
    K.rivets((-1.182, -0.50, 0.95), (-1.182, 1.28, 0.95), 10, 0.016, laiton, "rivets_flanc")
    K.box(-0.35, 0.30, 1.33, 1.345, 0.40, 0.86, cercle, "porte", bevel=0.006)
    K.box(0.18, 0.24, 1.345, 1.36, 0.58, 0.68, laiton, "poignee", bevel=0)
    for x0 in (-1.04, -0.72):
        for z0 in (0.48, 0.66):
            K.box(x0, x0 + 0.26, 1.332, 1.347, z0, z0 + 0.09, forge, "fente_forge", bevel=0)
    # renvoi d'angle à droite (colonne, deux boîtiers) et palier du volant
    K.box(0.95, 1.11, -0.42, -0.26, 0.22, 1.66, cercle, "colonne_renvoi", bevel=0.01)
    K.box(0.90, 1.16, -0.46, -0.22, 0.58, 0.82, laiton, "renvoi_bas", bevel=0.012)
    K.box(0.90, 1.16, -0.46, -0.22, 1.56, 1.80, laiton, "renvoi_haut", bevel=0.012)
    K.box(0.93, 1.13, 0.95, 1.15, 0.22, 0.80, cercle, "palier_volant", bevel=0.01)
    K.box(0.90, 1.16, 0.92, 1.18, 0.62, 0.82, laiton, "chapeau_palier", bevel=0.01)
    for x in (-0.98, 0.42):
        K.box(x - 0.07, x + 0.07, -0.42, -0.26, 1.02, 1.58, cercle, "pied_palier", bevel=0.008)
        K.box(x - 0.12, x + 0.12, -0.46, -0.22, 1.56, 1.80, laiton, "palier", bevel=0.012)
    K.module = "meca"
    ph = TAU * t
    K.rod((-1.10, -0.34, 1.68), (1.03, -0.34, 1.68), 0.042, acier, "arbre_toit")
    for x, r in ((-0.45, 0.17), (0.05, 0.13)):
        K.rod((x - 0.04, -0.34, 1.68), (x + 0.04, -0.34, 1.68), r, cercle, "poulie", verts=28)
    K.rod((1.03, -0.22, 0.70), (1.03, 1.47, 0.70), 0.038, acier, "arbre_volant")
    K.wheel((1.03, 1.40, 0.70), "y", 0.42, 0.08, 6, acier, cercle, "volant", phase=ph)
    H(K, -0.75, 1.62, 0.62, "#FF6A20", 1.0)
    if piece:
        K.module = "piece"
        for x in (-0.66, -0.06):
            K.box(x - 0.045, x + 0.045, -0.02, 0.12, 1.02, 2.38, acier, "montant_pilon", bevel=0.008)
        K.box(-0.74, 0.02, -0.06, 0.16, 2.30, 2.46, cercle, "traverse_pilon", bevel=0.012)
        K.cyl(-0.36, 0.05, 2.46, 2.72, 0.12, laiton, "cylindre_pilon", verts=28)
        K.cyl(-0.36, 0.05, 2.72, 2.77, 0.14, cercle, "chapeau_cylindre", verts=28)
        K.rod((-0.36, 0.05, 1.85), (-0.36, 0.05, 2.46), 0.03, acier, "tige_pilon")
        K.box(-0.56, -0.16, -0.04, 0.14, 1.55, 1.86, cercle, "mouton", bevel=0.015)
        K.box(-0.60, -0.12, -0.08, 0.18, 1.02, 1.20, cercle, "enclume", bevel=0.015)
        K.rivets((-0.54, 0.145, 1.80), (-0.18, 0.145, 1.80), 5, 0.014, laiton, "rivets_mouton")


# ------------------------------------------------------------------------------------------------
# Époque 3 · Vapeur : bâti de fonte, chaudière, machine à vapeur horizontale, cheminée ronde, manomètres
# ------------------------------------------------------------------------------------------------
def e03(K, t, piece):
    fonte = K.metal("e3_fonte", "#3A3634", k=1.9, rough=0.55, metallic=0.5, grain=0.22, rust="#5A2E18",
                    rust_amount=0.3, dirt=0.5, seed=31)
    cuivre = K.metal("e3_cuivre", "#8A5A3A", k=1.45, rough=0.32, metallic=0.85, grain=0.14, rust="#3E5A48",
                     rust_amount=0.18, rust_scale=7.0, dirt=0.45, seed=32)
    laiton = K.metal("e3_laiton", "#9C7E45", k=1.7, rough=0.25, metallic=0.9, grain=0.1, dirt=0.25, seed=33)
    acier = K.metal("e3_acier", "#5C6168", k=1.5, rough=0.35, metallic=0.7, grain=0.12, dirt=0.3, seed=34)
    suie = K.flat("e3_suie", "#0A0908", rough=0.95)
    cuir = K.flat("e3_courroie", "#3A2A1E", rough=0.8)
    ambre = K.emit("e3_ambre", "#FFC060", strength=1.3, base="#3A2810")
    K.module = "corps"
    bot = [(-1.26, -0.62), (1.26, -0.62), (1.26, 1.42), (-1.26, 1.42)]
    top = [(-1.20, -0.56), (1.20, -0.56), (1.20, 1.30), (-1.20, 1.30)]
    K.prism(bot, 0.0, 0.70, fonte, "bati", top=top, bevel=0.02)
    K.box(-1.24, 1.24, 1.30, 1.36, 0.50, 0.58, cuivre, "bandeau", bevel=0.006)
    K.rivets((-1.18, 1.37, 0.54), (1.18, 1.37, 0.54), 18, 0.016, laiton, "rivets_bandeau")
    # porte du foyer : hublot ambré
    K.rod((-0.62, 1.33, 0.32), (-0.62, 1.40, 0.32), 0.16, laiton, "cadre_hublot", verts=32)
    K.rod((-0.62, 1.39, 0.32), (-0.62, 1.415, 0.32), 0.12, ambre, "hublot", verts=32)
    # chaudière horizontale rivetée, sur deux selles
    for x in (-0.35, 0.75):
        K.box(x - 0.09, x + 0.09, -0.48, -0.02, 0.70, 0.86, fonte, "selle", bevel=0.01)
    K.lathe((-0.62, -0.25, 1.06), [(0, 0.0), (0.02, 0.22), (0.08, 0.32), (0.16, 0.345), (1.50, 0.345), (1.58, 0.32),
                                    (1.64, 0.22), (1.66, 0.0)], cuivre, "chaudiere", verts=40, axis=(1, 0, 0))
    for x in (-0.30, 0.20, 0.70):
        K.torus(x, -0.25, 1.06, 0.35, 0.018, laiton, "cercle_chaudiere", axis="x")
    K.cyl(0.25, -0.25, 1.30, 1.52, 0.11, cuivre, "dome_vapeur")
    K.sphere(0.25, -0.25, 1.52, 0.11, cuivre, "calotte")
    K.cyl(0.25, -0.25, 1.60, 1.70, 0.03, laiton, "soupape")
    K.sphere(0.25, -0.25, 1.71, 0.035, laiton, "soupape_bille")
    for x in (0.12, 0.60):
        K.rod((x, -0.03, 1.06), (x, 0.02, 1.06), 0.09, laiton, "manometre", verts=28)
        K.rod((x, 0.02, 1.06), (x, 0.032, 1.06), 0.072, ambre, "cadran", verts=28)
    # cheminée ronde à collerette
    K.lathe((-0.85, -0.38, 0.70), [(0, 0.19), (0.08, 0.19), (0.10, 0.13), (1.15, 0.12), (1.17, 0.17), (1.27, 0.17),
                                    (1.29, 0.14)], fonte, "cheminee", verts=36, cap1=False)
    K.cyl(-0.85, -0.38, 1.80, 1.82, 0.135, suie, "suie")
    K.torus(-0.85, -0.38, 1.20, 0.125, 0.015, laiton, "cercle_cheminee")
    # tuyauterie de cuivre : dôme -> cylindre
    K.tube([(0.25, -0.25, 1.45), (0.25, 0.05, 1.45), (-0.25, 0.30, 1.28), (-0.70, 0.50, 1.24)], 0.035, cuivre,
           "tuyau_vapeur")
    K.module = "meca"
    ph = TAU * t
    K.box(-1.05, -0.32, 0.42, 0.68, 0.70, 0.80, fonte, "berceau", bevel=0.01)
    K.lathe((-1.06, 0.55, 1.00), [(0, 0.0), (0.0, 0.20), (0.06, 0.22), (0.66, 0.22), (0.72, 0.20), (0.72, 0.0)],
            cuivre, "cylindre_vapeur", verts=32, axis=(1, 0, 0))
    for x in (-1.0, -0.40):
        K.torus(x, 0.55, 1.00, 0.222, 0.016, laiton, "bride_cylindre", axis="x")
    K.rod((-0.34, 0.55, 1.00), (0.12, 0.55, 1.00), 0.03, acier, "tige_piston")
    for z in (0.92, 1.08):
        K.box(-0.20, 0.30, 0.46, 0.64, z - 0.015, z + 0.015, acier, "glissiere", bevel=0)
    K.box(0.06, 0.18, 0.47, 0.63, 0.93, 1.07, laiton, "crosse", bevel=0.008)
    cx, cz, cr = 0.72, 1.12, 0.14
    pin = (cx + cr * math.cos(ph + 2.4), 0.55, cz + cr * math.sin(ph + 2.4))
    K.rod((0.12, 0.55, 1.00), pin, 0.026, acier, "bielle")
    K.rod((cx, 0.30, cz), (cx, 1.34, cz), 0.04, acier, "arbre_manivelle")
    K.rod((cx, 0.51, cz), (cx, 0.59, cz), 0.19, fonte, "plateau_manivelle", verts=32)
    for y in (0.36, 0.95):
        K.box(cx - 0.08, cx + 0.08, y - 0.06, y + 0.06, 0.70, cz + 0.06, fonte, "palier", bevel=0.01)
    K.wheel((cx, 1.22, cz), "y", 0.38, 0.07, 6, fonte, acier, "volant", phase=ph)
    K.rod((cx, 1.29, cz), (cx, 1.35, cz), 0.12, laiton, "poulie_haute", verts=28)
    K.rod((cx, 1.37, 0.30), (cx, 1.43, 0.30), 0.12, laiton, "poulie_basse", verts=28)
    for dx in (-0.12, 0.12):
        K.beam((cx + dx, 1.32, cz), (cx + dx, 1.41, 0.30), 0.014, 0.05, cuir, "courroie")
    H(K, -0.62, 1.55, 0.32, "#FFC060", 0.55)
    H(K, 0.36, 0.12, 1.10, "#FFC060", 0.45)
    if piece:
        K.module = "piece"
        gx, gy = 0.62, -0.25
        K.cyl(gx, gy, 1.36, 1.50, 0.10, fonte, "socle_regulateur")
        K.cyl(gx, gy, 1.50, 2.08, 0.075, laiton, "colonne_regulateur")
        K.rod((gx, gy, 2.08), (gx, gy, 2.62), 0.018, acier, "broche")
        K.cyl(gx, gy, 2.60, 2.68, 0.05, laiton, "chapeau_regulateur", r2=0.02)
        K.cyl(gx, gy, 2.24, 2.32, 0.06, laiton, "manchon")
        for s in (-1, 1):
            ball = (gx + s * 0.24, gy, 2.22)
            K.rod((gx, gy, 2.56), ball, 0.012, acier, "bras_boule")
            K.rod((gx, gy, 2.30), (gx + s * 0.13, gy, 2.36), 0.009, acier, "biellette")
            K.sphere(ball[0], ball[1], ball[2], 0.085, laiton, "boule")


# ------------------------------------------------------------------------------------------------
# Époque 4 · Pétrole : presse hydraulique (portique jaune, vérin), cuves latérales, garde-corps
# ------------------------------------------------------------------------------------------------
def e04(K, t, piece):
    jaune = K.metal("e4_jaune", "#8C7A3A", k=1.6, rough=0.5, metallic=0.25, grain=0.18, rust="#4A3A28",
                    rust_amount=0.25, dirt=0.5, seed=41)
    galva = K.metal("e4_galva", "#6E7378", k=1.55, rough=0.38, metallic=0.75, grain=0.22, grain_scale=80.0,
                    dirt=0.4, seed=42)
    noir = K.metal("e4_noir", "#1E1E1E", k=1.5, rough=0.5, metallic=0.3, grain=0.15, dirt=0.3, seed=43)
    chrome = K.metal("e4_tige", "#B8BCC0", k=1.2, rough=0.15, metallic=1.0, grain=0.05, dirt=0.0, seed=44)
    orange = K.emit("e4_voyant", "#FF8C1A", strength=1.4, base="#3A2008")
    K.module = "corps"
    K.box(-0.98, 0.98, -0.66, 1.40, 0.0, 0.92, galva, "caisson", bevel=0.02)
    for i in range(10):
        x0 = -0.98 + i * 0.196
        K.box(x0, x0 + 0.196, 1.40, 1.415, 0.04, 0.20, jaune if i % 2 == 0 else noir, "bande_danger", bevel=0)
    K.box(0.30, 0.84, 1.40, 1.42, 0.38, 0.80, noir, "panneau", bevel=0.006)
    for x in (0.38, 0.62):
        K.box(x, x + 0.15, 1.42, 1.432, 0.54, 0.74, orange, "voyant", bevel=0)
    # cuves latérales horizontales (axe nord-sud) ; à droite, plus courte (place de la cuve de pression)
    Lg, Lc = 2.45, 1.62
    for s, start, L in ((-1, 1.22, Lg), (1, 0.62, Lc)):
        x = s * 1.06
        prof = [(0, 0), (0.03, 0.15), (0.10, 0.24), (0.22, 0.28), (L - 0.22, 0.28), (L - 0.10, 0.24),
                (L - 0.03, 0.15), (L, 0)]
        K.lathe((x, start, 0.38), prof, jaune, "cuve_laterale", verts=36, axis=(0, 1, 0))
        yb = start - L / R2
        for f in (0.25, 0.75):
            yy = start + (yb - start) * f
            K.torus(x, yy, 0.38, 0.285, 0.022, noir, "bande_cuve", axis="y")
            K.box(x - 0.20, x + 0.20, yy - 0.06, yy + 0.06, 0.0, 0.16, galva, "selle", bevel=0.01)
    # garde-corps sur le toit
    posts = [(-0.92, 1.34), (-0.31, 1.34), (0.31, 1.34), (0.92, 1.34), (-0.92, 0.40), (0.92, 0.40), (-0.92, -0.60),
             (0.92, -0.60)]
    for x, y in posts:
        K.cyl(x, y, 0.92, 1.24, 0.014, jaune, "poteau_garde_corps", verts=8, bevel=0)
    for z in (1.08, 1.24):
        K.rod((-0.92, 1.34, z), (0.92, 1.34, z), 0.012, jaune, "lisse", verts=8)
        for s in (-1, 1):
            K.rod((s * 0.92, 1.34, z), (s * 0.92, -0.60, z), 0.012, jaune, "lisse", verts=8)
    # portique
    for s in (-1, 1):
        K.box(s * 0.68 - 0.07, s * 0.68 + 0.07, -0.30, -0.14, 0.92, 2.00, jaune, "montant_portique", bevel=0.01)
        K.box(s * 0.68 - 0.075, s * 0.68 + 0.075, -0.14, -0.125, 1.66, 1.86, orange, "voyant_portique", bevel=0)
    K.box(-0.86, 0.86, -0.34, -0.10, 1.90, 2.14, jaune, "traverse_portique", bevel=0.015)
    K.box(-0.86, 0.86, -0.10, -0.095, 1.95, 2.09, noir, "bande_traverse", bevel=0)
    K.module = "meca"
    K.cyl(0.0, -0.22, 1.42, 1.90, 0.15, galva, "verin", verts=32)
    K.torus(0.0, -0.22, 1.50, 0.152, 0.016, noir, "bague_verin")
    K.cyl(0.0, -0.22, 1.12, 1.44, 0.065, chrome, "tige_verin")
    K.box(-0.30, 0.30, -0.42, -0.02, 0.98, 1.14, noir, "tete_presse", bevel=0.012)
    K.box(-0.40, 0.40, -0.48, 0.08, 0.92, 0.98, galva, "matrice", bevel=0.008)
    for s in (-1, 1):
        K.tube([(s * 1.06, -0.30, 0.66), (s * 0.95, -0.28, 1.55), (s * 0.40, -0.24, 1.86), (s * 0.15, -0.22, 1.86)],
               0.024, noir, "flexible")
    H(K, 0.57, 1.58, 0.64, "#FF8C1A", 0.5)
    for s in (-1, 1):
        H(K, s * 0.68, 0.02, 1.76, "#FF8C1A", 0.25)
    if piece:
        K.module = "piece"
        X, Y = 1.24, 1.00
        K.lathe((X, Y, 0.0), [(0, 0.23), (0.10, 0.23), (0.12, 0.21), (1.20, 0.21), (1.32, 0.17), (1.40, 0.10),
                               (1.43, 0.0)], jaune, "cuve_pression", verts=36)
        for z in (0.35, 0.95):
            K.torus(X, Y, z, 0.212, 0.02, noir, "bande_cuve_pression")
        K.rod((X, Y + 0.13, 0.72), (X, Y + 0.17, 0.72), 0.075, galva, "manometre", verts=24)
        K.rod((X, Y + 0.17, 0.72), (X, Y + 0.18, 0.72), 0.06, orange, "cadran", verts=24)
        K.cyl(X, Y, 1.43, 1.52, 0.03, galva, "vanne")
        K.torus(X, Y, 1.54, 0.065, 0.012, noir, "volant_vanne")
        K.tube([(X - 0.18, Y, 0.95), (1.06, Y - 0.05, 0.95), (1.06, 0.55, 0.62)], 0.03, galva, "conduite")
        H(K, X, Y + 0.30, 0.72, "#FF8C1A", 0.2)


# ------------------------------------------------------------------------------------------------
# Époque 5 · Volcan : presse blindée en gradins (tronc de pyramide), capot incliné, fente de marteau
# ------------------------------------------------------------------------------------------------
def e05(K, t, piece):
    tung = K.metal("e5_tungstene", "#3E3D42", k=1.9, rough=0.38, metallic=0.75, grain=0.2, rust="#5A3A2A",
                   rust_amount=0.35, dirt=0.55, seed=51)
    rouille = K.metal("e5_rouille", "#5A3A2A", k=1.5, rough=0.6, metallic=0.4, grain=0.3, dirt=0.4, seed=52)
    rivet = K.metal("e5_rivet", "#6A6870", k=1.8, rough=0.3, metallic=0.9, grain=0.08, dirt=0.2, seed=53)
    basalte = K.metal("e5_basalte", "#2A2826", k=1.6, rough=0.75, metallic=0.1, grain=0.4, grain_scale=20.0,
                      dirt=0.4, seed=54)
    braise = K.emit("e5_braise", "#FF4A10", strength=1.5, base="#200804")
    K.module = "corps"
    tiers = [(0.00, 0.45, (1.30, -0.92, 1.42), (1.14, -0.79, 1.24)),
             (0.42, 0.88, (1.17, -0.80, 1.27), (0.99, -0.66, 1.04)),
             (0.85, 1.30, (1.02, -0.68, 1.08), (0.82, -0.52, 0.85))]
    for i, (z0, z1, (bx, by0, by1), (tx_, ty0, ty1)) in enumerate(tiers):
        bot = [(-bx, by0), (bx, by0), (bx, by1), (-bx, by1)]
        top = [(-tx_, ty0), (tx_, ty0), (tx_, ty1), (-tx_, ty1)]
        K.prism(bot, z0, z1, tung, "gradin", top=top, bevel=0.02)
        K.rivets((-bx + 0.10, by1 + 0.01, z0 + 0.05), (bx - 0.10, by1 + 0.01, z0 + 0.05), 9, 0.028, rivet,
                 "rivets_lourds")
        for x0, x1 in ((-0.75, -0.35), (-0.18, 0.18), (0.35, 0.75)):
            slope_strip(K, x0 * bx / 1.3, x1 * bx / 1.3, (by1, z0), (ty1, z1), 0.42, 0.66, braise, "fente_braise")
    hb = [(-0.64, -0.46), (0.64, -0.46), (0.64, 0.72), (-0.64, 0.72)]
    ht = [(-0.50, -0.40), (0.50, -0.40), (0.50, -0.02), (-0.50, -0.02)]
    K.prism(hb, 1.30, 2.22, tung, "capot", top=ht, bevel=0.02)
    slope_strip(K, -0.36, 0.36, (0.72, 1.30), (-0.02, 2.22), 0.36, 0.56, braise, "fente_marteau")
    for s in (-1, 1):
        K.cyl(s * 0.68, -0.50, 1.30, 2.20, 0.12, basalte, "pointe_basalte", verts=7, r2=0.01)
    K.module = "meca"
    K.cyl(0.0, -0.21, 2.20, 2.34, 0.13, rouille, "piston_marteau", verts=8)
    K.cyl(0.0, -0.21, 2.34, 2.40, 0.16, tung, "tete_piston", verts=8)
    H(K, 0.0, 1.62, 0.50, "#FF4A10", 0.6)
    H(K, 0.0, 0.85, 1.75, "#FF4A10", 0.4)
    if piece:
        K.module = "piece"
        for s in (-1, 1):
            for y0, y1 in ((0.10, 0.62), (-0.74, -0.26)):
                poly = [(s * 1.04, 0.0), (s * 1.47, 0.0), (s * 1.47, 0.14), (s * 1.06, 1.10)]
                K.plate(poly, y0, y1, rouille, "contrefort", bevel=0.012)
                K.rivets((s * 1.44, y1 + 0.01, 0.07), (s * 1.12, y1 + 0.01, 0.95), 4, 0.022, rivet, "rivets_contrefort")


# ------------------------------------------------------------------------------------------------
# Époque 6 · Électricité : bras de soudure à l'arc, piles d'isolateurs sur bobines aux quatre coins
# ------------------------------------------------------------------------------------------------
def e06(K, t, piece):
    cera = K.metal("e6_ceramique", "#D8D4C8", k=0.95, rough=0.35, metallic=0.0, grain=0.12, dirt=0.55, rust="#8A7A5A",
                   rust_amount=0.2, seed=61)
    cuivre = K.metal("e6_cuivre", "#B0703A", k=1.25, rough=0.3, metallic=0.9, grain=0.15, dirt=0.4, seed=62)
    acier = K.metal("e6_acier", "#5C6168", k=1.5, rough=0.4, metallic=0.6, grain=0.14, dirt=0.45, seed=63)
    noir = K.metal("e6_noir", "#202022", k=1.4, rough=0.5, metallic=0.2, dirt=0.3, seed=64)
    cyan = K.emit("e6_arc", "#60D0FF", strength=1.6, base="#102030")
    K.module = "corps"
    K.box(-1.06, 1.06, -0.66, 1.44, 0.0, 0.10, noir, "plinthe", bevel=0.01)
    K.box(-1.02, 1.02, -0.62, 1.40, 0.10, 0.88, acier, "caisson", bevel=0.02)
    K.box(-0.62, 0.62, 1.40, 1.415, 0.30, 0.76, noir, "panneau", bevel=0.006)
    for x in (-0.42, -0.14, 0.14, 0.42):
        K.box(x - 0.075, x + 0.075, 1.415, 1.425, 0.44, 0.64, cyan, "voyant", bevel=0)
    for (x, y, zc, ztop) in ((-1.12, -0.52, 0.95, 2.18), (1.12, -0.52, 0.95, 2.18), (-1.12, 1.16, 0.62, 1.22),
                             (1.12, 1.16, 0.62, 1.22)):
        K.cyl(x, y, 0.0, 0.08, 0.22, noir, "socle_bobine")
        K.cyl(x, y, 0.08, zc, 0.185, cuivre, "bobine", verts=32)
        rings = []
        z = 0.14
        while z < zc - 0.03:
            rings.append(K.torus(x, y, z, 0.19, 0.016, cuivre, "spire", minor_seg=8, major_seg=40))
            z += 0.07
        K.join(rings, "spires")
        z = zc
        disc = True
        while z < ztop - 0.04:
            h = 0.05 if disc else 0.06
            K.cyl(x, y, z, z + h, 0.17 if disc else 0.085, cera, "isolateur" if disc else "ame", verts=28)
            z += h
            disc = not disc
        K.sphere(x, y, ztop, 0.075, cuivre, "borne")
    K.module = "meca"
    K.cyl(0.0, 0.30, 0.88, 1.08, 0.24, noir, "tourelle_bras")
    K.cyl(0.0, 0.30, 1.08, 1.20, 0.15, acier, "base_epaule")
    sh, el, wr, tip = (0.0, 0.30, 1.24), (-0.25, -0.15, 2.02), (0.30, 0.50, 1.62), (0.38, 0.62, 1.22)
    K.sphere(*sh, 0.11, acier, "epaule")
    K.beam(sh, el, 0.13, 0.13, acier, "bras")
    K.rod((el[0] - 0.09, el[1], el[2]), (el[0] + 0.09, el[1], el[2]), 0.09, noir, "coude")
    K.beam(el, wr, 0.10, 0.10, acier, "avant_bras")
    K.sphere(*wr, 0.07, noir, "poignet")
    K.rod(wr, tip, 0.045, cuivre, "torche", r2=0.014)
    K.sphere(tip[0], tip[1], tip[2] - 0.02, 0.065, cyan, "arc_soudure")
    for a in (0.3, 1.5, 2.6, 4.0, 5.2):
        K.rod((tip[0], tip[1], tip[2] - 0.02), (tip[0] + 0.16 * math.cos(a), tip[1] + 0.09 * math.sin(a),
                                                tip[2] - 0.06 + 0.05 * math.sin(2 * a)), 0.008, cyan, "etincelle")
    K.box(0.15, 0.62, 0.45, 0.80, 0.88, 0.94, acier, "piece_soudee", bevel=0.004)
    K.tube([(0.0, 0.30, 1.10), (-0.30, 0.10, 1.30), (-0.30, -0.05, 1.85), (0.05, 0.25, 1.85), (0.32, 0.52, 1.66)],
           0.016, noir, "cable")
    H(K, tip[0], tip[1] + 0.12, tip[2], "#60D0FF", 0.55)
    H(K, 0.0, 1.62, 0.55, "#60D0FF", 0.3)
    if piece:
        K.module = "piece"
        cx, cy, cz = 0.0, -0.28, 2.32
        z = 0.88
        disc = True
        while z < 1.74:
            h = 0.05 if disc else 0.06
            K.cyl(cx, cy, z, z + h, 0.15 if disc else 0.075, cera, "isolateur_anneau" if disc else "ame", verts=28)
            z += h
            disc = not disc
        K.torus(cx, cy, cz, 0.50, 0.075, cuivre, "anneau_bobine", axis="y", minor_seg=14)
        K.torus(cx, cy, cz, 0.50, 0.082, noir, "ligature", axis="y", major_seg=16, minor_seg=6)
        K.torus(cx, cy + 0.02, cz, 0.405, 0.022, cyan, "anneau_lumineux", axis="y")
        H(K, cx, cy + 0.4, cz - 0.3, "#60D0FF", 0.15)


# ------------------------------------------------------------------------------------------------
# Époque 7 · Cristal : corps bas de pierre cerclé de bronze, couronne de cristaux asymétriques
# ------------------------------------------------------------------------------------------------
def e07(K, t, piece):
    pierre = K.metal("e7_pierre", "#4A4038", k=1.6, rough=0.85, metallic=0.0, grain=0.35, grain_scale=18.0, dirt=0.5,
                     seed=71)
    bronze = K.metal("e7_bronze", "#6A5236", k=1.8, rough=0.3, metallic=0.9, grain=0.14, rust="#3E6A55",
                     rust_amount=0.25, dirt=0.45, seed=72)
    cristal = K.metal("e7_cristal", "#9A5CFF", k=0.9, rough=0.12, metallic=0.0, grain=0.06, dirt=0.15, seed=73)
    lum = K.emit("e7_cristal_lumineux", "#B070FF", strength=1.1, base="#6A3AC0")
    K.module = "corps"
    bot = [(-1.30, -0.82), (1.30, -0.82), (1.30, 1.42), (-1.30, 1.42)]
    top = [(-1.22, -0.74), (1.22, -0.74), (1.22, 1.32), (-1.22, 1.32)]
    K.prism(bot, 0.0, 0.55, pierre, "corps_pierre", top=top, bevel=0.03)
    K.box(-1.24, 1.24, -0.76, 1.34, 0.50, 0.58, bronze, "bandeau", bevel=0.01)
    for x in (-1.26, 1.26):
        for y in (-0.78, 1.38):
            K.box(x - 0.05, x + 0.05, y - 0.04, y + 0.04, 0.0, 0.58, bronze, "montant", bevel=0.008)
    K.cyl(0.0, 0.25, 0.55, 0.72, 0.80, bronze, "sertissure", verts=8)
    crystals = [  # angle (deg), rayon, hauteur, rayon du cristal, inclinaison vers l'extérieur (deg), lumineux
        (100, 0.55, 2.45, 0.14, 10, True), (140, 0.60, 1.70, 0.12, 20, False), (62, 0.60, 1.90, 0.12, 16, False),
        (182, 0.64, 1.20, 0.11, 26, True), (20, 0.64, 1.40, 0.11, 24, False), (222, 0.62, 0.95, 0.10, 30, False),
        (318, 0.60, 1.05, 0.10, 30, True), (262, 0.56, 0.80, 0.09, 32, False), (290, 0.30, 0.70, 0.08, 12, False)]
    for i, (a, rad, h, r, tilt, lit) in enumerate(crystals):
        ar = math.radians(a)
        x, y = rad * math.cos(ar), 0.25 - rad * math.sin(ar) / R2
        tr = math.radians(tilt)
        K.crystal((x, y, 0.64), h, r, lum if lit else cristal, "cristal",
                  tilt=(tr * math.cos(ar), -tr * math.sin(ar)), spin=0.37 * i)
    K.module = "meca"
    K.cyl(0.0, 0.25, 0.72, 1.05, 0.06, bronze, "axe_tourniquet")
    K.torus(0.0, 0.25, 1.02, 0.38, 0.025, bronze, "anneau_tourniquet")
    for k in range(3):
        a = TAU * k / 3 + TAU * t
        K.rod((0.0, 0.25, 1.02), (0.38 * math.cos(a), 0.25 - 0.38 * math.sin(a) / R2, 1.02), 0.018, bronze, "rayon")
    K.crystal((0.0, 0.25, 1.05), 0.30, 0.06, lum, "focale", spin=0.2)
    H(K, 0.0, 0.70, 1.20, "#B070FF", 0.6)
    H(K, -0.45, 0.05, 1.50, "#B070FF", 0.4)
    if piece:
        K.module = "piece"
        K.cyl(0.0, 0.12, 0.72, 0.86, 0.27, bronze, "collier_grand_cristal", verts=8)
        K.crystal((0.0, 0.12, 0.80), 3.20, 0.24, lum, "grand_cristal", tilt=(0.04, -0.05), spin=0.5)
        H(K, 0.0, 0.5, 2.2, "#B070FF", 0.2)


# ------------------------------------------------------------------------------------------------
# Époque 8 · Marais : corps arrondi vert-de-gris, trois fioles-réacteurs bouillonnantes, conduits
# ------------------------------------------------------------------------------------------------
def e08(K, t, piece):
    vdg = K.metal("e8_vert_de_gris", "#4F6B5A", k=1.55, rough=0.45, metallic=0.5, grain=0.22, rust="#2E4038",
                  rust_amount=0.3, dirt=0.5, seed=81)
    cuivre = K.metal("e8_cuivre", "#8A5A3A", k=1.5, rough=0.3, metallic=0.85, grain=0.12, rust="#4F6B5A",
                     rust_amount=0.35, dirt=0.4, seed=82)
    caout = K.flat("e8_caoutchouc", "#2A2A28", k=1.3, rough=0.7)
    liquide = K.emit("e8_liquide", "#A8FF3A", strength=1.1, base="#4A7A20")
    K.module = "corps"
    K.rbox(-1.20, 1.20, -0.62, 1.40, 0.0, 0.78, vdg, "coque", r=0.16)
    K.rbox(-1.22, 1.22, -0.64, 1.42, 0.10, 0.17, cuivre, "ceinture", r=0.06)
    K.rod((0.0, 1.36, 0.42), (0.0, 1.43, 0.42), 0.22, cuivre, "cadre_hublot", verts=32)
    K.rod((0.0, 1.42, 0.42), (0.0, 1.445, 0.42), 0.17, liquide, "hublot", verts=32)
    K.module = "meca"
    flasks = [(-0.78, -0.30, 0.34, 2.12), (0.78, -0.30, 0.34, 2.12), (0.0, 0.66, 0.30, 1.45)]
    for i, (x, y, Rb, top) in enumerate(flasks):
        K.cyl(x, y, 0.72, 0.84, Rb * 0.72, cuivre, "collier_fiole")
        glass = K.emit_below("e8_verre_%d" % i, "#4A6A28", "#A8FF3A", level=Rb * 0.92, strength=1.0)
        K.lathe((x, y, 0.78), flask_profile(Rb, 0.085, top), glass, "fiole", verts=36)
        K.torus(x, y, 0.78 + top - 0.30, 0.10, 0.02, cuivre, "bague_col")
        K.tube([(x, y, 0.78 + top - 0.32), (x * 1.25, y + 0.25, 0.78 + top - 0.55), (x * 1.32, y + 0.55, 0.95)],
               0.024, caout, "condenseur")
        H(K, x, y + 0.3, 0.78 + Rb, "#A8FF3A", 0.28)
    K.tube([(-0.78, -0.30, 0.86), (0.0, 0.66, 0.86), (0.78, -0.30, 0.86)], 0.035, cuivre, "conduit_fioles")
    H(K, 0.0, 1.62, 0.42, "#A8FF3A", 0.16)
    if piece:
        K.module = "piece"
        K.cyl(0.0, -0.05, 0.78, 1.00, 0.20, cuivre, "pied_bulbe")
        glass = K.emit_below("e8_verre_grand", "#4A6A28", "#A8FF3A", level=0.46 * 0.92, strength=1.0)
        K.lathe((0.0, -0.05, 0.98), flask_profile(0.46, 0.10, 2.65, base_r=0.20), glass, "grand_bulbe", verts=40)
        pts = []
        for i in range(85):
            f = i / 84.0
            a = TAU * 3.5 * f
            pts.append((0.50 * math.cos(a), -0.05 - 0.50 * math.sin(a) / R2, 1.02 + 0.80 * f))
        K.tube(pts, 0.022, cuivre, "serpentin")
        H(K, 0.0, 0.3, 1.4, "#A8FF3A", 0.2)


# ------------------------------------------------------------------------------------------------
# Époque 9 · Atome : cellule chaude plombée octogonale, hublot vert, deux bras télémanipulateurs
# ------------------------------------------------------------------------------------------------
def e09(K, t, piece):
    plomb = K.metal("e9_plomb", "#4A5058", k=1.7, rough=0.45, metallic=0.6, grain=0.16, dirt=0.55, rust="#3A3E36",
                    rust_amount=0.2, seed=91)
    jaune = K.metal("e9_jaune", "#C9A227", k=1.05, rough=0.5, metallic=0.1, grain=0.18, dirt=0.5, rust="#4A3A20",
                    rust_amount=0.2, seed=92)
    beton = K.metal("e9_beton", "#7A7670", k=1.15, rough=0.9, metallic=0.0, grain=0.3, grain_scale=25.0, dirt=0.4,
                    seed=93)
    noir = K.flat("e9_noir", "#1A1A1A", rough=0.6)
    vert = K.emit("e9_uranium", "#5CFF4A", strength=1.3, base="#1A4A14")
    K.module = "corps"
    K.prism(octo(-1.34, 1.34, -0.90, 1.44, 0.40), 0.0, 0.16, beton, "socle_beton")
    K.prism(octo(-1.28, 1.28, -0.86, 1.40, 0.38), 0.16, 1.05, plomb, "cellule")
    K.prism(octo(-1.28, 1.28, -0.86, 1.40, 0.38), 1.05, 1.32, plomb, "chanfrein",
            top=octo(-1.04, 1.04, -0.64, 1.16, 0.30))
    for i in range(9):
        x0 = -0.90 + i * 0.20
        K.box(x0, x0 + 0.20, 1.40, 1.412, 0.20, 0.34, jaune if i % 2 == 0 else noir, "bande_danger", bevel=0)
    K.torus(0.15, 1.41, 0.68, 0.26, 0.05, jaune, "cadre_hublot", axis="y")
    K.rod((0.15, 1.38, 0.68), (0.15, 1.42, 0.68), 0.24, vert, "hublot", verts=40)
    K.rod((-0.58, 1.40, 0.68), (-0.58, 1.415, 0.68), 0.14, jaune, "trefle_fond", verts=28)
    for k in range(3):
        a = math.pi / 2 + TAU * k / 3
        K.rod((-0.58 + 0.035 * math.cos(a), 1.418, 0.68 + 0.035 * math.sin(a)),
              (-0.58 + 0.12 * math.cos(a), 1.418, 0.68 + 0.12 * math.sin(a)), 0.035, noir, "trefle_pale", r2=0.055)
    K.rod((-0.58, 1.415, 0.68), (-0.58, 1.42, 0.68), 0.025, noir, "trefle_centre")
    slope_strip(K, -0.55, 0.55, (1.40, 1.05), (1.16, 1.32), 0.28, 0.72, vert, "event_vert")
    K.module = "meca"
    for s in (-1, 1):
        bx, by = s * 0.55, -0.20
        K.cyl(bx, by, 1.32, 1.80, 0.15, plomb, "colonne_manipulateur", verts=8)
        K.cyl(bx, by, 1.80, 1.86, 0.17, jaune, "collier", verts=8)
        sh, el, wr = (bx, by, 1.95), (s * 0.82, -0.38, 2.72), (s * 0.30, 0.25, 2.25)
        K.sphere(*sh, 0.13, plomb, "epaule")
        K.beam(sh, el, 0.15, 0.15, jaune, "bras_manipulateur")
        K.rod((el[0] - 0.10, el[1], el[2]), (el[0] + 0.10, el[1], el[2]), 0.11, plomb, "coude")
        K.beam(el, wr, 0.12, 0.12, jaune, "avant_bras")
        K.sphere(*wr, 0.08, plomb, "poignet")
        for d in (-0.05, 0.05):
            K.rod(wr, (wr[0] - s * 0.06 + d, wr[1] + 0.14, wr[2] - 0.22), 0.016, noir, "pince")
    H(K, 0.15, 1.65, 0.68, "#5CFF4A", 0.6)
    H(K, 0.0, 1.35, 1.25, "#5CFF4A", 0.4)
    if piece:
        K.module = "piece"
        prof = [(0, 0.34), (0.30, 0.28), (0.70, 0.22), (1.05, 0.215), (1.30, 0.24), (1.50, 0.28)]
        K.lathe((0.0, -0.50, 1.30), prof, beton, "tour_refroidissement", verts=40, cap1=False)
        K.torus(0.0, -0.50, 2.70, 0.282, 0.02, jaune, "bague_tour")
        K.cyl(0.0, -0.50, 2.66, 2.68, 0.26, vert, "coeur_tour", verts=40)
        H(K, 0.0, -0.2, 2.6, "#5CFF4A", 0.2)


# ------------------------------------------------------------------------------------------------
# Époque 10 · Haute technologie : coque lisse sur pieds courts, dôme, trois bras robotisés articulés
# ------------------------------------------------------------------------------------------------
def e10(K, t, piece):
    caren = K.metal("e10_carenage", "#A8ADB3", k=1.0, rough=0.32, metallic=0.25, grain=0.06, grain_scale=90.0,
                    dirt=0.35, seed=101)
    noir = K.metal("e10_noir", "#222428", k=1.3, rough=0.45, metallic=0.3, grain=0.08, dirt=0.25, seed=102)
    vitre = K.metal("e10_vitre", "#2A3A4A", k=1.0, rough=0.08, metallic=0.0, grain=0.02, dirt=0.0, seed=103)
    bleu = K.emit("e10_bleu", "#3AA8FF", strength=1.4, base="#0A2A4A")
    K.module = "corps"
    for x in (-1.0, 1.0):
        for y in (-0.48, 1.10):
            K.cyl(x, y, 0.0, 0.05, 0.12, noir, "patin")
            K.cyl(x, y, 0.05, 0.30, 0.055, caren, "pied")
            K.cyl(x, y, 0.28, 0.45, 0.08, noir, "fourreau")
    K.rbox(-1.24, 1.24, -0.62, 1.28, 0.40, 1.20, caren, "coque", r=0.22, seg=5)
    K.rbox(-1.26, 1.26, -0.64, 1.30, 0.53, 0.75, noir, "bandeau", r=0.16)
    for x in (-0.95, -0.67, -0.39):
        K.box(x - 0.09, x + 0.09, 1.30, 1.312, 0.55, 0.73, bleu, "voyant", bevel=0)
    K.box(0.05, 0.90, 1.255, 1.275, 0.80, 1.04, noir, "ecran_cadre", bevel=0.004)
    K.box(0.09, 0.86, 1.275, 1.285, 0.83, 1.01, bleu, "ecran", bevel=0)
    K.cyl(0.0, 0.05, 1.20, 1.42, 0.64, noir, "tambour", verts=48)
    K.lathe((0.0, 0.05, 1.42), [(0, 0.62), (0.18, 0.59), (0.34, 0.50), (0.48, 0.36), (0.58, 0.19), (0.62, 0.0)],
            vitre, "dome", verts=48)
    K.torus(0.0, 0.05, 1.43, 0.63, 0.022, bleu, "anneau_dome")
    K.cyl(-1.02, -0.50, 1.20, 1.30, 0.06, noir, "pied_antenne")
    K.rod((-1.02, -0.50, 1.30), (-1.02, -0.50, 3.60), 0.012, noir, "antenne_fouet")
    K.sphere(-1.02, -0.50, 3.62, 0.03, bleu, "feu_antenne")
    K.module = "meca"
    arms = [((-0.85, -0.38), (-1.00, -0.58, 2.58), (-0.38, -0.12, 2.02), (-0.22, 0.02, 1.80)),
            ((0.85, -0.38), (1.00, -0.58, 2.58), (0.38, -0.12, 2.02), (0.22, 0.02, 1.80)),
            ((0.88, 0.80), (1.06, 0.60, 2.10), (0.52, 0.45, 1.85), (0.40, 0.40, 1.62))]
    for (bx, by), el, wr, tip in arms:
        K.cyl(bx, by, 1.20, 1.30, 0.13, noir, "base_bras")
        K.cyl(bx, by, 1.30, 1.42, 0.10, caren, "pivot")
        sh = (bx, by, 1.48)
        K.sphere(*sh, 0.085, noir, "epaule")
        K.beam(sh, el, 0.12, 0.12, caren, "bras")
        K.sphere(*el, 0.08, noir, "coude")
        K.beam(el, wr, 0.10, 0.10, caren, "avant_bras")
        K.sphere(*wr, 0.06, noir, "poignet")
        K.rod(wr, tip, 0.035, noir, "outil", r2=0.015)
        K.sphere(*tip, 0.03, bleu, "led_outil")
    H(K, 0.0, 1.55, 0.80, "#3AA8FF", 0.6)
    H(K, 0.0, 0.60, 1.45, "#3AA8FF", 0.4)
    if piece:
        K.module = "piece"
        K.cyl(0.0, -0.55, 1.20, 1.30, 0.10, noir, "pied_parabole")
        K.rod((0.0, -0.55, 1.30), (0.0, -0.55, 2.50), 0.045, caren, "mat_parabole")
        ax = (0.0, -0.5, 0.85)
        prof = [(0, 0.03), (0.03, 0.12), (0.08, 0.24), (0.15, 0.34), (0.21, 0.42)]
        K.lathe((0.0, -0.55, 2.50), prof, caren, "parabole", verts=40, axis=ax, cap1=False)
        n = math.sqrt(0.25 + 0.85 ** 2)
        d = (0.0, -0.5 / n, 0.85 / n)
        base = P(0.0, -0.55, 2.50)
        feed = (base.x + d[0] * 0.40, base.y + d[1] * 0.40, base.z + d[2] * 0.40)
        K.rod(T(base), T(type(base)(feed)), 0.012, noir, "bras_source")
        K.sphere(*T(type(base)(feed)), 0.035, bleu, "source")


# ------------------------------------------------------------------------------------------------
# Époque 11 · Titane : portique blanc à ailerons sur quatre pieds en V, côtés ouverts
# ------------------------------------------------------------------------------------------------
def e11(K, t, piece):
    blanc = K.metal("e11_alliage", "#C9C6BE", k=0.92, rough=0.35, metallic=0.35, grain=0.08, grain_scale=70.0,
                    dirt=0.55, rust="#8A8478", rust_amount=0.25, seed=111)
    titane = K.metal("e11_titane", "#8E9AA6", k=1.15, rough=0.3, metallic=0.85, grain=0.1, dirt=0.35, seed=112)
    noir = K.metal("e11_noir", "#26282C", k=1.3, rough=0.45, metallic=0.3, seed=113)
    ligne = K.emit("e11_ligne", "#BFE6FF", strength=1.3, base="#405060")
    K.module = "corps"
    zg = 1.35
    for (x, y) in ((-1.10, -0.62), (1.10, -0.62), (-1.10, 1.12), (1.10, 1.12)):
        for dx in (-0.20, 0.20):
            K.cyl(x + dx, y, 0.0, 0.05, 0.07, noir, "patin")
            K.beam((x + dx, y, 0.03), (x, y, zg), 0.085, 0.085, titane, "jambe_v")
        K.box(x - 0.09, x + 0.09, y - 0.07, y + 0.07, zg - 0.08, zg + 0.12, blanc, "noeud", bevel=0.01)
    K.box(-1.18, 1.18, 1.05, 1.19, zg - 0.02, zg + 0.22, blanc, "poutre_avant", bevel=0.012)
    K.box(-0.98, 0.98, 1.19, 1.20, zg + 0.01, zg + 0.19, ligne, "ligne_avant", bevel=0)
    K.box(-1.18, 1.18, -0.69, -0.55, zg, zg + 0.18, blanc, "poutre_arriere", bevel=0.012)
    for x in (-1.10, 1.10):
        K.box(x - 0.07, x + 0.07, -0.62, 1.12, zg, zg + 0.18, blanc, "longeron", bevel=0.012)
    K.cyl(0.0, 0.25, 0.0, 0.32, 0.22, titane, "pied_plateau", verts=32)
    K.rbox(-0.66, 0.66, -0.20, 0.70, 0.30, 0.44, blanc, "plateau", r=0.05)
    K.box(-0.25, 0.20, 0.10, 0.45, 0.44, 0.58, noir, "piece_travail", bevel=0.01)
    fins = [[(-0.34, zg + 0.18), (0.34, zg + 0.18), (0.0, 3.10)],
            [(0.52, zg + 0.18), (1.12, zg + 0.18), (1.22, 2.42)],
            [(-1.12, zg + 0.18), (-0.52, zg + 0.18), (-1.22, 2.42)]]
    for poly in fins:
        K.plate(poly, -0.66, -0.58, blanc, "aileron", bevel=0.01)
    strips = [[(-0.07, zg + 0.30), (0.07, zg + 0.30), (0.012, 2.85), (-0.012, 2.85)],
              [(0.80, zg + 0.30), (0.92, zg + 0.30), (1.15, 2.22), (1.12, 2.22)],
              [(-0.92, zg + 0.30), (-0.80, zg + 0.30), (-1.12, 2.22), (-1.15, 2.22)]]
    for poly in strips:
        K.plate(poly, -0.580, -0.575, ligne, "chenillard", bevel=0)
    K.module = "meca"
    K.box(-1.04, 1.04, 0.20, 0.32, zg + 0.02, zg + 0.14, titane, "traverse_mobile", bevel=0.008)
    K.box(-0.22, 0.10, 0.14, 0.38, zg - 0.12, zg + 0.20, blanc, "chariot", bevel=0.012)
    K.cyl(-0.06, 0.26, 0.70, zg - 0.10, 0.06, titane, "bras_telescopique")
    K.cyl(-0.06, 0.26, 0.60, 0.72, 0.09, noir, "outil")
    K.sphere(-0.06, 0.26, 0.58, 0.04, ligne, "led_outil")
    H(K, 0.0, 1.40, 1.45, "#BFE6FF", 0.5)
    H(K, -0.06, 0.45, 0.60, "#BFE6FF", 0.5)
    if piece:
        K.module = "piece"
        mx, my = 0.92, -0.40
        K.box(mx - 0.09, mx + 0.09, my - 0.07, my + 0.07, zg + 0.18, 2.58, titane, "mat_grue", bevel=0.01)
        K.box(mx - 0.13, mx + 0.13, my - 0.09, my + 0.09, 2.48, 2.66, blanc, "tete_grue", bevel=0.012)
        tip = (-0.75, my, 3.50)
        K.beam((mx, my, 2.60), tip, 0.12, 0.16, blanc, "fleche_grue")
        K.beam((mx, my, 2.60), (mx + 0.40, my, 2.72), 0.10, 0.12, blanc, "contre_fleche")
        K.box(mx + 0.32, mx + 0.52, my - 0.08, my + 0.08, 2.52, 2.76, titane, "contrepoids", bevel=0.01)
        K.rod((mx, my, 2.75), tip, 0.007, noir, "hauban")
        K.rod((tip[0] + 0.06, my, tip[2] - 0.06), (tip[0] + 0.06, my, 1.95), 0.006, noir, "cable")
        K.box(tip[0] - 0.0, tip[0] + 0.12, my - 0.04, my + 0.04, 1.84, 1.96, titane, "moufle", bevel=0.006)
        H(K, tip[0], my + 0.3, 2.0, "#BFE6FF", 0.1)


# ------------------------------------------------------------------------------------------------
# Époque 12 · Supraconducteurs : plateau en lévitation entre pylônes, anneaux chromés flottants, bloc flottant
# ------------------------------------------------------------------------------------------------
def e12(K, t, piece):
    noir = K.metal("e12_noir", "#26282E", k=1.5, rough=0.28, metallic=0.4, grain=0.06, dirt=0.3, seed=121)
    chrome = K.metal("e12_chrome", "#9AA3AD", k=1.35, rough=0.12, metallic=1.0, grain=0.04, dirt=0.1, seed=122)
    givre = K.metal("e12_givre", "#DDEEFF", k=0.85, rough=0.85, metallic=0.0, grain=0.3, grain_scale=40.0, dirt=0.2,
                    seed=123)
    cyan = K.emit("e12_cyan", "#4AF0FF", strength=1.4, base="#0A3040")
    K.module = "corps"
    K.prism(octo(-1.05, 1.05, -0.52, 1.26, 0.30), 0.0, 0.18, noir, "plinthe")
    K.prism(octo(-1.07, 1.07, -0.54, 1.28, 0.30), 0.16, 0.21, chrome, "lisere", bevel=0.004)
    K.cyl(0.0, 0.32, 0.21, 0.24, 0.55, cyan, "patin_magnetique", verts=48)
    for (x, y, h) in ((-1.18, -0.66, 2.15), (1.18, -0.66, 2.15), (-1.18, 1.16, 1.20), (1.18, 1.16, 1.20)):
        K.box(x - 0.09, x + 0.09, y - 0.065, y + 0.065, 0.0, h, noir, "pylone", bevel=0.012)
        K.box(x - 0.11, x + 0.11, y - 0.08, y + 0.08, 0.0, 0.26, givre, "givre", bevel=0.01)
        K.cyl(x, y, h, h + 0.18, 0.12, chrome, "chapeau_pylone", verts=4, r2=0.01)
        K.box(x - 0.095, x + 0.095, y - 0.07, y + 0.07, h - 0.36, h - 0.20, cyan, "bague_pylone", bevel=0)
    K.module = "meca"
    K.prism(octo(-0.82, 0.82, -0.25, 0.90, 0.24), 0.62, 0.76, noir, "plateau_levitation")
    K.prism(octo(-0.84, 0.84, -0.27, 0.92, 0.25), 0.74, 0.80, chrome, "jante_plateau", bevel=0.006)
    K.torus(0.0, 0.32, 0.60, 0.80, 0.022, cyan, "lueur_dessous")
    K.torus(0.0, 0.32, 1.10, 1.02, 0.045, chrome, "anneau_bas")
    K.torus(0.0, 0.32, 1.62, 0.78, 0.04, chrome, "anneau_haut")
    K.torus(0.0, 0.32, 1.60, 0.72, 0.016, cyan, "anneau_haut_lumineux")
    for (x, y, z, s, r) in ((-0.35, 0.30, 1.05, 0.13, 0.4), (0.30, 0.45, 1.18, 0.11, 0.9), (0.05, 0.10, 1.38, 0.09, 1.3)):
        K.obox((x, y, z), (2 * s, 2 * s, 2 * s), (r, 0.3 * r, 0.6 * r), noir, "piece_flottante", bevel=0.01)
    K.box(-0.28, 0.28, -0.35, 0.05, 2.75, 3.25, noir, "bloc_flottant", bevel=0.05)
    K.box(-0.285, 0.285, -0.355, 0.055, 2.96, 3.04, cyan, "fente_bloc", bevel=0)
    K.torus(0.0, -0.15, 2.68, 0.38, 0.03, chrome, "anneau_bloc")
    H(K, 0.0, 0.75, 0.45, "#4AF0FF", 0.5)
    H(K, 0.0, 0.40, 2.95, "#4AF0FF", 0.25)
    for s in (-1, 1):
        H(K, s * 1.18, 1.35, 0.95, "#4AF0FF", 0.125)
    if piece:
        K.module = "piece"
        K.torus(0.0, -0.15, 3.0, 0.62, 0.065, chrome, "anneau_vertical", axis="y", minor_seg=14)
        K.torus(0.0, -0.13, 3.0, 0.54, 0.018, cyan, "anneau_vertical_lumineux", axis="y")
        K.sphere(0.0, -0.15, 3.80, 0.10, chrome, "noyau_sommet")


# ------------------------------------------------------------------------------------------------
# Époque 13 · Fusion : noyau sphérique sur trépied dans un cadre ouvert, tore de plasma horizontal
# ------------------------------------------------------------------------------------------------
def e13(K, t, piece):
    cera = K.metal("e13_ceramique", "#D9D6CF", k=0.95, rough=0.42, metallic=0.0, grain=0.08, dirt=0.55,
                   rust="#9A9284", rust_amount=0.2, seed=131)
    cuivre = K.metal("e13_cuivre", "#B0703A", k=1.25, rough=0.28, metallic=0.9, grain=0.12, dirt=0.4, seed=132)
    sombre = K.metal("e13_sombre", "#2A2826", k=1.4, rough=0.5, metallic=0.4, seed=133)
    plasma = K.emit("e13_plasma", "#FF4FD8", strength=1.6, base="#5A1048")
    coeur = K.emit("e13_coeur", "#FF9A3A", strength=1.5, base="#5A2A08")
    K.module = "corps"
    for x, y, h in ((-1.15, -0.70, 2.05), (1.15, -0.70, 2.05), (-1.15, 1.18, 1.05), (1.15, 1.18, 1.05)):
        K.box(x - 0.07, x + 0.07, y - 0.05, y + 0.05, 0.0, h, cera, "montant_cadre", bevel=0.01)
        K.box(x - 0.11, x + 0.11, y - 0.08, y + 0.08, 0.0, 0.10, cuivre, "sabot", bevel=0.008)
    K.box(-1.22, 1.22, -0.75, -0.65, 1.95, 2.10, cera, "traverse_arriere", bevel=0.01)
    K.box(-1.22, 1.22, 1.13, 1.23, 0.95, 1.10, cera, "traverse_avant", bevel=0.01)
    for x in (-1.15, 1.15):
        K.beam((x, 1.18, 1.05), (x, -0.70, 2.02), 0.12, 0.12, cera, "longeron_incline")
    for k in range(3):
        a = math.radians(90 + 120 * k)
        fx, fy = 0.80 * math.cos(a), 0.20 - 0.80 * math.sin(a) / R2
        K.beam((fx, fy, 0.0), (0.30 * math.cos(a), 0.20 - 0.30 * math.sin(a) / R2, 0.95), 0.09, 0.09, cuivre,
               "jambe_trepied")
        K.cyl(fx, fy, 0.0, 0.05, 0.10, sombre, "pied_trepied")
    K.sphere(0.0, 0.20, 1.50, 0.70, cera, "sphere_confinement", seg=48, rings=24)
    for z, r in ((1.15, 0.605), (1.85, 0.605)):
        K.torus(0.0, 0.20, z, r, 0.02, cuivre, "parallele")
    c = P(0.0, 0.20, 1.50)
    from mathutils import Vector
    for d in ((0.0, -0.85, 0.53), (0.62, -0.74, 0.26), (-0.62, -0.74, 0.26)):
        v = Vector(d).normalized()
        K.sphere(*T(c + v * 0.64), 0.10, coeur, "hublot_coeur")
    K.cyl(0.0, -0.10, 2.10, 3.55, 0.10, cera, "colonne_injection")
    for z in (2.40, 2.80, 3.20):
        K.cyl(0.0, -0.10, z, z + 0.06, 0.13, cuivre, "bague_colonne")
    K.sphere(0.0, -0.10, 3.62, 0.13, cuivre, "tete_injection")
    K.module = "meca"
    K.torus(0.0, 0.20, 1.50, 1.12, 0.10, plasma, "tore_plasma", major_seg=96, minor_seg=16)
    for a in (135, 45):
        ar = math.radians(a)
        p0 = (1.12 * math.cos(ar), 0.20 - 1.12 * math.sin(ar) / R2, 1.50)
        K.beam(p0, (math.copysign(1.15, p0[0]), -0.70, 1.50), 0.06, 0.06, cuivre, "attache_tore")
    H(K, 0.0, 1.05, 1.50, "#FF4FD8", 0.5)
    for s in (-1, 1):
        H(K, s * 0.95, 0.35, 1.50, "#FF4FD8", 0.25)
    if piece:
        K.module = "piece"
        cz = 3.05
        K.torus(0.0, -0.10, cz, 0.50, 0.04, cuivre, "couronne_injecteurs")
        for k in range(3):
            a = TAU * k / 3 + 0.5
            K.rod((0.0, -0.10, cz), (0.50 * math.cos(a), -0.10 - 0.50 * math.sin(a) / R2, cz), 0.015, cuivre, "rayon")
        for k in range(6):
            a = TAU * k / 6 + 0.26
            px, py = 0.50 * math.cos(a), -0.10 - 0.50 * math.sin(a) / R2
            tip = (px * 1.22, -0.10 - 0.61 * math.sin(a) / R2, cz + 0.36)
            K.rod((px, py, cz - 0.04), tip, 0.055, cuivre, "injecteur", r2=0.022, verts=16)
            K.sphere(*tip, 0.04, plasma, "pointe_injecteur")
        H(K, 0.0, 0.2, cz, "#FF4FD8", 0.15)


# ------------------------------------------------------------------------------------------------
# Époque 14 · Orbite : plate-forme sur pieds, ailes de panneaux dorés, parabole, bras de grue
# ------------------------------------------------------------------------------------------------
def e14(K, t, piece):
    blanc = K.metal("e14_blanc", "#CFCBC2", k=0.92, rough=0.38, metallic=0.2, grain=0.08, dirt=0.55, rust="#8A8478",
                    rust_amount=0.2, seed=141)
    or_ = K.metal("e14_or", "#C9A23A", k=1.2, rough=0.32, metallic=0.95, grain=0.55, grain_scale=35.0, dirt=0.3,
                  seed=142)
    cell = K.metal("e14_cellules", "#1E2A55", k=1.3, rough=0.12, metallic=0.2, grain=0.05, dirt=0.1, seed=143)
    rouge = K.emit("e14_balise", "#FF2A2A", strength=1.6, base="#4A0808")
    bleu = K.emit("e14_reflet", "#2F6BFF", strength=0.8, base="#0A1A44")
    K.module = "corps"
    for x in (-0.70, 0.70):
        for y in (-0.30, 0.78):
            K.cyl(x, y, 0.0, 0.05, 0.10, blanc, "patin")
            K.cyl(x, y, 0.05, 0.88, 0.05, blanc, "pied")
            K.cyl(x, y, 0.66, 0.88, 0.07, or_, "manchon")
    K.box(-0.82, 0.82, -0.42, 0.88, 0.88, 1.06, blanc, "plate_forme", bevel=0.015)
    K.box(-0.56, 0.56, -0.28, 0.62, 1.06, 1.55, or_, "caisson_dore", bevel=0.03)
    K.box(-0.30, 0.30, 0.62, 0.64, 1.15, 1.45, bleu, "hublot_cellules", bevel=0)
    K.cyl(0.0, -0.20, 1.55, 3.12, 0.085, blanc, "mat")
    th = math.radians(-35.0)
    nrm = (0.0, -math.cos(th), -math.sin(th))   # normale avant d'un panneau incliné (Blender)
    for s in (-1, 1):
        K.box(min(s * 0.08, s * 0.44), max(s * 0.08, s * 0.44), -0.23, -0.17, 1.98, 2.06, blanc, "traverse_aile")
        for xa, xb in ((0.44, 0.96), (1.00, 1.50)):
            cx = s * (xa + xb) / 2.0
            K.obox((cx, -0.20, 2.02), (xb - xa, 0.03, 0.64), (th, 0.0, 0.0), or_, "cadre_panneau", bevel=0.006)
            off = P(cx, -0.20, 2.02)
            c2 = (off.x + nrm[0] * 0.02, off.y + nrm[1] * 0.02, off.z + nrm[2] * 0.02)
            K.obox((c2[0], -c2[1] / R2, c2[2]), (xb - xa - 0.05, 0.012, 0.58), (th, 0.0, 0.0), cell, "cellules",
                   bevel=0)
            for f in (0.33, 0.66):
                K.obox((c2[0] - (xb - xa) * 0.5 * s + (xb - xa) * f * s, -c2[1] / R2 + 0.004, c2[2]),
                       (0.012, 0.016, 0.58), (th, 0.0, 0.0), or_, "grille", bevel=0)
        K.sphere(s * 1.50, -0.12, 2.02, 0.065, rouge, "balise_aile")
    dax = (0.0, -0.55, 0.83)
    prof = [(0, 0.04), (0.04, 0.16), (0.10, 0.30), (0.18, 0.42), (0.26, 0.52)]
    K.lathe((0.0, -0.20, 3.10), prof, blanc, "parabole", verts=48, axis=dax, cap1=False)
    n = math.sqrt(0.55 ** 2 + 0.83 ** 2)
    d = (0.0, -0.55 / n, 0.83 / n)
    base = P(0.0, -0.20, 3.10)
    feed = base.copy()
    feed.y += d[1] * 0.45
    feed.z += d[2] * 0.45
    K.rod(T(base), T(feed), 0.012, blanc, "bras_source")
    K.sphere(*T(feed), 0.05, rouge, "balise_parabole")
    K.module = "meca"
    sh, el, wr = (0.40, 0.45, 1.62), (0.95, 0.20, 2.32), (1.18, 0.78, 1.78)
    K.cyl(0.40, 0.45, 1.55, 1.62, 0.10, blanc, "base_grue")
    K.sphere(*sh, 0.07, or_, "epaule_grue")
    K.beam(sh, el, 0.09, 0.09, blanc, "bras_grue")
    K.sphere(*el, 0.06, or_, "coude_grue")
    K.beam(el, wr, 0.07, 0.07, blanc, "avant_bras_grue")
    for dd in (-0.04, 0.04):
        K.rod(wr, (wr[0] + dd, wr[1] + 0.10, wr[2] - 0.16), 0.012, or_, "pince")
    for s in (-1, 1):
        H(K, s * 1.50, 0.15, 2.02, "#FF2A2A", 0.2)
    H(K, 0.0, 0.95, 1.30, "#2F6BFF", 0.6)
    if piece:
        K.module = "piece"
        K.beam((0.0, -0.20, 2.70), (-0.70, -0.42, 2.98), 0.06, 0.06, blanc, "bras_reservoir")
        K.sphere(-0.84, -0.44, 3.10, 0.30, or_, "reservoir_dore", seg=40, rings=20)
        K.torus(-0.84, -0.44, 3.10, 0.302, 0.018, blanc, "ceinture_reservoir")
        K.tube([(-0.84, -0.44, 2.80), (-0.70, -0.30, 2.40), (-0.30, -0.10, 1.62)], 0.02, or_, "conduite_reservoir")


# ------------------------------------------------------------------------------------------------
# Époque 15 · Légende : base flottante, cadre ajouré, noyau flottant, couronne de flèches en or blanc
# ------------------------------------------------------------------------------------------------
def e15(K, t, piece):
    orb = K.metal("e15_or_blanc", "#E8DCB0", k=0.85, rough=0.25, metallic=0.9, grain=0.1, dirt=0.5, rust="#9A8A60",
                  rust_amount=0.2, seed=151)
    nacre = K.metal("e15_nacre", "#D8D2C8", k=0.9, rough=0.22, metallic=0.1, grain=0.12, grain_scale=30.0, dirt=0.4,
                    seed=152)
    clair = K.emit("e15_lumiere", "#FFF2C0", strength=1.3, base="#8A8060")
    cy = 0.20
    K.module = "corps"
    K.lathe((0.0, cy, 0.30), [(0, 0.0), (0.0, 0.85), (0.06, 1.08), (0.14, 1.15), (0.22, 1.10), (0.26, 0.90),
                               (0.27, 0.0)], nacre, "base_flottante", verts=64)
    K.torus(0.0, cy, 0.44, 1.15, 0.045, orb, "jante")
    K.torus(0.0, cy, 0.28, 0.80, 0.03, clair, "lueur_dessous")
    for k in range(4):
        a = math.radians(45 + 90 * k)
        pts = []
        for i in range(17):
            f = i / 16.0
            r = 1.05 * (1 - f) + 0.42 * f + 0.30 * math.sin(math.pi * f) * (1 - f)
            pts.append((r * math.cos(a), cy - r * math.sin(a) / R2, 0.55 + 2.05 * f))
        K.tube(pts, 0.04, orb, "nervure")
    K.torus(0.0, cy, 2.62, 0.44, 0.06, orb, "anneau_couronne")
    K.cyl(0.0, cy, 2.55, 2.66, 0.38, nacre, "disque_couronne", verts=48)
    # flèches : centrale (cylindre effilé + pointe) puis six autour, plus hautes à l'arrière
    K.cyl(0.0, cy, 2.62, 4.40, 0.12, orb, "fleche_centrale", r2=0.08, verts=24)
    K.cyl(0.0, cy, 4.40, 4.92, 0.08, orb, "pointe_centrale", r2=0.004, verts=24)
    K.crystal((0.0, cy, 4.86), 0.22, 0.035, clair, "eclat_pointe")
    for k in range(6):
        a = math.radians(30 + 60 * k)
        x, y = 0.44 * math.cos(a), cy - 0.44 * math.sin(a) / R2
        hm = 3.30 + 0.45 * math.sin(a)
        K.cyl(x, y, 2.62, hm, 0.09, orb, "fleche", r2=0.075, verts=20)
        K.cyl(x, y, hm, hm + 0.40, 0.075, orb, "pointe", r2=0.004, verts=20)
    K.module = "meca"
    K.sphere(0.0, cy, 1.55, 0.26, clair, "noyau_flottant")
    K.torus(0.0, cy, 1.55, 0.36, 0.025, orb, "cage_1", tilt=0.5)
    K.torus(0.0, cy, 1.55, 0.36, 0.025, orb, "cage_2", axis="y")
    H(K, 0.0, 0.65, 1.55, "#FFF2C0", 0.5)
    H(K, 0.0, 0.25, 0.15, "#FFF2C0", 0.5)
    if piece:
        K.module = "piece"
        K.torus(0.0, cy, 4.15, 0.95, 0.035, clair, "anneau_halo", minor_seg=10, major_seg=96)
        import random
        rnd = random.Random(1530)
        for i in range(16):
            a = TAU * i / 16 + rnd.uniform(-0.15, 0.15)
            rr = 0.95 + rnd.uniform(-0.18, 0.18)
            z = 4.15 + rnd.uniform(-0.35, 0.35)
            K.sphere(rr * math.cos(a), cy - rr * math.sin(a) / R2, z, rnd.uniform(0.025, 0.045), clair, "particule",
                     seg=12, rings=6)
        H(K, 0.0, 0.6, 4.0, "#FFF2C0", 0.15)


BUILDERS = {1: e01, 2: e02, 3: e03, 4: e04, 5: e05, 6: e06, 7: e07, 8: e08, 9: e09, 10: e10, 11: e11, 12: e12,
            13: e13, 14: e14, 15: e15}


def build_level(S, C, n, t=0.0):
    """Construit le niveau n (2 à 30) ; renvoie les fenêtres du halo (tuiles relatives à l'entité)."""
    import params
    K = Kit(S, C)
    K.power = params.halo_puissance(n)
    K.halo_pts = []
    e = params.epoque(n)
    BUILDERS[e](K, t, params.est_pair(n))
    k = 1.0 + 0.05 * n
    wins = []
    for (tx, ty, z) in K.halo_pts:
        wins.append({"at": (tx, ty, 0.0), "r": (0.40 * k, 0.95 * k)})
        wins.append({"at": (tx, ty, z), "r": (0.22, 0.55)})
    return {"halo": wins or params.halo_fenetres(n), "modules": sorted({o.get("fo_module", "corps")
                                                                         for o in S.piece_objects()})}
