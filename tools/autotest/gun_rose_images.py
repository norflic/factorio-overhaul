"""Image montrée par le moteur contre image attendue, sur les captures de `gun-rose` (lot A3-jeu, 24/10). Python 3.9
(numpy, Pillow).

    py -3.9 tools/autotest/gun_rose_images.py "<racine>/fo-visual/write/script-output/fo-shots"
        --feuilles "<source>/graphics/levels/gun" [--sortie DOSSIER] [--ages 2-15]

Le moteur ne dit pas, par script, quelle image d'une RotatedAnimation il dessine. Ce banc la retrouve sur les captures
« rose64-ageNN-z2-jour » (zoom 2 = 64 px par tuile = l'échelle des feuilles hr ; midi ; sans mode Alt ni
anticrénelage) : pour chaque tourelle de la rose (table fo-shots/gun-rose-poses.tsv écrite par le scénario : niveau,
direction k, orientation écrite et relue, position réelle), chaque cellule de la feuille hr principale de l'âge est
posée à sa place (position de l'entité + shift de la feuille) et comparée aux pixels de la capture, sur les pixels
OPAQUES de la cellule (alpha 255, bord retiré d'un pixel) que la lueur additive ne touche pas : écart moyen RVB
(0 à 255). L'image montrée = la cellule d'écart minimal (décalage de ±2 px essayé pour les 3 meilleures).
Attendu : 64 directions -> l'image k (orientation écrite = feuilles.orientation_image(k)) ; 4 directions -> la plus
proche des 4 (k à 45° pile du lot A2 : d08, d24, d40, d56 : non contrôlé, ambigu). Verdict par tourelle : OK si
l'image montrée est l'attendue ; marge = écart du 2e meilleur / écart du meilleur.
Sortie : gun-rose-images.tsv et le BILAN ; code 0 si aucune tourelle contrôlée n'est fausse.
"""
import argparse
import csv
import json
import os
import sys

import numpy as np
from PIL import Image

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PREFIX = "__factorio-overhaul__/graphics/levels/gun/"


def plage(spec):
    res = []
    for x in [x for x in str(spec).split(",") if x]:
        a, b = x.split("-") if "-" in x else (x, x)
        res += list(range(int(a), int(b) + 1))
    return res


def lire_tsv(p):
    with open(p, encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def erosion(m):
    out = m.copy()
    out[1:, :] &= m[:-1, :]
    out[:-1, :] &= m[1:, :]
    out[:, 1:] &= m[:, :-1]
    out[:, :-1] &= m[:, 1:]
    return out


def attendu(k, n):
    """Image attendue pour la direction k (sur 64) d'une tête à n directions ; None si ambigu."""
    if n == 64:
        return k
    if k % 16 == 8:
        return None
    return int(round(k / 16.0)) % 4


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("shots")
    ap.add_argument("--feuilles", required=True)
    ap.add_argument("--sortie", default=None)
    ap.add_argument("--ages", default="2-15")
    a = ap.parse_args()
    sortie = a.sortie or a.shots
    spr = json.load(open(os.path.join(a.feuilles, "sprites.json"), encoding="utf-8"))
    index = {r["scene"]: r for r in lire_tsv(os.path.join(a.shots, "index.tsv"))}
    poses = lire_tsv(os.path.join(a.shots, "gun-rose-poses.tsv"))
    lignes = ["age\tniveau\tk\tdirections\tattendue\tmontree\tecart_montree\tecart_attendue\tmarge\tverdict"]
    n_ok = n_faux = n_amb = 0
    par_age = []
    for e in plage(a.ages):
        scene = "rose64-age%02d-z2-jour" % e
        if scene not in index:
            print("[FO-GUN-IMAGES] âge %d : capture %s absente" % (e, scene))
            n_faux += 1
            continue
        r = index[scene]
        cap = np.asarray(Image.open(os.path.join(a.shots, r["fichier"])).convert("RGB")).astype(np.int16)
        cx, cy, zoom = float(r["x"]), float(r["y"]), float(r["zoom"])
        if abs(zoom - 2) > 1e-6:
            raise SystemExit("%s : zoom %s, attendu 2" % (scene, zoom))
        H_cap, W_cap = cap.shape[:2]
        A = spr["ages"][str(e)]
        hm, hg = A["tete"]["main"]["hr"], A["tete"]["glow"]["hr"] if "glow" in A["tete"] else None
        nd, ll = hm["direction_count"], hm["line_length"]
        W, H = hm["width"], hm["height"]
        sheet = np.asarray(Image.open(os.path.join(a.feuilles, hm["filename"][len(PREFIX):])).convert("RGBA"))
        gsheet = (np.asarray(Image.open(os.path.join(a.feuilles, hg["filename"][len(PREFIX):])).convert("RGBA"))
                  if hg else None)
        cells = []
        for c in range(nd):
            x0, y0 = (c % ll) * W, (c // ll) * H
            cell = sheet[y0:y0 + H, x0:x0 + W]
            m = cell[..., 3] == 255
            if gsheet is not None:
                gw, gh = hg["width"], hg["height"]
                # lueur : même origine ? les deux couches ont leur propre cadre ; on la pose dans le repère de main
                gx0, gy0 = (c % ll) * gw, (c // ll) * gh
                gcell = gsheet[gy0:gy0 + gh, gx0:gx0 + gw, 3]
                ox = int(round((hg["shift"][0] - hm["shift"][0]) * 64 - gw / 2 + W / 2))
                oy = int(round((hg["shift"][1] - hm["shift"][1]) * 64 - gh / 2 + H / 2))
                gl = np.zeros((H, W), bool)
                ya, xa = max(0, oy), max(0, ox)
                yb, xb = min(H, oy + gh), min(W, ox + gw)
                gl[ya:yb, xa:xb] = gcell[ya - oy:yb - oy, xa - ox:xb - ox] > 0
                m &= ~gl
            m = erosion(m)
            cells.append((cell[..., :3].astype(np.int16), m))
        tour = [p for p in poses if int(p["niveau"]) == 2 * e - 1]
        ok_e = faux_e = amb_e = 0
        marges = []
        for p in tour:
            k = int(p["k"])
            px = (float(p["x"]) + hm["shift"][0] - cx) * 64 + W_cap / 2 - W / 2
            py = (float(p["y"]) + hm["shift"][1] - cy) * 64 + H_cap / 2 - H / 2
            bx, by = int(round(px)), int(round(py))

            def err(c, dx, dy):
                rgb, m = cells[c]
                x0, y0 = bx + dx, by + dy
                if x0 < 0 or y0 < 0 or x0 + W > W_cap or y0 + H > H_cap:
                    return 1e9
                zone = cap[y0:y0 + H, x0:x0 + W]
                return float(np.abs(zone[m] - rgb[m]).mean()) if m.any() else 1e9

            e0 = sorted((err(c, 0, 0), c) for c in range(nd))
            best = []
            for _, c in e0[:3]:
                best.append((min(err(c, dx, dy) for dx in range(-2, 3) for dy in range(-2, 3)), c))
            best.sort()
            montree = best[0][1]
            att = attendu(k, nd)
            e_att = min(err(att, dx, dy) for dx in range(-2, 3) for dy in range(-2, 3)) if att is not None else None
            marge = best[1][0] / max(best[0][0], 1e-6)
            if att is None:
                verdict = "AMBIGU"
                amb_e += 1
            elif montree == att:
                verdict = "OK"
                ok_e += 1
                marges.append(marge)
            else:
                verdict = "FAUX"
                faux_e += 1
            lignes.append("%d\t%d\t%d\t%d\t%s\t%d\t%.2f\t%s\t%.2f\t%s" % (
                e, 2 * e - 1, k, nd, "-" if att is None else att, montree, best[0][0],
                "-" if e_att is None else "%.2f" % e_att, marge, verdict))
        n_ok += ok_e
        n_faux += faux_e
        n_amb += amb_e
        par_age.append("âge %d (%d dir.) : %d OK, %d FAUX, %d ambigu(s) ; marge min %.1f" % (
            e, nd, ok_e, faux_e, amb_e, min(marges) if marges else 0))
        print("[FO-GUN-IMAGES] " + par_age[-1])
    os.makedirs(sortie, exist_ok=True)
    with open(os.path.join(sortie, "gun-rose-images.tsv"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lignes) + "\n")
    print("[FO-GUN-IMAGES] BILAN : %d OK, %d FAUX, %d ambigu(s) non contrôlé(s) ; table %s" % (
        n_ok, n_faux, n_amb, os.path.join(sortie, "gun-rose-images.tsv")))
    return 0 if n_faux == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
