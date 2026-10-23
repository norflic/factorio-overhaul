"""Lot A1 (23/10) : COPIE JETABLE du mod pour les expériences moteur E67 et E70 (scénario greffé a1-tourelle).

    py -3.9 tools/autotest/a1/jetable.py --dest <dossier neuf, hors du dépôt> [--src <racine du mod>]

1. Recopie la source du mod (par défaut : la racine de ce dépôt ou de ce worktree) dans --dest, sans .git, .claude,
   tools/render ni __pycache__ (mêmes exclusions que fo-autotest.bat).
2. Y ajoute a1_jetable_data.lua (prototypes de test, voir son en-tête) et l'appelle en fin de data-final-fixes.lua.
3. Dessine graphics/a1/fleches-64.png (64 flèches ROUGES numérotées, image k tournée de k x 360/64 degrés dans le
   sens HORAIRE depuis le haut ; 8 x 8 images de 128 px, ligne par ligne : tête levée), fleches-64-repli.png (les
   mêmes en BLEU : tête repliée, en levée ou en repli) et graphics/a1/repli.png (carré « REPLI », non utilisé
   depuis le second passage).
Le banc se lance ensuite sur cette copie : fo-autotest.bat nopause 1000 a1-tourelle "<dest>" (et fo-captures.bat
a1-tourelle "<dest>" pour les images). Le mod livré n'est jamais modifié.
"""
import argparse
import math
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
EXCLUS = {".git", ".claude", "__pycache__"}


def police(taille):
    try:
        return ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", taille)
    except OSError:
        return ImageFont.load_default()


def fleche(k, n=64, cote=128, couleur=(255, 40, 40, 255)):
    """Image k : flèche du centre vers le bord, angle k*360/n dans le sens horaire depuis le haut ; numéro k."""
    im = Image.new("RGBA", (cote, cote), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = cote / 2.0
    d.ellipse((c - 30, c - 30, c + 30, c + 30), fill=(30, 30, 30, 230), outline=(255, 255, 255, 255), width=2)
    a = 2.0 * math.pi * k / n
    ux, uy = math.sin(a), -math.cos(a)      # haut de l'image = nord ; sens horaire
    px, py = -uy, ux
    r0, r1, tete = 8.0, 60.0, 18.0
    d.line((c + ux * r0, c + uy * r0, c + ux * (r1 - tete + 2), c + uy * (r1 - tete + 2)), fill=couleur, width=8)
    pointe = (c + ux * r1, c + uy * r1)
    g = (c + ux * (r1 - tete) + px * 11, c + uy * (r1 - tete) + py * 11)
    dr = (c + ux * (r1 - tete) - px * 11, c + uy * (r1 - tete) - py * 11)
    d.polygon([pointe, g, dr], fill=couleur)
    f = police(22)
    t = "%d" % k
    w, h = d.textbbox((0, 0), t, font=f)[2:]
    d.text((c - w / 2.0, c - h / 2.0 - 2), t, font=f, fill=(255, 255, 0, 255))
    return im


def repli(cote=128):
    im = Image.new("RGBA", (cote, cote), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((24, 40, cote - 24, cote - 40), fill=(110, 110, 110, 235), outline=(255, 255, 255, 255), width=2)
    f = police(18)
    w, h = d.textbbox((0, 0), "REPLI", font=f)[2:]
    d.text(((cote - w) / 2.0, (cote - h) / 2.0 - 2), "REPLI", font=f, fill=(0, 0, 0, 255))
    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--src", default=MOD)
    a = ap.parse_args()
    src, dest = os.path.abspath(a.src), os.path.abspath(a.dest)
    if os.path.exists(dest):
        raise SystemExit("--dest existe déjà (copie jetable : dossier NEUF) : %s" % dest)
    if not os.path.exists(os.path.join(src, "info.json")):
        raise SystemExit("source sans info.json : %s" % src)
    render = os.path.join(src, "tools", "render")

    def ignorer(d, noms):
        return [n for n in noms if n in EXCLUS or os.path.join(d, n) == render]

    shutil.copytree(src, dest, ignore=ignorer)
    shutil.copy2(os.path.join(HERE, "a1_jetable_data.lua"), os.path.join(dest, "a1_jetable_data.lua"))
    dff = os.path.join(dest, "data-final-fixes.lua")
    with open(dff, "ab") as f:
        f.write(b"\n-- COPIE JETABLE du lot A1 (tools/autotest/a1/jetable.py) : prototypes de test E67 et E70\n"
                b"require(\"a1_jetable_data\")\n")
    g = os.path.join(dest, "graphics", "a1")
    os.makedirs(g, exist_ok=True)
    for fn, coul in (("fleches-64.png", (255, 40, 40, 255)), ("fleches-64-repli.png", (40, 120, 255, 255))):
        feuille = Image.new("RGBA", (8 * 128, 8 * 128), (0, 0, 0, 0))
        for k in range(64):
            feuille.paste(fleche(k, couleur=coul), ((k % 8) * 128, (k // 8) * 128))
        feuille.save(os.path.join(g, fn))
    repli().save(os.path.join(g, "repli.png"))
    print("copie jetable prête : %s (source %s)" % (dest, src))


if __name__ == "__main__":
    sys.exit(main())
