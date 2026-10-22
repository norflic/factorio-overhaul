"""Mitrailleuse, exploration de style « HYBRIDE PROGRESSIVE » (lot V3-S, 22/10/2026) : niveaux témoins 11
(époque 6), 21 (époque 11), 29 (époque 15) et pièce du niveau 30. Python PUR (geo, kit).

Approche (consigne de l'orchestrateur, charte DA_FACTORIO §6) :
- ères I-II : industriel lourd (tôle rivetée, acier, laiton, cuivre, vapeur) ; l'époque 6 « Électricité »
  y ajoute son moteur bobiné et ses piles d'isolateurs, en porcelaine brune vernissée (matériau d'époque en
  ACCENT, charte §6.4) ;
- ère III : électro-industriel (bobines, isolateurs, blindage épais) : non rendu ici ;
- ères IV-V : haute technologie MASSIVE à la manière du vanilla avancé (réacteur, centrifugeuse, silo) :
  acier sombre en grandes plaques boulonnées, cuivre, bandes de danger, petits foyers lumineux ; les
  matériaux d'époque (alliage blanc patiné à l'époque 11, or blanc à l'époque 15) ne sont que des accents.
- la PUISSANCE monte avec l'emprise (3×3 -> 5×5 -> 6×6), la masse, le nombre de systèmes et de pièces, et le
  nombre de foyers lumineux (on ajoute des foyers, on ne les agrandit pas) ; jamais par des mâts ni des vides.

Identité gardée de V3 phase 1 (tools/render/pieces/levels/gun) : tête à plusieurs canons rotatifs, socle
(base_picture, fixe) et tête (tournante) séparés, pièce du niveau pair dans la zone du socle jamais recouverte
par la tête (F46, recalculé ici par le rayon de la tête), ombres plein est (soleil d'ouest du pipeline, F47).

Règles de calque propres à une grande tourelle (moteur : le socle est dessiné en « lower-object », AVANT les
objets des entités voisines ; la tête en « object ») :
- rien du socle ne dépasse le bord NORD de l'emprise à l'écran (sinon l'entité voisine au nord, dessinée après,
  le recouvrirait) : Y_arrière + z_haut <= côté / 2 × 1,414 (contrôlé par apercu.py) ;
- devant la tête (sud), le socle reste plus bas que le pied de la tête à l'écran (la tête est dessinée par-dessus).

Repère : geo.py (1 unité = 1 tuile en X ; une tuile de jeu vers le sud = 1,414 unité en Y ; +Z haut). Tête
modélisée canons vers +Y (pose N) ; pose E = rotation de -90° autour de Z.
"""
import math
import random

import kit as K
from geo import Geo, MIN_T, SQ2, TAU, gy

# ------------------------------------------------------------------------------------------------
# Niveaux
# ------------------------------------------------------------------------------------------------
LEVELS = {
    11: {"epoch": 6, "era": "II", "side": 3, "deck": 0.33},
    21: {"epoch": 11, "era": "IV", "side": 5, "deck": 0.62},
    29: {"epoch": 15, "era": "V", "side": 6, "deck": 0.76},
    30: {"epoch": 15, "era": "V", "side": 6, "deck": 0.76, "piece": True},
}
POSES = {"N": 0.0, "E": -math.pi / 2}
# agrandissement de la tête au-dessus de la barbette (la tête domine son socle, comme le vanilla)
HEAD_SCALE = {11: 1.15, 21: 1.3, 29: 1.28}

# Systèmes fonctionnels (charte §6.2, comptés à la main sur la géométrie ci-dessous ; chaque niveau reprend
# tout ce qui précède)
SYSTEMS = {
    11: ["tête à canons rotatifs (2 × 4 canons)", "alimentation en munitions (tambour, bande, caisses)",
         "socle pivotant (couronne dentée, barbette)", "blindage frontal (masque, flasques)",
         "refroidissement des canons (manchons à eau, réservoir, tuyaux)", "canons jumelés",
         "moteur électrique bobiné et isolateurs (époque 6)", "batterie d'accumulateurs du socle"],
    21: None, 29: None,
}
SYSTEMS[21] = SYSTEMS[11] + [
    "chargeur automatique (trémies, convoyeurs, chargeur arrière)", "câblage et goulottes",
    "viseur / capteur optique", "générateur et condensateurs", "tourelles secondaires latérales (2)",
    "radiateurs (blocs à ailettes)"]
SYSTEMS[29] = SYSTEMS[21] + [
    "tourelle secondaire dorsale (3 tourelles secondaires en tout)", "réserve d'énergie visible (tours de cellules)",
    "blindage à plaques multiples (briques additionnelles)", "couronne de 3 canons rotatifs lourds"]
SYSTEMS[30] = SYSTEMS[29] + ["bastions d'angle lance-roquettes (pièce du niveau 30)"]
ANIMATIONS = {
    11: ["tir (rotation des canons)", "arc de l'éclateur entre les isolateurs", "bande de cartouches"],
    21: ["tir (rotation des canons)", "bande de cartouches", "convoyeurs des trémies", "chenillard des lignes bleu-blanc",
         "voyants qui clignotent"],
    29: ["tir (rotation des canons)", "bandes de cartouches", "convoyeurs des trémies", "cellules d'énergie qui pulsent",
         "voyants qui clignotent", "tourelles secondaires (rotation)"],
}
ANIMATIONS[30] = ANIMATIONS[29]

# ------------------------------------------------------------------------------------------------
# Matériaux (couleurs LINÉAIRES ; paramètres de fo_scene.mat_metal / mat_emissive). Ancre de style : la cheminée
# V0 validée (tôle brune rouillée, cerclages laiton, rivets mats, crasse des creux forte).
# ------------------------------------------------------------------------------------------------
RUST = (0.15, 0.055, 0.02)   # rouille plus SOMBRE que la tôle : taches lisibles en luminance (P2)


# grain : 22 cellules par unité (environ 3 px HR). À 48 (cheminée), le grain d'1,3 px est effacé par le filtre de
# pixel de 1,5 px (essais 1 à 3 : 55 % de surfaces planes, P4) ; le vanilla porte un grain de 2 à 4 px.
def _metal(color, rough=0.42, metallic=0.6, grain=0.32, grain_scale=22.0, rust=RUST, rust_amount=0.0,
           rust_scale=5.0, dirt=0.8, dirt_distance=0.3, soot=None):
    d = dict(color=color, rough=rough, metallic=metallic, grain=grain, grain_scale=grain_scale, dirt=dirt,
             dirt_distance=dirt_distance)
    if rust_amount > 0:
        d.update(rust=rust, rust_amount=rust_amount, rust_scale=rust_scale)
    if soot:
        d["soot"] = soot
    return ("metal", d)


def _emit(color, strength=1.0, crust=None):
    return ("emit", dict(color=color, strength=strength, crust=crust))


BASE_MATS = {
    "joint": _metal((0.018, 0.016, 0.014), rough=0.75, metallic=0.3, grain=0.2, dirt=0.5),
    "tole": _metal((0.22, 0.18, 0.135), rough=0.38, metallic=0.55, grain=0.5, rust_amount=0.45, rust_scale=6.0,
                   dirt=0.8, dirt_distance=0.14),
    "tole_b": _metal((0.34, 0.285, 0.215), rough=0.36, metallic=0.55, grain=0.5, rust_amount=0.3, rust_scale=7.0,
                     dirt=0.8, dirt_distance=0.14),
    "tole_r": _metal((0.2, 0.15, 0.11), rough=0.45, metallic=0.5, grain=0.52, rust_amount=0.7, rust_scale=9.0,
                     dirt=0.8, dirt_distance=0.14),
    "tole_sombre": _metal((0.1, 0.088, 0.074), rough=0.42, metallic=0.55, grain=0.5, rust_amount=0.35, rust_scale=8.0,
                          dirt=0.8, dirt_distance=0.14),
    "acier": _metal((0.24, 0.225, 0.2), rough=0.34, metallic=0.75, grain=0.36, grain_scale=26.0, rust_amount=0.22, rust_scale=8.0,
                    dirt=0.75, dirt_distance=0.14),
    "acier_clair": _metal((0.46, 0.43, 0.38), rough=0.3, metallic=0.8, grain=0.25, rust_amount=0.12, dirt=0.6,
                          dirt_distance=0.12),
    "boulon": _metal((0.6, 0.53, 0.41), rough=0.4, metallic=0.8, grain=0.1, dirt=0.3, dirt_distance=0.05),
    "laiton": _metal((0.72, 0.54, 0.28), rough=0.32, metallic=0.9, grain=0.15, grain_scale=70.0, rust=(0.3, 0.12, 0.05),
                     rust_amount=0.2, dirt=0.4),
    "laiton_tore": _metal((0.72, 0.54, 0.28), rough=0.42, metallic=0.9, grain=0.15, grain_scale=70.0,
                          rust=(0.3, 0.12, 0.05), rust_amount=0.2, dirt=0.4),
    "cuivre": _metal((0.6, 0.29, 0.14), rough=0.36, metallic=0.9, grain=0.16, grain_scale=60.0, rust=(0.24, 0.1, 0.04),
                     rust_amount=0.25, dirt=0.45),
    "canon": _metal((0.055, 0.05, 0.046), rough=0.38, metallic=0.85, grain=0.22, rust=(0.2, 0.08, 0.03),
                    rust_amount=0.2, dirt=0.5),
    "noir": _metal((0.035, 0.032, 0.03), rough=0.6, metallic=0.3, grain=0.2, dirt=0.4),
    "caoutchouc": _metal((0.03, 0.028, 0.026), rough=0.9, metallic=0.0, grain=0.15, dirt=0.3),
    "jaune": _metal((0.6, 0.4, 0.04), rough=0.55, metallic=0.15, grain=0.3, rust=(0.2, 0.09, 0.03), rust_amount=0.35,
                    dirt=0.75),
    "peint": _metal((0.27, 0.15, 0.075), rough=0.5, metallic=0.2, grain=0.5, rust_amount=0.45, rust_scale=8.0,
                    dirt=0.8, dirt_distance=0.14),
    "bois": _metal((0.22, 0.13, 0.065), rough=0.85, metallic=0.0, grain=0.4, dirt=0.65),
    "porcelaine": _metal((0.2, 0.085, 0.04), rough=0.26, metallic=0.0, grain=0.12, dirt=0.55),
    "ivoire": _metal((0.46, 0.42, 0.34), rough=0.38, metallic=0.0, grain=0.18, dirt=0.7),
    "cable_r": _metal((0.3, 0.035, 0.02), rough=0.6, metallic=0.0, grain=0.15, dirt=0.4),
    "verre": _metal((0.01, 0.012, 0.014), rough=0.1, metallic=0.0, grain=0.02, dirt=0.2),
    "suie": _metal((0.012, 0.011, 0.01), rough=0.95, metallic=0.0, grain=0.25, dirt=0.2),
    "ambre": _emit((1.0, 0.42, 0.04), 1.0, crust=(30.0, 0.3, 2.0)),
}


def materials(level):
    m = dict(BASE_MATS)
    e = LEVELS[level]["epoch"]
    if e == 6:
        m["arc"] = _emit((0.38, 0.82, 1.0), 1.0)                     # arcs cyan (bible), foyers seulement
    if e in (11, 15):
        # haute technologie massive : acier sombre en grandes plaques (gris chaud), accents d'époque patinés
        m["tole"] = _metal((0.2, 0.185, 0.16), rough=0.38, metallic=0.65, grain=0.5, rust_amount=0.25, rust_scale=8.0,
                           dirt=0.8, dirt_distance=0.14)
        m["tole_b"] = _metal((0.33, 0.31, 0.27), rough=0.36, metallic=0.65, grain=0.5, rust_amount=0.18,
                             rust_scale=7.0, dirt=0.8, dirt_distance=0.14)
        m["tole_r"] = _metal((0.19, 0.16, 0.13), rough=0.45, metallic=0.55, grain=0.52, rust_amount=0.55, rust_scale=9.0,
                             dirt=0.8, dirt_distance=0.14)
        m["tole_sombre"] = _metal((0.085, 0.08, 0.072), rough=0.42, metallic=0.6, grain=0.5, rust_amount=0.2,
                                  rust_scale=8.0, dirt=0.8, dirt_distance=0.14)
    if e == 11:
        m["alliage"] = _metal((0.36, 0.34, 0.3), rough=0.48, metallic=0.5, grain=0.28, rust_amount=0.12, dirt=0.85)
        m["bronze"] = _metal((0.42, 0.25, 0.1), rough=0.34, metallic=0.9, grain=0.2, dirt=0.5)   # titane recuit
        m["ligne"] = _emit((0.72, 0.88, 1.0), 1.0)                    # lignes bleu-blanc (bible)
    if e == 15:
        m["alliage"] = _metal((0.34, 0.32, 0.28), rough=0.48, metallic=0.5, grain=0.28, rust_amount=0.12, dirt=0.85)
        m["bronze"] = _metal((0.42, 0.25, 0.1), rough=0.34, metallic=0.9, grain=0.2, dirt=0.5)
        m["or_blanc"] = _metal((0.52, 0.43, 0.26), rough=0.4, metallic=0.85, grain=0.22, rust_amount=0.1, dirt=0.75)
        m["or_lum"] = _emit((1.0, 0.93, 0.7), 1.0, crust=(25.0, 0.25, 4.0))   # lumière blanche dorée (bible)
        m["ligne"] = _emit((1.0, 0.82, 0.45), 1.0)
    return m


# ------------------------------------------------------------------------------------------------
# Aides
# ------------------------------------------------------------------------------------------------
def octagon(hx, hy, cx_, cy_, cx=0.0, cy=0.0, cf=None):
    """Octogone (x, y) : demi-côtés hx, hy, chanfreins cx_ (en x) et cy_ (en y) ; cf = chanfreins
    (sud-ouest, sud-est, nord-est, nord-ouest) si différents."""
    c = cf or ((cx_, cy_),) * 4
    (a0, b0), (a1, b1), (a2, b2), (a3, b3) = c
    return [(cx - hx + a0, cy - hy), (cx + hx - a1, cy - hy), (cx + hx, cy - hy + b1), (cx + hx, cy + hy - b2),
            (cx + hx - a2, cy + hy), (cx - hx + a3, cy + hy), (cx - hx, cy + hy - b3), (cx - hx, cy - hy + b0)]


def plate_poly_edges(g, M, poly, z0, z1, mat, nseg=None, bolt_spacing=0.22):
    """Ceinture de plaques sur les côtés d'un prisme (une plaque par côté et par tronçon) : joints verticaux,
    boulons en haut et en bas. Le côté sud est celui qu'on voit le mieux."""
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        dx, dy = q[0] - p[0], q[1] - p[1]
        L = math.hypot(dx, dy)
        if L < 0.12:
            continue
        nx, ny = dy / L, -dx / L
        a = math.atan2(dy, dx)
        k = nseg or max(1, int(round(L / 0.55)))
        for j in range(k):
            t0, t1 = j / k, (j + 1) / k
            mx = p[0] + dx * (t0 + t1) / 2 + nx * 0.016
            my = p[1] + dy * (t0 + t1) / 2 + ny * 0.016
            g.push(); g.move((mx, my, (z0 + z1) / 2)); g.turn("z", a)
            w = L / k - 0.034
            g.box(mat, (w, 0.032, (z1 - z0) - 0.03), (0, 0, 0), 0.008)
            kb = max(2, int(w / bolt_spacing) + 1)
            for zz in ((z1 - z0) / 2 - 0.05, -(z1 - z0) / 2 + 0.05):
                K.bolts_line(g, M["boulon"], (-w / 2 + 0.05, -0.018, zz), (w / 2 - 0.05, -0.018, zz), kb, n=(0, -1, 0),
                             r=0.02)
            g.pop()


def deck_plates(g, M, x_range, y_range, z, nx, ny, mat="tole", t=0.03, gap=0.034, skip=None, seed=0, bolt_spacing=0.26):
    """Platelage du pont : grandes plaques jointives boulonnées (skip(x, y) -> True : pas de plaque)."""
    x0, x1 = x_range
    y0, y1 = y_range
    dx, dy = (x1 - x0) / nx, (y1 - y0) / ny
    for i in range(nx):
        for j in range(ny):
            cx, cy = x0 + (i + 0.5) * dx, y0 + (j + 0.5) * dy
            if skip and skip(cx, cy):
                continue
            pm = K.plate_variants(M, mat)
            K.plate(g, pm[(i * 7 + j * 3 + seed) % len(pm)], M["boulon"], (dx - gap, dy - gap, t), (cx, cy, z + t / 2),
                    spacing=bolt_spacing, r=0.022)


def parapet(g, M, x0, x1, y, z, h, t=0.16, emit=None, embrasures=0, seed=0):
    """Parapet blindé à l'avant du pont : face sud plaquée et boulonnée (vue de face par la caméra), chaperon
    d'acier, meurtrières sombres, ligne lumineuse facultative (emit) sur la face sud."""
    cy = y + t / 2
    K.armor_box(g, M, (x1 - x0, t, h), ((x0 + x1) / 2, cy, z + h / 2), div_top=(1, 1),
                div_side=(max(2, int((x1 - x0) / 0.6)), 1), faces=("s",), seed=seed)
    g.box(M["acier"], (x1 - x0 + 0.04, t + 0.05, 0.05), ((x0 + x1) / 2, cy, z + h + 0.025), 0.012)
    K.bolts_line(g, M["boulon"], (x0 + 0.08, cy - t / 2 + 0.02, z + h + 0.05), (x1 - 0.08, cy - t / 2 + 0.02, z + h + 0.05),
                 max(3, int((x1 - x0) / 0.2)), r=0.02)
    for i in range(embrasures):
        x = x0 + (i + 0.5) * (x1 - x0) / embrasures
        g.box(M["joint"], (0.16, 0.03, 0.06), (x, y - 0.03, z + h * 0.72), 0.0)
        g.box(M["acier"], (0.22, 0.04, 0.02), (x, y - 0.04, z + h * 0.72 + 0.045), 0.004)
    if emit:
        K.light_strip(g, emit, M["acier"], (x0 + 0.15, y - 0.045, z + h * 0.32), (x1 - 0.15, y - 0.045, z + h * 0.32),
                      0.045, n=(0, -1, 0), cells=max(3, int((x1 - x0) / 0.3)))
    g.count("parapet")


def race_ring(g, M, R, z, nb):
    """Chemin de roulement fixe du socle : bague laiton, couronne de boulons, joint sombre."""
    g.tube(M["joint"], R + 0.08, R - 0.08, 0.03, (0, 0, z + 0.015), n=64)
    g.torus(M["laiton_tore"], R + 0.02, 0.035, (0, 0, z + 0.03), n=72, m=10)
    K.bolts_ring(g, M["boulon"], (0, 0, z + 0.03), R + 0.12, nb, r=0.024)


def turntable(g, M, R, z, teeth=48):
    """Couronne de rotation de la tête : plateau, denture, boulons."""
    g.cyl(M["tole_sombre"], R, 0.09, (0, 0, z + 0.045), n=64, ch=0.012)
    for i in range(teeth):
        a = TAU * i / teeth
        g.push(); g.move((R * math.cos(a), R * math.sin(a), z + 0.045)); g.turn("z", a)
        g.box(M["acier"], (0.06, 0.05, 0.07), (0.01, 0, 0), 0.006)
        g.pop()
    g.count("dent", teeth)
    K.bolts_ring(g, M["boulon"], (0, 0, z + 0.09), R - 0.07, max(12, teeth // 2), r=0.022)
    return z + 0.09


def barbette(g, M, r0, r1, z0, z1, seams=12, rows=3, bands=("laiton_tore",), hatch_at=-math.pi / 2, ladder=True,
             rad_mult=3, slits=None):
    """Barbette (fût conique tournant) : tôle, couvre-joints verticaux rivetés, rangées de rivets, cerclages,
    trappe et échelle à l'arrière (côté -Y local)."""
    h = z1 - z0
    g.cyl(M["tole"], r0, h, (0, 0, z0 + h / 2), n=48, r2=r1, ch=0.015)
    for i in range(seams):
        a = TAU * (i + 0.5) / seams
        rr = (r0 + r1) / 2 + 0.012
        tilt = math.atan2(r0 - r1, h)
        g.push(); g.move((rr * math.cos(a), rr * math.sin(a), z0 + h / 2)); g.turn("z", a); g.turn("y", -tilt)
        g.box(M["tole_sombre"], (0.03, 0.08, h * 0.96), (0, 0, 0), 0.006)
        g.pop()
        for k in range(rows + 2):
            t = (k + 0.5) / (rows + 2)
            r = r0 + (r1 - r0) * t + 0.03
            K.rivet(g, M["boulon"], (r * math.cos(a), r * math.sin(a), z0 + h * t), (math.cos(a), math.sin(a), 0.3), 0.02)
    for k in range(rows):
        t = (k + 1) / (rows + 1)
        r = r0 + (r1 - r0) * t
        K.radial_rivets(g, M["boulon"], (0, 0), r + 0.004, z0 + h * t, int(seams * rad_mult), r=0.018, phase=0.13 * k)
    if slits:
        # fentes lumineuses verticales entre les couvre-joints (énergie visible des ères IV-V)
        for i in range(seams):
            a = TAU * i / seams
            t = 0.62
            r = r0 + (r1 - r0) * t + 0.01
            g.push(); g.move((r * math.cos(a), r * math.sin(a), z0 + h * t)); g.turn("z", a)
            g.turn("y", -math.atan2(r0 - r1, h))
            g.box(M["acier"], (0.03, 0.11, h * 0.36), (0, 0, 0), 0.006)
            g.box(slits, (0.034, 0.06, h * 0.3), (0.004, 0, 0), 0.0)
            g.pop()
    for j, b in enumerate(bands):
        t = (j + 1) / (len(bands) + 1)
        g.torus(M[b], r0 + (r1 - r0) * t + 0.01, 0.03, (0, 0, z0 + h * t), n=64, m=8)
    if hatch_at is not None:
        a = hatch_at
        rr = r0 + (r1 - r0) * 0.45
        tilt = math.atan2(r0 - r1, h)
        g.push(); g.move((rr * math.cos(a), rr * math.sin(a), z0 + h * 0.45)); g.turn("z", a); g.turn("y", -tilt)
        g.box(M["tole_sombre"], (0.04, 0.42, h * 0.55), (0.02, 0, 0), 0.01)
        g.box(M["acier"], (0.03, 0.04, h * 0.5), (0.05, 0.16, 0), 0.004)
        g.box(M["acier"], (0.03, 0.12, MIN_T + 0.01), (0.05, -0.08, 0.0), 0.004)
        for s in (-1, 1):
            for zz in (-1, 1):
                K.bolt(g, M["boulon"], (0.045, s * 0.17, zz * h * 0.22), (1, 0, 0), 0.016)
        g.pop()
        if ladder:
            a2 = a + 0.42
            K.ladder(g, M["acier"], (r0 * math.cos(a2) * 1.0, r0 * math.sin(a2) * 1.0, z0), h * 0.95, w=0.18,
                     n=(math.cos(a2), math.sin(a2), 0))
    g.count("barbette")


# ================================================================================================
# NIVEAU 11 (époque 6, ère II) : 3×3
# ================================================================================================
def socle_11(g, M, piece=False):
    hx, hy = 1.42, 1.98
    deck = LEVELS[11]["deck"]
    foot = octagon(1.47, 2.06, 0.34, 0.48)
    g.prism(M["acier"], foot, 0.0, 0.07)
    body = octagon(hx, 1.89, 0.3, 0.42, cy=-0.11)
    g.prism(M["tole_sombre"], body, 0.05, deck - 0.03)
    plate_poly_edges(g, M, body, 0.06, deck - 0.02, M["tole"])
    # pont : plaques jointives, couronne de roulement
    deck_plates(g, M, (-1.25, 1.25), (-1.78, 1.6), deck - 0.002, 4, 5,
                skip=lambda x, y: (x * x + (y) ** 2) < 0.75)
    g.prism(M["tole_sombre"], octagon(1.3, 1.72, 0.2, 0.3, cy=-0.1), deck - 0.035, deck - 0.0)
    race_ring(g, M, 1.02, deck, 30)
    # rebord riveté du pont (cornière), côté sud et flancs
    for x0, y0, x1, y1 in ((-1.1, -1.95, 1.1, -1.95), (-1.38, -1.5, -1.38, 1.5), (1.38, -1.5, 1.38, 1.5)):
        L = math.hypot(x1 - x0, y1 - y0)
        g.push(); g.move(((x0 + x1) / 2, (y0 + y1) / 2, deck + 0.025)); g.turn("z", math.atan2(y1 - y0, x1 - x0))
        g.box(M["acier"], (L, 0.05, 0.05), (0, 0, 0), 0.008)
        K.bolts_line(g, M["boulon"], (-L / 2 + 0.06, 0, 0.025), (L / 2 - 0.06, 0, 0.025), int(L / 0.16), r=0.016,
                     kind="rivet")
        g.pop()
    parapet(g, M, -1.08, 1.08, -1.97, deck, 0.12, t=0.1, seed=9)
    # bande de danger peinte le long de l'avant du pont
    K.hazard_band(g, M["jaune"], M["noir"], (-0.95, -1.7, deck + 0.03), (0.95, -1.7, deck + 0.03), 0.12, 0.012)
    # pattes d'ancrage aux 4 angles (chanfreins) : semelles et gros boulons
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * 1.27, sy * (1.79 if sy < 0 else 1.55)
            g.push(); g.move((cx, cy, 0.0)); g.turn("z", math.atan2(sy * 1.414, sx))
            g.box(M["acier"], (0.3, 0.2, 0.12), (0.12, 0, 0.06), 0.012)
            K.bolt(g, M["boulon"], (0.2, -0.05, 0.12), r=0.03, washer=M["acier"])
            K.bolt(g, M["boulon"], (0.2, 0.05, 0.12), r=0.03, washer=M["acier"])
            g.pop()
    # --- arrière gauche : boîte de jonction et 3 isolateurs (époque 6), câbles vers la couronne ---
    bx, by = -0.98, 1.08
    K.armor_box(g, M, (0.5, 0.36, 0.3), (bx, by, deck + 0.15), div_top=(1, 1), div_side=(2, 1),
                faces=("top", "s", "e", "w"), seed=3)
    for i, dx in enumerate((-0.16, 0.0, 0.16)):
        K.insulator_stack(g, M["porcelaine"], M["laiton"], (bx + dx, by + 0.02, deck + 0.3), 3, 0.055, 0.035, 0.034)
    K.slit_light(g, M["arc"], M["acier"], (bx - 0.08, by - 0.19, deck + 0.16), 0.2, 0.07, (0, -1, 0), bars=1)
    g.light((bx - 0.08, by - 0.3, deck + 0.16), (0.4, 0.8, 1.0), 3.0)
    K.cable_bundle(g, [M["cable_r"], M["noir"]], [(bx + 0.2, by - 0.18, deck + 0.04), (-0.75, 0.75, deck + 0.03),
                                                  (-0.62, 0.45, deck + 0.04)], spread=0.05, r=0.02,
                   ties=M["acier"], tie_every=0.2)
    # --- arrière droit : batterie d'accumulateurs (ressource de l'époque 6) ---
    K.capacitor_bank(g, M, (0.98, 1.12, deck + 0.04), 2, 2, r=0.1, h=0.26, pitch=0.24, cap="laiton")
    g.box(M["tole_sombre"], (0.56, 0.56, 0.04), (0.98, 1.12, deck + 0.02), 0.008)
    K.armor_box(g, M, (0.46, 0.12, 0.16), (0.98, 0.76, deck + 0.08), div_top=(2, 1), div_side=(2, 1),
                faces=("top", "s"), seed=7)
    K.slit_light(g, M["ambre"], M["acier"], (0.98, 0.69, deck + 0.09), 0.26, 0.05, (0, -1, 0), bars=2)
    g.light((0.98, 0.6, deck + 0.1), (1.0, 0.45, 0.06), 3.0)
    K.cable_bundle(g, [M["cuivre"], M["noir"]], [(0.8, 0.9, deck + 0.04), (0.72, 0.75, deck + 0.03),
                                                 (0.6, 0.48, deck + 0.04)], spread=0.05, r=0.02, ties=M["acier"])
    K.tread_plate(g, M["acier"], (-0.3, 0.55), (-1.66, -1.18), deck + 0.028)
    # --- avant gauche : caisses de munitions cerclées ---
    K.crate(g, M, (0.42, 0.3, 0.22), (-0.98, -1.5, deck), mat="bois", stencil="jaune")
    K.crate(g, M, (0.3, 0.26, 0.16), (-0.98, -1.5, deck + 0.235), mat="bois")
    K.crate(g, M, (0.3, 0.3, 0.2), (-0.55, -1.62, deck), mat="tole")
    # --- avant droit : coffre à outils, extincteur couché, voyants ambrés ---
    K.armor_box(g, M, (0.44, 0.28, 0.18), (0.95, -1.55, deck + 0.09), div_top=(2, 1), div_side=(2, 1),
                faces=("top", "s"), seed=5)
    g.cyl(M["cable_r"], 0.06, 0.32, (0.55, -1.64, deck + 0.065), axis="x", n=14, ch=0.01)
    g.cyl(M["laiton"], 0.035, 0.05, (0.37, -1.64, deck + 0.065), axis="x", n=10)
    for sx in (-1, 1):
        x = sx * 1.22
        g.box(M["acier"], (0.08, 0.08, 0.16), (x, -1.72, deck + 0.08), 0.008)
        K.lamp(g, M["ambre"], M["acier"], (x, -1.76, deck + 0.12), (0, -1, 0.4), 0.075, cage=M["acier"])
        g.light((x, -1.85, deck + 0.14), (1.0, 0.45, 0.06), 6.0)
    # tuyau de laiton le long du flanc gauche (eau de refroidissement vers la tête)
    K.pipe(g, M["laiton"], M["acier"], M["boulon"], [(-1.3, -1.2, deck + 0.06), (-1.3, 0.6, deck + 0.06),
                                                     (-0.98, 0.95, deck + 0.06)], 0.035)
    if piece:
        pass
    return g


def head_11(g, M):
    """Mitrailleuse électrique lourde : barbette rivetée, flasques blindées, 2 × 4 canons rotatifs à manchons à eau,
    moteur bobiné arrière, piles d'isolateurs dorsales et éclateur, tambour de munitions, réservoir d'eau."""
    deck = LEVELS[11]["deck"]
    z = turntable(g, M, 1.0, deck, 52)
    zb = 1.12
    barbette(g, M, 0.9, 0.74, z, zb, seams=12, rows=2, rad_mult=2)
    g.cyl(M["tole_sombre"], 0.8, 0.06, (0, 0, zb + 0.03), n=48, ch=0.01)
    g.torus(M["laiton_tore"], 0.76, 0.03, (0, 0, zb + 0.065), n=56, m=8)
    # tout ce qui est au-dessus de la barbette est agrandi (tête dominante, comme la tête vanilla sur son socle)
    g.push()
    g.scale_about((0, 0, zb), HEAD_SCALE[11])
    za = zb + 0.66     # axe des canons
    # flasques (tourillons) blindées
    prof = [(-0.6, zb + 0.06), (0.42, zb + 0.06), (0.5, za - 0.05), (0.28, za + 0.42), (-0.42, za + 0.42),
            (-0.6, za + 0.2)]
    for sx in (-1, 1):
        x0, x1 = (0.5, 0.64) if sx > 0 else (-0.64, -0.5)
        g.slab_x(M["tole"], prof, x0, x1)
        xo = x1 if sx > 0 else x0
        n = (sx, 0, 0)
        K.bolts_line(g, M["boulon"], (xo, -0.52, zb + 0.14), (xo, 0.38, zb + 0.14), 7, n=n, r=0.02, kind="rivet")
        K.bolts_line(g, M["boulon"], (xo, -0.5, za + 0.34), (xo, 0.22, za + 0.34), 6, n=n, r=0.02, kind="rivet")
        K.bolts_line(g, M["boulon"], (xo, -0.56, zb + 0.2), (xo, -0.56, za + 0.12), 5, n=n, r=0.02, kind="rivet")
        g.cyl(M["acier"], 0.2, 0.08, (xo + sx * 0.04, 0.02, za), axis="x", n=28, ch=0.012)
        g.cyl(M["laiton"], 0.1, 0.05, (xo + sx * 0.1, 0.02, za), axis="x", n=20, ch=0.008)
        K.bolts_ring(g, M["boulon"], (xo + sx * 0.08, 0.02, za), 0.15, 8, axis=(sx, 0, 0), r=0.016)
        # plaque de blindage rapportée sur la flasque (2e épaisseur)
        g.push(); g.move((xo + sx * 0.02, -0.12, zb + 0.32))
        g.box(M["tole_sombre"], (0.03, 0.5, 0.26), (0, 0, 0), 0.008)
        for yy in (-0.2, 0.2):
            for zz in (-0.09, 0.09):
                K.bolt(g, M["boulon"], (sx * 0.016, yy, zz), (sx, 0, 0), 0.018)
        g.pop()
    # caisson des culasses
    K.armor_box(g, M, (1.0, 0.9, 0.6), (0, -0.08, za + 0.08), div_top=(2, 2), div_side=(2, 1),
                faces=("top", "s", "n"), seed=11, plate_mat=[M["peint"], M["tole_r"], M["peint"], M["tole"]])
    # masque frontal incliné (blindage) et embrasures
    g.slab_x(M["tole_sombre"], [(0.36, za - 0.36), (0.52, za - 0.3), (0.56, za + 0.3), (0.34, za + 0.42)], -0.6, 0.6)
    K.bolts_line(g, M["boulon"], (-0.5, 0.45, za + 0.36), (0.5, 0.45, za + 0.36), 8, n=(0, 0.5, 1), r=0.02)
    K.bolts_line(g, M["boulon"], (-0.5, 0.54, za - 0.28), (0.5, 0.54, za - 0.28), 8, n=(0, 1, -0.2), r=0.02)
    for sx in (-1, 1):
        x = sx * 0.27
        g.cyl(M["acier"], 0.17, 0.12, (x, 0.58, za), axis="y", n=28, ch=0.015)
        K.bolts_ring(g, M["boulon"], (x, 0.64, za), 0.14, 8, axis="y", r=0.014)
        K.gatling(g, M, 4, 0.07, 0.034, 0.6, 1.3, x=x, z=za, phase=math.pi / 4, rings=(0.62, 0.95),
                  jacket=(0.62, 1.0, 0.125))
    # moteur électrique bobiné à l'arrière (identité époque 6)
    K.coil(g, M["cuivre"], M["acier"], (0, -0.82, za - 0.02), 0.3, 0.38, axis="y", turns=8, wire=0.028,
           flange=M["tole_sombre"])
    g.cyl(M["tole_sombre"], 0.33, 0.1, (0, -1.07, za - 0.02), axis="y", n=36, ch=0.015)
    K.bolts_ring(g, M["boulon"], (0, -1.12, za - 0.02), 0.27, 10, axis="-y", r=0.018)
    for i in range(10):
        a = TAU * i / 10
        g.push(); g.move((0.0, -1.0, za - 0.02)); g.turn("y", a)
        g.box(M["acier"], (0.034, 0.12, 0.08), (0, 0, 0.34), 0.0)
        g.pop()
    g.cyl(M["acier"], 0.08, 0.06, (0, -1.15, za - 0.02), axis="y", n=16, ch=0.01)
    # piles d'isolateurs dorsales, éclateur (arc cyan) et câbles vers le moteur
    ztop = za + 0.38
    for sx in (-1, 1):
        K.insulator_stack(g, M["porcelaine"], M["laiton"], (sx * 0.26, -0.36, ztop), 5, 0.085, 0.055, 0.045,
                          base_mat=M["acier"])
        g.cyl(M["cuivre"], 0.016, 0.16, (sx * 0.16, -0.36, ztop + 0.33), axis="x", n=8)
    g.box(M["arc"], (0.13, 0.04, 0.085), (0, -0.36, ztop + 0.33), 0.0)
    g.light((0, -0.36, ztop + 0.33), (0.4, 0.8, 1.0), 4.0)
    K.cable(g, M["cable_r"], [(0.26, -0.48, ztop + 0.05), (0.3, -0.7, za + 0.2), (0.2, -0.82, za + 0.3)], 0.022,
            ties=M["acier"])
    K.cable(g, M["noir"], [(-0.26, -0.48, ztop + 0.05), (-0.3, -0.7, za + 0.2), (-0.2, -0.82, za + 0.3)], 0.022,
            ties=M["acier"])
    # tambour de munitions (gauche) et bande de cartouches
    xd = -0.84
    g.cyl(M["tole"], 0.34, 0.26, (xd, -0.1, za - 0.05), axis="x", n=40, ch=0.02)
    for xx in (xd - 0.08, xd + 0.08):
        g.torus(M["laiton_tore"], 0.345, 0.022, (xx, -0.1, za - 0.05), axis="x", n=48, m=6)
    K.bolts_ring(g, M["boulon"], (xd - 0.13, -0.1, za - 0.05), 0.26, 10, axis="-x", r=0.018)
    g.cyl(M["acier"], 0.09, 0.05, (xd - 0.15, -0.1, za - 0.05), axis="x", n=16, ch=0.01)
    K.ammo_belt(g, M["laiton"], M["noir"], [(xd + 0.02, 0.05, za + 0.27), (-0.6, 0.12, za + 0.42),
                                            (-0.4, 0.15, za + 0.42)], pitch=0.05)
    # réservoir d'eau de refroidissement (droite) et tuyaux de cuivre vers les manchons
    xt = 0.8
    g.cyl(M["tole"], 0.15, 0.62, (xt, -0.18, za + 0.12), axis="y", n=28, ch=0.015)
    K.slit_light(g, M["ambre"], M["laiton"], (xt + 0.15, -0.2, za + 0.12), 0.32, 0.05, (1, 0, 0), bars=1)
    for yy in (-0.4, -0.18, 0.04):
        g.torus(M["laiton_tore"], 0.155, 0.018, (xt, yy, za + 0.12), axis="y", n=32, m=6)
    K.pipe(g, M["cuivre"], M["laiton"], None, [(xt, 0.13, za + 0.12), (xt - 0.1, 0.5, za + 0.12),
                                               (0.42, 0.7, za + 0.12)], 0.03)
    K.pipe(g, M["cuivre"], M["laiton"], None, [(xt - 0.05, -0.5, za + 0.2), (0.62, -0.62, za + 0.3),
                                               (0.3, -0.62, za + 0.34)], 0.026)
    # viseur et voyants
    K.sensor(g, M, (0.2, 0.18, za + 0.38), 0.24, 0.2, 0.14, lens_emit=M["ambre"])
    K.lamp(g, M["ambre"], M["acier"], (-0.3, -0.53, za + 0.2), (0, -1, 0), 0.065)
    K.lamp(g, M["ambre"], M["acier"], (0.3, -0.53, za + 0.2), (0, -1, 0), 0.065)
    # collecteur du moteur : fentes de braise derrière la cloche (lueur ambrée)
    for zz in (za + 0.13, za - 0.17):
        K.slit_light(g, M["ambre"], M["acier"], (0, -1.125, zz), 0.16, 0.05, (0, -1, 0), bars=1)
    for sx in (-1, 1):
        K.slit_light(g, M["arc"], M["acier"], (sx * 0.655, -0.05, za + 0.24), 0.18, 0.05, (sx, 0, 0), bars=0)
    g.light((0, -0.6, za + 0.2), (1.0, 0.45, 0.06), 4.0)
    K.lamp(g, M["ambre"], M["acier"], (-0.3, 0.1, za + 0.39), (0, 0, 1), 0.06, cage=M["acier_clair"])
    K.handrail(g, M["acier_clair"], [(-0.47, -0.52, za + 0.38), (-0.47, 0.34, za + 0.38)], h=0.14, post_every=0.28)
    K.handrail(g, M["acier_clair"], [(0.47, -0.52, za + 0.38), (0.47, 0.34, za + 0.38)], h=0.14, post_every=0.28)
    for sx in (-1, 1):
        g.box(M["acier_clair"], (0.16, 0.74, 0.03), (sx * 0.57, -0.07, za + 0.437), 0.008)
    g.pop()
    return g


# ================================================================================================
# NIVEAU 21 (époque 11, ère IV) : 5×5
# ================================================================================================
def socle_21(g, M, piece=False):
    deck = LEVELS[21]["deck"]
    s1 = octagon(2.45, 3.33, 0.5, 0.7, cy=-0.13)
    g.prism(M["acier"], octagon(2.49, 3.47, 0.52, 0.72, cy=-0.05), 0.0, 0.08)
    g.prism(M["tole_sombre"], s1, 0.06, 0.32)
    plate_poly_edges(g, M, s1, 0.07, 0.32, M["tole"])
    # 2e gradin à glacis incliné au sud
    hx2, hy2 = 2.22, 3.16
    g.prism(M["tole_sombre"], octagon(hx2, 3.03, 0.42, 0.6, cy=-0.13), 0.3, deck)
    glacis = [(-3.4, 0.32), (-3.16, 0.32), (-3.16, deck), (-3.0, deck)]
    g.slab_x(M["tole"], [(y, z) for y, z in glacis], -hx2 + 0.42, hx2 - 0.42)
    # plaques du glacis, grilles d'aération, échelles
    for i, x in enumerate((-1.45, -0.5, 0.5, 1.45)):
        if i in (1, 2):
            K.grille(g, M["acier"], M["tole_sombre"], 0.5, 0.2, (x, -3.29, 0.47), normal=(0, -0.8, 0.6),
                     deep_mat=M["joint"])
        else:
            K.slit_light(g, M["ligne"], M["acier"], (x, -3.29, 0.47), 0.42, 0.07, (0, -0.8, 0.6), bars=2)
            g.light((x, -3.4, 0.5), (0.75, 0.88, 1.0), 5.0)
    plate_poly_edges(g, M, octagon(hx2, 3.03, 0.42, 0.6, cy=-0.13), 0.33, deck - 0.01, M["tole"])
    # pont
    deck_plates(g, M, (-2.0, 2.0), (-2.9, 2.62), deck - 0.002, 9, 12, skip=lambda x, y: (x * x + y * y) < 2.4,
                bolt_spacing=0.17)
    race_ring(g, M, 1.62, deck, 40)
    K.hazard_band(g, M["jaune"], M["noir"], (-1.8, -2.8, deck + 0.03), (1.8, -2.8, deck + 0.03), 0.16, 0.014)
    for sx in (-1, 1):
        parapet(g, M, min(sx * 0.12, sx * 1.76), max(sx * 0.12, sx * 1.76), -3.14, deck, 0.3, emit=M["ligne"],
                embrasures=3, seed=13 + sx)
        g.light((sx * 1.0, -3.3, deck + 0.12), (0.75, 0.88, 1.0), 4.0)
    # bandes de danger autour de la couronne (secteurs avant)
    for a0 in (-2.4, -1.25):
        pts = [(1.9 * math.cos(a0 + 0.08 * k), 1.9 * math.sin(a0 + 0.08 * k), deck + 0.03) for k in range(10)]
        for p, q in zip(pts[:-1], pts[1:]):
            K.hazard_band(g, M["jaune"], M["noir"], p, q, 0.12, 0.012, stripe=0.1)
    K.tread_plate(g, M["acier"], (-1.05, 1.05), (-2.66, -2.0), deck + 0.028)
    # angles avant : trémies de munitions à convoyeur (chargeur automatique)
    for sx in (-1, 1):
        cx, cy = sx * 1.65, -2.35
        K.armor_box(g, M, (0.78, 0.62, 0.36), (cx, cy, deck + 0.18), div_top=(2, 1), div_side=(2, 1),
                    faces=("top", "s", "e", "w"), seed=21 + sx)
        g.slab_x(M["tole_r"], [(cy - 0.02, deck + 0.36), (cy + 0.3, deck + 0.36), (cy + 0.3, deck + 0.6)],
                 cx - 0.36, cx + 0.36)
        K.hazard_band(g, M["jaune"], M["noir"], (cx - 0.38, cy - 0.32, deck + 0.3), (cx + 0.38, cy - 0.32, deck + 0.3),
                      0.07, 0.012, stripe=0.08, n_up=(0, -1, 0))
        # convoyeur vers la couronne : galets et bande de cartouches
        x2 = sx * 1.05
        g.box(M["acier"], (0.2, 0.7, 0.05), ((cx + x2) / 2, cy + 0.6, deck + 0.14), 0.008)
        K.ammo_belt(g, M["laiton"], M["noir"], [(cx - sx * 0.1, cy + 0.3, deck + 0.2), ((cx + x2) / 2, cy + 0.6, deck + 0.2),
                                                (x2, cy + 0.95, deck + 0.18)], pitch=0.05)
        K.lamp(g, M["ambre"], M["acier"], (cx + sx * 0.3, cy - 0.32, deck + 0.42), (0, -1, 0.3), 0.065)
        K.light_strip(g, M["ligne"], M["acier"], (cx - 0.3, cy - 0.33, deck + 0.12), (cx + 0.2, cy - 0.33, deck + 0.12),
                      0.045, n=(0, -1, 0), cells=3)
        g.light((cx + sx * 0.3, cy - 0.45, deck + 0.42), (1.0, 0.45, 0.06), 5.0)
    # flancs : batteries de condensateurs (générateur) avec lignes bleu-blanc, goulottes de câbles
    for sx in (-1, 1):
        cx = sx * 1.92
        g.box(M["tole_sombre"], (0.5, 1.5, 0.05), (cx, 0.15, deck + 0.025), 0.01)
        K.capacitor_bank(g, M, (cx, 0.15, deck + 0.05), 1, 4, r=0.13, h=0.42, pitch=0.34, emit=M["ligne"],
                         cap="laiton")
        K.cable_tray(g, M["acier"], [M["cable_r"], M["noir"], M["cuivre"]], (sx * 1.6, -1.2, deck + 0.01),
                     (sx * 1.6, 1.3, deck + 0.01), w=0.18)
    # arrière : blocs de radiateurs (ailettes) et générateur central
    for sx in (-1, 1):
        cx = sx * 1.55
        K.armor_box(g, M, (0.9, 0.5, 0.18), (cx, 1.98, deck + 0.09), div_top=(2, 1), div_side=(2, 1),
                    faces=("top", "s"), seed=31 + sx)
        K.fins(g, M["acier"], M["tole_sombre"], 0.82, 0.38, 0.4, 13, (cx, 1.98, deck + 0.18), axis="x")
        K.pipe(g, M["cuivre"], M["laiton"], M["boulon"], [(cx - sx * 0.45, 1.8, deck + 0.3),
                                                          (sx * 1.25, 1.55, deck + 0.3), (sx * 1.35, 1.25, deck + 0.1)],
               0.045)
    K.armor_box(g, M, (1.0, 0.42, 0.45), (0.0, 2.2, deck + 0.225), div_top=(2, 1), div_side=(2, 1),
                faces=("top", "s", "e", "w"), seed=41)
    K.coil(g, M["cuivre"], M["acier"], (0, 1.86, deck + 0.22), 0.2, 0.6, axis="x", turns=9, wire=0.026,
           flange=M["tole_sombre"])
    for sx in (-1, 1):
        K.exhaust(g, M, (sx * 0.3, 2.12, deck + 0.45), 0.08, 0.16)
    # échelles sur le premier gradin (repère humain)
    for sx in (-1, 1):
        K.ladder(g, M["acier"], (sx * 1.1, -3.48, 0.0), 0.62, w=0.18, n=(0, -1, 0))
    # pattes d'ancrage
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.push(); g.move((sx * 2.18, sy * (3.1 if sy < 0 else 2.82), 0.0)); g.turn("z", math.atan2(sy * 1.414, sx))
            g.box(M["acier"], (0.42, 0.3, 0.16), (0.16, 0, 0.08), 0.014)
            for d in (-0.08, 0.08):
                K.bolt(g, M["boulon"], (0.26, d, 0.16), r=0.034, washer=M["acier"])
            g.pop()
    return g


def secondary_gun(g, M, c, scale=1.0, n=3, emit=None):
    """Tourelle secondaire (ère IV) : petite couronne, caisson riveté, canons rotatifs courts, viseur."""
    x, y, z = c
    s = scale
    g.cyl(M["tole_sombre"], 0.3 * s, 0.08 * s, (x, y, z + 0.04 * s), n=28, ch=0.01)
    K.bolts_ring(g, M["boulon"], (x, y, z + 0.08 * s), 0.25 * s, 10, r=0.016)
    K.armor_box(g, M, (0.42 * s, 0.5 * s, 0.3 * s), (x, y - 0.04 * s, z + 0.24 * s), div_top=(1, 2), div_side=(1, 1),
                faces=("top", "s", "e", "w", "n"), t=0.03, seed=int(100 * x + 7))
    K.gatling(g, M, n, 0.045 * s, 0.026 * s, y + 0.2 * s, y + 0.75 * s, x=x, z=z + 0.24 * s, rings=(0.1, 0.7),
              muzzle=True)
    K.sensor(g, M, (x + 0.12 * s, y - 0.1 * s, z + 0.39 * s), 0.14 * s, 0.14 * s, 0.09 * s, lens_emit=emit)
    g.count("tourelle_secondaire")


def head_21(g, M):
    """Tourelle lourde de haute technologie (vanilla avancé) : barbette blindée, caisson à plaques jointives et
    glacis incliné à ailerons-blindages (identité Titane, en masse), 2 × 6 canons rotatifs à manchons,
    2 tourelles secondaires latérales, chargeur arrière, radiateurs, générateur, câbles et lignes bleu-blanc."""
    deck = LEVELS[21]["deck"]
    z = turntable(g, M, 1.6, deck, 72)
    zb = 1.85
    barbette(g, M, 1.48, 1.26, z, zb, seams=16, rows=3, bands=("laiton_tore", "laiton_tore"), rad_mult=4,
             slits=M["ligne"])
    g.cyl(M["tole_sombre"], 1.34, 0.08, (0, 0, zb + 0.04), n=56, ch=0.012)
    K.bolts_ring(g, M["boulon"], (0, 0, zb + 0.08), 1.26, 30, r=0.022)
    g.push()
    g.scale_about((0, 0, zb), HEAD_SCALE[21])
    za = zb + 0.7
    # caisson principal
    K.armor_box(g, M, (2.0, 1.9, 0.98), (0, -0.25, zb + 0.08 + 0.49), div_top=(5, 5), div_side=(4, 3),
                faces=("top", "s", "n", "e", "w"), seed=51, plate_mat=[M["peint"], M["tole_b"], M["peint"], M["tole"]])
    # joues blindées latérales (ailerons-blindages en flèche, épais : identité Titane en MASSE)
    for sx in (-1, 1):
        x0, x1 = (1.0, 1.22) if sx > 0 else (-1.22, -1.0)
        prof = [(-1.2, zb + 0.1), (0.9, zb + 0.1), (1.05, za - 0.1), (0.55, za + 0.55), (-0.9, za + 0.55),
                (-1.35, za + 0.15)]
        g.slab_x(M["tole"], prof, x0, x1)
        xo = x1 if sx > 0 else x0
        K.bolts_line(g, M["boulon"], (xo, -1.1, zb + 0.2), (xo, 0.85, zb + 0.2), 11, n=(sx, 0, 0), r=0.022)
        K.bolts_line(g, M["boulon"], (xo, -0.85, za + 0.45), (xo, 0.5, za + 0.45), 8, n=(sx, 0, 0), r=0.022)
        # plaques additionnelles d'alliage blanc patiné (accent d'époque, petite surface)
        for i in range(5):
            for j in range(2):
                yy = -1.0 + i * 0.4
                zz = zb + 0.42 + j * 0.3
                g.box(M["alliage"] if (i + j) % 3 == 0 else M["tole_sombre"], (0.05, 0.36, 0.26),
                      (xo + sx * 0.025, yy, zz), 0.012)
                for dy in (-0.13, 0.13):
                    for dz in (-0.09, 0.09):
                        K.bolt(g, M["boulon"], (xo + sx * 0.05, yy + dy, zz + dz), (sx, 0, 0), 0.016)
        K.light_strip(g, M["ligne"], M["acier"], (xo + sx * 0.03, -1.1, zb + 0.2), (xo + sx * 0.03, 0.75, zb + 0.2),
                      0.045, n=(sx, 0, 0), cells=8)
        K.light_strip(g, M["ligne"], M["acier"], (xo + sx * 0.03, -1.05, za + 0.3), (xo + sx * 0.03, 0.5, za + 0.3),
                      0.05, n=(sx, 0, 0), cells=7)
        # tourelle secondaire sur sponson
        g.box(M["tole_sombre"], (0.5, 0.7, 0.12), (sx * 1.48, -0.35, zb + 0.4), 0.012)
        xa, xb = (1.22, 1.7) if sx > 0 else (-1.7, -1.22)
        g.slab_x(M["tole"], [(-0.7, zb + 0.1), (0.0, zb + 0.1), (0.0, zb + 0.34), (-0.7, zb + 0.34)], xa, xb)
        secondary_gun(g, M, (sx * 1.48, -0.3, zb + 0.46), 1.0, n=3, emit=M["ligne"])
    # glacis frontal incliné et masque
    g.slab_x(M["tole_sombre"], [(0.68, zb + 0.1), (1.05, zb + 0.18), (1.05, za + 0.15), (0.7, za + 0.55)], -1.0, 1.0)
    K.bolts_line(g, M["boulon"], (-0.9, 0.9, za + 0.33), (0.9, 0.9, za + 0.33), 12, n=(0, 0.6, 0.8), r=0.022)
    K.bolts_line(g, M["boulon"], (-0.9, 1.06, zb + 0.3), (0.9, 1.06, zb + 0.3), 12, n=(0, 1, 0), r=0.022)
    K.hazard_band(g, M["jaune"], M["noir"], (-0.95, 1.03, zb + 0.16), (0.95, 1.03, zb + 0.16), 0.08, 0.012,
                  stripe=0.09, n_up=(0, 1, 0))
    for sx in (-1, 1):
        x = sx * 0.5
        g.cyl(M["acier"], 0.3, 0.16, (x, 1.08, za), axis="y", n=32, ch=0.02)
        K.bolts_ring(g, M["boulon"], (x, 1.16, za), 0.25, 10, axis="y", r=0.018)
        K.gatling(g, M, 6, 0.12, 0.045, 1.1, 1.92, x=x, z=za, phase=0.0, rings=(0.62, 0.96),
                  jacket=(1.12, 1.56, 0.2))
        K.pipe(g, M["cuivre"], M["laiton"], None, [(x + sx * 0.18, 0.75, za + 0.42), (x + sx * 0.18, 1.3, za + 0.2),
                                                   (x + sx * 0.12, 1.45, za + 0.16)], 0.032)
    # toit : radiateurs à ailettes, viseur, échappements, faisceaux de câbles
    ztop = zb + 0.08 + 0.98
    K.fins(g, M["acier"], M["tole_sombre"], 1.1, 0.24, 0.5, 15, (0, -0.75, ztop), axis="x")
    K.sensor(g, M, (0.45, 0.35, ztop), 0.34, 0.26, 0.2, lens_emit=M["ligne"])
    for sx in (-1, 1):
        K.light_strip(g, M["ligne"], M["acier"], (sx * 0.93, -1.15, ztop + 0.04), (sx * 0.93, 0.62, ztop + 0.04),
                      0.05, cells=8)
    K.hatch(g, M["tole"], M["acier"], M["boulon"], (0.42, 0.36, 0.035), (-0.45, 0.25, ztop))
    for sx in (-1, 1):
        K.exhaust(g, M, (sx * 0.72, -0.85, ztop), 0.075, 0.2)
        K.slit_light(g, M["ligne"], M["acier"], (sx * 0.42, -0.25, ztop + 0.02), 0.36, 0.2, (0, 0, 1), bars=2)
    K.cable_bundle(g, [M["cable_r"], M["noir"], M["cable_r"]], [(-0.9, -1.0, ztop + 0.02), (-0.2, -0.3, ztop + 0.05),
                                                                (0.2, 0.05, ztop + 0.04)], spread=0.05, r=0.02,
                   ties=M["acier"])
    # arrière : chargeur automatique (tambour, bandes) et générateur à bobines
    K.armor_box(g, M, (1.5, 0.55, 0.78), (0, -1.45, zb + 0.08 + 0.39), div_top=(2, 1), div_side=(3, 2),
                faces=("top", "s", "e", "w"), seed=61)
    for sx in (-1, 1):
        g.cyl(M["tole"], 0.26, 0.3, (sx * 0.5, -1.82, zb + 0.5), axis="y", n=32, ch=0.02)
        K.bolts_ring(g, M["boulon"], (sx * 0.5, -1.97, zb + 0.5), 0.2, 8, axis="-y", r=0.018)
        g.torus(M["laiton_tore"], 0.265, 0.02, (sx * 0.5, -1.75, zb + 0.5), axis="y", n=36, m=6)
        K.ammo_belt(g, M["laiton"], M["noir"], [(sx * 0.65, -1.5, zb + 0.9), (sx * 0.9, -0.9, za + 0.25),
                                                (sx * 0.85, -0.3, za + 0.42), (sx * 0.6, 0.4, za + 0.45)], pitch=0.05)
    K.coil(g, M["cuivre"], M["acier"], (0, -1.8, zb + 0.95), 0.16, 0.7, axis="x", turns=10, wire=0.024,
           flange=M["tole_sombre"])
    for sx in (-1, 1):
        K.slit_light(g, M["ligne"], M["acier"], (sx * 0.3, -1.73, zb + 0.32), 0.36, 0.06, (0, -1, 0), bars=2)
        K.lamp(g, M["ambre"], M["acier"], (sx * 0.72, -1.73, zb + 0.72), (0, -1, 0), 0.045)
    g.light((0, -1.9, zb + 0.5), (0.75, 0.88, 1.0), 6.0)
    g.pop()
    return g


# ================================================================================================
# NIVEAU 29 (époque 15, ère V) : 6×6 ; NIVEAU 30 : + bastions d'angle
# ================================================================================================
def socle_29(g, M, piece=False):
    deck = LEVELS[29]["deck"]
    cf = ((1.0, 1.41), (1.0, 1.41), (0.6, 0.85), (0.6, 0.85))     # chanfreins avant larges (bastions du niv. 30)
    s1 = octagon(2.94, 3.99, 0, 0, cf=cf, cy=-0.17)
    g.prism(M["acier"], octagon(2.98, 4.12, 0, 0, cf=((1.02, 1.44), (1.02, 1.44), (0.62, 0.88), (0.62, 0.88)), cy=-0.08), 0, 0.09)
    g.prism(M["tole_sombre"], s1, 0.07, 0.38)
    plate_poly_edges(g, M, s1, 0.08, 0.38, M["tole"])
    hx2, hy2 = 2.66, 3.78
    s2 = octagon(hx2, 3.61, 0, 0, cf=((0.85, 1.2), (0.85, 1.2), (0.5, 0.7), (0.5, 0.7)), cy=-0.17)
    g.prism(M["tole_sombre"], s2, 0.36, deck)
    plate_poly_edges(g, M, s2, 0.39, deck - 0.01, M["tole"])
    g.slab_x(M["tole"], [(-4.05, 0.38), (-3.78, 0.38), (-3.78, deck), (-3.6, deck)], -hx2 + 0.85, hx2 - 0.85)
    for i, x in enumerate((-1.45, -0.72, 0.0, 0.72, 1.45)):
        if i % 2 == 1:
            K.grille(g, M["acier"], M["tole_sombre"], 0.5, 0.24, (x, -3.92, 0.57), normal=(0, -0.8, 0.6),
                     deep_mat=M["joint"])
        else:
            K.slit_light(g, M["or_lum"], M["acier"], (x, -3.92, 0.57), 0.46, 0.11, (0, -0.8, 0.6), bars=3)
            g.light((x, -4.05, 0.6), (1.0, 0.9, 0.65), 6.0)
    # pont
    deck_plates(g, M, (-2.45, 2.45), (-3.5, 3.2), deck - 0.002, 11, 15, skip=lambda x, y: (x * x + y * y) < 4.1,
                bolt_spacing=0.17)
    race_ring(g, M, 2.0, deck, 48)
    K.hazard_band(g, M["jaune"], M["noir"], (-1.6, -3.42, deck + 0.03), (1.6, -3.42, deck + 0.03), 0.18, 0.014)
    for sx in (-1, 1):
        parapet(g, M, min(sx * 0.12, sx * 1.8), max(sx * 0.12, sx * 1.8), -3.76, deck, 0.32, emit=M["ligne"],
                embrasures=3, seed=17 + sx)
        K.light_strip(g, M["ligne"], M["acier"], (sx * 1.98, -1.35, deck + 0.04), (sx * 1.98, 0.95, deck + 0.04),
                      0.05, cells=10)
        g.light((sx * 1.2, -3.7, deck + 0.1), (1.0, 0.85, 0.55), 4.0)
    for a0 in (-2.55, -1.2):
        pts = [(2.3 * math.cos(a0 + 0.07 * k), 2.3 * math.sin(a0 + 0.07 * k), deck + 0.03) for k in range(12)]
        for p, q in zip(pts[:-1], pts[1:]):
            K.hazard_band(g, M["jaune"], M["noir"], p, q, 0.14, 0.012, stripe=0.1)
    K.tread_plate(g, M["acier"], (-1.2, 1.2), (-3.28, -2.42), deck + 0.028)
    # angles avant : soutes à munitions basses (bandes de danger, convoyeurs vers la couronne)
    for sx in (-1, 1):
        cx, cy = sx * 1.75, -2.75
        K.armor_box(g, M, (0.9, 0.7, 0.34), (cx, cy, deck + 0.17), div_top=(2, 2), div_side=(2, 1),
                    faces=("top", "s", "e", "w"), seed=71 + sx)
        K.hazard_band(g, M["jaune"], M["noir"], (cx - 0.44, cy - 0.36, deck + 0.24), (cx + 0.44, cy - 0.36, deck + 0.24),
                      0.08, 0.012, stripe=0.08, n_up=(0, -1, 0))
        K.hatch(g, M["tole"], M["acier"], M["boulon"], (0.34, 0.3, 0.03), (cx, cy + 0.05, deck + 0.34))
        x2 = sx * 1.3
        g.box(M["acier"], (0.22, 0.85, 0.05), ((cx + x2) / 2, cy + 0.75, deck + 0.15), 0.008)
        K.ammo_belt(g, M["laiton"], M["noir"], [(cx - sx * 0.15, cy + 0.36, deck + 0.22),
                                                ((cx + x2) / 2, cy + 0.75, deck + 0.21), (x2, cy + 1.15, deck + 0.19)],
                    pitch=0.05)
        K.lamp(g, M["ambre"], M["acier"], (cx + sx * 0.32, cy - 0.36, deck + 0.4), (0, -1, 0.3), 0.05)
        g.light((cx + sx * 0.32, cy - 0.5, deck + 0.4), (1.0, 0.45, 0.06), 5.0)
    # flancs : murs de radiateurs et goulottes
    for sx in (-1, 1):
        cx = sx * 2.3
        g.box(M["tole_sombre"], (0.55, 2.4, 0.06), (cx, -0.2, deck + 0.03), 0.01)
        K.fins(g, M["acier"], M["tole_sombre"], 2.2, 0.36, 0.46, 30, (cx, -0.2, deck + 0.06), axis="y")
        K.pipe(g, M["cuivre"], M["laiton"], M["boulon"], [(cx - sx * 0.32, -1.4, deck + 0.12),
                                                          (cx - sx * 0.32, 1.0, deck + 0.12),
                                                          (sx * 1.8, 1.7, deck + 0.12)], 0.05, clamp_every=0.5)
        K.cable_tray(g, M["acier"], [M["cable_r"], M["noir"], M["cuivre"], M["cable_r"]], (sx * 1.85, -2.0, deck + 0.01),
                     (sx * 1.85, -0.9, deck + 0.01), w=0.2)
    # angles arrière : tours de réserve d'énergie (cellules lumineuses derrière des grilles)
    for sx in (-1, 1):
        cx, cy = sx * 2.05, 2.15
        K.armor_box(g, M, (0.95, 0.75, 0.65), (cx, cy, deck + 0.325), div_top=(2, 2), div_side=(2, 2),
                    faces=("top", "s", "e", "w"), seed=81 + sx)
        for k, dx in enumerate((-0.22, 0.22)):
            K.slit_light(g, M["or_lum"], M["acier"], (cx + dx, cy - 0.39, deck + 0.34), 0.28, 0.44, (0, -1, 0), bars=2)
        g.light((cx, cy - 0.6, deck + 0.4), (1.0, 0.9, 0.65), 7.0)
        K.capacitor_bank(g, M, (cx, cy + 0.05, deck + 0.65), 2, 2, r=0.11, h=0.2, pitch=0.3, cap="or_blanc",
                         emit=M["or_lum"])
        K.cable_bundle(g, [M["cable_r"], M["noir"], M["cuivre"]], [(cx - sx * 0.48, cy - 0.1, deck + 0.3),
                                                                  (sx * 1.35, 1.75, deck + 0.06),
                                                                  (sx * 1.05, 1.62, deck + 0.05)],
                       spread=0.055, r=0.022, ties=M["acier"])
    # arrière centre : générateur (bobines) et échappements
    K.armor_box(g, M, (1.5, 0.5, 0.5), (0.0, 2.55, deck + 0.25), div_top=(3, 1), div_side=(3, 1),
                faces=("top", "s"), seed=91)
    K.coil(g, M["cuivre"], M["acier"], (0, 2.15, deck + 0.24), 0.17, 1.0, axis="x", turns=14, wire=0.024,
           flange=M["tole_sombre"])
    for sx in (-1, 0, 1):
        K.exhaust(g, M, (sx * 0.5, 2.42, deck + 0.5), 0.07, 0.12)
    for sx in (-1, 1):
        K.ladder(g, M["acier"], (sx * 0.95, -4.18, 0.0), 0.76, w=0.18, n=(0, -1, 0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            if sy < 0:
                continue
            g.push(); g.move((sx * 2.5, sy * 3.45, 0.0)); g.turn("z", math.atan2(sy * 1.414, sx))
            g.box(M["acier"], (0.46, 0.34, 0.18), (0.18, 0, 0.09), 0.014)
            for d in (-0.09, 0.09):
                K.bolt(g, M["boulon"], (0.3, d, 0.18), r=0.036, washer=M["acier"])
            g.pop()
    if piece:
        bastions_30(g, M)
    return g


def bastions_30(g, M):
    """Pièce du niveau 30 : deux bastions d'angle lance-roquettes, posés dans les chanfreins avant du socle (zone
    jamais recouverte par la tête, F46) : blindage pentagonal, caisson à 2 × 3 tubes, bande de danger, voyant."""
    deck = LEVELS[29]["deck"]
    for sx in (-1, 1):
        # remplissage du chanfrein (triangle) par un bastion bas
        poly = [(sx * 1.98, -4.16), (sx * 2.94, -4.16), (sx * 2.94, -2.72)]
        g.prism(M["tole_sombre"], poly, 0.0, 0.36)
        plate_poly_edges(g, M, poly if sx < 0 else poly[::-1], 0.02, 0.35, M["tole"])
        # lanceur : caisson incliné, 2 × 3 tubes
        cx, cy = sx * 2.42, -3.55
        g.push(); g.move((cx, cy, 0.36)); g.turn("z", -sx * 0.6)
        K.armor_box(g, M, (0.62, 0.5, 0.26), (0, 0, 0.13), div_top=(2, 1), div_side=(2, 1),
                    faces=("top", "s", "e", "w", "n"), seed=101 + sx)
        g.push(); g.move((0, 0.02, 0.26)); g.turn("x", 0.55)
        g.box(M["acier"], (0.56, 0.48, 0.26), (0, 0, 0.13), 0.014)
        for i in range(3):
            for j in range(2):
                x = -0.18 + i * 0.18
                zz = 0.07 + j * 0.12
                g.cyl(M["joint"], 0.05, 0.02, (x, -0.245, zz), axis="y", n=12)
                g.torus(M["acier"], 0.058, 0.014, (x, -0.245, zz), axis="y", n=16, m=5)
                g.dome(M["jaune"], 0.032, (x, -0.235, zz), axis="-y", n=8, rings=2)
        K.hazard_band(g, M["jaune"], M["noir"], (-0.28, -0.25, 0.27), (0.28, -0.25, 0.27), 0.05, 0.01, stripe=0.07,
                      n_up=(0, -1, 0))
        g.pop()
        g.pop()
        K.lamp(g, M["ambre"], M["acier"], (sx * 2.7, -4.05, 0.3), (0, -1, 0.3), 0.045)
        g.light((sx * 2.7, -4.2, 0.3), (1.0, 0.45, 0.06), 4.0)
        g.count("bastion")


def head_29(g, M):
    """Forteresse : barbette blindée, caisson à plaques multiples (briques additionnelles), couronne de 3 canons
    rotatifs lourds (6 + 6 + 6 tubes), 2 tourelles secondaires d'épaule et 1 dorsale, réserve d'énergie arrière
    (cellules or blanc lumineuses derrière grilles), radiateurs, chargeur, câbles, capteurs."""
    deck = LEVELS[29]["deck"]
    z = turntable(g, M, 1.95, deck, 84)
    zb = 2.05
    barbette(g, M, 1.82, 1.55, z, zb, seams=18, rows=4, bands=("laiton_tore", "laiton_tore"), rad_mult=4,
             slits=M["or_lum"])
    g.cyl(M["tole_sombre"], 1.62, 0.09, (0, 0, zb + 0.045), n=64, ch=0.014)
    K.bolts_ring(g, M["boulon"], (0, 0, zb + 0.09), 1.54, 36, r=0.024)
    for i in range(16):
        a = TAU * (i + 0.5) / 16
        K.lamp(g, M["or_lum"], M["acier"], (1.6 * math.cos(a), 1.6 * math.sin(a), zb - 0.1), (math.cos(a), math.sin(a), 0.2),
               0.055)
    g.push()
    g.scale_about((0, 0, zb), HEAD_SCALE[29])
    za = zb + 0.82
    H = 1.15
    zc = zb + 0.09 + H / 2
    K.armor_box(g, M, (2.4, 2.3, H), (0, -0.3, zc), div_top=(6, 5), div_side=(5, 3),
                faces=("top", "s", "n", "e", "w"), seed=111, plate_mat=[M["peint"], M["tole_b"], M["peint"], M["tole"]])
    # briques de blindage additionnelles (plaques multiples) sur les flancs
    for sx in (-1, 1):
        x0, x1 = (1.2, 1.46) if sx > 0 else (-1.46, -1.2)
        prof = [(-1.45, zb + 0.1), (1.0, zb + 0.1), (1.2, za - 0.1), (0.7, za + 0.62), (-1.1, za + 0.62),
                (-1.6, za + 0.2)]
        g.slab_x(M["tole"], prof, x0, x1)
        xo = x1 if sx > 0 else x0
        for i in range(4):
            for j in range(2):
                yy = -1.15 + i * 0.52
                zz = zb + 0.34 + j * 0.42
                g.box(M["tole_sombre"] if (i + j) % 2 else M["alliage"], (0.07, 0.46, 0.36), (xo + sx * 0.035, yy, zz),
                      0.012)
                for dy in (-0.18, 0.18):
                    for dz in (-0.13, 0.13):
                        K.bolt(g, M["boulon"], (xo + sx * 0.072, yy + dy, zz + dz), (sx, 0, 0), 0.018)
        K.bolts_line(g, M["boulon"], (xo, -1.3, za + 0.52), (xo, 0.6, za + 0.52), 10, n=(sx, 0, 0), r=0.022)
        for k, yy in enumerate((0.85, 0.55)):
            K.slit_light(g, M["or_lum"], M["acier"], (xo + sx * 0.075, yy, zb + 0.13), 0.24, 0.06, (sx, 0, 0), bars=1)
        K.light_strip(g, M["ligne"], M["acier"], (xo + sx * 0.03, -1.4, za + 0.36), (xo + sx * 0.03, 0.5, za + 0.36),
                      0.05, n=(sx, 0, 0), cells=8)
        K.light_strip(g, M["or_lum"], M["acier"], (xo + sx * 0.08, -1.3, zb + 0.18), (xo + sx * 0.08, 0.7, zb + 0.18),
                      0.045, n=(sx, 0, 0), cells=9)
        # épaule : sponson et tourelle secondaire
        g.slab_x(M["tole"], [(-0.95, zb + 0.12), (0.2, zb + 0.12), (0.2, zb + 0.5), (-0.95, zb + 0.5)],
                 min(sx * 1.46, sx * 2.05), max(sx * 1.46, sx * 2.05))
        g.box(M["tole_sombre"], (0.6, 1.1, 0.06), (sx * 1.76, -0.38, zb + 0.53), 0.012)
        secondary_gun(g, M, (sx * 1.76, -0.3, zb + 0.56), 1.25, n=3, emit=M["ligne"])
    # glacis frontal et couronne de 3 canons rotatifs lourds
    g.slab_x(M["tole_sombre"], [(0.85, zb + 0.1), (1.3, zb + 0.2), (1.3, za + 0.2), (0.85, za + 0.62)], -1.2, 1.2)
    K.bolts_line(g, M["boulon"], (-1.1, 1.1, za + 0.42), (1.1, 1.1, za + 0.42), 14, n=(0, 0.6, 0.8), r=0.022)
    K.bolts_line(g, M["boulon"], (-1.1, 1.31, zb + 0.32), (1.1, 1.31, zb + 0.32), 14, n=(0, 1, 0), r=0.022)
    K.hazard_band(g, M["jaune"], M["noir"], (-1.15, 1.28, zb + 0.18), (1.15, 1.28, zb + 0.18), 0.09, 0.012,
                  stripe=0.09, n_up=(0, 1, 0))
    guns = ((0.0, za + 0.12, 0.17, 0.058), (-0.72, za - 0.08, 0.14, 0.05), (0.72, za - 0.08, 0.14, 0.05))
    for x, zz, rr, br in guns:
        g.cyl(M["acier"], rr + 0.2, 0.18, (x, 1.36, zz), axis="y", n=36, ch=0.02)
        K.bolts_ring(g, M["boulon"], (x, 1.45, zz), rr + 0.15, 12, axis="y", r=0.018)
        g.torus(M["or_blanc"], rr + 0.2, 0.025, (x, 1.42, zz), axis="y", n=40, m=6)
        K.gatling(g, M, 6, rr, br, 1.4, 2.32 if x == 0 else 2.2, x=x, z=zz, phase=0.0, rings=(0.6, 0.96),
                  jacket=(1.42, 1.9, rr + br + 0.06))
        K.pipe(g, M["cuivre"], M["laiton"], None, [(x + 0.2, 0.95, za + 0.5), (x + 0.2, 1.5, zz + rr + 0.2),
                                                   (x + 0.15, 1.65, zz + rr + 0.12)], 0.03)
    # toit : tourelle dorsale, radiateurs, capteurs, câbles
    ztop = zb + 0.09 + H
    g.cyl(M["tole_sombre"], 0.5, 0.14, (0, -0.55, ztop + 0.07), n=40, ch=0.014)
    K.bolts_ring(g, M["boulon"], (0, -0.55, ztop + 0.14), 0.44, 14, r=0.018)
    secondary_gun(g, M, (0, -0.6, ztop + 0.14), 1.35, n=4, emit=M["or_lum"])
    for sx in (-1, 1):
        K.slit_light(g, M["or_lum"], M["acier"], (sx * 0.62, -0.05, ztop + 0.02), 0.42, 0.24, (0, 0, 1), bars=3)
        K.fins(g, M["acier"], M["tole_sombre"], 0.75, 0.26, 0.55, 11, (sx * 0.8, -1.05, ztop), axis="x")
        K.sensor(g, M, (sx * 0.72, 0.45, ztop), 0.32, 0.26, 0.2, lens_emit=M["ligne"])
        K.exhaust(g, M, (sx * 0.95, -0.35, ztop), 0.075, 0.18)
    K.hatch(g, M["tole"], M["acier"], M["boulon"], (0.4, 0.36, 0.035), (0.0, 0.5, ztop))
    for sx in (-1, 1):
        K.light_strip(g, M["ligne"], M["acier"], (sx * 1.13, -1.35, ztop + 0.04), (sx * 1.13, 0.75, ztop + 0.04),
                      0.05, cells=9)
    K.cable_bundle(g, [M["cable_r"], M["noir"], M["cuivre"], M["cable_r"]],
                   [(-1.1, -1.3, ztop + 0.02), (-0.5, -0.05, ztop + 0.05), (0.3, 0.2, ztop + 0.04),
                    (0.95, 0.2, ztop + 0.04)], spread=0.05, r=0.02, ties=M["acier"])
    # arrière : réserve d'énergie (cellules lumineuses or blanc derrière grilles), chargeur, bobines
    K.armor_box(g, M, (2.0, 0.7, 0.95), (0, -1.8, zb + 0.09 + 0.475), div_top=(3, 1), div_side=(4, 2),
                faces=("top", "s", "e", "w"), seed=121)
    for i, x in enumerate((-0.66, -0.22, 0.22, 0.66)):
        K.slit_light(g, M["or_lum"], M["acier"], (x, -2.16, zb + 0.55), 0.17, 0.4, (0, -1, 0), bars=2)
    g.light((0, -2.4, zb + 0.55), (1.0, 0.9, 0.65), 9.0)
    K.coil(g, M["cuivre"], M["acier"], (0, -2.0, zb + 1.17), 0.17, 1.2, axis="x", turns=16, wire=0.024,
           flange=M["tole_sombre"])
    for sx in (-1, 1):
        g.cyl(M["tole"], 0.3, 0.32, (sx * 0.85, -2.25, zb + 0.4), axis="y", n=36, ch=0.02)
        K.bolts_ring(g, M["boulon"], (sx * 0.85, -2.41, zb + 0.4), 0.23, 10, axis="-y", r=0.018)
        g.torus(M["laiton_tore"], 0.305, 0.022, (sx * 0.85, -2.18, zb + 0.4), axis="y", n=40, m=6)
        K.ammo_belt(g, M["laiton"], M["noir"], [(sx * 0.95, -1.9, zb + 1.0), (sx * 1.15, -1.0, za + 0.45),
                                                (sx * 1.05, -0.2, za + 0.62), (sx * 0.75, 0.6, za + 0.66)], pitch=0.05)
        K.lamp(g, M["ambre"], M["acier"], (sx * 0.98, -2.16, zb + 0.85), (0, -1, 0), 0.045)
    g.pop()
    return g


# ------------------------------------------------------------------------------------------------
# Construction d'une variante
# ------------------------------------------------------------------------------------------------
def variants():
    """Variantes à rendre : socle de chaque niveau, tête N et E de chaque niveau impair, socle + pièce du
    niveau 30 (la tête du niveau 30 est celle du 29, la pièce est sur le socle)."""
    v = {}
    for lv in (11, 21, 29):
        v["n%02d-socle" % lv] = {"level": lv, "part": "socle"}
        for p in POSES:
            v["n%02d-tete-%s" % (lv, p)] = {"level": lv, "part": "tete", "pose": p}
    v["n30-socle"] = {"level": 30, "part": "socle"}
    return v


def build(name):
    """Renvoie (Geo, matériaux, angle de la tête) de la variante."""
    meta = variants()[name]
    lv = meta["level"]
    M_specs = materials(lv)
    M = {k: k for k in M_specs}
    g = Geo(name)
    if meta["part"] == "socle":
        if lv == 11:
            socle_11(g, M)
        elif lv == 21:
            socle_21(g, M)
        else:
            socle_29(g, M, piece=(lv == 30))
        return g, M_specs, 0.0
    if lv == 11:
        head_11(g, M)
    elif lv == 21:
        head_21(g, M)
    else:
        head_29(g, M)
    return g, M_specs, POSES[meta["pose"]]
