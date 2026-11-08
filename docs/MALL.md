# MALL CENTRALISÉ : conception (lot MALL, 8/11, phase A, aucun code)

Directive du DC (8/11 vers 18 h 30, en jouant la 0.6.71) : « Actuellement, le système crée de petits corpuscules d'assemblage
éparpillés, très espacés, qui tentent de se relier maladroitement. C'est inefficace pour passer aux Tiers supérieurs. » « Une fois les
premières interconnexions de survie établies, l'IA doit centraliser sa production. L'output massif des Méga-Fonderies doit alimenter un
véritable "Mall". » « Un Mall est une zone dense où les machines d'assemblage sont regroupées par rangées, proches les unes des autres,
partageant les mêmes bus d'inputs (fer, cuivre, acier, circuits). Quand un Tier supérieur demande une ressource en quantité
industrielle, l'IA arrête de construire des mini-usines isolées et allonge plutôt la rangée d'assembleurs dédiée dans le Mall
principal. » Et, pour le pétrole : « Le pattern de construction doit être un module capable d'être dupliqué […] pour former une longue
rangée extensible […] La duplication de la ligne ne doit s'arrêter que devant un obstacle physique infranchissable (lac, falaise). Si
c'est un obstacle destructible (caillou, arbre), l'agent le détruit et continue sa rangée. »

Base lue : `22cb5d46` (branche `mall`). Journal mesuré : copie figée `<racine>/fo-logs/2026-11-08_PARTIE-DC-0671/factorio-current-1830.log`
(0.6.71, 157 min de jeu, 2 699 lignes [FO-MALL]). Étiquettes : **lu** (vu au code, ligne citée), **mesuré** (compté dans ce journal),
**déduit** (raisonnement, non prouvé en moteur réel).

## 1. Ce qui existe, et pourquoi on obtient des corpuscules

### 1.1 Le module isolé du treillis
- Treillis : lots de 24 × 24, rues de 4, pas de 28 (`shared/team/plan.lua:37-39`, **lu**). Un module = un lot : un lot n'est candidat que
  s'il n'est pas déjà pris (`not l.used`, `script/team/build.lua:730`) ; le lot choisi est marqué pris (`build.lua:2910`) (**lu**).
- Placement : lots triés par distance à `toward` (`build.lua:711-750`), 8 lots essayés au plus (`build.lua:833`). Pour un assembleur,
  `toward` vaut `spec.near`, sinon le gisement de l'entrée principale, sinon le QG (`build.lua:2812`, `2825`) (**lu**). Les lots proches du
  QG sont pris tôt (fours, packs rouges, quartiers, centrales) : les modules suivants partent en spirale (**déduit**, **mesuré** au §1.6).
- Taille bornée par le lot : `M.MAX_SIDE = 24` (`shared/team/modules.lua:49`) ; une rangée de machines de côté s tient au plus
  ⌊25 / (s + 1)⌋ machines (`modules.lua:840`), soit **6 assembleurs 3 × 3**. Le bloc de mall tient ⌊19 / (s + 1)⌋ machines par côté
  (`shared/team/patrons.lua:618`), soit **8 machines** et 4 voies d'entrée (`patrons.lua:47`) (**lu**).
- Entrées : chaque port d'entrée reçoit une TÊTE D'ALIMENTATION, c'est-à-dire un coffre de quai et des bras (`build.lua:1510-1637`,
  `P.feeder`, `plan.lua:700`). Le coffre est rempli par des tournées « carry fill » de PNJ sous `Build.QUAI_LOW` = 60 objets
  (`build.lua:91-92`, `4136-4190`). Les blocs et cellules du mall sont TOUJOURS servis ainsi (`feed = "quai"`,
  `script/ai3/industrie.lua:427-429`) (**lu**).

### 1.2 Les rangées (RANGEES-ASM)
- Un ordre « chaine » agrandit une rangée de la même recette si elle le peut. Sinon, il pose une rangée neuve d'au moins
  `Ra.MIN_ROW` = 5 machines, près de l'ancienne (`shared/ai3/rangees_asm.lua:19-20`, `41-72` ; exécutant
  `script/ai3/rangees_asm.lua:109-152`) (**lu**).
- La rangée dynamique est planifiée ENTIÈRE à la borne de son gabarit (`script/team/rangee_dyn.lua:55-67`), puis grandit sur place
  (`rangee_dyn.lua:112-145`). Mais cette borne est celle du lot (6 machines au plus, avec en plus la borne de la voie). Pleine, la rangée
  suivante prend un AUTRE lot : `near` n'est qu'un point de départ pour le tri par distance (`rangees_asm.lua:41-46`) (**lu**).
- **Mesuré**, sur toutes les équipes : 18 décisions « nouveau » contre 2 « agrandir-dyn » ([FO-RANGEES-ASM]). Dès 2 voies, la borne de
  la rangée de câbles tombe à 4 (« gabarit 2 voie(s) : borne 4 »).

### 1.3 Les liens entre corpuscules
- **Liaison de quai** : un coffre de sortie, un bras, un tapis, un bras, un coffre de quai, à `Li.MAX_SPAN` = 40 tuiles au plus
  (`shared/team/liaison.lua:43`) (**lu**). **Mesuré** chez votre équipe à 152 min : « 56 quai(s) d'entree […] servis par tapis 5 sur 56 ».
- **« Bus » de produits** : malgré son nom, c'est UNE liaison longue par quai, « jamais de tronc partagé » (`script/team/bus.lua:10`), et
  4 au plus (`bus.lua:27`) (**lu**). **Mesuré** à 154 min : « aucun bus : 31 composante(s), 0 candidat(s) ».
- **Piquage** : il ne pique que des tapis HORS PLAN (`script/team/piquage.lua:6-8`) (**lu**). **Mesuré** : 0 piquage posé, dans toutes
  les équipes, pendant toute la partie.
- **Rapatriement** : il relie une sortie lointaine à un tampon placé au point qui minimise Σ débit × distance aux consommateurs
  (`shared/team/rapatriement.lua:20-22`) (**lu**). Les consommateurs étant éparpillés, les tampons le sont aussi : **mesuré**, (−27, 43)
  et (51, −20), à 71 et 72 tuiles du QG, de deux côtés opposés. Pour votre équipe : 42 lignes refusées « aucun chemin », 13 « trop long ».

### 1.4 Ce que le « mall » actuel fait vraiment ([FO-MALL])
- `shared/ai3/mall.lua` (Ml) n'est PAS un lieu. C'est un relevé de la demande. Il compte les fabrications répétées à la main (`Ml.note`)
  et les refus « manque sous une demi-machine » (`Ml.want`). Il en tire un nombre de machines voulu par objet (`Ml.decide`, `mall.lua:98` ;
  plafond `Ml.MACHINES_MAX` = 64, `mall.lua:33`) et des puits pour la capitalisation (`Ml.sinks`, `mall.lua:176`). Il filtre aussi la main
  (`shared/ai3/cerveau.lua:416-419`) (**lu**).
- `script/ai3/industrie.lua` (`Ind.think`, 313-460) range la demande en RANGÉES (au moins une demi-machine) ou en BLOCS de mall.
  `P.groups` (`patrons.lua:823`) regroupe les objets, et ce regroupement est REFAIT chaque minute. Chaque bloc demandé est un module
  NEUF (`Auto.submit`), dans un lot neuf, servi par quais (**lu**).
- **Mesuré**, les 2 699 lignes [FO-MALL] se répartissent ainsi :
  - 1 673 listes de la demande (`script/team/pile.lua:157-166`) ;
  - 1 026 décisions (`industrie.lua:89`) : 515 relevés de candidats, 230 « attend » (147 « manque iron-plate »), 56 refus, 39 DEMANDE
    (11 pour votre équipe), 28 FINI.

  Exemple de dispersion : « bloc [underground-belt] DEMANDE : module 87 (bloc, 10 entite(s), 0.2 objets/min voulus) », un lot entier
  pour 0,2 objet/min.
- **Mesuré**, demande « industrielle » de votre équipe à 157 min : « iron-gear-wheel x64 (234.3/min, TOURNE) ; electronic-circuit x25
  (72.5/min, amorcage a la main) ; iron-stick x13 (38.0/min, amorcage a la main) ». 64 machines d'engrenages voulues, alors qu'un module
  en porte 6 au plus.

### 1.5 Qui décide de construire un module
| Décideur | Levier | Exécutant | Placement |
|---|---|---|---|
| Capitalisation `Ca.decide` (une fois par minute, étape 10 ; `shared/ai3/capitalisation.lua:46-48`, `1795-1815`) | « chaine », « packs » | `execute` (`script/ai3/capitalisation.lua:1652-1700`), puis `RaRt.execute`, puis `Auto.submit`, puis `Build.request` | lot le plus proche de `near` ou du QG |
| Industrie `Ind.think` (même minute, `capitalisation.lua:2198`) | bloc de mall, cellule | `Auto.submit(feed = "quai")` | lot le plus proche du QG |
| Automatisation `A.decide` (IA3-e) | éteinte sous la capitalisation (en-tête de `capitalisation.lua:38-40`) | — | — |
| Cerveau | ne pose rien : la main seulement (`Ml.filter_crafts`) | — | — |

Le premier module d'un objet est borné à `A.FIRST_RATE_MAX` = 150 objets/min (`shared/ai3/automatiser.lua:77`) (**lu**).

### 1.6 Pourquoi des corpuscules (chaîne causale) et mesures
1. Une décision (ordre « chaine », bloc de mall) donne UN `Build.request`, donc UN module dans UN lot (§1.1).
2. Un module est borné à 24 tuiles : 6 assembleurs, 8 pour un bloc. Une demande industrielle (64 machines) ne peut donc donner qu'une
   série de modules.
3. Chaque module neuf prend le lot libre le plus proche : les lots du cœur étant pris, les modules partent en spirale.
4. Chaque module a ses quais, remplis à pied. Les liens tentés sont point à point, de quai à quai : il n'existe ni tronc partagé, ni
   zone commune (§1.3).
5. Les blocs de mall sont regroupés à neuf chaque minute : aucune identité stable, donc aucune rangée à allonger.

| Équipe (157 min) | modules d'assemblage | lots distincts | médiane au QG | médiane entre modules | boîte des lots | quais d'entrée | servis par tapis | tournées « fill » (objets portés) |
|---|---|---|---|---|---|---|---|---|
| votre équipe | 17 | **17** | 112 tuiles | **140 tuiles** | **280 × 196** | 56 | 5 | **746 (63 758)** |
| scarlet | 12 | 8 (+ 2 en repli) | 112 | 84 | 140 × 168 | 38 | 2 | 409 (47 062) |
| azure | 11 | 8 | 112 | 112 | 168 × 168 | 20 | 1 | 364 (25 577) |
| amber | 12 | 4 (+ 8 en repli) | 56 | 56 | 56 × 112 | 24 | 0 | 185 (19 732) |
| emerald | 6 | 4 | 112 | 112 | 140 × 112 | 8 | 1 | 94 (18 617) |

Distances de Manhattan au pas du treillis, sur les lots (i, j) des lignes `[FO-IA1D] … plan` (les lots « repli » n'ont pas de
coordonnées) ; quais et tournées : dernière ligne `[FO-PIQUAGE] … bilan`. Mesure faite par un script jetable (hors dépôt) qui relit ces trois sortes de lignes (**mesuré**).

Dates qui contraignent la transition (**mesuré**). Partie du DC : centrale finie entre 16 et 19 min ; premier champ électrique fini
entre 42 et 50 min ; recherche `logistics` (répartiteur, souterrain) finie à **74,8 min** (votre équipe), 81,4 (scarlet), 90,5 (azure).
Partie neuve de 40 min sur 0.6.71 (`fo-logs/2026-11-08_INTEG-0671/neuve40-9586fcc6`) : centrale à 7,7 min, mais ni champ fini ni
`logistics` en 40 min pour votre équipe.

## 2. Le flux cible

```
 MÉGA-FONDERIES ─ bouts de tapis de plaques (f.mega…sorties) ─┐       rapatriement (champs, fonderies lointaines) ─┐
                                                               ▼                                                    ▼
 QG ··· SECTEUR DU MALL : TÊTE (tampons, quais de secours) ─▶ TRONC : K lignes, UN objet par ligne (fer, cuivre, puis acier, circuits, …)
                                                                 │ prise = répartiteur + souterrain sous les autres lignes
                                         ┌───────────────────────┼───────────────────────┐
                                         ▼                       ▼                       ▼
                         RANGÉE « engrenages »      RANGÉE « circuits »       RANGÉE « acier » (fours)        (côté nord, puis sud)
                         cellule × n, grandit ↑      cellule × n, grandit ↑     cellule × n, grandit ↑
                                         │                       │                       │
                     sortie : coffres de tête barrés (PNJ → QG) ; plus tard, ligne de plus du TRONC (réinjection, tranche 5)
```

### 2.1 Le secteur du mall (où)
- **Un secteur par équipe**, réservé tôt, à la première passe du plan directeur après l'allumage du réglage. Il est choisi par le
  TERRAIN SEULEMENT, comme le demande le lead. Si on attend le déclencheur (45 à 75 min), les lots proches du QG sont tous pris et le
  mall partirait à 140 tuiles comme les corpuscules (**déduit** du §1.6).
- **Choix** (règle pure) : une fenêtre de départ de 60 × 60 tuiles (tronc de 4 places de rangées, rangées de 8 cellules de chaque côté).
  Elle est cherchée à une distance de Chebyshev de 84 tuiles au plus du QG (anneaux 1 à 3 du treillis), en dehors du lot du QG.
  - Contraintes : ni eau, ni falaise, ni minerai (règle L9 : on ne pose pas une fabrique sur un gisement), ni bâtiment.
  - Score : la longueur LIBRE au-delà de la fenêtre, le long des deux axes (le tronc d'un côté, les rangées de l'autre), lue jusqu'à 128
    tuiles. Viennent ensuite le moins d'arbres et de rochers, puis la distance au QG. Égalités départagées par (x, y, axe).
- **Réservation** : les lots couverts par la fenêtre reçoivent `l.mall = vrai` (exclus de `candidates`, `build.lua:730`), et les tuiles de
  la fenêtre sont réservées au nom du mall dans `b.occ` (aucun autre poseur n'y entre : liaisons, rapatriement, quartiers, repli).
  - Au-delà de la fenêtre, la réservation est GLISSANTE : chaque rangée et le tronc réservent leurs 2 cellules suivantes.
  - Une tuile réservée par un autre projet est un obstacle comme un bâtiment.
- Le secteur ne contient jamais de bâtiment du joueur (ils sont « bloqués » dans les masques, `build.lua:504-548`). Votre équipe partage
  pourtant sa force avec le joueur (`IA_WORKFLOW` §1) : on ne pose, ne pique ni ne démonte rien qui ne soit pas au mall.

### 2.2 La tête et le tronc (le bus d'entrée)
- **Tronc** : K lignes droites et parallèles. Chaque ligne est UN tapis qui porte UN objet sur ses deux voies, d'où une pureté
  vérifiable par ligne (§5). Les lignes sont espacées d'une tuile, voies vides comprises : ligne k au décalage 2k, intervalles aux
  décalages impairs. La largeur vaut donc 2K + 1 tuiles (9 pour K = 4).
- **Dimensionnement** : par objet, nombre de lignes = ⌈débit voulu ÷ débit d'un tapis⌉. Le débit voulu est la somme des consommations
  des rangées posées et décidées. Le tapis est le meilleur débloqué (`Conv.choose`) ; l'amélioration des tapis passe par le lot existant.
  Les lignes nouvelles naissent sur un bord. Ordre au départ : fer, cuivre ; acier et circuits s'ajoutent à la tranche 5.
- **Tête** (bout amont du tronc) : par ligne, un coffre TAMPON et ses bras, posés comme `P.feeder` aujourd'hui. Le nombre de bras est
  choisi au débit (`Build.Qd.plan`).
  - Ce tampon est rempli, dans l'ordre de préférence :
    - (a) par les tapis d'arrivée (méga-fonderie, tranche 4 ; ils se branchent sur la ligne elle-même, le coffre servant alors de secours) ;
    - (b) par les lignes de rapatriement, dont le tampon EST ce coffre ;
    - (c) par les PNJ (`quai_tasks`, inchangé). Cela fait un seul quai par ligne, au lieu d'un par module.
  - Une tête unique concentre la demande : la règle du tampon du rapatriement (Σ débit × distance) y amène d'elle-même les lignes
    longues (**déduit**). On peut aussi lui passer la tête en cible explicite.

### 2.3 Les prises (comment une rangée boit au tronc)
Repère : le tronc va vers l'est (+x) et les rangées partent vers le nord (décalage ≤ 0). La prise de la ligne k vers le nord, à la colonne
x, se compose ainsi :
- un RÉPARTITEUR tourné vers l'est, sur (x, 2k − 1) et (x, 2k) ;
- la sortie de bifurcation (x + 1, 2k − 1) est l'entrée d'un SOUTERRAIN vers le nord, qui ressort en (x + 1, 1) ;
- de là, un tapis monte jusqu'à la rangée.

```
décalage   x-1   x    x+1  x+2
   0        .    .    ↑    .        ← tapis de rangée, vers le nord
   1        .    .   [s]   .        ← sortie du souterrain (intervalle du haut)
   2        →    →    →    →        ligne 1, passe au-dessus du souterrain (k = 2 : 2k − 3 = 1 tuile sous terre)
   3        .   [R   [S]   .        ← bifurcation du répartiteur = entrée du souterrain vers le nord
   4        →    R]   →    →        ligne 2 : répartiteur sur (x, 3-4), elle continue en (x + 1, 4)
```
- Tuiles sous terre = 2k − 3 vers le nord, 2(K − k) − 1 vers le sud. On les compare à la portée du souterrain, LUE AU PROTOTYPE
  (`max_distance`). Avec le jaune (5 : 4 tuiles au plus entre l'entrée et la sortie), les lignes 1 à 3 se piquent vers le nord et les
  lignes K − 2 à K vers le sud.
- Une prise vers le nord et une prise vers le sud de la même ligne ne partagent jamais une colonne : les rangées du sud sont décalées
  d'une demi-place le long du tronc. Les rangées vont donc des deux côtés, et l'ordre des lignes se choisit
  pour que chaque rangée trouve ses entrées d'un même côté. Sinon, la rangée est refusée, avec sa cause.
- Deux prises pour une même rangée (lignes a < b) : prise a en colonne cx − 1, bifurcation en cx ; prise b en colonne cx, bifurcation
  en cx + 1. Leurs souterrains ne se coupent pas (b > a). Géométrie complète à prouver par le contrôle de la règle pure (§7).
- Répartiteur sans priorité : la rangée pleine se bouche, le reste du flux continue vers l'aval. La dernière rangée prend le reste. Le bout
  du tronc s'arrête net.
- **Avant le répartiteur** (pas encore de `logistics`) : une seule rangée, posée EN BOUT de tronc ; ses lignes deviennent son bus, sans
  prise. Le mall demande alors la recherche du répartiteur comme « voulue proche devant », sur le précédent du QCM du 8/11 vers 18 h 25
  pour `electronics`. Il la trouve par le TYPE de prototype (`T.LOGISTIC_TYPES`, `shared/team/config.lua:83`), jamais par un nom.

### 2.4 Les rangées (le module dupliqué)
- **Une rangée par recette** (rangée dédiée). Son bus fait 1 ou 2 tapis, un objet par tapis ; 4 voies, à deux objets par tapis, à la
  tranche 5.
- **Cellule = un MOTIF lu au catalogue de l'agent MOTIFS** (`shared/team/motifs/catalogue.lua`, décrit par rôles, emprise, période,
  n entrées / m sorties, et sa règle de sélection selon l'espace). Le mall n'invente aucune géométrie de rangée : il donne au motif
  l'espace libre, la demande, les objets du tronc et les techs, et reçoit le motif, le nombre de périodes ou un refus avec sa cause. Partage
  des rôles :
  - MOTIFS = QUOI : la cellule ;
  - `rangee_bus` = COMMENT ça s'étend : terrain, débit, croissance ;
  - MALL = OÙ et QUAND : secteur, tronc, prises, bascule.
- **Références du DC** (`<racine>/fo-logs/2026-11-08_MOTIFS/references/`, lues) :
  - `Patern1.png` : la cellule de base. 2 tapis d'entrée le long de la rangée ; un bras sur le tapis proche, un bras long sur le lointain ;
    une machine 3 × 3 ; un poteau ; un bras de sortie sur un tapis de sortie parallèle ;
  - `Patern_Mall2.png` : sa forme MIROIR de part et d'autre d'un tapis commun, avec insertion DIRECTE d'une machine dans l'autre (câbles
    vers circuits, période de 3 câbles pour 2 circuits) et une sortie par bras longs sur le tapis du milieu ;
  - `Mall1.png` : le peigne. Tapis d'entrée horizontaux, répartiteurs, tapis qui descendent entre des colonnes de machines, intermédiaires
    passés de machine à machine, coffres de sortie ;
  - `Fonderie.png` : la même forme pour les fours (tapis d'entrée au milieu, plaques des deux côtés), qui est la colonne de la
    méga-fonderie.
- **Exemple de dimension**, pour fixer les ordres de grandeur (la géométrie réelle vient du motif) : la cellule de Patern1 en miroir fait
  3 tuiles le long de la rangée et 14 en travers (coffre ou tapis de sortie | bras de sortie | machine | bras | tapis A | tapis B | bras |
  machine | bras de sortie | coffre ou tapis de sortie). « C K C » (circuits) et le four de l'acier (lot ACIER) sont des motifs comme les
  autres.
- **Croissance** : on ajoute des cellules en bout de rangée, entités translatées. Le projet de la rangée est rouvert en « reserve »
  (comme `Rg.grow`) et passe par le chantier ordinaire : réserve, défrichage, fantômes, PNJ. La cible n vient de la demande
  (`Ra.decide` : agrandir), bornée par n_max = min(terrain, débit de la prise ou du tapis de rangée, voie de sortie).
- **Arrêts**, avec leur cause au journal :
  - « obstacle:eau » ou « obstacle:falaise » : infranchissable, la rangée s'arrête ;
  - « obstacle:batiment » ou « obstacle:reserve » : idem ;
  - arbres et rochers (`masks.clear`) : défrichés (`add_obstacle`, existant), puis la rangée continue ;
  - « debit:prise » : la rangée est pleine. On ouvre une RANGÉE SŒUR de la même recette à la place suivante du tronc, ou on améliore le
    tapis (lot existant), selon le moins cher.
- **Tronc** : il s'allonge d'une place de rangée (15 tuiles : 14 + 1 d'écart) quand une recette nouvelle demande une rangée. Il s'arrête
  aux mêmes obstacles ; le mall est alors plein (décision D6).

### 2.5 Les sorties
- Tranches 2 à 4 : le tapis ou les coffres de sortie de la rangée reviennent vers le tronc. Ils finissent en coffres BARRÉS sur la rangée
  de tête (`P.out_quai`, `p.outs`, `keep_stock`, barres de `Ind.sweep`, tout cela existant). Les PNJ collectent en UN endroit vers le QG.
- Tranche 5 : la sortie d'une rangée d'intermédiaire (engrenages, circuits, acier) devient une ligne de plus du tronc, côté aval. Les
  rangées de tier supérieur la piquent comme le fer.

## 3. La transition

**État « interconnexions de survie établies »** (relu à chaque décision, factions et votre équipe) :
- S1, une centrale finie qui PRODUIT (kW > 0) ;
- S2, pour le fer ET le cuivre, au moins une source AUTOMATISÉE finie qui produit (fonderie de champ ou du treillis : débit mesuré > 0) ;
- S3, pas de crise : ni mode survie, ni QG menacé, sommet de pile ni R0 ni R1 ;
- S4, un assembleur utilisable.

**Bascule** : dès que S est vrai et que le tronc du mall est au moins en chantier, ce qui suit va au mall :
- tout ordre « chaine » ou « packs » d'un objet dont les entrées solides sont au tronc (ou au tronc prévu) ;
- toute « rangée » de l'industrie.

Concrètement :
- `Ra.decide` voit la rangée du mall comme une rangée dynamique : n_max est celui du terrain et du débit, n'est plus la borne de 24
  tuiles ;
- « agrandir » allonge la rangée, « nouveau » ouvre une rangée au mall, jamais un lot.

Ce qui reste hors du mall, avec sa cause au journal :
- les objets à entrée fluide ou à minerai ;
- les fours du QG ;
- les avant-postes et les champs ;
- avant la tranche 5, les blocs de mall à faible demande. Dès la tranche 3, ils sont posés dans l'ANNEXE du secteur (lots marqués mall
  non encore pris) et non dans un lot quelconque.

**Les corpuscules existants** :
- on n'en construit plus aucun pour un objet que le mall sert ;
- ceux qui existent continuent. Le mécanisme existant les endort de lui-même : quand le mall couvre la demande, le stock dépasse la cible,
  leur sortie n'est plus collectée, leur barre l'arrête, et une sortie pleine coupe leur alimentation (`build.lua:4175`, lot VIDEO-L4)
  (**déduit**, à mesurer : tournées « fill » de ces modules) ;
- leur démontage, qui rendrait les assembleurs au mall, est une capacité NEUVE (aucun démontage de module par PNJ aujourd'hui, `Build.cancel`
  n'annule qu'un projet non bâti, `build.lua:3256-3273`) : décision D3.

## 4. Le déclencheur exact (factions ET votre équipe, même règle, aucun `f.is_player`)

Les cadences (le sens de chaque réservation et de chaque prise est vérifié par le contrôle de la règle pure, §7) :

| Quand | Quoi | Où |
|---|---|---|
| Plan directeur, passe de 5 ticks | recherche du secteur par tranches (au plus 2 chunks lus par passe), puis réservation | `script/team/mall.lua` (champ `Build.Mall` : `build.lua` est à 199 locales) |
| Capitalisation, minute, étape 10 | relecture de S, choix d'une rangée (bascule de `RaRt.execute`) | `script/ai3/rangees_asm.lua`, branche mall |
| Plan directeur, passe | croissance des rangées et du tronc (une cellule par passe au plus) | `script/team/mall.lua` |

Causes de refus, une ligne [FO-MALL] par CHANGEMENT de signature (comme [FO-MEGA]) :
- « reglage eteint » ;
- « secteur : aucune fenetre libre a 84 tuiles (cause dominante : eau|falaise|minerai|batiments) » ;
- « secteur : recherche en cours (n/N chunks) » ;
- « attente S1 : aucune centrale qui produit » ;
- « attente S2 : aucune source automatisee de <objet> » ;
- « attente S3 : crise (survie|qg menace|pile Rx) » ;
- « attente S4 : aucun assembleur » ;
- « rangee <objet> : entree <x> hors du tronc (fluide|minerai) » ;
- « rangee <objet> : prises de deux cotes » ;
- « rangee <objet> : repartiteur non debloque (recherche voulue) » ;
- « rangee <objet> : stock hors besoin insuffisant (manque X N) » ;
- « rangee <objet> : arret obstacle:<cause> en (x, y) » ;
- « rangee <objet> : arret debit:prise (n_max) » ;
- « purete : <ligne> porte <y> » ;
- « tronc plein : obstacle:<cause> ».

Lignes positives : « SECTEUR (x, y) axe <e|n>, libre <L> tuiles », « rangee <objet> OUVERTE a n cellules », « rangee <objet> allongee de a a b »,
« ligne <objet> ajoutee au tronc (K) ».

## 5. Pureté

Règle du mall : une ligne du tronc porte UN objet ; un tapis de rangée porte un objet (une voie, un objet, à la tranche 5) ; une sortie ne
rejoint JAMAIS un tapis d'entrée, elle va à des coffres ou à une ligne NEUVE du tronc. Ce sont des invariants du plan pur (`Mall.verify`).
Le garde-fou commun `shared/team/purete.lua` (agent PURETE-TAPIS) est appelé :
- avant chaque raccord à un tapis EXISTANT : prise sur une ligne, arrivée sur une tête, réinjection d'une sortie ;
- au contrôle d'une rangée posée (relevé du contenu).

Un refus de pureté annule le raccord, jamais le reste de la rangée. Il est écrit « purete : … ». API : §6.

## 6. Coordination

Messages envoyés le 8/11 vers 19 h à mega-fonderie, petrole-rangee, acier et purete-tapis, puis à motifs (demande du lead). Les réponses
et les accords seront reportés ici. Ce qui a été proposé à chacun :

- **mega-fonderie** (en attente de réponse) :
  - proposé : ton runtime publie les bouts de tes tapis de plaques, avant le quai, dans
    `f.mega…sorties = { { item, x, y, dir, rate, belt } }`, avec un objet par tapis ;
  - le tronc qui va de ces bouts à la tête du mall est au mall (T4) ; ta tranche 4, « bus de plaques », s'arrête donc à ces bouts ;
  - d'ici là, le rapatriement ramène tes coffres de quai à la tête.
- **petrole-rangee** (en attente de réponse) :
  - proposé : la règle commune `shared/team/rangee_bus.lua` (`Rb.extent`, `Rb.capacite`, `Rb.cellules`, `Rb.croissance`) ;
  - les sorties solides (plastique, soufre) deviendraient plus tard des lignes du tronc.
- **acier** (en attente de réponse) :
  - proposé : sa livraison reste en lot ; une fois le mall posé, la rangée d'acier devient un motif de rangée du mall, qui pique la ligne
    de fer, et sa sortie devient la ligne « acier » (T5) ;
  - questions posées : le charbon (voie propre ou quai) et le décideur (capitalisation ou `Inter.think`).
- **purete-tapis** (en attente de réponse) : demandés, la signature de `shared/team/purete.lua`, si la pureté se juge par voie ou par tapis,
  et si l'objet est lu au contenu mesuré ou déclaré au plan (un tapis vide n'a que l'objet du plan).
- **motifs** (en attente de réponse) : demandés, le format d'une entrée (axe, période, ports de tête et de sortie, poteaux, miroir),
  l'entrée et la sortie de la sélection, et un contrôle sur la période modèle (coût par sethook). Il me faut au minimum Patern1 et sa
  forme miroir pour T2, et Patern_Mall2 pour T5.
- **pose-par-lots** (non contacté, pour mémoire) : une cellule de rangée est un lot de pose naturel, une tâche par cellule et kit entier.

## 7. Tranches de livraison (la plus petite d'abord)

Porte commune de chaque tranche :
- tests hors jeu, mutants compris ;
- `iag_test` (anti-échelle : aucun nom d'objet dans `shared/ai3` ni `script/ai3`) ;
- `content` OK ;
- un micro-banc de 2 500 ticks au plus par la file ;
- coût par passe mesuré par `debug.sethook` au pire cas : ≤ 370 k instructions, soit environ 5 ms au rapport mesuré par
  mega-fonderie (282 k ≈ 3,8 ms).

Le **constat du §1.6** limite la preuve en partie neuve. En 40 min, S2 et `logistics` ne sont pas atteints aujourd'hui par votre équipe.
`etape1-geants` (40 min) prouve donc les tranches 1 et 2, et l'absence de régression. La preuve des tranches 3 à 5 en partie neuve
demande une partie plus longue : `etape1-geants` porté à 90 min, soit un banc long, avec l'accord du DC (décision D7).

| # | Contenu | Fichiers | Critères mesurables |
|---|---|---|---|
| **T1** | Réglage `fo-war-mall`. Secteur choisi par le terrain et réservé (lots `l.mall`, tuiles `b.occ`). Relecture de S et journal [FO-MALL] des causes. Rien de posé. | `shared/team/mall_plan.lua` (secteur, score, `Mall.verify`), `script/team/mall.lua`, `settings/mall.lua`, `locale/{fr,en}/mall.cfg`, tests | etape1-geants : chaque équipe a un SECTEUR avant 2 min, à 84 tuiles au plus du QG, sans eau, falaise ni minerai. Aucun module du treillis n'y est posé (0 entité d'un autre projet dans la fenêtre à 40 min). Toute minute sans mall a une cause écrite. Recherche du secteur ≤ 370 k instructions par passe. |
| **T2** | Tête (tampons fer et cuivre), tronc court, PREMIÈRE rangée en bout de tronc (sans répartiteur), pour l'objet « chaine » le plus demandé dont les entrées sont au tronc. Croissance par cellules, arrêts et défrichage. Bascule pour CET objet. | `shared/team/rangee_bus.lua` (règle commune, §6), `mall_plan.lua` (tête, tronc), cellule LUE au catalogue de MOTIFS (Patern1 et son miroir), `script/team/mall.lua` (`Build.SITES.mall`), branche dans `script/ai3/rangees_asm.lua` | Micro-banc `mall-rangee` (stock garni, centrale finie) : une rangée de plus de 6 machines en ligne droite (au-delà de la borne du lot), 0 quai par machine, 1 quai par ligne. La rangée s'allonge quand la demande monte. Un arbre est défriché et la rangée continue ; une eau l'arrête. etape1-geants : pas de régression. |
| **T3** | Prises (répartiteur et souterrain), rangées des deux côtés, bascule COMPLÈTE (toute « chaine » dont les entrées sont au tronc), blocs de mall dans l'annexe du secteur, tampon du rapatriement dirigé sur la tête. Le mall demande `logistics`. | idem, plus `script/team/rapatriement.lua` (cible de tampon) | Partie de 90 min (D7) : après la bascule, 0 module d'assemblage neuf hors du secteur, causes écrites exceptées. Boîte des modules d'assemblage ≤ 2 × la fenêtre (aujourd'hui 280 × 196). Tournées « fill » réduites de moitié au moins au même temps de jeu que sur 0.6.71 ([FO-PIQUAGE] bilan). 0 voie mêlée (pureté). |
| **T4** | Arrivées de la méga-fonderie : tronc de plaques tracé des bouts publiés (§6) jusqu'à la tête, A* par tranches et traversée, et lignes dimensionnées à la somme des débits. | `script/team/mall.lua` | Partie de 90 min : au moins 50 % du fer de la ligne arrive par tapis (compteur de la tête contre les tournées), pour une équipe qui a une méga-fonderie. |
| **T5** | Réinjection : sortie d'une rangée d'intermédiaire (engrenages, circuits, acier) en ligne neuve du tronc ; rangées de tier supérieur qui la piquent ; rangées mixtes à 4 voies (le mall des objets de construction, coffres barrés) à la place des blocs. | `mall_plan.lua`, motifs Patern_Mall2 et rangée mixte à 4 voies (catalogue de MOTIFS) | Un objet de tier ≥ 2 fabriqué par une rangée dont TOUTES les entrées viennent du tronc. Plus aucun bloc de mall en lot. |
| **T6** | Rangées sœurs et amélioration des tapis de rangée, second mall quand le tronc est plein (D6), démontage des corpuscules (D3). | selon les décisions | selon les décisions |

## 8. Coût par pensée

- **Secteur** (T1, une fois) : au plus 2 chunks lus par passe de 5 ticks. Le terrain est relu par chunk, comme les masques du rapatriement
  et `masques_view` (`build.lua:573`). Le score de chaque fenêtre est en O(1) par sommes préfixées (eau, falaise, minerai, bâtiment,
  arbre). Environ 175 chunks dans le rayon de recherche, soit 90 passes environ, soit 7,5 s de jeu, une fois par équipe.
- **Décision** (T2 et suivantes) : O(ordres « chaine ») dans la minute de la capitalisation ; aucune lecture de carte.
- **Croissance** : une cellule par passe au plus. Elle coûte O(tuiles de la cellule, 42) pour l'étendue, plus le chantier ordinaire.
  Le tronc : une place par passe.
- **Plan d'une rangée neuve** : O(cellules posées au départ + prises), soit 2 prises. Le contrôle `Mall.verify` porte sur la seule cellule
  modèle et les prises : les autres cellules sont des translations, comme `Mf.sample`.
- **Tracé du tronc de plaques** (T4) : A* par tranches, avec le budget de `Bus.SLICE` (250 états par passe).
- Chaque fonction est mesurée par `debug.sethook` dans son test, au pire cas : 4 lignes, 2 prises, 12 cellules, fenêtre de 60 × 60. Il
  existe un mutant « contrôle de toutes les cellules », qui doit être refusé par le plafond.

## 9. Checklist `docs/IA_WORKFLOW.md` §6, appliquée

1. **Étape** : secteur et croissance dans la passe du plan directeur (5 t) ; bascule à l'étape 10 de la capitalisation (E1, minute) ;
   tâches de chantier en E2 (`Build.think`), comme tout projet.
2. **Stock** : la rangée se paie sur le stock HORS BESOIN (`affordable` de l'industrie, `Dep`), comme les blocs ; les tampons de tête se
   lisent BRUTS (coffre).
3. **Lecteurs** : `f.build.mall` est lu par `RaRt.existing` (même minute), par `Build.brief` (vue Cerveau) et par `candidates` (lot
   `l.mall`).
4. **Tâche** : le chantier passe `Board.sync` et la porte, comme tout projet `ia1d`. La tâche « fill » des tampons garde la priorité de
   `quai_tasks`.
5. **Vue** : les coffres de sortie des rangées sont des `p.outs`, donc vus. Les tampons de tête sont des `p.quais`.
6. **Boucle** : on ferme B2 (un seul endroit de dépôt et de collecte) et on raccourcit B1 (moins de tournées). B3 : les sorties barrées
   arrêtent la machine. B4 : S3 retient la bascule pendant une crise.
7. **Joueur** : on ne pique que les lignes du mall et on ne pose que dans le secteur ; les bâtiments du joueur sont des obstacles.
8. **`f.is_player`** : aucune branche ; factions et votre équipe suivent la même règle.
9. **Journal** : [FO-MALL] (secteur, causes, rangées, arrêts), [FO-PIQUAGE] bilan (tournées), [FO-IA1D] (lots), [FO-RANGEES-ASM].
10. **Preuve** : hors jeu d'abord ; micro-banc de 2 500 ticks ; pas de banc long sans accord du DC.

## 10. Décisions à soumettre au DC (option par défaut en tête, à poser en QCM)

- **D1, emplacement** :
  - (a, défaut) secteur réservé TÔT, choisi par le terrain, à 84 tuiles au plus du QG ;
  - (b) secteur choisi au déclencheur seulement ;
  - (c) secteur aligné sur les lots du treillis.
- **D2, géométrie** :
  - (a, défaut) peigne : tronc et rangées perpendiculaires, des deux côtés, chacune grandit jusqu'à l'obstacle. C'est la forme de vos
    références : Mall1 pour le peigne, Patern1 et Patern_Mall2 pour la rangée ;
  - (b) bande de mall à 4 voies (rangées le long du bus). Plus simple, mais une rangée dédiée ne peut plus s'allonger dès qu'une autre la
    suit.
- **D3, corpuscules existants** :
  - (a, défaut) on les laisse s'endormir (stock au-dessus de la cible, sortie pleine) ;
  - (b) démontage par les PNJ quand le mall couvre leur objet, avec les machines rendues au mall (capacité neuve) ;
  - (c) rien.
- **D4, seuil de « quantité industrielle »** :
  - (a, défaut) rangée au mall dès 2 machines voulues (`Ra.JUSTIFY`), et le reste à l'annexe ;
  - (b) dès une demi-machine (`Id.ROW_MIN`).
- **D5, recherche du répartiteur** :
  - (a, défaut) le mall la demande « voulue proche devant », dès S1 et S2 (précédent `electronics`) ;
  - (b) on attend l'ordre naturel (74,8 min dans votre partie).
- **D6, mall plein** :
  - (a, défaut) on ouvre les rangées de l'autre côté du tronc, puis un second secteur près du premier ;
  - (b) le mall reste plein et on améliore les tapis seulement.
- **D7, preuve** :
  - (a, défaut) T1 et T2 sur `etape1-geants` (40 min) et micro-bancs ; T3 et T4 sur `etape1-geants` porté à 90 min (banc long, à votre
    accord) ;
  - (b) sur votre partie seulement.
