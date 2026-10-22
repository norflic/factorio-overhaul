"""File de rendus du four (lot V3, phase 1) : quelques niveaux (--batch) par prise du verrou de rendu, pour partager
équitablement les 2 places du PC avec les autres familles (le verrou est rendu entre deux niveaux).

    python -P tools/render/pieces/levels/furnace/queue.py --levels 2-30 [--samples 32] [--quick]

Chaque niveau : python tools/render/with_render_lock.py --wait 0 -- python -P render_levels.py --levels n ;
code 2 (aucune place libre) → nouvel essai 1,5 s plus tard. Blender n'est JAMAIS lancé hors du verrou.
"""
import argparse
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import render_levels as RL  # noqa: E402


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="2-30")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--batch", type=int, default=4, help="niveaux rendus par prise du verrou (environ 3 min)")
    a = ap.parse_args()
    lock = os.path.join(RENDER, "with_render_lock.py")
    lv = RL.parse_levels(a.levels)
    for b in range(0, len(lv), a.batch):
        group = lv[b:b + a.batch]
        n = group[0]
        cmd = [sys.executable, lock, "--wait", "0", "--", sys.executable, "-P", os.path.join(HERE, "render_levels.py"),
               "--levels", ",".join(str(x) for x in group), "--samples", str(a.samples)] + (["--quick"] if a.quick else [])
        t0 = time.time()
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        while True:
            r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
            out = (r.stdout or "") + (r.stderr or "")
            if r.returncode == 2 and "aucune place libre" in out:
                time.sleep(1.5)
                continue
            break
        lines = [l for l in out.splitlines() if "FO-V3" in l or "Error" in l or "Traceback" in l]
        print("%s rc=%d attente+rendu %.0f s : %s" % (",".join("n%02d" % x for x in group), r.returncode, time.time() - t0,
                                                         " | ".join(lines) or out[-400:]), flush=True)
        if r.returncode != 0:
            print(out[-3000:], flush=True)


if __name__ == "__main__":
    main()
