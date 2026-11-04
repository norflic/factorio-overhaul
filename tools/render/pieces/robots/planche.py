"""PLANCHES DES ROBOTS (lot RB-V0) : nos états à côté du VRAI behemoth-biter et du VRAI spidertron, images HR de
<racine>/data/base/graphics/entity, même sol, même échelle, ombres et lueur composées comme en jeu (commun/compo.py).

    py -3.9 tools/render/pieces/robots/planche.py --src DIR --dest DOSSIER --robot trotte [--essai]

Écrit <dest>/<nom>-z1.png (échelle du jeu, 32 px par tuile), <nom>-gros.png, <nom>-marche.png, <nom>-marche.json. Le behemoth est
composé selon biterrunanimation (corps, masque 1 et 2 teintés, ombre, échelle 1,2) ; le spidertron selon create_spidertron : corps et
dessous à la hauteur 1,5, 8 pattes faites des vraies pièces hr-spidertron-legs-* étirées entre hanche, genou et pied comme le fait le
moteur (position des genoux : facteur 0,4, hauteur 2,5, valeurs des prototypes), teinte orange par défaut. Approximation hors moteur des
pattes, à ±quelques pixels ; le corps et ses couches sont exacts.
"""
import argparse
import importlib
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
# avant compo : compo met d'autres dossiers en tête du chemin, dont un autre piece.py et un autre formes.py
import piece  # noqa: E402
import aiguille, aileron, bobineur, chanfrein, cloche, couronne, ecaille, heliaste, levite, torique, trotte, truelle  # noqa: E401, E402, F401

sys.path.insert(0, os.path.join(os.path.dirname(HERE), "levels", "commun"))
import compo as K  # noqa: E402
import fo_calib as C  # noqa: E402

ENT = os.path.join(K.DATA, "base", "graphics", "entity")
ORANGE = np.array((0.869, 0.5, 0.13))
NOMS = {"trotte": ("trotte", "Trotte-Vapeur, âge 3 (boîte ±0,4, image 2 tuiles)", 2.6, 2.4, 1.7),
        "levite": ("levite", "Lévite, âge 12 (boîte ±0,9, image 5 tuiles)", 6.0, 6.2, 4.6),
        "couronne": ("couronne", "Couronné, âge 15 (géant, image 16 tuiles)", 16.0, 18.0, 12.0),
        "ecaille": ("ecaille", "Écaille, âge 5", 3.5, 5.0, 4.0), "bobineur": ("bobineur", "Bobineur, âge 6", 3.0, 4.0, 3.5),
        "aiguille": ("aiguille", "Aiguille, âge 7", 4.5, 5.0, 4.0), "cloche": ("cloche", "Cloche, âge 8", 3.5, 5.0, 4.0),
        "chanfrein": ("chanfrein", "Chanfrein, âge 9", 5.0, 5.5, 4.5), "truelle": ("truelle", "Truelle, âge 10", 3.5, 5.0, 4.0),
        "aileron": ("aileron", "Aileron, âge 11", 4.0, 5.5, 4.0), "torique": ("torique", "Torique, âge 13 (géant)", 12.0, 14.0, 10.0),
        "heliaste": ("heliaste", "Héliaste, âge 14 (géant)", 14.0, 17.0, 10.0)}


def _png(rel):
    return np.asarray(Image.open(os.path.join(ENT, rel)).convert("RGBA")).astype(np.float64) / 255.0


def _echelle(img, k):
    if abs(k - 1.0) < 1e-6:
        return img
    h, w = img.shape[:2]
    pm = img.copy()
    pm[..., :3] *= pm[..., 3:4]
    out = np.stack([np.asarray(Image.fromarray(pm[..., i].astype(np.float32), "F").resize((int(round(w * k)), int(round(h * k))), Image.LANCZOS))
                    for i in range(4)], -1)
    out = np.clip(out, 0, 1)
    a = np.maximum(out[..., 3:4], 1e-5)
    out[..., :3] = np.clip(out[..., :3] / a, 0, 1)
    return out


def behemoth(direction=11, image=3):
    """Vrai behemoth-biter (échelle 1,2 ; teintes de data/base/prototypes/entity/enemies.lua). direction : 0 = nord, sens horaire."""
    scale = 1.2

    def frame(mod, fw, fh):
        i = direction // 8 + 1 + 2 * (image // 8)
        return _png("biter/hr-biter-run-%s-%02d.png" % (mod, i) if mod else "biter/hr-biter-run-%02d.png" % i)[
            (direction % 8) * fh:(direction % 8 + 1) * fh, (image % 8) * fw:(image % 8 + 1) * fw]
    t1 = np.array((0.21, 0.19, 0.25))
    t2 = np.array((0.657, 0.95, 0.432))
    shadow = frame("shadow", 432, 292)
    base = frame("", 398, 310)
    m1 = frame("mask1", 238, 182).copy()
    m1[..., :3] *= t1
    m2 = frame("mask2", 232, 184).copy()
    m2[..., :3] *= t2

    def sh(px, py):
        return (px * scale / 32.0, py * scale / 32.0)
    return [{"img": _echelle(shadow, scale), "shift": sh(8, -1), "kind": "shadow"},
            {"img": _echelle(base, scale), "shift": sh(-1, -5), "kind": "main"},
            {"img": _echelle(m1, scale), "shift": sh(-1, -37), "kind": "main"},
            {"img": _echelle(m2, scale), "shift": sh(0, -38), "kind": "main"}]


def _sur(dst, src, x0, y0):
    """Pose src (RGBA) sur dst (RGBA) en (x0, y0), alpha par-dessus, avec recadrage."""
    Hc, Wc = dst.shape[:2]
    xs, ys = max(0, -x0), max(0, -y0)
    xd, yd = max(0, x0), max(0, y0)
    ww, hh = min(src.shape[1] - xs, Wc - xd), min(src.shape[0] - ys, Hc - yd)
    if ww <= 0 or hh <= 0:
        return
    c = src[ys:ys + hh, xs:xs + ww]
    a_ = c[..., 3:4]
    dst[yd:yd + hh, xd:xd + ww, :3] = c[..., :3] * a_ + dst[yd:yd + hh, xd:xd + ww, :3] * (1 - a_)
    dst[yd:yd + hh, xd:xd + ww, 3:4] = a_ + dst[yd:yd + hh, xd:xd + ww, 3:4] * (1 - a_)


def _segment(canvas, a, b, haut, milieu, bas_, off_h, off_b, ppt=64):
    """Segment de patte comme le moteur : milieu étiré entre 2 décalages, 2 bouts à leur taille, ancrés aux articulations.
    haut, bas_ : (image, décalage du centre en tuiles depuis l'articulation) ; milieu : image (échelle 0,25 en HR : moitié de largeur)."""
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    marge = 1.0
    H, w = int(round((L + 2 * marge) * ppt)), 120
    strip = np.zeros((H, w, 4))
    y0, y1 = int((marge + off_h) * ppt), int((marge + L - off_b) * ppt)
    m = milieu
    res = np.stack([np.asarray(Image.fromarray(m[..., i].astype(np.float32), "F").resize((m.shape[1] // 2, max(1, y1 - y0)), Image.BILINEAR)) for i in range(4)], -1)
    _sur(strip, np.clip(res, 0, 1), (w - res.shape[1]) // 2, y0)
    img, d = haut
    _sur(strip, img, (w - img.shape[1]) // 2, int((marge + d) * ppt - img.shape[0] / 2.0))
    img, d = bas_
    _sur(strip, img, (w - img.shape[1]) // 2, int((marge + L + d) * ppt - img.shape[0] / 2.0))
    ang = math.degrees(math.atan2(b[0] - a[0], b[1] - a[1]))    # vertical vers le bas → direction a→b
    pil = Image.fromarray(np.clip(np.round(strip * 255), 0, 255).astype(np.uint8), "RGBA").rotate(ang, Image.BICUBIC, expand=True)
    rot = np.asarray(pil).astype(np.float64) / 255.0
    cx, cy = (a[0] + b[0]) / 2.0 * ppt, (a[1] + b[1]) / 2.0 * ppt
    _sur(canvas, rot, int(round(cx - rot.shape[1] / 2.0)), int(round(cy - rot.shape[0] / 2.0)))


def spidertron(direction=44):
    """Vrai spidertron, échelle 1. Toile en tuiles écran, centrée sur la position de l'entité au sol ; direction : 0 à 63."""
    W, H = 9.0, 9.0
    ox, oy = W / 2.0, 6.2
    can = np.zeros((int(H * 64), int(W * 64), 4))
    ht = 1.5
    legs = [(15, -22, 2.25, -2.5), (23, -10, 3, -1), (25, 4, 3, 1), (15, 17, 2.25, 2.5), (-15, -22, -2.25, -2.5), (-23, -10, -3, -1), (-25, 4, -3, 1), (-15, 17, -2.25, 2.5)]
    up_a = _png("spidertron/legs/hr-spidertron-legs-upper-end-A.png")
    up_m = _png("spidertron/legs/hr-spidertron-legs-upper-stretchable.png")
    up_b = _png("spidertron/legs/hr-spidertron-legs-upper-end-B.png")
    lo_a = _png("spidertron/legs/hr-spidertron-legs-lower-end-A.png")
    lo_m = _png("spidertron/legs/hr-spidertron-legs-lower-stretchable.png")
    lo_b = _png("spidertron/legs/hr-spidertron-legs-lower-end-B.png")
    knee = _png("spidertron/legs/hr-spidertron-legs-knee.png")

    def col(img, w, h, i):
        return img[:h, i * w:(i + 1) * w]

    def jambe(i, mp):
        hx, hy = ox + mp[0] / 32.0, oy - ht + mp[1] / 32.0
        fx, fy = ox + mp[2], oy + mp[3]
        kx = hx + (fx - hx) * 0.4
        ky = oy + mp[3] * 0.4 + mp[1] / 32.0 * 0.6 - 2.5
        _segment(can, (kx, ky), (fx, fy), (col(lo_a, 40, 98, i), 19.5 / 32.0), col(lo_m, 50, 384, i), (col(lo_b, 34, 92, i), -21 / 32.0), 0.45, 0.65)
        _segment(can, (hx, hy), (kx, ky), (col(up_a, 42, 86, i), 18 / 32.0), col(up_m, 60, 256, i), (col(up_b, 38, 58, i), -9 / 32.0), 0.35, 0.45)
        kn = col(knee, 22, 28, i % 8)
        _sur(can, kn, int(kx * 64 - 11), int(ky * 64 - 14))

    derriere = [i for i, l in enumerate(legs) if l[3] < 0]
    devant = [i for i, l in enumerate(legs) if l[3] >= 0]
    for i in derriere:
        jambe(i, legs[i])

    def poser(img, cx, cy):
        _sur(can, img, int(round(cx * 64 - img.shape[1] / 2.0)), int(round(cy * 64 - img.shape[0] / 2.0)))
    bas = _png("spidertron/torso/hr-spidertron-body-bottom.png")
    bas_m = _png("spidertron/torso/hr-spidertron-body-bottom-mask.png")
    poser(bas, ox, oy - ht)
    bm = bas_m.copy()
    bm[..., :3] = bm[..., :3].mean(-1, keepdims=True) * ORANGE
    poser(bm, ox, oy - ht + 3.5 / 32.0)
    cor = _png("spidertron/torso/hr-spidertron-body.png")
    cor_m = _png("spidertron/torso/hr-spidertron-body-mask.png")
    r, c = direction // 8, direction % 8
    poser(cor[r * 138:(r + 1) * 138, c * 132:(c + 1) * 132], ox, oy - ht - 19 / 32.0)
    cm = cor_m[r * 100:(r + 1) * 100, c * 130:(c + 1) * 130].copy()
    cm[..., :3] = cm[..., :3].mean(-1, keepdims=True) * ORANGE
    poser(cm, ox, oy - ht - 14 / 32.0)
    for i in devant:
        jambe(i, legs[i])
    sh = _png("spidertron/torso/hr-spidertron-body-shadow.png")
    sw, shh = 192, 94
    return [{"img": sh[r * shh:(r + 1) * shh, c * sw:(c + 1) * sw], "shift": (26 / 32.0, 0.5 / 32.0), "kind": "shadow"},
            {"img": can, "shift": (W / 2.0 - ox, H / 2.0 - oy), "kind": "main"}]


def _regle(sheet, x, y, tuiles, ppt):
    d = ImageDraw.Draw(sheet)
    for i in range(int(tuiles) + 1):
        d.line((x + i * ppt, y, x + i * ppt, y + 5), fill=(240, 240, 240))
    d.line((x, y + 5, x + int(tuiles) * ppt, y + 5), fill=(240, 240, 240))
    d.text((x + int(tuiles) * ppt + 4, y - 4), "%d tuiles" % int(tuiles), fill=(240, 240, 240), font=K.font(12, False))


def cadre(lays, ppt=64.0, marge=0.25):
    """Boîte (x0, y0, x1, y1) en tuiles des couches, par rapport à la position de l'entité."""
    xs, ys = [], []
    for l in lays:
        h, w = l["img"].shape[:2]
        if l["kind"] == "main":      # le liseré de contact (AO) couvre toute la toile : seul le corps opaque compte
            yy, xx = np.nonzero(l["img"][..., 3] > 0.5)
            x0, x1, y0, y1 = xx.min(), xx.max() + 1, yy.min(), yy.max() + 1
        else:
            x0, x1, y0, y1 = 0, w, 0, h
        xs += [l["shift"][0] + (x0 - w / 2.0) / ppt, l["shift"][0] + (x1 - w / 2.0) / ppt]
        ys += [l["shift"][1] + (y0 - h / 2.0) / ppt, l["shift"][1] + (y1 - h / 2.0) / ppt]
    return min(xs) - marge, min(ys) - marge, max(xs) + marge, max(ys) + marge


def z1(src, robot, dest, zoom=1):
    """Pose du robot, vrai béhémoth, vrai spidertron, côte à côte."""
    mod, titre, _, largeur, hauteur = NOMS[robot]
    ppt = 64 if zoom == 2 else 32
    moi = K.own(src, robot + "-pose", ("shadow", "main", "glow"))
    bx = cadre(moi)
    H_t = max(9.5, bx[3] - bx[1])
    oy = max(6.6, -bx[1]) if robot == "couronne" else 6.6
    cases = [(titre.split(",")[0], max(3.0, bx[2] - bx[0]), moi),
             ("Vrai behemoth-biter", 8.5, behemoth()),
             ("Vrai spidertron", 9.5, spidertron())]
    x_moi = -bx[0] if bx[2] - bx[0] >= 3.0 else 1.5 - (bx[0] + bx[2]) / 2.0
    gap, hd, lab = 6, 34, 26
    cw = [int(c[1] * ppt) for c in cases]
    W = sum(cw) + (len(cases) + 1) * gap
    ch = int(H_t * ppt)
    sheet = Image.new("RGB", (W, hd + ch + lab + gap), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 7), "%s · zoom %d du jeu (%d px par tuile), rendu de jour" % (titre, zoom, ppt), fill=(255, 205, 120), font=K.font(16))
    x = gap
    for (t, wt, lays), w_ in zip(cases, cw):
        day, _, _ = K.compose([{"pos": (x_moi if lays is moi else wt / 2.0, oy), "layers": lays}], wt, H_t)
        img = K.down2(day) if zoom == 1 else day
        sheet.paste(K.to_im(img), (x, hd))
        dr.text((x + 5, hd + ch + 5), t, fill=(235, 235, 235), font=K.font(13))
        x += w_ + gap
    _regle(sheet, gap + 6, hd + 6, 2 if robot == "trotte" else 4, ppt)
    sheet.save(dest, optimize=True)
    print(dest, sheet.size)


def gros(src, robot, dest):
    """Gros plan : le sprite tel que le jeu l'aura (64 px/tuile, agrandi au pixel), puis le rendu à plus forte définition si la variante existe."""
    mod, titre, _, largeur, hauteur = NOMS[robot]
    meta = piece.ROBOTS[robot]
    cases = []
    lays = K.own(src, robot + "-pose", ("shadow", "main", "glow"))
    bx = cadre([l for l in lays if l["kind"] == "main"], marge=0.45)     # cadré sur le robot : l'ombre peut sortir de l'image
    wt, ht = bx[2] - bx[0], bx[3] - bx[1]
    pos = (-bx[0], -bx[1])
    if robot == "couronne":
        day, _, _ = K.compose([{"pos": pos, "layers": lays}], wt, ht)
        im = K.to_im(day)
        im.save(dest, optimize=True)
        print(dest, im.size)
        return
    ppt = int(meta["gros"] or 128)
    day64, _, _ = K.compose([{"pos": pos, "layers": lays}], wt, ht)
    k = ppt // 64
    g1 = K.to_im(day64).resize((day64.shape[1] * k, day64.shape[0] * k), Image.NEAREST)
    cases.append(("Le sprite du jeu : 64 px par tuile, agrandi × %d au pixel" % k, g1))
    if K.spec_of(src, robot + "-gros"):
        lay = K.own(src, robot + "-gros", ("shadow", "main", "glow"))
        day2, _, _ = K.compose([{"pos": pos, "layers": lay}], wt, ht, ppt=ppt)
        cases.append(("Rendu à %d px par tuile, pour juger le dessin (le jeu n'aura pas cette finesse)" % ppt, K.to_im(day2)))
    W = sum(c[1].size[0] for c in cases) + 6 * (len(cases) + 1)
    H = cases[0][1].size[1] + 40
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    x = 6
    for t, im in cases:
        sheet.paste(im, (x, 34))
        dr.text((x + 4, 9), t, fill=(255, 205, 120), font=K.font(15))
        x += im.size[0] + 6
    sheet.save(dest, optimize=True)
    print(dest, sheet.size)


def marche(src, robot, dest):
    """Fenêtre FIXE sur le sol : chaque case montre le même morceau de sol ; le robot y avance, le trait rouge marque le pied d'appui
    (repère du sol) : s'il ne bouge pas d'une case à l'autre, le pied ne glisse pas. Écrit aussi les mesures dans <dest>.json."""
    mod_nom, titre, _, largeur, hauteur = NOMS[robot]
    mod = importlib.import_module(mod_nom)
    n = piece.ROBOTS[robot]["images"]
    ppt_case = 32 if robot == "couronne" else 64
    cx, sx = math.cos(mod.CAP), math.sin(mod.CAP)
    pas = mod.PAS * getattr(mod, "ECH", 1.0)
    couches = [K.own(src, "%s-m%02d" % (robot, i), ("shadow", "main", "glow")) for i in range(n)]
    boites = [cadre([l for l in c if l["kind"] == "main"], marge=0.45) for c in couches]     # cadré sur le robot, pas sur son ombre
    bx = (min(b[0] for b in boites) - abs(cx) * pas / 2.0, min(b[1] for b in boites) - abs(sx) * pas * C.COS_T / 2.0,
          max(b[2] for b in boites) + abs(cx) * pas / 2.0, max(b[3] for b in boites) + abs(sx) * pas * C.COS_T / 2.0)
    lw, H_t = bx[2] - bx[0], bx[3] - bx[1]
    x_org, oy = -bx[0], -bx[1]
    col = 4 if n <= 4 else n // 2
    rangs = int(math.ceil(n / float(col)))
    cw, ch = int(lw * ppt_case), int(H_t * ppt_case)
    W = col * cw + (col + 1) * 6
    H = 34 + rangs * (ch + 24)
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), "%s · marche, %d images d'un cycle · pas %.2f tuiles · même morceau de sol dans chaque case · trait rouge : pied d'appui" % (titre, n, pas),
            fill=(255, 205, 120), font=K.font(15))
    mesures = {"robot": robot, "images": n, "pas_tuiles": pas, "distance_per_frame": pas / n, "appuis": []}
    for i in range(n):
        ph = i / float(n)
        d = ph - 0.5
        pos = (x_org + cx * d * pas, oy - sx * d * pas * C.COS_T)
        lays = couches[i]
        day, _, _ = K.compose([{"pos": pos, "layers": lays}], lw, H_t)
        img = K.down2(day) if ppt_case == 32 else day
        im = K.to_im(img)
        dcase = ImageDraw.Draw(im)
        sq = mod.squelette(ph)
        racine = sq.local["racine"]
        for nom in sorted(sq.marques):
            m = sq.marques[nom]
            if not m["appui"]:
                continue
            X, Y = racine[0][0] * m["pied"][0] + racine[0][1] * m["pied"][1] + racine[0][2] * m["pied"][2], racine[1][0] * m["pied"][0] + racine[1][1] * m["pied"][1] + racine[1][2] * m["pied"][2]
            sxp = pos[0] + X
            syp = pos[1] - Y * C.COS_T
            px, py = sxp * ppt_case, syp * ppt_case
            dcase.line((px - 6, py + 2, px + 6, py + 2), fill=(255, 40, 30), width=2)
            mesures["appuis"].append({"image": i, "pied": nom, "x_px_64": round(sxp * 64, 2), "y_px_64": round(syp * 64, 2)})
        c = i % col
        l = i // col
        x, y = 6 + c * (cw + 6), 34 + l * (ch + 24)
        sheet.paste(im, (x, y))
        dr.text((x + 5, y + ch + 3), "image %d / %d" % (i + 1, n), fill=(235, 235, 235), font=K.font(13, False))
    sheet.save(dest, optimize=True)
    # glissement mesuré à l'écran : même pied, images consécutives en appui
    pire = 0.0
    par = {}
    for a in mesures["appuis"]:
        par.setdefault(a["pied"], []).append(a)
    for nom, l in par.items():
        for a, b in zip(l, l[1:]):
            if b["image"] == a["image"] + 1:
                pire = max(pire, abs(a["x_px_64"] - b["x_px_64"]), abs(a["y_px_64"] - b["y_px_64"]))
    mesures["glissement_max_px_hr_a_l_ecran"] = pire
    json.dump(mesures, open(dest[:-4] + ".json", "w", encoding="utf-8", newline="\n"), indent=1)
    print(dest, sheet.size, "glissement max à l'écran : %.2f px HR" % pire)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--robots", default="trotte,levite,couronne")
    ap.add_argument("--quoi", default="z1,gros,marche")
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for r in [x for x in a.robots.split(",") if x]:
        for q in a.quoi.split(","):
            p = os.path.join(a.dest, "%s-%s.png" % (r, q))
            if q == "z1":
                z1(a.src, r, p)
            elif q == "gros":
                gros(a.src, r, p)
            elif q == "marche":
                marche(a.src, r, p)


if __name__ == "__main__":
    main()
