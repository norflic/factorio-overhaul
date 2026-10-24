#!/usr/bin/env python3
"""Tests hors jeu de tools/autotest/ia2_mesures.py (lot IA2-0) : outils numériques et lecture d'un journal fabriqué.

Usage : python -B tools/autotest/tests/test_ia2_mesures.py   -> « BILAN : N OK, 0 ECHEC(S) », code 0.
"""
import math
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import ia2_mesures as I  # noqa: E402

ok = fail = 0


def check(cond, msg):
    global ok, fail
    if cond:
        ok += 1
    else:
        fail += 1
        print("  ECHEC : " + msg)


def near(a, b, eps=1e-6):
    return a is not None and abs(a - b) <= eps


# Outils numériques
check(near(I.spearman([1, 2, 3, 4], [10, 20, 30, 40]), 1.0), "Spearman : suite croissante = 1")
check(near(I.spearman([1, 2, 3, 4], [40, 30, 20, 10]), -1.0), "Spearman : suite décroissante = -1")
check(I.spearman([1, 2], [1, 2]) is None, "Spearman : moins de 3 points = rien")
check(near(I.spearman([1, 2, 3], [5, 5, 9]), math.sqrt(3) / 2), "Spearman : ex æquo au rang moyen")
check(near(I.roundness(100, 100, 0), 1.0), "rondeur : disque = 1")
check(near(I.roundness(400, 100, 0), 2.0), "rondeur : 4 fois plus de variance sur x = 2")
check(near(I.roundness(250, 250, 150), 2.0), "rondeur : ellipse tournée de 45° (λ 400 et 100) = 2")
check(I.roundness(100, 0, 0) is None, "rondeur : ligne = rien (λ2 nul)")
check(near(I.entropy([0, 0, 0]), 0.0) and I.entropy([0, 0, 0]) >= 0, "entropie : un seul côté = 0 (jamais -0)")
check(near(I.entropy([0, 2, 4, 6]), 2.0), "entropie : 4 côtés égaux = 2 bits")
check(near(I.edit_distance(["a", "b", "c"], ["a", "b", "c"]), 0.0), "distance : suites identiques = 0")
check(near(I.edit_distance(["a", "b", "c", "d"], ["a", "x", "c", "d"]), 0.25), "distance : 1 substitution sur 4 = 0,25")
check(near(I.edit_distance([], ["a"]), 1.0), "distance : vide contre 1 = 1")
check(near(I.cv([10, 10, 10]), 0.0) and near(I.cv([5, 15]), 0.5), "coefficient de variation")
series = [(m, {"iron": 100, "copper": 50 if m < 5 else 10}) for m in range(0, 21)]
d = dict(I.dormant_share(series))
check(10 not in d or near(d[10], 110 / 110), "dormant : pas de fenêtre complète avant la minute 10 (ou tout dormant)")
check(near(d[20], 1.0), "dormant : stock immobile 10 min = 100 %")
series2 = [(m, {"iron": 100 + 10 * m}) for m in range(0, 21)]
check(near(dict(I.dormant_share(series2))[20], 200 / 300), "dormant : stock qui monte, part restée 10 min = min/actuel")

# Journal fabriqué : 2 factions, formes, attaques, sites, rapports par minute
P = "  1.000 Script @__factorio-overhaul__/script/faction/journal.lua:64: "
R = "  1.000 Script @__factorio-overhaul__/script/remote.lua:60: "
lines = [
    P + "[FO-STRAT] fondation tick 0 scarlet : personnalite builder, origine graine, flux 123, traits ambition=1400 prudence=950 agressivite=800 curiosite=1000 rancune=900 opportunisme=700 discipline=1200 ruse=850",
    P + "[FO-STRAT] fondation tick 0 azure : personnalite conqueror, origine graine, flux 456, traits ambition=1000 prudence=700 agressivite=1400 curiosite=800 rancune=1300 opportunisme=1200 discipline=800 ruse=900",
]
for minute in range(0, 31):
    lines.append(R.replace("remote.lua:60", "remote.lua:213") + f"[FO-AUTOTEST] ===== minute {minute} (tick {minute * 3600}) =====")
    lines.append(R + "  Scarlet Order [builder] tech 0+0 | avant-postes 0 () | fonderie 2")
    lines.append(R + f"    equipe : objectif coal | manque [] | stock iron=200 copper={60 + minute} coal=140 stone=80 steel=0 firearm=40 science1=0 | taches 1 libres 0 prises | ouvriers {{idle:8}} | livre fer {minute * 10} cuivre 0 charbon 0 minerai 0 | effectif 8/10")
    dead = minute >= 25
    lines.append(R + "  Azure League [conqueror]" + (" ANEANTIE |" if dead else "") + " tech 0+0 | avant-postes 0 () | fonderie 2")
    if not dead:
        lines.append(R + f"    equipe : objectif coal | manque [] | stock iron={300 - minute} copper=0 coal=0 stone=0 steel=0 firearm=0 science1=0 | taches 1 libres 0 prises | ouvriers {{idle:8}} | livre fer {minute * minute} cuivre 0 charbon 0 minerai 0 | effectif 8/10")
lines += [
    P + "[FO-SHAPE] tick 36060 scarlet : hq (100, 100) | batiments 20 | chunks 4 | centre (1.0, 2.0) | cov 400.0 100.0 0.0 | rayon 90 | avant-postes 1:coal:10:0,2:iron:0:20,3:copper:-30:0 | noms burner-mining-drill=4,stone-furnace=2",
    P + "[FO-SHAPE] tick 72060 scarlet : hq (100, 100) | batiments 30 | chunks 5 | centre (1.0, 2.0) | cov 400.0 100.0 0.0 | rayon 90 | avant-postes 2:iron:0:20,3:copper:-30:0,4:stone:0:-40 | noms burner-mining-drill=8,stone-furnace=2",
    P + "[FO-STRAT] attaque tick 36000 azure -> scarlet : 10 soldats, depart (0, 14), vise (100, 100), 130 tuiles, octant 5, seuil 1100",
    P + "[FO-STRAT] attaque tick 72000 azure -> scarlet : 20 soldats, depart (0, 14), vise (100, 100), 130 tuiles, octant 6, seuil 900",
    P + "[FO-STRAT] attaque tick 79200 azure -> scarlet : 30 soldats, depart (0, 14), vise (100, 100), 130 tuiles, octant 6, seuil -",
    # Lot IA2-a : champs en fin de ligne (rassemblement, règle, raid), postures du chef, issues.
    P + "[FO-STRAT] attaque tick 90000 scarlet -> azure : 6 soldats, depart (100, 114), vise (0, 0), 140 tuiles, octant 3, seuil 1012, rassemblement (-40, 40), regle -, raid",
    P + "[FO-STRAT] attaque tick 95000 scarlet -> azure : 21 soldats, depart (100, 114), vise (0, 0), 140 tuiles, octant 1, seuil 987, rassemblement (40, 40), regle variee",
    P + "[FO-STRAT] attaque tick 99000 scarlet -> azure : 22 soldats, depart (100, 114), vise (0, 0), 140 tuiles, octant 1, seuil 987, rassemblement -, regle ia0",
    P + "[FO-STRAT] issue tick 92000 scarlet -> azure : repoussee, 6 envoyes, 3 survivants, octant 3, raid",
    P + "[FO-STRAT] issue tick 97000 scarlet -> azure : aneantie, 21 envoyes, 0 survivants, octant 1",
]
DOMS = ["expansion"] * 10 + ["technologie"] * 6 + ["assaut"] * 8 + ["expansion"] * 6 + ["raids"] * 30
for k, d in enumerate(DOMS):
    lines.append(P + f"[FO-STRAT] posture tick {k * 3600 + 1} scarlet : dominante {d} (900, 60 %), 2e armee (500, 25 %), 3e raids (300, 15 %), raison territoire_a_prendre, menace 0, mult 1050, cible azure, raid -"
                 + (", changement" if k == 0 or DOMS[k - 1] != d else ""))
lines += [
    P + "[FO-STRAT] site tick 1000 scarlet iron-ore : (120, 110), 22 tuiles du QG, rang 1 sur 2 en reserve, plus proche 22 tuiles",
    P + "[FO-STRAT] site tick 2000 scarlet coal : (150, 100), 50 tuiles du QG, rang 2 sur 2 en reserve, plus proche 30 tuiles",
    "  1.0 Script @__factorio-overhaul__/script/team/team.lua:322: [FO-TEAM] scarlet : objectif atteint 'coal' a 0.5 min",
]
tmp = tempfile.mkdtemp(prefix="ia2m-")
with open(os.path.join(tmp, "benchmark.log"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
with open(os.path.join(tmp, "seed.txt"), "w", encoding="utf-8") as fh:
    fh.write("4242\n")
run = I.read_run(tmp)
s = I.faction_metrics(run["factions"]["scarlet"])
a = I.faction_metrics(run["factions"]["azure"])
check(run["seed"] == "4242" and run["minutes"] == 30, "graine et minutes lues")
check(s["personality"] == "builder" and s["traits"]["agressivite"] == 800 and s["origin"] == "graine", "fondation : personnalité, traits, origine")
check(s["outposts"] == 4 and near(s["rho"], 1.0), "radialité : 4 avant-postes connus (union des formes), ρ = 1 (plus loin à chaque fois)")
check(near(s["roundness"], 2.0) and s["chunks"] == 5, "rondeur et chunks de la dernière forme")
check(near(s["nearest_first"], 0.5) and s["sites"] == 2, "plus proche d'abord : 1 site sur 2 au rang 1")
check(a["attacks"] == 3 and near(a["first_attack_min"], 10.0), "attaques : 3, la 1re à 10 min")
check(near(a["cadence_cv"], I.cv([36000, 7200])), "cadence : CV des intervalles")
check(near(a["size_cv"], I.cv([10, 20, 30])), "tailles : CV des effectifs")
check(near(a["sides_entropy"], I.entropy([5, 6, 6])), "côtés : entropie des octants contre la même cible")
check(a["eliminated_min"] == 25 and len(run["factions"]["azure"]["stock"]) == 25, "faction anéantie : relevés arrêtés à 25 min, pas décalés")
check(len(run["factions"]["scarlet"]["stock"]) == 31, "faction vivante : 31 relevés (aucune ligne d'équipe mal attribuée)")
check(near(s["growth"], 1.0), "croissance : livraisons constantes = 1")
check(a["growth"] is None and near(a["rate_late"], (24 * 24 - 14 * 14) / 10), "croissance : faction anéantie avant 30 min = rien ; dernière fenêtre 14 à 24")
check(s["decisions"][:3] == ["site:iron-ore", "obj:coal", "site:coal"], "décisions dans l'ordre des ticks (1 000, 1 800, 2 000)")
check(near(s["reinvest_med"], (I.capital({"burner-mining-drill": 8, "stone-furnace": 2}) - I.capital({"burner-mining-drill": 4, "stone-furnace": 2})) / 100),
      "r proxy : capital gagné entre deux formes ÷ objets livrés entre les mêmes minutes")
# Lot IA2-a : chef
pe = I.entropy(DOMS)
check(s["thinks"] == 60 and s["posture_changes"] == 4 and near(s["posture_entropy"], pe), f"postures : 60 pensées, 4 changements, entropie {pe:.3f} bit")
check(near(s["changes_per_hour"], 4.0) and near(s["dominant_minutes_med"], 6.0), "stabilité : 4 changements par heure, durée médiane 6 min (séquences coupées exclues)")
check(s["raids"] == 1 and s["rule_varied"] == 1 and s["rule_ia0"] == 1 and s["with_approach"] == 2,
      "attaques : 1 raid, règle variée 1, règle d'IA0 1, 2 avec rassemblement avancé")
check(a["attacks"] == 3 and run["factions"]["azure"]["attacks"][0]["jitter"] == "1100" and run["factions"]["scarlet"]["attacks"][1]["jitter"] == "987",
      "seuil lu sans la virgule des champs ajoutés")
check(s["learn_cases"] == 2 and s["learned"] == 1, "apprentissage : 2 échecs suivis d'une attaque, 1 seul change de côté, de cible ou de taille")
check(s["issues"] == {"repoussee": 1, "aneantie": 1}, "issues lues")
per, summ = I.group_metrics([run])
check(summ["fighting120"] == [2] and summ["eliminated"] == ["azure 25 min"], "résumé : factions qui attaquent, anéanties")
check(summ["raids_total"] == [1] and summ["rule_varied_ia0"] == ["1/1"] and near(summ["learn_share"], 0.5), "résumé : raids, règles, apprentissage")
check(summ["distinct_personalities"]["scarlet"] == 1, "résumé : personnalités distinctes par couleur")
rc = I.main([tmp, "--json", os.path.join(tmp, "m.json")])
check(rc == 0 and os.path.exists(os.path.join(tmp, "m.json")), "ligne de commande : code 0, JSON écrit")

print(f"BILAN : {ok} OK, {fail} ECHEC(S)")
sys.exit(0 if fail == 0 else 1)
