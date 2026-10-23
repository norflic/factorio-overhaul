#!/usr/bin/env python3
"""Garde de silence de la session de test avec son (lot S0, correction du défaut bloquant de la vérification).

Constat de la vérification (fo-logs\\2026-10-24_S0\\verification.md §1) : avec les 9 volumes du config.ini de test à
0, la session avec images (FO_AUDIO=1, pilote SDL « wasapi ») a émis du son sur la sortie du PC (crête −34,6 dBFS,
86 % des relevés). Deux protections, l'une derrière l'autre :
  1. visual_session.py lance le factorio.exe de test, et lui seul, avec SDL_AUDIODRIVER=disk (pilote SDL
     « direct-to-disk audio » : la sortie est écrite dans un fichier, rien n'atteint Windows ; « dummy » n'existe pas
     dans le SDL de Factorio 1.1.91, qui retombe alors sur wasapi) ;
  2. ce garde relève, toutes les 10 ms, les sessions audio Windows (WASAPI, IAudioSessionManager2 et
     IAudioMeterInformation, en LECTURE SEULE) de toutes les sorties actives. Si le processus de test y possède
     une session (il a ouvert une vraie sortie) ou si sa crête n'est pas nulle, le garde TUE ce processus (son PID
     seulement) et note la violation ; le pilote rend alors le code 10.

Aucun réglage audio de Windows ni d'un autre processus n'est lu au-delà du PID et de la crête, ni modifié.
Seuls ctypes et la bibliothèque standard sont utilisés (pas de comtypes, pas de pycaw).
Banc : python -B tools/autotest/tests/test_audio_guard.py (témoin positif à −70 dBFS, témoin négatif).
"""
import ctypes
import ctypes.wintypes as wt
import threading
import time

HR = ctypes.HRESULT
CLSCTX_ALL = 0x17
E_RENDER, DEVICE_STATE_ACTIVE = 0, 1
COINIT_MULTITHREADED = 0


class GUID(ctypes.Structure):
    _fields_ = [("D1", ctypes.c_ulong), ("D2", ctypes.c_ushort), ("D3", ctypes.c_ushort), ("D4", ctypes.c_ubyte * 8)]


def _guid(text):
    g = GUID()
    ctypes.OleDLL("ole32").CLSIDFromString(ctypes.c_wchar_p("{" + text + "}"), ctypes.byref(g))
    return g


CLSID_MMDEVICEENUMERATOR = "BCDE0395-E52F-467C-8E3D-C4579291692E"
IID_IMMDEVICEENUMERATOR = "A95664D2-9614-4F35-A746-DE8DB63617E6"
IID_IAUDIOSESSIONMANAGER2 = "77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"
IID_IAUDIOSESSIONCONTROL2 = "BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"
IID_IAUDIOMETERINFORMATION = "C02216F6-8C67-4B5B-9D00-D008E73E0064"


def _vcall(obj, idx, restype, *argtypes):
    """Méthode n° idx de la table virtuelle d'une interface COM (0 à 2 : IUnknown)."""
    vt = ctypes.cast(ctypes.c_void_p(obj), ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p)))[0]
    fn = ctypes.WINFUNCTYPE(restype, ctypes.c_void_p, *argtypes)(vt[idx])
    return lambda *a: fn(obj, *a)


def _release(obj):
    if obj:
        _vcall(obj, 2, ctypes.c_ulong)()


def _qi(obj, iid):
    out = ctypes.c_void_p()
    _vcall(obj, 0, HR, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))(ctypes.byref(iid), ctypes.byref(out))
    return out.value


class Meter:
    """Relevé des sessions audio des sorties actives (à créer et utiliser dans UN SEUL fil, COM initialisé)."""

    def __init__(self):
        self.ole32 = ctypes.OleDLL("ole32")
        self.iid_asm2 = _guid(IID_IAUDIOSESSIONMANAGER2)
        self.iid_asc2 = _guid(IID_IAUDIOSESSIONCONTROL2)
        self.iid_ami = _guid(IID_IAUDIOMETERINFORMATION)
        self.managers = []
        en = ctypes.c_void_p()
        self.ole32.CoCreateInstance(ctypes.byref(_guid(CLSID_MMDEVICEENUMERATOR)), None, CLSCTX_ALL,
                                    ctypes.byref(_guid(IID_IMMDEVICEENUMERATOR)), ctypes.byref(en))
        col = ctypes.c_void_p()
        try:
            _vcall(en.value, 3, HR, ctypes.c_int, wt.DWORD, ctypes.POINTER(ctypes.c_void_p))(
                E_RENDER, DEVICE_STATE_ACTIVE, ctypes.byref(col))
            n = ctypes.c_uint()
            _vcall(col.value, 3, HR, ctypes.POINTER(ctypes.c_uint))(ctypes.byref(n))
            for i in range(n.value):
                d = ctypes.c_void_p()
                _vcall(col.value, 4, HR, ctypes.c_uint, ctypes.POINTER(ctypes.c_void_p))(i, ctypes.byref(d))
                m = ctypes.c_void_p()
                try:
                    _vcall(d.value, 3, HR, ctypes.POINTER(GUID), wt.DWORD, ctypes.c_void_p,
                           ctypes.POINTER(ctypes.c_void_p))(ctypes.byref(self.iid_asm2), CLSCTX_ALL, None,
                                                            ctypes.byref(m))
                    self.managers.append(m.value)
                finally:
                    _release(d.value)
        finally:
            _release(col.value)
            _release(en.value)

    def sessions(self, pids):
        """Compteurs de crête des sessions dont le PID est dans pids : [IAudioMeterInformation*] (à relâcher)."""
        found = []
        for mgr in self.managers:
            se = ctypes.c_void_p()
            _vcall(mgr, 5, HR, ctypes.POINTER(ctypes.c_void_p))(ctypes.byref(se))
            try:
                n = ctypes.c_int()
                _vcall(se.value, 3, HR, ctypes.POINTER(ctypes.c_int))(ctypes.byref(n))
                for i in range(n.value):
                    c = ctypes.c_void_p()
                    _vcall(se.value, 4, HR, ctypes.c_int, ctypes.POINTER(ctypes.c_void_p))(i, ctypes.byref(c))
                    c2 = None
                    try:
                        c2 = _qi(c.value, self.iid_asc2)
                        pid = wt.DWORD()
                        try:
                            _vcall(c2, 14, HR, ctypes.POINTER(wt.DWORD))(ctypes.byref(pid))
                        except OSError:
                            continue  # session de plusieurs processus (AUDCLNT_S_NO_SINGLE_PROCESS) : pas la nôtre
                        if pid.value in pids:
                            found.append(_qi(c.value, self.iid_ami))
                    finally:
                        _release(c2)
                        _release(c.value)
            finally:
                _release(se.value)
        return found

    @staticmethod
    def peak(meter):
        p = ctypes.c_float()
        _vcall(meter, 3, HR, ctypes.POINTER(ctypes.c_float))(ctypes.byref(p))
        return p.value

    def close(self):
        for m in self.managers:
            _release(m)
        self.managers = []


class Guard(threading.Thread):
    """Fil de garde : prêt (COM, sorties énumérées) avant le lancement, puis surveille le PID donné par watch()."""

    def __init__(self, period=0.01, enum_period=0.1):
        super().__init__(daemon=True)
        self.period, self.enum_period = period, enum_period
        self.ready = threading.Event()
        self.stopping = threading.Event()
        self.error = None          # garde indisponible : aucune session avec son ne doit être lancée
        self.outputs = 0           # sorties audio actives énumérées
        self.pid = None
        self.on_violation = None
        self.violation = None      # texte de la première violation
        self.t_watch = None
        self.t_violation = None
        self.reads = 0             # relevés de crête faits sur une session du processus de test
        self.rounds = 0            # tours de surveillance (toutes les period s)
        self.enums = 0             # énumérations des sessions
        self.sessions_seen = 0     # sessions audio Windows du processus de test vues (au plus fort)
        self.max_peak = 0.0
        self.nonzero = 0

    def watch(self, pid, on_violation):
        self.on_violation = on_violation
        self.t_watch = time.time()
        self.pid = pid

    def _violate(self, text):
        if self.violation is None:
            self.violation = text
            self.t_violation = time.time()
            cb = self.on_violation
            if cb:
                try:
                    cb()
                except Exception:  # noqa : le processus a pu se terminer entre-temps
                    pass

    def run(self):
        ole32 = ctypes.OleDLL("ole32")
        try:
            ole32.CoInitializeEx(None, COINIT_MULTITHREADED)
        except OSError as exc:
            self.error = "COM : %s" % exc
            self.ready.set()
            return
        meter = None
        try:
            meter = Meter()
            self.outputs = len(meter.managers)
            meter.sessions(set())  # un premier tour complet : l'énumération des sessions marche
        except OSError as exc:
            self.error = "WASAPI : %s" % exc
            self.ready.set()
            if meter:
                meter.close()
            return
        self.ready.set()
        meters, last_enum = [], 0.0
        try:
            while not self.stopping.is_set():
                pid = self.pid
                if pid is not None and self.violation is None:
                    now = time.time()
                    if now - last_enum >= self.enum_period:
                        for m in meters:
                            _release(m)
                        try:
                            meters = meter.sessions({pid})
                        except OSError:
                            meters = []
                        self.enums += 1
                        last_enum = now
                        if meters:
                            self.sessions_seen = max(self.sessions_seen, len(meters))
                    self.rounds += 1
                    for m in meters:
                        try:
                            p = Meter.peak(m)
                        except OSError:
                            continue
                        self.reads += 1
                        self.max_peak = max(self.max_peak, p)
                        if p > 0:
                            self.nonzero += 1
                    if self.max_peak > 0:
                        self._violate("crete de sortie NON NULLE du processus de test : %.6f" % self.max_peak)
                    elif meters:
                        self._violate("le processus de test a ouvert %d session(s) audio Windows (vraie sortie, "
                                      "pas le pilote disk)" % len(meters))
                time.sleep(self.period)
        finally:
            for m in meters:
                _release(m)
            meter.close()
            try:
                ole32.CoUninitialize()
            except OSError:
                pass

    def start_and_wait(self, timeout=15.0):
        """Démarre le fil et attend qu'il soit prêt : None si prêt, sinon le motif (garde indisponible)."""
        self.start()
        if not self.ready.wait(timeout):
            return "garde non prete apres %.0f s" % timeout
        return self.error

    def stop(self):
        self.stopping.set()
        if self.is_alive():
            self.join(5)

    def report(self):
        dur = (time.time() - self.t_watch) if self.t_watch else 0.0
        return ("garde de crete : %d sortie(s) audio active(s) surveillee(s), %d tours en %.1f s (toutes les %d ms), "
                "%d enumerations des sessions ; sessions audio Windows du processus de test : %d ; releves de crete "
                "sur ces sessions : %d, dont %d non nuls ; crete max %.6f%s" % (
                    self.outputs, self.rounds, dur, round(self.period * 1000), self.enums, self.sessions_seen,
                    self.reads, self.nonzero, self.max_peak,
                    "" if not self.violation else " ; VIOLATION a %.2f s : %s" % (
                        self.t_violation - self.t_watch, self.violation)))
