"""FEUILLES MULTIDIRECTIONNELLES D'IXION (lot ART-GEANTS, mandat de 10 h du DC, 11/11, F525) : la roue de feu roule, sa silhouette dépend
du sens de marche ; une seule image (cap 117°, vue du 31/10) la faisait glisser en marche vers le nord ou l'ouest.

    py -3.9 tools/render/pieces/experimentaux/feuilles_ixion_dirs.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources (à GARDER, lecture seule) : fo-logs/2026-11-11_GEANTS/rendu/cap-<c>/sprites/ixion/ (spec.json, main.png, glow_*.png, shadow.png),
rendus par
    FO_IXION_CAP=<c> py -3.9 -B tools/render/pieces/experimentaux/rendre.py --names ixion --out <rendu>/cap-<c>/sprites
        --cache <rendu>/cap-<c>/cache --px 40 --samples 32 --lueur-spp 16 --ombre-spp 16
(ixion.py : la roue corrigée après la critique du 1/11, reprise de la branche design-exp2, 7764b576, avec ses 4 lueurs feu, hublots,
plasma, soleil ; la vue unique du jeu est la même roue au cap 128°, 64 échantillons)
pour c = 0, 22,5 … 157,5 (POSES caps, 0 = nord, sens horaire). Une roue est la même à 180° près (essieu identique ; les tours pendues aux
deux bouts de l'essieu sont de part et d'autre) : 8 poses servent les 16 directions de marche (direction d -> pose d mod 8).
Réduction et lueurs fondues EXACTEMENT comme feuilles_xp.geant() (corps haute 32 px/tuile, normale 16 ; lueurs en une couche additive ;
ombre 16 / 8) ; aucune icône (celle d'Ixion reste celle de feuilles_xp). N'efface AUCUN autre fichier du dossier : écrit
hr-ixion-dNN*.png / ixion-dNN*.png, ixion_dirs.lua (généré, lu par prototypes/experimentaux_geants.lua) et MANIFEST-ixion-dirs.json.
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import feuilles_xp as FX  # noqa: E402

DIRECTIONS = 16
POSES = 8
SRC_DEFAUT = os.path.join(FX.LOGS, "2026-11-11_GEANTS", "rendu")
COMMANDE = ("py -3.9 tools/render/pieces/experimentaux/feuilles_ixion_dirs.py   (depuis la racine du mod ; sources : "
            "fo-logs/2026-11-11_GEANTS/rendu/cap-<c>, à GARDER)")


def cap_de(k):
    """Cap (degrés, 0 = nord, sens horaire) de la pose k, tel qu'écrit dans le nom du dossier source."""
    c = k * 360.0 / DIRECTIONS
    return ("%g" % c)


def pose(S, src, k):
    """Une pose : comme FX.geant() sans l'icône. Rend l'entrée { main, lueurs, ombre }."""
    var_dir = os.path.join(src, "cap-%s" % cap_de(k), "sprites")
    cle = "ixion-d%02d" % k
    spec = json.load(open(os.path.join(var_dir, "ixion", "spec.json"), encoding="utf-8"))
    out = {"lueurs": []}
    c, px, sh = FX.lit_couche(var_dir, "ixion", "main")
    out["main"] = S.couche(cle, FX.reduit(c, px, FX.PPT), FX.PPT, FX.reduit(c, px, FX.LR_PPT), FX.LR_PPT, sh)
    couches = []
    for nom in sorted(spec["layers"]):
        if nom.startswith("glow_"):
            g, gpx, gsh = FX.lit_couche(var_dir, "ixion", nom)
            if g.shape[0] * g.shape[1] > 1:
                x0 = gsh[0] * gpx - g.shape[1] / 2.0
                y0 = gsh[1] * gpx - g.shape[0] / 2.0
                couches.append((g, int(round(x0)), int(round(y0))))
    if couches:
        X0 = min(x for _, x, _ in couches)
        Y0 = min(y for _, _, y in couches)
        X1 = max(x + g.shape[1] for g, x, _ in couches)
        Y1 = max(y + g.shape[0] for g, _, y in couches)
        e = np.zeros((Y1 - Y0, X1 - X0, 3), np.float32)
        for g, x, y in couches:
            f = g.astype(np.float32) / 255.0
            e[y - Y0:y - Y0 + g.shape[0], x - X0:x - X0 + g.shape[1]] += f[..., :3] * f[..., 3:4]
        a = FX.additif(e)
        a, cx0, cy0 = FX.rogne(a)
        gsh = ((X0 + cx0 + a.shape[1] / 2.0) / px, (Y0 + cy0 + a.shape[0] / 2.0) / px)
        l = S.couche(cle + "-lueur", FX.reduit(a, px, FX.PPT), FX.PPT, FX.reduit(a, px, FX.LR_PPT), FX.LR_PPT, gsh)
        l["nom"] = "+".join(sorted(n[5:] for n in spec["layers"] if n.startswith("glow_")))
        out["lueurs"].append(l)
    o, opx, osh = FX.lit_couche(var_dir, "ixion", "shadow")
    out["ombre"] = S.couche(cle + "-ombre", FX.reduit(o, opx, FX.OMBRE_HR), FX.OMBRE_HR, FX.reduit(o, opx, FX.OMBRE_LR), FX.OMBRE_LR, osh)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--dest", default=FX.DEST_DEFAUT)
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for f in os.listdir(a.dest):
        if f.endswith(".png") and (f.startswith("hr-ixion-d") or f.startswith("ixion-d")):
            os.remove(os.path.join(a.dest, f))
    S = FX.Sortie(a.dest)
    poses = [pose(S, a.src, k) for k in range(POSES)]
    t = {"directions": DIRECTIONS, "poses": poses}
    with open(os.path.join(a.dest, "ixion_dirs.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- FICHIER GÉNÉRÉ par tools/render/pieces/experimentaux/feuilles_ixion_dirs.py (lot ART-GEANTS, F525) : ne pas modifier à la main.\n")
        f.write("-- Ixion, 16 directions de marche servies par 8 poses (direction d -> pose d mod 8 : une roue est la même à 180° près).\n")
        f.write("-- Images hors de git (D-6) : MANIFEST-ixion-dirs.json, « commande ». shift : centre de l'image depuis la position au sol, en tuiles.\n")
        f.write("return " + FX.lua(t) + "\n")
    fichiers, total, mpx_hr, mpx_lr = {}, 0, 0.0, 0.0
    from PIL import Image
    for f in sorted(S.fichiers):
        pp = os.path.join(a.dest, f)
        im = Image.open(pp)
        fichiers[f] = {"largeur": im.size[0], "hauteur": im.size[1], "taille": os.path.getsize(pp), "sha256": FX.sha(pp)}
        total += os.path.getsize(pp)
        if f.startswith("hr-"):
            mpx_hr += im.size[0] * im.size[1] / 1e6
        else:
            mpx_lr += im.size[0] * im.size[1] / 1e6
    with open(os.path.join(a.dest, "MANIFEST-ixion-dirs.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"commande": COMMANDE, "arguments": [], "fichiers": fichiers}, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-IXION] %d poses, %d fichiers PNG, %.2f Mo ; haute %.2f Mpx, normale %.2f Mpx" % (POSES, len(fichiers), total / 1e6,
          mpx_hr, mpx_lr), flush=True)


if __name__ == "__main__":
    main()
