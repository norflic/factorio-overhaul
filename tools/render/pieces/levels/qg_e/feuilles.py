"""FEUILLES DE JEU DES QG (lot QG-JEU, 1/11) : le centre de commandement et le QG des factions, 16 états (l'épave de
l'âge 0 et les âges 1 à 15) -> graphics/levels/centre/ (PNG hors de git, décision D-6), sprites.lua (généré, lu par
prototypes/levels/command.lua et prototypes/faction.lua), sprites.json et MANIFEST.json.

    py -3.9 tools/render/pieces/levels/qg_e/feuilles.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut : fo-logs/2026-11-01_QG-JEU/production/sprites/qgNN (à GARDER : rendus à 64 échantillons du kit
vaisseau_o, copiés des dossiers final / final2 de fo-logs/2026-10-31_QG/ageNN, PROVENANCE.txt). Pour chaque âge, trois
couches (principale, ombre, lueur), hr (64 px par tuile, hr-qgNN-*.png) copiée telle quelle et normale (32 px par tuile,
qgNN-*.png) réduite de moitié en alpha prémultiplié ; shift et tailles du spec.json du rendu. Par âge, en plus :
  - boite        drawing_box (tuiles) : union des trois couches (les sprites dépassent l'emprise en hauteur) ;
  - map_color    couleur moyenne de la couche principale (pondérée par l'alpha) ;
  - icone        icône 64 px à 4 niveaux de mipmaps (64 + 32 + 16 + 8), réduite de la couche principale.
"""
import argparse
import hashlib
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
LOGS = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
SRC_DEFAUT = os.path.join(LOGS, "2026-11-01_QG-JEU", "production", "sprites")
DEST_DEFAUT = os.path.join(MOD, "graphics", "levels", "centre")
PREFIXE_JEU = "__factorio-overhaul__/graphics/levels/centre/"
COUCHES = ("main", "shadow", "glow")
AGES = range(0, 16)
COMMANDE = "py -3.9 tools/render/pieces/levels/qg_e/feuilles.py   (depuis la racine du mod ; sources : " \
           "fo-logs/2026-11-01_QG-JEU/production/sprites, à GARDER)"


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def lire_spec(src, age):
    p = os.path.join(src, "qg%02d" % age, "spec.json")
    if not os.path.isfile(p):
        raise SystemExit("[FO-FEUILLES-QG] âge %d absent : %s" % (age, p))
    return json.load(open(p, encoding="utf-8"))


def reduite(im):
    """Moitié (arrondie au-dessus) en alpha prémultiplié : pas de liseré sombre sur les bords transparents."""
    w, h = im.size
    a = np.asarray(im.convert("RGBA")).astype(np.float64) / 255.0
    pm = a.copy()
    pm[..., :3] *= pm[..., 3:4]
    r = np.asarray(Image.fromarray((pm * 255).round().astype(np.uint8), "RGBA").resize(((w + 1) // 2, (h + 1) // 2),
                                                                                      Image.LANCZOS)).astype(np.float64) / 255.0
    al = np.clip(r[..., 3:4], 1e-6, 1)
    rgb = np.where(r[..., 3:4] > 1e-4, r[..., :3] / al, 0)
    out = np.concatenate([np.clip(rgb, 0, 1), r[..., 3:4]], -1)
    return Image.fromarray((out * 255).round().astype(np.uint8), "RGBA")


def copie_age(src, dest, age, fichiers):
    s = lire_spec(src, age)
    out = {}
    for k in COUCHES:
        c = s["layers"].get(k)
        if not c:
            continue
        hr_src = os.path.join(src, "qg%02d" % age, c["file"])
        hr_f = "hr-qg%02d-%s.png" % (age, k)
        lr_f = "qg%02d-%s.png" % (age, k)
        im = Image.open(hr_src).convert("RGBA")
        if im.size != (c["width"], c["height"]):
            raise SystemExit("[FO-FEUILLES-QG] %s : %s fait %s, spec.json %dx%d" % (hr_src, c["file"], im.size, c["width"], c["height"]))
        if max(im.size) > 8192:
            raise SystemExit("[FO-FEUILLES-QG] %s dépasse 8 192 px (F144)" % hr_src)
        im.save(os.path.join(dest, hr_f), optimize=True)
        lr = reduite(im)
        lr.save(os.path.join(dest, lr_f), optimize=True)
        fichiers.extend([hr_f, lr_f])
        out[k] = {"hr": {"filename": PREFIXE_JEU + hr_f, "width": im.size[0], "height": im.size[1],
                         "shift": [c["shift"][0], c["shift"][1]]},
                  "lr": {"filename": PREFIXE_JEU + lr_f, "width": lr.size[0], "height": lr.size[1],
                         "shift": [c["shift"][0], c["shift"][1]]}}
    if "main" not in out:
        raise SystemExit("[FO-FEUILLES-QG] âge %d sans couche principale" % age)
    return s, out


def rect(c):
    h = c["hr"]
    w, ht = h["width"] / 64.0, h["height"] / 64.0
    return (h["shift"][0] - w / 2, h["shift"][1] - ht / 2, h["shift"][0] + w / 2, h["shift"][1] + ht / 2)


def couleur_moyenne(dest, age):
    a = np.asarray(Image.open(os.path.join(dest, "hr-qg%02d-main.png" % age)).convert("RGBA")).astype(np.float64)
    w = a[..., 3] / 255.0
    rgb = (a[..., :3] * w[..., None]).sum((0, 1)) / max(1e-6, w.sum()) / 255.0
    return [round(float(c), 3) for c in rgb]


def icone(dest, age, fichiers):
    im = Image.open(os.path.join(dest, "hr-qg%02d-main.png" % age)).convert("RGBA")
    a = np.asarray(im)
    ys, xs = np.nonzero(a[..., 3] > 8)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    arr = np.asarray(sq).astype(np.float64) / 255.0
    pm = arr.copy()
    pm[..., :3] *= pm[..., 3:4]
    base = Image.fromarray((pm * 255).round().astype(np.uint8), "RGBA")
    out = Image.new("RGBA", (64 + 32 + 16 + 8, 64), (0, 0, 0, 0))
    x = 0
    for t in (64, 32, 16, 8):
        r = np.asarray(base.resize((t, t), Image.LANCZOS)).astype(np.float64) / 255.0
        al = np.clip(r[..., 3:4], 1e-6, 1)
        rgb = np.where(r[..., 3:4] > 1e-4, r[..., :3] / al, 0)
        u = np.concatenate([np.clip(rgb, 0, 1), r[..., 3:4]], -1)
        out.paste(Image.fromarray((u * 255).round().astype(np.uint8), "RGBA"), (x, 0))
        x += t
    f = "qg%02d-icone.png" % age
    out.save(os.path.join(dest, f), optimize=True)
    fichiers.append(f)
    return {"filename": PREFIXE_JEU + f, "icon_size": 64, "icon_mipmaps": 4}


def lua(v, ind=0):
    p = "  " * ind
    if isinstance(v, dict):
        if not v:
            return "{}"
        keys = sorted(v, key=lambda k: (isinstance(k, str), k))
        out = []
        for k in keys:
            kk = ("[%d]" % k) if isinstance(k, int) else k
            out.append("%s  %s = %s" % (p, kk, lua(v[k], ind + 1)))
        return "{\n" + ",\n".join(out) + "\n" + p + "}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x, ind) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(round(v, 6)) if isinstance(v, float) else str(v)
    return json.dumps(v, ensure_ascii=False)


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
    tab = {"ages": {}}
    for age in AGES:
        _, couches = copie_age(a.src, a.dest, age, fichiers)
        rs = [rect(c) for c in couches.values()]
        boite = [[round(min(r[0] for r in rs), 4), round(min(r[1] for r in rs), 4)],
                 [round(max(r[2] for r in rs), 4), round(max(r[3] for r in rs), 4)]]
        couches["boite"] = boite
        couches["map_color"] = couleur_moyenne(a.dest, age)
        couches["icone"] = icone(a.dest, age, fichiers)
        tab["ages"][age] = couches
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/levels/qg_e/feuilles.py (lot QG-JEU) : ne pas modifier à la\n"
              "-- main. Tailles en pixels, shift et boîtes en tuiles ; hr = 64 px par tuile (scale 0,5), normale = 32.\n"
              "-- Âge 0 = l'épave ; âges 1 à 15 = niveaux du centre. Images hors de git (D-6) : MANIFEST.json, « commande ».\n")
    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(entete + "return " + lua(tab) + "\n")
    with open(os.path.join(a.dest, "sprites.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(tab, f, indent=1, sort_keys=True, ensure_ascii=False)
    man = {"commande": COMMANDE, "arguments": [], "sources": a.src, "fichiers": {}}
    total = 0
    for fn in sorted(fichiers):
        p = os.path.join(a.dest, fn)
        w, h = Image.open(p).size
        n = os.path.getsize(p)
        total += n
        man["fichiers"][fn] = {"sha256": sha(p), "taille": n, "largeur": w, "hauteur": h}
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-QG] %d fichiers PNG, %.2f Mo, sources %s" % (len(fichiers), total / 1e6, a.src))


if __name__ == "__main__":
    main()
