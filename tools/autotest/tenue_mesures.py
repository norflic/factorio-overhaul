# Lot TENUE : verdicts T1 a T3 de fo-logs/2026-11-02_TENUE/CRITERES.md, lus dans les archives de banc.py (scenario dc-croissance, 4 h).
# Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/tenue_mesures.py <archive> [<archive> ...]
# Par archive et par faction (hors votre equipe) :
#   T1 vivante a 240 min     : pas de ligne [FO-ANEANTI] avant la fin de la partie (la partie dure 240 min ; fin = derniere minute vue)
#   T2 fer/min a 180 min >= 0,8 x fer/min a 120 min   (releves [FO-REGARD] R, flux_min iron-plate ; releve de 5 min le plus proche)
#   T3 soldats > 0 a 240 min : derniere ligne [FO-DC-CROISSANCE] "minute N | vivantes" (soldats de la faction)
# Une faction n'est jugee que si elle a au moins JUGEE_MIN fer/min a 120 min (sinon : « non jugee », elle n'a jamais produit).
import gzip
import os
import re
import sys

JUGEE_MIN = 200
RATIO = 0.8
R_LINE = re.compile(r"\[FO-REGARD\] R min=(\d+) force=(\S+) cle=(\S+) n=(\d+) max=\d+ soldats=(\d+) .*?flux_min \{([^}]*)\}")
ANE_LINE = re.compile(r"\[FO-ANEANTI\] tick (\d+) \(([\d.]+) min\) (\S+) : QG detruit \| cause (.*?) \| PNJ restants : ouvriers (\d+), soldats (\d+)")
KV = re.compile(r"([\w-]+)=(\S+)")
CLES = ("scarlet", "azure", "emerald")


def lire(arch):
    for nom in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, nom)
        if os.path.exists(p):
            f = gzip.open(p, "rt", encoding="utf8", errors="replace") if nom.endswith(".gz") else open(p, encoding="utf8", errors="replace")
            with f:
                return f.read().splitlines()
    return []


def analyser(lignes):
    fer = {c: {} for c in CLES}      # fer[cle][minute] = fer/min
    sold = {c: {} for c in CLES}     # sold[cle][minute] = soldats
    ouv = {c: {} for c in CLES}
    mort = {}                        # cle -> (minute, cause)
    derniere = 0
    for ln in lignes:
        m = R_LINE.search(ln)
        if m:
            cle = m.group(3)
            if cle in fer:
                kv = dict(KV.findall(m.group(6)))
                mn = int(m.group(1))
                derniere = max(derniere, mn)
                try:
                    fer[cle][mn] = float(kv.get("iron-plate", "0"))
                except ValueError:
                    pass
                sold[cle][mn] = int(m.group(5))
                ouv[cle][mn] = int(m.group(4))
            continue
        m = ANE_LINE.search(ln)
        if m and m.group(3) in CLES:
            mort[m.group(3)] = (float(m.group(2)), m.group(4))
    return fer, sold, ouv, mort, derniere


def proche(serie, minute, tol=5):
    """Valeur de la serie a la minute la plus proche (au plus tol minutes), sinon None."""
    if not serie:
        return None
    k = min(serie, key=lambda x: abs(x - minute))
    return serie[k] if abs(k - minute) <= tol else None


def traiter(arch):
    seed = ""
    sp = os.path.join(arch, "seed.txt")
    if os.path.exists(sp):
        seed = open(sp).read().strip()
    fer, sold, ouv, mort, derniere = analyser(lire(arch))
    print("== %s (graine %s, partie jusqu'a la minute %d)" % (os.path.basename(os.path.normpath(arch)), seed or "?", derniere))
    cas = tenus = 0
    for c in CLES:
        f120, f180 = proche(fer[c], 120), proche(fer[c], 180)
        fin = max(sold[c]) if sold[c] else None
        s240 = sold[c].get(fin) if fin is not None else None
        o240 = ouv[c].get(fin) if fin is not None else None
        m_mort = mort.get(c)
        t1 = m_mort is None
        t2 = (f120 is not None and f180 is not None and f180 >= RATIO * f120)
        t3 = s240 is not None and s240 > 0 and t1
        jugee = f120 is not None and f120 >= JUGEE_MIN
        if jugee:
            cas += 1
            if t1 and t2 and t3:
                tenus += 1
        print("  %-8s fer/min 120=%s 180=%s | soldats a la fin %s | ouvriers %s | %s | %s" % (
            c, "-" if f120 is None else "%.0f" % f120, "-" if f180 is None else "%.0f" % f180,
            "-" if s240 is None else s240, "-" if o240 is None else o240,
            "ANEANTIE a %.1f min (%s)" % m_mort if m_mort else "vivante",
            ("T1 %s T2 %s T3 %s" % tuple("OK " if x else "FAUX" for x in (t1, t2, t3))) if jugee else "non jugee (fer/min a 120 min < %d)" % JUGEE_MIN))
    print("  -> cas jugeables %d, tenus (T1+T2+T3) %d" % (cas, tenus))
    return cas, tenus


def main():
    if len(sys.argv) < 2:
        print(__doc__ or "usage : tenue_mesures.py <archive>...")
        return 2
    tc = tt = 0
    for a in sys.argv[1:]:
        c, t = traiter(a)
        tc, tt = tc + c, tt + t
    print("TOTAL : %d cas tenus sur %d jugeables" % (tt, tc))
    return 0


if __name__ == "__main__":
    sys.exit(main())
