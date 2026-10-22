"""Mitrailleuse, exploration de style « HYBRIDE PROGRESSIVE » (lot V3-S, 22/10/2026), REPRISE de l'après-midi :
niveaux témoins 11 (époque 6, 3×3), 21 (époque 11, 5×5), 29 (époque 15, 6×6) et pièce du niveau 30.
Python PUR (geo, kit, parts).

Ce qui change par rapport aux essais de 8 h 50 (critique de l'orchestrateur, point par point) :
1. PLUS DE PONT PLAT. Le socle n'est plus une dalle carrée à coins coupés : c'est un FÛT rond (barbette) au centre,
   entouré de VOLUMES qui ont de la hauteur et une fonction (réservoirs couchés et debout, chaudière et cheminée,
   dynamo, générateur, radiateurs, batteries, tours de cellules, coffres et caisses de munitions, tourelles
   secondaires sur piédestal), reliés par des gaines annelées qui passent PAR-DESSUS (réacteur vanilla). Les
   angles portent des semelles d'ancrage qui dépassent (F42) ; le contour n'est jamais un carré ; entre les
   volumes, des ombres internes et le sol.
2. LA TÊTE DOMINE. Elle est surélevée sur le fût (la tête du niveau 29 culmine vers 2,9 unités), plus large que
   la moitié de l'emprise, et se lit comme une ARME : canons rotatifs multiples, longs, à manchons et freins de
   bouche ; berceau à tourillons ; culasse ronde ; tambours et coffres de munitions ; bandes de cartouches. Elle
   grandit avec l'ère : 2 × 4 canons (n11), 2 × 6 canons lourds (n21), 1 × 8 + 2 × 6 canons et tourelle dorsale
   (n29).
3. MATÉRIAUX MÉLANGÉS. Tôle brune rouillée et laiton (cheminée V0) à l'ère II ; à l'ère IV-V, acier sombre chaud,
   plaques peintes patinées (olive, crème du réacteur, ocre), cuivre et laiton des tuyaux, bandes de danger ;
   arêtes chanfreinées qui attrapent un reflet franc.
4. RELIEF. Étages (couronne à contreforts, fût, tête), pièces en saillie, ombres portées internes.
5. MICRO-DÉTAIL PARTOUT. Chaque volume porte sa visserie (rivets, boulons, colliers, anneaux de gaine, lamelles,
   ailettes) : la densité par tuile ne doit pas baisser avec la taille.

Règles de calque (CHANGÉES, à prouver en moteur) : le socle d'une grande tourelle ne peut plus être dessiné en
« lower-object » (valeur par défaut de TurretPrototype.base_picture_render_layer) : ses volumes arrière montent
au-dessus du bord nord de l'emprise et seraient recouverts par l'entité voisine. Le prototype devra déclarer
base_picture_render_layer = "object" et gun_animation_secondary_draw_order = 1 (la tête au-dessus du socle,
même calque). Contraintes gardées : la tête est dessinée PAR-DESSUS tout le socle, donc rien du socle situé
devant elle (au sud) ne monte dans sa zone à l'écran ; la pièce du niveau 30 est posée là où la tête ne passe
jamais (F46) ; O ≤ 0,40 × côté (charte).

Repère : geo.py (1 unité = 1 tuile en X ; une tuile de jeu vers le sud = 1,414 unité en Y ; +Z haut). Tête
modélisée canons vers +Y (pose N) ; pose E = rotation de -90° autour de Z.
"""
import math

import kit as K
import parts as PT
from geo import Geo, MIN_T, SQ2, TAU

# ------------------------------------------------------------------------------------------------
# Niveaux
# ------------------------------------------------------------------------------------------------
LEVELS = {
    11: {"epoch": 6, "era": "II", "side": 3, "deck": 0.62},
    21: {"epoch": 11, "era": "IV", "side": 5, "deck": 1.02},
    29: {"epoch": 15, "era": "V", "side": 6, "deck": 1.36},
    30: {"epoch": 15, "era": "V", "side": 6, "deck": 1.36, "piece": True},
}
# « deck » : hauteur du chemin de roulement au sommet du fût (pied de la tête)
POSES = {"N": 0.0, "E": -math.pi / 2}
HEAD_SCALE = {11: 1.18, 21: 1.12, 29: 1.15}

# Systèmes fonctionnels (charte §6.2 ; chaque niveau reprend tout ce qui précède)
SYSTEMS = {
    11: ["tête à canons rotatifs (2 × 4 canons)", "alimentation en munitions (tambour, bande, caisses du socle)",
         "socle pivotant (fût riveté, couronne dentée)", "blindage frontal (masque, flasques)",
         "refroidissement des canons (manchons à eau, réservoir couché, chaudière et cheminée, gaines)",
         "canons jumelés", "moteur électrique bobiné, dynamo et isolateurs (époque 6)"],
}
SYSTEMS[21] = SYSTEMS[11] + [
    "chargeur automatique (coffres, convoyeur et bandes vers la culasse)", "câblage et goulottes",
    "viseur / capteur optique", "générateur couché et batteries de condensateurs", "tourelle secondaire sur piédestal",
    "radiateurs (blocs à ailettes)", "ailerons blindés arrière (époque 11)"]
SYSTEMS[29] = SYSTEMS[21] + [
    "tourelles secondaires multiples (2 sur piédestal + 1 dorsale)", "réserve d'énergie visible (2 tours de cellules)",
    "blindage à plaques multiples (briques additionnelles)", "couronne de 3 canons rotatifs lourds (8 + 6 + 6 tubes)"]
SYSTEMS[30] = SYSTEMS[29] + ["lance-roquettes avant (pièce du niveau 30)"]
ANIMATIONS = {
    11: ["tir (rotation des canons)", "arc de l'éclateur entre les isolateurs", "braises de la cheminée"],
    21: ["tir (rotation des canons)", "bande de cartouches", "chenillard des lignes bleu-blanc", "voyants qui clignotent",
         "tourelle secondaire (rotation)"],
    29: ["tir (rotation des canons)", "bandes de cartouches", "cellules d'énergie qui pulsent", "voyants qui clignotent",
         "tourelles secondaires (rotation)", "chenillard des lignes dorées"],
}
ANIMATIONS[30] = ANIMATIONS[29]

# ------------------------------------------------------------------------------------------------
# Matériaux (couleurs LINÉAIRES ; paramètres de fo_scene.mat_metal / mat_emissive). Ancre de style : la cheminée
# V0 validée (tôle brune rouillée, cerclages laiton, rivets, crasse des creux).
# ------------------------------------------------------------------------------------------------
RUST = (0.13, 0.05, 0.018)


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
    "joint": _metal((0.016, 0.014, 0.012), rough=0.75, metallic=0.3, grain=0.2, dirt=0.5),
    "tole": _metal((0.22, 0.17, 0.12), rough=0.38, metallic=0.55, grain=0.55, rust_amount=0.5, rust_scale=4.5,
                   dirt=0.85, dirt_distance=0.14),
    "tole_b": _metal((0.36, 0.3, 0.22), rough=0.34, metallic=0.55, grain=0.5, rust_amount=0.35, rust_scale=5.5,
                     dirt=0.85, dirt_distance=0.14),
    "tole_r": _metal((0.2, 0.13, 0.085), rough=0.45, metallic=0.5, grain=0.55, rust_amount=0.75, rust_scale=6.0,
                     dirt=0.85, dirt_distance=0.14),
    "tole_sombre": _metal((0.1, 0.086, 0.07), rough=0.42, metallic=0.55, grain=0.55, rust_amount=0.4, rust_scale=5.0,
                          dirt=0.85, dirt_distance=0.14),
    "acier": _metal((0.25, 0.23, 0.2), rough=0.3, metallic=0.8, grain=0.38, grain_scale=26.0, rust_amount=0.25,
                    rust_scale=6.0, dirt=0.75, dirt_distance=0.14),
    "acier_clair": _metal((0.46, 0.43, 0.38), rough=0.28, metallic=0.8, grain=0.25, rust_amount=0.12, dirt=0.6,
                          dirt_distance=0.12),
    "boulon": _metal((0.62, 0.55, 0.42), rough=0.36, metallic=0.85, grain=0.1, dirt=0.3, dirt_distance=0.05),
    "laiton": _metal((0.74, 0.55, 0.27), rough=0.3, metallic=0.9, grain=0.18, grain_scale=60.0, rust=(0.25, 0.1, 0.04),
                     rust_amount=0.25, rust_scale=7.0, dirt=0.45),
    "laiton_tore": _metal((0.74, 0.55, 0.27), rough=0.38, metallic=0.9, grain=0.15, grain_scale=70.0,
                          rust=(0.3, 0.12, 0.05), rust_amount=0.2, dirt=0.4),
    "cuivre": _metal((0.62, 0.29, 0.13), rough=0.34, metallic=0.9, grain=0.2, grain_scale=50.0, rust=(0.18, 0.08, 0.03),
                     rust_amount=0.3, rust_scale=7.0, dirt=0.5),
    "cuivre_gaine": _metal((0.55, 0.25, 0.11), rough=0.4, metallic=0.85, grain=0.2, grain_scale=50.0,
                           rust=(0.16, 0.07, 0.03), rust_amount=0.3, rust_scale=6.0, dirt=0.6),
    "canon": _metal((0.06, 0.054, 0.048), rough=0.34, metallic=0.85, grain=0.25, rust=(0.2, 0.08, 0.03),
                    rust_amount=0.25, rust_scale=6.0, dirt=0.5),
    "noir": _metal((0.035, 0.032, 0.03), rough=0.6, metallic=0.3, grain=0.2, dirt=0.4),
    "caoutchouc": _metal((0.03, 0.028, 0.026), rough=0.9, metallic=0.0, grain=0.15, dirt=0.3),
    "jaune": _metal((0.62, 0.42, 0.04), rough=0.55, metallic=0.15, grain=0.35, rust=(0.16, 0.07, 0.025),
                    rust_amount=0.45, rust_scale=6.0, dirt=0.8),
    "peint": _metal((0.27, 0.15, 0.07), rough=0.5, metallic=0.2, grain=0.55, rust_amount=0.5, rust_scale=5.5,
                    dirt=0.85, dirt_distance=0.14),
    "ocre": _metal((0.38, 0.22, 0.06), rough=0.5, metallic=0.2, grain=0.5, rust_amount=0.5, rust_scale=5.5, dirt=0.85,
                   dirt_distance=0.14),
    "olive": _metal((0.13, 0.12, 0.055), rough=0.5, metallic=0.25, grain=0.55, rust_amount=0.45, rust_scale=5.5,
                    dirt=0.85, dirt_distance=0.14),
    "creme": _metal((0.44, 0.4, 0.29), rough=0.45, metallic=0.15, grain=0.45, rust=(0.16, 0.08, 0.03), rust_amount=0.4,
                    rust_scale=6.5, dirt=0.9, dirt_distance=0.16),
    "bois": _metal((0.22, 0.13, 0.065), rough=0.85, metallic=0.0, grain=0.45, dirt=0.7),
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
        # moins de taches de rouille fines : densité de pièces au plafond anti-bouillie (45) à l'essai 2
        m["tole"] = _metal((0.22, 0.17, 0.12), rough=0.38, metallic=0.55, grain=0.5, rust_amount=0.35, rust_scale=2.6,
                           dirt=0.85, dirt_distance=0.14)
        m["tole_r"] = _metal((0.2, 0.13, 0.085), rough=0.45, metallic=0.5, grain=0.5, rust_amount=0.5, rust_scale=3.0,
                             dirt=0.85, dirt_distance=0.14)
        m["peint"] = _metal((0.27, 0.15, 0.07), rough=0.5, metallic=0.2, grain=0.5, rust_amount=0.4, rust_scale=3.0,
                            dirt=0.85, dirt_distance=0.14)
        m["ocre"] = _metal((0.38, 0.22, 0.06), rough=0.5, metallic=0.2, grain=0.5, rust_amount=0.4, rust_scale=3.0,
                           dirt=0.85, dirt_distance=0.14)
        for k in list(m):
            if m[k][0] == "metal":
                m[k] = (m[k][0], dict(m[k][1], mottle=0.22))
    if e in (11, 15):
        # haute technologie massive : acier sombre chaud, accents peints patinés
        m["tole"] = _metal((0.2, 0.175, 0.14), rough=0.36, metallic=0.65, grain=0.55, rust_amount=0.35, rust_scale=5.0,
                           dirt=0.85, dirt_distance=0.14)
        m["tole_b"] = _metal((0.27, 0.24, 0.19), rough=0.34, metallic=0.65, grain=0.5, rust_amount=0.25,
                             rust_scale=5.5, dirt=0.85, dirt_distance=0.14)
        m["tole_sombre"] = _metal((0.085, 0.077, 0.066), rough=0.4, metallic=0.6, grain=0.55, rust_amount=0.3,
                                  rust_scale=5.0, dirt=0.85, dirt_distance=0.14)
        m["peint"] = m["olive"]
    if e == 11:
        m["alliage"] = m["creme"]                                     # alliage blanc patiné : accents
        m["ligne"] = _emit((0.72, 0.88, 1.0), 1.0)                    # lignes bleu-blanc (bible)
    if e == 15:
        m["alliage"] = m["creme"]
        m["or_blanc"] = _metal((0.55, 0.44, 0.24), rough=0.34, metallic=0.85, grain=0.25, rust=(0.2, 0.1, 0.04),
                               rust_amount=0.2, rust_scale=7.0, dirt=0.75)
        m["or_lum"] = _emit((1.0, 0.9, 0.62), 1.0, crust=(25.0, 0.25, 4.0))   # lumière blanche dorée (bible)
        m["ligne"] = _emit((1.0, 0.8, 0.42), 1.0)
    return finish(m)


# taches basse fréquence (blender_render.add_mottle) et reflets plus francs : le vanilla a des arêtes à reflet
# spéculaire franc (p95 de luminance 181) ; l'essai de 13 h 40 plafonnait à 114-133
NO_MOTTLE = ("boulon", "verre", "suie", "joint", "noir", "caoutchouc", "laiton_tore")
SHINY = ("tole", "tole_b", "tole_r", "tole_sombre", "acier", "acier_clair", "canon", "laiton", "laiton_tore", "cuivre",
         "cuivre_gaine", "boulon", "or_blanc")


def finish(m):
    out = {}
    for k, (kind, par) in m.items():
        p = dict(par)
        if kind == "metal":
            if k not in NO_MOTTLE:
                p.setdefault("mottle", 0.5)
                p.setdefault("mottle_scale", 7.0)
            if k in SHINY:
                p["rough"] = round(p["rough"] * 0.8, 3)
        out[k] = (kind, p)
    return out


# ------------------------------------------------------------------------------------------------
# Aides communes (reprises de l'essai de 8 h 50 quand elles tenaient)
# ------------------------------------------------------------------------------------------------
def race_ring(g, M, R, z, nb):
    """Chemin de roulement fixe au sommet du fût : bague laiton, couronne de boulons, joint sombre."""
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


def barbette(g, M, r0, r1, z0, z1, seams=12, rows=3, bands=("laiton_tore",), hatch_at=-math.pi / 2, ladder=False,
             rad_mult=3, slits=None, body="tole", seam_mat="tole_sombre"):
    """Fût conique riveté : tôle, couvre-joints verticaux rivetés, rangées de rivets, cerclages, trappe au sud,
    fentes lumineuses facultatives."""
    h = z1 - z0
    g.cyl(M[body], r0, h, (0, 0, z0 + h / 2), n=64, r2=r1, ch=0.015)
    tilt = math.atan2(r0 - r1, h)
    for i in range(seams):
        a = TAU * (i + 0.5) / seams
        rr = (r0 + r1) / 2 + 0.012
        g.push(); g.move((rr * math.cos(a), rr * math.sin(a), z0 + h / 2)); g.turn("z", a); g.turn("y", -tilt)
        g.box(M[seam_mat], (0.03, 0.08, h * 0.96), (0, 0, 0), 0.006)
        g.pop()
        if math.sin(a) > 0.6:
            continue
        for k in range(rows + 2):
            t = (k + 0.5) / (rows + 2)
            r = r0 + (r1 - r0) * t + 0.03
            K.rivet(g, M["boulon"], (r * math.cos(a), r * math.sin(a), z0 + h * t), (math.cos(a), math.sin(a), 0.3), 0.02)
    for k in range(rows):
        t = (k + 1) / (rows + 1)
        r = r0 + (r1 - r0) * t
        K.radial_rivets(g, M["boulon"], (0, 0), r + 0.004, z0 + h * t, int(seams * rad_mult), r=0.018, phase=0.13 * k)
    if slits:
        for i in range(seams):
            a = TAU * i / seams
            if math.sin(a) > 0.3:
                continue
            t = 0.55
            r = r0 + (r1 - r0) * t + 0.01
            g.push(); g.move((r * math.cos(a), r * math.sin(a), z0 + h * t)); g.turn("z", a); g.turn("y", -tilt)
            g.box(M["acier"], (0.03, 0.1, h * 0.3), (0, 0, 0), 0.006)
            g.box(slits, (0.034, 0.05, h * 0.22), (0.004, 0, 0), 0.0)
            g.pop()
            g.count("fente")
    for j, b in enumerate(bands):
        t = (j + 1) / (len(bands) + 1)
        g.torus(M[b], r0 + (r1 - r0) * t + 0.01, 0.03, (0, 0, z0 + h * t), n=72, m=8)
    if hatch_at is not None:
        a = hatch_at
        rr = r0 + (r1 - r0) * 0.45
        g.push(); g.move((rr * math.cos(a), rr * math.sin(a), z0 + h * 0.45)); g.turn("z", a); g.turn("y", -tilt)
        g.box(M["tole_sombre"], (0.04, 0.42, h * 0.55), (0.02, 0, 0), 0.01)
        g.box(M["acier"], (0.03, 0.04, h * 0.5), (0.05, 0.16, 0), 0.004)
        g.box(M["acier"], (0.03, 0.12, MIN_T + 0.01), (0.05, -0.08, 0.0), 0.004)
        for s in (-1, 1):
            for zz in (-1, 1):
                K.bolt(g, M["boulon"], (0.045, s * 0.17, zz * h * 0.22), (1, 0, 0), 0.016)
        g.pop()
    g.count("barbette")


def secondary_gun(g, M, c, scale=1.0, n=3, emit=None, yaw=0.0):
    """Tourelle secondaire : couronne, caisson riveté, canons rotatifs courts, viseur, bande de cartouches."""
    x, y, z = c
    s = scale
    g.push(); g.move((x, y, z)); g.turn("z", yaw)
    g.cyl(M["tole_sombre"], 0.3 * s, 0.08 * s, (0, 0, 0.04 * s), n=28, ch=0.01)
    K.bolts_ring(g, M["boulon"], (0, 0, 0.08 * s), 0.25 * s, 10, r=0.016)
    K.armor_box(g, M, (0.44 * s, 0.5 * s, 0.3 * s), (0, -0.04 * s, 0.24 * s), div_top=(1, 2), div_side=(1, 1),
                faces=("top", "s", "e", "w", "n"), t=0.03, seed=int(100 * abs(x) + 7))
    g.slab_x(M["tole"], [(0.2 * s, 0.1 * s), (0.3 * s, 0.14 * s), (0.3 * s, 0.34 * s), (0.2 * s, 0.4 * s)], -0.2 * s, 0.2 * s)
    K.gatling(g, M, n, 0.05 * s, 0.026 * s, 0.28 * s, 0.85 * s, x=0.0, z=0.25 * s, rings=(0.1, 0.7), muzzle=True)
    K.sensor(g, M, (0.13 * s, -0.12 * s, 0.39 * s), 0.13 * s, 0.13 * s, 0.09 * s, lens_emit=emit)
    g.cyl(M["olive"] if "olive" in M else M["tole"], 0.11 * s, 0.16 * s, (-0.3 * s, -0.08 * s, 0.24 * s), axis="x", n=20,
          ch=0.01)
    K.ammo_belt(g, M["laiton"], M["noir"], [(-0.3 * s, 0.02 * s, 0.34 * s), (-0.22 * s, 0.12 * s, 0.38 * s),
                                            (-0.1 * s, 0.2 * s, 0.33 * s)], pitch=0.045, length=0.06, r=0.014)
    g.pop()
    g.count("tourelle_secondaire")


def pedestal(g, M, c, w, d, h, seed=0, emit=None):
    """Piédestal blindé (tourelle secondaire, lance-roquettes) : caisson à plaques, glacis sud, échelle, voyant."""
    cx, cy, cz = c
    K.armor_box(g, M, (w, d, h), (cx, cy, cz + h / 2), div_top=(2, 2), div_side=(2, 1), faces=("top", "s", "e", "w"),
                seed=seed, plate_mat=[M["tole"], M["peint"], M["tole_b"], M["tole_r"]])
    g.slab_x(M["tole_sombre"], [(cy - d / 2 - 0.14, cz), (cy - d / 2, cz), (cy - d / 2, cz + h * 0.55)],
             cx - w / 2 + 0.05, cx + w / 2 - 0.05)
    K.hazard_band(g, M["jaune"], M["noir"], (cx - w / 2 + 0.06, cy - d / 2 - 0.02, cz + h * 0.78),
                  (cx + w / 2 - 0.06, cy - d / 2 - 0.02, cz + h * 0.78), 0.07, 0.012, stripe=0.08, n_up=(0, -1, 0))
    if emit:
        K.lamp(g, M[emit], M["acier"], (cx + w / 2 - 0.1, cy - d / 2 - 0.02, cz + h * 0.4), (0, -1, 0), 0.04)
        K.light_strip(g, M[emit], M["acier"], (cx - w / 2 + 0.12, cy - d / 2 - 0.03, cz + h * 0.45),
                      (cx + w / 2 - 0.25, cy - d / 2 - 0.03, cz + h * 0.45), 0.05, n=(0, -1, 0), cells=3)
    g.count("piedestal")


def steps(g, M, x0, x1, y0, z_top, n, depth=0.14):
    """Escalier vers le fût (repère humain) : marches en tôle larmée, limons."""
    for i in range(n):
        z = z_top * (i + 1) / n
        y = y0 + i * depth
        g.box(M["acier"], (x1 - x0, depth + 0.02, 0.04), ((x0 + x1) / 2, y + depth / 2, z - 0.02), 0.006)
        g.box(M["tole_sombre"], (x1 - x0 - 0.04, 0.03, z - 0.04), ((x0 + x1) / 2, y + 0.015, (z - 0.04) / 2), 0.004)
    for x in (x0, x1):
        g.slab_x(M["tole"], [(y0, 0.0), (y0 + n * depth, 0.0), (y0 + n * depth, z_top), (y0, 0.05)], x - 0.02, x + 0.02)
    K.handrail(g, M["acier_clair"], [(x0, y0 + 0.05, 0.08), (x0, y0 + n * depth, z_top)], h=0.2, post_every=0.25)
    K.handrail(g, M["acier_clair"], [(x1, y0 + 0.05, 0.08), (x1, y0 + n * depth, z_top)], h=0.2, post_every=0.25)
    g.count("escalier")


def apron(g, M, x0, x1, y0, y1, z=0.0, hazard=True):
    """Tablier bas devant le fût : tôle larmée, bordure, bande de danger au bord sud."""
    g.box(M["tole_sombre"], (x1 - x0, y1 - y0, 0.06), ((x0 + x1) / 2, (y0 + y1) / 2, z + 0.03), 0.01)
    K.tread_plate(g, M["acier"], (x0 + 0.04, x1 - 0.04), (y0 + 0.12, y1 - 0.04), z + 0.06, pitch=0.15)
    if hazard:
        K.hazard_band(g, M["jaune"], M["noir"], (x0 + 0.02, y0 + 0.05, z + 0.06), (x1 - 0.02, y0 + 0.05, z + 0.06), 0.09,
                      0.012, stripe=0.1)
    g.count("tablier")


# ================================================================================================
# NIVEAU 11 (époque 6 « Électricité », ère II) : 3×3 ; X ±1,5 ; Y ±2,12
# ================================================================================================
def socle_11(g, M, piece=False):
    deck = LEVELS[11]["deck"]
    # semelles d'angle (dépassent du contour)
    for sx in (-1, 1):
        for sy in (-1, 1):
            PT.foot(g, M, (sx * 1.28, sy * 1.86, 0.0), 0.36, 0.44, 0.1)
    # fût riveté conique, bande de danger au pied
    barbette(g, M, 1.02, 0.9, 0.0, deck - 0.02, seams=14, rows=2, rad_mult=2.4, bands=("laiton_tore",))
    g.cyl(M["noir"], 1.03, 0.09, (0, 0, 0.08), n=72)
    k = 30
    for i in range(0, k, 2):
        a0, a1 = TAU * i / k, TAU * (i + 1) / k
        if math.sin(a0) > 0.5:
            continue
        g.prism(M["jaune"], [(1.03 * math.cos(a0), 1.03 * math.sin(a0)), (1.03 * math.cos(a1), 1.03 * math.sin(a1)),
                             (1.06 * math.cos(a1), 1.06 * math.sin(a1)), (1.06 * math.cos(a0), 1.06 * math.sin(a0))],
                0.04, 0.12)
    g.cyl(M["acier"], 0.95, 0.05, (0, 0, deck - 0.02), n=64, ch=0.01)
    race_ring(g, M, 0.86, deck, 28)
    # arrière : réservoir d'eau couché sur berceaux (refroidissement des manchons)
    PT.tank_h(g, M, (-0.32, 1.5, 0.42), 0.36, 1.75, axis="x", body="tole", n_bands=3, saddles=2, rivet_rows=5,
              gauge_side=(0.2, 1.13, 0.5))
    # angle nord-est : chaudière (foyer et gueule de braise) et cheminée (ancre de style V0)
    K.armor_box(g, M, (0.56, 0.62, 0.5), (1.12, 1.55, 0.25), div_top=(1, 1), div_side=(2, 1), faces=("top", "s", "e", "w"),
                seed=3, plate_mat=[M["tole_r"], M["tole"]])
    K.slit_light(g, M["ambre"], M["acier"], (1.12, 1.22, 0.2), 0.26, 0.07, (0, -1, 0), bars=3)
    g.light((1.12, 1.1, 0.22), (1.0, 0.45, 0.08), 3.0)
    K.hatch(g, M["tole_sombre"], M["acier"], M["boulon"], (0.3, 0.14, 0.03), (1.12, 1.23, 0.38), n=(0, -1, 0))
    PT.chimney(g, M, (1.17, 1.66, 0.5), 0.13, 0.82, ember="ambre", rings=3)
    K.pipe(g, M["cuivre"], M["laiton"], M["boulon"], [(0.84, 1.55, 0.36), (0.6, 1.5, 0.42), (0.5, 1.5, 0.42)], 0.045)
    # flanc ouest : dynamo à bobine et 2 piles d'isolateurs avec éclateur (identité époque 6)
    g.box(M["tole_sombre"], (0.46, 0.96, 0.1), (-1.24, 0.3, 0.05), 0.014)
    K.coil(g, M["cuivre"], M["acier"], (-1.24, 0.3, 0.33), 0.21, 0.6, axis="y", turns=9, wire=0.03, flange=M["tole_sombre"])
    for s in (-1, 1):
        g.cyl(M["tole_sombre"], 0.23, 0.12, (-1.24, 0.3 + s * 0.38, 0.33), axis="y", n=28, ch=0.015)
        g.slab(M["tole"], [(-1.44, 0.1), (-1.04, 0.1), (-1.1, 0.2), (-1.38, 0.2)], 0.3 + s * 0.38 - 0.05, 0.3 + s * 0.38 + 0.05)
    K.bolts_ring(g, M["boulon"], (-1.24, -0.15, 0.33), 0.17, 8, axis="-y", r=0.014)
    for i, yy in enumerate((-0.42, -0.95)):
        top = K.insulator_stack(g, M["porcelaine"], M["laiton"], (-1.22, yy, 0.0), 5 + i, 0.085, 0.055, 0.05,
                                base_mat=M["acier"])
        g.cyl(M["cuivre"], 0.014, 0.18, (-1.22, yy + 0.12 if i == 0 else yy + 0.1, top - 0.02), axis="y", n=8)
    g.box(M["arc"], (0.05, 0.12, 0.06), (-1.22, -0.68, 0.48), 0.0)
    g.light((-1.22, -0.68, 0.5), (0.4, 0.8, 1.0), 3.0)
    K.cable(g, M["cable_r"], [(-1.22, -0.3, 0.42), (-1.05, -0.1, 0.5), (-0.92, 0.1, 0.45)], 0.022, ties=M["acier"])
    # flanc est : pompe, vanne, petit réservoir debout, manomètre
    PT.tank_v(g, M, (1.25, 0.25, 0.0), 0.22, 0.62, body="tole_r", n_bands=2, seams=8, ladder=False)
    PT.valve(g, M, (1.16, -0.25, 0.14), axis="y", r=0.06)
    PT.gauge(g, M, (1.25, 0.02, 0.4), (0, -1, 0), 0.05)
    K.pipe(g, M["cuivre"], M["laiton"], M["boulon"], [(1.18, -0.3, 0.14), (1.0, -0.42, 0.14), (0.95, -0.42, 0.3)], 0.035)
    # avant : caisses de munitions (sud-ouest), coffres et convoyeur (sud-est), tablier et marches au centre
    K.crate(g, M, (0.46, 0.4, 0.3), (-1.0, -1.62, 0.0), seed=1, stencil="jaune")
    K.crate(g, M, (0.42, 0.36, 0.26), (-1.18, -1.2, 0.0), seed=2, stencil="jaune")
    K.crate(g, M, (0.36, 0.32, 0.22), (-1.02, -1.6, 0.3), seed=3, stencil=None)
    PT.ammo_box(g, M, (0.42, 0.34, 0.3), (1.0, -1.62, 0.0), body="ocre")
    PT.ammo_box(g, M, (0.36, 0.3, 0.26), (1.16, -1.18, 0.0), body="ocre")
    K.ammo_belt(g, M["laiton"], M["noir"], [(1.0, -1.45, 0.32), (0.86, -1.12, 0.36), (0.72, -0.9, 0.5)], pitch=0.05)
    apron(g, M, -0.45, 0.45, -2.08, -1.38, 0.0)
    steps(g, M, -0.26, 0.26, -1.42, 0.5, 4, 0.12)
    K.lamp(g, M["ambre"], M["acier"], (-0.5, -2.02, 0.1), (0, -1, 0.3), 0.04)
    K.lamp(g, M["ambre"], M["acier"], (0.5, -2.02, 0.1), (0, -1, 0.3), 0.04)
    # gaines annelées : réservoir -> fût, chaudière -> fût (passent par-dessus)
    PT.hose(g, M["cuivre_gaine"], M["cuivre"], [(-0.95, 1.2, 0.55), (-1.05, 0.95, 0.85), (-0.82, 0.7, 0.62)], r=0.05,
            collar=M["laiton"], bolt_mat=M["boulon"])
    PT.hose(g, M["cuivre_gaine"], M["cuivre"], [(0.3, 1.25, 0.6), (0.55, 1.0, 0.85), (0.72, 0.62, 0.6)], r=0.045,
            collar=M["laiton"], bolt_mat=M["boulon"])
    return g


def head_11(g, M):
    """Mitrailleuse électrique lourde : couronne tournante, fût court riveté, flasques blindées, 2 × 4 canons
    rotatifs à manchons à eau, moteur bobiné arrière, piles d'isolateurs dorsales et éclateur, tambour de
    munitions, réservoir d'eau. z = 0 au pied de la tête (sommet du fût du socle)."""
    deck = LEVELS[11]["deck"]
    g.push(); g.move((0, 0, deck))
    z = turntable(g, M, 0.84, 0.0, 44)
    zb = 0.34
    barbette(g, M, 0.72, 0.62, z, zb, seams=10, rows=1, rad_mult=2, hatch_at=None)
    g.cyl(M["tole_sombre"], 0.68, 0.06, (0, 0, zb + 0.03), n=48, ch=0.01)
    g.torus(M["laiton_tore"], 0.64, 0.03, (0, 0, zb + 0.065), n=56, m=8)
    g.push()
    g.scale_about((0, 0, zb), HEAD_SCALE[11])
    za = zb + 0.6
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
        g.push(); g.move((xo + sx * 0.02, -0.12, zb + 0.3))
        g.box(M["ocre"], (0.03, 0.5, 0.24), (0, 0, 0), 0.008)
        for yy in (-0.2, 0.2):
            for zz in (-0.08, 0.08):
                K.bolt(g, M["boulon"], (sx * 0.016, yy, zz), (sx, 0, 0), 0.018)
        g.pop()
    # culasse ronde (cylindre couché entre les flasques) et caisson
    g.cyl(M["tole_r"], 0.3, 1.0, (0, -0.15, za), axis="x", n=40, ch=0.02)
    for xx in (-0.3, 0.0, 0.3):
        g.torus(M["laiton_tore"], 0.305, 0.02, (xx, -0.15, za), axis="x", n=48, m=6)
    K.armor_box(g, M, (0.98, 0.62, 0.32), (0, -0.05, za + 0.2), div_top=(2, 2), div_side=(2, 1),
                faces=("top", "s", "n"), seed=11, plate_mat=[M["ocre"], M["tole_r"], M["peint"], M["tole"]])
    # masque frontal incliné
    g.slab_x(M["tole_sombre"], [(0.36, za - 0.32), (0.52, za - 0.28), (0.56, za + 0.28), (0.34, za + 0.38)], -0.6, 0.6)
    K.bolts_line(g, M["boulon"], (-0.5, 0.45, za + 0.33), (0.5, 0.45, za + 0.33), 8, n=(0, 0.5, 1), r=0.02)
    K.bolts_line(g, M["boulon"], (-0.5, 0.54, za - 0.25), (0.5, 0.54, za - 0.25), 8, n=(0, 1, -0.2), r=0.02)
    for sx in (-1, 1):
        x = sx * 0.27
        g.cyl(M["acier"], 0.17, 0.12, (x, 0.58, za), axis="y", n=28, ch=0.015)
        K.bolts_ring(g, M["boulon"], (x, 0.64, za), 0.14, 8, axis="y", r=0.014)
        K.gatling(g, M, 4, 0.07, 0.034, 0.6, 1.45, x=x, z=za, phase=math.pi / 4, rings=(0.55, 0.96),
                  jacket=(0.62, 1.08, 0.125))
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
    ztop = za + 0.36
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
    g.cyl(M["ocre"], 0.34, 0.26, (xd, -0.1, za - 0.05), axis="x", n=40, ch=0.02)
    for xx in (xd - 0.08, xd + 0.08):
        g.torus(M["laiton_tore"], 0.345, 0.022, (xx, -0.1, za - 0.05), axis="x", n=48, m=6)
    K.bolts_ring(g, M["boulon"], (xd - 0.13, -0.1, za - 0.05), 0.26, 10, axis="-x", r=0.018)
    g.cyl(M["acier"], 0.09, 0.05, (xd - 0.15, -0.1, za - 0.05), axis="x", n=16, ch=0.01)
    K.ammo_belt(g, M["laiton"], M["noir"], [(xd + 0.02, 0.05, za + 0.27), (-0.6, 0.12, za + 0.4),
                                            (-0.4, 0.15, za + 0.4)], pitch=0.05)
    # réservoir d'eau des manchons (droite) et tuyaux de cuivre
    xt = 0.8
    g.cyl(M["tole"], 0.15, 0.62, (xt, -0.18, za + 0.12), axis="y", n=28, ch=0.015)
    K.slit_light(g, M["ambre"], M["laiton"], (xt + 0.15, -0.2, za + 0.12), 0.32, 0.05, (1, 0, 0), bars=1)
    for yy in (-0.4, -0.18, 0.04):
        g.torus(M["laiton_tore"], 0.155, 0.018, (xt, yy, za + 0.12), axis="y", n=32, m=6)
    K.pipe(g, M["cuivre"], M["laiton"], None, [(xt, 0.13, za + 0.12), (xt - 0.1, 0.55, za + 0.12),
                                               (0.42, 0.72, za + 0.12)], 0.03)
    K.pipe(g, M["cuivre"], M["laiton"], None, [(xt - 0.05, -0.5, za + 0.2), (0.62, -0.62, za + 0.3),
                                               (0.3, -0.62, za + 0.34)], 0.026)
    K.sensor(g, M, (0.2, 0.18, za + 0.36), 0.24, 0.2, 0.14, lens_emit=M["ambre"])
    K.lamp(g, M["ambre"], M["acier"], (-0.3, -0.53, za + 0.2), (0, -1, 0), 0.055)
    K.lamp(g, M["ambre"], M["acier"], (0.3, -0.53, za + 0.2), (0, -1, 0), 0.055)
    K.slit_light(g, M["ambre"], M["acier"], (0, -1.125, za + 0.13), 0.16, 0.05, (0, -1, 0), bars=1)
    for sx in (-1, 1):
        K.slit_light(g, M["arc"], M["acier"], (sx * 0.655, -0.05, za + 0.24), 0.14, 0.045, (sx, 0, 0), bars=0)
    g.light((0, -0.6, za + 0.2), (1.0, 0.45, 0.06), 4.0)
    K.handrail(g, M["acier_clair"], [(-0.47, -0.52, za + 0.36), (-0.47, 0.34, za + 0.36)], h=0.14, post_every=0.28)
    K.handrail(g, M["acier_clair"], [(0.47, -0.52, za + 0.36), (0.47, 0.34, za + 0.36)], h=0.14, post_every=0.28)
    g.pop()
    g.pop()
    return g


# ================================================================================================
# NIVEAU 21 (époque 11 « Titane », ère IV) : 5×5 ; X ±2,5 ; Y ±3,54
# ================================================================================================
def socle_21(g, M, piece=False):
    deck = LEVELS[21]["deck"]
    for sx in (-1, 1):
        for sy in (-1, 1):
            PT.foot(g, M, (sx * 2.2, sy * 3.18, 0.0), 0.5, 0.6, 0.12)
    # couronne de soubassement à contreforts et fût supérieur
    PT.ring_drum(g, M, 1.92, 0.0, 0.46, n_butt=16, butt_out=0.26, emit="ligne", seed=1, r_in=1.6)
    PT.glow_cells_ring(g, M, "ligne", 1.93, 0.36, 14)

    barbette(g, M, 1.6, 1.44, 0.44, deck - 0.02, seams=18, rows=2, rad_mult=2.6, bands=("laiton_tore",),
             slits=M["ligne"], body="tole")
    g.cyl(M["acier"], 1.5, 0.05, (0, 0, deck - 0.02), n=72, ch=0.01)
    race_ring(g, M, 1.4, deck, 40)
    # arrière : générateur couché (fonds crème patinés), échappements, gaines vers le fût
    PT.generator(g, M, (-0.1, 2.72, 0.56), 0.5, 2.2, axis="x", cap="creme", fins=13)
    for sx in (-1, 1):
        K.exhaust(g, M, (sx * 0.95 - 0.1, 3.22, 0.0), 0.09, 1.0)
    PT.hose(g, M["cuivre_gaine"], M["cuivre"], [(-0.8, 2.3, 0.85), (-1.05, 1.95, 1.3), (-0.95, 1.5, 1.05)], r=0.065,
            collar=M["laiton"], bolt_mat=M["boulon"])
    PT.hose(g, M["cuivre_gaine"], M["cuivre"], [(0.55, 2.3, 0.85), (0.85, 1.95, 1.35), (0.9, 1.45, 1.05)], r=0.065,
            collar=M["laiton"], bolt_mat=M["boulon"])
    # angle nord-ouest : batterie de condensateurs ; nord-est : radiateur
    PT.capacitors(g, M, (-2.0, 2.55, 0.0), 2, 3, r=0.11, h=0.5, pitch=0.27, emit=M["ligne"])
    PT.radiator(g, M, (1.98, 2.55, 0.0), 0.8, 0.95, 0.55, n_fins=13, axis="x")
    K.pipe(g, M["cuivre"], M["laiton"], M["boulon"], [(1.6, 2.3, 0.45), (1.4, 2.0, 0.45), (1.25, 1.55, 0.35)], 0.05,
           clamp_every=0.3)
    # flanc ouest : réservoir de liquide de refroidissement debout ; flanc est : transformateur et vannes
    PT.tank_v(g, M, (-2.12, 0.55, 0.0), 0.3, 0.95, body="tole", n_bands=3, seams=10)
    PT.valve(g, M, (-2.12, -0.05, 0.12), axis="y", r=0.07)
    PT.hose(g, M["cuivre_gaine"], M["cuivre"], [(-2.1, 0.3, 0.75), (-1.95, 0.0, 0.95), (-1.62, -0.1, 0.72)], r=0.05,
            collar=M["laiton"], bolt_mat=M["boulon"])
    K.armor_box(g, M, (0.52, 0.9, 0.58), (2.1, 0.45, 0.29), div_top=(1, 2), div_side=(2, 1), faces=("top", "s", "e", "w"),
                seed=5, plate_mat=[M["olive"], M["tole"], M["olive"], M["tole_b"]])
    for i in range(3):
        K.insulator_stack(g, M["porcelaine"], M["laiton"], (2.1, 0.2 + i * 0.25, 0.58), 3, 0.06, 0.04, 0.04)
    K.grille(g, M["acier"], M["tole_sombre"], 0.4, 0.3, (2.1, -0.01, 0.3), normal=(0, -1, 0), deep_mat=M["joint"])
    K.lamp(g, M["ligne"], M["acier"], (2.28, -0.01, 0.48), (0, -1, 0), 0.04)
    PT.valve(g, M, (2.05, -0.45, 0.12), axis="x", r=0.06)
    # angle sud-ouest : tourelle secondaire sur piédestal
    pedestal(g, M, (-1.85, -2.5, 0.0), 0.9, 0.95, 0.5, seed=7, emit="ligne")
    secondary_gun(g, M, (-1.85, -2.45, 0.5), 1.25, n=3, emit=M["ligne"], yaw=0.35)
    # angle sud-est : magasin de munitions (coffres peints) et convoyeur vers le fût
    PT.ammo_box(g, M, (0.62, 0.5, 0.42), (1.82, -2.75, 0.0), body="olive")
    PT.ammo_box(g, M, (0.56, 0.46, 0.38), (2.0, -2.15, 0.0), body="olive")
    PT.ammo_box(g, M, (0.5, 0.42, 0.32), (1.75, -2.72, 0.42), body="creme")
    g.box(M["acier"], (0.24, 0.9, 0.06), (1.45, -1.75, 0.38), 0.008)
    for i in range(5):
        g.cyl(M["acier_clair"], 0.035, 0.26, (1.45, -2.1 + i * 0.18, 0.42), axis="x", n=10)
    K.ammo_belt(g, M["laiton"], M["noir"], [(1.8, -2.4, 0.5), (1.45, -1.9, 0.47), (1.3, -1.45, 0.6)], pitch=0.05)
    # avant : tablier, escalier, voyants
    apron(g, M, -0.6, 0.6, -3.4, -2.2, 0.0)
    K.crate(g, M, (0.46, 0.4, 0.3), (-0.95, -3.1, 0.0), seed=41, stencil="jaune")
    K.crate(g, M, (0.42, 0.36, 0.26), (0.92, -3.15, 0.0), seed=42, stencil="jaune")
    steps(g, M, -0.35, 0.35, -2.2, 0.9, 6, 0.13)
    for x in (-0.8, 0.8):
        K.lamp(g, M["ambre"], M["acier"], (x, -3.38, 0.1), (0, -1, 0.3), 0.045)
    g.light((0, -2.5, 0.4), (0.75, 0.88, 1.0), 4.0)
    K.cable_bundle(g, [M["cable_r"], M["noir"], M["cable_r"]], [(-1.75, 2.15, 0.55), (-1.5, 1.6, 0.6), (-1.3, 1.1, 0.75)],
                   spread=0.05, r=0.022, ties=M["acier"])
    return g


def _inset(poly, d):
    """Polygone convexe rentré de d vers son centre (pans inclinés d'une coque)."""
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    out = []
    for x, y in poly:
        dx, dy = x - cx, y - cy
        L = math.hypot(dx, dy)
        out.append((x - d * dx / L, y - d * dy / L))
    return out


def head_21(g, M):
    """Tourelle lourde de haute technologie, en COQUE blindée (tourelle de char, pas un cadre ouvert) : couronne,
    fût court, coque à pans inclinés plaqués et boulonnés (accents crème patinés), masque cylindrique portant
    2 × 6 canons rotatifs lourds à manchons, tambours de munitions latéraux et bandes, nuque arrière (groupe
    moteur, grilles, bobine), ailerons blindés (Titane) à ligne lumineuse, coupole et viseur."""
    deck = LEVELS[21]["deck"]
    g.push(); g.move((0, 0, deck))
    z = turntable(g, M, 1.32, 0.0, 64)
    zb = 0.3
    barbette(g, M, 1.18, 1.08, z, zb, seams=16, rows=1, rad_mult=2.5, hatch_at=None)
    g.push()
    g.scale_about((0, 0, zb), HEAD_SCALE[21])
    zh = zb + 0.72
    h0 = [(-0.92, -1.3), (0.92, -1.3), (1.12, -0.85), (1.12, 0.4), (0.8, 0.85), (-0.8, 0.85), (-1.12, 0.4), (-1.12, -0.85)]
    h1 = [(-0.72, -1.1), (0.72, -1.1), (0.88, -0.74), (0.88, 0.24), (0.58, 0.6), (-0.58, 0.6), (-0.88, 0.24), (-0.88, -0.74)]
    PT.loft(g, M["tole_sombre"], h0, zb, h1, zh)
    PT.plate_loft(g, M, h0, zb, h1, zh, [M["tole"], M["olive"], M["tole_b"], M["alliage"], M["tole_r"], M["tole_sombre"], M["olive"]], rows=2,
                  col_len=0.4, emit=M["ligne"], emit_every=2, seed=21, top_div=0.52)
    za = zb + 0.36
    # masque et canons
    g.cyl(M["tole"], 0.36, 1.25, (0, 0.74, za), axis="x", n=44, ch=0.02)
    for xx in (-0.55, 0.0, 0.55):
        g.torus(M["laiton_tore"], 0.362, 0.02, (xx, 0.74, za), axis="x", n=48, m=6)
    for k in range(3):
        a = 0.35 + k * 0.5
        K.bolts_line(g, M["boulon"], (-0.56, 0.74 + 0.37 * math.cos(a), za + 0.37 * math.sin(a)),
                     (0.56, 0.74 + 0.37 * math.cos(a), za + 0.37 * math.sin(a)), 9, n=(0, math.cos(a), math.sin(a)),
                     r=0.016, kind="rivet")
    for sx in (-1, 1):
        x = sx * 0.34
        g.cyl(M["acier"], 0.24, 0.2, (x, 1.04, za), axis="y", n=36, ch=0.02)
        K.bolts_ring(g, M["boulon"], (x, 1.14, za), 0.19, 10, axis="y", r=0.016)
        K.gatling(g, M, 6, 0.1, 0.04, 1.08, 2.5, x=x, z=za, phase=0.0, rings=(0.4, 0.97), jacket=(1.1, 1.75, 0.18),
                  vent=M["ambre"])
        K.pipe(g, M["cuivre"], M["laiton"], None, [(x + sx * 0.12, 0.62, zh + 0.02), (x + sx * 0.2, 1.1, za + 0.22),
                                                   (x + sx * 0.18, 1.25, za + 0.2)], 0.028)
    # tambours de munitions latéraux et bandes vers le toit
    for sx in (-1, 1):
        xd = sx * 1.3
        g.cyl(M["olive"], 0.36, 0.36, (xd, -0.3, za - 0.02), axis="x", n=44, ch=0.025)
        for xx in (xd - 0.11, xd + 0.11):
            g.torus(M["laiton_tore"], 0.365, 0.022, (xx, -0.3, za - 0.02), axis="x", n=52, m=6)
        K.bolts_ring(g, M["boulon"], (xd + sx * 0.18, -0.3, za - 0.02), 0.28, 12, axis=(sx, 0, 0), r=0.016)
        g.cyl(M["acier"], 0.1, 0.06, (xd + sx * 0.2, -0.3, za - 0.02), axis="x", n=16, ch=0.01)
        g.box(M["jaune"], (0.006, 0.24, 0.07), (xd + sx * 0.185, -0.3, za + 0.16), 0.0)
        g.box(M["tole_sombre"], (0.3, 0.3, 0.12), (sx * 1.08, -0.3, za - 0.3), 0.012)
        K.ammo_belt(g, M["laiton"], M["noir"], [(xd - sx * 0.05, -0.1, za + 0.32), (sx * 0.98, 0.05, zh + 0.04),
                                                (sx * 0.6, 0.15, zh + 0.05)], pitch=0.05)
    # nuque arrière : groupe moteur
    K.armor_box(g, M, (1.5, 0.5, 0.52), (0, -1.5, zb + 0.28), div_top=(3, 1), div_side=(3, 1), faces=("top", "s", "e", "w"),
                seed=23, plate_mat=[M["olive"], M["tole"], M["tole_b"]])
    for sx in (-1, 1):
        K.grille(g, M["acier"], M["tole_sombre"], 0.4, 0.26, (sx * 0.4, -1.76, zb + 0.28), normal=(0, -1, 0),
                 deep_mat=M["joint"])
        K.lamp(g, M["ambre"], M["acier"], (sx * 0.66, -1.76, zb + 0.12), (0, -1, 0), 0.04)
        K.exhaust(g, M, (sx * 0.55, -1.42, zb + 0.54), 0.06, 0.16)
    K.coil(g, M["cuivre"], M["acier"], (0, -1.55, zb + 0.66), 0.13, 0.62, axis="x", turns=9, wire=0.022,
           flange=M["tole_sombre"])
    for x in (-0.2, 0.2):
        K.slit_light(g, M["ligne"], M["acier"], (x, -1.76, zb + 0.44), 0.1, 0.16, (0, -1, 0), bars=1)
    g.light((0, -1.9, zb + 0.4), (0.75, 0.88, 1.0), 5.0)
    # ailerons blindés (Titane)
    for sx in (-1, 1):
        x = sx * 0.5
        fin = [(-0.95, zh), (-1.72, zb + 0.56), (-1.2, zh + 0.55)]
        g.slab_x(M["alliage"], fin, x - 0.035, x + 0.035)
        K.bolts_line(g, M["boulon"], (x + sx * 0.036, -1.6, zb + 0.62), (x + sx * 0.036, -1.15, zh + 0.45), 5,
                     n=(sx, 0, 0), r=0.015)
        K.light_strip(g, M["ligne"], M["acier"], (x + sx * 0.04, -0.98, zh + 0.04), (x + sx * 0.04, -1.16, zh + 0.48),
                      0.034, n=(sx, 0, 0), cells=2)
    # toit : grilles moteur, anneaux de levage, coupole, viseur, trappe, câbles
    for sx in (-1, 1):
        K.grille(g, M["acier"], M["tole_sombre"], 0.42, 0.3, (sx * 0.4, -0.85, zh + 0.035), normal=(0, 0, 1),
                 deep_mat=M["joint"])
        g.torus(M["acier_clair"], 0.045, 0.012, (sx * 0.62, 0.35, zh + 0.07), axis="x", n=14, m=4)
        g.box(M["acier"], (0.06, 0.08, 0.04), (sx * 0.62, 0.35, zh + 0.05), 0.006)
    g.cyl(M["tole"], 0.24, 0.16, (-0.32, -0.45, zh + 0.11), n=32, ch=0.015)
    K.bolts_ring(g, M["boulon"], (-0.32, -0.45, zh + 0.19), 0.19, 10, r=0.014)
    for a in (0.0, 2.1, 4.2):
        g.box(M["verre"], (0.07, 0.03, 0.04), (-0.32 + 0.24 * math.sin(a), -0.45 - 0.24 * math.cos(a), zh + 0.13), 0.0)
    K.sensor(g, M, (0.35, 0.05, zh + 0.03), 0.3, 0.24, 0.17, lens_emit=M["ligne"])
    K.hatch(g, M["tole_b"], M["acier"], M["boulon"], (0.3, 0.28, 0.03), (0.35, -0.6, zh + 0.03))
    K.cable_bundle(g, [M["cable_r"], M["noir"], M["cable_r"]], [(-0.6, -1.3, zb + 0.55), (-0.5, -0.9, zh + 0.05),
                                                                (-0.1, -0.2, zh + 0.06)], spread=0.05, r=0.02,
                   ties=M["acier"])
    g.pop()
    g.pop()
    return g


# ================================================================================================
# NIVEAU 29 (époque 15 « Légende », ère V) : 6×6 ; X ±3 ; Y ±4,24 ; NIVEAU 30 : + lance-roquettes avant
# ================================================================================================
def socle_29(g, M, piece=False):
    deck = LEVELS[29]["deck"]
    for sx in (-1, 1):
        for sy in (-1, 1):
            PT.foot(g, M, (sx * 2.66, sy * 3.88, 0.0), 0.56, 0.66, 0.13)
    PT.ring_drum(g, M, 2.35, 0.0, 0.5, n_butt=20, butt_out=0.28, emit="ligne", seed=2, r_in=1.98)
    PT.ring_drum(g, M, 1.98, 0.48, 0.92, n_butt=16, butt_out=0.18, emit="or_lum", seed=4, hazard=False, body="tole", r_in=1.72)
    PT.glow_cells_ring(g, M, "ligne", 2.36, 0.38, 16)
    PT.glow_cells_ring(g, M, "or_lum", 1.99, 0.74, 13)

    barbette(g, M, 1.72, 1.6, 0.9, deck - 0.02, seams=20, rows=2, rad_mult=2.6, bands=("laiton_tore",),
             slits=M["or_lum"], body="tole_sombre", seam_mat="tole")
    # plaques multiples sur le fût supérieur (briques additionnelles)
    for i in range(14):
        a = TAU * (i + 0.25) / 14
        if math.sin(a) > 0.4:
            continue
        r = 1.69
        g.push(); g.move((r * math.cos(a), r * math.sin(a), 1.12)); g.turn("z", a); g.turn("y", -0.12)
        g.box(M["alliage"] if i % 3 == 0 else M["tole"], (0.05, 0.42, 0.26), (0.02, 0, 0), 0.012)
        for dy in (-0.15, 0.15):
            for dz in (-0.08, 0.08):
                K.bolt(g, M["boulon"], (0.046, dy, dz), (1, 0, 0), 0.015)
        g.pop()
    g.cyl(M["acier"], 1.66, 0.05, (0, 0, deck - 0.02), n=72, ch=0.01)
    race_ring(g, M, 1.56, deck, 48)
    # arrière : générateur, deux tours de cellules (réserve d'énergie visible), échappements
    PT.generator(g, M, (0.0, 3.3, 0.62), 0.55, 2.4, axis="x", cap="creme", fins=15)
    for sx in (-1, 1):
        PT.cell_tower(g, M, (sx * 2.3, 3.2, 0.0), 0.72, 0.72, 5, cell_h=0.24, emit="or_lum", cap="or_blanc")
        g.light((sx * 2.3, 2.7, 0.7), (1.0, 0.9, 0.65), 6.0)
        PT.hose(g, M["cuivre_gaine"], M["cuivre"], [(sx * 1.95, 2.85, 1.05), (sx * 1.75, 2.35, 1.55), (sx * 1.25, 1.9, 1.3)],
                r=0.07, collar=M["laiton"], bolt_mat=M["boulon"])
        K.exhaust(g, M, (sx * 1.35, 3.9, 0.0), 0.1, 1.25)
    PT.hose(g, M["cuivre_gaine"], M["cuivre"], [(-0.55, 2.82, 0.95), (-0.35, 2.4, 1.6), (-0.25, 1.85, 1.38)], r=0.075,
            collar=M["laiton"], bolt_mat=M["boulon"])
    PT.hose(g, M["cuivre_gaine"], M["cuivre"], [(0.6, 2.82, 0.95), (0.45, 2.4, 1.62), (0.35, 1.85, 1.38)], r=0.075,
            collar=M["laiton"], bolt_mat=M["boulon"])
    # flancs : radiateurs et réservoirs debout
    for sx in (-1, 1):
        PT.radiator(g, M, (sx * 2.58, 1.25, 0.0), 0.72, 1.2, 0.6, n_fins=12, axis="x")
        PT.tank_v(g, M, (sx * 2.6, -0.3, 0.0), 0.32, 1.05, body="tole", n_bands=3, seams=10)
        PT.valve(g, M, (sx * 2.55, -0.95, 0.12), axis="y", r=0.07)
        K.pipe(g, M["cuivre"], M["laiton"], M["boulon"], [(sx * 2.5, -0.62, 0.2), (sx * 2.3, -0.9, 0.2),
                                                          (sx * 2.05, -1.0, 0.35)], 0.045)
        K.cable_bundle(g, [M["cable_r"], M["noir"], M["cuivre"]], [(sx * 2.3, 0.75, 0.55), (sx * 2.2, 0.4, 0.62),
                                                                  (sx * 1.98, 0.2, 0.82)], spread=0.05, r=0.022,
                       ties=M["acier"])
    # angles avant : tourelles secondaires sur piédestaux (2) ; magasin de munitions au centre avant
    for sx in (-1, 1):
        pedestal(g, M, (sx * 2.2, -2.95, 0.0), 1.0, 1.05, 0.56, seed=17 + sx, emit="or_lum")
        secondary_gun(g, M, (sx * 2.2, -2.9, 0.56), 1.4, n=4, emit=M["ligne"], yaw=-sx * 0.3)
    apron(g, M, -0.62, 0.62, -4.0, -2.75, 0.0)
    steps(g, M, -0.38, 0.38, -2.75, 1.1, 7, 0.14)
    for sx in (-1, 1):
        K.crate(g, M, (0.5, 0.42, 0.32), (sx * 1.05, -3.75, 0.0), seed=31 + sx, stencil="jaune")
        K.crate(g, M, (0.44, 0.38, 0.28), (sx * 1.0, -3.72, 0.32), seed=33 + sx, stencil=None)
    for sx in (-1, 1):
        PT.ammo_box(g, M, (0.62, 0.5, 0.4), (sx * 0.95, -2.8, 0.06), body="olive")
        PT.ammo_box(g, M, (0.56, 0.44, 0.34), (sx * 0.95, -2.75, 0.46), body="creme")
        K.ammo_belt(g, M["laiton"], M["noir"], [(sx * 0.95, -2.55, 0.82), (sx * 1.05, -2.2, 0.9), (sx * 1.2, -1.85, 0.95)],
                    pitch=0.05)
        K.lamp(g, M["ambre"], M["acier"], (sx * 1.15, -4.08, 0.1), (0, -1, 0.3), 0.045)
    g.light((0, -3.2, 0.4), (1.0, 0.85, 0.55), 5.0)
    if piece:
        rockets_30(g, M)
    return g


def rockets_30(g, M):
    """Pièce du niveau 30 : deux lance-roquettes à 2 × 3 tubes sur affût bas, devant les piédestaux des tourelles
    secondaires (zone basse et avant : la tête ne passe jamais dessus, F46)."""
    for sx in (-1, 1):
        cx, cy = sx * 1.85, -4.0
        g.box(M["tole_sombre"], (0.86, 0.5, 0.12), (cx, cy, 0.06), 0.014)
        K.bolts_line(g, M["boulon"], (cx - 0.38, cy - 0.25, 0.08), (cx + 0.38, cy - 0.25, 0.08), 5, n=(0, -1, 0), r=0.014)
        g.push(); g.move((cx, cy + 0.02, 0.12)); g.turn("z", -sx * 0.25); g.turn("x", 0.5)
        g.box(M["olive"], (0.72, 0.4, 0.34), (0, 0, 0.17), 0.016)
        for i in range(3):
            for j in range(2):
                x = -0.22 + i * 0.22
                zz = 0.09 + j * 0.16
                g.cyl(M["joint"], 0.06, 0.02, (x, -0.205, zz), axis="y", n=12)
                g.torus(M["acier"], 0.068, 0.016, (x, -0.205, zz), axis="y", n=16, m=5)
                g.dome(M["jaune"], 0.04, (x, -0.195, zz), axis="-y", n=8, rings=2)
        K.hazard_band(g, M["jaune"], M["noir"], (-0.34, -0.205, 0.36), (0.34, -0.205, 0.36), 0.05, 0.01, stripe=0.07,
                      n_up=(0, -1, 0))
        for s in (-1, 1):
            K.bolt(g, M["boulon"], (s * 0.32, -0.2, 0.03), (0, -1, 0), 0.015)
        g.pop()
        K.lamp(g, M["ambre"], M["acier"], (cx + sx * 0.36, cy - 0.26, 0.1), (0, -1, 0.3), 0.04)
        g.light((cx, cy - 0.4, 0.3), (1.0, 0.45, 0.06), 3.0)
        g.count("lance_roquettes")


def head_29(g, M):
    """Forteresse : couronne, fût court à fentes dorées, coque à deux étages (jupe blindée et coque supérieure à
    plaques multiples, accents crème et or blanc), masque large portant la couronne de 3 canons rotatifs lourds
    (8 + 6 + 6 tubes), deux magasins latéraux à 3 bandes, tourelle dorsale, nuque arrière à cellules dorées,
    viseurs, coupole."""
    deck = LEVELS[29]["deck"]
    g.push(); g.move((0, 0, deck))
    z = turntable(g, M, 1.5, 0.0, 72)
    zb = 0.34
    barbette(g, M, 1.36, 1.24, z, zb, seams=18, rows=1, rad_mult=2.5, hatch_at=None, slits=M["or_lum"])
    g.torus(M["or_blanc"], 1.3, 0.026, (0, 0, zb - 0.02), n=72, m=6)
    g.push()
    g.scale_about((0, 0, zb), HEAD_SCALE[29])
    s0 = [(-1.2, -1.6), (1.2, -1.6), (1.42, -1.1), (1.42, 0.5), (1.0, 1.05), (-1.0, 1.05), (-1.42, 0.5), (-1.42, -1.1)]
    z1 = zb + 0.36
    s1 = _inset(s0, 0.06)
    PT.loft(g, M["tole_sombre"], s0, zb, s1, z1)
    PT.plate_loft(g, M, s0, zb, s1, z1, [M["tole"], M["olive"], M["tole_r"], M["tole_b"]], rows=1, col_len=0.36,
                  emit=M["ligne"], emit_every=1, seed=29, top=False)
    u0 = _inset(s0, 0.14)
    zh = z1 + 0.6
    u1 = _inset(s0, 0.4)
    PT.loft(g, M["tole_sombre"], u0, z1, u1, zh)
    PT.plate_loft(g, M, u0, z1, u1, zh, [M["tole"], M["olive"], M["tole_b"], M["alliage"], M["tole_sombre"], M["olive"], M["tole_r"]], rows=2,
                  col_len=0.38, emit=M["or_lum"], emit_every=2, seed=31, top_div=0.5)
    # rebord de jupe (l'étage se lit) : cornière
    PT.loft(g, M["acier"], _inset(s0, 0.02), z1 - 0.005, _inset(s0, 0.1), z1 + 0.03)
    za = zb + 0.62
    g.cyl(M["tole"], 0.46, 1.7, (0, 0.98, za), axis="x", n=48, ch=0.025)
    for xx in (-0.78, -0.3, 0.3, 0.78):
        g.torus(M["or_blanc"] if abs(xx) > 0.5 else M["laiton_tore"], 0.462, 0.022, (xx, 0.98, za), axis="x", n=56, m=6)
    for k in range(3):
        a = 0.3 + k * 0.5
        K.bolts_line(g, M["boulon"], (-0.8, 0.98 + 0.47 * math.cos(a), za + 0.47 * math.sin(a)),
                     (0.8, 0.98 + 0.47 * math.cos(a), za + 0.47 * math.sin(a)), 12, n=(0, math.cos(a), math.sin(a)),
                     r=0.016, kind="rivet")
    guns = ((0.0, za + 0.08, 8, 0.15, 0.046, 3.1, (1.36, 2.15, 0.25)),
            (-0.6, za - 0.12, 6, 0.1, 0.04, 2.8, (1.3, 1.95, 0.18)),
            (0.6, za - 0.12, 6, 0.1, 0.04, 2.8, (1.3, 1.95, 0.18)))
    for x, zz, n, rr, br, y1, jk in guns:
        g.cyl(M["acier"], rr + 0.16, 0.2, (x, 1.36, zz), axis="y", n=40, ch=0.02)
        K.bolts_ring(g, M["boulon"], (x, 1.46, zz), rr + 0.11, 12, axis="y", r=0.016)
        g.torus(M["or_blanc"], rr + 0.16, 0.022, (x, 1.44, zz), axis="y", n=44, m=6)
        K.gatling(g, M, n, rr, br, 1.38, y1, x=x, z=zz, phase=0.0, rings=(0.42, 0.97), jacket=jk, vent=M["ambre"])
    # magasins latéraux (3 bandes chacun)
    for sx in (-1, 1):
        xm = sx * 1.7
        PT.ammo_box(g, M, (0.46, 1.1, 0.62), (xm, -0.4, zb + 0.02), belt_slot=False, body="olive")
        g.box(M["alliage"], (0.48, 0.3, 0.05), (xm, -0.4, zb + 0.66), 0.012)
        for k in range(3):
            yy = -0.75 + k * 0.33
            K.ammo_belt(g, M["laiton"], M["noir"], [(xm - sx * 0.1, yy, zb + 0.66), (sx * 1.35, yy + 0.2, zh + 0.02),
                                                    (sx * 0.95, yy + 0.35, zh + 0.04)], pitch=0.05)
        K.lamp(g, M["or_lum"], M["acier"], (xm, -0.96, zb + 0.45), (0, -1, 0), 0.04)
    # nuque arrière : cellules dorées, bobine, échappements
    K.armor_box(g, M, (1.9, 0.62, 0.62), (0, -1.9, zb + 0.33), div_top=(4, 1), div_side=(4, 2), faces=("top", "s", "e", "w"),
                seed=33, plate_mat=[M["olive"], M["tole"], M["tole_b"], M["tole_sombre"]])
    for x in (-0.66, -0.22, 0.22, 0.66):
        K.slit_light(g, M["or_lum"], M["acier"], (x, -2.22, zb + 0.34), 0.12, 0.2, (0, -1, 0), bars=2)
    K.coil(g, M["cuivre"], M["acier"], (0, -2.0, zb + 0.76), 0.14, 1.2, axis="x", turns=15, wire=0.022,
           flange=M["tole_sombre"])
    for sx in (-1, 1):
        K.exhaust(g, M, (sx * 0.75, -1.75, zb + 0.64), 0.07, 0.2)
        K.lamp(g, M["ambre"], M["acier"], (sx * 0.86, -2.22, zb + 0.12), (0, -1, 0), 0.04)
    g.light((0, -2.4, zb + 0.4), (1.0, 0.9, 0.65), 7.0)
    # toit : grilles moteur, anneaux de levage, tourelle dorsale, viseurs, coupole, câbles
    for sx in (-1, 1):
        K.grille(g, M["acier"], M["tole_sombre"], 0.46, 0.34, (sx * 0.5, -1.15, zh + 0.035), normal=(0, 0, 1),
                 deep_mat=M["joint"])
        K.grille(g, M["acier"], M["tole_sombre"], 0.3, 0.26, (sx * 0.62, -0.2, zh + 0.035), normal=(0, 0, 1),
                 deep_mat=M["joint"])
        g.torus(M["acier_clair"], 0.05, 0.013, (sx * 0.75, 0.55, zh + 0.08), axis="x", n=14, m=4)
        g.box(M["acier"], (0.07, 0.09, 0.05), (sx * 0.75, 0.55, zh + 0.055), 0.006)
    g.cyl(M["tole_sombre"], 0.4, 0.12, (0, -0.55, zh + 0.06), n=40, ch=0.014)
    g.torus(M["or_blanc"], 0.4, 0.02, (0, -0.55, zh + 0.12), n=48, m=6)
    secondary_gun(g, M, (0, -0.6, zh + 0.12), 1.35, n=4, emit=M["or_lum"])
    for sx in (-1, 1):
        K.sensor(g, M, (sx * 0.62, 0.3, zh + 0.03), 0.26, 0.22, 0.17, lens_emit=M["ligne"])
    g.cyl(M["tole"], 0.2, 0.14, (0.55, -0.85, zh + 0.1), n=28, ch=0.012)
    K.bolts_ring(g, M["boulon"], (0.55, -0.85, zh + 0.17), 0.16, 8, r=0.014)
    K.cable_bundle(g, [M["cable_r"], M["noir"], M["cuivre"], M["cable_r"]],
                   [(-0.8, -1.6, zb + 0.66), (-0.7, -1.1, zh + 0.05), (-0.35, -0.3, zh + 0.06)], spread=0.05, r=0.02,
                   ties=M["acier"])
    g.pop()
    g.pop()
    return g


# ------------------------------------------------------------------------------------------------
# Construction d'une variante
# ------------------------------------------------------------------------------------------------
def variants():
    """Socle de chaque niveau, tête N et E de chaque niveau impair, socle + pièce du niveau 30 (la tête du niveau
    30 est celle du 29, la pièce est sur le socle)."""
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
