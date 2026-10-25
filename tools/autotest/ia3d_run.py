# Lot IA3-DIAG : lance les bancs de mesure l'un après l'autre (verrou partagé : code 2 = attendre 30 s et recommencer),
# puis archive les journaux utiles (benchmark.log compressé, create.log, done.txt, seed.txt, source.txt) dans
# <racine>\fo-logs\2026-10-25_IA3-DIAG\bancs\<nom>.
# Usage : py -3.9 ia3d_run.py <source du mod> <nom:scenario:ticks:graine> [...]
import gzip
import os
import shutil
import subprocess
import sys
import time

RACINE = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
# Lot IA3-a : dossier de sortie réglable par IA3D_OUT (défaut : les bancs d'IA3-DIAG).
OUT = os.environ.get("IA3D_OUT") or os.path.join(RACINE, "fo-logs", "2026-10-25_IA3-DIAG", "bancs")
BAT = os.path.join(RACINE, "fo-autotest.bat")
RES = os.path.join(RACINE, "fo-autotest")
ATTENTE_MAX = 30 * 60


def run(source, nom, scenario, ticks, graine):
    env = dict(os.environ)
    if graine:
        env["FO_MAP_SEED"] = graine
    else:
        env.pop("FO_MAP_SEED", None)
    env.pop("FO_CREATE_SRC", None)
    env.pop("FO_AUDIO", None)
    t0 = time.time()
    while True:
        p = subprocess.run([BAT, "nopause", str(ticks), scenario, source], env=env, cwd=RACINE,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if p.returncode not in (0, 2):
            print(p.stdout.decode("cp850", "replace")[-1500:], flush=True)
        if p.returncode != 2:
            break
        if time.time() - t0 > ATTENTE_MAX:
            print(f"[IA3D] {nom} : verrou pris depuis plus de 30 min, abandon", flush=True)
            return 2
        time.sleep(30)
    dt = time.time() - t0
    dest = os.path.join(OUT, nom)
    os.makedirs(dest, exist_ok=True)
    for f in ("create.log", "done.txt", "seed.txt", "source.txt"):
        src = os.path.join(RES, f)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(dest, f))
    bl = os.path.join(RES, "benchmark.log")
    if os.path.exists(bl):
        with open(bl, "rb") as fi, gzip.open(os.path.join(dest, "benchmark.log.gz"), "wb") as fo:
            shutil.copyfileobj(fi, fo)
    print(f"[IA3D] {nom} : code {p.returncode}, {dt:.0f} s", flush=True)
    return p.returncode


def main():
    source = sys.argv[1]
    for spec in sys.argv[2:]:
        nom, scenario, ticks, graine = spec.split(":")
        run(source, nom, scenario, int(ticks), graine)


if __name__ == "__main__":
    main()
