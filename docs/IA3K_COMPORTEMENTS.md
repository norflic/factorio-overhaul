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

Une carte par équipe (chaque faction, votre équipe), dans `global` (espace `ia3k` de `script/core/storage.lua`). Elle
ne contient QUE ce que les PNJ de l'équipe ont perçu : regard en marche, vie perdue, morts de l'équipe, yeux fixes du QG
et des avant-postes (§5 bis). Aucune position, aucune distance, aucune cible écrite en dur.

- Cases de 16 × 16 tuiles (clé numérique `(cx + 32768) × 65536 + (cy + 32768)`).
- **Menaces fixes** (vers, nids, tourelles adverses, et « meutes », §5) : liste bornée (48), position, genre, portée LUE
  au prototype (`attack_parameters.range`, `vision_distance` pour un nid), date du dernier regard. Une menace pèse sur
  une case si sa portée + marge (10 tuiles) touche la case ; décroissance lente (2 % par minute ; meute : 10 % par minute).
  Un regard qui ne revoit pas une menace connue dans son champ l'efface (nid nettoyé).
- **Danger géométrique** `D.danger_exact` : distance réelle du point aux menaces (portée + 4 tuiles), en plus des cases :
  c'est lui que juge la porte (les cases surestiment : un avant-poste à 35-55 tuiles d'un ver était refusé).
- **Menaces mobiles** (unités, personnages adverses) et **attaques subies** : score de case, décroissance 10 % par minute.
- **Morts** : liste bornée (32) `{ x, y, tick, home }`. Une mort pèse 600 à moins de 24 tuiles pendant 30 min, puis
  décroît (10 % par minute) ; elle compte 60 min pour la règle « au plus 2 morts au même endroit (32 tuiles) par heure ».
  Une mort à moins de 16 tuiles du QG (raid sur le QG) est gardée (`home`) mais ne ferme aucun trajet.
- Décroissance par table entière précalculée (aucune puissance flottante, aucune trigonométrie).
- Seuil de blocage `B = clamp(600 × 1000 / prudence, 400, 750)` ; un ver ou une tourelle pèse 1 000, un nid 800 :
  bloqués pour tous ; une mort (600) bloque un prudent, coûte × 7 à un audacieux ; 2 morts bloquent tout le monde.

## 3. Trajets (`shared/ai3/route.lua`, pure)

- **Variation (C1)** : deux points de passage par tournée, au tiers et aux deux tiers du trajet, décalés latéralement de
  8 à 18 % de la distance (8 à 20 tuiles : en moteur réel l’aller s’allonge d’environ 2 fois l’écart) ; côté tiré par le flux de l'équipe, changé 2 fois sur 3 d'une
  tournée à la suivante, et tiré à part pour l'aller et le retour. Pas de variation sous 40 tuiles.
- **Avec danger** : A* déterministe sur les cases (8 voisins, coût 10 / 14 × (1 + danger ÷ 100), cases ≥ B
  infranchissables sauf départ et but), bruit de tournée ≤ 10 % par case, boîte du trajet + 8 cases, au plus 1 500
  développements ; égalités tranchées par la clé. Danger d'un point : le plus fort des cases qu'il touche à leurs bords.
  Départ dans une case marquée : sortie vers la case sûre la plus proche (6 anneaux au plus), puis itinéraire.
- Le chemin de cases est réduit aux tournants dont le segment ne traverse pas de case marquée (contrôle toutes les
  4 tuiles ; le premier segment passe par le centre de la case du PNJ s'il coupe une case marquée), puis **coupé en
  tronçons de 24 tuiles au plus** : entre deux points non alignés, le chemin du moteur s'écarte de la droite (F300).
  Les tronçons s'enchaînent sans arrêt (à 12 tuiles du point visé, le PNJ vise déjà le suivant).
- Résultat : points de passage, longueur, danger maximal traversé (cases et géométrique), danger au but, blocage.

## 4. Porte des tâches (C5, C6)

À la prise d'une tâche, après son programme : itinéraire du PNJ jusqu'à la première destination du programme. Bloqué au
sens des cases, l'itinéraire qui minimise le danger est gardé s'il reste hors de portée réelle des menaces.
- au moins 2 morts dans l'heure à moins de 32 tuiles du trajet ou du but : **attendre** (même escorté) ;
- trajet bloqué, but ≥ B, ou 1 mort dans l'heure : **escorte** si au moins 2 soldats sont libres, sinon **attendre** ;
- danger ≥ B ÷ 2 sur le trajet : escorte si possible ; sinon un prudent attend, un audacieux part ;
- but à plus de 160 tuiles du QG (C6) : escorte si possible (le PNJ part, les soldats le rattrapent) ;
- sinon **partir**.
- **Changer de site** : un minage refusé cherche une autre tuile de son minerai hors de la zone marquée (au plus 40 tuiles
  contrôlées, la plus proche du QG), puis la porte rejuge.
- **Escalade** (« attendre n'est pas une fin ») : une destination refusée pour une menace VUE (pas pour une mort) part
  quand même après W attentes, W = clamp(⌊4 × prudence / 1 000⌋, 2, 6) ; le PNJ garde ses réflexes. La menace qui bloque
  est signalée aux soldats, qui la nettoient quel que soit le caractère.
- Attendre = tâche rendue en échec « danger » (le tableau la reprend plus tard, ou le cerveau choisit un autre site).
  Escorte : 2 soldats + 1 par menace fixe à moins de 64 tuiles du trajet (6 au plus) ; le PNJ attend son escorte au QG
  (15 s au plus). Votre équipe n'a pas de soldats : elle détourne ou attend.

## 5. Réaction en marche (C2, C3, C4 pour les ouvriers ; `shared/ai3/reaction.lua`, pure)

À chaque pensée du PNJ (60 ticks) hors du QG (32 tuiles) : `find_nearest_enemy` autour d'un point 20 tuiles devant lui
(vers le point de passage courant), rayon 40 (audacieux) à 56 (prudent) : une zone de béhémoth (48 + marge) est vue
avant d'y entrer. Perte de vie depuis le regard précédent = attaque subie. Ce qui est vu est marqué, avec les autres
ennemis à moins de 24 tuiles de lui (le groupe entier : un nid et ses gardes, des vers en grappe), puis :
- **peur** : vie < seuil (40 % neutre ou audacieux, jusqu'à 55 % prudent) et ennemi à portée + 8, ou sans munitions
  (inventaire de munitions vide) et ennemi à moins de max(portée + 8, 24 à 36) : **fuite** vers la tourelle amie (3 tuiles
  derrière elle, côté QG) ou le QG le plus proche ; la garnison est alertée ;
- menace fixe sur le trajet restant ou à portée + 8 : **détour** (arrêt, nouvel itinéraire) ; déjà à portée + 2 :
  **demi-tour** (la tâche est rendue) ;
- unités : force PESÉE (vie maximale du prototype ÷ 75, au moins 0,2 ; un personnage : 1) ; en surnombre (alliés armés à
  moins de 16 tuiles + 1 ≥ rapport × force, rapport 1,5 agressif à 3 prudent) : **combat** sur place ; sinon au-delà de
  leur vue + 8 : **arrêt** 3 s puis nouvel itinéraire ; entre vue et vue + 8 : **détour** ; plus près : **demi-tour** ;
  après 2 arrêts ou détours dans la même tournée : demi-tour (on renonce) ;
- **meute** : un recul devant un groupe d'unités (force ≥ 0,4) marque sa zone comme menace fixe à décroissance rapide ;
- près du QG, face à des unités, sans tourelle où se réfugier : **combat** (fuir seul est pire) ;
- un soldat ou un ouvrier adverse isolé (force ≤ 1,5) vu près du QG : la garnison est appelée et le **chasse** ;
- une menace fixe nouvelle vue par un camarade, ou une mort de l'équipe, qui touche le reste du trajet : nouvel
  itinéraire. Retraite en cours : pas de nouvel arrêt à chaque regard.

## 5 bis. Yeux fixes

Le QG voit à 160 tuiles, un avant-poste à 128 (brouillard d'IA2-c) : 8 menaces fixes connues par équipe y sont
revérifiées toutes les 600 ticks ; une menace qui n'y est plus (nid détruit) est oubliée. Hors de ce champ, la mémoire
reste (brouillard).

## 6. Soldats (B5, C4, C7 ; `shared/ai3/soldats.lua`, pure)

Toutes les 30 ticks, une faction (à tour de rôle) : ses soldats SANS groupe du moteur et proches du QG (160 tuiles)
reçoivent un rôle, par priorité : **escorte** (demandes de la porte), **défense** du QG menacé et **chasse** d'un
adversaire isolé, **nettoyage** d'une menace qui a tué ou qui bloque une destination (3 + 2 par menace ; toute menace
proche si agressivité ≥ 900), **patrouille** (anneau de 80 tuiles ; part = agressivité ÷ 2, entre 25 et 75 %), **garde**
(postes à 28 tuiles du QG, avant-postes marqués). Les soldats loin du QG sont laissés au rappel de
`script/faction/military.lua` (sauf escorte, nettoyage, garde d'un avant-poste lointain : drapeau `s.ia3k`). Commandes
individuelles composées terminées par `wander` sans fin. Repos de 60 s après chaque mission. QG menacé (unité ou
personnage ennemi à moins de 48 tuiles) : les ouvriers SANS munitions entre 12 et 160 tuiles du QG s'abritent (C7 ; factions
et votre équipe, qui n'a pas de soldats). Mesure : part du temps « sans ordre » hors repos.

## 7. Lisibilité (D1)

`rendering.draw_text` au-dessus du PNJ (150 ticks, échelle 1,2), traduit (`locale/*/ia3k.cfg`) : « ! » alerte, Détour,
Demi-tour, Fuite, Combat, Escorte, Attente, Patrouille, Garde, Nettoyage, Abri, Défense, Chasse. Un seul texte vivant
par agent ; chaque état reste au moins 2 s (un état nouveau attend son tour, sauf « Fuite », dans un second emplacement).

## 8. Données en `global` (espace `ia3k`), budget

`ia3k = { teams = { [clé] = { map, epoch, stream, char, hold, stats, escorts, waits } }, agents = { [id] = { final, pts,
i, epoch, refuge, hold, hp, armed, label, escort, risk } } }` : nombres, chaînes, tables. Budget : regards ≈ 150 PNJ /
60 ticks ; A* seulement quand une marque touche la boîte du trajet ; soldats une faction par 30 ticks. Mesuré par
`analyze.py --spikes` sur les bancs (INTEGRATION.md du lot).

## 9. Bancs (moteur réel)

`ia3k-route` (C2, D1), `ia3k-memoire` (C5, le cas Écarlate ; économie), `ia3k-variete` (C1), `ia3k-peur` (C3),
`ia3k-soldats` (B5, C4) ; témoins `ia3k-route-temoin`, `ia3k-variete-temoin`, `ia3k-memoire-temoin` (lot éteint par la
porte des bancs). Hors jeu : `tests/ia3k_regles_test.lua`, `tests/ia3k_soldats_test.lua` (règles pures, mutants qui
doivent échouer), `tests/ia3k_moteur_test.lua` (moteur simulé). Rejeu : `tools/autotest/ia3k_rejouer.sh`.
