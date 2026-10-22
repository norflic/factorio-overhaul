"""Dominance époque par époque (niveaux impairs 19 à 29) avec tools/da/progression.py de la charte, SANS le modifier,
sur les mesures de mesure.py (une pose par fichier).

    py -3.9 tools/render/pieces/levels/gun_e_haut/prog_e.py <outils charte> <mesures.json> <sortie.txt>

progression.py lit la famille « mitrailleuse » et garde les niveaux impairs ; les familles absentes font échouer la
fin du script après l'impression de la mitrailleuse : on ne garde que cette partie de la sortie.
"""
import json
import os
import subprocess
import sys


def main():
    outils, mes, out = sys.argv[1:4]
    rows = [dict(r, famille="mitrailleuse") for r in json.load(open(mes, encoding="utf-8"))["niveaux"]]
    p = out + ".json"
    json.dump(rows, open(p, "w", encoding="utf-8"), ensure_ascii=False)
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    res = subprocess.run([sys.executable, os.path.join(outils, "progression.py"), p], capture_output=True, env=env)
    keep = []
    for ln in res.stdout.decode("utf-8", "replace").splitlines():
        if ln.startswith("laser"):
            break
        keep.append(ln)
    s = "\n".join(keep)
    open(out, "w", encoding="utf-8").write(s + "\n")
    print(s)


if __name__ == "__main__":
    main()
