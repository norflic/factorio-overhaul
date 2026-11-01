"""FEUILLES DE JEU DES USINES DE ROBOTS (lot US-V1, 1/11) : Atelier, Hall, Dock, Portique -> graphics/robots/usines/ (PNG hors de git,
décision D-6), sprites.lua (généré, lu par prototypes/robots.lua), sprites.json et MANIFEST.json.

    py -3.9 tools/render/pieces/usines_robots/feuilles.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut : fo-logs/2026-11-01_USV1/production/sprites/<usine> (à GARDER : rendus à 64 échantillons validés par la critique,
PROVENANCE.txt). Pour chaque usine, trois couches (principale, ombre, lueur), hr (64 px par tuile) copiée telle quelle et normale (32 px
par tuile) réduite de moitié en alpha prémultiplié, shift et tailles du spec.json du rendu ; boîte de dessin, couleur de carte, icône.
Mêmes règles que tools/render/pieces/levels/qg_e/feuilles.py, dont les fonctions d'image sont reprises.
"""
import argparse
import importlib.util
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
LOGS = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
SRC_DEFAUT = os.path.join(LOGS, "2026-11-01_USV1", "production", "sprites")
DEST_DEFAUT = os.path.join(MOD, "graphics", "robots", "usines")
PREFIXE_JEU = "__factorio-overhaul__/graphics/robots/usines/"
COUCHES = ("main", "shadow", "glow")
USINES = ("atelier", "hall", "dock", "portique")
COMMANDE = "py -3.9 tools/render/pieces/usines_robots/feuilles.py   (depuis la racine du mod ; sources : " \
           "fo-logs/2026-11-01_USV1/production/sprites, à GARDER)"

_spec = importlib.util.spec_from_file_location("qg_feuilles", os.path.join(HERE, "..", "levels", "qg_e", "feuilles.py"))
Q = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(Q)


def copie(src, dest, nom, fichiers):
    p = os.path.join(src, nom, "spec.json")
    if not os.path.isfile(p):
        raise SystemExit("[FO-FEUILLES-USINES] %s absente : %s" % (nom, p))
    s = json.load(open(p, encoding="utf-8"))
    out = {}
    for k in COUCHES:
        c = s["layers"].get(k)
        if not c:
            continue
        im = Image.open(os.path.join(src, nom, c["file"])).convert("RGBA")
        if im.size != (c["width"], c["height"]):
            raise SystemExit("[FO-FEUILLES-USINES] %s : %s fait %s, spec.json %dx%d" % (nom, c["file"], im.size, c["width"], c["height"]))
        if max(im.size) > 8192:
            raise SystemExit("[FO-FEUILLES-USINES] %s dépasse 8 192 px (F144)" % c["file"])
        hr_f, lr_f = "hr-%s-%s.png" % (nom, k), "%s-%s.png" % (nom, k)
        im.save(os.path.join(dest, hr_f), optimize=True)
        lr = Q.reduite(im)
        lr.save(os.path.join(dest, lr_f), optimize=True)
        fichiers.extend([hr_f, lr_f])
        sh = [c["shift"][0], c["shift"][1]]
        out[k] = {"hr": {"filename": PREFIXE_JEU + hr_f, "width": im.size[0], "height": im.size[1], "shift": sh},
                  "lr": {"filename": PREFIXE_JEU + lr_f, "width": lr.size[0], "height": lr.size[1], "shift": sh}}
    if "main" not in out:
        raise SystemExit("[FO-FEUILLES-USINES] %s sans couche principale" % nom)
    return out


def couleur_moyenne(dest, nom):
    a = np.asarray(Image.open(os.path.join(dest, "hr-%s-main.png" % nom)).convert("RGBA")).astype(np.float64)
    w = a[..., 3] / 255.0
    rgb = (a[..., :3] * w[..., None]).sum((0, 1)) / max(1e-6, w.sum()) / 255.0
    return [round(float(c), 3) for c in rgb]


def icone(dest, nom, fichiers):
    """Icône 64 px à 4 niveaux de mipmaps (64 + 32 + 16 + 8), réduite de la couche principale."""
    im = Image.open(os.path.join(dest, "hr-%s-main.png" % nom)).convert("RGBA")
    a = np.asarray(im)
    ys, xs = np.nonzero(a[..., 3] > 8)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    arr = np.asarray(sq).astype(np.float64) / 255.0
    arr[..., :3] *= arr[..., 3:4]
    base = Image.fromarray((arr * 255).round().astype(np.uint8), "RGBA")
    out = Image.new("RGBA", (64 + 32 + 16 + 8, 64), (0, 0, 0, 0))
    x = 0
    for t in (64, 32, 16, 8):
        r = np.asarray(base.resize((t, t), Image.LANCZOS)).astype(np.float64) / 255.0
        al = np.clip(r[..., 3:4], 1e-6, 1)
        rgb = np.where(r[..., 3:4] > 1e-4, r[..., :3] / al, 0)
        u = np.concatenate([np.clip(rgb, 0, 1), r[..., 3:4]], -1)
        out.paste(Image.fromarray((u * 255).round().astype(np.uint8), "RGBA"), (x, 0))
        x += t
    f = "%s-icone.png" % nom
    out.save(os.path.join(dest, f), optimize=True)
    fichiers.append(f)
    return {"filename": PREFIXE_JEU + f, "icon_size": 64, "icon_mipmaps": 4}


def rect(c):
    h = c["hr"]
    w, ht = h["width"] / 64.0, h["height"] / 64.0
    return (h["shift"][0] - w / 2, h["shift"][1] - ht / 2, h["shift"][0] + w / 2, h["shift"][1] + ht / 2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for f in os.listdir(a.dest):
        if f.endswith(".png"):
            os.remove(os.path.join(a.dest, f))
    fichiers = []
    tab = {"usines": {}}
    mpx = 0.0
    for nom in USINES:
        couches = copie(a.src, a.dest, nom, fichiers)
        rs = [rect(c) for c in couches.values()]
        boite = [[round(min(r[0] for r in rs), 4), round(min(r[1] for r in rs), 4)],
                 [round(max(r[2] for r in rs), 4), round(max(r[3] for r in rs), 4)]]
        for k in ("main", "glow"):
            if k in couches:
                mpx += couches[k]["hr"]["width"] * couches[k]["hr"]["height"] / 1e6
        couches["boite"] = boite
        couches["map_color"] = couleur_moyenne(a.dest, nom)
        couches["icone"] = icone(a.dest, nom, fichiers)
        tab["usines"][nom] = couches
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/usines_robots/feuilles.py (lot US-V1) : ne pas modifier à la main.\n"
              "-- Tailles en pixels, shift et boîtes en tuiles ; hr = 64 px par tuile (scale 0,5), normale = 32.\n"
              "-- Images hors de git (D-6) : MANIFEST.json, « commande ».\n")
    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(entete + "return " + Q.lua(tab) + "\n")
    with open(os.path.join(a.dest, "sprites.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(tab, f, indent=1, sort_keys=True, ensure_ascii=False)
    man = {"commande": COMMANDE, "arguments": [], "sources": a.src, "fichiers": {}}
    total = 0
    for fn in sorted(fichiers):
        p = os.path.join(a.dest, fn)
        w, h = Image.open(p).size
        n = os.path.getsize(p)
        total += n
        man["fichiers"][fn] = {"sha256": Q.sha(p), "taille": n, "largeur": w, "hauteur": h}
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-USINES] %d fichiers PNG, %.2f Mo, %.2f Mpx HR (principale + lueur), sources %s" % (len(fichiers), total / 1e6, mpx, a.src))


if __name__ == "__main__":
    main()
