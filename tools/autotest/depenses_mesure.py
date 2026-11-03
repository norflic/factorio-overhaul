# -*- coding: utf-8 -*-
"""Lot DEPENSES (3/11) : mesure du STOCK QUI DORT et de ce qui ne s'achète pas, par équipe et par tranche de 10 min.

Lecture seule d'un journal de partie (factorio-current.log du DC, ou benchmark.log[.gz] d'un banc). Sources :
  [FO-BRIQUES] <eq> a <m> min : stock libre {iron-plate=.. copper-plate=.. steel-plate=..}  (toutes les 5 min)
  [FO-RESERVE] <eq> minute <m> | ... stock libre <MU> MU investissable (..., depense <MU>, <n> ordre(s)) | objets au coffre <n>
  [FO-CAPI] <eq> minute <m> | ... budget=<dépensé>/<disponible> ... refus=[...]
  [FO-CAPITAL-ATTENTE] <eq> : '<but>' decide mais non paye, cause <cause> ... a <m> min
  [FO-DEPENSES] <eq> minute <m> | ... (lot DEPENSES : la règle elle-même, quand elle est allumée)
Stock DORMANT à la minute t = le plus bas des plaques libres (fer + cuivre + acier) relevées dans [t - 10, t] : au moins autant de
plaques sont restées au coffre 10 min sans servir (borne basse : des plaques sont fongibles).

Usage : py -3.9 -B tools/autotest/depenses_mesure.py <journal ou archive> [...] [--csv sortie.csv] [--minute 60]
"""
import gzip
import os
import re
import sys

PLATES = ("iron-plate", "copper-plate", "steel-plate")
WIN = 10  # minutes : fenêtre du stock dormant et largeur des tranches

RX_BRQ = re.compile(r"\[FO-BRIQUES\] (\S+) a ([0-9.]+) min : stock libre \{([^}]*)\}")
RX_RSV = re.compile(r"\[FO-RESERVE\] (\S+) minute (\d+) \| (besoin [A-Z ]+?) :.*?stock libre (-?[0-9.]+) MU investissable "
                    r"\(part du stock au budget (-?[0-9.]+), depense (-?[0-9.]+), (\d+) ordre")
RX_CAPI = re.compile(r"\[FO-CAPI\] (\S+) minute (\d+) \|.*? budget=(-?[0-9.]+)/(-?[0-9.]+) ")
RX_ATT = re.compile(r"\[FO-CAPITAL-ATTENTE\] (\S+) : '([^']+)' decide mais non paye, cause (\S+).* a ([0-9.]+) min")
RX_DEP = re.compile(r"\[FO-DEPENSES\] (\S+) minute (\d+) \| (.*)")


def open_log(path):
    if os.path.isdir(path):
        for name in ("benchmark.log.gz", "benchmark.log", "factorio-current.log"):
            p = os.path.join(path, name)
            if os.path.exists(p):
                path = p
                break
    if path.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8", errors="replace"), path
    return open(path, "r", encoding="utf-8", errors="replace"), path


def parse(path):
    fh, real = open_log(path)
    T = {}

    def team(k):
        if k not in T:
            T[k] = {"brq": [], "rsv": [], "capi": [], "att": [], "dep": []}
        return T[k]

    with fh:
        for line in fh:
            if "[FO-" not in line:
                continue
            m = RX_BRQ.search(line)
            if m:
                kv = {}
                for part in m.group(3).split():
                    if "=" in part:
                        a, b = part.split("=", 1)
                        if a not in kv:
                            try:
                                kv[a] = float(b)
                            except ValueError:
                                pass
                team(m.group(1))["brq"].append((float(m.group(2)), sum(kv.get(p, 0.0) for p in PLATES), kv.get("iron-plate", 0.0)))
                continue
            m = RX_RSV.search(line)
            if m:
                team(m.group(1))["rsv"].append((int(m.group(2)), m.group(3).strip(), float(m.group(4)), float(m.group(6)), int(m.group(7))))
                continue
            m = RX_CAPI.search(line)
            if m:
                occ = line.count("plan directeur occupe")
                team(m.group(1))["capi"].append((int(m.group(2)), float(m.group(3)), float(m.group(4)), occ))
                continue
            m = RX_ATT.search(line)
            if m:
                team(m.group(1))["att"].append((float(m.group(4)), m.group(2), m.group(3)))
                continue
            m = RX_DEP.search(line)
            if m:
                team(m.group(1))["dep"].append((int(m.group(2)), m.group(3)))
    return T, real


def dormant(brq, t):
    vals = [p for (m, p, _) in brq if t - WIN - 1e-6 <= m <= t + 1e-6]
    if len(vals) < 2:
        return None
    return min(vals)


def at(brq, t):
    best = None
    for (m, p, fe) in brq:
        if m <= t + 1e-6:
            best = (p, fe)
    return best


def table(T, last_min):
    rows = []
    for k in sorted(T):
        d = T[k]
        for t in range(WIN, last_min + 1, WIN):
            cur = at(d["brq"], t)
            dor = dormant(d["brq"], t)
            rs = [r for r in d["rsv"] if t - WIN < r[0] <= t]
            cp = [c for c in d["capi"] if t - WIN < c[0] <= t]
            at_ = [a for a in d["att"] if t - WIN < a[0] <= t]
            causes = {}
            for a in at_:
                causes[a[2]] = causes.get(a[2], 0) + 1
            rows.append({
                "eq": k, "t": t,
                "plaques": cur[0] if cur else None, "fer": cur[1] if cur else None, "dort": dor,
                "libre_mu": rs[-1][2] if rs else None,
                "depense_mu": sum(r[3] for r in rs), "ordres": sum(r[4] for r in rs),
                "budget_dep": sum(c[1] for c in cp), "budget_dispo": cp[-1][2] if cp else None,
                "occupe": sum(1 for c in cp if c[3] > 0), "cycles": len(cp),
                "attente": causes, "regle": len([x for x in d["dep"] if t - WIN < x[0] <= t]),
            })
    return rows


def fmt(x, w=7):
    if x is None:
        return "-".rjust(w)
    return ("%.0f" % x).rjust(w)


def main(argv):
    paths, csv, minute = [], None, 60
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--csv":
            csv = argv[i + 1]
            i += 2
            continue
        if a == "--minute":
            minute = int(argv[i + 1])
            i += 2
            continue
        paths.append(a)
        i += 1
    if not paths:
        print(__doc__)
        return 2
    out_csv = []
    for p in paths:
        T, real = parse(p)
        last = 0
        for d in T.values():
            for (m, _, _) in d["brq"]:
                last = max(last, int(m))
            for r in d["rsv"]:
                last = max(last, r[0])
        last = (last // WIN) * WIN
        print("=== %s (derniere minute %d)" % (real, last))
        print("eq        t  plaques   fer   DORT  libreMU depMU/10 ordres occupe/cyc  attente(causes)  regle")
        rows = table(T, last)
        for r in rows:
            att = ",".join("%s:%d" % (c, n) for c, n in sorted(r["attente"].items()))
            print("%-8s %3d %s %s %s %s %s %6d %4d/%-4d  %s  %d" % (
                r["eq"], r["t"], fmt(r["plaques"]), fmt(r["fer"], 5), fmt(r["dort"], 6), fmt(r["libre_mu"], 8),
                fmt(r["depense_mu"], 8), r["ordres"], r["occupe"], r["cycles"], att or "-", r["regle"]))
            out_csv.append((real, r))
        # Résumé à la minute demandée : stock dormant total des équipes de PNJ (votre équipe « player » à part).
        tot_d, tot_p = 0.0, 0.0
        for r in rows:
            if r["t"] == minute and r["eq"] != "player":
                tot_d += r["dort"] or 0
                tot_p += r["plaques"] or 0
        print("RESUME %s : a %d min, plaques libres des factions %.0f, dont DORMANTES (10 min) %.0f (%.0f %%)" % (
            os.path.basename(os.path.dirname(real)) or real, minute, tot_p, tot_d, 100.0 * tot_d / tot_p if tot_p > 0 else 0))
    if csv:
        with open(csv, "w", encoding="utf-8") as f:
            f.write("source;eq;t;plaques;fer;dort;libre_mu;depense_mu;ordres;occupe;cycles;attente;regle\n")
            for real, r in out_csv:
                f.write("%s;%s;%d;%s;%s;%s;%s;%.0f;%d;%d;%d;%s;%d\n" % (
                    real, r["eq"], r["t"], r["plaques"], r["fer"], r["dort"], r["libre_mu"], r["depense_mu"], r["ordres"],
                    r["occupe"], r["cycles"], ",".join("%s:%d" % kv for kv in sorted(r["attente"].items())), r["regle"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
