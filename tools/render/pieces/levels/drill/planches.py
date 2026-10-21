"""Planches de la foreuse électrique (lot V3, phase 1) : composition hors moteur des aperçus rendus.

    python -P tools/render/pieces/levels/drill/planches.py [--quick] [--dest docs/epoques/planches/drill]
           [--data "<racine>/data"]

Planches (PNG compacts, versionnés) :
  a-jour-zoom1.png        les 30 niveaux, pose N, au zoom 1 (32 px/tuile) sur la tuile de sol vanilla
                          hr-dirt-4, avec leurs ombres, de jour ; ligne du haut = niveaux impairs
                          (nouvelle silhouette, niveau 1 = vanilla), ligne du bas = niveaux pairs (+ pièce)
  b-nuit-zoom1.png        la même de nuit (LUT lut-night.png, carte des lumières = halos + lueurs, comme
                          tools/render/calib/maquette.py)
  c-gris-zoom1.png        la même en niveaux de gris (test du gris D1-1)
  d-vignettes.png         les 15 niveaux impairs en masques noirs, à la même échelle, le plus grand dans
                          64 px (test de la vignette D1-2), dans l'ordre ; d-vignettes-melangees.png : le
                          même jeu mélangé (lettres), la clé est dans d-vignettes-cle.txt
  e-gros-plans-zoom2-*.png  époques 1, 5, 10, 15 au zoom 2 (64 px/tuile, sprites hr 1:1) : vanilla
                          (niveau 1), niveau impair, niveau pair ; jour puis nuit
  f-directions-zoom1.png  les 30 niveaux dans les 4 directions (N, E, S, O), de jour, zoom 1
Composition (comme maquette.py, CALIBRATION §6) : ombres au maximum des alphas puis sol × (1 − 0,5 a) ;
corps par-dessus (sRGB codé, comme le tampon du moteur) ; lueur additive (jour) et dans la carte des
lumières ; nuit = mix(LUT_nuit(jour), jour, lumière bornée). lightMul et lightAdd du moteur : inconnus
(pris à 1 et 0) ; les lumières propres de la foreuse vanilla (DEL d'état, lumière de travail) ne sont
pas composées (foreuse à l'arrêt). NON PROUVÉ en moteur.
"""
import argparse
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(RENDER, "calib"))
import fo_post as P  # noqa: E402
import levels_io as IO  # noqa: E402
from maquette import lut_apply  # noqa: E402  (lecture seule du pipeline partagé)

DEFAULT_DATA = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data"
LUMA = np.array([0.2126, 0.7152, 0.0722])
# cadre d'une cellule (tuiles, autour de la position de l'entité) : sommet du niveau 30 compris
CX0, CX1, CY0, CY1 = -2.0, 2.75, -4.5, 2.0


def ground(data, h, w):
    g = np.asarray(Image.open(os.path.join(data, "base", "graphics", "terrain", "hr-dirt-4.png")).convert("RGB"))
    g = g[320:576].astype(np.float64) / 255.0
    reps = (h // g.shape[0] + 1, w // g.shape[1] + 1, 1)
    return np.tile(g, reps)[:h, :w].copy()


def cell(lay, data, light_extra=True):
    """Compose un niveau sur le sol : renvoie (jour, nuit) RGB du cadre de cellule (64 px/tuile)."""
    ox, oy = IO.ORIGIN
    x0, x1 = int(ox + CX0 * 64), int(ox + CX1 * 64)
    y0, y1 = int(oy + CY0 * 64), int(oy + CY1 * 64)
    h, w = y1 - y0, x1 - x0
    day = ground(data, h, w)
    sh = lay["shadow"][y0:y1, x0:x1] if lay["shadow"] is not None else np.zeros((h, w))
    day = day * (1 - 0.5 * sh)[..., None]
    m = lay["main"][y0:y1, x0:x1]
    a = m[..., 3:4]
    day = m[..., :3] * a + day * (1 - a)
    light = np.zeros((h, w, 3))
    if lay.get("glow") is not None:
        g = lay["glow"][y0:y1, x0:x1]
        pm = g[..., :3] * g[..., 3:4]
        day = np.clip(day + pm, 0, 1)
        light += pm
    if lay.get("light") is not None:
        li = lay["light"][y0:y1, x0:x1]
        light += li[..., :3] * li[..., 3:4]
    light = np.clip(light, 0, 1)
    night = lut_apply(day, os.path.join(data, "core", "graphics", "color_luts", "lut-night.png"))
    night = night * (1 - light) + day * light
    return day, night


def down2(rgb):
    h, w = rgb.shape[:2]
    lin = P.srgb_to_lin(rgb[:h // 2 * 2, :w // 2 * 2])
    lin = lin.reshape(h // 2, 2, w // 2, 2, 3).mean((1, 3))
    return P.lin_to_srgb(lin)


def to_img(rgb):
    return Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")


def grid(cells, cols, labels, pad=6, bg=(24, 24, 24), lab_h=14):
    """Assemble des images RGB (listes de lignes) avec une étiquette au-dessus de chaque cellule."""
    ch = max(c.shape[0] for row in cells for c in row if c is not None)
    cw = max(c.shape[1] for row in cells for c in row if c is not None)
    rows = len(cells)
    W = cols * (cw + pad) + pad
    H = rows * (ch + pad + lab_h) + pad
    out = Image.new("RGB", (W, H), bg)
    dr = ImageDraw.Draw(out)
    for r, row in enumerate(cells):
        for c, im in enumerate(row):
            if im is None:
                continue
            x = pad + c * (cw + pad)
            y = pad + r * (ch + pad + lab_h)
            dr.text((x + 2, y), labels[r][c], fill=(230, 230, 230))
            out.paste(to_img(im), (x, y + lab_h))
    return out


def save(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--dest", default=os.path.join(MOD_ROOT, "docs", "epoques", "planches", "drill"))
    ap.add_argument("--data", default=os.environ.get("FO_DATA", DEFAULT_DATA))
    a = ap.parse_args()
    spec = IO.load_spec()
    dest = a.dest
    if a.quick:
        dest = os.path.join(IO.OUT, "planches-quick")
    lays = {}
    for lvl in range(1, 31):
        for d in IO.DIRS:
            lay = IO.level_layers(spec, lvl, d, quick=a.quick)
            if lay is not None and lay["main"] is not None:
                lays[(lvl, d)] = lay
    cache = {}

    def comp(lvl, d):
        if (lvl, d) not in cache:
            cache[(lvl, d)] = cell(lays[(lvl, d)], a.data)
        return cache[(lvl, d)]

    written = []
    # (a) (b) (c) : pose N, 2 lignes × 15 époques, zoom 1
    for tag, idx, gray in (("a-jour-zoom1", 0, False), ("b-nuit-zoom1", 1, False), ("c-gris-zoom1", 0, True)):
        rows, labels = [[], []], [[], []]
        for e in range(1, 16):
            for r, lvl in enumerate((2 * e - 1, 2 * e)):
                if (lvl, "N") in lays:
                    im = down2(comp(lvl, "N")[idx])
                    if gray:
                        g = P.lin_to_srgb(P.srgb_to_lin(im) @ LUMA)
                        im = np.repeat(g[..., None], 3, -1)
                    rows[r].append(im)
                else:
                    rows[r].append(None)
                labels[r].append("niv %d (e%d)" % (lvl, e))
        written.append(save(grid(rows, 15, labels), os.path.join(dest, tag + ".png")))
    # (d) vignettes : 15 niveaux impairs, pose N, masques noirs à la même échelle (le plus grand : 64 px)
    masks = []
    for e in range(1, 16):
        lvl = 2 * e - 1
        if (lvl, "N") in lays:
            masks.append((e, lays[(lvl, "N")]["main"][..., 3] >= 0.5))
    if masks:
        ys0, ys1, xs0, xs1 = 10 ** 9, -1, 10 ** 9, -1
        for _, m in masks:
            ys, xs = np.nonzero(m)
            ys0, ys1, xs0, xs1 = min(ys0, ys.min()), max(ys1, ys.max()), min(xs0, xs.min()), max(xs1, xs.max())
        side = max(ys1 - ys0 + 1, xs1 - xs0 + 1)
        f = 64.0 / side
        th = []
        for e, m in masks:
            crop = m[ys0:ys0 + side, xs0:xs0 + side].astype(np.float64)
            im = Image.fromarray((crop * 255).astype(np.uint8), "L").resize((64, 64), Image.BOX)
            v = 1.0 - np.asarray(im).astype(np.float64) / 255.0
            th.append((e, np.repeat(v[..., None], 3, -1)))
        written.append(save(grid([[t for _, t in th]], 15, [["e%d" % e for e, _ in th]], bg=(255, 255, 255)),
                            os.path.join(dest, "d-vignettes.png")))
        rnd = random.Random(20261021)
        order = list(range(len(th)))
        rnd.shuffle(order)
        letters = "ABCDEFGHIJKLMNO"
        written.append(save(grid([[th[i][1] for i in order]], 15, [[letters[k] for k in range(len(order))]],
                                 bg=(255, 255, 255)), os.path.join(dest, "d-vignettes-melangees.png")))
        with open(os.path.join(dest, "d-vignettes-cle.txt"), "w", encoding="utf-8", newline="\n") as fk:
            fk.write("Vignettes mélangées (graine 20261021) : lettre -> époque\n")
            for k, i in enumerate(order):
                fk.write("%s -> époque %d (niveau %d)\n" % (letters[k], th[i][0], 2 * th[i][0] - 1))
            fk.write("Échelle commune : %.2f px par tuile (le plus grand cadre : %d px hr)\n" % (f * 64, side))
    # (e) gros plans zoom 2 : époques 1, 5, 10, 15
    for e in (1, 5, 10, 15):
        lv = [1, 2 * e - 1, 2 * e] if e > 1 else [1, 2]
        lv = [x for x in lv if (x, "N") in lays]
        rows = [[comp(x, "N")[0] for x in lv], [comp(x, "N")[1] for x in lv]]
        labels = [["jour niv %d%s" % (x, " (vanilla)" if x == 1 else "") for x in lv],
                  ["nuit niv %d" % x for x in lv]]
        written.append(save(grid(rows, len(lv), labels), os.path.join(dest, "e-gros-plans-zoom2-e%02d.png" % e)))
    # (f) 4 directions, zoom 1, de jour : 15 colonnes (époques) × 8 lignes (impair N E S O, pair N E S O)
    rows, labels = [], []
    for r, (par, d) in enumerate([(0, d) for d in IO.DIRS] + [(1, d) for d in IO.DIRS]):
        row, lab = [], []
        for e in range(1, 16):
            lvl = 2 * e - 1 + par
            row.append(down2(comp(lvl, d)[0]) if (lvl, d) in lays else None)
            lab.append("niv %d %s" % (lvl, d))
        rows.append(row)
        labels.append(lab)
    written.append(save(grid(rows, 15, labels), os.path.join(dest, "f-directions-zoom1.png")))
    for w in written:
        print(os.path.abspath(w))


if __name__ == "__main__":
    main()
