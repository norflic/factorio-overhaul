# MÉGA-FONDERIE : conception (lot MEGA-FONDERIE, 8/11)

Demande du DC (8/11, 17 h 50) : « Actuellement, je vois des foreuses électriques qui recrachent directement dans des fours en pierre
individuels. C'est une technique de début de partie, pas de l'automatisation à grande échelle. Ce qui est exigé : La transition électrique
implique la création de Méga-Fonderies. Les foreuses électriques doivent extraire en masse, envoyer les minerais sur de très gros bus
(plusieurs lignes), qui alimentent ensuite des blocs rectangulaires entiers dédiés uniquement à la fonte (les fonderies). »

## 1. Réponse au DC : pourquoi on reste en paires ou en petites lignes (lu sur aa17f16c)

1. **Ce que vous voyez est le remplacement sur place.** `script/team/foreuse_swap.lua:5-12` change une foreuse thermique d'avant-poste en
   électrique « son récepteur (four ou coffre) reste le même » ; le centre de la 3 × 3 est choisi pour que son dépôt tombe dans le four
   (`shared/team/foreuse_swap.lua:5-9`). C'est la seule voie électrique qui ne demande ni tapis ni plan : elle passe la première.
2. **Le champ en bandes, seule voie à tapis, avance bande par bande.** 2 chantiers de bande à la fois, tous minerais
   (`shared/team/thermique.lua:55`) ; la partie suivante attend que la précédente ait produit (`shared/team/migration_champ.lua:62`) ;
   8 foreuses par côté et par groupe (`script/team/champ.lua:44`). Et chaque bande finit dans **sa propre** colonne de fours, au bout de son
   tapis (`shared/team/champ.lua:13-18`, `shared/team/champ_colonne.lua:6-20`) : ni collecteur, ni bus, ni bloc.
3. **La fonderie du treillis tient dans un lot.** Ligne de foreuses ≤ min((24 − 1) / 3, voie / débit) = 7 paires
   (`shared/team/modules.lua:675` ; `P.LOT = 24`, `shared/team/plan.lua:37`), d'où 14 foreuses, 21 % d'un gisement de 1 000 tuiles ;
   elle démarre à ce que le stock paie (`script/team/build.lua:1828-1855`) ; un ordre = 1 module (`script/ai3/capitalisation.lua:131`)
   d'au plus 150 objets/min (`shared/ai3/automatiser.lua:77`, découpe `capitalisation.lua:1510-1518`).
4. **La décision suit un manque, pas un gisement.** L'ordre « couvrir » demande une demande NETTE de minerai
   (`shared/ai3/couverture.lua:44-48`) : on extrait ce qui manque, jamais en masse.

## 2. Le flux de bout en bout

```
gisement ─▶ BANDES de foreuses électriques (Ch.plan, inchangé : rangée de poteaux, foreuses, tapis, foreuses)
        ─▶ COLLECTEUR au bord du champ : chaque groupe de bande charge PAR LE CÔTÉ une voie d'une ligne du bus ;
           le charbon charge l'autre voie (four à combustible) ; four électrique : minerai sur les deux voies
        ─▶ BUS DE MINERAI : N lignes parallèles, N = ⌈minerai/s ÷ minerai par ligne⌉
        ─▶ BLOC DE FONTE rectangulaire : une COLONNE par ligne du bus ; tapis d'entrée au milieu, bras, fours,
           bras de sortie des deux côtés, tapis de plaques PARTAGÉS entre deux colonnes voisines, poteaux dans les rangées de bras
        ─▶ QUAI de plaques au bout de chaque tapis de sortie (bras → coffres, collecte existante), puis bus de plaques (tranche 4)
```

Repère du bloc (u en travers, v le long des colonnes, entrée en v = 0). Colonne de pas P = 2·fs + 6 (10 tuiles pour un four 2 × 2) :
`u=0 tapis de plaques | 1 bras de sortie | 2..fs+1 four | fs+2 bras d'entrée | fs+3 TAPIS D'ENTRÉE | fs+4 bras | four | 2fs+5 bras | (2fs+6 = tapis
de plaques de la colonne suivante)`. Largeur C·P + 1. Poteaux dans les colonnes de bras, sur les tuiles libres (un four de fs tuiles laisse
fs − 1 tuiles libres par bras), pas le long de v = plus grand multiple de fs ≤ 2·portée + 1 ; un poteau de bras de sortie sert deux colonnes.

## 3. Dimensionnement (règle pure `shared/team/mega_fonderie.lua`, toutes les données lues aux prototypes)

| Grandeur | Formule | Fer, four de pierre, tapis jaune |
|---|---|---|
| foreuses du gisement | D = ⌊tuiles × couverture ÷ (s·(s + 1))⌋ (1 foreuse par 12 tuiles en bandes), ou D du cadre du champ | 1 000 t : 83 ; 2 000 t : 166 |
| minerai | M = D × débit d'une foreuse (productivité comprise) | 41,5 /s ; 83 /s |
| minerai par ligne | voie (four à combustible : l'autre voie porte le charbon) ; 2 × voie (four électrique) | 7,5 /s |
| lignes du bus | N = ⌈M ÷ minerai par ligne⌉ ; tapis : le plus lent qui donne N ≤ 12, sinon le plus rapide et D réduit | 6 ; 12 |
| fours par colonne | n = ⌈minerai par ligne ÷ débit d'un four⌉, pair ; borné par la voie de sortie : n/2 × débit × rendement ≤ voie | 24 (12 par côté) |
| fours | F = ⌈M ÷ débit d'un four⌉ ; colonnes C = N (la dernière partielle) | 133 ; 266 |
| plaques | F × débit × rendement | 41,5 /s (2 490 /min) |
| charbon | F × combustible d'un four (+ 25 %, `Co.COAL_MARGIN`) | 3,0 /s → 8 foreuses |
| courant | D × kW foreuse + 2F × kW bras (porte : quota `Elec`) | ≈ 11 MW |
| rectangle | (C·P + 1) × (n/2 · fs + tête + quai) | 61 × 30 tuiles |

## 4. Déclencheurs et taille

Une fois par minute et par équipe (factions ET votre équipe), à l'étape 11 du cycle de la capitalisation (libre aujourd'hui), pour chaque
gisement recensé (`cs.deps`) : **décider** si (a) le réglage `fo-war-mega-fonderie` est allumé, (b) le minerai a un four de champ
(`MigChamp.takes`), (c) le gisement porte au moins `Mf.MIN_LINES` = 2 lignes pleines (sinon la colonne du champ suffit), (d) un réseau
produit, (e) un tapis est débloqué, (f) aucune crise (survie, QG menacé). Taille visée = saturation du gisement (directive du 8/11) ; taille
de départ = colonnes que le stock libre paie, au moins 1. Chaque refus a sa cause au journal `[FO-MEGA]` (une ligne par changement).

## 5. Croissance : une RANGÉE EXTENSIBLE le long du bus (règle commune `shared/team/rangee_bus.lua`)

Directive du DC (8/11, vers 18 h) : « passer d'une logique de "bloc fermé" à une logique de "rangée extensible alimentée par un bus" » ;
« un module capable d'être dupliqué (copié-collé) de gauche à droite [...] tant que la demande le justifie », arrêté seulement par un obstacle
infranchissable (lac, falaise), un obstacle destructible (caillou, arbre) étant détruit. Le bloc n'est donc pas un rectangle fermé : c'est une
RANGÉE de colonnes (une par ligne du bus), dupliquée le long du bord du champ. Règle commune (propriétaire MEGA-FONDERIE ; lecteurs
PETROLE-RANGEE, bus de tuyaux vers raffineries, et MALL, cellules d'assembleurs) : `Rb.extent` (modules posables avant la première tuile
infranchissable, tuiles à défricher, cause ; relecture par passes bornées), `Rb.count` (demande), `Rb.capacite` (débit de chaque ligne),
`Rb.croissance` (cible jamais en baisse, cause), `Rb.origine`. La géométrie d'un module vient de la base de motifs
(`shared/team/motifs/`, `fonte-2x2-double-central` = ma colonne ; `Cat.instancier`), pas de cette règle.
Chaque minute : relevé du minerai qui ARRIVE ; `Mf.grow` (Fonte.balance en unités « colonne » et « bande ») : entrée > capacité posée →
+1 colonne au bout de la rangée ; colonnes en attente de minerai et gisement non saturé → bandes demandées au champ ; jamais de retrait.
**Réservation : le TERRAIN seulement** (exigence du lead) : la place de la rangée est tenue aux tuiles, la pose commence dès que la PREMIÈRE
bande ou colonne est payée ; aucun projet ne garde le matériel de toute la rangée avant de poser (pas de « reserve:materiaux », frein n° 5).
Directive du DC (8/11, 18 h 30) : le minerai qui dort dans les coffres de tête de bande ou de colonne est raccordé au collecteur et au bus,
pas laissé en coffre ; la cible reste la saturation (« toutes les cases couvertes par des foreuses »).

## 6. Pose par lots et interfaces

Aujourd'hui un point d'appui par case de 8 × 8 (`build.lua:2709-2716`) et une tâche par point (`build.lua:3958-3994`) : une bande se pose en
une douzaine de petits voyages. Cible : UNE tâche par bande (ou par colonne) qui porte tout son kit, prise au QG une fois, posée en un passage
le long de son axe. **Une seule implémentation, celle du lot `pose-par-lots`** ; mes entités portent leur groupe (`e.lot`) et sont triées
le long de l'axe. Autres interfaces (accords du 8/11) :
- **MALL** : mes sorties de plaques sont son entrée. `f.mega.deps[g].sorties = { { item, x, y, dir, rate, belt } }` triées, publiées dès
  qu'une colonne POSÉE produit ; un tapis = un objet sur ses deux voies ; le tronc vers la tête du mall est au MALL (mes tapis s'arrêtent aux
  bouts publiés) ; d'ici là le quai reste la source, ramenée par le rapatriement ; le bus d'entrée du mall se dimensionne sur la somme des `rate`.
- **PURETÉ** : tout tapis du collecteur et du bus passe le garde-fou au plan (`script/team/purete.lua` : `Pur.fronts` dans le coût de l'A*,
  `Pur.check_route` sur le tracé trouvé ; refus « purete: <cause> »).
- **COURANT** : la ligne longue distance est celle du lot `courant-libre` (aucune seconde ligne de poteaux) ; la décision attend le courant.

## 7. Fichiers

- **Tranche 1 (ce lot)** : `shared/team/mega_fonderie.lua` (Mf.size, Mf.decide, Mf.block, Mf.verify, Mf.grow, Mf.line), `tests/mega_fonderie_test.lua`
  (mutants, coût), `script/team/mega_fonderie.lua` (décision, `f.mega`, `[FO-MEGA]`), `settings/mega_fonderie.lua`, `locale/{fr,en}/mega_fonderie.cfg` ;
  touché : `script/ai3/capitalisation.lua` (champ `Capi.Mega`, étape 11 ; 199 locales, aucune de plus).
- **Tranche 2, pose du bloc** : `Build.SITES.mega` (dans `script/team/mega_fonderie.lua`, comme `Build.SITES.champ`), place du rectangle au bord du champ.
- **Tranche 3, collecteur et bus** : `shared/team/champ.lua` (option de sortie « bus » d'une bande), tracé du faisceau de N lignes (traversée en tranches).
- **Tranche 4, pose par lots et bus de plaques** (module neuf : `build.lua` est à 198 locales sur 199).
- **Commun** : `shared/team/rangee_bus.lua` + `tests/rangee_bus_test.lua` (41 OK, 11 mutants ; passe de 4 000 tuiles ≤ 65 k instructions).
Réutilisé : `Ch.plan`, `Champ.data`, `Co.network` (charbon), `Fd.furnaces_for`, `Fonte.balance`, `Db.lane_capacity`, `Cv.saturation`, `Elec`,
la base de motifs, la ligne de `courant-libre`, la pose par lots de `pose-par-lots`, le garde de pureté.

## 8. Coût par pensée

Décision : O(1) par gisement, 2 gisements au plus par pensée, à l'étape 11 seulement. Plan : calculé seulement pour une décision neuve
(signature de la taille), sur un ÉCHANTILLON de 3 colonnes (`Mf.sample` : la première, une du milieu, la dernière partielle ; les colonnes
2 à C − 1 sont des translations). Mesuré par `debug.sethook` : bloc ENTIER de 12 colonnes de 64 fours, plan + contrôle = 1 015 k
instructions (≈ 13 à 25 ms : refusé) ; échantillon, décision complète (taille, plan, contrôle, coût d'une colonne) = **282 k au pire**
(≈ 3,8 ms), plafond du test 400 k, mutant « échantillon de 12 colonnes » refusé. Gisement de 1 000 tuiles : environ 60 k.

## 9. Critères mesurables sur `etape1-geants` (❔ propositions, à valider)

- **K1** : toute équipe qui a du courant décide sa méga-fonderie sur un gisement géant avant 20 min ([FO-MEGA] DECIDE), sinon une cause écrite.
- **K2** : à 40 min, couverture du gisement géant ≥ 50 % de ses tuiles (aujourd'hui 21 % d'un gisement de 1 000, 10 % de 2 000).
- **K3** : à 40 min, le bloc sort ≥ 15 plaques/s (deux colonnes pleines, 900 /min) par équipe qui a décidé.
- **K4** : aucune foreuse électrique ne dépose dans un four sur un gisement doté d'une méga-fonderie.
- **K5** : portée `mega:think` < 5 ms au pire, mesurée au profileur.

## 10. État de la tranche 1 (8/11, branche `mega-fonderie`)

Fait et testé HORS JEU seulement (aucun Factorio lancé : le DC joue) : règle pure (`tests/mega_fonderie_test.lua`, 200 OK, 20 mutants,
propriété « toute taille acceptée donne un plan juste » sur un balayage de 192 jeux de données, 4 320 essayés à la main, 0 faux) ; runtime
branché dans la capitalisation (E1, `Ia3.plan` → `Capi.think`, étape 11), factions ET votre équipe (`tests/mega_fonderie_moteur_test.lua`,
38 OK, 10 mutants) ; réglage `fo-war-mega-fonderie` (vrai ; l'intégrateur ajoute `require("settings.mega_fonderie")` à `settings.lua`, sans quoi
le réglage n'existe pas et rien ne tourne). Rien n'est encore POSÉ : la décision, sa taille et ses refus sont écrits (`f.mega`, `[FO-MEGA]`).
Moteur simulé (partie de 15 min, 4 factions et votre équipe, réglage allumé) : aucune erreur, 69 lignes `[FO-MEGA]`, toutes des refus ; le
moteur simulé ne peut pas décider (recensement à 1 tuile par gisement, prototypes sans rayon de foreuse : `Champ.data` répond « foreuse ou
minerai »). La décision n'est donc prouvée qu'avec `Champ.data` doublé. À prouver en moteur réel : micro-banc de décision (gisement de
1 000 tuiles, centrale finie, 2 500 ticks), puis `etape1-geants`.

## 11. Tranche 2 (A2, 9/11) : la décision ORDONNE le champ, ses bandes partent EN AVANCE

Constat de la tranche 1 (lu sur la partie géants-b36e23b2) : la décision n'avait aucun lecteur ; le champ ne bâtit qu'une bande à la fois par
gisement. Levier A2, validé par le lead le 8/11 : aligné sur la ligne de bande (`ligne-bande`, fusionné dans cette branche), parallélisme
borné par ce que le stock paie, sans priver la défense ni le mall.

Chaîne (déclencheur → décision → action → effet) :
1. `Mega.think` (étape 11, une fois par minute) lit un gisement : `Mf.decide` → « decide » (`script/team/mega_fonderie.lua`).
2. `order_field` : `MigChamp.want(f, dep, tick, Mp.par_max(rec))` (`migration_champ.lua`, `Mig.want`) : le champ est « voulu » (servi d'abord,
   aucune paire exigée, gisement sans avant-poste créé s'il y a un réseau alimenté à portée), `st.mega_par` = bandes en vol au plus (plafond 3,
   jamais plus que de lignes de bus). Journal `[FO-MEGA] ... POSE : champ N voulu` (ou la cause : aucun réseau alimenté à portée).
3. `ahead_step` (`Mig.think`, après le balayage) : quand la bande PRINCIPALE du cadre est au chantier (matières réunies), une bande de plus est
   demandée au plan directeur si `Mp.allow` (`shared/team/mega_pose.lua`) le permet : courant, pas d'ennemi, pas de paire thermique sous la
   bande (voie principale), moins de bandes en vol que le plafond, fer libre ≥ (1 + marge) × fer de la bande (livre de recettes), pile.
   Journal `[FO-MIGRATION] ... bande N EN AVANCE demandee` / `posee` / `pas de bande en avance (<cause>)`.
4. `ahead_reap` : une bande en avance « fini » est comptée posée (`done_pr`), les suivantes l'ignorent ; `Mig.projects` rend leurs projets au
   cerveau (il fabrique leurs matières) ; `begin_band` ne déclare pas le champ « posé » tant qu'une bande est en avance.
Lecteurs de chaque état écrit : `st.mega_par` (`ahead_step`), `st.ahead` (`begin_band`, `ahead_reap`, `Mig.projects`), `st.ahead_retry`
(`ahead_step`), `rec.field` / `rec.pose_key` (`Mega.summary`, journal).

Preuve hors jeu : `tests/mega_pose_test.lua` (48 OK, 17 mutants refusés), `tests/mega_fonderie_moteur_test.lua` (52 OK, 14 mutants). Preuve en
moteur réel : micro-bancs `mega-decision` (K1, 13 OK) et `mega-pose` (14 OK : au plus 3 bandes en vol, 2 bandes du même champ posées en
parallèle, 49 foreuses électriques posées en 3 min de jeu après la décision), voir le rapport du lot.
Fichier d'intégrateur : `settings/mega_fonderie.lua` (déjà dans le dépôt) doit être requis par `settings.lua`.
