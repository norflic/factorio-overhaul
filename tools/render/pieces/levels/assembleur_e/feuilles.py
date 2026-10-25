"""FEUILLES DE JEU DE LA MACHINE D'ASSEMBLAGE (lot F3-B, 25/10) : sprites de production -> graphics/levels/assembleur/
(PNG hors de git, décision D-6), sprites.lua (généré, lu par prototypes/levels/assembler.lua), sprites.json et
MANIFEST.json. Sur le modèle du four (four_e/feuilles.py, lot F2-B). Hors Blender.

    py -3.9 tools/render/pieces/levels/assembleur_e/feuilles.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut : fo-logs/2026-10-25_F3/production/sprites (à GARDER : rendus à 128 échantillons, ombre à 32,
décision D-7). Pour chaque variante (e01-piece, eNN-machine, eNN-piece) : couches principale, lueur, halo, ombre en hr
(64 px par tuile) et normale (32 px par tuile), recopiées telles quelles (noms hr-asm-… et asm-…), shift et tailles du
spec.json du rendu. Par âge (2 à 15), en plus :
  - boite        drawing_box : union des couches principales de la machine et de la pièce (tuiles) ;
  - foyer        couleur de la lumière de l'âge (commun/ages.FOYER) : lumière de travail du prototype ;
  - teinte       teinte du niveau pair (epoques.teinte_pair : 0,8 + 0,2 × lumière de l'âge, phase F3-A2) ;
  - map_color    couleur moyenne de la couche principale de la machine (pondérée par l'alpha) ;
  - icone        icône 64 px à 4 niveaux de mipmaps (64 + 32 + 16 + 8), réduite de la machine.
Aucune image animée n'est produite (animation de travail au moindre coût : la couche de lueur rendue est rejouée en
working_visualisations, scintillante ; voir prototypes/levels/assembler.lua).
"""
import argparse
import hashlib
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.join(os.path.dirname(HERE), "commun")
sys.path.insert(0, HERE)
sys.path.insert(0, COMMUN)
import ages  # noqa: E402
import epoques  # noqa: E402

RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
LOGS = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
SRC_DEFAUT = os.path.join(LOGS, "2026-10-25_F3", "production", "sprites")
DEST_DEFAUT = os.path.join(MOD, "graphics", "levels", "assembleur")
PREFIXE_JEU = "__factorio-overhaul__/graphics/levels/assembleur/"
COUCHES = ("main", "glow", "light", "shadow")
COMMANDE = "py -3.9 tools/render/pieces/levels/assembleur_e/feuilles.py   (depuis la racine du mod ; sources : " \
           "fo-logs/2026-10-25_F3/production/sprites, à GARDER)"


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def lire_spec(src, nom):
    p = os.path.join(src, nom, "spec.json")
    if not os.path.isfile(p):
        raise SystemExit("[FO-FEUILLES-ASM] variante absente : %s (%s)" % (nom, p))
    return json.load(open(p, encoding="utf-8"))


def copie_variante(src, dest, nom, fichiers):
    s = lire_spec(src, nom)
    if s.get("samples", 0) < 128 and not os.environ.get("FO_ASM_APERCU"):
        raise SystemExit("[FO-FEUILLES-ASM] %s rendue à %s échantillons (production : 128 ; essai : FO_ASM_APERCU=1)"
                         % (nom, s.get("samples")))
    out = {}
    for k in COUCHES:
        L = s["layers"].get(k)
        if not L:
            continue
        hr_f, lr_f = L["file"], L["lr"]["file"]
        for f in (hr_f, lr_f):
            shutil.copyfile(os.path.join(src, nom, f), os.path.join(dest, f))
            fichiers.append(f)
        out[k] = {"hr": {"filename": PREFIXE_JEU + hr_f, "width": L["width"], "height": L["height"],
                         "shift": [L["shift"][0], L["shift"][1]]},
                  "lr": {"filename": PREFIXE_JEU + lr_f, "width": L["lr"]["width"], "height": L["lr"]["height"],
                         "shift": [L["lr"]["shift"][0], L["lr"]["shift"][1]]}}
    return s, out


def rect(c):
    h = c["hr"]
    w, ht = h["width"] / 64.0, h["height"] / 64.0
    return (h["shift"][0] - w / 2, h["shift"][1] - ht / 2, h["shift"][0] + w / 2, h["shift"][1] + ht / 2)


def icone(src, nom, dest, e, fichiers):
    s = lire_spec(src, nom)
    im = Image.open(os.path.join(src, nom, s["layers"]["main"]["file"])).convert("RGBA")
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
    f = "asm-e%02d-icone.png" % e
    out.save(os.path.join(dest, f), optimize=True)
    fichiers.append(f)
    return {"filename": PREFIXE_JEU + f, "icon_size": 64, "icon_mipmaps": 4}


def couleur_carte(src, nom):
    s = lire_spec(src, nom)
    a = np.asarray(Image.open(os.path.join(src, nom, s["layers"]["main"]["file"])).convert("RGBA")).astype(np.float64)
    w = a[..., 3] / 255.0
    rgb = (a[..., :3] * w[..., None]).sum((0, 1)) / max(1e-6, w.sum()) / 255.0
    return [round(float(c), 3) for c in rgb]


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
    _, piece1 = copie_variante(a.src, a.dest, "e01-piece", fichiers)
    tab["ages"][1] = {"piece": piece1}
    for e in range(2, 16):
        _, machine = copie_variante(a.src, a.dest, "e%02d-machine" % e, fichiers)
        _, piece = copie_variante(a.src, a.dest, "e%02d-piece" % e, fichiers)
        rs = [rect(machine["main"]), rect(piece["main"])]
        boite = [[min(r[0] for r in rs), min(r[1] for r in rs)], [max(r[2] for r in rs), max(r[3] for r in rs)]]
        foyer = list(ages.FOYER[e]["rgb"])
        tab["ages"][e] = {
            "machine": machine, "piece": piece, "boite": boite,
            "foyer": [round(c, 4) for c in foyer],
            "teinte": [round(c, 4) for c in epoques.teinte_pair(e)],
            "map_color": couleur_carte(a.src, "e%02d-machine" % e),
            "icone": icone(a.src, "e%02d-machine" % e, a.dest, e, fichiers),
        }
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/levels/assembleur_e/feuilles.py (lot F3-B) : ne pas modifier à\n"
              "-- la main. Tailles en pixels, shift en tuiles ; hr = 64 px par tuile (scale 0,5), normale = 32.\n"
              "-- Images hors de git (D-6) : MANIFEST.json, « commande ».\n")
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
    print("[FO-FEUILLES-ASM] %d fichiers PNG, %.2f Mo, sources %s" % (len(fichiers), total / 1e6, a.src))


if __name__ == "__main__":
    main()
