r"""Mutants de la règle « sons » du harness, sur une COPIE JETABLE du mod (lot S0-suite) :

    py -3.9 -B tests/datastage/mut_sons.py --work <dossier jetable, hors du dépôt> [--data <racine>\data]
                                           [--avant <commit>]

Le fichier sound/levels/gun/tir-ere3-2.ogg (ère III : niveaux 13 à 18, soit 6 prototypes) de la copie est remplacé tour
à tour par :
  - temoin      : lui-même (aucune mutation)           -> harness code 0 ;
  - opus        : un vrai Ogg Opus (fixtures)          -> code 1, « Sons : 6 violation(s) », genre « codec » ;
  - flac        : un vrai FLAC dans Ogg (fixtures)     -> code 1, 6, « codec » ;
  - coupe-60    : ses 60 premiers % d'octets           -> code 1, 6, « tronqué » ;
  - coupe-page  : sans sa dernière page                -> code 1, 6, « tronqué » ;
  - vorbiz      : identification « vorbiz »            -> code 1, 6, « codec ».
Avec --avant <commit> (par défaut 5becadd, main avant ce lot), les mêmes mutants sont rejoués avec harness.lua et
sounds.lua de ce commit : ce que l'ancienne règle (« OggS » seul) laissait passer est imprimé (observé le 24/10 :
les 5 mutants y passent, code 0, « Sons : 0 violation(s) » : tous commencent par OggS).
Code 0 si chaque mutant est refusé comme attendu par la règle actuelle et le témoin accepté.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
GAME = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
CIBLE = os.path.join("sound", "levels", "gun", "tir-ere3-2.ogg")


def pages(data):
    out, p = [], 0
    while p + 27 <= len(data) and data[p:p + 4] == b"OggS":
        out.append(p)
        nseg = data[p + 26]
        p += 27 + nseg + sum(data[p + 27:p + 27 + nseg])
    return out


def mutants(orig):
    pg = pages(orig)
    ident = pg[0] + 27 + orig[pg[0] + 26]
    fx = os.path.join(HERE, "fixtures")
    return [
        ("temoin", orig, 0, None),
        ("opus", open(os.path.join(fx, "s0-opus.ogg"), "rb").read(), 1, "codec"),
        ("flac", open(os.path.join(fx, "s0-flac.ogg"), "rb").read(), 1, "codec"),
        ("coupe-60", orig[:int(len(orig) * 0.6)], 1, "tronqué"),
        ("coupe-page", orig[:pg[-1]], 1, "tronqué"),
        ("vorbiz", orig[:ident + 1] + b"vorbiz" + orig[ident + 7:], 1, "codec"),
    ]


def harness(lua, harness_dir, data, mod):
    # harness.lua trouve son dossier par le dernier « / » de arg[0] : chemins en barres obliques
    fwd = lambda p: p.replace(os.sep, "/")
    r = subprocess.run([lua, fwd(os.path.join(harness_dir, "harness.lua")), fwd(data), fwd(mod)], capture_output=True,
                       text=True,
                       encoding="utf-8", errors="replace", cwd=REPO)
    out = r.stdout + r.stderr
    m = re.search(r"^Sons : (\d+) violation", out, re.M)
    kinds = sorted(set(re.findall(r"^  SON (manquant|format|pas un son|codec|Vorbis invalide|tronqué) ", out, re.M)))
    return r.returncode, (int(m.group(1)) if m else None), kinds, out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--work", required=True)
    ap.add_argument("--data", default=os.path.join(GAME, "data"))
    # « lua5.2 » seul n'est pas trouvé par CreateProcess (l'extension « .2 » empêche l'ajout de « .exe ») : chemin complet
    ap.add_argument("--lua", default=shutil.which("lua5.2.exe") or r"C:\Users\evan2\bin\lua5.2.exe")
    ap.add_argument("--avant", default="5becadd")
    a = ap.parse_args()
    work = os.path.abspath(a.work)
    if os.path.normcase(work).startswith(os.path.normcase(REPO)):
        sys.exit("--work doit être hors du dépôt")
    mod = os.path.join(work, "mod")
    if os.path.exists(mod):
        shutil.rmtree(mod)
    shutil.copytree(REPO, mod, ignore=shutil.ignore_patterns(".git", ".claude", "__pycache__", "tools", "tests"))
    old = None
    if a.avant:
        old = os.path.join(work, "datastage-avant")
        if os.path.exists(old):
            shutil.rmtree(old)
        shutil.copytree(HERE, old, ignore=shutil.ignore_patterns("__pycache__", "fixtures"))
        for f in ("harness.lua", "sounds.lua"):
            blob = subprocess.run(["git", "show", "%s:tests/datastage/%s" % (a.avant, f)], capture_output=True,
                                  cwd=REPO).stdout
            if not blob:
                sys.exit("git show %s:tests/datastage/%s vide" % (a.avant, f))
            with open(os.path.join(old, f), "wb") as fh:
                fh.write(blob)
    path = os.path.join(mod, CIBLE)
    orig = open(path, "rb").read()
    ok = fail = 0
    try:
        for name, data, want_code, want_kind in mutants(orig):
            with open(path, "wb") as fh:
                fh.write(data)
            code, n, kinds, out = harness(a.lua, HERE, a.data, mod)
            good = code == want_code and (n == 0 if want_code == 0 else (n == 6 and kinds == [want_kind]))
            ok, fail = ok + good, fail + (not good)
            line = "[FO-MUT-SONS] %s %-11s (%d octets) : code %d, Sons %s violation(s), genres %s" % (
                "OK    " if good else "ECHEC ", name, len(data), code, n, ",".join(kinds) or "-")
            if old:
                ocode, on, okinds, _ = harness(a.lua, old, a.data, mod)
                line += " | regle d'avant (%s) : code %d, Sons %s" % (a.avant, ocode, on)
            print(line, flush=True)
            if not good:
                for ln in out.splitlines():
                    if ln.startswith("  SON") or ln.startswith("Sons"):
                        print("    " + ln)
    finally:
        with open(path, "wb") as fh:
            fh.write(orig)
    print("[FO-MUT-SONS] BILAN : %d OK, %d ECHEC(S)" % (ok, fail))
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
