# Lot IA3-k « comportements visibles » : conception

Lot IA3-k, 27/10/2026. Référence : `docs/IA_ATTENDUS.md`, famille C (C1 à C7), lignes B5 et D1. Demande du DC (OBJECTIFS
§5, 26/10) : « Les trajets sont prévisibles […] Ils ne s'adaptent pas du tout. Ils n'ont pas de comportement visible,
typiquement la peur […] ou à l'inverse l'agressivité. Et beaucoup d'agents ne font rien. » Cas chiffré : Écarlate,
26 PNJ tués en 41 min, presque tous en tâche « service » entre 87 et 103 tuiles du QG, par les mêmes petits biters et
vers (journal de sa partie du 26/10, lignes « PNJ … tue »).

Tout est générique : aucune règle par bâtiment, aucun nom d'objet dans les règles pures. Réglage de carte
`fo-war-ia3-comportement` (allumé par défaut) : éteint, aucun crochet n'agit (comportement de `main` à l'identique).

## 1. Ce que l'on prend dans le code existant

| Existant | Usage |
|---|---|
| `script/team/worker.lua` : programmes d'étapes, `goto_step`, autodéfense `defend` (tir à 18 tuiles, toutes les 60 ticks), état `walk` | crochets courts : `defend` (sens), `goto_step` (tronçon), prise de tâche (porte), `Worker.abort` exposé |
| `script/agents/nav.lua` + `script/core/path_service.lua` (demandes plafonnées, asynchrones) | chaque tronçon d'itinéraire est un `Nav.go` ordinaire : le moteur ne connaît pas de coût de danger, on lui donne des points de passage |
| `script/companion/registry.lua` : `death_cause`, `death_pos` gardés à la mort | marque de MORT dans la carte du danger (crochet `Registry.on_removed`, aucun changement du registre) |
| `shared/faction/traits.lua` (IA2-0) : `prudence`, `agressivite` (pour mille) | seuils de la peur, du détour, de l'engagement, part des patrouilles |
| `script/faction/military.lua` : garnison (`wander`), groupes du moteur | les soldats SANS groupe reçoivent un rôle (commande individuelle) ; une attaque du chef les reprend (priorité) |
| `Tr.new_stream` (flux à état dans `global`, mélange non linéaire) | tirage de la variation des trajets (sels 470 à 479 : IA3-k) |

## 2. Carte du danger (`shared/ai3/danger.lua`, pure)

Une carte par équipe (chaque faction, votre équipe), dans `global` (espace `ia3k` de `script/core/storage.lua`).

- Cases de 16 × 16 tuiles (clé numérique `(cx + 32768) × 65536 + (cy + 32768)`).
- **Menaces fixes** (vers, nids, tourelles adverses) : liste bornée (48), position, genre, portée, date du dernier regard.
  Le score d'une case = Σ des menaces dont la portée + marge touche la case (distance du point au rectangle), × une
  décroissance lente (2 % par minute). Un regard qui ne revoit pas une menace connue dans son champ l'efface (nid nettoyé).
- **Menaces mobiles** (unités, personnages adverses) et **attaques subies** : score de case, décroissance 10 % par minute
  (même forme que la rancune du chef et H11).
- **Morts** : liste bornée (32) `{ x, y, tick }`. Une mort pèse 600 sur les cases à moins de 24 tuiles pendant 30 min,
  puis décroît (10 % par minute) ; elle compte 60 min pour la règle « au plus 2 morts au même endroit par heure ».
- Décroissance par table entière précalculée (aucune puissance flottante, aucune trigonométrie).
- Seuil de blocage `B = clamp(600 × 1000 / prudence, 400, 750)` ; un ver ou une tourelle pèse 1 000, un nid 800 :
  bloqués pour tous ; une mort (600) bloque un prudent, coûte × 7 à un audacieux ; 2 morts bloquent tout le monde.

## 3. Trajets (`shared/ai3/route.lua`, pure)

- **Sans danger dans la boîte du trajet** : un point de passage tiré au sort par tournée, au milieu du trajet, décalé
  latéralement de h, |h| ∈ [0,06 D ; 0,18 D] (D = distance), côté tiré : allongement ≤ 6,3 % (2 √(¼ + 0,18²) = 1,063).
  Pas de variation sous 40 tuiles.
- **Avec danger** : A* déterministe sur les cases (8 voisins, coût 10 / 14 × (1 + danger ÷ 100), cases ≥ B
  infranchissables sauf départ et but), bruit de tournée ≤ 10 % par case (variété, allongement borné), boîte du trajet
  + 8 cases, au plus 1 500 développements ; égalités tranchées par la clé. Le chemin de cases est réduit aux tournants
  dont le segment ne traverse pas de case marquée (contrôle tous les 4 tuiles).
- Le résultat : points de passage, longueur, danger maximal traversé, morts de l'heure près du trajet, blocage.

## 4. Porte des tâches (C5, C6)

À la prise d'une tâche, après son programme : itinéraire du PNJ jusqu'à la première destination du programme.
- au moins 2 morts dans l'heure à moins de 32 tuiles du trajet ou du but : **attendre** (même escorté) ;
- trajet bloqué, but ≥ B, ou 1 mort dans l'heure : **escorte** si des soldats sont libres, sinon **attendre** ;
- danger ≥ B ÷ 2 sur le trajet : escorte si possible ; sinon un prudent attend, un audacieux part ;
- sinon **partir**. Attendre = tâche rendue en échec « danger » (pause de 30 s du tableau : elle est reprise plus tard,
  ou un autre site est choisi par le cerveau). Votre équipe n'a pas de soldats : elle détourne ou attend.

## 5. Réaction en marche (C2, C3, C4 pour les ouvriers ; `shared/ai3/reaction.lua`, pure)

À chaque pensée du PNJ (60 ticks) hors du QG (32 tuiles) : `find_nearest_enemy` autour d'un point 16 tuiles devant
lui (rayon 28 à 40 selon la prudence) ; perte de vie depuis le regard précédent = attaque subie. Ce qui est vu est
marqué sur la carte, puis :
- **peur** : vie < seuil (40 % neutre, jusqu'à 55 % prudent, jamais moins de 40 %) ou sans munitions, ennemi à portée
  + 8 : **fuite** vers la tourelle amie ou le QG le plus proche ; soldats de la garnison alertés (faction) ;
- menace fixe sur le trajet restant ou à portée + 8 : **détour** (arrêt, nouvel itinéraire) ; déjà à portée : demi-tour ;
- unités : en surnombre (alliés armés + 1 ≥ rapport × ennemis, rapport 1,5 audacieux à 3 prudent) : **combat** sur
  place ; sinon unités à plus de 24 tuiles : **arrêt** 3 s puis nouvel itinéraire ; plus près : **demi-tour**.

## 6. Soldats (B5, C4, C7 ; `shared/ai3/soldats.lua`, pure)

Toutes les 120 ticks par faction, les soldats SANS groupe du moteur reçoivent un rôle, par priorité : **escorte**
(demandes de la porte, 2 + menaces, au plus 6), **défense** du QG menacé (C7), **nettoyage** d'un nid ou d'un ver à moins
de 48 tuiles d'un avant-poste ou d'un trajet récent quand la garnison suffit (2 par menace + 3, agressivité ≥ 900 ou
une mort près de lui), **patrouille** (anneau de 64 à 96 tuiles, 8 secteurs, et avant-postes proches ; part = agressivité),
**garde** (postes à 28 tuiles du QG, avant-postes marqués). Commandes individuelles composées terminées par `wander`
sans fin : aucune fin de commande (un `unit_number` peut égaler un numéro de groupe dans `on_ai_command_completed`).
Repos de 60 s après chaque mission. Mesure : part du temps « sans ordre » hors repos.

## 7. Lisibilité (D1)

`rendering.draw_text` au-dessus du PNJ (décalage −3,2, 150 ticks, échelle 1,2), traduit (`locale/*/ia3k.cfg`) :
« ! » alerte, Détour, Demi-tour, Fuite, Combat, Escorte, Attente, Patrouille, Garde, Nettoyage, Abri, Défense. Un seul
texte vivant par agent (l'ancien est détruit).

## 8. Données en `global` (espace `ia3k`), budget

`ia3k = { teams = { [clé] = { map, char, stats, escorts, roles } }, agents = { [id] = { route, i, goal, tour, hold,
refuge, hp, label } } }` : nombres, chaînes, tables. Budget visé : regards 150 PNJ / 60 ticks × ~20 µs ≈ 0,05 ms par
tick ; A* seulement quand une marque touche la boîte du trajet (≤ 1 par tick, ≤ 1 ms) ; soldats O(n) toutes les 120
ticks. Mesuré par `analyze.py --spikes` sur les bancs.

## 9. Bancs (moteur réel)

`ia3k-route` (C2), `ia3k-memoire` (C5, le cas Écarlate), `ia3k-variete` (C1), `ia3k-peur` (C3), `ia3k-soldats` (B5,
C4). Hors jeu : `tests/ia3k_*_test.lua` (règles pures, mutants qui doivent échouer, moteur simulé).
