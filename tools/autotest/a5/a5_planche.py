"""Lot A5-ESSAI (25/10) : mesure et planches des captures du scénario a5-equipe. Python 3.9 (numpy, Pillow).

    py -3.9 tools/autotest/a5/a5_planche.py --avec <fo-shots de la copie> --sans <fo-shots du témoin> --out DIR

--avec : session de la copie jetable (colonnes 2 à 4 masquées à 25, 40, 60 % ; colonne 1 = niveau du mod) ;
--sans : session du mod sans masque, MÊMES positions et même sol (le niveau du mod partout).
Mesure, par capture et par tourelle : pixels changés (écart > 8/255 sur un canal) entre les deux sessions, couleur
moyenne avant / après sur ces pixels (teinte, saturation). La colonne 1 doit donner 0 pixel changé (contrôle : même
image, même place). Planches : DIR/planche-eNN-z2.png (jour au-dessus, nuit au-dessous, étiquettes), DIR/planche-z1.png
(les 3 âges au zoom 1, jour et nuit), DIR/mesure.txt.
"""
import argparse
import colorsys
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

COLS = ["sans masque", "25 %", "40 %", "60 %"]
ROWS = {"player": "joueur (défaut)", "fo-scarlet": "écarlate", "fo-azure": "azur"}


def police(t):
    for f in (r"C:\Windows\Fonts\segoeui.ttf", r"C:\Windows\Fonts\arial.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, t)
    return ImageFont.load_default()


def tsv(p):
    L = open(p, encoding="utf-8").read().strip().splitlines()
    h = L[0].split("\t")
    return [dict(zip(h, l.split("\t"))) for l in L[1:]]


def capture(d, scene):
    g = glob.glob(os.path.join(d, "*-%s.png" % scene))
    if len(g) != 1:
        raise SystemExit("%s : %d capture(s) %s" % (d, len(g), scene))
    return np.asarray(Image.open(g[0]).convert("RGB"))


QUESTIONS = [
    "Q-A5-1. Force de la couleur d'équipe : (A) 25 % (à peine teinté) ; (B) 40 % (lisible de près, palette gardée) ;",
    "         (C) 60 % (bien lisible, plus saturé). Recommandation de l'agent : B.",
    "Q-A5-2. Quelles pièces : (A) celles de l'essai (chapeau du dessus + liserés ou plaques) ; (B) le chapeau seul,",
    "         une pièce compacte, 7 à 32 fois moins chère en mémoire vidéo (âge 15 : à trouver, le dôme n'a pas de",
    "         chapeau visible) ; (C) autre chose (dire laquelle).",
    "Q-A5-3. La nuit, la couleur ne se voit presque plus : (A) c'est bien ainsi ; (B) ajouter un petit voyant",
    "         lumineux à la couleur de l'équipe (à essayer, non fait).",
]


def planche_dc(a):
    """Planche pour le Directeur Créatif : gros plans de jour (âges 3 agrandi × 2, 9, 15), nuit de l'âge 9, questions."""
    f_t, f_p = police(34), police(26)
    parts = []
    for nom in a.dc.split(","):
        im = Image.open(os.path.join(a.out, nom))
        k = float(a.largeur) / im.size[0]
        parts.append(im.resize((a.largeur, int(im.size[1] * k)), Image.LANCZOS))
    haut = 70
    bas = 50 + 36 * len(QUESTIONS)
    out = Image.new("RGB", (a.largeur, haut + sum(p.size[1] + 12 for p in parts) + bas), (22, 22, 22))
    dr = ImageDraw.Draw(out)
    dr.text((14, 14), "Couleur d'équipe de la mitrailleuse : ESSAI sur 3 âges (en jeu, zoom 2)", font=f_t,
            fill=(255, 220, 120))
    y = haut
    for p in parts:
        out.paste(p, (0, y))
        y += p.size[1] + 12
    y += 14
    for q in QUESTIONS:
        dr.text((14, y), q, font=f_p, fill=(255, 255, 255))
        y += 36
    p = os.path.join(a.out, "planche-DC.png")
    out.save(p, optimize=True)
    print("[A5-PLANCHE] %s : %d × %d" % (p, out.size[0], out.size[1]))
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--avec", required=True)
    ap.add_argument("--sans", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--agrandir", type=int, default=1)
    ap.add_argument("--dc", default="", help="images de --out à empiler dans planche-DC.png (liste)")
    ap.add_argument("--largeur", type=int, default=1600)
    a = ap.parse_args()
    if a.dc:
        return planche_dc(a)
    os.makedirs(a.out, exist_ok=True)
    caps = tsv(os.path.join(a.avec, "a5-equipe-captures.tsv"))
    sites = tsv(os.path.join(a.avec, "a5-equipe-sites.tsv"))
    lignes = []
    f_t, f_p = police(30), police(22)
    z1 = []
    for c in caps:
        age, z, nuit = int(c["age"]), int(c["zoom"]), c["nuit"] == "1"
        cx, cy, px, py = float(c["x"]), float(c["y"]), int(c["px"]), int(c["py"])
        A = capture(a.avec, c["capture"])
        S = capture(a.sans, c["capture"])
        if A.shape != S.shape:
            raise SystemExit("%s : tailles différentes" % c["capture"])
        H, W = A.shape[:2]
        k = 32.0 * z
        diff = np.abs(A.astype(int) - S.astype(int)).max(-1) > 8
        for s in [s for s in sites if int(s["age"]) == age]:
            x, y = float(s["x"]), float(s["y"])
            u0, u1 = int(W / 2 + (x - px / 2.0 - cx) * k), int(W / 2 + (x + px / 2.0 - cx) * k)
            v0, v1 = int(H / 2 + (y - py / 2.0 - 0.6 - cy) * k), int(H / 2 + (y + py / 2.0 - 0.6 - cy) * k)
            u0, v0, u1, v1 = max(0, u0), max(0, v0), min(W, u1), min(H, v1)
            m = diff[v0:v1, u0:u1]
            n = int(m.sum())
            txt = "%-10s %-11s i%-2s %6d px changés" % (c["capture"], s["force"], s["intensite"], n)
            if n:
                ca = A[v0:v1, u0:u1][m].mean(0) / 255.0
                cs = S[v0:v1, u0:u1][m].mean(0) / 255.0
                ha, sa, va = colorsys.rgb_to_hsv(*ca)
                hs, ss, vs = colorsys.rgb_to_hsv(*cs)
                txt += " ; avant (%.2f %.2f %.2f) teinte %3.0f° sat %.2f val %.2f -> après (%.2f %.2f %.2f) teinte %3.0f° sat %.2f val %.2f" % (
                    cs[0], cs[1], cs[2], hs * 360, ss, vs, ca[0], ca[1], ca[2], ha * 360, sa, va)
            lignes.append(txt)
        # planche étiquetée (la capture AVEC : colonne 1 = niveau du mod sans masque)
        marge_g, marge_h = 210, 46
        img = Image.new("RGB", (W + marge_g, H + marge_h), (22, 22, 22))
        img.paste(Image.fromarray(A), (marge_g, marge_h))
        dr = ImageDraw.Draw(img)
        for i, nm in enumerate(COLS):
            dr.text((marge_g + int((i + 0.5) * W / 4.0) - 60, 8), nm, font=f_t, fill=(255, 255, 255))
        for j, f in enumerate(["player", "fo-scarlet", "fo-azure"]):
            dr.text((8, marge_h + int((j + 0.5) * H / 3.0) - 12), ROWS[f], font=f_p, fill=(255, 255, 255))
        dr.text((8, 8), "âge %d %s" % (age, "nuit" if nuit else "jour"), font=f_p, fill=(255, 220, 120))
        if z == 2:
            p = os.path.join(a.out, "planche-e%02d-z2-%s.png" % (age, "nuit" if nuit else "jour"))
            img.save(p, optimize=True)
        else:
            z1.append((age, nuit, img))
    # gros plans : la TÊTE de chaque tourelle au zoom 2 (pixels du jeu, agrandis × a.agrandir), grille forces × colonnes
    for c in [c for c in caps if c["zoom"] == "2"]:
        age, nuit = int(c["age"]), c["nuit"] == "1"
        cx, cy, px, py = float(c["x"]), float(c["y"]), int(c["px"]), int(c["py"])
        A = capture(a.avec, c["capture"])
        H, W = A.shape[:2]
        k = 64.0
        demi = {3: 1.6, 9: 2.4, 15: 3.2}.get(age, px / 2.0)
        cases = {}
        for s in [s for s in sites if int(s["age"]) == age]:
            x, y = float(s["x"]), float(s["y"]) - {3: 0.6, 9: 1.0, 15: 1.0}.get(age, 0.8)
            u0, u1 = int(W / 2 + (x - demi - cx) * k), int(W / 2 + (x + demi - cx) * k)
            v0, v1 = int(H / 2 + (y - demi * 0.8 - cy) * k), int(H / 2 + (y + demi * 0.8 - cy) * k)
            im = Image.fromarray(A[max(0, v0):v1, max(0, u0):u1])
            if a.agrandir != 1:
                im = im.resize((im.size[0] * a.agrandir, im.size[1] * a.agrandir), Image.NEAREST)
            cases[(s["force"], int(s["intensite"]))] = im
        cw = max(i.size[0] for i in cases.values())
        ch = max(i.size[1] for i in cases.values())
        mg, mh = 150, 40
        img = Image.new("RGB", (mg + 4 * cw + 30, mh + 3 * ch + 20), (22, 22, 22))
        dr = ImageDraw.Draw(img)
        for i, it in enumerate([0, 25, 40, 60]):
            dr.text((mg + i * (cw + 10) + cw // 2 - 50, 6), COLS[i], font=f_t, fill=(255, 255, 255))
            for j, f in enumerate(["player", "fo-scarlet", "fo-azure"]):
                img.paste(cases[(f, it)], (mg + i * (cw + 10), mh + j * (ch + 10)))
        for j, f in enumerate(["player", "fo-scarlet", "fo-azure"]):
            dr.text((8, mh + j * (ch + 10) + ch // 2 - 12), ROWS[f], font=f_p, fill=(255, 255, 255))
        dr.text((8, 8), "âge %d, %s" % (age, "nuit" if nuit else "jour"), font=f_p, fill=(255, 220, 120))
        img.save(os.path.join(a.out, "gros-plan-e%02d-%s.png" % (age, "nuit" if nuit else "jour")), optimize=True)
    # zoom 1 : les 3 âges, jour à gauche, nuit à droite
    if z1:
        jours = [i for (e, n, i) in sorted(z1, key=lambda t: t[0]) if not n]
        nuits = [i for (e, n, i) in sorted(z1, key=lambda t: t[0]) if n]
        Wc = max(i.size[0] for i in jours)
        Ht = sum(i.size[1] for i in jours)
        out = Image.new("RGB", (2 * Wc + 10, Ht), (0, 0, 0))
        y = 0
        for j, n in zip(jours, nuits):
            out.paste(j, (0, y))
            out.paste(n, (Wc + 10, y))
            y += j.size[1]
        out.save(os.path.join(a.out, "planche-z1.png"), optimize=True)
    with open(os.path.join(a.out, "mesure.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lignes) + "\n")
    for l in lignes:
        print("[A5-PLANCHE] " + l)
    return 0


if __name__ == "__main__":
    sys.exit(main())
