"""Lot JALONS (14/11) : lecture d'une archive du scénario partie-jalons-30 (ou de tout journal portant [FO-JALON]).

Usage : py -3.9 -B tools/autotest/jalons.py <archive|factorio-current.log> [--minutes 10,15,20,30]
Affiche par équipe et par minute : foreuses électriques en marche (fer / cuivre / charbon / autres), fours en marche,
assembleurs, fer et cuivre produits ; puis les premières minutes (assembleur, four, foreuses) et le pic [FO-PERF-PIC]
(portée la plus longue) écrit au journal.
"""
import gzip
import os
import re
import sys

J = re.compile(r"\[FO-JALON\] minute=(\d+) equipe=(\S+) foreuses_elec_marche=(\S+) foreuses_comb_marche=(\d+) fours=(\d+)"
               r" fours_marche=(\d+) assembleurs=(\d+) assembleurs_marche=(\d+) fer_produit=(-?\d+) cuivre_produit=(-?\d+)")
P = re.compile(r"\[FO-JALON-PREMIERS\] minute=(\d+) equipe=(\S+) premier_assembleur=(\S+) premier_four_marche=(\S+) premieres_foreuses_elec=(\S+)")
PIC = re.compile(r"\[FO-PERF-PIC\] (\S+) (\S+) \S+ ?: ([\d.]+)ms")


def open_log(path):
    if os.path.isdir(path):
        for name in ("factorio-current.log", "benchmark.log.gz", "benchmark.log"):
            p = os.path.join(path, name)
            if os.path.exists(p):
                path = p
                break
    if path.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8", errors="replace")
    return open(path, encoding="utf-8", errors="replace")


def kv(s):
    if s == "-":
        return {}
    return {k: int(v) for k, v in (x.split(":") for x in s.split(","))}


def main():
    path = sys.argv[1]
    mins = [10, 15, 20, 30]
    if "--minutes" in sys.argv:
        mins = [int(x) for x in sys.argv[sys.argv.index("--minutes") + 1].split(",")]
    rows, first, pics = {}, {}, []
    with open_log(path) as f:
        for line in f:
            m = J.search(line)
            if m:
                rows[(m.group(2), int(m.group(1)))] = m.groups()
                continue
            m = P.search(line)
            if m:
                first[m.group(2)] = m.groups()
                continue
            m = PIC.search(line)
            if m:
                pics.append((float(m.group(3)), m.group(1), m.group(2)))
    teams = sorted({k for k, _ in rows})
    print("minute equipe        fer cuiv charb autres | fours_marche/fours | asm | fer_produit cuivre_produit")
    for mi in mins:
        for t in teams:
            r = rows.get((t, mi))
            if not r:
                print(f"{mi:>6} {t:<12} (pas de ligne)")
                continue
            e = kv(r[2])
            fe, cu, co = e.pop("iron-ore", 0), e.pop("copper-ore", 0), e.pop("coal", 0)
            print(f"{mi:>6} {t:<12} {fe:>4} {cu:>4} {co:>5} {sum(e.values()):>6} | {r[5]:>4}/{r[4]:<4} | {r[6]:>3} | {r[8]:>10} {r[9]:>10}")
    print("\npremieres minutes (assembleur / four en marche / foreuses elec par ressource)")
    for t in teams:
        p = first.get(t)
        if p:
            print(f"  {t:<12} asm={p[2]:<4} four={p[3]:<4} foreuses={p[4]}")
    pics.sort(reverse=True)
    print("\npics [FO-PERF-PIC] (portee la plus longue) :", ", ".join(f"{d:.1f}ms {s} {t}" for d, s, t in pics[:8]) or "aucun")


if __name__ == "__main__":
    main()
