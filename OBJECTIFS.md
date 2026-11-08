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

- Installée : **0.6.65** (`jouable-0.6.65` = 4ca8dc4d, 8/11 10 h 01) : `content` 554 OK, `pnj-auto` 7 OK en partie neuve, aucune erreur Lua ; balayage hors jeu à 10 h 10 : 323 tests sur 336 passés, seul rouge `robots_test` (déjà rouge en 0.6.64), les 13 derniers tournent. Avant : 0.6.64 (`jouable-0.6.64` = e0598bef).
- Suivante : 0.6.66 (`essai-0666` = c6bb40d8 : 0.6.65 + TV-PILOTE + TV-ENERGIE), puis les lots encore en cours du §1 et le gel du §3.
