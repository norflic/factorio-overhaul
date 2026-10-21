"""Mesures sur les sprites vanilla qui fixent l'étalonnage (CALIBRATION.md §2 à §5). Lecture seule.

    python -P tools/render/calib/measure_vanilla.py "<racine>/data"

Imprime : épaisseur des tuyaux, ellipses des cercles verticaux et horizontaux, extension des sprites
autour de la position de l'entité (ancrage), ombres des poteaux (élévation du soleil), rampes des ombres,
liseré de contact, photométrie.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from fitlib import load, luminance, mid_boundary, fit_ellipse_axis, fit_arc, column_edge, stats_opaque  # noqa: E402


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    data = sys.argv[1]
    E = os.path.join(data, "base", "graphics", "entity")

    def ld(rel):
        return load(os.path.join(E, rel))

    print("== §2.1 Tuyaux : diamètre nord-sud contre épaisseur est-ouest (alpha >= 0,8)")
    v = ld("pipe/hr-pipe-straight-vertical.png")[..., 3]
    h = ld("pipe/hr-pipe-straight-horizontal.png")[..., 3]
    for lvl in (0.8, 0.98):
        ns = [int((v[y] >= lvl).sum()) for y in (64, 80)]
        ew = [int((h[:, x] >= lvl).sum()) for x in (40, 64, 80)]
        print("   alpha >= %.2f : nord-sud (largeur) %s, est-ouest (épaisseur) %s" % (lvl, ns, ew))

    print("== §2.2 Cercles VERTICAUX face caméra (brides plates) : arc d'ellipse, b/a (attendu sin θ)")
    for rel, side in [("pipe-to-ground/hr-pipe-to-ground-up.png", "bottom"), ("pipe-covers/hr-pipe-cover-south.png", "bottom"),
                      ("pipe-covers/hr-pipe-cover-north.png", "top"), ("pipe/hr-pipe-ending-down.png", "top")]:
        al = ld(rel)[..., 3]
        ys, xs = np.nonzero(al >= 0.85)
        lim = ys.max() - 14 if side == "bottom" else ys.min() + 14
        pts = []
        for x in range(xs.min(), xs.max() + 1):
            e = column_edge(al, x, side, 0.85)
            if e is not None and ((side == "bottom" and e > lim) or (side == "top" and e < lim + 1)):
                pts.append((x + 0.5, e))
        xc, yc, a, b, rms = fit_arc(np.array(pts), side)
        print("   %-42s %-6s a=%.2f b=%.2f b/a=%.3f rms=%.2f px" % (rel, side, a, b, b / a, rms))

    print("== §2.3 Cercle HORIZONTAL : bouche de la cheminée du four en acier (ellipse complète), b/a (attendu cos θ)")
    im = ld("steel-furnace/hr-steel-furnace.png")[0:20, 108:150]
    L, al = luminance(im), im[..., 3]
    for thr in (0.12, 0.15, 0.18):
        m = (L < thr) & (al > 0.9)
        # composante connexe qui contient le centre de la bouche
        seen = np.zeros_like(m)
        stack = [(8, 20)]
        while stack:
            y, x = stack.pop()
            if 0 <= y < m.shape[0] and 0 <= x < m.shape[1] and m[y, x] and not seen[y, x]:
                seen[y, x] = True
                stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
        xc, yc, a, b, rms = fit_ellipse_axis(mid_boundary(seen))
        print("   seuil %.2f : a=%.2f b=%.2f b/a=%.3f rms=%.2f px" % (thr, a, b, b / a, rms))
    hole = ld("rocket-silo/hr-01-rocket-silo-hole.png")[..., 3] >= 0.5
    ys, xs = np.nonzero(hole)
    print("   puits du silo (boîte, forme irrégulière) : %d x %d -> %.3f" % (np.ptp(xs) + 1, np.ptp(ys) + 1, (np.ptp(ys) + 1) / (np.ptp(xs) + 1)))

    print("== §2.4 Ancrage : étendue opaque relative à la position de l'entité (px HR ; demi-emprise entre crochets)")
    for rel, w, hh, sh, n in [("steel-furnace/hr-steel-furnace.png", 171, 174, (-0.0390625, 0.0625), 2),
                              ("assembling-machine-2/hr-assembling-machine-2.png", 214, 218, (0, 0.125), 3),
                              ("wooden-chest/hr-wooden-chest.png", 62, 72, (0.015625, -0.0625), 1),
                              ("iron-chest/hr-iron-chest.png", 66, 76, (-0.015625, -0.015625), 1),
                              ("stone-furnace/hr-stone-furnace.png", 151, 146, (-0.0078125, 0.1875), 2),
                              ("gun-turret/hr-gun-turret-base.png", 150, 118, (0.015625, -0.03125), 2)]:
        a = ld(rel)[:hh, :w, 3]
        cx, cy = w / 2 - sh[0] * 64, hh / 2 - sh[1] * 64
        ys, xs = np.nonzero(a >= 0.99)
        print("   %-50s gauche %6.1f droite %6.1f haut %6.1f bas %6.1f  [%d]" % (rel, xs.min() - cx, xs.max() + 1 - cx, ys.min() - cy, ys.max() + 1 - cy, 32 * n))

    print("== §3.1 Ombres des poteaux : sommet du poteau, bout de l'ombre (px HR relatifs à l'entité), tan(élévation) à θ = 45°")
    for name, main, ms, mw, mh, shadow, ss, sw, shh in [
            ("petit", "small-electric-pole/hr-small-electric-pole.png", (0.046875, -1.328125), 72, 220,
             "small-electric-pole/hr-small-electric-pole-shadow.png", (1.59375, 0.09375), 256, 52),
            ("moyen", "medium-electric-pole/hr-medium-electric-pole.png", (0.109375, -1.375), 84, 252,
             "medium-electric-pole/hr-medium-electric-pole-shadow.png", (1.765625, -0.03125), 280, 64),
            ("grand", "big-electric-pole/hr-big-electric-pole.png", (0, -1.59375), 148, 312,
             "big-electric-pole/hr-big-electric-pole-shadow.png", (1.875, 0), 374, 94)]:
        m = ld(main)[:mh, :mw, 3] >= 0.5
        ys, xs = np.nonzero(m)
        top = ys.min() + ms[1] * 64 - mh / 2
        topx = xs[ys == ys.min()].mean() + 0.5 + ms[0] * 64 - mw / 2
        s = ld(shadow)[:shh, :sw, 3]
        sy, sx = np.nonzero(s >= 0.2)
        tip = sx.max() + 1 + ss[0] * 64 - sw / 2
        tipy = sy[sx == sx.max()].mean() + 0.5 + ss[1] * 64 - shh / 2
        hpx = tipy - top
        L = tip - topx
        tan_e = hpx / (L * 0.7071067811865476)
        print("   %-6s sommet y=%.1f x=%.1f | bout de l'ombre x=%.1f y=%.1f | ombre/hauteur=%.3f tan=%.3f -> %.1f°" % (
            name, top, topx, tip, tipy, L / hpx, tan_e, np.degrees(np.arctan(tan_e))))

    print("== §4.1 Rampes des ombres (de alpha 0,9 à 0,1, px) et alpha du cœur")
    for rel in ("wooden-chest/hr-wooden-chest-shadow.png", "steel-furnace/hr-steel-furnace-shadow.png",
                "big-electric-pole/hr-big-electric-pole-shadow.png"):
        a = ld(rel)[..., 3]
        r = int(np.argmax(a.sum(1)))
        row = a[r]
        x9 = np.nonzero(row > 0.9)[0].max()
        x1 = np.nonzero(row > 0.1)[0].max()
        print("   %-50s rampe droite %d px, alpha max %.2f" % (rel, x1 - x9, a.max()))

    print("== §5 Photométrie des couches principales (pixels opaques)")
    print("   %-48s %6s %6s %6s %6s %6s %6s %6s" % ("sprite", "Lmoy", "Lstd", "p05", "p50", "p95", "sat", "grain"))
    for rel, box in [("steel-furnace/hr-steel-furnace.png", None), ("assembling-machine-2/hr-assembling-machine-2.png", (0, 0, 214, 218)),
                     ("gun-turret/hr-gun-turret-base.png", None), ("storage-tank/hr-storage-tank.png", (0, 0, 219, 215)),
                     ("boiler/hr-boiler-N-idle.png", (0, 0, 269, 221)), ("radar/hr-radar.png", (0, 0, 196, 254)),
                     ("steel-chest/hr-steel-chest.png", None), ("medium-electric-pole/hr-medium-electric-pole.png", (0, 0, 84, 252)),
                     ("pipe/hr-pipe-straight-vertical.png", None)]:
        im = ld(rel)
        if box:
            im = im[box[1]:box[3], box[0]:box[2]]
        s = stats_opaque(im)
        print("   %-48s %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f" % (rel, s["L_mean"], s["L_std"], s["L_p05"], s["L_p50"],
                                                                   s["L_p95"], s["sat_mean"], s["grain"]))


if __name__ == "__main__":
    main()
