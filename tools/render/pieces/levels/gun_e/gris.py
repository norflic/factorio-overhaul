"""OUTIL COMMUN : test en gris, UNE SEULE définition de la FORME (règle d'or 3). FICHIER GELÉ. Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/gris.py --out DIR [--json f.json] [--planche gris.png] [--pose E]

FORME (protocole des juges de la passe 3, « FORME_32 », la seule qui compte désormais) : niveau impair de chaque
époque (époque 1 : niveau 2), corps seul (main + lueur de jour), réduit au zoom 1 (32 px/tuile), en gris (luma
Rec. 709 en lumière linéaire, puis sRGB), centré sur l'entité ;
    FORME = (pixels dans un seul des deux masques + pixels communs dont le gris flouté sigma 1,5 diffère de plus de 32)
            / pixels de l'union des masques.
SEUIL : FORME >= 25 % entre deux époques VOISINES DE MÊME TAILLE (1-2, 2-3, 4-5, 5-6, 7-8, 8-9, 10-11, 11-12, 13-14,
14-15) ; les paires qui changent de taille sont imprimées pour mémoire. IoU (recouvrement des masques) est donné à
titre indicatif, il ne décide de rien. Code de sortie 1 si une paire de même taille est sous le seuil.
Avec --planche, la planche en gris des 15 époques (même échelle, zoom 1) est écrite pour le regard.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402

D = K.D
SEUIL = 0.25
T = 14.0   # fenêtre en tuiles (la plus grande emprise, 6×6, avec ses canons, y tient)


def zoom1_gris(out, e, pose):
    lays = K.level_layers(out, e, pose, e == 1, kinds=("main", "glow"))
    if not lays:
        return None, None
    S = int(T * 64)
    acc = np.zeros((S, S, 3), np.float32)
    alpha = np.zeros((S, S), np.float32)
    for l in lays:
        img = l["img"].astype(np.float32)
        h, w = img.shape[:2]
        x0 = int(round(S / 2 + l["shift"][0] * 64 - w / 2))
        y0 = int(round(S / 2 + l["shift"][1] * 64 - h / 2))
        sl = (slice(y0, y0 + h), slice(x0, x0 + w))
        rgb = img[..., :3] ** 2.2
        a = img[..., 3]
        if l["kind"] == "glow":
            acc[sl] += rgb * a[..., None]
            continue
        acc[sl] = rgb * a[..., None] + acc[sl] * (1 - a[..., None])
        alpha[sl] = a + alpha[sl] * (1 - a)
    acc = acc.reshape(S // 2, 2, S // 2, 2, 3).mean(axis=(1, 3))
    alpha = alpha.reshape(S // 2, 2, S // 2, 2).mean(axis=(1, 3))
    rgb = np.where(alpha[..., None] > 1e-3, acc / np.maximum(alpha[..., None], 1e-3), 0)
    g = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    g = np.clip(g, 0, 1) ** (1 / 2.2) * 255
    return g, alpha >= 0.5


def forme(g1, m1, g2, m2):
    u = m1 | m2
    inter = m1 & m2
    b1 = D.masked_blur(g1, m1.astype(np.float32), 1.5)
    b2 = D.masked_blur(g2, m2.astype(np.float32), 1.5)
    ch = (m1 ^ m2) | (inter & (np.abs(b1 - b2) > 32))
    return float(ch.sum() / u.sum()), float(inter.sum() / u.sum())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--json", default="")
    ap.add_argument("--planche", default="")
    ap.add_argument("--pose", default="E")
    ap.add_argument("--epochs", default="1,2,3,4,5,6,7,8,9,10,11,12,13,14,15")
    a = ap.parse_args()
    eps = [int(x) for x in a.epochs.split(",") if x]
    G = {e: zoom1_gris(a.out, e, a.pose) for e in eps}
    res, nko = [], 0
    print("FORME en gris, pose %s, zoom 1 (une seule définition ; seuil %.0f %% entre voisines de même taille)" % (
        a.pose, 100 * SEUIL))
    for e1, e2 in zip(eps, eps[1:]):
        if G[e1][0] is None or G[e2][0] is None or e2 != e1 + 1:
            continue
        f, iou = forme(G[e1][0], G[e1][1], G[e2][0], G[e2][1])
        meme = K.SIDE[e1] == K.SIDE[e2]
        ok = (f >= SEUIL) if meme else True
        nko += not ok
        res.append({"de": e1, "a": e2, "meme_taille": meme, "FORME": f, "IoU": iou, "ok": ok})
        print("  ép.%2d -> %2d %s : FORME %5.1f %%  (IoU %.3f)  %s" % (
            e1, e2, "même taille   " if meme else "taille change ", 100 * f, iou,
            ("ok" if ok else "<-- SOUS LE SEUIL") if meme else "(pour mémoire)"))
    if a.json:
        json.dump(res, open(a.json, "w", encoding="utf-8"), indent=1)
    if a.planche:
        cw = int(T * 32)
        cols = 5
        rows_ = (len(eps) + cols - 1) // cols
        sheet = Image.new("L", (cols * (cw + 6) + 6, rows_ * (cw + 30) + 40), 24)
        dr = ImageDraw.Draw(sheet)
        dr.text((8, 8), "Test en gris · pose %s · zoom 1 · niveau impair (époque 1 : niveau 2)" % a.pose, fill=230,
                font=K.font(18))
        for i, e in enumerate(eps):
            g, m = G[e]
            if g is None:
                continue
            bg = np.full(g.shape, 60.0)
            img = np.where(m, g, bg).astype(np.uint8)
            x = 6 + (i % cols) * (cw + 6)
            y = 40 + (i // cols) * (cw + 30)
            sheet.paste(Image.fromarray(img, "L"), (x, y + 24))
            dr.text((x + 4, y + 4), "%d · %s" % (e, K.NAME[e]), fill=230, font=K.font(14))
        sheet.save(a.planche)
        print(a.planche)
    print("[FO-GRIS] %d paire(s) de même taille sous le seuil" % nko)
    sys.exit(1 if nko else 0)


if __name__ == "__main__":
    main()
