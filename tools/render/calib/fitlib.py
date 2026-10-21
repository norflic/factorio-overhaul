"""Outils de mesure communs à l'étalonnage (lot V0, H-V1).

Python pur + numpy + Pillow. Aucune écriture hors des chemins passés en argument.
"""
import os
import numpy as np
from PIL import Image

LUMA = np.array([0.2126, 0.7152, 0.0722])


def load(path):
    """Image RGBA en flottants [0, 1], forme (H, W, 4)."""
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0


def luminance(rgb):
    return rgb[..., :3] @ LUMA


def mid_boundary(mask):
    """Points de bord à mi-chemin entre pixels du masque et pixels hors masque (voisinage 4).

    Évite le biais d'un demi-pixel d'un bord pris aux centres des pixels intérieurs ou extérieurs.
    Coordonnées en pixels, origine au coin haut-gauche de l'image (centre du pixel i = i + 0,5).
    """
    pts = []
    m = mask
    h, w = m.shape
    # bords horizontaux (entre colonnes)
    diff = m[:, 1:] != m[:, :-1]
    ys, xs = np.nonzero(diff)
    pts.append(np.c_[xs + 1.0, ys + 0.5])
    diff = m[1:, :] != m[:-1, :]
    ys, xs = np.nonzero(diff)
    pts.append(np.c_[xs + 0.5, ys + 1.0])
    return np.vstack(pts)


def fit_ellipse_axis(pts):
    """Ellipse à axes alignés : A x² + C y² + D x + E y = 1 (moindres carrés).

    Renvoie (xc, yc, a, b, rms_px) avec a le demi-axe horizontal, b le demi-axe vertical.
    """
    x, y = pts[:, 0], pts[:, 1]
    M = np.c_[x * x, y * y, x, y]
    A, C, D, E = np.linalg.lstsq(M, np.ones(len(x)), rcond=None)[0]
    xc, yc = -D / (2 * A), -E / (2 * C)
    k = 1 + A * xc * xc + C * yc * yc
    a, b = np.sqrt(k / A), np.sqrt(k / C)
    # résidu géométrique approché
    r = np.sqrt(((x - xc) / a) ** 2 + ((y - yc) / b) ** 2)
    rms = np.sqrt(np.mean(((r - 1) * np.sqrt(a * b)) ** 2))
    return xc, yc, a, b, rms


def fit_arc(pts, side):
    """Demi-ellipse (arc du haut ou du bas) : y = yc ∓ b·sqrt(1 - ((x-xc)/a)²).

    Recherche en grille sur (xc, a), moindres carrés linéaires sur (yc, b). Renvoie
    (xc, yc, a, b, rms).
    """
    x, y = pts[:, 0], pts[:, 1]
    best = None
    x0, x1 = x.min(), x.max()
    for xc in np.arange(x0 + (x1 - x0) * 0.35, x0 + (x1 - x0) * 0.65, 0.25):
        for a in np.arange((x1 - x0) * 0.45, (x1 - x0) * 0.65, 0.1):
            u = (x - xc) / a
            m = np.abs(u) < 0.97
            if m.sum() < 8:
                continue
            s = np.sqrt(1 - u[m] ** 2)
            sign = 1.0 if side == "bottom" else -1.0
            M = np.c_[np.ones(m.sum()), sign * s]
            sol = np.linalg.lstsq(M, y[m], rcond=None)[0]
            rms = np.sqrt(np.mean((M @ sol - y[m]) ** 2))
            # pénalise les points hors de l'arc (|u| >= 1) qui seraient ignorés à tort
            out = (~m).sum() / len(x)
            score = rms + 2.0 * out
            if best is None or score < best[0]:
                best = (score, xc, sol[0], a, sol[1], rms)
    _, xc, yc, a, b, rms = best
    return xc, yc, a, b, rms


def column_edge(alpha, x, side, level):
    """Ordonnée sous-pixel où l'alpha de la colonne x franchit `level` (premier par le haut ou le bas)."""
    c = alpha[:, x]
    idx = np.nonzero(c >= level)[0]
    if len(idx) == 0:
        return None
    if side == "top":
        i = idx[0]
        if i == 0:
            return 0.0
        return i - (c[i] - level) / max(c[i] - c[i - 1], 1e-9) + 0.5
    i = idx[-1]
    if i == len(c) - 1:
        return float(len(c))
    return i + (c[i] - level) / max(c[i] - c[i + 1], 1e-9) + 0.5


def stats_opaque(img, alpha_min=0.99):
    """Statistiques photométriques des pixels opaques : luminance (moyenne, écart-type, centiles),
    saturation HSV moyenne, teinte moyenne, grain (écart-type du passe-haut 3×3)."""
    a = img[..., 3]
    m = a >= alpha_min
    rgb = img[..., :3]
    L = luminance(rgb)
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    # grain : luminance moins sa moyenne 3×3, sur les pixels dont tout le voisinage est opaque
    pad = np.pad(L, 1, mode="edge")
    blur = sum(pad[dy:dy + L.shape[0], dx:dx + L.shape[1]] for dy in range(3) for dx in range(3)) / 9
    mpad = np.pad(m, 1, constant_values=False)
    inner = m.copy()
    for dy in range(3):
        for dx in range(3):
            inner &= mpad[dy:dy + m.shape[0], dx:dx + m.shape[1]]
    hp = (L - blur)[inner]
    Lm = L[m]
    mean_rgb = rgb[m].mean(0)
    return {
        "n": int(m.sum()),
        "L_mean": float(Lm.mean()),
        "L_std": float(Lm.std()),
        "L_p05": float(np.percentile(Lm, 5)),
        "L_p50": float(np.percentile(Lm, 50)),
        "L_p95": float(np.percentile(Lm, 95)),
        "sat_mean": float(sat[m].mean()),
        "rgb_mean": [float(v) for v in mean_rgb],
        "grain": float(hp.std()) if hp.size else 0.0,
    }


def save_png(arr01, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    a = np.clip(np.round(arr01 * 255), 0, 255).astype(np.uint8)
    Image.fromarray(a, "RGBA" if a.shape[-1] == 4 else "RGB").save(path, optimize=True)
