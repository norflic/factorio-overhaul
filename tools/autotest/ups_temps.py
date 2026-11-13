# Lot UPS (13/11) : temps de script par tick AVANT / APRÈS, sur deux archives de banc (partie-reelle-120, lancées avec --seul).
#
#   PYTHONUTF8=1 py -3.9 -B tools/autotest/ups_temps.py <archive avant> <archive après>
#
# Lit benchmark-stdout.txt.gz (--benchmark-verbose all : colonne scriptUpdate, nanosecondes par tick) et les blocs cumulés
# « Profiler (fenetre N ticks) » de benchmark.log.gz. Les ticks du mod de test (tick % 600 = 0 ou 1 : étalon, rapports du banc,
# recensement) sont écartés. Fenêtres : 50-60 min, 60-120 min, 110-120 min, partie entière. Aucune écriture, aucun jeu.
import gzip, re, sys, os

RE_F = re.compile(r"Profiler \(fenetre (\d+) ticks\)")
RE_P = re.compile(r":\s+(\S+) \| total Duration: ([0-9.]+)ms")


def blocs(arch):
    """{fenetre: {portee: ms cumulees}} des blocs du profileur."""
    out, cur = {}, None
    with gzip.open(os.path.join(arch, "benchmark.log.gz"), "rt", encoding="utf-8", errors="replace") as f:
        for l in f:
            m = RE_F.search(l)
            if m:
                cur = int(m.group(1))
                out[cur] = {}
                continue
            if cur is not None:
                m = RE_P.search(l)
                if m:
                    out[cur][m.group(1)] = float(m.group(2))
                elif "Duration" not in l:
                    cur = None
    return out


def ticks(arch):
    """[(tick, script ms, tick entier ms)] des lignes tN de --benchmark-verbose all."""
    hdr, res = None, []
    with gzip.open(os.path.join(arch, "benchmark-stdout.txt.gz"), "rt", encoding="utf-8", errors="replace") as f:
        for l in f:
            if hdr is None:
                if l.startswith("tick,") and "scriptUpdate" in l:
                    hdr = l.strip().split(",")
                    i_s, i_w = hdr.index("scriptUpdate"), hdr.index("wholeUpdate")
                continue
            if l[0] == "t" and "," in l:
                c = l.split(",")
                try:
                    res.append((int(c[0][1:]), int(c[i_s]) / 1e6, int(c[i_w]) / 1e6))
                except ValueError:
                    pass
    return res


def stats(v):
    v = sorted(v)
    n = len(v)
    return dict(n=n, moy=sum(v) / n, p50=v[n // 2], p99=v[int(n * 0.99)], p999=v[int(n * 0.999)], mx=v[-1],
                n167=sum(1 for x in v if x > 16.7), n8=sum(1 for x in v if x > 8.0))


FEN = [("50-60 min", 180000, 216000), ("60-120 min", 216000, 432000), ("110-120 min", 396000, 432000), ("0-120 min", 600, 432000)]
PORTEES = ("event:on_tick", "build:pulse", "sched:timers", "faction:team", "team:view", "team:build", "team:etape7", "lane:fo-brain",
           "capital:decide", "build:plan")

if __name__ == "__main__":
    R = [[x for x in ticks(a) if x[0] % 600 > 1] for a in sys.argv[1:3]]
    print("%-12s %-6s %8s %8s %8s %8s %9s %8s %8s | %8s" % ("fenetre", "", "moy", "p50", "p99", "p99.9", "max", ">16.7ms", ">8ms", "tick moy"))
    for nom, a, b in FEN:
        for lab, T in zip(("avant", "apres"), R):
            v = [s for t, s, w in T if a <= t < b]
            w = [w for t, s, w in T if a <= t < b]
            if v:
                st = stats(v)
                print("%-12s %-6s %8.3f %8.3f %8.2f %8.2f %9.1f %8d %8d | %8.3f" % (nom, lab, st["moy"], st["p50"], st["p99"], st["p999"],
                                                                                 st["mx"], st["n167"], st["n8"], sum(w) / len(w)))
    P = [blocs(a) for a in sys.argv[1:3]]
    if all(216000 in B and 432000 in B for B in P):
        print("profileur, 60 a 120 min (ms/tick, portees inclusives) : avant -> apres")
        for k in PORTEES:
            d = [(B[432000].get(k, 0.0) - B[216000].get(k, 0.0)) / 216000 for B in P]
            print("  %-16s %.4f -> %.4f" % (k, d[0], d[1]))
