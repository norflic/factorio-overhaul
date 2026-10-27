# -*- coding: utf-8 -*-
"""Lot CAPIB : planches des captures du banc capi-partie pour le Directeur Créatif (moins de 2 000 px de côté).

Usage : py -3.9 -B tools/autotest/capi_planches.py <dossier fo-shots> <dossier de sortie> [--titre "texte"]
Lit fo-shots/capi-<faction>-<30min|60min|90min>-<base|gisement|foreuses>.png ; écrit :
  - planche-gisements.png : une ligne par faction, 30 / 60 / 90 min du gisement exploité (640 x 360 chacune) ;
  - planche-bases.png     : une ligne par faction, la base à 30 / 60 / 90 min ;
  - <faction>-<moment>-gisement.png en 1600 x 900 (copie, pour regarder en grand).
"""
import os
import re
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

MOMENTS = ["30min", "60min", "90min"]
W, H = 640, 360
LABEL = 28


def font(size):
    for name in ("arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def planche(shots, kind, factions, out, titre):
    rows = len(factions)
    cols = len(MOMENTS)
    img = Image.new("RGB", (cols * W, rows * (H + LABEL) + LABEL), (24, 24, 24))
    d = ImageDraw.Draw(img)
    f = font(18)
    d.text((8, 4), titre, fill=(240, 240, 240), font=f)
    for r, fk in enumerate(factions):
        for c, m in enumerate(MOMENTS):
            x, y = c * W, LABEL + r * (H + LABEL)
            p = None
            for k in ([kind] if kind != "gisement" else ["gisement", "foreuses"]):
                cand = os.path.join(shots, "capi-%s-%s-%s.png" % (fk, m, k))
                if os.path.exists(cand):
                    p = cand
                    break
            d.text((x + 8, y + 4), "%s - %s" % (fk, m), fill=(255, 220, 120), font=f)
            if p:
                im = Image.open(p).convert("RGB")
                im.thumbnail((W, H))
                img.paste(im, (x, y + LABEL))
            else:
                d.text((x + 8, y + LABEL + 8), "(pas de capture)", fill=(200, 80, 80), font=f)
    img.save(out)
    return img.size


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    shots, out = argv[0], argv[1]
    titre = "Capitalisation des factions (fo-war-capi allume)"
    if "--titre" in argv:
        titre = argv[argv.index("--titre") + 1]
    os.makedirs(out, exist_ok=True)
    factions = set()
    for name in os.listdir(shots):
        m = re.match(r"capi-(\w+)-(30min|60min|90min)-(base|gisement|foreuses)\.png$", name)
        if m:
            factions.add(m.group(1))
            if m.group(3) != "base":
                shutil.copyfile(os.path.join(shots, name), os.path.join(out, "%s-%s-%s.png" % (m.group(1), m.group(2), m.group(3))))
    factions = sorted(factions)
    if not factions:
        print("aucune capture capi-*")
        return 1
    s1 = planche(shots, "gisement", factions, os.path.join(out, "planche-gisements.png"), titre + " : gisement exploite, 30 / 60 / 90 min")
    s2 = planche(shots, "base", factions, os.path.join(out, "planche-bases.png"), titre + " : base, 30 / 60 / 90 min")
    print("planches : gisements %dx%d, bases %dx%d, %d faction(s)" % (s1[0], s1[1], s2[0], s2[1], len(factions)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
