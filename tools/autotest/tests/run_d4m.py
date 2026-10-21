"""Bancs HORS JEU du lot D4m, en une commande (ne lance pas Factorio, n'écrit rien dans la racine du jeu).

    python -B tools/autotest/tests/run_d4m.py [--work DOSSIER] [--lua lua5.2] [--logs <racine>/fo-logs]

  1. d4_dryrun.lua : le greffon d4-geant sur un moteur simulé (pose, champ réel, bras et foreuses reliés, BILAN,
     journal) ; son journal sert de fixture ;
  2. make_fixtures.py : vram.tsv et perf-stats.csv synthétiques ;
  3. unit_vram.py : vram.py et memory_summary (arithmétique, formats supposés) ;
  4. driver_it.py : visual_session.main() sur une racine factice avec un faux jeu (options, config.ini de test,
     codes 0 et 9, preuves recopiées, session.txt) ;
  5. (--logs) vram.py sur chaque visual.log des archives : 15 atlas attendus, aucune erreur.
Dossier de travail : --work, sinon un dossier temporaire neuf. Code de sortie 0 si toutes les étapes passent.
Ce que ces bancs NE prouvent PAS : tout ce qui dépend du moteur réel (README §5.3, « Non prouvé »).
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
AUTOTEST = os.path.dirname(HERE)
ROOT = os.path.dirname(os.path.dirname(AUTOTEST))


def step(name, cmd, results):
    print("=" * 8, name, ":", subprocess.list2cmdline(cmd), flush=True)
    try:
        rc = subprocess.run(cmd).returncode
    except OSError as exc:
        print("impossible de lancer %s : %s" % (cmd[0], exc))
        rc = 127
    results.append((name, rc))
    print("=" * 8, name, ":", "OK" if rc == 0 else "ECHEC (code %d)" % rc, flush=True)
    return rc == 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--work", help="dossier de travail (defaut : dossier temporaire neuf)")
    ap.add_argument("--lua", default="lua5.2", help="interprete Lua 5.2 (defaut : lua5.2 du PATH)")
    ap.add_argument("--logs", help="dossier d'archives fo-logs : vram.py sur chaque visual.log")
    a = ap.parse_args()
    work = os.path.abspath(a.work) if a.work else tempfile.mkdtemp(prefix="fo-d4m-")
    fixture = os.path.join(work, "fixture")
    os.makedirs(fixture, exist_ok=True)
    py = [sys.executable, "-B"]
    lua = shutil.which(a.lua) or a.lua  # « lua5.2 » : CreateProcess n'ajoute pas .exe à un nom qui a déjà un point
    results = []
    step("essai a blanc du greffon", [lua, os.path.join(HERE, "d4_dryrun.lua"), ROOT, os.path.join(fixture, "factorio.log")],
         results)
    step("fixtures synthetiques", py + [os.path.join(HERE, "make_fixtures.py"), fixture], results)
    step("unitaires vram.py", py + [os.path.join(HERE, "unit_vram.py"), AUTOTEST, fixture], results)
    step("integration visual_session.py", py + [os.path.join(HERE, "driver_it.py"), AUTOTEST, work], results)
    if a.logs:
        logs = sorted(glob.glob(os.path.join(a.logs, "*", "visual.log")))
        bad = []
        for lg in logs:
            out = subprocess.run(py + [os.path.join(AUTOTEST, "vram.py"), lg], capture_output=True, text=True,
                                 encoding="utf-8", errors="replace")
            line = next((ln for ln in out.stdout.splitlines() if ln.startswith("-- Atlas de sprites")), "")
            tot = next((ln.strip() for ln in out.stdout.splitlines() if ln.strip().startswith("TOTAL")), "")
            load = next((ln.strip() for ln in out.stdout.splitlines() if ln.startswith("atlas ")), "")
            print("  %s : %s | %s | %s" % (os.path.basename(os.path.dirname(lg)), line.strip(), tot, load))
            if out.returncode != 0 or "(15)" not in line:
                bad.append(lg)
        results.append(("vram.py sur %d journaux archives" % len(logs), 0 if logs and not bad else 1))
        print("=" * 8, "vram.py sur les archives :", "OK" if logs and not bad else "ECHEC %s" % bad)
    print()
    for name, rc in results:
        print("%-40s %s" % (name, "OK" if rc == 0 else "ECHEC (code %d)" % rc))
    n_ok = sum(1 for _, rc in results if rc == 0)
    print("BILAN d4m hors jeu : %d/%d etapes OK (dossier de travail : %s)" % (n_ok, len(results), work))
    return 0 if n_ok == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
