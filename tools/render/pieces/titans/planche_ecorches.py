"""PLANCHE AVANT / APRÈS des ÉCORCHÉS (lot VISUELS-DISTINCTS, 10/11) : les trois variantes (rôdeur, porteur, hurleur) telles que la
0.6.80 livrée les dessine (feuilles et teintes du dossier du mod déployé) et telles que ce lot les dessine (chair, peau, silhouette et
collerette par variante ; lueur = couleur de la variante mêlée à celle de l'ère), même sol, même échelle (zoom 2 = 64 px par tuile, ère 3,
échelle de l'image du jeu), jour et nuit ; puis « DE LOIN » (zoom 0,5) les trois côte à côte, avant puis après, avec la luminance
moyenne mesurée (sprites.lua ecorche.mesure). Python 3.9 + Pillow + numpy ; les tables sont lues par lua5.2 (sprites.lua, titans.lua).

    PYTHONUTF8=1 py -3.9 tools/render/pieces/titans/planche_ecorches.py --dest <planche.png> [--avant <racine du mod livré>]
"""
import argparse
import os
import subprocess

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
AVANT_DEFAUT = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul"
SABLE = (120, 86, 52)
NUIT = (16, 15, 19)
ERE = 3
DIRECTION = 3      # sud-est (celle de l'icône)
# s43 3d-ecorches : noms des colonnes (avant = le mod livré, après = ce worktree)
AVANT_NOM = os.environ.get("FO_PLANCHE_AVANT", "0.7.96 livrée")
APRES_NOM = os.environ.get("FO_PLANCHE_APRES", "refonte organique")
NOMS = ("rodeur", "porteur", "hurleur")
LUA_EXE = os.environ.get("FO_LUA", os.path.join(os.path.expanduser("~"), "bin", "lua5.2.exe"))
LUA = r"""
package.path = "./?.lua;" .. package.path
local T = require("shared.robots.titans")
local S = dofile("graphics/robots/titans/sprites.lua").ecorche
local ere, dir = tonumber(arg[1]), tonumber(arg[2]) + 1
for i, v in ipairs(T.ECORCHE.variants) do
  local m = T.ecorche(v, ere)
  local c = S[tostring(i)].course.couches
  for _, k in ipairs({ "main", "glow", "shadow" }) do
    local l = c[k]
    io.write(table.concat({ v.id, k, l.hr[dir], l.w, l.h, l.dens, l.sx, l.sy, m.scale, m.tint.r, m.tint.g, m.tint.b, m.glow,
      (S.mesure and S.mesure[tostring(i)] and S.mesure[tostring(i)].luminance) or -1 }, "\t"), "\n")
  end
end
"""


def font(size, bold=True):
    for f in (("arialbd.ttf" if bold else "arial.ttf"), "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def tables(racine):
    """Par variante : couches (fichier hr de la direction, taille d'image, densité, décalage), échelle, teinte, lueur, luminance."""
    r = subprocess.run([LUA_EXE, "-", str(ERE), str(DIRECTION)], input=LUA.encode("utf-8"), cwd=racine, capture_output=True, check=True)
    out = {}
    for ligne in r.stdout.decode("utf-8").splitlines():
        v, k, f, w, h, dens, sx, sy, sc, tr, tg, tb, g, lum = ligne.split("\t")
        e = out.setdefault(v, {"scale": float(sc), "tint": (float(tr), float(tg), float(tb)), "glow": float(g), "lum": float(lum), "c": {}})
        e["c"][k] = {"f": os.path.join(racine, f.replace("__factorio-overhaul__/", "").replace("/", os.sep)), "w": int(w), "h": int(h),
                     "dens": float(dens), "sx": float(sx), "sy": float(sy)}
    return out


def compose(e, W, Hh, nuit, ppt=64.0):
    fond = np.ones((Hh, W, 3)) * (np.array(NUIT if nuit else SABLE) / 255.0)
    ox, oy = W / 2.0, Hh * 0.62
    for k in ("shadow", "main", "glow"):
        c = e["c"][k]
        im = Image.open(c["f"]).convert("RGBA").crop((0, 0, c["w"], c["h"]))
        s = ppt / c["dens"] * e["scale"]
        im = im.resize((max(1, int(round(im.width * s))), max(1, int(round(im.height * s)))), Image.LANCZOS)
        a = np.asarray(im).astype(np.float64) / 255.0
        h, w = a.shape[:2]
        x0 = int(round(ox + c["sx"] * ppt * e["scale"] - w / 2.0))
        y0 = int(round(oy + c["sy"] * ppt * e["scale"] - h / 2.0))
        cx0, cy0, cx1, cy1 = max(0, x0), max(0, y0), min(W, x0 + w), min(Hh, y0 + h)
        if cx1 <= cx0 or cy1 <= cy0:
            continue
        sl = a[cy0 - y0:cy1 - y0, cx0 - x0:cx1 - x0]
        al = sl[..., 3:4]
        dst = fond[cy0:cy1, cx0:cx1]
        if k == "shadow":
            fond[cy0:cy1, cx0:cx1] = dst * (1 - al * 0.5)
        elif k == "glow":
            t = np.array(e["tint"]) * e["glow"]
            fond[cy0:cy1, cx0:cx1] = np.clip(dst + sl[..., :3] * t * al * (1.0 if nuit else 0.6), 0, 1)
        else:
            fond[cy0:cy1, cx0:cx1] = dst * (1 - al) + sl[..., :3] * (0.42 if nuit else 1.0) * al
    return Image.fromarray((fond * 255).round().astype(np.uint8), "RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--avant", default=AVANT_DEFAUT)
    a = ap.parse_args()
    av, apr = tables(a.avant), tables(MOD)
    f1, f2 = font(22), font(15, False)
    W, Hh = 330, 300
    H = 46 + 3 * (30 + Hh + 26) + 2 * (30 + 170 + 26)
    out = Image.new("RGB", (4 * (W + 10) + 10, H), (22, 22, 27))
    d = ImageDraw.Draw(out)
    d.text((14, 10), "Écorchés · avant : %s · après : %s · ère %d · zoom 2" % (AVANT_NOM, APRES_NOM, ERE),
           fill=(255, 210, 120), font=f1)
    y = 46
    for v in NOMS:
        d.text((14, y), "Écorché %s" % v, fill=(150, 205, 255), font=f1)
        y += 30
        cells = [(compose(av[v], W, Hh, False), "jour · " + AVANT_NOM), (compose(apr[v], W, Hh, False), "jour · " + APRES_NOM),
                 (compose(av[v], W, Hh, True), "nuit · " + AVANT_NOM), (compose(apr[v], W, Hh, True), "nuit · " + APRES_NOM)]
        for i, (im, lib) in enumerate(cells):
            out.paste(im, (10 + i * (W + 10), y))
            d.text((14 + i * (W + 10), y + Hh + 4), lib, fill=(230, 230, 230), font=f2)
        y += Hh + 26
    for tab, lib in ((av, AVANT_NOM), (apr, APRES_NOM)):
        d.text((14, y), "de loin (zoom 0,5) · " + lib, fill=(150, 205, 255), font=f1)
        row = Image.new("RGB", (3 * 220, 170), SABLE)
        for i, v in enumerate(NOMS):
            row.paste(compose(tab[v], 220, 170, False, 16.0), (i * 220, 0))
        out.paste(row, (10, y + 30))
        lums = ", ".join("%s %.3f" % (v, tab[v]["lum"]) for v in NOMS if tab[v]["lum"] >= 0)
        d.text((680, y + 60), ("luminance mesurée : " + lums) if lums else "luminance non mesurée", fill=(230, 230, 230), font=f2)
        y += 226
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    out.save(a.dest, optimize=True)
    tel = a.dest.replace(".png", "-telephone.png")
    k = min(1.0, 1600.0 / out.width)
    out.resize((int(out.width * k), int(out.height * k)), Image.LANCZOS).save(tel, optimize=True)
    print("[FO-PLANCHE] %s (%d × %d) et %s" % (a.dest, out.width, out.height, tel))


if __name__ == "__main__":
    main()
