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

| POTEAUX-UNIQUES | 4 graines tenues (paires 0,09 ; alimentes 1,16) ; 314159265 : 0 contre 69 alimentes, bifurcation par arbitrage des PNJ + annulation CAPI a 30 min (mesure) ; sceptique-pu en cours ; 2 graines de plus (987654321, 112358132) demandees | fusion si mediane >= 0,95 et <= 1 graine sur 6 sous 0,75 |
| DEFAUT CAPI (nouveau) | une CAPI annule un projet en reserve qui attend encore des materiaux (aucun progres en 30 min) : 314159265 scarlet projets 3 et 4 a 34,1 min | lot separe a ouvrir apres la vague (regle pure dans ai3_capitalisation) |

| FORTIFY | 5 graines : 0 erreur, PNJ et tourelles tenus, fer -33 % sur 314159265 et -18 % sur 123456789 a 40 min, sans gain demontre | PARQUE |
| EFFECTIF | plafond 18-19 PNJ = pas de fer au coffre apres 10 recrues a 4 min, pas une panne de la regle | CLOS ; question DC 16 |
| MAINS-CHAINE | cause du brief refutee (minerai non garde) ; 40 % des tournees de fonte partent a vide ; regle chaine_main.lua (33 OK, 25 mutants) sans gain mesurable | PARQUE par mainsc |

| POTEAUX-UNIQUES (decision 04 h 25) | criteres de fusion tenus sur 6 graines (mediane alimentes 1,34 ; paires 0,11) MAIS sceptique-pu : NON VALIDE : connectivite en baisse non mesuree par les criteres (poteaux hors reseau de la centrale 15,0 % contre 9,4 %, ilots 109 contre 90, shift_pole bloque 15 fois contre 2 : sans poteaux redondants un poteau gene ne peut plus bouger) ; « alimentes » confond capacite de la centrale et poteaux ; 123456789 -26 % = panne de centrale | PARQUE ; le DC veut « autre voie, pas de redondance » : a reprendre avec shift_pole + critere de connectivite (composantes, poteaux hors service) |

| PLANDIR-SURE (FUSIONNE 04 h 50) | 2 sceptiques valides ; PNJ inertes m60 29,5=29,5 ; migration des bras (bras_retour, micro-banc plandir-retour 12 OK, etat herite reproduit, pas une vraie sauvegarde) ; content 331 OK | version 0.6.8, tag jouable-0.6.8, branche jouable deplacee |
| PANEL | Kills/Pertes corriges (panel-kills 11 OK, ia1-gui 52 OK sans set_*_count), tests verts ; etape1-guide 4 graines non rejoue apres correction | attend verdict visuel du DC (question 10) ; rejeu 4 graines demande a panel |
| CAPI-ANNUL (nouveau) | agent capi-annul : regle « aucun progres en 30 min » vs projet en reserve qui attend des materiaux | en cours |

| PANEL (05 h 17) | serie v2 : 0 ligne differente sur 4 graines ([FO-FONCTION] 398/398, 380/380, 402/402, 390/390 ; guide idem), 17 OK x8, cout 0,0005 ms/tick ferme et 0,012 ms/tick ouvert (sans --seul) ; Kills/Pertes justes (panel-kills 11 OK, ia1-gui 52 OK) | NON fusionne : design = verdict du DC (captures-DC\ 8 images, question 10) ; reste : cout --seul, captures EN, rechargement de sauvegarde |
| RECON (veille) | ERREUR DE PILOTAGE : recon-2 travaillait (silence = pas de message, pas d absence de travail) ; essai 2 livre 4c67927 : veille_test 45 OK (17 mutants), moteur simule 156 OK, war_test 104 OK 1 ECHEC (sensibilite de trajectoire, constante non reglee) | ROUVERT 09 h : 8 parties (4 graines, lot contre veille-temoin) |

| CAPI-ANNUL (05 h 50) | defaut NON reproduit sur main (14 parties, 7 graines : 41=41 projets finis, rapports 1,00 car journaux identiques) ; cas 314159265 venait du code poteaux-uniques ; defaut voisin 1 graine sur 7 (123456789 scarlet : ordre annule a 32 min, chantier a 0 entite posee pendant 28 min, cause non etudiee) | PARQUE (regle ordre_progres.lua sur la branche capia) |
| OUTILLAGE-OUTILS (FUSIONNE 05 h 50) | outils seulement : fenetres, sans_fenetre, gels, lot_compare ; test_gels 16, lot_compare 9, sans_fenetre 28, test_banc_file 96 OK | main, version jeu inchangee 0.6.8 |

| KIT-A (FUSIONNE 06 h, version 0.6.9) | approuve avant (K2 tout vert sauf ia1-scale, defaut anterieur : 19/30 aussi sur main a2ccb0f) ; re-controle apres fusion avec 0.6.8 : content 331 OK, kit-egal 19 OK, etape1-guide 18 OK sur 20261020 et 1618033988, 0 erreur Lua ; tests hors jeu verts (kit 56, kit_moteur 28, levels 1690, iag 202...) | tag jouable-0.6.9, branche jouable deplacee |

| POTEAUX-V2 (06 h 35) | ECHEC 5 criteres sur 6 graines (hors reseau 0,317 contre 0,195 ; ilots 358 contre 233 ; raccordes/poses 0,89x ; paires 0,79 contre 0,60 vise ; 3 graines sur 6 sous 0,75) ; lot sautant 99 poteaux (~5 %), trop peu pour -40 % de paires ; metriques dominees par equipes sans centrale a 60 min (4/18 lot, 3/18 temoin) | PARQUE sans essai (bruit de 6 parties > effet) ; pistes : juger par equipe a centrale vivante sur 12 graines, ou corriger la cause des doublons au plan |
| PERTE DE CENTRALE a 50-60 min (nouveau) | 3 a 4 equipes sur 18 sans generateur a 60 min (ex. scarlet 20261020 : 762 kW a 50 min puis 0), cause non etablie (attaque supposee) | diagnostic lecture seule demande a plan-directeur sur les archives existantes |

| INSTRUMENT-CENTRALE (FUSIONNE 07 h 40, version 0.6.10) | A/A : 0 ligne differente sur 2 graines (jusqu a 1316 lignes) ; 0 erreur Lua sur 6 parties ; 1re mesure d une mort de centrale : 20261020 azure 58,6 min, chaudiere et pompe tuees par un small-biter a 1-2 tuiles, QG a 66 tuiles, AUCUNE tourelle a moins de 25 tuiles (mesure) ; content 331 OK | tag jouable-0.6.10 ; rejeu de 5 graines avec journal demande |

| CENTRALE-PERTE (07 h 57) | 9 parties avec journal : 19 lignes, 7 incidents sur 25 equipes (12 % hors graines choisies), tous « small » (6 small-biter, 1 small-spitter), 5 sur 7 SANS tourelle armee a moins de 25 tuiles, sites a 59-119 tuiles du QG (mediane 75), aucun a moins de 23 tuiles | lot CENTRALE-GARDE lance (plan-directeur) : K tourelles armees a portee de la centrale, scenario provoque + 6 graines |

| AUDIT DU 29/10 08 h 40 (wf_78236b79-ba7) | sur 15 remarques de D-26 : 1 dans main et prouvee (bras de centrale), 8 parquees, 5 sans code ; documents rattrapes (REPRISE, OBJECTIFS, RD_LOG, changelog 0.6.9) | rapport au DC |

| RECON (veille) (09 h 40) | 8 parties valides, 0 erreur Lua. TENUS : pertes 0/19, secteurs reconnus 4 graines sur 4 >= temoin (230/179, 289/257, 319/242, 389/382), fer 0, ouvrier absent 1,7 min. NON TENUS : departs 0,40 par faction et par 10 min (0,5 vise), defense 4 cas sur 8 (3 attaques de plus vers le joueur ; PNJ equipe 271828182 : 11 contre 25 a 60 min, cause deduite : decalage de trajectoire). Issues : 26 % fini, 32 % fuite, 26 % rien, 16 % chemin. 10 433 refus « tache prenable » alors que des PNJ libres existent (K5) | PARQUE apres 2 essais ; piste : « PNJ libres en surplus » ; war_test rouge consigne (sensibilite de trajectoire) |

| CENTRE-FUSEE (29/10 09 h 45) | verdict du DC sur les planches : « ça ne suit pas ce que j'avais demandé » : le centre doit etre la FUSEE de depart (epave, reparation, amelioration par ages, IA dispo d'emblee) ; le kit F5 (hotel de ville) est a refaire | lot lance : brief de design + premier jet (epave, repare, ages 4 / 8 / 15), validation du DC avant les 15 ages |

| CENTRE-FUSEE : forme tranchee (09 h 55) | le DC : « Vaisseau couche, long » (horizontal, plus long que large : nez, coque, reacteurs a l arriere ; les ages ajoutent ailes, tours et modules le long de la coque) ; il avait refuse l hotel de ville du kit F5 | agent centre-fusee : brief + premier jet 5 etats sur cette forme |

## Vague CORR (29/10 11 h 20) : corrections des remarques du DC, versions simples (wf_5db5c5ed-6e1)
| Lot | Branche | Preuve visee |
|---|---|---|
| RESEAU | corr-reseau | scenario provoque : courant revenu apres destruction de la centrale ou du pivot, absent sans la regle |
| RECONSTRUIRE | corr-reconstruire | micro-banc reconstruire-infra + A/A prime des 3 graines en echec |
| SOLDATS | corr-soldats | scenario : 25 soldats inactifs + champ de nids a 60 tuiles : expedition avec la regle, rien sans |
| FOURS (refill + mains) | corr-fours-mains | passages de refill sur 5 min, aucune tournee de fonte a vide sans courant |
| ENERGIE | corr-energie | demande > production : 2e centrale avec la regle, reseau sature sans |
Agents de workflow : NE JAMAIS leur ecrire (SendMessage clone) ; suivi par fo-logs/2026-10-29_CORR/<LOT>/STATUS.md. Nucleaire contre vapeur : decision du DC.

| PANEL (FUSIONNE 11 h 30, version 0.6.11) | onglet Partie de Maj+T ; 0 ecart de partie sur 4 graines ; panel-kills 11 OK, ia1-gui 7 OK, content 331 OK ; tests hors jeu verts ; design a valider par le DC | tag jouable-0.6.11 |

## Vague parallele statique (29/10 12 h 15, wf_97824227-9cd) : nouvelle methode du DC
Porte de fusion : relecture STATIQUE qui corrige + tests hors jeu rapides + UN content sur l ensemble ; plus de parties ni de statistiques. Les deux workflows CORR (wf_5db5c5ed-6e1, wf_f610afec-487) ont ete arretes et leurs tickets de banc retires ; leurs branches et rapports sont conserves.
| Lot | Branche | Base |
|---|---|---|
| RESEAU | corr-reseau | 9853511 |
| RECONSTRUIRE | corr-reconstruire | 5df9c58 |
| SOLDATS | corr-soldats | main |
| FOURS (refill + mains) | corr-fours-mains | 279c043 |
| ENERGIE | corr-energie | b2878f6 |
| RECON | corr-recon | 7ae60b4 |
| TOURELLES | corr-tourelles | main |
| STOCKAGE | corr-stockage | main |
| ESPACE (croissance + enceinte) | corr-espace | main |
| CONVOYEURS | corr-convoyeurs | main |
| CENTRE-JEU (mecanique reparation) | corr-centre-jeu | main |
| CENTRALE-GARDE | centrale-garde | d0c0b1b (plan-directeur, relecture a lancer) |
Agents de workflow : ne pas leur ecrire. Integration : je fusionne les branches valides dans une branche integration, tests hors jeu, UN content, puis main (0.6.12).

| VAGUE PARALLELE (FUSIONNEE 13 h, version 0.6.12) | 11 lots developpes puis relus en statique par des agents independants qui ont corrige (reseau, reconstruction, soldats, fours+mains, energie, reconnaissance, tourelles, stockage, espace, convoyeurs, centre-jeu) + CENTRALE-GARDE ; 4 conflits de fusion resolus a la main (requires, build.lua, outposts.lua) ; plafond iag_test de config.lua a 42 (T.wall) ; tests hors jeu verts ; content 331 OK 0 erreur Lua | tag jouable-0.6.12 |

| VAGUE 2 (FUSIONNEE 14 h, version 0.6.13) | ENCEINTE2 (segments, 1/4 du stock), GARDE-MULTI, FER-EQUIPE, BILAN + revue-globale-1 (3 defauts d'interaction corriges) + revue-globale-2 (2 couts reduits) ; 1 conflit de build.lua resolu (repair_enclosure : version segments) ; iag 227, enceinte 127, enceinte_flux 30, garde 87, reconstruction_exec 84 ; content 331 OK 0 erreur Lua | tag jouable-0.6.13 |

## Vague 3 (29/10 14 h 50) : fusionnee en 0.6.15
FONDERIES, FOREUSES, REBUILD-TOUT, DEFENSE-FRONT, GRENADES, FACTIONS-BLOQUEES : relecture statique OK (3 lots corriges par le relecteur), tests hors jeu verts, content 331 OK. Reste : rangees compactes de foreuses, equilibre fours/foreuses actif, Emeraude sans courant, Ecarlate sans electricite (cause non trouvee).

## Vague 4 (29/10 17 h 50) : fusionnee en 0.6.17
10 lots relus statiquement et fusionnes ; content 331 OK. Reste a lancer (apres verif pvp_test final) : MODE-SURVIE, MIGRATION-CHAMP, CAPI-PENURIE, CAPI-DEBIT, POTEAUX (releve paresseux).

## Nuit du 29 au 30/10 (autonomie de 10 h donnee par le DC a 22 h 40)
Places du banc : 3 (le DC ne joue plus ; remettre 1 s'il relance une partie). Plan :
1. 0.6.19 = vague 8 (SANS-GEL, PLAFOND-FOREUSES, FONDERIE-DYNAMIQUE, PORTE-BASE, NETTOYAGE-SITE, PILE-PRIORITE, ILOTS-MURS) : integrateur integ-0619 en cours ; puis content, tag.
2. 0.6.20 = retours en direct 6 a 9 (SCALE-COMPLET, ARMEE-ANTICIPATION, DETOUR-BOUCLE, COMPAGNONS-ACTIFS, RANGEES-DEBIT, MIGRATION-DECLENCHE, DEFENSE-CHOIX, ENERGIE-CROISSANCE, REBUILD-RAPIDE, TOURELLES-HORS-AXE, RECO-DIRECTION, CRAFT-PARALLELE, CHARBON-CENTRALE) : integration par lot valide + relecteur d'INTEGRATION (interactions) avant le content.
3. Apres 0.6.20 : PREVISION (un seul estimateur de menace, arbitrages du DC « comme le joueur » et « compter la defense ») ; fuites de la pile (capitalisation pendant une reparation, module rouvert contre module neuf) ; CAPI-DEBIT.
4. Fin de nuit : fumee en moteur reel de la derniere version sur 2 graines (verif-guide), journaux lus (erreurs Lua, [FO-PILE], [FO-SURVIE], [FO-ACTIF], [FO-REBUILD-RAPIDE], [FO-ENERGIE]) pour le rapport du matin.
5. Design : workflow centre v6 (16 etats Opus + critiques) et mur-opus ; planches en .html LOCAL seulement (consigne du DC : plus d'artefact).
Question DC en attente (QUESTIONS_DC.md) : extension des avant-postes au-dela de la portee des tourelles (defaut : les tourelles suivent).
- 29/10 23 h 40 : disque F: sature (3 copies robocopy de bancs en parallele + Blender + tests Lua des agents : content-0619 copie 278 Mo en 30 min) ; places ramenees a 2. Piste RESSOURCES signale qu'elle touche le bloc `crystal` de W.resources (shared/content/world.lua : teinte et eclats du minerai de cristal vers le bleu glacier, feuille M1) et laisse le decor W.decor (amas violets, sol de la plaine) a BIOMES-COULEURS : conflit possible dans world.lua a resoudre a la fusion des deux pistes.
- 29/10 23 h 45 : RESSOURCES demande si CRAFTS met en jeu les minerais d'X3 (blende/zinc age 3, cassiterite/etain age 4, bauxite/aluminium age 6, quartz age 10) ; pas de reponse (workflow), donc RESSOURCES ne touche pas X3 (son option par defaut). A lancer apres la fusion d'amelio-crafts : lot X3-MINERAIS (gisements + plaques + usages dans les chaines de CRAFTS).
- 29/10 23 h 55 : notes de fusion pour la piste AMELIO (signalees par RESSOURCES) : (1) fo-coil-winder cree deux fois (CRAFTS : C.BUILDINGS, copie assembleur 2, techno fo-electrical-steel ; X2 dans amelio-ressources : S.BUILDINGS de shared/content/superconductors.lua, copie assembleur 1, techno fo-superconductors) : data:extend ecrase sans erreur -> a la fusion garder celle de CRAFTS (age 6, X0), retirer fo-coil-winder de S.BUILDINGS et S.TECHS et ajuster superconductors_test ; (2) la torchere de CRAFTS ignore l'oxygene de X2 (fo-oxygen, fo-liquid-oxygen) : a brancher ; (3) shared/content/world.lua : sol de la plaine de cristal + W.no_vanilla_decor (BIOMES) contre « fo-black-sands » (X2) : garder les deux.
- 30/10 0 h : RESSOURCES fusionne amelio-crafts (ab2f2da6) dans amelio-ressources et y resout le doublon fo-coil-winder (garde CRAFTS), puis met en jeu cassiterite -> etain -> carte imprimee (X3). A l'integration : prendre amelio-ressources (qui contient crafts) ; ne pas fusionner amelio-crafts a part si sa tete y est deja.
- 30/10 0 h 34 -> 2 h : limite d'usage, 1 h 25 perdues pour tous les agents. A 2 h : workflows repris, integ-0619 relance (0.6.20 : reste CHARBON-CENTRALE, CRAFT-PARALLELE, RECO-DIRECTION + tests).

- 30/10 3 h 50 (integration AMELIO 0.6.22) : ecrire au changelog que dans une sauvegarde anterieure, un assembleur regle sur electrolyseur / reacteur de Kroll / concentrateur s arrete jusqu a ce qu on lui donne des bobines (CRAFTS, migration 307/24 dont 3 recettes).
