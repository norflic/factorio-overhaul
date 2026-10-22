"""Tourelle laser, lot V3 phase 1 (correction V3) : mesures de forme PURES (numpy seul), partagées par la mesure des
aperçus (measure_laser.py), le contrôle géométrique (geo_check.py) et le réglage des pivots (run_laser.py tune).

Bible §1.4 : « O : dépassement au-dessus du bord haut de l'emprise du sommet des MASSES principales. Les tiges fines
(moins de 0,15 tuile de large : mâts, antennes, paratonnerres) sont notées à part et ne comptent pas dans O. »
« L : largeur visuelle maximale de la boîte des masses. »
Réalisation (proposée par la vérification de la passe 5) :
- masses pour O = OUVERTURE HORIZONTALE du masque par un segment de TIGE_PX = 10 px hr (0,156 tuile) : toute partie
  de moins de 10 px de large disparaît (mât, antenne, épine), une masse plus large reste entière ;
- masses pour L = ouverture VERTICALE par le même segment (une tige horizontale ne compte pas dans L) ;
- la hauteur des tiges reste mesurée à part (O_brut = sommet du masque complet).
Une pointe (cristal, flèche) perd aussi son extrémité de moins de 10 px de large : elle est comptée comme une tige.
"""
import math

import numpy as np

TIGE_PX = 10            # 0,15 tuile = 9,6 px hr : segment de 10 px
PPT = 64.0


def _open_1d(m, w, axis):
    """Ouverture binaire par un segment de w pixels le long de `axis` (érosion puis dilatation)."""
    m = np.asarray(m, bool)
    if axis == 0:
        return _open_1d(m.T, w, 1).T
    H, W = m.shape
    if W < w:
        return np.zeros_like(m)
    c = np.zeros((H, W + 1), np.int32)
    np.cumsum(m, axis=1, out=c[:, 1:])
    ero = (c[:, w:] - c[:, :-w]) == w                 # fenêtre [x, x + w) entièrement pleine : (H, W - w + 1)
    ce = np.zeros((H, ero.shape[1] + 1), np.int32)
    np.cumsum(ero, axis=1, out=ce[:, 1:])
    x = np.arange(W)
    hi = np.minimum(x, ero.shape[1] - 1) + 1          # départs de fenêtre s dans [x - w + 1, x]
    lo = np.maximum(x - w + 1, 0)
    ok = hi > lo
    out = np.zeros_like(m)
    out[:, ok] = (ce[:, hi[ok]] - ce[:, lo[ok]]) > 0
    return out


def masses_O(m, w=TIGE_PX):
    """Masque des masses pour O (tiges verticales fines retirées)."""
    return _open_1d(m, w, 1)


def masses_L(m, w=TIGE_PX):
    """Masque des masses pour L (tiges horizontales fines retirées)."""
    return _open_1d(m, w, 0)


def top_bottom(m):
    rows = np.nonzero(np.asarray(m).any(1))[0]
    if rows.size == 0:
        return None, None
    return int(rows.min()), int(rows.max()) + 1


def left_right(m):
    cols = np.nonzero(np.asarray(m).any(0))[0]
    if cols.size == 0:
        return None, None
    return int(cols.min()), int(cols.max()) + 1


def shape_metrics(m, origin):
    """O (masses), O_brut (tiges comprises), L (masses), L_brut, boîte brute ; tuiles, origine = position de l'entité."""
    ox, oy = origin
    y0, y1 = top_bottom(m)
    x0, x1 = left_right(m)
    mo = masses_O(m)
    ml = masses_L(m)
    yo, _ = top_bottom(mo)
    lx0, lx1 = left_right(ml)
    t = lambda px, o: (px - o) / PPT
    return {"top": t(y0, oy), "bottom": t(y1, oy), "left": t(x0, ox), "right": t(x1, ox),
            "O": (-t(yo, oy) - 1.0) if yo is not None else float("nan"),
            "O_brut": -t(y0, oy) - 1.0,
            "L": ((lx1 - lx0) / PPT) if lx0 is not None else 0.0,
            "L_brut": (x1 - x0) / PPT,
            "area": float(np.asarray(m).sum() / PPT ** 2)}


def raster_tris(xy_px, shape):
    """Masque des triangles écran (N, 3, 2) en pixels (remplissage plein, Pillow)."""
    from PIL import Image, ImageDraw
    H, W = shape
    img = Image.new("L", (W, H), 0)
    dr = ImageDraw.Draw(img)
    for tri in xy_px:
        dr.polygon([(float(p[0]), float(p[1])) for p in tri], fill=255)
    return np.asarray(img) > 0


def largest_square(m):
    """Côté du plus grand carré ENTIÈREMENT couvert (recherche dichotomique sur une image intégrale)."""
    m = np.asarray(m, bool)
    if not m.any():
        return 0
    ii = np.zeros((m.shape[0] + 1, m.shape[1] + 1), np.int64)
    ii[1:, 1:] = m.cumsum(0).cumsum(1)

    def ok(k):
        if k > min(m.shape):
            return False
        s = ii[k:, k:] - ii[:-k, k:] - ii[k:, :-k] + ii[:-k, :-k]
        return bool((s == k * k).any())
    lo, hi = 1, min(m.shape)
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if ok(mid):
            lo = mid
        else:
            hi = mid - 1
    return lo


def profile_peaks(h, prom):
    """Pics d'un profil 1D h (NaN = colonne vide, prise à 0) de proéminence ≥ prom (pixels) : [(indice, proéminence)].
    Proéminence classique : hauteur du pic au-dessus du plus haut des deux cols qui le séparent d'un point plus haut
    (ou du bord, pris au niveau 0)."""
    h = np.nan_to_num(np.asarray(h, float), nan=0.0)
    n = len(h)
    out = []
    i = 0
    while i < n:
        j = i
        while j + 1 < n and h[j + 1] == h[i]:
            j += 1
        left = h[i - 1] if i > 0 else 0.0
        right = h[j + 1] if j + 1 < n else 0.0
        v = h[i]
        if v > 0 and v > left and v > right:
            a, lmin = i, v
            while a > 0 and h[a - 1] <= v:
                a -= 1
                lmin = min(lmin, h[a])
            lbase = lmin if a > 0 else 0.0
            b, rmin = j, v
            while b < n - 1 and h[b + 1] <= v:
                b += 1
                rmin = min(rmin, h[b])
            rbase = rmin if b < n - 1 else 0.0
            p = v - max(lbase, rbase)
            if p >= prom:
                out.append(((i + j) // 2, float(p)))
        i = j + 1
    return out


def silhouette_events(m, origin, prom_px=8, ground_rows=None):
    """« Événements » de silhouette (bible §1.2, D1-2) : dépassements du contour HAUT (pics du profil supérieur de
    proéminence ≥ prom_px, soit 0,125 tuile) et LATÉRAUX (pics des profils gauche et droit, même seuil), mesurés sur le
    masque complet. Indicateur proposé (la bible ne définit pas le comptage) : à lire avec la vignette, pas à sa place."""
    m = np.asarray(m, bool)
    H, W = m.shape
    cols = m.any(0)
    top = np.where(cols, H - np.argmax(m, axis=0), np.nan)          # hauteur du sommet par colonne (px depuis le bas)
    rows = m.any(1)
    left = np.where(rows, W - np.argmax(m, axis=1), np.nan)          # avancée vers la gauche par rangée
    right = np.where(rows, W - np.argmax(m[:, ::-1], axis=1), np.nan)
    tp = profile_peaks(top, prom_px)
    lp = profile_peaks(left, prom_px)
    rp = profile_peaks(right, prom_px)
    # un pic latéral tout en haut du masque est déjà le pic haut : on l'écarte (rangées à moins de prom_px du sommet)
    # l'extrémité latérale elle-même (pic de plus grande avancée) n'est pas un dépassement : seuls les pics latéraux
    # SECONDAIRES comptent (une boîte simple vaut 1 événement : son sommet)
    def drop_global(pk, prof):
        if not pk:
            return pk
        g = int(np.nanargmax(prof))
        k = min(range(len(pk)), key=lambda i: abs(pk[i][0] - g))
        return pk[:k] + pk[k + 1:]
    lp = drop_global(lp, left)
    rp = drop_global(rp, right)
    return {"haut": len(tp), "gauche": len(lp), "droite": len(rp), "total": len(tp) + len(lp) + len(rp)}


def iou(a, b):
    u = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum() / u) if u else 0.0


def scale_about(m, k, origin, pad=0):
    """Homothétie de rapport k autour de origin, sur un canevas agrandi de `pad` px de chaque côté."""
    H, W = m.shape
    ox, oy = origin
    Hp, Wp = H + 2 * pad, W + 2 * pad
    yy, xx = np.mgrid[0:Hp, 0:Wp]
    sx = np.floor(ox + (xx - pad + 0.5 - ox) / k).astype(int)
    sy = np.floor(oy + (yy - pad + 0.5 - oy) / k).astype(int)
    ok = (sx >= 0) & (sx < W) & (sy >= 0) & (sy < H)
    out = np.zeros((Hp, Wp), bool)
    out[ok] = m[sy[ok], sx[ok]]
    return out


def scaled_shifted_iou(a1, b, origin, ks, tmax=32):
    """max sur k et sur une translation libre t (|tx|, |ty| ≤ tmax px) de IoU(a1 agrandi de k autour de l'origine puis
    translaté de t, b). Intersection de toutes les translations par corrélation FFT. Renvoie (IoU, k, tx, ty)."""
    pad = tmax
    H, W = b.shape
    bp = np.zeros((H + 2 * pad, W + 2 * pad))
    bp[pad:pad + H, pad:pad + W] = b
    nb = b.sum()
    FB = np.conj(np.fft.rfft2(bp))
    best = (0.0, 1.0, 0, 0)
    for k in ks:
        ak = scale_about(a1, k, origin, pad).astype(float)
        na = a1.sum() * k * k
        corr = np.fft.irfft2(np.fft.rfft2(ak) * FB, s=bp.shape)
        # corr[dy, dx] = sum_p ak(p + d) b(p) : décalage de ak de -d ; on lit les décalages |d| ≤ tmax
        idx = np.r_[0:tmax + 1, -tmax:0]
        sub = np.round(corr[np.ix_(idx % bp.shape[0], idx % bp.shape[1])])
        v = sub / np.maximum(na + nb - sub, 1)
        i = np.unravel_index(np.argmax(v), v.shape)
        if v[i] > best[0]:
            best = (float(v[i]), float(k), int(-idx[i[1]]), int(-idx[i[0]]))
    return best
