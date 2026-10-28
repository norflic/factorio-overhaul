# -*- coding: utf-8 -*-
"""Lot STOCK-ECHELLE : remplissage du stock (coffre du QG + annexes) lu aux lignes [FO-ETAPE1-GUIDE] « base » d'archives.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/stock_mesures.py <archive> [<archive> ...]
Par archive et par force : relevé par minute (cases prises / cases, QG + annexes). Rend la part des relevés au-dessus de
70 % (T.annex.grow_at) et de 90 %, le maximum, et le rythme d'entrée des 20 dernières minutes (EXTRAPOLATION, pas une mesure).
"""
import gzip
import os
import re
import sys

RE_BASE = re.compile(r"\[FO-ETAPE1-GUIDE\] base minute (\d+) \| ([^|]+?) \|.*?coffre_(?:qg|equipe) (\d+)/(\d+) annexes=(\d+)\((\d+)/(\d+)\)")
CAP_MAX = 96 + 24 * 32  # coffre d'equipe + 24 annexes de fer (T.annex.max, kinds[1].slots)


def read_log(arch):
    for name in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, name)
        if os.path.exists(p):
            opener = gzip.open if name.endswith(".gz") else open
            with opener(p, "rt", encoding="utf-8", errors="replace") as fh:
                return fh.read().splitlines()
    return []


def series(arch):
    out = {}
    for l in read_log(arch):
        m = RE_BASE.search(l)
        if not m:
            continue
        minute, who = int(m.group(1)), m.group(2).strip()
        qu, qs, na, au, asz = (int(m.group(i)) for i in (3, 4, 5, 6, 7))
        out.setdefault(who, {})[minute] = (qu + au, qs + asz, na)
    return out


def med(v):
    v = sorted(v)
    return v[len(v) // 2] if v else 0


def main(argv):
    tot = {}
    for arch in argv:
        seed = os.path.basename(arch.rstrip("/\\"))
        for who, rows in sorted(series(arch).items()):
            fr = [(u / s) for (u, s, n) in rows.values() if s]
            over70 = sum(1 for x in fr if x >= 0.70)
            over90 = sum(1 for x in fr if x >= 0.90)
            mx = max(fr) if fr else 0
            last = rows[max(rows)] if rows else (0, 0, 0)
            ks = sorted(rows)
            rate = None
            if len(ks) >= 3:  # les lignes « base » sont toutes les 10 min : rythme sur les 20 dernieres minutes
                a, b = rows[ks[-3]], rows[ks[-1]]
                rate = (b[0] - a[0]) / float(ks[-1] - ks[-3])
            print("%-28s %-12s releves=%2d  >=70%%:%2d  >=90%%:%2d  max=%.2f  mediane=%.2f  min60: %d/%d cases, %d annexe(s)  rythme20=%s cases/min" % (
                seed, who, len(fr), over70, over90, mx, med(fr), last[0], last[1], last[2],
                "%.1f" % rate if rate is not None else "-"))
            t = tot.setdefault("player" if who.startswith("VOTRE") else "faction", [0, 0, 0])
            t[0] += len(fr); t[1] += over70; t[2] += over90
            if who.startswith("VOTRE") and rate is not None and rate > 0:
                eta = ks[-1] + (CAP_MAX - last[0]) / rate
                print("   EXTRAPOLATION lineaire (pas une mesure) : capacite max %d cases atteinte vers la minute %.0f" % (CAP_MAX, eta))
    for k, (n, a, b) in sorted(tot.items()):
        print("TOTAL %-8s releves=%d  >=70%%:%d (%.1f%%)  >=90%%:%d (%.1f%%)" % (k, n, a, 100.0 * a / max(1, n), b, 100.0 * b / max(1, n)))


if __name__ == "__main__":
    main(sys.argv[1:])
