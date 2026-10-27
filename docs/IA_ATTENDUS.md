# IA des PNJ : comportements attendus (liste de « logique évidente »)

Orchestrateur, 27/10/2026 vers 1 h 30. Source : message du DC du 26/10 au soir (macro de nuit, cité mot pour mot dans
OBJECTIFS §5), ses constats du 25/10 (§5, 10 h 50 à 18 h 45), le journal de sa partie du 26/10 (0.4.30, 4 factions,
8 PNJ, Impitoyable, 41 min : `H:\…\factorio-current.log`, lu sans rien toucher) et la conception IA3
(`docs/IA3_CERVEAU.md`, règles H1 à H12, critères K1 à K12).

Le DC l'a dit : il ne validera pas cette liste ; elle doit être de la logique évidente pour qui joue à Factorio. Chaque
ligne dit ce qu'un joueur humain ferait, ce que font les PNJ de `main` 0.4.30 (constaté), et un critère MESURABLE en
moteur réel. **Une ligne n'est faite que si son critère est mesuré vert en moteur réel sur au moins 2 graines** (4 si la
partie diverge, F252). Le travail en cours au 25/10 (lots IA3-a, b, c, f, IA1-d, sur leurs branches, rien de fusionné)
couvre une bonne part des familles A et B ; la famille C (ce qui se VOIT : trajets, peur, agressivité) n'était couverte
par aucun lot.

**Ce que le DC a joué le 26/10 est l'ANCIEN cerveau** (échelle de 17 marches, `shared/team/planner.lua`) : aucun lot IA3
n'était fusionné. Faits relevés dans sa partie : recherche 1 seulement entre 14 et 23 min selon la faction ; Écarlate a
perdu **26 PNJ en 41 min** (équipe de 8, recrutée en boucle), presque tous en tâche « service » entre 87 et 103 tuiles du
QG, tués par les mêmes petits biters et vers : elle renvoie ses PNJ au même endroit sans rien apprendre.

## A. Décider comme un joueur (économie, recherche, automatisation)

| ID | Un joueur… | Les PNJ de 0.4.30 | Critère en moteur réel | Lot |
|---|---|---|---|---|
| A1 | fait de la VRAIE recherche : laboratoires alimentés, packs fabriqués puis consommés, technologies du moteur | « niveau payé en packs » au QG, recherche 8e marche de l'échelle ; R1 à 14-23 min chez le DC | paliers 1 / 2 / 3 en ≤ 6 / 12 / 25 min à 8 PNJ (K1) ; technologies réellement débloquées (`force.technologies[…].researched`) | IA3-c |
| A2 | ne fabrique jamais ce qui ne servira pas | packs d'une recherche impayable fabriqués et jetés (27 à 37 PNJ-min) | 0 PNJ-minute sur une fabrication sans consommateur (K6) | IA3-a / IA3-c |
| A3 | attaque le goulot d'abord et mène plusieurs choses de front | un objectif à la fois ; « Objectif : Charbon, il manque 62 plaques de fer » sans que personne n'aille au fer | au moins 3 projets productifs en même temps à 8 PNJ ; le manque d'une plaque met ≥ 2 PNJ sur sa chaîne en moins de 1 min (cas `ia3b-fer`) | IA3-b, IA3-c |
| A4 | AUTOMATISE ce qui revient : foreuses électriques et tapis vers les fours, assembleurs pour engrenages, circuits et packs | porte à la main (41 à 58 % du temps en tournées) et fabrique à la main | tournées ≤ 15 % du temps à 90 min (K7) ; à 45 min, ≥ 3 modules qui produisent 5 min sans PNJ ; fabrication à la main ≤ 20 % des objets produits à 45 min | IA1-d puis IA3-e |
| A5 | n'accumule pas sans fin : un stock suffisant libère ses bras pour ce qui manque | pierre et charbon « à foison » pendant que le fer manque | aucune matière brute au-dessus de 3 fois son besoin des 15 min suivantes pendant qu'une autre manque, au-delà de 2 min | IA3-c |
| A6 | explore pour une raison (ressource utile manquante ou inconnue) et regarde autour de sa base au départ | prospecte sans brouillard ; n'explore pas quand le fer manque | 0 site choisi dans un secteur jamais vu ; pétrole trouvé ≤ 30 min après le besoin (5 graines sur 5) | IA3-f |
| A7 | grandit (« scale ») : plus de bras quand le travail attend, plus de production à chaque âge | effectif figé au départ (8 = 8 toute la partie) ; 30 PNJ ne livrent pas plus que 10 (0,95) | recrue quand du travail attend plus de 2 min et que le coût est couvert ; 30 contre 10 ≥ 1,2 (livré au coffre) ; effectif qui monte dans une partie longue | IA3-d |
| A8 | sécurise avant d'étendre, et s'étend loin quand c'est sûr | — | voir C5, C6 et IA3-g | IA3-g |
| A9 | va au pétrole, puis aux âges suivants | jamais de pétrole, plafond au niveau 3 | palier 4 ≤ 120 min (K2) ; âges au plus tard au calendrier X0 + 25 % (K8) | IA3-h, IA3-i |

## B. S'organiser comme un groupe (personne n'attend, personne ne se marche dessus)

| ID | Un groupe organisé… | Les PNJ de 0.4.30 | Critère en moteur réel | Lot |
|---|---|---|---|---|
| B1 | ne laisse personne planté au coffre pendant que du travail attend | « plein qui foutent rien » ; 32 à 72 % d'inactifs au début | inactifs ≤ 20 % de 0 à 10 min, ≤ 15 % de 30 à 90 min (K3) ; immobiles au QG pendant que du travail attend ≤ 5 min sur 119 (K5) | IA3-b |
| B2 | fait du travail UTILE (pas de l'occupation) | — | ≥ 70 % du temps sur des tâches dont le produit sert dans les 15 min (K3b) | IA3-b |
| B3 | ne se dispute pas la matière | 3 à 50 « arrachages » par équipe et par partie | 0 échec « stock » (K4) | IA3-b |
| B4 | met plusieurs personnes sur l'urgence | un seul minage à la main par minerai | cas `ia3b-fer` : 3 mineurs de fer en même temps, 62 plaques en ≤ 5 min (fait sur la branche IA3-b, à fusionner) | IA3-b |
| B5 | donne un rôle aux soldats entre deux attaques : patrouille, escorte des ouvriers, garde des avant-postes, nettoyage des nids proches des routes | « il y a bien des milices, mais beaucoup d'agents qui font rien » | soldats sans ordre ≤ 20 % du temps hors repos ; toute tournée vers une zone dangereuse (C5) escortée ; nids sur les routes de l'équipe nettoyés quand la force le permet | IA3-k |

## C. Se déplacer et réagir (ce qui se VOIT ; aucun lot avant le 27/10)

| ID | Un joueur… | Les PNJ de 0.4.30 | Critère en moteur réel | Lot |
|---|---|---|---|---|
| C1 | ne suit pas toujours la même ligne : il varie ses chemins | « les trajets sont prévisibles » | deux tournées vers le même site ne suivent pas le même couloir (écart latéral médian ≥ 4 tuiles) dans ≥ 50 % des cas, sans allonger le trajet de plus de 15 % | IA3-k |
| C2 | qui VOIT un ennemi sur son chemin s'arrête, se détourne ou rebrousse chemin | « même s'ils voient très clairement qu'il va y avoir quelqu'un sur leur trajet, ils vont quand même continuer » | banc : ennemis posés sur la route ; ≥ 90 % des PNJ changent de route ou s'arrêtent AVANT d'entrer à portée de tir ; 0 PNJ qui traverse une zone vue occupée | IA3-k |
| C3 | a PEUR quand il le faut : fuit blessé ou désarmé vers la tourelle ou le QG le plus proche, appelle à l'aide | « ils n'ont pas de comportement visible, typiquement la peur » | PNJ sous 40 % de vie ou sans munitions à portée d'un ennemi : fuite engagée en ≤ 1 s dans ≥ 90 % des cas ; soldats alertés ; un prudent fuit plus tôt qu'un audacieux (mesuré) | IA3-k |
| C4 | est AGRESSIF quand il a l'avantage : poursuit un éclaireur isolé, charge en surnombre, tend une embuscade | « ou à l'inverse l'agressivité » | en surnombre net (≥ 2 contre 1), les soldats engagent et poursuivent ; une faction agressive patrouille ses frontières (mesuré par le caractère IA2-0) | IA3-k |
| C5 | se souvient des endroits dangereux | Écarlate : 26 PNJ tués en 41 min aux mêmes 87 à 103 tuiles du QG, tâche « service » | une mort ou une attaque marque la zone (rayon et durée) ; une tâche dans une zone marquée n'est prise qu'escortée, ou attend, ou change de site ; au plus 2 morts au même endroit par heure et par équipe | IA3-k |
| C6 | ne part pas seul là où c'est risqué | ouvriers seuls à 200 à 300 tuiles du QG | toute tâche au-delà du rayon sûr ou dans une zone marquée part en groupe ou avec escorte | IA3-k, IA3-g |
| C7 | met ses ouvriers à l'abri quand la base est attaquée | toute l'équipe « en garde » | QG menacé : les ouvriers sans arme rentrent derrière les tourelles, les soldats sortent ; morts d'ouvriers pendant une attaque divisées par 2 | IA3-k |

## D. Lisibilité

| ID | Le joueur doit voir… | Critère | Lot |
|---|---|---|---|
| D1 | pourquoi un PNJ fait ce qu'il fait (projet, fuite, alerte, chasse) | état visible au-dessus du PNJ pendant ≥ 2 s à chaque changement de comportement de la famille C ; fenêtre « Équipe et factions » : projets en cours et raison | IA3-k, IA3-j |

## Ordre de travail (27/10)

1. **IA-V2** : réunir sur une branche les lots presque finis (IA3-b marché et registre, IA3-c cerveau par besoins, IA3-f
   exploration ; IA3-a gardé en repli), les ALLUMER par défaut, prouver en moteur réel le cas du DC (`ia3b-fer`,
   `ia3c-dc-*`) et les garde-fous (K9 à K11), puis fusionner (version 0.5.0). Couvre A1 à A3, A5, A6, B1 à B4.
2. **IA1-d** (plan directeur, construction par fantômes) : réparer la centrale, 5 terrains verts ; puis **IA3-e**
   (automatiser) : A4.
3. **IA3-k** (nouveau) : famille C et B5, D1 (comportements visibles), d'abord en règles pures et moteur simulé, puis
   bancs `ia3k-*` en moteur réel.
4. Ensuite : IA3-d (A7), IA3-g, IA3-h, IA3-i.
