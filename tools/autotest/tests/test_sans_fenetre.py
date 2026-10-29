# Lot OUTILLAGE (28/10) : le banc ne doit ouvrir aucune fenêtre de console chez le joueur. Hors jeu, environ 40 s.
#   PYTHONUTF8=1 py -3.9 -B tools/autotest/tests/test_sans_fenetre.py   -> BILAN : n OK
# 1. Règles pures de tools/autotest/sans_fenetre.py (drapeaux, priorité, console à cacher) et de fenetres.py.
# 2. EnumWindows (tools/autotest/fenetres.py) pendant le VRAI banc.py lancé par pythonw (aucune console, comme une tâche de
#    fond) sur une racine jetable avec un faux fo-autotest.bat qui lance robocopy, powershell et ping : l'ANCIEN banc.py (lu dans
#    git, commit ce8d148) ouvre une console VISIBLE (témoin positif) ; le nouveau, aucune.
# 3. Mutants : banc.py qui relance subprocess.run au lieu de sans_fenetre.run, sans_fenetre sans CREATE_NO_WINDOW, règle de la
#    console qui cache celle d'un humain : chacun doit être vu par l'un des contrôles.
# 4. Priorité réduite du faux .bat (lue par powershell DANS le .bat) ; FO_BANC_PRIORITE=normal la supprime.
# 5. Console propre : un programme sans console la cache ; derrière un cmd (terminal d'un humain), il la laisse visible.
import os
import shutil
import subprocess
import sys
import tempfile
import time

ICI = os.path.dirname(os.path.abspath(__file__))
AUTOTEST = os.path.dirname(ICI)
DEPOT = os.path.dirname(os.path.dirname(AUTOTEST))
ANCIEN_COMMIT = "ce8d148"
sys.path.insert(0, AUTOTEST)
import fenetres  # noqa: E402
import sans_fenetre  # noqa: E402

ok = 0
ko = 0


def verifie(cond, quoi):
    global ok, ko
    if cond:
        ok += 1
        print("OK   " + quoi)
    else:
        ko += 1
        print("ECHEC " + quoi)


# 1. Règles pures
verifie(sans_fenetre.priorite_voulue({}) == "below", "priorité par défaut : réduite")
verifie(sans_fenetre.priorite_voulue({"FO_BANC_PRIORITE": "normal"}) == "normal", "FO_BANC_PRIORITE=normal : normale")
verifie(sans_fenetre.priorite_voulue({"FO_BANC_PRIORITE": " NORMAL "}) == "normal", "FO_BANC_PRIORITE : espaces et casse ignorés")
verifie(sans_fenetre.priorite_voulue({"FO_BANC_PRIORITE": "haute"}) == "below", "valeur inconnue : priorité réduite")
d = sans_fenetre.drapeaux("below")
verifie(d & 0x08000000 and d & 0x4000 and not d & 0x20, "drapeaux « below » : CREATE_NO_WINDOW | BELOW_NORMAL")
d = sans_fenetre.drapeaux("normal")
verifie(d & 0x08000000 and d & 0x20 and not d & 0x4000, "drapeaux « normal » : CREATE_NO_WINDOW | NORMAL (explicite)")
o = sans_fenetre.options("below")
verifie(o["creationflags"] & 0x08000000 and o["startupinfo"].wShowWindow == 0
        and o["startupinfo"].dwFlags & subprocess.STARTF_USESHOWWINDOW, "options : CREATE_NO_WINDOW et SW_HIDE")

cc = sans_fenetre.console_a_cacher
verifie(cc([10], 10, 5, "py.exe") and cc([10, 5], 10, 5, "py.exe") and cc([5, 10], 10, 5, "PY.EXE"),
        "console à cacher : le programme seul, ou avec son lanceur py.exe")
verifie(not cc([10, 5], 10, 5, "cmd.exe") and not cc([10, 5], 10, 5, "powershell.exe") and not cc([10, 5], 10, 5, "bash.exe"),
        "console d'un humain (cmd, PowerShell, bash en parent) : jamais cachée")
verifie(not cc([10, 77], 10, 5, "py.exe") and not cc([], 10, 5, "py.exe"),
        "un tiers attaché à la console, ou aucun processus : jamais cachée")

verifie(fenetres.suspecte("ConsoleWindowClass", "x.exe") and fenetres.suspecte("Autre", "CMD.EXE")
        and not fenetres.suspecte("Autre", "factorio.exe"), "veille : fenêtre de type shell reconnue, le jeu non")
par = {5: 4, 4: 3, 3: 0, 9: 3}
nom = {5: "cmd.exe", 4: "py.exe", 3: "x.exe", 9: "y.exe"}
verifie(fenetres.descend_de(5, 3, par) and fenetres.descend_de(3, 3, par) and not fenetres.descend_de(9, 4, par),
        "descendance : enfant, soi-même ; le frère n'en descend pas")
verifie(fenetres.chaine(5, par, nom) == "cmd.exe(5) < py.exe(4) < x.exe(3)", "chaîne des parents lisible")
mv, mc, au = fenetres.classer({1: (True, "ConsoleWindowClass", 5, "t"), 2: (False, "IME", 5, ""), 3: (True, "Autre", 9, "j")},
                              4, par, nom)
verifie(len(mv) == 1 and len(mc) == 1 and len(au) == 1 and mv[0]["exe"] == "cmd.exe",
        "classement : visible chez un descendant, cachée chez un descendant, autre processus à part")

# 2. Racine jetable et faux .bat
tmp = tempfile.mkdtemp(prefix="sans fenetre ")
PYW = os.path.join(os.path.dirname(sys.executable), "pythonw.exe")
BAT = ("@echo off\r\nsetlocal\r\nset D=%~dp0fo-autotest\r\nif not exist \"%D%\" mkdir \"%D%\"\r\n"
       "robocopy \"%~dp0\" \"%~dp0cp\" /NFL /NDL /NJH /NJS /NP >nul\r\n"
       "powershell -NoProfile -Command \"(Get-Process -Id $PID).PriorityClass | Out-File -Encoding ascii '%~dp0priorite.txt'\"\r\n"
       "ping -n 2 127.0.0.1 >nul\r\nexit /b 0\r\n")
with open(os.path.join(tmp, "fo-autotest.bat"), "w", newline="") as f:
    f.write(BAT)
env = dict(os.environ, FO_ROOT=tmp)
for k in ("FO_PLACE", "FO_LOCK_HELD", "FO_AUDIO", "FO_BANC_PRIORITE"):
    env.pop(k, None)


def copie_outils(dest, banc_texte=None, sf_texte=None):
    """Copie banc.py (éventuellement modifié) et sans_fenetre.py dans dest."""
    os.makedirs(dest, exist_ok=True)
    shutil.copy2(os.path.join(AUTOTEST, "sans_fenetre.py"), dest)
    shutil.copy2(os.path.join(AUTOTEST, "banc.py"), dest)
    for nom_, txt in (("banc.py", banc_texte), ("sans_fenetre.py", sf_texte)):
        if txt is not None:
            with open(os.path.join(dest, nom_), "w", encoding="utf-8", newline="") as f:
                f.write(txt)
    return os.path.join(dest, "banc.py")


def lire(p):
    with open(p, encoding="utf-8", newline="") as f:
        return f.read()


def cmd_banc(script, python=PYW, place_out="out"):
    return [python, "-B", script, "--out", os.path.join(tmp, place_out), "--qui", "SANS-FENETRE", "--places", "1", "--",
            "100", "faux", tmp]


def mesure(script, python=PYW):
    shutil.rmtree(os.path.join(tmp, "out"), ignore_errors=True)
    code, vis, cach, autres, n, desc = fenetres.mesurer(cmd_banc(script, python), False, 0.8, env=env)
    banc_ecrit = os.path.exists(os.path.join(tmp, "out", "banc.txt"))
    return vis, desc, banc_ecrit


# témoin positif : l'ancien banc.py
r = subprocess.run(["git", "-C", DEPOT, "show", ANCIEN_COMMIT + ":tools/autotest/banc.py"], capture_output=True)
ancien_dir = os.path.join(tmp, "ancien")
os.makedirs(ancien_dir)
with open(os.path.join(ancien_dir, "banc.py"), "wb") as f:
    f.write(r.stdout)
verifie(r.returncode == 0 and b"def elu(" in r.stdout and b"sans_fenetre" not in r.stdout, "ancien banc.py (%s) lu dans git" % ANCIEN_COMMIT)
vis, desc, ecrit = mesure(os.path.join(ancien_dir, "banc.py"))
verifie(ecrit and desc >= 4 and any(v["classe"] == "ConsoleWindowClass" for v in vis),
        "ANCIEN banc.py sans console : une console VISIBLE s'ouvre (témoin positif : %s)"
        % ", ".join("%s/%s" % (v["classe"], v["exe"]) for v in vis))

# nouveau banc.py
vis, desc, ecrit = mesure(os.path.join(AUTOTEST, "banc.py"))
verifie(ecrit and desc >= 4 and not vis, "NOUVEAU banc.py sans console : aucune fenêtre visible, %d processus descendants vus, banc "
        "joué jusqu'à l'archive" % desc)

# 3. Mutants
texte_banc = lire(os.path.join(AUTOTEST, "banc.py"))
texte_sf = lire(os.path.join(AUTOTEST, "sans_fenetre.py"))
m1 = "p = sans_fenetre.run(cmd, env=env, cwd=RACINE"
verifie(texte_banc.count(m1) == 1, "mutant 1 : la ligne du lancement du .bat est reconnue")
script = copie_outils(os.path.join(tmp, "m1"), banc_texte=texte_banc.replace(m1, "p = subprocess.run(cmd, env=env, cwd=RACINE"))
vis, desc, ecrit = mesure(script)
verifie(ecrit and vis, "mutant 1 (banc.py relance subprocess.run) : vu par EnumWindows")
m2 = "return CREATE_NO_WINDOW | (BELOW"
verifie(texte_sf.count(m2) == 1, "mutant 2 : la ligne des drapeaux est reconnue")
# 2a : sans CREATE_NO_WINDOW, le STARTUPINFO SW_HIDE cache encore la console (double ceinture) : invisible à EnumWindows,
# attrapé par le contrôle pur des drapeaux ci-dessus. 2b : options() vide (ni drapeau ni SW_HIDE) : doit être vu.
script = copie_outils(os.path.join(tmp, "m2a"), sf_texte=texte_sf.replace(m2, "return 0 | (BELOW"))
vis, desc, ecrit = mesure(script)
print("INFO mutant 2a (sans CREATE_NO_WINDOW, SW_HIDE gardé) : %d fenêtre(s) visible(s)" % len(vis))
m2b = '    if os.name != "nt":\n        return {}\n    si = subprocess.STARTUPINFO()'
verifie(texte_sf.count(m2b) == 1, "mutant 2b : le début d'options() est reconnu")
script = copie_outils(os.path.join(tmp, "m2b"), sf_texte=texte_sf.replace(m2b, "    return {}\n    si = subprocess.STARTUPINFO()"))
vis, desc, ecrit = mesure(script)
verifie(ecrit and vis, "mutant 2b (options() vide) : vu par EnumWindows")
m3 = "    if not pids_console:\n        return False\n"
verifie(texte_sf.count(m3) == 1, "mutant 3 : la garde de la console est reconnue")
ns = {}
exec(compile(texte_sf.replace(m3, "    if not pids_console:\n        return True\n").replace(
    "        return False\n    return True\n\n\ndef _nom_du_processus", "        return True\n    return True\n\n\ndef _nom_du_processus"),
    "mutant3", "exec"), ns)
verifie(ns["console_a_cacher"]([10, 5], 10, 5, "cmd.exe") is True and ns["console_a_cacher"]([], 10, 5, "py.exe") is True
        and not (cc([10, 5], 10, 5, "cmd.exe") or cc([], 10, 5, "py.exe")),
        "mutant 3 (cache toute console) : les contrôles purs de la console d'un humain l'écartent")

# 4. Priorité vue par le .bat
def priorite(extra=None):
    e = dict(env, **(extra or {}))
    p = os.path.join(tmp, "priorite.txt")
    if os.path.exists(p):
        os.remove(p)
    subprocess.run(cmd_banc(os.path.join(AUTOTEST, "banc.py"), sys.executable), env=e, capture_output=True, timeout=120)
    return lire(p).strip() if os.path.exists(p) else "(absent)"


pr = priorite()
verifie(pr == "BelowNormal", "priorité du .bat lancé par le banc : %s (BelowNormal attendu)" % pr)
pr = priorite({"FO_BANC_PRIORITE": "normal"})
verifie(pr == "Normal", "FO_BANC_PRIORITE=normal : %s (Normal attendu)" % pr)

# 5. Console propre
PROG = ("import os, sys, ctypes\nsys.path.insert(0, %r)\nimport sans_fenetre\n"
        "h = ctypes.windll.kernel32.GetConsoleWindow()\n"
        "avant = bool(h and ctypes.windll.user32.IsWindowVisible(h))\n"
        "rep = sans_fenetre.cacher_ma_console()\n"
        "apres = bool(h and ctypes.windll.user32.IsWindowVisible(h))\n"
        "open(%r, 'w').write('%%d %%d %%d' %% (avant, rep, apres))\n") % (AUTOTEST, os.path.join(tmp, "console.txt"))
prog = os.path.join(tmp, "console_prog.py")
with open(prog, "w") as f:
    f.write(PROG)
sortie = os.path.join(tmp, "console.txt")


def console_de(cmd):
    if os.path.exists(sortie):
        os.remove(sortie)
    subprocess.Popen(cmd, creationflags=0x10, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(100):
        if os.path.exists(sortie) and lire(sortie):
            break
        time.sleep(0.1)
    return lire(sortie).split() if os.path.exists(sortie) else []


seul = console_de([sys.executable, "-B", prog])
verifie(seul == ["1", "1", "0"], "programme sans console : sa console visible est cachée (avant, cachée, après = %s)" % seul)
derriere_cmd = console_de(["cmd", "/c", sys.executable, "-B", prog])
verifie(derriere_cmd == ["1", "0", "1"],
        "même programme derrière un cmd (terminal d'un humain) : console laissée visible (%s)" % derriere_cmd)
shutil.rmtree(tmp, ignore_errors=True)

print("BILAN : %d OK, %d ECHEC(S)" % (ok, ko))
sys.exit(1 if ko else 0)
