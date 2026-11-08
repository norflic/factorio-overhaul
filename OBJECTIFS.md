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

Ce qui reste, et qui le fait (lots lancés le 8/11 vers 8 h 40, base 0.6.64 = e0598bef) :

| Point | Ce qui manque | Lot | État |
|---|---|---|---|
| V42 | soupape des fluides écrite, jamais appelée par le jeu | tv-flux | en cours |
| G51 | barils de fluide comptés dans le stock jugé | tv-flux | en cours |
| C11 | quotas recalculés quand les modules manquent | tv-quotas | en cours |
| C05 | valeur logistique des modules chiffrée dans le levier | tv-quotas | en cours |
| W02 | électrique refusée en amont sans centrale finie | tv-energie | en cours |
| G41 | règle générale « première expansion = énergie » | tv-energie | en cours |
| G65 | unité de secours de la centrale | tv-energie | en cours |
| V36 | remplissage de charbon déclenché par le tampon de vapeur | tv-vapeur | en cours |
| V89 | dégradation graduée sous 60 UPS (signal déterministe) | tv-vapeur | en cours |
| V10 | famille « armée » à parts réservées | tv-pilote | en cours |
| G02 | plafonds de sûreté des fours, chaînes et packs | tv-pilote | en cours |
| D02 | liste minimale d'amorçage écrite en code | tv-pilote | en cours |
| V88 | table défaut → signal → levier, lue par la décision | tv-gardes | en cours |
| W04 | inventaire des gardes fermées, refus écrit pour chacune | tv-gardes | en cours |
| G37 | sonde 30 × 30 décalée de +2 | tv-place | en cours |
| G38 | défrichage préventif 50 × 50 | tv-place | en cours |
| G57 | sites des factions sondés par tuile (10 × 10) | tv-place | en cours |
| C07 | repli de placement simple | tv-repli | en cours |
| V23 | enveloppe commune d'avance (logistique, défense, courant) | tv-archi | en cours |
| V91 | quartiers autonomes à réseau logistique propre | tv-archi | en cours |
| C25 | comparaison A/B octet à octet des règles de la vidéo | tv-methode | en cours |
| D05 | temps de réglage | tv-methode | en cours |
| V30 | boucle poser / remesurer / rang bas prouvée en moteur réel | mesure-dc | en cours |

Sans objet (fonction absente de notre jeu, à confirmer point par point) : V02, V43, V71, V80, V92, G39, G44, G48, G52, G62, D08,
W12.

## 2. L'EFFET « SPEEDRUNNERS » PROUVÉ SUR VOTRE SAUVEGARDE

Mesure en moteur réel sur `autosave1-2121.zip` (lot mesure-dc), pour chaque faction et pour votre équipe, toutes les 5 min de jeu :
machines en marche et causes d'arrêt, recherche en cours et finie, époque atteinte, plaques produites. But : aucune machine
inactive sans cause traitée, pénuries traitées avant qu'elles ne bloquent.

À faire dans VOTRE partie : allumer « PNJ : aller au pétrole » (Paramètres > Paramètres des mods > Carte). Il y est éteint, et la
recherche de votre équipe est arrêtée faute de pack bleu.

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

- Installée : **0.6.64** (`jouable-0.6.64` = e0598bef, 8/11 8 h 05). Contenu et preuves : `REPRISE.md`, `changelog.txt`.
- Suivante : 0.6.65, avec les lots du §1 et le gel du §3, chacun versé après relecture, balayage complet et bancs.
