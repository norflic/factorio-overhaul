"""Lot A3 (24/10) : planche des directions d'une tête de la mitrailleuse, composée sur son socle, et animation de
rotation (GIF et APNG). Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/planche64.py --age 5 --tetes DIR [--tetes DIR …] --dest DIR
        [--dirs 0-63] [--cols 16] [--zoom 1|2] [--nom planche.png] [--titre "…"] [--anim NOM] [--ms 70]
        [--sans-socle] [--sources-valides]

--tetes : dossiers de sorties de rendre.py, cherchés dans l'ordre ; pour dKK on cherche eNN-tete-dKK, puis, pour d00
et d16, les poses VALIDÉES eNN-tete-N et eNN-tete-E (--sources-valides ajoute les dossiers validés de feuilles.py et
le dossier S et O du lot A2). Socle : sprite validé de l'âge (niveau impair), jour, composition hors moteur de
compo.py (sol vanilla, ombre à 50 %, lueur additive), comme rose.py. Une case par direction, dans l'ordre d00 à d63
(d00 = nord, sens horaire), la source de chaque case est écrite dessous (V = validée, A2 = lot A2, A3 = ce lot…).
--anim : écrit NOM.gif et NOM.png (APNG) : une image par direction, fenêtre fixe (même cadre pour toutes).
Sortie texte : NOM.tsv (source, sha256 du PNG principal hr de chaque pose).
"""
import argparse
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402

LOGS = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
VALIDES = {e: os.path.join(LOGS, "2026-10-23_V3E-p5", "bas", "sprites") for e in range(1, 10)}
VALIDES.update({e: os.path.join(LOGS, "2026-10-23_V3E-p5", "haut", "sprites") for e in range(10, 13)})
VALIDES.update({e: os.path.join(LOGS, "2026-10-23_V3E-ereV", "sprites") for e in range(13, 16)})
A2 = os.path.join(LOGS, "2026-10-24_A2", "sprites")


def plage(spec):
    res = []
    for x in [x for x in str(spec).split(",") if x]:
        a, b = x.split("-") if "-" in x else (x, x)
        res += list(range(int(a), int(b) + 1))
    return res


def etiquette(d):
    d = d.replace("\\", "/").rstrip("/")
    if "V3E" in d:
        return "V"
    if "2026-10-24_A2" in d:
        return "A2"
    if "2026-10-24_A3" in d:
        return "A3"
    return d.split("/")[-1][:8]


def trouve(e, k, dossiers):
    noms = ["e%02d-tete-d%02d" % (e, k)]
    if k == 0:
        noms.append("e%02d-tete-N" % e)
    if k == 16:
        noms.append("e%02d-tete-E" % e)
    for d in dossiers:
        for n in noms:
            if os.path.exists(os.path.join(d, n, "spec.json")):
                return d, n
    return None, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--age", type=int, required=True)
    ap.add_argument("--tetes", action="append", default=[])
    ap.add_argument("--sources-valides", action="store_true")
    ap.add_argument("--dest", required=True)
    ap.add_argument("--dirs", default="0-63")
    ap.add_argument("--cols", type=int, default=16)
    ap.add_argument("--zoom", type=int, default=1, choices=(1, 2))
    ap.add_argument("--nom", default="")
    ap.add_argument("--titre", default="")
    ap.add_argument("--anim", default="")
    ap.add_argument("--ms", type=int, default=70)
    ap.add_argument("--sans-socle", action="store_true")
    ap.add_argument("--fenetre", type=int, default=0, help="côté de la fenêtre en tuiles (défaut : emprise + 4)")
    a = ap.parse_args()
    e = a.age
    dossiers = list(a.tetes)
    if a.sources_valides:
        dossiers += [VALIDES[e], A2]
    dirs = plage(a.dirs)
    T = a.fenetre or (K.SIDE[e] + 4)
    soc = [] if a.sans_socle else K.own(VALIDES[e], "e%02d-socle" % e)
    cell = int(T * 32 * a.zoom)
    lab_h, gap, head = 18, 4, 30
    cols = min(a.cols, len(dirs))
    rows = (len(dirs) + cols - 1) // cols
    W = cols * (cell + gap) + gap
    H = head + rows * (cell + lab_h + gap) + gap
    plate = Image.new("RGB", (W, H), (24, 24, 28))
    dr = ImageDraw.Draw(plate)
    f, fs = K.font(16), K.font(12, bold=False)
    dr.text((6, 6), a.titre or "Âge %d (%s) : directions %s, zoom %d, jour, hors moteur (d00 = nord, sens horaire)" % (
        e, K.NAME[e], a.dirs, a.zoom), font=f, fill=(235, 235, 235))
    frames = []
    tsv = ["dir\tsource\tvariante\tsha256_hr_main"]
    manque = []
    for i, k in enumerate(dirs):
        d, n = trouve(e, k, dossiers)
        x0 = gap + (i % cols) * (cell + gap)
        y0 = head + (i // cols) * (cell + lab_h + gap)
        if d is None:
            manque.append("d%02d" % k)
            dr.text((x0 + 4, y0 + 4), "d%02d absente" % k, font=fs, fill=(255, 80, 80))
            continue
        tete = K.own(d, n)
        day, _, _ = K.compose([{"pos": (T / 2, T / 2), "layers": soc + tete}], T, T)
        img = K.to_im(day if a.zoom == 2 else K.down2(day))
        if img.size != (cell, cell):
            img = img.resize((cell, cell), Image.LANCZOS)
        plate.paste(img, (x0, y0))
        dr.text((x0 + 2, y0 + cell + 2), "d%02d %s" % (k, etiquette(d)), font=fs, fill=(210, 210, 210))
        spec = json.load(open(os.path.join(d, n, "spec.json"), encoding="utf-8"))
        hm = hashlib.sha256(open(os.path.join(d, n, spec["layers"]["main"]["file"]), "rb").read()).hexdigest()
        tsv.append("d%02d\t%s\t%s\t%s" % (k, d, n, hm))
        frames.append((k, img))
    os.makedirs(a.dest, exist_ok=True)
    nom = a.nom or "planche-e%02d-%s-z%d.png" % (e, a.dirs.replace(",", "_"), a.zoom)
    plate.save(os.path.join(a.dest, nom))
    open(os.path.join(a.dest, nom[:-4] + ".tsv"), "w", encoding="utf-8", newline="\n").write("\n".join(tsv) + "\n")
    print("planche %s (%dx%d), %d poses, absentes : %s" % (os.path.join(a.dest, nom), W, H, len(frames),
                                                           ",".join(manque) or "aucune"))
    if a.anim and frames:
        ims = []
        for k, img in frames:
            im = img.copy()
            ImageDraw.Draw(im).text((4, 4), "d%02d" % k, font=fs, fill=(255, 255, 255))
            ims.append(im)
        ims[0].save(os.path.join(a.dest, a.anim + ".gif"), save_all=True, append_images=ims[1:], duration=a.ms,
                    loop=0, optimize=False)
        ims[0].save(os.path.join(a.dest, a.anim + ".png"), save_all=True, append_images=ims[1:], duration=a.ms,
                    loop=0, format="PNG")
        print("animation %s.gif et .png (APNG), %d images de %d ms" % (os.path.join(a.dest, a.anim), len(ims), a.ms))
    return 1 if manque else 0


if __name__ == "__main__":
    sys.exit(main())
