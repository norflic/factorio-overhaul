# TRAVERSEE : etat au redemarrage du 8/11 (16 h 15)
- Branche traversee-b2, SHA 1befdfde (dans la 0.6.68) ; ce fichier est le seul ajout non commite avant le commit suivant.
- Fait : regle pure shared/team/traversee.lua (2 phases, souterrains, gisement, poteaux, diagnostic, tranches), couche script/team/traversee.lua (lectures paresseuses et en cache, budget par projet et par tick, no_ore).
- Preuve moteur : banc ind-liaison-mur 28 OK (paire sous un mur) ; ind-liaison-gisement : paires posees (4 tuiles de gisement au lieu de 12), quai perturbe par des PNJ de la 0.6.66 (min 0).
- Tests : traversee_test 20 OK + mutants, traversee_script_test 30, bus_trace 23, bus 31, acces_champ 29, iag 480, liaison 164, poteaux_court 131 (bases precedentes).
- MANQUE 1 : cible de 5 ms par pensee non atteinte ; brancher les tranches (ctx.slice/resume, etat par projet) dans plan_drills et liaison (plan_project : etat "trace en cours").
- MANQUE 2 : banc ind-liaison-refus : la liaison n'est jamais demandee avec 168 murs en 5000 ticks (cause non cherchee) ; la ligne REFUS avec cause n'est prouvee qu'au test de script.
- MANQUE 3 : mesure en partie neuve a 60 min (CRITERES.md M1 a M4, fo-logs\2026-11-08_TRAVERSEE\).
- Risques : un gros gisement sur le trajet coute 1 a 4 M d'instructions (budget 4000 etats) ; souterrains non reserves dans le trou (un autre module peut y poser un souterrain de meme axe) ; eau sous une paire supposee passable.
