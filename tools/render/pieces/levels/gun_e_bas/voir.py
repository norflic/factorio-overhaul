"""Aperçus de travail groupés (lot V3-E) : une image par groupe d'époques, zoom 2 (64 px/tuile), jour.

    py -3.9 voir.py <dossier out> <dossier sortie> <préfixe> [--pose E] [--groups 2,3/4,5/6/7/8/9] [--even] [--night]
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("dest")
    ap.add_argument("prefix")
    ap.add_argument("--pose", default="E")
    ap.add_argument("--groups", default="2,3/4,5/6/7/8/9")
    ap.add_argument("--even", action="store_true")
    ap.add_argument("--both", action="store_true")
    ap.add_argument("--night", action="store_true")
    ap.add_argument("--zoom", type=int, default=2)
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for grp in a.groups.split("/"):
        eps = [int(x) for x in grp.split(",") if x]
        items = []
        for e in eps:
            items += [(e, False), (e, True)] if a.both else [(e, a.even or e == 1)]
        ents, x, H = [], 0.6, 0
        for e, ev in items:
            side = K.SIDE[e]
            x += side / 2.0
            ents.append({"pos": [x, 0.0], "layers": K.level_layers(a.out, e, a.pose, ev)})
            x += side / 2.0 + 1.0
            H = max(H, side)
        Ht = H + 2.4
        for en in ents:
            en["pos"][1] = 1.4 + H / 2.0
        day, night = K.compose(ents, x + 0.6, Ht)
        img = night if a.night else day
        if a.zoom == 1:
            img = K.down2(img)
        p = os.path.join(a.dest, "%s_%s.png" % (a.prefix, grp.replace(",", "-")))
        K.to_im(img).save(p)
        print(p)


if __name__ == "__main__":
    main()
