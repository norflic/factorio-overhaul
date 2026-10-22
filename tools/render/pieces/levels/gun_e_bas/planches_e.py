"""Planches de présentation du lot V3-E, époques 1 à 9 (composition hors moteur, sol vanilla, compo.py).

    py -3.9 tools/render/pieces/levels/gun_e_bas/planches_e.py <dossier out> <dossier planches>

(a) zoom 1, jour et nuit, pose E : mitrailleuse vanilla (niv. 1), niveaux 2, 3, 5, ..., 17, réacteur vanilla ;
(b) la même en pose N, de jour ;
(c) gros plan des CANONS de chaque époque au zoom 2 (64 px/tuile), pose E, jour ;
(d) niveau impair contre niveau pair, chaque époque, zoom 1 (et zoom 2 pour l'ère I), jour, pose E.
Légende « époque N · nom · emprise ». Le zoom 1 est une réduction 2×2 en lumière linéaire du rendu à 64 px/tuile.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402

BG = (24, 24, 27)
TXT = (235, 235, 235)
SUB = (170, 170, 175)
ACC = (255, 190, 90)


def label(e, even=False):
    if e == 1 and even:
        return "époque 1 · Pionnier", "niv. 2 · 2×2", "vanilla + sacs de sable"
    lvl = 2 * e - 1 + int(even)
    s = K.SIDE[e]
    return "époque %d · %s" % (e, K.NAME[e]), "niv. %d · emprise %d×%d" % (lvl, s, s)


def row(out, items, pose, gap=1.1, extra_h=0.0, minslot=0.0):
    """items : liste de (clé, couches, côté). Renvoie (entités, largeur en tuiles, hauteur, centres x).
    minslot : largeur minimale d'une case (tuiles), pour que les légendes ne se chevauchent pas."""
    ents, xs = [], []
    x = 0.8
    H = max(it[2] for it in items)
    for key, lays, side in items:
        half = max(side / 2.0 + gap / 2.0, minslot / 2.0)
        x += half
        xs.append(x)
        ents.append({"pos": [x, 0.0], "layers": lays})
        x += half
    Ht = H + 2.6 + extra_h
    for en in ents:
        en["pos"][1] = 1.5 + H / 2.0 + 0.3
    return ents, x + 0.6, Ht, xs


def items_line(out, pose, evens=False):
    it = [("van", K.vanilla_gun(pose), 2), ("e01", K.level_layers(out, 1, pose, True), 2)]
    for e in range(2, 10):
        it.append(("e%02d" % e, K.level_layers(out, e, pose, evens), K.SIDE[e]))
    return it


def draw_labels(img, xs, labels, y, ppt, f1, f2):
    d = ImageDraw.Draw(img)
    for x, lab in zip(xs, labels):
        cx = int(x * ppt)
        yy = y
        for i, t in enumerate(lab):
            f = f1 if i == 0 else f2
            w = d.textlength(t, font=f)
            d.text((cx - w / 2, yy), t, font=f, fill=TXT if i == 0 else SUB)
            yy += f.size + 4


def framed(scene, title, sub, labels_xs, labels, ppt, pad_h=70):
    W, H = scene.size
    f0, f1, f2 = K.font(26), K.font(15), K.font(13, False)
    out = Image.new("RGB", (W, H + pad_h + 72), BG)
    d = ImageDraw.Draw(out)
    d.text((14, 10), title, font=f0, fill=ACC)
    d.text((14, 42), sub, font=K.font(14, False), fill=SUB)
    out.paste(scene, (0, pad_h))
    draw_labels(out, labels_xs, labels, pad_h + H + 8, ppt, f1, f2)
    return out


def line_plate(out, pose, night, path, title):
    items = items_line(out, pose)
    items.append(("reac", K.vanilla_reactor(), 5))
    ents, Wt, Ht, xs = row(out, items, pose, minslot=5.4)
    day, ngt = K.compose(ents, Wt, Ht)
    img = K.to_im(K.down2(ngt if night else day))
    labels = [("vanilla", "niv. 1 · 2×2", "repère")]
    labels += [label(1, True)] + [label(e) for e in range(2, 10)]
    labels += [("réacteur vanilla", "5×5 · repère")]
    sub = ("pose %s · 32 px par tuile (zoom 1) · %s · composé hors moteur (sol hr-dirt-4, ombres, lueur, "
           "nuit = LUT du jeu, approximation)" % (pose, "nuit" if night else "jour"))
    framed(img, title, sub, xs, labels, 32).save(path)
    print(path)


def guns_plate(out, path):
    """Gros plan des canons : chaque époque composée sur le sol à 64 px/tuile, recadrée sur la tête et les canons."""
    tiles = []
    for e in range(2, 10):
        side = K.SIDE[e]
        ents = [{"pos": [side / 2.0 + 1.0, side / 2.0 + 1.6], "layers": K.level_layers(out, e, "E", False)}]
        Wt, Ht = side + 3.4, side + 2.6
        day, _ = K.compose(ents, Wt, Ht)
        img = K.to_im(day)
        cx, cy = ents[0]["pos"]
        # cadre serré sur la tête et ses canons (pose E : canons vers la droite), agrandi ×2 pour la lecture
        spec = K.own(out, "e%02d-tete-E" % e, ("main",))[0]
        h, w = spec["img"].shape[:2]
        sx_, sy_ = spec["shift"]
        hx0 = (cx + sx_) * 64 - w / 2.0
        hy0 = (cy + sy_) * 64 - h / 2.0
        box = (int(hx0 - 12), int(hy0 - 12), int(hx0 + w + 12), int(hy0 + h + 12))
        t = img.crop(box)
        tiles.append((e, t.resize((t.size[0] * 2, t.size[1] * 2), Image.LANCZOS)))
    f1, f2 = K.font(18), K.font(13, False)
    cols = 2
    cw = max(t[1].size[0] for t in tiles) + 20
    rows_h = []
    for i in range(0, len(tiles), cols):
        rows_h.append(max(t[1].size[1] for t in tiles[i:i + cols]) + 40)
    W = cw * cols + 20
    H = 80 + sum(rows_h)
    plate = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(plate)
    d.text((14, 10), "Canons de chaque époque · zoom 2 (64 px par tuile) agrandi ×2", font=K.font(26), fill=ACC)
    d.text((14, 44), "jour · pose E · tête et canons sur leur socle · époques 2 à 9 (l'époque 1 garde la tête vanilla)"
           " · composé hors moteur", font=K.font(14, False), fill=SUB)
    y = 80
    for i in range(0, len(tiles), cols):
        for j, (e, t) in enumerate(tiles[i:i + cols]):
            x = 10 + j * cw
            plate.paste(t, (x, y))
            a, b = label(e)
            d.text((x + 6, y + t.size[1] + 4), a, font=f1, fill=TXT)
            d.text((x + 6 + d.textlength(a + "  ", font=f1), y + t.size[1] + 7), b, font=f2, fill=SUB)
        y += rows_h[i // cols]
    plate.save(path)
    print(path)


def pairs_plate(out, path, zoom=1, epochs=range(1, 10)):
    items, labels = [], []
    for e in epochs:
        if e == 1:
            items.append(("v", K.vanilla_gun("E"), 2))
            labels.append(("niv. 1 · vanilla", "époque 1 · impair"))
            items.append(("p", K.level_layers(out, 1, "E", True), 2))
            labels.append(("niv. 2", "époque 1 · pair"))
            continue
        items.append(("o%d" % e, K.level_layers(out, e, "E", False), K.SIDE[e]))
        labels.append(("niv. %d" % (2 * e - 1), "époque %d · %s · impair" % (e, K.NAME[e])))
        items.append(("p%d" % e, K.level_layers(out, e, "E", True), K.SIDE[e]))
        labels.append(("niv. %d" % (2 * e), "époque %d · pair" % e))
    ents, Wt, Ht, xs = row(out, items, "E", gap=0.7, minslot=(2.6 if zoom == 2 else 5.0))
    day, _ = K.compose(ents, Wt, Ht)
    img = K.to_im(day if zoom == 2 else K.down2(day))
    ppt = 64 if zoom == 2 else 32
    sub = ("niveau impair puis niveau pair (pièce aux coins avant) · pose E · jour · %d px par tuile · composé hors moteur"
           % ppt)
    framed(img, "Impair contre pair · zoom %d" % zoom, sub, xs, labels, ppt).save(path)
    print(path)


def grey_plate(out, path):
    """Planche (a) en niveaux de gris (test noir et blanc, exigence (d)) : même composition, luma Rec. 709."""
    items = items_line(out, "E")
    ents, Wt, Ht, xs = row(out, items, "E", minslot=5.4)
    day, _ = K.compose(ents, Wt, Ht)
    rgb = K.down2(day)
    g = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    img = K.to_im(np.stack([g, g, g], -1))
    labels = [("vanilla", "niv. 1 · 2×2", "repère")] + [label(1, True)] + [label(e) for e in range(2, 10)]
    framed(img, "Test noir et blanc · époques 1 à 9 · jour · zoom 1", "pose E · 32 px par tuile · luma Rec. 709 · "
           "composé hors moteur", xs, labels, 32).save(path)
    print(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("dest")
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    P = lambda n: os.path.join(a.dest, n)  # noqa: E731
    line_plate(a.out, "E", False, P("a-zoom1-jour-E.png"), "Mitrailleuse V3-E · époques 1 à 9 · jour · zoom 1")
    line_plate(a.out, "E", True, P("a-zoom1-nuit-E.png"), "Mitrailleuse V3-E · époques 1 à 9 · nuit · zoom 1")
    line_plate(a.out, "N", False, P("b-zoom1-jour-N.png"), "Mitrailleuse V3-E · époques 1 à 9 · pose N · jour · zoom 1")
    grey_plate(a.out, P("a-zoom1-gris-E.png"))
    guns_plate(a.out, P("c-canons-zoom2.png"))
    pairs_plate(a.out, P("d-impair-pair-ere1-zoom2.png"), zoom=2, epochs=range(1, 4))
    pairs_plate(a.out, P("d-impair-pair-ere2-zoom1.png"), zoom=1, epochs=range(4, 7))
    pairs_plate(a.out, P("d-impair-pair-ere3-zoom1.png"), zoom=1, epochs=range(7, 10))


if __name__ == "__main__":
    main()
