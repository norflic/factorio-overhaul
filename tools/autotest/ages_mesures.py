#!/usr/bin/env python3
"""Lot AGES : lecture du journal d'une partie `dc-croissance` (ou d'un journal du DC) : l'ÂGE de chaque faction.

Âge = niveau du centre de commandement (lignes `[FO-CAPITAL-CENTRE] ... centre niveau N` et `[FO-CAPITAL] ... centre monte au
niveau N`). Rend, par faction : âge à 60, 120 et 180 minutes (et aux minutes données par --a), première montée du
centre, dernière cause du centre avant la première montée (ou à la fin), causes d'attente comptées ([FO-CAPITAL-ATTENTE]),
paliers de recherche, machines (assembleurs + fours + foreuses + labos, lignes [FO-EVOL]) et fer produit cumulé.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/ages_mesures.py <journal [.gz]> [<journal> ...] [--a 60,120,180]
"""
import argparse
import gzip
import re
import sys
from collections import Counter, defaultdict

RE_CENTRE = re.compile(r"\[FO-CAPITAL-CENTRE\] (\w+) : (.*?) ; centre niveau (\d+)(?:, cible '([^']*)')? a ([\d.]+) min")
RE_MONTE = re.compile(r"\[FO-CAPITAL\] (\w+) : centre monte au niveau (\d+) \(epoque \d+ ouverte\) a ([\d.]+) min")
RE_ATTENTE = re.compile(r"\[FO-CAPITAL-ATTENTE\] (\w+) : '([^']*)' decide mais non paye, cause ([\w-]+)(?: \(([^)]*)\))? a ([\d.]+) min")
RE_TECH = re.compile(r"\[FO-TEAM\] (\w+) : recherche niveau (\d+) payee en packs a ([\d.]+) min")
RE_EVOL = re.compile(r"\[FO-EVOL\] minute (\d+) \| (\w+) \| n=(\d+) .*?\| (assembling-machine=.*?) \| produit (.*)$")
RE_PAYEE = re.compile(r"\[FO-CAPITAL\] (\w+) : amelioration payee '([a-z]+)[:>]")
RE_ERR = re.compile(r"(Error while running event|Script Error|stack traceback)")


def lire(path):
    op = gzip.open if path.endswith(".gz") else open
    with op(path, "rt", encoding="utf-8", errors="replace") as f:
        for ligne in f:
            yield ligne.rstrip("\n")


def kv(texte):
    out = {}
    for m in re.finditer(r"([\w-]+)=(\d+)", texte):
        out[m.group(1)] = int(m.group(2))
    return out


def analyser(path):
    niv = defaultdict(list)      # faction -> [(minute, niveau)]
    cause = {}                    # faction -> (minute, texte)
    montee = {}                   # faction -> (minute, niveau) première montée
    cause_avant = {}              # faction -> cause avant la première montée
    attente = defaultdict(Counter)
    tech = defaultdict(list)
    evol = defaultdict(dict)      # faction -> minute -> (machines, fer, cuivre, labs)
    payees = defaultdict(Counter)
    erreurs = 0
    for l in lire(path):
        if RE_ERR.search(l):
            erreurs += 1
        m = RE_CENTRE.search(l)
        if m:
            f, txt, n, cible, mn = m.group(1), m.group(2), int(m.group(3)), m.group(4), float(m.group(5))
            niv[f].append((mn, n))
            cause[f] = (mn, txt)
            if f not in montee:
                cause_avant[f] = (mn, txt)
            continue
        m = RE_MONTE.search(l)
        if m:
            f, n, mn = m.group(1), int(m.group(2)), float(m.group(3))
            niv[f].append((mn, n))
            montee.setdefault(f, (mn, n))
            continue
        m = RE_ATTENTE.search(l)
        if m:
            attente[m.group(1)][m.group(3)] += 1
            continue
        m = RE_TECH.search(l)
        if m:
            tech[m.group(1)].append((float(m.group(3)), int(m.group(2))))
            continue
        m = RE_PAYEE.search(l)
        if m:
            payees[m.group(1)][m.group(2)] += 1
            continue
        m = RE_EVOL.search(l)
        if m:
            mn, f = int(m.group(1)), m.group(2)
            a = kv(m.group(4))
            p = kv(m.group(5))
            mach = sum(a.get(k, 0) for k in ("assembling-machine", "furnace", "mining-drill", "lab"))
            evol[f][mn] = (mach, p.get("iron-plate", 0), p.get("copper-plate", 0), a.get("lab", 0))
    return dict(niv=niv, cause=cause, montee=montee, cause_avant=cause_avant, attente=attente, tech=tech, evol=evol,
                payees=payees, erreurs=erreurs)


def age_a(liste, t):
    n = 1
    for mn, lvl in sorted(liste):
        if mn <= t:
            n = max(n, lvl)
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("journaux", nargs="+")
    ap.add_argument("--a", default="60,120,180")
    a = ap.parse_args()
    temps = [int(x) for x in a.a.split(",")]
    for path in a.journaux:
        r = analyser(path)
        print("== " + path)
        print("erreurs Lua : %d" % r["erreurs"])
        for f in sorted(set(r["niv"]) | set(r["evol"])):
            if f == "player":
                continue
            ages = " ".join("%dmin:%d" % (t, age_a(r["niv"][f], t)) for t in temps)
            mt = r["montee"].get(f)
            print("%-8s age %s | premiere montee %s | derniere cause %s" % (
                f, ages, ("%.1f min -> %d" % mt) if mt else "AUCUNE",
                ("%s a %.1f min" % (r["cause"][f][1], r["cause"][f][0])) if f in r["cause"] else "-"))
            if f in r["cause_avant"] and mt:
                print("         cause avant la montee : %s a %.1f min" % (r["cause_avant"][f][1], r["cause_avant"][f][0]))
            print("         attentes : %s | payees : %s" % (dict(r["attente"][f]), dict(r["payees"][f])))
            tp = sorted(r["tech"][f])
            print("         recherche : %s" % (" ".join("p%d@%.0f" % (n, mn) for mn, n in tp) or "-"))
            ev = r["evol"][f]
            lignes = []
            for t in temps:
                k = t if t in ev else (max([m for m in ev if m <= t]) if [m for m in ev if m <= t] else None)
                if k is not None:
                    mach, fer, cu, labs = ev[k]
                    lignes.append("%dmin machines=%d fer=%d cuivre=%d labos=%d" % (k, mach, fer, cu, labs))
            print("         " + " | ".join(lignes))


if __name__ == "__main__":
    sys.exit(main())
