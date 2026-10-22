"""Contrôle HORS JEU du journal d'un passage du banc « ht3-migration » (suite H-T3).

Le mod de test ne peut pas lire le journal du moteur : le scénario y écrit donc ce que le journal DOIT contenir
(lignes « [FO-HT3-MIGRATION] JOURNAL ATTENDU : … »), et ce script le compare aux lignes que factorio-overhaul y a
réellement écrites (Levels.migrate_footprints, Levels.repair, filet on_nth_tick(30)) :

  1. chaque mitrailleuse laissée faute de place a exactement UNE ligne
     « [FO-LEVELS] emprise : <nom> en <x>, <y> laissé en place » ;
  2. aucune autre ligne « laissé en place » (un second passage qui rejournaliserait serait vu) ;
  3. exactement UNE ligne de bilan des emprises, de la voie attendue (« mise à jour des emprises » =
     Levels.repair par on_configuration_changed ; « emprises (filet, … » = filet), avec les mêmes nombres ;
  4. le BILAN du scénario est présent, sans échec ;
  5. (lot V3-T2, corrections) si le scénario a écrit des lignes « JOURNAL ATTENDU : message <force> <laissés>
     <doublons> » : chaque message aux joueurs (« [FO-LEVELS] message de migration à la force … ») est journalisé
     exactement une fois avec ces nombres, et aucun autre.

    python -B tools/autotest/ht3_journal.py <benchmark.log>     (ou le dossier fo-autotest\\ d'un passage)
    python -B tools/autotest/ht3_journal.py --tag FO-T2-MIGRATION <benchmark.log>   (lot V3-T2 : scénario t2-migration,
                                                                 toutes les familles ; même format de lignes)

Code de sortie : 0 si tout concorde, 1 sinon (critère d'un passage, avec le BILAN du scénario).
"""
import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # accents lisibles dans Git Bash et les journaux

DEFAULT_TAG = "FO-HT3-MIGRATION"
RE_KEPT = re.compile(r"\[FO-LEVELS\] emprise : (\S+) en (\S+), (\S+) laissé en place")
RE_MSG = re.compile(r"\[FO-LEVELS\] message de migration à la force (\S+) : (\d+) laissé\(s\), (\d+) doublon\(s\)")
RE_SUM = re.compile(r"\[FO-LEVELS\] (mise à jour des emprises|emprises \(filet, sans changement de version\)) : "
                    r"(\d+) bâtiment\(s\) reposé\(s\), (\d+) déjà en place, (\d+) laissé\(s\)")


def tag_patterns(tag):
    """Expressions des lignes du scénario de balise `tag` (sans crochets : « FO-HT3-MIGRATION », « FO-T2-MIGRATION »)."""
    t = re.escape("[" + tag + "]")
    return (re.compile(t + r" JOURNAL ATTENDU : laisse (\S+) en (\S+), (\S+)\s*$"),
            re.compile(t + r" JOURNAL ATTENDU : bilan (\d+) (\d+) (\d+) voie (repair|filet)\s*$"),
            re.compile(t + r" BILAN : (\d+) OK, (\d+) ECHEC"),
            re.compile(t + r" JOURNAL ATTENDU : message (\S+) (\d+) (\d+)\s*$"))


def check_text(text, tag=DEFAULT_TAG):
    """Renvoie (liste de (ok, libellé, détail)) pour le texte d'un benchmark.log."""
    RE_EXPECT_KEPT, RE_EXPECT_SUM, RE_BILAN, RE_EXPECT_MSG = tag_patterns(tag)
    exp_kept, exp_sum, kept, sums, bilan = [], [], [], [], None
    exp_msg, msgs = [], []
    for line in text.splitlines():
        m = RE_EXPECT_MSG.search(line)
        if m:
            exp_msg.append(m.groups())
            continue
        m = RE_MSG.search(line)
        if m:
            msgs.append(m.groups())
            continue
        m = RE_EXPECT_KEPT.search(line)
        if m:
            exp_kept.append(m.groups())
            continue
        m = RE_EXPECT_SUM.search(line)
        if m:
            exp_sum.append((int(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4)))
            continue
        m = RE_KEPT.search(line)
        if m:
            kept.append(m.groups())
            continue
        m = RE_SUM.search(line)
        if m:
            voie = "repair" if m.group(1).startswith("mise") else "filet"
            sums.append((int(m.group(2)), int(m.group(3)), int(m.group(4)), voie))
            continue
        m = RE_BILAN.search(line)
        if m:
            bilan = (int(m.group(1)), int(m.group(2)))
    res = []
    res.append((len(exp_sum) == 1, "le scenario a ecrit ses attentes (une ligne de bilan attendu)",
                "%d ligne(s) de bilan attendu, %d mitrailleuse(s) laissee(s) attendue(s)" % (len(exp_sum), len(exp_kept))))
    for name, x, y in exp_kept:
        n = sum(1 for k in kept if k == (name, x, y))
        res.append((n == 1, "%s en %s, %s : journalisee « laisse en place » une seule fois" % (name, x, y), "%d ligne(s)" % n))
    extra = [k for k in kept if k not in exp_kept]
    res.append((not extra and len(kept) == len(exp_kept),
                "aucune autre ligne « laisse en place » (%d attendue(s))" % len(exp_kept),
                "%d ligne(s) au journal%s" % (len(kept), (" ; en trop : " + ", ".join("%s en %s, %s" % k for k in extra)) if extra else "")))
    want = exp_sum[0] if exp_sum else None
    res.append((len(sums) == 1 and want is not None and sums[0] == want,
                "une seule ligne de bilan des emprises, de la voie et des nombres attendus",
                "attendu %s ; journal %s" % (
                    ("%d reposee(s), %d deja en place, %d laissee(s), voie %s" % want) if want else "?",
                    " | ".join("%d, %d, %d, voie %s" % s for s in sums) or "aucune ligne")))
    res.append((bilan is not None and bilan[1] == 0, "BILAN du scenario present et sans echec",
                ("%d OK, %d ECHEC(S)" % bilan) if bilan else "absent"))
    if exp_msg:
        for force, k, d in exp_msg:
            n = sum(1 for m in msgs if m == (force, k, d))
            res.append((n == 1, "message aux joueurs de %s (%s laisse(s), %s doublon(s)) journalise une seule fois" % (force, k, d),
                        "%d ligne(s)" % n))
        extra = [m for m in msgs if m not in exp_msg]
        res.append((not extra and len(msgs) == len(exp_msg), "aucun autre message de migration (%d attendu(s))" % len(exp_msg),
                    "%d ligne(s)%s" % (len(msgs), (" ; en trop : " + ", ".join(" ".join(m) for m in extra)) if extra else "")))
    return res


def main(argv):
    args = list(argv[1:])
    tag = DEFAULT_TAG
    if len(args) == 3 and args[0] == "--tag":
        tag, args = args[1], args[2:]
    if len(args) != 1:
        print(__doc__)
        return 2
    path = args[0]
    if os.path.isdir(path):
        path = os.path.join(path, "benchmark.log")
    with open(path, encoding="utf-8", errors="replace") as f:
        res = check_text(f.read(), tag)
    for ok, label, detail in res:
        print("%s %s : %s" % ("OK    " if ok else "ECHEC ", label, detail))
    n_ok = sum(1 for r in res if r[0])
    print("JOURNAL %s : %d OK, %d ECHEC(S)  (%s)" % ("H-T3" if tag == DEFAULT_TAG else tag, n_ok, len(res) - n_ok, path))
    return 0 if n_ok == len(res) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
