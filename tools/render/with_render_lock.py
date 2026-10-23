"""
Verrou machine du rendu Blender : au plus N rendus en même temps sur le PC du Directeur Créatif
(défaut 2), lancés en priorité « inférieure à la normale » pour ne pas gêner une partie en cours.

Plusieurs agents (un par famille, chacun dans son worktree) rendent en parallèle : sans ce verrou, 7
Blender saturent les 16 fils du processeur. TOUT appel à Blender passe par ce script.

Usage (depuis la racine d'un worktree ou du mod) :
    python tools/render/with_render_lock.py [--slots N] [--wait S] [--priority below|normal] [--poll S]
        [--min-libre-go G] [--disque CHEMIN ...] -- <commande...>
(--poll : intervalle de scrutation en secondes, défaut 5, MINIMUM 5 : correcteur V0b, une scrutation plus
rapide passait devant les autres agents, qui scrutent toutes les 5 s ; aucune file d'attente : la première
scrutation qui trouve une place libre la prend.)
Exemple :
    python tools/render/with_render_lock.py -- python -P tools/render/render.py tools/render/pieces/cheminee.py

Le verrou est un dossier <racine du jeu>\\fo-render.lock.<k> (création atomique) qui contient owner.txt
(PID du script, commande). Un dossier dont le PID n'existe plus est repris (verrou orphelin). Codes de
sortie : celui de la commande ; 2 si aucune place ne s'est libérée avant --wait secondes ; 4 si la garde de
disque refuse.
Dossier des verrous : variable FO_RENDER_LOCK_DIR, sinon la racine du jeu ci-dessous.

GARDE DE DISQUE (reste du lot A0, fait au lot A3) : une fois la place obtenue, et avant de lancer la commande, le
script refuse (code 4, message « [fo-render] REFUS : … ») s'il reste moins de --min-libre-go Go libres (défaut 1,0)
sur le disque de chaque chemin donné par --disque (option répétable ; un chemin qui n'existe pas encore est remplacé
par son plus proche parent existant) ; sans --disque, le disque du dossier courant. --min-libre-go 0 désactive la
garde. Variable FO_RENDER_MIN_LIBRE_GO : autre seuil par défaut. Test : tools/render/tests/test_garde_disque.py.
"""
import ctypes
import os
import shutil
import subprocess
import sys
import time

DEFAULT_DIR = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
BELOW_NORMAL_PRIORITY_CLASS = 0x00004000
MIN_POLL_S = 5.0   # même rythme pour tous les agents : aucun ne passe devant les autres
_kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)


def alive(pid):
    """Le processus existe-t-il ? Lecture seule (jamais os.kill : sous Windows, il TERMINE le processus)."""
    if pid <= 0:
        return False
    h = _kernel32.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
    if not h:
        return ctypes.get_last_error() == 5  # accès refusé : le processus existe
    code = ctypes.c_ulong()
    ok = _kernel32.GetExitCodeProcess(h, ctypes.byref(code))
    _kernel32.CloseHandle(h)
    return bool(ok) and code.value == 259  # STILL_ACTIVE


def owner_pid(d):
    try:
        with open(os.path.join(d, "owner.txt"), encoding="utf-8") as f:
            return int(f.read().split()[0])
    except (OSError, ValueError, IndexError):
        return None


def release(d):
    """Supprime le dossier du verrou, en réessayant : un lecteur de owner.txt peut le tenir un instant."""
    for _ in range(40):
        shutil.rmtree(d, ignore_errors=True)
        if not os.path.exists(d):
            return
        time.sleep(0.25)


def try_slot(d):
    """Prend la place d (True), ou la laisse si elle est tenue par un processus vivant (False)."""
    for _ in range(2):
        try:
            os.mkdir(d)
        except FileExistsError:
            pid = owner_pid(d)
            if pid is None:
                try:  # dossier tout juste créé : son propriétaire écrit owner.txt
                    if time.time() - os.path.getmtime(d) < 30:
                        return False
                except OSError:
                    continue  # supprimé entre-temps : réessayer
            if alive(pid or -1):
                return False
            print("[fo-render] verrou orphelin repris : %s (PID %s)" % (d, pid), flush=True)
            release(d)
            continue
        with open(os.path.join(d, "owner.txt"), "w", encoding="utf-8") as f:
            f.write("%d %s\n" % (os.getpid(), " ".join(sys.argv)))
        return True
    return False


def acquire(base, slots, wait_s, poll_s=5.0):
    t0 = time.time()
    said = False
    while True:
        for k in range(1, slots + 1):
            d = os.path.join(base, "fo-render.lock.%d" % k)
            if try_slot(d):
                if said:
                    print("[fo-render] place obtenue après %.0f s : %s" % (time.time() - t0, d), flush=True)
                return d
        if time.time() - t0 > wait_s:
            return None
        if not said:
            print("[fo-render] %d rendu(s) déjà en cours : attente d'une place..." % slots, flush=True)
            said = True
        time.sleep(poll_s)


def existant(p):
    """Le chemin, ou son plus proche parent qui existe (un dossier de sortie pas encore créé)."""
    p = os.path.abspath(p)
    while not os.path.exists(p):
        q = os.path.dirname(p)
        if q == p:
            break
        p = q
    return p


def garde_disque(chemins, seuil_go):
    """None si chaque disque a au moins seuil_go Go libres, sinon le message de refus."""
    if seuil_go <= 0:
        return None
    for c in chemins or [os.getcwd()]:
        p = existant(c)
        libre = shutil.disk_usage(p).free / 1e9
        if libre < seuil_go:
            return ("[fo-render] REFUS : %.2f Go libres sur le disque de %s (seuil %.2f Go, option --min-libre-go) : "
                    "rien n'est lancé. Faites de la place, ou changez le seuil en connaissance de cause." % (
                        libre, p, seuil_go))
    return None


def main(argv):
    slots, wait_s, priority, poll_s = 2, 4 * 3600, "below", 5.0
    seuil_go = float(os.environ.get("FO_RENDER_MIN_LIBRE_GO", "") or 1.0)
    disques = []
    if "--" not in argv:
        print(__doc__)
        return 1
    opts, cmd = argv[:argv.index("--")], argv[argv.index("--") + 1:]
    i = 0
    while i < len(opts):
        if opts[i] == "--slots":
            slots = int(opts[i + 1]); i += 2
        elif opts[i] == "--wait":
            wait_s = float(opts[i + 1]); i += 2
        elif opts[i] == "--poll":
            poll_s = max(MIN_POLL_S, float(opts[i + 1])); i += 2
        elif opts[i] == "--priority":
            priority = opts[i + 1]; i += 2
        elif opts[i] == "--min-libre-go":
            seuil_go = float(opts[i + 1]); i += 2
        elif opts[i] == "--disque":
            disques.append(opts[i + 1]); i += 2
        else:
            print("option inconnue : %s" % opts[i]); return 1
    if not cmd:
        print("commande absente après --"); return 1
    base = os.environ.get("FO_RENDER_LOCK_DIR", DEFAULT_DIR)
    d = acquire(base, slots, wait_s, poll_s)
    if d is None:
        print("[fo-render] délai dépassé : aucune place libre en %.0f s" % wait_s, flush=True)
        return 2
    try:
        refus = garde_disque(disques, seuil_go)
        if refus:
            print(refus, flush=True)
            return 4
        flags = BELOW_NORMAL_PRIORITY_CLASS if priority == "below" else 0
        return subprocess.call(cmd, creationflags=flags)
    finally:
        release(d)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
