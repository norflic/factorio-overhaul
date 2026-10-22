"""Planches de l'exploration hybride (reprise de l'après-midi du 22/10) et images du test du regard naïf.

    python planches.py planches <couches (rendre.py --out)> <dumps vanilla> <sortie>
    python planches.py regard <couches> <dumps vanilla> <sortie>

« planches » : la mitrailleuse vanilla (niveau 1) puis les niveaux 11, 21, 29 et 30, intercalés avec des bâtiments
vanilla de référence (tourelle laser, assembleuse 3, réacteur nucléaire, silo à fusée), sur un sol vanilla, à la
MÊME échelle : zoom 2 (64 px/tuile, sprites HR 1:1) et zoom 1 (32 px/tuile, vue du joueur), de jour et de nuit en
pose E, plus une planche en pose N au zoom 1 de jour, et des gros plans (zoom 2 agrandi 2×) de chaque niveau.

« regard » : six images paire-01.png à paire-06.png (paires (1, 11), (11, 21), (21, 29), (29, 30), (1, 21),
(11, 29)), dans un ordre TIRÉ AU HASARD à chaque exécution (graine système, jamais écrite), le plus puissant
tantôt à gauche tantôt à droite ; zoom 1, jour, pose E, sol vanilla ; seules légendes : « A » et « B ». La clé
n'est écrite NULLE PART sur le disque : elle est imprimée sur la sortie standard, une seule fois.

Composition (recopie de tools/render/calib/maquette.py, qui suit les shaders du jeu) : ombres = tampon d'ombre
(maximum des alphas), sol × (1 − 0,5 × alpha) ; entités dans l'ordre de leur position (y puis x), couches dans
l'ordre de dessin (socle puis tête) ; lueur additive ajoutée à la carte des lumières ; nuit = mix(LUT_nuit(jour),
jour, lumière) avec lut-night.png du jeu. Les lumières moteur (LightDefinition) du vanilla ne sont PAS des sprites :
la nuit, les bâtiments vanilla paraissent plus sombres qu'en jeu (limite connue de la maquette). Zoom 1 : moyenne
2×2 en lumière linéaire.
"""
import json
import os
import random
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

DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
PPT = 64


def font(name, size):
    try:
        return ImageFont.truetype("C:/Windows/Fonts/%s" % name, size)
    except OSError:
        return ImageFont.load_default()


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
    elif which == "silo":
        d = dump(dumps, "rocket-silo_rocket-silo")
        nodes = [(d["hole_sprite"], 0, None), (d["door_back_sprite"], 0, None), (d["door_front_sprite"], 0, None),
                 (d["base_day_sprite"], 0, None), (d["base_front_sprite"], 0, None),
                 (d["red_lights_back_sprites"], 0, "glow"), (d["red_lights_front_sprites"], 0, "glow")]
        if "shadow_sprite" in d:
            nodes.insert(0, (d["shadow_sprite"], 0, None))
    else:
        raise KeyError(which)
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
    """Recopie de maquette.compose, positions arrondies au pixel. Renvoie (jour, nuit) en sRGB [0, 1]."""
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


def labelled(rgb, labels, title, k, band, sizes=(26, 20, 17)):
    """Titre en haut, étiquettes sous chaque entité (labels : [(x_tuiles, y_tuiles, lignes)]) ; k = px écran par px
    HR (1 au zoom 2, 0,5 au zoom 1)."""
    im = to_img(rgb)
    ft, f1, f2 = font("arialbd.ttf", sizes[0]), font("arialbd.ttf", sizes[1]), font("arial.ttf", sizes[2])
    head = sizes[0] + 20
    out = Image.new("RGB", (im.width, im.height + band + head), (26, 26, 26))
    out.paste(im, (0, head))
    d = ImageDraw.Draw(out)
    d.text((12, 8), title, fill=(236, 236, 236), font=ft)
    for x, y, lines in labels:
        px = int(x * PPT * k)
        py = int(y * PPT * k) + head
        for j, t in enumerate(lines):
            f = f1 if j == 0 else f2
            w = d.textlength(t, font=f)
            # fond sombre sous le texte (lisible sur le sol)
            d.rectangle((px - w / 2 - 4, py + 2 + j * (sizes[1] + 4), px + w / 2 + 4, py + 4 + j * (sizes[1] + 4) + sizes[1]),
                        fill=(20, 20, 20))
            d.text((px - w / 2, py + 3 + j * (sizes[1] + 4)), t, fill=(250, 250, 250) if j == 0 else (215, 215, 215), font=f)
    return out


# (clé, côté, ligne 1, ligne 2)
ROW = [("gun", 2, "mitrailleuse vanilla", "niveau 1 · époque 1 · 2×2"),
       ("laser", 2, "tourelle laser", "vanilla · 2×2"),
       (11, 3, "hybride niveau 11", "époque 6 · ère II · 3×3"),
       ("am3", 3, "assembleuse 3", "vanilla · 3×3"),
       (21, 5, "hybride niveau 21", "époque 11 · ère IV · 5×5"),
       ("reactor", 5, "réacteur nucléaire", "vanilla · 5×5"),
       (29, 6, "hybride niveau 29", "époque 15 · ère V · 6×6"),
       (30, 6, "hybride niveau 30", "époque 15 · 6×6 · + lance-roquettes"),
       ("silo", 9, "silo à fusée", "vanilla · 9×9")]


def row(root, dumps, pose, y_base, x0=1.0, gap=1.6):
    ents, labels = [], []
    x = x0
    for key, side, l1, l2 in ROW:
        side_slot = max(side, 4.4)          # la légende tient sous son bâtiment (zoom 1)
        x += (side_slot - side) / 2.0
        cx = x + side / 2.0
        cy = y_base - side / 2.0
        lays = level(root, key, pose) if isinstance(key, int) else vanilla(dumps, key, pose)
        ents.append({"pos": (cx, cy), "layers": lays})
        labels.append((cx, y_base + 0.25, [l1, l2]))
        x += side + (side_slot - side) / 2.0 + gap
    return ents, labels, x


def planches(root, dumps, out):
    os.makedirs(out, exist_ok=True)
    files = []
    top = 3.0
    yb = top + 9.0
    for pose in ("E", "N"):
        ents, labels, wx = row(root, dumps, pose, yb)
        day, night = compose(ents, wx + 0.4, yb + 0.6)
        tags = (("jour", day), ("nuit", night)) if pose == "E" else (("jour", day),)
        for tag, img in tags:
            nt = "de nuit (maquette : lumières moteur vanilla absentes)" if tag == "nuit" else "de jour"
            if pose == "E":
                p = os.path.join(out, "planche-hybride-zoom2-%s-poseE.png" % tag)
                labelled(img, labels, "Mitrailleuse « hybride progressive » (V3-S) parmi des bâtiments vanilla, même échelle ; "
                         "zoom 2 (64 px/tuile) ; %s ; pose E" % nt, 1.0, 120, (30, 24, 20)).save(p, optimize=True)
                files.append(p)
            p = os.path.join(out, "planche-hybride-zoom1-%s-pose%s.png" % (tag, pose))
            labelled(down2(img), labels, "Hybride V3-S, zoom 1 (32 px/tuile, vue du joueur) ; %s ; pose %s" % (nt, pose), 0.5,
                     80, (20, 16, 14)).save(p, optimize=True)
            files.append(p)
    # gros plans : chaque niveau en pose E au zoom 2, agrandi 2× (lecture du détail)
    for lv, side in ((11, 3), (21, 5), (29, 6), (30, 6)):
        ents = [{"pos": (side / 2.0 + 1.0, 2.6 + side / 2.0), "layers": level(root, lv, "E")}]
        d1, n1 = compose(ents, side + 3.6, side + 3.6)
        for tag, img in (("jour", d1), ("nuit", n1)):
            im = to_img(img)
            im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
            p = os.path.join(out, "gros-plan-n%02d-E-zoom2x2-%s.png" % (lv, tag))
            im.save(p, optimize=True)
            files.append(p)
    for f in files:
        print(f)


PAIRS = [(1, 11), (11, 21), (21, 29), (29, 30), (1, 21), (11, 29)]
SIDE = {1: 2, 11: 3, 21: 5, 29: 6, 30: 6}


def regard(root, dumps, out):
    """Paires du test du regard naïf ; la clé n'est imprimée QUE sur la sortie standard."""
    os.makedirs(out, exist_ok=True)
    rnd = random.SystemRandom()
    order = list(PAIRS)
    rnd.shuffle(order)
    # le plus puissant à gauche dans 3 paires sur 6, à droite dans les 3 autres (tirage)
    left_strong = [True] * 3 + [False] * 3
    rnd.shuffle(left_strong)
    key = []
    for i, (lo, hi) in enumerate(order):
        ab = (hi, lo) if left_strong[i] else (lo, hi)
        ents, labels = [], []
        x = 1.2
        H = 9.6
        yb = H - 0.9
        for j, lv in enumerate(ab):
            side = SIDE[lv]
            cx = x + side / 2.0
            lays = vanilla(dumps, "gun", "E") if lv == 1 else level(root, lv, "E")
            ents.append({"pos": (cx, yb - side / 2.0), "layers": lays})
            labels.append((cx, yb + 0.15, ["AB"[j]]))
            x += side + 2.0
        day, _ = compose(ents, x - 0.8, H)
        p = os.path.join(out, "paire-%02d.png" % (i + 1))
        labelled(down2(day), labels, "", 0.5, 46, (8, 30, 16)).save(p, optimize=True)
        key.append("paire-%02d.png : A = %d, B = %d" % (i + 1, ab[0], ab[1]))
    sys.stdout.write("CLE (non écrite sur le disque)\n" + "\n".join(key) + "\n")


if __name__ == "__main__":
    mode, root, dumps, out = sys.argv[1:5]
    (planches if mode == "planches" else regard)(root, dumps, out)
