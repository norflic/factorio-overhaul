# Lot OUTILLAGE (28/10) : lancer un sous-processus de CONSOLE sans qu'aucune fenêtre ne s'ouvre chez le joueur.
#
# Le constat du DC en jouant : « je vois des shells qui s'ouvrent et qui se ferment ». Sous Windows, un programme de
# console lancé par un processus qui n'a PAS de console (processus détaché, lancé par une tâche de fond, pythonw...) reçoit
# une console NEUVE et VISIBLE ; chaque cmd.exe, powershell.exe, robocopy.exe... des lanceurs du banc ouvre alors une
# fenêtre qui se ferme à sa fin. Le remède est de le lancer avec CREATE_NO_WINDOW (la console existe, cachée, et ses
# enfants la partagent) et un STARTUPINFO qui cache la fenêtre. La priorité BELOW_NORMAL évite en plus de gêner une
# partie en cours (le benchmark lui-même reste lancé par « start /ABOVENORMAL » dans fo-autotest.bat : mesures inchangées).
#
# À NE PAS utiliser pour le jeu avec images (fo-visual : sa fenêtre doit exister, réduite) : seulement pour des programmes
# de console dont la sortie est capturée (stdout=PIPE ou fichier), car un enfant en CREATE_NO_WINDOW n'écrit plus dans la
# console du parent.
#
# Variable FO_BANC_PRIORITE=normal : pas de priorité réduite (les fenêtres restent cachées).
import os
import subprocess

CREATE_NO_WINDOW = 0x08000000
BELOW_NORMAL_PRIORITY_CLASS = 0x00004000
NORMAL_PRIORITY_CLASS = 0x00000020
SW_HIDE = 0


def priorite_voulue(environ=None):
    """« below » (défaut) ou « normal » : règle pure, lue dans FO_BANC_PRIORITE."""
    env = os.environ if environ is None else environ
    return "normal" if (env.get("FO_BANC_PRIORITE") or "").strip().lower() == "normal" else "below"


def drapeaux(priorite="below"):
    """creationflags d'un programme de console caché."""
    return CREATE_NO_WINDOW | (BELOW_NORMAL_PRIORITY_CLASS if priorite == "below" else NORMAL_PRIORITY_CLASS)


def options(priorite=None):
    """Arguments à ajouter à subprocess.run / Popen : {} hors Windows (rien à cacher)."""
    if os.name != "nt":
        return {}
    si = subprocess.STARTUPINFO()
    si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    si.wShowWindow = SW_HIDE
    return {"creationflags": drapeaux(priorite or priorite_voulue()), "startupinfo": si}


def run(cmd, priorite=None, **kw):
    """subprocess.run sans fenêtre."""
    kw.update(options(priorite))
    return subprocess.run(cmd, **kw)


def popen(cmd, priorite=None, **kw):
    """subprocess.Popen sans fenêtre."""
    kw.update(options(priorite))
    return subprocess.Popen(cmd, **kw)


# --- Sa propre console -------------------------------------------------------------------------------------------------
# Un lanceur SANS console (tâche de fond, planificateur, application graphique) qui démarre « py -3.9 banc.py » fait ouvrir
# une console VISIBLE à py.exe, et elle reste ouverte toute la durée du banc (des heures dans la file) : c'est la « fenêtre
# qui s'ouvre et se ferme » du joueur. Le programme la cache dès qu'il démarre, MAIS seulement si cette console n'est
# partagée avec personne d'autre que lui et son lanceur « py » : jamais le terminal d'un humain (cmd, PowerShell, Git Bash).
LANCEURS_PY = ("py.exe", "pyw.exe")


def console_a_cacher(pids_console, moi, parent, nom_du_parent):
    """Règle pure : vrai si tous les processus attachés à la console sont ce programme et, au plus, son lanceur py.exe."""
    if not pids_console:
        return False
    for p in pids_console:
        if p == moi:
            continue
        if p == parent and nom_du_parent.lower() in LANCEURS_PY:
            continue
        return False
    return True


def _nom_du_processus(pid):
    import ctypes
    from ctypes import wintypes
    k = ctypes.WinDLL("kernel32", use_last_error=True)
    k.OpenProcess.restype = wintypes.HANDLE
    h = k.OpenProcess(0x1000, False, pid)
    if not h:
        return ""
    try:
        buf = ctypes.create_unicode_buffer(1024)
        n = wintypes.DWORD(1024)
        if k.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(n)):
            return os.path.basename(buf.value)
        return ""
    finally:
        k.CloseHandle(h)


def _parent_de(pid):
    import ctypes
    from ctypes import wintypes

    class PE(ctypes.Structure):
        _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD), ("th32ProcessID", wintypes.DWORD),
                    ("th32DefaultHeapID", ctypes.c_size_t), ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD),
                    ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", wintypes.LONG), ("dwFlags", wintypes.DWORD),
                    ("szExeFile", ctypes.c_wchar * 260)]
    k = ctypes.WinDLL("kernel32", use_last_error=True)
    k.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    h = k.CreateToolhelp32Snapshot(0x2, 0)
    e = PE()
    e.dwSize = ctypes.sizeof(PE)
    try:
        ok = k.Process32FirstW(h, ctypes.byref(e))
        while ok:
            if e.th32ProcessID == pid:
                return e.th32ParentProcessID
            ok = k.Process32NextW(h, ctypes.byref(e))
    finally:
        k.CloseHandle(h)
    return 0


def cacher_ma_console():
    """Cache la fenêtre de console de ce processus si elle n'est qu'à lui (et à son py.exe). Rend vrai si cachée.
    Sans effet hors Windows, sans console, ou quand la console est celle d'un shell : le terminal d'un humain reste visible."""
    if os.name != "nt":
        return False
    try:
        import ctypes
        k = ctypes.WinDLL("kernel32", use_last_error=True)
        u = ctypes.WinDLL("user32", use_last_error=True)
        hwnd = k.GetConsoleWindow()
        if not hwnd:
            return False
        tab = (ctypes.c_ulong * 32)()
        n = k.GetConsoleProcessList(tab, 32)
        if n == 0 or n > 32:
            return False
        moi = os.getpid()
        parent = _parent_de(moi)
        if console_a_cacher(list(tab[:n]), moi, parent, _nom_du_processus(parent) if parent else ""):
            u.ShowWindow(ctypes.c_void_p(hwnd), SW_HIDE)
            return True
    except Exception:
        return False
    return False
