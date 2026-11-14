"""RENDU DES TITANS (lot TITANS, 9/11) : Blender par le verrou de rendu (interdit n° 6), TEMP sur F:.

    py -3.9 tools/render/pieces/titans/rendre_titans.py juggernaut|sentinelle|leviathan [--stages 1,2,3[,drone]] [--samples 48] [--px 40] [--out DIR]
    py -3.9 tools/render/pieces/titans/rendre_titans.py kaiju --anim course|attaque [--images 0,1] [--dirs 0,4] [--samples 32] [--out DIR]
    py -3.9 tools/render/pieces/titans/rendre_titans.py juggernaut --anime --stages 1,2,3 --anim course|attaque [--images ..] [--dirs ..] [--out DIR]

Sorties (défaut, à GARDER, D-6) : fo-logs/2026-11-10_TITANS-FINITIONS/rendu/ : juggernaut-anime-<stage>/ (npz par animation, image et
direction, comme le Kaiju : FINITIONS 10/11), sentinelle-<stage>/ et leviathan-<stage>/ (npy + render.json, puis main.png, shadow.png,
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
LOGS = os.path.join(RACINE, "fo-logs", "2026-11-10_TITANS-FINITIONS")
OUT_DEFAUT = os.path.join(LOGS, "rendu")
TMP = os.environ.get("FO_TMP_RENDU") or os.path.join(LOGS, "tmp")   # LEVIATHAN2 : FO_TMP_RENDU -> TEMP de Blender sur C: (F: est une clé USB lente)


def lancer(args, out, wait):
    tmpd = os.environ.get("FO_TITAN_TMP") or TMP     # TITANS2 : temporaires hors de F: (clé USB) si demandé
    os.makedirs(tmpd, exist_ok=True)
    os.makedirs(out, exist_ok=True)
    prio = ["--priority", os.environ["FO_RENDER_PRIORITY"]] if os.environ.get("FO_RENDER_PRIORITY") else []   # TITANS2 : « normal » (basse par défaut : Windows bride alors Blender à moins d'un cœur)
    cmd = [sys.executable, LOCK, "--wait", str(wait)] + prio + ["--disque", out, "--", BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1",
           "-P", BATCH, "--"] + args
    env = dict(os.environ, PYTHONIOENCODING="utf-8", TEMP=tmpd, TMP=tmpd, TMPDIR=tmpd)
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
    ap.add_argument("what", choices=("juggernaut", "sentinelle", "leviathan", "kaiju", "ecorcheur", "ecorche", "ravageur", "corroder"))
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
    ap.add_argument("--anime", action="store_true", help="allié animé : 8 directions × images (Juggernaut)")
    ap.add_argument("--piece", default="", help="LEVIATHAN-SEG : pièce fixe d'un titan articulé (segment, queue) : --anime --anim pose --piece segment")
    a = ap.parse_args()
    t0 = time.time()
    SANS_STADE = ("kaiju", "ecorcheur", "corroder")   # lot KAIJUS-MUTANTS : une série par ennemi
    if a.anime and a.what not in SANS_STADE:
        args = ["--what", a.what, "--anime", "--stages", a.stages, "--anim", a.anim, "--images", a.images, "--dirs", a.dirs, "--out", a.out,
                "--samples", str(a.samples or 32)]
        if a.glb:
            args.append("--glb")
        if a.piece:
            args += ["--piece", a.piece]
        rc = lancer(args, a.out, a.wait)
        if rc:
            sys.exit(rc)
    elif a.what not in SANS_STADE:
        if not a.post_only:
            args = ["--what", a.what, "--stages", a.stages, "--out", a.out, "--samples", str(a.samples or 48), "--px", str(a.px)]
            if a.glb:
                args.append("--glb")
            rc = lancer(args, a.out, a.wait)
            if rc:
                sys.exit(rc)
        import rendre as XR  # post des géants : npy -> main/shadow/glow_*.png + spec.json (même format que les géants)
        for st in [x for x in a.stages.split(",") if x]:
            s = XR.post("%s-%s" % (a.what, st), a.out, a.out, None)
            print("[FO-POST] %s-%s %s" % (a.what, st, sorted(s["layers"])), flush=True)
    else:
        args = ["--what", a.what, "--anim", a.anim, "--images", a.images, "--dirs", a.dirs, "--out", a.out, "--samples", str(a.samples or 32)]
        if a.glb:
            args.append("--glb")
        rc = lancer(args, a.out, a.wait)
        if rc:
            sys.exit(rc)
    print("[FO-RENDRE-TITANS] %.0f s en tout" % (time.time() - t0), flush=True)


if __name__ == "__main__":
    main()
