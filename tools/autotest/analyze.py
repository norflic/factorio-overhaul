#!/usr/bin/env python3
"""
Analyse des résultats de fo-autotest.bat (moteur réel).

    python3 tools/autotest/analyze.py <dossier fo-autotest>

Lit :
  - benchmark-stdout.txt : sortie de --benchmark-verbose all (une ligne CSV par tick, en nanosecondes)
  - create.log, benchmark.log : journaux du moteur (erreurs, lignes [FO-AUTOTEST] / [FO-BENCH] / [FO-WAR])
Affiche : erreurs, résumé du benchmark, coût moyen / p99 / max par poste (ms), coût du script par minute,
et les rapports du mod de test.
"""
import os
import re
import sys

FOCUS = ["wholeUpdate", "gameUpdate", "scriptUpdate", "entityUpdate", "pathFinder", "commander",
         "mapGenerator", "luaGarbageIncremental", "electricNetworkUpdate", "chartRefresh"]


def read(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def pct(values, q):
    if not values:
        return 0.0
    s = sorted(values)
    i = min(len(s) - 1, int(q * (len(s) - 1) + 0.5))
    return s[i]


def parse_verbose(text):
    header, rows = None, []
    for line in text.splitlines():
        line = line.strip()
        if header is None and "wholeUpdate" in line and "," in line:
            header = [c for c in line.split(",") if c != ""]
            continue
        if header and line.startswith("t") and "," in line:
            cells = [c for c in line.split(",") if c != ""]
            try:
                tick = int(cells[0][1:])
            except ValueError:
                continue
            values = []
            for c in cells[1:]:
                try:
                    values.append(int(c))
                except ValueError:
                    values.append(0)
            rows.append((tick, values))
    return header, rows


def main():
    d = sys.argv[1] if len(sys.argv) > 1 else "fo-autotest"
    for name in ("create.log", "benchmark.log"):
        text = read(os.path.join(d, name))
        if text is None:
            print(f"== {name} : absent")
            continue
        errs = [l for l in text.splitlines() if "Error" in l or "error" in l.lower() and "0 error" not in l.lower()]
        print(f"== {name} : {len(text.splitlines())} lignes, {len(errs)} ligne(s) d'erreur")
        for l in errs[:20]:
            print("   ! " + l.strip())
        tagged = [l for l in text.splitlines() if "[FO-" in l]
        for l in tagged:
            print("   " + l.split("Script ")[-1].strip() if "Script " in l else "   " + l.strip())

    calib(read(os.path.join(d, "benchmark.log")) or "")
    out = read(os.path.join(d, "benchmark-stdout.txt"))
    if out is None:
        print("== benchmark-stdout.txt : absent")
        return
    for l in out.splitlines():
        if l.startswith("Performed") or l.startswith("avg") or "Error" in l:
            print("== " + l.strip())
    header, rows = parse_verbose(out)
    if not header or not rows:
        print("== pas de mesures par tick (--benchmark-verbose)")
        return
    cols = header[1:]  # header[0] = "tick"
    # Certaines versions ajoutent "timestamp" en 2e colonne
    print(f"== {len(rows)} ticks mesurés, {len(cols)} colonnes")
    print(f"{'poste':28s} {'moy ms':>8s} {'p50':>8s} {'p99':>8s} {'max':>8s}")
    for name in FOCUS:
        if name not in cols:
            continue
        i = cols.index(name)
        vals = [v[i] / 1e6 for _, v in rows if i < len(v)]
        print(f"{name:28s} {sum(vals) / len(vals):8.3f} {pct(vals, .5):8.3f} {pct(vals, .99):8.3f} {max(vals):8.3f}")
    if "scriptUpdate" in cols and "wholeUpdate" in cols:
        si, wi = cols.index("scriptUpdate"), cols.index("wholeUpdate")
        pi = cols.index("pathFinder") if "pathFinder" in cols else None
        print("minute  script_moy  script_p99  update_moy  pathfinder_moy")
        by_min = {}
        for tick, v in rows:
            by_min.setdefault(tick // 3600, []).append(v)
        for m in sorted(by_min):
            vs = by_min[m]
            s = [x[si] / 1e6 for x in vs]
            w = [x[wi] / 1e6 for x in vs]
            p = [x[pi] / 1e6 for x in vs] if pi is not None else [0]
            print(f"{m:6d}  {sum(s) / len(s):10.3f}  {pct(s, .99):10.3f}  {sum(w) / len(w):10.3f}  {sum(p) / len(p):14.3f}")


def calib(log):
    """Étalon machine ([FO-CALIB]) : même charge Lua toutes les 10 s ; sa dispersion mesure le bruit de la machine."""
    vals = []
    for l in log.splitlines():
        if "[FO-CALIB]" in l:
            m = re.search(r"\[FO-CALIB\] (\d+) Duration: ([0-9.]+)ms", l)
            if m:
                vals.append((int(m.group(1)), float(m.group(2))))
    if not vals:
        return
    ms = sorted(v for _, v in vals)
    med = ms[len(ms) // 2]
    slow = [(t, v) for t, v in vals if v > 1.5 * med]
    print(f"== étalon machine : {len(vals)} mesures, médiane {med:.2f} ms, min {ms[0]:.2f}, max {ms[-1]:.2f}, "
          f"{len(slow)} mesure(s) > 1,5 × médiane")
    for t, v in slow[:10]:
        print(f"   lent : tick {t} ({t / 3600:.1f} min) {v:.2f} ms")


def spikes(d, threshold_ms=2.0, skip_ticks=600):
    """Attribue les pics de scriptUpdate aux traces [FO-TRACE] du même tick (événements coûteux)."""
    out = read(os.path.join(d, "benchmark-stdout.txt"))
    log = read(os.path.join(d, "benchmark.log")) or ""
    if not out:
        return
    header, rows = parse_verbose(out)
    if not header:
        return
    cols = header[1:]
    si = cols.index("scriptUpdate")
    traces = {}
    for l in log.splitlines():
        if "[FO-TRACE]" in l:
            parts = l.split("[FO-TRACE] ", 1)[1].split()
            if len(parts) >= 2:
                traces.setdefault(int(parts[0]), []).append(" ".join(parts[1:]))
    # Les ticks multiples de 600 portent l'étalon machine (charge fixe) : exclus.
    spk = [(t, v[si] / 1e6) for t, v in rows if t > skip_ticks and t % 600 != 0 and v[si] / 1e6 > threshold_ms]
    if not spk:
        print(f"== pics de script > {threshold_ms} ms : aucun")
        return
    kinds, unexplained = {}, 0
    for t, ms in spk:
        tr = traces.get(t)
        if not tr:
            unexplained += 1
            continue
        for x in tr:
            k = x.split()[0] + (":" + x.split()[1] if x.split()[0] == "path" else "")
            kinds.setdefault(k, []).append(ms)
    total_ticks = len([1 for t, _ in rows if t > skip_ticks])
    print(f"== pics de script > {threshold_ms} ms : {len(spk)} ticks sur {total_ticks} ({100 * len(spk) / max(1, total_ticks):.1f} %), sans trace : {unexplained}")
    for k, v in sorted(kinds.items(), key=lambda kv: -len(kv[1])):
        print(f"   {k:30s} {len(v):6d} pics, moy {sum(v) / len(v):6.2f} ms")
    # Proportion des traces qui tombent sur un pic
    for kind in sorted({x.split()[0] for xs in traces.values() for x in xs}):
        ticks = [t for t, xs in traces.items() if any(x.split()[0] == kind for x in xs) and t > skip_ticks]
        if ticks:
            sp = set(t for t, _ in spk)
            print(f"   trace {kind:10s} : {len(ticks)} occurrences, {100 * sum(1 for t in ticks if t in sp) / len(ticks):.0f} % sur un pic")


if __name__ == "__main__":
    main()
    if len(sys.argv) > 2 and sys.argv[2] == "--spikes":
        spikes(sys.argv[1])
