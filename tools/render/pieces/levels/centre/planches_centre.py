"""Planches du centre de commandement, 15 niveaux (lot V3-a, phase 1). Python système (numpy + Pillow).

    python -P tools/render/pieces/levels/centre/planches_centre.py ["<racine>/data"] [--dest <dossier>]

Compose les APERÇUS de tools/render/out/levels/centre/nNN/ (render_centre.py) comme le moteur, avec la
maquette de V0 (tools/render/calib/maquette.py, utilisée sans modification) : ombres (maximum des alphas,
sol × (1 − 0,5 α)), entités triées par y puis x, lueur additive, nuit = mix(LUT nuit, jour, lumière).
Sol : texture vanilla hr-dirt-4.png. Époques 1 et 2 : la lueur est une couche draw_as_light (nuit
seulement, bible §5), elle n'est donc pas dessinée de jour.

Planches écrites dans docs/epoques/planches/centre/ (PNG compacts, versionnés) :
  centre-a-jour-zoom1.png    (a) les 15 niveaux côte à côte, zoom 1 (32 px/tuile), de jour, avec ombres ;
  centre-b-nuit-zoom1.png    (b) la même, de nuit ;
  centre-c-gris-zoom1.png    (c) la même en niveaux de gris (test du gris, D1-1) ;
  centre-d-vignettes.png     (d) masques noirs à la même échelle, le plus grand dans 64 px (D1-2), dans
                                 l'ordre puis mélangés (clé dans vignettes_cle.json) ;
  centre-e-zoom2-jour.png / centre-e-zoom2-nuit.png   (e) gros plans au zoom 2 (64 px/tuile) des époques 1,
                                 5, 10 et 15 à côté du niveau 1 ACTUEL (composition roboport + radar).
LIMITES (non prouvées hors moteur) : lightMul et lightAdd du moteur inconnus (pris à 1 et 0) ; zoom 1 =
moyenne 2 × 2 au lieu des mipmaps du jeu ; aperçus à échantillons réduits (grain).
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, os.path.join(RENDER, "calib"))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
from maquette import compose, down2, lut_apply  # noqa: E402,F401
from fitlib import load  # noqa: E402
import centre_params as PR  # noqa: E402

OUT = os.path.join(RENDER, "out", "levels", "centre")
DEST = os.path.join(MOD_ROOT, "docs", "epoques", "planches", "centre")
DEFAULT_DATA = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data"
SHORT = {1: "Pionnier", 2: "Forge", 3: "Vapeur", 4: "Pétrole", 5: "Volcan", 6: "Électricité", 7: "Cristal",
         8: "Marais", 9: "Atome", 10: "Haute techno", 11: "Titane", 12: "Supraconducteurs", 13: "Fusion",
         14: "Orbite", 15: "Légende"}


def font(size, bold=False):
    for f in (("arialbd.ttf" if bold else "arial.ttf"), "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", f), size)
        except OSError:
            continue
    return ImageFont.load_default()


def level_layers(e, res="hr"):
    d = os.path.join(OUT, "n%02d" % e)
    with open(os.path.join(d, "render.json"), encoding="utf-8") as f:
        r = json.load(f)
    lays = []
    for layer in ("shadow", "main", "glow", "light"):
        if layer not in r.get("spec", {}):
            continue
        sd = r["spec"][layer][res]
        kind = layer
        if layer == "glow" and e in PR.NIGHT_ONLY:
            kind = "light"      # époques 1-2 : lumière de nuit seulement (draw_as_light)
        lays.append({"img": load(os.path.join(d, sd["filename"])), "shift": tuple(sd["shift"]), "kind": kind})
    return lays


def resized_layer(data, rel, fw, fh, frame, shift, scale, dx, dy, kind="main"):
    """Image vanilla réduite (kit.moved) posée sur la grille : taille paire et position entière."""
    im = load(os.path.join(data, "base", "graphics", "entity", rel))
    fx, fy = frame
    im = im[fy * fh:(fy + 1) * fh, fx * fw:(fx + 1) * fw]
    w, h = int(round(fw * scale / 2)) * 2, int(round(fh * scale / 2)) * 2
    pm = np.concatenate([im[..., :3] * im[..., 3:4], im[..., 3:4]], -1)
    chans = [np.asarray(Image.fromarray((pm[..., c] * 255).astype(np.float32), "F").resize((w, h), Image.LANCZOS)) / 255.0
             for c in range(4)]
    r = np.clip(np.stack(chans, -1), 0, 1)
    a = r[..., 3:4]
    r = np.concatenate([np.where(a > 1e-6, r[..., :3] / np.maximum(a, 1e-6), 0), a], -1)
    sx, sy = shift[0] * scale + dx, shift[1] * scale + dy
    sx = round(sx * 64) / 64.0
    sy = round(sy * 64) / 64.0
    return {"img": r, "shift": (sx, sy), "kind": kind}


def current_level1(data):
    """Niveau 1 ACTUEL du centre (prototypes/levels/command.lua, provisoire, à remplacer) : corps du
    roboport, son ombre, base_patch, portes (image 0), radar réduit ×0,46 en (-1,05 ; -1,45)."""
    V = lambda rel, w, h, sh, kind="main", fr=(0, 0): _vl(data, rel, w, h, sh, kind, fr)  # noqa: E731
    lays = [V("roboport/hr-roboport-shadow.png", 294, 201, (28.5 / 32, 19.25 / 32), "shadow"),
            V("roboport/hr-roboport-base.png", 228, 277, (2 / 32, 7.75 / 32)),
            V("roboport/hr-roboport-base-patch.png", 138, 100, (1.5 / 32, 5 / 32)),
            V("roboport/hr-roboport-door-up.png", 97, 38, (-0.25 / 32, -29.5 / 32)),
            V("roboport/hr-roboport-door-down.png", 97, 41, (-0.25 / 32, -9.75 / 32)),
            resized_layer(data, "radar/hr-radar.png", 196, 254, (0, 0), (1 / 32, -16 / 32), 0.46, -1.05, -1.45)]
    return lays


def _vl(data, rel, w, h, shift, kind, frame):
    im = load(os.path.join(data, "base", "graphics", "entity", rel))
    fx, fy = frame
    return {"img": im[fy * h:(fy + 1) * h, fx * w:(fx + 1) * w], "shift": shift, "kind": kind}


def gray(rgb):
    y = rgb @ np.array([0.2126, 0.7152, 0.0722])
    return np.repeat(y[..., None], 3, -1)


def to_img(rgb):
    return Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")


def label(img, items, fnt, color=(235, 230, 215)):
    d = ImageDraw.Draw(img)
    for (x, y, txt) in items:
        w = d.textlength(txt, font=fnt)
        for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            d.text((x - w / 2 + ox, y + oy), txt, font=fnt, fill=(0, 0, 0))
        d.text((x - w / 2, y), txt, font=fnt, fill=color)
    return img


def save(img, name, dest):
    os.makedirs(dest, exist_ok=True)
    p = os.path.join(dest, name)
    img.save(p, optimize=True)
    return p


def plate_lineup(data, levels, dest):
    core = os.path.join(data, "core")
    rows = [[e for e in levels if e <= 8], [e for e in levels if e > 8]]
    dx, x0 = 5.5, 3.0          # positions multiples de 1/2 tuile : sprites sur la grille de pixels
    ys = [5.0, 14.5]
    ents, labels = [], []
    for r, row in enumerate(rows):
        for i, e in enumerate(row):
            pos = (x0 + i * dx, ys[r])
            ents.append({"pos": pos, "layers": level_layers(e)})
            labels.append((pos[0], pos[1] + 2.15, "%d · %s" % (e, SHORT[e])))
    Wt = x0 + 7 * dx + 4.6
    Ht = ys[1] + 2.75
    day, night = compose(data, core, ents, Wt, Ht)
    f = font(12, bold=True)
    lab = [(x * 32, y * 32, t) for x, y, t in labels]
    files = {}
    a = label(to_img(down2(day)), lab, f)
    files["a"] = save(a, "centre-a-jour-zoom1.png", dest)
    b = label(to_img(down2(night)), lab, f)
    files["b"] = save(b, "centre-b-nuit-zoom1.png", dest)
    c = label(to_img(gray(down2(day))), lab, f)
    files["c"] = save(c, "centre-c-gris-zoom1.png", dest)
    return files


def plate_vignettes(levels, dest):
    masks = {}
    for e in levels:
        d = os.path.join(OUT, "n%02d" % e)
        with open(os.path.join(d, "render.json"), encoding="utf-8") as f:
            sd = json.load(f)["spec"]["main"]["hr"]
        a = load(os.path.join(d, sd["filename"]))[..., 3] >= 0.5
        h, w = a.shape
        x0 = sd["shift"][0] * 64 - w / 2.0
        y0 = sd["shift"][1] * 64 - h / 2.0
        masks[e] = (a, x0, y0)
    X0 = min(x0 for a, x0, y0 in masks.values())
    Y0 = min(y0 for a, x0, y0 in masks.values())
    X1 = max(x0 + a.shape[1] for a, x0, y0 in masks.values())
    Y1 = max(y0 + a.shape[0] for a, x0, y0 in masks.values())
    Wc, Hc = int(np.ceil(X1 - X0)), int(np.ceil(Y1 - Y0))
    s = 64.0 / max(Wc, Hc)
    tw, th = max(1, int(round(Wc * s))), max(1, int(round(Hc * s)))
    cells = {}
    for e, (a, x0, y0) in masks.items():
        c = np.zeros((Hc, Wc), np.float32)
        xi, yi = int(round(x0 - X0)), int(round(y0 - Y0))
        c[yi:yi + a.shape[0], xi:xi + a.shape[1]] = a
        small = np.asarray(Image.fromarray(c * 255).resize((tw, th), Image.BOX)) / 255.0
        cell = np.ones((64, 64))
        ox, oy = (64 - tw) // 2, 64 - th
        cell[oy:oy + th, ox:ox + tw] = 1.0 - (small >= 0.5)
        cells[e] = cell
    gap, top = 10, 6
    n = len(levels)
    W = n * 64 + (n + 1) * gap
    H = 2 * (64 + top + 22) + 20
    img = Image.new("RGB", (W, H), (255, 255, 255))
    f = font(11, bold=True)
    d = ImageDraw.Draw(img)
    order = list(levels)
    # mélange déterministe (aucun aléa : permutation fixe par multiplication modulaire)
    shuffled = sorted(order, key=lambda e: (e * 7 + 3) % 16)
    letters = "ABCDEFGHIJKLMNO"
    key = {}
    for row, seq in enumerate((order, shuffled)):
        y = top + row * (64 + top + 22 + 10)
        for i, e in enumerate(seq):
            x = gap + i * (64 + gap)
            img.paste(Image.fromarray((cells[e] * 255).astype(np.uint8), "L").convert("RGB"), (x, y))
            d.rectangle((x - 1, y - 1, x + 64, y + 64), outline=(200, 200, 200))
            t = str(e) if row == 0 else letters[i]
            if row == 1:
                key[letters[i]] = e
            tw2 = d.textlength(t, font=f)
            d.text((x + 32 - tw2 / 2, y + 66), t, font=f, fill=(40, 40, 40))
    p = save(img, "centre-d-vignettes.png", dest)
    with open(os.path.join(dest, "vignettes_cle.json"), "w", encoding="utf-8", newline="\n") as fo:
        json.dump({"echelle_px_par_tuile": round(64 * s, 3), "boite_commune_px_hr": [Wc, Hc],
                   "melange": key}, fo, indent=1, ensure_ascii=False)
    return p


def plate_closeups(data, dest, epochs=(1, 5, 10, 15)):
    core = os.path.join(data, "core")
    dx, x0, y = 6.5, 3.0, 6.5
    ents = [{"pos": (x0, y), "layers": current_level1(data)}]
    labels = [(x0, y + 2.2, "niveau 1 ACTUEL (roboport + radar, à remplacer)")]
    for i, e in enumerate(epochs):
        if not os.path.exists(os.path.join(OUT, "n%02d" % e, "render.json")):
            continue
        pos = (x0 + (i + 1) * dx, y)
        ents.append({"pos": pos, "layers": level_layers(e)})
        labels.append((pos[0], pos[1] + 2.2, "%d · %s" % (e, PR.NAMES[e])))
    Wt = x0 + len(epochs) * dx + 5.6
    Ht = y + 2.75
    day, night = compose(data, core, ents, Wt, Ht)
    f = font(17, bold=True)
    lab = [(x * 64, yy * 64, t) for x, yy, t in labels]
    return {"jour": save(label(to_img(day), lab, f), "centre-e-zoom2-jour.png", dest),
            "nuit": save(label(to_img(night), lab, f), "centre-e-zoom2-nuit.png", dest)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("data", nargs="?", default=os.environ.get("FO_DATA", DEFAULT_DATA))
    ap.add_argument("--dest", default=DEST)
    a = ap.parse_args()
    levels = [e for e in range(1, 16) if os.path.exists(os.path.join(OUT, "n%02d" % e, "render.json"))]
    files = plate_lineup(a.data, levels, a.dest)
    files["d"] = plate_vignettes(levels, a.dest)
    files["e"] = plate_closeups(a.data, a.dest)
    for k, v in sorted(files.items()):
        print("[FO-PLANCHE] %s %s" % (k, v))


if __name__ == "__main__":
    main()
