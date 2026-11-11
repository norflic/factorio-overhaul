"""PLANCHES D'EFFETS de la famille (lot EXP2, 1/11) : un instant par image, sur une vraie base vanilla. Mêmes règles que effets.py : rien qu'un effet de jeu ne saurait faire
(additif sRGB, décalques, vraies explosions vanilla, restes vanilla), ni flou global ni distorsion.

    py -3.9 tools/render/pieces/experimentaux/effets2.py --src <sprites> --dest <dossier> --qui cairn,stylet,…
"""
import argparse
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import effets as EF  # noqa: E402
import fx as X  # noqa: E402
import scene as SC  # noqa: E402

PPT = 32
COS = math.cos(math.radians(45.0))
PAL_BLEU = [(0.0, (0.0, 0.0, 0.0)), (0.3, (0.03, 0.14, 0.42)), (0.6, (0.14, 0.46, 1.0)), (0.85, (0.56, 0.84, 1.0)), (1.0, (0.96, 1.0, 1.0))]
PAL_VERT = [(0.0, (0.0, 0.0, 0.0)), (0.3, (0.04, 0.3, 0.02)), (0.6, (0.3, 0.9, 0.08)), (0.85, (0.72, 1.0, 0.4)), (1.0, (0.97, 1.0, 0.82))]
PAL_VIOLET = [(0.0, (0.0, 0.0, 0.0)), (0.3, (0.2, 0.03, 0.4)), (0.6, (0.6, 0.16, 1.0)), (0.85, (0.88, 0.6, 1.0)), (1.0, (1.0, 0.95, 1.0))]


def couches(src, nom, ppt=PPT):
    g = SC.geant(src, nom, ppt)
    return g, ["main"] + sorted(k for k in g if k.startswith("glow"))


def rendu_geant(g, o, pos, mult=None, ombre=True):
    return {"pos": pos, "layers": g, "ordre": o, "mult": mult or {}, "ombre": ombre}


def reduire(sc, img, k=0.5):
    im = SC.to_im(img)
    return np.asarray(im.resize((int(sc.W * k), int(sc.H * k)), Image.LANCZOS), np.float32) / 255.0


def fusees(img, seed, x0, y0, x1, y1, k=1.0):
    """Paillettes additives sur un segment, mouvement d'ensemble."""
    r = np.random.RandomState(seed)
    H, W = img.shape[:2]
    for i in range(160):
        t = r.rand()
        x = int((x0 + (x1 - x0) * t + r.normal(0, 1.2)) * PPT)
        y = int((y0 + (y1 - y0) * t + r.normal(0, 1.2)) * PPT)
        if 2 < x < W - 3 and 2 < y < H - 3:
            img[y, x] = np.clip(img[y, x] + np.array((1.0, 0.95, 0.8), np.float32) * k, 0, 1)
            img[y + 1, x] = np.clip(img[y + 1, x] + np.array((1.0, 0.8, 0.5), np.float32) * k * 0.5, 0, 1)


def croix_visee(img, x, y, ray, col, k=1.0):
    """Marque de visée au sol (en jeu : `draw_sprite` en `ground-patch`, ou `draw_circle`)."""
    pil = Image.new("L", (int(ray * 4), int(ray * 4)), 0)
    d = ImageDraw.Draw(pil)
    c = ray * 2
    d.ellipse((c - ray, c - ray * 0.92, c + ray, c + ray * 0.92), outline=255, width=3)
    for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        d.line((c + dx * ray * 0.72, c + dy * ray * 0.72, c + dx * ray * 1.32, c + dy * ray * 1.32), fill=255, width=3)
    a = np.asarray(pil, np.float32) / 255.0
    x0, y0 = int(x - c), int(y - c)
    h, w = a.shape
    if x0 < 0 or y0 < 0 or x0 + w >= img.shape[1] or y0 + h >= img.shape[0]:
        return
    img[y0:y0 + h, x0:x0 + w] = np.clip(img[y0:y0 + h, x0:x0 + w] + np.asarray(col, np.float32) * (a[..., None] * k), 0, 1)


def ruines_et_feux(ents0, condition, seed=1):
    """condition(e) → âge du dégât (> 0 : détruit). Rend (ents, feux)."""
    ents, feux = [], []
    for e in ents0:
        a = condition(e)
        if a > 0:
            ru = EF.ruine(e)
            if ru is not None:
                ents.append(ru)
                feux.append((e["pos"][0], e["pos"][1], a))
        else:
            ents.append(e)
    return ents, feux


def dessine_feux(img, feux, ppt=PPT, tous=False):
    for (x0, y0, a) in sorted(feux, key=lambda q: q[1]):
        if a < 0.36:
            if tous or int(x0 * 3 + y0 * 7) % 3 == 0:
                i = int(a * 42)
                X.pose_over(img, X.explosion_massive(min(14, i), ppt), x0 * ppt - 22, (y0 - 2.8) * ppt)
        elif a < 4.0:
            if int(x0 * 2 + y0 * 5) % 3 < 2:
                hf = 64 if int(x0) % 2 else 96
                X.pose_add(img, X.panache(int(hf * 0.5), hf, int(x0) % 4 + 11, X.PAL_FEU), x0 * ppt, y0 * ppt, 0.85)
        if a > 0.6 and int(x0 * 5 + y0 * 11) % 9 == 0:
            hf = int(min(1.0, (a - 0.6) / 2.5) * 448) // 32 * 32
            if hf >= 96:
                X.pose_over(img, X.fumee(int(hf * 0.75), hf, int(x0) % 5 + 31), x0 * ppt + hf * 0.2, y0 * ppt - hf * 0.48)


def base(x0, x1, y0, y1, seed, trou=None, tourelles=None):
    L = EF.base_rangees(x0, x1, y0, y1, seed, trou)
    return L


def ecrit(images, legendes, titre, dest, cols):
    size = X.planche(images, legendes, titre, dest, cols=cols, k=1.0)
    print(os.path.basename(dest), size, flush=True)


# ======================================================================================================= CAIRN
def cairn(src, dest):
    W, H, gx, gy = 112, 84, 56, 58
    sc = SC.Scene(W, H, PPT, seed=41)
    g, o = couches(src, "cairn")
    L = base(6, 108, 8, 84, 7, lambda x, y: math.hypot(x - gx, y - gy) < 7)
    ents0 = EF.materialise(L)
    r = np.random.RandomState(42)
    cibles = [e for e in ents0 if e["nom"] in EF.RUINE and 10 < math.hypot(e["pos"][0] - gx, e["pos"][1] - gy) < 50]
    r.shuffle(cibles)
    cibles = cibles[:42]
    idx = {id(e): i for i, e in enumerate(cibles)}
    # bouts d'antennes (repris de cairn.GALETS)
    GAL = [((0.0, 0.0, 10.5), 6.5), ((3.6, 0.8, 21.5), 13.0), ((-3.2, -0.6, 33.5), 10.5), ((3.4, 0.5, 44.0), 7.6)]

    def bout(i, e):
        ex_, ey_ = e["pos"][0] - gx, e["pos"][1] - gy
        dd = math.hypot(ex_, ey_)
        # galet bas pour une cible proche, haut pour une cible lointaine
        c, a = GAL[min(3, int(dd / 14.0))]
        th = math.atan2(-ey_ / COS, ex_)
        L_ = a * 1.5
        wx, wy, wz = c[0] + L_ * math.cos(th), c[1] + L_ * math.sin(th), c[2] + 2.0
        return (gx + wx) * PPT, (gy - (wy + wz) * COS) * PPT
    dist = np.hypot(sc.X - gx, sc.Y - gy)
    ang = np.arctan2(sc.Y - gy, sc.X - gx)
    legendes = ["1 · Le Cairn au-dessus de la base", "2 · Le balayage : un quart de tour de radar au sol", "3 · Tout ce qu'il a vu est marqué", "4 · Chaque antenne tire sur sa marque", "5 · Seconde salve : ça saute partout", "6 · Il reste ce qu'il n'a pas vu"]
    images = []
    for k in range(6):
        def condition(e):
            i = idx.get(id(e))
            if i is None:
                return 0
            if k == 4 and i % 2 == 0:
                return 0.14
            if k == 5:
                return 3.0 + (i % 3)
            if k == 4:
                return 0.5
            return 0
        ents, feux = ruines_et_feux(ents0, condition)

        def sol(img, k=k):
            if k in (1, 2):
                # secteur de balayage, sillage qui s'estompe
                phi = (ang - (0.6 + k * 2.4)) % math.tau
                sillage = np.exp(-phi / 1.3) * (dist < 52) * (0.35 + 0.65 * (dist % 8 < 0.25))
                X.add(img, (0.1, 0.42, 1.0), np.clip(sillage * 0.42, 0, 0.7))
                bord = np.exp(-(phi / 0.03) ** 2) * (dist < 52)
                X.add(img, (0.6, 0.85, 1.0), np.clip(bord, 0, 1))
                for rr in (13, 26, 39, 52):
                    X.add(img, (0.14, 0.46, 1.0), np.clip(np.exp(-((dist - rr) / 0.14) ** 2) * 0.5, 0, 0.6))

        def air(img, k=k):
            dessine_feux(img, feux, tous=True)
            if k in (2, 3):
                for e in cibles:
                    croix_visee(img, e["pos"][0] * PPT, e["pos"][1] * PPT, 42, (0.45, 0.8, 1.0), 1.0)
            if k in (3, 4):
                for i, e in enumerate(cibles):
                    if k == 3 and i % 2:
                        continue
                    if k == 4 and i % 2 == 0:
                        continue
                    X.arc_electrique(img, bout(i, e), (e["pos"][0] * PPT, (e["pos"][1] - 0.5) * PPT), 3000 + i + k * 91, (0.16, 0.5, 1.0), epais=2, halo=5.0, k=0.9, wob=0.035)
        m = {"glow_bleu": [1.0, 1.5, 1.8, 2.4, 2.4, 0.8][k]}
        img = sc.rendu(ents, [rendu_geant(g, o, (gx, gy), m)], sol_fn=sol, air_fn=air)
        images.append(reduire(sc, img))
        print("cairn", k, flush=True)
    ecrit(images, legendes, "CAIRN · effet « Le Balayage » : 6 instants, 16 px/tuile", os.path.join(dest, "cairn-effet-1.png"), 3)


# ======================================================================================================= STYLET
def stylet(src, dest):
    W, H, gx, gy = 112, 84, 46, 58
    sc = SC.Scene(W, H, PPT, seed=43)
    g, o = couches(src, "stylet")
    L = base(10, 110, 10, 84, 9, lambda x, y: math.hypot(x - gx, y - gy) < 3)
    ents0 = EF.materialise(L)
    # circuit : traces à angle droit depuis la pointe, nœuds
    r = np.random.RandomState(44)
    rs = X.Reseau(45)
    noeuds = []

    def trace(x, y, d, s, n, prof):
        for i in range(n):
            L_ = float(r.randint(3, 7)) * 3.0
            dx, dy = {0: (1, 0), 1: (0, 1), 2: (-1, 0), 3: (0, -1)}[d]
            nx, ny = x + dx * L_, y + dy * L_
            if not (1 < nx < W - 1 and 1 < ny < H - 1):
                return
            pas = 1.0
            for j in range(int(L_)):
                rs.seg.append((x + dx * j, y + dy * j, x + dx * (j + 1), y + dy * (j + 1), 0.42 - 0.08 * prof, s + j))
            x, y = nx, ny
            s += L_
            noeuds.append((x, y, s, prof))
            if prof < 3 and r.rand() < 0.55:
                trace(x, y, (d + (1 if r.rand() < 0.5 else 3)) % 4, s, max(1, n - i - 1), prof + 1)
            d = (d + (1 if r.rand() < 0.5 else 3)) % 4 if r.rand() < 0.65 else d
    for d0 in range(4):
        trace(gx, gy, d0, 0.0, 5, 0)
        trace(gx, gy, d0, 0.0, 4, 1)
    A = rs.rasterise(W, H, PPT)
    masque = (A < 1e6).astype(np.float32)
    A2 = np.where(A < 1e6, A, 0.0)
    legendes = ["1 · Le Stylet plane, pointe en bas", "2 · Il touche : la première ligne part", "3 · Il écrit : le circuit court sous la base", "4 · Chaque nœud s'allume", "5 · Ils tirent vers le haut : le circuit saute", "6 · L'écriture reste au sol"]
    FRONT = [0.0, 8.0, 48.0, 90.0, 90.0, 200.0]
    PIL = [0.0, 0.0, 0.0, 0.0, 1.0, 0.0]
    images = []
    for k in range(6):
        Lf = FRONT[k]
        ouvert = X.flou((A2 <= Lf).astype(np.float32) * masque, 0.7) if Lf > 0 else np.zeros_like(A2)
        age = np.maximum(Lf - A2, 0)
        chaleur = ouvert * (np.exp(-age / 60.0) if k < 5 else 0.1)
        hal = X.flou(chaleur, 9.0) * 1.7
        sites = [(x, y) for (x, y, s, p) in noeuds if s <= Lf]

        def condition(e):
            if k < 4:
                return 0
            for (x, y) in sites:
                if abs(e["pos"][0] - x) < 5.5 and abs(e["pos"][1] - y) < 5.5:
                    return 0.14 if k == 4 else 2.5
            return 0
        ents, feux = ruines_et_feux(ents0, condition)

        def sol(img, k=k):
            if Lf <= 0:
                return
            X.over(img, (0.012, 0.016, 0.03), ouvert)
            img += X.rampe(np.clip(chaleur, 0, 1), PAL_BLEU) * ouvert[..., None]
            X.add(img, (0.1, 0.42, 1.0), np.clip(hal, 0, 0.7))
            # trou d'impact
            d = np.hypot(sc.X - gx, sc.Y - gy)
            img *= (1 - 0.7 * EF.lisse(6.0, 1.5, d))[..., None]

        def air(img, k=k):
            dessine_feux(img, feux)
            if k >= 3:
                for (x, y) in sites:
                    v = 0.9 if k < 5 else 0.3
                    d = 6
                    px, py = int(x * PPT), int(y * PPT)
                    if d < px < img.shape[1] - d and d < py < img.shape[0] - d:
                        img[py - d:py + d, px - d:px + d] = np.clip(img[py - d:py + d, px - d:px + d] + np.array((0.8, 0.92, 1.0), np.float32) * v, 0, 1)
            if k == 4:
                for j, (x, y) in enumerate(sorted(sites, key=lambda q: q[1])):
                    hp = 192 + (j * 53) % 256
                    hp = hp // 16 * 16
                    X.pose_add(img, X.panache(int(hp * 0.22), hp, j % 4 + 51, PAL_BLEU), x * PPT, y * PPT, 0.85)
            if k == 1:
                d = np.hypot(sc.X - gx, sc.Y - gy)
                X.add(img, (0.7, 0.88, 1.0), np.clip(1.2 * np.exp(-(d / 4.5) ** 2), 0, 1))
        m = {"glow_ligne": [1.0, 1.3, 1.6, 1.9, 2.3, 0.7][k], "glow_jets": [1.0, 1.4, 1.4, 1.4, 1.8, 0.8][k]}
        img = sc.rendu(ents, [rendu_geant(g, o, (gx, gy), m)], sol_fn=sol, air_fn=air)
        images.append(reduire(sc, img))
        print("stylet", k, flush=True)
    ecrit(images, legendes, "STYLET · effet « L'Écriture » : 6 instants, 16 px/tuile", os.path.join(dest, "stylet-effet-1.png"), 3)


# ======================================================================================================= TROMBE
def trombe(src, dest):
    W, H, gx, gy = 112, 84, 56, 56
    sc = SC.Scene(W, H, PPT, seed=47)
    g, o = couches(src, "trombe")
    L = base(6, 108, 8, 84, 11, lambda x, y: math.hypot(x - gx, y - gy) < 7)
    ents0 = EF.materialise(L)
    d = np.hypot(sc.X - gx, sc.Y - gy)
    n1 = SC.fbm(sc.H, sc.W, 90, cell=56.0)
    n2 = SC.fbm(sc.H, sc.W, 91, cell=9.0, oct=4)
    rs = X.Reseau(92)
    for i in range(26):
        th = math.tau * i / 26.0 + 0.2 * math.sin(i)
        rs.trace((gx + 4 * math.cos(th), gy + 4 * math.sin(th)), th, 46.0, 4.0, 0.3, wob=0.7, pas=1.0, branches=0.14)
    A = rs.rasterise(W, H, PPT)
    masque = (A < 1e6).astype(np.float32)
    A2 = np.where(A < 1e6, A, 0.0)
    R_G = [0.0, 8.0, 21.0, 34.0, 44.0, 44.0]
    legendes = ["1 · La Trombe tourne", "2 · Le froid tombe : le sol blanchit", "3 · Le gel gagne, tout s'arrête", "4 · 34 tuiles : les machines sont prises", "5 · La glace éclate de l'intérieur", "6 · Plaine gelée, débris de glace"]
    images = []
    rng = np.random.RandomState(93)
    givres = []
    for e in ents0:
        givres.append(rng.rand())
    for k in range(6):
        R = R_G[k]
        gel = EF.lisse(R + 3.5, R - 7.0, d + (n1 - 0.5) * 11.0) if R > 0 else np.zeros_like(d)

        def condition(e):
            de = math.hypot(e["pos"][0] - gx, e["pos"][1] - gy)
            if k >= 4 and de < 40:
                return 0.14 if k == 4 else 9.0
            return 0
        ents, feux = ruines_et_feux(ents0, condition)
        # bâtiments gelés : teinte givre dans le rayon (en jeu : `active = false`, `draw_sprite` de givre par-dessus)
        ents2 = []
        for e in ents:
            de = math.hypot(e["pos"][0] - gx, e["pos"][1] - gy)
            if de < R:
                lay2 = []
                for l in e["layers"]:
                    if l["kind"] == "shadow":
                        lay2.append(l)
                        continue
                    i2 = l["img"].copy()
                    lum = i2[..., :3].mean(-1, keepdims=True)
                    i2[..., :3] = i2[..., :3] * 0.4 + (lum * 0.6 + 0.22) * np.array((0.86, 0.96, 1.0), np.float32)
                    lay2.append({"img": np.clip(i2, 0, 1), "shift": l["shift"], "kind": l["kind"]})
                ents2.append({"pos": e["pos"], "layers": lay2, "nom": e["nom"]})
            else:
                ents2.append(e)

        def sol(img, k=k):
            if R <= 0:
                return
            alpha = np.clip(gel * (0.52 + 0.55 * n2), 0, 0.93)
            col = np.array((0.82, 0.91, 0.97), np.float32) * (0.74 + 0.42 * n2[..., None])
            a3 = alpha[..., None]
            img[:] = col * a3 + img * (1 - a3)
            # cristaux de givre blancs : le réseau
            ouv = X.flou((A2 <= R * 1.05).astype(np.float32) * masque, 0.6)
            X.add(img, (0.26, 0.36, 0.42), np.clip(ouv * 0.9, 0, 0.9))
            hal = X.flou(ouv, 10.0) * 0.5
            X.add(img, (0.05, 0.3, 0.45), np.clip(hal, 0, 0.3))

        def au_sol(img, k=k):
            # pics de glace autour des machines prises (2D) : au sol, donc SOUS la tornade
            if k in (3, 4, 5):
                pil = Image.new("RGBA", (sc.W, sc.H), (0, 0, 0, 0))
                dr = ImageDraw.Draw(pil)
                rr2 = np.random.RandomState(300)
                for e in sorted(ents0, key=lambda q: q["pos"][1]):
                    de = math.hypot(e["pos"][0] - gx, e["pos"][1] - gy)
                    if de > min(R, 40) or e["nom"] not in EF.RUINE:
                        continue
                    for j in range(6):
                        x = (e["pos"][0] + rr2.uniform(-1.8, 1.8)) * PPT
                        y = (e["pos"][1] + rr2.uniform(-0.4, 1.6)) * PPT
                        h = rr2.uniform(30, 120) * (1.0 if k < 5 else 0.5)
                        w = rr2.uniform(7, 16)
                        inc = rr2.uniform(-0.3, 0.3) * h
                        dr.polygon([(x - w, y), (x + inc, y - h), (x, y + 3)], fill=(150, 205, 230, 235))
                        dr.polygon([(x + w, y), (x + inc, y - h), (x, y + 3)], fill=(205, 238, 250, 235))
                a = np.asarray(pil, np.float32) / 255.0
                img[:] = a[..., :3] * a[..., 3:4] + img * (1 - a[..., 3:4])
            dessine_feux(img, feux)
            if k == 4:
                X.eclats(img, 330, 700, gx, gy, 40, PPT, 2.0, 6.0, haut=8.0, col=(0.72, 0.86, 0.94))

        def air(img, k=k):
            # poudre glacée qui spirale autour de la tornade
            cy = gy
            rr = np.random.RandomState(200 + k)
            n = 1400 if 0 < k < 5 else 400
            for i in range(n):
                t = rr.rand()
                z = 3 + 50 * t
                ra = (2.0 + 21 * t ** 1.55) * rr.uniform(0.85, 1.35)
                a = rr.uniform(0, math.tau)
                x = gx + ra * math.cos(a)
                y = cy - (ra * math.sin(a) + z) * COS
                px, py = int(x * PPT), int(y * PPT)
                if 3 < px < img.shape[1] - 12 and 3 < py < img.shape[0] - 3:
                    L_ = int(rr.uniform(3, 12))
                    v = rr.uniform(0.35, 0.95)
                    img[py, px:px + L_] = np.clip(img[py, px:px + L_] + np.array((0.7, 0.92, 1.0), np.float32) * v, 0, 1)
        m = {"glow_cyan": [1.0, 1.6, 2.0, 2.2, 2.6, 0.9][k]}
        img = sc.rendu(ents2, [rendu_geant(g, o, (gx, gy), m)], sol_fn=sol, sous_geant=au_sol, air_fn=air)
        images.append(reduire(sc, img))
        print("trombe", k, flush=True)
    ecrit(images, legendes, "TROMBE · effet « Le Gel » : 6 instants, 16 px/tuile", os.path.join(dest, "trombe-effet-1.png"), 3)


# ======================================================================================================= TOURNESOL
def tournesol(src, dest):
    W, H, gx, gy = 124, 84, 44, 60
    sc = SC.Scene(W, H, PPT, seed=49)
    g, o = couches(src, "tournesol")
    L = base(58, 122, 26, 84, 13) + base(10, 56, 72, 84, 14)
    ents0 = EF.materialise(L)
    # foyer : tête + 15 × AXE
    ax = (-0.6, -0.33, 0.73)
    n = math.sqrt(sum(a * a for a in ax))
    ax = tuple(a / n for a in ax)
    fw = (ax[0] * 15, ax[1] * 15, 39.0 + ax[2] * 15)
    fx_, fy_ = gx + fw[0], gy - (fw[1] + fw[2]) * COS
    # trajet du point d'impact
    P0, P1 = (63.0, 73.0), (118.0, 48.0)
    T = [0.0, 0.0, 0.05, 0.38, 0.72, 1.0]
    ALL = [False, False, True, True, True, False]
    n_ = SC.fbm(sc.H, sc.W, 94, cell=30.0)
    ligne = Image.new("L", (sc.W, sc.H), 0)
    legendes = ["1 · Il regarde le soleil", "2 · Les pétales se calent : le foyer s'allume", "3 · Le trait touche le sol", "4 · Il trace : le sol fond sous lui", "5 · Rien ne l'arrête, sauf la nuit", "6 · Une ligne de verre, la nuit il dort"]
    images = []
    rr = np.random.RandomState(95)
    etoiles = []
    for i in range(70):
        u, v = 20.0 * math.sqrt(rr.rand()), rr.uniform(0, math.tau)
        e1 = (ax[2], 0.0, -ax[0])
        n1 = math.sqrt(sum(a * a for a in e1))
        e1 = tuple(a / n1 for a in e1)
        e2 = (ax[1] * e1[2] - ax[2] * e1[1], ax[2] * e1[0] - ax[0] * e1[2], ax[0] * e1[1] - ax[1] * e1[0])
        px_ = (e1[0] * u * math.cos(v) + e2[0] * u * math.sin(v) + ax[0] * (2.6 + 0.0105 * u * u),
               e1[1] * u * math.cos(v) + e2[1] * u * math.sin(v) + ax[1] * (2.6 + 0.0105 * u * u),
               39.0 + e1[2] * u * math.cos(v) + e2[2] * u * math.sin(v) + ax[2] * (2.6 + 0.0105 * u * u))
        etoiles.append((gx + px_[0], gy - (px_[1] + px_[2]) * COS))
    for k in range(6):
        t = T[k]
        ix, iy = P0[0] + (P1[0] - P0[0]) * t, P0[1] + (P1[1] - P0[1]) * t
        dr = ImageDraw.Draw(ligne)
        if k >= 2:
            tp = T[k - 1] if k > 2 else 0.0
            pts = []
            for j in range(21):
                u = tp + (min(t, 1.0) - tp) * j / 20.0
                pts.append(((P0[0] + (P1[0] - P0[0]) * u + 0.7 * math.sin(u * 37.0)) * PPT, (P0[1] + (P1[1] - P0[1]) * u + 0.7 * math.cos(u * 29.0)) * PPT))
            dr.line(pts, fill=255, width=int(2.4 * PPT))
        tr = np.asarray(ligne, np.float32) / 255.0
        tr_f = X.flou(tr, 2.2)
        # chaleur le long du trait : décroît avec la distance à l'impact
        dimp = np.hypot(sc.X - ix, sc.Y - iy)
        chaleur = tr_f * np.exp(-dimp / (20.0 if ALL[k] else 0.4))
        hal = X.flou(chaleur, 12.0) * 2.0
        roussi = np.clip(X.flou(tr, 40.0) * 3.6, 0, 1) * (0.5 + 0.5 * n_)

        def condition(e):
            if k < 2:
                return 0
            # distance au segment déjà parcouru
            ex, ey = e["pos"]
            vx, vy = P1[0] - P0[0], P1[1] - P0[1]
            u = max(0.0, min(t, ((ex - P0[0]) * vx + (ey - P0[1]) * vy) / (vx * vx + vy * vy)))
            if math.hypot(ex - (P0[0] + vx * u), ey - (P0[1] + vy * u)) < 4.5:
                return (t - u) * 6.0 + 0.1 if ALL[k] else 3.5
            return 0
        ents, feux = ruines_et_feux(ents0, condition)

        def sol(img, k=k):
            if k < 2:
                return
            img *= (1 - 0.62 * roussi)[..., None]
            # verre sombre, reflets
            X.over(img, (0.03, 0.022, 0.016), tr_f * 0.92)
            X.add(img, (0.4, 0.32, 0.2), np.clip(tr_f * (n_ > 0.72) * 0.6, 0, 0.6))
            img += X.rampe(np.clip(chaleur * 1.3, 0, 1), X.PAL_FEU) * tr_f[..., None]
            X.add(img, (1.0, 0.5, 0.12), np.clip(hal, 0, 0.7))

        def air(img, k=k):
            dessine_feux(img, feux)
            # éclats des pétales
            if k in (1, 2, 3, 4):
                for j, (sx, sy) in enumerate(etoiles):
                    if (j + k) % 3 and k == 1:
                        continue
                    px, py = int(sx * PPT), int(sy * PPT)
                    L_ = 7 + (j * 13) % 18
                    if L_ < px < img.shape[1] - L_ and L_ < py < img.shape[0] - L_:
                        img[py, px - L_:px + L_] = np.clip(img[py, px - L_:px + L_] + np.array((1.0, 0.92, 0.6), np.float32) * 0.8, 0, 1)
                        img[py - L_:py + L_, px] = np.clip(img[py - L_:py + L_, px] + np.array((1.0, 0.92, 0.6), np.float32) * 0.8, 0, 1)
            if ALL[k] or k == 1:
                d = np.hypot(sc.X - fx_, sc.Y - fy_)
                X.add(img, (1.0, 0.82, 0.42), np.clip((1.1 if ALL[k] else 0.6) * np.exp(-(d / 3.0) ** 2) + (0.3 if ALL[k] else 0.12) * np.exp(-(d / 10.0) ** 2), 0, 1))
            if ALL[k]:
                # le trait : cœur blanc, halo or (en jeu : `beam`, ou 2 `draw_line` de `rendering`)
                X.arc_electrique(img, (fx_ * PPT, fy_ * PPT), (ix * PPT, iy * PPT), 7, (1.0, 0.7, 0.2), epais=6, halo=9.0, k=1.0, wob=0.0)
                X.arc_electrique(img, (fx_ * PPT, fy_ * PPT), (ix * PPT, iy * PPT), 8, (1.0, 0.6, 0.15), epais=3, halo=20.0, k=0.7, wob=0.0)
                d = np.hypot(sc.X - ix, sc.Y - iy)
                X.add(img, (1.0, 0.86, 0.55), np.clip(1.25 * np.exp(-(d / 3.2) ** 2) + 0.42 * np.exp(-(d / 9.0) ** 2), 0, 1))
                for j, (dx_, hf_) in enumerate(((-3.1, 128), (-1.2, 320), (0.7, 208), (2.6, 384), (4.3, 160))):
                    X.pose_add(img, X.panache(int(hf_ * 0.36), hf_, 11 + j, X.PAL_FEU), (ix + dx_) * PPT, (iy + 0.6 + 0.3 * j) * PPT, 0.7)
                fusees(img, 100 + k, ix - 8, iy - 6, ix + 8, iy + 1, 0.8)
        m = {"glow_foyer": [0.9, 1.5, 2.5, 2.5, 2.5, 0.6][k], "glow_balises": 1.0, "glow_cellules": 1.0}
        img = sc.rendu(ents, [rendu_geant(g, o, (gx, gy), m)], sol_fn=sol, air_fn=air)
        images.append(reduire(sc, img))
        print("tournesol", k, flush=True)
    ecrit(images, legendes, "TOURNESOL · effet « Le Foyer » : 6 instants, 16 px/tuile", os.path.join(dest, "tournesol-effet-1.png"), 3)


# ======================================================================================================= PETITS
def _vague(ppt=PPT, positions=()):
    return [{"pos": p, "layers": SC.behemoth(ppt), "nom": "biter"} for p in positions]


def mat_foudre(src, dest):
    W, H, gx, gy = 58, 42, 20, 28
    sc = SC.Scene(W, H, PPT, seed=61)
    g, o = couches(src, "mat_foudre")
    Bases = EF.materialise([("assembleur", 6, 34), ("assembleur", 10, 34), ("four", 14, 38), ("poteau", 8, 28), ("assembleur", 6, 20), ("assembleur", 10, 20)])
    tete = (gx, gy - 21.3 * COS)
    b1 = [(50, 12), (54, 22), (46, 28), (52, 34), (42, 18), (38, 30), (34, 14)]
    b2 = [(38, 14), (42, 24), (36, 28), (40, 34), (32, 18), (30, 30), (28, 14)]
    legendes = ["1 · Une vague arrive sur la base", "2 · La tête se charge, 1er arc", "3 · L'arc saute d'une cible à l'autre", "4 · Sol brûlé, rien n'est passé"]
    images = []
    for k in range(4):
        vivants = b1 if k == 0 else b2
        ents = list(Bases)
        if k < 3:
            ents += _vague(PPT, vivants if k < 2 else [])

        def sol(img, k=k):
            if k >= 2:
                for (x, y) in b2:
                    d = np.hypot(sc.X - x, sc.Y - y)
                    img *= (1 - 0.7 * EF.lisse(2.6, 0.8, d))[..., None]

        def air(img, k=k):
            a0 = (tete[0] * PPT, tete[1] * PPT)
            if k == 1:
                X.arc_electrique(img, a0, (b2[4][0] * PPT, b2[4][1] * PPT), 11, (0.1, 0.72, 1.0), epais=4, halo=8.0, wob=0.1)
            if k == 2:
                prec = a0
                for j, q in enumerate(sorted(b2, key=lambda z: z[0])):
                    X.arc_electrique(img, prec, (q[0] * PPT, q[1] * PPT), 20 + j, (0.1, 0.72, 1.0), epais=4, halo=8.0, wob=0.1)
                    prec = (q[0] * PPT, q[1] * PPT)
                    if j % 2 == 0:
                        X.arc_electrique(img, a0, prec, 40 + j, (0.1, 0.72, 1.0), epais=3, halo=6.0, wob=0.1)
                    X.pose_over(img, X.explosion_massive(5 + j, PPT), q[0] * PPT - 22, (q[1] - 2.8) * PPT)
            if k >= 1 and k < 3:
                d = np.hypot(sc.X - tete[0], sc.Y - tete[1])
                X.add(img, (0.5, 0.9, 1.0), np.clip(0.9 * np.exp(-(d / 1.6) ** 2) + 0.3 * np.exp(-(d / 4.0) ** 2), 0, 1))
        m = {"glow_arc": [1.0, 2.2, 2.6, 1.0][k]}
        img = sc.rendu(ents, [rendu_geant(g, o, (gx, gy), m)], sol_fn=sol, air_fn=air)
        images.append(reduire(sc, img, 0.75))
    ecrit(images, legendes, "MÂT-FOUDRE · effet « La Chaîne » : 4 instants, 24 px/tuile", os.path.join(dest, "mat_foudre-effet-1.png"), 2)


def geode(src, dest):
    W, H, gx, gy = 58, 42, 14, 30
    sc = SC.Scene(W, H, PPT, seed=63)
    g, o = couches(src, "geode")
    ents0 = EF.materialise([("tourelle", 38 + 3 * i, 18 + (i % 2) * 2) for i in range(6)] + [("tourelle", 40 + 3 * i, 30) for i in range(5)] + [("mur", 34, y) for y in range(10, 40)] + [("assembleur", 46, 8), ("assembleur", 50, 8)])
    dirn = math.radians(-6.0)
    rr = np.random.RandomState(64)
    spikes = []
    for j in range(170):
        s = rr.uniform(3, 44)
        lat = rr.normal(0, 1.1 + s * 0.07)
        spikes.append((gx + 2 + math.cos(dirn) * s - math.sin(dirn) * lat, gy + math.sin(dirn) * s + math.cos(dirn) * lat, s, rr.uniform(24, 110) * (0.8 + 0.014 * s), rr.uniform(7, 17), rr.uniform(-0.3, 0.3)))
    spikes.sort(key=lambda q: q[1])
    FR = [0.0, 12.0, 30.0, 46.0]
    legendes = ["1 · Elle s'ouvre, le cristal respire", "2 · Le sol crache des pointes", "3 · La ligne court vers le mur", "4 · Elle traverse : la défense est ouverte"]
    images = []
    for k in range(4):
        F_ = FR[k]

        def cond(e):
            ex, ey = e["pos"]
            s = (ex - gx - 2) * math.cos(dirn) + (ey - gy) * math.sin(dirn)
            lat = abs(-(ex - gx - 2) * math.sin(dirn) + (ey - gy) * math.cos(dirn))
            if s < F_ and lat < 3.0 + s * 0.09:
                return 0.1 + (F_ - s) / 40.0
            return 0
        ents, feux = ruines_et_feux(ents0, cond)

        def air(img, k=k):
            pil = Image.new("RGBA", (sc.W, sc.H), (0, 0, 0, 0))
            halo = Image.new("L", (sc.W, sc.H), 0)
            dr = ImageDraw.Draw(pil)
            dh = ImageDraw.Draw(halo)
            for (x, y, s, h, w, inc) in spikes:
                if s > F_:
                    continue
                c = min(1.0, (F_ - s) / 6.0 + 0.2)
                h2 = h * c
                X0, Y0 = x * PPT, y * PPT
                t = (X0 + inc * h2, Y0 - h2)
                dr.polygon([(X0 - w, Y0), t, (X0 - 0.2 * w, Y0 + 3)], fill=(58, 22, 104, 255))
                dr.polygon([(X0 + w, Y0), t, (X0 - 0.2 * w, Y0 + 3)], fill=(150, 88, 225, 255))
                dr.line([(X0 - 0.1 * w, Y0), t], fill=(226, 196, 255, 255), width=1)
                dh.line([(X0, Y0), t], fill=255, width=3)
            a = np.asarray(pil, np.float32) / 255.0
            img[:] = a[..., :3] * a[..., 3:4] + img * (1 - a[..., 3:4])
            h_ = X.flou(np.asarray(halo, np.float32) / 255.0, 7.0) * 2.0
            X.add(img, (0.5, 0.14, 1.0), np.clip(h_, 0, 0.55))
            dessine_feux(img, feux)
        m = {"glow_cristal": [1.5, 2.2, 2.2, 1.6][k]}
        img = sc.rendu(ents, [rendu_geant(g, o, (gx, gy), m)], air_fn=air)
        images.append(reduire(sc, img, 0.75))
    ecrit(images, legendes, "GÉODE · effet « Le Buisson » : 4 instants, 24 px/tuile", os.path.join(dest, "geode-effet-1.png"), 2)


def sarracenie(src, dest):
    W, H, gx, gy = 58, 42, 16, 30
    sc = SC.Scene(W, H, PPT, seed=65)
    g, o = couches(src, "sarracenie")
    Bases = EF.materialise([("four", 5, 38), ("four", 9, 38), ("poteau", 4, 24)])
    bout = (gx - 0.9, gy - (1.2 + 15.0) * COS)
    cibles = [(42, 18), (47, 28), (39, 33)]
    n_ = SC.fbm(sc.H, sc.W, 66, cell=26.0)
    legendes = ["1 · Les urnes guettent", "2 · Trois crachats en cloche", "3 · Ça éclate, l'acide s'étale", "4 · Flaques vives, les biters fondent"]
    biters = [(44, 16), (40, 20), (48, 27), (45, 31), (38, 34), (42, 36)]
    images = []
    for k in range(4):
        ents = list(Bases) + _vague(PPT, biters if k < 3 else biters[:1])

        def sol(img, k=k):
            if k < 2:
                return
            for (x, y) in cibles:
                d = np.hypot(sc.X - x, sc.Y - y) + (n_ - 0.5) * 4.5
                Rp = 3.5 if k == 2 else 5.0
                a = EF.lisse(Rp + 0.5, Rp - 0.4, d)
                c = X.rampe(np.clip(0.42 + 0.46 * n_, 0, 1), PAL_VERT)
                a3 = (a * 0.9)[..., None]
                img[:] = c * a3 + img * (1 - a3)
                X.add(img, (0.5, 1.0, 0.1), np.clip(np.exp(-((d - Rp) / 0.3) ** 2) * 0.6, 0, 0.8))
                X.add(img, (0.3, 0.8, 0.05), np.clip(EF.lisse(Rp + 5, Rp, d) * 0.22, 0, 0.3))

        def air(img, k=k):
            if k == 1:
                for j, (x, y) in enumerate(cibles):
                    # arc en cloche : 24 points, gouttes
                    for t in np.linspace(0.05, 0.72 + 0.1 * j, 28):
                        cx = bout[0] + (x - bout[0]) * t
                        cy = bout[1] + (y - bout[1]) * t - 40.0 * t * (1 - t) * 0.5
                        d = np.hypot(sc.X[int(cy * PPT) - 30 : int(cy * PPT) + 30, int(cx * PPT) - 30 : int(cx * PPT) + 30] - cx, sc.Y[int(cy * PPT) - 30 : int(cy * PPT) + 30, int(cx * PPT) - 30 : int(cx * PPT) + 30] - cy)
                        sub = img[int(cy * PPT) - 30 : int(cy * PPT) + 30, int(cx * PPT) - 30 : int(cx * PPT) + 30]
                        r_ = 0.2 + 0.55 * t
                        sub += np.array((0.45, 1.0, 0.12), np.float32) * np.clip(np.exp(-(d / r_) ** 2), 0, 1)[..., None] * (0.25 + 0.7 * t)
                        img[int(cy * PPT) - 30 : int(cy * PPT) + 30, int(cx * PPT) - 30 : int(cx * PPT) + 30] = np.clip(sub, 0, 1)
            if k == 2:
                for j, (x, y) in enumerate(cibles):
                    X.pose_add(img, X.panache(150, 200, 21 + j, PAL_VERT), x * PPT, y * PPT, 0.85)
                    X.eclats(img, 70 + j, 60, x, y, 6.0, PPT, 1.2, 3.5, haut=3.0, col=(0.3, 0.75, 0.08))
            if k == 3:
                rr = np.random.RandomState(67)
                for j, (x, y) in enumerate(cibles):
                    for b in range(70):
                        a, ra = rr.uniform(0, math.tau), 5.0 * math.sqrt(rr.rand())
                        px, py = int((x + ra * math.cos(a)) * PPT), int((y + ra * math.sin(a)) * PPT)
                        s_ = rr.randint(2, 7)
                        img[py - s_:py + s_, px - s_:px + s_] = np.clip(img[py - s_:py + s_, px - s_:px + s_] + np.array((0.5, 0.8, 0.2), np.float32) * 0.35, 0, 1)
        m = {"glow_suc": [1.0, 1.8, 2.0, 1.4][k]}
        img = sc.rendu(ents, [rendu_geant(g, o, (gx, gy), m)], sol_fn=sol, air_fn=air)
        images.append(reduire(sc, img, 0.75))
    ecrit(images, legendes, "SARRACÉNIE · effet « Le Crachat » : 4 instants, 24 px/tuile", os.path.join(dest, "sarracenie-effet-1.png"), 2)


def demi_vie(src, dest):
    W, H, ex, ey = 58, 44, 30, 28
    sc = SC.Scene(W, H, PPT, seed=69)
    g, o = couches(src, "demi_vie")
    ents0 = EF.materialise(EF.base_rangees(4, 56, 4, 44, 21, lambda x, y: math.hypot(x - ex, y - ey) < 5))
    d = np.hypot(sc.X - ex, sc.Y - ey)
    n_ = SC.fbm(sc.H, sc.W, 70, cell=34.0)
    legendes = ["1 · Elle fonce, le col s'allume", "2 · Sur place : le cœur fond", "3 · Fusion : tout dans 12 tuiles disparaît", "4 · Une zone verte, pour longtemps"]
    images = []
    for k in range(4):
        def cond(e):
            dd = math.hypot(e["pos"][0] - ex, e["pos"][1] - ey)
            return (0.14 if k == 2 else 3.0) if (k >= 2 and dd < 13) else 0
        ents, feux = ruines_et_feux(ents0, cond)

        def sol(img, k=k):
            if k >= 2:
                img *= (1 - 0.82 * EF.lisse(15, 8, d + (n_ - 0.5) * 6))[..., None]
                X.add(img, (0.2, 0.75, 0.05), np.clip(EF.lisse(14, 4, d + (n_ - 0.5) * 7) * (0.7 if k == 2 else 0.44) * (0.4 + 0.8 * n_), 0, 0.8))
                r_ = 13.5 if k == 3 else 16
                X.add(img, (0.5, 1.0, 0.15), np.clip(np.exp(-((d - r_) / 0.45) ** 2) * (0.7 + 0.5 * n_), 0, 1))

        def air(img, k=k):
            dessine_feux(img, feux)
            if k == 2:
                # vraie boule de nuke vanilla, virée au vert par 3 canaux ; pied au sol
                b = X.boule_nuke(9, PPT).copy()
                b[..., 0] *= 0.42
                b[..., 2] *= 0.3
                X.pose_over(img, b, ex * PPT, (ey - 7.2) * PPT)
                X.add(img, (0.5, 1.0, 0.2), np.clip(1.1 * np.exp(-(d / 8.0) ** 2), 0, 1))
            if k == 1:
                X.add(img, (0.65, 1.0, 0.35), np.clip(1.2 * np.exp(-(d / 3.0) ** 2) + 0.35 * np.exp(-(d / 9.0) ** 2), 0, 1))
            if k == 3:
                rr = np.random.RandomState(71)
                for b in range(240):
                    a, ra = rr.uniform(0, math.tau), 14.0 * math.sqrt(rr.rand())
                    px, py = int((ex + ra * math.cos(a)) * PPT), int((ey + ra * math.sin(a)) * PPT)
                    img[py:py + 2, px:px + 2] = np.clip(img[py:py + 2, px:px + 2] + np.array((0.6, 1.0, 0.25), np.float32) * 0.7, 0, 1)
        g_ = []
        if k < 2:
            px = (ex - 19, ey + 6) if k == 0 else (ex, ey + 2)
            g_ = [rendu_geant(g, o, px, {"glow_uranium": [1.4, 3.0][k]})]
        img = sc.rendu(ents, g_, sol_fn=sol, air_fn=air)
        images.append(reduire(sc, img, 0.75))
    ecrit(images, legendes, "DEMI-VIE · effet « La Fusion » : 4 instants, 24 px/tuile", os.path.join(dest, "demi_vie-effet-1.png"), 2)


def veilleuse(src, dest):
    W, H, gx, gy = 58, 42, 18, 34
    sc = SC.Scene(W, H, PPT, seed=75)
    g, o = couches(src, "veilleuse")
    Bases = EF.materialise([("assembleur", 5, 40), ("assembleur", 9, 40), ("poteau", 4, 30), ("labo", 30, 40)])
    tete = (gx, gy - 17.5 * COS)
    ci = (46.0, 22.0)
    bit = [(44, 20), (48, 24), (42, 25), (50, 20), (46, 16), (40, 18)]
    d = np.hypot(sc.X - ci[0], sc.Y - ci[1])
    n_ = SC.fbm(sc.H, sc.W, 76, cell=30.0)
    legendes = ["1 · Elle veille, le tore tourne", "2 · Le soleil captif donne une goutte", "3 · Elle retombe sur la vague", "4 · Plaque de verre : plus personne"]
    images = []
    for k in range(4):
        ents = list(Bases) + (_vague(PPT, bit) if k < 2 else [])

        def sol(img, k=k):
            if k >= 2:
                img *= (1 - 0.8 * EF.lisse(10, 5, d + (n_ - 0.5) * 5))[..., None]
                X.add(img, (1.0, 0.1, 0.6), np.clip(EF.lisse(9, 2, d) * (0.7 if k == 2 else 0.22) * (0.4 + 0.9 * n_), 0, 0.8))

        def air(img, k=k):
            if k == 1:
                # boule de plasma en cloche, avec sa traîne
                for t in np.linspace(0.02, 0.62, 30):
                    cx = tete[0] + (ci[0] - tete[0]) * t
                    cy = tete[1] + (ci[1] - tete[1]) * t - 60.0 * t * (1 - t) * 0.42
                    y0, y1, x0, x1 = int(cy * PPT) - 42, int(cy * PPT) + 42, int(cx * PPT) - 42, int(cx * PPT) + 42
                    if y0 < 0:
                        continue
                    dd = np.hypot(sc.X[y0:y1, x0:x1] - cx, sc.Y[y0:y1, x0:x1] - cy)
                    r_ = 0.35 + 0.8 * (t / 0.62) ** 3
                    img[y0:y1, x0:x1] = np.clip(img[y0:y1, x0:x1] + np.array((1.0, 0.25 + 0.6 * (t / 0.62) ** 4, 0.7), np.float32) * np.clip(np.exp(-(dd / r_) ** 2), 0, 1)[..., None] * (0.35 + 0.65 * (t / 0.62)), 0, 1)
            if k == 2:
                X.add(img, (1.0, 0.7, 0.85), np.clip(1.2 * np.exp(-(d / 6.0) ** 2) + 0.42 * np.exp(-(d / 13.0) ** 2), 0, 1))
                X.pose_add(img, X.panache(220, 300, 31, X.PAL_PLASMA), ci[0] * PPT, ci[1] * PPT, 0.7)
                X.add(img, (1.0, 0.25, 0.7), np.clip(np.exp(-((d - 11.0) / 0.6) ** 2) * (0.4 + 0.9 * n_), 0, 1))
                X.eclats(img, 77, 110, ci[0], ci[1], 11.0, PPT, 1.2, 3.5, haut=4.0)
        m = {"glow_plasma": [1.0, 1.8, 1.6, 1.0][k], "glow_soleil": [1.0, 1.9, 1.4, 1.0][k]}
        img = sc.rendu(ents, [rendu_geant(g, o, (gx, gy), m)], sol_fn=sol, air_fn=air)
        images.append(reduire(sc, img, 0.75))
    ecrit(images, legendes, "VEILLEUSE · effet « Le Lampion » : 4 instants, 24 px/tuile", os.path.join(dest, "veilleuse-effet-1.png"), 2)


TOUS = {"cairn": cairn, "stylet": stylet, "trombe": trombe, "tournesol": tournesol, "mat_foudre": mat_foudre, "geode": geode, "sarracenie": sarracenie, "demi_vie": demi_vie, "veilleuse": veilleuse}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--qui", default=",".join(TOUS))
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for n in a.qui.split(","):
        TOUS[n](a.src, a.dest)


if __name__ == "__main__":
    main()
