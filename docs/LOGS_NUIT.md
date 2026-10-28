# Relectures des logs (nuit du 28/10, ordre du DC)

Une section par passage (cron 17 et 47 de chaque heure). Script : scratchpad/scan_logs.py <heures>.

## 28/10 ~23 h 40, passage 0
- 337 fichiers (benchmark.log.gz, create.log, ECHEC.txt) des archives des 6 dernières heures : aucune erreur Lua, aucun « attempt to », aucune trace de pile, aucun ECHEC.txt.
- Limite : le motif ne voit pas les comportements erratiques sans erreur (boucles de tâches, fer gardé en inventaire) ; ils se lisent dans [FO-FONCTION] et les lots MAINS/REFILL de la nuit.

## 28/10 ~23 h 55, passage 1
- 39 fichiers de la derniere heure : aucune erreur Lua, aucun plantage, aucun ECHEC.txt. Machine : 3 jeux de test (3 places pleines), 7 processus banc.py, 39 bash, 5 sleep : charge normale, aucun parasite orphelin.
