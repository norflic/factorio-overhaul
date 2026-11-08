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

## 5. Croissance

Le rectangle entier (C colonnes) est réservé au plan, comme la ligne dynamique (`Build.ligne_split`) ; les colonnes se posent par pas.
Chaque minute : relevé du minerai qui ARRIVE au bloc ; `Fonte.balance` en unités « colonne » et « bande » : entrée > capacité des colonnes
posées → +1 colonne ; colonnes en attente de minerai et gisement non saturé → bandes demandées au champ (jusqu'à la capacité posée + 1 ligne) ;
jamais de retrait. Une ligne de bus de plus naît avec sa colonne.

## 6. Pose par lots

Aujourd'hui un point d'appui par case de 8 × 8 (`build.lua:2709-2716`) et une tâche par point (`build.lua:3958-3994`) : une bande se pose en
une douzaine de petits voyages. Proposé : les pièces d'une bande portent `ligne = true` et des points d'appui tous les 2 × portée de pose le
long de la bande (`build.lua:2708` garde déjà un point d'appui posé d'avance) ; UNE tâche par bande porte tout le kit (foreuses, tapis,
poteaux), le PNJ le prend au QG puis marche la bande d'un bout à l'autre. À coordonner avec le worktree `pose-par-lots` (ne pas doubler).

## 7. Fichiers

- **Tranche 1 (ce lot)** : `shared/team/mega_fonderie.lua` (Mf.size, Mf.decide, Mf.block, Mf.verify, Mf.grow, Mf.line), `tests/mega_fonderie_test.lua`
  (mutants, coût), `script/team/mega_fonderie.lua` (décision, `f.mega`, `[FO-MEGA]`), `settings/mega_fonderie.lua`, `locale/{fr,en}/mega_fonderie.cfg` ;
  touché : `script/ai3/capitalisation.lua` (champ `Capi.Mega`, étape 11 ; 199 locales, aucune de plus).
- **Tranche 2, pose du bloc** : `Build.SITES.mega` (dans `script/team/mega_fonderie.lua`, comme `Build.SITES.champ`), place du rectangle au bord du champ.
- **Tranche 3, collecteur et bus** : `shared/team/champ.lua` (option de sortie « bus » d'une bande), tracé du faisceau de N lignes (traversée en tranches).
- **Tranche 4, pose par lots et bus de plaques** (module neuf : `build.lua` est à 198 locales sur 199).
Réutilisé : `Ch.plan`, `Champ.data`, `Co.network` (charbon), `Fd.furnaces_for`, `Fonte.balance`, `Db.lane_capacity`, `Cv.saturation`, `Elec`.

## 8. Coût par pensée

Décision : O(1) par gisement, 2 gisements au plus par pensée, à l'étape 11 seulement. Plan du bloc : recalculé seulement quand la taille
change (signature) ; pire cas (12 lignes × 64 fours, ~3 000 entités, contrôle compris) mesuré par `debug.sethook` dans le test, plafond
400 000 instructions (≈ 5 ms à 12 ns par instruction), avec un mutant qui le dépasse.

## 9. Critères mesurables sur `etape1-geants` (❔ propositions, à valider)

- **K1** : toute équipe qui a du courant décide sa méga-fonderie sur un gisement géant avant 20 min ([FO-MEGA] DECIDE), sinon une cause écrite.
- **K2** : à 40 min, couverture du gisement géant ≥ 50 % de ses tuiles (aujourd'hui 21 % d'un gisement de 1 000, 10 % de 2 000).
- **K3** : à 40 min, le bloc sort ≥ 15 plaques/s (deux colonnes pleines, 900 /min) par équipe qui a décidé.
- **K4** : aucune foreuse électrique ne dépose dans un four sur un gisement doté d'une méga-fonderie.
- **K5** : portée `mega:think` < 5 ms au pire, mesurée au profileur.
