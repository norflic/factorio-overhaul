# Lot DEFENSE : lecture des archives du scenario dc-defense (tools/autotest/fo-autotest/scenarios/dc-defense.lua) et comparaison
# temoin / essai selon fo-logs/2026-11-02_DEFENSE/CRITERES.md.
# Usage : py -3.9 -B tools/autotest/defense_mesures.py --temoin <dossier> [<dossier>...] --essai <dossier> [<dossier>...]
#   chaque dossier : une archive banc.py (benchmark.log.gz ou benchmark.log) ; l'ordre des dossiers de --temoin et de --essai est celui des graines.
import argparse
import gzip
import re
import sys
from pathlib import Path

MES = re.compile(r"\[FO-DEF-MESURE\] minute (\d+) \| (\S+) \| tourelles=(\d+) pres_qg15=(\d+) pres_qg40=(\d+) pieces_prod=(\d+)")
PERTE = re.compile(r"\[FO-DEF-PERTE\] (\S+) \| vagues=(\d+) \| pieces_prod_perdues=(\d+) dont_hors_portee_de_tourelle=(\d+) \| "
                   r"tourelles_perdues=(\d+) \| pire_vague_prod=(\d+) pire_vague_tourelles=(\d+)")
TOTAL = re.compile(r"\[FO-DEF-PERTE\] TOTAL \| vagues=(\d+) \| pieces_prod_perdues=(\d+) dont_hors_portee=(\d+) \((\d+)%\) \| "
                   r"tourelles_perdues=(\d+) \| pertes_prod_par_vague=([\d.]+) \| factions_vivantes=(-?\d+)")


def lire(dossier):
    d = Path(dossier)
    for nom in ("benchmark.log.gz", "benchmark.log"):
        p = d / nom
        if p.exists():
            op = gzip.open if nom.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as f:
                return f.read().splitlines()
    sys.exit("aucun benchmark.log dans " + str(d))


def analyser(dossier):
    lignes = lire(dossier)
    mes, perte, total = {}, {}, None
    for l in lignes:
        m = MES.search(l)
        if m:
            minute, cle = int(m.group(1)), m.group(2)
            mes.setdefault(cle, {})[minute] = tuple(int(m.group(i)) for i in range(3, 7))
        m = PERTE.search(l)
        if m:
            perte[m.group(1)] = tuple(int(m.group(i)) for i in range(2, 8))
        m = TOTAL.search(l)
        if m:
            total = (int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5)), float(m.group(6)), int(m.group(7)))
    return mes, perte, total


def resume(dossier):
    mes, perte, total = analyser(dossier)
    tot = near = prod_perdu = hors = vagues = tur_perdues = 0
    for cle in sorted(mes):
        derniere = mes[cle][max(mes[cle])]
        tot += derniere[0]
        near += derniere[1]
    for cle in sorted(perte):
        v, pp, hp, tp, _, _ = perte[cle]
        vagues, prod_perdu, hors, tur_perdues = vagues + v, prod_perdu + pp, hors + hp, tur_perdues + tp
    return {
        "A": (near, tot), "B": (hors, prod_perdu), "C": (prod_perdu, vagues), "D": total[6] if total else -1, "E": tur_perdues,
        "equipes": {cle: mes[cle][max(mes[cle])] for cle in sorted(mes)},
    }


def pct(a, b):
    return 100.0 * a / b if b else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--temoin", nargs="+", required=True)
    ap.add_argument("--essai", nargs="*", default=[])
    a = ap.parse_args()
    cumul = {"t": [0, 0, 0, 0, 0, 0, 0, 0], "e": [0, 0, 0, 0, 0, 0, 0, 0]}
    for tag, dossiers in (("temoin", a.temoin), ("essai", a.essai)):
        c = cumul[tag[0]]
        for d in dossiers:
            r = resume(d)
            print(f"[{tag}] {d}")
            print(f"   A tourelles a <=15 tuiles du QG / total : {r['A'][0]}/{r['A'][1]} = {pct(*r['A']):.0f} %")
            print(f"   B pieces de production perdues hors de portee de toute tourelle : {r['B'][0]}/{r['B'][1]} = {pct(*r['B']):.0f} %")
            print(f"   C pertes de production par vague : {r['C'][0]}/{r['C'][1]} = {r['C'][0] / r['C'][1] if r['C'][1] else 0:.1f}")
            print(f"   D factions vivantes a la fin : {r['D']}   E tourelles perdues : {r['E']}")
            for cle, v in r["equipes"].items():
                print(f"      {cle:12s} tourelles {v[0]:3d}, a 15 tuiles du QG {v[1]:3d}, a 40 tuiles {v[2]:3d}, pieces de production {v[3]}")
            for i, x in enumerate((r["A"][0], r["A"][1], r["B"][0], r["B"][1], r["C"][0], r["C"][1], r["D"], r["E"])):
                c[i] += x
    for tag in ("t", "e"):
        c = cumul[tag]
        if not c[1]:
            continue
        print(f"CUMUL {'temoin' if tag == 't' else 'essai'} : A {pct(c[0], c[1]):.0f} % ({c[0]}/{c[1]}) ; B {pct(c[2], c[3]):.0f} % ({c[2]}/{c[3]}) ; "
              f"C {c[4] / c[5] if c[5] else 0:.1f} par vague ({c[4]}/{c[5]}) ; D {c[6]} ; E {c[7]}")


if __name__ == "__main__":
    main()
