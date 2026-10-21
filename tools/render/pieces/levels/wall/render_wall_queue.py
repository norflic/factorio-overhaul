"""File d'attente des aperçus du mur, TOUJOURS par le verrou de rendu officiel (lot V3, phase 1).

    python tools/render/pieces/levels/wall/render_wall_queue.py [--levels 2-30] [--poses droit,isole]
                                                                [--samples 32] [--retry 0.3] [--batch 1]

Chaque prise du verrou rend un LOT de --batch niveaux (toutes les poses demandées) :
    python tools/render/with_render_lock.py --wait 0 -- python -P render_wall.py --levels a,b,c --poses P
Code 2 (aucune place) : on réessaie après --retry secondes. Le verrou garde ses règles (2 places, priorité
basse, verrous orphelins repris).
Historique : passe 3 (21/10), une variante par prise (with_render_lock.py n'essaie qu'une fois toutes les 5 s
quand il attend) ; passe 4 (22/10, 01 h 20 à 01 h 46) : les 7 familles rendent en même temps, deux d'entre
elles par lots de 100 variantes et plus, et le mur, qui libérait la place toutes les 15 s, n'en retrouvait
plus (26 minutes sans rendu). D'où --batch (lot d'environ 1 min 30 par prise pour 3 niveaux).
Sortie : la même que render_wall.py (render_results.json fusionné).
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
    ap.add_argument("--retry", type=float, default=0.3)
    ap.add_argument("--batch", type=int, default=1, help="niveaux par prise du verrou")
    a = ap.parse_args()
    t_all = time.time()
    failed = []
    levels = parse_levels(a.levels)
    chunks = [levels[i:i + a.batch] for i in range(0, len(levels), max(1, a.batch))]
    for chunk in chunks:
        lv_arg = ",".join(str(v) for v in chunk)
        cmd = [sys.executable, LOCK, "--wait", "0", "--", sys.executable, "-P", RW, "--levels", lv_arg, "--poses",
               a.poses, "--samples", str(a.samples)]
        t0 = time.time()
        tries = 0
        while True:
            tries += 1
            p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
            if p.returncode != 2 or "[FO-WALL]" in p.stdout:
                break
            time.sleep(a.retry)
        lines = [x for x in p.stdout.splitlines() if x.startswith("[FO-WALL] n") or "ECHEC" in x]
        expected = ["n%02d-%s" % (lv, pose) for lv in chunk for pose in a.poses.split(",") if pose]
        done = [v for v in expected if any(l.startswith("[FO-WALL] %s " % v) for l in lines)]
        for v in expected:
            if v not in done:
                failed.append(v)
        print("[FO-WALL-Q] niveaux %s : %d/%d variantes, attente+rendu %.1f s (%d essais)" % (
            lv_arg, len(done), len(expected), time.time() - t0, tries), flush=True)
        for l in lines:
            print("    " + l[:160], flush=True)
        if len(done) < len(expected):
            print("    " + (p.stdout[-600:] + p.stderr[-600:]).strip().replace("\n", "\n    "), flush=True)
    print("[FO-WALL-Q] total %.1f s ; échecs : %s" % (time.time() - t_all, failed or "aucun"), flush=True)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
