# RESEAU-GRAPHE : relier un maximum de ressources aux assembleurs par des bus (conception)

Lot RESEAU-GRAPHE, 8/11. Rien n'est branché en jeu. Livrables : ce document, la règle pure `shared/team/reseau_graphe.lua` (Lua pur, sans nom d'objet), son banc `tests/reseau_graphe_test.lua` (184 contrôles, 30 mutants refusés) et les instances `tests/reseau_graphe_exemple.lua`.
Étiquettes : **mesuré** = lu dans les journaux archivés ou compté par un banc ; **lu** = vu dans le code ; **déduit** = raisonnement non prouvé en moteur réel ; **non mesuré** = paramètre posé faute de mesure.

## 0. Ce que demande le DC (8/11, 0.6.65), et la réponse en 12 lignes

« Ils utilisent directement les ressources dans les coffres des fonderies [...] le problème, c'est qu'il faut faire pas mal de trajets pour aller les chercher [...] relier un maximum les ressources aux assembleurs [...] blocs, graphes connexes [...] maximisation [...] K-max [...] le nombre de bus. »

1. Aujourd'hui tout passe par le QG : collecte (sortie du bloc vers le coffre du QG), puis remplissage (QG vers le quai du consommateur) : **deux trajets de PNJ par objet** (**lu** `build.lua` `out_tasks`, `quai_tasks`).
2. La liaison à tapis existante ne relie qu'UN quai à UN coffre de sortie du même objet à 40 tuiles au plus (**lu** `shared/team/liaison.lua` `Li.pairs`, `Li.MAX_SPAN`) : sur la sauvegarde du DC à 255 min, **1 quai servi par tapis sur 33 à 59** par équipe (§1).
3. Modèle : graphe biparti producteurs (coffres de sortie) vers consommateurs (quais), arêtes entre terminaux du même objet, poids = débit (objets/min) et distance. **Composantes connexes** par objet = les « blocs ».
4. Un **bus** est un tapis droit le long d'une rue (le tronc), avec une branche par coffre : un arbre « en peigne ». Une file de tapis a 2 voies, une voie porte un objet : **k files = 2k objets au plus** (le « K-max » du DC).
5. Objectif : maximiser le gain en PNJ-secondes par minute (trajets évités), sous k files, un budget de plaques, un tronc de 220 tuiles au plus, et le coût des croisements (souterrains).
6. Le sens du tapis compte : un consommateur ne reçoit que ce qui est en amont. Le gain d'un bus se calcule par un balayage le long du tronc (flot maximal sur un chemin orienté, **exact**).
7. Choix des terminaux d'un bus : élagage glouton à rebours et croissance gloutonne, on garde le meilleur (heuristique, **mesurée** à 98,9 % de l'optimum énuméré au pire, 39 instances). Choix des bus sous k : glouton meilleur de deux ordres (valeur, valeur par coût) ; optimal si seul k borne, moitié de l'optimum au pire pour le budget seul, **0,84 au pire mesuré** (60 instances).
8. Coût de calcul **mesuré** (`debug.sethook`) : pire passe 52 984 instructions (0,4 à 2,3 ms aux cadences 8 à 44 ns/instruction déjà mesurées), 300 terminaux en 9,97 millions d'instructions réparties sur 821 unités ; état sérialisable, aucune fonction.
9. Exemple chiffré (§4) : la règle actuelle économise **0,16 PNJ-équivalent** (1 paire) ; avec k = 2 files, **1,24** ; k = 4 : **1,83**, 74 % de la demande servie par tapis (plafond sans géométrie : 91 %).
10. k se choisit par `Rg.k_for(époque, tapis au coffre)` : une file de plus toutes les 3 époques, 150 tuiles de tapis en réserve par file (proposition, **non mesurée**).
11. Limites déclarées (§6) : débits nominaux (la sauvegarde du DC montre des modules « finis » à 0/min, à vérifier avant d'intégrer), pas de tracé réel (A* du plan directeur, interdits, lot traversee), pas de danger (F251).
12. Intégration : un lot suivant, après tv-archi (`liaison.lua`, quartiers) et traversee (§7).

## 1. Modèle actuel (lecture seule) et mesures

**Qui produit quoi, où sont les coffres** (**lu**). Un projet fini du plan directeur porte `p.outs` (coffres de sortie `{x, y}`, objet lu au contenu) et `p.quais` (coffres d'entrée `{x, y, item}`), `p.inflow[objet]` = débit nominal d'entrée en objets/s (`build.lua:2748-2749`). Blocs producteurs : fonderies (colonnes de fours aux gisements), champs, avant-postes (`o.sinks`, tournée « service »), modules de fabrication. Blocs consommateurs : modules (quais d'entrée), centrale (coffre de charbon), centre.

**Le chemin d'un objet aujourd'hui** (**lu**) : `out_tasks` émet une tâche `carry` mode « collect » quand un coffre de sortie atteint `Build.COLLECT_AT` = 200 objets (`build.lua:91`, `4038-4052`) ; `quai_tasks` émet `carry` mode « fill » quand le quai passe sous `Build.QUAI_LOW` = 60, remplissage jusqu'à `Build.QUAI_FILL` = 400 (`build.lua:4054-4100`). Le QG est le moyeu : aucune matière ne va d'un bloc à un autre sans passer par son coffre.

**Liaison à tapis existante** (**lu**, `shared/team/liaison.lua`, `script/team/liaison.lua`) : `Li.pairs` apparie un quai avec le coffre de sortie le plus proche du même objet, d'un AUTRE projet, à `Li.MAX_SPAN` = 40 tuiles (Manhattan) au plus ; un bras à chaque bout, tapis de 48 tuiles au plus (`Li.MAX_LEN`). Décision par `Li.worth` (retour en minutes contre `Li.TMAX` = 90).

**Mesures** (**mesuré**, `fo-logs\2026-11-08_MESURE-DC\temoin` et `\petrole`, sauvegarde du DC à 255,3 min, tick 919 256, bancs de 10 minutes de jeu ; `2026-11-08_ESSAI-0665\base-0664-etape1-guide`, partie neuve) :

| Mesure | Valeur | Source |
|---|---|---|
| Quais d'entrée / coffres de sortie / paires possibles / quais servis par tapis | joueur 33-50 / 51-65 / 0 / 1 ; azure 53 / 92 / 3 / 1 ; amber 59 / 90 / 1 / 2 ; emerald 18-28 / 28-45 / 0 / 0 | `[FO-LIAISON] releve` |
| Demandes de liaison d'azure | 8 demandées, 1 finie, 7 refusées (« aucun chemin ») | `[FO-LIAISON]` minute 264 |
| Un quai type | engrenages, 1,50 objet/s, à 54 tuiles du QG ; sa sortie à 33 tuiles ; retour 44 min, 6,2 PNJ-s/min économisées, 45 tuiles, coût 83 | `[FO-LIAISON] azure : quai 15:q2` |
| Partie neuve (24 à 60 min) | 2 à 10 quais, 2 à 12 sorties, 0 paire possible, 0 liaison | `[FO-LIAISON]` de la partie guide |
| Tâches `carry` réussies / échouées, cumul à 255 min | scarlet 323/488, azure 1024/920, emerald 825/317, amber 554/1029 | `taches ok/echec` de `remote.lua:62` |
| Livré à la main (toutes tâches) | azure 182 223 fer + 107 658 cuivre, soit au plus 285 plaques par `carry` réussie (le livré compte toutes les tâches) | `livre fer cuivre` |
| Causes d'échec cumulées (toutes tâches) | `danger` 263 à 1927, `chemin` 127 à 1084, `stock` 214 à 887 par équipe | `echecs {…}` |
| Débits livrés au QG, joueur à 256 min | fer 358/min, cuivre 33, engrenages 126, tapis 21 | `[FO-IA3E] player minute 256` |
| Modules finis du joueur | `fini(60/60)=0/min` pour presque tous | `[FO-IA3E] … modules {…}` |

Lecture : un PNJ fait un aller-retour de 54 tuiles (23,5 s avec 10 s de prise) pour 340 objets ; la sauvegarde du DC a fait **au plus 1 trajet réussi pour 285 plaques**, et 28 à 65 % des tâches `carry` échouent selon l'équipe (danger, chemin, stock). Le gain d'un tapis n'est pas que la marche : c'est aussi la fin de la dépendance au danger et au chemin pour ces trajets (**déduit**). L'écart de 33 à 59 quais pour 1 à 2 reliés vient de la règle (un seul coffre, 40 tuiles) et du tracé (6 refus sur 7 « aucun chemin »), pas du prix : `Li.worth` accepte le quai type.

**Non mesuré** : la répartition des quais par objet et leurs distances (le journal ne les donne pas). L'exemple du §4 est donc synthétique (positions illustratives, ordres de grandeur lus).

## 2. Formulation

**Données.** Producteurs P (coffres de sortie) et consommateurs C (quais), chacun : objet, tuile (x, y), débit r (objets/min). Moyeu H = QG. Un objet `o` : P_o, C_o.

**Trajets évités.** Un objet porté coûte `leg(d, lot) = (2d / marche + prise) / lot` PNJ-secondes (marche 8 tuiles/s, prise 10 s, lot 200 en collecte, 340 en remplissage ; mêmes constantes que `Li.worth`, test 2.4 : le gain du quai égale `labor_s_min` de `Li.worth`). Un objet livré par tapis de p à c évite `leg(d(p, H), 200) + leg(d(c, H), 340)`.

**Bus.** Un bus b = (objet o, axe a, sens, rue ℓ, sous-ensemble S_b ⊆ P_o ∪ C_o). Les terminaux sont rangés par position le long de l'axe ; le débit dans la voie à la position t est `f(t) = min(cap, f(t-1) + r_p)` à un producteur, `f - min(f, r_c)` à un consommateur ; servi(b) = somme des prises. Gain G(b) = somme des (prise × trajets évités). Coût : tronc + branches (tuiles × détour 1,3) + bras (un par 50 objets/min, 4 au plus) + poteaux, converti en PNJ-secondes avec la durée de pose (`Li.worth`). Valeur nette V(b) = tmax × G(b) − coût(b), avec tmax = 90 min : V(b) ≥ 0 équivaut à « le bus se paie en 90 min ».

**Choix.** Maximiser Σ V(b) sur un ensemble de bus tel que :
- au plus k files, une file portant 2 voies = 2 bus d'objets différents, même axe, même sens, même rue (écart ≤ 4 tuiles), troncs qui se recouvrent d'au moins la moitié du plus court : le recouvrement n'est payé qu'une fois (le « bus principal » regroupe des produits) ;
- dépense totale ≤ budget (plaques) ;
- chaque tronc ≤ 220 tuiles (`F251` : un tapis long se coupe, un PNJ loin meurt) ;
- chaque croisement avec un bus d'une autre file coûte une paire de souterrains (20 plaques-équivalent, **non mesuré**) ;
- les interdits (gisement évité, eau, lot traversee) entrent par le crochet `dist(a, b)` : `nil` = pas de liaison possible.

**Nature du problème.** Conception de réseau à coûts fixes multi-produits avec arbres de Steiner rectilinéaires et sac à dos : NP-difficile (Steiner rectilinéaire, Garey et Johnson 1977 ; sac à dos). La structure du jeu aide : un bus est une rue droite (peigne), un objet = une marchandise, et les blocs sont séparés (composantes connexes). On résout donc par décomposition, pas par programmation linéaire.

**Pourquoi pas un flot maximal de coût minimal.** Le coût d'un tapis est fixe (on le paie en entier ou pas) : un flot de coût minimal à coûts linéaires sous-estime les gros tapis et les écarterait à tort. Il reste utile comme **plafond** : `stats.ceiling` = Σ_o min(offre_o, demande_o) sans géométrie (borne supérieure valable de tout ensemble de bus).

## 3. Algorithme (`Rg.plan`, ou `Rg.begin` / `Rg.step` / `Rg.result`)

1. **Terminaux** : débit des sorties × (1 − `hub_share`) (30 %, **non mesuré**, laissés au QG pour la construction et la fabrication à la main) ; débit borné à 4 bras × 50/min.
2. **Composantes** (exact) : par objet, union-find sur les terminaux, arête si Manhattan ≤ 160 tuiles (ou `dist` ≤ 160 ; `nil` interdit). Plus de 32 terminaux : coupe à la médiane de l'axe le plus étendu, récursivement. Coût O(n²) par objet.
3. **Bus d'une composante** : axe et sens = déplacement du centre (pondéré par le débit) des producteurs vers celui des consommateurs ; tronc à la médiane des coordonnées perpendiculaires (minimise la somme des branches) ; évaluation exacte par balayage. Deux heuristiques : **élagage** (partir de tous les terminaux, retirer à chaque passe celui dont le départ améliore le plus V, ou celui qui raccourcit le plus tant que le tronc dépasse 220) et **croissance** (partir de la meilleure paire amont/aval, ajouter à chaque passe le terminal qui améliore le plus V). On garde le meilleur. Les terminaux laissés forment une composante résiduelle (3 bus au plus par composante) : une grappe trop loin du tronc a son propre bus. Chaque passe = au plus 32 évaluations de O(n log n) ; au pire O(n³ log n) par composante, avec n ≤ 32.
4. **Choix sous k** : candidats triés par V (ordre A) puis par V / coût (ordre B) ; chaque ordre est déroulé avec partage de file et coût marginal (recouvrement déduit, croisements ajoutés) ; on garde le meilleur total. L'ordre A place d'abord le meilleur bus seul.
5. **Sortie** : `buses` dans l'ordre de pose (la file la plus rentable d'abord, sa voie de base avant la voie qui partage son tronc), pour chaque bus ses prises triées par contribution (gain perdu au retrait ; un chantier interrompu laisse la partie la plus utile), `links` à plat, `belts`, `stats` (demande, servi, plafond, PNJ-équivalents, trajets évités par minute, plaques, tuiles, croisements, raisons des refus).

**Garanties, dites honnêtement.**
- Composantes et balayage : exacts (sur une ligne orientée, servir le plus tôt possible maximise le servi : argument d'échange).
- Choix des terminaux : heuristique sans garantie ; contrôlé contre l'énumération des 2^n sous-ensembles (n de 5 à 8, 39 instances) : pire 0,989, moyenne 1,000. Une passe ne voit pas une paire d'ajouts utiles ensemble (producteur + consommateur au-delà du tronc) : limite connue. L'élagage seul est coincé à 59 % de l'optimum sur une des instances (fixture 3.19) ; la croissance la rattrape, d'où le « meilleur des deux ».
- Choix sous k : si seul k borne et que les bus sont indépendants, le tri par V est **optimal** (les k premiers). Si seul le budget borne, le meilleur de {glouton par V / coût, meilleur bus seul} vaut au moins la moitié de l'optimum du sac à dos. Avec les deux bornes, le partage de tronc (coût sous-modulaire) et les croisements (sur-modulaires), aucune garantie : mesuré contre l'énumération sur 60 instances sans partage, pire 0,842, moyenne 0,997.

**Pourquoi cela tient dans le budget de calcul** (**mesuré**, `tests/reseau_graphe_test.lua` §11, `debug.sethook` compte de 1, déterministe) :

| Cas | Instructions |
|---|---|
| Pire passe (une unité de `Rg.step`) | 52 984 (0,4 à 2,3 ms à 8 à 44 ns/instruction) |
| Composante pleine de 32 terminaux, en une fois | 781 185 (une quinzaine d'unités) |
| 150 producteurs + 150 consommateurs, 10 objets | 9 965 532 en 821 unités |

Une unité par tranche de la passe du plan directeur (`Build.PULSE`, 5 ticks), une décision par minute au plus, et seulement quand la **signature** (liste triée des terminaux et débits arrondis) a changé : 300 terminaux coûtent 0,08 à 0,44 s de calcul répartis sur 70 s, soit moins de 0,7 % d'un cœur pour une équipe (**déduit** des cadences ; le coût réel en jeu se mesure au lot d'intégration). Le travail ne contient ni fonction ni entité (le crochet `dist` est repassé à chaque `Rg.step`) : on peut le garder dans l'état de l'équipe.

**Déterminisme** : listes triées avec départage par clé, aucun `pairs`, aucune trigonométrie, aucune horloge, aucun hasard ; test 7.1 : mêmes résultats quel que soit l'ordre des listes d'entrée.

## 4. Exemple chiffré (base du joueur à 256 min ; `tests/reseau_graphe_exemple.lua`)

Entrées : 7 coffres de sortie (fer : 4 × 120/min à 112 tuiles du QG, deux côtés ; cuivre 2 × 40/min ; engrenages 90/min) et 9 quais (fer 180 + 20 + 40 + 30 + 33/min, cuivre 50 + 20, engrenages 45 + 45). **Lu** dans les journaux : ordres de grandeur des débits (fer 358/min, cuivre 33, engrenages 126, tapis 21 livrés au QG) et un quai à 1,5 objet/s, 54 tuiles du QG. **Illustratif** : positions (pas du treillis de 28) et répartition des débits entre quais. Demande 463 objets/min ; plafond sans géométrie 422.

| Règle | Files | Bus | Servi (objets/min) | Part de la demande | Gain (PNJ-s/min) | PNJ-équivalents | Plaques | Tuiles |
|---|---|---|---|---|---|---|---|---|
| Actuelle (`Li.pairs`, 40 tuiles, un bras) | 1 paire | 1 | 28 | 6 % | 9,4 | 0,16 | – | – |
| Bus, k = 1 | 1 | 1 | 168 | 36 % | 58,5 | 0,97 | 332 | 188 |
| Bus, k = 2 | 2 | 2 | 218 | 47 % | 74,4 | 1,24 | 473 | 267 |
| Bus, k = 3 | 3 | 3 | 281 | 61 % | 93,7 | 1,56 | 838 | 492 |
| Bus, k = 4 | 4 | 4 | 344 | 74 % | 110,0 | 1,83 | 1 204 | 717 |
| Bus, k = 5 | 4 | 4 | 344 | 74 % | 110,0 | 1,83 | 1 204 | 717 |

À k = 5 la règle n'ouvre pas de cinquième file : plus rien ne se paie. Pour k = 2, bus 1 : fer, tronc vertical à x = 112 de y = −84 à −28 (sens du sud), 188 tuiles, 168 objets/min, retour 24 min, prises engr:q1 (contribution 58), fer-est:o1 (31), fer-est:o2 (28) ; bus 2 : cuivre, tronc à x = −28, 79 tuiles, 50/min, retour 37 min. À k = 4 s'ajoutent le fer de l'ouest vers circ:q1 et muni:q1 (63/min, 225 tuiles, retour 67 min) et les engrenages vers sci:q3 et tapis:q2 (63/min, 225 tuiles, retour 76 min, 1 croisement). Le reste du fer (quais sci:q1 et tapis:q1) est refusé : aucun producteur en amont dans la limite de tronc.

Ce que cela dit : (a) le premier bus (le fer vers le quai d'engrenages) apporte la moitié du gain de k = 4 (58,5 sur 110) : le « K-max » a un coude, k = 4 suffit ici ; (b) le plafond est atteint à 82 % avec 4 files ; (c) 1 à 2 PNJ-équivalents de travail de transport disparaissent, ce qui compte sur une équipe de 8 à 30 PNJ dont 28 à 65 % des `carry` échouent.

## 5. Choix de k

`Rg.k_for(époque, tapis_au_coffre) = min(1 + ⌊époque / 3⌋, ⌊tapis / 150⌋)` : 1 file aux époques 0 à 2, 2 aux époques 3 à 5, jusqu'à 5 à l'époque 14 ; jamais plus que le stock ne le permet (150 tuiles de tapis par file ouverte, un bus type de l'exemple fait 130 à 190 tuiles). **Proposition non mesurée** : le DC tranche la courbe. Par équipe, k est un paramètre du relevé.

## 6. Ce que la règle ne fait pas (à lire avant d'intégrer)

- **Pas de tracé réel.** Le peigne est une estimation de longueur (portée × 1,3 + 2 par terminal). Le tracé vient de `P.belt_route` (A* du plan directeur) ; 6 demandes sur 7 d'azure ont été refusées « aucun chemin ». Un bus refusé doit retomber sur ses sous-bus (retirer le terminal qui bloque) ; la règle fournit les prises triées par contribution pour cela.
- **Débits nominaux.** Les débits d'entrée viennent de `p.inflow` (nominal) ; ceux des sorties doivent venir de la production **mesurée** (`rate_meas` de `[FO-IA3E]`, quotas `p.qm_out`). Les modules « finis » du joueur sont à `0/min` dans le journal du DC à 255 min : si c'est vrai, rien ne sort de leurs coffres et aucun bus ne se paie ; à éclaircir avant tout branchement.
- **Un bloc qui produit et consomme le même objet** n'est pas exclu (`Li.pairs` l'exclut par `pid`) ; à ajouter si un gabarit en produit.
- **Danger** : aucune pondération par le danger (F251) ; le crochet `dist` peut rendre `nil` pour une zone à risque.
- **Croisements** comptés entre bus de files différentes seulement ; les collisions de troncs colinéaires (deux files sur la même rue sans recouvrement) ne sont pas évitées par la règle, le tracé les voit.
- **Coût en tick** : mesuré hors jeu en instructions ; la conversion en ms (8 à 44 ns/instruction) vient d'une mesure faite sous charge. À remesurer en jeu.
- **Valeurs non mesurées** : `Rg.HUB_SHARE` (0,3), `Rg.LANE_CAP` (450/min), `Rg.ARM_RATE` (50/min), `Rg.CROSS_PLAQUES` (20), `Rg.EPOCH_STEP`, `Rg.BELT_TILES`, `Li.LABOR_VALUE` (1 plaque par PNJ-seconde).

## 7. Intégration prévue (lot suivant, pas ici)

- **Où** (carte `docs/IA_WORKFLOW.md` §7) : « comment le bâtir » = plan directeur. `Liaison.step` (`script/team/liaison.lua`, relevé en E2, pouls de 5 ticks) garde son relevé ; `Ln.pairs` / `Ln.decide` sont remplacés par un travail `Rg.begin` avancé d'une unité par pouls ; la demande part par `Build.request` (nouvelle clé de projet « bus », à traiter comme `liaison` dans `eligible`, `SKIP_KEYS`). La décision « combien de files » reste au cerveau (capitalisation) via `Rg.k_for`.
- **Dépend de** : tv-archi (les dépôts de quartier, V23, deviennent des terminaux et des moyeux supplémentaires : `hub` devient une liste, le moyeu d'un terminal est le plus proche) ; traversee (tapis souterrains : `Rg.CROSS_PLAQUES` remplacé par le coût réel, `dist` rendu par le tracé réel, gisements évités) ; ces lots touchent `liaison.lua` : l'intégrateur choisit l'ordre.
- **Repli** : inchangé. La barre du coffre d'entrée (`Li.bar`) reste ; un bus coupé laisse le quai baisser sous `Build.QUAI_LOW` et le PNJ reprend (même mécanique que `liaison.lua`).
- **Journal** : une ligne `[FO-BUS]` par décision (signature, composantes, bus gardés, refusés avec la raison, servi, plafond), pour que la lecture au journal dise si le bus est la bonne idée avant de regarder des captures.
- **Preuve** : banc de moteur réel à écrire dans le lot d'intégration ; ici, preuve hors jeu seulement.

## 8. Checklist `IA_WORKFLOW.md` §6

1. Étape : aucune (règle pure, rien d'appelé). Prévue : E2 (plan directeur), pas la pensée de 300 ticks. 2. Stock : la règle lit des débits, pas le coffre ; l'intégration lira le stock LIBRE pour `Rg.k_for`. 3. Lecteurs : aucun encore ; futur lecteur = `Build.request`. 4. Tâche : un bus supprime des tâches `carry` (collecte et remplissage) ; il ne passe ni par `Board.sync` ni par la porte. 5. Vue : les sorties du plan directeur restent invisibles du cerveau (maillon fragile de la carte) ; un bus ne le règle pas. 6. Boucles : B2 (place, dépôt, collecte) s'améliore (moins de dépôts) ; aucune nouvelle boucle. 7. Joueur : aucune action sur une entité qui n'est pas à l'équipe. 8. `f.is_player` : vaut pour les factions et pour votre équipe. 9. Journal : `[FO-LIAISON]` (quais servis), `[FO-BUS]` à créer. 10. Preuve : 184 contrôles hors jeu, mutants, énumération ; aucun banc moteur.

Commandes : `lua5.2 tests/reseau_graphe_test.lua` (3 s ; attendu « [RESEAU-GRAPHE] BILAN : 184 OK, 0 ECHEC(S) », « mutants refusés : 30 sur 30 ») ; `lua5.2 tests/liaison_test.lua` inchangé (164 OK).
