"""Le verrou de rendu PARTAGÉ (tools/render/with_render_lock.py, inchangé) avec une scrutation de 0,5 s.

    python tools/render/pieces/levels/gun/lock_poll.py -- <commande...>

Pourquoi : le verrou n'a pas de file d'attente ; la première scrutation qui trouve une place libre la prend.
Le 21/10 (22 h 35), d'autres agents scrutaient toutes les 0,5 s (option --poll d'une version modifiée du
script) contre 5 s ici : les deux places leur revenaient à chaque libération (environ 50 min d'attente sans
obtenir de place). Ce module appelle with_render_lock.main tel quel (mêmes dossiers de verrou, 2 places au
plus sur le PC, priorité « inférieure à la normale ») ; seule l'attente entre deux scrutations est ramenée à
0,5 s. Besoin signalé au pipeline : une file d'attente équitable dans with_render_lock.py (lot V0b).
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, RENDER)
import with_render_lock as W  # noqa: E402

_sleep = time.sleep


class _Time:
    """Façade du module time pour with_render_lock : sleep plafonné à 0,5 s, le reste inchangé."""

    def __getattr__(self, k):
        return getattr(time, k)

    @staticmethod
    def sleep(s):
        _sleep(min(s, 0.5))


W.time = _Time()

if __name__ == "__main__":
    sys.exit(W.main(sys.argv[1:]))
