# -*- coding: utf-8 -*-
"""Lot STOCK-QG : lecture des lignes [FO-STOCK-QG] (scenarios/etape1-stock-qg.lua) de deux archives, AVANT et APRES les plafonds.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/stock_qg_lecture.py <avant> <apres> [--minutes 20,40]
Par minute et par équipe : cases prises / cases, annexes, charbon, pierre, bois, fours de pierre, soufre, plaques de fer, avant puis après.
"""
import gzip
import os
import re
import sys

RE = re.compile(r"\[FO-STOCK-QG\] minute (\d+) \| (\S+) \| cases (-?\d+)/(-?\d+) \| annexes (-?\d+) \| (.*?) \| top (.*)$")


def read_log(arch):
    for name in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, name)
        if os.path.exists(p):
            opener = gzip.open if name.endswith(".gz") else open
            with opener(p, "rt", encoding="utf-8", errors="replace") as fh:
                return fh.read().splitlines()
    return []


def parse(arch):
    out = {}
    for ln in read_log(arch):
        m = RE.search(ln)
        if not m:
            continue
        kv = dict((k, int(v)) for k, v in (x.split("=") for x in m.group(6).split()))
        kv.update(used=int(m.group(3)), size=int(m.group(4)), annexes=int(m.group(5)))
        out[(int(m.group(1)), m.group(2))] = kv
    return out


def main(argv):
    minutes = [20, 40]
    args = []
    i = 0
    while i < len(argv):
        if argv[i] == "--minutes":
            i += 1
            minutes = [int(x) for x in argv[i].split(",")]
        else:
            args.append(argv[i])
        i += 1
    if len(args) != 2:
        print(__doc__)
        return 2
    a, b = parse(args[0]), parse(args[1])
    cols = ["coal", "stone", "wood", "stone-furnace", "sulfur", "iron-plate"]
    print("minute | equipe | etat  | cases     | annexes | " + " | ".join(cols))
    for mn in minutes:
        teams = sorted(set(t for (m, t) in list(a) + list(b) if m == mn), key=lambda t: (t != "player", t))
        for t in teams:
            for label, d in (("avant", a), ("apres", b)):
                r = d.get((mn, t))
                if not r:
                    print("%6d | %-6s | %s | -" % (mn, t, label))
                    continue
                print("%6d | %-6s | %s | %4d/%-4d | %7d | %s" % (mn, t, label, r["used"], r["size"], r["annexes"],
                                                                  " | ".join(str(r.get(c, 0)) for c in cols)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
