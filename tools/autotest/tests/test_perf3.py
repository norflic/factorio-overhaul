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
# Lot X10-S0 : une portée après coup (idle:depart, inclusive : elle contient board:claim et worker:program, filles de la même mère)
# n'est retirée de personne et son propre vaut 0 : la mère garde 1 ms, et rien n'est compté deux fois.
DET2 = [" 1.0 Script @__factorio-overhaul__/script/core/profiler.lua:57: [FO-PERF3-T] 400 brain:worker:idle<lane:fo-brain Duration: 5.000000ms"
        " board:claim<brain:worker:idle Duration: 1.500000ms worker:program<brain:worker:idle Duration: 2.500000ms"
        " idle:depart<brain:worker:idle Duration: 4.000000ms lane:fo-brain<- Duration: 5.100000ms"]
pi = perf3.propre(perf3.parse_detail(DET2)[400])
verifie(abs(pi["brain:worker:idle"] - 1.0) < 1e-9 and pi["idle:depart"] == 0.0 and abs(sum(pi.values()) - 5.1) < 1e-9,
        "propre : portée après coup inclusive (ni fille ni double compte), somme des propres = premier niveau")
# Mutant (demande de perf3) : la portée inclusive additionnée comme une fille, comme avant ce lot. Le cas DOIT tomber.
_incl = perf3.INCLUSIVES
perf3.INCLUSIVES = frozenset()
pm = perf3.propre(perf3.parse_detail(DET2)[400])
perf3.INCLUSIVES = _incl
verifie(not (abs(pm["brain:worker:idle"] - 1.0) < 1e-9 and pm["idle:depart"] == 0.0 and abs(sum(pm.values()) - 5.1) < 1e-9),
        "mutant : portée inclusive additionnée comme une fille, le cas tombe (somme des propres %.1f au lieu de 5.1)" % sum(pm.values()))


# Garde de DÉRIVE (relecture de perf3, 7/11) : les noms des portées après coup, lus dans les appels de Profiler.fcredit de script/,
# doivent être EXACTEMENT INCLUSIVES. Un fcredit ajouté sans y être inscrit retomberait en silence dans le double compte ; un nom
# qui n'est pas un littéral ne se vérifie pas, et fait tomber le contrôle.
def noms_fcredit(racine):
    import re
    noms, appels, non_lit = set(), 0, 0
    for dossier, _, fichiers in os.walk(os.path.join(racine, "script")):
        for nom in sorted(fichiers):
            if not nom.endswith(".lua"):
                continue
            with open(os.path.join(dossier, nom), encoding="utf-8") as fh:
                for ligne in fh:
                    code = ligne.split("--", 1)[0]
                    for m in re.finditer(r'Profiler\.fcredit\(\s*"[^"]*"\s*,\s*([^)]*)\)', code):
                        appels += 1
                        lits = re.findall(r'"([^"]*)"', m.group(1))
                        if lits:
                            noms.update(lits)
                        else:
                            non_lit += 1
    return noms, appels, non_lit


def garde_inclusives(incl, noms, appels, non_lit):
    return appels > 0 and non_lit == 0 and noms == set(incl)


MOD = os.path.dirname(os.path.dirname(AUTOTEST))
nf, na, nl = noms_fcredit(MOD)
verifie(garde_inclusives(perf3.INCLUSIVES, nf, na, nl),
        "garde de dérive : %d appel(s) de Profiler.fcredit dans script/, noms littéraux = INCLUSIVES (%s)" % (na, ", ".join(sorted(nf))))
verifie(not garde_inclusives(perf3.INCLUSIVES - {"idle:depart"}, nf, na, nl),
        "mutant : un nom retiré d'INCLUSIVES, la garde tombe")

nm = perf3.normalise({0: 4.0, 650: 3.0, 1300: 1.0}, {0: 4.0, 600: 2.0}, 2.0)
verifie(nm[0] == 2.0 and nm[650] == 3.0 and nm[1300] == 1.0, "normalise : étalon de la fenêtre, sinon le plus proche")
verifie(perf3.normalise({5: 1.0}, {}, 2.0) == {5: 1.0}, "normalise : sans étalon, inchangé")
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

# Lot PERF4 : banc sur une sauvegarde : lignes du benchmark ramenées aux ticks du jeu.
import tempfile  # noqa: E402
with tempfile.TemporaryDirectory() as d:
    with open(os.path.join(d, "benchmark.log"), "w", encoding="utf-8") as f:
        f.write("  1.0 Script @__fo-autotest__/scenarios/perf4_partie_common.lua:1: [FO-PERF4] debut tick 919500 (x)\n")
    rows = {0: {"a": 1}, 1: {"a": 2}, 599: {"a": 3}}
    al = perf3.aligner(rows, d)
    verifie(sorted(al) == [919500, 919501, 920099],
            "aligner : t0 devient le tick 919500 (sauvegarde au tick 919500 : game.tick de la 1re mise à jour, mesuré sur B0)")
    rows_abs = {919500: {"a": 1}}
    verifie(perf3.aligner(rows_abs, d) == rows_abs, "aligner : des lignes déjà en ticks du jeu ne bougent pas")
    with open(os.path.join(d, "benchmark.log"), "w", encoding="utf-8") as f:
        f.write("rien\n")
    verifie(perf3.aligner(rows, d) == rows, "aligner : sans ligne [FO-PERF4] (carte créée), rien ne bouge")

# Lot PERF4 (7/11) : contrôle de l'alignement par l'étalon. Étalon de 2,1 ms aux ticks 600 et 1200, script de 0,3 ms
# ailleurs : bien aligné, l'étalon est DANS la ligne de son tick ; décalé d'un tick, il tombe sur une ligne voisine.
calib = {600: 2.1, 1200: 2.1}
juste = {t: {"scriptUpdate": (2.4 if t in calib else 0.3) * 1e6} for t in range(590, 1210)}
verifie(perf3.controle_etalon(juste, calib) == (0, 2), "alignement : étalon dans la ligne de son tick, 0 sur 2")
decale = {t + 1: r for t, r in juste.items()}
verifie(perf3.controle_etalon(decale, calib) == (2, 2), "mutant : lignes décalées d'un tick, 2 étalons sur 2 tombent")
verifie(perf3.dire_alignement(juste, calib) is True, "alignement : juste, pas d'alerte")
verifie(perf3.dire_alignement(decale, calib) is False, "mutant : décalé, ALIGNEMENT FAUX")

print("BILAN : %d OK%s" % (ok, (", %d ECHEC(S)" % ko) if ko else ""))
sys.exit(0 if ko == 0 else 1)
