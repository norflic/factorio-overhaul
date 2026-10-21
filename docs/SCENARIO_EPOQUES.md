# SCENARIO_EPOQUES : la Caustique d'Érèbe (lot X0)

> **Rôle.** Scénario et conception complète des 15 époques et des branches avancées demandées par le
> Directeur Créatif (Q7) : ressources, bâtiments, arbres de fabrication, Compaction, énergie, niveaux,
> recherche, factions. Les lots X1 à X15, C, V2, I et IA0 s'en servent comme cahier de contenu.
>
> **Statut : PROPOSITION ❔.** Rien n'est implémenté en jeu. Rien n'est décidé sans le Directeur Créatif
> (questions au §9).
>
> **Source unique des chiffres : `shared/content/epochs.lua`** (Lua pur, mêmes noms internes). Les
> tableaux des §3.3, §3.4 et §3.1 sont **générés depuis ce fichier** : en cas d'écart, le fichier fait foi.
>
> **Vérifié hors jeu** par `lua5.2 tests/epochs_test.lua` (21/10, **12 312 OK, 0 échec**) :
> - le graphe complet compte 545 recettes : 259 recettes de base (vanilla 1.1.91 réelle, arsenal et modules
>   existants), 15 pseudo-recettes de base et 271 recettes nouvelles ;
> - **0 recette infranchissable** : tout objet, bâtiment compris, se fabrique depuis les ressources de la carte ;
> - **0 anachronisme** : l'époque calculée de chaque recette, objet et bâtiment égale son époque déclarée ;
> - règles de production, limites moteur 1.1.91, difficulté et déterminisme : détail au §6.
>
> **Non vérifié** : tout comportement en moteur réel, les débits réels, l'équilibrage fin (liste au §8).
>
> Rédigé le 21/10/2026 (session 6, lot X0). Base : la proposition gagnante « La Caustique d'Érèbe »,
> enrichie des greffes retenues par les deux juges. Les corrections apportées à la proposition sont au §7.

---

## Sommaire

0. [En une page](#0-en-une-page)
1. [Le scénario](#1-le-scénario)
   - 1.1 Prémisse · 1.2 Fil narratif des 15 époques · 1.3 Fin de partie · 1.4 Factions IA et difficulté · 1.5 Déchiqueteurs
2. [Les branches avancées (Q7)](#2-les-branches-avancées-q7)
   - 2.1 Vue d'ensemble · 2.2 Déblocage et Serment · 2.3 Matière noire · 2.4 Antimatière · 2.5 Chronodynamique ·
     2.6 Matière étrange · 2.7 Convergence : la matière exotique
3. [Contenu par époque](#3-contenu-par-époque)
   - 3.1 Calendrier · 3.2 Ressources et biomes · 3.3 Bâtiments · 3.4 Arbres de fabrication ·
     3.5 Contenu vanilla et existant · 3.6 Bilans chiffrés
4. [Liens avec la Compaction, l'énergie, les niveaux, la recherche et la boucle idle](#4-liens-avec-la-compaction-lénergie-les-niveaux-la-recherche-et-la-boucle-idle)
5. [Contraintes moteur 1.1.91 et volume](#5-contraintes-moteur-111-et-volume)
6. [Vérification hors jeu](#6-vérification-hors-jeu)
7. [Corrections apportées à la proposition gagnante, greffes intégrées](#7-corrections-apportées-à-la-proposition-gagnante-greffes-intégrées)
8. [Ce qui n'est pas vérifié](#8-ce-qui-nest-pas-vérifié)
9. [Ce qui reste à décider par le Directeur Créatif](#9-ce-qui-reste-à-décider-par-le-directeur-créatif)
10. [Pour l'intégrateur](#10-pour-lintégrateur)

---

## 0. En une page

- **La planète.** Érèbe orbite dans une **caustique de matière noire**. Un **trou noir primordial** capturé
  dans son noyau (« le Cœur ») focalise cette caustique et chauffe le manteau. Toutes les anomalies du jeu en
  découlent : volcan et tungstène, cristaux qui chantent, marais à méthane, matière étrange des cratères,
  faune agressive.
- **Les équipages.** Cinq vaisseaux-usines de la Compagnie (le « Convoi ») ont été dispersés à l'arrivée. Le
  joueur est l'ingénieur de l'Arche-5. Les quatre autres équipages sont les quatre factions IA, chacune avec
  sa **doctrine**.
- **Le but caché**, révélé à l'époque 14 : ancrer sur le Cœur une **Porte**, un trou de ver vers le système
  natal. **Victoire** : ouvrir la Porte d'Érèbe et la tenir 30 min, sous 5 GW, pendant la **Marée du Cœur**.
- **Quatre branches avancées** (Q7) : **A. Matière noire**, **B. Antimatière**, **C. Chronodynamique**,
  **D. Matière étrange**. Chacune a une mécanique propre (marée, confinement, dilatation, contagion) et trois
  niveaux répartis de l'époque 7 à l'époque 14. La matière exotique de l'époque 15 en est la convergence.
  - Niveaux I et II cumulables. Niveau III : le **Serment** (époque 13) ouvre une seule maîtrise à l'époque
    14, les trois autres à l'époque 15.
  - La Porte consomme un produit de niveau II de chaque branche : aucune branche n'est inutile.
- **Boucle « presque idle »** (greffe) : Codex et lot de monnaie pour passer le centre, 5 jalons par époque,
  médaille, score de puissance, sabliers et dilatation.
- **Rythme** : époque 1 en 30 min, époque 15 atteinte vers 52,5 h, Porte vers 59,5 h (F1-3).
- **Volume (compté par le banc)** : 121 objets, 19 fluides, 69 bâtiments, 11 ressources de carte, 5 tuiles,
  242 recettes réelles (156 de fabrication, 69 de bâtiments, 17 de torchère) et 29 pseudo-recettes
  (minage, combustion, lancement), 48 variantes denses pour le lot C. **Environ 800 prototypes de plus**
  (496 aujourd'hui), technologies comprises (§5.5).

---

## 1. Le scénario

### 1.1 Prémisse : trois faits physiques, cachés au début, expliquent tout le jeu

1. **Érèbe traverse une caustique de matière noire.**
   - Les courants de matière noire du halo galactique se replient en surfaces très denses (hypothèse réelle
     des « caustiques » de Sikivie). Érèbe orbite dans l'une d'elles.
   - Dans cet univers, cette matière noire est un **champ d'axions froid**, faiblement couplé aux réseaux
     cristallins et aux champs magnétiques intenses (ce que cherchent les vrais haloscopes, comme ADMX).
2. **Le noyau abrite un trou noir primordial**, « le Cœur ».
   - Il a la masse d'un astéroïde et il est plus petit qu'un atome (la capture d'un tel objet par une
     planète est une hypothèse publiée).
   - Il focalise la caustique. L'accrétion et l'annihilation de matière noire capturée chauffent le manteau.
3. **La planète est donc anormale** :
   - volcanisme 40 fois trop actif : cendres, tungstène, fumerolles riches en hélium primordial ;
   - cristaux de résonance qui « chantent » au passage du vent d'axions ;
   - biosphère qui vit du méthane : le marais ;
   - faune nourrie par la chaleur du Cœur : les déchiqueteurs ;
   - dans les cratères, les reliques d'une **météorite de matière étrange** que le trou noir a attirée.

**Le Convoi.** Cinq vaisseaux-usines de la Compagnie partent exploiter « l'anomalie Érèbe ». À l'entrée dans
la caustique, une onde de marée gravitationnelle les disperse. L'Arche-5 s'écrase (l'épave du scénario
« freeplay ») ; son noyau récupéré devient le **centre de commandement**. Les quatre autres équipages
survivent ailleurs et deviennent les quatre factions.

**Le secret** (Codex XIV, archives orbitales de l'Arche). Le Convoi était une expédition vers le Cœur, pour
y ancrer une **Porte**, un trou de ver traversable stabilisé par de la matière exotique à densité d'énergie
négative (modèle de Morris et Thorne, 1988), vers le système natal à 40 années-lumière. Sans la Porte,
personne ne rentre. Celui qui l'ouvre tient Érèbe.

### 1.2 Fil narratif des 15 époques (liste d'OBJECTIFS §6, validée par Q7)

La structure suit quatre actes : survivre (époques 1 à 4), la planète est étrange (5 à 9), dompter les
nouvelles physiques (10 à 13), la vérité et la Porte (14 et 15). Chaque époque se ferme par un **Codex**
(objet fabriqué, livré au centre avec le lot de monnaie) qui porte le récit.

| Ép. | Thème | Ce que l'on bâtit | Ce que l'on découvre (Codex de l'époque) | Pression |
|---|---|---|---|---|
| 1 | Pionnier | épave, atelier et laboratoire à combustion, centre | Sur la carte, des « anomalies gravimétriques » qu'aucun instrument ne lit : le mystère est posé dès la 1re heure | délai de grâce, petits déchiqueteurs |
| 2 | Forge | four à coke, haut fourneau, concasseur, murs | Les balises des quatre autres équipages : ils ont survécu | premières patrouilles des factions |
| 3 | Vapeur | électricité, marteau-pilon, assembleurs, laboratoires électriques | La planète rayonne plus de chaleur qu'elle n'en reçoit | raids plus gros |
| 4 | Pétrole | raffinerie, vapocraqueur, torchère, asphalte, **T2** | Le pétrole d'Érèbe est trop jeune : il se forme encore, chauffé d'en dessous | premières attaques organisées (Normal) |
| 5 | Volcan | capteur géothermique, four de frittage, foreuse lourde | Le flux géothermique est 40 fois trop fort | blindés et ignés (cendres) |
| 6 | Électricité | four à arc, bobineuse, pylônes HT, tour à arc, tourelle laser | Les orages magnétiques suivent les anomalies | foudroyants attirés par les réseaux |
| 7 | Cristal | taillerie, amplificateurs, station de charge, **T3** | Les cristaux chantent sans source. La Ligue Azur publie « l'hypothèse de la Caustique » (**A-I**) | foudroyants renforcés |
| 8 | Marais | reformeur, électrolyseur, bioréacteur, turbine à gaz | La vie d'Érèbe digère le méthane | couvées |
| 9 | Atome | plomb, fission, irradiateur, piscine d'entreposage | Le cuivre irradié émet des positons : premier piège d'antimatière ; l'Ordre Écarlate y voit une arme (**B-I**) | — |
| 10 | Haute technologie | salle blanche, concentrateur, radar à réseau phasé, **T4** | Un réseau de cristal gravé oscille sans énergie : premier cristal temporel ; la Dynastie Ambre y voit l'éternité (**C-I**) | exo-fantassins des factions |
| 11 | Titane | champs de cratères, procédé Kroll, résonateur temporel | Inclusions beaucoup trop denses dans la brèche : de la matière étrange ; le Consortium Émeraude veut la transmuter (**D-I**). Le temps se stabilise (**C-II**) | nids de famille plus gros |
| 12 | Supraconducteurs | cryogénie, aimants, sels fondus, haloscope | On capte enfin la matière noire (**A-II**) ; la Caustique a une marée | les factions passent à l'époque 12 selon la difficulté |
| 13 | Fusion | hélium-3, plasma, fusion, synchrotron, cuve de catalyse, **T5** | Antimatière en quantité, strangelets (**B-II, D-II**). **Le Serment** : le joueur choisit sa doctrine | la rivale jurée attaque davantage |
| 14 | Orbite | fusées, météorites, rectennas, maîtrises (**III**) | **Révélation** : la Porte, le trou noir primordial | pluies de météorites, course à la Porte des factions |
| 15 | Légende | failles du Cœur, matière exotique, **Porte** | Le Cœur s'éveille | **Marée du Cœur** |

### 1.3 Fin de partie
- **La Porte d'Érèbe** est un `rocket-silo` réhabillé de **10×10** (Q9 : « une usine de 10x10 »). Le silo
  offre nativement la progression par « pièces » et le lancement (`fixed_recipe`, `rocket_parts_required`,
  vérifiés ; « Recipe products are ignored » : le segment n'est qu'un compteur).
  - Ses 100 « pièces » sont des **segments d'anneau**. La « charge utile » est la **Clé de phase**.
- **Charge de 30 minutes sous assaut : la Marée du Cœur.**
  - La Porte demande **5 GW pendant la charge** (greffe P3) ; la charge est suspendue si l'alimentation
    manque. Il faut donc 3 réacteurs à annihilation, ou l'équivalent.
  - Le directeur de la défense de tours existant (`script/td/director.lua`) lance 12 vagues jusqu'aux
    primordiaux, un boss toutes les 3 vagues. En Difficile et en Impitoyable, les factions convergent aussi.
  - Si la Porte tient : **victoire** (`LuaGameScript.set_game_state`, vérifié). La victoire vanilla au
    satellite est coupée : `remote.call("silo_script", "set_no_victory", true)` (vérifié,
    `data/core/lualib/silo-script.lua`, l. 57). On peut continuer à jouer.
  - Si elle tombe : la Clé est perdue, les segments restent.
- **Après la victoire, mode « Légende »** : recherches infinies au pack exotique, merveilles des autres
  doctrines, niveaux 29 et 30, score de puissance.
- **Défaite ❔ (QX3)** : en Difficile et en Impitoyable, une faction qui ouvre sa propre Porte avant vous gagne.

### 1.4 Factions IA et difficulté (Q4 : « oui (et différents niveaux de difficulté) »)

| Faction (personnalité existante) | Doctrine | Pourquoi | Élite (époque 13 et après) | Rivale jurée |
|---|---|---|---|---|
| Ordre Écarlate (conquérant) | **B. Antimatière** | l'arme absolue | Lancier d'annihilation | Dynastie Ambre |
| Ligue Azur (technocrate) | **A. Matière noire** | comprendre la Caustique | Arpenteur gravitique | Consortium Émeraude |
| Consortium Émeraude (bâtisseur) | **D. Matière étrange** | tout transmuter, tout posséder | Colosse étrange | Ligue Azur |
| Dynastie Ambre (équilibrée) | **C. Chronodynamique** | une dynastie veut l'éternité | Spectre chronique | Ordre Écarlate |

- **Le Serment** (époque 13) change les relations : la faction de même doctrine dirige contre vous 0,5 fois
  sa part de forces (cessez-le-feu possible) ; sa rivale jurée 1,5 fois. Faisable : `LuaForce.set_cease_fire`
  et `set_friend` existent (vérifié).
- **Table de difficulté** (greffe P3 fusionnée avec l'axe « écart d'époque » ; chiffres proposés au lot IA0 ❔,
  données `X.difficulty`) :

| Difficulté | Grâce | Attaque contre vous | Taille | Part des forces contre vous | Évolution | Écart d'époque | Course à la Porte | Crédit d'archive |
|---|---|---|---|---|---|---|---|---|
| Paisible | infinie (cessez-le-feu actuel) | aucune | — | 0 % | −0,05 | — | non | ×0,5 |
| Facile | jusqu'à votre époque 4 | toutes les 30 min | ×0,75 | 15 % | −0,05 | −2 | non | ×0,5 |
| Normal | jusqu'à votre époque 3 | toutes les 20 min | ×1 | 30 % | 0 | −1 | non | ×1 |
| Difficile | jusqu'à votre époque 2 | toutes les 12 min | ×1,4 | 45 % | +0,03 | 0 | oui, chantier de 4 h | ×1,5 |
| Impitoyable | 15 min | toutes les 8 min | ×2 | 60 % | +0,06 | +1 (plafond 15) | oui, chantier de 2 h 30 | ×2,5 |

- **Chantier de Porte d'une faction** (Difficile, Impitoyable) : visible sur la carte ; le détruire rend 30 %
  des matériaux investis (raid façon Clash of Clans).
- **Époques des IA : économie d'archive hybride** (greffe, à la place des dotations pures).
  - Honnêteté (C2-6) : le cerveau d'équipe réel stagne aujourd'hui à la recherche 3 (H-E1, pas de pétrole).
    Lui faire jouer les chaînes des époques 4 à 15 est hors de portée raisonnable.
  - Donc : le **minage réel** des avant-postes (plaques livrées au QG, déjà mesurées) fait progresser
    l'époque de la faction par une fonction pure (`X.faction_epoch`) : crédit = MU livrées × crédit de
    difficulté ; seuil de l'époque k = 300 MU × 1,6^(k−2), cumulé (300 MU pour l'époque 2, 33 860 pour
    l'époque 10, 359 788 pour l'époque 15) ; l'époque est plafonnée par la vôtre plus l'écart d'époque.
  - À chaque époque gagnée, la faction reçoit l'**équipement de l'époque** (unités du tableau ci-dessous) :
    c'est encore une imitation pour ce qui dépasse l'époque 4 ; à écrire tel quel dans OBJECTIFS C2.
  - Unités d'époque (`X.faction_units`, prototypes `unit`, agents de masse) : fusilier, mitrailleur et
    grenadier (existants), lance-flammes (époque 8), exo-fantassin laser (10), mécha léger (13), plus les 4
    élites de doctrine.

### 1.5 Les déchiqueteurs : la faune du Cœur
- La faune est nourrie par la chaleur du Cœur. Familles existantes liées à un biome et à une époque :
  blindés et ignés (cendres, époque 5), couvées (marais, 8), foudroyants (champs électriques, 6 et 7).
- **Fenêtre d'évolution bornée par votre époque** (greffe P3, `X.evolution_window`) : une fois par minute,
  le script ramène `LuaForce.evolution_factor` (écriture vérifiée) dans la fenêtre de votre époque, décalée
  selon la difficulté : de 0 à 0,10 à l'époque 1 jusqu'à 0,85 à 1,00 à l'époque 15. C'est l'équivalent de
  l'appariement par hôtel de ville de Clash of Clans. La même borne plafonne le palier des vagues de la
  défense de tours (`X.td_max_tier` : palier 2 aux époques 1-2, … primordiaux à l'époque 13).
- **Perturbation** (`X.perturbation`) : les productions exotiques poussent l'évolution vers le haut de la
  fenêtre, sans jamais la dépasser : +0,00005 par condensat d'axions, piège d'antihydrogène ou strangelet ;
  +0,0002 par matière exotique stabilisée.
- **Pollution native** : les bâtiments exotiques polluent fortement et attirent donc les attaques.
- **Butin** (greffe, `EntityWithHealthPrototype.loot`, vérifié) : un **tissu de déchiqueteur**, de 2 %
  (petit) à 8 % (primordial) par unité, 5 à 20 par nid. Il sert d'inoculum à l'époque 8 (à côté de
  l'échantillon de vase) et de **méthane de digesteur** : la défense devient productive.
- **Gardiens** : à l'époque 15, des nids **primordiaux** entourent les failles du Cœur.

---

## 2. Les branches avancées (Q7)

### 2.1 Vue d'ensemble

| | A. Matière noire | B. Antimatière | C. Chronodynamique | D. Matière étrange |
|---|---|---|---|---|
| Doctrine de | Ligue Azur | Ordre Écarlate | Dynastie Ambre | Consortium Émeraude |
| Appui scientifique réel | caustiques (Sikivie), haloscopes à axions (ADMX) | cuivre 64 émetteur β+, pièges de Penning, antihydrogène (CERN) | cristaux temporels sur processeur quantique (2021-2022) | hypothèse de la matière étrange (Witten, 1984) |
| I. Découverte | ép. 7 : résonateur de caustique | ép. 9 : positons du cuivre activé | ép. 10 : cristal temporel instable | ép. 11 : inclusions de la brèche d'impact |
| II. Exploitation | ép. 12 : haloscope, condensat d'axions | ép. 13 : synchrotron, antihydrogène | **ép. 11** : cristal stable, dilatation (ép. 12 : variante à l'hélium liquide) | ép. 13 : strangelets, transmutation |
| III. Maîtrise | ép. 14 si Serment, sinon 15 | idem | idem | idem |
| **Mécanique propre** | **marée** : rendement de 50 à 150 % sur le jour | **confinement** : 5 s sans courant et les pièges explosent | **dilatation** : accélère les voisins (branche « idle ») | **croissance autocatalytique et contagion** |
| Ce qu'elle rapporte | minage infini n'importe où, concentrés ρ8 | 2 GW par réacteur, armes, sondes | vitesse, chantiers et recherche accélérés, coffres intriqués, 6e ouvrier | minerais rares, puits des déchets, murs et armure |
| Coût, risque | hélium liquide, pollution | 150 MW par synchrotron, explosions | hélium liquide ou oscillateurs (branche sûre) | plasma, sol contaminé |
| Donnée de recherche | relevé gravimétrique | données d'annihilation | données chronométriques | données hadroniques |

### 2.2 Déblocage, Serment, cumul
- **Verrou d'époque natif** (greffe P3) : une technologie cachée `fo-epoch-k` (`enabled = false`) passe en
  `researched = true` (écriture vérifiée) quand le centre atteint le niveau k ; elle est prérequis de toutes
  les technologies de l'époque k. Cela évite de basculer `enabled` sur environ 340 technologies.
- **Niveaux I et II : cumulables.** Le niveau I se débloque par une technologie de branche payée avec le pack
  de l'époque ; le niveau II se paie avec la donnée de la branche (fenêtre de packs, §4.4).
- **Niveau III : le Serment** (centre au niveau 13). Choix **irréversible** d'une doctrine. Ses maîtrises
  s'ouvrent à l'époque 14 ; les trois autres à l'époque 15 (`LuaTechnology.enabled`, écriture vérifiée,
  réservé à cet usage). Récit : la Caustique ne supporte qu'une seule « grande perturbation » tant que le
  Cœur n'est pas ancré.
- **La Porte exige les quatre branches au niveau II** : chaque segment d'anneau consomme 1 condensat
  d'axions (A), 1 piège d'antihydrogène (B), 1 cristal temporel stable (C) et 2 plaques étranges (D). Le
  choix porte sur l'**ordre** et la **maîtrise précoce**, jamais sur l'abandon d'une branche.
- **Une branche ne bloque jamais la ligne principale des époques 1 à 14** (contrôlé par le banc : aucune
  recette hors branche d'époque ≤ 14 ne consomme un objet de branche).

### 2.3 A. Matière noire (gravitique)
- **Récit.** À l'époque 7, les cristaux taillés vibrent sans source près des anomalies gravimétriques. À
  l'époque 12, l'haloscope (cavité supraconductrice dans un champ intense, refroidie à l'hélium liquide)
  capte le champ d'axions des **veines de caustique**. Dans une **cavité de résonance**, le champ se condense.
- **Veines** (greffe juge 2) : posées par le script à l'événement `on_sector_scanned` (vérifié) : radar
  vanilla dès l'époque 3, radar à réseau phasé (portée ×3) à l'époque 10 ; hachage déterministe de la graine
  et du chunk, une veine garantie pour 20 à 25 chunks. Deux veines visibles près du départ dès l'époque 1 :
  « visibles mais illisibles » (catégorie `fo-caustic`, que seul l'haloscope mine).
- **Production.** Haloscope (5×5, 20 MW) : 20 flux sombre/s à marée moyenne. 2 condenseurs gravitiques : 0,1
  condensat/s. Les cavités sont **réutilisables** (résidu de combustion du condensat, ou relevé).
- **Mécanique : la marée.** Veines infinies dont le rendement vaut `amount / normal`. Toutes les 600 ticks,
  le script réécrit `amount` (écriture vérifiée) d'après une **table de 24 phases** sans trigonométrie
  (`X.tide`) : 0,5 à midi, 1,5 à minuit, linéaire, moyenne 1. Il faut des réservoirs ou surconstruire.
- **Ce qu'elle rapporte.**
  - **Puits gravitique** (II, 5×5) : se pose n'importe où ; le script crée dessous une « remontée profonde »
    infinie du minerai choisi. Il brûle 1 condensat par minute (2 MW, 120 MJ par condensat, la cavité est
    rendue) et sort **1 concentré ρ8/s, soit 8 MU/s**. C'est la réponse au « jouer en continu » (F1) : les
    gisements ne s'épuisent plus. Un haloscope fait tourner 6 puits.
  - **Puits gravitique II** (III) : 4 concentrés ρ8/s (32 MU/s), minerais rares compris (tungstène,
    ilménite, monazite).
  - **Bouclier de marée** (III) : −70 % de vitesse aux ennemis dans un rayon de 30.
  - **Observatoire de la Caustique** (merveille) : +20 % de productivité minière
    (`mining_drill_productivity_bonus`, écriture vérifiée) et marée bloquée à 150 %.

### 2.4 B. Antimatière (annihilation)
- **Récit.** À l'époque 9, du cuivre exposé au flux de neutrons d'un réacteur (cuivre 64, émetteur β+ réel)
  fournit des positons, pris dans des **pièges magnétiques**. À l'époque 13, un synchrotron alimenté par la
  fusion produit des antiprotons, recombinés en **antihydrogène**.
- **Note de physique honnête.** Dans notre univers, l'antimatière ne serait qu'un stockage. Sur Érèbe, le
  champ d'axions abaisse le seuil de création de paires : c'est la seule raison du rendement positif, et
  cela relie B à A. C'est une **fiction déclarée** (liste blanche d'énergie du banc ; variante au §9, QX4).
- **Production** : un parc de pièges qui circulent (vide → plein → vide), comme des bouteilles consignées.
- **Mécanique : le confinement.** Un bâtiment qui contient des pièges pleins (modérateur, synchrotron,
  recombineur, réacteur à annihilation) doit rester alimenté. 5 s sans énergie : ses pièges s'annihilent
  (2 000 dégâts par piège, rayon 8). Script : liste de ces bâtiments, contrôle toutes les 60 ticks. La
  destruction d'un réacteur chaud passe par le `meltdown_action` natif (vérifié dans la doc : déclenché à la
  mort au-delà de 90 % de la température maximale).
- **Chiffres.** Synchrotron : 1 piège à antiprotons toutes les 30 s pour 150 MW. Piège d'antihydrogène :
  50 GJ. Le **réacteur à annihilation** (III, **10×10**, 2 GW de chaleur) en brûle 1 toutes les 25 s. Il lui
  faut 1,2 synchrotron, 0,4 recombineur, 2,4 modérateurs et 1,2 irradiateur : **≈ 1,8 GW nets**.
- **Ce qu'elle rapporte.** Énergie de fin de partie ; **fusion catalysée** (greffe : 2 pastilles + 2 pièges
  d'antihydrogène → 2 pastilles de rendement doublé) ; **obus d'annihilation** ; **lance d'annihilation**
  (III, 20 000 dégâts, portée 60) ; **sonde profonde** (III, lancée par fusée : 50 météorites étranges et 50
  iridium).

### 2.5 C. Chronodynamique (cristaux temporels)
- **Récit.** À l'époque 10, un réseau de cristal gravé sur silicium, en salle blanche, oscille sans énergie :
  un cristal temporel instable. À l'époque 11, verrouillé en phase par des oscillateurs, il se stabilise ; à
  l'époque 12, l'hélium liquide double la cadence. Dans cet univers, il peut « prêter » du temps.
- **Production : une boucle de phase.** Instable → stable. Le cristal se déphase en travaillant : la chambre
  rend un cristal instable toutes les 300 s ; il faut le restabiliser.
- **Mécanique : la dilatation.** C'est la **branche « presque idle »** (E3).
  - **Chambre de dilatation** (II) : +100 % de vitesse aux machines à moins de 3 tuiles, tant qu'elle
    travaille ; chambre II (III) : +200 %. Technique : une balise cachée créée ou retirée par le script selon
    `status`, car `LuaEntity.speed_bonus` est en lecture seule (vérifié).
  - **Sablier quantique** (II), consommable : appliqué à un chantier du centre, il retire 25 % de la durée
    initiale, au moins 10 min. L'équivalent du « livre » de Clash of Clans.
  - **Coffres intriqués** (II, greffe ; `LinkedContainerPrototype` et `link_id`, vérifiés) : fabriqués par
    paire. Le tapis intriqué est **écarté** (juge 2 : il rendrait inutiles les trains de l'époque 12).
  - **Horloge éternelle** (merveille III) : 6e ouvrier, chantiers −25 %, laboratoires +50 %
    (`laboratory_speed_modifier`, écriture vérifiée).
- **Risque** : aucun. Branche sûre, au coût permanent (oscillateurs ou hélium).

### 2.6 D. Matière étrange
- **Récit.** À l'époque 11, la brèche d'impact des cratères livre de rares **inclusions étranges** (0,5 %),
  reliques d'une météorite de matière étrange. À l'époque 13, comprimée dans du plasma, une inclusion
  « germe » en strangelet confiné. Selon Witten, la matière étrange serait l'état le plus stable de la
  matière : un strangelet convertit la matière ordinaire qu'il touche.
- **Production : croissance autocatalytique.** 2 strangelets + 10 pierres + 10 sables → 3 strangelets
  (30 s, catalyseur 2).
- **Puits universel des déchets** (greffe P2) : « Croissance étrange : conversion de X » : 1 strangelet +
  32 X → 2 strangelets (catalyseur 1), pour X = laitier, sable, pierre, colis vitrifiés, sel usé. Les
  sous-produits accumulés depuis l'époque 2 deviennent une mine.
- **Mécanique : la contagion.** Une cuve dont la sortie reste pleine plus de 60 s déborde : le script
  convertit les tuiles voisines en **sol étrange** (rayon +1 par minute, 12 au plus) et inflige 50 dégâts/s
  aux bâtiments qui s'y trouvent, jusqu'à ce que la cuve soit vidée.
- **Ce qu'elle rapporte.** **Transmutation** : 40 pierres → 20 minerais rares en 20 s (tungstène, ilménite,
  monazite, uranium ou cristal), le strangelet servant de catalyseur ; **plaque étrange** ; **mur étrange**
  (12 000 PV) ; **mur de neutronium** (III, 50 000 PV) ; **armure étrange** (III) ; **Monolithe étrange**
  (merveille : transmutation ×2).

### 2.7 Convergence : la matière exotique (époque 15)
- Le Cœur s'éveille : le script crée 3 à 5 **failles du Cœur** (ressources fluides infinies), à des positions
  déterministes tirées de la graine, entre 600 et 1 200 tuiles du départ, gardées par des primordiaux.
- L'**ancre de faille** (qui consomme les quatre branches au niveau II) y capte la **matière exotique brute**
  en injectant du plasma. Le **stabilisateur de Casimir** la fixe dans des cavités à miroirs d'iridium (effet
  Casimir : énergie du vide négative entre deux miroirs), la cavité servant de catalyseur.
- La matière exotique stabilisée nourrit la Porte, la Clé de phase et le pack exotique.

---

## 3. Contenu par époque

### 3.1 Calendrier (F1-3 ; généré par `X.epoch_hours`, `X.rate`, `X.budget`, `X.pack_window`)

- Durée de l'époque k : 0,5 h × k, plafonnée à 7 h (greffe P2) : **59,5 h** pour les 15 époques.
- Débit visé de l'usine : géométrique de 3 MU/s à 14 000 MU/s (×1,83 par époque). Budget = débit × durée.
- **Passage du centre** de k à k+1 (gabarit P3) : un **Codex k** plus un lot de monnaie d'époque de 10 % du
  budget de l'époque. V2 convertit ces MU en objets pour `L.tier_costs` (niveaux 2k−1 et 2k).
- Fenêtre de packs : une technologie de l'époque k consomme les packs k, k−1 et k−2 (plus le pack militaire
  pour le combat) ; une technologie de branche consomme sa donnée et le pack de l'époque.

| Ép. | Durée | Cumul | Palier | Ouvriers | Niveau max | Débit visé (MU/s) | Budget (MU) | Passage du centre (MU) | Fenêtre de packs | Monnaies de niveau |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 Pionnier | 0,5 h | 0,5 h | T1 | 1 | 2 | 3 | 5.4e+03 | 540 | Pack d'automatisation | Plaque de fer, Plaque de cuivre, Brique de pierre, Circuit électronique |
| 2 Forge | 1 h | 1,5 h | T1 | 1 | 4 | 5 | 1.97e+04 | 1.97e+03 | Pack logistique, Pack d'automatisation | Plaque d'acier, Ciment |
| 3 Vapeur | 1,5 h | 3 h | T1 | 1 | 6 | 10 | 5.42e+04 | 5.42e+03 | Pack militaire, Pack logistique, Pack d'automatisation | Manomètre, Béton |
| 4 Pétrole | 2 h | 5 h | T2 | 2 | 8 | 18 | 1.32e+05 | 1.32e+04 | Pack chimique, Pack militaire, Pack logistique | Plastique, Circuit avancé |
| 5 Volcan | 2,5 h | 7,5 h | T2 | 2 | 10 | 34 | 3.02e+05 | 3.02e+04 | Pack géologique, Pack chimique, Pack militaire | Plaque de tungstène, Carbure de tungstène |
| 6 Électricité | 3 h | 10,5 h | T2 | 2 | 12 | 61 | 6.62e+05 | 6.62e+04 | Pack de production, Pack géologique, Pack chimique | Bobine, Batterie |
| 7 Cristal | 3,5 h | 14 h | T3 | 3 | 14 | 112 | 1.41e+06 | 1.41e+05 | Pack de résonance, Pack de production, Pack géologique | Lentille de résonance, Oscillateur à cristal |
| 8 Marais | 4 h | 18 h | T3 | 3 | 16 | 205 | 2.95e+06 | 2.95e+05 | Pack biochimique, Pack de résonance, Pack de production | Biopolymère, Culture méthanotrophe |
| 9 Atome | 4,5 h | 22,5 h | T3 | 3 | 18 | 375 | 6.07e+06 | 6.07e+05 | Pack isotopique, Pack biochimique, Pack de résonance | Blindage plombé, Cellule d'uranium |
| 10 Haute technologie | 5 h | 27,5 h | T4 | 4 | 20 | 685 | 1.23e+07 | 1.23e+06 | Pack utilitaire, Pack isotopique, Pack biochimique | Processeur, Tranche de silicium |
| 11 Titane | 5,5 h | 33 h | T4 | 4 | 22 | 1253 | 2.48e+07 | 2.48e+06 | Pack structurel, Pack utilitaire, Pack isotopique | Plaque de titane ρ8, Composite titane |
| 12 Supraconducteurs | 6 h | 39 h | T4 | 4 | 24 | 2290 | 4.95e+07 | 4.95e+06 | Pack magnétique, Pack structurel, Pack utilitaire | Bobine supraconductrice, Aimant permanent |
| 13 Fusion | 6,5 h | 45,5 h | T5 | 5 | 26 | 4188 | 9.8e+07 | 9.8e+06 | Pack plasma, Pack magnétique, Pack structurel | Pastille de fusion, Cellule de plasma |
| 14 Orbite | 7 h | 52,5 h | T5 | 5 | 28 | 7657 | 1.93e+08 | 1.93e+07 | Pack espace, Pack plasma, Pack magnétique | Superalliage ρ32, Miroir d'iridium |
| 15 Légende | 7 h | 59,5 h | T5 | 5 | 30 | 14000 | 3.53e+08 | — | Pack exotique, Pack espace, Pack plasma | Matière exotique stabilisée |

**Gabarit d'époque façon Clash of Clans** (greffe P3, `X.epochs[k].milestones`) : 5 jalons par époque.
- **Production** : un volume de la matière signature (par exemple 1 000 plaques de fer à l'époque 1).
- **Construction** : poser le bâtiment signature (par exemple 4 ateliers à combustion).
- **Recherche** : 60 % des technologies de l'époque.
- **Défense** : détruire 2 + k nids.
- **Exploration** : cartographier 64 × k chunks, ou trouver la ressource de l'époque.
- Récompense de chaque jalon : une caisse versée au centre (5 % du lot de passage) et 5 × k minutes de
  crédit d'accélération stockés par force (sans objet). Les 5 jalons donnent une **médaille** au choix :
  +2 % de productivité minière, +5 % de recherche ou +5 % de fabrication manuelle (attributs de force en
  écriture, vérifiés).
- **Score de puissance** : Σ(niveau × poids de la famille) + 500 × époque + 2 000 × merveille + 50 × jalon.

### 3.2 Ressources nouvelles et biomes

| Ressource | Époque | Où | Extraction | Notes |
|---|---|---|---|---|
| Tungstène (existant) | 5 | cendres volcaniques | foreuse électrique ou lourde | minerai dur |
| **Fumerolle → gaz volcanique** | 5 (hélium dès 12) | cendres volcaniques | capteur géothermique | infinie (minimum 20 %), 200 gaz/s à 100 % |
| Cristal de résonance (existant) | 7 | plaine de cristal | toute foreuse, ou à la main | — |
| Méthane (existant) | 8 | marais | chevalet de pompage | — |
| Échantillon de vase | 8 | arbres et troncs des marais | abattage | 30 % par arbre |
| Tissu de déchiqueteur | 1 (utile dès 8) | butin des déchiqueteurs | combat | 2 à 8 % par unité, 5 à 20 par nid |
| **Galène** | 9 | gisements classiques à plus de 300 tuiles | toute foreuse | → plomb et soufre |
| Uranium (vanilla) | 9 | vanilla | foreuse électrique et acide | — |
| **Ilménite** | 11 | **champs de cratères** (nouveau biome) | foreuse électrique ou lourde, puis concentrateur | née dense (concentré ρ8) |
| **Saumure** | 11 | lacs salés des cratères | chevalet de pompage | infinie |
| **Brèche d'impact** | 11 | remparts des cratères | foreuse électrique ou lourde | pierre, et 0,5 % d'inclusions étranges |
| **Monazite** | 12 | **sables noirs** (rivages) | foreuse électrique ou lourde, puis concentrateur | terres rares et thorium |
| Air | 12 | partout | unité cryogénique (recette sans ingrédient) | azote et oxygène liquides |
| **Veine de caustique** | visible dès 1, exploitable à 12 | posée au balayage radar | haloscope | infinie, soumise à la marée |
| **Remontée profonde** | 12 (A-II) | sous un puits gravitique (script) | puits gravitique | infinie |
| **Évent mantellique** (greffe P2) | 13 | cœur des cendres volcaniques, rare | foreuse profonde | hélium-3, infini (minimum 10 %) |
| Eau lourde, deutérium | 13 | toute eau | colonne isotopique | 1 000 eaux → 10 eaux lourdes |
| **Impact météoritique** | 14 | pluies de météorites (toutes les 20 à 40 min) | foreuse électrique ou lourde | 5 à 15 tuiles, 100 à 300 météorites ρ8 par tuile |
| Météorites (par fusée) | 14 | remorqueur orbital, sonde profonde | silo | — |
| **Faille du Cœur** | 15 | 3 à 5 failles, gardées par des primordiaux | ancre de faille | matière exotique brute, infinie |

Tuiles et biomes nouveaux (`X.tiles`) : **asphalte** (époque 4, route : marche ×1,4), **champs de cratères**
(11 ; texture choisie d'après sa couleur **mesurée**, F36 et F38 ; une image nouvelle est probable, Q2),
**sables noirs** (12, rivage), **sol étrange** (13, posé par la contagion), **abysse du Cœur** (15).

**Objets et fluides nouveaux par époque** (`X.items`) :

| Ép. | Objets | Fluides |
|---|---|---|
| 1 | Tissu de déchiqueteur, Codex I : journal du pionnier | — |
| 2 | Coke, Laitier, Ciment, Sable, Codex II : carnet de forge | — |
| 3 | Verre, Manomètre, Codex III : registre des chaudières | — |
| 4 | Asphalte, Codex IV : relevés de forage | Éthylène |
| 5 | Carbure de tungstène, Trépan en carbure, Pack géologique, Codex V : atlas des cendres | Gaz volcanique |
| 6 | Graphite, Tôle magnétique, Fil émaillé, Bobine, Codex VI : schémas du réseau | — |
| 7 | Cristal taillé, Poudre de cristal, Lentille de résonance, Oscillateur à cristal, Pack de résonance, Cristal chargé, Relevé gravimétrique, Codex VII : partitions du cristal | — |
| 8 | Échantillon de vase, Culture méthanotrophe, Biopolymère, Pack biochimique, Codex VIII : herbier du marais | Hydrogène, Oxygène, Dioxyde de carbone |
| 9 | Galène, Plaque de plomb, Blindage plombé, Pack isotopique, Cuivre activé, Piège magnétique, Piège à positons, Données d'annihilation, Cellule usée refroidie, Colis vitrifié, Codex IX : cahier du réacteur | — |
| 10 | Silicium métallurgique, Silicium pur, Tranche de silicium, Cristal temporel instable, Données chronométriques, Concentré de fer ρ8, Concentré de cuivre ρ8, Concentré de tungstène ρ8, Billette de fer ρ8, Billette de cuivre ρ8, Billette de tungstène ρ8, Codex X : plans de la salle blanche | — |
| 11 | Minerai d'ilménite, Concentré d'ilménite ρ8, Laitier titanifère ρ8, Éponge de titane ρ8, Plaque de titane ρ8, Soude caustique, Chlorure de magnésium, Magnésium, Composite titane, Pack structurel, Cryostat, Inclusion étrange, Données hadroniques, Cristal temporel stable, Sablier quantique, Codex XI : carte des cratères | Saumure, Chlore, Tétrachlorure de titane |
| 12 | Minerai de monazite, Concentré de monazite ρ8, Concentré de terres rares, Oxyde de thorium, Néodyme, Yttrium, Ruban supraconducteur, Aimant permanent, Bobine supraconductrice, Cellule de sel au thorium, Sel usé, Pack magnétique, Cellule SMES vide, Cellule SMES chargée, Cavité de résonance, Condensat d'axions, Codex XII : traité des aimants | Azote liquide, Oxygène liquide, Hélium, Hélium liquide, Flux sombre |
| 13 | Ilménite dégazée ρ8, Pastille de fusion, Pastille de fusion catalysée, Cellule de plasma, Pack plasma, Piège à antiprotons, Piège d'antihydrogène, Micro-charge d'antimatière, Obus d'annihilation, Strangelet confiné, Plaque étrange, Bloc de fer ρ32, Bloc de cuivre ρ32, Codex XIII : journal du confinement | Hélium-3, Eau lourde, Deutérium, Plasma |
| 14 | Météorite ferreuse ρ8, Météorite étrange ρ8, Ferronickel ρ8, Iridium, Superalliage ρ32, Miroir d'iridium, Ergol cryogénique, Remorqueur orbital, Centrale solaire orbitale, Sonde profonde, Armure étrange, Codex XIV : archives orbitales de l'Arche | Hydrogène liquide |
| 15 | Cavité de Casimir, Matière exotique stabilisée, Pack exotique, Segment d'anneau, Clé de phase | Matière exotique brute |

### 3.3 Bâtiments nouveaux (69, plus le centre existant ; généré depuis `X.buildings`)

- La taille maximale est 10×10 (Q9) : la Porte et le réacteur à annihilation l'atteignent.
- Les quatre familles d'énergie inhabituelles (chaleur, vapeur, brûleur à résidu, fluide brûlé) sont
  permises par le schéma 1.1.91 ; leur comportement est **non vérifié** en moteur (§8).
- Les époques 13 et 14 restent chargées (12 et 11 bâtiments, dont 6 et 9 de branche). Un niveau II a été
  avancé à l'époque 11 (greffe) ; aller plus loin coûterait la cohérence physique (le plasma n'existe qu'à 13).

| Bâtiment | Ép. | Prototype 1.1 | Taille | Énergie | Rôle |
|---|---|---|---|---|---|
| Atelier à combustion | 1 | assembling-machine | 3×3 | brûleur (chemical), 150 kW | vitesse 0,5 |
| Laboratoire à combustion | 1 | lab | 3×3 | brûleur (chemical), 120 kW | vitesse 0,5 |
| Four à coke | 2 | assembling-machine | 3×3 | brûleur (chemical), 180 kW | vitesse 1 |
| Haut fourneau | 2 | assembling-machine | 4×4 | brûleur (chemical), 600 kW | vitesse 1 |
| Concasseur | 2 | assembling-machine | 2×2 | brûleur (chemical), 120 kW | vitesse 1 |
| Marteau-pilon à vapeur | 3 | assembling-machine | 3×3 | vapeur, 900 kW | vitesse 1 |
| Torchère | 4 | furnace | 2×2 | 50 kW | vitesse 1 |
| Vapocraqueur | 4 | assembling-machine | 3×3 | 600 kW | vitesse 1 |
| Capteur géothermique | 5 | mining-drill | 3×3 | 300 kW | minage 1 (fo-fumarole) |
| Four de frittage | 5 | assembling-machine | 3×3 | 600 kW | vitesse 1 |
| Foreuse lourde | 5 | mining-drill | 3×3 | 400 kW | minage 1 (basic-solid, fo-hard-solid) |
| Four à arc | 6 | assembling-machine | 4×4 | 3 MW | vitesse 2 |
| Bobineuse | 6 | assembling-machine | 2×2 | 200 kW | vitesse 1 |
| Pylône haute tension | 6 | electric-pole | 2×2 | — | fil 64 |
| Broyeur à mâchoires | 6 | assembling-machine | 3×3 | 500 kW | vitesse 2 |
| Taillerie | 7 | assembling-machine | 3×3 | 400 kW | vitesse 1 |
| Amplificateur de résonance | 7 | beacon | 3×3 | 600 kW | 3 emplacements, diffusion 0,75 |
| Résonateur de caustique [A-I] | 7 | assembling-machine | 2×2 | 500 kW | vitesse 1 ; recette fixe ; actif seulement à 64 tuiles au plus d'une veine |
| Station de charge | 7 | assembling-machine | 2×2 | 10 MW | vitesse 1 |
| Générateur à cristal | 7 | burner-generator | 2×2 | produit 1 MW |  |
| Reformeur | 8 | assembling-machine | 3×3 | 1 MW | vitesse 1 |
| Électrolyseur | 8 | assembling-machine | 3×3 | 3 MW | vitesse 1 |
| Bioréacteur | 8 | assembling-machine | 3×3 | 300 kW | vitesse 1 |
| Turbine à gaz | 8 | generator | 3×5 | produit 10 MW |  |
| Irradiateur [B-I] | 9 | assembling-machine | 3×3 | chaleur ≥ 500 °C, 10 MW | vitesse 1 |
| Modérateur de positons [B-I] | 9 | assembling-machine | 3×3 | 2 MW | vitesse 1 ; confinement |
| Piscine d'entreposage | 9 | assembling-machine | 4×4 | aucune | vitesse 1 |
| Dépôt géologique | 9 | container | 6×6 | — |  |
| Salle blanche | 10 | assembling-machine | 5×5 | 4 MW | vitesse 1 |
| Radar à réseau phasé | 10 | radar | 3×3 | 1,2 MW |  |
| Concentrateur | 10 | assembling-machine | 2×2 | 1 MW | vitesse 1 ; accolé à une foreuse lourde, en insertion directe (BALANCE_SHEET §4) |
| Réacteur de Kroll | 11 | assembling-machine | 4×4 | 2 MW | vitesse 1 |
| Résonateur temporel [C-II] | 11 | assembling-machine | 3×3 | 8 MW | vitesse 1 |
| Chambre de dilatation [C-II] | 11 | assembling-machine | 3×3 | 5 MW | vitesse 1 ; recette fixe ; +100 % de vitesse à 3 tuiles |
| Coffre intriqué [C-II] | 11 | linked-container | 1×1 | — |  |
| Unité cryogénique | 12 | assembling-machine | 5×5 | 4 MW | vitesse 1 |
| Colonne d'extraction | 12 | assembling-machine | 3×3 | 500 kW | vitesse 1 |
| Réacteur à sels fondus | 12 | reactor | 5×5 | brûleur (fo-thorium) → 160 MW de chaleur |  |
| Accumulateur supraconducteur | 12 | accumulator | 3×3 | — |  |
| Locomotive maglev | 12 | locomotive | 2×6 | brûleur (fo-electric-storage) |  |
| Haloscope [A-II] | 12 | mining-drill | 5×5 | 20 MW | minage 1 (fo-caustic) |
| Condenseur gravitique [A-II] | 12 | assembling-machine | 4×4 | 15 MW | vitesse 1 |
| Puits gravitique [A-II] | 12 | mining-drill | 5×5 | brûleur (fo-axion), 2 MW | minage 1 (fo-deep) |
| Colonne isotopique | 13 | assembling-machine | 3×3 | 2 MW | vitesse 1 |
| Réacteur à fusion | 13 | reactor | 7×7 | brûleur (fo-fusion) → 800 MW de chaleur |  |
| Injecteur de plasma | 13 | boiler | 3×3 | chaleur ≥ 1000 °C, 200 MW |  |
| Turbine MHD | 13 | generator | 5×5 | produit 200 MW |  |
| Fonderie à plasma | 13 | assembling-machine | 5×5 | 20 MW | vitesse 1 |
| Foreuse profonde | 13 | mining-drill | 5×5 | 5 MW | minage 1 (fo-mantle) |
| Synchrotron [B-II] | 13 | assembling-machine | 9×9 | 150 MW | vitesse 1 ; confinement |
| Recombineur [B-II] | 13 | assembling-machine | 3×3 | 10 MW | vitesse 1 ; confinement |
| Compresseur hadronique [D-II] | 13 | assembling-machine | 5×5 | 100 MW | vitesse 1 |
| Cuve de catalyse [D-II] | 13 | assembling-machine | 4×4 | 30 MW | vitesse 1 ; contagion |
| Transmutateur [D-II] | 13 | assembling-machine | 4×4 | 50 MW | vitesse 1 |
| Mur étrange [D-II] | 13 | wall | 1×1 | — | 12000 PV |
| Rectenna | 14 | electric-energy-interface | 6×6 | produit 200 MW |  |
| Bouclier de déviation | 14 | assembling-machine | 4×4 | 30 MW |  |
| Puits gravitique II [A-III] | 14 | mining-drill | 5×5 | brûleur (fo-axion), 4 MW | minage 4 (fo-deep) |
| Bouclier de marée [A-III] | 14 | electric-turret | 4×4 | 20 MW |  |
| Observatoire de la Caustique [A-III] | 14 | wonder | 9×9 | — | merveille |
| Réacteur à annihilation [B-III] | 14 | reactor | 10×10 | brûleur (fo-antimatter) → 2000 MW de chaleur | confinement |
| Lance d'annihilation [B-III] | 14 | ammo-turret | 4×4 | — |  |
| Chambre de dilatation II [C-III] | 14 | assembling-machine | 3×3 | 10 MW | vitesse 1 ; recette fixe ; +200 % de vitesse à 3 tuiles |
| Horloge éternelle [C-III] | 14 | wonder | 9×9 | — | merveille |
| Mur de neutronium [D-III] | 14 | wall | 1×1 | — | 50000 PV |
| Monolithe étrange [D-III] | 14 | wonder | 9×9 | — | merveille |
| Ancre de faille | 15 | mining-drill | 7×7 | 100 MW | minage 1 (fo-rift) |
| Stabilisateur de Casimir | 15 | assembling-machine | 5×5 | 500 MW | vitesse 1 |
| Porte d'Érèbe | 15 | rocket-silo | 10×10 | 5000 MW | vitesse 1 ; recette fixe |

### 3.4 Arbres de fabrication (toutes les recettes nouvelles ; générés depuis `X.recipes`)

**Notation**
- « main ou assembleur » : catégorie `crafting` ; « assembleur » : `advanced-crafting` (impossible à la main).
- *(dense)* : recette qui recevra des variantes ρ du lot C (§4.1). (prod.) : productivité permise.
- [A-II] : branche et niveau. « p x % » : probabilité. [cat. n] : quantité catalytique (`catalyst_amount`).
- *minage*, *combustion*, *lancement*, *cueillette*, *butin*, *chauffe* : pseudo-recettes (extraction,
  combustible et son résidu `burnt_result`, charge utile `rocket_launch_products`, arbre, `loot`, chaudière).
- Les recettes vanilla restent **inchangées** (`data/base/prototypes/recipe.lua`) : les améliorations sont
  des **variantes** (moteur électrique bobiné, processeur en salle blanche, structure basse densité au titane,
  polyéthylène, acier au haut fourneau, engrenage forgé…).

#### Époque 1 · Pionnier
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Atelier à combustion | 6 Plaque de fer + 5 Engrenage + 6 Brique de pierre | 1 Atelier à combustion | main ou assembleur | 2 s |
| Laboratoire à combustion | 10 Engrenage + 10 Câble de cuivre + 6 Brique de pierre + 4 Bois | 1 Laboratoire à combustion | main ou assembleur | 3 s |
| Butin : tissu de déchiqueteur *butin* | — | Tissu de déchiqueteur (p 2 %) | main | 1 s |
| Codex I : journal du pionnier | 10 Pack d'automatisation + 20 Circuit électronique + 20 Plaque de fer + 20 Brique de pierre | 1 Codex I : journal du pionnier | main ou assembleur | 30 s |

#### Époque 2 · Forge
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Four à coke | 20 Brique de pierre + 10 Plaque de fer | 1 Four à coke | main ou assembleur | 3 s |
| Concasseur | 10 Plaque de fer + 10 Engrenage + 5 Brique de pierre | 1 Concasseur | main ou assembleur | 2 s |
| Haut fourneau | 40 Brique de pierre + 10 Plaque d'acier + 10 Engrenage | 1 Haut fourneau | main ou assembleur | 5 s |
| Cokéfaction *(dense)* (prod.) | 3 Charbon | 2 Coke | Four à coke | 4 s |
| Acier au haut fourneau *(dense)* | 4 Plaque de fer + 1 Coke | 1 Plaque d'acier + 1 Laitier | Haut fourneau | 12 s |
| Ciment de laitier *(dense)* | 2 Laitier + 1 Pierre | 2 Ciment | Concasseur ou Broyeur à mâchoires | 2 s |
| Sable *(dense)* | 1 Pierre | 2 Sable | Concasseur ou Broyeur à mâchoires | 1 s |
| Codex II : carnet de forge | 20 Plaque d'acier + 20 Ciment + 10 Pack logistique + 10 Coke | 1 Codex II : carnet de forge | main ou assembleur | 30 s |

#### Époque 3 · Vapeur
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Verre *(dense)* (prod.) | 4 Sable | 1 Verre | four | 3,2 s |
| Manomètre (prod.) | 1 Verre + 1 Engrenage + 1 Tuyau | 1 Manomètre | main ou assembleur | 2 s |
| Marteau-pilon à vapeur | 10 Plaque d'acier + 4 Tuyau + 2 Manomètre + 10 Engrenage | 1 Marteau-pilon à vapeur | main ou assembleur | 5 s |
| Engrenage forgé (prod.) | 3 Plaque de fer | 2 Engrenage | Marteau-pilon à vapeur | 1 s |
| Béton au ciment *(dense)* | 4 Ciment + 6 Sable + 50 Eau | 10 Béton | assembleur 2 ou 3 | 10 s |
| Codex III : registre des chaudières | 10 Manomètre + 20 Béton + 10 Pack militaire + 10 Verre | 1 Codex III : registre des chaudières | main ou assembleur | 30 s |

#### Époque 4 · Pétrole
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Torchère | 10 Plaque d'acier + 5 Tuyau + 2 Manomètre | 1 Torchère | main ou assembleur | 3 s |
| Vapocraqueur | 10 Plaque d'acier + 10 Tuyau + 5 Manomètre + 5 Circuit électronique + 20 Brique de pierre | 1 Vapocraqueur | main ou assembleur | 5 s |
| Vapocraquage | 30 Gaz de pétrole + 20 Vapeur | 30 Éthylène | Vapocraqueur | 2 s |
| Polyéthylène (prod.) | 20 Éthylène + 1 Charbon | 3 Plastique | usine chimique | 1 s |
| Asphalte | 10 Huile lourde + 5 Sable | 10 Asphalte | usine chimique | 4 s |
| Codex IV : relevés de forage | 20 Plastique + 10 Circuit avancé + 10 Pack chimique + 20 Asphalte | 1 Codex IV : relevés de forage | main ou assembleur | 30 s |
| Torchère *(puits)* | 100 de : Éthylène | — | Torchère | 1 s |

#### Époque 5 · Volcan
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Capteur géothermique | 10 Plaque de tungstène + 20 Tuyau + 4 Manomètre + 5 Circuit électronique | 1 Capteur géothermique | main ou assembleur | 8 s |
| Captage : fumerolle *minage* | — | 200 Gaz volcanique | Capteur géothermique | 1 s |
| Séparation du gaz volcanique | 100 Gaz volcanique | 70 Vapeur + 1 Soufre | usine chimique | 1 s |
| Four de frittage | 20 Brique de pierre + 10 Plaque de tungstène + 10 Circuit électronique + 5 Béton | 1 Four de frittage | main ou assembleur | 6 s |
| Carbure de tungstène (prod.) | 2 Plaque de tungstène + 1 Coke | 2 Carbure de tungstène | Four de frittage | 8 s |
| Trépan en carbure (prod.) | 1 Carbure de tungstène + 2 Plaque d'acier | 1 Trépan en carbure | main ou assembleur | 4 s |
| Foreuse lourde | 1 Foreuse électrique + 4 Trépan en carbure + 10 Plaque d'acier + 5 Moteur | 1 Foreuse lourde | main ou assembleur | 8 s |
| Pack géologique | 1 Trépan en carbure + 1 Soufre + 2 Pierre | 2 Pack géologique | main ou assembleur | 12 s |
| Codex V : atlas des cendres | 20 Plaque de tungstène + 10 Carbure de tungstène + 10 Pack géologique + 5 Trépan en carbure | 1 Codex V : atlas des cendres | main ou assembleur | 30 s |
| Torchère *(puits)* | 100 de : Gaz volcanique | — | Torchère | 1 s |

#### Époque 6 · Électricité
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Four à arc | 20 Plaque d'acier + 10 Béton + 10 Circuit avancé + 40 Câble de cuivre | 1 Four à arc | main ou assembleur | 10 s |
| Bobineuse | 10 Plaque d'acier + 5 Circuit électronique + 10 Engrenage | 1 Bobineuse | main ou assembleur | 4 s |
| Graphite *(dense)* (prod.) | 4 Coke | 3 Graphite | Four à arc | 6 s |
| Acier électrique *(dense)* | 3 Plaque de fer + 1 Graphite | 1 Plaque d'acier | Four à arc | 3 s |
| Tôle magnétique *(dense)* (prod.) | 2 Plaque d'acier + 1 Sable | 2 Tôle magnétique | Four à arc | 4 s |
| Fil émaillé (prod.) | 2 Câble de cuivre + 1 Plastique | 4 Fil émaillé | Bobineuse | 2 s |
| Bobine (prod.) | 4 Fil émaillé + 2 Tôle magnétique | 1 Bobine | Bobineuse | 3 s |
| Pylône haute tension | 10 Plaque d'acier + 4 Câble de cuivre + 2 Bobine | 1 Pylône haute tension | main ou assembleur | 2 s |
| Broyeur à mâchoires | 1 Concasseur + 10 Plaque d'acier + 2 Bobine + 5 Circuit électronique | 1 Broyeur à mâchoires | main ou assembleur | 4 s |
| Moteur électrique bobiné | 1 Moteur + 1 Bobine + 2 Circuit électronique + 10 Lubrifiant | 1 Moteur électrique | assembleur 2 ou 3 | 10 s |
| Codex VI : schémas du réseau | 10 Bobine + 20 Batterie + 10 Pack de production + 10 Graphite | 1 Codex VI : schémas du réseau | main ou assembleur | 30 s |

#### Époque 7 · Cristal
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Taillerie | 10 Plaque de tungstène + 5 Carbure de tungstène + 10 Circuit avancé + 2 Bobine | 1 Taillerie | main ou assembleur | 6 s |
| Taille du cristal | 2 Cristal de résonance + 20 Eau | 1 Cristal taillé + 1 Poudre de cristal | Taillerie | 5 s |
| Lentille de résonance (prod.) | 1 Cristal taillé + 2 Verre | 1 Lentille de résonance | Taillerie | 6 s |
| Oscillateur à cristal (prod.) | 1 Poudre de cristal + 1 Circuit électronique + 2 Fil émaillé | 2 Oscillateur à cristal | main ou assembleur | 3 s |
| Amplificateur de résonance | 1 Balise + 4 Lentille de résonance + 10 Oscillateur à cristal | 1 Amplificateur de résonance | main ou assembleur | 8 s |
| Pack de résonance | 1 Lentille de résonance + 2 Oscillateur à cristal + 1 Bobine | 2 Pack de résonance | main ou assembleur | 14 s |
| Résonateur de caustique [A-I] | 4 Lentille de résonance + 10 Oscillateur à cristal + 1 Radar + 10 Plaque de tungstène | 1 Résonateur de caustique | main ou assembleur | 8 s |
| Relevé gravimétrique [A-I] | 2 Oscillateur à cristal | 1 Relevé gravimétrique | Résonateur de caustique | 30 s |
| Station de charge | 10 Plaque d'acier + 4 Bobine + 5 Circuit avancé + 2 Accumulateur | 1 Station de charge | main ou assembleur | 6 s |
| Charge du cristal | 1 Cristal taillé | 1 Cristal chargé | Station de charge | 2 s |
| Générateur à cristal | 10 Plaque d'acier + 5 Bobine + 2 Lentille de résonance + 1 Machine à vapeur | 1 Générateur à cristal | main ou assembleur | 5 s |
| Décharge : cristal chargé *combustion* | 1 Cristal chargé | 1 Cristal taillé | Générateur à cristal, Locomotive maglev | 16 s |
| Codex VII : partitions du cristal | 5 Lentille de résonance + 10 Oscillateur à cristal + 10 Pack de résonance + 5 Cristal taillé | 1 Codex VII : partitions du cristal | main ou assembleur | 30 s |

#### Époque 8 · Marais
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Abattage d'arbre des marais *cueillette* | — | 4 Bois + Échantillon de vase (p 30 %) | main | 1 s |
| Reformeur | 15 Plaque d'acier + 10 Tuyau + 5 Plaque de tungstène + 5 Circuit avancé | 1 Reformeur | main ou assembleur | 6 s |
| Électrolyseur | 10 Plaque d'acier + 10 Bobine + 10 Circuit avancé + 10 Plastique | 1 Électrolyseur | main ou assembleur | 8 s |
| Bioréacteur | 10 Verre + 10 Plaque d'acier + 5 Tuyau + 5 Circuit électronique | 1 Bioréacteur | main ou assembleur | 5 s |
| Turbine à gaz | 20 Plaque d'acier + 10 Plaque de tungstène + 5 Bobine + 2 Moteur électrique | 1 Turbine à gaz | main ou assembleur | 8 s |
| Reformage du méthane | 50 Méthane + 100 Vapeur | 200 Hydrogène + 50 Dioxyde de carbone | Reformeur | 2 s |
| Électrolyse de l'eau | 100 Eau | 100 Hydrogène + 50 Oxygène | Électrolyseur | 2 s |
| Mise en culture (vase) | 5 Échantillon de vase + 50 Eau | 1 Culture méthanotrophe | Bioréacteur | 30 s |
| Mise en culture (tissu) | 5 Tissu de déchiqueteur + 50 Eau | 1 Culture méthanotrophe | Bioréacteur | 30 s |
| Croissance de la culture | 10 Culture méthanotrophe [cat. 10] + 100 Méthane + 50 Eau | 12 Culture méthanotrophe [cat. 10] | Bioréacteur | 20 s |
| Biopolymère (PHB) | 1 Culture méthanotrophe + 60 Méthane + 40 Oxygène | 4 Biopolymère + 20 Dioxyde de carbone | Bioréacteur | 10 s |
| Méthane de digesteur | 10 Tissu de déchiqueteur + 50 Eau | 60 Méthane | Bioréacteur | 20 s |
| Carbonatation du laitier | 50 Dioxyde de carbone + 2 Laitier | 3 Ciment | usine chimique | 4 s |
| Pack biochimique | 1 Culture méthanotrophe + 2 Biopolymère + 20 Acide sulfurique | 2 Pack biochimique | usine chimique | 15 s |
| Codex VIII : herbier du marais | 20 Biopolymère + 5 Culture méthanotrophe + 10 Pack biochimique | 1 Codex VIII : herbier du marais | main ou assembleur | 30 s |
| Torchère *(puits)* | 100 de : Hydrogène, Oxygène, Dioxyde de carbone | — | Torchère | 1 s |

#### Époque 9 · Atome
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Minage : galène *minage* | — | 1 Galène | main, foreuse à combustible, Foreuse électrique, Foreuse lourde | 1 s |
| Plomb *(dense)* (prod.) | 2 Galène | 1 Plaque de plomb | four | 3,2 s |
| Grillage de la galène *(dense)* | 4 Galène + 20 Oxygène | 3 Plaque de plomb + 1 Soufre | Four à arc | 4 s |
| Blindage plombé (prod.) | 3 Plaque de plomb + 1 Plaque d'acier | 1 Blindage plombé | main ou assembleur | 3 s |
| Pack isotopique | 2 Plaque de plomb + 1 Uranium 238 + 1 Oscillateur à cristal | 2 Pack isotopique | main ou assembleur | 15 s |
| Irradiateur [B-I] | 20 Blindage plombé + 20 Caloduc + 10 Circuit avancé | 1 Irradiateur | main ou assembleur | 10 s |
| Modérateur de positons [B-I] | 10 Blindage plombé + 10 Bobine + 10 Plaque de tungstène + 10 Circuit avancé | 1 Modérateur de positons | main ou assembleur | 10 s |
| Activation du cuivre [B-I] | 10 Plaque de cuivre | 10 Cuivre activé | Irradiateur | 30 s |
| Piège magnétique [B-I] | 4 Bobine + 2 Blindage plombé + 2 Circuit avancé | 1 Piège magnétique | main ou assembleur | 10 s |
| Capture de positons [B-I] | 10 Cuivre activé + 1 Piège magnétique | 1 Piège à positons + 10 Plaque de cuivre | Modérateur de positons | 60 s |
| Annihilation contrôlée [B-I] | 1 Piège à positons | 1 Piège magnétique + 4 Données d'annihilation | Modérateur de positons | 20 s |
| Piscine d'entreposage | 50 Béton + 20 Blindage plombé + 10 Tuyau + 1 Pompe côtière | 1 Piscine d'entreposage | main ou assembleur | 10 s |
| Refroidissement en piscine | 10 Cellule d'uranium usée | 10 Cellule usée refroidie | Piscine d'entreposage | 600 s |
| Vitrification | 2 Cellule usée refroidie + 4 Verre | 1 Colis vitrifié + 1 Uranium 238 | Four à arc | 20 s |
| Dépôt géologique | 100 Béton + 50 Blindage plombé + 20 Plaque d'acier | 1 Dépôt géologique | main ou assembleur | 10 s |
| Codex IX : cahier du réacteur | 20 Blindage plombé + 2 Cellule d'uranium + 10 Pack isotopique | 1 Codex IX : cahier du réacteur | main ou assembleur | 30 s |

#### Époque 10 · Haute technologie
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Salle blanche | 50 Béton + 20 Plaque d'acier + 20 Circuit avancé + 10 Verre + 10 Bobine | 1 Salle blanche | assembleur | 15 s |
| Silicium métallurgique *(dense)* (prod.) | 4 Sable + 1 Graphite | 1 Silicium métallurgique | Four à arc | 6 s |
| Silicium pur (prod.) | 2 Silicium métallurgique + 30 Hydrogène | 1 Silicium pur | usine chimique | 8 s |
| Tranche de silicium (prod.) | 1 Silicium pur | 4 Tranche de silicium | Salle blanche | 10 s |
| Processeur en salle blanche (prod.) | 10 Circuit électronique + 2 Circuit avancé + 1 Tranche de silicium + 5 Acide sulfurique | 2 Processeur | Salle blanche | 15 s |
| Radar à réseau phasé | 1 Radar + 10 Processeur + 20 Oscillateur à cristal + 10 Tôle magnétique | 1 Radar à réseau phasé | assembleur | 10 s |
| Cristal temporel instable [C-I] | 1 Cristal taillé + 2 Tranche de silicium + 1 Processeur | 1 Cristal temporel instable | Salle blanche | 30 s |
| Mesure de phase [C-I] | 1 Cristal temporel instable | 4 Données chronométriques + 1 Poudre de cristal | Salle blanche | 20 s |
| Concentrateur | 10 Plaque d'acier + 4 Bobine + 5 Processeur + 10 Carbure de tungstène | 1 Concentrateur | assembleur | 8 s |
| Concentré de fer ρ8 | 8 Minerai de fer | 1 Concentré de fer ρ8 | Concentrateur | 1 s |
| Concentré de cuivre ρ8 | 8 Minerai de cuivre | 1 Concentré de cuivre ρ8 | Concentrateur | 1 s |
| Concentré de tungstène ρ8 | 8 Minerai de tungstène | 1 Concentré de tungstène ρ8 | Concentrateur | 1 s |
| Fonte de concentré de fer *(dense)* | 1 Concentré de fer ρ8 | 1 Billette de fer ρ8 | Four à arc | 12,8 s |
| Fonte de concentré de cuivre *(dense)* | 1 Concentré de cuivre ρ8 | 1 Billette de cuivre ρ8 | Four à arc | 12,8 s |
| Fonte de concentré de tungstène *(dense)* | 1 Concentré de tungstène ρ8 | 1 Billette de tungstène ρ8 | Four à arc | 25,6 s |
| Découpe de billette de fer | 1 Billette de fer ρ8 | 8 Plaque de fer | main ou assembleur | 1 s |
| Découpe de billette de cuivre | 1 Billette de cuivre ρ8 | 8 Plaque de cuivre | main ou assembleur | 1 s |
| Découpe de billette de tungstène | 1 Billette de tungstène ρ8 | 8 Plaque de tungstène | main ou assembleur | 1 s |
| Codex X : plans de la salle blanche | 20 Processeur + 10 Tranche de silicium + 10 Pack utilitaire | 1 Codex X : plans de la salle blanche | main ou assembleur | 30 s |

#### Époque 11 · Titane
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Minage : ilménite *minage* | — | 1 Minerai d'ilménite | Foreuse électrique, Foreuse lourde | 2 s |
| Concentré d'ilménite ρ8 | 8 Minerai d'ilménite | 1 Concentré d'ilménite ρ8 | Concentrateur | 1 s |
| Pompage : saumure *minage* | — | 10 Saumure | chevalet de pompage | 1 s |
| Minage : brèche d'impact [D-I] *minage* | — | 1 Pierre + Inclusion étrange (p 0,5 %) | Foreuse électrique, Foreuse lourde | 2 s |
| Réacteur de Kroll | 30 Plaque d'acier + 20 Plaque de tungstène + 10 Bobine + 10 Processeur | 1 Réacteur de Kroll | assembleur | 12 s |
| Fusion de l'ilménite *(dense)* | 2 Concentré d'ilménite ρ8 + 2 Coke | 1 Laitier titanifère ρ8 + 6 Plaque de fer | Four à arc | 10 s |
| Électrolyse de la saumure | 100 Saumure | 40 Chlore + 40 Hydrogène + 1 Soude caustique + 1 Chlorure de magnésium | Électrolyseur | 3 s |
| Chloration | 1 Laitier titanifère ρ8 + 1 Coke + 60 Chlore | 40 Tétrachlorure de titane | usine chimique | 5 s |
| Réduction de Kroll | 40 Tétrachlorure de titane + 2 Magnésium | 1 Éponge de titane ρ8 + 2 Chlorure de magnésium | Réacteur de Kroll | 15 s |
| Électrolyse du chlorure de magnésium | 1 Chlorure de magnésium | 1 Magnésium + 15 Chlore | Électrolyseur | 3 s |
| Refusion sous vide *(dense)* (prod.) | 1 Éponge de titane ρ8 | 1 Plaque de titane ρ8 | Four à arc | 4 s |
| Tungstène par voie humide *(dense)* | 5 Minerai de tungstène + 1 Soude caustique + 40 Hydrogène | 4 Plaque de tungstène | usine chimique | 8 s |
| Cryostat (prod.) | 1 Plaque de titane ρ8 + 2 Biopolymère + 1 Processeur | 1 Cryostat | main ou assembleur | 10 s |
| Composite titane (prod.) | 1 Plaque de titane ρ8 + 2 Biopolymère + 1 Graphite | 2 Composite titane | main ou assembleur | 15 s |
| Structure basse densité au titane (prod.) | 1 Composite titane + 4 Plaque de cuivre | 2 Structure basse densité | main ou assembleur | 15 s |
| Pack structurel | 1 Composite titane + 1 Plaque de titane ρ8 + 1 Plaque de tungstène | 3 Pack structurel | main ou assembleur | 20 s |
| Analyse d'inclusion [D-I] | 1 Inclusion étrange + 1 Processeur | 4 Données hadroniques | Salle blanche | 60 s |
| Résonateur temporel [C-II] | 2 Plaque de titane ρ8 + 1 Cryostat + 10 Oscillateur à cristal + 10 Processeur | 1 Résonateur temporel | assembleur | 20 s |
| Cristal temporel stable (verrouillage de phase) [C-II] | 2 Cristal temporel instable + 4 Oscillateur à cristal | 1 Cristal temporel stable | Résonateur temporel | 80 s |
| Sablier quantique [C-II] | 1 Cristal temporel stable + 2 Oscillateur à cristal + 1 Processeur | 4 Sablier quantique | Salle blanche | 30 s |
| Chambre de dilatation [C-II] | 1 Amplificateur de résonance + 2 Cristal temporel stable + 10 Bobine + 5 Composite titane | 1 Chambre de dilatation | assembleur | 20 s |
| Maintien de phase [C-II] | 1 Cristal temporel stable | 1 Cristal temporel instable | Chambre de dilatation ou Chambre de dilatation II | 300 s |
| Coffre intriqué [C-II] | 2 Cristal temporel stable + 4 Plaque de titane ρ8 + 5 Processeur | 2 Coffre intriqué | assembleur | 20 s |
| Codex XI : carte des cratères | 5 Plaque de titane ρ8 + 10 Composite titane + 10 Pack structurel | 1 Codex XI : carte des cratères | main ou assembleur | 30 s |
| Torchère *(puits)* | 100 de : Saumure, Chlore, Tétrachlorure de titane | — | Torchère | 1 s |

#### Époque 12 · Supraconducteurs
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Minage : monazite *minage* | — | 1 Minerai de monazite | Foreuse électrique, Foreuse lourde | 2 s |
| Concentré de monazite ρ8 | 8 Minerai de monazite | 1 Concentré de monazite ρ8 | Concentrateur | 1 s |
| Unité cryogénique | 40 Plaque d'acier + 3 Plaque de titane ρ8 + 10 Moteur électrique + 10 Processeur + 20 Tuyau | 1 Unité cryogénique | assembleur | 15 s |
| Colonne d'extraction | 3 Plaque de titane ρ8 + 10 Verre + 10 Tuyau + 5 Processeur | 1 Colonne d'extraction | assembleur | 8 s |
| Lessivage de la monazite | 1 Concentré de monazite ρ8 + 20 Acide sulfurique | 4 Concentré de terres rares + 1 Oxyde de thorium | usine chimique | 8 s |
| Extraction par solvant | 4 Concentré de terres rares + 10 Pétrole léger | 2 Néodyme + 1 Yttrium | Colonne d'extraction | 6 s |
| Distillation de l'air | — | 50 Azote liquide + 15 Oxygène liquide | Unité cryogénique | 2 s |
| Séparation cryogénique du gaz volcanique | 100 Gaz volcanique + 10 Azote liquide | 70 Vapeur + 1 Soufre + 5 Hélium | Unité cryogénique | 1 s |
| Liquéfaction de l'hélium | 20 Hélium + 20 Azote liquide | 10 Hélium liquide | Unité cryogénique | 4 s |
| Ruban supraconducteur (YBCO) (prod.) | 1 Yttrium + 3 Plaque de cuivre + 20 Oxygène | 4 Ruban supraconducteur | Four de frittage | 6 s |
| Aimant permanent (NdFeB) (prod.) | 1 Néodyme + 2 Plaque de fer | 2 Aimant permanent | Four de frittage | 6 s |
| Bobine supraconductrice (prod.) | 4 Ruban supraconducteur + 1 Cryostat + 20 Azote liquide | 1 Bobine supraconductrice | Bobineuse | 10 s |
| Cellule de sel au thorium | 4 Oxyde de thorium + 1 Uranium 235 + 20 Chlore | 1 Cellule de sel au thorium | usine chimique | 20 s |
| Combustion : sel au thorium (160 MW) *combustion* | 1 Cellule de sel au thorium | 1 Sel usé | Réacteur à sels fondus | 200 s |
| Retraitement du sel | 2 Sel usé | 1 Oxyde de thorium + 1 Uranium 238 | centrifugeuse | 30 s |
| Réacteur à sels fondus | 200 Blindage plombé + 10 Plaque de titane ρ8 + 50 Processeur + 100 Béton | 1 Réacteur à sels fondus | assembleur | 60 s |
| Accumulateur supraconducteur | 4 Bobine supraconductrice + 10 Accumulateur + 2 Cryostat | 1 Accumulateur supraconducteur | assembleur | 10 s |
| Locomotive maglev | 1 Locomotive + 8 Aimant permanent + 4 Bobine supraconductrice + 10 Composite titane | 1 Locomotive maglev | assembleur | 20 s |
| Cellule SMES vide | 2 Bobine supraconductrice + 1 Cryostat + 1 Plaque de titane ρ8 | 1 Cellule SMES vide | main ou assembleur | 10 s |
| Charge de cellule SMES | 1 Cellule SMES vide | 1 Cellule SMES chargée | Station de charge | 50 s |
| Décharge : cellule SMES *combustion* | 1 Cellule SMES chargée | 1 Cellule SMES vide | Locomotive maglev, Générateur à cristal | 1 s |
| Pack magnétique | 1 Bobine supraconductrice + 2 Aimant permanent + 1 Plaque de titane ρ8 | 3 Pack magnétique | main ou assembleur | 20 s |
| Haloscope [A-II] | 4 Bobine supraconductrice + 2 Cryostat + 10 Lentille de résonance + 20 Processeur + 5 Plaque de titane ρ8 | 1 Haloscope | assembleur | 30 s |
| Captage : veine de caustique [A-II] *minage* | — | 20 Flux sombre | Haloscope | 1 s |
| Condenseur gravitique [A-II] | 4 Bobine supraconductrice + 20 Cristal taillé + 10 Processeur + 2 Cryostat | 1 Condenseur gravitique | assembleur | 20 s |
| Cavité de résonance [A-II] | 2 Lentille de résonance + 1 Bobine supraconductrice + 1 Cryostat | 1 Cavité de résonance | main ou assembleur | 15 s |
| Condensation d'axions [A-II] | 200 Flux sombre + 1 Cavité de résonance + 5 Hélium liquide | 1 Condensat d'axions | Condenseur gravitique | 20 s |
| Relevé de condensat [A-II] | 1 Condensat d'axions | 1 Cavité de résonance + 10 Relevé gravimétrique | Condenseur gravitique | 10 s |
| Puits gravitique [A-II] | 1 Foreuse lourde + 4 Condensat d'axions + 10 Bobine supraconductrice + 20 Composite titane | 1 Puits gravitique | assembleur | 30 s |
| Combustion : condensat (puits, 2 MW) [A-II] *combustion* | 1 Condensat d'axions | 1 Cavité de résonance | Puits gravitique, Puits gravitique II | 60 s |
| Remontée profonde : fer [A-II] *minage* | — | 1 Concentré de fer ρ8 | Puits gravitique | 1 s |
| Remontée profonde : cuivre [A-II] *minage* | — | 1 Concentré de cuivre ρ8 | Puits gravitique | 1 s |
| Cristal temporel stable (hélium liquide) [C-II] | 2 Cristal temporel instable + 5 Hélium liquide | 1 Cristal temporel stable | Résonateur temporel | 40 s |
| Codex XII : traité des aimants | 5 Bobine supraconductrice + 10 Aimant permanent + 10 Pack magnétique | 1 Codex XII : traité des aimants | main ou assembleur | 30 s |
| Torchère *(puits)* | 100 de : Azote liquide, Oxygène liquide, Hélium, Hélium liquide, Flux sombre | — | Torchère | 1 s |

#### Époque 13 · Fusion
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Colonne isotopique | 20 Plaque d'acier + 2 Plaque de titane ρ8 + 10 Tuyau + 5 Processeur | 1 Colonne isotopique | assembleur | 10 s |
| Réacteur à fusion | 200 Bobine supraconductrice + 100 Composite titane + 100 Cryostat + 200 Blindage plombé + 500 Béton | 1 Réacteur à fusion | assembleur | 120 s |
| Injecteur de plasma | 10 Bobine supraconductrice + 10 Plaque de tungstène + 10 Caloduc | 1 Injecteur de plasma | assembleur | 20 s |
| Turbine MHD | 20 Aimant permanent + 10 Bobine supraconductrice + 20 Plaque de tungstène + 20 Composite titane | 1 Turbine MHD | assembleur | 20 s |
| Fonderie à plasma | 50 Plaque de tungstène + 20 Bobine supraconductrice + 20 Béton + 10 Processeur | 1 Fonderie à plasma | assembleur | 30 s |
| Foreuse profonde | 1 Foreuse lourde + 20 Carbure de tungstène + 10 Bobine supraconductrice + 10 Processeur | 1 Foreuse profonde | assembleur | 20 s |
| Captage : évent mantellique *minage* | — | 4 Hélium-3 | Foreuse profonde | 1 s |
| Dégazage du régolithe | 1 Concentré d'ilménite ρ8 | 1 Ilménite dégazée ρ8 + 2 Hélium-3 | Four de frittage | 10 s |
| Fusion de l'ilménite dégazée *(dense)* | 2 Ilménite dégazée ρ8 + 2 Coke | 1 Laitier titanifère ρ8 + 6 Plaque de fer | Four à arc | 10 s |
| Distillation isotopique de l'hélium | 100 Hélium [cat. 90] + 10 Azote liquide | 90 Hélium [cat. 90] + 1 Hélium-3 | Unité cryogénique | 5 s |
| Eau lourde (procédé Girdler) | 1000 Eau | 10 Eau lourde | Colonne isotopique | 10 s |
| Électrolyse de l'eau lourde | 100 Eau lourde | 100 Deutérium + 50 Oxygène | Électrolyseur | 2 s |
| Pastille de fusion | 50 Deutérium + 50 Hélium-3 + 1 Composite titane | 1 Pastille de fusion | Unité cryogénique | 10 s |
| Combustion : pastille (800 MW) *combustion* | 1 Pastille de fusion | — | Réacteur à fusion | 100 s |
| Ionisation (injecteur) *chauffe* | 40 Hydrogène | 40 Plasma | Injecteur de plasma | 1 s |
| Cellule de plasma (prod.) | 1 Aimant permanent + 1 Composite titane + 50 Plasma | 1 Cellule de plasma | Fonderie à plasma | 5 s |
| Pack plasma | 1 Cellule de plasma + 1 Bobine supraconductrice + 1 Processeur | 3 Pack plasma | main ou assembleur | 25 s |
| Coulée de bloc de fer *(dense)* | 4 Concentré de fer ρ8 + 20 Plasma | 1 Bloc de fer ρ32 | Fonderie à plasma | 4 s |
| Coulée de bloc de cuivre *(dense)* | 4 Concentré de cuivre ρ8 + 20 Plasma | 1 Bloc de cuivre ρ32 | Fonderie à plasma | 4 s |
| Découpe de bloc de fer | 1 Bloc de fer ρ32 | 4 Billette de fer ρ8 | main ou assembleur | 1 s |
| Découpe de bloc de cuivre | 1 Bloc de cuivre ρ32 | 4 Billette de cuivre ρ8 | main ou assembleur | 1 s |
| Synchrotron [B-II] | 100 Bobine supraconductrice + 50 Aimant permanent + 50 Cryostat + 100 Processeur + 200 Béton | 1 Synchrotron | assembleur | 120 s |
| Recombineur [B-II] | 10 Bobine supraconductrice + 4 Cryostat + 10 Processeur + 10 Blindage plombé | 1 Recombineur | assembleur | 20 s |
| Production d'antiprotons (150 MW) [B-II] | 1 Piège magnétique + 100 Hydrogène | 1 Piège à antiprotons | Synchrotron | 30 s |
| Recombinaison (antihydrogène) [B-II] | 1 Piège à antiprotons + 1 Piège à positons | 1 Piège d'antihydrogène + 1 Piège magnétique | Recombineur | 10 s |
| Micro-charge d'antimatière [B-II] | 1 Piège d'antihydrogène + 10 Plaque de tungstène + 10 Ruban supraconducteur | 10 Micro-charge d'antimatière + 1 Piège magnétique | Recombineur | 20 s |
| Obus d'annihilation [B-II] | 1 Obus d'artillerie + 1 Micro-charge d'antimatière | 1 Obus d'annihilation | main ou assembleur | 10 s |
| Mesure d'annihilation [B-II] | 1 Piège d'antihydrogène | 1 Piège magnétique + 20 Données d'annihilation | Recombineur | 10 s |
| Fusion catalysée par l'antimatière [B-II] | 2 Pastille de fusion + 2 Piège d'antihydrogène | 2 Pastille de fusion catalysée + 2 Piège magnétique | Recombineur | 20 s |
| Combustion : pastille catalysée [B-II] *combustion* | 1 Pastille de fusion catalysée | — | Réacteur à fusion | 200 s |
| Compresseur hadronique [D-II] | 50 Bobine supraconductrice + 50 Plaque de tungstène + 20 Cryostat + 50 Processeur | 1 Compresseur hadronique | assembleur | 60 s |
| Cuve de catalyse [D-II] | 20 Blindage plombé + 20 Bobine supraconductrice + 10 Cryostat + 10 Composite titane | 1 Cuve de catalyse | assembleur | 30 s |
| Germination d'un strangelet [D-II] | 1 Inclusion étrange + 200 Plasma | 1 Strangelet confiné | Compresseur hadronique | 60 s |
| Croissance étrange [D-II] | 2 Strangelet confiné [cat. 2] + 10 Pierre + 10 Sable | 3 Strangelet confiné [cat. 2] | Cuve de catalyse | 30 s |
| Croissance étrange : conversion de laitier [D-II] | 1 Strangelet confiné [cat. 1] + 32 Laitier | 2 Strangelet confiné [cat. 1] | Cuve de catalyse | 30 s |
| Croissance étrange : conversion de sable [D-II] | 1 Strangelet confiné [cat. 1] + 32 Sable | 2 Strangelet confiné [cat. 1] | Cuve de catalyse | 30 s |
| Croissance étrange : conversion de pierre [D-II] | 1 Strangelet confiné [cat. 1] + 32 Pierre | 2 Strangelet confiné [cat. 1] | Cuve de catalyse | 30 s |
| Croissance étrange : conversion de colis vitrifiés [D-II] | 1 Strangelet confiné [cat. 1] + 32 Colis vitrifié | 2 Strangelet confiné [cat. 1] | Cuve de catalyse | 30 s |
| Croissance étrange : conversion de sel usé [D-II] | 1 Strangelet confiné [cat. 1] + 32 Sel usé | 2 Strangelet confiné [cat. 1] | Cuve de catalyse | 30 s |
| Plaque de matière étrange [D-II] | 1 Strangelet confiné + 4 Plaque de tungstène | 2 Plaque étrange | Cuve de catalyse | 20 s |
| Mesure hadronique [D-II] | 1 Strangelet confiné | 12 Données hadroniques | Compresseur hadronique | 10 s |
| Transmutateur [D-II] | 50 Plaque étrange + 20 Bobine supraconductrice + 20 Processeur | 1 Transmutateur | assembleur | 60 s |
| Transmutation : tungsten [D-II] | 1 Strangelet confiné [cat. 1] + 40 Pierre | 1 Strangelet confiné [cat. 1] + 20 Minerai de tungstène | Transmutateur | 20 s |
| Transmutation : ilmenite [D-II] | 1 Strangelet confiné [cat. 1] + 40 Pierre | 1 Strangelet confiné [cat. 1] + 20 Minerai d'ilménite | Transmutateur | 20 s |
| Transmutation : monazite [D-II] | 1 Strangelet confiné [cat. 1] + 40 Pierre | 1 Strangelet confiné [cat. 1] + 20 Minerai de monazite | Transmutateur | 20 s |
| Transmutation : uranium [D-II] | 1 Strangelet confiné [cat. 1] + 40 Pierre | 1 Strangelet confiné [cat. 1] + 20 Minerai d'uranium | Transmutateur | 20 s |
| Transmutation : crystal [D-II] | 1 Strangelet confiné [cat. 1] + 40 Pierre | 1 Strangelet confiné [cat. 1] + 20 Cristal de résonance | Transmutateur | 20 s |
| Mur étrange [D-II] | 1 Mur blindé + 2 Plaque étrange | 1 Mur étrange | main ou assembleur | 5 s |
| Codex XIII : journal du confinement | 2 Pastille de fusion + 5 Cellule de plasma + 10 Pack plasma | 1 Codex XIII : journal du confinement | main ou assembleur | 30 s |
| Torchère *(puits)* | 100 de : Hélium-3, Eau lourde, Deutérium | — | Torchère | 1 s |

#### Époque 14 · Orbite
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Minage : impact météoritique *minage* | — | 1 Météorite ferreuse ρ8 | Foreuse électrique, Foreuse lourde | 3 s |
| Liquéfaction de l'hydrogène | 100 Hydrogène + 10 Azote liquide | 50 Hydrogène liquide | Unité cryogénique | 2 s |
| Ergol cryogénique | 40 Hydrogène liquide + 20 Oxygène liquide + 1 Composite titane | 2 Ergol cryogénique | usine chimique | 10 s |
| Remorqueur orbital | 50 Composite titane + 20 Bobine supraconductrice + 10 Processeur + 20 Ergol cryogénique | 1 Remorqueur orbital | assembleur | 60 s |
| Lancement : remorqueur orbital *lancement* | 1 Remorqueur orbital + 100 Partie de fusée | 50 Météorite ferreuse ρ8 + 5 Météorite étrange ρ8 | silo | 1 s |
| Centrale solaire orbitale | 100 Panneau solaire + 50 Composite titane + 20 Bobine supraconductrice + 20 Processeur | 1 Centrale solaire orbitale | assembleur | 60 s |
| Lancement : centrale solaire orbitale (+50 MW) *lancement* | 1 Centrale solaire orbitale + 100 Partie de fusée | — | silo | 1 s |
| Concassage météoritique | 4 Météorite ferreuse ρ8 | 3 Ferronickel ρ8 + 1 Iridium + 2 Pierre | Concasseur ou Broyeur à mâchoires | 8 s |
| Concassage d'une météorite étrange | 1 Météorite étrange ρ8 | 5 Inclusion étrange + 2 Pierre | Concasseur ou Broyeur à mâchoires | 10 s |
| Superalliage ρ32 *(dense)* (prod.) | 3 Ferronickel ρ8 + 1 Plaque de titane ρ8 + 1 Carbure de tungstène | 1 Superalliage ρ32 | Four à arc | 8 s |
| Miroir d'iridium (prod.) | 2 Iridium + 1 Verre + 1 Composite titane | 1 Miroir d'iridium | Salle blanche | 20 s |
| Rectenna | 20 Aimant permanent + 100 Fil émaillé + 20 Composite titane + 10 Processeur | 1 Rectenna | assembleur | 30 s |
| Bouclier de déviation | 20 Bobine supraconductrice + 2 Superalliage ρ32 + 10 Processeur + 4 Cryostat | 1 Bouclier de déviation | assembleur | 30 s |
| Puits gravitique II [A-III] | 1 Puits gravitique + 10 Condensat d'axions + 5 Superalliage ρ32 | 1 Puits gravitique II | assembleur | 60 s |
| Remontée profonde : tungsten [A-III] *minage* | — | 1 Concentré de tungstène ρ8 | Puits gravitique II | 1 s |
| Remontée profonde : ilmenite [A-III] *minage* | — | 1 Concentré d'ilménite ρ8 | Puits gravitique II | 1 s |
| Remontée profonde : monazite [A-III] *minage* | — | 1 Concentré de monazite ρ8 | Puits gravitique II | 1 s |
| Bouclier de marée [A-III] | 10 Condensat d'axions + 10 Bobine supraconductrice + 5 Superalliage ρ32 | 1 Bouclier de marée | assembleur | 40 s |
| Observatoire de la Caustique [A-III] | 200 Condensat d'axions + 500 Lentille de résonance + 50 Superalliage ρ32 + 300 Processeur | 1 Observatoire de la Caustique | assembleur | 600 s |
| Réacteur à annihilation [B-III] | 300 Bobine supraconductrice + 50 Superalliage ρ32 + 500 Blindage plombé + 100 Cryostat | 1 Réacteur à annihilation | assembleur | 180 s |
| Combustion : antihydrogène (2 GW) [B-III] *combustion* | 1 Piège d'antihydrogène | 1 Piège magnétique | Réacteur à annihilation | 25 s |
| Lance d'annihilation [B-III] | 40 Bobine supraconductrice + 10 Superalliage ρ32 + 20 Processeur + 20 Micro-charge d'antimatière | 1 Lance d'annihilation | assembleur | 60 s |
| Sonde profonde [B-III] | 5 Piège d'antihydrogène + 50 Composite titane + 20 Processeur | 1 Sonde profonde | assembleur | 60 s |
| Lancement : sonde profonde [B-III] *lancement* | 1 Sonde profonde + 100 Partie de fusée | 50 Météorite étrange ρ8 + 50 Iridium | silo | 1 s |
| Chambre de dilatation II [C-III] | 1 Chambre de dilatation + 4 Cristal temporel stable + 2 Superalliage ρ32 | 1 Chambre de dilatation II | assembleur | 30 s |
| Horloge éternelle [C-III] | 100 Cristal temporel stable + 200 Sablier quantique + 50 Superalliage ρ32 + 300 Processeur | 1 Horloge éternelle | assembleur | 600 s |
| Mur de neutronium [D-III] | 1 Mur étrange + 8 Plaque étrange + 1 Superalliage ρ32 | 1 Mur de neutronium | main ou assembleur | 10 s |
| Armure étrange [D-III] | 40 Plaque étrange + 20 Composite titane + 10 Bobine supraconductrice | 1 Armure étrange | assembleur | 60 s |
| Monolithe étrange [D-III] | 500 Plaque étrange + 50 Strangelet confiné + 50 Superalliage ρ32 + 300 Processeur | 1 Monolithe étrange | assembleur | 600 s |
| Codex XIV : archives orbitales de l'Arche | 5 Superalliage ρ32 + 5 Miroir d'iridium + 10 Pack espace | 1 Codex XIV : archives orbitales de l'Arche | main ou assembleur | 30 s |
| Torchère *(puits)* | 100 de : Hydrogène liquide | — | Torchère | 1 s |

#### Époque 15 · Légende
| Recette | Entrées | Sorties | Machine | Durée |
|---|---|---|---|---|
| Ancre de faille | 4 Condensat d'axions + 4 Plaque étrange + 2 Piège d'antihydrogène + 2 Cristal temporel stable + 10 Superalliage ρ32 + 20 Bobine supraconductrice | 1 Ancre de faille | assembleur | 120 s |
| Captage : faille du Cœur *minage* | 20 Plasma | 5 Matière exotique brute | Ancre de faille | 1 s |
| Stabilisateur de Casimir | 50 Miroir d'iridium + 20 Bobine supraconductrice + 10 Superalliage ρ32 + 50 Processeur | 1 Stabilisateur de Casimir | assembleur | 60 s |
| Cavité de Casimir | 2 Miroir d'iridium + 1 Cristal temporel stable + 1 Bobine supraconductrice | 1 Cavité de Casimir | Salle blanche | 30 s |
| Stabilisation de la matière exotique (500 MW) | 50 Matière exotique brute + 1 Cavité de Casimir [cat. 1] | 1 Matière exotique stabilisée + 1 Cavité de Casimir [cat. 1] | Stabilisateur de Casimir | 60 s |
| Pack exotique | 1 Matière exotique stabilisée + 1 Superalliage ρ32 + 1 Processeur | 5 Pack exotique | Salle blanche | 30 s |
| Porte d'Érèbe | 500 Béton + 50 Superalliage ρ32 + 100 Bobine supraconductrice + 50 Miroir d'iridium + 20 Matière exotique stabilisée + 100 Processeur | 1 Porte d'Érèbe | assembleur | 300 s |
| Segment d'anneau | 2 Matière exotique stabilisée + 1 Superalliage ρ32 + 2 Plaque étrange + 1 Condensat d'axions + 1 Piège d'antihydrogène + 1 Cristal temporel stable | 1 Segment d'anneau | Porte d'Érèbe | 60 s |
| Clé de phase | 10 Matière exotique stabilisée + 10 Miroir d'iridium + 10 Sablier quantique | 1 Clé de phase | assembleur | 120 s |
| Ouverture de la Porte (charge de 30 min sous assaut, 5 GW) *lancement* | 1 Clé de phase + 100 Segment d'anneau | — | Porte d'Érèbe | 1 s |

### 3.5 Contenu vanilla et existant
- **Aucune recette vanilla n'est modifiée** (greffe P7 ; le livre des factions `shared/team/book.lua` et le
  banc `content` restent intacts). Contrôlé : aucune recette nouvelle ne porte un nom vanilla.
- **Phase « brûleur » aux époques 1 et 2 (QX1)** : assembleurs, laboratoire, foreuse électrique et énergie
  électrique vanilla sont rangés à l'époque 3 (« Vapeur : chaudières, machines à vapeur »).
- **Re-rangement complet** : chacune des 259 recettes de base (vanilla réelle, arsenal, modules, centre) a une
  époque dans `X.base_recipe_epochs`, et le banc prouve qu'aucune n'y est anachronique. Points notables :
  - modules 2 et 3 vanilla : époque 10, car ils exigent des processeurs ;
  - modules 4 et 5 du mod : époque 10 (processeurs) ; modules 6 à 10 : époque 14 (pack espace) ;
  - tapis rouges (30/s = T2) : époque 4 ; tapis bleus (45/s, hors modèle) : époque 7, **à trancher par le
    lot C** (retiré ou porté à 60/s) ;
  - robots, roboports, processeurs, LDS, carburant de fusée, artillerie : époque 10 ; silo et satellite : 14.
- **Corrections de l'existant** (`X.existing_overrides`, diff exact au §10) :
  - la **tour à arc** et l'**arc portatif** exigent du cristal de résonance (époque 7) alors que la liste
    validée (§6) place la tour à arc à l'époque 6 : leurs 15 et 10 cristaux deviennent 10 et 5 **bobines**
    (époque 6). La technologie `fo-arc-and-acid` est scindée : arc (6), acide (8) ;
  - `fo-heavy-weapons-2` est scindée : murs blindés et balles explosives (5), tourelle laser lourde (7),
    balles incendiaires (8). Elle demande aujourd'hui le pack utilitaire (époque 10).
- **Contenu existant touché** : arbres et troncs des marais (`world.lua`) donnent en plus 30 % d'échantillon
  de vase ; déchiqueteurs : butin de tissu.

### 3.6 Bilans de chaîne chiffrés (à 100 % de vitesse, calculés sur les recettes du §3.4)

**Époques 2 à 6**
- **Acier** : haut fourneau, 4 fers par acier au lieu de 5 (−20 %) ; le laitier devient du ciment
  (2 laitiers + 1 pierre → 2 ciments) ou, à l'époque 8, absorbe du CO₂ (carbonatation). Four à arc : 3 fers +
  1 graphite.
- **Engrenage forgé** : 1,5 fer par engrenage au lieu de 2 (−25 %), à la vapeur.
- **Plastique** (époque 4) : vapocraquage puis polyéthylène, 30 gaz → 4,5 plastiques au lieu de 3 (+50 %).
- **Fumerolle** : 200 gaz/s, traités par 2 usines chimiques, donnent 140 vapeurs/s, soit 4,7 machines à
  vapeur (**4,2 MW**), plus 2 soufres/s. Infinie.
- **Tungstène** : four, 2 minerais par plaque ; voie humide (11), 1,25 ; concentré ρ8 au four à arc (10),
  1 minerai par plaque.

**Époques 7 à 12**
- **Énergie transportable** : cristal chargé, 20 MJ pour 16 MJ rendus ; cellule SMES, 500 MJ pour 400 MJ
  rendus (80 %), combustible de la locomotive maglev (que la doc limite à un brûleur ou une source vide).
- **Titane** (une plaque ρ8 = 8 MU) : 16 minerais d'ilménite (2 concentrés), 3 cokes, **30 chlores nets**,
  soit 75 saumures ; sous-produits 6 plaques de fer, 30 hydrogènes, 0,75 soude, 0,75 chlorure de magnésium.
  La boucle du magnésium est fermée (2 Mg → 2 MgCl₂ → 2 Mg + 30 Cl).
- **Sels fondus** : cellule de 32 GJ en 200 s = 160 MW ; le sel usé se retraite (centrifugeuse) ou nourrit
  la branche D.

**Époque 13 : fusion**
- 1 réacteur de 800 MW brûle 1 pastille de 80 GJ toutes les 100 s : 0,5 hélium-3/s et 0,5 deutérium/s.
- Hélium-3 : un évent mantellique (4/s) alimente 8 réacteurs ; à défaut, 2,5 fours de dégazage par réacteur
  (l'ilménite dégazée reste fondable), ou la distillation isotopique de l'hélium (0,2/s par unité).
- Deutérium : 0,5 colonne isotopique.
- Électricité : 4 injecteurs (200 MW de chaleur chacun, 40 plasmas/s portés de 15 à 5 000 °C) et 4 turbines
  MHD de 200 MW, pour 160 hydrogènes/s (1,6 reformeur).

**Branches**
- **Matière noire** : 1 haloscope (20 MW) et 2 condenseurs → 0,1 condensat/s → 6 puits → **48 MU/s infinis**.
- **Antimatière** : un réacteur à annihilation, 2 GW de chaleur pour ≈ 0,2 GW de production : **≈ 1,8 GW nets**.
- **Matière étrange** : chaque cuve ajoute 1 strangelet toutes les 30 s ; un transmutateur donne 1 minerai
  rare/s pour 2 pierres/s.

**La Porte (total de fin de partie ; calculé par le banc)**
- **230 matières exotiques stabilisées** (200 pour les segments, 20 pour la Porte, 10 pour la Clé) :
  11 500 matières brutes (38 min avec une ancre) ; 230 min de stabilisateur (environ 1 h avec 4
  stabilisateurs, 2 GW).
- **160 superalliages ρ32** (5 120 MU) : 480 ferronickels, 640 météorites ferreuses ρ8.
- Miroirs d'iridium : 50 (Porte) + 10 (Clé) + 50 par stabilisateur + 2 par cavité, soit 268 avec 4
  stabilisateurs ; 536 iridiums, soit 2 144 météorites concassées ou 11 sondes profondes.
- Branches consommées : 104 condensats, 102 pièges d'antihydrogène, 102 cristaux stables (+ 4 pour les
  cavités), 204 plaques étranges.
- Charge : 5 GW pendant 30 min (9 TJ).

---

## 4. Liens avec la Compaction, l'énergie, les niveaux, la recherche et la boucle idle

### 4.1 Compaction ×4 (BALANCE_SHEET §3 ; un palier toutes les 3 époques, Q5)

| Palier | Époque | Tapis | ρ | Forme dense | Ce que les époques y apportent |
|---|---|---|---|---|---|
| T1 | 1 | 15/s | 1 | plaque (vanilla) | — |
| T2 | 4 | 30/s | 2 | « paquet » | tapis rouge vanilla |
| T3 | 7 | 60/s | 4 | « lingot » | — |
| T4 | 10 | 120/s | 8 | « billette » ou « concentré » | **concentrateur** accolé à la foreuse lourde (8 minerais → 1 concentré ρ8 en 1 s, insertion directe) ; four à arc : concentré → billette ρ8 ; découpe : billette → 8 plaques |
| T5 | 13 | 120/s | 32 | « bloc » | **fonderie à plasma** : 4 concentrés ρ8 + 20 plasmas → 1 bloc ρ32 ; découpe : bloc → 4 billettes |

- **Règle anti-explosion + « densité née du palier »** (P4, `X.dense_forms`) : une matière née à l'époque e
  avec la densité ρ n'existe qu'en ρ et aux densités des paliers **strictement** supérieurs au sien. Le fer
  existe en ρ1, 2, 4, 8, 32 ; le plastique (né en T2) en ρ1, 4, 8, 32 ; le **titane, l'ilménite et la
  monazite naissent en ρ8** (puis ρ32) ; le **superalliage naît en ρ32**. Une foreuse 1.1 ne transforme pas
  ce qu'elle extrait : d'où le concentrateur en insertion directe.
- **Recettes denses** : les recettes marquées *(dense)* recevront du lot C **48 variantes**, plus les
  intermédiaires denses ρ8 et ρ32 (engrenage, câble, circuit, circuit avancé, processeur, tuyau), calibrés à
  3,75 objets/s par machine. La Compaction des plaques (ρ1 → ρ2 → …) reste la conception du lot C.
- **Jamais de productivité** sur la compaction, la décompaction, la catalyse, la conversion ni la
  transmutation (BALANCE §6 ; contrôlé par le banc).
- Le puits gravitique (A) est une « foreuse de concentré » de branche ; la ligne principale garde le
  concentrateur, sans branche.

### 4.2 Énergie : chaque palier arrive avec sa source

| Source | Époque | Puissance | Combustible | Comparaison (MW par tapis, BALANCE §3) |
|---|---|---|---|---|
| Vapeur | 3 | 1,8 MW par chaudière | charbon, coke | T1 : 4,3 MW |
| Géothermie | 5 | 4,2 MW par fumerolle, infinie | — | T2 : 13,8 MW, soit 3,3 fumerolles |
| Cristal chargé | 7 | 1 MW par générateur, hors réseau | stockage à 80 % | avant-postes |
| Turbine à gaz | 8 | 10 MW | 6,7 méthanes/s | T3 : 44,2 MW, soit 4,4 turbines |
| Fission (vanilla) | 9 | 40 MW, +100 % par voisin | cellules d'uranium | T3 : environ 1 réacteur |
| Sels fondus (thorium) | 12 | 160 MW | cellule de 32 GJ | T4 : 141,6 MW, soit **1 réacteur par tapis** |
| Accumulateur supraconducteur | 12 | 200 MJ et 50 MW | — | lissage |
| Fusion D–³He et MHD | 13 | 800 MW | pastille de 80 GJ | T5 : 453 MW, soit 1 réacteur pour 1,8 tapis |
| Orbitale | 14 | 50 MW par centrale lancée | — | appoint |
| Annihilation (B-III) | 14 ou 15 | 2 GW (1,8 net) | piège de 50 GJ | 4 tapis T5 |

- **Règle d'énergie (P5, contrôlée)** : un combustible fabriqué rend moins que ce qu'il coûte (combustibles
  des ingrédients + énergie de la machine), sauf une **liste blanche écrite** : fission (sel au thorium),
  fusion (pastilles), annihilation (fiction déclarée), méthane de digesteur (entrée = butin de combat).
- L'**hydrogène, l'éthylène et l'ergol cryogénique n'ont aucune valeur de combustion** : sinon électrolyse
  puis combustion créeraient de l'énergie. Les fluides vanilla n'en ont pas non plus en 1.1.91 ; la turbine
  à gaz brûle le méthane du mod (1,5 MJ par unité).

### 4.3 Niveaux des bâtiments (V2), monnaies d'époque, ouvriers
- Centre de commandement : niveau = époque (1 à 15). Bâtiments : niveau maximal = 2 × niveau du centre (Q6).
- Les **monnaies d'époque** (§3.1) remplacent la liste actuelle des matériaux de palier (BALANCE §12). Les
  niveaux 2e−1 et 2e d'un bâtiment coûtent la monnaie de l'époque e, plus les monnaies plus anciennes.
- **Ouvriers** : 1 à 5 (un de plus toutes les 3 époques), +1 avec l'Horloge éternelle.
- **Chantiers de zone** (greffe P3, à valider par V2, `X.zone_upgrade`) : un ouvrier améliore jusqu'à 10
  bâtiments identiques dans un rayon de 20 tuiles, durée ×(1 + 0,1 × (N − 1)), coût ×N ; familles de
  production seulement, les défenses restent à l'unité.
- Le **sablier quantique** (C-II) agit sur les chantiers ; le lot I (idle) s'y branche.

### 4.4 Recherche
- **Packs** : 7 vanilla (automatisation 1, logistique 2, militaire 3, chimique 4, production 6, utilitaire 10,
  espace 14) et 8 nouveaux (géologique 5, résonance 7, biochimique 8, isotopique 9, structurel 11, magnétique
  12, plasma 13, exotique 15), plus 4 données de branche.
- **Fenêtre glissante** (greffe P2, `X.pack_window`) : jamais plus de 4 sortes de packs par technologie. Le
  laboratoire accepte tous les packs (`lab.inputs`, `data-final-fixes`), mais aucun mur de 19 packs.
  L'affichage d'un laboratoire à 19 entrées est **non vérifié**. Le laboratoire à combustion n'accepte que
  les packs rouge et vert.
- **Volume** (estimation, non comptée) : environ 110 technologies d'époque, 32 de branche, 8 infinies, 14
  verrous `fo-epoch-k`, plus environ 190 technologies vanilla re-rangées (packs réécrits selon la fenêtre).

### 4.5 Boucle « presque idle » (E3)
- E3-1 (l'usine nourrit le centre) : existant.
- E3-2 (score de puissance) et E3-3 (objectifs et récompenses par époque) : jalons, caisses, crédits
  d'accélération, médailles, score (§3.1). Données prêtes ; rien n'est implémenté.
- E3-4 (file de chantiers) : au lot I ; les chantiers de zone et les sabliers s'y raccordent.
- Branche C : la seule branche dont la mécanique est « idle » par nature (dilatation, sabliers).

---

## 5. Contraintes moteur 1.1.91 et volume

### 5.1 Faisable par prototypes (schéma vérifié dans `doc-html/prototype-api.json`)
- Ressources infinies (`infinite`, `minimum`, `normal`) ; combustibles à résidu (`burnt_result`) ; charges
  utiles de fusée (`rocket_launch_products`) : l'orbite se joue sans seconde surface.
- Machines à énergie chaleur ou fluide (`EnergySource` : `heat`, `fluid`) ; générateur `burns_fluid` ;
  `ReactorPrototype` (« May not be a heat energy source » : brûleur, vérifié) ; il n'existe pas de
  `FusionReactorPrototype` ni de `SpoilablePrototype` en 1.1.91 (absents, relu par le banc).
- Recette sans ingrédient et recette sans produit permises en toutes lettres (relu par le banc).
- `LinkedContainerPrototype`, `BurnerGeneratorPrototype` (générateur à cristal) existent.
- Silo réutilisable pour la Porte : `fixed_recipe`, `rocket_parts_required` (uint32).
- Pylône : `maximum_wire_distance` 64 au plus. Locomotive : brûleur ou `void` seulement.

### 5.2 Faisable par script (API runtime vérifiée dans `doc-html/runtime-api.json`, coût à mesurer)

| Système | API | Fréquence | Coût attendu |
|---|---|---|---|
| Verrou d'époque | `LuaTechnology.researched` (écriture) | à chaque niveau du centre | nul |
| Serment | `LuaTechnology.enabled` (écriture), `set_cease_fire`, `set_friend` | une fois | nul |
| Marée | `LuaEntity.amount` (écriture) | 600 ticks, table de 24 phases | O(tuiles de veine) |
| Veines | `on_sector_scanned`, `create_entity` | à chaque secteur balayé | faible |
| Remontées, failles | `create_entity` d'une ressource | à la pose, au réveil | nul |
| Dilatation | balise cachée selon `status` (`speed_bonus` en lecture seule) | 60 ticks | O(chambres) |
| Confinement, contagion | `energy`, `status`, `set_tiles`, dégâts | 60 ticks | O(bâtiments à risque) |
| Rectennas | `power_production` (écriture) | à chaque lancement ou pose | nul |
| Pluies de météorites, déviation | `create_entity` | toutes les 20 à 40 min | pic ponctuel |
| Fenêtre d'évolution | `LuaForce.evolution_factor` (écriture) | 3 600 ticks | nul |
| Perturbation | `item_production_statistics.get_input_count` | 36 000 ticks | nul |
| Merveilles, médailles | `mining_drill_productivity_bonus`, `laboratory_speed_modifier`, `manual_crafting_speed_modifier` (écriture) | à la pose | nul |
| Porte et Marée du Cœur | `on_rocket_launched`, directeur des vagues, `set_game_state` | événement | celui des vagues (E19 : 0,06 ms) |

- **Nouvelle hypothèse H-X1 · OUVERTE** : l'ensemble des systèmes X coûte au plus 0,05 ms/tick en moyenne
  à l'époque 15 avec une base de fin de partie. À mesurer au banc épinglé (budget A1).

### 5.3 Infaisable ou contourné
- **Pas de péremption** en 1.1.91 : demi-vie du cuivre activé, instabilité de l'antimatière et des
  strangelets remplacées par des **risques portés par les bâtiments** (confinement, contagion).
- **Pas de bonus de vitesse ni de productivité par entité fixé par script** : la dilatation passe par une
  balise cachée.
- **Pas d'interception de projectile par tourelle** : le bouclier de déviation est scripté.
- **Pas de seconde surface** (station orbitale exclue ; possible plus tard).
- **Fluides 1.1** : le débit chute avec la longueur des conduites ; plasma et flux sombre restent locaux.
- Tapis : plafond H-B1 de 120/s ; 1 fabrication par tick et par machine (aucune recette n'en approche).

### 5.4 Ce que le banc impose aux données (limites moteur, §6)
Quantités d'objets entières de 1 à 65 535 ; durée > 0,001 s ; aucun ingrédient en double ; aucun fluide en
catégorie `crafting` ; un seul objet d'entrée par four ; nombre de boîtes de fluide de la machine suffisant ;
probabilités dans ]0, 1] ; noms sans point, 200 caractères au plus ; pylônes et balises ≤ 64 ; bâtiments
≤ 10×10 (Q9).

### 5.5 Volume de contenu (compté par le banc, sauf mention)

| Catégorie | Nombre | Détail |
|---|---|---|
| Objets nouveaux | **121** | dont 8 packs, 4 données de branche, 14 Codex, 11 formes denses (concentrés, billettes, blocs) |
| Fluides nouveaux | **19** | gaz volcanique, éthylène, hydrogène, oxygène, CO₂, saumure, chlore, TiCl₄, azote et oxygène liquides, hélium, hélium liquide, flux sombre, hélium-3, eau lourde, deutérium, plasma, hydrogène liquide, matière exotique brute |
| Bâtiments nouveaux | **69** | 13 et 14 en tête (12 et 11) |
| Recettes réelles | **242** | 156 de fabrication, 69 de bâtiments, 17 de torchère |
| Pseudo-recettes | **29** | 15 minages ou captages, 7 combustions, 4 lancements, 1 cueillette, 1 butin, 1 chauffe |
| Variantes denses (lot C) | **48** | plus les intermédiaires denses |
| Ressources de carte | **11** | dont 4 posées par script ou événement |
| Tuiles et biomes | **5** | asphalte, champs de cratères, sables noirs, sol étrange, abysse du Cœur |
| Technologies | ≈ 164 (estimation) | plus environ 190 technologies vanilla re-rangées |
| Unités | ≈ 7 | 3 soldats d'époque, 4 élites |
| Systèmes de script | **14** | `X.systems` |
| **Prototypes au total** | **≈ 800 de plus** (estimation) | 496 aujourd'hui |
| Graphismes | — | 69 bâtiments (sprite haute résolution, ombre, lueur, icône), dont 3 merveilles 9×9 et deux 10×10 ; environ 140 icônes d'objets et de fluides ; 11 jeux de gisements ; 5 jeux de tuiles. Une première version peut recomposer des pièces vanilla ; D1 exige ensuite des formes propres (V0), et les règles visuelles des branches sont dans la bible V1 (§1.10) |

---

## 6. Vérification hors jeu

`lua5.2 tests/epochs_test.lua [chemin de prototype-api.json]` depuis la racine du mod. Résultat le 21/10 :
**12 312 OK, 0 ECHEC(S)**. Sections :

1. **Sources moteur** : relit dans `doc-html/prototype-api.json` (trouvé automatiquement depuis la racine du
   mod ou d'un worktree) les 13 phrases citées dans `X.DOC_PHRASES`, la version 1.1.91, et l'absence de
   `SpoilablePrototype` et `FusionReactorPrototype`. Si la doc est absente, ces contrôles sont sautés et le
   banc le dit.
2. **Structure, noms, traductions** : tableaux purs, préfixe `fo-`, unicité, aucune collision avec un nom
   vanilla ou existant, noms FR et EN partout.
3. **Graphe complet** : vanilla réelle (`tests/fixtures/recipes.lua`), arsenal et modules relus dans
   `shared/content/`, centre, corrections proposées ; chaque recette a une machine ; point fixe des époques
   (trié, déterministe, recalculé deux fois) : 0 infranchissable, 0 anachronisme.
4. **Époques** : ressource ou matériau et bâtiment par époque (F1-2), pack et monnaies disponibles, Codex,
   jalons, fenêtre de packs, durées (F1-3), paliers (Q5), ouvriers, niveaux (Q6), Compaction conforme à
   `shared/balance_model.lua`.
5. **Branches** : niveaux, Serment, recettes propres par niveau, donnée de recherche, produit de la Porte,
   indépendance de la ligne principale, doctrines réciproques, marée.
6. **Règles de production** : chaque objet a une source et un débouché (recette, torchère ou usage) ;
   productivité seulement sur des intermédiaires simples sans boucle ; `catalyst_amount` égal des deux côtés ;
   énergie (P5) ; **MU ≥ 0,75 × ρ** pour toute matière en vrac (P2).
7. **Compaction** : formes denses (P4).
8. **Limites moteur** par recette et par bâtiment (§5.4), catégories de minage, combustibles et résidus.
9. **Factions, difficulté, évolution** ; **la Porte** (230, 11 500, 100 segments, 5 GW).

**Défauts trouvés par le banc pendant la rédaction, et corrigés.**
- Dans les données (7) : le personnage ne minait pas à la main (tout le vanilla semblait infranchissable) ;
  modules 2 vanilla rangés à l'époque 7 alors qu'ils exigent des processeurs ; distillation de l'hélium non
  déclarée catalytique ; four de frittage sans sortie de fluide pour le dégazage ; **ferronickel tiré d'une
  météorite étrange (1 MU en donnait 8)** ; **pierre bon marché tirée de la même météorite, qui rendait la
  transmutation et le verre « gratuits » en MU** ; torchère du flux sombre classée hors branche.
- Dans le banc lui-même (4) : catégorie de munition prise pour une catégorie de recette ; MU des fluides
  porteurs (TiCl₄) comptés nuls avant leur calcul ; JSON compact de la doc non reconnu ; règle d'époque des
  recettes de niveau II trop stricte pour une variante plus tardive.

---

## 7. Corrections apportées à la proposition gagnante, greffes intégrées

**Incohérences corrigées**
1. **Modules** : la proposition rangeait les modules 4 et 5 à l'époque 7 ; ils exigent des processeurs
   (époque 10). Les modules 2 et 3 vanilla aussi.
2. **Tour à arc** : anachronisme à l'époque 6 (cristal de l'époque 7, relevé par les deux juges) ; recette
   corrigée en bobines et technologie scindée (§3.5).
3. **QX4 supprimée** : plus aucune recette vanilla modifiée ; des variantes à la place (chaudière et
   réacteur nucléaire : modifications abandonnées).
4. **Carburant cryogénique** : il produisait du carburant de fusée vanilla (100 MJ) pour environ 24 MJ
   investis, soit de l'énergie gratuite. Remplacé par un **ergol cryogénique** sans valeur de combustion,
   réservé au remorqueur orbital.
5. **Météorite étrange** : concassée, elle donnait du ferronickel et de la pierre « gratuits » (trouvé par la
   règle des MU) ; elle devient ρ8 et ne donne plus de ferronickel.
6. **Tailles** : la Porte passe de 13×13 à **10×10** (Q9) ; le réacteur à annihilation de 5×5 à **10×10**
   (exemple donné par le Directeur Créatif à Q9).
7. **Calendrier** : 66 h annoncées pour la Porte, au-delà des 60 h de F1-3 ; désormais **59,5 h**.
8. **Puits gravitique II** : des blocs ρ32 de chaque minerai rare auraient multiplié les objets ; il sort 4
   concentrés ρ8/s (même débit matière, 32 MU/s).
9. **Densité** : titane, ilménite, monazite (ρ8) et superalliage (ρ32) naissent denses ; les quantités des
   recettes sont recalibrées (un composite = ½ plaque de titane ; superalliage divisé par 3 à 10).
10. **Injecteur de plasma** : 40 plasmas/s par 200 MW (cohérent avec 1 kJ/°C), non 10.
11. **Comptes** : 93 objets, 18 fluides et 58 bâtiments annoncés (104, 19, 59 selon le script du juge) ;
    ici 121, 19 et 69, **comptés par le banc**, greffes comprises.
12. **Torchère** : le doute sur une recette sans produit est levé par la doc ; reste non vérifié le choix
    automatique de la recette par le fluide entrant (§8).

**Greffes intégrées** (juges 1 et 2)
- Verrou d'époque natif `fo-epoch-k` (P3).
- Fenêtre d'évolution bornée par l'époque, combinée à la Perturbation et au palier des vagues (P3).
- Table de difficulté complète, chantier de Porte des factions pillable à 30 %, économie d'archive hybride
  (P3).
- Gabarit d'époque : Codex, lot de 10 %, 5 jalons, caisses, crédits, médaille, score de puissance (P3).
- Chantiers de zone, à remonter au lot V2 (P3).
- Butin de tissu : inoculum et méthane de digesteur (P3).
- Densité née du palier, concentrateur en insertion directe, intermédiaires denses (P2).
- Règles P3, P5, P7 dans le banc : débouchés, productivité, énergie, MU, unicité, FR et EN (P2).
- Fenêtre glissante des packs (P2).
- Branche D puits universel des déchets ; piscine d'entreposage et dépôt géologique à l'époque 9 (P2).
- Coffres intriqués en récompense C-II ; tapis intriqué écarté (juge 2).
- Fusion catalysée par l'antimatière ; `meltdown_action` natif pour la destruction du réacteur (P2).
- Hélium-3 en ressource de carte : évents mantelliques (P2).
- Courbe de budgets en MU et passage du centre en MU, prêts pour V2 (P2).
- Ouverture de la Porte sous 5 GW (P3).
- Époques 12 à 14 étalées : la branche C passe au niveau II dès l'époque 11 (P2, P3).
- Veines posées par `on_sector_scanned` (juge 2).
- Énergie transportable : cristal chargé, cellule SMES pour la maglev (juge 2).
- Époque 4 étoffée : vapocraquage, éthylène, polyéthylène (faiblesse relevée par le juge 1).

---

## 8. Ce qui n'est pas vérifié

- **Tout, en moteur réel** : aucun prototype n'existe ; aucun banc `content` ne couvre ce contenu.
- Les **débits** réels et l'**équilibrage fin** (seuls les ratios du §3.6 sont calculés, à la main et par
  le banc pour la Porte).
- La physique des **fluides** en conduite (plasma, flux sombre).
- Le choix automatique d'une recette de **four par le fluide entrant** (torchère ; précédent connu : le mod
  « Flare Stack », non vérifié ici ; repli : `assembling-machine` à recette choisie).
- Les machines alimentées par la **chaleur** (irradiateur) ou par la **vapeur** (marteau-pilon).
- La chaîne de chaleur à **5 000 °C** (réacteur à fusion, injecteur de type chaudière).
- Une **foreuse à entrée et sortie de fluide** sur une ressource fluide (ancre de faille).
- Une foreuse qui détecte une **ressource créée par script après sa pose** (puits gravitique).
- L'effet de la **réécriture de `amount`** sur le rendement d'une ressource infinie (marée), et la
  convention `daytime` (0 à midi) utilisée par la table de marée.
- Qu'un **brûleur sans case de résidu refuse** un combustible à `burnt_result` (le banc impose la case par
  prudence).
- L'**affichage** d'un laboratoire à 19 entrées ; un pylône à zone d'alimentation de 0,5.
- L'application de `ModulePrototype.limitation` aux **balises** (dilatation, interdiction de productivité).
- Le **coût de script** (H-X1 ≤ 0,05 ms/tick).
- Les **IA** au-delà de l'époque 4 (H-E1) : l'économie d'archive reste en partie une imitation.
- Le **coût graphique** (69 bâtiments en formes propres, D1).
- Les **traductions** : les noms FR et EN sont dans les données ; les fichiers `.cfg` appartiennent aux lots
  X1 à X15.
- La copie du projet claude.ai (`claude/*.md`) n'est **pas** mise à jour par ce lot.

---

## 9. Ce qui reste à décider par le Directeur Créatif

- **QX1** : une phase « brûleur » aux époques 1 et 2, l'électricité n'arrivant qu'à l'époque 3 (Vapeur),
  comme le dit le §6. Est-ce acceptable ?
- **QX2** : le Serment, soit une seule maîtrise (III) avant l'époque 15, les niveaux I et II restant
  cumulables. Est-ce acceptable ?
- **QX3** : en Difficile et en Impitoyable, une faction qui ouvre sa Porte avant vous fait perdre la partie
  (« course à la Porte »). Est-ce acceptable ?
- **QX4** : l'antimatière. (a) Garder **≈ 1,8 GW nets par réacteur**, rendement positif déclaré fictif et
  expliqué par la Caustique ; ou (b) l'antimatière n'est qu'un **stockage à 53 %**, la fusion catalysée
  restant la seule source nette (modèle « ni énergie gratuite » de la proposition P2). Proposition : (a).
- **QX5** : les noms Érèbe, Caustique, Cœur, Convoi, Compagnie et Porte vous conviennent-ils ?

---

## 10. Pour l'intégrateur

Ce lot n'a modifié **aucun fichier partagé**. Diffs et textes proposés :

**1. `shared/content/arsenal.lua`** (à appliquer **avec le lot X6**, quand la bobine `fo-coil` existe en jeu ;
d'ici là, la tour à arc reste de fait à l'époque 7) :
```diff
@@ A.special_turrets, fo-tesla-turret (l. 138)
-    ingredients = { { "laser-turret", 1 }, { "fo-resonance-crystal", 15 }, { "copper-cable", 60 }, { "advanced-circuit", 10 } },
+    ingredients = { { "laser-turret", 1 }, { "fo-coil", 10 }, { "copper-cable", 60 }, { "advanced-circuit", 10 } },
@@ A.special_guns, fo-arc-gun (l. 190)
-    ingredients = { { "submachine-gun", 1 }, { "fo-resonance-crystal", 10 }, { "battery", 10 } },
+    ingredients = { { "submachine-gun", 1 }, { "fo-coil", 5 }, { "battery", 10 } },
```
Le banc affiche un « AVIS » tant que cette correction n'est pas intégrée. Technologies à scinder
(`prototypes/arsenal.lua`, `prototypes/arsenal_special.lua`) : `fo-arc-and-acid` (arc 6, acide 8),
`fo-heavy-weapons-2` (5, 7, 8) ; détail dans `X.existing_tech_epochs`.

**2. `OBJECTIFS.md`**
- F1-6 : « 🟨 conception livrée (lot X0, `docs/SCENARIO_EPOQUES.md`, `shared/content/epochs.lua`) ; graphe
  vérifié hors jeu (`tests/epochs_test.lua` : 12 312 OK, 0 échec) ; rien en moteur réel ».
- §4 : questions QX1 à QX5 (§9 ci-dessus) ; §7 : suivi du lot X0.
- C2 : écrire que les époques des IA au-delà de 4 sont une économie d'archive en partie imitée.

**3. `RD_LOG.md`** : hypothèse **H-X1** (§5.2) ; décision « QX4 supprimée : variantes au lieu de
modifications vanilla » ; les 9 défauts trouvés par le banc (§6) comme expérience hors jeu.

**4. `BALANCE_SHEET.md`** : nouvelle section « Époques » (calendrier §3.1, énergie §4.2, bilans §3.6,
difficulté §1.4, fenêtre d'évolution).

**5. `ARCHITECTURE.md`** : `shared/content/epochs.lua` et `tests/epochs_test.lua` dans l'arborescence ;
verrou `fo-epoch-k` et systèmes X (§5.2). **`CLAUDE.md` §5** : `lua5.2 tests/epochs_test.lua -> 12 312 OK`.

**6. `changelog.txt`** : « Lot X0 : scénario, 15 époques, 4 branches avancées, arbres de fabrication
(données et banc hors jeu) ».
