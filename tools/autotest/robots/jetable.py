"""Lot RB-0 (31/10) : COPIE JETABLE du mod pour les essais moteur E1 à E9 des robots (scénarios greffés rb0-*).

    py -3.9 tools/autotest/robots/jetable.py --dest <dossier neuf, hors du dépôt> [--src <racine du mod>]
                                             [--remplissage <Mpx>] [--cote 2048]
    py -3.9 tools/autotest/robots/jetable.py --dest <copie existante> --maj   (rafraîchit scénarios et prototypes)

1. Recopie la source du mod (par défaut : la racine de ce dépôt ou de ce worktree) dans --dest, sans .git, .claude,
   tools/render ni __pycache__ (mêmes exclusions que fo-autotest.bat et a1/jetable.py).
2. Y ajoute rb0_jetable_data.lua (prototypes de test, voir son en-tête) et l'appelle en fin de data-final-fixes.lua.
3. Avec --remplissage <Mpx> (E8 seulement) : écrit graphics/rb0/fill-<k>.png (feuilles opaques de --cote x --cote
   pixels, toutes différentes, dégradés qui se compressent bien en PNG mais pas en texture) et rb0_fill.lua ;
   nombre de feuilles = ceil(Mpx / (cote^2 / 1e6)).
Le banc se lance ensuite sur cette copie : banc.py ... -- <ticks> rb0-<essai> "<dest>". Le mod livré n'est jamais modifié.
"""
import argparse
import math
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
EXCLUS = {".git", ".claude", "__pycache__"}


def feuille(k, cote):
    """Feuille opaque k : dégradés croisés et anneaux de fréquences propres à k (aucune n'est identique à une autre)."""
    import numpy as np
    from PIL import Image
    y, x = np.mgrid[0:cote, 0:cote].astype("float32") / cote
    r = 0.5 + 0.5 * np.sin(2 * math.pi * ((3 + k) * x + (2 + k % 5) * y))
    g = 0.5 + 0.5 * np.sin(2 * math.pi * ((5 + k % 7) * x - (1 + k) * y + 0.1 * k))
    b = 0.5 + 0.5 * np.sin(2 * math.pi * (7 + k) * np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2))
    img = np.stack([r, g, b, np.ones_like(r)], axis=-1)
    return Image.fromarray((img * 255).astype("uint8"), "RGBA")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--src", default=MOD)
    ap.add_argument("--remplissage", type=float, default=0.0, help="Mpx de feuilles de remplissage (E8)")
    ap.add_argument("--cote", type=int, default=2048)
    ap.add_argument("--maj", action="store_true",
                    help="copie EXISTANTE : rafraichit seulement le mod de test (scenarios) et rb0_jetable_data.lua")
    a = ap.parse_args()
    src, dest = os.path.abspath(a.src), os.path.abspath(a.dest)
    if a.maj:
        if not os.path.exists(os.path.join(dest, "info.json")):
            raise SystemExit("--maj : %s n'est pas une copie jetable" % dest)
        shutil.copytree(os.path.join(src, "tools", "autotest", "fo-autotest"),
                        os.path.join(dest, "tools", "autotest", "fo-autotest"), dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copy2(os.path.join(HERE, "rb0_jetable_data.lua"), os.path.join(dest, "rb0_jetable_data.lua"))
        print("copie jetable mise a jour : %s" % dest)
        return 0
    if os.path.exists(dest):
        raise SystemExit("--dest existe déjà (copie jetable : dossier NEUF) : %s" % dest)
    if not os.path.exists(os.path.join(src, "info.json")):
        raise SystemExit("source sans info.json : %s" % src)
    render = os.path.join(src, "tools", "render")

    def ignorer(d, noms):
        return [n for n in noms if n in EXCLUS or os.path.join(d, n) == render]

    shutil.copytree(src, dest, ignore=ignorer)
    shutil.copy2(os.path.join(HERE, "rb0_jetable_data.lua"), os.path.join(dest, "rb0_jetable_data.lua"))
    dff = os.path.join(dest, "data-final-fixes.lua")
    with open(dff, "ab") as f:
        f.write(b"\n-- COPIE JETABLE du lot RB-0 (tools/autotest/robots/jetable.py) : prototypes de test E1 a E9\n"
                b"require(\"rb0_jetable_data\")\n")
    if a.remplissage > 0:
        n = int(math.ceil(a.remplissage / (a.cote * a.cote / 1e6)))
        g = os.path.join(dest, "graphics", "rb0")
        os.makedirs(g, exist_ok=True)
        lignes = []
        for k in range(1, n + 1):
            feuille(k, a.cote).save(os.path.join(g, "fill-%d.png" % k), optimize=False)
            lignes.append('  { fichier = "graphics/rb0/fill-%d.png", cote = %d },' % (k, a.cote))
        with open(os.path.join(dest, "rb0_fill.lua"), "w", encoding="utf8") as f:
            f.write("return {\n  echelle = 0.5,\n  feuilles = {\n%s\n  },\n}\n" % "\n".join(lignes))
        print("remplissage : %d feuille(s) de %dx%d (%.1f Mpx)" % (n, a.cote, a.cote, n * a.cote * a.cote / 1e6))
    print("copie jetable prête : %s (source %s)" % (dest, src))


if __name__ == "__main__":
    sys.exit(main())
