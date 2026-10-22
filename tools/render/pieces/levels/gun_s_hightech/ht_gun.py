"""Mitrailleuse « haute technologie à la Factorio » (explorateur de style, lot V3-S) : niveaux témoins 11, 21, 29
et pièce du niveau 30. Python PUR (aucun bpy) : géométrie par ht_geo.B, matériaux décrits ici, instanciés dans
Blender par ht_blender.py.

Approche (consigne de l'orchestrateur, verdict du Directeur Créatif du 22/10, charte DA_FACTORIO) : à la manière
du vanilla avancé (réacteur, centrifugeuse, silo, balise), les époques hautes deviennent des machines MASSIVES et
très détaillées : cœurs d'énergie lumineux en petits foyers, carénages techniques épais, conduits, gaines annelées,
radiateurs, tôles boulonnées, bandes de danger ; le corps reste du métal sombre, chaud et usé à toutes les époques ;
la couleur d'époque ne vit que dans les éléments lumineux ; les matériaux d'époque (céramique, titane, or blanc)
ne sont que des accents patinés.

Emprises (charte §6.2, échelle proposée) : niveau 11 (époque 6) 3×3, niveau 21 (époque 11) 5×5, niveau 29 et 30
(époque 15) 6×6. Le socle remplit l'emprise ; la tête tourne au-dessus d'un tambour fixe.

Repris de V3 phase 1 (pieces/levels/gun, branche worktree-wf_1f9884be-7b6-2) : identité « tête à plusieurs
canons », socle (base_picture, 1 direction) et tête (64 directions, poses N et E ici) séparés, canons vers +Y en
repère de tête (pose E = rotation de -90° autour de Z), source du halo portée par le socle, zone toujours visible
pour la pièce du niveau pair (F46 : ici, les coins avant, hors du balayage de la tête), ombres plein est (F47,
étalonnage du pipeline inchangé).

Règle de dessin des couches (le socle est dessiné en lower-object, la tête en object) : dans le cercle balayé par
la tête, les éléments du socle restent plus bas que le dessous des parties tournantes ; les éléments hauts du socle
sont aux coins ARRIÈRE (derrière la tête, qui les recouvre à raison) ; les coins et le bord AVANT restent bas (sinon
la tête, dessinée après, les recouvrirait à tort).
"""
import math

import ht_geo as G
from ht_geo import TD, TAU, Rx, Ry, Rz

# ------------------------------------------------------------------------------------------------
# Niveaux
# ------------------------------------------------------------------------------------------------
LEVELS = {
    11: {"epoch": 6, "era": 2, "side": 3},
    21: {"epoch": 11, "era": 4, "side": 5},
    29: {"epoch": 15, "era": 5, "side": 6},
    30: {"epoch": 15, "era": 5, "side": 6},
}
# lumière d'époque (DESIGN_EPOQUES §0) en couleur LINÉAIRE d'émission ; foyers petits et nombreux (charte §6.4)
EPOCH_GLOW = {6: (0.12, 0.62, 1.0),      # arcs cyan #60D0FF
              11: (0.52, 0.79, 1.0),     # lignes bleu-blanc #BFE6FF
              15: (1.0, 0.86, 0.50)}     # blanc doré #FFF2C0
TONES = ("plate", "plate", "plate_l", "plate2")   # tons de tôle tirés au hasard (graine fixe par niveau)
AMBER = (1.0, 0.42, 0.04)                # voyants d'état (teinte chaude, toutes époques)
# aileron triangulaire : profil (x, y) local -> plan vertical YZ (x local -> +Y, y local -> +Z, épaisseur selon X)
FIN_YZ = G.np.array([[0, 0, 1.0], [1.0, 0, 0], [0, 1.0, 0]])

# halo de nuit : intensité relative par niveau (proportionnelle, plafonnée ; charte §8.6 : rayon ≤ 1,5 × côté)
HALO_GAIN = {11: 0.55, 21: 0.8, 29: 1.0, 30: 1.0}
# fenêtre du halo au sol : plein jusqu'au bord de l'emprise, nul HALO_EXTRA tuile au-delà (rayon nul = côté/2 + 1,
# soit 0,83 × côté au plus : sous la borne « rayon ≤ 1,5 × côté » proposée par la charte §8.6)
HALO_EXTRA = 1.0
# dessus de la barbette (tambour fixe du socle) = pied de la tête
Z_DRUM = {11: 0.75, 21: 1.05, 29: 1.3, 30: 1.3}


def variants():
    v = {}
    for lv in (11, 21, 29):
        v["n%02d-socle" % lv] = {"level": lv, "part": "socle"}
        for d in ("N", "E"):
            v["n%02d-tete-%s" % (lv, d)] = {"level": lv, "part": "tete", "dir": d}
    v["n30-socle"] = {"level": 30, "part": "socle"}
    return v


VARIANTS = variants()
DIR_ANGLE = {"N": 0.0, "E": -math.pi / 2, "S": math.pi, "O": math.pi / 2}


# ------------------------------------------------------------------------------------------------
# Palette (couleurs LINÉAIRES ; paramètres de fo_scene.mat_metal). Ancre : cheminée V0 validée (tôle brune
# rouillée (0,2 ; 0,17 ; 0,13), grain 0,3 à l'échelle 45, crasse des creux 0,85). Le corps est le même à toutes
# les époques ; seul l'accent d'époque et la lueur changent.
# ------------------------------------------------------------------------------------------------
RUST = (0.16, 0.058, 0.022)          # rouille plus SOMBRE que la tôle : contraste de luminance (P2), pas seulement de teinte


def palette(epoch):
    M = {
        "body": dict(kind="metal", color=(0.17, 0.148, 0.118), rough=0.42, metallic=0.6, grain=0.4, grain_scale=48.0,
                     rust=RUST, rust_amount=0.38, rust_scale=10.0, dirt=0.9, dirt_distance=0.5),
        "plate": dict(kind="metal", color=(0.215, 0.185, 0.145), rough=0.4, metallic=0.6, grain=0.38, grain_scale=52.0,
                      rust=RUST, rust_amount=0.32, rust_scale=11.0, dirt=0.9, dirt_distance=0.45),
        "plate_l": dict(kind="metal", color=(0.255, 0.218, 0.17), rough=0.42, metallic=0.55, grain=0.38, grain_scale=50.0,
                        rust=RUST, rust_amount=0.3, rust_scale=11.0, dirt=0.9, dirt_distance=0.45),
        "plate2": dict(kind="metal", color=(0.11, 0.098, 0.082), rough=0.5, metallic=0.55, grain=0.4, grain_scale=45.0,
                       rust=RUST, rust_amount=0.42, rust_scale=9.0, dirt=0.9, dirt_distance=0.5),
        "dark": dict(kind="metal", color=(0.03, 0.027, 0.024), rough=0.6, metallic=0.4, grain=0.25, grain_scale=45.0,
                     dirt=0.5),
        "gun": dict(kind="metal", color=(0.085, 0.08, 0.074), rough=0.33, metallic=0.85, grain=0.22, grain_scale=60.0,
                    rust=RUST, rust_amount=0.2, rust_scale=7.0, dirt=0.6),
        "bolt": dict(kind="metal", color=(0.36, 0.315, 0.25), rough=0.5, metallic=0.8, grain=0.12, grain_scale=70.0,
                     dirt=0.3),
        "brass": dict(kind="metal", color=(0.44, 0.32, 0.15), rough=0.4, metallic=0.9, grain=0.2, grain_scale=60.0,
                      rust=RUST, rust_amount=0.25, rust_scale=6.0, dirt=0.55),
        "copper": dict(kind="metal", color=(0.36, 0.17, 0.085), rough=0.42, metallic=0.9, grain=0.22, grain_scale=55.0,
                       rust=RUST, rust_amount=0.2, rust_scale=6.0, dirt=0.6),
        "haz_y": dict(kind="metal", color=(0.36, 0.235, 0.02), rough=0.65, metallic=0.15, grain=0.35, grain_scale=45.0,
                      rust=RUST, rust_amount=0.4, rust_scale=6.0, dirt=0.75),
        "haz_k": dict(kind="metal", color=(0.028, 0.026, 0.023), rough=0.7, metallic=0.2, grain=0.3, grain_scale=45.0,
                      dirt=0.5),
        "rubber": dict(kind="metal", color=(0.03, 0.028, 0.026), rough=0.75, metallic=0.0, grain=0.15, grain_scale=60.0,
                       dirt=0.4),
        "cable_r": dict(kind="metal", color=(0.17, 0.035, 0.015), rough=0.6, metallic=0.0, grain=0.2, grain_scale=60.0,
                        dirt=0.5),
        "grille": dict(kind="metal", color=(0.045, 0.04, 0.035), rough=0.65, metallic=0.4, grain=0.2, grain_scale=50.0,
                       dirt=0.4),
        "case": dict(kind="metal", color=(0.46, 0.33, 0.13), rough=0.36, metallic=0.9, grain=0.15, grain_scale=70.0,
                     dirt=0.4),
        "glow": dict(kind="emit", color=EPOCH_GLOW[epoch], strength=1.0),
        "amber": dict(kind="emit", color=AMBER, strength=1.0),
    }
    if epoch == 6:
        # céramique d'isolateur PATINÉE (bible #D8D4C8 assombrie : accent, pas un corps clair)
        M["accent"] = dict(kind="metal", color=(0.40, 0.36, 0.29), rough=0.45, metallic=0.0, grain=0.22,
                           grain_scale=55.0, rust=RUST, rust_amount=0.2, rust_scale=7.0, dirt=0.8)
    elif epoch == 11:
        # titane terni (bible #8E9AA6 réchauffé et assombri ; plaques d'accent seulement)
        M["accent"] = dict(kind="metal", color=(0.27, 0.26, 0.24), rough=0.45, metallic=0.75, grain=0.24,
                           grain_scale=55.0, rust=RUST, rust_amount=0.15, rust_scale=7.0, dirt=0.75)
    else:
        # or blanc patiné (bible #E8DCB0 assombri), accents de couronne et de cœur
        M["accent"] = dict(kind="metal", color=(0.44, 0.36, 0.20), rough=0.38, metallic=0.9, grain=0.22,
                           grain_scale=55.0, rust=RUST, rust_amount=0.2, rust_scale=6.0, dirt=0.65)
    return M


# Crasse à moyenne échelle ajoutée par ht_blender.add_grime au matériau du pipeline (fo_scene.mat_metal inchangé) :
# (taches isotropes, coulures verticales), amplitudes relatives. Pourquoi : la charte (P2, variance basse fréquence
# des surfaces planes, plancher 16, vanilla 14 à 27) ; le premier rendu mesurait 12 à 13 : grain fin et rouille
# seulement, sans taches ni coulures entre 4 et 16 px.
GRIME = {"body": (0.38, 0.4), "plate": (0.38, 0.4), "plate_l": (0.38, 0.4), "plate2": (0.34, 0.34), "gun": (0.2, 0.2), "brass": (0.18, 0.2),
         "copper": (0.18, 0.2), "haz_y": (0.25, 0.35), "accent": (0.22, 0.28), "case": (0.12, 0.1),
         "haz_k": (0.2, 0.2), "dark": (0.2, 0.2), "grille": (0.15, 0.15)}


# ------------------------------------------------------------------------------------------------
# Modules communs
# ------------------------------------------------------------------------------------------------
def octagon(hx, hy, cf, cb):
    """Octogone d'emprise : demi-côtés hx (X) et hy (Y Blender), chanfreins avant cf et arrière cb (tuiles)."""
    return [(-hx + cf, -hy), (hx - cf, -hy), (hx, -hy + cf * TD), (hx, hy - cb * TD), (hx - cb, hy), (-hx + cb, hy),
            (-hx, hy - cb * TD), (-hx, -hy + cf * TD)]


def slab(b, side, z, cf, cb, deck=(8, 10)):
    """Dalle de fondation octogonale : tôles du dessus, bande de danger et boulons sur la face avant."""
    hx, hy = side / 2.0, side / 2.0 * TD
    b.prism("plate2", octagon(hx, hy, cf, cb), 0.0, z, bev=0.03)
    # bordure (cornière) sur le pourtour du dessus
    poly = octagon(hx, hy, cf, cb)
    n = len(poly)
    for i in range(n):
        p0, p1 = poly[i], poly[(i + 1) % n]
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        L = math.hypot(dx, dy)
        a = math.atan2(dy, dx)
        cx, cy = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        # vers l'intérieur
        nx, ny = -dy / L, dx / L
        b.box("body", (cx + nx * 0.05, cy + ny * 0.05, z + 0.025), (L - 0.06, 0.1, 0.05), R=Rz(a), bev=0.01)
        k = max(2, int(L / 0.32))
        for j in range(k):
            t = (j + 0.5) / k
            b.bolt("bolt", (p0[0] + dx * t + nx * 0.05, p0[1] + dy * t + ny * 0.05, z + 0.055), r=0.022)
    # tôles du dessus (les cases coupées par les chanfreins sont omises)
    nx_, ny_ = deck
    x0, x1, y0, y1 = -hx + 0.12, hx - 0.12, -hy + 0.12, hy - 0.12
    skip = set()
    w = (x1 - x0) / nx_
    d = (y1 - y0) / ny_
    for i in range(nx_):
        for j in range(ny_):
            cx = x0 + (i + 0.5) * w
            cy = y0 + (j + 0.5) * d
            # coin avant / arrière : distance au bord chanfreiné
            for (sx, sy, c) in ((-1, -1, cf), (1, -1, cf), (-1, 1, cb), (1, 1, cb)):
                if (sx * cx - (hx - c)) * TD + (sy * cy - (hy - c * TD)) > -0.25 and sx * cx > hx - c - w and \
                        sy * cy > hy - c * TD - d:
                    skip.add((i, j))
    gap = 0.035
    for i in range(nx_):
        for j in range(ny_):
            if (i, j) in skip:
                continue
            cx = x0 + (i + 0.5) * w
            cy = y0 + (j + 0.5) * d
            pw, pd = w - gap, d - gap
            r = b.rng.random()
            if r < 0.12:
                # grille encastrée (fond sombre)
                b.grille_top("body", "grille", "dark", cx - pw / 2, cx + pw / 2, cy - pd / 2, cy + pd / 2, z + 0.012,
                             max(3, int((pd if pw >= pd else pw) / 0.075)), along="x" if pw >= pd else "y")
                continue
            if r < 0.18:
                hatch(b, (cx, cy, z), pw * 0.85, pd * 0.85)
                continue
            mat = "plate2" if r < 0.3 else ("plate_l" if r < 0.5 else "plate")
            b.box(mat, (cx, cy, z + 0.015), (pw, pd, 0.03), bev=0.012)
            b.bolts_rect("bolt", cx - pw / 2, cx + pw / 2, cy - pd / 2, cy + pd / 2, z + 0.03, r=0.022, inset=0.055)
    # face avant : bande de danger et boulons
    yf = -hy - 0.004
    b.hazard_band("haz_y", "haz_k", (-hx + cf + 0.05, yf, z * 0.55), (hx - cf - 0.05, yf, z * 0.55), width=z * 0.55,
                  th=0.012, normal="-y")
    b.bolts_line("bolt", (-hx + cf, yf - 0.006, z * 0.15), (hx - cf, yf - 0.006, z * 0.15), int(side * 3), r=0.02,
                 axis="-y", h=0.014)


def capacitor(b, c, r, h, glow_slits=2, terminals=True):
    """Cellule de réserve d'énergie : fût cerclé, fenêtres de jauge lumineuses vers le sud (caméra), couvercle à
    bornes cuivre ; grille de protection sur les fenêtres."""
    x, y, z0 = c
    b.cyl("plate2", (x, y, z0 + 0.04), r + 0.05, 0.08, n=24, bev=0.01)
    b.cyl("body", (x, y, z0 + 0.08 + h / 2), r, h, n=28, bev=0.012)
    for t in (0.12, 0.5, 0.88):
        b.cyl("brass", (x, y, z0 + 0.08 + h * t), r + 0.018, 0.045, n=28, bev=0.006)
    # fenêtres de jauge (sud et sud-est / sud-ouest)
    for k in range(glow_slits):
        a = -math.pi / 2 + (k - (glow_slits - 1) / 2) * 0.55
        px, py = x + math.cos(a) * (r + 0.004), y + math.sin(a) * (r + 0.004)
        Rm = Rz(a + math.pi / 2)
        b.box("dark", (px, py, z0 + 0.08 + h * 0.5), (0.14, 0.03, h * 0.62), R=Rm, bev=0)
        b.box("glow", (px + math.cos(a) * 0.006, py + math.sin(a) * 0.006, z0 + 0.08 + h * 0.5), (0.095, 0.02, h * 0.5),
              R=Rm, bev=0)
        for zz in (0.36, 0.5, 0.64):
            b.box("grille", (px + math.cos(a) * 0.02, py + math.sin(a) * 0.02, z0 + 0.08 + h * zz), (0.1, 0.02, 0.025),
                  R=Rm, bev=0)
    zt = z0 + 0.08 + h
    b.cyl("plate", (x, y, zt + 0.04), r + 0.02, 0.08, r2=r * 0.8, n=28, bev=0.01)
    nb = 10
    for i in range(nb):
        a = TAU * i / nb
        b.bolt("bolt", (x + math.cos(a) * (r - 0.03), y + math.sin(a) * (r - 0.03), zt + 0.005), r=0.018)
    if terminals:
        for s in (-1, 1):
            b.cyl("copper", (x + s * r * 0.35, y, zt + 0.13), 0.045, 0.1, n=10, bev=0.006)
            b.cyl("dark", (x + s * r * 0.35, y, zt + 0.08), 0.06, 0.03, n=10, bev=0)


def radiator_block(b, c, size, along="x", glow=False, fin_pitch=0.07):
    """Radiateur : caisson, ailettes au-dessus, grilles latérales, tubulures cuivre aux extrémités."""
    x, y, z0 = c
    sx, sy, sz = size
    b.box("plate2", (x, y, z0 + sz * 0.3), (sx, sy, sz * 0.6), bev=0.02)
    b.plates_face("plate", (x, y - sy / 2, z0 + sz * 0.3), (1, 0, 0), (0, 0, 1), max(1, int(sx / 0.5)), 1, sx - 0.04,
                  sz * 0.56, th=0.025, bolt_mat="bolt", tones=TONES)
    n = int((sx if along == "x" else sy) / fin_pitch) - 1
    length = (sy if along == "x" else sx) - 0.08
    b.fins("body", (x, y, z0 + sz * 0.6), along, length, sz * 0.4, n, pitch=fin_pitch, th=0.032, base_mat="plate2")
    if glow:
        # lueur du cœur sous les ailettes (fente avant)
        k = max(2, int((sx - 0.2) / 0.32))
        for i in range(k):
            b.box("glow", (x - (sx - 0.2) / 2 + (i + 0.5) * (sx - 0.2) / k, y - sy / 2 - 0.004, z0 + sz * 0.45),
                  ((sx - 0.2) / k - 0.08, 0.02, 0.08), bev=0)
    for s in (-1, 1):
        if along == "x":
            b.cyl("copper", (x + s * (sx / 2 + 0.05), y, z0 + sz * 0.45), 0.06, sy * 0.85, axis="y", n=12, bev=0.006)
            for t in (-0.3, 0.3):
                b.cyl("brass", (x + s * (sx / 2 + 0.05), y + t * sy, z0 + sz * 0.45), 0.08, 0.04, axis="y", n=12, bev=0.005)
        else:
            b.cyl("copper", (x, y + s * (sy / 2 + 0.05), z0 + sz * 0.45), 0.06, sx * 0.85, axis="x", n=12, bev=0.006)


def crate(b, c, size, rot=0.0, hazard=True, lid=True):
    """Caisse de munitions blindée : tôles, cornières, bande de danger, poignées, couvercle boulonné."""
    x, y, z0 = c
    sx, sy, sz = size
    R = Rz(rot)
    b.push(R, (x, y, z0))
    b.box("plate2", (0, 0, sz / 2), (sx, sy, sz), bev=0.02)
    for sxx in (-1, 1):
        for syy in (-1, 1):
            b.box("body", (sxx * (sx / 2 - 0.02), syy * (sy / 2 - 0.02), sz / 2), (0.06, 0.06, sz + 0.02), bev=0.008)
    if lid:
        b.box("plate", (0, 0, sz + 0.02), (sx - 0.08, sy - 0.08, 0.04), bev=0.012)
        b.bolts_rect("bolt", -sx / 2 + 0.04, sx / 2 - 0.04, -sy / 2 + 0.04, sy / 2 - 0.04, sz + 0.04, r=0.02, inset=0.05,
                     n=(3, 3))
        b.box("dark", (0, 0, sz + 0.055), (sx * 0.3, 0.04, 0.03), bev=0.004)
    if hazard:
        b.hazard_band("haz_y", "haz_k", (-sx / 2 + 0.06, -sy / 2 - 0.004, sz * 0.62), (sx / 2 - 0.06, -sy / 2 - 0.004,
                      sz * 0.62), width=sz * 0.22, th=0.01, normal="-y")
    for s in (-1, 1):
        b.box("dark", (s * (sx / 2 + 0.02), 0, sz * 0.7), (0.03, sy * 0.35, 0.05), bev=0.004)
    b.bolts_line("bolt", (-sx / 2 + 0.08, -sy / 2 - 0.006, sz * 0.25), (sx / 2 - 0.08, -sy / 2 - 0.006, sz * 0.25),
                 max(2, int(sx / 0.15)), r=0.018, axis="-y", h=0.012)
    b.pop()


def pipe_run(b, p0, p1, r, z, flanges=4, valve=True, supports=3):
    """Conduite rigide sur supports : tube, brides boulonnées, vanne à volant."""
    p0, p1 = G.np.array([p0[0], p0[1], z], float), G.np.array([p1[0], p1[1], z], float)
    d = p1 - p0
    L = float(G.np.linalg.norm(d))
    u = d / L
    b.cyl("body", (p0 + p1) / 2, r, L, axis=u, n=14, bev=0.006)
    for i in range(flanges):
        p = p0 + d * (i + 0.5) / flanges
        b.cyl("plate", p, r * 1.5, 0.05, axis=u, n=14, bev=0.006)
        for k in range(6):
            a = TAU * k / 6
            F = G.frame_from_axis(u)
            q = p + (F[:, 0] * math.cos(a) + F[:, 1] * math.sin(a)) * r * 1.3
            b.cyl("bolt", q, 0.016, 0.07, axis=u, n=6, bev=0)
    for i in range(supports):
        p = p0 + d * (i + 0.5) / supports
        b.box("plate2", (p[0], p[1], z / 2), (0.08, 0.08, z), bev=0.008)
        b.box("body", (p[0], p[1], z - r - 0.02), (0.16, 0.12, 0.04), bev=0.006)
    if valve:
        p = p0 + d * 0.5 + G.np.array([0, 0, r + 0.08])
        b.cyl("plate", p - G.np.array([0, 0, 0.04]), 0.035, 0.08, n=10, bev=0.005)
        b.torus("cable_r", p, 0.085, 0.016, axis="z", n=16, m=6)
        for k in range(3):
            a = TAU * k / 3
            b.box("cable_r", p + G.np.array([math.cos(a) * 0.04, math.sin(a) * 0.04, 0]), (0.08, 0.02, 0.02), R=Rz(a),
                  bev=0)


def stairs(b, x, y_front, width, z_top, n):
    """Marches d'accès (caillebotis) et garde-corps bas, sur le bord avant."""
    step_d = 0.12
    for i in range(n):
        zz = z_top * (i + 1) / (n + 1)
        yy = y_front + (n - i - 0.5) * step_d
        b.box("plate2", (x, yy, zz / 2), (width, step_d, zz), bev=0.006)
        b.box("haz_y" if i == n - 1 else "grille", (x, yy - step_d / 2 + 0.012, zz - 0.004), (width - 0.04, 0.024, 0.012),
              bev=0)
    for s in (-1, 1):
        b.box("body", (x + s * (width / 2 + 0.03), y_front + n * step_d / 2, z_top * 0.5), (0.04, n * step_d, z_top),
              bev=0.006)


def lamp_post(b, c, h, glow="amber"):
    """Borne lumineuse basse (bollard) : fût, cerclage, voyant."""
    x, y, z0 = c
    b.cyl("plate2", (x, y, z0 + h / 2), 0.06, h, n=12, bev=0.006)
    b.cyl("haz_y", (x, y, z0 + h * 0.75), 0.064, h * 0.18, n=12, bev=0)
    b.cyl(glow, (x, y, z0 + h + 0.03), 0.045, 0.06, n=12, bev=0)
    b.cyl("dark", (x, y, z0 + h + 0.07), 0.055, 0.02, n=12, bev=0.004)


def hose_arc(b, p0, p1, lift, r, mat="copper", ring="brass", k=10, pitch=0.075):
    p0, p1 = G.np.asarray(p0, float), G.np.asarray(p1, float)
    pts = []
    for i in range(k + 1):
        t = i / k
        p = p0 + (p1 - p0) * t
        p[2] += lift * 4 * t * (1 - t)
        pts.append(p)
    b.hose(mat, ring, pts, r, pitch=pitch)


def cable_bundle(b, p0, p1, sag, n=3, r=0.022, spread=0.05):
    p0, p1 = G.np.asarray(p0, float), G.np.asarray(p1, float)
    d = p1 - p0
    side = G.np.cross(d, [0, 0, 1.0])
    nn = G.np.linalg.norm(side)
    side = side / nn if nn > 1e-6 else G.np.array([1.0, 0, 0])
    for i in range(n):
        o = (i - (n - 1) / 2) * spread
        mat = "cable_r" if i == n // 2 and n >= 3 else "rubber"
        b.cable(mat, p0 + side * o, p1 + side * o, sag=sag + 0.02 * i, r=r)
    # colliers
    for t in (0.25, 0.5, 0.75):
        p = p0 + d * t
        p[2] -= sag * 4 * t * (1 - t) + 0.01
        b.box("plate", p, (0.05, 0.05, 0.05), bev=0.005)


def barbette(b, R, z0, z1, nplates, rows=2, vents=4, glow_vents=0, vent_rows=1):
    """Barbette (tambour fixe haut et blindé) : fût, rangées de tôles boulonnées, bande de danger sous la
    couronne, grilles d'aération (certaines lumineuses), échelle, chemin de roulement du dessus."""
    h = z1 - z0
    b.cyl("plate2", (0, 0, z0 + h / 2), R, h, n=72, bev=0.02)
    rh = (h - 0.12) / rows
    vent_idx = set()
    front = [i for i in range(nplates) if math.sin(TAU * (i + 0.5) / nplates) < -0.25]
    step = max(1, len(front) // max(1, vents))
    for j, i in enumerate(front[::step][:vents]):
        vent_idx.add(i)
    glow_idx = set(sorted(vent_idx)[:glow_vents])
    for row in range(rows):
        zc = z0 + 0.03 + rh * (row + 0.5)
        off = 0.5 * (row % 2)
        for i in range(nplates):
            a = TAU * (i + 0.5 + off) / nplates
            w = TAU * R / nplates - 0.045
            ca, sa = math.cos(a), math.sin(a)
            Rm = Rz(a + math.pi / 2)
            c = (ca * (R + 0.028), sa * (R + 0.028), zc)
            if row >= rows - vent_rows and i in vent_idx:
                u = G.np.array([-sa, ca, 0.0])
                b.vent_face("plate", "body", "glow" if i in glow_idx else "dark", (ca * (R + 0.01), sa * (R + 0.01), zc),
                            u, (0, 0, 1), w * 0.8, rh * 0.8, max(3, int(rh / 0.07)))
                continue
            b.box("plate", c, (w, 0.055, rh - 0.04), R=Rm, bev=0.012)
            u = G.np.array([-sa, ca, 0.0])
            for s in (-1, 1):
                for zz in (-0.5, 0.5):
                    p = G.np.array(c) + u * s * (w / 2 - 0.045)
                    b.bolt("bolt", (p[0] + ca * 0.03, p[1] + sa * 0.03, zc + zz * (rh - 0.13)), r=0.02, h=0.014,
                           axis=(ca, sa, 0.0))
    # bande de danger sous la couronne (secteur avant, face à la caméra)
    for i in range(nplates):
        a = TAU * (i + 0.5) / nplates
        if math.sin(a) > -0.2:
            continue
        ca, sa = math.cos(a), math.sin(a)
        u = G.np.array([-sa, ca, 0.0])
        w = TAU * R / nplates
        p = G.np.array((ca * (R + 0.01), sa * (R + 0.01), z1 - 0.06))
        b.hazard_band("haz_y", "haz_k", p - u * w / 2, p + u * w / 2, width=0.09, th=0.012, normal=(ca, sa, 0.0), n=2)
    # couronne : bague laiton, joint sombre, rangée de boulons
    b.cyl("body", (0, 0, z1 - 0.02), R + 0.04, 0.05, n=72, bev=0.01)
    b.cyl("brass", (0, 0, z1 + 0.015), R * 0.94, 0.03, n=72, bev=0.008)
    b.cyl("dark", (0, 0, z1 + 0.012), R * 0.87, 0.026, n=72, bev=0)
    nb = int(TAU * R / 0.15)
    for i in range(nb):
        a = TAU * i / nb
        b.bolt("bolt", (math.cos(a) * R * 0.97, math.sin(a) * R * 0.97, z1 + 0.012), r=0.022)
    # échelle sur le flanc avant gauche
    a = math.radians(235)
    ca, sa = math.cos(a), math.sin(a)
    for s in (-1, 1):
        da = s * 0.09 / R
        b.box("body", (math.cos(a + da) * (R + 0.07), math.sin(a + da) * (R + 0.07), z0 + h / 2), (0.034, 0.034, h),
              bev=0)
    for k in range(int(h / 0.14)):
        b.box("body", (ca * (R + 0.07), sa * (R + 0.07), z0 + 0.1 + k * 0.14), (0.2, 0.032, 0.032), R=Rz(a + math.pi / 2),
              bev=0)


def blast_wall(b, x0, x1, y_front, h, depth=0.42, lamps=None):
    """Mur pare-éclats bas (face avant inclinée) : tôles boulonnées sur le talus, chaperon à bande de danger,
    barbacanes d'écoulement."""
    L = x1 - x0
    prof = [(y_front, 0.0), (y_front + depth, 0.0), (y_front + depth, h), (y_front + depth * 0.55, h)]
    b.prism("plate2", [(y, z) for y, z in prof], -L / 2, L / 2, R=G.np.array([[0, 0, 1.0], [1.0, 0, 0], [0, 1.0, 0]]),
            t=((x0 + x1) / 2, 0, 0), bev=0.02)
    # tôles sur le talus incliné
    ang = math.atan2(h, depth * 0.55)
    n = max(2, int(L / 0.45))
    w = L / n - 0.04
    slope_len = math.hypot(h, depth * 0.55)
    for i in range(n):
        cx = x0 + (i + 0.5) * L / n
        cy = y_front + depth * 0.275
        p = (cx, cy - 0.012, h / 2)
        Rm = Rx(-(math.pi / 2 - ang))
        b.box("plate", p, (w, 0.03, slope_len * 0.86), R=Rm, bev=0.01)
        for s in (-1, 1):
            for t in (-0.32, 0.32):
                q = G.np.array(p) + Rm @ G.np.array([s * (w / 2 - 0.05), -0.02, t * slope_len])
                b.bolt("bolt", q, r=0.02, h=0.014, axis=Rm @ G.np.array([0, -1.0, 0]))
        b.box("dark", (cx, y_front - 0.005, 0.05), (0.1, 0.02, 0.05), bev=0)
        if lamps:
            # feu de balisage encastré dans le talus (foyer séparé, face à la caméra)
            q = G.np.array(p) + Rm @ G.np.array([0.0, -0.022, 0.0])
            b.box(lamps, q, (0.1, 0.012, 0.07), R=Rm, bev=0)
    # chaperon
    b.box("body", ((x0 + x1) / 2, y_front + depth * 0.78, h + 0.025), (L, depth * 0.48, 0.05), bev=0.012)
    b.hazard_band("haz_y", "haz_k", (x0 + 0.04, y_front + depth * 0.56, h + 0.052), (x1 - 0.04, y_front + depth * 0.56,
                  h + 0.052), width=0.1, th=0.008, normal="z")


def floor_conduit(b, x0, x1, y, glow=True, w=0.22):
    """Caniveau d'énergie dans le pont : cornières, grille, fond lumineux (petits foyers séparés par les barreaux),
    deux câbles de cuivre."""
    L = x1 - x0
    zc = 0.0
    b.grille_top("body", "grille", "dark", x0, x1, y - w / 2, y + w / 2, zc, int(L / 0.09), along="y")
    if glow:
        # foyers séparés (tronçons de 0,3 tuile, entretoises sombres de 0,1) : jamais une longue plage lumineuse
        k = max(1, int(L / 0.4))
        for i in range(k):
            cx = x0 + (i + 0.5) * L / k
            b.box("glow", (cx, y, zc - 0.004), (L / k - 0.12, w - 0.09, 0.012), bev=0)
    for s in (-1, 1):
        b.cyl("copper", ((x0 + x1) / 2, y + s * w * 0.62, zc + 0.03), 0.03, L, axis="x", n=10, bev=0)


def manifold(b, x0, x1, y, z, r=0.055, n_tees=4):
    """Collecteur de refroidissement couché devant la barbette : 2 conduites parallèles sur berceaux, brides,
    tés montants vers la barbette."""
    for k, dy in enumerate((0.0, 0.17)):
        pipe_run(b, (x0, y + dy), (x1, y + dy), r * (1.0 - 0.15 * k), z + 0.04 * k, flanges=n_tees + 1, valve=(k == 0),
                 supports=n_tees)
    for i in range(n_tees):
        x = x0 + (x1 - x0) * (i + 0.5) / n_tees
        b.cyl("body", (x, y + 0.3, z + 0.1), r * 0.8, 0.26, n=12, bev=0.006)
        b.cyl("plate", (x, y + 0.3, z + 0.24), r * 1.2, 0.04, n=12, bev=0.005)
        b.cyl("body", (x, y + 0.15, z + 0.0), r * 0.8, 0.3, axis="y", n=12, bev=0.006)


def hatch(b, c, w, d):
    """Trappe de visite blindée dans le pont : cadre, couvercle boulonné, poignée, charnières."""
    x, y, z = c
    b.box("body", (x, y, z + 0.015), (w + 0.06, d + 0.06, 0.03), bev=0.006)
    b.box("plate", (x, y, z + 0.035), (w, d, 0.03), bev=0.01)
    b.bolts_rect("bolt", x - w / 2, x + w / 2, y - d / 2, y + d / 2, z + 0.05, r=0.018, inset=0.04, n=(3, 3))
    b.box("dark", (x, y - d * 0.25, z + 0.06), (w * 0.4, 0.03, 0.025), bev=0)
    for s in (-1, 1):
        b.cyl("plate2", (x + s * w * 0.3, y + d / 2 + 0.02, z + 0.04), 0.025, w * 0.18, axis="x", n=8, bev=0)


def tank_h(b, c, r, L):
    """Réservoir couché (fluide de refroidissement) : virole cerclée, fonds bombés, berceaux, manomètre, bande."""
    x, y, z0 = c
    zc = z0 + 0.06 + r
    b.cyl("body", (x, y, zc), r, L, axis="x", n=24, bev=0.01)
    for s in (-1, 1):
        b.sphere("plate", (x + s * L / 2, y, zc), r, n=20, m=10, scale=(0.35, 1, 1))
        b.box("plate2", (x + s * L * 0.3, y, z0 + 0.06 + r * 0.4), (0.08, r * 1.7, r * 0.8 + 0.12), bev=0.01)
    for t in (-0.38, -0.12, 0.12, 0.38):
        b.cyl("brass" if abs(t) > 0.3 else "plate", (x + t * L, y, zc), r + 0.015, 0.035, axis="x", n=24, bev=0.005)
    b.hazard_band("haz_y", "haz_k", (x - L * 0.08, y - r - 0.004, zc), (x + L * 0.08, y - r - 0.004, zc), width=r * 0.6,
                  th=0.01, normal="-y")
    b.cyl("plate", (x + L * 0.25, y, zc + r + 0.03), 0.04, 0.06, n=12, bev=0.004)
    b.cyl("brass", (x + L * 0.25, y - 0.02, zc + r + 0.1), 0.045, 0.02, axis="y", n=14, bev=0)
    b.cyl("body", (x - L * 0.25, y, zc + r + 0.04), 0.035, 0.1, n=10, bev=0.004)
    b.torus("cable_r", (x - L * 0.25, y, zc + r + 0.1), 0.05, 0.012, n=12, m=6)


def spline(pts, k=8):
    """Catmull-Rom par les points de contrôle (gaines souples)."""
    P = [G.np.asarray(p, float) for p in pts]
    P = [P[0]] + P + [P[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for j in range(k):
            t = j / k
            out.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P[-2])
    return out


def big_hose(b, pts, r):
    """Grosse gaine annelée de cuivre (boucle de refroidissement, comme le réacteur et le silo vanilla) : gaine,
    bagues laiton, brides boulonnées aux deux bouts, colliers de fixation au sol."""
    path = spline(pts)
    b.hose("copper", "brass", path, r, pitch=max(0.07, r * 0.85), n=14, ring_r=r * 1.14)
    for end, nxt in ((path[0], path[1]), (path[-1], path[-2])):
        d = G.np.asarray(end) - G.np.asarray(nxt)
        b.cyl("plate", end, r * 1.45, 0.06, axis=d, n=16, bev=0.006)
        F = G.frame_from_axis(d)
        for k in range(6):
            a = TAU * k / 6
            q = G.np.asarray(end) + (F[:, 0] * math.cos(a) + F[:, 1] * math.sin(a)) * r * 1.25
            b.cyl("bolt", q, 0.017, 0.08, axis=d, n=6, bev=0)
    for i in range(1, len(pts) - 1):
        x, y, z = pts[i]
        if z - r > 0.25:
            b.box("plate2", (x, y, (z - r) / 2 + 0.1), (0.07, 0.07, z - r - 0.1), bev=0.006)
        b.box("body", (x, y, z), (r * 2.6, 0.06, r * 2.6), R=Rz(math.atan2(pts[i + 1][1] - pts[i - 1][1],
                                                                          pts[i + 1][0] - pts[i - 1][0]) + math.pi / 2),
              bev=0.01)


def pump(b, c, r, h):
    """Pompe de refroidissement : corps cylindrique bridé, moteur horizontal à ailettes, tubulures."""
    x, y, z0 = c
    b.cyl("plate2", (x, y, z0 + 0.04), r + 0.05, 0.08, n=24, bev=0.01)
    b.cyl("body", (x, y, z0 + 0.08 + h / 2), r, h, n=24, bev=0.012)
    for t in (0.2, 0.8):
        b.cyl("plate", (x, y, z0 + 0.08 + h * t), r + 0.03, 0.05, n=24, bev=0.006)
        for k in range(8):
            a = TAU * k / 8
            b.bolt("bolt", (x + math.cos(a) * (r + 0.02), y + math.sin(a) * (r + 0.02), z0 + 0.08 + h * t + 0.03), r=0.016)
    zt = z0 + 0.08 + h
    b.cyl("plate2", (x, y, zt + 0.04), r * 0.9, 0.08, n=24, bev=0.01)
    b.cyl("body", (x, y, zt + 0.08 + r * 0.55), r * 0.55, r * 1.6, axis="y", n=20, bev=0.01)
    for k in range(7):
        b.cyl("plate", (x, y - r * 0.7 + k * r * 0.23, zt + 0.08 + r * 0.55), r * 0.62, 0.025, axis="y", n=20, bev=0)
    b.cyl("haz_y", (x, y - r * 0.82, zt + 0.08 + r * 0.55), r * 0.4, 0.03, axis="y", n=16, bev=0)
    b.lamp("amber", "plate2", (x + r * 0.7, y - r * 0.3, zt + 0.02), (0.06, 0.05), axis="z")


def conveyor(b, p0, p1, w, h=0.12):
    """Goulotte de munitions inclinée et capotée, fentes de visite (cartouches visibles)."""
    p0, p1 = G.np.asarray(p0, float), G.np.asarray(p1, float)
    d = p1 - p0
    L = float(G.np.linalg.norm(d))
    u = d / L
    side = G.np.cross([0, 0, 1.0], u)
    side /= G.np.linalg.norm(side)
    up = G.np.cross(u, side)
    Rm = G.np.stack([side, u, up], 1)
    b.box("plate2", (p0 + p1) / 2, (w, L, h), R=Rm, bev=0.012)
    k = max(2, int(L / 0.25))
    for i in range(k):
        q = p0 + d * (i + 0.5) / k + up * (h / 2 + 0.004)
        b.box("dark", q, (w * 0.6, 0.12, 0.012), R=Rm, bev=0)
        b.cyl("case", q + up * 0.006, 0.018, w * 0.5, axis=side, n=6, bev=0)
        b.bolts_line("bolt", q - side * w * 0.42 - u * 0.1, q - side * w * 0.42 + u * 0.1, 2, r=0.016, axis=up, h=0.01)
    for s in (0.0, 1.0):
        q = p0 + d * s
        b.box("body", q - up * (h / 2) - G.np.array([0, 0, q[2] / 2 - h / 2]) * 0, (w * 0.4, 0.06, 0.06), R=Rm, bev=0.006)


# ------------------------------------------------------------------------------------------------
# Socles
# ------------------------------------------------------------------------------------------------
def socle_11(b):
    """Époque 6 (Électricité), 3×3 : dalle, barbette, transformateur à bobines et isolateurs (coin arrière gauche),
    caisse de munitions et goulotte (coin arrière droit), pompe (flanc ouest), coffret (flanc est), mur bas avant."""
    side, hx, hy = 3, 1.5, 1.5 * TD
    zs = 0.15
    zd = Z_DRUM[11]
    slab(b, side, zs, cf=0.38, cb=0.15, deck=(9, 12))
    b.label("socle pivotant")
    barbette(b, 0.98, zs, zd, 14, rows=2, vents=4, glow_vents=4)
    # coin arrière gauche : transformateur (caisson à ailettes, bobines de cuivre, 2 isolateurs céramique, éclateur)
    x, y = -1.08, 1.62
    b.box("plate2", (x, y, zs + 0.3), (0.72, 0.85, 0.6), bev=0.02)
    b.plates_face("plate", (x, y - 0.425, zs + 0.3), (1, 0, 0), (0, 0, 1), 2, 1, 0.68, 0.54, th=0.022, bolt_mat="bolt", tones=TONES)
    b.fins("body", (x - 0.39, y, zs + 0.06), "y", 0.1, 0.46, 10, pitch=0.072, th=0.032)
    for k in range(3):
        b.cyl("copper", (x - 0.15 + k * 0.15, y + 0.12, zs + 0.66), 0.06, 0.12, n=14, bev=0.005)
        b.torus("copper", (x - 0.15 + k * 0.15, y + 0.12, zs + 0.64), 0.065, 0.016, n=14, m=6)
    for s in (-1, 1):
        zz = zs + 0.6
        for k in range(5):
            b.cyl("accent", (x + s * 0.2, y - 0.18, zz + 0.04), 0.075 if k % 2 == 0 else 0.055, 0.075, n=16, bev=0.008)
            zz += 0.075
        b.cyl("copper", (x + s * 0.2, y - 0.18, zz + 0.05), 0.022, 0.1, n=8, bev=0)
        b.sphere("copper", (x + s * 0.14, y - 0.18, zz + 0.1), 0.03, n=10, m=6)
    b.box("glow", (x, y - 0.18, zs + 1.06), (0.22, 0.05, 0.07), bev=0)
    b.light((x, y - 0.18, zs + 1.06), EPOCH_GLOW[6], 30.0)
    b.lamp("glow", "plate2", (x + 0.22, y - 0.435, zs + 0.47), (0.08, 0.05), axis="-y")
    b.lamp("amber", "plate2", (x - 0.12, y - 0.435, zs + 0.47), (0.06, 0.05), axis="-y")
    cable_bundle(b, (x + 0.36, y - 0.25, zs + 0.45), (-0.5, 0.75, zd - 0.05), sag=0.1, n=3)
    # coin arrière droit : caisse de munitions + goulotte vers la couronne
    crate(b, (1.03, 1.55, zs), (0.66, 0.75, 0.46))
    conveyor(b, (0.92, 1.05, zs + 0.52), (0.62, 0.64, zd - 0.09), 0.16)
    b.label("alimentation en munitions")
    # flanc ouest : pompe de refroidissement + conduite
    pump(b, (-1.2, -0.75, zs), 0.14, 0.32)
    pipe_run(b, (-1.3, -0.4), (-1.3, 0.75), 0.05, zs + 0.22, flanges=3, valve=True, supports=2)
    # flanc est : coffret électrique à grille + conduite
    b.box("plate2", (1.22, -0.55, zs + 0.24), (0.32, 0.5, 0.48), bev=0.012)
    b.vent_face("body", "plate", "dark", (1.22, -0.805, zs + 0.24), (1, 0, 0), (0, 0, 1), 0.24, 0.3, 4)
    pipe_run(b, (1.33, -0.2), (1.33, 0.85), 0.045, zs + 0.2, flanges=3, valve=False, supports=2)
    # avant : mur pare-éclats bas de part et d'autre des marches, caniveau d'énergie
    blast_wall(b, -hx + 0.42, -0.3, -hy + 0.03, 0.22, depth=0.32)
    blast_wall(b, 0.3, hx - 0.42, -hy + 0.03, 0.22, depth=0.32)
    stairs(b, 0.0, -hy + 0.02, 0.5, zs, 2)
    b.push(None, (0, 0, zs))
    floor_conduit(b, -0.9, 0.9, -hy + 0.62, glow=True, w=0.18)
    b.pop()
    for s in (-1, 1):
        hatch(b, (s * 0.95, -1.15, zs), 0.3, 0.36)
    big_hose(b, [(-0.8, 1.2, 0.42), (-1.5, 0.85, 0.32), (-1.58, -0.2, 0.28), (-1.4, -0.75, 0.36)], 0.06)
    return {"z_drum": zd}


def socle_21(b):
    """Époque 11 (Titane), 5×5 : dalle, barbette, condensateurs et transformateur (coin arrière gauche), générateur
    (coin arrière droit), radiateur à ailerons de titane (arrière), caisses et goulotte (flanc est), pompes et
    conduites (flanc ouest), mur pare-éclats et caniveaux d'énergie à l'avant."""
    side, hx, hy = 5, 2.5, 2.5 * TD
    zs = 0.2
    zd = Z_DRUM[21]
    slab(b, side, zs, cf=0.55, cb=0.22, deck=(12, 15))
    b.label("socle pivotant")
    barbette(b, 1.62, zs, zd, 22, rows=3, vents=8, glow_vents=8, vent_rows=2)
    # coin arrière gauche : 2 condensateurs + transformateur
    capacitor(b, (-2.0, 2.98, zs), 0.28, 1.0, glow_slits=2)
    capacitor(b, (-1.38, 3.1, zs), 0.22, 0.82, glow_slits=1)
    b.box("plate2", (-2.0, 2.25, zs + 0.32), (0.8, 0.55, 0.64), bev=0.02)
    b.plates_face("accent", (-2.0, 1.975, zs + 0.32), (1, 0, 0), (0, 0, 1), 2, 1, 0.76, 0.58, th=0.022, bolt_mat="bolt")
    b.vent_face("body", "plate", "dark", (-2.0, 1.945, zs + 0.32), (1, 0, 0), (0, 0, 1), 0.42, 0.32, 5)
    b.label("générateur et condensateurs")
    # coin arrière droit : générateur
    gx, gy = 1.85, 2.72
    b.box("plate2", (gx, gy, zs + 0.45), (1.2, 1.5, 0.9), bev=0.025)
    b.plates_face("plate", (gx, gy - 0.75, zs + 0.45), (1, 0, 0), (0, 0, 1), 3, 2, 1.16, 0.86, th=0.024, bolt_mat="bolt", tones=TONES)
    b.plates_face("accent", (gx - 0.6, gy, zs + 0.45), (0, -1, 0), (0, 0, 1), 3, 2, 1.46, 0.86, th=0.024,
                  bolt_mat="bolt")
    b.vent_face("body", "plate", "glow", (gx + 0.25, gy - 0.78, zs + 0.5), (1, 0, 0), (0, 0, 1), 0.36, 0.36, 5)
    b.grille_top("body", "grille", "dark", gx - 0.5, gx + 0.5, gy - 0.6, gy - 0.05, zs + 0.9, 8, along="x")
    b.fins("body", (gx, gy + 0.38, zs + 0.9), "x", 0.55, 0.2, 13, pitch=0.07)
    for s in (-1, 1):
        b.cyl("dark", (gx + s * 0.32, gy + 0.55, zs + 1.06), 0.075, 0.36, n=14, bev=0.006)
        b.cyl("plate", (gx + s * 0.32, gy + 0.55, zs + 1.25), 0.09, 0.04, n=14, bev=0.005)
    b.lamp("amber", "plate2", (gx - 0.3, gy - 0.765, zs + 0.78), (0.08, 0.06), axis="-y")
    b.lamp("glow", "plate2", (gx + 0.2, gy - 0.765, zs + 0.8), (0.16, 0.05), axis="-y")
    b.light((gx, gy - 0.9, zs + 0.6), EPOCH_GLOW[11], 40.0)
    # arrière : radiateur à ailerons de titane (signature d'époque, massive)
    radiator_block(b, (-0.05, 3.05, zs), (1.65, 0.75, 0.75), along="x", glow=True)
    for k in range(6):
        b.prism("accent", [(0.0, 0.0), (0.46, 0.0), (0.0, 0.34)], -0.017, 0.017, R=FIN_YZ,
                t=(-0.7 + k * 0.28, 2.76, zs + 0.75), bev=0.006)
    b.label("radiateurs")
    cable_bundle(b, (gx - 0.6, gy - 0.5, zs + 0.55), (1.05, 1.3, zd - 0.05), sag=0.15, n=3)
    hose_arc(b, (-1.0, 2.6, zs + 0.55), (-0.75, 1.42, zd - 0.1), 0.25, 0.055)
    hose_arc(b, (0.55, 2.7, zs + 0.6), (0.5, 1.55, zd - 0.1), 0.22, 0.05)
    b.label("câblage et conduits")
    # flanc est : 2 caisses + goulotte
    crate(b, (2.05, 0.35, zs), (0.66, 0.85, 0.52))
    crate(b, (2.05, -0.65, zs), (0.66, 0.85, 0.52))
    conveyor(b, (1.95, -0.15, zs + 0.6), (1.45, -0.15, zd - 0.02), 0.2)
    b.label("alimentation en munitions")
    # flanc ouest : 2 pompes et conduites
    pump(b, (-2.05, -1.1, zs), 0.18, 0.4)
    pump(b, (-2.05, 0.6, zs), 0.18, 0.4)
    pipe_run(b, (-2.35, -1.9), (-2.35, 1.6), 0.06, zs + 0.3, flanges=4, valve=True, supports=3)
    # avant : mur pare-éclats, marches, caniveaux d'énergie, bornes
    blast_wall(b, -hx + 0.6, -0.45, -hy + 0.03, 0.3, depth=0.38, lamps="glow")
    blast_wall(b, 0.45, hx - 0.6, -hy + 0.03, 0.3, depth=0.38, lamps="glow")
    stairs(b, 0.0, -hy + 0.02, 0.8, zs, 2)
    b.push(None, (0, 0, zs))
    floor_conduit(b, -1.5, 1.5, -hy + 0.75, glow=True, w=0.2)
    b.pop()
    manifold(b, -1.3, 1.3, -1.95, zs + 0.1, r=0.05, n_tees=4)
    for s in (-1, 1):
        tank_h(b, (s * 1.0, -2.38, zs), 0.15, 0.9)
    big_hose(b, [(1.3, 2.1, 0.75), (2.5, 1.6, 0.45), (2.62, -0.3, 0.34), (2.47, -1.9, 0.38), (1.6, -2.38, 0.37)], 0.085)
    big_hose(b, [(-1.45, 2.55, 0.6), (-2.55, 1.9, 0.45), (-2.64, 0.0, 0.34), (-2.5, -1.9, 0.38), (-1.6, -2.38, 0.37)],
             0.085)
    for s in (-1, 1):
        hatch(b, (s * 1.85, -2.1, zs), 0.4, 0.5)
    for s in (-1, 1):
        lamp_post(b, (s * 1.75, -hy + 0.7, zs), 0.26, glow="glow")
    return {"z_drum": zd}


def socle_29(b, piece=False):
    """Époque 15 (Légende), 6×6 : dalle, barbette haute, réserve d'énergie (4 cellules sous portique, coin arrière
    gauche), générateur lourd (coin arrière droit), radiateur (arrière), caisses et goulotte (flanc est), pompes et
    conduites (flanc ouest), mur pare-éclats, caniveaux d'énergie et bornes à l'avant. piece=True : niveau 30,
    deux lance-missiles aux coins avant (chanfreins)."""
    side, hx, hy = 6, 3.0, 3.0 * TD
    zs = 0.22
    zd = Z_DRUM[29]
    cf = 0.85
    slab(b, side, zs, cf=cf, cb=0.3, deck=(15, 19))
    b.label("socle pivotant")
    barbette(b, 2.0, zs, zd, 26, rows=3, vents=11, glow_vents=11, vent_rows=2)
    # coin arrière gauche : réserve d'énergie visible
    cells = [(-2.55, 3.68), (-1.92, 3.68), (-2.55, 3.0), (-1.92, 3.0)]
    for (x, y) in cells:
        capacitor(b, (x, y, zs), 0.27, 1.15, glow_slits=3)
    for (x0, y0) in ((-2.9, 2.62), (-1.58, 2.62), (-2.9, 4.04), (-1.58, 4.04)):
        b.box("body", (x0, y0, zs + 0.72), (0.08, 0.08, 1.44), bev=0.01)
        b.box("haz_y", (x0, y0, zs + 0.2), (0.085, 0.085, 0.16), bev=0.004)
    for yy in (2.62, 4.04):
        b.box("body", (-2.24, yy, zs + 1.42), (1.4, 0.08, 0.08), bev=0.01)
    for xx in (-2.9, -1.58):
        b.box("body", (xx, 3.33, zs + 1.42), (0.08, 1.5, 0.08), bev=0.01)
    b.label("réserve d'énergie visible")
    for (x, y) in cells[2:]:
        b.light((x, y - 0.35, zs + 0.7), EPOCH_GLOW[15], 35.0)
    # coin arrière droit : générateur lourd
    gx, gy = 2.2, 3.15
    b.box("plate2", (gx, gy, zs + 0.55), (1.3, 1.85, 1.1), bev=0.03)
    b.plates_face("plate", (gx, gy - 0.925, zs + 0.55), (1, 0, 0), (0, 0, 1), 3, 2, 1.26, 1.06, th=0.026, bolt_mat="bolt", tones=TONES)
    b.plates_face("plate", (gx - 0.65, gy, zs + 0.55), (0, -1, 0), (0, 0, 1), 4, 2, 1.8, 1.06, th=0.026, bolt_mat="bolt", tones=TONES)
    b.vent_face("body", "plate", "glow", (gx - 0.28, gy - 0.955, zs + 0.62), (1, 0, 0), (0, 0, 1), 0.4, 0.4, 6)
    b.vent_face("body", "plate", "glow", (gx + 0.28, gy - 0.955, zs + 0.62), (1, 0, 0), (0, 0, 1), 0.4, 0.4, 6)
    b.grille_top("body", "grille", "dark", gx - 0.5, gx + 0.5, gy - 0.8, gy - 0.1, zs + 1.1, 9, along="x",
                 glow_mat="glow")
    b.cyl("dark", (gx, gy - 0.45, zs + 1.13), 0.3, 0.02, n=24, bev=0)
    for k in range(5):
        a = TAU * k / 5
        b.box("plate", (gx + math.cos(a) * 0.14, gy - 0.45 + math.sin(a) * 0.14, zs + 1.15), (0.26, 0.07, 0.015),
              R=Rz(a + 0.4), bev=0)
    b.fins("body", (gx, gy + 0.45, zs + 1.1), "x", 0.7, 0.2, 14, pitch=0.075)
    for s in (-1, 1):
        b.cyl("dark", (gx + s * 0.4, gy + 0.75, zs + 1.3), 0.08, 0.4, n=14, bev=0.006)
        b.cyl("plate", (gx + s * 0.4, gy + 0.75, zs + 1.5), 0.1, 0.05, n=14, bev=0.005)
    for k in range(3):
        b.lamp("amber" if k == 1 else "glow", "plate2", (gx - 0.45 + k * 0.45, gy - 0.955, zs + 0.98), (0.1, 0.05),
               axis="-y")
    b.light((gx, gy - 1.05, zs + 0.6), EPOCH_GLOW[15], 45.0)
    b.label("générateur")
    # arrière : radiateur et gaines
    radiator_block(b, (-0.2, 3.62, zs), (2.2, 0.85, 0.85), along="x", glow=True)
    b.label("radiateurs")
    hose_arc(b, (-1.55, 3.2, zs + 0.7), (-1.15, 1.75, zd - 0.12), 0.25, 0.065)
    hose_arc(b, (0.9, 3.25, zs + 0.7), (0.9, 1.85, zd - 0.12), 0.22, 0.065)
    cable_bundle(b, (gx - 0.65, gy - 0.6, zs + 0.7), (1.45, 1.42, zd - 0.06), sag=0.18, n=4)
    cable_bundle(b, (-1.6, 2.7, zs + 0.9), (-1.42, 1.42, zd - 0.06), sag=0.15, n=3)
    b.label("câblage et conduits")
    # flanc est : 3 caisses + goulotte
    for yy in (0.95, -0.05, -1.05):
        crate(b, (2.5, yy, zs), (0.72, 0.88, 0.6))
    conveyor(b, (2.4, 0.45, zs + 0.68), (1.85, 0.45, zd - 0.02), 0.24)
    b.label("alimentation en munitions")
    # flanc ouest : 3 pompes et conduites
    for yy in (-1.45, 0.0, 1.45):
        pump(b, (-2.5, yy, zs), 0.2, 0.45)
    pipe_run(b, (-2.85, -2.3), (-2.85, 2.0), 0.065, zs + 0.3, flanges=5, valve=True, supports=4)
    # avant : mur pare-éclats, marches, caniveaux d'énergie lumineux, bornes
    blast_wall(b, -hx + cf + 0.02, -0.55, -hy + 0.03, 0.36, depth=0.44, lamps="glow")
    blast_wall(b, 0.55, hx - cf - 0.02, -hy + 0.03, 0.36, depth=0.44, lamps="glow")
    stairs(b, 0.0, -hy + 0.02, 1.0, zs, 2)
    b.push(None, (0, 0, zs))
    floor_conduit(b, -1.9, 1.9, -hy + 0.85, glow=True, w=0.26)
    b.pop()
    for s in (-1, 1):
        tank_h(b, (s * 1.2, -2.92, zs), 0.18, 1.3)
    big_hose(b, [(1.6, 2.3, 0.8), (2.6, 2.05, 0.6), (3.08, 1.45, 0.4), (3.12, -0.2, 0.36), (3.05, -1.9, 0.4),
                 (2.55, -2.62, 0.46), (2.0, -2.92, 0.46)], 0.1)
    big_hose(b, [(-1.55, 2.55, 0.66), (-2.95, 2.0, 0.55), (-3.12, 0.7, 0.42), (-3.12, -1.0, 0.42), (-2.92, -2.3, 0.46),
                 (-2.0, -2.92, 0.46)], 0.1)
    manifold(b, -1.6, 1.6, -2.35, zs + 0.1, r=0.06, n_tees=5)
    for s in (-1, 1):
        hatch(b, (s * 2.25, -2.45, zs), 0.45, 0.55)
    for s in (-1, 1):
        lamp_post(b, (s * 2.05, -hy + 0.95, zs), 0.3, glow="glow")
        lamp_post(b, (s * 0.75, -hy + 0.95, zs), 0.3)
    if piece:
        missile_pods(b, zs, hx, hy, cf)
    return {"z_drum": zd}


def missile_pods(b, zs, hx, hy, cf):
    """Pièce du niveau 30 : deux lance-missiles blindés aux coins avant, posés sur les chanfreins (hors du balayage
    de la tête : toujours visibles, F46), ogives à lueur blanc doré."""
    for s in (-1, 1):
        x = s * (hx - 0.5)
        y = -hy + 0.62
        b.push(Rz(s * 0.35), (x, y, 0.0))
        b.box("plate2", (0, 0, 0.12), (0.8, 0.85, 0.24), bev=0.02)
        b.hazard_band("haz_y", "haz_k", (-0.36, -0.43, 0.12), (0.36, -0.43, 0.12), width=0.12, th=0.01, normal="-y")
        b.cyl("body", (0, 0.05, 0.3), 0.3, 0.12, n=24, bev=0.01)
        b.push(Rx(0.32), (0, 0.05, 0.36))
        b.box("plate", (0, 0, 0.26), (0.66, 0.62, 0.46), bev=0.025)
        b.plates_face("plate2", (0.33, 0, 0.26), (0, 1, 0), (0, 0, 1), 2, 1, 0.58, 0.42, th=0.02, bolt_mat="bolt")
        b.plates_face("plate2", (-0.33, 0, 0.26), (0, -1, 0), (0, 0, 1), 2, 1, 0.58, 0.42, th=0.02, bolt_mat="bolt")
        b.bolts_rect("bolt", -0.31, 0.31, -0.29, 0.29, 0.49, r=0.02, inset=0.05, n=(4, 4))
        for i in range(3):
            for j in range(2):
                px, pz = -0.2 + i * 0.2, 0.15 + j * 0.2
                b.cyl("dark", (px, -0.312, pz), 0.075, 0.03, axis="y", n=14, bev=0)
                b.cyl("accent", (px, -0.31, pz), 0.085, 0.02, axis="y", n=14, bev=0.004)
                b.cyl("glow", (px, -0.322, pz), 0.04, 0.012, axis="y", n=10, bev=0)
        b.pop()
        b.pop()
        b.light((x, y - 0.4, 0.5), EPOCH_GLOW[15], 25.0)


# ------------------------------------------------------------------------------------------------
# Têtes (repère local : canons vers +Y ; z absolu)
# ------------------------------------------------------------------------------------------------
def shroud(b, c, r, L, holes_rows=5, holes_per_row=8):
    """Chemise de refroidissement perforée autour d'un faisceau (axe +Y)."""
    x, y0, z = c
    b.cyl("plate", (x, y0 + L / 2, z), r, L, axis="y", n=24, bev=0.008)
    for i in range(holes_rows):
        yy = y0 + L * (i + 0.5) / holes_rows
        for k in range(holes_per_row):
            a = TAU * (k + 0.5 * (i % 2)) / holes_per_row
            # demi-cercle visible du dessus seulement (inutile de percer le dessous)
            if math.sin(a) < -0.3:
                continue
            p = (x + math.cos(a) * (r + 0.002), yy, z + math.sin(a) * (r + 0.002))
            b.cyl("dark", p, 0.028, 0.02, axis=(math.cos(a), 0.0, math.sin(a)), n=8, bev=0)
    for t in (0.0, 1.0):
        b.cyl("body", (x, y0 + L * t, z), r + 0.025, 0.06, axis="y", n=24, bev=0.006)


def trunnion(b, x, y, z, w, h, d):
    """Berceau de canon : bloc, tourillons latéraux boulonnés."""
    b.box("plate2", (x, y, z), (w, d, h), bev=0.02)
    for s in (-1, 1):
        b.cyl("body", (x + s * (w / 2 + 0.03), y, z), h * 0.32, 0.06, axis="x", n=16, bev=0.006)
        for k in range(6):
            a = TAU * k / 6
            b.bolt("bolt", (x + s * (w / 2 + 0.065), y + math.cos(a) * h * 0.22, z + math.sin(a) * h * 0.22), r=0.016,
                   h=0.012, axis=(s, 0.0, 0.0))


def drum_mag(b, c, r, L, belt_to):
    """Tambour-chargeur latéral (axe Y) : fût cerclé, couvercles boulonnés, bande de danger, bande de cartouches."""
    x, y, z = c
    b.cyl("plate2", (x, y, z), r, L, axis="y", n=28, bev=0.012)
    for t in (-0.42, -0.14, 0.14, 0.42):
        b.cyl("body", (x, y + t * L, z), r + 0.02, 0.05, axis="y", n=28, bev=0.006)
    for s in (-1, 1):
        b.cyl("plate", (x, y + s * (L / 2 + 0.02), z), r * 0.85, 0.04, axis="y", n=24, bev=0.008)
        for k in range(8):
            a = TAU * k / 8
            b.bolt("bolt", (x + math.cos(a) * r * 0.7, y + s * (L / 2 + 0.045), z + math.sin(a) * r * 0.7), r=0.018,
                   h=0.012, axis=(0.0, float(s), 0.0))
    b.hazard_band("haz_y", "haz_k", (x - r * 0.6, y - L * 0.28, z + r + 0.005), (x - r * 0.6, y + L * 0.28, z + r + 0.005),
                  width=r * 0.5, th=0.01, normal="z")
    b.ammo_belt("case", "dark", [(x, y + L * 0.3, z + r * 0.9), belt_to], w=0.11)


def secondary_turret(b, c, scale=1.0):
    """Tourelle secondaire (défense rapprochée) : couronne, caisson, 2 canons, viseur à lueur d'époque."""
    x, y, z = c
    k = scale
    b.cyl("plate2", (x, y, z + 0.05 * k), 0.24 * k, 0.1 * k, n=24, bev=0.008)
    nb = 10
    for i in range(nb):
        a = TAU * i / nb
        b.bolt("bolt", (x + math.cos(a) * 0.2 * k, y + math.sin(a) * 0.2 * k, z + 0.1 * k), r=0.016)
    b.box("plate", (x, y, z + 0.2 * k), (0.34 * k, 0.4 * k, 0.2 * k), bev=0.015)
    b.box("body", (x, y + 0.02 * k, z + 0.31 * k), (0.26 * k, 0.3 * k, 0.04 * k), bev=0.008)
    for s in (-1, 1):
        b.cyl("gun", (x + s * 0.07 * k, y + 0.45 * k, z + 0.2 * k), 0.026 * k, 0.55 * k, axis="y", n=10, bev=0)
        b.cyl("body", (x + s * 0.07 * k, y + 0.26 * k, z + 0.2 * k), 0.045 * k, 0.14 * k, axis="y", n=12, bev=0.005)
        b.cyl("dark", (x + s * 0.07 * k, y + 0.725 * k, z + 0.2 * k), 0.032 * k, 0.03 * k, axis="y", n=10, bev=0)
    b.box("glow", (x + 0.1 * k, y + 0.205 * k, z + 0.25 * k), (0.09 * k, 0.012, 0.06 * k), bev=0)
    b.bolts_rect("bolt", x - 0.15 * k, x + 0.15 * k, y - 0.18 * k, y + 0.18 * k, z + 0.3 * k, r=0.016, inset=0.04)


def sensor(b, c, r, glow=True):
    """Viseur (télémètre) : fût, dôme d'accent, lentille lumineuse vers l'avant, visière."""
    x, y, z = c
    b.cyl("plate2", (x, y, z + 0.06), r, 0.12, n=24, bev=0.01)
    b.sphere("accent", (x, y, z + 0.12), r * 0.92, n=20, m=10, scale=(1, 1, 0.7))
    b.cyl("dark", (x, y + r * 0.8, z + 0.17), r * 0.42, 0.1, axis="y", n=16, bev=0.006)
    if glow:
        b.cyl("glow", (x, y + r * 0.86, z + 0.17), r * 0.28, 0.02, axis="y", n=16, bev=0)
    b.box("plate", (x, y + r * 0.75, z + 0.27), (r * 1.0, r * 0.4, 0.03), R=Rx(-0.3), bev=0.006)
    b.cyl("body", (x - r * 0.6, y - r * 0.4, z + 0.32), 0.03, 0.22, n=8, bev=0.004)


def head_11(b, z0):
    """Époque 6 : caisson blindé, 2 mitrailleuses à 4 canons (jumelées) sous chemises perforées, bouclier frontal,
    moteur électrique bobiné à l'arrière, 2 isolateurs dorsaux et éclateur (arc cyan), caisse de munitions à gauche."""
    zt = z0 + 0.66
    # plateau tournant
    b.cyl("plate2", (0, 0, z0 + 0.04), 0.72, 0.08, n=48, bev=0.01)
    for i in range(16):
        a = TAU * i / 16
        b.bolt("bolt", (math.cos(a) * 0.67, math.sin(a) * 0.67, z0 + 0.085), r=0.02)
    # caisson (octogone en plan, chanfreins avant)
    hull = [(-0.58, -0.6), (0.58, -0.6), (0.62, -0.3), (0.62, 0.38), (0.42, 0.6), (-0.42, 0.6), (-0.62, 0.38),
            (-0.62, -0.3)]
    b.prism("body", hull, z0 + 0.08, zt, bev=0.03)
    b.frustum("plate", [(-0.6, -0.58), (0.6, -0.58), (0.6, 0.36), (0.4, 0.58), (-0.4, 0.58), (-0.6, 0.36)], zt,
              zt + 0.1, 0.9, bev=0.02)
    b.plates_top("plate2", -0.45, 0.45, -0.45, 0.35, zt + 0.1, 4, 4, th=0.025, gap=0.03, bolt_mat="bolt")
    for s in (-1, 1):
        # normale sortante = u × v : u = (0, s, 0) pour la face x = s (correctif : tôles tournées vers l'intérieur)
        b.plates_face("plate", (s * 0.62, -0.1, z0 + 0.37), (0, s, 0), (0, 0, 1), 3, 2,
                      0.9, 0.52, th=0.025, bolt_mat="bolt", tones=TONES)
    b.label("tête à canons")
    # bouclier frontal incliné (3 plaques), meurtrières des canons
    b.label("blindage frontal")
    for px, w in ((0.0, 0.42), (-0.5, 0.2), (0.5, 0.2)):
        b.box("plate", (px, 0.66, z0 + 0.36), (w, 0.08, 0.6), R=Rx(-0.35), bev=0.02)
        b.bolts_line("bolt", (px - w / 2 + 0.05, 0.62, z0 + 0.62), (px + w / 2 - 0.05, 0.62, z0 + 0.62), 2, r=0.018,
                     axis=(0, 0.94, 0.34), h=0.012)
    # deux mitrailleuses à 4 canons, chemises perforées, berceaux
    b.label("canons jumelés")
    b.label("refroidissement des canons")
    zg = z0 + 0.36
    for s in (-1, 1):
        xg = s * 0.36
        trunnion(b, xg, 0.6, zg, 0.2, 0.22, 0.2)
        b.gatling("gun", "body", "dark", (xg, 0.62, zg), 4, 0.066, 0.034, 0.74, muzzle_mat="plate")
        shroud(b, (xg, 0.66, zg), 0.135, 0.42, holes_rows=4, holes_per_row=8)
    # moteur électrique bobiné (arrière), axe X
    zm = z0 + 0.36
    b.cyl("plate2", (0, -0.8, zm), 0.24, 0.8, axis="x", n=28, bev=0.012)
    for k in range(9):
        b.torus("copper", (-0.32 + k * 0.08, -0.8, zm), 0.245, 0.024, axis="x", n=28, m=6)
    for s in (-1, 1):
        b.cyl("body", (s * 0.42, -0.8, zm), 0.2, 0.05, axis="x", n=24, bev=0.008)
        for k in range(6):
            a = TAU * k / 6
            b.bolt("bolt", (s * 0.45, -0.8 + math.cos(a) * 0.14, zm + math.sin(a) * 0.14), r=0.016, h=0.012,
                   axis=(float(s), 0.0, 0.0))
    b.box("plate2", (0, -0.62, zm + 0.26), (0.36, 0.2, 0.14), bev=0.01)
    for s in (-1, 1):
        b.box("glow", (s * 0.09, -0.725, zm + 0.26), (0.1, 0.012, 0.08), bev=0)
    # isolateurs dorsaux et éclateur
    for s in (-1, 1):
        zz = zt + 0.12
        for k in range(5):
            b.cyl("accent", (s * 0.26, -0.3, zz + 0.04), 0.075 if k % 2 == 0 else 0.055, 0.075, n=16, bev=0.008)
            zz += 0.075
        b.cyl("copper", (s * 0.26, -0.3, zz + 0.06), 0.022, 0.12, n=8, bev=0)
        b.sphere("copper", (s * 0.2, -0.3, zz + 0.12), 0.035, n=10, m=6)
    b.box("glow", (0, -0.3, zt + 0.12 + 0.375 + 0.12), (0.34, 0.05, 0.07), bev=0)
    # câbles moteur -> canons
    for s in (-1, 1):
        b.cable("rubber", (s * 0.15, -0.6, zm + 0.2), (s * 0.4, 0.4, zt + 0.12), sag=-0.06, r=0.022)
    # caisse de munitions (flanc gauche) et bande vers la mitrailleuse gauche
    b.label("alimentation en munitions")
    b.push(None, (-0.82, -0.05, z0 + 0.1))
    b.box("plate2", (0, 0, 0.22), (0.26, 0.6, 0.44), bev=0.015)
    b.hazard_band("haz_y", "haz_k", (-0.13, -0.26, 0.3), (-0.13, 0.26, 0.3), width=0.1, th=0.01, normal="-x")
    b.box("plate", (0, 0, 0.455), (0.24, 0.56, 0.03), bev=0.008)
    b.bolts_rect("bolt", -0.1, 0.1, -0.26, 0.26, 0.47, r=0.016, inset=0.03, n=(2, 3))
    b.pop()
    b.ammo_belt("case", "dark", [(-0.75, 0.2, z0 + 0.55), (-0.55, 0.45, z0 + 0.5), (-0.4, 0.55, zg + 0.08)], w=0.09)
    # trappe et poignée sur le dessus
    b.cyl("plate", (0.2, -0.15, zt + 0.15), 0.12, 0.04, n=20, bev=0.008)
    b.box("dark", (0.2, -0.15, zt + 0.18), (0.14, 0.025, 0.02), bev=0)
    b.light((0, -0.3, zt + 0.6), EPOCH_GLOW[6], 20.0)


def head_21(b, z0):
    """Époque 11 : caisson blindé à glacis, gros faisceau de 6 canons sous chemise perforée, tambour-chargeur à
    droite, tourelle secondaire (arrière gauche), viseur, radiateur dorsal à ailerons (titane) et lignes lumineuses,
    gaines de refroidissement, câblage."""
    zt = z0 + 0.95
    b.cyl("plate2", (0, 0, z0 + 0.05), 1.25, 0.1, n=64, bev=0.012)
    for i in range(24):
        a = TAU * i / 24
        b.bolt("bolt", (math.cos(a) * 1.18, math.sin(a) * 1.18, z0 + 0.105), r=0.022)
    hull = [(-0.92, -1.0), (0.92, -1.0), (1.0, -0.7), (1.0, 0.55), (0.7, 0.95), (-0.7, 0.95), (-1.0, 0.55), (-1.0, -0.7)]
    b.prism("body", hull, z0 + 0.1, zt, bev=0.035)
    # glacis avant incliné
    b.box("plate", (0, 0.95, z0 + 0.55), (1.3, 0.12, 0.8), R=Rx(-0.45), bev=0.025)
    b.bolts_line("bolt", (-0.55, 0.88, z0 + 0.88), (0.55, 0.88, z0 + 0.88), 6, r=0.02, axis=(0, 0.9, 0.43), h=0.014)
    # dessus : tôles, trappes, grilles
    b.frustum("plate", [(-0.95, -0.95), (0.95, -0.95), (0.95, 0.5), (0.65, 0.88), (-0.65, 0.88), (-0.95, 0.5)], zt,
              zt + 0.1, 0.94, bev=0.02)
    b.plates_top("plate2", -0.75, 0.75, -0.85, 0.55, zt + 0.1, 4, 4, th=0.025, gap=0.03, bolt_mat="bolt",
                 skip={(0, 0), (1, 0)})
    for s in (-1, 1):
        b.plates_face("accent" if s < 0 else "plate", (s * 1.0, -0.1, z0 + 0.55), (0, s, 0), (0, 0, 1), 3, 2, 1.2,
                      0.8, th=0.026, bolt_mat="bolt")
    b.label("tête à canons")
    b.label("blindage frontal")
    # faisceau principal : 6 canons, chemise perforée, berceau
    zg = z0 + 0.5
    trunnion(b, 0.0, 1.0, zg, 0.5, 0.42, 0.3)
    b.gatling("gun", "body", "dark", (0, 1.05, zg), 6, 0.14, 0.056, 1.35, muzzle_mat="plate")
    shroud(b, (0, 1.12, zg), 0.29, 0.7, holes_rows=5, holes_per_row=10)
    for k in range(3):
        b.box("glow", (0, 1.25 + k * 0.17, zg + 0.255), (0.11, 0.065, 0.012), bev=0)
    b.label("canons jumelés")
    b.label("refroidissement des canons")
    # tambour-chargeur à droite
    drum_mag(b, (1.25, 0.05, z0 + 0.5), 0.34, 1.0, (0.3, 1.0, zg + 0.15))
    b.box("plate2", (1.05, 0.05, z0 + 0.25), (0.3, 0.7, 0.3), bev=0.015)
    b.label("chargeur automatique")
    # tourelle secondaire (arrière gauche) et viseur (avant gauche)
    secondary_turret(b, (-0.5, -0.45, zt + 0.12), 1.0)
    b.label("tourelle secondaire")
    sensor(b, (-0.5, 0.35, zt + 0.12), 0.2)
    b.label("viseur")
    # radiateur dorsal : bloc d'ailettes + ailerons triangulaires de titane (signature de l'époque)
    rx, ry = 0.45, -0.55
    b.box("plate2", (rx, ry, zt + 0.17), (0.6, 0.6, 0.14), bev=0.01)
    b.fins("body", (rx, ry, zt + 0.24), "x", 0.52, 0.32, 8, pitch=0.07)
    for k in range(3):
        b.prism("accent", [(0.0, 0.0), (0.55, 0.0), (0.0, 0.42)], -0.02, 0.02, R=FIN_YZ,
                t=(rx - 0.22 + k * 0.22, ry - 0.3, zt + 0.24), bev=0.006)
    for k in range(2):
        b.box("glow", (rx - 0.13 + k * 0.26, ry - 0.31, zt + 0.21), (0.2, 0.012, 0.07), bev=0)
        b.box("glow", (rx + 0.31, ry - 0.13 + k * 0.26, zt + 0.21), (0.012, 0.2, 0.07), bev=0)
    b.label("radiateurs")
    # lignes lumineuses sur les flancs (chenillard) et voyants
    for s in (-1, 1):
        for k in range(3):
            b.box("glow", (s * 0.83, -0.65 + k * 0.42, zt + 0.108), (0.07, 0.3, 0.012), bev=0)
    b.lamp("amber", "plate2", (-0.85, -1.005, z0 + 0.7), (0.08, 0.05), axis="-y")
    # gaines de refroidissement radiateur -> chemise, câbles
    hose_arc(b, (rx + 0.25, ry + 0.2, zt + 0.25), (0.15, 0.95, zg + 0.22), 0.3, 0.045, pitch=0.065)
    hose_arc(b, (rx - 0.2, ry + 0.2, zt + 0.25), (-0.15, 0.95, zg + 0.22), 0.35, 0.045, pitch=0.065)
    for s in (-1, 1):
        b.cable("rubber", (s * 0.85, -0.9, zt - 0.05), (s * 0.85, 0.5, zt - 0.05), sag=-0.03, r=0.025)
    b.label("câblage et conduits")
    # bustle arrière : coffre boulonné, grille
    b.box("plate2", (0, -1.1, z0 + 0.5), (1.4, 0.2, 0.7), bev=0.02)
    b.vent_face("body", "plate", "dark", (0, -1.205, z0 + 0.5), (1, 0, 0), (0, 0, 1), 0.8, 0.45, 6)
    b.light((0, 0.0, zt + 0.5), EPOCH_GLOW[11], 25.0)


def head_29(b, z0):
    """Époque 15 : forteresse tournante. Caisson à blindage espacé (plaques multiples), 2 faisceaux de 6 canons sous
    chemises, 2 tambours-chargeurs, 2 tourelles secondaires, viseur, couronne de radiateurs en or blanc à fentes
    lumineuses, cœur d'énergie visible sous grille, gaines et câbles."""
    zt = z0 + 1.15
    b.cyl("plate2", (0, 0, z0 + 0.06), 1.55, 0.12, n=72, bev=0.012)
    for i in range(30):
        a = TAU * i / 30
        b.bolt("bolt", (math.cos(a) * 1.48, math.sin(a) * 1.48, z0 + 0.125), r=0.024)
    hull = [(-1.2, -1.3), (1.2, -1.3), (1.32, -1.0), (1.32, 0.75), (0.95, 1.2), (-0.95, 1.2), (-1.32, 0.75),
            (-1.32, -1.0)]
    b.prism("body", hull, z0 + 0.12, zt, bev=0.04)
    b.label("tête à canons")
    # glacis avant
    b.box("plate", (0, 1.22, z0 + 0.62), (1.8, 0.14, 0.95), R=Rx(-0.42), bev=0.03)
    b.bolts_line("bolt", (-0.8, 1.13, z0 + 1.0), (0.8, 1.13, z0 + 1.0), 9, r=0.022, axis=(0, 0.91, 0.41), h=0.014)
    b.label("blindage frontal")
    # blindage espacé sur les flancs (2 couches : tôles du caisson + plaques sur entretoises)
    for s in (-1, 1):
        b.plates_face("plate2", (s * 1.32, -0.15, z0 + 0.62), (0, s, 0), (0, 0, 1), 4, 2, 1.7, 0.95, th=0.026,
                      bolt_mat="bolt")
        for k in range(3):
            yy = -0.75 + k * 0.6
            b.box("plate", (s * 1.42, yy, z0 + 0.66), (0.06, 0.5, 0.7), bev=0.02)
            for zz in (0.42, 0.9):
                b.cyl("body", (s * 1.375, yy, z0 + zz), 0.03, 0.06, axis="x", n=8, bev=0)
            b.bolts_line("bolt", (s * 1.455, yy - 0.18, z0 + 0.95), (s * 1.455, yy + 0.18, z0 + 0.95), 3, r=0.018,
                         axis=(float(s), 0, 0), h=0.012)
            b.bolts_line("bolt", (s * 1.455, yy - 0.18, z0 + 0.37), (s * 1.455, yy + 0.18, z0 + 0.37), 3, r=0.018,
                         axis=(float(s), 0, 0), h=0.012)
    b.label("blindage à plaques multiples")
    # dessus : tôles, trappes
    b.frustum("plate", [(-1.25, -1.25), (1.25, -1.25), (1.25, 0.7), (0.9, 1.12), (-0.9, 1.12), (-1.25, 0.7)], zt,
              zt + 0.1, 0.95, bev=0.02)
    b.plates_top("plate2", -1.05, 1.05, -1.1, 0.75, zt + 0.1, 5, 5, th=0.025, gap=0.03, bolt_mat="bolt")
    # 2 faisceaux de 6 canons, chemises, berceaux
    zg = z0 + 0.6
    for s in (-1, 1):
        xg = s * 0.62
        trunnion(b, xg, 1.25, zg, 0.48, 0.44, 0.3)
        b.gatling("gun", "body", "dark", (xg, 1.3, zg), 6, 0.13, 0.052, 1.55, muzzle_mat="plate")
        shroud(b, (xg, 1.38, zg), 0.27, 0.8, holes_rows=6, holes_per_row=10)
        # fentes de chaleur lumineuses sur la chemise (dessus)
        for k in range(3):
            b.box("glow", (xg, 1.5 + k * 0.2, zg + 0.235), (0.12, 0.07, 0.012), bev=0)
    b.label("canons jumelés")
    b.label("refroidissement des canons")
    # 2 tambours-chargeurs sur les flancs
    for s in (-1, 1):
        drum_mag(b, (s * 1.78, 0.1, z0 + 0.62), 0.4, 1.25, (s * 0.85, 1.25, zg + 0.18))
        b.box("plate2", (s * 1.55, 0.1, z0 + 0.32), (0.3, 0.9, 0.36), bev=0.015)
    b.label("chargeur automatique")
    # couronne de radiateurs (or blanc) à l'arrière du dessus, fentes lumineuses entre les blocs
    zc = zt + 0.13
    nblk = 7
    for k in range(nblk):
        a = math.pi + math.pi * (k + 0.5) / nblk          # demi-cercle arrière
        cx, cy = math.cos(a) * 0.95, math.sin(a) * 0.95 - 0.1
        b.push(Rz(a + math.pi / 2), (cx, cy, zc))
        b.box("plate2", (0, 0, 0.05), (0.36, 0.3, 0.1), bev=0.01)
        b.fins("accent", (0, 0, 0.1), "x", 0.26, 0.42 + 0.06 * (k % 2), 5, pitch=0.065, th=0.034)
        b.box("glow", (0, -0.16, 0.07), (0.26, 0.012, 0.07), bev=0)
        b.pop()
    b.label("radiateurs")
    # cœur d'énergie visible : grille centrale au-dessus d'un noyau lumineux (petits foyers séparés par les barreaux)
    b.box("plate2", (0.0, -0.35, zc + 0.06), (0.8, 0.6, 0.12), bev=0.012)
    b.grille_top("accent", "grille", "dark", -0.32, 0.32, -0.6, -0.1, zc + 0.12, 5, along="y", glow_mat="glow")
    b.label("réserve d'énergie visible")
    # 2 tourelles secondaires (avant gauche et avant droite du dessus) et viseur central
    for s in (-1, 1):
        secondary_turret(b, (s * 0.72, 0.35, zt + 0.12), 1.15)
    b.label("tourelles secondaires")
    sensor(b, (0.0, 0.45, zt + 0.12), 0.24)
    b.label("viseur")
    b.label("générateur ou condensateur")
    # gaines et câbles
    for s in (-1, 1):
        hose_arc(b, (s * 0.5, -0.9, zc + 0.15), (s * 0.62, 1.15, zg + 0.24), 0.35, 0.05, pitch=0.065)
        b.cable("rubber", (s * 1.15, -1.15, zt - 0.05), (s * 1.15, 0.6, zt - 0.05), sag=-0.03, r=0.026)
        b.cable("cable_r", (s * 1.08, -1.15, zt - 0.05), (s * 1.08, 0.6, zt - 0.05), sag=-0.03, r=0.022)
    b.label("câblage et conduits")
    # bustle arrière : coffre, grilles lumineuses, voyants
    b.box("plate2", (0, -1.42, z0 + 0.6), (2.0, 0.26, 0.85), bev=0.025)
    for s in (-1, 1):
        b.vent_face("body", "plate", "glow", (s * 0.5, -1.555, z0 + 0.6), (1, 0, 0), (0, 0, 1), 0.6, 0.5, 6)
    b.lamp("amber", "plate2", (0.0, -1.56, z0 + 0.85), (0.1, 0.05), axis="-y")
    for s in (-1, 1):
        for k in range(4):
            b.box("glow", (s * 1.12, -0.95 + k * 0.42, zt + 0.108), (0.08, 0.3, 0.012), bev=0)
    b.light((0, -0.35, zt + 0.6), EPOCH_GLOW[15], 30.0)


HEADS = {11: head_11, 21: head_21, 29: head_29, 30: head_29}
SOCLES = {11: socle_11, 21: socle_21, 29: socle_29, 30: lambda b: socle_29(b, piece=True)}
# échelle de la tête (modélisée à l'échelle 1, agrandie autour de son pied : la masse de la tête croît avec l'ère)
K_HEAD = {11: 1.2, 21: 1.15, 29: 1.15, 30: 1.15}


def build(variant):
    """Construit la géométrie d'une variante ; renvoie (constructeur, angle de rotation de la tête)."""
    v = VARIANTS[variant]
    lv = v["level"]
    b = G.B(seed=lv)
    if v["part"] == "socle":
        SOCLES[lv](b)
        return b, 0.0
    b.push(G.np.eye(3) * K_HEAD[lv], (0.0, 0.0, Z_DRUM[lv]))
    HEADS[lv](b, 0.0)
    b.pop()
    return b, DIR_ANGLE[v["dir"]]


def systems(level):
    """Inventaire des systèmes fonctionnels (socle + tête) du niveau."""
    lv = 29 if level == 30 else level
    b1 = G.B()
    SOCLES[lv](b1)
    HEADS[lv](b1, 0.0)
    return b1.systems
