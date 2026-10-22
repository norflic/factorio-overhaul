"""Contrôles automatiques des couches rendues (lot V0b) : Python système, numpy seul (pas de scipy).

Chaque fonction prend des tableaux (H, W[, 4]) en flottants 0..1 (sRGB codé, alpha droit, comme fo_post)
et renvoie des nombres : render.py les écrit dans le manifeste (« checks ») et refuse le rendu quand un
seuil bloquant est franchi ; check_sprites.py les refait sur les PNG livrés.

Origine des contrôles : vérification indépendante des captures V0
(<racine>\\fo-logs\\2026-10-21_V0_verif-captures\\rapport.md) :
- trous enfermés dans la silhouette (collerette translucide : le sol se voyait au travers) ;
- éléments plus fins que 2 px HR (garde-corps, poteaux, échelle : anneau pâle la nuit) ;
- halo (draw_as_light) posé sur la pièce ou sur le bâtiment porteur (il révèle leur couleur de jour) ;
- poches sombres enfermées dans le halo (« ombre fantôme » d'une partie cachée) ;
- photométrie du CORPS hors zones émissives (la lueur additive masquait le défaut de matité) ;
- plus grand carré émissif plein (critère D2-1 : au moins 8 × 8 px HR).
Ajouts du correcteur V0b (vérification des captures V0b) :
- règles de palette de la bible (docs/DESIGN_EPOQUES.md §1.5 : médiane d'époque ± 10, p95 ≤ 240, saturation
  ≤ 0,45) et rapport de luminance pièce / bâtiment vanilla porteur ;
- saturation, pics isolés d'un pixel (« lucioles » des rivets) et rapport laplacien / écart-type dans la
  photométrie.
"""
import numpy as np


def lum(rgb):
    """Luminance (Rec. 709) des valeurs sRGB codées, comme fitlib.py et les vérifications V0."""
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


# ------------------------------------------------------------------------------------------------
# Morphologie (numpy seul)
# ------------------------------------------------------------------------------------------------
def _shift(m, dy, dx, fill=False):
    out = np.full_like(m, fill)
    H, W = m.shape
    ys, yd = (slice(0, H - dy), slice(dy, H)) if dy >= 0 else (slice(-dy, H), slice(0, H + dy))
    xs, xd = (slice(0, W - dx), slice(dx, W)) if dx >= 0 else (slice(-dx, W), slice(0, W + dx))
    out[yd, xd] = m[ys, xs]
    return out


def dilate(mask, radius):
    """Dilatation d'un masque booléen par un disque de rayon `radius` px."""
    mask = np.asarray(mask, bool)
    if radius <= 0:
        return mask.copy()
    out = mask.copy()
    r = int(np.ceil(radius))
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= radius * radius and (dx or dy):
                out |= _shift(mask, dy, dx)
    return out


def reach_from_border(free):
    """Pixels de `free` reliés au bord de l'image (4-connexité), par propagation itérative."""
    free = np.asarray(free, bool)
    seen = np.zeros_like(free)
    seen[0, :] = free[0, :]
    seen[-1, :] = free[-1, :]
    seen[:, 0] |= free[:, 0]
    seen[:, -1] |= free[:, -1]
    while True:
        grow = seen | _shift(seen, 1, 0) | _shift(seen, -1, 0) | _shift(seen, 0, 1) | _shift(seen, 0, -1)
        grow &= free
        if (grow == seen).all():
            return seen
        seen = grow


# ------------------------------------------------------------------------------------------------
# Couche principale
# ------------------------------------------------------------------------------------------------
def enclosed_transparent(alpha, thr=0.5):
    """Pixels d'alpha < thr ENFERMÉS dans la silhouette (non reliés au bord par d'autres pixels
    d'alpha < thr) : le sol se verrait au travers de la pièce. Renvoie (nombre, alpha moyen, masque)."""
    a = np.asarray(alpha, np.float64)
    free = a < thr
    holes = free & ~reach_from_border(free)
    n = int(holes.sum())
    return n, (float(a[holes].mean()) if n else 0.0), holes


def thin_pixels(alpha, lo=0.1, hi=0.9, reach=2):
    """Pixels d'alpha partiel (lo..hi) bordés de pixels opaques (≥ hi) des DEUX côtés, à `reach` px au
    plus, horizontalement ou verticalement : éléments plus fins que 2 px HR ou interstices. Renvoie
    (nombre, part de la silhouette alpha ≥ 0,5)."""
    a = np.asarray(alpha, np.float64)
    part = (a > lo) & (a < hi)
    op = a >= hi
    hit = np.zeros_like(part)
    for axis in ((0, 1), (1, 0)):
        left = np.zeros_like(part)
        right = np.zeros_like(part)
        for k in range(1, reach + 1):
            left |= _shift(op, axis[0] * k, axis[1] * k)
            right |= _shift(op, -axis[0] * k, -axis[1] * k)
        hit |= part & left & right
    sil = max(1, int((a >= 0.5).sum()))
    return int(hit.sum()), float(hit.sum()) / sil


def largest_full_square(mask):
    """Côté du plus grand carré entièrement dans `mask` (programmation dynamique)."""
    m = np.asarray(mask, bool)
    H, W = m.shape
    dp = np.zeros((H + 1, W + 1), np.int32)
    best = 0
    for y in range(H):
        row = m[y]
        prev = dp[y]
        cur = dp[y + 1]
        for x in range(W):
            if row[x]:
                v = 1 + min(prev[x], prev[x + 1], cur[x])
                cur[x + 1] = v
                if v > best:
                    best = v
    return int(best)


def saturation(rgb, mask):
    """Saturation HSV moyenne ((max - min) / max) des pixels de `mask` (méthode de la bible et de fitlib)."""
    mx, mn = rgb.max(-1), rgb.min(-1)
    s = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    return float(s[mask].mean()) if np.any(mask) else 0.0


def specks(img, thr=0.25):
    """Part des pixels opaques qui sont des PICS ISOLÉS : luminance supérieure de plus de `thr` à la moyenne
    de leurs 8 voisins (tous opaques) et au moins égale à leur maximum - 0,02 (vérification V0b, b11 : cheminée
    V0b 1,17 %, four en acier 0,66 %, assembleur 0,46 %). Ils font scintiller le zoom 1 et dominent le grain."""
    a = img[..., 3]
    L = lum(img[..., :3])
    op = a >= 0.99
    H, W = L.shape
    P = np.pad(L, 1, mode="edge")
    Pa = np.pad(op, 1)
    neigh = [P[1 + dy:1 + dy + H, 1 + dx:1 + dx + W] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dy, dx) != (0, 0)]
    allop = np.all([Pa[1 + dy:1 + dy + H, 1 + dx:1 + dx + W] for dy in (-1, 0, 1) for dx in (-1, 0, 1)], 0)
    sp = allop & (L - np.mean(neigh, 0) > thr) & (L > np.max(neigh, 0) - 0.02)
    return float(sp.sum()) / max(1, int(op.sum()))


def bible_median(img, glow=None):
    """Médiane de luminance (/255) des pixels d'alpha ≥ 0,5 hors empreinte émissive (méthode de la bible)."""
    bb = img[..., 3] >= 0.5
    if glow is not None:
        bb &= ~emissive_mask(glow)
    return float(np.percentile(lum(img[..., :3])[bb] * 255, 50)) if bb.any() else float("nan")


def bible_rules(ph, epochs, medians, tol):
    """Règles 1 à 3 de la bible (§1.5) sur une photométrie `ph` (photometry). `epochs` : époques déclarées par
    la pièce ; `medians` : cible de médiane par époque. Renvoie la liste des infractions (texte)."""
    out = []
    p05, p50, p95 = ph["bible_p05_p50_p95"]
    for e in epochs:
        t = medians[int(e)]
        if abs(p50 - t) > tol:
            out.append("bible règle 1 : médiane du corps %.0f/255 hors de la cible de l'époque %d (%d ± %.0f)" % (
                p50, e, t, tol))
    if not 40 <= p50 <= 110:
        out.append("bible règle 1 : médiane du corps %.0f/255 hors de 40..110" % p50)
    if p95 > 240:
        out.append("bible règle 2 : p95 %.0f/255 > 240 (aucun blanc pur)" % p95)
    if ph.get("sat", 0.0) > 0.45:
        out.append("bible règle 3 : saturation moyenne %.2f > 0,45" % ph["sat"])
    return out


def emissive_mask(glow, thr=0.02, grow=2):
    """Empreinte de la lueur (alpha > thr), dilatée de `grow` px : zone exclue de la photométrie du corps."""
    return dilate(np.asarray(glow)[..., 3] > thr, grow)


def photometry(main, glow=None, opaque=0.99):
    """Photométrie du CORPS (pixels d'alpha ≥ opaque hors empreinte émissive), valeurs sRGB codées 0..1.
    Méthode des vérifications V0 (rapport 3) : écart-type, centiles, part claire, grain et gradient."""
    a = main[..., 3]
    body = a >= opaque
    if glow is not None:
        body &= ~emissive_mask(glow)
    L = lum(main[..., :3])
    v = L[body]
    if v.size == 0:
        return {"n": 0}
    # grain : écart-type du passe-haut 3×3 ; gradient : moyenne de |∇L| (différences centrées) ; laplacien RMS
    pad = np.pad(L, 1, mode="edge")
    box = sum(pad[1 + dy:1 + dy + L.shape[0], 1 + dx:1 + dx + L.shape[1]] for dy in (-1, 0, 1) for dx in (-1, 0, 1)) / 9.0
    hp = L - box
    gy = (pad[2:, 1:-1] - pad[:-2, 1:-1]) / 2.0
    gx = (pad[1:-1, 2:] - pad[1:-1, :-2]) / 2.0
    grad = np.hypot(gx, gy)
    lap = pad[2:, 1:-1] + pad[:-2, 1:-1] + pad[1:-1, 2:] + pad[1:-1, :-2] - 4 * L
    inner = body & ~dilate(~body, 1)  # gradient et laplacien sans les bords de la silhouette
    r = {
        "n": int(v.size),
        "mean": float(v.mean()), "std": float(v.std()),
        "p05": float(np.percentile(v, 5)), "p50": float(np.percentile(v, 50)), "p95": float(np.percentile(v, 95)),
        "frac_gt_0_5": float((v > 0.5).mean()),
        "grain": float(hp[body].std()),
        "grad": float(grad[inner].mean()) if inner.any() else 0.0,
        "lap_rms": float(np.sqrt((lap[inner] ** 2).mean())) if inner.any() else 0.0,
    }
    r["lap_over_std"] = r["lap_rms"] / r["std"] if r["std"] > 0 else 0.0
    # méthode de la bible (DESIGN_EPOQUES §1.5) : alpha ≥ 0,5, sur 255
    bb = a >= 0.5
    if glow is not None:
        bb &= ~emissive_mask(glow)
    vb = L[bb] * 255
    r["bible_p05_p50_p95"] = [float(np.percentile(vb, q)) for q in (5, 50, 95)]
    r["sat"] = saturation(main[..., :3], bb)
    r["specks"] = specks(main)
    return r


# ------------------------------------------------------------------------------------------------
# Halo (draw_as_light)
# ------------------------------------------------------------------------------------------------
def light_on(light, alpha):
    """Part de l'énergie du halo posée sur une silhouette (alpha d'un sprite, même grille) et maximum."""
    e = light[..., 3]
    tot = float(e.sum())
    on = e * np.clip(alpha, 0, 1)
    return (float(on.sum()) / tot if tot > 0 else 0.0), float(on.max()) if on.size else 0.0


def light_pockets(light, blocked, low=0.05, high=0.15):
    """Poches sombres ENFERMÉES dans le halo, sur le sol visible : composantes de {halo < low·pic} qui ne
    touchent ni le bord de l'image ni une silhouette (`blocked` : pièce, bâtiment porteur) et qui sont
    entourées de halo > high·pic. Une telle poche est l'ombre d'un objet absent de l'image (« ombre
    fantôme »). Renvoie le nombre de pixels concernés."""
    e = light[..., 3]
    peak = float(e.max())
    if peak <= 0:
        return 0
    blocked = np.asarray(blocked, bool)
    dark = (e < low * peak) & ~blocked
    # tout ce qui est sombre et relié au bord ou à une silhouette n'est pas une poche
    free = dark | blocked
    outside = reach_from_border(free)
    pockets = dark & ~outside
    if not pockets.any():
        return 0
    ring = dilate(pockets, 2) & ~pockets
    return int(pockets.sum()) if (e[ring] > high * peak).mean() > 0.5 else 0


def light_extent(light, thr_frac=0.1 / 0.89, px_per_tile=64.0, center=None):
    """Surface du halo (tuiles²) au-dessus d'un seuil d'alpha, intégrale (tuiles²·alpha), pic, et portée
    nord/sud/est/ouest depuis `center` (px). Seuil par défaut : λ = 0,1 avec λ ≈ 0,89 × alpha (pente
    mesurée en moteur, rapport V0)."""
    e = light[..., 3]
    area = float((e >= thr_frac).sum()) / px_per_tile ** 2
    integ = float(e.sum()) / px_per_tile ** 2
    out = {"area_tiles2": area, "integral": integ, "peak": float(e.max())}
    if center is not None:
        cx, cy = int(round(center[0])), int(round(center[1]))
        H, W = e.shape
        def run(dx, dy):
            x, y, k, last = cx, cy, 0, 0
            while 0 <= x < W and 0 <= y < H and k < 4 * px_per_tile:
                if e[y, x] >= thr_frac:
                    last = k
                x += dx
                y += dy
                k += 1
            return last / px_per_tile
        out.update(north=run(0, -1), south=run(0, 1), east=run(1, 0), west=run(-1, 0))
    return out
