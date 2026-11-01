"""FEUILLES DE JEU DES ROBOTS (lot RB-V1, 1/11) : sprites de production -> graphics/robots/ (PNG hors de git, décision D-6),
sprites.lua (généré, lu par prototypes/robots.lua), MANIFEST.json. Hors Blender, Python 3.9.

    py -3.9 tools/render/pieces/robots/feuilles.py [--robots trotte] [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut : fo-logs/2026-11-01_RBV1/<robot>/sprites (à GARDER). Chaque robot donne :
  <robot>-run-<couche>.png et hr-<robot>-run-<couche>.png : 16 directions × images de marche (une ligne par direction, nord d'abord,
      sens horaire ; pas de `slice`, F23) ;
  <robot>-tir-<couche>.png et hr-… : 16 directions à l'arrêt, 2 images (au repos, puis la même reculée de 2 px : recul du tir, sans rendu de plus) ;
  <robot>-icone.png : icône 64 px à 4 niveaux de mipmaps.
Couches : main, glow (additive, draw_as_glow), mask (teinte du propriétaire), shadow (draw_as_shadow). Toutes les images d'une couche ont
la même case, qui contient toutes les images, l'origine de l'entité au même pixel. hr = 64 px par tuile (scale 0,5) ; normale = 16 px par tuile
(scale 2 ; PLAN §5, décision : budget de l'atlas du plancher), réduite en lumière linéaire, alpha prémultiplié.
"""
import argparse
import hashlib
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)
import piece  # noqa: E402
import fo_post as P  # noqa: E402

LOGS = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs")
DEST_DEFAUT = os.path.join(MOD, "graphics", "robots")
PREFIXE_JEU = "__factorio-overhaul__/graphics/robots/"
COUCHES = ("main", "glow", "mask", "shadow")
K_NORMALE = 4     # 64 -> 16 px par tuile
COMMANDE = "py -3.9 tools/render/pieces/robots/feuilles.py   (depuis la racine du mod ; sources : fo-logs/2026-11-01_RBV1/<robot>/sprites, à GARDER)"


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def lire(src, nom, couche):
    """(image RGBA 0..1, rectangle (x0, y0, x1, y1) en px HR autour de l'origine) ou (None, None)."""
    d = os.path.join(src, nom)
    p = os.path.join(d, "spec.json")
    if not os.path.isfile(p):
        raise SystemExit("[FO-FEUILLES-ROBOTS] variante absente : %s\n  relancer le rendu" % p)
    spec = json.load(open(p, encoding="utf-8"))
    c = spec["layers"].get(couche)
    if c is None:
        return None, None
    im = np.asarray(Image.open(os.path.join(d, c["file"])).convert("RGBA")).astype(np.float64) / 255.0
    h, w = im.shape[:2]
    cx, cy = c["shift"][0] * 64.0, c["shift"][1] * 64.0
    x0, y0 = int(round(cx - w / 2.0)), int(round(cy - h / 2.0))
    return im, (x0, y0, x0 + w, y0 + h)


def reduit(img, k, couche):
    """Réduction par k, alignée sur la case : RVB en lumière linéaire, prémultiplié par alpha."""
    h, w = img.shape[:2]
    a = img[..., 3:4]
    lin = P.srgb_to_lin(img[..., :3]) * a
    bloc = np.dstack([lin, a])
    bloc = bloc.reshape(h // k, k, w // k, k, 4).mean((1, 3))
    a2 = np.maximum(bloc[..., 3:4], 1e-5)
    rgb = np.clip(P.lin_to_srgb(np.clip(bloc[..., :3] / a2, 0.0, 1.0)), 0.0, 1.0)
    return np.dstack([rgb, bloc[..., 3]])


def ecrit(img, path):
    Image.fromarray(np.clip(np.round(img * 255.0), 0, 255).astype(np.uint8), "RGBA").save(path, optimize=True)


def planche(src, noms, couche, colonnes):
    """noms : variantes dans l'ordre du moteur, ou (variante, dx, dy) : image décalée de (dx, dy) px HR. Rend (image HR, largeur de case,
    hauteur de case, shift en tuiles), ou None si aucune image."""
    lus = []
    for n in noms:
        nom, dx, dy = n if isinstance(n, tuple) else (n, 0, 0)
        im, b = lire(src, nom, couche)
        lus.append((im, None if b is None else (b[0] + dx, b[1] + dy, b[2] + dx, b[3] + dy)))
    boites = [b for _, b in lus if b is not None]
    if not boites:
        return None
    x0, y0 = min(b[0] for b in boites), min(b[1] for b in boites)
    x1, y1 = max(b[2] for b in boites), max(b[3] for b in boites)
    # case multiple de K_NORMALE, pour la réduction ; origine au même pixel dans toutes les images
    x0 -= (x0 % K_NORMALE)
    y0 -= (y0 % K_NORMALE)
    w, h = x1 - x0, y1 - y0
    w += (-w) % K_NORMALE
    h += (-h) % K_NORMALE
    lignes = len(noms) // colonnes
    out = np.zeros((lignes * h, colonnes * w, 4))
    for i, (im, b) in enumerate(lus):
        if im is None:
            continue
        cx, cy = (i % colonnes) * w + (b[0] - x0), (i // colonnes) * h + (b[1] - y0)
        out[cy:cy + im.shape[0], cx:cx + im.shape[1]] = im
    return out, w, h, ((x0 + w / 2.0) / 64.0, (y0 + h / 2.0) / 64.0)


def noms_tir(robot, nd):
    """Tir, par direction : l'image à l'arrêt, puis la même reculée de 2 px à l'opposé du tir, à l'écran."""
    out = []
    for k in range(nd):
        th = 2.0 * math.pi * k / nd
        n = "%s-d%02d-tir" % (robot, k)
        out += [n, (n, int(round(-2.0 * math.sin(th))), int(round(2.0 * math.cos(th) * 0.7071)))]
    return out


def icone(src, nom, dest):
    d = os.path.join(src, nom)
    spec = json.load(open(os.path.join(d, "spec.json"), encoding="utf-8"))
    im = np.asarray(Image.open(os.path.join(d, spec["layers"]["main"]["file"])).convert("RGBA")).astype(np.float64) / 255.0
    a = im[..., 3] > 0.5
    ys, xs = np.nonzero(a)
    im = im[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = im.shape[:2]
    cote = max(h, w)
    car = np.zeros((cote, cote, 4))
    car[(cote - h) // 2:(cote - h) // 2 + h, (cote - w) // 2:(cote - w) // 2 + w] = im
    pm = Image.fromarray(np.clip(np.round(car * 255.0), 0, 255).astype(np.uint8), "RGBA")
    bande = Image.new("RGBA", (64 + 32 + 16 + 8, 64), (0, 0, 0, 0))
    x = 0
    for t in (64, 32, 16, 8):
        bande.paste(pm.resize((t, t), Image.LANCZOS), (x, 0))
        x += t
    bande.save(dest, optimize=True)
    return dest


def lua(v, ind=0):
    pad = " " * ind
    if isinstance(v, dict):
        if not v:
            return "{}"
        return "{\n" + "".join("%s  %s = %s,\n" % (pad, k, lua(v[k], ind + 2)) for k in sorted(v)) + pad + "}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x, ind) for x in v) + " }"
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, float):
        return ("%.6f" % v).rstrip("0").rstrip(".")
    return str(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--robots", default=",".join(n for n, d in piece.ROBOTS.items() if d.get("serie")))
    ap.add_argument("--src", default="", help="dossier des sprites (défaut : fo-logs/2026-11-01_RBV1/<robot>/sprites)")
    ap.add_argument("--dest", default=DEST_DEFAUT)
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    table, manifeste = {}, {"commande": COMMANDE, "fichiers": {}}
    total = 0.0
    for robot in [x for x in a.robots.split(",") if x]:
        nd, ni, dt = piece.ROBOTS[robot]["serie"]
        src = a.src or os.path.join(LOGS, "2026-11-01_RBV1", robot, "sprites")
        t = {"directions": nd, "images": ni, "tuiles_par_cycle": dt, "distance_per_frame": dt / float(ni), "anims": {}}
        for anim, noms, colonnes in (("run", ["%s-d%02d-m%02d" % (robot, k, i) for k in range(nd) for i in range(ni)], ni),
                                     ("tir", noms_tir(robot, nd), 8)):
            t["anims"][anim] = {"frame_count": 2 if anim == "tir" else ni, "line_length": colonnes, "couches": {}}
            for couche in COUCHES:
                pl = planche(src, noms, couche, colonnes)
                if pl is None:
                    continue
                img, w, h, shift = pl
                hr_n, lr_n = "hr-%s-%s-%s.png" % (robot, anim, couche), "%s-%s-%s.png" % (robot, anim, couche)
                ecrit(img, os.path.join(a.dest, hr_n))
                lo = reduit(img, K_NORMALE, couche)
                ecrit(lo, os.path.join(a.dest, lr_n))
                t["anims"][anim]["couches"][couche] = {"hr": PREFIXE_JEU + hr_n, "lr": PREFIXE_JEU + lr_n, "w": w, "h": h, "lw": w // K_NORMALE, "lh": h // K_NORMALE,
                                                       "shift": [round(shift[0], 5), round(shift[1], 5)]}
                total += img.shape[0] * img.shape[1] / 1e6
                for n_ in (hr_n, lr_n):
                    manifeste["fichiers"][n_] = sha(os.path.join(a.dest, n_))
        ic = "%s-icone.png" % robot
        icone(src, "%s-d10-tir" % robot, os.path.join(a.dest, ic))
        manifeste["fichiers"][ic] = sha(os.path.join(a.dest, ic))
        t["icone"] = PREFIXE_JEU + ic
        table[robot] = t
    # table lue dans prototypes/robots.lua ; manifeste du contrôle
    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GÉNÉRÉ par tools/render/pieces/robots/feuilles.py (lot RB-V1) : ne pas éditer. %s\nreturn %s\n" % (COMMANDE, lua(table)))
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifeste, f, indent=1, sort_keys=True)
    n = len(manifeste["fichiers"])
    taille = sum(os.path.getsize(os.path.join(a.dest, x)) for x in manifeste["fichiers"]) / 1e6
    print("[FO-FEUILLES-ROBOTS] %d fichiers PNG, %.2f Mo, HR %.2f Mpx avant rognage du moteur" % (n, taille, total))


if __name__ == "__main__":
    main()
