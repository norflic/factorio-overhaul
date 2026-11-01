"""Planches de l'icône de la blende (lot ICONE-BLENDE, 30/10/2026). Python système (py -3.9 : Pillow). Hors moteur.

    py -3.9 tools/render/pieces/ressources/icone_blende/planche.py --data "<racine>/data" --out <dossier> \
        --colonne "AVANT S2=<icone.png>" --colonne "AVANT S8=<dossier>" --colonne "APRES=<dossier>" \
        --autre "galène=<icone.png>" ...

Une colonne est un fichier icone.png ou un dossier qui contient icone.png et icone-1.png à icone-3.png. Écrit :
  - inventaire.png : fente d'inventaire vanilla (gui-new.png, style « slot », 40 px) avec l'icône à 32 px, taille réelle
    puis agrandie × 3 (plus proche voisin), puis l'icône à 64 px × 2 ; colonnes, vanilla, autres minerais du mod ;
  - sol.png : les 4 images d'objet (`pictures`, scale 0,25) posées sur la terre dirt-4 et l'herbe grass-1, au zoom 2
    (mipmap 32 px) et au zoom 1 (mipmap 16 px), agrandies × 2 ;
  - grand.png : chaque icône et ses 3 images à 64 px, × 4.
Le moteur choisit le mipmap le plus proche de la taille affichée : on montre donc la bande exacte (64, 32, 16).
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFont

FOND = (49, 48, 49, 255)        # cadre « inside_deep_frame » de l'inventaire
TEXTE = (230, 225, 215, 255)
VANILLA = ("iron-ore", "copper-ore", "stone", "coal", "uranium-ore")
NOMS_VANILLA = {"iron-ore": "fer", "copper-ore": "cuivre", "stone": "pierre", "coal": "charbon", "uranium-ore": "uranium"}


def police(t=14):
    for f in ("C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, t)
    return ImageFont.load_default()


def mip(path, taille):
    """Mipmap `taille` (64, 32, 16, 8) d'une bande d'icône 120 × 64."""
    im = Image.open(path).convert("RGBA")
    x = {64: 0, 32: 64, 16: 96, 8: 112}[taille]
    return im.crop((x, 0, x + taille, taille))


def images(src):
    """Les fichiers d'une colonne : [icone] ou [icone, icone-1, icone-2, icone-3]."""
    if os.path.isdir(src):
        out = [os.path.join(src, "icone.png")]
        out += [os.path.join(src, "icone-%d.png" % k) for k in (1, 2, 3) if os.path.exists(os.path.join(src, "icone-%d.png" % k))]
        return out
    return [src]


def vanilla_images(data, nom):
    base = os.path.join(data, "base", "graphics", "icons", nom)
    out = [base + ".png"]
    out += [base + "-%d.png" % k for k in (1, 2, 3) if os.path.exists(base + "-%d.png" % k)]
    return out


def fente(data):
    g = Image.open(os.path.join(data, "core", "graphics", "gui-new.png")).convert("RGBA")
    return g.crop((0, 424, 80, 504)).resize((40, 40), Image.LANCZOS)


def inventaire(data, entrees, out):
    """entrees : [(titre, chemin d'icone.png)] ; séparateurs : titre None."""
    f = fente(data)
    P = police(13)
    n = len(entrees)
    pas = 44
    larg = 20 + n * pas
    # bande 1 : taille réelle ; bande 2 : × 3 ; bande 3 : 64 px × 2
    h1, h2, h3 = 40, 120, 128
    H = 30 + h1 + 30 + h2 + 30 + h3 + 60
    W = max(larg, 20 + n * 132)
    im = Image.new("RGBA", (W, H), FOND)
    d = ImageDraw.Draw(im)
    d.text((10, 6), "Inventaire, taille réelle (fente 40 px, icône 32 px)", font=P, fill=TEXTE)
    rang = Image.new("RGBA", (n * pas, 40), FOND)
    for i, (titre, p) in enumerate(entrees):
        if p is None:
            continue
        rang.alpha_composite(f, (i * pas, 0))
        rang.alpha_composite(mip(p, 32), (i * pas + 4, 4))
    im.alpha_composite(rang, (10, 30))
    y = 30 + h1 + 8
    d.text((10, y), "Même rangée agrandie × 3 (plus proche voisin)", font=P, fill=TEXTE)
    r3 = rang.resize((rang.width * 3, rang.height * 3), Image.NEAREST)
    if r3.width > W - 20:
        r3 = r3.crop((0, 0, W - 20, r3.height))
    im.alpha_composite(r3, (10, y + 22))
    y = y + 22 + h2 + 8
    d.text((10, y), "Icône 64 px × 2", font=P, fill=TEXTE)
    for i, (titre, p) in enumerate(entrees):
        x = 10 + i * 132
        if p is not None:
            im.alpha_composite(mip(p, 64).resize((128, 128), Image.NEAREST), (x, y + 22))
        d.text((x, y + 22 + h3 + 4), titre or "", font=P, fill=TEXTE)
    im.save(out)


def sol(data, colonnes, out):
    """colonnes : [(titre, [4 images])]. Une case de 3 × 2 tuiles par colonne et par sol, images posées en quinconce."""
    P = police(13)
    sols = (("terre dirt-4", "dirt-4"), ("herbe grass-1", "grass-1"))
    zooms = ((2, 64, 32), (1, 32, 16))
    case_t = (3, 2)
    blocs = []
    for nom_sol, fic in sols:
        for z, px_tuile, taille in zooms:
            src = os.path.join(data, "base", "graphics", "terrain", ("hr-%s.png" if z == 2 else "%s.png") % fic)
            t = Image.open(src).convert("RGBA")
            ligne = []
            for titre, imgs in colonnes:
                c = Image.new("RGBA", (case_t[0] * px_tuile, case_t[1] * px_tuile))
                for ty in range(case_t[1]):
                    for tx in range(case_t[0]):
                        k = (tx + 3 * ty) % 8
                        c.alpha_composite(t.crop((k * px_tuile, 0, (k + 1) * px_tuile, px_tuile)), (tx * px_tuile, ty * px_tuile))
                pos = ((0.55, 0.55), (1.45, 0.45), (2.35, 0.6), (0.9, 1.45), (1.9, 1.5), (2.5, 1.4))
                for j, (gx, gy) in enumerate(pos):
                    p = imgs[j % len(imgs)]
                    m = mip(p, taille)
                    c.alpha_composite(m, (int(gx * px_tuile - taille / 2), int(gy * px_tuile - taille / 2)))
                ligne.append(c.resize((c.width * 2, c.height * 2), Image.NEAREST) if z == 1 else c)
            blocs.append(("%s, zoom %d (image de %d px)%s" % (nom_sol, z, taille, ", agrandi × 2" if z == 1 else ""), ligne))
    cw = blocs[0][1][0].width
    ch = blocs[0][1][0].height
    W = 10 + len(colonnes) * (cw + 10)
    H = 10 + len(blocs) * (ch + 50) + 10
    im = Image.new("RGBA", (W, H), FOND)
    d = ImageDraw.Draw(im)
    y = 10
    for titre_bloc, ligne in blocs:
        d.text((10, y), titre_bloc, font=P, fill=TEXTE)
        for i, c in enumerate(ligne):
            x = 10 + i * (cw + 10)
            im.alpha_composite(c, (x, y + 20))
            d.text((x + 4, y + 22 + ch), colonnes[i][0], font=P, fill=TEXTE)
        y += ch + 50
    im.save(out)


def grand(colonnes, out):
    P = police(14)
    W = 10 + 4 * 266
    H = 10 + len(colonnes) * 290
    im = Image.new("RGBA", (W, H), FOND)
    d = ImageDraw.Draw(im)
    for r, (titre, imgs) in enumerate(colonnes):
        y = 10 + r * 290
        d.text((10, y), titre, font=P, fill=TEXTE)
        for k, p in enumerate(imgs[:4]):
            im.alpha_composite(mip(p, 64).resize((256, 256), Image.NEAREST), (10 + k * 266, y + 24))
    im.save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--colonne", action="append", default=[], help="TITRE=fichier ou dossier (blende)")
    ap.add_argument("--autre", action="append", default=[], help="TITRE=icone.png (autres minerais du mod)")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    cols = [(t, images(p)) for t, p in (x.split("=", 1) for x in a.colonne)]
    van = [(NOMS_VANILLA[n], vanilla_images(a.data, n)) for n in VANILLA]
    autres = [(t, [p]) for t, p in (x.split("=", 1) for x in a.autre)]
    entrees = [(t, im[0]) for t, im in cols] + [(None, None)] + [(t, im[0]) for t, im in van] + [(None, None)] + \
              [(t, im[0]) for t, im in autres]
    inventaire(a.data, entrees, os.path.join(a.out, "inventaire.png"))
    sol(a.data, cols + [v for v in van if v[0] in ("fer", "cuivre", "charbon")], os.path.join(a.out, "sol.png"))
    grand(cols + [v for v in van if v[0] in ("fer", "cuivre", "charbon")], os.path.join(a.out, "grand.png"))
    print("[FO-ICONE-BLENDE] planches : inventaire.png, sol.png, grand.png dans %s" % a.out)


if __name__ == "__main__":
    main()
