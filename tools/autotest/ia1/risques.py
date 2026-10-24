"""Lot IA1-0 : lecture du banc ia1-risques (docs/EQUIPES_PNJ.md §14).

Usage :
    py -3.9 tools/autotest/ia1/risques.py "<racine>\\fo-autotest"        (ou le chemin d'un benchmark.log)
    py -3.9 tools/autotest/ia1/risques.py --selftest

Lit les lignes [FO-IA1-RISQUES] du benchmark :
  - le BILAN (contrôles de protocole) ;
  - les 6 lignes « VERDICT Rk » (R1, R2, R3, R4, R5, R7), toutes exigées ;
  - les durées R4 (LuaProfiler, durée TOTALE de n appels) : coût unitaire en µs par répétition, médiane, min, max ;
    puis ramené à l'étalon de référence (2,01 ms : médiane de 116 mesures [FO-CALIB] des bancs d'intégration des 23 et
    24/10) par l'étalon de la même répétition (etalon_calib, même charge Lua que [FO-CALIB]).
Écrit le VERDICT R4 (coûts mesurés contre les estimations O.OP_UNITS de shared/team/org.lua : 1 unité ≈ 1 µs).
Code 0 : BILAN sans échec, 6 verdicts présents, toutes les mesures R4 lues ; 1 sinon.
"""
import argparse
import os
import re
import statistics
import sys

TAG = "[FO-IA1-RISQUES]"
REF_CALIB_MS = 2.01
VERDICTS = ["R1", "R2", "R3", "R4", "R5", "R7"]
# Estimations de shared/team/org.lua (O.OP_UNITS) : unités de travail, 1 unité ≈ 1 µs (à étalonner par R4).
OP_UNITS = {"ghost": 50, "revive": 50, "lot_eval": 50, "street_eval": 50}
LABELS = [
    "boucle_vide", "count_entities_lot_vide", "count_entities_lot_naturel", "count_entities_lot_occupe",
    "count_tiles_eau_lot_naturel", "count_falaises_lot_naturel", "count_ressources_lot_naturel",
    "count_autre_force_lot_naturel", "count_arbres_rochers_sans_limite_lot_naturel", "can_place_script_ghost",
    "pose_fantome_can_place_create", "pose_fantome_create_raise_built", "ravivage_retrait_objet_avec_gestionnaires",
    "ravivage_sans_gestionnaires", "retrait_objet_seul",
]
# Évaluation d'un lot de 24 × 24 (§6.5) : eau, falaises, ressources, bâtiments d'une autre force, arbres et rochers.
LOT_EVAL = ["count_tiles_eau_lot_naturel", "count_falaises_lot_naturel", "count_ressources_lot_naturel",
            "count_autre_force_lot_naturel", "count_arbres_rochers_sans_limite_lot_naturel"]

R4_RE = re.compile(r"\[FO-IA1-RISQUES\] R4\t(\S+)\tn=(\d+)\trep=(\d+)\tDuration: ([0-9.]+)ms")
BILAN_RE = re.compile(r"\[FO-IA1-RISQUES\] BILAN : (\d+) OK, (\d+) ECHEC")
VERDICT_RE = re.compile(r"\[FO-IA1-RISQUES\] VERDICT (R\d) : (\S+) : (.*)$")


def read_log(path):
    if os.path.isdir(path):
        path = os.path.join(path, "benchmark.log")
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()


def parse(lines):
    r4 = {}
    calib = {}
    bilan = None
    verdicts = {}
    for ln in lines:
        m = R4_RE.search(ln)
        if m:
            label, n, rep, ms = m.group(1), int(m.group(2)), int(m.group(3)), float(m.group(4))
            if label == "etalon_calib":
                calib[rep] = ms
            else:
                r4.setdefault(label, {})[rep] = (n, ms)
            continue
        m = BILAN_RE.search(ln)
        if m:
            bilan = (int(m.group(1)), int(m.group(2)))
            continue
        m = VERDICT_RE.search(ln)
        if m:
            verdicts[m.group(1)] = (m.group(2), m.group(3))
    return r4, calib, bilan, verdicts


def unit_costs(r4, calib):
    """{label: {"brut": [µs par rep], "norm": [µs ramenés à l'étalon]}} ; reps triées."""
    out = {}
    for label in sorted(r4):
        brut, norm = [], []
        for rep in sorted(r4[label]):
            n, ms = r4[label][rep]
            us = ms * 1000.0 / n
            brut.append(us)
            c = calib.get(rep)
            norm.append(us * REF_CALIB_MS / c if c else us)
        out[label] = {"brut": brut, "norm": norm}
    return out


def stat(xs):
    return statistics.median(xs), min(xs), max(xs)


def report(lines):
    r4, calib, bilan, verdicts = parse(lines)
    costs = unit_costs(r4, calib)
    ok = True
    out = []
    out.append("[FO-IA1-R4] etalon par repetition (ms, reference %.2f) : %s" % (
        REF_CALIB_MS, ", ".join("rep %d %.3f" % (k, calib[k]) for k in sorted(calib)) or "aucun"))
    missing = [lab for lab in LABELS if lab not in costs]
    if missing:
        ok = False
        out.append("[FO-IA1-R4] ECHEC mesures absentes : " + ", ".join(missing))
    out.append("[FO-IA1-R4] cout unitaire en microsecondes : brut (mediane, min, max) | ramene a l'etalon (mediane, min, max)")
    for lab in LABELS:
        if lab in costs:
            b, n = stat(costs[lab]["brut"]), stat(costs[lab]["norm"])
            out.append("[FO-IA1-R4]   %-46s %7.3f %7.3f %7.3f | %7.3f %7.3f %7.3f" % (lab, b[0], b[1], b[2], n[0], n[1], n[2]))
    if not missing:
        med = {lab: stat(costs[lab]["norm"])[0] for lab in LABELS}
        mx = {lab: stat(costs[lab]["norm"])[2] for lab in LABELS}
        ghost = med["pose_fantome_can_place_create"]
        revive = med["ravivage_retrait_objet_avec_gestionnaires"]
        handlers = revive - med["ravivage_sans_gestionnaires"] - med["retrait_objet_seul"]
        lot = sum(med[lab] for lab in LOT_EVAL)
        lot_max = sum(mx[lab] for lab in LOT_EVAL)
        out.append("[FO-IA1-R4] pose d'un fantome (can_place + create_entity) : %.1f us (max %.1f) ; estime %d" % (
            ghost, mx["pose_fantome_can_place_create"], OP_UNITS["ghost"]))
        out.append("[FO-IA1-R4] ravivage d'un fantome par un PNJ (retrait de l'objet + revive{raise_revive} + gestionnaires du mod) :"
                   " %.1f us (max %.1f) ; dont gestionnaires %.1f us ; estime %d" % (
                       revive, mx["ravivage_retrait_objet_avec_gestionnaires"], handlers, OP_UNITS["revive"]))
        out.append("[FO-IA1-R4] evaluation d'un lot de 24 x 24 (5 appels : eau, falaises, ressources, autre force, arbres) : "
                   "%.1f us (somme des max %.1f) ; estime %d" % (lot, lot_max, OP_UNITS["lot_eval"]))
        under = ghost <= OP_UNITS["ghost"] and revive <= OP_UNITS["revive"] and lot <= OP_UNITS["lot_eval"]
        prop = {
            "ghost": max(1, int(round(mx["pose_fantome_can_place_create"] * 1.5))),
            "revive": max(1, int(round(mx["ravivage_retrait_objet_avec_gestionnaires"] * 1.5))),
            "lot_eval": max(1, int(round(lot_max * 1.5))),
        }
        out.append("[FO-IA1-R4] VERDICT R4 : %s : couts mesures %s les estimations (fantome %.1f us, ravivage %.1f us, lot %.1f us "
                   "contre 50 chacun) ; proposition O.OP_UNITS (max ramene a l'etalon x 1,5) : ghost %d, revive %d, lot_eval %d, "
                   "street_eval %d ; repli : %s" % (
                       "OUI" if under else "NON", "sous" if under else "AU-DESSUS DE", ghost, revive, lot,
                       prop["ghost"], prop["revive"], prop["lot_eval"], prop["lot_eval"],
                       "aucun (budget de 400 unites par tick : environ %d poses ou %d ravivages)" % (
                           400 // prop["ghost"], 400 // prop["revive"]) if under else "reduire les evaluations par phase"))
    if bilan is None:
        ok = False
        out.append("[FO-IA1-R4] ECHEC aucun BILAN au journal")
    else:
        out.append("[FO-IA1-R4] BILAN du banc : %d OK, %d ECHEC(S)" % bilan)
        ok = ok and bilan[1] == 0
    for v in VERDICTS:
        if v in verdicts:
            out.append("[FO-IA1-R4] verdict %s : %s" % (v, verdicts[v][0]))
        else:
            ok = False
            out.append("[FO-IA1-R4] ECHEC verdict %s absent" % v)
    out.append("[FO-IA1-R4] RESULTAT : %s" % ("OK" if ok else "ECHEC"))
    return ok, out


SAMPLE = """   1.0 Script @__fo-autotest__/scenarios/ia1-risques.lua:1: [FO-IA1-RISQUES] VERDICT R1 : OUI : x
   1.0 Script x: [FO-IA1-RISQUES] VERDICT R2 : OUI : x
   1.0 Script x: [FO-IA1-RISQUES] VERDICT R3 : OUI : x
   1.0 Script x: [FO-IA1-RISQUES] VERDICT R4 : MESURE : x
   1.0 Script x: [FO-IA1-RISQUES] VERDICT R5 : OUI : x
   1.0 Script x: [FO-IA1-RISQUES] VERDICT R7 : OUI : x
   1.0 Script x: [FO-IA1-RISQUES] BILAN : 40 OK, 0 ECHEC(S)
"""


def selftest():
    lines = SAMPLE.splitlines()
    lines.append("x: [FO-IA1-RISQUES] R4\tetalon_calib\tn=200000\trep=1\tDuration: 4.020000ms")
    for lab in LABELS:
        n = 200 if lab.startswith(("pose", "ravivage", "retrait")) else 1000
        lines.append("x: [FO-IA1-RISQUES] R4\t%s\tn=%d\trep=1\tDuration: %.6fms" % (lab, n, n * 0.010))
    checks = 0
    ok, out = report(lines)
    assert ok, out
    checks += 1
    # 10 µs brut, étalon 2 × plus lent que la référence (4,02 contre 2,01 ms) : 5,000 µs ramenés.
    assert any("count_entities_lot_vide" in ln and "10.000" in ln and "5.000" in ln for ln in out), out
    checks += 1
    assert any("VERDICT R4 : OUI" in ln for ln in out), out
    checks += 1
    ok2, out2 = report([ln for ln in lines if "VERDICT R3" not in ln])
    assert not ok2 and any("verdict R3 absent" in ln for ln in out2)
    checks += 1
    ok3, _ = report([ln.replace("40 OK, 0 ECHEC", "39 OK, 1 ECHEC") for ln in lines])
    assert not ok3
    checks += 1
    ok4, out4 = report([ln for ln in lines if "can_place_script_ghost" not in ln])
    assert not ok4 and any("mesures absentes" in ln for ln in out4)
    checks += 1
    print("[FO-IA1-R4] autotest : %d OK" % checks)
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("chemin", nargs="?", help="dossier fo-autotest ou benchmark.log")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if not a.chemin:
        ap.error("chemin requis")
    ok, out = report(read_log(a.chemin))
    print("\n".join(out))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
