"""Planches de l'exploration hybride : la mitrailleuse vanilla (niveau 1) puis les niveaux 11, 21, 29 et 30, à
côté de bâtiments vanilla de référence (tourelle laser, machine d'assemblage 3, réacteur nucléaire), sur un sol
vanilla, de jour et de nuit, au zoom 2 (64 px/tuile, sprites HR 1:1) et au zoom 1 (32 px/tuile), même échelle
partout (charte §6.5 : la taille doit se lire).

    python planches.py <couches (rendre.py --out)> <dossier des dumps vanilla> <sortie>

Composition (recopie de tools/render/calib/maquette.py, qui suit les shaders du jeu) : ombres = tampon d'ombre
(maximum des alphas), sol × (1 − 0,5 × alpha) ; entités dans l'ordre de leur position (y puis x), couches dans
l'ordre de dessin (socle puis tête) ; lueur additive (jour) ajoutée à la carte des lumières ; nuit =
mix(LUT_nuit(jour), jour, lumière) avec lut-night.png du jeu ; lightMul et lightAdd du moteur inconnus (1 et 0).
Les lumières moteur (LightDefinition) du vanilla ne sont PAS des sprites : la nuit, les bâtiments vanilla
paraissent plus sombres qu'en jeu (limite connue de la maquette). Zoom 1 : moyenne 2×2 en lumière linéaire.
Vanilla : couches lues dans le Lua vanilla (dumps de tests/datastage/harness.lua --dump-proto), image 0.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(RENDER, "calib"))
CHARTE = os.environ.get("FO_CHARTE", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3S\charte\outils")
sys.path.insert(0, CHARTE)
import da_lib as DL  # noqa: E402
import fo_post as P  # noqa: E402
from maquette import lut_apply  # noqa: E402
import design as Dz  # noqa: E402
import json  # noqa: E402

DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
PPT = 64
try:
    FONT = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 22)
    FONTS = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    FONTB = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 26)
except OSError:
    FONT = FONTS = FONTB = ImageFont.load_default()


def dump(dumps, n):
    return DL.parse_dump(open(os.path.join(dumps, n + ".txt"), encoding="utf-8", errors="replace").read())


def vanilla(dumps, which, pose="E"):
    """Couches vanilla (img RGBA float, shift, kind) : main / shadow / glow / light ; masques d'équipe teintés."""
    idx = "E" if pose == "E" else 0
    if which == "gun":
        d = dump(dumps, "ammo-turret_gun-turret")
        nodes = [(d["base_picture"], 0, None), (d["prepared_animation"], idx, None)]
    elif which == "laser":
        d = dump(dumps, "electric-turret_laser-turret")
        nodes = [(d["base_picture"], 0, None), (d["prepared_animation"], idx, None)]
    elif which == "am3":
        d = dump(dumps, "assembling-machine_assembling-machine-3")
        nodes = [(d["animation"], 0, None)]
    elif which == "reactor":
        d = dump(dumps, "reactor_nuclear-reactor")
        nodes = [(d["lower_layer_picture"], 0, None), (d["picture"], 0, None), (d["working_light_picture"], 0, "light")]
    lays = DL.vanilla_layers(nodes, DATA)
    out = []
    for l in lays:
        img = l["img"].astype(np.float64)
        k = l["kind"]
        if k == "mask":
            lum = img[..., :3].mean(-1, keepdims=True)
            img = np.concatenate([lum * np.array(DL.TEAM_TINT), img[..., 3:4]], -1)
            k = "main"
        out.append({"img": img, "shift": l["shift"], "kind": k})
    # ombres d'abord (tampon d'ombre), puis l'ordre déclaré
    return out


def own(root, name, kinds=("shadow", "main", "glow", "light")):
    d = os.path.join(root, name)
    spec = json.load(open(os.path.join(d, "spec.json"), encoding="utf-8"))
    out = []
    for k in kinds:
        if k in spec["layers"]:
            s = spec["layers"][k]
            img = np.asarray(Image.open(os.path.join(d, s["file"])).convert("RGBA")).astype(np.float64) / 255.0
            out.append({"img": img, "shift": tuple(s["shift"]), "kind": k})
    return out


def level(root, lv, pose):
    return own(root, "n%02d-socle" % lv) + own(root, "n%02d-tete-%s" % (29 if lv == 30 else lv, pose))


def compose(entities, W_t, H_t):
    """Recopie de maquette.compose, positions arrondies au pixel. Renvoie (jour, lumière, nuit) en sRGB [0, 1]."""
    W, H = int(W_t * PPT), int(H_t * PPT)
    ground = DL.load_rgba(os.path.join(DATA, "base", "graphics", "terrain", "hr-dirt-4.png"))[320:576, :, :3].astype(np.float64)
    gh, gw = ground.shape[:2]
    day = np.tile(ground, (H // gh + 1, W // gw + 1, 1))[:H, :W].copy()
    shadow = np.zeros((H, W))
    light = np.zeros((H, W, 3))

    def place(lay, pos):
        img = lay["img"]
        h, w = img.shape[:2]
        x0 = int(round(pos[0] * PPT + lay["shift"][0] * PPT - w / 2.0))
        y0 = int(round(pos[1] * PPT + lay["shift"][1] * PPT - h / 2.0))
        xs0, ys0 = max(0, -x0), max(0, -y0)
        xd0, yd0 = max(0, x0), max(0, y0)
        ww, hh = min(w - xs0, W - xd0), min(h - ys0, H - yd0)
        return img[ys0:ys0 + hh, xs0:xs0 + ww], (slice(yd0, yd0 + hh), slice(xd0, xd0 + ww))

    for e in entities:
        for lay in e["layers"]:
            if lay["kind"] == "shadow":
                src, d = place(lay, e["pos"])
                shadow[d] = np.maximum(shadow[d], src[..., 3])
    day = day * (1 - 0.5 * shadow)[..., None]
    for e in sorted(entities, key=lambda e: (e["pos"][1], e["pos"][0])):
        for lay in e["layers"]:
            if lay["kind"] == "shadow":
                continue
            src, d = place(lay, e["pos"])
            a = src[..., 3:4]
            if lay["kind"] == "main":
                day[d] = src[..., :3] * a + day[d] * (1 - a)
            elif lay["kind"] == "glow":
                day[d] = np.clip(day[d] + src[..., :3] * a, 0, 1)
                light[d] += src[..., :3] * a
            elif lay["kind"] == "light":
                light[d] += src[..., :3] * a
    light = np.clip(light, 0, 1)
    night_lut = lut_apply(day, os.path.join(DATA, "core", "graphics", "color_luts", "lut-night.png"))
    night = night_lut * (1 - light) + day * light
    return day, night


def down2(rgb):
    h, w = rgb.shape[:2]
    lin = P.srgb_to_lin(rgb[:h // 2 * 2, :w // 2 * 2])
    return P.lin_to_srgb(lin.reshape(h // 2, 2, w // 2, 2, 3).mean((1, 3)))


def to_img(rgb):
    return Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")


def labelled(rgb, labels, title, zoom, band=80):
    """Ajoute un titre en haut et les étiquettes sous chaque entité (labels : [(x_tuiles, y_tuiles, lignes)])."""
    im = to_img(rgb)
    k = 1 if zoom == 2 else 0.5
    out = Image.new("RGB", (im.width, im.height + band + 40), (28, 28, 28))
    out.paste(im, (0, 40))
    d = ImageDraw.Draw(out)
    d.text((10, 6), title, fill=(235, 235, 235), font=FONTB if zoom == 2 else FONT)
    for x, y, lines in labels:
        px = int(x * PPT * k)
        py = int(y * PPT * k) + 40
        for j, t in enumerate(lines):
            f = FONT if (zoom == 2 and j == 0) else (FONTS if zoom == 1 else FONT)
            w = d.textlength(t, font=f)
            d.text((px - w / 2, py + 4 + j * (22 if zoom == 2 else 17)), t, fill=(240, 240, 240) if j == 0 else (200, 200, 200),
                   font=f)
    return out


def row(root, dumps, pose, y_base, x0=1.0, gap=2.0):
    """Une rangée : vanilla n1, laser, n11, assembleuse 3, n21, réacteur, n29, n30 (bas des emprises alignés)."""
    items = [("gun", 2, "mitrailleuse", "vanilla n1, 2×2"),
             ("laser", 2, "laser", "vanilla, 2×2"),
             (11, 3, "hybride n11", "ép. 6, 3×3"),
             ("am3", 3, "assembleuse 3", "vanilla, 3×3"),
             (21, 5, "hybride n21", "ép. 11, 5×5"),
             ("reactor", 5, "réacteur", "vanilla, 5×5"),
             (29, 6, "hybride n29", "ép. 15, 6×6"),
             (30, 6, "hybride n30", "+ bastions, 6×6")]
    ents, labels = [], []
    x = x0
    for key, side, l1, l2 in items:
        cx = x + side / 2.0
        cy = y_base - side / 2.0
        lays = level(root, key, pose) if isinstance(key, int) else vanilla(dumps, key, pose)
        ents.append({"pos": (cx, cy), "layers": lays})
        labels.append((cx, y_base + 0.15, [l1, l2]))
        x += side + gap
    return ents, labels, x


def main():
    root, dumps, out = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    # deux rangées : pose E (méthode de la charte) puis pose N
    top = 3.2           # marge au-dessus des plus grands (dépassement de la tête)
    e1, l1, wx = row(root, dumps, "E", top + 6.0)
    y2 = top + 6.0 + 1.6 + top + 6.0 - 1.4
    e2, l2, _ = row(root, dumps, "N", y2)
    W_t = wx + 0.2
    H_t = y2 + 1.6
    day, night = compose(e1 + e2, W_t, H_t)
    labels = l1 + l2
    titles = {"jour": "de jour", "nuit": "de nuit (maquette : lumières moteur vanilla absentes)"}
    files = []
    for tag, img in (("jour", day), ("nuit", night)):
        t2 = "Mitrailleuse « hybride progressive » (V3-S) : vanilla n1 puis n11, n21, n29, n30 parmi des bâtiments vanilla ; zoom 2 (64 px/tuile), %s ; rangée 1 pose E, rangée 2 pose N" % titles[tag]
        p = os.path.join(out, "planche-hybride-zoom2-%s.png" % tag)
        labelled(img, labels, t2, 2).save(p, optimize=True)
        files.append(p)
        t1 = "Hybride V3-S, zoom 1 (32 px/tuile, vue du joueur), %s ; rangée 1 pose E, rangée 2 pose N" % titles[tag]
        p = os.path.join(out, "planche-hybride-zoom1-%s.png" % tag)
        labelled(down2(img), labels, t1, 1, band=60).save(p, optimize=True)
        files.append(p)
    # gros plans zoom 2 (×2 au plus proche) : chaque niveau témoin en pose E, de jour
    for lv, side in ((11, 3), (21, 5), (29, 6), (30, 6)):
        ents = [{"pos": (side / 2.0 + 0.8, 3.0 + side / 2.0), "layers": level(root, lv, "E")}]
        d1, n1 = compose(ents, side + 3.4, side + 4.2)
        for tag, img in (("jour", d1), ("nuit", n1)):
            im = to_img(img)
            im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
            p = os.path.join(out, "gros-plan-n%02d-E-zoom2x2-%s.png" % (lv, tag))
            im.save(p, optimize=True)
            files.append(p)
    # test du regard naïf (charte §6.5) : paires (e, e+k) au même zoom, ordre mélangé (graine fixe), clé à part
    import random
    rnd = random.Random(15)
    pairs = [((1, "gun", 2), (11, 11, 3)), ((11, 11, 3), (21, 21, 5)), ((21, 21, 5), (29, 29, 6)), ((1, "gun", 2), (29, 29, 6)),
             ((29, 29, 6), (30, 30, 6))]
    ents, labels, key = [], [], []
    x = 1.0
    for i, (a, b) in enumerate(pairs):
        ab = [a, b]
        if rnd.random() < 0.5:
            ab = [b, a]
        for j, (lvl, k, side) in enumerate(ab):
            cx = x + side / 2.0
            cy = 3.2 + 6.0 - side / 2.0
            lays = vanilla(dumps, "gun", "E") if k == "gun" else level(root, k, "E")
            ents.append({"pos": (cx, cy), "layers": lays})
            labels.append((cx, 9.35, ["paire %d : %s" % (i + 1, "AB"[j])]))
            key.append("paire %d, %s = niveau %d" % (i + 1, "AB"[j], lvl))
            x += side + 0.8
        x += 1.4
    d1, _ = compose(ents, x, 10.0)
    p = os.path.join(out, "regard-naif-pose-E-zoom2.png")
    labelled(d1, labels, "Test du regard naïf (charte §6.5) : dans chaque paire, lequel est le plus puissant ? (clé : regard-naif-cle.txt)", 2,
             band=40).save(p, optimize=True)
    files.append(p)
    open(os.path.join(out, "regard-naif-cle.txt"), "w", encoding="utf-8").write("\n".join(key) + "\n")
    for f in files:
        print(f)


if __name__ == "__main__":
    main()
