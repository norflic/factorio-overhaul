# -*- coding: utf-8 -*-
"""Sprint s43 (sonde-charbon) : lecture des lignes [FO-SONDE-CHARBON] (scenarios/sonde_charbon.lua) d'une ou plusieurs archives de banc.

Usage : py -3.9 -B tools/autotest/sonde_charbon.py <archive> [<archive> ...] [--de M] [--a M]
Par archive et par équipe, sur les minutes [de, a] (défaut 1..60) : source (stock = Stock.count du mod, qg = coffre du QG seul),
minutes relevées, minutes à 0 combustible, moyenne, minimum, et la même chose pour le charbon nommé du coffre du QG. Somme en bas.
"""
import gzip, os, re, sys

LINE = re.compile(r"\[FO-SONDE-CHARBON\] minute=(\d+) equipe=(\S+) source=(\S+) combustible_qg=(-?\d+) charbon_qg=(-?\d+)")


def read(arch):
    for name in ("benchmark.log.gz", "benchmark.log", "factorio-current.log"):
        p = os.path.join(arch, name) if os.path.isdir(arch) else arch
        if os.path.isdir(arch) and not os.path.exists(p):
            continue
        op = gzip.open if p.endswith(".gz") else open
        with op(p, "rt", encoding="utf-8", errors="replace") as fh:
            return fh.read().splitlines()
    return []


def summary(lines, de=1, a=60):
    """{ equipe: { src, n, zero, mean, min, coal_zero, coal_mean } } (pur : testable sur une liste de lignes)."""
    acc = {}
    for line in lines:
        m = LINE.search(line)
        if not m:
            continue
        mi, k, src, n, c = int(m.group(1)), m.group(2), m.group(3), int(m.group(4)), int(m.group(5))
        if mi < de or mi > a or n < 0:
            continue
        d = acc.setdefault(k, {"src": src, "v": [], "c": []})
        d["v"].append(n)
        d["c"].append(max(c, 0))
    out = {}
    for k in sorted(acc):
        v, c = acc[k]["v"], acc[k]["c"]
        out[k] = {"src": acc[k]["src"], "n": len(v), "zero": sum(1 for x in v if x == 0), "mean": sum(v) / len(v), "min": min(v),
                  "coal_zero": sum(1 for x in c if x == 0), "coal_mean": sum(c) / len(c)}
    return out


def main(argv):
    de, a = 1, 60
    args = []
    i = 1
    while i < len(argv):
        if argv[i] == "--de":
            de = int(argv[i + 1]); i += 2
        elif argv[i] == "--a":
            a = int(argv[i + 1]); i += 2
        else:
            args.append(argv[i]); i += 1
    tot_zero, tot_n = 0, 0
    print("archive equipe source minutes a_zero moyenne minimum | charbon_qg: a_zero moyenne")
    for arch in args:
        s = summary(read(arch), de, a)
        for k, d in s.items():
            print("%s %s %s %d %d %.0f %d | %d %.0f" % (os.path.basename(arch.rstrip("/\\")), k, d["src"], d["n"], d["zero"], d["mean"], d["min"],
                                                     d["coal_zero"], d["coal_mean"]))
            tot_zero, tot_n = tot_zero + d["zero"], tot_n + d["n"]
    print("SOMME minutes a zero combustible : %d sur %d" % (tot_zero, tot_n))


if __name__ == "__main__":
    main(sys.argv)
