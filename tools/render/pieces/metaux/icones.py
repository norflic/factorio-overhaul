"""ICÔNES DES MÉTAUX (lot ICONES-DISTINCTES, 11/11) : le seul script qui génère graphics/metaux/icones/, icones.lua et
MANIFEST.json.

5 objets (64 px + 3 mipmaps) qui montraient tous une copie teintée de la plaque d'acier vanilla (prototypes/crafts.lua et
titanium.lua) : tôle magnétique, billettes de fer, de cuivre et de tungstène, plaque de titane. Rendus 3D (Blender :
mx_scene.py) sur le socle des icônes du calcul ; la réduction (lumière linéaire, liseré, netteté) est CELLE du calcul
(tools/render/pieces/calcul/icones.py), importée.

Depuis la racine du worktree (Blender SEULEMENT par le verrou de rendu) :
  python tools/render/with_render_lock.py -- py -3.9 tools/render/pieces/metaux/icones.py --rendre tout --samples 64
  py -3.9 tools/render/pieces/metaux/icones.py [--samples 64]     # bandes, icones.lua et MANIFEST depuis les rendus gardés
  py -3.9 tools/render/pieces/metaux/icones.py --check            # refait les bandes en mémoire, compare, code 1 si écart
  py -3.9 tools/render/pieces/metaux/icones.py --manifeste        # sha256 des PNG du dépôt contre MANIFEST.json, code 1 si écart
  py -3.9 tools/render/pieces/metaux/icones.py --planche <png>    # planche : icône teintée remplacée, puis nouvelle icône
Rendus gardés : <racine>/fo-logs/2026-11-11_ICONES-DISTINCTES/rendus/<samples>/ (ou --cache, à GARDER).
"""
import argparse
import hashlib
import importlib.util
import json
import os
import subprocess

from PIL import Image, ImageDraw

ICI = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.abspath(os.path.join(ICI, "..", "..", "..", ".."))
RACINE = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
DATA = os.path.join(RACINE, "data", "base", "graphics")
CACHE = os.path.join(RACINE, "fo-logs", "2026-11-11_ICONES-DISTINCTES", "rendus")
BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
SCENE = os.path.join(ICI, "mx_scene.py")
SORTIE = os.path.join(MOD, "graphics", "metaux")
VERSION = 1

_spec = importlib.util.spec_from_file_location("calcul_icones", os.path.join(ICI, "..", "calcul", "icones.py"))
CI = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(CI)

ITEMS = ["fo-magnetic-steel", "fo-iron-plate-r8", "fo-copper-plate-r8", "fo-tungsten-plate-r8", "fo-titanium-plate"]
NOMS_FR = {"fo-magnetic-steel": "Tole magnetique", "fo-iron-plate-r8": "Billette de fer", "fo-copper-plate-r8": "Billette de cuivre",
           "fo-tungsten-plate-r8": "Billette de tungstene", "fo-titanium-plate": "Plaque de titane"}
# Icône remplacée (ce que le jeu montrait à 0.6.91) : plaque d'acier vanilla et teinte qui MULTIPLIE (F36), lues dans
# prototypes/crafts.lua (ICON) et prototypes/titanium.lua (ICON).
REMPLACE = {
    "fo-magnetic-steel": ("icons/steel-plate", (0.72, 0.78, 0.95)),
    "fo-iron-plate-r8": ("icons/steel-plate", (0.82, 0.86, 0.96)),
    "fo-copper-plate-r8": ("icons/steel-plate", (1.00, 0.66, 0.46)),
    "fo-tungsten-plate-r8": ("icons/steel-plate", (0.60, 0.62, 0.70)),
    "fo-titanium-plate": ("icons/steel-plate", (0.96, 0.97, 1.00)),
}


def rendre(noms, samples, cache, taille=512):
    out = os.path.join(cache, str(samples))
    os.makedirs(out, exist_ok=True)
    cmd = [BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1", "-P", SCENE, "--", "--quoi", ",".join(noms),
           "--out", out, "--samples", str(samples), "--taille", str(taille)]
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    print("\n".join(l for l in p.stdout.splitlines() if "[CALC-ICONES]" in l or "Error" in l or "Traceback" in l or 'File "' in l))
    if p.returncode != 0:
        print(p.stdout[-3000:])
        print(p.stderr[-3000:])
        raise SystemExit("[MX-ICONES] échec du rendu Blender (code %d)" % p.returncode)


def generer(samples, cache):
    src = os.path.join(cache, str(samples))
    fichiers, man = {}, dict(version=VERSION, outil="tools/render/pieces/metaux/icones.py", samples=samples, fichiers={})
    manque = []
    for nom in ITEMS:
        p = os.path.join(src, nom + ".png")
        if not os.path.exists(p):
            manque.append(nom)
            continue
        b = CI.png_octets(CI.bande(p, (64, 32, 16, 8)))
        rel = "icones/" + nom + ".png"
        fichiers[rel] = b
        man["fichiers"][rel] = dict(genre="item", icon_size=64, icon_mipmaps=4, sha256=hashlib.sha256(b).hexdigest())
    if manque:
        raise SystemExit("[MX-ICONES] rendus manquants (samples %d) : %s" % (samples, ", ".join(manque)))
    return fichiers, man


def lua_table():
    L = ["-- GÉNÉRÉ par tools/render/pieces/metaux/icones.py : ne pas éditer à la main.",
         "-- Icônes des métaux (lot ICONES-DISTINCTES) : objets (64 px + 3 mipmaps).",
         "return {", "  item = {"]
    for n in sorted(ITEMS):
        L.append('    ["%s"] = { icon = "__factorio-overhaul__/graphics/metaux/icones/%s.png", icon_size = 64, icon_mipmaps = 4 },' % (n, n))
    L += ["  },", "}"]
    return "\n".join(L) + "\n"


def texte_manifeste(man):
    return json.dumps(man, ensure_ascii=False, indent=1, sort_keys=True) + "\n"


def _textes(man):
    return (("icones/MANIFEST.json", texte_manifeste(man)), ("icones/icones.lua", lua_table()))


def ecrire(fichiers, man):
    os.makedirs(os.path.join(SORTIE, "icones"), exist_ok=True)
    for rel, b in sorted(fichiers.items()):
        with open(os.path.join(SORTIE, rel.replace("/", os.sep)), "wb") as f:
            f.write(b)
    for rel, txt in _textes(man):
        with open(os.path.join(SORTIE, rel.replace("/", os.sep)), "w", encoding="utf-8", newline="\n") as f:
            f.write(txt)


def verifier(fichiers, man):
    ecarts = 0
    for rel, b in sorted(fichiers.items()):
        p = os.path.join(SORTIE, rel.replace("/", os.sep))
        if not os.path.exists(p) or open(p, "rb").read() != b:
            print("ÉCART", rel)
            ecarts += 1
    for rel, txt in _textes(man):
        p = os.path.join(SORTIE, rel.replace("/", os.sep))
        if not os.path.exists(p) or open(p, encoding="utf-8", newline="").read() != txt:
            print("ÉCART", rel)
            ecarts += 1
    print("[MX-ICONES] %d objet(s), %d écart(s)" % (len(ITEMS), ecarts))
    return ecarts


def verifier_manifeste():
    man = json.load(open(os.path.join(SORTIE, "icones", "MANIFEST.json"), encoding="utf-8"))
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
    attendus = {"icones/" + n + ".png" for n in ITEMS}
    for rel in sorted(attendus ^ vus):
        print("ABSENT OU EN TROP", rel)
        ecarts += 1
    print("[MX-ICONES] manifeste : %d fichier(s), %d écart(s)" % (len(vus), ecarts))
    return ecarts


def remplacee(nom):
    """Icône montrée à 0.6.91 : plaque d'acier vanilla (bande de mipmaps), teinte qui MULTIPLIE. Rend (64 px, 32 px)."""
    fichier, t = REMPLACE[nom]
    a = Image.open(os.path.join(DATA, fichier + ".png")).convert("RGBA")

    def teindre(im):
        r, g, b, al = im.split()
        return Image.merge("RGBA", (r.point(lambda v: int(v * t[0])), g.point(lambda v: int(v * t[1])), b.point(lambda v: int(v * t[2])), al))
    return teindre(a.crop((0, 0, 64, 64))), teindre(a.crop((64, 0, 96, 32)))


def _bande(nom, samples, cache, depot):
    if depot:
        p = os.path.join(SORTIE, "icones", nom + ".png")
        return Image.open(p).convert("RGBA") if os.path.exists(p) else None
    p = os.path.join(cache, str(samples), nom + ".png")
    return CI.bande(p, (64, 32, 16, 8)) if os.path.exists(p) else None


def planche(sortie, samples, cache, depot=False):
    """Ligne AVANT (copies teintées de la plaque d'acier) puis ligne APRÈS : 64 px × 3, 32 px en case d'inventaire, 32 px nu ;
    en bas, les cinq à 32 px en case côte à côte (lecture du joueur), avant puis après."""
    cw, n = 300, len(ITEMS)
    im = Image.new("RGBA", (n * cw + 24, 600), CI.FOND + (255,))
    d = ImageDraw.Draw(im)
    d.text((12, 8), "ICONES DISTINCTES (11/11) : en haut AVANT (0.6.91, plaque d'acier vanilla teintee), en dessous APRES (rendu 3D, %d ech.)"
           % samples, font=CI.police(15, True), fill=(235, 235, 235))
    for i, nom in enumerate(ITEMS):
        x = 12 + i * cw
        d.text((x, 34), NOMS_FR[nom], font=CI.police(14, True), fill=(255, 210, 120))
        v64, v32 = remplacee(nom)
        im.alpha_composite(v64.resize((192, 192), Image.NEAREST), (x, 58))
        im.alpha_composite(CI.fente(v32), (x + 200, 70))
        im.alpha_composite(v32, (x + 204, 130))
        b = _bande(nom, samples, cache, depot)
        if b is None:
            d.text((x + 20, 360), "(non rendu)", font=CI.police(12), fill=(255, 90, 90))
            continue
        i64, i32 = CI.mips(b, 64)
        im.alpha_composite(i64.resize((192, 192), Image.NEAREST), (x, 270))
        im.alpha_composite(CI.fente(i32), (x + 200, 282))
        im.alpha_composite(i32, (x + 204, 342))
    d.text((12, 486), "Inventaire (32 px) : avant  |  apres", font=CI.police(14, True), fill=(255, 210, 120))
    for i, nom in enumerate(ITEMS):
        im.alpha_composite(CI.fente(remplacee(nom)[1]), (12 + i * 46, 514))
        b = _bande(nom, samples, cache, depot)
        if b is not None:
            im.alpha_composite(CI.fente(CI.mips(b, 64)[1]), (12 + (n + 1) * 46 + i * 46, 514))
    im.convert("RGB").save(sortie)
    print("[MX-ICONES] planche : %s" % sortie)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rendre")
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--taille", type=int, default=512)
    ap.add_argument("--cache", default=CACHE)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--planche")
    ap.add_argument("--manifeste", action="store_true")
    ap.add_argument("--depot", action="store_true", help="planche : bandes du dépôt (graphics/metaux) au lieu des rendus gardés")
    a = ap.parse_args()
    if a.manifeste:
        return 1 if verifier_manifeste() else 0
    if a.rendre:
        rendre(ITEMS if a.rendre == "tout" else a.rendre.split(","), a.samples, a.cache, a.taille)
    if a.planche:
        planche(a.planche, a.samples, a.cache, a.depot)
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
