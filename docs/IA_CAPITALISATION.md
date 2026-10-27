# La capitalisation des factions (lot CAPI)

Règle pure : `shared/ai3/capitalisation.lua`. Test hors jeu : `tests/ai3_capitalisation_test.lua`.
Lot **hors jeu** : rien n'est branché en jeu, aucun banc en moteur réel n'a été lancé. Le branchement viendra **après les
fusions des lots SCALE, AUTO et CAPITAL** (plan pas à pas : `fo-logs\2026-10-27_CAPI\INTEGRATION.md`).

Version corrigée le 27/10 après la revue adverse (34 entrées sous deux lectures, 16 majeures, 29 défauts distincts) :
§9 et §10 disent ce qui reste ouvert et ce qui a changé.

## 1. La demande

Le Directeur Créatif, mot pour mot :

- 26/10 : « ils n'automatisent pas, ils craftent beaucoup à la main, ils ne font pas de recherches réelles […] beaucoup
  d'agents ne font rien […] Ils ne scalent pas alors qu'ils pourraient. »
- 27/10, 7 h 10 : « si ils font des chemins en dur […] dans le code, ça risque pas de le faire […] un véritable cerveau
  quelqu'un qui généralise, qui récupère [l'arbre] d'avancement, qui regarde ses ressources, ce qu'elles apportent […] ».
- 27/10, 12 h 05 : « Remarque : Le scaling des IA est aussi et surtout dans la maximisation des gisements, de la fonte et
  des crafts en fait, c'est le concept de capitalisation qu'il faut implémenter », puis « Et concernant la recherche
  IA ? ».
- 27/10, 12 h 15, sur la phrase de l'intégrateur « J'intègre donc la recherche à la capitalisation : plus de
  laboratoires et une production de packs qui grandissent avec les besoins » : « A ne pas oublier toute la partie plus de
  gisements. Plus de fours (dans la limite de ce qu'on peut faire fondre évidemment), si assembleurs disponibles alors on
  ajoute des chaînes de production etc etc. »
- 27/10, vers 12 h 30 (OBJECTIFS §4), critères de preuve : (1) couverture du gisement exploité, au moins 80 % des tuiles
  sous une foreuse ; (2) fours au nombre déduit du débit de minerai arrivé et de la vitesse des fours ; (3) nouveaux
  gisements ouverts quand le premier est couvert ; (4) chaînes d'assemblage dès que l'assembleur est disponible ;
  (5) laboratoires et packs qui grandissent.

Ce qui est donc **obligatoire** dans la règle, et où chaque point se trouve :

| Point | Levier | Section |
|---|---|---|
| (1) OUVRIR de nouveaux gisements, pas seulement couvrir les anciens | `ouvrir`, exploration | §3.4 |
| (2) des fours tant qu'il y a du minerai, jamais au-delà de l'arrivée | `fours`, contrôle dur `Ca.fed_max` | §3.5 |
| (3) des chaînes dès qu'un assembleur est disponible (recherché et fabricable) | `chaine`, `packs` | §3.6 |
| (4) laboratoires et production de packs | `labos`, `packs` | §3.7 |
| « etc. » : tout ce qu'un joueur ajouterait pour produire plus | biens d'équipement, `energie` ; améliorations de niveau : lot CAPITAL | §3.8 |

## 2. Le concept

Comme un joueur, une faction **réinvestit sa production dans plus de capacité de production**. Elle couvre ses gisements
de foreuses, puis elle en ouvre d'autres. Elle met autant de fours que son minerai en nourrit, et jamais plus. Elle monte
des rangées d'assembleurs pour ce qu'elle consomme, y compris pour ses propres machines. Elle fait grandir ses
laboratoires et sa production de packs avec la recherche. Elle recommence, et sa capacité croît comme un capital qui
rapporte : `dK/dt ≈ s × K ÷ (T̄ + délai de pose)`. Ici, `s` est la part réinvestie, `T̄` le retour moyen d'une chaîne et
le délai celui qui sépare la décision du bâtiment qui tourne.

Quatre idées tiennent tout :

1. **La demande vient des puits.** Ce sont la recherche, l'armée, les buts du cerveau et les chantiers. Elle descend
   ensuite le graphe des recettes. Un objet sans débouché ne vaut rien en amont.
2. **On investit là où ça rapporte vite.** Le retour se calcule `T = coût ÷ gain` pour le **projet de chaîne** entier
   (toutes les machines qui livrent un objet de plus au puits), avec un gain **marginal** : après chaque investissement
   retenu, tout est recalculé, si bien que chaque levier plafonne de lui-même.
3. **Le goulot amont passe d'abord.** Des fours ne valent rien sans minerai livré, et une chaîne attend son ingrédient.
4. **Les bornes viennent des données et des mesures**, jamais d'un nombre écrit pour une partie. Ce sont les places
   d'un gisement, le minerai livré par les foreuses, les packs produits, le budget (production, épargne, caractère) et
   les bras.

## 3. Les règles retenues (formules)

Unités : objets par minute, MU (unité de valeur de la règle X0), minutes. Les réglages de la règle sont des **nombres**
(`Ca.*`) ; aucun ne nomme le jeu.

### 3.1 Débits unitaires, lus dans les données (`Ca.data`)

Le relevé suit le format de `shared/ai3/catalogue.lua` (`K.build`). On y ajoute : `entities[].speed`, `mining_area`
(côté de l'aire de minage), `size` (côté de l'emprise), `energy_kw`, `resources[].mining_time`, `items[].fuel_value` et
`items[].type`. **`Ca.entity_of` convertit un prototype lu en jeu** (champs de `LuaEntityPrototype`) :

| Champ du runtime | Champ du relevé | Conversion |
|---|---|---|
| `crafting_speed`, `mining_speed`, `researching_speed` | `speed` | tel quel |
| `resource_searching_radius` (un RAYON : 2,49) | `mining_area` (un CÔTÉ : 5) | `⌊2 × rayon + ½⌋` |
| `tile_width` | `size` | tel quel |
| `energy_usage` (J par tick) | `energy_kw` | `× 60 ÷ 1000` (1 500 J/tick = 90 kW) |
| `Br.smooth` de SCALE (dixièmes de PNJ) | `idle` | `Ca.idle_of(x) = x ÷ 10` |

| Grandeur | Formule | Vanilla (retrouvé par le test, §1) |
|---|---|---|
| foreuse `d` sur la ressource `k` | `ρ = 60 × vitesse × (1 + bonus de minage) ÷ temps de minage` | électrique 30/min, à combustion 15/min |
| machine `m`, recette `r` | `60 × vitesse ÷ durée × quantité` | four en pierre 18,75 plaques/min ; pack rouge 6/min à l'assembleur 1 |
| laboratoire | `60 × vitesse × (1 + bonus)` secondes de recherche par minute | 6 unités/min d'une technologie de 10 s |
| combustible | `kW × 60 ÷ pouvoir calorifique (kJ)` | four en pierre 1,35/min |
| peigne de foreuses (paires face à un tapis) | terrain `(w + a + 1) × w ÷ 2`, couvert `min(terrain, a × w)` | électrique 13,5 et 13,5 ; à combustion 5 et 4 |
| valeur (MU) | point fixe min-plus **jusqu'à stabilité** : ressource `= Ca.RAW_MU × temps de minage` ; recette `= ingrédients + Ca.TIME_MU × durée` | plaque 1,32 ; engrenage 2,69 ; pack rouge 4,51 ; foreuse électrique 37,1 ; assembleur 1 35,7 ; laboratoire 69,5 |

- **Combustible** : celui du catalogue (`opts.cat.fuel`, filtré par l'exécutant), ou le meilleur produit extractible
  qu'admet `opts.fuel_ok`. Sans l'un ni l'autre, une ressource minable à la main plus riche que le charbon serait prise :
  c'est le défaut F332 (cristal de résonance, banc g1), reproduit par le test (§1) et évité en passant `opts.cat`.
- **Objets convertibles** (`D.convertible`) : les biens d'équipement (foreuses, fabriques, laboratoires), les pièces de
  l'exécutant et la **fermeture de leurs recettes**, sans les objets militaires (`R.ITEM_ROLE`). Vanilla : 33 objets
  (plaques, engrenages, circuits, pierre, acier, tuyaux…), mais ni coffre, ni tourelle, ni munition.
- La **machine choisie** pour une catégorie est la fabrique **disponible** au plus faible `(MU + Ca.H_FUEL × combustible ×
  MU du combustible) ÷ vitesse` : un exécutant sait la poser, l'objet qui la pose est au stock, ou bien sa recette est
  recherchée et il est fabricable. La foreuse est choisie de la même façon, par débit. Un **assembleur** est une fabrique
  dont une catégorie est aussi celle de la main.

### 3.2 Demande et besoin

- **Demande finale** (objets/min) :
  - besoin des buts `÷ Ca.H_GOALS` (10 min), **sans les buts capi ni le but de recherche** (ils sont déjà comptés par les
    lignes suivantes) ;
  - puits mesurés (`sinks`), **agrégés par objet** (débits sommés dans un ordre fixe, élastique si l'un l'est) ;
  - matières des ordres ouverts `÷ Ca.H_B` (10 min) : le capital fabrique le capital ;
  - packs de la recherche visée (§3.7) ;
  - combustible des machines à combustion posées et décidées.
- **Puits élastiques** : la recherche tant qu'il en reste, et les puits marqués `elastic` (au branchement : l'armée qui
  grandit selon α, et la réserve de munitions). Ils visent `cible ← min(cible × (1 + g), Ca.LEAD × débit mesuré)`, avec
  `g = min(Ca.G_MAX, s × dt ÷ (T̄ + délai))` en ‰ par cycle. `T̄` est la médiane des retours de chaîne acceptés sur les
  `Ca.T_HIST` derniers cycles ; le délai est mesuré par le runtime (`input.lag`, minutes entre la décision et le bâtiment
  qui tourne), `Ca.T_LAG` (5 min) sinon.
- **Saturation globale** : sans puits élastique, `g = 0` et rien ne croît.
- **Besoin** `R_i` : la demande est propagée dans le graphe, par profondeur décroissante, avec la recette choisie dans
  les données. Un objet ne transmet à son amont que son besoin **net** de stock, `R_i − stock_i ÷ Ca.H_STOCK`. La règle
  garde aussi la part de `R_k` de chaque utilisateur (`used_by`), qui sert aux fours d'avance (§3.5).
- **Capacité planifiée** `N_i` : machines posées, **reste à poser** des ordres ouverts (`n_left`), ordres décidés dans
  le cycle.
  - **La main n'est pas du capital** (`Ca.HAND_CAPITAL = 0`). Elle nourrit les machines aujourd'hui (elle compte dans la
    couverture d'un ingrédient), mais elle n'entre pas dans `N_i` : c'est la réponse à « ils craftent beaucoup à la
    main ».
  - Les foreuses d'un **gisement épuisé** (quantité connue et nulle) ne comptent plus.
- **Manque** : `d_i = R_i − N_i − stock_i ÷ Ca.H_STOCK`.
- **Nombre de machines** : `⌊d ÷ débit + ½⌋`, une machine dès qu'il en manque une demie. Pour un **goulot** (couverture
  `θ = (N + main + stock ÷ H) ÷ R` sous 90 %), une machine dès le premier objet qui manque (`Ca.count_for`). Sinon le refus
  « manque sous une demi-machine » est écrit.

### 3.3 Couvrir un gisement (`couvrir`)

Pour chaque gisement **ouvert** `f` de la ressource `k` :

- les **places libres** sont `⌊(tuiles − couvertes × terrain ÷ couvert) ÷ terrain⌋`. Les tuiles couvertes sont mesurées
  par le runtime, ou calculées depuis les foreuses posées et le reste des ordres ouverts ;
- **pour le manque** (`d_k > 0`) : `n = min(places, nombre de machines du manque)` ;
- **d'avance** (`d_k ≤ 0`, ressource qui a un débouché) : `n = min(places, ⌊(Ca.LEAD × R_k − N_k − stock) ÷ ρ⌋,
  places jusqu'à Ca.KAPPA)`, gain compté à `Ca.AHEAD_PCT` (25 %). C'est la réponse à « il aurait mis des foreuses
  partout » : la couverture monte à mesure que le budget le permet, jusqu'à 80 % des tuiles et 2 fois le besoin, jamais
  sans débouché. Pas sur un site ouvert dans le même cycle ;
- avec une **fonte sur place** (avant-poste : recette et four portés par le gisement), les fours se dimensionnent **par
  gisement** : `Ca.fed_max(débit total des foreuses du gisement, consommation de ses fours déjà là, κ)` ;
- un gisement où l'on ne peut pas poser ce cycle (**danger**, ou foreuse électrique sans courant **et sans centrale
  possible**) compte comme couvert : il ne bloque ni l'ouverture d'un autre, ni la réserve de places ;
- la couverture vaut `κ_f = couvertes ÷ tuiles` (‰). Le gisement est **couvert** si `κ_f ≥ Ca.KAPPA` (800 ‰, critère (1))
  ou s'il ne reste plus de place.

### 3.4 Ouvrir un gisement (`ouvrir`) : obligatoire

On ouvre un gisement **connu** (`deposits`, non ouvert, sans danger) de `k` si l'une de ces conditions tient :

| Condition | Raison écrite |
|---|---|
| (a) `d_k > 0` et tous les gisements ouverts de `k` couverts ou interdits (ou aucun ouvert) | « gisements ouverts couverts », « … interdits (danger, courant) », « aucun gisement ouvert » |
| (b) le site le plus proche coûte par débit, multiplié par `Ca.OPEN_RATIO` (120 %), moins que couvrir le gisement ouvert (le travail payé `λ` porte la distance) | « site moins cher par débit » |
| (c) épuisement : `réserve des ouverts ÷ N_k < Ca.H_LIFE` (60 min) ; une quantité **inconnue** ne compte jamais comme épuisée | « épuisement en … min » |
| (d) réserve de places : `places libres × ρ < Ca.RESERVE_PCT` (25 %) `× R_k`, tant que `N_k` reste sous `Ca.LEAD × R_k` | « réserve de places basse » |

- Le site reçoit `n = min(places, max(Ca.OPEN_MIN, nombre de machines du manque))` foreuses. Le coût fixe d'un site
  (`site_items` : les tourelles de « défendre d'abord », `T.defend_turrets`) est donné par le runtime.
- Une ouverture d'avance, quand `d_k ≤ 0`, ne compte que `Ca.AHEAD_PCT` (25 %) de son gain.
- Seuls les `Ca.SITES_EVAL` (3) sites sûrs les plus proches sont évalués par passe (coût de calcul).
- Sans site sûr connu, sous les mêmes conditions : **exploration** (`res.explore`).
- Sinon, l'ouverture est refusée avec sa raison : « gisements ouverts pas couverts (kappa … pour mille < 800) ».

### 3.5 Fours (`fours`) : jamais au-delà du minerai livré

Contrôle dur, pour une fabrique qui n'est pas un assembleur, dont un ingrédient est une ressource :

- l'**arrivée** qui dimensionne les fours est ce que livrent les **foreuses** au QG : `made − hand`. Ni le minage à la
  main (il cesse quand les PNJ sont réaffectés), ni le stock (une tâche ponctuelle de fonte le résorbe, pas un capital
  permanent) ;
- `n ≤ Ca.fed_max = ⌊x⌋ + [frac(x) ≥ 0,9]`, `x = (arrivée − consommation des fours du QG posés et décidés) ÷ consommation
  d'un four` : la famine reste sous 10 % d'un four et l'entassement sous un four ;
- **fondre d'avance** (« tout le minerai », critère (2)) : seulement sur la part du minerai que les **autres usages** ne
  réclament pas (leur besoin brut, moins ce que leurs machines consomment déjà), et **au plus `Ca.LEAD` × le débouché**.
  La part au-delà du manque ne compte que 25 % de son gain ;
- **sans débouché**, aucun four, même avec du minerai qui s'entasse ;
- un ingrédient fabriqué (plaques pour l'acier) suit la règle des chaînes (§3.6).

### 3.6 Chaînes d'assemblage (`chaine`, `packs`) : dès qu'un assembleur est disponible

- **La sorte vient de la machine choisie** : un assembleur donne une `chaine` (des `packs` pour une entrée de
  laboratoire), une autre fabrique des `fours`. Le moteur vanilla (catégorie que la main ne fait pas, fait par un
  assembleur) donne donc `chaine:engine-unit`, pas `fours`.
- La chaîne se décide dès qu'une machine est **disponible** : exécutable (`opts.exec`, en jeu `A.exec_entities` d'AUTO),
  recherchée et fabricable. Le gain compte aussi les bras rendus par la main : `λ × PNJ libérés`.
- **Goulot amont** : la chaîne **attend** tant qu'un de ses ingrédients fabriqués est couvert à moins de `Ca.THETA_MIN`
  (90 %) de son besoin dans le plan. Une fois l'ingrédient investi dans le cycle, la chaîne passe dans le même cycle.
- **Limites de l'exécutant**, écrites dans les refus : nombre d'ingrédients (`limits.max_ingredients`, 2 pour
  `G.simple`) et fluides (« limite : fluide »).

### 3.7 Recherche : laboratoires et packs (`labos`)

- La **recherche visée** `u*` (secondes de laboratoire par minute) grandit de `g` par cycle, au moins d'un laboratoire et
  jamais sous la mesure. Elle reste bornée par `Ca.LEAD × max(mesure, laboratoires posés)` et par la file entière en
  `Ca.H_R` (20 min).
- Le **mélange des packs** se calcule en répartissant `u* × H_R` sur la file, dans son ordre. Les packs voulus entrent
  dans la demande, d'où les chaînes de packs.
- **Laboratoires, en DÉBIT** : `n = ⌈(u* − capacité planifiée) ÷ débit d'un laboratoire⌉`, jamais plus que les packs ne
  nourrissent : `Ca.lab_cap` rend la recherche que les packs nourrissent au-delà des laboratoires planifiés, `min_p
  (couverture_p − consommation planifiée_p) ÷ part_p`. Les laboratoires affamés au-delà de 10 % (`research.starved`) n'en
  reçoivent aucun de plus.
- Sous menace, les laboratoires restent ouverts (levier du QG).

### 3.8 « etc. »

- **Biens d'équipement** : les matières qui manquent aux ordres ouverts sont une demande (§3.2). Une faction qui a un
  assembleur monte donc les chaînes de ses foreuses, de ses tuyaux, de ses bras.
- **Énergie** (`energie`) : une machine électrique rentable sans courant donne sa valeur (sa part de chaîne) à une
  centrale, donnée par le runtime (`Build.plant`) ; la centrale passe d'abord, la machine ensuite.
- **Améliorations de niveau** : elles restent au lot **CAPITAL** (`Cap.choose`, but de fond `capital:*`). CAPI ne les
  décide plus (un seul décideur par levier ; la version d'avant attendait un coût en MU et un gain que `Cap.candidates`
  ne rend pas, et plantait sur sa vraie sortie).

### 3.9 Coût, gain, retour, valeur

- **Coût** : `C = matières (MU) + λ × travail ÷ 60`.
  - Le travail (PNJ-s) compte la pose (`Ca.POSE_S` par entité), les allers-retours de chantier (`Ca.BATCH` entités par
    voyage, distance du gisement) et la fabrication à la main de ce qui manque au stock.
  - `λ` est le prix du travail (MU par PNJ-minute) : `0` si au moins un bras est libre, sinon la production par PNJ.
- **Capital d'une chaîne** (`Ca.chain_capital`, MU par objet/min) : la machine choisie et ses pièces divisées par son
  débit, plus le capital des ingrédients au prorata. Vanilla : minerai de fer 1,24 ; plaque 1,51 ; engrenage 3,61.
- **Gain** : `G = part utile × valeur de l'objet × part de l'étage × poids de la famille + λ × bras libérés −
  combustible` (MU/min).
  - La part utile est l'ajout, au plus le manque ; la part d'avance compte 25 %.
  - **Part de l'étage** (`Ca.share`) : capital de l'étage ÷ capital de la chaîne. La valeur de l'objet se répartit sur
    les étages au prorata de leur capital : elle n'est plus comptée à chaque étage. Un étage plein a donc le retour du
    projet entier, `T = capital de la chaîne ÷ valeur` : 1,24 min pour le minerai, 1,14 pour la plaque, 1,34 pour
    l'engrenage (2,68 à moitié utile), 2,45 pour le pack rouge.
- **Retour** : `T = C ÷ G`, accepté si `T ≤ T_max`. Sur vanilla, une chaîne pleine se rembourse en 1 à 5 min : `T_max`
  (10 à 40 min) refuse surtout les options d'avance, les chantiers lointains quand les bras sont payés, et sous menace.
  Le test le montre sur une option lente construite (§7).
- **Valeur au cerveau** : `v = 35 + ⌊15 × (T_max − T) ÷ (T_max + 7 × T)⌋`, de 50 (T = 0) à 35 (T = T_max), rationnelle et
  décroissante (aucun logarithme). Elle reste **sous la recherche** (`B.RESEARCH` 62) et l'extraction ; 35 est le seuil
  du travail qui fait venir une recrue (IA3-d).

### 3.10 Caractère, parts de l'armée et de la défense, budget

Traits d'IA2-0 et poids d'IA2-a (`B.weights`), pour mille :

| Grandeur | Formule | Bâtisseur | Technocrate | Équilibré | Conquérant |
|---|---|---|---|---|---|
| `s` (part réinvestie) | `clamp(500 × ambition × (2000 − agressivité) × w_capital, 200, 800)` | 800 | 660 | 500 | 225 |
| `α` (armée) | `150 × agressivité × w_armée` | 89 | | 150 | 281 |
| `δ` (défense) | `100 × prudence × w_défense × (2 sous menace)` | 100 | | 85 | 65 |
| `T_max` | `clamp(20 × ambition ÷ prudence, 10, 40)`, `÷ 4` sous menace | 30 | 21,1 | 22,2 | 26,7 |

- **Budget matières** du cycle : `épargne + s × stock libre convertible × (1 − δ − α) × Ca.STOCK_PCT %`.
  - **Épargne** (`st.bank`) : `s × Y × (1 − δ − α)` par minute s'y ajoute à chaque cycle, plafonnée à `Ca.BANK_H`
    (30) minutes de ce flux. Les ordres la dépensent après la part du stock. Une option plus chère qu'un cycle de
    production finit donc par passer : une faction sans stock (29,7 MU par cycle, une foreuse à 37,1 MU) pose sa
    première foreuse au 2e cycle (§6, X7). C'est le cas « ils ne scalent pas » : la demande mange toute la production.
  - `Y` est la valeur ajoutée mesurée (MU/min).
  - Le **stock libre** ne compte que les objets **convertibles** (§3.1) au-delà de `Ca.H_BUF` minutes de besoin, hors
    objets d'un puits et objets militaires : 2 000 coffres, 300 tourelles ou 3 000 chargeurs ne financent rien (§6, X6).
  - La défense et l'armée sont prises **avant**, sur le flux ET sur le stock.
- **Budget de bras** : `(bras libres + Ca.SPARE si l'effectif peut croître) × 60 × Ca.LABOR_H − travail des ordres
  ouverts`. Il remplace `A.MAX_OPEN`, `A.MAX_PER_PRODUCT` et `A.FIRST_RATE_MAX` : la borne est le travail disponible, pas un
  compte. `Ca.OPEN_MAX` (16 ordres ouverts) n'est qu'un plafond de sûreté du dépliage.
- **Menace** : `T_max ÷ 4` et `δ` doublé. Seuls les leviers du QG restent ouverts (`Ca.HQ_LEVERS` : fours, chaînes,
  packs, laboratoires, centrale) ; `couvrir` et `ouvrir` sont refusés.

### 3.11 Choix glouton (`Ca.decide`)

1. Calculer les options de tous les leviers.
2. Les trier par `(T arrondi au millionième, profondeur, clé)` (comparaison exacte et transitive).
3. Prendre la première qui tient dans le budget et les bras, en **réduisant sa taille par dichotomie** si elle est
   divisible (les bras règlent le rythme du chantier, pas la taille du capital).
4. L'appliquer au plan (`Ca.apply` : capacité, consommation, couverture, combustible, courant), puis **tout recalculer**.
5. Recommencer, au plus `Ca.MAX_ORDERS` (24) fois et tant que les ordres ouverts restent sous `Ca.OPEN_MAX`.

Un ordre ouvert garde sa clé (`couvrir:<gisement>`, `fours:<objet>`, …) jusqu'à sa fin : il n'est pas redemandé.

## 4. Interface

```lua
local Ca = require("shared.ai3.capitalisation")
local D = Ca.data(dump, { exec = { [entité] = true }, exec_roles = { main = true, labo = true }, cat = catalogue,
  mining_bonus, lab_bonus })                -- cat : K.build (son combustible) ; ou fuel_ok
local res = Ca.decide(input, st)            -- st : état persistant de la règle (nombres et tables), dans global
Ca.goals(goals, res, open)                  -- buts de FOND { key = "capi:<clé>", family, kind = "capi", value, fond = true, order }
Ca.capi_view(avail, res)                    -- part du stock virtuel réservable par les projets capi : (1 − δ − α)
Ca.text(res)                                -- ligne du journal « [FO-CAPI] <faction> minute M » (ASCII)
Ca.entity_of(proto), Ca.idle_of(x10)        -- conversions des unités du runtime
```

**Entrée** (`input`) :

| Champ | Contenu |
|---|---|
| `data` | `Ca.data(...)` |
| `state` | `{ techs = { [techno] = vrai }, known = { [ressource] = vrai } }` |
| `stock` | `{ [objet] = n }` |
| `flows` | `{ [objet] = { made = /min arrivés au QG (toutes sources), hand = /min faits ou minés à la main } }` |
| `machines` | `{ { entity, recipe, n, where = "qg" ou gisement } }` (posées : celles d'AUTO et de SCALE comprises) |
| `drills` | `{ { entity, resource, n, deposit } }` |
| `labs` | `{ { entity, n } }` |
| `deposits` | `{ { id, resource, tiles, amount (nil : inconnue), covered, dist, open, smelt, smelter, danger } }` (ouverts et connus) |
| `open` | ordres en cours (tels que rendus) + `n_left`, `smelt_left` (**reste à poser**), `missing = { {objet, n} }`, `work_left` |
| `sinks` | `{ { item, rate, want, elastic } }` |
| `need` | `{ [objet] = n }` : buts **sans** les buts capi ni le but de recherche |
| `research` | `{ queue = { { tech, left, time, packs } }, rate, starved }` |
| `power` | `{ have_kw, used_kw, plant = { kw, items, burner_kw } }` (facultatif) |
| `site_items`, `drill_extra`, `machine_extra` | `{ {objet, n} }` |
| `limits` | `{ max_ingredients }` |
| `workers`, `idle`, `can_grow` | bras (`idle` en PNJ : `Ca.idle_of(Br.smooth)`) |
| `traits`, `weights`, `threat` | caractère et menace |
| `dt`, `lag` | minutes depuis la décision précédente ; délai de pose mesuré (minutes) |
| `obtainable` | `function(objet) -> booléen` ou table `{ [objet] = vrai }` (en jeu : `ev.feas` d'IA-G, une table) |

**Sortie** (`res`) :

- `orders` : liste ordonnée. Chaque ordre porte :
  - `kind` ∈ { `couvrir`, `ouvrir`, `fours`, `chaine`, `packs`, `labos`, `energie` }, et `key` ;
  - `item`, `resource`, `recipe`, `entity`, `deposit`, `where`, `n`, `rate` (/min) et `items` (matières) ;
  - `cost_m`, `cost`, `work` (PNJ-s), `gain` (MU/min), `useful`, `share`, `T` (min), `value` (35 à 50) et `why` ;
  - pour une fonte sur place : `smelt_n`, `smelt_recipe`, `smelt_entity`.
- `refus` : `{ key, kind, item, why }`.
- `explore` : `{ resource, why }`.
- Caractère et budget : `s`, `delta`, `alpha`, `tmax`, `g`, `lambda`, `Y`, `K` (capital installé, MU/min), `budget`,
  `bank` (épargne après le cycle), `flow_part`, `stock_part`, `spent`, `labor`, `labor_used`, `open_n`.
- Recherche : `u_star`, `labs_target`.
- Plan : `coverage` (`{ id, resource, kappa, free, open, dead }`), `bottleneck` (`{ item, theta }`) et `R`.
- Les ordres ne contiennent aucune fonction : ils peuvent aller dans `global`.

## 5. Branchement prévu (résumé ; le plan pas à pas est dans `fo-logs\2026-10-27_CAPI\INTEGRATION.md`)

Un fichier nouveau, `script/ai3/capitalisation.lua` (runtime), et un réglage de carte `fo-war-capi` (éteint pour le
témoin). Aucun second chemin de pose. **Un seul décideur par levier** quand le réglage est allumé :

| Levier | Décideur (fo-war-capi allumé) | Exécutant | Ce qui s'éteint |
|---|---|---|---|
| couvrir (foreuses sur un gisement ouvert) | CAPI | avant-postes (`EMIT.outpost`, tâche `extend`) ; foreuses électriques : `Build.plan_drills` | `Br.wave` (SCALE), `B.GROW_*` (buts.lua) |
| ouvrir (gisement neuf) | CAPI | `site_needs` puis construction ; sans site : prospection d'IA3-f | rien (nouveau) |
| fours du QG | CAPI | rangées de fours du QG (SCALE : il pose ce que CAPI demande) | `Br.smelters` (nombre), `B.SMELTERS_WANT` |
| chaînes, packs | CAPI | `Build.request` avec `A.sized`, `A.method_for`, `A.exec_entities` (AUTO) | `A.decide` (AUTO) : il ne garde que ses méthodes |
| laboratoires | CAPI | places du QG de `research_step`, puis gabarit `labs` | `Ia3.LABS_MAX`, `Br.labs_max`, `Br.lab_window` |
| centrale | CAPI | `Build.plant` | — |
| améliorations de niveau | CAPITAL (`Cap.choose`) | `Cap.emit`, `Capital.pay` | — (CAPI n'y touche pas) |
| armée d'avance | SCALE (`Br.army`, part α) | inchangé | — |

- **Cerveau** : `Ca.goals(goals, res, open)` ajoute des buts de **fond** (`g.fond` du lot CAPITAL : aucune des K places,
  servis après les autres projets) ; il réémet chaque ordre ouvert avec la même clé jusqu'à sa fin. Le dépliage réserve
  avec `Ca.capi_view` : la part `α + δ` du stock virtuel reste à l'armée et à la défense.
- **Non-régression** : les bancs c1 et c1-témoin du lot CAPITAL (27/10) ont montré qu'un but de capital servi comme un
  projet ordinaire retardait la recherche (palier 3 : 1 faction sur 4 en 60 min contre 3 au témoin ; palier 2 en médiane
  24,3 min contre 14,3). Critère C5 : paliers K1 au moins aussi bons qu'au témoin.

Coût de calcul mesuré hors jeu (PC non épinglé, horloge à la milliseconde, 4 passages) : 0,6 à 1,2 ms par décision sur
la scène riche (4 gisements), 1,4 à 2,5 ms à 60 gisements connus, 3 à 4,4 ms à 200 ; pics de 2 à 6 ms. Une décision tient donc
en UN tick de 2 à 6 ms : au-dessus de la cible de 0,25 ms par tick du lot PERF. Il faut **étaler** (une faction par
tick, décalées, une décision par minute : 0,002 à 0,02 ms par tick en moyenne) et mesurer le pic en moteur réel avec
`--seul` (K10). Relevé : 37 à 62 ms, une fois par catalogue.

## 6. Critères de preuve en moteur réel (au branchement)

Par la file (`banc.py --qui CAPI`), sur au moins 2 graines, à 30 PNJ, avec le témoin `fo-war-capi` éteint sur les mêmes
graines. Les 5 critères du DC (27/10, 12 h 30) se lisent sur une **image de la base** et au journal `[FO-CAPI]`.

| # | Critère chiffré | Où |
|---|---|---|
| C1 | couverture d'un gisement exploité ≥ 80 % des tuiles (critère (1)), à mesure que le budget le permet | image + `coverage` |
| C2 | à chaque ordre, fours du QG × consommation ≤ minerai livré par les foreuses + 0,1 four ; minerai livré − fours × consommation < un four tant que le débouché le demande ; aucun four sans débouché (critère (2)) | `[FO-CAPI]`, `ia2_mesures.py` M3 |
| C3 | au moins un gisement **nouveau** par ressource en demande entre 20 et 90 min ; jamais avant que les ouverts soient couverts ou interdits, sauf épuisement ou réserve (critère (3)) | `[FO-CAPI]` + image |
| C4 | assembleur recherché et exécutable : une chaîne demandée en ≤ 5 min et finie en ≤ 20 min (critère (4)) | `[FO-CAPI]`, `[FO-IA3E]` |
| C5 | laboratoires ≥ visés − 1 dès 10 min ; packs produits ≥ 80 % de la consommation ; paliers K1 au moins aussi bons qu'au témoin et qu'à c1-témoin (palier 2 ≤ 14,3 min en médiane, palier 3 pour 3 factions sur 4 en 60 min) (critère (5)) | `[FO-CAPI]`, `[FO-CERVEAU]` |
| C6 | capital installé (`K`) à 60 min ≥ 2 × celui de 20 min ; allumé ÷ témoin ≥ 1,5 à 90 min | `capi_mesures.py` |
| C7 | inactifs ≤ 15 % de 30 à 90 min à 30 PNJ (K3) ; livré à 30 PNJ ÷ livré à 10 PNJ ≥ 1,2 ; armée envoyée ≥ 90 % du témoin | `scale_inactifs.py`, `ia1b_livre.py` |
| C8 | K9 (`verif-guide` 15 OK × 2 graines, `pvp_test`) ; K10 (part CAPI ≤ 0,01 ms par tick en moyenne et pic sous le p99 du témoin, `--seul`) ; K11 (`[FO-HASH]` égales, rechargement compris) | bancs existants |
| C9 | allumé : aucun module AUTO, aucune vague de SCALE décidés hors CAPI (journal) ; `site.tiles` recensés ≥ tuiles réelles d'un gisement de banc | `[FO-IA3E]`, `[FO-CAPI]` |

## 7. Preuve hors jeu (ce lot)

`lua5.2 tests/ai3_capitalisation_test.lua` donne **« [CAPI] BILAN : 151 OK, 0 ECHEC(S) (dont 30 mutants refusés sur
30) »** (27/10, worktree `capi`, après correction ; 91 OK et 13 mutants avant). `lua5.2 tests/iag_test.lua` donne
**96 OK** : l'anti-échelle relit le fichier, 958 noms cherchés, 0 fichier en défaut. `ai3_automatiser_test` (86 OK) et
`ai3_cerveau_test` (49 OK) sont inchangés.

Les scènes ne sont plus financées par des coffres : elles ont **1 000 circuits** au coffre (3 425 MU, convertibles), et
les contrôles du budget partent d'un stock vide.

| § | Ce qui est prouvé | Chiffres |
|---|---|---|
| 1 | ratios vanilla retrouvés depuis le relevé ; conversion d'un prototype du runtime ; point fixe sur 80 niveaux ; combustible filtré (F332) | 30 et 15 minerais/min ; 1,6 four par foreuse électrique ; 6 packs rouges/min ; peigne 13,5 / 13,5 et 5 / 4 ; rayons 2,49 et 0,99 -> aires 5 et 2 ; 1 500 et 2 500 J/tick -> 90 et 150 kW ; cristal à 8 MJ pris sans filtre, charbon avec le catalogue |
| 2 | couvrir avant ouvrir ; ouvrir quand couvert ou interdit ; d'avance (épuisement, réserve) ; épuisé ; quantité inconnue ; couverture d'avance ; goulot sous une demi-machine ; ressource inconnue ; ordre ouvert ; menace ; site 20 % moins cher ; courant | manque de 90/min : 3 foreuses sur d1 (T 1,24 min, valeur 44) ; manque de 940 : d1 rempli (18), puis s2 (13) ; d1 dangereux : s2 ouvert ; d1 épuisé : s2 à 5 foreuses ; couverture d'avance : 4 foreuses ; charbon à θ 0,69 : une foreuse ; cuivre inconnu : foreuse à combustion ; ordre à moitié posé : 400 ‰ |
| 3 | fours ≤ minerai livré (50 arrivées) ; ni main ni stock ; fondre d'avance au plus 2 × le débouché et sur la part libre ; fonte sur place par gisement | 300/min et 10 fours posés : +6 ; 1 875 au coffre : 0 ; 300 minés à la main : 0 ; 100 et 200 plaques/min : 10 et 16 fours ; X12 : 1 puis 5 fours de briques (pas 8) ; X2 : 6 foreuses, 9 fours |
| 4 | aucune chaîne avant la recherche ni sans exécutant ; engrenages avant packs ; retour de chaîne ; sorte par la machine ; la main n'est pas du capital | engrenages 1 (T 2,68 = capital de la chaîne ÷ valeur × 2), packs 5 (T 2,45) ; moteur : `chaine`, 3 assembleurs ; 400 tuyaux manquants : une rangée |
| 5 | laboratoires qui grandissent, bornés par les packs et par 2 × la mesure ; affamés : packs d'abord ; menace | visés 3 (120 s/min) et 24 (1 200 s/min) ; 1 200 -> 1 392 s/min en 4 cycles, au plus 2 400 ; 19 visés, 16 nourris |
| 6 | caractère, budget exact, épargne, stock non convertible, tri, T_max, valeur | budget 389 / 317 / 230 / 88 MU, engagé 386 / 228 / 84 ; X6 : coffres, tourelles, chargeurs : budget inchangé (29,7) ; X7 : premier ordre au cycle 2, 2 -> 16 foreuses en 20 cycles ; tri : la foreuse proche ; option à 14,4 min : prudent (10) refuse, ambitieux (40) prend, sous menace (10) refuse |
| 7 | saturation sans débouché | aucun puits : 0 ordre, g = 0 ; 50 000 plaques au coffre : ni foreuse ni four |
| 8 | données changées, même code ; tous les noms changés | four à vitesse 4 : 12 fours au lieu de 24 ; fer de temps 2 : 8 foreuses au lieu de 3 ; laboratoire à vitesse 2 : moitié moins ; mêmes ordres au renommage près, convertibles retrouvés |
| 9 | modèle simulé : ordres payés en **vrais ingrédients** (recette de chaque bien), réservés avant l'aval | K = 90, 108, 600, 1 677, 3 414 MU/min aux minutes 1, 20, 40, 99, 140 ; doublement depuis 20 min en 13 min ; g1 couvert à 64 min, plafond et exploration jusqu'à 100 ; g2 ouvert à 100 ; laboratoires 1 -> 114 ; 0 four au-delà du minerai livré ; bâtisseur 1 596 contre conquérant 126 à 50 min |
| 10 | déterminisme | deux passages ; entrées permutées ; relevé inverse ; puits en double dans deux ordres sur 3 cycles |
| 11 | 30 mutants refusés | les 13 d'avant ; les 10 qui survivaient à la revue (main comptée, ordres ouverts ignorés, danger ignoré, réserve à 0, connus ignorés, fonte sur place coupée, LEAD infini, T_max retiré, valeur constante, laboratoires bloqués sous menace) ; tri inversé, épuisement ignoré ; épargne coupée, stock non convertible compté, fours sur stock et main, valeur pleine à chaque étage, goulot ignoré |
| 12 | coût | voir §5 |
| 13 | cerveau | buts de fond ; vrai `P.update` sur trois pensées : ordre ouvert réémis, projet gardé, fermé à la fin ; 15 ordres capi : recherche et extraction gardent leur place parmi K = 9 ; `Ca.capi_view` |

Le modèle simulé du §9 reste un **jouet** : pose une minute après le paiement, coffres plafonnés à la mesure des
machines, aucun PNJ qui marche. Sa leçon pour le runtime : **la matière d'un ordre doit être réservée avant d'être
mangée par l'aval** (`P.take` à la priorité de l'ordre, sur `Ca.capi_view`).

## 8. Ce qui est écarté, et pourquoi

| Écarté | Pourquoi |
|---|---|
| Optimisation linéaire globale (simplexe sur le graphe) | trop chère par pensée (K10) ; instable ; illisible au journal. Le glouton marginal suffit et se lit. |
| « Liebig » strict (gain = valeur débloquée aux puits, au second goulot près) | avec plusieurs goulots à la fois, chaque option seule a un gain nul et le glouton se bloque. Remplacé par la part de chaque étage dans le capital de la chaîne, et l'attente de l'aval. |
| Valeur pleine à chaque étage (version d'avant) | la valeur au puits était comptée une fois par étage : retours illusoires, `T_max` sans effet (revue du 27/10). |
| Valeur ajoutée seule comme gain | un intermédiaire (engrenage, 0,05 MU) ne remboursait jamais sa machine. |
| Budget fongible sur tout le stock (version d'avant) | des coffres finançaient des foreuses ; sans stock, rien ne passait jamais (revue du 27/10). |
| Bornes en pour cent de l'effectif (`bras.lua`) ou nombres de bâtiments écrits (`B.GROW_MAX`, `B.SMELTERS_WANT`, `Ia3.LABS_MAX`, places fixes) | elles ne disent ni si l'investissement rapporte, ni s'il a un débouché. |
| Seuil de stock `B.saturated` (3 × besoin) pour la capitalisation | c'est un seuil, pas un flux ; remplacé par le besoin net du stock. |
| Améliorations de niveau dans CAPI | un second décideur à côté de `Cap.choose`, et une interface incompatible. |
| Chaînes à fluides (pétrole, pack chimique) | aucun exécutant fiable ; refus « limite : fluide ». |
| Modules, balises, trains, robots logistiques | aucun exécutant chez les factions ; les vitesses lues suivront d'elles-mêmes. |
| Démontage d'usines obsolètes | un joueur réaffecte ; hors lot. |
| Bâtiments posés par script sans travail de PNJ | de la triche, et l'effectif ne verrait aucun travail. |

## 9. Défauts et limites connus (à ne pas cacher)

- **Rien n'est prouvé en jeu.** Tous les chiffres viennent de données vanilla relevées et d'un modèle jouet. Les réglages
  sont choisis, pas calibrés en moteur réel : `Ca.TIME_MU` 0,1, `Ca.H_STOCK` 10, `Ca.LEAD` 2, `Ca.G_MAX` 150 ‰,
  `Ca.T_LAG` 5, `Ca.BANK_H` 30, `Ca.KAPPA` 800, `Ca.THETA_MIN` 900, `Ca.AHEAD_PCT` 25, `Ca.OPEN_MAX` 16.
- **Retours courts sur vanilla** : une chaîne pleine se rembourse en 1 à 5 min. C'est un fait de l'économie de Factorio
  en MU (une foreuse vaut 37 minerais et en mine 30 par minute), pas un artefact : `T_max` ne trie que les options
  lentes (avance, chantiers lointains payés, menace), et c'est le **budget** qui borne le plus souvent.
- **Fours d'avance plafonnés à 2 × le débouché** : si le minerai livré dépasse 2 fois la demande de plaques, l'excédent
  s'entasse (il n'a pas de débouché). Les foreuses étant elles-mêmes dimensionnées par la demande (et l'avance par
  2 × le besoin), ce cas ne devrait venir que d'une demande qui baisse. À mesurer (C2).
- **Partage du minerai pour le manque** : quand le minerai livré ne suffit pas à tous les usages, la fonte d'un objet
  prend ce qu'il trouve, sans part au prorata des autres usages (seule la fonte d'AVANCE réserve les autres usages).
- **Un seul ordre ouvert par clé** (`fours:<objet>`, `couvrir:<gisement>`) : un objet ne grandit pas plus vite que la pose
  de son ordre.
- **Démarrage lent de la recherche** : la recherche visée part de la mesure et grandit de `g` par minute.
- **Recettes à plusieurs produits** : une seule recette par objet ; les sous-produits sont ignorés.
- **Gisements** : `site.tiles` est plafonné à 64 aujourd'hui (`script/faction/sites.lua`). Sans recensement complet, un
  gisement paraît couvert après 4 foreuses électriques et `amount` est sous-estimé (épuisement annoncé trop tôt). Le
  recensement complet est un **préalable bloquant** du branchement (étape 1 du plan), avec sa mesure de coût.
- **Goulots des exécutants** (non corrigés ici) : une seule extension par sorte d'avant-poste à la fois
  (`shared/ai3/projets.lua`), une seule construction par sorte, une seule tâche `smelt` (`script/team/worker.lua`),
  6 places de fours au QG, 4 places de laboratoires. La règle demandera plus que ce qu'ils savent faire.
- Les laboratoires ne sont pas bornés par le courant (ils sont simulés sans courant sur main).
- **Coût** : une décision tient en un tick de 2 à 6 ms hors jeu ; elle doit être étalée (§5). Les options ne sont pas
  recalculées objet par objet après chaque ordre (tout est recalculé) : à faire si K10 le demande.

## 10. Ce que la revue du 27/10 a changé

| Défaut relevé | Correction |
|---|---|
| Budget fongible, non cumulé ; banc financé par 2 000 coffres | épargne `st.bank` (30 min de flux au plus) ; stock libre = objets convertibles seulement, `(1 − δ − α)` appliqué au stock ; scènes financées en circuits ; X6 et X7 au banc |
| Retour T sans sens (valeur pleine à chaque étage) | part de l'étage dans le capital de la chaîne (`Ca.chain_capital`, `Ca.share`) ; tri et `T_max` contrôlés par leurs effets |
| Buts capi au-dessus de la recherche, perdus d'une pensée à l'autre | buts de fond, valeur 35 à 50, réémis tant que l'ordre est ouvert (`Ca.goals(goals, res, open)`) ; vrai `P.update` au banc |
| Interface CAPITAL incompatible | `ameliorer` retiré : CAPITAL seul décide des niveaux |
| Combustible F332 revenu | `opts.cat` ou `opts.fuel_ok` |
| Gisement dangereux qui bloque l'ouverture | compté comme couvert (danger, courant sans centrale) |
| Fonte sur place dimensionnée par ordre | par gisement (débit total, fours déjà là) |
| « Fondre tout » sans réserve ni plafond | part libre des autres usages, au plus 2 × le débouché |
| 10 mutants survivants | 17 mutants de plus, 30 refusés sur 30 |
| Doublons de rôle avec AUTO et SCALE | table levier -> décideur -> exécutant (§5), critère C9 |
| Sorte d'ordre par la catégorie | par la machine choisie |
| Manque sous une demi-machine jamais comblé | une machine pour un goulot, refus écrit sinon |
| Unités de l'interface | `Ca.entity_of`, `Ca.idle_of`, contrôle au banc |
| Double compte de `need` | écrit : `need` sans les buts capi ni la recherche |
| `site.tiles` ≤ 64 | préalable bloquant du branchement |
| Pas de couverture d'avance | couverture d'avance jusqu'à 80 % et 2 × le besoin |
| Tri annoncé stable, puits en double | tri stable par l'index, puits agrégés, contrôle au §10 |
| Minerai miné à la main et stock comptés comme arrivée | arrivée = livré par les foreuses |
| Gisement épuisé, quantité inconnue | foreuses mortes hors capacité ; inconnue = jamais épuisée |
| Coût sous-estimé | index des gisements par ressource, mémo des états, 3 sites évalués, dichotomie ; mesuré à 60 et 200 gisements |
| `ev.feas` est une table | accepté en table ou en fonction |
| Point fixe limité à 60 passes | jusqu'à stabilité |
| `n` d'origine des ordres ouverts | `n_left`, `smelt_left` |
| Laboratoires : nombre et débit mélangés | raisonnement en débit |
| Croissance inerte (`T_FLOOR`) | `g = s ÷ (T̄ + délai de pose)` |
| NaN au journal sans effectif | travail engagé compté à part |

## 11. Identifiants

Réservés au lot : F353 à F356 et E235 à E237. Ce lot hors jeu n'a observé aucun fait moteur ; les brouillons du
journal (`fo-logs\2026-10-27_CAPI\INTEGRATION.md` §7) gardent F353 à F356 pour les faits du branchement et
proposent E235 à E237 pour les expériences hors jeu de ce lot.
