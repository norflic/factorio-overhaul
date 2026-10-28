# Portes des mesures fonctionnelles (lot MESURES)

Écrit le 28/10/2026 AVANT toute mesure de ce lot, versionné avec les outils (branche `mesures`, parent exact `main`
7da63d9). Il répond à l'exigence du DC : les vérifications comptaient des choses posées (« 54 fours » en carré, remplis
à la main) et le raisonnement qui les entourait avait des biais (audits `audit_mesures`, `audit_garde_fous`,
`audit_refus`, 28/10). Ici : ce que chaque indicateur prouve, ce qu'il ne prouve PAS, et la règle qui interdit de
choisir un seuil après avoir vu le résultat.

## 1. Règles du protocole (tenues par ce lot, à reprendre par les lots IA)

1. **Aucune porte dans ce lot.** Les lignes `[FO-FONCTION]` ne sont dans aucun BILAN. Aucun seuil de réussite n'est
   écrit ici : le tableau §4 dit seulement QUAND et SUR QUOI un seuil pourra être fixé.
2. **Deux jeux de graines distincts.**
   - Graines de JUGEMENT (celles du DC et des bancs, déjà vues par beaucoup de réglages) : `20261020`, `123456789`,
     `271828182`, `1618033988`. Elles ne servent JAMAIS à fixer un seuil.
   - Graines de RÉGLAGE : `314159265`, `577215664` (citées dans les commentaires de plusieurs bancs : ce ne sont donc pas
     des graines vierges, dit tel quel) et `141421356` (jamais citée : `git grep` sur le dépôt et recherche dans les
     `seed.txt` des archives, 0 occurrence au 28/10). Un seuil se fixe sur la distribution lue sur ces 3 graines au
     moins, écrit dans ce fichier avec sa date et le commit mesuré, PUIS le lot est jugé UNE fois sur les 4 graines de
     jugement.
3. **Témoin = parent exact du lot** (`git merge-base`), rejoué à chaque série, dans la même configuration (même
   scénario `etape1-guide`, 30 ouvriers, réglages livrés). Jamais une branche voisine.
4. **Essai A/A** : un changement sans effet voulu (ici : les outils de mesure seuls, `script/` et `shared/` intacts)
   rejoué sur les mêmes graines. Il donne la taille du bruit propre à la mesure et prouve qu'elle ne perturbe pas la
   partie (F238 : même code, même résultat ; F252 : tout changement de décision diverge).
5. **Distributions, pas maxima.** Tout rapport donne médiane, plage et nombre de forces, avec la liste des graines. Un
   résultat sur une graine n'est jamais une conclusion (F252, F382).
6. **Force morte.** Une force sans aucun corps de PNJ (`morte=1`) est listée, marquée, et exclue des médianes ; la
   médiane de parité ne porte que sur les factions vivantes (une équipe morte garde des comptes figés, audit §3.4).
7. **Un lot qui allume un comportement journalise un compteur de déclenchement** (hors de ce lot : ici rien n'est
   allumé).
8. **Définitions fixées avant lecture** (constantes de `fonction_common.lua`, non des seuils de réussite) : relevé d'état
   toutes les 30 s ; four « actif 50 % » = production de la fenêtre ≥ la moitié de sa cadence nominale ; tapis « plein »
   ≥ 7 objets sur la tuile ; machine « inactive » = ≤ 20 % de relevés `working` sur ≥ 5 relevés ; tourelle « armée »
   ≥ 5 chargeurs ; population productive = fours vus ≥ 3 relevés. Les changer après lecture exige de rejouer et de le
   consigner avec les deux versions.
9. **Un essai de débogage a eu lieu avant ce fichier** : `micro1` (graine 20261020, 36 100 ticks, une fenêtre de 10 min,
   seulement pour vérifier que les lignes sortent sans erreur moteur). Aucun seuil n'en est tiré.

## 2. Ce que lit chaque indicateur (genre de ligne `[FO-FONCTION]`)

Un « relevé » est un instantané pris toutes les 30 s ; la fenêtre est de 10 min (≈ 20 relevés), fermée à 10, 20, …
60 min. Toutes les forces (votre équipe et les factions) passent par la MÊME fonction.

| Indicateur (ligne : champs) | Ce qu'il PROUVE | Ce qu'il ne prouve PAS |
|---|---|---|
| **Fours** (`fours` : `n_auto`, `n_coffre`, `n_main`) : alimenteur structurel | Combien de fours ont une foreuse dont le `drop_target` est le four, ou un bras qui y dépose depuis un tapis, ou depuis un coffre lui-même alimenté par une foreuse/un bras sur tapis (un niveau). `main` = aucun alimenteur : posé et servi à la main. | Que le minerai arrive vraiment (un bras sur tapis vide compte « alimenté » : voir `ws`, `a50`). Que le tapis amont aboutisse à du minerai. Les chaînes de plus d'un coffre. Le combustible (suivi par le `statut`). |
| **Fours** (`prod_*`, `a50_*`, `eq_*`, `nom_*`) | Production RÉELLE de chaque four (delta de `products_finished` sur la fenêtre, lu sur la machine), contre sa cadence nominale (`crafting_speed` ÷ 3,2 s, en équivalents-plaque). Sépare alimentés / servis à la main. | Que la production serve à quelque chose (une plaque qui s'entasse est une plaque). Les fours détruits en cours de fenêtre, les fours vus < 3 relevés (comptés dans `jeunes`). |
| **Production de la force** (`prod`) | Plaques, acier, minerai, engrenages, circuits, packs fabriqués (machines) et consommés (labos) aux statistiques de production du moteur, par minute. `fours_equivalents` = plaques-équivalents ÷ cadence d'un four. | Les objets fabriqués à la main par un PNJ n'y sont pas (F319) : ils restent au décompte `main {…}` d'`[FO-IA3E]`, séparé. Le minage à la main d'un personnage entre-t-il dans les statistiques : NON VÉRIFIÉ en moteur. `insert_at_back` par script n'y est pas (F244). |
| **Statuts** (`statut` : histogramme par classe) | Part des relevés où la classe (four, foreuse électrique / à combustion, bras électrique / thermique, assembleur, labo, tourelle, générateur, chaudière) est `working`, `no_power`, `no_fuel`, `no_ingredients`, `no_minable_resources`, `waiting_for_space_in_destination`, `no_ammo`, etc. | Un état de moins de 30 s échappe ; un PNJ qui visite une machine juste avant le relevé la fait paraître saine. `waiting_for_source_items` d'un bras est un état sain, pas une preuve de débit. |
| **Foreuses** (`statut` classes `foreuse_*`) | Électriques séparées des thermiques ; part qui travaille, sans courant, sans combustible, épuisées, à sortie bouchée. Les pompes (`pumpjack`) sont à part (classe `pompe`). | Que le minerai extrait soit utile ; la couverture du gisement (relevée ailleurs : `capi_common.lua`). |
| **Électricité** (`elec`) | kW générés (moyenne des relevés de `energy_generated_last_tick`), part des poteaux dans le réseau d'un générateur (`electric_network_id`), nombre de réseaux de poteaux, et par classe de consommateur (foreuses électriques, bras électriques, assembleurs, labos) : posés, dans le réseau d'un générateur, alimentés (réseau du générateur ET état ni `no_power`, ni `low_power`, ni `not_plugged_in_electric_network`). | Que la centrale tienne la charge en pointe (la moyenne de relevés isolés lisse ; `low_power` est lu au relevé). Les panneaux solaires et accumulateurs (seuls les `generator` sont des producteurs ici). |
| **Bras** (`bras`, `statut` classes `bras_*`) | Électriques séparés des thermiques (un `burner-inserter` ne compte pas comme électrique) ; bras avec une cible de prise ET une cible de dépôt ; histogramme d'états. | Le nombre d'objets déplacés par bras (l'API n'a pas de compteur par bras). |
| **Tapis** (`tapis`) | Part des tapis EN AMONT d'une prise de bras (remontée depuis chaque `pickup_target` par `belt_neighbours`, souterrains compris) ; part des tuiles pleines qui ne servent à aucune prise ; culs-de-sac pleins sans prise. | Que le tapis porte la bonne matière ; les tapis dont le seul consommateur est un autre mécanisme (chargeur, répartiteur hors de cette force) ; un cul-de-sac plein qui est la FIN voulue d'une ligne (stockage tampon) est compté « inutile ». |
| **Tourelles** (`tourelles`) | Tourelles à munitions (`ammo-turret`) vides / faibles (< 5 chargeurs) / armées, munitions réelles dans l'inventaire. | Les tourelles laser (`electric-turret`), la couverture (portée contre bâtiments), l'utilité (une tourelle armée posée loin de tout). |
| **Corps de PNJ** (`corps`) | Part des relevés où chaque corps mine à la main, fabrique, se déplace (> 1 tuile depuis le relevé précédent), ou est INERTE (immobile, ni minage ni fabrication) ; `inactifs_mod_pct` du mod (task nil) à côté. | Qu'un corps qui marche accomplit quelque chose (il peut marcher pour rien : F239, F251). Que la tâche du PNJ ait un effet : la valeur créée se lit à `plaques_par_pnj_min`, indirectement. Le personnage connecté d'un joueur est exclu. |
| **Dormants** (`dormants`) | Stock NON posé : fours, foreuses, assembleurs, labos, bras dans le coffre (QG ou coffre d'équipe), les annexes et les inventaires des corps. Capital POSÉ inactif : machines à ≤ 20 % de relevés `working` sur ≥ 5 relevés. Assembleurs avec recette / ayant produit. | La valeur en objets (non pondérée par le coût : comptes par catégorie). Les objets hors du rectangle des annexes ou des inventaires de corps (conteneurs ailleurs). Un four légitimement à l'arrêt (matière absente en amont) est « inactif » : c'est le sujet de la mesure, pas une erreur. |
| **Recherche** (`tech`) | `researched` (technologies terminées) lu par la MÊME fonction pour toutes les forces, et depuis le début de la partie ; packs fabriqués / consommés. La colonne `tech=` de `[FO-ETAPE1-GUIDE] base` suit la même fonction ; le palier du plan des factions est `palier=`. | Que les technologies terminées aient un effet lu (leviers : mesuré ailleurs). Technologies marquées terminées par script au départ : comptées (la différence « depuis le début » les retire en partie). |
| **Parité** (`parite`) | Joueur contre la MÉDIANE des factions vivantes (et min, max, nombre de vivantes), par indicateur ; équipe morte signalée (`joueur_vivant=0`). | Rien sans plancher absolu : la médiane seule dit « au niveau de », pas « suffisant ». Le plancher se fixe après distribution (§4). |

## 3. Biais connus de la mesure elle-même

- Échantillonnage : 20 relevés par fenêtre ; une machine qui oscille plus vite que 30 s n'est lue que statistiquement.
- Les factions naissent après le tick 0 : leur fenêtre initiale est un peu plus courte (9,5 min contre 10 pour votre
  équipe) ; tous les débits sont par minute.
- `products_finished` ne voit que les machines posées et vivantes au rapport ; un four détruit puis rebâti compte comme
  « jeune ».
- Les forces dont les fours sont servis par des PNJ (classe `main`) peuvent légitimement produire : la mesure SÉPARE
  « posé et servi à la main » de « alimenté », elle ne dit pas que servir à la main est mauvais. C'est le DC qui décide
  (D-24) ce que doit être une base.
- Les relevés ne modifient rien dans la partie (lectures seules ; vérifié par l'essai A/A du §5).

## 4. Quand et comment fixer un seuil

| Étape | Condition | Qui écrit |
|---|---|---|
| 1. Lire la distribution sur les 3 graines de RÉGLAGE | `tools/autotest/fonction_mesures.py` sur les archives de réglage ; médiane, min, max, par indicateur et par minute | Ce fichier, §6, avec date, commit et chemins des archives |
| 2. Proposer un seuil par indicateur | Écrit AVANT de regarder les graines de jugement ; effet minimal supérieur au bruit mesuré (§5, A/A) | L'agent du lot qui en a besoin ; décision du DC |
| 3. Juger sur les 4 graines de jugement | Une seule fois ; médiane et plage ; pire graine citée ; forces mortes listées | Le rapport du lot |
| 4. Tout changement de seuil ou de définition | Les deux versions et leur résultat sur les mêmes archives | Ce fichier |

## 5. Essais de bruit et de non-perturbation (résultats en §6)

- **A/A** : `main` 7da63d9 (scénario `etape1-guide` sans les relevés, source détachée) contre la branche `mesures`,
  même graine. Les lignes `[FO-ETAPE1-GUIDE] base`, `mesure` et `[FO-IA3C]` doivent être identiques aux colonnes
  renommées près (`tech=`, `palier=`, `dormants stock_*`). Un écart signifierait que la mesure perturbe la partie.
- **Rejeu** : la branche `mesures` rejouée deux fois sur la même graine donne des lignes `[FO-FONCTION]` identiques
  (F238) ; sinon la mesure dépend du temps réel ou d'un ordre non déterminé.

## 6. Résultats (renseignés après les mesures)

Voir le rapport du lot et `fo-logs\2026-10-28_MESURES\` (archives) ; les distributions de RÉGLAGE et de JUGEMENT sont
ajoutées ici sous forme de tableaux datés.

## 7. Propositions NON lancées (accord du DC requis)

- Fenêtre « sans PNJ » en fin de partie longue (retirer le travail des PNJ de chaque force pendant 15 à 20 min et
  mesurer plaques/min et `products_finished`) : c'est le critère décisif d'autonomie (audit_mesures §5, point 12), mais
  c'est un banc > 10 000 ticks avec une intervention dans la partie. Précédent : `ia1_build_common.lua`
  (`AUTONOMY` = 5 min, plus courte que la réserve de charbon d'un quai : à allonger à ≥ 15 min).
- Transformer certains de ces relevés en `ctx.check` : seulement après §4, étape 2, et accord du DC.
- Étendre les mêmes relevés à `ia3e-usine`, `capi-partie`, `ia1-build-*` (promotions des critères calculés mais hors
  BILAN, audit_garde_fous §4).
