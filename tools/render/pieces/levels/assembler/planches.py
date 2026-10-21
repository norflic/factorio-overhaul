"""Planches de la machine d'assemblage 2 (lot V3, phase 1), à partir des rendus d'APERÇU. Python système (numpy, Pillow).

    python -P tools/render/pieces/levels/assembler/planches.py [--dest docs/epoques/planches/assembler] [--brouillon]

Compose EXACTEMENT les fichiers rendus (tools/render/out/levels/assembler/nNN/) avec leurs tailles et `shift`, comme le
moteur (même fonction que la maquette de V0, tools/render/calib/maquette.py, importée sans modification) :
ombres au maximum des alphas puis sol × (1 − 0,5 × alpha) (shadow-a8.frag), entités triées, lueur additive ; nuit =
mix(LUT_nuit(jour), jour, lumière) avec la LUT lut-night.png (game.frag), lightMul/lightAdd pris à 1 et 0 (NON PROUVÉ).
Sol : texture vanilla hr-dirt-4 (rangées opaques). Zoom 1 = 32 px/tuile (moyenne 2 × 2 des sprites hr en linéaire,
alors que le jeu filtre par mipmaps : écart possible) ; zoom 2 = 64 px/tuile (sprites hr 1:1).

Planches (bible §1.4 et consigne V3) :
  a-jour-zoom1.png        les 30 niveaux, de jour, zoom 1, ombres comprises
  b-nuit-zoom1.png        la même, de nuit
  c-gris-zoom1.png        la même, de jour, en niveaux de gris (test du gris D1-1)
  d-vignettes-masques.png les 15 niveaux impairs, masques noirs (alpha ≥ 0,5 de la couche principale), même échelle,
                          le plus grand tenant dans 64 px (test de la vignette D1-2) ; + d-vignettes-melangees.png et
                          sa clé d-vignettes-melangees-cle.txt (ordre tiré avec une graine fixe)
  e-gros-plan-epNN.png    époques 1, 5, 10, 15 au zoom 2 : vanilla (niveau 1), niveau impair, niveau pair ; jour en
                          haut, nuit en bas
"""
import argparse
import json
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(RENDER, "calib"))
import fo_post as P  # noqa: E402
import params  # noqa: E402
from maquette import compose, down2  # noqa: E402  (lecture seule : fonction de V0)

DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
CORE = os.path.join(DATA, "core")
OUT = os.path.join(RENDER, "out", "levels", params.FAMILLE)
DEST = os.path.join(MOD_ROOT, "docs", "epoques", "planches", params.FAMILLE)
CELL_W = 5.0          # largeur d'une case (tuiles) : l'ombre des niveaux hauts part loin vers l'est
TOP, BOTTOM = 4.25, 1.75  # au-dessus / au-dessous de l'origine (tuiles)


def load(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0


def font(size):
    for f in ("arialbd.ttf", "arial.ttf", "segoeui.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            continue
    return ImageFont.load_default()


def vanilla_layers():
    out = []
    for key, kind in (("shadow", "shadow"), ("main", "main")):
        v = params.VANILLA[key]
        im = load(os.path.join(DATA, "base", "graphics", "entity", v["file"]))
        w, h = v["frame"]
        out.append({"img": im[:h, :w], "shift": v["shift"], "kind": kind})
    return out


def level_layers(n):
    """Couches hr d'un niveau (ordre du moteur : ombre, principale, lueur, halo)."""
    if n == 1:
        return vanilla_layers()
    d = os.path.join(OUT, "n%02d" % n)
    with open(os.path.join(d, "n%02d.json" % n), encoding="utf-8") as f:
        rec = json.load(f)
    lays = vanilla_layers() if n == 2 else []
    for kind in ("shadow", "main", "glow", "light"):
        sd = rec["spec"].get(kind)
        if sd:
            lays.append({"img": load(os.path.join(d, sd["hr"]["filename"])), "shift": tuple(sd["hr"]["shift"]),
                         "kind": kind})
    return lays


def available():
    return [n for n in range(1, 31) if n == 1 or os.path.exists(os.path.join(OUT, "n%02d" % n, "n%02d.json" % n))]


def sheet(levels, per_row, brouillon=False):
    """Planche des niveaux (jour, nuit) à 64 px/tuile ; renvoie (jour, nuit, positions en tuiles)."""
    rows = (len(levels) + per_row - 1) // per_row
    W_t = CELL_W * per_row
    row_h = TOP + BOTTOM
    H_t = row_h * rows
    ents, pos = [], {}
    for i, n in enumerate(levels):
        r, c = divmod(i, per_row)
        p = (CELL_W * c + 2.0, row_h * r + TOP)   # multiples de 1/32 de tuile : grille paire au zoom 1
        pos[n] = p
        ents.append({"pos": p, "layers": level_layers(n)})
    day, night = compose(DATA, CORE, ents, W_t, H_t)
    return day, night, pos


def label(img_rgb, pos, ppt, header, levels, sub=None):
    """Étiquettes « N12 · ép. 6 » sous chaque niveau, et un titre."""
    head_h = 22
    im = Image.fromarray(np.clip(np.round(img_rgb * 255), 0, 255).astype(np.uint8), "RGB")
    canvas = Image.new("RGB", (im.width, im.height + head_h), (24, 22, 20))
    canvas.paste(im, (0, head_h))
    dr = ImageDraw.Draw(canvas)
    dr.text((6, 3), header, fill=(235, 225, 200), font=font(14))
    f = font(11 if ppt <= 32 else 16)
    for n in levels:
        x, y = pos[n]
        txt = "N%d · ép. %d" % (n, params.epoque(n)) if sub is None else sub(n)
        tx, ty = int(x * ppt) - int(1.45 * ppt), int((y + 1.55) * ppt) + head_h
        bb = dr.textbbox((tx, ty), txt, font=f)
        dr.rectangle((bb[0] - 2, bb[1] - 1, bb[2] + 2, bb[3] + 1), fill=(0, 0, 0))
        dr.text((tx, ty), txt, fill=(255, 240, 200), font=f)
    return canvas


def gray(rgb):
    lin = P.srgb_to_lin(rgb)
    y = lin @ np.array([0.2126, 0.7152, 0.0722])
    return np.repeat(P.lin_to_srgb(y)[..., None], 3, -1)


def main_mask(n):
    """Masque (alpha ≥ 0,5) de la couche principale sur une toile à 64 px/tuile, origine connue."""
    X0, Y0, W, H = -4.0, -5.5, 11 * 64, 9 * 64
    m = np.zeros((H, W))
    for lay in level_layers(n):
        if lay["kind"] != "main":
            continue
        img = lay["img"]
        h, w = img.shape[:2]
        x0 = int(round(-X0 * 64 + lay["shift"][0] * 64 - w / 2.0))
        y0 = int(round(-Y0 * 64 + lay["shift"][1] * 64 - h / 2.0))
        a = img[..., 3]
        m[y0:y0 + h, x0:x0 + w] = np.maximum(m[y0:y0 + h, x0:x0 + w], a)
    return m >= 0.5


def vignettes(levels, dest, header):
    masks = {n: main_mask(n) for n in levels}
    boxes = {}
    for n, m in masks.items():
        ys, xs = np.nonzero(m)
        boxes[n] = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    big = max(max(b[2] - b[0], b[3] - b[1]) for b in boxes.values())
    s = 64.0 / big
    cells = {}
    for n, m in masks.items():
        x0, y0, x1, y1 = boxes[n]
        crop = m[y0:y1, x0:x1].astype(np.float32)
        w, h = max(1, int(round((x1 - x0) * s))), max(1, int(round((y1 - y0) * s)))
        r = np.asarray(Image.fromarray(crop * 255).resize((w, h), Image.BOX)) >= 127.5
        cell = np.ones((64, 64), bool) * False
        ox, oy = (64 - w) // 2, 64 - h          # posés sur le bas de la case (sol commun)
        cell[oy:oy + h, ox:ox + w] = r[:64 - oy, :64 - ox]
        cells[n] = cell

    def strip(order, names, path, title):
        pad, lab = 8, 16
        W = len(order) * (64 + pad) + pad
        im = Image.new("RGB", (W, 64 + 2 * pad + lab + 20), (236, 232, 222))
        dr = ImageDraw.Draw(im)
        dr.text((pad, 3), title, fill=(30, 30, 30), font=font(12))
        for i, n in enumerate(order):
            x = pad + i * (64 + pad)
            y = 20 + pad
            dr.rectangle((x - 1, y - 1, x + 64, y + 64), outline=(190, 185, 175))
            c = np.where(cells[n], 0, 255).astype(np.uint8)
            im.paste(Image.fromarray(c, "L").convert("RGB"), (x, y), Image.fromarray(np.where(cells[n], 255, 0)
                                                                                      .astype(np.uint8), "L"))
            dr.text((x + 2, y + 64 + 3), names[i], fill=(30, 30, 30), font=font(11))
        im.save(path, optimize=True)
        return path

    order = list(levels)
    p1 = strip(order, ["N%d ép.%d" % (n, params.epoque(n)) for n in order], os.path.join(dest, "d-vignettes-masques.png"),
               header + " · ordre des époques · échelle commune : %.3f px par px hr (le plus grand = 64 px)" % s)
    rnd = random.Random(20261021)
    mixed = order[:]
    rnd.shuffle(mixed)
    letters = [chr(ord("A") + i) for i in range(len(mixed))]
    p2 = strip(mixed, letters, os.path.join(dest, "d-vignettes-melangees.png"),
               header + " · MÉLANGÉES : remettre dans l'ordre (clé dans d-vignettes-melangees-cle.txt)")
    with open(os.path.join(dest, "d-vignettes-melangees-cle.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("Clé du test de la vignette (D1-2), machine d'assemblage 2 : lettre -> niveau (époque)\n")
        for L_, n in zip(letters, mixed):
            f.write("%s -> niveau %d (époque %d)\n" % (L_, n, params.epoque(n)))
    return [p1, p2], s


def gros_plan(e, dest):
    n1, n2 = 2 * e - 1, 2 * e
    levels = [1] + ([n1] if n1 != 1 else []) + [n2]
    day, night, pos = sheet(levels, len(levels))
    rows = []
    for img, name in ((day, "jour"), (night, "nuit")):
        rows.append(label(img, pos, 64, "Époque %d (%s) · zoom 2 (64 px/tuile) · %s · vanilla (N1) puis N%s · APERÇU "
                          "phase 1, non validé" % (e, params.EPOQUES[e]["theme"], name,
                                                   " et N".join(str(n) for n in levels[1:])), levels))
    W = max(r.width for r in rows)
    out = Image.new("RGB", (W, sum(r.height for r in rows)), (24, 22, 20))
    y = 0
    for r in rows:
        out.paste(r, (0, y))
        y += r.height
    p = os.path.join(dest, "e-gros-plan-ep%02d.png" % e)
    out.save(p, optimize=True)
    return p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default=DEST)
    ap.add_argument("--levels", default="")
    ap.add_argument("--per-row", type=int, default=15)
    ap.add_argument("--only", default="abcde")
    ap.add_argument("--zoom", type=int, default=1, help="2 : planches a à c au zoom 2 (revue)")
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    levels = [int(x) for x in a.levels.split(",")] if a.levels else available()
    made = []
    hdr = "Machine d'assemblage 2 · niveaux %d à %d · APERÇU phase 1 (échantillons réduits), non validé" % (
        levels[0], levels[-1])
    if set("abc") & set(a.only):
        day, night, pos = sheet(levels, a.per_row)
        d1, n1 = (down2(day), down2(night)) if a.zoom == 1 else (day, night)
        pos1 = pos
        zp = 32 * a.zoom
        if "a" in a.only:
            p = os.path.join(a.dest, "a-jour-zoom1.png")
            label(d1, pos1, zp, hdr + " · zoom %d · jour" % a.zoom, levels).save(p, optimize=True)
            made.append(p)
        if "b" in a.only:
            p = os.path.join(a.dest, "b-nuit-zoom1.png")
            label(n1, pos1, zp, hdr + " · zoom %d · nuit (maquette hors moteur)" % a.zoom, levels).save(p, optimize=True)
            made.append(p)
        if "c" in a.only:
            p = os.path.join(a.dest, "c-gris-zoom1.png")
            label(gray(d1), pos1, zp, hdr + " · zoom %d · niveaux de gris (test du gris D1-1)" % a.zoom, levels).save(
                p, optimize=True)
            made.append(p)
    if "d" in a.only:
        odd = [n for n in levels if n % 2 == 1]
        ps, s = vignettes(odd, a.dest, "Machine d'assemblage 2 · niveaux impairs (1 par époque)")
        made += ps
    if "e" in a.only:
        for e in (1, 5, 10, 15):
            if all(n in levels for n in (2 * e - 1, 2 * e) if n != 1):
                made.append(gros_plan(e, a.dest))
    for p in made:
        print("[FO-PLANCHE] %s (%d o)" % (p, os.path.getsize(p)))


if __name__ == "__main__":
    main()
