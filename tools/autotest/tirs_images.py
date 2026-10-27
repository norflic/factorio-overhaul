r"""Images du lot TIRS (27/10 ; ronde 4) pour le téléphone du Directeur Créatif : GIF animés des RAFALES de captures du
scénario tirs-ages (une image tous les 2 ticks), en TEMPS RÉEL, avec un ralenti à part étiqueté comme tel, et planches
de moins de 2 000 px.

    py -3.9 -B tools/autotest/tirs_images.py <dossier fo-shots> <dossier de sortie>

Entrée : les captures NNN-<site>-<serie>-<ii>.png et fo-shots/tirs-ages-sites.tsv (écrite par le scénario).
Sortie :
  gif/<site>-<serie>.gif            rafale animée en temps réel (2 ticks = 33 ms : 30, 40, 30 ms), 640 px de large ;
  gif-ralenti/<site>-<serie>.gif    la même au ralenti ×4, « RALENTI x4 » écrit sur chaque image ;
  planche-<site>.png                images consécutives de chaque série (4 colonnes), 1 920 px de large ;
  planche-jour.png, planche-nuit.png, planche-z05.png : par site, l'image où le tir AJOUTE le plus de lumière (gain de
                                    luminance sur le minimum, pixel par pixel, de sa rafale : une image sans tir) ;
  index.txt                         par rafale : gain moyen et maximal ; contrôle « le gain moyen au zoom 0,5 croît avec
                                    l'âge » (âges 1, 5, 8, 10, 15).
"""
import csv
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

LARGEUR_GIF = 640
MS_TICK = 1000.0 / 60.0

TITRES = {
    "a01": "Age 1 (Pionnier), niveau 2",
    "a05": "Age 5 (Volcan), niveau 9",
    "a07-sans-effet": "Age 7, niveau 13 : SANS effet (comme avant)",
    "a08": "Age 8 (Marais), niveau 15",
    "a10": "Age 10 (Haute techno), niveau 19",
    "a15": "Age 15 (Neant), niveau 29",
    "a15-nord": "Age 15, tir vers le nord",
    "a15-sud": "Age 15, tir vers le sud",
    "a15-ouest": "Age 15, tir vers l'ouest",
    "a15-nordest": "Age 15, tir vers le nord-est",
    "a05-nord": "Age 5, tir vers le nord",
    "laser15": "Laser age 15, niveau 29",
    "laser08-temoin": "Laser age 8, niveau 15 : vanilla",
    "a15-loin": "Age 15 a 300 tuiles du joueur : sans effet (filtre)",
    "mur15": "Mur de 10 tourelles de l'age 15 face aux biters",
}
ORDRE_AGES = ["a01", "a05", "a08", "a10", "a15"]


def police(t):
    for f in (r"C:\Windows\Fonts\arialbd.ttf", r"C:\Windows\Fonts\arial.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, t)
    return ImageFont.load_default()


def etiquette(im, texte, taille=20, couleur=(255, 255, 255)):
    d = ImageDraw.Draw(im)
    f = police(taille)
    d.rectangle([0, 0, im.width, taille + 8], fill=(0, 0, 0))
    d.text((6, 3), texte, fill=couleur, font=f)
    return im


def lire_sites(dossier):
    rafales, meta = {}, {}
    with open(os.path.join(dossier, "tirs-ages-sites.tsv"), encoding="utf-8") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            k = (r["site"], r["serie"])
            rafales.setdefault(k, []).append(r["capture"])
            meta[k] = r
    fichiers = {}
    for n in os.listdir(dossier):
        if n.endswith(".png") and n[:3].isdigit() and n[3] == "-":
            fichiers[n[4:-4]] = os.path.join(dossier, n)
    return rafales, meta, fichiers


def gains(images):
    """Gain de luminance de chaque image sur le minimum pixel par pixel de la rafale (0 à 255, moyenne)."""
    a = np.stack([np.asarray(im.convert("L"), dtype=np.float32) for im in images])
    mn = a.min(axis=0)
    return [float(np.maximum(x - mn, 0).mean()) for x in a]


def gif(images, chemin, ms, texte, couleur=(255, 255, 255)):
    r = LARGEUR_GIF / images[0].width
    taille = (LARGEUR_GIF, int(round(images[0].height * r)))
    petites = [etiquette(im.convert("RGB").resize(taille, Image.LANCZOS), texte, 18, couleur) for im in images]
    pal = [im.quantize(colors=200, method=Image.MEDIANCUT, dither=Image.NONE) for im in petites]
    pal[0].save(chemin, save_all=True, append_images=pal[1:], duration=ms[:len(pal)], loop=0, optimize=True)


def durees(n, ms_image):
    """Durées (ms, multiples de 10 : unité du GIF) dont la moyenne vaut ms_image (30, 40, 30… pour 33,3)."""
    out, cumul = [], 0.0
    for i in range(n):
        cible = (i + 1) * ms_image
        d = int(round((cible - cumul) / 10.0)) * 10
        d = max(20, d)
        out.append(d)
        cumul += d
    return out


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
    for d in ("gif", "gif-ralenti"):
        os.makedirs(os.path.join(dst, d), exist_ok=True)
    rafales, meta, fichiers = lire_sites(src)
    ordre = []
    for (site, serie) in rafales:
        if site not in ordre:
            ordre.append(site)
    meilleures = {"jour": [], "nuit": [], "jour-z05": []}
    lignes, manque, n_gif = [], 0, 0
    act_z05 = {}
    for site in ordre:
        tuiles = []
        titre = TITRES.get(site, site)
        for serie in ("jour", "nuit", "jour-z05", "nuit-z05"):
            noms = rafales.get((site, serie), [])
            ims = [Image.open(fichiers[n]) for n in noms if n in fichiers]
            manque += len(noms) - len(ims)
            if not ims:
                continue
            m = meta[(site, serie)]
            cad = int(m.get("cadence") or 2)
            g = gains(ims)
            k = int(np.argmax(g))
            zoom = float(m["zoom"])
            nom = "%s-%s" % (site, serie)
            gif(ims, os.path.join(dst, "gif", nom + ".gif"), durees(len(ims), cad * MS_TICK),
                "%s, %s, zoom %.1f, temps reel" % (titre, serie.replace("-z05", ""), zoom))
            gif(ims, os.path.join(dst, "gif-ralenti", nom + ".gif"), durees(len(ims), 4 * cad * MS_TICK),
                "RALENTI x4 : %s, %s" % (titre, serie.replace("-z05", "")), (255, 210, 80))
            n_gif += 2
            if serie in meilleures:
                meilleures[serie].append((ims[k], "%s (image %d)" % (titre, k + 1)))
            if serie == "jour-z05":
                act_z05[site] = float(np.mean(g))
            lignes.append("%s\t%s\tzoom %.2f\t%d images\tgain moyen %.2f, max %.2f (image %d)" % (
                site, serie, zoom, len(ims), float(np.mean(g)), g[k], k + 1))
            n = 8 if serie == "jour" else 4
            for i, im in enumerate(ims[:n]):
                tuiles.append((im, "%s, +%d ticks" % (serie, cad * i)))
        if tuiles:
            grille(tuiles, 4, 480, 270, titre + " : images consecutives").save(
                os.path.join(dst, "planche-%s.png" % site), optimize=True)
    for serie, fichier in (("jour", "planche-jour.png"), ("nuit", "planche-nuit.png"), ("jour-z05", "planche-z05.png")):
        if meilleures[serie]:
            grille(meilleures[serie], 3, 640, 360, "Tirs par age, %s : l'image ou le tir ajoute le plus de lumiere"
                   % serie.replace("jour-z05", "jour, zoom 0,5")).save(os.path.join(dst, fichier), optimize=True)
    # contrôle : au zoom 0,5, le gain moyen croît avec l'âge (signature lisible au zoom de défense)
    croit, prev, parts = True, -1.0, []
    for s in ORDRE_AGES:
        if s in act_z05:
            parts.append("%s %.2f" % (s, act_z05[s]))
            if act_z05[s] <= prev:
                croit = False
            prev = act_z05[s]
    lignes.append("zoom 0,5, gain moyen par age : %s : %s" % (", ".join(parts), "CROISSANT" if croit else "NON CROISSANT"))
    with open(os.path.join(dst, "index.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lignes) + "\n")
    print("\n".join(lignes))
    print("BILAN : %d rafale(s), %d GIF, captures manquantes %d -> %s" % (
        sum(1 for l in lignes if "\t" in l), n_gif, manque, dst))
    return 0 if manque == 0 and lignes else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
