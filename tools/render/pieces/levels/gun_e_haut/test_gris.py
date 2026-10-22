"""Vignettes à l'aveugle et TEST NOIR ET BLANC du lot V3-E (époques 10 à 15), exigences (c), (d) et livrable 3.

    py -3.9 tools/render/pieces/levels/gun_e_haut/test_gris.py <racine>/data <dossier vignettes> <dossier vignettes-gris>
           [--essai]   (--essai : mesures seulement, aucune image écrite dans les dossiers partagés)

Pour chaque époque (niveau impair, pose E, de jour, zoom 1) : le bâtiment seul (socle + tête) composé sur le sol
vanilla (hr-dirt-4, ombre comprise), cadre carré 384 × 384 px centré sur l'entité, sans légende. Nom de fichier
ALÉATOIRE (8 hexadécimaux) ; la version grise a un AUTRE nom aléatoire. La correspondance n'est écrite que sur la
sortie standard (jamais sur le disque).

Mesures entre époques voisines (zoom 1, gris = luminance Rec. 709 calculée en linéaire, ramenée en sRGB) :
  dam_cadre : différence absolue moyenne des deux vignettes grises alignées (cadre entier, 0 à 255) ;
  dam_bat   : la même, sur l'union des deux masques du bâtiment seulement ;
  iou       : IoU des masques alpha (couche principale, alpha ≥ 0,5) ;
  forme     : part de l'union des masques dont la FORME change : pixels hors de l'intersection des masques, plus
              pixels communs dont le gris flouté (σ = 1,5 px) du bâtiment seul diffère de plus de 32 niveaux.
Repère de « petit écart » : les mêmes mesures entre le niveau impair et le niveau pair de la même époque (une pièce
ajoutée aux coins avant) : deux voisines doivent s'écarter nettement plus que ce repère.
"""
import argparse
import os
import secrets
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import planche as PL  # noqa: E402
import planches_e as PE  # noqa: E402

EP = (10, 11, 12, 13, 14, 15)


def lin(rgb):
    return np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)


def srgb(x):
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(np.clip(x, 0, 1), 1 / 2.4) - 0.055)


def gray(rgb):
    L = lin(rgb)
    return srgb(0.2126 * L[..., 0] + 0.7152 * L[..., 1] + 0.0722 * L[..., 2])


def building(e, piece=False, W=12.0):
    """Bâtiment seul (couches principales, sans sol) au zoom 2 sur canevas W × W tuiles : (rgb, alpha)."""
    ppt = 64
    n = int(W * ppt)
    rgb = np.zeros((n, n, 3))
    al = np.zeros((n, n))
    for lay in PE.ent(e, "E", piece):
        if lay["kind"] != "main":
            continue
        img = lay["img"]
        h, w = img.shape[:2]
        x0 = int(round(W / 2 * ppt + lay["shift"][0] * ppt - w / 2.0))
        y0 = int(round(W / 2 * ppt + lay["shift"][1] * ppt - h / 2.0))
        a = img[..., 3:4]
        rgb[y0:y0 + h, x0:x0 + w] = img[..., :3] * a + rgb[y0:y0 + h, x0:x0 + w] * (1 - a)
        al[y0:y0 + h, x0:x0 + w] = a[..., 0] + al[y0:y0 + h, x0:x0 + w] * (1 - a[..., 0])
    # zoom 1 : moyenne 2 × 2 (alpha prémultiplié)
    pre = np.concatenate([rgb * al[..., None], al[..., None]], -1)
    pre = pre.reshape(n // 2, 2, n // 2, 2, 4).mean((1, 3))
    a1 = pre[..., 3]
    rgb1 = pre[..., :3] / np.maximum(a1[..., None], 1e-6)
    return rgb1, a1


def blur(x, s):
    r = int(3 * s)
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / s) ** 2)
    k /= k.sum()
    y = np.apply_along_axis(lambda v: np.convolve(v, k, mode="same"), 0, x)
    return np.apply_along_axis(lambda v: np.convolve(v, k, mode="same"), 1, y)


def vignette(data, e, piece=False):
    day, _ = PL.compose(data, [{"pos": (6.0, 6.0), "layers": PE.ent(e, "E", piece)}], 12.0, 12.0)
    v = PL.down2(day)
    assert v.shape[:2] == (384, 384), v.shape
    return v


def compare(A, B):
    ga, gb = gray(A["vig"]) * 255, gray(B["vig"]) * 255
    ma, mb = A["a"] >= 0.5, B["a"] >= 0.5
    uni, inter = ma | mb, ma & mb
    dam_cadre = float(np.abs(ga - gb).mean())
    dam_bat = float(np.abs(ga - gb)[uni].mean())
    iou = float(inter.sum() / max(1, uni.sum()))
    ba = blur(gray(A["rgb"]) * A["a"], 1.5) * 255
    bb = blur(gray(B["rgb"]) * B["a"], 1.5) * 255
    changed = (uni & ~inter) | (inter & (np.abs(ba - bb) > 32))
    forme = float(changed.sum() / max(1, uni.sum()))
    return dict(dam_cadre=dam_cadre, dam_bat=dam_bat, iou=iou, forme=forme)


def unique_name(folder):
    while True:
        n = secrets.token_hex(4) + ".png"
        if not os.path.exists(os.path.join(folder, n)):
            return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("data")
    ap.add_argument("vig")
    ap.add_argument("vig_gris")
    ap.add_argument("--essai", action="store_true")
    a = ap.parse_args()
    S = {}
    for e in EP:
        rgb, al = building(e)
        S[e] = {"vig": vignette(a.data, e), "rgb": rgb, "a": al}
        rgbp, alp = building(e, True)
        S[(e, "p")] = {"vig": vignette(a.data, e, True), "rgb": rgbp, "a": alp}
    if not a.essai:
        os.makedirs(a.vig, exist_ok=True)
        os.makedirs(a.vig_gris, exist_ok=True)
        for e in EP:
            n1 = unique_name(a.vig)
            PL.to_im(S[e]["vig"]).save(os.path.join(a.vig, n1))
            n2 = unique_name(a.vig_gris)
            g = np.clip(np.round(gray(S[e]["vig"]) * 255), 0, 255).astype(np.uint8)
            Image.fromarray(g, "L").save(os.path.join(a.vig_gris, n2))
            print("VIGNETTE epoque=%d niveau=%d couleur=%s gris=%s" % (e, 2 * e - 1, os.path.join(a.vig, n1),
                                                                        os.path.join(a.vig_gris, n2)))
    print("voisines (pose E, zoom 1, gris) : dam_cadre / dam_bat / IoU masques / forme changée")
    for e0, e1 in zip(EP[:-1], EP[1:]):
        r = compare(S[e0], S[e1])
        print("  %d -> %d : %.1f / %.1f / %.3f / %.1f %%" % (e0, e1, r["dam_cadre"], r["dam_bat"], r["iou"],
                                                            100 * r["forme"]))
    print("repère (impair -> pair, même époque) :")
    for e in EP:
        r = compare(S[e], S[(e, "p")])
        print("  %d -> %d+pièce : %.1f / %.1f / %.3f / %.1f %%" % (e, e, r["dam_cadre"], r["dam_bat"], r["iou"],
                                                                 100 * r["forme"]))


if __name__ == "__main__":
    main()
