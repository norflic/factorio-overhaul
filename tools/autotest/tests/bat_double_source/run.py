"""Banc HORS JEU de fo-autotest.bat en double source (FO_CREATE_SRC, étape [2b/4]) : ne lance pas Factorio et
n'écrit rien dans la racine du jeu. Chaque cas tourne dans une racine JETABLE (dossier temporaire, chemins avec
espaces) qui contient une copie du .bat, un faux factorio.exe et un faux robocopy.exe compilés ici (gcc de
C:\\mingw64 ; sources : fake_factorio.c, fake_robocopy.c).

    python -B tools/autotest/tests/bat_double_source/run.py [--bat CHEMIN] [--gcc CHEMIN] [--keep]

Cas (suite H-T3, correction du défaut « résultat de rmdir et de robocopy non vérifiés à l'étape [2b/4] ») :
  1. sans FO_CREATE_SRC : code 0, done.txt, pas de create-source.txt, le benchmark voit la source nouvelle ;
  2. double source : code 0, create-source.txt, le benchmark voit la source nouvelle et AUCUN fichier propre
     à l'ancienne (marker-old.txt) ;
  3. un fichier de la copie de création reste ouvert sans partage (rmdir échoue en partie) : code 1, pas de
     done.txt, benchmark NON lancé (avant la correction : code 0 et marker-old.txt mêlé à la source nouvelle) ;
  4. robocopy de la source du benchmark en échec (code 16) : code 1, benchmark NON lancé (avant : code 0 et
     un benchmark sans factorio-overhaul).
Dans tous les cas, le verrou de la racine jetable est rendu. Code de sortie : 0 si les 4 cas passent.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_BAT = os.path.normpath(os.path.join(HERE, "..", "..", "fo-autotest.bat"))


def compile_fakes(gcc, out):
    for name in ("fake_factorio", "fake_robocopy"):
        exe = os.path.join(out, name + ".exe")
        r = subprocess.run([gcc, "-O1", "-o", exe, os.path.join(HERE, name + ".c")], capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit("compilation de %s.c impossible : %s" % (name, r.stderr.strip()))


def make_root(base, bat, bins, name):
    root = os.path.join(base, "racine " + name)
    os.makedirs(os.path.join(root, "bin", "x64"))
    shutil.copy(bat, os.path.join(root, "fo-autotest.bat"))
    shutil.copy(os.path.join(bins, "fake_factorio.exe"), os.path.join(root, "bin", "x64", "factorio.exe"))
    # cmd cherche d'abord dans le dossier courant (le .bat fait cd /d "%~dp0") : ce robocopy y passe avant
    # celui de System32 (variable NoDefaultCurrentDirectoryInExePath retirée de l'environnement du cas).
    shutil.copy(os.path.join(bins, "fake_robocopy.exe"), os.path.join(root, "robocopy.exe"))
    old, new = os.path.join(root, "src ancienne"), os.path.join(root, "src nouvelle")
    for src, ver in ((old, "0.4.1"), (new, "0.4.2")):
        os.makedirs(os.path.join(src, "tools", "autotest", "fo-autotest"))
        with open(os.path.join(src, "info.json"), "w") as f:
            f.write('{\n  "name": "factorio-overhaul",\n  "version": "%s"\n}\n' % ver)
        with open(os.path.join(src, "tools", "autotest", "fo-autotest", "control.lua"), "w") as f:
            f.write("-- mod de test factice\n")
    with open(os.path.join(old, "marker-old.txt"), "w") as f:
        f.write("seulement dans la source ancienne\n")
    return root, old, new


def run_case(base, bat, bins, name, double, extra):
    root, old, new = make_root(base, bat, bins, name)
    env = {k: v for k, v in os.environ.items()
           if k.upper() not in ("FO_CREATE_SRC", "FO_LOCK_HELD", "NODEFAULTCURRENTDIRECTORYINEXEPATH",
                                "FAKE_HOLD", "FAKE_ROBO_FAIL")}
    if double:
        env["FO_CREATE_SRC"] = old
    for k, v in extra.items():
        env[k] = v.replace("<new>", new)
    cmd = 'cmd /s /c ""%s" nopause 10 content "%s""' % (os.path.join(root, "fo-autotest.bat"), new)
    p = subprocess.run(cmd, env=env, capture_output=True, text=True, errors="replace")
    test = os.path.join(root, "fo-autotest")
    bso = os.path.join(test, "benchmark-stdout.txt")
    bench = open(bso, errors="replace").read() if os.path.exists(bso) else None
    res = {
        "rc": p.returncode,
        "done": os.path.exists(os.path.join(test, "done.txt")),
        "create_source": os.path.exists(os.path.join(test, "create-source.txt")),
        "lock": os.path.exists(os.path.join(root, "fo-autotest.lock")),
        "bench": bench,
        "console": [l for l in p.stdout.splitlines() if l.strip()][-1:] or [""],
    }
    if "FAKE_HOLD" in extra:
        time.sleep(9)  # l'enfant qui tient le fichier se termine (8 s) avant le nettoyage
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bat", default=REPO_BAT)
    ap.add_argument("--gcc", default=r"C:\mingw64\bin\gcc.exe")
    ap.add_argument("--keep", action="store_true", help="garder les racines jetables")
    a = ap.parse_args()
    base = tempfile.mkdtemp(prefix="fo bat double source ")
    bins = os.path.join(base, "bin")
    os.makedirs(bins)
    compile_fakes(a.gcc, bins)
    ok = fail = 0

    def check(cond, label, res):
        nonlocal ok, fail
        if cond:
            ok += 1
        else:
            fail += 1
        print("%s %s (code %d, done %s, create-source %s, verrou %s, benchmark %s ; %s)" % (
            "OK    " if cond else "ECHEC ", label, res["rc"], res["done"], res["create_source"], res["lock"],
            (res["bench"] or "non lance").strip().replace("\n", " | "), res["console"][0].strip()))

    r = run_case(base, a.bat, bins, "1 sans variable", False, {})
    check(r["rc"] == 0 and r["done"] and not r["create_source"] and not r["lock"] and r["bench"]
          and '"0.4.2"' in r["bench"] and "marker-old.txt absent" in r["bench"],
          "1. sans FO_CREATE_SRC : comportement habituel", r)
    r = run_case(base, a.bat, bins, "2 double source", True, {})
    check(r["rc"] == 0 and r["done"] and r["create_source"] and not r["lock"] and r["bench"]
          and '"0.4.2"' in r["bench"] and "marker-old.txt absent" in r["bench"],
          "2. double source : le benchmark voit la seule source nouvelle", r)
    r = run_case(base, a.bat, bins, "3 fichier verrouille", True, {"FAKE_HOLD": "marker-old.txt"})
    check(r["rc"] == 1 and not r["done"] and r["bench"] is None and not r["lock"],
          "3. copie de creation non effacee (fichier tenu ouvert) : arret, code 1", r)
    r = run_case(base, a.bat, bins, "4 robocopy en echec", True, {"FAKE_ROBO_FAIL": "<new>"})
    check(r["rc"] == 1 and not r["done"] and r["bench"] is None and not r["lock"],
          "4. copie de la source du benchmark en echec : arret, code 1", r)
    print("BILAN : %d OK, %d ECHEC(S)  (bat : %s)" % (ok, fail, a.bat))
    if a.keep:
        print("racines gardees :", base)
    else:
        shutil.rmtree(base, ignore_errors=True)
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
