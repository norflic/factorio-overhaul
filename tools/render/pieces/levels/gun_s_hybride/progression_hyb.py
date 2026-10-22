"""Dominance de puissance (charte §6.1) des niveaux hybrides avec l'outil de l'analyste, SANS le modifier.

    python progression_hyb.py <mesures.json de mesure.py> <dossier de sortie> [pose E|N]

progression.py (charte/outils) lit une liste de mesures, ne garde que les niveaux impairs d'une famille et compare
les époques successives (emprise, masse, pièces, foyers lumineux). On lui donne :
- A : mitrailleuse vanilla (niveau 1, époque 1, mesures_vanilla.json) puis n11, n21, n29 (pose demandée) ;
- B : n29 puis n30 ; n30 est un niveau PAIR de la même époque, que progression.py écarterait : il est présenté
  sous l'époque 16 et le niveau 31 (relabel déclaré dans la sortie, aucun chiffre changé).
Le script de l'analyste est exécuté tel quel, avec sa liste de familles réduite à « mitrailleuse » (les trois
autres familles n'ont pas de lignes ici et feraient échouer rows[0]).
"""
import json
import os
import sys

CHARTE = os.environ.get("FO_CHARTE", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3S\charte\outils")


def run(rows, path):
    json.dump(rows, open(path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    src = open(os.path.join(CHARTE, "progression.py"), encoding="utf-8").read()
    src = src.replace('("mitrailleuse", "laser", "assembleur", "centre")', '("mitrailleuse",)')
    old = sys.argv
    sys.argv = ["progression.py", path]
    try:
        exec(compile(src, "progression.py", "exec"), {"__name__": "__main__"})
    finally:
        sys.argv = old


def main():
    mes, out = sys.argv[1], sys.argv[2]
    pose = sys.argv[3] if len(sys.argv) > 3 else "E"
    os.makedirs(out, exist_ok=True)
    rows = [r for r in json.load(open(mes, encoding="utf-8")) if r["pose"] == pose]
    van = [r for r in json.load(open(os.path.join(os.path.dirname(CHARTE), "mesures_vanilla.json"), encoding="utf-8"))
           if r["nom"] == "gun-turret"][0]
    van = dict(van, famille="mitrailleuse", niveau=1, epoque=1)
    A = [van] + [dict(r, famille="mitrailleuse") for r in rows if r["niveau"] in (11, 21, 29)]
    print("== A : vanilla n1 -> n11 -> n21 -> n29 (pose %s)" % pose)
    run(A, os.path.join(out, "progression_A_%s.json" % pose))
    r29 = [r for r in rows if r["niveau"] == 29][0]
    r30 = [r for r in rows if r["niveau"] == 30][0]
    B = [dict(r29, famille="mitrailleuse"), dict(r30, famille="mitrailleuse", niveau=31, epoque=16)]
    print("== B : n29 -> n30 (pose %s ; n30 présenté comme « époque 16, niveau 31 » pour l'outil)" % pose)
    run(B, os.path.join(out, "progression_B_%s.json" % pose))


if __name__ == "__main__":
    main()
