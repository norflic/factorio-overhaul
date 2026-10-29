# Plan de la nuit du 28 au 29/10 (D-26) : une remarque du DC, un lot

Source : retour du DC après plus de 6 h de jeu sur 0.6.7 (OBJECTIFS §5, 28/10 soir). Audit d'état en lecture seule
(14 agents, workflow wf_c1387a85-719) : aucune remarque n'est « déjà finie dans main » ; la plupart sont **écrites ou
en branche parquée**, jamais prouvées sur 4 graines. Protocole : critères écrits avant, 4 graines contre la base
`fo-logs\2026-10-28_MESURES\base-<graine>`, deux relecteurs sceptiques, fusion seulement si tout est tenu.

| Remarque du DC | État audité | Lot / agent | Décision |
|---|---|---|---|
| Relier le réseau, autre voie, pas de poteaux redondants | partiel (5 morceaux dans 6 branches, rien en main) | RESEAU-VIVANT | lancé (nuit) |
| Réparer ce qui est détruit | partiel (couverture-reco parquée, danger) | RECONSTRUIRE (agent couverture) | relancé sur main |
| Panel de stats | partiel (fenêtre IA1-i existe) | PANEL-STATS | lancé (nuit) |
| 25 soldats inactifs / nids | partiel | NIDS (factions d'abord) | lancé (nuit) ; milice du joueur : question au DC |
| Gestion de l'espace / enceinte (scénarios) | non implémenté (aucun fichier de scénario trouvé ; SCENARIO_EPOQUES.md = contenu) | ESPACE / ENCEINTE | question au DC |
| Niveaux de convoyeurs, stack | non implémenté (D-17/LOG-1 à concevoir) | TAPIS-NIVEAUX | question au DC |
| Centre de commandement vivant | partiel (confusion QG du vaisseau / centre) | CENTRE-QG | question au DC |
| Tourelles couvrantes | fait en branche (couverture, parquée) | COUVERTURE-2 | après RECONSTRUIRE et danger |
| Stockage | partiel (annexes en main) | STOCK-ECHELLE | lancé (nuit, petit) |
| Énergie / meilleure centrale | partiel (vapeur figée 1 chaudière + 2 machines) | ENERGIE (agent plan-directeur) | relancé sur plandir2 |
| Production moins consommation | partiel (rien au runtime) | BILAN | question au DC |
| Refill au maximum | défaut mesuré | REMPLISSAGE | lancé (nuit) |
| Minage à la main, fer non fondu | partiel (cas inverse traité) | MAINS-CHAINE | lancé (nuit) |

Lots d'avant la nuit encore en mesure : kit-2, leviers, améliorer, plan-directeur, equipe-joueur, recon-eclaireurs, outillage.
Parqués : layout, recon (visée), fer, couverture, couverture-reco, petrole2, adopte*, poteaux*.

## Etat de la nuit (29/10 ~03 h)
| Lot | Resultat | Decision |
|---|---|---|
| STOCK | aucun defaut de capacite a 60 min ; code inchange | rien a fusionner ; question DC n 9 |
| PANEL | onglet Partie livre (ed025f3), 0 ecart de partie, 50 OK ia1-gui | a fusionner apres sceptiques + verdict visuel DC (question n 10) |
| REFILL | C3 tenu, C1/C2/C4 non tenus de justesse ; regression equipe sur 1618033988 | parque (3 versions) |
| NIDS | lot inerte en 60 min (0 operation), ne degrade rien | parque ; vrai lot suivant : constituer la force + reconnaitre le champ de nids (apres recon-veille) |
| LEVIERS v2 | simplification (retrait du bloc), preuve mince (2 graines) | priorite basse, a completer a 4 graines |
| KIT (kit-a) | criteres tenus (15/12/12), approuve | fusion EN DERNIER apres la vague + passe d integration |
| PLANDIR-SURE | chaine 10 parties jouee | tableau attendu |
| RESEAU-VIVANT | deux lignes (RESEAUV / reseauv-code) en mesure | comparaison a la fin |
| RECONSTRUIRE | signal positif sur 1618033988, echecs programme 110 vs 17 sur une graine | en mesure |
| MAINS-CHAINE | agent repris (mainsc) apres arret des agents du workflow | analyse des temoins en cours |
| FORTIFY | plantage board.lua:785 corrige ; p4 joue | lecture attendue |
| RECON (veille) | essai 1 refuse (cout du vivier = -12 tourelles) ; essai 2 : ouvrier libre | code en ecriture |
| ENERGIE | n ajoute aucune decision | parquee |

## Etat de la nuit (29/10 ~03 h 45) : fin du workflow nuit-lots-1 (18 agents), verdicts des sceptiques
| Lot | Verdict sceptiques | Decision |
|---|---|---|
| RESEAU-VIVANT | non valide (garde du pont sans delai ; pole_chain traverse des poteaux de projets en chantier ; C1, C5b, C6 non tenus) | lot complet PARQUE ; correctif des poteaux uniques extrait en lot POTEAUX-UNIQUES (RESEAUV, mesure seule) ; la decouverte restes (corpse) + objets au sol transmise a RECONSTRUIRE |
| PANEL | non valide : colonnes Kills/Pertes INVERSEES (ia1i_stats.lua:73, prouve en moteur par un sceptique), tests circulaires (ia1-gui.lua:285-287) | agent nomme `panel` lance pour corriger (jalons dans PANEL/STATUS.md, RAPPORT2.md) ; design : verdict DC (question 10) |
| NIDS | non valide : inerte, defaut latent de chargement des nids voisins, reglage allume par defaut sans preuve | PARQUE |
| STOCK | non valide : verdict « sans defaut » contredit le critere B3 ecrit avant (fenetre de mesure, temoin de bruit apres coup) | rien a fusionner ; a rouvrir seulement si le DC le demande (question 9) |
| REFILL | non valide : valeur_test 52 OK 1 ECHEC, regression 1618033988 confirmee par A/A (QG a 16 fours) | PARQUE |
| MAINS | livraison vide (aucune mesure rendue par les agents du workflow) | repris par l'agent nomme `mainsc` |
| RECONSTRUIRE | 2 essais faits, R1 à R3 non tenus, 4 graines identiques à la base, divergence après le 1er événement, plantage corrigé 74edb3e | PARQUE (questions DC 14 et 15 : fusion malgré les écarts ? source de bois) |
| PLANDIR-SURE | criteres S1 a S5 tenus | 2 sceptiques lances (sceptique-sure1, sceptique-sure2) avant fusion |
| KIT (kit-a) | tout vert sauf ia1-scale (effectif joueur 19/30) | temoin demande a kit-2 ; fusion bloquee jusqu'a explication |
