"""OUTIL COMMUN : vignettes LETTRÉES d'une ronde de lecture (regard naïf, catalogue §C ; passe 5). Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/vignettes.py --dest DOSSIER --src DOSSIER_SPRITES
        [--src 1-9=DOSSIER_1 --src 10-15=DOSSIER_2 …] [--epochs 1,…,15] [--pose E|N] [--gris]

Une image par époque : le bâtiment seul au niveau impair (époque 1 : niveau 2, pièce SOUS la mitrailleuse vanilla),
zoom 1, jour, sol vanilla, cadre carré 384 × 384 (12 tuiles) centré sur l'emprise, pose E (canons à l'est) ou N
(canons au nord), en couleur ou en gris (--gris : luma Rec. 709). Les sprites viennent d'un ou de plusieurs dossiers
de sortie de rendre.py : « --src DOSSIER » sert pour toutes les époques ; « --src 2-9=DOSSIER » ou
« --src 3,7,11=DOSSIER » pour une plage ou une liste (une plage par dossier ; la dernière qui couvre une époque gagne).

Chaque vignette porte une GRANDE LETTRE (A à O) tirée au sort, différente à chaque jeu, sur un cartouche sombre posé
dans le coin le plus vide de l'image (celui qui recouvre le moins de pixels du bâtiment et de son ombre ; s'il en
recouvre, l'outil le dit sur la sortie d'erreur). Contre les fuites de clé :
  - lettres, noms de fichier (8 caractères hexadécimaux) et ORDRE D'ÉCRITURE tirés au sort (tirage du système) ;
  - toutes les images sont calculées d'abord, puis écrites ; même date de modification pour toutes ; PNG sans
    métadonnées ;
  - la CLÉ (lettre, époque, fichier) n'est écrite QUE sur la sortie standard, en JSON, jamais sur le disque. Les
    messages de l'outil vont sur la sortie d'erreur.
"""
import argparse
import json
import os
import secrets
import sys
import time

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402

LETTRES = "ABCDEFGHIJKLMNO"
T = 12.0          # 12 tuiles à 64 px = 768 px, réduits à 384 (zoom 1)
CART = 76         # côté du cartouche (px de la vignette)
MARGE = 6


def sources(specs, eps):
    """--src : [« DOSSIER » | « PLAGE=DOSSIER »] -> {époque: dossier}. Le séparateur est le PREMIER « = » (un chemin
    Windows a des « : », jamais de « = » en tête)."""
    res = {}
    for s in specs:
        if "=" in s and not os.path.isdir(s):
            plage, d = s.split("=", 1)
            sel = set()
            for part in plage.split(","):
                part = part.strip()
                if not part:
                    continue
                if "-" in part:
                    a, b = part.split("-", 1)
                    sel |= set(range(int(a), int(b) + 1))
                else:
                    sel.add(int(part))
        else:
            d, sel = s, set(eps)
        if not os.path.isdir(d):
            raise SystemExit("dossier de sprites introuvable : %s" % d)
        for e in sorted(sel):
            res[e] = d
    manque = [e for e in eps if e not in res]
    if manque:
        raise SystemExit("aucun dossier de sprites pour les époques %s" % manque)
    return res


def rendu(out, e, pose):
    besoin = ["e01-piece"] if e == 1 else ["e%02d-socle" % e, "e%02d-tete-%s" % (e, pose)]
    manque = [n for n in besoin if not K.spec_of(out, n)]
    if manque:
        raise SystemExit("époque %d : sprites absents dans %s : %s" % (e, out, ", ".join(manque)))
    lays = K.level_layers(out, e, pose, e == 1)
    day, _, alpha = K.compose([{"pos": (T / 2, T / 2), "layers": lays}], T, T)
    # emprise du bâtiment ET de son ombre, au zoom 1 (le cartouche ne doit cacher ni l'un ni l'autre)
    ground, _, _ = K.compose([{"pos": (T / 2, T / 2), "layers": []}], T, T)
    occ = (alpha > 0.02) | (np.abs(day - ground).max(-1) > 0.03)
    occ = occ.reshape(occ.shape[0] // 2, 2, occ.shape[1] // 2, 2).any(axis=(1, 3))
    return K.down2(day), occ


def coin(occ):
    """Coin du cartouche : celui qui recouvre le moins de pixels occupés (ordre de préférence à égalité : haut gauche,
    haut droite, bas gauche, bas droite)."""
    n = occ.shape[0]
    best = None
    for nom, (x0, y0) in (("haut-gauche", (MARGE, MARGE)), ("haut-droite", (n - MARGE - CART, MARGE)),
                          ("bas-gauche", (MARGE, n - MARGE - CART)), ("bas-droite", (n - MARGE - CART, n - MARGE - CART))):
        c = int(occ[y0:y0 + CART, x0:x0 + CART].sum())
        if best is None or c < best[0]:
            best = (c, nom, x0, y0)
    return best


def lettrer(img, lettre, x0, y0):
    dr = ImageDraw.Draw(img)
    dr.rounded_rectangle((x0, y0, x0 + CART - 1, y0 + CART - 1), radius=10, fill=(14, 14, 18), outline=(250, 250, 250),
                         width=3)
    f = K.font(62)
    bb = dr.textbbox((0, 0), lettre, font=f)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    dr.text((x0 + (CART - w) / 2 - bb[0], y0 + (CART - h) / 2 - bb[1]), lettre, fill=(255, 255, 255), font=f)
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--src", action="append", required=True)
    ap.add_argument("--epochs", default="1,2,3,4,5,6,7,8,9,10,11,12,13,14,15")
    ap.add_argument("--pose", default="E", choices=("E", "N"))
    ap.add_argument("--gris", action="store_true")
    a = ap.parse_args()
    eps = [int(x) for x in a.epochs.split(",") if x]
    if len(eps) > len(LETTRES):
        raise SystemExit("au plus %d vignettes par jeu" % len(LETTRES))
    src = sources(a.src, eps)
    os.makedirs(a.dest, exist_ok=True)
    if any(f.lower().endswith(".png") for f in os.listdir(a.dest)):
        raise SystemExit("le dossier %s contient déjà des vignettes : un jeu par dossier" % a.dest)
    rnd = secrets.SystemRandom()
    lettres = rnd.sample(LETTRES, len(eps))
    imgs = {}
    for e, lt in zip(eps, lettres):
        rgb, occ = rendu(src[e], e, a.pose)
        if a.gris:
            rgb = K.grey(rgb)
        img = K.to_im(rgb)
        assert img.size == (384, 384), img.size
        cache, nom, x0, y0 = coin(occ)
        if cache:
            print("attention : la vignette %s cache %d px du bâtiment ou de son ombre (coin %s)" % (lt, cache, nom),
                  file=sys.stderr)
        imgs[e] = (lt, lettrer(img, lt, x0, y0))
    t_fixe = time.mktime((2026, 1, 1, 12, 0, 0, 0, 1, -1))
    order = list(eps)
    rnd.shuffle(order)
    cle = []
    for e in order:
        lt, img = imgs[e]
        while True:
            name = secrets.token_hex(4) + ".png"
            p = os.path.join(a.dest, name)
            if not os.path.exists(p):
                break
        img.save(p, optimize=False)
        os.utime(p, (t_fixe, t_fixe))
        cle.append({"lettre": lt, "epoque": e, "niveau": 2 if e == 1 else 2 * e - 1, "fichier": os.path.abspath(p)})
    cle.sort(key=lambda r: r["lettre"])
    print("%d vignettes (pose %s, %s) dans %s" % (len(cle), a.pose, "gris" if a.gris else "couleur", a.dest),
          file=sys.stderr)
    print(json.dumps({"pose": a.pose, "gris": a.gris, "dossier": os.path.abspath(a.dest), "cle": cle},
                     ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
