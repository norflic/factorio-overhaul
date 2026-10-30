"""Essai C du four de frittage : BATTERIE DE CORNUES. Massif de briques réfractaires tenu par des poutres en H et
des tirants, chapeau de basalte ; 2 portes de cornue rougeoyantes au sud ; colonnes montantes vers un barillet de
gaz posé sur le massif, qui descend au centre vers la sortie sud et file au gazomètre (nord-est) ; cheminée de
briques (nord-ouest) ; arrivée nord dans la face nord du massif."""
import math

import geo
from organes import Y
import fritt_commun as FC


def build(S, k):
    FC.raccords(k)
    z0 = k.socle(3, 0.4, 0.14, "socle", "capot")
    x0, x1, ys, yn_, zm = -1.3, 1.3, Y(-0.82), Y(0.62), 1.08
    # massif de briques, chapeau de basalte, poutres en H et tirants
    k.box("brique", ((x0 + x1) / 2, (ys + yn_) / 2, (z0 + zm) / 2), (x1 - x0, yn_ - ys, zm - z0))
    k.caisson("capot", x0 - 0.04, x1 + 0.04, ys - 0.04, yn_ + 0.04, zm, zm + 0.1, pas=0.12, rebord="structure")
    for x in (-1.25, -1.05, -0.35, 0.35, 1.05, 1.25):
        FC.poutre_h(k, x, ys, z0, zm + 0.12, -1)
        FC.poutre_h(k, x, yn_, z0, zm + 0.12, +1)
    for x in (-1.25, -0.35, 0.35, 1.25):
        k.put("acier", geo.tube([(x, ys - 0.08, zm + 0.16), (x, yn_ + 0.08, zm + 0.16)], 0.018, 6))
        for y in (ys - 0.08, yn_ + 0.08):
            k.boulon((x, y, zm + 0.16), (0, 1 if y > 0 else -1, 0), 0.026)
    for x in (x0, x1):
        k.box("structure", (x, (ys + yn_) / 2, zm - 0.05), (0.06, yn_ - ys, 0.06))
    # 2 portes de cornue (sud), lueur
    for x in (-0.7, 0.7):
        FC.porte(k, x, ys, 0.58, 0.46, 0.5)
        k.halo(S, (x, ys - 0.35, 0.55), (1.0, 0.3, 0.05), 4.5, 0.25)
        FC.regard(k, (x, ys - 0.02, 0.98), (0, -1, 0), 0.03)
    # colonnes montantes et barillet
    zb, yb = 1.55, Y(-0.12)
    for x in (-0.7, 0.7):
        k.tuyau("tuyau", [(x, Y(-0.45), zm + 0.1), (x, Y(-0.45), zb - 0.05), (x, yb - 0.12, zb + 0.12)], 0.06, 0.1)
        k.put("structure", geo.tour([(zm + 0.1, 0.11), (zm + 0.2, 0.11), (zm + 0.2, 0.0)], 14, "z", (x, Y(-0.45), 0.0)))
        k.vanne((x, Y(-0.45), zm + 0.45), (0, 0, 1), 0.045, "chrome", "rouge")
    k.put("tuyau", geo.tube([(-1.1, yb, zb), (1.1, yb, zb)], 0.13, 20))
    for x in (-1.1, 1.1):
        k.bride((x, yb, zb), (1 if x > 0 else -1, 0, 0), 0.13)
    for x in (-0.95, 0.0, 0.95):
        k.box("structure", (x, yb, (zm + 0.1 + zb - 0.13) / 2), (0.06, 0.06, zb - 0.13 - zm - 0.1), petite=True)
    for x in (-0.4, 0.4):
        k.bride((x, yb, zb), (1, 0, 0), 0.13, "structure", 8)
    # descente centrale vers la sortie sud (entre les portes), garde hydraulique
    k.tuyau("tuyau", [(0.0, yb - 0.1, zb), (0.0, Y(-1.18), zb), (0.0, Y(-1.18), z0 + 0.03)], 0.075, 0.14)
    k.caisson("capot2", -0.14, 0.14, Y(-1.18) - 0.13, Y(-1.18) + 0.13, 0.42, 0.72, pas=0.08, rebord="structure")
    k.vanne((0.0, Y(-1.18), 0.95), (0, 0, 1), 0.055, "chrome", "rouge")
    # gazomètre (nord-est) et son guide
    xg, yg, rg = 0.86, Y(1.0), 0.3
    k.put("structure", geo.tour([(z0, rg + 0.08), (z0 + 0.25, rg + 0.08), (z0 + 0.25, 0.0)], 32, "z", (xg, yg, 0.0)))
    k.cuve_v("capot2", xg, yg, rg, z0 + 0.25, 0.82, 32, (0.5,), "structure", dome=0.25)
    for i in range(4):
        a = geo.TAU * i / 4 + math.pi / 4
        px, py = xg + (rg + 0.1) * math.cos(a), yg + (rg + 0.1) * math.sin(a)
        k.box("structure", (px, py, (z0 + 1.1) / 2), (0.05, 0.05, 1.1 - z0), petite=True)
        k.box("acier", (px - 0.04 * math.cos(a), py - 0.04 * math.sin(a), 0.86), (0.05, 0.05, 0.06), petite=True)
    k.put("structure", geo.tour([(1.08, rg + 0.13), (1.12, rg + 0.13), (1.12, rg + 0.07), (1.08, rg + 0.07)], 32, "z",
                                (xg, yg, 0.0)))
    k.tuyau("tuyau", [(1.1, yb, zb), (1.2, yb, zb), (1.2, yg, zb), (xg, yg, zb), (xg, yg, 0.95)], 0.06, 0.12, False)
    # cheminée de briques (nord-ouest), bandes de fonte, chapeau
    xs, ys_ = -0.98, Y(0.92)
    a = 0.22
    k.put("brique", geo.prisme([(xs - a, ys_ - a), (xs + a, ys_ - a), (xs + a, ys_ + a), (xs - a, ys_ + a)], z0, 1.84,
                               top_scale=0.72))
    for zz in (0.5, 0.92, 1.34, 1.74):
        s = a * (1.0 - 0.28 * (zz - z0) / (1.84 - z0)) + 0.02
        k.put("structure", geo.prisme([(xs - s, ys_ - s), (xs + s, ys_ - s), (xs + s, ys_ + s), (xs - s, ys_ + s)],
                                      zz - 0.03, zz + 0.03))
    s = a * 0.72 + 0.03
    k.put("capot", geo.prisme([(xs - s, ys_ - s), (xs + s, ys_ - s), (xs + s, ys_ + s), (xs - s, ys_ + s)], 1.84, 1.9))
    k.put("noir", geo.prisme([(xs - s + 0.05, ys_ - s + 0.05), (xs + s - 0.05, ys_ - s + 0.05),
                              (xs + s - 0.05, ys_ + s - 0.05), (xs - s + 0.05, ys_ + s - 0.05)], 1.9, 1.905))
    k.put("brique", geo.prisme([(x0 + 0.1, yn_), (-0.75, yn_), (-0.75, ys_ - a), (x0 + 0.1, ys_ - a)], zm + 0.1, zm + 0.3))
    # arrivée nord dans la face nord du massif
    k.tuyau("tuyau", [(0.0, Y(1.28), z0 + 0.03), (0.0, Y(1.28), 0.7), (0.0, yn_ + 0.06, 0.7)], 0.06, 0.12)
    k.vanne((0.0, Y(1.0), 0.7), (0, 1, 0), 0.05, "chrome", "rouge")
    # outillage : ringard et fût au sud-ouest
    k.put("acier", geo.tube([(-1.32, Y(-1.3), z0 + 0.02), (-1.2, ys - 0.15, 0.9)], 0.018, 6))
    k.box("structure", (1.18, Y(-1.15), z0 + 0.12), (0.22, 0.22, 0.24))
    k.armoire((1.05, ys - 0.05, z0), (0.36, 0.2, 0.5), voyants=(("feu", 0.0),))
