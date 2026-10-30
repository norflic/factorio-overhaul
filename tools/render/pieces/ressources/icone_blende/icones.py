"""Icônes du minerai « blende » (lot ICONE-BLENDE, 30/10/2026). Python système (py -3.9 : numpy, Pillow).

    # rendu (Blender, TOUJOURS par le verrou) puis post-traitement, installé dans graphics/ressources/blende :
    python tools/render/with_render_lock.py --disque <travail> -- py -3.9 \
        tools/render/pieces/ressources/icone_blende/icones.py --samples 128 --travail <travail>
    # post-traitement seul (rendu déjà fait) : --post-seul ; ailleurs que dans le mod : --sortie <dossier>

Produit icone.png (icône de l'objet et du gisement) et icone-1.png à icone-3.png (`pictures` de l'objet au sol et sur
tapis), au format vanilla : 64 px + 3 mipmaps (bande 120 × 64, icon_mipmaps = 4), comme icons/iron-ore.png. Les
sommes sha256 et la note « icones » du MANIFEST.json de la feuille sont mises à jour (check_gisement.py les relit).
Formes et matières : reglages.py et piece.py (même modèle que le gisement S8).
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys
import time

import numpy as np

ICI = os.path.dirname(os.path.abspath(__file__))
RES = os.path.dirname(ICI)
RENDER = os.path.abspath(os.path.join(RES, "..", ".."))
MOD = os.path.abspath(os.path.join(RENDER, "..", ".."))
for p in (ICI, RES, RENDER):
    if p not in sys.path:
        sys.path.insert(0, p)
import reglages as R  # noqa: E402
import fo_post as P  # noqa: E402

PIECE = os.path.join(ICI, "piece.py")
BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
SORTIE = os.path.join(MOD, "graphics", "ressources", "blende")
LF = chr(10)
NOMS = ("icone.png", "icone-1.png", "icone-2.png", "icone-3.png")


def rendre(travail, samples):
    os.makedirs(travail, exist_ok=True)
    cmd = [BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1",
           "-P", os.path.join(RENDER, "blender", "render_piece.py"), "--",
           "--piece", PIECE, "--out", travail, "--variant", "tas", "--samples", str(samples),
           "--layers", "main", "--margin", "32"]
    for k in sorted(R.CALIB):
        cmd += ["--set", "%s=%r" % (k, R.CALIB[k])]
    t0 = time.time()
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    with open(os.path.join(travail, "blender.log"), "w", encoding="utf-8") as f:
        f.write(" ".join(cmd) + LF + p.stdout + LF + p.stderr)
    if p.returncode != 0 or "[FO-RENDER]" not in p.stdout:
        raise SystemExit("[FO-ICONE-BLENDE] ECHEC du rendu Blender, journal : %s" % os.path.join(travail, "blender.log"))
    print("[FO-ICONE-BLENDE] rendu : %.1f s (%d échantillons)" % (time.time() - t0, samples))


def recadre(img, cx, cy, s):
    x0, y0 = int(round(cx - s / 2)), int(round(cy - s / 2))
    out = np.zeros((s, s, img.shape[2]))
    H, W = img.shape[:2]
    xa, xb, ya, yb = max(0, x0), min(W, x0 + s), max(0, y0), min(H, y0 + s)
    if xa < xb and ya < yb:
        out[ya - y0:yb - y0, xa - x0:xb - x0] = img[ya:yb, xa:xb]
    return out


def bandes(travail):
    """Les 4 bandes d'icône (64 + 32 + 16 + 8 px) tirées de la passe principale."""
    pre = os.path.join(travail, "icone-blende-tas")
    with open(pre + "-render.json", encoding="utf-8") as f:
        info = json.load(f)
    main = np.load(pre + "-main.npy").astype(np.float64)
    ox, oy = info["origin_px"]
    out = []
    for i in range(len(R.TAS)):
        cx = ox + R.ECART * (i - 1.5) * R.PX_PAR_TUILE
        f = recadre(main, cx, oy, R.CADRE)
        a = f[..., 3]
        # rien ne doit toucher le bord du recadrage (sinon un tas voisin ou un morceau coupé)
        bord = max(a[0].max(), a[-1].max(), a[:, 0].max(), a[:, -1].max())
        if bord > 0.01:
            raise SystemExit("[FO-ICONE-BLENDE] ECHEC : tas %d coupé par le recadrage (alpha %.2f au bord)" % (i, bord))
        out.append(nettete(P.icon_strip(f, fill=0.96)))
    return info, out


def nettete(strip, gain=0.55):
    """Netteté douce (masque flou, rayon 0,7 px) sur chaque taille de la bande, couleur seulement (l'alpha reste celui
    de la réduction) : la réduction 640 → 64 px adoucit les arêtes, les icônes vanilla sont peintes nettes."""
    from PIL import Image, ImageFilter
    out = strip.copy()
    x = 0
    for s in (64, 32, 16, 8):
        bloc = strip[:s, x:x + s]
        a = bloc[..., 3:4]
        # couleur étendue sous l'alpha nul (pas de halo sombre au bord) : moyenne pondérée locale
        rgb = (np.clip(bloc[..., :3], 0, 1) * 255).astype(np.uint8)
        im = Image.fromarray(rgb, "RGB")
        fl = np.asarray(im.filter(ImageFilter.GaussianBlur(0.7))).astype(np.float64) / 255.0
        net = np.clip(bloc[..., :3] + gain * (bloc[..., :3] - fl), 0, 1)
        out[:s, x:x + s, :3] = np.where(a > 0.5, net, bloc[..., :3])
        x += s
    return out


def post(travail, sortie):
    info, strips = bandes(travail)
    sums = {}
    for nom, s in zip(NOMS, strips):
        sums[nom] = P.write_png(s, os.path.join(sortie, nom))
    mp = os.path.join(sortie, "MANIFEST.json")
    if os.path.exists(mp):
        with open(mp, encoding="utf-8") as f:
            man = json.load(f)
        man["sha256"].update(sums)
        man["sha256"] = dict(sorted(man["sha256"].items()))
        man["icones"] = {
            "outil": "tools/render/pieces/ressources/icone_blende/icones.py",
            "rendu": "tas de morceaux de matrice clivés {110} hérissés de tétraèdres tronqués rubis et ambre (modèle S8), "
                     "passe main seule, %g px par tuile" % R.PX_PAR_TUILE,
            "echantillons": info.get("samples"), "secondes_blender": info.get("seconds"),
        }
        with open(mp, "w", encoding="utf-8", newline=LF) as f:
            json.dump(man, f, indent=1, ensure_ascii=False, sort_keys=True)
            f.write(LF)
    for nom in NOMS:
        print("[FO-ICONE-BLENDE] %s %s" % (nom, sums[nom][:16]))
    print("[FO-ICONE-BLENDE] 4 icônes dans %s" % sortie)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--travail", required=True)
    ap.add_argument("--sortie", default=SORTIE)
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--post-seul", action="store_true")
    a = ap.parse_args()
    if not a.post_seul:
        rendre(a.travail, a.samples)
    os.makedirs(a.sortie, exist_ok=True)
    post(a.travail, a.sortie)


if __name__ == "__main__":
    main()
