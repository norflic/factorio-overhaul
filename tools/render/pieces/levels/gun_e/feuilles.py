"""FEUILLES DE JEU de la mitrailleuse V3-E (lot A2, 24/10 ; 64 directions : lot A3-jeu) : des sprites de production
aux fichiers du mod. Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/feuilles.py [--dest graphics/levels/gun] [--valide 1-9=DIR …]
        [--so DIR] [--a3 DIR] [--ages-64 auto|aucun|LISTE] [--hors-regle-ok NOM,…] [--ecartees-ok eNN-dKK,…]
        [--data <racine>/data]

Ce que l'outil écrit dans --dest (dossier du mod ; les PNG y sont HORS de git, décision D-6 de l'orchestrateur) :
  - socle et pièce de chaque âge : COPIES octet à octet des sprites validés (mêmes noms : hr-gune-eNN-socle-main.png…) ;
  - tête de chaque âge (2 à 15), par couche (main, shadow, glow ; la tête n'a pas de couche « light ») et par
    résolution, UNE feuille par couche (8 192 px au plus par côté, F144 : contrôlé, sinon refus) :
      * 64 DIRECTIONS (lot A3-jeu) si les 64 poses de l'âge existent et sont contrôlées : d00 = tete-N et d16 = tete-E
        (sources validées V3-E), d32 et d48 (lot A2, --so), les 60 autres de la production A3 (--a3 : controle.json
        « ok », sha256 du spec.json et des PNG égaux à ceux du contrôle, aucun trou « HORS REGLE » sauf --hors-regle-ok) ;
        feuille de 8 × 8 images dans l'ordre d00 à d63 d'une RotatedAnimation (rangée par rangée, line_length 8 ;
        rotation uniforme −2π·K/64 depuis le nord, sens horaire ; apply_projection laissé vrai : le moteur montre
        l'image K pour l'orientation orientation_image(K), F121, E70) ;
      * sinon REPLI à 4 directions, exactement comme au lot A2 : feuille en COLONNE de 4 images N, E, S, O (doc 1.1.91,
        « 4 : North (1), East (2), South (3), West (4) » ; F123) ;
    cadre commun = union des poses de l'âge, bords PAIRS relatifs à l'origine (la version normale tombe au pixel) ;
    chaque pose collée à sa place exacte : les pixels de chaque pose, donc des poses validées (N = d00, E = d16), sont
    recopiés SANS changement (contrôle : check_gun_sheets.py --sources) ;
  - icône de chaque âge 2 à 15 (64 px + mipmaps, bande 120 × 64) : socle + tête E composés hors Blender, réduits par
    fo_post.icon_strip (même code que l'icône de render.py) ;
  - sprites.lua (définitions lues par prototypes/levels/gun.lua) et sprites.json (mêmes données, pour les outils) ;
  - MANIFEST.json : chaque fichier (taille, sha256, dimensions), les sources (spec.json et sha256 de chaque PNG
    source) et la commande exacte qui régénère le dossier. sprites.lua, sprites.json et MANIFEST.json sont COMMITÉS.

Bouche du canon et éclat de tir (E68, correction A2) :
  - bouche DESSINÉE de chaque pose = milieu des bouts des deux canons extrêmes (rangées de lignes dont le pixel opaque
    le plus avancé est à TOL_CANON px au plus du plus avancé de la pose ; vanilla, un seul canon : TOL_VANILLE) ;
  - règle du MOTEUR, mesurée par gun-rose sur 60 tourelles (15 âges × 4 directions, écart ≤ 0,009 tuile) : l'éclat
    (entité explosion-gunshot) naît en projectile_center + distance × (vx, vy) / |(vx, vy / K_PROJ)|, v = cible −
    projectile_center ; pour une cible lointaine dans la direction u : centre + distance × (ux, K_PROJ × uy) ; il se
    VOIT H_ECLAT tuile plus haut (hauteur de l'explosion) ; une cible proche dévie l'éclat en E et en O d'au plus
    distance × |centre.y| / portée (0,07 tuile à l'âge 15 pour une cible à 25 tuiles) ;
  - marge = où l'éclat visible de la VANILLA tombe au-delà de sa bouche, moyenne de N, E et O (MARGE_DIRS) ;
  - pour chaque âge, centre.y et distance au sens des moindres carrés sur TOUTES les directions de l'âge (4, ou 64 :
    lot A3-jeu ; cible = bouche + marge le long du tir) ; un âge dont l'éclat visible tombe à plus de SEUIL_ECLAT tuile
    de sa cible dans UNE direction est REFUSÉ (code non nul, rien n'est écrit au-delà des PNG) ; à 64 directions, le
    réglage écarte les bouches mal mesurées (ajuste_robuste) et le seuil ne porte que sur les directions gardées :
    chaque direction écartée doit donc avoir été REGARDÉE (ECLAT_ECARTEES_OK_DEFAUT, --ecartees-ok), sinon l'âge
    reste à 4 directions (correction M-1, 24/10) ; le réglage SANS exclusion est rappelé dans
    « outils.eclat_apres.sans_exclusion » ; écarts dans
    sprites.json (« ecarts_bouche », « ecart_max »), éclat visible prévu (« eclat_visible ») ; à 64 directions, l'écart
    du réglage « avant » (ajusté sur d00, d16, d32, d48 seulement, comme au lot A2) sur les 64 directions est gardé
    dans « outils.eclat_avant » ;
  - direction quelconque (lot A3-jeu) : le tir de l'image K va, à l'écran, dans la direction de orientation_image(K) ;
    la bouche se mesure dans le repère (le long du tir, en travers) de cette direction : bouche_u(), qui rend
    EXACTEMENT bouche() aux 4 directions cardinales (même découpe en rangées).

Sources par défaut (designs VALIDÉS par le Directeur Créatif ; production à 128 échantillons) :
  âges 1 à 9    fo-logs/2026-10-23_V3E-p5/bas/sprites
  âges 10 à 12  fo-logs/2026-10-23_V3E-p5/haut/sprites   (e13 à e15 de ce dossier : REFUSÉS, REFUSES.txt)
  âges 13 à 15  fo-logs/2026-10-23_V3E-ereV/sprites
  poses S et O  fo-logs/2026-10-24_A2/sprites (eNN-tete-d32, eNN-tete-d48 ; lot A2)
  60 autres     fo-logs/2026-10-24_A3/sprites (eNN-tete-dKK ; production A3, 128 échantillons, ombre à 32 : D-7)
  socle animé   fo-logs/2026-10-24_A4/socle-anime/sprites (eNN-socle-anime : lueur et halo en N images, anime_socle.py,
                lot A4 ; un âge sans dossier garde son socle fixe ; --socle-anime aucun : tous fixes)

Éclat de tir 2D (lot A4) : eclat_tir.py, appelé à la fin de chaque âge (gun-eNN-eclat.png, couche d'attacking_animation,
bouts des canons mesurés sur la feuille de tête qui vient d'être écrite).
"""
import argparse
import hashlib
import json
import math
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
GAME = os.path.dirname(os.path.dirname(MOD)) if os.path.basename(os.path.dirname(MOD)) == "mods" else None
sys.path.insert(0, RENDER)
import fo_post as P  # noqa: E402

MOD_NAME = "factorio-overhaul"
LOGS = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
VALIDES_DEFAUT = ["1-9=" + os.path.join(LOGS, "2026-10-23_V3E-p5", "bas", "sprites"),
                  "10-12=" + os.path.join(LOGS, "2026-10-23_V3E-p5", "haut", "sprites"),
                  "13-15=" + os.path.join(LOGS, "2026-10-23_V3E-ereV", "sprites")]
SO_DEFAUT = os.path.join(LOGS, "2026-10-24_A2", "sprites")
A3_DEFAUT = os.path.join(LOGS, "2026-10-24_A3", "sprites")
SOCLE_ANIME_DEFAUT = os.path.join(LOGS, "2026-10-24_A4", "socle-anime", "sprites")   # lot A4 (à GARDER)
DATA_DEFAUT = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data"
DEST_DEFAUT = os.path.join(MOD, "graphics", "levels", "gun")
GRAPHICS_PREFIX = "__%s__/graphics/levels/gun/" % MOD_NAME
DIRECTIONS = (("N", "tete-N"), ("E", "tete-E"), ("S", "tete-d32"), ("O", "tete-d48"))
TETE_COUCHES = ("main", "shadow", "glow")
FIXE_COUCHES = ("main", "shadow", "glow", "light")
# Vanilla (data/base/prototypes/entity/turrets.lua, mitrailleuse) : point du moteur et tête hr
VANILLE = {"projectile_creation_distance": 1.39375, "projectile_center": (0.0, -0.0875),
           "tete_hr": {"w": 132, "h": 130, "shift_px": (0.0, -27.5), "bandes": 4, "par_bande": 16, "images": 2}}
# Éclat de tir (E68, mesuré en moteur par le scénario gun-rose : position de l'entité explosion-gunshot) :
#   point du moteur = projectile_center + distance × (ux, K_PROJ × uy) ; vanilla : N −1,0664 et S +0,8945 pour
#   centre −0,0875 et distance 1,39375 (K = 0,702 et 0,705) ; âge 15 : N −3,6094, S +2,6875 (0,706, 0,707) ;
#   l'éclat se VOIT H_ECLAT tuile plus haut (hauteur d'une explosion, défaut 1 de ExplosionPrototype ; vanilla en E :
#   bout des canons à 0,05 tuile de cette hauteur).
K_PROJ = 0.7071
H_ECLAT = 1.0
TOL_CANON = 24          # px hr : bouts de canon à 0,375 tuile au plus du plus avancé
TOL_VANILLE = 4         # px hr : la vanilla n'a qu'un canon (gatling) ; une tolérance large prend le corps
# Marge étalonnée sur la vanilla en N, E et O seulement : en S, le point opaque le plus bas de la tête vanilla est la
# couronne dentée, pas la bouche (planche fo-logs/2026-10-24_A2/correction/vanille-bouches.png ; à l'œil, l'éclat
# vanilla en S tombe environ 0,34 tuile au-delà de la bouche, comme en N et en E).
MARGE_DIRS = ("N", "E", "O")
SEUIL_ECLAT = 0.5       # tuile : écart maximal toléré entre l'éclat visible prévu et sa cible (bouche + marge)
COMMANDE = ("py -3.9 tools/render/pieces/levels/gun_e/feuilles.py   (depuis la racine du mod ; sources par défaut : "
            "en tête de feuilles.py)")
# Têtes A3 « HORS REGLE » (trou enfermé > 8 px hors bouchon) ACCEPTÉES après regard sur gros plan (lot A3-jeu, 24/10 :
# fo-logs/2026-10-24_A3-jeu/hors-regle-1.png, hors-regle-2.png, e03-d06-trou-x3.png ; jour mécanique entre culasse et
# bobine, ou entre bobine et coque ; verdict du DC NON rendu). Liste par DÉFAUT, pour que la commande sans option du
# MANIFEST régénère exactement les feuilles commitées ; --hors-regle-ok en AJOUTE, --hors-regle-ok aucun la vide.
# Lot A3-final (24/10, après la fin de la production à 11:59) : e11-tete-d07 (27 px), d22 (9 px), d33 (13 px) REGARDÉES
# (fo-logs/2026-10-24_A3-final/trous-e11-d07.png, trous-e11-d22.png, trous-e11-d33.png, trous-e11-d33-x10.png, avec
# leurs voisines) : d07 et d22, fente fine entre la base d'une ailette et le faisceau de canons, la même que chez les
# voisines d06, d08, d23 (sous leur plafond) ; d33, fente de 1 à 2 px sur 11 px entre la petite ailette droite de la
# bouche et le manchon (trous-e11-d33-marque-x10.png, trou en vert). Jours mécaniques plausibles, aucun manque de
# matière ; verdict du DC NON rendu.
HORS_REGLE_OK_DEFAUT = ("e03-tete-d06", "e03-tete-d51", "e03-tete-d58", "e03-tete-d59", "e06-tete-d54",
                        "e11-tete-d07", "e11-tete-d22", "e11-tete-d33")
# Éclat à 64 directions (correction M-1 de la vérification du lot A3-jeu, 24/10) : une direction ÉCARTÉE du réglage par
# ajuste_robuste() (bouche jugée mal mesurée) sort du contrôle chiffré ; elle n'est donc admise que si quelqu'un a
# REGARDÉ l'éclat prévu dans cette direction (planche eclat64.py --couleur, et tir en jeu quand il est joué) et l'a
# inscrite ici, « eNN-dKK », avec la planche. Toute direction écartée HORS de cette liste renvoie son âge en REPLI à
# 4 directions (rien n'est refusé en silence, rien ne passe sans regard). --ecartees-ok en AJOUTE, « aucun » la vide.
# Fait à ne pas perdre : SANS exclusion, l'âge 2 serait REFUSÉ par le seuil de 0,5 tuile (0,568 en d54) ; la liste
# ci-dessous est donc un écart à la lettre de la consigne (« refus au-delà de 0,5 tuile »), à trancher par
# l'orchestrateur (fo-logs/2026-10-24_A3-jeu/NOTES.md, « Correction »). Verdict du DC NON rendu.
# Âge 2 : regardé le 24/10 (correcteur) : fo-logs/2026-10-24_A3-jeu/correction/eclat64-e02-ecartees-z4.png (bouche
# mesurée sur le corps, éclat prévu au bout des canons) et tirs en jeu correction/captures-tir/ (11 directions).
ECLAT_ECARTEES_OK_DEFAUT = ("e02-d07", "e02-d08", "e02-d09", "e02-d10", "e02-d16", "e02-d48", "e02-d54", "e02-d55",
                            "e02-d56", "e02-d57", "e02-d60")
# 64 directions (lot A3-jeu)
NDIR64 = 64
LIGNE64 = 8             # feuille de 8 × 8 images, rangée par rangée (line_length 8)
LIMITE_PX = 8192        # F144 : largeur et hauteur d'un fichier d'image d'entrée (doc 1.1.91, prototype-api.json)
PROJ_IMAGE = math.sqrt(0.5)   # apply_projection : compression verticale de la vue (E70 : NE -> image 6, SE -> 26…)
CARDINAUX = {"N": 0, "E": 16, "S": 32, "O": 48}   # pose du lot A2 -> numéro de direction sur 64
SAMPLES_PASSES_A3 = {"shadow": 32}               # D-7 : ombre à 32 échantillons (spec.json des têtes A3)


def sha_file(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def plages(specs):
    res = {}
    for s in specs:
        plage, d = s.split("=", 1)
        a, b = plage.split("-") if "-" in plage else (plage, plage)
        for e in range(int(a), int(b) + 1):
            res[e] = d
    return res


def lire_spec(d, nom):
    p = os.path.join(d, nom, "spec.json")
    if not os.path.exists(p):
        raise SystemExit("source absente : %s" % p)
    s = json.load(open(p, encoding="utf-8"))
    if s.get("variant") != nom:
        raise SystemExit("%s : spec.json d'une autre variante (%s)" % (p, s.get("variant")))
    if s.get("samples") != 128 or s.get("quick") or s.get("apercu"):
        raise SystemExit("%s : pas un rendu de production (échantillons %s, rapide %s, aperçu %s)"
                         % (p, s.get("samples"), s.get("quick"), s.get("apercu")))
    for lay, L in s["layers"].items():
        for res, LL in (("hr", L), ("lr", L["lr"])):
            f = os.path.join(d, nom, LL["file"])
            if sha_file(f) != LL["sha256"]:
                raise SystemExit("%s : sha256 du PNG différent du spec.json (%s %s)" % (f, lay, res))
    return s, os.path.join(d, nom)


def rgba(p):
    return np.asarray(Image.open(p).convert("RGBA"))


def ecrire_png(u8, p):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    u8 = u8.copy()
    u8[u8[..., 3] == 0, :3] = 0
    Image.fromarray(u8, "RGBA").save(p, optimize=True, compress_level=9)


def boite_px(L):
    """Boîte d'une couche hr relative à l'origine, en px hr (gauche, haut, droite, bas) ; entiers PAIRS exigés."""
    w, h = L["width"], L["height"]
    gx = L["shift"][0] * 64 - w / 2
    gy = L["shift"][1] * 64 - h / 2
    if abs(gx - round(gx)) > 1e-9 or abs(gy - round(gy)) > 1e-9:
        raise SystemExit("bord de pose non entier : %s" % L["file"])
    gx, gy = int(round(gx)), int(round(gy))
    if gx % 2 or gy % 2 or w % 2 or h % 2:
        raise SystemExit("bord de pose impair (la version normale ne tomberait pas au pixel) : %s" % L["file"])
    return gx, gy, gx + w, gy + h


def _vers_E(a, d):
    """Tourne la couche alpha pour que la direction du tir d devienne +x (colonnes croissantes)."""
    if d == "E":
        return a
    if d == "O":
        return a[:, ::-1]
    if d == "S":
        return a.T
    return a[::-1, :].T


def canons(alpha, d, tol=None):
    """Bouts de canon d'une pose, dans le repère tourné vers +x : liste de (première rangée, dernière rangée, bout),
    bout = bord avant (px) ; une « rangée » est une suite de lignes dont le pixel opaque (alpha ≥ 0,5) le plus avancé est
    à TOL_CANON px au plus du plus avancé de la pose."""
    op = _vers_E(alpha, d) >= 128
    lignes = np.nonzero(op.any(1))[0]
    r = np.full(op.shape[0], -1)
    for i in lignes:
        r[i] = int(np.nonzero(op[i])[0].max()) + 1
    xm = int(r.max())
    cand = r >= xm - (TOL_CANON if tol is None else tol)
    res = []
    i = 0
    while i < len(r):
        if cand[i]:
            j = i
            while j + 1 < len(r) and cand[j + 1]:
                j += 1
            res.append((i, j, int(r[i:j + 1].max())))
            i = j + 1
        else:
            i += 1
    return res


def bouche(alpha, gauche, haut, d, tol=None):
    """Bouche dessinée d'une pose (tuiles depuis l'origine de l'entité) : MILIEU des bouts des deux canons extrêmes
    (correction A2 : la médiane des lignes des 6 dernières colonnes tombait dans un seul canon dès que les deux
    canons arrivent au même bout, âge 12). En transverse : milieu des centres des deux rangées extrêmes ; le long du
    tir : moyenne de leurs bouts. Une seule rangée (canons jumeaux collés, vanilla, âges 2 et 3) : son centre."""
    h, w = alpha.shape
    rr = canons(alpha, d, tol)
    a, b = rr[0], rr[-1]
    trans = ((a[0] + a[1] + 1) / 2.0 + (b[0] + b[1] + 1) / 2.0) / 2.0
    bout = (a[2] + b[2]) / 2.0
    if d == "E":
        x, y = bout, trans
    elif d == "O":
        x, y = w - bout, trans
    elif d == "S":
        x, y = trans, bout
    else:
        x, y = trans, h - bout
    return float((gauche + x) / 64.0), float((haut + y) / 64.0)


UNITE = {"N": (0.0, -1.0), "E": (1.0, 0.0), "S": (0.0, 1.0), "O": (-1.0, 0.0)}


def point_moteur(centre_y, dist, d):
    """Point de création de l'éclat (entité explosion-gunshot) mesuré en moteur (E68, gun-rose) : projectile_center +
    distance × (ux, K_PROJ × uy), en tuiles depuis le centre de l'entité."""
    ux, uy = UNITE[d]
    return dist * ux, centre_y + K_PROJ * dist * uy


def eclat_visible(centre_y, dist, d):
    """Où l'éclat se VOIT : point du moteur relevé de la hauteur de l'explosion (H_ECLAT tuile)."""
    x, y = point_moteur(centre_y, dist, d)
    return x, y - H_ECLAT


def marges(bouches, centre_y, dist):
    """Pour chaque direction : (marge le long du tir = éclat visible − bouche dessinée, écart transverse)."""
    res = {}
    for d, (bx, by) in sorted(bouches.items()):
        vx, vy = eclat_visible(centre_y, dist, d)
        ux, uy = UNITE[d]
        res[d] = ((vx - bx) * ux + (vy - by) * uy, (vx - bx) * uy - (vy - by) * ux)
    return res


def ajuste_tir(bouches, marge):
    """projectile_center.y et projectile_creation_distance au sens des moindres carrés sur les 4 directions : l'éclat
    visible doit tomber à `marge` tuile au-delà de la bouche dessinée (marge étalonnée sur la vanilla)."""
    A, b = [], []
    for d, (bx, by) in sorted(bouches.items()):
        ux, uy = UNITE[d]
        tx, ty = bx + marge * ux, by + marge * uy
        if ux:
            A.append([0.0, ux]); b.append(tx)
        A.append([1.0, K_PROJ * uy]); b.append(ty + H_ECLAT)
    sol = np.linalg.lstsq(np.array(A), np.array(b), rcond=None)[0]
    return float(sol[0]), float(sol[1])


# ------------------------------------------------------------------ directions quelconques (lot A3-jeu, 64 directions)
def orientation_image(k, n=NDIR64):
    """Orientation (0 = nord, sens horaire, tour entier = 1) pour laquelle le moteur montre l'image k d'une tête à n
    directions rendue en rotation UNIFORME (angle θk = 2π·k/n autour de la verticale) avec apply_projection : à
    l'écran, la direction θk se voit comprimée en hauteur (PROJ_IMAGE), donc tan(2π·o) = tan(θk) / PROJ_IMAGE. Le centre
    de la plage de l'image k. Vérifié en moteur aux 8 directions (E70 : o = 1/8 -> image 6 ; 3/8 -> 26 ; 5/8 -> 38 ;
    7/8 -> 58, soit l'arrondi de l'angle déprojeté)."""
    if (k * 4) % n == 0:
        return (k * 4 // n) / 4.0
    th = 2.0 * math.pi * k / n
    return (math.atan2(math.sin(th), PROJ_IMAGE * math.cos(th)) / (2.0 * math.pi)) % 1.0


def image_orientation(o, n=NDIR64):
    """Image montrée par le moteur pour l'orientation o (règle déduite d'E70 : arrondi de l'angle déprojeté)."""
    a = 2.0 * math.pi * o
    th = math.atan2(math.sin(a) * PROJ_IMAGE, math.cos(a)) % (2.0 * math.pi)
    return int(math.floor(th / (2.0 * math.pi) * n + 0.5)) % n


def unite_orientation(o):
    """Vecteur unitaire de la direction d'orientation o, en coordonnées d'écran (x à droite, y vers le bas)."""
    a = 2.0 * math.pi * o
    ux, uy = math.sin(a), -math.cos(a)
    return (0.0 if abs(ux) < 1e-12 else ux), (0.0 if abs(uy) < 1e-12 else uy)


def unite_pose(nom):
    """Direction du tir d'une pose : « N », « E », « S », « O » (UNITE, exact) ou « dKK » (64 directions)."""
    if nom in UNITE:
        return UNITE[nom]
    k = int(nom[1:])
    for c, kk in CARDINAUX.items():
        if kk == k:
            return UNITE[c]
    return unite_orientation(orientation_image(k))


def direction_sol(nom):
    """Direction du tir d'une pose dans le plan du SOL déprojeté (y écran / PROJ_IMAGE) : (sin θ, −cos θ), θ = 2π·K/64
    (rotation uniforme du rendu) ; exacte aux 4 directions cardinales."""
    if nom in UNITE:
        return UNITE[nom]
    k = int(nom[1:])
    for c, kk in CARDINAUX.items():
        if kk == k:
            return UNITE[c]
    th = 2.0 * math.pi * k / NDIR64
    return math.sin(th), -math.cos(th)


def bouche_u(alpha, gauche, haut, nom, tol=None):
    """Bouche dessinée de la pose `nom` (« N »… ou « dKK ») : même règle que bouche() (milieu des bouts des deux canons
    extrêmes), mais mesurée dans le plan du SOL DÉPROJETÉ (x, y / PROJ_IMAGE), où le tir va dans direction_sol(nom) :
    deux canons parallèles et de même longueur y ont leurs bouts sur une même perpendiculaire au tir ; à l'écran, hors
    des 4 directions cardinales, la projection les décale le long du tir (jusqu'à 0,8 tuile à l'âge 5 en d04 : un seul
    canon restait dans la tolérance, bouche sur un canon ; premier essai de ce lot, planche eclat64-e05, refusé).
    Chaque pixel opaque (alpha ≥ 0,5) porte s = projection de son centre + demi-largeur le long du tir (bord avant) ;
    les « lignes » sont des bandes de la largeur d'un pixel en travers ; rangées = bandes contiguës dont le s maximal
    est à TOL_CANON px d'écran au plus du plus avancé. Aux 4 directions cardinales, les bandes sont les lignes ou les
    colonnes de pixels : résultat IDENTIQUE à bouche() (contrôlé à chaque passage par main())."""
    P = PROJ_IMAGE
    wx, wy = direction_sol(nom)
    vx, vy = -wy, wx
    ys, xs = np.nonzero(alpha >= 128)
    px, py = xs + 0.5, (ys + 0.5) / P
    s = px * wx + py * wy + 0.5 * (abs(wx) + abs(wy) / P)
    t = px * vx + py * vy
    bw = abs(vx) + abs(vy) / P            # largeur d'un pixel d'écran en travers (1 en N/S, 1/P en E/O)
    b = np.floor(t / bw + 1e-9).astype(np.int64)
    b0 = int(b.min())
    r = np.full(int(b.max()) - b0 + 1, -np.inf)
    np.maximum.at(r, b - b0, s)
    sm = r.max()
    cand = r >= sm - (TOL_CANON if tol is None else tol) * math.sqrt(wx * wx + (wy / P) ** 2)
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
    a, z = rr[0], rr[-1]
    trans = ((a[0] + a[1] + 1) / 2.0 + (z[0] + z[1] + 1) / 2.0) / 2.0
    bout = (a[2] + z[2]) / 2.0
    trans *= bw
    x, y = bout * wx + trans * vx, (bout * wy + trans * vy) * P
    return float((gauche + x) / 64.0), float((haut + y) / 64.0)


def point_moteur_u(centre_y, dist, u):
    """Règle du moteur (F126) pour une cible lointaine dans la direction d'écran u : projectile_center + distance ×
    u / |(ux, uy / K)|."""
    ux, uy = u
    n = math.sqrt(ux * ux + (uy / K_PROJ) ** 2)
    return dist * ux / n, centre_y + dist * uy / n


def eclat_visible_u(centre_y, dist, u):
    x, y = point_moteur_u(centre_y, dist, u)
    return x, y - H_ECLAT


def marges_u(bouches, unites, centre_y, dist):
    """Pour chaque pose : (marge le long du tir = éclat visible − bouche dessinée, écart transverse)."""
    res = {}
    for d, (bx, by) in sorted(bouches.items()):
        ux, uy = unites[d]
        vx, vy = eclat_visible_u(centre_y, dist, (ux, uy))
        res[d] = ((vx - bx) * ux + (vy - by) * uy, (vx - bx) * uy - (vy - by) * ux)
    return res


def ajuste_tir_u(bouches, unites, marge):
    """projectile_center.y et projectile_creation_distance au sens des moindres carrés sur TOUTES les poses données
    (même système qu'ajuste_tir() aux 4 directions cardinales)."""
    A, b = [], []
    for d, (bx, by) in sorted(bouches.items()):
        ux, uy = unites[d]
        n = math.sqrt(ux * ux + (uy / K_PROJ) ** 2)
        tx, ty = bx + marge * ux, by + marge * uy
        if ux:
            A.append([0.0, ux / n]); b.append(tx)
        A.append([1.0, uy / n]); b.append(ty + H_ECLAT)
    sol = np.linalg.lstsq(np.array(A), np.array(b), rcond=None)[0]
    return float(sol[0]), float(sol[1])


def ecarts_de(mm, marge):
    return {d: [round(m[0] - marge, 4), round(m[1], 4)] for d, m in sorted(mm.items())}


def pire_de(ecarts):
    return max((v[0] ** 2 + v[1] ** 2) ** 0.5 for v in ecarts.values())


REJET_MIN = 0.25        # tuile : une direction n'est écartée du réglage que si son écart dépasse ce seuil…
REJET_MED = 3.0         # … ET REJET_MED fois l'écart médian des directions gardées
GARDE_MIN = 0.75        # part minimale des directions gardées, sinon refus de l'âge


def ajuste_robuste(bouches, unites, marge):
    """Réglage à 64 directions, robuste aux bouches MAL MESURÉES (lot A3-jeu). Fait : avec apply_projection et
    K = PROJ_IMAGE, la règle du moteur (F126) donne, pour une cible lointaine, exactement le mouvement d'un point qui
    TOURNE avec la tête (centre + distance × (sin θ, −0,7071·cos θ)) : une seule bouche par âge convient à toutes les
    directions. Une direction dont l'écart sort de la tendance vient donc d'une mesure fausse (un organe ou un coin
    de la coque plus avancé que les canons dans cette vue : âge 2, d07 à d10, planche eclat64-e02), pas du moteur.
    Itération : moindres carrés sur les directions gardées ; on écarte celles dont l'écart dépasse REJET_MIN tuile ET
    REJET_MED × la médiane des gardées ; jusqu'à stabilité. Rend (centre_y, distance, écarts de TOUTES les directions,
    liste triée des directions écartées)."""
    garde = sorted(bouches)
    for _ in range(10):
        cy, dist = ajuste_tir_u({d: bouches[d] for d in garde}, unites, marge)
        ec = ecarts_de(marges_u(bouches, unites, cy, dist), marge)
        norme = {d: (v[0] ** 2 + v[1] ** 2) ** 0.5 for d, v in ec.items()}
        med = float(np.median([norme[d] for d in garde]))
        seuil = max(REJET_MIN, REJET_MED * med)
        nouveau = sorted(d for d in bouches if norme[d] <= seuil)
        if nouveau == garde:
            break
        garde = nouveau
    return cy, dist, ec, sorted(set(bouches) - set(garde))


def ecartees_ok_de(spec):
    """« eNN-dKK,… » -> {âge: ensemble de « dKK »} (directions écartées admises après regard)."""
    res = {}
    for x in sorted(spec):
        e, dn = x.split("-")
        res.setdefault(int(e[1:]), set()).add(dn)
    return res


def eclat_64_precontrole(e, liste, ok_e, seuil, marge):
    """Avant de bâtir les feuilles d'un âge à 64 directions (correction M-1 du lot A3-jeu) : bouches des 64 poses (même
    calcul que dans la boucle des couches : bouche_u sur l'alpha de la couche principale), réglage robuste, écartées.
    Rend (motif de repli ou None, résumé). Motifs : direction écartée non regardée (absente de ok_e), ou plus de
    (1 − GARDE_MIN) × 64 directions écartées. Le résumé donne aussi le réglage SANS exclusion (règle stricte)."""
    bouches, unites = {}, {}
    for dname, nom, dsrc, _ in liste:
        s, d = lire_spec(dsrc, nom)
        L = s["layers"]["main"]
        gx, gy, _, _ = boite_px(L)
        bouches[dname] = bouche_u(rgba(os.path.join(d, L["file"]))[..., 3], gx, gy, dname)
        unites[dname] = unite_pose(dname)
    _, _, _, rejet = ajuste_robuste(bouches, unites, marge)
    cy0, d0 = ajuste_tir_u(bouches, unites, marge)
    ec0 = ecarts_de(marges_u(bouches, unites, cy0, d0), marge)
    pire0 = max(ec0, key=lambda k: ec0[k][0] ** 2 + ec0[k][1] ** 2)
    resume = {"ecartees": rejet, "sans_exclusion": {"tir": [round(cy0, 5), round(d0, 5)],
                                                    "ecart_max": round(pire_de(ec0), 4), "pire_direction": pire0,
                                                    "refuse_par_le_seuil": pire_de(ec0) > seuil}}
    non_vues = [dn for dn in rejet if dn not in ok_e]
    if len(rejet) > (1 - GARDE_MIN) * NDIR64:
        return "éclat : %d directions écartées du réglage (plus de %d)" % (len(rejet), (1 - GARDE_MIN) * NDIR64), resume
    if non_vues:
        return "éclat : direction(s) écartée(s) NON REGARDÉE(S) %s (ECLAT_ECARTEES_OK_DEFAUT)" % ",".join(
            non_vues), dict(resume, non_vues=non_vues)
    return None, resume


# ------------------------------------------------------------------ têtes de la production A3 (lot A3-jeu)
def etat_a3(a3, nom, hors_regle_ok=()):
    """« faite » si la tête de production A3 est complète et contrôlée : même règle que produire_a3.etat (controle.json
    « ok », chaque fichier au sha256 du contrôle), plus : aucun trou « HORS REGLE » (sauf nom dans hors_regle_ok)."""
    d = os.path.join(a3, nom)
    if not os.path.exists(os.path.join(d, "spec.json")):
        return "absente"
    c = os.path.join(d, "controle.json")
    if not os.path.exists(c):
        return "pas de controle.json"
    try:
        cj = json.load(open(c, encoding="utf-8"))
    except ValueError:
        return "controle.json illisible"
    if not cj.get("ok") or cj.get("variant") != nom:
        return "contrôle en échec"
    if not cj.get("fichiers"):
        return "contrôle sans fichiers"
    for f, h in sorted(cj["fichiers"].items()):
        p = os.path.join(d, f)
        if not os.path.exists(p):
            return "%s absent" % f
        if sha_file(p) != h:
            return "%s modifié depuis le contrôle" % f
    if (cj.get("trous") or {}).get("verdict") not in ("OK", "ACCEPTE") and nom not in hors_regle_ok:
        return "trous %s" % (cj.get("trous") or {}).get("verdict")
    return "faite"


def poses_64(e, dv, so, a3, hors_regle_ok=()):
    """Les 64 poses de l'âge e : liste de (« dKK », nom de la source, dossier, origine) ; ou (None, motif)."""
    poses, manque = [], []
    for k in range(NDIR64):
        if k == 0:
            poses.append(("d00", "e%02d-tete-N" % e, dv, "V"))
        elif k == 16:
            poses.append(("d16", "e%02d-tete-E" % e, dv, "V"))
        elif k in (32, 48):
            poses.append(("d%02d" % k, "e%02d-tete-d%02d" % (e, k), so, "A2"))
        else:
            nom = "e%02d-tete-d%02d" % (e, k)
            et = etat_a3(a3, nom, hors_regle_ok)
            if et != "faite":
                manque.append("%s (%s)" % (nom, et))
            poses.append(("d%02d" % k, nom, a3, "A3"))
    if manque:
        return None, "%d tête(s) A3 sur 60 manquent ou ne sont pas contrôlées, dont %s" % (len(manque), manque[0])
    return poses, None


def bouches_vanille(data_dir):
    V = VANILLE["tete_hr"]
    res = {}
    for d, k in (("N", 0), ("E", 16), ("S", 32), ("O", 48)):
        bande, ligne = divmod(k, V["par_bande"])
        p = os.path.join(data_dir, "base", "graphics", "entity", "gun-turret", "hr-gun-turret-shooting-%d.png" % (bande + 1))
        im = rgba(p)
        cad = im[ligne * V["h"]:(ligne + 1) * V["h"], 0:V["w"]]
        # by_pixel(x, y) = x/32 tuile ; en px hr (64/tuile) : 2x. Shift hr vanilla = by_pixel(0, -27.5) -> -55 px hr.
        gauche = V["shift_px"][0] * 2 - V["w"] / 2
        haut = V["shift_px"][1] * 2 - V["h"] / 2
        res[d] = bouche(cad[..., 3], gauche, haut, d, TOL_VANILLE)
    return res


def lua_value(v, ind=""):
    if isinstance(v, dict):
        items = []
        for k in sorted(v, key=lambda x: (isinstance(x, str), x)):
            if isinstance(k, int):
                key = "[%d]" % k
            else:
                key = k if k.isidentifier() else '["%s"]' % k
            items.append("%s  %s = %s" % (ind, key, lua_value(v[k], ind + "  ")))
        return "{\n" + ",\n".join(items) + "\n" + ind + "}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_value(x, ind) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return repr(v) if not v.is_integer() else str(int(v))
    return '"%s"' % v


def texte_lua(donnees):
    return ("-- FICHIER GÉNÉRÉ par tools/render/pieces/levels/gun_e/feuilles.py (lots A2 et A3-jeu) : ne pas modifier à\n"
            "-- la main. Tailles en pixels, shift en tuiles. hr = 64 px/tuile (scale 0,5), normale = 32 px/tuile.\n"
            "-- Têtes (RotatedAnimation), selon l'âge : direction_count 64, feuille de 8 × 8 images d00 à d63 rangée par\n"
            "-- rangée (line_length 8, rotation uniforme, apply_projection vrai : F121) ; ou, en repli, direction_count 4,\n"
            "-- feuille en COLONNE N, E, S, O (line_length 1, F123). Images : MANIFEST.json (hors de git, D-6) ;\n"
            "-- régénérer : voir MANIFEST.json, « commande ».\n"
            "return ") + lua_value(donnees) + "\n"


def pour_lua(donnees):
    """Données de sprites.lua (jeu) tirées de sprites.json : sans les sous-tables des outils (« poses » de chaque
    couche de tête, « outils » de chaque âge), clés d'âge entières."""
    pl = json.loads(json.dumps(donnees))
    for e, A in pl["ages"].items():
        A.pop("outils", None)
        for lay, cd in A.get("tete", {}).items():
            cd.pop("poses", None)
    pl["ages"] = {int(k): v for k, v in pl["ages"].items()}
    return pl


def couche_def(fichier_hr, fichier_lr, w, h, shift):
    return {"hr": {"filename": GRAPHICS_PREFIX + fichier_hr, "width": w, "height": h, "shift": [shift[0], shift[1]]},
            "lr": {"filename": GRAPHICS_PREFIX + fichier_lr, "width": w // 2, "height": h // 2,
                   "shift": [shift[0], shift[1]]}}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default=DEST_DEFAUT)
    ap.add_argument("--valide", action="append", default=None)
    ap.add_argument("--so", default=SO_DEFAUT)
    ap.add_argument("--a3", default=A3_DEFAUT, help="têtes de la production A3 (64 directions)")
    ap.add_argument("--ages-64", default="auto",
                    help="auto : tout âge dont les 64 poses sont là et contrôlées ; aucun : repli à 4 partout ; "
                         "LISTE (ex. 2,5) : ces âges seulement (refus si l'un est incomplet)")
    ap.add_argument("--hors-regle-ok", default="",
                    help="têtes A3 « HORS REGLE » acceptées après regard (noms, virgules), EN PLUS de "
                         "HORS_REGLE_OK_DEFAUT ; « aucun » : aucune, pas même celles de la liste par défaut")
    ap.add_argument("--ecartees-ok", default="",
                    help="directions d'éclat écartées admises après regard (« eNN-dKK », virgules), EN PLUS de "
                         "ECLAT_ECARTEES_OK_DEFAUT ; « aucun » : aucune (un âge qui en écarte reste à 4 directions)")
    ap.add_argument("--data", default=DATA_DEFAUT)
    ap.add_argument("--socle-anime", default=SOCLE_ANIME_DEFAUT,
                    help="socles émissifs animés (lot A4, anime_socle.py : <dossier>/eNN-socle-anime) ; « aucun » : "
                         "socles fixes partout")
    ap.add_argument("--seuil", type=float, default=SEUIL_ECLAT, help="seuil de refus de l'éclat (essai du refus)")
    a = ap.parse_args()
    valides = plages(a.valide or VALIDES_DEFAUT)
    if a.hors_regle_ok.strip() == "aucun":
        hors_regle_ok = ()
    else:
        hors_regle_ok = tuple(sorted(set(HORS_REGLE_OK_DEFAUT) | set(x for x in a.hors_regle_ok.split(",") if x)))
    if a.ecartees_ok.strip() == "aucun":
        ecartees_ok = ()
    else:
        ecartees_ok = tuple(sorted(set(ECLAT_ECARTEES_OK_DEFAUT) | set(x for x in a.ecartees_ok.split(",") if x)))
    ok_par_age = ecartees_ok_de(ecartees_ok)
    if a.ages_64 not in ("auto", "aucun"):
        voulus64 = set(int(x) for x in a.ages_64.split(",") if x)
    else:
        voulus64 = None
    dest = os.path.abspath(a.dest)
    os.makedirs(dest, exist_ok=True)
    for f in os.listdir(dest):
        if f.endswith(".png"):
            os.remove(os.path.join(dest, f))
    sources = {}
    ages = {}
    union = {}

    def copie(d, L):
        """Copie octet à octet d'un PNG validé (hr et normale) ; rend la définition."""
        for LL in (L, L["lr"]):
            shutil.copyfile(os.path.join(d, LL["file"]), os.path.join(dest, LL["file"]))
        return couche_def(L["file"], L["lr"]["file"], L["width"], L["height"], L["shift"])

    def note_source(nom, s, d):
        sources[nom] = {"dossier": d, "spec_sha256": sha_file(os.path.join(d, "spec.json")),
                        "couches": {lay: {"hr": L["sha256"], "lr": L["lr"]["sha256"]} for lay, L in s["layers"].items()},
                        "echantillons": s["samples"], "trous_px": s["checks"]["largest_hole_px"],
                        "bouchon_arriere": (s.get("count") or {}).get("bouchon_arriere", 0)}
        if s.get("samples_passes"):
            # D-7 (lot A3) : échantillons de certaines passes (ombre à 32) ; m-9 de la vérification d'A3
            sources[nom]["samples_passes"] = s["samples_passes"]

    # âge 1 : pièce posée sous la mitrailleuse vanilla
    s, d = lire_spec(valides[1], "e01-piece")
    note_source("e01-piece", s, d)
    ages[1] = {"piece": {lay: copie(d, s["layers"][lay]) for lay in FIXE_COUCHES if lay in s["layers"]}}
    vb = bouches_vanille(a.data)
    # marge étalonnée sur la vanilla : où son éclat visible tombe, le long du tir, par rapport au bout de ses canons
    mv = marges(vb, VANILLE["projectile_center"][1], VANILLE["projectile_creation_distance"])
    marge = sum(mv[d][0] for d in MARGE_DIRS) / len(MARGE_DIRS)
    ecarts_vanille = {d: [round(m[0] - marge, 4), round(m[1], 4)] for d, m in sorted(mv.items())}
    refus = []
    bilan_dirs = []
    pre_eclat = {}

    for e in range(2, 16):
        dv = valides[e]
        A = {}
        for part in ("socle", "piece"):
            nom = "e%02d-%s" % (e, part)
            s, d = lire_spec(dv, nom)
            note_source(nom, s, d)
            A[part] = {lay: copie(d, s["layers"][lay]) for lay in FIXE_COUCHES if lay in s["layers"]}
        # socle émissif ANIMÉ (lot A4) : lueur et halo en feuilles de N images (anime_socle.py), si l'âge en a un dans
        # --socle-anime ; les autres âges gardent le socle fixe
        nom_a = "e%02d-socle-anime" % e
        if a.socle_anime != "aucun" and os.path.exists(os.path.join(a.socle_anime, nom_a, "spec.json")):
            s, d = lire_spec(a.socle_anime, nom_a)
            note_source(nom_a, dict(s, checks={"largest_hole_px": 0}), d)
            A["socle_anime"] = {}
            for lay in ("glow", "light"):
                L = s["layers"][lay]
                cd = copie(d, L)
                for r in ("hr", "lr"):
                    cd[r]["frame_count"] = L["frame_count"]
                    cd[r]["line_length"] = L["line_length"]
                    cd[r]["animation_speed"] = s["animation_speed"]
                A["socle_anime"][lay] = cd
        # poses de la tête : 64 directions si l'âge est complet et contrôlé, sinon repli à 4 (lot A2)
        repli = None
        liste = None
        if a.ages_64 == "aucun":
            repli = "repli demandé (--ages-64 aucun)"
        elif voulus64 is not None and e not in voulus64:
            repli = "âge hors de --ages-64"
        else:
            liste, repli = poses_64(e, dv, a.so, a.a3, hors_regle_ok)
            if liste is None and voulus64 is not None:
                raise SystemExit("[FO-FEUILLES] âge %d demandé à 64 directions mais incomplet : %s" % (e, repli))
            if liste is not None:
                # correction M-1 : toute direction écartée du réglage de l'éclat doit avoir été REGARDÉE, sinon repli
                motif, pre = eclat_64_precontrole(e, liste, ok_par_age.get(e, set()), a.seuil, marge)
                pre_eclat[e] = pre
                if motif:
                    print("[FO-FEUILLES] âge %d : %s ; sans exclusion : écart max %.3f (%s)%s ; regarder "
                          "eclat64.py --ages %d --couleur --planche <dossier>, puis inscrire les directions vues" % (
                              e, motif, pre["sans_exclusion"]["ecart_max"], pre["sans_exclusion"]["pire_direction"],
                              " > seuil" if pre["sans_exclusion"]["refuse_par_le_seuil"] else "", e))
                    if voulus64 is not None:
                        raise SystemExit("[FO-FEUILLES] âge %d demandé à 64 directions : %s" % (e, motif))
                    liste, repli = None, motif
        if liste is None:
            liste = [(dname, "e%02d-%s" % (e, part), dv if part in ("tete-N", "tete-E") else a.so,
                      "V" if part in ("tete-N", "tete-E") else "A2") for dname, part in DIRECTIONS]
        n_dirs = len(liste)
        cols = 1 if n_dirs == 4 else LIGNE64
        rows = n_dirs // cols
        poses = []
        for dname, nom, dsrc, origine in liste:
            s, d = lire_spec(dsrc, nom)
            if origine == "A3" and s.get("samples_passes") != SAMPLES_PASSES_A3:
                raise SystemExit("%s : samples_passes %s, attendu %s (D-7)" % (nom, s.get("samples_passes"),
                                                                                SAMPLES_PASSES_A3))
            note_source(nom, s, d)
            poses.append((dname, nom, s, d))
        tete = {}
        bouches = {}
        for lay in TETE_COUCHES:
            presentes = [p for p in poses if lay in p[2]["layers"]]
            if not presentes:
                continue
            boites = {p[1]: boite_px(p[2]["layers"][lay]) for p in presentes}
            L0 = min(b[0] for b in boites.values())
            T0 = min(b[1] for b in boites.values())
            R0 = max(b[2] for b in boites.values())
            B0 = max(b[3] for b in boites.values())
            W, H = R0 - L0, B0 - T0
            if cols * W > LIMITE_PX or rows * H > LIMITE_PX:
                raise SystemExit("[FO-FEUILLES] âge %d tête %s : feuille %d × %d px, au-delà de %d (F144)" % (
                    e, lay, cols * W, rows * H, LIMITE_PX))
            hr = np.zeros((rows * H, cols * W, 4), np.uint8)
            lr = np.zeros((rows * H // 2, cols * W // 2, 4), np.uint8)
            cellules = {}
            for k, (dname, nom, s, d) in enumerate(poses):
                if lay not in s["layers"]:
                    continue
                L = s["layers"][lay]
                gx, gy, rx, by = boites[nom]
                ih = rgba(os.path.join(d, L["file"]))
                il = rgba(os.path.join(d, L["lr"]["file"]))
                assert ih.shape[:2] == (L["height"], L["width"]), nom
                assert il.shape[:2] == (L["height"] // 2, L["width"] // 2), nom
                cx, cy = (k % cols) * W, (k // cols) * H
                y0, x0 = cy + gy - T0, cx + gx - L0
                hr[y0:y0 + ih.shape[0], x0:x0 + ih.shape[1]] = ih
                y0l, x0l = y0 // 2, x0 // 2
                lr[y0l:y0l + il.shape[0], x0l:x0l + il.shape[1]] = il
                cellules[dname] = {"source": nom, "x": gx - L0, "y": gy - T0}
                if n_dirs != 4:
                    cellules[dname]["k"] = k
                if lay == "main":
                    if n_dirs == 4:
                        bouches[dname] = bouche(ih[..., 3], gx, gy, dname)
                    else:
                        bouches[dname] = bouche_u(ih[..., 3], gx, gy, dname)
                for kind in ("main", "glow"):
                    if lay == kind:
                        u = union.setdefault(e, [1e9, 1e9, -1e9, -1e9])
                        u[0], u[1] = min(u[0], gx / 64.0), min(u[1], gy / 64.0)
                        u[2], u[3] = max(u[2], rx / 64.0), max(u[3], by / 64.0)
            fh, fl = "hr-gun-e%02d-tete-%s.png" % (e, lay), "gun-e%02d-tete-%s.png" % (e, lay)
            ecrire_png(hr, os.path.join(dest, fh))
            ecrire_png(lr, os.path.join(dest, fl))
            shift = ((L0 + R0) / 2.0 / 64.0, (T0 + B0) / 2.0 / 64.0)
            cd = couche_def(fh, fl, W, H, shift)
            for r in ("hr", "lr"):
                cd[r]["direction_count"] = n_dirs
                cd[r]["line_length"] = cols
            tete[lay] = cd
            # placement de chaque pose dans sa cellule (outil de contrôle : check_gun_sheets.py --sources)
            tete[lay]["poses"] = cellules
        A["tete"] = tete
        # boîte d'affichage : socle, pièce et toutes les poses de tête (couches principale et lueur)
        u = union.setdefault(e, [1e9, 1e9, -1e9, -1e9])
        for part in ("socle", "piece"):
            for lay in ("main", "glow"):
                if lay in A[part]:
                    h = A[part][lay]["hr"]
                    u[0] = min(u[0], h["shift"][0] - h["width"] / 128.0)
                    u[1] = min(u[1], h["shift"][1] - h["height"] / 128.0)
                    u[2] = max(u[2], h["shift"][0] + h["width"] / 128.0)
                    u[3] = max(u[3], h["shift"][1] + h["height"] / 128.0)
        A["boite"] = [[u[0], u[1]], [u[2], u[3]]]
        outils = {"directions": n_dirs, "noms": [p[0] for p in poses],
                  "origines": {o: sum(1 for x in liste if x[3] == o) for o in ("V", "A2", "A3")},
                  "repli": repli}
        if n_dirs == 4:
            # bouche (E68) : centre et distance ajustés sur les 4 directions (règle du moteur mesurée, marge vanilla)
            cy, dist = ajuste_tir(bouches, marge)
            cy, dist = round(cy, 5), round(dist, 5)
            mm = marges(bouches, cy, dist)
            ecarts = ecarts_de(mm, marge)
            vis = {d: [round(v, 5) for v in eclat_visible(cy, dist, d)] for d in sorted(bouches)}
            ecarts_ecrits = ecarts
        else:
            unites = {d: unite_pose(d) for d in bouches}
            # contrôle : aux 4 directions cardinales, bouche_u() = bouche() du lot A2
            card = {}
            for c, kk in sorted(CARDINAUX.items()):
                dn = "d%02d" % kk
                p = [x for x in poses if x[0] == dn][0]
                Lm = p[2]["layers"]["main"]
                gx, gy, _, _ = boite_px(Lm)
                al = rgba(os.path.join(p[3], Lm["file"]))[..., 3]
                b_old = bouche(al, gx, gy, c)
                if max(abs(b_old[0] - bouches[dn][0]), abs(b_old[1] - bouches[dn][1])) > 1e-9:
                    raise SystemExit("[FO-FEUILLES] âge %d : bouche_u(%s) %s ≠ bouche(%s) %s" % (
                        e, dn, bouches[dn], c, b_old))
                card[c] = b_old
            # AVANT : réglage du lot A2 (4 directions), évalué sur les 64
            cy4, dist4 = ajuste_tir(card, marge)
            cy4, dist4 = round(cy4, 5), round(dist4, 5)
            ec_av = ecarts_de(marges_u(bouches, unites, cy4, dist4), marge)
            # APRÈS : moindres carrés sur les 64 directions, bouches mal mesurées écartées (ajuste_robuste)
            cy, dist, _, rejet = ajuste_robuste(bouches, unites, marge)
            cy, dist = round(cy, 5), round(dist, 5)
            ecarts_tous = ecarts_de(marges_u(bouches, unites, cy, dist), marge)
            ecarts = {d: v for d, v in ecarts_tous.items() if d not in rejet}
            non_vues = [dn for dn in rejet if dn not in ok_par_age.get(e, set())]
            if non_vues or rejet != pre_eclat[e]["ecartees"]:
                refus.append("âge %d : écartées %s, précontrôle %s, non regardées %s (incohérence interne)" % (
                    e, rejet, pre_eclat[e]["ecartees"], non_vues))
            if len(ecarts) < GARDE_MIN * n_dirs:
                refus.append("âge %d : %d direction(s) sur %d écartées du réglage (bouche non mesurable) : %s" % (
                    e, len(rejet), n_dirs, rejet))
            vis = {d: [round(v, 5) for v in eclat_visible_u(cy, dist, unites[d])] for d in sorted(bouches)}
            ecarts_ecrits = ecarts_tous
            outils["eclat_avant"] = {"tir": {"projectile_creation_distance": dist4, "projectile_center": [0.0, cy4]},
                                     "ecart_max_4": round(pire_de({c: ec_av["d%02d" % CARDINAUX[c]]
                                                                   for c in CARDINAUX}), 4),
                                     "ecart_max_64": round(pire_de(ec_av), 4),
                                     "pire_direction": max(ec_av, key=lambda d: ec_av[d][0] ** 2 + ec_av[d][1] ** 2)}
            outils["eclat_apres"] = {"ecart_max_64": round(pire_de(ecarts), 4),
                                     "ecart_max_toutes": round(pire_de(ecarts_tous), 4),
                                     "ecart_max_4": round(pire_de({c: ecarts_tous["d%02d" % CARDINAUX[c]]
                                                                   for c in CARDINAUX}), 4),
                                     "pire_direction": max(ecarts, key=lambda d: ecarts[d][0] ** 2 + ecarts[d][1] ** 2),
                                     "ecartees": rejet,
                                     "ecartees_regardees": sorted(d for d in rejet if d in ok_par_age.get(e, set())),
                                     "ecarts_ecartees": {d: ecarts_tous[d] for d in rejet},
                                     # règle stricte de la consigne (aucune exclusion) : rappel chiffré, hors décision
                                     "sans_exclusion": pre_eclat[e]["sans_exclusion"]}
        pire = pire_de(ecarts)
        if pire > a.seuil:
            refus.append("âge %d : éclat à %.3f tuile de sa cible (seuil %.2f) ; pire direction %s %s" % (
                e, pire, a.seuil, max(ecarts, key=lambda d: ecarts[d][0] ** 2 + ecarts[d][1] ** 2),
                ecarts[max(ecarts, key=lambda d: ecarts[d][0] ** 2 + ecarts[d][1] ** 2)]))
        A["tir"] = {"projectile_creation_distance": dist, "projectile_center": [0.0, cy]}
        A["bouches"] = {k: [round(v[0], 5), round(v[1], 5)] for k, v in sorted(bouches.items())}
        A["eclat_visible"] = vis
        A["ecarts_bouche"] = ecarts_ecrits
        A["ecart_max"] = round(pire, 4)
        # icône : socle + tête E (pose validée tete-E = d16), composées en lumière linéaire, réduites
        A["icone"] = icone(dest, e, A, [p for p in poses if p[1] == "e%02d-tete-E" % e][0])
        A["outils"] = outils
        # éclat de tir 2D (lot A4) : couche draw_as_glow d'attacking_animation, bouts des canons MESURÉS sur la feuille
        # de tête qui vient d'être écrite, mêmes directions que la tête (64 ou repli à 4) : se régénère avec elle
        import eclat_tir  # noqa: E402  (import tardif : eclat_tir importe ce module)
        A["eclat"], outils["eclat_tir"], _, _ = eclat_tir.feuille_eclat(dest, e, A, marge)
        ages[e] = A
        bilan_dirs.append((e, n_dirs, outils["origines"], repli))
    imprime_tir(ages, vb, marge, ecarts_vanille)
    for e, n, org, repli in bilan_dirs:
        print("[FO-FEUILLES] âge %2d : %d directions (poses V %d, A2 %d, A3 %d)%s" % (
            e, n, org["V"], org["A2"], org["A3"], (" ; REPLI à 4 : " + repli) if n == 4 and repli else ""))
    if refus:
        for r in refus:
            print("[FO-FEUILLES] REFUS " + r)
        raise SystemExit("[FO-FEUILLES] éclat de tir hors des canons : %d âge(s) refusé(s) (E68)" % len(refus))
    donnees = {"directions": ["N", "E", "S", "O"], "ages": ages,
               "eclat": {"k_proj": K_PROJ, "hauteur": H_ECLAT, "marge": round(marge, 5), "seuil": SEUIL_ECLAT,
                         "tol_canon_px": TOL_CANON},
               "vanille": {"bouches": {k: [round(v[0], 5), round(v[1], 5)] for k, v in sorted(vb.items())},
                           "ecarts_bouche": ecarts_vanille,
                           "projectile_creation_distance": VANILLE["projectile_creation_distance"],
                           "projectile_center": list(VANILLE["projectile_center"])}}
    # les sous-tables « poses » et « outils » restent dans sprites.json (outils), pas dans sprites.lua (jeu)
    with open(os.path.join(dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(texte_lua(pour_lua(donnees)))
    with open(os.path.join(dest, "sprites.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(donnees, f, indent=1, sort_keys=True)
    fichiers = {}
    for f in sorted(os.listdir(dest)):
        if f.endswith(".png"):
            p = os.path.join(dest, f)
            with Image.open(p) as im:
                w, h = im.size
            fichiers[f] = {"taille": os.path.getsize(p), "sha256": sha_file(p), "largeur": w, "hauteur": h}
    manifeste = {"commande": COMMANDE, "outil": "tools/render/pieces/levels/gun_e/feuilles.py",
                 "arguments": sys.argv[1:], "hors_regle_ok": list(hors_regle_ok),
                 "eclat_ecartees_ok": list(ecartees_ok),
                 "controle": "py -3.9 tools/render/pieces/levels/gun_e/check_gun_sheets.py [--sources]",
                 "git": "PNG hors de git (.gitignore : graphics/levels/gun/*.png, décision D-6) ; ce manifeste, "
                        "sprites.lua et sprites.json sont commités",
                 "directions": {str(e): n for e, n, _, _ in bilan_dirs},
                 "sources": sources, "fichiers": fichiers,
                 "sprites_lua_sha256": sha_file(os.path.join(dest, "sprites.lua")),
                 "sprites_json_sha256": sha_file(os.path.join(dest, "sprites.json"))}
    with open(os.path.join(dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifeste, f, indent=1, sort_keys=True)
    tot = sum(v["taille"] for v in fichiers.values())
    n64 = sum(1 for _, n, _, _ in bilan_dirs if n == NDIR64)
    print("[FO-FEUILLES] %d fichiers PNG, %.2f Mo, %d sources ; têtes : %d âge(s) à 64 directions, %d à 4 ; dest %s" % (
        len(fichiers), tot / 1e6, len(sources), n64, len(bilan_dirs) - n64, dest))
    print("[FO-FEUILLES] boîtes : " + " ; ".join("âge %d %s" % (e, [[round(x, 3) for x in c] for c in ages[e]["boite"]])
                                                  for e in range(2, 16)))
    return 0


def imprime_tir(ages, vb, marge, ecarts_vanille):
    print("[FO-FEUILLES] éclat (E68) : K_PROJ %.4f, hauteur %.2f, marge vanilla %.4f tuile, seuil %.2f ; vanilla : "
          "bouches %s, écarts (le long, transverse) %s" % (K_PROJ, H_ECLAT, marge, SEUIL_ECLAT,
                                                           {k: [round(v[0], 4), round(v[1], 4)] for k, v in sorted(vb.items())},
                                                           ecarts_vanille))
    for e in sorted(ages):
        A = ages[e]
        if "tir" not in A:
            continue
        eb = A["ecarts_bouche"]
        if "E" in eb:
            print("[FO-FEUILLES] âge %2d tir %s ; écarts (le long, transverse) E %s N %s S %s O %s ; max %.3f" % (
                e, A["tir"], eb["E"], eb["N"], eb["S"], eb["O"], A["ecart_max"]))
        else:
            o = A["outils"]
            av, ap = o["eclat_avant"], o["eclat_apres"]
            print("[FO-FEUILLES] âge %2d tir %s (64 directions) ; écart max sur 64 : AVANT (réglage A2 %s) %.3f "
                  "(pire %s ; sur les 4 cardinales %.3f) -> APRÈS %.3f (pire %s %s ; sur les 4 cardinales %.3f)" % (
                      e, A["tir"], av["tir"], av["ecart_max_64"], av["pire_direction"], av["ecart_max_4"],
                      ap["ecart_max_64"], ap["pire_direction"], eb[ap["pire_direction"]], ap["ecart_max_4"]))
            se = ap["sans_exclusion"]
            print("[FO-FEUILLES] âge %2d éclat : %d direction(s) écartée(s) du réglage %s, toutes regardées %s ; écart "
                  "max des écartées %.3f ; SANS exclusion (règle stricte) : %.3f (%s)%s" % (
                      e, len(ap["ecartees"]), ap["ecartees"], ap["ecartees_regardees"] == ap["ecartees"],
                      pire_de(ap["ecarts_ecartees"]) if ap["ecartees"] else 0.0, se["ecart_max"],
                      se["pire_direction"], " : AU-DELÀ DU SEUIL, l'âge ne passe que par la liste regardée"
                      if se["refuse_par_le_seuil"] else ""))


def icone(dest, e, A, pose_e):
    def charge(d, L):
        return rgba(os.path.join(d, L["file"])).astype(np.float64) / 255.0, boite_px(L)
    # socle : depuis la copie dans dest (mêmes octets que la source)
    sm = A["socle"]["main"]["hr"]
    socle = rgba(os.path.join(dest, os.path.basename(sm["filename"]))).astype(np.float64) / 255.0
    sb = boite_px({"width": sm["width"], "height": sm["height"], "shift": sm["shift"], "file": sm["filename"]})
    dname, nom, s, d = pose_e            # tête E (pose validée tete-E, d16)
    tete, tb = charge(d, s["layers"]["main"])
    L0, T0 = min(sb[0], tb[0]), min(sb[1], tb[1])
    R0, B0 = max(sb[2], tb[2]), max(sb[3], tb[3])
    can_s = np.zeros((B0 - T0, R0 - L0, 4))
    can_t = np.zeros_like(can_s)
    can_s[sb[1] - T0:sb[3] - T0, sb[0] - L0:sb[2] - L0] = socle
    can_t[tb[1] - T0:tb[3] - T0, tb[0] - L0:tb[2] - L0] = tete
    comp = P.over(can_t, can_s)
    strip = P.icon_strip(comp)
    f = "gun-e%02d-icone.png" % e
    ecrire_png(P.to_u8(strip), os.path.join(dest, f))
    return {"filename": GRAPHICS_PREFIX + f, "icon_size": 64, "icon_mipmaps": 4}


if __name__ == "__main__":
    sys.exit(main())
