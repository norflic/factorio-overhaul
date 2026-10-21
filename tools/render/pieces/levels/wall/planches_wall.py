"""Planches du mur (lot V3, phase 1) : composition hors moteur des aperçus, comme la maquette V0.

    python -P tools/render/pieces/levels/wall/planches_wall.py [--out docs/epoques/planches/wall] [--quick 2,3,4]

Écrit dans le dossier de sortie (PNG compacts, à commiter) :
  a-niveaux-zoom1-jour.png    les 30 niveaux, zoom 1 (32 px/tuile), sol vanilla, ombres, de jour
  b-niveaux-zoom1-nuit.png    la même de nuit (LUT de nuit + carte des lumières : halos + lueurs)
  c-niveaux-zoom1-gris.png    la même de jour en niveaux de gris (test du gris, D1-1)
  d-vignettes-masques.png     les 15 niveaux impairs en masques noirs, même échelle, le plus grand
                              dans 64 px (test de la vignette, D1-2) ; d-vignettes-melangees.png sans légende
  e-gros-plans-zoom2-jour.png / e-gros-plans-zoom2-nuit.png  époques 1, 5, 10, 15 au zoom 2, à côté du
                              sprite vanilla du niveau 1
  f-raccord-zoom1-jour.png / -nuit.png   une rangée continue N1 à N30 (raccord entre niveaux, merge group 0)
Chaque cellule montre 3 pièces droites (raccord) et une pièce isolée. Les bouts de rangée vanilla
(ending_left/right) ne sont pas encore produits (phase 2) : les rangées s'arrêtent net.
Composition (tools/render/calib/maquette.py, partagé, importé tel quel) : ombres au maximum des alphas,
sol × (1 - 0,5·alpha), entités triées par y, lueurs additives, nuit = mix(LUT_nuit(jour), jour, lumière).
lightMul/lightAdd du moteur inconnus (1 et 0) : la nuit hors moteur est NON PROUVÉE.
"""
import argparse
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(RENDER, "calib"))
sys.path.insert(0, RENDER)
import maquette  # noqa: E402
import wall_layers as WL  # noqa: E402
import fo_post as P  # noqa: E402

DATA = WL.DATA
CORE = os.path.join(DATA, "core")
EPOCH_NAMES = {1: "Pionnier", 2: "Forge", 3: "Vapeur", 4: "Pétrole", 5: "Volcan", 6: "Électricité", 7: "Cristal",
               8: "Marais", 9: "Atome", 10: "Haute techno", 11: "Titane", 12: "Supracond.", 13: "Fusion",
               14: "Orbite", 15: "Légende"}


def font(size):
    for f in ("arial.ttf", "segoeui.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            continue
    return ImageFont.load_default()


def cell_entities(level, x0, y0, db, n_run=3):
    """Entités d'une cellule : n_run pièces droites à partir de x0 (centres de tuiles), puis une isolée."""
    ents = []
    for i in range(n_run):
        ents.append({"pos": (x0 + i + 0.5, y0 + 0.5), "layers": WL.level_layers(level, "droit", res_db=db)})
    ents.append({"pos": (x0 + n_run + 1.5, y0 + 0.5), "layers": WL.level_layers(level, "isole", res_db=db)})
    return ents


def to_img(rgb):
    return Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")


def gray(rgb):
    lum = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]     # sRGB codé (comme l'œil sur capture)
    return np.repeat(lum[..., None], 3, -1)


def label(img, items, scale):
    d = ImageDraw.Draw(img)
    f = font(max(10, int(11 * scale)))
    for (x, y), txt in items:
        d.text((x * scale + 1, y * scale + 1), txt, fill=(0, 0, 0), font=f)
        d.text((x * scale, y * scale), txt, fill=(255, 240, 200), font=f)
    return img


def planche_niveaux(db, levels, out, tag=""):
    cols = 5
    cw, ch = 6.0, 3.0
    rows = (len(levels) + cols - 1) // cols
    ents, labels = [], []
    for i, lv in enumerate(levels):
        cx, cy = (i % cols) * cw, (i // cols) * ch
        ents += cell_entities(lv, int(cx) + 0, int(cy) + 1, db)
        e = (lv + 1) // 2
        # légende SOUS le mur de la cellule (au-dessus, elle se lisait comme celle de la rangée précédente)
        labels.append(((cx * 32 + 3, (cy + 2.45) * 32), "N%d  é%d %s%s" % (lv, e, EPOCH_NAMES[e], " (vanilla)" if lv == 1 else "")))
    day, night = maquette.compose(DATA, CORE, ents, cols * cw, rows * ch)
    d1, n1 = maquette.down2(day), maquette.down2(night)
    files = {}
    for name, rgb in (("a-niveaux-zoom1-jour%s.png" % tag, d1), ("b-niveaux-zoom1-nuit%s.png" % tag, n1),
                      ("c-niveaux-zoom1-gris%s.png" % tag, gray(d1))):
        im = label(to_img(rgb), labels, 1)
        p = os.path.join(out, name)
        im.save(p, optimize=True)
        files[name] = p
    return files


def mask_canvas(layers, ppt=64, ext=(-1.0, 1.0, -2.0, 1.0)):
    """Masque (alpha >= 0,5) des couches principales composées, sur une toile en tuiles (x0, x1, y0, y1)."""
    x0, x1, y0, y1 = ext
    W, H = int((x1 - x0) * ppt), int((y1 - y0) * ppt)
    acc = np.zeros((H, W))
    for lay in layers:
        if lay["kind"] != "main":
            continue
        img = lay["img"]
        h, w = img.shape[:2]
        xi = int(round((lay["shift"][0] - x0) * ppt - w / 2.0))
        yi = int(round((lay["shift"][1] - y0) * ppt - h / 2.0))
        a = img[..., 3]
        xs0, ys0 = max(0, -xi), max(0, -yi)
        xd0, yd0 = max(0, xi), max(0, yi)
        ww, hh = min(w - xs0, W - xd0), min(h - ys0, H - yd0)
        if ww > 0 and hh > 0:
            sub = a[ys0:ys0 + hh, xs0:xs0 + ww]
            acc[yd0:yd0 + hh, xd0:xd0 + ww] = sub + acc[yd0:yd0 + hh, xd0:xd0 + ww] * (1 - sub)
    return acc >= 0.5


def run_layers(level, db, n=3):
    """Couches de n pièces droites côte à côte (rangée), centrées sur l'origine."""
    out = []
    for i in range(n):
        dx = i - (n - 1) / 2.0
        for lay in WL.level_layers(level, "droit", res_db=db):
            out.append(dict(lay, shift=(lay["shift"][0] + dx, lay["shift"][1])))
    return out


def planche_vignettes(db, out, odd_levels):
    """Trois rangées, chacune à SA propre échelle commune (le plus grand masque de la rangée tient dans
    64 px) : D = pièce droite seule, I = pièce isolée, R = rangée de 3 pièces droites (la crête se lit en
    rangée, c'est ainsi qu'on voit un mur en jeu)."""
    poses = ("droit", "isole", "rangee")
    masks = {p: [mask_canvas(WL.level_layers(lv, p, res_db=db)) for lv in odd_levels] for p in poses[:2]}
    masks["rangee"] = [mask_canvas(run_layers(lv, db), ext=(-2.0, 2.0, -2.0, 1.0)) for lv in odd_levels]
    files = {}
    for shuffled in (False, True):
        order = list(range(len(odd_levels)))
        if shuffled:
            random.Random(15).shuffle(order)
        pad, lab = 8, 16
        tile = 64
        W = len(order) * (tile + pad) + pad
        Hh = len(poses) * (tile + pad + lab) + pad
        img = Image.new("RGB", (W, Hh), (255, 255, 255))
        d = ImageDraw.Draw(img)
        f = font(11)
        for pi, p in enumerate(poses):
            ms = masks[p]
            ys, xs = np.nonzero(np.any(ms, axis=0))
            y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            side = max(y1 - y0, x1 - x0)
            for j, idx in enumerate(order):
                m = ms[idx][y0:y0 + side, x0:x0 + side]
                sq = np.zeros((side, side), bool)
                sq[:m.shape[0], :m.shape[1]] = m
                # le plus grand tient dans 64 px : même facteur pour tous (tailles relatives conservées)
                im = Image.fromarray((~sq * 255).astype(np.uint8), "L").resize((tile, tile), Image.BOX)
                im = im.point(lambda v: 0 if v < 128 else 255)
                X = pad + j * (tile + pad)
                Y = pad + pi * (tile + pad + lab)
                img.paste(im.convert("RGB"), (X, Y))
                d.rectangle([X - 1, Y - 1, X + tile, Y + tile], outline=(200, 200, 200))
                if not shuffled:
                    d.text((X + 2, Y + tile + 2), "é%d %s" % (idx + 1, {"droit": "D", "isole": "I", "rangee": "R"}[p]),
                           fill=(0, 0, 0), font=f)
                else:
                    d.text((X + 2, Y + tile + 2), "%s" % chr(65 + j), fill=(0, 0, 0), font=f)
        name = "d-vignettes-melangees.png" if shuffled else "d-vignettes-masques.png"
        p = os.path.join(out, name)
        img.save(p, optimize=True)
        files[name] = p
        if shuffled:
            files["d-ordre-melange"] = {chr(65 + j): "époque %d" % (idx + 1) for j, idx in enumerate(order)}
    return files


def planche_gros_plans(db, out, epochs=(1, 5, 10, 15)):
    """e : zoom 2 (64 px/tuile, sprites hr 1:1). Une rangée par époque : le niveau 1 vanilla, puis le niveau
    impair et le niveau pair de l'époque (2 pièces droites qui se raccordent + 1 pièce isolée chacun).
    Rangées de 4 tuiles : la légende de chaque rangée est juste au-dessus de SES murs."""
    ents, labels = [], []
    gw, gh = 5, 4
    for r, e in enumerate(epochs):
        y = r * gh + 2
        groups = [(1, "N1 vanilla"), (2 * e - 1, "N%d" % (2 * e - 1)), (2 * e, "N%d" % (2 * e))]
        if e == 1:
            groups = [(1, "N1 vanilla"), (2, "N2 (vanilla + pièce)")]
        for gi, (lv, txt) in enumerate(groups):
            x = gi * gw + 1
            for i in range(2):
                ents.append({"pos": (x + i + 0.5, y + 0.5), "layers": WL.level_layers(lv, "droit", res_db=db)})
            ents.append({"pos": (x + 3 + 0.5, y + 0.5), "layers": WL.level_layers(lv, "isole", res_db=db)})
            labels.append(((x * 64 - 40, r * gh * 64 + 6), "é%d %s · %s" % (e, EPOCH_NAMES[e], txt)))
    day, night = maquette.compose(DATA, CORE, ents, 3 * gw + 1, len(epochs) * gh)
    files = {}
    for name, rgb in (("e-gros-plans-zoom2-jour.png", day), ("e-gros-plans-zoom2-nuit.png", night)):
        im = label(to_img(rgb), labels, 1)
        p = os.path.join(out, name)
        im.save(p, optimize=True)
        files[name] = p
    return files


def planche_raccord(db, out):
    """f : une rangée droite continue N1, N2, ..., N30 (visual_merge_group = 0 : des murs de niveaux différents
    se raccordent) au zoom 1, jour, puis la même au zoom 2 sur les transitions d'époque 1-2-3 et 28-29-30."""
    ents = [{"pos": (1 + i + 0.5, 2.5), "layers": WL.level_layers(lv, "droit", res_db=db)} for i, lv in enumerate(range(1, 31))]
    day, night = maquette.compose(DATA, CORE, ents, 32, 3.5)
    files = {}
    lab = [(((1 + i) * 32 + 9, 4), "%d" % lv) for i, lv in enumerate(range(1, 31))]
    for name, rgb in (("f-raccord-zoom1-jour.png", maquette.down2(day)), ("f-raccord-zoom1-nuit.png", maquette.down2(night))):
        im = label(to_img(rgb), lab, 1)
        p = os.path.join(out, name)
        im.save(p, optimize=True)
        files[name] = p
    return files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(MOD_ROOT, "docs", "epoques", "planches", "wall"))
    ap.add_argument("--quick", default="")
    a = ap.parse_args()
    db = WL.results()
    if a.quick:
        levels = [int(x) for x in a.quick.split(",")]
        out = os.path.join(WL.OUT, "apercu")
        os.makedirs(out, exist_ok=True)
        print(planche_niveaux(db, levels, out, tag="-apercu"))
        return
    os.makedirs(a.out, exist_ok=True)
    files = {}
    files.update(planche_niveaux(db, list(range(1, 31)), a.out))
    files.update(planche_vignettes(db, a.out, [2 * e - 1 for e in range(1, 16)]))
    files.update(planche_gros_plans(db, a.out))
    files.update(planche_raccord(db, a.out))
    for k, v in files.items():
        print(k, v)


if __name__ == "__main__":
    main()
