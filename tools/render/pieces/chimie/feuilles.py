"""FEUILLES DE JEU DES MACHINES DE CHIMIE (lot DA-CHIMIE, 4/11) : vapocraqueur, reformeur, électrolyseur, colonne d'extraction,
chacune dans ses 4 directions -> graphics/machines/chimie/ (PNG hors de git, décision D-6), sprites.lua (généré, lu par
prototypes/chimie_visuels.lua), sprites.json et MANIFEST.json.

    py -3.9 tools/render/pieces/chimie/feuilles.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut : fo-logs/2026-11-04_DA-CHIMIE/final (à GARDER : rendus finaux de rendre.py, un dossier <machine>_<n|e|s|w>
avec spec.json). Couches : principale, ombre, lueur, et halo de nuit (« light », vapocraqueur) ; hr (64 px par tuile) copiée telle
quelle, normale (32 px par tuile) réduite de moitié en alpha prémultiplié (fonctions de levels/qg_e/feuilles.py) ; boîte de dessin
(union des 4 directions), couleur de carte, icône 64 px à 4 mipmaps (couche principale « nord »).
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
SRC_DEFAUT = os.path.join(LOGS, "2026-11-04_DA-CHIMIE", "final")
DEST_DEFAUT = os.path.join(MOD, "graphics", "machines", "chimie")
PREFIXE_JEU = "__factorio-overhaul__/graphics/machines/chimie/"
COUCHES = ("main", "shadow", "glow", "light")
MACHINES = ("craqueur", "reformeur", "electrolyseur", "colonne")
DIRS = ("n", "e", "s", "w")
COMMANDE = "py -3.9 tools/render/pieces/chimie/feuilles.py   (depuis la racine du mod ; sources : " \
           "fo-logs/2026-11-04_DA-CHIMIE/final, à GARDER)"
TAG = "[FO-FEUILLES-CHIMIE]"

_spec = importlib.util.spec_from_file_location("qg_feuilles", os.path.join(HERE, "..", "levels", "qg_e", "feuilles.py"))
Q = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(Q)


def copie(src, dest, nom, fichiers):
    p = os.path.join(src, nom, "spec.json")
    if not os.path.isfile(p):
        raise SystemExit("%s %s absente : %s" % (TAG, nom, p))
    s = json.load(open(p, encoding="utf-8"))
    out = {}
    for k in COUCHES:
        c = s["layers"].get(k)
        if not c:
            continue
        im = Image.open(os.path.join(src, nom, c["file"])).convert("RGBA")
        if im.size != (c["width"], c["height"]):
            raise SystemExit("%s %s : %s fait %s, spec.json %dx%d" % (TAG, nom, c["file"], im.size, c["width"], c["height"]))
        if max(im.size) > 8192:
            raise SystemExit("%s %s dépasse 8 192 px (F144)" % (TAG, c["file"]))
        hr_f, lr_f = "hr-%s-%s.png" % (nom, k), "%s-%s.png" % (nom, k)
        im.save(os.path.join(dest, hr_f), optimize=True)
        lr = Q.reduite(im)
        lr.save(os.path.join(dest, lr_f), optimize=True)
        fichiers.extend([hr_f, lr_f])
        sh = [c["shift"][0], c["shift"][1]]
        out[k] = {"hr": {"filename": PREFIXE_JEU + hr_f, "width": im.size[0], "height": im.size[1], "shift": sh},
                  "lr": {"filename": PREFIXE_JEU + lr_f, "width": lr.size[0], "height": lr.size[1], "shift": sh}}
    if "main" not in out or "shadow" not in out:
        raise SystemExit("%s %s sans couche principale ou sans ombre" % (TAG, nom))
    return out


def couleur_moyenne(dest, nom):
    a = np.asarray(Image.open(os.path.join(dest, "hr-%s-main.png" % nom)).convert("RGBA")).astype(np.float64)
    w = a[..., 3] / 255.0
    rgb = (a[..., :3] * w[..., None]).sum((0, 1)) / max(1e-6, w.sum()) / 255.0
    return [round(float(c), 3) for c in rgb]


def icone(dest, nom, machine, fichiers):
    """Icône 64 px à 4 niveaux de mipmaps (64 + 32 + 16 + 8), réduite de la couche principale (avec la lueur, qui fait la
    signature de la machine : flamme, tubes, cyan, phases)."""
    base = Image.open(os.path.join(dest, "hr-%s-main.png" % nom)).convert("RGBA")
    a = np.asarray(base)
    ys, xs = np.nonzero(a[..., 3] > 8)
    im = base.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    arr = np.asarray(sq).astype(np.float64) / 255.0
    arr[..., :3] *= arr[..., 3:4]
    lisse = Image.fromarray((arr * 255).round().astype(np.uint8), "RGBA")
    out = Image.new("RGBA", (64 + 32 + 16 + 8, 64), (0, 0, 0, 0))
    x = 0
    for t in (64, 32, 16, 8):
        r = np.asarray(lisse.resize((t, t), Image.LANCZOS)).astype(np.float64) / 255.0
        al = np.clip(r[..., 3:4], 1e-6, 1)
        rgb = np.where(r[..., 3:4] > 1e-4, r[..., :3] / al, 0)
        u = np.concatenate([np.clip(rgb, 0, 1), r[..., 3:4]], -1)
        out.paste(Image.fromarray((u * 255).round().astype(np.uint8), "RGBA"), (x, 0))
        x += t
    f = "%s-icone.png" % machine
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
    tab = {"machines": {}}
    mpx = 0.0
    for m in MACHINES:
        t = {}
        rs = []
        for d in DIRS:
            couches = copie(a.src, a.dest, "%s_%s" % (m, d), fichiers)
            rs += [rect(c) for k, c in couches.items() if k != "light"]
            for k, c in couches.items():
                mpx += c["hr"]["width"] * c["hr"]["height"] / 1e6
            t[d] = couches
        t["boite"] = [[round(min(r[0] for r in rs), 4), round(min(r[1] for r in rs), 4)],
                      [round(max(r[2] for r in rs), 4), round(max(r[3] for r in rs), 4)]]
        t["map_color"] = couleur_moyenne(a.dest, "%s_n" % m)
        t["icone"] = icone(a.dest, "%s_n" % m, m, fichiers)
        tab["machines"][m] = t
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/chimie/feuilles.py (lot DA-CHIMIE) : ne pas modifier à la main.\n"
              "-- machines[nom][n|e|s|w][main|shadow|glow|light] = { hr, lr } ; tailles en pixels, shift et boîtes en tuiles ;\n"
              "-- hr = 64 px par tuile (scale 0,5), normale (lr) = 32. Images hors de git (D-6) : MANIFEST.json, « commande ».\n")
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
    print("%s %d fichiers PNG, %.2f Mo, %.2f Mpx HR (toutes couches), sources %s" % (TAG, len(fichiers), total / 1e6, mpx, a.src))


if __name__ == "__main__":
    main()
