"""ICÔNES DE LA ROBOTIQUE (lot DA-ICONES) : le seul script qui génère graphics/robotique/{icones,tech}/, icones.lua et MANIFEST.json.

45 icônes : 7 pièces de robots, 2 circuits, 3 siliciums, 3 bobinages, 12 kits, 3 segments de géants (objets : 64 px + 3
mipmaps), 15 technologies (256 px + 3 mipmaps). Rendus 3D (Blender : rq_scene.py) sur le socle des icônes du calcul ; la
réduction (lumière linéaire, liseré, netteté) est CELLE du calcul (tools/render/pieces/calcul/icones.py), importée.

Depuis la racine du worktree (Blender SEULEMENT par le verrou de rendu) :
  python tools/render/with_render_lock.py -- py -3.9 tools/render/pieces/robotique/icones.py --rendre tout --samples 64
  py -3.9 tools/render/pieces/robotique/icones.py [--samples 64]     # bandes, icones.lua et MANIFEST depuis les rendus gardés
  py -3.9 tools/render/pieces/robotique/icones.py --check            # refait les bandes en mémoire, compare, code 1 si écart
  py -3.9 tools/render/pieces/robotique/icones.py --manifeste        # sha256 des PNG du dépôt contre MANIFEST.json, code 1 si écart
  py -3.9 tools/render/pieces/robotique/icones.py --planche <png> [--samples N]   # planche, icône vanilla teintée remplacée à côté
Rendus gardés : <racine>/fo-logs/2026-11-04_DA-ICONES/rendus/<samples>/ (ou --cache, à GARDER).
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
CACHE = os.path.join(RACINE, "fo-logs", "2026-11-04_DA-ICONES", "rendus")
BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
SCENE = os.path.join(ICI, "rq_scene.py")
SORTIE = os.path.join(MOD, "graphics", "robotique")
VERSION = 1

_spec = importlib.util.spec_from_file_location("calcul_icones", os.path.join(ICI, "..", "calcul", "icones.py"))
CI = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(CI)

ROBOTS = ["steam-trotter", "scalehide", "coiler", "needle", "bellwether", "chamfer", "trowel", "finback", "levite", "toroid", "heliast",
          "crowned"]
GEANTS = ["toroid", "heliast", "crowned"]
PIECES = ["fo-servo-motor", "fo-optical-sensor", "fo-controller", "fo-guidance-core", "fo-magnetic-actuator", "fo-ndyag-rod",
          "fo-laser-module"]
CIRCUITS = ["fo-printed-circuit-board", "fo-crystal-oscillator"]
MATIERES = ["fo-metallurgical-silicon", "fo-pure-silicon", "fo-silicon-wafer", "fo-enameled-wire", "fo-coil", "fo-superconducting-tape"]
KITS = ["fo-robot-kit-" + r for r in ROBOTS]
SEGMENTS = ["fo-robot-segment-" + r for r in GEANTS]
ITEMS = PIECES + CIRCUITS + MATIERES + KITS + SEGMENTS
TECHNOS = ["fo-servo-mechanisms", "fo-robot-guidance", "fo-magnetic-drive", "fo-robot-automata", "fo-robot-heavy", "fo-robot-coil",
           "fo-robot-bay", "fo-robot-bellwether", "fo-robot-mortar", "fo-robot-dock", "fo-robot-finback", "fo-robot-levite",
           "fo-robot-gantry", "fo-robot-gantry-heliast", "fo-robot-gantry-crowned"]

# Icône remplacée (ce que le jeu montre aujourd'hui) : (fichier vanilla, teinte), lue dans prototypes/{robot_parts,tin,crafts,
# superconductors,robots}.lua à 0.6.46.
ROBOT_TINT = {
    "steam-trotter": (0.80, 0.62, 0.40), "scalehide": (0.62, 0.36, 0.28), "coiler": (0.45, 0.70, 0.95), "needle": (0.70, 0.50, 0.95),
    "bellwether": (0.55, 0.95, 0.80), "chamfer": (0.75, 0.75, 0.45), "trowel": (0.95, 0.85, 0.35), "finback": (0.90, 0.95, 1.00),
    "levite": (0.55, 0.85, 0.95), "toroid": (0.95, 0.55, 0.85), "heliast": (1.00, 0.80, 0.35), "crowned": (1.00, 0.95, 0.80),
}
REMPLACE = {
    "fo-servo-motor": ("icons/electric-engine-unit", (0.85, 0.95, 1.00)),
    "fo-optical-sensor": ("icons/radar", (0.70, 0.90, 1.00)),
    "fo-controller": ("icons/advanced-circuit", (0.80, 1.00, 0.85)),
    "fo-guidance-core": ("icons/processing-unit", (1.00, 0.90, 0.60)),
    "fo-magnetic-actuator": ("icons/electric-engine-unit", (1.00, 0.70, 0.70)),
    "fo-ndyag-rod": ("icons/pipe", (0.95, 0.75, 1.00)),
    "fo-laser-module": ("icons/laser-turret", (1.00, 0.55, 0.55)),
    "fo-printed-circuit-board": ("icons/electronic-circuit", (0.55, 1.00, 0.55)),
    "fo-crystal-oscillator": ("icons/advanced-circuit", (0.70, 0.86, 1.00)),
    "fo-metallurgical-silicon": ("icons/stone", (0.55, 0.58, 0.66)),
    "fo-pure-silicon": ("icons/iron-plate", (0.62, 0.66, 0.80)),
    "fo-silicon-wafer": ("icons/copper-plate", (0.55, 0.62, 0.95)),
    "fo-enameled-wire": ("icons/copper-cable", (0.85, 0.38, 0.26)),
    "fo-coil": ("icons/iron-gear-wheel", (1.00, 0.66, 0.36)),
    "fo-superconducting-tape": ("icons/copper-cable", (0.45, 0.45, 0.52)),
    "fo-servo-mechanisms": ("icons/electric-engine-unit", (0.85, 0.95, 1.00)),
    "fo-robot-guidance": ("icons/processing-unit", (1.00, 0.90, 0.60)),
    "fo-magnetic-drive": ("icons/electric-engine-unit", (1.00, 0.70, 0.70)),
}
for _r in ROBOTS:
    REMPLACE["fo-robot-kit-" + _r] = ("icons/spidertron" if _r in GEANTS else "icons/engine-unit", ROBOT_TINT[_r])
for _r in GEANTS:
    REMPLACE["fo-robot-segment-" + _r] = ("icons/low-density-structure", ROBOT_TINT[_r])
for _t in TECHNOS[3:]:
    REMPLACE[_t] = ("technology/engine", (0.75, 0.80, 0.90))


# ------------------------------------------------------------------------------------------------------------------
# Rendu
# ------------------------------------------------------------------------------------------------------------------
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
        raise SystemExit("[RQ-ICONES] échec du rendu Blender (code %d)" % p.returncode)


# ------------------------------------------------------------------------------------------------------------------
# Génération (bandes de mipmaps : réduction du calcul)
# ------------------------------------------------------------------------------------------------------------------
def generer(samples, cache):
    src = os.path.join(cache, str(samples))
    fichiers, man = {}, dict(version=VERSION, outil="tools/render/pieces/robotique/icones.py", samples=samples, fichiers={})
    manque = []
    for genre, liste, tailles, dossier, cle in (("item", ITEMS, (64, 32, 16, 8), "icones", ""), ("tech", TECHNOS, (256, 128, 64, 32), "tech", "tech-")):
        for nom in liste:
            p = os.path.join(src, cle + nom + ".png")
            if not os.path.exists(p):
                manque.append(cle + nom)
                continue
            b = CI.png_octets(CI.bande(p, tailles))
            rel = dossier + "/" + nom + ".png"
            fichiers[rel] = b
            man["fichiers"][rel] = dict(genre=genre, icon_size=tailles[0], icon_mipmaps=4, sha256=hashlib.sha256(b).hexdigest())
    if manque:
        raise SystemExit("[RQ-ICONES] rendus manquants (samples %d) : %s" % (samples, ", ".join(manque)))
    return fichiers, man


def lua_table():
    L = ["-- GÉNÉRÉ par tools/render/pieces/robotique/icones.py : ne pas éditer à la main.",
         "-- Icônes de la robotique (lot DA-ICONES) : objets (64 px + 3 mipmaps), technologies (256 px + 3).",
         "return {", "  item = {"]
    for n in sorted(ITEMS):
        L.append('    ["%s"] = { icon = "__factorio-overhaul__/graphics/robotique/icones/%s.png", icon_size = 64, icon_mipmaps = 4 },' % (n, n))
    L += ["  },", "  tech = {"]
    for n in sorted(TECHNOS):
        L.append('    ["%s"] = { icon = "__factorio-overhaul__/graphics/robotique/tech/%s.png", icon_size = 256, icon_mipmaps = 4 },' % (n, n))
    L += ["  },", "}"]
    return "\n".join(L) + "\n"


def texte_manifeste(man):
    return json.dumps(man, ensure_ascii=False, indent=1, sort_keys=True) + "\n"


def _textes(man):
    return (("icones/MANIFEST.json", texte_manifeste(man)), ("icones/icones.lua", lua_table()))


def ecrire(fichiers, man):
    for d in ("icones", "tech"):
        os.makedirs(os.path.join(SORTIE, d), exist_ok=True)
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
    print("[RQ-ICONES] %d objet(s), %d technologie(s), %d écart(s)" % (len(ITEMS), len(TECHNOS), ecarts))
    return ecarts


def verifier_manifeste():
    """Sans les rendus gardés : chaque PNG du dépôt porte la somme du manifeste, et le manifeste n'oublie ni n'invente aucun fichier."""
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
    print("[RQ-ICONES] manifeste : %d fichier(s), %d écart(s)" % (len(vus), ecarts))
    return ecarts


# ------------------------------------------------------------------------------------------------------------------
# Planche : chaque icône (64 px × 2, 32 px en case, 32 px nu) et, à côté, l'icône vanilla teintée qu'elle remplace
# ------------------------------------------------------------------------------------------------------------------
def remplacee(nom, taille0):
    """Icône actuelle en jeu : fichier vanilla (bande de mipmaps), teinte qui MULTIPLIE (F36). Rend (grande, 32 px)."""
    fichier, t = REMPLACE[nom]
    a = Image.open(os.path.join(DATA, fichier + ".png")).convert("RGBA")
    g = a.crop((0, 0, taille0, taille0))
    off, t32 = 0, taille0
    while t32 > 32:          # bande vanilla : 64, 32, 16, 8 (ou 256, 128, 64, 32) côte à côte
        off += t32
        t32 //= 2
    p = a.crop((off, 0, off + 32, 32))
    def teindre(im):
        r, gg, b, al = im.split()
        return Image.merge("RGBA", (r.point(lambda v: int(v * t[0])), gg.point(lambda v: int(v * t[1])), b.point(lambda v: int(v * t[2])), al))
    return teindre(g), teindre(p)


GROUPES = [("Pieces de robots", PIECES), ("Circuits", CIRCUITS), ("Silicium et bobinages", MATIERES), ("Kits (famille : ambre Atelier, violet Hall, bleu Dock, magenta Portique)", KITS),
           ("Segments des geants", SEGMENTS)]


def planche(sortie, samples, cache, noms=None, titre=None):
    """noms : ne montrer que ces icônes (objets et technologies, par nom) ; titre : bandeau."""
    src = os.path.join(cache, str(samples))
    garde = (lambda n: True) if not noms else (lambda n: n in noms)
    groupes = [(t, [n for n in g if garde(n)]) for t, g in GROUPES]
    groupes = [(t, g) for t, g in groupes if g]
    technos = [t for t in TECHNOS if garde(t)]
    ligne, cw, ch = 6, 318, 168
    rangs = sum((len(g) + ligne - 1) // ligne for _, g in groupes)
    tl, tw, th = 4, 474, 300
    hauteur = 40 + rangs * ch + len(groupes) * 24 + 30 + ((len(technos) + tl - 1) // tl) * th + 20
    im = Image.new("RGBA", (max(ligne * cw, tl * tw) + 24, hauteur), CI.FOND + (255,))
    d = ImageDraw.Draw(im)
    d.text((12, 8), (titre or "DA-ICONES : etats cles") + ", %d echantillons | a gauche : NOUVELLE (64 px x 2, 32 px en case, 32 px nu) | a droite, "
           "sur fond rouge sombre : l'icone ACTUELLE en jeu (vanilla teintee, 64 px et 32 px en case)" % samples, font=CI.police(14, True),
           fill=(235, 235, 235))
    y = 36
    for nom_g, liste in groupes:
        d.text((12, y), nom_g, font=CI.police(14, True), fill=(255, 210, 120))
        y += 22
        for i, n in enumerate(liste):
            x, yy = 12 + (i % ligne) * cw, y + (i // ligne) * ch
            d.text((x, yy), n[3:], font=CI.police(11), fill=(205, 205, 205))
            p = os.path.join(src, n + ".png")
            if os.path.exists(p):
                b = CI.bande(p, (64, 32, 16, 8))
                i64, i32 = CI.mips(b, 64)
                im.alpha_composite(i64.resize((128, 128), Image.NEAREST), (x, yy + 16))
                im.alpha_composite(CI.fente(i32), (x + 130, yy + 16))
                im.alpha_composite(i32, (x + 134, yy + 62))
            else:
                d.text((x + 20, yy + 70), "(non rendu)", font=CI.police(12), fill=(255, 90, 90))
            v64, v32 = remplacee(n, 64)
            d.rectangle((x + 176, yy + 16, x + 176 + 68 + 44, yy + 16 + 104), fill=(60, 34, 34))
            im.alpha_composite(v64, (x + 178, yy + 20))
            im.alpha_composite(CI.fente(v32), (x + 246, yy + 32))
        y += ((len(liste) + ligne - 1) // ligne) * ch + 2
    d.text((12, y), "Technologies : 256 px, mipmaps 64 et 32 en case | a droite, l'icone actuelle (vanilla teintee, 128 px)", font=CI.police(14, True),
           fill=(255, 210, 120))
    y += 24
    for i, t in enumerate(technos):
        x0, y0 = 12 + (i % tl) * tw, y + (i // tl) * th
        d.text((x0, y0), t, font=CI.police(11), fill=(205, 205, 205))
        p = os.path.join(src, "tech-" + t + ".png")
        if os.path.exists(p):
            b = CI.bande(p, (256, 128, 64, 32))
            im.alpha_composite(b.crop((0, 0, 256, 256)), (x0, y0 + 16))
            im.alpha_composite(b.crop((384, 0, 448, 64)), (x0 + 258, y0 + 20))
            im.alpha_composite(CI.fente(b.crop((448, 0, 480, 32))), (x0 + 270, y0 + 90))
        else:
            d.text((x0 + 60, y0 + 120), "(non rendu)", font=CI.police(12), fill=(255, 90, 90))
        fichier = REMPLACE[t][0]
        big = 256 if fichier.startswith("technology") else 64
        v, v32 = remplacee(t, big)
        v = v.resize((128, 128), Image.LANCZOS if big == 256 else Image.NEAREST)
        d.rectangle((x0 + 330, y0 + 140, x0 + 330 + 134, y0 + 140 + 134), fill=(60, 34, 34))
        im.alpha_composite(v, (x0 + 333, y0 + 143))
    im.convert("RGB").save(sortie)
    print("[RQ-ICONES] planche : %s" % sortie)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rendre")
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--taille", type=int, default=512)
    ap.add_argument("--cache", default=CACHE)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--planche")
    ap.add_argument("--manifeste", action="store_true")
    ap.add_argument("--noms", help="planche : liste de noms séparés par des virgules")
    ap.add_argument("--titre")
    a = ap.parse_args()
    if a.manifeste:
        return 1 if verifier_manifeste() else 0
    if a.rendre:
        noms = (ITEMS + ["tech-" + t for t in TECHNOS]) if a.rendre == "tout" else a.rendre.split(",")
        rendre(noms, a.samples, a.cache, a.taille)
    if a.planche:
        planche(a.planche, a.samples, a.cache, set(a.noms.split(",")) if a.noms else None, a.titre)
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
