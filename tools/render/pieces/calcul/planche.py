"""Planches de contrôle des icônes du calcul (lot CALC-ICONES-A) : avant (provisoire, vanilla teinté) | après | vanilla.

  py -3.9 tools/render/pieces/calcul/planche.py --icones <dossier des bandes> --data "<racine>/data" --out <dossier>

Écrit : planche-comparaison.png (chaque icône : avant 64 et 32 px, après 64 et 32 px, 32 px agrandi x 2 au pixel, fond
sombre et clair), planche-inventaire.png (cases de 40 px du jeu, à 32 px, mêlées aux icônes vanilla voisines),
planche-marque.png (recette « Processeur gravé » : processeur vanilla + puce logique en coin, comme with_mark).
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)

# Icône PROVISOIRE (prototypes/compute.lua de main 0.6.27, table ICON et FLUID) : fichier vanilla, teinte
AVANT = {
    "fo-logic-die": ("processing-unit", (1.00, 0.85, 0.45)),
    "fo-dram-die": ("advanced-circuit", (0.55, 1.00, 0.80)),
    "fo-sram-die": ("advanced-circuit", (0.85, 0.60, 1.00)),
    "fo-etched-wafer": ("processing-unit", (0.78, 0.86, 1.00)),
    "fo-photomask": ("solar-panel", (0.80, 0.92, 1.00)),
    "fo-crystal-laser": ("laser-turret", (0.70, 0.90, 1.00)),
    "fo-heat-sink": ("heat-pipe", (0.90, 0.92, 1.00)),
    "fo-degassed-ilmenite": ("stone", (0.55, 0.50, 0.52)),
    "fo-photoresist": ("fluid/heavy-oil", (0.90, 0.55, 0.20)),
    "fo-helium-3": ("fluid/petroleum-gas", (0.95, 0.95, 0.60)),
}
NOMS = {
    "fo-logic-die": "Puce logique", "fo-dram-die": "Puce DRAM", "fo-sram-die": "Puce SRAM",
    "fo-etched-wafer": "Tranche gravée", "fo-photomask": "Photomasque", "fo-crystal-laser": "Laser à cristal",
    "fo-heat-sink": "Radiateur d'aluminium", "fo-degassed-ilmenite": "Ilménite dégazée",
    "fo-photoresist": "Résine photosensible (fluide)", "fo-helium-3": "Hélium-3 (fluide)",
}
ORDRE = ["fo-logic-die", "fo-dram-die", "fo-sram-die", "fo-etched-wafer", "fo-photomask", "fo-crystal-laser",
         "fo-heat-sink", "fo-degassed-ilmenite", "fo-photoresist", "fo-helium-3"]
VOISINS = ["processing-unit", "advanced-circuit", "electronic-circuit", "heat-pipe", "copper-plate", "solar-panel",
           "stone", "laser-turret", "fluid/heavy-oil", "fluid/petroleum-gas"]
SOMBRE, CLAIR = (49, 48, 49), (214, 210, 200)


def polices():
    try:
        return ImageFont.truetype("arialbd.ttf", 16), ImageFont.truetype("arial.ttf", 12)
    except OSError:
        f = ImageFont.load_default()
        return f, f


def vanilla(data, nom):
    return Image.open(os.path.join(data, "base", "graphics", "icons", nom + ".png")).convert("RGBA")


def teinter(im, t):
    px = im.load()
    out = im.copy()
    po = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            po[x, y] = (int(r * t[0]), int(g * t[1]), int(b * t[2]), a)
    return out


def m64(b):
    return b.crop((0, 0, 64, 64))


def m32(b):
    return b.crop((64, 0, 96, 32))


def case(fond, icone32, taille=40, sombre=True):
    """Case d'inventaire (40 px) : fond gris du jeu, biseau, icône de 32 px au centre."""
    c = Image.new("RGBA", (taille, taille), (0, 0, 0, 255))
    d = ImageDraw.Draw(c)
    if sombre:
        d.rectangle((0, 0, taille - 1, taille - 1), fill=(62, 62, 62, 255))
        d.line((0, 0, taille - 1, 0), fill=(40, 40, 40, 255))
        d.line((0, 0, 0, taille - 1), fill=(40, 40, 40, 255))
        d.line((0, taille - 1, taille - 1, taille - 1), fill=(88, 88, 88, 255))
        d.line((taille - 1, 0, taille - 1, taille - 1), fill=(88, 88, 88, 255))
    else:
        d.rectangle((0, 0, taille - 1, taille - 1), fill=fond + (255,))
    o = (taille - 32) // 2
    c.alpha_composite(icone32, (o, o))
    return c


def planche_comparaison(bandes, data, chemin):
    ft, fs = polices()
    lig = 150
    larg = 1060
    H = 70 + len(ORDRE) * lig
    im = Image.new("RGB", (larg, H), (24, 24, 26))
    d = ImageDraw.Draw(im)
    d.text((14, 10), "CALC-ICONES-A : avant (vanilla teinté, provisoire) | après | sur fond clair ; 64 et 32 px, 32 px x 2",
           fill=(235, 235, 235), font=ft)
    d.text((14, 36), "Images des fichiers, sans retouche. Fond sombre = (49, 48, 49) ; fond clair = (214, 210, 200).",
           fill=(190, 190, 190), font=fs)
    y = 64
    for n in ORDRE:
        src, t = AVANT[n]
        av = teinter(vanilla(data, src), t)
        ap = bandes[n]
        d.text((14, y + 4), NOMS[n], fill=(235, 235, 235), font=ft)
        d.text((14, y + 24), n, fill=(160, 160, 160), font=fs)
        blocs = [("avant", av, SOMBRE, 200), ("après", ap, SOMBRE, 420), ("après, fond clair", ap, CLAIR, 740)]
        for lib, b, fond, x in blocs:
            tuile = Image.new("RGBA", (300, lig - 8), fond + (255,))
            tuile.alpha_composite(m64(b), (6, 22))
            tuile.alpha_composite(m32(b), (80, 38))
            tuile.alpha_composite(case(SOMBRE, m32(b)) if fond == SOMBRE else case(CLAIR, m32(b), sombre=False), (76, 86))
            tuile.alpha_composite(m32(b).resize((64, 64), Image.NEAREST), (130, 22))
            if lib != "avant":
                tuile.alpha_composite(b.crop((96, 0, 112, 16)).resize((32, 32), Image.NEAREST), (204, 22))
            im.paste(tuile.convert("RGB"), (x, y))
            enc = (230, 230, 230) if fond == SOMBRE else (20, 20, 20)
            d.text((x + 6, y + 3), lib, fill=enc, font=fs)
        y += lig
    im.save(chemin)


def planche_inventaire(bandes, data, chemin):
    """Inventaire du jeu : rangées de cases de 40 px, icônes à 32 px : nouvelles icônes et vanilla voisines mêlées."""
    ft, fs = polices()
    rang1 = ["fo-logic-die", "processing-unit", "fo-dram-die", "advanced-circuit", "fo-sram-die", "electronic-circuit",
             "fo-etched-wafer", "copper-plate", "fo-photomask", "solar-panel"]
    rang2 = ["fo-crystal-laser", "laser-turret", "fo-heat-sink", "heat-pipe", "fo-degassed-ilmenite", "stone",
             "fo-photoresist", "fluid/heavy-oil", "fo-helium-3", "fluid/petroleum-gas"]
    w = 10 * 40 + 28
    im = Image.new("RGB", (w * 2 + 30, 220), (24, 24, 26))
    d = ImageDraw.Draw(im)
    d.text((14, 8), "Cases d'inventaire de 40 px, icônes à 32 px (mipmap du fichier) : nouvelle icône | voisine vanilla",
           fill=(235, 235, 235), font=ft)
    for k, (fond, sombre) in enumerate(((SOMBRE, True), (CLAIR, False))):
        x0 = 14 + k * (w + 4)
        d.rectangle((x0 - 6, 34, x0 + w - 18, 214), fill=(41, 41, 41) if sombre else CLAIR)
        for j, rang in enumerate((rang1, rang2)):
            for i, n in enumerate(rang):
                b = bandes[n] if n in bandes else vanilla(data, n)
                c = case(fond, m32(b), sombre=sombre)
                im.paste(c.convert("RGB"), (x0 + i * 41, 44 + j * 84))
                lab = "neuf" if n in bandes else "vanilla"
                d.text((x0 + i * 41 + 2, 44 + j * 84 + 42), lab, fill=(200, 200, 200) if sombre else (30, 30, 30), font=fs)
    im.save(chemin)


def planche_marque(bandes, data, chemin):
    """Recette « Processeur gravé » : processeur vanilla 32 px + puce logique à l'échelle 0,25 décalée de (8, 8)
    (prototypes/compute.lua, with_mark : scale = 0,5 x 32 / 64, shift = {8, 8}) ; puis la même chose à 64 px."""
    ft, fs = polices()
    im = Image.new("RGB", (620, 200), (24, 24, 26))
    d = ImageDraw.Draw(im)
    d.text((14, 8), "Marque de la recette « Processeur gravé » (with_mark) : avant | après", fill=(235, 235, 235), font=ft)
    pu = vanilla(data, "processing-unit")
    for k, (lib, die) in enumerate((("avant", teinter(vanilla(data, "processing-unit"), AVANT["fo-logic-die"][1])),
                                    ("après", bandes["fo-logic-die"]))):
        x = 20 + k * 300
        d.text((x, 36), lib, fill=(220, 220, 220), font=fs)
        # 64 px de base : la marque fait 32 px (scale 0,25 sur une icône dessinée à 32 -> 16 px à 32, 32 px à 64)
        base64 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        base64.alpha_composite(m64(pu), (0, 0))
        base64.alpha_composite(m32(die), (32, 32))
        base32 = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        base32.alpha_composite(m32(pu), (0, 0))
        base32.alpha_composite(die.crop((96, 0, 112, 16)), (16, 16))
        tu = Image.new("RGBA", (280, 140), SOMBRE + (255,))
        tu.alpha_composite(base64, (8, 8))
        tu.alpha_composite(case(SOMBRE, base32), (84, 20))
        tu.alpha_composite(base32.resize((96, 96), Image.NEAREST), (140, 8))
        im.paste(tu.convert("RGB"), (x, 54))
    im.save(chemin)


PAIRES = [("fo-logic-die", "processing-unit"), ("fo-dram-die", "advanced-circuit"), ("fo-sram-die", "electronic-circuit"),
          ("fo-etched-wafer", "copper-plate"), ("fo-photomask", "solar-panel"), ("fo-crystal-laser", "laser-turret"),
          ("fo-heat-sink", "heat-pipe"), ("fo-degassed-ilmenite", "stone"), ("fo-photoresist", "fluid/heavy-oil"),
          ("fo-helium-3", "fluid/petroleum-gas")]


def planche_agrandie(bandes, data, chemin, k=3):
    """Chaque icône de 64 px agrandie x k AU PIXEL, à côté de sa voisine vanilla au même agrandissement."""
    ft, fs = polices()
    cw = 64 * k + 12
    im = Image.new("RGB", (14 + 4 * cw + 30, 40 + 5 * (64 * k + 30)), SOMBRE)
    d = ImageDraw.Draw(im)
    d.text((14, 10), "64 px agrandis x %d au pixel : nouvelle icône | voisine vanilla" % k, fill=(235, 235, 235), font=ft)
    for i, (n, v) in enumerate(PAIRES):
        col, lig = i % 2, i // 2
        x = 14 + col * (2 * cw + 30)
        y = 40 + lig * (64 * k + 30)
        for j, b in enumerate((bandes[n], vanilla(data, v))):
            im.paste(m64(b).resize((64 * k, 64 * k), Image.NEAREST), (x + j * cw, y), m64(b).resize((64 * k, 64 * k), Image.NEAREST))
        d.text((x, y + 64 * k + 4), "%s  |  %s" % (NOMS[n], v), fill=(210, 210, 210), font=fs)
    im.save(chemin)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--icones", required=True)
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    bandes = {}
    for n in ORDRE:
        p = os.path.join(a.icones, n + ".png")
        if os.path.exists(p):
            bandes[n] = Image.open(p).convert("RGBA")
    manq = [n for n in ORDRE if n not in bandes]
    if manq:
        print("absentes : " + ", ".join(manq))
        for n in manq:
            bandes[n] = teinter(vanilla(a.data, AVANT[n][0]), AVANT[n][1])
    planche_comparaison(bandes, a.data, os.path.join(a.out, "planche-comparaison.png"))
    planche_inventaire(bandes, a.data, os.path.join(a.out, "planche-inventaire.png"))
    planche_marque(bandes, a.data, os.path.join(a.out, "planche-marque.png"))
    planche_agrandie(bandes, a.data, os.path.join(a.out, "planche-agrandie.png"))
    print("planches dans " + a.out)


if __name__ == "__main__":
    main()
