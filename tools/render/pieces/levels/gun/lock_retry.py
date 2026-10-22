"""Relance la commande PRESCRITE du verrou de rendu jusqu'à obtenir une place (lot V3 gun, reprise 3).

    python tools/render/pieces/levels/gun/lock_retry.py -- <commande...>

Chaque essai est exactement « python tools/render/with_render_lock.py --wait 0 -- <commande> » (script partagé
INCHANGÉ : mêmes dossiers de verrou, 2 places au plus sur le PC, priorité « inférieure à la normale »). Si aucune
place n'est libre, le script partagé rend le code 2 sans rien lancer ; on réessaie 0,5 s plus tard.

Pourquoi : le verrou n'a pas de file d'attente. Le 22/10 (1 h 05 à 1 h 50), les 6 autres familles relançaient
« --wait 0 » en boucle serrée : la scrutation de 5 s du script partagé n'a obtenu aucune place en 45 min. On
s'aligne sur la même cadence, sans rien changer au verrou. Besoin signalé au pipeline : une file équitable.
"""
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
LOCK = os.path.normpath(os.path.join(HERE, "..", "..", "..", "with_render_lock.py"))
MARK = "aucune place libre"


def main(argv):
    if "--" not in argv:
        print(__doc__)
        return 1
    cmd = argv[argv.index("--") + 1:]
    t0, n = time.time(), 0
    while True:
        n += 1
        p = subprocess.Popen([sys.executable, LOCK, "--wait", "0", "--"] + cmd, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT)
        busy = False
        for raw in p.stdout:
            line = raw.decode("utf-8", errors="replace")
            if MARK in line:
                busy = True
                continue
            sys.stdout.write(line)
            sys.stdout.flush()
        rc = p.wait()
        if rc == 2 and busy:
            if n % 600 == 1:
                print("[lock_retry] pas de place (%d essais, %.0f s)" % (n, time.time() - t0), flush=True)
            time.sleep(0.5)
            continue
        print("[lock_retry] place obtenue après %d essai(s), %.0f s ; code %d" % (n, time.time() - t0, rc), flush=True)
        return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
