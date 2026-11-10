"""PLANCHE AVANT / APRÈS du pulvérisateur d'acide (lot MURS-ACIDE, 10/11) : l'image d'aujourd'hui (lance-flammes vanilla, socle nord
teinté acier et tête direction 0 ; la petite usine chimique collée à l'arrière par prototypes/arsenal_special.lua n'est pas recomposée)
à côté des feuilles rendues pour les QUATRE directions du socle (tête tournée vers l'avant de chaque direction : 0, 16, 32, 48 sur 64),
même sol, même échelle (zoom 2 = 64 px par tuile), jour et nuit ; puis une bande de 8 des 64 directions de la tête sur le socle sud.
Python 3.9, Pillow + numpy, hors Blender. Réutilise planche.py (lire, compose, font).

    py -3.9 tools/render/pieces/batiments/planche_acide.py --dest <planche.png> [--src graphics/batiments]
"""
import argparse
import importlib.util
import json
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
_s = importlib.util.spec_from_file_location("bat_planche", os.path.join(HERE, "planche.py"))
PL = importlib.util.module_from_spec(_s)
_s.loader.exec_module(PL)
FT = os.path.join(PL.ENT, "flamethrower-turret")
TINT = (0.72, 0.74, 0.76)       # teinte du socle d'aujourd'hui (prototypes/arsenal_special.lua)
DIRS = (("north", "n", 0, "nord"), ("east", "e", 16, "est"), ("south", "s", 32, "sud"), ("west", "w", 48, "ouest"))


def aujourdhui():
    base = PL.lire(os.path.join(FT, "hr-flamethrower-turret-base-north.png"))
    base[..., :3] *= np.array(TINT)
    ombre = PL.lire(os.path.join(FT, "hr-flamethrower-turret-base-north-shadow.png"))
    gun = PL.lire(os.path.join(FT, "hr-flamethrower-turret-gun.png"), (0, 0, 158, 128))
    # shifts du prototype vanilla (util.by_pixel, tuiles × 64 px HR) : socle (-1, 13), ombre (3, 15), tête (-1, -25) + décalage nord (0, -6)
    return [(ombre, (6, 30), "shadow"), (base, (-2, 26), "main"), (gun, (-2, -62), "main")]


def refait(src, tab, d, kd, direction, kinds=("shadow", "main", "glow")):
    out = []
    s = tab["socles"][kd]
    pv = tab["pivots"][d]
    for k in kinds:
        if k in s:
            h = s[k]["hr"]
            out.append((PL.lire(os.path.join(src, os.path.basename(h["filename"]))), (h["shift"][0] * 64, h["shift"][1] * 64), k))
        t = tab["tete"].get(k)
        if t:
            hh = t["hr"]
            b, r = divmod(direction, tab["rangs"])
            w, ht = hh["width"], hh["height"]
            a = PL.lire(os.path.join(src, os.path.basename(hh["stripes"][b])), (0, r * ht, w, (r + 1) * ht))
            out.append((a, ((hh["shift"][0] + pv[0]) * 64, (hh["shift"][1] + pv[1]) * 64), k))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(PL.MOD, "graphics", "batiments"))
    ap.add_argument("--dest", required=True)
    a = ap.parse_args()
    tab = json.load(open(os.path.join(a.src, "sprites.json"), encoding="utf-8"))["acide"]
    W, Hh = 300, 330
    titre = PL.font(20)
    pt = PL.font(13, bold=False)
    cases = [("aujourd'hui : lance-flammes teinté", aujourdhui())]
    for d, kd, di, nom in DIRS:
        cases.append(("refait : socle %s" % nom, refait(a.src, tab, d, kd, di)))
    bande = [refait(a.src, tab, "south", "s", k) for k in range(0, 64, 8)]
    L = 12
    H = 40 + 2 * (Hh + 26) + 30 + Hh // 2 + 30
    img = Image.new("RGB", (L + len(cases) * (W + L), H), (22, 22, 28))
    dr = ImageDraw.Draw(img)
    m = tab.get("marque", {})
    dr.text((L, 10), "MURS-ACIDE · pulvérisateur d'acide refait (socle à direction, tête 64 directions) · zoom 2 · même sol, même échelle"
            " · liseré « %s », toit « %s »" % (m.get("fonction", "?"), m.get("toit", "?")), fill=(255, 214, 120), font=titre)
    y = 40
    for nuit in (False, True):
        for i, (lab, lays) in enumerate(cases):
            x = L + i * (W + L)
            img.paste(PL.compose(lays, W, Hh, nuit), (x, y))
            dr.text((x, y + Hh + 4), ("nuit · " if nuit else "jour · ") + lab, fill=(220, 220, 220), font=pt)
        y += Hh + 26
    dr.text((L, y), "tête tournante sur le socle sud : 8 des 64 directions (zoom 1)", fill=(150, 200, 255), font=PL.font(15))
    y += 24
    for i, lays in enumerate(bande):
        im = PL.compose(lays, W, Hh, False, ppt=32)
        img.paste(im, (L + i * (W // 2 + 8), y))
        dr.text((L + i * (W // 2 + 8), y + Hh // 2 + 2), "direction %d/64" % (i * 8), fill=(220, 220, 220), font=pt)
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    img.save(a.dest, optimize=True)
    tel = a.dest[:-4] + "-telephone.png"
    k = min(1.0, 1600.0 / img.width)
    img.resize((int(img.width * k), int(img.height * k)), Image.LANCZOS).save(tel, optimize=True)
    print("[FO-PLANCHE-ACIDE] %s (%dx%d), %s" % (a.dest, img.width, img.height, tel))


if __name__ == "__main__":
    main()
