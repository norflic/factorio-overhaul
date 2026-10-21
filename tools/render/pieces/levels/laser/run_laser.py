"""Tourelle laser, lot V3 phase 1 : pilote (Python système). Blender passe TOUJOURS par le verrou de rendu.

    python tools/render/pieces/levels/laser/run_laser.py dry   [--levels 2-30]
    python tools/render/pieces/levels/laser/run_laser.py render --levels 3,4 [--parts base,N,E,S,W] [--samples 32]
    python tools/render/pieces/levels/laser/run_laser.py all   [--samples 32] [--batch 6]   (rendu + post)
    python tools/render/pieces/levels/laser/run_laser.py post  [--levels ...]
    python tools/render/pieces/levels/laser/run_laser.py tune  (pivots : O mesuré sur la géométrie -> cible §4)
    python tools/render/with_render_lock.py -- python tools/render/pieces/levels/laser/run_laser.py pipeline --nolock
          (réglage des pivots + rendu + post-traitement de tous les niveaux sous UNE prise du verrou ; Blender
          reste séquentiel : 1 seul rendu à la fois pour ce pilote)

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


NOLOCK = False   # vrai seulement quand le pilote entier tourne déjà sous with_render_lock.py (commande pipeline)


def blender(args, log_name):
    pre = [] if NOLOCK else [sys.executable, LOCK, "--"]
    cmd = pre + [fo_blender.blender_exe(), "-b", "--factory-startup", "-noaudio", "-P", ENTRY, "--"] + args
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


def o_max_by_epoch():
    """O maximal (4 poses) de chaque niveau impair, mesuré sur les triangles exportés par le mode sec."""
    import numpy as np
    import geo_check as G
    import laser_design as D
    out = {}
    for e in range(2, 16):
        p = os.path.join(G.GEO, "geo-L%02d.npz" % (2 * e - 1))
        g = np.load(p)
        bx, by = G.screen(g["base"])
        tops = []
        for d in ("N", "E", "S", "W"):
            hx, hy = G.screen(G.rot(g["head"], D.DIRECTIONS[d]))
            tops.append(min(by.min(), hy.min()))
        out[e] = (-min(tops) - 1.0, -by.min() - 1.0)
    return out


def tune(rounds=3):
    """Règle le pivot de chaque époque pour que O (sommet des 4 poses) tombe sur la cible du §4 (±0,01 tuile).
    y écran = -K (Y + Z) : monter le pivot de dz monte la tête de K dz. Écrit pivot_regle.txt (lu par laser_design)."""
    import importlib
    import laser_design as D
    K = 0.5 ** 0.5
    for r in range(rounds):
        blender(["--dry", "--levels", ",".join(str(2 * e - 1) for e in range(2, 16)), "--out", os.path.join(RAW, "geo")],
                "dry.log")
        om = o_max_by_epoch()
        lines = ["# pivot réglé par run_laser.py tune (tour %d) : époque pivot   # O mesuré -> cible (O du socle seul)" % (r + 1)]
        worst = 0.0
        for e in range(2, 16):
            o, ob = om[e]
            tgt = D.O_TARGET[e]
            # on ne touche qu'aux époques hors tolérance (±0,01 tuile) : les autres gardent le pivot de leur rendu
            new = D.PIVOT[e] + (tgt - o) / K if abs(o - tgt) > 0.01 else D.PIVOT[e]
            new = max(D.PIVOT_MIN[e], new)
            worst = max(worst, abs(o - tgt))
            lines.append("%d %.4f   # O %.3f -> %.2f (socle %.2f), pivot précédent %.4f" % (e, new, o, tgt, ob, D.PIVOT[e]))
        print("\n".join(lines), flush=True)
        if worst <= 0.01:
            print("[tune] O sur la cible à 0,01 près pour les 14 époques", flush=True)
            return
        with open(D.PIVOT_FILE, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
        importlib.reload(D)
    print("[tune] écart restant après %d tours (voir pivot_regle.txt)" % rounds, flush=True)


def main():
    global NOLOCK
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["dry", "render", "post", "all", "tune", "pipeline"])
    ap.add_argument("--nolock", action="store_true", help="déjà sous with_render_lock.py (ne pas reprendre le verrou)")
    ap.add_argument("--levels", default="2-30")
    ap.add_argument("--parts", default="base,N,E,S,W")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--batch", type=int, default=6, help="niveaux par prise du verrou (partage des 2 places)")
    a = ap.parse_args()
    NOLOCK = a.nolock
    levels = levels_from(a.levels)
    if a.cmd == "tune":
        tune()
        return
    if a.cmd == "pipeline":
        if not NOLOCK:
            raise SystemExit("pipeline : à lancer sous tools/render/with_render_lock.py avec --nolock")
        tune()
        blender(["--dry", "--levels", "2-30", "--out", os.path.join(RAW, "geo")], "dry.log")
        a.cmd = "all"
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
