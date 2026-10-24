"""ÉCLAT DE TIR 2D PAR ÂGE de la mitrailleuse (lot A4, 24/10/2026) : une couche lumineuse (draw_as_glow, additive) de
attacking_animation, posée au bout des canons de CHAQUE direction de la tête (64 ou 4 : même repli que les têtes).
Python 3.9, sans Blender.

Appelé par feuilles.py (fin de chaque âge) : l'éclat se RÉGÉNÈRE avec les feuilles, donc passe tout seul à 64 directions
quand un âge y passe (production A3). Seul :
    py -3.9 tools/render/pieces/levels/gun_e/eclat_tir.py --planche DOSSIER [--ages 2,5,15] [--zoom 2] [--image A|B]
        (planche de contrôle : chaque direction, pose en couleur + l'éclat montré en jeu, depuis graphics/levels/gun ;
        --image : l'autre dessin, pour comparer)
    py -3.9 tools/render/pieces/levels/gun_e/eclat_tir.py --controle
        (régénère chaque feuille d'éclat dans un dossier jetable et la compare octet à octet à celle du mod)

POSITIONS MESURÉES SUR LES FEUILLES (pas calculées) : pour chaque direction, la cellule de la feuille de tête (couche
principale, hr) est découpée et la bouche est mesurée par la MÊME règle que feuilles.bouche_u / eclat64.py (rangées de
lignes dont le pixel opaque le plus avancé, dans le plan du sol déprojeté, est à TOL_CANON px du plus avancé) ; on garde
ici les BOUTS des deux rangées extrêmes (deux canons : deux éclats ; une seule rangée : un éclat), dont le milieu EST la
bouche de feuilles.py (contrôlé à chaque passage, sinon refus). Exception dite : une direction ÉCARTÉE du réglage de
l'éclat par feuilles.ajuste_robuste (bouche mal mesurée : coin de bouclier, âge 2) n'a pas de mesure fiable ; l'éclat y
est posé au point du réglage (éclat visible du moteur moins la marge vanilla), le point vert REGARDÉ pour ces
directions (D-12, planches eclat64 --couleur --seules-ecartees). Le mode de chaque direction est écrit dans sprites.json
(outils.eclat_tir.modes).

FORME ET COULEUR PAR ÂGE : couleurs du registre commun ages.py (FOYER[e].rgb : corps de la flamme ; FOYER[e].rgb2, ou
la couleur de catalogue de la famille FAMILLES[e], pour l'accent du bord ; cœur = foyer mêlé de blanc) ; forme par âge
(FORMES : cône, pointes, anneau, arcs), à la taille de l'âge (emprise / 2). L'éclat tourne avec la tête : son axe suit le
tir de la direction (feuilles.unite_pose) et sa longueur est raccourcie par la vue à 45° (plan du sol, PROJ_IMAGE).

UNE SEULE IMAGE PAR DIRECTION (correction M-1 du lot A4, F149) : le moteur ne dessine la couche d'attacking_animation
d'une mitrailleuse qu'UN tick par coup (cadence 6 ticks) ; avec deux images (A pleine, B réduite), seule l'image
d'indice 1 (B) paraissait, jamais A (copie jetable A rouge / B vert, 56 captures sur 56 en vert) : pas de scintillement,
et A ne servait qu'à occuper la mémoire vidéo. Le dessin gardé est IMAGE_JEU (« A » : la pleine, choix PROVISOIRE de
l'agent, sans verdict du Directeur Créatif ; « B » : la réduite, celle qu'on voyait en jeu avant la correction). La tête
garde une image, sans repeat_count (gun.lua refuse un éclat de plus d'une image).

FEUILLE : normale seulement (32 px/tuile, pas de hr_version : une lueur douce n'a pas besoin de 64 px/tuile et la
feuille hr des âges 13 à 15 dépasserait 8 192 px) ; dessinée à 64 px/tuile puis réduite 2 × 2 en additif
(fo_post.downsample2_additive), codée comme les autres lueurs (RGB = c / max, A = max). Images dans l'ordre d'une
RotatedAnimation : image i = direction (une image par direction), rangées de line_length images (1 à 4 directions :
une colonne N, E, S, O, F123 ; 8 à 64 à 64 directions, au plus 8 192 px de côté, F144).
Cellule commune = union des éclats de toutes les directions ; le moteur range les images ROGNÉES (F147) : le vide de
la cellule ne coûte pas de mémoire vidéo.
"""
import argparse
import hashlib
import json
import math
import os
import shutil
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
sys.path.insert(0, RENDER)
import ages  # noqa: E402
import fo_post as P  # noqa: E402
import feuilles as FE  # noqa: E402

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

FRAMES = 1              # une image par direction : le moteur n'en montre qu'une par coup (F149, correction M-1)
# dessin de cette image : "A" (pleine), "B" (réduite) ou "ERE" (de B à l'ère I jusqu'à A à l'ère V, par paliers égaux :
# réponse du DC à Q-A4-1, 24/10 : « B mais A sur les dernières aires » puis « je voudrai qu'il grossisse au fur et à
# mesure des aires, docn en gros, le dernier il est gros »)
IMAGE_JEU = "ERE"
DESSINS = {"A": 0, "B": 1, "ERE": 2}
L0_PX = 34.0            # px hr : longueur de base de l'éclat d'un âge 2 × 2 (0,53 tuile), × emprise / 2
AVANCE = 0.18           # centre de l'éclat : AVANCE × longueur au-delà du bout du canon, le long du tir
FRAME_B = dict(force=0.62, longueur=0.72, tour=14.0)   # image B : plus faible, plus courte, pointes tournées (degrés)
SEP_MIN_PX = 10         # px hr : deux rangées plus proches (en travers) = un seul éclat
LIMITE_PX = FE.LIMITE_PX

# Formes par âge (longueurs en multiples de la longueur de base ; angles en degrés depuis l'axe du tir, plan du sol) :
#   coeur : rayon du cœur blanc ; cone : (longueur, demi-largeur à la base, demi-angle) ; pointes : ((angle, longueur,
#   largeur), …) ; anneau : (rayon, épaisseur, aplatissement le long du tir) ou None ; arcs : (nombre, longueur, graine)
#   ou None (âge 6 : arcs électriques) ; bord : poids de l'accent au bout de la flamme.
FORMES = {
    # ère I, poudre : flamme large à trois branches (2) et étoile à cinq (3)
    2: dict(coeur=0.30, cone=(1.00, 0.30, 30), pointes=((52, 0.55, 0.07), (-52, 0.55, 0.07)), anneau=None, arcs=None,
            bord=0.55),
    3: dict(coeur=0.28, cone=(1.05, 0.26, 26), pointes=((68, 0.48, 0.06), (-68, 0.48, 0.06), (30, 0.40, 0.05),
                                                         (-30, 0.40, 0.05)), anneau=None, arcs=None, bord=0.45),
    # ère II : torchère longue (4), gerbe de braise (5), arcs électriques (6)
    4: dict(coeur=0.26, cone=(1.40, 0.28, 20), pointes=((38, 0.32, 0.06), (-38, 0.32, 0.06)), anneau=None, arcs=None,
            bord=0.60),
    5: dict(coeur=0.32, cone=(1.00, 0.42, 38), pointes=((22, 0.62, 0.04), (-22, 0.62, 0.04), (48, 0.50, 0.04),
                                                         (-48, 0.50, 0.04), (75, 0.36, 0.035), (-75, 0.36, 0.035)),
            anneau=None, arcs=None, bord=0.50),
    6: dict(coeur=0.24, cone=(0.55, 0.20, 18), pointes=(), anneau=None, arcs=(4, 1.05, 61), bord=0.35),
    # ère III : cristal à facettes (7), bulle toxique (8), anneau d'atome (9)
    7: dict(coeur=0.22, cone=(0.70, 0.16, 14), pointes=((30, 0.85, 0.045), (-30, 0.85, 0.045), (90, 0.45, 0.04),
                                                         (-90, 0.45, 0.04)), anneau=None, arcs=None, bord=0.60),
    8: dict(coeur=0.40, cone=(0.75, 0.46, 46), pointes=(), anneau=(0.42, 0.08, 0.40), arcs=None, bord=0.40),
    9: dict(coeur=0.26, cone=(0.95, 0.22, 20), pointes=(), anneau=(0.46, 0.06, 0.34), arcs=None, bord=0.50),
    # ère IV : traits de plasma (10, 11), trait et anneau supraconducteur (12)
    10: dict(coeur=0.20, cone=(1.55, 0.11, 5), pointes=((150, 0.30, 0.035), (-150, 0.30, 0.035)), anneau=None,
             arcs=None, bord=0.55),
    11: dict(coeur=0.20, cone=(1.75, 0.10, 4), pointes=(), anneau=(0.30, 0.05, 0.30), arcs=None, bord=0.45),
    12: dict(coeur=0.22, cone=(1.40, 0.12, 6), pointes=(), anneau=(0.44, 0.06, 0.32), arcs=None, bord=0.55),
    # ère V : annihilation (13), étoile de la Porte (14), éclosion incandescente (15)
    13: dict(coeur=0.34, cone=(0.80, 0.20, 16), pointes=((45, 0.50, 0.04), (-45, 0.50, 0.04), (135, 0.40, 0.04),
                                                          (-135, 0.40, 0.04)), anneau=(0.56, 0.07, 0.36), arcs=None,
             bord=0.70),
    14: dict(coeur=0.26, cone=(0.60, 0.12, 10), pointes=((0, 1.00, 0.035), (60, 0.70, 0.03), (-60, 0.70, 0.03),
                                                          (120, 0.55, 0.03), (-120, 0.55, 0.03), (180, 0.45, 0.03)),
             anneau=None, arcs=None, bord=0.45),
    15: dict(coeur=0.44, cone=(1.20, 0.48, 46), pointes=(), anneau=(0.62, 0.10, 0.42), arcs=None, bord=0.75),
}


def _hex(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def couleurs(e):
    """(cœur, corps, accent) de l'âge e, depuis ages.py : corps = FOYER[e].rgb ; accent = FOYER[e].rgb2 s'il existe,
    sinon la couleur de catalogue de sa famille (FAMILLES[e]) ; cœur = corps mêlé de 70 % de blanc."""
    f = ages.FOYER[e]
    corps = tuple(float(x) for x in f["rgb"])
    acc = tuple(float(x) for x in f["rgb2"]) if f.get("rgb2") and tuple(f["rgb2"]) != tuple(f["rgb"]) \
        else _hex(ages.FAMILLES[e]["catalogue"])
    coeur = tuple(0.3 * c + 0.7 for c in corps)
    return coeur, corps, acc


def taille_age(e):
    """Emprise du niveau impair de l'âge (2e − 1) / 2 : 1 (âges 2-3), 1,5 (4-6), 2 (7-9), 2,5 (10-12), 3 (13-15)."""
    return (2 + (2 * e - 2) // 6) / 2.0


def _sol_vers_ecran(ds, phi_deg):
    """Direction du plan du sol ds tournée de phi (degrés, sens horaire vu de dessus), projetée à l'écran : (vecteur
    unitaire écran, facteur de raccourci de la vue)."""
    a = math.radians(phi_deg)
    gx = ds[0] * math.cos(a) - ds[1] * math.sin(a)
    gy = ds[0] * math.sin(a) + ds[1] * math.cos(a)
    sx, sy = gx, gy * FE.PROJ_IMAGE
    n = math.hypot(sx, sy)
    return (sx / n, sy / n), n


def rangees_u(alpha, nom, tol=None):
    """Rangées de canons d'une pose (même découpe que feuilles.bouche_u) : liste de (première bande, dernière bande,
    bout s), et le repère (wx, wy, vx, vy, bw, b0)."""
    Pj = FE.PROJ_IMAGE
    wx, wy = FE.direction_sol(nom)
    vx, vy = -wy, wx
    ys, xs = np.nonzero(alpha >= 128)
    px, py = xs + 0.5, (ys + 0.5) / Pj
    s = px * wx + py * wy + 0.5 * (abs(wx) + abs(wy) / Pj)
    t = px * vx + py * vy
    bw = abs(vx) + abs(vy) / Pj
    b = np.floor(t / bw + 1e-9).astype(np.int64)
    b0 = int(b.min())
    r = np.full(int(b.max()) - b0 + 1, -np.inf)
    np.maximum.at(r, b - b0, s)
    sm = r.max()
    cand = r >= sm - (FE.TOL_CANON if tol is None else tol) * math.sqrt(wx * wx + (wy / Pj) ** 2)
    rr = []
    i = 0
    while i < len(r):
        if cand[i]:
            j = i
            while j + 1 < len(r) and cand[j + 1]:
                j += 1
            rr.append((i + b0, j + b0, float(r[i:j + 1].max())))
            i = j + 1
        else:
            i += 1
    return rr, (wx, wy, vx, vy, bw)


def bouts(alpha, gauche, haut, nom):
    """Bouts des deux canons extrêmes (tuiles depuis l'origine), et leur milieu (= feuilles.bouche_u, contrôlé)."""
    Pj = FE.PROJ_IMAGE
    rr, (wx, wy, vx, vy, bw) = rangees_u(alpha, nom)

    def point(bande_moy, bout):
        tr = bande_moy * bw
        x, y = bout * wx + tr * vx, (bout * wy + tr * vy) * Pj
        return (gauche + x) / 64.0, (haut + y) / 64.0

    a, z = rr[0], rr[-1]
    ca, cz = (a[0] + a[1] + 1) / 2.0, (z[0] + z[1] + 1) / 2.0
    milieu = point((ca + cz) / 2.0, (a[2] + z[2]) / 2.0)
    ref = FE.bouche_u(alpha, gauche, haut, nom)
    if max(abs(milieu[0] - ref[0]), abs(milieu[1] - ref[1])) > 1e-9:
        raise SystemExit("[FO-ECLAT-TIR] %s : milieu des bouts %s ≠ bouche_u %s (mesure divergente)" % (nom, milieu, ref))
    sep = abs(cz - ca) * bw
    if len(rr) == 1 or sep < SEP_MIN_PX:
        return milieu, [milieu], sep
    return milieu, [point(ca, a[2]), point(cz, z[2])], sep


# ------------------------------------------------------------------------------------------------ dessin d'un éclat
def _gauss_segment(X, Y, x0, y0, x1, y1, larg):
    """Intensité d'un trait du point 0 au point 1 (gaussienne en travers, décroît vers le bout 1)."""
    dx, dy = x1 - x0, y1 - y0
    L2 = dx * dx + dy * dy
    if L2 < 1e-9:
        return np.zeros_like(X)
    t = np.clip(((X - x0) * dx + (Y - y0) * dy) / L2, 0.0, 1.0)
    px, py = x0 + t * dx, y0 + t * dy
    d2 = (X - px) ** 2 + (Y - py) ** 2
    return np.exp(-d2 / (larg * larg)) * (1.0 - t) ** 1.2


def rayon(e, forme=None):
    """Rayon (px hr) de la fenêtre d'un éclat de l'âge e."""
    f = forme or FORMES[e]
    Lf = L0_PX * taille_age(e)
    m = max([f["cone"][0] * 1.2, f["coeur"] * 2.5] + [p[1] for p in f["pointes"]] +
            ([f["anneau"][0] + 2 * f["anneau"][1]] if f["anneau"] else []) + ([f["arcs"][1] * 1.2] if f["arcs"] else []))
    return int(math.ceil(m * Lf * (1.0 + AVANCE) + 6))


def part_ere(e):
    """Place de l'ère de l'âge e entre B et A : 0 à l'ère I (âges 1 à 3), 1 à l'ère V (âges 13 à 15), quarts entre."""
    return ((e - 1) // 3) / 4.0


def dessine(e, centre_px, nom, frame):
    """Éclat de l'âge e, direction nom, image frame (0 = A, 1 = B, 2 = progression par ère), centré en centre_px (px hr,
    repère de la fenêtre rendue) : rend (fenêtre carrée prémultipliée H × W × 3, x0, y0 de la fenêtre)."""
    f = FORMES[e]
    coeur_c, corps_c, acc_c = couleurs(e)
    ds = FE.direction_sol(nom)
    t = {0: 1.0, 1: 0.0}.get(frame, part_ere(e))
    k_len = FRAME_B["longueur"] + (1.0 - FRAME_B["longueur"]) * t
    k_for = FRAME_B["force"] + (1.0 - FRAME_B["force"]) * t
    tour = FRAME_B["tour"] * (1.0 - t)
    Lf = L0_PX * taille_age(e) * k_len
    R = rayon(e)
    cx, cy = centre_px
    x0, y0 = int(math.floor(cx)) - R, int(math.floor(cy)) - R
    ys, xs = np.mgrid[y0:y0 + 2 * R + 1, x0:x0 + 2 * R + 1]
    X, Y = xs + 0.5, ys + 0.5
    (ux, uy), fz = _sol_vers_ecran(ds, 0.0)
    a = (X - cx) * ux + (Y - cy) * uy        # le long du tir (écran)
    b = -(X - cx) * uy + (Y - cy) * ux       # en travers
    # cœur
    rc = f["coeur"] * Lf
    I_coeur = np.exp(-(a * a + b * b) / (rc * rc))
    # cône (flamme vers l'avant ; longueur raccourcie par la vue)
    cl, cw, cang = f["cone"]
    Lc = cl * Lf * fz
    ap = a + 0.35 * rc
    w = np.maximum(cw * Lf * 0.5 + np.maximum(ap, 0) * math.tan(math.radians(cang)) * 0.5 / max(fz, 0.3), 1.0)
    I_cone = np.exp(-(b / w) ** 2) * np.where(ap >= 0, np.exp(-2.2 * (ap / max(Lc, 1.0)) ** 2),
                                              np.exp(-(ap / (0.35 * rc + 1e-6)) ** 2))
    # pointes (plan du sol), tournées en image B
    I_pt = np.zeros_like(X)
    for ang, lg, lw in f["pointes"]:
        (sx, sy), fs = _sol_vers_ecran(ds, ang + (tour if ang >= 0 else -tour))
        Ls = lg * Lf * fs
        I_pt = np.maximum(I_pt, _gauss_segment(X, Y, cx, cy, cx + sx * Ls, cy + sy * Ls, max(lw * Lf, 0.9)))
    # arcs électriques (âge 6) : traits brisés déterministes
    I_arc = np.zeros_like(X)
    if f["arcs"]:
        n, lg, graine = f["arcs"]
        rng = np.random.RandomState(graine * 10 + (1 if frame == 1 else 0))   # progression par ère : les arcs de A
        for i in range(n):
            ang = (-70 + 140 * (i + 0.5) / n) + rng.uniform(-12, 12)
            (sx, sy), fs = _sol_vers_ecran(ds, ang)
            Ls = lg * Lf * fs * rng.uniform(0.7, 1.0)
            px_, py_ = cx, cy
            seg = 4
            for j in range(seg):
                t1 = (j + 1) / seg
                off = rng.uniform(-0.16, 0.16) * Ls
                qx = cx + sx * Ls * t1 - sy * off
                qy = cy + sy * Ls * t1 + sx * off
                I_arc = np.maximum(I_arc, _gauss_segment(X, Y, px_, py_, qx, qy, max(0.03 * Lf, 0.9)) * (1 - 0.5 * j / seg))
                px_, py_ = qx, qy
    # anneau (onde de choc, perpendiculaire au tir : ellipse aplatie le long du tir)
    I_an = np.zeros_like(X)
    if f["anneau"]:
        rr, ep, q = f["anneau"]
        a_r = a - 0.25 * Lc
        r = np.sqrt((a_r / q) ** 2 + b * b)
        I_an = np.exp(-((r - rr * Lf) / max(ep * Lf, 1.0)) ** 2)
    corps = np.clip(I_cone + I_pt + I_arc, 0.0, 1.0)
    bord = np.clip(f["bord"] * corps * (1.0 - np.exp(-(np.maximum(a, 0) / max(0.45 * Lc, 1.0)) ** 2)) + I_an, 0, 1)
    c = (np.array(coeur_c)[None, None, :] * I_coeur[..., None] * 1.0 +
         np.array(corps_c)[None, None, :] * corps[..., None] * 0.85 +
         np.array(acc_c)[None, None, :] * bord[..., None] * 0.80)
    c = np.clip(c * k_for, 0.0, 1.0)
    return c, x0, y0


# ------------------------------------------------------------------------------------------------ feuille d'un âge
def noms_dirs(n_dirs):
    return ["N", "E", "S", "O"] if n_dirs == 4 else ["d%02d" % k for k in range(FE.NDIR64)]


def line_length(n_dirs, w, h):
    """Images par rangée : FRAMES (une direction par rangée : une colonne N, E, S, O, F123) à 4 directions ; à 64, la valeur (8, 16, 32 ou 64) qui tient dans
    8 192 px et donne la feuille la plus carrée."""
    n = n_dirs * FRAMES
    if n_dirs == 4:
        return FRAMES
    best = None
    for L in (8, 16, 32, 64):
        W, H = L * w, -(-n // L) * h
        if max(W, H) > LIMITE_PX:
            continue
        k = max(W, H) / max(1, min(W, H))
        if best is None or k < best[0]:
            best = (k, L)
    if best is None:
        raise SystemExit("[FO-ECLAT-TIR] cellule %d × %d : aucune disposition sous %d px (F144)" % (w, h, LIMITE_PX))
    return best[1]


def mesure(dest, e, A):
    """Mesure sur la feuille de tête hr (couche principale) : pour chaque direction, (mode, bouts, milieu, séparation)."""
    td = A["tete"]["main"]["hr"]
    fn = os.path.join(dest, os.path.basename(td["filename"]))
    feuille = np.asarray(Image.open(fn).convert("RGBA"))
    W, H, ll = td["width"], td["height"], td["line_length"]
    gx0 = int(round(td["shift"][0] * 64 - W / 2.0))
    gy0 = int(round(td["shift"][1] * 64 - H / 2.0))
    n_dirs = td["direction_count"]
    noms = noms_dirs(n_dirs)
    ecartees = set(((A.get("outils") or {}).get("eclat_apres") or {}).get("ecartees") or [])
    cy, dist = A["tir"]["projectile_center"][1], A["tir"]["projectile_creation_distance"]
    marge = None
    res = {}
    poses = A["tete"]["main"].get("poses") or {}
    for k, nom in enumerate(noms):
        cell = feuille[(k // ll) * H:(k // ll + 1) * H, (k % ll) * W:(k % ll + 1) * W, 3]
        # découpe à partir du coin de la pose dans sa cellule (feuilles.py : poses[nom].x, .y) : mêmes coordonnées de
        # pixels que la pose source, donc mêmes bandes que bouche_u (hors des 4 directions cardinales, les bandes
        # dépendent de l'origine des pixels)
        px0, py0 = (poses[nom]["x"], poses[nom]["y"]) if nom in poses else (0, 0)
        milieu, pts, sep = bouts(cell[py0:, px0:], gx0 + px0, gy0 + py0, nom)
        ref = A["bouches"][nom]
        if max(abs(milieu[0] - ref[0]), abs(milieu[1] - ref[1])) > 1e-4:
            raise SystemExit("[FO-ECLAT-TIR] âge %d %s : bouche mesurée sur la feuille %s ≠ sprites.json %s" % (
                e, nom, milieu, ref))
        if nom in ecartees:
            if marge is None:
                marge = mesure.marge
            u = FE.unite_pose(nom)
            vx, vy = FE.eclat_visible_u(cy, dist, u)
            pts = [(vx - marge * u[0], vy - marge * u[1])]
            res[nom] = ("réglage (écartée, regardée D-12)", pts, milieu, sep)
        else:
            res[nom] = ("mesuré", pts, milieu, sep)
    return res, n_dirs


mesure.marge = None


def feuille_eclat(dest, e, A, marge, image=None):
    """Écrit gun-eNN-eclat.png dans dest (depuis la feuille de tête déjà écrite) ; rend (définition pour sprites.lua,
    outils pour sprites.json). `image` : dessin « A » ou « B » (défaut IMAGE_JEU ; autre valeur : planche de
    comparaison seulement)."""
    dessin = DESSINS[image or IMAGE_JEU]
    # marge arrondie comme dans sprites.json (« eclat.marge ») : le contrôle régénère avec la valeur écrite
    mesure.marge = round(marge, 5)
    pos, n_dirs = mesure(dest, e, A)
    noms = noms_dirs(n_dirs)
    Lf = L0_PX * taille_age(e)
    # centres (px hr depuis l'origine de l'entité) : bout + AVANCE × longueur le long du tir (raccourcie par la vue)
    centres = {}
    for nom in noms:
        (ux, uy), fz = _sol_vers_ecran(FE.direction_sol(nom), 0.0)
        av = AVANCE * Lf * fz
        centres[nom] = [(x * 64 + ux * av, y * 64 + uy * av) for x, y in pos[nom][1]]
    R = rayon(e)
    xs = [c[0] for v in centres.values() for c in v]
    ys = [c[1] for v in centres.values() for c in v]
    L = int(math.floor(min(xs))) - R - 2
    T = int(math.floor(min(ys))) - R - 2
    Rr = int(math.ceil(max(xs))) + R + 3
    Bb = int(math.ceil(max(ys))) + R + 3
    L -= L % 2
    T -= T % 2
    Rr += Rr % 2
    Bb += Bb % 2
    Wc, Hc = Rr - L, Bb - T
    wl, hl = Wc // 2, Hc // 2
    ll = line_length(n_dirs, wl, hl)
    n = n_dirs * FRAMES
    lignes = -(-n // ll)
    sheet = np.zeros((lignes * hl, ll * wl, 4))
    pics = {}
    for k, nom in enumerate(noms):
        for fr in range(FRAMES):
            c = np.zeros((Hc, Wc, 3))
            for (px, py) in centres[nom]:
                w_, x0, y0 = dessine(e, (px - L, py - T), nom, dessin + fr)
                ya, xa = max(0, y0), max(0, x0)
                yb, xb = min(Hc, y0 + w_.shape[0]), min(Wc, x0 + w_.shape[1])
                if yb > ya and xb > xa:
                    c[ya:yb, xa:xb] += w_[ya - y0:yb - y0, xa - x0:xb - x0]
            c = np.clip(c, 0.0, 1.0)
            m = c.max(-1, keepdims=True)
            enc = np.concatenate([np.where(m > 1e-6, c / np.maximum(m, 1e-6), 0), m], -1)
            lr = P.downsample2_additive(enc)
            i = k * FRAMES + fr
            r0, c0 = (i // ll) * hl, (i % ll) * wl
            sheet[r0:r0 + hl, c0:c0 + wl] = lr
            pics[(nom, fr)] = enc
    fn = "gun-e%02d-eclat.png" % e
    P.write_png(sheet, os.path.join(dest, fn))
    shift = [(L + Rr) / 2.0 / 64.0, (T + Bb) / 2.0 / 64.0]
    defn = {"lr": {"filename": FE.GRAPHICS_PREFIX + fn, "width": wl, "height": hl, "shift": shift,
                   "direction_count": n_dirs, "frame_count": FRAMES, "line_length": ll}}
    coeur_c, corps_c, acc_c = couleurs(e)
    outils = {"modes": {nom: pos[nom][0] for nom in noms},
              "bouts": {nom: [[round(x, 5), round(y, 5)] for x, y in pos[nom][1]] for nom in noms},
              "deux_canons": sum(1 for nom in noms if len(pos[nom][1]) == 2),
              "dessin": image or IMAGE_JEU,
              "ecartees_au_reglage": sorted(nom for nom in noms if pos[nom][0] != "mesuré"),
              "couleurs": {"coeur": [round(x, 4) for x in coeur_c], "corps": [round(x, 4) for x in corps_c],
                           "accent": [round(x, 4) for x in acc_c]},
              "longueur_base_tuiles": round(Lf / 64.0, 4), "cellule_px_lr": [wl, hl], "feuille_px": [ll * wl, lignes * hl]}
    return defn, outils, pics, (L, T)


# ------------------------------------------------------------------------------------------------ outils seuls
def _sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def _marge():
    vb = FE.bouches_vanille(FE.DATA_DEFAUT)
    mv = FE.marges(vb, FE.VANILLE["projectile_center"][1], FE.VANILLE["projectile_creation_distance"])
    return sum(mv[d][0] for d in FE.MARGE_DIRS) / len(FE.MARGE_DIRS)


def controle(dest):
    """Régénère chaque feuille d'éclat depuis les feuilles de tête du mod, dans un dossier jetable : mêmes octets et
    même définition que sprites.json. Rend (erreurs, nombre d'âges)."""
    donnees = json.load(open(os.path.join(dest, "sprites.json"), encoding="utf-8"))
    marge = donnees["eclat"]["marge"]
    tmp = tempfile.mkdtemp(prefix="fo-eclat-tir-")
    err, n = [], 0
    try:
        for k, A in sorted(donnees["ages"].items(), key=lambda kv: int(kv[0])):
            e = int(k)
            if e == 1:
                continue
            if "eclat" not in A:
                err.append("âge %d : pas d'éclat de tir dans sprites.json" % e)
                continue
            td = A["tete"]["main"]["hr"]
            shutil.copyfile(os.path.join(dest, os.path.basename(td["filename"])),
                            os.path.join(tmp, os.path.basename(td["filename"])))
            try:
                defn, _, _, _ = feuille_eclat(tmp, e, A, marge)
            except SystemExit as ex:      # mesure impossible ou divergente sur une feuille de tête abîmée
                err.append("âge %d : %s" % (e, ex))
                continue
            fn = os.path.basename(defn["lr"]["filename"])
            if defn != A["eclat"]:
                err.append("âge %d : définition régénérée ≠ sprites.json (%s contre %s)" % (e, defn, A["eclat"]))
            if _sha(os.path.join(tmp, fn)) != _sha(os.path.join(dest, fn)):
                err.append("âge %d : %s régénéré ≠ fichier du mod" % (e, fn))
            n += 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return err, n


def planche(dest, ages_, out, zoom, image=None):
    """Une planche par âge : chaque direction, la pose en couleur (feuille de tête hr) et l'éclat (une image)
    composé en additif, sur fond sombre ; croix rouge : bouts mesurés. `image` : dessin montré (défaut IMAGE_JEU, celui du
    jeu ; l'autre pour comparer)."""
    image = image or IMAGE_JEU
    from PIL import ImageDraw
    donnees = json.load(open(os.path.join(dest, "sprites.json"), encoding="utf-8"))
    marge = donnees["eclat"]["marge"]
    os.makedirs(out, exist_ok=True)
    chemins = []
    for e in ages_:
        A = donnees["ages"][str(e)]
        tmp = tempfile.mkdtemp(prefix="fo-eclat-pl-")
        try:
            td = A["tete"]["main"]["hr"]
            shutil.copyfile(os.path.join(dest, os.path.basename(td["filename"])),
                            os.path.join(tmp, os.path.basename(td["filename"])))
            defn, outils, pics, (L, T) = feuille_eclat(tmp, e, A, marge, image)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        feuille = np.asarray(Image.open(os.path.join(dest, os.path.basename(td["filename"]))).convert("RGBA")) / 255.0
        W, H, ll = td["width"], td["height"], td["line_length"]
        gx0 = int(round(td["shift"][0] * 64 - W / 2.0))
        gy0 = int(round(td["shift"][1] * 64 - H / 2.0))
        noms = noms_dirs(td["direction_count"])
        Hc, Wc = pics[(noms[0], 0)].shape[:2]
        x0 = min(gx0, L)
        y0 = min(gy0, T)
        x1 = max(gx0 + W, L + Wc)
        y1 = max(gy0 + H, T + Hc)
        cw, ch = x1 - x0, y1 - y0
        ncol = 8 if len(noms) == 64 else 4
        img = np.zeros((((len(noms) + ncol - 1) // ncol) * ch * FRAMES, ncol * cw, 3))
        img[...] = (0.10, 0.11, 0.10)
        marques = []
        for k, nom in enumerate(noms):
            cell = feuille[(k // ll) * H:(k // ll + 1) * H, (k % ll) * W:(k % ll + 1) * W]
            for fr in range(FRAMES):
                oy = ((k // ncol) * FRAMES + fr) * ch
                ox = (k % ncol) * cw
                zone = img[oy:oy + ch, ox:ox + cw]
                ya, xa = gy0 - y0, gx0 - x0
                sub = zone[ya:ya + H, xa:xa + W]
                sub[...] = sub * (1 - cell[..., 3:4]) + cell[..., :3] * cell[..., 3:4]
                enc = pics[(nom, fr)]
                ya, xa = T - y0, L - x0
                sub = zone[ya:ya + Hc, xa:xa + Wc]
                sub[...] = np.clip(sub + enc[..., :3] * enc[..., 3:4], 0, 1)
                for bx, by in outils["bouts"][nom]:
                    marques.append((ox + bx * 64 - x0, oy + by * 64 - y0, nom, fr, outils["modes"][nom]))
        im = Image.fromarray((img * 255).round().astype(np.uint8))
        f = zoom / 2.0
        im = im.resize((max(1, int(im.width * f)), max(1, int(im.height * f))), Image.LANCZOS)
        dr = ImageDraw.Draw(im)
        for x, y, nom, fr, mode in marques:
            x, y = x * f, y * f
            c = (255, 60, 60) if mode == "mesuré" else (60, 230, 60)
            dr.line([(x - 3, y), (x + 3, y)], fill=c)
            dr.line([(x, y - 3), (x, y + 3)], fill=c)
        for k, nom in enumerate(noms):
            for fr in range(FRAMES):
                dr.text((((k % ncol) * cw) * f + 3, (((k // ncol) * FRAMES + fr) * ch) * f + 2),
                        "%s %s" % (nom, image), fill=(230, 230, 230))
        p = os.path.join(out, "eclat-tir-e%02d-%s-z%d.png" % (e, image, zoom))
        im.save(p)
        chemins.append(p)
        print("[FO-ECLAT-TIR] âge %2d : %d directions, deux canons %d, au réglage %s ; feuille %s ; planche %s" % (
            e, len(noms), outils["deux_canons"], outils["ecartees_au_reglage"] or "aucune", outils["feuille_px"], p))
    return chemins


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default=FE.DEST_DEFAUT)
    ap.add_argument("--planche", default=None)
    ap.add_argument("--ages", default="2-15")
    ap.add_argument("--zoom", type=int, default=2)
    ap.add_argument("--image", choices=tuple(DESSINS), default=None,
                    help="planche : dessin montré (défaut IMAGE_JEU, celui du jeu)")
    ap.add_argument("--controle", action="store_true")
    a = ap.parse_args()
    if a.controle:
        err, n = controle(a.dest)
        for x in err:
            print("[FO-ECLAT-TIR] ECHEC " + x)
        print("[FO-ECLAT-TIR] contrôle : %d âge(s) régénéré(s), %d écart(s)" % (n, len(err)))
        return 1 if err else 0
    if a.planche:
        sel = []
        for x in a.ages.split(","):
            u, v = (x.split("-") + [x])[:2] if "-" in x else (x, x)
            sel += list(range(int(u), int(v) + 1))
        planche(a.dest, sel, a.planche, a.zoom, a.image)
    return 0


if __name__ == "__main__":
    sys.exit(main())
