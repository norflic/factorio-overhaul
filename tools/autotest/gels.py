# Lot OUTILLAGE (28/10) : d'où viennent les « gels » périodiques (le jeu ralentit puis réaccélère toutes les ~0,5 s à x10, soit
# environ toutes les 300 ticks) ? Analyse HORS JEU d'archives de banc (benchmark-stdout.txt[.gz], benchmark.log[.gz]) :
#   1. les ticks « pics » de scriptUpdate (au-dessus de PIC_FACTEUR x la médiane ET de PIC_MIN_MS) ;
#   2. leur rythme : écart le plus fréquent entre deux pics, part des pics alignés sur une période P (tick % P constant) ;
#   3. ce qui les cause : les lignes « [FO-TRACE] <tick> <type> ... » du journal posées sur le tick du pic ;
#   4. les pensées périodiques LOURDES du profileur (dernier bloc « Profiler (fenetre N ticks) » : total, moyenne par tick) ;
#   5. le COÛT DU GEL : surcoût du pic au-dessus de la médiane (ms), et ce que l'ÉTALEMENT sur P ticks en ferait (surcoût / P).
# Usage : py -3.9 -B tools/autotest/gels.py <archive de banc.py ou dossier> [...]  [--seuil-ms 3] [--facteur 4] [--top 12]
# Aucune écriture, aucun jeu. Règles pures : pics(), rythme(), alignement() (tests/test_gels.py).
import argparse
import collections
import gzip
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

PIC_FACTEUR = 4.0
PIC_MIN_MS = 3.0
RE_TRACE = re.compile(r"\[FO-TRACE\] (\d+) (\S+) (\S+) (\S+)")
RE_FENETRE = re.compile(r"Profiler \(fenetre (\d+) ticks\)")
RE_POSTE = re.compile(r"^\s*([^\s|]+) \| total Duration: ([0-9.]+)ms \| moyenne/tick Duration: ([0-9.]+)ms")


def mediane(v):
    s = sorted(v)
    return s[len(s) // 2] if s else 0.0


def pics(ticks, ms, facteur=PIC_FACTEUR, min_ms=PIC_MIN_MS):
    """Règle pure : [(tick, ms)] des ticks dont le coût dépasse facteur x la médiane ET min_ms."""
    med = mediane(ms)
    seuil = max(facteur * med, min_ms)
    return [(t, x) for t, x in zip(ticks, ms) if x > seuil]


def rythme(ticks_pics, max_ecart=2000):
    """Règle pure : (écart le plus fréquent entre pics voisins, nombre d'occurrences, part des écarts), sur les écarts <= max_ecart.
    (0, 0, 0.0) sans écart."""
    ecarts = [b - a for a, b in zip(ticks_pics, ticks_pics[1:]) if 0 < b - a <= max_ecart]
    if not ecarts:
        return 0, 0, 0.0
    e, n = collections.Counter(ecarts).most_common(1)[0]
    return e, n, n / len(ecarts)


def alignement(ticks_pics, periodes=range(32, 1201), largeur=4):
    """Règle pure : les périodes P dont une fenêtre de `largeur` restes consécutifs (r .. r + largeur - 1, tick % P) porte au moins
    60 % des pics (au moins 6 pics) ; [(P, r, part)], la plus GRANDE période d'abord (c'est la vraie : ses diviseurs s'alignent
    aussi et ne sont pas répétés). La fenêtre couvre les pensées de plusieurs ids sur des ticks voisins (créneaux consécutifs de
    l'ordonnanceur) ; P >= 8 x largeur : la fenêtre reste au plus 1/8 de la période, sinon tout s'aligne."""
    n = len(ticks_pics)
    res = []
    if n < 6:
        return res
    for p in sorted((q for q in periodes if q >= 8 * largeur), reverse=True):
        if any(q % p == 0 for q, _, _ in res):
            continue
        cnt = collections.Counter(t % p for t in ticks_pics)
        r, c = max(((r0, sum(cnt.get((r0 + k) % p, 0) for k in range(largeur))) for r0 in sorted(cnt)),
                   key=lambda z: (z[1], -z[0]))
        part = c / n
        if part >= 0.6:
            res.append((p, r, part))
    return res


def ouvrir(d, nom):
    p = os.path.join(d, nom)
    if os.path.exists(p):
        return open(p, encoding="utf-8", errors="replace")
    if os.path.exists(p + ".gz"):
        return gzip.open(p + ".gz", "rt", encoding="utf-8", errors="replace")
    return None


def serie_script(d):
    """([ticks], [ms scriptUpdate], [ms wholeUpdate]) lus dans benchmark-stdout (CSV par tick, nanosecondes)."""
    f = ouvrir(d, "benchmark-stdout.txt")
    if f is None:
        return [], [], []
    with f:
        texte = f.read()
    import analyze
    header, rows = analyze.parse_verbose(texte)
    if not header or "scriptUpdate" not in header or "wholeUpdate" not in header:
        return [], [], []
    # header[0] = tick, header[1] = timestamp ; rows[i][1] = valeurs à partir de la colonne 1 (après le tick)
    i_s = header.index("scriptUpdate") - 1
    i_w = header.index("wholeUpdate") - 1
    t, s, w = [], [], []
    for tick, vals in rows:
        if len(vals) > max(i_s, i_w):
            t.append(tick)
            s.append(vals[i_s] / 1e6)
            w.append(vals[i_w] / 1e6)
    return t, s, w


def traces(d):
    """{tick: [(type, a, b)]} des lignes [FO-TRACE] du journal du benchmark."""
    res = collections.defaultdict(list)
    f = ouvrir(d, "benchmark.log")
    if f is None:
        return res
    with f:
        for l in f:
            m = RE_TRACE.search(l)
            if m:
                res[int(m.group(1))].append((m.group(2), m.group(3), m.group(4)))
    return res


def postes(d):
    """Dernier bloc du profileur : (fenetre en ticks, [(poste, total ms, ms par tick)])."""
    f = ouvrir(d, "benchmark.log")
    if f is None:
        return 0, []
    fen, courant, dernier = 0, [], (0, [])
    with f:
        for l in f:
            m = RE_FENETRE.search(l)
            if m:
                if courant:
                    dernier = (fen, courant)
                fen, courant = int(m.group(1)), []
                continue
            m = RE_POSTE.match(l.split("remote.lua:60:", 1)[-1])
            if m and fen:
                courant.append((m.group(1), float(m.group(2)), float(m.group(3))))
    return (fen, courant) if courant else dernier


def analyser(d, facteur, min_ms, top):
    t, s, w = serie_script(d)
    print("== %s" % d)
    if not t:
        print("   pas de benchmark-stdout (ou colonnes absentes)")
        return
    med = mediane(s)
    p = pics(t, s, facteur, min_ms)
    moy = sum(s) / len(s)
    print("   %d ticks ; scriptUpdate : médiane %.3f ms, moyenne %.3f ms, max %.1f ms ; %d pic(s) (> max(%gx médiane, %g ms))"
          % (len(t), med, moy, max(s), len(p), facteur, min_ms))
    if p:
        surcout = sum(x - med for _, x in p)
        print("   surcoût total des pics : %.0f ms sur %d ticks = %.3f ms/tick en moyenne (%.0f %% de la moyenne script)"
              % (surcout, len(t), surcout / len(t), 100 * surcout / len(t) / moy if moy else 0))
        e, n, part = rythme([a for a, _ in p])
        print("   écart le plus fréquent entre pics : %d ticks (%d fois, %.0f %% des écarts)" % (e, n, 100 * part))
        al = alignement([a for a, _ in p])
        for P, r, part in al[:6]:
            print("   alignement : tick %% %d == %d pour %.0f %% des pics" % (P, r, 100 * part))
        tr = traces(d)
        cause = collections.Counter()
        cout = collections.Counter()
        for tick, x in p:
            ev = tr.get(tick) or []
            noms = sorted({"%s:%s" % (k, a) if k in ("ia3k", "act", "prospect") else k for k, a, b in ev}) or ["(aucun trace)"]
            for nom in noms:
                cause[nom] += 1
                cout[nom] += x - med
        print("   causes (traces posées sur le tick du pic) : " + " ; ".join(
            "%s x%d (%.0f ms)" % (k, c, cout[k]) for k, c in cause.most_common(top)))
        gros = sorted(p, key=lambda z: -z[1])[:5]
        print("   5 plus gros pics : " + ", ".join("t%d %.1f ms" % z for z in gros))
        if al:
            P = al[0][0]
            print("   ÉTALER sur %d ticks ramènerait le pic moyen de %.1f ms à %.2f ms/tick pendant %d ticks (travail total inchangé)"
                  % (P, sum(x - med for _, x in p) / len(p), sum(x - med for _, x in p) / len(p) / P, P))
    fen, ps = postes(d)
    if ps:
        lourds = sorted(ps, key=lambda z: -z[1])[:top]
        print("   profileur (fenêtre %d ticks), postes les plus lourds : " % fen + " ; ".join(
            "%s %.0f ms (%.3f/tick)" % z for z in lourds))


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("dossiers", nargs="+")
    ap.add_argument("--seuil-ms", type=float, default=PIC_MIN_MS)
    ap.add_argument("--facteur", type=float, default=PIC_FACTEUR)
    ap.add_argument("--top", type=int, default=12)
    a = ap.parse_args(argv)
    for d in a.dossiers:
        analyser(d, a.facteur, a.seuil_ms, a.top)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
