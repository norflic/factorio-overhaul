"""Banc HORS JEU de fo-autotest.bat : double source (FO_CREATE_SRC, étape [2b/4]) et graine de la carte
(FO_MAP_SEED, lot INT-GRAINE). Ne lance pas Factorio et n'écrit rien dans la racine du jeu. Chaque cas tourne dans
une racine JETABLE (dossier temporaire, chemins avec espaces) qui contient une copie du .bat, un faux factorio.exe
et un faux robocopy.exe compilés ici (gcc de C:\\mingw64 ; sources : fake_factorio.c, fake_robocopy.c).

    python -B tools/autotest/tests/bat_double_source/run.py [--bat CHEMIN] [--captures CHEMIN] [--gcc CHEMIN]
                                                            [--keep]

Cas (suite H-T3, correction du défaut « résultat de rmdir et de robocopy non vérifiés à l'étape [2b/4] ») :
  1. sans FO_CREATE_SRC : code 0, done.txt, pas de create-source.txt, le benchmark voit la source nouvelle ;
  2. double source : code 0, create-source.txt, le benchmark voit la source nouvelle et AUCUN fichier propre
     à l'ancienne (marker-old.txt) ;
  3. un fichier de la copie de création reste ouvert sans partage (rmdir échoue en partie) : code 1, pas de
     done.txt, benchmark NON lancé (avant la correction : code 0 et marker-old.txt mêlé à la source nouvelle) ;
  4. robocopy de la source du benchmark en échec (code 16) : code 1, benchmark NON lancé (avant : code 0 et
     un benchmark sans factorio-overhaul).
Cas de la graine (lot INT-GRAINE ; le faux factorio.exe écrit dans create-stdout.txt la valeur qui suit
--map-gen-seed, le nombre d'occurrences de l'option, argc et la variable FO_MAP_SEED qu'il a reçue) :
  5. graine par défaut : les cas 1 et 2 (sans FO_MAP_SEED) ont passé « --map-gen-seed 20261020 » une seule fois,
     argc 10, et seed.txt vaut 20261020 ;
  6. FO_MAP_SEED vide (présente dans l'environnement avec une valeur vide) : défaut 20261020 ;
  7. graines valides (987654321, 4294967295, 0, 0042 -> 42, 20 chiffres dont 19 zéros de tête -> 7, et 42 en
     double source) : la graine (sans zéros de tête) est passée à --create et écrite dans seed.txt, code 0 ;
  8. graines refusées (4294967296, 11 chiffres, lettres, signe, espace, espace seul, « ! », « % », guillemet et
     « & » d'injection) : code 1, message « Graine invalide », factorio NON lancé, verrou rendu, fo-autotest\\ du
     banc précédent intact (done.txt « ancien »), aucune commande injectée exécutée ;
  9. par fo-captures.bat (qui appelle fo-autotest.bat ; fo-visual.bat remplacé par un faux) : la graine de
     FO_MAP_SEED arrive à --create ; une graine refusée donne le code 8, fo-visual.bat NON appelé, verrou rendu.
Cas du son (lot S0, E69 ; le faux factorio.exe écrit le nombre de --disable-audio reçus et les lignes de volume
du config.ini qu'il lit AU LANCEMENT, à la création comme au benchmark) :
 10. sans FO_AUDIO (cas 1 et 2) ou FO_AUDIO vide : --disable-audio une fois à la création ET au benchmark, aucune
     section [sound] (comportement inchangé), audio.txt « son coupe » ;
 11. FO_AUDIO=1 : aucun --disable-audio, section [sound] avec les 9 volumes à 0.000000 déjà écrits quand le jeu
     démarre, à la création et au benchmark, audio.txt « son ACTIF » ; en double source aussi ;
 12. FO_AUDIO refusée (0, « yes », « 1 » suivi d'une espace, « 11 », « % », guillemet et « & » d'injection) :
     code 1, rien n'a tourné, verrou rendu, fo-autotest\\ précédent intact, aucune commande injectée ;
 13. par fo-captures.bat : FO_AUDIO=1 arrive au banc (création sans --disable-audio) ; une valeur refusée donne
     le code 8, fo-visual.bat NON appelé.
Code de sortie : 0 si tous les contrôles passent.
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
REPO_CAPTURES = os.path.normpath(os.path.join(HERE, "..", "..", "fo-captures.bat"))
DEFAULT_SEED = "20261020"
# Faux fo-visual.bat (cas 9) : note son appel et rend 0.
FAKE_VISUAL = '@echo off\r\n> "%~dp0fo-visual-appel.txt" echo appel\r\nexit /b 0\r\n'


def compile_fakes(gcc, out):
    for name in ("fake_factorio", "fake_robocopy"):
        exe = os.path.join(out, name + ".exe")
        r = subprocess.run([gcc, "-O1", "-o", exe, os.path.join(HERE, name + ".c")], capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit("compilation de %s.c impossible : %s" % (name, r.stderr.strip()))


def make_root(base, bat, bins, name, captures=None):
    root = os.path.join(base, "racine " + name)
    os.makedirs(os.path.join(root, "bin", "x64"))
    shutil.copy(bat, os.path.join(root, "fo-autotest.bat"))
    if captures:
        shutil.copy(captures, os.path.join(root, "fo-captures.bat"))
        with open(os.path.join(root, "fo-visual.bat"), "w", newline="") as f:
            f.write(FAKE_VISUAL)
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


def read(path):
    return open(path, errors="replace").read() if os.path.exists(path) else None


def run_case(base, bat, bins, name, double, extra, captures=None, previous=False):
    """captures : chemin de fo-captures.bat (le cas passe par lui) ; previous : un fo-autotest\\ « ancien » existe
    déjà (résultats du banc précédent, qui doivent rester intacts si rien ne tourne)."""
    root, old, new = make_root(base, bat, bins, name, captures)
    test = os.path.join(root, "fo-autotest")
    if previous:
        os.makedirs(test)
        with open(os.path.join(test, "done.txt"), "w") as f:
            f.write("ancien\n")
    env = {k: v for k, v in os.environ.items()
           if k.upper() not in ("FO_CREATE_SRC", "FO_LOCK_HELD", "NODEFAULTCURRENTDIRECTORYINEXEPATH",
                                "FAKE_HOLD", "FAKE_ROBO_FAIL", "FO_MAP_SEED", "FO_AUDIO")}
    if double:
        env["FO_CREATE_SRC"] = old
    for k, v in extra.items():
        env[k] = v.replace("<new>", new)
    if captures:
        cmd = 'cmd /s /c ""%s" content "%s""' % (os.path.join(root, "fo-captures.bat"), new)
    else:
        cmd = 'cmd /s /c ""%s" nopause 10 content "%s""' % (os.path.join(root, "fo-autotest.bat"), new)
    p = subprocess.run(cmd, env=env, cwd=root, capture_output=True, text=True, errors="replace")
    bench = read(os.path.join(test, "benchmark-stdout.txt"))
    seed = read(os.path.join(test, "seed.txt"))
    res = {
        "rc": p.returncode,
        "done": os.path.exists(os.path.join(test, "done.txt")),
        "done_text": (read(os.path.join(test, "done.txt")) or "").strip(),
        "create_source": os.path.exists(os.path.join(test, "create-source.txt")),
        "lock": os.path.exists(os.path.join(root, "fo-autotest.lock")),
        "bench": bench,
        "create_out": read(os.path.join(test, "create-stdout.txt")),
        "seed": seed.strip() if seed is not None else None,
        "audio": (read(os.path.join(test, "audio.txt")) or "").strip(),
        "visual": os.path.exists(os.path.join(root, "fo-visual-appel.txt")),
        "piege": sorted(f for f in os.listdir(root) if f.lower().startswith("piege")),
        "stdout": p.stdout,
        "console": [l for l in p.stdout.splitlines() if l.strip()][-1:] or [""],
    }
    if "FAKE_HOLD" in extra:
        time.sleep(9)  # l'enfant qui tient le fichier se termine (8 s) avant le nettoyage
    return res


def seed_passed(res, seed):
    """La graine `seed` a été passée telle quelle, une seule fois, sans mot de trop, et écrite dans seed.txt."""
    out = res["create_out"] or ""
    return ("create : map-gen-seed [%s] x1 argc 10" % seed) in out and res["seed"] == seed


AUDIO_KEYS = ("master-volume", "music-volume", "game-effects-volume", "gui-effects-volume", "walking-sound-volume",
              "environment-sounds-volume", "alerts-volume", "wind-volume", "simulation-volume")


def audio_off(res):
    """Son coupé comme avant : --disable-audio une fois à la création et au benchmark, aucune ligne [sound]."""
    c, b = res["create_out"] or "", res["bench"] or ""
    return ("create : disable-audio x1" in c and "benchmark : disable-audio x1" in b
            and "create : config [sound] x0, 0 ligne(s) de volume" in c
            and "benchmark : config [sound] x0, 0 ligne(s) de volume" in b
            and res["audio"].startswith("son coupe"))


def audio_on(res):
    """Son actif : aucun --disable-audio ; les 9 volumes à 0 sont dans le config.ini quand le jeu démarre."""
    c, b = res["create_out"] or "", res["bench"] or ""
    ok = ("create : disable-audio x0" in c and "benchmark : disable-audio x0" in b
          and "create : config [sound] x1, %d ligne(s) de volume" % len(AUDIO_KEYS) in c
          and "benchmark : config [sound] x1, %d ligne(s) de volume" % len(AUDIO_KEYS) in b
          and res["audio"].startswith("son ACTIF"))
    for k in AUDIO_KEYS:
        ok = ok and ("create : config %s=0.000000" % k) in c and ("benchmark : config %s=0.000000" % k) in b
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bat", default=REPO_BAT)
    ap.add_argument("--captures", default=REPO_CAPTURES)
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
        create = [l.strip() for l in (res["create_out"] or "").splitlines() if "map-gen-seed" in l or " env " in l]
        print("%s %s (code %d, done %s, create-source %s, verrou %s, seed.txt %s, create %s, benchmark %s ; %s)" % (
            "OK    " if cond else "ECHEC ", label, res["rc"], res["done"], res["create_source"], res["lock"],
            res["seed"], " | ".join(create) or "non lance",
            (res["bench"] or "non lance").strip().replace("\n", " | "), res["console"][0].strip()))

    # --- double source (suite H-T3) ---
    r1 = run_case(base, a.bat, bins, "1 sans variable", False, {})
    check(r1["rc"] == 0 and r1["done"] and not r1["create_source"] and not r1["lock"] and r1["bench"]
          and '"0.4.2"' in r1["bench"] and "marker-old.txt absent" in r1["bench"],
          "1. sans FO_CREATE_SRC : comportement habituel", r1)
    r2 = run_case(base, a.bat, bins, "2 double source", True, {})
    check(r2["rc"] == 0 and r2["done"] and r2["create_source"] and not r2["lock"] and r2["bench"]
          and '"0.4.2"' in r2["bench"] and "marker-old.txt absent" in r2["bench"],
          "2. double source : le benchmark voit la seule source nouvelle", r2)
    r = run_case(base, a.bat, bins, "3 fichier verrouille", True, {"FAKE_HOLD": "marker-old.txt"})
    check(r["rc"] == 1 and not r["done"] and r["bench"] is None and not r["lock"],
          "3. copie de creation non effacee (fichier tenu ouvert) : arret, code 1", r)
    r = run_case(base, a.bat, bins, "4 robocopy en echec", True, {"FAKE_ROBO_FAIL": "<new>"})
    check(r["rc"] == 1 and not r["done"] and r["bench"] is None and not r["lock"],
          "4. copie de la source du benchmark en echec : arret, code 1", r)

    # --- graine (lot INT-GRAINE) ---
    check(seed_passed(r1, DEFAULT_SEED) and "env FO_MAP_SEED ABSENTE" in (r1["create_out"] or ""),
          "5a. sans FO_MAP_SEED : graine 20261020 (defaut inchange)", r1)
    check(seed_passed(r2, DEFAULT_SEED), "5b. double source sans FO_MAP_SEED : graine 20261020", r2)
    r = run_case(base, a.bat, bins, "6 graine vide", False, {"FO_MAP_SEED": ""})
    check(r["rc"] == 0 and r["done"] and not r["lock"] and seed_passed(r, DEFAULT_SEED),
          "6. FO_MAP_SEED vide : retour au defaut 20261020", r)
    valid = [("987654321", "987654321"), ("4294967295", "4294967295"), ("0", "0"), ("0042", "42"),
             ("0" * 19 + "7", "7")]
    for i, (given, expected) in enumerate(valid):
        r = run_case(base, a.bat, bins, "7%s graine %s" % ("abcde"[i], expected), False, {"FO_MAP_SEED": given})
        check(r["rc"] == 0 and r["done"] and not r["lock"] and seed_passed(r, expected)
              and ("env FO_MAP_SEED [%s]" % given) in (r["create_out"] or ""),
              "7%s. FO_MAP_SEED=%s : graine %s passee a --create" % ("abcde"[i], given, expected), r)
    r = run_case(base, a.bat, bins, "7f double source graine 42", True, {"FO_MAP_SEED": "42"})
    check(r["rc"] == 0 and r["done"] and r["create_source"] and not r["lock"] and seed_passed(r, "42")
          and r["bench"] and '"0.4.2"' in r["bench"] and "marker-old.txt absent" in r["bench"],
          "7f. double source et FO_MAP_SEED=42 : les deux s'appliquent", r)
    invalid = ["4294967296", "12345678901", "12ab", "-5", "1 2", " ", "12!34", "%CD%",
               '1" & echo PIEGE> piege.txt & rem "', "1&echo PIEGE>piege2.txt"]
    for i, given in enumerate(invalid):
        r = run_case(base, a.bat, bins, "8%02d graine refusee" % i, False, {"FO_MAP_SEED": given}, previous=True)
        check(r["rc"] == 1 and "Graine invalide" in r["stdout"] and r["create_out"] is None and r["seed"] is None
              and r["done_text"] == "ancien" and not r["lock"] and not r["piege"],
              "8.%02d FO_MAP_SEED=[%s] refusee : code 1, rien n'a tourne" % (i, given), r)
    if a.captures and os.path.exists(a.captures):
        r = run_case(base, a.bat, bins, "9a captures graine", False, {"FO_MAP_SEED": "123456"}, captures=a.captures)
        check(r["rc"] == 0 and r["visual"] and not r["lock"] and seed_passed(r, "123456"),
              "9a. fo-captures.bat avec FO_MAP_SEED=123456 : graine passee a --create", r)
        r = run_case(base, a.bat, bins, "9b captures graine refusee", False, {"FO_MAP_SEED": "abc"},
                     captures=a.captures, previous=True)
        check(r["rc"] == 8 and not r["visual"] and not r["lock"] and r["done_text"] == "ancien"
              and r["create_out"] is None,
              "9b. fo-captures.bat avec FO_MAP_SEED=abc : code 8, session visuelle non lancee", r)
    else:
        fail += 1
        print("ECHEC  9. fo-captures.bat introuvable : %s" % a.captures)

    # --- son (lot S0, E69) ---
    check(audio_off(r1), "10a. sans FO_AUDIO : --disable-audio a la creation et au benchmark (inchange)", r1)
    check(audio_off(r2), "10b. double source sans FO_AUDIO : son coupe", r2)
    r = run_case(base, a.bat, bins, "10c son vide", False, {"FO_AUDIO": ""})
    check(r["rc"] == 0 and r["done"] and not r["lock"] and audio_off(r) and seed_passed(r, DEFAULT_SEED),
          "10c. FO_AUDIO vide : son coupe, comme sans variable", r)
    r = run_case(base, a.bat, bins, "11a son actif", False, {"FO_AUDIO": "1"})
    check(r["rc"] == 0 and r["done"] and not r["lock"] and audio_on(r)
          and ("create : map-gen-seed [%s] x1 argc 9" % DEFAULT_SEED) in (r["create_out"] or ""),
          "11a. FO_AUDIO=1 : sans --disable-audio, 9 volumes a 0 avant chaque lancement", r)
    r = run_case(base, a.bat, bins, "11b son actif double source", True, {"FO_AUDIO": "1"})
    check(r["rc"] == 0 and r["done"] and r["create_source"] and not r["lock"] and audio_on(r)
          and r["bench"] and '"0.4.2"' in r["bench"] and "marker-old.txt absent" in r["bench"],
          "11b. FO_AUDIO=1 en double source : volumes a 0 aux deux lancements", r)
    bad_audio = ["0", "yes", "1 ", "11", "%CD%", '1" & echo PIEGE> piege3.txt & rem "', "1&echo PIEGE>piege4.txt"]
    for i, given in enumerate(bad_audio):
        r = run_case(base, a.bat, bins, "12%02d son refuse" % i, False, {"FO_AUDIO": given}, previous=True)
        check(r["rc"] == 1 and "FO_AUDIO" in r["stdout"] and r["create_out"] is None and r["seed"] is None
              and r["done_text"] == "ancien" and not r["lock"] and not r["piege"],
              "12.%02d FO_AUDIO=[%s] refusee : code 1, rien n'a tourne" % (i, given), r)
    if a.captures and os.path.exists(a.captures):
        r = run_case(base, a.bat, bins, "13a captures son", False, {"FO_AUDIO": "1"}, captures=a.captures)
        check(r["rc"] == 0 and r["visual"] and not r["lock"] and audio_on(r),
              "13a. fo-captures.bat avec FO_AUDIO=1 : banc sans --disable-audio, volumes a 0", r)
        r = run_case(base, a.bat, bins, "13b captures son refuse", False, {"FO_AUDIO": "oui"},
                     captures=a.captures, previous=True)
        check(r["rc"] == 8 and not r["visual"] and not r["lock"] and r["done_text"] == "ancien"
              and r["create_out"] is None,
              "13b. fo-captures.bat avec FO_AUDIO=oui : code 8, session visuelle non lancee", r)
    else:
        fail += 1
        print("ECHEC  13. fo-captures.bat introuvable : %s" % a.captures)
    print("BILAN : %d OK, %d ECHEC(S)  (bat : %s)" % (ok, fail, a.bat))
    if a.keep:
        print("racines gardees :", base)
    else:
        shutil.rmtree(base, ignore_errors=True)
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
