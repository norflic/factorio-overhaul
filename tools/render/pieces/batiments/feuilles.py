"""FEUILLES DE JEU DU KIT batiments (lot POLISSAGE-FX, 10/11) : coffre d'équipe, pylône haute tension, cuve d'électrolyse ->
graphics/batiments/ (PNG hors de git, D-6), sprites.lua (généré, lu par prototypes/batiments_visuels.lua), sprites.json, MANIFEST.json.

    py -3.9 tools/render/pieces/batiments/feuilles.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut : fo-logs/2026-11-10_POLISSAGE-FX/rendu/<bâtiment> (à GARDER). Par bâtiment : couches principale, ombre, lueur ;
hr (64 px par tuile) copiée telle quelle, normale (32 px par tuile) réduite de moitié en alpha prémultiplié (Q.reduite du kit QG) ; boîte
de dessin, couleur de carte, icône à 4 mipmaps ; pylône : ANCRAGES des fils (pixels HR relatifs au pied -> tuiles, fil et ombre).
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
SRC_DEFAUT = os.path.join(LOGS, "2026-11-10_POLISSAGE-FX", "rendu")
SRC_TOURELLES = os.path.join(LOGS, "2026-11-10_POLISSAGE-2", "rendu")
DEST_DEFAUT = os.path.join(MOD, "graphics", "batiments")
PREFIXE_JEU = "__factorio-overhaul__/graphics/batiments/"
COMMANDE = ("py -3.9 tools/render/pieces/batiments/feuilles.py   (depuis la racine du mod ; sources : fo-logs/2026-11-10_POLISSAGE-FX/rendu "
            "et fo-logs/2026-11-10_POLISSAGE-2/rendu, à GARDER)")
BATIMENTS = ("coffre", "pylone", "cuve", "bastion2", "bastion3", "bastion4", "tesla", "laser_lourd")
# lot POLISSAGE-2 : tourelles électriques à tête non tournante ; leur lueur devient une bande de PULSE images (facteurs d'intensité
# précalculés, onde triangulaire : aucune trigonométrie), lue par prototypes/batiments_visuels.lua (têtes : direction_count 1)
TOURELLES = ("bastion2", "bastion3", "bastion4", "tesla", "laser_lourd")
PULSE = (0.5, 0.62, 0.76, 0.9, 1.0, 0.9, 0.76, 0.62)
SOURCES = {b: (SRC_TOURELLES if b in TOURELLES else SRC_DEFAUT) for b in BATIMENTS}
COUCHES = ("main", "shadow", "glow")

_spec = importlib.util.spec_from_file_location("qg_feuilles", os.path.join(HERE, "..", "levels", "qg_e", "feuilles.py"))
Q = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(Q)


def _ecrit(im, dest, f, fichiers):
    if max(im.size) > 8192:
        raise SystemExit("[FO-FEUILLES-BATIMENTS] %s dépasse 8 192 px (F144)" % f)
    im.save(os.path.join(dest, f), optimize=True)
    fichiers.append(f)


def couches(src, dest, cle, fichiers):
    p = os.path.join(src, cle, "spec.json")
    if not os.path.isfile(p):
        raise SystemExit("[FO-FEUILLES-BATIMENTS] %s absent : %s" % (cle, p))
    s = json.load(open(p, encoding="utf-8"))
    out = {}
    for k in COUCHES:
        c = s["layers"].get(k)
        if not c:
            continue
        im = Image.open(os.path.join(src, cle, c["file"])).convert("RGBA")
        if im.size != (c["width"], c["height"]):
            raise SystemExit("[FO-FEUILLES-BATIMENTS] %s : %s fait %s, spec.json %dx%d" % (cle, c["file"], im.size, c["width"], c["height"]))
        hr_f, lr_f = "hr-%s-%s.png" % (cle, k), "%s-%s.png" % (cle, k)
        _ecrit(im, dest, hr_f, fichiers)
        lr = Q.reduite(im)
        _ecrit(lr, dest, lr_f, fichiers)
        sh = [c["shift"][0], c["shift"][1]]
        out[k] = {"hr": {"filename": PREFIXE_JEU + hr_f, "width": im.size[0], "height": im.size[1], "shift": sh},
                  "lr": {"filename": PREFIXE_JEU + lr_f, "width": lr.size[0], "height": lr.size[1], "shift": sh}}
    if "main" not in out:
        raise SystemExit("[FO-FEUILLES-BATIMENTS] %s sans couche principale" % cle)
    anc = s.get("ancrages") or {}
    if anc:
        out["ancrages"] = {n: {"fil": [round(v["fil"][0] / 64.0, 4), round(v["fil"][1] / 64.0, 4)],
                               "ombre": [round(v["ombre"][0] / 64.0, 4), round(v["ombre"][1] / 64.0, 4)]} for n, v in sorted(anc.items())}
    return out


def pulse(src, dest, cle, c, fichiers):
    """Bande de len(PULSE) images de la lueur (hr et normale), intensité × facteur (alpha prémultiplié : la lueur additive baisse)."""
    g = c.get("glow")
    if not g:
        raise SystemExit("[FO-FEUILLES-BATIMENTS] %s : tourelle sans lueur" % cle)
    out = {}
    for res in ("hr", "lr"):
        p = os.path.join(dest, os.path.basename(g[res]["filename"]))
        a = np.asarray(Image.open(p).convert("RGBA")).astype(np.float64)
        imgs = []
        for f in PULSE:
            b = a.copy()
            b[..., 3] = b[..., 3] * f
            imgs.append(b)
        strip = Image.fromarray(np.concatenate(imgs, 1).round().astype(np.uint8), "RGBA")
        fn = ("hr-%s-pulse.png" if res == "hr" else "%s-pulse.png") % cle
        _ecrit(strip, dest, fn, fichiers)
        out[res] = {"filename": PREFIXE_JEU + fn, "width": a.shape[1], "height": a.shape[0], "shift": list(g[res]["shift"]),
                    "frame_count": len(PULSE), "line_length": len(PULSE)}
    return out


def couleur_moyenne(dest, cle):
    a = np.asarray(Image.open(os.path.join(dest, "hr-%s-main.png" % cle)).convert("RGBA")).astype(np.float64)
    w = a[..., 3] / 255.0
    rgb = (a[..., :3] * w[..., None]).sum((0, 1)) / max(1e-6, w.sum()) / 255.0
    return [round(float(c), 3) for c in rgb]


def icone(dest, cle, fichiers):
    """Icône 64 px à 4 mipmaps (64 + 32 + 16 + 8), réduite de la couche principale."""
    im = Image.open(os.path.join(dest, "hr-%s-main.png" % cle)).convert("RGBA")
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
    f = "%s-icone.png" % cle
    out.save(os.path.join(dest, f), optimize=True)
    fichiers.append(f)
    return {"filename": PREFIXE_JEU + f, "icon_size": 64, "icon_mipmaps": 4}


def rect(c):
    h = c["hr"]
    w, ht = h["width"] / 64.0, h["height"] / 64.0
    return (h["shift"][0] - w / 2, h["shift"][1] - ht / 2, h["shift"][0] + w / 2, h["shift"][1] + ht / 2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="", help="une seule source pour tous (défaut : SOURCES par bâtiment)")
    ap.add_argument("--dest", default=DEST_DEFAUT)
    ap.add_argument("--batiments", default=",".join(BATIMENTS))
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for f in os.listdir(a.dest):
        if f.endswith(".png"):
            os.remove(os.path.join(a.dest, f))
    fichiers, tab, mpx = [], {}, 0.0
    for cle in [b for b in a.batiments.split(",") if b]:
        src = a.src or SOURCES[cle]
        c = couches(src, a.dest, cle, fichiers)
        if cle in TOURELLES:
            c["pulse"] = pulse(src, a.dest, cle, c, fichiers)
        rs = [rect(v) for k, v in c.items() if k in ("main", "shadow", "glow")]
        c["boite"] = [[round(min(r[0] for r in rs), 4), round(min(r[1] for r in rs), 4)],
                      [round(max(r[2] for r in rs), 4), round(max(r[3] for r in rs), 4)]]
        for k in ("main", "glow"):
            if k in c:
                mpx += c[k]["hr"]["width"] * c[k]["hr"]["height"] / 1e6
        c["map_color"] = couleur_moyenne(a.dest, cle)
        c["icone"] = icone(a.dest, cle, fichiers)
        tab[cle] = c
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/batiments/feuilles.py (lot POLISSAGE-FX) : ne pas modifier à la main.\n"
              "-- Tailles en pixels, shift, boîtes et ancrages en tuiles ; hr = 64 px par tuile (scale 0,5), normale = 32.\n"
              "-- Images hors de git (D-6) : MANIFEST.json, « commande ».\n")
    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(entete + "return " + Q.lua(tab) + "\n")
    with open(os.path.join(a.dest, "sprites.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(tab, f, indent=1, sort_keys=True, ensure_ascii=False)
    man = {"commande": COMMANDE, "sources": a.src or sorted(set(SOURCES.values())), "fichiers": {}}
    total = 0
    for fn in sorted(fichiers):
        p = os.path.join(a.dest, fn)
        w, h = Image.open(p).size
        n = os.path.getsize(p)
        total += n
        man["fichiers"][fn] = {"sha256": Q.sha(p), "taille": n, "largeur": w, "hauteur": h}
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-BATIMENTS] %d fichiers PNG, %.2f Mo, %.2f Mpx HR (principale, lueur), sources %s" % (len(fichiers), total / 1e6, mpx,
          a.src or sorted(set(SOURCES.values()))))


if __name__ == "__main__":
    main()
