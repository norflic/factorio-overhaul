# IA de faction : carte du workflow de bout en bout (0.6.58, commit 0e340b99)

Pour tout agent qui touche l'IA des équipes de PNJ (factions et votre équipe). Code lu en LECTURE SEULE dans le worktree
`<mod>/.claude/worktrees/integ-0652b` ; tous les chemins ci-dessous partent de là. Journal de la partie du DC :
`<racine>/fo-logs/2026-11-07_PARTIE-DC-0658/factorio-current-1415.log` (appelé « journal »).
Étiquettes : **lu** = vu dans le code à la ligne citée (ou dans le journal) ; **déduit** = raisonnement sur ce code, NON prouvé en moteur réel.
Écart à la demande : le découpage de 0.6.58 compte **4 étapes (E1 à E4), pas 6** (**lu** `script/team/team.lua:821-826`).

```
 on_tick ─ Scheduler (script/core/scheduler.lua:231)
   ├─ voie fo-commander, 300 t, faction k à la phase 7, 82, 157, 232 ─▶ Commander.think ─▶ Team.think = E1 ─▶ E2 ─▶ E3 ─▶ E4 ─▶ queue (Chef, Veille, PvP)
   ├─ voie de votre équipe, 300 t, phase 174 ──────────────────────────▶ Team.think = E1 ─▶ E2 ─▶ E3 ─▶ E4 (pas de queue)
   ├─ voie fo-brain, 60 t par PNJ ─▶ FSM « worker » : idle ─claim─▶ step ⇄ walk / mine / craft / wait / ia1d ─▶ idle
   └─ on_nth_tick : Build.PULSE (5 t, travail du plan directeur), prospection (30 t), 600 t (fenêtres, guerre)

  VUE (E1) ─▶ CERVEAU + PLAN (E1) ─▶ TABLEAU (sync E1, plan directeur E2, réparations E3) ─▶ MARCHÉ (indices E4)
     ▲                                                                                        │
     │                                   PNJ : claim → programme → porte → registre → étapes  ▼
     └──── coffre QG + annexes, sorties d'avant-postes, registre, morts ◀──── EFFETS EN JEU ◀──┘
```

## 1. Le rythme

| Cadence | Ce qui tourne | Où | |
|---|---|---|---|
| chaque tick | ordonnanceur : voies et minuteurs (dont les étapes E2 à E4) | `script/core/scheduler.lua:231` ; `script/team/team.lua:1173-1190` | lu |
| 5 ticks | passe de travail du plan directeur pour toutes les équipes | `script/team/build.lua:77`, `4526-4534` | lu |
| 30 ticks | prospection de votre équipe (`f.site_needs`) | `script/team/player_team.lua:241-245` | lu |
| 60 ticks par PNJ | pensée du PNJ (machine « worker »), 6 étapes au plus, autodéfense toutes les 60 t ; une prise de tâche coûte des jetons | `script/companion/brain.lua:163` ; `settings.lua:26-28` (défaut 60) ; `script/team/worker.lua:66`, `130`, `1418`, `1449` | lu |
| 300 ticks | PENSÉE D'ÉQUIPE. Factions : `think_period` 300, phases espacées ; votre équipe : phase 174 | `shared/faction/config.lua:91` ; `script/faction/commander.lua:134-137`, `150-155` ; `player_team.lua:234-239` | lu |
| 1 min (12 pensées) | capitalisation (décision à l'étape 10, [FO-CAPI], [FO-RESERVE]) ; chef ; prévision ; [FO-EFFECTIF] (factions) | `script/ai3/capitalisation.lua:97`, `1494`, `1551` ; `commander.lua:125` ; `script/ai3/cerveau.lua:846-850` ; `team.lua:1121`, `1231-1238` | lu |
| 5 min | journaux de mesure [FO-MUNITIONS], [FO-REARMEMENT], [FO-FLUX], [FO-SEC], [FO-ACTIF], [FO-PRISE-VIDE] | `team.lua:637-647`, `871-872` ; `script/team/board.lua:738-764` | lu |

Les 4 étapes d'une pensée (T = tick de la pensée) :
- **E1 (T)** `TT.e1` (`team.lua:831-943`, **lu**) : `Team.view` (462-798) ; état de base d'une faction (`DefChoix.base`, 837) ; plan = `Ia3.plan` ou `Planner.plan` (842-843) ; filtre des tournées de fonte (862-866) ; journaux ; objectifs atteints et patience (884-901) ; `f.team.goal/missing/unreachable` (902-904) ; `f.site_needs` (925) ; `Board.sync` (929) ; `Bail.think` (930) ; `SurvieQg.note_plan` (931) ; `Survie.think` (932) ; `Poles.think` = organisation et FOND (937) ; `Ia3.after_poles` (938) ; préemption de la file sûre (939).
- **E2 (T+1)** `Build.think` : chantiers, défrichage, quais, collectes du plan directeur (`team.lua:945-952` ; `build.lua:4846-4906`, **lu**).
- **E3 (T+2)** reconstruction, réparations, infrastructure électrique (`team.lua:954-965`, **lu**).
- **E4 (T+3)** (`team.lua:967-1127`, **lu**) : `Inter.think` (970) ; `Board.assign` = marché (975) ; mesures et cases du QG (998-1011) ; paiements sur le stock RELU (1015) : recrue (1019-1047), armée (1048-1065), pièces électriques (1070), gisements (1077), foreuses (1081), migration du champ (1088), capital (1093-1110), packs de recherche (1114-1119) ; journaux (1120-1122) ; `Stock.balance`, `Stock.grow` (1124-1125). Puis la queue du commandant (`team.lua:1157-1167` ; `commander.lua:124-131`).
- E4 lit une COPIE de la vue et du plan de T (`Et.freeze`, `team.lua:1130-1133`, `1218`, **lu**) : décision à T, paiement à T+3 sur un coffre qui a bougé entre-temps (**déduit**).

Factions face à votre équipe (même `Team.think`, ~15 branches sur `f.is_player`, **lu**) :
- effectif : factions par `Effectif.decide` (`team.lua:700-721`) ; votre équipe par `grow_due` (651-664), la réserve de fer (667-673), `recover_floor` (781) ;
- QG occupé par les biters : factions seulement (514) ; recrue retenue dans un QG sans tourelle armée : votre équipe seulement (737) ;
- fond : votre équipe dès l'effectif de départ si une tourelle est possible, sinon fond sûr ; faction au-delà de son départ seulement (`script/team/poles.lua:398-405`) ;
- récolte « KIT » (tuile réservée, entité la plus proche) : factions seulement, `Harvest.PLAYER = false` (`script/team/harvest.lua:49-52`) ;
- recherche de votre équipe seulement quand votre force n'a rien en cours (`script/ai3/cerveau.lua:792`) ;
- guerre : `PvP.think` dans la queue d'une faction (`commander.lua:129`) ; une faction déclarée donne des gardes au QG de votre équipe (`team.lua:563-567`) ;
- votre équipe = force du coffre = **force du joueur** (`player_team.lua:53`, `95`) : PNJ et bâtiments du joueur partagent la force (**lu**) ; un PNJ peut donc miner un bâtiment du joueur (**déduit**).

## 2. La chaîne de décision

| # | Étape | LIT | ÉCRIT | Relu par |
|---|---|---|---|---|
| 1 | **Vue** `Team.view` (`team.lua:462-798`, E1) | coffre + annexes (`script/team/stock.lua:86-96`) ; registre (`Board.view_stock(..., true)`, `team.lua:692` ; `board.lua:244-266`) ; avant-postes `Outposts.status` (`script/faction/outposts.lua:828-852`) ; tourelles, menaces, sites, tableau (495-505) | `view.stock` = stock LIBRE (741) ; `iron0` = coffre BRUT (488) ; `f.team.floor` (522), `flux_fill` (680), `ammo_*` (594-618), `effectif` (707-711) | plan ; `Poles.think` ; `Survie.think` ; E4 (copie) ; `flux_fill` par la tournée (`worker.lua:513`) ; `floor` par le chef |
| 2 | **Cerveau** `Ia3.active` → `Ia3.plan` (`script/ai3/cerveau.lua:193-222`, `778-956`) → `C.think` (`shared/ai3/cerveau.lua:198-487`) : planificateur permanent sur `C.base_view` (203), pile (214-225), besoin évalué `st.noyau` (228-243), buts et projets (248-318), dépliage (339-340), approvisionnement (346), manques, saturation, couverture (352-425), fusion des tâches (435-473), manque du projet dominant (477-487) | vue, livre de recettes, `f.team.ia3` | `plan.tasks/missing/smelt/site_needs/recruit_*/train/research` ; `st.short`, `st.saturated`, `st.covered`, `st.noyau`, `st.pile` | `Board.sync` ; `f.team.missing` → réservé de l'effectif (`team.lua:393`) et raisons d'attente (989) ; `st.noyau` → capitalisation et `Rsv.covered` à la pensée SUIVANTE (`script/ai3/reserve.lua:4-5`, `27-31`) ; `st.saturated/covered` → `Ia3.after_poles` (`cerveau.lua:968-1003`) |
| 2b | **Planificateur** `Planner.plan` (`shared/team/planner.lua`), aussi appelé DANS `C.think` | vue | entretien (593-622), survie (882-1004), objectif (1006), fonderie (1125), ouvriers, armée, recherche (1130-1171), matières (1265) | idem |
| 3 | **Plan directeur** `Build.think` (E2, `build.lua:4846-4906`) | `f.build` (projets, états) ; coffres des quais et sorties | tâches `ia1d` par `Board.add` (4879) ; quais et collectes (`quai_tasks`, 3925-3983) **seulement si le projet est « fini » ou « chantier »** (4870) | PNJ (programme `worker.lua:417-428`, travail `build.lua:3603-3727`) |
| 4 | **Tableau** `Board.sync` (`board.lua:323-394`), `Board.add` (398-424) | plan ; tâches prises | remplace les tâches LIBRES par le plan (330-339), pause après échec (335), vieillissement des tournées (343-354), manque de plaques (355-375), rétention des minages (379-390), liste triée (58-69) | claim, assign, vue (backlog), effectif (`team.lua:366-389`) |
| 5 | **Marché** `Board.assign` (E4, `board.lua:766-837`) | PNJ « idle » (773-778) ; tâches libres dont la matière stricte est libre (801-811) | `b.hint` (834), valable 60 t (534) | `claim_market` (567-624) |
| 6 | **PNJ** (`worker.lua`) | `Board.claim` (1455 → `board.lua:839-920`) : ordre `M.order`, réservation stricte au registre tout ou rien, préemption (147-187), 8 essais (529) ; `Worker.program` (431-741) ; PORTE `H.gate` (1477-1492 → `script/ai3/comportement.lua:793-882`) ; prises larges bornées (1494 ; `board.lua:191-216`) | `agent.task/steps` ; étapes `run_steps` (1308-1408) : home, take, goto, act, craft, mine, wait, ia1d | `Board.finish` (`board.lua:969-1017` : pause, compteurs, échecs de chemin) ; `Poles.task_done` |
| 7 | **Effets en jeu** | inventaire du PNJ, coffres | dépôt `deposit_all` (`worker.lua:295-306` → `Stock.insert`, `stock.lua:72-83`, `f.refused_at` si refus) ; prises (309-325 ; `board.lua:220-240`) ; actes (`worker.lua:780-889`) ; minage (1700-1755) ; mort : `o.lethal_tick` (1888), `f.hq_deaths` (1869-1881), rappel (1892-1894) | la vue suivante : la boucle se ferme |

Maillons fragiles de la chaîne :
- la vue ne voit PAS les coffres de sortie du plan directeur : `outputs` ne lit que `o.sinks` (`outposts.lua:838-845`), et un champ migré « n'a plus rien à collecter ici (la fonderie du plan a ses coffres) » (847-849) ; `view.repat` est fait de ces seuls avant-postes (`team.lua:681`) (**lu**) → le fer du champ n'existe pas pour le cerveau, le manque, la survie ni le fond (**déduit**) ;
- `Ia3.after_poles` rappelle `Board.sync(f, keep, tick)` SANS plan ni vue (`cerveau.lua:999`, **lu**) : `b.need_mult` et `b.hold_left` repassent à nil (`board.lua:376-381`, **lu**) pour le reste de la pensée (**déduit**, effet sur le marché non mesuré) ;
- `Board.sync` (E1) efface les tâches `ia1d` libres que seul `Build.think` (E2) remet : une tâche du plan directeur est absente du tableau pendant 1 tick à chaque pensée (**déduit**) ;
- lectures mêlées du stock : brut (`iron0`, `team.lua:488` : croissance, munitions, réserve de fer) contre libre (`view.stock`, 741) (**lu**).

## 3. Flux de matière

**Extraction**
- Avant-postes thermiques : foreuses → réceptacles `o.sinks` (`outposts.lua:795-799`) ; tournée « service » à 95 si un brûleur est bas, à 70 si la sortie atteint `T.collect_at` = 40 ou après 3 min (`planner.lua:603-620` ; `shared/team/config.lua:110-111`) ; l'acte vide les sorties et recharge les brûleurs (`worker.lua:831-838` ; `outposts.lua:904-917`) (**lu**).
- Champ (migration en bandes, plan directeur) : foreuses électriques → fours → coffres `p.outs` ; collecte = tâche « carry » mode « collect » à partir de `Build.COLLECT_AT` = 200 objets (`build.lua:91`, `3969-3981`), priorité `p.prio` = 52 pour une bande (`shared/team/migration_champ.lua:64`), **seulement pour un projet fini ou en chantier** (`build.lua:4870`) (**lu**).
- Minage à la main : programme `worker.lua:634-738` ; refusé si le coffre couvre la tâche (638-650) ou si les sorties d'un avant-poste brut en ont (654-666) (**lu**).

**Transformation** : fours du QG (tournée « smelt », `worker.lua:578-631`, `886-889`, filtrée par `ChaineMain`, `team.lua:862-866` ; seuil `T.smelt_collect_min` = 10, `config.lua:197`) ; fours du champ et lignes à tapis ; mall du plan directeur (sortie gardée sous `keep_stock`, `build.lua:3904-3911`) (**lu**).

**Collecte** : trois seuils indépendants, 40 (avant-postes), 200 (plan directeur), 10 (fours du QG) (**lu**).

**Stockage** : stock = coffre du QG + annexes (`stock.lua:1-18`, `53-96`) ; rangement aux annexes à 80 % (`stock.lua:123-155` ; `config.lua:183-188`) ; une annexe ne se pose que si un coffre est EN MAIN (`stock.lua:285-307`) ; ce coffre ne vient que du fond (`shared/team/fond.lua:407-421`, appelé avec `annex_want = Stock.wanted(f)`, `poles.lua:440`) (**lu**).

**Consommation, dans l'ordre** (**lu**) :
1. prise au registre à la prise de tâche (stricte, préemption à 30 points d'écart, 10 si l'autre n'a rien pris : `board.lua:19-24`, `147-187`) : le premier PNJ servi par le marché prend ;
2. E4 : recrue → armée → pièces électriques → gisements, foreuses → migration du champ → capital → packs de recherche → rangement, annexe (`team.lua:1013-1125`) ;
3. plan : entretien → survie → objectif → fonderie → ouvriers, armée, recherche → matières (`planner.lua:593`, `882`, `1006`, `1125`, `1130`, `1265`) ; pile R0 survivre, R1 réparer + protéger, R2 produire, R3 améliorer (`shared/ai3/pile.lua:12-20`) ;
4. munitions : les tourelles d'abord (plancher du rechargement des PNJ, `worker.lua:260-293` ; recharge bornée au manque, 525-559) ;
5. recrue : kit + (10 + effectif) fer (`shared/team/scale.lua:116-119`), payée au QG avec les plaques du coffre (`planner.lua:961-976` ; `team.lua:1019-1039`).

## 4. Boucles de rétroaction et verrous

- **B1 fer → recrue → bras → collecte → fer.** Sous l'effectif de départ, la recrue de votre équipe n'est payée que si le livre trouve TOUTES les plaques ; sinon rien (`planner.lua:962-975`) ; la règle ordinaire demande alors le kit à 55 (`planner.lua:1169`), qui manque du même fer (**lu**). Sans bras, une collecte à 52 n'est jamais servie (**déduit**).
- **B2 place → dépôt → collecte.** Coffre plein : `Stock.insert` refuse (`stock.lua:81`) ; le PNJ garde ce qui n'est pas déposé (`worker.lua:225-229`) ; la collecte suivante insère 0 dans un sac plein et rend quand même « done » (`build.lua:3705-3724`) (**lu**) → voyages à vide sans pause d'échec (**déduit**).
- **B3 saturation sans sortie.** Une matière saturée garde les tournées de ses sorties PLEINES (`shared/ai3/cerveau.lua:437-442`, **lu**) ; aucun consommateur ne vide une matière qui dort (**déduit**).
- **B4 danger → porte → attente → survie.** Chaque refus de la porte compte pour la paralysie (`script/team/survie.lua:62-66`) ; le mode survie assouplit la porte (`comportement.lua:842-848`) (**lu**).

| Garde qui met en pause | Écrit à | Lu à | Effet, durée | |
|---|---|---|---|---|
| avant-poste meurtrier | `worker.lua:1883-1888` | `team.lua:551` → `planner.lua:598-602` | plus de tournée sans tourelles, sauf matière < 50 au coffre ; 10 min (`config.lua:249`, `262`) | lu |
| avant-poste dangereux (nid, ver, perte récente) | `team.lua:535-540` ; `poles.lua:360-371` | `board.lua:346` ; fond | ni urgence de tournée, ni fond | lu |
| QG occupé (factions) | `worker.lua:1869-1881` | `team.lua:514` | aucune recrue ; 3 morts en 2 min à 24 tuiles → 10 min (`config.lua:258-260`) | lu |
| QG menacé (votre équipe) | `team.lua:571-575` | `poles.lua:406` | fond coupé, tout le monde garde à 96 (`config.lua:293-295`) | lu |
| QG en péril sans tourelle armée (biters de la force « enemy » à 48 tuiles du coffre ou moins, `survie_qg.lua:220`) | `SurvieQg.recruit_hold` → `hold_recruits` (`team.lua:737`) | `planner.lua:962`, `1138` (ni recrue de reprise ni recrue ordinaire) ; second verrou sur la recrue sans arme `team.lua:1042-1043` | AUCUNE recrue, armée ou non, tant que la menace dure ; ne voit PAS les soldats des factions (correction d'effondrement, 7/11) | lu |
| rappel | perte loin du QG (`worker.lua:1892-1894`, `1218`) ; file sûre (`team.lua:939`) | PNJ | tâche abandonnée, retour au QG | lu |
| pause d'échec | `Board.finish` (`board.lua:997-1004`) | `Board.sync` (335), `Board.add` (416) | 1 800 t (48), plus court pour un danger, croissant pour un chemin | lu |
| bail | `Bail.think` (`team.lua:930`) | PNJ | tournée sans progrès rendue | lu |
| porte (danger, escorte, vague, boucle) | `worker.lua:1477-1492` | `comportement.lua:793-882` | tâche refusée « danger » | lu |
| mode survie | `survie.lua:114-135` | vue, planificateur, porte | minages, fours, porte assouplie | lu |
| réserve de fer (votre équipe) | `team.lua:667-673` | `planner.lua:1150-1160` | recrue de croissance retenue sous 400 fer (`config.lua:304`), sauf besoin évalué couvert (`team.lua:654-655`) | lu |
| frein « inactifs » | `team.lua:517` | `planner.lua:1146-1149` | pas de recrue ; jamais sous le plancher (`scale.lua:111-114`) | lu |
| plafond d'agents | `team.lua:470` | `planner.lua:1139-1145` | recrue bloquée | lu |
| pile (R0 à R2 retiennent R3) | `team.lua:1075-1110` | E4 | foreuses, capital suspendus | lu |
| rétention des minages | `board.lua:379-390` | tableau | minage retenu tant que des plaques dorment aux sorties d'avant-postes | lu |
| fond coupé | `poles.lua:398-406` ; cerveau en manque (`fond.lua:388`) | fond | sous l'effectif de départ, ni fond ni coffre d'annexe | lu |

## 5. Maillons cassés ou absents vus le 7/11 (0.6.58, journal)

- **D1. Recrue payée en fer, fer libre à 0, équipe bloquée à 2 PNJ.** Journal : « inactifs 0/2 » ([FO-IA3C] player minute 177), « manque iron-plate 1932 » ([FO-RESERVE] minutes 174 à 177), mode survie depuis 90 min ([FO-SURVIE] 177,1), « 0 PNJ libre(s), 16 tache(s) libre(s) » ([FO-ACTIF] 175,0) (**lu**). Sur la carte : §2 étape 2b, §3 point 5, boucle B1. Maillons : la recrue de reconstruction rend rien sans plaques (`planner.lua:968-975`, **lu**) ; le fer EXISTE au champ, « coffres de sortie 10 (plaques 4353, max 585, 8 au seuil de collecte) » ([FO-CHAMP-ETAT] minute 169, **lu**), mais la vue ne le voit pas (§2, maillons fragiles) et la collecte à 52 perd contre 16 tâches libres pour 2 PNJ (**déduit**). **Absent** : aucun signal « matière disponible dans un coffre du plan directeur » vers la vue, le manque ou la survie ; aucune hausse de priorité de la collecte quand une recrue attend ce fer.
- **D2. Fer produit au champ, jamais collecté ; fours « sortie pleine ».** Collecte et remplissage des quais seulement pour « fini » et « chantier » (`build.lua:4870`, **lu**) ; le champ a des bandes « refuse » (2 à 3) et « reserve:pile » ([FO-CHAMP-ETAT] minutes 149 à 169, **lu**) : leurs coffres de sortie et de combustible ne sont plus servis (**déduit**). Une autre part de l'arrêt est électrique : « bras sans courant 7 », « foreuses … sans courant 12 » (minutes 159 et 169, **lu**) ; des bras sans courant laissent la sortie du four pleine (**déduit**). La collecte qui ne prend rien est comptée réussie (B2).
- **D3. Coffre du QG plein de pierre, aucun coffre ajouté.** Aucune ligne [FO-ANNEXE] pour player de toute la partie, 31 pour scarlet ; « stone dort 28888 » ([FO-DEPENSES] minute 177) ; « sature [copper-plate stone] » (**lu**, journal). Maillons : annexe posée seulement avec un coffre en main (`stock.lua:286`) ; coffre fabriqué seulement par le fond (`fond.lua:407-421`), coupé pour votre équipe sous son effectif de départ (`poles.lua:399-406`) ; cerveau en manque : seulement un coffre sans plaque (le coffre en bois, qui demande du bois, `fond.lua:416`) (**lu**) ; avec 2 PNJ sur 12, le fond est coupé (**déduit**). Double compte possible : `Stock.wanted` compte les coffres en main MOINS la demande du plan directeur (`stock.lua:160-161`, `197-199`), `Fond.base` retire les coffres libres BRUTS (`fond.lua:411-413`) : coffres réservés au plan → coffre voulu, mais rien fabriqué (**déduit**, à tester hors jeu). La pierre continue d'arriver (B3).
- **D4. Tourelles du joueur minées par un PNJ** (`worker.lua:1752`, **déduit**). Votre équipe garde l'ancienne récolte (`harvest.lua:49-52`) : l'entité minée est la PREMIÈRE ressource trouvée à 2,5 tuiles, dans l'ordre du moteur (`worker.lua:84`) ; `update_selected_entity(res.position)` puis `mining_state` (1752-1753) minent ce qui est sélectionné sur cette tuile (**lu**) ; un bâtiment de la même force passe devant la ressource à la sélection (**déduit**, non prouvé en moteur réel). Le contrôle « tuile libre » n'est fait qu'au programme, sur la tuile choisie (684-697), pas sur l'entité prise à 2,5 tuiles, ni au retour après un dépôt (1734-1736), ni pour un gisement lointain (720-723) (**lu**). Force partagée avec le joueur (§1). Voir F41 et F96 (RD_LOG) avant de corriger.

## 6. Checklist avant de toucher l'IA (à donner à tout agent)

1. **Étape** : ma modification passe-t-elle par E1 (vue, plan, tableau), E2 (plan directeur), E3 (réparations), E4 (marché, paiements) ou par la pensée du PNJ (60 t) ? E4 lit la COPIE de la vue de T.
2. **Stock** : je lis le coffre BRUT (`Stock.count`) ou le stock LIBRE (`Board.view_stock`) ? Les deux coexistent dans la même vue.
3. **Lecteurs** : qui lit l'état que j'écris (grep du champ), et quand : même pensée, pensée suivante (`st.noyau`, `f.team.missing`), minute suivante (capitalisation) ?
4. **Tâche** : passe-t-elle `Board.sync` (tâches libres effacées), la porte, le registre strict, la pause d'échec ? Que pèse sa priorité contre 90, 95, 96 ?
5. **Vue** : le cerveau voit-il la matière que je produis (sorties `o.sinks`, coffre, registre) ? Sinon elle n'existe pas pour lui.
6. **Boucle** : est-ce que je ferme B1 (fer → recrue → bras → collecte), B2 (place → dépôt), B3 (saturation) ou B4 (danger → survie) ? Sous l'effectif de départ, le fond est coupé.
7. **Joueur** : votre équipe partage la force du joueur : aucune action (miner, démonter, sélectionner) sur une entité qui n'est pas à l'équipe.
8. **`f.is_player`** : ma règle vaut-elle pour les factions, votre équipe, ou les deux (§1) ?
9. **Journal** : quelle ligne [FO-...] le prouvera ([FO-CHAMP-ETAT] « au seuil de collecte », [FO-ANNEXE], [FO-RESERVE] « manque », [FO-ACTIF] PNJ libres et tâches libres, [FO-MINAGE], [FO-SURVIE], [FO-IA3C] « inactifs ») ?
10. **Preuve** : test hors jeu d'abord, micro-banc de 2 500 ticks au plus par la file ensuite ; pas de banc long sans accord du DC.

## 7. Modules : point d'entrée, ce qu'ils lisent et écrivent (pour placer un mécanisme nouveau)

Quand (cadence) : P = chaque pensée (300 t), M = une fois par minute, W = pensée d'un PNJ (60 t), 5t = passe du plan directeur. Lu = vu au code (ou dans l'en-tête du fichier) ; les colonnes LIT et ÉCRIT résument le code cité.

| Module (fichier : entrée) | Quand | LIT | ÉCRIT | Lu par | |
|---|---|---|---|---|---|
| Pensée d'équipe `Team.think` (`script/team/team.lua:1202`) | P | équipe | `f.team.etape` (E2 à E4 à venir) | minuteur `TT.step` (1173) | lu |
| Vue `Team.view` (`team.lua:462`) | P (E1) | coffre, registre, avant-postes, tableau, menaces | table `view` (§2) | plan, fond, survie, E4 | lu |
| Planificateur permanent `P.plan` (`shared/team/planner.lua:239` ; aides `add`/`take`/`want` 243-267) | P (E1), 2 fois avec IA3 (`shared/ai3/cerveau.lua:203`) | `view`, livre | `plan.tasks`, `missing`, `smelt`, `recruit_*`, `train`, `research`, `priorite` | `C.think`, `Board.sync`, E4 | lu |
| Cerveau IA3 runtime `Ia3.plan` (`script/ai3/cerveau.lua:778`) : recherche (792), contexte `ctx` (862-880) | P (E1) | vue, `f.team.ia3`, `ctx` (auto, capi, capital, pile, bilan, prévision…) | plan fusionné, `st.*` | tableau ; modules ci-dessous à la pensée suivante | lu |
| Cerveau IA3 pur `C.think` (`shared/ai3/cerveau.lua:198`) | P | `view`, livre, `st`, `ctx` | `st.short/saturated/covered/noyau/pile/need/mall`, plan | runtime | lu |
| Buts `B.generate` (`shared/ai3/buts.lua:284`), cibles d'extraction `B.targets` (180), poids `B.weights` (123) | P | situation `s`, `st` | liste de buts (valeur, famille) | `P.update` | lu |
| Projets `P.update` (`shared/ai3/projets.lua:104`), dépliage `P.emit` (568), fours d'amorce `P.boot_smelters` (595), approvisionnement `P.supply` (634) | P | buts, stock virtuel `E.avail` | `E.tasks`, `E.raw` (manques), `E.smelt`, `E.explore` | `C.think` (fusion 435-473) | lu |
| Pile de priorité `Pi.update` (`shared/ai3/pile.lua:108`), `Pi.allows` (297), `Pi.porte` (337) | P | signaux (`Pi.signals`, 424) | `st.pile` (sommet, retenue, focus) | `C.think` (filtre des buts 250-317), E4 (`team.lua:1075`) | lu |
| Automatisation IA3-e `Auto.think` (`script/ai3/automatisation.lua:546`) → `A.decide` (`shared/ai3/automatiser.lua:739`) → `submit` → `Build.request` (`automatisation.lua:478`) | M (décision), P (suivi) | fenêtre des charges à la main, stock, débit voulu par la capitalisation | demandes de modules ; `ctx.auto` = { modules, cap, covered } (603-...) | cerveau (`covered` retire des tournées) | lu |
| Capitalisation `Capi.think` (`script/ai3/capitalisation.lua:1564`) → `Ca.decide` (`shared/ai3/capitalisation.lua:1954`), buts de fond `Ca.goals` (2057) | M (étape 10 sur 12, en-tête 14-24) | relevé des machines, couverture des gisements, recensement, besoin évalué `st.noyau` | ordres aux exécutants (fonderies et chaînes par `Auto.submit`, champ par `MigChamp`, laboratoires), débit voulu `f.team.ia3.puits` | `Auto.think`, cerveau (`ctx.capi`) | lu |
| Amélioration `Capital.goal` (`script/ai3/capital.lua:438`), paiement `Capital.pay` (697) | P | bâtiments à niveaux, centre | but « capital », paiement en E4 | cerveau, E4 | lu |
| Bras libres `Br.smelters` (`shared/ai3/bras.lua:122`), `Br.army` (168) | P | effectif, bras libres | fours du QG voulus, armée visée | `B.generate` (`shared/ai3/buts.lua:376`, factions seulement) ; `Ia3.plan` (`script/ai3/cerveau.lua:822`) | lu |
| Besoin évalué `Rs.state` (`shared/ai3/reserve.lua:146`), recrues `Rs.recruits` (51) | P | stock, postes, réparations, recrues | `st.noyau` | capitalisation, `Rsv.covered` (pensée suivante) | lu |
| Mall `Ml.decide` (`shared/ai3/mall.lua:98`) | P | fabrications à la main récurrentes | `st.mall` | filtre des fabrications (`shared/ai3/cerveau.lua:360-373`) | lu |
| Prévision `Prev.think` (`script/ai3/prevision.lua:403`) | M au plus | menaces reçues | `f.prevision`, cadres « préparer » | vue (`army_soon`), pile | lu |
| Cerveau général IA-G `General.choose_tech` (`script/ai3/general.lua:585`), `General.key` (413) | P | graphe de fabrication | recherche, ressource clé | cerveau | lu |
| Pétrole `Pet.think` (`script/ai3/petrole.lua:915`), site `Build.SITES.petrole` (732) | P | sites à fluides | projets de site | plan directeur | lu |
| Plan directeur : demande `Build.request` (`script/team/build.lua:569`) ; vie d'un projet `advance` (4098) ; passe `pulse_team` (4446) ; tâches `Build.think` (4846) ; ligne dynamique `Build.ligne_step` (1949) ; types de site `Build.SITES` (109) ; gabarits `spec.gen` (600-607) | 5t (passe), P (E2, tâches) | `f.build`, treillis, coffres des quais et sorties | projets (états attente → … → fini), tâches `ia1d` (`Board.add`, 4879) | PNJ (`Build.work`, 3603) | lu |
| Champ : `Mig.think` (`script/team/migration_champ.lua:1522`, E4), `Champ.frame` (`script/team/champ.lua:441`), `Champ.band` (580), `Build.SITES.champ` (695) | P (E4) | avant-postes thermiques, gisement | bandes = projets du plan directeur | plan directeur, automatisation (`MigChamp.projects`, 1596) | lu |
| Fond `F.candidates` (`shared/team/fond.lua:452`) via `Poles.think` (`script/team/poles.lua:279`, appel 443) | P (E1) | stock libre, avant-postes, coffres voulus | tâches `fond` (`Board.add`) | tableau | lu |
| Survie `Sv.decide` (`shared/team/survie.lua:128`) via `Survie.think` (`script/team/survie.lua:114`) | P (E1) | manques des plaques clés | mode, tâches de survie | vue suivante, porte | lu |
| Effectif des factions `E.decide` (`shared/ai3/effectif.lua:137`) | P (vue) | travail qui attend, bras libres, coût | décision « recrue » | planificateur | lu |
| Marché `M.order` (`shared/ai3/marche.lua:83`), `M.assign` (126) ; tableau `Board.sync/add/assign/claim` (`script/team/board.lua:323`, `398`, `766`, `839`) | P et W | tâches, PNJ, registre | paires PNJ × tâche, réservations | PNJ | lu |
| PNJ `Worker.program` (`script/team/worker.lua:431`), FSM (1442) | W | tâche, coffre, monde | effets en jeu (§2 étape 7) | vue suivante | lu |
| Reconstruction `Recon.think` (`script/team/reconstruction.lua:325`) ; gisements `Gis.think` (`script/team/gisement.lua:105`) ; foreuses `Swap.think` (`script/team/foreuse_swap.lua:232`) ; tapis `Conv.step` (`script/team/convoyeurs.lua:150`) ; intermédiaires `Inter.think` (`script/team/intermediaires.lua:172`) | P (E3, E4, E2) | registre des pièces, foreuses, tapis | tâches, remplacements | tableau, monde | lu |
| Sites `Sites.prospect` (`script/faction/sites.lua:534`), `Sites.available` (766), `Sites.find` (909) | 30 t, P | `f.site_needs`, carte | réserve de sites | vue, programme « build » | lu |
| Stratégie des factions `Chef.think` (`script/faction/chef.lua:257`), `PvP.think` (`script/faction/pvp.lua:310`) | M (chef), P (queue) | rivales, défense vue | ordre des objectifs, attaques | vue (`ladder`), guerre | lu |

**Où insérer une nouvelle règle de planification** (recommandation, **déduit** de la structure ci-dessus) :
- **Quoi construire, à quel débit, quand grandir** (le cœur d'une usine qui s'étend seule, « tiers dynamiques » compris) : dans la **capitalisation** (`Ca.decide`, une décision par minute), qui est déjà le décideur unique des fonderies, des chaînes et des laboratoires (« un seul décideur par levier », `script/ai3/capitalisation.lua:25-32`, **lu**) ; elle émet des ordres et un débit voulu, jamais des tâches.
- **Comment le bâtir** (gabarit, taille, emplacement, croissance par paliers) : dans le **plan directeur** : un générateur de gabarit (`spec.gen`, `build.lua:600-607`) ou un type de site (`Build.SITES`, `build.lua:109`), demandé par `Build.request`, grandi par une règle du genre de `Build.ligne_step` (`build.lua:1949`) ; les quais et sorties suivent `quai_tasks` (attention au défaut D2 : états servis).
- **Ce qui manque pour le bâtir** (matières, fabrication, minage) : rien à ajouter en général : le module devient un but « auto: » ou « capi: » du **cerveau IA3** (`Ca.goals`, `ctx.auto`), qui déplie les manques (`P.emit`, `P.supply`) ; une règle neuve de ce genre se branche dans `B.generate` ou par un champ de `ctx` (`script/ai3/cerveau.lua:862-880`).
- **Travail permanent à chaque pensée** (entretien, urgence, recrue) : dans le **planificateur** (`P.plan`, une section numérotée de plus, avec `add`/`take`/`want`) ; il tourne aussi dans `C.think`, donc pour les deux cerveaux.
- Toute règle neuve : Lua PUR dans `shared/`, testée hors jeu, listes triées ; le runtime (`script/`) ne fait que lire le monde et appliquer ; elle passe la pile (`Pi.allows` / `Pi.porte`) si elle améliore (R3).
