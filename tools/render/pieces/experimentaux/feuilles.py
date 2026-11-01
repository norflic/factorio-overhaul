"""FEUILLES DE JEU DU BOURDON (lot BOURDON, 1er/11) : rendus + effets procéduraux -> graphics/robots/bourdon/ (PNG hors de git, D-6),
sprites.lua (généré, lu par prototypes/bourdon.lua et script/robots/bourdon.lua) et MANIFEST.json. Hors Blender.

    py -3.9 tools/render/pieces/experimentaux/feuilles.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut (à GARDER) : fo-logs/2026-10-31_ROBOTS/BOURDON/rendu/sprites : corps, battant, ancre, griffes, chaine (rendre.py, 40 px/tuile).
Résolutions : corps et pièces hr 40 px/tuile, normale 16 ; ombres hr 16, normale 8 ; effets procéduraux hr 32, normale 16 (déterministes, graine fixe).
Chaque image reste sous 4 096 px (une page d'atlas, F148, F144). Noms de sprite : fo-bourdon-<cle>.
"""
import argparse
import hashlib
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fx as X  # noqa: E402

RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
LOGS = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs")
SRC_DEFAUT = os.path.join(LOGS, "2026-10-31_ROBOTS", "BOURDON", "rendu", "sprites")
DEST_DEFAUT = os.path.join(MOD, "graphics", "robots", "bourdon")
PREFIXE = "__factorio-overhaul__/graphics/robots/bourdon/"
COMMANDE = "py -3.9 tools/render/pieces/experimentaux/feuilles.py   (depuis la racine du mod ; sources : fo-logs/2026-10-31_ROBOTS/BOURDON/rendu/sprites, à GARDER)"
PX_RENDU = 40.0
PPT = 32.0


def lanczos(a, w, h):
    """Réduction d'une image RGBA (uint8) : alpha prémultiplié, pour ne pas assombrir les bords."""
    x = a.astype(np.float32) / 255.0
    x[..., :3] *= x[..., 3:4]
    ch = [np.asarray(Image.fromarray(x[..., c], "F").resize((w, h), Image.LANCZOS), np.float32) for c in range(4)]
    o = np.stack(ch, -1)
    al = np.clip(o[..., 3:4], 1e-4, 1)
    o[..., :3] = np.clip(o[..., :3] / al, 0, 1)
    o[..., 3] = np.clip(o[..., 3], 0, 1)
    return np.round(o * 255).astype(np.uint8)


def ecrit(a, dest, nom):
    p = os.path.join(dest, nom)
    Image.fromarray(a, "RGBA").save(p, compress_level=6)
    return nom


class Sortie:
    def __init__(self, dest):
        self.dest = dest
        self.spr = {}

    def pose(self, cle, hr, hr_ppt, lr, lr_ppt, shift=(0.0, 0.0), blend=None, ombre=False, lueur=False, longueur=None):
        """hr, lr : images RGBA uint8 ; *_ppt : pixels par tuile. Rend l'entrée de sprites.lua."""
        for a in (hr, lr):
            assert a.shape[0] <= 4096 and a.shape[1] <= 4096, cle
        fh = ecrit(hr, self.dest, "hr-%s.png" % cle)
        fl = ecrit(lr, self.dest, "%s.png" % cle)
        self.spr[cle] = {"hr": {"filename": PREFIXE + fh, "width": hr.shape[1], "height": hr.shape[0], "scale": PPT / hr_ppt},
                         "lr": {"filename": PREFIXE + fl, "width": lr.shape[1], "height": lr.shape[0], "scale": PPT / lr_ppt},
                         "shift": [round(float(shift[0]), 4), round(float(shift[1]), 4)]}
        e = self.spr[cle]
        if blend:
            e["blend"] = blend
        if ombre:
            e["ombre"] = True
        if lueur:
            e["lueur"] = True
        if longueur:
            e["long"] = longueur

    def rendu(self, src, var, couche, cle, hr_ppt=PX_RENDU, lr_ppt=16.0, **kw):
        s = json.load(open(os.path.join(src, var, "spec.json"), encoding="utf-8"))
        info = s["layers"][couche]
        a = np.asarray(Image.open(os.path.join(src, var, info["file"])).convert("RGBA"))
        w, h = a.shape[1], a.shape[0]
        k = hr_ppt / PX_RENDU
        hr = a if k == 1.0 else lanczos(a, max(1, int(round(w * k))), max(1, int(round(h * k))))
        k2 = lr_ppt / PX_RENDU
        lr = lanczos(a, max(1, int(round(w * k2))), max(1, int(round(h * k2))))
        self.pose(cle, hr, hr_ppt, lr, lr_ppt, shift=info["shift"], **kw)
        return info


# ---------------------------------------------------------------------------------------------- bruit
def bruit1d(n, seed, cell, oct=3):
    """Bruit lisse périodique sur n points, de 0 à 1."""
    r = np.random.RandomState(seed)
    out = np.zeros(n, np.float32)
    amp, tot = 1.0, 0.0
    for o in range(oct):
        m = max(2, int(n / (cell / (2 ** o))))
        v = r.rand(m)
        xs = np.arange(n) * m / float(n)
        i0 = xs.astype(int) % m
        f = xs - np.floor(xs)
        f = f * f * (3 - 2 * f)
        out += amp * (v[i0] * (1 - f) + v[(i0 + 1) % m] * f)
        tot += amp
        amp *= 0.55
    return out / tot


def bruit2d(h, w, seed, cell, oct=4):
    r = np.random.RandomState(seed)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(oct):
        cc = cell / (2 ** o)
        mh, mw = max(2, int(h / cc) + 2), max(2, int(w / cc) + 2)
        v = r.rand(mh, mw).astype(np.float32)
        ima = Image.fromarray(v, "F").resize((w, h), Image.BICUBIC)
        out += amp * np.asarray(ima, np.float32)
        tot += amp
        amp *= 0.55
    return np.clip(out / tot, 0, 1)


def additif(c):
    """c : énergie RGB (float). Codage additif du pipeline (fo_post.additive_layer) : RGB = c / max, A = max."""
    c = np.clip(c, 0, 1)
    m = c.max(-1, keepdims=True)
    rgb = np.where(m > 1e-6, c / np.maximum(m, 1e-6), 0)
    return np.round(np.concatenate([rgb, m], -1) * 255).astype(np.uint8)


def rgba(col, al):
    """Couleur (tableau h × w × 3 ou triplet) et alpha -> RGBA uint8."""
    h, w = al.shape
    c = np.ones((h, w, 3), np.float32) * np.asarray(col, np.float32)
    return np.round(np.clip(np.concatenate([c, al[..., None]], -1), 0, 1) * 255).astype(np.uint8)


def fenetre(n, bord):
    """Fondu de 0 à 1 sur `bord` (fraction) à chaque bout."""
    x = (np.arange(n) + 0.5) / n
    t = np.clip(np.minimum(x, 1 - x) / bord, 0, 1)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------------------------------------- effets
def crete(ppt, seed, fort=1.0, fin=1.0):
    """Morceau de crête d'onde, 12 × 4 tuiles, bord extérieur EN HAUT : ligne fine et turbulente, traîne vers l'intérieur (haut de la feuille = dehors)."""
    W, H = int(12 * ppt), int(4 * ppt)
    k = ppt / 32.0
    y0 = 1.25 * ppt
    bo = bruit1d(W, seed, 90 * k, 4)
    bg = bruit1d(W, seed + 1, 34 * k, 3)
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    dy = y - (y0 + (bo - 0.5) * 16 * k + (bg - 0.5) * 6 * k)
    tb = bruit2d(H, W, seed + 2, 24 * k)
    l1 = np.exp(-(dy / (2.6 * k * fin)) ** 2) * (0.55 + 0.9 * bg)
    tr = np.where(dy > 0, np.exp(-dy / (19.0 * k)), np.exp(dy / (8.0 * k))) * (0.2 + 1.25 * tb ** 1.4)
    t = np.clip(l1 * 1.25 + tr * 0.72, 0, 1)
    win = fenetre(W, 0.26)
    # palette or chaud vers blanc
    c = X.rampe(np.clip(t, 0, 1), [(0.0, (0, 0, 0)), (0.22, (0.62, 0.38, 0.1)), (0.5, (1.0, 0.78, 0.36)), (0.78, (1.0, 0.93, 0.64)), (1.0, (1.0, 0.99, 0.9))])
    return additif(c * (win * fort)[..., None])


def poussiere(ppt, seed):
    """Morceau du mur de poussière, 16 × 6 tuiles, ocre, sans lueur."""
    W, H = int(16 * ppt), int(6 * ppt)
    k = ppt / 32.0
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    b = bruit2d(H, W, seed, 54 * k, 5)
    b2 = bruit2d(H, W, seed + 3, 18 * k, 4)
    prof = np.exp(-((y - H * 0.5) / (H * 0.3)) ** 2)
    al = np.clip((prof * (b ** 1.1) * 4.2 - 0.3), 0, 1) * fenetre(W, 0.3)
    al = np.clip(al, 0, 0.95)
    teinte = 0.62 + 0.7 * b2
    col = np.stack([0.6 * teinte, 0.47 * teinte, 0.33 * teinte], -1)
    return rgba(col, al)


def chemin(W, seed):
    """Tracé d'une fissure : y(x) brisé, de (0, 0) à (W, 0)."""
    r = np.random.RandomState(seed)
    pts = [(0.0, 0.0), (float(W), 0.0)]
    amp = W * 0.11
    for _ in range(5):
        nou = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            nou.append(((a[0] + b[0]) / 2 + r.uniform(-0.1, 0.1) * (b[0] - a[0]), (a[1] + b[1]) / 2 + r.uniform(-amp, amp)))
            nou.append(b)
        pts = nou
        amp *= 0.55
    return pts


def trace_fissure(W, H, seed):
    """Rend la distance en pixels au tracé (avec 2 petites fourches), et la largeur relative."""
    pts = chemin(W, seed)
    from PIL import ImageDraw
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    cy = H / 2.0
    d.line([(p[0], cy + p[1]) for p in pts], fill=255, width=max(1, int(H * 0.05)))
    r = np.random.RandomState(seed + 7)
    for _ in range(3):
        i = int(r.randint(2, len(pts) - 2))
        p = pts[i]
        a = r.uniform(0.3, 0.9) * (1 if r.rand() < 0.5 else -1)
        q = [(p[0], cy + p[1])]
        x, y = p[0], cy + p[1]
        for s in range(4):
            x += math.cos(a) * W * 0.05
            y += math.sin(a) * W * 0.05
            a += r.uniform(-0.5, 0.5)
            q.append((x, y))
        d.line(q, fill=170, width=max(1, int(H * 0.028)))
    return np.asarray(im, np.float32) / 255.0


def fissure(ppt, seed):
    """Morceau de fissure, 8 × 2,5 tuiles. Froid : gueule noire, lèvres de terre. Chaud (mêmes tracés) : cœur d'or, halo. x va de bout en bout, sans fondu vif."""
    W, H = int(8 * ppt), int(2.5 * ppt)
    k = ppt / 32.0
    m = trace_fissure(W, H, seed)
    win = fenetre(W, 0.08)[None, :] * fenetre(H, 0.18)[:, None]
    co = X.flou(m, 0.7 * k)
    lev = X.flou(m, 3.2 * k)
    al_f = np.clip(co * 2.8, 0, 0.97) * win + np.clip(lev * 1.7, 0, 0.42) * win
    col = np.zeros((H, W, 3), np.float32)
    col[...] = (0.02, 0.014, 0.01)
    # lèvre : un soupçon de terre claire, côté ouest (F47 : la lumière vient de l'ouest)
    froid = rgba(col, np.clip(al_f, 0, 1))
    t = np.clip(X.flou(m, 0.7 * k) * 1.9, 0, 1)
    h1 = X.flou(m, 3.0 * k) * 2.2
    h2 = X.flou(m, 8.0 * k) * 2.6
    c = X.rampe(np.clip(t, 0, 1), [(0.0, (0, 0, 0)), (0.35, (0.8, 0.42, 0.08)), (0.7, (1.0, 0.8, 0.34)), (1.0, (1.0, 0.97, 0.78))])
    c = np.clip(c + np.clip(h1, 0, 0.9)[..., None] * np.array((1.0, 0.68, 0.22), np.float32) + np.clip(h2, 0, 0.45)[..., None] * np.array((0.65, 0.38, 0.1), np.float32), 0, 1)
    chaud = additif(c * win[..., None])
    return froid, chaud


def balaye(n):
    """Sol balayé par l'onde, n × n pixels : stries radiales sombres, cratère au centre. Échelle : suit le rayon de l'onde."""
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    dx, dy = (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1
    r = np.hypot(dx, dy)
    ph = np.arctan2(dy, dx)
    rng = np.random.RandomState(9)
    br = rng.rand(1440).astype(np.float32)
    br = np.convolve(np.r_[br[-8:], br, br[:8]], np.ones(5) / 5.0, "same")[8:-8]
    st = np.interp((ph + math.pi) / (2 * math.pi) * 1440.0, np.arange(1440), br)
    st = np.clip((st - 0.3) * 2.8, 0, 1).astype(np.float32)
    b = bruit2d(n, n, 77, n / 22.0, 5)
    al = 0.1 + 0.26 * st * (0.35 + 0.65 * b)
    al = al * np.clip((1.0 - r) / 0.09, 0, 1) ** 1.3
    cr = np.clip(1 - r / 0.1, 0, 1) ** 2
    al = np.clip(al + 0.45 * cr, 0, 0.9)
    teinte = 0.5 + 0.5 * b
    col = np.stack([0.05 * teinte, 0.035 * teinte, 0.022 * teinte], -1)
    return rgba(col, al)


def flash(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    dx, dy = (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1
    r = np.hypot(dx, dy)
    ph = np.arctan2(dy, dx)
    rais = 0.4 + 0.6 * np.abs(np.cos(ph * 4)) ** 30 + 0.3 * np.abs(np.cos(ph * 4 + 0.78)) ** 40
    t = np.exp(-(r / 0.08) ** 2) * 1.3 + np.exp(-(r / 0.28) ** 2) * 0.55 + np.exp(-(r / 0.8)) * rais * 0.6
    fen = np.clip((1.0 - r) / 0.25, 0, 1)
    c = np.stack([np.clip(t, 0, 1), np.clip(t * 0.86, 0, 1), np.clip(t * 0.56, 0, 1)], -1) * fen[..., None]
    return additif(c)


def anneau_air(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    dx, dy = (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1
    r = np.hypot(dx, dy)
    b = bruit2d(n, n, 41, n / 18.0, 4)
    t = np.exp(-((r - 0.93) / 0.012) ** 2) * (0.5 + 0.8 * b) + np.exp(-((r - 0.93) / 0.05) ** 2) * 0.28 * b
    fen = np.clip((1.0 - r) / 0.03, 0, 1)
    c = np.stack([np.clip(t, 0, 1), np.clip(t * 0.86, 0, 1), np.clip(t * 0.55, 0, 1)], -1) * fen[..., None]
    return additif(c)


def lueur_sol(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot((x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1)
    t = np.exp(-(r / 0.45) ** 2) * np.clip((1.0 - r) / 0.2, 0, 1)
    return additif(np.stack([t, t * 0.8, t * 0.44], -1) * 0.8)


def ombre_chaine(ppt):
    """L'ombre d'une chaîne : 1 × 36 tuiles, pointillé des mailles."""
    W, H = max(4, int(1 * ppt)), int(36 * ppt)
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    per = 1.5 * ppt
    mail = 0.65 + 0.35 * np.abs(np.cos(y / per * math.pi * 2))
    pr = np.exp(-(((x + 0.5) / W - 0.5) / 0.26) ** 2)
    al = np.clip(pr * mail * 0.62, 0, 1)
    return rgba((0.0, 0.0, 0.0), al)


# ---------------------------------------------------------------------------------------------- sortie
def lua(v, ind=0):
    pad = "  " * ind
    if isinstance(v, dict):
        out = ["{"]
        for k in sorted(v):
            key = k if isinstance(k, str) and k.replace("_", "a").isalnum() and not k[0].isdigit() else '["%s"]' % k
            out.append('%s  %s = %s,' % (pad, key, lua(v[k], ind + 1)))
        out.append(pad + "}")
        return "\n".join(out)
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x, ind) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, float):
        return repr(round(v, 5))
    return str(v)


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for f in os.listdir(a.dest):
        if f.endswith(".png"):
            os.remove(os.path.join(a.dest, f))
    S = Sortie(a.dest)
    src = a.src
    # le corps, ses lueurs ; les lueurs sont aussi vues de nuit
    S.rendu(src, "corps", "main", "corps")
    S.rendu(src, "corps", "glow_vitrail", "vitrail", blend="additive", lueur=True)
    S.rendu(src, "corps", "glow_cristal", "cristal", blend="additive", lueur=True)
    S.rendu(src, "corps", "shadow", "corps-ombre", hr_ppt=16.0, lr_ppt=8.0, ombre=True)
    S.rendu(src, "battant", "main", "battant")
    S.rendu(src, "battant", "glow_battant", "battant-lueur", blend="additive", lueur=True)
    S.rendu(src, "ancre", "main", "ancre")
    S.rendu(src, "ancre", "glow_ancre", "ancre-lueur", blend="additive", lueur=True)
    S.rendu(src, "ancre", "shadow", "ancre-ombre", hr_ppt=16.0, lr_ppt=8.0, ombre=True)
    S.rendu(src, "griffes", "main", "griffes")
    S.rendu(src, "griffes", "shadow", "griffes-ombre", hr_ppt=16.0, lr_ppt=8.0, ombre=True)
    info = S.rendu(src, "chaine", "main", "chaine")
    S.spr["chaine"]["long"] = round(info["height"] / PX_RENDU, 3)
    S.pose("chaine-ombre", ombre_chaine(16.0), 16.0, ombre_chaine(8.0), 8.0, ombre=True, longueur=36.0)
    # effets
    for i in range(1, 5):
        S.pose("crete-%d" % i, crete(32.0, 100 + i * 11), 32.0, crete(16.0, 100 + i * 11), 16.0, blend="additive", lueur=True)
    for i in range(1, 3):
        S.pose("crete2-%d" % i, crete(32.0, 500 + i * 11, 0.65, 1.4), 32.0, crete(16.0, 500 + i * 11, 0.65, 1.4), 16.0, blend="additive", lueur=True)
    for i in range(1, 4):
        S.pose("poussiere-%d" % i, poussiere(32.0, 200 + i * 13), 32.0, poussiere(16.0, 200 + i * 13), 16.0)
    for i in range(1, 7):
        fh, ch = fissure(32.0, 300 + i * 17)
        fl, cl = fissure(16.0, 300 + i * 17)
        S.pose("fissure-%d" % i, fh, 32.0, fl, 16.0)
        S.pose("fissure-chaude-%d" % i, ch, 32.0, cl, 16.0, blend="additive", lueur=True)
    S.pose("balaye", balaye(1024), 1024 / 100.0, balaye(512), 512 / 100.0)
    S.pose("flash", flash(256), 8.0, flash(128), 4.0, blend="additive", lueur=True)
    S.pose("anneau-air", anneau_air(512), 512 / 32.0, anneau_air(256), 256 / 32.0, blend="additive", lueur=True)
    S.pose("lueur-sol", lueur_sol(256), 8.0, lueur_sol(128), 4.0, blend="additive", lueur=True)
    # sprites.lua, MANIFEST.json
    p = os.path.join(a.dest, "sprites.lua")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- FICHIER GÉNÉRÉ par tools/render/pieces/experimentaux/feuilles.py (lot BOURDON) : ne pas modifier à la main.\n")
        f.write("-- Images hors de git (D-6) : MANIFEST.json, « commande ». shift : centre de l'image depuis la position au sol, en tuiles.\n")
        f.write("return " + lua(S.spr) + "\n")
    fichiers = {}
    total = 0
    mpx_hr, mpx_lr = 0.0, 0.0
    for f in sorted(os.listdir(a.dest)):
        if f.endswith(".png"):
            pp = os.path.join(a.dest, f)
            im = Image.open(pp)
            fichiers[f] = {"largeur": im.size[0], "hauteur": im.size[1], "taille": os.path.getsize(pp), "sha256": sha(pp)}
            total += os.path.getsize(pp)
            if f.startswith("hr-"):
                mpx_hr += im.size[0] * im.size[1] / 1e6
            else:
                mpx_lr += im.size[0] * im.size[1] / 1e6
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"commande": COMMANDE, "arguments": [], "fichiers": fichiers}, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-BOURDON] %d fichiers PNG, %.2f Mo ; haute %.2f Mpx, normale %.2f Mpx" % (len(fichiers), total / 1e6, mpx_hr, mpx_lr), flush=True)


if __name__ == "__main__":
    main()
