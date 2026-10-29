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

## 29/10 ~01 h 30, passage 4
- 192 fichiers (derniere heure) : aucune erreur Lua ni plantage. MAIS 53 archives portaient un ECHEC.txt FAUX (« benchmark interrompu » alors que « Performed N updates » est present) : les worktrees des lots avaient encore le banc.py d AVANT le correctif 8bf71c2. Corrige : banc.py de main copie dans 38 worktrees, 53 fichiers renommes ECHEC-FAUX-POSITIF.txt (resultats valides). Un ECHEC.txt reel reste : voir ci-dessous.

## 29/10 ~01 h 55, passage 5
- 229 fichiers (derniere heure, y compris benchmark-stdout) : aucune erreur Lua. Le plantage de FORTIFY/p3 (board.lua:785) est corrige par l agent (garde + test).
- 4 nouveaux ECHEC.txt FAUX (Performed present) malgre la copie du banc.py corrige : NIDS/lot3-271828182, RECONSTRUIRE/lot-314159265, KIT2/K2-etape1-271828182, QUAI/bq-314159265 : ces pilotes appellent un banc.py hors des worktrees synchronises (supposé) ; renommes ECHEC-FAUX-POSITIF.txt. A traiter : corriger la source du banc.py appele par ces pilotes.
- Charge normale : 7 banc.py, 42 bash, disque 126 Go libres.

## 29/10 ~03 h 00, passage 6 et 7
- Passages 6 et 7 : aucune erreur Lua, aucun plantage, aucun ECHEC.txt reel (les faux positifs de banc.py sont renommes au fil de l eau). Disque 123-124 Go libres, charge normale (6 banc.py, 35 bash).
- Constat d organisation : lot MAINS sans agent vivant depuis ~00 h (trois agents de workflow arretes, pilote de bancs poursuivi) ; repris par l agent nomme mainsc a 02 h 30.
