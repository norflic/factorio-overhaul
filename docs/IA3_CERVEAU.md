# IA3 « le cerveau des PNJ » : conception (document qui fait foi)

Architecte de la section IA3, 25/10/2026. Décision du DC : D-18 (RD_LOG ; OBJECTIFS §4, R-QCM-25g). Phase CONCEPTION :
rien n'est branché dans le jeu.

## 0. En bref

À ÉCRIRE

## 1. Comment un joueur humain pense à Factorio, en règles calculables

Un joueur ne suit pas une liste. Il a **un ou deux buts**, un arbre de dépendances en tête, et il se pose sans arrêt
deux questions : « qu'est-ce qui me bloque le plus ? » et « qu'est-ce que je fais à la main trop souvent ? ». Il ne
reste jamais planté devant son coffre : s'il attend du fer, il fabrique autre chose. Il range son temps comme la
ressource la plus rare de la partie.

Le cerveau actuel (`shared/team/planner.lua`) fait l'inverse : une échelle de 17 marches écrites à la main
(`T.ladder`, `shared/team/config.lua:104`), une marche à la fois, la recherche en 8e position, cinq niveaux de
recherche écrits à la main (`T.research`) et des priorités fixes (95 à 30). Les chiffres d'IA3-DIAG en sont la
conséquence directe : recherche 3 à 46 à 52 min au lieu de 12 à 36 (« possible » mesuré), 32 à 72 % de PNJ inactifs
dans les 10 premières minutes, 27 à 37 PNJ-minutes de packs jetés par faction.

Les douze règles suivantes traduisent le raisonnement d'un joueur en calculs. Unités : le **PNJ-seconde** (temps d'un
PNJ) pour le travail, le **MU** (1 plaque de fer, BALANCE_SHEET §3) pour la matière. Chaque règle dit ce que fait le
joueur, sa forme calculable, ce que fait le code d'aujourd'hui (mesuré), et où elle vit dans la nouvelle conception.

### 1.1 La boucle du joueur

```
 observer          s'orienter                 décider                         agir
 (ce que je sais)  (mes buts, mes manques)    (comment, qui, quand)           (gestes)
 stock, débits ──► buts emboîtés (H1, H9) ──► méthode la moins chère (§3) ──► tâches au tableau,
 carte connue      goulot (H2), faisable ?    réserver la matière (§2.2)       PNJ libres qui les prennent
 dangers, pertes   (H8), risque (H6)          ou explorer, ou s'équiper        (§2.3), expéditions (§4)
       ▲                                                                              │
       └──────────────────────── mesurer ce qui a marché (H11) ◄──────────────────────┘
```

Une pensée par équipe toutes les 300 ticks (5 s), comme aujourd'hui, découpée en phases (§5.3).

### 1.2 Les douze règles

**H1. Des buts emboîtés, jamais un geste sans raison.**
- Joueur : « je veux la recherche Automatisation → 10 packs rouges → des engrenages et des plaques de cuivre → du fer →
  miner ».
- Calcul : un BUT est `{ quoi, quantité ou débit, valeur, échéance souple }` ; il se **déplie** sur le graphe des
  recettes et des technologies lu dans les données du jeu (§3.2), jusqu'aux feuilles : matière au stock, geste à la
  main, machine, gisement, technologie. Chaque tâche porte la chaîne de ses « pourquoi » (projet et chemin), affichée
  dans la fenêtre (§5.5).
- Aujourd'hui : l'échelle écrite à la main ; une tâche ne porte qu'une étiquette (`tag = "objectif"`, `"armee"`…).
- Nouvelle conception : §3.1 (générateurs de buts) et §3.2 (dépliage).

**H2. Le goulot d'abord.**
- Joueur : regarde ce qui manque le plus pour son but, et met ses efforts là.
- Calcul (théorie des contraintes) : pour chaque feuille `l` du dépliage des buts ouverts, `attente_l = besoin_net_l ÷
  débit_l` (débit LU : statistiques de la force, F242 ; pour un geste à la main, PNJ disponibles ÷ durée de la recette).
  Le goulot est la feuille de plus grande attente, pondérée par la valeur du but. L'investissement suivant (§3.4) vise
  d'abord le goulot. Les débits visés viennent du solveur d'IA1-e1 (`shared/team/production.lua`, `P.solve`).
- Aujourd'hui : « première marche non atteinte » ; le goulot n'existe que pour les plaques de fer et de cuivre au-delà
  de 120 manquantes (`planner.lua:695-711`). Mesuré : le fer manque dans `default` (8 à 160 plaques au QG de 10 à
  60 min) pendant que 2 000 à 9 000 plaques de cuivre dorment.

**H3. À la main d'abord, puis automatiser ce qui revient.**
- Joueur : fabrique les 10 premiers engrenages à la main, pose un assembleur quand ça devient pénible.
- Calcul : pour chaque recette, la demande glissante `D` (objets par minute sur 10 min, lue au registre des
  réservations, §2.2) et le coût à la main `c = durée ÷ vitesse de fabrication du PNJ` (PNJ-secondes par objet).
  Charge à la main `= D × c ÷ 60` PNJ. On AUTOMATISE quand la charge dépasse 0,25 PNJ pendant 10 min ET que le
  retour sur investissement `T = coût du module (MU) ÷ gain (MU par minute)` est sous l'horizon `H` (20 min en
  sécurité, 5 min menacé : horizon du chef d'IA2). Le gain compte les PNJ-minutes libérées au **prix fictif** d'une
  PNJ-minute (§2.3 : la valeur de la meilleure tâche restée sans preneur), plus le débit gagné. Les recettes que la
  main ne sait pas faire (moteur, plastique, catégories autres que `crafting`) n'ont pas le choix : machine d'emblée.
  Le transport suit la règle d'IA1 déjà testée (`O.needs_automation` : plus de 60 objets par minute, plus de 10 min,
  64 tuiles au plus → tapis ou conduite).
- Aujourd'hui : rien n'est jamais automatisé. Mesuré : 40 à 58 % du travail d'une faction à 4 PNJ part en tournées
  à pied ; 0 assembleur, 0 tapis en 2 h.
- Nouvelle conception : §3.4 (« fabriquer, automatiser, agrandir, améliorer, construire ailleurs »).

**H4. Sur-construire quand c'est sûr ; ne pas laisser dormir le stock.**
- Joueur : au calme, il pose deux fois les fours qu'il lui faut, en pensant à la suite.
- Calcul : capacité visée `= débit des buts de la fenêtre d'anticipation × (1 + marge)` ; fenêtre = les 2 buts
  suivants en sécurité, le seul but courant sous menace ; marge 25 % en sécurité, 0 % menacé. Un stock DORMANT
  (plus de 10 min de sa consommation, et rien de réservé dessus) est un signal d'investissement : il est proposé aux
  projets qui le consomment (§3.4). C'est la capitalisation demandée (« scale un max et capitalise », R-20H).
- Aujourd'hui : capitalisation nulle (IA3-DIAG §2.4) : 2 000 à 9 000 cuivres dorment en fin de partie.

**H5. Explorer tôt, et explorer pour une raison.**
- Joueur : fait un tour au début pour voir les gisements, puis part chercher le pétrole quand il en a besoin.
- Calcul : la CONNAISSANCE de l'équipe = secteurs cartographiés par sa force (le moteur cartographie autour de ses
  personnages) + mémoire des gisements vus. Valeur d'une exploration = somme des valeurs des buts bloqués par une
  ressource inconnue + une petite valeur de curiosité quand tout est calme (un éclaireur au plus). Détails : §4.1.
- Aujourd'hui : la prospection (`script/faction/sites.lua`) regarde les chunks autour du QG **sans brouillard** (elle
  voit ce que la force n'a jamais vu) ; le pétrole n'est jamais cherché. Écart avec D-16 (« brouillard partout ») :
  déclaré ici, corrigé au lot IA3-f.

**H6. Sécuriser avant d'étendre.**
- Joueur : pose des tourelles avant de s'installer chez les biters, emporte des tourelles quand il part loin.
- Calcul : chaque lieu a un RISQUE (nids vus, pertes passées sur place, territoire ennemi, distance du QG) ; le
  risque fixe l'équipement, l'escorte, ou l'attente (§4.2). Les règles d'IA1-b2 (« défendre d'abord », avant-poste
  meurtrier) en sont un cas particulier et sont gardées.
- Aujourd'hui : rien chez les factions (IA1-b2 ne touche que votre équipe, `T.defend_first_factions = false`).

**H7. Ne jamais attendre : mener plusieurs choses de front.**
- Joueur : pendant que les fours tournent, il fabrique autre chose.
- Calcul : le cerveau garde PLUSIEURS projets ouverts (de 2 à `1 + ⌈PNJ ÷ 3⌉`, §3.5) ; un projet bloqué n'en bloque
  aucun autre ; un PNJ libre prend la tâche la plus utile qu'il SAIT faire, quel que soit son rôle (§2.3) ; s'il n'y
  a rien, il fait un investissement par défaut (capital, H4) plutôt que d'attendre au coffre.
- Aujourd'hui : un objectif à la fois, 12 min de patience sur un gisement introuvable (C5) ; un exécutant ne prend que
  le travail de son pôle (C3 b). Mesuré : chez 8 factions sur 12 à 8 PNJ, 42 à 115 minutes sur 119 avec au moins un
  demi-PNJ immobile au QG ET 2,5 à 6,6 tâches libres au tableau.

**H8. Ne pas fabriquer ce qui ne servira pas.**
- Joueur : ne fait pas les ingrédients du pack bleu tant qu'il n'a pas de pétrole.
- Calcul : un but est PAYABLE si chaque feuille de son dépliage est atteignable (stock, méthode connue, projet en cours,
  ou exploration lancée) ; sinon il devient « en attente de <cause> » et seule la cause devient un but (« trouver du
  pétrole »). Aucune tâche n'est créée pour les autres feuilles d'un but impayable. Prouvé hors jeu (§7, test
  `ai3_graphe_test`).
- Aujourd'hui : C1, la plus coûteuse : 120 rouges, 52 à 105 verts et jusqu'à 60 militaires fabriqués pour une
  recherche 4 impayable, soit 27 à 37 PNJ-minutes jetées par faction, puis des PNJ inactifs (4,55 sur 8).

**H9. La recherche ouvre des portes : elle vaut ce qu'elle débloque.**
- Joueur : recherche ce qui lui ouvre la suite, et tôt : la recherche 1 se paie avec le coffre de départ.
- Calcul : `valeur(techno) = Σ valeur des recettes qu'elle débloque pour les buts ouverts + poids stratégique du chef`
  (personnalité, D-18 : « selon le caractère ») ; on recherche la technologie de meilleure `valeur ÷ coût` (coût =
  packs en PNJ-minutes et en MU, lus dans le prototype). Aucune liste de niveaux écrite à la main.
- Aujourd'hui : C2 : packs verrouillés jusqu'à la 8e marche, priorité 40 sous l'armée et les recrues ; R1 +15 à
  +18 min, R3 +16 (4 PNJ) à +34 min (8 PNJ) sur le possible mesuré.

**H10. Garder une réserve.**
- Joueur : garde des munitions, du charbon, quelques plaques pour réparer.
- Calcul : un projet permanent « Réserve » tient des réservations dimensionnées sur la consommation (munitions des
  tourelles, charbon des brûleurs pour 3 min, un équipement de recrue ; plancher de 150 fer de la défense d'IA1-b2,
  F253). La réserve passe avant les projets ordinaires, après les urgences.

**H11. Apprendre de ses erreurs, dans la partie.**
- Joueur : « ce gisement m'a coûté deux morts, je n'y retourne pas sans tourelles ».
- Calcul : chaque échec (tâche, chemin, mort, avant-poste perdu) ajoute un SURCOÛT à la méthode ou au lieu concerné,
  qui décroît de 10 % par minute (même forme que la rancune du chef, IA2-a) ; deux échecs du même lieu → méthode
  suivante (autre site, expédition équipée). Mémoire bornée (32 entrées par équipe), nombres seulement.
- Aujourd'hui : pause de 30 s d'une tâche échouée (`Board.finish`, `RETRY_TICKS`), patience de 12 min d'une marche.

**H12. Le temps des PNJ est la ressource rare.**
- Joueur : « 5 minutes à porter du charbon, c'est 5 minutes où je ne fais pas d'usine ».
- Calcul : tout coût de méthode se compte en PNJ-secondes + MU (§3.3) ; le PRIX FICTIF d'une PNJ-seconde est lu
  au tableau (valeur des tâches restées sans preneur) ; il pousse l'automatisation (H3) quand les bras manquent, et la
  fabrication à la main quand des PNJ sont libres.

### 1.3 Ce qui reste volontairement « humain » (erreurs crédibles)

Un joueur parfait se repère aussi vite qu'un script. Le cerveau garde donc :
- des estimations, pas la vérité : il ne connaît que la carte vue (H5) et estime les dangers (§4.2) ;
- le hasard borné d'IA2 (tirage entre les options à 90 % ou plus de la meilleure, jamais une mauvaise) pour l'ordre
  des projets de valeur proche et le choix entre sites équivalents ;
- l'inertie : un projet commencé garde un bonus de 20 % (comme `O.ENGAGED_BONUS` et `P.HYSTERESIS`) ; on ne change
  pas d'avis toutes les 5 s.

## 2. Comment un groupe organisé joue

Huit joueurs qui se connaissent ne jouent pas comme huit joueurs seuls. Ils ont **un plan commun** (« on fait la
centrale, puis les packs verts »), ils **réservent** (« ces plaques sont pour la machine à vapeur, n'y touche pas »),
chacun **prend ce qui reste à faire** sans attendre qu'on le lui ordonne, les spécialités **orientent** (celui qui
aime la logistique fait les tapis) sans **interdire** (s'il n'y a pas de tapis à faire, il fait des engrenages), et
ils **se parlent** (« je pars au pétrole avec deux tourelles »). Un chef fixe le cap, pas chaque geste.

C'est exactement ce qu'une usine réelle organise par la **planification des besoins** (MRP : nomenclatures, besoins
nets, réservations de stock, ordres de fabrication) et par le **tableau de tâches** (kanban : chacun tire le travail
au lieu d'attendre un ordre). La conception reprend ces deux outils industriels.

### 2.1 Le tableau commun (blackboard)

Un seul état partagé par équipe, lu par tous, écrit par peu :

| Partie | Écrit par | Lu par | Contenu |
|---|---|---|---|
| Intentions | le chef (IA2), une fois par minute ; pour votre équipe : votre orientation | le cerveau | poids des familles de buts (recherche, armée, expansion, défense, capital), rivale, horizon |
| Projets | le cerveau (IA3), toutes les 5 s | PNJ, fenêtre | buts ouverts, méthode choisie, avancement, cause d'un blocage, meneur |
| Registre | le cerveau (réservations) ; les PNJ (prises, dépôts) | tous | stock libre, réservé par projet, en main par PNJ |
| Tableau des tâches | le cerveau et l'organisation | PNJ | tâches libres et prises, valeur, pourquoi |
| Connaissance | les PNJ et les yeux de la faction (IA2-c), au fil des événements | le cerveau | secteurs vus, gisements vus, nids vus, dangers, pertes |

Écrire au tableau commun est la seule façon de « communiquer » : aucune décision n'est prise par un PNJ seul, aucune
n'est cachée à la fenêtre.

### 2.2 Les réservations : personne ne « s'arrache » les plaques

**Ce qui se passe aujourd'hui (mesuré).** Le cerveau calcule un stock virtuel à chaque pensée (`planner.lua:189-200`),
donc deux tâches d'une MÊME pensée ne comptent pas sur les mêmes plaques. Mais :
- rien ne survit d'une pensée à l'autre : toutes les 5 s, l'ordre des priorités refait le partage (une recherche
  longue perd ses plaques dès qu'un besoin plus prioritaire apparaît : c'est C2, la recherche servie en dernier) ;
- les prises « larges » ignorent le plan : la fonderie prend jusqu'à 100 plaques pour l'acier, la recharge des
  tourelles jusqu'à 200 chargeurs, la tournée son charbon (`worker.lua:191-240`, prises non strictes) ;
- résultat mesuré dans les 6 parties d'IA3-DIAG (dernière ligne « taches ok/echec » de chaque équipe, journaux
  archivés `bancs\*\benchmark.log.gz`) : **3 à 50 échecs « stock » par équipe en 2 h** : un PNJ arrive au coffre et
  ce que le plan lui promettait n'y est plus ; la tâche est perdue, le PNJ a marché pour rien, la tâche est en pause
  30 s. C'est la trace mesurée de « l'arrachage ».

**Le registre (nouveau, `shared/ai3/registre.lua`, prototype testé §7).**

```
stock(o)        lu au coffre à chaque pensée (vérité du moteur)
reserve(p, o)   quantité de o réservée au projet p
en_main(pnj, o) objets pris au coffre pour une tâche, pas encore utilisés
libre(o)      = stock(o) − Σ_p reserve(p, o)          ≥ 0 toujours (contrôlé par le test)
```

Règles :
1. **Allocation par priorité, stable.** À chaque pensée, les projets, triés par priorité (avec l'inertie de 20 % d'un
   projet engagé, puis par identifiant), reçoivent leur besoin NET : `besoin − réservé − en main − en fabrication`.
   Un projet garde ce qu'il a déjà réservé : une nouvelle demande ne puise que dans le LIBRE.
2. **Prise stricte.** Un PNJ ne prend au coffre que ce que la réservation de SA tâche couvre. Les prises larges
   d'aujourd'hui (fonderie, recharge, charbon) deviennent les réservations d'un projet permanent « Entretien ».
3. **Préemption réglée.** Un projet peut prendre la réservation d'un autre seulement si l'écart de priorité atteint
   30 points (une urgence : munitions sous attaque, recrue de survie), ou 10 points si l'autre n'a encore rien
   consommé ; jamais ce qu'un PNJ a déjà en main. Le projet préempté est replanifié et la fenêtre le dit : « Azur :
   les plaques de la machine à vapeur partent aux munitions (attaque au nord) ».
4. **Restitution.** Un projet fini ou abandonné rend son reste au libre. Les objets d'un PNJ tué sont perdus avec lui
   (F253) : le projet replanifie.
5. **Pas de famine.** Un projet qui attend sa matière gagne 1 point de priorité par minute d'attente, jusqu'à +20.

**Exemple (votre phrase).** Le coffre contient 60 plaques de fer. Le projet « centrale à vapeur » (priorité 60)
réserve 31 plaques pour sa machine à vapeur (8 engrenages, 5 tuyaux, 10 plaques). Le projet « munitions de réserve »
(priorité 50) en veut 40 : il n'en obtient que les 29 libres. Deux PNJ libres prennent les deux tâches de la machine à
vapeur (« engrenages », « tuyaux ») ; chacune porte sa part de la réservation, elles ne se recouvrent pas. Si une
attaque arrive (munitions en priorité 95, écart 45 ≥ 30), les munitions peuvent reprendre les plaques de la centrale
qui ne sont PAS encore en main ; la centrale attend, et la fenêtre dit pourquoi.

### 2.3 La place de marché des tâches : n'importe quel PNJ libre prend la tâche la plus utile qu'il sait faire

**Aujourd'hui.** `O.pick_task` (`shared/team/org.lua:929`) range les tâches par rang : un exécutant ne prend une tâche
ordinaire que de SON pôle (rang 5) ; hors pôle, seulement les urgences (rang 3, plafonnées) et le travail de fond
(rang 7, `board.lua:137-149`). Mesuré (C3 b) : chez 8 factions sur 12 à 8 PNJ, **42 à 115 minutes sur 119** avec au
moins un demi-PNJ immobile au QG pendant que 2,5 à 6,6 tâches restent libres.

**Nouvelle règle : un score, pas un interdit.** Pour un PNJ libre `n` et une tâche libre `t` qu'il SAIT faire :

```
score(n, t) = valeur(t) × aptitude(n, t) × (1 + bonus_rôle(n, t)) − trajet(n, t) + continuité(n, t)
  valeur(t)     = priorité du projet (0 à 100, inertie et vieillissement compris) × 1,5 si la tâche est sur le
                  chemin critique de son projet (§3.5), × 0,7^k pour la k-ième tâche du même genre déjà prise
                  pendant une urgence (anti-ruée, remplace la limite hors pôle d'aujourd'hui)
  aptitude(n,t) = 0 s'il ne peut pas (pas d'arme pour une garde, pas de place en inventaire) ; sinon
                  1 + bonus de rang du PNJ dans ce geste (O.rank, IA1 : un fabricant de rang 3 vaut plus en
                  fabrication)
  bonus_rôle    = +0,20 si la tâche est de son pôle ; +0,20 de plus pour un généraliste sur une tâche de
                  conception ; 0 sinon : le rôle ORIENTE, il n'interdit jamais
  trajet(n,t)   = distance (tuiles) du PNJ au point de départ de la tâche ÷ 10 (une tâche à 100 tuiles perd
                  10 points)
  continuité    = +10 si la tâche suit la précédente du même projet (moins d'allers-retours)
```

- **Attribution déterministe.** Quand plusieurs PNJ sont libres à la même pensée, on calcule tous les couples,
  on les trie (score décroissant, puis clé de tâche, puis identifiant du PNJ) et on attribue gloutonnement : la
  meilleure paire d'abord. Un PNJ qui se libère entre deux pensées prend son meilleur score immédiatement (une
  seule passe sur le tableau, comme aujourd'hui). Coût : `PNJ libres × tâches` évaluations, au plus 30 × 64 ≈ 2 000
  par pensée et par équipe (environ 1 ms hors jeu, à mesurer ; §5.3).
- **Personne n'attend s'il y a du travail.** Propriété contrôlée par le prototype (§7) : à chaque attribution, aucun
  PNJ libre ne reste sans tâche s'il existe une tâche libre qu'il sait faire. Sans aucune tâche, le PNJ prend un
  INVESTISSEMENT PAR DÉFAUT (réserve de biens d'équipement, minage d'appoint, éclairage de la carte, H4, H5), sous
  le plafond du travail manuel d'IA1 (`O.manual_cap`).
- **Le prix fictif d'une PNJ-seconde** (H12) = valeur de la meilleure tâche restée sans preneur à la fin de
  l'attribution (0 si tout est pris). Il est lu par la règle d'automatisation (H3) et par le recrutement (§3.6).

### 2.4 Des rôles qui orientent sans interdire

On garde l'organisation d'IA1 (`docs/EQUIPES_PNJ.md` §3, §4) : 3 pôles (extraction, base, territoire), des managers
qui sont des fonctions, des généralistes (1 PNJ sur 6) qui MÈNENT un projet de bout en bout, des exécutants, votre
orientation (préréglages). Ce qui change :
- le pôle d'un PNJ devient un BONUS de score (+20 %), plus un filtre ;
- les cibles par pôle (`O.pole_targets`) restent : elles disent où l'organisation PRÉFÈRE ses bras ; un PNJ
  durablement hors de son pôle (plus de 5 min sur 10) y est réaffecté par l'hystérésis existante (`O.MAX_MOVES`) ;
- un projet a un MENEUR (généraliste, sinon le premier PNJ qui y travaille) : c'est lui que la fenêtre nomme, c'est
  lui qui prend les tâches de conception (implanter, choisir un site, partir en expédition).

### 2.5 Communication

- **Le pourquoi de chaque tâche** : projet, but, chemin (« Kai fabrique 6 engrenages → machine à vapeur → centrale →
  recherche Électronique »).
- **Annonces** (journal de la fenêtre, et une ligne du journal du mod) : projet ouvert, bloqué (et pourquoi), fini,
  préempté ; départ et retour d'expédition. Une faction n'annonce rien au joueur (brouillard) ; votre équipe vous parle.
- **Remontées des PNJ** (événements, sans attendre la pensée) : ennemi ou nid vu, gisement vu, PNJ tué, bâtiment
  perdu, chemin impossible. Une remontée grave (attaque, mort) avance la pensée suivante (au plus une pensée
  anticipée par 60 ticks).
- **Appel à l'aide** : un PNJ attaqué publie une tâche urgente « défendre ici » ; les règles de valeur (§2.3) y envoient
  les plus proches, pas toute l'équipe.

### 2.6 Qui décide quoi : chef, cerveau, organisation, PNJ

| Niveau | Question | Rythme | Code |
|---|---|---|---|
| Chef (IA2, gardé) | QUOI et POURQUOI : posture (technologie, armée, expansion…), horizon, rivale, raids | 1 / min | `shared/faction/chef.lua` |
| Cerveau (IA3, nouveau) | COMMENT et AVEC QUOI : buts, dépliage, méthode, réservations, tâches | 1 / 5 s, par phases | `shared/ai3/*` |
| Organisation (IA1, adaptée) | QUI : pôles, meneurs, score de la place de marché | 1 / 5 s, après le cerveau | `shared/team/org.lua` |
| PNJ (gardé, verbes étendus) | FAIRE : programmes d'étapes | au fil des ticks | `script/team/worker.lua` |

- Le chef ne commande plus un ORDRE d'échelle (`C.ladder_order`) : il donne des **poids** aux familles de buts. La
  personnalité (D-18 : « recherche ou armée d'abord selon le caractère ») passe par là : le technocrate pondère la
  recherche, le conquérant l'armée ; la mesure M2 d'IA2 (diversité des décisions) reste le garde-fou.
- Votre équipe : votre orientation (fenêtre, onglet « Orientation ») remplace le chef ; elle ne recherche pas (vous
  recherchez), mais elle sert vos buts (§3.1, buts de l'équipe du joueur).

## 3. L'algorithme générique

À ÉCRIRE

## 4. Les expéditions

À ÉCRIRE

## 5. Intégration, déterminisme, budget, migration, fenêtre

À ÉCRIRE

## 6. Plan de lots

À ÉCRIRE

## 7. Prototypes et tests hors jeu de la conception

À ÉCRIRE
