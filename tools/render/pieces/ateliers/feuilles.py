"""FEUILLES DE JEU DES BÂTIMENTS D'ATELIER (lot DA-ATELIERS, phase 3) -> graphics/machines/ateliers/ (PNG hors de git, décision D-6),
sprites.lua (généré, lu par prototypes/ateliers_visuels.lua), sprites.json et MANIFEST.json.

    py -3.9 tools/render/pieces/ateliers/feuilles.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut : fo-logs/2026-11-04_DA-ATELIERS/final/<bâtiment>/<variante> (à GARDER : rendus finaux à 256 échantillons,
post-traités par rendre.py). Pour chaque pièce et chaque couche : alpha nettoyé (sous 4/255 mis à zéro, îles isolées de moins de
24 px retirées : un pixel parasite gonfle le rectangle rangé dans l'atlas, plein au plancher, F186), recadrage pair (la version
32 px/tuile tombe au pixel) et shift recalculé, HR (64 px par tuile) et normale (32 px par tuile, moitié en alpha prémultiplié) ;
icône 64 px à 4 mipmaps ; couleur de carte. Mêmes fonctions d'image que tools/render/pieces/levels/qg_e/feuilles.py.
"""
import argparse
import importlib.util
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
LOGS = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
SRC_DEFAUT = os.path.join(LOGS, "2026-11-04_DA-ATELIERS", "final")
DEST_DEFAUT = os.path.join(MOD, "graphics", "machines", "ateliers")
PREFIXE_JEU = "__factorio-overhaul__/graphics/machines/ateliers/"
COMMANDE = "py -3.9 tools/render/pieces/ateliers/feuilles.py   (depuis la racine du mod ; sources : fo-logs/2026-11-04_DA-ATELIERS/final, à GARDER)"
# pièce du jeu : (dossier du bâtiment dans les sources, variante rendue, couches, icône)
PIECES = {
    "torchere": ("torchere", "torchere_e", ("main", "shadow", "glow", "light"), True),
    "concasseur": ("carriere", "concasseur_d", ("main", "shadow", "glow", "light"), True),
    "machoires": ("carriere", "machoires_d", ("main", "shadow", "glow", "light"), True),
    "torchere_tuyau_n": ("torchere", "raccord_torchere_n", ("main", "shadow"), False),
    "torchere_tuyau_e": ("torchere", "raccord_torchere_e", ("main", "shadow"), False),
    "torchere_tuyau_s": ("torchere", "raccord_torchere_s", ("main", "shadow"), False),
    "torchere_tuyau_o": ("torchere", "raccord_torchere_o", ("main", "shadow"), False),
}
SEUIL = 4.0 / 255.0
ILE_MIN_PX = 24

_spec = importlib.util.spec_from_file_location("qg_feuilles", os.path.join(HERE, "..", "levels", "qg_e", "feuilles.py"))
Q = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(Q)


def nettoie(im, shift, additive=False):
    """Alpha : seuil, îles isolées retirées ; recadrage PAIR et shift recalculé. Rend (image, shift, pixels retirés).
    Couche additive (lueur, halo) : une petite île n'est retirée que si elle est faible (alpha max < 0,2) : un voyant fait 5 à 10 px."""
    a = np.asarray(im).astype(np.float64) / 255.0
    al = a[..., 3]
    al[al < SEUIL] = 0.0
    lab, n = ndimage.label(al > 0, structure=np.ones((3, 3)))
    retires = 0
    if n:
        tailles = ndimage.sum(np.ones_like(al), lab, index=np.arange(1, n + 1))
        maxi = ndimage.maximum(al, lab, index=np.arange(1, n + 1))
        for i, (t, m) in enumerate(zip(tailles, maxi), start=1):
            if t < ILE_MIN_PX and (not additive or m < 0.2):
                al[lab == i] = 0.0
                retires += int(t)
    a[..., 3] = al
    ys, xs = np.nonzero(al > 0)
    if not len(xs):
        return None, shift, retires
    h, w = al.shape
    x0, y0 = xs.min() - xs.min() % 2, ys.min() - ys.min() % 2
    x1, y1 = xs.max() + 1, ys.max() + 1
    x1 += (x1 - x0) % 2
    y1 += (y1 - y0) % 2
    x1, y1 = min(x1, w + (w % 2)), min(y1, h + (h % 2))
    crop = np.zeros((y1 - y0, x1 - x0, 4))
    sub = a[y0:min(y1, h), x0:min(x1, w)]
    crop[:sub.shape[0], :sub.shape[1]] = sub
    ns = (float(shift[0] + ((x0 + x1) / 2.0 - w / 2.0) / 64.0), float(shift[1] + ((y0 + y1) / 2.0 - h / 2.0) / 64.0))
    return Image.fromarray((np.clip(crop, 0, 1) * 255).round().astype(np.uint8), "RGBA"), ns, retires


def copie(src, dest, nom, fichiers, bilan):
    bat, var, couches, _ = PIECES[nom]
    p = os.path.join(src, bat, var, "spec.json")
    if not os.path.isfile(p):
        raise SystemExit("[FO-FEUILLES-ATELIERS] %s absente : %s" % (nom, p))
    s = json.load(open(p, encoding="utf-8"))
    out = {}
    for k in couches:
        c = s["layers"].get(k)
        if not c:
            continue
        im = Image.open(os.path.join(src, bat, var, c["file"])).convert("RGBA")
        if im.size != (c["width"], c["height"]):
            raise SystemExit("[FO-FEUILLES-ATELIERS] %s : %s fait %s, spec.json %dx%d" % (nom, c["file"], im.size, c["width"], c["height"]))
        im, sh, ret = nettoie(im, c["shift"], additive=k in ("glow", "light"))
        if im is None:
            continue
        if max(im.size) > 8192:
            raise SystemExit("[FO-FEUILLES-ATELIERS] %s dépasse 8 192 px (F144)" % c["file"])
        bilan.append("%s %s : %dx%d, %d px isolés retirés" % (nom, k, im.size[0], im.size[1], ret))
        hr_f, lr_f = "hr-%s-%s.png" % (nom, k), "%s-%s.png" % (nom, k)
        im.save(os.path.join(dest, hr_f), optimize=True)
        lr = Q.reduite(im)
        lr.save(os.path.join(dest, lr_f), optimize=True)
        fichiers.extend([hr_f, lr_f])
        sh = [round(sh[0], 6), round(sh[1], 6)]
        out[k] = {"hr": {"filename": PREFIXE_JEU + hr_f, "width": im.size[0], "height": im.size[1], "shift": sh},
                  "lr": {"filename": PREFIXE_JEU + lr_f, "width": lr.size[0], "height": lr.size[1], "shift": sh}}
    if "main" not in out:
        raise SystemExit("[FO-FEUILLES-ATELIERS] %s sans couche principale" % nom)
    return out


def couleur_moyenne(dest, nom):
    a = np.asarray(Image.open(os.path.join(dest, "hr-%s-main.png" % nom)).convert("RGBA")).astype(np.float64)
    w = a[..., 3] / 255.0
    rgb = (a[..., :3] * w[..., None]).sum((0, 1)) / max(1e-6, w.sum()) / 255.0
    return [round(float(c), 3) for c in rgb]


def icone(dest, nom, fichiers):
    """Icône 64 px à 4 niveaux de mipmaps (64 + 32 + 16 + 8), réduite de la couche principale (même recette que les usines)."""
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
    fichiers, bilan = [], []
    tab = {"pieces": {}}
    mpx = 0.0
    for nom in sorted(PIECES):
        couches = copie(a.src, a.dest, nom, fichiers, bilan)
        rs = [rect(c) for c in couches.values()]
        couches["boite"] = [[round(float(min(r[0] for r in rs)), 4), round(float(min(r[1] for r in rs)), 4)],
                            [round(float(max(r[2] for r in rs)), 4), round(float(max(r[3] for r in rs)), 4)]]
        for k in ("main", "glow", "shadow", "light"):
            if k in couches:
                mpx += couches[k]["hr"]["width"] * couches[k]["hr"]["height"] / 1e6
        couches["map_color"] = couleur_moyenne(a.dest, nom)
        if PIECES[nom][3]:
            couches["icone"] = icone(a.dest, nom, fichiers)
        tab["pieces"][nom] = couches
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/ateliers/feuilles.py (lot DA-ATELIERS) : ne pas modifier à la main.\n"
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
    for b in bilan:
        print("  " + b)
    print("[FO-FEUILLES-ATELIERS] %d fichiers PNG, %.2f Mo, %.3f Mpx HR (toutes couches), sources %s" % (len(fichiers), total / 1e6, mpx, a.src))


if __name__ == "__main__":
    main()
