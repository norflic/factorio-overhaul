#!/usr/bin/env python3
"""Lecture de l'A/B du seuil S2 du mall (scenarios mall-ab-on / mall-ab-off, lot MALL).

Usage : mall_ab.py <dossier ab-<sha>>   (sous-dossiers on-<graine>, off-<graine>)
Par equipe, aux minutes 60 et 89 : couverture electrique des gisements ([FO-GEANTS] TOTAL), plaques/min moyennes sur 5 minutes ([FO-MALL-AB]), objets du mall, machines,
rangees, avant-postes ; premier passage de l'etat S ; avant-postes perdus ([FO-STRAT] orphelins).
"""
import gzip
import os
import re
import sys

TEAMS = ("player", "scarlet", "azure", "amber", "emerald")
MINUTES = (60, 89)
RE_AB = re.compile(r"\[FO-MALL-AB\] (\w+) minute (\d+) \| fer ([-\d.]+)/min cuivre ([-\d.]+)/min \| mall : objets (\d+), coffres (\d+), machines (\d+), rangees (\d+) \| avant-postes (\d+) \| S (\w+)")
RE_GE = re.compile(r"\[FO-GEANTS\] minute (\d+)\.0 \| (\w+) \| TOTAL .*?couvert elec=(\d+) therm=(\d+)")
RE_ORPH = re.compile(r"\[FO-STRAT\] orphelins tick \d+ (\w+) : (\d+) demontes \(avant-poste perdu")
RE_RED = re.compile(r"\[FO-MALL\] (\w+) : etat PRET .* a ([\d.]+) min")
RE_FAIL = re.compile(r"Error|error while|non-recoverable", re.I)


def read(path):
    p = os.path.join(path, "benchmark.log.gz")
    with gzip.open(p, "rt", encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()


def analyse(path):
    ab, ge = {}, {}
    lost = {}
    pret = {}
    fails = 0
    for line in read(path):
        m = RE_AB.search(line)
        if m:
            key, minute = m.group(1), int(m.group(2))
            ab[(key, minute)] = [float(m.group(3)), float(m.group(4)), int(m.group(5)), int(m.group(6)), int(m.group(7)), int(m.group(8)), int(m.group(9)), m.group(10)]
            continue
        m = RE_GE.search(line)
        if m:
            ge[(m.group(2), int(m.group(1)))] = (int(m.group(3)), int(m.group(4)))
            continue
        m = RE_ORPH.search(line)
        if m:
            lost[m.group(1)] = lost.get(m.group(1), 0) + 1
            continue
        m = RE_RED.search(line)
        if m and m.group(1) not in pret:
            pret[m.group(1)] = float(m.group(2))
        if RE_FAIL.search(line) and "FO-" not in line:
            fails += 1
    return ab, ge, lost, pret, fails


def mean_rate(ab, key, minute, idx):
    vals = [ab[(key, m)][idx] for m in range(minute - 4, minute + 1) if (key, m) in ab]
    return sum(vals) / len(vals) if vals else None


def main(root):
    runs = sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d)))
    print("graine ; bras ; equipe ; S a (min) ; minute ; couverture elec ; therm ; fer/min ; cuivre/min ; objets mall ; machines ; rangees ; avant-postes ; postes perdus")
    tot = {}
    for r in runs:
        m = re.match(r"(on|off)-(\d+)$", r)
        if not m:
            continue
        arm, seed = m.group(1), m.group(2)
        ab, ge, lost, pret, fails = analyse(os.path.join(root, r))
        if fails:
            print(f"# {r} : {fails} ligne(s) d'erreur")
        for key in TEAMS:
            if not any(k == key for k, _ in ab):
                continue
            for mn in MINUTES:
                g = ge.get((key, mn)) or ge.get((key, mn - 1))
                a = ab.get((key, mn))
                fer, cu = mean_rate(ab, key, mn, 0), mean_rate(ab, key, mn, 1)
                o = a if a else [None] * 8
                print(f"{seed} ; {arm} ; {key} ; {pret.get(key, '-')} ; {mn} ; {g[0] if g else '-'} ; {g[1] if g else '-'} ; "
                      f"{fer:.1f} ; {cu:.1f} ; {o[2]} ; {o[4]} ; {o[5]} ; {o[6]} ; {lost.get(key, 0)}" if fer is not None else
                      f"{seed} ; {arm} ; {key} ; {pret.get(key, '-')} ; {mn} ; {g[0] if g else '-'} ; {g[1] if g else '-'} ; - ; - ; {o[2]} ; {o[4]} ; {o[5]} ; {o[6]} ; {lost.get(key, 0)}")
                if a and g:
                    k = (arm, mn)
                    t = tot.setdefault(k, {"elec": 0, "fer": 0.0, "cu": 0.0, "mall": 0, "n": 0})
                    t["elec"] += g[0]
                    t["fer"] += fer or 0
                    t["cu"] += cu or 0
                    t["mall"] += a[2]
                    t["n"] += 1
    print()
    print("Moyennes par equipe et par partie (toutes graines, toutes equipes presentes) :")
    print("bras ; minute ; couverture elec ; fer/min ; cuivre/min ; objets mall ; n")
    for (arm, mn), t in sorted(tot.items()):
        n = t["n"]
        print(f"{arm} ; {mn} ; {t['elec'] / n:.0f} ; {t['fer'] / n:.0f} ; {t['cu'] / n:.0f} ; {t['mall'] / n:.0f} ; {n}")


if __name__ == "__main__":
    main(sys.argv[1])
