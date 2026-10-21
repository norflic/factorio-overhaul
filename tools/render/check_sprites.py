"""Contrôle hors moteur des sprites livrés (ce que le chargeur de Factorio refuserait ou afficherait mal).

    python tools/render/check_sprites.py [pièce ...]        (défaut : toutes celles de manifests/)

Pour chaque couche de chaque variante du manifeste :
- le PNG existe, est en RGBA 8 bits, et ses dimensions valent EXACTEMENT width × height déclarés
  (un rectangle plus grand que l'image fait refuser le prototype au chargement) ;
- hr = 2 × lr en largeur et en hauteur, même shift ;
- shift multiple exact de 1/64 de tuile (alignement au pixel HR) et bord gauche/haut sur la grille
  paire (alignement au pixel de la version normale) ;
- la somme SHA-256 du fichier est celle du manifeste (fichier non retouché à la main) ;
- couche non vide ; ombre noire ; icône 120 × 64 (64 + 32 + 16 + 8).
Code de sortie 1 au premier écart.
"""
import hashlib
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MOD_ROOT = os.path.dirname(os.path.dirname(HERE))


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def check(name):
    with open(os.path.join(HERE, "manifests", name + ".json"), encoding="utf-8") as f:
        man = json.load(f)
    errs, n = [], 0
    for v in man["variants"]:
        d = os.path.join(MOD_ROOT, "graphics", *v["dest"].split("/"))
        for layer, sd in sorted(v["spec"].items()):
            for res in ("lr", "hr"):
                s = sd[res]
                p = os.path.join(d, s["filename"])
                n += 1
                if not os.path.exists(p):
                    errs.append("absent : " + p)
                    continue
                im = Image.open(p)
                if im.mode != "RGBA":
                    errs.append("%s : mode %s (RGBA attendu)" % (s["filename"], im.mode))
                if im.size != (s["width"], s["height"]):
                    errs.append("%s : %s déclaré %dx%d" % (s["filename"], im.size, s["width"], s["height"]))
                if sha(p) != v["files"][s["filename"]]:
                    errs.append("%s : somme SHA-256 différente du manifeste" % s["filename"])
                for k in (0, 1):
                    q = s["shift"][k] * 64
                    if abs(q - round(q)) > 1e-9:
                        errs.append("%s : shift %r non multiple de 1/64" % (s["filename"], s["shift"]))
                # bord gauche/haut relatif à la position de l'entité, en px HR : pair
                w_hr, h_hr = sd["hr"]["width"], sd["hr"]["height"]
                left = s["shift"][0] * 64 - w_hr / 2.0
                top = s["shift"][1] * 64 - h_hr / 2.0
                if abs(left - round(left)) > 1e-9 or abs(top - round(top)) > 1e-9 or round(left) % 2 or round(top) % 2:
                    errs.append("%s : bord (%.2f, %.2f) px hors de la grille paire" % (s["filename"], left, top))
                ext = im.getextrema()
                if ext[3][1] == 0:
                    errs.append("%s : couche vide" % s["filename"])
                if layer == "shadow" and max(ext[0][1], ext[1][1], ext[2][1]) > 0:
                    errs.append("%s : ombre non noire" % s["filename"])
            if (sd["hr"]["width"], sd["hr"]["height"]) != (2 * sd["lr"]["width"], 2 * sd["lr"]["height"]):
                errs.append("%s/%s : hr ≠ 2 × lr" % (v["name"], layer))
            if sd["hr"]["shift"] != sd["lr"]["shift"]:
                errs.append("%s/%s : shift hr ≠ lr" % (v["name"], layer))
    for icon, h in man["icon"].items():
        p = os.path.join(MOD_ROOT, "graphics", *man["variants"][0]["dest"].split("/"), icon)
        n += 1
        im = Image.open(p)
        if im.size != (120, 64):
            errs.append("%s : %s au lieu de 120x64 (64 px + 3 mipmaps)" % (icon, im.size))
        if sha(p) != h:
            errs.append("%s : somme SHA-256 différente du manifeste" % icon)
    p = os.path.join(MOD_ROOT, "graphics", *man["variants"][0]["dest"].split("/"), "sprites.lua")
    if sha(p) != man["sprites_lua"]:
        errs.append("sprites.lua : somme différente du manifeste")
    return n, errs


def main():
    names = sys.argv[1:] or sorted(f[:-5] for f in os.listdir(os.path.join(HERE, "manifests")) if f.endswith(".json"))
    bad = 0
    for name in names:
        n, errs = check(name)
        for e in errs:
            print("[FO-SPRITES] ECHEC %s : %s" % (name, e))
        print("[FO-SPRITES] %s : %d fichiers contrôlés, %d écart(s)" % (name, n, len(errs)))
        bad += len(errs)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
