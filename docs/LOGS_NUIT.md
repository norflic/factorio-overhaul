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

## 29/10 ~15 h 25, passage 33
- Rien de nouveau cote archives (aucune nouvelle depuis content-0616 ; file des bancs vide). La partie du DC (0.6.16, factorio.exe PID 28932) tourne : son journal vivant n'est pas aux emplacements habituels (factorio-current.log racine = 26/10, %APPDATA% = juin) : a ne pas lire a la place d'une archive ; ses retours dictes (RETOUR_DC_2 a 5) tiennent lieu de releve. 5 workflows en cours (statique) : PRIORITE, AGENCEMENT, EXTENSION-FER + REBUILD-SUIVI, POTEAUX + audit murs, audit Emeraude ; centre-fusee relance (v5).

## 29/10 ~15 h 55, passage 34
- Rien de nouveau : aucune archive de partie ou de banc depuis content-0616 (INTEG, 15 h 10) ; aucun factorio.exe, file des bancs vide. 8 lots en statique (PRIORITE, AGENCEMENT, EXTENSION-FER, REBUILD-SUIVI, POTEAUX relus ; DEFENSE-FACTIONS, SITE-PROCHE, ENCEINTE3 en dev) + centre-fusee (v5). Note outil : ne pas lancer find sur tout fo-logs (plus de 120 s).

## 29/10 ~16 h 20, passage 35
- Rien de nouveau : aucune archive de partie ou de banc depuis content-0616 (15 h 10) ; aucun factorio.exe, file vide, places = 1 (le DC joue a autre chose, une seule instance Factorio autorisee). 5 lots valides fusionnes dans integration-0617 ; AGENCEMENT, DEFENSE-FACTIONS, SITE-PROCHE, CAPI-REPLI, REBUILD-AVANT-POSTE en cours (statique) ; Blender (centre v5) tourne. Aucune erreur Lua a signaler.

## 29/10 ~16 h 50, passage 36
- Rien de nouveau : aucune archive de partie ou de banc depuis content-0616 (15 h 10) ; aucun factorio.exe, file vide, places = 1. Travail en statique (5 lots dans integration-0617, 5 en relecture/dev) ; Blender (centre v5 sessions b et c) tourne ; pvp_test lance en parallele par un agent de verification (6 processus lua, pas d'archive).

## 29/10 ~17 h 25, passage 37
- Rien de nouveau cote archives (derniere : content-0616, 15 h 10 ; aucun factorio.exe, file vide). Resultat hors jeu notable : pvp_test integration-0617 = 1305 OK, 0 ECHEC ; les 5 echecs de la 0.6.15 etaient un ecart du moteur simule (LuaEntity.burner absent de tests/mock_engine.lua, mesure par bissection des branches), pas une regression de jeu ; pvp_test entre desormais dans la porte de fusion.

## 29/10 ~17 h 55, passage 38
- content-0617 (VAGUE4/INTEG, 0.6.17) : 331 OK, 0 erreur Lua, 0 avertissement du mod. pvp_test sur main 0.6.17 = 1305 OK, 0 ECHEC (resultat final apres toutes les fusions). Aucun factorio.exe, file des bancs vide. Rien d'anormal.

## 29/10 ~18 h 20, passage 39
- Rien de nouveau : aucune archive depuis content-0617 (17 h 50, 331 OK, 0 erreur) ; aucun factorio.exe, file vide, places = 1. Vague 6 (SURVIE-PENURIE, MIGRATION-CHAMP, POTEAUX-MASQUES) en developpement statique ; centre v5 session c en rendu.

## 29/10 ~19 h, passage 40
- Rien de nouveau : aucune archive depuis content-0617 (17 h 50, 331 OK, 0 erreur) ; aucune partie ni banc ; file vide, places = 1. Vague 6 et relecture d'integration 0.6.17 en statique ; centre v5 livree (page publiee), essai 6 lance (Blender, un seul) ; mur F6 en cours.

## 29/10 ~19 h 20, passage 41
- Rien de nouveau : aucune archive depuis content-0617 (17 h 50, 331 OK, 0 erreur) ; aucune partie ni banc ; file vide, places = 1. integration-0618 (vague 6 : survie, migration, masques) : tests hors jeu verts, en attente des 3 lots d'integration (defense, economie, reconstruction) avant le content unique.

## 29/10 ~19 h 50, passage 42
- Rien de nouveau : aucune archive depuis content-0617 (17 h 50) ; aucune partie ni banc ; file vide, places = 1. Les 3 lots d'integration (defense, economie, reconstruction) sont en relecture statique ; integration-0618 attend leur fusion avant le content unique.

## 29/10 ~20 h 45, passage 43
- content-0618 (VAGUE7/INTEG, 0.6.18) : 331 OK, 0 erreur Lua. pvp_test 0.6.18 = 1305 OK. Regression trouvee a l'integration (survie_moteur_test 61/63 : commande partielle du QG sans demande de matieres, mesure par bissection) et corrigee (58b430b) avant la fusion. Aucun factorio.exe, file vide, places = 1 ; Blender (design v6, mur) tourne.

## 29/10 ~20 h 50, passage 44
- Rien de nouveau : aucune archive depuis content-0618 (331 OK, 0 erreur) ; aucune partie ni banc ; file vide, places = 1. Vague 8 + PILE-PRIORITE en statique ; design : workflow centre v6 (socle, essais carcasse) et mur-opus sur le verrou Blender ; centre-fusee et centre-opus arretes (aucun Blender a eux).

## 29/10 ~21 h 20, passage 45
- Rien de nouveau : aucune archive depuis content-0618 ; aucune partie ni banc ; file vide, places = 1. Vague 8 + PILE en statique (5 lots sur 7 avec commit) ; centre v6 : 14 etats en design sur le verrou Blender (2 places).

## 29/10 ~22 h, passage 46
- Rien de nouveau cote archives (derniere : content-0618) ; aucun banc (le DC joue, places = 1). Retours en direct du DC (RETOUR_DC_6 et _7) traites en lots : SCALE-COMPLET, ARMEE-ANTICIPATION, DETOUR-BOUCLE, COMPAGNONS-ACTIFS, RANGEES-DEBIT, MIGRATION-DECLENCHE, DEFENSE-CHOIX ; conception PREVISION ; vague 8 en relecture.

## 29/10 ~22 h 55, passage 47
- Rien de nouveau : aucune archive de banc depuis content-0618 ; file vide (3 places ouvertes, le DC ne joue plus). 0.6.19 en tests (7 lots integres, interaction ILOTS/PILE corrigee) ; retours 6-9 en relecture ; piste amelioration lancee ; centre v6 arrete sur consigne du DC.

## 29/10 ~23 h 20, passage 48
- Pas d'archive de banc terminee a lire (content-0619 et bancs de la piste amelio en cours ; 3 places prises, 2 tickets biomes en file). Sorties de bancs de la piste lues (.out BIOMES/CRAFTS) : voir lignes ci-dessus si echec. Journal de la partie du DC 0.6.18 archive par la piste dans fo-logs/2026-10-30_AMELIO/journaux-DC (factorio-current du 29/10 21 h 23).

## 29/10 ~23 h 55, passage 49
- content-0619 : 331 OK, 0 erreur Lua (2417 s : disque F: sature par 3 copies de bancs en parallele, places ramenees a 2). Aucune autre archive de banc terminee depuis (bancs de la piste amelio en cours). Aucun processus parasite ; 2 Blender (mur-opus et une piste).

## 30/10 ~0 h 20, passage 50
- 14 archives de la piste amelio/petites demandes lues : 0 erreur Lua partout ; content 331 OK sur pd-elec, pd-espacement, pd-fonderieqg, pd-intermediaires, calculs ; centre-qg 12 OK ; crafts-chaines 7 OK ; sc-journal 18 OK ; monde 116 OK.
- ANOMALIE (mesuree) : BIOMES/apres-1-captures : [FO-B0-BIOMES] 10 OK, 1 ECHEC apres le changement de couleurs des biomes (ligne ci-dessus) ; la verification de la piste doit le traiter, sinon a corriger avant fusion d'amelio-biomes (pas de message : agent de workflow).
- Snapshots src-0.6.18 des pistes : sources de migration (src-0.*), gardes.

## 30/10 ~2 h, passage 51 (reprise apres la limite d'usage)
- Limite d'usage atteinte vers 0 h 34, levee a 2 h : tous les agents se sont arretes environ 1 h 25. Les workflows (amelio, petites demandes) ont repris seuls ; integ-0619 relance par message. Verrou orphelin de la place 1 (amelio-crafts, processus 36000 mort depuis 0 h 42) : sera retire par banc.py. Aucune archive nouvelle a lire ; aucun factorio.exe.

## 30/10 ~2 h 20, passage 52
- 15 archives de la nuit (piste amelio / petites demandes) lues. Iterations de developpement, pas de version : biomes 9/2 ECHEC (avant) -> 11 OK 0 ECHEC (apres-3) : l'echec du passage 50 est corrige (mesure).
- PD-CENTRALE pd-centrale-7300-b : erreur Lua dans le SCENARIO DE BANC (greffon pd-centrale.lua:123, index de 'a' nil), pas dans le mod ; v2 a 10 OK 1 ECHEC, v3 en cours (mesure).
- CRAFTS banc-content-ab2f2da : content 355 OK, 5 ECHEC : les 5 recettes de torchere (fo-flare-brine, -chlorine, -ethylene, -hydrogen, -titanium-tetrachloride) ne produisent rien (statut 20) ; a corriger avant fusion (verification de la piste ou integrateur) (mesure).
- PD-REPARATION banc2 17/1 -> banc3 18 OK ; PD-CENTREQG migration 12/2 -> 14 OK et 13 OK. Aucune erreur Lua du mod.

## 30/10 ~2 h 55, passage 53
- 11 archives lues, 0 erreur Lua. Biomes : b0-biomes 11 OK + content 331 OK (corrige). Crafts e4 : content 370 OK, 0 ECHEC (torcheres corrigees). Centre-QG : migration 13 OK, content 331 OK.
- ANOMALIE (mesuree) : CRAFTS banc-e4-migration-content (creation 0.6.18 -> amelio-crafts) : content 307 OK, 24 ECHEC : effets des modules de VITESSE trop forts apres migration (speed-module +1.07 au lieu de +0.80 ... fo-speed-module-5 +5.55 au lieu de +2.40, conso aussi) : suppose : complement de multiplication des modules (balise D-17, MOD-1/MOD-3) applique deux fois a la migration ; a verifier sur main (meme banc en double source) avant d'accuser le lot ; bloquant pour la fusion d'amelio-crafts tant que non tranche.
- ANOMALIE (mesuree) : PD-CENTRALE v3 et v4 : 10 OK, 1 ECHEC « poteaux du projet relies a portee de fil (un seul reseau) : 1/7 » : la centrale lointaine n'est pas reliee en un seul reseau ; explo-v2 6 OK. Lot encore en iteration.

## 30/10 ~3 h 15, modules apres migration (suite du passage 53)
- CAUSE (mesuree, valeurs = produit exact 1,2^4-1 ... 1,6^4-1) : PAS un defaut de jeu. content_test pose ses 30 machines sans raise_built (non suivies par le mod sur une carte neuve : somme du moteur), puis apres une montee de version Mult.migrate (on_configuration_changed) les recense et leur pose la balise de complement : les effets se MULTIPLIENT comme le veulent D-15/D-17. Le controle du banc attendait toujours la somme. En jeu, les machines des PNJ (Mult.refresh) et du joueur (evenements de construction) sont suivies. Correctif du TEST seulement (branche corr-modules-migration : content_test juge chaque machine selon son etat suivi/non suivi, 0 ou 1 balise ; tests/modules_migration_test.lua). Temoin : 21 ECHEC (et non 24). A fusionner avec un content en double source.

## 30/10 ~3 h 25, passage 54
- 6 archives, 0 erreur Lua. Crafts e5 : content 387 OK (nouvelles recettes) ; chaines e8 : 10 OK. Centrale lointaine v5 : 11 OK, 0 ECHEC (poteaux relies en un seul reseau : corrige) + content 331 OK. Temoins de migration : 310 OK, 21 ECHEC = artefact du banc (modules non suivis), deja explique ; corrige par corr-modules-migration (test seulement). content-0620 en cours.

## 30/10 ~3 h 50, passage 55
- 9 archives (content-0620, RESSOURCES 15/16/20/21/22, CRAFTS verif x2, pd-centrale-7300), 0 erreur Lua, 0 ECHEC.txt.
- CRAFTS verif-migration-content 307 OK / 24 ECHEC : 21 « module » = defaut du TEST en double source (temoin main identique ;
  corrige par corr-modules-migration, dans la 0.6.21) ; 3 « recette fo-electrolyzer / fo-kroll-reactor / fo-ore-concentrator :
  rien produit, statut 21 » = vrai arret visible apres migration d'une sauvegarde 0.6.18 (les machines du titane demandent des
  bobines ; assembleur arrete jusqu'a ce qu'on lui en donne) [mesure, RAPPORT CRAFTS §2]. A ECRIRE au changelog de la 0.6.22.
- Processus : 41 bash (shells d'agents et workflows), aucun factorio.exe orphelin ; mur-opus : verrou de rendu orphelin retire.

## 30/10 ~4 h 25, passage 56
- 18 archives (RESSOURCES content 401 OK, PETROLE2 content 331 + petrole-court 8 OK x3 dont migration 0.6.20, PREVISION, INTEG-0621 x4, JOURNAUX-DC content 331 + journaux-dc 8 OK), 0 erreur Lua, 0 ECHEC.txt, codes 0.
- A SURVEILLER : PREVISION prev-vague passe de 6/5 a 8/3, 10/1 puis 11/0 ECHEC en 4 bancs. Verifier a la relecture que le
  code a ete corrige et non le scenario ou ses seuils (test assoupli = faute, skill §2) [supposé, a verifier dans le diff].

## 30/10 ~4 h 55, passage 57
- 4 archives (PREVISION prev-vague-final 11 OK, JOURNAUX-DC victoire 8 OK, CAPI-DEBIT content 331 + pnj-auto 7 OK), 0 erreur Lua, 0 ECHEC, codes 0. Rien de nouveau ; le point PREVISION (seuils du scenario) reste a verifier dans le diff a la fin du workflow.

## 30/10 ~5 h 25, passage 58
- 14 archives (INTEG-0622 x13, JOURNAUX relecture content 331), 0 erreur Lua, codes 0. Echecs tous expliques : migration-content 3 ECHEC (machines du titane sans bobines, connu, au changelog 0.6.22) ; sc-journal 1 ECHEC = controle du scenario perime (fumerolle desormais en jeu) corrige par l'orchestrateur, sc-journal-2 18 OK [mesure].

## 30/10 ~5 h 55, passage 59
- 10 archives (JOURNAUX relecture 8 OK, CAPI-DEBIT et FUITES-PILE content 331, BIOMES-SUIVI x7 : b0 11, monde 336, content 429, depart 3), 0 erreur Lua, codes 0.
- BIOMES-SUIVI avant-depart (420 ticks) sans BILAN : releve hors bilan seul (mesure 'avant' sur main, scenario arrete avant le controle ; rejoue a 760 ticks = 3 OK) [deduit, banc.txt + journal]. Rien a ouvrir.

## 30/10 ~6 h 25, passage 60
- 14 archives (INTEG-0623 x4, BIOMES-SUIVI x4, X3-MINERAIS x5 dont quartz-puces 10, migration 7, content 439, monde 378, PREVISION-REVUE content 331), 0 erreur Lua, 0 ECHEC, codes 0. Rien de nouveau.

## 30/10 ~6 h 55, passage 61
- 4 archives (FUITES-PILE relecture content 331, X3-MINERAIS images x2 (BILAN dans fo-shots, session avec images) + relecture content 439), 0 erreur Lua, codes 0. Rien de nouveau. X3-MINERAIS parque (Q26 : disques de plaine poses au milieu d'autres biomes).
