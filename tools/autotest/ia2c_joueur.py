#!/usr/bin/env python3
"""Mesures du lot IA2-c (le joueur sous brouillard, modèle de l'adversaire), lues dans les journaux d'un banc.

Lignes lues (create.log puis benchmark.log ; graine dans seed.txt) :
  [FO-PVP] attaque / issue / rassemblement / eclaireur / modele / declaration   (script/faction/pvp.lua, vision.lua)
  [FO-STRAT] rassemblement / modele / issue                                     (script/faction/chef.lua)

Usage :
  python -B tools/autotest/ia2c_joueur.py <dossier de banc> [...]
  python -B tools/autotest/ia2c_joueur.py --avant <d1> [...] --apres <d2> [...]   (deux groupes)
  options : --json <fichier>

Mesures :
  1re attaque contre le joueur (min) par banc ; moyenne, écart-type (de l'échantillon), bornes ;
  côté d'arrivée : défense vue du côté choisi ÷ défense du côté le plus défendu (attaques où un côté est défendu) ;
    part des attaques arrivées par un côté sans défense vue quand un autre en a ;
  M4 contre le joueur : après une attaque repoussée ou anéantie, l'attaque SUIVANTE de la même faction vise un autre
    secteur (> 32 tuiles), arrive par un autre octant, ou est ≥ 1,3 × plus grosse ;
  go / no-go : rassemblements « go » et « renonce » (joueur ; rivales) ; éclaireurs partis, arrivés ;
  styles du joueur vus par chaque faction (dernier style, changements) ; styles des rivales (lignes [FO-STRAT] modele).
"""
import argparse
import json
import os
import re
import statistics
import sys

RX = {
    "attack": re.compile(r"\[FO-PVP\] attaque tick (\d+) (\w+) -> joueur : (\d+) soldats vers \((-?\d+), (-?\d+)\), defense estimee (\d+)"
                         r".*?(?:, octant (-?\d+|-), cote (\d+|-) sur (\d+|-), direct (-?\d+|-), style (\w+), tempo (\d+))?\s*$"),
    "issue": re.compile(r"\[FO-PVP\] issue tick (\d+) (\w+) -> joueur : (\w+), (\d+) envoyes, (\d+) survivants, octant (\S+?), vivants"),
    "rally": re.compile(r"\[FO-(PVP|STRAT)\] rassemblement tick (\d+) (\w+) -> (\w+) : (go|renonce), defense vue (\d+) \(depart (\d+)\)"),
    "scout": re.compile(r"\[FO-PVP\] eclaireur tick (\d+) (\w+) : (part vers|arrive|arrete|sans itineraire)"),
    "model": re.compile(r"\[FO-PVP\] modele tick (\d+) (\w+) : style (\w+)"),
    "rmodel": re.compile(r"\[FO-STRAT\] modele tick (\d+) (\w+) -> (\w+) : style (\w+)"),
    "declare": re.compile(r"\[FO-PVP\] declaration tick (\d+) (\w+)"),
    "sissue": re.compile(r"\[FO-STRAT\] issue tick (\d+) (\w+) -> (\w+) : (\w+),"),
}


def parse_lines(lines):
    """Événements d'un banc (listes triées par tick)."""
    ev = {k: [] for k in RX}
    seen = set()
    for line in lines:
        for k, rx in RX.items():
            m = rx.search(line)
            if m:
                key = (k, m.group(0))
                if key in seen:  # create.log et benchmark.log peuvent se recouvrir : une seule fois
                    break
                seen.add(key)
                ev[k].append(m.groups())
                break
    return ev


def learned_player(attacks, issues):
    """M4 contre le joueur : (cas, appris). attacks : [(tick, key, n, x, y, octant)], issues : [(tick, key, outcome)]."""
    cases, learned = 0, 0
    by_key = {}
    for a in attacks:
        by_key.setdefault(a[1], []).append(a)
    for t, key, outcome in issues:
        if outcome not in ("repoussee", "aneantie"):
            continue
        lst = by_key.get(key, [])
        prev = [a for a in lst if a[0] <= t]
        nxt = [a for a in lst if a[0] > t]
        if not prev or not nxt:
            continue
        p, q = prev[-1], nxt[0]
        cases += 1
        far = (p[3] - q[3]) ** 2 + (p[4] - q[4]) ** 2 > 32 * 32
        other_side = p[5] is not None and q[5] is not None and p[5] != q[5]
        bigger = q[2] >= 1.3 * p[2]
        if far or other_side or bigger:
            learned += 1
    return cases, learned


def run_metrics(lines):
    ev = parse_lines(lines)
    out = {}
    attacks = []
    for g in ev["attack"]:
        tick, key, n, x, y = int(g[0]), g[1], int(g[2]), int(g[3]), int(g[4])
        octant = int(g[6]) if g[6] not in (None, "-") else None
        side = int(g[7]) if g[7] not in (None, "-") else None
        smax = int(g[8]) if g[8] not in (None, "-") else None
        attacks.append((tick, key, n, x, y, octant, side, smax, g[10]))
    attacks.sort()
    out["attacks"] = len(attacks)
    out["first_min"] = attacks[0][0] / 3600 if attacks else None
    out["first_key"] = attacks[0][1] if attacks else None
    defended = [a for a in attacks if a[7] not in (None, 0) and a[6] is not None]
    out["side_cases"] = len(defended)
    out["side_free"] = sum(1 for a in defended if a[6] == 0)
    out["side_ratio"] = (statistics.mean(a[6] / a[7] for a in defended) if defended else None)
    issues = [(int(g[0]), g[1], g[2]) for g in ev["issue"]]
    out["issues"] = {}
    for _, _, o in issues:
        out["issues"][o] = out["issues"].get(o, 0) + 1
    out["m4_cases"], out["m4_learned"] = learned_player([a[:6] for a in attacks], issues)
    out["rally_player"] = {"go": 0, "renonce": 0}
    out["rally_rival"] = {"go": 0, "renonce": 0}
    for g in ev["rally"]:
        d = out["rally_player"] if g[0] == "PVP" else out["rally_rival"]
        d[g[4]] += 1
    out["scouts"] = {}
    for g in ev["scout"]:
        out["scouts"][g[2]] = out["scouts"].get(g[2], 0) + 1
    styles = {}
    for g in ev["model"]:
        styles.setdefault(g[1], []).append(g[2])
    out["player_styles"] = {k: v[-1] for k, v in sorted(styles.items())}
    out["player_style_changes"] = sum(len(v) for v in styles.values())
    rst = {}
    for g in ev["rmodel"]:
        rst[g[3]] = rst.get(g[3], 0) + 1
    out["rival_style_lines"] = rst
    so = {}
    for g in ev["sissue"]:
        so[g[3]] = so.get(g[3], 0) + 1
    out["rival_issues"] = so
    out["declarations"] = [(int(g[0]) / 3600, g[1]) for g in ev["declare"]]
    return out


def read_run(folder):
    lines = []
    for name in ("create.log", "benchmark.log"):
        p = os.path.join(folder, name)
        if os.path.exists(p):
            with open(p, encoding="utf-8", errors="replace") as fh:
                lines.extend(fh.read().splitlines())
    seed = None
    sp = os.path.join(folder, "seed.txt")
    if os.path.exists(sp):
        with open(sp, encoding="utf-8", errors="replace") as fh:
            seed = fh.read().strip()
    r = run_metrics(lines)
    r["seed"] = seed
    r["folder"] = os.path.basename(folder.rstrip("\\/"))
    return r


def group(runs):
    firsts = [r["first_min"] for r in runs if r["first_min"] is not None]
    s = {"runs": len(runs), "firsts": firsts}
    s["first_mean"] = statistics.mean(firsts) if firsts else None
    s["first_sd"] = statistics.stdev(firsts) if len(firsts) >= 2 else None
    s["first_lo"] = min(firsts) if firsts else None
    s["first_hi"] = max(firsts) if firsts else None
    s["attacks"] = sum(r["attacks"] for r in runs)
    sc = sum(r["side_cases"] for r in runs)
    s["side_cases"], s["side_free"] = sc, sum(r["side_free"] for r in runs)
    ratios = [r["side_ratio"] for r in runs if r["side_ratio"] is not None]
    s["side_ratio"] = statistics.mean(ratios) if ratios else None
    mc = sum(r["m4_cases"] for r in runs)
    s["m4_cases"], s["m4_share"] = mc, (sum(r["m4_learned"] for r in runs) / mc if mc else None)
    for k in ("rally_player", "rally_rival"):
        s[k] = {"go": sum(r[k]["go"] for r in runs), "renonce": sum(r[k]["renonce"] for r in runs)}
    return s


def fmt(x, nd=1):
    if x is None:
        return "-"
    if isinstance(x, float):
        return f"{x:.{nd}f}"
    return str(x)


def show(label, runs):
    print(f"== {label}")
    for r in runs:
        print(f"  graine {r['seed']} : 1re attaque {fmt(r['first_min'])} min ({r['first_key']}), attaques {r['attacks']}, "
              f"issues {r['issues']}, côté (cas {r['side_cases']}, sans défense {r['side_free']}, ratio {fmt(r['side_ratio'], 2)}), "
              f"M4 {r['m4_learned']}/{r['m4_cases']}, rassemblement joueur {r['rally_player']}, rivales {r['rally_rival']}, "
              f"éclaireurs {r['scouts']}, styles du joueur {r['player_styles']}, styles des rivales {r['rival_style_lines']}")
    s = group(runs)
    print(f"  1re attaque : moyenne {fmt(s['first_mean'])} min, écart-type {fmt(s['first_sd'])}, de {fmt(s['first_lo'])} à {fmt(s['first_hi'])} ; "
          f"attaques {s['attacks']} ; côté : {s['side_free']} sans défense sur {s['side_cases']} défendus, ratio moyen {fmt(s['side_ratio'], 2)} ; "
          f"M4 joueur {fmt(s['m4_share'], 2)} ({s['m4_cases']} cas) ; rassemblement joueur {s['rally_player']}, rivales {s['rally_rival']}")
    return s


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="*")
    ap.add_argument("--avant", nargs="*", default=[])
    ap.add_argument("--apres", nargs="*", default=[])
    ap.add_argument("--json")
    a = ap.parse_args(argv)
    out = {}
    for label, dirs in (("banc", a.dirs), ("avant", a.avant), ("apres", a.apres)):
        if dirs:
            runs = [read_run(d) for d in dirs]
            out[label] = {"runs": runs, "group": show(label, runs)}
    if a.json:
        with open(a.json, "w", encoding="utf-8") as fh:
            json.dump(out, fh, ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
