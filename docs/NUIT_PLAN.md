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
