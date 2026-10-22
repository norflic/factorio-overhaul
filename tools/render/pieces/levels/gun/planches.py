"""Planches de la famille gun (lot V3 phase 1), composées hors moteur à partir des aperçus (render_gun.py).

    python tools/render/pieces/levels/gun/planches.py [--pose E] [--out docs/epoques/planches/gun]

Composition (règles de tools/render/calib/maquette.py, dont on réutilise lut_apply et down2) :
  - sol : texture vanilla hr-dirt-4.png (rangées opaques 320 à 575), répétée ;
  - ombres : tampon commun (maximum des alphas), sol × (1 − 0,5 × alpha) (shadow-a8.frag) ;
  - entités triées par y puis x ; dans une entité : socle (lower-object) puis tête (object) ;
  - lueur (draw_as_glow) : ajoutée au jour ET à la carte des lumières ; halo (draw_as_light) : carte seule ;
  - nuit : mix(LUT_nuit(jour), jour, lumière), LUT lut-night.png ; lightMul/lightAdd du moteur inconnus
    (pris à 1 et 0 : NON PROUVÉ hors moteur) ;
  - niveau 1 (vanilla) et niveau 2 : avec le masque de couleur de force vanilla, teint en orange joueur
    (0,869 ; 0,5 ; 0,130). Les niveaux 3 à 30 n'ont PAS encore de masque d'équipe (passe à ajouter en phase 2).
Planches écrites (PNG) :
  a) gun-a-jour-zoom1.png      30 niveaux, zoom 1 (32 px/tuile), une colonne par époque (impair en haut) ;
  b) gun-b-nuit-zoom1.png      la même de nuit ;
  c) gun-c-gris-zoom1.png      la même en niveaux de gris (test du gris D1-1) ;
  d) gun-d-vignettes.png       15 niveaux impairs en masques noirs à la même échelle (le plus grand tient
                               dans 64 px), 4 poses, et gun-d-vignettes-melange.png (ordre mélangé, clé dans
                               gun-d-cle.json) ;
  e) gun-e-gros-plan-eNN.png   époques 1, 5, 10, 15 au zoom 2 (64 px/tuile), jour et nuit, à côté du niveau 1 ;
  f) gun-f-poses-zoom1.png     les 15 niveaux impairs dans les 4 poses de référence, de jour (complément) ;
  g) gun-g-rangs-zoom1.png     reprise 4 (vérification adverse, mineur 1) : pour chaque niveau pair, un rang de 3
                               tourelles JOINTIVES (emprises 2 × 2 côte à côte, cas courant derrière les murs), pose N
                               et pose E, de jour, zoom 1 ; repères des bords d'emprise sous chaque rang. Montre le
                               recouvrement des pièces débordantes (plafond L = 2,20 contre débord F42 : à trancher).
"""
import argparse
import json
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "calib"))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import d1lib as D  # noqa: E402
import fo_post as P  # noqa: E402
from maquette import lut_apply, down2  # noqa: E402

DATA = D.DATA
CORE = os.path.join(DATA, "core")
GT = D.GT
TEAM = (0.869, 0.5, 0.130)
PPT = 64


def vanilla_masks(pose):
    """Masques de couleur de force du niveau 1 (socle et tête), teints, en couches « main »."""
    d = D.VAN_DIR[pose]
    f, row = d // 16 + 1, d % 16
    hm = D.load_rgba(os.path.join(GT, "hr-gun-turret-shooting-mask-%d.png" % f))[row * 54:(row + 1) * 54, 0:58]
    bm = D.load_rgba(os.path.join(GT, "hr-gun-turret-base-mask.png"))
    out = []
    for img, shift, mod in ((bm, (0.0, -4.5 / 32), "socle"), (hm, (0.0, -32.5 / 32), "tete")):
        im = img.copy()
        im[..., :3] = im[..., :3] * np.array(TEAM)
        out.append(D.layer(im, D.tl_from_shift(shift, im.shape[1], im.shape[0]), "main", mod))
    return out


def level_layers(level, pose):
    lays = D.level_layers(level, pose, "final")
    if level <= 2:
        m = vanilla_masks(pose)
        # masque du socle juste après le socle vanilla, masque de tête juste après la tête vanilla
        out = []
        for l in lays:
            out.append(l)
            if l["kind"] == "main" and l["module"] == "socle" and l["img"].shape[:2] == (118, 150):
                out.append(m[0])
            if l["kind"] == "main" and l["module"] == "tete" and l["img"].shape[:2] == (130, 132):
                out.append(m[1])
        lays = out
    return lays


def ground(Wpx, Hpx):
    g = D.load_rgba(os.path.join(DATA, "base", "graphics", "terrain", "hr-dirt-4.png"))[320:576, :, :3]
    gh, gw = g.shape[:2]
    return np.tile(g, (Hpx // gh + 1, Wpx // gw + 1, 1))[:Hpx, :Wpx].copy()


def compose(entities, Wpx, Hpx):
    """entities : [{"pos": (x, y) px de l'origine de l'entité sur la scène, "layers": couches d1lib}]."""
    day = ground(Wpx, Hpx)
    shadow = np.zeros((Hpx, Wpx))
    light = np.zeros((Hpx, Wpx, 3))

    def region(lay, pos):
        img = lay["img"]
        h, w = img.shape[:2]
        xi = int(pos[0] + lay["tl"][0] - D.OX)
        yi = int(pos[1] + lay["tl"][1] - D.OY)
        xs0, ys0 = max(0, -xi), max(0, -yi)
        xd0, yd0 = max(0, xi), max(0, yi)
        ww, hh = min(w - xs0, Wpx - xd0), min(h - ys0, Hpx - yd0)
        if ww <= 0 or hh <= 0:
            return None
        return img[ys0:ys0 + hh, xs0:xs0 + ww], (slice(yd0, yd0 + hh), slice(xd0, xd0 + ww))

    for e in entities:
        for lay in e["layers"]:
            if lay["kind"] == "shadow":
                r = region(lay, e["pos"])
                if r:
                    shadow[r[1]] = np.maximum(shadow[r[1]], r[0][..., 3])
    day = day * (1 - 0.5 * shadow)[..., None]
    # moteur : TOUTES les couches lower-object (socles) de toutes les entités avant les couches object (têtes) ;
    # dans chaque couche, ordre des entités par y puis x (reprise 4 : avant, la passe était faite entité par entité,
    # ce qui posait le socle d'une tourelle voisine par-dessus la tête de la précédente, planche g)
    ents = sorted(entities, key=lambda e: (e["pos"][1], e["pos"][0]))
    passes = [(e, l) for e in ents for l in e["layers"] if l["module"] == "socle"]
    passes += [(e, l) for e in ents for l in e["layers"] if l["module"] != "socle"]
    for e, lay in passes:
        if lay["kind"] == "shadow":
            continue
        r = region(lay, e["pos"])
        if not r:
            continue
        src, d = r
        a = src[..., 3:4]
        if lay["kind"] == "main":
            day[d] = src[..., :3] * a + day[d] * (1 - a)
        elif lay["kind"] == "glow":
            day[d] = np.clip(day[d] + src[..., :3] * a, 0, 1)
            light[d] += src[..., :3] * a
        elif lay["kind"] == "light":
            light[d] += src[..., :3] * a
    light = np.clip(light, 0, 1)
    night = lut_apply(day, os.path.join(CORE, "graphics", "color_luts", "lut-night.png")) * (1 - light) + day * light
    return day, night


def font(size):
    # police système avec accents (la police par défaut de Pillow n'a pas « É ») ; repli sur celle de Pillow
    for f in ("arial.ttf", "segoeui.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            continue
    return ImageFont.load_default(size=size)


def to_img(rgb):
    return Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")


def gray(rgb):
    l = D.luminance(P.srgb_to_lin(rgb))
    return np.repeat(P.lin_to_srgb(l)[..., None], 3, -1)


def label_band(img, texts, ys, color=(235, 230, 215), size=12):
    dr = ImageDraw.Draw(img)
    f = font(size)
    for (x, y, t) in texts:
        dr.text((x, y), t, fill=color, font=f, anchor="mm")
    return img


def grid_planche(pose, cell_w=4.0, top=4.0, bottom=1.6, head_px=26):
    """15 colonnes (époques) × 2 rangées (niveau impair, niveau pair), à 64 px/tuile."""
    rows = [lambda e: 2 * e - 1, lambda e: 2 * e]
    row_h = top + bottom
    Wpx = int(15 * cell_w * PPT)
    Hpx = int(2 * row_h * PPT)
    ents, labels = [], []
    for ri, fn in enumerate(rows):
        for e in range(1, 16):
            lv = fn(e)
            x = (e - 1) * cell_w * PPT + 1.6 * PPT
            y = (ri * row_h + top) * PPT
            ents.append({"pos": (x, y), "layers": level_layers(lv, pose)})
            labels.append((x / 2, (ri * row_h + top + bottom - 0.35) * PPT / 2 + head_px, "%d" % lv))
    day, night = compose(ents, Wpx, Hpx)
    return day, night, labels, Wpx, Hpx


def with_header(rgb_zoom1, labels, title, head_px=26, cell_w=4.0):
    im = to_img(rgb_zoom1)
    W, H = im.size
    T = 22   # bande du titre, au-dessus de la bande des époques
    out = Image.new("RGB", (W, H + head_px + T), (24, 22, 20))
    out.paste(im, (0, head_px + T))
    dr = ImageDraw.Draw(out)
    dr.text((6, T / 2 + 2), title, fill=(235, 230, 215), font=font(13), anchor="lm")
    for e in range(1, 16):
        x = ((e - 1) * cell_w + 1.6) * PPT / 2
        dr.text((x, T + head_px - 6), "ép. %d" % e, fill=(200, 190, 160), font=font(11), anchor="mb")
    for (x, y, t) in labels:
        dr.text((x + 1, y + T + 1), "niv. " + t, fill=(0, 0, 0), font=font(12), anchor="mm")
        dr.text((x, y + T), "niv. " + t, fill=(250, 245, 230), font=font(12), anchor="mm")
    return out


def save(img, path, compact=False):
    """compact=True : PNG à palette de 256 couleurs (tramage de Floyd-Steinberg), planches de vue d'ensemble au zoom
    1 versionnées dans docs/ (disque H: limité) ; les gros plans (D3, précision au pixel) restent en RGB sans perte."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if compact and img.mode == "RGB":
        # FASTOCTREE : MEDIANCUT perdait les couleurs émissives rares (bulbe vert é8 et cristaux violets é7 devenus
        # blanchâtres, constaté le 22/10) ; l'octree garde les teintes saturées peu fréquentes
        img = img.quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.FLOYDSTEINBERG)
    img.save(path, optimize=True)
    return path


def vignettes(out_dir):
    """Masques noirs des 15 niveaux impairs, 4 poses, même échelle (le plus grand tient dans 64 px)."""
    masks = {}
    for e in range(1, 16):
        for pose in D.POSES:
            masks[(e, pose)] = D.main_alpha(D.level_layers(2 * e - 1, pose, "final")) >= 0.5
    # boîte commune relative à l'origine (même échelle, même ancrage pour toutes)
    x0 = y0 = 10 ** 9
    x1 = y1 = -10 ** 9
    for m in masks.values():
        ys, xs = np.nonzero(m)
        x0, x1 = min(x0, xs.min() - D.OX), max(x1, xs.max() + 1 - D.OX)
        y0, y1 = min(y0, ys.min() - D.OY), max(y1, ys.max() + 1 - D.OY)
    side = max(x1 - x0, y1 - y0)
    k = 64.0 / side
    cells = {}
    for key, m in masks.items():
        sub = m[D.OY + y0:D.OY + y0 + side, D.OX + x0:D.OX + x0 + side].astype(np.float32)
        im = Image.fromarray((sub * 255).astype(np.uint8), "L").resize((64, 64), Image.BOX)
        a = np.asarray(im, np.float64) / 255.0
        cells[key] = np.where(a >= 0.5, 0, 255).astype(np.uint8)
    pad, head = 8, 22
    W = 15 * (64 + pad) + pad + 40
    H = 4 * (64 + pad) + pad + head
    sheet = Image.new("L", (W, H), 255)
    dr = ImageDraw.Draw(sheet)
    for e in range(1, 16):
        dr.text((40 + pad + (e - 1) * (64 + pad) + 32, head - 6), "niv. %d" % (2 * e - 1), fill=0, font=font(11),
                anchor="mb")
    for pi, pose in enumerate(D.POSES):
        dr.text((20, head + pad + pi * (64 + pad) + 32), pose, fill=0, font=font(14), anchor="mm")
        for e in range(1, 16):
            sheet.paste(Image.fromarray(cells[(e, pose)], "L"), (40 + pad + (e - 1) * (64 + pad), head + pad + pi * (64 + pad)))
    p1 = save(sheet, os.path.join(out_dir, "gun-d-vignettes.png"))
    # mélange (pose E) pour le test humain ; la clé est écrite à part
    order = list(range(1, 16))
    random.Random(20261021).shuffle(order)
    W2 = 15 * (64 + pad) + pad
    sh = Image.new("L", (W2, 64 + 2 * pad + 16), 255)
    d2 = ImageDraw.Draw(sh)
    for i, e in enumerate(order):
        sh.paste(Image.fromarray(cells[(e, "E")], "L"), (pad + i * (64 + pad), pad))
        d2.text((pad + i * (64 + pad) + 32, 64 + pad + 10), chr(ord("A") + i), fill=0, font=font(12), anchor="mm")
    p2 = save(sh, os.path.join(out_dir, "gun-d-vignettes-melange.png"))
    key = {chr(ord("A") + i): {"epoque": e, "niveau": 2 * e - 1} for i, e in enumerate(order)}
    with open(os.path.join(out_dir, "gun-d-cle.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"pose": "E", "echelle_px_par_tuile": round(64 * k, 3), "cle": key}, f, indent=1, sort_keys=True)
    return [p1, p2], 64 * k


def gros_plans(out_dir, epochs=(1, 5, 10, 15)):
    paths = []
    for e in epochs:
        spec = [(1, "E", "niv. 1 (vanilla)"), (2 * e - 1, "E", "niv. %d" % (2 * e - 1)), (2 * e, "E", "niv. %d" % (2 * e)),
                (2 * e, "S", "niv. %d (S)" % (2 * e))]
        if e == 1:   # le niveau impair de l'époque 1 EST le vanilla : on montre plutôt le niveau 2 en pose N
            spec[1] = (2, "N", "niv. 2 (N)")
        cw, top, bottom = 3.6, 4.0, 1.5
        Wpx, Hpx = int(len(spec) * cw * PPT), int((top + bottom) * PPT)
        ents = [{"pos": ((i * cw + 1.5) * PPT, top * PPT), "layers": level_layers(lv, pose)} for i, (lv, pose, _) in enumerate(spec)]
        day, night = compose(ents, Wpx, Hpx)
        head = 22
        out = Image.new("RGB", (Wpx, 2 * Hpx + 2 * head), (24, 22, 20))
        dr = ImageDraw.Draw(out)
        for ri, (rgb, tag) in enumerate(((day, "jour"), (night, "nuit"))):
            out.paste(to_img(rgb), (0, ri * (Hpx + head) + head))
            dr.text((6, ri * (Hpx + head) + head / 2), "Époque %d, zoom 2 (64 px/tuile), %s" % (e, tag),
                    fill=(235, 230, 215), font=font(13), anchor="lm")
            for i, (_, _, t) in enumerate(spec):
                dr.text(((i * cw + 1.5) * PPT, ri * (Hpx + head) + head + Hpx - 14), t, fill=(250, 245, 230),
                        font=font(13), anchor="mm")
        paths.append(save(out, os.path.join(out_dir, "gun-e-gros-plan-e%02d.png" % e)))
    return paths


def poses_planche(out_dir, cell_w=4.0, top=4.0, bottom=1.6):
    row_h = top + bottom
    Wpx, Hpx = int(15 * cell_w * PPT), int(4 * row_h * PPT)
    ents, labels = [], []
    for ri, pose in enumerate(D.POSES):
        for e in range(1, 16):
            x = ((e - 1) * cell_w + 1.6) * PPT
            y = (ri * row_h + top) * PPT
            ents.append({"pos": (x, y), "layers": level_layers(2 * e - 1, pose)})
            labels.append((x / 2, (ri * row_h + top + bottom - 0.35) * PPT / 2 + 26, "%d %s" % (2 * e - 1, pose)))
    day, _ = compose(ents, Wpx, Hpx)
    img = with_header(down2(day), labels, "Mitrailleuse : niveaux impairs, 4 poses de référence (N, E, S, O), jour, zoom 1")
    return save(img, os.path.join(out_dir, "gun-f-poses-zoom1.png"), True)


def rangs_planche(out_dir, poses=("N", "E"), cols=5, gap=1.2, top=4.0, bottom=1.4):
    """Niveaux pairs : 3 tourelles jointives (x = -2, 0, +2 tuiles) par case, 5 cases par rangée, poses N puis E."""
    lvls = list(range(2, 31, 2))
    cell_w = 6.0 + gap
    rows = [(pose, lvls[i:i + cols]) for pose in poses for i in range(0, len(lvls), cols)]
    Wpx, Hpx = int(cols * cell_w * PPT), int(len(rows) * (top + bottom) * PPT)
    ents, labels, ticks = [], [], []
    for ri, (pose, lv_row) in enumerate(rows):
        for ci, lv in enumerate(lv_row):
            cx = (ci * cell_w + gap / 2 + 3.0) * PPT
            y = (ri * (top + bottom) + top) * PPT
            for dx in (-2, 0, 2):
                ents.append({"pos": (cx + dx * PPT, y), "layers": level_layers(lv, pose)})
            labels.append((cx / 2, (ri * (top + bottom) + top + bottom - 0.3) * PPT / 2, "niv. %d %s" % (lv, pose)))
            for bx in (-3, -1, 1, 3):
                ticks.append(((cx + bx * PPT) / 2, (y + 1.0 * PPT) / 2))
    day, _ = compose(ents, Wpx, Hpx)
    im = to_img(down2(day))
    T = 22
    out = Image.new("RGB", (im.width, im.height + T), (24, 22, 20))
    out.paste(im, (0, T))
    dr = ImageDraw.Draw(out)
    dr.text((6, T / 2 + 2), "Mitrailleuse : niveaux pairs, 3 tourelles jointives (emprises 2 × 2 côte à côte), poses N et E, "
                            "jour, zoom 1 ; traits blancs = bords d'emprise", fill=(235, 230, 215), font=font(13), anchor="lm")
    for x, y in ticks:
        dr.line([(x, y + T + 2), (x, y + T + 9)], fill=(255, 255, 255), width=1)
    for (x, y, t) in labels:
        dr.text((x + 1, y + T + 1), t, fill=(0, 0, 0), font=font(12), anchor="mm")
        dr.text((x, y + T), t, fill=(250, 245, 230), font=font(12), anchor="mm")
    return save(out, os.path.join(out_dir, "gun-g-rangs-zoom1.png"), True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pose", default="E")
    ap.add_argument("--out", default=os.path.join(D.MOD_ROOT, "docs", "epoques", "planches", "gun"))
    ap.add_argument("--only", default="abcdefg")
    a = ap.parse_args()
    paths = []
    if any(c in a.only for c in "abc"):
        day, night, labels, Wpx, Hpx = grid_planche(a.pose)
        t = "Mitrailleuse : 30 niveaux, pose %s, zoom 1 (32 px/tuile), " % a.pose
        if "a" in a.only:
            paths.append(save(with_header(down2(day), labels, t + "jour (impair en haut, pair en bas)"),
                              os.path.join(a.out, "gun-a-jour-zoom1.png"), True))
        if "b" in a.only:
            paths.append(save(with_header(down2(night), labels, t + "nuit"), os.path.join(a.out, "gun-b-nuit-zoom1.png"), True))
        if "c" in a.only:
            paths.append(save(with_header(gray(down2(day)), labels, t + "niveaux de gris (test du gris D1-1)"),
                              os.path.join(a.out, "gun-c-gris-zoom1.png"), True))
    if "d" in a.only:
        ps, ppt = vignettes(a.out)
        paths += ps
        print("vignettes : %.2f px par tuile" % ppt)
    if "e" in a.only:
        paths += gros_plans(a.out)
    if "f" in a.only:
        paths.append(poses_planche(a.out))
    if "g" in a.only:
        paths.append(rangs_planche(a.out))
    for p in paths:
        print(os.path.abspath(p), "%d Ko" % (os.path.getsize(p) // 1024))


if __name__ == "__main__":
    main()
