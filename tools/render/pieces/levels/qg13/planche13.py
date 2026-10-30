"""PLANCHE du QG âge 13 : notre état À CÔTÉ des âges voisins (s'ils existent), de l'ancienne v6 et de sprites vanilla,
même sol, même échelle, ombre et lueur composées comme en jeu (commun/compo.py). Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/levels/qg13/planche13.py --dest p.png --zoom 1
        --cases "own:<dossier>:<nom>:<titre>:16x8,van:vaisseau,van:reacteur" [--nuit] [--titre "…"]

« own:<dossier>:<nom>:<titre>:<LxH> » : sprites produits par un rendre.py (dossier/<nom>/spec.json) ;
« van:<clé> » : sprite vanilla posé à son shift du jeu ; « auto:<dossier d'âge>:<titre> » : le spec.json le plus
récent sous ce dossier (âges voisins des autres agents), ignoré s'il n'y en a pas.
"""
import argparse
import glob
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
import compo as K  # noqa: E402

ENT = os.path.join(K.DATA, "base", "graphics", "entity")
VANILLA = {
    "vaisseau": ("crash-site-spaceship/hr-spaceship.png", (0, 0, 1228, 790), (-13, 34),
                 "crash-site-spaceship/hr-spaceship-shadow.png", (0, 0, 1340, 842), (-23, 50), (16, 8),
                 "Vanilla : épave du vaisseau"),
    "raffinerie": ("oil-refinery/hr-oil-refinery.png", (0, 0, 386, 430), (0, -7.5),
                   "oil-refinery/hr-oil-refinery-shadow.png", (0, 0, 674, 426), (82.5, 26.5), (5, 5),
                   "Vanilla : raffinerie"),
    "reacteur": ("nuclear-reactor/hr-reactor.png", (0, 0, 302, 318), (-5, -7),
                 "nuclear-reactor/hr-reactor-shadow.png", (0, 0, 525, 323), (52, 0), (5, 5),
                 "Vanilla : réacteur"),
    "silo": ("rocket-silo/hr-06-rocket-silo.png", (0, 0, 608, 596), (3, -1),
             "rocket-silo/hr-00-rocket-silo-shadow.png", (0, 0, 612, 578), (8, 2), (9, 9),
             "Vanilla : silo"),
}


def _png(rel, rect):
    im = Image.open(os.path.join(ENT, rel)).convert("RGBA").crop(rect)
    return np.asarray(im).astype(np.float64) / 255.0


def own(d, nom):
    sp = os.path.join(d, nom, "spec.json")
    spec = json.load(open(sp, encoding="utf-8"))
    res = []
    for k in ("shadow", "main", "glow"):
        if k in spec["layers"]:
            s = spec["layers"][k]
            img = np.asarray(Image.open(os.path.join(d, nom, s["file"])).convert("RGBA")).astype(np.float64) / 255
            res.append({"img": img, "shift": tuple(s["shift"]), "kind": k})
    return res


def case(c):
    """(couches, emprise, titre) ou None."""
    p = c.split(":")
    if p[0] == "van":
        f, r, sh, fs, rs, shs, emp, t = VANILLA[p[1]]
        return ([{"img": _png(fs, rs), "shift": (shs[0] / 32.0, shs[1] / 32.0), "kind": "shadow"},
                 {"img": _png(f, r), "shift": (sh[0] / 32.0, sh[1] / 32.0), "kind": "main"}], emp, t)
    if p[0] == "own":
        rest = c[4:]
        # le dossier peut contenir « F: » : on découpe par la droite
        d, nom, titre, emp = rest.rsplit(":", 3)
        w, h = emp.split("x")
        return own(d, nom), (int(w), int(h)), titre
    if p[0] == "auto":
        d, titre = c[5:].rsplit(":", 1)
        specs = [s for s in glob.glob(os.path.join(d, "**", "spec.json"), recursive=True)
                 if "main" in json.load(open(s, encoding="utf-8")).get("layers", {})]
        if not specs:
            return None
        sp = max(specs, key=os.path.getmtime)
        dd, nom = os.path.split(os.path.dirname(sp))
        return own(dd, nom), (16, 8), "%s (%s)" % (titre, os.path.relpath(os.path.dirname(sp), d))
    raise SystemExit("case inconnue : " + c)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--cases", required=True)
    ap.add_argument("--zoom", type=int, default=1, choices=(1, 2))
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--titre", default="")
    ap.add_argument("--haut", type=float, default=15.0)
    ap.add_argument("--oy", type=float, default=10.5)
    a = ap.parse_args()
    cs = [x for x in (case(c) for c in a.cases.split(",") if c) if x is not None]
    ppt = 64 if a.zoom == 2 else 32
    ch = int(a.haut * ppt)
    gap, hd, lab = 6, 40, 30
    cw = [int((max(e[0], 6) + 3) * ppt) for _, e, _ in cs]
    W = sum(cw) + (len(cs) + 1) * gap
    H = hd + ch + lab + gap
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), a.titre or "QG âge 13 · zoom %d · %s" % (a.zoom, "nuit" if a.nuit else "jour"),
            fill=(255, 205, 120), font=K.font(22 if a.zoom == 2 else 16))
    x = gap
    for i, (lays, e, t) in enumerate(cs):
        Wt = cw[i] / float(ppt)
        day, night, _ = K.compose([{"pos": (Wt / 2.0, a.oy), "layers": lays}], Wt, a.haut)
        img = night if a.nuit else day
        if a.zoom == 1:
            img = K.down2(img)
        im = K.to_im(img)
        d2 = ImageDraw.Draw(im)
        # emprise tracée au sol (pointillés)
        x0, x1 = (Wt / 2.0 - e[0] / 2.0) * ppt, (Wt / 2.0 + e[0] / 2.0) * ppt
        y0, y1 = (a.oy - e[1] / 2.0) * ppt, (a.oy + e[1] / 2.0) * ppt
        for k in range(int(x0), int(x1), 8):
            d2.line([(k, y0), (k + 3, y0)], fill=(255, 255, 255))
            d2.line([(k, y1), (k + 3, y1)], fill=(255, 255, 255))
        for k in range(int(y0), int(y1), 8):
            d2.line([(x0, k), (x0, k + 3)], fill=(255, 255, 255))
            d2.line([(x1, k), (x1, k + 3)], fill=(255, 255, 255))
        sheet.paste(im, (x, hd))
        dr.text((x + 6, hd + ch + 4), "%s · %d×%d" % (t, e[0], e[1]), fill=(235, 235, 235), font=K.font(16 if a.zoom == 2 else 12))
        x += cw[i] + gap
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest, optimize=True)
    print(a.dest, sheet.size)


if __name__ == "__main__":
    main()
