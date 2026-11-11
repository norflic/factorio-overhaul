"""FEUILLES DE JEU DU LÉVIATHAN ARTICULÉ (lot LEVIATHAN-SEG, mandat du DC, 11/11) : rendus -> graphics/robots/titans/leviathan/ (PNG hors de
git, D-6), sprites.lua (généré, lu par prototypes/titans.lua) et MANIFEST.json (commité). Hors Blender : réduction, rognage, feuilles.

    PYTHONUTF8=1 py -3.9 tools/render/pieces/titans/feuilles_leviathan.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources (à GARDER) : fo-logs/2026-11-11_LEVIATHAN-SEG/rendu/ (batch_titans.py, par rendre_titans.py) :
  leviathan-anime-<stade>/leviathan-<stade>-<course|attaque>-<image>-<dir>.npz : la TÊTE (16 directions, 4 + 4 images) ;
  leviathan-<segment|queue>-<stade>/leviathan-<pièce>-<stade>-pose-00-<dir>.npz : les pièces fixes (16 directions, une image).
Même traitement que les titans animés (feuilles_titans.anime : liseré de contact, lueur additive, ombre), un fichier par direction et par
couche ; densités : corps au rendu, lueur et ombre à demi-densité (DIVS). Icône de chaque stade : le titan ENTIER composé (queue,
segments, tête posés en ligne derrière la tête, direction sud-est, aux distances de la règle T.LEVIATHAN.segmente), tenu dans 60 px.
"""
import argparse
import glob
import json
import os
import re
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(RENDER, "pieces", "experimentaux"))
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import feuilles_xp as FX  # noqa: E402
import feuilles_titans as FT  # noqa: E402

RACINE = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91")
SRC_DEFAUT = os.path.join(RACINE, "fo-logs", "2026-11-11_LEVIATHAN-SEG", "rendu")
DEST_DEFAUT = os.path.join(MOD, "graphics", "robots", "titans", "leviathan")
PREFIXE = "__factorio-overhaul__/graphics/robots/titans/leviathan/"
COMMANDE = "PYTHONUTF8=1 py -3.9 tools/render/pieces/titans/feuilles_leviathan.py   (depuis la racine du mod ; sources : fo-logs/2026-11-11_LEVIATHAN-SEG/rendu, à GARDER)"
NOM = "leviathan"
STADES = ("1", "2", "3")
PIECES = ("segment", "queue")
DIVS = {"main": 1, "glow": 2, "shadow": 2}
MAX_PX = 4096
ICONE_DIR = 6          # sud-est sur 16 directions (comme l'icône des titans à 8 directions : direction 3)


def regle_segmente():
    """T.LEVIATHAN.segmente lu dans le texte de shared/robots/titans.lua (n, premier, espacement, queue, directions) : une seule source."""
    src = open(os.path.join(MOD, "shared", "robots", "titans.lua"), encoding="utf-8").read()
    m = re.search(r"segmente = \{([^}]*)", src)
    out = {}
    for k, v in re.findall(r"(\w+) = ([0-9.]+)", m.group(1)):
        out[k] = float(v)
    return out


def serie_tete():
    src = open(os.path.join(HERE, NOM + ".py"), encoding="utf-8").read()
    m = re.search(r"\nSERIE = \{(.*?)\}", src)
    return {k: float(v) for k, v in re.findall(r'"(\w+)":\s*([0-9.]+)', m.group(1))}


def couche_main(src, sub, base, anim, i, k):
    """Couche principale d'une vue (liseré de contact composé dessous, comme feuilles_titans.anime), origine et densité."""
    z = np.load(os.path.join(FT.dossier(src, sub), "%s-%s-%02d-%02d.npz" % (base, anim, i, k)))
    fr = P.contact_fringe(z["ao"].astype(np.float64) / 255.0, C.AO_STRENGTH, C.AO_GAMMA, C.AO_COLOR)
    fr[..., 3] *= FT.sans_points_isoles(fr[..., 3], FT.SEUIL / 255.0)
    mn = P.over(z["main"].astype(np.float64) / 255.0, fr)
    return mn, z["origine"], float(z["densite"][0])


def icone_composee(S, src, st, seg):
    """Le titan entier, direction sud-est : queue, segments (du dernier au premier), tête par-dessus, chacun posé à sa distance d'arc
    derrière la tête (vecteur unitaire de la direction, en px de rendu : 1 tuile = densité px) ; rogné, tenu dans 60 px, cadre de 64."""
    n = int(seg["n"])
    abscisses = [seg["premier"] + k * seg["espacement"] for k in range(n)] + [seg["premier"] + (n - 1) * seg["espacement"] + seg["queue"]]
    v = (0.70711, 0.70711)          # sud-est (y vers le sud) : la tête regarde vers le bas à droite, le corps part vers le haut à gauche
    vues = [couche_main(src, "%s-queue-%s" % (NOM, st), "%s-queue-%s" % (NOM, st), "pose", 0, ICONE_DIR)]
    offs = [abscisses[n]]
    for k in range(n, 0, -1):
        vues.append(couche_main(src, "%s-segment-%s" % (NOM, st), "%s-segment-%s" % (NOM, st), "pose", 0, ICONE_DIR))
        offs.append(abscisses[k - 1])
    vues.append(couche_main(src, "%s-anime-%s" % (NOM, st), "%s-%s" % (NOM, st), "course", 0, ICONE_DIR))
    offs.append(0.0)
    D = vues[-1][2]
    pos = []
    for (mn, org, dens), s in zip(vues, offs):
        pos.append((int(round(-v[0] * s * D - org[0])), int(round(-v[1] * s * D - org[1]))))
    x0 = min(p[0] for p in pos)
    y0 = min(p[1] for p in pos)
    W = max(p[0] + vv[0].shape[1] for p, vv in zip(pos, vues)) - x0
    H = max(p[1] + vv[0].shape[0] for p, vv in zip(pos, vues)) - y0
    toile = np.zeros((H, W, 4))
    for (mn, org, dens), p in zip(vues, pos):
        x, y = p[0] - x0, p[1] - y0
        h, w = mn.shape[:2]
        toile[y:y + h, x:x + w] = P.over(mn, toile[y:y + h, x:x + w])
    b = FT.boite(np.round(toile[..., 3] * 255))
    toile = np.round(np.clip(toile[b[1]:b[3], b[0]:b[2]], 0, 1) * 255).astype(np.uint8)
    k = 60.0 / max(toile.shape[0], toile.shape[1])
    ic = FX.lanczos(toile, max(1, int(round(toile.shape[1] * k))), max(1, int(round(toile.shape[0] * k))))
    cadre = np.zeros((64, 64, 4), np.uint8)
    oy, ox = (64 - ic.shape[0]) // 2, (64 - ic.shape[1]) // 2
    cadre[oy:oy + ic.shape[0], ox:ox + ic.shape[1]] = ic
    return {"filename": S.ecrit(cadre, "icone-%s-%s.png" % (NOM, st)), "size": 64}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for f in glob.glob(os.path.join(a.dest, "*.png")):
        os.remove(f)
    FX.PREFIXE = PREFIXE
    se = serie_tete()
    seg = regle_segmente()
    FT.DIRS = int(se["dirs"])
    S = FX.Sortie(a.dest)
    spr = {"tete": {"anime": True, "foulee": FT.foulee_de(NOM), "reduc": FT.REDUC, "directions": FT.DIRS}}
    poids = {"tete": {"haute": 0.0, "normale": 0.0, "images": 0}}
    for piece in PIECES:
        spr[piece] = {"reduc": FT.REDUC, "directions": FT.DIRS}
        poids[piece] = {"haute": 0.0, "normale": 0.0, "images": 0}
    for st in STADES:
        FT.ANIMS = (("course", int(se["course"])), ("attaque", int(se["attaque"])))
        spr["tete"][st] = FT.anime(S, a.src, poids["tete"], "%s-anime-%s" % (NOM, st), "%s-%s" % (NOM, st), "%s-tete-%s" % (NOM, st), DIVS, MAX_PX)
        FT.ANIMS = (("pose", 1),)
        for piece in PIECES:
            e = FT.anime(S, a.src, poids[piece], "%s-%s-%s" % (NOM, piece, st), "%s-%s-%s" % (NOM, piece, st), "%s-%s-%s" % (NOM, piece, st), DIVS, MAX_PX)
            os.remove(os.path.join(a.dest, os.path.basename(e.pop("icone")["filename"])))
            S.fichiers = [f for f in S.fichiers if not f.startswith("icone-%s-%s" % (NOM, piece))]
            spr[piece][st] = e
        os.remove(os.path.join(a.dest, os.path.basename(spr["tete"][st]["icone"]["filename"])))
        spr["tete"][st]["icone"] = icone_composee(S, a.src, st, seg)
    p = os.path.join(a.dest, "sprites.lua")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- FICHIER GÉNÉRÉ par tools/render/pieces/titans/feuilles_leviathan.py (lot LEVIATHAN-SEG) : ne pas modifier à la main.\n")
        f.write("-- Images hors de git (D-6) : MANIFEST.json, « commande ». shift : centre de l'image depuis le pivot de la pièce, en tuiles.\n")
        f.write("return " + FX.lua(spr) + "\n")
    fichiers = {}
    total = 0
    for f in sorted(os.listdir(a.dest)):
        if f.endswith(".png"):
            pp = os.path.join(a.dest, f)
            im = Image.open(pp)
            fichiers[f] = {"largeur": im.size[0], "hauteur": im.size[1], "taille": os.path.getsize(pp), "sha256": FT.sha(pp)}
            total += os.path.getsize(pp)
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"commande": COMMANDE, "arguments": [], "poids_mpx": {k: {kk: round(vv, 2) for kk, vv in v.items()} for k, v in poids.items()},
                   "fichiers": fichiers}, f, indent=1, sort_keys=True, ensure_ascii=False)
    tot = sum(v["haute"] for v in poids.values())
    print("[FO-FEUILLES-LEVIATHAN] %d fichiers PNG, %.2f Mo ; haute %.1f Mpx en tout" % (len(fichiers), total / 1e6, tot), flush=True)
    for k, v in poids.items():
        print("  %s : %d images ; haute %.1f Mpx ; normale %.2f Mpx" % (k, v["images"], v["haute"], v["normale"]))


if __name__ == "__main__":
    main()
