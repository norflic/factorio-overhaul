r"""Images du lot TIRS (27/10) pour le téléphone du Directeur Créatif : GIF animés des RAFALES de captures du scénario
tirs-ages (une image tous les 2 ticks) et planches de moins de 2 000 px.

    py -3.9 -B tools/autotest/tirs_images.py <dossier fo-shots> <dossier de sortie>

Entrée : les captures NNN-<site>-<jour|nuit>-<ii>.png et fo-shots/tirs-ages-sites.tsv (écrite par le scénario).
Sortie :
  gif/<site>-<jour|nuit>.gif      rafale animée, 640 px de large, à mi-vitesse (une image de jeu sur 2 ticks = 67 ms) ;
  planche-<site>.png              8 images consécutives de jour (4 × 2), puis 4 de nuit, 1 920 px de large ;
  planche-jour.png, planche-nuit.png : l'image la plus « active » de chaque site (écart à la médiane de la rafale) ;
  index.txt                       la liste, avec la mesure d'activité de chaque rafale.
"""
import csv
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

LARGEUR_GIF = 640
MS_IMAGE = 67

TITRES = {
    "a01": "Age 1 (Pionnier), niveau 2",
    "a05": "Age 5 (Volcan), niveau 9",
    "a08-temoin": "Age 8, niveau 15 : TEMOIN (effet d'avant)",
    "a10": "Age 10 (Haute techno), niveau 19",
    "a15": "Age 15 (Neant), niveau 29",
    "laser15": "Laser age 15, niveau 29",
    "laser08-temoin": "Laser age 8, niveau 15 : TEMOIN",
}


def police(t):
    for f in (r"C:\Windows\Fonts\arialbd.ttf", r"C:\Windows\Fonts\arial.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, t)
    return ImageFont.load_default()


def etiquette(im, texte, taille=22):
    d = ImageDraw.Draw(im)
    f = police(taille)
    d.rectangle([0, 0, im.width, taille + 10], fill=(0, 0, 0))
    d.text((8, 4), texte, fill=(255, 255, 255), font=f)
    return im


def lire_sites(dossier):
    rafales = {}
    with open(os.path.join(dossier, "tirs-ages-sites.tsv"), encoding="utf-8") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            rafales.setdefault((r["site"], r["etat"]), []).append(r["capture"])
    fichiers = {}
    for n in os.listdir(dossier):
        if n.endswith(".png") and n[:3].isdigit() and n[3] == "-":
            fichiers[n[4:-4]] = os.path.join(dossier, n)
    return rafales, fichiers


def activite(images):
    """Écart de chaque image à la médiane de la rafale (moyenne absolue, 0 à 255) : où le tir se voit le plus."""
    a = np.stack([np.asarray(im.convert("L"), dtype=np.float32) for im in images])
    med = np.median(a, axis=0)
    return [float(np.abs(x - med).mean()) for x in a]


def gif(images, chemin):
    r = LARGEUR_GIF / images[0].width
    taille = (LARGEUR_GIF, int(round(images[0].height * r)))
    petites = [im.convert("RGB").resize(taille, Image.LANCZOS) for im in images]
    pal = [im.quantize(colors=200, method=Image.MEDIANCUT, dither=Image.NONE) for im in petites]
    pal[0].save(chemin, save_all=True, append_images=pal[1:], duration=MS_IMAGE, loop=0, optimize=True)


def grille(tuiles, cols, l, h, titre=None):
    lignes = (len(tuiles) + cols - 1) // cols
    haut = 40 if titre else 0
    out = Image.new("RGB", (cols * l, lignes * h + haut), (20, 20, 20))
    if titre:
        etiquette(out, titre, 26)
    for i, (im, txt) in enumerate(tuiles):
        t = im.convert("RGB").resize((l, h), Image.LANCZOS)
        if txt:
            etiquette(t, txt, 18)
        out.paste(t, ((i % cols) * l, haut + (i // cols) * h))
    return out


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    src, dst = argv[1], argv[2]
    os.makedirs(os.path.join(dst, "gif"), exist_ok=True)
    rafales, fichiers = lire_sites(src)
    ordre = []
    for (site, etat) in rafales:
        if site not in ordre:
            ordre.append(site)
    meilleures = {"jour": [], "nuit": []}
    lignes = []
    manque = 0
    for site in ordre:
        par_etat = {}
        for etat in ("jour", "nuit"):
            noms = rafales.get((site, etat), [])
            ims = [Image.open(fichiers[n]) for n in noms if n in fichiers]
            manque += len(noms) - len(ims)
            if not ims:
                continue
            act = activite(ims)
            par_etat[etat] = (ims, act)
            gif(ims, os.path.join(dst, "gif", "%s-%s.gif" % (site, etat)))
            k = int(np.argmax(act))
            meilleures[etat].append((ims[k], TITRES.get(site, site)))
            lignes.append("%s\t%s\t%d images\tactivite moyenne %.2f, max %.2f (image %d)" % (
                site, etat, len(ims), float(np.mean(act)), act[k], k + 1))
        tuiles = []
        if "jour" in par_etat:
            ims = par_etat["jour"][0]
            for i, im in enumerate(ims[:8]):
                tuiles.append((im, "jour, +%d ticks" % (2 * i)))
        if "nuit" in par_etat:
            ims = par_etat["nuit"][0]
            for i, im in enumerate(ims[:4]):
                tuiles.append((im, "nuit, +%d ticks" % (2 * i)))
        if tuiles:
            grille(tuiles, 4, 480, 270, TITRES.get(site, site) + " : images consecutives (2 ticks)").save(
                os.path.join(dst, "planche-%s.png" % site), optimize=True)
    for etat in ("jour", "nuit"):
        if meilleures[etat]:
            grille(meilleures[etat], 3, 640, 360, "Tirs par age, %s (image la plus active de chaque rafale)" % etat).save(
                os.path.join(dst, "planche-%s.png" % etat), optimize=True)
    with open(os.path.join(dst, "index.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lignes) + "\n")
    print("\n".join(lignes))
    print("BILAN : %d rafale(s), %d GIF, captures manquantes %d -> %s" % (len(lignes), len(lignes), manque, dst))
    return 0 if manque == 0 and lignes else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
