"""ICÔNES DES MODULES, version 3 (lot ART-MODULES, 9/11) : 3 familles x 10 paliers, rendu 2D procédural HOLOGRAPHIQUE
(numpy, Pillow, scipy). Remplace le relief métallique des lots MOD-V / MOD-3 (versions 1 et 2).

Directive du DC (9/11) : « refonte graphique complète des modules [...] designs modernes, holographiques ou
techno-organiques à haute lisibilité ; code couleur franc : Vitesse = cyan électrique, Productivité = ambre/orange
ionique, Efficacité = vert émeraude/biologique ». Choix visuels PROVISOIRES (le DC tranche sur la planche) :

  PALETTE (sRGB)            liseré      cœur lumineux   corps sombre   glyphe
    vitesse (speed)         #00E5FF     #B8FBFF         #071824        #EAFDFF
    productivité            #FF9E1B     #FFE2A8         #1F1005        #FFF5E0
    efficacité              #1FE88A     #C4FFDF         #061C12        #ECFFF3
  FORME commune (cohérence) : PUCE octogonale (carré à coins coupés), cœur sombre à dégradé radial, micro-trame
    hexagonale (techno-organique) et balayage horizontal faibles, LISERÉ lumineux de la couleur de la famille avec
    halo (bloom) qui déborde de la silhouette, fin filet intérieur ; contour sombre d'environ 1 px (fond clair).
  GLYPHE (la famille se lit à la couleur ET au dessin, dès 16 px) :
    vitesse       : ÉCLAIR (zigzag plein, pointe en bas à gauche) ;
    productivité  : ENGRENAGE à 8 dents, évidé, FLÈCHE montante dans le moyeu (« produire plus ») ;
    efficacité    : HEXAGONE évidé (cellule) avec une FEUILLE pleine et sa nervure sombre.
  PALIER : CHIFFRE ARABE (1 à 10) sur une étiquette en HAUT À GAUCHE (le coin bas droit porte le nombre d'objets) :
    police 3 x 5 AU PIXEL à 32 px, même grille agrandie x 2 (cases 2 x 2 unités) à 64 px et dans les technologies ;
    JAUGE de 10 segments au bas de la puce, k segments allumés (64 px et technologies seulement : 10 segments ne
    tiennent pas à 32 px) ; éclat du liseré, largeur du halo et blancheur du glyphe croissent de 1 à 10 ; aux 16 et
    8 px, la famille se lit au glyphe et à la couleur (le chiffre n'y tient pas, l'étiquette reste visible en bloc).

Les teintes de BALISE (beacon_tint) restent celles de l'ÂGE qui débloque le palier (D-17 : « Couleur de l'âge »),
relevées sans Blender dans tools/render/pieces/levels/commun/ages.py ; palier 1 -> époque 6 ; 2 à 5 -> 10 ; 6 à 10 ->
14 (shared/content/epochs.lua, contrôlé par verifier_epoques()). Inchangées depuis la version 2 : icons.lua garde la
même forme, prototypes/modules.lua ne change pas.

Déterminisme : aucun hasard, aucune horloge ; deux passages donnent les mêmes octets (--check). Les 60 images sont
rendues en parallèle (multiprocessing, --jobs), le résultat ne dépend pas du nombre de processus.

Sorties (dossier --out, par défaut graphics/modules du mod) :
  <objet>.png        icône d'objet 64 px + 3 mipmaps (bande 120 x 64), icon_size 64, icon_mipmaps 4 ;
  tech/<techno>.png  icône de technologie 256 px + 3 mipmaps (bande 480 x 256), icon_size 256, icon_mipmaps 4 ;
  MANIFEST.json      noms, tailles, sha256, version de l'outil, couleurs de balise (beacon_tint) par objet ;
  icons.lua          même table pour l'étape data (chemins, beacon_tint), relue par prototypes/modules.lua.
Usage :
  py -3.9 tools/render/pieces/modules/icones.py                  # écrit graphics/modules (30 + 30 fichiers)
  py -3.9 tools/render/pieces/modules/icones.py --check          # régénère en mémoire et compare au MANIFEST (code 1 si écart)
  py -3.9 tools/render/pieces/modules/icones.py --planche <png>  # planche des 30 icônes à 64, 32 et 16 px, fond sombre et clair
  py -3.9 tools/render/pieces/modules/icones.py --jobs 1         # rendu séquentiel (mêmes octets)
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

VERSION = 3   # 3 : lot ART-MODULES (9/11), holographique ; 2 : MOD-3 (D-17) ; 1 : MOD-V
N = 512          # résolution de travail (unités de dessin : 0 à 64)
U = N / 64.0     # pixels de travail par unité
TYPES = ("speed", "productivity", "effectivity")
VANILLA = {"speed": ("speed-module", "speed-module-2", "speed-module-3"),
           "productivity": ("productivity-module", "productivity-module-2", "productivity-module-3"),
           "effectivity": ("effectivity-module", "effectivity-module-2", "effectivity-module-3")}
# Époque qui débloque chaque palier (shared/content/epochs.lua). Contrôlé par verifier_epoques().
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
# Couleurs
# ------------------------------------------------------------------------------------------------------------------
def srgb_vers_lin(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_vers_srgb(c, epaule=True):
    c = np.clip(c, 0.0, None)
    # épaule douce au-dessus de 0,85 (les lumières tendent vers le blanc sans plat dur) ; pas pour une image déjà finie
    if epaule:
        c = np.where(c > 0.85, 0.85 + 0.15 * (1.0 - np.exp(-(c - 0.85) / 0.15)), c)
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, 12.92 * c, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def hexa(s):
    """'#RRGGBB' -> rgb linéaire (tuple de 3 flottants)."""
    s = s.lstrip("#")
    return tuple(float(v) for v in srgb_vers_lin([int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]))


# Palette par famille (sRGB, consignée dans l'en-tête et le LISEZMOI) ; convertie en linéaire à l'import.
PALETTE_SRGB = {
    "speed": dict(lisere="#00E5FF", coeur="#B8FBFF", corps="#071824", glyphe="#EAFDFF"),
    "productivity": dict(lisere="#FF9E1B", coeur="#FFE2A8", corps="#1F1005", glyphe="#FFF5E0"),
    "effectivity": dict(lisere="#1FE88A", coeur="#C4FFDF", corps="#061C12", glyphe="#ECFFF3"),
}
PALETTE = {t: {r: np.asarray(hexa(v), float) for r, v in d.items()} for t, d in PALETTE_SRGB.items()}


def matieres_age(e):
    rel = {}

    def metal(nom, rgb, **kw):
        rel[nom] = dict(rgb=tuple(rgb), rough=kw.get("rough", 0.4), met=kw.get("met", 0.2))
        return nom
    ages.matieres(e, metal, {})
    return rel


def roles_age(e):
    """Rôles de l'âge e pour les BALISES (beacon_tint, D-17) : champ (dominante) et lumière (foyer)."""
    m = matieres_age(e)
    f = ages.FOYER[e]
    if e == 6:
        champ = m["porcelaine_capot"]
    elif e == 10:
        champ = m["blanc_casse"]
    elif e == 14:
        champ = m["indigo_nuit"]
    else:
        raise ValueError("âge sans rôles de module : %d" % e)
    return dict(champ=champ, lumiere=tuple(f["rgb"]), age=e)


def beacon_tint(k):
    R = roles_age(EPOQUE[k])

    def s(c):
        v = lin_vers_srgb(np.asarray(c, float))
        return dict(r=round(float(v[0]), 3), g=round(float(v[1]), 3), b=round(float(v[2]), 3), a=1)
    return dict(primary=s(R["champ"]["rgb"]), secondary=s(np.asarray(R["lumiere"]) * 0.9))


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


def sd_boite(x0, y0, x1, y1, r=0.0):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = np.abs(X - cx) - hx, np.abs(Y - cy) - hy
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def sd_hexagone(cx, cy, r):
    """Hexagone à pointe en haut, rayon (sommet) r."""
    px, py = np.abs(X - cx), np.abs(Y - cy)
    ri = r * math.sqrt(3) / 2
    return np.maximum(px * math.sqrt(3) / 2 + py * 0.5, px) - ri


def couv(sd):
    """Couverture anticrénelée (1 dedans, 0 dehors) d'un champ en unités."""
    return np.clip(0.5 - sd * U, 0.0, 1.0)


def bande(sd, interieur, largeur):
    """Couverture d'une bande entre sd = -interieur et sd = -(interieur + largeur)."""
    return np.clip(couv(sd + interieur) - couv(sd + interieur + largeur), 0.0, 1.0)


# ------------------------------------------------------------------------------------------------------------------
# Géométrie : puce commune et trois glyphes
# ------------------------------------------------------------------------------------------------------------------
RIM = 2.4          # liseré (unités) : 1,2 px à 32 px
CENTRE = (32.0, 33.0)


def sd_puce():
    x0, y0, x1, y1, c = 4.5, 4.5, 59.5, 61.5, 11.0
    pts = [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]
    return sd_poly(pts) - 1.4


def _engrenage(cx, cy, n, r_pied, r_tete, f_tete, f_pied, arc=6):
    pts = []
    pas = 2 * math.pi / n
    for i in range(n):
        a0 = i * pas - math.pi / 2
        ang = [(a0 - f_pied * pas / 2, r_pied), (a0 - f_tete * pas / 2, r_tete), (a0 + f_tete * pas / 2, r_tete),
               (a0 + f_pied * pas / 2, r_pied)]
        for a, r in ang:
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        a_deb = a0 + f_pied * pas / 2
        a_fin = a0 + pas - f_pied * pas / 2
        for j in range(1, arc):
            a = a_deb + (a_fin - a_deb) * j / arc
            pts.append((cx + r_pied * math.cos(a), cy + r_pied * math.sin(a)))
    return pts


def glyphe_vitesse():
    """ÉCLAIR plein : zigzag du haut droit vers le bas gauche."""
    pts = [(38.0, 12.5), (20.5, 37.5), (30.5, 37.5), (26.0, 54.5), (44.5, 29.5), (34.5, 29.5)]
    sd = sd_poly(pts) - 0.6
    return dict(plein=sd, creux=None)


def glyphe_productivite():
    """ENGRENAGE plein à 8 dents, FLÈCHE montante EN CREUX dans le moyeu (sombre sur clair : tient le halo des hauts
    paliers, où une flèche claire dans un moyeu évidé se noyait)."""
    cx, cy = CENTRE
    roue = sd_poly(_engrenage(cx, cy, 8, 12.3, 16.6, 0.42, 0.62)) - 0.5
    tete = sd_poly([(cx, cy - 7.0), (cx - 5.8, cy - 0.6), (cx + 5.8, cy - 0.6)])
    tige = sd_boite(cx - 1.9, cy - 1.2, cx + 1.9, cy + 6.6, 0.6)
    fleche = np.minimum(tete, tige)
    return dict(plein=roue, creux=fleche)


def glyphe_efficacite():
    """HEXAGONE évidé (cellule) et FEUILLE pleine, nervure en creux."""
    cx, cy = CENTRE
    hexa_sd = sd_hexagone(cx, cy, 17.5)
    cellule = np.abs(hexa_sd) - 1.5
    ax, ay, bx, by = 23.0, 43.5, 41.5, 23.0
    L = math.hypot(bx - ax, by - ay)
    ux, uy = (bx - ax) / L, (by - ay) / L
    nx, ny = -uy, ux
    W = 7.6

    def demi(u):
        return W * math.sin(math.pi * u ** 0.72)

    def pt(u, v):
        return (ax + ux * L * u + nx * v, ay + uy * L * u + ny * v)
    us = [i / 40.0 for i in range(41)]
    contour = [pt(u, demi(u)) for u in us] + [pt(u, -demi(u)) for u in reversed(us[1:-1])]
    feuille = sd_poly(contour) - 0.3
    p0, p1 = pt(0.08, 0), pt(0.86, 0)
    nervure = sd_segment(p0[0], p0[1], p1[0], p1[1], 0.75)
    return dict(plein=np.minimum(cellule, feuille), creux=np.maximum(nervure, feuille + 1.6))


GLYPHES = {"speed": glyphe_vitesse, "productivity": glyphe_productivite, "effectivity": glyphe_efficacite}
_GEO_CACHE = {}


def geo(t):
    if t not in _GEO_CACHE:
        g = GLYPHES[t]()
        g["puce"] = sd_puce()
        _GEO_CACHE[t] = g
    return _GEO_CACHE[t]


# ------------------------------------------------------------------------------------------------------------------
# Trames (techno-organique) : micro-trame hexagonale et balayage horizontal, déterministes
# ------------------------------------------------------------------------------------------------------------------
def _hexd(px, py):
    px, py = np.abs(px), np.abs(py)
    return np.maximum(px * 0.8660254 + py * 0.5, py)


def trame_hexagonale(pas=5.0, epaisseur=0.35):
    """Lignes d'un pavage hexagonal (pas = distance entre centres, unités) : 1 sur la ligne, 0 ailleurs."""
    rx, ry = pas, pas * 1.7320508
    x, y = X / rx, Y / ry
    ax, ay = (x % 1.0 - 0.5) * rx, (y % 1.0 - 0.5) * ry
    bx, by = ((x - 0.5) % 1.0 - 0.5) * rx, ((y - 0.5) % 1.0 - 0.5) * ry
    d = np.minimum(_hexd(ax, ay), _hexd(bx, by))
    bord = pas * 0.5
    return np.clip(1.0 - np.abs(d - bord) / epaisseur, 0.0, 1.0)


def balayage(periode=2.0):
    """Balayage horizontal : lignes de 1 px à 32 px, une sur deux."""
    return ((Y % periode) < periode / 2).astype(float)


_TRAMES = {}


def trames():
    if not _TRAMES:
        _TRAMES["hex"] = trame_hexagonale()
        _TRAMES["bal"] = balayage()
    return _TRAMES


# ------------------------------------------------------------------------------------------------------------------
# Palier : chiffre arabe (police 3 x 5) et jauge
# ------------------------------------------------------------------------------------------------------------------
CHIFFRES = {
    "0": ["XXX", "X.X", "X.X", "X.X", "XXX"],
    "1": [".X.", "XX.", ".X.", ".X.", "XXX"],
    "2": ["XXX", "..X", "XXX", "X..", "XXX"],
    "3": ["XXX", "..X", "XXX", "..X", "XXX"],
    "4": ["X.X", "X.X", "XXX", "..X", "..X"],
    "5": ["XXX", "X..", "XXX", "..X", "XXX"],
    "6": ["XXX", "X..", "XXX", "X.X", "XXX"],
    "7": ["XXX", "..X", "..X", "..X", "..X"],
    "8": ["XXX", "X.X", "XXX", "X.X", "XXX"],
    "9": ["XXX", "X.X", "XXX", "..X", "XXX"],
}


def bitmap_chiffre(k):
    cols = []
    for i, ch in enumerate(str(k)):
        gl = CHIFFRES[ch]
        if i:
            cols.append([0] * 5)
        for c in range(3):
            cols.append([1 if gl[r][c] == "X" else 0 for r in range(5)])
    b = np.zeros((5, len(cols)), bool)
    for c, col in enumerate(cols):
        b[:, c] = col
    return b


def rect_plaque32(k):
    """Étiquette sur la grille de 32 px : (x0, y0, x1, y1) inclusifs, coin HAUT GAUCHE."""
    w = bitmap_chiffre(k).shape[1]
    return (0, 0, w + 3, 8)


def sd_plaque(k):
    x0, y0, x1, y1 = rect_plaque32(k)
    return sd_boite(x0 * 2 + 0.25, y0 * 2 + 0.25, (x1 + 1) * 2 - 0.25, (y1 + 1) * 2 - 0.25, 1.4)


def plaque_vecteur(k):
    """Étiquette et chiffre à 64 px et au-delà : la grille de 32 agrandie x 2 (une case = 2 x 2 unités), coins à peine
    adoucis ; renvoie (couverture de l'étiquette, couverture du bord, couverture du chiffre)."""
    x0, y0, x1, y1 = rect_plaque32(k)
    sd_pl = sd_plaque(k)
    a_pl = couv(sd_pl)
    a_bord = np.clip(a_pl - couv(sd_pl + 1.6), 0.0, 1.0)
    b = bitmap_chiffre(k)
    d = None
    for r in range(5):
        for c in range(b.shape[1]):
            if b[r, c]:
                gx, gy = (x0 + 2 + c) * 2, (y0 + 2 + r) * 2
                s = sd_boite(gx + 0.1, gy + 0.1, gx + 1.9, gy + 1.9, 0.3)
                d = s if d is None else np.minimum(d, s)
    return a_pl, a_bord, couv(d) * a_pl


JAUGE_N = 10


def jauge(k):
    """Jauge de 10 segments au bas de la puce (64 px et technologies) : (segments allumés, segments éteints)."""
    x0, x1, y0, y1 = 13.0, 51.0, 53.6, 56.6
    pas = (x1 - x0) / JAUGE_N
    allume = eteint = None
    for i in range(JAUGE_N):
        s = sd_boite(x0 + i * pas + 0.45, y0, x0 + (i + 1) * pas - 0.45, y1, 0.5)
        if i < k:
            allume = s if allume is None else np.minimum(allume, s)
        else:
            eteint = s if eteint is None else np.minimum(eteint, s)
    a_on = couv(allume) if allume is not None else np.zeros_like(X)
    a_off = couv(eteint) if eteint is not None else np.zeros_like(X)
    return a_on, a_off


# ------------------------------------------------------------------------------------------------------------------
# Rendu d'une icône à N px, en lumière linéaire, alpha prémultiplié
# ------------------------------------------------------------------------------------------------------------------
def eclat(k):
    """Éclat du palier k (0 à 1) : croît de façon régulière de 1 à 10."""
    return (k - 1) / 9.0


def couleur_glyphe(t, k):
    """Couleur du glyphe : du cœur lumineux vers le blanc du glyphe avec le palier."""
    P = PALETTE[t]
    e = eclat(k)
    return P["coeur"] * (1 - e * 0.7) + P["glyphe"] * (e * 0.7)


def rendre_art(t, k, avec_plaque_vecteur=False):
    g = geo(t)
    P = PALETTE[t]
    T = trames()
    e = eclat(k)
    lis = P["lisere"]
    corps = P["corps"]

    sd_p = g["puce"]
    a_puce = couv(sd_p)
    a_rim = bande(sd_p, 0.0, RIM)
    a_filet = bande(sd_p, RIM + 1.9, 0.6)
    a_coeur = couv(sd_p + RIM)
    a_gl = couv(g["plein"])
    if g["creux"] is not None:
        a_gl = a_gl * (1.0 - couv(g["creux"]))

    # --- cœur sombre : dégradé radial, teinte de la famille, trames faibles ---
    cx, cy = CENTRE
    r = np.hypot(X - cx, Y - cy) / 30.0
    base = corps[None, None, :] * (1.25 - 0.45 * np.clip(r, 0, 1))[..., None]
    base = base + lis[None, None, :] * (0.035 * T["hex"] + 0.012 * T["bal"])[..., None]
    # voile lumineux de la famille au centre (vitrage) qui monte avec le palier
    base = base + lis[None, None, :] * (0.10 + 0.14 * e) * np.clip(1.0 - r * 1.1, 0, 1)[..., None] ** 2
    rgb = base * a_coeur[..., None]

    # --- liseré et filet (émissifs) ---
    i_rim = 0.55 + 0.75 * e
    rgb = rgb * (1 - a_rim[..., None]) + (lis * i_rim)[None, None, :] * a_rim[..., None]
    rgb = rgb + (lis * (0.18 + 0.22 * e))[None, None, :] * a_filet[..., None]

    # --- glyphe (émissif) ---
    c_gl = couleur_glyphe(t, k) * (1.0 + 0.22 * e)
    rgb = rgb * (1 - a_gl[..., None]) + c_gl[None, None, :] * a_gl[..., None]

    # --- jauge et étiquette du palier (vecteur : 64 px et technologies) ---
    a_pl = np.zeros_like(X)
    a_on = np.zeros_like(X)
    if avec_plaque_vecteur:
        a_on, a_off = jauge(k)
        rgb = rgb * (1 - a_off[..., None]) + (corps * 0.6 + lis * 0.10)[None, None, :] * a_off[..., None]
        rgb = rgb * (1 - a_on[..., None]) + (lis * (0.9 + 0.5 * e))[None, None, :] * a_on[..., None]
        a_pl, a_bord, a_ch = plaque_vecteur(k)
        fond = corps * 0.45
        rgb = rgb * (1 - a_pl[..., None]) + fond[None, None, :] * a_pl[..., None]
        rgb = rgb * (1 - a_bord[..., None]) + (lis * 0.55)[None, None, :] * a_bord[..., None]
        rgb = rgb * (1 - a_ch[..., None]) + (P["glyphe"] * 1.3)[None, None, :] * a_ch[..., None]

    # --- halo (bloom) du liseré et du glyphe, dedans et dehors ---
    emis = (lis * i_rim * 0.9)[None, None, :] * a_rim[..., None] + c_gl[None, None, :] * a_gl[..., None]
    emis = emis + (lis * 0.4)[None, None, :] * a_on[..., None]
    sig = (1.3 + 1.7 * e) * U
    halo = np.stack([ndimage.gaussian_filter(emis[..., i], sig) for i in range(3)], axis=-1)
    gain = 0.40 + 0.35 * e
    rgb = rgb + halo * gain * a_puce[..., None] * (1 - a_gl[..., None]) * (1 - a_pl[..., None])

    # --- contour sombre (lisibilité sur fond clair) puis halo extérieur ---
    a_sil = np.maximum(a_puce, a_pl)
    sil_tot = sd_p if not avec_plaque_vecteur else np.minimum(sd_p, sd_plaque(k))
    a_cont = np.clip(couv(sil_tot - 0.9) - a_sil, 0.0, 1.0) * 0.9
    contour = corps * 0.35
    dehors = np.clip(1.0 - a_sil - a_cont, 0.0, 1.0)
    halo_ext = halo * gain * 0.7
    a_ext = np.clip(halo_ext.max(axis=-1) * 1.6, 0.0, 0.5) * dehors
    rgb = rgb * a_sil[..., None] + contour[None, None, :] * a_cont[..., None] + halo_ext * dehors[..., None]
    alpha = a_sil + a_cont + a_ext
    rgb = np.minimum(rgb, np.maximum(alpha, 1e-6)[..., None] * 4.0)
    return rgb, np.clip(alpha, 0.0, 1.0)   # rgb prémultiplié, linéaire


# ------------------------------------------------------------------------------------------------------------------
# Réductions et images
# ------------------------------------------------------------------------------------------------------------------
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


def reduire_image(im, taille):
    """Réduction par moyenne de boîtes, en lumière linéaire, alpha prémultiplié."""
    px = np.asarray(im).astype(np.float64) / 255.0
    a = px[..., 3]
    lin = srgb_vers_lin(px[..., :3]) * a[..., None]
    f = im.size[0] // taille
    r = lin.reshape(taille, f, taille, f, 3).mean(axis=(1, 3))
    al = a.reshape(taille, f, taille, f).mean(axis=(1, 3))
    return en_image(r, al, epaule=False)


def poser_plaque_pixel(img, t, k):
    """Étiquette AU PIXEL sur l'image de 32 px : bord au liseré atténué, fond sombre, chiffre arabe 3 x 5 clair."""
    P = PALETTE[t]
    px = np.array(img).astype(np.float64)
    x0, y0, x1, y1 = rect_plaque32(k)
    fond = lin_vers_srgb(P["corps"] * 0.45) * 255
    bord = lin_vers_srgb(P["lisere"] * 0.55) * 255
    chiffre = lin_vers_srgb(P["glyphe"] * 1.3) * 255
    b = bitmap_chiffre(k)
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            bordure = yy in (y0, y1) or xx in (x0, x1)
            if (yy in (y0, y1)) and (xx in (x0, x1)):
                continue   # coins arrondis (pixel laissé à l'art)
            col = bord if bordure else fond
            gy, gx = yy - (y0 + 2), xx - (x0 + 2)
            if 0 <= gy < 5 and 0 <= gx < b.shape[1] and b[gy, gx]:
                col = chiffre
            px[yy, xx, :3] = col
            px[yy, xx, 3] = 255
    return Image.fromarray(np.round(px).astype(np.uint8), "RGBA")


def icone_objet(t, k):
    """64 px : art, jauge et étiquette en vecteur ; 32 px : art réduit puis étiquette AU PIXEL ; 16 et 8 px : réduits
    de l'image de 32 px finale (étiquette comprise, en bloc)."""
    rgb, a = rendre_art(t, k)
    rgb_p, a_p = rendre_art(t, k, avec_plaque_vecteur=True)
    bande_im = Image.new("RGBA", (120, 64), (0, 0, 0, 0))
    im64 = en_image(*reduire(rgb_p, a_p, 64))
    im32 = poser_plaque_pixel(en_image(*reduire(rgb, a, 32)), t, k)
    im16 = reduire_image(im32, 16)
    im8 = reduire_image(im16, 8)
    x = 0
    for im in (im64, im32, im16, im8):
        bande_im.paste(im, (x, 0))
        x += im.size[0]
    return bande_im


def icone_techno(t, k):
    rgb, a = rendre_art(t, k, avec_plaque_vecteur=True)
    bande_im = Image.new("RGBA", (480, 256), (0, 0, 0, 0))
    x = 0
    for taille in (256, 128, 64, 32):
        r, al = reduire(rgb, a, taille)
        bande_im.paste(en_image(r, al), (x, 0))
        x += taille
    return bande_im


def png_octets(im):
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return b.getvalue()


def _rendre_un(tk):
    t, k = tk
    return t, k, png_octets(icone_objet(t, k)), png_octets(icone_techno(t, k))


def generer(jobs=None):
    """Rend les 60 images ; renvoie {chemin relatif: octets} et le manifeste. Même résultat quel que soit `jobs`."""
    taches = [(t, k) for t in TYPES for k in range(1, 11)]
    if jobs is None:
        jobs = max(1, min(os.cpu_count() or 1, len(taches)))
    if jobs > 1:
        import multiprocessing
        with multiprocessing.Pool(jobs) as pool:
            res = pool.map(_rendre_un, taches, chunksize=1)
    else:
        res = [_rendre_un(tk) for tk in taches]
    fichiers = {}
    man = dict(version=VERSION, outil="tools/render/pieces/modules/icones.py", objets={}, technos={})
    for t, k, b, bt in res:
        o = nom_objet(t, k)
        fichiers["%s.png" % o] = b
        man["objets"][o] = dict(type=t, palier=k, epoque=EPOQUE[k], fichier="%s.png" % o, icon_size=64,
                                icon_mipmaps=4, largeur=120, hauteur=64, sha256=hashlib.sha256(b).hexdigest(),
                                beacon_tint=beacon_tint(k))
        fichiers["tech/%s.png" % o] = bt
        man["technos"][o] = dict(type=t, palier=k, fichier="tech/%s.png" % o, icon_size=256, icon_mipmaps=4,
                                 largeur=480, hauteur=256, sha256=hashlib.sha256(bt).hexdigest())
    return fichiers, man


def lua_table(man):
    L = ["-- GÉNÉRÉ par tools/render/pieces/modules/icones.py (lot ART-MODULES, version 3) : ne pas éditer à la main.",
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
# Planche de contrôle (le DC juge depuis son téléphone : 64 px, 32 px, 16 px, et le 16 px agrandi x 4 au pixel)
# ------------------------------------------------------------------------------------------------------------------
def planche(chemin, fichiers):
    try:
        f_titre = ImageFont.truetype("arialbd.ttf", 20)
        f_txt = ImageFont.truetype("arial.ttf", 14)
    except OSError:
        f_titre = f_txt = ImageFont.load_default()
    noms_t = {"speed": "Vitesse : éclair, cyan", "productivity": "Productivité : engrenage-flèche, ambre",
              "effectivity": "Efficacité : feuille-hexagone, émeraude"}
    cell = 128
    marge_g = 300
    larg = marge_g + 10 * cell + 16
    rang_h = 64 + 8 + 64 + 14
    bloc_h = 3 * rang_h + 60
    fonds = [("fond sombre (inventaire)", (49, 48, 49)), ("fond clair", (214, 210, 200))]
    H = 100 + len(fonds) * bloc_h + 10
    im = Image.new("RGB", (larg, H), (24, 24, 26))
    d = ImageDraw.Draw(im)
    d.text((16, 12), "Modules, version 3 (lot ART-MODULES, 9/11) : 3 familles x 10 paliers, holographique ; proposition à juger",
           fill=(235, 235, 235), font=f_titre)
    d.text((16, 42), "Chaque case, en haut : 64 px, 32 px (inventaire), 16 px ; en bas : les 16 px agrandis x 4 au pixel. "
                     "Images du fichier, sans retouche.", fill=(200, 200, 200), font=f_txt)
    d.text((16, 62), "Couleur ET glyphe = famille ; palier : chiffre en haut à gauche (64 et 32 px), jauge de 10 segments "
                     "(64 px), éclat du liseré et du halo.", fill=(200, 200, 200), font=f_txt)
    y = 100
    for libelle, fond in fonds:
        d.rectangle((0, y, larg, y + bloc_h - 10), fill=fond)
        enc = (230, 230, 230) if sum(fond) < 300 else (20, 20, 20)
        d.text((16, y + 8), libelle, fill=enc, font=f_txt)
        for k in range(1, 11):
            x = marge_g + (k - 1) * cell
            d.text((x + 4, y + 8), "palier %d" % k, fill=enc, font=f_txt)
            if k in (1, 2, 6):
                d.text((x + 4, y + 26), "âge %d" % EPOQUE[k], fill=enc, font=f_txt)
        yy = y + 50
        for t in TYPES:
            d.text((16, yy + 50), noms_t[t], fill=enc, font=f_txt)
            for k in range(1, 11):
                b = Image.open(io.BytesIO(fichiers["%s.png" % nom_objet(t, k)])).convert("RGBA")
                x = marge_g + (k - 1) * cell
                c64 = b.crop((0, 0, 64, 64))
                c32 = b.crop((64, 0, 96, 32))
                c16 = b.crop((96, 0, 112, 16))
                tuile = Image.new("RGBA", (cell, rang_h), fond + (255,))
                tuile.alpha_composite(c64, (2, 0))
                tuile.alpha_composite(c32, (72, 8))
                tuile.alpha_composite(c16, (108, 44))
                tuile.alpha_composite(c16.resize((64, 64), Image.NEAREST), (2, 72))
                tuile.alpha_composite(c32.resize((64, 64), Image.NEAREST), (70, 72))
                im.paste(tuile.convert("RGB"), (x, yy))
            yy += rang_h
        y += bloc_h
    im.save(chemin)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=os.path.join(MOD, "graphics", "modules"))
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--planche")
    ap.add_argument("--jobs", type=int, default=None, help="processus de rendu (défaut : cœurs ; 1 = séquentiel)")
    ap.add_argument("--sans-ecrire", action="store_true", help="ne rien écrire dans --out (planche seule)")
    a = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    verifier_epoques()
    fichiers, man = generer(a.jobs)
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
