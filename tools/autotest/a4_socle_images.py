"""Socle émissif animé (lots A4 et A4-SOCLE) : le moteur anime-t-il base_picture, âge par âge ? Mesure sur les captures
de nuit du scénario a4-socle. Python 3.9.

    py -3.9 tools/autotest/a4_socle_images.py "<fo-shots de fo-captures.bat a4-socle>" [--planche SORTIE.png]
                                              [--gif DOSSIER] [--seuil 100] [--distinctes 4]

Table : fo-shots/a4-socle-sites.tsv (écrite par le scénario). Deux séries par site, indépendantes :
- INSTANTS : 8 captures de nuit du site (genre « site »), à 130 ticks d'écart (21,67 images du cycle de 16) ;
- SUITE : les 10 captures successives de nuit de son ère (genre « suite », 10 ticks d'écart, 1,67 image), découpées
  autour du site (même carré que la capture du site : (emprise + 4) × 64 px au zoom 2).
Deux images sont DISTINCTES si plus de `--seuil` pixels (100 : seuil du pilote de l'âge 6) changent de plus de 3 (sur
255) sur un canal. Images distinctes d'une série : regroupement glouton (une image qui ne diffère d'aucune déjà gardée
ne compte pas).
- Témoin (socle FIXE, âge 4, `temoin` = 1) : toutes les images de chaque série identiques au pixel.
- Socle animé (âges 5 à 15) : au moins `--distinctes` (4) images distinctes dans CHAQUE série. Seuil fixé AVANT le
  passage qui le juge (24/10, 21 h 45), sur la prévision des motifs (`anim_emission.py`) : 5 à 8 aux instants, 5 à 10 à
  la suite ; l'âge 14 (« souffle », 2 battements) n'a que 5 niveaux de lumière (m = 1 + 0,3 sin(πk/4)).
  Premier passage (instants à 120 ticks = 4 images) : l'âge 14 montrait 8 fois la MÊME image (m = 1 aux images 0, 4,
  8, 12) : repliement de l'échantillonnage, d'où l'écart de 130 ticks et la seconde série.
Écrits aussi : pixels qui changent d'une image à la suivante, énergie de chaque instant rapportée à la moyenne.
Code 0 si le témoin est fixe et les 11 socles animés bougent dans les deux séries.
--planche : une rangée par site (8 instants de nuit côte à côte).
--gif : par ère, un GIF des 10 captures successives (vitesse du jeu : 167 ms par image ; palette commune, découpe autour
  des 3 tourelles) et une planche (images 1, 4, 7, 10, puis l'écart max à l'image 1 × 6).
"""
import argparse
import csv
import glob
import os
import sys

import numpy as np
from PIL import Image

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ORDRE = ["I", "II", "III", "IV", "V"]


def fichier(shots, capture):
    f = glob.glob(os.path.join(shots, "[0-9][0-9][0-9]-%s.png" % capture))
    if len(f) != 1:
        raise SystemExit("[FO-A4-SOCLE-IMG] capture %s : %d fichier(s)" % (capture, len(f)))
    return f[0]


def lire(shots, capture):
    return np.asarray(Image.open(fichier(shots, capture)).convert("RGB")).astype(np.int32)


def emprise(n):
    return 2 + (n - 1) // 6


def change(a, b):
    return int((np.abs(a - b).max(-1) > 3).sum())


def distinctes(ims, seuil):
    gardees = []
    for im in ims:
        if all(change(im, g) > seuil for g in gardees):
            gardees.append(im)
    return len(gardees)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("shots")
    ap.add_argument("--planche", default=None)
    ap.add_argument("--gif", default=None)
    ap.add_argument("--seuil", type=int, default=100)
    ap.add_argument("--distinctes", type=int, default=4)
    a = ap.parse_args()
    rows = list(csv.DictReader(open(os.path.join(a.shots, "a4-socle-sites.tsv"), encoding="utf-8"), delimiter="\t"))
    suites = {}
    for r in rows:
        if r["genre"] == "suite":
            suites.setdefault(r["ere"], []).append(r)
    for era in suites:
        suites[era].sort(key=lambda r: int(r["instant"]))
    cache = {}

    def suite_im(r):
        if r["capture"] not in cache:
            cache[r["capture"]] = lire(a.shots, r["capture"])
        return cache[r["capture"]]

    par, info = {}, {}
    for r in rows:
        if r["genre"] == "site" and r["nuit"] == "1":
            k = (int(r["age"]), int(r["niveau"]))
            par.setdefault(k, []).append((int(r["instant"]), lire(a.shots, r["capture"])))
            info[k] = r
    ko = 0
    n_anim = n_tem = 0
    for k in sorted(par):
        age, n = k
        r0 = info[k]
        ims = [im for _, im in sorted(par[k], key=lambda t: t[0])]
        st = np.stack(ims)
        zone = st.sum(-1).max(0) > 60
        bouge = [change(st[i + 1], st[i]) for i in range(len(ims) - 1)]
        en = st.sum(-1)[:, zone].sum(1).astype(np.float64) if zone.any() else np.ones(len(ims))
        e_rel = en / en.mean()
        d_inst = distinctes(ims, a.seuil)
        # seconde série : la suite de l'ère, découpée autour du site
        sr = suites.get(r0["ere"], [])
        crops = []
        for s in sr:
            im = suite_im(s)
            h, w = im.shape[:2]
            cx = w / 2 + (float(r0["x"]) - float(s["x"])) * 64
            cy = h / 2 + (float(r0["y"]) - 0.5 - float(s["y"])) * 64
            demi = (emprise(n) + 4) * 32
            x0, x1 = int(max(0, cx - demi)), int(min(w, cx + demi))
            y0, y1 = int(max(0, cy - demi)), int(min(h, cy + demi))
            crops.append(im[y0:y1, x0:x1])
        d_suite = distinctes(crops, a.seuil) if crops else 0
        bouge_s = [change(crops[i + 1], crops[i]) for i in range(len(crops) - 1)]
        if r0["temoin"] == "1":
            n_tem += 1
            ok = int(np.abs(st - st[0]).max()) == 0 and len(crops) > 1 and \
                max(int(np.abs(c - crops[0]).max()) for c in crops) == 0
            genre = "témoin, socle fixe"
        else:
            n_anim += 1
            ok = d_inst >= a.distinctes and d_suite >= a.distinctes
            genre = "socle animé"
        ko += not ok
        print("[FO-A4-SOCLE-IMG] %s âge %2d niveau %2d (%s) : images distinctes : instants %d sur %d, suite %d sur %d ; "
              "pixels qui changent (instants) %s ; (suite) %s ; énergie relative (instants) %s" % (
                  "OK    " if ok else "ECHEC ", age, n, genre, d_inst, len(ims), d_suite, len(crops), bouge, bouge_s,
                  [round(float(x), 3) for x in e_rel]))
    if n_tem != 1 or n_anim != 11:
        ko += 1
        print("[FO-A4-SOCLE-IMG] ECHEC  sites : %d témoin(s), %d socle(s) animé(s) ; attendu 1 et 11" % (n_tem, n_anim))
    if a.planche:
        lignes = []
        larg = max(max(im.shape[1] for _, im in v) for v in par.values()) * 8
        for k in sorted(par):
            ims = [im for _, im in sorted(par[k], key=lambda t: t[0])]
            l = np.concatenate(ims, axis=1)
            fond = np.zeros((l.shape[0], larg, 3), np.int32)
            fond[:, :l.shape[1]] = l
            lignes.append(fond)
        Image.fromarray(np.clip(np.concatenate(lignes, axis=0), 0, 255).astype(np.uint8)).save(a.planche)
        print("[FO-A4-SOCLE-IMG] planche : %s" % a.planche)
    if a.gif:
        os.makedirs(a.gif, exist_ok=True)
        for era in sorted(suites, key=lambda e: (ORDRE.index(e) if e in ORDRE else 99, e)):
            ims = [suite_im(s) for s in suites[era]]
            # découpe en largeur : des tourelles de l'ère, ± (emprise + 3) / 2 tuiles autour des centres extrêmes
            sites = [info[k] for k in info if info[k]["ere"] == era]
            h, w = ims[0].shape[:2]
            s0 = suites[era][0]
            xs = [w / 2 + (float(r["x"]) - float(s0["x"])) * 64 for r in sites]
            demi = max((emprise(int(r["niveau"])) + 3) * 32 for r in sites)
            x0, x1 = int(max(0, min(xs) - demi)), int(min(w, max(xs) + demi))
            fr = [Image.fromarray(im[:, x0:x1].astype(np.uint8)) for im in ims]
            pal = fr[0].quantize(colors=255, method=Image.MEDIANCUT)
            q = [f.quantize(palette=pal, dither=Image.NONE) for f in fr]
            g = os.path.join(a.gif, "socle-ere-%s-z2-nuit.gif" % era)
            q[0].save(g, save_all=True, append_images=q[1:], duration=167, loop=0, optimize=False)
            choix = [ims[i][:, x0:x1] for i in (0, 3, 6, 9) if i < len(ims)]
            ecart = np.abs(np.stack([im[:, x0:x1] for im in ims]) - ims[0][:, x0:x1]).max(0) * 6
            p = np.concatenate(choix + [ecart], axis=0)
            pl = os.path.join(a.gif, "socle-ere-%s-z2-nuit-suite.png" % era)
            Image.fromarray(np.clip(p, 0, 255).astype(np.uint8)).save(pl)
            print("[FO-A4-SOCLE-IMG] ère %s : %d images successives -> %s (%d ko), %s" % (
                era, len(ims), g, os.path.getsize(g) // 1024, pl))
    print("[FO-A4-SOCLE-IMG] BILAN : %d ECHEC(S)" % ko)
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
