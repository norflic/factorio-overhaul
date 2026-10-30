"""Dessins des 10 icônes du lot CALC-ICONES-A (puces, composants, 2 fluides). Moteur : moteur2d.py ; couleurs : palette.py.

Coordonnées en unités de 0 à 64 (1 unité = 1 px de l'icône de 64), y vers le bas. Lumière du nord-ouest.
"""
import math

import numpy as np
from scipy import ndimage

import moteur2d as M
import palette as P
from moteur2d import X, Y, U, Surface, Toile, couv, profil, sd_boite, sd_cercle, sd_segment, sd_poly, bruit


# ------------------------------------------------------------------------------------------------------------------
# Matières et motifs communs des puces
# ------------------------------------------------------------------------------------------------------------------
def irise(xl, yl, force=1.0, graine=7):
    """Film d'interférence du silicium poli (teinte qui tourne avec la position) : rgb linéaire faible."""
    nz = bruit(graine, maille=16)
    ph = 0.018 * (xl * 0.8 + yl) + 0.30 * nz
    rgb = np.stack([0.5 + 0.5 * np.cos(2 * math.pi * (ph + o)) for o in (0.0, 0.33, 0.67)], axis=-1)
    return rgb * 0.035 * force


def surface_silicium(xl, yl, graine=7, film=1.0, nom="silicium"):
    s = Surface(P.mat(nom))
    s.alb = s.alb + irise(xl, yl, film, graine)
    s.tref = P.lin("silicium_reflet")
    return s


def biseau(s, sd, h=0.9, w=1.4):
    s.H += h * profil(sd, w)


def plots(s, xl, yl, liste, cote=2.6, dh=0.6):
    """Plots d'or (carrés) aux centres donnés, en relief, sur une ouverture sombre de la passivation."""
    sd = None
    for (cx, cy) in liste:
        d = sd_boite(xl, yl, cx - cote / 2, cy - cote / 2, cx + cote / 2, cy + cote / 2, 0.4)
        sd = d if sd is None else np.minimum(sd, d)
    s.poser(couv(sd - 0.35), P.mat("or_sombre"), dh=-0.2)
    a = couv(sd)
    s.poser(a, P.mat("or"), dh=dh, prof=profil(sd, 0.7))
    return a


def bloc_fonction(s, xl, yl, x0, y0, x1, y1, fn, motif, graine=1, lueur=0.10, haut=0.5, force_motif=1.0):
    """Bloc fonctionnel d'une puce (« die shot ») : couleur de fonction en relief, motif fin en creux, reflets."""
    sd = sd_boite(xl, yl, x0, y0, x1, y1, 0.5)
    a = couv(sd)
    clair, moyen, sombre = (dict(rgb=P.lin("%s.%s" % (fn, k)), rough=0.22, met=0.25) for k in ("clair", "moyen", "sombre"))
    s.poser(a, moyen, dh=haut, prof=profil(sd, 0.8))
    m = np.clip(motif(xl - x0, yl - y0, x1 - x0, y1 - y0), 0, 1) * couv(sd + 0.7) * force_motif
    s.poser(m, sombre, dh=-0.22)
    nz = bruit(graine, maille=5)
    hl = np.clip((nz - 0.58) * 3.0, 0, 1) * a * (1 - m)
    s.poser(hl * 0.9, clair)
    s.lueur(a * (1 - 0.7 * m), P.lin(fn + ".moyen"), lueur)
    return a


def rayures(pas, larg, axe="x"):
    def m(u, v, w, h):
        t = (u if axe == "x" else v) / pas
        f = np.abs(t - np.round(t)) * pas
        return np.clip((larg / 2 - f) * U / 1.5 + 0.5, 0, 1)
    return m


def grille(pas, larg):
    def m(u, v, w, h):
        return np.maximum(rayures(pas, larg, "x")(u, v, w, h), rayures(pas, larg, "y")(u, v, w, h))
    return m


def anneau_scellement(s, xl, yl, x0, y0, x1, y1, retrait=1.3, larg=0.9):
    sd = sd_boite(xl, yl, x0 + retrait, y0 + retrait, x1 - retrait, y1 - retrait, 0.6)
    d = np.maximum(sd, -(sd + larg))
    s.poser(couv(d), P.mat("anneau"), dh=0.35, prof=profil(d, 0.4))


# ------------------------------------------------------------------------------------------------------------------
# Puce logique : carrée, plots sur les 4 bords, 4 cœurs ambre
# ------------------------------------------------------------------------------------------------------------------
def icone_puce_logique():
    t = Toile()
    x0, y0, x1, y1 = 7.5, 10.5, 56.5, 59.5

    def f(x, y):
        return sd_boite(x, y, x0, y0, x1, y1, 1.4)

    def dessus(xl, yl, sd):
        s = surface_silicium(xl, yl, 11)
        biseau(s, sd)
        anneau_scellement(s, xl, yl, x0, y0, x1, y1)
        pl = []
        n = 9
        for i in range(n):
            u = x0 + 6.2 + i * (x1 - x0 - 12.4) / (n - 1)
            pl += [(u, y0 + 3.7), (u, y1 - 3.7)]
            v = y0 + 6.2 + i * (y1 - y0 - 12.4) / (n - 1)
            pl += [(x0 + 3.7, v), (x1 - 3.7, v)]
        plots(s, xl, yl, pl)
        c0, c1 = x0 + 6.8, x1 - 6.8
        r0, r1 = y0 + 6.8, y1 - 6.8
        mx, my = (c0 + c1) / 2, (r0 + r1) / 2
        g = 1.5
        mot = grille(2.6, 0.42)
        for (a0, b0, a1, b1, gr) in ((c0, r0, mx - g, my - g, 1), (mx + g, r0, c1, my - g, 2),
                                     (c0, my + g, mx - g, r1, 3), (mx + g, my + g, c1, r1, 4)):
            bloc_fonction(s, xl, yl, a0, b0, a1, b1, "logique", mot, graine=20 + gr, lueur=0.34, force_motif=0.6)
            # unité d'exécution claire dans le coin intérieur de chaque cœur
            ix = a1 - 5.0 if a0 < mx else a0 + 1.2
            iy = b1 - 5.0 if b0 < my else b0 + 1.2
            d = sd_boite(xl, yl, ix, iy, ix + 3.8, iy + 3.8, 0.4)
            r = couv(d)
            s.poser(r, dict(rgb=P.lin("logique.clair"), rough=0.18, met=0.3), dh=0.35, prof=profil(d, 0.5))
            s.lueur(r, P.lin("logique.clair"), 0.45)
        # bus d'or en croix entre les cœurs
        bus = np.minimum(sd_boite(xl, yl, mx - 0.45, r0 + 0.5, mx + 0.45, r1 - 0.5),
                         sd_boite(xl, yl, c0 + 0.5, my - 0.45, c1 - 0.5, my + 0.45))
        s.poser(couv(bus), P.mat("or"), dh=0.2)
        return s

    t.dalle(f, 0.0, 3.6, P.mat("silicium_bord"), dessus)
    t.contour()
    return t


# ------------------------------------------------------------------------------------------------------------------
# Puce DRAM : rectangle long, plots au milieu, 8 bancs vert d'eau
# ------------------------------------------------------------------------------------------------------------------
def icone_puce_dram():
    t = Toile()
    x0, y0, x1, y1 = 3.5, 19.0, 61.5, 50.0

    def f(x, y):
        return sd_boite(x, y, x0, y0, x1, y1, 1.2)

    def dessus(xl, yl, sd):
        s = surface_silicium(xl, yl, 13)
        biseau(s, sd)
        anneau_scellement(s, xl, yl, x0, y0, x1, y1)
        my = (y0 + y1) / 2
        spine = sd_boite(xl, yl, x0 + 3.0, my - 2.3, x1 - 3.0, my + 2.3, 0.6)
        s.poser(couv(spine), P.mat("silicium_bord"), dh=-0.15)
        n = 13
        plots(s, xl, yl, [(x0 + 5.4 + i * (x1 - x0 - 10.8) / (n - 1), my) for i in range(n)], cote=2.5)
        mot = rayures(1.1, 0.45, "x")
        w = (x1 - x0 - 6.0 - 3 * 1.7) / 4
        for row, (b0, b1) in enumerate(((y0 + 3.0, my - 3.0), (my + 3.0, y1 - 3.0))):
            for k in range(4):
                a0 = x0 + 3.0 + k * (w + 1.7)
                bloc_fonction(s, xl, yl, a0, b0, a0 + w, b1, "dram", mot, graine=40 + row * 4 + k, lueur=0.30)
                cy = (b0 + b1) / 2
                d = sd_boite(xl, yl, a0 + 0.5, cy - 0.7, a0 + w - 0.5, cy + 0.7, 0.3)
                amp = couv(d)
                s.poser(amp, dict(rgb=P.lin("dram.clair"), rough=0.2, met=0.3), dh=0.25)
                s.lueur(amp, P.lin("dram.clair"), 0.35)
        return s

    t.dalle(f, 0.0, 3.6, P.mat("silicium_bord"), dessus)
    t.contour()
    return t


# ------------------------------------------------------------------------------------------------------------------
# Puce SRAM : cache EMPILÉ (deux puces), pavage violet 4 x 4
# ------------------------------------------------------------------------------------------------------------------
def icone_puce_sram():
    # Critique du 30/10 : la puce du dessus DÉBORDAIT de la base (à gauche et en haut) : deux cartes qui se chevauchent,
    # la base se lisait comme une équerre violette. Le cache est maintenant POSÉ sur la base, en retrait de ses bords,
    # et y jette son ombre (lumière du nord-ouest) ; la base montre des vias d'or (liaisons du cache empilé), pas du violet.
    t = Toile()
    bx0, by0, bx1, by1 = 10.0, 17.0, 61.0, 63.0      # puce de base
    hx0, hy0, hx1, hy1 = 14.5, 22.5, 48.5, 56.5      # cache empilé (posé sur la base, en retrait)

    def fb(x, y):
        return sd_boite(x, y, bx0, by0, bx1, by1, 1.2)

    def dessus_base(xl, yl, sd):
        s = surface_silicium(xl, yl, 17)
        biseau(s, sd)
        anneau_scellement(s, xl, yl, bx0, by0, bx1, by1)
        # vias d'or en grille (liaisons verticales vers le cache) sur la partie découverte, à droite et en bas
        pl = []
        for i in range(4):
            for j in range(11):
                pl.append((hx1 + 3.4 + i * 2.6, by0 + 4.0 + j * 3.6))
        for i in range(8):
            for j in range(2):
                pl.append((bx0 + 4.0 + i * 3.6, hy1 + 2.8 + j * 2.6))
        plots(s, xl, yl, pl, cote=1.3, dh=0.30)
        # ombre portée du cache (au sud-est), douce
        omb = ndimage.gaussian_filter(couv(sd_boite(xl, yl, hx0 + 2.2, hy0 + 2.4, hx1 + 2.2, hy1 + 2.4, 1.2)), 0.9 * U)
        s.alb = s.alb * (1 - 0.70 * omb)[..., None]
        s.H -= 0.9 * omb
        return s

    def fh(x, y):
        return sd_boite(x, y, hx0, hy0, hx1, hy1, 1.2)

    def dessus_haut(xl, yl, sd):
        s = surface_silicium(xl, yl, 19)
        biseau(s, sd)
        anneau_scellement(s, xl, yl, hx0, hy0, hx1, hy1)
        n = 4
        g = 1.5
        w = (hx1 - hx0 - 5.4 - (n - 1) * g) / n
        for i in range(n):
            for j in range(n):
                a0 = hx0 + 2.7 + i * (w + g)
                b0 = hy0 + 2.7 + j * (w + g)
                clair = (i + j) % 2 == 0
                bloc_fonction(s, xl, yl, a0, b0, a0 + w, b0 + w, "sram", rayures(0.95, 0.38, "y" if clair else "x"),
                              graine=70 + i * 4 + j, lueur=0.36 if clair else 0.20)
        tags = None
        for i in range(1, n):
            u = hx0 + 2.7 + i * (w + g) - g / 2
            v = hy0 + 2.7 + i * (w + g) - g / 2
            d = np.minimum(sd_boite(xl, yl, u - 0.3, hy0 + 2.7, u + 0.3, hy1 - 2.7),
                           sd_boite(xl, yl, hx0 + 2.7, v - 0.3, hx1 - 2.7, v + 0.3))
            tags = d if tags is None else np.minimum(tags, d)
        a = couv(tags)
        s.poser(a, dict(rgb=P.lin("sram.clair"), rough=0.2, met=0.2), dh=0.1)
        s.lueur(a, P.lin("sram.clair"), 0.45)
        return s

    t.dalle(fb, 0.0, 3.2, P.mat("silicium_bord"), dessus_base)
    t.dalle(fh, 3.2, 3.4, P.mat("silicium_bord"), dessus_haut)
    t.contour()
    return t


# ------------------------------------------------------------------------------------------------------------------
# Tranche gravée : disque à méplat, damier de puces, irisé
# ------------------------------------------------------------------------------------------------------------------
def icone_tranche_gravee():
    t = Toile()
    cx, cy, r = 32.0, 33.0, 28.5
    meplat = cy + 26.0

    def f(x, y):
        return np.maximum(sd_cercle(x, y, cx, cy, r), y - meplat)

    def dessus(xl, yl, sd):
        # Critique du 30/10 : puces de 5,5 px, bruit à 32 px ; pas de 7,6 (environ 40 puces), bord nu plus irisé.
        s = surface_silicium(xl, yl, 23, film=1.7)
        biseau(s, sd, 0.6, 1.0)
        pas, rue = 7.6, 1.0
        dies = None
        n = int(2 * r / pas) + 2
        for i in range(-n, n + 1):
            for j in range(-n, n + 1):
                a0 = cx - pas / 2 + i * pas + rue / 2
                b0 = cy - pas / 2 + j * pas + rue / 2
                a1, b1 = a0 + pas - rue, b0 + pas - rue
                coins = [(a0, b0), (a1, b0), (a0, b1), (a1, b1)]
                if all(math.hypot(px - cx, py - cy) < r - 1.5 and py < meplat - 1.5 for px, py in coins):
                    d = sd_boite(xl, yl, a0, b0, a1, b1, 0.3)
                    dies = d if dies is None else np.minimum(dies, d)
        a = couv(dies)
        s.poser(a, P.mat("silicium_clair"), dh=0.30, prof=profil(dies, 0.5))
        s.alb = s.alb + irise(xl, yl, 3.0, 29) * a[..., None]
        loc_x = np.mod(xl - (cx - pas / 2 + rue / 2), pas)
        loc_y = np.mod(yl - (cy - pas / 2 + rue / 2), pas)
        # chaque puce : un cœur ambre (la puce logique à venir) et une bande de mémoire vert d'eau
        coeur = ((np.abs(loc_x - 2.4) < 1.5) & (np.abs(loc_y - 2.4) < 1.5)).astype(float) * a
        mem = ((np.abs(loc_x - 3.3) < 2.4) & (np.abs(loc_y - 5.3) < 0.7)).astype(float) * a
        s.poser(coeur, dict(rgb=P.lin("logique.moyen"), rough=0.2, met=0.3), dh=0.08)
        s.lueur(coeur, P.lin("logique.moyen"), 0.30)
        s.poser(mem, dict(rgb=P.lin("dram.moyen"), rough=0.2, met=0.3), dh=0.05)
        s.lueur(mem, P.lin("dram.moyen"), 0.22)
        return s

    def cote_fn(hh, nx, ny):
        base = np.asarray(P.lin("silicium_clair"))[None, None, :] * np.ones((M.N, M.N, 1))
        return base * (1.0 + 1.2 * np.clip(hh - 0.55, 0, 1))[..., None]

    t.dalle(f, 0.0, 2.6, P.mat("silicium_bord"), dessus, cote_fn=cote_fn)
    t.contour()
    return t


# ------------------------------------------------------------------------------------------------------------------
# Photomasque : plaque carrée de quartz, absorbeur de tungstène, cadre de pellicule
# ------------------------------------------------------------------------------------------------------------------
def icone_photomasque():
    t = Toile()
    x0, y0, x1, y1 = 6.0, 11.0, 58.0, 61.0

    def f(x, y):
        return sd_boite(x, y, x0, y0, x1, y1, 1.2)

    def dessus(xl, yl, sd):
        s = Surface(P.mat("quartz"))
        s.tref = P.lin("quartz")
        biseau(s, sd, 0.8, 1.2)
        # traînées de reflet du verre (deux bandes diagonales)
        dd = (xl - x0) + (yl - y0)
        for c0, w, k in ((30.0, 4.0, 0.22), (40.0, 1.6, 0.18)):
            s.lueur(couv(sd) * np.exp(-((dd - c0) / w) ** 2), (1.0, 1.0, 1.0), k)
        m0, n0 = x0 + 10.5, y0 + 10.0
        m1, n1 = x1 - 10.5, y1 - 10.0
        g = 1.5
        w = (m1 - m0 - 2 * g) / 3
        h = (n1 - n0 - 2 * g) / 3
        tung = P.mat("tungstene")
        for i in range(3):
            for j in range(3):
                a0, b0 = m0 + i * (w + g), n0 + j * (h + g)
                d = sd_boite(xl, yl, a0, b0, a0 + w, b0 + h, 0.3)
                a = couv(d)
                u, v = xl - a0, yl - b0
                lig = (np.abs(np.mod(v, 2.5) - 1.25) < 0.40) & (u > 1.5) & (u < w * 0.62)
                col = (np.abs(np.mod(u, 3.0) - 1.5) < 0.40) & (v > 1.2) & (v < h - 1.2) & (u > w * 0.68)
                trou = ((lig | col) & (d < -0.9)).astype(float)
                s.poser(a * (1 - trou), tung, dh=0.28, prof=profil(d, 0.4))
        for (px, py) in ((x0 + 4.6, y0 + 4.6), (x1 - 4.6, y0 + 4.6), (x0 + 4.6, y1 - 4.6), (x1 - 4.6, y1 - 4.6)):
            d = np.minimum(sd_boite(xl, yl, px - 2.4, py - 0.5, px + 2.4, py + 0.5),
                           sd_boite(xl, yl, px - 0.5, py - 2.4, px + 0.5, py + 2.4))
            s.poser(couv(d), tung, dh=0.15)
        for k in range(11):
            u = x0 + 16.0 + k * 1.9 + (0.5 if k % 3 == 0 else 0)
            d = sd_boite(xl, yl, u, y1 - 6.2, u + (0.9 if k % 2 else 0.5), y1 - 3.4)
            s.poser(couv(d), tung, dh=0.1)
        fr = sd_boite(xl, yl, m0 - 3.4, n0 - 3.4, m1 + 3.4, n1 + 3.4, 0.9)
        d = np.maximum(fr, -(fr + 1.6))
        s.poser(couv(d), P.mat("aluminium"), dh=1.2, prof=profil(d, 0.5))
        return s

    def cote_fn(hh, nx, ny):
        c = np.asarray(P.lin("quartz_bord"))[None, None, :] * np.ones((M.N, M.N, 1))
        return c * (1.35 + 0.9 * np.clip(hh - 0.45, 0, 1))[..., None]

    t.dalle(f, 0.0, 3.8, P.mat("quartz_bord"), dessus, cote_fn=cote_fn)
    t.contour()
    return t


# ------------------------------------------------------------------------------------------------------------------
# Laser à cristal : tube en diagonale (âge 10), bobines de cuivre, cristal hexagonal, faisceau
# ------------------------------------------------------------------------------------------------------------------
def icone_laser():
    # Critique du 30/10 : le premier dessin (tube long et fin, rayures de cuivre, petite pointe presque blanche) se lisait
    # comme un stylo, une seringue ou une pile. Le CRISTAL devient l'élément dominant : gros prisme hexagonal cyan à 3
    # facettes franches (claire, cyan, sombre), tenu par un collier de chrome à griffes sur un émetteur court de l'âge 10
    # (carénage gris, bobines de cuivre, voyant bleu), faisceau à la pointe.
    t = Toile()
    ax, ay = 13.0, 52.0
    ux, uy = math.sqrt(0.5), -math.sqrt(0.5)
    vx, vy = uy, -ux                      # v > 0 : côté nord-ouest (éclairé)
    u = (X - ax) * ux + (Y - ay) * uy
    v = (X - ax) * vx + (Y - ay) * vy

    def troncon(u0, u1, r):
        return np.maximum(np.maximum(u0 - u, u - u1), np.abs(v) - r)

    def cyl(r):
        return np.sqrt(np.clip(r * r - v * v, 0, None))

    # émetteur : culot noir mat, corps de carénage à 2 bobines de cuivre, collier de chrome
    vox, voy = ax + ux * 9.0 + vx * 7.4, ay + uy * 9.0 + vy * 7.4
    pieces = [(-4.0, 0.0, 11.4, "noir_mat", "culot"), (0.0, 13.0, 12.0, "carenage", "corps"),
              (13.0, 17.0, 13.6, "chrome", "bague")]
    for (u0, u1, r, nom, det) in pieces:
        sd = troncon(u0, u1, r)
        s = Surface(P.mat(nom))
        s.H = cyl(r) * 0.6
        biseau(s, np.maximum(u0 - u, u - u1), 0.5, 0.8)
        if det == "culot":
            rid = (np.abs(np.mod(v, 2.2) - 1.1) < 0.55).astype(float)
            s.H += 0.5 * rid
        if det == "bague":
            s.H += 0.4 * np.cos(2 * math.pi * (u - u0) / (u1 - u0) - math.pi) + 0.4
        if det == "corps":
            for (c0, c1) in ((1.2, 4.6), (6.2, 9.6)):
                a = couv(np.maximum(c0 - u, u - c1)) * couv(np.abs(v) - r - 0.6)
                fil = 0.5 + 0.5 * np.cos(2 * math.pi * u / 0.85)
                s.poser(a, P.mat("cuivre"), dh=0.8)
                s.H += 0.3 * a * fil
                s.alb = s.alb * (1 - 0.40 * (a * (1 - fil))[..., None])
            vo = sd_cercle(X, Y, vox, voy, 1.4)
            s.poser(couv(vo), P.mat("voyant"), dh=0.4)
            s.lueur(couv(vo), np.asarray(P.lin("10.lumiere")) * 1.0 + 0.5, 1.6)
            j = couv(np.abs(v + 4.5) - 0.2) * couv(np.maximum(10.2 - u, u - 12.6))
            s.alb = s.alb * (1 - 0.5 * j[..., None])
        t.relief(sd, s)
        if det == "corps":
            hal = np.exp(-(np.clip(sd_cercle(X, Y, vox, voy, 1.4), 0, None) / 1.5) ** 2)
            t.lueur_libre(np.asarray(P.lin("10.lumiere")) * 0.6, hal * 0.5)
    # cristal : prisme hexagonal vu de côté (3 facettes : claire au nord-ouest, cyan au milieu, sombre au sud-est)
    u0, u1, rc, kp = 15.5, 30.0, 10.4, 1.7
    pointe = np.maximum(u - u1, 0) * kp
    sd = np.maximum(np.maximum(u0 - u, u - u1 - rc / kp + 2.2), np.abs(v) - rc + pointe)
    s = Surface(P.mat("cristal", rough=0.08))
    cy_ = np.asarray(P.lin("cristal"))
    lim = rc * 0.42 - pointe * 0.42
    claire = np.clip((v - lim) * U / 2 + 0.5, 0, 1)
    sombre = np.clip((-v - lim) * U / 2 + 0.5, 0, 1)
    s.alb = M.melange(s.alb, cy_ * 1.6 + 0.10, claire)
    s.alb = M.melange(s.alb, cy_ * np.array([0.06, 0.22, 0.50]), sombre)
    s.H = np.clip(rc * 0.4 - pointe * 0.6, 0, None)
    s.tref = P.lin("cristal")
    # inclusions et fêlures internes (le cristal n'est pas du verre uni)
    nz = bruit(131, maille=3.0)
    fel = couv(np.abs((u - 22.0) * 0.55 + v * 0.8) - 0.22) * couv(np.abs(v) - rc * 0.38) * couv(np.abs(u - 22.5) - 4.0)
    s.lueur(couv(sd) * (1 - sombre), P.lin("cristal"), 0.28)
    s.lueur(couv(sd) * sombre * np.clip((nz - 0.55) * 3, 0, 1), P.lin("cristal"), 0.35)
    s.lueur(fel, P.lin("cristal_coeur"), 0.45)
    arete = couv(np.abs(np.abs(v) - np.maximum(lim, 0)) - 0.32) * couv(sd + 0.6)
    s.lueur(arete, P.lin("cristal_coeur"), 0.50)
    t.relief(sd, s, reflet=0.6)
    # griffes de chrome qui tiennent le cristal (sur les deux arêtes visibles)
    for vv in (-rc + 0.6, rc - 0.6):
        d_ = np.maximum(np.maximum(u0 - 0.5 - u, u - u0 - 6.0), np.abs(v - vv) - 1.5)
        g = Surface(P.mat("chrome"))
        g.H = 1.4 * profil(d_, 0.8)
        t.relief(d_, g)
    # faisceau et éclat à la pointe
    tip = u1 + rc / kp - 2.2
    fx, fy = ax + ux * tip, ay + uy * tip
    d = sd_segment(X, Y, fx, fy, fx + ux * 12.0, fy + uy * 12.0, 0.0)
    t.lueur_libre(np.asarray(P.lin("cristal_coeur")) * 1.4, np.exp(-(np.clip(d, 0, None) / 1.2) ** 2))
    t.lueur_libre(np.asarray(P.lin("10.lumiere")), np.exp(-(np.clip(d, 0, None) / 3.0) ** 2) * 0.6)
    ec = np.hypot(X - fx, Y - fy)
    croix = np.abs((X - fx) * vx + (Y - fy) * vy)
    t.lueur_libre(np.asarray(P.lin("cristal_coeur")) * 1.2, np.exp(-(ec / 2.0) ** 2))
    t.lueur_libre(np.asarray(P.lin("10.lumiere")) * 0.8, np.exp(-(croix / 0.5) ** 2) * np.exp(-(ec / 5.5) ** 2) * 0.8)
    t.contour()
    return t


# ------------------------------------------------------------------------------------------------------------------
# Radiateur : semelle de cuivre, ailettes d'aluminium, 2 caloducs (vraie vue 3/4)
# ------------------------------------------------------------------------------------------------------------------
def icone_radiateur():
    t = Toile()
    v = M.Vue34(5.0, 60.5, kx=0.42, ky=0.50, kz=0.92)
    X0, X1, Dp, zs, zf = 0.0, 46.0, 24.0, 5.5, 38.0     # plus haut que la 1re version : remplit le cadre
    nf, ef = 7, 2.6
    pas = (X1 - X0 - ef) / (nf - 1)
    cu = P.lin("cuivre")
    al = P.lin("aluminium")
    stries = 0.90 + 0.12 * np.cos(2 * math.pi * Y / 0.8)
    # Critique du 30/10 : faces unies, plates à côté du vanilla. Dégradé vertical (le haut des ailettes prend la lumière,
    # le pied est dans l'ombre des voisines), brossage irrégulier, et reflet du cuivre qui court sur la semelle.
    pied, tete = v.p(0, 0, zs)[1], v.p(0, 0, zf)[1]
    grad = 0.62 + 0.55 * np.clip((pied - Y) / (pied - tete), 0, 1) ** 0.8
    brosse = 1.0 + 0.16 * (bruit(141, maille=6.0) - 0.5)
    ref_cu = 0.85 + 0.45 * np.exp(-((X - 0.55 * (60.5 - Y) - 14.0) / 5.0) ** 2)
    M.boite3d(t, v, X0, X1, 0.0, Dp, 0.0, zs, cu, haut=0.9, avant=0.70, est=0.42,
              tex=dict(avant=ref_cu, haut=ref_cu))

    def caloduc(xa, xb, yy, zz=27.0, r=2.1):
        (pax, pay), (pbx, pby) = v.p(xa, yy, zz), v.p(xb, yy, zz)
        sd = np.maximum(np.abs(Y - pay) - r, np.maximum(pax - X, X - pbx))
        s = Surface(P.mat("cuivre"))
        s.H = np.sqrt(np.clip(r * r - (Y - pay) ** 2, 0, None)) * 0.9
        t.relief(sd, s, ao=False)

    for i in range(nf):
        a0 = X0 + i * pas
        M.boite3d(t, v, a0, a0 + ef, 1.0, Dp - 1.0, zs, zf, al, haut=1.25, avant=0.80, est=0.42,
                  tex=dict(avant=stries * grad * brosse, est=stries * grad ** 1.4 * brosse))
        if i < nf - 1:
            for yy in (16.5, 7.5):
                caloduc(a0 + ef, a0 + pas, yy)
    for yy in (16.5, 7.5):
        caloduc(X1, X1 + 2.8, yy)
    t.contour()
    return t


# ------------------------------------------------------------------------------------------------------------------
# Ilménite dégazée : tas de boulettes frittées
# ------------------------------------------------------------------------------------------------------------------
BOULETTES = [  # (x, y, r)
    (20.0, 19.0, 8.6), (37.0, 16.0, 8.2), (51.0, 22.5, 7.6),
    (11.0, 33.0, 8.4), (28.0, 31.0, 9.6), (45.5, 34.0, 8.8),
    (18.0, 48.0, 9.4), (36.0, 48.5, 9.8), (53.5, 47.0, 7.8),
]


def icone_ilmenite_degazee():
    t = Toile()
    pores = bruit(91, maille=1.7)
    grain = bruit(92, maille=3.5)
    paillettes = bruit(93, maille=0.9)
    for k, (cx, cy, r) in enumerate(sorted(BOULETTES, key=lambda b: b[1])):
        sd = sd_cercle(X, Y, cx, cy, r)
        s = Surface(P.mat("ilmenite_deg"))
        s.H = np.sqrt(np.clip(r * r - (X - cx) ** 2 - (Y - cy) ** 2, 0, None)) * 0.95
        p = np.clip((pores - 0.66) * 4.0, 0, 1) * couv(sd + 0.8)
        s.poser(p, P.mat("ilmenite_pore"), dh=-0.6)
        b = np.clip((grain - 0.55) * 2.0, 0, 1) * couv(sd + 1.0) * (1 - p)
        s.poser(b * 0.45, P.mat("ilmenite_reflet"))
        e = np.clip((paillettes - 0.80) * 8.0, 0, 1) * couv(sd + 1.2) * (1 - p)
        s.poser(e, P.mat("ilmenite_reflet", rough=0.12), dh=0.25)
        t.relief(sd, s, pente=1.2)
    t.contour()
    return t


# ------------------------------------------------------------------------------------------------------------------
# Résine photosensible : goutte ambre au-dessus d'une tranche qu'elle nappe
# ------------------------------------------------------------------------------------------------------------------
def goutte_sd(cx, cy, r, h):
    """Goutte : cercle (cx, cy, r) et pointe à h au-dessus du centre, flancs TANGENTS au cercle."""
    k = r / h
    tx, ty = r * math.sqrt(1 - k * k), -r * k
    pts = [(cx - tx, cy + ty), (cx, cy - h), (cx + tx, cy + ty), (cx, cy)]
    return np.minimum(sd_cercle(X, Y, cx, cy, r), sd_poly(X, Y, pts))


def icone_resine():
    t = Toile()
    ex, ey, rx, ry = 32.0, 52.5, 28.0, 9.0

    def f(x, y):
        return M.sd_ellipse(x, y, ex, ey, rx, ry)

    def dessus(xl, yl, sd):
        s = surface_silicium(xl, yl, 101, film=1.5)
        biseau(s, sd, 0.5, 0.8)
        nap = M.sd_ellipse(xl, yl, ex, ey, 17.0, 5.4)
        a = couv(nap)
        s.poser(a, P.mat("resine"), dh=0.9, prof=profil(nap, 2.5))
        s.lueur(a, P.lin("resine"), 0.12)
        return s

    t.dalle(f, 0.0, 2.4, P.mat("silicium_bord"), dessus)
    cx, cy, r = 32.0, 28.5, 13.6
    sd = goutte_sd(cx, cy, r, 27.0)
    s = Surface(P.mat("resine", rough=0.14))
    s.tref = P.lin("resine")
    # distance intérieure EXACTE (la réunion cercle + pointe n'est pas un vrai champ de distance dedans)
    dd = ndimage.distance_transform_edt(sd < 0) / U
    dd = ndimage.gaussian_filter(dd, 0.6 * U)
    s.H = np.sqrt(dd * (2 * r - np.minimum(dd, r))) * 0.85
    a = couv(sd)
    bord = 1.0 - profil(sd, 4.0)
    s.alb = M.melange(s.alb, P.lin("resine_sombre"), bord * a * 0.85)
    # la lumière traverse la résine : le bas de la goutte s'allume (côté opposé à la lumière)
    trans = np.clip((Y - (cy - 4.0)) / (r + 4.0), 0, 1) * np.clip((X - cx + 6.0) / 14.0, 0, 1)
    s.lueur(a * trans * profil(sd, 3.0), np.array([1.0, 0.50, 0.08]), 0.75)
    s.lueur(a, np.asarray(P.lin("resine")), 0.06)
    t.relief(sd, s, reflet=0.8, pente=1.0)
    # reflet net de la fenêtre (haut gauche)
    hl = M.sd_ellipse(X, Y, cx - 5.5, cy - 5.5, 2.0, 3.4)
    t.lueur_libre(np.array([1.0, 0.95, 0.85]), couv(hl) * 0.8)
    t.contour()
    return t


# ------------------------------------------------------------------------------------------------------------------
# Hélium-3 : noyau de 3 nucléons (2 protons, 1 neutron), 2 orbites de plasma (âge 13)
# ------------------------------------------------------------------------------------------------------------------
def icone_helium3():
    t = Toile()
    cx, cy = 32.0, 32.5
    orbites = [(math.radians(-30), 30.0, 10.0), (math.radians(30), 30.0, 10.0)]

    def orbite(theta, a, b, devant):
        ct, st = math.cos(theta), math.sin(theta)
        xr = (X - cx) * ct + (Y - cy) * st
        yr = -(X - cx) * st + (Y - cy) * ct
        e = np.abs(np.hypot(xr / a, yr / b) - 1.0) * b
        cote = ((yr > 0) if devant else (yr <= 0)).astype(float)
        return couv(e - 0.85) * cote, np.exp(-(e / 1.5) ** 2) * cote

    def electron(theta, a, b, phi):
        ct, st = math.cos(theta), math.sin(theta)
        ex_, ey_ = a * math.cos(phi), b * math.sin(phi)
        return cx + ex_ * ct - ey_ * st, cy + ex_ * st + ey_ * ct

    plasma = np.asarray(P.lin("plasma"))
    for (th, a, b) in orbites:
        a_, halo = orbite(th, a, b, False)
        t.lueur_libre(plasma * 0.5, halo * 0.28)
        t.poser(np.zeros((M.N, M.N, 3)) + plasma * 0.75, a_ * 0.95)
    nucl = [(37.0, 25.0, 9.4, "helium3_neutron"), (26.0, 32.5, 9.8, "helium3_proton"),
            (38.5, 39.5, 9.8, "helium3_proton")]
    for (x, y, r, nom) in sorted(nucl, key=lambda n: n[1]):
        sd = sd_cercle(X, Y, x, y, r)
        s = Surface(P.mat(nom))
        s.H = np.sqrt(np.clip(r * r - (X - x) ** 2 - (Y - y) ** 2, 0, None))
        if nom == "helium3_proton":
            s.lueur(couv(sd), np.asarray(P.lin("13.coeur")) * 0.4, 0.15)
        t.relief(sd, s, pente=1.0)
    for k, (th, a, b) in enumerate(orbites):
        a_, halo = orbite(th, a, b, True)
        t.lueur_libre(plasma * 0.5, halo * 0.30)
        t.poser(np.zeros((M.N, M.N, 3)) + plasma * 1.15, a_)
        exx, eyy = electron(th, a, b, math.radians(55 if k == 0 else 205))
        d = sd_cercle(X, Y, exx, eyy, 2.4)
        t.poser(np.zeros((M.N, M.N, 3)) + np.array([1.5, 1.2, 1.6]), couv(d))
        t.lueur_libre(plasma, np.exp(-(np.clip(d, 0, None) / 1.7) ** 2) * 0.75)
    t.contour()
    return t


ICONES = {   # nom -> (fonction, âge, type de prototype)
    "fo-logic-die": (icone_puce_logique, 10, "item"),
    "fo-dram-die": (icone_puce_dram, 10, "item"),
    "fo-sram-die": (icone_puce_sram, 10, "item"),
    "fo-etched-wafer": (icone_tranche_gravee, 10, "item"),
    "fo-photomask": (icone_photomasque, 10, "item"),
    "fo-crystal-laser": (icone_laser, 10, "item"),
    "fo-heat-sink": (icone_radiateur, 10, "item"),
    "fo-degassed-ilmenite": (icone_ilmenite_degazee, 13, "item"),
    "fo-photoresist": (icone_resine, 10, "fluid"),
    "fo-helium-3": (icone_helium3, 13, "fluid"),
}
