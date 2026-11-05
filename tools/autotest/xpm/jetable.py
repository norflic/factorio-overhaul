"""Lot DESIGN-MODULES (5/11) : COPIE JETABLE du mod où les MODULES DES GÉANTS sont branchés, pour les bancs xpm-grille et xpm-images.

    py -3.9 tools/autotest/xpm/jetable.py --dest <dossier neuf, hors du dépôt> [--base <checkout du mod avec ses PNG hors de git>]
                                          [--src <ce worktree>]

Le lot ne touche ni data.lua, ni control.lua (fichiers de l'intégrateur), ni script/robots/experimentaux_geants.lua (lot EXPERIMENTAUX).
Cette copie les modifie, elle seule :
1. recopie --base (par défaut le checkout principal du mod : il porte les PNG hors de git, D-6), sans .git, .claude, tools/render ni
   __pycache__ (exFAT : copie, jamais de lien dur) ;
2. y recopie TOUS les fichiers suivis par git de --src (le worktree design-modules) : le code est exactement celui de la branche, seuls
   les PNG hors de git viennent de la base ;
3. ajoute `require("prototypes.experimentaux_modules")` après `require("prototypes.experimentaux")` dans data.lua, et
   `require("script.robots.experimentaux_modules")` après `require("script.robots.experimentaux")` dans control.lua ;
4. dans script/robots/experimentaux_geants.lua, s'ils manquent : le crochet de salve G.ecoute (demandé au lot EXPERIMENTAUX, pour la marque
   visible des modules) et le retour des modules d'un géant refusé au plafond ;
5. ajoute une cible d'essai, fo-xpm-cible (10 000 000 PV, sans résistance, cible militaire) : une salve ne la tue pas, ses PV perdus la
   mesurent exactement (xpm_jetable_data.lua, appelé en fin de data.lua).
Bancs : py -3.9 -B tools/autotest/banc.py --out <archive> --qui DESIGN-MODULES -- 2500 xpm-grille "<dest>"
"""
import argparse
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
RACINE = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91")
BASE = os.path.join(RACINE, "mods", "factorio-overhaul")
EXCLUS = {".git", ".claude", "__pycache__"}
CIBLE = '''-- COPIE JETABLE DESIGN-MODULES : cible d'essai des bancs xpm-*. Ne jamais livrer.
local c = table.deepcopy(data.raw["simple-entity-with-force"]["simple-entity-with-force"])
c.name = "fo-xpm-cible"
c.localised_name = { "entity-name.simple-entity-with-force" }
c.max_health = 10000000
c.resistances = nil
c.is_military_target = true
c.minable = nil
data:extend({ c })
'''


def lire(p):
    return open(p, encoding="utf-8", newline="").read()


def ecrire(p, s):
    open(p, "w", encoding="utf-8", newline="").write(s)


def inserer_apres(s, ancre, ligne, chemin):
    if ligne in s:
        return s
    i = s.find(ancre)
    if i < 0:
        raise SystemExit("ancre absente dans %s : %s" % (chemin, ancre))
    j = s.find("\n", i)
    return s[:j + 1] + ligne + "\n" + s[j + 1:]


def inserer_avant(s, ancre, texte, chemin):
    i = s.find(ancre)
    if i < 0:
        raise SystemExit("ancre absente dans %s : %s" % (chemin, ancre))
    return s[:i] + texte + s[i:]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--dest", required=True)
    ap.add_argument("--base", default=BASE)
    ap.add_argument("--src", default=SRC)
    a = ap.parse_args()
    dest, base, src = os.path.abspath(a.dest), os.path.abspath(a.base), os.path.abspath(a.src)
    if os.path.exists(dest):
        raise SystemExit("--dest existe déjà (copie jetable : dossier NEUF) : %s" % dest)

    def ignorer(d, noms):
        rel = os.path.relpath(d, base).replace(os.sep, "/")
        out = [n for n in noms if n in EXCLUS]
        if rel == "tools" and "render" in noms:
            out.append("render")
        return out
    shutil.copytree(base, dest, ignore=ignorer)
    suivis = subprocess.run(["git", "-C", src, "ls-files", "-z"], capture_output=True, check=True).stdout.decode("utf-8").split("\0")
    n = 0
    for rel in suivis:
        if not rel or rel.startswith("tools/render/"):
            continue
        p = os.path.join(dest, *rel.split("/"))
        os.makedirs(os.path.dirname(p), exist_ok=True)
        shutil.copyfile(os.path.join(src, *rel.split("/")), p)
        n += 1
    dl = os.path.join(dest, "data.lua")
    ecrire(dl, inserer_apres(lire(dl), 'require("prototypes.experimentaux")',
                             'require("prototypes.experimentaux_modules") -- COPIE JETABLE DESIGN-MODULES', dl))
    cl = os.path.join(dest, "control.lua")
    ecrire(cl, inserer_apres(lire(cl), 'require("script.robots.experimentaux")',
                             'require("script.robots.experimentaux_modules") -- COPIE JETABLE DESIGN-MODULES', cl))
    ecrire(os.path.join(dest, "xpm_jetable_data.lua"), CIBLE)
    ecrire(dl, lire(dl).rstrip(chr(10)) + chr(10) + 'require("xpm_jetable_data") -- COPIE JETABLE DESIGN-MODULES : cible d\'essai' + chr(10))
    gp = os.path.join(dest, "script", "robots", "experimentaux_geants.lua")
    g = lire(gp)
    poses = []
    if "function G.ecoute(" not in g:
        g = inserer_avant(g, "local function zone(g, r, c, tick)",
                          "-- COPIE JETABLE DESIGN-MODULES : crochet de salve (marque visible des modules)\nlocal ecouteurs = {}\n"
                          "function G.ecoute(f) ecouteurs[#ecouteurs + 1] = f end\n\n", gp)
        i = g.find("local function zone(g, r, c, tick)")
        j = g.find("  local eff = Ech.effectif(r, g.bonus)\n", i)
        if j < 0:
            raise SystemExit("ancre de la salve absente dans %s" % gp)
        k = g.find("\n", j) + 1
        g = g[:k] + "  for _, f in ipairs(ecouteurs) do f(e, r, g.bonus, c, eff) end -- COPIE JETABLE DESIGN-MODULES\n" + g[k:]
        poses.append("crochet G.ecoute")
    if "eq in ipairs(e.grid.equipment) do rendre(" not in g:
        g = inserer_avant(g, "    rendre(player, e, name)\n",
                          "    if e.grid then for _, eq in ipairs(e.grid.equipment) do rendre(player, e, eq.name) end end -- COPIE JETABLE DESIGN-MODULES\n", gp)
        poses.append("modules rendus au refus")
    ecrire(gp, g)
    print("[XPM-JETABLE] copie prête : %s (base %s, %d fichiers suivis de %s ; posés dans experimentaux_geants : %s)"
          % (dest, base, n, src, ", ".join(poses) or "rien"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
