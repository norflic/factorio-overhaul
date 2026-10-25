# IA3 « le cerveau des PNJ » : conception (document qui fait foi)

Architecte de la section IA3, 25/10/2026. Décision du DC : D-18 (RD_LOG ; OBJECTIFS §4, R-QCM-25g). Phase CONCEPTION :
rien n'est branché dans le jeu.

## 0. En bref

**Ce que le cerveau actuel fait mal, et pourquoi** (chiffres d'IA3-DIAG, 6 parties de 2 h en moteur réel) :
1. Il suit une **échelle écrite à la main** (17 marches, une à la fois) : la recherche est la 8e marche, en priorité 40
   sous l'armée et les recrues, donc R3 arrive à 46 à 52 min au lieu de 12 à 36 possibles ; un gisement introuvable
   bloque toute la file jusqu'à 12 min.
2. Il ne sait pas qu'une recherche est **impayable** : 27 à 37 PNJ-minutes de packs jetés par faction pour une
   recherche 4 sans pétrole.
3. Ses PNJ sont **enfermés dans leur pôle** : 32 à 72 % d'inactifs au début, et dans 42 à 115 minutes sur 119, des PNJ
   attendent au QG pendant que des tâches attendent au tableau.
4. Rien n'est **réservé** d'une pensée à l'autre : 3 à 50 fois par équipe et par partie, un PNJ arrive au coffre et ce
   qu'on lui avait promis n'y est plus (la trace mesurée de « l'arrachage »).
5. Il **porte au lieu d'automatiser** (41 à 58 % du travail en tournées), **ne cherche jamais le pétrole**, et prospecte
   **sans brouillard**.
6. Les factions **ne paient pas la vraie recherche** : 290 packs pour des technologies qui en coûtent 6 415, dont une
   (`military-3`) qui exige le pétrole (mesuré par le prototype, §3.8).

**La conception (dix lignes)** :
1. Le **chef** (IA2, gardé) fixe le cap une fois par minute : des POIDS par famille de buts selon le caractère.
2. Des **générateurs de buts** (recherche, armée, défense, extraction au goulot, capital, exploration, réserve) lisent
   l'état et les données ; plus d'échelle (§3.1).
3. Chaque but se **déplie** sur le graphe recettes-technologies-machines-ressources par SIX méthodes génériques
   (prendre, main, machine, extraire, explorer, rechercher) : aucune règle par bâtiment (§3.2, prototype : 0 nom du jeu
   dans le code).
4. Un but **impayable** n'émet que ce qui ouvre la voie (explorer, rechercher) : plus de fabrication jetée (H8).
5. Les buts deviennent des **projets** qui durent, 2 à 10 en parallèle selon l'effectif ; un projet bloqué ne bloque
   personne ; le chemin critique passe devant (§3.5).
6. Un **registre** réserve la matière de chaque projet : prise stricte, préemption réglée et dite (§2.2).
7. Une **place de marché** : tout PNJ libre prend la tâche la plus utile qu'il sait faire ; le rôle oriente (+20 %),
   n'interdit plus (§2.3).
8. Le **solveur** d'IA1-e1 tranche fabriquer à la main, automatiser, agrandir, améliorer, construire ailleurs au retour
   sur investissement (§3.4).
9. Les **expéditions** évaluent la sécurité sur la carte vue, s'équipent (tourelles, munitions, grenades, escorte),
   posent leurs tourelles au contact, ou attendent ; le pétrole en est le premier cas (§4).
10. Tout est **déterministe**, découpé par phases (≤ 2 ms par tick en pointe, ≈ 0,1 ms en moyenne estimés), le même
    de l'âge 1 à l'âge 15 (§5).

**Plan** : 10 lots (§6), dont 3 jours de lots rapides (fondations, recherche d'abord, personne n'attend, effectif 8)
puis le nouveau cerveau, l'automatisation (avec IA1-d), l'exploration, les expéditions, le pétrole (palier 4 en
120 min ou moins) et les âges. 17 à 21 jours d'agents au total. Risque majeur : le plan directeur IA1-d (construction
automatisée à l'échelle) n'est pas prouvé ; tout ce qui suit l'automatisation en dépend.

**Sommaire** : §1 le joueur (H1 à H12) · §2 le groupe · §3 l'algorithme · §4 les expéditions · §5 intégration,
déterminisme, budget, migration, fenêtre · §6 lots et critères (K1 à K11) · §7 prototypes et ce qui n'est pas vérifié.
Résumé pour le DC : `fo-logs\2026-10-25_IA3\RESUME_DC.md`.

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

Exigence du DC : « on peut pas faire ça pour tous les bâtiments ». Donc : **aucune règle par bâtiment**, tout se
déduit des prototypes (recettes, technologies, entités, ressources), et le même code sert de l'âge 1 à l'âge 15.

### 3.0 Choix de l'algorithme, et pourquoi

| Famille | Ce qu'elle fait bien | Pourquoi pas seule ici | Retenu pour |
|---|---|---|---|
| GOAP (A* sur des états symboliques, F.E.A.R.) | enchaînements émergents de quelques actions | les QUANTITÉS (60 plaques, 1 080 packs) font exploser l'espace d'états ; nos plans font 45 étapes (recherche Automatisation) à 369 étapes (pack chimique) d'après le prototype, là où GOAP tient en pratique moins de 10 ; une recherche A* à égalités est instable d'une pensée à l'autre ; plan illisible pour la fenêtre | rien |
| HTN (décomposition par méthodes, SHOP, Horizon) | « obtenir X » se décompose naturellement sur le graphe des recettes ; temps linéaire ; plan lisible (chaîne des pourquoi) | ses méthodes s'écrivent d'habitude À LA MAIN, tâche par tâche : interdit par le DC | **l'ossature**, avec SIX méthodes génériques déduites des données |
| IA d'utilité (notes, courbes) | choisir entre des options concurrentes, varier selon un caractère | ne sait pas enchaîner | le choix des buts (chef, IA2, déjà là) et la place de marché (§2.3) |
| Solveur de débits (programme linéaire, IA1-e1) | machines, débits, retour sur investissement | ne choisit pas les buts | les débits et le choix « main, automatiser, agrandir, améliorer » (§3.4) |
| MRP et kanban (industrie) | besoins nets, réservations, tirer le travail | ne choisit pas les méthodes | la coordination du groupe (§2.2, §2.3) |
| Simulation (MCTS) | évaluer des futurs | coûteuse en Lua, tirages à semer, résultats instables | rien |

**Conclusion : une PLANIFICATION PAR BESOINS** = HTN générique (6 méthodes tirées des données) + utilité (quels buts,
qui fait quoi) + solveur de débits (combien) + registre MRP (qui a droit à quoi). Chaque brique existe déjà dans le
mod ou dans le prototype de ce lot, sauf le registre et la place de marché (prototypes testés, §7).

### 3.1 Les buts : des générateurs, pas une échelle

Chaque FAMILLE de buts a un générateur pur qui lit l'état et les données ; il rend des buts `{ famille, quoi, valeur
0 à 100, échéance }`. `valeur = base de la famille × poids du chef (pour mille) × urgence`. Le cerveau garde les
meilleurs (§3.5). Familles :

| Famille | Générateur (données lues) | Remplace |
|---|---|---|
| Recherche | technologie de meilleure `valeur ÷ coût` parmi celles dont les prérequis sont faits ou prévus ; valeur = recettes débloquées utiles aux buts ouverts (pack suivant, machine qui automatise une recette fréquente, meilleure arme ou tourelle, recette d'un but bloqué) + poids du chef (H9) | `T.research` (5 niveaux écrits à la main) et `T.unlocks` |
| Armée | effectif visé (posture du chef, menace : `P.army_target` gardé) ; type de soldat = le meilleur ÉQUIPEMENT dont tous les objets sont payables (table `T.kits`, données) | `P.best_unit` par niveau de recherche |
| Défense | règles d'IA1-b2 (QG d'abord, avant-poste défendu avant d'être agrandi) ; la tourelle = la meilleure tourelle dont la recette et la munition sont payables | marche « fortify » |
| Extraction | débits bruts demandés par les buts ouverts sur l'horizon (solveur) contre débits mesurés : le GOULOT (H2) ouvre une construction ou un agrandissement d'avant-poste, au site de meilleure valeur (IA2-b, `shared/faction/valeur.lua`) | marches « iron2 », « iron3 », « expand »… |
| Capital | automatiser une recette faite trop souvent à la main (H3), investir un stock dormant (H4), améliorer un niveau (MOD, niveaux) | rien (capitalisation nulle, IA3-DIAG §2.4) |
| Exploration | ressource inconnue requise par un but (H5, §4.1) ; curiosité au calme | rien (prospection sans brouillard) |
| Entretien, Réserve | tournées, fonderie, munitions des tourelles, charbon, une recrue d'avance (H10) | priorités fixes 95, 70, 60 |
| Survie | règles d'IA2-a2 et de VERIF-NUIT gardées telles quelles (recrue équipée au QG, fonderie reposée) | inchangé |

La personnalité passe par les poids du chef : pour une même partie, le technocrate ouvre la recherche suivante avant
le 2e lot de soldats, le conquérant l'inverse (D-18 : « selon le caractère »). Le hasard borné d'IA2 départage les buts
de valeur proche (à 90 % ou plus du meilleur).

### 3.2 Le dépliage : six méthodes déduites des données (prototype `shared/ai3/graphe.lua`)

Pour « obtenir N × objet », dans un état (stock, technologies, machines construites, ressources connues) :

| Méthode | Condition (lue dans les données) | Étapes émises |
|---|---|---|
| prendre | l'objet est au stock libre | `take` (une réservation, §2.2) |
| main | recette d'une catégorie que la main sait faire, solides seulement, un produit (règle du personnage vanilla, comme `shared/team/book.lua`) | ingrédients d'abord, puis `hand` |
| machine | sinon : une machine dont les catégories contiennent celle de la recette ; si l'équipe n'en a pas, la CONSTRUIRE (`build`) avec son énergie (électricité : une « ligne » qui la produit ; combustible : un approvisionnement) | `build`, `line`, `supply`, puis `produce` |
| extraire | l'objet est une ressource CONNUE ; un extracteur de sa catégorie (foreuse à combustible si possible, sinon électrique ; la main en dernier recours) | `build` de l'extracteur, `extract` |
| explorer | ressource INCONNUE | `explore` seulement (§4) |
| rechercher | recette verrouillée : la technologie qui la débloque, ses prérequis, ses packs, un laboratoire | `research` (après ses prérequis et un laboratoire) |

- **Fluides et électricité en capacité.** Un fluide n'est pas « fabriqué en quantité » : il faut une LIGNE qui le
  produit (pompe de rive pour l'eau, chaudière pour la vapeur, machine à vapeur pour l'électricité, raffinerie pour le
  gaz…). Les débits sont l'affaire du solveur d'IA1-e1. L'électricité est un pseudo-fluide produit par les générateurs
  (en jeu : les prototypes `generator`, `boiler`, `offshore-pump` le disent).
- **Cycles des recettes** (barils, craquage, liquéfaction) : deux points fixes sur tout le graphe : la FAISABILITÉ
  (plus petit point fixe : un cycle ne rend rien faisable) et le COÛT DE CHOIX (min-plus). Une recette qui consomme ce
  qu'elle produit (la liquéfaction demande de l'huile lourde) n'est pas un moyen d'OBTENIR cet objet.
- **Ce que le prototype montre, sans une ligne par bâtiment** (test `tests/ai3_graphe_test.lua`, 31 OK ; le test
  cherche les 825 noms d'objets, de bâtiments et de ressources du jeu dans le code du module : 0 trouvé) :
  - recherche « automation » depuis le kit de départ : pompe de rive, chaudière, machine à vapeur, foreuse de charbon
    pour la chaudière, laboratoire, 10 packs rouges à la main (1,5 PNJ-minute), recherche : 45 étapes ;
  - pack chimique AVEC pétrole connu : électricité, laboratoire, 12 recherches dans un ordre valide (automation,
    electronics, steel-processing, logistic-science-pack, automation-2, engine, fluid-handling, oil-processing,
    plastics, advanced-electronics, sulfur-processing, chemical-science-pack), assembleur (le moteur n'est pas
    fabricable à la main), acier, moteurs, usine chimique, raffinerie, chevalet sur le pétrole, plastique, soufre :
    369 étapes, 9 constructions ; le chemin d'un joueur vanilla ;
  - pack chimique SANS pétrole connu (règle H8, défaut C1) : impayable, cause « crude-oil », UNE exploration, les
    12 recherches (payables : elles ne demandent que des packs rouges et verts), et AUCUNE fabrication de moteur, de
    circuit avancé, de plastique, de soufre ni aucune construction de raffinerie, de chevalet ou d'usine chimique ;
  - même résultat, octet pour octet, si les recettes sont données dans l'ordre inverse (déterminisme).
- **Coût mesuré hors jeu** (Lua 5.2.4, PC non épinglé, 4 autres agents actifs : ordre de grandeur) : points fixes
  4,9 à 5,6 ms pour 273 recettes et 183 technologies (8 à 12 passes), refaits seulement quand l'état change ; un
  dépliage 1,0 à 1,5 ms. Découpage en jeu : §5.3.

### 3.3 Le coût d'une méthode

Le prototype choisit avec un coût simplifié (durée de recette + surcoûts). La version en jeu compte, pour chaque
méthode, trois termes dans une seule unité (le MU, prix de la PNJ-seconde lu au tableau, §2.3) :
- **travail** : PNJ-secondes (fabrication à la main = durée ÷ vitesse du PNJ ; tournées et portage = distance ÷ vitesse
  de marche × allers-retours ; construction = rythme de pose, `P.BUILD_TICKS_PER_ENTITY`) × prix fictif de la
  PNJ-seconde ;
- **matière** : MU des objets consommés et des bâtiments posés (`P.values`, solveur d'IA1-e1) ;
- **risque** : pertes attendues (PNJ, objets portés) sur le chemin et au site (§4.2), plus le surcoût des échecs passés
  (H11).
Choix : la méthode la moins chère par unité utile, avec 20 % d'inertie pour la méthode déjà engagée (comme
`P.HYSTERESIS`).

### 3.4 Fabriquer, automatiser, agrandir, améliorer, construire ailleurs

Une seule décision pour tout flux demandé par les buts (objets par minute sur l'horizon) : le solveur d'IA1-e1 la sait
déjà pour quatre options (`P.options`, `P.choose` : agrandir, améliorer d'un niveau, remplacer de palier, module neuf,
avec retour sur investissement `T = coût ÷ gain`). IA3 y ajoute :
- **à la main** : coût = charge de travail × prix fictif ; c'est l'option par défaut tant que la charge est faible ;
- **construire ailleurs** : un avant-poste sur un meilleur gisement, ou un bloc près d'une ressource lointaine
  (raffiner sur place, EQUIPES_PNJ §6.8) ; coût = construction + risque (§4) + trajets.
Règles de bascule (H3, H4) : automatiser quand la charge à la main dépasse 0,25 PNJ pendant 10 min et que `T ≤ H`
(20 min en sécurité, 5 min menacé, horizon du chef) ; agrandir quand un module est en « capacité » (diagnostic
d'IA1-e1) ; améliorer quand l'emprise manque ou que le plafond d'entités approche (« grandir en hauteur », IA2) ;
construire ailleurs quand le gisement est épuisé, trop loin, ou que la ressource n'existe pas au QG.
L'IMPLANTATION (où poser, comment brancher) reste au plan directeur (IA1-d) : IA3 exige des gabarits PARAMÉTRIQUES (une
rangée de machines de taille et de boîtes à fluide lues dans le prototype, bras, tapis), pas un gabarit par bâtiment.

### 3.5 Projets en parallèle, chemin critique

- Un **projet** = un but retenu, sa méthode, ses réservations, ses tâches, son meneur, son état (préparation, en cours,
  bloqué, fini). Il SURVIT d'une pensée à l'autre (fin du « tout recalculé toutes les 5 s » qui fait C2).
- **K projets ouverts** : `K = 2 + ⌊PNJ ÷ 4⌋`, au plus 10 (4 PNJ : 3 projets ; 8 PNJ : 4 ; 30 PNJ : 9). Les buts de plus
  forte valeur ; à valeur proche, le hasard borné ; un projet engagé garde 20 % d'inertie.
- **Un projet bloqué ne bloque personne** : il rend ses PNJ, garde ses réservations (sauf préemption), et sa cause
  devient un but (explorer, rechercher) : fin des 12 min de patience de C5.
- **Chemin critique** : la plus longue chaîne d'étapes restantes (en secondes) ; ses tâches valent × 1,5 au marché.
  C'est ce qui fait qu'à 8 PNJ, les packs d'une recherche et la construction du laboratoire avancent EN MÊME TEMPS.
- **Découpage du travail** : les étapes de même nature et de même objet sont regroupées, puis coupées en lots
  d'environ 30 s de fabrication (comme `CHUNK_SECONDS` aujourd'hui), pour que plusieurs PNJ avancent un même projet.

### 3.6 Effectif

8 PNJ par faction au départ (D-18). Une recrue quand le prix fictif de la PNJ-seconde reste au-dessus du seuil pendant
2 min (du travail utile attend) ET que la recrue se paie (`O.recruit_cost`) ; plus de recrue quand des PNJ sont libres
sans travail. C'est la règle d'IA1-b2 (« du travail qui attend lève le frein »), généralisée aux factions.

### 3.7 Identique de l'âge 1 à l'âge 15

Le cerveau ne nomme aucune époque :
- le verrou d'époque est une technologie (`fo-epoch-k`, `X.epoch_lock`) ; sa « recherche » a pour méthode « payer le
  niveau du centre » (monnaies de `X.currencies`, coût lu dans `shared/levels/config.lua`) : une 7e méthode générique,
  `level`, quand le lot des époques des factions (IA3-i) arrive ;
- une ressource nouvelle (tungstène, cristal, méthane, titane…) est une ressource de plus : explorer, extraire ;
- un bâtiment nouveau est une machine de plus : ses catégories le rendent utilisable ;
- les packs de chaque époque (`X.epochs[k].pack`) sont des objets comme les autres.
Mesure du DC « factions qui passent les âges » : §6, lot IA3-i.

### 3.8 Fait mesuré par le prototype : les factions ne paient pas la vraie recherche

Le test calcule le coût RÉEL (prototypes vanilla 1.1.91) des technologies que les factions reçoivent aujourd'hui à
chaque niveau (`T.unlocks`, `shared/team/config.lua:146`) contre ce qu'elles paient (`T.research`) :

| Niveau | Payé (packs) | Coût réel des technologies reçues (packs) |
|---|---|---|
| 0 (au départ) | 0 | 30 |
| 1 | 30 | 395 |
| 2 | 90 | 2 640 |
| 3 | 170 | 3 350, dont 100 packs CHIMIQUES (`military-3`) |
| 0 à 3 | 290 | 6 415 (22 fois plus) |

Deux conséquences, dites franchement :
1. Aujourd'hui, une faction au niveau 3 a des technologies militaires qu'aucun joueur ne peut avoir sans pétrole.
2. Un cerveau qui « joue comme un joueur » paie la VRAIE recherche : 1 080 packs rouges et 915 verts pour atteindre le
   pack chimique (prototype, prérequis compris), soit environ 233 PNJ-minutes de fabrication à la main, ou des
   assembleurs. Les factions iront donc moins vite en « niveaux » au début, et plus vite ensuite (automatisation,
   pétrole). Les critères (§6) sont écrits en vraies technologies, pas en niveaux.

## 4. Les expéditions

Demande du DC (R-QCM-25g) : « ils doivent se débrouiller pour chercher du pétrole, comme les joueurs quoi, mais peut
être que pour aller chercher du pétrole les IA évaluent la sécurité d'abord, donc peut être s'équiper en grenade ou
tourelle et munitions histoire de si ils sont attaqué ils peuvent les poser pour se défendre ».

Une expédition est un PROJET (§3.5) comme un autre : elle a un but (un gisement ou une ressource à trouver), des
réservations (l'équipement), des tâches (préparer, marcher, construire, tenir), un meneur. Elle naît du dépliage : une
étape `explore` (ressource inconnue) ou un site connu mais lointain ou dangereux.

### 4.1 Trouver, sous le brouillard

**Ce que l'équipe sait.** Le tableau commun (§2.1) garde une carte de CONNAISSANCE par secteurs de 64 × 64 tuiles,
la même grille que les yeux d'IA2-c (`script/faction/vision.lua`) : pour chaque secteur vu, la date, les gisements vus
(ressource, quantité estimée, centre), les nids et les vers vus, l'eau, les bâtiments et tourelles d'autres forces.
Les YEUX de l'équipe : son QG (160 tuiles), ses avant-postes (128), ses groupes (96), ses éclaireurs (128) comme
aujourd'hui, PLUS chacun de ses PNJ en déplacement (48 tuiles, nouveau). « Regarder » un secteur coûte un comptage du
moteur (`count_entities_filtered` sur les types `resource`, `unit-spawner`, `turret`), à tour de rôle, comme la voie
de repérage d'IA2-c (1 regard toutes les 8 ticks pour tout le mod aujourd'hui).
- La prospection d'avant-postes (`script/faction/sites.lua`) ne cherche plus que dans les secteurs VUS (fin de la
  prospection sans brouillard, écart à D-16 déclaré au §1, H5).
- Pour ne pas ralentir le début, un « tour du propriétaire » à la création : un PNJ fait un anneau de 150 tuiles
  autour du QG dans les 5 premières minutes, comme un joueur.

**Où chercher une ressource inconnue.** Le secteur NON VU de meilleure note :
`note = probabilité a priori × sécurité ÷ (distance au QG + 100)`
- probabilité a priori : fréquence et taille de la ressource dans les réglages de génération de la carte
  (`surface.map_gen_settings.autoplace_controls[ressource]`) ; une ressource rare au centre de départ (le pétrole
  vanilla) a une probabilité qui croît avec la distance au point de départ de la carte ;
- sécurité = 1 − risque estimé du secteur (nids vus dans les voisins) ;
- l'éclaireur suit une SPIRALE de secteurs autour de la meilleure direction, rentre quand il a trouvé, quand il voit un
  ennemi à moins de 40 tuiles (il fuit vers le QG et note le danger), ou au bout de 10 min.
**Qui explore.** Un PNJ ouvrier libre (il voit, il sait fuir, il sait revenir : locomotion d'IA1), jamais le meneur
d'un projet ; un soldat seul se fait tuer près de certains QG (F235). Coût d'un tour de 600 tuiles de rayon : environ
3 800 tuiles de marche, 7 min (vitesse d'un personnage, environ 9 tuiles par seconde).

### 4.2 Évaluer la sécurité (prototype `shared/ai3/expedition.lua`)

Le risque d'un site (pour mille, plafonné à 1 000) ne lit que ce que l'équipe SAIT :

| Terme | Poids | Source |
|---|---|---|
| nids vus à moins de 64 tuiles du site | 100 par nid, 40 par ver | carte de connaissance |
| nids vus près du chemin | 50 par nid | secteurs traversés |
| inconnu autour du site | 200 × part des secteurs voisins non vus | carte de connaissance (prudence face à l'inconnu) |
| pertes récentes sur place | 150 par PNJ tué, décroissance 10 % par minute | mémoire H11 (IA1-b2 : avant-poste meurtrier) |
| territoire d'une faction ennemie | 300 | zones vues, IA2-c |
| distance au QG | 50 par tranche de 100 tuiles | temps d'exposition |

Décision (seuils multipliés par la PRUDENCE du caractère, IA2-0 : 500 neutre, 800 prudent : seuils − 30 %,
200 audacieux : + 30 %) :

| Risque | Action | Équipement (réservé au registre, §2.2) |
|---|---|---|
| < 150 | **léger** : les constructeurs partent seuls | arme et 10 chargeurs (l'équipement de l'ouvrier) |
| 150 à 400 | **équipé** : ils emportent de quoi tenir | 2 tourelles, 20 munitions par tourelle, 5 grenades, un PNJ de plus |
| 400 à 700 | **escorté** : des soldats ouvrent la route | 4 tourelles, 30 munitions par tourelle, 10 grenades, 8 soldats devant |
| ≥ 700, ou perte attendue > moitié de la valeur | **nettoyer** si le caractère est agressif (≥ 600) et l'armée suffit (2 soldats par nid ou ver, + 5) ; sinon **attendre** : chercher un autre site, réévaluer toutes les 5 min | — |
| équipement voulu mais pas payable | **préparer** : le projet fabrique d'abord tourelles, munitions, soldats | — |

- L'équipement est tiré des DONNÉES : la meilleure tourelle PAYABLE (dépliage, §3.2), la meilleure munition de SA
  catégorie, la meilleure grenade ; aucun nom d'objet dans le module (contrôlé par le test).
- Perte attendue = risque × (PNJ exposés × 60 MU + valeur de l'équipement) ; valeur du site = valeur des buts qu'il
  débloque (le pétrole débloque tout l'âge suivant : valeur haute).
- Exemple chiffré par le prototype (le cas du §4.5) : 2 nids et 3 vers près d'un champ de pétrole à 380 tuiles, un nid
  près du chemin, 60 % des secteurs voisins vus : risque 600 (nids 320, chemin 50, inconnu 80, distance 150) ; bande
  escortée ; avec 3 soldats disponibles sur 8 voulus, « préparer » ; avec 10, départ escorté de 8. Le même site rend
  un PRUDENT plus équipé qu'un AUDACIEUX, et un site infesté (6 nids, 6 vers) fait NETTOYER le conquérant et ATTENDRE
  le pacifique (test `tests/ai3_expedition_test.lua`, 15 OK).

### 4.3 Partir : le convoi et le réflexe de la tourelle

- **Convoi** : le meneur (un généraliste), les constructeurs, les porteurs, l'escorte. L'escorte est un groupe de
  soldats du moteur, menée par petits bonds (au plus 56 tuiles, F213 ; un long `go_to_location` échoue dans une base
  ennemie, F172) ; les PNJ suivent le meneur ; regroupement tous les 100 tuiles (personne à plus de 20 tuiles).
- **Le réflexe de la tourelle (votre idée)** : un PNJ qui PORTE des tourelles et voit un ennemi à moins de 24 tuiles
  (`find_enemy_units`, une fois toutes les 30 ticks par porteur, seulement pendant une expédition) pose une tourelle sur
  la case libre la plus proche entre lui et la menace (`can_place_entity`, puis `create_entity` par script, comme la
  pose « fortify » d'aujourd'hui), la remplit, se bat à côté ; les autres PNJ du convoi se regroupent autour. Menace
  partie (aucun ennemi à 40 tuiles pendant 10 s) : la tourelle est REPRISE (`LuaEntity.mine` avec l'inventaire du
  PNJ, API 1.1.91 vérifiée dans `runtime-api.json`) si elle est sur le chemin, sinon laissée comme jalon défendu.
  Grenades : lancées sur un groupe d'au moins 3 ennemis à portée (le PNJ en a ; à vérifier en moteur réel, risque §6).
- **À l'arrivée** : les tourelles d'abord (règle d'IA1-b2 « défendre d'abord » : 1 + foreuses ÷ 8), puis la
  production ; l'escorte reste jusqu'à ce que les tourelles soient posées et pleines.

### 4.4 Tenir l'avant-poste

- Défense permanente : les tourelles posées ; une tournée de munitions (tâche « refill », urgente sous le seuil) ; une
  réparation (packs de réparation) quand une tourelle passe sous 50 %.
- Perdu une fois : le site devient MEURTRIER (+ 300 de risque pendant 20 min, H11), l'expédition suivante monte d'une
  bande ; perdu deux fois en 30 min : chercher un autre site ; c'est la mémoire du chef (IA2-a, sites perdus) qui le
  porte.
- Un avant-poste lointain n'est pas « gardé » par des PNJ (IA1-b2 a coupé les gardes : 13 à 30 % d'immobilisés,
  IA3-DIAG C7) : ce sont les tourelles qui gardent.

### 4.5 Le pétrole, déroulé

1. Le dépliage du pack chimique dit : impayable, cause « crude-oil » (§3.2) ; il émet `explore crude-oil` ET les 12
   recherches payables. L'exploration devient un projet de forte valeur (elle débloque l'âge suivant).
2. Un éclaireur part vers les secteurs non vus les mieux notés ; il trouve du pétrole à 380 tuiles au nord-est, et voit
   2 nids et 3 vers à 50 tuiles.
3. Risque 600 : escorté. Le projet réserve 4 tourelles, 120 munitions, 10 grenades ; il demande 8 soldats à l'armée
   (le chef les compte comme « expédition », pas comme attaque) ; pendant ce temps la recherche continue.
4. Départ quand tout est prêt (pas avant : c'est « préparer »).
5. En route, des biters attaquent : un porteur pose 2 tourelles, le convoi se regroupe, les tourelles sont reprises.
6. Au champ : 2 tourelles, puis 2 chevalets ; la raffinerie et l'usine chimique sont posées PRÈS du champ (raffiner sur
   place, EQUIPES_PNJ §6.8) ; l'électricité vient d'une ligne de poteaux depuis la centrale ou d'une petite centrale à
   l'eau la plus proche, au moins cher des deux (§3.3) ; le plastique et le soufre rentrent au QG portés (puis par
   tapis, règle d'automatisation).
7. L'avant-poste tient par ses tourelles et une tournée de munitions ; le pack chimique devient payable ; la recherche
   de l'âge 4 reprend.

### 4.6 Ce qui reste à prouver en moteur réel (lots IA3-f, IA3-g)

- Le comptage par secteur pour la connaissance (coût par regard, déjà mesuré pour IA2-c : 0,0043 ms par tick pour la
  voie de repérage) et le nombre de regards en plus pour les PNJ en déplacement.
- Pose d'une tourelle par script près d'ennemis qui bougent (collision avec un biter : `can_place_entity` refuse ; on
  essaie 4 cases), reprise par `mine`, munitions conservées.
- Un groupe d'escorte de 8 qui ne se disperse pas (F173, F174 : membres retirés d'un groupe sans événement).
- Le coût d'un convoi sur la locomotion (chemins plus longs : demandes de chemin du mod en vol).

## 5. Intégration, déterminisme, budget, migration, fenêtre

### 5.1 Ce qui est gardé, remplacé, supprimé

| Fichier ou mécanisme | Sort | Détail |
|---|---|---|
| `script/team/worker.lua` (programmes d'étapes, verbes) | **gardé**, verbes ajoutés | nouveaux : `explore` (spirale de secteurs), `deliver` (packs aux laboratoires), réflexe de tourelle en expédition, `pickup` (reprise par `mine`) ; la prise au coffre passe par le registre (stricte) |
| `script/team/board.lua` | **gardé** (stockage des tâches) | `Board.claim` appelle la place de marché ; `Board.sync` ne remplace plus que les tâches des projets replanifiés |
| `shared/team/production.lua` (solveur IA1-e1) | **gardé** | débits, valeurs en MU, options et retour sur investissement (§3.4) ; « à la main » et « ailleurs » ajoutés |
| `shared/team/modules.lua` (gabarits IA1-c) | **gardé**, rendu paramétrique par IA1-d | une rangée par catégorie de machine, dimensions lues dans les prototypes |
| `shared/team/book.lua` | **gardé** | produit les étapes de fabrication à la main d'une tâche `craft` (format attendu par `worker.lua`) |
| `shared/team/org.lua` (pôles, managers, généralistes) | **gardé**, une règle changée | `O.pick_task` (rangs : pôle obligatoire) remplacé par le score du marché (§2.3) ; `O.pole_targets`, généralistes, promotion, rangs : inchangés |
| `shared/team/fond.lua` | **gardé**, rôle changé | ses candidats deviennent les investissements par défaut (famille Capital) |
| `shared/team/scale.lua` | **gardé** | effectif de départ des factions 4 → 8 (D-18 ; fichier de l'intégrateur pour le réglage) |
| `shared/faction/chef.lua`, `traits.lua`, `valeur.lua`, `adversaire.lua` (IA2) | **gardés** | le chef rend des POIDS de familles au lieu d'un ordre d'échelle (`C.ladder_order` retiré) ; prudence et agressivité servent aux expéditions |
| `script/faction/vision.lua` (IA2-c) | **gardé**, étendu | les PNJ en déplacement deviennent des yeux (48 tuiles) ; la carte de connaissance alimente le cerveau |
| `script/faction/sites.lua` | **gardé**, restreint | ne prospecte que dans les secteurs vus |
| `script/gui/team_window.lua` | **gardé**, complété | §5.5 |
| `shared/team/planner.lua` (échelle, priorités fixes) | **remplacé** puis **supprimé** | par `shared/ai3/cerveau.lua` (générateurs de buts, dépliage, projets) ; gardé derrière un réglage jusqu'à la preuve (§5.4) |
| `T.ladder`, `T.player_ladder`, `T.research`, `T.unlocks`, `T.goal_patience`, `T.goal_defer` | **supprimés** après migration | la recherche devient la VRAIE recherche (§3.8) ; plus d'échelle ni de patience |
| `unlock()` et le paiement des niveaux (`script/team/team.lua:82`, `:440`) | **remplacés** | `LuaForce.add_research` et des laboratoires livrés en packs par les PNJ (§5.2) |
| prises larges au coffre (fonderie, recharge, charbon) | **remplacées** | réservations du projet permanent « Entretien » (§2.2) |

Nouveaux fichiers (lots d'implémentation) : `shared/ai3/graphe.lua`, `registre.lua`, `marche.lua`, `expedition.lua`
(prototypes de ce lot, à durcir), `shared/ai3/buts.lua` (générateurs), `shared/ai3/projets.lua`, `shared/ai3/cerveau.lua`
(pensée par phases), `shared/ai3/connaissance.lua` (carte vue) ; `script/ai3/*.lua` pour l'exécution ;
`locale/fr/ia3.cfg`, `locale/en/ia3.cfg`.

### 5.2 La vraie recherche des factions

- Une faction recherche une technologie RÉELLE (`LuaForce.add_research`, file de sa force) ; ses PNJ construisent des
  laboratoires (méthode `research`, §3.2) et y livrent les packs (verbe `deliver`, ou un bras quand l'automatisation le
  justifie) ; le MOTEUR fait avancer la recherche, au temps réel des prototypes.
- **À vérifier en moteur réel avant tout** (lot IA3-0, expérience E180) : une force sans joueur qui a une recherche en
  cours et des laboratoires alimentés progresse ; `research_finished` est levé. Repli si non : le QG consomme les packs
  au coût réel et au temps réel (`unit.time × count ÷ laboratoires`), sans laboratoire du moteur.
- Les factions gardent ce qu'elles ont déjà reçu dans une partie en cours (§5.4) ; aucune technologie n'est retirée.

### 5.3 Déterminisme et budget de calcul

**Déterminisme** (ARCHITECTURE §2) :
- listes triées partout (projets par identifiant croissant, objets et recettes par nom, tâches par clé, PNJ par
  identifiant) ; aucune décision sur l'ordre de `pairs` (les prototypes de ce lot le respectent et le testent : mêmes
  sorties pour des entrées dans l'ordre inverse) ;
- hasard : seulement les flux d'IA2 (`Tr.new_stream`, mélange non linéaire, multiplication modulo exacte), sels 400 à
  499 réservés à IA3 ;
- le catalogue (index des prototypes) est un cache LOCAL, construit au premier usage dans un événement (jamais dans
  `on_load`), identique chez tous les pairs (mêmes prototypes, ordre trié) ; `global` ne garde que des nombres, chaînes
  et tables : projets, registre, connaissance, expéditions ;
- aucun `require` pendant un événement (F24) ; aucune décision sur un temps mesuré ;
- preuve : deux passages de la même graine, empreintes `[FO-HASH]` identiques à 30 min (C5-9, F238).

**Budget** (A1 : 1,5 ms par tick au plus en moyenne ; mesuré aujourd'hui : 0,066 à 0,078 ms par tick pour 150 PNJ, E124 ;
une pensée d'équipe 0,62 ms, ia0-normal). Estimations IA3 (mesures hors jeu du prototype, PC non épinglé, à confirmer
en moteur réel épinglé) :

| Poste | Hypothèse | ms par tick (moyenne) | Pic par tick |
|---|---|---|---|
| Points fixes (faisabilité, coût) | 5 ms par changement d'état, environ 1 par minute et par équipe, 5 équipes | 0,007 | ≤ 0,6 (une passe par tick, 8 à 12 passes) |
| Dépliages | 1 à 1,5 ms par projet replanifié, environ 2 par pensée et par équipe | 0,05 | ≤ 1,5 (un dépliage par tick pour tout le mod) |
| Registre (allocation) | projets × objets, < 0,1 ms par pensée | 0,002 | 0,1 |
| Place de marché | prise d'un PNJ libéré : 64 tâches × environ 1 µs ; 150 PNJ, une tâche par minute chacun | 0,003 | 0,1 |
| Attribution globale (plusieurs PNJ libres à la fois) | ≤ 2 000 couples, environ 1 ms | 0,02 | 1 |
| Connaissance (regards des PNJ) | file commune, 1 regard toutes les 8 ticks (comme IA2-c) | 0,005 | 0,05 |
| Réflexe de tourelle | 10 porteurs × 20 µs ÷ 30 ticks | 0,007 | 0,2 |
| **Total ajouté par IA3** | | **≈ 0,1** | **≤ 2 ms** (règle : une seule phase lourde par tick pour tout le mod) |

Avec l'existant (0,07 à 0,08), le script resterait vers 0,2 ms par tick pour 150 PNJ, soit 13 % du budget A1. Aucun de
ces chiffres n'est une mesure en jeu : chaque lot les mesure (`ia1-scale` épinglé, `analyze.py --spikes`).

### 5.4 Migration des parties en cours

- Réglage de carte `fo-ia3-cerveau` (oui par défaut dans une partie neuve) : tant que les lots IA3-a à IA3-c ne sont
  pas prouvés, l'ancien cerveau reste disponible, ce qui permet aussi les bancs « avant / après » sur la même source.
- Au premier passage (`on_configuration_changed`, F130 : appelé aussi quand seul le contenu change) :
  - les technologies déjà reçues restent (pas de retrait : les armées en dépendent) ; une ligne du journal dit
    « Azur : avance de recherche héritée (niveau 2 de l'ancien système) » ;
  - l'échelle (`done`, `deferred`, `goal`) est oubliée ; les avant-postes, la fonderie, les tourelles restent tels
    quels (ce sont les lignes d'extraction du nouveau cerveau) ;
  - le registre démarre vide (tout le stock est libre), la première pensée alloue ;
  - les tâches LIBRES du tableau sont retirées ; les tâches PRISES vont à leur terme (leurs programmes sont chez les
    PNJ) ;
  - la carte de connaissance démarre avec les secteurs que les yeux d'IA2-c ont déjà vus, plus les gisements des
    avant-postes existants.
- Preuve : banc en double source (`FO_CREATE_SRC` = source 0.4.28 ou la dernière avant IA3), comme `ia1b-migration`.

### 5.5 Ce que montre la fenêtre « Équipe et factions »

Principe : le joueur voit des INTENTIONS et des RAISONS, jamais un script ; aucun faux chiffre (règle d'IA1-i).
- **Mon équipe** : les projets en cours (nom, pourquoi, avancement, meneur), ce qui est réservé, ce qui bloque et
  pourquoi (« attend du pétrole : un éclaireur cherche au nord-est »), le prix du travail (« 3 tâches attendent des
  bras » : signal de recrutement) ; le journal (annonces, §2.5).
- **PNJ** : la tâche de chaque PNJ et sa raison courte (« packs verts → recherche Automatisation 2 »).
- **Chantiers** (aujourd'hui « à venir ») : projets et expéditions : destination, risque et sa raison (« 2 nids vus »),
  bande (équipé, escorté), équipement réservé, état (préparer, en route, sur place, tenu).
- **Territoire** (avec IA1-g) : gisements connus, dangers connus.
- **Factions** : l'âge, la recherche en cours et le projet dominant de chaque faction (le DC juge leur progression ;
  une version « sous brouillard » qui ne montre que ce que vous avez vu reste possible, à trancher plus tard).
- Captures à chaque lot qui touche la fenêtre, verdict du DC.

## 6. Plan de lots

### 6.1 Mesures communes et critères d'acceptation de la section

**Paliers de recherche, en vraies technologies** (prototype, `G.tech_packs`, prérequis compris, vanilla 1.1.91) :
le palier k est atteint quand la technologie qui débloque le k-ième pack est recherchée ET que 10 de ces packs sont
fabriqués (40 pour le palier 4, comme l'ancien niveau 4).

| Palier | Technologie | Technologies | Packs (rouges + verts) | Secondes de laboratoire (un laboratoire) |
|---|---|---|---|---|
| 1 | `automation` | 1 | 10 + 0 | 100 |
| 2 | `logistic-science-pack` | 1 | 75 + 0 | 375 |
| 3 | `military-science-pack` | 6 | 195 + 50 | 1 625 |
| 4 | `chemical-science-pack` (pétrole) | 12 | 1 080 + 915 | 21 275 (6 à 10 laboratoires pour tenir 90 min) |

Pendant les lots rapides (IA3-a, IA3-b), l'ancien système de niveaux reste en place : les critères y sont écrits en
NIVEAUX (R1 à R3, comme IA3-DIAG) ; à partir d'IA3-c, en PALIERS.

**Critères de la section** (chacun mesuré en moteur réel par les outils d'IA3-DIAG, `tools/autotest/ia3d_*`, sur au
moins 2 graines, 4 quand la partie diverge, F252) :

| ID | Critère | Aujourd'hui (IA3-DIAG) | Visé | Lot |
|---|---|---|---|---|
| K1 | recherche 3 (niveau R3, puis palier 3) | 46 à 52 min (médianes), 3 factions sur 12 jamais | **≤ 25 min** (4 PNJ) ; ≤ 20 min (8 PNJ) | IA3-a, puis IA3-c |
| K2 | recherche 4 AVEC pétrole (palier 4) | jamais | **≤ 120 min**, 8 PNJ, Normal, 4 graines sur 5 | IA3-h |
| K3 | PNJ inactifs | 32 à 72 % (0-10 min), votre équipe 52 à 65 % (0-60 min) | **≤ 15 %** de 30 à 90 min ; ≤ 20 % de 0 à 10 min | IA3-b |
| K4 | ressource « arrachée » | 3 à 50 échecs « stock » par équipe en 2 h | **0** échec « stock » ; préemptions seulement par règle (§2.2), chacune au journal | IA3-b |
| K5 | PNJ immobiles au QG pendant que du travail attend | 42 à 115 minutes sur 119 (8 factions sur 12) | **≤ 5 minutes sur 119** | IA3-b |
| K6 | fabrication jetée (packs d'une recherche impayable) | 27 à 37 PNJ-minutes par faction | **0** | IA3-a |
| K7 | tournées à pied | 41 à 58 % du travail (4 PNJ) | **≤ 15 %** à 90 min | IA3-e |
| K8 | factions qui passent les âges | plafond au niveau 3 | âges 2, 3, 4 à ± 25 % du calendrier X0 (0,5 h, 1,5 h, 3 h), 3 graines | IA3-i |
| K9 | garde-fous | `pvp_test` 1 305 OK, `verif-guide` 15 OK | **`pvp_test` : ordre strict des attaques par difficulté tenu** (attentes recalées, jamais affaiblies) ; `verif-guide` 15 OK sur les graines du guide où il l'était avant le lot ; aucune faction anéantie avant 60 min, au plus 1 sur 16 en 2 h (IA2-a2) | tous |
| K10 | budget | script 0,07 à 0,08 ms par tick (150 PNJ, E124) | ≤ 0,25 ms en moyenne, p99 du script ≤ 2 ms (banc épinglé) | tous |
| K11 | déterminisme | empreintes égales (F238) | `[FO-HASH]` égales à 30 min sur 2 passages | tous |

### 6.2 Les lots, dans l'ordre

**IA3-0 · Fondations (pur, plus 2 expériences en moteur réel).** 1 jour.
- Contenu : durcir les prototypes (`graphe`, `registre`, `marche`, `expedition`) ; adaptateur « prototypes du jeu →
  catalogue » (`script/ai3/catalogue.lua`) et contrôle : le catalogue tiré de `game.*_prototypes` dans le banc rend le
  même dépliage que la fixture hors jeu ; expériences **E180** (une force sans joueur recherche avec des laboratoires
  du moteur : `add_research`, progression, `research_finished`) et **E181** (pose d'une tourelle par script près de
  biters en mouvement, reprise par `mine`, munitions gardées).
- Fichiers : `shared/ai3/*`, `script/ai3/catalogue.lua`, scénario greffé `ia3-risques`, `tests/ai3_*_test.lua`.
- Preuve : tests hors jeu verts ; `ia3-risques` « BILAN : n OK » ; aucune règle de jeu changée (`content` 331 OK).
- Risque : E180 négatif → repli « le QG consomme les packs au coût et au temps réels » (§5.2), écrit dans le lot.

**IA3-a · Recherche d'abord, rien d'impayable (dans l'ancien cerveau).** Une demi-journée.
- Contenu : packs demandés dès le départ (verrou de la marche « tech1 » levé) ; priorité de la recherche selon le
  caractère (poids du chef) au lieu de 40 fixe ; plafond de 10 packs par sorte levé ; aucun pack d'un niveau dont un
  pack est impayable (test de faisabilité du prototype, générique).
- Fichiers : `shared/team/planner.lua`, `shared/team/config.lua` (fichier de l'intégrateur pour les constantes).
- Preuve : `ia3d-reduit` et `ia3d-default`, 2 graines ; `pvp_test`, `chef_test` ; `verif-guide` 2 graines.
- Critères : R1 ≤ 5 min, R2 ≤ 12, **R3 ≤ 25 (4 PNJ), ≤ 20 (8 PNJ)** (K1) ; K6 = 0 ; K9.
- Risque : armée plus lente au début (IA2-a2 à rejouer) ; ordre strict de `pvp_test` (listes de tâches changées).

**IA3-b · Personne n'attend, personne n'arrache (registre et place de marché).** 1 jour.
- Contenu : `Board.claim` par le score du marché (factions ET votre équipe, après fusion d'IA1-b2) ; registre des
  réservations : prise stricte, prises larges remplacées par le projet « Entretien », préemption réglée et journalisée ;
  minage à la main par plusieurs PNJ quand une plaque manque.
- Fichiers : `script/team/board.lua`, `script/team/worker.lua` (prise), `shared/team/org.lua` (`O.pick_task`),
  `shared/ai3/registre.lua`, `shared/ai3/marche.lua`.
- Preuve : `ia3d-*` 2 graines ; `ia1-poles` ; `org_test`, `pvp_test`.
- Critères : **K3, K4, K5** ; `ia1-poles` occupation ≥ 85 % ; K9.
- Risque : plus de PNJ hors du QG = plus de morts (F239) : mesurer les morts par heure (pas pire qu'avant de 10 %).

**IA3-d · Effectif 8 (avec IA3-b).** Une demi-journée.
- Contenu : 8 PNJ par faction au départ (D-18) ; recrue quand du travail attend (prix fictif > seuil 2 min).
- Preuve et critères : `ia1b-scale30` contre `ia1b-scale10` ≥ 1,2 (aujourd'hui 0,95 à 1,07) ; K9, K10.

**IA3-c · Le cerveau par besoins (buts, dépliage, projets, vraie recherche).** 2 à 3 jours.
- Contenu : `shared/ai3/buts.lua`, `projets.lua`, `cerveau.lua` (pensée par phases) remplacent `planner.lua` derrière le
  réglage `fo-ia3-cerveau` ; K projets en parallèle, chemin critique ; vraie recherche (laboratoires, §5.2) ;
  migration (§5.4) ; fenêtre : projets, raisons (§5.5).
- Preuve : `ia3d-*` 4 graines, avant / après sur la même source (réglage) ; banc de migration en double source ;
  captures de la fenêtre.
- Critères : palier 1 ≤ 6 min, palier 2 ≤ 12 min, **palier 3 ≤ 25 min** (8 PNJ) ; au moins 3 projets productifs en
  même temps à 8 PNJ ; K3 tenu ; K6 = 0 ; variété IA2 (mesures M1, M2) pas pire ; K9, K10, K11.
- Risque : le plus gros changement de comportement ; vraie recherche plus chère (§3.8) : début plus lent en
  « niveaux » ; à surveiller dès 10 min (palier 1 ≤ 6 min).

**IA3-e · Automatiser ce qui sert souvent (avec le plan directeur IA1-d).** 3 à 4 jours.
- Contenu : règle « main → machine » (§3.4) ; gabarits PARAMÉTRIQUES ; centrale, poteaux ; laboratoires alimentés par
  bras ; foreuses électriques et tapis vers la fonderie (fin des tournées).
- Preuve : `ia1-build` (IA1-d) 5 graines ; `ia3d-*`.
- Critères : **K7** ; au moins 3 modules dont la production tient 5 min sans PNJ à 45 min (C5-3 a) ; capitalisation
  (mesure M3 d'IA2) > 0 ; 30 contre 10 ≥ 1,2.
- Risque : dépend d'IA1-d (pose des fantômes à l'échelle, F26 à F28 : risque R13 d'EQUIPES_PNJ).

**IA3-f · Exploration sous brouillard.** 1,5 jour (en parallèle d'IA3-c possible).
- Contenu : carte de connaissance, PNJ yeux, prospection dans les secteurs vus, éclaireurs, tour du propriétaire.
- Preuve : scénario greffé `ia3-brouillard` (5 graines).
- Critères : 0 site pris dans un secteur jamais vu (contrôle du banc) ; pétrole trouvé moins de 30 min après l'étape
  `explore` sur 5 graines sur 5 ; morts d'éclaireurs ≤ 1 par heure et par faction ; 2e gisement de fer pas plus de 5 min
  plus tard qu'avant le lot.

**IA3-g · Expéditions évaluées.** 2 à 3 jours.
- Contenu : §4 en entier (risque, équipement réservé, convoi, réflexe de la tourelle, tenue de l'avant-poste).
- Preuve : `ia3-expedition` (scénario : site à 380 tuiles, 2 nids, 3 vers ; 5 graines) ; captures du convoi et des
  tourelles posées.
- Critères : aucun départ sans l'équipement de sa bande ; réflexe de la tourelle dans la seconde du contact (100 % des
  contacts du banc) ; morts par expédition ≤ 0,5 en moyenne ; avant-poste lointain tenu ≥ 20 min sur 4 graines sur 5 ;
  un prudent et un audacieux décident différemment sur le même site (mesuré).
- Risque : groupes du moteur (F171 à F174), pose près d'ennemis qui bougent (E181).

**IA3-h · Pétrole (remplace IA1-e2).** 2 à 3 jours, après c, e, f, g.
- Contenu : la chaîne du pétrole sortie du dépliage, raffinage sur place, électricité au moins cher (ligne ou centrale
  locale), plastique et soufre rapatriés.
- Preuve : `ia3d-default` 4 h, 5 graines ; `ia1-oil`.
- Critères : **K2 : palier 4 ≤ 120 min** à 8 PNJ en Normal sur 4 graines sur 5 (un joueur vanilla correct : 90 à
  120 min ; calendrier X0 du joueur : âge 4 à 3 h ; C5-3 b tolérait 3 h 45).

**IA3-i · Les âges (remplace IA1-f).** 3 jours et plus (dépend des lots X des âges suivants).
- Contenu : méthode `level` (payer le niveau du centre en monnaies), verrous `fo-epoch-k`, ressources et bâtiments des
  lots X : rien de spécifique dans le cerveau.
- Critères : **K8** ; enveloppe de difficulté (Facile plus lent) mesurée.

**IA3-j · Lisibilité (chaque lot montre sa part, puis le test à l'aveugle).** 1 jour à la fin.
- Contenu : fenêtre complète (§5.5), journal des annonces, test M5 d'IA2 (« joueur ou PNJ ? ») proposé au DC.

Dépendances : 0 → a et b (indépendants) → d ; 0 et b → c ; c → e (avec IA1-d) ; 0 → f (en parallèle de c) ; c et
f → g ; c, e, f, g → h → i. **Durée totale estimée : 17 à 21 jours de travail d'agents**, dont 3 jours pour les lots
rapides (0, a, b, d) qui donnent les premiers effets visibles.

### 6.3 Risques majeurs

1. **IA1-d (la construction automatisée à l'échelle) n'est pas prouvé.** Sans lui, IA3-e et IA3-h n'existent pas : les
   factions resteraient au portage (K7) et sans pétrole (K2). C'est le chemin critique de toute la section.
2. **La vraie recherche coûte 22 fois plus que l'ancienne** (§3.8). Si l'automatisation (IA3-e) traîne, les factions
   paraîtront PLUS lentes en niveaux de 20 à 60 min. Garde : IA3-c mesure les paliers 1 à 3 dès les premières minutes,
   et l'ancien cerveau reste derrière un réglage.
3. **Recherche par une force sans joueur** (E180) : si le moteur ne fait pas avancer la recherche, repli au QG (même
   coût, même temps), moins « joueur ».
4. **Ordre strict de `pvp_test`** : chaque lot change les listes de tâches ; les attentes se recalent sur l'ordre des
   difficultés, jamais en l'affaiblissant (IA1-b2 l'a cassé une fois : 1 302 OK, 3 ECHEC).
5. **Divergence des parties** (F252) : un changement de votre équipe change toute la partie ; conclure sur 4 graines.
6. **Pics de calcul** : points fixes 5 ms et attribution globale 1 ms (hors jeu) : découpés (une phase lourde par tick
   pour tout le mod) ; mesurés à chaque lot.
7. **Factions trop fortes pour le joueur** : un cerveau qui joue bien peut dépasser le calendrier X0 ; l'enveloppe de
   difficulté (Facile : PNJ plus lents à fabriquer, moins nombreux) et le chef (satiété, trêve d'IA2-a2) règlent le
   tempo ; mesure à chaque lot de la première attaque et des pertes du joueur dans `verif-guide`.
8. **Expéditions et moteur** : groupes qui perdent des membres (F173, F174), tourelle posée sur un biter (E181).

## 7. Prototypes et tests hors jeu de la conception

Aucun de ces fichiers n'est chargé par le jeu (aucun `require` depuis `control.lua`, `data.lua` ou `script/`). Ils
prouvent que les idées incertaines tiennent, sur les vraies données.

| Fichier | Rôle | Test (lua5.2, depuis la racine du mod) | Résultat (25/10) |
|---|---|---|---|
| `shared/ai3/graphe.lua` | dépliage générique, six méthodes, points fixes, règle H8 | `lua5.2 tests/ai3_graphe_test.lua` | **31 OK** |
| `shared/ai3/registre.lua` | réservations, prise stricte, préemption réglée | `lua5.2 tests/ai3_groupe_test.lua` | **24 OK** (avec le marché) |
| `shared/ai3/marche.lua` | score, attribution gloutonne, anti-ruée, règle des pôles pour comparaison | idem | idem |
| `shared/ai3/expedition.lua` | risque, bandes, équipement tiré du catalogue | `lua5.2 tests/ai3_expedition_test.lua` | **15 OK** |
| `tests/ai3_gen_tech.lua` | génère `tests/fixtures/tech_ai3.lua` (183 technologies vanilla, infinies omises) | `lua5.2 tests/ai3_gen_tech.lua "<racine>/data" tests/fixtures/tech_ai3.lua` | 183 écrites |
| `tests/fixtures/entities_ai3.lua` | bouchon des prototypes d'entités (catégories, énergie) et pseudo-recettes (chaudière, générateur) | — | — |

**Résultats chiffrés** (expériences proposées à l'intégrateur : **E178** prototype du dépliage et coût réel de la
recherche des factions ; **E179** jouet « pôles contre marché ») :
- généricité : 825 noms d'objets, de bâtiments et de ressources cherchés dans le code du dépliage : 0 ;
- chemin vers le pack chimique déduit des données (§3.2) ; sans pétrole connu : exploration et recherches seulement ;
- niveaux 0 à 3 des factions : 290 packs payés pour 6 415 de coût réel ; `military-3` exige le pack chimique (§3.8) ;
- registre : 20 000 opérations tirées, 0 violation, état identique sur 2 passages ;
- marché : 1 000 tableaux tirés, 0 PNJ libre laissé sans tâche faisable ; jouet à 8 PNJ (3 extraction, 3 base,
  2 territoire ; 70 % du travail à la base, comme les packs et les fabrications d'IA3-DIAG ; 600 pas) : règle des
  pôles **35 % d'inactifs pendant que du travail attend**, 778 tâches faites, 202 en retard ; place de marché
  **0 %**, 980 faites, 0 en retard ;
- expédition : l'exemple du pétrole (risque 600, escorté, « préparer » sans les 8 soldats) ;
- coût hors jeu : points fixes 4,9 à 5,6 ms, dépliage 1,0 à 1,5 ms (273 recettes, 183 technologies).

**Ce qui n'est PAS vérifié** :
- rien n'a tourné en moteur réel ; aucun chiffre de durée de partie n'est prédit par ces prototypes ;
- le jouet du marché n'est pas le jeu : il montre le mécanisme (pas d'attente quand du travail existe), pas le gain en
  minutes de recherche ;
- la fixture des entités est copiée à la main (17 machines) ; les technologies du mod (`fo-…`) ne sont pas dans la
  fixture ; « recette active au départ » est déduit (recette qu'aucune technologie ne débloque) : en jeu, on lira
  `force.recipes[nom].enabled` ;
- poteaux électriques, tuyaux, tapis et débits des fluides ne sont pas modélisés par le dépliage (plan directeur et
  solveur) ;
- le coût de choix du prototype est simplifié (durée de recette et surcoûts) ; la version en jeu compte travail,
  matière et risque (§3.3) ;
- les étapes du dépliage ne sont pas encore regroupées en tâches (369 étapes pour le pack chimique, dont beaucoup de
  petites extractions et fontes répétées) ;
- faits moteur : aucun nouveau (F269 à F275 restent libres pour IA3-0 ; E180 et E181 y sont prévus).
