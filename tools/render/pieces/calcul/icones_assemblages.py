"""ICÔNES DES ASSEMBLAGES DU CALCUL ET DE LEURS TECHNOLOGIES (lot CALC-ICONES-B, 30/10). Proposition à juger.

Demande du DC (30/10, vers 10 h 50) : « aussi designez toute la partie du scenario calcul, que ce soit les usines ou les
items ». Aujourd'hui, ces objets portent des icônes vanilla TEINTÉES (prototypes/compute.lua, table ICON) : 5 objets sur
16 ont celle du processeur, 2 celle de la balise ; à 32 px seule la teinte les distingue (INVENTAIRE §1).

Pourquoi Blender ici (et pas le rendu 2D des modules) : les icônes vanilla des objets voisins (processeur, balise,
accumulateur) et TOUTES les icônes de technologie vanilla sont des RENDUS 3D en 3/4. Une baie de serveurs, une carte
graphique ou un lustre de dilution sont des volumes : le rendu 2D les aplatirait. Chaque icône est un petit modèle à ses
vraies proportions (scene_assemblages.py), rendu à 512 px (objets) ou 512 px (technologies), fond transparent, puis
réduit ici par moyenne de boîtes en lumière LINÉAIRE (alpha prémultiplié) vers 64/32/16/8 px (objets) ou 256/128/64/32
(technologies), au format vanilla (bande 120 × 64, icon_mipmaps 4 ; bande 480 × 256).

Usage (depuis la racine du worktree ; Blender SEULEMENT par le verrou de rendu) :
  python tools/render/with_render_lock.py -- py -3.9 tools/render/pieces/calcul/icones_assemblages.py --rendre <a,b|cles|tout> --samples 12
  py -3.9 tools/render/pieces/calcul/icones_assemblages.py --assembler           # bandes PNG, MANIFEST.json, icons-b.lua
  py -3.9 tools/render/pieces/calcul/icones_assemblages.py --check               # refait les bandes depuis le cache, compare
  py -3.9 tools/render/pieces/calcul/icones_assemblages.py --planche <png>       # planche à 32/64 px avec les vanilla voisines
Cache des rendus : tools/render/cache/calcul-icones-b/<samples>/<nom>.png (ignoré par git).
"""
import argparse
import hashlib
import io
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.abspath(os.path.join(ICI, "..", "..", "..", ".."))
RACINE = os.path.abspath(os.path.join(MOD, "..", ".."))
if not os.path.isdir(os.path.join(RACINE, "data", "base")):
    RACINE = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
DATA = os.path.join(RACINE, "data", "base", "graphics")
SORTIE = os.path.join(MOD, "graphics", "calcul", "icones-b")
CACHE = os.path.join(MOD, "tools", "render", "cache", "calcul-icones-b")
BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
SCENE = os.path.join(ICI, "scene_assemblages.py")
VERSION = 1

# objet -> (âge, nom FR, icône vanilla PROVISOIRE (pour la page avant/après), vanilla voisine de comparaison)
OBJETS = {
    "fo-memory-module": (10, "Barrette de mémoire vive", "electronic-circuit", "electronic-circuit"),
    "fo-motherboard": (10, "Carte mère", "advanced-circuit", "advanced-circuit"),
    "fo-server-blade": (10, "Baie de serveurs", "beacon", "beacon"),
    "fo-graphics-card": (11, "Carte graphique", "processing-unit", "processing-unit"),
    "fo-gpu-blade": (11, "Baie d'accélérateurs", "beacon", "beacon"),
    "fo-qubit-chip": (13, "Puce à qubits", "processing-unit", "processing-unit"),
    "fo-dilution-stage": (13, "Étage à dilution", "accumulator", "accumulator"),
    "fo-quantum-processor": (13, "Processeur quantique", "processing-unit", "processing-unit"),
}
TECHNOS = {
    "fo-chip-foundry": (10, "Fonderie de puces", "advanced-electronics-2"),
    "fo-data-centers": (10, "Centres de calcul", "research-speed"),
    "fo-gpu-computing": (11, "Calcul accéléré", "advanced-electronics-2"),
    "fo-regolith-degassing": (13, "Dégazage du régolithe", "nuclear-power"),
    "fo-quantum-computing": (13, "Calcul quantique", "advanced-electronics-2"),
}
# Procédure du DC : 3 à 4 icônes clés d'abord, série après son verdict.
CLES = ["fo-memory-module", "fo-server-blade", "fo-gpu-blade", "fo-quantum-processor", "tech-fo-data-centers"]


# ------------------------------------------------------------------------------------------------------------------
# Rendu (Blender)
# ------------------------------------------------------------------------------------------------------------------
def rendre(noms, samples):
    out = os.path.join(CACHE, str(samples))
    os.makedirs(out, exist_ok=True)
    cmd = [BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1", "-P", SCENE, "--",
           "--quoi", ",".join(noms), "--out", out, "--samples", str(samples), "--taille", "512"]
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    lignes = [l for l in p.stdout.splitlines() if "[CALC-ICONES-B]" in l or "Error" in l or "Traceback" in l]
    print("\n".join(lignes))
    if p.returncode != 0:
        print(p.stdout[-4000:])
        print(p.stderr[-4000:])
        raise SystemExit("[CALC-ICONES-B] échec du rendu Blender (code %d)" % p.returncode)


# ------------------------------------------------------------------------------------------------------------------
# Réduction (lumière linéaire, alpha prémultiplié)
# ------------------------------------------------------------------------------------------------------------------
def srgb_vers_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_vers_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, 12.92 * c, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def charger(chemin):
    im = Image.open(chemin)
    a = np.asarray(im).astype(np.float64)
    a = a / (65535.0 if a.max() > 255 else 255.0)
    rgb, al = a[..., :3], a[..., 3]
    return srgb_vers_lin(rgb) * al[..., None], al


def reduire(rgb_pm, al, taille):
    n = al.shape[0]
    f = n // taille
    r = rgb_pm.reshape(taille, f, taille, f, 3).mean(axis=(1, 3))
    a = al.reshape(taille, f, taille, f).mean(axis=(1, 3))
    return r, a


def contour(rgb_pm, al, px, force):
    """Liseré sombre discret autour de la silhouette (largeur px à cette taille) : lisibilité sur fond clair, comme les
    icônes des modules validées par le DC. Le vanilla n'en a pas mais ses objets ont des bords très sombres."""
    if px <= 0:
        return rgb_pm, al
    im = Image.fromarray(np.round(al * 255).astype(np.uint8), "L")
    k = max(3, int(round(px * 2)) | 1)
    dil = np.asarray(im.filter(ImageFilter.MaxFilter(k))).astype(np.float64) / 255.0
    dil = np.asarray(Image.fromarray(np.round(dil * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(px * 0.35))).astype(np.float64) / 255.0
    ajout = np.clip(dil - al, 0, 1) * force
    sombre = np.array([0.006, 0.006, 0.008])
    return rgb_pm + sombre[None, None, :] * ajout[..., None], np.clip(al + ajout, 0, 1)


def nettete(im, rayon, quantite):
    """Accentuation douce (sRGB) de la couleur seulement ; l'alpha est gardé."""
    if quantite <= 0:
        return im
    rgb = im.convert("RGB").filter(ImageFilter.UnsharpMask(radius=rayon, percent=int(quantite), threshold=1))
    out = Image.merge("RGBA", (*rgb.split(), im.split()[3]))
    return out


def en_image(rgb_pm, al):
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(al[..., None] > 1e-4, rgb_pm / np.maximum(al[..., None], 1e-4), 0.0)
    s = lin_vers_srgb(c)
    out = np.zeros(al.shape + (4,), np.uint8)
    out[..., :3] = np.round(s * 255).astype(np.uint8)
    out[..., 3] = np.round(np.clip(al, 0, 1) * 255).astype(np.uint8)
    out[al <= 1e-4, :3] = 0
    return Image.fromarray(out, "RGBA")


def bande(chemin, tailles):
    rgb, al = charger(chemin)
    largeur = sum(tailles)
    b = Image.new("RGBA", (largeur, tailles[0]), (0, 0, 0, 0))
    x = 0
    for t in tailles:
        r, a = reduire(rgb, al, t)
        r, a = contour(r, a, {64: 1.0, 32: 0.75, 256: 2.0, 128: 1.2}.get(t, 0.0), 0.85)
        im = en_image(r, a)
        im = nettete(im, 0.6 if t <= 64 else 1.0, {64: 55, 32: 45, 256: 40, 128: 45}.get(t, 0))
        b.paste(im, (x, 0))
        x += t
    return b


def png_octets(im):
    f = io.BytesIO()
    im.save(f, "PNG", optimize=True)
    return f.getvalue()


def generer(samples, noms=None):
    """Bandes depuis le cache ; renvoie {chemin relatif: octets} et le manifeste."""
    src = os.path.join(CACHE, str(samples))
    fichiers, man = {}, dict(version=VERSION, outil="tools/render/pieces/calcul/icones_assemblages.py",
                            samples=samples, objets={}, technos={})
    for o, (age, nom, prov, _v) in sorted(OBJETS.items()):
        if noms is not None and o not in noms:
            continue
        p = os.path.join(src, o + ".png")
        if not os.path.exists(p):
            continue
        b = png_octets(bande(p, (64, 32, 16, 8)))
        fichiers[o + ".png"] = b
        man["objets"][o] = dict(age=age, nom=nom, fichier=o + ".png", icon_size=64, icon_mipmaps=4,
                                sha256=hashlib.sha256(b).hexdigest(), provisoire_avant=prov)
    for t, (age, nom, prov) in sorted(TECHNOS.items()):
        if noms is not None and "tech-" + t not in noms:
            continue
        p = os.path.join(src, "tech-" + t + ".png")
        if not os.path.exists(p):
            continue
        b = png_octets(bande(p, (256, 128, 64, 32)))
        fichiers["tech/" + t + ".png"] = b
        man["technos"][t] = dict(age=age, nom=nom, fichier="tech/" + t + ".png", icon_size=256, icon_mipmaps=4,
                                 sha256=hashlib.sha256(b).hexdigest(), provisoire_avant=prov)
    return fichiers, man


def lua_table(man):
    L = ["-- GÉNÉRÉ par tools/render/pieces/calcul/icones_assemblages.py (lot CALC-ICONES-B) : ne pas éditer à la main.",
         "-- Icônes dessinées des assemblages du calcul (objets 64 px + 3 mipmaps) et de leurs technologies (256 px + 3).",
         "-- Un objet absent de cette table garde son icône provisoire (vanilla teintée, prototypes/compute.lua).",
         "return {", "  version = %d," % man["version"], "  objets = {"]
    for o in sorted(man["objets"]):
        L.append('    ["%s"] = { icon = "__factorio-overhaul__/graphics/calcul/icones-b/%s", icon_size = 64, icon_mipmaps = 4 },'
                 % (o, man["objets"][o]["fichier"]))
    L += ["  },", "  technos = {"]
    for t in sorted(man["technos"]):
        L.append('    ["%s"] = { icon = "__factorio-overhaul__/graphics/calcul/icones-b/%s", icon_size = 256, icon_mipmaps = 4 },'
                 % (t, man["technos"][t]["fichier"]))
    L += ["  },", "}"]
    return "\n".join(L) + "\n"


def ecrire(fichiers, man):
    os.makedirs(os.path.join(SORTIE, "tech"), exist_ok=True)
    for rel, b in sorted(fichiers.items()):
        with open(os.path.join(SORTIE, rel), "wb") as f:
            f.write(b)
    with open(os.path.join(SORTIE, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    with open(os.path.join(SORTIE, "icons-b.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(lua_table(man))


# ------------------------------------------------------------------------------------------------------------------
# Planche de comparaison
# ------------------------------------------------------------------------------------------------------------------
def police(t, gras=False):
    try:
        return ImageFont.truetype("arialbd.ttf" if gras else "arial.ttf", t)
    except OSError:
        return ImageFont.load_default()


def fente(im32, fond, taille=40):
    """Case d'inventaire vanilla approchée : fente de 40 px, bord biseauté, icône de 32 px au centre."""
    c = Image.new("RGBA", (taille, taille), fond + (255,))
    d = ImageDraw.Draw(c)
    clair = tuple(min(255, v + 28) for v in fond)
    sombre = tuple(max(0, v - 30) for v in fond)
    d.rectangle((0, 0, taille - 1, taille - 1), outline=sombre)
    d.line((1, taille - 2, taille - 2, taille - 2), fill=clair)
    d.line((taille - 2, 1, taille - 2, taille - 2), fill=clair)
    c.alpha_composite(im32, ((taille - 32) // 2, (taille - 32) // 2))
    return c


def vanilla_objet(nom):
    return Image.open(os.path.join(DATA, "icons", nom + ".png")).convert("RGBA")


def vanilla_techno(nom):
    return Image.open(os.path.join(DATA, "technology", nom + ".png")).convert("RGBA")


def provisoire_objet(o):
    """L'icône provisoire d'aujourd'hui : vanilla × teinte (prototypes/compute.lua, table ICON), comme le moteur."""
    import re
    src = open(os.path.join(MOD, "prototypes", "compute.lua"), encoding="utf-8").read()
    m = re.search(r'\["%s"\]\s*=\s*\{\s*"item",\s*"([^"]+)",\s*\{\s*r\s*=\s*([\d.]+),\s*g\s*=\s*([\d.]+),\s*b\s*=\s*([\d.]+)'
                  % re.escape(o), src)
    if not m:
        return None
    im = vanilla_objet(m.group(1))
    a = np.asarray(im).astype(np.float64)
    a[..., 0] *= float(m.group(2))
    a[..., 1] *= float(m.group(3))
    a[..., 2] *= float(m.group(4))
    return Image.fromarray(np.round(a).astype(np.uint8), "RGBA")


def planche(chemin, fichiers, voisins_objets, voisins_technos):
    """Fond sombre (gris d'inventaire 49) et fond clair, côte à côte ; chaque icône : 64 px, fente de 40 px avec la
    mipmap de 32 px, 32 px agrandi × 2 au pixel. Vanilla voisines à droite, aux mêmes tailles."""
    objs = [k for k in fichiers if not k.startswith("tech/")]
    techs = [k for k in fichiers if k.startswith("tech/")]
    cell = 150
    fonds = [("fond sombre (inventaire)", (49, 48, 49)), ("fond clair", (214, 210, 200))]
    lignes_obj = [("proposition", [(k[:-4], Image.open(io.BytesIO(fichiers[k])).convert("RGBA")) for k in objs]),
                  ("vanilla voisines", [(v, vanilla_objet(v)) for v in voisins_objets])]
    larg = 150 + cell * max(len(lignes_obj[0][1]), len(voisins_objets), 1)
    th = 300
    larg = max(larg, 40 + (th + 20) * max(1, len(techs) + len(voisins_technos)))
    H = 70 + len(fonds) * (2 * 190 + 40) + 2 * (th + 70) + 20
    im = Image.new("RGB", (larg, H), (24, 24, 26))
    d = ImageDraw.Draw(im)
    d.text((16, 12), "CALC-ICONES-B : icônes clés (proposition à juger) à côté des icônes vanilla voisines",
           fill=(235, 235, 235), font=police(18, True))
    d.text((16, 40), "Chaque case : 64 px | fente d'inventaire 40 px avec la mipmap de 32 px | 32 px agrandi x2 au pixel. "
                     "Images du fichier, sans retouche.", fill=(200, 200, 200), font=police(13))
    y = 70
    for libelle, fond in fonds:
        d.rectangle((0, y, larg, y + 2 * 190 + 30), fill=fond)
        enc = (230, 230, 230) if sum(fond) < 300 else (20, 20, 20)
        d.text((16, y + 6), libelle, fill=enc, font=police(13, True))
        yy = y + 26
        for titre, items in lignes_obj:
            d.text((16, yy + 2), titre, fill=enc, font=police(12))
            for i, (nom, b) in enumerate(items):
                x = 150 + i * cell
                c64 = b.crop((0, 0, 64, 64))
                c32 = b.crop((64, 0, 96, 32))
                t = Image.new("RGBA", (cell, 170), fond + (255,))
                t.alpha_composite(c64, (4, 18))
                t.alpha_composite(fente(c32, (fond[0] - 12 if sum(fond) > 300 else 62,) * 3), (74, 30))
                t.alpha_composite(c32.resize((64, 64), Image.NEAREST), (4, 90))
                t.alpha_composite(c32, (78, 106))
                im.paste(t.convert("RGB"), (x, yy))
                d.text((x + 4, yy + 2), nom[:24], fill=enc, font=police(11))
            yy += 185
        y += 2 * 190 + 40
    # technologies
    for libelle, fond in fonds:
        d.rectangle((0, y, larg, y + th + 60), fill=fond)
        enc = (230, 230, 230) if sum(fond) < 300 else (20, 20, 20)
        d.text((16, y + 6), "technologies, " + libelle + " : 256 px puis 64 px (mipmap) ; à droite les vanilla",
               fill=enc, font=police(13, True))
        items = [(k[5:-4], Image.open(io.BytesIO(fichiers[k])).convert("RGBA")) for k in techs] + \
                [(v + " (vanilla)", vanilla_techno(v)) for v in voisins_technos]
        for i, (nom, b) in enumerate(items):
            x = 40 + i * (th + 20)
            t = Image.new("RGBA", (th, th), fond + (255,))
            t.alpha_composite(b.crop((0, 0, 256, 256)), (0, 20))
            t.alpha_composite(b.crop((384, 0, 448, 64)), (th - 66, th - 70))
            im.paste(t.convert("RGB"), (x, y + 30))
            d.text((x, y + 30), nom, fill=enc, font=police(12))
        y += th + 70
    im.save(chemin)


def provisoire_techno(t):
    """Icône provisoire d'une technologie : vanilla × teinte (prototypes/compute.lua, table TECH_ICON)."""
    import re
    src = open(os.path.join(MOD, "prototypes", "compute.lua"), encoding="utf-8").read()
    m = re.search(r'\["%s"\]\s*=\s*\{\s*"([^"]+)",\s*\{\s*r\s*=\s*([\d.]+),\s*g\s*=\s*([\d.]+),\s*b\s*=\s*([\d.]+)'
                  % re.escape(t), src)
    nom = {"research-speed-1": "research-speed"}.get(m.group(1), m.group(1))
    a = np.asarray(vanilla_techno(nom)).astype(np.float64)
    for i in range(3):
        a[..., i] *= float(m.group(2 + i))
    return Image.fromarray(np.round(a).astype(np.uint8), "RGBA")


def mesures32(im):
    """Mesures à 32 px (la mipmap de l'inventaire) : part couverte (alpha > 0,5), luminance moyenne (sRGB, 0-255),
    saturation moyenne (HSV, 0-1), sur les pixels couverts."""
    c = np.asarray(im.crop((64, 0, 96, 32))).astype(np.float64)
    m = c[..., 3] > 127
    rgb = c[m][:, :3]
    lum = (0.2126 * rgb[:, 0] + 0.7152 * rgb[:, 1] + 0.0722 * rgb[:, 2]).mean()
    mx, mn = rgb.max(axis=1), rgb.min(axis=1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0).mean()
    return dict(couverture=float(m.mean()), luminance=float(lum), saturation=float(sat))


def ecart32(a, b):
    """Écart moyen (0-255) entre deux icônes de 32 px posées sur le fond d'inventaire (49, 48, 49)."""
    def sur_fond(im):
        c = np.asarray(im.crop((64, 0, 96, 32))).astype(np.float64)
        al = c[..., 3:4] / 255.0
        return c[..., :3] * al + np.array([49, 48, 49]) * (1 - al)
    return float(np.abs(sur_fond(a) - sur_fond(b)).mean())


PAGE_CSS = """
:root{--fond:#1b1b1d;--txt:#e6e6e6;--doux:#a8a8a8;--carte:#262628}
@media (prefers-color-scheme: light){:root:not([data-theme="dark"]){--fond:#1b1b1d}}
body{background:var(--fond);color:var(--txt);font:15px/1.5 system-ui,Segoe UI,Arial,sans-serif;margin:0;padding:16px}
h1{font-size:22px;margin:0 0 6px} h2{font-size:18px;margin:28px 0 8px} p,li{max-width:1000px}
table{border-collapse:collapse;margin:8px 0} td,th{padding:6px 10px;border-bottom:1px solid #444;vertical-align:middle;text-align:center}
th{font-weight:600} .g{text-align:left}
.s{background:#313031} .c{background:#d6d2c8;color:#111}
img{image-rendering:pixelated;vertical-align:middle;margin:2px}
.tech img{image-rendering:auto;max-width:100%}
.note{background:var(--carte);padding:10px 14px;border-left:3px solid #3AA8FF;max-width:1000px}
.wrap{overflow-x:auto}
"""


def page(dossier, fichiers, notes_html=""):
    """Page LOCALE avant (provisoire) | après | vanilla, sur fond sombre et clair, avec mesures."""
    import html as H
    os.makedirs(os.path.join(dossier, "img"), exist_ok=True)

    def sauve(im, nom, agrandir=1):
        if agrandir != 1:
            im = im.resize((im.size[0] * agrandir, im.size[1] * agrandir), Image.NEAREST)
        im.save(os.path.join(dossier, "img", nom))
        return "img/" + nom

    def cases(b, nom):
        return dict(i64=sauve(b.crop((0, 0, 64, 64)), nom + "-64.png"),
                    f32=sauve(fente(b.crop((64, 0, 96, 32)), (62, 62, 62)), nom + "-fente.png"),
                    x2=sauve(b.crop((64, 0, 96, 32)), nom + "-32x2.png", 2))

    lignes, mes = [], []
    for o in sorted(k[:-4] for k in fichiers if not k.startswith("tech/")):
        age, nom, prov, vois = OBJETS[o]
        apres = Image.open(io.BytesIO(fichiers[o + ".png"])).convert("RGBA")
        avant = provisoire_objet(o)
        van = vanilla_objet(vois)
        c = dict(avant=cases(avant, o + "-avant"), apres=cases(apres, o + "-apres"),
                 van=cases(van, o + "-vanilla-" + vois))
        lignes.append((o, age, nom, vois, c))
        mes.append((o, mesures32(apres), vois, mesures32(van)))
    tl = []
    for t in sorted(k[5:-4] for k in fichiers if k.startswith("tech/")):
        age, nom, vois = TECHNOS[t]
        apres = Image.open(io.BytesIO(fichiers["tech/" + t + ".png"])).convert("RGBA")
        av = provisoire_techno(t)
        van = vanilla_techno(vois)
        tl.append((t, age, nom, vois, sauve(av.crop((0, 0, 256, 256)), "tech-%s-avant.png" % t),
                   sauve(apres.crop((0, 0, 256, 256)), "tech-%s-apres.png" % t),
                   sauve(van.crop((0, 0, 256, 256)), "tech-%s-vanilla.png" % t),
                   sauve(apres.crop((384, 0, 448, 64)), "tech-%s-apres-64.png" % t),
                   sauve(van.crop((384, 0, 448, 64)), "tech-%s-vanilla-64.png" % t)))
    ec = ""
    if "fo-server-blade.png" in fichiers and "fo-gpu-blade.png" in fichiers:
        sb = Image.open(io.BytesIO(fichiers["fo-server-blade.png"])).convert("RGBA")
        gb = Image.open(io.BytesIO(fichiers["fo-gpu-blade.png"])).convert("RGBA")
        ref = ecart32(vanilla_objet("advanced-circuit"), vanilla_objet("processing-unit"))
        ref2 = ecart32(vanilla_objet("speed-module"), vanilla_objet("speed-module-2"))
        ec = ("<p>Écart moyen à 32 px, sur le fond d'inventaire, entre baie de serveurs et baie d'accélérateurs : "
              "<b>%.1f</b> (sur 255). Repères vanilla : circuit avancé / processeur %.1f (même dessin, autre couleur) ; "
              "module de vitesse 1 / 2 : %.1f.</p>" % (ecart32(sb, gb), ref, ref2))
    h = ["<!doctype html><html lang='fr'><head><meta charset='utf-8'>"
         "<meta name='viewport' content='width=device-width,initial-scale=1'>",
         "<title>Icônes du calcul B</title><style>%s</style></head><body>" % PAGE_CSS,
         "<h1>CALC-ICONES-B : icônes des assemblages et des technologies du calcul</h1>",
         "<p><b>Proposition à juger, rien n'est validé.</b> Seul le verdict du Directeur Créatif sur ces images valide un "
         "design. Icônes CLÉS seulement (procédure : 3 à 4 icônes, puis la série après votre verdict).</p>", notes_html]
    for fond, cls in (("fond d'inventaire sombre", "s"), ("fond clair", "c")):
        h.append("<h2>Objets, %s : avant (provisoire) | après (proposition) | vanilla voisine</h2>" % fond)
        h.append("<div class='wrap'><table class='%s'><tr><th class='g'>objet</th><th>âge</th><th colspan=3>avant</th>"
                 "<th colspan=3>après</th><th colspan=3>vanilla</th></tr>" % cls)
        h.append("<tr><th></th><th></th>" + "<th>64</th><th>fente 32</th><th>32 ×2</th>" * 3 + "</tr>")
        for o, age, nom, vois, c in lignes:
            r = "<tr><td class='g'>%s<br><small>%s</small></td><td>%d</td>" % (H.escape(nom), o, age)
            for k in ("avant", "apres", "van"):
                r += "<td><img src='%s'></td><td><img src='%s'></td><td><img src='%s'></td>" % (
                    c[k]["i64"], c[k]["f32"], c[k]["x2"])
            h.append(r + "</tr>")
        h.append("</table></div>")
    h.append("<h2>Mesures à 32 px (taille de l'inventaire)</h2><table class='s'><tr><th class='g'>icône</th>"
             "<th>couverture</th><th>luminance</th><th>saturation</th><th class='g'>vanilla voisine</th><th>couverture</th>"
             "<th>luminance</th><th>saturation</th></tr>")
    for o, m, v, mv in mes:
        h.append("<tr><td class='g'>%s</td><td>%.0f %%</td><td>%.0f</td><td>%.2f</td><td class='g'>%s</td><td>%.0f %%</td>"
                 "<td>%.0f</td><td>%.2f</td></tr>" % (o, 100 * m["couverture"], m["luminance"], m["saturation"], v,
                                                      100 * mv["couverture"], mv["luminance"], mv["saturation"]))
    h.append("</table>" + ec)
    if tl:
        h.append("<h2>Technologies (256 px, puis la mipmap de 64 px)</h2><div class='wrap'><table class='tech s'>"
                 "<tr><th class='g'>technologie</th><th>avant (provisoire)</th><th>après</th><th>vanilla voisine</th>"
                 "<th>64 px : après | vanilla</th></tr>")
        for t, age, nom, vois, av, ap, va, a64, v64 in tl:
            h.append("<tr><td class='g'>%s<br><small>%s, âge %d</small></td><td><img src='%s'></td><td><img src='%s'></td>"
                     "<td><img src='%s'><br><small>%s</small></td><td><img src='%s'> <img src='%s'></td></tr>"
                     % (H.escape(nom), t, age, av, ap, va, vois, a64, v64))
        h.append("</table></div>")
    h.append("<h2>Planche complète</h2><p><img src='planche.png' style='image-rendering:auto;max-width:100%'></p>")
    h.append("</body></html>")
    with open(os.path.join(dossier, "index.html"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(h))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--rendre", help="noms séparés par des virgules, ou « cles », ou « tout »")
    ap.add_argument("--samples", type=int, default=48, help="48 : rendu final des icônes clés ; 8 à 12 pour les essais")
    ap.add_argument("--assembler", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--seulement", help="n'assembler que ces noms (« cles »)")
    ap.add_argument("--planche")
    ap.add_argument("--page", help="dossier de la page .html LOCALE (index.html, img/, planche.png)")
    ap.add_argument("--notes", help="fichier HTML de notes inséré en tête de la page")
    a = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    tous = list(OBJETS) + ["tech-" + t for t in TECHNOS]
    if a.rendre:
        noms = CLES if a.rendre == "cles" else tous if a.rendre == "tout" else a.rendre.split(",")
        rendre(noms, a.samples)
    sel = None
    if a.seulement:
        sel = CLES if a.seulement == "cles" else a.seulement.split(",")
    if a.assembler or a.check or a.planche or a.page:
        fichiers, man = generer(a.samples, sel)
        if a.check:
            ref = json.load(open(os.path.join(SORTIE, "MANIFEST.json"), encoding="utf-8"))
            pb = []
            for grp in ("objets", "technos"):
                for k, d in sorted(man[grp].items()):
                    r = ref[grp].get(k)
                    if not r or r["sha256"] != d["sha256"]:
                        pb.append(k)
                    elif hashlib.sha256(open(os.path.join(SORTIE, d["fichier"]), "rb").read()).hexdigest() != d["sha256"]:
                        pb.append(k + " (fichier)")
            if open(os.path.join(SORTIE, "icons-b.lua"), encoding="utf-8").read() != lua_table(man):
                pb.append("icons-b.lua")
            print("[CALC-ICONES-B] contrôle : %d objet(s), %d techno(s), %d écart(s)%s"
                  % (len(man["objets"]), len(man["technos"]), len(pb), (" : " + ", ".join(pb)) if pb else ""))
            return 1 if pb else 0
        if a.assembler:
            ecrire(fichiers, man)
            print("[CALC-ICONES-B] %d fichier(s) dans %s" % (len(fichiers), SORTIE))
        if a.planche:
            vo = sorted(set(OBJETS[k[:-4]][3] for k in fichiers if not k.startswith("tech/")))
            vt = sorted(set(TECHNOS[k[5:-4]][2] for k in fichiers if k.startswith("tech/")))
            planche(a.planche, fichiers, vo + ["low-density-structure"], vt)
            print("[CALC-ICONES-B] planche : %s" % a.planche)
        if a.page:
            os.makedirs(a.page, exist_ok=True)
            vo = sorted(set(OBJETS[k[:-4]][3] for k in fichiers if not k.startswith("tech/")))
            vt = sorted(set(TECHNOS[k[5:-4]][2] for k in fichiers if k.startswith("tech/")))
            planche(os.path.join(a.page, "planche.png"), fichiers, vo + ["low-density-structure"], vt)
            notes = open(a.notes, encoding="utf-8").read() if a.notes else ""
            page(a.page, fichiers, notes)
            print("[CALC-ICONES-B] page : %s" % os.path.join(a.page, "index.html"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
