"""DIRECTION D « Plaquette » des modules de production (lot DESIGN-MODULES, 7/11) : PROPOSITION, rien n'est remplacé.

Demande du DC (7/11), citée : « d'ailleur, il faudrait redesigner les modules de vitesse, productivité etc car ils sont pas beau ».
Critique des directions A, B, C (icones_directions.py) : des pictogrammes plats « d'application mobile », du même pipeline que
les icônes que le DC trouve « pas beau ». Ici le module redevient un OBJET, comme en vanilla (boîtier de métal peint vu de
trois quarts, voyants en dôme, contacts dorés, paroi avant, ombre, pas de contour noir), dans la langue du mod :
  - le TYPE se lit à l'EMBLÈME en relief (émail de la couleur du type bordé de métal, dans la perspective de la face, avec sa
    paroi et son ombre) : chevrons (vitesse), engrenage (productivité, D-17), feuille (efficacité) ; la peinture du type (D-17)
    le double, mais la forme suffit (lisible en gris) ;
  - le PALIER se lit à 5 voyants en dôme (allumés : ceil(k / 2), le dernier à demi aux paliers impairs), à la MATIÈRE des
    bagues et du bord de l'emblème (bronze I à III, acier IV à VI, or VII à X), au X par des coins d'or et un halo coloré
    (jamais du blanc), et au chiffre romain au pixel (D-17 : « Garder le romain »).
Critique sévère (7/11) : 1re passe A, B, C refusées ; 2e passe D refusée (hublot « lave-linge », signe « autocollant ») ;
3e passe D « montrable » (puce sombre écartée : elle faisait écran), défauts corrigés ensuite (voyants séparés, emblème
agrandi, efficacité contrastée, tranches éclairées selon leur orientation).

Rendu : champs de distance signée évalués dans l'espace de l'OBJET (grille inverse d'une rotation de ANGLE et d'un raccourci
vertical RACC), relief éclairé du nord-ouest (même lumière que icones.py), usure aux arêtes par un bruit à graine fixe (deux
passages donnent les mêmes octets), parois extrudées, ombres portées douces. Géométrie par type mise en cache (geometrie).
"""

import math
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import icones as I  # noqa: E402

N, U = I.N, I.U
ANGLE = math.radians(7.0)    # rotation du boîtier (sens horaire à l'écran)
RACC = 0.82                  # raccourci vertical de la face du dessus (vue de biais)
EPAIS = 6.4                  # paroi avant (unités de 64 px)
CY = 28.0                    # centre de la face du dessus à l'écran
GRAINE = 20261107

PEINTURE = {  # linéaire ; teintes vanilla un peu désaturées (vanilla : bleu 60,110,170 ; orange 200,110,40 ; vert 80,140,70)
    "speed": (0.055, 0.160, 0.420),
    "productivity": (0.500, 0.115, 0.030),
    "effectivity": (0.045, 0.165, 0.040),   # plus sombre : la feuille claire doit trancher (3e critique)
}
GARNITURE = {
    1: dict(rgb=(0.40, 0.21, 0.085), rough=0.40, met=0.90),   # bronze
    2: dict(rgb=(0.50, 0.52, 0.56), rough=0.28, met=0.90),    # acier
    3: dict(rgb=(0.86, 0.57, 0.16), rough=0.22, met=0.95),    # or
    4: dict(rgb=(0.92, 0.66, 0.24), rough=0.16, met=0.95),    # or poli
}
METAL_NU = dict(rgb=(0.40, 0.40, 0.42), rough=0.30, met=0.85)


def marche(k):
    """Marche de matière du palier k : 1 (I à III), 2 (IV à VI), 3 (VII à IX), 4 (X)."""
    return 1 if k <= 3 else 2 if k <= 6 else 3 if k <= 9 else 4


def leds(k):
    return (k + 1) // 2


def eclat(k):
    return (k - 1) / 9.0


# ------------------------------------------------------------------------------------------------------------------
# Champs de distance signée sur une grille donnée (espace de l'objet)
# ------------------------------------------------------------------------------------------------------------------
def grille(dy=0.0):
    """Coordonnées OBJET de chaque pixel de sortie, la sortie décalée de dy vers le HAUT (dy > 0 : paroi sous la face)."""
    qx, qy = I.X - 32.0, I.Y - dy - CY
    c, s = math.cos(-ANGLE), math.sin(-ANGLE)
    px = c * qx - s * qy
    py = (s * qx + c * qy) / RACC
    return px + 32.0, py + 32.0


def s_boite(X, Y, x0, y0, x1, y1, r=0.0):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = np.abs(X - cx) - hx, np.abs(Y - cy) - hy
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def s_chanfrein(X, Y, x0, y0, x1, y1, c, r=1.2):
    """Boîte à coins chanfreinés (octogone), arrondie de r."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = np.abs(X - cx), np.abs(Y - cy)
    boite = s_boite(X, Y, x0 + r, y0 + r, x1 - r, y1 - r)
    biais = (qx + qy - (hx + hy - c)) / math.sqrt(2.0)
    return np.maximum(boite, biais) - r


def s_cercle(X, Y, cx, cy, r):
    return np.hypot(X - cx, Y - cy) - r


def s_segment(X, Y, ax, ay, bx, by, r):
    ex, ey = bx - ax, by - ay
    wx, wy = X - ax, Y - ay
    t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0.0, 1.0)
    return np.hypot(wx - ex * t, wy - ey * t) - r


def s_polyligne(X, Y, pts, r):
    d = None
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        s = s_segment(X, Y, ax, ay, bx, by, r)
        d = s if d is None else np.minimum(d, s)
    return d


def s_poly(X, Y, pts):
    p = np.asarray(pts, float)
    d = (X - p[0, 0]) ** 2 + (Y - p[0, 1]) ** 2
    s = np.ones_like(X)
    for i in range(len(p)):
        j = i - 1
        ex, ey = p[j, 0] - p[i, 0], p[j, 1] - p[i, 1]
        wx, wy = X - p[i, 0], Y - p[i, 1]
        t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0.0, 1.0)
        bx, by = wx - ex * t, wy - ey * t
        d = np.minimum(d, bx * bx + by * by)
        c1, c2, c3 = Y >= p[i, 1], Y < p[j, 1], ex * wy > ey * wx
        s = np.where((c1 & c2 & c3) | (~c1 & ~c2 & ~c3), -s, s)
    return s * np.sqrt(d)


# ------------------------------------------------------------------------------------------------------------------
# Géométrie (espace de l'objet, unités de 64)
# ------------------------------------------------------------------------------------------------------------------
# 3e jet (critique du 7/11) : plus de hublot rond ni de colonne de voyants (« façade de lave-linge »), plus de signe dessiné de face
# (« autocollant »). 4e jet : une puce sombre au signe allumé faisait ÉCRAN ; le signe devient un EMBLÈME de métal poli en relief sur la
# face, dans la même perspective (paroi, ombre portée), sans lumière propre : comme en vanilla, seuls les voyants brillent. Le palier se
# lit à 5 GROS voyants en dôme sur une barre en haut, la matière de la barre et des vis le double ; au X, emblème d'or, coins d'or, halo.
CORPS = (6.0, 9.0, 61.0, 57.0, 7.5)      # boîte, chanfrein
# voyants : 5 dômes SÉPARÉS, chacun dans sa bague (3e critique : la barre en pilule faisait onglet ou barre de titre)
LED_XS = (30.6, 36.9, 43.2, 49.5, 55.8)
LED_Y, LED_R = 15.75, 2.6
HC = 1.7                                  # hauteur de l'emblème (décalage vers le haut à l'écran)
GC = (33.0, 38.5)                         # centre de l'emblème
ECHELLE_EMB = 1.18                        # emblème agrandi de 18 % (3e critique : 11 px sur 32, la couleur passait avant la forme)


def glyphe(t, X, Y):
    """Emblème du type (champ, nervures) agrandi de ECHELLE_EMB autour de GC."""
    cx, cy = GC
    sg, nv = glyphe_base(t, cx + (X - cx) / ECHELLE_EMB, cy + (Y - cy) / ECHELLE_EMB)
    return sg * ECHELLE_EMB, (nv * ECHELLE_EMB if nv is not None else None)


def glyphe_base(t, X, Y):
    cx, cy = GC
    if t == "speed":
        d = None
        for x0 in (cx - 7.0, cx + 6.5):
            s = s_polyligne(X, Y, [(x0 - 5.6, cy - 10.0), (x0 + 5.6, cy), (x0 - 5.6, cy + 10.0)], 3.0)
            d = s if d is None else np.minimum(d, s)
        return d, None
    if t == "productivity":
        roue = s_poly(X, Y, I._engrenage(cx, cy, 8, 8.8, 12.6, 0.40, 0.60)) - 0.3
        return np.maximum(roue, -s_cercle(X, Y, cx, cy, 3.6)), None
    # efficacité : feuille ASYMÉTRIQUE (un bord plus bombé, pointe effilée) et longue tige : pas une ellipse (« œil », critique du 7/11)
    ax, ay, bx, by = cx - 10.5, cy + 10.0, cx + 14.5, cy - 10.5
    L = math.hypot(bx - ax, by - ay)
    ux, uy = (bx - ax) / L, (by - ay) / L
    nx, ny = -uy, ux
    us = [i / 40.0 for i in range(41)]
    haut = [(ax + ux * L * u + nx * 9.0 * math.sin(math.pi * u) ** 0.75 * (1.0 - 0.35 * u),
             ay + uy * L * u + ny * 9.0 * math.sin(math.pi * u) ** 0.75 * (1.0 - 0.35 * u)) for u in us]
    bas = [(ax + ux * L * u - nx * 5.0 * math.sin(math.pi * u), ay + uy * L * u - ny * 5.0 * math.sin(math.pi * u)) for u in reversed(us[1:-1])]
    feuille = np.minimum(s_poly(X, Y, haut + bas) - 0.2, s_segment(X, Y, ax - 5.0, ay + 4.0, ax + 1.0, ay - 0.5, 1.15))
    nerv = s_segment(X, Y, ax + ux * 2.0, ay + uy * 2.0, ax + ux * L * 0.9, ay + uy * L * 0.9, 0.55)
    for u in (0.32, 0.52, 0.70):
        q0 = (ax + ux * L * u, ay + uy * L * u)
        nerv = np.minimum(nerv, s_segment(X, Y, q0[0], q0[1], q0[0] + ux * 3.5 + nx * 5.5, q0[1] + uy * 3.5 + ny * 5.5, 0.42))
    return feuille, nerv


# ------------------------------------------------------------------------------------------------------------------
# Rendu
# ------------------------------------------------------------------------------------------------------------------
_BRUIT = {}


def bruit(sigma):
    if sigma not in _BRUIT:
        n = np.random.RandomState(GRAINE + int(sigma * 10)).standard_normal((N, N))
        n = ndimage.gaussian_filter(n, sigma)
        _BRUIT[sigma] = n / max(n.std(), 1e-9)
    return _BRUIT[sigma]


def extrusion(sd_fn, dy0, dy1, pas=12):
    """Union d'une forme balayée à l'écran de dy0 à dy1 (paroi d'un volume) ; sd_fn(X, Y) en espace de l'objet."""
    s = None
    for i in range(pas + 1):
        Xb, Yb = grille(dy0 + (dy1 - dy0) * i / float(pas))
        v = sd_fn(Xb, Yb)
        s = v if s is None else np.minimum(s, v)
    return s


_GEO = {}


def geometrie(t):
    """Champs du type t, qui ne dépendent pas du palier (mis en cache : les 10 paliers ne paient l'extrusion qu'une fois)."""
    if t in _GEO:
        return _GEO[t]
    X, Y = grille()
    Xp, Yp = grille(-HC)                 # dessus de l'emblème
    f_corps = lambda A, B: s_chanfrein(A, B, *CORPS)       # noqa: E731
    f_emb = lambda A, B: glyphe(t, A, B)[0]                # noqa: E731
    g = dict(X=X, Y=Y)
    g["s_corps"] = f_corps(X, Y)
    g["s_bas"] = extrusion(f_corps, 0.0, EPAIS, 16)
    g["a_top"] = I.couv(g["s_corps"])
    g["a_obj"] = I.couv(np.minimum(g["s_corps"], g["s_bas"]))
    g["a_cote"] = np.clip(g["a_obj"] - g["a_top"], 0.0, 1.0)
    g["s_pt"], g["s_nerv"] = glyphe(t, Xp, Yp)
    g["a_pt"] = I.couv(g["s_pt"])                           # dessus de l'emblème
    g["a_pc"] = np.clip(I.couv(extrusion(f_emb, -HC, 0.0, 8)) - g["a_pt"], 0.0, 1.0)   # paroi de l'emblème
    # ombre portée de l'emblème sur la face (vers le sud-est)
    dec = int(round(1.2 * U))
    o = np.zeros((N, N))
    o[dec:, dec:] = np.maximum(I.couv(f_emb(X, Y)), g["a_pc"])[:-dec, :-dec]
    g["ombre"] = ndimage.gaussian_filter(o, 0.9 * U) * (1 - g["a_pt"]) * (1 - g["a_pc"])
    Xm, Ym = grille(EPAIS * 0.55)
    g["Xm"], g["Ym"] = Xm, Ym
    _GEO[t] = g
    return g


def rendre(t, k, avec_plaque=False):
    g = geometrie(t)
    X, Y = g["X"], g["Y"]
    e = eclat(k)
    mk = marche(k)
    lum = np.asarray(I.TYPE_COULEURS[t]["lumiere"], float)
    peint = np.asarray(PEINTURE[t], float)
    gar = GARNITURE[mk]
    s_corps, s_bas, a_top, a_obj, a_cote = g["s_corps"], g["s_bas"], g["a_top"], g["a_obj"], g["a_cote"]
    s_pt, a_pt, a_pc, ombre_puce = g["s_pt"], g["a_pt"], g["a_pc"], g["ombre"]

    alb = np.zeros((N, N, 3))
    rough = np.zeros((N, N))
    met = np.zeros((N, N))
    emis = np.zeros((N, N, 3))

    def poser(a, mat):
        nonlocal alb, rough, met
        alb = I._melange(alb, mat["rgb"], a)
        rough = rough * (1 - a) + mat["rough"] * a
        met = met * (1 - a) + mat["met"] * a

    # peinture : teinte qui varie à grande échelle (pas de grain), usure SEULEMENT sur les arêtes
    n_l = bruit(24.0)
    poser(a_top, dict(rgb=tuple(peint), rough=0.50, met=0.25))
    alb = alb * np.clip(1.0 + 0.05 * n_l, 0.85, 1.15)[..., None]
    arete = 1.0 - I.profil(s_corps, 1.3)
    usure = np.clip((arete - 0.55) * 3.0 + 0.25 * bruit(5.0), 0.0, 1.0) * a_top
    poser(usure * 0.8, METAL_NU)
    H = (5.0 + 1.5 * I.profil(s_corps, 2.4)) * a_top
    a_r = I.couv(np.abs(s_corps + 2.7) - 0.32) * a_top      # rainure de panneau
    H -= 0.55 * a_r
    alb = alb * (1 - 0.35 * a_r)[..., None]
    if mk == 4:   # X : coins d'or sur les 4 chanfreins (la pièce de plus), assez grands pour se voir à 32 px
        cx0, cy0 = (CORPS[0] + CORPS[2]) / 2, (CORPS[1] + CORPS[3]) / 2
        hx, hy = (CORPS[2] - CORPS[0]) / 2, (CORPS[3] - CORPS[1]) / 2
        coin = (np.abs(X - cx0) + np.abs(Y - cy0)) - (hx + hy - CORPS[4] - 11.0)
        a_coin = I.couv(-coin) * I.couv(s_corps + 0.6) * (1 - a_r)
        poser(a_coin, GARNITURE[4])
        H += 0.5 * a_coin

    # 5 voyants en dôme, chacun dans sa bague de la matière du palier : allumés = ceil(k / 2) ; aux paliers impairs, le dernier
    # allumé est à demi (I et II, III et IV... se distinguent) ; reflet en haut à gauche
    a_led_on = np.zeros((N, N))
    for i, lx in enumerate(LED_XS):
        s_bg = s_cercle(X, Y, lx, LED_Y, LED_R + 1.0)
        a_bg = I.couv(s_bg)
        poser(a_bg, gar)
        H = H * (1 - a_bg) + (5.9 + 0.8 * I.profil(s_bg, 0.8)) * a_bg
        s_l = s_cercle(X, Y, lx, LED_Y, LED_R)
        a_l = I.couv(s_l)
        d_l = I.profil(s_l, LED_R)
        H = H * (1 - a_l) + (6.4 + 1.8 * d_l) * a_l
        if i < leds(k):
            demi = 0.42 if (k % 2 == 1 and i == leds(k) - 1) else 1.0
            alb = I._melange(alb, lum * (0.15 + 0.30 * demi) + 0.03, a_l)
            emis += ((lum * 0.8 + 0.12) * (1.25 + 0.35 * e) * demi)[None, None, :] * (a_l * (0.45 + 0.55 * d_l))[..., None]
            a_led_on = np.maximum(a_led_on, a_l * demi)
        else:
            alb = I._melange(alb, lum * 0.04 + 0.004, a_l)
        rough = rough * (1 - a_l) + 0.08 * a_l
        met = met * (1 - a_l)
        a_sp = I.couv(s_cercle(X, Y, lx - 1.0, LED_Y - 1.1, 0.75)) * a_l
        emis += np.array([0.55, 0.56, 0.58])[None, None, :] * a_sp[..., None]
    h_led = ndimage.gaussian_filter(a_led_on, 1.1 * U)
    h_led = h_led / max(h_led.max(), 1e-6)
    emis += (lum * 0.30)[None, None, :] * (h_led * (1 - a_led_on) * a_top)[..., None]

    # emblème : bord de métal de la matière du palier, émail de verre de la couleur du type (lueur douce qui monte avec le palier),
    # nervures gravées ; un emblème gris faisait « réglages » (engrenage) et « plume » (feuille), essai du 7/11
    mat_e = gar
    poser(a_pt, mat_e)
    H = H * (1 - a_pt) + (5.0 + HC + 1.2 * I.profil(s_pt, 1.1)) * a_pt
    a_em = I.couv(s_pt + 1.0)
    alb = I._melange(alb, lum * 0.85, a_em)
    rough = rough * (1 - a_em) + 0.12 * a_em
    met = met * (1 - a_em)
    emis += (lum * (0.22 + 0.38 * e))[None, None, :] * a_em[..., None]
    s_nerv = g["s_nerv"]
    if s_nerv is not None:
        a_n = I.couv(s_nerv) * a_pt
        H -= 0.9 * a_n
        alb = alb * (1 - 0.55 * a_n)[..., None]
    if mk == 4:   # X : halo coloré autour de l'emblème, sur la face (jamais du blanc)
        hp = ndimage.gaussian_filter(np.maximum(a_pt, a_pc), 2.2 * U)
        hp = hp / max(hp.max(), 1e-6)
        emis += (lum * 0.75)[None, None, :] * (hp * (1 - a_pt) * (1 - a_pc) * a_top)[..., None]

    # éclairage (même lumière que icones.rendre_art)
    gy, gx = np.gradient(H * U)
    gx, gy = gx / U, gy / U
    nx, ny, nz = -gx * 2.0, -gy * 2.0, np.ones_like(H)
    nn = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / nn, ny / nn, nz / nn
    diff = np.clip(nx * I.LUM[0] + ny * I.LUM[1] + nz * I.LUM[2], 0.0, 1.0)
    nh = np.clip(nx * I.DEMI[0] + ny * I.DEMI[1] + nz * I.DEMI[2], 0.0, 1.0)
    p = 6.0 + (1.0 - rough) ** 2 * 90.0
    spec = (0.04 + 0.75 * (1.0 - rough) ** 2) * nh ** p
    creux = np.clip(ndimage.gaussian_filter(H, 1.0 * U) - H, 0.0, 3.0)
    occl = (1.0 - 0.38 * creux) * (1.0 - 0.60 * ombre_puce)
    vert = 1.08 - 0.16 * (I.Y / 64.0)
    lit = alb * ((0.34 + 0.66 * diff / I.LUM[2]) * occl * vert)[..., None]
    lit = lit + spec[..., None] * ((1.0 - met)[..., None] + met[..., None] * alb * 2.2) + emis

    # paroi de l'emblème : son métal dans l'ombre, filet clair sous l'arête
    paroi_p = np.asarray(mat_e["rgb"])[None, None, :] * 0.30
    filet_p = I.couv(np.abs(s_pt) - 0.4) * a_pc
    paroi_p = paroi_p + np.array([0.12, 0.12, 0.13])[None, None, :] * filet_p[..., None]
    lit = lit * (1 - a_pc[..., None]) + paroi_p * a_pc[..., None]

    # paroi avant du boîtier : peinture dans l'ombre, filet clair sous l'arête, contacts dorés
    fond_paroi = np.clip((I.Y - 30.0) / 30.0, 0.0, 1.0)
    # tranches éclairées selon leur orientation (lumière du nord-ouest : tranche ouest claire, tranche sud sombre ; 3e critique)
    gyc, gxc = np.gradient(s_corps)
    nrm = np.sqrt(gxc * gxc + gyc * gyc) + 1e-9
    face_l = np.clip((gxc * -0.86 + gyc * -0.50) / nrm, 0.0, 1.0)
    paroi = peint[None, None, :] * (0.22 + 0.50 * face_l + 0.03 * n_l)[..., None] * (1.0 - 0.35 * fond_paroi)[..., None]
    filet = I.couv(np.abs(s_corps) - 0.45) * a_cote
    Xm, Ym = g["Xm"], g["Ym"]
    s_pins = None
    for px_ in np.arange(15.0, 52.0, 4.0):
        sp = s_boite(Xm, Ym, px_ - 1.1, 51.0, px_ + 1.1, 63.0, 0.3)
        s_pins = sp if s_pins is None else np.minimum(s_pins, sp)
    a_pins = I.couv(s_pins) * a_cote * np.clip((I.Y - 30.0) / 4.0, 0.0, 1.0)
    paroi = paroi + np.asarray(METAL_NU["rgb"])[None, None, :] * 0.35 * filet[..., None]
    or_p = np.asarray(GARNITURE[3]["rgb"]) * 0.55
    paroi = paroi * (1 - a_pins[..., None]) + or_p[None, None, :] * a_pins[..., None]
    rgb_pm = lit * a_top[..., None] + paroi * a_cote[..., None]     # déjà prémultiplié par la couverture

    # bord sombre doux (pas de contour noir) et ombre portée au sol
    s_obj = np.minimum(s_corps, s_bas)
    rgb_pm *= (0.45 + 0.55 * I.profil(s_obj, 0.9))[..., None]
    if avec_plaque:
        rgb_pm, a_obj = plaque_vecteur(rgb_pm, a_obj, t, k)
    dec = int(round(1.4 * U))
    ombre = np.zeros((N, N))
    ombre[dec:, dec:] = a_obj[:-dec, :-dec]
    ombre = ndimage.gaussian_filter(ombre, 1.3 * U) * 0.55
    alpha = a_obj + ombre * (1 - a_obj)
    return rgb_pm, np.clip(alpha, 0.0, 1.0)


def plaque_vecteur(rgb_pm, a_obj, t, k):
    """Plaque du chiffre romain en vecteur, à la place exacte de la plaque au pixel des 32 px (icones.plaque_vecteur)."""
    R = I.roles_type(t, k)
    a_pl, a_gl = I.plaque_vecteur(k)
    fond = np.asarray(R["plaque"]["rgb"], float) * 0.6 + 0.006
    bord = np.asarray(R["logement"]["rgb"], float) * 0.35
    a_bd = I.couv(np.abs(I.sd_plaque(k) + 0.5) - 0.5) * a_pl
    c = fond[None, None, :] * (1 - a_bd[..., None]) + bord[None, None, :] * a_bd[..., None]
    c = c * (1 - a_gl[..., None]) + I.couleur_glyphe(R, k)[None, None, :] * a_gl[..., None]
    rgb_pm = rgb_pm * (1 - a_pl[..., None]) + c * a_pl[..., None]
    return rgb_pm, np.maximum(a_obj, a_pl)


def icone_objet(t, k):
    """Bande 120 x 64 (64, 32, 16, 8 px) comme icones.icone_objet : plaque en vecteur à 64 px, au pixel à 32 px."""
    rgb, a = rendre(t, k)
    rgb_p, a_p = plaque_vecteur(rgb, a, t, k)      # la plaque posée sur l'image finie (un seul rendu par palier)
    R = I.roles_type(t, k)
    im64 = I.en_image(*I.reduire(rgb_p, a_p, 64))
    im32 = I.poser_plaque_pixel(I.en_image(*I.reduire(rgb, a, 32)), k, 1, R)
    im16 = I.reduire_image(im32, 16)
    im8 = I.reduire_image(im16, 8)
    bande = Image.new("RGBA", (120, 64), (0, 0, 0, 0))
    x = 0
    for im in (im64, im32, im16, im8):
        bande.paste(im, (x, 0))
        x += im.size[0]
    return bande, im64
