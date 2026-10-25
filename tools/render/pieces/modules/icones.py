"""ICÔNES DES MODULES (lot MOD-V, 25/10) : 3 types x 10 paliers, rendu 2D procédural maîtrisé (numpy, Pillow, scipy).

Pourquoi pas Blender : une icône se juge à 32 px dans l'inventaire ; le chiffre du palier doit y tomber AU PIXEL (gravure
dessinée à la main sur la grille de 32 px), ce qu'un rendu 3D réduit ne garantit pas. La FORME est donc décrite par des
champs de distance signée (SDF) à 512 px, éclairée comme un relief (hauteur -> normales -> lumière du nord-ouest,
spéculaire selon la rugosité et la métallicité de la matière de l'âge), puis réduite par moyenne de boîtes en lumière
LINÉAIRE ; la plaque du palier est posée ensuite, au pixel, à 64 et 32 px. Aucun hasard : deux passages donnent les
mêmes octets.

COULEURS (lot MOD-3, décision D-17 du DC, 25/10 : « Couleur par type ») : le CORPS du module a la couleur de son TYPE
(TYPE_COULEURS : bleu vitesse, orange productivité, vert efficacité), plus sombre au palier 1, pleine au palier 10.
Les teintes des BALISES (beacon_tint) restent celles de l'ÂGE qui débloque le palier (D-17 : « Couleur de l'âge ») :
celles des âges (tools/render/pieces/levels/commun/ages.py), lues en appelant ages.matieres() avec une fausse fonction
metal() qui RELÈVE les couleurs (rgb linéaires, rugosité, métallicité) sans Blender ; palier 1 -> époque 6 ; 2 à 5 ->
10 ; 6 à 10 -> 14 (shared/content/epochs.lua). Lot MOD-V (version 1) : corps aux couleurs de l'âge (roles_age).

FORMES (le type se lit à la silhouette ET à la couleur) :
  - vitesse      : CHEVRON pointé vers la droite (« > »), cœur lumineux à la pointe ;
  - productivité : ENGRENAGE à 8 dents, cœur lumineux au moyeu (D-17, réponse à MOD-V Q3 ; la croix « + » du 2e jet de
                   MOD-V est gardée pour mémoire, geo_productivite) ;
  - efficacité   : FEUILLE en diagonale (pointe en haut à droite, tige en bas à gauche), nervure lumineuse.
MONTÉE DU PALIER : chiffre romain gravé sur une plaque en HAUT À GAUCHE (au pixel à 32 px, vecteur à 64 px et dans les
technologies ; D-17 : « Garder le romain ») ; éclat du cœur et halo qui croissent de 1 à 10 ; pièces en nombre = rang
dans la génération (paliers 2 à 5 : 1 à 4 VOYANTS ; 6 à 10 : 1 à 5 ÉTOILES), à la lumière du type ; teinte du champ.

Sorties (dossier --out, par défaut graphics/modules du mod) :
  <objet>.png        icône d'objet 64 px + 3 mipmaps (bande 120 x 64), icon_size 64, icon_mipmaps 4 ;
  tech/<techno>.png  icône de technologie 256 px + 3 mipmaps (bande 480 x 256), icon_size 256, icon_mipmaps 4 ;
  MANIFEST.json      noms, tailles, sha256, version de l'outil, couleurs de balise (beacon_tint) par objet ;
  icons.lua          même table pour l'étape data (chemins, beacon_tint), relue par prototypes/modules.lua.
Usage :
  py -3.9 tools/render/pieces/modules/icones.py                 # écrit graphics/modules (30 + 30 fichiers)
  py -3.9 tools/render/pieces/modules/icones.py --check         # régénère en mémoire et compare au MANIFEST (code 1 si écart)
  py -3.9 tools/render/pieces/modules/icones.py --planche <png>  # planche des 30 icônes à 32 et 64 px, fond sombre et clair
"""

import argparse
import hashlib
import io
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ICI = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.abspath(os.path.join(ICI, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(ICI, "..", "levels", "commun"))
import ages  # noqa: E402

VERSION = 2   # 2 : lot MOD-3 (D-17), couleurs par type, productivité en engrenage
N = 512          # résolution de travail (unités de dessin : 0 à 64)
U = N / 64.0     # pixels de travail par unité
TYPES = ("speed", "productivity", "effectivity")
VANILLA = {"speed": ("speed-module", "speed-module-2", "speed-module-3"),
           "productivity": ("productivity-module", "productivity-module-2", "productivity-module-3"),
           "effectivity": ("effectivity-module", "effectivity-module-2", "effectivity-module-3")}
# Époque qui débloque chaque palier (shared/content/epochs.lua, liste des époques : speed-module en 6 ; -2, -3, 4 et 5 en
# 10 ; 6 à 10 en 14). Contrôlé par tests : verifier_epoques() relit le fichier Lua.
EPOQUE = {1: 6, 2: 10, 3: 10, 4: 10, 5: 10, 6: 14, 7: 14, 8: 14, 9: 14, 10: 14}


def nom_objet(t, k):
    return VANILLA[t][k - 1] if k <= 3 else "fo-%s-module-%d" % (t, k)


def verifier_epoques():
    """Relit shared/content/epochs.lua : chaque objet de module figure dans la liste de l'époque attendue."""
    src = open(os.path.join(MOD, "shared", "content", "epochs.lua"), encoding="utf-8").read()
    import re
    pb = []
    for t in TYPES:
        for k in range(1, 11):
            nom = nom_objet(t, k)
            e = EPOQUE[k]
            m = re.search(r"\{\s*%d,\s*\{(.*?)\}\s*\}" % e, src, re.S)
            if not m or ('"%s"' % nom) not in m.group(1):
                pb.append("%s : absent de l'époque %d" % (nom, e))
    if pb:
        raise SystemExit("[FO-MODV] époques : " + " ; ".join(pb))
    return True


# ------------------------------------------------------------------------------------------------------------------
# Couleurs des âges (relevées sans Blender)
# ------------------------------------------------------------------------------------------------------------------
def matieres_age(e):
    rel = {}

    def metal(nom, rgb, **kw):
        rel[nom] = dict(rgb=tuple(rgb), rough=kw.get("rough", 0.4), met=kw.get("met", 0.2))
        return nom
    ages.matieres(e, metal, {})
    return rel


def roles_age(e):
    """Rôles du module dans l'âge e : champ (dominante), cadre (secondaire), logement, accent, lumière."""
    m = matieres_age(e)
    f = ages.FOYER[e]
    lum = tuple(f["rgb"])
    lum2 = tuple(f.get("rgb2") or f["rgb"])
    if e == 6:
        r = dict(champ=m["porcelaine_capot"], cadre=m["bleu_machine"], logement=m["fonte_bleue"],
                 accent=[m["porcelaine"]], plaque=m["fonte_bleue"])
    elif e == 10:
        r = dict(champ=m["blanc_casse"], cadre=m["gris_tech"], logement=m["anthracite"],
                 accent=[m["cable_r"], m["cable_b"]], plaque=m["anthracite"])
    elif e == 14:
        r = dict(champ=m["indigo_nuit"], cadre=m["blanc_lunaire"], logement=m["noir_spatial"],
                 accent=[], plaque=m["noir_spatial"])
    else:
        raise ValueError("âge sans rôles de module : %d" % e)
    r["lumiere"], r["lumiere2"] = lum, lum2
    r["age"] = e
    r["anneau"] = (e == 6)
    return r


# Lot MOD-3 (décision D-17 du DC, 25/10 : « Couleur par type ») : le CORPS du module prend la couleur de son TYPE (bleu
# vitesse, orange productivité, vert efficacité, les couleurs vanilla) ; la couleur ne dit plus l'âge. Le palier se lit
# au chiffre romain, à l'éclat du cœur et du halo, aux pièces (voyants de 2 à 5, étoiles de 6 à 10 : leur FORME suit
# encore la génération) et à une montée douce de la teinte du champ (plus sombre au palier 1, pleine au palier 10).
# Les teintes des BALISES restent celles de l'âge (beacon_tint, D-17 : « Couleur de l'âge »).
TYPE_COULEURS = {
    "speed": dict(champ=(0.10, 0.30, 0.85), cadre=(0.022, 0.065, 0.24), logement=(0.010, 0.022, 0.075),
                  lumiere=(0.35, 0.75, 1.0), lumiere2=(0.55, 0.85, 1.0)),
    "productivity": dict(champ=(0.85, 0.28, 0.04), cadre=(0.22, 0.065, 0.016), logement=(0.060, 0.018, 0.006),
                         lumiere=(1.0, 0.72, 0.22), lumiere2=(1.0, 0.85, 0.50)),
    "effectivity": dict(champ=(0.11, 0.58, 0.11), cadre=(0.022, 0.15, 0.032), logement=(0.008, 0.045, 0.012),
                        lumiere=(0.55, 1.0, 0.45), lumiere2=(0.75, 1.0, 0.65)),
}


def roles_type(t, k):
    """Rôles du module de type t, palier k (lot MOD-3) : mêmes clés que roles_age."""
    c = TYPE_COULEURS[t]
    e = eclat(k)
    montee = 0.62 + 0.38 * e
    champ = tuple(v * montee for v in c["champ"])
    r = dict(champ=dict(rgb=champ, rough=0.36, met=0.15), cadre=dict(rgb=c["cadre"], rough=0.42, met=0.30),
             logement=dict(rgb=c["logement"], rough=0.45, met=0.40), accent=[],
             plaque=dict(rgb=c["logement"], rough=0.45, met=0.40))
    r["lumiere"], r["lumiere2"] = tuple(c["lumiere"]), tuple(c["lumiere2"])
    r["age"] = EPOQUE[k]
    r["anneau"] = False
    return r


# ------------------------------------------------------------------------------------------------------------------
# Champs de distance signée (unités de 0 à 64 ; négatif dedans)
# ------------------------------------------------------------------------------------------------------------------
_c = (np.arange(N) + 0.5) / U
X, Y = np.meshgrid(_c, _c)


def sd_poly(pts):
    p = np.asarray(pts, float)
    d = (X - p[0, 0]) ** 2 + (Y - p[0, 1]) ** 2
    s = np.ones_like(X)
    n = len(p)
    for i in range(n):
        j = i - 1
        ex, ey = p[j, 0] - p[i, 0], p[j, 1] - p[i, 1]
        wx, wy = X - p[i, 0], Y - p[i, 1]
        t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0.0, 1.0)
        bx, by = wx - ex * t, wy - ey * t
        d = np.minimum(d, bx * bx + by * by)
        c1 = Y >= p[i, 1]
        c2 = Y < p[j, 1]
        c3 = ex * wy > ey * wx
        m = (c1 & c2 & c3) | (~c1 & ~c2 & ~c3)
        s = np.where(m, -s, s)
    return s * np.sqrt(d)


def sd_cercle(cx, cy, r):
    return np.hypot(X - cx, Y - cy) - r


def sd_segment(ax, ay, bx, by, r):
    ex, ey = bx - ax, by - ay
    wx, wy = X - ax, Y - ay
    t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0.0, 1.0)
    return np.hypot(wx - ex * t, wy - ey * t) - r


def sd_polyligne(pts, r):
    d = None
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        s = sd_segment(ax, ay, bx, by, r)
        d = s if d is None else np.minimum(d, s)
    return d


def sd_boite(x0, y0, x1, y1, r=0.0):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = np.abs(X - cx) - hx, np.abs(Y - cy) - hy
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def couv(sd):
    """Couverture anticrénelée (1 dedans, 0 dehors) d'un champ en unités."""
    return np.clip(0.5 - sd * U, 0.0, 1.0)


def profil(sd, largeur):
    """Biseau arrondi : 0 au bord, 1 à `largeur` unités dedans."""
    t = np.clip(-sd / largeur, 0.0, 1.0)
    return np.sqrt(1.0 - (1.0 - t) ** 2)


# ------------------------------------------------------------------------------------------------------------------
# Géométrie des trois types
# ------------------------------------------------------------------------------------------------------------------
CADRE = 3.6   # largeur du cadre (unités) : 2 px à 32 px


def geo_vitesse():
    pts = [(5.5, 6.5), (31.5, 6.5), (57.0, 32.0), (31.5, 57.5), (5.5, 57.5), (30.0, 32.0)]
    sil = sd_poly(pts) - 1.5
    champ = sil + CADRE
    # logement du cœur : chevron court près de la pointe
    log = sd_polyligne([(38.5, 21.5), (48.5, 32.0), (38.5, 42.5)], 4.0)
    coeur = sd_polyligne([(39.5, 23.5), (46.8, 32.0), (39.5, 40.5)], 1.9)
    # pièces : sur l'axe des bras, hors de la plaque (coin haut gauche) ; bras bas puis bras haut, de la queue à la pointe
    def bras(t, bas):
        return (18.5 + 25.5 * t, (57.5 - 25.5 * t) if bas else (6.5 + 25.5 * t))
    slots = [bras(0.14, True), bras(0.52, False), bras(0.33, True), bras(0.72, False), bras(0.52, True)]
    return dict(sil=sil, champ=champ, logement=log, coeur=coeur, coeur_centre=(45.0, 32.0), slots=slots,
                cables=[], nervure=None)


def _engrenage(cx, cy, n, r_pied, r_tete, f_tete, f_pied, arc=6):
    pts = []
    pas = 2 * math.pi / n
    for i in range(n):
        a0 = i * pas - math.pi / 2
        ang = [(a0 - f_pied * pas / 2, r_pied), (a0 - f_tete * pas / 2, r_tete), (a0 + f_tete * pas / 2, r_tete),
               (a0 + f_pied * pas / 2, r_pied)]
        for a, r in ang:
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        # arc du pied jusqu'à la dent suivante
        a_deb = a0 + f_pied * pas / 2
        a_fin = a0 + pas - f_pied * pas / 2
        for j in range(1, arc):
            a = a_deb + (a_fin - a_deb) * j / arc
            pts.append((cx + r_pied * math.cos(a), cy + r_pied * math.sin(a)))
    return pts


def geo_productivite():
    """CROIX « + » (le produit en plus). L'engrenage du premier jet (geo_productivite_engrenage, gardé pour mémoire) se
    confondait en mode Alt avec l'icône de recette de la roue dentée, affichée juste au-dessus des modules."""
    cx, cy = 32.0, 32.0
    bras = 12.0
    sil = np.minimum(sd_boite(3.0, cy - bras, 61.0, cy + bras, 4.0), sd_boite(cx - bras, 3.0, cx + bras, 61.0, 4.0))
    champ = sil + CADRE
    log = sd_cercle(cx, cy, 9.6)
    coeur = sd_cercle(cx, cy, 5.8)
    # pièces : une par bras (haut, droite, bas, gauche), puis une seconde sur le bras du haut
    slots = [(cx, cy - 14.5), (cx + 15.5, cy), (cx, cy + 15.5), (cx - 15.5, cy), (cx, cy - 23.0)]
    return dict(sil=sil, champ=champ, logement=log, coeur=coeur, coeur_centre=(cx, cy), slots=slots, cables=[],
                nervure=None)


def geo_productivite_engrenage():
    cx, cy = 31.0, 31.0
    sil = sd_poly(_engrenage(cx, cy, 8, 23.0, 29.0, 0.36, 0.56)) - 1.2
    champ = sil + CADRE
    # le champ ne suit pas les dents : couronne pleine sous le pied, cadre sur les dents
    champ = np.maximum(champ, sd_cercle(cx, cy, 20.5))
    log = sd_cercle(cx, cy, 10.5)
    coeur = sd_cercle(cx, cy, 6.2)
    # pièces sur un cercle autour du moyeu, hors de la plaque (haut gauche) et du nombre d'objets (bas droite) :
    # du haut, dans le sens des aiguilles d'une montre, puis le côté gauche
    slots = []
    for a_deg in (-80, -35, 10, 170, 125):
        a = math.radians(a_deg)
        slots.append((cx + 15.5 * math.cos(a), cy + 15.5 * math.sin(a)))
    return dict(sil=sil, champ=champ, logement=log, coeur=coeur, coeur_centre=(cx, cy), slots=slots, cables=[],
                nervure=None)


def geo_efficacite():
    # feuille OVALE : base arrondie (bas gauche), pointe (haut droite) ; demi-largeur w(u) = W sin(pi u^0,7), u de 0
    # (base) à 1 (pointe) : plus large vers le tiers de la base (2e jet : la lentille symétrique se lisait « plume »)
    ax, ay, bx, by = 10.5, 53.5, 57.5, 6.5
    L = math.hypot(bx - ax, by - ay)
    ux, uy = (bx - ax) / L, (by - ay) / L
    nx, ny = -uy, ux                                 # normale à l'axe
    W = 19.0

    def demi(u):
        return W * math.sin(math.pi * u ** 0.7)

    def pt(u, v):
        return (ax + ux * L * u + nx * v, ay + uy * L * u + ny * v)
    us = [i / 48.0 for i in range(49)]
    contour = [pt(u, demi(u)) for u in us] + [pt(u, -demi(u)) for u in reversed(us[1:-1])]
    lame = sd_poly(contour)
    tige = sd_segment(3.5, 60.5, 12.5, 51.5, 2.3)
    sil = np.minimum(lame - 0.6, tige)
    champ = lame + CADRE
    # nervure lumineuse le long de l'axe ; logement = gouttière autour
    p0, p1 = pt(0.13, 0), pt(0.82, 0)
    log = sd_segment(p0[0], p0[1], p1[0], p1[1], 3.6)
    q0, q1 = pt(0.15, 0), pt(0.80, 0)
    coeur = sd_segment(q0[0], q0[1], q1[0], q1[1], 1.5)
    # pièces : de part et d'autre de la nervure, de la base vers la pointe
    slots = [pt(u, cote * 0.5 * demi(u) + cote * 2.0) for u, cote in
             ((0.30, 1), (0.30, -1), (0.50, 1), (0.50, -1), (0.68, 1))]
    return dict(sil=sil, champ=champ, logement=log, coeur=coeur, coeur_centre=(31.0, 32.0), slots=slots,
                cables=[], nervure=((ax, ay), (bx, by)))


# Lot MOD-3 (D-17, réponse du DC à MOD-V Q3 : « Engrenage ») : la productivité reprend l'ENGRENAGE du premier jet. La
# croix (geo_productivite) est gardée pour mémoire. Le risque vu par MOD-V (engrenage gris de la recette de roue dentée
# en mode Alt) est réduit par la couleur orange du type : à regarder sur les captures.
GEO = {"speed": geo_vitesse, "productivity": geo_productivite_engrenage, "effectivity": geo_efficacite}
_GEO_CACHE = {}


def geo(t):
    if t not in _GEO_CACHE:
        _GEO_CACHE[t] = GEO[t]()
    return _GEO_CACHE[t]


# ------------------------------------------------------------------------------------------------------------------
# Rendu d'une icône (art sans plaque) à N px, en lumière linéaire, alpha prémultiplié
# ------------------------------------------------------------------------------------------------------------------
LUM = np.array([-0.55, -0.75, 0.95])
LUM = LUM / np.linalg.norm(LUM)
DEMI = LUM + np.array([0.0, 0.0, 1.0])
DEMI = DEMI / np.linalg.norm(DEMI)


def eclat(k):
    """Éclat du palier k (0 à 1) : croît de façon régulière de 1 à 10."""
    return (k - 1) / 9.0


def rang(k):
    """Rang dans la génération (nombre de pièces) : âge 6 -> 0 ; âge 10 -> 1 à 4 ; âge 14 -> 1 à 5."""
    return 0 if k == 1 else (k - 1 if k <= 5 else k - 5)


def _melange(dst, src, a):
    return dst * (1.0 - a[..., None]) + np.asarray(src, float)[None, None, :] * a[..., None]


def rendre_art(t, k, avec_plaque_vecteur=False):
    g = geo(t)
    R = roles_type(t, k)   # lot MOD-3 (D-17) : couleurs du TYPE (MOD-V : roles_age(EPOQUE[k]))
    e = eclat(k)
    n_pieces = rang(k)

    a_sil = couv(g["sil"])
    a_champ = couv(g["champ"])
    a_log = couv(g["logement"])
    a_coeur = couv(g["coeur"])

    # --- hauteur (unités) ---
    H = 3.0 * profil(g["sil"], 2.2)
    H += 0.9 * profil(g["champ"], 1.2) * a_champ
    H -= 1.6 * profil(g["logement"], 0.9) * a_log
    H += 1.2 * profil(g["coeur"], 1.4) * a_coeur

    # --- albédo, rugosité, métallicité ---
    alb = np.zeros((N, N, 3))
    rough = np.zeros((N, N))
    met = np.zeros((N, N))

    def poser(a, mat):
        nonlocal alb, rough, met
        alb = _melange(alb, mat["rgb"], a)
        rough = rough * (1 - a) + mat["rough"] * a
        met = met * (1 - a) + mat["met"] * a

    poser(a_sil, R["cadre"])
    poser(a_champ, R["champ"])
    if t == "effectivity":
        # tige du même matériau que le cadre (déjà posé) ; rien de plus
        pass

    # accents de l'âge : câbles rouge et bleu (âge 10) ; anneau de porcelaine autour du logement (âge 6)
    if R["age"] == 10:
        for poly, mat in zip(g["cables"], R["accent"]):
            a = couv(sd_polyligne(poly, 0.95)) * a_champ
            poser(a, mat)
            H += 0.5 * a
    if R.get("anneau"):
        anneau = np.maximum(g["logement"] - 1.6, -(g["logement"]))
        a = couv(anneau) * a_champ
        poser(a, R["accent"][0])
        H += 0.4 * a

    poser(a_log, R["logement"])

    # pièces : voyants (âge 10) ou étoiles (âge 14)
    emis = np.zeros((N, N, 3))
    lum = np.asarray(R["lumiere"], float)
    lum2 = np.asarray(R["lumiere2"], float)
    for i in range(n_pieces):
        sx, sy = g["slots"][i]
        if R["age"] == 10:
            lunette = sd_cercle(sx, sy, 3.3)
            lampe = sd_cercle(sx, sy, 2.3)
            a_l = couv(lunette)
            poser(a_l, R["logement"])
            H += 0.8 * profil(lunette, 0.8) * a_l
            a_p = couv(lampe)
            H += 0.5 * profil(lampe, 1.0) * a_p
            alb = _melange(alb, lum * 0.3, a_p)
            d = profil(lampe, 1.6)
            emis += (lum * 1.6)[None, None, :] * a_p[..., None]
            emis += np.array([0.5, 0.7, 1.0])[None, None, :] * (a_p * d * d)[..., None] * 0.9
        else:
            # étoile à 4 branches (croix fine + point), blanc d'étoile
            r = 3.0
            croix = np.minimum(sd_segment(sx - r, sy, sx + r, sy, 0.45), sd_segment(sx, sy - r, sx, sy + r, 0.45))
            point = sd_cercle(sx, sy, 1.15)
            a_c = couv(croix)
            a_p = couv(point)
            emis += (lum2 * 1.4)[None, None, :] * a_c[..., None] * 0.9
            emis += (lum * 2.6)[None, None, :] * a_p[..., None]
            alb = _melange(alb, lum * 0.5, np.maximum(a_c, a_p) * 0.6)

    # cœur : lumière de l'âge, plus vive et plus blanche avec le palier
    i_coeur = 0.8 + 2.6 * e
    blanc = 0.05 + 0.65 * e
    c_coeur = lum * (1 - blanc) + np.array([1.0, 1.0, 1.0]) * blanc
    dome = profil(g["coeur"], 1.6)
    alb = _melange(alb, lum * 0.25, a_coeur)
    emis += (c_coeur * i_coeur)[None, None, :] * (a_coeur * (0.55 + 0.45 * dome))[..., None]

    # halo du cœur sur le logement et le champ (dans la silhouette seulement)
    halo_src = a_coeur
    sig = (1.2 + 4.0 * e) * U
    halo = ndimage.gaussian_filter(halo_src, sig)
    halo = halo / max(halo.max(), 1e-6)
    emis += (lum * (0.04 + 0.9 * e))[None, None, :] * (halo * (1 - a_coeur))[..., None]

    # plaque vectorielle (icône d'objet à 64 px, icônes de technologie)
    if avec_plaque_vecteur:
        a_pl, a_gl = plaque_vecteur(k)
        poser(a_pl, dict(R["plaque"], rgb=tuple(np.asarray(R["plaque"]["rgb"]) * 0.6 + 0.006)))
        H = H * (1 - a_pl) + (3.4 + 0.6 * profil(sd_plaque(k), 0.7)) * a_pl
        alb = _melange(alb, lum * 0.3, a_gl)
        emis = emis * (1 - a_pl[..., None]) + couleur_glyphe(R, k)[None, None, :] * a_gl[..., None]
        a_sil = np.maximum(a_sil, a_pl)

    # --- éclairage ---
    gy, gx = np.gradient(H * U)   # pente en unités / pixel de travail -> relief ; x vers la droite, y vers le bas
    gx, gy = gx / U * 1.0, gy / U * 1.0
    nx, ny, nz = -gx * 2.2, -gy * 2.2, np.ones_like(H)
    nn = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / nn, ny / nn, nz / nn
    diff = np.clip(nx * LUM[0] + ny * LUM[1] + nz * LUM[2], 0.0, 1.0)
    diff_plat = LUM[2]
    nh = np.clip(nx * DEMI[0] + ny * DEMI[1] + nz * DEMI[2], 0.0, 1.0)
    p = 6.0 + (1.0 - rough) ** 2 * 90.0
    ks = 0.04 + 0.55 * (1.0 - rough) ** 2
    spec = ks * nh ** p
    # occlusion : creux sous le relief voisin
    creux = np.clip(ndimage.gaussian_filter(H, 1.2 * U) - H, 0.0, 3.0)
    occl = 1.0 - 0.22 * creux
    # dégradé vertical léger (volume)
    vert = 1.06 - 0.12 * (Y / 64.0)
    lit = alb * ((0.38 + 0.62 * diff / diff_plat) * occl * vert)[..., None]
    spec_col = (1.0 - met)[..., None] * 1.0 + met[..., None] * alb * 2.2
    lit = lit + spec[..., None] * spec_col + emis

    # contour sombre (lisibilité sur fond clair) : 0,9 unité autour de la silhouette
    sil_tot = g["sil"] if not avec_plaque_vecteur else np.minimum(g["sil"], sd_plaque(k))
    a_tot = couv(sil_tot - 0.9)
    contour = np.asarray(R["logement"]["rgb"], float) * 0.35
    a_cont = np.clip(a_tot - a_sil, 0.0, 1.0)
    rgb = lit * a_sil[..., None] + contour[None, None, :] * a_cont[..., None] * 0.92
    alpha = a_sil + a_cont * 0.92
    return rgb, np.clip(alpha, 0.0, 1.0)   # rgb prémultiplié, linéaire


# ------------------------------------------------------------------------------------------------------------------
# Plaque du palier (chiffre romain)
# ------------------------------------------------------------------------------------------------------------------
ROMAIN = {1: "I", 2: "II", 3: "III", 4: "IV", 5: "V", 6: "VI", 7: "VII", 8: "VIII", 9: "IX", 10: "X"}
GLYPHES = {  # grille de 32 px, 5 de haut : I 1 de large, V 3, X 5 (un X de 3 se lisait « 8 », premier jet)
    "I": ["X", "X", "X", "X", "X"],
    "V": ["X.X", "X.X", "X.X", ".X.", ".X."],
    "X": ["X...X", ".X.X.", "..X..", ".X.X.", "X...X"],
}
# mêmes glyphes en vecteur (unités de 64 px = 2 px de la grille de 32) : segments dans une case de largeur w
GLYPHES_VECT = {
    "I": (2, [((1.0, 1.0), (1.0, 9.0))]),
    "V": (6, [((1.0, 1.0), (3.0, 9.0)), ((5.0, 1.0), (3.0, 9.0))]),
    "X": (10, [((1.2, 1.2), (8.8, 8.8)), ((8.8, 1.2), (1.2, 8.8))]),
}


def couleur_glyphe(R, k):
    """Lumière des chiffres gravés : lumière de l'âge vers le blanc, plus vive avec le palier (linéaire)."""
    e = eclat(k)
    lum = np.asarray(R["lumiere"], float)
    blanc = 0.35 + 0.45 * e
    return (lum * (1 - blanc) + blanc) * (1.3 + 0.8 * e)


def bitmap_chiffre(k):
    s = ROMAIN[k]
    cols = []
    for i, ch in enumerate(s):
        gl = GLYPHES[ch]
        if i:
            cols.append([0] * 5)
        for c in range(len(gl[0])):
            cols.append([1 if gl[r][c] == "X" else 0 for r in range(5)])
    w = len(cols)
    b = np.zeros((5, w), bool)
    for c, col in enumerate(cols):
        b[:, c] = col
    return b


def rect_plaque32(k):
    """Rectangle de la plaque sur la grille de 32 px : (x0, y0, x1, y1) inclusifs, collé au coin HAUT GAUCHE (le coin
    bas droit porte le nombre d'objets de la case d'inventaire)."""
    w = bitmap_chiffre(k).shape[1]
    larg = w + 4
    return (0, 0, larg - 1, 8)


def sd_plaque(k):
    x0, y0, x1, y1 = rect_plaque32(k)
    return sd_boite(x0 * 2 + 0.25, y0 * 2 + 0.25, (x1 + 1) * 2 - 0.25, (y1 + 1) * 2 - 0.25, 1.6)


def plaque_vecteur(k):
    """Plaque et chiffres en vecteur, à la place exacte de la plaque au pixel (1 unité = 2 px de la grille de 32)."""
    x0, y0, x1, y1 = rect_plaque32(k)
    a_pl = couv(sd_plaque(k))
    x, gy0 = (x0 + 2) * 2, (y0 + 2) * 2
    d = None
    for ch in ROMAIN[k]:
        w, segs = GLYPHES_VECT[ch]
        for (ax, ay), (bx, by) in segs:
            sdg = sd_segment(x + ax, gy0 + ay, x + bx, gy0 + by, 0.95)
            d = sdg if d is None else np.minimum(d, sdg)
        x += w + 2
    a_gl = couv(d) * a_pl
    return a_pl, a_gl


def lin_vers_srgb(c, epaule=True):
    c = np.clip(c, 0.0, None)
    # épaule douce au-dessus de 0,85 (les lumières tendent vers le blanc sans plat dur) ; pas pour une image déjà finie
    if epaule:
        c = np.where(c > 0.85, 0.85 + 0.15 * (1.0 - np.exp(-(c - 0.85) / 0.15)), c)
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, 12.92 * c, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def srgb_vers_lin(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def reduire(rgb, alpha, taille):
    f = N // taille
    r = rgb.reshape(taille, f, taille, f, 3).mean(axis=(1, 3))
    a = alpha.reshape(taille, f, taille, f).mean(axis=(1, 3))
    return r, a


def en_image(rgb_pm, a, epaule=True):
    """Prémultiplié linéaire -> RGBA 8 bits sRGB (non prémultiplié)."""
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(a[..., None] > 1e-4, rgb_pm / np.maximum(a[..., None], 1e-4), 0.0)
    s = lin_vers_srgb(c, epaule)
    out = np.zeros(a.shape + (4,), np.uint8)
    out[..., :3] = np.round(s * 255).astype(np.uint8)
    out[..., 3] = np.round(np.clip(a, 0, 1) * 255).astype(np.uint8)
    out[a <= 1e-4, :3] = 0
    return Image.fromarray(out, "RGBA")


def poser_plaque_pixel(img, k, echelle, R):
    """Plaque au pixel sur l'image de 32 px (echelle 1) : bord presque noir, fond de la matière de plaque de l'âge,
    chiffre romain dans la lumière de l'âge."""
    px = np.array(img).astype(np.float64)
    x0, y0, x1, y1 = rect_plaque32(k)
    fond = lin_vers_srgb(np.asarray(R["plaque"]["rgb"], float) * 0.6 + 0.006) * 255
    bord = lin_vers_srgb(np.asarray(R["logement"]["rgb"], float) * 0.35) * 255
    glyphe = lin_vers_srgb(couleur_glyphe(R, k)) * 255
    b = bitmap_chiffre(k)
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            bordure = yy in (y0, y1) or xx in (x0, x1)
            coin = (yy in (y0, y1)) and (xx in (x0, x1))
            if coin:
                continue   # coins arrondis (pixel laissé à l'art)
            col = bord if bordure else fond
            gy, gx = yy - (y0 + 2), xx - (x0 + 2)
            if 0 <= gy < 5 and 0 <= gx < b.shape[1] and b[gy, gx]:
                col = glyphe
            for dy in range(echelle):
                for dx in range(echelle):
                    Y_, X_ = yy * echelle + dy, xx * echelle + dx
                    px[Y_, X_, :3] = col
                    px[Y_, X_, 3] = 255
    return Image.fromarray(np.round(px).astype(np.uint8), "RGBA")


# ------------------------------------------------------------------------------------------------------------------
# Fichiers
# ------------------------------------------------------------------------------------------------------------------
def icone_objet(t, k):
    """64 px : art et plaque en vecteur ; 32 px : art réduit puis plaque AU PIXEL ; 16 et 8 px : art seul (un chiffre
    n'y tient pas)."""
    rgb, a = rendre_art(t, k)
    rgb_p, a_p = rendre_art(t, k, avec_plaque_vecteur=True)
    R = roles_type(t, k)
    bande = Image.new("RGBA", (120, 64), (0, 0, 0, 0))
    im64 = en_image(*reduire(rgb_p, a_p, 64))
    im32 = poser_plaque_pixel(en_image(*reduire(rgb, a, 32)), k, 1, R)
    # 16 et 8 px : réduits de l'image de 32 px FINALE, plaque comprise (2e jet : sans plaque à 16 px, le filtrage entre
    # deux niveaux de mipmap effaçait à moitié la plaque dans une case affichée à environ 24 px, capture du coffre)
    im16 = reduire_image(im32, 16)
    im8 = reduire_image(im16, 8)
    x = 0
    for im in (im64, im32, im16, im8):
        bande.paste(im, (x, 0))
        x += im.size[0]
    return bande


def reduire_image(im, taille):
    """Réduction par moyenne de boîtes, en lumière linéaire, alpha prémultiplié."""
    px = np.asarray(im).astype(np.float64) / 255.0
    a = px[..., 3]
    lin = srgb_vers_lin(px[..., :3]) * a[..., None]
    f = im.size[0] // taille
    r = lin.reshape(taille, f, taille, f, 3).mean(axis=(1, 3))
    al = a.reshape(taille, f, taille, f).mean(axis=(1, 3))
    return en_image(r, al, epaule=False)


def icone_techno(t, k):
    rgb, a = rendre_art(t, k, avec_plaque_vecteur=True)
    bande = Image.new("RGBA", (480, 256), (0, 0, 0, 0))
    x = 0
    for taille in (256, 128, 64, 32):
        r, al = reduire(rgb, a, taille)
        bande.paste(en_image(r, al), (x, 0))
        x += taille
    return bande


def png_octets(im):
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return b.getvalue()


def beacon_tint(k):
    R = roles_age(EPOQUE[k])
    def s(c):
        v = lin_vers_srgb(np.asarray(c, float))
        return dict(r=round(float(v[0]), 3), g=round(float(v[1]), 3), b=round(float(v[2]), 3), a=1)
    return dict(primary=s(R["champ"]["rgb"]), secondary=s(np.asarray(R["lumiere"]) * 0.9))


def noms_technos(t, k):
    return VANILLA[t][k - 1] if k <= 3 else "fo-%s-module-%d" % (t, k)


def generer():
    """Rend les 60 images ; renvoie {chemin relatif: octets} et le manifeste."""
    fichiers = {}
    man = dict(version=VERSION, outil="tools/render/pieces/modules/icones.py", objets={}, technos={})
    for t in TYPES:
        for k in range(1, 11):
            o = nom_objet(t, k)
            b = png_octets(icone_objet(t, k))
            fichiers["%s.png" % o] = b
            man["objets"][o] = dict(type=t, palier=k, epoque=EPOQUE[k], fichier="%s.png" % o, icon_size=64,
                                    icon_mipmaps=4, largeur=120, hauteur=64, sha256=hashlib.sha256(b).hexdigest(),
                                    beacon_tint=beacon_tint(k))
            tn = noms_technos(t, k)
            bt = png_octets(icone_techno(t, k))
            fichiers["tech/%s.png" % tn] = bt
            man["technos"][tn] = dict(type=t, palier=k, fichier="tech/%s.png" % tn, icon_size=256, icon_mipmaps=4,
                                      largeur=480, hauteur=256, sha256=hashlib.sha256(bt).hexdigest())
    return fichiers, man


def lua_table(man):
    L = ["-- GÉNÉRÉ par tools/render/pieces/modules/icones.py (lot MOD-V) : ne pas éditer à la main.",
         "-- Icônes des modules (objets 64 px + 3 mipmaps, technologies 256 px + 3 mipmaps) et teintes de balise.",
         "return {", "  version = %d," % man["version"], "  objets = {"]
    for o in sorted(man["objets"]):
        d = man["objets"][o]
        bt = d["beacon_tint"]
        L.append('    ["%s"] = { fichier = "%s", icon_size = 64, icon_mipmaps = 4, palier = %d, epoque = %d,'
                 % (o, d["fichier"], d["palier"], d["epoque"]))
        L.append("      beacon_tint = { primary = { r = %.3f, g = %.3f, b = %.3f, a = 1 }, secondary = { r = %.3f, "
                 "g = %.3f, b = %.3f, a = 1 } } }," % (bt["primary"]["r"], bt["primary"]["g"], bt["primary"]["b"],
                                                      bt["secondary"]["r"], bt["secondary"]["g"],
                                                      bt["secondary"]["b"]))
    L.append("  },")
    L.append("  technos = {")
    for tn in sorted(man["technos"]):
        d = man["technos"][tn]
        L.append('    ["%s"] = { fichier = "%s", icon_size = 256, icon_mipmaps = 4 },' % (tn, d["fichier"]))
    L.append("  },")
    L.append("}")
    return "\n".join(L) + "\n"


# ------------------------------------------------------------------------------------------------------------------
# Planche
# ------------------------------------------------------------------------------------------------------------------
def planche(chemin, fichiers):
    try:
        f_titre = ImageFont.truetype("arialbd.ttf", 18)
        f_txt = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        f_titre = f_txt = ImageFont.load_default()
    noms_t = {"speed": "Vitesse : chevron", "productivity": "Productivité : engrenage",
              "effectivity": "Efficacité : feuille"}
    cell = 112
    marge_g = 200
    larg = marge_g + 10 * cell + 16
    rang_h = 64 + 6 + 64 + 18
    bloc_h = 3 * rang_h + 56
    fonds = [("fond sombre", (49, 48, 49)), ("fond clair", (214, 210, 200))]
    H = 96 + len(fonds) * bloc_h + 10
    im = Image.new("RGB", (larg, H), (24, 24, 26))
    d = ImageDraw.Draw(im)
    d.text((16, 12), "Modules : 3 types x 10 paliers (lots MOD-V et MOD-3 : couleur par type, engrenage ; proposition à juger)", fill=(235, 235, 235),
           font=f_titre)
    d.text((16, 40), "Chaque case : en haut à gauche 64 px, à droite 32 px (taille de l'inventaire), en dessous les "
                     "mêmes 32 px agrandis x 2 au pixel. Images du fichier, sans retouche.", fill=(200, 200, 200),
           font=f_txt)
    d.text((16, 60), "Forme ET couleur = type (bleu vitesse, orange productivité, vert efficacité ; D-17) ; montée : "
                     "chiffre romain, éclat du cœur, pièces (voyants 2 à 5, étoiles 6 à 10), teinte du champ.",
           fill=(200, 200, 200), font=f_txt)
    y = 96
    for libelle, fond in fonds:
        d.rectangle((0, y, larg, y + bloc_h - 10), fill=fond)
        enc = (230, 230, 230) if sum(fond) < 300 else (20, 20, 20)
        d.text((16, y + 8), libelle, fill=enc, font=f_txt)
        for k in range(1, 11):
            x = marge_g + (k - 1) * cell
            d.text((x + 4, y + 8), "palier %d" % k, fill=enc, font=f_txt)
            if k in (1, 2, 6):
                d.text((x + 4, y + 24), "âge %d : %s" % (EPOQUE[k], ages.NOMS[EPOQUE[k]]), fill=enc, font=f_txt)
        yy = y + 46
        for t in TYPES:
            d.text((16, yy + 50), noms_t[t], fill=enc, font=f_txt)
            for k in range(1, 11):
                b = Image.open(io.BytesIO(fichiers["%s.png" % nom_objet(t, k)])).convert("RGBA")
                x = marge_g + (k - 1) * cell
                c64 = b.crop((0, 0, 64, 64))
                c32 = b.crop((64, 0, 96, 32))
                tuile = Image.new("RGBA", (cell, rang_h), fond + (255,))
                tuile.alpha_composite(c64, (2, 0))
                tuile.alpha_composite(c32, (72, 16))
                tuile.alpha_composite(c32.resize((64, 64), Image.NEAREST), (2, 70))
                im.paste(tuile.convert("RGB"), (x, yy))
            yy += rang_h
        y += bloc_h
    im.save(chemin)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=os.path.join(MOD, "graphics", "modules"))
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--planche")
    ap.add_argument("--sans-ecrire", action="store_true", help="ne rien écrire dans --out (planche seule)")
    a = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    verifier_epoques()
    fichiers, man = generer()
    if a.check:
        ref = json.load(open(os.path.join(a.out, "MANIFEST.json"), encoding="utf-8"))
        pb = []
        for o, d in sorted(man["objets"].items()):
            r = ref["objets"].get(o)
            if not r or r["sha256"] != d["sha256"]:
                pb.append(o)
            elif hashlib.sha256(open(os.path.join(a.out, d["fichier"]), "rb").read()).hexdigest() != d["sha256"]:
                pb.append(o + " (fichier)")
        for tn, d in sorted(man["technos"].items()):
            r = ref["technos"].get(tn)
            if not r or r["sha256"] != d["sha256"]:
                pb.append("tech/" + tn)
            elif hashlib.sha256(open(os.path.join(a.out, d["fichier"]), "rb").read()).hexdigest() != d["sha256"]:
                pb.append("tech/" + tn + " (fichier)")
        lua = open(os.path.join(a.out, "icons.lua"), encoding="utf-8").read()
        if lua != lua_table(man):
            pb.append("icons.lua")
        print("[FO-MODV] contrôle : %d objet(s), %d techno(s), %d écart(s)%s"
              % (len(man["objets"]), len(man["technos"]), len(pb), (" : " + ", ".join(pb)) if pb else ""))
        return 1 if pb else 0
    if not a.sans_ecrire:
        os.makedirs(os.path.join(a.out, "tech"), exist_ok=True)
        total = 0
        for rel, b in sorted(fichiers.items()):
            with open(os.path.join(a.out, rel), "wb") as f:
                f.write(b)
            total += len(b)
        with open(os.path.join(a.out, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(man, f, ensure_ascii=False, indent=1, sort_keys=True)
            f.write("\n")
        with open(os.path.join(a.out, "icons.lua"), "w", encoding="utf-8", newline="\n") as f:
            f.write(lua_table(man))
        print("[FO-MODV] %d fichier(s) PNG, %.2f Mo, dans %s" % (len(fichiers), total / 1e6, a.out))
    if a.planche:
        planche(a.planche, fichiers)
        print("[FO-MODV] planche : %s" % a.planche)
    return 0


if __name__ == "__main__":
    sys.exit(main())
