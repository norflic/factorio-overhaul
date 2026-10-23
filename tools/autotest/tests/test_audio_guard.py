"""Banc du garde de silence (audio_guard.py, lot S0, correction) SUR LA VRAIE SORTIE AUDIO du PC, sans Factorio.

    python -B tools/autotest/tests/test_audio_guard.py

Deux processus Python enfants, surveillés chacun par un garde neuf :
  - témoin NÉGATIF : l'enfant dort 2,5 s sans ouvrir de son → aucune session, crête 0, pas de violation, l'enfant
    finit seul (code 0) ;
  - témoin POSITIF : l'enfant joue, par winsound, 3 s d'un son INAUDIBLE (30 Hz, −70 dBFS, crête 0,000316 ; même
    témoin que la vérification du lot, verif\\temoin.py) → le garde voit sa session audio Windows, note la violation
    et TUE l'enfant (son PID seulement) avant la fin du son (code de l'enfant non nul, en moins de 2 s).
Le garde lui-même ne lit que des PID et des crêtes. Code de sortie : 0 si tous les contrôles passent.
"""
import os
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
import audio_guard  # noqa: E402

ok = fail = 0

CHILD_TONE = r'''
import math, struct, sys, time, wave, winsound
p = sys.argv[1]
fs, amp = 44100, 10 ** (-70 / 20)
with wave.open(p, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(fs)
    w.writeframes(b"".join(struct.pack("<h", int(round(32767 * amp * math.sin(2 * math.pi * 30 * i / fs))))
                           for i in range(fs * 3)))
time.sleep(0.5)
winsound.PlaySound(p, winsound.SND_FILENAME)
'''
CHILD_QUIET = "import time; time.sleep(2.5)"


def check(cond, label):
    global ok, fail
    if cond:
        ok += 1
    else:
        fail += 1
    print("%s %s" % ("OK    " if cond else "ECHEC ", label))


def run(code, args, wait):
    g = audio_guard.Guard()
    err = g.start_and_wait()
    if err:
        g.stop()
        return g, None, err, 0.0
    child = subprocess.Popen([sys.executable, "-I", "-c", code] + args)
    t0 = time.time()
    g.watch(child.pid, child.terminate)
    try:
        rc = child.wait(timeout=wait)
    except subprocess.TimeoutExpired:
        child.kill()
        rc = child.wait()
    dt = time.time() - t0
    time.sleep(0.2)
    g.stop()
    return g, rc, None, dt


def main():
    work = tempfile.mkdtemp(prefix="fo-garde-")
    try:
        g, rc, err, dt = run(CHILD_QUIET, [], 10)
        check(err is None, "garde prete (COM, %d sortie(s) active(s))%s" % (g.outputs, "" if not err else " : " + err))
        print("       " + g.report())
        check(rc == 0 and g.violation is None and g.sessions_seen == 0 and g.max_peak == 0.0 and g.rounds > 50,
              "temoin negatif : enfant silencieux, aucune session, crete 0, %d tours, fin seule (code %s, %.1f s)" % (
                  g.rounds, rc, dt))
        wav = os.path.join(work, "temoin-30hz-moins70dbfs.wav")
        g, rc, err, dt = run(CHILD_TONE, [wav], 15)
        print("       " + g.report())
        check(err is None and g.violation is not None and g.sessions_seen >= 1,
              "temoin positif : session audio de l'enfant vue, violation notee (%s)" % g.violation)
        check(rc not in (None, 0) and dt < 3.4,
              "temoin positif : enfant TUE par le garde avant la fin du son (code %s, %.2f s apres le lancement ; "
              "son de 3 s commence a 0,5 s)" % (rc, dt))
    finally:
        for f in os.listdir(work):
            os.remove(os.path.join(work, f))
        os.rmdir(work)
    print("BILAN : %d OK, %d ECHEC(S)" % (ok, fail))
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
