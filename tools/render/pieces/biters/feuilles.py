"""FEUILLES DE JEU DES SOUCHES (lot BI-V1) : rendus -> graphics/biters/ (PNG hors de git, décision D-6), sprites.lua (généré, lu par prototypes/souches.lua),
MANIFEST.json (commité).
    PYTHONUTF8=1 py -3.9 tools/render/pieces/biters/feuilles.py [--src DIR] [--dest DIR] [--brouillon]        (depuis la racine du mod)
Sources : fo-logs/2026-11-01_BIV1/rendu (à GARDER). Une feuille par couche et par animation, en lecture continue sur 2 × images colonnes, moins si la feuille passerait 8 192 px (F144 ; `ll` : images par ligne), cellule = union des
rognages de toutes les images. hr- : densité du rendu ; sans préfixe : le quart (16 px par tuile environ, PLAN §5). --brouillon : une image ou une direction
manquante prend la plus proche (essai du pipeline, jamais pour livrer) ; sans lui, un manque est une erreur.
Le poids imprimé suit le PLAN §5 mais avec le rognage MESURÉ image par image, sans le 0,73 estimé : Mpx × rangement (1,19 haute, 1,44 normale, F187), ombres à part (F148).
"""
import argparse
import glob
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402

SRC_DEFAUT = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-11-01_BIV1\rendu"
DEST_DEFAUT = os.path.join(MOD, "graphics", "biters")
PREFIXE = "__factorio-overhaul__/graphics/biters/"
SOUCHES = {"moucheron": {"course": 6, "attaque": 3, "K": 4.23, "foulee": 0.548}, "ecraseur": {"course": 6, "attaque": 3, "K": 0.5, "foulee": 3.17}}
REDUC = 4
SEUIL = 2
PLUS_PETIT_AMAS = 12   # pixels : un amas plus petit, dans le liseré de contact ou l'ombre, est du bruit de rendu (BITERS-JEU)
SEUIL_OMBRE = 24       # sur 255 (le moteur affiche l'ombre à 50 % : 4,7 %) ; en dessous : poussière et liseré du bord du cadre, à 32 échantillons.
                       # L'ombre rendue est presque binaire (écraseur : 9,8 % du cadre > 2, 9,2 % > 128) : son bord n'y perd presque rien.


def chercher(d, s, anim, i, k, nb, brouillon):
    p = os.path.join(d, s, "%s-%s-%02d-%02d.npz" % (s, anim, i, k))
    if os.path.exists(p):
        return p
    if not brouillon:
        raise SystemExit("MANQUE : " + p)
    for di in range(nb):
        for ii in ((i + di) % nb, (i - di) % nb):
            for dk in range(16):
                for kk in ((k + dk) % 16, (k - dk) % 16):
                    q = os.path.join(d, s, "%s-%s-%02d-%02d.npz" % (s, anim, ii, kk))
                    if os.path.exists(q):
                        return q
    raise SystemExit("AUCUNE SOURCE : %s %s" % (s, anim))


def sans_points_isoles(a, seuil, mini=PLUS_PETIT_AMAS):
    """Masque des pixels de `a` (> seuil) qui appartiennent à un amas d'au moins `mini` pixels (8-connexité). Lot BITERS-JEU : le bruit
    de l'AO et de l'ombre à 32 échantillons sème des pixels isolés (alpha 4 à 13 sur 255) sur tout le cadre ; ils empêchent le moteur de
    rogner chaque image (F147) et font payer le cadre entier à l'atlas, sans rien montrer."""
    m = a > seuil
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    if n == 0:
        return m
    tailles = ndimage.sum(m, lab, range(1, n + 1))
    garde = np.zeros(n + 1, bool)
    garde[1:] = tailles >= mini
    return garde[lab]


def boite(a):
    ys, xs = np.where(a > SEUIL)
    if not len(xs):
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def reduit(img, n):
    """RGBA 8 bits -> réduit d'un facteur n, en lumière linéaire prémultipliée, par moyenne (taille multiple de n)."""
    h, w = img.shape[:2]
    f = img.astype(np.float64) / 255.0
    a = f[..., 3:4]
    lin = P.srgb_to_lin(f[..., :3]) * a
    x = np.concatenate([lin, a], axis=-1).reshape(h // n, n, w // n, n, 4).mean((1, 3))
    rgb = np.where(x[..., 3:4] > 1e-5, x[..., :3] / np.maximum(x[..., 3:4], 1e-5), 0.0)
    return np.round(np.clip(np.concatenate([P.lin_to_srgb(np.clip(rgb, 0, 1)), x[..., 3:4]], -1), 0, 1) * 255).astype(np.uint8)


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    ap.add_argument("--brouillon", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for f in glob.glob(os.path.join(a.dest, "*.png")):
        os.remove(f)
    table = {}
    fichiers = {}
    poids = {}
    for s, cfg in SOUCHES.items():
        table[s] = {"K": cfg["K"], "foulee": cfg["foulee"]}
        poids[s] = {"haute": 0.0, "plancher": 0.0, "ombre": 0.0, "images": 0}
        for anim in ("course", "attaque"):
            nb = cfg[anim]
            images = {}
            for k in range(16):
                for i in range(nb):
                    z = np.load(chercher(a.src, s, anim, i, k, nb, a.brouillon))
                    # liseré de contact sous la créature (sa couleur est droite), portée propre au modèle sans effet ici
                    # (même composition que P.compose_main, avec le liseré nettoyé de ses points isolés)
                    fr = P.contact_fringe(z["ao"].astype(np.float64) / 255.0, C.AO_STRENGTH, C.AO_GAMMA, C.AO_COLOR)
                    fr[..., 3] *= sans_points_isoles(fr[..., 3], SEUIL / 255.0)
                    mn = P.over(z["main"].astype(np.float64) / 255.0, fr)
                    mn = np.round(np.clip(mn, 0, 1) * 255).astype(np.uint8)
                    om = np.where(sans_points_isoles(z["ombre"], SEUIL_OMBRE), z["ombre"], 0).astype(np.uint8)
                    images[(k, i)] = (mn, om, z["masque"], z["origine"], float(z["densite"][0]))
            D = images[(0, 0)][4]
            ox, oy = images[(0, 0)][3]
            H0, W0 = images[(0, 0)][0].shape[:2]
            bb = {"main": [], "ombre": []}
            for (mn, om, _ms, _o, _d) in images.values():
                bb["main"].append(boite(mn[..., 3]))
                bb["ombre"].append(boite(om))
            uni = {}
            for c, l in bb.items():
                l = [x for x in l if x is not None]
                x0, y0 = min(x[0] for x in l), min(x[1] for x in l)
                x1, y1 = max(x[2] for x in l), max(x[3] for x in l)
                # cellule alignée sur la réduction : largeur et hauteur multiples de REDUC
                x0, y0 = x0 - x0 % REDUC, y0 - y0 % REDUC
                x1, y1 = min(W0, x1 + (-x1) % REDUC), min(H0, y1 + (-y1) % REDUC)
                uni[c] = (x0, y0, x1 - (x1 - x0) % REDUC, y1 - (y1 - y0) % REDUC)
            couches = {}
            for c, nomc in (("main", "main"), ("main", "mask"), ("ombre", "shadow")):
                x0, y0, x1, y1 = uni[c]
                cw, ch = x1 - x0, y1 - y0
                ll = min(nb * 2, 8192 // cw)
                lignes = (16 * nb + ll - 1) // ll
                assert ch * lignes <= 8192, (s, anim, nomc, ch, lignes)
                feuille = np.zeros((ch * lignes, cw * ll, 4), np.uint8)
                for (k, i), (mn, om, ms, _o, _d) in images.items():
                    if nomc == "main":
                        t = mn[y0:y1, x0:x1]
                    elif nomc == "mask":
                        t = np.zeros((ch, cw, 4), np.uint8)
                        lum = (0.2126 * mn[y0:y1, x0:x1, 0] + 0.7152 * mn[y0:y1, x0:x1, 1] + 0.0722 * mn[y0:y1, x0:x1, 2]) / 255.0
                        g = np.round(np.clip(lum * 1.9, 0, 1) * 255).astype(np.uint8)
                        t[..., 0], t[..., 1], t[..., 2] = g, g, g
                        t[..., 3] = (ms[y0:y1, x0:x1].astype(np.float64) * mn[y0:y1, x0:x1, 3] / 255.0).astype(np.uint8)
                    else:
                        t = np.zeros((ch, cw, 4), np.uint8)
                        t[..., 3] = om[y0:y1, x0:x1]
                    lig, col = divmod(k * nb + i, ll)
                    feuille[lig * ch:(lig + 1) * ch, col * cw:(col + 1) * cw] = t
                    if nomc != "shadow":
                        bx = boite(t[..., 3])
                        if bx:
                            aire = (bx[2] - bx[0]) * (bx[3] - bx[1]) / 1e6
                            poids[s]["haute"] += aire * 1.19
                            poids[s]["plancher"] += aire / (REDUC * REDUC) * 1.44
                    else:
                        bx = boite(t[..., 3])
                        if bx:
                            poids[s]["ombre"] += (bx[2] - bx[0]) * (bx[3] - bx[1]) / 1e6 / (REDUC * REDUC)
                poids[s]["images"] = poids[s]["images"] + (16 * nb if nomc == "main" else 0)
                nom_hr = "hr-%s-%s-%s.png" % (s, anim, nomc)
                nom_lr = "%s-%s-%s.png" % (s, anim, nomc)
                Image.fromarray(feuille, "RGBA").save(os.path.join(a.dest, nom_hr), optimize=True)
                lr = reduit(feuille, REDUC)
                Image.fromarray(lr, "RGBA").save(os.path.join(a.dest, nom_lr), optimize=True)
                sft = ((x0 + x1) / 2.0 - ox, (y0 + y1) / 2.0 - oy)
                couches[nomc] = {"hr": PREFIXE + nom_hr, "lr": PREFIXE + nom_lr, "w": int(cw), "h": int(ch), "lw": int(cw // REDUC), "lh": int(ch // REDUC), "ll": int(ll),
                                 "sx": round(sft[0] / D, 5), "sy": round(sft[1] / D, 5)}
                for nm in (nom_hr, nom_lr):
                    pth = os.path.join(a.dest, nm)
                    with Image.open(pth) as im:
                        fichiers[nm] = {"sha256": sha(pth), "taille": os.path.getsize(pth), "largeur": im.size[0], "hauteur": im.size[1]}
            table[s][anim] = {"images": nb, "densite": D, "reduc": REDUC, "couches": couches}
    # sprites.lua : table pure, ordre fixe
    L = ["-- GÉNÉRÉ par tools/render/pieces/biters/feuilles.py : ne pas modifier. Images hors de git (D-6) : voir MANIFEST.json.", "return {"]
    for s in SOUCHES:
        t = table[s]
        L.append('  %s = { K = %s, foulee = %s,' % (s, t["K"], t["foulee"]))
        for anim in ("course", "attaque"):
            x = t[anim]
            L.append('    %s = { images = %d, densite = %s, reduc = %d, couches = {' % (anim, x["images"], x["densite"], x["reduc"]))
            for nomc in ("main", "mask", "shadow"):
                c = x["couches"][nomc]
                L.append('      %s = { hr = "%s", lr = "%s", w = %d, h = %d, lw = %d, lh = %d, ll = %d, sx = %s, sy = %s },' % (nomc, c["hr"], c["lr"], c["w"], c["h"], c["lw"], c["lh"], c["ll"], c["sx"], c["sy"]))
            L.append('    } },')
        L.append('  },')
    L.append('}')
    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    man = {"commande": "PYTHONUTF8=1 py -3.9 tools/render/pieces/biters/feuilles.py   (depuis la racine du mod ; sources : fo-logs/2026-11-01_BIV1/rendu, à GARDER)",
           "brouillon": bool(a.brouillon), "poids_mpx": {s: {k: round(v, 2) for k, v in p.items()} for s, p in poids.items()}, "fichiers": dict(sorted(fichiers.items()))}
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    total = sum(os.path.getsize(os.path.join(a.dest, n)) for n in fichiers) / 1e6
    print("[FO-FEUILLES-BITERS] %d fichiers PNG, %.2f Mo%s" % (len(fichiers), total, " (BROUILLON)" if a.brouillon else ""))
    for s, p in poids.items():
        print("  %s : %d images ; haute %.1f Mpx ; plancher %.2f Mpx ; ombres plancher %.2f Mpx" % (s, p["images"], p["haute"], p["plancher"], p["ombre"]))
    print("  total : haute %.1f Mpx ; plancher %.2f Mpx" % (sum(p["haute"] for p in poids.values()), sum(p["plancher"] for p in poids.values())))


if __name__ == "__main__":
    main()
