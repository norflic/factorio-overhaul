"""Lot B0 : planches pour le Directeur Créatif (captures AVANT / APRÈS du scénario b0-biomes, même graine, mêmes points).

py -3.9 tools/autotest/b0_planche.py <dossier du lot>
  le dossier contient avant-complet/shots, apres/shots, e136-couches/shots et apres-pale/shots (fo-captures.bat b0-biomes) ;
  sorties dans ce dossier : planche-B0.png (10 images) et planche-B0-options.png (4 variantes du cristal).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 800, 450


def police(t):
    for f in ("arialbd.ttf", "arial.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(f, t)
        except OSError:
            pass
    return ImageFont.load_default()


def case(dossier, chemin, titre):
    im = Image.open(os.path.join(dossier, chemin)).convert("RGB").resize((W, H), Image.LANCZOS)
    d = ImageDraw.Draw(im)
    f = police(22)
    x0, y0, x1, y1 = d.textbbox((10, 8), titre, font=f)
    d.rectangle((x0 - 6, y0 - 4, x1 + 6, y1 + 4), fill=(0, 0, 0))
    d.text((10, 8), titre, font=f, fill=(255, 255, 255))
    return im


def planche(dossier, cases, colonnes, sortie, entete):
    lignes = (len(cases) + colonnes - 1) // colonnes
    haut = 44
    out = Image.new("RGB", (colonnes * W + (colonnes - 1) * 8, haut + lignes * (H + 8)), (24, 24, 24))
    d = ImageDraw.Draw(out)
    d.text((10, 10), entete, font=police(24), fill=(255, 255, 255))
    for i, (chemin, titre) in enumerate(cases):
        if chemin is None:
            continue
        x = (i % colonnes) * (W + 8)
        y = haut + (i // colonnes) * (H + 8)
        out.paste(case(dossier, chemin, titre), (x, y))
    out.save(os.path.join(dossier, sortie), optimize=True)
    print(sortie, out.size)


def main():
    dossier = sys.argv[1]
    a, p = "avant-complet/shots/", "apres/shots/"
    planche(dossier, [
        (a + "017-nuancier-z05.png", "1a AVANT : nuancier (cristal et marais en escalier)"),
        (p + "017-nuancier-z05.png", "1b APRES : nuancier, memes disques"),
        (a + "002-frontiere-cristal-z1.png", "2a AVANT : frontiere du cristal, zoom 1"),
        (p + "002-frontiere-cristal-z1.png", "2b APRES : meme endroit, zoom 1"),
        (a + "016-site-cristal-z1.png", "3a AVANT : site garanti du cristal"),
        (p + "016-site-cristal-z1.png", "3b APRES : site garanti du cristal"),
        (a + "006-frontiere-marais-z1.png", "4a AVANT : frontiere du marais, zoom 1"),
        (p + "006-frontiere-marais-z1.png", "4b APRES : marais, meme endroit"),
        (p + "004-large-cristal-z025.png", "5 APRES : vue large du cristal, zoom 0,25"),
        (p + "012-frontiere-vanilla-z1.png", "6 REFERENCE vanilla : herbe / desert, zoom 1"),
    ], 2, "planche-B0.png", "Lot B0 - biomes : AVANT (gauche) / APRES (droite), graine 20261020, midi")
    planche(dossier, [
        (a + "002-frontiere-cristal-z1.png", "A : avant (eau violette, bords en escalier)"),
        ("e136-couches/shots/002-frontiere-cristal-z1.png", "B : eau violette gardee, bords corriges"),
        ("apres-pale/shots/002-frontiere-cristal-z1.png", "C : sol lilas pale"),
        (p + "002-frontiere-cristal-z1.png", "D : sol mauve bruyere (livre)"),
    ], 2, "planche-B0-options.png", "Lot B0 - plaine de cristal : variantes au meme endroit (zoom 1, midi)")
    v = "apres-verdict2/shots/"  # apres-verdict/ : premier essai, couches de bruit nommées (F198), forêt changée
    if os.path.isdir(os.path.join(dossier, v)):
        # Après le verdict du DC (« B1 D, B2 A, B3 B, B4 B ») : grain fin des frontières, plus de décor vanilla sur le cristal.
        planche(dossier, [
            (a + "002-frontiere-cristal-z1.png", "AVANT : frontiere du cristal, zoom 1"),
            (p + "002-frontiere-cristal-z1.png", "APRES B0 : sol mauve, bords fondus"),
            (v + "002-frontiere-cristal-z1.png", "APRES VERDICT : grain fin, sans decor vanilla"),
            (a + "003-frontiere-cristal-z2.png", "AVANT : zoom 2"),
            (p + "003-frontiere-cristal-z2.png", "APRES B0 : zoom 2"),
            (v + "003-frontiere-cristal-z2.png", "APRES VERDICT : zoom 2"),
            (v + "006-frontiere-marais-z1.png", "APRES VERDICT : marais, zoom 1"),
            (v + "004-large-cristal-z025.png", "APRES VERDICT : vue large, zoom 0,25"),
            (None, ""),
        ], 3, "planche-B0-verdict.png", "Lot B0 - avant / apres B0 / apres verdict du DC (graine 20261020, memes endroits, midi)")


if __name__ == "__main__":
    main()
