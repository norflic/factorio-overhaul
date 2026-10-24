"""Lot IA1-0 : lecture du banc ia1-risques (docs/EQUIPES_PNJ.md §14).

Usage :
    py -3.9 tools/autotest/ia1/risques.py "<racine>\\fo-autotest" [<passe 2> ...] [--attendu R1=OUI,...]
    py -3.9 tools/autotest/ia1/risques.py --selftest

Chaque chemin est une PASSE du banc (dossier fo-autotest archivé ou benchmark.log). Pour chaque passe :
  - le BILAN (contrôles de protocole) doit être sans échec ;
  - les 6 lignes « VERDICT Rk » (R1, R2, R3, R4, R5, R7) doivent être présentes ET égales aux verdicts attendus
    (--attendu ; par défaut R1=OUI, R2=SE REALISE, R3=OUI, R4=MESURE, R5=OUI, R7=OUI) : un verdict qui change fait
    échouer le code de sortie ;
  - les durées R4 (LuaProfiler, durée TOTALE de n appels) donnent un coût unitaire BRUT en µs par répétition.
Correction du 24/10 (vérification M3) : les valeurs « ramenées à l'étalon » ne sont plus calculées (l'étalon varie de
14 à 23 % dans un même tick) ; l'étalon de chaque répétition sert seulement à dire si la passe est CALME (médiane des
étalons au plus 2,31 ms = 2,01 ms × 1,15 ; 2,01 ms : médiane de 116 mesures [FO-CALIB] des bancs d'intégration des
23 et 24/10).
Écrit le VERDICT R4 : OUI si le MAXIMUM BRUT de toutes les passes (fantôme, ravivages, évaluation d'un lot) reste sous
les estimations O.OP_UNITS de shared/team/org.lua (50 unités, 1 unité ≈ 1 µs). Proposition O.OP_UNITS = maximum brut
des passes CALMES × 1,5, arrondi au-dessus, seulement s'il y a au moins 2 passes calmes. Le ravivage est une BORNE
BASSE : les gestionnaires d'équipe (§12) n'existent pas encore (à remesurer dans ia1-scale).
Code 0 : toutes les passes valides ; 1 sinon.
"""
import argparse
import math
import os
import re
import statistics
import sys

REF_CALIB_MS = 2.01
CALM_MS = REF_CALIB_MS * 1.15
VERDICTS = ["R1", "R2", "R3", "R4", "R5", "R7"]
DEFAULT_EXPECTED = "R1=OUI,R2=SE REALISE,R3=OUI,R4=MESURE,R5=OUI,R7=OUI"
# Estimations de shared/team/org.lua (O.OP_UNITS) : unités de travail, 1 unité ≈ 1 µs.
OP_UNITS = {"ghost": 50, "revive": 50, "lot_eval": 50, "street_eval": 50}
LOTS = {
    "naturel": ["count_tiles_eau_lot_naturel", "count_falaises_lot_naturel", "count_ressources_lot_naturel",
                "count_autre_force_lot_naturel", "count_arbres_rochers_sans_limite_lot_naturel"],
    "foret": ["count_tiles_eau_lot_foret", "count_falaises_lot_foret", "count_ressources_lot_foret",
              "count_autre_force_lot_foret", "count_arbres_rochers_sans_limite_lot_foret"],
}
GHOST = "pose_fantome_can_place_create"
# Ravivages « machine » (assembleur, tuyau raccordé, poteau isolé) : unité revive ; poteau RACCORDÉ à un réseau
# électrique : mesuré en 4 quarts de 50 (le réseau grandit de 1 à 200 poteaux), unité à part (revive_pole).
REVIVES = ["ravivage_retrait_objet_avec_gestionnaires", "ravivage_tuyau_raccorde"]
POLES = ["ravivage_poteau_raccorde_q1", "ravivage_poteau_raccorde_q2", "ravivage_poteau_raccorde_q3",
         "ravivage_poteau_raccorde_q4", "ravivage_poteau_isole", "ravivage_poteau_isole_sans_gestionnaires",
         "ravivage_poteau_isole_force_sans_poteau", "pose_poteau_create_entity"]
LABELS = [
    "boucle_vide", "count_entities_lot_vide", "count_entities_lot_naturel", "count_entities_lot_occupe",
] + LOTS["naturel"] + LOTS["foret"] + [
    "can_place_script_ghost", GHOST, "pose_fantome_create_raise_built",
] + REVIVES + POLES + ["ravivage_sans_gestionnaires", "retrait_objet_seul"]

R4_RE = re.compile(r"\[FO-IA1-RISQUES\] R4\t(\S+)\tn=(\d+)\trep=(\d+)\tDuration: ([0-9.]+)ms")
BILAN_RE = re.compile(r"\[FO-IA1-RISQUES\] BILAN : (\d+) OK, (\d+) ECHEC")
VERDICT_RE = re.compile(r"\[FO-IA1-RISQUES\] VERDICT (R\d) : (.+?) : (.*)$")


def read_log(path):
    if os.path.isdir(path):
        path = os.path.join(path, "benchmark.log")
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()


def parse(lines):
    r4, calib, bilan, verdicts = {}, {}, None, {}
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
            verdicts[m.group(1)] = (m.group(2).strip(), m.group(3))
    return r4, calib, bilan, verdicts


def unit_costs(r4):
    """{label: [µs bruts par répétition, répétitions triées]}."""
    return {label: [r4[label][rep][1] * 1000.0 / r4[label][rep][0] for rep in sorted(r4[label])] for label in sorted(r4)}


def parse_expected(text):
    out = {}
    for part in text.split(","):
        if "=" in part:
            k, v = part.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def check_pass(name, lines, expected, out):
    """Contrôle une passe ; renvoie (ok, coûts bruts, étalons)."""
    r4, calib, bilan, verdicts = parse(lines)
    costs = unit_costs(r4)
    ok = True
    if bilan is None:
        ok = False
        out.append("[FO-IA1-R4] %s : ECHEC aucun BILAN au journal" % name)
    else:
        out.append("[FO-IA1-R4] %s : BILAN du banc %d OK, %d ECHEC(S)" % ((name,) + bilan))
        ok = ok and bilan[1] == 0
    for v in VERDICTS:
        if v not in verdicts:
            ok = False
            out.append("[FO-IA1-R4] %s : ECHEC verdict %s absent" % (name, v))
        elif expected.get(v) is not None and verdicts[v][0] != expected[v]:
            ok = False
            out.append("[FO-IA1-R4] %s : ECHEC verdict %s : %s, attendu %s" % (name, v, verdicts[v][0], expected[v]))
        else:
            out.append("[FO-IA1-R4] %s : verdict %s : %s" % (name, v, verdicts[v][0]))
    missing = [lab for lab in LABELS if lab not in costs]
    if missing:
        ok = False
        out.append("[FO-IA1-R4] %s : ECHEC mesures absentes : %s" % (name, ", ".join(missing)))
    if not calib:
        ok = False
        out.append("[FO-IA1-R4] %s : ECHEC aucun etalon" % name)
    return ok, costs, [calib[k] for k in sorted(calib)]


def lot_max(costs_by_label):
    """Évaluation d'un lot : somme, sur les 5 appels, du maximum brut ; le pire des lots."""
    return max(sum(max(costs_by_label[lab]) for lab in labs) for labs in LOTS.values())


def report(passes, expected):
    """passes : [(nom, lignes)]. Renvoie (ok, lignes de sortie)."""
    out, ok, per = [], True, []
    for name, lines in passes:
        pok, costs, cal = check_pass(name, lines, expected, out)
        ok = ok and pok
        if cal:
            med = statistics.median(cal)
            calm = med <= CALM_MS
            out.append("[FO-IA1-R4] %s : etalon (ms) mediane %.3f, min %.3f, max %.3f : passe %s (seuil %.2f)" % (
                name, med, min(cal), max(cal), "CALME" if calm else "CHARGEE", CALM_MS))
        else:
            calm = False
        per.append((name, pok, calm, costs))
    valid = [p for p in per if p[1]]
    if not valid:
        out.append("[FO-IA1-R4] RESULTAT : ECHEC")
        return False, out
    # Coûts bruts, toutes passes valides confondues : médiane, min, max.
    out.append("[FO-IA1-R4] cout unitaire BRUT en microsecondes, %d passe(s) x repetitions : mediane, min, max" % len(valid))
    allc = {lab: [x for p in valid for x in p[3][lab]] for lab in LABELS}
    for lab in LABELS:
        xs = allc[lab]
        out.append("[FO-IA1-R4]   %-46s %7.3f %7.3f %7.3f" % (lab, statistics.median(xs), min(xs), max(xs)))
    ghost_max = max(allc[GHOST])
    revive_max = max(max(allc[lab]) for lab in REVIVES)
    pole_max = max(max(allc[lab]) for lab in POLES)
    lot_all = lot_max(allc)
    out.append("[FO-IA1-R4] maximum brut, toutes passes : fantome %.1f us ; ravivage d'une machine (assembleur, tuyau "
               "raccorde ; BORNE BASSE, gestionnaires d'equipe absents) %.1f us ; ravivage d'un POTEAU (raccorde ou isole) "
               "%.1f us ; evaluation d'un lot (somme des max, pire de lot naturel et foret dense) %.1f us" % (
                   ghost_max, revive_max, pole_max, lot_all))
    for lab in REVIVES + POLES:
        out.append("[FO-IA1-R4]   %-46s mediane %7.1f, max %7.1f us" % (lab, statistics.median(allc[lab]), max(allc[lab])))
    calm = [p for p in valid if p[2]]
    if len(calm) >= 2:
        cc = {lab: [x for p in calm for x in p[3][lab]] for lab in LABELS}
        g = max(cc[GHOST])
        r = max(max(cc[lab]) for lab in REVIVES)
        pl = max(max(cc[lab]) for lab in POLES)
        lt = lot_max(cc)
        prop = ("ghost %d, revive %d, revive_pole %d (NOUVELLE unite), lot_eval %d, street_eval %d (maximum brut de %d passes "
                "calmes : %.1f / %.1f / %.1f / %.1f us, x 1,5)") % (
            math.ceil(g * 1.5), math.ceil(r * 1.5), math.ceil(pl * 1.5), math.ceil(lt * 1.5), math.ceil(lt * 1.5), len(calm),
            g, r, pl, lt)
    else:
        prop = "NON ETABLIE (%d passe(s) calme(s) sur %d ; il en faut 2)" % (len(calm), len(valid))
    over = []
    if ghost_max > OP_UNITS["ghost"]:
        over.append("fantome")
    if revive_max > OP_UNITS["revive"]:
        over.append("ravivage d'une machine")
    if pole_max > OP_UNITS["revive"]:
        over.append("ravivage d'un POTEAU (%.0f us, %.1f x l'estimation)" % (pole_max, pole_max / OP_UNITS["revive"]))
    if lot_all > OP_UNITS["lot_eval"]:
        over.append("evaluation d'un lot")
    out.append("[FO-IA1-R4] VERDICT R4 : %s : fantome %.1f, ravivage d'une machine %.1f, ravivage d'un poteau %.1f, lot %.1f us "
               "contre 50 unites chacun ; au-dessus : %s ; proposition O.OP_UNITS : %s ; ravivages = bornes basses, a remesurer "
               "dans ia1-scale ; repli : %s" % (
                   "OUI" if not over else "NON", ghost_max, revive_max, pole_max, lot_all, ", ".join(over) or "rien", prop,
                   "aucun" if not over else "compter a part ce qui depasse (unite revive_pole) et le limiter par tick"))
    out.append("[FO-IA1-R4] RESULTAT : %s" % ("OK" if ok else "ECHEC"))
    return ok, out


SAMPLE = """   1.0 Script @__fo-autotest__/scenarios/ia1-risques.lua:1: [FO-IA1-RISQUES] VERDICT R1 : OUI : x
   1.0 Script x: [FO-IA1-RISQUES] VERDICT R2 : SE REALISE : x : y
   1.0 Script x: [FO-IA1-RISQUES] VERDICT R3 : OUI : x
   1.0 Script x: [FO-IA1-RISQUES] VERDICT R4 : MESURE : x
   1.0 Script x: [FO-IA1-RISQUES] VERDICT R5 : OUI : x
   1.0 Script x: [FO-IA1-RISQUES] VERDICT R7 : OUI : x
   1.0 Script x: [FO-IA1-RISQUES] BILAN : 40 OK, 0 ECHEC(S)
"""


def sample(calib_ms, unit_us):
    lines = SAMPLE.splitlines()
    lines.append("x: [FO-IA1-RISQUES] R4\tetalon_calib\tn=200000\trep=1\tDuration: %.6fms" % calib_ms)
    for lab in LABELS:
        n = 200 if lab.startswith(("pose", "ravivage", "retrait")) else 1000
        lines.append("x: [FO-IA1-RISQUES] R4\t%s\tn=%d\trep=1\tDuration: %.6fms" % (lab, n, n * unit_us / 1000.0))
    return lines


def selftest():
    exp = parse_expected(DEFAULT_EXPECTED)
    checks = 0
    calm1, calm2, busy = sample(2.0, 10.0), sample(2.1, 12.0), sample(4.0, 30.0)
    ok, out = report([("a", calm1), ("b", calm2)], exp)
    assert ok, out
    checks += 1
    # Coût brut 12 µs au pire des passes calmes : ghost = ceil(12 × 1,5) = 18 ; lot = 5 × 12 = 60 → 90.
    assert any("ghost 18, revive 18, revive_pole 18 (NOUVELLE unite), lot_eval 90" in ln for ln in out), out
    checks += 1
    # Lot de 60 µs au-dessus de 50 : VERDICT R4 NON.
    assert any("VERDICT R4 : NON" in ln for ln in out), out
    checks += 1
    ok2, out2 = report([("a", calm1), ("c", busy)], exp)
    assert ok2 and any("NON ETABLIE (1 passe(s) calme(s)" in ln for ln in out2), out2
    checks += 1
    small = sample(2.0, 1.0)
    ok3, out3 = report([("a", small), ("b", small)], exp)
    assert ok3 and any("VERDICT R4 : OUI" in ln for ln in out3), out3
    checks += 1
    ok4, out4 = report([("a", [ln for ln in calm1 if "VERDICT R3" not in ln])], exp)
    assert not ok4 and any("verdict R3 absent" in ln for ln in out4)
    checks += 1
    ok5, _ = report([("a", [ln.replace("40 OK, 0 ECHEC", "39 OK, 1 ECHEC") for ln in calm1])], exp)
    assert not ok5
    checks += 1
    ok6, out6 = report([("a", [ln for ln in calm1 if "ravivage_tuyau_raccorde" not in ln])], exp)
    assert not ok6 and any("mesures absentes" in ln for ln in out6)
    checks += 1
    # Un verdict qui change (R1 passé à NON, R2 à NE SE REALISE PAS) fait échouer (vérification m3).
    ok7, out7 = report([("a", [ln.replace("VERDICT R1 : OUI", "VERDICT R1 : NON") for ln in calm1])], exp)
    assert not ok7 and any("verdict R1 : NON, attendu OUI" in ln for ln in out7), out7
    checks += 1
    ok8, out8 = report([("a", [ln.replace("SE REALISE", "NE SE REALISE PAS") for ln in calm1])], exp)
    assert not ok8 and any("attendu SE REALISE" in ln for ln in out8), out8
    checks += 1
    print("[FO-IA1-R4] autotest : %d OK" % checks)
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("chemins", nargs="*", help="dossiers fo-autotest ou benchmark.log, une passe chacun")
    ap.add_argument("--attendu", default=DEFAULT_EXPECTED, help="verdicts attendus, ex. " + DEFAULT_EXPECTED)
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if not a.chemins:
        ap.error("au moins un chemin requis")
    passes = [(os.path.basename(os.path.normpath(p)) if os.path.isdir(p) else p, read_log(p)) for p in a.chemins]
    ok, out = report(passes, parse_expected(a.attendu))
    print("\n".join(out))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
