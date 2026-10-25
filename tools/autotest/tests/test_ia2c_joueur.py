#!/usr/bin/env python3
"""Contrôles hors jeu de tools/autotest/ia2c_joueur.py (lot IA2-c) : lecture des lignes, 1re attaque, côté, M4."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import ia2c_joueur as J  # noqa: E402

ok, ko = 0, 0


def check(cond, msg):
    global ok, ko
    if cond:
        ok += 1
    else:
        ko += 1
        print("  ECHEC : " + msg)


LINES = [
    "  1.2 Script @__fo__/x.lua:1: [FO-PVP] declaration tick 72000 scarlet (grace)",
    "[FO-PVP] eclaireur tick 64000 scarlet : part vers (0, 0) (depart), secteurs connus 0",
    "[FO-PVP] eclaireur tick 66000 scarlet : arrive (0, 0), 20 secteurs a regarder",
    "[FO-PVP] attaque tick 93600 scarlet -> joueur : 20 soldats vers (-90, 10), defense estimee 8, besoin 13, tech 1, octant 2, cote 0 sur 8, direct 7, style equilibre, tempo 1043",
    "[FO-PVP] rassemblement tick 95000 scarlet -> joueur : go, defense vue 8 (depart 8), force 22, 20 soldats, octant 2",
    "[FO-PVP] issue tick 96000 scarlet -> joueur : repoussee, 20 envoyes, 5 survivants, octant 2, vivants 5",
    "[FO-PVP] attaque tick 130000 scarlet -> joueur : 21 soldats vers (-90, 10), defense estimee 23, besoin 25, tech 1, octant 3, cote 4 sur 16, direct 7, style tortue, tempo 900",
    "[FO-PVP] attaque tick 100000 azure -> joueur : 13 soldats vers (-80, 20), defense estimee 8, besoin 13, tech 0",
    "[FO-PVP] modele tick 90000 scarlet : style tortue (avant equilibre) : secteurs vus 1, tourelles vues 3, croissance 0, etendue 0, coups recus 0, attaques repoussees 0",
    "[FO-STRAT] rassemblement tick 50000 azure -> emerald : renonce, defense vue 60 (depart 10), force 20, 15 soldats, octant 4",
    "[FO-STRAT] modele tick 50000 azure -> emerald : style tortue (avant inconnu) : avant-postes vus 2",
    "[FO-STRAT] issue tick 51000 azure -> emerald : renonce, 15 envoyes, 15 survivants, octant 4, vivants 15",
]

r = J.run_metrics(LINES)
check(r["attacks"] == 3, "3 attaques contre le joueur (%s)" % r["attacks"])
check(abs(r["first_min"] - 26.0) < 1e-9 and r["first_key"] == "scarlet", "1re attaque 26,0 min, Écarlate (%s)" % r["first_min"])
check(r["side_cases"] == 2 and r["side_free"] == 1, "côté : 2 attaques face à une défense, 1 par un côté libre")
check(abs(r["side_ratio"] - 0.125) < 1e-9, "ratio moyen (0 et 0,25) = 0,125 (%s)" % r["side_ratio"])
check(r["m4_cases"] == 1 and r["m4_learned"] == 1, "M4 : la suivante change d'octant et grossit")
check(r["rally_player"] == {"go": 1, "renonce": 0} and r["rally_rival"] == {"go": 0, "renonce": 1}, "rassemblements")
check(r["scouts"].get("part vers") == 1 and r["scouts"].get("arrive") == 1, "éclaireurs")
check(r["player_styles"] == {"scarlet": "tortue"}, "style du joueur vu par Écarlate")
check(r["rival_style_lines"] == {"tortue": 1} and r["rival_issues"] == {"renonce": 1}, "styles et issues des rivales")
check(r["declarations"] == [(20.0, "scarlet")], "déclaration")
dup = J.run_metrics(LINES + LINES)
check(dup["attacks"] == 3, "lignes répétées (create.log + benchmark.log) comptées une fois")
check(J.learned_player([(0, "a", 10, 0, 0, 1), (10, "a", 10, 0, 0, 1)], [(5, "a", "repoussee")]) == (1, 0),
      "M4 : même secteur, même octant, même taille : pas appris")
check(J.learned_player([(0, "a", 10, 0, 0, 1), (10, "a", 13, 0, 0, 1)], [(5, "a", "aneantie")]) == (1, 1),
      "M4 : 1,3 × plus grosse : appris")
check(J.learned_player([(0, "a", 10, 0, 0, 1)], [(5, "a", "repoussee")]) == (0, 0), "M4 : sans attaque suivante, pas de cas")
g = J.group([r, J.run_metrics(LINES[3:4])])
check(g["first_sd"] == 0.0 and g["runs"] == 2, "groupe : écart-type de deux 1res attaques égales")

print("Résultat : %d OK, %d ECHEC(S)" % (ok, ko))
sys.exit(1 if ko else 0)
