"""Tourelle laser : contrôle géométrique rapide (avant rendu) à partir des triangles exportés par `run_laser.py dry`.

Pour chaque niveau : boîte écran (tuiles) du socle + tête en N, E, S, O ; O = -(haut) - 1 ; largeur ; enveloppe
balayée de la tête sur 64 directions (bas et haut) ; comparaison à la cible §4.
Repère écran : x = X ; y = -0,7071 (Y + Z) (projection à 45°, tools/render/CALIBRATION.md §2).
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import laser_design as D  # noqa: E402

GEO = os.path.normpath(os.path.join(HERE, "..", "..", "..", "cache", "levels-laser", "geo"))
K = math.sqrt(0.5)


def rot(tris, heading_deg):
    a = -math.radians(heading_deg)
    c, s = math.cos(a), math.sin(a)
    out = tris.copy()
    out[..., 0] = tris[..., 0] * c - tris[..., 1] * s
    out[..., 1] = tris[..., 0] * s + tris[..., 1] * c
    return out


def screen(tris):
    x = tris[..., 0]
    y = -K * (tris[..., 1] + tris[..., 2])
    return x, y


def main():
    print("niv ép | O_N   O_E   O_S   O_W   max | cible | L_N   L_E  | tête: bas_env haut_env | z_max")
    for lv in range(2, 31):
        p = os.path.join(GEO, "geo-L%02d.npz" % lv)
        if not os.path.exists(p):
            continue
        g = np.load(p)
        e = D.epoch_of(lv)
        base = g["base"]
        bx, by = screen(base)
        row = []
        Ls = []
        if "head" in g:
            head = g["head"]
            for d in ("N", "E", "S", "W"):
                h = rot(head, D.DIRECTIONS[d])
                hx, hy = screen(h)
                top = min(by.min(), hy.min())
                row.append(-top - 1.0)
                Ls.append(max(bx.max(), hx.max()) - min(bx.min(), hx.min()))
            env_lo, env_hi = -9, 9
            for k in range(64):
                h = rot(head, k * 360.0 / 64)
                hx, hy = screen(h)
                env_lo = max(env_lo, hy.max())
                env_hi = min(env_hi, hy.min())
            zmax = float(max(head[..., 2].max(), base[..., 2].max()))
        else:
            row = [-by.min() - 1.0] * 4
            Ls = [bx.max() - bx.min()] * 2
            env_lo = env_hi = float("nan")
            zmax = float(base[..., 2].max())
        print("%3d %2d | %s %5.2f | %5.2f | %5.2f %5.2f | %+.2f %+.2f | %.2f  socle x[%.2f,%.2f] y[%.2f,%.2f]" % (
            lv, e, " ".join("%5.2f" % v for v in row), max(row), D.O_TARGET[e], Ls[0], Ls[1], env_lo, env_hi, zmax,
            bx.min(), bx.max(), by.min(), by.max()))


if __name__ == "__main__":
    main()
