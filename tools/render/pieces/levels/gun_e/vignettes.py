"""OUTIL COMMUN : vignettes du test à l'aveugle (regard naïf, catalogue §C). FICHIER GELÉ. Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/vignettes.py --out DIR --dest DOSSIER --gris DOSSIER_GRIS
        [--cle FICHIER_HORS_DES_DOSSIERS] [--epochs 1,…,15]

Une image par époque : le bâtiment seul au niveau impair (époque 1 : niveau 2), zoom 1, jour, pose E, sol vanilla,
cadre carré 384 × 384 centré sur l'emprise, sans légende. Couleur dans --dest, gris (luma Rec. 709) dans --gris.
Défaut de la passe 3 corrigé (clé compromise : vignettes écrites dans l'ordre des époques) :
  - toutes les images sont calculées D'ABORD, puis écrites dans un ORDRE TIRÉ AU SORT (tirage du système), différent
    pour la couleur et pour le gris ;
  - NOMS ALÉATOIRES (8 caractères hexadécimaux) ;
  - dates de modification identiques pour toutes ; la date de création (que Windows ne permet pas de fixer) ne suit
    que l'ordre tiré au sort ;
  - PNG sans métadonnées.
La correspondance (fichier -> époque) n'est écrite NULLE PART dans les dossiers des vignettes : sur la sortie
standard, ou dans --cle (un fichier qu'on ne montre pas au regard naïf, hors de ces dossiers).
"""
import argparse
import os
import secrets
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402


def rendu(out, e):
    lays = K.level_layers(out, e, "E", e == 1)
    T = 12.0  # 12 tuiles à 64 px = 768 px, réduits à 384 (zoom 1)
    day, _, _ = K.compose([{"pos": (T / 2, T / 2), "layers": lays}], T, T)
    return K.down2(day)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--gris", required=True)
    ap.add_argument("--cle", default="")
    ap.add_argument("--epochs", default="1,2,3,4,5,6,7,8,9,10,11,12,13,14,15")
    a = ap.parse_args()
    eps = [int(x) for x in a.epochs.split(",") if x]
    if a.cle and os.path.abspath(os.path.dirname(a.cle)) in (os.path.abspath(a.dest), os.path.abspath(a.gris)):
        raise SystemExit("la clé ne doit pas être dans un dossier de vignettes")
    imgs = {e: rendu(a.out, e) for e in eps}
    rnd = secrets.SystemRandom()
    t_fixe = time.mktime((2026, 1, 1, 12, 0, 0, 0, 1, -1))
    lignes = []
    for dest, grey in ((a.dest, False), (a.gris, True)):
        os.makedirs(dest, exist_ok=True)
        order = list(eps)
        rnd.shuffle(order)
        for e in order:
            rgb = K.grey(imgs[e]) if grey else imgs[e]
            img = K.to_im(rgb)
            assert img.size == (384, 384), img.size
            while True:
                name = secrets.token_hex(4) + ".png"
                p = os.path.join(dest, name)
                if not os.path.exists(p):
                    break
            img.save(p, optimize=False)
            os.utime(p, (t_fixe, t_fixe))
            lignes.append("%s\t%s\tepoque=%d\tniveau=%d" % ("gris" if grey else "couleur", os.path.abspath(p), e,
                                                             2 if e == 1 else 2 * e - 1))
    if a.cle:
        open(a.cle, "w", encoding="utf-8").write("\n".join(sorted(lignes)) + "\n")
        print("clé écrite :", a.cle)
    else:
        print("\n".join(sorted(lignes)))


if __name__ == "__main__":
    main()
