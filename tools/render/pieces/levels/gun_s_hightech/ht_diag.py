"""Diagnostics hors Blender (aucun verrou) sur l'aperçu rapide de ht_apercu.py :
  - plus grands foyers lumineux (zone lumineuse dilatée de 3 px, comme da_lib L2) : taille et position ;
  - part VISIBLE du corps occupée par le tablier bas (matériaux « grille » du tablier, repérés par une couleur
    témoin) : garde-fou contre le piège de la dalle (critique de l'orchestrateur, point 1).

    python ht_diag.py [--levels 29] [--pose E] [--out <dossier>]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ht_apercu as A  # noqa: E402
import ht_gun as H  # noqa: E402

CHARTE = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3S\charte\outils"
sys.path.insert(0, CHARTE)
import da_lib as D  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="11,21,29")
    ap.add_argument("--pose", default="E")
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    for lv in [int(x) for x in a.levels.split(",")]:
        info = H.LEVELS[lv]
        pal = H.palette(info["epoch"])
        bs, _ = H.build("n%02d-socle" % lv)
        hl = 29 if lv == 30 else lv
        bh, ang = H.build("n%02d-tete-%s" % (hl, a.pose))
        parts = [A.triangles(bs, 0.0), A.triangles(bh, ang)]
        body, em, origin = A.raster(parts, [pal, pal])
        lum = D.dilate(em > 0.5, 3)
        szs, labmap = D.components(lum)
        sizes = []
        for k, cnt in szs.items():
            if cnt < 200:
                continue
            ys, xs = np.nonzero(labmap == k)
            sizes.append((cnt / 64.0 ** 2, (xs.mean() - origin[0]) / 64, (ys.mean() - origin[1]) / 64))
        sizes.sort(reverse=True)
        print("n%02d %s : %d foyers ; plus grands (t², x, y en tuiles depuis le centre) : %s" % (
            lv, a.pose, len(sizes), ", ".join("%.3f@(%.2f,%.2f)" % s for s in sizes[:6])))
        # tablier : rendu avec les matériaux du tablier en rouge pur
        pal2 = dict(pal)
        mask_parts = []
        for (T, mats) in parts[:1]:
            mask_parts.append((T, mats))
        tagged = {k: dict(v) for k, v in pal.items()}
        tagged["__apron"] = dict(kind="emit", color=(1.0, 0.0, 0.0))
        T, mats = parts[0]
        # le tablier est le premier groupe émis par apron() : on le repère par le préfixe du matériau "grille" posé
        # à z < 0,06 (dessus du tablier)
        low = T[:, :, 2].max(1) < 0.075
        mats2 = ["__apron" if (low[i] and mats[i] in ("grille", "plate2", "body", "bolt")) else mats[i]
                 for i in range(len(mats))]
        body2, em2, _ = A.raster([(T, mats2), parts[1]], [tagged, tagged])
        red = (body2[..., 0] > 0.99) & (body2[..., 1] < 0.01) & (body2[..., 3] > 0.5)
        tot = (body2[..., 3] > 0.5).sum()
        print("   tablier visible : %.1f %% du corps (%.2f t²)" % (100.0 * red.sum() / tot, red.sum() / 64.0 ** 2))
        if a.out:
            os.makedirs(a.out, exist_ok=True)
            im = Image.fromarray((np.clip(body2, 0, 1) * 255).astype(np.uint8), "RGBA")
            bg = Image.new("RGBA", im.size, (40, 40, 40, 255))
            bg.alpha_composite(im)
            bg.convert("RGB").save(os.path.join(a.out, "tablier-n%02d-%s.png" % (lv, a.pose)))


if __name__ == "__main__":
    main()
