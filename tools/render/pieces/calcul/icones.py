"""ICÔNES DE LA CHAÎNE DU CALCUL : le seul script qui génère graphics/calcul/{icones,tech}/, icones.lua et MANIFEST.json.

Toutes les icônes sont des RENDUS 3D (Blender : scene_icones.py), comme les icônes vanilla : modelé réel, reflets, ombre
interne. Réduction en lumière linéaire (alpha prémultiplié) vers le format vanilla : 64/32/16/8 (bande 120 × 64,
icon_mipmaps 4) pour les objets et les fluides ; 256/128/64/32 (bande 480 × 256) pour les technologies.

Depuis la racine du worktree (Blender SEULEMENT par le verrou de rendu) :
  python tools/render/with_render_lock.py -- py -3.9 tools/render/pieces/calcul/icones.py --rendre tout --samples 64
  py -3.9 tools/render/pieces/calcul/icones.py [--samples 64]     # bandes, icones.lua et MANIFEST depuis les rendus gardés
  py -3.9 tools/render/pieces/calcul/icones.py --check            # refait les bandes en mémoire, compare, code 1 si écart
  py -3.9 tools/render/pieces/calcul/icones.py --manifeste        # sha256 des PNG du dépôt contre MANIFEST.json (sans les rendus), code 1 si écart
  py -3.9 tools/render/pieces/calcul/icones.py --planche <png> [--samples N]   # planche à côté des vanilla
Rendus gardés : <racine>/fo-logs/2026-11-01_CALCUL-DESIGN/icones/rendus/<samples>/ (ou --cache, à GARDER).
"""
import argparse
import hashlib
import io
import json
import os
import subprocess

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.abspath(os.path.join(ICI, "..", "..", "..", ".."))
RACINE = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
DATA = os.path.join(RACINE, "data", "base", "graphics")
CACHE = os.path.join(RACINE, "fo-logs", "2026-11-01_CALCUL-DESIGN", "icones", "rendus")
BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
SCENE = os.path.join(ICI, "scene_icones.py")
SORTIE = os.path.join(MOD, "graphics", "calcul")
VERSION = 1

OBJETS = ["fo-photomask", "fo-etched-wafer", "fo-crystal-laser", "fo-logic-die", "fo-dram-die", "fo-sram-die", "fo-heat-sink",
          "fo-memory-module", "fo-motherboard", "fo-graphics-card", "fo-degassed-ilmenite", "fo-qubit-chip", "fo-dilution-stage",
          "fo-quantum-processor", "fo-silicon-ingot", "fo-exposed-wafer", "fo-nand-die", "fo-flash-drive", "fo-optical-fiber",
          "fo-network-switch"]
BAIES = ["fo-server-blade", "fo-memory-rack", "fo-storage-rack", "fo-network-rack", "fo-cooling-rack", "fo-gpu-blade", "fo-quantum-rack"]
FLUIDES = ["fo-photoresist", "fo-helium-3", "fo-chilled-water", "fo-warm-water", "fo-dilution-mix"]
TECHNOS = ["fo-chip-foundry", "fo-data-centers", "fo-gpu-computing", "fo-regolith-degassing", "fo-quantum-computing", "fo-wafer-fab",
           "fo-data-centers-2"]
ITEMS = OBJETS + BAIES + FLUIDES


# ------------------------------------------------------------------------------------------------------------------
# Rendu
# ------------------------------------------------------------------------------------------------------------------
def rendre(noms, samples, cache):
    out = os.path.join(cache, str(samples))
    os.makedirs(out, exist_ok=True)
    cmd = [BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1", "-P", SCENE, "--", "--quoi", ",".join(noms),
           "--out", out, "--samples", str(samples), "--taille", "512"]
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    print("\n".join(l for l in p.stdout.splitlines() if "[CALC-ICONES]" in l or "Error" in l or "Traceback" in l or 'File "' in l))
    if p.returncode != 0:
        print(p.stdout[-3000:])
        print(p.stderr[-3000:])
        raise SystemExit("[CALC-ICONES] échec du rendu Blender (code %d)" % p.returncode)


# ------------------------------------------------------------------------------------------------------------------
# Réduction (lumière linéaire, alpha prémultiplié)
# ------------------------------------------------------------------------------------------------------------------
def srgb_vers_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_vers_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, 12.92 * c, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def charger(chemin):
    a = np.asarray(Image.open(chemin)).astype(np.float64)
    a = a / (65535.0 if a.max() > 255 else 255.0)
    rgb, al = a[..., :3], a[..., 3]
    return srgb_vers_lin(rgb) * al[..., None], al


def reduire(rgb_pm, al, taille):
    f = al.shape[0] // taille
    return rgb_pm.reshape(taille, f, taille, f, 3).mean(axis=(1, 3)), al.reshape(taille, f, taille, f).mean(axis=(1, 3))


def contour(rgb_pm, al, px, force):
    """Liseré sombre discret : le bord des objets vanilla est très sombre, ce qui les détache sur fond clair comme sombre."""
    if px <= 0:
        return rgb_pm, al
    im = Image.fromarray(np.round(al * 255).astype(np.uint8), "L")
    k = max(3, int(round(px * 2)) | 1)
    dil = im.filter(ImageFilter.MaxFilter(k)).filter(ImageFilter.GaussianBlur(px * 0.35))
    ajout = np.clip(np.asarray(dil).astype(np.float64) / 255.0 - al, 0, 1) * force
    sombre = np.array([0.006, 0.006, 0.008])
    return rgb_pm + sombre[None, None, :] * ajout[..., None], np.clip(al + ajout, 0, 1)


def nettete(im, rayon, quantite):
    """Accentuation douce de la couleur seulement ; l'alpha est gardé."""
    if quantite <= 0:
        return im
    rgb = im.convert("RGB").filter(ImageFilter.UnsharpMask(radius=rayon, percent=int(quantite), threshold=1))
    return Image.merge("RGBA", (*rgb.split(), im.split()[3]))


def en_image(rgb_pm, al):
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(al[..., None] > 1e-4, rgb_pm / np.maximum(al[..., None], 1e-4), 0.0)
    out = np.zeros(al.shape + (4,), np.uint8)
    out[..., :3] = np.round(lin_vers_srgb(c) * 255).astype(np.uint8)
    out[..., 3] = np.round(np.clip(al, 0, 1) * 255).astype(np.uint8)
    out[al <= 1e-4, :3] = 0
    return Image.fromarray(out, "RGBA")


def bande(chemin, tailles):
    rgb, al = charger(chemin)
    b = Image.new("RGBA", (sum(tailles), tailles[0]), (0, 0, 0, 0))
    x = 0
    for t in tailles:
        r, a = reduire(rgb, al, t)
        r, a = contour(r, a, {64: 0.9, 32: 0.7, 256: 2.0, 128: 1.2}.get(t, 0.0), 0.8)
        im = nettete(en_image(r, a), 0.6 if t <= 64 else 1.0, {64: 70, 32: 60, 16: 40, 256: 45, 128: 50}.get(t, 0))
        b.paste(im, (x, 0))
        x += t
    return b


def png_octets(im):
    f = io.BytesIO()
    im.save(f, "PNG", optimize=True)
    return f.getvalue()


# ------------------------------------------------------------------------------------------------------------------
# Génération
# ------------------------------------------------------------------------------------------------------------------
def generer(samples, cache):
    src = os.path.join(cache, str(samples))
    fichiers, man = {}, dict(version=VERSION, outil="tools/render/pieces/calcul/icones.py", samples=samples, fichiers={})
    manque = []
    for genre, liste, tailles, dossier, cle in (("item", ITEMS, (64, 32, 16, 8), "icones", ""), ("tech", TECHNOS, (256, 128, 64, 32), "tech", "tech-")):
        for nom in liste:
            p = os.path.join(src, cle + nom + ".png")
            if not os.path.exists(p):
                manque.append(cle + nom)
                continue
            b = png_octets(bande(p, tailles))
            rel = dossier + "/" + nom + ".png"
            fichiers[rel] = b
            man["fichiers"][rel] = dict(genre=genre, icon_size=tailles[0], icon_mipmaps=4, sha256=hashlib.sha256(b).hexdigest())
    if manque:
        raise SystemExit("[CALC-ICONES] rendus manquants (samples %d) : %s" % (samples, ", ".join(manque)))
    return fichiers, man


def lua_table():
    L = ["-- GÉNÉRÉ par tools/render/pieces/calcul/icones.py : ne pas éditer à la main.",
         "-- Icônes de la chaîne du calcul : objets et fluides (64 px + 3 mipmaps), technologies (256 px + 3).",
         "return {", "  item = {"]
    for n in sorted(ITEMS):
        L.append('    ["%s"] = { icon = "__factorio-overhaul__/graphics/calcul/icones/%s.png", icon_size = 64, icon_mipmaps = 4 },' % (n, n))
    L += ["  },", "  tech = {"]
    for n in sorted(TECHNOS):
        L.append('    ["%s"] = { icon = "__factorio-overhaul__/graphics/calcul/tech/%s.png", icon_size = 256, icon_mipmaps = 4 },' % (n, n))
    L += ["  },", "}"]
    return "\n".join(L) + "\n"


def texte_manifeste(man):
    return json.dumps(man, ensure_ascii=False, indent=1, sort_keys=True) + "\n"


def ecrire(fichiers, man):
    for d in ("icones", "tech"):
        os.makedirs(os.path.join(SORTIE, d), exist_ok=True)
    for rel, b in sorted(fichiers.items()):
        with open(os.path.join(SORTIE, rel.replace("/", os.sep)), "wb") as f:
            f.write(b)
    for rel, txt in (("icones/MANIFEST.json", texte_manifeste(man)), ("icones/icones.lua", lua_table())):
        with open(os.path.join(SORTIE, rel.replace("/", os.sep)), "w", encoding="utf-8", newline="\n") as f:
            f.write(txt)


def verifier(fichiers, man):
    ecarts = 0
    for rel, b in sorted(fichiers.items()):
        p = os.path.join(SORTIE, rel.replace("/", os.sep))
        if not os.path.exists(p) or open(p, "rb").read() != b:
            print("ÉCART", rel)
            ecarts += 1
    for rel, txt in (("icones/MANIFEST.json", texte_manifeste(man)), ("icones/icones.lua", lua_table())):
        p = os.path.join(SORTIE, rel.replace("/", os.sep))
        if not os.path.exists(p) or open(p, encoding="utf-8", newline="").read() != txt:
            print("ÉCART", rel)
            ecarts += 1
    print("[CALC-ICONES] %d objet(s) et fluide(s), %d technologie(s), %d écart(s)" % (len(ITEMS), len(TECHNOS), ecarts))
    return ecarts


# ------------------------------------------------------------------------------------------------------------------
# Planche : chaque icône à 64 px × 2, à 32 px dans une case d'inventaire et à 32 px × 2, près d'icônes vanilla
# ------------------------------------------------------------------------------------------------------------------
FOND = (49, 48, 49)
VANILLA = ["electronic-circuit", "processing-unit", "low-density-structure", "speed-module", "battery", "beacon", "engine-unit", "fluid/water", "fluid/heavy-oil",
           "fluid/sulfuric-acid", "fluid/petroleum-gas"]


def police(t, gras=False):
    try:
        return ImageFont.truetype("arialbd.ttf" if gras else "arial.ttf", t)
    except OSError:
        return ImageFont.load_default()


def fente(im32, taille=40):
    c = Image.new("RGBA", (taille, taille), (44, 44, 44, 255))
    d = ImageDraw.Draw(c)
    d.rectangle((0, 0, taille - 1, taille - 1), outline=(24, 24, 24))
    d.line((1, taille - 2, taille - 2, taille - 2), fill=(80, 80, 80))
    d.line((taille - 2, 1, taille - 2, taille - 2), fill=(80, 80, 80))
    c.alpha_composite(im32, ((taille - 32) // 2, (taille - 32) // 2))
    return c


def mips(b, t0):
    return b.crop((0, 0, t0, t0)), b.crop((t0, 0, t0 + t0 // 2, t0 // 2))


def planche(sortie, samples, cache):
    src = os.path.join(cache, str(samples))
    disp = [n for n in ITEMS if os.path.exists(os.path.join(src, n + ".png"))]
    ligne = 8
    cw, ch = 176, 152
    van_h = 112
    hauteur = 12 + 26 + (len(disp) + ligne - 1) // ligne * ch + 26 + van_h + 20
    tech = [t for t in TECHNOS if os.path.exists(os.path.join(src, "tech-" + t + ".png"))]
    hauteur += 26 + 340 * ((len(tech) + 3) // 4)
    im = Image.new("RGBA", (ligne * cw + 24, hauteur), FOND + (255,))
    d = ImageDraw.Draw(im)
    d.text((12, 8), "Chaine du calcul : objets, baies, fluides | 64 px x 2 (sans lissage), 32 px en case, 32 px nu | %d echantillons" % samples, font=police(15, True), fill=(235, 235, 235))
    y0 = 36
    for i, n in enumerate(disp):
        b = bande(os.path.join(src, n + ".png"), (64, 32, 16, 8))
        i64, i32 = mips(b, 64)
        x, y = 12 + (i % ligne) * cw, y0 + (i // ligne) * ch
        d.text((x, y), n[3:], font=police(11), fill=(205, 205, 205))
        im.alpha_composite(i64.resize((128, 128), Image.NEAREST), (x, y + 16))
        im.alpha_composite(fente(i32), (x + 130, y + 16))
        im.alpha_composite(i32, (x + 134, y + 62))
    y = y0 + (len(disp) + ligne - 1) // ligne * ch + 4
    d.text((12, y), "Vanilla, a la meme echelle", font=police(13, True), fill=(235, 235, 235))
    y += 20
    x = 12
    for n in VANILLA:
        a = Image.open(os.path.join(DATA, "icons", n + ".png")).convert("RGBA")
        i64 = a.crop((0, 0, 64, 64))
        i32 = a.crop((64, 0, 96, 32))
        im.alpha_composite(i64, (x, y))
        im.alpha_composite(fente(i32), (x + 66, y + 12))
        x += 112
    y += van_h - 20
    d.text((12, y), "Technologies : 256 px, puis mipmaps 64 et 32", font=police(15, True), fill=(235, 235, 235))
    y += 24
    for i, t in enumerate(tech):
        b = bande(os.path.join(src, "tech-" + t + ".png"), (256, 128, 64, 32))
        x0, y0t = 12 + (i % 4) * 340, y + (i // 4) * 340
        d.text((x0, y0t), t, font=police(11), fill=(205, 205, 205))
        im.alpha_composite(b.crop((0, 0, 256, 256)), (x0, y0t + 16))
        im.alpha_composite(b.crop((384, 0, 448, 64)), (x0 + 258, y0t + 40))
        im.alpha_composite(fente(b.crop((448, 0, 480, 32))), (x0 + 258, y0t + 110))
    im.convert("RGB").save(sortie)
    print("[CALC-ICONES] planche : %s (%d icônes)" % (sortie, len(disp) + len(tech)))


def verifier_manifeste():
    """Sans les rendus gardés : chaque PNG du dépôt porte la somme du manifeste, et le manifeste n'oublie ni n'invente aucun fichier."""
    chemin = os.path.join(SORTIE, "icones", "MANIFEST.json")
    man = json.load(open(chemin, encoding="utf-8"))
    ecarts, vus = 0, set()
    for rel, m in sorted(man["fichiers"].items()):
        vus.add(rel)
        p = os.path.join(SORTIE, rel.replace("/", os.sep))
        if not os.path.exists(p):
            print("MANQUE", rel)
            ecarts += 1
        elif hashlib.sha256(open(p, "rb").read()).hexdigest() != m["sha256"]:
            print("SOMME FAUSSE", rel)
            ecarts += 1
    attendus = {"icones/" + n + ".png" for n in ITEMS} | {"tech/" + n + ".png" for n in TECHNOS}
    for rel in sorted(attendus - vus):
        print("ABSENT DU MANIFESTE", rel)
        ecarts += 1
    for rel in sorted(vus - attendus):
        print("EN TROP AU MANIFESTE", rel)
        ecarts += 1
    for d in ("icones", "tech"):
        for f in sorted(os.listdir(os.path.join(SORTIE, d))):
            if f.endswith(".png") and d + "/" + f not in vus:
                print("FICHIER ORPHELIN", d + "/" + f)
                ecarts += 1
    print("[CALC-ICONES] manifeste : %d fichier(s), %d écart(s)" % (len(vus), ecarts))
    return ecarts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rendre")
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--cache", default=CACHE)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--planche")
    ap.add_argument("--manifeste", action="store_true")
    a = ap.parse_args()
    if a.manifeste:
        return 1 if verifier_manifeste() else 0
    if a.rendre:
        noms = (ITEMS + ["tech-" + t for t in TECHNOS]) if a.rendre == "tout" else a.rendre.split(",")
        rendre(noms, a.samples, a.cache)
    if a.planche:
        planche(a.planche, a.samples, a.cache)
        return 0
    if a.rendre and a.rendre != "tout":
        return 0
    fichiers, man = generer(a.samples, a.cache)
    if a.check:
        return 1 if verifier(fichiers, man) else 0
    ecrire(fichiers, man)
    verifier(fichiers, man)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
