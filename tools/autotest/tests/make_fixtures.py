"""Fichiers SYNTHÉTIQUES pour éprouver vram.py hors jeu (lot D4m) : vram.tsv (format du pilote visual_session.py)
et perf-stats.csv (colonnes lues dans le binaire 1.1.91, PerformanceLogger.cpp ; le vrai format, l'unité et le sens
des colonnes ne sont PAS prouvés : ce fichier n'éprouve que l'arithmétique de vram.py).

Usage : python -B make_fixtures.py <dossier>
Le fichier de statistiques suit les phases du greffon d4-geant (journal de d4_dryrun.lua : 10 000 ms par vue) :
z030-jour est limitée par le GPU (cpu-frame 12 ms, gpu-frame 16,7 ms : la voie « cpu-frame » surestime), z030-nuit
tourne à 55,5 images/s (555 lignes en 10 s, gpu-frame 18 ms). present-count croît d'une unité par ligne,
refresh-count de 2,4 (écran à 144 Hz pour 60 images/s).
"""
import os
import random
import sys

COLUMNS = ["prepare", "texture-streaming-analysis", "texture-streaming-update", "cpu-render", "cpu-flip", "sleep",
           "cpu-frame", "sprite-count", "draw-call-count", "tiles-rendered", "vt-tiles-requested", "vt-tiles-added",
           "vt-tiles-reused", "vt-tiles-evicted", "vt-tiles-skipped", "gpu-terrain-render", "gpu-draw-engine-render",
           "gpu-frame", "sync-interval", "last-present-count", "present-count", "refresh-count", "sync-refresh-count",
           "frames-skipped"]
# (genre, lignes, sprites, tuiles, cpu-frame ms, gpu-frame ms)
PLAN = [("repere", 180, 0, 1900, 3.0, 2.0),
        ("z030-jour", 600, 60000, 22500, 12.0, 16.6),
        ("repere", 60, 0, 1900, 3.0, 2.0),
        ("z050-jour", 600, 25000, 8100, 6.0, 8.0),
        ("repere", 60, 0, 1900, 3.0, 2.0),
        ("z030-nuit", 555, 70000, 22500, 13.0, 18.0),
        ("repere", 60, 0, 1900, 3.0, 2.0),
        ("z050-nuit", 600, 30000, 8100, 7.0, 9.0),
        ("repere", 60, 0, 1900, 3.0, 2.0),
        ("z030-tetes", 600, 40000, 22500, 10.0, 14.0),  # galerie des tetes (correction du lot D4m-GEANT)
        ("repere", 200, 0, 1900, 3.0, 2.0)]


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    random.seed(1)
    with open(os.path.join(out, "vram.tsv"), "w", newline="\n") as f:
        f.write("t_s\tdedie_o\tpartage_o\tcarte_dedie_o\tram_privee_o\tram_ws_o\n")
        for i in range(0, 130):
            t = i * 0.5
            ded = 0 if t < 1 else min(2.6e9, 0.3e9 + t * 0.6e9) + (0.2e9 if 8 <= t <= 18 else 0)
            f.write("%.2f\t%d\t%d\t%d\t%d\t%d\n" % (t, ded, 0.1e9, ded + 1.5e9, 3.1e9, 2.9e9))
    present, refresh = 1000, 5000.0
    with open(os.path.join(out, "perf-stats.csv"), "w", newline="\n") as f:
        f.write("CPU,12th Gen Intel(R) Core(TM) i5-12600KF\nGPU,AMD Radeon RX 6900 XT\nWindowWidth,1920\nWindowHeight,1080\n")
        f.write(",".join(COLUMNS) + "\n")
        for kind, n, spr, tiles, cpu, gpu in PLAN:
            for _ in range(n):
                sprites = random.randint(0, 20) if kind == "repere" else spr + random.randint(-500, 500)
                present += 1
                refresh += 2.4
                row = {c: 0 for c in COLUMNS}
                row.update({"prepare": cpu * 0.6, "cpu-render": cpu * 0.3, "cpu-flip": 0.4, "cpu-frame": cpu,
                            "sprite-count": sprites, "draw-call-count": sprites // 40, "tiles-rendered": tiles,
                            "gpu-frame": gpu, "sync-interval": 1, "present-count": present,
                            "last-present-count": present - 1, "refresh-count": int(refresh),
                            "sync-refresh-count": int(refresh)})
                f.write(",".join(("%.3f" % row[c]) if isinstance(row[c], float) else str(row[c]) for c in COLUMNS) + "\n")
    print("fixtures ecrites dans " + out)


if __name__ == "__main__":
    main()
