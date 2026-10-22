"""Banc HORS JEU de tools/autotest/ht3_journal.py (suite H-T3) : journaux synthétiques au format réel.

    python -B tools/autotest/tests/test_ht3_journal.py      -> « BILAN : n OK, 0 ECHEC(S) », code 0

Le cas « ligne laissé en place supprimée » est la mutation relevée par le correcteur (défaut 1) : le banc en
jeu (21 OK) ne la voyait pas ; ce contrôle doit la refuser.
"""
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # accents lisibles dans Git Bash et les journaux

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import ht3_journal  # noqa: E402

P = "   1.6%02d Script @__factorio-overhaul__/script/levels/levels.lua:975: "
T = "   1.7%02d Script @__fo-autotest__/greffons.lua:38: "
GOOD = [
    P % 1 + "[FO-LEVELS] emprise : fo-lvl-gun-7 en 310, 275 laissé en place (2×2 → 3×3, aucune place libre ; gêne : [entity=stone-wall]×4)",
    P % 2 + "[FO-LEVELS] emprise : fo-lvl-gun-25 en 330, 275 laissé en place (2×2 → 6×6, aucune place libre ; gêne : [tile=water]×5)",
    P % 3 + "[FO-LEVELS] mise à jour des emprises : 5 bâtiment(s) reposé(s), 2 déjà en place, 2 laissé(s) faute de place (chevauchement toléré)",
    T % 1 + "[FO-HT3-MIGRATION] JOURNAL ATTENDU : laisse fo-lvl-gun-7 en 310, 275",
    T % 2 + "[FO-HT3-MIGRATION] JOURNAL ATTENDU : laisse fo-lvl-gun-25 en 330, 275",
    T % 3 + "[FO-HT3-MIGRATION] JOURNAL ATTENDU : bilan 5 2 2 voie repair",
    T % 4 + "[FO-HT3-MIGRATION] BILAN : 21 OK, 0 ECHEC(S)",
]

ok = fail = 0


def expect(lines, want_ok, label, tag=ht3_journal.DEFAULT_TAG):
    global ok, fail
    res = ht3_journal.check_text("\n".join(lines), tag)
    got = all(r[0] for r in res)
    bad = [r[1] for r in res if not r[0]]
    if got == want_ok:
        ok += 1
        print("OK     %s%s" % (label, (" (refuse : " + " ; ".join(bad) + ")") if bad else ""))
    else:
        fail += 1
        print("ECHEC  %s : attendu %s, obtenu %s %s" % (label, want_ok, got, bad))


expect(GOOD, True, "journal conforme (voie on_configuration_changed)")
expect([l for l in GOOD if "fo-lvl-gun-7 en 310, 275 laissé" not in l], False,
       "mutation : ligne « laissé en place » de coince7 supprimée")
expect(GOOD + [P % 9 + "[FO-LEVELS] emprise : fo-lvl-gun-7 en 310, 275 laissé en place (rejournalisée)"], False,
       "ligne « laissé en place » en double (second passage qui rejournalise)")
expect(GOOD + [P % 8 + "[FO-LEVELS] emprises (filet, sans changement de version) : 0 bâtiment(s) reposé(s), 0 déjà en place, 0 laissé(s) faute de place (chevauchement toléré)"],
       False, "seconde ligne de bilan (le filet a rejoué la migration)")
expect([l.replace("voie repair", "voie filet") for l in GOOD], False, "voie attendue = filet, journal = Levels.repair")
expect([l.replace("mise à jour des emprises", "emprises (filet, sans changement de version)").replace("voie repair", "voie filet")
        for l in GOOD], True, "journal conforme (voie du filet)")
expect([l.replace("5 bâtiment(s)", "4 bâtiment(s)") for l in GOOD], False, "nombres du bilan différents")
expect([l.replace("21 OK, 0 ECHEC", "20 OK, 1 ECHEC") for l in GOOD], False, "BILAN du scénario en échec")
expect([l for l in GOOD if "JOURNAL ATTENDU : bilan" not in l], False, "attentes du scénario absentes")
# Lot V3-T2 : balise du scénario t2-migration (--tag) ; les lignes d'une autre balise ne comptent pas.
T2 = [l.replace("[FO-HT3-MIGRATION]", "[FO-T2-MIGRATION]") for l in GOOD]
expect(T2, True, "balise FO-T2-MIGRATION (scenario t2-migration) : journal conforme", "FO-T2-MIGRATION")
expect(GOOD, False, "balise FO-T2-MIGRATION demandee, journal du scenario ht3 : attentes absentes", "FO-T2-MIGRATION")
# Lot V3-T2 (corrections, défaut 9) : message aux joueurs après la migration, journalisé par le mod.
MSG = T2 + [P % 4 + "[FO-LEVELS] message de migration à la force fo-t2 : 2 laissé(s), 0 doublon(s)",
            T % 5 + "[FO-T2-MIGRATION] JOURNAL ATTENDU : message fo-t2 2 0"]
expect(MSG, True, "message de migration attendu et journalise une fois", "FO-T2-MIGRATION")
expect([l for l in MSG if "message de migration à la force" not in l], False, "message de migration attendu mais absent", "FO-T2-MIGRATION")
expect(MSG + [P % 5 + "[FO-LEVELS] message de migration à la force fo-t2 : 2 laissé(s), 0 doublon(s)"], False,
       "message de migration en double", "FO-T2-MIGRATION")
expect([l.replace("2 laissé(s), 0 doublon(s)", "3 laissé(s), 0 doublon(s)") for l in MSG], False,
       "message de migration avec un autre nombre", "FO-T2-MIGRATION")
print("BILAN : %d OK, %d ECHEC(S)" % (ok, fail))
sys.exit(0 if fail == 0 else 1)
