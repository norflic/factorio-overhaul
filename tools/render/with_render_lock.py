"""
Verrou machine du rendu Blender : au plus N rendus en même temps sur le PC du Directeur Créatif
(défaut 2), lancés en priorité « inférieure à la normale » pour ne pas gêner une partie en cours.

Plusieurs agents (un par famille, chacun dans son worktree) rendent en parallèle : sans ce verrou, 7
Blender saturent les 16 fils du processeur. TOUT appel à Blender passe par ce script.

Usage (depuis la racine d'un worktree ou du mod) :
    python tools/render/with_render_lock.py [--slots N] [--wait S] [--priority below|normal] [--poll S] -- <commande...>
(--poll : intervalle de scrutation en secondes, défaut 5 ; aucune file d'attente : la première scrutation
qui trouve une place libre la prend.)
Exemple :
    python tools/render/with_render_lock.py -- python -P tools/render/render.py tools/render/pieces/cheminee.py

Le verrou est un dossier <racine du jeu>\\fo-render.lock.<k> (création atomique) qui contient owner.txt
(PID du script, commande). Un dossier dont le PID n'existe plus est repris (verrou orphelin). Codes de
sortie : celui de la commande ; 2 si aucune place ne s'est libérée avant --wait secondes.
Dossier des verrous : variable FO_RENDER_LOCK_DIR, sinon la racine du jeu ci-dessous.
"""
import ctypes
import os
import shutil
import subprocess
import sys
import time

DEFAULT_DIR = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
BELOW_NORMAL_PRIORITY_CLASS = 0x00004000
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


def main(argv):
    slots, wait_s, priority, poll_s = 2, 4 * 3600, "below", 5.0
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
            poll_s = max(0.2, float(opts[i + 1])); i += 2
        elif opts[i] == "--priority":
            priority = opts[i + 1]; i += 2
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
        flags = BELOW_NORMAL_PRIORITY_CLASS if priority == "below" else 0
        return subprocess.call(cmd, creationflags=flags)
    finally:
        release(d)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
