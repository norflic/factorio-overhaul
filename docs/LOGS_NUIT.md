# Relectures des logs (nuit du 28/10, ordre du DC)

Une section par passage (cron 17 et 47 de chaque heure). Script : scratchpad/scan_logs.py <heures>.

## 28/10 ~23 h 40, passage 0
- 337 fichiers (benchmark.log.gz, create.log, ECHEC.txt) des archives des 6 dernières heures : aucune erreur Lua, aucun « attempt to », aucune trace de pile, aucun ECHEC.txt.
- Limite : le motif ne voit pas les comportements erratiques sans erreur (boucles de tâches, fer gardé en inventaire) ; ils se lisent dans [FO-FONCTION] et les lots MAINS/REFILL de la nuit.

## 28/10 ~23 h 55, passage 1
- 39 fichiers de la derniere heure : aucune erreur Lua, aucun plantage, aucun ECHEC.txt. Machine : 3 jeux de test (3 places pleines), 7 processus banc.py, 39 bash, 5 sleep : charge normale, aucun parasite orphelin.

## 29/10 ~00 h 30, passage 2
- 52 fichiers de la derniere heure : aucune erreur Lua, aucun plantage, aucun ECHEC.txt (le faux ECHEC code 12 de banc.py est corrige depuis 8bf71c2).
- Incident mesure : disque F: PLEIN (0 octet libre) vers 23 h 55-00 h 10 : 94 worktrees (~650 Mo) + snapshots src-* ; nettoye (130 Go libres). Des archives de cette fenetre peuvent etre tronquees : a verifier avant lecture.
- Machine : 1 jeu de test pour 8 processus banc.py (places sous-utilisees apres le blocage disque), 68 bash (agents) : a surveiller. Doublon d agent RESEAU (clone) repere par ses commits et ses pilotes ; pilotes tues, lignes separees (--qui RESEAUC).

## 29/10 ~00 h 55, passage 3
- 208 fichiers (derniere heure, motifs elargis : Lua error, warning, ERREUR, ECHEC DU BANC) : aucune occurrence. Disque 130 Go libres, 12 processus banc.py (11 tickets en file, 3 places pleines), 58 bash : charge normale.
- Point de vigilance (supposé) : deux tickets du meme nom RESEAUV dans la file (instance autoritaire et relecteur reseauv) ; consigne donnee a reseauv de ne plus lancer de ticket du lot.
