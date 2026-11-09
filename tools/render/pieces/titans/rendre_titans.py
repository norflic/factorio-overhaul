"""RENDU DES TITANS (lot TITANS, 9/11) : Blender par le verrou de rendu (interdit n° 6), TEMP sur F:.

    py -3.9 tools/render/pieces/titans/rendre_titans.py juggernaut [--stages 1,2,3] [--samples 48] [--px 40] [--out DIR]
    py -3.9 tools/render/pieces/titans/rendre_titans.py kaiju --anim course|attaque [--images 0,1] [--dirs 0,4] [--samples 32] [--out DIR]

Sorties (défaut, à GARDER, D-6) : fo-logs/2026-11-09_TITANS/rendu/ : juggernaut-<stage>/ (npy + render.json, puis main.png, shadow.png,
glow_*.png et spec.json par le post de experimentaux/rendre.py) ; kaiju/kaiju-<anim>-<image>-<dir>.npz. Journal : rendu/rendre.log.
Puis : feuilles_titans.py (feuilles de jeu), planches_titans.py (planches du DC).
"""
import argparse
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(RENDER, "pieces", "experimentaux"))

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
BATCH = os.path.join(HERE, "batch_titans.py")
RACINE = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
LOGS = os.path.join(RACINE, "fo-logs", "2026-11-09_TITANS")
OUT_DEFAUT = os.path.join(LOGS, "rendu")
TMP = os.path.join(LOGS, "tmp")


def lancer(args, out, wait):
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(out, exist_ok=True)
    cmd = [sys.executable, LOCK, "--wait", str(wait), "--disque", out, "--", BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1",
           "-P", BATCH, "--"] + args
    env = dict(os.environ, PYTHONIOENCODING="utf-8", TEMP=TMP, TMP=TMP, TMPDIR=TMP)
    t0 = time.time()
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    log = []
    for raw in p.stdout:
        line = raw.decode("utf-8", "replace").rstrip()
        log.append(line)
        if line.startswith("[FO-TITAN]") or "Error" in line or "Traceback" in line or "[fo-render]" in line:
            print(line, flush=True)
    rc = p.wait()
    with open(os.path.join(out, "rendre.log"), "a", encoding="utf-8") as f:
        f.write(" ".join(args) + "\n" + "\n".join(log[-400:]) + "\n")
    print("[FO-BATCH] %s : %.0f s, code %d" % (args[1], time.time() - t0, rc), flush=True)
    if rc:
        print("\n".join(log[-40:]))
    return rc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("what", choices=("juggernaut", "kaiju"))
    ap.add_argument("--stages", default="1,2,3")
    ap.add_argument("--anim", default="course")
    ap.add_argument("--images", default="")
    ap.add_argument("--dirs", default="")
    ap.add_argument("--samples", type=int, default=0)
    ap.add_argument("--px", type=float, default=40.0)
    ap.add_argument("--out", default=OUT_DEFAUT)
    ap.add_argument("--wait", type=int, default=14400)
    ap.add_argument("--glb", action="store_true")
    ap.add_argument("--post-only", action="store_true")
    a = ap.parse_args()
    t0 = time.time()
    if a.what == "juggernaut":
        if not a.post_only:
            args = ["--what", "juggernaut", "--stages", a.stages, "--out", a.out, "--samples", str(a.samples or 48), "--px", str(a.px)]
            if a.glb:
                args.append("--glb")
            rc = lancer(args, a.out, a.wait)
            if rc:
                sys.exit(rc)
        import rendre as XR  # post des géants : npy -> main/shadow/glow_*.png + spec.json (même format que les géants)
        for st in [int(x) for x in a.stages.split(",") if x]:
            s = XR.post("juggernaut-%d" % st, a.out, a.out, None)
            print("[FO-POST] juggernaut-%d %s" % (st, sorted(s["layers"])), flush=True)
    else:
        args = ["--what", "kaiju", "--anim", a.anim, "--images", a.images, "--dirs", a.dirs, "--out", a.out, "--samples", str(a.samples or 32)]
        if a.glb:
            args.append("--glb")
        rc = lancer(args, a.out, a.wait)
        if rc:
            sys.exit(rc)
    print("[FO-RENDRE-TITANS] %.0f s en tout" % (time.time() - t0), flush=True)


if __name__ == "__main__":
    main()
