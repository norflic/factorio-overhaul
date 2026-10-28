# Banc en moteur réel AVEC FILE D'ATTENTE (orchestrateur, 27/10) : à utiliser par TOUS les agents à la place d'un appel
# direct à fo-autotest.bat ou fo-captures.bat.
#
# Pourquoi : le 25/10, cinq agents ont sondé le verrou fo-autotest.lock chacun à son rythme ; une chaîne de bancs le
# reprenait dès qu'il se libérait (45 min sans l'obtenir pour d'autres agents), et un banc a effacé fo-autotest\ AVANT
# que le précédent n'ait archivé ses journaux (le verrou était rendu par le .bat, l'archivage se faisait après).
#
# PLUSIEURS PLACES (lot BANC2, 27/10 vers 9 h ; accord du DC à 8 h 50 : « au pire ça rame mais c'est pas grave ») :
#   place 1 : dossier <racine>\fo-autotest,   verrou fo-autotest.lock   (celui d'avant, partagé avec fo-captures.bat
#             et fo-visual.bat : les images ne tournent QU'À la place 1) ;
#   place 2 : dossier <racine>\fo-autotest-2, verrou fo-autotest-2.lock (fo-autotest.bat avec FO_PLACE=2) ;
#   place 3 : dossier <racine>\fo-autotest-3, verrou fo-autotest-3.lock (FO_PLACE=3).
# Nombre de places ouvertes : --places N si donné (prioritaire), sinon le fichier <racine>\fo-banc-places.txt, RELU à
# chaque tour d'attente (on le change sans relancer personne) : absent -> 2 ; « 1 », « 2 » ou « 3 » -> ce nombre ;
# toute autre valeur ou fichier illisible -> 1 (jamais de risque).
# Tant que le fo-autotest.bat de la RACINE ne connaît pas FO_PLACE (ancien .bat, déploiement pas fini), 1 place
# seulement, --places compris : l'ancien .bat ferait tourner la place 2 dans fo-autotest\, celui de la place 1.
# GARDE-FOU MÉMOIRE : une place au-delà de la première n'est prise que s'il reste au moins 6 Go de mémoire physique
# libre (GlobalMemoryStatusEx, --memoire-min-go pour les tests), et au plus UNE place au-delà de la première par tour.
#
# Trois genres de tickets :
#   ordinaire : banc sans images, n'importe quelle place ;
#   place 1   : --captures, --visuel ou --son (fo-captures.bat, fo-visual, son) : la place 1 seulement. Un ticket d'un
#               ANCIEN lanceur (sans marque [banc2 ...]) compte comme « place 1 » : il ne connaît que fo-autotest.lock ;
#   seul      : --seul (mesure de performance K10) : TOUTES les places (1 à 3, quel que soit le nombre ouvert : une
#               place fermée peut encore finir un banc lancé avant le changement), personne d'autre ne tourne.
#
# RÈGLE DE LA FILE (à chaque tour, tous les lanceurs calculent la même affectation ; chacun n'agit que pour lui) :
#   1. classement : tour de rôle INCHANGÉ (le plus ancien ticket du lot servi il y a le plus longtemps d'abord ; dans un
#      lot, premier arrivé, premier servi, strictement) ; un lot qui occupe déjà une place compte comme servi
#      maintenant, il passe après les lots qui n'en occupent pas ;
#   2. on parcourt le classement : le premier ticket « place 1 » prend la place 1 si elle est libre, sinon il la RÉSERVE
#      (aucun ticket classé après lui ne la prend : il est servi dès qu'elle se libère) ; un ticket ordinaire prend la
#      place 1 si elle est libre et non réservée (mais une autre place libre si un ticket « place 1 » attend derrière
#      lui), sinon une place 2 ou 3 libre ; un ticket « seul » est une BARRIÈRE : rien ne part derrière lui, il part
#      quand il est premier et que toutes les places sont libres ;
#   3. un verrou tenu par un ticket « seul » arrête tous les départs.
# Pas de famine : un ticket qui attend ne perd jamais son rang à cause de son propre lot (premier arrivé, premier servi
# dans le lot) ; chaque départ d'un autre lot fait reculer ce lot derrière lui ; la place 1 réservée et la barrière du
# « seul » ne servent que le premier qui les attend. Une place libre n'attend que derrière un « seul » (le temps que les
# bancs en cours finissent) ou faute de mémoire.
#
# Ce que fait ce lanceur :
#   1. il prend un TICKET (fichier <racine>\fo-banc-file\<horloge>-<pid>.txt, « qui : scenario ticks (date) [banc2 genre
#      limite] ») : les tickets d'un processus mort sont retirés ;
#   2. quand l'affectation lui donne une place, il prend le verrou de cette place D'UN SEUL COUP (dossier préparé avec
#      owner.txt « pid qui jj/mm hh:mm:ss », format d'avant, et banc2.txt « mode pid », puis renommé : jamais de verrou
#      vide), et lance le .bat avec FO_LOCK_HELD=<place> (et FO_PLACE=<place> aux places 2 et 3) ;
#   3. il ARCHIVE les journaux du dossier de SA place dans --out (journaux compressés, carte non copiée sauf --carte)
#      AVANT de rendre le verrou ;
#   4. il rend le verrou, retire son ticket, affiche les lignes BILAN et rend le code du .bat.
# Un verrou VIDE est celui d'un appel direct au .bat (ancien usage) : place occupée ; s'il reste vide plus de 20 min sans
# aucun factorio.exe de test de cette place, il est orphelin et retiré. Un verrou avec owner.txt d'un processus mort et
# sans jeu de test de cette place est retiré (place 1 : ligne de commande avec « \fo-autotest\ » ou « fo-visual » ;
# place N : « \fo-autotest-N\ » ou « fo-visual »). Seul le premier ticket du classement fait ce ménage (s'il vient d'un
# ancien lanceur, celui-ci garde la place 1 et le premier nouveau ticket fait les places 2 et 3).
#
# Usage (depuis n'importe quel dossier ; racine du jeu trouvée en remontant depuis ce fichier) :
#   py -3.9 -B tools/autotest/banc.py --out <dossier> [--graine N] [--creation <source>] [--son] [--carte]
#          [--visuel "<FO_VISUAL_ARGS>"] [--qui <étiquette>] [--captures] [--seul] [--places N]
#          -- <ticks> <scenario> <source du mod>
#   --captures : fo-captures.bat <scenario> <source> au lieu de fo-autotest.bat (ticks ignorés) ; archive aussi
#                fo-visual\write\script-output\fo-shots\ dans <out>\fo-shots.
#   --seul : banc seul sur le PC (mesures de performance K10 : TOUJOURS --seul).
#   --places N : nombre de places vues par ce lanceur (1 à 3), au lieu de fo-banc-places.txt ; ce ticket ne prend
#                alors aucune place au-delà de N.
#   --file : affiche les places, la file et l'affectation, sans rien lancer.
# Codes : ceux du .bat ; 9 = attente de plus de --attente-max secondes (défaut 6 h), rien n'a tourné ;
#         12 = le jeu a rendu 0 mais le dossier de la place n'a PAS de résultat frais (voir ci-dessous).
# ARCHIVE ÉCHEC (28/10) : un jeu qui plante avant d'effacer le dossier de sa place (code 3221225794 vu à la place 2) laissait
# les journaux PÉRIMÉS du banc précédent, archivés comme s'ils étaient les siens (une partie plantée se lisait comme la
# réussite d'un autre lot). Après chaque banc, `diagnostic` compare le dossier de la place à son état d'avant le lancement
# et à l'heure du lancement : code non nul, done.txt / benchmark.log / create.log absents, inchangés ou plus vieux que le
# lancement, benchmark interrompu (pas de ligne « Performed N updates » en fin de benchmark-stdout.txt). En cas de problème :
# fichier ECHEC.txt dans l'archive (les raisons), AUCUN fichier périmé archivé, code de sortie non nul (celui du jeu, sinon 12).
import argparse
import ctypes
import gzip
import os
import re
import shutil
import subprocess
import sys
import time

try:  # lot OUTILLAGE : aucun sous-processus ne doit ouvrir de fenêtre chez le joueur (tools/autotest/sans_fenetre.py)
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import sans_fenetre
except ImportError:  # copie isolée de ce fichier : mêmes drapeaux, en minimal
    class sans_fenetre:  # noqa: N801
        @staticmethod
        def run(cmd, **kw):
            if os.name == "nt":
                si = subprocess.STARTUPINFO()
                si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                kw.update(creationflags=0x08000000 | 0x4000, startupinfo=si)
            return subprocess.run(cmd, **kw)

_kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

MAX_PLACES = 3
PLACES = tuple(range(1, MAX_PLACES + 1))
MEMOIRE_MIN_GO = 6.0
PLACES_PAR_DEFAUT = 2


def racine_du_jeu():
    if os.environ.get("FO_ROOT"):
        return os.environ["FO_ROOT"]
    d = os.path.dirname(os.path.abspath(__file__))
    while True:
        if os.path.isfile(os.path.join(d, "bin", "x64", "factorio.exe")):
            return d
        p = os.path.dirname(d)
        if p == d:
            raise SystemExit("[BANC] racine du jeu introuvable (bin\\x64\\factorio.exe) au-dessus de " + __file__)
        d = p


RACINE = racine_du_jeu()
FILE = os.path.join(RACINE, "fo-banc-file")
FICHIER_PLACES = os.path.join(RACINE, "fo-banc-places.txt")


def dossier(p):
    return os.path.join(RACINE, "fo-autotest" if p == 1 else "fo-autotest-%d" % p)


def verrou(p):
    return dossier(p) + ".lock"


def proprio(p):
    return os.path.join(verrou(p), "owner.txt")


def marque(p):
    return os.path.join(verrou(p), "banc2.txt")


VERROU = verrou(1)
PROPRIO = proprio(1)


def vivant(pid):
    if pid <= 0:
        return False
    h = _kernel32.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
    if not h:
        return False
    code = ctypes.c_ulong()
    ok = _kernel32.GetExitCodeProcess(h, ctypes.byref(code))
    _kernel32.CloseHandle(h)
    return bool(ok) and code.value == 259  # STILL_ACTIVE


class _Memoire(ctypes.Structure):
    _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
                ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
                ("ullTotalPageFile", ctypes.c_ulonglong), ("ullAvailPageFile", ctypes.c_ulonglong),
                ("ullTotalVirtual", ctypes.c_ulonglong), ("ullAvailVirtual", ctypes.c_ulonglong),
                ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]


def memoire_libre_go():
    """Mémoire physique libre en Go (GlobalMemoryStatusEx) ; 0 si la lecture échoue (aucune place en plus)."""
    m = _Memoire()
    m.dwLength = ctypes.sizeof(_Memoire)
    if not _kernel32.GlobalMemoryStatusEx(ctypes.byref(m)):
        return 0.0
    return m.ullAvailPhys / 2.0 ** 30


def jeux_de_test(p=None):
    """Nombre de factorio.exe dont la ligne de commande vise un dossier de test : place p (« \\fo-autotest\\ » ou
    « \\fo-autotest-N\\ », ou fo-visual) ; p None : tout dossier de test (fo-autotest* ou fo-visual)."""
    if p is None:
        motif = "$_.CommandLine -like '*fo-autotest*'"
    else:
        motif = "$_.CommandLine -like '*\\%s\\*'" % os.path.basename(dossier(p))
    try:
        out = sans_fenetre.run(["powershell", "-NoProfile", "-Command",
                              "@(Get-CimInstance Win32_Process -Filter \"Name='factorio.exe'\" | "
                              "? { %s -or $_.CommandLine -like '*fo-visual*' }).Count" % motif],
                             capture_output=True, text=True, timeout=60).stdout.strip()
        return int(out or "0")
    except Exception:
        return 1  # dans le doute, on suppose qu'un jeu tourne


def pid_du_ticket(n):
    try:
        return int(n.split("-")[1].split(".")[0])
    except (IndexError, ValueError):
        return 0


def tickets():
    os.makedirs(FILE, exist_ok=True)
    res = []
    for n in sorted(os.listdir(FILE)):
        p = os.path.join(FILE, n)
        if n.startswith(("prise-", "rendu-")) and os.path.isdir(p):
            # dossier de verrou préparé ou rendu par un lanceur mort entre deux étapes
            if not vivant(pid_du_ticket(n)):
                shutil.rmtree(p, ignore_errors=True)
            continue
        if not n.endswith(".txt"):
            continue
        pid = pid_du_ticket(n)
        if not pid:
            continue
        if not vivant(pid):
            try:
                os.remove(p)
            except OSError:
                pass
            continue
        res.append(n)
    return res


def lire(p):
    try:
        with open(p, encoding="utf-8", errors="replace") as f:
            return f.read().strip()
    except OSError:
        return ""


# Tour de rôle entre les lots (27/10, 3 h 50) : le 27/10, un lot a déposé 14 bancs d'un coup et les bancs du cas du DC
# d'un autre lot attendaient derrière (1 h). Le ticket servi est désormais le plus ancien du lot servi il y a le plus
# longtemps (jamais servi d'abord) ; à l'intérieur d'un lot, premier arrivé, premier servi. Le lot est l'étiquette --qui.
SERVIS = os.path.join(FILE, "servis")


def lot_du_texte(txt):
    return txt.split(" : ", 1)[0] if " : " in txt else txt


def lot_du_ticket(n):
    return lot_du_texte(lire(os.path.join(FILE, n)))


_MARQUE = re.compile(r"\[banc2 (ordinaire|place1|seul) ([1-9])\]\s*$")


def genre_du_texte(txt):
    """(genre, limite) d'un ticket ; un ticket d'un ancien lanceur (sans marque) : ("place1", 1)."""
    m = _MARQUE.search(txt)
    return (m.group(1), int(m.group(2))) if m else ("place1", 1)


def nom_de_lot(qui):
    return "".join(c if c.isalnum() or c in "-_" else "_" for c in qui)[:80] or "_"


def dernier_service(qui):
    try:
        return float((lire(os.path.join(SERVIS, nom_de_lot(qui))).split() or ["0"])[0])
    except ValueError:
        return 0.0


def classement(t, lot=lot_du_ticket, servi=dernier_service):
    """Tickets à servir, dans l'ordre : le plus ancien ticket de chaque lot (les suivants attendent qu'il soit parti),
    lots rangés par dernier service (jamais servi d'abord), puis par ancienneté du ticket. Règle pure."""
    premier = {}
    for n in t:
        premier.setdefault(lot(n), n)
    return sorted(premier.values(), key=lambda n: (servi(lot(n)), n))


def elu(t, lot=lot_du_ticket, servi=dernier_service):
    """Ticket à servir parmi t (triés par heure de dépôt) : règle pure, testée par tests/test_banc_file.py."""
    c = classement(t, lot, servi)
    return c[0] if c else None


def affecter(rangs, genre, libres, n, memoire_ok, limite=lambda t: MAX_PLACES):
    """Règle pure de la file : {ticket: [places à prendre maintenant]}.
    rangs : tickets en attente, dans l'ordre de classement() ; genre(t) : "ordinaire", "place1" ou "seul" ;
    libres : places sans verrou ; n : places ouvertes (1 à 3) ; memoire_ok : assez de mémoire pour une place de plus ;
    limite(t) : place la plus haute permise au ticket (--places)."""
    res = {}
    p1 = 1 in libres          # place 1 encore à donner (ni prise, ni réservée)
    en_plus = memoire_ok      # une seule place au-delà de la première par tour
    fin = next((i for i, t in enumerate(rangs) if genre(t) == "seul"), len(rangs))
    for i, t in enumerate(rangs):
        g = genre(t)
        if g == "seul":
            if not res and all(p in libres for p in PLACES):
                res[t] = list(PLACES)
            break
        if g == "place1":
            if p1:
                res[t] = [1]
            p1 = False        # prise, ou réservée à ce ticket
            continue
        autre = None
        if en_plus:
            autre = next((p for p in range(2, min(n, limite(t)) + 1) if p in libres), None)
        images_derriere = any(genre(u) == "place1" for u in rangs[i + 1:fin])
        if p1 and not (images_derriere and autre):
            res[t] = [1]
            p1 = False
        elif autre:
            res[t] = [autre]
            libres = set(libres) - {autre}
            en_plus = False
    return res


def places_ouvertes(option=None, texte=None):
    """Nombre de places : --places si donné ; sinon fo-banc-places.txt : absent (texte None) -> 2 ; « 1 », « 2 », « 3 »
    -> ce nombre ; autre chose (fichier illisible compris) -> 1. Règle pure."""
    if option is not None:
        return option
    if texte is None:
        return PLACES_PAR_DEFAUT
    texte = texte.strip()
    return int(texte) if texte in ("1", "2", "3") else 1


def bat_a_places():
    """Vrai si le fo-autotest.bat de la racine connaît FO_PLACE (déployé depuis le lot BANC2). Un ancien .bat
    ignorerait FO_PLACE et ferait tourner le banc de la place 2 dans fo-autotest\\, celui de la place 1."""
    try:
        with open(os.path.join(RACINE, "fo-autotest.bat"), "rb") as f:
            return b"FO_PLACE" in f.read()
    except OSError:
        return False


def lire_places(option):
    if not bat_a_places():
        return 1
    if option is not None:
        return option
    if not os.path.exists(FICHIER_PLACES):
        return places_ouvertes(None, None)
    try:
        with open(FICHIER_PLACES, encoding="utf-8", errors="strict") as f:
            return places_ouvertes(None, f.read(64))
    except (OSError, UnicodeError):
        return 1


def noter_service(qui, pid):
    p = os.path.join(SERVIS, nom_de_lot(qui))
    if lire(p).split()[1:2] == [str(pid)]:
        return
    os.makedirs(SERVIS, exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(f"{time.time():.3f} {pid}\n")


def observer_verrou():
    """Note le lot qui tient chaque place (owner.txt : « pid qui jj/mm hh:mm:ss »), même lancé par une version de ce
    fichier sans tour de rôle : sans cela, ses lots passeraient pour jamais servis."""
    for p in PLACES:
        m = lire(proprio(p)).split()
        if len(m) >= 4 and m[0].isdigit():
            noter_service(" ".join(m[1:-2]), int(m[0]))


def etat_place(p):
    """None si la place est libre ; sinon (pid, qui, mode), mode « partage », « exclusif » (ticket --seul) ou
    « inconnu » (ancien lanceur ou appel direct au .bat : place occupée, rien de plus)."""
    if not os.path.isdir(verrou(p)):
        return None
    m = lire(proprio(p)).split()
    pid = int(m[0]) if m and m[0].isdigit() else 0
    k = lire(marque(p)).split()
    mode = k[0] if len(k) >= 2 and k[0] in ("partage", "exclusif") and k[1] == str(pid) and pid else "inconnu"
    return (pid, " ".join(m[1:-2]) if len(m) >= 4 else "", mode)


def nettoyer(places, etat):
    """Retire les verrous orphelins des places données ; etat garde l'heure où l'on a vu chaque verrou vide."""
    for p in places:
        v = verrou(p)
        cle = "vide_depuis_%d" % p
        if not os.path.isdir(v):
            etat.pop(cle, None)
            continue
        txt = lire(proprio(p))
        if txt:
            etat.pop(cle, None)
            try:
                pid = int(txt.split()[0])
            except (ValueError, IndexError):
                pid = 0
            if not vivant(pid) and jeux_de_test(p) == 0 and lire(proprio(p)) == txt:
                print(f"[BANC] place {p} : verrou orphelin (processus {pid} mort, aucun jeu de test) : retiré", flush=True)
                shutil.rmtree(v, ignore_errors=True)
            continue
        t = etat.setdefault(cle, time.time())
        if time.time() - t > 20 * 60 and jeux_de_test(p) == 0 and not lire(proprio(p)):
            print(f"[BANC] place {p} : verrou vide depuis plus de 20 min sans jeu de test : orphelin, retiré", flush=True)
            shutil.rmtree(v, ignore_errors=True)
            etat.pop(cle, None)


def prendre_place(p, qui, mode):
    """Prend le verrou de la place p d'un seul coup : dossier préparé (owner.txt au format d'avant, banc2.txt) puis
    renommé ; le renommage échoue si le verrou existe (mkdir du .bat ou d'un ancien lanceur compris)."""
    pid = os.getpid()
    tmp = os.path.join(FILE, f"prise-{pid}-{p}")
    shutil.rmtree(tmp, ignore_errors=True)
    proprietaire = f"{pid} {qui} {time.strftime('%d/%m %H:%M:%S')}\n"
    try:
        os.makedirs(tmp)
        with open(os.path.join(tmp, "owner.txt"), "w", encoding="utf-8") as f:
            f.write(proprietaire)
        with open(os.path.join(tmp, "banc2.txt"), "w", encoding="utf-8") as f:
            f.write(f"{mode} {pid}\n")
        os.rename(tmp, verrou(p))
        return True
    except OSError:
        shutil.rmtree(tmp, ignore_errors=True)
        if os.path.exists(verrou(p)):
            return False
    try:  # renommage refusé alors que la place est libre : prise à l'ancienne (mkdir puis owner.txt)
        os.mkdir(verrou(p))
    except OSError:
        return False
    with open(proprio(p), "w", encoding="utf-8") as f:
        f.write(proprietaire)
    with open(marque(p), "w", encoding="utf-8") as f:
        f.write(f"{mode} {pid}\n")
    return True


def a_moi(p):
    return lire(proprio(p)).split()[:1] == [str(os.getpid())]


def rendre_place(p):
    """Rend le verrou de la place p s'il est à ce processus : renommé d'abord (il disparaît d'un coup), puis effacé."""
    if not (os.path.isdir(verrou(p)) and a_moi(p)):
        return
    tmp = os.path.join(FILE, f"rendu-{os.getpid()}-{p}")
    shutil.rmtree(tmp, ignore_errors=True)
    try:
        os.rename(verrou(p), tmp)
    except OSError:
        tmp = verrou(p)
    shutil.rmtree(tmp, ignore_errors=True)


def gz(src, dst):
    with open(src, "rb") as fi, gzip.open(dst, "wb") as fo:
        shutil.copyfileobj(fi, fo)


CODE_SANS_RESULTAT = 12
TOLERANCE_HORLOGE = 3.0  # exFAT arrondit les heures de modification à 2 s
FICHIERS_BANC = ("done.txt", "benchmark.log", "create.log", "benchmark-stdout.txt")


def signature(res):
    """{nom: (heure de modification, taille)} des fichiers du dossier de la place, avant le lancement."""
    sig = {}
    for n in sorted(os.listdir(res)) if os.path.isdir(res) else []:
        p = os.path.join(res, n)
        if os.path.isfile(p):
            st = os.stat(p)
            sig[n] = (st.st_mtime, st.st_size)
    return sig


def fin_de_benchmark(p):
    """Vrai si la fin de benchmark-stdout.txt porte « Performed N updates » (le jeu est allé au bout des ticks)."""
    try:
        with open(p, "rb") as f:
            f.seek(0, os.SEEK_END)
            f.seek(max(0, f.tell() - 65536))
            return b"Performed " in f.read()
    except OSError:
        return False


def diagnostic(res, t_lancement, sig_avant, code, captures=False, fin=fin_de_benchmark):
    """(problèmes, périmés) : raisons pour lesquelles ce banc n'a pas de résultat frais, et fichiers du dossier de la place
    qui datent d'un banc précédent (inchangés depuis avant le lancement ou plus vieux que le lancement)."""
    problemes, perimes = [], set()
    if code != 0:
        problemes.append(f"code de sortie {code} (le jeu ou le lanceur a échoué)")
    sig_apres = signature(res)

    def frais(n):
        if n not in sig_apres:
            return None
        st = sig_apres[n]
        if sig_avant.get(n) == st or st[0] < t_lancement - TOLERANCE_HORLOGE:
            return False
        return True

    for n in sorted(sig_apres):
        if n in FICHIERS_BANC and frais(n) is False:
            perimes.add(n)
    if not captures:  # les images (fo-captures.bat) ne produisent pas de benchmark.log : seuls code et périmés comptent
        for n in FICHIERS_BANC:
            f = frais(n)
            if f is None:
                problemes.append(f"{n} absent")
            elif f is False:
                problemes.append(f"{n} PÉRIMÉ (d'un banc précédent : le jeu n'a pas écrit dans ce dossier)")
        if frais("benchmark-stdout.txt") and not fin(os.path.join(res, "benchmark-stdout.txt")):
            problemes.append("benchmark interrompu (pas de ligne « Performed N updates » : le jeu s'est arrêté avant la fin)")
    return problemes, perimes


def archiver(out, carte, captures, place=1, perimes=()):
    os.makedirs(out, exist_ok=True)
    res = dossier(place)
    for n in sorted(os.listdir(res)) if os.path.isdir(res) else []:
        p = os.path.join(res, n)
        if not os.path.isfile(p) or n in perimes:
            continue
        if n.endswith(".zip") and not carte:
            continue
        if n in ("benchmark.log", "benchmark-stdout.txt", "create-stdout.txt") or (n == "create.log" and os.path.getsize(p) > 1_000_000):
            gz(p, os.path.join(out, n + ".gz"))
        else:
            shutil.copy2(p, os.path.join(out, n))
    if captures:
        shots = os.path.join(RACINE, "fo-visual", "write", "script-output", "fo-shots")
        if os.path.isdir(shots):
            shutil.copytree(shots, os.path.join(out, "fo-shots"), dirs_exist_ok=True)


def bilans(out):
    lignes = []
    for n in ("create.log", "benchmark.log", "create.log.gz", "benchmark.log.gz"):
        p = os.path.join(out, n)
        if not os.path.exists(p):
            continue
        op = gzip.open if n.endswith(".gz") else open
        with op(p, "rt", encoding="utf-8", errors="replace") as f:
            for l in f:
                if "BILAN" in l:
                    lignes.append(n.split(".")[0] + " : " + l.strip()[-200:])
    return lignes


def tour(option_places, memoire_min_go):
    """Un tour de la file, vu par n'importe quel lanceur : (tickets, textes, etats, rangs, affectation, n, memoire)."""
    t = tickets()
    observer_verrou()
    textes = {x: lire(os.path.join(FILE, x)) for x in t}
    etats = {p: etat_place(p) for p in PLACES}
    en_cours = {e[0] for e in etats.values() if e}
    lots_en_cours = {lot_du_texte(textes[x]) for x in t if pid_du_ticket(x) in en_cours}
    attente = [x for x in t if pid_du_ticket(x) not in en_cours]
    maintenant = time.time()
    rangs = classement(attente, lambda x: lot_du_texte(textes[x]),
                       lambda l: maintenant if l in lots_en_cours else dernier_service(l))
    n = lire_places(option_places)
    mem = memoire_libre_go()
    if any(e and e[2] == "exclusif" for e in etats.values()):
        aff = {}
    else:
        aff = affecter(rangs, lambda x: genre_du_texte(textes[x])[0], {p for p in PLACES if etats[p] is None}, n,
                       mem >= memoire_min_go, lambda x: genre_du_texte(textes[x])[1])
    return t, textes, etats, rangs, aff, n, mem


def montrer_file(option_places, memoire_min_go):
    t, textes, etats, rangs, aff, n, mem = tour(option_places, memoire_min_go)
    print(f"[BANC] racine {RACINE}")
    print(f"[BANC] places ouvertes : {n} (fo-banc-places.txt : "
          f"{lire(FICHIER_PLACES) or 'absent' if os.path.exists(FICHIER_PLACES) else 'absent'}) ; "
          f"mémoire libre {mem:.1f} Go (seuil {memoire_min_go:g} Go pour les places 2 et 3)")
    for p in PLACES:
        e = etats[p]
        print(f"[BANC] place {p} ({os.path.basename(verrou(p))}) : " + (
            "libre" if e is None else f"tenue par {lire(proprio(p)) or '(vide : appel direct au .bat)'} ({e[2]})"))
    places_de = {e[0]: p for p, e in sorted(etats.items(), reverse=True) if e}
    for i, x in enumerate(t):
        p = places_de.get(pid_du_ticket(x))
        quoi = (f"  (en cours, place {p})" if p else
                f"  <- part maintenant, place {aff[x]}" if x in aff else
                f"  (rang {rangs.index(x) + 1})" if x in rangs else "  (derrière un ticket de son lot)")
        print(f"[BANC] file {i + 1} : {x} {textes[x]}{quoi}")


def main(argv):
    if hasattr(sans_fenetre, "cacher_ma_console"):
        sans_fenetre.cacher_ma_console()  # lot OUTILLAGE : lanceur sans console -> pas de fenêtre ouverte pendant des heures
    ap = argparse.ArgumentParser()
    ap.add_argument("--out")
    ap.add_argument("--graine")
    ap.add_argument("--creation")
    ap.add_argument("--son", action="store_true")
    ap.add_argument("--carte", action="store_true")
    ap.add_argument("--captures", action="store_true")
    ap.add_argument("--visuel")
    ap.add_argument("--seul", action="store_true")
    ap.add_argument("--places", type=int, choices=PLACES)
    ap.add_argument("--memoire-min-go", type=float, default=MEMOIRE_MIN_GO)
    ap.add_argument("--qui", default="")
    ap.add_argument("--file", action="store_true")
    ap.add_argument("--attente-max", type=float, default=6 * 3600)
    ap.add_argument("reste", nargs="*")
    # F307 : argparse refuse « --visuel "--no-atlas-cache" » (valeur qui commence par « -- ») ; on la recolle.
    argv = list(argv)
    for i in range(len(argv) - 1):
        if argv[i] == "--visuel":
            argv[i:i + 2] = ["--visuel=" + argv[i + 1]]
            break
    a = ap.parse_args(argv)
    if a.file:
        montrer_file(a.places, a.memoire_min_go)
        return 0
    if not a.out or len(a.reste) != 3:
        ap.error("il faut --out <dossier> et, après --, <ticks> <scenario> <source du mod>")
    ticks, scenario, source = a.reste
    out = os.path.abspath(a.out)
    env = dict(os.environ)
    for k in ("FO_MAP_SEED", "FO_CREATE_SRC", "FO_AUDIO", "FO_VISUAL_ARGS", "FO_LOCK_HELD", "FO_PLACE"):
        env.pop(k, None)
    if a.graine:
        env["FO_MAP_SEED"] = a.graine
    if a.creation:
        env["FO_CREATE_SRC"] = a.creation
    if a.son:
        env["FO_AUDIO"] = "1"
    if a.visuel:
        env["FO_VISUAL_ARGS"] = a.visuel
    genre = "seul" if a.seul else "place1" if (a.captures or a.visuel or a.son) else "ordinaire"
    mode = "exclusif" if genre == "seul" else "partage"
    qui = (a.qui or os.path.basename(out)).replace("\n", " ")
    os.makedirs(FILE, exist_ok=True)
    moi = f"{time.time_ns():020d}-{os.getpid()}.txt"
    with open(os.path.join(FILE, moi), "w", encoding="utf-8") as f:
        f.write(f"{qui} : {scenario} {ticks} ({time.strftime('%d/%m %H:%M:%S')}) "
                f"[banc2 {genre} {a.places or MAX_PLACES}]\n")
    t0 = time.time()
    etat = {}
    dernier = 0
    mes = []
    try:
        while True:
            tenues = [p for p in PLACES if os.path.isdir(verrou(p)) and a_moi(p)]
            if tenues:  # ticket « seul » servi en partie (une place prise entre-temps par un appel direct) : la suite
                for p in PLACES:
                    if p not in tenues and etat_place(p) is None:
                        prendre_place(p, qui, mode)
                tenues = [p for p in PLACES if os.path.isdir(verrou(p)) and a_moi(p)]
                if len(tenues) == MAX_PLACES:
                    mes = tenues
                    noter_service(qui, os.getpid())
                    break
            else:
                t, textes, etats, rangs, aff, n, mem = tour(a.places, a.memoire_min_go)
                nouveaux = [x for x in rangs if _MARQUE.search(textes[x])]
                if rangs and (rangs[0] == moi or (nouveaux and nouveaux[0] == moi)):
                    nettoyer(PLACES if rangs[0] == moi else PLACES[1:], etat)
                    t, textes, etats, rangs, aff, n, mem = tour(a.places, a.memoire_min_go)
                if moi in aff:
                    voulues = aff[moi]
                    prises = []
                    for p in voulues:
                        if not prendre_place(p, qui, mode):
                            break
                        prises.append(p)
                    if prises == voulues:
                        mes = prises
                        noter_service(qui, os.getpid())
                        break
                    if genre != "seul":
                        for p in prises:
                            rendre_place(p)
            if time.time() - t0 > a.attente_max:
                print(f"[BANC] {qui} : attente de plus de {a.attente_max:.0f} s, abandon (rien n'a tourné)", flush=True)
                return 9
            if time.time() - dernier > 300:
                t = tickets()
                rang = t.index(moi) + 1 if moi in t else "?"
                occ = ", ".join(f"{p} {'libre' if etat_place(p) is None else 'prise'}" for p in PLACES)
                print(f"[BANC] {qui} : en file ({genre}), rang {rang} sur {len(t)}, attente {time.time() - t0:.0f} s ; "
                      f"places ouvertes {lire_places(a.places)} ({occ}) ; mémoire libre {memoire_libre_go():.1f} Go",
                      flush=True)
                dernier = time.time()
            time.sleep(2)
        attente = time.time() - t0
        place = mes[0]
        env["FO_LOCK_HELD"] = str(place)
        if place != 1:
            env["FO_PLACE"] = str(place)
        print(f"[BANC] {qui} : place {place} ({genre}{', toutes les places' if genre == 'seul' else ''}), "
              f"attente {attente:.0f} s", flush=True)
        sig_avant = signature(dossier(place))
        t1 = time.time()
        if a.captures:
            cmd = [os.path.join(RACINE, "fo-captures.bat"), scenario, source]
        else:
            cmd = [os.path.join(RACINE, "fo-autotest.bat"), "nopause", str(ticks), scenario, source]
        # Lot OUTILLAGE : sans fenêtre (CREATE_NO_WINDOW), priorité réduite pour la création de la carte et les copies ;
        # le benchmark reste lancé par « start /ABOVENORMAL » dans fo-autotest.bat (mesures inchangées).
        p = sans_fenetre.run(cmd, env=env, cwd=RACINE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        t2 = time.time()
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, "banc-sortie.txt"), "wb") as f:
            f.write(p.stdout)
        problemes, perimes = diagnostic(dossier(place), t1, sig_avant, p.returncode, a.captures)
        archiver(out, a.carte, a.captures, place, perimes)
        echec = os.path.join(out, "ECHEC.txt")
        if problemes:
            with open(echec, "w", encoding="utf-8") as f:
                f.write(f"ECHEC du banc {qui} ({scenario}, {ticks} ticks, place {place}, {time.strftime('%d/%m/%Y %H:%M:%S')}) :\n")
                f.write("".join(f"  - {x}\n" for x in problemes))
                f.write("Fichiers périmés NON archivés : " + (", ".join(sorted(perimes)) or "aucun") + "\n")
                f.write("Cette archive ne contient PAS le résultat d'une partie : ne pas la lire comme un succès.\n")
        elif os.path.exists(echec):
            os.remove(echec)
        if problemes and p.returncode == 0:
            p.returncode = CODE_SANS_RESULTAT
        with open(os.path.join(out, "banc.txt"), "w", encoding="utf-8") as f:
            f.write(f"{qui}\ncommande : {' '.join(cmd)}\ngraine {a.graine or '-'} ; creation {a.creation or '-'} ; "
                    f"son {a.son} ; visuel {a.visuel or '-'}\ncode {p.returncode} ; attente {attente:.0f} s ; "
                    f"banc {t2 - t1:.0f} s ; fin {time.strftime('%d/%m/%Y %H:%M:%S')}\n"
                    f"place {place} ; verrous {' '.join(map(str, mes))} ; genre {genre} ; dossier {dossier(place)} ; "
                    f"prise {t1:.3f} ; fin {t2:.3f}\n")
    finally:
        for q in reversed(PLACES):
            rendre_place(q)
        try:
            os.remove(os.path.join(FILE, moi))
        except OSError:
            pass
    print(f"[BANC] {qui} : code {p.returncode}, place {place}, attente {attente:.0f} s, banc {time.time() - t1:.0f} s, "
          f"archive {out}", flush=True)
    for x in problemes:
        print(f"[BANC] {qui} : ECHEC DU BANC : {x}", flush=True)
    for l in bilans(out):
        print("[BANC]   " + l, flush=True)
    return p.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
