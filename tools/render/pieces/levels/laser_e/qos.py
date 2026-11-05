"""Bridage d'économie d'énergie (EcoQoS, « power throttling ») des sessions Blender de la production du laser (lot F1-C,
5/11 ; choix « b » du lead : sans EcoQoS, en BelowNormal, retour au STOP quand le DC joue). Python 3.9, Windows, ctypes.

Fait mesuré (4/11, 20 h 20) : une session Blender lancée par le verrou de rendu (priorité BelowNormal, sans fenêtre)
n'utilisait que 2,5 cœurs sur 16 (têtes de l'âge 10 : 90 s au lieu de 36 s) ; lancée d'un processus détaché à fenêtre
cachée, une seule passe durait 15 min. Hypothèse : Windows range ce processus de fond en EcoQoS, donc sur les cœurs E.
Ce module retire (ou remet) l'EcoQoS d'UN processus par SetProcessInformation(ProcessPowerThrottling) ; la priorité
BelowNormal posée par with_render_lock.py n'est pas touchée. Aucun autre processus n'est modifié.
"""
import ctypes
from ctypes import wintypes

PROCESS_SET_INFORMATION = 0x0200
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
PROCESS_POWER_THROTTLING_CURRENT_VERSION = 1
PROCESS_POWER_THROTTLING_EXECUTION_SPEED = 0x1
PROCESS_POWER_THROTTLING_CLASS = 4          # ProcessPowerThrottling (PROCESS_INFORMATION_CLASS)
TH32CS_SNAPPROCESS = 0x2

_k32 = ctypes.WinDLL("kernel32", use_last_error=True)


class _PPTS(ctypes.Structure):
    _fields_ = [("Version", wintypes.ULONG), ("ControlMask", wintypes.ULONG), ("StateMask", wintypes.ULONG)]


class _PE32(ctypes.Structure):
    _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD), ("th32ProcessID", wintypes.DWORD),
                ("th32DefaultHeapID", ctypes.c_size_t), ("th32ModuleID", wintypes.DWORD),
                ("cntThreads", wintypes.DWORD), ("th32ParentProcessID", wintypes.DWORD),
                ("pcPriClassBase", ctypes.c_long), ("dwFlags", wintypes.DWORD),
                ("szExeFile", ctypes.c_wchar * 260)]


_k32.SetProcessInformation.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
_k32.SetProcessInformation.restype = wintypes.BOOL
_k32.OpenProcess.restype = wintypes.HANDLE
_k32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE


def processus():
    """[(pid, parent, nom)] de tous les processus (instantané Toolhelp)."""
    h = _k32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    res = []
    if not h or h == wintypes.HANDLE(-1).value:
        return res
    try:
        e = _PE32()
        e.dwSize = ctypes.sizeof(_PE32)
        ok = _k32.Process32FirstW(h, ctypes.byref(e))
        while ok:
            res.append((e.th32ProcessID, e.th32ParentProcessID, e.szExeFile))
            ok = _k32.Process32NextW(h, ctypes.byref(e))
    finally:
        _k32.CloseHandle(h)
    return res


def descendants(pid, nom=None):
    """PID des descendants de `pid` (de nom `nom`, insensible à la casse, si donné)."""
    procs = processus()
    enfants = {}
    for p, pp, n in procs:
        enfants.setdefault(pp, []).append((p, n))
    res, pile, vus = [], [pid], set()
    while pile:
        q = pile.pop()
        for p, n in enfants.get(q, []):
            if p in vus or p == q:
                continue
            vus.add(p)
            pile.append(p)
            if nom is None or n.lower() == nom.lower():
                res.append(p)
    return res


def ecoqos(pid, actif):
    """actif False : EcoQoS retiré (vitesse d'exécution non bridée) ; True : EcoQoS imposé. Rend (ok, erreur)."""
    h = _k32.OpenProcess(PROCESS_SET_INFORMATION | PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not h:
        return False, ctypes.get_last_error()
    try:
        s = _PPTS(PROCESS_POWER_THROTTLING_CURRENT_VERSION, PROCESS_POWER_THROTTLING_EXECUTION_SPEED,
                  PROCESS_POWER_THROTTLING_EXECUTION_SPEED if actif else 0)
        ok = _k32.SetProcessInformation(h, PROCESS_POWER_THROTTLING_CLASS, ctypes.byref(s), ctypes.sizeof(s))
        return bool(ok), (0 if ok else ctypes.get_last_error())
    finally:
        _k32.CloseHandle(h)
