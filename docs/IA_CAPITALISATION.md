# La capitalisation des factions (lot CAPI)

Règle pure : `shared/ai3/capitalisation.lua`. Test hors jeu : `tests/ai3_capitalisation_test.lua`.
Lot **hors jeu** : rien n'est branché en jeu, aucun banc en moteur réel n'a été lancé. Le branchement viendra **après les
fusions des lots SCALE et AUTO** (ordre annoncé, OBJECTIFS §4, 27/10, 12 h 05).

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
| « etc. » : tout ce qu'un joueur ajouterait pour produire plus | biens d'équipement, `energie`, `ameliorer` | §3.8 |

## 2. Le concept

Comme un joueur, une faction **réinvestit sa production dans plus de capacité de production**. Elle couvre ses gisements
de foreuses, puis elle en ouvre d'autres. Elle met autant de fours que son minerai en nourrit, et jamais plus. Elle monte
des rangées d'assembleurs pour ce qu'elle consomme, y compris pour ses propres machines. Elle fait grandir ses
laboratoires et sa production de packs avec la recherche. Elle recommence, et sa capacité croît comme un capital qui
rapporte : `dK/dt ≈ (s ÷ T̄) × K`. Ici, `s` est la part réinvestie et `T̄` le temps de retour moyen.

Quatre idées tiennent tout :

1. **La demande vient des puits.** Ce sont la recherche, l'armée, les buts du cerveau et les chantiers. Elle descend
   ensuite le graphe des recettes. Un objet sans débouché ne vaut rien en amont.
2. **On investit là où ça rapporte vite.** Le retour se calcule `T = coût ÷ gain`, avec un gain **marginal** : après
   chaque investissement retenu, tout est recalculé, si bien que chaque levier plafonne de lui-même.
3. **Le goulot amont passe d'abord.** Des fours ne valent rien sans minerai arrivé, et une chaîne attend son ingrédient.
4. **Les bornes viennent des données et des mesures**, jamais d'un nombre écrit pour une partie. Ce sont les places
   d'un gisement, le minerai arrivé, les packs produits, le budget (production, caractère) et les bras.

Synthèse des trois propositions de conception :

- **Joueur expert** : débits lus dans les prototypes, peigne de foreuses, conditions d'ouverture, arrondi des fours,
  équilibre entre laboratoires et packs, biens d'équipement.
- **Économie du capital** : registre, puits élastiques et croissance `g = s ÷ T̄`, budget `s × production libre`, parts
  de la défense et de l'armée, prix du travail `λ`, saturation par le flux plutôt que par un seuil de stock, choix
  glouton marginal.
- **Exécution et coût** : `λ = 0` avec des bras libres, budget de bras à la place de `A.MAX_OPEN`, valeur des ordres de
  35 à 90 (seuil de la recrue), contrôle dur des fours, menace (leviers du QG seulement), goulots des exécutants.

## 3. Les règles retenues (formules)

Unités : objets par minute, MU (unité de valeur de la règle X0), minutes. Les réglages de la règle sont des **nombres**
(`Ca.*`) ; aucun ne nomme le jeu.

### 3.1 Débits unitaires, lus dans les données (`Ca.data`)

Le relevé suit le format de `shared/ai3/catalogue.lua` (`K.build`). On y ajoute : `entities[].speed` (vitesse de
fabrication, de minage ou de recherche), `mining_area` (côté de l'aire de minage), `size` (côté de l'emprise),
`energy_kw`, `resources[].mining_time` et `items[].fuel_value`.

| Grandeur | Formule | Vanilla (retrouvé par le test, §1) |
|---|---|---|
| foreuse `d` sur la ressource `k` | `ρ = 60 × vitesse × (1 + bonus de minage) ÷ temps de minage` | électrique 30/min, à combustion 15/min |
| machine `m`, recette `r` | `60 × vitesse ÷ durée × quantité` | four en pierre 18,75 plaques/min ; pack rouge 6/min à l'assembleur 1 |
| laboratoire | `60 × vitesse × (1 + bonus)` secondes de recherche par minute | 6 unités/min d'une technologie de 10 s |
| combustible | `kW × 60 ÷ pouvoir calorifique (kJ)` | four en pierre 1,35/min |
| peigne de foreuses (paires face à un tapis) | terrain `(w + a + 1) × w ÷ 2`, couvert `min(terrain, a × w)` | électrique 13,5 et 13,5 ; à combustion 5 et 4 |
| valeur (MU) | point fixe min-plus : ressource `= Ca.RAW_MU × temps de minage` ; recette `= ingrédients + Ca.TIME_MU × durée` | plaque 1,32 ; engrenage 2,69 ; pack rouge 4,51 |

La **machine choisie** pour une catégorie est la fabrique **disponible** au plus faible `(MU + Ca.H_FUEL × combustible ×
MU du combustible) ÷ vitesse` : un exécutant sait la poser, l'objet qui la pose est au stock, ou bien sa recette est
recherchée et il est fabricable. La foreuse est choisie de la même façon, par débit. Un **assembleur** est une fabrique
dont une catégorie est aussi celle de la main ; il remplace la main. Un **four** est une fabrique d'une catégorie que la
main ne fait pas.

### 3.2 Demande et besoin

- **Demande finale** (objets/min) :
  - besoin des buts `÷ Ca.H_GOALS` (10 min) ;
  - puits mesurés (`sinks`) ;
  - matières des ordres ouverts `÷ Ca.H_B` (10 min) : le capital fabrique le capital ;
  - packs de la recherche visée (§3.7) ;
  - combustible des machines à combustion posées et décidées.
- **Puits élastiques** : la recherche tant qu'il en reste, et les puits marqués `elastic`. Ils visent
  `cible ← min(cible × (1 + g), Ca.LEAD × débit mesuré)`, avec `g = min(Ca.G_MAX, s × dt ÷ max(Ca.T_FLOOR, T̄))` en ‰
  par cycle. `T̄` est la médiane des retours acceptés sur les `Ca.T_HIST` derniers cycles.
- **Saturation globale** : sans puits élastique, `g = 0` et rien ne croît.
- **Besoin** `R_i` : la demande est propagée dans le graphe, par profondeur décroissante, avec la recette choisie dans
  les données. Un objet ne transmet à son amont que son besoin **net** de stock, `R_i − stock_i ÷ Ca.H_STOCK` :
  50 000 plaques au coffre ne demandent aucun minerai.
- **Capacité planifiée** `N_i` : machines posées, ordres ouverts et ordres décidés dans le cycle.
  - **La main n'est pas du capital.** Elle nourrit les machines aujourd'hui (elle compte dans la couverture d'un
    ingrédient), mais elle n'entre pas dans `N_i`.
  - C'est la réponse à « ils craftent beaucoup à la main ».
- **Manque** : `d_i = R_i − N_i − stock_i ÷ Ca.H_STOCK`.

### 3.3 Couvrir un gisement (`couvrir`)

Pour chaque gisement **ouvert** `f` de la ressource `k`, avec `d_k > 0` :

- les **places libres** sont `⌊(tuiles − couvertes × terrain ÷ couvert) ÷ terrain⌋`. Les tuiles couvertes sont mesurées
  par le runtime, ou calculées depuis les foreuses posées ;
- le gisement reçoit `n = min(places, ⌊d_k ÷ ρ + ½⌋)` foreuses, une machine dès qu'il en manque une demie ;
- avec une **fonte sur place** (avant-poste : recette et four portés par le gisement), les fours grandissent avec les
  foreuses, sur leur débit **prévu** : `Ca.fed_max(n × ρ, 0, κ)` ;
- la couverture vaut `κ_f = couvertes ÷ tuiles` (‰). Le gisement est **couvert** si `κ_f ≥ Ca.KAPPA` (800 ‰, critère (1))
  ou s'il ne reste plus de place.

### 3.4 Ouvrir un gisement (`ouvrir`) : obligatoire

On ouvre un gisement **connu** (`deposits`, non ouvert) de `k` si l'une de ces conditions tient :

| Condition | Raison écrite |
|---|---|
| (a) `d_k > 0` et tous les gisements ouverts de `k` couverts (ou aucun ouvert) | « gisements ouverts couverts » |
| (b) un site dont le coût par débit, multiplié par `Ca.OPEN_RATIO` (120 %), reste sous celui de couvrir le gisement ouvert (le travail payé `λ` porte la distance) | « site moins cher par débit » |
| (c) épuisement : `réserve des ouverts ÷ N_k < Ca.H_LIFE` (60 min) | « épuisement en … min » |
| (d) réserve de places : `places libres × ρ < Ca.RESERVE_PCT` (25 %) `× R_k` | « réserve de places basse » |

- Le site reçoit `n = min(places, max(Ca.OPEN_MIN, ⌊d_k ÷ ρ + ½⌋))` foreuses. Le coût fixe d'un site (`site_items` : les
  tourelles de « défendre d'abord », `T.defend_turrets`) est donné par le runtime.
- Une ouverture d'avance, quand `d_k ≤ 0`, ne compte que `Ca.AHEAD_PCT` (25 %) de son gain.
- Sans site connu, sous les mêmes conditions : **exploration** (`res.explore`).
- Sinon, l'ouverture est refusée avec sa raison : « gisements ouverts pas couverts (kappa … pour mille < 800) ».
- « Remplir avant d'ouvrir » découle donc du seuil de couverture et du coût fixe. Ce n'est pas un ordre écrit à la main.

### 3.5 Fours (`fours`) : jamais au-delà du minerai arrivé

Contrôle dur, pour une fabrique d'une catégorie que la main ne fait pas, dont un ingrédient est une ressource :

- `x = (arrivée mesurée au QG + stock ÷ Ca.H_STOCK − consommation des fours du QG posés et décidés) ÷ consommation d'un
  four` ;
- `n ≤ Ca.fed_max = ⌊x⌋ + [frac(x) ≥ 0,9]`. La famine reste sous 10 % d'un four et l'entassement sous un four ;
- l'arrivée ne compte que le minerai **livré au QG**, pas celui que les avant-postes fondent sur place ;
- **débouché présent** (`R_plaque > 0`) : la faction fond **tout** le minerai arrivé (critère (2)). La part au-delà du
  manque ne compte que 25 % de son gain ;
- **sans débouché**, aucun four, même avec du minerai qui s'entasse ;
- un ingrédient fabriqué (plaques pour l'acier) suit la règle des chaînes (§3.6).

### 3.6 Chaînes d'assemblage (`chaine`, `packs`) : dès qu'un assembleur est disponible

- La chaîne d'un objet dont la recette est d'une catégorie de la main se décide dès qu'une machine est **disponible** :
  exécutable (`opts.exec`, en jeu `A.exec_entities` d'AUTO), recherchée et fabricable.
- On pose `n = ⌊d_i ÷ débit d'une machine + ½⌋` machines. Le gain compte aussi les bras rendus par la main :
  `λ × PNJ libérés`.
- **Goulot amont** : la chaîne **attend** tant qu'un de ses ingrédients fabriqués est couvert à moins de `Ca.THETA_MIN`
  (90 %) de son besoin dans le plan. La couverture compte les machines planifiées, la main et le stock. Une fois
  l'ingrédient investi dans le cycle, la chaîne passe dans le même cycle : les ingrédients viennent d'abord dans la
  liste.
- Un ingrédient ressource se lit sur l'arrivée mesurée (§3.5).
- **Limites de l'exécutant**, écrites dans les refus : nombre d'ingrédients (`limits.max_ingredients`, 2 pour
  `G.simple`) et fluides (« limite : fluide »).
- Un objet qui est une entrée de laboratoire donne un ordre `packs`, pondéré par le poids de la recherche.

### 3.7 Recherche : laboratoires et packs (`labos`)

- La **recherche visée** `u*` (secondes de laboratoire par minute) grandit de `g` par cycle, au moins d'un laboratoire et
  jamais sous la mesure. Elle reste bornée par `Ca.LEAD × max(mesure, laboratoires posés)` et par la file entière en
  `Ca.H_R` (20 min).
- Le **mélange des packs** se calcule en répartissant `u* × H_R` sur la file, dans son ordre. Les packs voulus,
  `u* × packs par seconde`, entrent dans la demande, d'où les chaînes de packs.
- **Laboratoires** : `⌈u* ÷ débit d'un laboratoire⌉`, mais **jamais plus que les packs ne nourrissent**
  (`Ca.lab_cap` : capacité de packs planifiée, plus la main et le stock). Les laboratoires affamés au-delà de 10 %
  (`research.starved`) n'en reçoivent aucun de plus : les packs passent d'abord.
- Une seconde de recherche vaut ses packs et son temps. Le laboratoire est le puits de toute la chaîne des packs.

### 3.8 « etc. »

- **Biens d'équipement** : les matières qui manquent aux ordres ouverts sont une demande (§3.2). Une faction qui a un
  assembleur monte donc les chaînes de ses foreuses, de ses tuyaux, de ses bras.
- **Énergie** (`energie`) : une machine électrique rentable sans courant (foreuse, assembleur) donne sa valeur à une
  centrale. La centrale (kW, objets, chaudière) est donnée par le runtime (`Build.plant`) et passe d'abord ; la machine
  vient ensuite, dans le même cycle. Les laboratoires du QG sont simulés sans courant sur main ; ils ne sont pas bornés
  par le courant.
- **Améliorations** (`ameliorer`) : les candidats du lot CAPITAL (`Cap.candidates`), avec leur coût et leur gain en MU,
  sont rangés avec les autres options par leur retour. Le choix n'est pas refait.

### 3.9 Coût, gain, retour, valeur

- **Coût** : `C = matières (MU) + λ × travail ÷ 60`.
  - Le travail (PNJ-s) compte la pose (`Ca.POSE_S` par entité), les allers-retours de chantier (`Ca.BATCH` entités par
    voyage, distance du gisement) et la fabrication à la main de ce qui manque au stock.
  - `λ` est le prix du travail (MU par PNJ-minute) : `0` si au moins un bras est libre (un bras libre ne coûte rien),
    sinon la production par PNJ.
- **Gain** : `G = part utile × valeur pleine de l'objet × poids de la famille + λ × bras libérés − combustible` (MU/min).
  - La part utile est l'ajout, au plus le manque ; la part d'avance compte 25 %.
  - **Valeur pleine** et non valeur ajoutée : un engrenage n'ajoute que 0,05 MU, mais sans lui aucun pack ne se fait.
    Le premier essai, en valeur ajoutée, refusait l'assembleur d'engrenages (retour de 24 min).
- **Retour** : `T = C ÷ G`, accepté si `T ≤ T_max`.
- **Valeur au cerveau** : `v = 35 + ⌊55 × (T_max − T) ÷ T_max⌋`, entre 35 et 90. Tout ordre accepté vaut donc au moins
  35, le seuil du travail qui fait recruter (IA3-d). Sa priorité est `P.prio_of(v)`, de 55 à 80.

### 3.10 Caractère, parts de l'armée et de la défense, budget

Traits d'IA2-0 et poids d'IA2-a (`B.weights`), pour mille :

| Grandeur | Formule | Bâtisseur | Technocrate | Équilibré | Conquérant |
|---|---|---|---|---|---|
| `s` (part réinvestie) | `clamp(500 × ambition × (2000 − agressivité) × w_capital, 200, 800)` | 800 | 660 | 500 | 225 |
| `α` (armée) | `150 × agressivité × w_armée` | 89 | | 150 | 281 |
| `δ` (défense) | `100 × prudence × w_défense × (2 sous menace)` | 100 | | 85 | 65 |
| `T_max` | `clamp(20 × ambition ÷ prudence, 10, 40)`, `÷ 4` sous menace | 30 | | 22,2 | 26,7 |

- **Budget matières** du cycle : `s × (production × (1 − δ − α) × dt + stock libre × Ca.STOCK_PCT %)`.
  - La production est la valeur ajoutée mesurée (MU/min).
  - Le stock libre est ce qui dépasse `Ca.H_BUF` minutes de besoin : le stock qui dort s'investit.
  - La défense et l'armée sont prises **avant**.
- **Budget de bras** : `(bras libres + Ca.SPARE si l'effectif peut croître) × 60 × Ca.LABOR_H − travail des ordres
  ouverts`.
  - Il remplace `A.MAX_OPEN`, `A.MAX_PER_PRODUCT` et `A.FIRST_RATE_MAX` : la borne est le travail disponible, pas un
    compte.
- **Menace** : `T_max ÷ 4` et `δ` doublé. Seuls les leviers du QG restent ouverts : `couvrir` et `ouvrir` sont refusés.

### 3.11 Choix glouton (`Ca.decide`)

1. Calculer les options de tous les leviers.
2. Les trier par `(T, profondeur, clé)`.
3. Prendre la première qui tient dans le budget et les bras, en **réduisant sa taille** si elle est divisible (les bras
   règlent le rythme du chantier, pas la taille du capital).
4. L'appliquer au plan (`Ca.apply` : capacité, consommation, couverture, combustible, courant), puis **tout recalculer**.
5. Recommencer, au plus `Ca.MAX_ORDERS` (24) fois.

Un ordre ouvert garde sa clé (`couvrir:<gisement>`, `fours:<objet>`, …) jusqu'à sa fin : il n'est pas redemandé.

## 4. Interface

```lua
local Ca = require("shared.ai3.capitalisation")
local D = Ca.data(dump, { exec = { [entité] = true }, exec_roles = { main = true, labo = true }, mining_bonus, lab_bonus })
local res = Ca.decide(input, st)   -- st : état persistant de la règle (nombres et tables), dans global côté runtime
Ca.goals(goals, res)               -- un but { key = "capi:<clé>", family = "capital" | "recherche", kind = "capi", value, order }
Ca.text(res)                       -- ligne du journal « [FO-CAPI] <faction> minute M » (ASCII)
```

**Entrée** (`input`) :

| Champ | Contenu |
|---|---|
| `data` | `Ca.data(...)` |
| `state` | `{ techs = { [techno] = vrai }, known = { [ressource] = vrai } }` |
| `stock` | `{ [objet] = n }` |
| `flows` | `{ [objet] = { made = /min arrivés au QG (toutes sources), hand = /min faits à la main } }` |
| `machines` | `{ { entity, recipe, n, where = "qg" ou gisement } }` |
| `drills` | `{ { entity, resource, n, deposit } }` |
| `labs` | `{ { entity, n } }` |
| `deposits` | `{ { id, resource, tiles, amount, covered, dist, open, smelt, smelter, danger } }` (ouverts et connus) |
| `open` | ordres en cours (tels que rendus) + `missing = { {objet, n} }`, `work_left` |
| `sinks` | `{ { item, rate, want, elastic } }` |
| `need` | `{ [objet] = n }` (buts) |
| `research` | `{ queue = { { tech, left, time, packs } }, rate, starved }` |
| `power` | `{ have_kw, used_kw, plant = { kw, items, burner_kw } }` (facultatif) |
| `upgrades` | `{ { key, cost, gain, items, work, why } }` (CAPITAL) |
| `site_items`, `drill_extra`, `machine_extra` | `{ {objet, n} }` |
| `limits` | `{ max_ingredients }` |
| `workers`, `idle`, `can_grow` | bras |
| `traits`, `weights`, `threat` | caractère et menace |
| `dt` | minutes depuis la décision précédente |
| `obtainable` | `function(objet) -> booléen` (facultatif ; en jeu : `ev.feas` d'IA-G) |

**Sortie** (`res`) :

- `orders` : liste ordonnée. Chaque ordre porte :
  - `kind` ∈ { `couvrir`, `ouvrir`, `fours`, `chaine`, `packs`, `labos`, `energie`, `ameliorer` }, et `key` ;
  - `item`, `resource`, `recipe`, `entity`, `deposit`, `where`, `n`, `rate` (/min) et `items` (matières) ;
  - `cost_m`, `cost`, `work` (PNJ-s), `gain` (MU/min), `T` (min), `value` (35 à 90) et `why` ;
  - pour une fonte sur place : `smelt_n`, `smelt_recipe`, `smelt_entity`.
- `refus` : `{ key, kind, item, why }`.
- `explore` : `{ resource, why }`.
- Caractère et budget : `s`, `delta`, `alpha`, `tmax`, `g`, `lambda`, `Y` (production, MU/min), `K` (capital installé,
  MU/min), `budget`, `spent`, `labor`, `labor_used`.
- Recherche : `u_star`, `labs_target`.
- Plan : `coverage` (`{ id, resource, kappa, free, open }`), `bottleneck` (`{ item, theta }`) et `R` (besoin par
  objet).
- Les ordres ne contiennent aucune fonction : ils peuvent aller dans `global`.

## 5. Branchement prévu (après les fusions de SCALE et d'AUTO)

Un fichier nouveau, `script/ai3/capitalisation.lua` (runtime), et un réglage de carte `fo-war-capi` (éteint pour le
témoin). Aucun second chemin de pose.

| Morceau | Ce qu'il donne ou reçoit |
|---|---|
| **Relevé** | Celui du cerveau général (`script/ai3/general.lua`), complété des vitesses (`crafting_speed`, `mining_speed`, `researching_speed`), de `resource_searching_radius` (en `mining_area`), `tile_width`, `energy_usage`, `mineable_properties.mining_time`, `fuel_value`, et des bonus de la force. Refait une fois par catalogue. |
| **Mesures** | Différences de compteurs `get_input_count` sur la fenêtre (F242), `f.team.delivered` (F244 : un insert par script n'entre pas aux statistiques), `hand` tiré de la fenêtre d'IA3-e (`f.team.ia3e.window`), minerai livré au QG distinct de la fonte sur place. |
| **Gisements** | Recensement par composante connexe des tuiles de minerai (en cache, reste relu toutes les 5 min) ; `site.tiles` n'est plus plafonné à 64 ; tuiles couvertes = union des aires des foreuses posées. |
| **Cadence** | Une décision par équipe et par minute (`dt = 1`), sur son créneau de l'ordonnanceur ; `st` dans `f.team.capi`. |
| **Cerveau général (IA-G)** | `need` = buts de `Gen.summary` ; file de recherche = `Gen.choose` (technologie en cours, puis `d.ranked`) avec unités restantes ; `obtainable` = `ev.feas` ; `weights` = `B.weights`. |
| **Projets (IA3-c)** | `Ca.goals` ajoute les buts « capi » à la liste de `B.generate` ; `P.EMIT.capi` envoie chaque ordre à son exécutant ci-dessous. |
| `couvrir` | Avant-postes à combustion : `EMIT.outpost` (tâche `extend`), par paires, plusieurs avant-postes à la fois (goulot X1 de la proposition « exécution » : `view.pending[sorte]` n'autorise qu'une extension par sorte). Foreuses électriques : `Build.plan_drills` ou `Build.request` (gabarit `drills`) d'IA1-d et AUTO. |
| `ouvrir` | `site_needs` puis tâche de construction ; clé `build:<sorte>:<n>` (goulot X1 : une seule construction par sorte aujourd'hui) ; sans site : prospection d'IA3-f. |
| `fours` | Rangées du QG de SCALE (`Br.smelters` ne donne plus le nombre, il pose ce que CAPI demande ; plus de `SMELTER_OFFSETS` à 6 places) ; service par rangée (goulot X2 : une seule tâche `smelt` aujourd'hui, environ 12 fours par plaque, à mesurer). |
| `chaine`, `packs` | `Build.request` avec `A.sized`, `A.method_for` et `A.exec_entities` d'AUTO (`rate` = `o.rate`, `feed`, `near`). |
| `labos` | Places du QG de `research_step`, puis gabarit `labs` ; `Ia3.LABS_MAX`, `Br.labs_max` et `Br.lab_window` ne bornent plus. |
| `energie` | `Build.plant`. |
| `ameliorer` | `Cap.emit` du lot CAPITAL, inchangé. |
| **Automatisation (IA3-e)** | Sa charge à la main devient l'entrée `hand` (gain des bras libérés). `A.decide` reste une seconde source tant que CAPI n'est pas prouvée. `A.MAX_OPEN`, `A.MAX_PER_PRODUCT` et `A.FIRST_RATE_MAX` sont remplacés par le budget de bras. Le réglage `fo-war-ia3e` doit être allumé : sans exécutant d'assembleur, les points (3) et (4) n'ont personne. |
| **Plan directeur (IA1-d)** | Inchangé : il reçoit des `Build.request`. |
| **Effectif (IA3-d, repris par SCALE)** | Les ordres valent au moins 35 : le travail en attente fait venir les recrues (`E.decide`). `can_grow` = raison d'`E.decide` hors plafond, garde et menace ; `idle` = `Br.smooth` de SCALE. |
| **SCALE** | Les quantités de `Br.smelters`, `Br.wave`, `Br.cap_max`, `Br.labs_max`, `Br.lab_window`, `Br.depth_max` et `Br.need_floor` sont remplacées par les ordres. `Br.smooth` (bras libres) et `Br.army` (armée d'avance, part α) restent. `B.GROW_MAX`, `B.SMELTERS_WANT` et `Ia3.LABS_MAX` ne bornent plus. `B.saturated` ne bloque plus que les tournées et le minage à la main. |
| **Danger (IA3-k)** | `danger = vrai` sur un gisement où `D.danger_at` dépasse le seuil de la prudence, ou qui a coûté 2 morts dans l'heure. |
| **Journal** | `[FO-CAPI] <faction> minute M : ` + `Ca.text(res)`. |

Coût de calcul mesuré hors jeu (PC non épinglé) : 0,25 à 0,6 ms par décision sur la scène riche vanilla, 18 à 27 ms par
relevé (une fois par catalogue). Rapporté au tick pour 5 équipes, une décision par minute, c'est environ 0,003 ms par
tick. À remesurer en moteur réel avec la clé `capi` du profileur de PERF, banc `--seul` (K10).

## 6. Critères de preuve en moteur réel (au branchement)

Par la file (`banc.py --qui CAPI`), sur au moins 2 graines, à 30 PNJ, avec le témoin `fo-war-capi` éteint sur les mêmes
graines. Les 5 critères du DC (27/10, 12 h 30) se lisent sur une **image de la base** et au journal `[FO-CAPI]`.

| # | Critère chiffré | Où |
|---|---|---|
| C1 | couverture d'un gisement exploité ≥ 80 % des tuiles (critère (1)), à mesure que le capital le permet | image + `coverage` |
| C2 | à chaque ordre, fours du QG × consommation ≤ arrivée + 0,1 four ; arrivée − fours × consommation < un four ; minerai dormant au coffre ≤ 10 min d'arrivée (critère (2)) | `[FO-CAPI]`, `ia2_mesures.py` M3 |
| C3 | au moins un gisement **nouveau** par ressource en demande entre 20 et 90 min ; jamais avant que les ouverts soient couverts, sauf épuisement ou réserve (critère (3)) | `[FO-CAPI]` + image |
| C4 | assembleur recherché et exécutable : une chaîne demandée en ≤ 5 min et finie en ≤ 20 min (critère (4)) | `[FO-CAPI]`, `[FO-IA3E]` |
| C5 | laboratoires ≥ visés − 1 dès 10 min ; packs produits ≥ 80 % de la consommation ; paliers K1 (palier 2 ≤ 12 min, palier 3 ≤ 25 min) (critère (5)) | `[FO-CAPI]`, `[FO-CERVEAU]` |
| C6 | capital installé (`K`) à 60 min ≥ 2 × celui de 20 min ; allumé ÷ témoin ≥ 1,5 à 90 min | `capi_mesures.py` |
| C7 | inactifs ≤ 15 % de 30 à 90 min à 30 PNJ (K3) ; livré à 30 PNJ ÷ livré à 10 PNJ ≥ 1,2 | `scale_inactifs.py`, `ia1b_livre.py` |
| C8 | K9 (`verif-guide` 15 OK × 2 graines, `pvp_test`) ; K10 (part CAPI ≤ 0,01 ms par tick, `--seul`) ; K11 (`[FO-HASH]` égales, rechargement compris) | bancs existants |

Scénarios à écrire au branchement :

- **courts** :
  - `capi-fonte` : 300 minerais au coffre, aucune plaque, puis arrivée coupée ;
  - `capi-gisement` : avant-postes pleins ;
  - `capi-chaine` : assembleur recherché, aucune charge à la main ;
  - `capi-labos` : recherche en attente, packs au coffre ;
- **longs** : `capi-croissance` (216 000 ticks, 30 PNJ, 4 graines) et `capi-30v10` ;
- **outil** : `tools/autotest/capi_mesures.py`, qui lit `[FO-CAPI]`, `[FO-EFFECTIF]` et `[FO-IA3C]`.

## 7. Preuve hors jeu (ce lot)

`lua5.2 tests/ai3_capitalisation_test.lua` donne **« [CAPI] BILAN : 91 OK, 0 ECHEC(S) (dont 13 mutants refusés sur
13) »**, en environ 9 s (27/10, worktree `capi`). `lua5.2 tests/iag_test.lua` donne **96 OK** (95 avant ce lot) :
l'anti-échelle relit le nouveau fichier, avec 958 noms cherchés et 0 fichier en défaut.

| § | Ce qui est prouvé | Chiffres |
|---|---|---|
| 1 | ratios vanilla retrouvés depuis le relevé, sans table | 30 et 15 minerais/min ; 1,6 four en pierre par foreuse électrique ; 48 fours en pierre ou 24 en acier pour 30 foreuses ; 6 packs rouges/min ; 6 unités/min ; peigne 13,5 / 13,5 et 5 / 4 ; plaque 1,32, engrenage 2,69 MU ; combustible déduit, 1,35/min |
| 2 | couvrir avant ouvrir, ouvrir quand couvert, d'avance, explorer, menace, site 20 % moins cher, courant | manque de 90/min : 3 foreuses sur d1 (T 1,24 min, valeur 86), s2 refusé « pas couverts » ; manque de 940 : d1 rempli (18), puis s2 ouvert (13) ; épuisement en 25 min : s2 ouvert d'avance (2) ; sans courant : centrale puis foreuses |
| 3 | fours ≤ arrivée sur 50 arrivées de 0,1 à 30/s ; stock résorbé ; tout le minerai fondu s'il y a un débouché ; aucun four sans débouché | 300/min et 10 fours posés : +6 ; 1 875 au coffre : 10 ; 300/min pour 100 plaques/min : 16 fours |
| 4 | aucune chaîne avant la recherche ni sans exécutant ; engrenages avant packs ; plaques en manque : rien en aval ; biens d'équipement ; limite de l'exécutant ; courant | engrenages 1 (T 0,44), packs 5 (T 1,32) ; 400 tuyaux manquants : une rangée |
| 5 | laboratoires qui grandissent, bornés par les packs, affamés : packs d'abord | visés 3 (120 s/min) et 26 (1 200 s/min) ; 20 visés, 16 nourris |
| 6 | caractère, budget exact, parts de l'armée et de la défense, menace, prix du travail | budget 389 / 317 / 230 / 88 MU (bâtisseur, technocrate, équilibré, conquérant), engagé 364 / 216 / 86 ; menace : retour 22,2 → 5,6 min |
| 7 | saturation sans débouché | aucun puits : 0 ordre, g = 0 ; 50 000 plaques au coffre : ni foreuse ni four |
| 8 | données changées, même code | four à vitesse 4 : 12 fours au lieu de 24 ; fer de temps 2 : 8 foreuses au lieu de 3 ; engrenage au cuivre : besoin de cuivre en hausse ; laboratoire à vitesse 2 : moitié moins de laboratoires ; **tous les noms changés** : mêmes ordres au renommage près |
| 9 | modèle simulé (données jouets, noms inventés) : le capital qui rapporte | K = 90, 228, 1 701, 3 540 MU/min aux minutes 1, 40, 79, 120 ; doublement en 10 min depuis 40 min ; g1 couvert à 68 min, plafond et exploration jusqu'à 100 ; g2 ouvert à 100 ; laboratoires 1 → 120 ; 0 four au-delà de l'arrivée ; bâtisseur 381 contre conquérant 105 à 40 min |
| 10 | déterminisme | deux passages ; entrées permutées ; relevé dans l'ordre inverse |
| 11 | 13 mutants refusés | fours au-delà du minerai, ouvrir sans couverture, stock ignoré, plan non mis à jour, budget ignoré, travail payé avec des bras libres, assembleur sans recherche, laboratoires au-delà des packs, caractère ignoré, aval avant son ingrédient, menace ignorée, croissance coupée, débouché ignoré |

Le modèle simulé du §9 est un **jouet**. Il ne prouve rien du jeu :

- les ordres se paient en lingots (MU ÷ MU du lingot), pris après la fonte et avant l'aval, au plus la moitié du coffre ;
- la pose se fait la minute suivante ;
- les coffres sont à la mesure des machines ;
- aucun PNJ ne marche.

Deux erreurs de ce modèle ont été trouvées et corrigées en route : paiement après la consommation (aucun investissement,
minerai entassé), puis plafond du coffre qui bridait le débit. Elles sont notées ici parce qu'elles montrent ce que le
runtime devra garantir : **la matière d'un ordre doit être réservée avant d'être mangée par l'aval**. En jeu, c'est le
rôle de `P.take` et `P.want`, à la priorité de l'ordre.

## 8. Ce qui est écarté, et pourquoi

| Écarté | Pourquoi |
|---|---|
| Optimisation linéaire globale (simplexe sur le graphe) | trop chère par pensée (K10) ; instable (une petite mesure change tout le plan) ; illisible au journal. Le glouton marginal suffit et se lit. |
| « Liebig » strict (gain = valeur débloquée aux puits, au second goulot près) | avec plusieurs goulots à la fois, chaque option seule a un gain nul et le glouton se bloque. Remplacé par manque par objet, valeur pleine, et attente de l'aval (goulot amont). |
| Valeur ajoutée seule comme gain | un intermédiaire (engrenage, 0,05 MU) ne remboursait jamais sa machine. |
| Bornes en pour cent de l'effectif (`bras.lua`) ou nombres de bâtiments écrits (`B.GROW_MAX`, `B.SMELTERS_WANT`, `Ia3.LABS_MAX`, places fixes) | elles ne disent ni si l'investissement rapporte, ni s'il a un débouché. |
| Croissance réactive au seul manque (`B.GROW_*`) | la capacité suivrait le passé, pas l'investissement. |
| Seuil de stock `B.saturated` (3 × besoin) pour la capitalisation | c'est un seuil, pas un flux ; remplacé par le besoin net du stock. |
| « Main bus » littéral | l'exécutant pose des modules de 24 × 24 à quais ; les ordres d'intermédiaires en tiennent lieu. |
| Chaînes à fluides (pétrole, pack chimique) | aucun exécutant fiable ; refus « limite : fluide ». |
| Modules de vitesse et de productivité, balises, trains, robots logistiques | aucun exécutant chez les factions ; les vitesses lues suivront d'elles-mêmes. |
| Démontage d'usines obsolètes | un joueur réaffecte ; hors lot. |
| Bâtiments posés par script sans travail de PNJ | de la triche, et l'effectif ne verrait aucun travail. |
| Prix dynamiques (`marche.lua`) pour choisir | les MU fixes suffisent ; λ est le seul prix variable. |

## 9. Défauts et limites connus (à ne pas cacher)

- **Rien n'est prouvé en jeu.** Tous les chiffres viennent de données vanilla relevées et d'un modèle jouet. Les réglages
  de la règle sont choisis, pas calibrés en moteur réel : `Ca.TIME_MU` 0,1, `Ca.H_STOCK` 10, `Ca.LEAD` 2, `Ca.G_MAX`
  150 ‰, `Ca.T_FLOOR` 5, `Ca.KAPPA` 800, `Ca.THETA_MIN` 900, `Ca.AHEAD_PCT` 25.
- **Le gain en valeur pleine est optimiste** : il se recouvre le long d'une chaîne. Les retours sont courts (0,2 à 3 min
  sur vanilla), `T_max` ne trie presque rien et c'est le **budget** qui borne. C'est voulu (le budget porte le caractère),
  mais à mesurer.
- **Un ordre ouvert par clé** (`fours:<objet>`, `couvrir:<gisement>`) : un objet ne grandit pas plus vite que la pose de
  son ordre. Le modèle jouet pose en une minute, le jeu non.
- **Démarrage lent de la recherche** : la recherche visée part de la mesure et grandit de g par minute. Le jouet attend
  environ 15 min avant sa première chaîne de packs.
- **Recettes à plusieurs produits** : une seule recette par objet ; les sous-produits sont ignorés.
- **Arrivée de minerai** : le runtime doit séparer le minerai livré au QG du minerai fondu sur place. Sinon, le contrôle
  des fours compte faux.
- **Gisements** : `site.tiles` est plafonné à 64 aujourd'hui (`sites.lua`). Sans recensement complet, la couverture et
  les places sont fausses.
- **Goulots des exécutants** (lus dans le code par la proposition « exécution », non corrigés ici) : une seule extension
  par sorte d'avant-poste à la fois (`shared/ai3/projets.lua:321`), une seule construction par sorte (`:369`), une seule
  tâche `smelt` (`script/team/worker.lua:331`), 6 places de fours au QG, 4 places de laboratoires. La règle demandera
  plus que ce qu'ils savent faire.
- Les laboratoires ne sont pas bornés par le courant (ils sont simulés sans courant sur main).
- Coût de calcul mesuré hors jeu seulement.

## 10. Identifiants

Réservés au lot : F353 à F356 et E235 à E237. Ce lot hors jeu n'a observé aucun fait moteur. Les numéros servent au
branchement (expériences de C1 à C8).
