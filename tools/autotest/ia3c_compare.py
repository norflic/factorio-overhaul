# Lot IA3-c : critères du cerveau par besoins (docs/IA3_CERVEAU.md §6.2) AVANT / APRÈS sur des bancs de la MÊME source,
# archivés par ia3d_run.py (benchmark.log.gz) : ia3d-* (réglage fo-war-ia3-cerveau éteint) contre ia3c-* (allumé).
# Par faction : minutes des PALIERS 1 à 3 (lignes « [FO-IA3C] … palier k atteint », écrites par les deux cerveaux), de
# « fer II » (K12), niveaux R1 à R3 de l'ancien cerveau, soldats à 60 min, PNJ inactifs (K3 : part « inactif » des tâches
# relevées par le scénario, fenêtres 0-10 et 30-90 min), projets menés en même temps (cerveau par besoins : part des
# minutes avec 3 projets ou plus dont des PNJ tiennent une tâche), faction anéantie (dernière minute relevée).
# Usage : py -3.9 -B tools/autotest/ia3c_compare.py --avant <archive> [...] --apres <archive> [...]
import gzip
import os
import re
import statistics
import sys

RE_PAL = re.compile(r"\[FO-IA3C\] (\w+) : palier (\d) atteint a ([0-9.]+) min")
RE_IRON2 = re.compile(r"\[FO-TEAM\] (\w+) : objectif atteint 'iron2' a ([0-9.]+) min")
RE_RES = re.compile(r"\[FO-TEAM\] (\w+) : recherche niveau (\d) payee en packs a ([0-9.]+) min")
RE_MIN = re.compile(r"\[FO-IA3[A-Z]-[A-Z]+\] minute (\d+) \| (\w+) tech (\d+) soldats (\d+) pnj (\d+)/(\d+) \| taches \{([^}]*)\}")
RE_PROJ = re.compile(r"\[FO-IA3C\] (\w+) minute (\d+) \| actifs (\d+) productifs (\d+) pris (\d+) bloques (\d+) K (\d+)")


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


def parse(path):
    teams = {}

    def t(name):
        return teams.setdefault(name, {"pal": {}, "res": {}, "iron2": None, "rows": [], "proj": []})

    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = RE_PAL.search(line)
            if m:
                t(m.group(1))["pal"].setdefault(int(m.group(2)), float(m.group(3)))
                continue
            m = RE_IRON2.search(line)
            if m:
                d = t(m.group(1))
                if d["iron2"] is None:
                    d["iron2"] = float(m.group(2))
                continue
            m = RE_RES.search(line)
            if m:
                t(m.group(1))["res"].setdefault(int(m.group(2)), float(m.group(3)))
                continue
            m = RE_MIN.search(line)
            if m:
                t(m.group(2))["rows"].append({"min": int(m.group(1)), "soldats": int(m.group(4)), "pnj": int(m.group(5)),
                                              "taches": kv(m.group(7))})
                continue
            m = RE_PROJ.search(line)
            if m:
                t(m.group(1))["proj"].append({"min": int(m.group(2)), "actifs": int(m.group(3)), "pris": int(m.group(5)),
                                              "bloques": int(m.group(6)), "K": int(m.group(7))})
    return teams


def idle_share(rows, a, b):
    idle = tot = 0.0
    for r in rows:
        if a <= r["min"] < b:
            for k, v in r["taches"].items():
                tot += v
                if k == "inactif":
                    idle += v
    return None if tot == 0 else 100.0 * idle / tot


def faction_stats(path):
    out = []
    teams = parse(path)
    last_min = max([r["min"] for d in teams.values() for r in d["rows"]] or [0])
    for name in sorted(teams):
        if name == "player":
            continue
        d = teams[name]
        if not d["rows"] and not d["pal"]:
            continue
        sold60 = None
        for r in d["rows"]:
            if r["min"] <= 60:
                sold60 = r["soldats"]
        end = max([r["min"] for r in d["rows"]] or [0])
        par3 = None
        if d["proj"]:
            par3 = 100.0 * sum(1 for p in d["proj"] if p["pris"] >= 3) / len(d["proj"])
        out.append({"team": name, "p1": d["pal"].get(1), "p2": d["pal"].get(2), "p3": d["pal"].get(3),
                    "r1": d["res"].get(1), "r2": d["res"].get(2), "r3": d["res"].get(3), "iron2": d["iron2"],
                    "sold60": sold60, "idle010": idle_share(d["rows"], 0, 10), "idle3090": idle_share(d["rows"], 30, 90),
                    "par3": par3, "dead": end < last_min - 1 and end or None})
    return out


def med(values):
    v = [x for x in values if x is not None]
    return statistics.median(v) if v else None


def fmt(x):
    return "—" if x is None else (f"{x:.1f}" if isinstance(x, float) else str(x))


COLS = ["p1", "p2", "p3", "r1", "r2", "r3", "iron2", "sold60", "idle010", "idle3090", "par3", "dead"]


def group(label, archives):
    rows = []
    for a in archives:
        p = os.path.join(a, "benchmark.log.gz")
        if not os.path.exists(p):
            print(f"  {a} : benchmark.log.gz absent")
            continue
        for r in faction_stats(p):
            r["bench"] = os.path.basename(a.rstrip("/\\"))
            rows.append(r)
    print(f"== {label} ({len(archives)} banc(s), {len(rows)} faction(s))")
    print("  " + "banc".ljust(34) + "faction".ljust(9) + "".join(c.rjust(9) for c in COLS))
    for r in rows:
        print("  " + r["bench"][:33].ljust(34) + r["team"].ljust(9) + "".join(fmt(r[c]).rjust(9) for c in COLS))
    never = {k: sum(1 for r in rows if r[k] is None) for k in ("p1", "p2", "p3")}
    print("  médianes : " + "  ".join(f"{c} {fmt(med([r[c] for r in rows]))}" for c in COLS if c != "dead")
          + f"  | jamais : p1 {never['p1']}, p2 {never['p2']}, p3 {never['p3']} sur {len(rows)}"
          + f"  | anéanties : {sum(1 for r in rows if r['dead'] is not None)}")
    return rows


def main():
    args = sys.argv[1:]
    groups, cur = {"avant": [], "apres": []}, None
    for a in args:
        if a in ("--avant", "--apres"):
            cur = a[2:]
        elif cur:
            groups[cur].append(a)
    for k in ("avant", "apres"):
        if groups[k]:
            group(k.upper(), groups[k])


if __name__ == "__main__":
    main()
