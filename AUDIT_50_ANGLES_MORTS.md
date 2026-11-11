# Audit : 50 angles morts du cerveau des IA (v0.7.1, 11/11/2026, 15 h)

Audit statique en lecture seule, un agent par pilier, chaque point prouvé par un `fichier:ligne` lu. Aucun point ne reprend un fait F488 à F550 de RD_LOG. Bilan : 19 points corrigés et livrés en 0.7.2 (n° 1, 6, 7, 11, 12, 13, 17, 21, 23, 24, 26, 31, 32, 33, 38, 41, 42, 43, 45), 1 écarté (n° 2), 30 à faire. Colonne « État » : **0.7.2** = corrigé, testé et livré dans la 0.7.2 ; **à faire** = documenté, non corrigé.

Format : n° · composant · faille · impact · correction proposée · état.

## Pilier 1 : macro-économie, anticipation, rétroaction

1. `script/team/plafond_charbon.lua:23-26` · toute foreuse de charbon compte dans la capacité, même à sec ou arrêtée · le plafond croit l'extraction suffisante pendant que les chaudières s'éteignent · ne compter que les foreuses qui travaillent ou ont la sortie pleine · **0.7.2**
2. `shared/team/centrale.lua:135` · la garde F491 (charge mesurée < 75 %) neutralise l'anticipation des chantiers · modules sans courant, centrale demandée trop tard · `and not n.anticipate` · écarté : contournait la règle F491 du DC (centrale sous 75 %)
3. `script/team/lots_minerai_glue.lua:162,213`, `shared/team/gisement.lua:159` · la quantité restante d'un gisement ne sert qu'au journal ; seule la mort à l'arrêt (5 min) déclenche un remplacement · 30 min et plus de trou de production · minutes restantes = quantité / débit, en manque sous N minutes · à faire (L)
4. `shared/ai3/depenses.lua:68-70` · le stock gardé suit la production, pas la consommation · la réserve part en dépenses quand la source tarit · `max(prod, conso)` · à faire (M)
5. `shared/team/gisement.lua:23,68-76` · plancher de besoin à 50 % du plus grand besoin pour toute matière · foreuses vers des minerais que rien ne consomme · plancher à 10 % · à faire (S)
6. `shared/ai3/demande.lua:170` · le puits de demande décroît de 5 %/min seulement après le réveil · pénuries artificielles · fermeture nette · **0.7.2**
7. `shared/team/centrale.lua:29,149` · 15 demandes de centrale au plus sur toute la partie · croissance électrique arrêtée en partie longue · garde supprimée · **0.7.2**
8. `shared/ai3/saturation.lua:35,84` · aucune fonte de stock reconnue avant 10 relevés · 10 min d'aveuglement · fenêtre 4 · à faire (S)
9. `shared/ai3/demande.lua:54,158` · plancher de puits à 10/min avec une production nulle · le stock dormant est drainé pendant un effondrement · plancher 0 · à faire (S)
10. `shared/team/bilan_charbon.lua:14,18` · le besoin de charbon ignore les recettes qui le consomment · extraction structurellement courte · ajouter la consommation en recettes · à faire (M)

## Pilier 2 : exploration, reconnaissance, cartographie

11. `shared/ai3/carte.lua:130`, `script/ai3/exploration.lua:359,755` · les gisements sont comptés en secteurs de 64 tuiles : un gisement sur deux secteurs clôt la demande en « trouvé » · éclaireur rentré sans gisement neuf · compter des grappes · **0.7.2**
12. `script/ai3/exploration.lua:605-606` · la cible de l'éclaireur n'est pas contrôlée sur son trajet (la veille l'est) · éclaireur à travers des nids connus · `K.path_clear` · **0.7.2**
13. `script/ai3/exploration.lua:1166-1170` · le minage d'appoint lointain ignore les nids du couloir · PNJ morts en route · `K.path_nests` · **0.7.2**
14. `script/faction/sites.lua:555` · le choix d'un site d'avant-poste ne lit pas `K.site_risk` · avant-postes posés derrière des nids · refuser au-delà du seuil de risque · à faire (S)
15. `shared/ai3/carte.lua:44,316` · le risque d'un site ignore les nids que sa pollution atteindra (64-224 tuiles) · vagues dès la mise en route · terme de pollution · à faire (M)
16. `carte.lua:419-449`, `exploration.lua:627-630` · l'eau vue n'entre pas dans le choix de cible ni du pas · chemins ratés au bord des lacs · pénaliser les segments sur l'eau · à faire (M)
17. `script/ai3/exploration.lua:861` · `inject_known` prend les 3 gisements les plus proches, sans la quantité · avant-postes vite épuisés · trier par quantité / distance · **0.7.2**
18. `shared/ai3/carte.lua:388-394` · l'a priori de distance disparaît après le premier gisement ; aucun a priori pour l'eau · 2e gisement cherché autour du QG · garder la règle · à faire (S)
19. `script/ai3/exploration.lua:648` · reprise du tour après une fuite sur un index décalé · point sauté ou rejoué · reprendre par `pts[...].ring` · à faire (S)
20. `script/ai3/exploration.lua:280-283` · richesse estimée sur les 8 premières tuiles du quart · quantités faussées · échantillon réparti · à faire (S)

## Pilier 3 : arbre technologique, priorisation R&D

21. `shared/ai3/general.lua:126-128,403` · une technologie sans usage vaut 5 et passe devant des paliers chers · packs dépensés pour rien en début de partie · `V_OTHER = 0` · **0.7.2**
22. `shared/ai3/reglages.lua:100-105` · les intermédiaires (acier, plastique) n'ont aucun rôle · acier, fours électriques, logistique 2 tardifs · rôle « intermédiaire » déduit du livre · à faire (M)
23. `shared/ai3/general.lua:21` · la logistique vaut 10 contre 30 pour une machine · bus resté au tapis jaune · `V_LOG = 30` · **0.7.2**
24. `shared/ai3/buts.lua:124` · les poids de recherche ignorent la menace · aucune poussée militaire sous attaque · armée ×1,5 sous menace · **0.7.2**
25. `shared/ai3/general.lua:334-348` · la règle « défense d'abord » s'arrête à la recette de tourelle · tourelles restées aux dégâts de base · étendre aux bonus militaires sous menace · à faire (M)
26. `script/ai3/general.lua:625-629` · la recherche en cours, tant que payable, court-circuite `Gen.choose` · une recherche chère bloque la tourelle · laisser choisir si la tourelle est fermée · **0.7.2**
27. `script/ai3/cerveau.lua:75,667-675` · réserve de 10 packs de chaque sorte, même sans recherche qui les lit · fer et cuivre gaspillés · réserve limitée aux packs utiles · à faire (S)
28. `script/ai3/cerveau.lua:72-73,588` · un seul labo sous 10 min de recherche restante · paliers lents · fenêtre 180 s, 2 labos dès le pack vert · à faire (S)
29. `shared/ai3/impayable.lua:23-24` · une recherche impayable garde les labos 8 à 10 min · labos à l'arrêt · 3 min, lâcher si l'ingrédient n'est pas fabricable · à faire (S)
30. `shared/team/planner.lua:1272`, `shared/ai3/recherche.lua:108-159` · `A.plan`, `A.priority`, `A.lean` jamais appelés : règle documentée morte · ancien cerveau sans plancher d'économie · brancher ou supprimer · à faire (M)

## Pilier 4 : topologie, flux, deadlocks

31. `shared/team/plan.lua:772-774`, `script/team/build.lua:1689-1692` · l'arrivée latérale verse deux voies dans une seule · débit des foreuses divisé par deux · borner le nombre de foreuses · **0.7.2**
32. `script/team/build.lua:1786` · un port à un seul minerai ne source que sa voie 1 · fours de bout de ligne à sec · sourcer la voie 2 au-delà d'une voie de débit · **0.7.2**
33. `script/team/build.lua:1862-1867` · un quai de repli refusé n'est pas signalé · module fini mais jamais alimenté · rendre l'échec · **0.7.2**
34. `script/team/piquage.lua:459,498,526-530` · la branche du répartiteur ne reçoit que le surplus ; « inerte » seulement noté · quai vide malgré le tapis · partage égal après N relevés inertes · à faire (S)
35. `script/team/piquage.lua:512-516` · une branche coupée reste au sol et tient ses tuiles · fer et tuiles immobilisés · libérer à la coupe · à faire (M)
36. `script/team/piquage.lua:509-510` · l'attente d'un répartiteur absent du coffre n'est jamais comptée · chantier ouvert sans fin · plafond ou but du cerveau · à faire (S)
37. `script/team/stock.lua:1026-1031`, `script/team/bus.lua:113` · un tampon de rapatriement plein compte encore à plein débit dans le bus · bus bâti sur un débit fictif · débit 0 à la barre · à faire (M)
38. `shared/team/convoyeurs.lua:63-67` · le tapis rapide « au stock » est choisi sans regarder la longueur du tracé · chantier bloqué faute de tapis · exiger la longueur · **0.7.2**
39. `script/team/bus.lua:31,124` · débit supposé de 120/min pour toute source du bus · tronc pour un produit lent · estimer le débit · à faire (S)
40. `script/team/melange.lua:148,212` · le contrôle anti-mélange n'est jamais refait après un agrandissement de foreuse · tapis pollué par un autre minerai · relire au changement d'entité · à faire (S)

## Pilier 5 : résilience militaire, tactique, santé du système

41. `script/ai3/soldats.lua:326-327` · la menace sur le QG prend l'ennemi le plus proche, quel qu'il soit : un ver plus proche masque la vague · ouvriers dehors pendant la percée · chercher d'abord une unité · **0.7.2**
42. `script/ai3/soldats.lua:822-823` · même masque pour la mise à l'abri de l'équipe du joueur · PNJ du joueur sous l'attaque · même correction · **0.7.2**
43. `script/team/reparation.lua:53` · une pièce détruite n'est pas retirée du relevé · quota de réparation saturé de pièces mortes · `Rp.drop` sur le coup mortel · **0.7.2**
44. `script/team/reparation.lua:206` · la garde de réparation ignore vers et tourelles ennemis · réparateurs tués en boucle · chercher aussi les tourelles · à faire (S)
45. `script/team/reparation.lua:155,221-224` · tâche de réparation sans preneur rouverte à l'identique toutes les 5 s · boucle zombie · compter, reporter après 3 · **0.7.2**
46. `script/team/rebuild_rapide.lua:84` · `subst_fail` posé pour toute la partie · plus jamais de foreuse de secours · tick et nouvel essai · à faire (S)
47. `script/team/rebuild_rapide.lua:100` · `find_nearest_enemy` (nids et vers compris) à chaque pensée · foreuse thermique jamais reprise, appel répété · filtrer ou mémoriser · à faire (S)
48. `shared/team/repli_place.lua:61,118` · la table des fenêtres refusées grossit sans fin · `global` gonfle en partie longue · purger au-delà de `RETRY` · à faire (S)
49. `script/team/qg_tourelle.lua:72` · la vague n'est cherchée que dans la force `enemy` · diagnostic aveugle entre factions · forces ennemies de l'entité · à faire (S)
50. `script/ai3/soldats.lua:331-336` · l'unité la plus proche est comptée deux fois dans les profils de menace · ralliement biaisé · liste vide au départ · à faire (S)
