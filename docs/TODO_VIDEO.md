# TODO de la vidéo « Factorio Automated » : une ligne par élément

Demande du DC, mot pour mot : « il faudra une todo liste exhaustive pour chaque petit élément de la vidéo. Y a beaucoup de chose
qu'il dit qui sont en fait une réflexion précise derrière a implémenter ou au moins a prendre en compte (même si évidemment j'ai
dit 50% donc forcément y a plein d'infos qui pour nous seraient inutile) ».

**Comment lire la liste :**
- Chaque ligne vient de la transcription (sous-titres automatiques anglais, horodatage mm:ss) ou d'une source liée par l'auteur :
  - **G** : son code, numéros de ligne ;
  - **D** : la description ;
  - **V2** : la vidéo de suite ;
  - **C** : ses réponses en commentaires ;
  - **S** : son scénario.
- **Ce qui est seulement MONTRÉ à l'image n'est pas ici** : je n'ai pas les images. Le DC peut ajouter ce dont il se souvient.
- **Verdicts** :
  - **IMPLÉMENTER** ;
  - **À PRENDRE EN COMPTE** : contrainte ou principe de conception ;
  - **INUTILE POUR NOUS**, avec la raison.
- **Cible** :
  - le lot du rapport (`RAPPORT_VIDEO.md` §6 : L0 à L13) ;
  - le module d'après `IA_WORKFLOW.md` (worktree `integ-0652b`, 0e340b99), avec fichier:ligne ;
  - la taille S, M ou L, et les dépendances.
- La « réflexion » est ma lecture de son raisonnement. Ce qui n'est pas dit par l'auteur est marqué [DÉDUIT].

---

## A. Vidéo principale, dans l'ordre

| # | mm:ss | Dit (citation courte) | Réflexion derrière | Verdict | Cible, taille, dépendances |
|---|---|---|---|---|---|
| V01 | 0:10 | « I love the smell of Logistics in the morning » | Accroche. | INUTILE POUR NOUS (aucune logique) | — |
| V02 | 0:14 | « based entirely on Logistics Bots with no trains or belts » | Un seul moyen de transport, universel : aucun routage à concevoir. | INUTILE POUR NOUS (PNJ au départ, puis tapis) ; À PRENDRE EN COMPTE quand les factions auront un réseau logistique | — |
| V03 | 0:19 | « first rocket in under 6 hours … 1,000 [science] per minute in under a day » | La réussite se mesure par des jalons datés. | À PRENDRE EN COMPTE (nos jalons : âge atteint à t) ; INUTILE le chiffre (pas de 1 000 SPM visé) | — |
| V04 | 0:22 | « about 30 UPS … 24 UPS if biters are turned on » | La performance se mesure avec ET sans ennemis. | À PRENDRE EN COMPTE (mesures `--seul` avec et sans biters) | — |
| V05 | 0:31 | « I'm not building anything, this Factory builds itself » | Aucune intervention humaine. | À PRENDRE EN COMPTE (déjà vrai pour les factions) | — |
| V06 | 0:44 | « pretty much any self-expanding Factory requires the recursive blueprints mod » | Il faut poser des plans par script. | INUTILE POUR NOUS (nous avons l'API) | — |
| V07 | 0:54 | Le déployeur prend un plan, un planificateur de déconstruction ou un livre ; les signaux disent où et lequel | On sépare une bibliothèque numérotée de gabarits, une position et une commande. | À PRENDRE EN COMPTE (existe : `Build.request` `build.lua:569`, `spec.gen` 600-607, `Build.SITES` 109) | — |
| V08 | 1:09 | « a book of blueprints … and an automated way to tell the blueprint deployer which one to deploy » | Deux pièces seulement : une bibliothèque et UN décideur. | À PRENDRE EN COMPTE (« un seul décideur par levier », `script/ai3/capitalisation.lua:25-32`) | — |
| V09 | 1:20 | Moon Logic : « without having to build Acres of combinator setups » | Écrire la logique en code plutôt qu'en combinateurs. | INUTILE POUR NOUS (nous sommes un mod) | — |
| V10 | 1:37 | « not just science but also the buildings … and … ammunition » | Le même mécanisme sert la science, les biens d'équipement et les munitions. | À PRENDRE EN COMPTE (tout consommateur dans la même demande : vérifier que munitions et équipement entrent dans les puits de `Ca.requirements` l.756-763) | — |
| V11 | 1:52 | « avoid hardcoding things as much as possible » | Généralité. | À PRENDRE EN COMPTE (anti-échelle, `tests/iag_test.lua` §8) | — |
| V12 | 1:57 | « a system of tiers … the last tier contains space science » | Des rangs de fabrication. | IMPLÉMENTER (rang calculé, non écrit) | L1, nouveau `shared/ai3/rang.lua` ; M ; aucune |
| V13 | 2:08 | « ore, oil products and power aren't on this list » | Les rangs ne couvrent que le fabriqué ; matières premières, fluides et énergie ont leurs propres déclencheurs. | À PRENDRE EN COMPTE (rang 0 = ressources ; énergie : `power_options` ; fluides : `Pet.think` `script/ai3/petrole.lua:915`) | — |
| V14 | 2:12 | « any item with a negative signal is in demand » | La demande est un manque NET, mesuré. | IMPLÉMENTER | L3, nouveau `shared/ai3/manque_local.lua`, lecture dans `Team.view` (`team.lua:462`), puits de `Ca.requirements` (l.756) ; M ; aucune |
| V15 | 2:20 | « if there is no demand for anything in tier one we check … tier 2 and so on » | On parcourt les rangs du bas vers le haut. | IMPLÉMENTER (porte ciblée, pas globale) | L2, `Ca.options` l.1791, `Ca.before` l.1784 ; M ; L1 |
| V16 | 2:29 | « build a tile … the item with the most demand » | Dans le rang retenu, on prend le plus gros manque. | IMPLÉMENTER | L2 ; M ; L1, L3 |
| V17 | 2:36 | « the lowest number tier that doesn't contain any of its ingredients » | Définition : rang = 1 + rang max des ingrédients. | IMPLÉMENTER | L1 ; M ; aucune |
| V18 | 2:40 | Exemple des circuits verts (plaques rang 1, câble rang 2) | La règle s'illustre sur un objet. | IMPLÉMENTER (cas de test) | L1, `tests/rang_test.lua` ; S ; L1 |
| V19 | 2:49 | « if there isn't enough copper wire it doesn't matter how many green chip assemblers we have » | La demande d'un étage haut est souvent le symptôme d'un manque plus bas. | IMPLÉMENTER | L2 ; M ; L1 |
| V20 | 3:00 | « supply chain issues are caused by shortages of low-level ingredients … higher tier products aren't in demand anymore » | Soigner la racine, pas le symptôme. | IMPLÉMENTER (même porte) | L2 ; M ; L1 |
| V21 | 3:11 | « the smallest unit of construction … a tile » | Unité de construction petite et fixe. | IMPLÉMENTER (une cellule de plus par objet et par décision sur un manque mesuré) | L6, `Ca.decide` l.1973 ; S ; L3 |
| V22 | 3:17 | « a 3X3 grid of these is called a mega tile » | Regroupement 3 × 3 autour d'une case commune. | À PRENDRE EN COMPTE (quartiers du treillis, `shared/team/plan.lua` l.5-13) | — |
| V23 | 3:20 | « building a blank Mega tile then filling each of the eight empty tiles » | L'enveloppe commune d'abord (logistique, défense, courant), les modules ensuite. | IMPLÉMENTER (lot prêt avant l'ordre) | L8, plan directeur (`Build.think` `build.lua:4846`), `emplacements.lua` règle 2 ; M ; aucune |
| V24 | 3:28 | « keep manufacturing until it has 1 minute's worth of surplus » | Quota de sortie DANS le module. | IMPLÉMENTER | L4, `shared/team/patrons.lua`, `keep_stock` `build.lua:3904-3911` ; M ; aucune |
| V25 | 3:36 | « request 1 minute's worth of ingredients » | Quota d'entrée dans le module. | IMPLÉMENTER | L4 ; M ; aucune |
| V26 | 3:38 | « report … any ingredients that are missing » | Chaque module publie son manque. | IMPLÉMENTER | L3 ; M ; aucune |
| V27 | 3:44 | « the ingredient inserters … only work if there is less than 1 minute worth of product » | La garde est sur l'ENTRÉE : un module plein n'avale pas d'ingrédients, qui restent pour les autres. | IMPLÉMENTER (pas de tournée d'alimentation vers une sortie pleine) | L4, tâches de quai `build.lua:3925-3983`, `Board.add` `board.lua:398` ; M ; aucune |
| V28 | 3:50 | « subtracts from the number of ingredients that are needed, and if the number is negative … passed » | Formule : manque = besoin − contenu ; seuls les manques sont publiés. | IMPLÉMENTER | L3 ; M ; aucune |
| V29 | 4:03 | « the green chip tile will report that copper wire is in demand » | La demande naît de ce qui est POSÉ (cascade physique). | IMPLÉMENTER | L3 ; M ; aucune |
| V30 | 4:13 | « continue building them until copper wire demand is satisfied or a lower tier ingredient … is in demand » | Poser, remesurer, reposer ; un rang plus bas prend la main. | IMPLÉMENTER | L2 + L3 + L6 ; M ; L1 |
| V31 | 4:23 | « power and oil … won't fit onto a single tile and require special case Mega tiles » | Les grosses infrastructures sont des leviers à part. | À PRENDRE EN COMPTE (existe : courant, pétrole, champ) | — |
| V32 | 4:29 | « a perfect balance of solar panels and accumulators » | Une unité d'énergie autonome équilibrée. | INUTILE POUR NOUS (choix de contenu) | — |
| V33 | 4:37 | « Robo ports can use up to 4 megawatts when charging Bots … hard to break even » | Le transport consomme de l'énergie : il entre dans le bilan. | À PRENDRE EN COMPTE (bras, tapis, poteaux ; roboports plus tard) | — |
| V34 | 4:46 | « giant oceans of solar dotted with islands of manufacturing » | Une énergie peu dense étale l'usine et allonge les trajets. | À PRENDRE EN COMPTE (pour des PNJ, la distance tue : F239, F251) | — |
| V35 | 4:53 | « nuclear Mega tile with a 2x2 reactor neighbor bonus » | Choix nucléaire. | INUTILE POUR NOUS (contenu ; nucléaire contre vapeur : décision du DC) | — |
| V36 | 5:00 | « check if the steam in the storage tanks has gone below a certain threshold … feed fuel cells » | On donne le combustible selon le TAMPON d'énergie, pas en continu. | À PRENDRE EN COMPTE (règles des brûleurs ; gain faible) | — |
| V37 | 5:12 | « don't waste fuel cells keeping the reactors at 1,000° … only feed them when they go below 500 » | Hystérésis du combustible. | À PRENDRE EN COMPTE (idem) | — |
| V38 | 5:26 | « doesn't have any method for building or piping pump jacks, so … coal liquefaction » | Choisir la recette que l'exécutant SAIT poser plutôt qu'un placement difficile. | À PRENDRE EN COMPTE (existe : `can_exec`, `Fl.executors`) | — |
| V39 | 5:32 | « start with a few barrels of heavy oil … to Kickstart » | Une recette qui consomme son propre produit exige une amorce. | IMPLÉMENTER (détecter les cycles à amorcer et les écrire) | L1 (`cyc`, `seed`) ; S ; L1 |
| V40 | 5:41 | « coal liquefaction has some pretty wild product ratios » | Les co-produits sont déséquilibrés. | INUTILE POUR NOUS (recette vanilla précise) | — |
| V41 | 5:50 | « more barrels of heavy oil than light oil … cracked into light oil » | Équilibrer des co-produits en comparant leurs stocks : une règle locale simple. | À PRENDRE EN COMPTE (`shared/ai3/fluides.lua` refuse les sous-produits fluides ; à revoir si on les accepte) | — |
| V42 | 6:02 | « petroleum pipes get full … turn the excess petroleum into solid fuel » | Soupape : un co-produit plein ne doit pas arrêter toute la chaîne. | À PRENDRE EN COMPTE (W boucle B3 « saturation sans sortie », D3 « pierre qui dort ») | — |
| V43 | 6:13 | « this basically never happens » | Une garde rare, mais nécessaire. | À PRENDRE EN COMPTE | — |
| V44 | 6:16 | « places a premium on mining its own resources » | L'extraction propre passe avant. | À PRENDRE EN COMPTE (capitalisation : couvrir et ouvrir) | — |
| V45 | 6:20 | « ore in an upcoming Mega tile … built as a blank Mega tile even if we're in a power crisis » | Saisir le gisement sur le chemin de croissance, même en crise. | IMPLÉMENTER | L9, lots « gisement » `shared/team/plan.lua` l.9-11, l.42 ; S ; aucune |
| V46 | 6:29 | « because we don't know when we'll come across ore again » | L'occasion rare passe avant le besoin courant. | IMPLÉMENTER (même règle) | L9 ; S |
| V47 | 6:31 | « whenever we build a tile we also scan for ore » | Sonder chaque place avant d'y poser. | IMPLÉMENTER | L9 ; S |
| V48 | 6:38 | « infinite chests that will supply a dribble of ore » | L'amorce est un FILET : elle ne doit pas masquer le besoin d'extraction. | À PRENDRE EN COMPTE (`Ca.HAND_CAPITAL` = 0, `capitalisation.lua:105` : la main n'est pas du capital) | — |
| V49 | 6:45 | « after about a dozen Mega tiles … we don't need these anymore » | L'amorce s'éteint d'elle-même. | À PRENDRE EN COMPTE | — |
| V50 | 6:56 | « the mall of Shame … rows of infinite chests that supply all the buildings » | Amorcer avec une source provisoire. | INUTILE POUR NOUS (triche) ; l'idée d'amorce est reprise en V51 à V56 | — |
| V51 | 7:06 | « only going to use these until we have a tile that can craft the buildings » | L'amorce est retirée dès que la production existe. | IMPLÉMENTER (existe en partie : `Ml.hand_allowed` `mall.lua:168`) | L7 ; S ; L5 |
| V52 | 7:10 | « a constant combinator that puts a demand for 10,000 of the building » | On FORCE la demande de départ des biens d'équipement. | IMPLÉMENTER (graine = matériel des prochains projets du plan directeur) | L7, `Ml.decide` `mall.lua:98`, file de `Build.request` ; S ; aucune |
| V53 | 7:18 | « try and build tiles that manufacture these buildings as soon as it can » | Le capital qui fabrique le capital passe en premier. | IMPLÉMENTER (effet de la graine) | L7 ; S |
| V54 | 7:21 | « reports … when it first successfully manufactures its product » | Le critère de fin est la PREMIÈRE PRODUCTION, pas la pose. | IMPLÉMENTER | L5, entrée `machines` de `Ca.decide` (l.1941), `advance` `build.lua:4098` ; M ; aucune |
| V55 | 7:26 | Le déployeur retire le coffre infini, le bras, le coffre fournisseur et le combinateur | Le retrait est automatique et complet. | IMPLÉMENTER (retrait de la main à la 1re production) | L7 ; S ; L5 |
| V56 | 7:35 | « an arithmetic combinator that holds the number of products that were pulled » | On garde la mesure de ce que l'amorce a fourni. | IMPLÉMENTER (compteur `[FO-AMORCE]` par objet) | L7 ; S |
| V57 | 7:44 | « tiles for everything in the mall and … enough tiles to satisfy all the downstream demand, what do we do? » | L'état « rien ne manque » est explicite. | IMPLÉMENTER (prédicat « aucun manque à aucun rang ») | L10 ; S ; L1, L3 |
| V58 | 7:49 | « sets a 5-minute timer and if no products come into demand … we build a research tile » | Minuteur de stabilité avant de grandir. | IMPLÉMENTER (variante de C2, à comparer) | L10, `Dm.step` `shared/ai3/demande.lua` ; S ; L1, L3 |
| V59 | 7:58 | « research tiles report their demand … immediately creates demand for all seven sciences » | Le sommet est un consommateur comme les autres. | IMPLÉMENTER (les labos publient leur manque comme un module) | L3 + L10 ; S |
| V60 | 8:03 | « strain demand on other products or create demand for products that we don't have tiles for yet » | La cascade dimensionne tout l'amont. | À PRENDRE EN COMPTE | — |
| V61 | 8:09 | « launched a rocket and have some production capacity for each of the seven sciences » | Couvrir chaque pack. | À PRENDRE EN COMPTE ; INUTILE la fusée | — |
| V62 | 8:16 | « about 6 game hours and 100 mega tiles » | Ordres de grandeur. | INUTILE POUR NOUS (leur échelle) | — |
| V63 | 8:22 | « build out a ton of power to handle the load of all these tiles running continuously » | La charge réelle n'apparaît que quand tout tourne : l'énergie se règle sur la charge mesurée. | À PRENDRE EN COMPTE (`power = { have_kw, used_kw }`, `Ca.decide` l.1947) | — |
| V64 | 8:27 | « backfill some of the slower tiles … that built up surpluses » | Une recette lente vit un temps sur son stock, puis se rattrape. | À PRENDRE EN COMPTE (voir V79) | — |
| V65 | 8:33 | « if things stay that way for 5 minutes straight we build a new research tile » | La stabilité doit être CONTINUE. | IMPLÉMENTER | L10 ; S |
| V66 | 8:40 | « and then whatever tiles are needed to keep up the pace » | La marche du sommet déclenche la cascade. | IMPLÉMENTER (même mécanisme) | L10 ; S |
| V67 | 8:44 | « continues indefinitely until … 500 mega tiles and 25 research tiles » | Croissance sans fin, plafond seulement au sommet. Écart : 484 dans G. | À PRENDRE EN COMPTE (C2 « à l'infini ») ; INUTILE les chiffres | — |
| V68 | 8:56 | « most of the footage … with biters turned off » | Mettre au point sans ennemis d'abord. | À PRENDRE EN COMPTE (déjà : Paisible) | — |
| V69 | 9:02 | « takes several days of real world time » avec biters | La défense ralentit énormément la croissance. | À PRENDRE EN COMPTE | — |
| V70 | 9:09 | « an artillery cannon that clears the area … for about 36 mega tiles » | Zone sûre initiale à la taille de la croissance prévue. | INUTILE POUR NOUS (artillerie tardive ; adversaires actifs) | — |
| V71 | 9:16 | « sets a flag each time the factory reaches a corner … artillery station tile at the next opportunity » | Défense posée par la géométrie ; un drapeau différé est consommé à la prochaine place. | INUTILE POUR NOUS (notre défense suit la menace) ; À PRENDRE EN COMPTE l'idée du drapeau différé | — |
| V72 | 9:25 | « clear biter nests before we try to build … blueprints will be incomplete and we have no way to detect or fix » | Ne jamais engager une place non sûre ; un chantier incomplet doit être détectable. | IMPLÉMENTER (lot sûr avant l'ordre ; chantier incomplet = cause écrite) | L8 + L5 ; M |
| V73 | 9:35 | « waits until almost all construction Bots are idle before surveying or building » | Ne pas lancer plus de chantiers que les bras ne servent. | IMPLÉMENTER (porte des bras à seuil croissant) | L6, `Dm.slots` (`shared/ai3/demande.lua`) ; S ; L0 |
| V74 | 9:44 | « construction Bots will be kept busy fixing and replacing damaged buildings » | La réparation prend la priorité par la porte seule. | À PRENDRE EN COMPTE (pile : R1 avant R3, `shared/ai3/pile.lua:108`) | — |
| V75 | 9:54 | « inject one or two research tasks for artillery range … gaps in artillery coverage » | Une recherche dictée par un besoin mesuré (couverture). | À PRENDRE EN COMPTE (IA-G : valeur militaire, `script/ai3/general.lua:585`) | — |
| V76 | 10:18 | « the rail based tiles had to be huge » | Historique : une grande unité. | INUTILE POUR NOUS (historique) | — |
| V77 | 10:25 | « built the same tile twice by accident … massive downstream demand spikes » | Le coût d'une erreur grandit avec la taille de l'unité. | IMPLÉMENTER (petites marches ; mesurer d'abord H-VID-2) | L6 ; S ; L0 |
| V78 | 10:33 | « if we build one too many … we don't create too much downstream demand » | Même raison. | IMPLÉMENTER | L6 ; S |
| V79 | 10:40 | « a surplus … doesn't get so large that it prevents us from realizing that we don't have enough production capacity » | Un gros stock MASQUE un manque de capacité. | IMPLÉMENTER (une matière n'est saturée que si son débit net ≥ 0 : vérifier `B.saturated` `shared/ai3/buts.lua:150` ; la capitalisation borne déjà le stock à 10 min, `Ca.H_STOCK` l.87) | revue de `buts.lua` ; S ; aucune |
| V80 | 10:46 | « the main reason I opted for this unconventional design » | La granularité est le choix fondateur. | À PRENDRE EN COMPTE | — |
| V81 | 10:57 | « a rail tile would report a one … if it was missing a particular ingredient » | Un signal binaire ne suffit pas. | IMPLÉMENTER (manques en quantités) | L3 ; M |
| V82 | 11:02 | « I know exactly how much of each ingredient is in demand » | Le manque est quantitatif. | IMPLÉMENTER | L3 ; M |
| V83 | 11:09 | « product that is in transit is accounted for as well » | Pas de double livraison. | IMPLÉMENTER (transit = tâches réservées et inventaires des PNJ) | L3, registre de `board.lua:839-920` ; M |
| V84 | 11:17 | « Bots are the most brute force method of transportation » | Il reconnaît la force brute. | INUTILE POUR NOUS | — |
| V85 | 11:23 | « I just add more Bots until stuff is flowing » | Dimensionner le transport sur sa saturation mesurée. | À PRENDRE EN COMPTE (existe : `E.decide` `shared/ai3/effectif.lua:137`, travail qui attend) | — |
| V86 | 11:30 | « robo ports become the number one power draw, we just build more power » | Le coût du transport remonte dans la demande d'énergie. | À PRENDRE EN COMPTE | — |
| V87 | 11:36 | « travel times get too long … overbuild manufacturing tiles until … close to where it's needed » | La localité émerge de la demande. | INUTILE POUR NOUS (PNJ mortels en route ; notre plan place par distance, `plan.lua` l.9-13) | — |
| V88 | 11:45 | « this Factory is able to address its own issues » | Chaque panne produit un signal que la même boucle traite. | À PRENDRE EN COMPTE (principe : chaque défaut doit avoir un signal et un levier) | — |
| V89 | 11:56 | « keep UPS above 60 for a couple hundred mega tiles » | La performance tient longtemps puis cède. | À PRENDRE EN COMPTE | — |
| V90 | 12:03 | « slowed to half speed » | Chiffre. | INUTILE POUR NOUS | — |
| V91 | 12:10 | « minifactory that is self-contained … several dozen copies with unconnected logistic networks » | Cloisonner borne le coût. | À PRENDRE EN COMPTE (quartiers autonomes, moins de trajets) | — |
| V92 | 12:22 | « design the factory as it goes … I pay the price in … inefficient layout, long travel times » | Le prix de la conception réactive. | À PRENDRE EN COMPTE (notre capitalisation est hybride : calcul et mesure) | — |
| V93 | 12:37 | « I never got around to sorting out … offshore pump tiles » | Limite de son exécutant. | INUTILE POUR NOUS (nous posons des pompes) | — |
| V94 | 12:43 | « some sort of multiphase Blueprinting logic » | Un gabarit lié au terrain demande plusieurs phases. | À PRENDRE EN COMPTE (plan directeur : rive, énergie) | — |
| V95 | 12:45 | « infinite water pipes, which are definitely a copout » | Triche reconnue. | INUTILE POUR NOUS (triche) | — |
| V96 | 12:59 | « level three modules all over this Factory … I really should be crafting them » | Triche reconnue. | INUTILE POUR NOUS (triche) | — |
| V97 | 13:03 | « the supply chain required for that is about as large as a 1,000 [SPM] Factory alone » | Un intermédiaire haut se valorise par TOUTE sa chaîne. | À PRENDRE EN COMPTE (existe : `Ca.chain_capital` `capitalisation.lua:827`) | — |
| V98 | 13:09 | « it would take weeks » | Chiffre. | INUTILE POUR NOUS | — |
| V99 | 13:16 | « I've disconnected the combinators so we never actually build the tiles for them » | Pouvoir EXCLURE un objet de la demande. | À PRENDRE EN COMPTE (réglage d'exclusion ; nos refus écrits) | — |
| V100 | 13:21 | « would require refactoring every manufacturing tile » | Des quotas figés coûtent une refonte : les calculer depuis les débits. | À PRENDRE EN COMPTE (L4 : quotas lus des débits) | — |
| V101 | 13:35 | « at least a 3 by 3 block of Mega tiles just for combinators » ; commenter du code plutôt que des épingles | Lua contre combinateurs. | INUTILE POUR NOUS | — |
| V102 | 13:56 | « I've linked a zip of the scenario » | Distribution. | INUTILE POUR NOUS | — |
| V103 | 14:01 | GreyGoo, JOSEF, l'usine communautaire de Nilaus | Références. | INUTILE POUR NOUS (non lues) | — |
| V104 | 14:36 | « grab the scenario … see if you can improve on it » | Appel aux joueurs. | INUTILE POUR NOUS | — |
| V105 | 14:44 | « automated Factory design could become a new category of play » | Vision. | INUTILE POUR NOUS | — |
| V106 | 14:54 | Conclusion, « stay building » | Fin. | INUTILE POUR NOUS | — |

## B. Le code de l'algorithme (G), éléments qui ne sont pas dits à voix haute

| # | Ligne | Ce que fait le code | Réflexion derrière | Verdict | Cible, taille, dépendances |
|---|---|---|---|---|---|
| G01 | 1-16 | Entrées et sorties décrites en tête | Contrat écrit de la règle. | À PRENDRE EN COMPTE (nos en-têtes de règles pures) | — |
| G02 | 17 | `MAX_MEGATILES = 484` | Plafond de croissance. | À PRENDRE EN COMPTE (un plafond de sûreté par type) | L13 |
| G03 | 18 | `MAX_RESEARCH_TILES = 25` | Plafond du sommet. | À PRENDRE EN COMPTE | — |
| G04 | 20-21 | Décalage des épingles | Réglage d'affichage. | INUTILE POUR NOUS | — |
| G05 | 27-34 | Il ne lit que des SOMMES fournies par le moteur | Décision bon marché. | À PRENDRE EN COMPTE (lire les agrégats du moteur, pas balayer des entités) | — |
| G06 | 36-42 | Porte « constructeurs occupés > mégatuiles ÷ 25 + 1 » | Le seuil grandit avec la taille, car « overproduction in the late game is less catastrophic ». | IMPLÉMENTER | L6, `Dm.slots` ; S ; L0 |
| G07 | 43-44 | Porte « robots logistiques libres < 10 % » | Ne pas ajouter de charge à un transport saturé. | IMPLÉMENTER (porte de transport par les PNJ libres et les tâches libres) | L6 ; S ; L0 |
| G08 | 45-46 | Porte « moins de 300 robots de construction » | Pas d'extension quand les bras ont été décimés. | À PRENDRE EN COMPTE (existe : pile R0, « équipe sous son effectif de départ ») | — |
| G09 | 48-53 | Crise d'énergie : entrée sous 40 %, sortie au-dessus de 50 % ; besoin verrouillé jusqu'à la pose | Ni oscillation, ni « guérison » trompeuse. | IMPLÉMENTER | L12, `power_options` (`Ca.options` l.1813), `Pi.signals` `pile.lua:424` ; S |
| G10 | 55-57 | Porte combinée | Toutes les gardes avant toute décision. | À PRENDRE EN COMPTE | — |
| G11 | 59 | `out = {}` à chaque passage | Les commandes sont réémises, jamais périmées. | À PRENDRE EN COMPTE (ordres idempotents) | — |
| G12 | 61-167 | Table de 10 rangs écrite à la main ; 3 écarts à sa propre règle (pack logistique, four en pierre, plastique) | Une table à la main se trompe. | IMPLÉMENTER (calculer) | L1 ; M |
| G13 | 169-211 | Plus bas rang en manque ; le plus négatif ; on s'arrête au premier rang qui a un manque | Le cœur des rangs. | IMPLÉMENTER (porte ciblée par dépendance) | L2 ; M ; L1 |
| G14 | 178-180 | Égalité : le premier de la liste gagne (`<` strict) | Départage déterministe. | À PRENDRE EN COMPTE (égalités par clé triée, déjà la règle) | — |
| G15 | 181-204 | Le dernier posé est sauté, sauf s'il est le seul en manque de son rang | Le signal est en retard sur la pose : ne pas surconstruire. | IMPLÉMENTER (anti-répétition sur un signal MESURÉ) | L6 ; S ; L3 |
| G16 | 213-238 | Initialisation : compteur relu depuis le réseau au premier passage | Reprise sur l'observation après un démarrage. | À PRENDRE EN COMPTE (après un chargement : reconstruire, comme CAPI-DECIDE) | — |
| G17 | 219-225 | « we can't trust the input from the outside world … we wait for the numbers … to match » | Compteur d'intention contre observation : pas de double pose. | IMPLÉMENTER | L5 ; M |
| G18 | 242-243 | Nouvelle mégatuile seulement quand l'observé a rattrapé l'intention | Confirmation avant l'étape suivante. | IMPLÉMENTER | L5 ; M |
| G19 | 244-286 | Sonde (30 × 30) et défrichage (50 × 50) AVANT la décision ; `delay = 60` | Décider sur des faits frais ; préparer la place. | IMPLÉMENTER | L9 + L8 ; S à M |
| G20 | 293-295 | Un chantier en cours est continué | Ne jamais abandonner un chantier pour un nouveau choix. | À PRENDRE EN COMPTE (projets : inertie de +20 %, `projets.lua`) | — |
| G21 | 296-299 | La 1re mégatuile est nucléaire | L'énergie d'abord. | À PRENDRE EN COMPTE (première expansion = énergie) | — |
| G22 | 300-308 | Zone riche en minerai : mégatuile vide (minée par ses tuiles), même en crise | Occasion de gisement. | IMPLÉMENTER | L9 ; S |
| G23 | 310-335 | Nucléaire seulement si combustible et réacteurs sont au stock, sinon solaire | Choisir l'énergie dont la chaîne est PRÊTE. | À PRENDRE EN COMPTE (`can_exec`, objets du gabarit fabricables) | — |
| G24 | 316 contre 322 | Le commentaire dit « last 2 megatiles », le code fait `>= last + 1` | Écart entre commentaire et code. | INUTILE POUR NOUS (leur défaut) ; À PRENDRE EN COMPTE (relire le code, pas le commentaire) | — |
| G25 | 336-338 | Moins de 9 mégatuiles : solaire quand même | Énergie d'avance au départ. | À PRENDRE EN COMPTE | — |
| G26 | 341-347 | Pétrole si un baril manque et que la précédente n'était pas pétrole | Pas deux grosses unités de suite. | IMPLÉMENTER (anti-répétition, même règle que G15) | L6 ; S |
| G27 | 386-389 | Drapeau d'artillerie à chaque coin après 36 mégatuiles | Défense géométrique. | INUTILE POUR NOUS | — |
| G28 | 400-434 | Sonde de 10 × 10 par tuile | Sonder chaque place. | IMPLÉMENTER | L9 ; S |
| G29 | 436-438 | Déployeur occupé : refaire le MÊME plan | Une relance est idempotente. | IMPLÉMENTER | L5 (une relance reprend le même gabarit) ; S |
| G30 | 440-468 | Minage seulement si le stock du réseau est sous 250 000 (pierre 200 000, uranium 100 000) | Plafond de stock par matière première. | À PRENDRE EN COMPTE (existe : saturation, `B.SAT_FACTOR`) | — |
| G31 | 451-462 | Minerai le plus abondant à cet endroit | Exploiter ce que la place offre. | À PRENDRE EN COMPTE | — |
| G32 | 486-493 | Tuile de recherche si le minuteur est échu (et moins de 25) | Marche du sommet. | IMPLÉMENTER | L10 ; S |
| G33 | 494-501 | Crise d'énergie et rien d'autre à faire : « Small Power Station » | Une petite unité d'urgence. | À PRENDRE EN COMPTE (centrale de secours bon marché) | — |
| G34 | 502-511 | Minuteur de 18 000 ticks posé seulement si rien ne manque et pas de crise | Ne pas grandir pendant une crise. | IMPLÉMENTER | L10 ; S |
| G35 | 549-555 | Étiquette de carte par tuile (`_api`, `add_chart_tag`) | Voir les décisions sur la carte. | IMPLÉMENTER | L11 ; S |
| G36 | 556-565 | Compteur avancé seulement si le déployeur était libre ; toute pose annule le minuteur | Confirmation, et stabilité remise à zéro. | IMPLÉMENTER | L5 + L10 ; S |
| G37 | 566 | `delay = 120` après une tuile, 60 après une sonde | Laisser au signal le temps de bouger. | À PRENDRE EN COMPTE (cadence de 1 min de la capitalisation) | — |
| G38 | 568-570 | Porte fermée : la sonde est jetée | Des données périmées ne servent pas. | À PRENDRE EN COMPTE | — |
| G39 | 572, 13-14 | `signal-check` = « good time for construction and research », faux en choc logistique | [DÉDUIT] La recherche est coupée quand le transport sature. | À PRENDRE EN COMPTE (pile : R3 suspendu ; tournées de packs moins prioritaires sous saturation) | — |

## C. Description et FAQ (D)

| # | Élément | Réflexion derrière | Verdict | Cible |
|---|---|---|---|---|
| D01 | Mise à jour du 17/03/2025 : ne marche plus en 2.0 | Dépendance aux mods. | INUTILE POUR NOUS (1.1.91) | — |
| D02 | Pour transplanter la racine : le livre de plans, « a stack of heavy oil barrels », « at least one logistic bot » | La liste MINIMALE d'amorçage est explicite. | À PRENDRE EN COMPTE (notre kit de départ des factions, écrit et minimal) | — |
| D03 | `von_noying.lua`, `safe_mode` | Option sans biters. | INUTILE POUR NOUS | — |
| D04 | Matériel d'enregistrement | Production vidéo. | INUTILE POUR NOUS | — |
| D05 | « about six months total … most of that was tweaking and minor improvements » | Le gros du travail est le réglage. | À PRENDRE EN COMPTE (prévoir le temps de réglage et le moteur simulé) | — |
| D06 | Le nom « Von Noying » | Anecdote. | INUTILE POUR NOUS | — |
| D07 | Lampes sur un réseau séparé : la courbe de puissance donne le % de robots inactifs | Une mesure dans le temps de la saturation du transport. | À PRENDRE EN COMPTE (existe : `[FO-ACTIF]`, PNJ libres et tâches libres) | — |
| D08 | Tuiles nucléaires gardées dans la racine : « finding a good build condition … proved difficult » ; une de chaque suffit | Quand une condition de pose est difficile, une instance fixe au départ vaut mieux qu'une règle fragile. | À PRENDRE EN COMPTE | — |

## D. Vidéo de suite (V2)

| # | mm:ss | Dit | Réflexion derrière | Verdict | Cible |
|---|---|---|---|---|---|
| W01 | 0:56 | Le mod LTN était requis sans le savoir : son signal servait dans un combinateur | Une garde dépend d'une entrée qui peut manquer. | IMPLÉMENTER (garde fermée si l'entrée manque, refus écrit) | L13 ; S |
| W02 | 2:00 | Le but : « I didn't want anything from the mall to be putting Demand on the network if we were out of water » | Couper une source de demande quand une ressource critique en amont manque (eau → nucléaire → énergie). | À PRENDRE EN COMPTE (la pile suspend R3 ; garde « matière critique » à envisager) | — |
| W03 | 2:19 | « in practice this might not really be needed … water crises end up sorting themselves out » | Honnêteté : une garde qu'on n'a pas su prouver. | À PRENDRE EN COMPTE (une garde sans mesure se prouve ou se retire) | — |
| W04 | 2:40 | Mod Auto Research : « you need that research to keep coming » | La file de recherche ne doit jamais être vide. | À PRENDRE EN COMPTE (IA-G choisit toujours ; votre équipe ne cherche que si la force est libre, `script/ai3/cerveau.lua:792`) | — |
| W05 | 4:37 à 8:19 | Tutoriel d'installation du scénario | Mode d'emploi. | INUTILE POUR NOUS | — |
| W06 | 7:57 | Ne pas éditer le scénario pendant qu'il tourne ; « this particular function and not on player created for a reason » | Piège d'événement. | INUTILE POUR NOUS | — |
| W07 | 9:12 | « planners and pantsers … the AI had to figure out what to do at each step on its own » | Réactif contre planifié. | À PRENDRE EN COMPTE (garder notre hybride : calcul par la capitalisation, mesure par L3) | — |
| W08 | 10:24 | L'usine de Griswald calculée d'avance (« 1,000 white science per minute » dans le calculateur) | Le contrepoint planifié, « immaculate ». | À PRENDRE EN COMPTE | — |
| W09 | 12:19 | « I did have to hardcode … these tiers … a little bit unfortunate » | Les rangs doivent venir des données. | IMPLÉMENTER | L1 ; M |
| W10 | 12:38 | « as long as the algorithm knows about this general structure, that you can't make these things without these things » | La seule connaissance nécessaire, c'est la structure des dépendances. | IMPLÉMENTER (rang depuis le graphe) | L1 ; M |
| W11 | 13:29 | Les commentaires demandent de la « real AI » | Sujet de la suite. | INUTILE POUR NOUS | — |
| W12 | 14:29 | « if you have a deterministic algorithm that does the correct thing almost all the time, replacing it with AI … would end up approximating this function » | Une règle déterministe juste vaut mieux qu'un apprentissage coûteux. | À PRENDRE EN COMPTE (notre choix : règles pures déterministes) | — |
| W13 | 15:31 | Recherche arborescente de Monte-Carlo : « not always pick the best one … local maximum » | Explorer pour éviter un maximum local. | INUTILE POUR NOUS (pas d'apprentissage ; déterminisme) | — |
| W14 | 16:28 | Go se simule presque gratuitement, Factorio non | Le coût de la simulation borne l'apprentissage. | À PRENDRE EN COMPTE (notre moteur simulé est notre « jeu bon marché ») | — |
| W15 | 17:40 | Une partie probante dure 24 h de jeu, environ 12 h réelles | Les preuves longues coûtent cher. | À PRENDRE EN COMPTE (micro-scénarios d'abord, bancs longs avec accord du DC) | — |
| W16 | 19:46 | Pokémon par RL : 1 000 $ de calcul | Ordre de grandeur. | INUTILE POUR NOUS | — |
| W17 | 22:08 | « the AI would be up against a pretty good algorithm … tons and tons of compute » | Conclusion contre le RL. | INUTILE POUR NOUS | — |
| W18 | 23:00 | Remerciements | Fin. | INUTILE POUR NOUS | — |

## E. Réponses de l'auteur en commentaires (C)

| # | Dit (citation courte) | Réflexion derrière | Verdict | Cible |
|---|---|---|---|---|
| C01 | Formule de portée d'artillerie : « probably the correct answer … bugs wouldn't show up until the factory had been running for hours » | Les défauts tardifs n'apparaissent qu'après des heures. | À PRENDRE EN COMPTE (parties longues au moteur simulé) | — |
| C02 | JOSEF : « using Factorio's mechanics alongside combinators » | Les mécaniques natives font le travail sans script. | À PRENDRE EN COMPTE (barres de coffre, F95 ; L4) | — |
| C03 | Factorio 2.0, assembleur universel | Avenir. | INUTILE POUR NOUS (1.1.91) | — |
| C04 | En vanilla : « at least a 3x3 megatile … of combinators » | Combinateurs contre Lua. | INUTILE POUR NOUS | — |
| C05 | Balises : « adding beacons means fewer assemblers » ; modules de productivité : « reducing the total number of bots needed » | Moins d'ingrédients, c'est moins de transport. | À PRENDRE EN COMPTE (pour des PNJ, un module de productivité réduit les tournées : valeur logistique des modules D-17) | — |
| C06 | Réacteurs 2 × 2 : « no room for all the exchangers and turbines » | Contenu nucléaire. | INUTILE POUR NOUS | — |
| C07 | « make the placement of stuff as "dumb" as possible. The "smarter" the algorithm gets, the higher the likelihood of a really nasty … bug … deep into the run » | La simplicité protège des défauts tardifs. | À PRENDRE EN COMPTE (règle la plus petite qui marche ; repli simple de placement) | — |
| C08 | « encode any sort of quotas into the blueprints and not the algorithm » | Séparer : le module se règle, le cerveau décide. | IMPLÉMENTER | L4 ; M |
| C09 | Hexagones ; Moon Logic pour les décalages | Géométrie. | INUTILE POUR NOUS | — |
| C10 | Version 2.0 cassée | Maintenance. | INUTILE POUR NOUS | — |
| C11 | Remplacer les coffres infinis par des coffres contenant le nombre mesuré ; sans modules, recalculer les quotas | Dimensionner un vrai kit par la mesure de l'amorce ; quotas recalculés depuis les débits. | IMPLÉMENTER (compteur d'amorce) ; À PRENDRE EN COMPTE (quotas calculés, L4) | L7 ; S |
| C12 | « 1000 construction bots and 500*(number of megatiles) logistic bots … trial and error » ; plus d'un million de robots perdus avec biters | Un effectif cible proportionnel à la taille ; des pertes énormes. | À PRENDRE EN COMPTE (`E.decide` borne par le travail qui attend) | — |
| C13 | Bug des silos : « is there a -10K signal … for all the items in the mall? » | Un défaut de demande se diagnostique sur la graine. | IMPLÉMENTER (plafond par objet ; garde fermée par défaut) | L13 ; S |
| C14 | « I reach through to _api and set map pins for each tile » | Traçabilité visuelle. | IMPLÉMENTER | L11 ; S |
| C15 | « Lua is not the UPS bottleneck » ; pas besoin de script externe | Une décision bon marché. | À PRENDRE EN COMPTE (chez nous, le script EST le goulot : 84 ms par pensée, `DECOUPAGE-PENSEE`) | — |
| C16 | Vidéo de 10 h : « you have to keep moving the camera » | Production vidéo. | INUTILE POUR NOUS | — |
| C17 | Waterfill pas dans les plans | Limite de mod. | INUTILE POUR NOUS | — |
| C18 | Factorio 2 force plus de travail manuel | Avenir. | INUTILE POUR NOUS | — |
| C19 | RL : 1 000 $ pour battre Pierre ; 1 M$ pour Factorio | Coût. | INUTILE POUR NOUS | — |
| C20 | Un réseau pourrait « better predicting what will be needed next instead of reacting to demand and power spikes after they happen » | La faiblesse de la boucle réactive, c'est le RETARD. | À PRENDRE EN COMPTE (graine de demande par le plan à venir, L7 ; `Prev.think` pour les menaces, `script/ai3/prevision.lua:403`) | — |
| C21 | Musique (Donkey Kong 64, Banjo-Tooie) | Anecdote. | INUTILE POUR NOUS | — |
| C22 | UPS qui tend vers 0, limite de mémoire | Théorie. | INUTILE POUR NOUS | — |
| C23 | Modules de productivité : « production more stable and predictable with fewer boom-bust cycles » | La stabilité a une valeur en soi. | À PRENDRE EN COMPTE (petites marches, L6) | — |
| C24 | « avoid … plug "1000 of all sciences per minute" in to the Factorio online calculator … the algorithm should be in charge of "designing" » | Concevoir en réagissant. | À PRENDRE EN COMPTE (hybride) | — |
| C25 | Le plaisir de résoudre sans casser ce qui marche | Méthode. | À PRENDRE EN COMPTE (non-régression : A/B octet à octet) | — |
| C26 | « lay down tiles with level 1 mods, then later use upgrade planners to get them to levels 2 and 3 » | Améliorer sur place plutôt que reconstruire. | À PRENDRE EN COMPTE (existe : niveaux, `Capital.goal` `script/ai3/capital.lua:438` ; foreuses `Swap.think`) | — |
| C27 | « It does require pre-researched techs (I don't know of any SEFs that don't) » | Toutes les usines auto-extensibles trichent sur la recherche. | INUTILE POUR NOUS (nous payons la recherche) | — |
| C28 | Capture vidéo 4K | Matériel. | INUTILE POUR NOUS | — |

## F. Scénario (S)

| # | Élément | Réflexion | Verdict |
|---|---|---|---|
| S01 | `research_all_technologies` | Triche de recherche. | INUTILE POUR NOUS |
| S02 | `game.speed = 100` | Accélérer les essais. | INUTILE POUR NOUS (nos bancs ont leur mode) |
| S03 | `cheat_mode` du joueur | Triche. | INUTILE POUR NOUS |
| S04 | `safe_mode` : ennemis, falaises et pollution retirés | Banc sans ennemis. | À PRENDRE EN COMPTE (bancs « Paisible » déjà) |
| S05 | La surface 2 (plans) est vidée au départ | [DÉDUIT] Les plans sont dessinés sur une seconde surface. | INUTILE POUR NOUS |

---

## G. Les IMPLÉMENTER, classés par rentabilité

| Rang | Lot | Lignes de cette liste | Ce que ça règle chez nous | Module cible (`IA_WORKFLOW.md`) | Taille | Dépend de |
|---|---|---|---|---|---|---|
| 1 | L0 mesures H-VID-1, H-VID-2, H-VID-3 | V73, V77, G06, G07 | Savoir avant de changer : ordres émis contre chantiers commencés, pic d'amont, coût de `Ca.requirements`. | Journaux `[FO-CAPI]`, moteur simulé | S | — |
| 2 | L1 rang calculé (+ L1b perf) | V12, V17, V18, V39, G12, W09, W10 | Tiers dynamiques par force et par âge ; `depth` refait jusqu'à 25 fois par décision (l.764-788). | nouveau `shared/ai3/rang.lua` ; `Ca.requirements` `shared/ai3/capitalisation.lua:752` | S à M | — |
| 3 | L2 porte de rang ciblée | V15, V16, V19, V20, V30, G13 | Modules en attente de fer qui tiennent les places de la foreuse de fer (`emplacements.lua`, règle 8 ; `REPRISE.md` l.22). | `Ca.options` l.1791, `Ca.before` l.1784, `fabric_options` l.1571 | M | L1, L0 |
| 4 | L5 confirmation observée | V54, V72, G17, G18, G29, G36 | Une machine posée mais non nourrie compte comme capacité (W D1, D2). | entrée `machines` de `Ca.decide` l.1941 ; `advance` `script/team/build.lua:4098` ; `emplacements.lua` | M | — |
| 5 | L3 manque mesuré, transit compris | V14, V26, V28, V29, V59, V81, V82, V83 | Le fer des coffres du plan directeur invisible (W D1) ; un vrai signal de manque. | nouveau `shared/ai3/manque_local.lua` ; `Team.view` `script/team/team.lua:462` ; puits `Ca.requirements` l.756 | M | — |
| 6 | L6 petites marches et portes | V21, V73, V77, V78, G06, G07, G15, G26 | « 0 PNJ libre, 16 tâches libres » (W D1) ; pics d'amont. | `Ca.decide` l.1973, `Dm.slots` `shared/ai3/demande.lua`, `Ex.guard` `shared/ai3/extension.lua` | S | L0 (L3 pour l'anti-répétition) |
| 7 | L4 quotas du gabarit | V24, V25, V27, C08 | Fours « sortie pleine » (W D2) ; ingrédients avalés par des modules pleins. | `shared/team/patrons.lua` ; `keep_stock` `build.lua:3904-3911` ; quais `build.lua:3925-3983` | M | — |
| 8 | L11 trace sur la carte | G35, C14 | Le DC voit les décisions là où elles sont posées. | runtime `script/ai3/capitalisation.lua` ; `add_chart_tag` comme `script/world/guarantee.lua` | S | — |
| 9 | L7 amorce et retrait | V51, V52, V53, V55, V56, C11 | La dépendance à la main ; un kit de départ dimensionné par la mesure. | `Ml.decide` `shared/ai3/mall.lua:98`, `Ml.hand_allowed` l.168 ; file de `Build.request` | S | L5 |
| 10 | L10 marches de stabilité | V57, V58, V65, V66, G32, G34 | Croissance par paliers sûrs, à comparer à C2. | `Dm.step` `shared/ai3/demande.lua` | S | L1, L3 |
| 11 | L12 hystérésis et verrou | G09 | Crises qui oscillent ou se « guérissent » trop tôt. | `power_options` ; `Pi.signals` `shared/ai3/pile.lua:424` | S | (L5) |
| 12 | L13 plafonds et gardes fermées par défaut | W01, C13, G02 | Emballement d'un objet ; garde à entrée manquante. | `Ca.decide` (`Ca.OPEN_MAX` l.148) | S | — |
| 13 | revue de la saturation | V79 | Un stock qui masque un manque de capacité. | `B.saturated` `shared/ai3/buts.lua:150` | S | — |
| 14 | L9 sonder, minerai d'abord | V45, V46, V47, G19, G22, G28 | Fabrique posée sur un gisement ; décision sur des faits périmés. | lots « gisement » `shared/team/plan.lua` l.9-11, l.42 | S | — |
| 15 | L8 lot prêt avant l'ordre | V23, V72, G19 | Module bloqué en défrichage qui tient une place (en-tête d'`emplacements.lua`). | `Build.think` `build.lua:4846` ; `emplacements.lua` règle 2 | M | — |

**Décompte :**
- 106 lignes de la vidéo principale, 39 du code, 8 de la description, 18 de la suite, 28 commentaires, 5 du scénario : 204 lignes ;
- 64 IMPLÉMENTER, 88 À PRENDRE EN COMPTE et 56 INUTILE POUR NOUS, compté par script sur la colonne des verdicts ;
- 4 lignes portent deux verdicts, d'où 208 verdicts pour 204 lignes ;
- aucune ligne n'est sans verdict.
