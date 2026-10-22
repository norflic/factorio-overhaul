"""Planches de l'explorateur « haute technologie » (lot V3-S), composées hors moteur.

    python ht_planches.py --dumps <dossier des dumps --dump-proto> --out <dossier> [--poses E,N]

Une rangée par pose, même échelle pour tout, sur le sol vanilla (hr-dirt-4, comme les planches de V3 phase 1) :
  mitrailleuse vanilla (niveau 1, 2×2) | niveau 11 (3×3) | niveau 21 (5×5) | niveau 29 (6×6) | niveau 30 (6×6)
  || références vanilla : tourelle laser (2×2), machine d'assemblage 3 (3×3), réacteur nucléaire (5×5),
  silo à fusée (9×9).
Règles de composition (planches.py de V3 phase 1, maquette.py du pipeline) : ombres dans un tampon commun (sol ×
(1 − 0,5 × alpha), shadow-a8.frag) ; couches lower-object (socles des tourelles) de toutes les entités, puis
couches object ; lueur additive (jour) et carte des lumières (nuit) ; nuit = LUT lut-night.png du jeu mélangée au
jour par la carte des lumières (lightMul / lightAdd du moteur inconnus : NON PROUVÉ hors moteur) ; masques
d'équipe vanilla teints en orange joueur. Zoom 2 = 64 px/tuile ; zoom 1 = réduction 2× en lumière linéaire.
Les sprites vanilla et leurs décalages viennent des dumps du Lua vanilla (da_lib.vanilla_layers de la charte).
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "calib"))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_post as P  # noqa: E402
import ht_gun as H  # noqa: E402
import ht_post  # noqa: E402
from maquette import lut_apply, down2  # noqa: E402

CHARTE = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3S\charte\outils"
sys.path.insert(0, CHARTE)
import da_lib as D  # noqa: E402

DATA = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data"
PPT = 64
RENDERS = None    # dossier des rendus post-traités (--renders)
TEAM = np.array((0.869, 0.5, 0.130), np.float32)


def font(size, bold=False):
    for f in (("arialbd.ttf",) if bold else ()) + ("arial.ttf", "segoeui.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            continue
    return ImageFont.load_default()


def load_dump(dumps, n):
    with open(os.path.join(dumps, n + ".txt"), encoding="utf-8", errors="replace") as f:
        return D.parse_dump(f.read())


def vanilla(dumps, name, pose):
    """Couches vanilla (img, shift, kind, module) d'un bâtiment de référence, ombres comprises."""
    dir_idx = "E" if pose == "E" else 0
    if name == "gun-turret":
        d = load_dump(dumps, "ammo-turret_gun-turret")
        socle = D.vanilla_layers([(d["base_picture"], 0, None)], DATA)
        tete = D.vanilla_layers([(d["prepared_animation"], dir_idx, None)], DATA)
    elif name == "laser-turret":
        d = load_dump(dumps, "electric-turret_laser-turret")
        socle = D.vanilla_layers([(d["base_picture"], 0, None)], DATA)
        tete = D.vanilla_layers([(d["prepared_animation"], dir_idx, None), (d["energy_glow_animation"], dir_idx, "light")],
                                DATA)
    elif name == "assembling-machine-3":
        d = load_dump(dumps, "assembling-machine_assembling-machine-3")
        socle, tete = [], D.vanilla_layers([(d["animation"], 0, None)], DATA)
    elif name == "nuclear-reactor":
        d = load_dump(dumps, "reactor_nuclear-reactor")
        socle = D.vanilla_layers([(d["lower_layer_picture"], 0, None)], DATA)
        tete = D.vanilla_layers([(d["picture"], 0, None), (d["working_light_picture"], 0, "light")], DATA)
    elif name == "rocket-silo":
        d = load_dump(dumps, "rocket-silo_rocket-silo")
        socle = D.vanilla_layers([(d["hole_sprite"], 0, None), (d["door_back_sprite"], 0, None),
                                  (d["door_front_sprite"], 0, None)], DATA)
        tete = D.vanilla_layers([(d["base_day_sprite"], 0, None), (d["base_front_sprite"], 0, None),
                                 (d["red_lights_back_sprites"], 0, "glow"), (d["red_lights_front_sprites"], 0, "glow")],
                                DATA)
    else:
        raise KeyError(name)
    for l in socle:
        l["module"] = "socle"
    for l in tete:
        l["module"] = "tete"
    out = socle + tete
    for l in out:
        if l["kind"] == "mask":
            img = l["img"].copy()
            img[..., :3] = img[..., :3].mean(-1, keepdims=True) * TEAM
            l["img"] = img
            l["kind"] = "main"
    return out


def ours(level, pose):
    """Couches de l'explorateur (spec.json de ht_post), ombres comprises."""
    hl = 29 if level == 30 else level
    out = []
    for var, mod in (("n%02d-socle" % level, "socle"), ("n%02d-tete-%s" % (hl, pose), "tete")):
        d = os.path.join(RENDERS, var)
        with open(os.path.join(d, "spec.json"), encoding="utf-8") as f:
            spec = json.load(f)
        for k in ("shadow", "main", "glow", "light"):
            if k in spec["layers"]:
                s = spec["layers"][k]
                out.append({"img": D.load_rgba(os.path.join(d, s["file"])).copy(), "shift": tuple(s["shift"]),
                            "kind": k, "module": mod})
    return out


def ground(W, Hh):
    g = D.load_rgba(os.path.join(DATA, "base", "graphics", "terrain", "hr-dirt-4.png"))[320:576, :, :3]
    gh, gw = g.shape[:2]
    return np.tile(g, (Hh // gh + 1, W // gw + 1, 1))[:Hh, :W].astype(np.float64).copy()


def compose(ents, W, Hh):
    day = ground(W, Hh)
    shadow = np.zeros((Hh, W))
    light = np.zeros((Hh, W, 3))

    def region(l, pos):
        img = l["img"]
        h, w = img.shape[:2]
        xi = int(round(pos[0] + l["shift"][0] * PPT - w / 2.0))
        yi = int(round(pos[1] + l["shift"][1] * PPT - h / 2.0))
        xs0, ys0 = max(0, -xi), max(0, -yi)
        xd0, yd0 = max(0, xi), max(0, yi)
        ww, hh = min(w - xs0, W - xd0), min(h - ys0, Hh - yd0)
        if ww <= 0 or hh <= 0:
            return None
        return img[ys0:ys0 + hh, xs0:xs0 + ww].astype(np.float64), (slice(yd0, yd0 + hh), slice(xd0, xd0 + ww))

    for e in ents:
        for l in e["layers"]:
            if l["kind"] == "shadow":
                r = region(l, e["pos"])
                if r:
                    shadow[r[1]] = np.maximum(shadow[r[1]], r[0][..., 3])
    day = day * (1 - 0.5 * shadow)[..., None]
    order = sorted(ents, key=lambda e: (e["pos"][1], e["pos"][0]))
    passes = [(e, l) for e in order for l in e["layers"] if l["module"] == "socle"]
    passes += [(e, l) for e in order for l in e["layers"] if l["module"] != "socle"]
    for e, l in passes:
        if l["kind"] == "shadow":
            continue
        r = region(l, e["pos"])
        if not r:
            continue
        src, sl = r
        a = src[..., 3:4]
        if l["kind"] == "main":
            day[sl] = src[..., :3] * a + day[sl] * (1 - a)
        elif l["kind"] == "glow":
            day[sl] = np.clip(day[sl] + src[..., :3] * a, 0, 1)
            light[sl] += src[..., :3] * a
        elif l["kind"] == "light":
            light[sl] += src[..., :3] * a
    light = np.clip(light, 0, 1)
    night = lut_apply(day, os.path.join(DATA, "core", "graphics", "color_luts", "lut-night.png")) * (1 - light) + \
        day * light
    return day, night


ROW = [("v", "gun-turret", 2, "niveau 1 · époque 1 (vanilla)", "mitrailleuse 2×2"),
       ("o", 11, 3, "niveau 11 · époque 6", "3×3"),
       ("o", 21, 5, "niveau 21 · époque 11", "5×5"),
       ("o", 29, 6, "niveau 29 · époque 15", "6×6"),
       ("o", 30, 6, "niveau 30 · époque 15", "6×6 + pièce (lance-missiles)"),
       ("sep",),
       ("v", "laser-turret", 2, "tourelle laser", "vanilla 2×2"),
       ("v", "assembling-machine-3", 3, "assembleuse 3", "vanilla 3×3"),
       ("v", "nuclear-reactor", 5, "réacteur nucléaire", "vanilla 5×5"),
       ("v", "rocket-silo", 9, "silo à fusée", "vanilla 9×9")]


def row_scene(dumps, pose, mesures=None, gap=2.0, top=4.2, bottom=1.2):
    x = 2.2
    ents, labels, seps = [], [], []
    for it in ROW:
        if it[0] == "sep":
            seps.append(x + 0.2)
            x += 1.2
            continue
        kind, key, side = it[0], it[1], it[2]
        cx = x + side / 2.0
        try:
            lay = vanilla(dumps, key, pose) if kind == "v" else ours(key, pose)
        except FileNotFoundError:
            lay = []
            it = it[:4] + ("(non rendu)",)
        ents.append({"pos": (cx * PPT, None), "layers": lay, "side": side})
        sub = it[4]
        if kind == "o" and mesures and (key, pose) in mesures:
            m = mesures[(key, pose)]
            sub = "%s · %.1f t² · %d pièces" % (it[4], m["masse_tuiles2"], m["petites_pieces"])
        labels.append((cx, it[3], sub))
        x += side + gap + (1.6 if kind == "o" and pose == "E" else 0.0)   # canons qui débordent à l est
    W = int((x + 0.4) * PPT)
    maxside = 9
    base_y = (top + maxside) * PPT     # bord sud commun des emprises
    for e in ents:
        e["pos"] = (e["pos"][0], base_y - e["side"] / 2.0 * PPT)
    Hh = int(base_y + bottom * PPT)
    return ents, labels, seps, W, Hh, base_y


def to_img(rgb):
    return Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")


def annotate(im, labels, seps, base_y, scale, title):
    """scale = pixels par tuile de l'image (64 ou 32)."""
    W, Hh = im.size
    T = 30
    out = Image.new("RGB", (W, Hh + T + 2 * int(scale * 0.55)), (24, 22, 20))
    out.paste(im, (0, T))
    dr = ImageDraw.Draw(out)
    dr.text((8, T / 2), title, fill=(235, 230, 215), font=font(15 if scale == 64 else 13, True), anchor="lm")
    fy = T + base_y * scale / PPT + 4
    f1, f2 = font(14 if scale == 64 else 11, True), font(13 if scale == 64 else 10)
    for (cx, t1, t2) in labels:
        x = cx * scale
        dr.text((x, fy + 2), t1, fill=(250, 245, 230), font=f1, anchor="mt")
        dr.text((x, fy + (20 if scale == 64 else 15)), t2, fill=(200, 192, 170), font=f2, anchor="mt")
    for sx in seps:
        x = sx * scale
        dr.line([(x, T + 8), (x, out.height - 6)], fill=(120, 110, 90), width=2)
    return out


def naive_pairs(dumps, out, pairs):
    """Test du regard naïf (charte §6.5) : une image par paire, deux bâtiments côte à côte, zoom 1, jour, pose E,
    sol vanilla, même échelle, SEULEMENT « A » et « B » en légende. `pairs` = [(fichier, gauche, droite), ...] où
    gauche/droite valent 1 (mitrailleuse vanilla) ou un niveau de l'explorateur. Rien d'autre n'est écrit : la clé
    n'existe que dans la valeur de retour de l'agent."""
    os.makedirs(out, exist_ok=True)
    written = []
    for fn, left, right in pairs:
        ents = []
        x = 1.0
        cxs = []
        for key in (left, right):
            side = 2 if key == 1 else H.LEVELS[key]["side"]
            lay = vanilla(dumps, "gun-turret", "E") if key == 1 else ours(key, "E")
            cx = x + side / 2.0
            ents.append({"pos": (cx * PPT, None), "layers": lay, "side": side})
            cxs.append(cx)
            x += side + 2.6
        W = int((x + 0.2) * PPT)
        top, maxside, bottom = 3.4, max(e["side"] for e in ents), 1.0
        base_y = (top + maxside) * PPT
        for e in ents:
            e["pos"] = (e["pos"][0], base_y - e["side"] / 2.0 * PPT)
        Hh = int(base_y + bottom * PPT)
        day, _ = compose(ents, W, Hh)
        im = to_img(down2(day))
        canvas = Image.new("RGB", (im.width, im.height + 34), (24, 22, 20))
        canvas.paste(im, (0, 0))
        dr = ImageDraw.Draw(canvas)
        f = font(22, True)
        for cx, letter in zip(cxs, ("A", "B")):
            dr.text((cx * 32, im.height + 17), letter, fill=(250, 245, 230), font=f, anchor="mm")
        p = os.path.join(out, fn)
        canvas.save(p, optimize=True)
        written.append(p)
    return written


def main():
    global RENDERS
    ap = argparse.ArgumentParser()
    ap.add_argument("--dumps", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--poses", default="E,N")
    ap.add_argument("--renders", default=ht_post.OUT)
    ap.add_argument("--mesures", default=os.path.join(HERE, "mesures", "mesures_hightech.json"))
    ap.add_argument("--samples", default="")
    ap.add_argument("--naif", default="", help="fichier:gauche:droite,... (1 = mitrailleuse vanilla)")
    a = ap.parse_args()
    RENDERS = a.renders
    os.makedirs(a.out, exist_ok=True)
    if a.naif:
        pairs = []
        for item in a.naif.split(","):
            fn, l, r = item.split(":")
            pairs.append((fn, int(l), int(r)))
        for p in naive_pairs(a.dumps, a.out, pairs):
            print(p)
        return
    mes = {}
    if os.path.exists(a.mesures):
        for r in json.load(open(a.mesures, encoding="utf-8")):
            mes[(r["niveau"], r["pose"])] = r
    written = []
    smp = (" · rendu Cycles %s échantillons" % a.samples) if a.samples else ""
    for pose in a.poses.split(","):
        ents, labels, seps, W, Hh, base_y = row_scene(a.dumps, pose, mes)
        day, night = compose(ents, W, Hh)
        for tag, img in (("jour", day), ("nuit", night)):
            t2 = "Mitrailleuse « haute technologie à la Factorio » (V3-S, reprise) : vanilla, niveaux 11, 21, 29, 30 · " \
                 "références vanilla · pose %s · %s · zoom 2 (64 px/tuile)%s" % (pose, tag, smp)
            im2 = annotate(to_img(img), labels, seps, base_y, 64, t2)
            p2 = os.path.join(a.out, "hightech-%s-%s-zoom2.png" % (pose, tag))
            im2.save(p2, optimize=True)
            t1 = t2.replace("zoom 2 (64 px/tuile)", "zoom 1 (32 px/tuile)")
            im1 = annotate(to_img(down2(img)), labels, seps, base_y, 32, t1)
            p1 = os.path.join(a.out, "hightech-%s-%s-zoom1.png" % (pose, tag))
            im1.save(p1, optimize=True)
            written += [p1, p2]
    for p in written:
        print(p)


if __name__ == "__main__":
    main()
