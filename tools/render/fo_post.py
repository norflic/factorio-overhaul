"""Post-traitement des rendus Blender en sprites Factorio (Python système : numpy + Pillow).

Entrées : <prefix>-<couche>.npy (valeurs exactes des PNG 16 bits de Blender : sRGB codé, alpha droit).
Sorties : PNG 8 bits RGBA, haute résolution (64 px/tuile, scale 0,5) et normale (32 px/tuile, scale 1),
recadrés au plus juste, avec le décalage `shift` exact (multiple de 1/64 de tuile).
"""
import hashlib
import os

import numpy as np
from PIL import Image


def srgb_to_lin(c):
    c = np.asarray(c, np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(np.asarray(c, np.float64), 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def over(top, bottom):
    """Composition « par-dessus » en lumière linéaire ; entrées et sortie : sRGB codé, alpha droit."""
    ta, ba = top[..., 3:4], bottom[..., 3:4]
    tl, bl = srgb_to_lin(top[..., :3]) * ta, srgb_to_lin(bottom[..., :3]) * ba
    a = ta + ba * (1 - ta)
    pl = tl + bl * (1 - ta)
    rgb = np.where(a > 1e-8, pl / np.maximum(a, 1e-8), 0)
    return np.concatenate([lin_to_srgb(rgb), a], -1)


def contact_fringe(ao, strength, gamma, color):
    """Liseré de contact (comme les sprites vanilla) à partir de la passe AO : occlusion = 1 - AO."""
    occ = np.clip(1.0 - srgb_to_lin(ao[..., 0]), 0, 1) * (ao[..., 3] > 0.5)
    a = np.minimum(1.0, strength * occ ** gamma)
    a = np.where(a < 3.0 / 255, 0.0, a)   # bruit résiduel de l'AO : pas de voile sur tout le canevas
    out = np.zeros(ao.shape[:2] + (4,))
    out[..., :3] = color
    out[..., 3] = a
    return out


def compose_main(main, ao, C):
    if ao is None:
        return main.astype(np.float64)
    return over(main.astype(np.float64), contact_fringe(ao, C.AO_STRENGTH, C.AO_GAMMA, C.AO_COLOR))


def shadow_layer(sh):
    """Ombre : noir, alpha = part d'ombre (le moteur l'affiche à 50 %, shadow-a8.frag)."""
    out = np.zeros(sh.shape[:2] + (4,))
    out[..., 3] = np.clip(sh[..., 3], 0, 1)
    return out


def additive_layer(img, gain=1.0):
    """Couche additive (lueur, halo) : prémultiplié = couleur émise ; codé RGB = c / max, A = max."""
    c = np.clip(img[..., :3].astype(np.float64) * img[..., 3:4] * gain, 0, 1)
    m = c.max(-1, keepdims=True)
    rgb = np.where(m > 1e-6, c / np.maximum(m, 1e-6), 0)
    return np.concatenate([rgb, m], -1)


def mask_with(img, mask_alpha):
    """Cache la couche derrière un sprite opaque (alpha du masque, même grille de pixels)."""
    out = img.copy()
    out[..., 3] = out[..., 3] * (1 - np.clip(mask_alpha, 0, 1))
    return out


def trim_box(img, origin, thr=1.0 / 255, pad=0):
    """Boîte de recadrage [x0, x1) × [y0, y1) alignée sur la grille paire relative à l'origine."""
    a = img[..., 3] >= thr
    if not a.any():
        return None
    ys, xs = np.nonzero(a)
    ox, oy = origin
    x0, x1 = xs.min() - pad, xs.max() + 1 + pad
    y0, y1 = ys.min() - pad, ys.max() + 1 + pad
    # alignement pair relatif à l'origine (la version 32 px/tuile tombe alors sur la grille du jeu)
    x0 -= (x0 - ox) % 2
    y0 -= (y0 - oy) % 2
    x1 += (x1 - ox) % 2
    y1 += (y1 - oy) % 2
    H, W = a.shape
    # au bord du canevas : on resserre vers l'intérieur en gardant la parité
    if x0 < 0:
        x0 += 2 * ((-x0 + 1) // 2)
    if y0 < 0:
        y0 += 2 * ((-y0 + 1) // 2)
    while x1 > W:
        x1 -= 2
    while y1 > H:
        y1 -= 2
    return int(x0), int(y0), int(x1), int(y1)


def fade_edges(img, width=24):
    """Atténue une couche additive vers zéro sur les `width` derniers pixels du canevas (halo coupé net
    sinon). Fenêtre en cosinus surélevé."""
    H, W = img.shape[:2]
    def ramp(n):
        r = np.ones(n)
        k = min(width, n // 2)
        t = (np.arange(k) + 0.5) / k
        r[:k] = 0.5 - 0.5 * np.cos(np.pi * t)
        r[n - k:] = r[:k][::-1]
        return r
    w = ramp(H)[:, None] * ramp(W)[None, :]
    out = img.copy()
    out[..., 3] = out[..., 3] * w
    return out


def radial_window(img, center_px, r0_px, r1_px):
    """Borne un halo : plein jusqu'à r0, décroissance en smoothstep jusqu'à 0 à r1 (pixels écran)."""
    H, W = img.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W]
    r = np.hypot(xx + 0.5 - center_px[0], yy + 0.5 - center_px[1])
    t = np.clip((r - r0_px) / max(1e-6, r1_px - r0_px), 0, 1)
    w = 1 - t * t * (3 - 2 * t)
    out = img.copy()
    out[..., 3] = out[..., 3] * w
    return out


def floor_alpha(img, thr=2.0 / 255):
    out = img.copy()
    out[..., 3] = np.where(out[..., 3] < thr, 0.0, out[..., 3])
    return out


def downsample2(img):
    """Réduction 2× (moyenne 2×2 en linéaire prémultiplié)."""
    h, w = img.shape[:2]
    a = img[..., 3:4]
    pl = srgb_to_lin(img[..., :3]) * a
    pl = pl.reshape(h // 2, 2, w // 2, 2, 3).mean((1, 3))
    a2 = a.reshape(h // 2, 2, w // 2, 2, 1).mean((1, 3))
    rgb = np.where(a2 > 1e-8, pl / np.maximum(a2, 1e-8), 0)
    return np.concatenate([lin_to_srgb(rgb), a2], -1)


def downsample2_additive(img):
    """Réduction 2× d'une couche additive (moyenne de la couleur prémultipliée, en valeurs codées)."""
    h, w = img.shape[:2]
    pm = img[..., :3] * img[..., 3:4]
    pm = pm.reshape(h // 2, 2, w // 2, 2, 3).mean((1, 3))
    m = pm.max(-1, keepdims=True)
    rgb = np.where(m > 1e-6, pm / np.maximum(m, 1e-6), 0)
    return np.concatenate([rgb, m], -1)


def to_u8(img):
    return np.clip(np.round(img * 255.0), 0, 255).astype(np.uint8)


def write_png(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    u = to_u8(img)
    # pixels entièrement transparents : couleur nulle (fichiers plus petits, aucun liseré au filtrage)
    u[u[..., 3] == 0, :3] = 0
    Image.fromarray(u, "RGBA").save(path, optimize=True, compress_level=9)
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def sprite_def(box, origin, scale_px):
    """Largeur, hauteur et shift (tuiles) d'un recadrage à scale_px pixels par tuile."""
    x0, y0, x1, y1 = box
    ox, oy = origin
    w, h = x1 - x0, y1 - y0
    sx = ((x0 + x1) / 2.0 - ox) / 64.0
    sy = ((y0 + y1) / 2.0 - oy) / 64.0
    f = 64 // scale_px
    return {"width": w // f, "height": h // f, "shift": [sx, sy]}


def icon_strip(main, sizes=(64, 32, 16, 8), fill=0.92):
    """Icône 64 px avec mipmaps (bande horizontale 64+32+16+8) à partir de la couche principale."""
    a = main[..., 3] > 0.02
    ys, xs = np.nonzero(a)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    side = max(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    sq = np.zeros((side, side, 4))
    sx0, sy0 = int(round(cx - side / 2.0)), int(round(cy - side / 2.0))
    H, W = main.shape[:2]
    for yy in range(side):
        y = sy0 + yy
        if 0 <= y < H:
            xa, xb = max(0, sx0), min(W, sx0 + side)
            sq[yy, xa - sx0:xb - sx0] = main[y, xa:xb]
    pm = np.concatenate([srgb_to_lin(sq[..., :3]) * sq[..., 3:4], sq[..., 3:4]], -1)
    out = []
    for s in sizes:
        inner = max(1, int(round(s * fill)))
        chans = []
        for c in range(4):
            ch = Image.fromarray((pm[..., c] * 255).astype(np.float32), "F").resize((inner, inner), Image.LANCZOS)
            chans.append(np.clip(np.asarray(ch) / 255.0, 0, 1))
        r = np.stack(chans, -1)
        tile = np.zeros((s, s, 4))
        o = (s - inner) // 2
        tile[o:o + inner, o:o + inner] = r
        a2 = tile[..., 3:4]
        rgb = np.where(a2 > 1e-6, tile[..., :3] / np.maximum(a2, 1e-6), 0)
        out.append(np.concatenate([lin_to_srgb(rgb), a2], -1))
    strip = np.zeros((sizes[0], sum(sizes), 4))
    x = 0
    for s, im in zip(sizes, out):
        strip[:s, x:x + s] = im
        x += s
    return strip
