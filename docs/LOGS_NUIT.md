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

## 29/10 ~03 h 30, passage 8
- Derniere heure : aucune erreur Lua ni plantage ; aucun ECHEC.txt reel. Disque 123 Go, charge normale.
- Lecture directe des archives K2-* (kit-a) : tout vert sauf K2-ia1scale (effectif joueur 19/30 au lieu de >= 27, recrues payees 11) : temoin main demande a kit-2.

## 29/10 ~04 h, passage 9
- PLANTAGE reel (mesure) : fo-logs/2026-10-29_NUIT/RECONSTRUIRE/invalide/lot5/lot6-987654321, benchmark-stdout.txt.gz, ~42 min : reconstruction.lua:296 (pole_cands) « attempt to index local p (a userdata value) » ; deja trouve par l agent RECONSTRUIRE (archives rangees en invalide/), corrige sur la branche reconstruire (74edb3e : enumeration des prototypes par pairs sur la table du moteur, lecture protegee), rejeu lot8 en cours. Aucun effet sur main.
- Rien d autre : pas d ECHEC reel hors ces deux archives, disque 125 Go, 3 banc.py pour 3 lots, aucun factorio.exe parasite.

## 29/10 ~04 h 30, passage 10
- Rien de nouveau : seules anomalies = les 2 archives deja connues (RECONSTRUIRE/invalide/lot5-6, plantage corrige 74edb3e). Disque 137 Go. Machine au repos : 0 banc.py, 0 factorio.exe, 3 bash (file vide, 3 places libres).

## 29/10 ~04 h 55, passage 11
- Rien de nouveau : une seule ligne hors bilan, RECONSTRUIRE/invalide/lot7-987654321 (archive deja ecartee), reconstruction.lua:307 « poteau __self ecarte des remplacants » = lecture protegee de 74edb3e qui ecarte l entree __self du moteur (mesure), pas un plantage. 0 erreur Lua dans les series actives (CAPIA, PANELS). Disque 135 Go ; 2 banc.py pour 2 lots, 1 factorio.exe, 15 bash (pic normal en mesure).

## 29/10 ~05 h 25, passage 12
- Rien de nouveau : 108 fichiers lus, 0 erreur Lua, 0 ECHEC reel. Disque 136 Go. File vide (0 banc.py, 0 factorio.exe, 3 bash) : la serie 2 de CAPIA est finie ou entre deux parties.

## 29/10 ~06 h, passage 13
- Rien de nouveau : 50 fichiers lus, 0 erreur Lua, 0 ECHEC reel. Disque 136 Go. File vide (0 banc.py, 0 factorio.exe, 5 bash) : POTEAUX-V2 en phase de code et de criteres.

## 29/10 ~06 h 30, passage 14
- Rien de nouveau : 64 fichiers lus, 0 erreur Lua, 0 ECHEC reel (series INTEG 0.6.9 et POTEAUX-V2 en code 0). Disque 136 Go ; 1 banc.py pour 1 lot, 1 factorio.exe, 10 bash.

## 29/10 ~06 h 55, passage 15
- Rien de nouveau : 25 archives des 70 dernieres minutes relues (stdout et benchmark.log : Error while running, attempt to, stack traceback, non-recoverable) : 0 occurrence ; 0 ECHEC reel. Disque 136 Go ; 1 banc.py pour 1 lot, 1 factorio.exe, 7 bash. Note : /tmp/scan2.py attend maintenant un argument (ancienne version perdue) ; releve fait par boucle directe.

## 29/10 ~07 h 25, passage 16
- Rien de nouveau : 14 archives des 70 dernieres minutes relues (CENTRALE-PERTE i1-*, t0-*) : 0 erreur Lua, 0 ECHEC. Disque 137 Go ; file vide (0 banc.py, 0 factorio.exe, 3 bash).

## 29/10 ~07 h 55, passage 17
- Rien de nouveau : 12 archives des 70 dernieres minutes relues (collecte m-* de CENTRALE-PERTE, INTEG content-0610) : 0 erreur Lua, 0 ECHEC. Disque 138 Go ; file vide (0 banc.py, 0 factorio.exe, 3 bash).

## 29/10 ~08 h 30, passage 18
- Rien de nouveau : 16 archives des 70 dernieres minutes relues (CENTRALE-GARDE a-lot/a-tem, parties libres B en cours) : 0 erreur Lua, 0 ECHEC. Disque 136 Go ; 1 banc.py pour 1 lot, 1 factorio.exe, 7 bash.

## 29/10 ~09 h, passage 19
- Rien de nouveau : 18 archives des 70 dernieres minutes relues (CENTRALE-GARDE parties libres b-*) : 0 erreur Lua, 0 ECHEC. Disque 136 Go ; 1 banc.py (entre deux parties), 0 factorio.exe a cet instant, 1 blender.exe (RENDU3D, verrou de rendu, un seul), 12 bash.

## 29/10 ~09 h 35, passage 20
- Rien de nouveau : 22 archives des 70 dernieres minutes relues (CENTRALE-GARDE b-*, RECON6 lot et temoin) : 0 erreur Lua, 0 ECHEC. Disque 137 Go ; 1 banc.py pour 1 lot, 1 factorio.exe, 0 blender.exe (banc 3D fini), 7 bash. Note : le sceptique-cg1 a efface par erreur des .py du scratchpad partage (scan_logs.py, scan2.py) ; releve fait par boucle directe.

## 29/10 ~10 h 10, passage 21
- Rien de nouveau : 15 archives des 70 dernieres minutes relues (CENTRALE-GARDE c-*, d-*) : 0 erreur Lua, 0 ECHEC. Disque 137 Go ; file vide (0 banc.py, 0 factorio.exe, 0 blender.exe, 3 bash) : plan-directeur ecrit ses corrections, centre-fusee prepare son brief.

## 29/10 ~10 h 30, passage 22
- Rien de nouveau : 10 archives des 80 dernieres minutes relues : 0 erreur Lua, 0 ECHEC. Disque 136 Go ; file vide (0 banc.py, 0 factorio.exe), 1 blender.exe (CENTRE-FUSEE, verrou de rendu), 8 bash.

## 29/10 ~10 h 55, passage 23
- Rien de nouveau dans les 8 archives des 80 dernieres minutes : 0 erreur Lua, 0 ECHEC. Disque 129 Go (worktrees de la vague CORR). 5 banc.py pour 5 lots, 0 factorio.exe a cet instant. A SURVEILLER : 51 processus bash (5 agents de workflow + 5 autres agents) ; pas de rafale ; au-dela de 80 ou si le PC ralentit, mettre un lot en pause. Correction : deux horodatages d OBJECTIFS (~10 h 40 et 10 h 50) avaient ete ecrits « 11 h » par erreur.

- 29/10 ~11 h 20 : le DC demande d ouvrir la 2e place de banc (fo-banc-places.txt = 2). A remettre a 1 si le DC rejoue ou si le PC ralentit.

## 29/10 ~11 h 30, passage 24
- Rien de nouveau : 14 archives des 80 dernieres minutes relues (CENTRALE-GARDE, INTEG, CORR) : 0 erreur Lua, 0 ECHEC. Disque 128 Go ; 6 banc.py (tickets en attente de leurs lots), 0 factorio.exe a cet instant (entre deux parties), 1 blender.exe (CENTRE-FUSEE, verrou), 46 bash.

## 29/10 ~11 h 55, passage 25
- Rien de nouveau : 37 archives des 80 dernieres minutes relues (CORR, CENTRALE-GARDE) : 0 erreur Lua, 0 ECHEC. Disque 126 Go ; 6 banc.py (tickets en attente), 1 factorio.exe, 34 bash, 1 blender.exe (CENTRE-FUSEE, verrou, lance a 11 h 51 : essai de l agent apres sa passe de proprete, a verifier).

## 29/10 ~12 h 30, passage 26
- Rien de nouveau : archives des 80 dernieres minutes relues (parties arretees a 12 h 05 et CENTRALE-GARDE) : 0 erreur Lua, 0 ECHEC reel. Disque 124 Go ; plus aucune partie (methode statique), 1 blender.exe (CENTRE-FUSEE).

## 29/10 ~13 h, passage 27
- Rien de nouveau : content-0612 (integration 0.6.12) 0 erreur Lua, 0 warning du mod ; 6 archives des 90 dernieres minutes : 0 erreur ; aucune partie ni rendu en cours. Nettoyage : tous les worktrees de lots fusionnes retires (branches gardees), centre-fusee conserve.

## 29/10 ~13 h 30, passage 28
- Rien de nouveau : aucune partie ni rendu depuis 13 h (methode statique) ; archives des 90 dernieres minutes : 0 erreur Lua, 0 ECHEC. Disque 154 Go. Vague 2 et revues globales en cours (statique, aucun banc).

## 29/10 ~13 h 40, passage 29 : fumee 0.6.13
- 2 parties completes (20261020, 1618033988 ; 216300 ticks) : BILAN 18 OK, 0 erreur Lua. Journaux des nouveautes presents : [FO-BILAN] 36 lignes (lecture reelle des flux OK), [FO-CENTRALE-GARDE] 51-53, [FO-VEILLE] 35-47, [FO-TOUR-POSE] 14-16, [FO-ESPACE] 1-9, [FO-RECON] 0-4. Pas de [FO-CENTRALE-MORT] (aucune centrale perdue). Aucun journal pour soldats-expedition, convoyeurs, fer-equipe : non declenches ou muets (a verifier si le DC voit un defaut).

## 29/10 ~13 h 50, passage 30
- Lecture approfondie des 2 parties de fumee 0.6.13 (FUMEE) : 0 warning du mod, 0 erreur Lua. Centrales : sur 33 releves « centrale presente », 4 a 0 kW (azure 20261020 min 20 ; scarlet 20261020 min 20 et 30 ; azure 1618033988 min 60) : demarrages (mesure) sauf azure min 60 (cause non lue, plausiblement quai a sec : lot quai-charge jamais fusionne). Pensees : pics de 70 a 150 ms au tick 4 (initialisation capi:think / lane fo-pteam), ponctuels. Aucun refus repete anormal (lignes de bilan de blocage = une par minute et par equipe). Rien a ouvrir.

- 29/10 ~14 h : un factorio.exe sans argument tourne depuis 13 h 26 (partie du DC) : fo-banc-places.txt remis a 1, aucun banc moteur tant qu elle dure. Mes 2 parties de fumee de 13 h 33 ont tourne en meme temps que sa partie (2 places) : a ne plus faire.

## 29/10 ~14 h 20, passage 31
- Rien de nouveau : seule archive recente content-0614 (VAGUE3/INTEG) : BILAN 331 OK, 0 erreur Lua, 0 plantage. Aucune partie ni banc en cours (aucun factorio.exe, file vide, places = 1), 1 processus python sans rapport avec banc.py. Vague 3 en developpement statique (FONDERIES livre, 5 lots en cours).

## 29/10 ~15 h 10, passage 32
- Rien de nouveau : content-0615 et content-0616 (VAGUE3/INTEG) 331 OK, 0 erreur Lua, 0 plantage. Aucun factorio.exe, file des bancs vide. Workflow wf_90c72aba-bba (PRIORITE-RESSOURCES + audit capitalisation) en cours, statique, aucun banc.
