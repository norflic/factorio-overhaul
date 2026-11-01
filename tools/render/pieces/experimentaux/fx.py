"""BRIQUES D'EFFETS des expérimentaux (lot RB-V0, 31/10), en 2D sur la scène : chacune correspond à une feuille ou à un appel
du moteur (FAISABILITE.md) : fissures (décalques au sol), panaches (animation additive), onde (explosion à échelle croissante),
arcs (beam), vraies explosions vanilla. Déterministe : graines fixes, aucun hasard global. Python 3.9, numpy, scipy, PIL.
"""
import math

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ND

import scene as SC

ENT = SC.ENT


def flou(a, sigma):
    """Flou gaussien (sigma en px) ; passe par une réduction pour les grands rayons."""
    if sigma < 6:
        return ND.gaussian_filter(a, sigma, truncate=2.5)
    k = int(sigma / 3)
    h, w = a.shape[:2]
    pet = np.asarray(Image.fromarray(a.astype(np.float32), "F").resize((max(2, w // k), max(2, h // k)), Image.BOX), np.float32)
    pet = ND.gaussian_filter(pet, sigma / k, truncate=2.5)
    return np.asarray(Image.fromarray(pet, "F").resize((w, h), Image.BICUBIC), np.float32)


def add(img, rgb, a):
    """Additif sRGB (couche draw_as_glow / blend additive du moteur)."""
    img += np.asarray(rgb, np.float32) * a[..., None]


def over(img, rgb, a):
    a = np.clip(a, 0, 1)[..., None]
    img[:] = np.asarray(rgb, np.float32) * a + img * (1 - a)


def rampe(t, stops):
    """Palette : t 0..1 (tableau) vers RGB par arrêts [(t, (r, g, b))]."""
    xs = [s[0] for s in stops]
    out = [np.interp(t, xs, [s[1][i] for s in stops]) for i in range(3)]
    return np.stack(out, -1).astype(np.float32)


# ---------------------------------------------------------------------------------------------- fissures
class Reseau:
    """Réseau de fissures au sol : segments (x0, y0, x1, y1, largeur, arrivée), en tuiles. rasterise() : carte d'arrivée (en tuiles
    de progression du front) et largeur relative."""

    def __init__(self, seed):
        self.r = np.random.RandomState(seed)
        self.seg = []

    def trace(self, p, d, L, s0, w0, wob=0.6, pas=1.2, branches=0.0, prof=0, va=1.0):
        """Fissure depuis p dans la direction d (radians), longueur L, arrivée s0 au départ, largeur w0 qui s'amincit."""
        x, y = p
        n = max(2, int(L / pas))
        a = d
        for i in range(n):
            a += self.r.uniform(-wob, wob) * 0.5 + (d - a) * 0.25
            nx, ny = x + math.cos(a) * pas, y + math.sin(a) * pas
            t = i / float(n)
            w = w0 * (1 - t) ** 0.7 + 0.1
            self.seg.append((x, y, nx, ny, w, s0 + (i * pas) / va))
            if prof < 3 and self.r.rand() < branches:
                sg = 1 if self.r.rand() < 0.5 else -1
                self.trace((nx, ny), a + sg * self.r.uniform(0.45, 1.2), L * (1 - t) * self.r.uniform(0.25, 0.6), s0 + (i * pas) / va, w * 0.62, wob, pas, branches * 0.7, prof + 1, va)
            x, y = nx, ny

    def rasterise(self, W_t, H_t, ppt):
        W, H = int(W_t * ppt), int(H_t * ppt)
        A = Image.new("F", (W, H), 1e9)
        dA = ImageDraw.Draw(A)
        order = sorted(self.seg, key=lambda s: -s[5])
        for (x0, y0, x1, y1, w, s) in order:
            px = max(1, int(round(w * ppt)))
            dA.line((x0 * ppt, y0 * ppt, x1 * ppt, y1 * ppt), fill=float(s), width=px)
            rad = px / 2.0
            dA.ellipse((x1 * ppt - rad, y1 * ppt - rad, x1 * ppt + rad, y1 * ppt + rad), fill=float(s))
        return np.asarray(A, np.float32)


def bandeau_chauffe(age, chaud=1.0, froid=25.0):
    """0..1 : 1 au passage du front, puis refroidissement (âge en tuiles de progression)."""
    return np.clip(np.exp(-np.maximum(age, 0) / froid) * chaud, 0, 1)


# ---------------------------------------------------------------------------------------------- panaches
PAL_PLASMA = [(0.0, (0.0, 0.0, 0.0)), (0.25, (0.45, 0.02, 0.32)), (0.5, (1.0, 0.12, 0.62)), (0.72, (1.0, 0.5, 0.42)), (0.9, (1.0, 0.86, 0.62)), (1.0, (1.0, 1.0, 0.95))]
PAL_FLAMME = [(0.0, (0.0, 0.0, 0.0)), (0.3, (0.32, 0.01, 0.2)), (0.6, (0.85, 0.08, 0.5)), (0.85, (1.0, 0.42, 0.34)), (1.0, (1.0, 0.72, 0.5))]
PAL_FEU = [(0.0, (0.0, 0.0, 0.0)), (0.3, (0.5, 0.08, 0.01)), (0.55, (1.0, 0.38, 0.05)), (0.8, (1.0, 0.72, 0.28)), (1.0, (1.0, 0.97, 0.8))]
PAL_OR = [(0.0, (0.0, 0.0, 0.0)), (0.3, (0.45, 0.26, 0.05)), (0.6, (1.0, 0.75, 0.3)), (0.85, (1.0, 0.93, 0.68)), (1.0, (1.0, 1.0, 0.94))]
_PAN = {}


def panache(wp, hp, seed, pal):
    """Flamme verticale additive, wp × hp px : bruit étiré vers le haut, cœur étroit qui se dissout. Rend RGB (déjà × intensité)."""
    cle = (wp, hp, seed, id(pal))
    if cle in _PAN:
        return _PAN[cle]
    n1 = SC.fbm(hp, wp, seed, cell=max(4.0, wp / 3.0), oct=5, persist=0.6)
    n2 = SC.fbm(hp, wp, seed + 9, cell=max(3.0, wp / 7.0), oct=4, persist=0.6)
    v = np.linspace(0.0, 1.0, hp, dtype=np.float32)[:, None]    # 0 en haut, 1 au pied
    u = np.linspace(-1.0, 1.0, wp, dtype=np.float32)[None, :]
    largeur = 0.16 + 0.52 * np.sin(np.clip(v, 0, 1) * 2.6) ** 0.9
    # ondulation latérale : le panache se tord en montant
    dec = (n1 - 0.5) * 0.55 * (1.1 - v)
    d = np.abs(u + dec) / largeur
    prof = np.clip(1.0 - d ** 1.7, 0, 1)
    corps = prof * (0.45 + 0.75 * n2) * np.clip(v * 1.5 + 0.15 * n1, 0, 1) ** 0.9
    corps = np.clip(corps * (0.85 + 0.65 * v), 0, 1)
    # pied et bords fondus : jamais de rectangle visible, même une fois tourné
    corps = corps * np.clip((1.0 - v) * 9.0, 0, 1) * np.clip((1.0 - np.abs(u)) * 5.0, 0, 1) * np.clip(v * 6.0, 0, 1)
    rgb = rampe(corps, pal)
    _PAN[cle] = rgb
    return rgb


def pose_add(img, spr, cx, by, k=1.0):
    """Additif du sprite (RGB), centré en x, pied en by (px)."""
    h, w = spr.shape[:2]
    x0, y0 = int(cx - w / 2), int(by - h)
    xs0, ys0 = max(0, -x0), max(0, -y0)
    xd0, yd0 = max(0, x0), max(0, y0)
    ww = min(w - xs0, img.shape[1] - xd0)
    hh = min(h - ys0, img.shape[0] - yd0)
    if ww <= 0 or hh <= 0:
        return
    img[yd0:yd0 + hh, xd0:xd0 + ww] = np.clip(img[yd0:yd0 + hh, xd0:xd0 + ww] + spr[ys0:ys0 + hh, xs0:xs0 + ww] * k, 0, 1)


def pose_over(img, rgba, cx, cy):
    h, w = rgba.shape[:2]
    x0, y0 = int(cx - w / 2), int(cy - h / 2)
    xs0, ys0 = max(0, -x0), max(0, -y0)
    xd0, yd0 = max(0, x0), max(0, y0)
    ww = min(w - xs0, img.shape[1] - xd0)
    hh = min(h - ys0, img.shape[0] - yd0)
    if ww <= 0 or hh <= 0:
        return
    a = rgba[ys0:ys0 + hh, xs0:xs0 + ww, 3:4]
    img[yd0:yd0 + hh, xd0:xd0 + ww] = rgba[ys0:ys0 + hh, xs0:xs0 + ww, :3] * a + img[yd0:yd0 + hh, xd0:xd0 + ww] * (1 - a)


_FUM = {}


def fumee(wp, hp, seed, col=(0.13, 0.11, 0.1)):
    """Colonne de fumée (alpha), wp × hp px, plus large en haut."""
    cle = (wp, hp, seed, col)
    if cle in _FUM:
        return _FUM[cle]
    n = SC.fbm(hp, wp, seed, cell=max(6.0, wp / 4.0), oct=5, persist=0.55)
    v = np.linspace(0.0, 1.0, hp, dtype=np.float32)[:, None]
    u = np.linspace(-1.0, 1.0, wp, dtype=np.float32)[None, :]
    largeur = 0.28 + 0.68 * (1 - v)
    d = np.abs(u + (n - 0.5) * 0.5) / largeur
    a = np.clip(1.15 - d ** 2, 0, 1) * np.clip((n - 0.26) * 2.4, 0, 1) * np.clip(np.minimum((1 - v) * 7, v * 3 + 0.2), 0, 1)
    c = np.asarray(col, np.float32) * (0.72 + 0.6 * n[..., None])
    out = np.dstack([c, a * 0.62]).astype(np.float32)
    _FUM[cle] = out
    return out


# ---------------------------------------------------------------------------------------------- arcs
def arc_electrique(img, p0, p1, seed, col, epais=2.0, halo=7.0, k=1.0, wob=0.12):
    """Arc entre p0 et p1 (px), brisé par déplacement du point milieu (en jeu : `beam`), avec son halo."""
    r = np.random.RandomState(seed)
    pts = [p0, p1]
    amp = math.hypot(p1[0] - p0[0], p1[1] - p0[1]) * wob
    for _ in range(6):
        out = []
        for a, b in zip(pts[:-1], pts[1:]):
            m = ((a[0] + b[0]) / 2 + r.uniform(-amp, amp), (a[1] + b[1]) / 2 + r.uniform(-amp, amp))
            out += [a, m]
        out.append(pts[-1])
        pts = out
        amp *= 0.55
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    m = int(halo * 4 + 8)
    x0, y0 = int(min(xs)) - m, int(min(ys)) - m
    x1, y1 = int(max(xs)) + m, int(max(ys)) + m
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(img.shape[1], x1), min(img.shape[0], y1)
    if x1 <= x0 or y1 <= y0:
        return
    im = Image.new("L", (x1 - x0, y1 - y0), 0)
    d = ImageDraw.Draw(im)
    d.line([(p[0] - x0, p[1] - y0) for p in pts], fill=255, width=max(1, int(round(epais))))
    a = np.asarray(im, np.float32) / 255.0
    h = ND.gaussian_filter(a, halo, truncate=2.5) * (halo * 1.8)
    sub = img[y0:y1, x0:x1]
    sub += np.asarray(col, np.float32) * (np.clip(h, 0, 1)[..., None] * 0.8 * k)
    sub += np.asarray((1.0, 0.96, 0.98), np.float32) * (a[..., None] * 0.9 * k)
    img[y0:y1, x0:x1] = np.clip(sub, 0, 1)


# ---------------------------------------------------------------------------------------------- explosions vanilla
_EXP = {}


def explosion_massive(i, ppt=32):
    """Image i (0..56) de la vraie `massive-explosion` vanilla (hr, 656×634, 6×5 par feuille), réduite à ppt ; RGBA, shift en tuiles."""
    cle = (i, ppt)
    if cle in _EXP:
        return _EXP[cle]
    f = 1 if i < 30 else 2
    j = i if i < 30 else i - 30
    im = Image.open(ENT + "massive-explosion/hr-massive-explosion-%d.png" % f).convert("RGBA").crop(((j % 6) * 656, (j // 6) * 634, (j % 6 + 1) * 656, (j // 6 + 1) * 634))
    k = 0.5 * ppt / 32.0
    im = im.resize((int(656 * k), int(634 * k)), Image.BOX)
    a = np.asarray(im, np.float32) / 255.0
    _EXP[cle] = a
    return a


def boule_nuke(i, ppt=32):
    """Image i (0..24) de la vraie `nuke-explosion` vanilla (hr, 628×720, 5×5 par feuille, échelle 1) ; RGBA."""
    cle = ("n", i, ppt)
    if cle in _EXP:
        return _EXP[cle]
    im = Image.open(ENT + "nuke-explosion/hr-nuke-explosion-1.png").convert("RGBA").crop(((i % 5) * 628, (i // 5) * 720, (i % 5 + 1) * 628, (i // 5 + 1) * 720))
    k = ppt / 32.0
    if k != 1.0:
        im = im.resize((int(628 * k), int(720 * k)), Image.BOX)
    a = np.asarray(im, np.float32) / 255.0
    _EXP[cle] = a
    return a


# ---------------------------------------------------------------------------------------------- éclats
def eclats(img, seed, n, cx, cy, rayon, ppt, tmin=1.5, tmax=6.0, haut=0.0, col=(0.11, 0.075, 0.05)):
    """Éclats de sol projetés : polygones sombres à face éclairée, répartis autour de (cx, cy) jusqu'à rayon (tuiles)."""
    r = np.random.RandomState(seed)
    H, W = img.shape[:2]
    pil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(pil)
    for i in range(n):
        th = r.uniform(0, math.tau)
        ra = r.uniform(0.2, 1.0) ** 0.6 * rayon
        h = r.uniform(0, 1) * haut
        x = (cx + math.cos(th) * ra) * ppt
        y = (cy + math.sin(th) * ra - h) * ppt
        s = r.uniform(tmin, tmax)
        ph = r.uniform(0, math.tau)
        pts = [(x + math.cos(ph + j * math.tau / 5) * s * r.uniform(0.6, 1.2), y + math.sin(ph + j * math.tau / 5) * s * r.uniform(0.5, 1.0)) for j in range(5)]
        v = r.uniform(0.75, 1.5)
        d.polygon(pts, fill=(int(255 * col[0] * v), int(255 * col[1] * v), int(255 * col[2] * v), 255))
        d.line([pts[0], pts[1]], fill=(int(255 * min(1, col[0] * 2.6 * v)), int(255 * min(1, col[1] * 2.6 * v)), int(255 * min(1, col[2] * 2.6 * v)), 255), width=1)
    a = np.asarray(pil, np.float32) / 255.0
    al = a[..., 3:4]
    img[:] = a[..., :3] * al + img * (1 - al)


def planche(images, legendes, titre, dest, cols=4, k=0.5):
    """Assemble les images (RGB float) en planche, chacune réduite de k, légendes dessous."""
    from PIL import ImageDraw as D
    ims = []
    for rgb in images:
        im = SC.to_im(rgb)
        if k != 1.0:
            im = im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS)
        ims.append(im)
    w, h = ims[0].size
    rows = int(math.ceil(len(ims) / float(cols)))
    gap, lab, hd = 6, 30, 40
    sheet = Image.new("RGB", (cols * w + (cols + 1) * gap, hd + rows * (h + lab + gap)), (22, 22, 26))
    dr = D.Draw(sheet)
    dr.text((10, 8), titre, fill=(255, 205, 120), font=SC.police(22))
    for i, im in enumerate(ims):
        x = gap + (i % cols) * (w + gap)
        y = hd + (i // cols) * (h + lab + gap)
        sheet.paste(im, (x, y))
        dr.text((x + 6, y + h + 4), legendes[i], fill=(235, 235, 235), font=SC.police(17))
    sheet.save(dest, optimize=True)
    return sheet.size
