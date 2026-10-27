"""Lot IA3-d (A7, « ils ne scalent pas ») : mesure de l'effectif des factions dans un banc archivé par banc.py.

Usage : py -3.9 -B tools/autotest/effectif.py <archive> [<archive> ...]
Lit benchmark.log (ou .gz) : lignes minute d'IA3-DIAG (« minute M | <équipe> tech T soldats S pnj N/max | taches {…} »)
et lignes du mod « [FO-EFFECTIF] <équipe> minute M | effectif n/plafond … | croissance g (recrues r) | raisons {…} ».
Imprime, par faction : effectif aux minutes 1, 10, 30, 60, 90 et dernière, maximum, moyenne des minutes 90 à 119,
recrues de croissance et recrues payées, raisons des pensées sur la partie (part en %), minutes où la règle a recruté
et PNJ sans tâche relevés pendant ces minutes (critère : pas de recrue quand des PNJ sont inactifs). Code 0 si lisible.
"""
import gzip
import os
import re
import sys

RE_DIAG = re.compile(r"\] minute (\d+) \| (\w+) tech (\d+) soldats (\d+) pnj (\d+)/(\d+) \| taches \{([^}]*)\}")
RE_EFF = re.compile(r"\[FO-EFFECTIF\] (\w+) minute (\d+) \| effectif (\d+)/(\d+) \(depart (\d+)\) \| croissance (\d+) "
                    r"\(recrues (\d+)\) \| raisons \{([^}]*)\}")


def opener(d):
    for n in ("benchmark.log", "benchmark.log.gz"):
        p = os.path.join(d, n)
        if os.path.exists(p):
            if n.endswith(".gz"):
                return gzip.open(p, "rt", encoding="utf-8", errors="replace")
            return open(p, encoding="utf-8", errors="replace")
    raise OSError("benchmark.log absent : " + d)


def kv(s):
    out = {}
    for part in s.split():
        if ":" in part:
            k, v = part.rsplit(":", 1)
            try:
                out[k] = float(v)
            except ValueError:
                pass
    return out


def main(d):
    diag, eff = {}, {}
    with opener(d) as fh:
        for line in fh:
            m = RE_EFF.search(line)
            if m:
                team, minute = m.group(1), int(m.group(2))
                eff.setdefault(team, []).append({
                    "m": minute, "n": int(m.group(3)), "cap": int(m.group(4)), "start": int(m.group(5)),
                    "grown": int(m.group(6)), "recruited": int(m.group(7)), "why": kv(m.group(8))})
                continue
            m = RE_DIAG.search(line)
            if m:
                team, minute = m.group(2), int(m.group(1))
                diag.setdefault(team, {})[minute] = {"n": int(m.group(5)), "max": int(m.group(6)),
                                                     "idle": kv(m.group(7)).get("inactif", 0.0)}
    print(d)
    for team in sorted(set(diag) | set(eff)):
        dm = diag.get(team, {})
        rows = eff.get(team, [])
        mins = sorted(dm)
        if mins:
            def at(x):
                k = min(mins, key=lambda v: abs(v - x))
                return dm[k]["n"]
            last = mins[-1]
            tail = [dm[k]["n"] for k in mins if 90 <= k <= 119]
            mean_tail = sum(tail) / len(tail) if tail else float("nan")
            print(f"  {team:8s} effectif min1 {at(1)} min10 {at(10)} min30 {at(30)} min60 {at(60)} min90 {at(90)} "
                  f"min{last} {dm[last]['n']} | max {max(dm[k]['n'] for k in mins)} plafond {dm[last]['max']} | "
                  f"moyenne 90-119 {mean_tail:.1f}")
        if rows:
            tot = {}
            for r in rows:
                for k, v in r["why"].items():
                    tot[k] = tot.get(k, 0) + v
            n = sum(tot.values()) or 1
            parts = " ".join(f"{k} {100 * v / n:.0f}%" for k, v in sorted(tot.items(), key=lambda kv_: -kv_[1]))
            rec_min = [r["m"] for r in rows if r["why"].get("recrue", 0) > 0]
            idle_at = [dm[m]["idle"] for m in rec_min if m in dm]
            idle_txt = (f"{sum(idle_at) / len(idle_at):.2f} PNJ sans tache en moyenne (max {max(idle_at):.2f})"
                        if idle_at else "-")
            print(f"           croissance {rows[-1]['grown']} recrues de croissance, {rows[-1]['recruited']} recrues payees ; "
                  f"raisons ({int(n)} pensees) : {parts}")
            print(f"           minutes avec une decision « recrue » : {len(rec_min)} ; PNJ sans tache relevés pendant "
                  f"ces minutes : {idle_txt}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    rc = 0
    for a in sys.argv[1:]:
        try:
            main(a)
        except OSError as e:
            print("illisible :", e)
            rc = 1
    sys.exit(rc)
