"""Essai d'intégration HORS JEU de visual_session.main() sur une racine FACTICE, avec un faux jeu (fake_game.py).

Usage : python -B driver_it.py <dossier tools/autotest> <dossier de travail>
Le dossier de travail reçoit la racine factice (<travail>/fakeroot, recréée) ; les fixtures sont lues dans
<travail>/fixture (run_d4m.py les prépare). Rien n'est lu ni écrit dans la vraie racine du jeu ; aucune liste de
processus réelle ne sert à fermer quoi que ce soit (factorio_processes est remplacée par une liste vide) ; le
faux jeu est un script Python lancé sans fenêtre. Les compteurs GPU de Windows sont lus (lecture seule) pour le
PID du faux jeu.
"""
import os
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
AUTOTEST, WORK = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AUTOTEST)
import visual_session as vs  # noqa: E402

root = os.path.join(WORK, "fakeroot")
if os.path.isdir(root):
    shutil.rmtree(root)
os.makedirs(os.path.join(root, "bin", "x64"))
open(os.path.join(root, "bin", "x64", "factorio.exe"), "w").close()  # fichier vide : seul os.path.exists le lit
test = os.path.join(root, "fo-autotest")
os.makedirs(os.path.join(test, "mods", "fo-autotest", "scenarios"))
open(os.path.join(test, "fo-autotest-map.zip"), "wb").write(b"PK")
open(os.path.join(test, "source.txt"), "w").write("worktree D4m (essai)\n")
open(os.path.join(test, "mods", "fo-autotest", "scenario.lua"), "w").write('return "d4-geant"\n')
open(os.path.join(test, "mods", "fo-autotest", "scenarios", "d4-geant.lua"), "w").write("return {}\n")
os.environ["FAKE_FIXTURE"] = os.path.join(WORK, "fixture")

real_popen = subprocess.Popen
launched = []


class Shim:
    def __getattr__(self, k):
        return getattr(subprocess, k)

    def Popen(self, cmd, **kw):
        launched.append(cmd)
        kw["creationflags"] = 0x08000000  # CREATE_NO_WINDOW
        kw.pop("startupinfo", None)
        return real_popen([sys.executable, "-B", os.path.join(HERE, "fake_game.py")] + cmd[1:], **kw)


vs.subprocess = Shim()
vs.factorio_processes = lambda: []
CASES = (
    ("normale, compression basse, mesure, hd",
     ["--quality", "normal", "--texture-compression", "low-quality", "--measure", "--window", "hd", "--ticks", "3000"], {}),
    ("haute demandee, journal normal", ["--quality", "high", "--video-memory", "medium"], {"FAKE_FORCE_QUALITY": "normal"}),
    ("compression basse demandee, journal haute", ["--texture-compression", "low-quality"], {"FAKE_FORCE_DXT": "high-quality"}),
)
results = []
for label, extra, env in CASES:
    for k in ("FAKE_FORCE_QUALITY", "FAKE_FORCE_DXT"):
        os.environ.pop(k, None)
    os.environ.update(env)
    sys.argv = ["visual_session.py", "--root", root, "--timeout", "60"] + extra
    print("=" * 20, label)
    code = vs.main()
    shots = os.path.join(root, "fo-visual", "write", "script-output", "fo-shots")
    cfg = open(os.path.join(root, "fo-visual", "config.ini"), encoding="utf-8").read()
    sess = open(os.path.join(shots, "session.txt"), encoding="utf-8").read()
    results.append((label, code, sorted(os.listdir(shots)), cfg, launched[-1], sess))
print()
ok = fail = 0


def check(cond, what):
    global ok, fail
    print(("OK    " if cond else "ECHEC ") + what)
    if cond:
        ok += 1
    else:
        fail += 1


lab, code, files, cfg, cmd, sess = results[0]
check(code == 0, "code 0 (mesure, qualite normale et compression basse appliquees) : %s" % code)
check("graphics-quality=normal" in cfg, "cle graphics-quality=normal dans le config.ini de test")
check("texture-compression-level=low-quality" in cfg, "cle texture-compression-level=low-quality dans le config.ini de test")
check("--graphics-quality" in cmd and cmd[cmd.index("--graphics-quality") + 1] == "normal", "option --graphics-quality normal")
check("--output-perf-stats" in cmd, "option --output-perf-stats")
check("--window-size" in cmd and cmd[cmd.index("--window-size") + 1] == "1920x1080", "fenetre hd 1920x1080")
check(all(f in files for f in ("vram.tsv", "factorio.log", "stdout.txt", "perf-stats.csv", "memoire.txt", "session.txt")),
      "preuves recopiees dans fo-shots : " + ", ".join(files))
check("images/s phase z030-jour : phase 60.0" in sess, "session.txt : images/s par phase (voie phase)")
check("VSync ACTIF" in sess and "144" in sess, "session.txt : VSync et frequence de l'ecran")
check("champ reel de la vue z030-jour" in sess, "session.txt : champ reel des vues")
lab, code, files, cfg, cmd, sess = results[1]
check(code == 9, "code 9 quand le journal contredit la qualite demandee (obtenu %s)" % code)
check("graphics-quality=high" in cfg and "video-memory-usage=medium" in cfg, "cles high et medium ecrites")
check("--graphics-quality" not in cmd, "pas d'option --graphics-quality pour high (le binaire ne l'accepte pas)")
check(cmd[cmd.index("--video-memory-usage") + 1] == "medium", "option --video-memory-usage medium")
check("--output-perf-stats" not in cmd, "pas de statistiques de rendu sans --measure")
lab, code, files, cfg, cmd, sess = results[2]
check(code == 9, "code 9 quand le journal contredit la compression demandee (obtenu %s)" % code)
check("ECHEC compression des textures demandee low-quality, appliquee high-quality" in sess,
      "session.txt : ecart de compression ecrit")
print("--- session.txt (1er essai) ---")
print(results[0][5])
print("BILAN integration : %d OK, %d ECHEC(S)" % (ok, fail))
sys.exit(0 if not fail else 1)
