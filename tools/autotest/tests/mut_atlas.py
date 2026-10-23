"""Mutations de l'étape 5 de run_d4m.py (atlas attendus selon les réglages déclarés par le journal).

    python -B tools/autotest/tests/mut_atlas.py --logs <racine>/fo-logs --out <dossier jetable>

Copie quelques visual.log archivés dans <out>/<cas>/visual.log (témoins intacts ou porteurs d'une variation sans
effet, et mutants), puis passe chaque copie à run_d4m.verifie_journal : un témoin doit être conforme, un mutant doit
être refusé. Vérifie aussi le garde-fou du dossier de sortie (cas « garde-… », sur un faux fo-logs temporaire).
Les archives ne sont que LUES (ce sont des preuves) ; seul <out> est écrit. Garde-fou : <out> ne doit être ni <logs>
lui-même (les copies <out>/<cas>/visual.log seraient alors des <logs>/*/visual.log, que l'étape 5 lit), ni un dossier
placé DANS une archive que l'étape 5 lit (<logs>/X/… avec X/visual.log : on mêlerait des mutants à une preuve). Un
sous-dossier de <logs> qui n'est pas une archive (par exemple <logs>/<suite>/d4m/mutants) est permis : ses copies sont
au moins deux niveaux sous <logs>, hors de portée de l'étape 5 (vérifié après écriture, et par les cas « garde-… »).
Code de sortie 0 si chaque cas donne le verdict attendu ; 2 si <out> est refusé.
"""
import argparse
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import run_d4m  # noqa: E402  (même dossier ; aucun effet à l'import)

HAUTE = "2026-10-22_D4m_2-haute-mesure"
HAUTE_P1 = "2026-10-21_P1_vitrine-exemple-final"
NORMALE = "2026-10-22_D4m_4-normale-mesure"
PLANCHER = "2026-10-22_D4m_5-plancher-mesure"
# Lot A2 (correction, 24/10) : journaux AVEC les icônes d'âge de la mitrailleuse et le marqueur « [FO-GUN-ICONES] »
# (trois niveaux sous fo-logs : hors de l'étape 5 de run_d4m, lus ici seulement) ; l'atlas [icon] y perd
# « linear-mip-level » en qualité normale (rangement de l'atlas, F125).
A2_HAUTE = os.path.join("2026-10-24_A2", "correction", "d4m", "1-haute-galerie")
A2_NORMALE = os.path.join("2026-10-24_A2", "correction", "d4m", "3-normale-galerie")
A2_PLANCHER = os.path.join("2026-10-24_A2", "correction", "d4m", "5-plancher-galerie")
MARQUEUR = "[FO-GUN-ICONES]"
ICONE_LML = "[icon, not-compressed, mipmap, linear-minification, linear-magnification, linear-mip-level]"
ICONE_SANS_LML = "[icon, not-compressed, mipmap, linear-minification, linear-magnification]"
# Impressions de script (format du journal : horodatage, « Script @… : », message) qui CONTIENNENT les mots d'une ligne
# du moteur : elles ne doivent compter ni comme atlas, ni comme atlas virtuel.
SCRIPT_VIRTUEL = "   1.900 Script @__factorio-overhaul__/x.lua:1: note : Created virtual atlas pages 4096x4096x9"
SCRIPT_ATLAS = "   1.901 Script @__factorio-overhaul__/x.lua:2: note : Created atlas bitmap 16384x16384 [none]"


def norme(p):
    """Chemin comparable : absolu, liens résolus, casse et séparateurs ramenés (Windows ignore la casse)."""
    return os.path.normcase(os.path.realpath(os.path.abspath(p)))


def garde_out(logs, out):
    """None si <out> est sûr pour <logs> ; sinon la raison du refus (voir l'en-tête)."""
    L, O = norme(logs), norme(out)
    if O == L:
        return ("%s est le dossier d'archives lui-meme : les copies <out>/<cas>/visual.log seraient lues par "
                "l'etape 5" % out)
    if O.startswith(L.rstrip(os.sep) + os.sep):
        archive = os.path.relpath(O, L).split(os.sep)[0]
        if os.path.isfile(os.path.join(L, archive, "visual.log")):
            return "%s est dans l'archive %s, que l'etape 5 lit : on y melerait des mutants" % (out, archive)
    return None


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


def suite(*muts):
    """Mutation composée : applique les mutations dans l'ordre."""
    def f(lines):
        for m in muts:
            lines = m(lines)
        return lines
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
    # bon total et bons « [none] », mauvaise composition des 13 autres (défaut 2 du correcteur, M1 et M2)
    ("haute-15-decal-double-sans-icone", HAUTE, suite(double_ligne("[decal]"), sans_ligne("[icon,")), False),
    ("normale-terrain-en-low-object", NORMALE,
     remplace("[terrain, mipmap, linear-minification, linear-mip-level]", "[low-object]"), False),
    # la seule variation tolérée (« linear-minification » sur [low-object]) reste étroite
    ("temoin-normale-low-object-linmin", NORMALE, remplace("[low-object]", "[low-object, linear-minification]"), True),
    ("haute-icone-sans-linmin", HAUTE, remplace("[icon, not-compressed, mipmap, linear-minification,",
                                                "[icon, not-compressed, mipmap,"), False),
    # taille des « [none] » : plancher non appliqué, ou appliqué à tort (défaut 2 du correcteur, M3)
    ("plancher-none-taille-normale", PLANCHER, remplace("2048x1316 [none]", "16384x8604 [none]"), False),
    ("normale-none-taille-plancher", NORMALE, remplace("16384x8604 [none]", "2048x1316 [none]"), False),
    # réglages déclarés qui ne correspondent pas au contenu
    ("haute-declaree-normale", HAUTE, remplace("[Graphics quality: high]", "[Graphics quality: normal]"), False),
    ("normale-declaree-haute", NORMALE, remplace("[Graphics quality: normal]", "[Graphics quality: high]"), False),
    ("plancher-sans-atlas-virtuel", PLANCHER, sans_ligne(run_d4m.VIRTUEL), False),
    ("normale-avec-atlas-virtuel", NORMALE, insere_apres("[icon-background", "   2.518 Created virtual atlas pages 4096x4096x9"),
     False),
    # impressions de script qui contiennent les mots du moteur (défaut 3 du correcteur, M4) : sans effet
    ("temoin-haute-script-virtuel", HAUTE, insere_apres("Graphics options:", SCRIPT_VIRTUEL), True),
    ("temoin-haute-script-atlas", HAUTE, insere_apres("Graphics options:", SCRIPT_ATLAS), True),
    ("plancher-virtuel-seulement-script", PLANCHER,
     suite(sans_ligne(run_d4m.VIRTUEL), insere_apres("Graphics options:", SCRIPT_VIRTUEL)), False),
    # réglages absents ou non étalonnés
    ("normale-memoire-medium", NORMALE, remplace("[Video memory usage: all]", "[Video memory usage: medium]"), False),
    ("haute-dxt-none", HAUTE, remplace("[DXT: high-quality]", "[DXT: none]"), False),
    ("sans-ligne-graphics-options", HAUTE, sans_ligne("Graphics options:"), False),
    # lot A2 : icônes d'âge de la mitrailleuse ; « linear-mip-level » de l'atlas [icon] toléré absent en normale SEULEMENT
    ("temoin-a2-haute", A2_HAUTE, None, True),
    ("temoin-a2-normale-icone-sans-lml", A2_NORMALE, None, True),
    ("temoin-a2-plancher-icone-sans-lml", A2_PLANCHER, None, True),
    # sans le marqueur du mod, l'absence du drapeau n'est plus tolérée (correction A2 : la garde la voit de nouveau)
    ("normale-icone-sans-lml-sans-marqueur", NORMALE, remplace(ICONE_LML, ICONE_SANS_LML), False),
    ("a2-normale-sans-marqueur", A2_NORMALE, sans_ligne(MARQUEUR), False),
    ("a2-plancher-sans-marqueur", A2_PLANCHER, sans_ligne(MARQUEUR), False),
    ("haute-icone-sans-lml", HAUTE, remplace(ICONE_LML, ICONE_SANS_LML), False),
    ("a2-haute-icone-sans-lml", A2_HAUTE, remplace(ICONE_LML, ICONE_SANS_LML), False),
    ("a2-normale-icone-sans-mipmap", A2_NORMALE, remplace(ICONE_SANS_LML, "[icon, not-compressed, linear-minification, "
                                                                          "linear-magnification]"), False),
    ("a2-normale-sans-icone", A2_NORMALE, sans_ligne(ICONE_SANS_LML), False),
]


def cas_garde():
    """Le garde-fou de --out sur un faux fo-logs temporaire : [(cas, attendu, obtenu, détail, (mot vrai, mot faux))]."""
    res = []
    tmp = tempfile.mkdtemp(prefix="fo-mut-garde-")
    try:
        logs = os.path.join(tmp, "fo-logs")
        os.makedirs(os.path.join(logs, "archive-a"))
        with open(os.path.join(logs, "archive-a", "visual.log"), "w", encoding="utf-8") as fh:
            fh.write("journal factice\n")
        os.makedirs(os.path.join(logs, "suite"))
        dehors = os.path.join(tmp, "dehors")
        essais = [
            ("garde-out-egal-logs", logs, False),
            ("garde-out-egal-logs-barre", logs + os.sep, False),
            ("garde-out-egal-logs-point", os.path.join(logs, "suite", ".."), False),
            ("garde-out-dans-archive", os.path.join(logs, "archive-a", "mutants"), False),
            ("garde-out-sous-logs-hors-archive", os.path.join(logs, "suite", "d4m"), True),
            ("garde-out-sous-logs-direct", os.path.join(logs, "zz"), True),
            ("garde-out-dehors", dehors, True),
        ]
        if os.name == "nt":  # Windows ignore la casse : le même dossier écrit autrement doit être refusé aussi
            essais.insert(1, ("garde-out-egal-logs-casse", logs.swapcase(), False))
            essais.insert(4, ("garde-out-dans-archive-casse", os.path.join(logs, "ARCHIVE-A", "m"), False))
        for cas, out, attendu in essais:
            raison = garde_out(logs, out)
            res.append((cas, attendu, raison is None, raison or "accepte", ("accepte", "refuse")))
        # Preuve par l'étape 5 elle-même : un <logs>/<cas>/visual.log est lu, un <logs>/zz/<cas>/visual.log ne l'est pas.
        for cas, sous, lu_attendu in (("garde-etape5-lit-profondeur-1", [], True),
                                      ("garde-etape5-ignore-profondeur-2", ["zz"], False)):
            d = os.path.join(logs, *(sous + ["cas-x"]))
            os.makedirs(d)
            lg = os.path.join(d, "visual.log")
            with open(lg, "w", encoding="utf-8") as fh:
                fh.write("mutant factice\n")
            lu = norme(lg) in set(norme(p) for p in run_d4m.journaux_archives(logs))
            res.append((cas, lu_attendu, lu, "%s par l'etape 5" % ("lu" if lu else "non lu"), ("lu", "non lu")))
            shutil.rmtree(d)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return res


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--logs", required=True, help="dossier d'archives fo-logs (lu seulement)")
    ap.add_argument("--out", required=True, help="dossier jetable des copies (vidé de ses cas puis réécrit)")
    a = ap.parse_args()
    logs, out = os.path.abspath(a.logs), os.path.abspath(a.out)
    raison = garde_out(logs, out)
    if raison:
        print("refuse : %s" % raison)
        return 2
    py = [sys.executable, "-B"]
    n_ok = n = 0
    ecrits = []
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
        ecrits.append(lg)
        ok, resume, ecarts = run_d4m.verifie_journal(lg, py, os.path.join(out, "_json"))
        bon = ok == attendu
        n += 1
        n_ok += bon
        print("%-5s %-36s attendu %-9s obtenu %-9s %s" % ("OK" if bon else "ECHEC", cas,
                                                        "conforme" if attendu else "refuse",
                                                        "conforme" if ok else "refuse", " ; ".join(ecarts)))
    for cas, attendu, obtenu, detail, mots in cas_garde():
        bon = attendu == obtenu
        n += 1
        n_ok += bon
        print("%-5s %-36s attendu %-9s obtenu %-9s %s" % ("OK" if bon else "ECHEC", cas,
                                                        mots[0] if attendu else mots[1],
                                                        mots[0] if obtenu else mots[1], detail))
    # Après écriture : aucune copie ne doit faire partie des journaux que l'étape 5 lit dans <logs>.
    lus = set(norme(p) for p in run_d4m.journaux_archives(logs))
    fuite = [p for p in ecrits if norme(p) in lus]
    n += 1
    n_ok += not fuite
    print("%-5s %-36s %s" % ("OK" if not fuite else "ECHEC", "aucune-copie-lue-par-l-etape-5",
                             "%d copie(s) lue(s) : %s" % (len(fuite), fuite) if fuite else
                             "%d copies, aucune parmi les %d journaux de l'etape 5" % (len(ecrits), len(lus))))
    print("BILAN mutations atlas : %d OK, %d ECHEC(S) sur %d cas" % (n_ok, n - n_ok, n))
    return 0 if n_ok == n else 1


if __name__ == "__main__":
    sys.exit(main())
