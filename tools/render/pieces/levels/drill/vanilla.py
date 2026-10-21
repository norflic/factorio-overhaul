"""Foreuse électrique VANILLA (niveau 1) composée hors moteur, image 0, 4 directions (lot V3, famille drill).

Python système (numpy + Pillow). Les couches, tailles et `shift` viennent de
<racine>/data/base/prototypes/entity/mining-drill.lua (1.1.91), relus le 21/10 :
  corps N/E/S/O        : lignes 441-747  (animation, repeat_count 5, image 0)
  tige verticale       : electric_mining_drill_animation()            162x156, by_pixel(1, -11), 30 images
  tige horizontale     : electric_mining_drill_horizontal_animation() 80x160,  by_pixel(2, -12)
  avant horizontal     : electric_mining_drill_horizontal_front_animation() 66x154, by_pixel(-3, 3)
  sorties N, E, O      : animation (sous la tige) ; sortie S : working_visualisations (devant)
  cadres avant E, S, O : working_visualisations, always_draw (devant)
  ombres               : corps + tige (image 0)
Ordre de dessin = ordre du prototype : couches de `animation`, puis `working_visualisations` (tige,
avant horizontal, cadres avant). Poussières et fumées (non toujours dessinées) exclues.

Repère : toile à 64 px par tuile (couches hr, scale 0,5 : 1 px hr = 1/64 tuile), origine = position
de l'entité. Les couches plates au sol (integration_patch) ne sont PAS composées (D1-3 amendé, Q13).
"""
import os

import numpy as np
from PIL import Image

DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
D = "electric-mining-drill/"


def bp(x, y):
    return (x / 32.0, y / 32.0)


def L(f, w, h, shift, kind="main"):
    return {"file": D + f, "w": w, "h": h, "shift": shift, "kind": kind}


VERT = L("hr-electric-mining-drill.png", 162, 156, bp(1, -11))
VERT_SH = L("hr-electric-mining-drill-shadow.png", 218, 56, bp(21, 5), "shadow")
HORI = L("hr-electric-mining-drill-horizontal.png", 80, 160, bp(2, -12))
HORI_SH = L("hr-electric-mining-drill-horizontal-shadow.png", 180, 164, bp(33, 1), "shadow")
HORI_FRONT = L("hr-electric-mining-drill-horizontal-front.png", 66, 154, bp(-3, 3))

LAYERS = {
    "N": [L("hr-electric-mining-drill-N.png", 190, 208, bp(0, -4)),
          L("hr-electric-mining-drill-N-output.png", 60, 66, bp(-3, -44)),
          L("hr-electric-mining-drill-N-shadow.png", 212, 204, bp(6, -3), "shadow"),
          VERT, VERT_SH],
    "E": [L("hr-electric-mining-drill-E.png", 192, 188, bp(0, -4)),
          L("hr-electric-mining-drill-E-output.png", 50, 74, bp(30, -8)),
          L("hr-electric-mining-drill-E-shadow.png", 222, 182, bp(10, 2), "shadow"),
          HORI, HORI_SH, HORI_FRONT,
          L("hr-electric-mining-drill-E-front.png", 136, 148, bp(21, 10))],
    "S": [L("hr-electric-mining-drill-S.png", 184, 192, bp(0, -1)),
          L("hr-electric-mining-drill-S-shadow.png", 212, 204, bp(6, 2), "shadow"),
          VERT, VERT_SH,
          L("hr-electric-mining-drill-S-output.png", 84, 56, bp(-1, 34)),
          L("hr-electric-mining-drill-S-front.png", 190, 104, bp(0, 27))],
    "W": [L("hr-electric-mining-drill-W.png", 192, 188, bp(0, -4)),
          L("hr-electric-mining-drill-W-output.png", 50, 60, bp(-31, -13)),
          L("hr-electric-mining-drill-W-shadow.png", 200, 182, bp(-5, 2), "shadow"),
          HORI, HORI_SH, HORI_FRONT,
          L("hr-electric-mining-drill-W-front.png", 134, 140, bp(-22, 12))],
}
DIRS = ("N", "E", "S", "W")
# LR (32 px/tuile) : mêmes couches en résolution normale (utile au masque de la version 32 px)
_cache = {}


def _img(rel):
    if rel not in _cache:
        im = Image.open(os.path.join(DATA, "base", "graphics", "entity", rel)).convert("RGBA")
        _cache[rel] = np.asarray(im).astype(np.float64) / 255.0
    return _cache[rel]


def compose(direction, canvas=(640, 640), origin=(320, 352)):
    """Compose le niveau 1 vanilla : renvoie dict(main=RGBA alpha droit sRGB, shadow=alpha, origin).

    Image 0 de chaque feuille (colonne 0, rangée 0). Composition « par-dessus » en sRGB codé,
    comme le moteur (mélange alpha dans l'espace du tampon, sans linéarisation).
    """
    H, W = canvas
    ox, oy = origin
    rgb = np.zeros((H, W, 3))
    a = np.zeros((H, W))
    sh = np.zeros((H, W))
    for lay in LAYERS[direction]:
        src = _img(lay["file"])[:lay["h"], :lay["w"]]
        x0 = ox + lay["shift"][0] * 64 - lay["w"] / 2.0
        y0 = oy + lay["shift"][1] * 64 - lay["h"] / 2.0
        xi, yi = int(round(x0)), int(round(y0))
        assert abs(xi - x0) < 1e-6 and abs(yi - y0) < 1e-6, (lay["file"], x0, y0)
        # découpe à la toile (une toile plus petite que le sprite : masque du niveau 2)
        xs0, ys0 = max(0, -xi), max(0, -yi)
        xd0, yd0 = max(0, xi), max(0, yi)
        ww, hh = min(lay["w"] - xs0, W - xd0), min(lay["h"] - ys0, H - yd0)
        if ww <= 0 or hh <= 0:
            continue
        src = src[ys0:ys0 + hh, xs0:xs0 + ww]
        sa = src[..., 3]
        if lay["kind"] == "shadow":
            sh[yd0:yd0 + hh, xd0:xd0 + ww] = np.maximum(sh[yd0:yd0 + hh, xd0:xd0 + ww], sa)
            continue
        d_rgb = rgb[yd0:yd0 + hh, xd0:xd0 + ww]
        d_a = a[yd0:yd0 + hh, xd0:xd0 + ww]
        # prémultiplié dans le tampon
        d_rgb[:] = src[..., :3] * sa[..., None] + d_rgb * (1 - sa[..., None])
        d_a[:] = sa + d_a * (1 - sa)
    main = np.zeros((H, W, 4))
    main[..., :3] = np.where(a[..., None] > 1e-8, rgb / np.maximum(a[..., None], 1e-8), 0)
    main[..., 3] = a
    return {"main": main, "shadow": sh, "origin": origin}


if __name__ == "__main__":
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else "vanilla-drill.png"
    tiles = []
    for d in DIRS:
        c = compose(d)
        m = c["main"]
        bg = np.full(m.shape[:2] + (3,), 0.35)
        bg = bg * (1 - 0.5 * c["shadow"][..., None])
        img = m[..., :3] * m[..., 3:4] + bg * (1 - m[..., 3:4])
        ox, oy = c["origin"]
        for k in (-96, 96):
            img[oy + k, :, :] = (1, 0, 0)
            img[:, ox + k, :] = (1, 0, 0)
        tiles.append(img)
    Image.fromarray((np.concatenate(tiles, 1) * 255).astype(np.uint8)).save(out)
    print(out)
