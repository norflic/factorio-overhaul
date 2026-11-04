# -*- coding: utf-8 -*-
"""Lot DEPENSES2 (4/11) : lecture de la sonde [FO-DEPENSES-DIAG*] (scenarios/depenses_diag_common.lua) et des journaux du mod.

Par équipe (factions et votre équipe), aux minutes demandées :
  - coffres : total et familles (plaques, intermédiaires, packs, munitions, tourelles, matières, bâtiments) ; DORMANT d'une famille ou
    d'un objet = le plus bas des 3 relevés [t-10, t-5, t] (resté au moins 10 min) ;
  - recherche : laboratoires (en marche, sans pack), packs dedans, courante, ingrédients, technologies faites (et faites en 10 min) ;
  - armement : tourelles, à sec, munitions dedans, soldats, âge ;
  - pourquoi (journaux du mod, 10 dernières minutes) : refus de la capitalisation (labos, packs, techno, chaînes) par raison, sommet
    de la pile, besoin évalué ([FO-RESERVE] : couvert, défense, stock libre MU, dépense), munitions ([FO-MUNITIONS] : par tourelle,
    cible), tourelles voulues ([FO-DEFENSE]).
Usage : py -3.9 -B tools/autotest/depenses_diag.py <archive> [...] [--minutes 30,45,59]
"""
import gzip
import os
import re
import sys

RX_TAG = re.compile(r"\[FO-DEPENSES-DIAG(?:-DC)?\] ([CLPA]) min=(\d+) eq=(\S+) (.*)")
RX_MIN_LOG = re.compile(r"\] (\S+) minute (\d+)")
RX_CAPI = re.compile(r"\[FO-CAPI\] (\S+) minute (\d+) \|.*?budget=(-?[0-9.]+)/(-?[0-9.]+) .*? labos=(\d+) .*?ordres=\[([^\]]*)\].*?refus=\[(.*?)\] (?:repli|reserve|\| envoyes)")
RX_RSV = re.compile(r"\[FO-RESERVE\] (\S+) minute (\d+) \| besoin (COUVERT|NON couvert) : prevu (\d+), defense (\d+), reconstruction (\d+), recrues (\d+).*?stock libre (-?[0-9.]+) MU investissable \(part du stock au budget -?[0-9.]+, depense (-?[0-9.]+), (\d+) ordre")
RX_PILE = re.compile(r"\[FO-PILE\] (\S+) : sommet (\S+), ameliorer (\S+)")
RX_MUN = re.compile(r"\[FO-MUNITIONS\] (\S+) minute ([0-9.]+) \| tourelles (\d+), chargeurs (\d+) \(([0-9.]+) par tourelle\).*?coffre (\d+) chargeur.*?cible (\d+) par tourelle")
RX_DEF = re.compile(r"\[FO-DEFENSE\] (\S+) a ([0-9.]+) min : fer (-?\d+), cuivre (-?\d+), tourelle fabricable (\S+), tourelles du QG (\d+) \(voulues (\d+)\), front pose (\d+) ; postes \[([^\]]*)\]")
RX_REF = re.compile(r"(\w+):([^ ,(]+) \(([^()]*(?:\([^()]*\)[^()]*)*)\)")


def open_log(path):
    if os.path.isdir(path):
        for name in ("benchmark.log.gz", "benchmark.log"):
            p = os.path.join(path, name)
            if os.path.exists(p):
                path = p
                break
    if path.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8", errors="replace"), path
    return open(path, "r", encoding="utf-8", errors="replace"), path


def kvs(text):
    out = {}
    for part in text.split():
        if "=" in part:
            a, b = part.split("=", 1)
            try:
                out[a] = float(b)
            except ValueError:
                out[a] = b
    return out


def norm_reason(r):
    r = re.sub(r"-?[0-9]+(\.[0-9]+)?", "N", r)
    return r[:70]


def parse(path):
    fh, real = open_log(path)
    D = {}  # (eq, min, kind) -> dict
    capi, rsv, pile, mun, dfn = [], [], [], [], []
    last_min = {}
    with fh:
        for line in fh:
            if "[FO-" not in line:
                continue
            m = RX_TAG.search(line)
            if m:
                kind, mi, eq, rest = m.group(1), int(m.group(2)), m.group(3), m.group(4)
                rec = {"raw": rest}
                if kind == "C":
                    head, _, top = rest.partition("| top ")
                    rec.update(kvs(head))
                    rec["top"] = kvs(top)
                else:
                    rec.update(kvs(rest.replace("{", " ").replace("}", " ")))
                D[(eq, mi, kind)] = rec
                continue
            m = RX_MIN_LOG.search(line)
            if m:
                last_min[m.group(1)] = int(m.group(2))
            m = RX_CAPI.search(line)
            if m:
                refs = {}
                for kind, item, why in RX_REF.findall(m.group(7)):
                    k = kind + ":" + norm_reason(why)
                    refs[k] = refs.get(k, 0) + 1
                capi.append((m.group(1), int(m.group(2)), float(m.group(3)), float(m.group(4)), int(m.group(5)), m.group(6), refs))
                continue
            m = RX_RSV.search(line)
            if m:
                rsv.append((m.group(1), int(m.group(2)), m.group(3), int(m.group(5)), float(m.group(8)), float(m.group(9))))
                continue
            m = RX_PILE.search(line)
            if m:
                pile.append((m.group(1), last_min.get(m.group(1), 0), m.group(2), m.group(3)))
                continue
            m = RX_MUN.search(line)
            if m:
                mun.append((m.group(1), float(m.group(2)), int(m.group(3)), int(m.group(4)), float(m.group(5)), int(m.group(6)), int(m.group(7))))
                continue
            m = RX_DEF.search(line)
            if m:
                dfn.append((m.group(1), float(m.group(2)), int(m.group(6)), int(m.group(7)), int(m.group(8)), m.group(9)))
    return D, capi, rsv, pile, mun, dfn, real


FAMS = ("plaques", "intermediaires", "packs", "munitions", "tourelles", "matieres", "batiments")


def g(rec, k):
    v = rec.get(k, 0) if rec else 0
    return v if isinstance(v, float) else 0.0


def window(D, eq, t):
    ms = sorted(k[1] for k in D if k[0] == eq and k[2] == "C" and t - 10 <= k[1] <= t)
    if len(ms) < 2 or ms[0] > t - 9 or ms[-1] != t:
        return None
    return [D[(eq, x, "C")] for x in ms]


def dormant_fam(D, eq, t, fam):
    recs = window(D, eq, t)
    return min(g(r, fam) for r in recs) if recs else None


def dormant_items(D, eq, t):
    recs = window(D, eq, t)
    if not recs:
        return {}
    out = {}
    for item, n in recs[-1]["top"].items():
        if all(isinstance(r["top"].get(item), float) for r in recs):
            out[item] = min(r["top"][item] for r in recs)
    return out


def main(argv):
    paths, mins = [], [30, 45, 59]
    i = 0
    while i < len(argv):
        if argv[i] == "--minutes":
            mins = [int(x) for x in argv[i + 1].split(",")]
            i += 2
            continue
        paths.append(argv[i])
        i += 1
    for p in paths:
        D, capi, rsv, pile, mun, dfn, real = parse(p)
        eqs = sorted(set(k[0] for k in D))
        print("=== %s" % real)
        for eq in eqs:
            for t in mins:
                tt = t if (eq, t, "C") in D else (60 if (eq, 60, "C") in D and t == 59 else t)
                C, L, A = D.get((eq, tt, "C")), D.get((eq, tt, "L")), D.get((eq, tt, "A"))
                if not C:
                    continue
                dor = {f: dormant_fam(D, eq, tt, f) for f in FAMS}
                di = dormant_items(D, eq, tt)
                Lp = D.get((eq, tt - 10, "L")) or D.get((eq, tt - 9, "L"))
                done10 = (g(L, "faites") - g(Lp, "faites")) if (L and Lp) else None
                print("%-8s %2d | coffre %5d | dort(10') %s | objets qui dorment %s" % (
                    eq, tt, g(C, "total"),
                    " ".join("%s=%s" % (f[:5], "-" if dor[f] is None else "%d" % dor[f]) for f in FAMS),
                    " ".join("%s=%d" % (k, v) for k, v in sorted(di.items(), key=lambda kv: -kv[1])[:8])))
                if L:
                    print("           recherche : labos %d (marche %d, sans pack %d, packs dedans %d) courante %s %.2f [%s] faites %d (+%s en 10 min)" % (
                        g(L, "labos"), g(L, "marche"), g(L, "sans_pack"), g(L, "packs_dedans"), L.get("courante"), g(L, "avancement"),
                        L.get("ingredients"), g(L, "faites"), "-" if done10 is None else "%d" % done10))
                if A:
                    print("           armement : tourelles %d (a sec %d, munitions dedans %d) soldats %d ouvriers %d age %d" % (
                        g(A, "tourelles"), g(A, "a_sec"), g(A, "munitions_dedans"), g(A, "soldats"), g(A, "ouvriers"), g(A, "age")))
                key = "votre equipe" if eq == "player" else eq
                cp = [c for c in capi if c[0] in (eq, key) and tt - 10 < c[1] <= tt]
                if cp:
                    refs = {}
                    for c in cp:
                        for k, n in c[6].items():
                            if k.split(":")[0] in ("labos", "packs", "techno", "chaine", "equiper"):
                                refs[k] = refs.get(k, 0) + n
                    top = sorted(refs.items(), key=lambda kv: -kv[1])[:5]
                    print("           capi (10 min) : budget depense %.0f / dispo %.0f, labos %d, ordres non vides %d/%d ; refus %s" % (
                        sum(c[2] for c in cp), cp[-1][3], cp[-1][4], sum(1 for c in cp if c[5].strip()), len(cp),
                        " ; ".join("%s x%d" % kv for kv in top)))
                rs = [r for r in rsv if r[0] in (eq, key) and tt - 10 < r[1] <= tt]
                if rs:
                    print("           reserve : besoin %s (defense %d) ; stock libre %.0f MU ; depense %.0f MU en 10 min" % (
                        rs[-1][2], rs[-1][3], rs[-1][4], sum(r[5] for r in rs)))
                pl = [x for x in pile if x[0] in (eq, key) and tt - 10 < x[1] <= tt]
                if pl:
                    som = {}
                    for x in pl:
                        k = x[2] + "/ameliorer " + x[3]
                        som[k] = som.get(k, 0) + 1
                    print("           pile (10 min) : %s" % ", ".join("%s x%d" % kv for kv in sorted(som.items(), key=lambda kv: -kv[1])[:3]))
                mu = [x for x in mun if x[0] in (eq, key) and tt - 10 < x[1] <= tt]
                if mu:
                    x = mu[-1]
                    print("           munitions : %d tourelles, %.1f chargeurs par tourelle (cible %d), %d au coffre" % (x[2], x[4], x[6], x[5]))
                df = [x for x in dfn if x[0] in (eq, key) and tt - 10 < x[1] <= tt]
                if df:
                    x = df[-1]
                    print("           defense : tourelles du QG %d (voulues %d), front pose %d ; postes [%s]" % (x[2], x[3], x[4], x[5][:160]))
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
