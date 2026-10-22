"""Vignettes du test à l'aveugle (lot V3-E) : une image par époque, le bâtiment seul (niveau impair de l'époque ;
époque 1 : niveau 2), zoom 1, jour, pose E, sol vanilla, cadre carré 384 × 384 centré sur l'emprise, sans légende ni
chiffre. Nom de fichier ALÉATOIRE (8 caractères hexadécimaux tirés par le système).
Troisième passe : les mêmes vignettes en niveaux de gris (luma Rec. 709) dans un second dossier, avec un AUTRE tirage
de noms et un autre ordre (exigence (d), test noir et blanc).

    py -3.9 tools/render/pieces/levels/gun_e_bas/vignettes_e.py <dossier out> <dossier vignettes>
           [--gris <dossier vignettes en gris>] [--epochs 1,...,9]

La correspondance (fichier -> époque, niveau) n'est écrite NULLE PART sur le disque : elle n'est imprimée que sur la
sortie standard, pour la valeur de retour de l'agent. Ne pas rediriger cette sortie vers un fichier.
"""
import argparse
import os
import secrets
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402


def render(out, e):
    lays = K.level_layers(out, e, "E", e == 1)
    T = 12.0  # 12 tuiles à 64 px = 768 px, réduits à 384 (zoom 1)
    day, _ = K.compose([{"pos": (T / 2, T / 2), "layers": lays}], T, T)
    return K.down2(day)


def save(rgb, dest, grey):
    if grey:
        g = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
        rgb = np.stack([g, g, g], -1)
    img = K.to_im(rgb)
    assert img.size == (384, 384), img.size
    while True:
        name = secrets.token_hex(4) + ".png"
        p = os.path.join(dest, name)
        if not os.path.exists(p):
            break
    img.save(p)
    return os.path.abspath(p).replace("\\", "/")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("dest")
    ap.add_argument("--gris", default="")
    ap.add_argument("--epochs", default="1,2,3,4,5,6,7,8,9")
    a = ap.parse_args()
    eps = [int(x) for x in a.epochs.split(",") if x]
    imgs = {e: render(a.out, e) for e in eps}
    rnd = secrets.SystemRandom()
    for dest, grey in ((a.dest, False), (a.gris, True)):
        if not dest:
            continue
        os.makedirs(dest, exist_ok=True)
        order = list(eps)
        rnd.shuffle(order)
        for e in order:
            p = save(imgs[e], dest, grey)
            print("%s\t%s\tepoque=%d\tniveau=%d" % ("gris" if grey else "couleur", p, e, 2 if e == 1 else 2 * e - 1))


if __name__ == "__main__":
    main()
