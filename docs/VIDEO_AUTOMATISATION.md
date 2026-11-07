# Vidéo « Factorio Automated » (Chris Uehlinger, @uehreka) : compte rendu exhaustif et plan d'implémentation

Rapport de recherche du 7/11/2026, deuxième version (la première est remplacée). Travail limité au web et à la lecture :
aucun code écrit, aucun Factorio, aucun Blender (le DC joue).

**Demandes du DC, mot pour mot :**
- « Analysez la vidéo pour en tirer les bons aspets qui nous feront avancer rapidement. De manière critique, ils faut que les
  agents soient conscient du workflow de la logique globale de notre IA de faction. »
- « j'ai écouté la vidéo 4 fois, j'ai vraiment bien récouté et je pense qu'on peut au moins récupérer 50% de la logique globale.
  Donc le compte rendu de l'agent mendaté pour regarder la vidéo, doit être exhaustif et surtout qu'on puisse l'implémenter dans
  notre logique (tiers dynamique, etc...) »
- « il faudra une todo liste exhaustive pour chaque petit élément de la vidéo. Y a beaucoup de chose qu'il dit qui sont en fait
  une réflexion précise derrière a implémenter ou au moins a prendre en compte (même si évidemment j'ai dit 50% donc forcément y a
  plein d'infos qui pour nous seraient inutile) »

**Fichiers du dossier :**
- ce rapport ;
- `TODO_VIDEO.md` : une ligne par élément de la vidéo, avec son verdict ;
- `IA_WORKFLOW.md` : la carte de notre IA, écrite par l'agent carte-ia sur le code 0.6.58, commit 0e340b99, worktree
  `integ-0652b`.

Tous les chemins de notre code cités ici partent de ce worktree.

**Étiquettes :**
- **[LU …]** : lu dans la source dite. L'horodatage est en mm:ss pour une vidéo ; pour un fichier, c'est un numéro de ligne.
- **[DÉDUIT]** : mon raisonnement. Ce n'est pas dit par l'auteur et ce n'est pas prouvé en moteur réel.

**Sources :**
- **V** : vidéo principale, sous-titres automatiques ;
- **D** : sa description ;
- **G** : le code de l'algorithme (gist) ;
- **S** : le scénario ;
- **V2** : la vidéo de suite ;
- **C** : les réponses de l'auteur en commentaires ;
- **M** : les pages des mods ;
- **N** : notre code ;
- **W** : `IA_WORKFLOW.md`.

---

## 0. Ce qui a été lu, ce qui ne l'a pas été

| Source | Ce que c'est | État |
|---|---|---|
| V | Sous-titres AUTOMATIQUES anglais : 15 min 30, publiée le 19/01/2024, 516 347 vues le 7/11/2026, 457 segments horodatés (récupérés avec yt-dlp). | **Lu en entier.** Reconnaissance vocale : « signs per minute » = science per minute, « megga tiles » = megatiles, « manfacturing » = manufacturing. Les citations sont reprises telles quelles. |
| D | Description, FAQ de l'auteur, 21 chapitres. | **Lu en entier** |
| G | `the-algorithm.lua`, 571 lignes, gist publié par l'auteur le jour de la vidéo (lien de la description). | **Lu ligne par ligne** |
| S | Scénario v9 « Return of the Biters » (19/02/2024) : `control.lua`, `von_noying.lua`. | Lu. **La carte (`blueprint.dat`, 4 Mo, binaire) n'est PAS lue.** |
| V2 | « Followup: Factorio Automated » (24 min 32, 20/02/2024), sous-titres automatiques (638 segments) et description. | **Lu en entier** |
| C | 34 réponses de l'auteur, parmi 391 commentaires récupérés (sur environ 487). | Lues. Aucun pseudo ni adresse repris. |
| M | Pages des mods Recursive Blueprints et Moon Logic, README de Moon Logic. | Lues |
| N, W | `IA_WORKFLOW.md` en entier ; dans notre code : `shared/ai3/capitalisation.lua` l.83-150, 700-813, 1571-1706, 1784-2047 ; en-tête de `shared/ai3/emplacements.lua` ; en-tête et `evaluate_feas` de `shared/ai3/graphe.lua` ; en-têtes de `cerveau`, `general`, `demande`, `extension`, `pile`, `mall`, `industrie`, `projets`, `fluides`, `shared/team/plan.lua`, `patrons.lua`. | Lu |

**NON LU, à dire clairement :**
- **Les IMAGES de la vidéo.** Je n'ai que le son transcrit. Ce qui est seulement MONTRÉ n'est pas dans ce rapport : la disposition
  des tuiles, les combinateurs, le « mall of shame » à l'écran, les compteurs. Si le DC se souvient d'un élément montré sans être
  dit, il faut me le donner : je ne l'invente pas.
- La carte du scénario et les sauvegardes, donc le contenu exact des plans de tuiles.
- Reddit (refusé à l'outil).
- Les vidéos citées par l'auteur.

---

## 1. L'usine en une page

```
 Fil ROUGE (le réseau ADDITIONNE) : stock du réseau logistique (+), manques publiés par les tuiles (−), −10 000 par bâtiment
   du « mall of shame » au départ ; robots libres et totaux ; charge des accus ; nombre de mégatuiles et de tuiles de recherche.
                │
                ▼
 Combinateur Moon Logic : Lua dans la partie, 571 lignes, mémoire `var`, relancé tous les 60 à 120 ticks.
   PORTES : robots de construction occupés ? robots logistiques saturés ? crise d'énergie (hystérésis 40/50 %, verrou) ?
   8 tuiles posées ET mégatuile vue par le réseau ?
     ├─ oui → choisir une MÉGATUILE : énergie, pétrole, vide
     └─ non → choisir une TUILE dans la mégatuile vide, par cette PRIORITÉ :
              minerai sous la case > artillerie due > RANG le plus bas en manque > recherche (5 min sans manque) > petite centrale
   Chaque choix se fait en deux passages : 1) SONDER (scanner, défrichage) ; 2) DÉCIDER sur ce qui a été vu.
                │ fil VERT : numéro du plan dans le livre, X, Y (la sortie revient en entrée)
                ▼
 Blueprint Deployer (Recursive Blueprints) → fantômes → robots de construction → tuile posée → compteurs du réseau
                │
 La tuile se RÉGULE SEULE : elle produit jusqu'à 1 min d'avance, demande 1 min d'ingrédients, publie ses manques (négatifs).
```

**[DÉDUIT]** Les « 50 % de logique globale » récupérables sont la BOUCLE DE CONTRÔLE :
1. on mesure le manque, là où il se produit ;
2. on sert le plus bas rang en manque ;
3. on pose une petite unité ;
4. on attend de VOIR qu'elle tourne ;
5. on remesure.

S'y ajoutent l'autorégulation des modules, l'amorce qui se retire seule et la croissance par marches après stabilité. Le reste
(robots, triches, géométrie, nucléaire, barils) ne se transpose pas.

---

## 2. La vidéo, dans l'ordre (chapitres de D), mécanisme par mécanisme

Chaque mécanisme porte un numéro (M01, M02…) repris dans `TODO_VIDEO.md` et au §6.

### 0:00 « Introduction »

**M01** (0:14-0:19). Transport uniquement par robots logistiques : « my factory based entirely on Logistics Bots with no trains
or belts ».

**M02** (0:19-0:28). Jalons mesurés et performance :
- « launch its first rocket in under 6 hours and Achieve 1,000 [science] per minute in under a day » ;
- « about 30 UPS on my M1 Max MacBook Pro, 24 UPS if biters are turned on ».

**M03** (0:31-0:35). « I'm not building anything, this Factory builds itself. »

### 0:45 « Mods used »

**M04** (0:44-1:09). « pretty much any self-expanding Factory requires the recursive blueprints mod ». Le déployeur reçoit trois
choses :
- un plan, un planificateur de déconstruction ou un livre de plans ;
- par les signaux, l'endroit où poser ;
- pour un livre, le plan à prendre.

**M05** (1:09-1:17). L'usine tient en deux pièces : « a book of blueprints to lay out and an automated way to tell the blueprint
deployer which one to deploy ».

**M06** (1:20-1:31). La logique est un combinateur Moon Logic programmé en Lua, pour écrire « a sophisticated algorithm without
having to build Acres of combinator setups ».

### 1:36 « The Algorithm »

**M07** (1:37-1:52). Le même mécanisme fabrique tout : « capable of making not just science but also the buildings needed to
build new parts of the factory and really any arbitrary product I thought I might need like ammunition ».

**M08** (1:52-1:56). « as modular and flexible as possible and tried to avoid hardcoding things as much as possible ».

**M09** (1:57-2:08). Les rangs : « a system of tiers for all the products we would need to craft. The first couple tiers contain
fairly basic ingredients while the last tier contains space science ».

**M10** (2:08-2:12). Hors des rangs : « ore, oil products and power aren't on this list ».

**M11** (2:12-2:20). La demande : « the algorithm looks at the demand numbers coming in on the red circuit network. Any item with
a negative signal is in demand ».

**M12** (2:20-2:33). Le parcours des rangs : « if there is no demand for anything in tier one we check if anything from tier 2 is
in demand and so on. Once we find a tier where one or more items are in demand we build a tile designed to manufacture the item
with the most demand ».

**M13** (2:36-2:47). La définition : « I put every item in the lowest number tier that doesn't contain any of its ingredients ;
green chips require iron plates and copper wire, iron plates are in tier one and copper wire is in tier 2 ».

**M14** (2:49-2:59). La raison : « if green chips and copper wire are both in demand it probably means we should build copper wire
assemblers first, since if there isn't enough copper wire it doesn't matter how many green chip assemblers we have ».

**M15** (3:00-3:07). Le principe : « often supply chain issues are caused by shortages of low-level ingredients and if we take
care of those suddenly some of the higher tier products aren't in demand anymore ».

### 3:10 « Manufacturing Tiles »

**M16** (3:11-3:20). « the smallest unit of construction in this Factory is what I call a tile and a 3X3 grid of these is called
a mega tile ».

**M17** (3:20-3:28). « most of the time we'll expand the factory by building a blank Mega tile then filling each of the eight
empty tiles with manufacturing tiles ».

**M18** (3:28-3:36). Quota de sortie : « it needs to keep manufacturing until it has 1 minute's worth of surplus in its provider
chests ».

**M19** (3:36-3:38). Quota d'entrée : « it needs to request 1 minute's worth of ingredients ».

**M20** (3:38-3:44). « it needs to report to the red circuit Network any ingredients that are missing ».

**M21** (3:44-3:50). La garde est sur les bras d'ENTRÉE : « the ingredient inserters are wired up to only work if there is less
than 1 minute worth of product in the provider chests ».

**M22** (3:50-4:03). Formule du manque : « the requester chests report the number of ingredients they have to this combinator,
which subtracts from the number of ingredients that are needed, and if the number is negative, meaning ingredients are needed,
then that negative number is passed to the red circuit Network ».

**M23** (4:03-4:21). La cascade :
- « The first time we build a green chip tile we may not have any copper wire tiles, so the green chip tile will report that
  copper wire is in demand » ;
- « the algorithm will probably decide to build a copper wire tile next, and it will continue building them until copper wire
  demand is satisfied or a lower tier ingredient like copper plate is in demand ».

### 4:24 « Solar Megatiles »

**M24** (4:23-4:29). « power and oil are two concerns that won't fit onto a single tile and require special case Mega tiles ».

**M25** (4:29-4:37). Une mégatuile solaire « with a perfect balance of solar panels and accumulators ».

**M26** (4:37-4:51). Le coût énergétique du transport :
- « each Mega tile has to have at least one Robo port and Robo ports can use up to 4 megawatts when charging Bots, it was
  actually pretty hard to break even » ;
- résultat : « giant oceans of solar dotted with islands of manufacturing tiles ».

### 4:54 « Nuclear Megatiles »

**M27** (4:53-5:00). « a nuclear Mega tile with a 2x2 reactor neighbor bonus ».

**M28** (5:00-5:23). Le combustible est donné selon le TAMPON :
- « every couple minutes we check if the steam in the storage tanks has gone below a certain threshold and if it has we feed fuel
  cells » ;
- « we don't waste fuel cells keeping the reactors at 1,000° and ideally only feed them when they go below 500 ».

### 5:27 « Oil Processing Megatiles »

**M29** (5:26-5:32). Contourner un placement difficile : « The algorithm doesn't have any method for building or piping pump
jacks, so all oil processing has to be based on coal liquefaction ».

**M30** (5:32-5:41). Amorce d'une recette qui a besoin de son produit : « we have to start with a few barrels of heavy oil in the
root megatile to Kickstart the first oil processing Mega tile ».

**M31** (5:41-6:02). Équilibre des co-produits par comparaison de stocks :
- « if we have more barrels of heavy oil than light oil we pump heavy oil into the Eastern Area to be cracked into light oil » ;
- et de même pour l'huile légère et le gaz.

**M32** (6:02-6:16). Soupape : « in the unlikely event that petroleum pipes get full while we're low on heavy or light oil, we
have a pump that will turn on and feed this chemical plant which will turn the excess petroleum into solid fuel, although this
basically never happens ».

### 6:17 « Mining Tiles »

**M33** (6:16-6:31). Le minerai est prioritaire :
- « our Factory does place a premium on mining its own resources. If the resource scanner provided by the recursive blueprints
  mod detects a large amount of ore in an upcoming Mega tile, that Mega tile will be built as a blank Mega tile even if we're in a
  power crisis » ;
- la raison : « because we don't know when we'll come across ore again ».

**M34** (6:31-6:38). « whenever we build a tile we also scan for ore and build a mining tile if ore is present ».

**M35** (6:38-6:50). Une amorce qui ne coule qu'au compte-gouttes :
- « the root Mega tile does have infinite chests that will supply a dribble of ore if there is negative amount in the red circuit
  network » ;
- « after about a dozen Mega tiles we've usually got iron and copper ore and we don't need these anymore ».

### 6:56 « Kickstart demand with the "Mall of Shame" »

**M36** (6:56-7:10). Une amorce provisoire : « rows of infinite chests that supply all the buildings we're going to use to build
the factory; however we're only going to use these until we have a tile that can craft the buildings ».

**M37** (7:10-7:21). Demande forcée : « Under each infinite chest is a constant combinator that puts a demand for 10,000 of the
building onto the red circuit Network. This means the algorithm will try and build tiles that manufacture these buildings as soon
as it can ».

**M38** (7:21-7:26). Fin = première production : « each manufacturing tile for these buildings reports to the green circuit
Network when it first successfully manufactures its product ».

**M39** (7:26-7:41). Retrait, et la mesure est gardée : « the blueprint deployer at the bottom uses a deconstruction planner to
remove the infinite chest, inserter, provider chest and constant combinator, leaving only an arithmetic combinator that holds the
number of products that were pulled from the infinite chest before it was destroyed ».

### 7:42 « Building the first Research Tile »

**M40** (7:44-7:55). Minuteur de stabilité : « once we have tiles for everything in the mall and we've built enough tiles to
satisfy all the downstream demand, what do we do? Well, the algorithm sets a 5-minute timer and if no products come into demand
during those 5 minutes we build a research tile ».

**M41** (7:58-8:09). Le sommet publie lui aussi sa demande :
- « research tiles report their demand on the red circuit network, so this immediately creates demand for all seven sciences » ;
- « creating manufacturing tiles for those starts to strain demand on other products, or create demand for products that we
  don't have tiles for yet ».

### 8:17 « The climb to 1000SPM »

**M42** (8:16-8:32). Après le 1er lancement (« about 6 game hours and 100 mega tiles ») :
- « the algorithm usually is to build out a ton of power to handle the load of all these tiles running continuously » ;
- puis « backfill some of the slower tiles like rocket control unit and rocket fuel that built up surpluses ».

**M43** (8:33-8:44). La marche suivante : « if things stay that way for 5 minutes straight we build a new research tile and then
whatever tiles are needed to keep up the pace ».

**M44** (8:44-8:51). « this phase of the factory continues indefinitely until, usually after over 500 mega tiles and 25 research
tiles, we've achieved 1,000 science per minute ».
- **Écart** : le gist plafonne à 484 mégatuiles (G l.17).

### 8:55 « Biter Defense »

**M45** (8:56-9:09). « most of the footage I've shown you was gathered with biters turned off » ; avec biters, il faut « several
days of real world time ».

**M46** (9:09-9:25). Artillerie :
- « starts with an artillery cannon that clears the area around the root Mega tile and keeps us free of biter nests for about 36
  mega tiles » ;
- ensuite, « sets a flag for each time the factory reaches a corner, telling it to build an artillery station tile at the next
  opportunity ».

**M47** (9:25-9:35). « it's important that we clear biter nests before we try to build on top of land, since otherwise the
blueprints will be incomplete and we have no way to detect or fix if that happens ».

**M48** (9:35-9:51). Porte des constructeurs :
- « the algorithm waits until almost all construction Bots are idle before surveying or building a new tile » ;
- avec biters, « construction Bots will be kept busy fixing and replacing damaged buildings ».

**M49** (9:54-10:06). Idée d'avenir : « inject one or two research tasks for artillery range after a certain number of Mega tiles,
since the gaps in artillery coverage start to get close to the Factory's outer layers ».

### 10:15 « Pro: Small Tiles mean low stakes »

**M50** (10:18-10:51). Petites unités :
- « the rail based tiles had to be huge; this meant that if my algorithm built the same tile twice by accident it would lead to
  massive downstream demand spikes » ;
- « The smallness of the manufacturing tiles ensure that if we build one too many for a particular product, we don't create too
  much downstream demand » ;
- « and if we build up a surplus it doesn't get so large that it prevents us from realizing that we don't have enough production
  capacity later on ».

### 10:53 « Pro: Fine-grain measurements of supply and demand »

**M51** (10:57-11:15). Des quantités, transit compris :
- « in my previous Factory a rail tile would report a one on the green circuit network if it was missing a particular
  ingredient » ;
- « In this Factory I know exactly how much of each ingredient is in demand » ;
- « the way the logistic network reports to the Circuit Network ensures that product that is in transit is accounted for as
  well ».

### 11:17 « Pro: Transportation is simple »

**M52** (11:20-11:54). Trois réponses de la même boucle :
- « if not enough stuff is going where it needs to go I just add more Bots until stuff is flowing » ;
- « if the number of bots means the robo ports become the number one power draw we just build more power » ;
- « if the travel times get too long the unsatisfied demand will cause us to overbuild manufacturing tiles until we're
  manufacturing everything close to where it's needed ».

L'auteur conclut : « this Factory is able to address its own issues ».

### 11:54 « Con: UPS »

**M53** (11:56-12:35). Performance :
- « keep UPS above 60 for a couple hundred mega tiles », puis « half speed » à 1 000 SPM ;
- à 10 000 SPM, il faut « design a minifactory that is self-contained and then stamp out several dozen copies with unconnected
  logistic networks » ;
- le prix de son choix : « I wanted the algorithm to sort of design the factory as it goes, which means I pay the price in terms
  of inefficient layout, long travel times, more active Bots at any given time and therefore lower UPS ».

### 12:35 « Con: Water »

**M54** (12:37-12:53). L'eau :
- « I never got around to sorting out how to do offshore pump tiles ; I'd probably have to add some sort of multiphase
  Blueprinting logic » ;
- à la place, des tuyaux d'eau infinis, « definitely a copout ».

### 12:56 « Con: Modules »

**M55** (12:59-13:33). Les modules :
- « the supply chain required for that is about as large as a 1,000 [science] per minute Factory alone » ;
- « I've disconnected the combinators so we never actually build the tiles for them and we just rely on the infinite chest
  forever » ;
- les rétrograder « would require refactoring every manufacturing tile ».

### 13:36 « Things that aren't Cons »

**M56** (13:35-13:53). Les combinateurs ordinaires auraient demandé « at least a 3 by 3 block of Mega tiles just for
combinators ».

### 14:00 « Other factories you should check out » ; 14:35 « Conclusion »

**M57** (14:01-15:27). Références :
- GreyGoo (inspiration), JOSEF, l'usine communautaire de Nilaus ;
- souhait : « automated Factory design could become a new category of play ».

---

## 3. Les « tiers dynamiques » en détail

### 3.1 Définition
- **Dite [LU V 2:36-2:47]** : « I put every item in the lowest number tier that doesn't contain any of its ingredients. »
  **[DÉDUIT]** La lecture qui rend l'exemple juste : rang(objet) = 1 + le plus haut rang de ses ingrédients. Les plaques sont au
  rang 1, le câble au rang 2, le circuit vert au rang 3.
- **Codée [LU G l.61-167]** : une table ÉCRITE À LA MAIN de 10 rangs et d'environ 100 objets, chacun avec le numéro du plan qui le
  fabrique (`outSignal`). Rang 1 : plaques de fer, de cuivre, briques de pierre. Rang 10 : science spatiale.
- **Ce qui n'est PAS dans les rangs [LU V 2:08-2:12 ; G]** : le minerai (tuiles de minage décidées par la sonde), les produits du
  pétrole (mégatuile pétrole décidée par les barils en manque), l'énergie (mégatuiles et petite centrale décidées par la charge
  des accus), la recherche (minuteur) et l'artillerie (drapeau).
- **[LU V2 12:19-12:38]** L'auteur regrette ce codage en dur : « I did have to hardcode some things like these tiers … which I
  think is a little bit unfortunate ». **[LU V2 12:38-12:57]** Il dit aussi que c'est la seule connaissance nécessaire : « as long
  as the algorithm knows about this general structure, that you can't make these things without these things, it's able to sort
  of just go on its own … just by reacting to what the factory needs at any moment ».

### 3.2 La table écrite s'écarte de la règle dite
**[DÉDUIT, vérifié sur les recettes vanilla 1.1]** Trois écarts :
- `logistic-science-pack` est au rang 4 avec l'`inserter`, son ingrédient (rang 4). La règle dirait 5.
- `stone-furnace` est au rang 2 alors que son seul ingrédient est la pierre (minerai, hors rangs). La règle dirait 1.
- `plastic-bar` est au rang 5 alors que ses ingrédients sont le charbon et le gaz (hors rangs).

D'autres placements ne s'expliquent qu'en comptant les BARILS comme ingrédients :
- `concrete` est au rang 5, après `water-barrel` (rang 4) ;
- `sulfur` est au rang 5 ;
- dans cette usine, les fluides voyagent en barils (§4.6).

**Conséquence** : une table à la main se trompe, même chez son auteur. Chez nous, le rang se CALCULE depuis les recettes (§6, L1).

### 3.3 Ce qui fait passer au rang suivant [LU G l.169-211]
1. Pour chaque rang i, de 1 à 10, on cherche les objets du rang dont le signal est négatif (en manque). On garde le plus négatif,
   la comparaison stricte `<` donnant la victoire au PREMIER de la liste en cas d'égalité.
2. **Anti-répétition** : l'objet dont on vient de poser la tuile (`lastSignal`) est sauté. S'il est le SEUL en manque du rang,
   on le reprend quand même (`check_again`, l.191-204). Le commentaire dit : « We do not want to start checking higher tiers,
   since they might depend on this item. »
3. **Un rang qui a un manque ARRÊTE la recherche** : on ne regarde jamais les rangs supérieurs tant qu'un rang inférieur manque
   de quelque chose. On ne passe au rang i + 1 que si AUCUN objet du rang i n'est en manque.
4. Si aucun rang n'a de manque, on passe aux autres branches : recherche, petite centrale, minuteur (§4.3).

### 3.4 Comment les besoins remontent [LU V 3:28-4:21 ; G l.2-3]
- Rien n'est CALCULÉ en amont : le besoin remonte PHYSIQUEMENT. Une tuile posée demande une minute de ses ingrédients ; ce qui
  lui manque devient un nombre négatif sur le réseau.
- Une tuile de circuits verts qui n'a pas de câble crée donc la demande de câble. La tuile de câble crée à son tour la demande
  de cuivre si le cuivre manque. Et ainsi de suite.
- **[DÉDUIT]** Le fil additionne le stock du réseau (+) et les manques (−). Un manque n'apparaît que s'il dépasse ce que le
  réseau contient déjà : c'est un manque NET.
- **[LU V 11:09-11:15]** Le transit est compté.

### 3.5 Recalcul quand la demande change
- **Aucun plan n'est gardé.** Chaque passage (60 à 120 ticks) relit les signaux et refait le choix. Le seul état est `var` :
  compteur de tuiles, dernier plan posé, drapeaux, minuteur [LU G l.213-238].
- **[LU G l.240-243, l.556-557]** La demande ne change la décision qu'APRÈS confirmation de la pose précédente. Le compteur interne
  `tilesBuilt` n'avance que si le déployeur était libre, et une nouvelle mégatuile attend que le compteur de mégatuiles publié par
  le réseau rattrape le compteur interne.
- **[LU G l.36-42]** Entre deux tuiles, la porte « robots de construction occupés » laisse le temps à la tuile posée de
  commencer à tourner et à sa demande d'apparaître.
- **[DÉDUIT]** Le retard entre la pose et l'effet sur le signal est le danger : on reposerait la même tuile. Deux protections
  existent : l'anti-répétition (§3.3, point 2) et la petite taille de l'unité (M50).

### 3.6 Ce que notre code a DÉJÀ, et ce qui manque [LU N]
| Idée de la vidéo | Chez nous (lu) | Ce qui diffère |
|---|---|---|
| Rang = 1 + rang max des ingrédients | `Ca.requirements` calcule `depth[i]` = 1 + max des profondeurs des ingrédients, sur la recette choisie (`shared/ai3/capitalisation.lua:764-783`), à CHAQUE appel. Un cycle est coupé par `depth[i] = 0` à la première visite (l.769). | Calculée seulement sur les objets demandés, refaite à chaque tour de la décision (jusqu'à 1 + 24 fois, l.1958 et 2002). |
| Plus bas rang d'abord | `Ca.before` trie les options par retour `Tq` D'ABORD, puis par `depth`, puis par clé (l.1784-1788). `Ca.SCARCE_FIRST` réordonne ensuite par bande de pénurie (l.1818-1829). | Le rang ne départage qu'à retour égal. Une option haute et rentable passe devant une option basse. |
| « Le rang inférieur d'abord » pour une chaîne | Goulot amont : une chaîne attend tant qu'un ingrédient FABRIQUÉ direct est couvert à moins de `Ca.THETA_MIN` = 900 ‰ (l.103, 1629-1637). | Ingrédients directs fabriqués seulement ; le minerai est traité par `fed_max`. Ce n'est pas une porte par rang. |
| Ne pas retenir de place pour ce qui attend | `Ca.blocked_items` (l.1862) et `emplacements.lua` : 8 règles accumulées (attente de matière, figé, stock riche, pile, mall, complément, manque). | **[DÉDUIT]** Ces 8 règles soignent le symptôme « des ordres attendent leur matière en tenant une place ». La vidéo ne l'a pas, parce qu'elle ne décide un objet que si aucun rang inférieur ne manque. |
| Manque mesuré, transit compris | La capitalisation a des « puits mesurés » (en-tête l.24) et lit `flows.made` / `flows.hand` (l.1940) ; la capacité `plan.N` compte les machines POSÉES. | Le manque d'entrée de chaque module posé n'est pas lu. **[LU W §2, §5 D1, D2]** La vue ne voit pas les coffres de sortie du plan directeur : du fer produit n'existe pas pour le cerveau. |
| Une unité par décision | `Ca.MAX_ORDERS` = 24 nouveaux ordres par cycle (l.147) ; une chaîne au plus `Ca.CHAIN_MAX` = 4 machines d'avance (l.123) ; `Ca.LEAD` = 2 (l.125). | **[DÉDUIT]** Plus de pose par décision, et donc plus de risque de pic d'amont (M50). |

### 3.7 « Tiers dynamiques » : la version pour nos 15 âges [DÉDUIT]
1. **Le rang se calcule**, il ne s'écrit pas :
   - rang(ressource) = 0 ;
   - rang(objet) = min sur ses recettes OUVERTES et faisables de (1 + max des rangs des ingrédients) ;
   - même définition que `depth`, mais sur TOUT le livre de la force et avec une gestion juste des cycles : plus petit point fixe,
     comme `evaluate_feas` dans `shared/ai3/graphe.lua:211-236`.
2. **Dynamique pour trois raisons** :
   - il change quand une recherche ouvre une recette (un objet fait à la main, puis en machine avec d'autres ingrédients, change
     de rang) ;
   - il est PAR FORCE (chaque faction a son livre et son âge) ;
   - le nombre de rangs n'est pas fixé : il dépend des recettes des 15 âges.
3. **La porte est ciblée** : la vidéo bloque TOUS les rangs supérieurs dès qu'un rang inférieur manque, parce qu'ils « might
   depend on this item ». Nous connaissons le graphe : nous ne bloquons que les objets qui DÉPENDENT, même indirectement, d'un
   objet en manque de rang inférieur. Une chaîne indépendante peut continuer.
4. **Un manque sans issue ne bloque rien** : pas de recette, pas de machine, ressource inconnue. C'est la règle « BLOQUÉ » de la
   pile (`shared/ai3/pile.lua` l.29-31) : « un siège sans issue ne gèle rien ».

---

## 4. L'algorithme complet (G), branche par branche

### 4.1 Entrées et sorties [LU G l.1-16, l.27-34]

**Entrées (fil rouge) :**
- `red[objet]` : stock du réseau, négatif en manque ;
- `signal-info` : nombre de mégatuiles ;
- `signal-dot` : nombre de tuiles de recherche ;
- `A` et `B` : robots logistiques libres et total ;
- `C` et `D` : robots de construction libres et total ;
- `E` : charge des accumulateurs.

**Entrées (fil vert) :**
- `green[minerai]` : ce que le scanner a vu ;
- `green['construction-robot']` et `green['signal-P']` : sa propre sortie, en retour.

**Sorties :**
- vers le scanner (rouge) : X, Y, W, H de la zone à sonder ;
- vers le déployeur (vert) : `construction-robot` = numéro du plan, puis X, Y ;
- `signal-check` vaut 1 quand le moment est bon « for construction and research » (l.13-14). **[DÉDUIT]** Quelque chose dans
  l'usine coupe donc la RECHERCHE en cas de choc logistique, pour rendre le transport à la construction.

### 4.2 Portes [LU G l.36-57]

| Porte | Ferme si | Ligne |
|---|---|---|
| constructeurs occupés | occupés > mégatuiles ÷ 25 + 1. Commentaire : « We wait less the larger the factory is, since overproduction in the late game is less catastrophic. » | 36-42 |
| choc logistique | libres < total ÷ 10 | 43-44 |
| choc de construction | total < 300 (« only in biter runs ») | 45-46 |
| énergie (pour le choix, pas pour la porte) | entrée en crise sous 40 %, sortie au-dessus de 50 % ; `need_power` reste vrai jusqu'à la pose d'une mégatuile d'énergie (« keep building power megatiles even if the power situation has temporarily recovered ») | 48-53 |
| plafond | 484 mégatuiles | 17, 240 |

Si une porte se ferme, la sonde en cours est jetée (`is_surveying = false`, l.568-570) et sera refaite.

### 4.3 Arbre de décision [LU G]

**Mégatuile (l.290-353).** Elle se décide quand `tilesBuilt % 8 == 0` et `tilesBuilt / 8 >= mégatuiles` (l.242-243). On teste
dans cet ordre :
1. un chantier est en cours (déployeur ≠ 0, et pas le plan 109 de défrichage) : on le continue ;
2. c'est la 1re mégatuile : nucléaire (106) ;
3. la sonde voit de l'uranium > 100 000, ou une somme de 5 minerais > 1 000 000 : mégatuile vide (1), même en crise d'énergie ;
4. `need_power` est vrai :
   - nucléaire si les 4 conditions sont vraies : plus de 10 mégatuiles, plus de 90 cellules, plus de 3 réacteurs au réseau (ou
     coffres infinis), et la mégatuile précédente n'était pas nucléaire (commentaire « last 2 megatiles », code
     `>= last + 1` : écart entre le commentaire et le code) ;
   - sinon solaire (2) ;
   - dans les deux cas, `need_power = false` et `tilesBuilt += 8` ;
5. moins de 9 mégatuiles : solaire ;
6. baril de gaz, d'huile légère ou d'huile lourde en manque, et la précédente n'était pas du pétrole (110) : pétrole ;
7. sinon : vide (1).

En plus, le drapeau d'artillerie se lève au-delà de 36 mégatuiles, à un coin de la spirale (l.388-389).

**Tuile (l.436-512).** On teste dans cet ordre :
1. le déployeur porte encore un plan : on refait LE MÊME ;
2. uranium sondé > 100 000 et réseau < 100 000 : tuile d'uranium (54) ;
3. fer, cuivre ou charbon sondé > 100 000 et réseau < 250 000 (pierre : 200 000) : tuile de minage (53) du minerai le plus
   abondant à cet endroit ;
4. drapeau d'artillerie levé : tuile d'artillerie (114), puis le drapeau retombe ;
5. rangs (§3.3) : la tuile de l'objet choisi ;
6. moins de 25 tuiles de recherche et minuteur échu : tuile de recherche (9) ;
7. crise d'énergie : petite centrale (108) ;
8. moins de 25 tuiles de recherche et aucun minuteur : minuteur = maintenant + 18 000 ticks (5 min) ;
9. **validation** : si le déployeur était libre et qu'un plan est choisi, alors `tilesBuilt += 1` et le minuteur de recherche est
   ANNULÉ (l.556-565) ; puis `delay = 120`.

### 4.4 Géométrie [LU G l.246-271, 273, 402-433, 545 ; DÉDUIT par déroulé de la boucle]
- Une spirale carrée de mégatuiles de 48 tuiles de jeu autour de la racine.
- Dans une mégatuile, les 8 tuiles de 16 entourent la case centrale (roboport et tourelles laser : icônes de l.307 et l.351).
- La sonde lit 30 × 30 pour une mégatuile et 10 × 10 pour une tuile. Le défrichage (plan 109) couvre 50 × 50 au moment de la
  sonde d'une mégatuile.

### 4.5 Trace [LU G l.284-285, 433, 482-485, 549-555]
- Une ligne `game.print` par décision.
- Une étiquette de carte par tuile, avec l'icône du produit, posée par `_api` (`add_chart_tag`).

### 4.6 Mise en place et triches [LU S ; D ; V]
- **Mise en place** : `research_all_technologies`, `game.speed = 100`, joueur en mode triche, mode « sans biters » au choix.
- **Triches** :
  - coffres infinis : mall, minerai, modules de niveau 3 ;
  - eau infinie ;
  - amorce par barils d'huile lourde.
- **Fluides** : ils voyagent en barils, d'où les signaux `*-barrel` de G.

---

## 5. Notre IA de faction : le workflow global (résumé de W ; lire W en entier avant de coder)

**Rythme [LU W §1] :**
- ordonnanceur à chaque tick ;
- pensée d'un PNJ toutes les 60 ticks ;
- passe du plan directeur toutes les 5 ticks ;
- PENSÉE D'ÉQUIPE toutes les 300 ticks, en 4 étapes :
  - E1 (T) : vue, plan, tableau, fond ;
  - E2 (T+1) : plan directeur ;
  - E3 (T+2) : réparations ;
  - E4 (T+3) : marché et paiements, sur une COPIE de la vue de T ;
- capitalisation et automatisation une fois par minute.

**Chaîne [LU W §2]** : vue (`script/team/team.lua:462`) → cerveau IA3 (`script/ai3/cerveau.lua:778` →
`shared/ai3/cerveau.lua:198`) → plan directeur (`script/team/build.lua:4846`) → tableau (`script/team/board.lua:323`) → marché
(`board.lua:766`) → PNJ (`script/team/worker.lua:431`) → effets → vue suivante.

**Où brancher une règle neuve [LU W §7, recommandation de carte-ia] :**
- **quoi construire, à quel débit, quand grandir** (tiers dynamiques compris) : dans la capitalisation, `Ca.decide`
  (`shared/ai3/capitalisation.lua:1954`), décideur unique des fonderies, des chaînes et des labos
  (`script/ai3/capitalisation.lua:25-32`) ;
- **comment le bâtir** : plan directeur (`Build.request` `build.lua:569`, `spec.gen` 600-607, `Build.SITES` 109,
  `Build.ligne_step` 1949) ;
- **ce qui manque pour le bâtir** : les buts `auto:` et `capi:` du cerveau (`Ca.goals` l.2057, `P.emit`, `P.supply`) ;
- **travail permanent** : planificateur `P.plan` (`shared/team/planner.lua:239`).

**Pièges [LU W] :**
- la vue ne voit pas les coffres de sortie du plan directeur (`script/faction/outposts.lua:838-849`) ;
- les collectes et les quais ne sont servis que pour un projet « fini » ou « chantier » (`build.lua:4870`) ;
- E4 paie sur un coffre qui a bougé depuis T ;
- 16 gardes de pause (W §4) ;
- 4 défauts ouverts dans la partie du DC, D1 à D4 (W §5).

**Correspondance des notions :**

| Vidéo | Chez nous |
|---|---|
| robots de construction | PNJ (bras), 4 à 30 par équipe |
| robots logistiques | tournées de PNJ, puis tapis |
| réseau logistique (stock + transit) | coffre du QG et annexes, registre des réservations, inventaires des PNJ |
| tuile | module (cellule, rangée, bloc de mall) dans un lot de 24 × 24 |
| mégatuile | quartier de lots du treillis (`shared/team/plan.lua` l.5-13) |
| déployeur | `Build.request` |
| plan du livre | gabarit `spec.gen` / `Build.SITES` |
| sonde | relevé du lot par le plan directeur |

---

## 6. Implémentation chez nous : lots, règles pures, runtime, tests, coût

**Règles communes à tous les lots :**
- Lua PUR dans `shared/` (aucune API, aucun nom du jeu : test anti-échelle `tests/iag_test.lua` §8) ;
- listes triées, pas de `pairs` décisionnel, entiers en ‰, ticks de jeu, jamais d'horloge ;
- le runtime (`script/`) ne fait que lire le monde et appliquer ;
- preuve : tests hors jeu, puis micro-banc de moins de 2 500 ticks par la file, puis 3 graines pour toute règle qui change une
  décision (`REPRISE.md` l.49, F252) ;
- coût mesuré en INSTRUCTIONS (`debug.sethook`, comme `tests/champ_tranches_test.lua`, `counted_steps`). Pour situer : 8 à 44 ns
  par instruction hors jeu selon la charge (mémoire « coût Lua en instructions »), donc 10⁵ instructions = 0,8 à 4,4 ms. Les
  budgets donnés ici sont **[DÉDUIT]** et à mesurer avant fusion ;
- compatibilité avec le découpage en cours :
  - pensée en 4 étapes (`fo-logs/2026-11-07_DECOUPAGE-PENSEE`) ;
  - décision de capitalisation reprenable en tranches (`fo-logs/2026-11-07_CAPI-DECIDE`) : tout calcul ajouté à `Ca.decide` se
    fait DANS une unité et ne lit que l'instantané ;
  - un cache en mémoire de module porte une clé (force, génération du livre) et est jeté s'il ne correspond pas.

### L0. Mesures préalables (rien ne change dans le jeu) — taille S
- **H-VID-1** :
  - question : combien d'ordres `Ca.decide` émet-il par décision, contre combien de chantiers vraiment commencés ? Et combien
    d'ordres attendent leur matière en tenant une place ?
  - lecture : lignes `[FO-CAPI]` et états des projets du plan directeur, sur la partie du DC (`fo-logs/2026-11-07_PARTIE-DC-0658`)
    ou au moteur simulé.
- **H-VID-2** :
  - question : quand une chaîne de N machines est posée, quel appel d'amont crée-t-elle (fer demandé dans les 10 min suivantes) ?
    La capacité à 2 fois la demande (`Ca.LEAD`, `Ml.LEAD`, `Id.LEAD`) crée-t-elle les pics de M50 ?
- **H-VID-3** :
  - question : quelle part des instructions de `Ca.decide` va aux appels de `Ca.requirements` (1 + nombre d'ordres) ?
  - but : chiffrer ce que rapporterait L1b.
- **Coût** : nul en jeu (lecture de journaux, moteur simulé).

### L1. RANG calculé (tiers dynamiques) — M09, M10, M12, M13, M30 — taille S à M

**Module cible** : nouveau fichier `shared/ai3/rang.lua`, lu par la capitalisation (`Ca.requirements` l.752, `Ca.before` l.1784)
et par l'automatisation.

**Règle pure `Rg.build(D, open, opts)`** :
- **entrées** :
  - `D` = relevé de `Ca.data` : `recipes`, `producers`, `res`, `hand`, catégories ;
  - `open(rn)` = recette ouverte pour la force (même prédicat que `Ca.recipe_open`) ;
  - `opts.fluids` = les fluides comptent comme des objets (rang de la recette qui les produit ; l'eau pompée est au rang 0).
- **sorties** :
  - `rank[objet]` (entier ≥ 0) ;
  - `tiers[k]` = liste triée des objets du rang k ;
  - `cyc[objet]` = vrai pour un objet qui n'a de rang que par un cycle (recette qui consomme son produit, comme l'amorce
    d'huile lourde de M30) ;
  - `seed[objet]` = quantité d'amorce nécessaire (ingrédient du cycle).
- **calcul** : plus petit point fixe de type Jacobi, rang par rang, sans récursion :
  - passe k : un objet sans rang reçoit le rang k si une de ses recettes ouvertes a tous ses ingrédients classés à des rangs
    strictement inférieurs à k ;
  - itération sur `D.recipe_list` triée ;
  - arrêt quand une passe ne classe rien, ou à `Rg.MAX` passes.
  - Les objets restés sans rang sont soit des cycles (marqués `cyc`, rang = 1 + max des ingrédients classés), soit impayables.
- **invariants testés** :
  - (I1) pour toute recette retenue r d'un objet i, rang(ingrédient) < rang(i), sauf `cyc` ;
  - (I2) rang des ressources = 0 ;
  - (I3) déterministe : même sortie quel que soit l'ordre d'insertion des tables ;
  - (I4) aucun nom du jeu dans le fichier ;
  - (I5) une recette ouverte en plus ne fait jamais MONTER un rang (le min ne peut que baisser).

**Runtime** :
- calcul paresseux à la première décision qui en a besoin, gardé en mémoire de module avec la clé (force, génération du livre) ;
- la génération change à `on_research_finished`, `on_research_reversed`, `on_technology_effects_reset`, `on_force_reset` et
  `on_configuration_changed`, comme le livre de recettes (ARCHITECTURE §5) ;
- rien dans `global`, sauf peut-être la génération (un nombre) ;
- une ligne `[FO-RANG]` par recalcul : nombre de rangs, objets par rang, cycles.

**L1b (perf, même lot)** : remplacer, dans `Ca.requirements`, le parcours `visit` qui recalcule `depth` à chaque appel
(l.764-788) par `rank`.
- A/B octet à octet attendu tant que les objets demandés ne forment pas de cycle. Avec un cycle, `depth` vaut aujourd'hui 0 à la
  re-visite (l.769) : écart attendu, à écrire tel quel.
- Gain : la récursion et deux tris, sur 1 + nombre d'ordres appels par décision (à chiffrer par H-VID-3).

**Tests** : `tests/rang_test.lua` :
- (a) vanilla, d'après le relevé `harness.lua … --dump-recipes` (la fixture `recipes_ia1e.lua` est périmée : 839 recettes contre
  1 189, `REPRISE.md` l.16). Valeurs attendues : plaques 1, engrenage 2, câble 2, circuit vert 3, bras 4, pack logistique 5
  (et non 4 comme la table de l'auteur, §3.2) ;
- (b) cycle synthétique (A depuis B, B depuis A, plus une recette de départ) ;
- (c) recette qui consomme son produit (amorce) ;
- (d) recette ouverte par une recherche : le rang change, la génération est invalidée ;
- (e) relevé du mod sur les 15 âges : nombre de rangs écrit, aucun objet fabricable sans rang hors `cyc` ;
- (f) mesure des instructions.

**Mutants** (chacun doit faire échouer un test) :
1. rang = max au lieu de 1 + max ;
2. fluides ignorés ;
3. cycle non traité (récursion sans garde) ;
4. cache non invalidé après une recherche ;
5. itération par `pairs` (le test permute l'ordre d'insertion) ;
6. min remplacé par « première recette ».

**Coût [DÉDUIT]** :
- construction : passes × (recettes + ingrédients). Avec environ 1 200 recettes, environ 4 000 arêtes et 10 à 25 rangs : quelques
  10⁵ à 10⁶ instructions, une fois par recherche finie et par force ;
- si une mesure dépasse le budget d'une tranche : découper par passes (une passe par tick) ;
- consultation : O(1).

### L2. PORTE DE RANG dans la capitalisation : « le plus bas rang en manque d'abord » — M12, M14, M15, M23 — taille M
**Dépend de L1.**

**Module cible** :
- `Ca.decide` (`shared/ai3/capitalisation.lua:1954`), dans la boucle des ordres (l.1973-2003) ;
- `Ca.before` (l.1784) ;
- `fabric_options` (l.1571 ; goulot amont l.1629-1637) ;
- répercussion sur `shared/ai3/emplacements.lua` (`Em.order_seat`).

**Règle pure `Rg.gate(rank, req, plan, ctx_def)`**, appelée par `Ca.options` :
- **entrées** :
  - `rank` (L1) ;
  - `req` (`Ca.requirements` : `R`, `list`, `rec`) ;
  - `plan.N`, `plan.hand`, `ctx.stock` ;
  - les refus « sans issue » du tour : aucune recette, aucune machine, `executant :`, explore.
- **calcul** :
  - `Def` = objets dont le manque `R − N − main − stock ÷ H_STOCK` > 0 et qui ont AU MOINS une option possible ;
  - `r*` = rang minimal de `Def` ;
  - `taint[i]` = vrai si une recette retenue de i a un ingrédient dans `Def` de rang < rang(i), ou un ingrédient « taint » ;
    propagé dans l'ordre croissant des rangs, en une passe.
- **sorties** :
  - `deferred[i]` = vrai pour une option de fabrication d'un objet « taint » (refus écrit : « rang : <ingrédient> (rang k)
    d'abord ») ;
  - clé de tri par bande de rang.
- **politique proposée** :
  - (P1) les options d'un objet « taint » sont différées ;
  - (P2) le tri devient (rang croissant, puis `Tq`, puis clé) À L'INTÉRIEUR des options de fabrication et d'extraction. Les
    laboratoires, le courant et les leviers gardent leur place, comme `SCARCE_FIRST` aujourd'hui ;
  - (P3) l'extraction d'une ressource (rang 0) dont dépend un objet de `Def` passe devant ;
  - (P4) R0 et R1 de la pile ne sont jamais concernés.
- **invariants** :
  - (I1) aucune option différée ne dépend d'un objet sans issue (un manque bloqué ne gèle rien) ;
  - (I2) une option indépendante de `Def` n'est jamais différée ;
  - (I3) quand `Def` est vide, résultat identique à aujourd'hui (A/B octet à octet).

**Ce que la règle doit changer [DÉDUIT, à prouver]** : un module qui attend du fer n'est plus décidé tant que le fer est en
manque avec une option possible. Il ne tient donc plus de place.
- Mesure attendue au journal : les refus « plan directeur occupe » et les ordres « attente de matière » de `emplacements.lua`
  (règles 1, 5, 8) baissent.
- On ne retire AUCUNE des 8 règles avant cette mesure.

**Runtime** : aucun ; tout est dans `shared/`. Le journal `[FO-CAPI]` écrit `r*` et les ordres différés.

**Tests** : extension de `tests/ai3_capitalisation_test.lua` :
- (a) le cas mesuré de l'EFFONDREMENT (`emplacements.lua` en-tête, règle 8) : fer en manque avec une foreuse possible, module
  de rang plus haut qui attend du fer → module différé, foreuse décidée ;
- (b) chaîne indépendante (sans fer) décidée dans le même cycle ;
- (c) fer en manque sans gisement connu → rien n'est différé, l'exploration est émise ;
- (d) A/B sans manque ;
- (e) 3 graines au moteur simulé : âge atteint, fer, morts, au bruit près.

**Mutants** :
1. porte globale (tout rang supérieur bloqué, comme la vidéo) → (b) échoue ;
2. porte supprimée → (a) échoue ;
3. manque sans issue qui bloque → (c) échoue ;
4. tri `Tq` d'abord conservé → (a) échoue quand l'option haute est plus rentable ;
5. « taint » limité aux ingrédients directs → cas à deux étages échoue.

**Coût [DÉDUIT]** :
- une passe O(|`req.list`| + arêtes) par appel de `Ca.options` : de l'ordre de 10⁴ instructions pour 200 objets demandés ;
- jusqu'à 25 appels par décision ; à recalculer seulement quand l'ordre choisi touche `Def` ;
- borne : moins de 5 % des instructions actuelles de `Ca.options`, à vérifier par sethook.

### L3. MANQUE MESURÉ au module, transit compris — M11, M20, M22, M23, M41, M51 — taille M

**Module cible** :
- puits mesurés de la capitalisation (`input.sinks`, `Ca.requirements` l.756) ;
- vue (`Team.view`, `team.lua:462`) pour la lecture ;
- répare en partie le piège « la vue ne voit pas les coffres de sortie du plan directeur » (W §2, D1).

**Règle pure `Mq.step(mods, transit, stock)`** (nouveau `shared/ai3/manque_local.lua`) :
- **entrées** :
  - `mods` = liste triée par identifiant de modules posés, chacun avec `{ id, recette, nominal (/min, lu du gabarit), entrees =
    {objet = n dans ses entrées}, sorties = {objet = n}, tourne = vrai/faux }` ;
  - `transit` = `{ [id] = { [objet] = n } }`, depuis les tâches du tableau réservées à ce module et les inventaires des PNJ
    affectés ;
  - `stock` = stock libre (`Board.view_stock`).
- **sorties** :
  - `need[objet]` = Σ max(0, 1 min de nominal − entrées − transit) sur les modules ;
  - `net[objet]` = `need` − stock libre − Σ sorties disponibles : positif = manque, comme le signal négatif de la vidéo ;
  - `starved` = modules dont une entrée est à 0 avec un manque ;
  - `avail[objet]` = Σ sorties des modules (ce que la vue ne voit pas aujourd'hui).
- **invariants** :
  - (I1) un objet en transit vers un module n'est jamais compté deux fois (registre strict) ;
  - (I2) `need` ≥ 0 ;
  - (I3) déterministe ;
  - (I4) un module à l'arrêt faute de courant n'a pas de manque d'entrée ; c'est un manque de COURANT, écrit à part.

**Runtime** :
- en E1, lecture de `get_inventory` / `get_item_count` des entrées et des sorties des modules du plan directeur ;
- par tranche bornée : au plus `Mq.READ` = 32 modules par pensée, en tourniquet sur la liste triée (curseur dans `global`, un
  nombre) ;
- un module non relu garde sa dernière lecture et son âge. L'âge entre dans la sortie, pour ne pas décider sur une lecture trop
  vieille.

**Branchement** :
- `net` entre dans `ctx.sinks` comme puits mesuré, ce qui remplace `need ÷ H_GOALS` pour les objets couverts par des modules ;
- `avail` entre dans la vue.

**Tests** : `tests/manque_local_test.lua` :
- (a) un module de circuits sans câble → manque de câble = 1 min de nominal ;
- (b) câble en route → manque réduit d'autant ;
- (c) câble au stock libre → manque net nul ;
- (d) sorties pleines → comptées dans `avail` ;
- (e) tourniquet : 100 modules lus en 4 pensées, ordre stable après sauvegarde et chargement (moteur simulé).

**Mutants** :
1. transit ignoré (double livraison) ;
2. sorties ignorées (D1 reste) ;
3. lecture par `pairs` ;
4. module sans courant compté comme affamé.

**Coût [DÉDUIT]** :
- 32 modules × (2 à 8 inventaires) = au plus 256 appels moteur, plus l'agrégation, par pensée ;
- de l'ordre de 2 à 3 × 10⁴ instructions de Lua, plus les appels C ;
- à mesurer au moteur réel par micro-banc (les appels C ne se comptent pas en instructions).

### L4. QUOTAS DANS LE GABARIT — M18, M19, M21, M55 (fin) — taille M

**Module cible** :
- `shared/team/patrons.lua` (barre du coffre de sortie) ;
- plan directeur, tâches de quai et d'alimentation (`build.lua:3925-3983`, `keep_stock` 3904-3911) ;
- tableau (`board.lua:398`).

**Règle pure `Pt.quotas(gabarit, nominal, opts)`** :
- **sorties** :
  - `bar_out` = ⌈N_SORTIE minutes × nominal⌉ cases (F95 : la barre limite aussi `insert`) ;
  - `want_in[objet]` = 1 min de consommation nominale ;
  - `feed_ok` = faux si les sorties dépassent `bar_out` × 90 %.
- **invariants** :
  - (I1) calculés depuis les débits lus (jamais une constante par bâtiment : M55, une table figée coûte une refonte) ;
  - (I2) `want_in` ≤ capacité de l'entrée ;
  - (I3) déterministe.

**Runtime** :
- la barre se pose au moment de la pose ;
- en E2, une tournée d'ALIMENTATION vers un module dont `feed_ok` est faux n'est pas émise. C'est M21 : un module plein n'avale
  pas d'ingrédients, qui restent pour les autres ;
- cela touche le défaut D2 de W (fours « sortie pleine »).

**Tests** :
- quotas pour 3 recettes à débits différents ;
- pas de tournée d'alimentation vers une sortie pleine ;
- la tournée de COLLECTE reste émise (sinon interblocage) ;
- **mutants** :
  1. alimentation gardée quand la sortie est pleine ;
  2. barre constante ;
  3. collecte bloquée par `feed_ok`.

**Coût** : O(entrées) par module et par pensée, déjà parcouru par `Build.think` : quelques centaines d'instructions par module.

### L5. CONFIRMATION OBSERVÉE : la capacité ne compte qu'après la première production — M38, M47, G l.219-225 — taille M

**Module cible** :
- entrée `machines` de `Ca.decide` (l.1941) ;
- capacité `plan.N` ;
- états des projets du plan directeur (`advance`, `build.lua:4098`) ;
- `emplacements.lua` (règles 1 et 2).

**Règle pure `Cf.capacity(projets, mesures)`** :
- un module passe à l'état « confirmé » à sa PREMIÈRE production mesurée (sortie qui augmente, ou statistique de production de
  la force) ;
- `N` ne compte que les modules confirmés ;
- les modules posés mais non confirmés comptent en « ordre ouvert » (`n_left`), pas en capacité ;
- un chantier qui reste incomplet au-delà de `Cf.STALL` (comme `Em.STALL`) rend une cause écrite : courant, entrée, place, danger.
  Il n'est jamais compté comme capacité. C'est M47 : « no way to detect or fix », alors que nous POUVONS détecter.
- **invariants** :
  - (I1) une machine jamais nourrie ne masque jamais un manque ;
  - (I2) une nouvelle décision sur le même objet ne part pas tant qu'un ordre posé n'est ni confirmé ni en échec (compteur
    d'intention contre observation : l'analogue de `tilesBuilt`) ;
  - (I3) un ordre en échec a TOUJOURS une issue : annulé à `Capi.ORDER_TTL` ou rouvert ailleurs.

**Runtime** : lecture de la sortie au moment de la lecture de L3 ; ou, sans L3, des compteurs de production (F242 :
`get_input_count`, et non la moyenne par minute).

**Tests** :
- module posé sans courant : pas de capacité, cause « courant » ;
- module posé et nourri : confirmé à la 1re production ;
- pas de second ordre pendant l'attente ;
- **mutants** :
  1. capacité comptée à la pose ;
  2. ordre bloqué sans issue ;
  3. second ordre émis pendant l'attente.

**Coût** : O(modules) par minute, moins de 10⁴ instructions.

### L6. PETITES MARCHES ET PORTES DE CROISSANCE — M48, M50, G l.36-46, l.181-189 — taille S

**Module cible** :
- `Ca.decide` (l.1973 : nombre de tours ; `Ca.MAX_ORDERS` l.147 ; `Ca.CHAIN_LEAD` l.124) ;
- `Dm.slots` (`shared/ai3/demande.lua`) ;
- `Ex.guard` (`shared/ai3/extension.lua`).

**Règle pure** :
- **(a) une unité par objet et par décision** quand l'objet vient d'un manque MESURÉ (L3) : au plus 1 cellule de plus par objet
  et par cycle, puis on attend la remesure. Cela reste compatible avec `Ca.LEAD` pour la demande calculée ;
- **(b) porte des bras à seuil croissant** : nouveaux chantiers seulement si les bras occupés au chantier ≤ ⌊modules ÷ 25⌋ + 1
  (G l.40-42), ou l'équivalent dans `Dm.slots` (déjà « selon les bras libres ») ;
- **(c) porte de transport** : si moins de 10 % des PNJ sont libres pendant 2 pensées de suite, ou si les tâches libres dépassent
  k × PNJ, aucun nouveau chantier qui ajoute des tournées (un tapis reste permis). C'est l'équivalent du « choc logistique » ;
  **[DÉDUIT]** cela touche D1 de W (« 0 PNJ libre, 16 tâches libres ») ;
- **(d) anti-répétition** sur un signal mesuré : pas deux décisions de suite sur le même objet, sauf s'il est le seul en manque
  de son rang.
- **invariants** :
  - (I1) jamais plus d'ordres par cycle que de chantiers que les bras peuvent commencer (H-VID-1) ;
  - (I2) R0 et R1 jamais bloqués par ces portes.

**Tests** : chaque porte isolée, avec ses seuils lus en ‰ entiers. **Mutants** : chaque porte retirée, puis seuil fixe à la place
du seuil croissant.

**Coût** : O(1) par décision.

### L7. AMORCE ET RETRAIT — M35 à M39, M37 — taille S

**Module cible** :
- mall (`Ml.decide`, `shared/ai3/mall.lua:98` ; `Ml.hand_allowed`, en-tête l.18) ;
- plan directeur (file des demandes `Build.request`).

**Règle pure** :
- **(a) graine** : la liste de matériel des K prochains projets du plan directeur (bâtiments à poser) entre comme demande de
  départ (`Ml.want`), sans attendre 3 épisodes de fabrication à la main (`Ml.MIN_EPISODES`) ;
- **(b) retrait** : `Ml.hand_allowed` refuse déjà la main quand le mall tourne. Le passage à « tourne » se fait à la PREMIÈRE
  production (M38, via L5) ;
- **(c) compteur d'amorce** : cumul par objet de ce que la main a fourni avant que le mall tourne (M39). Ligne `[FO-AMORCE]`
  par objet au retrait ; c'est ce qui dimensionne un kit de départ réel (C, réponse sur les coffres infinis).
- **invariants** :
  - la graine ne dépasse jamais la liste de matériel ;
  - la main n'est jamais refusée à stock nul (déjà dans `mall.lua` l.18).

**Tests** : graine présente au 1er cycle ; retrait à la 1re production ; compteur. **Mutants** : graine absente ; retrait à la
pose ; compteur remis à zéro.

**Coût** : O(projets × objets) par minute.

### L8. LOT PRÊT AVANT L'ORDRE — M17, M47 — taille M

**Module cible** :
- plan directeur : classement des lots (`shared/team/plan.lua`), défrichage (`Build.think` E2), états `defrichage`, `fantomes`,
  `chantier` ;
- `emplacements.lua` (règle 2, module figé).

**Règle** :
- un lot du quartier est préparé AVANT qu'un module y soit commandé : défriché, sans ennemi dans un rayon donné, relié au courant,
  sous sa cible de tourelles ;
- l'ordre de module ne prend un emplacement que sur un lot prêt. C'est la mégatuile vide de M17 : l'enveloppe d'abord, les
  modules ensuite ;
- **[DÉDUIT]** cela vise le module « bloqué en défrichage 74 min » de l'en-tête d'`emplacements.lua`.

**Tests** :
- un lot non défriché ne reçoit pas d'ordre ;
- un défrichage borné rend une cause d'échec ;
- **mutants** :
  1. ordre sur un lot non prêt ;
  2. défrichage sans borne.

**Coût** : déjà payé par le plan directeur ; l'état « prêt » coûte O(1) par lot.

### L9. SONDER AVANT DE DÉCIDER, MINERAI D'ABORD — M33, M34, G l.244-286, l.303-308 — taille S
**Module cible** : classement des lots (`shared/team/plan.lua`, lots « gisement » : l.9-11, `P.MIN_RES_TILES` l.42).

**Règle** :
- un lot qui porte une ressource est réservé à l'extraction et à la fonte. Aucun autre module n'y est posé, même en crise (M33) ;
- le relevé du lot (la sonde) précède la décision. Un relevé jeté quand une porte se ferme est refait (G l.568-570).

**Tests** : le lot à minerai est refusé à une fabrique. **Mutant** : fabrique posée sur le minerai.

**Coût** : O(1) par lot.

### L10. CROISSANCE PAR MARCHES APRÈS STABILITÉ — M40, M41, M43, G l.486-511, l.559-564 — taille S

**Module cible** : demande ouverte C2 (`Dm.step`, `shared/ai3/demande.lua` l.17-35) et puits élastiques de la capitalisation.

**Règle pure `Dm.palier(st, sat)`** :
- quand aucun manque n'existe à aucun rang (L1, L3), qu'il n'y a pas de crise d'énergie (L12) et qu'il y a des bras libres, un
  minuteur de `Dm.PALIER_TICKS` = 18 000 démarre ;
- toute pose l'annule ;
- échu, il ajoute UNE marche au sommet : un laboratoire de plus et ses packs comme puits. Après l'arbre fini, la marche va à
  l'équipement, comme C2 aujourd'hui. La cascade de demande fait ensuite le reste.
- **variante à comparer** à la croissance continue actuelle (+10 % par cycle quand le stock dort), sans la remplacer avant la
  mesure sur 3 graines ;
- **invariants** :
  - (I1) jamais deux marches sans pose entre elles ;
  - (I2) le minuteur compte en ticks de jeu.

**Tests** : minuteur, annulation, marche. **Mutants** : minuteur non annulé ; marche sans condition de stabilité.

**Coût** : O(1).

### L11. TRACE PAR DÉCISION — G l.284, 549-555 ; C (« set map pins for each tile ») — taille S

**Module cible** : runtime de la capitalisation (`script/ai3/capitalisation.lua`, journal `[FO-CAPI]`) et plan directeur à la pose.

**Règle** :
- une ligne de journal par ordre : objet, rang, cause, manque mesuré ;
- une étiquette de carte par module posé, avec l'icône du produit (`force.add_chart_tag`, déjà utilisé par
  `script/world/guarantee.lua`) :
  - derrière un réglage de débogage ;
  - sur la force du JOUEUR pour que le DC la voie (une étiquette appartient à une force) ;
  - **[LU F131]** il faut un chunk cartographié : rien en `--create` et `--benchmark`, seulement en partie avec images ;
  - **[LU doc 1.1.91]** `rendering` n'a pas de mode « carte » : seul `LuaPlayer.render_mode` existe dans `runtime-api.json`.

**Tests** : micro-banc avec images, étiquettes présentes. **Mutant** : étiquette sur la force de la faction (invisible pour le DC).

**Coût** : un appel moteur par module posé.

### L12. HYSTÉRÉSIS ET VERROU DES CRISES — M28, G l.48-53 — taille S

**Module cible** :
- options de courant de la capitalisation (`power_options`, `Ca.options` l.1813 ; entrée `power = { have_kw, used_kw }`) ;
- santé du réseau ;
- pile (`Pi.signals`, `shared/ai3/pile.lua:424`).

**Règle** :
- crise d'énergie à l'entrée sous un seuil bas, à la sortie au-dessus d'un seuil haut ;
- besoin VERROUILLÉ jusqu'à ce que le correctif soit posé ET confirmé (L5) ;
- même revue pour le fer et le danger : aucun seuil unique, aucune levée avant le correctif.

**Tests** : oscillation du signal autour du seuil, pas de bascule. **Mutants** : un seul seuil ; verrou levé à la sortie de crise.

**Coût** : O(1).

### L13. PLAFONDS ET PORTES « FERMÉES PAR DÉFAUT » — V2 0:56-2:36 (« silos sans fin »), G l.17-18 — taille S

**Module cible** : `Ca.decide` (`Ca.OPEN_MAX` l.148 existe ; `Ml.MACHINES_MAX` existe).

**Règle** :
- un plafond par objet de modules ouverts et posés, relatif à la demande mesurée (au plus k × la demande) ;
- toute garde qui lit une entrée ABSENTE se ferme (refus écrit) au lieu de s'ouvrir. Le bug des silos de l'auteur vient d'une
  entrée absente dans une garde.

**Tests** :
- entrée de garde absente → refus ;
- plafond atteint → refus ;
- **mutant** : garde ouverte sur entrée absente.

**Coût** : O(1) par option.

### Lots écartés
Le transport tout robot, les triches, la géométrie en spirale comme règle principale, l'artillerie aux coins, le nucléaire et les
barils (§8).

---

## 7. Ordre d'implémentation, le plus rentable d'abord [DÉDUIT]

| Rang | Lot | Pourquoi d'abord | Taille | Dépend de |
|---|---|---|---|---|
| 1 | L0 mesures | Sans elles, L2 et L6 sont des paris. Rien ne change en jeu. | S | — |
| 2 | L1 et L1b rang | Règle pure, sans effet de décision tant que L2 n'est pas branché ; L1b peut réduire le coût de `Ca.decide`, point chaud du jour. | S à M | — |
| 3 | L2 porte de rang | Seul mécanisme de la vidéo qui attaque une CAUSE déjà mesurée : des modules en attente de fer qui tiennent les places de la foreuse de fer (`emplacements.lua`, règle 8 ; `REPRISE.md` l.22). | M | L1, L0 |
| 4 | L5 confirmation | Une machine posée et non nourrie compte aujourd'hui comme capacité (D1, D2 de W) ; la remplacer par l'observation ferme la boucle. | M | — (mieux avec L3) |
| 5 | L3 manque mesuré | Rend visible le fer des coffres du plan directeur (D1 de W) et donne le vrai signal de la vidéo. | M | — |
| 6 | L6 portes et petites marches | Le « choc logistique » colle à D1 (0 PNJ libre, 16 tâches libres). | S | L0 |
| 7 | L4 quotas du gabarit | Fours « sortie pleine » (D2) ; peu de code. | M | — |
| 8 | L11 trace | Peu cher ; le DC juge sur ce qu'il voit. | S | — |
| 9 | L7 amorce | Presque fait (`Ml.hand_allowed`) ; manque la graine et le compteur. | S | L5 |
| 10 | L10 marches de stabilité | À comparer à C2 ; utile une fois L1 à L3 en place. | S | L1, L3 |
| 11 | L12, L13 | Gardes ; petits. | S | — |
| 12 | L8, L9 | Utiles mais déjà en partie couverts par le plan directeur. | M, S | — |

---

## 8. Ce qu'il ne faut PAS emprunter
- **Les triches** : coffres infinis, eau infinie, recherche entière, `game.speed`, modules tirés d'un coffre. L'auteur triche là où il
  n'a pas su automatiser ; nous ne pouvons pas.
- **« Ajouter des robots » comme réponse au transport.** Nos PNJ sont peu nombreux, lents et mortels (F239, F251). **[DÉDUIT]** Le
  jour où les factions ont un réseau logistique (elles ont des robots depuis 0.6.35, `REPRISE.md` l.56), la mesure « stock moins
  manques, transit compris » devient lisible telle quelle ; avant, il faut la construire (L3).
- **La localité qui émerge de la surconstruction (M52).** Pour des PNJ, la distance tue ; gardons le placement par distance du plan
  directeur.
- **Les rangs écrits à la main.** Contraires à l'anti-échelle, et faux chez l'auteur (§3.2).
- **La porte de rang GLOBALE** : elle bloque des chaînes indépendantes ; la nôtre est ciblée (L2).
- **La défense par la géométrie (M46).** La nôtre suit la menace (pile R0 et R1, `Ex.guard`).
- **Les mods** Moon Logic et Recursive Blueprints : seule l'idée compte, le moteur additionne et le script décide peu.
- **L'apprentissage par renforcement (V2)** : écarté par l'auteur lui-même. Régler des constantes par recherche aveugle est interdit
  (CLAUDE.md §10.3).

## 9. Limites
- Les éléments seulement MONTRÉS ne sont pas couverts (§0).
- Les sous-titres sont automatiques : les nombres DITS peuvent être mal transcrits (500 mégatuiles contre 484 dans le code). Les
  nombres du gist sont exacts.
- Les coûts en instructions du §6 sont des estimations à mesurer.
- Les liens « lot ↔ défaut » sont des hypothèses : L2 contre l'interblocage, L5 et L3 contre D1 et D2, L6 contre la saturation des
  PNJ.
- Le code de référence est celui du worktree `integ-0652b` (0e340b99). Une ligne citée peut avoir bougé sur `main`.

## 10. Sources
- Vidéo : https://www.youtube.com/watch?v=PGiTkkMOfiw ; auteur confirmé par
  https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=PGiTkkMOfiw&format=json (« Chris Uehlinger »,
  https://www.youtube.com/@uehreka). Commentaires : même page.
- Gist : https://gist.github.com/chrisuehlinger/c38fff88b7e429c81c2582430a2c3ab9 ; version brute :
  https://gist.githubusercontent.com/chrisuehlinger/c38fff88b7e429c81c2582430a2c3ab9/raw/the-algorithm.lua (créé le
  19/01/2024, 1 révision, 0 commentaire).
- Vidéo de suite : https://www.youtube.com/watch?v=w2IoMaIrkpo
- Scénario v9 : https://drive.google.com/file/d/1luWUWRxwXrZxq_Rz_JJwvrYaayG9NmsR/view
- Mods :
  - https://mods.factorio.com/mod/recursive-blueprints ;
  - https://mods.factorio.com/mod/Moon_Logic ;
  - https://github.com/mk-fg/games/tree/master/factorio/Moon_Logic
- Profil GitHub de l'auteur, aucun dépôt Factorio visible : https://github.com/chrisuehlinger
- **Citées, NON lues** :
  - https://www.youtube.com/watch?v=xF--1XdcOeM ;
  - https://www.youtube.com/watch?v=oP-jeBaPjmw ;
  - https://www.youtube.com/watch?v=dpLrnf1jWK8 ;
  - https://www.reddit.com/r/technicalfactorio/comments/f3nje7/10k_spm_bot_base/ ;
  - https://www.youtube.com/watch?v=DH3hCy4l4sY ;
  - https://www.youtube.com/watch?v=DcYLT37ImBY
- **Récupération** : yt-dlp installé dans un environnement jetable du dossier temporaire de session :
  - sous-titres : `--skip-download --write-auto-subs --sub-langs en --sub-format json3` ;
  - commentaires : `--write-comments --extractor-args "youtube:max_comments=800,all,100,20;comment_sort=top"`.

## 11. Résumé
1. **Lu en entier** : les deux vidéos (sous-titres automatiques horodatés), le code de l'algorithme (571 lignes), le scénario,
   34 réponses de l'auteur.
2. **Pas vu** : les images. Ce qui est seulement montré manque, et le contenu exact des plans de tuiles aussi.
3. **La logique globale, solide (lue)** :
   - on mesure le manque au consommateur (négatif, transit compris) ;
   - on sert le plus BAS rang en manque, l'objet au plus gros manque, sans reprendre le dernier posé ;
   - on pose UNE petite unité ;
   - on attend de voir qu'elle tourne ;
   - on remesure ;
   - des portes passent avant (constructeurs, transport, énergie avec hystérésis et verrou) ;
   - le module se régule seul (1 min d'avance, 1 min d'entrée) ;
   - l'amorce se retire à la 1re production ;
   - une marche de recherche suit 5 min sans manque.
4. **Tiers** : rang = 1 + rang max des ingrédients. La table de l'auteur est écrite à la main et fausse en 3 endroits. Chez nous,
   `depth` existe déjà mais ne sert qu'à départager. La porte manque.
5. **Spéculatif (à mesurer d'abord, L0)** : que la porte de rang ciblée (L2) règle l'interblocage du fer ; que la confirmation (L5)
   et le manque mesuré (L3) règlent D1 et D2 ; que L1b allège `Ca.decide`.
6. **Ordre proposé** : L0 → L1 → L2 → L5 → L3 → L6 → L4, puis le reste. Détails et tests aux §6 et §7 ; une ligne par élément dans
   `TODO_VIDEO.md`.
