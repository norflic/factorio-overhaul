# ARCHITECTURE — Factorio Overhaul

> Document vivant. Toute décision structurante y est consignée avec sa justification.
> **Cahier des charges et état réel : OBJECTIFS.md** (référence pour comparer attentes et livraisons).
> **Mode d'emploi pour reprendre le travail (Claude Code, multi-agent) : CLAUDE.md.**
> Dernière mise à jour : 2026-10-23, vers 18 h 30 (lot M0 : garantie des monnaies des âges 5, 7 et 8, §7.1 ; lot K0 :
> kit de rendu commun des familles, en cours d'intégration, §7 ter ; lot A1 : directions de la tête et scénario
> `a1-tourelle`, §7 ter et §8 ; bancs `monde`, `m0-reprise`, `m0-migration`, §8). Avant : 2026-10-22, 19 h 20, session 6 (lot V3-T2 : emprise croissante de toutes les familles,
> points servis, progression notée, bâtiment hors grille, §7 bis ; bancs, §8). Avant : 2026-10-21, session 5 (niveaux de bâtiments façon Clash of Clans : centre de
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
├── docs/DESIGN_EPOQUES.md          # bible des 15 époques × 7 familles (lot V1) ; docs/epoques/mesures/ : mesures vanilla
├── docs/SCENARIO_EPOQUES.md        # scénario « La Caustique d'Érèbe », 15 époques, 4 branches, arbres de fabrication (lot X0)
├── docs/EQUIPES_PNJ.md             # conception des équipes de PNJ organisées (C5, lot IA1) : pôles, généralistes, production adaptative, interface, plan de lots
├── settings/faction.lua            # réglages par lot, requis par settings.lua (lot IA0)
├── graphics/vitrine/               # sprites rendus par le pipeline 3D (lot V0) ; prototypes/vitrine.lua les déclare
├── graphics/levels/gun/            # feuilles de la mitrailleuse en jeu (lot A2, D-6) : 318 PNG générés HORS de git ; sprites.lua, sprites.json, MANIFEST.json commités (§7 ter)
├── sound/levels/gun/               # sons de la mitrailleuse (lot S0) : 20 OGG COMMITÉS (tir par ère), sons.lua généré, MANIFEST.json ; outil : tools/sound/
├── tools/render/                   # pipeline de rendu 3D (Blender) étalonné sur le vanilla : README, CALIBRATION
│   └── pieces/levels/              # kits de rendu des familles à niveaux (§7 ter) : gun_e/ (mitrailleuse validée ; directions dKK, rose.py, e66*.py, identite.py : lot A1) ; commun/ (kit commun, registre des âges, profils de famille : lot K0)
├── docs/DA_FACTORIO.md             # charte de direction artistique mesurable (lot V3-S, E43) ; docs/da/ : mesures vanilla et V3 phase 1, planches
├── tools/da/                       # mesure de la charte sur des sprites (py -3.9 : numpy, Pillow) : da_lib, seuils (23 planchers), progression (dominance entre époques)
├── info.json, changelog.txt, settings.lua
├── data.lua / data-updates.lua / data-final-fixes.lua   # prototypes uniquement
├── control.lua                                          # câblage uniquement
├── shared/                         # PUR Lua, aucune API : partagé data / runtime / hors-jeu
│   ├── balance_model.lua           # paliers Compaction ×4 (logistique)
│   ├── content/{modules,enemies,arsenal,world}.lua      # données d'équilibrage du contenu
│   ├── content/epochs.lua          # contenu des 15 époques et des branches (lot X0) : ressources, objets, recettes, bâtiments, technologies (données pures, pas encore en jeu)
│   ├── content/guarantee.lua       # garantie des monnaies des âges 5, 7 et 8 (lot M0, §7.1) : spécifications, candidats (Park-Miller), paliers de reprise, verdict du sol, disposition du site (pur)
│   ├── faction/{config,strategy}.lua                    # paramètres + décision d'attaque des factions
│   ├── team/{config,book,planner}.lua                   # économie réelle, livre de recettes, CERVEAU D'ÉQUIPE
│   ├── team/org.lua                # modèle pur des rôles (C5, lot IA1) : pôles, affectation différée, jetons de travail, résurrection, rangs
│   ├── td/waves.lua                                     # composition des vagues (défense de tours)
│   ├── levels/config.lua                                # NIVEAUX : familles, stats, coûts, plafond, design ; emprises (L.footprints, lot V3-T)
│   ├── levels/footprint.lua        # emprise croissante (lot V3-T) : géométrie des carrés, RÈGLE DE POSITION, place, contour, migration (pur)
│   ├── levels/points.lua           # points de jeu (lot V3-T2) : déplacement des points d'un prototype (move_point), inverse, rotation, RÈGLE DES POINTS SERVIS (pur)
│   └── levels/clear.lua            # « libérer la place » (lot V3-T3) : RÈGLE DE DÉCALAGE (texte de référence en tête), C.plan (quoi marquer, où reposer chaque gêneur, quoi signaler), C.choose (candidate au plan complet), C.supply_kept (pur)
├── prototypes/                     # générateurs de prototypes (lisent shared/)
│   ├── lib.lua                     # copie, teintes, échelle de sprites, icônes à numéro de palier
│   ├── companion/body.lua, world.lua, modules.lua, enemies.lua, arsenal.lua, faction.lua
│   ├── arsenal_special.lua         # canon, mortier, tour à arc, pulvérisateur d'acide, armes portatives
│   ├── evolution.lua               # couches lumineuses (masques, reflet, halo de nuit)
│   ├── levels.lua                  # point d'entrée des niveaux (lot V2)
│   └── levels/                     # common.lua (non visuel, garde de dress), style.lua (style commun Q10), un fichier par famille : centre 15 niveaux, 6 familles × 30
├── script/
│   ├── core/                       # socle (événements, stockage versionné, ordonnanceur, pathfinding, FSM, traces…)
│   ├── agents/nav.lua              # navigation partagée des agents riches
│   ├── companion/                  # registre, locomotion, rendu, cerveau, banc /fo-bench
│   ├── team/                       # équipe : tableau des tâches, ouvriers, cerveau runtime, équipe du joueur
│   ├── faction/                    # état, sites, avant-postes, militaire, commandant, guerre
│   ├── td/director.lua             # défense de tours : force fo-horde, vagues, panneau, commandes
│   ├── levels/                     # chantiers d'amélioration, centre de commandement, panneau « Évolution » ; free.lua (lot V3-T3) : bouton « Libérer la place », marques, fantômes, demandes en attente, Annuler (chargé par panel.lua et remote.lua, pas par control.lua)
│   ├── world/                      # dangers des biomes, couvée des déchiqueteurs ; guarantee.lua (lot M0, §7.1) : pose des sites garantis, interface « fo-monde »
│   └── remote.lua                  # interface "factorio-overhaul" (pilotage sans joueur)
├── tests/
│   ├── mock_engine.lua             # moteur simulé partagé (inventaires, brûleurs, fabrication, tir…) ; boîtes vanilla, recherche par boîte (suite V3-T) en intervalles fermés, contact bord à bord compris (lot R1, E53) ; marques de démontage, fantômes (création, revive), mine, points d'un bras, fils d'un poteau (lot V3-T3)
│   ├── run.lua                     # socle + compagnons (114)
│   ├── war_test.lua                # guerre à économie réelle + monde (92)
│   ├── td_test.lua                 # défense de tours (270)
│   ├── pteam_test.lua              # équipe du joueur (15)
│   ├── monde_test.lua              # garantie des monnaies (lot M0) : candidats, décision, sites, échec et reprise par paliers, en moteur simulé (157)
│   ├── migration_test.lua          # sauvegardes 0.2 → 0.4.4 (et sans changement de version) : chantiers, PV, emprises V3-T et V3-T2, reprise de progression, hors grille, doublons, message, filet, contact bord à bord, namespace levels_free créé vide (82)
│   ├── levels_test.lua             # niveaux : règles, amélioration, emprise croissante, points servis, objet au sol bord à bord, « libérer la place » en moteur simulé (1 642 + 11 écarts connus) ; attentes tirées de L.footprints
│   ├── levels_clear_cases.lua      # cas purs de la règle de décalage (lot V3-T3, shared/levels/clear.lua), joués par levels_test (détail : FO_VERBOSE_CLEAR=1)
│   ├── fixtures/recipes.lua        # 246 recettes vanilla réelles (livre de recettes hors-jeu)
│   └── datastage/                  # rejoue l'étape data réelle + validateur de schéma + règles moteur
│       └── engine_rules.lua        # règle des points de jeu : pipe-inside, pipe-off-center, drop-inside, drop-on-footprint (suite V3-T, E47)
└── tools/
    ├── api_lint.py                 # chaque appel d'API contre runtime-api.json
    ├── print_balance.lua, print_content.lua
    └── autotest/                   # MOTEUR RÉEL : mod fo-autotest (scénarios, banc de contenu, captures),
                                    # fo-autotest.bat, fo-autotest-watch.bat, fo-visual.bat, analyze.py ;
                                    # fo-autotest/checks/levels_taille.lua : greffon du banc content, emprise croissante (lot V3-T, 26 contrôles)
                                    # fo-autotest/checks/levels_machines.lua : greffon, emprise croissante des machines, du laser et du centre (lot V3-T2, 54 contrôles, E49)
                                    # fo-autotest/checks/levels_points.lua : greffon, points de jeu servis dans les 4 orientations, fabrications en cours (lot V3-T2, 25 contrôles, E51, E52)
                                    # fo-autotest/scenarios/ht3-migration.lua : scénario greffé, migration d'une sauvegarde 0.4.1 (double source, E46)
                                    # fo-autotest/scenarios/t2-machines.lua : scénario greffé, les deux greffons V3-T2 joués au tick 60, pour les captures (80 contrôles)
                                    # fo-autotest/scenarios/t2-migration.lua : scénario greffé, migration d'une sauvegarde 0.4.2 vers 0.4.3, usine dense (double source, E50 ; 64 contrôles)
                                    # fo-autotest/scenarios/t2-defense.lua : scénario greffé, migration d'une défense dense de 21 tourelles, création 0.4.1 ou 0.4.2 (double source seulement, lot R1, E54 ; 36 contrôles)
                                    # fo-autotest/scenarios/bord-a-bord.lua : scénario greffé, contact exact zone/boîte de find_entities_filtered et count_entities_filtered (lot R1, E53 ; 45 cas, 12 contrôles)
                                    # fo-autotest/scenarios/t3-libere.lua : scénario greffé, bouton « libérer la place » en moteur réel, zones A à V et L, vrais robots en R (lot V3-T3, E59 ; 1 900 ticks, 41 contrôles)
                                    # fo-autotest/scenarios/t3-migration.lua : scénario greffé, « libérer la place » pour un bâtiment laissé hors grille par une vraie migration (double source src-0.4.2 seulement, lot V3-T3, E59 ; 1 000 ticks, 7 contrôles)
                                    # fo-autotest/scenarios/monde.lua : scénario greffé, garantie des monnaies sur nauvis et 5 graines (surfaces créées), cas A à F (lot M0, E73, E74 ; 700 ticks, 89 contrôles)
                                    # fo-autotest/scenarios/m0-reprise.lua : scénario greffé, échec puis reprise de la garantie (lot M0, E74 ; 2 600 ticks, 15 contrôles)
                                    # fo-autotest/scenarios/m0-migration.lua : scénario greffé, migration d'une sauvegarde 0.4.4 (double source src-0.4.4 seulement, lot M0, E76 ; 700 ticks, 9 contrôles)
                                    # fo-autotest/scenarios/a1-tourelle.lua + a1/jetable.py, a1/a1_jetable_data.lua : levée et directions d'une tourelle (lot A1, E67, E70 ; sur une COPIE JETABLE du mod seulement, 1 000 ticks, 5 contrôles ; sur le mod livré, refus propre à l'init)
                                    # ht3_journal.py : contrôle du journal d'un passage ht3-migration (7 contrôles) ; --tag FO-T2-MIGRATION : passage t2-migration (26) ; --tag FO-T2-DEFENSE : passage t2-defense (19 ou 11)
                                    # vram.py : atlas relevés dans visual.log ; atlas virtuel du plancher COMPTÉ dans l'estimation depuis le lot R1 (E55)
                                    # tests/ : run_d4m.py (banc D4m, 5 étapes), unit_vram.py (99), mut_atlas.py (40 cas),
                                    #   mut_vram.py (témoin nul et 18 mutants de vram.py, lot R1, E55),
                                    #   test_ht3_journal.py (15), bat_double_source/ (faux factorio.exe et robocopy.exe, 4 cas)
```
Traductions : `locale/fr/` et `locale/en/`, un fichier par lot (par exemple `levels-taille.cfg`, lot V3-T : taille,
place libre ou prise, directions, motif « no-room » ; lot V3-T2 : `regrid-line`, `points-moved`, `migration-kept`,
`migration-stacked` ; lot V3-T3 : 25 clés `free-*` dans chaque langue, comptées sur `main` le 22/10 ; les notes du
correcteur disent 27).

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
- **PvP et difficulté** (lot IA0, `script/faction/pvp.lua`, réglages dans `settings/faction.lua`) :
  - Le réglage de partie `fo-pvp-difficulty` offre 5 niveaux. « Paisible » est l'ancien cessez-le-feu.
  - Hors Paisible, une faction déclare la guerre au joueur à la fin de sa grâce. Un préavis de 2 min
    est garanti, et `grace_floor` le maintient quand le niveau change en cours de partie.
  - Le joueur est alors une cible comme une rivale, dans la stratégie pure (`S.decide`) : même règle
    de coalition contre le leader, territoire compté en unité commune.
  - Repérage des installations du joueur : un `count_entities_filtered` toutes les 8 ticks, sur un
    disque de 24 secteurs.
  - Abattre un attaquant en guerre ouverte n'est pas une provocation.
  - Une sauvegarde déjà en guerre garde ses hostilités (hostilité héritée).
  - Limites : seule la force `player` est visée, et seulement dans un rayon de 1 536 tuiles.
  - Chiffres : BALANCE_SHEET §10 bis.
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
| Monde | 3 biomes, 3 ressources à effets (générées depuis `W.resource_order` depuis le lot M0) ; sites garantis des 3 monnaies, posés par script (§7.1) | `shared/content/world.lua`, `shared/content/guarantee.lua` |
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

### 7.1 Garantie des monnaies des âges 5, 7 et 8 (lot M0, 23/10, version 0.4.5)

**Problème** : le tungstène (âge 5), le cristal de résonance (âge 7) et le méthane (âge 8) ne viennent que des biomes
du mod, placés par bruit. Sur une graine sans cendres proches, le centre ne passe pas l'âge 5 (3 graines sur 5
essayées : RD_LOG E73) ; et dans une sauvegarde existante, l'autoplacement ne touche que les chunks neufs.

**Découpage** (règle 7 du §2) :
- `shared/content/guarantee.lua` (PUR, testé hors jeu par `tests/monde_test.lua`) : `G.specs()` lit le nombre et
  les distances dans `X.base_resources` (`shared/content/epochs.lua`, `placement.guaranteed`) et la forme du site dans
  le champ `guarantee` de `W.resources` (`shared/content/world.lua`) ; candidats `G.candidates(graine, spec, n, essai)`
  par un Park-Miller à état local (graine de la carte mêlée au `seed1` de la ressource ; essai k = graine décalée de
  1 000 k ; direction par rejet dans le disque unité, AUCUNE trigonométrie ; rayon uniforme en aire dans l'anneau
  [dmin + cœur + 1, dmax − cœur − 1]) ; 24 candidats au plus par essai (`G.MAX_TRIES`) ; refus « voisin » (autre site
  garanti), « batiment » (entité d'une force autre qu'`enemy` ou `neutral` dans le disque + 2), « gisement »
  (ressource sous le cœur + 3), « sol » (tuile non naturelle ou eau sous le cœur + 1) ; paliers de reprise
  `G.rules(essai)` : niveau 1, autres candidats ; niveau 2, eau naturelle tolérée sous le cœur jusqu'à 50 %
  (`G.WATER_SHARE`) et comblée par le sol du biome ; niveau 3 et suivants, distance maximale × 1,5
  (`G.RING_STRETCH`) ; jamais tolérés : un bâtiment d'une force joueur ou IA, un gisement existant sous le cœur, une
  dalle posée par un joueur ; délais `G.retry_delay(échecs)` : 600, 1 200, 2 400… ticks, au plus 36 000.
- `script/world/guarantee.lua` (exécution) : état `global.fo.world` déclaré par `Storage.declare("world")`
  (`done`, `fails`, `sites`, `tags`, `runs` ; nombres, chaînes de clés et positions seulement) ; abonnements
  statiques par le bus `Events` ; chargé par `control.lua` (une ligne `require`).
- `prototypes/world.lua` : les ressources du monde sont générées depuis les données (boucle sur `W.resource_order`,
  `ore_prototypes` ou `fluid_prototypes` selon `kind` ; sortie identique à 0.4.4 : E75). Le générateur depuis
  `X.resources` et `X.tiles` est REPORTÉ aux lots X (34 prototypes sur 35 n'existent pas encore ; RD_LOG, décisions du
  23/10).

**Trois moments** :
1. `on_init` : partie neuve (tick 0) : le site est TOUJOURS posé (savoir si la graine a déjà un gisement à 200-700
   tuiles coûterait environ 2 s de génération : F133 ; Q-M0-1) ; mod ajouté à une partie en cours (tick > 0) : comme
   une sauvegarde.
2. `on_configuration_changed` : sauvegarde existante : posé seulement s'il manque des unités dans les chunks DÉJÀ
   générés à moins de dmax (minerai : quantité / `min_total` ; fluide : nombre de puits) ; reprend aussi tout échec
   sans attendre le délai.
3. Filet `on_nth_tick(600)` : rejoue ce qui n'a pas été traité (mod mis à jour sans que la configuration soit
   rejouée : F130 montre que l'appel n'est pas garanti par la version) et reprend un échec quand
   `game.tick >= next_tick`. Coût hors travail : une boucle sur 3 clés.

**Réussite et échec** : une ressource n'est marquée traitée (`done[clé]`) que RÉUSSIE ; un échec écrit
`fails[clé] = { count, next_tick, history }`, est annoncé aux joueurs (`game.print`, clé `fo-monde.site-echec`, FR et
EN) et repris au palier suivant (correction M-1 de la vérification). **Le site** : disque de tuiles du biome (cendres
r 13, plaine de cristal r 15, marais r 7 ; bord irrégulier haché), posé seulement sur un sol naturel de terre ferme ;
gisement (tungstène 197 tuiles, environ 198 000 ; cristal 149 tuiles, environ 120 000) ou puits (2 puits de méthane à
450 000) ; falaises du cœur retirées ; décor vanilla du disque retiré, décoratifs du biome régénérés ; zone
cartographiée pour « player » et étiquette de carte posée à `on_chunk_charted` (F131 : `add_chart_tag` juste après
`chart` échoue) ; message aux joueurs (`locale/*/m0.cfg`, lien `[gps]`).

**Interface distante `fo-monde`** (bancs en moteur réel ; données simples) : `status()` (runs, done, fails, étiquettes
en attente), `specs()`, `candidates(surface, clé, n, essai)`, `apply(surface, opts)` (surface de banc : rien n'est
gardé ni cartographié), `forget(clé)` (banc seulement : la ressource redevient « à traiter »).

**Coût mesuré** (moteur réel, LuaProfiler ; E74) : une fois par ressource et par partie, 105 à 196 ms quand des chunks
doivent être générés, 11 à 21 ms sinon, 1,4 ms pour un filet sans travail ; jusqu'à 767 ms sur une carte à eau
maximale (vérification, pire cas non borné). Non prouvé : l'accès à pied du site depuis le départ (île possible).

## 7 bis. Niveaux de bâtiments « façon Clash of Clans » (session 5)

**Décision du Directeur Créatif** : une progression par niveaux, avec de vrais échelons, presque un jeu
« idle ». Règles et chiffres : BALANCE_SHEET §12.

- **Structure (lot V2).** `shared/levels/config.lua` porte les règles pures :
  - 15 époques ; centre de 1 à 15 ; familles de 1 à 30 ; plafond = min(30, 2 × centre) ;
  - lot V2c : amélioration INSTANTANÉE (Q19 ; plus d'ouvriers ni de durées) ; condition du centre (Q16 :
    `L.cc_condition_level`, `L.cc_blockers`) ;
  - courbe de coûts par époque (`value_mult` des familles, `cc_value` du centre, × `L.TEAM_FACTOR`), avec ses
    monnaies et une table d'indirection pour les matériaux encore provisoires ; calendrier RECOPIÉ au
    chargement depuis le scénario X0 (`shared/content/epochs.lua`, dans `L.target` : une seule source ; la
    config ne lit plus X ensuite, et la garde de dress compare X à la fermeture de chaque famille) ;
  - règle de place (`L.stack_size`, `L.cost_slots`, `L.chest_slots`) : un coût tient dans la
    moitié du coffre du centre qui le paie ;
  - recherche vanilla allégée (QX9 : `L.vanilla_tech_epoch`, `L.vanilla_unit_count`, appliqués par
    `data-final-fixes.lua`).

  `prototypes/levels/common.lua` génère tout ce qui n'est pas visuel. Chaque `prototypes/levels/<famille>.lua`
  fournit son visuel par `dress`/`icons`, sous une **garde inversée**, qui fonctionne ainsi :
  - tout le prototype est capturé, sauf une liste blanche graphique ;
  - toute modification de jeu, de la config, du style commun ou des prototypes sources est refusée,
    avec un message qui nomme la clé ;
  - `ctx` est en lecture seule.

  Les 7 agents V3 travaillent donc chacun dans un seul fichier.
- **Un prototype par niveau.** Le niveau 1 est le bâtiment vanilla ; les niveaux 2 à 30 (centre : 2 à 15) s'appellent
  `fo-lvl-<famille>-<n>`, et le centre de commandement de base `fo-command-center`. Chaque niveau a son
  objet, pour qu'un bâtiment démonté garde son niveau. Pas de `next_upgrade`, pour que le planificateur
  d'amélioration ne contourne ni le coût ni le plafond. `L.parse(nom)` donne famille et niveau
  (table de correspondance, coût constant).
- **Remplacement moteur.** Aussitôt le coût payé (lot V2c), `create_entity{fast_replace = true, spill = false,
  raise_built = true}` remplace le bâtiment comme un remplacement rapide fait à la main : contenu,
  recette, modules et fils de circuit sont conservés, et l'objet de l'ancien niveau est détruit. Il faut
  pour cela un groupe de remplacement commun : les tourelles vanilla n'en ont pas, le mod leur en donne un
  (`fo-lvl-gun`, `fo-lvl-laser`). Un remplacement manuel de secours existe ; il est compté (`fallback`),
  et le banc exige 0.
- **Paiement.** Le stock du centre de commandement d'abord, puis l'inventaire du joueur. Le centre est un
  coffre : l'usine l'alimente, et la production nourrit la progression.
- **État** (`global.fo.levels`) : centre par force, statistiques. Depuis V2c, `jobs` et `busy` restent vides :
  les chantiers d'une sauvegarde 0.3.0 ou 0.4.0 sont ACHEVÉS au chargement (`Levels.finish_legacy_jobs`,
  dans `on_configuration_changed`, et un filet toutes les 30 ticks sans changement de version).
- **Condition du centre (Q16, V2c).** `Levels.census(force, niveau)` recense, par famille, « en possède au
  moins un » et « en a un au niveau visé ou plus » (`count_entities_filtered{ force, name, limit = 1 }` sans
  zone, surfaces triées par index) ; calculé pour le centre seulement. `Levels.census_cached` le garde en
  cache par force dans `global.fo.levels.census` (construction : mise à jour exacte ; retrait : invalidation ;
  expiration après `Levels.CENSUS_TTL` = 600 ticks) : le panneau lit le cache, chaque décision
  (`Levels.start`) recense en entier. Compteur `stats.census_scans`.
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
- **Pilotage sans joueur** : `levels_upgrade` (motif du refus, dont « cc-families »), `levels_row`,
  `levels_status` (interface distante, pour le banc de contenu ; `levels_time_factor` retiré au lot V2c).
- **Emprise par niveau (lot V3-T, Q23 et Q24, intégré le 22/10 à 14 h 50, version 0.4.2 ; E44).**
  - **Table.** `L.footprints` (`shared/levels/config.lua`) donne le côté de l'emprise par famille : par ère
    (`era`, 5 côtés, une ère = `L.ERA_EPOCHS` = 3 époques) ou niveau par niveau (`level`). `L.footprint(famille, n)`
    le lit ; une famille absente garde `family.size`. Ligne livrée par V3-T : `gun = { era = { 2, 3, 4, 5, 6 } }` ;
    depuis V3-T2 (0.4.3), toutes les familles sauf le mur (voir plus bas ; chiffres : BALANCE_SHEET §12).
  - **Garde.** `L.footprint_errors()` refuse une ligne dont la famille est inconnue, la forme fausse, un côté non
    entier, une emprise qui rétrécit, ou un niveau 1 différent de `family.size` (le niveau 1 EST le bâtiment
    vanilla, jamais retouché). Elle est appelée en tête de `Common.generate` : l'étape data s'arrête avec le motif.
  - **Prototypes.** `apply_footprint` (`prototypes/levels/common.lua`) ne touche que les niveaux dont le côté
    diffère du niveau 1 : boîtes au style vanilla (sélection = le carré exact, collision = le carré réduit de
    0,3 tuile de chaque côté), `drawing_box` à l'échelle, portée des tourelles + `L.range_bonus` (la portée du
    moteur se mesure depuis le centre), et points de jeu déplacés par `move_point` (voir plus bas).
    `footprint_problems` arrête l'étape data si un raccord de tuyau ou le point de dépôt tombe dans la boîte de
    collision, si un raccord n'est pas sur un centre de tuile, ou si la zone d'extraction est plus petite que
    l'emprise. Depuis la suite V3-T (E47), le banc de l'étape data vérifie aussi les règles des raccords et du dépôt
    pour toute entité du mod (`tests/datastage/engine_rules.lua`). Le groupe de remplacement rapide reste commun à
    toutes les tailles (F72). Le sprite est agrandi
    du rapport des côtés (`kit.sprite_scale`) : visuel PROVISOIRE, sans détail ajouté.
  - **Règle de position** (texte de référence, mot pour mot : en tête de `shared/levels/footprint.lua`). Le
    nouveau bâtiment (côté b) CONTIENT l'ancien (côté a), aligné sur la grille : (b − a + 1)² candidates. Ordre
    déterministe : la plus centrée d'abord (dx² + dy² le plus petit), puis, à égalité, côté IMPAIR : nord puis
    ouest ; côté PAIR : sud puis est. La première position LIBRE est retenue. Aucune libre : refus « no-room »,
    rien de payé, et le contour montre la position LA PLUS FACILE À LIBÉRER (d'abord sans tuile bloquante, puis
    le moins d'entités, puis le moins de tuiles, puis l'ordre de préférence). Conséquence voulue : en montant
    d'une taille à la fois (2 → 6), le bâtiment se décale d'une demi-tuile vers le nord-ouest aux tailles
    impaires et revient sur son centre d'origine aux tailles paires.
  - **Ce qui bloque** : une tuile qui touche le masque du nouveau prototype (eau, hors carte) ; une entité dont
    la boîte touche la nouvelle et qui partage une couche, sauf l'ancien bâtiment, les personnages (écartés par
    `move_stuck_players`, F71), les unités et les objets au sol (sortis après l'agrandissement, F75). « Touche »
    veut dire ici « chevauche » : les recherches par zone du moteur rendent aussi le simple contact bord à bord
    (F96), donc `Levels.room`, `remove_ghosts` et `move_ground_items` refiltrent par chevauchement strict
    (`Foot.overlap`) ; un objet au sol qui touche seulement le bord du nouveau bâtiment n'est ni sorti, ni compté,
    ni journalisé (lot R1, E53 ; avant le 22/10, `move_ground_items` le poussait et le comptait à tort). Ressources
    et fantômes ne bloquent jamais (couches absentes du masque) ; le fantôme de mur recouvert a été retiré par
    le moteur lui-même (F74, un seul cas observé) ; le filet `remove_ghosts` du script couvre les autres cas,
    non observés en moteur réel ; les décors sont retirés (`destroy_decoratives`).
  - **Remplacement.** À taille égale : le remplacement rapide moteur d'avant (F39), inchangé. Quand la taille
    change : remplacement PAR SCRIPT (`Levels.resize_replace`) : `create_entity` SANS `fast_replace` à la position
    retenue (`raise_built`, `move_stuck_players` ; F70), puis transfert du contenu (`Levels.transfer` : munitions,
    abattages et dégâts, fluides, brûleur, recette et progression, fils et réglages de circuit ; PV en
    proportion et direction posés par l'appelant, `replace`, fonction locale, ou `Levels.migrate_footprints`),
    décors, fantômes et objets au sol, et enfin destruction de l'ancien sans événement. Si un gestionnaire détruit le nouveau (F40), l'ancien reste intact et `refund` rend chaque part du coût à
    l'inventaire qui l'a payée (relevé de `pay`).
  - **Ordre des motifs.** La place est calculée dans l'aperçu, donc AVANT le paiement ; « no-room » ne passe
    qu'APRÈS les autres motifs (« max », « no-cc », « cc-too-low », « unknown-item », « cc-families »,
    « no-resources » ; `Levels.preview`). Le test c2. de `levels_test` ne vérifie que l'ordre « no-resources »
    avant « no-room ».
  - **Contour de refus.** `rendering.draw_rectangle` à durée limitée (`Levels.CONTOUR_TTL` = 300 ticks) : le carré
    nécessaire en orange, chaque entité et chaque tuile qui gêne marquées en rouge ; visible du seul joueur qui a
    demandé, sinon de la seule force du bâtiment (F73) ; rien dans `global`, effacé par le moteur. Compté dans
    `stats.contours`.
  - **Aperçu du panneau.** Pour son seul joueur, tant que le panneau est ouvert : carré vert de la position
    retenue (avec la direction écrite si ce n'est pas la préférée), ou contour orange à libérer ; redessiné à
    chaque rafraîchissement, durée jusqu'au rafraîchissement suivant + 2 ticks (jamais empilé), non compté comme
    refus. Le bouton reste actif pour « no-room » (le clic refuse sans payer et dessine le contour 300 ticks).
    Prouvé en moteur simulé seulement.
  - **Migration.** `global.fo.levels.footprints` garde le relevé des côtés de la version qui a écrit la
    sauvegarde (nombres seulement ; absent avant V3-T). `Levels.migrate_footprints` compare ce relevé à la
    table : bâtiment reposé à la première position libre (même transfert, crochets `on_replaced`, centre suivi)
    ou laissé en place, compté et journalisé ; les chantiers hérités forcés prennent la position la plus facile
    à libérer. Déclencheurs : `on_configuration_changed` (via `Levels.repair`, voie normale : montée de version)
    ET, à défaut, le filet `on_nth_tick(30)`, au premier passage où `Levels.footprints_stale()` voit un relevé
    périmé. Prouvé en moteur simulé, puis **en moteur réel le 22/10** sur une carte de banc créée par 0.4.1
    (RD_LOG E46, H-T3). Le moteur appelle `on_configuration_changed` même SANS montée de version, avec
    `mod_changes` vide, quand les données de prototypes ont changé (F77 ; attribution aux données : déduite,
    non prouvée) : c'est alors aussi `Levels.repair` qui migre. Le filet n'a servi qu'en expérience de
    contrôle ; aucun cas réel connu n'en dépend. Au chargement, l'entité agrandie garde sa position et prend la
    nouvelle boîte avant la migration (F76) ; un bras qui la nourrissait a visé seul la nouvelle entité (F79 ;
    un seul cas joué : bras à combustible). Une mitrailleuse sans place reste hors grille, avec sa nouvelle
    taille (question Q-T3, rattachée à Q-T2-1).
  - **Pilotage sans joueur.** `levels_upgrade` et `levels_preview` rendent `resize`, `position`, `candidate`,
    `contour`, `contour_candidate` et `blockers` ; `levels_status` ajoute `resized`, `room_refused`, `contours`,
    `forced`, `resize_failed`, `ghosts_removed`, `ground_moved`, `ground_left`… et, depuis la suite H-T3,
    `footprints` (copie du relevé) et `footprints_stale` (le `global` d'un mod est illisible des autres, F35).
- **Toutes les familles (lot V3-T2, Q-S1 : oui ; intégré le 22/10 à 19 h 05, fusion `681dd5c`, version 0.4.3 ;
  RD_LOG E49 à E52, F83 à F95).**
  - **Table.** `command {4,5,6,7,8}`, `gun {2,3,4,5,6}`, `laser {2,3,4,5,6}`, `drill {3,4,5,6,6}`,
    `furnace {2,3,4,5,6}`, `assembler {3,4,5,6,6}` ; le mur n'a pas de ligne. Rien n'a changé dans
    `apply_footprint` ni `footprint_problems` : la mécanique de V3-T suffit pour les 6 familles.
  - **Règle des points servis** (`shared/levels/points.lua`, pur ; `Levels.served_points` ; 3 lignes de
    `Foot.evaluate`), complément de la règle de position. Un point de jeu de l'ancien bâtiment (dépôt d'une foreuse
    lu par `drop_position`, raccords de tuyau lus par `get_pipe_connections`, souterrains exclus) est SERVI si une
    entité qui bloquerait le nouveau bâtiment s'y trouve (pour un raccord : une entité à boîte à fluide). Les points
    sont ramenés à l'orientation nord (`Points.unrotate`), portés à l'ancien et au nouveau côté (`Points.transpose`),
    puis chaque candidate est marquée (`Points.mark`) : une position qui ferait sortir un point servi de la boîte de
    collision de l'entité qui le sert n'est PAS libre. Cette entité compte alors comme une gêne (`cand.moved`) : elle
    est désignée en jaune dans le contour (« point:<nom> »), comptée pour la position la plus facile à libérer, et
    dite à part dans le panneau (ligne `points-moved`). Dépôt sur un convoyeur : tout convoyeur au nouveau point le
    sert (sinon une rangée de foreuses perdait ses bouts). Égalités à `Points.TOL` = 1/64 près : le moteur rend les
    positions en virgule fixe (F92). Pour chaque orientation, une position garde le point servi : seule la place
    autour en décide. Raison : la règle de position ignore l'orientation, et une foreuse tournée vers le sud ou
    l'ouest déposait à côté de son coffre (E51).
  - **Remplacement par script, compléments** (`Levels.resize_replace`) :
    - recette donnée à la CRÉATION (`recipe =` de `create_entity`) : sans recette, un assembleur n'est pas orientable
      et `direction` est ignorée (F91) ;
    - téléport sur place (`new.teleport(new.position)`) après la destruction de l'ancien, pour toute entité à boîte
      à fluide, puis `update_connections()` pour une foreuse : sans lui, le nouveau bâtiment n'est pas raccordé aux
      tuyaux que l'ancien occupait (F90) ;
    - inventaires (`Levels.transfer`) : filtres des cases recopiés AVANT les objets ; barre rouge recopiée APRÈS, et
      seulement si elle limitait (`get_bar()` ≤ nombre de cases ; un coffre sans barre rend nombre de cases + 1, F95).
  - **Fabrication en cours (progression notée).** Un four neuf ignore l'écriture de `crafting_progress`, et une
    fabrication en cours a déjà pris ses ingrédients (F83). `resume_later` rend donc les ingrédients de la
    fabrication en cours à la nouvelle machine (objets ; fluides à la température de l'ancienne boîte, sinon au
    minimum de la recette ; ce qui n'entre pas est renversé, ou compté dans `fluid_lost`) et note la progression dans
    `global.fo.levels.pending[numéro]` = { entity, recipe, progress, bonus, tick } (aucune fonction).
    `Levels.resume_progress`, abonné à `on_tick`, la repose (progression et bonus de productivité) au premier tick où
    la machine refabrique la même recette ; autre recette ou machine disparue : entrée retirée ; au-delà de
    `Levels.PENDING_TTL` = 3600 ticks, entrée oubliée (seule la fraction de fabrication est perdue). Dans le cas
    courant, la liste est vide : corps de la fonction à liste vide, 100 000 appels en boucle, 0,10 à 0,38 µs par
    appel ; coût de l'appel de l'abonnement par le moteur à chaque tick : non mesuré (H-L1, mesure partielle). L'entrée suit la machine si elle
    est remplacée de nouveau avant d'avoir repris (par script : `Levels.transfer` ; par le moteur : `replace`), et
    une progression notée d'une machine déjà repartie est reposée AVANT une nouvelle amélioration (défauts 2 et 15,
    moteur simulé seulement). Jamais de progression écrite hors fabrication : écrite sur un assembleur à l'arrêt (seul cas joué),
    elle rend `is_crafting()` vrai et
    donne une fabrication gratuite (F84) ; une machine en « sortie pleine » est en fabrication à 1,000 (F93). À
    taille égale, le remplacement rapide moteur garde la fabrication (F94).
  - **Bâtiment hors grille** (laissé par une migration ; F86). `Levels.off_grid(entity, côté)` (jamais pour un 1×1) ;
    `Levels.current_box` : son emprise actuelle est le carré de côté + 1 qui contient exactement sa boîte, ce qui
    rend la règle de position valable telle quelle (un agrandissement le contient ; à côté égal, il est REMIS sur la
    grille à une demi-tuile au plus, cas « côté plus petit » de `shared/levels/footprint.lua`). `replace` ne le fait
    JAMAIS passer par le remplacement rapide moteur, même à côté égal : `create_entity{fast_replace = true}` recalerait
    la position, ne remplacerait rien et poserait le nouveau par-dessus l'ancien (F86). `Levels.preview` le traite
    comme un changement d'emprise (`resize.regrid = true`) : place vérifiée avant le paiement, sinon refus
    « no-room » et contour ; le panneau ajoute la ligne `regrid-line`.
  - **Migration, compléments.** Message aux joueurs (`Levels.tell_migration`, appelé par `Levels.repair` et par le
    filet) : par force, dans l'ordre des noms, le nombre de bâtiments laissés hors grille, ce qu'ils deviennent, le
    remède et des liens de carte `[gps=x,y]` vers les 5 premiers (`migration-kept`) ; journal « [FO-LEVELS] message de
    migration à la force <nom> : <n> laissé(s), <m> doublon(s) », contrôlé par `ht3_journal.py`. Pas de repère sur la
    carte (il faudrait le suivre dans `global`). `Levels.find_stacked` relève les doublons SUPERPOSÉS hérités d'avant
    0.4.3 (deux bâtiments d'une même famille de côté ≥ 2 dont les centres sont à une demi-tuile au plus, issus de
    F86) : journal, compteur `stats.stacked`, message `migration-stacked` ; aucun n'est retiré.
  - **Pilotage sans joueur.** `levels_upgrade` et `levels_preview` rendent aussi `points` (« drop:iron-chest@x,y »,
    « pipe:… ») ; `levels_status` ajoute `resumed`, `pending`, `fluid_lost` et `stacked` ; `levels_bench_resume(n)`
    (banc seulement) mesure n appels de `Levels.resume_progress` sous un `LuaProfiler`, au journal.
  - **Limites connues** : dans une usine réelle, une machine bordée de ses bras sur deux côtés opposés ne grandit
    jamais sans démontage, et 18 machines sur 24 d'une usine dense restent hors grille à la migration (question
    Q-T2-1 ; depuis 0.4.4, bouton « Libérer la place », ci-dessous, qui ne libère pas le milieu d'une rangée collée) ;
    la production par tuile baisse quand la machine grandit (question Q-T2-2, BALANCE_SHEET §12 ; réponse A appliquée
    par le lot V3-T4 sur sa branche, NON intégrée : Q-T4-1).
- **Libérer la place (lot V3-T3, Q-T2-1 : « QT21 option B » ; intégré le 22/10 à 22 h 50, fusion `8a28804`, version
  0.4.4 ; RD_LOG E56 à E59, F103 à F110).** La règle Q24 ne change pas : sans clic, refus « no-room » et contour. Le
  bouton du panneau (`free-button`, motif « no-room » seulement) et l'interface distante appellent `Free.free_room`
  (`script/levels/free.lua`, aussi `Levels.free_room`) ; `free.lua` est chargé par `panel.lua` et `remote.lua`, pas
  par `control.lua`.
  - **Règle pure** (`shared/levels/clear.lua` ; texte de référence, mot pour mot, en tête du fichier). `C.plan(input)`
    dit, pour UNE candidate, quoi marquer, où poser chaque fantôme et quoi signaler : sortie minimale (côté le plus
    proche, puis ordre fixe) ; bras décalé le long de SON axe avec ce qui le sert (petit contenant décalé, ligne
    RACCOURCIE, ou BOSSE de la ligne qui longe le bâtiment, F106) ; convoyeur jamais décalé seul ; tuyau seulement
    raccourci, sinon signalé ; poteau décalé si chaque fil de cuivre reste à portée et si la zone d'alimentation est
    gardée (`C.supply_kept` ; poteaux cherchés jusqu'à `Free.POLE_REACH` = 12 tuiles : contrôle prudent) ; murs
    décalés par couloirs, ligne refermée par des murs de BASE (un mur de niveau ne se fabrique pas) ; arbres et
    rochers marqués, rien à reposer ; bâtiment voisin, autre force, falaise, eau, véhicule, gêneur réservé par une
    autre demande : SIGNALÉS, jamais marqués. Plus de `C.MAX_MARKS` = 64 gêneurs : refus « too-many ». Un fantôme ne
    va jamais dans le nouveau carré, sur une entité restante, un autre fantôme, l'ancien bâtiment ni une tuile
    bloquante : contrôle PUR sur la scène relevée, le moteur ne protège pas la place d'un fantôme (F105, F108).
  - **Tout ou rien par demande, plan COMPLET seulement.** `C.choose` essaie la candidate du contour, puis les autres
    dans l'ordre « la plus facile à libérer » de `footprint.lua`, et retient la première dont le plan est complet ;
    sinon : refus, rien de marqué, aucun fantôme, aucune demande ; les gêneurs sont entourés de VIOLET au sol et listés
    avec leur position `[gps]`. Exécution : marques (`order_deconstruction`, force du bâtiment, le joueur comme dernier
    utilisateur ; robots, ou le joueur à la main ; le mod ne détruit rien), puis fantômes (`entity-ghost` sans
    expiration, même nom, même orientation, réglages recopiés par `copy_settings`, taille de pile posée à part : F107).
    Une marque ou un fantôme refusé par le moteur retire tout ce qui a été posé (fantômes d'abord, puis marques : F103),
    motif `engine-refused`. Les fils de circuit d'un gêneur reposé ne sont PAS refaits (message `free-wired`).
  - **Relevé = critère de `Levels.room`** (`Levels.blocks`, `Levels.mask_layers`, plus la couche des objets et les
    fantômes ; scène triée par y, x, nom, numéro). Une gêne de la candidate absente du relevé est signalée, jamais
    ignorée. Carrés et gêneurs RÉSERVÉS : aucun fantôme dans le carré d'une autre demande de la surface ; un gêneur
    marqué par une autre demande, ou qui porte un de ses fantômes, est signalé.
  - **Coût exigé au clic** : condition Q16 et coût réunis (sinon refus, par exemple `no-resources`) ; le paiement a
    lieu à l'agrandissement (centre, puis inventaire du joueur connecté). Le coût n'est pas bloqué : dépensé entre le
    clic et la libération, il donne un message et la demande attend.
  - **Demande en attente.** Vérification toutes les `Free.PERIOD` = 60 ticks (`on_nth_tick`, `Free.check` ; liste vide :
    un seul test). Décision restreinte au carré libéré (`Levels.room(…, only_box)`, `Levels.preview` et `Levels.start`
    avec `opts.box`) ; crochet `Levels.pending_box` lu par `Levels.preview` : tant qu'une demande attend, le bouton
    « Améliorer », la touche U, la rangée et l'interface distante ne visent que ce carré. Carré, gêneurs encore marqués
    et places des fantômes redessinés à chaque vérification. Durée de vie `Free.TTL` = 108 000 ticks (30 min de jeu).
  - **Annuler, expirer, bâtiment disparu** (`Free.cancel`) : l'usine est REMISE COMME AVANT, dans l'ordre a à f de
    `free.lua` : (a) fantômes déjà construits : l'entité construite est marquée à démonter (retrouvée par nom, position,
    direction et force : F109) ; (b) places d'origine des gêneurs déjà démontés contrôlées, source de réglages choisie ;
    (c) fantômes du mod retirés ; (d) fantômes d'ORIGINE posés, réglages recopiés ; (e) sources restantes retirées ;
    (f) marques du mod annulées EN DERNIER (F103). Place d'origine prise : comptée et dite avec sa position
    (`free-restore-blocked`, jamais rencontrée en moteur réel). Rien d'autre n'est touché.
  - **`global.fo.levels_free`** (namespace `levels_free`, déclaré dans `free.lua`) : `list` (demandes, liste ordonnée,
    dans l'ordre de création), `next`, `names`, `stats`. La liste des demandes ne garde QUE des nombres : identifiant,
    numéro d'unité, index de surface, de force et de joueur, positions, carré, niveau, ticks, directions, groupes et
    l'INDICE d'un nom de prototype (contrôle du moteur simulé). **Écart à la règle « nombres seulement », écrit tel
    quel** : les noms de prototypes, nécessaires pour reposer un gêneur à l'identique quand on annule, sont gardés en
    CHAÎNES dans `levels_free.names` (liste ordonnée, une fois chacun, hors de la liste des demandes ; jamais l'ordre
    de `pairs`). Ce sont des données simples, sans entité ni fonction ; l'écart est signalé par le correcteur comme
    écart à faire valider ; il est gardé tel quel à l'intégration (22/10, fusion `8a28804`), mais n'a pas encore été
    soumis au Directeur Créatif (tâche ouverte : faire valider ou retirer, OBJECTIFS §7 et REPRISE §7).
  - **Pilotage sans joueur** (`script/remote.lua`) : `levels_free_room(entity[, player_index[, {dry = true}]])` (`dry` :
    plan seul, rien de posé ; motif `dry` ou le refus), `levels_free_cancel(entity)`, `levels_free_status()`,
    `levels_free_check()` (vérification tout de suite).
  - **Limites** : seul un bâtiment qui a un côté libre se libère ; au milieu d'une rangée collée, un voisin gêne toujours
    (plan seul : 5 libérables sur 19 dans l'usine dense de `t2-migration`, 2 sur 13 dans la défense dense de
    `t2-defense`, création 0.4.1 ; E59) ; fusion de deux réseaux électriques par le raccord automatique d'un poteau
    reposé : non traitée ; coût en temps non mesuré (H-L1).
- **Déplacement des points de jeu (lot V3-T, `move_point` ; depuis V3-T2 dans `shared/levels/points.lua`,
  `Points.move_point`, recopié tel quel et lu par `prototypes/levels/common.lua`).** Du côté a au côté
  b, centre du bâtiment = origine :
  - une coordonnée AU-DELÀ du bord (|v| ≥ a/2) garde son écart au bord : signe(v) × (|v| − a/2 + b/2) ; un
    raccord à une demi-tuile hors d'un 3×3 (± 2) reste à une demi-tuile hors d'un 6×6 (± 3,5) ;
  - une coordonnée À L'INTÉRIEUR est portée à la même proportion du côté, puis calée sur le centre de tuile le
    plus proche du nouveau côté (à égalité, le plus petit ; jamais « −0 ») ;
  - rayon d'extraction : r + (b − a)/2 (foreuse 3×3 : 2,49, soit 5×5 tuiles ; en 6×6 : 3,99, soit 8×8).
  Concernés : raccords de toutes les boîtes à fluide, `vector_to_place_result`, `resource_searching_radius`.
  Non déplacés : fils de connexion, connecteurs de circuit, image de la zone d'extraction.

## 7 ter. Kits de rendu des familles à niveaux (`tools/render/pieces/levels/`)

Outillage hors du mod en jeu (Blender 5.2.2 et Python 3.9, toujours par `tools/render/with_render_lock.py`). Depuis le lot A2
(version 0.4.6), les images de la mitrailleuse sont en jeu : feuilles en fin de section.

**`gun_e/` : la mitrailleuse validée par le DC** (15 âges, 23/10, 14 h 50 ; fusionné par `93e3d89`). Un fichier par
âge (`ep01.py` à `ep15.py`), `corps.py`, `piece.py` (table des variantes), `rendre.py`, `batch_blender.py`,
`accroches.py`. **Directions de la tête (lot A1, dégel D-9, fusionné par `5a95650`)** : `piece.DIRS["dKK"]` =
−2π·K/64, K = 00 à 63, 0 = nord, sens horaire (convention du moteur, E70) ; `d00` = `N` et `d16` = `E` à l'égalité exacte
des flottants (identité des sprites validés prouvée octet à octet) ; variantes `eNN-tete-dKK` et `kS-tete-dKK`
construites à la demande (la table explicite reste de 72) ; `rendre.py --dirs rose|N,NE,…|d00,…`. Le moteur choisit
l'image par `apply_projection` (F121) : garder des feuilles en rotation uniforme. Outils d'expérience : `identite.py`,
`rose.py`, `e66.py`, `e66_temps.py` et `e66_temps_blender.py` (rendu passe par passe dans une seule session).
Limite : `batch_blender.py` ne règle pas encore les échantillons par passe (décision D-7 ; préalable du gain E66).

**`commun/` : le kit commun des familles (lot K0) : intégré** (lot INT-K0, fusion `e4e8416`, 23/10 vers 18 h 40 ;
branche `worktree-wf_2bade7c0-0e8-2`, tête `87c4fb1`). Structure :
- déplacés de `gun_e/` (`git mv`) : `kit.py`, `parts.py`, `parts2.py`, `parts3.py`, `formes.py`, `silhouettes.py`,
  `construction.py`, et les outils de contrôle `compo.py`, `ilots.py`, `gris.py`, `mesures.py`, `dominance.py`,
  `vignettes.py`, `apercu.py` ; nouveaux : `habillage.py`, `pont.py`, `repere.py`, `places.py` (solveur
  d'accroches ; les obstacles propres à la mitrailleuse restent dans `gun_e/accroches.py`) ;
- **registre des âges `ages.py`** : noms (ère V cosmique : 13 Antimatière, 14 La Porte, 15 Néant), ères, FAMILLES de
  couleur des foyers (E72), palettes d'âge copiées des `epNN.py` (`FOYER`, `CORPS`, `matieres(N, …)` dans l'ordre
  d'origine des appels `metal()`, pour garder les graines), table explicite `PALETTE[N]` (dominante, secondaire,
  accent, lumière, source) contrôlée à l'import ; `gun_e/epoques.py` et les `epNN.py` le lisent ;
- **profils de famille** : `commun/famille.py` (contrat d'un `profil.py` : nom, âges, emprise par âge, poses,
  référence vanilla, cibles de la charte, trous voulus, composition d'un niveau, variantes d'une ronde…, contrôlé au
  chargement) ; un profil par famille, `<famille>/profil.py` (exemple : `gun_e/profil.py`) ; choix par `--famille NOM`,
  sinon `FO_FAMILLE`, sinon `gun_e` ; `famille.charger` oublie les modules d'une AUTRE famille avant de charger un
  profil (défaut 1 de la vérification ; test `commun/tests/test_famille.py`, famille factice `fam_essai`) ;
- **contrôle d'empreinte FORTE** : `construction.py --tout --forte --matieres` (construction SANS rendu : tous les
  objets de `bpy.data` dont les lumières de halo, propriétés RNA dont `matrix_world`, modificateurs, données des
  lumières, maillage évalué en monde, matières complètes, monde, et relevé des appels `mat_metal`, `mat_emissive`,
  `mat_flat` avec leurs graines) ; `empreintes.py --forte` compare deux empreintes et nomme les objets, matières et
  graines qui diffèrent. **Règle : toute retouche du kit commun rejoue ce contrôle contre l'empreinte de référence**
  (`fo-logs\2026-10-23_suite\K0\correction\avant.json` pour les 72 variantes d'avant A1 ; `avant_hab.json` pour les
  habillages d'essai) ; attendu : « 0 différente(s), 0 absente(s) (forte) ». L'empreinte sans `--forte` ne voit ni
  les halos ni les positions : ne plus s'y fier ;
- mode d'emploi : `commun/LISEZMOI.md`.
Restent dans `gun_e/` : `rendre.py`, `batch_blender.py`, `accroches.py`, `corps.plateforme` (le lot A1 les modifiait
en parallèle). **Graines de bruit inertes** dans Blender 5.2.2 (F136) : les graines ne changent aujourd'hui aucune
image ; les activer changerait tous les designs validés (décision du DC). Non prouvé : un profil d'une autre famille
que la mitrailleuse ; `stone-wall` n'est pas mesuré pour la charte (`dominance.py` refusera le mur).

**Feuilles du jeu de la mitrailleuse (lot A2, décision D-6, version 0.4.6)** : `gun_e/feuilles.py` découpe les rendus
validés (sources dans `<racine>\fo-logs\`, à GARDER : `2026-10-23_V3E-p5\bas\sprites` et `haut\sprites`,
`2026-10-23_V3E-ereV\sprites`, `2026-10-24_A2\sprites`) en feuilles du jeu dans `graphics/levels/gun/` (318 PNG,
13,04 Mo, HORS de git par `.gitignore`) et écrit `sprites.lua` (lu par `prototypes/levels/gun.lua`), `sprites.json` et
`MANIFEST.json` (fichier, taille, sha256, dimensions), commités ; l'outil est déterministe. Par âge : socle, pièce des
niveaux pairs (posée APRÈS le socle), tête à 4 directions (feuille en colonne N, E, S, O, F123), lueur, halo
`draw_as_light`, ombres, icône d'âge ; bouche de tir par âge ajustée sur la règle du moteur (F126, F129 ; refus au-delà
de 0,5 tuile). Contrôles : `gun_e/check_gun_sheets.py --sources [--mutants]` (sha256 contre le manifeste, poses au pixel
contre les sources) ; `tests/datastage/gun_sheets.lua` (Lua pur, branché sur le harness et `levels_test` : chaque PNG du
manifeste présent, à la bonne taille, sinon la commande de régénération est imprimée) ; règle « images » du harness
(`tests/datastage/images.lua` : fichiers présents, rectangles dans l'image ; étalonnée sur la vanilla). **Checkout ou
worktree neuf : lancer `feuilles.py` d'abord.** Les bancs recopient les PNG présents sur le disque (F127). Bouchon
arrière (`corps.bouchon_arriere`) posé dans le secteur d20 à d44 seulement, âges 4 à 7 : le saut à la frontière du
secteur est à juger en A3. Les 6 autres familles gardent `kit.provisional`.

**Sons des familles (lot S0, version 0.4.7)** : `tools/sound/sons.py` (numpy, scipy ; `blender_audio.py` pour le
module `aud` de Blender, toujours par `with_render_lock.py`) dérive des sons vanilla (`<racine>\data\base\sound\`,
lecture seule) les sons du mod dans `sound/levels/<famille>/` : OGG COMMITÉS (petits), `sons.lua` généré (lu par
`prototypes/levels/gun.lua` pour `attack_parameters.sound`, niveau par niveau selon l'ère), `MANIFEST.json` ; volume
mesuré sur l'OGG livré, jamais au-dessus de la vanilla ; timbre plus grave à chaque ère (contrôlé) ; octets
reproductibles (F154) ; `sons.py --check`. Règle « sons » du harness (`tests/datastage/sounds.lua`) : tout son cité
existe, au bon format et au bon en-tête (un son manquant bloque le jeu au menu, F151). Sessions de test avec son :
`FO_AUDIO=1`, pilote SDL `disk` pour le seul jeu de test, garde de crête `tools/autotest/audio_guard.py` (CLAUDE.md §4).

## 8. Chaîne de vérification

| Banc | Ce qu'il prouve | Ce qu'il ne prouve pas |
|---|---|---|
| `tests/datastage/harness.lua` | L'étape data s'exécute (core + base + mod, dans l'ordre moteur) ; schéma, références, localisation FR/EN ; règles moteur connues (ex. `slice` des animations tournantes, F23). **Règle des points de jeu** (suite V3-T, E47, `tests/datastage/engine_rules.lua`) : raccords hors de la boîte de collision et sur un centre de tuile, dépôt de foreuse hors de la boîte et des tuiles, pour toute entité ; exception vanilla : le chevalet de pompage (F82) ; auto-contrôle de 11 cas, compté dans les violations. Résultat attendu au 22/10 (17 h 06 à 17 h 13, `main` ; inchangé après le lot V3-T2, 19 h 09) : 911 prototypes ajoutés ou modifiés, 0 erreur nouvelle, « Règles moteur : 0 violation(s) », points de jeu vanilla 18 entités / 51 points et mod 61 / 182, auto-contrôle 11/11, 0 clé manquante | Rendu, génération de carte réelle ; ce que fait le moteur réel d'un raccord ou d'un dépôt mal placé (déduit de la géométrie, non observé) |
| `tools/api_lint.py` | Chaque appel runtime existe en 1.1.91, avec la bonne forme d'appel (**669 usages**, 0 erreur sur `main` le 23/10 vers 17 h 50, après les fusions des lots A1 (scénario `a1-tourelle`) et M0 (garantie, scénarios `monde`, `m0-reprise`, `m0-migration`) ; avant : 609 usages, 0 erreur au 22/10, vers 22 h 55 (bancs hors jeu de 22 h 50 environ à 22 h 55, fin de la sortie à 22:55:17), `main` après le lot V3-T3 : marques, fantômes, `copy_settings`, `revive`, scénarios `t3-libere` et `t3-migration` ; le correcteur du lot annonçait 615 dans son worktree, écart non expliqué ; 535 après le lot R1, 519 après le lot V3-T2, 447 avant ce lot, 434 avant les suites de V3-T) | Comportement à l'exécution |
| `tests/*.lua` (moteur simulé) | Logique runtime, cerveau d'équipe sur les vraies recettes, sérialisabilité, déterminisme, rechargement, migration ; résultats attendus au 22/10 : CLAUDE.md §5 (dont migration 82 et levels 1 642 depuis le lot V3-T3 : 41 cas purs de la règle de décalage (`tests/levels_clear_cases.lua`) et 23 contrôles de `free.lua` en moteur simulé (voiture, annulation après démontage et après reconstruction, demandes voisines, refus du moteur, plan seul, crochet, coût absent ; liste des demandes en nombres), namespace `levels_free` créé vide au chargement ; migration 81 et levels 1 577 depuis le lot R1 : contact bord à bord, objet au sol qui touche seulement le bord ; migration 79 et levels 1 575 depuis le lot V3-T2 : points servis, reprise de progression, hors grille, doublons, message de migration). **Moteur simulé** (suite V3-T, E47) : boîtes de collision et masques vanilla des prototypes intégrés (relevés par `harness --dump-final`), `bounding_box` et recherche par zone sur la boîte, en **intervalles fermés** depuis le lot R1 (contact par un bord ou un coin compris, comme le moteur réel : F96, E53 ; exclu jusqu'au 22/10, par choix non observé), filtre `collision_mask`, `get_control_behavior`, `get_recipe` et `set_recipe`, `destroy_decoratives` relevé ; option `legacy_boxes` = ancien modèle, pour comparaison seulement. Attentes de `levels_test` et `migration_test` tirées de `L.footprints` ; `FO_DATA_DIR=<racine>/data` pour une copie du mod hors de l'arborescence du jeu | Fidélité du moteur (exemple : le moteur simulé ne retirait pas les fantômes recouverts, le vrai moteur le fait, F74) ; filtre `position` seule (ignoré), `limit` de la recherche non inversée, `count_entities_filtered` ; les prototypes que les bancs déclarent sans boîte restent en 1×1 ; ni barre de coffre, ni boîte à fluide, ni orientation : les mutations m15, m16 et m17 du lot V3-T2 y survivent (tenues en moteur réel par `levels_points`, E51) |
| `fo-autotest.bat` scénario `content` | **Le vrai jeu** : chaque recette dans sa machine, chaque module, chaque munition, tourelle et arme portative en duel, les contres voulus, ennemis, nids, biomes, niveaux. **317 contrôles** depuis le lot V3-T2 (22/10, `main`, `done.txt` 19:05:39,98) : 210 du banc, dont 63 de niveaux ; 2 de l'exemple greffé ; 26 du greffon `levels_taille` (mitrailleuse : agrandissement sur place, refus et contour, transfert, chaîne 6 → 30) ; 54 de `levels_machines` (laser, foreuse, four, assembleur, centre : transfert réel, raccord et dépôt, usine dense, chaînes 6 → 30 et 1 → 15, prototypes) ; 25 de `levels_points` (points servis dans les 4 orientations, refus, fabrications en cours, F84, barre, coût du `on_tick`). La ligne du journal dit « exemple 2 OK 0 ECHEC, levels_taille 26 OK 0 ECHEC, levels_machines 54 OK 0 ECHEC, levels_points 25 OK 0 ECHEC ». 238 avant ce lot | Rendu ; panneau et aperçu au sol (pas de joueur en mode benchmark) ; seconde amélioration avant le `on_tick` du mod (défauts 2 et 15) ; raccords du fluide de minage et boîte à fluide de sortie |
| `fo-autotest.bat` scénario greffé `t2-machines` (1 500 ticks) | Les greffons `levels_machines` et `levels_points` joués au tick 60 (états séparés ; refus rejoués au tick 1440), pour qu'une session avec images (`fo-captures.bat t2-machines`) photographie les machines APRÈS l'agrandissement et les contours de refus. **80 contrôles** (22/10, `main`, 19:05:44,44) | Comme `content` |
| `fo-autotest.bat` en **double source** (`FO_CREATE_SRC`), scénarios greffés `ht3-migration` et `t2-migration` + `ht3_journal.py` | **Une vraie sauvegarde d'une version ancienne migrée par la nouvelle** (suite H-T3, E46 ; lot V3-T2, E50) : la carte est créée par la source de `FO_CREATE_SRC`, puis rejouée par la source habituelle. `ht3-migration` (création 0.4.1, `src-0.4.1`) : 30 contrôles depuis V3-T2 (mitrailleuses reposées, déjà en place ou laissées, munitions, PV, chevauchements, bras, relevé, filet, et le centre 15 qui grandit), puis 7 contrôles du journal hors jeu (`ht3_journal.py`). `t2-migration` (création 0.4.2, `<racine>\fo-logs\2026-10-22_V3T2\src-0.4.2` = `git archive c4d37e5`) : 64 contrôles (libres de chaque famille reposés ou déjà en place, contenu exact, paires collées, centres 15, 10 et 6, usine dense de 24 machines : 18 laissées hors grille et toujours en service, filet), puis 26 contrôles du journal (`ht3_journal.py --tag FO-T2-MIGRATION` : lignes « laissé en place », ligne de bilan, messages aux joueurs par force). Attendu au 22/10 (`main`, 19:05:48,49 et 19:05:52,39 ; rejoué après le lot R1 à 20:11:28,04 et 20:11:32,11) : 64 OK et journal 26 OK ; 30 OK et journal 7 OK. **`t2-defense`** (lot R1, E54 ; 1 200 ticks ; création 0.4.1 par `src-0.4.1` ou 0.4.2 par `src-0.4.2`) : ligne de défense de 21 tourelles (11 mitrailleuses, 10 lasers) en trois tronçons derrière un mur continu, un bras électrique par mitrailleuse sur un convoyeur de munitions, 24 poteaux sur une interface électrique ; 36 contrôles (classement nominatif par tronçon et par version de création, contenu, chevauchements, compteurs, mur intact, réseau, munitions apportées par le bras, trois vagues de biters moyens, tir de chaque tourelle, filet), puis le journal (`ht3_journal.py --tag FO-T2-DEFENSE`). Attendu au 22/10 (`main`, 20:11:36,19 et 20:11:40,52) : création 0.4.1, 36 OK et journal 19 OK, « 8 reposé(s), 0 déjà en place, 13 laissé(s) » ; création 0.4.2, 36 OK et journal 11 OK, « 5, 0, 5 ». Depuis le lot V3-T3 (22/10), `t2-migration` et `t2-defense` journalisent aussi « LIBERER LA PLACE (plan seul, hors bilan) » : `levels_free_room` en plan seul (`dry`) pour chaque bâtiment laissé ; ligne HORS bilan, BILAN et journaux inchangés (rejoués sur `main` de 22:51:06 à 22:51:19 : 64 + 26, 30 + 7, 36 + 19, 36 + 11). Résultat : 5 libérables sur 19 (`t2-migration`), 2 sur 13 et 0 sur 5 (`t2-defense`) | Rechargement d'une carte déjà migrée ; disposition d'usine réelle ; aspect de la défense migrée (verdict du Directeur Créatif) ; gestes du joueur sur une tourelle laissée ; vraie attaque ; migration d'une machine EN fabrication (`--create` sauvegarde au tick 0) ; les sauvegardes du Directeur Créatif (jamais touchées) |
| `fo-autotest.bat` scénario greffé `t3-libere` (1 900 ticks, lot V3-T3) | **Le bouton « Libérer la place » en moteur réel** (E59), par l'interface distante `levels_free_room` comme le bouton du panneau : zones A (usine dense, bras FILTRANT), B1 (mitrailleuse collée au mur, Q-T3), B2 (mur épais et eau), C1 et C2 (Annuler, avant et après un démontage : usine remise comme avant), D (sans clic : rien ne change), E (coût absent, puis présent, retiré, revenu), F (refus « blocked » entre deux voisins), G (deux voisins libérés l'un après l'autre), R (VRAIS robots de construction : démontage, agrandissement, reconstruction par le moteur), V (voiture dans la candidate), L (clic après le bilan, pour les captures) ; forces `fo-t3`, `fo-t3p`, `fo-t3r`. Ailleurs qu'en R, le banc joue les robots (il mine les marques, puis construit les fantômes). Attendu au 22/10 (`main`, 22:50:58,19) : « [FO-T3-LIBERE] BILAN : 41 OK, 0 ECHEC(S) ». `fo-captures.bat t3-libere` : 4 images prises après le bilan (`shots_delay` = 1 840) | Le panneau et les boutons avec un vrai joueur, le jeu à la main ; l'expiration et le bâtiment disparu (moteur simulé) ; foreuses, fours, lasers et centre ; les fils de circuit des gêneurs (non refaits) ; les rangées collées (non libérables : voir `t2-migration` et `t2-defense`, plan seul) |
| `fo-autotest.bat` en double source, scénario greffé `t3-migration` (1 000 ticks, lot V3-T3) | **« Libérer la place » pour un bâtiment laissé HORS GRILLE par une vraie migration** (E59 ; un script ne sait pas fabriquer un bâtiment hors grille : F104). Création par `src-0.4.2` (deux assembleurs 8 collés, en 3×3), benchmark par 0.4.4 : l'assembleur laissé hors grille est refusé (« no-room ») ; au clic, bras sud et deux tuiles marqués, fantômes posés ; une fois les marques minées, il est remis sur la grille au niveau 9 de lui-même ; l'usine remarche. Attendu au 22/10 (`main`, 22:51:53,59) : « [FO-T3-MIGRATION] BILAN : 7 OK, 0 ECHEC(S) ». Un passage à 700 ticks est trop court (aucun BILAN) | Comme `t3-libere` ; un seul bâtiment hors grille joué |
| `fo-autotest.bat` scénario greffé `bord-a-bord` (60 ticks, lot R1) | **Le contact exact entre une zone de recherche et une boîte de collision, en moteur réel** (E53, F96 à F98) : 45 cas (mur de pierre, mitrailleuse vanilla, laser 7 du mod ; 4 bords, 2 coins, zones nulles, chevauchement et écart de 1/256, rayons), `find_entities_filtered` et `count_entities_filtered`, chacun comparé à la règle du moteur simulé (`STRICT = false` : intervalles fermés) ; un écart est un ECHEC, à corriger en alignant le moteur simulé. Attendu au 22/10 (`main`, 20:11:23,82) : « [FO-BORD-A-BORD] BILAN : 12 OK, 0 ECHEC(S) » | La `position` seule est journalisée, pas comparée (le moteur simulé l'ignore) ; troncature ou arrondi des boîtes (F98) ; les recherches du mod hors des niveaux (balayages par secteurs de `pvp.lua`, `sites.lua`, `war.lua`) |
| `fo-autotest.bat` scénarios greffés `monde` (700 ticks), `m0-reprise` (2 600 ticks) et, en double source `src-0.4.4` seulement, `m0-migration` (700 ticks) (lot M0) | **La garantie des monnaies en moteur réel** (§7.1) : `monde` joue nauvis (garantie à `on_init`, graine 20261020) et 5 autres graines sur des surfaces créées par le scénario (la graine de `fo-autotest.bat` est fixe) : surfaces neuves, explorées, sans les 3 ressources, avec obstacles, filet (E73, E74) ; `m0-reprise` : deux échecs provoqués puis la reprise au niveau 2 (eau comblée) ; `m0-migration` : une sauvegarde 0.4.4 (`<racine>\fo-logs\2026-10-23_suite\M0\src-0.4.4` = `git archive 93e3d89`, à GARDER) chargée par 0.4.5 (E76). Attendu sur `main` (23/10, `done.txt` 17:45:34,86, 17:45:39,32, 17:45:43,44) : « [FO-MONDE] BILAN : 89 OK », « [FO-M0-REPRISE] BILAN : 15 OK », « [FO-M0-MIGRATION] BILAN : 9 OK », 0 échec. `fo-captures.bat monde` : 9 captures, 91 OK (étiquettes de carte posées : la cartographie ne tourne qu'avec images, F131). Hors jeu : `tests/monde_test.lua` (157) | La voie `on_init` sur une autre graine de nauvis (graine paramétrable : lot INT-GRAINE, en cours) ; un échec naturel ; le niveau 3 de reprise (hors jeu seulement) ; l'accès à pied ; une sauvegarde avec base et guerre ; le visuel (verdict du DC) |
| `fo-autotest.bat` scénario greffé `a1-tourelle` (1 000 ticks, lot A1), sur une COPIE JETABLE | **Levée et directions d'une tourelle en moteur réel** (E67, E70) : `py -3.9 tools/autotest/a1/jetable.py --dest <dossier neuf, hors du dépôt>` recopie le mod et ajoute en fin de `data-final-fixes` des prototypes de test (têtes « flèches » numérotées, variantes de levée) ; puis `fo-autotest.bat nopause 1000 a1-tourelle "<copie>"` (et `fo-captures.bat a1-tourelle "<copie>"`). Attendu : « [FO-A1-TOURELLE] BILAN : 5 OK, 0 ECHEC(S) » (23/10, 15:56:07,00 ; 16:48:01,51 au vérificateur). Sur le mod livré, le scénario se refuse à l'init (« prototypes de test absents ») | `folding`, `attacking`, `starting_attack`, `ending_attack` ; une cible ennemie imposée ; une vraie feuille `dKK` en jeu |
| `fo-autotest.bat` scénarios `default`, `waves`, `pteam`… | **Le vrai jeu** sans affichage, dossiers isolés : guerre à économie réelle, défense de tours, équipe du joueur ; temps par tick et par poste ; étalon machine | Rendu |
| `fo-captures.bat` (= `fo-autotest.bat` + `fo-visual.bat`) + `shots.lua`, `vitrine.lua` | **Le vrai jeu avec images** (`--benchmark-graphics`, arrêt seul), captures automatiques, session fermée sans intervention, index et planche-contact ; vitrine d'entités à côté des références vanilla ; greffons de scénarios et de contrôles (`tools/autotest/README.md`) | Le jugement esthétique (verdict du Directeur Créatif) |
| `tools/autotest/tests/run_d4m.py` (banc D4m hors jeu) + `mut_atlas.py` + `mut_vram.py` | Hors jeu, en 5 étapes : essai à blanc du greffon `d4-geant`, fixtures synthétiques, unitaires de `vram.py` (99 depuis le lot R1, 57 avant), intégration de `visual_session.py`, et les 13 journaux archivés relus avec les atlas ATTENDUS selon les réglages que déclare chaque journal (qualité, mémoire vidéo, DXT ; table `ATLAS_ATTENDUS`) : nombre d'atlas, atlas [none], les 13 autres une fois par catégorie, atlas virtuel, seuil des [none] au plancher ; lignes horodatées du moteur seulement (E48, F80). `mut_atlas.py` : 40 cas (7 témoins, 21 mutants, 11 cas du garde-fou de `--out`, 1 contrôle final). Depuis le lot R1 (E55), `vram.py` COMPTE l'atlas virtuel du plancher (pages, mipmaps en borne haute ; plancher 0,28 à 0,53 Go) ; `mut_vram.py` : un témoin nul qui doit survivre, puis 18 mutants de `vram.py` que `unit_vram.py` doit tous refuser par un contrôle (copie de TOUS les modules de `tools/autotest`). Attendu au 22/10 : 5/5, 40 OK, « témoin nul survivant ; 18/18 mutants détectés » | La mémoire vidéo réelle (seulement en moteur réel, E40) ; les réglages jamais observés (refusés tant qu'aucun journal ne les étalonne) ; la résidence et le format des pages de l'atlas virtuel (hypothèses, F102) ; d'autres fautes de `vram.py` que les 18 mutants écrits |
| `tools/da/seuils.py`, `progression.py` (charte `docs/DA_FACTORIO.md`) | Un sprite tient les bandes mesurées sur 28 bâtiments vanilla (détail, patine, palette, lumière, masse) ; la puissance ne baisse pas d'une époque à la suivante (dominance) | Le style, la lisibilité, le « badass » : filtre de refus automatique seulement, le verdict reste au Directeur Créatif |

### Outillage du moteur réel

- `fo-autotest.bat` : benchmark épinglé sur les cœurs P (processeur hybride : F30) et priorité au-dessus
  de la normale ; étalon machine `[FO-CALIB]` (charge Lua fixe chronométrée toutes les 10 s) lu par
  `analyze.py`, qui signale les fenêtres où la machine ralentit.
- **Double source** (`fo-autotest.bat`, suite H-T3, 22/10 ; `tools/autotest/README.md` §1.1) : variable
  d'environnement facultative `FO_CREATE_SRC`. Si elle est définie, la copie de factorio-overhaul faite pour
  l'étape `--create` vient de ce chemin (par exemple une version ancienne exportée par `git archive`). À l'étape
  [2b/4], cette copie est effacée puis remplacée par la source habituelle (argument 4 ou `fo-autotest-params.txt`)
  avant le `--benchmark`. Le mod de test vient toujours de la source habituelle. `source.txt` donne la source du
  benchmark ; `create-source.txt` n'est écrit qu'en double source. Le banc s'arrête avec le code 1, sans
  `done.txt` ni benchmark, si la copie de création n'est pas effacée en entier ou si robocopy de la source du
  benchmark rend 8 ou plus. Sans la variable, ce bloc est sauté et le comportement est celui d'avant (vérifié par
  `tools/autotest/tests/bat_double_source/run.py`, 4 cas, et par le banc `content` standard, 238 OK). La
  propagation de la variable par `fo-captures.bat` a été essayée deux fois par le lot V3-T2 (22/10, 17 h 53 et
  18 h 53, `fo-captures.bat t2-migration`, code 0) : la carte du banc est créée par la source de création
  (`banc-create-source.txt` dans l'archive du premier essai ; pour le second, `factorio.log` montre `mod_changes`
  0.4.2 -> 0.4.3) et la session avec images rejoue la migration (E50).
- **Greffons** (`fo-autotest/greffons.lua`) : les contrôles greffés (`checks/`) ne sont chargés que pour le banc
  `content` ou un scénario greffé dont la base est `content`. Sinon, un mod de test récent ne se chargerait pas
  avec une source ancienne qui n'a pas les fichiers que les contrôles requièrent.
- `analyze.py <dossier> --spikes` : pics de script attribués aux traces `[FO-TRACE]` du même tick.
- Scénarios : `default`, `content` (banc de contenu : 317 contrôles avec les greffons depuis le lot V3-T2, 238 depuis le lot V3-T ; 180 à la session 5), scénarios greffés `t2-machines`, `t2-migration` et `ht3-migration` (lots V3-T2 et H-T3), `t2-defense` et `bord-a-bord` (lot R1), `t3-libere` et `t3-migration` (lot V3-T3), `monde`, `m0-reprise` et `m0-migration` (lot M0), `a1-tourelle` (lot A1, copie jetable seulement), `waves` (défense de tours + guerre),
  `pteam` (équipe du joueur + guerre), `baseline`, `stress`, `noexp`, `peace`, `parked`, `worker`.
- `shots.lua` : en session graphique (`fo-visual.bat`), captures automatiques des points d'intérêt dans
  `fo-visual\write\script-output\fo-shots\`, de jour et de nuit. Le mod de test coupe l'introduction
  du scénario « freeplay » (son message met le jeu en pause : F34). `global` étant propre à chaque mod, QG
  et avant-postes viennent de l'interface `points_of_interest` ; un point de biome n'est retenu que dans
  un chunk entièrement généré (F35), noté par la quantité de décor visible.
- Étape data : `harness.lua --dump-proto type/nom` (prototype vanilla) et `--dump-final type/nom`
  (prototype tel que le mod le livre : vérifier une couche ajoutée sans lancer le jeu).
- Hors-jeu : `tests/run.lua`, `tests/war_test.lua`, `tests/td_test.lua`, `tests/pteam_test.lua`,
  `tests/migration_test.lua`, `tests/monde_test.lua` (moteur simulé) ; `tests/datastage/harness.lua` (étape data + règles moteur) ;
  `tools/api_lint.py` (appels d'API contre la doc 1.1.91) ; outillage du banc : `tools/autotest/tests/run_d4m.py`,
  `mut_atlas.py`, `mut_vram.py`, `test_ht3_journal.py`, `bat_double_source/run.py` (attendus : CLAUDE.md §5).

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
