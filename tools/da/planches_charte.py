# -*- coding: utf-8 -*-
"""
Planches d'illustration de la charte (même échelle partout) à partir des composés écrits par
mesure_vanilla.py et mesure_apercus.py (4e argument : dossier d'aperçus).

    python planches_charte.py <dossier composés vanilla> <dossier composés aperçus> <mesures_vanilla.json>
                              <mesures_apercus_v3p1.json> <dossier de sortie>
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

PV, PA, JV, JA, OUT = sys.argv[1:6]
V = {r["nom"]: r for r in json.load(open(JV, encoding="utf-8"))}
A = {r["nom"]: r for r in json.load(open(JA, encoding="utf-8"))}
BG = (40, 40, 40)
try:
    FONT = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 15)
    FONTB = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 18)
except OSError:
    FONT = FONTB = ImageFont.load_default()


def crop(path, scale=1.0):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(int)
    m = np.abs(a - np.array(BG)).sum(2) > 6
    ys, xs = np.nonzero(m)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    if scale != 1.0:
        im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.LANCZOS)
    return im


def board(items, title, path, scale=1.0, gap=18):
    ims = [(crop(p, scale), lab) for p, lab in items]
    H = max(i.height for i, _ in ims)
    W = sum(max(i.width, 196) for i, _ in ims) + gap * (len(ims) + 1)
    sheet = Image.new("RGB", (W, H + 150), BG)
    d = ImageDraw.Draw(sheet)
    d.text((gap, 8), title, fill=(235, 235, 235), font=FONTB)
    x = gap
    for im, lab in ims:
        w = max(im.width, 196)
        sheet.paste(im, (x + (w - im.width) // 2, 40 + H - im.height))
        for j, line in enumerate(lab):
            d.text((x, 48 + H + j * 18), line, fill=(220, 220, 220), font=FONT)
        x += w + gap
    sheet.save(path)
    print(path, sheet.size)


def lab_v(n):
    r = V[n]
    return [n + " (" + r["cote_emprise"] + ")", "pièces %d · %.0f/t²" % (r["petites_pieces"], r["petites_pieces_par_tuile2"]),
            "grain %.1f · lap %.0f" % (r["grain_surfaces"], r["laplacien_moyen"]),
            "L p50 %.0f · massif %.2f" % (r["lum_p50"], r["part_massive"]), "remplissage %.2f" % r["remplissage_emprise"]]


def lab_a(n, titre):
    r = A[n]
    return [titre, "pièces %d · %.0f/t²" % (r["petites_pieces"], r["petites_pieces_par_tuile2"]),
            "grain %.1f · lap %.0f" % (r["grain_surfaces"], r["laplacien_moyen"]),
            "L p50 %.0f · massif %.2f" % (r["lum_p50"], r["part_massive"]), "remplissage %.2f" % r["remplissage_emprise"]]


board([(os.path.join(PV, "vanilla-gun-turret.png"), lab_v("gun-turret")),
       (os.path.join(PV, "vanilla-assembling-machine-3.png"), lab_v("assembling-machine-3")),
       (os.path.join(PV, "vanilla-centrifuge.png"), lab_v("centrifuge")),
       (os.path.join(PA, "cheminee-V0-sur-four-n00.png"), lab_a("cheminee-V0-sur-four-n00", "cheminée V0 + four")),
       (os.path.join(PA, "mitrailleuse-n11.png"), lab_a("mitrailleuse-n11", "V3p1 mitr. n11 (ép. 6)")),
       (os.path.join(PA, "mitrailleuse-n21.png"), lab_a("mitrailleuse-n21", "V3p1 mitr. n21 (ép. 11)")),
       (os.path.join(PA, "mitrailleuse-n29.png"), lab_a("mitrailleuse-n29", "V3p1 mitr. n29 (ép. 15)")),
       (os.path.join(PA, "assembleur-n21.png"), lab_a("assembleur-n21", "V3p1 assemb. n21 (ép. 11)")),
       (os.path.join(PA, "laser-n25.png"), lab_a("laser-n25", "V3p1 laser n25 (ép. 13)"))],
      "Charte DA : vanilla 1.1.91 et cheminée V0 validée contre les aperçus rejetés de V3 phase 1 (64 px/tuile, même échelle, corps seul)",
      os.path.join(OUT, "planche-A-vanilla-contre-v3p1.png"))

board([(os.path.join(PV, "vanilla-gun-turret.png"), lab_v("gun-turret")),
       (os.path.join(PV, "vanilla-artillery-turret.png"), lab_v("artillery-turret")),
       (os.path.join(PV, "vanilla-roboport.png"), lab_v("roboport")),
       (os.path.join(PV, "vanilla-nuclear-reactor.png"), lab_v("nuclear-reactor")),
       (os.path.join(PV, "vanilla-rocket-silo.png"), lab_v("rocket-silo"))],
      "Loi d'échelle vanilla : la taille multiplie les pièces, la densité par tuile reste ~29 (32 px/tuile, même échelle)",
      os.path.join(OUT, "planche-B-echelle-vanilla.png"), scale=0.5)
