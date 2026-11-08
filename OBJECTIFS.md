# OBJECTIFS : Factorio Overhaul

> Réécrit le 8/11 vers 8 h 45, sur ordre du Directeur Créatif : « on efface tous vos objectifs [...] on met clairement une todo
> au niveau objectifs SIMPLE, CLAIRE, PRECISE ! On indique FINIR A 100% TOUS LES POINTS DE LA TODO LISTE VIDEO, plus tous les
> autres objectifs anexe comment l'optimisation. » L'ancien fichier, avec les citations, les preuves et l'historique, est
> archivé dans `docs/archives/OBJECTIFS_ARCHIVE_2026-11-08.md` (et `..._2026-11-07.md` avant lui).
>
> **Définition de FAIT** : la règle est branchée dans le jeu, allumée par défaut, testée hors jeu avec mutants, relue par un
> relecteur indépendant, prouvée par un banc en moteur réel, et présente dans une version INSTALLÉE. Sinon, ce n'est pas fait.

## 1. FINIR À 100 % TOUS LES POINTS DE LA TODO VIDÉO (`docs/TODO_VIDEO.md`)

État sur la 0.6.64 (recompte du 8/11 à 8 h 30, `scratchpad/recompte_impl_0664.md` et `recompte_pec_0664.md`) :
- IMPLÉMENTER : **70 / 78** faits, 8 partiels ;
- À PRENDRE EN COMPTE : **79 / 106** faits, 14 partiels, 1 absent, 12 sans objet.

Ce qui reste, et qui le fait (lots lancés le 8/11 vers 8 h 40, base 0.6.64 = e0598bef ; état mis à jour le 8/11 à 10 h 10). La 0.6.65 est sortie en **fusion rapide** sur ordre du DC (tests du lot et des fichiers touchés, partie neuve sans plantage) : relecture indépendante et balayage complet faits APRÈS la sortie. Un point « 0.6.65 installée » n'est donc FAIT au sens ci-dessus qu'une fois cette relecture passée.

| Point | Ce qui manque | Lot | État |
|---|---|---|---|
| V42 | soupape des fluides écrite, jamais appelée par le jeu | tv-flux | micro-banc flux-soupape en cours |
| G51 | barils de fluide comptés dans le stock jugé | tv-flux | micro-banc en cours |
| C11 | quotas recalculés quand les modules manquent | tv-quotas | **0.6.65 installée** |
| C05 | valeur logistique des modules chiffrée dans le levier | tv-quotas | déjà fait (recompte du 8/11) |
| W02 | électrique refusée en amont sans centrale finie | tv-energie | versé dans essai-0666 (c6bb40d8), tests en cours |
| G41 | règle générale « première expansion = énergie » | tv-energie | versé dans essai-0666, tests en cours |
| G65 | unité de secours de la centrale | tv-energie | versé dans essai-0666, tests en cours |
| V36 | remplissage de charbon déclenché par le tampon de vapeur | tv-vapeur | **0.6.65 installée** |
| V89 | dégradation graduée sous 60 UPS (signal déterministe) | tv-vapeur | **0.6.65 installée** |
| V10 | famille « armée » à parts réservées | tv-pilote | versé dans essai-0666 (c6bb40d8), tests en cours |
| G02 | plafonds de sûreté des fours, chaînes et packs | tv-pilote | versé dans essai-0666, tests en cours |
| D02 | liste minimale d'amorçage écrite en code | tv-pilote | versé dans essai-0666, tests en cours |
| V88 | table défaut → signal → levier, lue par la décision | tv-gardes | **0.6.65 installée** (journal [FO-DEFAUT], sans effet sur les décisions : partiel) |
| W04 | inventaire des gardes fermées, refus écrit pour chacune | tv-gardes | **0.6.65 installée** (30 gardes dans essai-0666) |
| G37 | sonde 30 × 30 décalée de +2 | tv-place | **0.6.65 installée** |
| G38 | défrichage préventif 50 × 50 | tv-place | **0.6.65 installée** |
| G57 | sites des factions sondés par tuile (10 × 10) | tv-place | **0.6.65 installée** |
| C07 | repli de placement simple | tv-repli | **0.6.65 installée** (micro-banc tv-repli en cours) |
| V23 | enveloppe commune d'avance (logistique, défense, courant) | tv-archi | **0.6.65 installée** ; défense des lots préparés : en cours |
| V91 | quartiers autonomes à réseau logistique propre | tv-archi | **0.6.65 installée en version minimale** ; vidange, collecte, « engagé » : en cours |
| C25 | comparaison A/B octet à octet des règles de la vidéo | tv-methode | **0.6.65 installée** |
| D05 | temps de réglage | tv-methode | en cours |
| V30 | boucle poser / remesurer / rang bas prouvée en moteur réel | mesure-dc | en cours (sauvegarde du DC) |

Sans objet (fonction absente de notre jeu, à confirmer point par point) : V02, V43, V71, V80, V92, G39, G44, G48, G52, G62, D08,
W12.

## 2. L'EFFET « SPEEDRUNNERS » PROUVÉ SUR VOTRE SAUVEGARDE

Mesure en moteur réel sur `autosave1-2121.zip` (lot mesure-dc), pour chaque faction et pour votre équipe, toutes les 5 min de jeu :
machines en marche et causes d'arrêt, recherche en cours et finie, époque atteinte, plaques produites. But : aucune machine
inactive sans cause traitée, pénuries traitées avant qu'elles ne bloquent.

À faire dans VOTRE partie : allumer « PNJ : aller au pétrole » (Paramètres > Paramètres des mods > Carte). Il y est éteint, et la
recherche de votre équipe est arrêtée faute de pack bleu.

Mesure sur la 0.6.64 (lot mesure-dc, 10 min de jeu, `fo-logs/2026-11-08_MESURE-DC`) : 30 % des machines en marche, aucune époque gagnée. Causes d'arrêt : sans combustible 22,8 %, plus de place 15,6 %, sortie pleine 12,3 %, fours sans minerai 8,5 %, assembleurs sans fer 7,8 %. Lots ouverts le 8/11 : blocage-combustible (le charbon des coffres des avant-postes n'est ni porté ni ramassé), blocage-sortie, blocage-labos (site pétrolier refusé puis jamais retenté, donc aucun pack chimique).

Labos des PNJ : décision du DC (8/11, vers 10 h 50, QCM) : « Non, garder la recherche virtuelle ». Les labos restent du décor ; on corrige seulement le blocage du pétrole.

Vue « Cerveau » demandée par le DC (8/11, vers 10 h 55) : « j'aimerais un mode debug, pas le mode que vous avez déjà mis dans les paramètres, un mode debug qui me permet de visualiser les choix que fait le cerveau, par exemple de ma faction. [...] si elle sait régulièrement si cette zone fonctionne, comment l'améliorer si la zone est à améliorer, si finalement il y a une tâche prévue par exemple pour refill en charbon cette zone, pour remplacer ce coffre de charbon par un input directement avec des convoyeurs, pour remplacer ce bras mécanique par un splitter par exemple. » Lot debug-cerveau ouvert.

Constat du DC en jeu (0.6.65, 8/11 vers 11 h 10, azure à l'âge 3, environ 2 h 30 de partie) : « il y a souvent un à deux max rangées de mineurs électriques [...] Avant, c'était très bien fait par les foreuses électriques [...] Petit à petit, ça couvrait tout le gisement [...] ils construisent pas en boucle » ; fonderie de cuivre d'azure : 30 fours, 227 plaques/min (environ 40 % de sa capacité) ; « un mode qui existe pour [...] avoir le niveau de production de chaque usine. J'aimerais [...] que ce soit par défaut » ; « j'ose espérer que la logique de splitter [...] est intégrée » (elle ne l'est pas : répartiteurs posés seulement à la construction des champs). Lots ouverts : couverture (régression de la couverture des gisements, construire en boucle avec le stock), blocage-sortie-2 (reprise), débit par usine visible par défaut dans la vue Cerveau.

Constat du DC en jeu (8/11 vers 11 h 20) : « ils ont 50 modules de vitesse dans les coffres et qu'ils se bougeraient pas le derrière pour les poser [...] dans les usines d'assemblage » ; « ils n'améliorent pas du tout la base [...] tous les fours [...] toutes les foreuses [...] pas non plus les convoyeurs. Et quand ils décident de le faire, c'est un seul et ils le max pour aucune raison [...] penser en bloc et pas penser en petite unité [...] vérifiez également que les blocs soient améliorés [...] en fonction de l'orientation. » Lots ouverts : amelioration (en largeur, par bloc, selon l'orientation), modules-poses (modules du stock posés par les PNJ).

Demande du DC (8/11 vers 11 h 30) : pour un produit en manque, « améliorer ce bloc-là et en parallèle continuer de construire des foreuses, continuer de construire des fonderies, continuer d'améliorer » ; obstacles de tracé : « trouver le moyen de pouvoir entre guillemets enjamber cet obstacle-là, par exemple en posant des tunnels souterrains, en posant des splitters, en contournant avec des convoyeurs. Évitez également de passer par-dessus les gisements [...] si vous ne pouvez pas passer par autre part que par le gisement, passez par le gisement, mais essayez quand même d'organiser le passage un minimum. » Lot ouvert : traversee (aucun tracé de liaison n'emploie de tapis souterrain aujourd'hui) ; amelioration et couverture se partagent le stock en parallèle.

Constat du DC en jeu (8/11 vers 11 h 45, environ 3 h de partie, difficulté Normal) : « une quantité de tourelles en stock assez impressionnante, qui se défendent pas si bien que ça [...] si jamais j'avais pas posé de tourelles moi-même pour la défense, ils se seraient jamais défendus correctement » ; « réduire quand même beaucoup plus la range des soldats [...] au moins enlever 30 % quoi. Si la range est de 18, mettre la range à 11 ou 12 » ; « ils améliorent les assembleurs. En tout cas mon équipe [...] d'autres équipes n'améliorent pas leur base régulièrement [...] C'est pas le même cerveau » ; modules aussi « sur les foreuses » ; « j'ai moi-même construit une fonderie de cuivre [...] pendant plus d'une heure et demie, il y avait pas de fonderie de cuivre [...] ils n'utilisent pas le cuivre qui est dans les coffres » ; « ils utilisent directement les ressources dans les coffres qui sont positionnés au niveau des fonderies [...] très bien [...] Le problème, c'est qu'il faut faire pas mal de trajets [...] relier un maximum les ressources aux assembleurs [...] blocs et graphes connexes [...] K-max [...] le nombre de bus ». Lots ouverts : defense-stock (tourelles du stock posées), portee-soldats (× 0,65, de 18 à 12, sans toucher aux armes du joueur ni aux tourelles), reseau-graphe (conception : relier producteurs et consommateurs par k bus).

Demandes du DC (8/11 entre 11 h 55 et 12 h 05) : « avoir des usines dont l'input est nécessaire [...] à mi-chemin entre les deux ou [...] le plus proche de l'un ou de l'autre en fonction du besoin de l'input » ; « vérifie bien que un bloc d'usine, ça a n inputs et n outputs en fonction des outputs » ; « ils pourraient clairement utiliser un splitter pour relier l'input de ce bloc avec le flux [...] les inputs des box [...] sont jamais améliorés [...] Il va jamais relier un bus de charbon ou utiliser un splitter » ; « ils sont cinq à miner du cuivre par terre alors que ils ont des coffres avec des milliers et des milliers [...] de plaques de cuivre ». Lots : reseau-graphe (placement des usines par débit × distance, audit n entrées / m sorties des gabarits), piquage (entrée de bloc servie par un répartiteur sur un tapis existant), blocage-sortie-2 (extraction à la main d'une ressource qui dort en stock).

Demandes du DC (8/11 vers 12 h 10 et 12 h 20) : repérer une sortie sans balayage (« un bras [...] qui le met dans un coffre et ce coffre-là, il n'y a pas de sortie de ce coffre. Ça, c'est un output ») ; « ils minent à la main du cuivre, ils minent à la main du fer et ils le mettent dans des fours à côté de la base » malgré des milliers de plaques dans les coffres des fonderies ; « une fonderie qui est vachement loin du centre [...] ça le met pas sur des convoyeurs pour le ramener [...] transformer les coffres [...] en buffers [...] un bras [...] qui récupère des convoyeurs et qui le met dans les coffres, et ensuite un autre bras qui récupère du coffre et qui le met sur un autre convoyeur [...] vers des endroits où il y en a besoin ». Mesure (reseau-graphe) : tout passe par le QG, 2 trajets de PNJ par objet ; azure a porté 182 000 fer et 108 000 cuivre à la main. Lots : minage-main (registre des coffres par événements, plus d'extraction à la main quand des plaques dorment), rapatriement (sorties lointaines ramenées par tapis vers un tampon près des consommateurs).
Directive du DC (8/11, 13 h 05, « DIRECTIVE ARCHITECTURALE FINALE ») : bus et répartiteurs, coffres comme buffers reliés par piquage, rangées d'assembleurs qui partagent entrée et sortie, mall à étapes, amélioration continue (tapis, bras rapides, assembleurs, modules), « Dans une heure exactement, cette architecture interconnectée et évolutive doit être active et visible en jeu ». État : 0.6.66 installée à 14 h 00 avec bus (tronc posé en moteur réel), piquage, rapatriement, rangées (agrandir ou rangée de 5), amélioration par bloc ; mall entre blocs NON fait ; gels A* connus après installation (bus 2 à 10 s), correctifs en cours. Demande du DC (8/11, 13 h 20) : « le centre de commandement doit être proche du spawn du joueur, et déjà réparé au niveau 1 » : fait en 0.6.66 (centre_test 84 OK), non vu en moteur réel. Constat du DC (8/11, 14 h 30, 0.6.66, partie neuve, ~35 min) : « À 33 minutes de jeu, l'équipe a posé une soixantaine de foreuses thermiques et continue d'en rajouter [...] alors que la technologie électrique est déjà disponible » ; « l'IA attend exactement 37 minutes de jeu pour commencer à poser ses premières foreuses électriques » ; « Les PNJ ne doivent plus miner à la main à ce stade, et les nouvelles expansions de gisements doivent se faire directement en électrique » ; « ils devraient relier le coffre de charbon pour créer un input continu et automatisé, et remplacer l'intégralité du champ de minerais par des foreuses électriques ». Puis (14 h 35) : « Tolérance zéro pour l'inactivité et expansion continue : S'il y a la moindre possibilité matérielle de crafter des foreuses et de construire de nouveaux fours, les agents doivent le faire sans aucune interruption [...] L'objectif absolu est de capter un maximum de ressources le plus rapidement possible. » Lots ouverts : electrique, minage-main (suite), fonderie-bloc, zero-idle ; preuve : journal de sa partie copié dans fo-logs/2026-11-08_PARTIE-DC-0666 (capacité 5400 kW saturée, options électriques refusées « courant insuffisant », minage à la main ia3 à 35 min).

Directives du DC (8/11, après-midi), citées :
- 14 h 57, ultimatum : « Tu livres la version en l'état […] tu ne seras autorisé à utiliser qu'une seule instance de Factorio en arrière-plan au maximum ». Livrées : 0.6.67 (14 h 57), 0.6.68 (15 h 16), 0.6.70 (17 h 15).
- 15 h 07, prolongation : saturation à 100 %, rangées dynamiques, « Transition tout-électrique et destruction immédiate des foreuses thermiques », charbon par tapis vers les fonderies, vue Cerveau, amélioration continue. État : tout est intégré, mais la transition électrique n'est PAS atteinte en partie neuve (0 foreuse électrique en 40 min sur la 0.6.70 : centrale 1 inutilisée à cause de l'« amorçage », centrale 2 posée à 301 tuiles avec des poteaux moyens non recherchés). Agents COURANT-LIBRE et CENTRALE-PRES.
- 15 h 25 : « je ne relancerai pas ma sauvegarde, je teste TOUJOURS sur une nouvelle partie, depuis le début ». Porte de livraison : content, puis une partie neuve de 40 min (QCM, 15 h 27).
- 15 h 48 : « veillez à ce qu'il n'y ait plus de 1 million de process Lua en arrière-plan qui tournent et continuez le développement avec une seule instance Factorio maximum ». Règle : un seul lua5.2 à la fois par agent.
- 16 h 50 : « enlevez les artefacts, n'utilisez QUE les fichiers locaux html pour me montrer. JAMAIS les artefacts ».
- 17 h 20, « VRAIE FONDERIE D'ACIER » : « L'acier est produit par des PNJ qui insèrent manuellement des plaques de fer dans des fours isolés près du QG. Ce n'est pas viable à grande échelle […] Implémentez un bloc dédié "Fonderie d'acier" […] une rangée de fours reliée par un bus (convoyeur) de plaques de fer en input, et un convoyeur d'acier en output. Transition : Plus aucun PNJ ne doit alimenter des fours à acier manuellement dès que les ressources (convoyeurs, bras) permettent de construire cette ligne automatisée. Intégrez ce comportement aux rangées d'assembleurs dynamiques pour la prochaine livraison. » État : agent ACIER lancé (branche `acier`).
- Vers 17 h 40, QCM sur la couverture contre la défense : les ordres « couvrir » et « ouvrir » passent la pile « Oui, toujours ». Confié à COURANT-LIBRE (`shared/ai3/pile.lua`).
- Vers 17 h 50, « AUDIT LOGIQUE ET BIAIS DE TEST : LA VRAIE TRANSITION ÉLECTRIQUE ». Ses quatre demandes, citées :
  1. « Vous devez impérativement augmenter la taille des gisements dans vos tests » : la couverture à 100 % est fausse sur de petits gisements de départ.
  2. « Méga-Fonderies » : foreuses électriques → grands bus de minerai à plusieurs voies → blocs de fonte rectangulaires, au lieu de foreuses qui crachent dans des fours isolés.
  3. Fabrication par lots, comme un humain : 20 foreuses d'un coup, puis une ligne entière (foreuses, tapis, poteaux) posée en un passage.
  4. « répondez point par point à l'audit du flux de décision » : le déclencheur thermique → électrique ; ce qui déclenche ou bloque la pose en masse ; pourquoi son équipe est plus lente que les factions.

  Réponse donnée en séance (journaux des parties neuves de 40 min, 0.6.70 à 0.6.72) :
  - Biais reconnu : la porte jouait les gisements de départ (262 à 640 tuiles). Une ligne de fonderie est plafonnée à 7 paires, soit environ 207 tuiles minées, soit 10 % d'un gisement de 2 000 tuiles.
  - Le refus du thermique (`E.thermal`) n'a jamais rien posé. La pose électrique passe par une seule chaîne : capitalisation « couvrir/ouvrir » → champ → réseau « sain » → bande → tracé du tapis → réserve → PNJ.
  - Cinq verrous mesurés : réseau sain exigeant une production > 0 (cercle vicieux) ; budget de tracé partagé, régression de la 0.6.68 ; pile « adapter » ; centrale 2 à 301 tuiles avec des poteaux moyens ; réserve totale avant la pose.
  - Équipe contre factions, même cerveau mais chemins coupés pour l'équipe du joueur : croissance « bras libres » (`script/ai3/general.lua:474`) ; agrandissement des gisements ouverts réservé aux factions (`shared/ai3/buts.lua:337`) ; pas de récolte de minerai. À 30 min : 30 foreuses contre 51 (scarlet) et 61 (azure), toutes thermiques.

  Lots lancés : GISEMENTS-GEANTS (scénario `etape1-geants`, 2 500 à 5 000 tuiles), MEGA-FONDERIE (conception d'abord), POSE-PAR-LOTS, CAPI-POTEAU (le gabarit des foreuses de capitalisation cède au poteau moyen), plus COURANT-LIBRE, TRANCHES-FOREUSES et ACIER. CENTRALE-PRES (78c20542) est fusionné dans `essai-0666` (44643872). Porte de la prochaine livraison : une partie neuve sur gisements géants qui montre de vrais champs électriques, sans effondrement.


## 3. OPTIMISATION

- **×10 réel sur votre sauvegarde** : 600 UPS, donc au plus 1,67 ms par tick, moteur et script compris. Dernière mesure
  (0.6.58) : script 2,87 ms par tick, p99 45,2 ms, pire tick 302 ms. À remesurer sur la dernière version.
- **Gel des usines et garnisons lointaines** (x10-gel) : plantage corrigé ; aucun pic au-dessus de 2 ms (C19) ; aucune perte nette
  sur votre sauvegarde et un gain net sur une scène 10 fois plus grosse (C20'). Retiré de la 0.6.64, vise la version suivante.

## 4. AUTRES OBJECTIFS

- Votre équipe de PNJ : elle ne doit plus tomber à 2 PNJ (vu en 0.6.58), à vérifier sur la dernière version.
- Coffres et poches : critères C1 et C2 non tenus ; surplus des poches de votre équipe (option appliquée : rien, le stock absorbe).
- Visuel : 4 familles sur 7 changent à chaque âge ; titan (concept par défaut : Arche).
- Équilibre : coût du robot trowel hors de sa bande (10 778 contre 13 700 MU) ; test robots rouge.

## 5. VERSIONS

- Installée et poussée sur GitHub : **0.6.71** (`jouable-0.6.71` = 3fc921dc, 8/11 17 h 15), `content` 554 OK. Défaut connu : aucune foreuse électrique en 40 min de partie neuve. Avant : 0.6.70 (`jouable-0.6.70` = a0ea69ca), 0.6.68, 0.6.67, 0.6.65.
- Suivante : 0.6.72 sur `essai-0666`, aujourd'hui en 44643872. Elle contient le budget de tracé propre (fd5159bb), le correctif de survie_moteur_test, le réseau sain sans demande (4bb0bf9e) et la centrale au poteau obtenable (78c20542). NON livrable en l'état :
  - le tracé pondéré coûte jusqu'à 90 ms dans un tick (découpage en tranches en cours) ;
  - avec 4bb0bf9e, la partie neuve s'effondre (0 foreuse thermique à 30 min, 72 % d'inactifs), diagnostic en cours.
