#!/usr/bin/env python3
"""Tests hors jeu de tools/autotest/geants_lecture.py (lot GISEMENTS-GEANTS).

Deux sources : des lignes COPIÉES TELLES QUELLES du journal du micro-banc (fo-logs/2026-11-08_GEANTS/micro2, 8/11, 139 OK) et une
série synthétique aux valeurs connues (minutes 5 à 40) pour vérifier les calculs, la synthèse, les cas dégénérés.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/tests/test_geants_lecture.py   -> « BILAN : N OK, 0 ECHEC(S) », code 0.
"""
import gzip
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import geants_lecture as L  # noqa: E402

ok = fail = 0


def check(cond, msg):
    global ok, fail
    if cond:
        ok += 1
    else:
        fail += 1
        print("  ECHEC : " + msg)


P = "  14.745 Script @__fo-autotest__/scenarios/geants_common.lua:505: "

# Extrait réel du journal du micro-banc (micro2) : une équipe et le témoin, minute 0,0.
REEL = [
    P + "[FO-GEANTS] pose terminee au tick 1 : 3 equipe(s), 24 gisement(s), 82164 tuiles creees",
    P + "[FO-GEANTS] minute 0.0 | player | iron-ore#1 | tuiles=4765 | couvert elec=0 (0 pm) therm=0 (0 pm) total=0 (0 pm) | foreuses elec=0 therm=0 | lignes=0 directes=0 sans_sortie=0",
    P + "[FO-GEANTS] minute 0.0 | player | TOTAL 8 gisement(s) 27518 tuiles | couvert elec=0 therm=0 total=0 (0 pm) | foreuses dessus elec=0 therm=0, hors geants 0 (toutes: elec=0 therm=0) | lignes=0",
    P + "[FO-GEANTS] minute 0.0 | TEMOIN | iron-ore#1 | tuiles=1400 | couvert elec=50 (36 pm) therm=8 (6 pm) total=58 (41 pm) | foreuses elec=2 therm=2 | lignes=2 directes=1 sans_sortie=0",
    P + "[FO-GEANTS] minute 0.0 | TEMOIN | TOTAL 1 gisement(s) 1400 tuiles | couvert elec=50 therm=8 total=58 (41 pm) | foreuses dessus elec=2 therm=2, hors geants 0 (toutes: elec=2 therm=2) | lignes=2",
    P + "[FO-ETAPE1-GEANTS-COURT] OK     GEANTS : releve : lignes de tapis : 2",
]


def dep_line(minute, team, ore, rang, n, ce, ct, cu, e, t, li, di=0, ss=0):
    return (P + "[FO-GEANTS] minute %.1f | %s | %s#%d | tuiles=%d | couvert elec=%d (%d pm) therm=%d (%d pm) total=%d (%d pm) | "
            "foreuses elec=%d therm=%d | lignes=%d directes=%d sans_sortie=%d") % (
        minute, team, ore, rang, n, ce, 1000 * ce // n, ct, 1000 * ct // n, cu, 1000 * cu // n, e, t, li, di, ss)


def tot_line(minute, team, ng, n, ce, ct, cu, e, t, hors, li):
    return (P + "[FO-GEANTS] minute %.1f | %s | TOTAL %d gisement(s) %d tuiles | couvert elec=%d therm=%d total=%d (%d pm) | "
            "foreuses dessus elec=%d therm=%d, hors geants %d (toutes: elec=%d therm=%d) | lignes=%d") % (
        minute, team, ng, n, ce, ct, cu, 1000 * cu // n, e, t, hors, e + 3, t + hors, li)


def synth(minutes):
    """player : à la minute m, 2 gisements (4000 et 2000 tuiles), électrique 25*m tuiles sur le grand, thermique 4*m ; azure : rien."""
    lines = []
    for m in minutes:
        ce, ct = 25 * m, 4 * m
        lines.append(dep_line(m, "player", "iron-ore", 1, 4000, ce, ct, ce + ct - 2, m, m, 2))
        lines.append(dep_line(m, "player", "iron-ore", 2, 2000, 0, 0, 0, 0, 0, 0))
        lines.append(tot_line(m, "player", 2, 6000, ce, ct, ce + ct - 2, m, m, 3, 2))
        lines.append(dep_line(m, "azure", "coal", 1, 3000, 0, 0, 0, 0, 0, 0))
        lines.append(tot_line(m, "azure", 1, 3000, 0, 0, 0, 0, 0, 5, 0))
    return lines


def write_arch(d, lines, gz=True):
    name = "benchmark.log.gz" if gz else "benchmark.log"
    p = os.path.join(d, name)
    opener = gzip.open if gz else open
    with opener(p, "wt", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


# 1. Lignes réelles : analyse
data = L.parse(REEL)
check(sorted(data) == ["TEMOIN", "player"], "équipes lues : player et TEMOIN : %s" % sorted(data))
r = L.at(data["player"], 0)
check(r is not None and r["total"]["tuiles"] == 27518 and r["total"]["n_dep"] == 8, "TOTAL réel lu (8 gisements, 27518 tuiles)")
check(r["deps"]["iron-ore#1"]["tuiles"] == 4765, "gisement réel lu (iron-ore#1, 4765 tuiles)")
t = L.at(data["TEMOIN"], 0)["total"]
check((t["cov_e"], t["cov_t"], t["cov"], t["e"], t["t"], t["lignes"]) == (50, 8, 58, 2, 2, 2), "témoin réel : 50/8/58, 2+2 foreuses, 2 lignes")
td = L.at(data["TEMOIN"], 0)["deps"]["iron-ore#1"]
check((td["lignes"], td["directes"], td["sans_sortie"]) == (2, 1, 0), "témoin réel : 2 lignes, 1 sortie directe, 0 sans sortie")

# 2. Archive faite de l'extrait réel : le témoin est écarté, puis gardé avec --avec-temoin
with tempfile.TemporaryDirectory() as d:
    write_arch(d, REEL)
    txt, syn = L.report(d, [5, 10], False, False)
    check("TEMOIN" not in txt and "player" in txt, "témoin écarté par défaut")
    txt2, _ = L.report(d, [5, 10], False, True)
    check("TEMOIN" in txt2, "témoin gardé avec --avec-temoin")
    check("la minute demandee manque : dernier releve" in txt, "minute de synthèse absente : dernier relevé dit")
    check(syn["player"]["minute"] == 0.0 and syn["player"]["pm"] == 0.0, "synthèse de repli : minute 0, 0 pm")

# 3. Série synthétique : calculs
with tempfile.TemporaryDirectory() as d:
    write_arch(d, REEL + synth([5, 10, 15, 20, 25, 30, 35, 40]))
    txt, syn = L.report(d, list(L.MINUTES), True, False)
    rows = L.parse(L.read_log(d))["player"]
    t40 = L.at(rows, 40)["total"]
    check(t40["cov_e"] == 1000 and t40["cov_t"] == 160 and t40["cov"] == 1158, "minute 40 : 1000 / 160 / 1158 tuiles")
    s = syn["player"]
    check(abs(s["pm_e"] - 1000 * 1000 / 6000) < 1e-9, "pm électrique à 40 min : 166,7 (1000 tuiles sur 6000)")
    check(abs(s["pm_t"] - 1000 * 160 / 6000) < 1e-9, "pm thermique à 40 min : 26,7")
    check(abs(s["pm"] - 1000 * 1158 / 6000) < 1e-9, "pm total à 40 min : 193,0 (l'union, pas la somme)")
    check(s["foreuses"] == 80 and s["lignes"] == 2, "synthèse : 80 foreuses (40 + 40), 2 lignes")
    check(s["touches"] == 1 and s["gisements"] == 2, "synthèse : 1 gisement touché sur 2")
    check(syn["azure"]["pm"] == 0.0 and syn["azure"]["touches"] == 0, "azure : 0 pm, 0 gisement touché")
    check("166.7" in txt and "26.7" in txt and "193.0" in txt, "tableau et synthèse portent 166.7, 26.7 et 193.0")
    check("meilleur iron-ore#1" in txt and "pire iron-ore#2 0.0 pm" in txt, "meilleur et pire gisement nommés")
    check("detail player" in txt and "iron-ore#2" in txt, "--detail : détail par gisement")
    check("Equipe VOTRE EQUIPE (player)" in txt and "Equipe azure" in txt, "un tableau par équipe, la vôtre d'abord")
    lines = [ln for ln in txt.splitlines() if re.match(r"^\s+\d+ \| ", ln)]
    check(len(lines) == 16, "8 minutes par équipe dans les tableaux : %d ligne(s) pour 2 équipes" % len(lines))

# 4. Cas dégénérés
with tempfile.TemporaryDirectory() as d:
    txt, syn = L.report(d, [5, 40])
    check("Aucune ligne" in txt and syn == {}, "archive vide : message, pas de plantage")
with tempfile.TemporaryDirectory() as d:
    write_arch(d, synth([5, 10]), gz=False)  # non compressé, sans minute 40
    txt, syn = L.report(d, [5, 10, 40])
    check("player a 10.0 min (la minute demandee manque" in txt, "benchmark.log brut lu ; minute 40 manquante : repli sur 10")
    check(" 40 |      - " in txt, "minute manquante écrite « - » dans le tableau")
with tempfile.TemporaryDirectory() as d:
    # une minute relevée deux fois : la dernière ligne l'emporte ; une ligne illisible est ignorée
    a = synth([5])
    b = [ln.replace("elec=125", "elec=999") for ln in synth([5])]
    write_arch(d, a + ["[FO-GEANTS] minute 5.0 | player | iron-ore#1 | ligne cassee"] + b)
    check(L.at(L.parse(L.read_log(d))["player"], 5)["total"]["cov_e"] == 999, "doublon : la dernière ligne l'emporte, ligne cassée ignorée")
check(L.pm(5, 0) == 0.0, "pm avec 0 tuile : 0, pas de division par zéro")
check(L.main([]) == 2 and L.main(["--inconnue"]) == 2, "sans archive ou option inconnue : code 2")

print("BILAN : %d OK, %d ECHEC(S)" % (ok, fail))
sys.exit(1 if fail else 0)
