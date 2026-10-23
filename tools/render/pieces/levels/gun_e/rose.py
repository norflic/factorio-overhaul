"""Lot A1 (23/10) : planches de la ROSE DES DIRECTIONS de la mitrailleuse (8 directions par âge, composées sur le socle).
Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/rose.py --tetes DOSSIER_ROSE --socles 1-12=DOSSIER --socles 13-15=DOSSIER
        --dest DOSSIER [--zoom 1|2] [--ages 1,2,3] [--nom planche.png] [--titre "…"]

Une ligne par âge (niveau impair ; âge 1 : niveau 2 = pièce e01-piece SOUS la mitrailleuse vanilla, tête vanilla à
l'image 8·j de ses 64 directions), une colonne par direction N, NE, E, SE, S, SO, O, NO = têtes eNN-tete-d00 … d56
(rendre.py --dirs rose). Jour, sol vanilla, composition hors moteur de compo.py (ombres, lueur additive), zoom 1
(32 px par tuile) ou 2 (64 px). Fenêtre carrée de (côté + 6) tuiles : la plus grande des âges de la planche, ou
celle de chaque âge avec --fenetre-par-age (colonnes calées sur la plus grande).

ATTENTION, convention du moteur (lot A1, E70, captures) : les images dKK sont des rotations UNIFORMES du modèle 3D
(K x 360/64 degrés) ; le moteur choisit l'image par apply_projection (vrai par défaut) : pour une cible au nord-est
du monde, il dessine d06, pas d08. La colonne « NE » montre donc l'image d08 telle qu'elle sera dessinée, pour une
cible à environ 54,7 degrés du nord (atan(tan 45 / cos 45)) ; le nord, l'est, le sud et l'ouest coïncident.

Sortie : la planche PNG, et <nom>.tsv : par âge et direction, part de la couche principale du socle (alpha) que la
couche principale de la tête recouvre (« la tête cache le socle »), et hauteur et largeur de la tête à l'écran.
"""
import argparse
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
# lot K0 (fusion INT-K0) : compo.py et les outils communs sont dans ../commun ; gun_e reste devant
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402
import piece  # noqa: E402

COLS = piece.ROSE


def nom_age(e):
    """Nom de l'époque lu dans epNN.py (« NOM = "…" », sans importer Blender) ; en dernier recours compo.NAME, qui
    suit commun/ages.NOMS (ère V cosmique : 13 Antimatière, 14 La Porte, 15 Néant, depuis le lot K0)."""
    p = os.path.join(HERE, "ep%02d.py" % e)
    if os.path.exists(p):
        for ln in open(p, encoding="utf-8"):
            m = re.match(r'^NOM\s*=\s*"([^"]+)"', ln)
            if m:
                return m.group(1)
    return K.NAME[e]


def sources(specs):
    res = {}
    for s in specs:
        plage, d = s.split("=", 1)
        a, b = plage.split("-") if "-" in plage else (plage, plage)
        for e in range(int(a), int(b) + 1):
            res[e] = d
    return res


def couches(e, dkk, j, tetes, socles):
    """(socle, tête) : listes de couches compo ; âge 1 : pièce + base vanilla, tête vanilla image 8·j."""
    if e == 1:
        van = K.vanilla("ammo-turret_gun-turret", lambda d: [(d["base_picture"], 0, None)], "gun-base")
        tete = K.vanilla("ammo-turret_gun-turret", lambda d: [(d["prepared_animation"], 8 * j, None)], "gun-t%d" % (8 * j))
        return K.own(socles[1], "e01-piece") + list(van), list(tete)
    soc = K.own(socles[e], "e%02d-socle" % e)
    tete = K.own(tetes, "e%02d-tete-%s" % (e, dkk))
    if not soc or not tete:
        raise SystemExit("âge %d, %s : sprites absents (socle %d couches, tête %d couches)" % (e, dkk, len(soc), len(tete)))
    return soc, tete


def alpha_de(lays, T):
    _, _, a = K.compose([{"pos": (T / 2, T / 2), "layers": [l for l in lays if l["kind"] == "main"]}], T, T,
                        ground=False)
    return a


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tetes", required=True)
    ap.add_argument("--socles", action="append", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--zoom", type=int, default=1, choices=(1, 2))
    ap.add_argument("--ages", default="1,2,3")
    ap.add_argument("--nom", default="")
    ap.add_argument("--titre", default="")
    ap.add_argument("--fenetre-par-age", action="store_true",
                    help="fenêtre de (côté + 6) tuiles PAR ÂGE (sinon la plus grande pour toute la planche)")
    a = ap.parse_args()
    S = sources(a.socles)
    ages = [int(x) for x in a.ages.split(",") if x]
    Tmax = max(K.SIDE[e] for e in ages) + 6
    Tage = {e: (K.SIDE[e] + 6 if a.fenetre_par_age else Tmax) for e in ages}
    cell = int(Tmax * 32 * a.zoom)
    hcell = {e: int(Tage[e] * 32 * a.zoom) for e in ages}
    head_h, lab_w, gap = 56, 150, 6
    W = lab_w + len(COLS) * (cell + gap)
    H = head_h + sum(hcell[e] + gap for e in ages) + 30
    plate = Image.new("RGB", (W, H), (24, 24, 28))
    dr = ImageDraw.Draw(plate)
    f, fs = K.font(18), K.font(14, bold=False)
    titre = a.titre or ("Rose des directions, âges %s, zoom %d (jour, hors moteur, aperçu 32 échantillons)"
                        % (", ".join(map(str, ages)), a.zoom))
    dr.text((8, 8), titre, font=f, fill=(235, 235, 235))
    for c, (bou, dkk) in enumerate(COLS):
        dr.text((lab_w + c * (cell + gap) + 6, head_h - 18), "%s (%s)" % (bou, dkk), font=fs, fill=(220, 220, 220))
    lignes = ["age\tdirection\timage\tsocle_recouvert_par_tete\ttete_largeur_px_z1\ttete_hauteur_px_z1"]
    y0 = head_h
    for r, e in enumerate(ages):
        T, ce = Tage[e], hcell[e]
        if r:
            y0 += hcell[ages[r - 1]] + gap
        dr.text((8, y0 + 8), "Âge %d" % e, font=f, fill=(235, 235, 235))
        dr.text((8, y0 + 32), nom_age(e)[:18], font=fs, fill=(200, 200, 200))
        dr.text((8, y0 + 52), "niveau %d" % (2 if e == 1 else 2 * e - 1), font=fs, fill=(170, 170, 170))
        for c, (bou, dkk) in enumerate(COLS):
            soc, tete = couches(e, dkk, c, a.tetes, S)
            day, _, _ = K.compose([{"pos": (T / 2, T / 2), "layers": soc + tete}], T, T)
            img = K.to_im(day if a.zoom == 2 else K.down2(day))
            if img.size != (ce, ce):
                img = img.resize((ce, ce), Image.LANCZOS)
            plate.paste(img, (lab_w + c * (cell + gap), y0))
            sa, ta = alpha_de(soc, T), alpha_de(tete, T)
            cache = float(np.minimum(sa, ta).sum() / max(sa.sum(), 1e-9))
            ys, xs = np.nonzero(ta > 0.1)
            lw = (xs.max() - xs.min() + 1) / 2.0 if len(xs) else 0
            lh = (ys.max() - ys.min() + 1) / 2.0 if len(ys) else 0
            lignes.append("%d\t%s\t%s\t%.3f\t%.0f\t%.0f" % (e, bou, dkk if e > 1 else "vanilla-%d" % (8 * c), cache, lw, lh))
    dr.text((8, H - 24), "Images dKK = rotation uniforme du modèle 3D ; le moteur les choisit par apply_projection "
                         "(NE du monde -> d06). Têtes : %s ; socles : sprites validés (passe 5, ère V)."
                         % a.tetes.replace("\\", "/").rstrip("/").split("/")[-2:][0],
            font=fs, fill=(160, 160, 160))
    os.makedirs(a.dest, exist_ok=True)
    nom = a.nom or "rose-ages-%s-z%d.png" % ("-".join(map(str, ages)), a.zoom)
    plate.save(os.path.join(a.dest, nom))
    with open(os.path.join(a.dest, nom[:-4] + ".tsv"), "w", encoding="utf-8", newline="\n") as fo:
        fo.write("\n".join(lignes) + "\n")
    print("planche %s (%dx%d)" % (os.path.join(a.dest, nom), W, H))


if __name__ == "__main__":
    main()
