"""Planches du four (lot V3, phase 1) : docs/epoques/planches/furnace/*.png.

    python -P tools/render/pieces/levels/furnace/planches.py            # toutes les planches
    python -P tools/render/pieces/levels/furnace/planches.py --preview 2,3 --dst <fichier.png>

(a) galerie-jour-zoom1 : les 30 niveaux au zoom 1 (32 px/tuile), sur le sol vanilla hr-dirt-4, avec ombres ;
    une colonne par époque (niveau impair en haut, niveau pair en bas) ;
(b) galerie-nuit-zoom1 : la même de nuit (LUT de nuit du jeu, halos et lueurs) ;
(c) galerie-gris-zoom1 : la même en niveaux de gris (test du gris D1-1) ;
(d) vignettes-64 : les 15 niveaux impairs en masques noirs à la MÊME échelle (le plus grand tient dans 64 px),
    dans l'ordre, puis mélangés (lettres ; la clé est dans planches.json) : test de la vignette D1-2 ;
(e) gros-plan-eNN-zoom2 : les 15 époques (correction V3, OBJECTIFS D3-2 : « une revue en gros plan aux zooms
    1 et 2 pour chaque famille et chaque époque » ; le premier jet n'en avait que 4) au zoom 2 (64 px/tuile, HR
    1:1), niveau impair et niveau pair à côté du four vanilla du niveau 1 ; trois bandes : jour EN MARCHE, jour
    À L'ARRÊT (ni feu ni halo : seules les lueurs de décor always_draw restent), nuit en marche ;
(g) situation-zoom1 : 3 fours côte à côte (rangée serrée) aux niveaux 1, 16 et 29, plates-formes d'inserteurs
    vanilla au sud (sans bras) et courroie vanilla : lecture de l'emprise, chevauchements, ancrage au sol
    (correction V3 : la capture en moteur demandée reste à faire, phase 2).
Composition : compose.py (formules de tools/render/calib/maquette.py). Rien n'est prouvé en moteur réel.
"""
import argparse
import json
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compose as CP  # noqa: E402
import params as PRM  # noqa: E402

MOD_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", ".."))
DST = os.path.join(MOD_ROOT, "docs", "epoques", "planches", "furnace")


def font(size):
    for f in ("C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def gallery(levels_grid, col_w=3.6, row_h=5.0, top_pad=0.3, working=True):
    """levels_grid : liste de colonnes, chaque colonne = liste de niveaux (lignes). Renvoie (jour, lumière, positions)."""
    ncol = len(levels_grid)
    nrow = max(len(c) for c in levels_grid)
    ents, pos = [], {}
    for i, col in enumerate(levels_grid):
        for j, n in enumerate(col):
            if n is None:
                continue
            p = (round((i * col_w + 1.25) * 64) / 64.0, round((top_pad + j * row_h + 3.3) * 64) / 64.0)
            ents.append({"pos": p, "layers": CP.level_layers(n, working)})
            pos[n] = p
    day, light = CP.compose(ents, ncol * col_w, nrow * row_h + top_pad)
    return day, light, pos


def label(img, items, size=13, fill=(235, 230, 215), shadow=(0, 0, 0)):
    d = ImageDraw.Draw(img)
    f = font(size)
    for (x, y, t) in items:
        d.text((x + 1, y + 1), t, font=f, fill=shadow)
        d.text((x, y), t, font=f, fill=fill)
    return img


def galleries(meta):
    grid = [[2 * e - 1, 2 * e] for e in range(1, 16)]
    day, light, pos = gallery(grid)
    nig = CP.night(day, light)
    out = {}
    col_w = 3.6
    for name, rgb in (("galerie-jour-zoom1", day), ("galerie-nuit-zoom1", nig), ("galerie-gris-zoom1", CP.gray(day))):
        z1 = CP.down2(rgb)
        img = CP.to_img(z1)
        head = Image.new("RGB", (img.width, 34), (24, 22, 20))
        canvas = Image.new("RGB", (img.width, img.height + 34))
        canvas.paste(head, (0, 0))
        canvas.paste(img, (0, 34))
        items = []
        for e in range(1, 16):
            x = int((e - 1) * col_w * 32) + 4
            items.append((x, 2, "%d %s" % (e, PRM.EPOCHS[e]["nom"])))
            items.append((x, 17, "ère %s" % PRM.EPOCHS[e]["ere"]))
        for n, (px, py) in pos.items():
            items.append((int((px - 1.2) * 32), int((py + 0.95) * 32) + 34 - 14, "n%d" % n))
        label(canvas, items[:30], 12)
        label(canvas, items[30:], 12, fill=(255, 255, 255))
        if name.startswith("galerie-gris"):
            canvas = canvas.convert("L").convert("RGB")
        path = os.path.join(DST, name + ".png")
        canvas.save(path, optimize=True)
        out[name] = path
    return out


def vignettes(meta):
    cv = CP.mask_canvas(-2.5, 2.5, -3.5, 1.75)
    odds = [2 * e - 1 for e in range(1, 16)]
    masks = {n: CP.objmask(n, cv) for n in odds}
    # boîte commune de la plus grande silhouette (même échelle pour toutes) : côté max en pixels HR
    side = 0
    boxes = {}
    for n, m in masks.items():
        ys, xs = np.nonzero(m)
        boxes[n] = (xs.min(), xs.max() + 1, ys.min(), ys.max() + 1)
        side = max(side, xs.max() + 1 - xs.min(), ys.max() + 1 - ys.min())
    k = 64.0 / side
    # cadre commun : centré en x sur l'origine, bas commun au bas de l'emprise (y = +1)
    ox = (0 - cv["x0"]) * CP.PPT
    oy = (1.05 - cv["y0"]) * CP.PPT
    cells = {}
    for n, m in masks.items():
        im = Image.fromarray((~m * 255).astype(np.uint8), "L")
        x0, y0 = int(round(ox - side / 2)), int(round(oy - side))
        crop = im.crop((x0, y0, x0 + side, y0 + side)).resize((64, 64), Image.BOX)
        cells[n] = crop.point(lambda v: 0 if v < 128 else 255)
    rnd = random.Random(20261021)
    shuffled = odds[:]
    rnd.shuffle(shuffled)
    letters = "ABCDEFGHIJKLMNO"
    pad, lab = 10, 18
    W = 15 * (64 + pad) + pad
    H = 2 * (64 + lab + pad) + pad + 20
    img = Image.new("L", (W, H), 255)
    d = ImageDraw.Draw(img)
    f = font(12)
    d.text((pad, 2), "Dans l'ordre (niveaux impairs = époques 1 à 15)", font=f, fill=0)
    for i, n in enumerate(odds):
        x = pad + i * (64 + pad)
        img.paste(cells[n], (x, 20))
        d.rectangle((x - 1, 19, x + 64, 84), outline=200)
        d.text((x + 2, 86), "e%d n%d" % (PRM.epoch_of(n), n), font=f, fill=0)
    y2 = 20 + 64 + lab + pad
    d.text((pad, y2 - 2), "Mélangées (clé : planches.json)", font=f, fill=0)
    for i, n in enumerate(shuffled):
        x = pad + i * (64 + pad)
        img.paste(cells[n], (x, y2 + 14))
        d.rectangle((x - 1, y2 + 13, x + 64, y2 + 78), outline=200)
        d.text((x + 26, y2 + 80), letters[i], font=f, fill=0)
    big = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
    p1 = os.path.join(DST, "vignettes-64.png")
    big.convert("RGB").save(p1, optimize=True)
    meta["vignettes"] = {"echelle_px_par_tuile": round(64.0 / side * CP.PPT, 3), "cote_max_px_hr": int(side),
                         "cle_melange": {letters[i]: "n%d (époque %d)" % (n, PRM.epoch_of(n)) for i, n in enumerate(shuffled)},
                         "note": "image agrandie ×2 au plus proche : chaque vignette fait 64 × 64 px avant agrandissement"}
    return {"vignettes-64": p1}


def closeups(meta):
    out = {}
    for e in range(1, 16):
        cols = [1] if e == 1 else [1, 2 * e - 1]
        cols += [2 * e]
        grid = [[n] for n in cols]
        day, light, pos = gallery(grid, col_w=3.8, row_h=4.7, top_pad=0.15)
        off, _l, _p = gallery(grid, col_w=3.8, row_h=4.7, top_pad=0.15, working=False)
        nig = CP.night(day, light)
        bands = [("jour, en marche", CP.to_img(day)), ("jour, à l'arrêt (sans feu ni halo)", CP.to_img(off)),
                 ("nuit, en marche", CP.to_img(nig))]
        h = bands[0][1].height
        W = bands[0][1].width
        canvas = Image.new("RGB", (W, 24 + 3 * (h + 20)), (24, 22, 20))
        items = [(6, 4, "Époque %d · %s (ère %s) · zoom 2 (64 px/tuile)" % (e, PRM.EPOCHS[e]["nom"], PRM.EPOCHS[e]["ere"]))]
        for j, (title, im) in enumerate(bands):
            y = 24 + j * (h + 20)
            canvas.paste(im, (0, y + 20))
            items.append((6, y + 2, title))
            for i, n in enumerate(cols):
                t = "n1 vanilla" if n == 1 else "n%d" % n
                items.append((int(i * 3.8 * 64) + 8, y + 24, t))
        label(canvas, items, 15)
        p = os.path.join(DST, "gros-plan-e%02d-zoom2.png" % e)
        canvas.save(p, optimize=True)
        out["gros-plan-e%02d" % e] = p
    return out


def situation(meta):
    """(g) Mise en situation hors moteur : rangées serrées de 3 fours (niveaux 1, 16, 29), inserteurs et courroie."""
    ent_dir = os.path.join(CP.DATA, "base", "graphics", "entity")
    plat = CP.frame(CP.load(os.path.join(ent_dir, "inserter", "hr-inserter-platform.png")), 105, 79, 0)
    belt = CP.frame(CP.load(os.path.join(ent_dir, "transport-belt", "hr-transport-belt.png")), 128, 128, 0, 0)
    rows = [1, 16, 29]
    row_h = 6.0
    ents = []
    for j, n in enumerate(rows):
        y0 = 3.0 + j * row_h                   # entité 2×2 : centre sur un nœud de la grille
        for i in range(3):
            x = 1.0 + 2 * i
            ents.append({"pos": (x, y0), "layers": CP.level_layers(n)})
            ents.append({"pos": (x - 0.5, y0 + 1.5), "layers": [{"img": plat, "shift": CP.bp(1.5, 6.5), "kind": "main"}]})
        for t in range(7):
            ents.append({"pos": (0.5 + t, y0 + 2.5), "layers": [{"img": belt, "shift": (0.0, 0.0), "kind": "main"}]})
    W_t, H_t = 7.0, row_h * len(rows) + 0.4
    day, light = CP.compose(ents, W_t, H_t)
    z1 = CP.to_img(CP.down2(day))
    nig = CP.to_img(CP.down2(CP.night(day, light)))
    canvas = Image.new("RGB", (z1.width * 2 + 8, z1.height + 24), (24, 22, 20))
    canvas.paste(z1, (0, 24))
    canvas.paste(nig, (z1.width + 8, 24))
    items = [(6, 4, "Situation (zoom 1) : rangées serrées, inserteurs (plates-formes vanilla) et courroie au sud · jour | nuit")]
    for j, n in enumerate(rows):
        items.append((4, 24 + int((0.2 + j * row_h) * 32), "n%d" % n))
    label(canvas, items, 13)
    p = os.path.join(DST, "situation-zoom1.png")
    canvas.save(p, optimize=True)
    return {"situation": p}


def overlay_d13(meta):
    """(f) D1-3 : masques du niveau 1 (bleu) et du niveau 30 (orange), même origine, 64 px/tuile ; blanc =
    intersection. Masques sans couches plates au sol (voir measure_d1.py)."""
    cv = CP.mask_canvas(-2.5, 2.5, -3.5, 1.75)
    m1, m30 = CP.objmask(1, cv), CP.objmask(30, cv)
    img = np.full(m1.shape + (3,), 40, np.uint8)
    img[m1 & ~m30] = (70, 130, 230)
    img[m30 & ~m1] = (240, 140, 40)
    img[m1 & m30] = (235, 235, 235)
    # emprise 2×2 en pointillés
    ox, oy = int(-cv["x0"] * CP.PPT), int(-cv["y0"] * CP.PPT)
    for t in range(-64, 64, 4):
        for (x, y) in ((ox + t, oy - 64), (ox + t, oy + 63), (ox - 64, oy + t), (ox + 63, oy + t)):
            img[y, x] = (160, 160, 160)
    im = Image.fromarray(img, "RGB")
    canvas = Image.new("RGB", (im.width, im.height + 40), (24, 22, 20))
    canvas.paste(im, (0, 40))
    u = (m1 | m30).sum()
    label(canvas, [(6, 4, "D1-3 : n1 vanilla (bleu) / n30 (orange) / commun (blanc)"),
                   (6, 21, "IoU = %.3f ; emprise 2×2 en pointillés" % ((m1 & m30).sum() / u))], 13)
    p = os.path.join(DST, "d1-3-superposition.png")
    canvas.save(p, optimize=True)
    return {"d1-3-superposition": p}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default="")
    ap.add_argument("--dst", default="")
    ap.add_argument("--night", action="store_true")
    a = ap.parse_args()
    if a.preview:
        lv = [int(x) for x in a.preview.split(",")]
        day, light, _ = gallery([[n] for n in lv], col_w=3.8, row_h=4.7, top_pad=0.15)
        rgb = CP.night(day, light) if a.night else day
        CP.to_img(rgb).save(a.dst)
        print(a.dst)
        return
    os.makedirs(DST, exist_ok=True)
    meta = {"source": "tools/render/pieces/levels/furnace/planches.py", "rendus": "tools/render/out/levels/furnace (aperçu)",
            "echantillons": sorted({CP.spec(n)["samples"] for n in PRM.RENDERED})}
    files = {}
    files.update(galleries(meta))
    files.update(vignettes(meta))
    files.update(closeups(meta))
    files.update(situation(meta))
    files.update(overlay_d13(meta))
    meta["fichiers"] = {k: os.path.relpath(v, MOD_ROOT).replace("\\", "/") for k, v in files.items()}
    with open(os.path.join(DST, "planches.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f, indent=1, ensure_ascii=False, sort_keys=True)
    for k, v in sorted(files.items()):
        print("%-22s %s (%d Ko)" % (k, v, os.path.getsize(v) // 1024))


if __name__ == "__main__":
    main()
