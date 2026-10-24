"""Feuille de gisement au format exact des minerais vanilla (lot M1, 24/10). Python système (py -3.9 : numpy, Pillow).

    # rendu (Blender, TOUJOURS par le verrou) puis post-traitement :
    python tools/render/with_render_lock.py -- py -3.9 tools/render/pieces/ressources/feuille.py \
        --direction A --samples 32 --travail <dossier de rendu> --sortie <dossier des feuilles> [--nom tungstene]
    # post-traitement seul (rendu déjà fait, sans Blender) :
    py -3.9 tools/render/pieces/ressources/feuille.py --direction A --travail <...> --sortie <...> --post-seul

Format produit (lu dans data/base/prototypes/entity/resources.lua, minerais vanilla 1.1.91) :
  - hr-<nom>.png : 1024 × 1024, 8 colonnes (frame_count = 8, variantes) × 8 lignes (variation_count = 8, stades ;
    ligne 0 = stade le plus riche, stage_counts décroissants), cadre 128 px, scale 0,5 ;
  - <nom>.png : 512 × 512, cadre 64 px (réduction 2× en lumière linéaire prémultipliée) ;
  - (facultatif) hr-<nom>-effet.png et <nom>-effet.png : même grille, couche ADDITIVE (stages_effect, comme
    hr-uranium-ore-glow.png) ; « eclats » : reflets froids tirés des reflets les plus clairs du rendu ; « lave » :
    passe de lueur de Blender ;
  - icone.png (64 px + 3 mipmaps = 120 × 64, comme icons/iron-ore.png) et icone-1.png à icone-3.png (images de
    l'objet au sol, `pictures` vanilla : même format) ;
  - MANIFEST.json : sha256 de chaque fichier, direction, échantillons, couverture par stade.
Chaque cadre = pièce par-dessus son liseré de contact (passe ao), par-dessus son ombre portée (passe shadow, noire,
alpha × 0,5 comme le moteur l'affiche) : un minerai vanilla porte son ombre dans sa propre image (aucune couche
d'ombre séparée dans le prototype resource).
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys
import time

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)
import directions as D  # noqa: E402
import fo_calib as C  # noqa: E402
import mesure as MS  # noqa: E402
import fo_post as P  # noqa: E402

PIECE = os.path.join(HERE, "gisement.py")
FRAME = 128
LF = chr(10)   # MANIFEST.json en fins de ligne Unix (le dépôt garde les octets tels quels, .gitattributes)
BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")


def centre_cellule(r, c):
    return (D.PAS * (c - 3.5), D.PAS * (r - 4.0))


def rendre(cle, travail, samples, lignes, icones_seules=False):
    """Un seul appel de Blender : toute la grille de la direction (passes main, ao, shadow, glow), ou la seule ligne
    des icônes (icones_seules : passe main seulement)."""
    os.makedirs(travail, exist_ok=True)
    cmd = [BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1",
           "-P", os.path.join(RENDER, "blender", "render_piece.py"), "--",
           "--piece", PIECE, "--out", travail, "--variant", cle, "--samples", str(samples),
           "--layers", "main" if icones_seules else "main,ao,shadow,glow", "--margin", "32"]
    for k in sorted(D.CALIB.get(cle, {})):
        cmd += ["--set", "%s=%r" % (k, D.CALIB[cle][k])]
    env = dict(os.environ)
    env["FO_M1_LIGNES"] = str(lignes)
    env["FO_M1_ICONES_SEULES"] = "1" if icones_seules else "0"
    t0 = time.time()
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    with open(os.path.join(travail, "blender-%s.log" % cle), "w", encoding="utf-8") as f:
        f.write(" ".join(cmd) + "\n" + p.stdout + "\n" + p.stderr)
    if p.returncode != 0 or "[FO-RENDER]" not in p.stdout:
        raise SystemExit("[FO-GISEMENT] ECHEC du rendu Blender (%s), journal : %s" % (cle, travail))
    dt = time.time() - t0
    print("[FO-GISEMENT] rendu %s : %.1f s (%d échantillons, %d lignes)" % (cle, dt, samples, lignes))
    return dt


def charger(travail, cle):
    pre = os.path.join(travail, "gisement-%s" % cle)
    with open(pre + "-render.json", encoding="utf-8") as f:
        info = json.load(f)
    L = {}
    for k in ("main", "ao", "shadow", "glow"):
        if os.path.exists(pre + "-%s.npy" % k):
            L[k] = np.load(pre + "-%s.npy" % k).astype(np.float64)
    return info, L


def recadre(img, cx, cy, s=FRAME):
    x0, y0 = int(round(cx - s / 2)), int(round(cy - s / 2))
    out = np.zeros((s, s, img.shape[2]))
    H, W = img.shape[:2]
    xa, xb, ya, yb = max(0, x0), min(W, x0 + s), max(0, y0), min(H, y0 + s)
    if xa < xb and ya < yb:
        out[ya - y0:yb - y0, xa - x0:xb - x0] = img[ya:yb, xa:xb]
    return out


def bordure(f, nul=2, plein=10):
    """Fondu de l'alpha près des bords d'un cadre : 0 sur les `nul` premiers pixels, plein à `plein` pixels.
    check_gisement.py (24/10) a trouvé l'OMBRE de 2 cristaux (cadres (0, 3) et (2, 3), alpha 0,5) coupée net au bord est
    du cadre : un cadre de minerai ne doit rien porter dans sa bordure (la vanilla laisse 3 px au moins)."""
    s = f.shape[0]
    d = np.minimum(np.arange(s), np.arange(s)[::-1]).astype(np.float64)
    t = np.clip((d - nul) / float(plein - nul), 0, 1)
    w = t * t * (3 - 2 * t)
    out = f.copy()
    out[..., 3] = out[..., 3] * np.minimum(w[:, None], w[None, :])
    return out


def rampe(x, a, b):
    return np.clip((x - a) / float(b - a), 0, 1)


def couleur_effet(main, alpha, teinte=(0.55, 0.78, 1.0), seuil=(0.52, 0.85), lueur=None):
    """Éclats froids : reflets les plus clairs de la couche principale (luminance sRGB codée), en additif.

    lueur (correction M1, 24/10 ; facultatif) : dict(lum=(a, b), froid=(a, b), gain=g) : lueur froide en plus des
    éclats, sur les faces qui renvoient le ciel (luminance entre a et b ET bleutées : b - r entre a et b), au gain g.
    Les éclats seuls n'allumaient que 0,78 % des pixels de la feuille (uranium vanilla : 38 %) : de nuit, en moteur,
    le tungstène ne se distinguait pas du fer (vérification du lot, MAJEUR 1)."""
    lum = 0.2126 * main[..., 0] + 0.7152 * main[..., 1] + 0.0722 * main[..., 2]
    k = rampe(lum, seuil[0], seuil[1])
    if lueur:
        froid = main[..., 2] - main[..., 0]
        kl = rampe(lum, *lueur["lum"]) * rampe(froid, *lueur["froid"]) * lueur["gain"]
        k = np.maximum(k, kl)
    k = k * (alpha > 0.5)
    img = np.zeros(main.shape[:2] + (4,))
    img[..., :3] = teinte
    img[..., 3] = k
    return P.additive_layer(img)


def post(cle, travail, sortie, nom, lignes=D.STADES + 1):
    info, L = charger(travail, cle)
    ox, oy = info["origin_px"]
    d = D.DIRECTIONS[cle]
    main = P.compose_main(L["main"], L.get("ao"), C)
    ombre = P.shadow_layer(L["shadow"]) if "shadow" in L else None
    if ombre is not None:
        ombre[..., 3] *= C.ENGINE_SHADOW_FACTOR
        cadre_plein = P.over(main, ombre)
    else:
        cadre_plein = main
    effet_src = None
    if d.get("effet") == "lave" and "glow" in L:
        effet_src = P.additive_layer(L["glow"])
    elif d.get("effet") == "eclats":
        effet_src = couleur_effet(L["main"], L["main"][..., 3], **D.EFFET.get(cle, {}))

    hr = np.zeros((D.STADES * FRAME, D.COLONNES * FRAME, 4))
    hre = np.zeros_like(hr) if effet_src is not None else None
    couv = []
    for r in range(min(lignes, D.STADES)):
        cv = []
        for c in range(D.COLONNES):
            tx, ty = centre_cellule(r, c)
            cx, cy = ox + tx * C.PX_PER_UNIT_HR, oy + ty * C.PX_PER_UNIT_HR
            f = bordure(recadre(cadre_plein, cx, cy))
            hr[r * FRAME:(r + 1) * FRAME, c * FRAME:(c + 1) * FRAME] = f
            cv.append(float((f[..., 3] > 0.5).mean()))
            if hre is not None:
                hre[r * FRAME:(r + 1) * FRAME, c * FRAME:(c + 1) * FRAME] = bordure(recadre(effet_src, cx, cy))
        couv.append(round(float(np.mean(cv)), 4))
    os.makedirs(sortie, exist_ok=True)
    sums = {}
    sums["hr-%s.png" % nom] = P.write_png(P.floor_alpha(hr), os.path.join(sortie, "hr-%s.png" % nom))
    sums["%s.png" % nom] = P.write_png(P.floor_alpha(P.downsample2(hr)), os.path.join(sortie, "%s.png" % nom))
    if hre is not None:
        sums["hr-%s-effet.png" % nom] = P.write_png(P.floor_alpha(hre), os.path.join(sortie, "hr-%s-effet.png" % nom))
        sums["%s-effet.png" % nom] = P.write_png(P.floor_alpha(P.downsample2_additive(hre)),
                                                 os.path.join(sortie, "%s-effet.png" % nom))
    if lignes > D.STADES:
        for c in range(4):
            tx, ty = centre_cellule(D.STADES, c)
            cx, cy = ox + tx * C.PX_PER_UNIT_HR, oy + ty * C.PX_PER_UNIT_HR
            f = recadre(main, cx, cy, 2 * FRAME)
            strip = P.icon_strip(f, fill=0.94)
            fn = "icone.png" if c == 0 else "icone-%d.png" % c
            sums[fn] = P.write_png(strip, os.path.join(sortie, fn))
    man = {
        "outil": "tools/render/pieces/ressources/feuille.py",
        "direction": cle, "nom_direction": d["nom"], "nom": nom,
        "echantillons": info.get("samples"), "blender": info.get("blender"),
        "secondes_blender": info.get("seconds"),
        "couverture_par_stade": couv, "couverture_vanilla": list(D.COUVERTURE_VANILLA),
        # couleurs VUES, mesurées sur le fichier écrit (mesure.repartition ; check_gisement.py les recalcule)
        "repartition": MS.repartition(MS.lire(os.path.join(sortie, "hr-%s.png" % nom))),
        "effet": d.get("effet"), "effet_reglages": D.EFFET.get(cle, {}),
        "format": {"frame": FRAME, "frame_count": D.COLONNES, "variation_count": D.STADES,
                   "scale_hr": 0.5, "icon_size": 64, "icon_mipmaps": 4},
        "sha256": dict(sorted(sums.items())),
    }
    with open(os.path.join(sortie, "MANIFEST.json"), "w", encoding="utf-8", newline=LF) as f:
        json.dump(man, f, indent=1, ensure_ascii=False, sort_keys=True)
        f.write("\n")
    print("[FO-GISEMENT] %s (%s) : couverture par stade %s (vanilla %s)" % (cle, d["nom"], couv,
                                                                            list(D.COUVERTURE_VANILLA)))
    print("[FO-GISEMENT] %d fichier(s) dans %s" % (len(sums), sortie))
    return man


def post_icones(cle, travail, sortie):
    """Icônes seules (rendu --icones-seules) : icone.png, icone-1.png à icone-3.png, sommes mises à jour dans le
    MANIFEST.json de la feuille (qui doit exister)."""
    info, L = charger(travail, cle)
    ox, oy = info["origin_px"]
    sums = {}
    for c in range(4):
        tx, ty = centre_cellule(D.STADES, c)
        cx, cy = ox + tx * C.PX_PER_UNIT_HR, oy + ty * C.PX_PER_UNIT_HR
        f = recadre(L["main"], cx, cy, 2 * FRAME)
        fn = "icone.png" if c == 0 else "icone-%d.png" % c
        sums[fn] = P.write_png(P.icon_strip(f, fill=0.96), os.path.join(sortie, fn))
    mp = os.path.join(sortie, "MANIFEST.json")
    with open(mp, encoding="utf-8") as f:
        man = json.load(f)
    man["sha256"].update(sums)
    man["sha256"] = dict(sorted(man["sha256"].items()))
    man["icones"] = {"rendu": "gros plan (gisement.cellule_icone), passe main seule", "echantillons": info.get("samples"),
                     "secondes_blender": info.get("seconds")}
    with open(mp, "w", encoding="utf-8", newline=LF) as f:
        json.dump(man, f, indent=1, ensure_ascii=False, sort_keys=True)
        f.write("\n")
    print("[FO-GISEMENT] %s : 4 icônes en gros plan dans %s" % (cle, sortie))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--direction", required=True)
    ap.add_argument("--travail", required=True)
    ap.add_argument("--sortie", required=True)
    ap.add_argument("--nom", default="tungstene")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--lignes", type=int, default=D.STADES + 1)
    ap.add_argument("--post-seul", action="store_true")
    ap.add_argument("--icones-seules", action="store_true",
                    help="ne rend que la ligne des icônes et remplace les 4 icônes d'une feuille déjà faite")
    a = ap.parse_args()
    for cle in a.direction.split(","):
        if a.icones_seules:
            trav = os.path.join(a.travail, cle + "-icones")
            if not a.post_seul:
                rendre(cle, trav, a.samples, a.lignes, icones_seules=True)
            post_icones(cle, trav, a.sortie)
            continue
        trav = os.path.join(a.travail, cle)
        if not a.post_seul:
            rendre(cle, trav, a.samples, a.lignes)
        post(cle, trav, os.path.join(a.sortie, cle) if "," in a.direction else a.sortie, a.nom, a.lignes)


if __name__ == "__main__":
    main()
