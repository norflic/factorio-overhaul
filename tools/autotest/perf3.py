# Lot PERF3 (5/11) : temps script par tick de la partie du DC, pics et répartition par portée du profileur.
#
#   PYTHONUTF8=1 py -3.9 -B tools/autotest/perf3.py <archive A> [--detail <archive B>] [--seuil 16] [--top 40]
#   PYTHONUTF8=1 py -3.9 -B tools/autotest/perf3.py --decisions <archive X> <archive Y> [--sans-profileur]
#
# A : banc de temps (scenario perf3-dc, profileur éteint, --seul) : benchmark-stdout.txt(.gz) (--benchmark-verbose all,
#     nanosecondes par tick) et benchmark.log(.gz) (étalon [FO-CALIB] au tick % 600, SOUSTRAIT du tick où il tourne : c'est
#     le mod de test, pas le mod). Les ticks % 3600 portent aussi le rapport du banc (control.lua du mod de test) : comptés
#     à part (« sans les minutes du banc »).
# B : banc de détail (scenario perf3-dc-detail) : lignes « [FO-PERF3-T] <tick> <portée><mère> Duration: <x>ms ... » (une par
#     tick, script/core/profiler.lua) ; temps PROPRE d'une portée = sa durée moins celle de ses filles du même tick.
#     Mêmes décisions que A (le profileur ne décide de rien) : un tick de A et le même tick de B font le même travail.
# --decisions : journal des décisions du mod (lignes [FO-*] sans horodatage ni fichier:ligne), hors lignes de temps et de
#     mesure ([FO-CALIB], [FO-PERF3-T], [FO-TRACE], profileur) ; --sans-profileur retire aussi les lignes que le mod
#     n'écrit que profileur allumé ([FO-IA3K], [FO-ATTACK], [FO-TD]) pour comparer un banc A à un banc B. Code 0 si égales.
# Aucune écriture, aucun jeu. Règles pures testées par tools/autotest/tests/test_perf3.py.
import argparse
import collections
import gzip
import os
import re
import sys

RE_CALIB = re.compile(r"\[FO-CALIB\] (\d+) Duration: ([0-9.]+)ms")
RE_T = re.compile(r"\[FO-PERF3-T\] (\d+)(.*)$")
RE_SCOPE = re.compile(r" (\S+)<(\S+) Duration: ([0-9.]+)ms")
RE_PREFIX = re.compile(r"^\s*[0-9.]+ (?:Script @__[^:]+:\d+: )?")
MESURE = ("[FO-CALIB]", "[FO-PERF3-T]", "[FO-TRACE]", "[FO-BENCH]", "Duration:", "Profiler (fenetre", "Profiler: desactive")
PROFILEUR_SEUL = ("[FO-IA3K]", "[FO-ATTACK]", "[FO-TD]")
SEUILS = (1.6, 4.0, 8.0, 16.0, 50.0, 100.0)


def opn(d, name):
    p = os.path.join(d, name)
    if os.path.exists(p):
        return open(p, encoding="utf-8", errors="replace")
    if os.path.exists(p + ".gz"):
        return gzip.open(p + ".gz", "rt", encoding="utf-8", errors="replace")
    raise SystemExit("absent : " + p + "(.gz)")


def pct(values, q):
    """Même centile que tools/autotest/analyze.py (rang arrondi)."""
    if not values:
        return 0.0
    s = sorted(values)
    i = min(len(s) - 1, int(q * (len(s) - 1) + 0.5))
    return s[i]


def parse_verbose(lines):
    """{tick: {colonne: ns}} des lignes « tN,... » sous l'en-tête de --benchmark-verbose all."""
    header, out = None, {}
    for line in lines:
        line = line.strip()
        if header is None:
            if line.startswith("tick,") and "scriptUpdate" in line:
                header = [c for c in line.split(",") if c != ""]
            continue
        if not line.startswith("t") or "," not in line:
            continue
        cells = [c for c in line.split(",") if c != ""]
        try:
            tick = int(cells[0][1:])
            vals = [int(c) for c in cells[1:]]
        except ValueError:
            continue
        out[tick] = dict(zip(header[1:], vals))
    return out


def parse_calib(lines):
    out = {}
    for line in lines:
        m = RE_CALIB.search(line)
        if m:
            out[int(m.group(1))] = float(m.group(2))
    return out


RE_DEBUT = re.compile(r"\[FO-PERF4\] debut tick (\d+)")


def aligner(rows, a_dir):
    """Lot PERF4 (banc sur une SAUVEGARDE donnée) : la partie commence au tick D (ligne « [FO-PERF4] debut tick D » du
    scénario). Si les lignes tN de --benchmark-verbose comptent depuis 0, elles sont décalées sur les ticks du jeu : phases
    (tick % 300...), étalon [FO-CALIB] et détail [FO-PERF3-T] sont en ticks du jeu (game.tick pendant la mise à jour).
    La ligne t0 est la mise à jour où game.tick vaut D (MESURÉ le 7/11 sur B0 : décalage D, écart moyen script - détail
    0,10 ms sur 1 243 ticks et 0 étalon sur 60 retiré d'une ligne qui ne le contient pas ; décalage D + 1, l'ancienne règle :
    35 ms et 59 sur 60). Contrôle à chaque lecture : controle_etalon."""
    if not rows:
        return rows
    with opn(a_dir, "benchmark.log") as f:
        debut = None
        for line in f:
            m = RE_DEBUT.search(line)
            if m:
                debut = int(m.group(1))
                break
    if debut is None or min(rows) >= debut:
        return rows
    shift = debut - min(rows)
    print("   (banc sur une sauvegarde : partie commencée au tick %d ; lignes du benchmark décalées de %+d)" % (debut, shift))
    return {t + shift: v for t, v in rows.items()}


def controle_etalon(rows, calib, seuil_ms=0.5):
    """(n, total) : ticks de l'étalon [FO-CALIB] où scriptUpdate (ns) moins l'étalon tombe sous -seuil_ms. Lignes bien
    alignées : 0 (l'étalon tourne dans la ligne de son tick) ; décalées d'un tick : presque tous (59 sur 60, PERF4, 7/11)."""
    n = tot = 0
    for t, c in calib.items():
        r = rows.get(t)
        if r is None:
            continue
        tot += 1
        if r.get("scriptUpdate", 0) / 1e6 - c < -seuil_ms:
            n += 1
    return n, tot


def dire_alignement(rows, calib):
    """Ligne du rapport sur l'alignement (controle_etalon) ; « ALIGNEMENT FAUX » si plus de la moitié des étalons tombent."""
    n, tot = controle_etalon(rows, calib)
    faux = tot > 0 and 2 * n > tot
    print("   contrôle de l'alignement : %d étalon(s) sur %d plus grands que le script de leur tick (attendu 0)%s" % (
        n, tot, " : ALIGNEMENT FAUX, ticks décalés" if faux else ""))
    return not faux


def script_ms(rows, calib):
    """{tick: ms} du script, étalon [FO-CALIB] soustrait au tick où il tourne (jamais sous 0)."""
    out = {}
    for t, r in rows.items():
        x = r.get("scriptUpdate", 0) / 1e6 - calib.get(t, 0.0)
        out[t] = x if x > 0 else 0.0
    return out


def normalise(sc, calib, ref):
    """{tick: ms} ramenés à l'étalon de référence `ref` (ms) : × ref / étalon de la fenêtre de 600 ticks du tick (mesure
    [FO-CALIB] au début de la fenêtre ; la plus proche avant, sinon après). La machine qui ralentit (autre programme sur
    les mêmes cœurs, F30) allonge l'étalon et le script dans le même rapport : approximation, les deux sont du Lua."""
    if not calib:
        return dict(sc)
    ks = sorted(calib)
    out = {}
    for t, x in sc.items():
        k = (t // 600) * 600
        c = calib.get(k)
        if c is None:
            c = calib[min(ks, key=lambda q: abs(q - t))]
        out[t] = x * ref / c if c > 0 else x
    return out


def stats(v):
    if not v:
        return {"n": 0, "moy": 0.0, "med": 0.0, "p99": 0.0, "p999": 0.0, "max": 0.0}
    return {"n": len(v), "moy": sum(v) / len(v), "med": pct(v, 0.5), "p99": pct(v, 0.99), "p999": pct(v, 0.999),
            "max": max(v)}


def comptes(v, seuils=SEUILS):
    return {s: sum(1 for x in v if x > s) for s in seuils}


def parse_detail(lines):
    """{tick: {portée: (mère, ms)}} des lignes [FO-PERF3-T]."""
    out = {}
    for line in lines:
        m = RE_T.search(line)
        if not m:
            continue
        tick = int(m.group(1))
        d = out.setdefault(tick, {})
        for name, mother, ms in RE_SCOPE.findall(m.group(2)):
            old = d.get(name)
            d[name] = (mother, float(ms) + (old[1] if old else 0.0))
    return out


def propre(scopes):
    """{portée: ms propres} : durée moins celle des filles (mère = portée) du même tick, jamais sous 0."""
    child = collections.defaultdict(float)
    for name, (mother, ms) in scopes.items():
        if mother != "-" and mother in scopes:
            child[mother] += ms
    return {n: max(0.0, ms - child[n]) for n, (_, ms) in scopes.items()}


def premier_niveau(scopes):
    """Somme des portées de premier niveau (mère « - ») : le temps du mod dans le tick."""
    return sum(ms for (mother, ms) in scopes.values() if mother == "-")


def periode(ticks, max_ecart=7200):
    """(écart le plus fréquent entre occurrences voisines, part de cet écart) ; (0, 0.0) si moins de 3 occurrences."""
    ecarts = [b - a for a, b in zip(ticks, ticks[1:]) if 0 < b - a <= max_ecart]
    if len(ecarts) < 2:
        return 0, 0.0
    e, n = collections.Counter(ecarts).most_common(1)[0]
    return e, n / len(ecarts)


def decisions(lines, sans_profileur=False):
    """Lignes [FO-*] du journal sans horodatage ni « Script @fichier:ligne: », hors lignes de mesure."""
    out = []
    for line in lines:
        if "[FO-" not in line:
            continue
        s = RE_PREFIX.sub("", line.rstrip("\n"))
        if any(k in s for k in MESURE):
            continue
        if sans_profileur and any(k in s for k in PROFILEUR_SEUL):
            continue
        out.append(s)
    return out


def fmt_stats(s):
    return "moyenne %.3f ms, médiane %.3f, p99 %.2f, p99,9 %.2f, max %.1f (%d ticks)" % (
        s["moy"], s["med"], s["p99"], s["p999"], s["max"], s["n"])


def rapport(a_dir, b_dir, seuil, top, ref=None):
    with opn(a_dir, "benchmark-stdout.txt") as f:
        rows = parse_verbose(f)
    rows = aligner(rows, a_dir)
    with opn(a_dir, "benchmark.log") as f:
        calib = parse_calib(f)
    sc = script_ms(rows, calib)
    ticks = sorted(sc)
    print("== A : %s" % a_dir)
    dire_alignement(rows, calib)
    cv = list(calib.values())
    print("   ticks %d (de %d à %d) ; étalon [FO-CALIB] : %d mesures, médiane %.2f ms, min %.2f, max %.2f (soustrait)" % (
        len(ticks), ticks[0], ticks[-1], len(calib), pct(cv, 0.5), min(cv) if cv else 0, max(cv) if cv else 0))
    if ref:
        sc = normalise(sc, calib, ref)
        print("   TEMPS RAMENÉS À L'ÉTALON %.2f ms (× %.2f / étalon de la fenêtre de 600 ticks)" % (ref, ref))
    whole = {t: rows[t].get("wholeUpdate", 0) / 1e6 - calib.get(t, 0.0) for t in ticks}
    ent = {t: rows[t].get("entityUpdate", 0) / 1e6 for t in ticks}
    gc = {t: rows[t].get("luaGarbageIncremental", 0) / 1e6 for t in ticks}
    pf = {t: rows[t].get("pathFinder", 0) / 1e6 for t in ticks}
    t0 = ticks[0]  # lot PERF4 : 0 pour une carte créée, le tick de la sauvegarde sinon
    sans0 = [t for t in ticks if t - t0 >= 60]  # les premiers ticks (lancement de la guerre, chargement) à part
    print("   ticks 0 à 59 (lancement) : script %s" % ", ".join("t%d=%.0f" % (t, sc[t]) for t in ticks[:60] if sc[t] > 16))
    minute_banc = [t for t in sans0 if t % 3600 == 0]
    hors_banc = [t for t in sans0 if t % 3600 != 0]
    for label, sel in (("script, ticks 60 à la fin", sans0), ("script, sans les minutes du banc (tick % 3600)", hors_banc)):
        v = [sc[t] for t in sel]
        print("   %s : %s" % (label, fmt_stats(stats(v))))
        c = comptes(v)
        print("      ticks au-dessus de : " + ", ".join("%g ms %d" % (s, c[s]) for s in SEUILS))
    v = [sc[t] for t in minute_banc]
    print("   minutes du banc (tick % 3600, rapport du mod de test) : " + fmt_stats(stats(v)))
    for label, d in (("wholeUpdate (étalon soustrait)", whole), ("entityUpdate", ent), ("luaGarbageIncremental", gc),
                     ("pathFinder", pf)):
        print("   %s : %s" % (label, fmt_stats(stats([d[t] for t in sans0]))))
    print("   par tranche de 10 min (script, sans les minutes du banc) :")
    for k in range(0, 6):
        sel = [sc[t] for t in hors_banc if k * 36000 <= t - t0 < (k + 1) * 36000]
        if sel:
            s, c = stats(sel), comptes(sel)
            print("      %2d-%2d min : moy %.3f p99 %.2f max %.1f | >16 ms %d, >8 ms %d, >4 ms %d | whole moy %.3f" % (
                k * 10, k * 10 + 10, s["moy"], s["p99"], s["max"], c[16.0], c[8.0], c[4.0],
                sum(whole[t] for t in hors_banc if k * 36000 <= t - t0 < (k + 1) * 36000) / len(sel)))
    pics = [t for t in hors_banc if sc[t] > 4.0]
    print("   phases des ticks > 4 ms (%d) : " % len(pics) + " ; ".join(
        "mod %d : %s" % (p, ", ".join("%d×%d" % (r, n) for r, n in collections.Counter(t % p for t in pics).most_common(4)))
        for p in (30, 60, 300, 600)))
    gros = sorted((t for t in sans0 if sc[t] > seuil), key=lambda t: -sc[t])
    print("   pics > %g ms : %d" % (seuil, len(gros)))

    det = None
    if b_dir:
        with opn(b_dir, "benchmark.log") as f:
            det = parse_detail(f)
        print("== B (détail) : %s : %d ticks détaillés" % (b_dir, len(det)))
        tot_self = collections.defaultdict(float)
        tot_incl = collections.defaultdict(float)
        occ = collections.defaultdict(list)
        lourds = collections.defaultdict(list)
        n4 = collections.Counter()
        n16 = collections.Counter()
        mx = collections.defaultdict(float)
        mothers = {}
        for t in sorted(det):
            if t < t0 + 60:
                continue
            d = det[t]
            pr = propre(d)
            for name, (mother, ms) in d.items():
                mothers.setdefault(name, mother)
                tot_incl[name] += ms
                tot_self[name] += pr[name]
                occ[name].append(t)
                if ms > 2.0:
                    lourds[name].append(t)
                if ms > 4.0:
                    n4[name] += 1
                if ms > 16.0:
                    n16[name] += 1
                if ms > mx[name]:
                    mx[name] = ms
        nt = max(1, len([t for t in ticks if t - t0 >= 60]))
        print("   portées par temps PROPRE (ms par tick de jeu = total / %d ticks) :" % nt)
        print("   %-34s %-22s %9s %9s %9s %7s %7s %8s  %s" % ("portée", "mère", "propre/t", "incl/t", "max ms", ">4ms", ">16ms",
                                                         "passages", "période des passages > 2 ms"))
        for name in sorted(tot_self, key=lambda n: -tot_self[n])[:top]:
            e, part = periode(lourds[name])
            print("   %-34s %-22s %9.4f %9.4f %9.1f %7d %7d %8d  %s" % (
                name[:34], mothers[name][:22], tot_self[name] / nt, tot_incl[name] / nt, mx[name], n4[name], n16[name],
                len(occ[name]), ("%d ticks (%.0f %%)" % (e, 100 * part)) if e else "-"))
        # Attribution : qui fait les pics de A (même tick dans B).
        for lim in (4.0, seuil):
            sel = [t for t in hors_banc if sc[t] > lim and t in det]
            acc = collections.defaultdict(float)
            for t in sel:
                for name, ms in propre(det[t]).items():
                    acc[name] += ms
            tot = sum(acc.values()) or 1.0
            print("   ticks de A > %g ms (%d, dont détaillés dans B) : temps propre de B par portée :" % (lim, len(sel)))
            for name in sorted(acc, key=lambda n: -acc[n])[:15]:
                print("      %-40s %9.1f ms  %5.1f %%" % (name[:40], acc[name], 100 * acc[name] / tot))
        accord = [(sc[t], premier_niveau(det[t])) for t in gros if t in det]
        if accord:
            r = sum(1 for a, b in accord if b > 0.5 * a)
            print("   accord A/B sur les pics > %g ms : %d sur %d ont dans B au moins la moitié du temps de A" % (
                seuil, r, len(accord)))
    print("   %d plus gros pics de A (tick, minute, script ms, whole ms%s) :" % (min(top, len(gros)),
                                                                              ", portées propres de B" if det else ""))
    for t in gros[:top]:
        extra = ""
        if det and t in det:
            pr = propre(det[t])
            best = sorted(pr, key=lambda n: -pr[n])[:5]
            extra = " | B %.1f : " % premier_niveau(det[t]) + ", ".join("%s %.1f" % (n, pr[n]) for n in best)
        print("      t%-7d %5.1f min  %7.1f  %7.1f%s" % (t, t / 3600, sc[t], whole[t], extra))


def compare(x_dir, y_dir, sans_profileur):
    with opn(x_dir, "benchmark.log") as f:
        x = decisions(f, sans_profileur)
    with opn(y_dir, "benchmark.log") as f:
        y = decisions(f, sans_profileur)
    n = min(len(x), len(y))
    first = next((i for i in range(n) if x[i] != y[i]), None)
    if first is None and len(x) == len(y):
        print("DECISIONS EGALES : %d lignes" % len(x))
        return 0
    if first is None:
        first = n
    print("DECISIONS DIFFERENTES : %d contre %d lignes ; première différence à la ligne %d :" % (len(x), len(y), first + 1))
    print("   X : " + (x[first] if first < len(x) else "<fin>"))
    print("   Y : " + (y[first] if first < len(y) else "<fin>"))
    return 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("archive", nargs="?")
    ap.add_argument("--detail")
    ap.add_argument("--seuil", type=float, default=16.0)
    ap.add_argument("--top", type=int, default=40)
    ap.add_argument("--decisions", nargs=2)
    ap.add_argument("--sans-profileur", action="store_true")
    ap.add_argument("--etalon", type=float, help="ramener les temps du script à cet étalon [FO-CALIB] (ms), ex. 2.13")
    a = ap.parse_args()
    if a.decisions:
        sys.exit(compare(a.decisions[0], a.decisions[1], a.sans_profileur))
    if not a.archive:
        ap.error("archive A requise")
    rapport(a.archive, a.detail, a.seuil, a.top, a.etalon)


if __name__ == "__main__":
    main()
