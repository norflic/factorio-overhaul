"""Modèles paramétriques des niveaux 2 à 30 de la machine d'assemblage 2 (lot V3, phase 1). S'exécute DANS Blender.

Une fonction par époque (bible docs/DESIGN_EPOQUES.md §5, ligne « Assembleur 2 ») : le niveau impair 2e-1 est la
silhouette de l'époque, le niveau pair 2e ajoute la pièce (module « piece », couche séparée en phase 2).
Le niveau 1 est le sprite vanilla (Q11) : rien à modéliser. Le niveau 2 ne modélise que la pièce de l'époque 1,
posée sur le sprite vanilla et masquée au pixel par son alpha au post-traitement (variante « four » de V0).

Repère : voir kit.py (tuiles de jeu, y vers le sud ; écran y = ty - 0,7071·z). Paramètre t (0 à 1) : phase du
mécanisme animé (32 images en phase 2) ; la phase 1 ne rend que t = 0 (pose de référence, image 0).
"""
import math

from mathutils import Vector

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


def ecailles(K, a, b, xa, xb, f0, f1, n, mat, stagger=0.0, lift=0.05):
    """Rangée de n écailles de blindage sur une face inclinée nord-sud (arête basse a=(ty, z), arête haute b, demi-
    largeurs xa en bas et xb en haut), entre les fractions f0 et f1. Chaque écaille est un pentagone pointe en bas,
    décollé de la face vers sa pointe (`lift` tuile) : sa normale diffère de celle de la face, d'où le motif imbriqué
    lisible au zoom 1. stagger : décalage d'une demi-écaille (rangée supérieure)."""
    A, B = P(0.0, a[0], a[1]), P(0.0, b[0], b[1])
    tg = (B - A).normalized()
    nrm = Vector((1.0, 0.0, 0.0)).cross(tg)
    if nrm.z < 0:
        nrm = -nrm

    def pt(x, f, off):
        ty = a[0] + (b[0] - a[0]) * f
        z = a[1] + (b[1] - a[1]) * f
        return P(x, ty, z) + nrm * off

    fm = f0 + 0.40 * (f1 - f0)
    xh = xa + (xb - xa) * (f0 + f1) / 2.0 - 0.06
    w = 2.0 * xh / n
    objs = []
    for i in range(n):
        u = -xh + (i + 0.5 + stagger) * w
        if u + 0.45 * w > xh + 1e-6:
            continue
        h = 0.55 * w
        verts = [pt(u - h, f1, 0.006), pt(u + h, f1, 0.006), pt(u + h, fm, 0.6 * lift), pt(u, f0, lift),
                 pt(u - h, fm, 0.6 * lift)]
        objs.append(K.mesh(verts, [(0, 1, 2, 3, 4)], mat, "ecaille", bevel=0))
    return objs


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
# Raccords de tuyaux (correction V3 du 22/10, bible §0 « tuyaux N et S » et §1.8-6)
# ------------------------------------------------------------------------------------------------
# Les entrées de fluide restent celles du vanilla : (0, -2) et (0, 2) (entities.lua:4729, 4738), (±2, 0) quand la
# machine est tournée. Les pipe_picture vanilla sont dessinées pour le corps vanilla : ici, chaque époque reçoit ses
# propres départs de tuyau, modules « tuyau_ns » et « tuyau_ew », rendus à part (phase 2 : pipe_picture par époque,
# 4 directions). Géométrie calée sur les sprites vanilla mesurés (hr-pipe-straight-vertical/horizontal.png) : tube de
# 0,60 tuile de large à l'écran (rayon 0,30), axe à z 0,30 ; le bout du départ tombe à l'écran sur le bord de
# l'emprise (y = ±1,5 pour N et S : ty = ∓1,5 + 0,707 × 0,30 ; x = ±1,5 pour E et O, à ty 0,15 pour que l'axe
# tombe à -0,06 tuile à l'écran comme le tuyau horizontal vanilla).
PIPE_R, PIPE_Z = 0.30, 0.30
PIPE_EW_TY = 0.15
# (distance d'attache depuis le centre, hauteur de la colonne montante ou None) pour N, S, E, O ; couleur du tube
RACCORDS = {
    2: ((-0.72, None), (1.42, None), (0.64, None), (-1.18, None), "#5C6168"),
    3: ((-0.66, None), (1.42, None), (1.29, None), (-1.26, None), "#8A5A3A"),
    4: ((-0.66, None), (1.40, None), (1.30, None), (-1.30, None), "#6E7378"),
    5: ((-0.30, None), (1.22, None), (1.12, None), (-1.12, None), "#3E3D42"),
    6: ((-0.66, None), (1.44, None), (0.82, None), (-0.82, None), "#B0703A"),
    7: ((-0.22, None), (1.38, None), (1.20, None), (-1.20, None), "#6A5236"),
    8: ((-0.42, None), (1.32, None), (0.96, None), (-0.96, None), "#4F6B5A"),
    9: ((-0.56, None), (1.38, None), (1.10, None), (-1.10, None), "#4A5058"),
    10: ((-0.40, 0.40), (1.10, 0.40), (1.05, 0.40), (-1.05, 0.40), "#A8ADB3"),
    11: ((-0.14, 0.28), (0.76, 0.28), (0.68, 0.28), (-0.68, 0.28), "#C9C6BE"),
    12: ((-0.52, None), (1.26, None), (1.05, None), (-1.05, None), "#9AA3AD"),
    13: ((-0.45, 0.42), (0.93, 0.42), (0.97, 0.42), (-0.97, 0.42), "#D9D6CF"),
    14: ((-0.40, 0.88), (0.86, 0.88), (0.80, 0.88), (-0.80, 0.88), "#CFCBC2"),
    15: ((-0.55, 0.28), (0.85, 0.28), (0.85, 0.28), (-0.85, 0.28), "#E8DCB0"),
}


def raccords(K, e):
    """Départs de tuyau N, S (module tuyau_ns) et E, O (module tuyau_ew) de l'époque e : tube du bord de l'emprise
    jusqu'au corps, brides aux deux bouts, coude et colonne montante si le corps est levé (ères IV et V)."""
    if e not in RACCORDS:
        return
    n_, s_, e_, w_, col = RACCORDS[e]
    tube = K.metal("tuyau_e%02d" % e, col, k=1.3 if e < 10 else 0.9, rough=0.4, metallic=0.6, grain=0.15, dirt=0.45,
                   seed=900 + e)
    bride = K.metal("bride_e%02d" % e, "#2E2C2A" if e < 10 else col, k=1.4 if e < 10 else 0.7, rough=0.45,
                    metallic=0.6, grain=0.1, dirt=0.3, seed=950 + e)
    z = PIPE_Z
    edge_n, edge_s = -1.5 + 0.7071 * z, 1.5 + 0.7071 * z
    legs = [("tuyau_ns", (0.0, edge_n, z), (0.0, n_[0], z), n_[1], "y"),
            ("tuyau_ns", (0.0, edge_s, z), (0.0, s_[0], z), s_[1], "y"),
            ("tuyau_ew", (1.5, PIPE_EW_TY, z), (e_[0], PIPE_EW_TY, z), e_[1], "x"),
            ("tuyau_ew", (-1.5, PIPE_EW_TY, z), (w_[0], PIPE_EW_TY, z), w_[1], "x")]
    saved = K.module
    for mod, a, b, zr, ax in legs:
        K.module = mod
        K.rod(a, b, PIPE_R, tube, "tube", verts=28)
        K.torus(a[0], a[1], a[2], PIPE_R + 0.005, 0.045, bride, "bride_bord", axis=ax, minor_seg=8)
        if zr is not None and zr > z + 0.02:
            K.sphere(b[0], b[1], b[2], PIPE_R, tube, "coude", seg=24, rings=12)
            K.cyl(b[0], b[1], z, zr + 0.04, PIPE_R * 0.8, tube, "colonne_montante", verts=24)
            K.cyl(b[0], b[1], zr - 0.03, zr + 0.04, PIPE_R * 0.95, bride, "bride_corps", verts=24)
        else:
            K.torus(b[0], b[1], b[2], PIPE_R + 0.005, 0.045, bride, "bride_corps", axis=ax, minor_seg=8)
    K.module = saved


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
    # verre ambré : la nuit, le halo ne fait que RÉVÉLER la couleur du jour (maquette game.frag) ; un verre sombre
    # restait invisible (planche de nuit du 21/10)
    lampe = K.emit("e1_lanterne", "#FFB060", strength=1.4, base="#D89850", night_only=True)
    caisse = K.metal("e1_caisse", "#6B4F35", k=1.9, rough=0.8, metallic=0.0, grain=0.4, grain_scale=22.0, dirt=0.55,
                     seed=13)
    # Correction V3 du 22/10 : potence abaissée de 0,18 (O visé 0,45 au lieu de 0,64 : le passage au niveau 3 ne
    # doit pas faire paraître la machine améliorée plus basse).
    # Mât équarri au coin arrière droit, hors du corps vanilla (x ≤ 1,28) : il DÉPASSE (F42), comme la flèche et la
    # charge suspendue, qui passent au-dessus du bord haut du sprite vanilla (-1,56 à l'écran).
    X, Y = 1.37, -1.06
    for (dx, dy) in ((0.17, 0.0), (0.0, 0.17)):
        K.box(X - 0.03 - dx, X + 0.03 + dx, Y - 0.03 - dy, Y + 0.03 + dy, 0.0, 0.07, bois, "semelle", bevel=0.008)
    K.beam((X, Y + 0.19, 0.03), (X, Y + 0.02, 0.42), 0.055, 0.055, bois, "contrefiche")
    K.box(X - 0.06, X + 0.06, Y - 0.055, Y + 0.055, 0.0, 1.28, bois, "mat", bevel=0.01)
    K.beam((X + 0.08, Y, 1.20), (0.26, Y, 1.20), 0.085, 0.11, bois, "fleche")
    K.beam((X - 0.05, Y, 0.70), (X - 0.62, Y, 1.15), 0.06, 0.06, bois, "jambe_de_force")
    for z in (0.66, 1.12):
        K.box(X - 0.072, X + 0.072, Y - 0.067, Y + 0.067, z, z + 0.07, fer, "ferrure", bevel=0.004)
    K.box(0.24, 0.40, Y - 0.06, Y + 0.06, 1.13, 1.27, fer, "sabot_fleche", bevel=0.005)
    K.rivets((0.27, Y + 0.062, 1.24), (0.38, Y + 0.062, 1.24), 3, 0.014, fer, "clous")
    # treuil à manivelle sur le mât (le câble remonte le long de la flèche jusqu'à la poulie)
    K.rod((X - 0.13, Y + 0.10, 0.52), (X + 0.13, Y + 0.10, 0.52), 0.06, bois, "tambour_treuil", verts=20)
    for s in (-1, 1):
        K.box(X + s * 0.13 - 0.015, X + s * 0.13 + 0.015, Y + 0.02, Y + 0.16, 0.42, 0.62, fer, "flasque", bevel=0)
    K.beam((X + 0.15, Y + 0.10, 0.52), (X + 0.15, Y + 0.10, 0.36), 0.022, 0.022, fer, "manivelle")
    xp = 0.36
    K.rod((xp, Y - 0.04, 1.12), (xp, Y + 0.04, 1.12), 0.06, fer, "poulie", verts=20)
    K.tube([(X - 0.02, Y + 0.10, 0.58), (X - 0.02, Y + 0.07, 1.12), (xp, Y + 0.01, 1.18)], 0.009, corde, "cable")
    K.module = "meca"
    for dx in (-0.05, 0.05):
        K.rod((xp + dx, Y, 1.11), (xp + dx, Y, 0.95), 0.007, corde, "corde")
    K.box(xp - 0.08, xp + 0.08, Y - 0.035, Y + 0.035, 0.87, 0.96, fer, "moufle", bevel=0.006)
    K.torus(xp, Y, 0.84, 0.03, 0.011, fer, "crochet", axis="y")
    for dx in (-0.12, 0.12):
        K.rod((xp, Y, 0.83), (xp + dx, Y, 0.76), 0.005, corde, "elingue")
    # charge suspendue : caisse en bois cerclée (kit d'époque 1), au-dessus du toit vanilla
    K.box(xp - 0.16, xp + 0.16, Y - 0.13, Y + 0.13, 0.52, 0.76, caisse, "caisse_suspendue", bevel=0.012)
    for z in (0.54, 0.73):
        K.box(xp - 0.165, xp + 0.165, Y - 0.135, Y + 0.135, z, z + 0.025, fer, "cerclage_caisse", bevel=0)
    K.module = "piece"
    K.box(X - 0.013, X + 0.013, Y + 0.05, Y + 0.20, 0.96, 0.985, fer, "potence_lanterne", bevel=0)
    K.cyl(X, Y + 0.20, 0.91, 0.955, 0.05, fer, "lanterne_toit", r2=0.014)
    K.cyl(X, Y + 0.20, 0.80, 0.91, 0.065, lampe, "lanterne_verre", verts=16)
    K.cyl(X, Y + 0.20, 0.78, 0.80, 0.07, fer, "lanterne_pied")
    H(K, X - 0.02, Y + 0.28, 0.85, "#FFB060", 1.0)


# ------------------------------------------------------------------------------------------------
# Époque 2 · Forge : caisse rivetée cerclée, volant d'inertie à droite, arbre de transmission au toit
# ------------------------------------------------------------------------------------------------
def e02(K, t, piece):
    acier = K.metal("e2_acier", "#5C6168", k=1.55, rough=0.40, metallic=0.55, grain=0.14, rust="#4A3020",
                    rust_amount=0.22, dirt=0.5, seed=21)
    cercle = K.metal("e2_cerclage", "#2E2C2A", k=1.6, rough=0.45, metallic=0.65, grain=0.2, dirt=0.35, seed=22)
    laiton = K.metal("e2_laiton", "#8C7440", k=2.0, rough=0.26, metallic=0.9, grain=0.1, dirt=0.2, seed=23)
    plaque = K.metal("e2_plaque", "#5C6168", k=1.25, rough=0.5, metallic=0.5, grain=0.2, rust="#4A3020",
                     rust_amount=0.35, dirt=0.55, seed=24)
    cuir = K.flat("e2_courroie", "#3A2A1E", rough=0.8)
    # braises couvertes (orange sombre) : révélées la nuit par leur propre lumière (même raison que la lanterne)
    forge = K.emit("e2_forge", "#FF6A20", strength=1.5, base="#B04A18", night_only=True)
    K.module = "corps"
    # Silhouette (correction V3 du 22/10 : le CONTOUR change, pas seulement le toit) : deux « cubes cerclés » en
    # gradin. Caisse basse sur toute la largeur utile, tour de forge crénelée sur la moitié gauche ; à droite, le toit
    # bas porte les engrenages et le grand volant se dresse SEUL au flanc droit (ses rayons laissent voir le sol).
    zb, zt = 0.52, 1.28                     # toit de la caisse basse, toit de la tour
    K.box(-1.18, 0.64, -0.72, 1.42, 0.0, 0.14, cercle, "socle", bevel=0.02)
    K.box(-1.14, 0.60, -0.68, 1.38, 0.14, zb, acier, "caisse_basse", bevel=0.025)
    for z in (0.18, zb - 0.07):
        K.box(-1.16, 0.62, -0.70, 1.40, z, z + 0.05, cercle, "cerclage", bevel=0.006)
    for x in (-1.14, 0.60):
        for y in (-0.68, 1.38):
            K.box(x - 0.045, x + 0.045, y - 0.035, y + 0.035, 0.14, zb + 0.02, cercle, "corniere", bevel=0.006)
    K.rivets((-1.10, 1.405, 0.205), (0.56, 1.405, 0.205), 13, 0.016, laiton, "rivets_face")
    K.rivets((-1.10, 1.405, zb - 0.045), (0.56, 1.405, zb - 0.045), 13, 0.016, laiton, "rivets_face")
    K.box(-0.20, 0.42, 1.38, 1.395, 0.20, 0.46, cercle, "porte", bevel=0.006)
    K.box(0.30, 0.36, 1.395, 1.41, 0.28, 0.38, laiton, "poignee", bevel=0)
    for x0 in (-1.02, -0.70):
        K.box(x0, x0 + 0.26, 1.382, 1.397, 0.30, 0.40, forge, "fente_forge", bevel=0)
    # tour de forge (cube supérieur cerclé) et parapet crénelé (créneaux d'acier, signature de l'époque)
    K.box(-1.14, 0.12, -0.68, 0.40, zb, zt, acier, "tour_forge", bevel=0.025)
    for z in (zb + 0.05, zt - 0.08):
        K.box(-1.16, 0.14, -0.70, 0.42, z, z + 0.05, cercle, "cerclage_tour", bevel=0.006)
    for x in (-1.14, 0.12):
        for y in (-0.68, 0.40):
            K.box(x - 0.045, x + 0.045, y - 0.035, y + 0.035, zb, zt + 0.02, cercle, "corniere_tour", bevel=0.006)
    K.rivets((-1.10, 0.425, zt - 0.055), (0.08, 0.425, zt - 0.055), 9, 0.016, laiton, "rivets_tour")
    for x0 in (-0.92, -0.52, -0.12):
        K.box(x0, x0 + 0.22, 0.402, 0.417, zb + 0.20, zb + 0.44, forge, "gueule_forge", bevel=0)
    zp = zt + 0.12
    K.box(-1.14, 0.12, -0.68, -0.59, zt, zp, cercle, "parapet", bevel=0.008)
    K.box(-1.14, 0.12, 0.31, 0.40, zt, zp, cercle, "parapet", bevel=0.008)
    K.box(-1.14, -1.05, -0.59, 0.31, zt, zp, cercle, "parapet", bevel=0.008)
    K.box(0.03, 0.12, -0.59, 0.31, zt, zp, cercle, "parapet", bevel=0.008)
    for i in range(5):
        x = -1.06 + i * 0.29
        for y in (-0.635, 0.355):
            K.box(x - 0.06, x + 0.06, y - 0.05, y + 0.05, zp, zp + 0.13, acier, "merlon", bevel=0.008)
    K.box(-0.86, -0.30, -0.40, 0.12, zt, zt + 0.05, plaque, "plaque_boulonnee", bevel=0.006)
    K.rivets((-0.82, 0.10, zt + 0.055), (-0.34, 0.10, zt + 0.055), 4, 0.014, laiton, "rivets_plaque")
    # toit bas, à droite : soufflet de forge (kit d'époque 2) sur l'avant (il pompe : module meca), paliers de l'arbre
    K.module = "meca"
    K.box(0.16, 0.56, 0.86, 1.28, zb, zb + 0.06, cercle, "planche_soufflet", bevel=0.006)
    K.prism([(0.16, 0.86), (0.56, 0.86), (0.56, 1.28), (0.16, 1.28)], zb + 0.06, zb + 0.24, cuir, "cuir_soufflet",
            top=[(0.22, 0.92), (0.50, 0.94), (0.50, 1.20), (0.22, 1.22)], bevel=0.01)
    K.box(0.18, 0.54, 0.88, 1.26, zb + 0.24, zb + 0.29, cercle, "planche_soufflet", bevel=0.006)
    K.rod((0.16, 1.07, zb + 0.13), (0.06, 1.07, zb + 0.13), 0.03, laiton, "buse_soufflet", r2=0.015)
    K.module = "corps"
    for x in (0.18, 0.54):
        K.box(x - 0.05, x + 0.05, -0.62, -0.50, zb, 1.12, cercle, "palier_arbre", bevel=0.008)
    # palier du volant (colonne étroite derrière le moyeu : le volant reste ajouré)
    K.box(0.90, 1.10, 1.02, 1.20, 0.0, 0.58, cercle, "colonne_volant", bevel=0.01)
    K.box(0.86, 1.14, 0.98, 1.24, 0.0, 0.08, cercle, "semelle_volant", bevel=0.008)
    K.module = "meca"
    ph = TAU * t
    # arbre de transmission sur ses paliers, poulie, courroie vers le grand engrenage
    K.rod((0.12, -0.56, 1.06), (0.60, -0.56, 1.06), 0.04, acier, "arbre_toit")
    K.rod((0.36, -0.56, 1.06), (0.44, -0.56, 1.06), 0.15, cercle, "poulie", verts=28)
    for dz in (-1, 1):
        K.beam((0.40, -0.56, 1.06 + dz * 0.13), (0.40, 0.10, 0.96 + dz * 0.07), 0.07, 0.012, cuir, "courroie")
    # deux engrenages qui s'engrènent, de face (lisibles) : identité « mécanisme sur le toit »
    for x in (0.22, 0.56):
        K.box(x - 0.05, x + 0.05, 0.08, 0.20, zb, 0.98, cercle, "chevalet", bevel=0.008)
    K.gear((0.40, 0.18, 0.96), "y", 0.30, 0.07, 16, laiton, "grand_engrenage", phase=ph)
    K.gear((0.76, 0.18, 1.20), "y", 0.16, 0.07, 9, acier, "pignon", phase=-ph * 1.9 + 0.2)
    crank = (1.00 + 0.24 * math.cos(ph), 1.36, 0.70 + 0.24 * math.sin(ph))
    K.rod((0.76 + 0.10 * math.cos(-ph * 1.9), 0.24, 1.20 + 0.10 * math.sin(-ph * 1.9)), crank, 0.022, acier, "bielle")
    K.rod((1.00, 1.10, 0.70), (1.00, 1.44, 0.70), 0.045, acier, "arbre_volant")
    K.wheel((1.00, 1.32, 0.70), "y", 0.50, 0.09, 6, acier, cercle, "volant", phase=ph)
    H(K, -0.75, 1.55, 0.35, "#FF6A20", 0.55)
    H(K, -0.45, 0.62, 0.95, "#FF6A20", 0.45)
    if piece:
        # marteau-pilon vertical sur l'arrière du toit bas : il remplit l'échancrure de droite et dépasse de +0,30
        # (O visé 0,46 : cylindre au plus haut, à -1,96 à l'écran)
        K.module = "piece"
        yp = -0.30
        for x in (0.22, 0.70):
            K.box(x - 0.05, x + 0.05, yp - 0.07, yp + 0.07, zb, 1.94, acier, "montant_pilon", bevel=0.008)
        K.box(0.14, 0.78, yp - 0.09, yp + 0.09, 1.86, 2.00, cercle, "traverse_pilon", bevel=0.012)
        K.rivets((0.20, yp + 0.095, 1.93), (0.72, yp + 0.095, 1.93), 5, 0.014, laiton, "rivets_traverse")
        K.cyl(0.46, yp, 2.00, 2.24, 0.13, laiton, "cylindre_pilon", verts=28)
        K.cyl(0.46, yp, 2.24, 2.28, 0.15, cercle, "chapeau_cylindre", verts=28)
        K.rod((0.46, yp, 1.54), (0.46, yp, 2.00), 0.03, acier, "tige_pilon")
        K.box(0.28, 0.64, yp - 0.08, yp + 0.08, 1.30, 1.54, cercle, "mouton", bevel=0.015)
        K.rivets((0.32, yp + 0.085, 1.48), (0.60, yp + 0.085, 1.48), 4, 0.014, laiton, "rivets_mouton")
        K.box(0.26, 0.66, yp - 0.11, yp + 0.11, zb, zb + 0.18, cercle, "enclume", bevel=0.015)


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
    # Silhouette (correction V3 du 22/10) : bâti ÉTROIT à gauche (machine à vapeur sur son toit) et CHAUDIÈRE
    # VERTICALE décentrée à l'arrière droit, séparée du bâti par un jour ; l'avant droit reste dégagé (bâche d'eau
    # basse seulement). Cheminée ronde à collerette au-dessus de la chaudière.
    zb = 0.70
    bot = [(-1.26, -0.66), (0.24, -0.66), (0.24, 1.42), (-1.26, 1.42)]
    top = [(-1.20, -0.60), (0.18, -0.60), (0.18, 1.34), (-1.20, 1.34)]
    K.prism(bot, 0.0, zb, fonte, "bati", top=top, bevel=0.02)
    K.box(-1.24, 0.22, 1.32, 1.38, 0.50, 0.58, cuivre, "bandeau", bevel=0.006)
    K.rivets((-1.18, 1.39, 0.54), (0.16, 1.39, 0.54), 11, 0.016, laiton, "rivets_bandeau")
    # porte du foyer : hublot ambré (lueur de jour)
    K.rod((-0.62, 1.33, 0.30), (-0.62, 1.40, 0.30), 0.16, laiton, "cadre_hublot", verts=32)
    K.rod((-0.62, 1.39, 0.30), (-0.62, 1.415, 0.30), 0.12, ambre, "hublot", verts=32)
    # toit du bâti : coutures rivetées, trou d'homme
    for yy in (0.10, 0.80):
        K.box(-1.18, 0.16, yy - 0.025, yy + 0.025, zb, zb + 0.018, fonte, "couture", bevel=0)
        K.rivets((-1.14, yy, zb + 0.02), (0.12, yy, zb + 0.02), 9, 0.014, laiton, "rivets_toit")
    K.rod((-0.10, 1.02, zb), (-0.10, 1.02, zb + 0.06), 0.15, fonte, "trou_homme", verts=28)
    # chaudière verticale : socle annulaire, virole rivetée, dôme, cheminée à collerette
    bx, by = 0.88, 0.0
    K.cyl(bx, by, 0.0, 0.16, 0.46, fonte, "socle_chaudiere", verts=40)
    K.lathe((bx, by, 0.16), [(0, 0.40), (1.02, 0.40), (1.10, 0.37), (1.18, 0.30), (1.24, 0.18), (1.27, 0.0)], cuivre,
            "chaudiere", verts=40)
    for z in (0.40, 0.72, 1.00):
        K.torus(bx, by, z, 0.402, 0.018, laiton, "virole")
        K.rivets((bx - 0.36, by + 0.21, z + 0.03), (bx + 0.36, by + 0.21, z + 0.03), 7, 0.013, laiton, "rivets_virole")
    # cheminée : sommet à z 2,38, soit -1,80 à l'écran (O 0,27, enveloppe 0,27)
    K.lathe((bx, by, 1.40), [(0, 0.19), (0.08, 0.19), (0.10, 0.12), (0.84, 0.115), (0.86, 0.17), (0.96, 0.17),
                              (0.98, 0.14)], fonte, "cheminee", verts=36, cap1=False)
    K.cyl(bx, by, 2.36, 2.38, 0.135, suie, "suie")
    K.torus(bx, by, 1.80, 0.12, 0.015, laiton, "cercle_cheminee")
    # manomètres ronds sur la virole (face sud) : cadrans ambrés (lueur de jour)
    for (x, z) in ((bx - 0.17, 0.86), (bx + 0.17, 0.86)):
        K.rod((x, by + 0.33, z), (x, by + 0.40, z), 0.105, laiton, "manometre", verts=28)
        K.rod((x, by + 0.40, z), (x, by + 0.412, z), 0.092, ambre, "cadran", verts=28)
    # soupape au sommet du dôme
    K.cyl(bx + 0.18, by, 1.34, 1.50, 0.03, laiton, "soupape")
    K.sphere(bx + 0.18, by, 1.52, 0.04, laiton, "soupape_bille")
    # pompe d'alimentation à bras (fine) à l'avant droit, qui laisse ce coin dégagé ; conduite coudée vers la chaudière
    K.cyl(0.86, 0.98, 0.0, 0.10, 0.12, fonte, "socle_pompe")
    K.cyl(0.86, 0.98, 0.10, 0.52, 0.055, cuivre, "corps_pompe")
    K.beam((0.86, 0.98, 0.56), (1.10, 0.98, 0.70), 0.03, 0.03, acier, "bras_pompe")
    K.tube([(0.86, 0.98, 0.30), (0.86, 0.60, 0.30), (0.86, 0.36, 0.40)], 0.03, cuivre, "conduite_eau")
    # tuyau de vapeur : chaudière -> cylindre (passe le jour entre bâti et chaudière)
    K.tube([(bx - 0.30, by - 0.10, 1.10), (0.20, -0.20, 1.10), (-0.40, -0.26, 1.16), (-0.70, -0.26, 1.18)], 0.035,
           cuivre, "tuyau_vapeur")
    K.module = "meca"
    ph = TAU * t
    # machine à vapeur horizontale à l'ARRIÈRE du toit : le volant dépasse le bord arrière du bâti à l'écran (2e
    # événement de silhouette avec la chaudière ; bible §5, époque 3)
    yc = -0.26
    K.box(-1.20, -0.46, yc - 0.16, yc + 0.16, zb, zb + 0.10, fonte, "berceau", bevel=0.01)
    K.lathe((-1.20, yc, 0.98), [(0, 0.0), (0.0, 0.20), (0.06, 0.22), (0.66, 0.22), (0.72, 0.20), (0.72, 0.0)],
            cuivre, "cylindre_vapeur", verts=32, axis=(1, 0, 0))
    for x in (-1.14, -0.54):
        K.torus(x, yc, 0.98, 0.222, 0.016, laiton, "bride_cylindre", axis="x")
    K.rod((-0.48, yc, 0.98), (-0.26, yc, 0.98), 0.03, acier, "tige_piston")
    for z in (0.90, 1.06):
        K.box(-0.40, -0.16, yc - 0.08, yc + 0.08, z - 0.015, z + 0.015, acier, "glissiere", bevel=0)
    K.box(-0.30, -0.20, yc - 0.07, yc + 0.07, 0.91, 1.05, laiton, "crosse", bevel=0.008)
    cx, cz, cr = -0.10, 1.18, 0.14
    pin = (cx + cr * math.cos(ph + 2.4), -0.06, cz + cr * math.sin(ph + 2.4))
    K.rod((-0.24, yc, 0.98), pin, 0.026, acier, "bielle")
    K.rod((cx, -0.52, cz), (cx, 0.10, cz), 0.04, acier, "arbre_manivelle")
    for y in (-0.48, 0.06):
        K.box(cx - 0.08, cx + 0.08, y - 0.05, y + 0.05, zb, cz + 0.06, fonte, "palier", bevel=0.01)
    K.wheel((cx, -0.20, cz), "y", 0.40, 0.07, 6, fonte, acier, "volant", phase=ph)
    K.rod((cx, -0.08, cz), (cx, -0.02, cz), 0.07, laiton, "plateau_manivelle", verts=24)
    K.rod((cx, 0.10, cz), (cx, 0.16, cz), 0.12, laiton, "poulie", verts=28)
    for dx in (-0.11, 0.11):
        K.beam((cx + dx, 0.13, cz), (cx + dx, 0.70, zb + 0.06), 0.012, 0.05, cuir, "courroie")
    K.rod((cx, 0.66, zb + 0.06), (cx, 0.74, zb + 0.06), 0.10, laiton, "poulie_basse", verts=24)
    H(K, -0.62, 1.55, 0.30, "#FFC060", 0.55)
    H(K, bx, by + 0.62, 0.86, "#FFC060", 0.45)
    if piece:
        # régulateur à boules de Watt au sommet du bâti (arrière gauche), +0,30 au-dessus de l'enveloppe
        K.module = "piece"
        gx, gy = -0.78, -0.30
        K.cyl(gx, gy, zb, zb + 0.14, 0.10, fonte, "socle_regulateur")
        K.cyl(gx, gy, zb + 0.14, 2.20, 0.075, laiton, "colonne_regulateur")
        K.rod((gx, gy, 2.20), (gx, gy, 2.70), 0.018, acier, "broche")
        K.cyl(gx, gy, 2.68, 2.76, 0.05, laiton, "chapeau_regulateur", r2=0.02)
        K.cyl(gx, gy, 2.38, 2.46, 0.06, laiton, "manchon")
        for s in (-1, 1):
            ball = (gx + s * 0.27, gy, 2.34)
            K.rod((gx, gy, 2.66), ball, 0.018, acier, "bras_boule")
            K.rod((gx, gy, 2.44), (gx + s * 0.15, gy, 2.50), 0.013, acier, "biellette")
            K.sphere(ball[0], ball[1], ball[2], 0.11, laiton, "boule")


# ------------------------------------------------------------------------------------------------
# Époque 4 · Pétrole : presse hydraulique (portique jaune, vérin), cuves latérales, garde-corps
# ------------------------------------------------------------------------------------------------
def e04(K, t, piece):
    K.gain = 0.62    # photométrie : p50 mesuré 75 -> 60 (bible §1.5, ±10)
    jaune = K.metal("e4_jaune", "#8C7A3A", k=1.6, rough=0.5, metallic=0.25, grain=0.18, rust="#4A3A28",
                    rust_amount=0.25, dirt=0.5, seed=41)
    galva = K.metal("e4_galva", "#6E7378", k=1.55, rough=0.38, metallic=0.75, grain=0.22, grain_scale=80.0,
                    dirt=0.4, seed=42)
    noir = K.metal("e4_noir", "#1E1E1E", k=1.5, rough=0.5, metallic=0.3, grain=0.15, dirt=0.3, seed=43)
    chrome = K.metal("e4_tige", "#B8BCC0", k=1.2, rough=0.15, metallic=1.0, grain=0.05, dirt=0.0, seed=44)
    caillebotis = K.metal("e4_caillebotis", "#6E7378", k=1.2, rough=0.55, metallic=0.6, grain=0.5, grain_scale=140.0,
                          dirt=0.6, seed=45)
    orange = K.emit("e4_voyant", "#FF8C1A", strength=1.4, base="#3A2008")
    flamme = K.emit("e4_flamme", "#FFA030", strength=2.2, base="#FF8C1A")
    K.module = "corps"
    # Silhouette (correction V3 du 22/10 : rupture d'ère) : caisson central ÉTROIT et bas, deux cuves horizontales
    # (axe nord-sud) DÉTACHÉES de chaque côté par un jour, plus basses que lui ; portique en Π à deux fenêtres ouvertes
    # au-dessus ; torchère fine au coin arrière gauche ; passerelle à garde-corps (lignes fines) sur l'avant.
    zc = 0.72
    K.box(-0.64, 0.64, -0.66, 1.40, 0.0, zc, galva, "caisson", bevel=0.02)
    for i in range(7):
        x0 = -0.64 + i * 0.183
        K.box(x0, x0 + 0.183, 1.40, 1.415, 0.04, 0.18, jaune if i % 2 == 0 else noir, "bande_danger", bevel=0)
    K.box(-0.46, 0.46, 1.40, 1.42, 0.28, 0.62, noir, "panneau", bevel=0.006)
    for x in (-0.34, 0.10):
        K.box(x, x + 0.24, 1.42, 1.432, 0.36, 0.54, orange, "voyant", bevel=0)
    # cuves latérales horizontales sur selles (kit d'époque 4)
    for s_ in (-1, 1):
        x = s_ * 1.02
        start, L = 1.24, 2.40
        prof = [(0, 0), (0.03, 0.17), (0.10, 0.26), (0.22, 0.30), (L - 0.22, 0.30), (L - 0.10, 0.26),
                (L - 0.03, 0.17), (L, 0)]
        K.lathe((x, start, 0.42), prof, jaune, "cuve_laterale", verts=36, axis=(0, 1, 0))
        yb = start - L / R2
        for f in (0.22, 0.78):
            yy = start + (yb - start) * f
            K.torus(x, yy, 0.42, 0.305, 0.022, noir, "bande_cuve", axis="y")
            K.box(x - 0.22, x + 0.22, yy - 0.07, yy + 0.07, 0.0, 0.18, galva, "selle", bevel=0.01)
        K.tube([(x, 0.30, 0.70), (x, 0.30, 0.84), (s_ * 0.66, 0.30, 0.84)], 0.03, galva, "piquage_cuve")
        K.cyl(x, 1.02, 0.70, 0.82, 0.05, galva, "trou_homme_cuve")
    # passerelle à garde-corps sur l'avant du toit (lignes fines : la silhouette reste ouverte)
    K.box(-0.62, 0.62, 0.62, 1.38, zc, zc + 0.02, caillebotis, "caillebotis", bevel=0)
    for i in range(8):
        y = 0.66 + i * 0.09
        K.box(-0.62, 0.62, y - 0.008, y + 0.008, zc + 0.02, zc + 0.03, noir, "lame_caillebotis", bevel=0)
    posts = [(-0.60, 1.36), (0.0, 1.36), (0.60, 1.36), (-0.60, 0.64), (0.60, 0.64)]
    for x, y in posts:
        K.cyl(x, y, zc, zc + 0.32, 0.016, jaune, "poteau_garde_corps", verts=8, bevel=0)
    for z in (zc + 0.16, zc + 0.32):
        K.rod((-0.60, 1.36, z), (0.60, 1.36, z), 0.013, jaune, "lisse", verts=8)
        for s_ in (-1, 1):
            K.rod((s_ * 0.60, 1.36, z), (s_ * 0.60, 0.64, z), 0.013, jaune, "lisse", verts=8)
    # échelle (kit) sur la cuve gauche, vanne à volant sur le toit
    for dx in (-0.08, 0.08):
        K.rod((-1.02 + dx, 1.30, 0.0), (-1.02 + dx, 1.10, 0.78), 0.012, jaune, "montant_echelle", verts=8)
    for k in range(5):
        z = 0.12 + k * 0.14
        K.rod((-1.10, 1.30 - z * 0.26, z), (-0.94, 1.30 - z * 0.26, z), 0.009, jaune, "barreau", verts=6)
    K.cyl(0.36, 0.95, zc, zc + 0.20, 0.035, galva, "colonne_vanne")
    K.torus(0.36, 0.95, zc + 0.22, 0.09, 0.014, jaune, "volant_vanne")
    # torchère (kit d'époque 4) au coin arrière gauche : tige fine, brûleur et flamme (animée en phase 2)
    K.cyl(-0.98, -0.80, 0.0, 0.08, 0.10, galva, "bride_torchere")
    K.cyl(-0.98, -0.80, 0.08, 1.92, 0.035, galva, "tige_torchere", verts=12)
    for z in (0.60, 1.20, 1.60):
        K.torus(-0.98, -0.80, z, 0.037, 0.008, noir, "collier_torchere", minor_seg=6)
    K.cyl(-0.98, -0.80, 1.90, 1.96, 0.05, noir, "bruleur_torchere", verts=12)
    K.tube([(-0.98, -0.80, 0.30), (-0.70, -0.70, 0.30), (-0.62, -0.62, 0.40)], 0.025, galva, "conduite_torchere")
    # portique en Π au centre arrière du toit : montants et traverse, deux fenêtres ouvertes à l'écran
    yp = -0.10
    for s_ in (-1, 1):
        K.box(s_ * 0.56 - 0.07, s_ * 0.56 + 0.07, yp - 0.07, yp + 0.07, zc, 2.30, jaune, "montant_portique",
              bevel=0.01)
        K.box(s_ * 0.56 - 0.075, s_ * 0.56 + 0.075, yp + 0.07, yp + 0.085, 1.50, 1.74, orange, "voyant_portique",
              bevel=0)
    K.box(-0.66, 0.66, yp - 0.08, yp + 0.08, 2.28, 2.40, jaune, "traverse_portique", bevel=0.012)
    for i in range(6):
        x0 = -0.64 + i * 0.213
        if i % 2:
            K.box(x0, x0 + 0.213, yp + 0.08, yp + 0.09, 2.30, 2.38, noir, "bande_traverse", bevel=0)
    K.module = "meca"
    K.cyl(-0.98, -0.80, 1.96, 2.18, 0.065, flamme, "flamme_torchere", verts=12, r2=0.008)
    H(K, -0.98, -0.80, 2.05, "#FF8C1A", 0.25)
    K.cyl(0.0, yp, 1.58, 2.28, 0.16, galva, "verin", verts=32)
    K.torus(0.0, yp, 1.68, 0.162, 0.016, noir, "bague_verin")
    K.cyl(0.0, yp, 1.18, 1.60, 0.065, chrome, "tige_verin")
    K.box(-0.28, 0.28, yp - 0.15, yp + 0.15, 1.04, 1.20, noir, "tete_presse", bevel=0.012)
    K.box(-0.40, 0.40, yp - 0.20, yp + 0.20, zc, zc + 0.08, galva, "matrice", bevel=0.008)
    K.box(-0.22, 0.22, yp - 0.12, yp + 0.12, zc + 0.08, zc + 0.12, jaune, "piece_emboutie", bevel=0.004)
    for s_ in (-1, 1):
        K.tube([(s_ * 1.02, -0.40, 0.72), (s_ * 0.80, -0.30, 1.10), (s_ * 0.42, yp - 0.04, 1.58),
                (s_ * 0.15, yp, 1.66)], 0.024, noir, "flexible")
    H(K, 0.0, 1.58, 0.45, "#FF8C1A", 0.5)
    for s_ in (-1, 1):
        H(K, s_ * 0.56, yp + 0.25, 1.62, "#FF8C1A", 0.25)
    if piece:
        # cuve de pression verticale au coin avant droit : dépasse à droite (x jusqu'à 1,48) et au-dessus des cuves
        K.module = "piece"
        X, Y = 1.24, 1.12
        K.lathe((X, Y, 0.0), [(0, 0.24), (0.10, 0.24), (0.12, 0.22), (1.55, 0.22), (1.70, 0.17), (1.80, 0.10),
                               (1.84, 0.0)], jaune, "cuve_pression", verts=36)
        for z in (0.35, 0.95, 1.45):
            K.torus(X, Y, z, 0.222, 0.02, noir, "bande_cuve_pression")
        K.rod((X, Y + 0.13, 0.72), (X, Y + 0.17, 0.72), 0.10, galva, "manometre", verts=24)
        K.rod((X, Y + 0.17, 0.72), (X, Y + 0.18, 0.72), 0.09, orange, "cadran", verts=24)
        K.cyl(X, Y, 1.84, 1.94, 0.03, galva, "vanne")
        K.torus(X, Y, 1.96, 0.07, 0.013, noir, "volant_vanne")
        K.tube([(X - 0.18, Y, 1.25), (0.86, Y - 0.05, 1.25), (0.62, 0.90, 0.90)], 0.03, galva, "conduite")
        H(K, X, Y + 0.30, 0.72, "#FF8C1A", 0.2)


# ------------------------------------------------------------------------------------------------
# Époque 5 · Volcan : presse blindée en gradins (tronc de pyramide), capot incliné, fente de marteau
# ------------------------------------------------------------------------------------------------
def e05(K, t, piece):
    K.gain = 0.66    # photométrie : p50 mesuré 52 -> 42 (bible §1.5, ±10)
    tung = K.metal("e5_tungstene", "#3E3D42", k=1.9, rough=0.38, metallic=0.75, grain=0.2, rust="#5A3A2A",
                   rust_amount=0.35, dirt=0.55, seed=51)
    rouille = K.metal("e5_rouille", "#5A3A2A", k=1.5, rough=0.6, metallic=0.4, grain=0.3, dirt=0.4, seed=52)
    rivet = K.metal("e5_rivet", "#6A6870", k=1.8, rough=0.3, metallic=0.9, grain=0.08, dirt=0.2, seed=53)
    basalte = K.metal("e5_basalte", "#2A2826", k=1.6, rough=0.75, metallic=0.1, grain=0.4, grain_scale=20.0,
                      dirt=0.4, seed=54)
    braise = K.emit("e5_braise", "#FF4A10", strength=1.5, base="#200804")
    K.module = "corps"
    # VRAI tronc de pyramide à l'écran (correction V3 du 22/10) : la base recule (bord arrière à ty -0,30) pour que
    # chaque gradin se projette AU-DESSUS du précédent ; le sommet du dernier gradin fait 40 % de la base (bible
    # §5 : « troncs de pyramide », sommet ≤ 70 %). Les flancs de la base restent en retrait de l'emprise (±1,10) :
    # les contreforts du niveau pair viennent s'y loger.
    tiers = [(0.00, 0.45, (1.12, -0.30, 1.22), (0.94, -0.18, 1.08)),
             (0.45, 0.95, (0.86, -0.12, 0.98), (0.64, 0.00, 0.82)),
             (0.95, 1.55, (0.60, 0.04, 0.78), (0.38, 0.14, 0.62))]
    for i, (z0, z1, (bx, by0, by1), (tx_, ty0, ty1)) in enumerate(tiers):
        bot = [(-bx, by0), (bx, by0), (bx, by1), (-bx, by1)]
        top = [(-tx_, ty0), (tx_, ty0), (tx_, ty1), (-tx_, ty1)]
        K.prism(bot, z0, z1, tung, "gradin", top=top, bevel=0.02)
        K.rivets((-bx + 0.10, by1 + 0.01, z0 + 0.05), (bx - 0.10, by1 + 0.01, z0 + 0.05), 8 - 2 * i, 0.028, rivet,
                 "rivets_lourds")
        for x0, x1 in ((-0.75, -0.35), (-0.18, 0.18), (0.35, 0.75)):
            slope_strip(K, x0 * bx / 1.12, x1 * bx / 1.12, (by1, z0), (ty1, z1), 0.36, 0.70, braise, "fente_braise")
        # blindage en écailles (signature de l'époque) : deux rangées décalées, sous et au-dessus des fentes
        ecailles(K, (by1, z0), (ty1, z1), bx, tx_, 0.04, 0.40, 6 - i, rouille if i == 0 else tung, 0.0)
        ecailles(K, (by1, z0), (ty1, z1), bx, tx_, 0.68, 0.98, 5 - i, tung, 0.5)
    # capot incliné du marteau (sommet de la pyramide)
    hb = [(-0.34, 0.16), (0.34, 0.16), (0.34, 0.60), (-0.34, 0.60)]
    ht = [(-0.24, 0.20), (0.24, 0.20), (0.24, 0.40), (-0.24, 0.40)]
    K.prism(hb, 1.55, 2.40, tung, "capot", top=ht, bevel=0.02)
    slope_strip(K, -0.22, 0.22, (0.60, 1.55), (0.40, 2.40), 0.30, 0.62, braise, "fente_marteau")
    # pointes de basalte (kit d'époque) aux coins ARRIÈRE, penchées vers l'extérieur : colonne hexagonale puis
    # aiguille (2 événements de silhouette, de part et d'autre du marteau)
    for s in (-1, 1):
        K.cyl(s * 1.16, -0.62, 0.0, 0.62, 0.12, basalte, "colonne_basalte", verts=6)
        K.rod((s * 1.16, -0.62, 0.58), (s * 1.32, -0.70, 1.86), 0.10, basalte, "pointe_basalte", verts=6, r2=0.012)
        K.torus(s * 1.16, -0.62, 0.58, 0.12, 0.025, rivet, "frette_colonne", minor_seg=6)
    K.module = "meca"
    # marteau-pilon : piston et tête qui montent et descendent dans le capot (sommet -1,97 à l'écran : O 0,47)
    K.cyl(0.0, 0.29, 2.40, 2.92, 0.13, rouille, "piston_marteau", verts=8)
    K.cyl(0.0, 0.29, 2.92, 3.02, 0.17, tung, "tete_piston", verts=8)
    for s in (-1, 1):
        K.rod((s * 0.22, 0.29, 2.40), (s * 0.12, 0.29, 2.88), 0.03, rivet, "glissiere_marteau")
    H(K, 0.0, 1.62, 0.50, "#FF4A10", 0.6)
    H(K, 0.0, 0.85, 1.75, "#FF4A10", 0.4)
    if piece:
        K.module = "piece"
        for s in (-1, 1):
            for y0, y1 in ((0.62, 1.12), (-0.24, 0.26)):     # dans les retraits des flancs, devant les basaltes
                poly = [(s * 1.04, 0.0), (s * 1.40, 0.0), (s * 1.40, 0.14), (s * 0.98, 1.00)]
                K.plate(poly, y0, y1, rouille, "contrefort", bevel=0.012)
                K.rivets((s * 1.37, y1 + 0.01, 0.07), (s * 1.12, y1 + 0.01, 0.90), 4, 0.022, rivet, "rivets_contrefort")


# ------------------------------------------------------------------------------------------------
# Époque 6 · Électricité : bras de soudure à l'arc, piles d'isolateurs sur bobines aux quatre coins
# ------------------------------------------------------------------------------------------------
def e06(K, t, piece):
    K.gain = 0.58    # photométrie : p50 mesuré 84 -> 64 (bible §1.5, ±10)
    cera = K.metal("e6_ceramique", "#D8D4C8", k=0.95, rough=0.35, metallic=0.0, grain=0.12, dirt=0.55, rust="#8A7A5A",
                   rust_amount=0.2, seed=61)
    cuivre = K.metal("e6_cuivre", "#B0703A", k=1.25, rough=0.3, metallic=0.9, grain=0.15, dirt=0.4, seed=62)
    acier = K.metal("e6_acier", "#5C6168", k=1.5, rough=0.4, metallic=0.6, grain=0.14, dirt=0.45, seed=63)
    noir = K.metal("e6_noir", "#202022", k=1.4, rough=0.5, metallic=0.2, dirt=0.3, seed=64)
    cyan = K.emit("e6_arc", "#60D0FF", strength=1.6, base="#102030")
    K.module = "corps"
    # Silhouette (correction V3 du 22/10) : caisson ÉTROIT et bas entre quatre piles d'isolateurs détachées (jours
    # verticaux) ; les deux piles arrière, le bras de soudure au centre : 3 événements de silhouette.
    zr = 0.66
    K.box(-0.82, 0.82, -0.66, 1.44, 0.0, 0.10, noir, "plinthe", bevel=0.01)
    K.box(-0.78, 0.78, -0.62, 1.40, 0.10, zr, acier, "caisson", bevel=0.02)
    K.box(-0.52, 0.52, 1.40, 1.415, 0.20, 0.56, noir, "panneau", bevel=0.006)
    for x in (-0.36, -0.12, 0.12, 0.36):
        K.box(x - 0.075, x + 0.075, 1.415, 1.425, 0.28, 0.48, cyan, "voyant", bevel=0)
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
    # toit : transformateur à ailettes (arrière gauche), barres de cuivre vers les piles, gabarit de soudure
    K.box(-0.70, -0.24, -0.56, -0.20, zr, zr + 0.46, acier, "transformateur", bevel=0.015)
    for i in range(6):
        x = -0.66 + i * 0.076
        K.box(x - 0.012, x + 0.012, -0.20, -0.12, zr + 0.04, zr + 0.42, acier, "ailette", bevel=0)
    for x in (-0.60, -0.47, -0.34):
        K.cyl(x, -0.38, zr + 0.46, zr + 0.52, 0.035, cera, "traversee", verts=16)
        K.cyl(x, -0.38, zr + 0.52, zr + 0.60, 0.022, cuivre, "borne_traversee", verts=12)
    for (x, y, zc) in ((-1.12, -0.52, 0.95), (1.12, -0.52, 0.95)):
        K.tube([(x * 0.42, -0.38, zr + 0.56), (x * 0.70, -0.45, zr + 0.40), (x * 0.94, -0.52, zc + 0.05)], 0.022,
               cuivre, "barre_cuivre")
    K.box(0.10, 0.64, 0.40, 0.86, zr, zr + 0.04, noir, "gabarit", bevel=0.006)
    for x in (0.14, 0.60):
        K.box(x - 0.03, x + 0.03, 0.44, 0.82, zr + 0.04, zr + 0.12, acier, "bride_gabarit", bevel=0.004)
    # éclateur (kit d'époque 6) sur l'avant droit du toit
    for x in (0.52, 0.72):
        K.cyl(x, 0.20, zr, zr + 0.30, 0.03, cera, "pied_eclateur", verts=12)
        K.sphere(x, 0.20, zr + 0.34, 0.05, cuivre, "boule_eclateur")
    K.module = "meca"
    # arc électrique entre les bornes des deux piles arrière (signature : arcs cyan), en zigzag déterministe
    import random
    rnd = random.Random(611 + int(t * 1000))

    def arc(a, b, n, sag, name):
        pts = []
        for i in range(n + 1):
            f = i / float(n)
            jit = 0 < i < n
            pts.append((a[0] + (b[0] - a[0]) * f + (rnd.uniform(-0.03, 0.03) if jit else 0.0),
                        a[1] + (b[1] - a[1]) * f + (rnd.uniform(-0.04, 0.04) if jit else 0.0),
                        a[2] + (b[2] - a[2]) * f - sag * math.sin(math.pi * f) + (rnd.uniform(-0.05, 0.05) if jit else 0.0)))
        K.tube(pts, 0.032, cyan, name)
    # arcs (signature : arcs cyan) : de la borne de la pile arrière gauche à la traversée du transformateur, de la
    # pile arrière droite à l'éclateur
    arc((-1.12, -0.52, 2.16), (-0.47, -0.38, zr + 0.62), 9, 0.10, "arc_gauche")
    arc((1.12, -0.52, 2.16), (0.72, 0.20, zr + 0.38), 9, 0.08, "arc_droit")
    H(K, -0.80, -0.20, 1.70, "#60D0FF", 0.1)
    H(K, 0.92, 0.0, 1.50, "#60D0FF", 0.1)
    K.cyl(0.0, 0.30, zr, zr + 0.20, 0.24, noir, "tourelle_bras")
    K.cyl(0.0, 0.30, zr + 0.20, zr + 0.32, 0.15, acier, "base_epaule")
    sh, el, wr, tip = (0.0, 0.30, zr + 0.36), (-0.20, -0.20, 2.36), (0.30, 0.50, 1.62), (0.38, 0.62, 1.10)
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
    K.box(0.15, 0.58, 0.45, 0.80, zr + 0.04, zr + 0.10, acier, "piece_soudee", bevel=0.004)
    K.tube([(0.0, 0.30, zr + 0.22), (-0.30, 0.10, 1.20), (-0.26, -0.10, 2.10), (0.05, 0.25, 1.90), (0.32, 0.52, 1.66)],
           0.016, noir, "cable")
    H(K, tip[0], tip[1] + 0.12, tip[2], "#60D0FF", 0.55)
    H(K, 0.0, 1.62, 0.55, "#60D0FF", 0.3)
    if piece:
        K.module = "piece"
        cx, cy, cz = 0.0, -0.40, 2.17
        z = zr
        disc = True
        while z < 1.65:
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
    # saturation de la couche principale mesurée 0,45 à 0,47 le 22/10 (règle ≤ 0,45) : albédos désaturés, la couleur
    # vive reste dans l'émission
    cristal = K.metal("e7_cristal", "#8E78C0", k=0.9, rough=0.12, metallic=0.0, grain=0.06, dirt=0.15, seed=73)
    lum = K.emit("e7_cristal_lumineux", "#B070FF", strength=0.42, base="#6A5890")
    K.module = "corps"
    # Silhouette (correction V3 du 22/10) : corps de pierre ABAISSÉ (0,28 au lieu de 0,55) et peu profond, d'où une
    # couronne de cristaux qui se détache seule au-dessus de l'ancien caisson ; trois grands cristaux
    # asymétriques (3 événements), les petits restent bas, sur l'avant et les flancs.
    zb = 0.28
    bot = [(-1.20, -0.22), (1.20, -0.22), (1.20, 1.38), (-1.20, 1.38)]
    top = [(-1.12, -0.14), (1.12, -0.14), (1.12, 1.28), (-1.12, 1.28)]
    K.prism(bot, 0.0, zb, pierre, "corps_pierre", top=top, bevel=0.03)
    K.box(-1.14, 1.14, -0.16, 1.30, zb - 0.04, zb + 0.04, bronze, "bandeau", bevel=0.01)
    for x in (-1.16, 1.16):
        for y in (-0.18, 1.34):
            K.box(x - 0.05, x + 0.05, y - 0.04, y + 0.04, 0.0, zb + 0.06, bronze, "montant", bevel=0.008)
    K.cyl(0.0, 0.40, zb, zb + 0.16, 0.86, bronze, "sertissure", verts=8)
    zs = zb + 0.12
    crystals = [  # (x, y) au sol, hauteur, rayon, inclinaison (vers l'est, vers le sud) en degrés, lumineux
        ((-0.06, 0.18), 3.15, 0.17, (-4, -4), True),      # A : le plus haut (O 0,68)
        ((0.76, 0.30), 2.35, 0.15, (17, -6), False),       # B : à droite
        ((-0.80, 0.36), 2.00, 0.14, (-19, -4), True),      # C : à gauche
        # petits cristaux, bas : avant et flancs (ne créent pas d'autre événement)
        ((0.30, 0.82), 0.80, 0.10, (10, 18), False), ((-0.36, 0.86), 0.70, 0.09, (-12, 20), True),
        ((0.88, 0.80), 0.62, 0.09, (26, 14), False), ((-0.92, 0.84), 0.55, 0.08, (-26, 14), False),
        ((0.20, 0.52), 1.10, 0.10, (8, 6), False), ((-0.40, 0.48), 1.00, 0.10, (-10, 8), False)]
    for i, ((x, y), h, r, (te, ts), lit) in enumerate(crystals):
        K.crystal((x, y, zs), h, r, lum if lit else cristal, "cristal",
                  tilt=(math.radians(te), math.radians(ts)), spin=0.37 * i)
    K.module = "meca"
    # tourniquet de bronze au pied des cristaux (rotation en phase 2) et prisme focal
    K.cyl(0.0, 0.62, zs, zs + 0.30, 0.06, bronze, "axe_tourniquet")
    K.torus(0.0, 0.62, zs + 0.28, 0.42, 0.03, bronze, "anneau_tourniquet")
    for k in range(3):
        a = TAU * k / 3 + TAU * t
        K.rod((0.0, 0.62, zs + 0.28), (0.42 * math.cos(a), 0.62 - 0.42 * math.sin(a) / R2, zs + 0.28), 0.02, bronze,
              "rayon")
    for k in range(3):
        a = TAU * k / 3 + TAU * t + 0.5
        K.crystal((0.42 * math.cos(a), 0.62 - 0.42 * math.sin(a) / R2, zs + 0.30), 0.36, 0.085, lum, "prisme",
                  spin=0.3 * k)
    H(K, 0.0, 0.95, 1.00, "#B070FF", 0.5)
    H(K, -0.20, 0.10, 1.70, "#B070FF", 0.5)
    if piece:
        K.module = "piece"
        K.cyl(0.32, -0.02, zs, zs + 0.16, 0.26, bronze, "collier_grand_cristal", verts=8)
        K.crystal((0.32, -0.02, zs + 0.06), 3.10, 0.24, lum, "grand_cristal", tilt=(0.06, -0.04), spin=0.5)
        H(K, 0.30, 0.3, 2.2, "#B070FF", 0.2)


# ------------------------------------------------------------------------------------------------
# Époque 8 · Marais : corps arrondi vert-de-gris, trois fioles-réacteurs bouillonnantes, conduits
# ------------------------------------------------------------------------------------------------
def e08(K, t, piece):
    K.gain = 0.36    # photométrie : p50 mesuré 87 puis 70 -> 60 (bible §1.5, ±10)
    vdg = K.metal("e8_vert_de_gris", "#4F6B5A", k=1.55, rough=0.45, metallic=0.5, grain=0.22, rust="#2E4038",
                  rust_amount=0.3, dirt=0.5, seed=81)
    cuivre = K.metal("e8_cuivre", "#8A5A3A", k=1.5, rough=0.3, metallic=0.85, grain=0.12, rust="#4F6B5A",
                     rust_amount=0.35, dirt=0.4, seed=82)
    caout = K.flat("e8_caoutchouc", "#2A2A28", k=1.3, rough=0.7)
    liquide = K.emit("e8_liquide", "#A8FF3A", strength=1.1, base="#4A7A20")
    K.module = "corps"
    # Silhouette (correction V3 du 22/10) : coque ARRONDIE (rayon 0,30 : coins coupés à l'écran) posée sur quatre
    # pieds ronds, plus étroite que l'emprise ; deux cuves de verre DÉTACHÉES sur les flancs (jours verticaux) ; trois
    # fioles-réacteurs sur le toit, les deux arrière hautes (4 événements avec les cuves).
    zh0, zh1 = 0.12, 0.80
    for x in (-0.66, 0.66):
        for y in (-0.16, 1.06):
            K.cyl(x, y, 0.0, zh0 + 0.06, 0.13, cuivre, "pied_rond")
    K.rbox(-0.96, 0.96, -0.42, 1.32, zh0, zh1, vdg, "coque", r=0.30, seg=6)
    K.rbox(-0.99, 0.99, -0.45, 1.35, zh0 + 0.18, zh0 + 0.26, cuivre, "ceinture", r=0.10)
    K.rod((0.0, 1.30, 0.46), (0.0, 1.37, 0.46), 0.21, cuivre, "cadre_hublot", verts=32)
    K.rod((0.0, 1.36, 0.46), (0.0, 1.385, 0.46), 0.165, liquide, "hublot", verts=32)
    K.module = "meca"
    flasks = [(-0.58, -0.14, 0.33, 2.16), (0.58, -0.14, 0.33, 2.16), (0.0, 0.66, 0.30, 1.30)]
    for i, (x, y, Rb, top) in enumerate(flasks):
        K.cyl(x, y, zh1 - 0.06, zh1 + 0.06, Rb * 0.72, cuivre, "collier_fiole")
        glass = K.emit_below("e8_verre_%d" % i, "#4A6A28", "#A8FF3A", level=Rb * 0.92, strength=1.0)
        K.lathe((x, y, zh1), flask_profile(Rb, 0.085, top), glass, "fiole", verts=36)
        K.torus(x, y, zh1 + top - 0.30, 0.10, 0.02, cuivre, "bague_col")
        K.tube([(x, y, zh1 + top - 0.32), (x * 1.25, y + 0.25, zh1 + top - 0.55), (x * 1.30, y + 0.50, zh1 + 0.16)],
               0.024, caout, "condenseur")
        H(K, x, y + 0.3, zh1 + Rb, "#A8FF3A", 0.25)
    K.tube([(-0.58, -0.14, zh1 + 0.08), (0.0, 0.66, zh1 + 0.08), (0.58, -0.14, zh1 + 0.08)], 0.035, cuivre,
           "conduit_fioles")
    H(K, 0.0, 1.62, 0.46, "#A8FF3A", 0.15)
    # cuves de verre cylindriques (kit d'époque 8) DÉTACHÉES des flancs de la coque (jour de 0,08) : elles dépassent
    # latéralement (L de l'époque 2,83) et forment deux événements de silhouette
    K.module = "corps"
    for s_ in (-1, 1):
        X = s_ * 1.26
        glass = K.emit_below("e8_cuve_%d" % (s_ + 1), "#4A6A28", "#A8FF3A", level=0.66, strength=0.9)
        K.cyl(X, 0.56, 0.06, 1.30, 0.15, glass, "cuve_verre", verts=32)
        for z in (0.0, 1.28):
            K.cyl(X, 0.56, z, z + 0.08, 0.165, cuivre, "frette_cuve", verts=32)
        K.sphere(X, 0.56, 1.40, 0.08, cuivre, "bouchon_cuve")
        K.tube([(X, 0.56, 0.30), (s_ * 1.10, 0.56, 0.30), (s_ * 0.92, 0.56, 0.30)], 0.03, caout, "conduit_cuve")
        H(K, X, 0.90, 0.40, "#A8FF3A", 0.1)
    if piece:
        K.module = "piece"
        K.cyl(0.0, -0.05, zh1, zh1 + 0.22, 0.20, cuivre, "pied_bulbe")
        glass = K.emit_below("e8_verre_grand", "#4A6A28", "#A8FF3A", level=0.46 * 0.92, strength=1.0)
        K.lathe((0.0, -0.05, zh1 + 0.20), flask_profile(0.46, 0.10, 2.42, base_r=0.20), glass, "grand_bulbe",
                verts=40)
        pts = []
        for i in range(85):
            f = i / 84.0
            a = TAU * 3.5 * f
            pts.append((0.50 * math.cos(a), -0.05 - 0.50 * math.sin(a) / R2, zh1 + 0.24 + 0.80 * f))
        K.tube(pts, 0.022, cuivre, "serpentin")
        H(K, 0.0, 0.3, 1.4, "#A8FF3A", 0.2)


# ------------------------------------------------------------------------------------------------
# Époque 9 · Atome : cellule chaude plombée octogonale, hublot vert, deux bras télémanipulateurs
# ------------------------------------------------------------------------------------------------
def e09(K, t, piece):
    K.gain = 0.52    # photométrie : p50 mesuré 78 -> 56 (bible §1.5, ±10)
    plomb = K.metal("e9_plomb", "#4A5058", k=1.7, rough=0.45, metallic=0.6, grain=0.16, dirt=0.55, rust="#3A3E36",
                    rust_amount=0.2, seed=91)
    jaune = K.metal("e9_jaune", "#C9A227", k=1.05, rough=0.5, metallic=0.1, grain=0.18, dirt=0.5, rust="#4A3A20",
                    rust_amount=0.2, seed=92)
    beton = K.metal("e9_beton", "#7A7670", k=1.15, rough=0.9, metallic=0.0, grain=0.3, grain_scale=25.0, dirt=0.4,
                    seed=93)
    noir = K.flat("e9_noir", "#1A1A1A", rough=0.6)
    vert = K.emit("e9_uranium", "#5CFF4A", strength=1.3, base="#1A4A14")
    K.module = "corps"
    # Silhouette (correction V3 du 22/10) : cellule octogonale plus étroite (±1,04) aux chanfreins de 0,42 (coins
    # coupés VISIBLES dans le masque : bas avant et haut arrière) ; mât de balise et cheminée de ventilation posés au
    # sol HORS de la cellule, aux coins arrière (jours latéraux) ; 4 événements : mât, deux coudes, cheminée.
    zc, zt = 0.92, 1.16
    K.prism(octo(-1.10, 1.10, -0.56, 1.38, 0.44), 0.0, 0.14, beton, "socle_beton")
    K.prism(octo(-1.04, 1.04, -0.50, 1.32, 0.42), 0.14, zc, plomb, "cellule")
    K.prism(octo(-1.04, 1.04, -0.50, 1.32, 0.42), zc, zt, plomb, "chanfrein", top=octo(-0.80, 0.80, -0.28, 1.08, 0.32))
    for i in range(7):
        x0 = -0.70 + i * 0.20
        K.box(x0, x0 + 0.20, 1.32, 1.332, 0.20, 0.32, jaune if i % 2 == 0 else noir, "bande_danger", bevel=0)
    K.torus(0.18, 1.33, 0.62, 0.24, 0.05, jaune, "cadre_hublot", axis="y")
    K.rod((0.18, 1.30, 0.62), (0.18, 1.34, 0.62), 0.22, vert, "hublot", verts=40)
    K.rod((-0.48, 1.32, 0.62), (-0.48, 1.335, 0.62), 0.13, jaune, "trefle_fond", verts=28)
    for k in range(3):
        a = math.pi / 2 + TAU * k / 3
        K.rod((-0.48 + 0.033 * math.cos(a), 1.338, 0.62 + 0.033 * math.sin(a)),
              (-0.48 + 0.11 * math.cos(a), 1.338, 0.62 + 0.11 * math.sin(a)), 0.033, noir, "trefle_pale", r2=0.05)
    K.rod((-0.48, 1.335, 0.62), (-0.48, 1.34, 0.62), 0.023, noir, "trefle_centre")
    slope_strip(K, -0.48, 0.48, (1.32, zc), (1.08, zt), 0.28, 0.72, vert, "event_vert")
    # toit : tourelle octogonale à hublot de cœur (vert uranium), conduits annelés vers les manipulateurs, trappe
    K.prism(octo(-0.40, 0.40, 0.10, 0.80, 0.14), zt, zt + 0.20, plomb, "tourelle_coeur", bevel=0.012)
    K.cyl(0.0, 0.45, zt + 0.20, zt + 0.225, 0.24, jaune, "cerclage_hublot", verts=40)
    K.cyl(0.0, 0.45, zt + 0.225, zt + 0.24, 0.20, vert, "hublot_coeur", verts=40)
    for k in range(8):
        a = TAU * k / 8 + 0.2
        K.sphere(0.22 * math.cos(a), 0.45 - 0.22 * math.sin(a) / R2, zt + 0.23, 0.016, noir, "boulon_hublot")
    for s_ in (-1, 1):
        pts = [(s_ * 0.38, 0.45, zt + 0.10), (s_ * 0.50, 0.30, zt + 0.10), (s_ * 0.55, 0.0, zt + 0.13),
               (s_ * 0.55, -0.10, zt + 0.23)]
        K.tube(pts, 0.05, beton, "conduit_annele")
    K.box(0.44, 0.76, 0.62, 0.96, zt, zt + 0.04, jaune, "trappe", bevel=0.006)
    K.rod((0.60, 0.79, zt + 0.04), (0.60, 0.79, zt + 0.05), 0.10, noir, "trefle_trappe", verts=24)
    # coins arrière, AU SOL et hors de la cellule : mât de balise rayé (feu vert) à gauche, cheminée de ventilation
    # annelée à chapeau à droite (kit : balise de radiation, conduit annelé)
    K.prism(octo(-1.36, -1.14, -0.84, -0.62, 0.06), 0.0, 0.10, beton, "socle_balise")
    K.cyl(-1.25, -0.73, 0.10, 2.36, 0.05, plomb, "mat_balise", verts=12)
    for i in range(5):
        K.cyl(-1.25, -0.73, 1.66 + i * 0.12, 1.72 + i * 0.12, 0.056, jaune if i % 2 == 0 else noir, "rayure_balise",
              verts=12)
    K.cyl(-1.25, -0.73, 2.36, 2.40, 0.06, jaune, "socle_feu", verts=16)
    K.sphere(-1.25, -0.73, 2.46, 0.065, vert, "feu_balise")
    K.prism(octo(1.12, 1.38, -0.86, -0.60, 0.07), 0.0, 0.10, beton, "socle_ventilation")
    K.cyl(1.25, -0.73, 0.10, 2.10, 0.09, plomb, "cheminee_ventilation", verts=20)
    for z in (0.50, 0.90, 1.30, 1.70, 2.00):
        K.torus(1.25, -0.73, z, 0.093, 0.016, beton, "anneau_ventilation", minor_seg=6)
    K.cyl(1.25, -0.73, 2.16, 2.20, 0.14, plomb, "chapeau_ventilation", verts=20, r2=0.04)
    for k in range(3):
        a = TAU * k / 3
        K.rod((1.25 + 0.08 * math.cos(a), -0.73 - 0.08 * math.sin(a) / R2, 2.10),
              (1.25 + 0.12 * math.cos(a), -0.73 - 0.12 * math.sin(a) / R2, 2.17), 0.008, plomb, "patte_chapeau")
    K.tube([(1.25, -0.73, 0.70), (1.10, -0.60, 0.70), (0.98, -0.45, 0.70)], 0.05, beton, "conduit_ventilation")
    H(K, -1.25, -0.43, 2.45, "#5CFF4A", 0.1)
    K.module = "meca"
    for s in (-1, 1):
        bx, by = s * 0.52, -0.16
        K.cyl(bx, by, zt, zt + 0.42, 0.15, plomb, "colonne_manipulateur", verts=8)
        K.cyl(bx, by, zt + 0.42, zt + 0.48, 0.17, jaune, "collier", verts=8)
        sh, el, wr = (bx, by, zt + 0.57), (s * 0.80, -0.36, 2.70), (s * 0.30, 0.22, 2.20)
        K.sphere(*sh, 0.13, plomb, "epaule")
        K.beam(sh, el, 0.15, 0.15, jaune, "bras_manipulateur")
        K.rod((el[0] - 0.10, el[1], el[2]), (el[0] + 0.10, el[1], el[2]), 0.11, plomb, "coude")
        K.beam(el, wr, 0.12, 0.12, jaune, "avant_bras")
        K.sphere(*wr, 0.08, plomb, "poignet")
        for d in (-0.05, 0.05):
            K.rod(wr, (wr[0] - s * 0.06 + d, wr[1] + 0.14, wr[2] - 0.22), 0.016, noir, "pince")
    H(K, 0.18, 1.57, 0.62, "#5CFF4A", 0.6)
    H(K, 0.0, 1.27, 1.25, "#5CFF4A", 0.3)
    if piece:
        # tour de refroidissement miniature (hyperboloïde) au centre arrière du toit : +0,30
        K.module = "piece"
        prof = [(0, 0.38), (0.36, 0.30), (0.84, 0.24), (1.26, 0.235), (1.56, 0.26), (1.80, 0.31)]
        K.lathe((0.0, -0.40, zt), prof, beton, "tour_refroidissement", verts=40, cap1=False)
        K.torus(0.0, -0.40, zt + 1.82, 0.312, 0.02, jaune, "bague_tour")
        K.cyl(0.0, -0.40, zt + 1.78, zt + 1.80, 0.29, vert, "coeur_tour", verts=40)
        H(K, 0.0, -0.1, zt + 1.5, "#5CFF4A", 0.2)


# ------------------------------------------------------------------------------------------------
# Époque 10 · Haute technologie : coque lisse sur pieds courts, dôme, trois bras robotisés articulés
# ------------------------------------------------------------------------------------------------
def e10(K, t, piece):
    K.gain = 0.48    # photométrie : p50 mesuré 117 -> 82 (bible §1.5, ±10)
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
    K.torus(0.0, 0.05, 1.43, 0.63, 0.045, bleu, "anneau_dome")
    K.cyl(-1.02, -0.50, 1.20, 1.30, 0.06, noir, "pied_antenne")
    K.rod((-1.02, -0.50, 1.30), (-1.02, -0.50, 3.60), 0.012, noir, "antenne_fouet")
    K.sphere(-1.02, -0.50, 3.62, 0.065, bleu, "feu_antenne")
    K.module = "meca"
    # trois bras robotisés articulés : les deux arrière DÉPASSENT sur les côtés (coudes hors de la coque, correction
    # V3 du 22/10 : événements de silhouette de l'ère IV), le troisième travaille à l'avant droit
    arms = [((-0.80, -0.30), (-1.38, -0.46, 2.76), (-0.60, 0.02, 2.06), (-0.40, 0.14, 1.80)),
            ((0.80, -0.30), (1.38, -0.46, 2.76), (0.60, 0.02, 2.06), (0.40, 0.14, 1.80)),
            ((0.86, 0.80), (1.24, 0.62, 1.86), (0.56, 0.48, 1.70), (0.40, 0.42, 1.50))]
    for (bx, by), el, wr, tip in arms:
        K.cyl(bx, by, 1.20, 1.30, 0.13, noir, "base_bras")
        K.cyl(bx, by, 1.30, 1.42, 0.10, caren, "pivot")
        sh = (bx, by, 1.48)
        K.sphere(*sh, 0.085, noir, "epaule")
        K.beam(sh, el, 0.17, 0.15, caren, "bras")
        K.sphere(*el, 0.11, noir, "coude")
        K.beam(el, wr, 0.13, 0.12, caren, "avant_bras")
        K.sphere(*wr, 0.07, noir, "poignet")
        K.rod(wr, tip, 0.035, noir, "outil", r2=0.015)
        K.sphere(*tip, 0.08, bleu, "led_outil")
    # radôme (kit d'époque 10) au sommet du dôme : événement central
    K.cyl(0.0, 0.05, 2.02, 2.30, 0.035, noir, "mat_radome")
    K.sphere(0.0, 0.05, 2.42, 0.15, caren, "radome")
    K.torus(0.0, 0.05, 2.42, 0.152, 0.018, bleu, "anneau_radome")
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
        K.sphere(*T(type(base)(feed)), 0.065, bleu, "source")


# ------------------------------------------------------------------------------------------------
# Époque 11 · Titane : portique blanc à ailerons sur quatre pieds en V, côtés ouverts
# ------------------------------------------------------------------------------------------------
def e11(K, t, piece):
    blanc = K.metal("e11_alliage", "#C9C6BE", k=0.45, rough=0.35, metallic=0.35, grain=0.08, grain_scale=70.0,
                    dirt=0.55, rust="#8A8478", rust_amount=0.25, seed=111)
    titane = K.metal("e11_titane", "#8E9AA6", k=1.15, rough=0.3, metallic=0.85, grain=0.1, dirt=0.35, seed=112)
    noir = K.metal("e11_noir", "#26282C", k=1.3, rough=0.45, metallic=0.3, seed=113)
    ligne = K.emit("e11_ligne", "#BFE6FF", strength=0.75, base="#405060")
    K.module = "corps"
    # Portique blanc sur quatre pieds en V, côtés ouverts. Correction V3 du 22/10 : la machine ne doit plus
    # RÉTRÉCIR (aire 4,57 t²) : carénage de toit sur la moitié arrière du portique, membrures et plateau plus forts,
    # cinq ailerons en flèche (5 événements de silhouette, ère IV : 4 à 5).
    zg = 1.30
    for (x, y) in ((-1.12, -0.62), (1.12, -0.62), (-1.12, 1.12), (1.12, 1.12)):
        for dx in (-0.20, 0.20):
            K.cyl(x + dx, y, 0.0, 0.05, 0.08, noir, "patin")
            K.beam((x + dx, y, 0.03), (x, y, zg), 0.11, 0.11, titane, "jambe_v")
        K.box(x - 0.10, x + 0.10, y - 0.08, y + 0.08, zg - 0.10, zg + 0.14, blanc, "noeud", bevel=0.01)
    K.box(-1.22, 1.22, 1.04, 1.20, zg - 0.04, zg + 0.24, blanc, "poutre_avant", bevel=0.012)
    K.box(-1.00, 1.00, 1.20, 1.21, zg, zg + 0.20, ligne, "ligne_avant", bevel=0)
    for x in (-1.12, 1.12):
        K.box(x - 0.09, x + 0.09, -0.62, 1.12, zg - 0.02, zg + 0.22, blanc, "longeron", bevel=0.012)
    # carénage de toit (moitié arrière) : panneau d'alliage blanc, joints noirs
    K.rbox(-1.22, 1.22, -0.72, 0.30, zg, zg + 0.24, blanc, "carenage_toit", r=0.06)
    for x in (-0.62, 0.0, 0.62):
        K.box(x - 0.012, x + 0.012, -0.72, 0.30, zg + 0.24, zg + 0.25, noir, "joint_toit", bevel=0)
    # plateau bas sur pied central (pièce en cours d'usinage)
    K.cyl(0.0, 0.32, 0.0, 0.30, 0.26, titane, "pied_plateau", verts=32)
    K.rbox(-0.78, 0.78, -0.24, 0.86, 0.28, 0.44, blanc, "plateau", r=0.05)
    K.box(-0.30, 0.24, 0.12, 0.52, 0.44, 0.60, noir, "piece_travail", bevel=0.01)
    # cinq ailerons triangulaires (kit d'époque 11), sur l'arrière du carénage, balayés vers l'extérieur
    zf = zg + 0.24
    fins = [[(-0.30, zf), (0.30, zf), (0.0, 3.10)],
            [(0.30, zf), (0.78, zf), (0.68, 2.62)], [(-0.78, zf), (-0.30, zf), (-0.68, 2.62)],
            [(0.84, zf), (1.22, zf), (1.32, 2.32)], [(-1.22, zf), (-0.84, zf), (-1.32, 2.32)]]
    for poly in fins:
        K.plate(poly, -0.66, -0.56, blanc, "aileron", bevel=0.01)
    strips = [[(-0.06, zf + 0.10), (0.06, zf + 0.10), (0.012, 2.80), (-0.012, 2.80)],
              [(0.50, zf + 0.10), (0.60, zf + 0.10), (0.68, 2.44), (0.65, 2.44)],
              [(-0.60, zf + 0.10), (-0.50, zf + 0.10), (-0.65, 2.44), (-0.68, 2.44)],
              [(1.00, zf + 0.10), (1.08, zf + 0.10), (1.28, 2.18), (1.25, 2.18)],
              [(-1.08, zf + 0.10), (-1.00, zf + 0.10), (-1.25, 2.18), (-1.28, 2.18)]]
    for poly in strips:
        K.plate(poly, -0.560, -0.555, ligne, "chenillard", bevel=0)
    K.module = "meca"
    # traverse mobile et chariot sous le portique (avant), bras télescopique vers la pièce
    K.box(-1.04, 1.04, 0.46, 0.60, zg + 0.02, zg + 0.16, titane, "traverse_mobile", bevel=0.008)
    K.box(-0.22, 0.14, 0.40, 0.66, zg - 0.14, zg + 0.22, blanc, "chariot", bevel=0.012)
    K.cyl(-0.04, 0.53, 0.70, zg - 0.12, 0.065, titane, "bras_telescopique")
    K.cyl(-0.04, 0.53, 0.60, 0.72, 0.10, noir, "outil")
    K.sphere(-0.04, 0.53, 0.58, 0.065, ligne, "led_outil")
    H(K, 0.0, 1.40, 1.45, "#BFE6FF", 0.5)
    H(K, -0.04, 0.72, 0.60, "#BFE6FF", 0.5)
    if piece:
        # grue en flèche (kit : flèche) sur le coin arrière droit du carénage : +0,30
        K.module = "piece"
        mx, my = 0.96, -0.40
        K.box(mx - 0.09, mx + 0.09, my - 0.07, my + 0.07, zf, 2.70, titane, "mat_grue", bevel=0.01)
        K.box(mx - 0.13, mx + 0.13, my - 0.09, my + 0.09, 2.60, 2.78, blanc, "tete_grue", bevel=0.012)
        tip = (-0.80, my, 3.44)
        K.beam((mx, my, 2.72), tip, 0.12, 0.16, blanc, "fleche_grue")
        K.beam((mx, my, 2.72), (mx + 0.40, my, 2.84), 0.10, 0.12, blanc, "contre_fleche")
        K.box(mx + 0.32, mx + 0.52, my - 0.08, my + 0.08, 2.64, 2.88, titane, "contrepoids", bevel=0.01)
        K.rod((mx, my, 2.87), tip, 0.007, noir, "hauban")
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
    # pylônes écartés (±1,30 : L de l'époque) ; correction V3 du 22/10 : deux éclats flottants au-dessus des anneaux
    # complètent les événements de silhouette (pylône, éclat, bloc, éclat, pylône : 5)
    for (x, y, h) in ((-1.30, -0.66, 2.15), (1.30, -0.66, 2.15), (-1.30, 1.16, 1.20), (1.30, 1.16, 1.20)):
        K.box(x - 0.09, x + 0.09, y - 0.065, y + 0.065, 0.0, h, noir, "pylone", bevel=0.012)
        K.box(x - 0.11, x + 0.11, y - 0.08, y + 0.08, 0.0, 0.26, givre, "givre", bevel=0.01)
        K.cyl(x, y, h, h + 0.18, 0.12, chrome, "chapeau_pylone", verts=4, r2=0.01)
        K.box(x - 0.095, x + 0.095, y - 0.07, y + 0.07, h - 0.36, h - 0.20, cyan, "bague_pylone", bevel=0)
    K.module = "meca"
    K.prism(octo(-0.82, 0.82, -0.25, 0.90, 0.24), 0.62, 0.76, noir, "plateau_levitation")
    K.prism(octo(-0.84, 0.84, -0.27, 0.92, 0.25), 0.74, 0.80, chrome, "jante_plateau", bevel=0.006)
    K.torus(0.0, 0.32, 0.58, 0.80, 0.075, cyan, "lueur_dessous")
    K.torus(0.0, 0.32, 1.10, 1.02, 0.045, chrome, "anneau_bas")
    K.torus(0.0, 0.32, 1.62, 0.78, 0.04, chrome, "anneau_haut")
    K.torus(0.0, 0.32, 1.60, 0.72, 0.016, cyan, "anneau_haut_lumineux")
    for (x, y, z, s, r) in ((-0.35, 0.30, 1.05, 0.13, 0.4), (0.30, 0.45, 1.18, 0.11, 0.9), (0.05, 0.10, 1.38, 0.09, 1.3)):
        K.obox((x, y, z), (2 * s, 2 * s, 2 * s), (r, 0.3 * r, 0.6 * r), noir, "piece_flottante", bevel=0.01)
    for s_ in (-1, 1):
        K.crystal((s_ * 0.66, -0.36, 2.48), 0.56, 0.12, noir, "eclat_flottant", tilt=(s_ * 0.18, -0.05), sides=4,
                  spin=0.4)
        K.torus(s_ * 0.66, -0.36, 2.44, 0.15, 0.03, cyan, "anneau_eclat")
    K.box(-0.28, 0.28, -0.35, 0.05, 2.85, 3.35, noir, "bloc_flottant", bevel=0.05)
    K.box(-0.285, 0.285, -0.355, 0.055, 3.01, 3.19, cyan, "fente_bloc", bevel=0)
    K.torus(0.0, -0.15, 2.78, 0.38, 0.03, chrome, "anneau_bloc")
    H(K, 0.0, 0.75, 0.45, "#4AF0FF", 0.5)
    H(K, 0.0, 0.40, 2.95, "#4AF0FF", 0.25)
    for s in (-1, 1):
        H(K, s * 1.30, 1.35, 0.95, "#4AF0FF", 0.125)
    if piece:
        K.module = "piece"
        K.torus(0.0, -0.15, 3.06, 0.62, 0.065, chrome, "anneau_vertical", axis="y", minor_seg=14)
        K.torus(0.0, -0.13, 3.06, 0.54, 0.018, cyan, "anneau_vertical_lumineux", axis="y")
        K.sphere(0.0, -0.15, 3.86, 0.10, chrome, "noyau_sommet")


# ------------------------------------------------------------------------------------------------
# Époque 13 · Fusion : noyau sphérique sur trépied dans un cadre ouvert, tore de plasma horizontal
# ------------------------------------------------------------------------------------------------
def e13(K, t, piece):
    K.gain = 0.21    # photométrie : p50 mesuré 149, 127, 104, puis 85 et 79 (22/10) -> 92 (bible §1.5, ±10)
    cera = K.metal("e13_ceramique", "#D9D6CF", k=0.95, rough=0.42, metallic=0.0, grain=0.08, dirt=0.55,
                   rust="#9A9284", rust_amount=0.2, seed=131)
    cuivre = K.metal("e13_cuivre", "#B0703A", k=1.25, rough=0.28, metallic=0.9, grain=0.12, dirt=0.4, seed=132)
    sombre = K.metal("e13_sombre", "#2A2826", k=1.4, rough=0.5, metallic=0.4, seed=133)
    plasma = K.emit("e13_plasma", "#FF4FD8", strength=1.1, base="#5A1048")
    coeur = K.emit("e13_coeur", "#FF9A3A", strength=1.5, base="#5A2A08")
    K.module = "corps"
    # Noyau sphérique sur trépied dans un cadre ouvert, tore de plasma. Correction V3 du 22/10 : plus de masse
    # (membrures plus fortes, sphère plus grande, anneau de confinement bas), les montants arrière DÉPASSENT du cadre
    # et deux injecteurs se dressent sur le tore : 5 événements (montant, injecteur, colonne, injecteur, montant).
    for x, y, h in ((-1.34, -0.70, 2.50), (1.34, -0.70, 2.50), (-1.34, 1.18, 1.05), (1.34, 1.18, 1.05)):
        K.box(x - 0.09, x + 0.09, y - 0.07, y + 0.07, 0.0, h, cera, "montant_cadre", bevel=0.01)
        K.box(x - 0.13, x + 0.13, y - 0.10, y + 0.10, 0.0, 0.12, cuivre, "sabot", bevel=0.008)
    for x in (-1.34, 1.34):
        K.cyl(x, -0.70, 2.50, 2.58, 0.10, cuivre, "chapeau_montant", verts=16)
        K.sphere(x, -0.70, 2.66, 0.10, cuivre, "fleuron")
    K.box(-1.42, 1.42, -0.76, -0.64, 1.92, 2.12, cera, "traverse_arriere", bevel=0.01)
    K.box(-1.42, 1.42, 1.12, 1.24, 0.92, 1.10, cera, "traverse_avant", bevel=0.01)
    for x in (-1.34, 1.34):
        K.beam((x, 1.18, 1.05), (x, -0.70, 2.02), 0.15, 0.15, cera, "longeron_incline")
    # anneau de confinement bas et trépied
    K.torus(0.0, 0.24, 0.42, 0.98, 0.07, cuivre, "anneau_confinement", major_seg=72, minor_seg=10)
    for k in range(3):
        a = math.radians(90 + 120 * k)
        fx, fy = 0.82 * math.cos(a), 0.24 - 0.82 * math.sin(a) / R2
        K.beam((fx, fy, 0.0), (0.30 * math.cos(a), 0.24 - 0.30 * math.sin(a) / R2, 0.95), 0.11, 0.11, cuivre,
               "jambe_trepied")
        K.cyl(fx, fy, 0.0, 0.06, 0.12, sombre, "pied_trepied")
    for k in range(4):
        a = math.radians(45 + 90 * k)
        K.beam((0.98 * math.cos(a), 0.24 - 0.98 * math.sin(a) / R2, 0.42),
               (1.34 * (1 if math.cos(a) > 0 else -1), (-0.70 if math.sin(a) > 0 else 1.18), 0.42), 0.06, 0.06,
               cuivre, "rayon_anneau")
    K.sphere(0.0, 0.24, 1.52, 0.78, cera, "sphere_confinement", seg=48, rings=24)
    for z, r in ((1.12, 0.67), (1.92, 0.67)):
        K.torus(0.0, 0.24, z, r, 0.022, cuivre, "parallele")
    c = P(0.0, 0.24, 1.52)
    for d in ((0.0, -0.85, 0.53), (0.62, -0.74, 0.26), (-0.62, -0.74, 0.26)):
        v = Vector(d).normalized()
        K.sphere(*T(c + v * 0.72), 0.11, coeur, "hublot_coeur")
    # colonne d'injection centrale (sommet : O 1,29)
    K.cyl(0.0, -0.08, 2.20, 3.62, 0.11, cera, "colonne_injection")
    for z in (2.50, 2.90, 3.30):
        K.cyl(0.0, -0.08, z, z + 0.06, 0.14, cuivre, "bague_colonne")
    K.sphere(0.0, -0.08, 3.70, 0.14, cuivre, "tete_injection")
    K.module = "meca"
    K.torus(0.0, 0.24, 1.52, 1.14, 0.12, plasma, "tore_plasma", major_seg=96, minor_seg=16)
    for a in (135, 45):
        ar = math.radians(a)
        p0 = (1.14 * math.cos(ar), 0.24 - 1.14 * math.sin(ar) / R2, 1.52)
        K.beam(p0, (math.copysign(1.34, p0[0]), -0.70, 1.52), 0.07, 0.07, cuivre, "attache_tore")
    # deux injecteurs dressés sur l'arrière du tore (kit : injecteur)
    for s_ in (-1, 1):
        a = math.radians(90 - s_ * 30)
        px, py = 1.14 * math.cos(a), 0.24 - 1.14 * math.sin(a) / R2
        K.cyl(px, py, 1.52, 1.66, 0.09, cuivre, "bride_injecteur")
        K.rod((px, py, 1.66), (px * 1.06, py - 0.04, 2.72), 0.075, cuivre, "injecteur_tore", r2=0.035, verts=16)
        K.sphere(px * 1.06, py - 0.04, 2.76, 0.07, plasma, "buse_injecteur")
    H(K, 0.0, 1.10, 1.52, "#FF4FD8", 0.5)
    for s in (-1, 1):
        H(K, s * 0.95, 0.40, 1.52, "#FF4FD8", 0.25)
    if piece:
        # couronne d'injecteurs autour de la colonne : +0,20 (O 1,49, plafond 1,50)
        K.module = "piece"
        cz = 3.52
        K.torus(0.0, -0.08, cz, 0.50, 0.05, cuivre, "couronne_injecteurs")
        for k in range(3):
            a = TAU * k / 3 + 0.5
            K.rod((0.0, -0.08, cz), (0.50 * math.cos(a), -0.08 - 0.50 * math.sin(a) / R2, cz), 0.018, cuivre, "rayon")
        for k in range(6):
            a = TAU * k / 6 + 0.26
            px, py = 0.50 * math.cos(a), -0.08 - 0.50 * math.sin(a) / R2
            tip = (px * 1.25, -0.08 - 0.62 * math.sin(a) / R2, cz + 0.52)
            K.rod((px, py, cz - 0.04), tip, 0.06, cuivre, "injecteur", r2=0.026, verts=16)
            K.sphere(*tip, 0.068, plasma, "pointe_injecteur")
        H(K, 0.0, 0.2, cz, "#FF4FD8", 0.15)


# ------------------------------------------------------------------------------------------------
# Époque 14 · Orbite : plate-forme sur pieds, ailes de panneaux dorés, parabole, bras de grue
# ------------------------------------------------------------------------------------------------
def e14(K, t, piece):
    K.gain = 0.80    # photométrie : p50 mesuré 100 -> 88 (bible §1.5, ±10)
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
    K.box(-0.86, 0.86, -0.44, 0.90, 0.88, 1.06, blanc, "plate_forme", bevel=0.015)
    K.box(-0.62, 0.62, -0.30, 0.66, 1.06, 1.62, or_, "caisson_dore", bevel=0.03)
    K.box(-0.34, 0.34, 0.66, 0.68, 1.15, 1.50, bleu, "hublot_cellules", bevel=0)
    K.cyl(0.0, -0.20, 1.62, 3.05, 0.085, blanc, "mat")
    th = math.radians(-35.0)
    nrm = (0.0, -math.cos(th), -math.sin(th))   # normale avant d'un panneau incliné (Blender)
    for s in (-1, 1):
        K.box(min(s * 0.08, s * 0.44), max(s * 0.08, s * 0.44), -0.23, -0.17, 1.98, 2.06, blanc, "traverse_aile")
        for xa, xb in ((0.44, 0.96), (1.00, 1.50)):
            cx = s * (xa + xb) / 2.0
            K.obox((cx, -0.20, 2.02), (xb - xa, 0.03, 0.78), (th, 0.0, 0.0), or_, "cadre_panneau", bevel=0.006)
            off = P(cx, -0.20, 2.02)
            c2 = (off.x + nrm[0] * 0.02, off.y + nrm[1] * 0.02, off.z + nrm[2] * 0.02)
            K.obox((c2[0], -c2[1] / R2, c2[2]), (xb - xa - 0.05, 0.012, 0.72), (th, 0.0, 0.0), cell, "cellules",
                   bevel=0)
            for f in (0.33, 0.66):
                K.obox((c2[0] - (xb - xa) * 0.5 * s + (xb - xa) * f * s, -c2[1] / R2 + 0.004, c2[2]),
                       (0.012, 0.016, 0.72), (th, 0.0, 0.0), or_, "grille", bevel=0)
        # mâts-balises (kit d'époque 14) au bout et au milieu de chaque aile : 4 événements de silhouette avec la
        # parabole au centre (correction V3 du 22/10 : ère V, 5 à 6)
        for xm, hm in ((1.52, 2.86), (0.98, 2.72)):
            K.cyl(s * xm, -0.20, 1.98, hm, 0.022, blanc, "mat_balise", verts=10)
            K.cyl(s * xm, -0.20, hm, hm + 0.04, 0.05, or_, "socle_balise", verts=12)
            K.sphere(s * xm, -0.20, hm + 0.10, 0.07, rouge, "balise_aile")
    K.module = "meca"            # parabole orientable (rotation en phase 2) : part animée du toit
    dax = (0.0, -0.55, 0.83)
    prof = [(0, 0.04), (0.04, 0.16), (0.10, 0.30), (0.18, 0.42), (0.26, 0.52)]
    K.lathe((0.0, -0.20, 3.03), prof, blanc, "parabole", verts=48, axis=dax, cap1=False)
    n = math.sqrt(0.55 ** 2 + 0.83 ** 2)
    d = (0.0, -0.55 / n, 0.83 / n)
    base = P(0.0, -0.20, 3.03)
    feed = base.copy()
    feed.y += d[1] * 0.45
    feed.z += d[2] * 0.45
    K.rod(T(base), T(feed), 0.012, blanc, "bras_source")
    K.sphere(*T(feed), 0.065, rouge, "balise_parabole")
    sh, el, wr = (0.40, 0.45, 1.62), (0.95, 0.20, 2.32), (1.18, 0.78, 1.78)
    K.cyl(0.40, 0.45, 1.55, 1.62, 0.10, blanc, "base_grue")
    K.sphere(*sh, 0.07, or_, "epaule_grue")
    K.beam(sh, el, 0.09, 0.09, blanc, "bras_grue")
    K.sphere(*el, 0.06, or_, "coude_grue")
    K.beam(el, wr, 0.07, 0.07, blanc, "avant_bras_grue")
    for dd in (-0.04, 0.04):
        K.rod(wr, (wr[0] + dd, wr[1] + 0.10, wr[2] - 0.16), 0.012, or_, "pince")
    for s in (-1, 1):
        H(K, s * 1.52, 0.15, 2.90, "#FF2A2A", 0.1)
        H(K, s * 0.98, 0.15, 2.76, "#FF2A2A", 0.1)
    H(K, 0.0, 0.95, 1.30, "#2F6BFF", 0.6)
    if piece:
        K.module = "piece"
        K.beam((0.0, -0.20, 2.70), (-0.70, -0.42, 3.06), 0.06, 0.06, blanc, "bras_reservoir")
        K.sphere(-0.84, -0.44, 3.18, 0.30, or_, "reservoir_dore", seg=40, rings=20)
        K.torus(-0.84, -0.44, 3.18, 0.302, 0.018, blanc, "ceinture_reservoir")
        K.tube([(-0.84, -0.44, 2.88), (-0.70, -0.30, 2.40), (-0.30, -0.10, 1.62)], 0.02, or_, "conduite_reservoir")


# ------------------------------------------------------------------------------------------------
# Époque 15 · Légende : base flottante, cadre ajouré, noyau flottant, couronne de flèches en or blanc
# ------------------------------------------------------------------------------------------------
def e15(K, t, piece):
    # Couleur (correction V3 du 22/10) : l'or blanc des flèches doit se lire clair (#E8DCB0, luminance visée ≥ 140) :
    # pas de gain global d'époque ; métal moins « miroir » (le ciel est sombre) pour que l'albédo se voie, reflets
    # francs gardés par une rugosité basse ; la nacre de la base reste plus sombre (p50 du corps visé 108 ± 10).
    K.gain = 1.0
    # flèches : or blanc clair (rendu mesuré le 22/10 : p50 108 avec k 0,95 et métal 0,45 -> plus diffus, plus clair)
    # mesuré le 22/10 : p50 des flèches 114 en métal diffus (une moitié de chaque flèche est à l'ombre) -> or blanc
    # LUMINEUX : albédo #E8DCB0 et faible émission blanc doré (couche de lueur : part émissive de l'époque 15, bible
    # §1.6 : 12 à 15 %)
    orf = K.emit("e15_or_blanc_lumineux", "#FFF2C0", strength=0.22, base="#E8DCB0")
    # cadre, haubans, cages : or blanc PATINÉ, plus sombre (p50 du corps visé 108)
    orb = K.metal("e15_or_blanc", "#E8DCB0", k=0.40, rough=0.30, metallic=0.5, grain=0.08, dirt=0.45,
                  rust="#8A7A50", rust_amount=0.2, seed=151)
    nacre = K.metal("e15_nacre", "#D8D2C8", k=0.13, rough=0.22, metallic=0.1, grain=0.12, grain_scale=30.0, dirt=0.4,
                    seed=152)
    sombre = K.metal("e15_sombre", "#3A3630", k=1.2, rough=0.4, metallic=0.5, seed=153)
    clair = K.emit("e15_lumiere", "#FFF2C0", strength=0.75, base="#8A8060")
    K.module = "corps"
    # Silhouette (refonte V3 du 22/10) : CADRE CARRÉ ajouré à l'échelle de l'emprise (4 montants à ±1,30 et anneau
    # carré à z 2,2), base flottante OCTOGONALE (jour de 0,28 sous elle), noyau et cages au centre-haut (toit),
    # couronne de quatre flèches en or blanc suspendue au-dessus ; petites flèches sur les montants arrière :
    # 6 événements. Le vide V vient des jours du cadre, la machine garde son aire (6 à 8 t²).
    X, YB, YF, ZR = 1.30, -1.10, 1.25, 2.00
    for x in (-X, X):
        for y, h in ((YB, ZR + 0.10), (YF, ZR + 0.10)):
            K.box(x - 0.09, x + 0.09, y - 0.07, y + 0.07, 0.10, h, orb, "montant", bevel=0.012)
            K.prism(octo(x - 0.15, x + 0.15, y - 0.12, y + 0.12, 0.05), 0.0, 0.12, sombre, "sabot")
    for y in (YB, YF):
        K.box(-X - 0.08, X + 0.08, y - 0.08, y + 0.08, ZR - 0.06, ZR + 0.12, orb, "traverse_haute", bevel=0.012)
    for x in (-X, X):
        K.box(x - 0.08, x + 0.08, YB, YF, ZR - 0.06, ZR + 0.12, orb, "longeron_haut", bevel=0.012)
    # petites flèches (kit : flèche de couronne, petite taille) au sommet des montants arrière
    for x in (-X, X):
        K.cyl(x, YB, ZR + 0.12, ZR + 0.22, 0.10, nacre, "chapiteau", verts=16)
        K.cyl(x, YB, ZR + 0.22, ZR + 0.72, 0.075, orf, "petite_fleche", r2=0.006, verts=16)
    # base flottante octogonale (socle flottant du kit), lueur dessous
    zb0, zb1 = 0.28, 0.50
    K.prism(octo(-0.90, 0.90, -0.58, 0.90, 0.30), zb0, zb1, nacre, "base_flottante", bevel=0.02)
    K.prism(octo(-0.93, 0.93, -0.61, 0.93, 0.31), zb1 - 0.05, zb1 + 0.02, orb, "jante", bevel=0.008)
    K.cyl(0.0, 0.15, zb0 - 0.03, zb0, 0.62, clair, "lueur_dessous", verts=48)
    # anneau de couronne suspendu au centre du cadre par quatre haubans rigides
    cy, zc = 0.08, ZR + 0.06
    K.torus(0.0, cy, zc, 0.66, 0.06, orb, "anneau_couronne", major_seg=72)
    K.cyl(0.0, cy, zc - 0.06, zc + 0.04, 0.55, nacre, "disque_couronne", verts=48)
    c0 = P(0.0, cy, zc)
    for xs, ys in ((-X, YB), (X, YB), (-X, YF), (X, YF)):
        q = P(xs, ys, ZR + 0.03)
        d = q - c0
        d.z = 0.0
        K.beam(T(q), T(c0 + d.normalized() * 0.66), 0.07, 0.07, orb, "hauban")
    # flèches de couronne : deux grandes au centre (O 1,50), deux moyennes sur les côtés, deux basses devant
    spires = [(110, 2.04, 0.12), (70, 2.04, 0.12), (160, 2.02, 0.10), (20, 2.02, 0.10), (260, 1.10, 0.09),
              (280, 1.10, 0.09)]
    for a_deg, h, r in spires:
        a = math.radians(a_deg)
        x, y = 0.66 * math.cos(a), cy - 0.66 * math.sin(a) / R2
        K.cyl(x, y, zc, zc + 0.10, r * 1.3, nacre, "bague_fleche", verts=20)
        K.cyl(x, y, zc + 0.10, zc + h * 0.78, r, orf, "fleche", r2=r * 0.72, verts=20)
        K.cyl(x, y, zc + h * 0.78, zc + h, r * 0.72, orf, "pointe", r2=0.004, verts=20)
    K.module = "meca"
    # noyau flottant et cages tournantes en position de toit (au-dessus du centre de la base)
    K.sphere(0.0, 0.15, 1.32, 0.34, clair, "noyau_flottant")
    K.torus(0.0, 0.15, 1.32, 0.62, 0.045, orb, "cage_1", tilt=0.5)
    K.torus(0.0, 0.15, 1.32, 0.62, 0.045, orb, "cage_2", axis="y")
    K.torus(0.0, 0.15, 1.32, 0.54, 0.04, orb, "cage_3", axis="x")
    # éclats de cristal clair en orbite autour du noyau (kit : cristal clair ; ils tournent avec les cages)
    for k in range(3):
        a = TAU * k / 3 + 0.4 + TAU * t
        K.crystal((0.78 * math.cos(a), 0.15 - 0.78 * math.sin(a) / R2, 1.10), 0.40, 0.08, orf, "eclat_orbite",
                  spin=0.5 * k)
    K.cyl(0.0, 0.15, zb1, zb1 + 0.10, 0.34, orb, "embase_noyau", verts=32)
    H(K, 0.0, 0.70, 1.30, "#FFF2C0", 0.45)
    H(K, 0.0, 0.25, 0.15, "#FFF2C0", 0.35)
    H(K, 0.0, 0.40, zc + 0.8, "#FFF2C0", 0.2)
    if piece:
        # halo de particules : anneau-halo en CEINTURE autour des flèches (O ≤ 1,50 : plafond Q9) et particules
        # d'au moins 8 × 8 px hr (F37, §1.6)
        K.module = "piece"
        zh = 3.22
        halo = K.emit("e15_halo", "#FFF2C0", strength=0.5, base="#6A6048")
        K.torus(0.0, cy, zh, 0.95, 0.04, halo, "anneau_halo", minor_seg=10, major_seg=96)
        import random
        rnd = random.Random(1530)
        for i in range(10):
            a = TAU * i / 10 + rnd.uniform(-0.12, 0.12)
            rr = 0.95 + rnd.uniform(-0.12, 0.12)
            z = zh + rnd.uniform(-0.30, 0.20)
            K.sphere(rr * math.cos(a), cy - rr * math.sin(a) / R2, z, rnd.uniform(0.068, 0.074), halo, "particule",
                     seg=16, rings=8)
        H(K, 0.0, 0.6, 3.2, "#FFF2C0", 0.15)


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
    raccords(K, e)
    # Flaque de halo cuite dans la couche draw_as_light : compacte comme le vanilla (E31 : halo V0 trop grand,
    # 242 × 266 px hr contre 152 × 126 pour le four), qui grandit doucement avec le niveau. Le halo proportionnel
    # au niveau de la bible (§1.6, D2-3 : S(N) = s·(1 + 0,05·N)) passera par une LightDefinition en phase 2.
    k = 1.0 + 0.03 * n
    wins = []
    for (tx, ty, z) in K.halo_pts:
        wins.append({"at": (tx, ty, 0.0), "r": (0.35 * k, 0.85 * k)})
        wins.append({"at": (tx, ty, z), "r": (0.20, 0.50)})
    # flaque de lumière au rayon imposé par la bible (§1.6, D2-3 : S(N) = s × (1 + 0,05·N)), centrée sur l'entité :
    # la surface du halo croît avec le niveau (correction V3 du 22/10) ; voir params.flaque et rendre.light_layer
    f = params.flaque(n)
    wins.append({"at": (0.0, 0.0, 0.0), "r": (f["r0"], f["r1"]), "flaque": True})
    parts = {}
    for o in S.piece_objects():
        mod = o.get("fo_module", "corps")
        base = o.name.split("_", 1)[1].rsplit("_", 1)[0] if o.name.count("_") >= 2 else o.name
        parts.setdefault(mod, set()).add(base)
    return {"halo": wins or params.halo_fenetres(n), "modules": sorted(parts),
            "parts": {k: sorted(v) for k, v in sorted(parts.items())}}
