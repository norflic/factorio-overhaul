# ARCHITECTURE — Factorio Overhaul

> Document vivant. Toute décision structurante y est consignée avec sa justification.
> **Cahier des charges et état réel : OBJECTIFS.md** (référence pour comparer attentes et livraisons).
> **Mode d'emploi pour reprendre le travail (Claude Code, multi-agent) : CLAUDE.md.**
> Dernière mise à jour : 2026-10-21, session 5 (niveaux de bâtiments façon Clash of Clans : centre de
> commandement, chantiers, panneau « Évolution »). Session 4 : économie réelle et cerveau d'équipe,
> équipe du joueur, défense de tours, arsenal spécial, biomes et évolution visuelle.

## 0. Cible technique

| Élément | Valeur | Conséquence |
|---|---|---|
| Moteur | Factorio **1.1.91** (API v4, figée) | Table persistante = `global`. Doc de référence : `doc-html/runtime-api.json` et `prototype-api.json` livrés avec le jeu. |
| Mode de jeu | **Solo avec PNJ** (décision du 2026-10-20) ; le multijoueur reste possible | Le déterminisme reste exigé : il conditionne aussi sauvegarde/chargement et rejeu, et ne coûte rien. |
| Machine de référence | i5-12600KF, 64 Go | Budget **script total du mod ≤ 1,5 ms/tick en moyenne** (≈ 9 % de 16,67 ms). |
| Moteur C++ | **Non modifiable**, et inutile de le modifier | Tout le contenu passe par l'étape data (Lua ouvert dans `data/base`) et l'API runtime. La licence interdit de distribuer une version altérée du jeu. |

Portage 2.0 : `global` n'est nommé qu'à un seul endroit (`script/core/storage.lua`, marqueur `PORT-2.0`).

## 1. Arborescence

```
factorio-overhaul/
├── CLAUDE.md                       # mode d'emploi de reprise (Claude Code) : règles, commandes, bancs
├── OBJECTIFS.md                    # cahier des charges : demandes, critères d'acceptation, état réel
├── ARCHITECTURE.md, BALANCE_SHEET.md, RD_LOG.md
├── info.json, changelog.txt, settings.lua
├── data.lua / data-updates.lua / data-final-fixes.lua   # prototypes uniquement
├── control.lua                                          # câblage uniquement
├── shared/                         # PUR Lua, aucune API : partagé data / runtime / hors-jeu
│   ├── balance_model.lua           # paliers Compaction ×4 (logistique)
│   ├── content/{modules,enemies,arsenal,world}.lua      # données d'équilibrage du contenu
│   ├── faction/{config,strategy}.lua                    # paramètres + décision d'attaque des factions
│   ├── team/{config,book,planner}.lua                   # économie réelle, livre de recettes, CERVEAU D'ÉQUIPE
│   ├── td/waves.lua                                     # composition des vagues (défense de tours)
│   └── levels/config.lua                                # NIVEAUX : familles, stats, coûts, durées, plafond, design
├── prototypes/                     # générateurs de prototypes (lisent shared/)
│   ├── lib.lua                     # copie, teintes, échelle de sprites, icônes à numéro de palier
│   ├── companion/body.lua, world.lua, modules.lua, enemies.lua, arsenal.lua, faction.lua
│   ├── arsenal_special.lua         # canon, mortier, tour à arc, pulvérisateur d'acide, armes portatives
│   ├── evolution.lua               # couches lumineuses (masques, reflet, halo de nuit)
│   └── levels.lua                  # centre de commandement + niveaux 2-10 de 6 familles (70 entités)
├── script/
│   ├── core/                       # socle (événements, stockage versionné, ordonnanceur, pathfinding, FSM, traces…)
│   ├── agents/nav.lua              # navigation partagée des agents riches
│   ├── companion/                  # registre, locomotion, rendu, cerveau, banc /fo-bench
│   ├── team/                       # équipe : tableau des tâches, ouvriers, cerveau runtime, équipe du joueur
│   ├── faction/                    # état, sites, avant-postes, militaire, commandant, guerre
│   ├── td/director.lua             # défense de tours : force fo-horde, vagues, panneau, commandes
│   ├── levels/                     # chantiers d'amélioration, centre de commandement, panneau « Évolution »
│   ├── world/                      # dangers des biomes, couvée des déchiqueteurs
│   └── remote.lua                  # interface "factorio-overhaul" (pilotage sans joueur)
├── tests/
│   ├── mock_engine.lua             # moteur simulé partagé (inventaires, brûleurs, fabrication, tir…)
│   ├── run.lua                     # socle + compagnons (114)
│   ├── war_test.lua                # guerre à économie réelle + monde (86)
│   ├── td_test.lua                 # défense de tours (270)
│   ├── pteam_test.lua              # équipe du joueur (15)
│   ├── migration_test.lua          # sauvegarde 0.2 -> 0.3 (12)
│   ├── levels_test.lua             # niveaux : règles + chantiers en moteur simulé (556)
│   ├── fixtures/recipes.lua        # 246 recettes vanilla réelles (livre de recettes hors-jeu)
│   └── datastage/                  # rejoue l'étape data réelle + validateur de schéma + règles moteur
└── tools/
    ├── api_lint.py                 # chaque appel d'API contre runtime-api.json
    ├── print_balance.lua, print_content.lua
    └── autotest/                   # MOTEUR RÉEL : mod fo-autotest (scénarios, banc de contenu, captures),
                                    # fo-autotest.bat, fo-autotest-watch.bat, fo-visual.bat, analyze.py
```

## 2. Règles (non négociables)

1. **Cycle de vie** : settings → data → control. `control.lua` ne fait que des `require`.
2. **Abonnements statiques** (bus `Events`), jamais conditionnels.
3. **`on_load` ne modifie jamais `global`** ; caches locaux reconstruits paresseusement.
4. **Aucune décision pilotée par un temps mesuré** (LuaProfiler illisible) : budgets en unités de travail.
5. **Pas de trigonométrie dans la simulation** ; RNG maison ; itérations triées, jamais l'ordre de `pairs`.
6. **Jamais de fonction dans `global`** : noms de handlers résolus au runtime.
7. **Données ≠ générateurs ≠ runtime** : l'équilibrage vit dans `shared/` (pur Lua, testable), les
   prototypes sont générés, la stratégie des IA est une fonction pure (`decide(view) → actions`).
8. **Assets : pièces vanilla recomposées ET, depuis la session 5, nouvelles images autorisées**
   (réponse du Directeur Créatif à Q2 d'OBJECTIFS.md : pièces 3D rendues dans le style Factorio ;
   conventions à établir par l'hypothèse H-V1 du RD_LOG avant toute production en série). Historique :
   **zéro nouvel asset par défaut** jusqu'à la session 5 : copies vanilla teintées, mises à l'échelle, superposées
   (fonctions d'animation vanilla `biterrunanimation`, `worm_*`, `spawner_*`, animations du personnage).
   **Évolution visible (session 4, Directeur Créatif : « pas seulement la couleur, le design »)** : un
   palier ou une famille se reconnaît à sa FORME et à sa LUMIÈRE, jamais à la seule teinte : pièces
   d'autres machines (socles, antennes, réservoirs, accumulateurs), couches lumineuses additives
   `draw_as_glow` dont l'intensité croît avec le palier, halos de nuit `draw_as_light`
   (`prototypes/evolution.lua` : `glow_masks`, `light_layers`, `glow_copy`), textures et décor propres à
   chaque biome, puces différentes sur les icônes de modules. Les futures machines à paliers suivront la
   même règle. **Une teinte ne fait que multiplier** : la texture de base se choisit d'après sa couleur
   MESURÉE (aperçu calculé sur le fichier du jeu avant d'écrire le prototype, F36/F38), et chaque rendu
   est vérifié en capture de jour ET de nuit.

## 3. Socle (inchangé depuis la session 1, sauf mention)

- **Ordonnanceur : roue de périodes** — période exacte P, aucun double passage, retrait O(1).
  Formule de budget : `coût/tick = Σ (n_voie / P_voie) × c_handler`.
- **PathService** — plafonne les requêtes du mod (le pathfinder est partagé avec les biters : 10 nouvelles
  requêtes/tick), relances, tickets anti-résultat-périmé, timeout.
- **FSM** — états { enter, think, exit, on = { événements } } ; `FSM.event` (session 2) pour les
  événements externes (navigation).
- **Nav** (session 2) — `script/agents/nav.lua` : pathing → moving → arrived/failed, détection de blocage ;
  émet `nav_moving` / `nav_arrived` / `nav_failed` vers la machine de l'agent. Partagé par compagnons et
  ingénieurs.

## 4. Deux classes d'agents (décision structurante, confirmée)

| | Agents riches | Agents de masse |
|---|---|---|
| Exemples | Compagnons, **ouvriers d'équipe** (factions et équipe du joueur) | **Soldats de faction**, déchiqueteurs, horde |
| Corps | `character` (inventaire, PV) | prototype `unit` (IA moteur) |
| Coût script | O(N) : décision / P ticks, pilotage / k ticks | O(nombre de **groupes**) |
| Volume visé | ≈ 40 ouvriers + compagnons du joueur | 4 × 100 soldats + vagues |

Le « 100 contre 100 contre 100 contre 100 » repose donc sur 400 soldats natifs, que le moteur gère en C++,
pilotés par groupes. Les ouvriers (10 au plus par équipe) sont les seuls agents riches des factions. Mesuré
(session 4, E17) : ~70 agents riches + 4 cerveaux d'équipe pour 0,10 ms/tick de script en moyenne.

## 5. Factions IA : économie réelle et cerveau d'équipe (pilier 2, session 4)

Une équipe = un QG (coffre de 200 cases : le **stock**), des **ouvriers** (agents riches, corps
`character`) et des **soldats** (unités moteur). Aucune monnaie abstraite : tout ce qui est construit,
fabriqué, équipé ou recherché sort du stock, et tout ce qui est produit y rentre.

```
            shared/team/planner.lua  (PUR : testé hors-jeu sur les vraies recettes)
   vue de l'équipe ──► objectif (échelle T.ladder) ──► « il manque » ──► tâches priorisées
         ▲                         │ livre de recettes (shared/team/book.lua) : comment fabriquer
         │                         ▼
   script/team/team.lua ── tableau des tâches (script/team/board.lua) ──► ouvriers (script/team/worker.lua)
   stock réel du QG,         recruter (équipement), équiper des soldats,       home → take → goto → act → home
   avant-postes, tourelles   payer une recherche en packs                       craft · mine · walk · défense
```

- **Échelle d'objectifs** (`shared/team/config.lua`) : charbon → fer → cuivre → pierre → défense du QG
  (60 chargeurs) → armée (10) → fer II → recherche 1 → fonderie → grande armée → expansion minière →
  recherche 2 → avant-postes défendus → … → pétrole (recherche 4, pack chimique : chantier suivant).
  Un objectif atteint n'est jamais réouvert ; un objectif sans progrès en 12 min est mis de côté 15 min.
- **Ce qui manque et comment** : chaque besoin est développé jusqu'aux matières premières par le livre de
  recettes (seules les recettes « crafting » sont fabricables à la main, comme pour le joueur). Une
  matière première vient d'un avant-poste (on attend sa tournée), de la fonderie (minerai d'appoint,
  acier, briques) ou du minage à la main par les ouvriers inoccupés.
- **Règles d'entretien** : brûleur sous 3 charbons → tournée urgente ; production en attente ≥ 40 ou
  3 min sans visite → tournée ; tourelle sous 8 chargeurs → ravitaillement ; marge de charbon < 40 % →
  avant-poste de charbon agrandi ; plaque manquante > 120 → avant-poste de fer ou de cuivre agrandi.
- **Avant-postes** : foreuses à combustible → four (fer, cuivre) ou coffre (charbon, pierre) ; agrandis
  sur leur gisement (20 foreuses de fer, 12 de charbon ou de cuivre, 8 de pierre) avant d'en chercher un
  autre ; point d'accès mémorisé.
- **Ouvriers** : un programme d'étapes par tâche (sérialisable) ; une case par ouvrier au QG ; tout
  échec rapporte au QG ce qui a été pris ; autodéfense au pistolet (ennemi à moins de 18 tuiles) ; au
  dépôt, l'ouvrier vide aussi ses cases arme et munitions (F29) ; une équipe privée de tous ses ouvriers
  en embauche un sans arme.
- **Soldats** : créés seulement si leur équipement est au stock (fusilier : mitraillette + 5 chargeurs ;
  mitrailleur : + chargeurs perforants + armure ; grenadier : grenades + armure).
- **Recherche** : niveaux payés en packs réels ; chaque niveau débloque des technologies vanilla pour la
  force de l'équipe (recettes fabricables).
- **Zone de départ** : un gisement de chaque ressource de base à ~46 tuiles de chaque QG (fer : rayon 11,
  jusqu'à 20 foreuses ; charbon, cuivre : rayon 8 ; pierre : rayon 6). Prospection : disque de 12,5 chunks,
  élargi à 18 chunks après un tour sans trouvaille.
- **Migration** (schéma de stockage 2) : une guerre d'une sauvegarde 0.2 (économie à MU) est arrêtée
  proprement au chargement et les joueurs sont prévenus ; les machines à états inconnues sont inertes.
- **Attaque** : décision pure `shared/faction/strategy.lua` : taille minimale envoyée = 20 / agressivité
  (conquérant 13 … bâtisseur 28), garnison gardée, force ≥ 1,3 × défense estimée (Lanchester).
- **Pathfinding des agents** : un départ qui chevauche un obstacle avec la boîte élargie de la requête est
  poussé hors de l'obstacle avant la demande (`script/core/path_service.lua`).

### Équipe du joueur
Le joueur pose un **coffre d'équipe** : ses compagnons deviennent des ouvriers du même cerveau (échelle
`T.player_ladder`, sans armée ni recherche : le joueur recherche lui-même), qui n'utilisent que le contenu
du coffre. `/fo-team status | dismiss`.

### Guerre (sessions 2-3, inchangé)
- **Prospection de fond** : voie "fo-prospect", 4 chunks / 30 ticks, seulement pour les ressources que
  le cerveau d'équipe demande ; sites proches d'ennemis ou inaccessibles mis de côté 30 min.
- **Itinéraires d'attaque** : une requête de chemin par attaque (grille grossière) ; le groupe suit des
  points de passage puis attaque la zone ; cible sans itinéraire écartée 10 min.
- **QG validés** : emplacement choisi parmi 17 candidats (eau, falaises), accès à pied au centre vérifié ;
  sinon la faction déménage (4 fois au plus).
- **Cible** : coalition contre le leader (nettement plus de territoire), sinon le rival voisin ; l'avant-poste
  le plus proche d'abord, le QG en dernier.
- **Diplomatie** : factions hostiles entre elles et aux déchiqueteurs ; cessez-le-feu avec le joueur
  (paramètre) rompu dès que le joueur tue une de leurs entités.
- **Élimination** : QG détruit → faction anéantie ; dernière faction en vie → victoire annoncée.
- **Commandes** : `/fo-war start|status|stop|fund` ; interface distante `factorio-overhaul`.

## 6. Mode défense de tours (session 4)

`shared/td/waves.lua` (pur) : budget de vague 24 × 1,3^(n-1), dépensé en déchiqueteurs selon leur palier
(coût 1, 3, 10, 30, 90, 260, 700, 2 000), palier maximal 1 + vague/4, familles introduites aux vagues 4
(blindés), 7 (ignés), 9 (couvées), 12 (foudroyants), boss toutes les 5 vagues (palier 2 + vague/5),
récompenses croissantes.
`script/td/director.lua` : force dédiée `fo-horde` (en paix avec les déchiqueteurs naturels), points
d'apparition annoncés sur la carte, apparition étalée (12 unités/s), assaut en groupes moteur vers le
barycentre des tourelles du joueur, panneau à l'écran (compte à rebours, vivants, record), bouton,
`/fo-waves on|off|next|status`, interface distante. Activable et désactivable à tout moment, en plus de
la guerre des factions. Toutes les 10 s, un groupe inactif est relancé, un groupe qui ne se rapproche
plus de la base repart d'un autre point d'apparition, les unités sans groupe sont regroupées ; si les
assaillants atteignent la base et qu'aucune tourelle ne tient, la base est tombée : le mode s'arrête,
record conservé.


## 7. Contenu en paliers et nouvelles familles d'armes (pilier 3)

| Domaine | Ce qui est généré | Source des données |
|---|---|---|
| Modules | vitesse, productivité, efficacité : paliers 4 → 10 | `shared/content/modules.lua` |
| Déchiqueteurs | paliers 5-8, 4 familles × 8 paliers × 2 types, 4 nids de famille, vers 5-8 | `shared/content/enemies.lua` |
| Arsenal | 4 munitions, mitrailleuse lourde, 2 tourelles lourdes, 2 murs | `shared/content/arsenal.lua` |
| **Arsenal spécial** (session 4) | tourelle-canon, mortier, tour à arc, pulvérisateur d'acide ; obus de mortier, obus en tungstène, grenade de lanceur, balle de rail, cellule d'arc ; lance-grenades, fusil à rail, arc portatif ; 3 technologies | `shared/content/arsenal.lua` (A.special_*) |
| Monde | 3 biomes, 3 ressources à effets | `shared/content/world.lua` |
| Factions | QG (stock), 12 soldats, coffre d'équipe du joueur | `shared/faction/config.lua`, `shared/team/config.lua` |

Total : **347 prototypes** ajoutés ou modifiés, validés hors-jeu contre le schéma 1.1.91 et en moteur réel.

**Évolution visuelle (session 4)** : déchiqueteurs des familles et des paliers 5-8, nids de famille et
vers 5-8 portent une couche lumineuse (copie additive de leurs masques) : braise (ignés), arcs (foudroyants),
violet (couvées), acier froid (blindés), intensité croissante avec le palier. Biomes : sol calciné des
cratères gris charbon + roches en fusion, aiguilles de basalte, arbres calcinés, braises qui rougeoient la
nuit (cendres) ; surface vitrifiée miroitante, terrain ferme + amas de cristal violets et éclats cyan
lumineux, minables (plaine de cristal) ; eau croupie olive constructible + forêt de troncs morts,
roseaux, écume toxique lumineuse (marais). Minerais : tungstène en blocs de métal sombre à reflets acier,
cristal violet vif à éclats pulsés (éclats = texture du gisement en additif). Tourelles lourdes : socle
d'artillerie (mitrailleuse lourde) ou de balise (laser lourd), tête éclairée de nuit.

**Silhouettes composées** (règle 8 élargie) : une nouvelle arme assemble des pièces graphiques vanilla :
socle de mitrailleuse agrandi + tourelle de char (canon), socle et fût d'artillerie réduits (mortier),
pile d'accumulateurs + antenne de balise + arcs de charge lumineux et halo de nuit (tour à arc), lance-flammes adossé à un
petit réacteur chimique (acide) ; icônes composées (icône de base teintée + pastille de la munition).


## 7 bis. Niveaux de bâtiments « façon Clash of Clans » (session 5)

**Décision du Directeur Créatif** : une progression par niveaux, avec de vrais échelons, presque un jeu
« idle ». Règles et chiffres : BALANCE_SHEET §12.

- **Un prototype par niveau.** Le niveau 1 est le bâtiment vanilla ; les niveaux 2 à 10 s'appellent
  `fo-lvl-<famille>-<n>`, et le centre de commandement de base `fo-command-center`. Chaque niveau a son
  objet, pour qu'un bâtiment démonté garde son niveau. Pas de `next_upgrade`, pour que le planificateur
  d'amélioration ne contourne ni le coût ni le plafond. `L.parse(nom)` donne famille et niveau
  (table de correspondance, coût constant).
- **Remplacement moteur.** Au terme d'un chantier, `create_entity{fast_replace = true, spill = false,
  raise_built = true}` remplace le bâtiment comme un remplacement rapide fait à la main : contenu,
  recette, modules et fils de circuit sont conservés, et l'objet de l'ancien niveau est détruit. Il faut
  pour cela un groupe de remplacement commun : les tourelles vanilla n'en ont pas, le mod leur en donne un
  (`fo-lvl-gun`, `fo-lvl-laser`). Un remplacement manuel de secours existe ; il est compté (`fallback`),
  et le banc exige 0.
- **Paiement.** Le stock du centre de commandement d'abord, puis l'inventaire du joueur. Le centre est un
  coffre : l'usine l'alimente, et la production nourrit la progression.
- **État** (`global.fo.levels`) : centre par force, chantiers indexés par `unit_number`, ouvriers occupés
  par force, statistiques. Les chantiers sont parcourus triés toutes les 30 ticks : coût nul hors chantier.
- **Interface.** Panneau « Évolution » au survol (`on_selected_entity_changed`), touche U (entrée
  personnalisée `fo-level-up`), bouton « Toute la rangée » pour les murs. Les tourelles laser et les murs
  n'ont pas d'interface moteur, d'où un panneau propre plutôt qu'une interface relative. Le panneau suit
  le bâtiment remplacé grâce au crochet `Levels.on_replaced`, enregistré au chargement.
- **Design (REJETÉ par le Directeur Créatif le 21/10 à 17 h 26 : « je ne vois QUE un changement de
  couleur/teinte » ; E25).** Cible : OBJECTIFS.md D1/E2/F1 : une pièce visible de plus à chaque
  niveau et une nouvelle silhouette à chaque époque (15 époques). Ce qui existe aujourd'hui : des couches s'ajoutent au prototype copié : matériau (teinte), socle (texture de sol
  découpée à l'emprise, en première couche), reflet `draw_as_glow`, halo `draw_as_light`, et une échelle de
  sprite qui croît. Ces opérations sont dans `prototypes/levels.lua` et `prototypes/evolution.lua`, et
  appliquées aux seuls champs graphiques principaux de chaque type.
- **Pilotage sans joueur** : `levels_upgrade`, `levels_row`, `levels_time_factor`, `levels_status`
  (interface distante, pour le banc de contenu).

## 8. Chaîne de vérification

| Banc | Ce qu'il prouve | Ce qu'il ne prouve pas |
|---|---|---|
| `tests/datastage/harness.lua` | L'étape data s'exécute (core + base + mod, dans l'ordre moteur) ; schéma, références, localisation FR/EN ; règles moteur connues (ex. `slice` des animations tournantes, F23) | Rendu, génération de carte réelle |
| `tools/api_lint.py` | Chaque appel runtime existe en 1.1.91, avec la bonne forme d'appel | Comportement à l'exécution |
| `tests/*.lua` (moteur simulé) | Logique runtime, cerveau d'équipe sur les vraies recettes, sérialisabilité, déterminisme, rechargement, migration | Fidélité du moteur |
| `fo-autotest.bat` scénario `content` | **Le vrai jeu** : chaque recette dans sa machine, chaque module, chaque munition, tourelle et arme portative en duel, les contres voulus, ennemis, nids, biomes, niveaux (180 contrôles, dont 35 de niveaux) | Rendu |
| `fo-autotest.bat` scénarios `default`, `waves`, `pteam`… | **Le vrai jeu** sans affichage, dossiers isolés : guerre à économie réelle, défense de tours, équipe du joueur ; temps par tick et par poste ; étalon machine | Rendu |
| `fo-visual.bat` + `shots.lua` | **Le vrai jeu avec images** sur la dernière carte de test, captures automatiques | — |

### Outillage du moteur réel

- `fo-autotest.bat` : benchmark épinglé sur les cœurs P (processeur hybride : F30) et priorité au-dessus
  de la normale ; étalon machine `[FO-CALIB]` (charge Lua fixe chronométrée toutes les 10 s) lu par
  `analyze.py`, qui signale les fenêtres où la machine ralentit.
- `analyze.py <dossier> --spikes` : pics de script attribués aux traces `[FO-TRACE]` du même tick.
- Scénarios : `default`, `content` (banc de contenu, 180 contrôles depuis la session 5), `waves` (défense de tours + guerre),
  `pteam` (équipe du joueur + guerre), `baseline`, `stress`, `noexp`, `peace`, `parked`, `worker`.
- `shots.lua` : en session graphique (`fo-visual.bat`), captures automatiques des points d'intérêt dans
  `fo-visual\write\script-output\fo-shots\`, de jour et de nuit. Le mod de test coupe l'introduction
  du scénario « freeplay » (son message met le jeu en pause : F34). `global` étant propre à chaque mod, QG
  et avant-postes viennent de l'interface `points_of_interest` ; un point de biome n'est retenu que dans
  un chunk entièrement généré (F35), noté par la quantité de décor visible.
- Étape data : `harness.lua --dump-proto type/nom` (prototype vanilla) et `--dump-final type/nom`
  (prototype tel que le mod le livre : vérifier une couche ajoutée sans lancer le jeu).
- Hors-jeu : `tests/run.lua`, `tests/war_test.lua`, `tests/td_test.lua`, `tests/pteam_test.lua`,
  `tests/migration_test.lua` (moteur simulé) ; `tests/datastage/harness.lua` (étape data + règles moteur) ;
  `tools/api_lint.py` (appels d'API contre la doc 1.1.91).

## 9. Budget UPS

| Sous-système | Budget moyen | Levier |
|---|---|---|
| Compagnons + ouvriers (agents riches) | 0,30 ms | N, P, k |
| Cerveaux d'équipe + commandants | 0,10 ms | 1 pensée / équipe / 5 s |
| Armées (niveau groupe) | 0,10 ms | nombre de groupes |
| Monde (biomes, couvée) | 0,05 ms | événements, voies étalées |
| Rendu debug | 0,10 ms | désactivable |
| Réserve | 0,85 ms | — |
| **Total script** | **≤ 1,5 ms** | |

Le coût C++ (pathfinder, unités, combats) se lit dans le benchmark de l'autotest, pas dans le temps script.

**Mesuré en moteur réel (session 4, E17 : 30 min, 4 équipes à économie réelle, ~70 agents riches, 50
compagnons, benchmark épinglé sur les cœurs P)** : script **0,10 ms/tick** en moyenne (p99 0,58 ms) ;
tick complet 0,39 ms (p99 1,58 ms) ; 2 ticks sur 108 000 au-delà de 16,7 ms. Sur 60 min de guerre (E21) :
script 0,14 ms/tick (p99 0,86 ms), tick complet 0,58 ms (p99 2,2 ms), 8 ticks sur 216 000 au-delà de 16,7 ms. Attention (F30) : sur un
processeur hybride, un benchmark laissé en arrière-plan passe sur les cœurs E et toutes les mesures sont
faussées (×3, pauses de 170 ms) ; l'étalon `[FO-CALIB]` le détecte.
