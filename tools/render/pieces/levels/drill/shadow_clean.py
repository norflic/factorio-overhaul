"""Nettoyage de la couche d'ombre des aperçus de la foreuse (lot V3, phase 1), hors Blender.

    python -P tools/render/pieces/levels/drill/shadow_clean.py      # repasse sur les ombres déjà écrites

Constat (22/10, 1 h 05, niveau 2 pose N, 24 échantillons) : la passe d'ombre (attrape-ombre Cycles) laisse
des points isolés de faible alpha jusqu'aux bords du canevas (≈ 2 300 px d'alpha 0,02 à 0,3 hors de
l'ombre réelle) : la boîte de recadrage couvre alors tout le canevas (556 × 472 px hr) et le moteur
afficherait un voile de points (alpha × 0,5, F58). Le vanilla a des ombres nettes (F58).

Filtre (fonction pure, ne modifie pas tools/render/fo_post.py) : un pixel d'ombre est gardé s'il est à
3 px au plus d'un « cœur » (alpha >= 0,30, après suppression des cœurs d'un seul pixel) ; les autres
passent à 0. Les rampes de bord (1 à 2 px) sont conservées ; seul le bruit éloigné disparaît.
Besoin signalé au pipeline partagé (lot V0b) : même filtre dans fo_post.shadow_layer, ou plus
d'échantillons sur la passe d'ombre.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_post as P  # noqa: E402

CORE = 0.30
REACH = 3


def _box_any(m, r):
    """Dilatation binaire par un carré (2r+1) × (2r+1), par sommes cumulées."""
    k = 2 * r + 1
    h, w = m.shape
    c = np.pad(m.astype(np.int32), ((r + 1, r), (r + 1, r))).cumsum(0).cumsum(1)
    s = c[k:k + h, k:k + w] - c[0:h, k:k + w] - c[k:k + h, 0:w] + c[0:h, 0:w]
    return s > 0


def despeckle(layer):
    """Couche d'ombre RGBA (float) -> même couche sans le bruit isolé. Renvoie (couche, pixels retirés)."""
    a = layer[..., 3]
    core = a >= CORE
    # cœurs d'un seul pixel (aucun voisin cœur en 8-connexité) : bruit
    nb = _box_any(core, 1).astype(np.int32)
    cnt = np.pad(core.astype(np.int32), 1)
    neigh = sum(cnt[1 + dy:1 + dy + a.shape[0], 1 + dx:1 + dx + a.shape[1]]
                for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dy, dx) != (0, 0))
    core = core & (neigh > 0)
    del nb
    keep = _box_any(core, REACH)
    out = layer.copy()
    removed = int(((a > 0) & ~keep).sum())
    out[..., 3] = np.where(keep, a, 0.0)
    return out, removed


def clean_file(path, shift):
    """Nettoie un PNG d'ombre déjà recadré ; renvoie la nouvelle définition (ou None si inchangé)."""
    img = np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0
    h, w = img.shape[:2]
    origin = (int(round(w / 2.0 - shift[0] * 64)), int(round(h / 2.0 - shift[1] * 64)))
    out, removed = despeckle(img)
    if removed == 0:
        return None
    box = P.trim_box(out, origin)
    x0, y0, x1, y1 = box
    sha = P.write_png(out[y0:y1, x0:x1], path)
    sd = P.sprite_def(box, origin, 64)
    return {"width": sd["width"], "height": sd["height"], "shift": sd["shift"], "sha256": sha, "removed": removed,
            "before": [w, h]}


def main():
    spec_path = os.path.join(RENDER, "out", "levels", "drill", "spec.json")
    with open(spec_path, encoding="utf-8") as f:
        spec = json.load(f)
    n = 0
    for key in sorted(spec["levels"]):
        for d in ("N", "E", "S", "W"):
            sd = spec["levels"][key].get(d, {}).get("shadow")
            if not sd or sd.get("despeckled"):
                continue
            path = os.path.join(RENDER, sd["file"])
            r = clean_file(path, sd["shift"])
            sd["despeckled"] = True
            if r is None:
                continue
            print("%s %s ombre : %d px de bruit retirés, %dx%d -> %dx%d" % (key, d, r["removed"], r["before"][0],
                                                                         r["before"][1], r["width"], r["height"]))
            sd.update({k: r[k] for k in ("width", "height", "shift", "sha256")})
            n += 1
    with open(spec_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(spec, f, indent=1, sort_keys=True)
    print("%d couches d'ombre nettoyées" % n)


if __name__ == "__main__":
    main()
