# -*- coding: utf-8 -*-
"""Lot RESEAU-VIVANT : jugement des critères C1, C5, C6 (et lecture de C2 à C4) contre les témoins, exactement comme ils sont
écrits dans fo-logs/2026-10-29_NUIT/RESEAU/CRITERES.md (écrits AVANT les mesures de la branche corrigée).

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/reseau_juge.py <dossier RESEAU> [--base <dossier 2026-10-28_MESURES>]
            [--graines 20261020,123456789,271828182,1618033988] [--reglage 314159265] [--lot lot] [--temoin temoin]
Archives lues : <dossier>/<lot>-<graine> (code du lot, etape1-guide), <dossier>/<temoin>-<graine> (relevé à vide sans le code),
<base>/base-<graine> (base commune, main 72ab9ed, lignes elec seulement). Une archive absente est dite, jamais comptée.

C1 : (foreuses électriques + bras électriques + assembleurs + labos) posés MOINS alimentés, minute 60 ([FO-FONCTION] elec) ;
     somme 4 graines x équipes <= 50 % de celle de la base ET aucune équipe pire que sa base de plus de 5.
C5 : paires de poteaux < 2 tuiles (reseau) aux minutes 40 et 60 : <= 2 par équipe ; poteaux par consommateur alimenté,
     médiane (graines x équipes) à 60 min <= celle du témoin.
C6 : tourelles armées et corps par équipe à 10, 40 et 60 min >= témoin x 0,85 (bruit non mesuré : le seuil est écrit ici, pas
     tiré de la lecture) ; 0 pose (poteau, pièce de centrale) avec un ennemi à moins de 28 tuiles ; réouvertures d'un même projet <= 5.
"""
import argparse
import collections
import gzip
import os
import re
import statistics
import sys

PE = re.compile(r"\[FO-FONCTION\] elec minute (\d+) \| (\w+) \| (.*)$")
PR = re.compile(r"\[FO-FONCTION\] reseau minute (\d+) \| (\w+) \| (.*)$")
PT = re.compile(r"\[FO-FONCTION\] tourelles minute (\d+) \| (\w+) \| (.*)$")
PC = re.compile(r"\[FO-FONCTION\] corps minute (\d+) \| (\w+) \| (.*)$")
POSE = re.compile(r"\[FO-POLE\] (\w+) : projet (\d+) .* (pose|deja) en .*ennemi a 28 tuiles : (OUI|non)")
RES = re.compile(r"\[FO-RESEAU\] (\w+) : (.*) a ([\d.]+) min")
EVT = re.compile(r"\[FO-RESEAU-DETRUIT\] (.*)$")
CLASSES = ("foreuse_elec", "bras_elec", "assembleur", "labo")


def kvs(s):
    return dict(x.split("=", 1) for x in s.split() if "=" in x)


def lines(d):
    for name in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(d, name)
        if os.path.exists(p):
            op = gzip.open if name.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as f:
                for line in f:
                    yield line
            return


def read(d):
    R = dict(elec={}, reseau={}, tour={}, corps={}, poses=0, feu=0, decisions=collections.Counter(), dec=[], evt=[], ok=False)
    for line in lines(d):
        R["ok"] = True
        for rx, key in ((PE, "elec"), (PR, "reseau"), (PT, "tour"), (PC, "corps")):
            m = rx.search(line)
            if m:
                R[key][(int(m.group(1)), m.group(2))] = kvs(m.group(3))
                break
        else:
            m = POSE.search(line)
            if m:
                R["poses"] += 1
                R["feu"] += m.group(4) == "OUI"
                continue
            m = RES.search(line)
            if m:
                txt = m.group(2)
                if not txt.startswith("synthese"):
                    R["decisions"][txt.split(":")[0].split(" ")[0]] += 1
                    if len(R["dec"]) < 60:
                        R["dec"].append("%s %s min : %s" % (m.group(1), m.group(3), txt))
                continue
            m = EVT.search(line)
            if m:
                R["evt"].append(m.group(1))
    return R


def deficit(R, minute=60):
    out = {}
    for (m, team), kv in R["elec"].items():
        if m != minute:
            continue
        try:
            pose = sum(int(kv[c + "_pose"]) for c in CLASSES)
            al = sum(int(kv[c + "_alimentes"]) for c in CLASSES)
        except KeyError:
            continue
        out[team] = (pose - al, pose)
    return out


def med(v):
    return statistics.median(v) if v else float("nan")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--base", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "..", "..", "fo-logs",
                                                  "2026-10-28_MESURES"))
    ap.add_argument("--graines", default="20261020,123456789,271828182,1618033988")
    ap.add_argument("--reglage", default="314159265")
    ap.add_argument("--lot", default="lot")
    ap.add_argument("--temoin", default="temoin")
    a = ap.parse_args()
    base_root = os.path.abspath(a.base)
    seeds = a.graines.split(",") + ([a.reglage] if a.reglage else [])
    L, T, B = {}, {}, {}
    for s in seeds:
        for root, pre, dst in ((a.root, a.lot, L), (a.root, a.temoin, T), (base_root, "base", B)):
            d = os.path.join(root, "%s-%s" % (pre, s))
            if os.path.isdir(d):
                r = read(d)
                if r["ok"]:
                    dst[s] = r
    judged = a.graines.split(",")
    print("== C1 : consommateurs electriques poses MOINS alimentes a 60 min (foreuses elec + bras elec + assembleurs + labos)")
    tot = collections.Counter()
    worse = []
    for s in seeds:
        tag = "" if s in judged else " (reglage)"
        if s not in L or s not in B:
            print("  %s%s : manque (lot=%s base=%s)" % (s, tag, s in L, s in B))
            continue
        dl, db, dt = deficit(L[s]), deficit(B[s]), deficit(T[s]) if s in T else {}
        row = []
        for team in sorted(set(dl) | set(db)):
            l, b, t = dl.get(team), db.get(team), dt.get(team)
            row.append("%s %s/%s/%s" % (team, l[0] if l else "-", b[0] if b else "-", t[0] if t else "-"))
            if s in judged and l and b:
                tot["lot"] += l[0]
                tot["base"] += b[0]
                if l[0] > b[0] + 5:
                    worse.append((s, team, l[0], b[0]))
        print("  %s%s : lot/base/temoin %s" % (s, tag, " ; ".join(row)))
    if tot["base"] or tot["lot"]:
        rap = tot["lot"] / max(1, tot["base"])
        print("  JUGEMENT C1 (4 graines) : lot %d / base %d -> rapport %.2f (seuil 0.50) ; equipes pires que la base de plus de 5 : %s -> %s"
              % (tot["lot"], tot["base"], rap, worse or "aucune", "TENU" if rap <= 0.5 and not worse else "NON TENU"))
    print("== C5 : paires de poteaux < 2 tuiles (seuil <= 2 par equipe) ; poteaux par consommateur alimente")
    bad5, pa_l, pa_t = [], [], []
    for s in seeds:
        if s not in L:
            continue
        for m in (40, 60):
            for team in sorted(t for (mm, t) in L[s]["reseau"] if mm == m):
                kv = L[s]["reseau"][(m, team)]
                p2 = int(kv.get("paires_lt2", 0))
                tkv = T.get(s, {}).get("reseau", {}).get((m, team))
                print("  %s min %d %-8s paires_lt2 lot %d / temoin %s ; poteaux %s ; alimentes %s/%s ; poteaux_par_alimente lot %s / temoin %s"
                      % (s, m, team, p2, tkv["paires_lt2"] if tkv else "-", kv.get("poteaux"), kv.get("alimentes"), kv.get("conso"),
                         kv.get("poteaux_par_alimente"), tkv["poteaux_par_alimente"] if tkv else "-"))
                if s in judged and p2 > 2:
                    bad5.append((s, team, m, p2))
                if m == 60 and s in judged:
                    pa_l.append(float(kv.get("poteaux_par_alimente", 0)))
                    if tkv:
                        pa_t.append(float(tkv.get("poteaux_par_alimente", 0)))
    print("  JUGEMENT C5 : equipes a plus de 2 paires : %s ; poteaux_par_alimente mediane lot %.2f / temoin %.2f -> %s"
          % (bad5 or "aucune", med(pa_l), med(pa_t), "TENU" if not bad5 and med(pa_l) <= med(pa_t) else "NON TENU"))
    print("== C6 : tourelles armees et corps (lot / temoin), 10, 40 et 60 min ; poses sous le feu ; decisions")
    ratios = []
    for s in seeds:
        if s not in L:
            continue
        for m in (10, 40, 60):
            for team in sorted(t for (mm, t) in L[s]["tour"] if mm == m and t != "player"):
                l, t = L[s]["tour"].get((m, team)), T.get(s, {}).get("tour", {}).get((m, team))
                lc, tc = L[s]["corps"].get((m, team)), T.get(s, {}).get("corps", {}).get((m, team))
                if l and t:
                    ratios.append((s, team, m, int(l.get("armees", 0)), int(t.get("armees", 0)),
                                   int(lc["corps"]) if lc else -1, int(tc["corps"]) if tc else -1))
        print("  %s : poses avec un ennemi a 28 tuiles %d sur %d ; decisions %s" % (s, L[s]["feu"], L[s]["poses"], dict(L[s]["decisions"])))
    low = [r for r in ratios if r[4] > 0 and r[3] < 0.85 * r[4] or r[6] > 0 and r[5] < 0.85 * r[6]]
    for r in ratios:
        print("  %s %-8s min %2d : tourelles armees lot %d / temoin %d ; corps lot %d / temoin %d%s" % (r + (("   <- sous 0.85" if r in low else ""),)))
    feu = sum(L[s]["feu"] for s in L)
    print("  JUGEMENT C6 : lignes sous 0.85 du temoin : %d sur %d ; poses sous le feu : %d -> %s"
          % (len(low), len(ratios), feu, "TENU" if not low and feu == 0 else "NON TENU (voir lignes)"))
    for s in seeds:
        if s in L:
            for t in L[s]["dec"][:12]:
                print("   [%s] %s" % (s, t))
    return 0


if __name__ == "__main__":
    sys.exit(main())
