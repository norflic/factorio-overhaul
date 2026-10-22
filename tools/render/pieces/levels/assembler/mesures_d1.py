"""Mesures D1 de la machine d'assemblage 2 (lot V3, phase 1), sur les rendus d'aperçu. Python système (numpy, Pillow).

    python -P tools/render/pieces/levels/assembler/mesures_d1.py [--source complet|masque] [--sortie <fichier.txt>]

Reprend le protocole de docs/epoques/mesures/measure.py (bible §1.4, RD_LOG E27), en numpy :
- toile commune à 64 px par tuile, origine = position de l'entité ; masque = alpha ≥ 0,5 de la couche PRINCIPALE
  (sans ombre, lueur ni halo). Aucun niveau de cette famille n'a de couche plate au sol (socle, dalle) : le masque
  amendé (Q13 a) est donc le masque entier. Le liseré de contact fait partie de la couche principale, comme en vanilla ;
- niveau 1 = sprite vanilla hr, image 0 ; niveau 2 = union du sprite vanilla et de la pièce masquée ;
- O (masses) : dépassement au-dessus de l'emprise après ouverture HORIZONTALE par un segment de 1 × 10 px (0,15 tuile),
  qui ne retire que ce qui fait moins de 0,15 tuile de LARGE (mâts, antennes, câbles : bible §1.4 ; correction du
  vérificateur V3, 22/10 : l'ancienne ouverture carrée retirait aussi les anneaux et poutres vus par la tranche) ;
  O total : sur le masque brut ;
- D1-1 : aire ajoutée par la pièce paire hors du masque impair (≥ 0,10 t² visé) ; aire où la luminance change d'au
  moins 20/255 (≥ 0,15 t², autre voie du critère) ; IoU impair / pair précédent (≤ 0,85) ;
- D1-2 : IoU brute ET normalisée en échelle entre époques consécutives (niveaux impairs ; ≤ 0,85, ≤ 0,75 aux
  changements d'ère), IoU normalisée contre le niveau 1 (≤ 0,80) ; O jamais décroissant ; événements de silhouette
  (pics du profil supérieur, proéminence ≥ 0,12 t) ;
- D1-3 amendé (Q13) : IoU(niveau 1, niveau 30) < 0,50 (cible ≤ 0,45) ET IoU normalisée en échelle = max sur k de
  IoU(niveau 1 agrandi de k, niveau 30), k de 0,50 à 2,50 par pas de 0,01, ancrages à l'origine et au pied (seuil
  proposé 0,75) ;
- contrôles ajoutés au 22/10 : zones de lueur de moins de 8 × 8 px hr, surface du halo de nuit (alpha > 0,1),
  luminance des flèches de l'époque 15, part visible du mécanisme animé (passe de contrôle « meca » du rendu) ;
- vide V : part du masque du niveau 1 laissée transparente par le niveau ; emprise couverte ; L (largeur des masses).
"""
import argparse
import io
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, HERE)
import params  # noqa: E402

DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
OUT = os.path.join(RENDER, "out", "levels", params.FAMILLE)
PPT = 64
X0, X1, Y0, Y1 = -4.0, 7.0, -5.5, 3.0          # étendue de la toile (tuiles)
W, H = int((X1 - X0) * PPT), int((Y1 - Y0) * PPT)
OX, OY = -X0 * PPT, -Y0 * PPT                   # pixel de l'origine (bord de pixel)
LUMA = np.array([0.2126, 0.7152, 0.0722])


def load_rgba(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0


def put(img, shift_tiles):
    """Image hr (64 px/tuile) posée sur la toile : centre = origine + shift."""
    out = np.zeros((H, W, img.shape[2]))
    h, w = img.shape[:2]
    x0 = OX + shift_tiles[0] * PPT - w / 2.0
    y0 = OY + shift_tiles[1] * PPT - h / 2.0
    xi, yi = int(round(x0)), int(round(y0))
    assert abs(x0 - xi) < 1e-6 and abs(y0 - yi) < 1e-6, (x0, y0)
    xs0, ys0, xd0, yd0 = max(0, -xi), max(0, -yi), max(0, xi), max(0, yi)     # rogné aux bords de la toile
    ww, hh = min(w - xs0, W - xd0), min(h - ys0, H - yd0)
    if ww > 0 and hh > 0:
        out[yd0:yd0 + hh, xd0:xd0 + ww] = img[ys0:ys0 + hh, xs0:xs0 + ww]
    return out


def over(top, bottom):
    a_t, a_b = top[..., 3:4], bottom[..., 3:4]
    a = a_t + a_b * (1 - a_t)
    rgb = np.where(a > 1e-8, (top[..., :3] * a_t + bottom[..., :3] * a_b * (1 - a_t)) / np.maximum(a, 1e-8), 0)
    return np.concatenate([rgb, a], -1)


def vanilla():
    v = params.VANILLA["main"]
    im = load_rgba(os.path.join(DATA, "base", "graphics", "entity", v["file"]))
    w, h = v["frame"]
    return put(im[:h, :w], v["shift"])


def level_rgba(n, source):
    """Couche principale du niveau n sur la toile (RGBA)."""
    if n == 1:
        return vanilla()
    if source == "masque":
        a = np.asarray(Image.open(os.path.join(OUT, "masques", "masque-n%02d.png" % n))).astype(np.float64) / 255.0
        with open(os.path.join(OUT, "masques", "masque-n%02d.json" % n), encoding="utf-8") as f:
            ox, oy = json.load(f)["origin_px"]
        img = np.zeros(a.shape + (4,))
        img[..., 3] = a
        h, w = a.shape
        shift = ((w / 2.0 - ox) / PPT, (h / 2.0 - oy) / PPT)
        lay = put(img, shift)
    else:
        with open(os.path.join(OUT, "n%02d" % n, "n%02d.json" % n), encoding="utf-8") as f:
            rec = json.load(f)
        sd = rec["spec"]["main"]["hr"]
        lay = put(load_rgba(os.path.join(OUT, "n%02d" % n, sd["filename"])), sd["shift"])
    if n == 2:
        return over(lay, vanilla())
    return lay


def opening(m, k=10):
    """Ouverture morphologique par un carré k × k (images d'intégrales)."""
    m = m.astype(np.int32)
    I = np.zeros((m.shape[0] + 1, m.shape[1] + 1), np.int32)
    I[1:, 1:] = m.cumsum(0).cumsum(1)
    full = np.zeros_like(m)
    s = I[k:, k:] - I[:-k, k:] - I[k:, :-k] + I[:-k, :-k]
    full[:s.shape[0], :s.shape[1]] = (s == k * k)
    J = np.zeros((m.shape[0] + k, m.shape[1] + k), np.int32)
    J[k:, k:] = full.cumsum(0).cumsum(1)
    # pixel (y, x) couvert si une fenêtre pleine a son coin en (y', x'), y-k < y' ≤ y, x-k < x' ≤ x
    yy, xx = np.arange(m.shape[0]), np.arange(m.shape[1])
    A = J[np.ix_(yy + k, xx + k)] - J[np.ix_(yy, xx + k)] - J[np.ix_(yy + k, xx)] + J[np.ix_(yy, xx)]
    return A > 0


def hopen(m, k=10):
    """Ouverture HORIZONTALE par un segment 1 × k : ne retire que ce qui fait moins de k px de LARGE (bible §1.4 :
    tiges fines de moins de 0,15 tuile de large). Une poutre ou un anneau vus par la tranche (fins en hauteur mais
    larges) restent : c'est la définition de la bible (correction du vérificateur V3, 22/10)."""
    c = np.cumsum(np.pad(m.astype(np.int32), ((0, 0), (1, 0))), 1)
    full = (c[:, k:] - c[:, :-k]) == k             # fenêtre [x, x + k) pleine
    out = np.zeros_like(m, bool)
    for d in range(k):
        out[:, d:d + full.shape[1]] |= full
    return out


def box(m):
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return None
    return dict(left=xs.min() / PPT + X0, right=(xs.max() + 1) / PPT + X0, top=ys.min() / PPT + Y0,
                bottom=(ys.max() + 1) / PPT + Y0)


def iou(a, b):
    u = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum() / u) if u else 0.0


def scaled(mask, k):
    """Masque agrandi d'un facteur k autour de l'origine (plus proche voisin)."""
    yy, xx = np.mgrid[0:H, 0:W]
    sx = ((xx + 0.5 - OX) / k + OX - 0.5).round().astype(int)
    sy = ((yy + 0.5 - OY) / k + OY - 0.5).round().astype(int)
    ok = (sx >= 0) & (sx < W) & (sy >= 0) & (sy < H)
    out = np.zeros_like(mask)
    out[ok] = mask[sy[ok], sx[ok]]
    return out


def iou_norm(m1, mN):
    """IoU normalisée en échelle autour de l'ORIGINE (k de 0,50 à 2,50) : voir norm_iou."""
    r = norm_iou(m1, mN)
    return r["origine"][0], r["origine"][1]


def _scale_about(m, k, cx, cy):
    """m agrandi de k autour du point (cx, cy) (bords de pixel), plus proche voisin (indices séparables)."""
    h, w = m.shape
    sx = np.floor((np.arange(w) + 0.5 - cx) / k + cx).astype(int)
    sy = np.floor((np.arange(h) + 0.5 - cy) / k + cy).astype(int)
    okx, oky = (sx >= 0) & (sx < w), (sy >= 0) & (sy < h)
    out = m[np.ix_(np.clip(sy, 0, h - 1), np.clip(sx, 0, w - 1))]
    return out & oky[:, None] & okx[None, :]


def norm_iou(a_full, b_full, ks=None):
    """IoU normalisée en échelle (bible §1.4, Q13 b) : max sur k de IoU(a agrandi de k, b), deux ancrages :
    - « origine » : agrandissement autour de la position de l'entité ;
    - « pied » : autour du bas-centre de la boîte de a (le sol commun : variante du vérificateur V3, 22/10).
    k de 0,50 à 2,50 par pas de 0,01 ; masques recadrés (marge de 200 px) pour la vitesse. Renvoie aussi le maximum
    des deux (« max »), qui est la valeur retenue pour les seuils (≤ 0,80 contre le niveau 1, ≤ 0,85 entre époques,
    ≤ 0,75 aux changements d'ère, ≤ 0,75 pour D1-3)."""
    if ks is None:
        ks = np.arange(0.50, 2.501, 0.01)
    m = a_full | b_full
    ys, xs = np.nonzero(m)
    pad = 200
    y0, y1 = max(0, ys.min() - pad), min(H, ys.max() + pad)
    x0, x1 = max(0, xs.min() - pad), min(W, xs.max() + pad)
    a, b = a_full[y0:y1, x0:x1], b_full[y0:y1, x0:x1]
    cx, cy = OX - x0, OY - y0
    ya, xa = np.nonzero(a)
    fx, fy = (xa.min() + xa.max() + 1) / 2.0, ya.max() + 1
    out = {}
    for name, (px, py) in (("origine", (cx, cy)), ("pied", (fx, fy))):
        best, kb = 0.0, 1.0
        for k in ks:
            v = iou(_scale_about(a, k, px, py), b)
            if v > best:
                best, kb = v, float(k)
        out[name] = (best, kb)
    out["max"] = max(out["origine"][0], out["pied"][0])
    return out


def profile_peaks(m, prom=0.12):
    """Événements de silhouette par les PICS DU PROFIL SUPÉRIEUR (indicateur du vérificateur V3, 22/10) : hauteur du
    premier pixel opaque de chaque colonne, pics de proéminence topographique ≥ `prom` tuile (un plateau compte
    pour un pic ; une colonne vide vaut le sol). Renvoie (nombre, [(x, hauteur, proéminence)])."""
    cols = m.any(0)
    top = np.where(cols, m.argmax(0), H)
    h = (OY - top) / PPT                    # hauteur à l'écran au-dessus de l'origine (tuiles)
    floor = -(H - OY) / PPT
    h = np.where(cols, h, floor)
    # plateaux -> un candidat au milieu
    n = len(h)
    peaks = []
    i = 1
    while i < n - 1:
        if h[i] > h[i - 1]:
            j = i
            while j + 1 < n and h[j + 1] == h[i]:
                j += 1
            if j + 1 < n and h[j + 1] < h[i]:
                peaks.append(((i + j) // 2, i, j))
            i = j + 1
        else:
            i += 1
    out = []
    for c, i, j in peaks:
        v = h[c]
        L = i - 1
        lmin = v
        while L >= 0 and h[L] < v:          # à gauche, un sommet ÉGAL arrête la recherche : de plusieurs pics de
            # même hauteur (créneaux), seul le premier garde la proéminence totale, les autres celle de leur creux
            lmin = min(lmin, h[L])
            L -= 1
        if L < 0:
            lmin = min(lmin, floor)
        R = j + 1
        rmin = v
        while R < n and h[R] <= v:
            rmin = min(rmin, h[R])
            R += 1
        if R >= n:
            rmin = min(rmin, floor)
        p = v - max(lmin, rmin)
        if p >= prom:
            out.append((float(c / PPT + X0), float(v), float(p)))
    return len(out), out


# Événements de silhouette visés par époque (bible §5, ligne « Signature » de chaque fiche ; §1.2 par ère)
EVTS = {1: (1, 1), 2: (1, 2), 3: (2, 2), 4: (2, 2), 5: (2, 3), 6: (3, 3), 7: (3, 3), 8: (3, 4), 9: (4, 4), 10: (4, 4),
        11: (4, 5), 12: (5, 5), 13: (5, 5), 14: (5, 6), 15: (6, 6)}


def dilate(m, r):
    """Dilatation par un carré (2r+1) × (2r+1) (image d'intégrales)."""
    k = 2 * r + 1
    I = np.zeros((m.shape[0] + k, m.shape[1] + k), np.int32)
    I[r + 1:r + 1 + m.shape[0], r + 1:r + 1 + m.shape[1]] = m.astype(np.int32)
    I = I.cumsum(0).cumsum(1)
    return (I[k:, k:] - I[:-k, k:] - I[k:, :-k] + I[:-k, :-k])[:m.shape[0], :m.shape[1]] > 0


def components(m):
    """Composantes 4-connexes d'un masque booléen (liste de tableaux d'indices (y, x))."""
    seen = np.zeros_like(m, bool)
    out = []
    H_, W_ = m.shape
    for y0, x0 in zip(*np.nonzero(m)):
        if seen[y0, x0]:
            continue
        stack, pix = [(y0, x0)], []
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            pix.append((y, x))
            for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= yy < H_ and 0 <= xx < W_ and m[yy, xx] and not seen[yy, xx]:
                    seen[yy, xx] = True
                    stack.append((yy, xx))
        out.append(np.array(pix))
    return out


def events(m, body_k=32, min_area=0.03, min_ext=0.12):
    """Indicateur APPROCHÉ du nombre d'« événements de silhouette » (bible §1.2, D1-2 : dépassements) : le corps est
    l'ouverture du masque par un carré de 0,5 tuile ; un événement est une composante connexe de ce qui DÉPASSE du
    corps (masque moins le corps dilaté de 3 px), d'aire ≥ 0,03 t² et d'étendue ≥ 0,12 t. Calcul à 32 px/tuile."""
    body = opening(m, body_k)
    prot = m & ~dilate(body, 3)
    h2, w2 = prot.shape[0] // 2, prot.shape[1] // 2
    small = prot[:h2 * 2, :w2 * 2].reshape(h2, 2, w2, 2).any(axis=(1, 3))
    found = []
    for c in components(small):
        area = len(c) / 32.0 ** 2
        ext = max(c[:, 0].max() - c[:, 0].min() + 1, c[:, 1].max() - c[:, 1].min() + 1) / 32.0
        if area >= min_area and ext >= min_ext:
            found.append((float(c[:, 1].mean() / 32.0 + X0), float(c[:, 0].mean() / 32.0 + Y0), area))
    found.sort()
    return len(found), found


def lum255(rgba):
    return (rgba[..., :3] @ LUMA) * 255.0


def photometry(rgba, m):
    L = lum255(rgba)[m]
    rgb = rgba[..., :3][m]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return dict(p05=float(np.percentile(L, 5)), p50=float(np.percentile(L, 50)), p95=float(np.percentile(L, 95)),
                sat=float(sat.mean()), rgb=[float(x) * 255 for x in rgb.mean(0)])


def glow_area(n):
    p = os.path.join(OUT, "n%02d" % n, "n%02d.json" % n)
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8") as f:
        rec = json.load(f)
    g = rec["spec"].get("glow")
    if not g:
        return 0.0
    im = load_rgba(os.path.join(OUT, "n%02d" % n, g["hr"]["filename"]))
    return float((im[..., 3] >= 0.35).sum()) / PPT ** 2


def glow_components(n):
    """Zones de lueur (couche draw_as_glow, alpha ≥ 0,35, composantes 8-connexes) : liste des boîtes (w, h) en px hr.
    Bible §1.6 et F37 : chaque zone fait au moins 8 × 8 px hr."""
    p = os.path.join(OUT, "n%02d" % n, "n%02d.json" % n)
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8") as f:
        rec = json.load(f)
    g = rec["spec"].get("glow")
    if not g:
        return []
    a = load_rgba(os.path.join(OUT, "n%02d" % n, g["hr"]["filename"]))[..., 3] >= 0.35
    out = []
    for c in components8(a):
        out.append((int(c[:, 1].max() - c[:, 1].min() + 1), int(c[:, 0].max() - c[:, 0].min() + 1), len(c)))
    return out


def components8(m):
    seen = np.zeros_like(m, bool)
    out = []
    H_, W_ = m.shape
    for y0, x0 in zip(*np.nonzero(m)):
        if seen[y0, x0]:
            continue
        stack, pix = [(y0, x0)], []
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            pix.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < H_ and 0 <= xx < W_ and m[yy, xx] and not seen[yy, xx]:
                        seen[yy, xx] = True
                        stack.append((yy, xx))
        out.append(np.array(pix))
    return out


def light_surface(n):
    """Surface (t²) de la couche halo de nuit (draw_as_light) d'alpha > 0,1 (protocole du vérificateur V3)."""
    p = os.path.join(OUT, "n%02d" % n, "n%02d.json" % n)
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8") as f:
        rec = json.load(f)
    g = rec["spec"].get("light")
    if not g:
        return 0.0
    a = load_rgba(os.path.join(OUT, "n%02d" % n, g["hr"]["filename"]))[..., 3]
    return float((a > 0.1).sum()) / PPT ** 2


def meca_share(n, m):
    """Part VISIBLE du mécanisme animé (module meca, passe de contrôle du rendu) dans le masque du niveau, et sa
    position. « Haut-centre » : la zone animée du vanilla (bible §2.8 : x de -0,9 à +0,95, y de -1,6 à +0,7), prolongée
    vers le haut (une machine plus haute garde son toit au même endroit en x) : |x| ≤ 0,95 et y ≤ +0,70."""
    p = os.path.join(OUT, "n%02d" % n, "n%02d.json" % n)
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8") as f:
        rec = json.load(f)
    d = rec["spec"].get("_meca_alpha")
    if not d:
        return None
    a = np.asarray(Image.open(os.path.join(OUT, "n%02d" % n, d["filename"]))).astype(np.float64) / 255.0
    ox, oy = d["origin_px"]
    img = np.zeros(a.shape + (4,))
    img[..., 3] = a
    h, w = a.shape
    lay = put(img, ((w / 2.0 - ox) / PPT, (h / 2.0 - oy) / PPT))[..., 3] >= 0.5
    lay &= m
    if not m.sum():
        return None
    b = box(m)
    ys, xs = np.nonzero(lay)
    if not len(xs):
        return {"share": 0.0}
    xt, yt = xs / PPT + X0, ys / PPT + Y0
    hc = ((np.abs(xt) <= 0.95) & (yt <= 0.70)).sum() / float(len(xt))
    # part ANIMÉE au sens de la bible §2.8 (pixels qui changent de plus de 32/255 d'une image à l'autre) : mécanisme
    # + zones émissives qui pulsent ou clignotent selon le calendrier §1.6 (braises, arcs, cristaux, bulles, voyants,
    # chenillard, plasma, balises...), soit la couche de lueur (alpha ≥ 0,35) ; l'amplitude réelle des pulsations
    # (> 32/255 ?) n'existe qu'en phase 2 : HYPOTHÈSE, non prouvée
    g = rec["spec"].get("glow")
    anim = lay.copy()
    if g:
        gi = load_rgba(os.path.join(OUT, "n%02d" % n, g["hr"]["filename"]))
        anim |= (put(gi, g["hr"]["shift"])[..., 3] >= 0.35) & m
    return {"share": float(lay.sum() / m.sum()), "cx": float(xt.mean()), "cy": float(yt.mean()),
            "haut_centre": float(hc), "anim_share": float(anim.sum() / m.sum())}


# Comptage À L'ŒIL des événements de silhouette (dépassements lisibles sur la vignette de 64 px, y compris les
# dépassements LATÉRAUX que l'indicateur des pics ne voit pas), lu le 22/10 sur d-vignettes-evenements.png et
# d-vignettes-masques.png (rendus d'aperçu du 22/10, un seul lecteur : le correcteur V3 ; à relire par V4) :
# N1 bosses du toit à peine lisibles ; N3 tour crénelée + volant latéral ; N5 chaudière-cheminée + volant ; N7 portique
# + torchère ; N9 deux aiguilles + marteau ; N11 deux piles arrière + bras ; N13 trois cristaux ; N15 deux fioles + deux
# cuves latérales ; N17 mât, deux coudes, cheminée ; N19 deux coudes, antenne, radôme ; N21 cinq ailerons ; N23 deux
# pylônes, deux éclats, bloc ; N25 deux fleurons, deux injecteurs, colonne ; N27 quatre mâts-balises + parabole ; N29
# deux petites flèches + quatre flèches de couronne (lisibles mais serrées à 64 px).
OEIL = {1: 1, 3: 2, 5: 2, 7: 2, 9: 3, 11: 3, 13: 3, 15: 4, 17: 4, 19: 4, 21: 5, 23: 5, 25: 5, 27: 5, 29: 6}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default="complet", choices=("complet", "masque"))
    ap.add_argument("--sortie", default="")
    ap.add_argument("--json", default=os.path.join(OUT, "mesures-d1.json"))
    a = ap.parse_args()
    rgba, mask = {}, {}
    for n in range(1, 31):
        try:
            rgba[n] = level_rgba(n, a.source)
        except FileNotFoundError:
            continue
        mask[n] = rgba[n][..., 3] >= 0.5
    half = params.EMPRISE / 2.0
    fp = np.zeros((H, W), bool)
    fp[int(OY - half * PPT):int(OY + half * PPT), int(OX - half * PPT):int(OX + half * PPT)] = True
    A1 = mask[1]
    res = {"source": a.source, "levels": {}}
    lines = []
    P_ = lines.append
    P_("Mesures D1 · machine d'assemblage 2 · source : rendus d'aperçu « %s » (64 px/tuile, masque alpha ≥ 0,5 de la "
       "couche principale ; niveau 1 = vanilla hr image 0 ; niveau 2 = vanilla + pièce)" % a.source)
    P_("Correction V3 du 22/10 : O des masses par ouverture HORIZONTALE 1 × 10 px (bible §1.4 : seules les tiges de "
       "moins de 0,15 tuile de LARGE sont retirées ; l'ancienne ouverture carrée est donnée pour mémoire, « O_car ») ;")
    P_("IoU normalisée en échelle (Q13 b) : max sur k ∈ [0,50 ; 2,50] de IoU(a agrandi de k, b), ancrage à l'ORIGINE "
       "et au PIED (bas-centre de la boîte de a) ; la valeur retenue est le maximum des deux.")
    P_("Seuils de travail (vérificateur V3) : nIoU(1, n) ≤ 0,80 ; nIoU entre époques consécutives ≤ 0,85, ≤ 0,75 aux "
       "changements d'ère ; D1-3 : IoU(1, 30) ≤ 0,45 et nIoU(1, 30) ≤ 0,75.")
    P_("")
    P_("niv ép  O_mas  O_car  O_tot  L_mas  aire   empr  V%   IoU_prec  ajout  dL     IoU_1n  nIoU_1n(o/p)   "
       "envO  envL  envV  ΔO/env")
    for n in range(1, 31):
        if n not in mask:
            continue
        m = mask[n]
        e = params.epoque(n)
        b, bh, bs = box(m), box(hopen(m)), box(opening(m))
        r = {"epoch": e, "O_masses": -bh["top"] - half, "O_carre": -bs["top"] - half, "O_total": -b["top"] - half,
             "L_masses": bh["right"] - bh["left"], "area": m.sum() / PPT ** 2, "footprint_cover": (m & fp).sum() /
             fp.sum(), "V_pct": (A1 & ~m).sum() / A1.sum() * 100, "box": b, "iou_1": iou(A1, m)}
        if n > 1:
            nr = norm_iou(A1, m)
            r["niou_1"] = nr["max"]
            r["niou_1_detail"] = {"origine": nr["origine"], "pied": nr["pied"]}
        if n > 1 and (n - 1) in mask:
            r["iou_prev"] = iou(mask[n - 1], m)
        if n % 2 == 0 and (n - 1) in mask:
            both = m & mask[n - 1]
            r["piece_added"] = (m & ~mask[n - 1]).sum() / PPT ** 2
            r["lum_changed"] = (((np.abs(lum255(rgba[n]) - lum255(rgba[n - 1])) >= 20) & both).sum() / PPT ** 2
                                if a.source == "complet" else None)
        if a.source == "complet" and n > 1:
            r["photo"] = photometry(rgba[n], m)
            r["glow_area"] = glow_area(n)
        env = params.ENVELOPPE[e]
        res["levels"][n] = r
        nd = r.get("niou_1_detail")
        P_("%3d %2d  %5.2f  %5.2f  %5.2f  %5.2f  %5.2f  %3.0f%%  %3.0f  %s  %s  %s  %5.3f   %s  %4.2f  %4.2f  %3d  %s" % (
            n, e, r["O_masses"], r["O_carre"], r["O_total"], r["L_masses"], r["area"], r["footprint_cover"] * 100,
            r["V_pct"], ("%6.3f" % r["iou_prev"]) if "iou_prev" in r else "   -  ",
            ("%5.2f" % r["piece_added"]) if "piece_added" in r else "  -  ",
            ("%5.2f" % r["lum_changed"]) if r.get("lum_changed") is not None else "  -  ", r["iou_1"],
            ("%.3f/%.3f %s" % (nd["origine"][0], nd["pied"][0], "ok" if r["niou_1"] <= 0.80 else "HAUT")) if nd else
            "   -          ", env[0], env[1], env[2],
            ("%+.2f" % (r["O_masses"] - env[0])) if n % 2 == 1 else "  pair"))
    odd = [n for n in range(1, 31, 2) if n in mask]
    P_("")
    P_("Plafond Q9 : O des masses ≤ 1,50 à tous les niveaux : %s ; maximum %.2f (niveau %d)" % (
        "RESPECTÉ" if max(res["levels"][n]["O_masses"] for n in mask) <= params.PLAFOND_O + 1e-9 else "DÉPASSÉ",
        max(res["levels"][n]["O_masses"] for n in mask),
        max(mask, key=lambda n: res["levels"][n]["O_masses"])))
    P_("Écart des niveaux impairs à l'enveloppe O du rang (bible §4, visé ±0,05) : " + "  ".join(
        "%d:%+.2f" % (n, res["levels"][n]["O_masses"] - params.ENVELOPPE[params.epoque(n)][0]) for n in odd))
    P_("Écart des niveaux impairs à l'enveloppe L du rang : " + "  ".join(
        "%d:%+.2f" % (n, res["levels"][n]["L_masses"] - params.ENVELOPPE[params.epoque(n)][1]) for n in odd))
    P_("")
    P_("D1-2 · époques consécutives (niveaux impairs) : IoU brute, IoU normalisée (origine/pied, max) ; seuil 0,85, "
       "0,75 aux changements d'ère ; O des masses jamais décroissant")
    res["consecutive"] = {}
    for i in range(len(odd) - 1):
        p, q = odd[i], odd[i + 1]
        v = iou(mask[p], mask[q])
        nr = norm_iou(mask[p], mask[q])
        era = params.EPOQUES[params.epoque(p)]["ere"] != params.EPOQUES[params.epoque(q)]["ere"]
        lim = 0.75 if era else 0.85
        dO = res["levels"][q]["O_masses"] - res["levels"][p]["O_masses"]
        res["consecutive"]["%d-%d" % (p, q)] = {"iou": v, "niou": nr["max"], "niou_origine": nr["origine"],
                                                 "niou_pied": nr["pied"], "seuil": lim, "dO": dO}
        P_("  %2d -> %2d (ép. %2d -> %2d%s) : IoU %.3f ; nIoU %.3f/%.3f -> %.3f (≤ %.2f : %s) ; ΔO %+.2f %s" % (
            p, q, params.epoque(p), params.epoque(q), ", CHANGEMENT D'ÈRE" if era else "", v, nr["origine"][0],
            nr["pied"][0], nr["max"], lim, "ok" if nr["max"] <= lim else "ÉCHEC", dO, "ok" if dO >= -1e-9 else
            "DÉCROÎT"))
    P_("")
    P_("D1-2 · événements de silhouette des niveaux impairs. Indicateur 1 (vérificateur V3) : pics du profil supérieur de "
       "proéminence ≥ 0,12 t (de plusieurs sommets égaux, seul le premier garde la proéminence totale). Indicateur 2 "
       "(ancien) : composantes qui dépassent du corps ouvert à 0,5 t. À l'œil : planche d-vignettes-evenements.png. "
       "Cible : fiche d'époque (bible §5), fourchette de l'ère (§1.2)")
    for n in odd:
        e = params.epoque(n)
        k, pk = profile_peaks(mask[n])
        k2, _ = events(mask[n])
        lo, hi = EVTS[e]
        res["levels"][n]["events"] = k
        res["levels"][n]["events_old"] = k2
        res["levels"][n]["events_peaks"] = pk
        oe = OEIL.get(n)
        if oe is not None:
            res["levels"][n]["events_eye"] = oe
        P_("  niveau %2d (ép. %2d, ère %-3s) : pics %d [visé %s] %s ; ancien %d ; à l'œil %s ; pics x = %s" % (
            n, e, params.EPOQUES[e]["ere"], k, ("%d" % lo) if lo == hi else ("%d à %d" % (lo, hi)),
            "ok" if lo <= k <= hi else ("sous" if k < lo else "au-dessus"), k2, "-" if oe is None else str(oe),
            " ".join("%+.2f" % x for x, _, _ in pk)))
    P_("")
    P_("O des masses sur les 30 niveaux (un niveau pair porte la pièce, souvent au-dessus : le niveau impair suivant peut "
       "être plus bas que lui)")
    seq = [n for n in range(1, 31) if n in mask]
    P_("  " + "  ".join("%d:%.2f" % (n, res["levels"][n]["O_masses"]) for n in seq))
    P_("")
    P_("D1-1 · niveaux pairs : aire ajoutée par la pièce (≥ 0,10 t²) ; niveaux impairs : IoU avec le pair précédent (≤ 0,85)")
    for n in range(2, 31):
        if n not in mask:
            continue
        r = res["levels"][n]
        if n % 2 == 0 and "piece_added" in r:
            ok = r["piece_added"] >= 0.10 or (r.get("lum_changed") or 0) >= 0.15
            P_("  niveau %2d : pièce +%.3f t² hors du masque impair ; luminance changée sur %s t² ; O %+.2f -> %s" % (
                n, r["piece_added"], ("%.3f" % r["lum_changed"]) if r.get("lum_changed") is not None else "-",
                r["O_masses"] - res["levels"][n - 1]["O_masses"], "ok" if ok else "ÉCHEC"))
        elif n % 2 == 1 and "iou_prev" in r:
            P_("  niveau %2d : IoU avec le niveau %d = %.3f -> %s" % (n, n - 1, r["iou_prev"],
                                                                      "ok" if r["iou_prev"] <= 0.85 else "ÉCHEC"))
    P_("")
    P_("D1-4 · emprise : collision ±1,2 et sélection ±1,5 INCHANGÉES par construction ; débord visuel du masque hors de "
       "l'emprise 3 × 3 (≤ 0,25 admis, bible §1.3)")
    for n in range(1, 31):
        if n not in mask:
            continue
        b = res["levels"][n]["box"]
        ox_ = max(-b["left"] - half, b["right"] - half, 0.0)
        ob_ = max(b["bottom"] - half, 0.0)
        res["levels"][n]["overhang"] = {"side": ox_, "bottom": ob_}
        P_("  niveau %2d : x de %+.2f à %+.2f, bas %+.2f ; débord latéral %.2f, bas %.2f -> %s" % (
            n, b["left"], b["right"], b["bottom"], ox_, ob_, "ok" if ox_ <= 0.25 and ob_ <= 0.25 else "DÉBORD"))
    P_("")
    if 30 in mask:
        P_("D1-3 amendé (Q13) · niveau 1 contre les niveaux 29 et 30, masque sans couche plate au sol")
        for n in (29, 30):
            if n not in mask:
                continue
            v = iou(A1, mask[n])
            nr = norm_iou(A1, mask[n])
            res["D1_3_%d" % n] = {"iou": v, "iou_norm": nr["max"], "origine": nr["origine"], "pied": nr["pied"],
                                  "V_pct": res["levels"][n]["V_pct"], "area": res["levels"][n]["area"]}
            P_("  niveau 1 / niveau %d : IoU %.3f (cible ≤ 0,45 : %s) ; nIoU origine %.3f (k %.2f), pied %.3f (k %.2f) "
               "-> %.3f (≤ 0,75 : %s) ; V %.0f %% (≥ 35) ; aire %.2f t² (vanilla 6,98)" % (
                   n, v, "ok" if v <= 0.45 else ("< 0,50" if v < 0.5 else "ÉCHEC"), nr["origine"][0], nr["origine"][1],
                   nr["pied"][0], nr["pied"][1], nr["max"], "ok" if nr["max"] <= 0.75 else "AU-DESSUS",
                   res["levels"][n]["V_pct"], res["levels"][n]["area"]))
    if a.source == "complet":
        P_("")
        P_("Photométrie de la couche principale (pixels opaques ; luminance sRGB sur 255 ; bible §1.5 : p50 cible de "
           "l'époque ±10, p95 ≤ 240, saturation ≤ 0,45) et lueur de jour (aire alpha ≥ 0,35, t² ; part du masque)")
        cibles = {1: 50, 2: 52, 3: 58, 4: 60, 5: 42, 6: 64, 7: 55, 8: 60, 9: 56, 10: 82, 11: 100, 12: 60, 13: 92, 14: 88,
                  15: 108}
        for n in range(2, 31):
            r = res["levels"].get(n)
            if not r or "photo" not in r:
                continue
            ph = r["photo"]
            e = r["epoch"]
            ga = r.get("glow_area") or 0.0
            P_("  niveau %2d (ép. %2d) : p05 %5.1f  p50 %5.1f (cible %3d %s)  p95 %5.1f %s  sat %.2f %s  lueur %.3f t² "
               "(%.1f %%)" % (n, e, ph["p05"], ph["p50"], cibles[e], "ok" if abs(ph["p50"] - cibles[e]) <= 10 else "hors",
                              ph["p95"], "ok" if ph["p95"] <= 240 else "HORS", ph["sat"],
                              "ok" if ph["sat"] <= 0.45 else "HORS", ga, ga / r["area"] * 100))
        P_("")
        P_("Flèches de couronne de l'époque 15 (or blanc #E8DCB0, luminance de l'albédo ≈ 215) : pixels opaques au-dessus "
           "de la traverse haute du cadre (y < -2,70) et |x| < 0,95 ; visé p50 ≥ 140")
        for n in (29, 30):
            if n not in mask:
                continue
            reg = np.zeros_like(mask[n])
            reg[:int(OY - 2.70 * PPT), int(OX - 0.95 * PPT):int(OX + 0.95 * PPT)] = True
            sel = mask[n] & reg
            if sel.sum():
                L = lum255(rgba[n])[sel]
                rgb = rgba[n][..., :3][sel].mean(0) * 255
                res["levels"][n]["spires"] = {"p50": float(np.percentile(L, 50)), "rgb": [float(x) for x in rgb],
                                              "px": int(sel.sum())}
                P_("  niveau %d : %d px ; RGB moyen (%.0f, %.0f, %.0f) ; luminance p50 %.1f -> %s" % (
                    n, sel.sum(), rgb[0], rgb[1], rgb[2], np.percentile(L, 50),
                    "ok" if np.percentile(L, 50) >= 140 else "SOMBRE"))
        P_("")
        P_("Zones de lueur (draw_as_glow, alpha ≥ 0,35, composantes 8-connexes) : bible §1.6 et F37 : au moins 8 × 8 px hr ; "
           "zones plus petites listées (largeur × hauteur en px hr)")
        for n in range(2, 31):
            gc = glow_components(n)
            if gc is None:
                continue
            small = [(w_, h_) for w_, h_, _ in gc if w_ < 8 or h_ < 8]
            res["levels"][n]["glow_small"] = small
            res["levels"][n]["glow_zones"] = len(gc)
            P_("  niveau %2d : %2d zone(s), %d sous 8 × 8 px %s" % (n, len(gc), len(small), (
                "(" + ", ".join("%d×%d" % s_ for s_ in small[:12]) + (" …" if len(small) > 12 else "") + ")") if small
                else "-> ok"))
        P_("")
        P_("Halo de nuit (draw_as_light) : surface d'alpha > 0,1 (t²), visée croissante avec le niveau (bible §1.6, D2-3 ; "
           "flaque imposée de rayon S(N) = 0,80 × (1 + 0,05·N) : π·S² donné pour comparaison)")
        prev, bad = None, []
        row = []
        for n in range(2, 31):
            sf = light_surface(n)
            if sf is None:
                continue
            res["levels"][n]["halo_surface"] = sf
            S_ = params.flaque(n)["S"]
            row.append("%d:%.1f(%.1f)" % (n, sf, np.pi * S_ ** 2))
            if prev is not None and sf < prev - 0.05:
                bad.append(n)
            prev = sf if prev is None else max(prev, sf)
        P_("  " + "  ".join(row))
        P_("  niveaux plus petits qu'un niveau inférieur (tolérance 0,05 t²) : " + (", ".join(map(str, bad)) or "aucun"))
        P_("")
        P_("Mécanisme animé (module meca) : part VISIBLE dans le masque du niveau impair, centre (x ; y) et part située en "
           "haut-centre (|x| ≤ 0,95 et y ≤ +0,70 : zone animée du vanilla prolongée vers le haut) ; vanilla : 30 %, "
           "haut-centre ; visé > 20 % en haut-centre (bible §2.8)")
        for n in odd:
            if n == 1:
                continue
            ms = meca_share(n, mask[n])
            if ms is None:
                continue
            res["levels"][n]["meca_share"] = ms["share"]
            res["levels"][n]["meca"] = ms
            if "cx" in ms:
                P_("  niveau %2d : mécanisme %4.1f %% des pixels ; centre (%+.2f ; %+.2f) ; %3.0f %% en haut-centre -> %s ; "
                   "avec les zones émissives animées : %4.1f %% -> %s" % (
                       n, ms["share"] * 100, ms["cx"], ms["cy"], ms["haut_centre"] * 100,
                       "ok" if ms["share"] >= 0.20 and ms["haut_centre"] >= 0.5 else "sous 20 %",
                       ms["anim_share"] * 100, "ok" if ms["anim_share"] >= 0.20 else "sous 20 %"))
            else:
                P_("  niveau %2d : aucun pixel visible -> INSUFFISANT" % n)
    txt = "\n".join(lines)
    sys.stdout.buffer.write((txt + "\n").encode("utf-8"))
    if a.sortie:
        os.makedirs(os.path.dirname(os.path.abspath(a.sortie)), exist_ok=True)
        with open(a.sortie, "w", encoding="utf-8", newline="\n") as f:
            f.write(txt + "\n")
    os.makedirs(os.path.dirname(a.json), exist_ok=True)
    with open(a.json, "w", encoding="utf-8") as f:
        json.dump(res, f, indent=1, default=float)


if __name__ == "__main__":
    main()
