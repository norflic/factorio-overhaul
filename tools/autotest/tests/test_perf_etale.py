# Lot PERF, correction après revue (27/10) : contrôles de tools/autotest/perf_etale.py sur des données fabriquées.
#   - le REPORT garde le travail (somme et moyenne égales, reste nul quand le budget suffit) ; l'ancien plafond le supprime ;
#   - délai de la file : un pic de 9,6 ms au-delà du plafond, budget 1 ms par tick : soldé en 9 ticks ;
#   - pente et ordonnée retrouvées sur des ticks d'A* fabriqués (y = 0,5 + 0,006 × développements) ;
#   - lecture du journal : A* du même tick juste avant une ligne « attend » attribués à la porte refusée, et pas ceux
#     d'un itinéraire accepté ;
#   - de bout en bout sur une archive fabriquée (fichiers .gz), statistiques comme analyze.py ;
#   - mutant : un report qui perd le travail au-delà du budget est vu par le contrôle de conservation.
# Usage : py -3.9 -B tools/autotest/tests/test_perf_etale.py
import gzip
import io
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import perf_etale as P  # noqa: E402

ok = ko = 0


def check(cond, msg):
    global ok, ko
    if cond:
        ok += 1
    else:
        ko += 1
        print("  ECHEC : " + msg)


# 1. Report contre plafond
ticks = list(range(1, 1001))
vals = [0.2] * 1000
for t in range(50, 1000, 100):
    vals[t - 1] = 10.0
spike = lambda t: t % 100 == 50  # noqa: E731
cap = 0.4


def m1(t, v):
    if spike(t) and v > cap:
        return cap, v - cap
    return v, 0.0


out, rest, delays, pend = P.spread(ticks, vals, m1, 1.0)
check(abs(sum(out) + rest - sum(vals)) < 1e-9, "report : travail conservé (%.6f + %.6f contre %.6f)" % (sum(out), rest, sum(vals)))
check(rest < 1e-9 and pend == 0, "report : rien ne reste quand le budget suffit")
check(abs(P.stats(out)[0] - P.stats(vals)[0]) < 1e-9, "report : moyenne inchangée")
check(abs(max(out) - 1.4) < 1e-9, "report : pics aplatis à plafond + budget (max %.2f contre 10)" % max(out))
check(delays and max(delays) == 9, "délai : 9,6 ms à 1 ms par tick, soldé en 9 ticks (%s)" % (max(delays) if delays else None))
cp = P.capped(ticks, vals, spike, cap)
check(P.stats(cp)[0] < P.stats(vals)[0] - 0.09, "ancien plafond : la moyenne baisse (travail supprimé : %.3f contre %.3f)"
      % (P.stats(cp)[0], P.stats(vals)[0]))

# 2. Pente
devs = {}
vals2 = []
for t in ticks:
    if t % 10 == 5:
        devs[t] = 100 + (t * 37) % 900
        vals2.append(0.5 + 0.006 * devs[t])
    else:
        vals2.append(0.2)
b, a0, n = P.slope(ticks, vals2, devs, set())
check(abs(b - 0.006) < 1e-9 and abs(a0 - 0.5) < 1e-9, "régression : pente %.4f ms, ordonnée %.3f ms" % (b, a0))

# 3. Lecture du journal : attribution des A* à la porte refusée
log = "\n".join([
    "  1.0 Script @__factorio-overhaul__/script/core/trace.lua:13: [FO-TRACE] 100 ia3k astar 7",
    "  1.0 Script @__factorio-overhaul__/script/ai3/comportement.lua:441: [FO-IA3K] emerald : PNJ 4 itineraire A* de (0, 0) a (9, 9) : 1 point(s)",
    "  1.0 Script @__factorio-overhaul__/script/core/trace.lua:13: [FO-TRACE] 101 ia3k astar 341",
    "  1.0 Script @__factorio-overhaul__/script/core/trace.lua:13: [FO-TRACE] 101 ia3k astar 299",
    "  1.0 Script @__factorio-overhaul__/script/ai3/comportement.lua:602: [FO-IA3K] amber : PNJ 80 attend (bloque) : tache service vers (-184, -500), morts 0",
    "  1.0 Script @__factorio-overhaul__/script/core/trace.lua:13: [FO-TRACE] 300 team amber 3",
    "  1.0 Script @__factorio-overhaul__/script/ai3/comportement.lua:602: [FO-IA3K] amber : PNJ 81 attend (but) : tache mine vers (-187, -493), morts 0",
])
dv, team, ref = P.read_log(io.StringIO(log))
check(dv[100] == 7 and dv[101] == 640 and 300 in team, "journal : développements par tick, pensée d'équipe")
check(len(ref) == 2 and ref[0][6] == 101 and ref[0][7] == 640, "porte refusée : les 2 A* du tick 101 attribués (%s)" % (ref[:1],))
check(ref[1][7] == 0, "porte refusée sans A* juste avant : rien d'attribué (pas l'A* accepté du tick 100)")

# 4. De bout en bout sur une archive fabriquée
tmp = tempfile.mkdtemp(prefix="perf_etale_")
try:
    head = "tick,timestamp,wholeUpdate,scriptUpdate,entityUpdate,"
    lines = [head] + ["t%d,0,0,%d,0," % (t, round(v * 1e6)) for t, v in zip(ticks, vals2)]
    with gzip.open(os.path.join(tmp, "benchmark-stdout.txt.gz"), "wt", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    tr = ["  1.0 Script @__x__/t.lua:1: [FO-TRACE] %d ia3k astar %d" % (t, d) for t, d in sorted(devs.items())]
    with gzip.open(os.path.join(tmp, "benchmark.log.gz"), "wt", encoding="utf-8") as f:
        f.write("\n".join(tr) + "\n")
    with gzip.open(os.path.join(tmp, "benchmark-stdout.txt.gz"), "rt", encoding="utf-8") as f:
        tk, vv = P.read_script(f)
    check(tk == ticks and abs(sum(vv) - sum(vals2)) < 1e-6, "lecture de benchmark-stdout.txt.gz")
    buf = io.StringIO()
    old = sys.stdout
    sys.stdout = buf
    try:
        code = P.main([tmp, "--budgets", "1.0"])
    finally:
        sys.stdout = old
    txt = buf.getvalue()
    m = P.stats(vals2)
    check(code == 0 and ("moy %.3f" % m[0]) in txt and ("p99 %5.2f" % m[2]) in txt, "de bout en bout : la ligne « mesure » redonne la moyenne et le p99")
    check("pente 6.00 us" in txt, "de bout en bout : pente lue")
finally:
    shutil.rmtree(tmp, ignore_errors=True)

# 5. Mutant : un report qui jette le travail au-delà du budget
real = P.spread


def lossy(ticks_, vals_, moved, budget):
    out_ = []
    for t, v in zip(ticks_, vals_):
        keep, mv = moved(t, v)
        out_.append(keep + min(mv, budget))
    return out_, 0.0, [], 0


o2, r2, _, _ = lossy(ticks, vals, m1, 1.0)
check(abs(sum(o2) + r2 - sum(vals)) > 1e-3, "mutant (travail jeté) vu par le contrôle de conservation")

print("[PERF-ETALE] BILAN : %d OK, %d ECHEC(S)" % (ok, ko))
sys.exit(0 if ko == 0 else 1)
