# Lot PERF, correction après revue (27/10) : que donneraient l'A* ÉTALÉ et la pensée d'équipe DÉCOUPÉE sur une mesure K10 ?
#
# La première simulation du lot (whatif.py, dossier de travail) plafonnait les ticks d'A* et de pensée d'équipe à 2 × la
# médiane : elle SUPPRIMAIT le travail au-delà du plafond. Or étaler une recherche ou découper une pensée garde le même
# travail au total (tests/perf_test.lua : mêmes développements quel que soit le découpage) : la moyenne ne peut pas baisser.
# Cet outil REPORTE le travail sur les ticks suivants (file premier entré, premier sorti), avec un budget fixe par tick :
#   - modèle 1 : tout l'excédent au-delà de 2 × la médiane, aux ticks d'A* et de pensée d'équipe, est reporté ;
#   - modèle 2 : seuls les DÉVELOPPEMENTS de l'A* sont reportés (pente × développements, pente par régression sur les
#     ticks d'A* sans pensée d'équipe) ; le reste du tick (ordonnée : champ du danger, profil exact, porte, et le travail
#     ordinaire du tick) reste en place ; la pensée d'équipe est reportée au-delà de 2 × la médiane ;
#   - « à retirer » : ce que la moyenne doit PERDRE pour la cible (le report ne la change pas) ;
#   - portes refusées : les A* faits pour une porte qui refuse (lignes « [FO-IA3K] ... attend (...) » du journal, A* du
#     même tick juste avant), leurs répétitions vers la même destination, et le modèle 2 sans ces A* répétés.
# Statistiques comme tools/autotest/analyze.py (tous les ticks mesurés, même centile) : la ligne « mesure » redonne ses
# chiffres de scriptUpdate.
# Usage : py -3.9 -B tools/autotest/perf_etale.py <archive de banc.py ou dossier décompressé> [--pente <µs>]
#         [--budgets 0.3,0.5,0.7,1.0] [--cible 0.25] [--cible-p99 2.0]
# Lit benchmark-stdout.txt(.gz) et benchmark.log(.gz) ; aucune écriture.
import collections
import gzip
import os
import re
import sys

RE_TRACE = re.compile(r"\[FO-TRACE\] (\d+) (\S+) (\S+) (-?\d+)")
RE_ATTEND = re.compile(r"\[FO-IA3K\] (\S+) : PNJ (\d+) attend \((\S+)\) : tache (\S+) vers \((-?\d+), (-?\d+)\)")


def opn(d, name):
    p = os.path.join(d, name)
    if os.path.exists(p):
        return open(p, encoding="utf-8", errors="replace")
    if os.path.exists(p + ".gz"):
        return gzip.open(p + ".gz", "rt", encoding="utf-8", errors="replace")
    raise SystemExit("absent : " + p + "(.gz)")


def pct(values, q):
    # même centile que tools/autotest/analyze.py
    if not values:
        return 0.0
    s = sorted(values)
    i = min(len(s) - 1, int(q * (len(s) - 1) + 0.5))
    return s[i]


def stats(v):
    return sum(v) / len(v), pct(v, 0.5), pct(v, 0.99), max(v)


def read_script(f):
    """scriptUpdate par tick (ms), en ordre de tick. Même lecture que analyze.parse_verbose."""
    header, rows = None, {}
    for line in f:
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
            i = header.index("scriptUpdate")  # header[0] = tick : cells est aligné sur header
            try:
                rows[tick] = int(cells[i]) / 1e6
            except (ValueError, IndexError):
                rows[tick] = 0.0
    ticks = sorted(rows)
    return ticks, [rows[t] for t in ticks]


def read_log(f):
    """Ticks d'A* (développements par tick), ticks de pensée d'équipe, A* des portes refusées."""
    devs = collections.Counter()
    team = set()
    refused = []  # (faction, pnj, raison, tache, x, y, tick, developpements)
    block = []  # traces ia3k astar consécutives (tick, développements) juste avant la ligne courante
    for line in f:
        m = RE_TRACE.search(line)
        if m:
            t, kind, a, b = int(m.group(1)), m.group(2), m.group(3), int(m.group(4))
            if kind == "ia3k" and a == "astar":
                devs[t] += b
                if block and block[-1][0] != t:
                    block = []
                block.append((t, b))
                continue
            if kind == "team":
                team.add(t)
            block = []
            continue
        m = RE_ATTEND.search(line)
        if m:
            if block:
                t = block[-1][0]
                n = sum(b for tt, b in block if tt == t)
            else:
                t, n = None, 0
            refused.append((m.group(1), int(m.group(2)), m.group(3), m.group(4), int(m.group(5)), int(m.group(6)), t, n))
            block = []
            continue
        if "[FO-" in line:
            block = []
    return devs, team, refused


def slope(ticks, vals, devs, team):
    """Régression linéaire du temps script sur les développements, ticks d'A* sans pensée d'équipe (comme regr.py)."""
    pts = [(devs[t], v) for t, v in zip(ticks, vals) if t in devs and t not in team and t % 300 > 3]
    n = len(pts)
    if n < 2:
        return 0.0, 0.0, n
    mx = sum(p[0] for p in pts) / n
    my = sum(p[1] for p in pts) / n
    sxx = sum((x - mx) ** 2 for x, _ in pts)
    if sxx == 0:
        return 0.0, my, n
    b = sum((x - mx) * (y - my) for x, y in pts) / sxx
    return b, my - b * mx, n


def capped(ticks, vals, spike, cap):
    """ANCIENNE simulation (whatif.py) : ticks visés plafonnés, travail au-delà SUPPRIMÉ."""
    return [min(v, cap) if spike(t) else v for t, v in zip(ticks, vals)]


def spread(ticks, vals, moved, budget):
    """Report : moved(t, v) -> (gardé dans le tick, reporté). File premier entré, premier sorti ; au plus `budget` ms de
    travail reporté par tick, ajoutés au travail du tick (le reporté peut commencer au tick même où il naît).
    Rend (temps par tick, reste à la fin en ms, délais en ticks de chaque dépôt soldé, dépôts non soldés)."""
    out, q, delays = [], collections.deque(), []
    for t, v in zip(ticks, vals):
        keep, mv = moved(t, v)
        if mv > 0:
            q.append([t, mv])
        room = budget
        took = 0.0
        while q and room > 1e-12:
            item = q[0]
            d = min(item[1], room)
            item[1] -= d
            room -= d
            took += d
            if item[1] <= 1e-12:
                delays.append(t - item[0])
                q.popleft()
        out.append(keep + took)
    return out, sum(i[1] for i in q), delays, len(q)


def fmt_stats(label, v, total_in=None, rest=None, delays=None, pending=0):
    mean, med, p99, mx = stats(v)
    s = "%-58s moy %.3f  p50 %.3f  p99 %5.2f  max %6.1f" % (label, mean, med, p99, mx)
    if rest is not None:
        s += "  | reste %.1f ms" % rest
    if delays is not None:
        if delays:
            s += ", delai p99 %d ticks, max %d" % (pct(delays, 0.99), max(delays))
        if pending:
            s += ", %d depot(s) non solde(s)" % pending
    return s


def main(argv):
    args, opts = [], {"pente": None, "budgets": "0.3,0.5,0.7,1.0", "cible": "0.25", "cible-p99": "2.0"}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a.startswith("--") and a[2:] in opts:
            opts[a[2:]] = argv[i + 1]
            i += 2
            continue
        args.append(a)
        i += 1
    if len(args) != 1:
        print(__doc__ or "usage : perf_etale.py <archive> [--pente us] [--budgets ...] [--cible ms]")
        return 2
    d = args[0]
    with opn(d, "benchmark-stdout.txt") as f:
        ticks, vals = read_script(f)
    with opn(d, "benchmark.log") as f:
        devs, team, refused = read_log(f)
    if not ticks:
        print("aucune mesure par tick")
        return 2
    budgets = [float(x) for x in opts["budgets"].split(",")]
    cible, cible99 = float(opts["cible"]), float(opts["cible-p99"])
    mean, med, p99, mx = stats(vals)
    cap = 2 * med
    b, a0, npts = slope(ticks, vals, devs, team)
    if opts["pente"] is not None:
        b = float(opts["pente"]) / 1000.0
    total = sum(vals)
    print("== %s : %d ticks mesures" % (os.path.basename(os.path.normpath(d)), len(ticks)))
    print(fmt_stats("mesure (comme analyze.py)", vals))
    print("   ticks d'A* : %d ; ticks de pensee d'equipe : %d ; plafond des pics 2 x mediane = %.3f ms" % (len(devs), len(team), cap))
    print("   pente %.2f us par developpement, ordonnee %.2f ms par tick d'A* (%d ticks d'A* sans pensee d'equipe)%s"
          % (1000 * b, a0, npts, " ; pente IMPOSEE" if opts["pente"] is not None else ""))
    spike = lambda t: t in devs or t in team  # noqa: E731
    print(fmt_stats("ANCIEN plafond (travail SUPPRIME, simulation fausse)", capped(ticks, vals, spike, cap)))

    def model1(t, v):
        if spike(t) and v > cap:
            return cap, v - cap
        return v, 0.0

    def model2_for(dv):
        def m(t, v):
            mv = 0.0
            if t in dv:
                mv = min(v, b * dv[t])
                v -= mv
            if t in team and v > cap:
                mv += v - cap
                v = cap
            return v, mv
        return m

    print("-- modele 1 : tout l'excedent des ticks d'A* et de pensee d'equipe REPORTE")
    for bud in budgets:
        out, rest, dl, pend = spread(ticks, vals, model1, bud)
        print(fmt_stats("   budget %.1f ms par tick" % bud, out, rest=rest, delays=dl, pending=pend))
    print("-- modele 2 : seuls les developpements de l'A* reportes (ordonnee gardee), pensee d'equipe reportee")
    m2 = model2_for(devs)
    for bud in budgets:
        out, rest, dl, pend = spread(ticks, vals, m2, bud)
        print(fmt_stats("   budget %.1f ms par tick" % bud, out, rest=rest, delays=dl, pending=pend))
    need = mean - cible
    print("-- a RETIRER pour la cible de moyenne %.2f ms : %.3f ms par tick (%.0f %% du script), le report ne change pas la moyenne"
          % (cible, need, 100 * need / mean if mean else 0))
    # Portes refusées : A* attribués, répétitions vers la même destination (faction, case de destination, raison).
    att = [r for r in refused if r[6] is not None and r[7] > 0]
    dev_ref = sum(r[7] for r in att)
    print("-- portes refusees (lignes « attend ») : %d, dont %d avec un A* attribue (%d developpements, %.1f ms a la pente,"
          " %.1f %% du script)" % (len(refused), len(att), dev_ref, b * dev_ref, 100 * b * dev_ref / total if total else 0))
    seen = set()
    rep = collections.Counter()
    for r in refused:
        k = (r[0], r[2], r[4] // 8, r[5] // 8)
        if k in seen and r[6] is not None and r[7] > 0:
            rep[r[6]] += r[7]
        seen.add(k)
    dev_rep = sum(rep.values())
    print("   destinations distinctes (faction, raison, case de 8 tuiles) : %d ; repetitions : %d A* de tick, %d developpements, "
          "%.1f ms a la pente (%.1f %% du script, %.4f ms par tick)"
          % (len(seen), len(rep), dev_rep, b * dev_rep, 100 * b * dev_rep / total if total else 0, b * dev_rep / len(ticks)))
    dv2 = collections.Counter(devs)
    for t, n in rep.items():
        dv2[t] -= n
        if dv2[t] <= 0:
            del dv2[t]
    vals_r = [v - min(v, b * rep.get(t, 0)) for t, v in zip(ticks, vals)]
    print(fmt_stats("   sans les A* des refus repetes (developpements seuls)", vals_r))
    for bud in budgets:
        out, rest, dl, pend = spread(ticks, vals_r, model2_for(dv2), bud)
        print(fmt_stats("   puis modele 2, budget %.1f ms par tick" % bud, out, rest=rest, delays=dl, pending=pend))
    print("-- cibles K10 : moyenne <= %.2f ms, p99 <= %.1f ms" % (cible, cible99))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
