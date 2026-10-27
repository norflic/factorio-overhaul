# -*- coding: utf-8 -*-
"""Lot CAPITAL : lecture des archives des bancs capital-partie et capital-temoin (banc.py).

Usage :
  py -3.9 -B tools/autotest/capital_mesures.py <archive> [<archive> ...]
  py -3.9 -B tools/autotest/capital_mesures.py --comparer <partie> <temoin> [<partie> <temoin> ...]

Pour chaque archive : par faction, minute de pose du centre, minute du passage au niveau 2 (et plus), nombre
d'améliorations payées, refus, soldats et PNJ aux minutes 15, 30, 45 et 59 (relevés par minute), minute des paliers 2
et 3 de recherche (lignes « [FO-IA3C] <faction> : palier N atteint a X min »), paliers de la ligne « cible A1 », BILAN.
Lit benchmark-stdout.txt(.gz) et benchmark.log(.gz).

--comparer (correction après revue, 27/10) : par paire (partie, témoin) de la MÊME graine, médianes des paliers 2 et 3
sur les 4 factions, puis sur les seules factions VALIDES dans les deux passages : une faction est EFFONDRÉE dans un
passage quand elle compte au plus EFFONDREE_PNJ PNJ à la minute 45 (la partie diverge au moindre changement, F252 : une
faction décimée dans un seul passage ne compare plus la même chose). Écart par faction valide (partie - témoin) ; à la
fin, écarts de toutes les paires réunies : nombre de factions en retard, en avance, médiane des écarts. « jamais » =
palier non atteint en 60 min (compté comme plus tard que tout).
"""
import gzip
import math
import os
import re
import sys

EFFONDREE_PNJ = 3
INF = math.inf


def read(path):
    for name in (path, path + ".gz"):
        if os.path.exists(name):
            if name.endswith(".gz"):
                with gzip.open(name, "rt", encoding="utf-8", errors="replace") as f:
                    return f.read()
            with open(name, "r", encoding="utf-8", errors="replace") as f:
                return f.read()
    return ""


def parse(arch):
    out = read(os.path.join(arch, "benchmark-stdout.txt"))
    log = read(os.path.join(arch, "benchmark.log"))
    text = out or log
    fac = {}

    def F(k):
        return fac.setdefault(k, {"pose": None, "cc": {}, "paid": 0, "refus": 0, "dec": 0, "soldats": {}, "pnj": {},
                                  "palier": {}})

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
    for m in re.finditer(r"minute (\d+) \| (\w+) tech \d+ soldats (\d+) (?:pnj (\d+)/(\d+))?", text):
        mn = int(m.group(1))
        if mn in (15, 30, 45, 59):
            F(m.group(2))["soldats"][mn] = int(m.group(3))
            if m.group(4) is not None:
                F(m.group(2))["pnj"][mn] = int(m.group(4))
    for m in re.finditer(r"\[FO-IA3C\] (\w+) : palier (\d) atteint a ([\d.]+) min", text):
        F(m.group(1))["palier"].setdefault(int(m.group(2)), float(m.group(3)))
    bilan = re.findall(r"\] BILAN : [^\n]*", log)
    cibles = re.findall(r"cible A1 : palier \d[^\n]*", log)
    return fac, bilan[-1].strip("] ").strip() if bilan else "", cibles


def fmt(x):
    return "jamais" if x == INF else ("%.1f" % x)


def median(xs):
    xs = sorted(xs)
    n = len(xs)
    if n == 0:
        return None
    if n % 2 == 1:
        return xs[n // 2]
    a, b = xs[n // 2 - 1], xs[n // 2]
    return INF if INF in (a, b) else (a + b) / 2


def show(arch):
    fac, bilan, cibles = parse(arch)
    print("== " + arch)
    for k in sorted(fac):
        v = fac[k]
        cc = " ".join("niv%d@%.1f" % (n, v["cc"][n]) for n in sorted(v["cc"]))
        sol = " ".join("%d:%d" % (n, v["soldats"][n]) for n in sorted(v["soldats"]))
        pnj = " ".join("%d:%d" % (n, v["pnj"][n]) for n in sorted(v["pnj"]))
        pose = ("%.1f" % v["pose"]) if v["pose"] is not None else "jamais"
        pal = " ".join("p%d %s" % (n, fmt(v["palier"].get(n, INF))) for n in (2, 3))
        print("  %-8s pose du centre %-7s %-22s decisions %3d payees %3d refus %3d | %s | soldats %s | pnj %s"
              % (k, pose, cc or "-", v["dec"], v["paid"], v["refus"], pal, sol, pnj))
    for line in cibles:
        print("  " + line.strip())
    if bilan:
        print("  " + bilan)


def factions(fac):
    return sorted(k for k in fac if fac[k]["pnj"] or fac[k]["palier"])


def compare(pairs):
    deltas = {2: [], 3: []}
    for partie, temoin in pairs:
        fp, _, _ = parse(partie)
        ft, _, _ = parse(temoin)
        keys = sorted(set(factions(fp)) & set(factions(ft)))
        print("== partie %s\n   temoin %s" % (os.path.basename(partie), os.path.basename(temoin)))
        dead = {}
        for k in keys:
            dp = fp[k]["pnj"].get(45, 99) <= EFFONDREE_PNJ
            dt = ft[k]["pnj"].get(45, 99) <= EFFONDREE_PNJ
            dead[k] = (dp, dt)
            print("  %-8s pnj a 45 min : partie %s, temoin %s%s%s" % (
                k, fp[k]["pnj"].get(45, "?"), ft[k]["pnj"].get(45, "?"),
                " | EFFONDREE dans la partie" if dp else "", " | EFFONDREE au temoin" if dt else ""))
        for n in (2, 3):
            ap = [fp[k]["palier"].get(n, INF) for k in keys]
            at = [ft[k]["palier"].get(n, INF) for k in keys]
            ok = [k for k in keys if not (dead[k][0] or dead[k][1])]
            vp = [fp[k]["palier"].get(n, INF) for k in ok]
            vt = [ft[k]["palier"].get(n, INF) for k in ok]
            per = []
            for k in ok:
                a, b = fp[k]["palier"].get(n, INF), ft[k]["palier"].get(n, INF)
                if a == INF and b == INF:
                    d = 0.0
                elif a == INF:
                    d = INF
                elif b == INF:
                    d = -INF
                else:
                    d = a - b
                deltas[n].append(d)
                per.append("%s %s" % (k, ("%+.1f" % d) if abs(d) != INF else ("jamais (partie)" if d > 0 else "jamais (temoin)")))
            print("  palier %d : mediane 4 factions partie %s, temoin %s | factions valides (%d) : partie %s, temoin %s | ecarts %s"
                  % (n, fmt(median(ap)), fmt(median(at)), len(ok), fmt(median(vp) if vp else INF),
                     fmt(median(vt) if vt else INF), ", ".join(per) or "-"))
    print("== toutes les paires (factions valides dans les deux passages)")
    for n in (2, 3):
        ds = deltas[n]
        late = sum(1 for d in ds if d > 0.05)
        early = sum(1 for d in ds if d < -0.05)
        same = len(ds) - late - early
        med = median(ds)
        print("  palier %d : %d faction(s) comparee(s) : %d en retard, %d en avance, %d egales ; mediane des ecarts %s min"
              % (n, len(ds), late, early, same, ("%+.1f" % med) if med is not None and abs(med) != INF else str(med)))


def main(args):
    if args and args[0] == "--comparer":
        rest = args[1:]
        if len(rest) < 2 or len(rest) % 2 != 0:
            print("usage : --comparer <partie> <temoin> [<partie> <temoin> ...]")
            return 2
        compare([(rest[i], rest[i + 1]) for i in range(0, len(rest), 2)])
        return 0
    for arch in args:
        show(arch)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
