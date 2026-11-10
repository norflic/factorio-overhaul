"""FEUILLES PROCÉDURALES DES EFFETS (lot POLISSAGE-FX, 10/11) : VORTEX (spirale lumineuse qui tourne, 8 images) et ONDE (anneau de
choc qui s'élargit et s'éteint, 8 images). Blanches, en alpha : la TEINTE du prototype (couleur de l'arme, lue dans ses données)
leur donne leur couleur ; dessinées en « additive » / draw_as_glow par le jeu.

    py -3.9 tools/render/pieces/effets/vortex.py [--dest graphics/effets]      (depuis la racine du mod ; numpy + Pillow, pas de Blender)

Sorties (hors git, D-6) : hr-vortex.png (8 × 256 px), vortex.png (8 × 128 px), hr-onde.png, onde.png, sprites.lua (lu par
prototypes/effets_armes.lua : tailles, images, échelles), MANIFEST.json (SHA-256). DÉTERMINISTE : pur calcul, aucun aléa ;
la trigonométrie reste ici (outil de rendu), jamais dans la simulation (shared/content/effets_armes.lua, script).
"""
import argparse
import hashlib
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
DEST_DEFAUT = os.path.join(MOD, "graphics", "effets")
PREFIXE_JEU = "__factorio-overhaul__/graphics/effets/"
IMAGES = 8
PX = 128          # résolution normale ; hr = 2 ×
COMMANDE = "py -3.9 tools/render/pieces/effets/vortex.py   (depuis la racine du mod)"


def grille(n):
    """Coordonnées polaires normalisées d'une image n × n : r (0 au centre, 1 au bord inscrit), theta (radians)."""
    u = (np.arange(n) + 0.5) / n * 2.0 - 1.0
    x, y = np.meshgrid(u, u)
    return np.sqrt(x * x + y * y), np.arctan2(y, x)


def vortex(n, k):
    """Image k du vortex : trois bras en spirale logarithmique qui tournent d'un huitième de tour par image, cœur brillant,
    bord qui s'éteint en douceur ; luminance L (0-1) et alpha."""
    r, th = grille(n)
    phase = 2.0 * np.pi * k / IMAGES
    tors = 5.5 * np.log(np.maximum(r, 0.02))           # spirale : l'angle du bras dépend du rayon
    bras = 0.5 + 0.5 * np.cos(3.0 * th + tors - phase)  # 3 bras
    bras = bras ** 3.0
    rayon = np.clip(1.0 - r, 0.0, 1.0) ** 1.4           # s'éteint vers le bord
    coeur = np.exp(-(r / 0.16) ** 2)
    anneau = np.exp(-((r - 0.55) / 0.12) ** 2) * 0.35
    L = np.clip(bras * rayon * 0.9 + coeur * 1.2 + anneau, 0.0, 1.0)
    L = np.where(r > 1.0, 0.0, L)
    a = np.clip(L * 1.15, 0.0, 1.0)
    return L, a


def onde(n, k):
    """Image k de l'onde : anneau qui part du centre (rayon 0,12) et atteint le bord (0,95) à la dernière image, de plus en plus
    fin et transparent ; léger voile derrière le front."""
    r, _ = grille(n)
    t = k / (IMAGES - 1.0)
    r0 = 0.12 + 0.83 * t
    w = 0.16 * (1.0 - 0.55 * t)
    front = np.exp(-((r - r0) / w) ** 2)
    voile = np.clip((r0 - r) / max(r0, 1e-6), 0.0, 1.0) * 0.18 * (1.0 - t)
    L = np.clip(front + voile, 0.0, 1.0) * (1.0 - 0.75 * t)
    L = np.where(r > 1.0, 0.0, L)
    return L, np.clip(L * 1.3, 0.0, 1.0)


def feuille(fn, n):
    """Rangée de IMAGES images n × n ; blanc en RGB, luminance dans l'alpha (une teinte multiplie RGB : la couleur de l'arme)."""
    sheet = np.zeros((n, n * IMAGES, 4), dtype=np.float64)
    for k in range(IMAGES):
        L, a = fn(n, k)
        cell = sheet[:, k * n:(k + 1) * n]
        cell[..., 0] = cell[..., 1] = cell[..., 2] = np.clip(0.55 + 0.45 * L, 0.0, 1.0)
        cell[..., 3] = a
    return Image.fromarray((sheet * 255.0).round().astype(np.uint8), "RGBA")


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def lua(v, ind=0):
    pad = "  " * ind
    if isinstance(v, dict):
        rows = []
        for k in sorted(v):
            key = k if k.isidentifier() else '["%s"]' % k
            rows.append("%s  %s = %s" % (pad, key, lua(v[k], ind + 1)))
        return "{\n" + ",\n".join(rows) + "\n" + pad + "}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x, ind + 1) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % v
    return repr(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default=DEST_DEFAUT)
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    tab, fichiers = {}, []
    for nom, fn in (("vortex", vortex), ("onde", onde)):
        ent = {"images": IMAGES, "lr": {}, "hr": {}}
        for cle, n in (("lr", PX), ("hr", 2 * PX)):
            f = ("hr-%s.png" if cle == "hr" else "%s.png") % nom
            im = feuille(fn, n)
            im.save(os.path.join(a.dest, f), optimize=True)
            fichiers.append(f)
            ent[cle] = {"filename": PREFIXE_JEU + f, "width": n, "height": n, "scale": 1.0 if cle == "lr" else 0.5}
        tab[nom] = ent
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/effets/vortex.py (lot POLISSAGE-FX) : ne pas modifier à la main.\n"
              "-- Rangées de « images » images carrées ; lr = 32 px par tuile pour 1 tuile = 128 px (scale 1), hr = scale 0,5.\n"
              "-- Images hors de git (D-6) : MANIFEST.json, « commande ».\n")
    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(entete + "return " + lua(tab) + "\n")
    man = {"commande": COMMANDE, "fichiers": {}}
    total = 0
    for fn in sorted(fichiers):
        p = os.path.join(a.dest, fn)
        w, h = Image.open(p).size
        s = os.path.getsize(p)
        total += s
        man["fichiers"][fn] = {"sha256": sha(p), "taille": s, "largeur": w, "hauteur": h}
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-EFFETS] %d PNG, %.2f Mo -> %s" % (len(fichiers), total / 1e6, a.dest))


if __name__ == "__main__":
    main()
