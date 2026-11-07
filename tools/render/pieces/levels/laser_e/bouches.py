"""BOUCHE DU FAISCEAU de la tourelle laser (lot F1-C, 4/11) : mesure sur la géométrie (bouche_blender.py, par le verrou de
rendu, aucun rendu, moins d'une minute) et conversion en points du moteur. Python 3.9.

    py -3.9 tools/render/pieces/levels/laser_e/bouches.py [--ages 2-15] [--out laser_e/bouches.json]

Écrit laser_e/bouches.json (COMMITÉ, lu par feuilles.py) : pour chaque âge, la mesure brute (unités Blender) et le tir
du prototype :
  source_offset = {0, −L}   (attack_parameters, tourné avec la tête : source_direction_count 64)
  hauteur       = H         (action_delivery.source_offset = {0, −H}, vertical à l'écran, non tourné)
avec L = y_bouche (portée horizontale de la bouche : 1 unité Blender = 1 tuile, la tête tourne autour de l'axe vertical
sans étirement) et H = z_bouche × sin θ (θ = 45°, fo_calib : hauteur vue à l'écran). Modèle du moteur (B, vérifié en moteur réel) : le
faisceau part de position + projection(rotation(source_offset)) + (0, −H), la projection écrasant y par cos θ ; c'est le
modèle sur lequel la vanilla est dessinée (centroïde de la lueur de sa lentille, hr-laser-turret-shooting-light.png : en
hauteur, à 0,01 tuile près en NE et E, 0,13 en S ; sans projection, 0,38 en S ; fo-logs/2026-11-04_LASER-F1C/NOTES-
PRODUCTION.md). Vérifié en moteur réel (4/11) : captures du scénario f1-lasers, faisceaux de la vanilla et des âges 2, 6,
10, 14 et 15 dans 8 directions, partis du point prévu.
"""
import argparse
import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, RENDER)
import fo_calib as C  # noqa: E402

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
SORTIE = os.path.join(HERE, "bouches.json")


def tir(m):
    """Mesure brute (unités Blender) -> points du prototype (tuiles)."""
    return {"source_offset": [0.0, -round(m["y_bouche"], 4)], "hauteur": round(m["z_bouche"] * C.SIN_T, 4)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ages", default="2-15")
    ap.add_argument("--out", default=SORTIE)
    a = ap.parse_args()
    brut = os.path.splitext(os.path.abspath(a.out))[0] + "-brut.json"
    cmd = [sys.executable, LOCK, "--", BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1",
           "-P", os.path.join(HERE, "bouche_blender.py"), "--", "--out", brut, "--ages", a.ages]
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    texte = p.stdout.decode("utf-8", "replace")
    for l in texte.splitlines():
        if "[FO-BOUCHE]" in l or "Error" in l or "Traceback" in l:
            print(l)
    if p.returncode:
        print(texte[-3000:])
        return p.returncode
    mes = json.load(open(brut, encoding="utf-8"))
    os.remove(brut)
    res = {"outil": "tools/render/pieces/levels/laser_e/bouches.py", "theta_deg": C.THETA_DEG, "ages": {}}
    for e in sorted(mes, key=int):
        res["ages"][e] = dict(mes[e], tir=tir(mes[e]))
        t = res["ages"][e]["tir"]
        print("[FO-BOUCHES] âge %2s : source_offset {0, %.3f}, hauteur %.3f" % (e, t["source_offset"][1], t["hauteur"]))
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1, sort_keys=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
