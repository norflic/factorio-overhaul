"""PLANCHES D'EFFETS des expérimentaux (lot RB-V0, 31/10), 8 images dans le temps sur une vraie base vanilla.

    py -3.9 tools/render/pieces/experimentaux/effets.py --src <sprites> --dest <dossier> [--qui ixion,bourdon]

IXION, effet 1 « La Tranchée » : la roue prend feu, frappe le sol ; une fissure de plasma court droit devant sur 90 tuiles, des geysers
sortent le long de la fissure, ce qui est dessus saute. BOURDON, effet 1 « Le Glas » : le battant frappe la cloche ; une onde de choc
circulaire balaie 60 tuiles, couche la base et fend le sol en étoile.
"""
import argparse
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fx as X  # noqa: E402
import scene as SC  # noqa: E402

PPT = 32
COS = math.cos(math.radians(45.0))


def base_rangees(x0, x1, y0, y1, seed, trou=None):
    """Base vanilla : îlots de production alignés sur la grille, tapis, poteaux. trou(x, y) : vrai = rien ici."""
    r = np.random.RandomState(seed)
    ents = []
    y = y0
    bloc = 0
    while y < y1:
        famille = ["assembleur", "four", "assembleur", "labo", "four", "panneau"][bloc % 6]
        pas = 4
        x = x0 + (bloc % 2) * 2
        while x < x1:
            # îlots de 3 à 7 machines de même type, trous de service
            if r.rand() < 0.2:
                x += pas * int(r.randint(1, 3))
                continue
            f_ilot = famille if famille == "panneau" or r.rand() < 0.6 else ["assembleur", "four", "labo"][int(r.randint(0, 3))]
            for _ in range(int(r.randint(3, 8))):
                if x >= x1:
                    break
                if not (trou and trou(x, y)):
                    ents.append((f_ilot, x, y))
                    if famille != "panneau" and not (trou and trou(x, y + 6)):
                        ents.append((f_ilot, x, y + 6))
                x += pas
        # tapis entre les 2 rangées
        if famille != "panneau":
            x = x0 - 2
            while x < x1 + 2:
                if not (trou and trou(x, y + 3)):
                    ents.append(("tapis", x, y + 3))
                x += 1
            for x in range(int(x0), int(x1), 12):
                if not (trou and trou(x + 1, y + 3)):
                    ents.append(("petit_poteau", x + 1, y + 3 + 0.0))
        y += 15 if famille != "panneau" else 7
        bloc += 1
    return ents


def materialise(liste, ppt=PPT):
    return [{"pos": (x, y), "layers": SC.vanilla(n, ppt), "nom": n} for (n, x, y) in liste]


RUINE = {"assembleur": "assembleur_r", "four": "four_r", "labo": "labo_r", "raffinerie": "raffinerie_r", "radar": "radar_r", "tourelle": "tourelle_r"}


def ruine(e, ppt=PPT):
    """L'entité détruite : son vrai reste vanilla (un tapis, un mur, un panneau disparaissent)."""
    n = e["nom"]
    if n in RUINE:
        return {"pos": e["pos"], "layers": SC.vanilla(RUINE[n], ppt), "nom": RUINE[n]}
    return None


def lisse(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# ==================================================================================================== IXION
PSI = -math.radians(38.0)
R_EXT, DENT = 28.0, 1.7
ZC = R_EXT + DENT - 0.3
W_J = 3.8
KE = 0.85


def ecran_ix(x, y, z):
    """Point local de la roue → décalage écran en tuiles depuis sa position au sol."""
    wx = x * math.cos(PSI) - y * math.sin(PSI)
    wy = x * math.sin(PSI) + y * math.cos(PSI)
    return wx * KE, -(wy + z) * COS * KE


def effet_ixion(src, dest):
    W_t, H_t, gx, gy = 128, 92, 30, 62
    sc = SC.Scene(W_t, H_t, PPT, seed=21)
    g = SC.geant(src, "ixion", PPT)
    # la fissure : droit devant, légèrement en biais de la marche
    D = math.radians(21.0)
    V = 46.0                    # tuiles par unité de temps
    rs = X.Reseau(1313)
    rs.trace((gx + 1.5, gy + 0.2), D, 92.0, 0.0, 1.5, wob=0.3, pas=0.7, branches=0.075)
    A = rs.rasterise(W_t, H_t, PPT) / V
    masque = (A < 1e6).astype(np.float32)
    A2 = np.where(A < 1e6, A, 0.0)
    # arrivée d'un point au sol : plus proche passage (pour décider des destructions)
    princ = []
    x, y = gx + 1.5, gy + 0.2
    for i in range(0, 100):
        princ.append((gx + 1.5 + math.cos(D) * i, gy + 0.2 + math.sin(D) * i, i / V))

    def proche(px, py):
        best, ta = 1e9, 0.0
        for (qx, qy, t) in princ:
            d = (qx - px) ** 2 + (qy - py) ** 2
            if d < best:
                best, ta = d, t
        return math.sqrt(best), ta

    L = base_rangees(50, 124, 61, 92, 3) + base_rangees(52, 124, 26, 52, 4)
    for yy in range(46, 92, 3):
        L.append(("tourelle", 46.5, yy))
    for yy in range(44, 92, 1):
        L.append(("mur", 43.5, yy))
    L += [("raffinerie", 66, 22), ("raffinerie", 74, 22), ("raffinerie", 82, 22), ("radar", 100, 22), ("radar", 106, 22), ("poteau", 62, 56), ("poteau", 92, 56), ("poteau", 118, 56)]
    ents0 = materialise(L)
    FLAMMES = [(p[1] * 1.0, p) for p in []]
    pts_geysers = []
    cases = set()
    rr = np.random.RandomState(77)
    for (x0, y0, x1, y1, w, s) in rs.seg:
        # un geyser au plus par case de 7 × 4 tuiles : l'additif sature vite en aplat blanc
        case = (int(x0 / 7.0), int(y0 / 4.0))
        if s > 14.0 and case not in cases and rr.rand() < 0.5:
            cases.add(case)
            pts_geysers.append((x0, y0, s / V, w, int(rr.randint(1, 5)), rr.uniform(0.7, 1.3)))
    # ======= le temps
    T = [-2.0, -0.6, 0.12, 0.65, 1.3, 2.0, 3.1, 6.0]
    plasma_k = [1.0, 1.5, 2.0, 1.8, 1.6, 1.5, 1.1, 0.5]
    soleil_k = [1.0, 1.5, 2.0, 1.5, 1.3, 1.1, 0.9, 0.5]
    charge = [0.0, 0.7, 1.0, 0.85, 0.75, 0.65, 0.3, 0.0]
    legendes = ["1 · Roue au repos", "2 · Elle prend feu : arcs du soleil captif vers la jante", "3 · Elle mord le sol : le front part", "4 · 30 tuiles en 0,4 s, la ligne de tourelles saute",
                "5 · Les geysers sortent derrière le front", "6 · 90 tuiles, toute la fissure crache", "7 · Les geysers retombent, les ruines brûlent", "8 · Cicatrice : on voit où elle a frappé"]
    rim = []
    for s in (-1, 1):
        for k in range(36):
            th = math.tau * k / 36.0
            rim.append((th, s))
    rim_pts = [(ecran_ix((R_EXT + DENT) * math.cos(th), s * (W_J + 0.2), ZC + (R_EXT + DENT) * math.sin(th)), th) for th, s in rim]
    soleil = ecran_ix(0, 0, ZC)
    images = []
    sc_sol = sc.sol.copy()
    bruit_br = SC.fbm(sc.H, sc.W, 5, cell=48.0)
    for k, t in enumerate(T):
        front = t * V
        age = np.where(masque > 0, t - A2, -1.0)
        ouvert = (age >= 0).astype(np.float32)
        col = X.flou(ouvert, 0.7)
        chaleur = np.exp(-np.maximum(age, 0) / 1.5) * ouvert
        coeur = X.flou(ouvert, 2.6) ** 3
        chaleur_l = X.flou(chaleur, 0.8) * (0.5 + 0.5 * coeur)
        hal1 = X.flou(chaleur, 12.0) * 2.6
        hal2 = X.flou(chaleur, 44.0) * 4.0
        lip = X.flou(ouvert, 16.0)
        roussi = np.clip(X.flou(ouvert, 90.0) * 7.0, 0, 1) * (0.5 + 0.5 * bruit_br)

        def sol_fn(img, k=k):
            if t < 0.05:
                return
            # bourrelets soulevés (relief éclairé côté ouest), sol roussi autour
            img *= (1 - 0.68 * np.clip(roussi, 0, 1))[..., None]
            rel = np.roll(lip, (-2, -2), (0, 1)) - lip
            img += np.clip(rel * 2.4, 0, 0.35)[..., None] * np.array((0.55, 0.42, 0.3), np.float32)
            img *= (1 - np.clip(lip * 1.5, 0, 0.8))[..., None]
            X.over(img, (0.012, 0.008, 0.01), col)
            img += X.rampe(np.clip(chaleur_l, 0, 1), X.PAL_PLASMA) * col[..., None]
            X.add(img, (1.0, 0.1, 0.6), np.clip(hal1, 0, 0.9))
            X.add(img, (0.6, 0.05, 0.36), np.clip(hal2, 0, 0.3))
            # cratère de contact
            cr = lisse(9.0, 2.5, np.hypot(sc.X - gx, (sc.Y - gy) * 1.15))
            img *= (1 - 0.75 * cr)[..., None]

        # destructions : au passage du front, à moins de 8 tuiles de la fissure
        ents = []
        expl = []
        for e in ents0:
            d, ta = proche(e["pos"][0], e["pos"][1])
            if d < 8.5 and t > ta + 0.05:
                rui = ruine(e)
                if rui is not None:
                    ents.append(rui)
                    a = t - ta
                    expl.append((e["pos"][0], e["pos"][1], a, d))
            else:
                ents.append(e)

        def air_fn(img, k=k):
            cont = charge[k]
            # éclats projetés le long du front
            if 0.3 < t < 3.0:
                X.eclats(img, 400 + k, 110, gx + math.cos(D) * min(front, 92.0) * 0.55, gy + math.sin(D) * min(front, 92.0) * 0.55, min(44.0, max(6.0, front * 0.5)), PPT, 1.5, 4.5, haut=6.0)
            # panaches dans l'ordre nord → sud
            for (x0, y0, ta, w, sd, kk) in sorted(pts_geysers, key=lambda q: q[1]):
                a = t - ta
                if a <= 0.02:
                    continue
                h = 23.0 * kk * (0.6 + min(1.0, w)) * (a / 0.45 if a < 0.45 else math.exp(-(a - 0.45) / 1.1))
                if h < 1.2:
                    continue
                hp = int(round(h * PPT / 32)) * 32
                hp = max(32, hp)
                sp = X.panache(max(16, int(hp * 0.3)), hp, sd, X.PAL_PLASMA if a < 1.3 else X.PAL_FEU)
                X.pose_add(img, sp, x0 * PPT, (y0 + 0.2) * PPT, 0.34 + 0.24 * math.exp(-a / 1.3))
            for (x0, y0, a, d) in sorted(expl, key=lambda q: q[1]):
                # vraie explosion vanilla au passage, puis feu
                i = int(a * 42)
                if i < 15 and int(x0 * 3 + y0 * 7) % 3:
                    continue
                if i < 15:
                    ex = X.explosion_massive(i, PPT)
                    X.pose_over(img, ex, x0 * PPT - 22 * PPT / 32.0, (y0 - 45.0 / 32.0 * 2) * PPT)
                elif a < 3.2:
                    hf = 64 if int(x0 * 3 + y0) % 3 else 96
                    X.pose_add(img, X.panache(int(hf * 0.5), hf, int(x0) % 4 + 11, X.PAL_FEU), x0 * PPT, y0 * PPT, 0.9)
            # fumées noires tardives
            if t > 1.0:
                for (x0, y0, a, d) in sorted(expl, key=lambda q: q[1]):
                    if int(x0 * 5 + y0 * 11) % 9:
                        continue
                    hf = int(min(1.0, (a - 0.5) / 2.5) * 512) if a > 0.5 else 0
                    if hf > 96:
                        hf = hf // 32 * 32
                        fm = X.fumee(int(hf * 0.75), hf, int(x0) % 5 + 31)
                        X.pose_over(img, fm, x0 * PPT + hf * 0.2, y0 * PPT - hf * 0.48)
            # roue de feu : les 18 tuyères crachent
            flammes_tuyeres(img, gx, gy, max(0.3, cont), k, PPT)
            # arcs du soleil vers la jante
            if cont > 0.2:
                a0 = ((gx + soleil[0]) * PPT, (gy + soleil[1]) * PPT)
                n = int(3 + 6 * cont)
                for j in range(n):
                    th = math.tau * j / n + k * 0.7 + j * 0.31
                    q = ecran_ix(21.3 * math.cos(th), 0.0, ZC + 21.3 * math.sin(th))
                    b0 = ((gx + q[0]) * PPT, (gy + q[1]) * PPT)
                    s0 = ecran_ix(6.4 * math.cos(th), 0.0, ZC + 6.4 * math.sin(th))
                    a1 = ((gx + s0[0]) * PPT, (gy + s0[1]) * PPT)
                    X.arc_electrique(img, a1, b0, 900 + k * 37 + j, (1.0, 0.12, 0.66), epais=3 if j % 3 == 0 else 2, halo=7.0, k=0.55 + 0.5 * cont)
            # éclair d'impact
            if abs(t - 0.12) < 0.05:
                d = np.hypot(sc.X - gx, (sc.Y - gy) * 1.0)
                X.add(img, (1.0, 0.82, 0.9), np.clip(1.5 * np.exp(-(d / 7.0) ** 2), 0, 1))
                X.add(img, (1.0, 0.2, 0.6), np.clip(0.7 * np.exp(-(d / 20.0) ** 2), 0, 0.8))

        img = sc.rendu(ents, [{"pos": (gx, gy), "layers": g, "ordre": ("main", "glow_plasma", "glow_soleil", "glow_hublots", "glow_feu"),
                               "mult": {"glow_plasma": plasma_k[k], "glow_soleil": soleil_k[k], "glow_hublots": 1.0, "glow_feu": 1.0 + charge[k]}}], sol_fn=sol_fn, air_fn=air_fn)
        images.append(np.asarray(SC.to_im(img).resize((sc.W // 2, sc.H // 2), Image.LANCZOS), np.float32) / 255.0)
        if k == 5:
            SC.to_im(img).save(os.path.join(dest, "ixion-effet-1-pic-z1.png"), optimize=True)
        print("ixion image", k, flush=True)
    return X.planche(images, legendes, "IXION · effet 1, « La Tranchée » : 8 images dans le temps, 16 px/tuile, sur une vraie base vanilla", os.path.join(dest, "ixion-effet-1.png"), cols=4, k=1.0)


_TOUR = {}


def flammes_tuyeres(img, gx, gy, cont, k, ppt):
    """Flamme orange de chaque tuyère (1 crampon sur 4 des 2 rails). cont : 0,3 au repos, 1 en charge. En jeu : 18 `draw_animation` liées à l'entité."""
    points = []
    for s in (-1, 1):
        for n in range(0, 36, 4):
            th = math.tau * n / 36.0 + s * math.tau / 36.0 * 0.25
            a = s * (W_J - 0.525)
            points.append((ecran_ix(30.1 * math.cos(th), a, ZC + 30.1 * math.sin(th)), th, n + (s + 1) * 18))
    for (o, th, sem) in sorted(points, key=lambda q: q[0][1]):
        alea = (math.sin(sem * 12.9898 + k * 78.233) * 43758.5453) % 1.0
        hp = int((130 + 430 * cont) * (0.72 + 0.28 * alea) * cont ** 0.35 * ppt / 32.0)
        hp = max(48, hp // 16 * 16)
        wp = int(hp * 0.46)
        # le rayon vu à l'écran, pas l'angle dans le plan de la roue : la flamme sort de sa tuyère
        dx, dy = math.cos(th) * math.cos(PSI), -math.sin(th) * COS - math.cos(th) * math.sin(PSI) * COS
        n_ = math.hypot(dx, dy) or 1.0
        ang = int(round(math.degrees(math.atan2(dx, -dy)) / 15.0)) % 24
        fl = panache_tourne(wp, hp, (sem % 3) + 41, ang)
        pose_add_centre(img, fl, (gx + o[0]) * ppt + dx / n_ * hp * 0.43, (gy + o[1]) * ppt + dy / n_ * hp * 0.43, 0.9)



def panache_tourne(wp, hp, seed, ang):
    cle = (wp, hp, seed, ang)
    if cle in _TOUR:
        return _TOUR[cle]
    sp = X.panache(wp, hp, seed, X.PAL_FEU)
    ims = []
    for c in range(3):
        ims.append(np.asarray(Image.fromarray(sp[..., c], "F").rotate(-ang * 15.0, Image.BILINEAR, expand=True), np.float32))
    a = np.stack(ims, -1)
    _TOUR[cle] = a
    return a


def pose_add_centre(img, spr, cx, cy, k=1.0):
    h, w = spr.shape[:2]
    X.pose_add(img, spr, cx, cy + h / 2.0, k)


# ==================================================================================================== BOURDON
Z_LEVRE = 33.0
ZP = Z_LEVRE + 7.0


def balance(layer, alpha, ppt=PPT):
    """Le battant oscille autour du pivot (0, 0, ZP) dans le plan x-z : rotation 2D corrigée de la projection (z vu à 0,7071)."""
    im = layer["img"]
    h, w = im.shape[:2]
    pivx = (-layer["shift"][0]) * ppt + w / 2.0
    pivy = (-(ZP * COS) - layer["shift"][1]) * ppt + h / 2.0
    m = int(max(h, w) * 0.5)
    H2, W2 = h + 2 * m, w + 2 * m
    ca, sa = math.cos(alpha), math.sin(alpha)
    # coordonnées monde : x, zv = (v / 0,7071) ; sortie → entrée (inverse de la rotation)
    a00, a01, a10, a11 = ca, -sa * COS, sa / COS, ca
    px, py = pivx + m, pivy + m
    coefs = (a00, a01, px - a00 * px - a01 * py - m, a10, a11, py - a10 * px - a11 * py - m)
    ch = []
    pm = im.copy()
    pm[..., :3] *= pm[..., 3:4]
    for c in range(4):
        ch.append(np.asarray(Image.fromarray(pm[..., c], "F").transform((W2, H2), Image.AFFINE, coefs, Image.BILINEAR), np.float32))
    out = np.stack(ch, -1)
    al = np.clip(out[..., 3:4], 1e-4, 1)
    out[..., :3] = np.clip(out[..., :3] / al, 0, 1)
    return {"img": out, "shift": layer["shift"], "kind": layer["kind"]}


def effet_bourdon(src, dest):
    W_t, H_t, gx, gy = 140, 104, 70, 66
    sc = SC.Scene(W_t, H_t, PPT, seed=31)
    g0 = SC.geant(src, "bourdon", PPT)
    bat = SC.geant(src, "battant", PPT)

    def trou(x, y):
        return math.hypot(x - gx, y - gy) < 6.0

    L = base_rangees(8, 136, 8, 104, 5, trou)
    for x in range(10, 132):
        if not trou(x, 60):
            pass
    L += [("raffinerie", 26, 36), ("raffinerie", 34, 36), ("radar", 112, 90), ("radar", 118, 90)]
    ents0 = materialise(L)
    rs = X.Reseau(1515)
    for i in range(18):
        th = math.tau * i / 18.0 + 0.1 * math.sin(i * 2.7)
        rs.trace((gx + 5.0 * math.cos(th), gy + 5.0 * math.sin(th)), th, 46.0 + 22.0 * (i % 3) / 2.0, 5.0, 0.9 if i % 3 == 0 else 0.5, wob=0.55, pas=1.25, branches=0.07)
    A = rs.rasterise(W_t, H_t, PPT)
    masque = (A < 1e6).astype(np.float32)
    A2 = np.where(A < 1e6, A, 0.0)
    r = np.hypot(sc.X - gx, sc.Y - gy)
    phi = np.arctan2(sc.Y - gy, sc.X - gx)
    # stries radiales du sol balayé
    rng = np.random.RandomState(9)
    br = rng.rand(1440).astype(np.float32)
    br = np.convolve(np.r_[br[-8:], br, br[:8]], np.ones(5) / 5.0, "same")[8:-8]
    stries = np.interp((phi + math.pi) / math.tau * 1440.0, np.arange(1440), br).astype(np.float32)
    stries = np.clip((stries - 0.3) * 2.8, 0, 1)
    bruit = SC.fbm(sc.H, sc.W, 77, cell=40.0)
    bruit2 = SC.fbm(sc.H, sc.W, 78, cell=96.0, oct=6, persist=0.6)
    # le temps : rayon du premier front ; second front, plus faible
    R1 = [0.0, 0.0, 5.0, 17.0, 31.0, 46.0, 66.0, 90.0]
    R2 = [0.0, 0.0, 0.0, 4.0, 13.0, 26.0, 44.0, 0.0]
    BAL = [0.0, -21.0, 13.0, -7.0, 4.0, -2.0, 1.0, 0.0]
    VIT = [1.0, 1.5, 3.2, 2.2, 1.7, 1.3, 1.0, 0.8]
    CRI = [1.0, 1.9, 3.6, 2.4, 1.6, 1.2, 1.0, 1.0]
    legendes = ["1 · Elle flotte au-dessus de la base", "2 · Le battant recule, les vitraux montent", "3 · Il frappe : le sol part autour de la cloche", "4 · 17 tuiles : tout ce qui est sous elle tombe",
                "5 · 31 tuiles : l'onde lève un mur de poussière", "6 · 46 tuiles : elle couche la base, le sol se fend", "7 · 66 tuiles : elle sort de l'écran, seconde onde", "8 · Le silence : une étoile dans le sol"]
    images = []
    zr = 45.0
    motes = np.random.RandomState(5)
    mx = motes.uniform(gx - 26, gx + 26, 520)
    my = motes.uniform(gy - 30, gy + 18, 520)
    for k in range(8):
        R = R1[k]
        Rb = R2[k]
        ouvert = (A2 <= (R if k < 7 else 90.0)).astype(np.float32) * masque
        ouvert = X.flou(ouvert, 0.7)
        age = np.maximum(R - A2, 0.0) if k < 7 else np.full_like(A2, 200.0)
        chaleur = ouvert * np.exp(-age / (17.0 if k < 7 else 60.0))
        coeur = X.flou(ouvert, 2.0) ** 2
        hal = X.flou(chaleur, 9.0) * 1.9
        hal2 = X.flou(chaleur, 36.0) * 2.4
        balaye = (lisse(R + 1.0, R - 3.0, r) if R > 0 else np.zeros_like(r)) * lisse(74.0, 40.0, r)

        def sol_fn(img, k=k):
            if R <= 0:
                return
            # sol balayé : assombri, strié dans le sens de l'onde
            img *= (1 - balaye[..., None] * (0.16 + 0.34 * stries[..., None] * (0.35 + 0.65 * bruit[..., None])))
            # bourrelet de terre poussé devant le front
            bour = np.exp(-((r - R + 0.8) / 2.6) ** 2) * (0.6 + 0.8 * bruit) * (1.0 if k < 7 else 0.0)
            img += np.clip(bour * 0.34, 0, 0.5)[..., None] * np.array((0.8, 0.62, 0.42), np.float32)
            rel = np.roll(X.flou(ouvert, 3.0), (-2, -2), (0, 1)) - X.flou(ouvert, 3.0)
            img += np.clip(rel * 2.5, 0, 0.3)[..., None] * np.array((0.6, 0.5, 0.36), np.float32)
            X.over(img, (0.012, 0.009, 0.006), ouvert)
            img += X.rampe(np.clip(chaleur * (0.45 + 0.55 * coeur), 0, 1), X.PAL_OR) * ouvert[..., None]
            X.add(img, (1.0, 0.72, 0.28), np.clip(hal, 0, 0.8))
            X.add(img, (0.65, 0.4, 0.12), np.clip(hal2, 0, 0.25))
            cr = lisse(10.0, 3.0, r)
            img *= (1 - 0.5 * cr)[..., None]

        ents, expl = [], []
        for e in ents0:
            d = math.hypot(e["pos"][0] - gx, e["pos"][1] - gy)
            if (R > d + 1.5 or k == 7) and d < zr:
                ru = ruine(e)
                if ru is not None:
                    ents.append(ru)
                    expl.append((e["pos"][0], e["pos"][1], (R - d) / 18.0 if k < 7 else 9.0, d))
            else:
                ents.append(e)

        def air_fn(img, k=k):
            # flammes et explosions sur les ruines
            for (x0, y0, a, d) in sorted(expl, key=lambda q: q[1]):
                sel = int(x0 * 2 + y0 * 5) % 3
                if a < 0.36:
                    if sel == 0:
                        i = int(a * 42)
                        X.pose_over(img, X.explosion_massive(min(14, i), PPT), x0 * PPT - 22, (y0 - 2.8) * PPT)
                elif a < 6:
                    if sel < 2:
                        hf = 64 if sel else 96
                        X.pose_add(img, X.panache(int(hf * 0.5), hf, int(x0) % 4 + 11, X.PAL_FEU), x0 * PPT, y0 * PPT, 0.85)
                if a > 1.0 and int(x0 * 5 + y0 * 11) % 9 == 0:
                    hf = int(min(1.0, (a - 1.0) / 2.5) * 448) // 32 * 32
                    if hf >= 96:
                        X.pose_over(img, X.fumee(int(hf * 0.75), hf, int(x0) % 5 + 31), x0 * PPT + hf * 0.2, y0 * PPT - hf * 0.48)
            # mur de poussière de l'onde : anneaux empilés (en jeu : 1 feuille, cf. FAISABILITE)
            for (Rr, kk) in ((R, 1.0), (Rb, 0.3)):
                if 0 < Rr < 85 and k < 7:
                    ampl = kk * (1.0 if Rr < 60 else max(0.25, 1.0 - (Rr - 60) / 30.0))
                    Hw = 4.0 + Rr * 0.14
                    q = 4
                    pet = (sc.H // q, sc.W // q)
                    ys = (np.arange(pet[0]) + 0.5) * q / PPT
                    xs = (np.arange(pet[1]) + 0.5) * q / PPT
                    Xp, Yp = np.meshgrid(xs, ys)
                    a_p = np.zeros(pet, np.float32)
                    cr = np.zeros(pet, np.float32)
                    N = 16
                    for j in range(N):
                        dy = Hw * j / float(N)
                        rj = np.hypot(Xp - gx, Yp + dy - gy)
                        env = (1 - j / float(N)) ** 1.1
                        a_p += np.exp(-((rj - Rr) / 2.1) ** 2) * env * (1.0 / N) * 5.4
                        if j < 3:
                            cr += np.exp(-((rj - Rr) / 0.75) ** 2) * 0.7
                    up = lambda z: np.asarray(Image.fromarray(z.astype(np.float32), "F").resize((sc.W, sc.H), Image.BICUBIC), np.float32)
                    a_h = up(a_p)
                    tb = bruit2 ** 1.6
                    al = np.clip(a_h * (0.25 + 1.5 * tb), 0, 1) * ampl
                    col = np.array((0.6, 0.47, 0.33), np.float32) * (0.6 + 0.7 * bruit[..., None])
                    al3 = (al * 0.85)[..., None]
                    img[:] = col * al3 + img * (1 - al3)
                    X.add(img, (1.0, 0.8, 0.42), np.clip(up(cr) * ampl * (0.12 + 1.15 * tb), 0, 0.9))
            # éclats dans l'onde
            if 0 < R < 70 and k < 7:
                X.eclats(img, 800 + k, 420, gx, gy, R, PPT, 1.5, 5.0, haut=6.0)

        def sous_geant(img, k=k):
            # anneaux dans l'air, autour de la lèvre (le son)
            cy = gy - Z_LEVRE * COS
            if k in (2, 3, 4, 5):
                for j, rr in enumerate(((k - 1) * 9.0 + 12, (k - 1) * 9.0 + 3.0)):
                    d = np.hypot(sc.X - gx, (sc.Y - cy) / COS)
                    X.add(img, (1.0, 0.86, 0.55), np.clip(np.exp(-((d - rr) / 0.5) ** 2) * (0.9 - 0.15 * k - 0.25 * j) * (0.6 + 0.6 * bruit), 0, 1))
            # chute de l'éclat sous la cloche
            if k >= 1:
                d = np.hypot(sc.X - gx, sc.Y - gy)
                X.add(img, (1.0, 0.82, 0.45), np.clip(np.exp(-(d / 11.0) ** 2) * (0.1 if k == 1 else 0.55 if k == 2 else 0.28 / (k - 1)), 0, 0.7))

        lay = dict(g0)
        lay["battant_main"] = balance(bat["main"], math.radians(BAL[k]))
        if "glow_battant" in bat:
            lay["battant_glow"] = balance(bat["glow_battant"], math.radians(BAL[k]))

        def sous_tout(img, k=k):
            air_fn(img)
            sous_geant(img)

        def apres(img, k=k):
            # éclair de frappe à la lèvre, là où le battant touche
            if k == 2:
                px_, py_ = gx + 11.5, gy - Z_LEVRE * COS - 1.0
                d = np.hypot(sc.X - px_, sc.Y - py_)
                X.add(img, (1.0, 0.93, 0.7), np.clip(1.2 * np.exp(-(d / 4.0) ** 2) + 0.35 * np.exp(-(d / 12.0) ** 2), 0, 1))
            # paillettes d'or qui retombent
            if k >= 5:
                ppx = (mx * PPT).astype(int)
                ppy = ((my + (k - 5) * 9.0) * PPT).astype(int)
                ok = (ppx > 1) & (ppx < sc.W - 2) & (ppy > 1) & (ppy < sc.H - 2)
                for dx, dy, v in ((0, 0, 0.9), (1, 0, 0.5), (0, 1, 0.5), (-1, 0, 0.3), (0, -1, 0.3)):
                    img[ppy[ok] + dy, ppx[ok] + dx] = np.clip(img[ppy[ok] + dy, ppx[ok] + dx] + np.array((1.0, 0.86, 0.5), np.float32) * v, 0, 1)

        img = sc.rendu(ents, [{"pos": (gx, gy), "layers": lay, "ordre": ("battant_main", "battant_glow", "main", "glow_vitrail", "glow_cristal"),
                               "mult": {"glow_vitrail": VIT[k], "glow_cristal": CRI[k], "battant_glow": VIT[k]}}], sol_fn=sol_fn, sous_geant=sous_tout, air_fn=apres)
        images.append(np.asarray(SC.to_im(img).resize((sc.W // 2, sc.H // 2), Image.LANCZOS), np.float32) / 255.0)
        if k == 5:
            SC.to_im(img).save(os.path.join(dest, "bourdon-effet-1-pic-z1.png"), optimize=True)
        print("bourdon image", k, flush=True)
    return X.planche(images, legendes, "BOURDON · effet 1, « Le Glas » : 8 images dans le temps, 16 px/tuile, sur une vraie base vanilla", os.path.join(dest, "bourdon-effet-1.png"), cols=4, k=1.0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--qui", default="ixion,bourdon")
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    if "ixion" in a.qui:
        print(effet_ixion(a.src, a.dest), flush=True)
    if "bourdon" in a.qui:
        print(effet_bourdon(a.src, a.dest), flush=True)


if __name__ == "__main__":
    main()
