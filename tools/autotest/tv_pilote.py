#!/usr/bin/env python3
"""Lot TV-PILOTE : lecture APRES COUP du journal d'un micro-banc `tv-pilote` (scenarios/tv-pilote.lua).

Le journal du mod n'est pas lisible depuis un script du banc : on lit l'archive de banc.py (tous les .log et .txt du dossier).
Usage : py -3.9 -B tools/autotest/tv_pilote.py <archive> [--guerre-requise]
Rend 0 quand chaque maillon de chaque point est au journal, 1 sinon. Une ligne par maillon : OK / MANQUE, avec la ligne trouvee.
"""
import io
import os
import re
import sys


def lire(dossier):
    lignes = []
    for racine, _, fichiers in os.walk(dossier):
        for nom in sorted(fichiers):
            if nom.endswith((".log", ".txt")):
                chemin = os.path.join(racine, nom)
                try:
                    with io.open(chemin, "r", encoding="utf-8", errors="replace") as f:
                        for ligne in f:
                            lignes.append((nom, ligne.rstrip("\n")))
                except OSError:
                    pass
    return lignes


MAILLONS = [
    # (point, libelle, motif)
    ("W04", "journal des gardes inventoriees", r"\[FO-GARDES\] (\d+) garde\(s\) inventoriee\(s\) : (\d+) fermee\(s\) sans mesure \(refus ecrit\), (\d+) ouverte\(s\)"),
    ("D02", "kit minimal contre le compteur d'amorce", r"\[FO-AMORCE\] \S+ : kit minimal : .+ x\d+.* \| main avant la 1re production, hors liste : "),
    ("V88", "courant -> signal -> levier energie", r"\[FO-DEFAUT\] \S+ : courant -> .+ -> levier energie \("),
    ("V88", "sortie -> signal -> levier collecte", r"\[FO-DEFAUT\] \S+ : sortie -> .+ -> levier collecte \("),
    ("V88", "chantier occupe -> levier relance", r"\[FO-DEFAUT\] \S+ : chantier occupe -> .+ -> levier relance \("),
    ("V88", "cause hors table : defaut sans levier ECRIT", r"\[FO-DEFAUT\] \S+ : defaut sans levier « cause-inventee-par-le-banc »"),
    ("V10", "famille armee : part et reserve lues par le cerveau", r"\[FO-ARMEE\] \S+ : famille armee, part (\d+) pour mille ; besoins \[.+\] ; reserve \["),
    ("banc", "decision hatee, capitalisation a decide", r"\[FO-TV-PILOTE\] \S+ : defauts notes tick \d+, decision hatee tick \d+, decisions [1-9]"),
]


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    lignes = lire(argv[1])
    guerre_requise = "--guerre-requise" in argv
    manque = 0
    for point, libelle, motif in MAILLONS:
        rx = re.compile(motif)
        trouve = next(((n, l) for n, l in lignes if rx.search(l)), None)
        if trouve is None and point == "V10" and not guerre_requise:
            # sans guerre declaree il n'y a ni but de defense ni d'armee : la famille n'a rien a reserver ; on le dit sans echouer
            rx2 = re.compile(r"\[FO-ARMEE\]")
            autre = next(((n, l) for n, l in lignes if rx2.search(l)), None)
            print("%-4s %-52s %s" % (point, libelle, "ABSENT (aucune ligne [FO-ARMEE] : %s)" % ("autre ligne vue" if autre else "pas de but militaire dans la fenetre")))
            manque += 1
            continue
        if trouve is None:
            manque += 1
            print("%-4s %-52s MANQUE" % (point, libelle))
        else:
            print("%-4s %-52s OK  %s" % (point, libelle, trouve[1].strip()[:260]))
    # lignes d'avertissement : une cause du mod hors de la table, ou une garde qui plante
    for n, l in lignes:
        if "[FO-DEFAUT]" in l and "defaut sans levier" in l and "cause-inventee-par-le-banc" not in l:
            print("ATTENTION defaut reel sans levier : %s" % l.strip()[:240])
        if "script error" in l.lower() or "attempt to" in l:
            print("ERREUR %s : %s" % (n, l.strip()[:240]))
            manque += 1
    print("BILAN : %d maillon(s) manquant(s) sur %d" % (manque, len(MAILLONS)))
    return 0 if manque == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
