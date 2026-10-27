# Tour de rôle de la file du banc (tools/autotest/banc.py, 27/10) : règle pure, puis vrais lanceurs sur une racine
# jetable (FO_ROOT) avec un faux fo-autotest.bat qui note l'ordre de passage. Aucun jeu lancé, aucun verrou réel touché.
#   py -3.9 -B tools/autotest/tests/test_banc_file.py   -> BILAN : n OK
import os
import shutil
import subprocess
import sys
import tempfile
import time

ICI = os.path.dirname(os.path.abspath(__file__))
BANC = os.path.join(os.path.dirname(ICI), "banc.py")
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


# 1. Règle pure (import avec une racine jetable : RACINE est lue à l'import).
tmp = tempfile.mkdtemp(prefix="banc_file_")
os.environ["FO_ROOT"] = tmp
sys.path.insert(0, os.path.dirname(BANC))
import banc  # noqa: E402

lots = {"1-a": "A", "2-a": "A", "3-b": "B", "4-a": "A", "5-c": "C"}
servi = {"A": 100.0, "B": 0.0, "C": 50.0}
verifie(banc.elu([], lots.get, servi.get) is None, "file vide : personne")
verifie(banc.elu(["1-a", "2-a"], lots.get, servi.get) == "1-a", "un seul lot : premier arrivé")
verifie(banc.elu(sorted(lots), lots.get, servi.get) == "3-b", "lot jamais servi d'abord, même arrivé après")
servi["B"] = 200.0
verifie(banc.elu(sorted(lots), lots.get, servi.get) == "5-c", "puis le lot servi il y a le plus longtemps")
servi.update(A=10.0, C=300.0)
verifie(banc.elu(sorted(lots), lots.get, servi.get) == "1-a", "dans un lot : son plus ancien ticket")
servi.update(A=0.0, B=0.0, C=0.0)
verifie(banc.elu(sorted(lots), lots.get, servi.get) == "1-a", "égalité : le plus ancien ticket")
verifie(banc.nom_de_lot("IA-V2 / x") == "IA-V2___x", "nom de fichier du lot sans caractère interdit")

# 2. Vrais lanceurs : A1 tient le banc ; pendant ce temps A2, A3 (lot A) puis B1 (lot B) arrivent.
# Attendu : A1, B1, A2, A3 (en premier arrivé, premier servi : A1, A2, A3, B1).
with open(os.path.join(tmp, "fo-autotest.bat"), "w", newline="\r\n") as f:
    f.write("@echo off\necho %3>> \"%~dp0ordre.txt\"\nping -n 5 127.0.0.1 >nul\nexit /b 0\n")
env = dict(os.environ, FO_ROOT=tmp)


def lancer(nom, qui):
    return subprocess.Popen([sys.executable, "-B", BANC, "--out", os.path.join(tmp, "out", nom), "--qui", qui,
                             "--", "10", nom, tmp], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


procs = [lancer("A1", "A")]
time.sleep(2.5)
for nom, qui in (("A2", "A"), ("A3", "A"), ("B1", "B")):
    procs.append(lancer(nom, qui))
    time.sleep(0.4)
codes = [p.wait(timeout=180) for p in procs]
verifie(codes == [0, 0, 0, 0], f"4 lanceurs finis, code 0 ({codes})")
with open(os.path.join(tmp, "ordre.txt")) as f:
    ordre = [l.strip() for l in f if l.strip()]
verifie(ordre == ["A1", "B1", "A2", "A3"], f"ordre de passage A1, B1, A2, A3 ({', '.join(ordre)})")
verifie(not os.path.isdir(os.path.join(tmp, "fo-autotest.lock")), "verrou rendu")
verifie(not [n for n in os.listdir(os.path.join(tmp, "fo-banc-file")) if n.endswith(".txt")], "aucun ticket restant")
verifie(sorted(os.listdir(os.path.join(tmp, "fo-banc-file", "servis"))) == ["A", "B"], "services notés par lot")

# 3. Un lot tenu par une ancienne version (owner.txt sans service noté) compte comme servi.
os.mkdir(os.path.join(tmp, "fo-autotest.lock"))
with open(os.path.join(tmp, "fo-autotest.lock", "owner.txt"), "w") as f:
    f.write(f"{os.getpid()} IA ancien 27/10 03:44:44\n")
banc.observer_verrou()
verifie(banc.dernier_service("IA ancien") > time.time() - 60, "verrou d'une ancienne version : service noté")
shutil.rmtree(os.path.join(tmp, "fo-autotest.lock"))

shutil.rmtree(tmp, ignore_errors=True)
print(f"BILAN : {ok} OK" + (f", {ko} ECHEC(S)" if ko else ""))
sys.exit(1 if ko else 0)
