# File du banc (tools/autotest/banc.py, 27/10) : règles pures (tour de rôle, affectation des places, nombre de places),
# puis vrais lanceurs sur une racine jetable (FO_ROOT, chemin avec une espace) avec un faux fo-autotest.bat et un faux
# fo-captures.bat qui notent, pour chaque banc, les bancs actifs au début et à la fin (preuve du chevauchement) et les
# verrous présents. Aucun jeu lancé, aucun verrou réel touché. Lot BANC2 : plusieurs places (1 à 3), tickets « place 1 »
# (images) et « seul » (K10), garde-fou mémoire, passage de 3 à 1 place en cours de route, cohabitation avec l'ANCIEN
# banc.py (lu dans git, commit aeb03ba).
#   PYTHONUTF8=1 py -3.9 -B tools/autotest/tests/test_banc_file.py   -> BILAN : n OK
import os
import shutil
import subprocess
import sys
import tempfile
import time

ICI = os.path.dirname(os.path.abspath(__file__))
BANC = os.path.join(os.path.dirname(ICI), "banc.py")
DEPOT = os.path.dirname(os.path.dirname(os.path.dirname(ICI)))
ANCIEN_COMMIT = "aeb03ba"
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


# 1. Règles pures (import avec une racine jetable : RACINE est lue à l'import).
tmp = tempfile.mkdtemp(prefix="banc file ")
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
servi.update(A=10.0, B=30.0, C=20.0)
verifie(banc.classement(sorted(lots), lots.get, servi.get) == ["1-a", "5-c", "3-b"],
        "classement : un ticket par lot (le plus ancien), lots par dernier service")

G = {"o1": "ordinaire", "o2": "ordinaire", "o3": "ordinaire", "p": "place1", "p2": "place1", "s": "seul"}


def aff(rangs, libres, n=3, mem=True, lim=None):
    return banc.affecter(rangs, G.get, set(libres), n, mem, (lambda t: lim.get(t, 3)) if lim else (lambda t: 3))


verifie(aff([], {1, 2, 3}) == {}, "affectation : file vide, personne")
verifie(aff(["o1", "o2", "o3"], {1, 2, 3}) == {"o1": [1], "o2": [2]},
        "3 ordinaires, 3 places libres : place 1, puis UNE seule place en plus par tour")
verifie(aff(["o1", "o2"], {1, 2, 3}, mem=False) == {"o1": [1]}, "mémoire basse : place 1 seulement")
verifie(aff(["o1", "o2"], {1, 2, 3}, n=1) == {"o1": [1]}, "1 place ouverte : place 1 seulement")
verifie(aff(["o1", "o2"], {2, 3}, n=1) == {}, "1 place ouverte, place 1 prise : personne (places 2 et 3 fermées)")
verifie(aff(["p", "o1"], {2, 3}) == {"o1": [2]},
        "images en tête, place 1 prise : elles l'attendent, l'ordinaire part à la place 2")
verifie(aff(["o1", "p"], {1, 2, 3}) == {"o1": [2], "p": [1]},
        "ordinaire devant des images : il prend la place 2 et laisse la place 1 aux images")
verifie(aff(["o1", "p"], {1}) == {"o1": [1]}, "ordinaire devant des images, seule la place 1 libre : l'ordinaire (rang)")
verifie(aff(["o1", "p"], {1, 2}, mem=False) == {"o1": [1]}, "idem sans mémoire pour une place de plus")
verifie(aff(["p", "o1"], {1, 2, 3}) == {"p": [1], "o1": [2]}, "images en tête, tout libre : place 1 et place 2")
verifie(aff(["p", "p2", "o1"], {1, 2, 3}) == {"p": [1], "o1": [2]},
        "deux tickets d'images : le premier seul prend la place 1, l'ordinaire part ailleurs")
verifie(aff(["p", "p2", "o1"], {2, 3}) == {"o1": [2]}, "place 1 prise, réservée au premier ticket d'images")
verifie(aff(["s", "o1"], {1, 2, 3}) == {"s": [1, 2, 3]}, "seul en tête, tout libre : toutes les places")
verifie(aff(["s", "o1"], {1, 3}) == {}, "seul en tête, une place prise : BARRIÈRE, personne ne part")
verifie(aff(["o1", "s", "o2"], {1, 2, 3}) == {"o1": [1]}, "ordinaire devant un seul : il part ; rien derrière le seul")
verifie(aff(["o1", "s", "p"], {1, 2, 3}) == {"o1": [1]}, "images derrière un seul : la barrière les arrête aussi")
verifie(aff(["o1", "o2"], {2, 3}, lim={"o1": 1}) == {"o2": [2]}, "--places 1 : ce ticket ne prend jamais la place 2")
verifie(aff(["o1"], {1, 2}, lim={"o1": 1}) == {"o1": [1]}, "--places 1 : place 1 libre, il part")
verifie(aff(["o1", "o2"], {3}, n=3) == {"o1": [3]}, "seule la place 3 libre : prise")
verifie(aff(["o1", "o2"], {3}, n=2) == {}, "place 3 libre mais 2 places ouvertes : personne")

with open(banc.FICHIER_PLACES, "w") as f:
    f.write("3\n")
verifie(banc.lire_places(None) == 1 and banc.lire_places(3) == 1,
        "pas de fo-autotest.bat à la racine : 1 place, --places 3 compris")
with open(os.path.join(tmp, "fo-autotest.bat"), "w", newline="\r\n") as f:
    f.write("@echo off\nrem ancien banc, sans place\nexit /b 0\n")
verifie(banc.lire_places(None) == 1 and banc.lire_places(3) == 1,
        "fo-autotest.bat d'avant BANC2 (sans FO_PLACE) à la racine : 1 place (déploiement dans le mauvais ordre)")
with open(os.path.join(tmp, "fo-autotest.bat"), "w", newline="\r\n") as f:
    f.write("@echo off\nif \"%FO_PLACE%\"==\"2\" rem place 2\nexit /b 0\n")
verifie(banc.lire_places(None) == 3, "fo-autotest.bat qui connaît FO_PLACE : le fichier compte (3)")
os.remove(banc.FICHIER_PLACES)
verifie(banc.places_ouvertes(None, None) == 2, "fo-banc-places.txt absent : 2 places")
verifie([banc.places_ouvertes(None, x) for x in ("1", "2", "3\r\n", " 3 ")] == [1, 2, 3, 3], "fichier « 1 » à « 3 »")
verifie([banc.places_ouvertes(None, x) for x in ("0", "4", "03", "deux", "", "3 places", "-1")] == [1] * 7,
        "fichier hors de 1 à 3 ou illisible : 1 place")
verifie(banc.places_ouvertes(3, "1") == 3 and banc.places_ouvertes(1, None) == 1, "--places prioritaire sur le fichier")
verifie(banc.lire_places(None) == 2, "lire_places : fichier absent, 2")
for contenu, attendu in ((b"3\r\n", 3), (b"7", 1), (b"\xff\xfe\x00", 1)):
    with open(banc.FICHIER_PLACES, "wb") as f:
        f.write(contenu)
    verifie(banc.lire_places(None) == attendu and banc.lire_places(2) == 2,
            "lire_places : fichier %r -> %d, --places 2 -> 2" % (contenu, attendu))
os.remove(banc.FICHIER_PLACES)
verifie(banc.genre_du_texte("IA : content 4000 (27/10 09:00:00)") == ("place1", 1),
        "ticket d'un ANCIEN lanceur : genre « place 1 », limite 1 (il ne connaît que fo-autotest.lock)")
verifie(banc.genre_du_texte("X : s 1 (d) [banc2 ordinaire 3]") == ("ordinaire", 3)
        and banc.genre_du_texte("X : s 1 (d) [banc2 seul 1]\n") == ("seul", 1)
        and banc.lot_du_texte("X : s 1 (d) [banc2 seul 1]") == "X", "marque [banc2 genre limite] lue, lot inchangé")
m = banc.memoire_libre_go()
verifie(0 < m < 4096, "mémoire libre lue par GlobalMemoryStatusEx : %.1f Go" % m)
verifie([os.path.basename(banc.verrou(p)) for p in banc.PLACES] == ["fo-autotest.lock", "fo-autotest-2.lock",
                                                                    "fo-autotest-3.lock"]
        and banc.VERROU == os.path.join(tmp, "fo-autotest.lock"), "verrous des places 1 à 3 (place 1 : celui d'avant)")

# 2. Faux .bat : chaque banc note les bancs actifs à son début et à sa fin, et les verrous présents.
FAUX_BAT = r"""@echo off
setlocal
set NOM=%3
set D=%~dp0fo-autotest
if not "%FO_PLACE%"=="" set D=%~dp0fo-autotest-%FO_PLACE%
if /i "%FAKE_MODE%"=="crash" exit /b 3221225794
if /i "%FAKE_MODE%"=="muet" exit /b 0
echo %3>> "%~dp0ordre.txt"
if not exist "%~dp0actifs" mkdir "%~dp0actifs" 2>nul
> "%~dp0actifs\%NOM%" echo %NOM%
> "%~dp0trace-%NOM%.txt" echo debut
for %%f in ("%~dp0actifs\*") do if /i not "%%~nxf"=="%NOM%" >> "%~dp0trace-%NOM%.txt" echo avec %%~nxf
for %%v in (fo-autotest.lock fo-autotest-2.lock fo-autotest-3.lock) do if exist "%~dp0%%v\owner.txt" >> "%~dp0trace-%NOM%.txt" echo verrou %%v
if exist "%D%" rmdir /s /q "%D%"
mkdir "%D%"
> "%D%\place.txt" echo %NOM% FO_PLACE[%FO_PLACE%] FO_LOCK_HELD[%FO_LOCK_HELD%] FO_AUDIO[%FO_AUDIO%]
ping -n %2 127.0.0.1 >nul
> "%D%\create.log" echo cree %NOM%
> "%D%\benchmark.log" echo [FO-%NOM%] BILAN : 1 OK, 0 ECHEC(S)
> "%D%\benchmark-stdout.txt" echo t1,0,0,
if /i not "%FAKE_MODE%"=="interrompu" >> "%D%\benchmark-stdout.txt" echo   Performed 1 updates in 1.000 ms
> "%D%\done.txt" echo termine
for %%f in ("%~dp0actifs\*") do if /i not "%%~nxf"=="%NOM%" >> "%~dp0trace-%NOM%.txt" echo avec %%~nxf
del "%~dp0actifs\%NOM%"
>> "%~dp0trace-%NOM%.txt" echo fin
exit /b 0
"""
FAUX_CAPTURES = r"""@echo off
setlocal
> "%~dp0captures-%1.txt" echo %1 FO_PLACE[%FO_PLACE%] FO_LOCK_HELD[%FO_LOCK_HELD%]
call "%~dp0fo-autotest.bat" nopause %FAKE_CAPTURES_S% %1 %2
exit /b %errorlevel%
"""
for nom, texte in (("fo-autotest.bat", FAUX_BAT), ("fo-captures.bat", FAUX_CAPTURES)):
    with open(os.path.join(tmp, nom), "w", newline="\r\n") as f:
        f.write(texte)
env = dict(os.environ, FO_ROOT=tmp)
for k in ("FO_PLACE", "FO_LOCK_HELD", "FO_AUDIO"):
    env.pop(k, None)
ancien = os.path.join(tmp, "ancien", "banc.py")
os.makedirs(os.path.dirname(ancien))
r = subprocess.run(["git", "-C", DEPOT, "show", ANCIEN_COMMIT + ":tools/autotest/banc.py"], capture_output=True)
with open(ancien, "wb") as f:
    f.write(r.stdout)
verifie(r.returncode == 0 and b"def elu(" in r.stdout and b"PLACES" not in r.stdout,
        "ancien banc.py (%s) lu dans git pour la cohabitation" % ANCIEN_COMMIT)


def lancer(nom, qui, secondes, *opts, script=BANC, extra=None):
    e = dict(env, **(extra or {}))
    return subprocess.Popen([sys.executable, "-B", script, "--out", os.path.join(tmp, "out", nom), "--qui", qui]
                            + list(opts) + ["--", str(secondes + 1), nom, tmp],
                            env=e, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def lignes(p):
    try:
        with open(p, errors="replace") as f:
            return [l.strip() for l in f if l.strip()]
    except OSError:
        return []


def trace(nom):
    return lignes(os.path.join(tmp, "trace-%s.txt" % nom))


def avec(nom):
    return {l.split(" ", 1)[1] for l in trace(nom) if l.startswith("avec ")}


def ensemble(a, b):
    """Vrai si les bancs a et b ont tourné en même temps (l'un a vu l'autre actif à son début ou à sa fin)."""
    return b in avec(a) or a in avec(b)


def banc_txt(nom):
    d = {}
    for l in lignes(os.path.join(tmp, "out", nom, "banc.txt")):
        if l.startswith("place "):
            for morceau in l.split(" ; "):
                k, _, v = morceau.partition(" ")
                d[k] = v
    return d


def place_de(nom):
    try:
        return int(banc_txt(nom).get("place", "0"))
    except ValueError:
        return 0


def archive_juste(nom, place):
    """place.txt archivé : écrit par CE banc, dans le dossier de SA place (FO_PLACE et FO_LOCK_HELD de la place)."""
    l = lignes(os.path.join(tmp, "out", nom, "place.txt"))
    attendu = "%s FO_PLACE[%s] FO_LOCK_HELD[%d]" % (nom, "" if place == 1 else place, place)
    return bool(l) and l[0].startswith(attendu)


def attendre(procs, delai=240):
    return [p.wait(timeout=delai) for p in procs]


def attendre_debut(noms, delai=30):
    t = time.time()
    while time.time() - t < delai:
        if all(trace(n) for n in noms):
            return True
        time.sleep(0.2)
    return False


def places(n):
    with open(os.path.join(tmp, "fo-banc-places.txt"), "w") as f:
        f.write("%d\n" % n)


MEM = ("--memoire-min-go", "0.5")

# 3. Une place (--places 1) : A1 tient le banc ; A2, A3 (lot A) puis B1 (lot B) arrivent.
# Attendu : A1, B1, A2, A3 (en premier arrivé, premier servi : A1, A2, A3, B1), aucun chevauchement.
procs = [lancer("A1", "A", 4, "--places", "1")]
time.sleep(2.5)
for nom, qui in (("A2", "A"), ("A3", "A"), ("B1", "B")):
    procs.append(lancer(nom, qui, 4, "--places", "1"))
    time.sleep(0.4)
codes = attendre(procs)
verifie(codes == [0, 0, 0, 0], f"--places 1 : 4 lanceurs finis, code 0 ({codes})")
ordre = lignes(os.path.join(tmp, "ordre.txt"))
verifie(ordre == ["A1", "B1", "A2", "A3"], f"--places 1 : ordre de passage A1, B1, A2, A3 ({', '.join(ordre)})")
verifie(all(place_de(n) == 1 and archive_juste(n, 1) and not avec(n) for n in ("A1", "A2", "A3", "B1")),
        "--places 1 : tous à la place 1 (FO_LOCK_HELD=1, sans FO_PLACE), jamais deux à la fois")
verifie(not os.path.isdir(os.path.join(tmp, "fo-autotest.lock")), "verrou rendu")
verifie(not [n for n in os.listdir(os.path.join(tmp, "fo-banc-file")) if n.endswith(".txt")], "aucun ticket restant")
verifie(sorted(os.listdir(os.path.join(tmp, "fo-banc-file", "servis"))) == ["A", "B"], "services notés par lot")

# 4. Un lot tenu par une ancienne version (owner.txt sans service noté) compte comme servi.
os.mkdir(os.path.join(tmp, "fo-autotest.lock"))
with open(os.path.join(tmp, "fo-autotest.lock", "owner.txt"), "w") as f:
    f.write(f"{os.getpid()} IA ancien 27/10 03:44:44\n")
banc.observer_verrou()
verifie(banc.dernier_service("IA ancien") > time.time() - 60, "verrou d'une ancienne version : service noté")
verifie(banc.etat_place(1)[2] == "inconnu" and banc.etat_place(2) is None,
        "verrou sans banc2.txt (ancien lanceur) : place 1 occupée, mode inconnu")
shutil.rmtree(os.path.join(tmp, "fo-autotest.lock"))

# 5. Trois places : C1, D1, E1 (trois lots) tournent EN MÊME TEMPS ; puis le fichier passe à 1 place pendant qu'ils
# tournent : F1 et G1, déposés ensuite, ne partent qu'à la place 1, l'un après l'autre.
places(3)
procs = [lancer(n, "L" + n, 8, *MEM) for n in ("C1", "D1", "E1")]
verifie(attendre_debut(["C1", "D1", "E1"]), "3 places : les 3 bancs ont démarré")
places(1)
time.sleep(0.5)
procs += [lancer("F1", "LF1", 2, *MEM)]
time.sleep(0.6)
procs += [lancer("G1", "LG1", 2, *MEM)]
codes = attendre(procs)
verifie(codes == [0] * 5, f"3 places puis 1 : 5 lanceurs finis, code 0 ({codes})")
trois = ["C1", "D1", "E1"]
verifie(sorted(place_de(n) for n in trois) == [1, 2, 3], "C1, D1, E1 : places 1, 2 et 3 (%s)" %
        [place_de(n) for n in trois])
verifie(ensemble("C1", "D1") and ensemble("C1", "E1") and ensemble("D1", "E1"),
        "C1, D1, E1 ont tourné EN MÊME TEMPS (chaque banc a vu les deux autres actifs)")
verifie(all(archive_juste(n, place_de(n)) for n in trois),
        "archive de chaque place : place.txt du bon dossier (fo-autotest, fo-autotest-2, fo-autotest-3)")
verifie(all(banc_txt(n).get("dossier", "").endswith(os.path.basename(banc.dossier(place_de(n)))) for n in trois),
        "banc.txt : dossier de la place utilisée")
un = [n for n in trois if place_de(n) == 1][0]
verifie(place_de("F1") == 1 and place_de("G1") == 1 and archive_juste("F1", 1) and archive_juste("G1", 1),
        "passage à 1 place : F1 et G1 à la place 1 seulement, aucun nouveau départ aux places 2 et 3")
verifie(not ensemble("F1", "G1") and not ensemble("F1", un) and not ensemble("G1", un),
        "passage à 1 place : F1 et G1 l'un après l'autre, après le banc de la place 1")

# 6. Images à la place 1 pendant que deux bancs sans images tournent aux places 2 et 3 (correction de 9 h : les
# captures ne prennent QUE la place 1).
places(3)
procs = [lancer("P1", "LP1", 0, "--captures", *MEM, extra={"FAKE_CAPTURES_S": "8"})]
time.sleep(0.8)
procs += [lancer("Q1", "LQ1", 5, *MEM)]
time.sleep(0.6)
procs += [lancer("R1", "LR1", 5, *MEM)]
codes = attendre(procs)
verifie(codes == [0, 0, 0], f"images et 2 bancs : 3 lanceurs finis, code 0 ({codes})")
cap = lignes(os.path.join(tmp, "captures-P1.txt"))
verifie(place_de("P1") == 1 and cap == ["P1 FO_PLACE[] FO_LOCK_HELD[1]"] and archive_juste("P1", 1)
        and banc_txt("P1").get("verrous") == "1",
        "--captures : fo-captures.bat à la place 1 (FO_LOCK_HELD=1, sans FO_PLACE), seul verrou tenu : la place 1")
verifie(sorted([place_de("Q1"), place_de("R1")]) == [2, 3] and ensemble("P1", "Q1") and ensemble("P1", "R1")
        and ensemble("Q1", "R1"), "Q1 et R1 aux places 2 et 3 PENDANT la session avec images")

# 7. Images en attente de la place 1 : elles ne retiennent pas les bancs ordinaires, et sont servies dès que la
# place 1 se libère (K1, ordinaire déposé après elles, ne la leur prend pas).
procs = [lancer("H1", "LH1", 7, *MEM)]
time.sleep(1.5)
procs += [lancer("P2", "LP2", 0, "--captures", *MEM, extra={"FAKE_CAPTURES_S": "2"})]
time.sleep(0.6)
procs += [lancer("I1", "LI1", 2, *MEM)]
time.sleep(0.6)
procs += [lancer("J1", "LJ1", 2, *MEM)]
time.sleep(0.6)
procs += [lancer("K1", "LK1", 2, *MEM)]
codes = attendre(procs)
verifie(codes == [0] * 5, f"images en attente : 5 lanceurs finis, code 0 ({codes})")
verifie(place_de("H1") == 1 and place_de("P2") == 1 and not ensemble("H1", "P2"),
        "images en attente : P2 à la place 1, après H1")
verifie(place_de("I1") in (2, 3) and place_de("J1") in (2, 3) and ensemble("H1", "I1") and ensemble("H1", "J1"),
        "images en attente : I1 et J1, déposés après elles, partent aux places 2 et 3 sans les attendre")
verifie(place_de("K1") in (2, 3) and float(banc_txt("P2").get("prise", "0")) > 0
        and float(banc_txt("P2").get("prise", "0")) < float(banc_txt("H1").get("fin", "0") or 0) + 3.5,
        "images en attente : K1 ne prend pas la place 1, P2 part moins de 3,5 s après la fin de H1")

# 8. Ticket « seul » (--seul, K10) : il attend que TOUTES les places soient libres, rien ne part derrière lui, il
# tourne seul avec les 3 verrous, puis la file reprend.
procs = [lancer("L1", "LL1", 5, *MEM)]
time.sleep(1.5)
procs += [lancer("X1", "LX1", 2, "--seul", *MEM)]
time.sleep(0.6)
procs += [lancer("M1", "LM1", 2, *MEM)]
codes = attendre(procs)
verifie(codes == [0, 0, 0], f"seul : 3 lanceurs finis, code 0 ({codes})")
tx = trace("X1")
verifie(place_de("X1") == 1 and banc_txt("X1").get("verrous") == "1 2 3"
        and all("verrou %s" % os.path.basename(banc.verrou(p)) in tx for p in banc.PLACES),
        "seul : place 1, les 3 verrous tenus pendant son banc")
verifie(not avec("X1") and not ensemble("X1", "L1") and not ensemble("X1", "M1"), "seul : personne en même temps")
verifie(not ensemble("M1", "L1") and float(banc_txt("M1").get("prise", "0")) > float(banc_txt("X1").get("fin", "9e9")),
        "seul : M1 (déposé après lui) attend derrière la barrière, places 2 et 3 libres comprises")

# 9. Garde-fou mémoire : sous le seuil, aucune place au-delà de la première.
procs = [lancer("N1", "LN1", 2, "--memoire-min-go", "100000")]
time.sleep(0.6)
procs += [lancer("O1", "LO1", 2, "--memoire-min-go", "100000")]
codes = attendre(procs)
verifie(codes == [0, 0] and place_de("N1") == 1 and place_de("O1") == 1 and not ensemble("N1", "O1"),
        "mémoire sous le seuil : N1 puis O1, à la place 1 seulement")

# 10. Cohabitation avec un ANCIEN banc.py en attente (il ne connaît que fo-autotest.lock) : V1 (nouveau) tient la
# place 1 ; W1 (ANCIEN) arrive, puis Y1 et Z1 (nouveaux). W1 compte comme un ticket « place 1 » : Y1 et Z1 partent
# aux places 2 et 3 sans l'attendre ; W1 part à la place 1 après V1, jamais en même temps qu'elle.
procs = [lancer("V1", "LV1", 6, *MEM)]
time.sleep(1.5)
procs += [lancer("W1", "LW1", 2, script=ancien)]
time.sleep(1.0)
procs += [lancer("Y1", "LY1", 2, *MEM)]
time.sleep(0.6)
procs += [lancer("Z1", "LZ1", 2, *MEM)]
codes = attendre(procs)
verifie(codes == [0] * 4, f"cohabitation : 4 lanceurs finis, code 0 ({codes})")
w = lignes(os.path.join(tmp, "out", "W1", "place.txt"))
verifie(bool(w) and w[0].startswith("W1 FO_PLACE[] FO_LOCK_HELD[1]") and not ensemble("W1", "V1"),
        "cohabitation : l'ancien lanceur tourne à la place 1, après V1, jamais en même temps")
verifie(place_de("Y1") in (2, 3) and place_de("Z1") in (2, 3) and ensemble("V1", "Y1") and ensemble("V1", "Z1"),
        "cohabitation : Y1 et Z1 aux places 2 et 3 pendant que l'ancien attend la place 1")

# 10. Archive ÉCHEC (28/10) : un jeu qui plante ou ne répond pas laissait les journaux PÉRIMÉS du banc précédent, archivés comme
# les siens. Faux .bat : "crash" (code d'échec sans rien écrire : cmd tronque 3221225794 à -1), "muet" (code 0 sans rien écrire), "interrompu" (écrit tout, sans
# la ligne « Performed »). Le dossier de la place contient d'abord les fichiers d'un autre lot (vieux, ou récents mais inchangés).
import gzip  # noqa: E402


def planter(vieux):
    d = os.path.join(tmp, "fo-autotest")
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    t = time.time() - 3600 if vieux else time.time() + 30  # « récent » : l'heure du fichier passe pour fraîche
    for n, txt in (("done.txt", "termine AUTRE"), ("benchmark.log", "[FO-AUTRE] BILAN : 99 OK, 0 ECHEC(S)"),
                   ("create.log", "cree AUTRE"), ("benchmark-stdout.txt", "t1,\n  Performed 99 updates in 1 ms\n")):
        with open(os.path.join(d, n), "w") as fh:
            fh.write(txt)
        os.utime(os.path.join(d, n), (t, t))


def echec(nom, mode, vieux=True):
    planter(vieux)
    p = lancer(nom, "ECH", 1, "--places", "1", extra={"FAKE_MODE": mode} if mode else None)
    code = p.wait(timeout=120)
    sortie = p.stdout.read().decode("utf-8", "replace")
    out = os.path.join(tmp, "out", nom)
    texte = "".join(lignes(os.path.join(out, "ECHEC.txt"))) if os.path.exists(os.path.join(out, "ECHEC.txt")) else None
    return code, out, texte, sortie


code, out, texte, sortie = echec("E_crash", "crash")
verifie(code not in (0, 12) and texte is not None and "code de sortie" in texte and "PÉRIMÉ" in texte,
        f"jeu planté : code {code} rendu, ECHEC.txt écrit, journaux périmés signalés")
verifie(not os.path.exists(os.path.join(out, "benchmark.log.gz")) and not os.path.exists(os.path.join(out, "done.txt"))
        and not os.path.exists(os.path.join(out, "create.log")),
        "jeu planté : AUCUN journal périmé archivé (une partie plantée ne se lit pas comme celle d'un autre lot)")
verifie("ECHEC DU BANC" in sortie, "jeu planté : l'échec est dit sur la sortie du lanceur")
code, out, texte, sortie = echec("E_muet", "muet")
verifie(code == 12 and texte is not None and "done.txt PÉRIMÉ" in texte, f"jeu muet (code 0, rien écrit) : code 12 rendu ({code}), ECHEC.txt")
verifie(not os.path.exists(os.path.join(out, "benchmark.log.gz")), "jeu muet : journal périmé non archivé")
code, out, texte, sortie = echec("E_recent", "muet", vieux=False)
verifie(code == 12 and texte is not None and not os.path.exists(os.path.join(out, "benchmark.log.gz")),
        "journal périmé mais RÉCENT (heure future) : reconnu par sa signature inchangée, code 12")
code, out, texte, sortie = echec("E_interrompu", "interrompu")
verifie(code == 12 and texte is not None and "interrompu" in texte and os.path.exists(os.path.join(out, "benchmark.log.gz")),
        "benchmark interrompu (pas de ligne Performed) : code 12, ECHEC.txt, journaux frais archivés pour le diagnostic")
code, out, texte, sortie = echec("E_ok", None)
verifie(code == 0 and texte is None and os.path.exists(os.path.join(out, "benchmark.log.gz"))
        and "AUTRE" not in gzip.open(os.path.join(out, "benchmark.log.gz"), "rt").read(),
        "banc normal : code 0, pas de ECHEC.txt, journaux frais (pas ceux du lot précédent)")
# règle pure
d = os.path.join(tmp, "diag")
os.makedirs(d)
for n in banc.FICHIERS_BANC:
    with open(os.path.join(d, n), "w") as fh:
        fh.write("x")
    os.utime(os.path.join(d, n), (1000.0, 1000.0))
sig = banc.signature(d)
pb, per = banc.diagnostic(d, 2000.0, sig, 0, fin=lambda p: True)
verifie(len(pb) == 4 and per == set(banc.FICHIERS_BANC), "diagnostic : 4 fichiers périmés, 4 problèmes")
for n in banc.FICHIERS_BANC:
    os.utime(os.path.join(d, n), (2500.0, 2500.0))
pb, per = banc.diagnostic(d, 2000.0, sig, 0, fin=lambda p: True)
verifie(pb == [] and per == set(), "diagnostic : fichiers plus récents que le lancement, tout va bien")
pb, per = banc.diagnostic(d, 2000.0, sig, 5, fin=lambda p: True)
verifie(len(pb) == 1 and "code de sortie 5" in pb[0], "diagnostic : code non nul seul = un problème")
pb, per = banc.diagnostic(d, 2000.0, sig, 0, captures=True, fin=lambda p: False)
verifie(pb == [], "diagnostic : captures, pas de contrôle de benchmark")
os.remove(os.path.join(d, "done.txt"))
pb, per = banc.diagnostic(d, 2000.0, sig, 0, fin=lambda p: True)
verifie(len(pb) == 1 and "done.txt absent" in pb[0], "diagnostic : done.txt absent")
pb, per = banc.diagnostic(os.path.join(tmp, "nexistepas"), 2000.0, {}, 0, fin=lambda p: True)
verifie(len(pb) == 4, "diagnostic : dossier de la place absent = 4 fichiers absents")
# fin_de_benchmark (28/10 : faux ECHEC code 12 sur les longues parties) : « Performed » est AVANT le tableau CSV par tick
# (plus de 1 Mo), pas dans les 64 derniers Ko ; une ligne coupée par la frontière d'un bloc est aussi trouvée.
gros = os.path.join(tmp, "gros-stdout.txt")
with open(gros, "wb") as fh:
    fh.write(b"debut\nPerformed 216300 updates in 145348 ms\n" + b"t1,12345,6789\n" * 200000)
verifie(banc.fin_de_benchmark(gros), "fin_de_benchmark : « Performed » au début d'un fichier de plus de 2 Mo est trouvé")
coupe = os.path.join(tmp, "coupe-stdout.txt")
with open(coupe, "wb") as fh:
    fh.write(b"x" * ((1 << 20) - 4) + b"Performed 5 updates\n" + b"y" * 3000)
verifie(banc.fin_de_benchmark(coupe), "fin_de_benchmark : « Performed » coupé par la frontière d'un bloc de 1 Mo est trouvé")
vide = os.path.join(tmp, "sans-stdout.txt")
with open(vide, "wb") as fh:
    fh.write(b"t1,12345,6789\n" * 200000)
verifie(not banc.fin_de_benchmark(vide), "fin_de_benchmark : fichier sans « Performed » (jeu interrompu) = faux")
verifie(not banc.fin_de_benchmark(os.path.join(tmp, "absent-stdout.txt")), "fin_de_benchmark : fichier absent = faux")

# 11. Rien ne reste.
reste = [d for d in os.listdir(tmp) if d.endswith(".lock")]
verifie(reste == [], f"aucun verrou restant ({reste})")
f = os.path.join(tmp, "fo-banc-file")
reste = [n for n in os.listdir(f) if n.endswith(".txt") or n.startswith(("prise-", "rendu-"))]
verifie(reste == [], f"aucun ticket ni dossier de prise restant ({reste})")
sortie = subprocess.run([sys.executable, "-B", BANC, "--file"], env=env, capture_output=True, text=True,
                        encoding="utf-8", errors="replace").stdout
verifie("places ouvertes : 3" in sortie and sortie.count(": libre") == 3, "--file : places ouvertes et places libres")

shutil.rmtree(tmp, ignore_errors=True)
print(f"BILAN : {ok} OK" + (f", {ko} ECHEC(S)" if ko else ""))
sys.exit(1 if ko else 0)
