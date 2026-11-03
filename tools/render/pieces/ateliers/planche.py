"""PLANCHE D'ÉTATS CLÉS des bâtiments d'atelier (kit ateliers, lot DA-ATELIERS), COPIE adaptée de calcul_o/planche.py : une
rangée par bâtiment, d'abord le visuel ACTUEL en jeu (sprite vanilla mis à l'échelle et teinté comme prototypes/crafts.lua :
lib.scale_sprites, lib.tint_sprites), puis les variantes a, b, c. Même sol, même échelle, ombres et lueur composées comme en
jeu (levels/commun/compo.py). Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/ateliers/planche.py --src DIR --dest planche.png [--zoom 1|2] [--nuit]
        [--batiments concasseur,machoires,bobineuse,torchere,taillerie] [--variantes a,b,c]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "levels", "commun"))
import compo as K  # noqa: E402

ENT = os.path.join(K.DATA, "base", "graphics", "entity")
# sprites vanilla : (fichier, rectangle de la 1re image, shift en px du jeu (32/tuile), ombre, rectangle, shift)
VAN = {
    "assembleur1": ("assembling-machine-1/hr-assembling-machine-1.png", (0, 0, 214, 226), (0, 2),
                    "assembling-machine-1/hr-assembling-machine-1-shadow.png", (0, 0, 190, 165), (8.5, 5)),
    "assembleur2": ("assembling-machine-2/hr-assembling-machine-2.png", (0, 0, 214, 218), (0, 4),
                    "assembling-machine-2/hr-assembling-machine-2-shadow.png", (0, 0, 196, 163), (12, 4.75)),
}
sys.path.insert(0, HERE)
import piece as PC  # noqa: E402
# visuel actuel (prototypes/crafts.lua + shared/content/crafts.lua) : modèle vanilla, facteur d'échelle, teinte
ACTUEL = {
    "concasseur": ("assembleur1", 2.0 / 3.0, (0.78, 0.70, 0.58)),
    "machoires": ("assembleur2", 1.0, (0.70, 0.72, 0.80)),
    "bobineuse": ("assembleur2", 2.0 / 3.0, (0.98, 0.80, 0.55)),
    "torchere": ("assembleur1", 2.0 / 3.0, (1.00, 0.55, 0.40)),
    "taillerie": ("assembleur2", 1.0, (0.62, 0.86, 1.00)),
}
NOMS = {"concasseur": "Concasseur fo-crusher", "machoires": "Broyeur à mâchoires fo-jaw-crusher", "bobineuse": "Bobineuse fo-coil-winder",
        "torchere": "Torchère fo-flare-stack", "taillerie": "Taillerie fo-lapidary"}
TITRE_V = {"a": "a : référence", "b": "b : plus chargée", "c": "c : autre parti"}


def _png(rel, rect, k=1.0, tint=None):
    im = Image.open(os.path.join(ENT, rel)).convert("RGBA").crop(rect)
    if k != 1.0:
        im = im.resize((max(1, int(round(im.size[0] * k))), max(1, int(round(im.size[1] * k)))), Image.LANCZOS)
    a = np.asarray(im).astype(np.float64) / 255.0
    if tint is not None:
        a[..., :3] = a[..., :3] * np.array(tint)
    return a


def couches(src, nom):
    if nom.startswith("van:"):
        bat = nom[4:]
        mod, k, tint = ACTUEL[bat]
        f, r, sh, fs, rs, shs = VAN[mod]
        return [{"img": _png(fs, rs, k), "shift": (shs[0] * k / 32.0, shs[1] * k / 32.0), "kind": "shadow"},
                {"img": _png(f, r, k, tint), "shift": (sh[0] * k / 32.0, sh[1] * k / 32.0), "kind": "main"}]
    return K.own(src, nom, ("shadow", "main", "glow", "light"))


def cote(nom):
    bat = nom[4:] if nom.startswith("van:") else nom.rsplit("_", 1)[0]
    return PC.BATIMENTS[bat][1]


def titre(nom, court=False):
    if nom.startswith("van:"):
        if court:
            return "actuel (vanilla teinté)"
        return "actuel : %s ×%s teinté" % (ACTUEL[nom[4:]][0], "2/3" if ACTUEL[nom[4:]][1] < 1 else "1")
    return TITRE_V[nom.rsplit("_", 1)[1]].split(" :")[0] if court else TITRE_V[nom.rsplit("_", 1)[1]]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--batiments", default="concasseur,machoires,bobineuse,torchere,taillerie")
    ap.add_argument("--variantes", default="a,b,c")
    ap.add_argument("--zoom", type=int, default=2, choices=(1, 2))
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--titre", default="")
    a = ap.parse_args()
    bats = [b for b in a.batiments.split(",") if b]
    vs = [v for v in a.variantes.split(",") if v]
    ppt = 64 if a.zoom == 2 else 32
    CW, gap, hd, lab, rh = 5.0, 6, 40, 24, 22
    HT = {"torchere": 8.6}
    OY = {"torchere": 6.4}
    W = int(len(vs) + 1) * (int(CW * ppt) + gap) + gap
    rows = []
    for b in bats:
        ht = HT.get(b, 6.4)
        rows.append((b, ht, OY.get(b, 4.3)))
    H = hd + sum(rh + int(ht * ppt) + lab + gap for _, ht, _ in rows)
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), a.titre or "DA-ATELIERS · états clés · zoom %d · %s · à gauche : visuel actuel en jeu (même échelle)"
            % (a.zoom, "nuit" if a.nuit else "jour"), fill=(255, 205, 120), font=K.font(22 if a.zoom == 2 else 15))
    y = hd
    for b, ht, oy in rows:
        dr.text((10, y + 2), "%s · %d×%d" % (NOMS[b], cote("van:" + b), cote("van:" + b)), fill=(255, 225, 160),
                font=K.font(18 if a.zoom == 2 else 13))
        y += rh
        x = gap
        for nom in ["van:" + b] + ["%s_%s" % (b, v) for v in vs]:
            day, night, _ = K.compose([{"pos": (CW / 2.0, oy), "layers": couches(a.src, nom)}], CW, ht)
            img = night if a.nuit else day
            if a.zoom == 1:
                img = K.down2(img)
            sheet.paste(K.to_im(img), (x, y))
            dr.text((x + 6, y + int(ht * ppt) + 3), titre(nom, a.zoom == 1), fill=(235, 235, 235), font=K.font(16 if a.zoom == 2 else 11))
            x += int(CW * ppt) + gap
        y += int(ht * ppt) + lab + gap
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest, optimize=True)
    print(a.dest, sheet.size, "%.2f Mo" % (os.path.getsize(a.dest) / 1e6))


if __name__ == "__main__":
    main()
