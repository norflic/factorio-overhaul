"""PRODUCTION DES SOUCHES (lot BI-V1) : une image de chaque animation à la fois, chacune par le verrou de rendu, pour rendre la main aux autres agents.
    PYTHONUTF8=1 py -3.9 tools/render/pieces/biters/produire.py [--souches moucheron,ecraseur] [--samples 32] [--dirs 0,10] [--images 0]
Reprenable : ce qui existe n'est pas refait. Sources dans fo-logs/2026-11-01_BIV1/rendu (à GARDER, D-6). Code 0 : tout est là.
"""
import argparse
import glob
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
RACINE = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
OUT = os.path.join(RACINE, "fo-logs", "2026-11-01_BIV1", "rendu")
BLENDER = r"C:\Users\evan2\tools\blender-5.2.2\blender.exe"
IMAGES = {"moucheron": {"course": 6, "attaque": 3}, "ecraseur": {"course": 6, "attaque": 3}}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--souches", default="moucheron,ecraseur")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--dirs", default="")
    ap.add_argument("--images", default="")
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    choix = [int(x) for x in a.images.split(",") if x]
    nd = len(a.dirs.split(",")) if a.dirs else 16
    code = 0
    for s in a.souches.split(","):
        for anim, nb in IMAGES[s].items():
            for i in range(nb):
                if choix and i not in choix:
                    continue
                d = os.path.join(a.out, s)
                if a.dirs:
                    fait = sum(os.path.exists(os.path.join(d, "%s-%s-%02d-%02d.npz" % (s, anim, i, int(k)))) for k in a.dirs.split(","))
                else:
                    fait = len(glob.glob(os.path.join(d, "%s-%s-%02d-*.npz" % (s, anim, i))))
                if fait >= nd:
                    continue
                cmd = [sys.executable, os.path.join(RENDER, "with_render_lock.py"), "--wait", "14400", "--", BLENDER, "-b", "--factory-startup", "-noaudio",
                       "-P", os.path.join(HERE, "serie_blender.py"), "--", "--souche", s, "--anim", anim, "--image", str(i), "--out", d, "--samples", str(a.samples)]
                if a.dirs:
                    cmd += ["--dirs", a.dirs]
                p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
                l = [x for x in p.stdout.splitlines() if x.startswith("[FO-BITER]")]
                print(l[-1] if l else "ECHEC %s %s %d code %d\n%s" % (s, anim, i, p.returncode, (p.stdout + p.stderr)[-1500:]), flush=True)
                if not l:
                    code = 1
    print("[FO-PRODUCTION] code", code, flush=True)
    return code


if __name__ == "__main__":
    sys.exit(main())
