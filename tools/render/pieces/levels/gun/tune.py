"""Réglage des hauteurs de tête (zg) sur l'enveloppe O de la bible §4, POSE PAR POSE, à partir des silhouettes
géométriques (geo.py) ; écrit params.json avec --apply. Écrit aussi une planche de contrôle des silhouettes.

    python tools/render/pieces/levels/gun/tune.py [--apply] [--sheet <png>] [--strict]

O d'une pose = dépassement des MASSES (structures de moins de 10 px hr de large exclues, bible §1.4) au-dessus du
bord haut de l'emprise. O dépend linéairement de zg (la tête monte d'un bloc, le fût s'étire) : 0,707 tuile
d'écran par unité de hauteur.

Règle (reprise 4, 22/10 ; vérification adverse, majeur 1) : avant, zg était réglé sur le seul MAXIMUM des 4 poses,
qui dépend surtout de la pose S (éléments dorsaux) ; pose par pose, la tourelle rapetissait (époque 3 en pose N :
0,55 contre 0,94 à l'époque 2). Désormais, pour chaque époque e = 2..15, dans l'ordre :
  - zg_T = hauteur qui met le maximum des 4 poses sur la cible O(e) de la bible (plafond) ;
  - zg_min = plus petite hauteur telle que O_p(e) ≥ O_p(e-1) pour CHAQUE pose p (O_p(1) = vanilla : plancher) ;
  - on retient zg_T ; si zg_min > zg_T, l'époque est INFAISABLE par zg seul : l'écart entre poses doit être réduit
    par la géométrie (pièce dorsale avancée, pièce frontale ou latérale montée). --strict : code de sortie 3.
Contrôle final : max ≤ cible (+0,005) ET O_p non décroissant pour chaque pose.
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import d1lib as D  # noqa: E402
import gun as G  # noqa: E402

K = math.sqrt(0.5)   # tuile d'écran par unité de hauteur
TOL = 0.005          # tolérance des comparaisons pose par pose (un recul de 1 px hr = 0,016 tuile est un échec)
HALF_PX = 1.0 / 128  # le sommet mesuré est arrondi au pixel (couverture ≥ 0,5) : erreur ≤ 1/2 px hr
AIM = HALF_PX        # on vise la cible MOINS un demi-pixel : le maximum mesuré reste ≤ cible + 1/2 px


def measure():
    """O par pose des 15 niveaux impairs (silhouettes « dry ») et masques pour la planche."""
    per, masks, L = {}, {}, {}
    for e in range(1, 16):
        lv = 2 * e - 1
        per[e], L[e] = {}, 0.0
        for pose in D.POSES:
            m = D.main_alpha(D.level_layers(lv, pose, "dry")) >= 0.5
            masks[(lv, pose)] = m
            mt = D.metrics(m)
            per[e][pose] = mt["O"]
            L[e] = max(L[e], mt["L"])
    return per, masks, L


def plan(per, zg):
    """Hauteurs proposées (zg_T) et contrôle de faisabilité pose par pose, époque après époque."""
    new_zg, new_O, rows = {}, {1: dict(per[1])}, []
    for e in range(2, 16):
        mx = max(per[e].values())
        d_T = (G.O_TARGET[e] - AIM - mx) / K
        d_min = max((new_O[e - 1][p] - per[e][p]) / K for p in D.POSES)
        bind = max(D.POSES, key=lambda p: new_O[e - 1][p] - per[e][p])
        ok = d_min <= d_T + TOL / K
        new_zg[e] = round(zg[e] + d_T, 4)
        new_O[e] = {p: per[e][p] + d_T * K for p in D.POSES}
        rows.append((e, zg[e], new_zg[e], ok, bind, (d_min - d_T) * K))
    return new_zg, new_O, rows


def check(per):
    """max ≤ cible et O non décroissant pose par pose (valeurs mesurées, sans simulation)."""
    bad = []
    for e in range(1, 16):
        if max(per[e].values()) > G.O_TARGET[e] + HALF_PX + 1e-9 or max(per[e].values()) > G.O_PLAFOND + 1e-9:
            bad.append("e%02d max %.3f > cible %.2f" % (e, max(per[e].values()), G.O_TARGET[e]))
        if e > 1:
            for p in D.POSES:
                if per[e][p] < per[e - 1][p] - TOL:
                    bad.append("e%02d pose %s : %.3f < %.3f (e%02d)" % (e, p, per[e][p], per[e - 1][p], e - 1))
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--epochs", default="", help="époques dont zg est réécrit par --apply (défaut : toutes) ; les autres "
                    "gardent leur zg : le sommet mesuré étant arrondi au pixel, un nouveau réglage déplacerait zg de "
                    "±0,02 sans raison et obligerait à refaire leurs rendus")
    ap.add_argument("--sheet", default=os.path.join(D.DRY_DIR, "_silhouettes.png"))
    a = ap.parse_args()
    P = G.load_params()
    per, masks, L = measure()
    print("O mesuré par pose (silhouettes géométriques) :")
    for e in range(1, 16):
        print("e%02d zg=%.4f cible %.2f  max %.3f  N %.3f E %.3f S %.3f O %.3f  L %.2f (max %.2f)" % (
            e, P["zg"][e], G.O_TARGET[e], max(per[e].values()), per[e]["N"], per[e]["E"], per[e]["S"], per[e]["O"],
            L[e], G.L_TARGET[e]))
    bad = check(per)
    print("Contrôle (max ≤ cible, O non décroissant par pose) : %s" % ("OK" if not bad else "ÉCHEC"))
    for b in bad:
        print("   " + b)
    new_zg, new_O, rows = plan(per, P["zg"])
    infeasible = [r for r in rows if not r[3]]
    print("Proposition (max sur la cible) :")
    for e, z0, z1, ok, bind, gap in rows:
        print("e%02d zg %.4f -> %.4f  %s" % (e, z0, z1, "faisable" if ok else
                                              "INFAISABLE par zg seul (pose %s : manque %.3f tuile)" % (bind, gap)))
        print("      O prévu : " + " ".join("%s %.3f" % (p, new_O[e][p]) for p in D.POSES))
    if a.apply:
        path = os.path.join(HERE, "params.json")
        old = {}
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                old = json.load(f)
        only = {int(x) for x in a.epochs.split(",") if x}
        old["zg"] = {str(e): (new_zg[e] if (not only or e in only) else P["zg"][e]) for e in range(2, 16)}
        old["gain"] = {str(e): P["gain"][e] for e in range(1, 16)}
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(old, f, indent=1, sort_keys=True)
        print("params.json mis à jour")
    # planche des silhouettes (impairs, 4 poses) : noir sur blanc, 1 px = 1 px hr / 2
    cells = []
    for pose in D.POSES:
        row = []
        for e in range(1, 16):
            m = masks[(2 * e - 1, pose)]
            crop = m[D.OY - 4 * D.PPT:D.OY + int(1.4 * D.PPT), D.OX - int(1.3 * D.PPT):D.OX + int(1.3 * D.PPT)]
            row.append(crop)
        cells.append(np.concatenate(row, 1))
    sheet = np.concatenate(cells, 0)
    img = Image.fromarray(np.where(sheet, 0, 255).astype(np.uint8), "L")
    img = img.resize((img.width // 2, img.height // 2), Image.BILINEAR)
    img.save(a.sheet)
    print("planche :", a.sheet)
    if a.strict and (infeasible or (bad and not a.apply)):
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
