"""ICÔNES DES PUCES ET COMPOSANTS du calcul (lot CALC-ICONES-A, 30/10) : 8 objets + 2 fluides, rendu 2,5 D maîtrisé.

DC (30/10, vers 10 h 50) : « aussi designez toute la partie du scenario calcul, que ce soit les usines ou les items ».
Avant ce lot : copies teintées du vanilla (prototypes/compute.lua, table ICON) ; 5 objets portaient l'icône du processeur.

Pourquoi pas Blender : même raison que les modules (tools/render/pieces/modules/icones.py, validés par le DC) : une icône
se juge à 32 px ; le motif d'une puce (plots, bancs, pavage) doit y rester lisible, ce qu'on règle mieux en dessinant la
forme qu'en réduisant un rendu 3D. Dessins : dessins.py ; moteur : moteur2d.py (champs de distance, relief éclairé du nord-ouest, extrusion
pour la vue 3/4 du vanilla). Couleurs : palette.py (commune avec CALC-ICONES-B, qui la relit sans la modifier).

LECTURE PAR LA SILHOUETTE (puis la couleur) :
  - fo-logic-die          puce LOGIQUE : carrée, plots d'or sur les 4 bords, 4 cœurs ambre en 2 x 2 ;
  - fo-dram-die           puce DRAM : rectangle long (2 : 1), rangée de plots au MILIEU, 8 bancs vert d'eau striés ;
  - fo-sram-die           puce SRAM : DEUX puces empilées (cache empilé), pavage violet 4 x 4 sur celle du dessus ;
  - fo-etched-wafer       tranche gravée : DISQUE de silicium à méplat, damier de puces, irisé ;
  - fo-photomask          photomasque : plaque CARRÉE de quartz clair, absorbeur de tungstène en 3 x 3, cadre de pellicule ;
  - fo-crystal-laser      laser à cristal : tube en DIAGONALE (carénage de l'âge 10, bobines de cuivre), cristal et faisceau ;
  - fo-heat-sink          radiateur : AILETTES d'aluminium dressées sur une semelle de cuivre, 2 caloducs ;
  - fo-degassed-ilmenite  ilménite dégazée : TAS DE BOULETTES rondes frittées (le minerai, lui, est en morceaux) ;
  - fo-photoresist        résine photosensible : GOUTTE ambre au-dessus d'une tranche qu'elle nappe ;
  - fo-helium-3           hélium-3 : NOYAU de 3 nucléons (2 protons, 1 neutron) dans 2 orbites de plasma.

Sorties (dossier --out, par défaut graphics/calcul/icones du mod) :
  <objet>.png     64 px + 3 mipmaps (bande 120 x 64), icon_size 64, icon_mipmaps 4 ;
  MANIFEST.json   noms, tailles, sha256, version de l'outil ;
  icons-a.lua     même table pour l'étape data (chemins), relue par prototypes/compute.lua.
Usage :
  py -3.9 tools/render/pieces/calcul/icones_composants.py                  # écrit graphics/calcul/icones
  py -3.9 tools/render/pieces/calcul/icones_composants.py --check          # régénère en mémoire, compare (code 1 si écart)
  py -3.9 tools/render/pieces/calcul/icones_composants.py --sans-ecrire --apercu <dossier>   # PNG d'essai seulement
"""
import argparse
import hashlib
import json
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.abspath(os.path.join(ICI, "..", "..", "..", ".."))
sys.path.insert(0, ICI)
import moteur2d as M  # noqa: E402
from dessins import ICONES  # noqa: E402

VERSION = 1


NETTETE32 = 0.35


def generer(noms=None):
    fichiers, man = {}, dict(version=VERSION, outil="tools/render/pieces/calcul/icones_composants.py", icones={})
    for nom in (noms or sorted(ICONES)):
        fn, age, typ = ICONES[nom]
        b = M.png_octets(M.bande_icone(fn(), NETTETE32))
        fichiers["%s.png" % nom] = b
        man["icones"][nom] = dict(fichier="%s.png" % nom, age=age, type=typ, icon_size=64, icon_mipmaps=4,
                                  largeur=120, hauteur=64, sha256=hashlib.sha256(b).hexdigest())
    return fichiers, man


def lua_table(man):
    L = ["-- GÉNÉRÉ par tools/render/pieces/calcul/icones_composants.py (lot CALC-ICONES-A) : ne pas éditer à la main.",
         "-- Icônes des puces et composants du calcul (64 px + 3 mipmaps), relues par prototypes/compute.lua.",
         "return {", "  version = %d," % man["version"], "  icones = {"]
    for n in sorted(man["icones"]):
        d = man["icones"][n]
        L.append('    ["%s"] = { fichier = "%s", icon_size = 64, icon_mipmaps = 4, age = %d, type = "%s" },'
                 % (n, d["fichier"], d["age"], d["type"]))
    L += ["  },", "}"]
    return "\n".join(L) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=os.path.join(MOD, "graphics", "calcul", "icones"))
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--sans-ecrire", action="store_true")
    ap.add_argument("--apercu", help="dossier où poser les bandes PNG (essais)")
    ap.add_argument("--seulement", help="noms séparés par des virgules")
    a = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    noms = a.seulement.split(",") if a.seulement else None
    fichiers, man = generer(noms)
    if a.check:
        ref = json.load(open(os.path.join(a.out, "MANIFEST.json"), encoding="utf-8"))
        pb = []
        for n, d in sorted(man["icones"].items()):
            r = ref["icones"].get(n)
            if not r or r["sha256"] != d["sha256"]:
                pb.append(n)
            elif hashlib.sha256(open(os.path.join(a.out, d["fichier"]), "rb").read()).hexdigest() != d["sha256"]:
                pb.append(n + " (fichier)")
        if sorted(ref["icones"]) != sorted(man["icones"]):
            pb.append("liste des icônes")
        if open(os.path.join(a.out, "icons-a.lua"), encoding="utf-8").read() != lua_table(man):
            pb.append("icons-a.lua")
        print("[FO-CALC-ICONES-A] contrôle : %d icône(s), %d écart(s)%s"
              % (len(man["icones"]), len(pb), (" : " + ", ".join(pb)) if pb else ""))
        return 1 if pb else 0
    if a.apercu:
        os.makedirs(a.apercu, exist_ok=True)
        for rel, b in fichiers.items():
            open(os.path.join(a.apercu, rel), "wb").write(b)
        print("[FO-CALC-ICONES-A] aperçu : %d bande(s) dans %s" % (len(fichiers), a.apercu))
    if not a.sans_ecrire:
        os.makedirs(a.out, exist_ok=True)
        tot = 0
        for rel, b in sorted(fichiers.items()):
            open(os.path.join(a.out, rel), "wb").write(b)
            tot += len(b)
        with open(os.path.join(a.out, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as fh:
            json.dump(man, fh, ensure_ascii=False, indent=1, sort_keys=True)
            fh.write("\n")
        with open(os.path.join(a.out, "icons-a.lua"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(lua_table(man))
        print("[FO-CALC-ICONES-A] %d icône(s), %.1f ko, dans %s" % (len(fichiers), tot / 1e3, a.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
