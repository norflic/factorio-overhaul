# Scénarios des 15 époques : design jouable (piste SCENARIOS, nuit du 29 au 30/10)

> **Statut : PROPOSITION**, à valider par le Directeur Créatif. Ce document ne remplace pas le scénario approuvé
> (`docs/SCENARIO_EPOQUES.md`, lot X0, Q19) : il le **rend jouable**. X0 dit *ce qui se passe* (prémisse, Codex,
> factions, contenu chiffré) ; ce document dit *ce que fait le joueur*, époque par époque, minute par minute, et
> **sur quels objets qui existent en jeu aujourd'hui** (`main` 0.6.18, 2e087bc).
> Le visuel reste dans `docs/DESIGN_EPOQUES.md` ; les chiffres dans `BALANCE_SHEET.md` et `shared/levels/config.lua`.

Sources lues : `docs/SCENARIO_EPOQUES.md` §1 (l. 74-253), `shared/content/epochs.lua` (époques, Codex, jalons,
fenêtres d'évolution), `shared/levels/config.lua` (monnaies, coûts du centre), `shared/content/world.lua` (biomes,
ressources garanties), recettes et technologies FINALES du mod (`harness.lua --dump-recipes/--dump-techs`, 29/10).

---

## 0. Glossaire (lève une ambiguïté des documents)

| Mot | Sens dans ce document |
|---|---|
| **Scénario** | le **récit jouable** d'une époque : objectif, déroulement, menaces, moment fort. Ce n'est PAS un « scénario » Factorio (`scenarios/`) ni l'enceinte ou l'espace dont parlent `QUESTIONS_DC.md:7` et `NUIT_PLAN.md:14` (« aucun fichier de scénario n'existe » : vrai au sens Factorio, la partie se joue en freeplay). |
| **Époque k** | le niveau k du centre de commandement (1 à 15). Le centre **est** l'époque (`L.epoch_of` : centre → n). |
| **Âge** | même chose qu'époque, vu des bâtiments : les niveaux 2k−1 et 2k d'une famille appartiennent à l'époque k. |
| **Monnaie de l'époque k** | `L.epoch_materials[k].item` : ce que l'on fabrique PENDANT l'époque k pour payer le centre k+1 (60 % de la valeur) et le centre k+2 (40 %). |
| **Codex k** | texte du récit (X0, §1.6) révélé à l'arrivée à l'époque k. X0 prévoit un OBJET Codex livré au centre ; en jeu, il est aujourd'hui un **message du journal** (§3). |
| **Jalon** | objectif facultatif d'une époque (X0 : 5 par époque, `X.milestone_kinds`). Ici : objectifs **affichés**, sans récompense (les récompenses changent l'équilibre : question au DC, §6). |
| **Journal d'époque** | la fenêtre en jeu livrée par cette piste (`/fo-journal`), §3. |
| **En jeu / prévu X0 / proposé** | colonne d'état de chaque élément : *en jeu* = prototype ou script présent dans `main` ; *prévu X0* = écrit dans le scénario approuvé, absent du jeu ; *proposé* = nouveau dans ce document, à valider. |

---

## 1. Principes communs

### 1.1 Rythme (calendrier X0, une seule source : `X.epoch_hours`)

Durée de l'époque k : 0,5 × k heure, plafonnée à 7 h. Heure nominale d'arrivée (`X.reach_hour`), coût du passage
du centre (`L.cost`, chiffres de `main` 0.6.18) :

| Époque | Arrivée | Durée | Passage du centre vers cette époque (coût exact en jeu) |
|---|---|---|---|
| 1 Pionnier | 0 h | 0,5 h | réparation de l'épave (`C.repair_cost`) |
| 2 Forge | 0,5 h | 1 h | fer 310, cuivre 160, briques 160, circuits 60 |
| 3 Vapeur | 1,5 h | 1,5 h | fer 360, cuivre 180, briques 180, circuits 70, **acier 80** |
| 4 Pétrole | 3 h | 2 h | fer 400, cuivre 210, briques 210, circuits 80, **moteurs 70**, acier 85 |
| 5 Volcan | 5 h | 2,5 h | fer 450, cuivre 230, briques 230, circuits 85, **plastique 1 200**, moteurs 270 |
| 6 Électricité | 7,5 h | 3 h | fer 500, cuivre 260, briques 260, circuits 95, **tungstène 910**, plastique 810 |
| 7 Cristal | 10,5 h | 3,5 h | fer 540, …, **batteries 410**, tungstène 620 |
| 8 Marais | 14 h | 4 h | fer 590, …, **cristal 1 260**, batteries 280 |
| 9 Atome | 18 h | 4,5 h | fer 640, …, **barils de méthane 380**, cristal 850 |
| 10 Haute techno | 22,5 h | 5 h | fer 680, …, **uranium 238 600**, méthane 560 |
| 11 Titane | 27,5 h | 5,5 h | fer 730, …, **processeurs 400**, uranium 238 1 440 |
| 12 Supraconducteurs | 33 h | 6 h | fer 780, …, **titane 1 550**, processeurs 280 |
| 13 Fusion | 39 h | 6,5 h | fer 820, …, **moteurs électriques 2 000** (provisoire), titane 1 070 |
| 14 Orbite | 45,5 h | 7 h | fer 870, …, **uranium 235 1 070** (provisoire), moteurs électriques 2 000 |
| 15 Légende | 52,5 h | 7 h | fer 910, …, **unités de contrôle de fusée 760** (provisoire), uranium 235 1 690 |

**Écart connu (Q-V2c-1, ouvert)** : ce calendrier est la cible ; le centre 15 s'atteint en jeu en 3 h 27 dans le
banc de rythme, car rien ne retient le joueur hors des monnaies. Ce document ne le corrige pas (cela change
l'équilibre) : il propose au §6 le levier X0 (Codex obligatoire) et un levier plus doux (jalons).

### 1.2 Gabarit d'une époque : trois temps

Chaque époque suit le même gabarit, pour que le joueur reconnaisse le rythme :

1. **Arrivée** (les 10 premières minutes) : le centre passe à l'époque k. Le **journal** s'ouvre : Codex k, objectifs,
   menace. Le plafond des bâtiments monte à 2k (`L.building_cap`). Le joueur améliore aussitôt ce qui protège
   (tourelles, murs) et ce qui produit la monnaie de l'époque précédente (déjà connue).
2. **Montée** (le gros de l'époque) : apprendre la **nouveauté** (ressource, énergie, chaîne), trouver le
   **gisement** de l'époque, monter la chaîne de la **monnaie k** ; la **menace** de l'époque frappe (biome,
   factions).
3. **Sortie** (la dernière demi-heure) : remplir le coffre du centre (monnaie k et monnaie k−1), passer le centre.
   C'est le « moment fort » de chaque fiche : une décision ou une attaque qui ne se joue qu'une fois.

### 1.3 Ce qui est en jeu aujourd'hui (constat, 29/10)

- **Récit en jeu avant cette piste** : un texte volant « Époque k : Nom ! » (`script/levels/levels.lua:1036`). Aucun
  Codex, aucune intro, aucun jalon, aucune victoire (`show_message_dialog`, `set_game_state` : 0 appel).
- **Livré par cette piste** (branche `amelio-scenarios`) : le **journal d'époque** (§3) : intro au départ (épave),
  Codex et objectifs à chaque passage du centre, `/fo-journal` pour relire. Aucun effet sur l'équilibre.
- **Absent** et prévu X0 : objets Codex, 14 bâtiments signature sur 15, packs de science du mod (8), fenêtre
  d'évolution bornée par l'époque (`X.evolution_window` : 0 appel dans `script/`), époques des factions, Serment,
  Porte, Marée du Cœur.
- **Ressources en jeu** : pétrole (vanilla), tungstène (5), cristal de résonance (7), méthane (8), ilménite et
  saumure (11), uranium (vanilla). **Absentes** : fumerolle (5), galène (9), veine de caustique (12), cheminée du
  manteau (13), impact de météorite (14), faille du Cœur (15).
- **Familles de déchiqueteurs en jeu** : blindés, ignés, de couvée, foudroyants (`fo-enemy.family-*`).

---

## 2. Prologue : l'épave (avant l'époque 1)

| Élément | État |
|---|---|
| Épave du centre posée près du premier joueur, inerte, 40 % de vie (`script/levels/centre.lua`) | en jeu |
| Réparation payée sur l'inventaire du joueur (bouton du panneau, touche U) | en jeu |
| **Texte d'introduction** (X0 `X.story.intro`) | **livré par cette piste** (journal) |
| Vaisseau couché 2 : 1 (art de l'épave) | prévu (sprites à valider par le DC) |

**Déroulement proposé (10 à 15 minutes).**
1. Le joueur se réveille à côté de l'épave. Le journal s'ouvre : *« L'Arche-5 s'est écrasée sur Érèbe… »* et un seul
   objectif : **réparer le noyau**. La liste exacte du coût (fer, cuivre, pierre) est dans le panneau de l'épave.
2. Il mine à la main, pose ses premières foreuses à combustible, fond ses premières plaques.
3. **Moment fort** : il répare. Le noyau se rallume (le centre redevient minable, ouvrable, pleine vie), le journal
   affiche le **Codex I** : *« Jour 1. L'Arche-5 est une épave ; son noyau tient encore… »*. L'époque 1 commence.

Pourquoi ce découpage : le Codex I parle du noyau qui « tient encore » ; il sonne juste au moment où le joueur le
remet en marche, pas avant.

---

## 3. Journal d'époque (livré par cette piste, en jeu)

- **Quand** : (a) au premier passage d'un joueur en personnage (après la cinématique de freeplay) : intro ;
  (b) chaque fois que le centre de sa force monte d'époque (réparation de l'épave comprise) : Codex et objectifs ;
  (c) à la demande : `/fo-journal` (époque actuelle) ou `/fo-journal k` (une époque déjà atteinte).
- **Quoi** : une fenêtre « Journal d'époque » : titre (époque, acte), texte du Codex, objectifs de l'époque **dérivés
  des données du jeu** (aucune liste de noms écrite à la main) :
  1. **Passer le centre à l'époque k+1** : coût exact (`L.cost`), avec ce que le centre contient déjà ;
  2. **Plafond des bâtiments** : niveau 2k (`L.building_cap`) ;
  3. **Gisement de l'époque** : la ressource de la fiche (X0) si son prototype existe en jeu, sinon rien ;
  4. **Cartographier** : la cible d'exploration X0 de l'époque (64 × k chunks aux époques qui en ont une) ;
  5. **Recherches** : 60 % des technologies classées à l'époque (annexe A), si elle en a ;
  6. **Défense** : détruire 2 + k nids pendant l'époque (jalon X0, compté par force, sans récompense) ;
  7. **Menace** : une ligne par époque (texte de ce document, FR et EN).
- **Multijoueur** : une fenêtre par joueur (pas de `show_message_dialog`, qui n'accepte qu'un joueur unique dans la
  partie) ; une ligne dans le chat pour toute la force.
- **Sauvegardes 0.6.18** : au premier chargement, le journal s'aligne sur l'époque actuelle de chaque force **sans
  rejouer** les annonces ni l'intro ; une ligne de chat signale `/fo-journal`.
- **Factions** : leurs forces n'ont pas de joueur ; le journal les ignore.

---

## 4. Les 15 fiches

Chaque fiche : **objectif du joueur** (une phrase), **nouveautés**, **ressources**, **déroulement** (arrivée, montée,
sortie), **objectifs du journal**, **menace** (déchiqueteurs et factions), **moment fort**, **Codex**. La colonne
« état » dit ce qui existe.

### Acte 1 : Survivre (époques 1 à 4)

#### Époque 1 : Pionnier (0 h, 30 min)
- **Objectif du joueur** : passer du travail à la main à une première ligne automatique, et tenir ses premiers nids
  à distance.
- **Nouveautés** : brûleurs, foreuses et bras à combustible, première tourelle (niveau 1-2). *En jeu (vanilla +
  familles à niveaux 1-2).*
- **Ressources** : fer, cuivre, charbon, pierre, bois. *En jeu.*
- **Déroulement**.
  - Arrivée : réparation de l'épave (prologue). Le centre est au niveau 1 : plafond des bâtiments 2.
  - Montée : 4 foreuses à combustible sur le fer, 2 sur le cuivre, fours en ligne ; premiers circuits ; science
    rouge.
  - Sortie : remplir le centre (fer 310, cuivre 160, briques 160, circuits 60).
- **Objectifs du journal** : centre 2 (coût ci-dessus) ; plafond 2 ; cartographier 64 chunks (X0).
- **Menace** : petits déchiqueteurs, délai de grâce des factions. *En jeu (vanilla + grâce IA0).*
- **Moment fort** : la première attaque de petits déchiqueteurs sur les foreuses, repoussée par 2 tourelles de
  niveau 2 que le joueur a améliorées lui-même.
- **Codex I** : « Jour 1. L'Arche-5 est une épave ; son noyau tient encore. Les gravimètres de bord affichent des
  anomalies que rien n'explique : la chute les aurait-elle faussés ? »

#### Époque 2 : Forge (0,5 h, 1 h)
- **Objectif** : faire de l'**acier** en quantité, monnaie de l'époque.
- **Nouveautés** : acier, science verte, murs et portes, armure lourde, modules 1 (18 technologies classées à
  l'époque 2, annexe A) ; bâtiments niveaux 3-4. **Coke** : prévu X0 ici, mais en jeu le four à coke (`fo-coke-oven`)
  n'est débloqué que par la recherche du titane (`fo-titanium-processing`, classée époque 10) : **écart**, §6.
- **Ressources** : charbon (coke), fer.
- **Déroulement**.
  - Arrivée : le journal annonce que les **quatre balises** du Convoi répondent : les factions existent.
  - Montée : une ligne fer → acier de 12 fours ; premiers murs de pierre et portes autour des foreuses.
  - Sortie : 80 acier dans le centre (plus le panier de base).
- **Objectifs du journal** : centre 3 (fer 360, cuivre 180, briques 180, circuits 70, **acier 80**) ; plafond 4 ;
  cartographier 128 chunks.
- **Menace** : premières **patrouilles des factions** (éclaireurs, IA2-c en jeu) ; déchiqueteurs moyens.
- **Moment fort** : la première patrouille d'une faction passe au bord de la base. Proposé : le journal nomme la
  faction (Ordre Écarlate, Ligue Azur, Consortium Émeraude, Dynastie Ambre) la première fois qu'une de ses unités
  est vue (non codé : `script/team` est tenu par un autre lot).
- **Codex II** : « Quatre balises répondent sur la fréquence du Convoi. Les autres équipages ont survécu, et ils
  s'arment. »

#### Époque 3 : Vapeur (1,5 h, 1 h 30)
- **Objectif** : l'**électricité à vapeur** et les **moteurs**.
- **Nouveautés** : moteurs, science militaire, automatisation 2, rails et trains, voitures, réseau de circuits
  (21 technologies classées à l'époque 3). Chaudières et machines à vapeur dès le départ (vanilla).
- **Ressources** : eau, charbon, fer, acier.
- **Déroulement**.
  - Arrivée : Codex III, le bilan thermique « ne ferme pas ».
  - Montée : centrale de 2 à 4 chaudières ; ligne de moteurs (engrenages + acier + tuyaux) ; recherche militaire.
  - Sortie : 70 moteurs (+ 85 acier) dans le centre.
- **Objectifs du journal** : centre 4 ; plafond 6 ; cartographier 192 chunks.
- **Menace** : **raids de déchiqueteurs plus gros** (la pollution de la centrale les attire).
- **Moment fort** : la centrale tombe en panne de charbon pendant un raid ; les mitrailleuses de niveau 6, elles, ne
  dépendent pas du courant et tiennent. Leçon : stock de charbon, et premier train de charbon.
- **Codex III** : « Le bilan thermique ne ferme pas : Érèbe rayonne plus de chaleur que son étoile ne lui en donne.
  Quelque chose chauffe la planète par en dessous. »

#### Époque 4 : Pétrole (3 h, 2 h)
- **Objectif** : le **plastique**, monnaie de l'époque (1 200 pour le centre 5 : la première grosse marche).
- **Nouveautés** : raffinerie, usine chimique, plastique, science bleue, lasers, robots, roquettes, béton : la plus
  grosse vague de l'acte 1 (47 technologies classées à l'époque 4).
- **Ressources** : **pétrole brut** (*en jeu*, gisement à trouver, souvent loin).
- **Déroulement**.
  - Arrivée : Codex IV : le pétrole est « jeune ». Objectif d'exploration : **trouver un gisement de pétrole**.
  - Montée : avant-poste pétrolier (premier site hors de la base, à défendre) ; raffinage de base ; plastique.
  - Sortie : 1 200 plastique + 270 moteurs.
- **Objectifs du journal** : centre 5 ; plafond 8 ; gisement : pétrole brut.
- **Menace** : **premières attaques organisées des factions** en Normal (IA0 : intervalle, part des forces). Les
  déchiqueteurs suivent les pipelines.
- **Moment fort** : la première attaque organisée d'une faction vise l'avant-poste pétrolier, pas la base : le
  joueur apprend que ses sites isolés sont des cibles.
- **Codex IV** : « Le pétrole d'Érèbe est jeune : il se forme encore, à quelques kilomètres sous nos pieds. Les
  géologues de l'Arche refusent d'y croire. »

### Acte 2 : La planète est étrange (époques 5 à 9)

#### Époque 5 : Volcan (5 h, 2 h 30)
- **Objectif** : le **tungstène**, minerai dur des **cendres volcaniques**.
- **Nouveautés** (*en jeu*, 4 technologies classées à l'époque 5) : minerai dur (catégorie `fo-hard-solid` : les
  foreuses à combustible ne le minent pas) ; plaque de tungstène (`fo-tungsten-processing`) ; **armes lourdes 1**
  (munitions au tungstène, mitrailleuse lourde, tourelle lourde, mur renforcé) ; **armes de siège** (canon, mortier,
  lance-grenades, obus au tungstène) ; char. Géothermie et fumerolles : *prévu X0, absent*.
- **Ressources** : tungstène (**garanti** sur toute carte, lot M0), cendres volcaniques (marche −10 %, véhicules
  freinés, *en jeu*). Fumerolle : *absente*.
- **Déroulement**.
  - Arrivée : Codex V. Le journal pointe le **gisement garanti** de tungstène.
  - Montée : expédition dans les cendres (foreuses électriques obligatoires : il faut tirer du courant jusque-là) ;
    plaques de tungstène.
  - Sortie : 910 tungstène + 810 plastique.
- **Objectifs du journal** : centre 6 ; plafond 10 ; gisement : tungstène.
- **Menace** : **blindés et ignés** dans les cendres (familles *en jeu*) ; ils résistent aux balles ordinaires : les
  munitions au tungstène sont la réponse (boucle voulue : la ressource de l'époque arme contre sa faune).
- **Moment fort** : premier contact avec un nid blindé ; les balles rebondissent. Le joueur rentre fabriquer ses
  premières munitions au tungstène, puis revient.
- **Codex V** : « Le flux géothermique est quarante fois trop fort. Le manteau est chauffé de l'intérieur, comme par
  un cœur. »

#### Époque 6 : Électricité (7,5 h, 3 h)
- **Objectif** : les **batteries** et un réseau électrique qui tient sous l'orage.
- **Nouveautés** (24 technologies classées à l'époque 6) : batteries, accumulateurs, haute tension, **tourelle
  laser**, panneaux solaires, modules de vitesse et de productivité, science de production. La tourelle Tesla et le
  fusil à arc (`fo-arc-and-acid`) viennent à l'époque 8 ; le four à arc avec le titane.
- **Ressources** : cuivre, acide sulfurique (soufre), fer.
- **Déroulement**.
  - Arrivée : Codex VI : les orages « suivent les anomalies ».
  - Montée : chaîne de batteries ; premiers accumulateurs ; tourelles laser sur les lignes.
  - Sortie : 410 batteries + 620 tungstène.
- **Objectifs du journal** : centre 7 ; plafond 12 ; cartographier 384 chunks.
- **Menace** : **foudroyants** attirés par les réseaux (famille *en jeu* ; l'attraction par le réseau : *prévu X0*).
- **Moment fort** : la première nuit d'orage, les foudroyants remontent une ligne électrique jusqu'à la base.
- **Codex VI** : « Les orages magnétiques ne suivent pas les vents : ils suivent les anomalies gravimétriques. Nos
  réseaux les attirent. »

#### Époque 7 : Cristal (10,5 h, 3 h 30)
- **Objectif** : récolter le **cristal de résonance** de la **plaine de cristal**.
- **Nouveautés** : cristal de résonance (combustible qui accélère les véhicules, *en jeu*) ; balises (transmission
  d'effet), tapis express, productivité minière 2 : seulement **3 technologies** classées à l'époque 7 (époque creuse
  en recherche, annexe A).
- **Ressources** : cristal de résonance (**garanti**, lot M0) ; plaine de cristal (marche +10 %, régénère les
  personnages : *en jeu*).
- **Déroulement**.
  - Arrivée : Codex VII : la **Ligue Azur** publie l'hypothèse de la Caustique. Première fois qu'une faction est
    NOMMÉE comme actrice du récit.
  - Montée : avant-poste dans la plaine (la plaine soigne : bonne base avancée) ; trains ou voitures au cristal.
  - Sortie : 1 260 cristaux + 280 batteries.
- **Objectifs du journal** : centre 8 ; plafond 14 ; gisement : cristal de résonance.
- **Menace** : **foudroyants renforcés** ; la Ligue Azur convoite la même plaine (proposé : ses avant-postes s'y
  posent, ce que l'IA fait déjà quand la valeur du site est haute, IA2-b).
- **Moment fort** : la course à la plaine de cristal contre la Ligue Azur.
- **Codex VII** : « Les cristaux chantent sans source. La Ligue Azur publie une hypothèse : Érèbe traverse une
  caustique de matière noire. »

#### Époque 8 : Marais (14 h, 4 h)
- **Objectif** : le **méthane** des marais, en barils.
- **Nouveautés** (*en jeu*, 4 technologies) : méthane, craquage du méthane, barils ; lance-flammes ; **arc et acide**
  (tourelle Tesla, pulvérisateur d'acide, fusil et cellule à arc) ; **armes lourdes 2** (balles explosives et
  incendiaires, tourelle laser lourde, mur blindé). Turbine à gaz, bioréacteur : *prévu X0*.
- **Ressources** : méthane (**garanti**, lot M0) ; marais toxique (marche −30 %, poison 2 dégâts/s, *en jeu*).
- **Déroulement**.
  - Arrivée : Codex VIII : « tout ici se nourrit de la même chaleur ».
  - Montée : pompes dans le marais (armure ou véhicule : le poison tue les imprudents) ; remplissage de barils.
  - Sortie : 380 barils de méthane + 850 cristaux.
- **Objectifs du journal** : centre 9 ; plafond 16 ; gisement : méthane.
- **Menace** : **couvées** (famille *en jeu*) : nids qui se multiplient vite dans le marais.
- **Moment fort** : nettoyer une couvée au lance-flammes chargé au méthane (+50 % de dégâts du jet, *en jeu*).
- **Codex VIII** : « La vie d'Érèbe respire le méthane qu'exhale un sous-sol chauffé. Tout ici se nourrit de la même
  chaleur. »

#### Époque 9 : Atome (18 h, 4 h 30)
- **Objectif** : l'**uranium 238** et la fission.
- **Nouveautés** (4 technologies) : traitement de l'uranium, énergie nucléaire, retraitement, munitions à l'uranium.
  Galène, piège à positons : *prévu X0, absent*.
- **Ressources** : uranium (vanilla, acide sulfurique requis). Galène : *absente*.
- **Déroulement**.
  - Arrivée : Codex IX : l'**Ordre Écarlate** voit une arme dans l'antimatière.
  - Montée : mine d'uranium (acide), centrifugeuses, premier réacteur.
  - Sortie : 600 uranium 238 + 560 barils de méthane.
- **Objectifs du journal** : centre 10 ; plafond 18 (la galène du jalon X0 n'existe pas : aucun gisement affiché ;
  l'uranium est vanilla, sur toute carte).
- **Menace** : l'**Ordre Écarlate** cherche l'arme absolue (proposé : il vise d'abord le réacteur, ce que la valeur
  militaire des cibles permet déjà) ; évolution des déchiqueteurs élevée.
- **Moment fort** : le premier réacteur démarre pendant une attaque de l'Ordre ; il faut le défendre avant qu'il ne
  chauffe trop sans eau.
- **Codex IX** : « Le cuivre irradié émet des positons : nous avons piégé notre premier grain d'antimatière. L'Ordre
  Écarlate y voit déjà une arme. »

### Acte 3 : Dompter les nouvelles physiques (époques 10 à 13)

#### Époque 10 : Haute technologie (22,5 h, 5 h)
- **Objectif** : les **processeurs** en série.
- **Nouveautés** : la plus grosse vague du jeu, **62 technologies** classées à l'époque 10 : processeurs, science
  jaune, robots logistiques, artillerie, Kovarex, modules 4-5, munitions à plasma (armes lourdes 3), **et déjà le
  titane** (`fo-titanium-processing`) et la voie humide du tungstène. Concentrés ρ8, cristal temporel : *prévu X0*.
- **Ressources** : aucune nouvelle (X0 : concentrés).
- **Déroulement**.
  - Arrivée : Codex X : la **Dynastie Ambre** voit l'éternité dans un cristal temporel.
  - Montée : usine de circuits avancés et de processeurs ; modules ; robots.
  - Sortie : 400 processeurs + 1 440 uranium 238.
- **Objectifs du journal** : centre 11 ; plafond 20 ; cartographier 640 chunks.
- **Menace** : exo-fantassins laser des factions (*prévu X0* ; aujourd'hui les unités vanilla de l'IA).
- **Moment fort** : la base passe aux robots de construction : le joueur reconstruit un mur détruit sans y aller.
- **Codex X** : « Un réseau de cristal gravé oscille sans énergie : un cristal temporel. La Dynastie Ambre y voit
  l'éternité. »

#### Époque 11 : Titane (27,5 h, 5 h 30)
- **Objectif** : la **plaque de titane** par la chaîne de Kroll, dans le **champ de cratères**.
- **Nouveautés** (*toutes en jeu*, lot X1, mais débloquées à l'époque 10 : **aucune** technologie classée à l'époque
  11) : concentrateur, électrolyseur, chloration, réacteur de Kroll, four à arc ; coke, saumure, chlore, hydrogène,
  soude, magnésium, tétrachlorure, éponge.
- **Ressources** : **ilménite** et **saumure** (**garanties**, champ de cratères, lot X1).
- **Déroulement**.
  - Arrivée : Codex XI : le **Consortium Émeraude** veut tout transmuter.
  - Montée : la chaîne la plus longue du jeu (9 machines) ; le chlore se recycle.
  - Sortie : 1 550 plaques de titane + 280 processeurs.
- **Objectifs du journal** : centre 12 ; plafond 22 ; gisement : ilménite.
- **Menace** : **nids de famille plus loin, plus gros** autour des cratères.
- **Moment fort** : la première plaque sort du four à arc après 9 machines : c'est la première fois que le joueur
  ferme une boucle de recyclage (chlore).
- **Codex XI** : « Les inclusions de la brèche sont bien trop denses : de la matière étrange, venue d'une météorite
  que quelque chose a attirée. Le Consortium Émeraude veut tout transmuter. »

#### Époque 12 : Supraconducteurs (33 h, 6 h)
- **Objectif** : la monnaie voulue (bobine supraconductrice) est **provisoire** : **moteur électrique** en jeu.
- **Nouveautés** : *prévu X0* : sels fondus, haloscope, accumulateur supraconducteur. En jeu : **canon électrique**
  (`fo-railgun`, seule technologie classée à l'époque 12) ; moteurs électriques et lubrifiant (débloqués plus tôt).
- **Ressources** : veine de caustique : *absente*.
- **Déroulement**.
  - Arrivée : Codex XII : la Caustique a une **marée**.
  - Montée : 2 000 moteurs électriques : grosse usine de lubrifiant.
  - Sortie : 2 000 moteurs électriques + 1 070 titane.
- **Objectifs du journal** : centre 13 ; plafond 24.
- **Menace** : les factions passent à l'époque 12 selon la difficulté (*prévu X0* ; non câblé).
- **Moment fort** (proposé, non codé) : la première **marée** : une vague de déchiqueteurs toutes les N minutes,
  annoncée au journal 2 minutes avant (le directeur de défense de tours sait déjà lancer une vague).
- **Codex XII** : « L'haloscope capte enfin le champ d'axions. La Caustique a une marée, et cette marée suit la
  rotation du noyau. »

#### Époque 13 : Fusion (39 h, 6 h 30)
- **Objectif** : monnaie **provisoire** : **uranium 235** (Kovarex) ; voulue : hélium-3.
- **Nouveautés** : *prévu X0* : fusion D-³He, **Serment** (choix de doctrine). En jeu : réacteur à fusion portatif,
  araignée (2 technologies) ; Kovarex depuis l'époque 10.
- **Déroulement**.
  - Arrivée : Codex XIII : « Il faut choisir sa doctrine : le Serment. »
  - Montée : Kovarex en série.
  - Sortie : 1 070 uranium 235 + 2 000 moteurs électriques.
- **Objectifs du journal** : centre 14 ; plafond 26.
- **Menace** : la rivale jurée attaque davantage (*prévu X0*, dépend du Serment).
- **Moment fort** : le **Serment** (X0 §1.4) : le seul choix irréversible de la partie. Proposé : un dialogue à 4
  boutons au journal, effet par `set_cease_fire` (gros, `shared/ai3` et `script/team` : hors de cette piste).
- **Codex XIII** : « Antimatière en quantité, strangelets en cuve : la Caustique ne tolère qu'une seule grande
  perturbation. Il faut choisir sa doctrine : le Serment. »

### Acte 4 : La vérité et la Porte (époques 14 et 15)

#### Époque 14 : Orbite (45,5 h, 7 h)
- **Objectif** : lancer une fusée ; monnaie **provisoire** : **unité de contrôle de fusée**.
- **Nouveautés** : silo, fusée, pack spatial, modules 6 à 10 (17 technologies). Rectenna, superalliage, météorites :
  *prévu X0*.
- **Déroulement**.
  - Arrivée : Codex XIV, **la révélation** : le Convoi venait ouvrir une Porte.
  - Montée : silo, pièces de fusée ; le premier lancement donne le pack spatial.
  - Sortie : 760 unités de contrôle + 1 690 uranium 235.
- **Objectifs du journal** : centre 15 ; plafond 28.
- **Menace** : pluies de météorites, course à la Porte des factions (*prévu X0*).
- **Moment fort** : le premier lancement ; le journal montre le Codex XIV comme une archive qui « parle enfin ».
- **Codex XIV** : « Les archives orbitales de l'Arche parlent enfin : le Convoi venait ancrer une Porte sur le trou
  noir du Cœur. Sans elle, personne ne rentre. »

#### Époque 15 : Légende (52,5 h, 7 h et au-delà)
- **Objectif** : bâtiments aux niveaux 29 et 30, puis la Porte (*prévu X0*).
- **Nouveautés** : niveaux 29-30 de toutes les familles (*en jeu*) ; **aucune** technologie. Porte, Clé de phase,
  Marée du Cœur : *prévu X0*.
- **Déroulement**.
  - Arrivée : Codex XV (**proposé** : X0 n'a pas de texte pour l'époque 15, le tableau §1.6 s'arrête au XIV).
  - Montée : tout monter au niveau 30.
  - Sortie : aujourd'hui, **aucune** (pas de Porte) : la partie continue en bac à sable.
- **Objectifs du journal** : plafond 30 ; aucun passage de centre (centre au maximum).
- **Menace** : Marée du Cœur (*prévu X0*).
- **Moment fort** : la Porte (§5).
- **Codex XV (proposé, FR)** : « Le Cœur s'éveille. Des failles s'ouvrent sur la plaine, gardées par des nids que
  personne n'a jamais vus. La Porte se construit ici, ou nulle part. »
- **Codex XV (proposé, EN)** : « The Core awakens. Rifts open across the plain, guarded by nests no one has ever seen.
  The Gate is built here, or nowhere. »

---

## 5. Fin de partie (rappel X0 et correction)

- La **Porte** (silo réhabillé 10 × 10, 100 segments, Clé de phase), la **charge de 30 min sous assaut** (Marée du
  Cœur : 12 vagues du directeur de défense de tours), la **victoire** par `set_game_state` : X0 §1.3, inchangé.
- **Correction (QX3, `OBJECTIFS.md:650`)** : la défaite par une faction qui ouvre sa Porte n'existe **qu'en
  Impitoyable**. `SCENARIO_EPOQUES.md` dit encore « Difficile et Impitoyable » (l. 159, 185, 203) : à corriger par
  l'intégrateur (§6).
- **Proposé** : tant que la Porte n'existe pas, le journal de l'époque 15 dit honnêtement « La Porte n'est pas encore
  construite dans cette version » (fait : objectif « Porte : à venir »).

---

## 6. Propositions (documents partagés et équilibre : à décider)

1. **`docs/SCENARIO_EPOQUES.md`** : QX3 (l. 159, 185, 203) « Difficile et Impitoyable » → « Impitoyable » ; tableau
   §1.6 : ajouter le Codex XV (texte ci-dessus) ou dire qu'il n'y en a pas.
2. **`shared/content/epochs.lua`** : ajouter `codex_fr`/`codex_en` à l'époque 15 (même texte) ; le journal le lit déjà
   s'il existe (il retombe sinon sur la clé de locale `codex-15`).
3. **Jalons de construction** (X0 : 14 bâtiments sur 15 absents) : les remplacer par des **bâtiments à niveaux en
   jeu** : « 4 bâtiments au niveau 2k−1 » (première silhouette de l'époque). Mesurable avec le recensement existant.
4. **Rythme (Q-V2c-1)** : deux leviers, au choix du DC :
   - X0 : le **Codex k** devient un objet fabriqué, exigé au passage du centre (recette par époque) : retient le
     joueur, mais change `config.lua` et l'équilibre ;
   - doux : les **jalons** donnent une récompense (caisse de 5 % du lot du centre, X0 `X.MILESTONE_CRATE_SHARE`) sans
     rien exiger.
5. **Recherche mal répartie (constat, annexe A)** : 62 technologies à l'époque 10, 47 à la 4, mais 0 aux époques 11
   et 15, 1 à la 12, 2 à la 13, 3 à la 7. Le joueur n'a presque rien à chercher pendant les 18 h des époques 11 à 13.
   Proposition : reclasser le titane (`fo-titanium-processing`, `fo-wet-tungsten`) à l'époque 11 ; étaler les
   modules 6-10 de 11 à 15 ; à trancher avec le lot X3 (graphe de fabrication).
6. **Coke** : X0 le place à l'époque 2 (Forge) ; en jeu, le four à coke n'existe qu'avec le titane (époque 10).
   Proposition : une technologie « Cokerie » à l'époque 2 (packs rouge et vert) qui débloque `fo-coke-oven` et
   `fo-coking` ; la recherche du titane garde le reste.
7. **`control.lua`** : une ligne `require("script.scenario.journal")` après `require("script.levels.panel")`
   (seul fichier partagé à toucher pour livrer le journal).

---

## Annexe A : technologies par époque (en jeu, 29/10)

Classement de la règle des niveaux (`L.vanilla_tech_epoch` : la plus haute époque des recettes débloquées, sinon
des packs), appliqué aux technologies FINALES du mod (`harness.lua --dump-techs`). C'est ce que lit l'objectif
« Recherches de l'époque » du journal (60 %, part X0).

| Époque | Nombre | Exemples |
|---|---|---|
| 1 | 7 | électronique, tourelle, logistique, militaire 1 |
| 2 | 18 | acier, science verte, murs, portes, modules, armure lourde |
| 3 | 21 | automatisation 2, moteur, rails, voitures, réseau de circuits, science militaire |
| 4 | 47 | pétrole, plastique, science bleue, lasers, robots, roquettes, béton |
| 5 | 4 | tungstène, armes lourdes 1, armes de siège, char |
| 6 | 24 | batteries, accumulateurs, tourelle laser, solaire, modules, science de production |
| 7 | 3 | transmission d'effet, logistique 3, productivité minière 2 |
| 8 | 4 | lance-flammes, arc et acide, armes lourdes 2, méthane |
| 9 | 4 | uranium, nucléaire, retraitement, munitions à l'uranium |
| 10 | 62 | processeurs, science jaune, robots logistiques, artillerie, Kovarex, titane, modules 4-5 |
| 11 | 0 | aucune |
| 12 | 1 | canon électrique |
| 13 | 2 | fusion portative, araignée |
| 14 | 17 | silo, pack spatial, modules 6-10 |
| 15 | 0 | aucune |

---

## 7. Rôle des factions par époque (résumé)

| Époque | Rôle des factions dans le récit | En jeu aujourd'hui |
|---|---|---|
| 1 | absentes (grâce) | grâce IA0 |
| 2 | les balises répondent : elles existent | patrouilles, éclaireurs (IA2-c) |
| 3 | elles s'arment | attaques selon la difficulté |
| 4 | premières attaques organisées (Normal) | attaques IA0, côtés choisis (IA2-a) |
| 7 | la Ligue Azur publie l'hypothèse de la Caustique | sites d'expansion par valeur (IA2-b) |
| 9 | l'Ordre Écarlate veut l'arme | — |
| 10 | la Dynastie Ambre veut l'éternité | — |
| 11 | le Consortium Émeraude veut transmuter | — |
| 12 | les factions passent à l'époque 12 | non câblé (époques des factions : X0) |
| 13 | Serment : alliée de doctrine, rivale jurée | non câblé |
| 14-15 | course à la Porte (Impitoyable) | non câblé |
