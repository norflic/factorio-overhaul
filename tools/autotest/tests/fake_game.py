"""FAUX jeu (aucun lien avec Factorio) pour l'essai d'intégration de visual_session.py (driver_it.py) : lit ses
arguments et le config.ini DE TEST comme le ferait le binaire, écrit un journal (réglages, écran, atlas, lignes
PHASE et CHAMP du journal de l'essai à blanc), des captures, le marqueur de fin, puis (fin « naturelle ») les
statistiques de rendu et le résumé du mode benchmark. Variables : FAKE_FIXTURE (dossier des fixtures),
FAKE_FORCE_QUALITY et FAKE_FORCE_DXT (le « jeu » ignore la demande : le pilote doit rendre le code 9)."""
import os
import shutil
import sys
import time

from PIL import Image

args = sys.argv[1:]


def opt(name):
    return args[args.index(name) + 1] if name in args else None


cfg = opt("--config")
ini = open(cfg, encoding="utf-8").read()
keys = dict(ln.split("=", 1) for ln in ini.splitlines() if "=" in ln)
write = keys["write-data"]
quality = os.environ.get("FAKE_FORCE_QUALITY") or opt("--graphics-quality") or keys.get("graphics-quality", "high")
vmu = opt("--video-memory-usage") or keys.get("video-memory-usage", "all")
dxt = os.environ.get("FAKE_FORCE_DXT") or keys.get("texture-compression-level", "high-quality")
fixture = os.environ["FAKE_FIXTURE"]
os.makedirs(write, exist_ok=True)
log = open(os.path.join(write, "factorio-current.log"), "w", encoding="utf-8")
log.write("   0.000 2026-10-21 23:00:00; Factorio 1.1.91 (build 61680, win64, full)\n")
log.write("   0.001 Program arguments: %s\n" % " ".join('"%s"' % a for a in args))
log.write("   0.114 Display options: [FullScreen: 0] [VSync: 1] [UIScale: automatic (100.0%)] [Lang: fr]\n")
log.write("   0.337  [0]: \\\\.\\DISPLAY25 - AMD Radeon RX 6900 XT {0x80005, [0,0], 3840x2160, 32bit, 144Hz}\n")
log.write("   0.300 Graphics options: [Graphics quality: %s] [Video memory usage: %s] [DXT: %s] [Color: 32bit]\n" % (
    quality, vmu, dxt))
log.write("   0.301                   [Max threads (load/render): 32/16] [Max texture size: 0] [Tex.Stream.: 0]\n")
log.write("   1.000 Created atlas bitmap 16384x16380 [none]\n   1.001 Created atlas bitmap 8192x2272 [icon, not-compressed, mipmap]\n")
log.write("   2.000 Generated mipmaps (5) for atlas [1] of size 8192x2272\n   2.100 Sprites loaded\n   2.200 Factorio initialised\n")
for ln in open(os.path.join(fixture, "factorio.log"), encoding="utf-8"):
    if "PHASE" in ln or "CHAMP" in ln:
        log.write(ln)
log.flush()
shots = os.path.join(write, "script-output", "fo-shots")
os.makedirs(shots, exist_ok=True)
open(os.path.join(shots, "plan.txt"), "w").write("2 captures prevues, scenario d4-geant\n")
with open(os.path.join(shots, "index.tsv"), "w") as f:
    f.write("num\tfichier\tscene\tx\ty\tzoom\tdaytime\ttick\tresolution\talt_mode\tanti_alias\n")
    for i, n in ((1, "usine-z030-jour"), (2, "usine-z050-nuit")):
        Image.new("RGB", (160, 90), (40 * i, 80, 120)).save(os.path.join(shots, "%03d-%s.png" % (i, n)))
        f.write("%03d\t%03d-%s.png\t%s\t208\t-2\t0.3\t0\t%d\t1600x900\t0\t1\n" % (i, i, n, n, 2790 + 10 * i))
time.sleep(1.5)
open(os.path.join(shots, "done.txt"), "w").write("termine 2 captures, tick 2911\n")
time.sleep(2.5)  # fin « naturelle » du budget de ticks
perf = opt("--output-perf-stats")
if perf:
    shutil.copy(os.path.join(fixture, "perf-stats.csv"), perf)
print("  Performed 3000 updates in 50000.000 ms")
print("  avg: 16.667 ms, min: 0.500 ms, max: 80.000 ms")
log.write("  60.000 Quitting: automatic-quit.\n")
log.close()
sys.exit(0)
