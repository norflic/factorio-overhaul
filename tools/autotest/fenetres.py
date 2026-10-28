# Lot OUTILLAGE (28/10) : y a-t-il des fenêtres de console qui s'ouvrent ? Mesure par EnumWindows (ctypes), sans rien changer.
#
# Lance une commande, échantillonne les fenêtres de premier niveau toutes les 5 ms pendant qu'elle tourne, et dit lesquelles
# sont APPARUES visibles et appartiennent à un descendant de la commande (cmd.exe, powershell.exe, robocopy.exe, conhost.exe...).
# Les fenêtres des AUTRES processus (le jeu du joueur, d'autres agents) sont comptées à part et n'entrent pas dans le verdict.
#   --detache : la commande est lancée SANS console (DETACHED_PROCESS), comme par une tâche de fond ou un lanceur sans
#               terminal : c'est le cas qui fait ouvrir une console visible à chaque programme de console lancé en dessous ;
#   --apres S : continue d'échantillonner S secondes après la fin de la commande (défaut 1,0).
#   --veille S : SANS commande, surveille tout le PC pendant S secondes (à lancer avant de jouer) : chaque fenêtre de
#               console, ou de cmd/powershell/robocopy/python..., qui devient visible est notée avec l'HEURE, sa classe, son
#               processus, la CHAÎNE de ses parents et sa LIGNE DE COMMANDE (lue dans la mémoire du processus pendant qu'il
#               vit) : c'est ainsi qu'on trouve QUI ouvre les fenêtres que le joueur voit. Journal : --garder <fichier>.
# Usage : py -3.9 -B tools/autotest/fenetres.py [--detache] [--apres S] [--garder <fichier json>] -- <commande...>
#         py -3.9 -B tools/autotest/fenetres.py --veille 600 [--garder <fichier>]
# Code : 0 aucune fenêtre visible chez les descendants ; 1 au moins une ; 2 usage.
# Limite : une fenêtre créée et détruite entre deux échantillons (moins de 5 ms) échapperait ; une console vit toute la durée
# de son processus, donc les programmes lancés ici (50 ms et plus) sont vus.
import argparse
import ctypes
import json
import os
import subprocess
import sys
import time
from ctypes import wintypes

user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

DETACHED_PROCESS = 0x00000008
TH32CS_SNAPPROCESS = 0x2
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
INVALID = ctypes.c_void_p(-1).value

ENUM = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
user32.EnumWindows.argtypes = [ENUM, wintypes.LPARAM]
user32.IsWindowVisible.argtypes = [wintypes.HWND]
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
kernel32.OpenProcess.restype = wintypes.HANDLE
kernel32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
kernel32.CloseHandle.argtypes = [wintypes.HANDLE]


class _Proc(ctypes.Structure):
    _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD), ("th32ProcessID", wintypes.DWORD),
                ("th32DefaultHeapID", ctypes.c_size_t), ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD),
                ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", wintypes.LONG), ("dwFlags", wintypes.DWORD),
                ("szExeFile", ctypes.c_wchar * 260)]


def processus():
    """{pid: (ppid, nom d'exécutable)} de tous les processus (Toolhelp32)."""
    res = {}
    h = kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    if not h or h == INVALID:
        return res
    e = _Proc()
    e.dwSize = ctypes.sizeof(_Proc)
    ok = kernel32.Process32FirstW(h, ctypes.byref(e))
    while ok:
        res[e.th32ProcessID] = (e.th32ParentProcessID, e.szExeFile)
        ok = kernel32.Process32NextW(h, ctypes.byref(e))
    kernel32.CloseHandle(h)
    return res


def fenetres():
    """[(hwnd, visible, classe, pid, titre)] des fenêtres de premier niveau."""
    liste = []

    def cb(hwnd, _):
        pid = wintypes.DWORD(0)
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        cls = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(hwnd, cls, 256)
        tit = ctypes.create_unicode_buffer(256)
        user32.GetWindowTextW(hwnd, tit, 256)
        liste.append((int(hwnd or 0), bool(user32.IsWindowVisible(hwnd)), cls.value, pid.value, tit.value))
        return True

    user32.EnumWindows(ENUM(cb), 0)
    return liste


class _PBI(ctypes.Structure):
    _fields_ = [("Reserved1", ctypes.c_void_p), ("PebBaseAddress", ctypes.c_void_p), ("Reserved2", ctypes.c_void_p * 2),
                ("UniqueProcessId", ctypes.c_void_p), ("Reserved3", ctypes.c_void_p)]


def ligne_de_commande(pid):
    """Ligne de commande d'un processus vivant (PEB lu avec ReadProcessMemory, Windows 64 bits) ; « ? » si illisible."""
    if ctypes.sizeof(ctypes.c_void_p) != 8:
        return "?"
    h = kernel32.OpenProcess(0x0410, False, pid)  # PROCESS_QUERY_INFORMATION | PROCESS_VM_READ
    if not h:
        return "?"
    try:
        pbi = _PBI()
        ntdll = ctypes.WinDLL("ntdll")
        if ntdll.NtQueryInformationProcess(h, 0, ctypes.byref(pbi), ctypes.sizeof(pbi), None) != 0:
            return "?"
        lu = ctypes.c_size_t(0)
        ptr = ctypes.c_void_p(0)
        if not kernel32.ReadProcessMemory(h, ctypes.c_void_p(pbi.PebBaseAddress + 0x20), ctypes.byref(ptr), 8, ctypes.byref(lu)):
            return "?"
        us = ctypes.create_string_buffer(16)  # UNICODE_STRING : Length(2) MaxLength(2) pad(4) Buffer(8)
        if not kernel32.ReadProcessMemory(h, ctypes.c_void_p(ptr.value + 0x70), us, 16, ctypes.byref(lu)):
            return "?"
        longueur = int.from_bytes(us.raw[0:2], "little")
        tampon = int.from_bytes(us.raw[8:16], "little")
        if not longueur or longueur > 8192:
            return "?"
        buf = ctypes.create_string_buffer(longueur)
        if not kernel32.ReadProcessMemory(h, ctypes.c_void_p(tampon), buf, longueur, ctypes.byref(lu)):
            return "?"
        return buf.raw.decode("utf-16-le", "replace")
    finally:
        kernel32.CloseHandle(h)


CLASSES_CONSOLE = ("ConsoleWindowClass", "CASCADIA_HOSTING_WINDOW_CLASS", "PseudoConsoleWindow")
EXE_SUSPECTS = ("cmd.exe", "powershell.exe", "pwsh.exe", "conhost.exe", "robocopy.exe", "python.exe", "py.exe", "bash.exe",
                "sh.exe", "wscript.exe", "cscript.exe", "windowsterminal.exe", "openconsole.exe", "findstr.exe", "tasklist.exe",
                "wmic.exe", "git.exe", "taskkill.exe")


def suspecte(classe, exe):
    """Règle pure : une fenêtre devenue visible qui ressemble à un shell."""
    return classe in CLASSES_CONSOLE or exe.lower() in EXE_SUSPECTS


def chaine(pid, parents, noms):
    """« enfant < parent < grand-parent » (noms d'exécutables), au plus 8 niveaux."""
    res = []
    for _ in range(8):
        res.append("%s(%d)" % (noms.get(pid, "?"), pid))
        if pid not in parents or parents[pid] in (0, pid):
            break
        pid = parents[pid]
    return " < ".join(res)


def veille(secondes, journal=None, pas=0.005):
    """Surveille tout le PC : note chaque fenêtre suspecte qui devient visible. Rend la liste des relevés."""
    t0 = time.time()
    parents, noms, cmdl, vues, notes = {}, {}, {}, {}, []
    base = {h for h, v, _, _, _ in fenetres()}
    while time.time() - t0 < secondes:
        for pid, (pp, nom) in processus().items():
            if pid not in parents:
                cmdl[pid] = None
            parents[pid] = pp
            noms[pid] = nom
        for hwnd, vis, cls, pid, tit in fenetres():
            if hwnd in base or not vis or hwnd in vues:
                continue
            exe = noms.get(pid, "?")
            vues[hwnd] = True
            if not suspecte(cls, exe):
                continue
            ligne = ligne_de_commande(pid)
            r = {"heure": time.strftime("%H:%M:%S"), "t": round(time.time() - t0, 3), "classe": cls, "exe": exe, "pid": pid,
                 "chaine": chaine(pid, parents, noms), "ligne": ligne, "titre": tit}
            notes.append(r)
            print("[VEILLE] %s %s %s pid %d ; chaîne %s ; ligne %s" % (r["heure"], cls, exe, pid, r["chaine"], ligne[:200]), flush=True)
            if journal:
                with open(journal, "a", encoding="utf-8") as f:
                    f.write(json.dumps(r, ensure_ascii=False) + "\n")
        time.sleep(pas)
    return notes


def descend_de(pid, racine, parents):
    """Vrai si pid est racine ou en descend (chaîne des parents connus ; au plus 64 pas : pas de boucle sur pid réutilisé)."""
    for _ in range(64):
        if pid == racine:
            return True
        if pid not in parents or parents[pid] == pid or parents[pid] == 0:
            return False
        pid = parents[pid]
    return False


def classer(vues, racine, parents, noms):
    """Règle pure : (miennes visibles, miennes cachées, autres visibles) parmi {hwnd: (visible_un_jour, classe, pid, titre)}.
    Une fenêtre est « mienne » si son processus descend de la commande lancée, ou si son parent (conhost.exe lancé pour une
    console) en descend."""
    mi_v, mi_c, autres = [], [], []
    for hwnd, (vis, cls, pid, tit) in sorted(vues.items()):
        d = {"hwnd": hwnd, "classe": cls, "pid": pid, "exe": noms.get(pid, "?"), "titre": tit}
        mien = descend_de(pid, racine, parents)
        if mien and vis:
            mi_v.append(d)
        elif mien:
            mi_c.append(d)
        elif vis:
            autres.append(d)
    return mi_v, mi_c, autres


def mesurer(cmd, detache=False, apres=1.0, pas=0.005, env=None):
    """Lance cmd et relève les fenêtres ; rend (code, miennes visibles, miennes cachées, autres visibles, nb d'échantillons,
    nb de processus descendants vus)."""
    base = {h for h, _, _, _, _ in fenetres()}
    p = subprocess.Popen(cmd, creationflags=DETACHED_PROCESS if detache else 0, env=env,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    vues, parents, noms = {}, {}, {}
    n = 0
    fin = None
    while True:
        procs = processus()
        for pid, (pp, nom) in procs.items():
            parents[pid] = pp
            noms[pid] = nom
        for hwnd, vis, cls, pid, tit in fenetres():
            if hwnd in base:
                continue
            ancien = vues.get(hwnd)
            vues[hwnd] = (vis or (ancien[0] if ancien else False), cls, pid, tit or (ancien[3] if ancien else ""))
        n += 1
        if p.poll() is not None and fin is None:
            fin = time.time() + apres
        if fin is not None and time.time() >= fin:
            break
        time.sleep(pas)
    mi_v, mi_c, autres = classer(vues, p.pid, parents, noms)
    desc = sum(1 for pid in parents if pid != p.pid and descend_de(pid, p.pid, parents))
    return p.returncode, mi_v, mi_c, autres, n, desc


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--detache", action="store_true")
    ap.add_argument("--apres", type=float, default=1.0)
    ap.add_argument("--garder")
    ap.add_argument("--veille", type=float)
    ap.add_argument("cmd", nargs="*")
    a = ap.parse_args(argv)
    if a.veille:
        notes = veille(a.veille, a.garder)
        print("[VEILLE] BILAN : %d fenêtre(s) de type shell devenue(s) visible(s) en %.0f s" % (len(notes), a.veille))
        return 1 if notes else 0
    if not a.cmd:
        ap.error("une commande après -- ou --veille S")
    t0 = time.time()
    code, mi_v, mi_c, autres, n, desc = mesurer(a.cmd, a.detache, a.apres)
    print(f"[FENETRES] commande {' '.join(a.cmd)} ; {'SANS console (DETACHED_PROCESS)' if a.detache else 'avec la console du lanceur'} ; "
          f"code {code} ; {time.time() - t0:.1f} s ; {n} échantillons ; {desc} processus descendants vus")
    for d in mi_v:
        print(f"[FENETRES]   VISIBLE chez un descendant : classe {d['classe']} ; {d['exe']} (pid {d['pid']}) ; titre « {d['titre']} »")
    for d in mi_c:
        print(f"[FENETRES]   cachée chez un descendant : classe {d['classe']} ; {d['exe']} (pid {d['pid']})")
    print(f"[FENETRES] fenêtres d'autres processus apparues visibles pendant la mesure (hors verdict) : {len(autres)}"
          + "".join(f"\n[FENETRES]   autre : classe {d['classe']} ; {d['exe']} (pid {d['pid']}) ; « {d['titre'][:60]} »" for d in autres[:12]))
    print(f"[FENETRES] BILAN : {len(mi_v)} fenêtre(s) visible(s) chez les descendants, {len(mi_c)} cachée(s)")
    if a.garder:
        with open(a.garder, "w", encoding="utf-8") as f:
            json.dump({"cmd": a.cmd, "detache": a.detache, "code": code, "visibles": mi_v, "cachees": mi_c, "autres": autres,
                       "echantillons": n, "descendants": desc}, f, ensure_ascii=False, indent=1)
    return 1 if mi_v else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
