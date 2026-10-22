"""Mutations de l'étape 5 de run_d4m.py (atlas attendus selon les réglages déclarés par le journal).

    python -B tools/autotest/tests/mut_atlas.py --logs <racine>/fo-logs --out <dossier jetable>

Copie quelques visual.log archivés dans <out>/<cas>/visual.log (témoins intacts et mutants), puis passe chaque copie
à run_d4m.verifie_journal : un témoin doit être conforme, un mutant doit être refusé. Les archives ne sont que LUES
(ce sont des preuves) ; seul <out> est écrit, et il doit être hors de <logs>/*/ (sinon l'étape 5 lirait les mutants).
Code de sortie 0 si chaque cas donne le verdict attendu.
"""
import argparse
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import run_d4m  # noqa: E402  (même dossier ; aucun effet à l'import)

HAUTE = "2026-10-22_D4m_2-haute-mesure"
HAUTE_P1 = "2026-10-21_P1_vitrine-exemple-final"
NORMALE = "2026-10-22_D4m_4-normale-mesure"
PLANCHER = "2026-10-22_D4m_5-plancher-mesure"


def sans_ligne(motif, rang=0):
    """Mutation : retire la rang-ième ligne qui contient motif."""
    def f(lines):
        hits = [i for i, ln in enumerate(lines) if motif in ln]
        assert len(hits) > rang, "motif %r absent" % motif
        return lines[:hits[rang]] + lines[hits[rang] + 1:]
    return f


def remplace(ancien, nouveau, rang=0):
    """Mutation : remplace ancien par nouveau dans la rang-ième ligne qui le contient."""
    def f(lines):
        hits = [i for i, ln in enumerate(lines) if ancien in ln]
        assert len(hits) > rang, "motif %r absent" % ancien
        out = list(lines)
        out[hits[rang]] = out[hits[rang]].replace(ancien, nouveau, 1)
        return out
    return f


def double_ligne(motif):
    """Mutation : répète la première ligne qui contient motif (un atlas de plus, même signature)."""
    def f(lines):
        i = next(i for i, ln in enumerate(lines) if motif in ln)
        return lines[:i + 1] + [lines[i]] + lines[i + 1:]
    return f


def insere_apres(motif, ligne):
    """Mutation : insère ligne après la première ligne qui contient motif."""
    def f(lines):
        i = next(i for i, ln in enumerate(lines) if motif in ln)
        return lines[:i + 1] + [ligne] + lines[i + 1:]
    return f


# (cas, journal source, mutation ou None, verdict attendu : True = conforme)
CAS = [
    ("temoin-haute", HAUTE, None, True),
    ("temoin-haute-p1", HAUTE_P1, None, True),
    ("temoin-normale", NORMALE, None, True),
    ("temoin-plancher", PLANCHER, None, True),
    # nombre d'atlas faux pour des réglages connus
    ("haute-14-sans-second-none", HAUTE, sans_ligne("[none]", 1), False),
    ("haute-14-sans-decal", HAUTE_P1, sans_ligne("[decal]"), False),
    ("haute-16-none-triple", HAUTE, double_ligne("[none]"), False),
    ("normale-13-sans-decal", NORMALE, sans_ligne("[decal]"), False),
    ("normale-13-sans-none", NORMALE, sans_ligne("[none]"), False),
    ("normale-15-none-double", NORMALE, double_ligne("[none]"), False),
    ("plancher-13-sans-icone", PLANCHER, sans_ligne("[icon,"), False),
    # bon total, mauvaise composition : le second « [none] » devient un « decal » (15 atlas, 1 seul « [none] »)
    ("haute-15-un-seul-none", HAUTE, remplace("[none]", "[decal]", 1), False),
    # réglages déclarés qui ne correspondent pas au contenu
    ("haute-declaree-normale", HAUTE, remplace("[Graphics quality: high]", "[Graphics quality: normal]"), False),
    ("normale-declaree-haute", NORMALE, remplace("[Graphics quality: normal]", "[Graphics quality: high]"), False),
    ("plancher-sans-atlas-virtuel", PLANCHER, sans_ligne(run_d4m.VIRTUEL), False),
    ("normale-avec-atlas-virtuel", NORMALE, insere_apres("[icon-background", "   2.518 Created virtual atlas pages 4096x4096x9"),
     False),
    # réglages absents ou non étalonnés
    ("normale-memoire-medium", NORMALE, remplace("[Video memory usage: all]", "[Video memory usage: medium]"), False),
    ("haute-dxt-none", HAUTE, remplace("[DXT: high-quality]", "[DXT: none]"), False),
    ("sans-ligne-graphics-options", HAUTE, sans_ligne("Graphics options:"), False),
]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--logs", required=True, help="dossier d'archives fo-logs (lu seulement)")
    ap.add_argument("--out", required=True, help="dossier jetable des copies (vidé de ses cas puis réécrit)")
    a = ap.parse_args()
    logs, out = os.path.abspath(a.logs), os.path.abspath(a.out)
    if os.path.dirname(out) == logs:
        print("refuse : %s est un sous-dossier direct de %s, l'etape 5 lirait les mutants" % (out, logs))
        return 2
    py = [sys.executable, "-B"]
    n_ok = 0
    for cas, src, mut, attendu in CAS:
        with open(os.path.join(logs, src, "visual.log"), encoding="utf-8", errors="replace", newline="") as fh:
            lines = fh.read().split("\n")
        if mut:
            lines = mut(lines)
        d = os.path.join(out, cas)
        if os.path.isdir(d):
            shutil.rmtree(d)
        os.makedirs(d)
        lg = os.path.join(d, "visual.log")
        with open(lg, "w", encoding="utf-8", newline="") as fh:
            fh.write("\n".join(lines))
        ok, resume, ecarts = run_d4m.verifie_journal(lg, py, os.path.join(out, "_json"))
        bon = ok == attendu
        n_ok += bon
        print("%-5s %-32s attendu %-9s obtenu %-9s %s" % ("OK" if bon else "ECHEC", cas,
                                                        "conforme" if attendu else "refuse",
                                                        "conforme" if ok else "refuse", " ; ".join(ecarts)))
    print("BILAN mutations atlas : %d OK, %d ECHEC(S) sur %d cas" % (n_ok, len(CAS) - n_ok, len(CAS)))
    return 0 if n_ok == len(CAS) else 1


if __name__ == "__main__":
    sys.exit(main())
