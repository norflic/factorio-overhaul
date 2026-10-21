# EQUIPES_PNJ : des équipes de PNJ organisées (lot IA1, OBJECTIFS C5)

> **Statut** : conception, plus un modèle pur testé hors jeu (`shared/team/org.lua`, `tests/org_test.lua` :
> 260 OK, 0 échec). **Rien n'est en jeu.** Aucun comportement décrit ici n'est vérifié en moteur réel.
>
> **Sources** : la demande du 21/10 à 21 h 35 et sa précision de 21 h 45 (Q19), qui prime sur tout le reste ;
> la proposition gagnante du concours IA1 (angle technique et performance), enrichie des greffes des deux juges.
> Ses incohérences sont corrigées et listées au §19.
>
> **Conventions** :
> - « vérifié » : relu dans le code, dans `doc-html/runtime-api.json` ou `prototype-api.json` 1.1.91, dans
>   `data/base`, ou recalculé dans un journal archivé de `<racine>\fo-logs\` ;
> - « estimé » : chiffre de conception, à mesurer ;
> - « non vérifié » : rien ne le prouve encore ;
> - **[à valider]** : proposition soumise au Directeur Créatif (le marqueur des critères proposés d'OBJECTIFS.md).
>
> Le Directeur Créatif seul valide un design : l'interface et l'affichage du territoire passeront par ses captures.

## Sommaire
0. En bref
1. « Pourquoi 6 ouvriers ? »
2. Le socle : ce qu'on garde, ce qui bloque (mesuré)
3. Organisation : un cerveau, trois pôles, cinq managers, des généralistes, des exécutants
4. Rôles et managers en détail
5. Ce que font les PNJ (verbes), amélioration instantanée comprise
6. Cœur de la R&D : une production adaptative, pilotée par les objectifs
7. Conflit : territoire, gisements disputés, raids, déchiqueteurs
8. Interface de gestion de votre équipe (maquettes des écrans)
9. Résurrection et recrutement
10. Progression des PNJ, comparée au joueur
11. Tailles et réglages
12. Budget de script chiffré
13. Déterminisme, sauvegarde, multijoueur
14. Risques moteur et expériences préalables
15. Critères d'acceptation mesurables
16. Découpage en lots, avec preuves en moteur réel
17. Questions au Directeur Créatif (5)
18. Le modèle pur livré : `shared/team/org.lua`
19. Corrections apportées à la proposition gagnante, greffes retenues et écartées
20. Fichiers, interfaces avec les autres lots, notes pour l'intégrateur
21. Ce qui n'est pas vérifié

---

## 0. En bref

| Question | Réponse courte |
|---|---|
| Pourquoi 6 ? | Deux « 6 » différents (§1). Celui des factions vient d'une règle de 2 ouvriers + 1 par avant-poste (plafond 10), posée avant que le coût d'un agent soit connu. Ce coût n'est plus la limite (E22). La vraie limite, **mesurée**, est le **manque de travail** : aujourd'hui, la moitié des ouvriers font des tournées ou minent à la main, un quart attendent. |
| Combien demain ? | **30 PNJ par faction** et **30 dans votre équipe** (réglables de 6 à 60), 4 factions. Départ à 8, plafonds de 15, 25, puis 30 aux époques 1, 2 et 3 [à valider]. |
| Qui décide ? | **Un seul cerveau par équipe** (C2-1). Il appelle **5 managers** (fonctions pures, un par domaine : gisements, logistique, production, infrastructures, défense), regroupés en **3 pôles** (Extraction, Base, Territoire). |
| Les « couteaux suisses » ? | **1 PNJ sur 6 est généraliste** (5 sur 30) : un vrai ouvrier, rattaché à un pôle, qui **mène un projet de bout en bout** à travers les domaines (« je vais aller chercher du pétrole, je vais mettre des tuyaux »). Lui seul conçoit : choisir un lot, implanter un module, tracer une conduite, ouvrir une zone. Les 25 autres exécutent. |
| Que construisent-ils ? | De **vraies lignes de production** : des modules éprouvés (gabarits) dimensionnés par un **solveur de débits**, placés sur un **plan directeur en lots et en rues** adapté au terrain, bâtis fantôme par fantôme. Du pétrole avec des tuyaux. Des améliorations **instantanées**. Des zones tenues par des tourelles. |
| Et vous ? | Vous donnez l'**orientation** (3 curseurs ou un préréglage), des **cibles de production** (« circuits rouges : 30/min »), des **zones** à tenir, des **ordres directs** avec les outils vanilla. Une interface à 5 onglets (§8). |
| Coût | Projection **0,19 à 0,27 ms/tick** de script pour 150 PNJ. Cible du lot : **≤ 0,40 ms**. Budget A1 : 1,5 ms. Le coût moteur des usines des IA est **inconnu** (§12). |
| Preuve | 11 lots, chacun avec son scénario en moteur réel et des seuils chiffrés (§16). Le modèle d'organisation est déjà testé hors jeu (§18). |

---

## 1. « Pourquoi 6 ouvriers ? »

Votre message (21/10, 21 h 35) arrive juste après votre accord sur QX6. Deux « 6 » coexistent dans nos
documents, et le mot « ouvriers » y a deux sens.

1. **Les « ouvriers » des niveaux** (`L.MAX_BUILDERS = 5`, `L.builders`, vérifié dans `shared/levels/config.lua`)
   sont des **chantiers d'amélioration simultanés**, de 1 à 5, plus un 6e offert par la merveille « Horloge
   éternelle » (QX6). C'était un réglage de rythme à la Clash of Clans. **Avec Q19** (« si on a les ressources,
   on améliore, terminé »), **ce sens disparaît** : plus de durée, plus de file, plus de limite de chantiers.
   L'adaptation du système des niveaux revient au lot V2c ; IA1 n'en conçoit aucune.
2. **Les ouvriers PNJ des factions** : `T.workers_wanted = min(plafond, 2 + nombre d'avant-postes)`, avec
   `F.defaults.engineers_max = 10` et `T.player_workers_max = 8` (vérifié dans `shared/team/config.lua` et
   `shared/faction/config.lua`). BALANCE_SHEET §10 mesure **6 ouvriers à 10 min** pour chaque faction, puis 6 à 9
   à 60 min.

**Pourquoi si peu de PNJ ?**
- **Raison historique.** La règle date des sessions 2 à 4 (20 et 21/10). Le coût d'un agent riche était alors
  inconnu (H5). Il est mesuré depuis : **402 agents riches pour 0,50 ms/tick** (E22). Le budget n'est plus la limite.
- **Raison réelle, mesurée.** Le cerveau ne crée pas assez de travail. Journal archivé
  `<racine>\fo-logs\2026-10-21_integration_IA0_ia0-normal\` (60 min, 4 équipes, 28 ouvriers ; recalculé par le
  rédacteur avec `tools/autotest/analyze.py` et la lecture du journal) :
  - **24,3 % d'ouvriers inactifs** en moyenne après 30 min (28,2 % sur toute la partie) ;
  - à 59 min : Émeraude « ouvriers {idle:4 service:4} », soit la moitié inactive ; sur les 4 équipes, **14
    ouvriers sur 28 font des tournées ou minent à la main**, 7 attendent, **7 seulement construisent ou
    fabriquent** ;
  - les 4 équipes sont figées sur l'objectif `iron3`, avec « manque [site:ironx1] » ;
  - le fer est rare au stock (59 à 249 plaques), le cuivre s'entasse (1 659 à 2 986) ;
  - 3 062 demandes de chemin, 148 échecs, dont **128 « but occupé »** (F28 qui revient).

  Avec le cerveau actuel, 30 PNJ auraient surtout attendu ou miné à la main. Le test de compatibilité
  (`tests/org_test.lua`, dernière section) l'illustre hors jeu, sur une vue construite pour le test (4 avant-postes,
  stock de départ) : le cerveau actuel y ouvre 7 tâches, soit 305 s de travail, de quoi occuper 3 exécutants
  sur 25. C'est une illustration, pas une mesure.

**Ce qui change.** 30 PNJ par équipe, et surtout **du travail réel pour 30** : lignes de production, logistique,
améliorations, pétrole, territoire. Une organisation (pôles, managers, généralistes) répartit ce travail.

Le « 100 par faction » de C1 reste porté par les **soldats**, agents de masse (unités moteur pilotées par
groupes, ARCHITECTURE §4). Une faction compte donc 30 PNJ qui jouent, plus jusqu'à 100 soldats.

---

## 2. Le socle : ce qu'on garde, ce qui bloque (mesuré)

| Élément (vérifié dans le code) | On garde | Limite à 30 PNJ |
|---|---|---|
| `shared/team/planner.lua` : cerveau pur, échelle d'objectifs, « il manque » par le livre de recettes | Oui. Il devient la **couche d'entretien et de secours** : tournées, ravitaillement, reconstruction, embauche de secours, éprouvées par E16 à E21. | Il raisonne en **quantités**, pas en **débits**. Il ne fabrique qu'à la main. Son échelle s'arrête au pétrole (H-E1). |
| `shared/team/book.lua` : livre construit sur les vraies recettes | Oui, étendu par un calcul de débits pour toutes les catégories de machines | Seule la catégorie `crafting` est fabricable : **le moteur (`engine-unit`, catégorie `advanced-crafting`), le plastique et le soufre (`chemistry`) ne se font pas à la main** (vérifié dans `tests/fixtures/recipes.lua`, contrôlé par `org_test.lua`). Le pack chimique exige donc un assembleur, une usine chimique et du pétrole : c'est la cause précise de H-E1. |
| `script/team/board.lua` : tableau des tâches | Oui, avec un pôle noté par tâche | `Board.claim` trie toutes les clés à chaque prise, soit O(T log T) par ouvrier inoccupé. Remplacé par un tri par pensée et un passage par prise (`O.sort_tasks`, `O.pick_task`). |
| `script/team/worker.lua` : programme d'étapes sérialisable | Oui, avec de nouveaux verbes (§5) | 16 cases au QG (`SLOTS`) : au-delà de 16 PNJ, deux PNJ partagent une case (F27 revient). Tout programme commence par `home`, d'où la foule au QG. |
| `script/faction/outposts.lua`, `sites.lua` | Oui (avant-postes à combustible des époques 1 et 2) | `Sites.claim` interdit tout gisement réclamé par une autre faction : **aucun conflit de gisement n'est possible** aujourd'hui. |
| Coût mesuré (même journal : 216 000 ticks, 4 équipes, 28 PNJ, banc épinglé) | — | Script **0,065 ms/tick** (p99 0,57 ; max 9,9). Une pensée d'équipe : **0,62 ms** (vue 0,32 ; plan 0,17 ; attaque 0,05). Voie `fo-brain` : 0,012 ms/tick pour 28 agents, soit **0,43 µs par PNJ et par tick**. Locomotion : 0,26 µs par PNJ et par tick. Pathfinder (C++) : 0,008 ms (p99 0,28). Tick complet : 0,32 ms (p99 1,87). Étalon `[FO-CALIB]` : 29 mesures sur 360 au-delà de 1,5 × la médiane, la machine a donc été dérangée par moments. |

**Écarts aux règles relevés dans le code (à corriger au lot IA1-a).**
- `planner.lua`, ligne 131 (`goal_status`) : `pairs(need.stock)` ajoute des besoins dans l'ordre de `pairs`, ce
  qu'interdit la règle 5. Sans effet aujourd'hui (un seul objet de stock dans l'échelle), mais faux dès le deuxième.
- `worker.lua` (cases du QG) et `team.lua` (angles des gisements de départ) : trigonométrie au chargement. Le
  risque est faible (constantes), mais la règle l'interdit. À remplacer par des tables constantes.

---

## 3. Organisation : un cerveau, trois pôles, cinq managers, des généralistes, des exécutants

```
                 ┌──────────── CERVEAU D'ÉQUIPE (pur, 1 par équipe, une pensée toutes les 300 ticks, 4 phases) ────────────┐
 vue de l'équipe │ 1. Objectifs pondérés : époque, recherche, monnaies des niveaux, armée, VOTRE orientation et vos cibles │
 (stock, débits  │ 2. Solveur de débits : machines nécessaires, matières premières, fluides (§6)                       │
 mesurés, modules│ 3. Écart avec le parc installé, diagnostic ; PROJETS ; organisation (shared/team/org.lua)            │
 lots, zones,    │ 4. Tâches, tableau trié une fois                                                                     │
 PNJ)  ────────► └───────┬───────────────────────────────┬───────────────────────────────────┬─────────────────────────┘
               PÔLE EXTRACTION                  PÔLE BASE (« avancement »)            PÔLE TERRITOIRE
               managers : gisements,            managers : production,                manager : défense
                          logistique                       infrastructures
                       │                                │                                    │
               généralistes (≈ 1 sur 6) : chacun MÈNE un projet de bout en bout, à travers les domaines
                       │                                │                                    │
               exécutants : programmes d'étapes (machine « worker » existante, verbes étendus)
```

- **Un seul cerveau par équipe** (C2-1). Les pôles et les managers ne sont pas des cerveaux de plus : ce sont des
  fonctions pures appelées par le cerveau. Elles produisent chacune leurs projets et leurs tâches.
- **3 pôles**, d'après vos mots :
  - **Extraction** : « on essaie d'extraire un maximum de ressources, on les convertit » (la fonderie y est) ;
  - **Base** : « l'avancée de la base de l'équipe en entier », c'est-à-dire production automatisée, recherche,
    améliorations, énergie ;
  - **Territoire** : la protection et le contrôle de zones.
- **5 managers**, un par domaine : c'est votre « avec si vous voulez des managers aussi […] qui s'occuperait des
  ressources, […] de la construction, […] tout ce qui va être automatisé, […] d'améliorer par exemple les
  infrastructures existantes ». Un manager est une **fonction**, pas un personnage : il lit l'état de son domaine,
  ouvre des projets et compte le travail ouvert (la « demande »). Il a une ligne de rapport dans l'interface.
- **Les généralistes, vos « couteaux suisses »** : environ **1 PNJ sur 6** (5 sur 30, réglable de 1 à 8). Ce sont
  de **vrais ouvriers**, qui travaillent comme les autres. Chacun a un **pôle de référence**, mais il **mène un
  projet entier** à travers les domaines : le projet Pétrole va du chevalet de pompage à la raffinerie, en passant
  par la conduite et la ligne électrique. Lui seul prend les **tâches de conception** : choisir et réserver un lot,
  implanter un module (poser ses fantômes), tracer une conduite ou une ligne, ouvrir une zone, débloquer un échec.
- **Les exécutants** prennent tout le reste : raviver des fantômes, porter, entretenir, fabriquer, ravitailler,
  miner. Ils sont répartis entre les pôles selon le travail ouvert et l'orientation (§4.2).
- **Un généraliste tué** : son projet attend (les exécutants continuent l'entretien et ravivent les fantômes déjà
  posés), un autre généraliste libre le reprend, et un exécutant est promu au bout de 2 min s'il manque un
  généraliste. Un chantier **commencé** passe avant un projet neuf (+20 points de priorité). C'est un vrai levier
  de conflit, et il ne coûte rien à calculer.

---

## 4. Rôles et managers en détail

### 4.1 Les cinq managers (domaines)

| Manager | Pôle | Vos mots | Projets qu'il ouvre | Tâches (types existants en gras) |
|---|---|---|---|---|
| Gisements | Extraction | « s'occuperait des ressources » ; « on les convertit » | avant-poste, ligne de foreuses, chevalets de pompage, défrichage, revendication d'un gisement | **build, extend, mine, smelt, smelters**, drill_line, pumpjack, clear ; conception : claim_site |
| Logistique | Extraction | (la « logique de pipeline ») | porteurs, tapis d'îlot, conduites, lignes de poteaux | **service**, carry, belt, pipe, power_line, recover ; conception : route |
| Production | Base | « tout ce qui va être automatisé, la construction de tel ou tel objet » | modules de production, labos, atelier de bâtiments | **craft**, ghost, recipe, lab ; conception : plan_module, claim_lot, unblock |
| Infrastructures | Base | « améliorer par exemple les infrastructures existantes » | améliorations de niveau, remplacements de palier, centrale électrique | upgrade, replace, repair, power_plant ; conception : plan_upgrade |
| Défense | Territoire | « la protection » ; « je veux contrôler cette zone là » | zones, anneaux de tourelles, garnisons | **refill, fortify**, zone_ring, garrison, rebuild ; conception : open_zone |

Les 9 types de tâches du cerveau actuel ont tous un domaine : `org_test.lua` les lit dans `planner.lua` et le
vérifie. Le modèle s'applique donc dès le lot IA1-b, avant tout nouveau verbe.

### 4.2 Répartition des exécutants entre pôles (`O.pole_targets`, testé)

À chaque pensée :
1. **Besoin** d'un pôle = secondes de travail ouvert ÷ 300 s (horizon de 5 min), en PNJ équivalents.
2. **Partage** des exécutants au prorata de « orientation × besoin », chaque pôle étant plafonné à
   ⌈besoin × 5/4⌉ : on ne met pas 10 PNJ sur 2 tâches. Au plus 3 tours de remplissage.
3. **Fond** : s'il reste des exécutants sans travail identifié, ils vont aux pôles selon la seule orientation, et
   le cerveau leur ouvre des tâches de fond (agrandir, prospecter, renforcer). Ce surplus est publié : c'est la
   mesure honnête du manque de travail.
4. **Planchers** : au moins 2 exécutants à l'extraction ; au moins 2 par zone active au territoire (« j'ai par
   exemple […] 2 PNJ »).
5. **Hystérésis** :
   - au plus 2 changements de pôle par pensée ;
   - seulement des PNJ inoccupés, qu'on n'interrompt jamais ;
   - seulement si l'écart à la cible atteint 2 d'un côté ;
   - jamais le même PNJ deux fois en 10 min, soit **au plus 6 changements par PNJ et par heure, par construction**.

   Le test l'éprouve sur 720 pensées où l'orientation s'inverse à chaque fois : le pire PNJ change 6 fois.
6. Les **recrues** sans pôle sont placées tout de suite là où l'écart est le plus grand.

Le PNJ qu'on déplace vient du pôle le plus excédentaire qui a un PNJ inoccupé (sinon du suivant). C'est le moins
gradé, puis la recrue la plus récente : les vétérans restent à leur poste.

### 4.3 Orientation : la vôtre, ou la personnalité de la faction

| Préréglage | Extraction | Base | Territoire |
|---|---|---|---|
| Équilibre (défaut) | 40 | 40 | 20 |
| Ressources | 60 | 25 | 15 |
| Améliorer la base | 25 | 60 | 15 |
| Protection | 20 | 25 | 55 |
| Expansion | 45 | 20 | 35 |

| Faction (personnalité) | Extraction | Base | Territoire |
|---|---|---|---|
| Ordre Écarlate (conquérant) | 33 | 33 | 34 |
| Ligue Azur (technocrate) | 47 | 47 | 6 |
| Consortium Émeraude (bâtisseur) | 40 | 53 | 7 |
| Dynastie Ambre (équilibrée) | 40 | 40 | 20 |

- **Menace** (attaque en cours ou annoncée) : +20 points au territoire tant qu'elle dure.
- Les points se normalisent en entiers de somme 100, sans flottant dans les décisions.

### 4.4 Généralistes : nombre, pôles, projets, promotion

- **Nombre** : ⌈effectif ÷ 6⌉, au plus le réglage (5). Cela donne 2 pour 8 PNJ, 2 pour 10, 5 pour 30, et 8 pour 50
  si le réglage est à 8.
- **Pôles de référence** :
  - d'abord un généraliste par pôle orienté à 15 % ou plus, du plus orienté au moins orienté ;
  - le reste au prorata de l'orientation ;
  - en changeant le moins possible : un changement d'orientation ne déplace que le nombre minimal de généralistes
    (testé).

  Exemples : 2/2/1 pour 5 généralistes en équilibre ; 3/2/0 pour la Ligue Azur, dont le territoire n'est orienté
  qu'à 6 %.
- **Projets** :
  - un généraliste mène un seul projet à la fois ;
  - un projet garde son meneur tant que celui-ci vit, même si les priorités changent ;
  - les projets sans meneur sont servis par priorité effective (+20 pour un chantier commencé), d'abord par un
    généraliste du même pôle ;
  - les projets en surnombre attendent, ce qui est visible dans l'interface.
- **Promotion** :
  - après la mort d'un généraliste : 2 min après, sauf résurrection entre-temps ;
  - quand l'équipe grandit : aussitôt ;
  - le promu est le meilleur exécutant (rang, puis expérience).
  - On ne rétrograde jamais.

### 4.5 Prise de tâche (`O.pick_task`, testé)

Un PNJ inoccupé parcourt une seule fois le tableau trié (priorité, puis clé) et garde la meilleure tâche de rang
le plus bas :

| Rang | Généraliste | Exécutant |
|---|---|---|
| 0 | une tâche de **son** projet, même peu prioritaire | — |
| 1 | une tâche de conception de son pôle | — (jamais de conception) |
| 2 | une tâche de son pôle | une tâche de son pôle |
| 3 | n'importe quelle tâche (« ouvrier à part entière ») | une tâche **urgente** (priorité ≥ 90) d'un autre pôle |

**Plafond du travail manuel** (règle d'automatisation, §6.6) :
- minage à la main et portage, chacun au plus 50 % des exécutants à l'époque 1, puis 20 % ;
- au-delà du plafond, la tâche reste au tableau, sauf urgence ;
- le manque devient visible, et le manager Logistique ouvre un projet de tapis ou de conduite.

---

## 5. Ce que font les PNJ (verbes)

| Pôle | Verbes existants (moteur réel, E16 à E21) | Verbes nouveaux |
|---|---|---|
| Extraction | miner à la main, poser un avant-poste à combustible, l'agrandir, tournée (collecte et charbon), fonderie du QG | **défricher** (`LuaControl.mine_entity` sur arbres et rochers ; le bois revient au stock) ; poser une **ligne de foreuses électriques** ; poser des **chevalets de pompage** ; **porter** d'un quai à l'autre ; tirer une **ligne électrique** ; poser une **conduite** ; **récupérer un cadavre** (inventaire au sol, 15 min de vie : `time_to_live` vanilla vérifié) |
| Base | fabriquer à la main (file du personnage), payer une recherche en packs | **implanter un module** (généraliste) ; **raviver les fantômes** un par un, objets portés, depuis un point d'appui dans la rue ; régler la recette ; **améliorer** (niveau suivant, instantané) ; **remplacer** de palier (four en pierre → four en acier, assembleur 1 → 2, tapis jaune → rouge) ; réparer |
| Territoire | poser des tourelles, ravitailler, autodéfense au pistolet | **ouvrir une zone** (généraliste) ; poser un anneau de tourelles et de murs ; **garnison** (rester dans la zone et tirer) ; reconstruire ; **sape** (§7) |
| Attaque | — (ce sont les soldats) | les cibles de la stratégie pure s'étendent aux **zones de gisement** et aux **modules de production** adverses (§7) |

Les PNJ **ne mènent pas d'assaut eux-mêmes** : les soldats attaquent (C1). C'est un choix par défaut ; des
« commandos de PNJ » restent possibles plus tard, au prix d'un coût et d'un risque de plus.

### 5.1 Amélioration INSTANTANÉE (Q19), et ce qu'elle unifie

Vos mots : « si on a les ressources, on améliore, terminé. Parce que c'est comme pour poser les constructions ».

- **Tâche `upgrade`**, du manager Infrastructures, sans file, sans durée et sans nombre de chantiers :
  1. `home` ;
  2. `take` du coût, au stock ou au centre ;
  3. aller jusqu'au bâtiment ;
  4. **act upgrade**, qui appelle `Levels.upgrade_with(entité, inventaire_du_PNJ)`. Cette fonction est à fournir
     par V2c : elle vérifie le plafond (2 × niveau du centre), retire le coût de l'inventaire du PNJ et remplace le
     bâtiment par `create_entity{fast_replace = true, spill = false, raise_built = true}`, **sans** `character` ni
     `player` (F39, F40).
- **Garde contre la duplication (greffe des deux juges)**. On ne passe **jamais** `character=` à `create_entity`
  pour une amélioration par un PNJ. Raisons :
  - chaque bâtiment de niveau se mine en **son propre objet** (`prototypes/levels/common.lua`, ligne 628, vérifié) ;
  - la documentation 1.1.91 dit que `spill=false` détruit les objets du remplacement « si `player` est nil »
    (vérifié) ;
  - un remplacement simulé « par ce personnage » rendrait donc l'objet de l'ancien niveau au PNJ, d'où un
    bâtiment en double.

  Au banc : `fallback = 0` et **0 objet de niveau en trop**.
- **Un trajet, tout un module.** `O.trip_capacity` calcule combien de bâtiments un PNJ améliore d'un coup avec ses
  cases libres (testé). Par exemple, avec 2 cases libres, 5 fours sur 6 (100 acier et 50 engrenages) ; avec 3, tout
  le module.
- **Priorités permanentes (greffe P1)**. Exemple : « garder les fours de la ligne cuivre au niveau maximal ».
  Elles sont servies au fil du stock, dès que le coût est là. Des **interdits par famille** (« ne pas améliorer les
  murs ») complètent. C'est la boucle « presque idle » d'E3 sans file ni durée : la production remplit le stock,
  les PNJ améliorent.
- **Unification avec les chantiers des niveaux** : retenue sous cette forme minimale. Une amélioration est une
  **tâche ordinaire** du domaine Infrastructures, et les PNJ de votre équipe améliorent comme vous. Le sort de
  `L.MAX_BUILDERS` et de `L.builders` revient à V2c.

---

## 6. Cœur de la R&D : une production adaptative, pilotée par les objectifs

Votre exemple : « on a les circuits verts, faut les circuits rouges […] Peut-être qu'il faudrait améliorer la
production de circuits verts en termes de débit […] On manquerait de ressources pour avoir les circuits rouges
[…] si ça manque de ressources de pétrole, et je vais aller chercher du pétrole, je vais mettre des tuyaux ».

### 6.1 Du but aux manques : le solveur de débits (pur, `shared/team/production.lua`, lot IA1-e)
- **Entrées** :
  - objectifs pondérés, en objets par minute : packs de la recherche visée, monnaie de l'époque pour les niveaux,
    équipement de l'armée, objets de bâtiment des projets en file, **vos cibles** ;
  - livre de recettes, toutes catégories (four, assembleur, chimie, raffinage) ;
  - machines disponibles, à leur vitesse réelle : vitesse vanilla (assembleur 2 : 0,75, vérifié), plus +8 % par
    niveau pour le four et l'assembleur et +10 % pour la foreuse (`k` de `shared/levels/config.lua`, vérifié).
- **Algorithme** : une expansion descendante, comme `Book:plan`, mais en débits.
  - Machines d'une recette = débit visé ÷ produits par cycle × durée ÷ (60 × vitesse).
  - Le pétrole passe par des **blocs à ratios fixes** (raffinage de base, puis avancé), ce qui évite les boucles du
    craquage.
- **Sortie** : un graphe { recette → machines nécessaires, flux d'entrée, flux de sortie } et des besoins bruts
  (minerais, pétrole brut, eau, charbon, électricité).
- **Coût estimé** : au plus 100 nœuds par pensée, plafonné à 60 nœuds par tick (phase 2). Non mesuré.

**Jeu d'essai (greffe P1), recalculé par le rédacteur sur les recettes vanilla** (`tests/fixtures/recipes.lua`)
**et les puissances vanilla** (`data/base`), pour **10 circuits rouges par minute** :

| Étage | Recette (vérifiée) | Débit voulu | Machines |
|---|---|---|---|
| Circuit rouge | 6 s : 2 verts + 2 plastiques + 4 câbles → 1 | 10/min | assembleur 2 (0,75) : 7,5/min chacun → **2** |
| Circuit vert | 0,5 s : 1 fer + 3 câbles → 1 | 20/min | **1** assembleur 2 (90/min) |
| Câble | 0,5 s : 1 cuivre → 2 | 40 + 60 = **100/min** | **1** assembleur 2 (180/min) |
| Plastique | 1 s : 20 gaz + 1 charbon → 2 (chimie) | 20/min | **1** usine chimique (120/min) |
| Gaz | raffinage de base, 5 s : 100 brut → 45 gaz | 200/min | **1** raffinerie (540/min) |
| Pétrole brut | chevalet : 10/s pour un gisement à 100 % (vérifié dans `data/base`) | 444/min, soit 7,4/s | **1** chevalet si le gisement rend 74 % ou plus |
| Plaques | four en pierre : 18,75/min chacun | cuivre 50, fer 20/min | 3 + 2 fours |

- **Électricité** : 4 assembleurs à 150 kW, 1 usine chimique à 210 kW, 1 raffinerie à 420 kW et 1 chevalet à 90 kW,
  soit **1,32 MW** pour les machines (puissances vérifiées dans `data/base`). Les foreuses et les bras portent le
  total à environ **1,6 à 2 MW** (estimé). Il faut une chaudière de 1,8 MW.
- **Charbon** : environ 25 à 30/min pour l'électricité, 10/min pour le plastique et environ 7/min pour les fours,
  soit **environ 45/min**. La proposition P1 annonçait environ 70/min ; l'écart dépend des bras et du minage du
  charbon lui-même, et le test du solveur (lot IA1-e) le tranchera.
- **Leçon** : le vrai besoin est le **charbon et l'électricité**, puis le pétrole. C'est exactement la chaîne de
  manques que le solveur doit trouver seul.

### 6.2 Diagnostic : ce que le moteur mesure gratuitement
- `LuaForce.item_production_statistics` et `fluid_production_statistics`, avec
  `LuaFlowStatistics.get_flow_count{name, input, precision_index}` (vérifié). Chaque faction a sa force : on lit
  son débit réel par objet sans parcourir une seule entité. Pour votre équipe, les statistiques mêlent votre
  production et celle des PNJ : c'est voulu, c'est la production de votre base.
- **Par module**, toutes les 600 ticks, on lit sur une machine témoin `LuaEntity.products_finished` et `status`
  (vérifiés), plus le contenu du quai de sortie.
- **Deux diagnostics distincts** :
  - **manque de capacité** : la capacité installée est sous le besoin, donc on construit ou on agrandit ;
  - **module affamé** : il produit à moins de 60 % de sa capacité nominale alors que l'amont manque. On ne
    construit pas plus en aval, on traite l'amont. C'est le cas de vos circuits verts trop lents, et du plastique
    qui manque, donc du pétrole.

### 6.3 Des manques aux projets : construire, agrandir, améliorer ou remplacer
Pour une recette en déficit de plus de 15 %, le manager Production compare le **coût par unité de débit
ajoutée**, en MU (la valeur unitaire de BALANCE_SHEET §12) :

| Option | Coût | Débit ajouté | Condition |
|---|---|---|---|
| Agrandir un module (emplacements d'extension du gabarit) | objets des machines ajoutées | +n machines | une extension libre sur le lot |
| Améliorer d'un niveau (instantané) | `L.cost` | +8 à +10 % par bâtiment | plafond 2 × centre |
| Remplacer de palier (fast_replace) | différence des coûts | ×1,5 à ×2 | technologie acquise, même groupe de remplacement |
| Nouveau module | objets du gabarit et du lot | débit nominal | un lot libre ; **+20 % de pénalité de complexité** (greffe P1) |

On retient l'option la moins chère par débit ajouté, à 20 % près en faveur de l'option déjà engagée, pour ne pas
osciller. Les besoins bruts deviennent des projets d'extraction : avant-poste, ligne de foreuses, pétrole, eau, ou
porteurs si la matière existe mais n'arrive pas.

### 6.4 Les gabarits de modules (`shared/team/modules.lua`, pur, lot IA1-c)
Précision honnête : **les PNJ ne dessinent pas une usine tuile par tuile**. Ils **choisissent, dimensionnent,
placent, relient, agrandissent et remplacent des modules éprouvés**, comme un joueur qui pose ses plans favoris.
C'est ce qui rend la chose prouvable, peu coûteuse et sans blocage (question Q-IA1-4).

- **Un gabarit** contient :
  - des entités relatives (nom, dx, dy, direction, recette) ;
  - une emprise d'au plus 24 × 24 ;
  - des **ports** au bord (quai d'entrée, quai de sortie, tapis, tuyau) ;
  - des **points d'appui** dans la rue, d'où le PNJ construit à portée ;
  - son débit nominal (solveur), sa puissance, son époque et sa technologie, ses emplacements d'extension.
- **Un générateur paramétrique** produit les archétypes répétitifs, avec des rotations par matrices entières :
  - colonne de fours ×n ;
  - rangée d'assembleurs ×n ;
  - ligne de foreuses le long d'un tapis ;
  - labos ;
  - centrale à vapeur (1 pompe, n chaudières, 2n machines) ;
  - anneau de défense.
- **Les gabarits dessinés en jeu** couvrent les blocs complexes (pétrole, chimie). Un plan exporté en chaîne est
  converti hors jeu par `tools/team/bp2lua.py` (base64, zlib et json de la bibliothèque standard). Vous pourrez
  dessiner vos propres modules.
- **Exemples recalculés** (vanilla) :
  - colonne de 24 fours en pierre : 7,5 plaques/s ; en acier : 15/s, soit un tapis jaune ;
  - îlot de 6 assembleurs 2 de câbles et 4 de circuits verts : 6 circuits/s (ratio 3:2) ;
  - un assembleur 2 de circuits rouges : 0,125/s.
- **Validation** :
  - un contrôle hors jeu : pas de chevauchement, ports au bord, portée des bras, sens des tapis, puissance déclarée ;
  - le banc en moteur réel `ia1-modules` mesure chaque gabarit (§16).
- **Contrat avec les lots X (greffe P1)** :
  - chaque bâtiment d'un lot déclare sa famille de gabarit ;
  - chaque ressource déclare sa méthode d'extraction ;
  - le banc signale toute déclaration manquante.

  C'est la condition pour que les IA jouent réellement les époques 7 à 15.

### 6.5 Plan directeur et adaptation au terrain, sans F26
- **Lots et rues.** Autour du QG (ou de votre coffre d'équipe), une grille de **lots de 24 × 24** séparés par des
  **rues de 4 tuiles**, soit un pas de 28. Cela fait 8 lots en 1re couronne, 16 en 2e et 24 en 3e : 48 lots dans un
  rayon d'environ 100 tuiles.
  - Les rues restent libres. Elles portent :
    - la marche des PNJ, par points de passage en Manhattan, **sans pathfinder** ;
    - les **grands poteaux** aux carrefours (portée 30 pour un pas de 28) ;
    - les points d'appui des modules.
  - Cela règle F28 par construction (on ne vise plus l'intérieur d'un bâti), et F27 (chaque pôle a son quai et
    ses cases).
- **Évaluation d'un lot** : 3 à 5 appels moteur, **aucune entité posée**.
  1. `count_tiles_filtered{area, collision_mask = "water-tile", limit = 1}` ;
  2. `count_entities_filtered{area, type = "cliff", limit = 1}` ;
  3. `count_entities_filtered{area, type = "resource", limit = 1}`, pour garder les gisements à l'extraction ;
  4. bâtiments d'une autre force (lot contesté), ou les vôtres pour votre équipe ;
  5. arbres et rochers (coût du défrichage).

  Le résultat est gardé dans le lot (état, raison, tick) et **revalidé par un appel** juste avant d'implanter.
- **Rives** : `find_tiles_filtered` donne des candidats, puis `can_place_entity` teste la pompe dans les 4
  orientations. Ce sont des tests, pas des créations (F26).
- **Gisements** : la ligne de foreuses suit le grand axe des tuiles de ressource lues par la prospection.
  Pétrole : un chevalet par puits.
- **Falaises** : lot refusé, sauf si l'équipe a des explosifs de falaise (projet de défrichage).
- **Plus de lot libre** : le rayon s'élargit d'une couronne ; sinon, l'option « améliorer » gagne d'elle-même
  (§6.3).
- **Conduites et tapis courts** : A* pur sur la grille d'une zone bornée à 32 × 32, avec les obstacles lus par un
  `find_entities_filtered` et des souterrains pour sauter un obstacle. L'état de l'A* vit **dans global**, découpé
  en tranches de 256 nœuds par tick (§13).

### 6.6 Construire comme un joueur : les fantômes, et la règle d'automatisation
1. Le généraliste implante le module. Les fantômes sont posés par
   `create_entity{name = "entity-ghost", inner_name, force, expires = false}` après
   `can_place_entity{build_check_type = script_ghost}`, ou par `LuaItemStack.build_blueprint` (vérifiés ;
   `expires` existe en 1.1.91 : la durée de vie se règle à la pose). Au plus **10 fantômes par tick et par équipe**.
2. Les exécutants prennent au stock les objets d'un lot de fantômes et marchent jusqu'au point d'appui. Pour
   chaque fantôme à portée, ils retirent un objet de leur inventaire et appellent `ghost.revive{raise_revive = true}`
   (vérifié). La recette est réglée sur l'entité ravivée.
   - Rythme visé : une entité toutes les 10 ticks (estimé).
   - Un module de 60 entités prend 2 à 3 min à un PNJ, environ 40 s à quatre (estimé).
3. La portée de construction des PNJ passe de 10 à 16 tuiles (`character_build_distance_bonus`, vérifié), pour
   couvrir un lot de 24 depuis deux rues.
4. Ordre de pose : poteaux, machines, bras, puis tapis et tuyaux. Un fantôme bloqué (un PNJ qui passe, un ennemi)
   est repris plus tard ; au bout de 3 échecs, le module est signalé à son meneur (tâche `unblock`).
5. Les fantômes **montrent le plan à l'avance**, ce qui le rend lisible. À l'époque 10 (robots), des **roboports**
   dans les rues font construire ces mêmes fantômes par le moteur, en C++, sans coût de script : les PNJ passent
   alors à l'expansion et au territoire.
6. **Règle d'automatisation (greffe P1, `O.needs_automation`, testée)** : tout flux de **plus de 60 objets/min**,
   nécessaire **plus de 10 min**, sur **64 tuiles ou moins**, passe par un tapis ou une conduite. Portage et minage
   à la main sont plafonnés (§4.5) ; la fabrication à la main l'est à 30/min par objet. Sans cette règle, les
   lignes automatisées n'apparaissent jamais : 30 PNJ préféreraient porter et fabriquer à la main.

### 6.7 Logistique : elle suit les époques comme pour un joueur

| Époques | Entre modules et avant-postes | Dans un îlot |
|---|---|---|
| 1 à 3 | **porteurs** : au plus 20 cases par trajet (greffe P2 ; estimé à environ un tapis jaune à courte distance) | tapis et bras du gabarit |
| 4 à 9 | porteurs, plus **tapis d'îlot** entre lots voisins (rue traversée en souterrain) | idem |
| 10 et après | **robots logistiques du moteur** : les coffres de quai deviennent des coffres logistiques par fast_replace, roboports dans les rues | idem |

- La **Compaction ×4** (lot C) rend les porteurs viables longtemps : une pile ρ8 ou ρ32 porte 8 ou 32 fois plus de
  matière.
- **Trains et tapis longue distance** : pas dans IA1. Le risque est trop élevé ; ce sera un lot ultérieur si le
  banc l'exige.

### 6.8 Pétrole, eau, énergie : la fin de H-E1
- **Énergie** :
  - centrale à vapeur au bord de l'eau ;
  - une ligne de grands poteaux tous les 28 tuiles jusqu'à la base et jusqu'aux champs de pétrole (place trouvée
    par `find_non_colliding_position`, fils posés par `connect_neighbour`, vérifiés).
- **Pétrole**, comme vous l'avez décrit :
  - chevalets sur les puits, conduites (A* borné, §6.5), puis bloc raffinerie et chimie **posé près du champ**
    (greffe P1 : en fluides 1.1, le débit chute avec la longueur des conduites ; on raffine sur place et on
    transporte du solide) ;
  - le plastique et le soufre sortent sur un quai que vident les porteurs ;
  - l'eau du soufre vient d'une pompe de rive proche, sinon en barils portés (vanilla).
- **Moteurs** : un module d'assembleurs pour `engine-unit` (catégorie `advanced-crafting`, non fabricable à la
  main), sans quoi le pack chimique reste impossible même avec du plastique.
- **Critère** : l'équipe produit le pack chimique et passe la recherche 4 (C2-5).

### 6.9 Les époques des IA, sans tricher plus que nécessaire
- Chaque faction reçoit un **vrai centre de commandement** près de son QG, payé par sa production. Son niveau est
  son époque, comme pour vous.
- **Visé en réel par IA1 : les époques 1 à 6** (vanilla et contenu déjà en jeu). Au-delà, une IA joue réellement
  une époque **dès que les gabarits du lot X correspondant existent**.
- Le **crédit d'archive** de X0 (`X.faction_epoch`) devient un **plancher de rattrapage en objets** : une faction
  qui a 2 époques de retard sur son calendrier reçoit un « colis du Convoi » avec les matériaux manquants. Ce n'est
  plus une époque fictive. Écart déclaré : pour les époques 7 à 15, ce colis reste une aide tant que les gabarits
  manquent.

---

## 7. Conflit : territoire, gisements disputés, raids, déchiqueteurs

Vos mots : « un conflit en fait de production, un conflit d'évolution également de ressources, qui va réussir à
acquérir quelles ressources à certains endroits, un conflit entre les factions, pouvoir s'attaquer ».

### 7.1 Zones de territoire
- **Une zone** est un rectangle aligné sur les secteurs de 64 × 64 que le repérage PvP utilise déjà. Elle porte :
  - une priorité ;
  - ses PNJ, **2 par défaut**, comme dans votre exemple ;
  - un nombre de tourelles visé : **2 + ⌊époque ÷ 3⌋** (greffe P1), soit 2 à l'époque 1 et 7 à l'époque 15 ;
  - un état chiffré :
    - **tenue** : tourelles visées posées, 8 chargeurs ou plus chacune, aucune présence militaire ennemie ;
    - **contestée** : ennemi présent, ou tourelles sous le compte ;
    - **perdue** : aucune tourelle et ennemi présent depuis 60 s.
- Le contrôle d'une zone coûte environ 20 µs toutes les 300 ticks (un comptage filtré ; estimé).
- **Votre outil de zone** : un **outil de sélection** (`SelectionToolPrototype`, raccourci de barre). Vous tirez un
  rectangle, `on_player_selected_area` crée l'ordre de zone, et la sélection alternative
  (`on_player_alt_selected_area`) le retire (vérifiés).
- **Sans gâcher le visuel** : aucune surcouche permanente.
  1. Les tourelles posées sont le marqueur, dans le monde.
  2. Une **bordure pointillée fine, en mode Alt seulement**, visible de votre seule force : `draw_line` avec
     `dash_length`, `gap_length`, `only_in_alt_mode`, `draw_on_ground` et `players` (vérifiés).
  3. Une **étiquette de carte** par zone (`LuaForce.add_chart_tag`, vérifié), visible sur la carte seulement.
     L'affichage des dessins `rendering` en vue carte n'est pas vérifié (R6).

  Le jugement visuel vous revient, sur captures.

### 7.2 Gisements disputés : « qui va réussir à acquérir quelles ressources »
- **Registre des gisements à 4 états** (greffe P2) : libre, tenu, contesté, perdu, avec une étiquette de carte.
- **Revendication datée** (`Sites.claim` devient une propriété contestable) :
  - une faction peut viser le gisement d'une autre si sa **rareté** pour elle est forte (le fer aujourd'hui,
    mesuré) ;
  - une revendication non exploitée depuis 10 min est libérée (anti-squat, greffe P1).
- **Décision pure `S.contest`** (dans `shared/faction/strategy.lua`, lot IA0b puis IA1-g) : conquérir, contourner
  (chercher ailleurs) ou attendre. La valeur d'une zone de gisement = rareté × richesse ÷ défense estimée. Les
  soldats prennent la zone, puis la Défense la tient et les Gisements l'exploitent.
- **Gisements centraux** [à valider, décision par défaut] : à la fondation, un gros gisement (fer ou cuivre, en
  alternance) **à égale distance** de chaque paire de QG voisins, et un champ de pétrole au centre. Ce sont des
  points chauds, comme les objectifs d'une carte de MOBA.
- **Sape** (greffe P2) : le mode de zone « Conquérir » pose des tourelles hors de portée de la défense rivale, puis
  les avance. C'est un rôle offensif des constructeurs, sans armée.

### 7.3 Conflit de production et guerre d'usure
- Les **modules de production** adverses deviennent des cibles de raid.
- Tuer des PNJ adverses leur coûte des résurrections (§9), et tuer un généraliste gèle ses projets : c'est une
  guerre d'usure économique réelle.
- **Déchiqueteurs** : les usines des IA polluent, donc les attirent. Les zones servent aussi contre eux. La fenêtre
  d'évolution de X0, bornée par votre époque, s'applique toujours.

---

## 8. Interface de gestion de votre équipe

Vos mots : « une interface pour vraiment manager en fait ces équipes » ; « nous on pourrait diriger […]
l'orientation principale » ; « c'est à nous aussi de concentrer nos efforts sur tel ou tel aspect ».

**Accès** : un raccourci de barre et une touche (`ShortcutPrototype`, `CustomInputPrototype`, vérifiés). Éléments
d'interface 1.1.91 vérifiés : `tabbed-pane`, `slider`, `choose-elem-button`, `minimap`, `switch`, `progressbar`,
`table`, `scroll-pane` ; événements `on_lua_shortcut`, `on_gui_value_changed`, `on_gui_elem_changed`,
`on_gui_selected_tab_changed`.

**Les maquettes ci-dessous fixent le contenu, pas le style** : le style suivra le vanilla, et votre verdict sur
captures tranchera.

### 8.1 Onglet « Vue d'ensemble » (lecture)
```
┌ Équipe de l'Arche-5 ─ [Vue d'ensemble] [Orientation] [PNJ] [Territoire] [Chantiers] ─────────── [x] ┐
│ Époque 4 · Pétrole       Objectif : pack chimique (recherche 4)          PNJ 24 + 1 en résurrection  │
│                                                                                                      │
│ IL MANQUE (débit mesuré / besoin, par minute)                                                        │
│   Circuits verts     18 / 30   ███████████░░░░░░░   capacité       → « agrandir l'îlot 3 » (Lise)    │
│   Plastique           0 / 20   ░░░░░░░░░░░░░░░░░░   amont : pétrole → projet Pétrole (Marc) 34/52    │
│   Plaques de fer    240 / 210  ███████████████████   ok                                              │
│                                                                                                      │
│ EFFECTIFS     Extraction 10 (2 gén.)   Base 9 (2 gén.)   Territoire 5 (1 gén.)   Inactifs 8 %       │
│ MANAGERS      Gisements : 2 avant-postes, 1 ligne de foreuses en pose                                │
│               Logistique : 4 porteurs (plafond 5) ; tapis îlot 2 → 3 proposé                         │
│               Production : 6 modules (1 affamé : circuits verts)                                     │
│               Infrastructures : 14 améliorations faites, 3 en attente de stock                       │
│               Défense : 2 zones tenues, 1 contestée                                                  │
│ JOURNAL (20 derniers)                                                                    [voir tout] │
│   12:41  Ligue Azur conteste le gisement de cuivre C-2          [Conquérir ?] [Laisser] [→ carte]    │
│   12:38  Marc a fini la conduite du champ Est                                            [→ carte]   │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
```
- L'**arbre des manques** demande une décision quand il faut en prendre une (greffe P2 : « Conquérir ? »).
- Alertes : une par type et par minute au plus ; journal des 20 derniers événements ; `[→ carte]` appelle
  `LuaPlayer.zoom_to_world` (vérifié).

### 8.2 Onglet « Orientation » (vos priorités)
```
┌ Orientation ──────────────────────────────────────────────────────────────────────────────────────────┐
│ Préréglages : (Équilibre) (Ressources) (Améliorer la base) (Protection) (Expansion)                    │
│   Extraction  ──────────●────────── 40 %                                                               │
│   Base        ──────────●────────── 40 %        la somme reste à 100 % : les autres s'ajustent         │
│   Territoire  ─────●─────────────── 20 %                                                               │
│                                                                                                        │
│ CIBLES DE PRODUCTION                                     mesuré       état                             │
│   [circuit rouge ▾]   30 /min                           11 /min       solveur : 4 assembleurs + pétrole│
│   [plaque d'acier ▾]  60 /min                           62 /min       atteinte                         │
│   [+ ajouter]                                                                                          │
│ PRIORITÉS PERMANENTES                                                                                  │
│   [x] Fours de la ligne cuivre au niveau maximal       [x] Tourelles des zones au niveau maximal       │
│ INTERDITS          [ ] murs   [ ] foreuses   (familles que l'équipe n'améliore pas)                    │
│ RÉSERVES DU CENTRE (jamais touchées par l'équipe)  [acier ▾] 200   [plastique ▾] 100   [+]             │
│ MODE   (•) Assisté : l'équipe bâtit dans ses zones constructibles      ( ) Autonome                   │
└────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```
- Un curseur ne s'applique qu'à la pensée suivante (5 s au plus) : un glisser émet plusieurs événements, seule la
  dernière valeur compte.
- **Réserves du centre** (greffe P2) : l'équipe ne vide jamais ce que vous gardez pour vous.

### 8.3 Onglet « PNJ »
```
┌ PNJ (24/25, plafond de l'époque : 25) ─────────────────────────────────────────── [Recruter : 34 fer] ┐
│ Nom        Rôle          Pôle         Rang  Tâche                       PV     Actions                  │
│ Lise       Généraliste   Extraction   4     mène : îlot circuits 3      100 %  [pôle ▾] [rappeler]       │
│ Marc       Généraliste   Base         3     mène : Pétrole (34/52)      80 %   [pôle ▾] [rappeler]       │
│ Ana        Exécutante    Extraction   2     porte 20 cases → quai 2     100 %  [pôle ▾] [promouvoir]     │
│ ...                                                                                                     │
│ DISPARUS                                                                                                │
│ Yanis      Généraliste   Territoire   5     mort à 12:31 (Ordre Écarlate)      [Ressusciter : 50 s]     │
│                                             coût : 125 fer, 10 plastiques, pistolet, 10 chargeurs (vert)│
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 8.4 Onglet « Territoire »
```
┌ Territoire ───────────────────────────────────────────────────────────────── [Outil de zone] ┐
│ Zone          État        PNJ   Tourelles    Munitions     Mode                              │
│ Gisement C-2  contestée   2     3/4          9 chargeurs   [Tenir ▾] Tenir / Conquérir (sape)│
│ Champ Est     tenue       2     4/4          18            [Tenir ▾]                          │
│ ┌──────────────┐  mini-carte de la zone choisie (minimap)                                   │
│ │   ·  ▲  ·    │  Affichage : bordure pointillée en mode Alt seulement ; étiquette de carte │
│ └──────────────┘                                                                            │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 8.5 Onglet « Chantiers »
```
┌ Chantiers ─────────────────────────────────────────────────────────────────────────────────────────┐
│ Projet                      Meneur   Avancement        État                     Actions             │
│ Îlot circuits verts n° 3    Lise     41/60 entités     fantômes posés           [annuler]           │
│ Pétrole : champ Est         Marc     conduite 34/52    en cours                 [annuler]           │
│ Labo ×4                     —        —                 attend un généraliste    [priorité ▲]        │
│ VOS ORDRES  fantômes posés par vous : 12 (ravivés par l'équipe)  ;  à démonter : 3                   │
│ [Outil « Ordre d'amélioration »]  sélection : niveau suivant ; sélection alternative : niveau maximal│
│ [Zones constructibles]   [x] Valider chaque plan avant la pose des fantômes                          │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
```
- **Ordres directs avec les outils vanilla** (greffe P2) :
  - les fantômes et copier-coller que vous posez sont ravivés par vos PNJ, avec les objets du coffre d'équipe ;
  - le planificateur de déconstruction leur donne du démontage (`on_marked_for_deconstruction`, vérifié) ;
  - un **outil « Ordre d'amélioration »** (outil de sélection) crée des tâches `upgrade`. Le planificateur
    d'amélioration vanilla ne convient pas : les bâtiments de niveau n'ont pas de `next_upgrade`, pour que le
    planificateur ne contourne ni le coût ni le plafond (ARCHITECTURE §7 bis).

### 8.6 Pilotage sans clic (bancs)
- Commande `/fo-team`.
- Interface distante : `team_status`, `set_orientation`, `set_target`, `add_zone`, `kill_npc`, `resurrect`,
  `promote`.

Elles servent aux bancs (aucun clic) et aux captures avec `show_gui` (F51).

En multijoueur, l'état est par force et chaque action garde l'index du joueur. Un onglet « Renseignement », en
lecture seule et en mode débogage, suivra les équipes IA.

---

## 9. Résurrection et recrutement (`O.resurrection`, `O.recruit_cost`, `O.revive_policy`, testés)

Vos mots : « pouvoir également ressusciter des workers, […] à combien ça coûte ».

- **Mort** : le personnage laisse son cadavre et son inventaire, 15 min (vérifié), qu'une tâche `recover` peut
  aller chercher. La fiche du PNJ (nom, rang, expérience, rôle, pôle) passe au **registre des disparus**.
- **Résurrection** au centre de commandement (au QG pour une faction sans centre, à votre coffre d'équipe faute
  de centre) [à valider] :

  | Rang | Coût (époque 1) | Coût (époque ≥ 2) | Délai |
  |---|---|---|---|
  | 1 | pistolet + 10 chargeurs + 25 fer | + 2 matériau de l'époque | 10 s |
  | 3 | + 75 fer | + 6 matériau | 30 s |
  | 5 | + 125 fer | + 10 matériau (par exemple 10 batteries à l'époque 6) | 50 s |

  - Délai = 10 s (le `respawn_time` vanilla du personnage, défaut vérifié dans `prototype-api.json`) + 10 s par rang
    au-delà du premier.
  - Réglage `fo-resurrection-cost` (0 à 5) : il multiplie le surcoût (fer et matériau), jamais le kit.
  - Une résurrection à la fois par centre, plus une tous les 5 niveaux du centre.
  - **Le PNJ revient avec son nom, son rang, son expérience et son rôle.** Un généraliste ressuscité reprend son
    projet s'il est encore libre.
- **Recruter** : un PNJ de rang 1 coûte le kit + (10 + effectif actuel) plaques de fer (40 à 30 PNJ). C'est moins
  cher, mais on perd l'expérience.
- **Politique des IA** (et bouton « automatique » de votre équipe) :
  - ressusciter un PNJ de rang 2 ou plus si le stock le permet ;
  - sinon recruter ;
  - sinon attendre.

  L'embauche de secours sans arme (E16 it. 9) est conservée.

---

## 10. Progression des PNJ, comparée au joueur (`O.rank`, `O.gain`, `O.modifiers`, testés)

Vos mots : « peut-être qu'ils pourront crafter plus vite, s'améliorer plus vite, se déplacer légèrement plus vite
aussi, que le joueur principal ».

- **Modificateurs PAR PERSONNAGE**, en lecture et écriture sur `LuaControl` (vérifié dans `runtime-api.json`) :
  - `character_crafting_speed_modifier`, `character_mining_speed_modifier`, `character_running_speed_modifier` ;
  - `character_inventory_slots_bonus`, `character_build_distance_bonus`, `character_reach_distance_bonus`.
- **Piège** : `LuaForce.manual_crafting_speed_modifier` et ses voisins s'appliquent à toute la force, **vous
  compris**. Pour que vos PNJ dépassent le joueur, on n'écrit que les modificateurs par personnage.
- **Référence vanilla** (relue dans `data/base/prototypes/entity/entities.lua`) : course 0,15 tuile/tick, minage 0,5,
  inventaire 80, portée de construction 10.
- **Expérience = minutes de travail utile.** Une tâche de conception compte double, une victime rapporte 2.
  - Seuils des rangs : 0, 30, 120, 360 et 900 min de travail.
  - Le rang 5 arrive donc vers 15 h de travail, soit environ 30 h de jeu à mi-temps : la progression dure toute la
    partie de 60 h.
- **Profil « léger »** (défaut) [à valider] :

| Rang | Fabrication | Minage | Course | Inventaire | Portée |
|---|---|---|---|---|---|
| 1 | ×1 (comme vous) | ×1 | +0 % | +0 | +6 (lots de 24) |
| 2 | ×1,25 | ×1,25 | +4 % | +10 | +6 |
| 3 | ×1,5 | ×1,5 | +8 % | +20 | +6 |
| 4 | ×2 | ×2 | +12 % | +30 | +6 |
| 5 | ×3 | ×2,5 | **+15 %** | +40 | +6 |

- Au rang 5, cela donne une course de 0,1725 tuile/tick (contre 0,15), un minage de 1,25 (contre 0,5) et 120 cases
  (contre 80).
- **Autres profils** :
  - « égal » : aucun bonus (la portée +6 reste, nécessaire aux lots) ;
  - « fort » : bonus ×1,5, mais la course reste plafonnée.
- **Course plafonnée à +15 %** pour tout profil et toute difficulté : c'est votre « légèrement plus vite ». Avec
  ses exosquelettes, le joueur reste plus rapide en fin de partie.
- **Difficulté des IA** : bonus ×0,8 en Paisible et Facile, ×1 en Normal, ×1,1 en Difficile, ×1,25 en Impitoyable.
  C'est une seule table, comme pour IA0.
- Non vérifié : que ces modificateurs agissent sur un personnage sans joueur, et qu'ils s'ajoutent à ceux de la
  force (expérience R5).

---

## 11. Tailles et réglages (`settings/team.lua`, fichier nouveau du lot)

| Réglage | Défaut | Plage | Remarque |
|---|---|---|---|
| `fo-factions` | 4 | 0 à 4 | lu au lancement de la guerre. Au-delà de 4, il faudrait des équipages hors du récit X0 (le Convoi en compte 4) : non retenu par défaut |
| `fo-team-npc-max` | 30 | 6 à 60 | PNJ par faction (remplace `F.defaults.engineers_max = 10`) |
| `fo-player-team-npc-max` | 30 | 0 à 60 | votre équipe (remplace `T.player_workers_max = 8`) |
| `fo-team-chiefs` | 5 | 1 à 8 | plafond des généralistes (1 pour 6 PNJ) |
| `fo-npc-start` | 8 | 2 à 30 | effectif de départ (2 aujourd'hui), borné par le plafond de l'époque 1 |
| `fo-npc-bonus` | léger | égal, léger, fort | §10 |
| `fo-resurrection-cost` | 1,0 | 0 à 5 | multiplicateur du surcoût |
| `fo-agents-max` | 300 | 50 à 600 | **garde de performance comptée en agents** (pas en temps : règle 4). Au-delà, le recrutement est suspendu |
| `fo-team-entity-cap` | 4 000 | 500 à 20 000 | entités bâties par équipe (coût moteur, §12) |
| `fo-path-issue-per-tick` | 2 | 1 à 6 | demandes de chemin émises par le mod et par tick (§12) ; s'ajoute à `fo-path-max-inflight` (6) |

**Plafond d'effectif par époque** [à valider] : la moitié du maximum à l'époque 1, 5/6 à l'époque 2, tout ensuite.
Cela donne :
- 15, 25 puis 30 pour 30 PNJ ;
- 5, 9, puis 10 pour 10 PNJ ;
- 25, 42, puis 50 pour 50 PNJ.

30 PNJ sont donc atteignables vers 1 h 30 au calendrier X0. La cohérence narrative : les dormeurs de l'Arche qu'on
réveille.

---

## 12. Budget de script chiffré

**Mesures de référence** (moteur réel, banc épinglé ; recalculées par le rédacteur pour ia0-normal) :

| Source | Contenu | Script moyen | Détail |
|---|---|---|---|
| ia0-normal (journal archivé, 216 000 ticks) | 4 équipes, 28 PNJ, guerre en Normal | **0,065 ms** (p99 0,57 ; max 9,9) | voie `fo-brain` 0,012 ms (0,43 µs/PNJ/tick) ; `fo-loco` 0,0072 (0,26 µs/PNJ/tick) ; pensées d'équipe 0,0082 (0,62 ms par pensée) ; prospection 0,0088 ; repérage PvP 0,0048 ; chemins 0,0019 côté script ; pathfinder (C++) 0,008 ms (p99 0,28) ; 3 062 chemins, latence moyenne 0,5 tick ; `entityUpdate` 0,157 ms ; tick complet 0,32 ms (p99 1,87) |
| E22, `stress` | 402 agents riches | **0,50 ms** (p99 1,5) | 1,24 µs par agent et par tick, dont locomotion 0,65 |
| E17 | environ 70 agents et 4 cerveaux | 0,10 ms | — |
| `org_test` / mesure hors jeu (Lua 5.2.4, PC non épinglé, autres agents actifs : ordre de grandeur) | `O.plan`, `O.pick_task` | — | `O.plan` : environ 0,1 à 0,2 ms par pensée pour 30 à 60 PNJ ; `O.pick_task` : environ 0,2 µs par tâche parcourue |

**Projection pour 150 PNJ** (4 × 30 + votre équipe de 30) :

| Poste | Calcul | ms/tick |
|---|---|---|
| Pensée des PNJ (`fo-brain`) | 150 × 0,43 µs | 0,064 |
| Locomotion | 150 × 0,26 µs | 0,039 |
| Pensées d'équipe | 5 équipes × environ 2 ms par pensée (0,62 mesuré, plus `O.plan` environ 0,15, plus solveur et lots estimés) ÷ 300 | 0,033 |
| Prise de tâche | 150 prises par minute × environ 100 tâches × 0,2 µs | 0,001 |
| Construction et transferts | environ 5 entités/s × 30 µs, plus les dépôts (estimé) | 0,005 |
| Suivi des modules | 500 modules × 10 µs ÷ 600 (estimé) | 0,008 |
| Territoire | 50 zones × 20 µs ÷ 300 (estimé) | 0,003 |
| Prospection et terrain | mesure × 5/4, plus 4 lots × 30 µs ÷ 300 par équipe | 0,013 |
| PvP, chemins côté script (× 5), interface | mesures | 0,020 |
| **Total IA1 (coefficients ia0-normal)** | | **≈ 0,19** |
| **Majorant** (150 × 1,24 µs de E22, plus le reste) | | **≈ 0,27** |
| **Cible du lot** | | **≤ 0,40 ms en moyenne** ; p99 du script total ≤ 1,5 ms ; pire tick ≤ 10 ms |

**Pics, par construction et en unités de travail (règle 4)** :
- La pensée est **découpée en 4 phases**, sur 4 ticks consécutifs : vue, solveur, projets et organisation, tableau.
  Les équipes sont décalées de 60 ticks : au plus **une phase par tick pour tout le mod**.
- Plafonds par phase :
  - 60 nœuds de recette ;
  - 4 évaluations de lot ;
  - 10 fantômes par tick et par équipe ;
  - A* de 256 nœuds par tick.
- `O.plan` compte son travail (`ops`) : 215 unités pour 10 PNJ, 511 pour 30 et 945 pour 60, soit une croissance
  presque linéaire (testé : ≤ 8 × entre 10 et 60 PNJ).
- La reconstruction du livre de recettes (2,3 ms mesurés à la 1re pensée, chiffre de la proposition) a son propre
  tick, une fois par recherche.

**Pathfinder** (10 nouvelles requêtes par tick, partagées avec les déchiqueteurs et les unités ; 1 000 pas par tick,
`map-settings.lua` ligne 153, vérifié) :
- Aujourd'hui : 0,86 requête/s pour 28 PNJ. Pour 150 PNJ, en linéaire : 4,6 req/s, soit **0,077 par tick, 0,8 % de
  la limite**.
- La marche dans la base se fait par les rues, sans pathfinder : on attend 2 à 3 req/s.
- Garde : 2 émissions par tick au plus pour le mod, ce qui laisse au moins 8 au moteur.
- On suit au banc la latence (p95) et les pas consommés. Un cache des routes longues n'est ajouté que si
  `ia1-scale` dépasse 1 req/tick en pointe : déclencheur mesuré, pas spéculatif.

**Coût moteur, hors budget A1, mais les 60 UPS en dépendent : non mesuré.**
- Chaque base d'IA ajoute des machines, des bras et des tapis : environ 1 500 entités par équipe à l'époque 6
  (estimé), soit environ 8 000 au total.
- `entityUpdate` vaut 0,157 ms aujourd'hui ; son coût avec ces usines est **inconnu**.
- D'où la garde `fo-team-entity-cap`, et la mesure de `entityUpdate` et `wholeUpdate` dans `ia1-war2h` avant de
  déclarer C5-7.

---

## 13. Déterminisme, sauvegarde, multijoueur

- Tout le pur vit dans `shared/team/` : `org` (livré), puis `production`, `modules`, `layout`, `territory`. Il est
  testé hors jeu sur les **vraies recettes**, avec double passage et comparaison canonique (`org_test.lua` le fait
  déjà, y compris avec un ordre d'entrée mélangé et une copie profonde).
- **Règle multi-tick (multijoueur)** : tout calcul étalé sur plusieurs ticks (phases du cerveau, A*, implantation
  des fantômes) garde son **état dans global**. Raison : un client qui rejoint en cours de calcul n'a pas les caches
  locaux ; s'il recalculait depuis un monde qui a changé, ce serait une désynchronisation. Les caches locaux ne
  sont permis que s'ils se déduisent à coup sûr de l'état courant (livre de recettes, gabarits instanciés).
- Pas de coroutine, pas de fonction dans global, `on_load` inerte. Itérations triées ; rotations par matrices
  entières ; arithmétique entière pour les coûts et les plafonds. Piège évité, vérifié en Lua 5.2 : arrondi au-dessus,
  10 × (1 + 0,1 × 14) vaut 24,000000000000004, donc 25 au lieu de 24 (9 valeurs fausses entre 0 et 60 PNJ) ; le
  modèle calcule 10 + 14.
- Le **travail compté** de `O.plan` ne dépend que des tailles, pas de l'ordre d'entrée : les tris sont comptés
  n × ⌈log2 n⌉, et non au nombre d'appels du comparateur.
- **Sauvegarde légère** :
  - un module en mémoire = (clé de gabarit, lot, rotation, état) ; ses entités se recalculent ;
  - un PNJ pèse environ 1 Ko ;
  - le total est estimé sous 1 Mo pour 5 équipes.
- **Migration** (schéma suivant, `script/core/storage.lua`, intégrateur) :
  - avant-postes et PNJ existants conservés ;
  - leurs pôles et leurs rôles sont fixés à la 1re pensée (recrues sans pôle : `place`), jamais dans `on_load` ;
  - l'ancien tableau devient le tableau commun, chaque tâche portant son pôle.
- **Multijoueur réel** : non vérifié, faute de banc à deux clients. La preuve possible : déterminisme hors jeu,
  plus deux passages en moteur à la même graine avec des empreintes `[FO-HASH]` identiques.

---

## 14. Risques moteur et expériences préalables (lot IA1-0, scénario `ia1-risques`)

| N° | Ce qu'on ignore | Expérience (E35 et suivantes) | Repli |
|---|---|---|---|
| R1 | Le remplacement d'un bâtiment de niveau par un PNJ sans `character` garde-t-il contenu et recette sans objet en trop ? (contrôle de F39 dans ce cas) | améliorer un four porté par un PNJ ; compter les objets de niveau de toute la carte avant et après | réinsertion manuelle comptée (`fallback`, exigé à 0) |
| R2 | Les fantômes d'une force de script sont-ils visibles par vous ? Vos robots bâtissent-ils les fantômes de votre équipe avec vos objets ? | 1 module de faction et 1 de votre équipe, avec un roboport proche | votre équipe : pose « juste à temps », un module à la fois |
| R3 | Les roboports d'une force IA bâtissent-ils ses fantômes et assurent-ils sa logistique ? | roboport, plus robots de construction dans un coffre de stockage | rester sur les PNJ |
| R4 | Coût réel de `count_entities_filtered{area 24 × 24, limit = 1}` et de `can_place_entity` | 1 000 appels chronométrés en série | réduire les évaluations par phase |
| R5 | Les modificateurs `character_*` agissent-ils sur un personnage sans joueur ? S'ajoutent-ils à ceux de la force ? | PNJ contre personnage témoin : 100 engrenages, 60 s de marche, 60 s de minage, avec et sans bonus de force | modificateurs de force pour les factions, mais jamais pour votre équipe |
| R6 | Un dessin `rendering` s'affiche-t-il en vue carte ? | capture en carte | étiquettes de carte seules |
| R7 | Un coffre lié (`LinkedContainerPrototype`, `link_id`) partage-t-il un inventaire par force ? | 2 coffres, même `link_id`, 2 forces | porteurs seuls |
| R8 | Débit des conduites des gabarits pétrole (en fluides 1.1, le débit chute avec la longueur) | banc `ia1-modules` | conduites courtes, souterrains, raffinage sur place |
| R9 | Foule de PNJ : collisions dans les rues, fantômes bloqués par un PNJ qui passe | `ia1-build` | points d'appui hors emprise, reprise différée |
| R10 | Les déchiqueteurs attirés par la pollution des usines IA rasent une faction | `ia1-war2h` | fenêtre d'évolution X0, zones de défense, plafond d'entités |
| R11 | Équilibrage : 30 PNJ qui minent à la main font 15 minerais/s (0,5/s chacun : minage 0,5 et `mining_time` 1, vérifiés), 7,5 fois les 2 MU/s moyens de l'époque 1 (X0, §3.1) | `ia1-scale` : débit livré par équipe, minute par minute | plafond du travail manuel (§4.5) ; recalibrage du calendrier (Q-IA1-1) |
| R12 | `entityUpdate` des usines des IA (environ 8 000 entités, estimé) | `ia1-war2h`, banc épinglé | `fo-team-entity-cap`, modules moins nombreux mais améliorés (l'option « améliorer » coûte peu d'entités) |

---

## 15. Critères d'acceptation mesurables (C5-1 à C5-7 repris et chiffrés ; C5-8 à C5-10 proposés) [à valider]

| ID | Critère | Mesure en moteur réel |
|---|---|---|
| C5-1 | Taille réglable : 30 PNJ par faction, 4 factions par défaut | à 90 min, chaque faction a au moins 27 PNJ vivants ou en résurrection ; réglage à 10 puis à 60 : effectifs conformes aux plafonds par époque ; votre équipe à 30 |
| C5-2 | Un cerveau par équipe ; managers et généralistes qui répartissent les PNJ | une pensée par équipe et par période (trace) ; généralistes = ⌈effectif ÷ 6⌉ au plus 5 ; perte forcée de l'avant-poste de fer : +3 PNJ à l'extraction en 2 pensées (10 s) ; au plus 6 changements de pôle par PNJ et par heure ; **inactivité moyenne ≤ 15 % par équipe entre 30 et 90 min** (aujourd'hui : 24,3 % en moyenne sur 4 équipes de 6 à 8, et un instantané à 50 % chez Émeraude) ; part du travail manuel (tournées et minage à la main) ≤ 40 % à 90 min (aujourd'hui : 50 % à 59 min) |
| C5-3 | Vraies lignes automatisées, et améliorations | dans les 90 min (Normal), chaque faction a au moins 3 modules dont la production avance 5 min **sans aucun PNJ** (`products_finished`), dont un de circuits verts ; **pack chimique et recherche 4 atteints** (C2-5) ; au moins 10 bâtiments améliorés par un PNJ porteur du coût ; 0 module sur l'eau ou sur une falaise ; au moins 90 % des modules commencés sont finis ; sur **3 graines** |
| C5-4 | Votre équipe se pilote par l'interface | un curseur fait atteindre sa cible à un pôle, à 1 près, en 10 s ou moins (testé hors jeu : 2 pensées) ; la cible « circuits verts 30/min » atteint au moins 80 % (statistiques de force) en 20 min ou moins, ressources disponibles ; captures de l'interface, puis **votre verdict** |
| C5-5 | Résurrection à coût et délai chiffrés | PNJ tué puis ressuscité après le délai de la table, à 1 s près ; coût retiré exactement (différence de stock) ; rang, expérience et rôle conservés ; refus si le stock manque |
| C5-6 | Progression mesurée contre le joueur | même scénario, personnage témoin : au rang 1, ±5 % ; au rang 5 (profil léger), fabrication ×3, minage ×2,5, course +15 % (±5 %), inventaire +40 |
| C5-7 | 4 × 30 se disputent les gisements et s'attaquent, A1 tenu | 2 h de jeu : au moins 1 gisement change de propriétaire, au moins 1 attaque vise une zone de gisement ; script IA1 ≤ 0,40 ms et script total ≤ 1,5 ms en moyenne ; p99 ≤ 2 ms ; moins de 0,01 % des ticks au-delà de 16,7 ms ; `wholeUpdate` et `entityUpdate` mesurés et publiés |
| C5-8 | Territoire sans gâcher le visuel | zone ordonnée avec 2 PNJ : au moins 2 tourelles en 5 min ou moins, munitions ≥ 8 chargeurs pendant 30 min sous pression ; rien de visible hors mode Alt et carte ; captures, puis **votre verdict** |
| C5-9 | Déterminisme | deux passages à la même graine : empreintes `[FO-HASH]` identiques à 30 min ; hors jeu : sauvegarde et rechargement identiques (fait pour `org.lua`) |
| C5-10 | Rythme (greffe P2, recalé sur le calendrier) | recherche 1 en 8 min ou moins (aujourd'hui 12 à 25 min) ; chaque faction atteint ses époques à 25 % près de l'heure du joueur nominal (contrôle de X0) ; au moins un événement visible (bâtiment, module, zone) toutes les 3 min par équipe |

---

## 16. Découpage en lots, avec preuves en moteur réel

Ordre fixé par Q18 : IA1 se construit en parallèle de la Compaction, juste après le visuel, sur des fichiers
distincts. Chaque lot suit la définition de « terminé » d'OBJECTIFS §7 :
- bancs hors jeu verts ;
- étape data sans nouvelle erreur, api_lint à 0 ;
- `content` vert en moteur réel ;
- captures pour ce qui se voit ;
- documents à jour.

| Lot | Contenu | Dépend de | Preuve en moteur réel (banc épinglé) | Hors jeu |
|---|---|---|---|---|
| IA1-0 Levée des risques (S) | expériences R1 à R9 | — | `ia1-risques` : un verdict chiffré par expérience dans RD_LOG (E35 et suivantes, faits F67 et suivants) | — |
| IA1-a Échelle 30 (M) | `settings/team.lua` ; recrutement par paliers ; au moins 36 cases au QG en table constante ; tableau trié une fois par pensée (`O.sort_tasks`, `O.pick_task`) ; garde d'agents ; ≤ 2 chemins émis par tick ; correctifs `pairs` (planner.lua l. 131) et trigonométrie | 0 | `ia1-scale`, 60 min, 4 × 30 + 30 : script ≤ 0,25 ms ; échecs de chemin ≤ 5 % ; « but occupé » ≤ 20 ; non-régression `ia0-normal` et `content` ; **inactivité et surplus publiés** (attendus élevés : ce lot ne crée pas encore de travail) | pteam, war, migration, org |
| IA1-b Pôles, managers, généralistes (M) | `org.lua` branché sur `team.lua` et `board.lua` ; rapports d'une ligne par manager et par généraliste ; interface v0 en lecture ; interface distante | a | `ia1-poles` : orientation changée, effectifs à la cible en 10 s ; crise injectée, +3 en 2 pensées ; ≤ 6 changements par PNJ et par heure ; une pensée par équipe et par période | org (fait : 260 OK) |
| IA1-c Gabarits (M) | catalogue, générateur, contrôle des gabarits, `bp2lua.py` | 0 | `ia1-modules` : chaque gabarit posé dans une arène, alimenté par des coffres infinis et une interface électrique, **débit à ±10 % du nominal** sur 5 min ; captures | contrôle de tous les gabarits |
| IA1-d Plan directeur et construction (L) | lots et rues, évaluation du terrain, fantômes, construction par les PNJ, énergie, poteaux, marche par les rues | b, c | `ia1-build` sur 3 graines (eau, falaises, plaine) : 0 chevauchement ; **au moins 90 % des modules commencés finis (porte du lot e)** ; refus de lot classés par raison ; captures | évaluation de lots sur cartes synthétiques |
| IA1-e Production adaptative et pétrole (L) | solveur de débits, diagnostic, choix agrandir / améliorer / remplacer / construire, règle d'automatisation, chaîne pétrole, assembleur à moteurs, A* borné | d (porte à 90 %) | `ia1-oil` : depuis la recherche 3, pack chimique puis recherche 4 ; module affamé détecté ; flux de plus de 60/min automatisés ; **H-E1 close** si c'est vert | solveur sur les vraies recettes (jeu d'essai du §6.1) |
| IA1-f Améliorations et époques réelles (M) | tâche `upgrade` (`O.trip_capacity`), priorités permanentes, centre de commandement des factions, plancher d'archive en objets | e, **V2c** | `ia1-levels` : au moins 10 améliorations par un PNJ porteur ; plafond respecté ; `fallback = 0` ; **0 objet de niveau dupliqué** ; époques 1 à 6 en réel | — |
| IA1-g Territoire et gisements disputés (L) | zones, outil, garnisons, sape, gisements centraux, revendication datée, `S.contest`, cibles de raid | b, **IA0b** | `ia1-territory` (C5-8) ; captures en mode Alt et en vue normale, puis votre verdict | stratégie pure |
| IA1-h Résurrection et progression (S) | modèle déjà testé (`org.lua`) branché : modificateurs, expérience, registre des disparus, résurrection au centre | a | `ia1-progress` (C5-5, C5-6) contre un personnage témoin | coûts, délais, seuils (fait) |
| IA1-i Interface de gestion (M) | 5 onglets, cibles de production, réserves, modes, outils de zone, d'amélioration et de zones constructibles | b, e, g | `ia1-gui` : pilotage par l'interface distante, puis captures avec `show_gui` (F51) ; votre verdict | modèle de l'interface |
| IA1-z Grande guerre de validation (S) | aucun code nouveau | tous | `ia1-war2h` (C5-7, C5-10) et `ia1-hash` deux fois (C5-9) ; journaux dans `fo-logs\` | — |

Durées : 4 h de jeu prennent environ 5 à 15 min réelles au banc épinglé (E17 : 30 min en 40 s). Ce chiffre se
dégradera avec les usines des IA (non mesuré).

---

## 17. Questions au Directeur Créatif (5)

1. **Q-IA1-1 · Le calendrier de 60 h avec des équipes de 30.** 30 PNJ font beaucoup plus que le joueur seul que
   supposait le calendrier X0 : à la main seulement, 15 minerais/s, contre 2 MU/s en moyenne à l'époque 1.
   **Proposition recommandée** : garder une partie longue (Porte vers 60 h) en recalibrant les coûts des époques
   sur « joueur + équipe » au lot V2c. L'« évolution nette, rapide » se sent alors dans les premières époques et
   dans l'activité visible des équipes. Les factions IA progressent par leur production réelle ; le crédit
   d'archive devient un simple plancher de rattrapage.
2. **Q-IA1-2 · La montée des effectifs.** **Proposition recommandée** : départ à 8 PNJ (dont 2 généralistes),
   plafonds de 15, 25, puis 30 aux époques 1, 2 et 3, soit 30 vers 1 h 30 ; même règle pour votre équipe, réglable
   de 6 à 60.
3. **Q-IA1-3 · La progression et la résurrection.** **Proposition recommandée** : le profil « léger » (au rang 5 :
   fabrication ×3, minage ×2,5, course +15 % au plus, +40 cases), avec des rangs à 30 min, 2 h, 6 h et 15 h de
   travail ; une résurrection en 10 s plus 10 s par rang, pour le kit, 25 fer par rang et 2 matériaux d'époque par
   rang ; un PNJ qui revient avec son rang et son rôle.
4. **Q-IA1-4 · La « conception » des usines.** Les PNJ composent des **modules éprouvés** (gabarits), dimensionnés
   par le solveur de débits, adaptés au terrain par le plan directeur, agrandis, améliorés ou remplacés. Ils ne
   dessinent pas tuile par tuile. **Proposition recommandée** : oui, et vous pourrez dessiner vos propres modules
   en jeu (plan exporté, converti par `bp2lua.py`).
5. **Q-IA1-5 · Votre base et vos PNJ.** **Proposition recommandée** : le mode « Assisté » par défaut. Vos PNJ ne
   bâtissent que dans des **zones constructibles** que vous tracez ; leurs fantômes montrent le plan avant la pose ;
   ils ne touchent jamais à vos **réserves** ; vos propres fantômes et ordres d'amélioration passent en premier.
   Le mode « Autonome » (sans zones) et l'interrupteur « Valider chaque plan » sont en option.

**Décisions prises par défaut** (réversibles, sans question) :
- 4 factions au plus, celles du récit X0 ;
- porteurs seuls au départ, sans coffres liés au QG, comme un joueur ;
- territoire affiché en mode Alt et sur la carte seulement, sous réserve de votre verdict sur captures ;
- pas de commandos de PNJ : ce sont les soldats qui attaquent ;
- gisements centraux à la fondation.

---

## 18. Le modèle pur livré : `shared/team/org.lua`

Lua pur, sans API, comme le reste de `shared/`. Il ne décide pas **quoi** faire (le cerveau, puis le solveur) ni
**comment** (les programmes d'étapes) : il décide **qui fait quoi**.

| Fonction | Rôle |
|---|---|
| `O.plan(input)` | une pensée d'organisation : orientation normalisée, besoin par pôle, cibles d'exécutants, placement des recrues, mouvements (hystérésis), promotion, pôles des généralistes, meneurs des projets, taux d'inactivité, travail compté (`ops`) |
| `O.pole_targets`, `O.generalist_quotas`, `O.apportion` | répartitions entières déterministes (plus fort reste, égalités par l'ordre fixe des pôles) |
| `O.sort_tasks`, `O.pick_task` | tableau trié une fois par pensée, puis un seul passage par prise (remplace le tri complet de `Board.claim`) |
| `O.demand_from_tasks`, `O.TASK_DOMAIN`, `O.DESIGN_KINDS`, `O.MANUAL_KINDS`, `O.TASK_WORK` | domaines, conception réservée, travail manuel plafonné, durées estimées (à mesurer au lot IA1-b) |
| `O.needs_automation`, `O.manual_cap` | règle d'automatisation et plafonds de travail manuel |
| `O.headcount_cap`, `O.start_headcount`, `O.generalists_wanted` | effectifs |
| `O.rank`, `O.gain`, `O.modifiers` | progression (modificateurs par personnage, course plafonnée) |
| `O.resurrection`, `O.resurrection_slots`, `O.recruit_cost`, `O.revive_policy` | résurrection et recrutement (listes triées, arithmétique entière) |
| `O.trip_capacity` | amélioration instantanée : combien de bâtiments en un trajet |

**`tests/org_test.lua` : 260 OK, 0 échec.** Il couvre :
- les tables, y compris les types de tâches lus dans `planner.lua` ;
- l'orientation ;
- les plafonds aux tailles 10, 30, 50 et 60 ;
- 500 tirages de répartition ;
- le déterminisme : double passage, ordre mélangé, copie profonde, entrée non modifiée ;
- l'hystérésis : convergence, puis 0 mouvement en 100 pensées, et au plus 6 changements par PNJ en 1 h d'ordres
  contradictoires ;
- la réaction au curseur (cible en 2 pensées), à une crise (+3 en 2 pensées) et à une menace ;
- la promotion (pas avant 2 min, la meilleure) ;
- les meneurs de projets (stables, chantier commencé repris d'abord) ;
- la prise de tâche ;
- le coût compté ;
- la résurrection, le recrutement et la progression (course jamais au-delà de +15 %, monotonie sur 3 profils et 6
  difficultés) ;
- la règle d'automatisation ;
- l'amélioration en un trajet ;
- la compatibilité avec le cerveau actuel sur les vraies recettes, et la cause de H-E1 (moteur, plastique et
  soufre non fabricables à la main).

---

## 19. Corrections apportées à la proposition gagnante, greffes retenues et écartées

**Incohérences corrigées** (dites, comme le veut R5) :
1. **Date du « 6 »** : la proposition écrivait « une règle de 2020-10 ». C'est faux : la règle date des sessions 2
   à 4 (20 et 21/10/2026).
2. **Critère d'inactivité ≤ 25 %** : il est **déjà tenu aujourd'hui** en moyenne (24,3 % après 30 min, recalculé
   dans le journal archivé). Il ne prouvait donc rien. Remplacé par ≤ 15 % **par équipe**, plus une part de travail
   manuel ≤ 40 %.
3. **Cinq chefs à domaine fixe** (un par domaine, quel que soit l'effectif) : ils sont remplacés par **5 managers
   (fonctions)** et par des **généralistes (personnes) qui mènent un projet de bout en bout**. Leur nombre suit
   l'effectif (1 sur 6), ce qui est plus fidèle à « peu d'experts à tout faire » et à « ces 5 là ils piloteraient
   en fait différentes parties ».
4. **Expérience R1 avec `character=`** : elle est remplacée par une **interdiction**. Chaque niveau se mine en son
   propre objet, et `spill=false` ne détruit les objets que si `player` est nil (vérifié) : `character=` risquait
   un bâtiment de niveau en double. R1 devient un simple contrôle.
5. **Course +20 % au rang 5** : ramenée à **+15 %**, avec un plafond pour tout profil et toute difficulté
   (« légèrement »).
6. **Seuils d'expérience 0 / 20 / 60 / 150 / 300 « tâches »** : avec plus de 100 tâches par PNJ et par heure
   (ordre de grandeur des journaux), le rang 5 arrivait en 2 à 3 h, pour une partie de 60 h. Remplacés par des
   **minutes de travail** (0 / 30 / 120 / 360 / 900).
7. **Délai de résurrection** de 20 s + 10 s × rang (70 s au rang 5) : ramené à **10 s** (le `respawn_time` vanilla,
   vérifié) + 10 s par rang au-delà du premier (50 s au rang 5).
8. **Montée 12 / 20 / 30**, jugée trop lente par un juge : portée à **15 / 25 / 30**, avec un départ à 8 au lieu de
   6.
9. **H-E1 réduit au pétrole** : le moteur (`engine-unit`) est en `advanced-crafting` et ne se fabrique pas à la
   main (vérifié). Un module d'assembleurs est donc aussi nécessaire (§6.8).
10. **Identifiants** : les juges citaient « F66 et E35 ». F66 est pris depuis (atlas des sprites). Les prochains
    sont **F67 et E35**, ce que dit CLAUDE.md.
11. **Arithmétique** : le coût de recrue « 10 × (1 + 0,1 × effectif) », arrondi au-dessus, est faux en flottant pour
    9 effectifs sur 61 (25 au lieu de 24 à 14 PNJ, vérifié). Il s'écrit 10 + effectif.

**Greffes retenues** :
- **P1** :
  - jeu d'essai chiffré du solveur, recalculé (§6.1) ;
  - règle d'automatisation et plafonds manuels ;
  - généralistes de bout en bout et managers nommés ;
  - choix au coût par débit avec +20 % de complexité ;
  - priorités permanentes et interdits par famille ;
  - garde contre la duplication ;
  - course +15 % ;
  - revendication datée et anti-squat, gisements à égale distance ;
  - zones chiffrées (2 + ⌊époque ÷ 3⌋) ;
  - critère de stabilité (6 par heure) et orientation tirée de la doctrine, avec +20 points en cas de menace ;
  - raffinage sur place ;
  - contrat avec les lots X.
- **P2** :
  - ordres directs par les outils vanilla et outil « Ordre d'amélioration » ;
  - réserves du centre et modes Assisté / Autonome ;
  - alerte d'équilibrage (R11, Q-IA1-1) ;
  - registre des gisements à 4 états, alertes limitées et journal ;
  - arbre des manques qui demande une décision ;
  - sape ;
  - suivi des 1 000 pas du pathfinder ;
  - résurrection de base à 10 s ;
  - portage à 20 cases ;
  - critère de rythme, recalé sur le calendrier (C5-10).
- **P3** (base) : mesure réelle de l'inactivité, rues sans pathfinder, phases en unités de travail, banc des
  modules, porte à 90 %, `bp2lua.py`, règle multi-tick, gardes, gisements centraux, raids sur les modules,
  roboports à l'époque 10, interface distante.

**Greffes écartées ou adaptées** :
- « **5 généralistes offerts au départ** » (P2) : écartée. Elle contredit « peu d'experts » (5 sur 8). Le départ
  à 8 PNJ, dont 2 généralistes, donne un démarrage visible.
- « **Pétrole en 60 min** » (critère de rythme de P2) : il contredit le calendrier validé (le pétrole est
  l'époque 4, vers 3 h). Il est remplacé par « les époques à 25 % près de l'heure du joueur nominal ».

---

## 20. Fichiers, interfaces avec les autres lots, notes pour l'intégrateur

**Livré par ce lot (rédaction)** : `docs/EQUIPES_PNJ.md`, `shared/team/org.lua`, `tests/org_test.lua`. Aucun fichier
partagé n'est touché.

**Possédés par IA1 (lots suivants)** :
- `shared/team/*.lua` : les existants, plus `org` (livré), `production`, `modules`, `layout`, `territory` ;
- `script/team/*.lua` : les existants, plus `terrain`, `construct`, `zones`, `gui` ;
- `settings/team.lua` et `prototypes/team.lua` (outils de zone, d'amélioration et de zones constructibles,
  raccourci, touche) ;
- `locale/{fr,en}/ia1.cfg` ;
- `tests/ia1_*.lua` et `tests/mock_ghosts.lua` (on n'élargit pas `mock_engine.lua`, qui est partagé) ;
- `tools/team/bp2lua.py`, et les greffons `tools/autotest/fo-autotest/scenarios/ia1-*.lua` et `checks/ia1-*.lua`.

**Par l'intégrateur** : `control.lua`, `settings.lua`, `data.lua` (des `require`), `checks/index.lua`,
`script/core/storage.lua` (schéma), documents.

**Points de contact** :
- **V2c** : `Levels.upgrade_with(entité, inventaire)` instantané, sans `character`, et un centre de commandement par
  force de faction ; le sort de `L.MAX_BUILDERS` et de `L.builders`.
- **IA0b** : `shared/faction/strategy.lua` (cibles de zone, `S.contest`) et `script/faction/{sites,war,commander}.lua`.
  IA1-g passe **après** la fusion d'IA0b.
- **C** : paliers de tapis et de machines dans les gabarits (`shared/content/logistics.lua`).
- **X1 à X15** : un gabarit pour l'IA par chaîne livrée, et une méthode d'extraction par ressource.

**Écarts documentaires à corriger par l'intégrateur** :
- ARCHITECTURE §4 dit encore « Les ouvriers (10 au plus par équipe) » : à mettre à jour quand IA1-a sera intégré.
- OBJECTIFS C5 : les critères 1 à 7 à remplacer par la table du §15 si vous la validez, et l'état « conception
  livrée, modèle pur testé hors jeu (260 OK) ».
- RD_LOG :
  - noter le constat chiffré du §1 (24,3 % d'inactifs, 50 % de travail manuel) comme mesure de référence de C5-2 ;
  - noter la cause précise de H-E1 (moteur non fabricable à la main).
- CLAUDE.md : ajouter `lua5.2 tests/org_test.lua -> 260 OK` aux bancs hors jeu.
- Le texte de la commande du lot donnait encore « F65, E32 » comme prochains identifiants. CLAUDE.md (à jour)
  donne F67 et E35.

---

## 21. Ce qui n'est pas vérifié

- **Aucun comportement nouveau n'est vérifié en moteur réel.** Seule l'**existence** des appels d'API cités l'est,
  dans `runtime-api.json` et `prototype-api.json` 1.1.91.
- Le modèle `org.lua` est vérifié **hors jeu seulement** : ses durées de tâches (`O.TASK_WORK`) sont des
  estimations, et sa réaction réelle (PNJ qui marchent, tâches qui échouent) reste à voir au lot IA1-b.
- Ne sont que des estimations, à mesurer :
  - le coût du solveur et la pensée complète (environ 2 ms) ;
  - le rythme de construction (une entité par 10 ticks) ;
  - la capacité d'un porteur ;
  - les 1 500 entités par base à l'époque 6 ;
  - la consommation de charbon du jeu d'essai (45/min recalculé contre 70/min selon P1) ;
  - le temps de `O.plan` mesuré hors jeu, sur un PC non épinglé partagé avec d'autres agents.
- Le coût moteur (`entityUpdate`) des usines des IA est inconnu.
- L'effet des modificateurs `character_*` sur un personnage sans joueur, et leur addition à ceux de la force, ne
  sont pas vérifiés (R5).
- La production réelle des IA aux époques 7 à 15 dépend des gabarits des lots X ; d'ici là, le plancher d'archive
  reste une aide.
- Le multijoueur n'est pas testé à deux clients.
- Les maquettes du §8 décrivent un contenu, pas un design : rien n'est validé tant que vous n'avez pas jugé les
  captures.
- Le recalibrage du calendrier (Q-IA1-1) n'est pas chiffré : il dépend de votre réponse et du lot V2c.
