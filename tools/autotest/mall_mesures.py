#!/usr/bin/env python3
"""Lecture des journaux [FO-MALL-ALIM] du lot MALL (script/team/liaison.lua) : un tableau par archive de banc, un relevé par équipe et par minute.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/mall_mesures.py <archive> [<archive> ...] [--comparer <temoin> <essai>]

Une archive est un dossier de banc (benchmark.log.gz ou benchmark.log). Le journal donne, toutes les 5 minutes par équipe :
  - les causes pour lesquelles les quais d'entrée ne sont pas servis par un tapis, pour les malls et pour les autres ;
  - le portage à la main cumulé (voyages, objets) dont celui vers les malls ;
  - les objets fabriqués par minute par les malls depuis le dernier relevé.
--comparer calcule les critères K1 à K4 de fo-logs/2026-11-02_MALL/CRITERES.md (essai contre témoin, par équipe, mêmes minutes).
"""
import gzip
import os
import re
import sys

LIGNE = re.compile(
    r"\[FO-LIAISON\] (?P<eq>\S+) : \[FO-MALL-ALIM\] quais sans tapis : mall : (?P<mall>.*?) ; autres : (?P<autres>.*?)"
    r"(?: ; sortie la plus proche des quais LOIN : (?P<loin>[\d,]+) tuiles)?"
    r"(?: ; sans sortie pour \[(?P<sans>.*?)\] ; sorties \[(?P<sorties>.*?)\])?"
    r" \| portage a la main : (?P<voy>\d+) voyage\(s\), (?P<obj>\d+) objet\(s\) dont (?P<mvoy>\d+) voyage\(s\) et (?P<mobj>\d+) objet\(s\) vers des malls"
    r" \| malls : (?P<nit>\d+) objet\(s\) suivis, (?P<fab>[\d.]+) fabrique\(s\)/min depuis le dernier releve"
    r"(?: \| portage des malls par objet \[(?P<par>.*?)\])? a (?P<min>[\d.]+) min")


def causes(texte):
    out = {}
    if texte.strip() in ("", "aucun"):
        return out
    for part in texte.split(","):
        part = part.strip()
        m = re.match(r"(\d+) (\S+)$", part)
        if m:
            out[m.group(2)] = int(m.group(1))
    return out


def lire(archive):
    chemin = None
    for nom in ("benchmark.log.gz", "benchmark.log"):
        c = os.path.join(archive, nom)
        if os.path.exists(c):
            chemin = c
            break
    if not chemin:
        raise SystemExit("pas de benchmark.log dans " + archive)
    ouvrir = gzip.open if chemin.endswith(".gz") else open
    rel = {}
    with ouvrir(chemin, "rt", encoding="utf-8", errors="replace") as f:
        for ligne in f:
            m = LIGNE.search(ligne)
            if not m:
                continue
            d = m.groupdict()
            r = {
                "min": float(d["min"]), "mall": causes(d["mall"]), "autres": causes(d["autres"]),
                "voy": int(d["voy"]), "obj": int(d["obj"]), "mvoy": int(d["mvoy"]), "mobj": int(d["mobj"]),
                "nit": int(d["nit"]), "fab": float(d["fab"]), "sans": d["sans"], "sorties": d["sorties"], "par": d["par"],
            }
            rel.setdefault(d["eq"], []).append(r)
    return rel


def au_plus_pres(liste, minute):
    """Dernier relevé de minute <= `minute` (les relevés d'une équipe tombent toutes les 5 min, décalés)."""
    best = None
    for r in liste:
        if r["min"] <= minute + 1e-9:
            best = r
    return best


def part_servie(r):
    """(servis, utiles) : quais de mall servis par tapis, et quais de mall dont le débit est utile (hors cause « debit »)."""
    c = r["mall"]
    utiles = sum(v for k, v in c.items() if k != "debit")
    return c.get("servi", 0), utiles


def afficher(archive, rel):
    print("== %s" % archive)
    for eq in sorted(rel):
        print("-- %s" % eq)
        print("  min  quais-mall(causes)                       portage(voy/obj)  vers malls(voy/obj)  malls(obj suivis, fab/min)")
        for r in rel[eq]:
            causes_txt = ", ".join("%d %s" % (v, k) for k, v in sorted(r["mall"].items())) or "aucun"
            print("  %4.0f  %-40s  %4d/%-7d  %4d/%-7d  %2d  %6.1f" % (
                r["min"], causes_txt[:40], r["voy"], r["obj"], r["mvoy"], r["mobj"], r["nit"], r["fab"]))
            if r.get("sans") and r["min"] >= 30:
                print("        sans sortie pour [%s] ; sorties [%s]" % (r["sans"], r["sorties"]))
            if r.get("par") and r["min"] >= 30:
                print("        portage des malls par objet [%s]" % r["par"])


def comparer(temoin, essai):
    print("== comparaison témoin %s / essai %s" % (temoin, essai))
    rt, re_ = lire(temoin), lire(essai)
    for eq in sorted(set(rt) & set(re_)):
        t60, e60 = au_plus_pres(rt[eq], 60), au_plus_pres(re_[eq], 60)
        t30, e30 = au_plus_pres(rt[eq], 30), au_plus_pres(re_[eq], 30)
        if not (t60 and e60):
            continue
        s_t, u_t = part_servie(t60)
        s_e, u_e = part_servie(e60)
        k1 = (u_e == 0) or (s_e / u_e >= 0.5)
        dt = t60["mvoy"] - (t30["mvoy"] if t30 else 0)
        de = e60["mvoy"] - (e30["mvoy"] if e30 else 0)
        k2 = (de <= 0.6 * dt) if dt >= 10 else (de <= dt)
        # durée d'un aller-retour : 2 x distance au QG / 8 + 10 s ; distance inconnue ici : 40 tuiles (contexte, pas critère)
        k4 = (dt - de) * (2 * 40 / 8 + 10) / 30.0
        derniers_t = [r["fab"] for r in rt[eq] if 45 <= r["min"] <= 60 and r["nit"] > 0]
        derniers_e = [r["fab"] for r in re_[eq] if 45 <= r["min"] <= 60 and r["nit"] > 0]
        ft = sum(derniers_t) / len(derniers_t) if derniers_t else 0.0
        fe = sum(derniers_e) / len(derniers_e) if derniers_e else 0.0
        k3 = (fe >= 0.95 * ft) if ft > 0 else True
        print("%-9s K1 servis %d/%d (témoin %d/%d) %s | K2 voyages 30-60 min : %d contre %d %s | K3 fab/min %.1f contre %.1f %s | K4 %.1f PNJ-s/min libérées (aller-retour 40 tuiles) %s"
              % (eq, s_e, u_e, s_t, u_t, "OK" if k1 else "FAUX", de, dt, "OK" if k2 else "FAUX", fe, ft, "OK" if k3 else "FAUX", k4, "OK" if k4 >= 0 else "FAUX"))


def main(argv):
    if "--comparer" in argv:
        i = argv.index("--comparer")
        comparer(argv[i + 1], argv[i + 2])
        return 0
    archives = [a for a in argv if not a.startswith("--")]
    if not archives:
        print(__doc__)
        return 2
    for a in archives:
        afficher(a, lire(a))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
