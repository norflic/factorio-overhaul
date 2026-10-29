"""Feuille PROPRE du lac de saumure (lot AMELIO-RESSOURCES, 30/10 ; réponse du DC du 25/10, D-17 : « saumure au visuel
propre »). Python + Pillow, sans Blender, déterministe.

Avant : le puits de pétrole vanilla teinté (flaque noire teintée vert d'eau : une tache sombre sans rien de salin). Ici :
la SILHOUETTE de la flaque vanilla (mêmes 4 variantes, même découpe 74 × 60 et 148 × 120, même décalage : le moteur et le
chevalet de pompage la placent comme le pétrole) recolorée en eau de saumure turquoise profond, bordée d'une CROÛTE DE
SEL blanche cristalline (anneau intérieur et halo extérieur, au lieu de l'ombre noire vanilla), et semée de cristaux de
sel sur la croûte. Le relief (reflets, creux) de la flaque vanilla est gardé dans la luminance de l'eau.

    py -3.9 tools/render/pieces/ressources/saumure.py "<racine>/data" graphics/ressources/saumure
    -> saumure.png (296 × 60), hr-saumure.png (592 × 120), MANIFEST.json
"""
import hashlib
import json
import os
import random
import sys

from PIL import Image, ImageFilter

EAU = (26, 94, 102)         # saumure profonde (turquoise : la couleur de carte de la saumure, plus sombre)
EAU_CLAIRE = (120, 205, 200)
SEL = (232, 236, 228)       # croûte de sel
SEL_OMBRE = (176, 186, 182)
ANNEAU = 7                  # largeur de la croûte intérieure (px, hr)
GRAINE = 7105               # la graine de la saumure (shared/content/world.lua)


def melange(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def recolorer(src):
    """src : image RGBA hr de la flaque vanilla (4 cadres côte à côte). Renvoie l'image recolorée."""
    w, h = src.size
    a = src.getchannel("A")
    plein = a.point(lambda v: 255 if v >= 128 else 0)
    # anneau : distance au bord, en érodant le masque plein (filtre minimum 3 × 3 répété)
    erode = [plein]
    for _ in range(ANNEAU):
        erode.append(erode[-1].filter(ImageFilter.MinFilter(3)))
    rng = random.Random(GRAINE)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sp, op = src.load(), out.load()
    ep = [e.load() for e in erode]
    for y in range(h):
        for x in range(w):
            r, g, b, al = sp[x, y]
            if al == 0:
                continue
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            if al < 128:
                # halo vanilla (ombre floue autour de la flaque) : croûte de sel diffuse, plus claire et moins opaque
                op[x, y] = SEL_OMBRE + (int(al * 0.85),)
                continue
            # profondeur dans l'anneau : 0 au bord, ANNEAU au cœur
            d = 0
            while d < ANNEAU and ep[d + 1][x, y] == 255:
                d += 1
            if d < ANNEAU:
                t = d / float(ANNEAU)
                c = melange(SEL, SEL_OMBRE, 0.35 * t + 0.25 * rng.random())
                if t > 0.6:
                    c = melange(c, EAU_CLAIRE, (t - 0.6) / 0.4 * 0.7)
                op[x, y] = c + (255,)
            else:
                # eau : relief de la flaque vanilla (lum 0 à ~0,8) étiré vers l'eau claire
                k = min(1.0, lum * 3.2)
                op[x, y] = melange(EAU, EAU_CLAIRE, k * 0.6) + (al,)
    # cristaux de sel épars sur la croûte (2 px), hors de l'eau
    for _ in range(w * h // 260):
        x, y = rng.randrange(w - 2), rng.randrange(h - 2)
        if 0 < erode[0].getpixel((x, y)) and erode[ANNEAU].getpixel((x, y)) == 0 and op[x, y][3] > 0:
            for dx in (0, 1):
                for dy in (0, 1):
                    op[x + dx, y + dy] = (250, 252, 248, 255)
    return out


def main():
    data, sortie = sys.argv[1], sys.argv[2]
    os.makedirs(sortie, exist_ok=True)
    src = Image.open(os.path.join(data, "base", "graphics", "entity", "crude-oil", "hr-crude-oil.png")).convert("RGBA")
    hr = recolorer(src)
    lr = hr.resize((hr.size[0] // 2, hr.size[1] // 2), Image.LANCZOS)
    fichiers = {"hr-saumure.png": hr, "saumure.png": lr}
    man = {"outil": "tools/render/pieces/ressources/saumure.py", "source": "__base__/graphics/entity/crude-oil/hr-crude-oil.png",
           "format": {"frame_count": 4, "variation_count": 1, "width": 74, "height": 60, "hr_width": 148, "hr_height": 120},
           "couleurs": {"eau": EAU, "eau_claire": EAU_CLAIRE, "sel": SEL, "sel_ombre": SEL_OMBRE, "anneau_px": ANNEAU},
           "sha256": {}}
    for nom, im in sorted(fichiers.items()):
        p = os.path.join(sortie, nom)
        im.save(p, optimize=True)
        man["sha256"][nom] = hashlib.sha256(open(p, "rb").read()).hexdigest()
    with open(os.path.join(sortie, "MANIFEST.json"), "w", encoding="utf-8") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-SAUMURE] %s : %s" % (sortie, ", ".join("%s %dx%d" % (n, i.size[0], i.size[1]) for n, i in sorted(fichiers.items()))))


if __name__ == "__main__":
    main()
