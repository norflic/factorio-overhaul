#!/usr/bin/env python3
"""
Lot IA1-a « Échelle 30 » : lecture du banc ia1-scale (docs/EQUIPES_PNJ.md §16).

    py -3.9 -B tools/autotest/ia1_scale.py <dossier fo-autotest ou archive> [--csv <fichier>] [--seuil-script 0.25]

Lit benchmark-stdout.txt (--benchmark-verbose : temps script par tick) et benchmark.log (lignes [FO-IA1-SCALE]).
Publie :
  - temps script (scriptUpdate) : moyenne, p99, max, par tranche de 10 min ; seuil du lot : moyenne <= 0,25 ms ;
  - BILAN du scénario (effectifs, chemins, « but occupé », demandes en vol et émises par tick) ;
  - par équipe et par minute : effectif, inactivité RÉELLE, exécutants AU-DELÀ DU CARNET, production en MU ;
  - le « m » de Q-IA1-1 : production moyenne de l'équipe (MU/s, minutes 10 à 60) ÷ débit nominal X0 de
    l'époque 1 (X.rate_avg(1) = 2,252 MU/s, shared/content/epochs.lua).
Code de sortie : 0 si le BILAN est sans échec ET la moyenne du script sous le seuil ; 1 sinon ; 2 si illisible.
"""
import argparse
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyze  # noqa: E402  (parse_verbose, pct, calib)

TAG = "[FO-IA1-SCALE]"
# Débit moyen nominal X0 de l'époque 1 (shared/content/epochs.lua : X.rate_avg(1)).
RATE1 = (3 - 3 / (14000 / 3) ** (1 / 14)) / math.log((14000 / 3) ** (1 / 14))

TEAM_RE = re.compile(r"minute (\d+) \| (\w+) n=(\d+)/(\d+) recrues=(\d+) garde=(\d+) inactifs=([0-9.]+)% "
                     r"au-dela=([0-9.]+) mu=(-?\d+)")
PATH_RE = re.compile(r"minute (\d+) \| agents (\d+) \| chemins demandes (\d+) emis (\d+) ok (\d+) echecs (\d+) "
                     r"\(([0-9.]+) %\) but_occupe (\d+)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--csv", default=None)
    ap.add_argument("--seuil-script", type=float, default=0.25)
    a = ap.parse_args()

    out = analyze.read(os.path.join(a.dir, "benchmark-stdout.txt"))
    log = analyze.read(os.path.join(a.dir, "benchmark.log"))
    if out is None or log is None:
        print("ILLISIBLE : benchmark-stdout.txt ou benchmark.log absent")
        return 2
    header, rows = analyze.parse_verbose(out)
    if not header or not rows:
        print("ILLISIBLE : aucune mesure par tick")
        return 2
    cols = header[1:]
    si = cols.index("scriptUpdate")
    wi = cols.index("wholeUpdate")
    ei = cols.index("entityUpdate") if "entityUpdate" in cols else None
    pfi = cols.index("pathFinder") if "pathFinder" in cols else None
    script = [v[si] / 1e6 for _, v in rows]
    whole = [v[wi] / 1e6 for _, v in rows]
    mean = sum(script) / len(script)
    print(f"== {len(rows)} ticks mesures ({len(rows) / 3600:.1f} min de jeu)")
    print(f"== script : moyenne {mean:.3f} ms, p99 {analyze.pct(script, .99):.3f}, max {max(script):.3f} "
          f"(seuil du lot {a.seuil_script} ms : {'OK' if mean <= a.seuil_script else 'ECHEC'})")
    print(f"== tick complet (wholeUpdate) : moyenne {sum(whole) / len(whole):.3f} ms, p99 {analyze.pct(whole, .99):.3f}, "
          f"max {max(whole):.3f} ; ticks > 16,7 ms : {sum(1 for w in whole if w > 16.7)}")
    if ei is not None:
        ent = [v[ei] / 1e6 for _, v in rows]
        print(f"== entityUpdate : moyenne {sum(ent) / len(ent):.3f} ms")
    if pfi is not None:
        pf = [v[pfi] / 1e6 for _, v in rows]
        print(f"== pathFinder (C++) : moyenne {sum(pf) / len(pf):.3f} ms, p99 {analyze.pct(pf, .99):.3f}")
    print("tranche   script_moy  script_p99")
    buckets = {}
    for (tick, v), s in zip(rows, script):
        buckets.setdefault(tick // 36000, []).append(s)
    for b in sorted(buckets):
        s = buckets[b]
        print(f"{b * 10:3d}-{b * 10 + 10:<3d}  {sum(s) / len(s):10.3f}  {analyze.pct(s, .99):10.3f}")
    analyze.calib(log)

    bilan = None
    for line in log.splitlines():
        if TAG in line and ("OK " in line or "ECHEC" in line or "BILAN" in line):
            txt = line.split(TAG, 1)[1].strip()
            print("   " + txt)
            if "BILAN" in txt:
                bilan = txt
    teams, paths = {}, []
    for line in log.splitlines():
        if TAG not in line:
            continue
        m = TEAM_RE.search(line)
        if m:
            minute, key = int(m.group(1)), m.group(2)
            teams.setdefault(key, []).append({
                "minute": minute, "n": int(m.group(3)), "max": int(m.group(4)), "recruited": int(m.group(5)),
                "guard": int(m.group(6)), "idle": float(m.group(7)), "surplus": float(m.group(8)),
                "mu": int(m.group(9)),
            })
            continue
        m = PATH_RE.search(line)
        if m:
            paths.append([int(g) if g.isdigit() else float(g) for g in m.groups()])
    print(f"== production nominale X0 a l'epoque 1 : {RATE1:.3f} MU/s")
    print("equipe     effectif(min 60)  atteint 27 a  inactivite 30-60 min  au-dela du carnet 30-60  MU/s 10-60  m")
    for key in sorted(teams):
        series = teams[key]
        reach = next((r["minute"] for r in series if r["n"] >= 27), None)
        late = [r for r in series if 30 <= r["minute"] <= 60]
        mid = [r for r in series if 10 <= r["minute"] <= 60 and r["mu"] >= 0]
        idle = sum(r["idle"] for r in late) / len(late) if late else float("nan")
        surplus = sum(r["surplus"] for r in late) / len(late) if late else float("nan")
        mu_s = sum(r["mu"] for r in mid) / len(mid) / 60 if mid else float("nan")
        print(f"{key:10s} {series[-1]['n']:>4d}/{series[-1]['max']:<4d}       {str(reach):>6s}        "
              f"{idle:8.1f} %               {surplus:6.1f}            {mu_s:7.2f}   {mu_s / RATE1:5.2f}")
    if a.csv:
        with open(a.csv, "w", encoding="utf-8") as f:
            f.write("equipe;minute;effectif;max;recrues;garde;inactivite_pct;au_dela_du_carnet;production_mu_minute\n")
            for key in sorted(teams):
                for r in teams[key]:
                    f.write(f"{key};{r['minute']};{r['n']};{r['max']};{r['recruited']};{r['guard']};"
                            f"{r['idle']:.1f};{r['surplus']:.1f};{r['mu']}\n")
        print(f"== tableau par minute : {a.csv}")
    if paths:
        last = paths[-1]
        print(f"== chemins (cumul fin) : demandes {last[2]}, emises {last[3]}, ok {last[4]}, echecs {last[5]} "
              f"({last[6]} %), but occupe {last[7]}")
    ok = bilan is not None and "0 ECHEC" in bilan and mean <= a.seuil_script
    print("VERDICT : " + ("OK" if ok else "ECHEC") + (f" ({bilan})" if bilan else " (aucun BILAN)"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
