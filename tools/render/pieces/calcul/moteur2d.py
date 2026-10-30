"""Petit moteur 2,5 D des icônes de la chaîne du calcul (lot CALC-ICONES-A, 30/10).

Même principe que les icônes des modules validées par le DC (tools/render/pieces/modules/icones.py) : formes en champs de
distance signée à 512 px (unités de 0 à 64, y vers le bas), relief -> normales -> lumière du NORD-OUEST, réduction en
lumière LINÉAIRE à 64, 32, 16 et 8 px (icon_size 64, icon_mipmaps 4, bande 120 x 64 comme le vanilla). Ajout propre à ce
lot : la vue 3/4 des icônes vanilla (icons/electronic-circuit.png, copper-plate.png : l'épaisseur se voit SOUS l'objet)
par EXTRUSION d'une forme plate (`dalle`) : le dessus d'une dalle de hauteur z est décalé de z x DECAL (vers le haut et un
peu vers la gauche), d'où des faces avant (sud) et droite (est) visibles, ombrées selon la normale du contour.
Aucun hasard non fixé : deux passages donnent les mêmes octets (bruit = RandomState à graine fixe).
"""
import io

import numpy as np
from PIL import Image
from scipy import ndimage

N = 512
U = N / 64.0
_c = (np.arange(N) + 0.5) / U
X, Y = np.meshgrid(_c, _c)
DECAL = (-0.30, -1.0)          # déplacement à l'écran d'une unité de hauteur (vers le haut, un peu à gauche)
LUM = np.array([-0.55, -0.75, 0.95])
LUM = LUM / np.linalg.norm(LUM)
DEMI = LUM + np.array([0.0, 0.0, 1.0])
DEMI = DEMI / np.linalg.norm(DEMI)
L2 = np.array([-0.6, -0.8])    # direction de la lumière dans le plan (vers le nord-ouest)


# ------------------------------------------------------------------------------------------------------------------
# Champs de distance (fonctions de (x, y) -> distance en unités, négative dedans)
# ------------------------------------------------------------------------------------------------------------------
def sd_boite(x, y, x0, y0, x1, y1, r=0.0):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = np.abs(x - cx) - hx, np.abs(y - cy) - hy
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def sd_cercle(x, y, cx, cy, r):
    return np.hypot(x - cx, y - cy) - r


def sd_ellipse(x, y, cx, cy, rx, ry):
    # approximation suffisante pour l'anticrénelage (rapport d'axes modéré)
    k = np.hypot((x - cx) / rx, (y - cy) / ry)
    return (k - 1.0) * min(rx, ry)


def sd_segment(x, y, ax, ay, bx, by, r):
    ex, ey = bx - ax, by - ay
    wx, wy = x - ax, y - ay
    t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0.0, 1.0)
    return np.hypot(wx - ex * t, wy - ey * t) - r


def sd_poly(x, y, pts):
    p = np.asarray(pts, float)
    d = (x - p[0, 0]) ** 2 + (y - p[0, 1]) ** 2
    s = np.ones_like(x)
    for i in range(len(p)):
        j = i - 1
        ex, ey = p[j, 0] - p[i, 0], p[j, 1] - p[i, 1]
        wx, wy = x - p[i, 0], y - p[i, 1]
        t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0.0, 1.0)
        bx, by = wx - ex * t, wy - ey * t
        d = np.minimum(d, bx * bx + by * by)
        c1 = y >= p[i, 1]
        c2 = y < p[j, 1]
        c3 = ex * wy > ey * wx
        m = (c1 & c2 & c3) | (~c1 & ~c2 & ~c3)
        s = np.where(m, -s, s)
    return s * np.sqrt(d)


def couv(sd):
    return np.clip(0.5 - sd * U, 0.0, 1.0)


def profil(sd, largeur):
    t = np.clip(-sd / largeur, 0.0, 1.0)
    return np.sqrt(1.0 - (1.0 - t) ** 2)


def bruit(graine, maille=8, lisse=1):
    """Bruit de valeur déterministe, 0 à 1, maille en unités (sur la grille de travail)."""
    n = max(2, int(round(64 / maille)) + 1)
    g = np.random.RandomState(graine).rand(n, n)
    z = ndimage.zoom(g, (N + 2 * U) / n, order=lisse)[: N, : N]
    z = (z - z.min()) / max(z.max() - z.min(), 1e-9)
    return z


def melange(dst, src, a):
    src = np.asarray(src, float)
    if src.ndim == 1:
        src = src[None, None, :]
    return dst * (1.0 - a[..., None]) + src * a[..., None]


# ------------------------------------------------------------------------------------------------------------------
# Surface : albédo, rugosité, métallicité, relief, émission
# ------------------------------------------------------------------------------------------------------------------
class Surface:
    def __init__(self, mat):
        self.alb = np.zeros((N, N, 3)) + np.asarray(mat["rgb"], float)[None, None, :]
        self.rough = np.full((N, N), float(mat["rough"]))
        self.met = np.full((N, N), float(mat["met"]))
        self.H = np.zeros((N, N))
        self.emis = np.zeros((N, N, 3))
        self.tref = None    # teinte du reflet d'un diélectrique (None : blanc)

    def poser(self, a, mat, dh=0.0, prof=None):
        """Pose la matière `mat` là où a > 0 ; relève le relief de dh (x prof si donné)."""
        self.alb = melange(self.alb, mat["rgb"], a)
        self.rough = self.rough * (1 - a) + mat["rough"] * a
        self.met = self.met * (1 - a) + mat["met"] * a
        if dh:
            self.H += dh * a * (prof if prof is not None else 1.0)

    def lueur(self, a, rgb, k=1.0):
        self.emis += np.asarray(rgb, float)[None, None, :] * (a * k)[..., None]


def eclairer(s, pente=1.6, reflet=1.0, ao=True):
    """Lumière du nord-ouest sur le relief H ; reflet d'environnement (faux, déterministe) pour les surfaces lisses."""
    gy, gx = np.gradient(s.H, 1.0 / U)
    nx, ny, nz = -gx * pente, -gy * pente, np.ones_like(s.H)
    nn = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / nn, ny / nn, nz / nn
    diff = np.clip(nx * LUM[0] + ny * LUM[1] + nz * LUM[2], 0.0, 1.0)
    lum = 0.26 + 0.74 * diff / LUM[2]
    nh = np.clip(nx * DEMI[0] + ny * DEMI[1] + nz * DEMI[2], 0.0, 1.0)
    p = 8.0 + (1.0 - s.rough) ** 2 * 120.0
    ks = 0.05 + 0.6 * (1.0 - s.rough) ** 2
    spec = ks * nh ** p
    # reflet d'environnement : direction réfléchie + fausse perspective (une plaque plate n'est pas uniforme)
    rx = 2 * nz * nx + (X - 32.0) / 64.0 * 1.1
    ry = 2 * nz * ny + (Y - 32.0) / 64.0 * 1.1
    ciel = np.clip(0.5 - 0.62 * (rx + ry), 0.0, 1.0) ** 1.6
    bande = np.exp(-(((rx + ry) + 0.18) / 0.13) ** 2)
    env = 0.05 + 0.45 * ciel + 0.95 * bande
    lisse = (1.0 - s.rough) ** 2 * reflet
    if ao:
        creux = np.clip(ndimage.gaussian_filter(s.H, 1.0 * U) - s.H, 0.0, 3.0)
        occl = 1.0 - 0.25 * creux
    else:
        occl = 1.0
    met = s.met[..., None]
    base = s.alb * (lum * occl)[..., None] * (1.0 - 0.55 * met)
    refl_met = s.alb * (env * lisse * 1.5 * occl)[..., None] * met
    tref = np.ones(3) if s.tref is None else np.asarray(s.tref, float)
    refl_die = (env * lisse * 0.30 * occl)[..., None] * (1.0 - met) * tref[None, None, :]
    spec_c = spec[..., None] * ((1.0 - met) + met * s.alb * 2.4)
    return base + refl_met + refl_die + spec_c + s.emis


# ------------------------------------------------------------------------------------------------------------------
# Toile (alpha prémultiplié, lumière linéaire)
# ------------------------------------------------------------------------------------------------------------------
class Toile:
    def __init__(self):
        self.P = np.zeros((N, N, 3))
        self.A = np.zeros((N, N))

    def poser(self, rgb, cov):
        self.P = self.P * (1.0 - cov[..., None]) + rgb * cov[..., None]
        self.A = self.A * (1.0 - cov) + cov

    def dalle(self, f, z0, ep, cote, dessus, pas=0.2, cote_fn=None, sombre_bas=0.30):
        """Forme plate `f(x, y)` extrudée de z0 à z0 + ep. `cote` : matière des flancs ; `dessus(xl, yl, sd)` -> Surface.
        Rend la couverture du dessus (pour les détails posés ensuite)."""
        if ep > 0:
            ss = np.arange(z0, z0 + ep, pas)
            haut = np.full((N, N), np.nan)
            nxs = np.zeros((N, N))
            nys = np.zeros((N, N))
            cv = np.zeros((N, N))
            for s in ss:
                dx, dy = DECAL[0] * s, DECAL[1] * s
                sd = f(X - dx, Y - dy)
                c = couv(sd)
                m = c > 0.0
                if not m.any():
                    continue
                gy, gx = np.gradient(sd)
                gn = np.maximum(np.hypot(gx, gy), 1e-9)
                haut[m] = (s - z0) / ep
                nxs[m] = (gx / gn)[m]
                nys[m] = (gy / gn)[m]
                cv = np.maximum(cv, c)
            ok = ~np.isnan(haut)
            hh = np.where(ok, haut, 0.0)
            d2 = nxs * L2[0] + nys * L2[1]
            shade = (0.50 + 0.30 * d2) * (1.0 - sombre_bas + sombre_bas * hh)
            if cote_fn is not None:
                rgb = cote_fn(hh, nxs, nys) * shade[..., None]
            else:
                rgb = np.asarray(cote["rgb"], float)[None, None, :] * shade[..., None]
                # liseré clair au sommet du flanc (arête vive vue de face)
                rgb = rgb + np.asarray(cote["rgb"], float)[None, None, :] * (np.clip((hh - 0.82) / 0.18, 0, 1) * 0.5)[..., None]
                # reflet métallique sur le flanc tourné vers le sud-ouest
                rgb = rgb + (cote["met"] * 0.25 * np.clip(-nxs * 0.7 + nys * 0.7, 0, 1) ** 4)[..., None] * np.asarray(cote["rgb"])[None, None, :]
            self.poser(rgb, cv)
        dx, dy = DECAL[0] * (z0 + ep), DECAL[1] * (z0 + ep)
        xl, yl = X - dx, Y - dy
        sd = f(xl, yl)
        surf = dessus(xl, yl, sd)
        rgb = eclairer(surf)
        c = couv(sd)
        self.poser(rgb, c)
        return c, xl, yl

    def relief(self, sd, surf, **kw):
        c = couv(sd)
        self.poser(eclairer(surf, **kw), c)
        return c

    def lueur_libre(self, rgb, a):
        """Lumière additive hors de toute matière (faisceau, halo) : ajoute de la couverture."""
        self.P = self.P + np.asarray(rgb, float)[None, None, :] * a[..., None]
        self.A = np.clip(self.A + a * 0.85, 0.0, 1.0)

    def contour(self, couleur=(0.004, 0.004, 0.006), largeur=0.75, force=0.85):
        """Liseré sombre sous la silhouette (lisibilité sur fond clair), comme les icônes des modules."""
        dist = ndimage.distance_transform_edt(self.A < 0.5) / U
        ring = np.clip((largeur - dist) * U / 2.0 + 0.5, 0.0, 1.0) * force
        ring = ring * (1.0 - self.A)
        self.P = self.P + np.asarray(couleur)[None, None, :] * ring[..., None]
        self.A = self.A + ring


# ------------------------------------------------------------------------------------------------------------------
# Boîtes en vraie vue 3/4 (radiateur) : sol raccourci, profondeur qui fuit en haut à droite, faces dessus / avant / est
# ------------------------------------------------------------------------------------------------------------------
class Vue34:
    def __init__(self, ox, oy, kx=0.42, ky=0.52, kz=0.86):
        self.ox, self.oy, self.kx, self.ky, self.kz = ox, oy, kx, ky, kz

    def p(self, x, y, z):
        return (self.ox + x + self.kx * y, self.oy - self.ky * y - self.kz * z)


def face(toile, pts, rgb, ombre=1.0, texture=None, arete=None):
    """Face plane (polygone projeté), teinte unie x ombre (+ texture multiplicative), arête claire facultative."""
    sd = sd_poly(X, Y, pts)
    c = couv(sd)
    col = np.zeros((N, N, 3)) + np.asarray(rgb, float)[None, None, :] * ombre
    if texture is not None:
        col = col * texture[..., None]
    if arete is not None:
        (ax, ay), (bx, by), k = arete
        d = sd_segment(X, Y, ax, ay, bx, by, 0.0)
        col = col + np.asarray(rgb, float)[None, None, :] * (np.exp(-(d / 0.55) ** 2) * k)[..., None]
    toile.poser(col, c)
    return c


def boite3d(toile, v, x0, x1, y0, y1, z0, z1, rgb, haut=1.0, avant=0.62, est=0.38, tex=None):
    P = v.p
    # dessus
    face(toile, [P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1)], rgb, haut,
         texture=None if tex is None else tex.get("haut"), arete=(P(x0, y0, z1), P(x1, y0, z1), 0.55))
    # face est (x = x1)
    face(toile, [P(x1, y0, z0), P(x1, y1, z0), P(x1, y1, z1), P(x1, y0, z1)], rgb, est,
         texture=None if tex is None else tex.get("est"))
    # face avant (y = y0)
    face(toile, [P(x0, y0, z0), P(x1, y0, z0), P(x1, y0, z1), P(x0, y0, z1)], rgb, avant,
         texture=None if tex is None else tex.get("avant"), arete=(P(x0, y0, z1), P(x0, y0, z0), 0.35))


# ------------------------------------------------------------------------------------------------------------------
# Sorties (mêmes conversions que modules/icones.py)
# ------------------------------------------------------------------------------------------------------------------
def lin_vers_srgb(c, epaule=True):
    c = np.clip(c, 0.0, None)
    if epaule:
        c = np.where(c > 0.85, 0.85 + 0.15 * (1.0 - np.exp(-(c - 0.85) / 0.15)), c)
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, 12.92 * c, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def srgb_vers_lin(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def en_image(rgb_pm, a, epaule=True):
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(a[..., None] > 1e-4, rgb_pm / np.maximum(a[..., None], 1e-4), 0.0)
    s = lin_vers_srgb(c, epaule)
    out = np.zeros(a.shape + (4,), np.uint8)
    out[..., :3] = np.round(s * 255).astype(np.uint8)
    out[..., 3] = np.round(np.clip(a, 0, 1) * 255).astype(np.uint8)
    out[a <= 1e-4, :3] = 0
    return Image.fromarray(out, "RGBA")


def reduire(P, A, taille):
    f = N // taille
    r = P.reshape(taille, f, taille, f, 3).mean(axis=(1, 3))
    a = A.reshape(taille, f, taille, f).mean(axis=(1, 3))
    return r, a


def bande_icone(toile, nettete32=0.0):
    """Bande 120 x 64 : 64, 32, 16, 8 px réduits en lumière linéaire depuis la toile de 512 px."""
    bande = Image.new("RGBA", (120, 64), (0, 0, 0, 0))
    x = 0
    for taille in (64, 32, 16, 8):
        r, a = reduire(toile.P, toile.A, taille)
        if taille == 32 and nettete32 > 0:
            # accentuation douce à 32 px (taille de l'inventaire) : masque flou, sur le prémultiplié
            flou_r = ndimage.gaussian_filter(r, (0.8, 0.8, 0))
            flou_a = ndimage.gaussian_filter(a, 0.8)
            r = np.clip(r + nettete32 * (r - flou_r), 0, None)
            a = np.clip(a + nettete32 * 0.5 * (a - flou_a), 0, 1)
            r = np.minimum(r, a[..., None] * 4.0)
        bande.paste(en_image(r, a), (x, 0))
        x += taille
    return bande


def png_octets(im):
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return b.getvalue()
