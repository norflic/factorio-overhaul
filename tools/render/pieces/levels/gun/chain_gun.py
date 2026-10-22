"""Enchaîne, sous UNE seule place du verrou de rendu, l'export de géométrie des têtes et le rendu d'aperçu des
variantes de la famille gun (lot V3 phase 1, reprise 3).

    python tools/render/pieces/levels/gun/lock_retry.py -- python tools/render/pieces/levels/gun/chain_gun.py \
        [--samples 32] [--names a,b,...] [--no-geo]

Pourquoi : 7 familles se disputent 2 places sans file d'attente (22/10 : plus de 45 min par place) ; une seule
acquisition pour l'export (1 min) et les 86 variantes (≈ 25 min) évite une seconde attente. Les processus
Blender héritent de la priorité « inférieure à la normale » posée par with_render_lock.py (Windows : un enfant
d'un processus BELOW_NORMAL reçoit cette classe). Le post-traitement (render_gun.py --post-only), les silhouettes
(geo.py) et les mesures se font ENSUITE, hors du verrou (Python système, sans Blender).
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gun as G  # noqa: E402

MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", ".."))
BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
GEO = os.path.join(MOD, "tools", "render", "cache", "levels-gun", "geo")
CACHE = os.path.join(MOD, "tools", "render", "cache", "levels-gun", "cycles")


def blender(script, args):
    cmd = [BLENDER, "-b", "--factory-startup", "-noaudio", "-P", os.path.join(HERE, script), "--"] + args
    print("[chain] " + " ".join(cmd[-6:]), flush=True)
    return subprocess.call(cmd)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--names", default="")
    ap.add_argument("--no-geo", action="store_true")
    a = ap.parse_args()
    if not a.no_geo:
        heads = ",".join("e%02d-tete-N" % e for e in range(2, 16))
        rc = blender("geo_export.py", ["--out", GEO, "--only", heads])
        if rc:
            return rc
    names = [n for n in a.names.split(",") if n] or sorted(G.PIECE["variants"])
    os.makedirs(CACHE, exist_ok=True)
    return blender("render_batch.py", ["--names", ",".join(names), "--out", CACHE, "--samples", str(a.samples)])


if __name__ == "__main__":
    sys.exit(main())
