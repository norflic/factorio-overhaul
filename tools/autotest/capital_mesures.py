# -*- coding: utf-8 -*-
"""Lot CAPITAL : lecture des archives des bancs capital-partie et capital-temoin (banc.py).

Usage : py -3.9 -B tools/autotest/capital_mesures.py <archive> [<archive> ...]
Pour chaque archive : par faction, minute de pose du centre, minute du passage au niveau 2 (et plus), nombre
d'améliorations payées, refus, soldats aux minutes 30, 45 et 59 (relevés par minute d'ia3d_common), paliers de
recherche (ligne « cible A1 »), BILAN du banc. Lit benchmark-stdout.txt(.gz) et benchmark.log(.gz).
"""
import gzip
import os
import re
import sys


def read(path):
    for name in (path, path + ".gz"):
        if os.path.exists(name):
            if name.endswith(".gz"):
                with gzip.open(name, "rt", encoding="utf-8", errors="replace") as f:
                    return f.read()
            with open(name, "r", encoding="utf-8", errors="replace") as f:
                return f.read()
    return ""


def main(args):
    for arch in args:
        out = read(os.path.join(arch, "benchmark-stdout.txt"))
        log = read(os.path.join(arch, "benchmark.log"))
        text = out or log
        fac = {}

        def F(k):
            return fac.setdefault(k, {"pose": None, "cc": {}, "paid": 0, "refus": 0, "dec": 0, "soldats": {}})

        for m in re.finditer(r"\[FO-CAPITAL\] (\w+) : centre de commandement pose \(niveau 1\) en \([^)]*\) a ([\d.]+) min", text):
            F(m.group(1))["pose"] = float(m.group(2))
        for m in re.finditer(r"\[FO-CAPITAL\] (\w+) : centre monte au niveau (\d+) \(epoque \d+ ouverte\) a ([\d.]+) min", text):
            F(m.group(1))["cc"][int(m.group(2))] = float(m.group(3))
        for m in re.finditer(r"\[FO-CAPITAL\] (\w+) : amelioration payee", text):
            F(m.group(1))["paid"] += 1
        for m in re.finditer(r"\[FO-CAPITAL\] (\w+) : amelioration '[^']*' refusee", text):
            F(m.group(1))["refus"] += 1
        for m in re.finditer(r"\[FO-CAPITAL\] (\w+) : but '", text):
            F(m.group(1))["dec"] += 1
        for m in re.finditer(r"minute (\d+) \| (\w+) tech \d+ soldats (\d+) ", text):
            mn = int(m.group(1))
            if mn in (15, 30, 45, 59):
                F(m.group(2))["soldats"][mn] = int(m.group(3))
        print("== " + arch)
        for k in sorted(fac):
            v = fac[k]
            cc = " ".join("niv%d@%.1f" % (n, v["cc"][n]) for n in sorted(v["cc"]))
            sol = " ".join("%d:%d" % (n, v["soldats"][n]) for n in sorted(v["soldats"]))
            pose = ("%.1f" % v["pose"]) if v["pose"] is not None else "jamais"
            print("  %-8s pose du centre %-7s %-22s decisions %3d payees %3d refus %3d | soldats %s"
                  % (k, pose, cc or "-", v["dec"], v["paid"], v["refus"], sol))
        for line in re.findall(r"cible A1 : palier \d[^\n]*", log):
            print("  " + line.strip())
        b = re.findall(r"\] BILAN : [^\n]*", log)
        if b:
            print("  " + b[-1].strip("] ").strip())


if __name__ == "__main__":
    main(sys.argv[1:])
