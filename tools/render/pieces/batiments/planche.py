"""PLANCHE AVANT / APRÈS des bâtiments refaits (lot POLISSAGE-FX, 10/11) : par bâtiment, l'image d'AUJOURD'HUI (sprite vanilla teinté
et mis à l'échelle comme le prototype provisoire le fait) à côté des feuilles rendues (principale + ombre, puis la lueur de nuit), même
sol, même échelle (zoom 2 = 64 px par tuile), jour et nuit. Python 3.9, Pillow + numpy, hors Blender.

    py -3.9 tools/render/pieces/batiments/planche.py [--src graphics/batiments] --dest <planche.png> [--zoom 2]
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
ENT = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data\base\graphics\entity"
SABLE = (120, 86, 52)
NUIT = (16, 15, 19)
# aujourd'hui : couches (fichier HR, rectangle, shift en px HR, genre), échelle, teinte, titre
VANILLA = {
    "coffre": ([("steel-chest/hr-steel-chest-shadow.png", (0, 0, 110, 46), (24.5, 16), "shadow"),
                ("steel-chest/hr-steel-chest.png", (0, 0, 64, 80), (-0.5, -1), "main")],
               1.0, (1.0, 0.85, 0.35), "coffre d'acier teinté jaune"),
    "pylone": ([("big-electric-pole/hr-big-electric-pole-shadow.png", (0, 0, 374, 94), (120, 0), "shadow"),
                ("big-electric-pole/hr-big-electric-pole.png", (0, 0, 148, 312), (0, -102), "main")],
               1.0, (0.78, 0.84, 0.92), "grand poteau teinté"),
    "cuve": ([("electric-furnace/hr-electric-furnace-shadow.png", (0, 0, 227, 171), (22.5, 15.5), "shadow"),
              ("electric-furnace/hr-electric-furnace.png", (0, 0, 239, 219), (1.5, 11.5), "main")],
             4.0 / 3.0, (0.80, 0.86, 0.95), "four électrique teinté × 4/3"),
}
NOMS = {"coffre": ("Coffre d'équipe", "fo-team-chest", 1), "pylone": ("Pylône haute tension", "fo-ht-pylon", 2),
        "cuve": ("Cuve d'électrolyse ignée", "fo-reduction-cell", 4),
        # lot POLISSAGE-2 (10/11) : tourelles électriques ; « aujourd'hui » = couches EXACTES livrées en 0.6.79 (avant_tourelles.json)
        "bastion2": ("Bastion II (laser, âge 2) : le prisme", "fo-bastion-2", 2),
        "bastion3": ("Bastion III (arc, âge 3) : la couronne d'électrodes", "fo-bastion-3", 2),
        "bastion4": ("Bastion IV (plasma, âge 4) : le confinement", "fo-bastion-4", 2),
        "tesla": ("Tour à arc : la bobine Tesla", "fo-tesla-turret", 2),
        "laser_lourd": ("Tourelle laser lourde : le dôme focal", "fo-heavy-laser-turret", 3)}
AVANT = os.path.join(HERE, "avant_tourelles.json")


def avant_tourelle(cle):
    """Image d'aujourd'hui d'une tourelle : socle + tête repliée (direction 0, image 0) aux échelles, décalages et teintes livrés."""
    import json
    lays = json.load(open(AVANT, encoding="utf-8"))["tourelles"][cle]
    out = []
    for l in lays:
        x, y, w, h = l["rect"]
        a = lire(os.path.join(ENT, l["fichier"].replace("/", os.sep)), (x, y, x + w, y + h))
        k = l["scale"] * 2.0                      # hr à l'échelle 0,5 = 64 px par tuile
        if abs(k - 1.0) > 1e-6:
            im = Image.fromarray((a * 255).round().astype(np.uint8), "RGBA")
            im = im.resize((max(1, int(round(im.width * k))), max(1, int(round(im.height * k)))), Image.LANCZOS)
            a = np.asarray(im).astype(np.float64) / 255.0
        if l["genre"] != "shadow":
            a[..., :3] *= np.array(l["tint"])
        out.append((a, (l["shift"][0] * 64, l["shift"][1] * 64), l["genre"]))
    return out


def font(size, bold=True):
    for f in (("arialbd.ttf" if bold else "arial.ttf"), "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def lire(path, rect=None):
    im = Image.open(path).convert("RGBA")
    if rect:
        im = im.crop(rect)
    return np.asarray(im).astype(np.float64) / 255.0


def vanilla(cle):
    lays, k, tint, _ = VANILLA[cle]
    out = []
    for f, rect, sh, kind in lays:
        a = lire(os.path.join(ENT, f), rect)
        if k != 1.0:
            im = Image.fromarray((a * 255).round().astype(np.uint8), "RGBA")
            im = im.resize((max(1, int(round(im.width * k))), max(1, int(round(im.height * k)))), Image.LANCZOS)
            a = np.asarray(im).astype(np.float64) / 255.0
        if kind != "shadow":
            a[..., :3] *= np.array(tint)
        out.append((a, (sh[0] * k, sh[1] * k), kind))
    return out


def feuilles(src, cle, kinds):
    import importlib.util
    spec = importlib.util.spec_from_file_location("spr_json", os.path.join(HERE, "feuilles.py"))
    import json
    tab = json.load(open(os.path.join(src, "sprites.json"), encoding="utf-8"))[cle]
    out = []
    for k in kinds:
        if k not in tab:
            continue
        h = tab[k]["hr"]
        p = os.path.join(MOD, h["filename"].replace("__factorio-overhaul__/", "").replace("/", os.sep))
        out.append((lire(p), (h["shift"][0] * 64, h["shift"][1] * 64), k))
    return out


def compose(lays, W, Hh, nuit, ppt=64):
    """Compose des couches (px HR relatifs au pied de l'entité) sur un sol W × Hh px, pied au point (W/2, Hh × 0,72)."""
    fond = np.ones((Hh, W, 3)) * (np.array(NUIT if nuit else SABLE) / 255.0)
    ox, oy = W / 2.0, Hh * 0.72
    for a, (sx, sy), kind in lays:
        h, w = a.shape[:2]
        x0, y0 = int(round(ox + sx - w / 2.0)), int(round(oy + sy - h / 2.0))
        x1, y1 = x0 + w, y0 + h
        cx0, cy0, cx1, cy1 = max(0, x0), max(0, y0), min(W, x1), min(Hh, y1)
        if cx1 <= cx0 or cy1 <= cy0:
            continue
        s = a[cy0 - y0:cy1 - y0, cx0 - x0:cx1 - x0]
        dst = fond[cy0:cy1, cx0:cx1]
        al = s[..., 3:4]
        if kind == "shadow":
            fond[cy0:cy1, cx0:cx1] = dst * (1 - al * 0.5)
        elif kind == "glow":
            if nuit:
                fond[cy0:cy1, cx0:cx1] = np.clip(dst + s[..., :3] * al, 0, 1)
            else:
                fond[cy0:cy1, cx0:cx1] = np.clip(dst + s[..., :3] * al * 0.35, 0, 1)
        else:
            rgb = s[..., :3] * (0.42 if nuit else 1.0)
            fond[cy0:cy1, cx0:cx1] = dst * (1 - al) + rgb * al
    im = Image.fromarray((fond * 255).round().astype(np.uint8), "RGB")
    if ppt == 32:
        im = im.resize((W // 2, Hh // 2), Image.LANCZOS)
    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(MOD, "graphics", "batiments"))
    ap.add_argument("--dest", required=True)
    ap.add_argument("--zoom", type=int, default=2, choices=(1, 2))
    ap.add_argument("--batiments", default="coffre,pylone,cuve")
    ap.add_argument("--titre", default="POLISSAGE-FX · bâtiments génériques refaits")
    a = ap.parse_args()
    ppt = 64 if a.zoom == 2 else 32
    gap, th, lab, fs = 8, 28, 20, 14
    rows = []
    for cle in [b for b in a.batiments.split(",") if b]:
        nom, proto, side = NOMS[cle]
        W = int((side + 3.5) * 64)
        Hh = int((side + 2.0) * 64 * 0.72) + (420 if cle == "pylone" else 80)
        cells = []
        for nuit in (False, True):
            pre = "nuit · " if nuit else "jour · "
            if cle in VANILLA:
                cells.append((compose(vanilla(cle), W, Hh, nuit, ppt), pre + "aujourd'hui : " + VANILLA[cle][3]))
            else:
                cells.append((compose(avant_tourelle(cle), W, Hh, nuit, ppt), pre + "aujourd'hui (0.6.79)"))
            cells.append((compose(feuilles(a.src, cle, ("shadow", "main", "glow")), W, Hh, nuit, ppt), pre + "refait (titans : argent, cyan, magenta)"))
        rows.append(("%s · %s · %d×%d" % (nom, proto, side, side), cells))
    Wt = max(sum(c[0].width for c in r[1]) + gap * 5 for r in rows)
    Ht = 44 + sum(th + max(c[0].height for c in r[1]) + lab + gap for r in rows)
    sheet = Image.new("RGB", (Wt, Ht), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), "%s · zoom %d · même sol, même échelle · 1re case : l'image d'aujourd'hui" % (a.titre, a.zoom),
            fill=(255, 205, 120), font=font(20))
    y = 44
    for t, cells in rows:
        dr.text((gap + 2, y + 2), t, fill=(150, 210, 255), font=font(fs + 2))
        y += th
        x = gap
        hh = max(c[0].height for c in cells)
        for im, lb in cells:
            sheet.paste(im, (x, y + hh - im.height))
            dr.text((x + 4, y + hh + 3), lb, fill=(235, 235, 235), font=font(fs, False))
            x += im.width + gap
        y += hh + lab + gap
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest, optimize=True)
    tel = a.dest[:-4] + "-telephone.png"
    r = min(1.0, 1600.0 / sheet.width)
    sheet.resize((int(sheet.width * r), int(sheet.height * r)), Image.LANCZOS).save(tel, optimize=True)
    print(a.dest, sheet.size, tel)


if __name__ == "__main__":
    main()
