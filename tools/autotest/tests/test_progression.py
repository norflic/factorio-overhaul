# -*- coding: utf-8 -*-
"""Test de tools/autotest/progression.py (lot PROGRESSION) : règles pures, lignes synthétiques, extrait réel.

Lancement : PYTHONUTF8=1 py -3.9 -B tools/autotest/tests/test_progression.py   (hors jeu, rien n'est lancé)
L'extrait réel (tools/autotest/tests/progression_extrait.txt) vient de l'archive K2-etape1-1618033988 (2026-10-28,
scénario etape1-guide, graine 1618033988) : 712 lignes [FO-FONCTION], [FO-ETAPE1-GUIDE] et autres, filtrées.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import progression as P  # noqa: E402

OK = 0
ECHECS = []


def verifie(nom, cond, detail=""):
    global OK
    if cond:
        OK += 1
    else:
        ECHECS.append(f"{nom} {detail}")


def journal_de(lignes):
    j = P.Journal()
    for ln in lignes:
        if "[FO-" in ln:
            j.ligne(ln)
    return j


def prod(minute, equipe, fer, cuivre=0.0, acier=0.0, circuits=0.0, packs=0):
    return (f"  17.5 Script @x.lua:366: [FO-FONCTION] prod minute {minute} | {equipe} | fenetre=10.0 pnj=5 morte=0 "
            f"plaques_min={fer + cuivre:.1f} fer_min={fer:.1f} cuivre_min={cuivre:.1f} brique_min=0.0 acier_min={acier:.1f} "
            f"ore_fer_min=0.0 ore_cuivre_min=0.0 charbon_min=0.0 pierre_min=0.0 engrenages_min=0.0 "
            f"circuits_min={circuits:.1f} packs_fab={packs} packs_conso=0")


# --- règles pures -----------------------------------------------------------------------------------------------
verifie("tranche 9,5 -> 10", P.tranche_de(9.5) == 10, str(P.tranche_de(9.5)))
verifie("tranche 10 -> 10", P.tranche_de(10.0) == 10, str(P.tranche_de(10.0)))
verifie("tranche 10,5 -> 20", P.tranche_de(10.5) == 20, str(P.tranche_de(10.5)))
verifie("tranche 0,5 -> 10", P.tranche_de(0.5) == 10, str(P.tranche_de(0.5)))
verifie("tranche 120 -> 120", P.tranche_de(120.0) == 120, str(P.tranche_de(120.0)))

verifie("croissance simple", P.croissance([1.0, 2.0, 4.0]) == [2.0, 2.0], str(P.croissance([1.0, 2.0, 4.0])))
verifie("croissance : precedent nul -> None", P.croissance([0.0, 5.0])[0] is None)
verifie("croissance : absent -> None", P.croissance([None, 5.0, 6.0]) == [None, 1.2], str(P.croissance([None, 5.0, 6.0])))

verifie("expo : 3 de suite", P.exponentielle([None, 1.5, 1.6, 1.7]))
verifie("expo : 2 de suite seulement", not P.exponentielle([1.5, 1.6]))
verifie("expo : suite cassee", not P.exponentielle([1.5, 1.6, 1.0, 1.5, 1.6]))
verifie("expo : 1,3 pile n'est pas au-dessus", not P.exponentielle([1.3, 1.3, 1.3]))
verifie("expo : trou None coupe la suite", not P.exponentielle([1.5, None, 1.6, 1.7]))

# --- lignes synthétiques ----------------------------------------------------------------------------------------
# croissance nette sur 4 tranches : fer x2 par tranche -> EXPONENTIELLE ; cuivre plat -> non
lignes = [prod(10, "alpha", 10, 5), prod(20, "alpha", 20, 5), prod(30, "alpha", 40, 5), prod(40, "alpha", 80, 5)]
j = journal_de(lignes)
r = P.bilan_equipe(j, "alpha", j.tranches())
verifie("expo synthetique : fer", r["exponentielle"]["fer_min"] is True, str(r["exponentielle"]))
verifie("expo synthetique : cuivre plat", r["exponentielle"]["cuivre_min"] is False)
verifie("expo synthetique : facteurs fer", r["croissance"]["fer_min"] == [2.0, 2.0, 2.0], str(r["croissance"]["fer_min"]))

# l'équipe du joueur : « VOTRE EQUIPE » (guide) et « player » (fonction) forment UNE équipe
j = journal_de([prod(10, "player", 3.0),
                "[FO-ETAPE1-GUIDE] base minute 10 | VOTRE EQUIPE | chaudieres=1 vapeur=0 poteaux=2 foreuses_elec=4 "
                "foreuses_comb=1 tapis=40 bras=0 fours=3 assembleurs=2 labos=1 coffres=2 | tech=7 palier=x n=0 | coffre_qg 0 | -"])
verifie("VOTRE EQUIPE = player", j.equipes == {"player"}, str(j.equipes))
verifie("base_elec lu sous player", j.valeur("player", 10, "base_elec") == 4.0, str(j.valeur("player", 10, "base_elec")))
verifie("tech lue sous player", j.valeur("player", 10, "tech") == 7.0)

# foreuses sur les géants : [FO-GEANTS] TOTAL
j = journal_de(["  9.1 Script @x.lua:505: [FO-GEANTS] minute 12.0 | alpha | TOTAL 3 gisement(s) 9000 tuiles | couvert elec=10 "
                "therm=5 total=15 (2 pm) | foreuses dessus elec=4 therm=2, hors geants 0 (toutes: elec=1 therm=0) | lignes=3"])
verifie("geants elec", j.valeur("alpha", 20, "fe_elec") == 4.0, str(j.valeur("alpha", 20, "fe_elec")))
verifie("geants therm", j.valeur("alpha", 20, "fe_therm") == 2.0)

# électrique : thermiques debout et électriques qui tournent (ligne avec « a X min » à la fin)
j = journal_de(["  5.0 Script @x.lua:179: [FO-ELECTRIQUE] alpha : thermiques debout 3 (chaudiere, vapeur), hors avant-postes de "
                "l'equipe 1, electriques qui tournent 7 (force), poteaux au stock 0, remplacees cette minute 0, cause du reste : "
                "rien a faire a 25.4 min"])
verifie("electrique thermiques", j.valeur("alpha", 30, "th_debout") == 3.0, str(j.valeur("alpha", 30, "th_debout")))
verifie("electrique electriques", j.valeur("alpha", 30, "el_live") == 7.0)

# zéro inactivité : équipe AVANT « minute » ; le nombre « 3 pensee(s) » ne doit pas devenir l'équipe
j = journal_de(["  7.0 Script @x.lua:266: [FO-ZERO-IDLE] alpha minute 12 | 3 pensee(s) | PNJ libres 4 sans tache + 1 au fond "
                "(PNJ-pensees) | agrandissements emis 2 {x} | restes sans agrandissement 0 | cause c | manque {}"])
verifie("zero-idle : equipe", j.equipes == {"alpha"}, str(j.equipes))
verifie("zero-idle : PNJ libres", j.valeur("alpha", 20, "pnj_libres") == 4.0, str(j.valeur("alpha", 20, "pnj_libres")))

# projets de liaison : comptés ; tuiles de tapis sommées ; une ligne sans minute suit la dernière minute vue
j = journal_de([prod(10, "alpha", 1.0),
                "  8.0 Script @x.lua:529: [FO-LIAISON] alpha : projet 3 planifie (quai (1, 2), x) : 12 tuile(s) de tapis "
                "posees, 2 bras, 2 poteau(x), de la sortie (1, 2) au quai (3, 4), 0 obstacle(s)"])
verifie("liaison : compte", j.compte("alpha", 10, "liaison") == 1, str(j.compte("alpha", 10, "liaison")))
verifie("liaison : tuiles", j.compte("alpha", 10, "tuiles_liaison") == 12, str(j.compte("alpha", 10, "tuiles_liaison")))

# --- extrait réel -----------------------------------------------------------------------------------------------
EXTRAIT = os.path.join(HERE, "progression_extrait.txt")
rap = P.analyser(EXTRAIT)
equipes = {e["equipe"]: e for e in rap["equipes"]}
verifie("extrait : 712 lignes", rap["lignes"] == 712, str(rap["lignes"]))
verifie("extrait : 3 equipes", set(equipes) == {"player", "azure", "scarlet"}, str(sorted(equipes)))
verifie("extrait : 6 tranches", rap["tranches"] == [10, 20, 30, 40, 50, 60], str(rap["tranches"]))
verifie("extrait : fer player t10", equipes["player"]["tranches"][0]["fer_min"] == 109.9,
        str(equipes["player"]["tranches"][0]["fer_min"]))
verifie("extrait : scarlet cuivre EXPONENTIELLE (demarrage x5, x1,62, x1,95)",
        equipes["scarlet"]["exponentielle"]["cuivre_min"] is True)
verifie("extrait : scarlet packs non EXPONENTIELLE", equipes["scarlet"]["exponentielle"]["packs_fab"] is False)
verifie("extrait : azure tapis t60", equipes["azure"]["tranches"][5]["tapis_fn"] == 365.0,
        str(equipes["azure"]["tranches"][5]["tapis_fn"]))
verifie("extrait : inventaire FONCTION 390", rap["inventaire"]["FONCTION"] == 390, str(rap["inventaire"]["FONCTION"]))
verifie("extrait : aucun geant ni electrique dans l'extrait", equipes["player"]["tranches"][0]["fe_elec"] is None)

print(f"[PROGRESSION] BILAN : {OK} OK, {len(ECHECS)} ECHEC(S)")
for e in ECHECS:
    print("  ECHEC " + e)
sys.exit(0 if not ECHECS else 1)
