"""Tourelle laser, lot V3 phase 1 : planches (Python système). Sorties : docs/epoques/planches/laser/*.png.

    python tools/render/pieces/levels/laser/boards_laser.py [--dir E]

(a) laser-a-niveaux-zoom1-jour.png : les 30 niveaux, 15 colonnes (époques) × 2 rangées (impair, pair), zoom 1
    (32 px/tuile), sur le sol vanilla hr-dirt-4, avec les ombres, de jour ;
(b) laser-b-niveaux-zoom1-nuit.png : la même de nuit (LUT de nuit + carte des lumières, comme la maquette V0) ;
(c) laser-c-niveaux-zoom1-gris.png : la même en niveaux de gris (test du gris D1-1) ;
(d) laser-d-vignettes.png : les 15 niveaux impairs en masques noirs, même échelle (le plus grand tient dans 64 px),
    une rangée par pose N, E, S, O, puis une rangée mélangée (clé dans laser-d-vignettes-cle.txt) ;
(e) laser-e-gros-plans-zoom2-{jour,nuit}.png : époques 1, 5, 10, 15 au zoom 2 (64 px/tuile, sprites hr 1:1),
    à côté du sprite vanilla du niveau 1 ;
(f) laser-f-poses-zoom1-jour.png : les 30 niveaux dans les 4 directions de tête (contrôle des poses).
Composition hors moteur : compose_laser.py (ordre des couches du moteur, nuit sans lightMul/lightAdd : non prouvée).
"""
import argparse
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compose_laser as CL  # noqa: E402
import laser_design as D  # noqa: E402

MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", ".."))
DEST = os.path.join(MOD, "docs", "epoques", "planches", "laser")
PPT = 64


def font(size):
    for name in ("arial.ttf", "DejaVuSans.ttf", "segoeui.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def save(img, name):
    os.makedirs(DEST, exist_ok=True)
    p = os.path.join(DEST, name)
    img.save(p, optimize=True)
    print("[planche] %s %dx%d %.0f Ko" % (p, img.width, img.height, os.path.getsize(p) / 1024))
    return p


def label_band(img, texts, height, fsize, bg=(24, 22, 20), fg=(235, 225, 200)):
    """Ajoute un bandeau de libellés : texts = [(x_centre, texte)]."""
    out = Image.new("RGB", (img.width, img.height + height), bg)
    out.paste(img, (0, height))
    dr = ImageDraw.Draw(out)
    f = font(fsize)
    for x, t in texts:
        w = dr.textlength(t, font=f)
        dr.text((x - w / 2, (height - fsize) / 2 - 1), t, fill=fg, font=f)
    return out


def row_scene(levels, direction, spacing_t=3.0, top_t=4.0, bottom_t=1.6, margin_t=1.0):
    W = int((margin_t * 2 + spacing_t * (len(levels) - 1) + 2.4) * PPT)
    H = int((top_t + bottom_t) * PPT)
    ents = []
    xs = []
    for i, lv in enumerate(levels):
        x = (margin_t + 0.8 + i * spacing_t) * PPT
        ents.append({"pos": (x, top_t * PPT), "layers": CL.level_layers(lv, direction)})
        xs.append(x)
    return ents, W, H, xs


def board_levels(direction):
    """(a), (b), (c) : 2 rangées de 15 (impairs en haut, pairs en bas), zoom 1."""
    rows = {}
    for name, levels in (("impair", [2 * e - 1 for e in D.EPOCHS]), ("pair", [2 * e for e in D.EPOCHS])):
        ents, W, H, xs = row_scene(levels, direction)
        day, night, _ = CL.compose(ents, W, H)
        rows[name] = (CL.down2(day), CL.down2(night), [x / 2 for x in xs], levels)
    out = {}
    for k, idx in (("jour", 0), ("nuit", 1)):
        imgs = []
        for name in ("impair", "pair"):
            arr, xs, levels = rows[name][idx], rows[name][2], rows[name][3]
            im = CL.to_img(arr)
            im = label_band(im, [(x, "niv. %d" % lv) for x, lv in zip(xs, levels)], 16, 12)
            imgs.append(im)
        W = imgs[0].width
        head = Image.new("RGB", (W, 34), (24, 22, 20))
        dr = ImageDraw.Draw(head)
        f = font(12)
        for e, x in zip(D.EPOCHS, rows["impair"][2]):
            t1 = "ép. %d" % e
            t2 = D.EPOCH_NAME[e]
            dr.text((x - dr.textlength(t1, font=f) / 2, 2), t1, fill=(235, 225, 200), font=f)
            dr.text((x - dr.textlength(t2, font=f) / 2, 17), t2, fill=(200, 190, 160), font=f)
        full = Image.new("RGB", (W, head.height + sum(i.height for i in imgs)), (24, 22, 20))
        full.paste(head, (0, 0))
        y = head.height
        for im in imgs:
            full.paste(im, (0, y))
            y += im.height
        out[k] = full
    return out


def board_gray(day_img):
    a = np.asarray(day_img).astype(np.float64) / 255.0
    lin = np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    y = lin @ np.array([0.2126, 0.7152, 0.0722])
    g = np.where(y <= 0.0031308, y * 12.92, 1.055 * y ** (1 / 2.4) - 0.055)
    return Image.fromarray(np.clip(np.round(g * 255), 0, 255).astype(np.uint8), "L").convert("RGB")


def board_vignettes(seed=20261021):
    """(d) : masques noirs à la même échelle (le plus grand tient dans 64 px), ancrés sur la position de l'entité."""
    levels = [2 * e - 1 for e in D.EPOCHS]
    masks = {(lv, d): CL.mask_of(lv, d) for lv in levels for d in ("N", "E", "S", "W")}
    union = np.zeros_like(next(iter(masks.values())))
    for m in masks.values():
        union |= m
    ys, xs = np.nonzero(union)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    side = max(x1 - x0, y1 - y0)
    s = 64.0 / side
    cell = 72

    def vign(m):
        sub = m[y0:y0 + side, x0:x0 + side].astype(np.float32)
        pad = np.zeros((side, side), np.float32)
        pad[:sub.shape[0], :sub.shape[1]] = sub
        im = Image.fromarray((pad * 255).astype(np.uint8), "L").resize((64, 64), Image.BOX)
        a = np.asarray(im) >= 128
        tile = np.full((cell, cell), 255, np.uint8)
        tile[4:68, 4:68][a] = 0
        return tile

    rows = []
    names = []
    for d in ("N", "E", "S", "W"):
        rows.append([vign(masks[(lv, d)]) for lv in levels])
        names.append("pose %s" % d)
    rnd = random.Random(seed)
    perm = list(range(15))
    rnd.shuffle(perm)
    letters = "ABCDEFGHIJKLMNO"
    rows.append([vign(masks[(levels[i], "N")]) for i in perm])
    names.append("mélangée (N)")
    lab_w = 110
    W = lab_w + cell * 15
    H = 22 + cell * len(rows) + 18 * len(rows)
    img = Image.new("RGB", (W, H), (255, 255, 255))
    dr = ImageDraw.Draw(img)
    f = font(12)
    for i, lv in enumerate(levels):
        t = "niv. %d" % lv
        dr.text((lab_w + i * cell + cell / 2 - dr.textlength(t, font=f) / 2, 4), t, fill=(0, 0, 0), font=f)
    y = 22
    for r, (row, nm) in enumerate(zip(rows, names)):
        dr.text((6, y + cell / 2 - 7), nm, fill=(0, 0, 0), font=f)
        for i, tile in enumerate(row):
            img.paste(Image.fromarray(tile, "L").convert("RGB"), (lab_w + i * cell, y))
            if r == 4:
                t = letters[i]
                dr.text((lab_w + i * cell + cell / 2 - 4, y + cell), t, fill=(160, 0, 0), font=f)
        y += cell + 18
    key = ["Planche (d), rangée mélangée (pose N) : lettre -> niveau (époque)"]
    for i, p in enumerate(perm):
        key.append("%s -> niveau %d (époque %d)" % (letters[i], levels[p], D.epoch_of(levels[p])))
    key.append("Échelle commune : %.4f px de vignette par px hr (le plus grand masque, toutes poses : %d px hr)" % (s, side))
    return img, "\n".join(key) + "\n"


def board_closeups():
    """(e) : époques 1, 5, 10, 15 au zoom 2, à côté du vanilla niveau 1 ; pose de tête E et S."""
    rows_day, rows_night = [], []
    for e in (1, 5, 10, 15):
        levels = [1] + ([2] if e == 1 else [2 * e - 1, 2 * e])
        ents = []
        sp = 3.4
        W = int((len(levels) * 2 * sp + 0.6) * PPT)
        H = int(5.6 * PPT)
        labels = []
        i = 0
        for lv in levels:
            for d in ("E", "S"):
                x = (1.5 + i * sp) * PPT
                ents.append({"pos": (x, 4.0 * PPT), "layers": CL.level_layers(lv, d)})
                labels.append((x, "niv. %d %s%s" % (lv, d, " (vanilla)" if lv == 1 else "")))
                i += 1
        day, night, _ = CL.compose(ents, W, H)
        title = "Époque %d · %s" % (e, D.EPOCH_NAME[e])
        for arr, rows in ((day, rows_day), (night, rows_night)):
            im = label_band(CL.to_img(arr), labels, 20, 14)
            im = label_band(im, [(im.width / 2, title)], 22, 15)
            rows.append(im)
    out = {}
    for k, rows in (("jour", rows_day), ("nuit", rows_night)):
        W = max(r.width for r in rows)
        full = Image.new("RGB", (W, sum(r.height for r in rows)), (24, 22, 20))
        y = 0
        for r in rows:
            full.paste(r, (0, y))
            y += r.height
        out[k] = full
    return out


def board_poses():
    """(f) : les 30 niveaux, têtes N, E, S, O, zoom 1 ; 2 niveaux par rangée."""
    rows = []
    for r in range(15):
        lvs = [2 * r + 1, 2 * r + 2]
        ents, labels = [], []
        sp = 2.8
        i = 0
        for lv in lvs:
            for d in ("N", "E", "S", "W"):
                x = (1.2 + i * sp + (0.8 if lv % 2 == 0 else 0)) * PPT
                ents.append({"pos": (x, 4.0 * PPT), "layers": CL.level_layers(lv, d)})
                labels.append((x / 2, "%d %s" % (lv, d)))
                i += 1
        W = int((1.2 + 8 * sp + 1.6) * PPT)
        H = int(5.5 * PPT)
        day, _, _ = CL.compose(ents, W, H)
        rows.append(label_band(CL.to_img(CL.down2(day)), labels, 14, 11))
    W = rows[0].width
    full = Image.new("RGB", (W, sum(r.height for r in rows)), (24, 22, 20))
    y = 0
    for r in rows:
        full.paste(r, (0, y))
        y += r.height
    return full


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="E", help="direction de tête des planches a, b, c")
    ap.add_argument("--only", default="abcdef")
    a = ap.parse_args()
    paths = []
    if any(c in a.only for c in "abc"):
        b = board_levels(a.dir)
        paths.append(save(b["jour"], "laser-a-niveaux-zoom1-jour.png"))
        paths.append(save(b["nuit"], "laser-b-niveaux-zoom1-nuit.png"))
        paths.append(save(board_gray(b["jour"]), "laser-c-niveaux-zoom1-gris.png"))
    if "d" in a.only:
        img, key = board_vignettes()
        paths.append(save(img, "laser-d-vignettes.png"))
        with open(os.path.join(DEST, "laser-d-vignettes-cle.txt"), "w", encoding="utf-8", newline="\n") as f:
            f.write(key)
    if "e" in a.only:
        c = board_closeups()
        paths.append(save(c["jour"], "laser-e-gros-plans-zoom2-jour.png"))
        paths.append(save(c["nuit"], "laser-e-gros-plans-zoom2-nuit.png"))
    if "f" in a.only:
        paths.append(save(board_poses(), "laser-f-poses-zoom1-jour.png"))
    return paths


if __name__ == "__main__":
    main()
