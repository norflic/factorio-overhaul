"""Maquette hors moteur : la pièce rendue à côté de bâtiments vanilla, sur un sol vanilla, de jour et de
nuit, au zoom 2 (64 px/tuile, sprites HR 1:1) et au zoom 1 (32 px/tuile).

    python tools/render/calib/maquette.py "<racine>/data" [--piece cheminee] [--tag nom]

Compose EXACTEMENT les fichiers livrés (graphics/…) avec les tailles et décalages du manifeste
(tools/render/manifests/<piece>.json), comme le moteur :
- ombres : tampon d'ombre (maximum des alphas), sol × (1 − 0,5 × alpha) (core/…/shadow-a8.frag) ;
- entités dans l'ordre de leur position (y puis x), couches dans l'ordre déclaré ;
- lueur (draw_as_glow, additive) ajoutée au rendu de jour et à la carte des lumières ;
- nuit : couleur = mix(LUT_nuit(jour), jour, lumière) (core/…/game.frag), LUT lut-night.png,
  lumière = halos (draw_as_light) + lueurs, bornée à [0, 1]. lightMul/lightAdd du moteur : inconnus,
  pris à 1 et 0 (écart possible, NON PROUVÉ hors moteur).
Écrit aussi les statistiques photométriques de la couche principale contre les références vanilla.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.dirname(HERE)
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)
from fitlib import load, stats_opaque, luminance  # noqa: E402
import fo_post as P  # noqa: E402


def vanilla_layer(data, rel, w, h, shift, frame=(0, 0), kind="main"):
    im = load(os.path.join(data, "base", "graphics", "entity", rel))
    fx, fy = frame
    im = im[fy * h:(fy + 1) * h, fx * w:(fx + 1) * w]
    return {"img": im, "shift": shift, "kind": kind}


def own_layer(path, shift, kind):
    return {"img": load(path), "shift": shift, "kind": kind}


def lut_apply(img_rgb, lut_path):
    """LUT 3D 16³ de Factorio (256 × 16 : 16 tranches de bleu côte à côte, x = rouge, y = vert),
    entrée = couleur × 0,9375 + 0,03125 (game.frag), interpolation trilinéaire."""
    lut = np.asarray(Image.open(lut_path).convert("RGB")).astype(np.float64) / 255.0
    L = np.zeros((16, 16, 16, 3))
    for b in range(16):
        L[:, :, b] = lut[:, b * 16:(b + 1) * 16].transpose(1, 0, 2)  # L[r, g, b]
    c = np.clip(img_rgb, 0, 1) * 15.0
    i0 = np.floor(c).astype(int)
    i0 = np.clip(i0, 0, 14)
    f = c - i0
    out = np.zeros_like(img_rgb)
    for dr in (0, 1):
        for dg in (0, 1):
            for db in (0, 1):
                w = (f[..., 0] if dr else 1 - f[..., 0]) * (f[..., 1] if dg else 1 - f[..., 1]) * (f[..., 2] if db else 1 - f[..., 2])
                out += w[..., None] * L[i0[..., 0] + dr, i0[..., 1] + dg, i0[..., 2] + db]
    return out


def check_lut_layout(core):
    ident = os.path.join(core, "graphics", "color_luts", "identity-lut.png")
    test = np.random.RandomState(1).rand(32, 32, 3)
    err = np.abs(lut_apply(test, ident) - test).max()
    return float(err)


def compose(data, core, entities, W_t, H_t, ppt=64):
    """entities : liste de {pos: (x, y) tuiles, layers: [...]}. Renvoie (jour RGB, lumière RGB)."""
    W, H = int(W_t * ppt), int(H_t * ppt)
    # rangées 320 à 575 : variantes 4×4 tuiles entièrement opaques (les autres rangées ont des trous)
    ground = load(os.path.join(data, "base", "graphics", "terrain", "hr-dirt-4.png"))[320:576, :, :3]
    gh, gw = ground.shape[:2]
    reps = (H // gh + 1, W // gw + 1, 1)
    day = np.tile(ground, reps)[:H, :W].copy()
    shadow = np.zeros((H, W))
    light = np.zeros((H, W, 3))

    def blit(dst_shape, lay, pos):
        img = lay["img"]
        h, w = img.shape[:2]
        x0 = pos[0] * ppt + lay["shift"][0] * ppt - w / 2.0
        y0 = pos[1] * ppt + lay["shift"][1] * ppt - h / 2.0
        xi, yi = int(round(x0)), int(round(y0))
        assert abs(xi - x0) < 1e-6 and abs(yi - y0) < 1e-6, (lay, x0, y0)
        return img, xi, yi

    def region(xi, yi, h, w):
        xs0, ys0 = max(0, -xi), max(0, -yi)
        xd0, yd0 = max(0, xi), max(0, yi)
        ww, hh = min(w - xs0, W - xd0), min(h - ys0, H - yd0)
        return (slice(ys0, ys0 + hh), slice(xs0, xs0 + ww)), (slice(yd0, yd0 + hh), slice(xd0, xd0 + ww))

    for e in entities:
        for lay in e["layers"]:
            if lay["kind"] == "shadow":
                img, xi, yi = blit(None, lay, e["pos"])
                s, d = region(xi, yi, *img.shape[:2])
                shadow[d] = np.maximum(shadow[d], img[s][..., 3])
    day = day * (1 - 0.5 * shadow)[..., None]
    for e in sorted(entities, key=lambda e: (e["pos"][1], e["pos"][0])):
        for lay in e["layers"]:
            if lay["kind"] == "shadow":
                continue
            img, xi, yi = blit(None, lay, e["pos"])
            s, d = region(xi, yi, *img.shape[:2])
            src = img[s]
            a = src[..., 3:4]
            if lay["kind"] == "main":
                day[d] = src[..., :3] * a + day[d] * (1 - a)
            elif lay["kind"] == "glow":
                day[d] = np.clip(day[d] + src[..., :3] * a, 0, 1)
                light[d] += src[..., :3] * a
            elif lay["kind"] == "light":
                light[d] += src[..., :3] * a
    light = np.clip(light, 0, 1)
    night_lut = lut_apply(day, os.path.join(core, "graphics", "color_luts", "lut-night.png"))
    night = night_lut * (1 - light) + day * light
    return day, night


def down2(rgb):
    h, w = rgb.shape[:2]
    lin = P.srgb_to_lin(rgb[:h // 2 * 2, :w // 2 * 2])
    lin = lin.reshape(h // 2, 2, w // 2, 2, 3).mean((1, 3))
    return P.lin_to_srgb(lin)


def save(rgb, path, scale=1):
    im = Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("data")
    ap.add_argument("--piece", default="cheminee")
    ap.add_argument("--tag", default="current")
    a = ap.parse_args()
    data = a.data
    core = os.path.join(data, "core")
    out = os.path.join(RENDER, "out", "maquette", a.tag)
    with open(os.path.join(RENDER, "manifests", "%s.json" % a.piece), encoding="utf-8") as f:
        man = json.load(f)
    gdir = os.path.join(MOD_ROOT, "graphics")

    def own(variant, res="hr"):
        r = [v for v in man["variants"] if v["name"] == variant][0]
        lays = []
        for layer in ("shadow", "main", "glow", "light"):
            if layer in r["spec"]:
                sd = r["spec"][layer][res]
                lays.append(own_layer(os.path.join(gdir, *r["dest"].split("/"), sd["filename"]), sd["shift"], layer))
        return lays

    am2 = [vanilla_layer(data, "assembling-machine-2/hr-assembling-machine-2-shadow.png", 196, 163, (0.375, 0.1484375), kind="shadow"),
           vanilla_layer(data, "assembling-machine-2/hr-assembling-machine-2.png", 214, 218, (0, 0.125))]
    furnace = [vanilla_layer(data, "steel-furnace/hr-steel-furnace-shadow.png", 277, 85, (1.2265625, 0.3515625), kind="shadow"),
               vanilla_layer(data, "steel-furnace/hr-steel-furnace.png", 171, 174, (-0.0390625, 0.0625))]
    turret = [vanilla_layer(data, "gun-turret/hr-gun-turret-raising-shadow.png", 250, 124, (0.59375, 0.078125), kind="shadow"),
              vanilla_layer(data, "gun-turret/hr-gun-turret-base.png", 150, 118, (0.015625, -0.03125)),
              vanilla_layer(data, "gun-turret/hr-gun-turret-raising.png", 130, 126, (0, -0.828125))]
    variants = [v["name"] for v in man["variants"]]
    ents = [
        {"pos": (2.5, 3.5), "layers": am2},
        {"pos": (6.0, 3.0), "layers": furnace},
    ]
    x = 8.5
    if "%s-seule" % a.piece in variants:
        ents.append({"pos": (x, 3.5), "layers": own("%s-seule" % a.piece)})
    if "%s-four" % a.piece in variants:
        ents.append({"pos": (11.0, 3.0), "layers": furnace + own("%s-four" % a.piece)})
    ents.append({"pos": (14.0, 3.0), "layers": turret})
    Wt, Ht = 17, 5.5
    day, night = compose(data, core, ents, Wt, Ht)
    files = {}
    files["zoom2_jour"] = save(day, os.path.join(out, "maquette-zoom2-jour.png"))
    files["zoom2_nuit"] = save(night, os.path.join(out, "maquette-zoom2-nuit.png"))
    files["zoom1_jour"] = save(down2(day), os.path.join(out, "maquette-zoom1-jour.png"))
    files["zoom1_nuit"] = save(down2(night), os.path.join(out, "maquette-zoom1-nuit.png"))
    # gros plans ×3 (zoom 2) : cheminée seule et four équipé
    for name, (cx, cy) in (("gros-plan-cheminee", (8.5, 2.6)), ("gros-plan-four", (11.0, 2.2))):
        x0, x1 = int((cx - 1.6) * 64), int((cx + 1.9) * 64)
        y0, y1 = max(0, int((cy - 2.2) * 64)), int((cy + 1.6) * 64)
        files[name + "_jour"] = save(day[y0:y1, x0:x1], os.path.join(out, name + "-jour-x3.png"), 3)
        files[name + "_nuit"] = save(night[y0:y1, x0:x1], os.path.join(out, name + "-nuit-x3.png"), 3)
    rep ={"files": files, "lut_identity_error": check_lut_layout(core)}
    # photométrie de la couche principale (HR) contre les références vanilla
    r = [v for v in man["variants"] if v["name"] == "%s-seule" % a.piece]
    if r:
        sd = r[0]["spec"]["main"]["hr"]
        mine = load(os.path.join(gdir, *r[0]["dest"].split("/"), sd["filename"]))
        rep["photometrie"] = {"piece": stats_opaque(mine)}
        refs = {"four-acier": ("steel-furnace/hr-steel-furnace.png", None),
                "assembleur-2": ("assembling-machine-2/hr-assembling-machine-2.png", (0, 0, 214, 218)),
                "mitrailleuse-socle": ("gun-turret/hr-gun-turret-base.png", None),
                "reservoir": ("storage-tank/hr-storage-tank.png", (0, 0, 219, 215)),
                "chaudiere": ("boiler/hr-boiler-N-idle.png", (0, 0, 269, 221)),
                "radar": ("radar/hr-radar.png", (0, 0, 196, 254)),
                "coffre-acier": ("steel-chest/hr-steel-chest.png", None),
                "poteau-moyen": ("medium-electric-pole/hr-medium-electric-pole.png", (0, 0, 84, 252))}
        for k, (rel, box) in refs.items():
            im = load(os.path.join(data, "base", "graphics", "entity", rel))
            if box:
                im = im[box[1]:box[3], box[0]:box[2]]
            rep["photometrie"][k] = stats_opaque(im)
        # couleur de la lueur (moyenne prémultipliée des pixels > 0,1)
        g = r[0]["spec"].get("glow")
        if g:
            gi = load(os.path.join(gdir, *r[0]["dest"].split("/"), g["hr"]["filename"]))
            pm = gi[..., :3] * gi[..., 3:4]
            m = pm.max(-1) > 0.1
            rep["lueur_rgb_moyenne"] = [float(v) for v in pm[m].mean(0)]
            rep["lueur_rgb_max"] = [float(v) for v in pm.reshape(-1, 3).max(0)]
    with open(os.path.join(out, "maquette.json"), "w", encoding="utf-8") as f:
        json.dump(rep, f, indent=1)
    print(json.dumps({k: v for k, v in rep.items() if k != "photometrie"}, indent=1))
    if "photometrie" in rep:
        print("%-20s %6s %6s %6s %6s %6s %6s %6s" % ("photométrie", "Lmoy", "Lstd", "p05", "p50", "p95", "sat", "grain"))
        for k, s in rep["photometrie"].items():
            print("%-20s %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f" % (k, s["L_mean"], s["L_std"], s["L_p05"], s["L_p50"],
                                                                     s["L_p95"], s["sat_mean"], s["grain"]))


if __name__ == "__main__":
    main()
