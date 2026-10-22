"""Tourelle laser : contrôle géométrique rapide (avant rendu) à partir des triangles exportés par `run_laser.py dry`.

Pour chaque niveau : socle + tête en N, E, S, O RASTÉRISÉS à 64 px/tuile sur le canevas des aperçus ; O des MASSES
(bible §1.4 : tiges de moins de 0,15 tuile exclues, masses.py) et O_brut (tiges comprises) ; L des masses et L_brut ;
enveloppe balayée de la tête sur 64 directions (bas et haut) ; comparaison à la cible §4.
Repère écran : x = X ; y = -0,7071 (Y + Z) (projection à 45°, tools/render/CALIBRATION.md §2).
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import laser_design as D  # noqa: E402
import masses as MS  # noqa: E402

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


def pose_mask(g, heading):
    """Masque (canevas des aperçus, 64 px/tuile) du socle et de la tête tournée du cap donné."""
    ox, oy = D.ORIGIN_PX
    parts = [g["base"]]
    if "head" in g:
        parts.append(rot(g["head"], heading))
    tris = np.concatenate(parts, 0)
    x, y = screen(tris)
    xy = np.stack([ox + x * D.PPT, oy + y * D.PPT], -1)
    return MS.raster_tris(xy, (D.CANVAS_H, D.CANVAS_W))


def metrics(lv):
    """{pose: shape_metrics} sur la géométrie exportée, ou None."""
    p = os.path.join(GEO, "geo-L%02d.npz" % lv)
    if not os.path.exists(p):
        return None
    g = np.load(p)
    return {d: MS.shape_metrics(pose_mask(g, D.DIRECTIONS[d]), D.ORIGIN_PX) for d in ("N", "E", "S", "W")}


def main():
    print("niv ép | O masses N E S W  max | O_brut max | cible | L masses max  L_brut max | cible L | tête: bas_env haut_env | z_max")
    for lv in range(2, 31):
        p = os.path.join(GEO, "geo-L%02d.npz" % lv)
        if not os.path.exists(p):
            continue
        g = np.load(p)
        e = D.epoch_of(lv)
        base = g["base"]
        bx, by = screen(base)
        mt = metrics(lv)
        row = [mt[d]["O"] for d in ("N", "E", "S", "W")]
        obrut = max(mt[d]["O_brut"] for d in mt)
        lm = max(mt[d]["L"] for d in mt)
        lb = max(mt[d]["L_brut"] for d in mt)
        if "head" in g:
            head = g["head"]
            env_lo, env_hi = -9, 9
            for k in range(64):
                h = rot(head, k * 360.0 / 64)
                hx, hy = screen(h)
                env_lo = max(env_lo, hy.max())
                env_hi = min(env_hi, hy.min())
            zmax = float(max(head[..., 2].max(), base[..., 2].max()))
        else:
            env_lo = env_hi = float("nan")
            zmax = float(base[..., 2].max())
        # pivot qui amènerait O sur la cible du §4, si le sommet est celui de la tête (y écran = -K (Y + Z))
        piv = D.PIVOT.get(e)
        sug = piv + (D.O_TARGET[e] - max(row)) / K if (piv is not None and "head" in g) else float("nan")
        print("%3d %2d | %s %5.2f | %5.2f | %5.2f | %5.2f %5.2f | %5.2f | %+.2f %+.2f | %.2f  socle x[%.2f,%.2f] y[%.2f,%.2f] | pivot %.2f -> %.2f" % (
            lv, e, " ".join("%5.2f" % v for v in row), max(row), obrut, D.O_TARGET[e], lm, lb, D.L_TARGET[e], env_lo,
            env_hi, zmax, bx.min(), bx.max(), by.min(), by.max(), piv or float("nan"), sug))


if __name__ == "__main__":
    main()


def iou_table():
    """IoU entre époques consécutives (niveaux impairs) et D1-3 contre le vanilla, sur la géométrie rastérisée (avant
    rendu : estimation ; la mesure qui fait foi est measure_laser.py sur les aperçus)."""
    import compose_laser as CL
    masks = {}
    for lv in range(3, 31):
        p = os.path.join(GEO, "geo-L%02d.npz" % lv)
        if os.path.exists(p):
            g = np.load(p)
            masks[lv] = {d: pose_mask(g, D.DIRECTIONS[d]) for d in ("N", "E", "S", "W")}
    masks[1] = {d: CL.mask_of(1, d) for d in ("N", "E", "S", "W")}
    for lv in range(3, 30, 2):
        prev = lv - 2
        if lv in masks and prev in masks:
            v = max(MS.iou(masks[lv][d], masks[prev][d]) for d in masks[lv])
            print("IoU époque %d / %d (niv. %d / %d) : %.3f" % (D.epoch_of(lv), D.epoch_of(prev), lv, prev, v))
    for last in (29, 30):
        if last in masks:
            print("D1-3 estimé niv. 1 / %d : IoU max %.3f" % (last, max(MS.iou(masks[1][d], masks[last][d]) for d in masks[1])))


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "--iou":
    iou_table()
