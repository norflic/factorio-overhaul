"""Appel de Blender en ligne de commande (Python système). Chemins toujours absolus.

Blender attendu : C:\\Users\\evan2\\tools\\blender-5.2.2\\blender.exe (surcharge : variable
d'environnement FO_BLENDER). Voir README.md pour l'installation vérifiée.
"""
import json
import os
import subprocess
import time

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_BLENDER = r"C:\Users\evan2\tools\blender-5.2.2\blender.exe"
ENTRY = os.path.join(HERE, "blender", "render_piece.py")


def blender_exe():
    return os.environ.get("FO_BLENDER", DEFAULT_BLENDER)


def render(piece, variant, out_dir, samples=None, sets=(), layers=None, margin=None, log=None):
    """Rend une variante d'une pièce ; renvoie (infos du rendu, durée en s)."""
    piece = os.path.abspath(piece)
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)
    cmd = [blender_exe(), "-b", "--factory-startup", "-noaudio", "-P", ENTRY, "--",
           "--piece", piece, "--out", out_dir, "--variant", variant]
    if samples:
        cmd += ["--samples", str(samples)]
    if layers:
        cmd += ["--layers", ",".join(layers)]
    if margin is not None:
        cmd += ["--margin", str(margin)]
    for s in sets:
        cmd += ["--set", s]
    t0 = time.time()
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    dt = time.time() - t0
    if log:
        with open(log, "a", encoding="utf-8") as f:
            f.write(" ".join(cmd) + "\n" + p.stdout[-4000:] + p.stderr[-4000:] + "\n")
    name = None
    for line in p.stdout.splitlines():
        if line.startswith("[FO-RENDER]"):
            name = line.split()[1]
    if p.returncode != 0 or name is None:
        raise RuntimeError("échec du rendu Blender (%s/%s) :\n%s\n%s" % (piece, variant, p.stdout[-3000:], p.stderr[-3000:]))
    with open(os.path.join(out_dir, name + "-render.json"), encoding="utf-8") as f:
        info = json.load(f)
    info["_dir"] = out_dir
    info["_prefix"] = name
    return info, dt
