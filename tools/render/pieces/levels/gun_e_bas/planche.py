"""Planches de la mitrailleuse « industriel lourd » (lot V3-S) : même zoom pour tout, sol vanilla, jour et nuit,
zoom 2 (64 px/tuile, sprites hr 1:1) et zoom 1 (32 px/tuile, réduction 2×2 en lumière linéaire).

    python tools/render/pieces/levels/gun_s_industriel/planche.py <racine>/data <dumps --dump-proto> <outils charte>
           <dossier de sortie> [--pose E] [--mesures mesures.json]

Rangée avant : mitrailleuse vanilla (niveau 1, pose E), niveaux 11, 21, 29 et 30 de cette exploration.
Rangée arrière : bâtiments vanilla de référence (tourelle laser, machine d'assemblage 3, réacteur nucléaire, silo
à fusée), couches et décalages lus dans le Lua vanilla (dumps du banc data, da_lib.vanilla_layers).
Composition comme tools/render/calib/maquette.py (fonctions reprises : LUT de nuit de game.frag, sol
hr-dirt-4) : ombres (max des alphas, sol × (1 − 0,5 a)), entités par position, lueur additive (jour + carte des
lumières), halo dans la carte des lumières ; nuit = mix(LUT_nuit(jour), jour, lumière). lightMul/lightAdd du
moteur inconnus (pris à 1 et 0) : la nuit n'est qu'une approximation hors moteur.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
WORK = os.environ.get("FO_IND_WORK", "H:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/fo-logs/2026-10-22_V3S/industriel")
OUT = os.path.join(WORK, "out")
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(RENDER, "calib"))
import fo_post as P  # noqa: E402
from maquette import lut_apply  # noqa: E402

try:
    FONT = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 15)
    FONTB = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 17)
except OSError:
    FONT = FONTB = ImageFont.load_default()

TINT = (0.869, 0.5, 0.13)


def own(name, kinds=("shadow", "main", "glow", "light")):
    spec = json.load(open(os.path.join(OUT, name, "spec.json"), encoding="utf-8"))
    out = []
    for k in kinds:
        if k in spec["layers"]:
            s = spec["layers"][k]
            img = np.asarray(Image.open(os.path.join(OUT, name, s["file"])).convert("RGBA")).astype(np.float64) / 255
            out.append({"img": img, "shift": tuple(s["shift"]), "kind": k})
    return out


def vanilla(D, dumps, data, dump, fn):
    d = D.parse_dump(open(os.path.join(dumps, dump + ".txt"), encoding="utf-8", errors="replace").read())
    nodes = [n for n in fn(d) if n[0] is not None]
    lays = D.vanilla_layers(nodes, data)
    return [{"img": l["img"].astype(np.float64), "shift": l["shift"], "kind": l["kind"]} for l in lays]


def compose(data, ents, W_t, H_t, ppt=64):
    W, H = int(W_t * ppt), int(H_t * ppt)
    ground = np.asarray(Image.open(os.path.join(data, "base", "graphics", "terrain", "hr-dirt-4.png"))
                        .convert("RGB")).astype(np.float64)[320:576] / 255.0
    gh, gw = ground.shape[:2]
    day = np.tile(ground, (H // gh + 1, W // gw + 1, 1))[:H, :W].copy()
    shadow = np.zeros((H, W))
    light = np.zeros((H, W, 3))

    def place(lay, pos):
        img = lay["img"]
        h, w = img.shape[:2]
        x0 = int(round(pos[0] * ppt + lay["shift"][0] * ppt - w / 2.0))
        y0 = int(round(pos[1] * ppt + lay["shift"][1] * ppt - h / 2.0))
        xs0, ys0 = max(0, -x0), max(0, -y0)
        xd0, yd0 = max(0, x0), max(0, y0)
        ww, hh = min(w - xs0, W - xd0), min(h - ys0, H - yd0)
        if ww <= 0 or hh <= 0:
            return None, None
        return img[ys0:ys0 + hh, xs0:xs0 + ww], (slice(yd0, yd0 + hh), slice(xd0, xd0 + ww))

    for e in ents:
        for lay in e["layers"]:
            if lay["kind"] == "shadow":
                src, d = place(lay, e["pos"])
                if src is not None:
                    shadow[d] = np.maximum(shadow[d], src[..., 3])
    day = day * (1 - 0.5 * shadow)[..., None]
    for e in sorted(ents, key=lambda e: (e["pos"][1], e["pos"][0])):
        for lay in e["layers"]:
            if lay["kind"] == "shadow":
                continue
            src, d = place(lay, e["pos"])
            if src is None:
                continue
            a = src[..., 3:4]
            if lay["kind"] == "main":
                day[d] = src[..., :3] * a + day[d] * (1 - a)
            elif lay["kind"] == "mask":
                lum = src[..., :3].mean(-1, keepdims=True)
                day[d] = lum * np.array(TINT) * a + day[d] * (1 - a)
            elif lay["kind"] == "glow":
                day[d] = np.clip(day[d] + src[..., :3] * a, 0, 1)
                light[d] += src[..., :3] * a
            elif lay["kind"] == "light":
                light[d] += src[..., :3] * a
    light = np.clip(light, 0, 1)
    night = lut_apply(day, os.path.join(data, "core", "graphics", "color_luts", "lut-night.png"))
    night = night * (1 - light) + day * light
    return day, night


def down2(rgb):
    h, w = rgb.shape[:2]
    lin = P.srgb_to_lin(rgb[:h // 2 * 2, :w // 2 * 2])
    return P.lin_to_srgb(lin.reshape(h // 2, 2, w // 2, 2, 3).mean((1, 3)))


def to_im(rgb):
    return Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")


def board(rgb, labels, title, path, scale):
    im = to_im(rgb)
    W, H = im.size
    sheet = Image.new("RGB", (W, H + 30), (22, 22, 22))
    sheet.paste(im, (0, 30))
    d = ImageDraw.Draw(sheet)
    d.text((8, 6), title, fill=(235, 235, 235), font=FONTB)
    for (x, y), lines in labels:
        for j, line in enumerate(lines):
            tx, ty = int(x * scale), int(y * scale) + 30 + j * 16
            d.text((tx + 1, ty + 1), line, fill=(0, 0, 0), font=FONT)
            d.text((tx, ty), line, fill=(240, 240, 225), font=FONT)
    sheet.save(path, optimize=True)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("data")
    ap.add_argument("dumps")
    ap.add_argument("outils")
    ap.add_argument("out")
    ap.add_argument("--pose", default="E")
    ap.add_argument("--mesures", default="")
    a = ap.parse_args()
    sys.path.insert(0, a.outils)
    import da_lib as D
    os.makedirs(a.out, exist_ok=True)
    meas = {}
    if a.mesures and os.path.exists(a.mesures):
        meas = {r["niveau"]: r for r in json.load(open(a.mesures, encoding="utf-8"))}
    pose = a.pose
    gun = vanilla(D, a.dumps, a.data, "ammo-turret_gun-turret",
                  lambda d: [(d["base_picture"], 0, None), (d["prepared_animation"], 0 if pose == "N" else pose, None)])
    laser = vanilla(D, a.dumps, a.data, "electric-turret_laser-turret",
                    lambda d: [(d["base_picture"], 0, None), (d["prepared_animation"], 0 if pose == "N" else pose, None)])
    am3 = vanilla(D, a.dumps, a.data, "assembling-machine_assembling-machine-3", lambda d: [(d["animation"], 0, None)])
    reactor = vanilla(D, a.dumps, a.data, "reactor_nuclear-reactor",
                      lambda d: [(d["lower_layer_picture"], 0, None), (d["picture"], 0, None),
                                 (d["working_light_picture"], 0, "light")])
    silo = vanilla(D, a.dumps, a.data, "rocket-silo_rocket-silo",
                   lambda d: [(d["hole_sprite"], 0, None), (d["door_back_sprite"], 0, None),
                              (d["door_front_sprite"], 0, None), (d["base_day_sprite"], 0, None),
                              (d["base_front_sprite"], 0, None), (d["red_lights_back_sprites"], 0, "glow"),
                              (d["red_lights_front_sprites"], 0, "glow")])
    # rangée arrière (références vanilla) : y = 6 ; rangée avant (tourelles) : y = 16,5
    yb, yf = 6.5, 17.0
    ents = [
        {"pos": (2.0, yb + 2.0), "layers": laser, "lab": ["tourelle laser 2×2"]},
        {"pos": (5.5, yb + 1.5), "layers": am3, "lab": ["assembleuse 3 · 3×3"]},
        {"pos": (11.5, yb + 1.0), "layers": reactor, "lab": ["réacteur nucléaire 5×5"]},
        {"pos": (21.5, yb - 0.5), "layers": silo, "lab": ["silo à fusée 9×9"]},
        {"pos": (2.0, yf), "layers": gun, "lab": ["niv. 1 · époque 1", "vanilla · 2×2"]},
    ]
    x = 4.5
    for lvl, (socle, tete, side, ep) in ((11, ("e06-socle", "e06-tete", 3, 6)), (21, ("e11-socle", "e11-tete", 5, 11)),
                                         (29, ("e15-socle", "e15-tete", 6, 15)),
                                         (30, ("e15-socle-piece", "e15-tete", 6, 15))):
        if not os.path.exists(os.path.join(OUT, socle, "spec.json")):
            continue
        x += side / 2.0
        lab = ["niv. %d · époque %d" % (lvl, ep), "emprise %d×%d" % (side, side)]
        r = meas.get(lvl)
        if r and lvl == 30:
            lab.append("= niv. 29 + cellules")
        ents.append({"pos": (x, yf - (side - 2) / 2.0 * 0.0), "layers": own(socle) + own("%s-%s" % (tete, pose)),
                     "lab": lab, "side": side})
        x += side / 2.0 + 1.0
    Wt = max(31.0, x + 0.5)
    Ht = yf + 4.9
    day, night = compose(a.data, ents, Wt, Ht)
    labels = []
    for e in ents:
        side = e.get("side", 2)
        labels.append(((e["pos"][0] - side / 2.0) * 64, (e["pos"][1] + side / 2.0 + 0.25) * 64, e["lab"]))
    labels = [((x0, y0), lab) for x0, y0, lab in labels]
    files = []
    tag = "pose %s" % pose
    files.append(board(day, labels, "Industriel lourd : vanilla niv. 1 puis niv. 11, 21, 29, 30 ; références vanilla au fond ; zoom 2, jour, %s" % tag,
                       os.path.join(a.out, "planche-industriel-zoom2-jour-%s.png" % pose), 1.0))
    files.append(board(night, labels, "Industriel lourd : zoom 2, nuit (LUT de game.frag, hors moteur), %s" % tag,
                       os.path.join(a.out, "planche-industriel-zoom2-nuit-%s.png" % pose), 1.0))
    files.append(board(down2(day), labels, "Industriel lourd : zoom 1 (32 px/tuile), jour, %s" % tag,
                       os.path.join(a.out, "planche-industriel-zoom1-jour-%s.png" % pose), 0.5))
    files.append(board(down2(night), labels, "Industriel lourd : zoom 1, nuit (hors moteur), %s" % tag,
                       os.path.join(a.out, "planche-industriel-zoom1-nuit-%s.png" % pose), 0.5))
    # gros plan zoom 2 de la rangée avant
    y0, y1 = int((yf - 6.5) * 64), int((yf + 3.6) * 64)
    gp = day[y0:y1, :int((x + 0.2) * 64)]
    files.append(board(gp, [((l[0][0], l[0][1] - y0), l[1]) for l in labels if l[0][1] > y0],
                       "Industriel lourd : rangée des tourelles, zoom 2, jour, %s" % tag,
                       os.path.join(a.out, "planche-industriel-tourelles-zoom2-jour-%s.png" % pose), 1.0))
    print("\n".join(files))


if __name__ == "__main__":
    main()
