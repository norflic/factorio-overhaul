"""Icônes de la monazite (lot design-icone-monazite, 30/10). Python système (py -3.9 : numpy, Pillow).

    # rendu (Blender, TOUJOURS par le verrou) puis post-traitement :
    python tools/render/with_render_lock.py -- py -3.9 tools/render/pieces/ressources/icones_monazite.py \
        --samples 128 --travail <dossier de rendu> --sortie graphics/ressources/monazite/icones [--compo A]
    # post-traitement seul (rendu déjà fait) : --post-seul

Sortie : icone.png (64 px + mipmaps 32, 16, 8 : 120 × 64, comme icons/iron-ore.png) et icone-1.png à icone-3.png
(images de l'objet au sol, `pictures` vanilla, même format), MANIFEST.json (sha256, composition, échantillons).
Pièce : icone_monazite.py (même rognon que le gisement M1).
"""
import argparse
import json
import os
import subprocess
import sys
import time

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402

PIECE = os.path.join(HERE, "icone_monazite.py")
BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LF = chr(10)
NOMS = ("icone.png", "icone-1.png", "icone-2.png", "icone-3.png")
PAS = 4.0      # = icone_monazite.PAS (la pièce importe bpy : on ne l'importe pas ici)
# Réglage du gisement M1 (directions.CALIB["M1"]) + lumière d'icône (essai 32d : avec l'appoint zénithal du monde,
# 1,5, les rognons sortaient pâles et plats, sans le côté d'ombre franc des icônes vanilla) : soleil plus fort,
# appoint réduit. Une icône n'est pas éclairée par le monde du jeu : seul son contraste compte.
CALIB = {"SKY_GLOSSY_FACTOR": 5.0, "FILL_STRENGTH": 0.15, "SUN_STRENGTH": 3.2}


def rendre(compo, travail, samples):
    os.makedirs(travail, exist_ok=True)
    cmd = [BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1",
           "-P", os.path.join(RENDER, "blender", "render_piece.py"), "--",
           "--piece", PIECE, "--out", travail, "--variant", compo, "--samples", str(samples),
           "--layers", "main,ao", "--margin", "32"]
    for k in sorted(CALIB):
        cmd += ["--set", "%s=%r" % (k, CALIB[k])]
    t0 = time.time()
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    with open(os.path.join(travail, "blender-%s.log" % compo), "w", encoding="utf-8") as f:
        f.write(" ".join(cmd) + "\n" + p.stdout + "\n" + p.stderr)
    if p.returncode != 0 or "[FO-RENDER]" not in p.stdout:
        raise SystemExit("[FO-ICONES-MONAZITE] ECHEC du rendu Blender, journal : %s" % travail)
    print("[FO-ICONES-MONAZITE] rendu %s : %.1f s (%d échantillons)" % (compo, time.time() - t0, samples))


def recadre(img, cx, cy, s):
    x0, y0 = int(round(cx - s / 2)), int(round(cy - s / 2))
    out = np.zeros((s, s, img.shape[2]))
    H, W = img.shape[:2]
    xa, xb, ya, yb = max(0, x0), min(W, x0 + s), max(0, y0), min(H, y0 + s)
    if xa < xb and ya < yb:
        out[ya - y0:yb - y0, xa - x0:xb - x0] = img[ya:yb, xa:xb]
    return out


def avec_liseré(main, ao, px):
    """Liseré de contact du kit (fo_post.compose_main : passe ao, même réglage que les feuilles), gardé à `px` pixels
    HR au plus des rognons : les creux entre deux rognons et le pied de chacun foncent, comme le contour sombre des
    morceaux des icônes vanilla, sans tache de sol autour du tas (essai 32h : sans lui, rognons clairs sur fond clair
    sans bord)."""
    a = Image.fromarray((np.clip(main[..., 3], 0, 1) * 255).astype(np.uint8), "L")
    pres = np.asarray(a.filter(ImageFilter.MaxFilter(2 * px + 1))).astype(np.float64) / 255.0
    fr = P.contact_fringe(ao, C.AO_STRENGTH, C.AO_GAMMA, C.AO_COLOR)
    fr[..., 3] *= pres
    return P.over(main, fr)


def avec_bord(main, px, force):
    """Bord sombre des silhouettes (critique de l'icône, 30/10 vers 12 h) : les morceaux des icônes vanilla ont un bord
    extérieur sombre (5e centile de luminance 0,08 à 0,11 ; F : 0,15) qui les détache de la fente grise à 32 px ; les
    rognons de F fondaient par leurs bords éclairés (haut, gauche). Sur `px` pixels HR depuis le bord de l'alpha, la
    couleur est assombrie d'au plus `force` (en lumière linéaire), en rampe ; l'alpha ne change pas."""
    a8 = Image.fromarray((np.clip(main[..., 3], 0, 1) * 255).astype(np.uint8), "L")
    rampe = np.zeros(main.shape[:2])
    for k in range(1, px + 1):
        er = np.asarray(a8.filter(ImageFilter.MinFilter(2 * k + 1))).astype(np.float64) / 255.0
        rampe += (main[..., 3] - er).clip(0, 1) / px
    f = 1.0 - force * rampe.clip(0, 1)
    lin = P.srgb_to_lin(main[..., :3]) * f[..., None]
    return np.concatenate([P.lin_to_srgb(lin), main[..., 3:4]], -1)


def avec_niveaux(main, t5, t95):
    """Niveaux de l'icône (critique, 30/10 vers 12 h 15) : les matières résineuses de G (or_v, ambre, miel_v), plus
    sombres que l'or et le soufre de F, ont fait tomber le 95e centile de luminance de 0,80 à 0,67 (fer et cuivre
    vanilla : 0,83 et 0,81) : un tas terne et sans reflet. Les luminances des pixels opaques (sRGB, Rec. 709) sont
    remises en ligne de leurs 5e et 95e centiles vers `t5` et `t95` ; chaque pixel garde sa teinte (RVB × L'/L,
    écrêté à 1, donc les reflets blanchissent comme ceux du cuivre vanilla) ; l'alpha ne change pas."""
    a = main[..., 3]
    rgb = main[..., :3]
    L = rgb @ np.array([0.2126, 0.7152, 0.0722])
    m = a > 0.5
    p5, p95 = np.percentile(L[m], 5), np.percentile(L[m], 95)
    L2 = (t5 + (L - p5) * (t95 - t5) / max(p95 - p5, 1e-6)).clip(0.0, 1.0)
    k = np.where(L > 1e-6, L2 / np.maximum(L, 1e-6), 1.0)
    return np.concatenate([(rgb * k[..., None]).clip(0.0, 1.0), main[..., 3:4]], -1)


def post(compo, travail, sortie, fill, liseré=3, bord=(0, 0.0), niveaux=None):
    pre = os.path.join(travail, "icones-monazite-%s" % compo)
    with open(pre + "-render.json", encoding="utf-8") as f:
        info = json.load(f)
    main = np.load(pre + "-main.npy").astype(np.float64)
    if liseré and os.path.exists(pre + "-ao.npy"):
        main = avec_liseré(main, np.load(pre + "-ao.npy").astype(np.float64), liseré)
    if bord[0] > 0 and bord[1] > 0:
        main = avec_bord(main, bord[0], bord[1])
    if niveaux:
        main = avec_niveaux(main, niveaux[0], niveaux[1])
    ox, oy = info["origin_px"]
    s = int(PAS * C.PX_PER_UNIT_HR)
    os.makedirs(sortie, exist_ok=True)
    sums = {}
    for i, fn in enumerate(NOMS):
        cx = ox + PAS * (i - 1.5) * C.PX_PER_UNIT_HR
        f = recadre(main, cx, oy - 0.3 * C.PX_PER_UNIT_HR, s)
        sums[fn] = P.write_png(P.icon_strip(f, fill=fill), os.path.join(sortie, fn))
    man = {
        "outil": "tools/render/pieces/ressources/icones_monazite.py",
        "piece": "tools/render/pieces/ressources/icone_monazite.py",
        "composition": compo,
        "modele": "rognon du gisement M1 (gisement.roche, directions M1)",
        "echantillons": info.get("samples"), "blender": info.get("blender"),
        "secondes_blender": info.get("seconds"), "remplissage": fill, "liseré_px_hr": liseré,
        "bord_px_hr": bord[0], "bord_force": bord[1], "niveaux_p5_p95": list(niveaux) if niveaux else None,
        "format": {"icon_size": 64, "icon_mipmaps": 4, "largeur": 120},
        "sha256": dict(sorted(sums.items())),
    }
    with open(os.path.join(sortie, "MANIFEST.json"), "w", encoding="utf-8", newline=LF) as f:
        json.dump(man, f, indent=1, ensure_ascii=False, sort_keys=True)
        f.write("\n")
    print("[FO-ICONES-MONAZITE] %d icône(s) dans %s" % (len(sums), sortie))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compo", default="A")
    ap.add_argument("--travail", required=True)
    ap.add_argument("--sortie", required=True)
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--remplissage", type=float, default=0.96)
    ap.add_argument("--post-seul", action="store_true")
    ap.add_argument("--lisere", type=int, default=3, help="liseré de contact gardé à N px HR des rognons (0 : aucun)")
    ap.add_argument("--bord", type=int, default=0, help="bord sombre des silhouettes sur N px HR (0 : aucun ; G : 5)")
    ap.add_argument("--bord-force", type=float, default=0.55)
    ap.add_argument("--niveaux", default="", help="p5,p95 visés de la luminance des pixels opaques (G : 0.09,0.82)")
    a = ap.parse_args()
    for compo in a.compo.split(","):
        trav = os.path.join(a.travail, compo)
        if not a.post_seul:
            rendre(compo, trav, a.samples)
        post(compo, trav, os.path.join(a.sortie, compo) if "," in a.compo else a.sortie, a.remplissage, a.lisere,
             (a.bord, a.bord_force), tuple(float(v) for v in a.niveaux.split(",")) if a.niveaux else None)


if __name__ == "__main__":
    main()
