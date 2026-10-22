"""Aperçu de travail (lot V3-E) : époques côte à côte sur sol vanilla, zoom 2 et zoom 1, jour (et nuit).

    py -3.9 apercu.py <dossier out> <sortie.png> --epochs 2,3 [--pose E] [--even] [--zoom 2] [--night]
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
    ap.add_argument("png")
    ap.add_argument("--epochs", default="2")
    ap.add_argument("--pose", default="E")
    ap.add_argument("--even", action="store_true")
    ap.add_argument("--both", action="store_true", help="impair puis pair pour chaque époque")
    ap.add_argument("--zoom", type=int, default=2)
    ap.add_argument("--night", action="store_true")
    ap.add_argument("--vanilla", action="store_true")
    a = ap.parse_args()
    eps = [int(x) for x in a.epochs.split(",") if x]
    ents = []
    x = 1.0
    H = 0
    items = []
    if a.vanilla:
        items.append((1, False))
    for e in eps:
        if a.both:
            items += [(e, False), (e, True)]
        else:
            items.append((e, a.even))
    for e, ev in items:
        side = K.SIDE[e]
        x += side / 2.0 + 0.3
        ents.append({"pos": (x, 0.0), "layers": K.level_layers(a.out, e, a.pose, ev)})
        x += side / 2.0 + 0.9
        H = max(H, side)
    Ht = H + 3.0
    for en in ents:
        en["pos"] = (en["pos"][0], Ht - 1.0 - H / 2.0 + 0.4)
    day, night = K.compose(ents, x + 1.0, Ht)
    img = night if a.night else day
    if a.zoom == 1:
        img = K.down2(img)
    K.to_im(img).save(a.png)
    print(a.png)


if __name__ == "__main__":
    main()
