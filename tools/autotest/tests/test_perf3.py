# Lot PERF3 : règles pures de tools/autotest/perf3.py (lecture du benchmark, étalon soustrait, détail par tick, temps propre,
# période, journal des décisions), avec mutants. Hors jeu, moins de 2 s.
#   PYTHONUTF8=1 py -3.9 -B tools/autotest/tests/test_perf3.py   -> BILAN : n OK
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
AUTOTEST = os.path.dirname(ICI)
sys.path.insert(0, AUTOTEST)
import perf3  # noqa: E402

ok = ko = 0


def verifie(cond, quoi):
    global ok, ko
    if cond:
        ok += 1
        print("OK   " + quoi)
    else:
        ko += 1
        print("ECHEC " + quoi)


VERBOSE = [
    "   0.001 bla",
    "tick,timestamp,wholeUpdate,entityUpdate,scriptUpdate,",
    "t0,0,5000000,100000,4000000,",
    "t1,10,900000,100000,300000,",
    "t600,20,3000000,100000,2600000,",
    "Performed 3 updates",
]
rows = perf3.parse_verbose(VERBOSE)
verifie(sorted(rows) == [0, 1, 600] and rows[1]["scriptUpdate"] == 300000, "parse_verbose : 3 ticks, colonnes nommées")
LOG = [
    "   5.603 Script @__fo-autotest__/control.lua:255: [FO-CALIB] 600 Duration: 2.400000ms",
    "   5.603 Script @__fo-autotest__/control.lua:255: [FO-CALIB] 0 Duration: 5.000000ms",
]
cal = perf3.parse_calib(LOG)
verifie(cal == {600: 2.4, 0: 5.0}, "parse_calib : tick et durée")
sc = perf3.script_ms(rows, cal)
verifie(abs(sc[600] - 0.2) < 1e-9 and abs(sc[1] - 0.3) < 1e-9, "script_ms : étalon soustrait au seul tick où il tourne")
verifie(sc[0] == 0.0, "script_ms : jamais sous 0")

DET = [
    " 1.0 Script @__factorio-overhaul__/script/core/profiler.lua:57: [FO-PERF3-T] 300 event:on_tick<- Duration: 10.000000ms"
    " lane:commander<event:on_tick Duration: 9.000000ms team:board<lane:commander Duration: 6.000000ms"
    " faction:think<lane:commander Duration: 2.500000ms nth:60<- Duration: 1.000000ms",
    " 1.1 Script @__factorio-overhaul__/script/core/profiler.lua:57: [FO-PERF3-T] 301 event:on_tick<- Duration: 0.100000ms",
]
det = perf3.parse_detail(DET)
verifie(sorted(det) == [300, 301] and det[300]["team:board"] == ("lane:commander", 6.0), "parse_detail : portée, mère, durée")
pr = perf3.propre(det[300])
verifie(abs(pr["event:on_tick"] - 1.0) < 1e-9 and abs(pr["lane:commander"] - 0.5) < 1e-9 and pr["team:board"] == 6.0,
        "propre : durée moins les filles du même tick")
verifie(perf3.premier_niveau(det[300]) == 11.0, "premier_niveau : event:on_tick + nth:60")
# Mutant : une portée comptée deux fois (mère ignorée) ferait un temps propre de la voie > 9.
verifie(pr["lane:commander"] < 9.0, "mutant : la fille retirée de la mère")

verifie(perf3.periode([0, 300, 600, 900, 1500]) == (300, 0.75), "periode : écart le plus fréquent et sa part")
verifie(perf3.periode([0, 5]) == (0, 0.0), "periode : trop peu d'occurrences")
v = [0.1] * 98 + [20.0, 120.0]
s = perf3.stats(v)
verifie(s["max"] == 120.0 and s["p99"] == 20.0 and s["n"] == 100, "stats : max et p99")
c = perf3.comptes(v)
verifie(c[16.0] == 2 and c[100.0] == 1 and c[1.6] == 2, "comptes : seuils stricts")

J1 = [
    "  10.0 Script @__factorio-overhaul__/script/team/team.lua:860: [FO-TEAM] amber : objectif atteint 'x' a 3.0 min",
    "  10.1 Script @__fo-autotest__/control.lua:255: [FO-CALIB] 600 Duration: 2.4ms",
    "  10.2 Script @__factorio-overhaul__/script/core/profiler.lua:57: [FO-PERF3-T] 600 event:on_tick<- Duration: 1ms",
    "  10.3 Script @__factorio-overhaul__/script/ai3/comportement.lua:869: [FO-IA3K] amber : PNJ 3 attend",
    "  10.4 Script @__factorio-overhaul__/script/remote.lua:62:   capi:data | total Duration: 1ms | moyenne/tick Duration: 1ms",
]
J2 = [
    "  99.0 Script @__factorio-overhaul__/script/team/team.lua:871: [FO-TEAM] amber : objectif atteint 'x' a 3.0 min",
]
verifie(perf3.decisions(J1, True) == perf3.decisions(J2, True),
        "decisions : horodatage, fichier:ligne, mesures et lignes du profileur retirées")
verifie(perf3.decisions(J1) != perf3.decisions(J2), "decisions : [FO-IA3K] gardé sans --sans-profileur")
J3 = [J2[0].replace("3.0 min", "3.1 min")]
verifie(perf3.decisions(J3) != perf3.decisions(J2), "mutant : une décision changée est vue")

print("BILAN : %d OK%s" % (ok, (", %d ECHEC(S)" % ko) if ko else ""))
sys.exit(0 if ko == 0 else 1)
