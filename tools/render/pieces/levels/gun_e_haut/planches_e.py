"""Planches du lot V3-E, époques 10 à 15 (mitrailleuse), composées hors moteur sur le sol vanilla (hr-dirt-4),
même méthode que planche.py (ombres, principal, lueur additive, halo ; nuit = LUT de game.frag, approximation).

    py -3.9 tools/render/pieces/levels/gun_e_haut/planches_e.py <racine>/data <dumps --dump-proto> <outils charte>
           <dossier planches> [--vignettes <dossier>]

(a) planche-a-epoques-zoom1-{jour,nuit}-E.png : les 6 époques (niveau impair) côte à côte, pose E, zoom 1, avec la
    mitrailleuse vanilla et le réacteur nucléaire en repère ; légende « époque N · nom · emprise ».
(b) planche-b-epoques-zoom1-jour-N.png : la même en pose N, de jour.
(c) planche-c-canons-zoom2-jour-E.png (et -N) : gros plan des canons de chaque époque, zoom 2 (64 px/tuile, 1:1).
(d) planche-d-impair-pair-zoom1-jour-E.png : niveau impair contre niveau pair, par époque, zoom 1 ; et
    planche-d-pieces-zoom2-jour-E.png : bande avant (coins avant) des deux niveaux, zoom 2.
--vignettes : une image par époque, bâtiment seul, zoom 1, jour, pose E, 384 × 384 centrée, sans légende, nom
    aléatoire (8 caractères hexadécimaux) ; la correspondance est imprimée sur la sortie standard SEULEMENT.
"""
import argparse
import os
import secrets
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import planche as PL  # noqa: E402

NAME = {10: "Haute technologie", 11: "Titane", 12: "Supraconducteurs", 13: "Fusion", 14: "Orbite", 15: "Légende"}
SIDE = PL.SIDES
EP = (10, 11, 12, 13, 14, 15)


def ent(e, pose, piece=False):
    socle = "e%02d-socle%s" % (e, "-piece" if piece else "")
    return PL.own(socle) + PL.own("e%02d-tete-%s" % (e, pose))


def row_board(data, refs, pose, piece=False, title="", paths=(), night_path=None, gap=1.6):
    ents = []
    x = 1.0
    yf = 7.2
    for lab, lays, side in refs:
        x += side / 2.0
        ents.append({"pos": (x, yf), "layers": lays, "lab": lab, "side": side})
        x += side / 2.0 + gap
    for e in EP:
        side = SIDE[e]
        x += side / 2.0
        lvl = 2 * e - 1 + (1 if piece else 0)
        ents.append({"pos": (x, yf), "layers": ent(e, pose, piece),
                     "lab": ["époque %d" % e, NAME[e], "%d×%d · niveau %d" % (side, side, lvl)], "side": side})
        x += side / 2.0 + gap
    W, H = x + 0.5, yf + 4.6
    day, night = PL.compose(data, ents, W, H)
    labels = [(((e["pos"][0] - e["side"] / 2.0) * 64, (e["pos"][1] + e["side"] / 2.0 + 0.35) * 64), e["lab"])
              for e in ents]
    PL.board(PL.down2(day), labels, title + " · jour", paths[0], 0.5)
    if night_path:
        PL.board(PL.down2(night), labels, title + " · nuit (LUT de game.frag, hors moteur)", night_path, 0.5)


def canons(data, out, pose):
    """Gros plan zoom 2 : la tête et ses canons, sur le socle, cadrage fixe par époque."""
    tiles = []
    for e in EP:
        side = SIDE[e]
        c = side / 2.0 + 1.5
        W = H = side + 3.0
        day, _ = PL.compose(data, [{"pos": (c, c), "layers": ent(e, pose)}], W, H)
        if pose == "E":
            box = (c - 0.3 * side, c - 0.74 * side, c + 0.8 * side + 0.3, c + 0.12 * side)
        else:
            box = (c - 0.58 * side, c - 0.98 * side - 0.3, c + 0.58 * side, c - 0.02 * side)
        x0, y0, x1, y1 = [int(round(v * 64)) for v in box]
        crop = day[max(0, y0):y1, max(0, x0):x1]
        tiles.append((e, PL.to_im(crop)))
    cols = 2
    cw = max(t.width for _, t in tiles)
    ch = max(t.height for _, t in tiles) + 26
    sheet = Image.new("RGB", (cols * cw + (cols + 1) * 8, 34 + 3 * ch + 4 * 8), (22, 22, 22))
    d = ImageDraw.Draw(sheet)
    d.text((8, 8), "Canons des époques 10 à 15 · zoom 2 (64 px par tuile, 1:1) · jour · pose %s · composé hors moteur" % pose,
           fill=(235, 235, 235), font=PL.FONTB)
    for i, (e, t) in enumerate(tiles):
        cx, cy = 8 + (i % cols) * (cw + 8), 34 + 8 + (i // cols) * (ch + 8)
        sheet.paste(t, (cx, cy + 26))
        d.text((cx + 2, cy + 4), "époque %d · %s · %d×%d" % (e, NAME[e], SIDE[e], SIDE[e]), fill=(240, 230, 200),
               font=PL.FONTB)
    p = os.path.join(out, "planche-c-canons-zoom2-jour-%s.png" % pose)
    sheet.save(p, optimize=True)
    return p


def pairs(data, out):
    ents = []
    x = 1.0
    yf = 4.0
    rows = ((10, 11, 12), (13, 14, 15))
    labels = []
    for r, row in enumerate(rows):
        x = 1.0
        y = yf + r * 9.5
        for e in row:
            side = SIDE[e]
            for piece in (False, True):
                x += side / 2.0
                lvl = 2 * e - 1 + (1 if piece else 0)
                ents.append({"pos": (x, y), "layers": ent(e, "E", piece), "side": side})
                lab = ["ép. %d · %s" % (e, NAME[e]), "niv. %d%s" % (lvl, " (+ pièce paire)" if piece else "")]
                labels.append((((x - side / 2.0) * 64, (y + side / 2.0 + 0.35) * 64), lab))
                x += side / 2.0 + (0.6 if not piece else 1.8)
    W, H = x + 0.5, yf + 9.5 + 4.6
    day, _ = PL.compose(data, ents, W, H)
    p1 = PL.board(PL.down2(day), labels, "Niveau impair contre niveau pair (pièce paire aux coins avant) · zoom 1 · jour · pose E",
                  os.path.join(out, "planche-d-impair-pair-zoom1-jour-E.png"), 0.5)
    # bande avant à zoom 2
    tiles = []
    for e in EP:
        side = SIDE[e]
        c = side / 2.0 + 1.5
        row = []
        for piece in (False, True):
            day, _ = PL.compose(data, [{"pos": (c, c), "layers": ent(e, "E", piece)}], side + 3.0, side + 3.0)
            x0, x1 = int((c - side / 2.0 - 0.3) * 64), int((c + side / 2.0 + 0.3) * 64)
            y0, y1 = int((c + side / 2.0 - 1.7) * 64), int((c + side / 2.0 + 0.6) * 64)
            row.append(PL.to_im(day[y0:y1, x0:x1]))
        tiles.append((e, row))
    cw = max(r[0].width for _, r in tiles)
    ch = max(r[0].height for _, r in tiles) + 24
    sheet = Image.new("RGB", (2 * cw + 3 * 8, 34 + 6 * (ch + 8)), (22, 22, 22))
    d = ImageDraw.Draw(sheet)
    d.text((8, 8), "Pièce du niveau pair : bande avant du socle, zoom 2 · jour · à gauche niveau impair, à droite niveau pair",
           fill=(235, 235, 235), font=PL.FONTB)
    for i, (e, row) in enumerate(tiles):
        cy = 34 + i * (ch + 8)
        for j, t in enumerate(row):
            cx = 8 + j * (cw + 8)
            sheet.paste(t, (cx, cy + 24))
            d.text((cx + 2, cy + 3), "époque %d · %s · niveau %d" % (e, NAME[e], 2 * e - 1 + j), fill=(240, 230, 200),
                   font=PL.FONT)
    p2 = os.path.join(out, "planche-d-pieces-zoom2-jour-E.png")
    sheet.save(p2, optimize=True)
    return [p1, p2]


def vignettes(data, out):
    os.makedirs(out, exist_ok=True)
    res = []
    for e in EP:
        day, _ = PL.compose(data, [{"pos": (6.0, 6.0), "layers": ent(e, "E")}], 12.0, 12.0)
        im = PL.to_im(PL.down2(day))
        assert im.size == (384, 384), im.size
        while True:
            name = secrets.token_hex(4) + ".png"
            if not os.path.exists(os.path.join(out, name)):
                break
        p = os.path.join(out, name)
        im.save(p)
        res.append((e, 2 * e - 1, p))
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("data")
    ap.add_argument("dumps")
    ap.add_argument("outils")
    ap.add_argument("out")
    ap.add_argument("--vignettes", default="")
    ap.add_argument("--only", default="abcd")
    a = ap.parse_args()
    sys.path.insert(0, a.outils)
    import da_lib as D
    os.makedirs(a.out, exist_ok=True)
    files = []
    for pose in ("E", "N"):
        if pose == "N" and "b" not in a.only:
            continue
        if pose == "E" and "a" not in a.only:
            continue
        gun = PL.vanilla(D, a.dumps, a.data, "ammo-turret_gun-turret",
                         lambda d: [(d["base_picture"], 0, None), (d["prepared_animation"], 0 if pose == "N" else pose,
                                                                   None)])
        reactor = PL.vanilla(D, a.dumps, a.data, "reactor_nuclear-reactor",
                             lambda d: [(d["lower_layer_picture"], 0, None), (d["picture"], 0, None),
                                        (d["working_light_picture"], 0, "light")])
        refs = [(["mitrailleuse vanilla", "2×2 (niveau 1)"], gun, 2), (["réacteur vanilla", "5×5"], reactor, 5)]
        if pose == "E":
            pj = os.path.join(a.out, "planche-a-epoques-zoom1-jour-E.png")
            pn = os.path.join(a.out, "planche-a-epoques-zoom1-nuit-E.png")
            row_board(a.data, refs, "E", title="Mitrailleuse, époques 10 à 15 (niveaux impairs) · zoom 1 · pose E",
                      paths=(pj,), night_path=pn)
            files += [pj, pn]
        else:
            pj = os.path.join(a.out, "planche-b-epoques-zoom1-jour-N.png")
            row_board(a.data, refs, "N", title="Mitrailleuse, époques 10 à 15 (niveaux impairs) · zoom 1 · pose N",
                      paths=(pj,))
            files.append(pj)
    if "c" in a.only:
        files.append(canons(a.data, a.out, "E"))
        files.append(canons(a.data, a.out, "N"))
    if "d" in a.only:
        files += pairs(a.data, a.out)
    print("\n".join(files))
    if a.vignettes:
        for e, lvl, p in vignettes(a.data, a.vignettes):
            print("VIGNETTE epoque=%d niveau=%d %s" % (e, lvl, p))


if __name__ == "__main__":
    main()
