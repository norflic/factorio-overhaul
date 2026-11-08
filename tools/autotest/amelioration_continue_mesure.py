#!/usr/bin/env python
"""Lot AMELIORATION-CONTINUE : lit le journal d'une partie (benchmark.log ou .log.gz, ou le journal du jeu) et juge les critères K1 à K6
de fo-logs/2026-11-08_AMELIORATION-CONTINUE/CRITERES.md.

    py -3.9 -B tools/autotest/amelioration_continue_mesure.py <journal> [--temoin <journal du temoin>]

Lit seulement : lignes [FO-CAPITAL] « amelioration payee », [FO-AMELIORATION-PARC], [FO-IA3C] « recherche ... commencee », profileur
« capital:decide ». Le centre (famille command) et les tourelles/murs ne comptent pas comme pièces de production dans K2 ; ils sont
comptés à part. Sans PYTHONUTF8, l'affichage des accents peut échouer : lancer avec PYTHONUTF8=1.
"""
import argparse
import gzip
import re
import statistics
import sys

PAYEE = re.compile(r"\[FO-CAPITAL\] (\w+) : amelioration payee '([^']*)' \(([^)]*)\).*? a ([0-9.]+) min")
PARC = re.compile(r"\[FO-AMELIORATION-PARC\] (\w+) : (\S+) : (.*?) ; montees (\d+)/(\d+) \((\d+)%\) a ([0-9.]+) min")
RECH = re.compile(r"\[FO-IA3C\] (\w+) : recherche '([^']+)' commencee .*? a ([0-9.]+) min")
PROFIL = re.compile(r"capital:decide \| total Duration: ([0-9.]+)ms \| moyenne/tick Duration: ([0-9.]+)ms")
LOTX = re.compile(r" x(\d+)")


def lire(path):
    op = gzip.open if path.endswith(".gz") else open
    with op(path, "rt", encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()


def mesurer(lines):
    paiements = []  # (equipe, minute, pieces, genre, texte)
    parcs = []
    rech = []
    profil = None
    for ln in lines:
        m = PAYEE.search(ln)
        if m:
            team, key, txt, minute = m.group(1), m.group(2), m.group(3), float(m.group(4))
            lot = LOTX.search(txt)
            n = int(lot.group(1)) if lot else 1
            genre = "remplacer" if txt.startswith("remplacer") else ("bloc" if txt.startswith("bloc") else "niveau")
            if txt.startswith("command"):
                genre = "centre"
            paiements.append((team, minute, n, genre, txt))
            continue
        m = PARC.search(ln)
        if m:
            parcs.append((m.group(1), m.group(2), int(m.group(4)), int(m.group(5)), int(m.group(6)), float(m.group(7)), m.group(3)))
            continue
        m = RECH.search(ln)
        if m:
            rech.append((m.group(1), m.group(2), float(m.group(3))))
            continue
        m = PROFIL.search(ln)
        if m:
            profil = (float(m.group(1)), float(m.group(2)))
    return paiements, parcs, rech, profil


def resume(nom, lines):
    paiements, parcs, rech, profil = mesurer(lines)
    out = []
    out.append("== %s" % nom)
    prod = [p for p in paiements if p[3] in ("remplacer", "bloc")]
    tout = [p for p in paiements]
    out.append("paiements : %d (dont %d de pieces de production, %d centre) ; pieces montees (hors centre) : %d" % (
        len(tout), len(prod), sum(1 for p in tout if p[3] == "centre"), sum(p[2] for p in tout if p[3] != "centre")))
    if tout:
        tailles = [p[2] for p in tout]
        out.append("tailles des lots payes : mediane %s, max %d, lots de 4 pieces ou plus : %d" % (statistics.median(tailles), max(tailles), sum(1 for t in tailles if t >= 4)))
    equipes = sorted(set(p[0] for p in tout))
    for e in equipes:
        mine = sorted(p for p in tout if p[0] == e)
        pieces = sum(p[2] for p in mine if p[3] != "centre")
        premier = mine[0][1]
        trous = [round(b[1] - a[1], 1) for a, b in zip(mine, mine[1:])]
        pire = max(trous) if trous else 0
        genres = {}
        for p in mine:
            genres[p[3]] = genres.get(p[3], 0) + p[2]
        out.append("  %-8s %3d paiement(s), %4d piece(s), premier a %.1f min, plus long intervalle %.1f min ; %s" % (
            e, len(mine), pieces, premier, pire, ", ".join("%s %d" % (k, genres[k]) for k in sorted(genres))))
    # Parc : dernier etat par equipe et groupe, et premier etat
    dernier = {}
    premier = {}
    for (team, key, up, tot, pct, minute, txt) in parcs:
        dernier[(team, key)] = (minute, up, tot, pct, txt)
        premier.setdefault((team, key), (minute, up, tot, pct, txt))
    for (team, key) in sorted(dernier):
        a, b = premier[(team, key)], dernier[(team, key)]
        out.append("  parc %-8s %-28s : %d/%d (%d%%) a %.1f min -> %d/%d (%d%%) a %.1f min  [%s]" % (
            team, key, a[1], a[2], a[3], a[0], b[1], b[2], b[3], b[0], b[4]))
    for (team, tech, minute) in rech:
        if tech in ("logistics-2", "fast-inserter", "advanced-material-processing", "automation-2", "logistics"):
            out.append("  recherche %-8s %s commencee a %.1f min" % (team, tech, minute))
    if profil:
        out.append("profileur capital:decide : total %.0f ms, moyenne %.5f ms par tick" % profil)
    return out, paiements, profil


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("journal")
    ap.add_argument("--temoin")
    a = ap.parse_args()
    out, paiements, profil = resume(a.journal, lire(a.journal))
    print("\n".join(out))
    if a.temoin:
        out_t, pt, prof_t = resume(a.temoin, lire(a.temoin))
        print("\n".join(out_t))
        base = sum(p[2] for p in pt if p[3] != "centre")
        now = sum(p[2] for p in paiements if p[3] != "centre")
        tailles = [p[2] for p in paiements]
        print("== VERDICT (criteres K1 a K6 du CRITERES.md)")
        print("K1 lots : mediane %s (temoin %s), lot >= 4 : %s" % (statistics.median(tailles) if tailles else "-",
              statistics.median([p[2] for p in pt]) if pt else "-", "OUI" if any(t >= 4 for t in tailles) else "NON"))
        print("K2 volume : %d pieces (temoin %d) : %s" % (now, base, "OUI" if base and now >= 3 * base else ("OUI" if now >= 15 else "NON")))
        if profil:
            print("K6 cout : %.5f ms par tick (seuil 0.02) : %s" % (profil[1], "OUI" if profil[1] <= 0.02 else "NON"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
