"""File d'attente des aperçus du mur : UNE variante par prise du verrou de rendu (lot V3, phase 1).

    python tools/render/pieces/levels/wall/render_wall_queue.py [--levels 2-30] [--poses droit,isole]
                                                                [--samples 32] [--retry 0.5]

Pourquoi : render_wall.py sous un seul verrou garde la place pendant toute la série (20 min) et, en attente,
with_render_lock.py n'essaie qu'une fois toutes les 5 s ; les autres familles prennent le verrou variante par
variante (« --wait 0 ») et réessaient aussitôt : la série entière attendait plus d'une heure (21/10, 21 h 45 à
22 h 50). Ici chaque variante est un appel distinct, TOUJOURS par le verrou officiel :
    python tools/render/with_render_lock.py --wait 0 -- python -P render_wall.py --levels N --poses P
Code 2 (aucune place) : on réessaie après --retry secondes. Le verrou garde ses règles (2 places, priorité
basse, verrous orphelins repris). Sortie : la même que render_wall.py (render_results.json fusionné).
"""
import argparse
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
LOCK = os.path.join(RENDER, "with_render_lock.py")
RW = os.path.join(HERE, "render_wall.py")
sys.path.insert(0, HERE)
from render_wall import parse_levels  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="2-30")
    ap.add_argument("--poses", default="droit,isole")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--retry", type=float, default=0.5)
    a = ap.parse_args()
    t_all = time.time()
    failed = []
    for lv in parse_levels(a.levels):
        for pose in [p for p in a.poses.split(",") if p]:
            cmd = [sys.executable, LOCK, "--wait", "0", "--", sys.executable, "-P", RW, "--levels", str(lv), "--poses",
                   pose, "--samples", str(a.samples)]
            t0 = time.time()
            tries = 0
            while True:
                tries += 1
                p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
                if p.returncode != 2 or "[FO-WALL]" in p.stdout:
                    break
                time.sleep(a.retry)
            line = [x for x in p.stdout.splitlines() if x.startswith("[FO-WALL] n")]
            ok = p.returncode == 0 and line
            if not ok:
                failed.append("n%02d-%s" % (lv, pose))
            print("[FO-WALL-Q] n%02d-%s %s attente+rendu %.1f s (%d essais) %s" % (
                lv, pose, "OK" if ok else "ECHEC", time.time() - t0, tries, (line[0] if line else p.stdout[-400:] +
                                                                           p.stderr[-400:]).strip()), flush=True)
    print("[FO-WALL-Q] total %.1f s ; échecs : %s" % (time.time() - t_all, failed or "aucun"), flush=True)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
