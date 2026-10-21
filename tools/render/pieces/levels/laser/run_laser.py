"""Tourelle laser, lot V3 phase 1 : pilote (Python système). Blender passe TOUJOURS par le verrou de rendu.

    python tools/render/pieces/levels/laser/run_laser.py dry   [--levels 2-30]
    python tools/render/pieces/levels/laser/run_laser.py render --levels 3,4 [--parts base,N,E,S,W] [--samples 32]
    python tools/render/pieces/levels/laser/run_laser.py all   [--samples 32] [--batch 6]   (rendu + post)
    python tools/render/pieces/levels/laser/run_laser.py post  [--levels ...]

Poses rendues (phase 1, Q12) : socle (1 direction) pour les niveaux 2 à 30 ; tête « prepared » N, E, S, O
pour les niveaux IMPAIRS 3 à 29 (le niveau pair garde la tête de son impair : la pièce va sur le socle).
Sorties (ignorées par git) : tools/render/out/levels/laser/.
"""
import argparse
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
OUT = os.path.join(RENDER, "out", "levels", "laser")
RAW = os.path.join(RENDER, "cache", "levels-laser")
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)
import fo_blender  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except AttributeError:
    pass
LOCK = os.path.join(RENDER, "with_render_lock.py")
ENTRY = os.path.join(HERE, "render_laser.py")


def levels_from(spec):
    out = []
    for part in spec.split(","):
        if "-" in part:
            a, b = part.split("-")
            out += list(range(int(a), int(b) + 1))
        elif part:
            out.append(int(part))
    return out


def jobs_for(levels, parts):
    jobs = []
    for lv in levels:
        for p in parts:
            if p == "base" and lv >= 2:
                jobs.append("L%02d:base" % lv)
            elif p != "base" and lv >= 3 and lv % 2 == 1:
                jobs.append("L%02d:%s" % (lv, p))
    return jobs


def blender(args, log_name):
    cmd = [sys.executable, LOCK, "--", fo_blender.blender_exe(), "-b", "--factory-startup", "-noaudio", "-P", ENTRY, "--"] + args
    os.makedirs(RAW, exist_ok=True)
    t0 = time.time()
    with open(os.path.join(RAW, log_name), "a", encoding="utf-8") as log:
        log.write("\n$ " + " ".join(cmd) + "\n")
        log.flush()
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                           errors="replace")
        log.write(p.stdout)
    lines = [ln for ln in p.stdout.splitlines() if ln.startswith("[FO-") or "Error" in ln or "Traceback" in ln
             or ln.startswith("[fo-render]")]
    print("\n".join(lines[-80:]))
    print("[run_laser] code %d en %.0f s" % (p.returncode, time.time() - t0), flush=True)
    if p.returncode != 0:
        print(p.stdout[-4000:])
        raise SystemExit(p.returncode)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["dry", "render", "post", "all"])
    ap.add_argument("--levels", default="2-30")
    ap.add_argument("--parts", default="base,N,E,S,W")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--batch", type=int, default=6, help="niveaux par prise du verrou (partage des 2 places)")
    a = ap.parse_args()
    levels = levels_from(a.levels)
    if a.cmd == "dry":
        blender(["--dry", "--levels", a.levels, "--out", os.path.join(RAW, "geo")], "dry.log")
        return
    if a.cmd in ("render", "all"):
        for i in range(0, len(levels), a.batch):
            chunk = levels[i:i + a.batch]
            jobs = jobs_for(chunk, a.parts.split(","))
            if jobs:
                blender(["--jobs", ",".join(jobs), "--out", RAW, "--samples", str(a.samples)], "render.log")
            if a.cmd == "all":
                import post_laser
                post_laser.run(chunk)
    if a.cmd == "post":
        import post_laser
        post_laser.run(levels)


if __name__ == "__main__":
    main()
