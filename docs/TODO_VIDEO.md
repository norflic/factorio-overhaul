# TODO de la vidéo « Factorio Automated » : une ligne par élément

Demande du DC, mot pour mot : « il faudra une todo liste exhaustive pour chaque petit élément de la vidéo. Y a beaucoup de chose
qu'il dit qui sont en fait une réflexion précise derrière a implémenter ou au moins a prendre en compte (même si évidemment j'ai
dit 50% donc forcément y a plein d'infos qui pour nous seraient inutile) ».

## Comment lire cette liste

**D'où viennent les lignes :**
- de la transcription (sous-titres automatiques anglais, horodatage mm:ss) ;
- ou d'une source donnée par l'auteur lui-même :
  - **G** : son code (`the-algorithm.lua`, numéros de ligne) ;
  - **D** : la description de la vidéo ;
  - **V2** : la vidéo de suite ;
  - **C** : ses réponses en commentaires ;
  - **S** : son scénario.

**Ce qui est seulement MONTRÉ à l'image n'est pas ici** : je n'ai pas les images. Le DC peut dicter ce dont il se souvient.

**Verdicts :**
- **IMPLÉMENTER** ;
- **À PRENDRE EN COMPTE** : contrainte ou principe de conception ;
- **INUTILE POUR NOUS** : avec la raison.

Les lignes inutiles restent dans la liste, pour que rien ne paraisse omis.

**Cible** :
- le lot du rapport (`RAPPORT_VIDEO.md` §6, L0 à L13) ;
- le module, d'après la carte `IA_WORKFLOW.md` §7. La carte est dans CE dossier (`fo-logs/2026-11-07_VIDEO-AUTOMATISATION/`), pas dans
  `docs/`. Elle porte sur le worktree `integ-0652b`, commit 0e340b99 ;
- la taille S, M ou L, et les dépendances.

**Pour** (lignes IMPLÉMENTER seulement) :
- **F** : les factions ;
- **J** : votre équipe ;
- **F + J** : les deux.

La capitalisation tourne pour les deux : « Factions ET votre équipe de PNJ (Capi.on n'exclut pas is_player) »,
`script/ai3/capitalisation.lua:8`. Deux réserves :
- le cerveau général IA-G est réservé aux factions (`script/ai3/cerveau.lua:83`, `869`, `890`) ;
- la recherche de votre équipe n'est lancée que si la force du joueur n'a rien en cours (`script/ai3/cerveau.lua:792`).

**Réflexion** : c'est ma lecture de son raisonnement. Ce qu'il ne dit pas est marqué [DÉDUIT].

### Correspondance entre les deux numérotations des rapports
| Premier rapport (T) | Second rapport (L) | Objet |
|---|---|---|
| T1 | L1 (rang calculé) + L2 (porte de rang) | tiers dynamiques |
| T2 | L3 | manque mesuré au consommateur, transit compris |
| T3 | L4 | quotas dans le gabarit |
| T4 | L5 | engagement puis confirmation observée |
| T5, T9, T10, T14 | L6 (+ L0 pour les mesures) | portes de croissance, petites marches, anti-répétition, décider moins à la fois |
| T6 | L12 | hystérésis et verrou des crises |
| T7 | L10 | marches de croissance après stabilité |
| T8 | L7 | amorce et retrait |
| T11 | L9 + L8 | sonder avant de décider, lot prêt |
| T12 | (principe, C07) | placement simple de repli |
| T13 | L11 | trace sur la carte |
| — | L13 | plafonds et gardes fermées par défaut |

---

## A. Vidéo principale, dans l'ordre

| # | mm:ss | Dit (citation courte) | Réflexion derrière | Verdict | Cible, taille, dépendances | Pour |
|---|---|---|---|---|---|---|
| V01 | 0:10 | « I love the smell of Logistics in the morning » | Accroche. | INUTILE POUR NOUS (aucune logique) | — | — |
| V02 | 0:14 | « based entirely on Logistics Bots with no trains or belts » | Un seul moyen de transport, universel : aucun routage à concevoir. | INUTILE POUR NOUS (PNJ au départ, puis tapis) ; À PRENDRE EN COMPTE quand les factions auront un réseau logistique | — | — |
| V03 | 0:19 | « first rocket in under 6 hours … 1,000 [science] per minute in under a day » | La réussite se mesure par jalons datés. | À PRENDRE EN COMPTE (nos jalons : âge atteint à t) ; INUTILE le chiffre (pas de 1 000 SPM visé) | — | — |
| V04 | 0:22 | « about 30 UPS … 24 UPS if biters are turned on » | La performance se mesure avec ET sans ennemis. | À PRENDRE EN COMPTE (mesures `--seul` avec et sans biters) | — | — |
| V05 | 0:31 | « I'm not building anything, this Factory builds itself » | Aucune intervention humaine. | À PRENDRE EN COMPTE (déjà vrai pour les factions) | — | — |
| V06 | 0:44 | « pretty much any self-expanding Factory requires the recursive blueprints mod » | Il faut poser des plans par script. | INUTILE POUR NOUS (nous avons l'API) | — | — |
| V07 | 0:54 | Le déployeur prend un plan, un planificateur de déconstruction ou un livre ; les signaux disent où et lequel | Séparer une bibliothèque numérotée de gabarits, une position et une commande. | À PRENDRE EN COMPTE (existe : `Build.request` `script/team/build.lua:569`, `spec.gen` 600-607, `Build.SITES` 109) | — | — |
| V08 | 1:09 | « a book of blueprints … and an automated way to tell the blueprint deployer which one to deploy » | Deux pièces : une bibliothèque et UN décideur. | À PRENDRE EN COMPTE (« un seul décideur par levier », `script/ai3/capitalisation.lua:25-32`) | — | — |
| V09 | 1:20 | Moon Logic : « without having to build Acres of combinator setups » | La logique en code plutôt qu'en combinateurs. | INUTILE POUR NOUS (nous sommes un mod) | — | — |
| V10 | 1:37 | « not just science but also the buildings … and … ammunition » | Un seul mécanisme pour la science, les biens d'équipement et les munitions. | À PRENDRE EN COMPTE (tout consommateur dans la même demande : vérifier que munitions et équipement entrent dans les puits de `Ca.requirements`, `shared/ai3/capitalisation.lua:756-763`) | — | — |
| V11 | 1:52 | « avoid hardcoding things as much as possible » | Généralité. | À PRENDRE EN COMPTE (anti-échelle, `tests/iag_test.lua` §8) | — | — |
| V12 | 1:57 | « a system of tiers … the last tier contains space science » | Des rangs de fabrication. | IMPLÉMENTER (rang CALCULÉ, §H) | L1, nouveau `shared/ai3/rang.lua`, appelé dans `Ca.decide` (`capitalisation.lua:1954`) ; M ; aucune | F + J |
| V13 | 2:08 | « ore, oil products and power aren't on this list » | Les rangs ne couvrent que le fabriqué ; matières premières, fluides et énergie ont leurs déclencheurs. | À PRENDRE EN COMPTE (rang 0 = ressources ; énergie : `power_options`, `Ca.options` l.1813 ; fluides : `Pet.think` `script/ai3/petrole.lua:915`) | — | — |
| V14 | 2:12 | « any item with a negative signal is in demand » | La demande est un manque NET mesuré. | IMPLÉMENTER (§G : remède de la vue aveugle) | L3, nouveau `shared/ai3/manque_local.lua`, lecture dans `Team.view` (`script/team/team.lua:462`), puits de `Ca.requirements` (l.756) ; M ; aucune | F + J |
| V15 | 2:20 | « if there is no demand for anything in tier one we check … tier 2 and so on » | Parcourir les rangs de bas en haut. | IMPLÉMENTER (porte CIBLÉE par dépendance, pas globale) | L2, `Ca.options` l.1791, `Ca.before` l.1784 ; M ; L1 | F + J |
| V16 | 2:29 | « build a tile … the item with the most demand » | Dans le rang retenu, le plus gros manque. | IMPLÉMENTER | L2 ; M ; L1, L3 | F + J |
| V17 | 2:36 | « the lowest number tier that doesn't contain any of its ingredients » | Définition : rang = 1 + rang max des ingrédients. | IMPLÉMENTER | L1 (§H) ; M ; aucune | F + J |
| V18 | 2:40 | Exemple des circuits verts (plaques rang 1, câble rang 2) | La règle sur un objet. | IMPLÉMENTER (cas de test) | L1, `tests/rang_test.lua` ; S ; L1 | F + J |
| V19 | 2:49 | « if there isn't enough copper wire it doesn't matter how many green chip assemblers we have » | La demande d'en haut est souvent le symptôme d'un manque en bas. | IMPLÉMENTER | L2 ; M ; L1 | F + J |
| V20 | 3:00 | « shortages of low-level ingredients … higher tier products aren't in demand anymore » | Soigner la racine. | IMPLÉMENTER (même porte) | L2 ; M ; L1 | F + J |
| V21 | 3:11 | « the smallest unit of construction … a tile » | Unité petite et fixe. | IMPLÉMENTER (une cellule de plus par objet et par décision sur un manque mesuré) | L6, boucle de `Ca.decide` l.1973 ; S ; L3 | F + J |
| V22 | 3:17 | « a 3X3 grid of these is called a mega tile » | Regroupement autour d'une case commune. | À PRENDRE EN COMPTE (quartiers du treillis, `shared/team/plan.lua` l.5-13) | — | — |
| V23 | 3:20 | « building a blank Mega tile then filling each of the eight empty tiles » | L'enveloppe commune (logistique, défense, courant) d'abord, les modules ensuite. | IMPLÉMENTER (lot prêt avant l'ordre) | L8, `Build.think` (`build.lua:4846`), `shared/ai3/emplacements.lua` règle 2 ; M ; aucune | F + J |
| V24 | 3:28 | « keep manufacturing until it has 1 minute's worth of surplus » | Quota de sortie DANS le module. | IMPLÉMENTER | L4, `shared/team/patrons.lua`, `keep_stock` `build.lua:3904-3911` ; M ; aucune | F + J |
| V25 | 3:36 | « request 1 minute's worth of ingredients » | Quota d'entrée dans le module. | IMPLÉMENTER | L4 ; M ; aucune | F + J |
| V26 | 3:38 | « report … any ingredients that are missing » | Chaque module publie son manque. | IMPLÉMENTER | L3 ; M ; aucune | F + J |
| V27 | 3:44 | « the ingredient inserters … only work if there is less than 1 minute worth of product » | La garde est sur l'ENTRÉE : un module plein n'avale pas d'ingrédients, qui restent pour les autres. | IMPLÉMENTER (pas de tournée d'alimentation vers une sortie pleine ; la collecte reste) | L4, quais `build.lua:3925-3983`, `Board.add` `script/team/board.lua:398` ; M ; aucune | F + J |
| V28 | 3:50 | « subtracts from the number of ingredients that are needed, and if the number is negative … passed » | Manque = besoin − contenu ; seuls les manques sont publiés. | IMPLÉMENTER | L3 ; M ; aucune | F + J |
| V29 | 4:03 | « the green chip tile will report that copper wire is in demand » | La demande naît de ce qui est POSÉ. | IMPLÉMENTER | L3 ; M ; aucune | F + J |
| V30 | 4:13 | « continue building them until copper wire demand is satisfied or a lower tier ingredient … is in demand » | Poser, remesurer, reposer ; un rang plus bas prend la main. | IMPLÉMENTER | L2 + L3 + L6 ; M ; L1 | F + J |
| V31 | 4:23 | « power and oil … require special case Mega tiles » | Les grosses infrastructures sont des leviers à part. | À PRENDRE EN COMPTE (existe : courant, pétrole, champ) | — | — |
| V32 | 4:29 | « a perfect balance of solar panels and accumulators » | Une unité d'énergie équilibrée. | INUTILE POUR NOUS (choix de contenu) | — | — |
| V33 | 4:37 | « Robo ports can use up to 4 megawatts … hard to break even » | Le transport consomme de l'énergie. | À PRENDRE EN COMPTE (bras, tapis, poteaux ; roboports plus tard) | — | — |
| V34 | 4:46 | « giant oceans of solar dotted with islands of manufacturing » | Une énergie peu dense étale l'usine. | À PRENDRE EN COMPTE (la distance tue des PNJ : F239, F251) | — | — |
| V35 | 4:53 | « nuclear Mega tile with a 2x2 reactor neighbor bonus » | Choix nucléaire. | INUTILE POUR NOUS (contenu ; nucléaire contre vapeur : décision du DC) | — | — |
| V36 | 5:00 | « check if the steam in the storage tanks has gone below a certain threshold … feed fuel cells » | Combustible selon le tampon d'énergie. | À PRENDRE EN COMPTE (règles des brûleurs ; gain faible) | — | — |
| V37 | 5:12 | « only feed them when they go below 500 » | Hystérésis du combustible. | À PRENDRE EN COMPTE | — | — |
| V38 | 5:26 | « doesn't have any method for building or piping pump jacks, so … coal liquefaction » | Choisir la recette que l'exécutant SAIT poser. | À PRENDRE EN COMPTE (existe : `can_exec`, `Fl.executors`) | — | — |
| V39 | 5:32 | « start with a few barrels of heavy oil … to Kickstart » | Une recette qui consomme son produit exige une amorce. | IMPLÉMENTER (cycle détecté, amorce écrite, §H) | L1 (`cyc`, `seed`) ; S ; L1 | F + J |
| V40 | 5:41 | « coal liquefaction has some pretty wild product ratios » | Co-produits déséquilibrés. | INUTILE POUR NOUS (recette vanilla précise) | — | — |
| V41 | 5:50 | « more barrels of heavy oil than light oil … cracked into light oil » | Équilibrer des co-produits par comparaison de stocks. | À PRENDRE EN COMPTE (`shared/ai3/fluides.lua` refuse les sous-produits fluides ; à revoir si on les accepte) | — | — |
| V42 | 6:02 | « petroleum pipes get full … turn the excess petroleum into solid fuel » | Soupape : un co-produit plein n'arrête pas la chaîne. | À PRENDRE EN COMPTE (W boucle B3, D3 ; voir §G conflit FLUX) | — | — |
| V43 | 6:13 | « this basically never happens » | Garde rare mais nécessaire. | À PRENDRE EN COMPTE | — | — |
| V44 | 6:16 | « places a premium on mining its own resources » | L'extraction propre d'abord. | À PRENDRE EN COMPTE (capitalisation : couvrir et ouvrir) | — | — |
| V45 | 6:20 | « ore in an upcoming Mega tile … built as a blank Mega tile even if we're in a power crisis » | Saisir le gisement sur le chemin de croissance, même en crise. | IMPLÉMENTER | L9, lots « gisement » `shared/team/plan.lua` l.9-11, `P.MIN_RES_TILES` l.42 ; S ; aucune | F + J |
| V46 | 6:29 | « we don't know when we'll come across ore again » | L'occasion rare passe avant le besoin courant. | IMPLÉMENTER (même règle) | L9 ; S | F + J |
| V47 | 6:31 | « whenever we build a tile we also scan for ore » | Sonder chaque place avant d'y poser. | IMPLÉMENTER | L9 ; S | F + J |
| V48 | 6:38 | « infinite chests that will supply a dribble of ore » | L'amorce est un FILET, elle ne masque pas le besoin d'extraction. | À PRENDRE EN COMPTE (`Ca.HAND_CAPITAL` = 0, `capitalisation.lua:105`) | — | — |
| V49 | 6:45 | « after about a dozen Mega tiles … we don't need these anymore » | L'amorce s'éteint d'elle-même. | À PRENDRE EN COMPTE | — | — |
| V50 | 6:56 | « the mall of Shame … rows of infinite chests that supply all the buildings » | Source provisoire. | INUTILE POUR NOUS (triche ; l'amorce est reprise en V51 à V56) | — | — |
| V51 | 7:06 | « only going to use these until we have a tile that can craft the buildings » | Retirer l'amorce dès que la production existe. | IMPLÉMENTER (en partie là : `Ml.hand_allowed` `shared/ai3/mall.lua:168`) | L7 ; S ; L5 | F + J |
| V52 | 7:10 | « a constant combinator that puts a demand for 10,000 of the building » | Demande de départ FORCÉE des biens d'équipement. | IMPLÉMENTER (graine = matériel des prochains projets du plan directeur) | L7, `Ml.decide` `mall.lua:98`, file de `Build.request` ; S ; aucune | F + J |
| V53 | 7:18 | « try and build tiles that manufacture these buildings as soon as it can » | Le capital qui fabrique le capital d'abord. | IMPLÉMENTER (effet de la graine) | L7 ; S | F + J |
| V54 | 7:21 | « reports … when it first successfully manufactures its product » | Fin = 1re PRODUCTION, pas la pose. | IMPLÉMENTER | L5, entrée `machines` de `Ca.decide` (l.1941), `advance` `build.lua:4098` ; M ; aucune | F + J |
| V55 | 7:26 | Le déployeur retire le coffre infini, le bras, le coffre et le combinateur | Retrait complet et automatique. | IMPLÉMENTER (main retirée à la 1re production) | L7 ; S ; L5 | F + J |
| V56 | 7:35 | « an arithmetic combinator that holds the number of products that were pulled » | Garder la mesure de ce que l'amorce a fourni. | IMPLÉMENTER (compteur `[FO-AMORCE]`) | L7 ; S | F + J |
| V57 | 7:44 | « tiles for everything in the mall and … enough tiles to satisfy all the downstream demand, what do we do? » | L'état « rien ne manque » est explicite. | IMPLÉMENTER (prédicat « aucun manque à aucun rang ») | L10 ; S ; L1, L3 | F (J à vérifier : recherche, `cerveau.lua:792`) |
| V58 | 7:49 | « a 5-minute timer and if no products come into demand … we build a research tile » | Minuteur de stabilité avant de grandir. | IMPLÉMENTER (variante de C2, à comparer) | L10, `Dm.step` `shared/ai3/demande.lua` ; S ; L1, L3 | F (J à vérifier) |
| V59 | 7:58 | « research tiles report their demand … creates demand for all seven sciences » | Le sommet est un consommateur comme un autre. | IMPLÉMENTER (les labos publient leur manque) | L3 + L10 ; S | F + J |
| V60 | 8:03 | « strain demand on other products or create demand for products that we don't have tiles for yet » | La cascade dimensionne l'amont. | À PRENDRE EN COMPTE | — | — |
| V61 | 8:09 | « launched a rocket and have some production capacity for each of the seven sciences » | Couvrir chaque pack. | À PRENDRE EN COMPTE ; INUTILE la fusée | — | — |
| V62 | 8:16 | « about 6 game hours and 100 mega tiles » | Ordres de grandeur. | INUTILE POUR NOUS (leur échelle) | — | — |
| V63 | 8:22 | « build out a ton of power to handle the load of all these tiles running continuously » | La charge réelle n'apparaît qu'en marche : l'énergie se règle sur la charge mesurée. | À PRENDRE EN COMPTE (`power = { have_kw, used_kw }`, `Ca.decide` l.1947) | — | — |
| V64 | 8:27 | « backfill some of the slower tiles … that built up surpluses » | Une recette lente vit sur son stock, puis se rattrape. | À PRENDRE EN COMPTE (voir V79) | — | — |
| V65 | 8:33 | « if things stay that way for 5 minutes straight we build a new research tile » | Stabilité CONTINUE. | IMPLÉMENTER | L10 ; S | F (J à vérifier) |
| V66 | 8:40 | « and then whatever tiles are needed to keep up the pace » | La marche du sommet déclenche la cascade. | IMPLÉMENTER | L10 ; S | F (J à vérifier) |
| V67 | 8:44 | « continues indefinitely until … 500 mega tiles and 25 research tiles » | Croissance sans fin, plafond au sommet seulement. Écart : 484 dans G. | À PRENDRE EN COMPTE (C2 « à l'infini ») ; INUTILE les chiffres | — | — |
| V68 | 8:56 | « most of the footage … with biters turned off » | Mettre au point sans ennemis. | À PRENDRE EN COMPTE (déjà : Paisible) | — | — |
| V69 | 9:02 | « several days of real world time » avec biters | La défense ralentit énormément la croissance. | À PRENDRE EN COMPTE | — | — |
| V70 | 9:09 | « an artillery cannon that clears the area … for about 36 mega tiles » | Zone sûre initiale à la taille de la croissance. | INUTILE POUR NOUS (artillerie tardive ; adversaires actifs) | — | — |
| V71 | 9:16 | « sets a flag each time the factory reaches a corner … artillery station tile at the next opportunity » | Défense par la géométrie ; drapeau différé consommé à la prochaine place. | INUTILE POUR NOUS (notre défense suit la menace) ; À PRENDRE EN COMPTE l'idée du drapeau différé | — | — |
| V72 | 9:25 | « clear biter nests before we try to build … we have no way to detect or fix » | N'engager qu'une place sûre ; un chantier incomplet doit être détectable. | IMPLÉMENTER | L8 + L5 ; M | F + J |
| V73 | 9:35 | « waits until almost all construction Bots are idle before surveying or building » | Pas plus de chantiers que les bras ne servent. | IMPLÉMENTER (porte des bras à seuil croissant) | L6, `Dm.slots` (`shared/ai3/demande.lua`) ; S ; L0 | F + J |
| V74 | 9:44 | « construction Bots will be kept busy fixing and replacing damaged buildings » | La réparation prend la priorité par la porte seule. | À PRENDRE EN COMPTE (pile : R1 avant R3, `shared/ai3/pile.lua:108`) | — | — |
| V75 | 9:54 | « inject one or two research tasks for artillery range … gaps in artillery coverage » | Recherche dictée par un besoin mesuré. | À PRENDRE EN COMPTE (IA-G : valeur militaire, `script/ai3/general.lua:585`) | — | — |
| V76 | 10:18 | « the rail based tiles had to be huge » | Historique. | INUTILE POUR NOUS | — | — |
| V77 | 10:25 | « built the same tile twice by accident … massive downstream demand spikes » | L'erreur coûte en proportion de la taille de l'unité. | IMPLÉMENTER (petites marches ; mesure H-VID-2 d'abord) | L6 ; S ; L0 | F + J |
| V78 | 10:33 | « if we build one too many … we don't create too much downstream demand » | Même raison. | IMPLÉMENTER | L6 ; S | F + J |
| V79 | 10:40 | « a surplus … doesn't get so large that it prevents us from realizing that we don't have enough production capacity » | Un gros stock MASQUE un manque de capacité. | IMPLÉMENTER (une matière n'est saturée que si son débit net ≥ 0 : revoir `B.saturated` `shared/ai3/buts.lua:169` (150 était périmé) ; `Ca.H_STOCK` = 10 min, l.87) | revue de `buts.lua` ; S ; aucune | F + J |
| V80 | 10:46 | « the main reason I opted for this unconventional design » | La granularité est le choix fondateur. | À PRENDRE EN COMPTE | — | — |
| V81 | 10:57 | « a rail tile would report a one … if it was missing a particular ingredient » | Un signal binaire ne suffit pas. | IMPLÉMENTER (manques en quantités) | L3 ; M | F + J |
| V82 | 11:02 | « I know exactly how much of each ingredient is in demand » | Le manque est quantitatif. | IMPLÉMENTER | L3 ; M | F + J |
| V83 | 11:09 | « product that is in transit is accounted for as well » | Pas de double livraison. | IMPLÉMENTER (transit = tâches réservées et inventaires des PNJ) | L3, registre `board.lua:839-920` ; M | F + J |
| V84 | 11:17 | « Bots are the most brute force method of transportation » | Il reconnaît la force brute. | INUTILE POUR NOUS | — | — |
| V85 | 11:23 | « I just add more Bots until stuff is flowing » | Dimensionner le transport sur sa saturation. | À PRENDRE EN COMPTE (existe : `E.decide` `shared/ai3/effectif.lua:137` pour les factions ; `grow_due` pour votre équipe, `team.lua:651-664`) | — | — |
| V86 | 11:30 | « robo ports become the number one power draw, we just build more power » | Le transport remonte dans la demande d'énergie. | À PRENDRE EN COMPTE | — | — |
| V87 | 11:36 | « travel times get too long … overbuild … until … close to where it's needed » | Localité émergente. | INUTILE POUR NOUS (PNJ mortels en route ; placement par distance, `plan.lua` l.9-13) | — | — |
| V88 | 11:45 | « this Factory is able to address its own issues » | Chaque panne produit un signal que la même boucle traite. | À PRENDRE EN COMPTE (chaque défaut doit avoir un signal et un levier) | — | — |
| V89 | 11:56 | « keep UPS above 60 for a couple hundred mega tiles » | La performance tient, puis cède. | À PRENDRE EN COMPTE | — | — |
| V90 | 12:03 | « slowed to half speed » | Chiffre. | INUTILE POUR NOUS | — | — |
| V91 | 12:10 | « minifactory that is self-contained … several dozen copies with unconnected logistic networks » | Cloisonner borne le coût. | À PRENDRE EN COMPTE (quartiers autonomes) | — | — |
| V92 | 12:22 | « design the factory as it goes … I pay the price in … inefficient layout, long travel times » | Le prix de la conception réactive. | À PRENDRE EN COMPTE (garder l'hybride : calcul et mesure) | — | — |
| V93 | 12:37 | « I never got around to sorting out … offshore pump tiles » | Limite de son exécutant. | INUTILE POUR NOUS (nous posons des pompes) | — | — |
| V94 | 12:43 | « some sort of multiphase Blueprinting logic » | Un gabarit lié au terrain demande plusieurs phases. | À PRENDRE EN COMPTE (plan directeur : rive, énergie) | — | — |
| V95 | 12:45 | « infinite water pipes, which are definitely a copout » | Triche reconnue. | INUTILE POUR NOUS (triche) | — | — |
| V96 | 12:59 | « level three modules all over this Factory … I really should be crafting them » | Triche reconnue. | INUTILE POUR NOUS (triche) | — | — |
| V97 | 13:03 | « about as large as a 1,000 [SPM] Factory alone » | Un intermédiaire haut se valorise par sa chaîne entière. | À PRENDRE EN COMPTE (existe : `Ca.chain_capital` `capitalisation.lua:827`) | — | — |
| V98 | 13:09 | « it would take weeks » | Chiffre. | INUTILE POUR NOUS | — | — |
| V99 | 13:16 | « I've disconnected the combinators so we never actually build the tiles for them » | Pouvoir EXCLURE un objet de la demande. | À PRENDRE EN COMPTE (réglage d'exclusion ; refus écrits) | — | — |
| V100 | 13:21 | « would require refactoring every manufacturing tile » | Des quotas figés coûtent une refonte. | À PRENDRE EN COMPTE (L4 : quotas lus des débits) | — | — |
| V101 | 13:35 | « at least a 3 by 3 block of Mega tiles just for combinators » ; commenter du code plutôt qu'épingler | Lua contre combinateurs. | INUTILE POUR NOUS | — | — |
| V102 | 13:56 | « I've linked a zip of the scenario » | Distribution. | INUTILE POUR NOUS | — | — |
| V103 | 14:01 | GreyGoo, JOSEF, l'usine communautaire de Nilaus | Références. | INUTILE POUR NOUS (non lues) | — | — |
| V104 | 14:36 | « grab the scenario … see if you can improve on it » | Appel. | INUTILE POUR NOUS | — | — |
| V105 | 14:44 | « automated Factory design could become a new category of play » | Vision. | INUTILE POUR NOUS | — | — |
| V106 | 14:54 | Conclusion, « stay building » | Fin. | INUTILE POUR NOUS | — | — |

## B. Le code (G), bloc par bloc et ligne par ligne : seuils et portes

| # | Ligne(s) | Ce que fait le code | Réflexion derrière | Verdict | Cible, taille, dépendances | Pour |
|---|---|---|---|---|---|---|
| G01 | 1-16 | Contrat des entrées et des sorties en tête du fichier | Une règle commence par son contrat. | À PRENDRE EN COMPTE (nos en-têtes de règles pures) | — | — |
| G02 | 17 | `MAX_MEGATILES = 484` | Plafond de croissance. | À PRENDRE EN COMPTE (plafond de sûreté par type) | — | — |
| G03 | 18 | `MAX_RESEARCH_TILES = 25` | Plafond du sommet. | À PRENDRE EN COMPTE | — | — |
| G04 | 20-21 | `PIN_OFFSET_X/Y` | Calage des épingles. | INUTILE POUR NOUS | — | — |
| G05 | 27 | `signal-info` = nombre de mégatuiles, PUBLIÉ par les mégatuiles | Le compte vient de l'observation. | À PRENDRE EN COMPTE (voir G35) | — | — |
| G06 | 28 | `signal-dot` = nombre de tuiles de recherche | Idem. | À PRENDRE EN COMPTE | — | — |
| G07 | 29-30 | Robots logistiques libres et total (A, B) | Mesure de saturation du transport. | À PRENDRE EN COMPTE (analogue : PNJ libres et tâches libres, `[FO-ACTIF]`) | — | — |
| G08 | 31-32 | Robots de construction libres et total (C, D) | Mesure des bras. | À PRENDRE EN COMPTE (bras libres, `shared/ai3/bras.lua`) | — | — |
| G09 | 33 | Charge des accumulateurs (E) | Mesure de l'énergie. | À PRENDRE EN COMPTE (`power`, `Ca.decide` l.1947) | — | — |
| G10 | 34 | `lastSignal` relu sur le fil vert (sa propre sortie) | Mémoire du dernier posé. | INUTILE POUR NOUS (nous avons `global`) | — | — |
| G11 | 36-37 | occupés = total − libres | Les bras occupés se déduisent. | À PRENDRE EN COMPTE | — | — |
| G12 | 40-42 | Porte : occupés > mégatuiles ÷ 25 + 1 → attendre. Commentaire : « We wait less the larger the factory is, since overproduction in the late game is less catastrophic. » | Le seuil de chantiers parallèles grandit avec la taille. | IMPLÉMENTER | L6, `Dm.slots` (`shared/ai3/demande.lua`) ; S ; L0 | F + J |
| G13 | 43-44 | Porte : libres < total ÷ 10 → « logistic shock » | Ne pas charger un transport saturé. | IMPLÉMENTER (porte de transport : PNJ libres sous 10 % pendant 2 pensées, ou tâches libres > k × PNJ) | L6 ; S ; L0 | F + J |
| G14 | 46 | Porte : total < 300 → « construction shock » (« only in biter runs ») | Pas d'extension quand les bras sont décimés. | À PRENDRE EN COMPTE (existe : pile R0, équipe sous son effectif de départ) | — | — |
| G15 | 50 | Entrée en crise d'énergie : charge < 40 | Seuil bas. | IMPLÉMENTER | L12, `power_options` (`Ca.options` l.1813), `Pi.signals` `pile.lua:424` ; S | F + J |
| G16 | 51-52 | Maintien de la crise tant que charge < 50 | Seuil haut : hystérésis. | IMPLÉMENTER | L12 ; S | F + J |
| G17 | 53 | `need_power` verrouillé jusqu'à la pose d'une mégatuile d'énergie | Ne pas lâcher le correctif quand la crise « guérit » un instant. | IMPLÉMENTER (verrou levé à la confirmation, L5) | L12 ; S ; (L5) | F + J |
| G18 | 55-57 | `can_build` = ni constructeurs occupés, ni choc logistique, ni choc de construction. L'énergie n'est PAS une porte : elle oriente le choix. | Une crise d'énergie fait CONSTRUIRE (de l'énergie) au lieu d'arrêter. | À PRENDRE EN COMPTE (pile : R1 et R2 servent la crise, pas d'arrêt global) | — | — |
| G19 | 59 | `out = {}` à chaque passage | Commandes réémises, jamais périmées. | À PRENDRE EN COMPTE (ordres idempotents) | — | — |
| G20 | 61 | Commentaire : « Each item is in the first tier that does not contain any of its ingredients » | Règle des rangs. | IMPLÉMENTER (calculée) | L1 (§H) ; M | F + J |
| G21 | 62-167 | 10 rangs, environ 100 objets, chacun avec son numéro de plan | Table à la main. | IMPLÉMENTER (remplacer par le calcul) | L1 ; M | F + J |
| G22 | 108, 111, 114 | Écarts à sa propre règle : pack logistique au rang 4 (l'`inserter`, son ingrédient, y est aussi) ; four en pierre au rang 2 (pierre seule) ; plastique au rang 5 (charbon et gaz) | Une table à la main se trompe. | À PRENDRE EN COMPTE (cas de test de L1) | — | — |
| G23 | 78, 85-86, 93, 115 | Barils comptés comme objets (vide au rang 3, eau au rang 4) | Ses fluides voyagent en barils. | À PRENDRE EN COMPTE (chez nous les fluides vont par tuyaux : rang de leur recette, eau pompée au rang 0) | — | — |
| G24 | 170 | Rangs parcourus de 1 à 10 | Du bas vers le haut. | IMPLÉMENTER | L2 ; M ; L1 | F + J |
| G25 | 178 | Candidat si `red[objet] < 0` | Seul un manque net compte. | IMPLÉMENTER | L2 + L3 ; M | F + J |
| G26 | 179-180 | Le plus négatif gagne ; `<` strict : à égalité, le premier de la liste | Le plus gros manque, départage stable. | IMPLÉMENTER (égalité par clé triée) | L2 ; M | F + J |
| G27 | 184-186 | Le dernier posé (`lastSignal`) est sauté, `check_again` noté | Le signal est en retard sur la pose. | IMPLÉMENTER (anti-répétition sur un signal MESURÉ) | L6 ; S ; L3 | F + J |
| G28 | 191-204 | S'il est le SEUL en manque du rang, on le reprend ; on ne monte pas (« they might depend on this item ») | La porte de rang est stricte. | IMPLÉMENTER (stricte pour les objets qui en DÉPENDENT, pas pour les autres) | L2 ; M ; L1 | F + J |
| G29 | 206 | `signal-L` = rang retenu, en sortie | Trace du rang choisi. | IMPLÉMENTER (le rang retenu `r*` dans `[FO-CAPI]`) | L2 / L11 ; S | F + J |
| G30 | 210 | Rien en manque : `nil` | État « rien ne manque ». | IMPLÉMENTER | L10 ; S | F (J à vérifier) |
| G31 | 213 | Initialisation seulement quand le déployeur est vu sur le réseau | Ne rien décider tant que l'exécutant n'existe pas. | À PRENDRE EN COMPTE (`can_exec`) | — | — |
| G32 | 219-225 | « we can't trust the input from the outside world … we wait for the numbers from the circuit network to match the expected number from the variable » | Compteur d'intention contre observation. | IMPLÉMENTER | L5 ; M | F + J |
| G33 | 225 | `tilesBuilt` relu sur le réseau à l'initialisation | Reprise sur l'observation. | À PRENDRE EN COMPTE (après un chargement, reconstruire depuis l'état observé, comme CAPI-DECIDE) | — | — |
| G34 | 228-236 | Les rangs sont imprimés au démarrage | Trace de configuration. | IMPLÉMENTER (ligne `[FO-RANG]` à chaque recalcul) | L1 ; S | F + J |
| G35 | 242-243 | Nouvelle mégatuile si `tilesBuilt % 8 == 0` ET `tilesBuilt ÷ 8 ≥ mégatuiles publiées` | Pas d'étape suivante avant la confirmation. | IMPLÉMENTER | L5 ; M | F + J |
| G36 | 246-271 | Position = fonction du NOMBRE de mégatuiles (spirale), sans carte gardée | Le placement se déduit d'un compteur : rien à désynchroniser. | À PRENDRE EN COMPTE (repli de placement simple, C07) | — | — |
| G37 | 275-278 | Sonde : 30 × 30 au décalage +2 | Lire la place avant de choisir. | IMPLÉMENTER | L9 ; S | F + J |
| G38 | 279-283 | Défrichage (plan 109) sur 50 × 50 pendant la sonde | Préparer la place avant le choix. | IMPLÉMENTER | L8 ; M | F + J |
| G39 | 286 | `delay = 60` entre la sonde et la décision | Laisser la sonde rendre son résultat. | À PRENDRE EN COMPTE | — | — |
| G40 | 293-295 | Chantier en cours (≠ 109) : continuer | Jamais d'abandon pour un nouveau choix. | À PRENDRE EN COMPTE (projets : inertie de +20 %) | — | — |
| G41 | 297-299 | 1re mégatuile = nucléaire | L'énergie d'abord. | À PRENDRE EN COMPTE (1re expansion = énergie) | — | — |
| G42 | 303 | Uranium sondé > 100 000 → mégatuile vide | Gisement rare saisi. | IMPLÉMENTER (seuils lus en données, pas en dur) | L9 ; S | F + J |
| G43 | 303-305 | Somme des 5 minerais sondés > 1 000 000 → mégatuile vide, avant l'énergie | Gisement saisi même en crise. | IMPLÉMENTER | L9 ; S | F + J |
| G44 | 317 | Nucléaire seulement après 10 mégatuiles | Une grosse unité seulement quand l'usine est assez grande. | À PRENDRE EN COMPTE | — | — |
| G45 | 318 | … et plus de 90 cellules de combustible au réseau | Ne poser que ce que sa chaîne nourrit. | À PRENDRE EN COMPTE (existe : `Ca.fed_max`, `can_exec`) | — | — |
| G46 | 319-321 | … et plus de 3 réacteurs au réseau (ou coffres infinis) | Les pièces doivent être là AVANT l'ordre. | À PRENDRE EN COMPTE (existe : objets du gabarit fabricables) | — | — |
| G47 | 322-323 | … et pas de nucléaire à la mégatuile précédente (commentaire : « last 2 », code `>= last + 1`) | Pas deux grosses unités de suite. Écart commentaire/code. | IMPLÉMENTER (anti-répétition des grosses unités) ; À PRENDRE EN COMPTE (relire le code, pas le commentaire) | L6 ; S | F + J |
| G48 | 329-333 | Sinon solaire | Repli sûr. | À PRENDRE EN COMPTE | — | — |
| G49 | 334-335 | `need_power = false`, `tilesBuilt += 8` | Le verrou retombe à la POSE. | À PRENDRE EN COMPTE (chez nous : à la confirmation, L5) | — | — |
| G50 | 336-338 | Moins de 9 mégatuiles : solaire quand même | Énergie d'avance au départ. | À PRENDRE EN COMPTE | — | — |
| G51 | 341-347 | Pétrole si un baril (gaz, huile légère ou lourde) est en manque et que la précédente n'était pas pétrole | Anti-répétition ; le fluide se juge sur ses barils. | IMPLÉMENTER (même anti-répétition que G47) | L6 ; S | F + J |
| G52 | 349-352 | Sinon mégatuile vide (8 places) | Défaut : de la place pour fabriquer. | À PRENDRE EN COMPTE | — | — |
| G53 | 354 | `is_paving = true` (jamais relu) | Reste de code. | INUTILE POUR NOUS | — | — |
| G54 | 388-389 | Drapeau d'artillerie : plus de 36 mégatuiles et la spirale tourne un coin | Défense géométrique. | INUTILE POUR NOUS (défense par la menace) | — | — |
| G55 | 391-395 | Coordonnées x × 48 + 2, y × 48 ; `delay = 60` | Grille fixe. | INUTILE POUR NOUS (treillis 24 + 4) | — | — |
| G56 | 402-427 | Tuile n = `tilesBuilt % 8 + 1` : les 8 voisines de la case centrale | Ordre de remplissage fixe. | À PRENDRE EN COMPTE (repli simple, C07) | — | — |
| G57 | 429-432 | Sonde : 10 × 10 par tuile | Sonder chaque place. | IMPLÉMENTER | L9 ; S | F + J |
| G58 | 436-438 | Déployeur occupé : refaire LE MÊME plan | Relance idempotente. | IMPLÉMENTER | L5 ; S | F + J |
| G59 | 440 | Uranium : sondé > 100 000 ET réseau < 100 000 | Plafond de stock. | À PRENDRE EN COMPTE (existe : saturation, `B.SAT_FACTOR`) | — | — |
| G60 | 446-449 | Fer, cuivre, charbon : sondé > 100 000 et réseau < 250 000 ; pierre < 200 000 | Plafond de stock par matière première : on n'ouvre plus de mine au-delà. | À PRENDRE EN COMPTE (existe ; voir le conflit FLUX au §G pour D3) | — | — |
| G61 | 451-462 | Minerai le plus abondant, à égalité dans l'ordre fer, cuivre, pierre, charbon | Exploiter ce que la place offre ; départage fixe. | À PRENDRE EN COMPTE | — | — |
| G62 | 469-475 | Drapeau d'artillerie consommé ici, puis retombé | Obligation différée consommée à la prochaine place. | À PRENDRE EN COMPTE (idée du drapeau différé) | — | — |
| G63 | 477-485 | Rangs (G24 à G28) | Le cœur. | IMPLÉMENTER | L2 ; M ; L1 | F + J |
| G64 | 486-493 | Recherche : moins de 25 tuiles et minuteur échu ; minuteur remis à l'infini | Marche du sommet. | IMPLÉMENTER | L10 ; S | F (J à vérifier) |
| G65 | 494-501 | Crise d'énergie et rien d'autre : « Small Power Station » (commentaire l.494-495 : éviter d'attendre la recherche pendant une crise) | Petite unité d'urgence ; pas de croissance en crise. | À PRENDRE EN COMPTE (centrale de secours bon marché) | — | — |
| G66 | 506-511 | Rien en manque, pas de crise, pas de minuteur : minuteur = maintenant + 18 000 ticks | Stabilité de 5 min avant de grandir. | IMPLÉMENTER | L10 ; S | F (J à vérifier) |
| G67 | 549-555 | Étiquette de carte par tuile (`_api`, `add_chart_tag`) | Voir chaque décision sur la carte. | IMPLÉMENTER | L11 ; S | F + J |
| G68 | 556-558 | Validation : `tilesBuilt += 1` seulement si le déployeur était libre et qu'un plan est choisi | L'intention n'avance que si l'ordre est parti. | IMPLÉMENTER | L5 ; S | F + J |
| G69 | 559-564 | Toute pose ANNULE le minuteur de recherche | La stabilité repart de zéro à chaque pose. | IMPLÉMENTER | L10 ; S | F (J à vérifier) |
| G70 | 566 | `delay = 120` après une décision de tuile | Laisser le signal bouger avant de redécider. | À PRENDRE EN COMPTE (notre cadence : 1 min pour la capitalisation) | — | — |
| G71 | 568-570 | Une porte se ferme : la sonde est jetée | Des données périmées ne servent pas. | À PRENDRE EN COMPTE | — | — |
| G72 | 571 | `signal-P` = dernier plan, sur le fil | Mémoire par le fil. | INUTILE POUR NOUS | — | — |
| G73 | 572, 13-14 | `signal-check` vaut 1 quand c'est « a good time for construction and research », 0 en choc logistique | [DÉDUIT] La recherche est coupée quand le transport sature. | À PRENDRE EN COMPTE (tournées de packs moins prioritaires sous saturation ; R3 suspendu) | — | — |

## C. Description et FAQ (D)

| # | Élément | Réflexion derrière | Verdict | Cible |
|---|---|---|---|---|
| D01 | Mise à jour du 17/03/2025 : ne marche plus en 2.0 | Dépendance aux mods. | INUTILE POUR NOUS (1.1.91) | — |
| D02 | Pour transplanter la racine : le livre, « a stack of heavy oil barrels », « at least one logistic bot » | La liste MINIMALE d'amorçage est explicite. | À PRENDRE EN COMPTE (kit de départ écrit et minimal) | — |
| D03 | `von_noying.lua`, `safe_mode` | Option sans biters. | INUTILE POUR NOUS | — |
| D04 | Matériel d'enregistrement | Production vidéo. | INUTILE POUR NOUS | — |
| D05 | « about six months total … most of that was tweaking » | Le gros du travail est le réglage. | À PRENDRE EN COMPTE (temps de réglage, moteur simulé) | — |
| D06 | Le nom « Von Noying » | Anecdote. | INUTILE POUR NOUS | — |
| D07 | Lampes sur un réseau séparé : la courbe de puissance donne le % de robots inactifs | Mesure dans le temps de la saturation du transport. | À PRENDRE EN COMPTE (existe : `[FO-ACTIF]`) | — |
| D08 | Tuiles nucléaires dans la racine : « finding a good build condition … proved difficult » | Une condition de pose fragile se remplace par une instance fixe au départ. | À PRENDRE EN COMPTE | — |

## D. Vidéo de suite (V2), dans l'ordre

| # | mm:ss | Dit | Réflexion derrière | Verdict | Cible | Pour |
|---|---|---|---|---|---|---|
| W01 | 0:01 | Remerciements, plus de 120 000 vues | Intro. | INUTILE POUR NOUS | — | — |
| W02 | 1:26 | Le mod LTN était requis sans le savoir : son signal servait dans un combinateur | Une garde dépend d'une entrée qui peut MANQUER. | IMPLÉMENTER (garde fermée si l'entrée manque, refus écrit) | L13, `Ca.decide` ; S | F + J |
| W03 | 2:00 | « I didn't want anything from the mall to be putting Demand on the network if we were out of water » | Couper une source de demande quand une ressource critique en amont manque (eau, nucléaire, énergie). | À PRENDRE EN COMPTE (la pile suspend R3 ; garde « matière critique » à envisager) | — | — |
| W04 | 2:19 | « in practice this might not really be needed … water crises end up sorting themselves out » | Une garde jamais prouvée. | À PRENDRE EN COMPTE (une garde sans mesure se prouve ou se retire) | — | — |
| W05 | 2:40 | Mod Auto Research : « you need that research to keep coming in » | La file de recherche ne doit jamais être vide. | À PRENDRE EN COMPTE (IA-G choisit toujours ; votre équipe : `cerveau.lua:792`) | — | — |
| W06 | 4:03 | Il MONTRE la liste de ses mods installés | (montré, non vu) | INUTILE POUR NOUS | — | — |
| W07 | 4:37 | Tutoriel d'installation du scénario | Mode d'emploi. | INUTILE POUR NOUS | — | — |
| W08 | 6:18 | Les scénarios ne se synchronisent pas entre ordinateurs, les sauvegardes oui | Plateforme. | INUTILE POUR NOUS | — | — |
| W09 | 7:57 | Ne pas éditer le scénario en cours ; « this particular function and not on player created for a reason » | Piège d'événement. | INUTILE POUR NOUS | — | — |
| W10 | 9:12 | « planners and pantsers … the AI had to figure out what to do at each step on its own » | Réactif contre planifié. | À PRENDRE EN COMPTE (garder l'hybride : calcul par la capitalisation, mesure par L3) | — | — |
| W11 | 9:45 | « giving the computer as Little Instruction as possible » | Peu de connaissance codée. | À PRENDRE EN COMPTE (anti-échelle) | — | — |
| W12 | 10:24 | L'usine de Griswald calculée d'avance : « 1,000 white science per minute » dans le calculateur | Contrepoint planifié, « immaculate ». | À PRENDRE EN COMPTE | — | — |
| W13 | 12:19 | « I did have to hardcode … these tiers … a little bit unfortunate » | Les rangs doivent venir des données. | IMPLÉMENTER | L1 (§H) ; M | F + J |
| W14 | 12:38 | « as long as the algorithm knows about this general structure, that you can't make these things without these things » | La seule connaissance utile est la structure des dépendances. | IMPLÉMENTER (rang depuis le graphe) | L1 ; M | F + J |
| W15 | 13:29 | Les commentaires demandent de la « real AI » | Sujet. | INUTILE POUR NOUS | — | — |
| W16 | 14:29 | « if you have a deterministic algorithm that does the correct thing almost all the time, replacing it with AI … approximating this function » | Une règle déterministe juste vaut mieux qu'un apprentissage. | À PRENDRE EN COMPTE (règles pures déterministes) | — | — |
| W17 | 15:31 | Monte-Carlo : « not always pick the best one … local maximum » | Explorer pour sortir d'un maximum local. | INUTILE POUR NOUS (déterminisme, pas d'apprentissage) | — | — |
| W18 | 16:28 | Go se simule presque gratuitement, Factorio non | Le coût de la simulation borne l'apprentissage. | À PRENDRE EN COMPTE (notre moteur simulé = « jeu bon marché ») | — | — |
| W19 | 17:40 | Une partie probante : 24 h de jeu, environ 12 h réelles | Les preuves longues coûtent cher. | À PRENDRE EN COMPTE (micro-scénarios d'abord ; banc long avec l'accord du DC) | — | — |
| W20 | 19:46 | Pokémon par RL : 1 000 $ de calcul | Ordre de grandeur. | INUTILE POUR NOUS | — | — |
| W21 | 22:08 | « up against a pretty good algorithm … tons and tons of compute » | Conclusion contre le RL. | INUTILE POUR NOUS | — | — |
| W22 | 23:00 | Remerciements, pas de chaîne Factorio | Fin. | INUTILE POUR NOUS | — | — |

## E. Réponses de l'auteur en commentaires (C)

| # | Dit (citation courte) | Réflexion derrière | Verdict | Cible | Pour |
|---|---|---|---|---|---|
| C01 | Portée d'artillerie : « probably the correct answer … bugs wouldn't show up until the factory had been running for hours » | Les défauts tardifs n'apparaissent qu'après des heures. | À PRENDRE EN COMPTE (parties longues au moteur simulé) | — | — |
| C02 | JOSEF : « using Factorio's mechanics alongside combinators » | Les mécaniques natives font le travail sans script. | À PRENDRE EN COMPTE (barres de coffre, F95 ; L4) | — | — |
| C03 | 2.0, assembleur universel | Avenir. | INUTILE POUR NOUS (1.1.91) | — | — |
| C04 | Vanilla : « at least a 3x3 megatile … of combinators » | Combinateurs contre Lua. | INUTILE POUR NOUS | — | — |
| C05 | Balises : « adding beacons means fewer assemblers » ; productivité : « reducing the total number of bots needed » | Moins d'ingrédients = moins de transport. | À PRENDRE EN COMPTE (pour des PNJ, la productivité réduit les tournées : valeur logistique des modules, D-17) | — | — |
| C06 | Réacteurs 2 × 2 : « no room for all the exchangers and turbines » | Contenu. | INUTILE POUR NOUS | — | — |
| C07 | « placement of stuff as "dumb" as possible. The "smarter" the algorithm gets, the higher the likelihood of a really nasty … bug … deep into the run » | La simplicité protège des défauts tardifs. | À PRENDRE EN COMPTE (règle la plus petite qui marche ; repli de placement simple) | — | — |
| C08 | « encode any sort of quotas into the blueprints and not the algorithm » | Le module se règle, le cerveau décide. | IMPLÉMENTER | L4 ; M | F + J |
| C09 | Hexagones ; Moon Logic pour les décalages | Géométrie. | INUTILE POUR NOUS | — | — |
| C10 | 2.0 cassée | Maintenance. | INUTILE POUR NOUS | — | — |
| C11 | Remplacer les coffres infinis par des coffres contenant le nombre mesuré ; sans modules, recalculer les quotas | Dimensionner un vrai kit sur la mesure de l'amorce ; quotas recalculés depuis les débits. | IMPLÉMENTER (compteur d'amorce) ; À PRENDRE EN COMPTE (quotas calculés, L4) | L7 ; S | F + J |
| C12 | « 1000 construction bots and 500*(number of megatiles) logistic bots … trial and error » ; plus d'un million perdus avec biters | Effectif proportionnel à la taille ; pertes énormes. | À PRENDRE EN COMPTE (`E.decide` borne par le travail qui attend) | — | — |
| C13 | Silos : « is there a -10K signal … for all the items in the mall? » | Un défaut de demande se diagnostique sur la graine. | IMPLÉMENTER (plafond par objet ; garde fermée par défaut) | L13 ; S | F + J |
| C14 | « I reach through to _api and set map pins for each tile » | Traçabilité visuelle. | IMPLÉMENTER | L11 ; S | F + J |
| C15 | « Lua is not the UPS bottleneck » | Décision bon marché. | À PRENDRE EN COMPTE (chez nous le script EST le goulot : 84 ms de médiane par pensée, `fo-logs/2026-11-07_DECOUPAGE-PENSEE`) | — | — |
| C16 | Vidéo de 10 h : « you have to keep moving the camera » | Production. | INUTILE POUR NOUS | — | — |
| C17 | Waterfill pas dans les plans | Limite de mod. | INUTILE POUR NOUS | — | — |
| C18 | Factorio 2 force le travail manuel | Avenir. | INUTILE POUR NOUS | — | — |
| C19 | RL : 1 000 $ pour battre Pierre ; 1 M$ pour Factorio | Coût. | INUTILE POUR NOUS | — | — |
| C20 | « better predicting what will be needed next instead of reacting to demand and power spikes after they happen » | La faiblesse d'une boucle réactive, c'est le RETARD. | À PRENDRE EN COMPTE (graine par le plan à venir, L7 ; `Prev.think` pour les menaces, `script/ai3/prevision.lua:403`) | — | — |
| C21 | Musique | Anecdote. | INUTILE POUR NOUS | — | — |
| C22 | UPS qui tend vers 0 | Théorie. | INUTILE POUR NOUS | — | — |
| C23 | Productivité : « production more stable and predictable with fewer boom-bust cycles » | La stabilité a de la valeur. | À PRENDRE EN COMPTE (petites marches, L6) | — | — |
| C24 | « avoid … plug "1000 of all sciences per minute" in to the … calculator » | Concevoir en réagissant. | À PRENDRE EN COMPTE (hybride) | — | — |
| C25 | Résoudre sans casser ce qui marche | Méthode. | À PRENDRE EN COMPTE (A/B octet à octet) | — | — |
| C26 | « lay down tiles with level 1 mods, then later use upgrade planners » | Améliorer sur place. | À PRENDRE EN COMPTE (existe : `Capital.goal` `script/ai3/capital.lua:438`, `Swap.think`) | — | — |
| C27 | « It does require pre-researched techs (I don't know of any SEFs that don't) » | Toutes trichent sur la recherche. | INUTILE POUR NOUS (nous payons la recherche) | — | — |
| C28 | Capture 4K | Matériel. | INUTILE POUR NOUS | — | — |

## F. Scénario (S)

| # | Élément | Réflexion | Verdict |
|---|---|---|---|
| S01 | `research_all_technologies` | Triche de recherche. | INUTILE POUR NOUS |
| S02 | `game.speed = 100` | Accélérer les essais. | INUTILE POUR NOUS |
| S03 | `cheat_mode` du joueur | Triche. | INUTILE POUR NOUS |
| S04 | `safe_mode` : ennemis, falaises, pollution retirés | Banc sans ennemis. | À PRENDRE EN COMPTE (bancs « Paisible ») |
| S05 | Surface 2 (plans) vidée au départ | [DÉDUIT] Plans dessinés sur une seconde surface. | INUTILE POUR NOUS |

---

## G. Les maillons cassés du 7/11 et ce que la vidéo y répond

Source : `IA_WORKFLOW.md` §2 (« maillons fragiles ») et §5 (D1 à D4), lus.

### D0. La vue ne voit pas les coffres de sortie du plan directeur
- **Le maillon [LU W §2]** :
  - `outputs` ne lit que `o.sinks` (`script/faction/outposts.lua:838-845`) ;
  - un champ migré « n'a plus rien à collecter ici » (847-849) ;
  - `view.repat` n'est fait que de ces avant-postes (`team.lua:681`) ;
  - **[DÉDUIT W]** le fer du champ n'existe ni pour le cerveau, ni pour le manque, ni pour la survie, ni pour le fond.
- **Ce que dit la vidéo** : le réseau ADDITIONNE TOUS les coffres fournisseurs, où qu'ils soient. Un manque n'existe que s'il dépasse
  ce stock total, transit compris (M11, M22, M51 ; G25).
- **Remède naturel : L3 (T2), le manque mesuré au consommateur** :
  - **lecture** : le runtime lit, en E1, les coffres de sortie de TOUS les projets du plan directeur, quel que soit leur état (fini,
    chantier, `refuse`, `reserve:pile`), par tranche bornée ;
  - **sortie** : `avail_out[objet]`, un champ à part de `view.stock` pour ne rien compter deux fois ;
  - **calcul** : manque net = besoin mesuré − stock libre du QG − `avail_out` − transit ;
  - **décision** : quand `avail_out` couvre un manque, l'action est de COLLECTER, pas de construire. Une tâche de collecte est émise
    avec la priorité de ce qu'elle débloque ;
  - **lecteurs de `avail_out`** :
    - la vue ;
    - la survie (`Sv.decide`, `shared/team/survie.lua:128`) : pas de mode survie pour une plaque qui attend dans un coffre de sortie,
      c'est la collecte qui devient urgente ;
    - le manque du cerveau ;
    - la capitalisation, au même titre que le stock, sur `Ca.H_STOCK` minutes.
- **Pour** : F + J.

### D1. Recrue payée en fer, fer libre à 0, votre équipe bloquée à 2 PNJ [LU W §5]
- **Les maillons** :
  - la recrue de reconstruction ne rend rien sans plaques (`shared/team/planner.lua:968-975`) ;
  - le fer existe au champ (« plaques 4353 ») mais la vue ne le voit pas : c'est D0 ;
  - la collecte à 52 perd contre 16 tâches libres pour 2 PNJ.
- **Ce que dit la vidéo** :
  - le manque net compte les sorties (D0 : **L3**) ;
  - la porte « choc logistique » arrête d'ajouter du travail quand le transport sature (G13 : **L6**) ;
  - le travail urgent passe par la même boucle (M52).
- **Lots** :
  - **L3** rend le fer visible et transforme le manque en collecte ;
  - **L6** retient les nouveaux chantiers tant que « 0 PNJ libre, 16 tâches libres » ;
  - **[DÉDUIT]** la priorité de la collecte doit hériter de la recrue qui attend ce fer. W §5 D1 note « aucune hausse de priorité de
    la collecte quand une recrue attend ce fer ». C'est à brancher dans L3 : la tâche de collecte prend la priorité du manque
    qu'elle couvre.
- **Pour** : J surtout (votre équipe sous son effectif de départ), F aussi.

### D2. Fer produit au champ, jamais collecté ; fours « sortie pleine » [LU W §5]
- **Les maillons** :
  - collecte et remplissage des quais seulement pour « fini » et « chantier » (`build.lua:4870`) ;
  - bandes « refuse » et « reserve:pile » plus servies ;
  - bras sans courant ;
  - une collecte qui ne prend rien est comptée réussie (W boucle B2).
- **Ce que dit la vidéo** :
  - le stock de TOUS les coffres compte (D0) ;
  - un module ne compte comme capacité qu'à sa 1re production (M38) ;
  - une sortie pleine n'avale plus d'ingrédients (M21).
- **Lots** :
  - **L3** lit les sorties quel que soit l'état et émet la collecte ;
  - **L5** ne compte pas comme capacité un module qui ne produit pas : bande sans courant, sortie jamais vidée. La capitalisation
    voit donc le manque au lieu d'une capacité fantôme, et la cause est écrite (courant) ;
  - **L4** n'alimente plus un four dont la sortie est pleine.
- **Pour** : F + J.

### D3. Coffre du QG plein de pierre, aucun coffre ajouté [LU W §5]
- **Les maillons** :
  - annexe posée seulement avec un coffre en main ;
  - coffre fabriqué seulement par le fond, coupé sous l'effectif de départ ;
  - « stone dort 28888 » ;
  - la pierre continue d'arriver (W boucle B3).
- **Ce que dit la vidéo** :
  - pas de nouvelle mine au-delà d'un plafond de stock (G59, G60) ;
  - une sortie pleine ARRÊTE la production du module : c'est voulu (M18, M21) ;
  - une soupape n'existe que pour un co-produit COUPLÉ (M32).
- **Conflit avec FLUX, TRANCHÉ (7/11, lead) par le lot STOCKAGE-VITAL** (charbonmain, 82d29f9a), d'après la remarque du jour du DC
  (« coffres remplis de pierres ») :
  - le conflit : le lot FLUX garde la tournée des sorties PLEINES d'un produit saturé ou couvert (`shared/ai3/cerveau.lua:441`,
    « le four s'arrête : 17 fours à 100 plaques de cuivre » ; `Fx.drop_service`, `shared/team/flux.lua:164-168`), alors que la
    règle de la vidéo ne collecte plus un produit saturé : sa sortie se remplit et l'extraction s'arrête d'elle-même ;
  - ce que fait STOCKAGE-VITAL : une matière NON vitale saturée n'est plus ramassée tant qu'une autre matière manque, ou dès que le
    stock dépasse 80 %. Le fer et le charbon sont toujours ramassés ;
  - **écart restant avec la vidéo, voulu** : ce n'est pas l'arrêt complet de la vidéo. Une sortie pleine qui ne gêne rien reste
    collectée quand rien ne manque. Aucune décision du DC n'est plus nécessaire sur ce point.
- **Lots** :
  - **L4** quotas de sortie : la production s'arrête par la barre ;
  - revue de la saturation (V79) ;
  - D3 garde sa cause propre (annexe liée au fond), que la vidéo ne traite pas.
- **Pour** : F + J.

### D4. Tourelles du joueur minées par un PNJ [LU W §5]
- La vidéo n'en dit rien. C'est hors sujet ; aucun lot d'ici.

---

## H. Spécification de T1 / L1 : rangs CALCULÉS et recalculés (tiers dynamiques)

Demande du lead : « Détaille T1 en règle pure : entrées, contraction des cycles, invariants, coût, où elle s'insère dans Ca.decide ».
Le DC veut des rangs CALCULÉS et recalculés quand le catalogue change (nouvel âge, recherche).

### H.1 Fichier, signature, cadence
- **Fichier** : `shared/ai3/rang.lua`, Lua PUR, aucun nom du jeu (test anti-échelle `tests/iag_test.lua` §8).
- **Signature** : `Rg.build(D, pick, seeds) -> R`.
- **Cadence** : UNE fois par décision de capitalisation, dans `Ca.decide`, avant la boucle des ordres (§H.5). Aucun cache d'une
  décision à l'autre, donc aucune invalidation à oublier.
  - Le catalogue de la force change à une recherche finie, à un nouvel âge, à un changement de configuration ou à une machine d'une
    catégorie nouvelle.
  - Le changement est pris à la décision suivante : une minute au plus.
- **Option** : un calcul « livre entier » par génération du livre (ligne `[FO-RANG]` pour le DC et pour IA-G), gardé en mémoire de
  module avec la clé (force, génération), jamais dans `global`.

### H.2 Entrées
- **`D`** = relevé `Ca.data` (`shared/ai3/capitalisation.lua:278`) :
  - `D.recipes[rn] = { category, energy, ingredients = { {name, amount, fluid} }, products = { {name, amount, fluid} } }` ;
  - `D.producers[objet] = { rn… }` ;
  - `D.res[ressource] = vrai` ;
  - `D.hand[catégorie]`.
- **`pick(objet) -> recette | nil, raison`** : la recette que la capitalisation UTILISERA pour cet objet, c'est-à-dire `choose_recipe`
  (l.730). Elle est déjà mémoïsée par décision (`ctx.rec_memo`), et sa politique est : ouverte, faisable, sans fluide, de même nom,
  à un seul produit, puis le nom.
  - Le rang utilise la MÊME recette que la propagation des besoins (`Ca.requirements` l.772). La porte de rang (L2) est donc
    cohérente avec le calcul du besoin.
  - Variante « min sur toutes les recettes ouvertes » : pour l'affichage seulement, pas pour la porte.
- **`seeds`** = les objets dont la décision a besoin :
  - puits (`ctx.sinks`) ;
  - besoins des buts (`input.need`) ;
  - manques des ordres ouverts (`ctx.open[].missing`) ;
  - packs (`ctx.pack_rates`) ;
  - combustible (`D.fuel`).
  - Ce sont les mêmes graines que `Ca.requirements` l.756-763. On ajoute les objets demandés par L3 quand il existe.

### H.3 Calcul
1. **Fermeture** : à partir des graines, parcours ITÉRATIF (pile explicite, sans récursion) des ingrédients des recettes choisies.
   Les objets sont visités dans l'ordre trié des noms, les ingrédients dans l'ordre de la recette puis du nom. On obtient les
   sommets V (objets) et les arcs E (ingrédient → produit).
   - Une ressource (`D.res`) est une feuille de rang 0.
   - Un objet sans recette choisie est une feuille sans rang (`why` = la raison de `pick`).
   - Un fluide est un objet comme un autre. Aujourd'hui, `choose_recipe` place les recettes à fluide en dernier (l.739), et
     `Ca.requirements` ne propage pas une recette à fluide (« limite : fluide », l.774). Le rang suit la même règle : l'objet d'une
     recette à fluide est une feuille avec cette raison, donc A/B identique.
2. **Contraction des cycles** :
   - composantes fortement connexes par Tarjan ITÉRATIF, déterministe : racines dans l'ordre trié des noms, successeurs triés ;
   - une composante de plus d'un objet, ou un objet dont la recette consomme son propre produit (boucle sur lui-même, l'amorce
     d'huile lourde de V39), est un CYCLE ;
   - `cyc[objet] = id de composante` ;
   - `seed[objet]` = quantité de l'ingrédient interne au cycle, pour un tour de recette : l'amorce à prévoir, écrite au journal.
3. **Rang sur le graphe contracté** (sans cycle) : ordre topologique de Kahn, avec départage par le plus petit nom de la file.
   - rang(composante) = 1 + max(rang des ingrédients EXTERNES à la composante), ou 0 pour une ressource ;
   - tous les objets d'une composante partagent le rang de la composante ;
   - un ingrédient sans rang (impayable) rend le produit sans rang, avec la cause propagée (« impayable : <ingrédient> »).
4. **Sorties** :
   - `R.rank[objet]` (entier ≥ 0, ou nil) ;
   - `R.tiers[k]` = liste triée des objets de rang k ;
   - `R.order` = objets par rang décroissant, puis nom. C'est l'ordre de propagation de `Ca.requirements`. Dans une composante,
     l'ordre est le nom, et l'arc qui referme le cycle n'est PAS propagé : sa quantité est `seed` ;
   - `R.cyc`, `R.seed` ;
   - `R.why[objet]` ;
   - `R.n_tiers` (nombre de rangs : il varie avec l'âge) ;
   - `R.cost` = instructions comptées en test.

### H.4 Invariants (chacun testé)
- **I1 (rang strict)** : pour toute recette choisie d'un objet i, et tout ingrédient j hors de la composante de i,
  `rank[j] < rank[i]`.
- **I2 (feuilles)** : `rank[ressource] = 0`. Un objet sans recette choisie n'a pas de rang et a une raison.
- **I3 (cycles)** : les objets d'une même composante ont le même rang. Aucun arc interne n'est propagé. `seed` est écrit pour tout
  cycle.
- **I4 (déterminisme)** : la sortie est identique quel que soit l'ordre d'insertion des tables. Le test permute les tables avant
  l'appel. Aucun `pairs` décisionnel, aucun flottant dans les rangs.
- **I5 (équivalence)** : sans cycle dans la fermeture, `R.rank` est égal au `depth` actuel de `Ca.requirements` (l.764-783), et
  `R.order` donne la même propagation. C'est l'A/B octet à octet de la décision.
- **I6 (dynamique)** : ouvrir une recette (recherche, âge) ou ajouter une catégorie de machine présente change `pick`, donc le rang,
  à la décision suivante. Le test joue une recherche entre deux décisions.
- **I7 (anti-échelle)** : aucun nom d'objet, de machine ou de recette dans le fichier.
- **I8 (borne)** : itérations ≤ |V| + |E|. Aucune récursion (pas de dépassement de pile C sur une longue chaîne des 15 âges).

### H.5 Où la règle s'insère dans `Ca.decide` (`shared/ai3/capitalisation.lua:1954-2047`)
1. **Après `prepare`** (l.1956), avant `Ca.requirements` (l.1958) : `ctx.rank = Rg.build(ctx.D, function(i) return
   choose_recipe(ctx, i) end, seeds_of(ctx))`.
2. **Dans `Ca.requirements`** (l.752-813) :
   - le parcours `visit` qui recalcule `depth` (l.764-788) est remplacé par la lecture de `ctx.rank` ;
   - la liste `items` vient de `R.order` ;
   - `rec` vient de `pick` ;
   - si un tour de la boucle ajoute une graine nouvelle (le combustible d'une machine décidée, l.2002), `Rg.extend(R, nouvelles
     graines)` complète la fermeture sans tout refaire.
   - **Effet** : aujourd'hui la fermeture et les deux tris sont refaits 1 + nombre d'ordres fois (jusqu'à 25). Demain : une fois,
     plus des extensions.
3. **Dans `fabric_options`** (l.1687) : `depth = req.depth[item]` devient `ctx.rank.rank[item]`.
4. **Dans `Ca.before`** (l.1784) :
   - rien ne change en L1 ;
   - en L2, la clé devient (rang, `Tq`, clé) pour les options de fabrication et d'extraction ;
   - la porte ciblée lit `R.order` pour propager les objets « dépendants d'un manque » en une passe (L2).
5. **Avec la décision reprenable en tranches** (`fo-logs/2026-11-07_CAPI-DECIDE/CRITERES.md`) :
   - `Rg.build` tourne dans l'unité 1 (`decide_begin`) sur l'INSTANTANÉ ;
   - `R` vit dans l'état de travail J, en mémoire ;
   - après un chargement, J est recalculé depuis l'instantané, donc `R` est identique (fonction pure de l'instantané).
6. **Journal** : `[FO-RANG] <équipe> rangs=<n> cycles=<liste> amorces=<objet:quantité>`, une ligne quand `n_tiers` ou les cycles
   changent ; `r*` (rang du manque le plus bas) dans `[FO-CAPI]` (L2).

### H.6 Coût par tick (en instructions, borné ; [DÉDUIT], à mesurer par `debug.sethook` comme `tests/champ_tranches_test.lua`)
- **Fermeture, Tarjan et Kahn** : O(|V| + |E|), environ 30 à 60 instructions par arc.
- **Taille** :
  - pour une décision ordinaire (quelques centaines d'objets demandés, environ 1 000 arcs) : de l'ordre de 3 à 6 × 10⁴
    instructions, une fois par décision ;
  - pour le livre entier (environ 1 200 recettes, 4 000 arcs) : de l'ordre de 2 × 10⁵.
- **Pour situer** : 8 à 44 ns par instruction hors jeu, donc 10⁵ instructions = 0,8 à 4,4 ms. La décision coûte aujourd'hui jusqu'à
  164 ms d'un seul tenant (CRITERES CAPI-DECIDE §1).
- **Bilan attendu** : NÉGATIF (un gain), puisque la fermeture et ses tris disparaissent des 24 tours suivants. À prouver par la
  mesure H-VID-3 (L0) avant de le dire.
- **Borne dure** : si |V| + |E| dépasse `Rg.MAX` (par exemple 20 000), le calcul se découpe en unités de la décision en tranches,
  sans jamais dépasser le budget d'une tranche.

### H.7 Les 15 âges et les deux sortes d'équipes
- **Le rang est par FORCE** : chaque faction a son livre, donc son âge. Le nombre de rangs n'est pas fixé (`R.n_tiers`, écrit au
  journal) ; un âge nouveau ouvre des recettes et allonge les chaînes.
- **Factions ET votre équipe** : la capitalisation tourne pour les deux (`script/ai3/capitalisation.lua:8`). Votre équipe partage la
  force du joueur (W §1) : son livre est celui du joueur. Une recherche faite par le joueur change donc les rangs de son équipe.
- **Un objet qui change de recette d'un âge à l'autre change de rang** : par exemple, fait à la main au départ, puis en machine avec
  d'autres ingrédients. C'est le sens de « dynamique ».

### H.8 Tests et mutants
- **`tests/rang_test.lua`** :
  - (a) vanilla, sur le relevé `harness.lua … --dump-recipes`. La fixture `recipes_ia1e.lua` est périmée : 839 recettes contre 1 189
    (`REPRISE.md` l.16). Valeurs attendues : plaques 1, engrenage 2, câble 2, circuit 3, bras 4, pack logistique 5 (la table de
    l'auteur dit 4, §B G22) ;
  - (b) cycle à deux objets ;
  - (c) boucle sur lui-même (amorce) ;
  - (d) recherche entre deux décisions (I6) ;
  - (e) relevé du mod, 15 âges : `n_tiers` écrit, aucun objet fabricable sans rang hors cycles ;
  - (f) A/B de `Ca.decide` sur le corpus de `tests/ai3_capitalisation_test.lua` : identique sans cycle (I5) ;
  - (g) instructions comptées.
- **Mutants** (chacun doit faire échouer un test) :
  1. rang = max au lieu de 1 + max ;
  2. arc de cycle propagé ;
  3. Tarjan par `pairs` (le test permute les tables) ;
  4. recette de la porte différente de celle de la propagation (`pick` contourné) ;
  5. extension oubliée pour une graine nouvelle ;
  6. récursion à la place de la pile.

---

## I. Les IMPLÉMENTER, classés par rentabilité

| Rang | Lot | Lignes de cette liste | Ce que ça règle chez nous | Module cible (`IA_WORKFLOW.md` §7) | Taille | Dépend de | Pour |
|---|---|---|---|---|---|---|---|
| 1 | L0 mesures H-VID-1, H-VID-2, H-VID-3 | V73, V77, G12, G13 | Savoir avant de changer : ordres émis contre chantiers commencés, pic d'amont, coût de `Ca.requirements`. | journaux `[FO-CAPI]`, moteur simulé | S | — | F + J |
| 2 | L1 rang calculé (§H) | V12, V17, V18, V39, G20, G21, G34, W13, W14 | Tiers dynamiques par force et par âge ; la fermeture est refaite jusqu'à 25 fois par décision. | nouveau `shared/ai3/rang.lua` ; `Ca.decide` `shared/ai3/capitalisation.lua:1954`, `Ca.requirements` l.752 | S à M | — | F + J |
| 3 | L3 manque mesuré, transit compris | V14, V26, V28, V29, V59, V81, V82, V83, G25 | **D0** (la vue ne voit pas les coffres du plan directeur) et **D1** ; le vrai signal de la vidéo. | nouveau `shared/ai3/manque_local.lua` ; `Team.view` `script/team/team.lua:462` ; puits de `Ca.requirements` l.756 ; survie `shared/team/survie.lua:128` | M | — | F + J |
| 4 | L2 porte de rang ciblée | V15, V16, V19, V20, V30, G24, G26, G28, G29, G63 | Des modules en attente de fer qui tiennent les places de la foreuse de fer (`emplacements.lua` règle 8 ; `REPRISE.md` l.22). | `Ca.options` l.1791, `Ca.before` l.1784, `fabric_options` l.1571 | M | L1, L0 | F + J |
| 5 | L5 confirmation observée | V54, V72, G32, G35, G58, G68 | **D2** : un module qui ne produit pas compte comme capacité. | entrée `machines` de `Ca.decide` l.1941 ; `advance` `build.lua:4098` ; `emplacements.lua` | M | — (mieux avec L3) | F + J |
| 6 | L6 portes et petites marches | V21, V73, V77, V78, G12, G13, G27, G47, G51 | **D1** : « 0 PNJ libre, 16 tâches libres » ; pics d'amont. | `Ca.decide` l.1973, `Dm.slots` `shared/ai3/demande.lua`, `Ex.guard` `shared/ai3/extension.lua` | S | L0 (L3 pour l'anti-répétition) | F + J |
| 7 | L4 quotas du gabarit | V24, V25, V27, C08 | **D2** : fours à sortie pleine, ingrédients avalés ; **D3** en partie (arrêt par la barre). | `shared/team/patrons.lua` ; `keep_stock` `build.lua:3904-3911` ; quais `build.lua:3925-3983` | M | — (D3 : tranché par STOCKAGE-VITAL, §G) | F + J |
| 8 | L11 trace sur la carte | G67, C14 | Le DC voit les décisions là où elles sont posées. | runtime `script/ai3/capitalisation.lua` ; `add_chart_tag` comme `script/world/guarantee.lua` | S | — | F + J |
| 9 | L7 amorce et retrait | V51, V52, V53, V55, V56, C11 | La dépendance à la main ; un kit de départ dimensionné par la mesure. | `Ml.decide` `shared/ai3/mall.lua:98`, `Ml.hand_allowed` l.168 ; file de `Build.request` | S | L5 | F + J |
| 10 | L12 hystérésis et verrou | G15, G16, G17 | Crises qui oscillent ou « guérissent » trop tôt. | `power_options` ; `Pi.signals` `shared/ai3/pile.lua:424` | S | (L5) | F + J |
| 11 | L13 plafonds et gardes fermées par défaut | W02, C13 | Emballement d'un objet ; garde à entrée manquante. | `Ca.decide` (`Ca.OPEN_MAX` l.148) | S | — | F + J |
| 12 | Revue de la saturation | V79 | Un stock qui masque un manque de capacité. | `B.saturated` `shared/ai3/buts.lua:169` (150 était périmé) | S | — | F + J |
| 13 | L10 marches de stabilité | V57, V58, V65, V66, G30, G64, G66, G69 | Croissance par paliers sûrs, à comparer à C2. | `Dm.step` `shared/ai3/demande.lua` | S | L1, L3 | F (J à vérifier : `cerveau.lua:792`) |
| 14 | L9 sonder, minerai d'abord | V45, V46, V47, G37, G42, G43, G57 | Fabrique posée sur un gisement ; décision sur des faits périmés. | lots « gisement » `shared/team/plan.lua` l.9-11, l.42 | S | — | F + J |
| 15 | L8 lot prêt avant l'ordre | V23, V72, G38 | Module bloqué en défrichage qui tient une place (en-tête d'`emplacements.lua`). | `Build.think` `build.lua:4846` ; `emplacements.lua` règle 2 | M | — | F + J |

**Avancement (7/11, 18 h 05 ; mis à jour par l'intégrateur)**. Rien n'est encore EN JEU : une règle pure testée hors jeu ne
change pas ce que vous verrez tant qu'elle n'est pas branchée. Plans de branchement et ordre de fusion :
`fo-logs/2026-11-07_VIDEO-AUTOMATISATION/INTEGRATION_VIDEO.md`.

| Lot | État | Preuve |
|---|---|---|
| L0 | ✅ mesuré | `L0_MESURES.md` |
| L1 | règle pure ✅, branchement planifié | `shared/ai3/rang.lua` (rang-tiers 6888b86f) ; décision identique au bit près, 6 à 14 % moins d'instructions ; `PLAN_L1_L2.md` |
| L2 | règle pure ✅, branchement planifié | `shared/ai3/porte_rang.lua` (8675011e) : 26 OK, 9 mutants sur 9 ; interblocage du fer couvert |
| L3, L5, L13 | règles pures ✅, branchement planifié | `manque_local`, `confirmation`, `plafonds` (video-l5 5e720b38) ; `PLAN_L3_L5_L13.md` |
| L4, L7 | règles pures ✅ | `quotas`, `amorce` (video-l4 a7395d7a) |
| L6, L10, L12 | règles pures ✅, branchement planifié | `portes_extension` 14 OK, 11 mutants ; `palier` 12 OK, 10 ; `hysteresis` 11 OK, 9 (video-l6 b209dd30) ; `PLAN_L6_L10_L12.md` |
| L11 | règle pure et module ✅, branchement planifié | `shared/ai3/trace.lua`, `script/ai3/trace_carte.lua` (video-l4 79edf454) : 30 OK, 8 mutants ; réglage `fo-debug-trace-carte` à déclarer |
| L8 | ✅ déjà corrigé : règle 2 d'`emplacements.lua` (CAPI-DEBIT, 30/10), `capi_debit_test` 74 OK (16 h 22) . **Clos** : sur votre partie 0.6.58 (177 min), 21 défrichages, tous de moins de 2 min, et 0 place tenue plus de 5 min. Le volet préventif n'est pas utile | `PLAN_L8.md` §5 (rang-tiers) |
| L9 | règle pure ✅, branchement planifié | `shared/team/lot_minerai.lua` (video-l9 646aeac2) : 14 OK, 12 mutants. Trois défauts trouvés : une fabrique se repliait sur un gisement (`build.lua:2727-2728`) ; un seuil unique sans quantité (`plan.lua:42`) ; un relevé jamais refait (l.373). À mesurer avant de brancher, par [FO-LOTS-MINERAI] : une faction à rayon maximal perd-elle une chaîne ? `PLAN_L9.md` |
| Saturation (rang 12) | règle pure ✅ et correctif de `B.saturated` (inerte tant que personne n'écrit `s.drain`), branchement planifié (étape 4 bis, après L3) | `shared/ai3/saturation.lua` (video-sat b41858a9) : 67 OK, 13 mutants. Scène V79 : levée à 10 min avec 20 min de stock restant, au lieu de 23 min avec 7 min restantes. Projection à 20 min (supposée, à mesurer). La levée en jeu demande un banc long (36 000 ticks) : à votre accord. `PLAN_SATURATION.md` |
| Branchement | étapes 0 et 1 ✅ (3a437d4a : capi-decide, corr-collecte et les règles réunies, 16 suites vertes, aucun effet en jeu) ; étape 2 ✅ (e96c41b3 : L13 garde fermée, une décision sur une entrée absente est refusée et journalisée) ; étape 3 ✅ (71e98fd2 : L5 et son plafond. Hors jeu, 502 rendus identiques sans suspension. **En moteur réel**, `capi-partie` 10 000 ticks, M1 à M4 OK : 148 premières productions confirmées par les 5 équipes (128 à la 1re minute, 20 à la 2e), de vraies suspensions de « coal » et de « copper-plate », 0 erreur) ; étape 5a ✅ (83feecb6, a09bbb1f : le courant dans la décision, F391) ; **à 18 h, `video-integ` = ebd22e3c** : étape 4 ✅ (c3657d3b, L3 manque mesuré ; la survie STRICTE, 0cc3fc9d, arrive avec l'étape 4 bis), étape 5 partie 1 ✅ (e9d8ee83, L12 `hq_threat`), étape 9 ✅ (86343a23, L4 quotas), étape 10 ✅ (ebd22e3c, L7 amorce) ; suites hors jeu vertes, sauf `charbon_centrale` 80 OK 1 ECHEC (contrôle statique décalé, déjà sur la base, confié à flux2). Micro-banc `collecte-fer` de l'étape 4 (5 400 ticks, 18 h) : le manque mesuré se lève à 1 min (472 plaques de fer, priorité 94), mais la collecte n'est pas encore prise à la fin du banc (déduit : banc trop court, à relire). Branches prêtes : `integ-sat` c3b53b15 (4 bis), `integ-l6` 9d59a37c (6), `integ-l1l2` 4366fdbf (8), `integ-l11` 677d7daf (11) ; restent L10 (7), L12 partie 2 (centrale), L9 (12) | cerveau-central, branche `video-integ` ; rang-tiers, video-l4, video-l5, video-l6 |

**Changement d'ordre depuis le rapport** : L3 monte au 3e rang. C'est le remède de D0 et de D1, que le lead a demandé de relier ;
L2 en profite (le manque mesuré nourrit la porte de rang).

**Décompte**, fait par script sur les colonnes des verdicts et de « Pour » :
- 242 lignes : 106 de la vidéo, 73 du code, 8 de la description, 22 de la suite, 28 commentaires, 5 du scénario ;
- 78 IMPLÉMENTER, 106 À PRENDRE EN COMPTE et 62 INUTILE POUR NOUS ;
- 4 lignes portent deux verdicts ;
- aucune ligne n'est sans verdict ;
- toute ligne IMPLÉMENTER a sa colonne « Pour » remplie, et aucune autre ne l'a.
