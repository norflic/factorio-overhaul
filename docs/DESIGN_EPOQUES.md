# DESIGN_EPOQUES : bible des 15 époques (lot V1)

> **Rôle.** Ce document guide les 7 agents de production V3 (une famille chacun) et le contrôle V4. Il fixe,
> pour **15 époques × 7 familles**, la silhouette, la pièce ajoutée par niveau, les matériaux et la lumière,
> avec des enveloppes chiffrées que V4 peut vérifier. Les planches de concept viendront quand le pipeline de
> rendu V0 sera prêt : il n'y en a aucune ici.
>
> **Statut.** Proposition ❔. **Aucun design n'est validé tant que le Directeur Créatif n'a pas rendu son
> verdict sur capture** (OBJECTIFS D1 à D3). Toutes les mesures vanilla de ce document ont été faites sur les
> fichiers du jeu 1.1.91 (Lua des prototypes, PNG, `doc-html/prototype-api.json`) : rien n'est cité de
> mémoire. Ce qui n'est pas vérifié est marqué « non vérifié » (liste complète au §8).
>
> Rédigé le 21/10/2026, session 6, lot V1. Scripts et sorties brutes des mesures : `docs/epoques/mesures/`.

**Cadre validé par le Directeur Créatif (21/10, 18 h 07)**
- **Q6** : « oui c'est bien ». 2 niveaux par époque, soit **30 niveaux** par bâtiment. Le **centre de
  commandement a 15 niveaux : son niveau est l'époque**.
- **Q7** : « oui, mais en faite rajoutez carrément des branches de matière noire etc, en mode vraiment un truc
  avancé (il faut donc imaginer le scénario et les crafts également évidemment) ». La liste des 15 époques
  d'OBJECTIFS §6 est **validée telle quelle** ; les branches avancées sont conçues par le lot X0
  (`docs/SCENARIO_EPOQUES.md`). Ce document n'en fixe que les **règles visuelles** (§1.10).

**Comment lire.** Le §1 donne les règles générales, qui valent pour toutes les époques. Le §2 donne les fiches
techniques mesurées, le §3 la charge de rendu, le §4 les enveloppes par rang. Le §5 contient les 15 fiches
d'époque, **chacune indépendante** : changer le thème d'une époque ne touche qu'une section. Les questions sont
au §6.

---

## 0. Résumé

### Une ligne par époque
| Ère | Époque | Signature de silhouette (commune aux 7 familles) | Matériaux | Lumière propre |
|---|---|---|---|---|
| I Industrielle | 1 Pionnier | bas, trapu, irrégulier : sacs de sable, rondins, mât de bois | fer brut, bois, toile | lanterne la nuit seulement |
| I | 2 Forge | cubes cerclés, boucliers plats, créneaux d'acier | acier boulonné, cerclages, laiton | lueur de forge la nuit |
| I | 3 Vapeur | premières **cheminées rondes** verticales, manomètres | cuivre, laiton, fonte | **1re lueur de jour** : hublots ambrés |
| II Lourde | 4 Pétrole | **cuves horizontales**, passerelles à garde-corps, torchère | tôle jaune délavée, acier galvanisé | voyants orange, flamme animée |
| II | 5 Volcan | **blindage incliné** en écailles, troncs de pyramide | tungstène sombre, braise | fentes de braise qui pulsent |
| II | 6 Électricité | **piles d'isolateurs** empilées, bobines | céramique blanche, cuivre | arcs cyan animés |
| III Exotique | 7 Cristal | **pointes de cristal** asymétriques | bronze, pierre, cristal violet | cristaux qui respirent |
| III | 8 Marais | **bulbes de verre** ronds, conduits | verre vert-jaune, vert-de-gris | liquide luminescent, bulles |
| III | 9 Atome | **octogones chanfreinés**, tours de refroidissement | plomb, jaune d'avertissement | vert uranium (`uranium-glow`) |
| IV Haute techno | 10 Haute technologie | **dômes lisses**, antennes fouet ; les corps se lèvent | carénage gris clair, noir mat | voyants bleus clignotants |
| IV | 11 Titane | **ailerons** triangulaires, silhouette en flèche, pieds | alliage blanc patiné | lignes bleu-blanc qui courent |
| IV | 12 Supraconducteurs | **anneaux en lévitation**, premiers vides | noir profond, chrome, givre | anneaux cyan en rotation |
| V Stellaire | 13 Fusion | **tore de plasma** autour d'une sphère | céramique blanche, cuivre | plasma magenta qui tourne |
| V | 14 Orbite | **ailes de panneaux dorés**, paraboles (la plus large) | feuille d'or, cellules bleu nuit | balises rouges clignotantes |
| V | 15 Légende | **couronne** de flèches, base flottante, halo | or blanc, nacre | particules, halo maximal |

### Une ligne par famille
| Famille | Identité invariante (ce qui dit « c'est une … » à toutes les époques) | Fichier vanilla (niveau 1) | Pose de référence D1 |
|---|---|---|---|
| Centre de commandement (4×4, conteneur, **15 niveaux**) | le plus grand bâtiment ; une porte centrale au sud ; un **mât de commandement** (drapeau, balise, antenne, flèche) qui en est le point le plus haut | composition actuelle (`prototypes/levels.lua:252-266`), à redessiner | image unique |
| Mitrailleuse (2×2, `ammo-turret`) | tête tournante à **plusieurs canons** + caisse ou alimentation de munitions ; socle sous la tête | `turrets.lua:691-863` | tête « prepared », directions N, E, S, O |
| Tourelle laser (2×2, `electric-turret`) | tête tournante **sans canon**, une **lentille ou un émetteur** qui s'allume au tir ; socle à condensateurs | `turrets.lua:883-1041` | idem |
| Mur (1×1, `wall`) | bande continue qui se raccorde ; la **crête** porte la signature d'époque | `entities.lua:4903-5581` | pièce `straight_horizontal` (la plus fréquente), puis les 9 clés |
| Foreuse électrique (3×3, 4 directions) | cadre carré à 4 montants, **tige ou tour centrale verticale**, goulotte de sortie côté orientation | `mining-drill.lua:385-2609` | corps N, E, S, O (image 0) |
| Four en acier (2×2, brûleur) | foyer compact, **bouche lumineuse** au sud, **cheminée** à l'arrière droit d'où sort la fumée | `entities.lua:7208-7443` | image unique |
| Machine d'assemblage 2 (3×3) | machine carrée, **mécanisme animé sur le toit** (bras, engrenages), tuyaux N et S | `entities.lua:4703-4827` | image 0 |

**Document** : `<racine>\mods\factorio-overhaul\docs\DESIGN_EPOQUES.md` (branche du lot V1).

---

## 1. Règles générales

### 1.1 Cadre des niveaux (Q6 validée)
- L'époque `e` (1 à 15) contient les niveaux **`2e-1` (impair)** et **`2e` (pair)** de chaque famille, sauf le
  centre.
  - **Niveau impair** : nouvelle **silhouette** (rendu complet de l'époque).
  - **Niveau pair** : la silhouette impaire **plus une pièce** visible (§1.4, critère D1-1).
- **Centre de commandement** : 15 niveaux, **niveau = époque**. Chaque niveau est une silhouette complète ; il
  n'y a pas de pièce paire.
- **Niveau 1 = bâtiment vanilla inchangé** pour les 6 familles vanilla (aucune image à produire). C'est la
  référence du critère D1-3. Le niveau 2 est donc « vanilla + 1 pièce » : c'est le **pilote idéal** du pipeline
  V0, qui doit marier une pièce rendue à un sprite vanilla (H-V1).
- **Le centre d'époque 1 est redessiné** : la composition actuelle (corps de roboport + radar) se lit comme un
  bâtiment de fin de partie, ce qui contredit la progression (question Q-V1-4).

### 1.2 Les ères : 5 groupes de 3 époques
Les époques sont groupées par 3, comme les paliers logistiques (T1 à T5 aux époques 1, 4, 7, 10, 13) et les
ouvriers (+1 toutes les 3 époques).
- Au sein d'une ère, les formes sont **cousines**.
- D'une ère à l'autre, la rupture est **forte**. Le test de la vignette (D1-2) s'appuie sur ce double niveau :
  l'ère se lit au premier coup d'œil, et l'époque à la hauteur et au nombre de dépassements.

| Ère | Époques | Langage de forme | « Événements » de silhouette (dépassements) | Vide minimal (§1.4) |
|---|---|---|---|---|
| I Industrielle | 1-3 | boîtes basses, matériaux bruts, premières verticales | 1 à 2 | 0 |
| II Lourde | 4-6 | cylindres, pentes, empilements ; plus large et plus haut | 2 à 3 | 0 |
| III Exotique | 7-9 | formes organiques ou rondes, pointes, bulbes, octogones | 3 à 4 | 0 |
| IV Haute techno | 10-12 | lisse, élancé, **sur pieds**, premières pièces flottantes | 4 à 5 | croissant |
| V Stellaire | 13-15 | anneaux lumineux, ailes, couronnes, **base flottante** | 5 à 6 | maximal |

### 1.3 Grammaire commune : 4 strates
Chaque silhouette se décrit en 4 strates. Les fiches d'époque les nomment dans cet ordre.

| Strate | Rôle | Règle |
|---|---|---|
| **Socle** | contact au sol | Pour être vue, une pièce de socle doit **dépasser de l'emprise** (F42), de 0,10 à 0,25 tuile, ou passer en `integration_patch`, une décalcomanie au sol (§1.8). |
| **Corps** | identité de la famille | Il porte les invariants du §0 : une mitrailleuse garde toujours ses canons, un four sa bouche lumineuse. |
| **Sommet** | point le plus haut | **Il porte la signature d'époque**, parce que c'est lui qui reste lisible sur une vignette de 64 px. |
| **Accessoires** | dépassements latéraux ou frontaux | C'est là que se place la **pièce du niveau pair**. |

**Kit d'époque** : chaque époque définit 4 à 6 accessoires 3D (liste dans sa fiche). Ils sont modélisés une
fois et employés par les 7 familles. C'est ce qui rend les familles d'une même époque cousines, et c'est aussi
une économie de modélisation (§3.3).

### 1.4 Enveloppes, lisibilité et tests D1
**Définitions** (coordonnées en tuiles, origine au centre de l'entité, y vers le bas, emprise de côté `s`).
- **O** : dépassement **au-dessus du bord haut de l'emprise** du sommet des masses principales, soit
  `-(haut de la boîte) - s/2`. Les tiges fines (moins de 0,15 tuile de large : mâts, antennes, paratonnerres)
  sont notées à part et ne comptent pas dans O.
- **L** : largeur visuelle maximale de la boîte des masses.
- **Masque** : pixels d'alpha ≥ 128 des couches de l'entité, sans les couches d'ombre (`draw_as_shadow`), de
  lumière (`draw_as_light`) et d'éclat (`draw_as_glow`), et sans l'`integration_patch` (décalcomanie au sol).
  ❔ Ce périmètre est une proposition de mesure, à valider.
- **Vide V** : part du masque du niveau 1 que le niveau impair de l'époque laisse transparente.

**Croissance.**
- O croît **linéairement** du niveau 1 mesuré jusqu'au plafond de l'époque 15. L croît de même.
- Les valeurs par rang sont au §4. Elles sont reprises dans chaque fiche d'époque.
- **Plafonds proposés** ❔ (Q-V1-2), choisis pour ne pas masquer les bâtiments placés au nord :

| Famille | O vanilla mesuré | O plafond (époque 15) | L max | Raison du plafond |
|---|---|---|---|---|
| Centre | 0,41 | 3,60 | 3,90 | bâtiment unique, il doit dominer |
| Mitrailleuse | 0,84 | 2,40 | 2,20 | les tourelles se posent en ligne derrière les murs |
| Laser | 1,02 | 2,60 | 2,10 | idem |
| Mur | 0,25 | 1,00 | 1,00 (la pièce doit se raccorder) | un mur plus haut cache les tourelles derrière lui |
| Foreuse | 0,38 | 1,60 | 3,20 | posée en rangées serrées |
| Four | 0,28 | 1,60 | 2,20 | posé en rangées serrées |
| Assembleur 2 | 0,06 | 1,50 | 3,10 | posé en rangées serrées |

**Pourquoi des vides aux ères IV et V (critère D1-3).**
- Le recouvrement se mesure par `IoU = |A1 ∩ A30| / |A1 ∪ A30|` sur les masques (proposition de mesure).
- Si le niveau 30 **contient** tout le niveau 1, alors IoU = A1/A30. Avec les plafonds ci-dessus, on obtient
  0,47 (laser) à 0,83 (assembleur) : **le critère échoue** pour 6 familles sur 7.
- Il faut donc que les silhouettes hautes **laissent vide** une part de l'ancienne. Le §4 chiffre cette part
  (cible IoU ≤ 0,45, avec une marge) : jusqu'à 35 % pour l'assembleur et 30 % pour le four.
- D'où la direction artistique des ères IV et V : corps sur pieds, pièces en lévitation, structures ajourées.
- Une alternative est d'aller beaucoup plus haut, sans vide : il faudrait alors O ≈ 4 tuiles pour le four et
  O ≈ 5,3 tuiles pour l'assembleur. C'est la question Q-V1-1.
- **Rappel mesuré** : le design rejeté de la session 5 (E25) donne IoU(niveau 1, niveau 10) = **0,65 à 0,81**
  (`mesures/silhouettes_vanilla.txt`). Le critère D1-3 l'aurait refusé automatiquement.

**Tests et indicateurs automatiques proposés à V4** ❔ (ils aident le verdict du Directeur Créatif sans le
remplacer).

| Critère | Protocole | Indicateur automatique |
|---|---|---|
| D1-1 test du gris | Les 30 niveaux côte à côte, en niveaux de gris, au zoom 1. | **Niveau pair** : la pièce ajoute au moins **0,10 tuile²** de masque hors du masque impair (environ 100 px au zoom 1), ou change la luminance de ±20/255 sur au moins 0,15 tuile². **Niveau impair** : IoU avec le niveau pair précédent ≤ 0,85. |
| D1-2 test de la vignette | Les 15 niveaux impairs en masques noirs, **à la même échelle** (le plus grand tient dans 64 px, ce qui garde les tailles relatives), mélangés, à remettre dans l'ordre. | O ne décroît jamais ; IoU entre époques consécutives ≤ 0,85 ; nombre d'événements de silhouette dans la fourchette de l'ère (§1.2). |
| D1-3 recouvrement | Niveau 1 contre niveau 30, même pose, même origine, 64 px par tuile. | IoU < 0,50 (cible de production ≤ 0,45), maximum sur les poses de référence (N, E, S, O pour les tourelles et la foreuse). |
| D1-4 emprise | — | `collision_box` et `selection_box` identiques au vanilla à tous les niveaux. `drawing_box` agrandie à l'enveloppe (§1.8). |

Un **outil de mesure réutilisable** existe déjà : `docs/epoques/mesures/measure.py`. Il compose des couches
hr (frame, scale, shift) dans un repère en tuiles, puis calcule boîte, aire, IoU, couleur et ombre. Il est
écrit en Python standard, avec un décodeur PNG maison. V4 peut le reprendre dans
`tools/render/check_silhouettes.py`.

### 1.5 Matériaux et palette mesurable
**Ce que mesure le vanilla** (corps rendu, pixels d'alpha ≥ 128 ; `mesures/silhouettes_vanilla.txt`).

| Famille | RGB moyen | Luminance p5 / p50 / p95 (sur 255) | Saturation moyenne |
|---|---|---|---|
| Mitrailleuse | (77, 68, 59) | 4 / 52 / 194 | 0,26 |
| Laser | (90, 82, 74) | 6 / 60 / 236 | 0,23 |
| Mur (droit) | (71, 64, 55) | 23 / 51 / 177 | 0,25 |
| Foreuse N | (86, 76, 70) | 14 / 71 / 167 | 0,20 |
| Four | (66, 60, 45) | 4 / 46 / 169 | 0,36 |
| Assembleur 2 | (68, 61, 55) | 8 / 48 / 166 | 0,40 |
| Centre actuel | (77, 72, 62) | 12 / 56 / 181 | 0,27 |

**Le style Factorio est donc sombre, chaud, peu saturé, avec des reflets francs** (p95 de 166 à 236).

**Règles de palette.** Elles se vérifient sur le **rendu**, pas sur l'albédo.
1. La luminance médiane du corps suit la cible de l'époque (tableau ci-dessous, ±10). Elle reste entre 40 et 110.
2. p95 ≤ 240 : aucun blanc pur, même pour l'or blanc. La patine, l'usure et l'occlusion ambiante sont
   obligatoires.
3. La saturation moyenne du corps reste ≤ 0,45. Les couleurs vives vivent dans les couches émissives, ou dans
   des accents qui couvrent au plus 15 % du corps.
4. **La couleur vient du rendu, jamais d'une teinte** (F36, F38 : une teinte ne fait que multiplier). Seule
   exception : les passes **émissives et lumineuses rendues en blanc ou en gris**, que l'on colore par `tint`.
   Une teinte sur du blanc donne exactement la couleur voulue. Le vanilla le fait déjà : les DEL de la foreuse
   et la lumière de la balise sont des PNG gris (type 4) teintés à l'exécution (`apply_tint = "status"`,
   `mining-drill.lua:278`).

| Époque | Albédos proposés (sRGB) | Luminance médiane cible du corps | Couleur émissive |
|---|---|---|---|
| 1 | fer brut #5A5048, bois #6B4F35, toile #8A7A5A | 50 | (lanterne #FFB060, la nuit seulement) |
| 2 | acier #5C6168, cerclage #2E2C2A, laiton #8C7440 | 52 | forge #FF6A20 (nuit) |
| 3 | cuivre #8A5A3A, laiton #9C7E45, fonte #3A3634 | 58 | ambre #FFC060 |
| 4 | tôle jaune délavée #8C7A3A, galvanisé #6E7378 | 60 | orange #FF8C1A |
| 5 | tungstène #3E3D42, rouille brûlée #5A3A2A | 42 | braise #FF4A10 |
| 6 | céramique #D8D4C8, cuivre de bobine #B0703A, acier #5C6168 | 64 | cyan #60D0FF |
| 7 | bronze #6A5236, pierre #4A4038, cristal #9A5CFF | 55 | violet #B070FF |
| 8 | verre #8FBF4A, vert-de-gris #4F6B5A, caoutchouc #2A2A28 | 60 | vert-jaune #A8FF3A |
| 9 | plomb #4A5058, jaune d'avertissement #C9A227, béton #7A7670 | 56 | vert uranium #5CFF4A |
| 10 | carénage #A8ADB3, noir mat #222428 | 82 | bleu #3AA8FF |
| 11 | alliage blanc #C9C6BE, titane #8E9AA6 | 100 | bleu-blanc #BFE6FF |
| 12 | noir profond #26282E, chrome #9AA3AD, givre #DDEEFF | 60 | cyan #4AF0FF |
| 13 | céramique blanche #D9D6CF, cuivre #B0703A | 92 | plasma #FF4FD8, cœur #FF9A3A |
| 14 | feuille d'or #C9A23A, blanc #CFCBC2, cellules #1E2A55 | 88 | balise #FF2A2A, cellules #2F6BFF |
| 15 | or blanc #E8DCB0, nacre #D8D2C8, cristal clair | 108 | blanc doré #FFF2C0 |

### 1.6 Lumière
**Soleil.** Il vient du **nord-ouest** pour tous les rendus : ombres portées vers l'**est-sud-est**. Décalage
mesuré entre le centroïde de l'ombre et celui du corps :

| Famille | Décalage x | Décalage y |
|---|---|---|
| Mitrailleuse | +1,31 | +0,39 |
| Laser | +1,40 | +0,52 |
| Four | +0,71 | +0,45 |
| Centre actuel | +0,66 | +0,55 |
| Assembleur 2 | +0,32 | +0,04 |
| Mur | +0,31 à +0,36 | +0,55 à +0,75 |

Toutes les ombres vanilla sont des **couches séparées** `draw_as_shadow`, en PNG gris + alpha (type 4). V0
calibre l'angle exact ; ces chiffres servent à valider ses rendus.

**Éclat de jour (D2-1)** : couche `draw_as_glow`, dessinée comme un sprite **puis** comme une lumière
(`prototype-api.json`, `SpriteParameters.draw_as_glow`). Pour une `WorkingVisualisation`, on combine
`draw_as_light = true` avec `draw_as_sprite = true` (valeur par défaut).
- Dès l'**époque 3**, chaque niveau a au moins une zone émissive **visible de jour**.
- Chaque zone fait au moins 8 × 8 px hr (4 × 4 px au zoom 1). Une bande de quelques pixels ne se voit pas (F37).
- Sa luminance dépasse d'au moins 80/255 la médiane du corps.
- Part émissive du corps proposée ❔ : 1 % (époque 3), 3 % (5), 5 % (7), 7 % (10), 10 % (13), 12 à 15 % (15).

**Halo de nuit proportionnel au niveau (D2-3)** ❔ : intensité `I(N) = 0,05 + 0,02·N` et rayon
`S(N) = s × (1 + 0,05·N)` tuiles, où N est le niveau (1 à 30) ; pour le centre, N = 2e.
- Ce halo passe par une `LightDefinition` de `working_visualisations` (foreuse, four, assembleur), par
  `glow_light_intensity` (laser), ou par une couche `draw_as_light` (centre, mitrailleuse, mur).
- Pour le mur, il se limite à une couche `draw_as_light` dans le sprite, de rayon au plus 1 tuile : des
  centaines de murs posent des centaines de lumières (coût GPU non mesuré).

**Animations (D2-2) : ce que chaque type permet** (lu dans `prototype-api.json`, voir F44 proposé).

| Famille | Champ graphique | Animable par prototype ? | Moyen d'animation |
|---|---|---|---|
| Centre | `ContainerPrototype.picture` : **Sprite** | **non** | dessin par script : `rendering.draw_animation` (prototype `animation`) et `rendering.draw_light`, attachés à l'entité et recréés à chaque remplacement par le crochet `Levels.on_replaced` |
| Mur | `WallPrototype.pictures` : **SpriteVariations** | **non** | lueurs fixes seulement (`draw_as_glow`, `draw_as_light`) ; aucune animation (des milliers d'objets de rendu seraient nécessaires) |
| Mitrailleuse, laser | `base_picture` : Animation4Way ; tête : RotatedAnimation4Way ; `energy_glow_animation` (laser) | oui | **animer le socle** (1 direction) ; ne jamais ajouter d'images à la tête hors tir (×64 directions) |
| Foreuse | `graphics_set.working_visualisations` | oui | visualisations avec `always_draw`, `fadeout`, `effect` |
| Four, assembleur | `animation` (Animation4Way), `working_visualisations`, `idle_animation` | oui | `effect = "flicker"` ou `"uranium-glow"`, `light` |

- Les **particules** se font en feuilles d'animation, pas en particules moteur : c'est gratuit au tick et
  déterministe.
- Une animation **invariante par rotation** (particules, arcs, pulsation d'un halo) se rend une fois et sert à
  toutes les familles et à toutes les directions.
- Calendrier proposé :

| Époque | Animation |
|---|---|
| 4 | flamme de torchère |
| 5 | pulsation des braises |
| 6 | arcs |
| 7 | respiration des cristaux |
| 8 | bulles |
| 9 | `uranium-glow` (gratuit) |
| 10 | voyants qui clignotent (`frame_sequence`) |
| 11 | chenillard |
| 12 | rotation des anneaux (modules fixes seulement) |
| 13 | plasma qui tourne |
| 14 | balises qui clignotent |
| 15 | particules partagées |

### 1.7 Pièges moteur à respecter (déjà payés, RD_LOG)
| Fait | Règle de production |
|---|---|
| **F42** : un socle sous un sprite qui couvre toute l'emprise est invisible | Toute pièce ajoutée doit **sortir du masque** existant. Part de l'emprise couverte par le vanilla (mesurée) : four **87 %**, assembleur **77 %**, mitrailleuse 70 %, centre actuel 66 %, foreuse 52 à 62 %, laser 44 %. Sur le four et l'assembleur, une pièce ne se voit que si elle dépasse en haut ou sur les côtés (assembleur : 0,22 tuile libre de chaque côté). |
| **F42, tourelles** : la tête (couche `object`) est dessinée **par-dessus** le socle (`lower-object`) | La pièce paire d'une tourelle se place dans la **zone du socle toujours visible**, hors de l'enveloppe balayée par la tête sur 64 directions. Vanilla : mitrailleuse 51 % du socle, y ∈ [-0,66 ; +0,72], **sauf l'avant-centre**, que le canon couvre quand il vise au sud ; laser 71 %, y ∈ [-0,42 ; +0,69]. **À recalculer à chaque époque** avec la tête de l'époque. |
| **F36 / F38** : une teinte ne fait que multiplier | La couleur vient du rendu (§1.5). Teinter seulement des passes émissives blanches. |
| **F37** : la copie lumineuse d'un masque fin ne se voit pas | Une lueur, c'est une **vraie couche alpha** émissive d'au moins 8 × 8 px hr, ou un halo `draw_as_light` de toute la pièce. |
| **F23** : une RotatedAnimation à plusieurs fichiers exige `slice` | Têtes de tourelles : soit `stripes` comme le vanilla (`turrets.lua:124-146`, hr `:155-177`), soit `filenames` + `slice` + `lines_per_file` (obligatoires : `prototype-api.json`, `RotatedAnimation.slice`). Feuilles ≤ 4096 px de côté (prudence, limite non vérifiée). |
| **F39** : le remplacement exige un `fast_replaceable_group` commun | Inchangé : tous les niveaux d'une famille gardent le groupe. |
| **F43** : paramètres de `localised_name` en chaînes | Inchangé. |

### 1.8 Précision du rendu (D1-5, D3) et points d'ancrage de jeu
1. **Une caméra, une origine.** Toutes les couches d'un niveau (corps, ombre, émissif, pièce) sortent du même
   rendu ou de rendus calés sur la même origine. Les `shift` sont **générés par le pipeline**, jamais réglés à la
   main, et restent des multiples de 1/64 de tuile (1 px hr).
2. **Dimensions hr paires** : la basse résolution (hr/2) tombe alors juste. Le vanilla a des tailles impaires
   (four hr 171 × 174), source de décalages d'un demi-pixel entre qualités graphiques.
3. **Ombre des pièces séparées** : au sol, dans la couche `draw_as_shadow` de la pièce. Sur le corps, dans une
   couche `blend_mode = "multiplicative"`, rendue avec le corps comme receveur d'ombre. Ce mode existe dans
   `BlendMode` ; son rendu en jeu n'est **pas vérifié**.
4. **`drawing_box`** = enveloppe visuelle du niveau. Selon `prototype-api.json`, elle sert à cadrer l'entité
   dans l'interface. Que le moteur découpe ou non les sprites hauts en bord d'écran n'est **pas vérifié** :
   V3 doit faire une capture d'un bâtiment haut en bord d'écran.
5. **`water_reflection`** : à refaire par époque, ou à **retirer** (mitrailleuse, laser, four, centre). Garder
   le reflet vanilla sous une autre silhouette est un défaut D3.
6. **Points d'ancrage de jeu** : ils doivent suivre la nouvelle géométrie, faute de quoi c'est un défaut D3.

| Famille | Champ | Valeur vanilla et source |
|---|---|---|
| Mitrailleuse | `attack_parameters.projectile_center` | {0, -0,0875} (`turrets.lua:831`) |
| Mitrailleuse | `projectile_creation_distance` | 1,39375 (`:830`) |
| Mitrailleuse | `shell_particle.center` | (`:838`) |
| Laser | `attack_parameters.source_offset` | {0, -3,423489/4} (`turrets.lua:1004`) |
| Laser | rayon `source_offset` | {0, -1,31439} (`:1019`) |
| Four | `energy_source.smoke[1].position` | {0,7 ; -1,2} (`entities.lua:7268`) : **la fumée doit sortir du haut de la nouvelle cheminée** |
| Foreuse | `vector_to_place_result` | {0, -1,85} (`mining-drill.lua:2592`) : la goulotte reste du côté de l'orientation |
| Foreuse | entrées de fluide | (-2,0), (2,0), (0,2) (`:407-412`) |
| Foreuse | connecteurs de circuit | `circuit_connector_definitions["electric-mining-drill"]` (`:2606-2608`) : garder un emplacement, ou redéfinir les points par époque |
| Assembleur | tuyaux | entrée (0,-2), sortie (0,2) (`entities.lua:4729, 4738`) : laisser l'ouverture des tuyaux au même endroit, ou rendre `pipe_picture` par époque (4 images) |

7. **Icônes** : l'icône d'un niveau est le rendu de sa pose de référence (64 px, 4 mipmaps), plus le numéro de
   niveau (`lib.tier_icons`). Elle sert aussi de vignette au test D1-2.
8. **Sols et socles** : un socle qui doit rester visible passe en `integration_patch` (`EntityWithHealth`,
   Sprite4Way, couche `lower-object`) ou en `integration` (tourelles) **plus grand que l'emprise**. Un patch au
   sol par époque et par taille d'emprise (2×2, 3×3, 4×4) suffit, partagé entre familles (§3.3).

### 1.9 Contrat de fichiers proposé à V0, V2 et V3 ❔
- Arborescence : `graphics/levels/<famille>/e<NN>/` et `graphics/levels/<famille>/e<NN>/piece/`.
- Un fichier par module (`socle`, `tete`, `corps`, `meca`, `piece`) et par passe :
  `-couleur`, `-ombre`, `-emissif` (gris, teinté en jeu), `-masque` (couleur d'équipe, tourelles), `-lumiere`.
- Version hr seulement, chargée aussi en basse qualité, ou `hr` + basse résolution réduite automatiquement.
  À trancher par V0.
- Côté `prototypes/levels/<famille>.lua` (V2) : une fonction de visuel par niveau qui assemble les couches de
  l'époque `ceil(n/2)`, plus la pièce si `n` est pair. La pièce est une **couche ajoutée** au rendu impair :
  après le corps si elle est devant ou au-dessus, avant le corps si elle passe derrière.

### 1.10 Branches avancées (Q7) : règles visuelles seulement
X0 en définit le contenu (matière noire, etc.). Ici, seulement **comment une branche se voit** et **ce qu'elle
coûte**.
1. **Une branche est une variante d'un niveau, pas un niveau.** Elle garde **la silhouette de l'époque** et
   n'entre pas dans les tests D1-1 à D1-3 (la silhouette, c'est l'époque).
2. **Elle se reconnaît à 3 marques, toujours aux mêmes endroits de chaque famille** :
   - **(a) une couleur émissive réservée.** Sa teinte est à au moins 30° de l'émissif de l'époque où elle
     apparaît. Son motif est propre à la branche (veines, battement, scintillement) ;
   - **(b) un matériau de branche** sur une **zone de branche** définie par famille (panneaux, inserts), qui
     couvre au plus 25 % du corps ;
   - **(c) un emblème de branche** facultatif : petite pièce de 0,15 tuile² au plus, invariante par rotation,
     posée au **point d'emblème** de la famille. Ce point se trouve dans la zone toujours visible pour les
     tourelles, au sommet des machines.
3. **Coût en images.**

| Marque | Coût |
|---|---|
| Couleur émissive | **0 rendu** : passe émissive blanche teintée |
| Matériau de branche | 1 rendu par pose **du module qui porte la zone** : socle ou corps fixe = 1 pose (4 pour la foreuse) ; **interdit sur les têtes de tourelles** (124 à 148 poses) |
| Emblème | 1 pose par famille, ou une seule pour toutes s'il est commun |
| Total par branche et par époque | environ 7 à 12 poses pour les 7 familles (contre 300 à 400 pour une époque complète) |

4. **Prototypes** : une variante portée par l'entité multiplie les prototypes (familles × niveaux × branches).
   Une variante dessinée par script à l'exécution (`rendering.draw_sprite` sur la zone de branche) n'en ajoute
   aucun. Le choix revient à X0 et V2 ; le coût en images est le même.
5. **Si une branche a ses propres niveaux**, il faut repasser par le §3 : le coût change d'échelle.

---

## 2. Fiches techniques par famille (mesurées)

Sources :
- `<racine>\data\base\prototypes\entity\*.lua` (fichier et ligne cités) ;
- dimensions des PNG lues dans leur en-tête ;
- silhouettes composées des couches hr (64 px par tuile, échelle 0,5) par `docs/epoques/mesures/measure.py`.

Sorties brutes :
- `silhouettes_vanilla.txt` ;
- `tourelles_foreuse_lumieres.txt` ;
- `assembleur_zone_animee.txt`.

Toutes les couches hr sont en `scale = 0.5`. Un `util.by_pixel(x, y)` vaut x/32 tuile.

### 2.1 Synthèse
| Famille | Collision / sélection | Directions | Images d'animation | Silhouette vanilla (pose de référence) |
|---|---|---|---|---|
| Centre (conteneur) | collision ±1,7 / sélection ±2 (copiées du roboport, `entities.lua:11529-11530`) | 1 | 0 (Sprite) | L 3,41 × H 4,45 ; O 0,41 ; aire 10,82 t² ; emprise couverte à 66 % |
| Mitrailleuse | ±0,7 / ±1 (`turrets.lua:701-702`) | tête 64 (tir) et 4 (repli) ; socle 1 | tir 2, déploiement 5 | L 1,95 × H 2,56 ; O 0,84 ; aire 3,28 ; 70 % |
| Laser | ±0,7 / ±1 (`turrets.lua:891-892`) | tête 64 et 4 ; socle 1 | tir 1, déploiement 15 | L 1,72 × H 2,70 ; O 1,02 ; aire 2,26 ; 44 % |
| Mur | ±0,29 / ±0,5 (`entities.lua:4909-4910`) | 9 clés de connexion + 2 raccords à 4 directions | 0 | droit horizontal : L 1,00 × H 1,30 ; O 0,25 ; aire 1,24 ; 100 % |
| Foreuse | ±1,4 / ±1,5 (`mining-drill.lua:396-397`) | 4 | sortie 5, trépan 30, poussière 10 à 30 | N : L 2,94 × H 3,36 ; O 0,38 ; aire 4,99 ; 52 % |
| Four | ±0,7 / x ±0,8, y ±1 (`entities.lua:7242-7243`) | 1 | feu 48 | L 1,97 × H 2,30 ; O 0,28 ; aire 3,60 ; 87 % |
| Assembleur 2 | ±1,2 / ±1,5 (`entities.lua:4743-4744`) | 1 (même animation pour les 4 orientations) | 32 (tout le sprite) | L 2,56 × H 3,00 ; O 0,06 ; aire 6,98 ; 77 % |

### 2.2 Centre de commandement (`prototypes/levels.lua:221-289`)
**Construction actuelle.** `container` copié du coffre en acier (`entities.lua:7845-7912`), dont la boîte, la
santé, les sons et les résistances viennent du roboport. `picture` = couches dans cet ordre :
1. corps du roboport hr 228 × 277, shift by_pixel(2 ; 7,75) (`entities.lua:11564-11581`) ;
2. son ombre, 294 × 201, by_pixel(28,5 ; 19,25) (`:11582-11598`) ;
3. `base_patch`, 138 × 100 (`:11601-11619`) ;
4. portes haute et basse en image 0, 97 × 38 et 97 × 41 (`:11641-11678`) ;
5. radar en image fixe 0, déplacé de (-1,05 ; -1,45) et réduit à ×0,46 (×0,58 et -1,55 au niveau 7+) ;
6. haut de balise réduit à ×0,75 au niveau 4+, en (1,15 ; -1,25), et un second à ×0,65 au niveau 7+
   (`beacon-animations.lua:58-80`, 96 × 140).
Échelle du sprite +1,2 %/niveau.

**Défaut D3 trouvé à la lecture** (non vu en capture) : le radar posé sur le toit prend `pictures.layers[1]`
seulement (`prototypes/levels.lua:254, 262`), **sans son ombre** (la couche d'ombre du radar,
`radar-shadow.png`, est à `entities.lua:4290-4301`). Le radar flotte sans ombre.

**Contraintes de type.**
- `picture` est un **Sprite** : aucune animation, aucune visualisation de travail. Animer passe par le script
  (§1.6).
- Pas de couleur d'équipe.
- Boîte de collision ±1,7 (4×4).

**Silhouette mesurée (niveau 1 actuel)** : x [-1,72 ; +1,69], y [-2,41 ; +2,05] ; ombre au centroïde
(+0,66 ; +0,55) du corps. IoU(niveau 1, niveau 10 actuel) = 0,73.

**Conséquence.**
- Un sprite fixe par niveau (15 au total), haut de 7,65 tuiles au plus à l'époque 15.
- Animations des époques 5 et suivantes par `rendering.draw_animation` (coût script : création au chantier,
  rien par tick ; à confirmer par H-L1).

### 2.3 Mitrailleuse (`turrets.lua:20-319`, `691-863`)
| Couche | Fichier hr | Image (px) | Disposition | shift hr | Remarque |
|---|---|---|---|---|---|
| Socle | `hr-gun-turret-base.png` 150 × 118 | 150 × 118 | 1 | (0,5 ; -1) | `base_picture`, couche `lower-object` (`:744-769`) |
| Masque du socle | `hr-gun-turret-base-mask.png` | 122 × 102 | 1 | (0 ; -4,5) | `apply_runtime_tint`, couleur d'équipe (`:794-819`) |
| Ombre du socle | — | — | — | — | **commentée dans le vanilla** (`:770-793`) : le socle n'a pas d'ombre |
| Tête, tir | `hr-gun-turret-shooting-1..4.png` 264 × 2080 | 132 × 130 | 4 bandes × 16 directions × 2 images = **64 directions** | (0 ; -27,5) | `stripes` (`:147-179`) ; `prepared` = image 0, `attacking` = 2 images (`:733-734`) |
| Masque de tête | `hr-gun-turret-shooting-mask-1..4.png` | 58 × 54 | idem | (0 ; -32,5) | couleur d'équipe |
| Ombre de tête | `hr-gun-turret-shooting-shadow-1..4.png` 500 × 1984 | 250 × 124 | idem | (22 ; 2,5) | `draw_as_shadow` |
| Tête, déploiement | `hr-gun-turret-raising.png` 650 × 504 | 130 × 126 | 5 images × 4 directions | (0 ; -26,5) | repli = image 0 (`:715-723`) ; déploiement et repli = 5 images (`:724-743`) |
| Masque et ombre du déploiement | `-raising-mask` 240 × 248, `-raising-shadow` 1250 × 496 | 48 × 62 ; 250 × 124 | idem | — | — |

- Aucune lumière, aucun éclat.
- `rotation_speed` 0,015, `preparing_speed` 0,08.
- Mesures (`tourelles_foreuse_lumieres.txt`) :
  - la tête balaie, sur 64 directions, x [-1,00 ; +1,00], y [-1,84 ; +0,11] ;
  - son sommet varie de -1,84 à -1,50 selon la direction ;
  - le **socle toujours visible** représente **51 %** du socle (bas et coins avant).
- Couleur moyenne (77, 68, 59), luminance médiane 52.

### 2.4 Tourelle laser (`turrets.lua:321-515`, `883-1041`)
| Couche | Fichier hr | Image | Disposition | shift hr |
|---|---|---|---|---|
| Socle | `hr-laser-turret-base.png` | 138 × 104 | 1 | (-0,5 ; 2) |
| Ombre du socle | `hr-laser-turret-base-shadow.png` | 132 × 82 | 1 | (6 ; 3) |
| Tête, tir | `hr-laser-turret-shooting.png` 1008 × 960 | 126 × 120 | 8 × 8 = **64 directions**, 1 image | (0 ; -35) |
| Masque de tête | `-shooting-mask.png` 736 × 640 | 92 × 80 | idem | (0 ; -43,5) |
| Ombre de tête | `-shooting-shadow.png` 1360 × 736 | 170 × 92 | idem | (50,5 ; 2,5) |
| **Éclat de tir** | `-shooting-light.png` 976 × 928 | 122 × 116 | idem, additif | (-0,5 ; -35) |
| Déploiement (+ masque, ombre) | `-raising.png` 1950 × 504 ; `-raising-mask` 1290 × 320 ; `-raising-shadow` 2730 × 384 | 130 × 126 ; 86 × 80 ; 182 × 96 | **15 images × 4 directions** | (0 ; -32,5) |

- L'éclat de tir est l'`energy_glow_animation` (`:937`), avec `glow_light_intensity = 0.5` (`:938`).
- Mesures :
  - tête balayée x [-0,97 ; +0,97], y [-2,02 ; -0,19] ;
  - **socle toujours visible 71 %** (y ≥ -0,42) ;
  - éclat de tir RGB moyen (255, 85, 3), soit rouge-orangé.

### 2.5 Mur (`entities.lua:4903-5581`)
`pictures` : toutes les images sont des **SpriteVariations fixes**. Chaque clé a une couche principale et une
couche d'ombre ; les ombres sont une image unique répétée (`repeat_count`).

| Clé | Lignes | hr (image) | Variantes | shift hr | Boîte mesurée (y) | Implication |
|---|---|---|---|---|---|---|
| `single` | 4992-5037 | 64 × 86 | 2 | (0 ; -5) | [-0,75 ; +0,42] | mur isolé |
| `straight_vertical` | 5038-5083 | 64 × 134 | 5 | (0 ; 8) | [-0,75 ; **+1,08**] | la face avant **descend de 0,58 tuile dans la tuile du sud** pour couvrir le joint |
| `straight_horizontal` | 5084-5129 | 64 × 92 | 6 | (0 ; -2) | [-0,75 ; +0,55] | pièce la plus fréquente ; couvre 100 % de la tuile |
| `corner_right_down` | 5130-5175 | 64 × 128 | 2 | (0 ; 7) | [-0,75 ; +1,06] | angle avec descente |
| `corner_left_down` | 5176-5221 | 64 × 134 | 2 | (0 ; 7) | [-0,75 ; +1,06] | idem, en miroir |
| `t_up` | 5222-5267 | 64 × 134 | 4 | (0 ; 7) | [-0,75 ; +1,06] | T avec descente |
| `ending_right` | 5268-5313 | 64 × 92 | 2 | (0 ; -3) | [-0,75 ; +0,52] | fin de rangée |
| `ending_left` | 5314-5359 | 64 × 92 | 2 | (0 ; -3) | [-0,75 ; +0,53] | idem |
| `filling` | 5360-5380 | 48 × 56 | 8 | (0 ; -1) | [-0,41 ; +0,41] | bouche-trou (facultatif) |
| `water_connection_patch` | 5381-5420 | 116 × 128 | Sprite4Way (4) | (0 ; -2) | — | raccord à l'eau (facultatif) |
| `gate_connection_patch` | 5421-5460 | 82 × 108 | Sprite4Way (4) | (0 ; -7) | — | raccord à une porte (facultatif) |
| diodes et lumières | 5463-5576 | 72 × 44 | Sprite4Way | (-1 ; -23) | — | `draw_as_glow`, seulement avec porte et circuit |

- Au total, **41 images** par niveau (33 variantes + 8 raccords), plus 11 ombres.
- `visual_merge_group = 0` (`:4989`) : des murs de niveaux différents se raccordent entre eux. **Toutes les
  époques doivent donc partager les mêmes points de raccord** : même hauteur de crête au bord de tuile et même
  profil de joint.
- La correspondance exacte entre connexion et clé est déduite des noms et de la géométrie mesurée ; **non
  vérifiée en moteur**.
- Crête vanilla à 0,25 tuile au-dessus de la tuile ; face avant haute de 1,30 tuile.

### 2.6 Foreuse électrique (`mining-drill.lua`)
**Jeu sec** (`graphics_set`, `:429-1094`) : vitesse d'animation 0,4 (`:6`).

| Élément | Lignes | Directions | Images | hr (image) |
|---|---|---|---|---|
| Corps | 443-747 | N, E, S, O | 1 (`repeat_count` 5) | N 190 × 208, E et O 192 × 188, S 184 × 192 |
| Ombres du corps | — | N, E, S, O | 1 | ≈ 200 à 222 × 182 à 204 |
| Sorties | 475-497, 557-579, 697-719, 1013-1033 | N, E, O, S | **5** | 60 × 66, 50 × 74, 50 × 60, 84 × 56 |
| Trépan, arrière | 820-856 | vertical (N = S), horizontal (E = O) | **30 + 30** | 162 × 156 ; 80 × 160 |
| Ombre du trépan | 135-163, 225-253 | vertical, horizontal | 21 + 21 | — |
| Trépan, avant horizontal | 195-223, 969-977 | E = O | **30** | 66 × 154 |
| Cadres avant | 979-1085 | E, S, O | 1 | 136 × 148, 190 × 104, 134 × 140 |
| Poussières (teinte du minerai) | 767-967 | — | 10 et 30 | — |
| DEL d'état | 273-359, 1088 | 4 | 1 | `draw_as_light`, PNG gris teinté par l'état |
| Lumière secondaire | 375-381, 1092 | — | — | intensité 0,2, taille 2 |

**Jeu humide** (`wet_mining_graphics_set`, `:1096-2469`, minage avec fluide) :
- corps humides N, E, S, O (190 à 194 × 198 à 208) et leurs ombres ;
- cadres avant humides (4) ;
- fenêtres de fluide, fonds et flux en plans arrière et avant, **teintés par le fluide** (PNG gris), environ 21
  images fixes (`:1632-2314`).

**Autres éléments.**
- `integration_patch` : 4 directions, 216 à 236 × 214 à 230 (`:2471-2581`).
- `shift_animation_waypoints` : le trépan se déplace de -0,5 à +0,6 tuile (`:749-760`).

**Mesures** (pose N, image 0) :
- les montants laissent le **centre-bas ouvert** (trépan visible) ;
- le sommet de la tige oscille de -1,52 à -1,06 selon l'image ;
- E et O débordent de 0,20 tuile du côté de la sortie ;
- couleur (86, 76, 70), luminance médiane 71.

**Conséquence** : il y a 4 directions pour tout ce qui n'est pas invariant par rotation. La pièce paire se
place **au sommet de la tour centrale** et reste **invariante par rotation** : 1 rendu au lieu de 4.

### 2.7 Four en acier (`entities.lua:7208-7443`)
| Élément | Lignes | hr | Images | Couche |
|---|---|---|---|---|
| Corps | 7278-7295 | 171 × 174, shift (-1,25 ; 2) | 1 | principal |
| Ombre | 7296-7315 | 277 × 85, shift (39,25 ; 11,25) | 1 | `draw_as_shadow` ; ombre longue (jusqu'à x +3,36) |
| Feu | 7320-7347 | 57 × 81 (feuille 456 × 486) | **48**, `line_length` 8 | `draw_as_light` + sprite, `effect = "flicker"`, `fadeout` |
| Lueur | 7348-7362 | **basse résolution seulement**, 60 × 43 | 1 | additif, lumière |
| Intérieur allumé | 7363-7392 | 128 × 150 | 1 | additif, lumière |
| Lumière au sol | 7393-7425 | 152 × 126, shift (1 ; 48) | 1 | `draw_as_sprite = false` (nuit seulement) |

- `energy_source` brûleur : `smoke` en {0,7 ; -1,2} (`:7268`) et `light_flicker` (`:7257-7262`).
- Pas de direction, pas de circuit.
- Mesures : **87 % de l'emprise couverte**, O 0,28. Feu RGB moyen (157, 112, 39) ; lumière au sol
  (205, 103, 10).
- **Conséquence (F42)** : rien de ce qui reste dans l'emprise ne se voit. Les pièces passent au-dessus
  (cheminée, hotte) ou sur les côtés, ou au sol devant le four (dépassement sud).

### 2.8 Machine d'assemblage 2 (`entities.lua:4703-4827`)
| Élément | Lignes | hr | Images |
|---|---|---|---|
| Corps | 4752-4771 | 214 × 218 (feuille 1712 × 872), shift (0 ; 4) | **32**, `line_length` 8 |
| Ombre | 4772-4793 | 196 × 163 (feuille 1568 × 652), shift (12 ; 4,75) | 32 |
| Tuyaux | `assemblerpipes.lua:1`, `pipecovers.lua` | `hr-assembling-machine-2-pipe-N/E/S/W` | 4 directions |

- Aucune `working_visualisations` et **aucune lumière**. `alert_icon_shift` by_pixel(-3 ; -12) (`:4713`).
- **Zone animée mesurée** (pixels qui varient de plus de 32/255 entre les 32 images) : **30 % des pixels
  opaques**, concentrés dans le **haut-centre** (x ≈ -0,9 à +0,95, y ≈ -1,6 à +0,7). Le reste du corps est fixe.
- Mesures : 77 % de l'emprise couverte, 0,22 tuile libre de chaque côté, O 0,06. Couleur (68, 61, 55).
- **Conséquence** : on sépare **corps fixe (1 rendu)** et **mécanisme animé** (32 images rendues avec le corps
  en cache) : 15 + 15 × 32 au lieu de 30 × 32 rendus complets.

---

## 3. Charge de rendu

### 3.1 Unités
- **Pose** : un rendu caméra d'un module dans une direction et une image d'animation.
- Chaque pose produit ses **passes** : couleur, ombre, émissif (blanc, dès l'époque 3), masque d'équipe
  (tourelles). Les passes ne coûtent pas de rendu supplémentaire, seulement des fichiers.
- La basse résolution se déduit par réduction et ne coûte aucun rendu.

### 3.2 Poses par famille
**Formules.** « Intégral » = structure vanilla refaite à chaque niveau. « Kit » = les économies du §3.3.

| Famille | Poses par rendu complet | Intégral, 30 niveaux | Kit proposé | Kit + options |
|---|---|---|---|---|
| Centre (15 niveaux) | 1 | 15 | 15 corps + animations par script (époques 5 à 15, environ 16 images) ≈ **190** | 190 |
| Mitrailleuse | tête 128 + déploiement 20 + socle 1 + patch 1 = 150 | 4 500 | 15 × 150 + 15 pièces de socle = **2 265** | 1 305 (1 image de tir) |
| Laser | tête 64 + déploiement 60 + socle 1 + patch 1 = 126 | 3 780 | 15 × 126 + 15 = **1 905** | 1 485 (déploiement en 8 images) |
| Mur | 41 | 1 230 | 15 × 23 (variantes réduites) + 15 surcouches = **360** | 360 |
| Foreuse | sec 121 + humide 29 = 150 | 4 500 | 15 × 60 + trépans par ère 5 × 90 + 15 pièces = **1 365** | 1 155 (fenêtres humides par ère) |
| Four | 1 + feu 48 + 1 = 50 | 1 500 | 15 corps + 15 pièces + 4 nouveaux feux × 48 = **222** | 222 |
| Assembleur 2 | 32 | 960 | 15 corps + 15 × 32 mécanismes + 15 pièces = **510** | 270 (mécanisme en 16 images) |
| **Total** | — | **≈ 16 500** | **≈ 6 800 (-59 %)** | **≈ 5 000 (-70 %)** |

Détail des postes :
- Mitrailleuse : 128 = 64 directions × 2 images de tir ; 20 = déploiement 4 × 5.
- Laser : 60 = déploiement 4 × 15.
- Mur : 41 = 33 variantes + 8 raccords ; la variante est réduite à 1 par clé, 3 pour les droits.
- Foreuse :
  - le sec compte 4 corps, 20 sorties, 3 cadres, 90 trépan (30 arrière vertical, 30 arrière horizontal,
    30 avant) et 4 patchs ;
  - l'humide compte 4 corps, 4 cadres et 21 fenêtres.

**Images = poses × passes.**
- Passes par pose : 4 pour les tourelles (couleur, ombre, masque d'équipe, émissif), 3 pour les autres
  familles (couleur, ombre, émissif).
- Un rendu complet produit donc environ 600 images (mitrailleuse), 500 (laser), 450 (foreuse), 150 (four),
  120 (mur), 96 (assembleur) et 3 (centre).
- Le kit (≈ 6 800 poses) produit **au plus environ 25 000 images hr** (9 100 pour la mitrailleuse, 7 600 pour
  le laser, 7 900 pour les 5 autres familles), moins là où une passe manque (pas d'émissif avant l'époque 3).
  La basse résolution s'en déduit sans rendu.

**Familles les plus coûteuses.**
1. **Mitrailleuse et laser** : la tête (tir sur 64 directions et déploiement) représente 98 % des poses de
   chaque rendu complet.
2. **Foreuse** : 4 directions, 3 trépans de 30 images et le jeu humide.

**Familles les moins coûteuses** : centre, four, mur.

**Feuilles et mémoire.**
- Une tête de mitrailleuse d'époque 15 mesure environ 140 × 220 px hr. Ses 128 images (64 directions × 2)
  tiennent en 4 bandes de 16 directions, comme le vanilla : chaque feuille fait 280 × 3520 px, sous 4096 px.
  Au-delà de 256 px de haut, il faut 8 bandes de 8 directions, ou `filenames` + `slice` (F23).
- **Mémoire vidéo estimée** (RGBA non compressé, hr) :
  - vanilla : environ 30 Mo pour la mitrailleuse, 23 Mo pour le laser, 18 Mo pour la foreuse, 10 Mo pour
    l'assembleur, 2 Mo pour le mur, 1,3 Mo pour le four ;
  - total des nouvelles images : **0,8 à 1,4 Go** selon les options, dont 75 % pour les deux tourelles ;
  - **mémoire du PC du Directeur Créatif** (registre Windows, lecture seule, 21/10) : AMD Radeon RX 6900 XT,
    **16 Go**. Ce n'est pas une contrainte sur ce PC ;
  - effet sur le **temps de chargement** du jeu : non mesuré.
- **Temps de rendu** : inconnu tant que V0 n'a pas chronométré une pose. Ordre de grandeur : 2 s par pose en
  rendu temps réel donnent environ 4 h ; 20 s en lancer de rayons donnent environ 38 h. **Non vérifié.**

### 3.3 Économies qui ne dégradent pas la lecture
1. **La pièce paire est une couche séparée**, rendue seule (avec le corps en cache pour les occultations),
   ajoutée au rendu impair. Elle coûte 1 pose, au lieu d'un rendu complet (150 pour une tourelle).
2. **Tourelles : la pièce paire va sur le socle** (1 direction), dans la zone toujours visible (§1.7), **jamais
   sur la tête** (×64).
3. **Pièces invariantes par rotation** (mâts, lanternes, bulbes, cristaux, anneaux horizontaux, paraboles
   pointées vers le ciel) : 1 rendu pour les 4 directions de la foreuse, et réutilisables d'une famille à
   l'autre.
4. **Corps fixe + mécanisme animé** pour l'assembleur (mesure §2.8) et le four (feu ou plasma par ère).
5. **Trépan de la foreuse par ère** (5 jeux au lieu de 15) : le mécanisme intérieur est à moitié caché.
6. **Patch au sol commun** par époque et par taille d'emprise : 2×2 (mitrailleuse, laser, four), 3×3
   (foreuse, assembleur), 4×4 (centre). Soit 45 images au lieu de 105.
7. **Mur** : 1 variante par clé (3 pour les droits, contre 5 et 6 en vanilla) ; la pièce paire est une
   **surcouche identique** sur toutes les clés (crête).
8. **Émissifs blancs teintés** : couleur d'époque, couleur de branche, état (vert, jaune, rouge) sans rendu
   supplémentaire.
9. **Animations partagées** (arcs de l'époque 6, bulles de l'époque 8, particules de l'époque 15) : une feuille
   invariante pour toutes les familles.

**Options qui dégradent un peu (question Q-V1-5).**
- Mitrailleuse : **1 image de tir** au lieu de 2. On perd le recul du canon ; c'est -42 % de poses pour la
  famille.
- Laser : **déploiement en 8 images** au lieu de 15. L'ouverture est moins fluide ; c'est -22 %.
- **Garder 64 directions** pour les têtes : 32 directions feraient sauter la rotation, ce qui va contre
  l'exigence R4 (précision).

---

## 4. Enveloppes par rang d'époque (source : `docs/epoques/mesures/enveloppes.txt`)

O = dépassement au-dessus de l'emprise ; L = largeur visuelle maximale ; V = vide minimal, en % du masque du
niveau 1, laissé transparent par le niveau impair. Toutes les valeurs sont en tuiles. Le rang 1 est mesuré sur
le vanilla, sauf le centre, qui part de la composition actuelle et sera redessiné.

| Rang | Centre O / L / V | Mitrailleuse | Laser | Mur (O seul, L = 1) | Foreuse | Four | Assembleur 2 |
|---|---|---|---|---|---|---|---|
| 1 | 0,41 / 3,41 / 0 | 0,84 / 1,95 / 0 | 1,02 / 1,72 / 0 | 0,25 / 0 | 0,38 / 2,94 / 0 | 0,28 / 1,97 / 0 | 0,06 / 2,56 / 0 |
| 2 | 0,64 / 3,45 / 0 | 0,95 / 1,97 / 0 | 1,13 / 1,75 / 0 | 0,30 / 0 | 0,47 / 2,96 / 0 | 0,37 / 1,99 / 0 | 0,16 / 2,60 / 0 |
| 3 | 0,87 / 3,48 / 0 | 1,06 / 1,99 / 0 | 1,25 / 1,77 / 0 | 0,36 / 0 | 0,55 / 2,98 / 0 | 0,47 / 2,00 / 0 | 0,27 / 2,64 / 0 |
| 4 | 1,09 / 3,52 / 0 | 1,17 / 2,00 / 0 | 1,36 / 1,80 / 0 | 0,41 / 0 | 0,64 / 3,00 / 0 | 0,56 / 2,02 / 0 | 0,37 / 2,68 / 0 |
| 5 | 1,32 / 3,55 / 0 | 1,29 / 2,02 / 0 | 1,47 / 1,83 / 0 | 0,46 / 0 | 0,73 / 3,01 / 0 | 0,66 / 2,04 / 0 | 0,47 / 2,71 / 0 |
| 6 | 1,55 / 3,58 / 0 | 1,40 / 2,04 / 0 | 1,58 / 1,86 / 0 | 0,52 / 0 | 0,82 / 3,03 / 0 | 0,75 / 2,05 / 0 | 0,57 / 2,75 / 0 |
| 7 | 1,78 / 3,62 / 0 | 1,51 / 2,06 / 0 | 1,70 / 1,88 / 0 | 0,57 / 0 | 0,90 / 3,05 / 0 | 0,85 / 2,07 / 0 | 0,68 / 2,79 / 0 |
| 8 | 2,00 / 3,66 / 0 | 1,62 / 2,08 / 0 | 1,81 / 1,91 / 0 | 0,62 / 0 | 0,99 / 3,07 / 0 | 0,94 / 2,08 / 0 | 0,78 / 2,83 / 0 |
| 9 | 2,23 / 3,69 / 0 | 1,73 / 2,09 / 0 | 1,92 / 1,94 / 0 | 0,68 / 0 | 1,08 / 3,09 / 0 | 1,03 / 2,10 / 0 | 0,88 / 2,87 / 0 |
| 10 | 2,46 / 3,73 / 4 | 1,84 / 2,11 / 3 | 2,04 / 1,96 / 1 | 0,73 / 4 | 1,16 / 3,11 / 3 | 1,13 / 2,12 / 5 | 0,99 / 2,91 / 6 |
| 11 | 2,69 / 3,76 / 8 | 1,95 / 2,13 / 7 | 2,15 / 1,99 / 2 | 0,79 / 8 | 1,25 / 3,13 / 7 | 1,22 / 2,13 / 10 | 1,09 / 2,95 / 12 |
| 12 | 2,92 / 3,79 / 12 | 2,07 / 2,15 / 10 | 2,26 / 2,02 / 2 | 0,84 / 12 | 1,34 / 3,14 / 10 | 1,32 / 2,15 / 15 | 1,19 / 2,98 / 18 |
| 13 | 3,14 / 3,83 / 17 | 2,18 / 2,16 / 13 | 2,37 / 2,05 / 3 | 0,89 / 17 | 1,43 / 3,16 / 13 | 1,41 / 2,17 / 20 | 1,29 / 3,02 / 23 |
| 14 | 3,37 / 3,86 / 21 | 2,29 / 2,18 / 17 | 2,49 / 2,07 / 4 | 0,95 / 21 | 1,51 / 3,18 / 17 | 1,51 / 2,18 / 25 | 1,40 / 3,06 / 29 |
| 15 | 3,60 / 3,90 / 25 | 2,40 / 2,20 / 20 | 2,60 / 2,10 / 5 | 1,00 / 25 | 1,60 / 3,20 / 20 | 1,60 / 2,20 / 30 | 1,50 / 3,10 / 35 |

**Pas par époque** :

| Famille | Centre | Mitrailleuse | Laser | Mur | Foreuse | Four | Assembleur |
|---|---|---|---|---|---|---|---|
| Pas (tuile) | 0,228 | 0,111 | 0,113 | 0,054 | 0,087 | 0,094 | 0,103 |

À l'échelle de la vignette, cela fait 1 à 2 px par époque : la hauteur seule ne suffit pas à classer les
époques, c'est la **signature de forme** qui fait le travail (§1.2).

**Budget D1-3 à l'époque 15** (IoU visé ≤ 0,45 ; aire A30 estimée = boîte × remplissage 0,5 à 0,75).

| Famille | A1 mesurée | A30 estimée | Intersection max | Vide à laisser | IoU si A30 contenait tout A1 |
|---|---|---|---|---|---|
| Centre | 10,82 | 16,4 | 8,45 | ≥ 22 % | 0,66 |
| Mitrailleuse | 3,28 | 5,3 | 2,67 | ≥ 19 % | 0,62 |
| Laser | 2,26 | 4,8 | 2,20 | ≥ 3 % | 0,47 |
| Mur (droit) | 1,24 | 1,9 | 0,98 | ≥ 21 % | 0,65 |
| Foreuse N | 4,99 | 8,1 | 4,06 | ≥ 19 % | 0,62 |
| Four | 3,60 | 4,8 | 2,60 | ≥ 28 % | 0,75 |
| Assembleur 2 | 6,98 | 8,4 | 4,76 | ≥ 32 % | 0,83 |

La colonne V du tableau par rang arrondit ces valeurs aux 5 % supérieurs. Pour le centre, A1 sera celle du
**nouveau** niveau 1 : la règle reste « V ≥ 25 % du niveau 1 ».

---

## 5. Fiches d'époque

Chaque fiche est indépendante. Colonnes des tableaux :
- **Niveau impair** : silhouette (socle, corps, sommet, accessoires) et ce qui dépasse.
- **O / L** : §4, rang e.
- **Niveau pair** : la pièce ajoutée et l'endroit où elle sort du masque.
- **Δ** : ce qui change par rapport à l'époque précédente.

Le centre n'a qu'un niveau par époque.

### Époque 1 · Pionnier (ère I, logistique T1)
- **Ressources** : fer, cuivre, charbon, pierre.
- **Signature** : matériaux de fortune. Silhouette **basse, trapue, irrégulière** : sacs de sable, rondins,
  bâches, cordages. 1 événement de silhouette.
- **Kit d'époque** :
  - sac de sable (3 variantes) ;
  - rondin, planche ;
  - caisse en bois ;
  - lanterne à huile ;
  - mât en bois ;
  - rouleau de barbelé.
- **Matériaux** : fer brut #5A5048, bois #6B4F35, toile #8A7A5A. Luminance médiane 50, saturation ≤ 0,35.
- **Lumière** : de jour, aucune lueur. La nuit, la lanterne (#FFB060) au halo de la formule §1.6. Aucune
  animation.
- **Δ** : référence (vanilla).

| Famille | Niveau impair (1) | O / L | Niveau pair (2) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 1) | **Poste de pionnier** : cabane en rondins à toit de tôle ondulée, sur plate-forme de rondins ; rempart de sacs de sable en U devant la porte sud ; mât de drapeau en bois à l'arrière gauche (tige jusqu'à O ≈ 1,2). Remplace la composition roboport. | 0,41 / 3,41 (masses) | — | lanterne de porte (nuit) |
| Mitrailleuse | vanilla | 0,84 / 1,95 | **Arc de sacs de sable** sur les coins avant et les flancs du socle (y ≥ -0,66, l'avant-centre restant libre), qui dépasse de 0,10 de chaque côté et de 0,15 sous l'emprise | — |
| Laser | vanilla | 1,02 / 1,72 | **Muret de sacs de sable** bas devant le socle (y ≥ -0,42) + câble d'alimentation en tranchée, dépasse de 0,15 au sud | — |
| Mur | vanilla (pierre) | 0,25 | **Rouleau de barbelé** sur la crête : surcouche identique sur toutes les clés, +0,15 | — |
| Foreuse | vanilla | 0,38 / 2,94 | **Chevalement en bois** (trépied de poutres) au-dessus de la tour, invariant par rotation, +0,50 | lanterne pendue au chevalement (nuit) |
| Four | vanilla | 0,28 / 1,97 | **Hotte et conduit de fumée en tôle rivetée** à l'arrière droit, +0,45 ; la fumée part du haut du conduit | — |
| Assembleur 2 | vanilla | 0,06 / 2,56 | **Potence de levage en bois avec palan** en haut à droite, +0,50 en haut et +0,10 à droite | lanterne (nuit) |

### Époque 2 · Forge (ère I, T1)
- **Ressources** : acier.
- **Signature** : **cubes cerclés** et **boucliers plats** à arêtes vives ; premiers **créneaux d'acier**.
  Silhouette orthogonale. 1 à 2 événements.
- **Kit d'époque** :
  - plaque boulonnée ;
  - cerclage ;
  - rivet ;
  - cornière ;
  - volant d'inertie ;
  - soufflet ;
  - mât en treillis.
- **Matériaux** : acier #5C6168, cerclage #2E2C2A, rivets en laiton #8C7440. Luminance 52.
- **Lumière** : de jour, aucune lueur. La nuit, lueur de forge #FF6A20 par des fentes (`draw_as_light`). Aucune
  animation.
- **Δ** : on passe de formes molles et irrégulières (sacs, bois) à l'acier orthogonal. Les silhouettes
  deviennent des blocs à bouclier.

| Famille | Niveau impair (3) | O / L | Niveau pair (4) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 2) | **Bastion d'acier** : bloc carré à 2 étages en plaques boulonnées, cerclé ; porte blindée centrale ; 2 échauguettes trapues aux coins avant ; mât en treillis d'acier (tige). Δ : du bois à l'acier, volume deux fois plus massif. | 0,64 / 3,45 | — | fentes de forge (nuit) |
| Mitrailleuse | Tête en **caisson riveté** à 2 canons, avec un **bouclier frontal plat** qui dépasse au-dessus de la tête ; socle octogonal cerclé. Δ : silhouette de tête rectangulaire et haute. | 0,95 / 1,97 | **Caisse de munitions cerclée** sur le flanc gauche du socle (zone visible), qui dépasse de 0,10 à gauche | — |
| Laser | Tête carénée de plaques rivetées autour de la lentille, avec visière ; socle cerclé. Δ : la tête vanilla est habillée d'un caisson. | 1,13 / 1,75 | **Jupe de blindage boulonnée** sur l'avant du socle, qui dépasse de 0,15 sous l'emprise | — |
| Mur | Pierre plaquée d'acier boulonné ; **merlons d'acier** sur la crête (2 par tuile, bord supérieur crénelé). Δ : crête droite, maintenant crénelée. | 0,30 | **Pique d'acier** au centre de chaque tuile (surcouche), +0,12 | — |
| Foreuse | Cadre en acier boulonné, montants cerclés ; **tour en treillis d'acier** au-dessus de la tige. Δ : le bois devient de l'acier, la tour est plus haute. | 0,47 / 2,96 | **Poulie et lanterne de mine** au sommet du treillis (invariant), +0,25 | lanterne (nuit) |
| Four | Four en briques réfractaires cerclé d'acier, avec la **première cheminée carrée** haute à l'arrière droit et une porte à volets. Δ : apparition de la cheminée. | 0,37 / 1,99 | **Soufflet de forge** sur le flanc gauche, qui dépasse de 0,15 à gauche | bouche rouge (nuit) |
| Assembleur 2 | Caisse rivetée ; **grand volant d'inertie** sur le flanc droit (+0,20 à droite) ; arbre de transmission sur le toit. Δ : la boîte vanilla gagne un volant latéral. | 0,16 / 2,60 | **Marteau-pilon vertical** sur l'avant-toit, +0,30 | — |

### Époque 3 · Vapeur (ère I, T1)
- **Ressources** : eau, vapeur.
- **Signature** : premières **cheminées rondes** verticales, **manomètres** ronds, tuyaux de cuivre coudés.
  Chaque famille gagne au moins un **fût vertical** qui dépasse. 2 événements.
- **Kit d'époque** :
  - cheminée ronde à collerette ;
  - manomètre ;
  - soupape ;
  - tuyau coudé en cuivre ;
  - chaudière rivetée ;
  - régulateur à boules.
- **Matériaux** : cuivre #8A5A3A, laiton #9C7E45, fonte #3A3634. Luminance 58.
- **Lumière** : **première lueur visible de jour** (D2-1) : hublots et cadrans ambrés #FFC060 (`draw_as_glow`,
  zones d'au moins 8 × 8 px hr). La nuit, halo chaud. Animation facultative : panache de vapeur en 16 images
  (invariant, partagé).
- **Δ** : la verticalité arrive ; la palette se réchauffe (cuivre).

| Famille | Niveau impair (5) | O / L | Niveau pair (6) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 3) | **Hôtel de la vapeur** : bâtiment à 2 étages en brique bardée de cuivre ; **2 hautes cheminées rondes** à l'arrière ; grand cadran-manomètre en façade ; tuyauterie extérieure ; mât. | 0,87 / 3,48 | — | cadran et fenêtres ambrés |
| Mitrailleuse | Tête avec **chaudière compacte dorsale** et cheminée courte (tourne avec la tête) ; 2 canons longs ; alimentation par tuyau ; socle en fonte. | 1,06 / 1,99 | **Réservoir de vapeur debout** au coin avant droit du socle, qui dépasse de 0,10 à droite | hublot de chaudière |
| Laser | Tête refroidie par **serpentins de cuivre** et un évent court ; lentille cerclée de laiton. | 1,25 / 1,77 | **Chaudière auxiliaire basse** devant le socle, qui dépasse de 0,15 au sud | voyant ambré |
| Mur | Brique et **tuyau de cuivre** le long de la crête ; une **colonnette-cheminée ronde** par tuile (crête « en piquets »). | 0,36 | **Globe de lanterne à vapeur** sur la colonnette, +0,15 | globe ambré (`draw_as_glow`) |
| Foreuse | Chaudière verticale avec **cheminée ronde** au coin opposé à la sortie ; volant latéral ; tuyaux de cuivre. | 0,55 / 2,98 | **Sifflet et grand manomètre** au sommet de la tour (invariant), +0,25 | cadran ambré |
| Four | **Haut-fourneau rond** cerclé, **cheminée ronde** haute, tuyère de cuivre, hublot ambré. Δ : la cheminée carrée devient ronde et plus haute. | 0,47 / 2,00 | **Chaudière de récupération** (cylindre horizontal) sur le flanc gauche, qui dépasse de 0,15 | hublot et bouche |
| Assembleur 2 | **Machine à vapeur sur le toit** : cylindre à piston horizontal, cheminée ronde, courroies vers des poulies. | 0,27 / 2,64 | **Régulateur à boules de Watt** au sommet, +0,30 | voyant ambré |

### Époque 4 · Pétrole (ère II, **T2**)
- **Ressources** : pétrole, plastique, soufre.
- **Signature** : **cuves cylindriques horizontales**, **passerelles à garde-corps** (lignes fines), torchère.
  Silhouettes plus larges, hérissées de garde-corps. 2 événements.
- **Kit d'époque** :
  - cuve horizontale ;
  - garde-corps ;
  - échelle ;
  - vanne à volant ;
  - fût ;
  - torchère et sa flamme.
- **Matériaux** : tôle jaune délavée #8C7A3A, acier galvanisé #6E7378, bandes noires. Luminance 60.
- **Lumière** : de jour, voyants orange #FF8C1A et flamme. La nuit, la torchère éclaire. **Animation : flamme de
  torchère** en 16 images (invariante, partagée).
- **Δ** : début de l'ère II. La brique et le cuivre s'en vont ; l'horizontal (cuves) et la ligne fine
  (garde-corps) arrivent.

| Famille | Niveau impair (7) | O / L | Niveau pair (8) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 4) | **QG de raffinerie** : bâtiment à toit-terrasse ; **2 cuves horizontales** sur le toit ; passerelle à garde-corps ; **torchère** haute à l'arrière droit (tige et flamme). | 1,09 / 3,52 | — | flamme animée, voyants |
| Mitrailleuse | Tête caissonnée jaune avec **2 bidons-chargeurs cylindriques** latéraux ; **3 canons**. | 1,17 / 2,00 | **Passerelle avec garde-corps** autour de l'avant du socle, qui dépasse de 0,15 de chaque côté | voyant orange |
| Laser | Tête avec **cuve de refroidissement horizontale** dorsale et tuyaux. | 1,36 / 1,80 | **Fût de liquide de refroidissement et vanne** au coin avant gauche | voyant orange |
| Mur | Béton peint à bandes jaunes et noires ; **garde-corps** et poteaux sur la crête. | 0,41 | **Feu d'avertissement orange** sur chaque poteau, +0,15 | feu orange (glow) |
| Foreuse | Châssis peint ; **2 vérins hydrauliques** ; **cuve horizontale** à l'arrière ; passerelle sur le toit. | 0,64 / 3,00 | **Petit derrick en treillis** au-dessus de la tour (invariant), +0,40 | feu de derrick |
| Four | **Brûleur au fioul** : foyer en cylindre horizontal et réservoir de fioul latéral ; cheminée ; garde-corps. | 0,56 / 2,02 | **Torchère** greffée sur la cheminée, +0,30 | flamme animée |
| Assembleur 2 | **Presse hydraulique** : portique sur le toit (2 montants et une traverse) ; cuves latérales. | 0,37 / 2,68 | **Cuve de pression verticale** sur le flanc droit, qui dépasse de 0,15 | voyant orange |

### Époque 5 · Volcan (ère II, T2)
- **Ressources** : **tungstène** (biome des cendres).
- **Signature** : **blindage incliné en écailles**, **troncs de pyramide**, rivets lourds, **fentes de braise**.
  Formes en coin, lourdes. 2 à 3 événements.
- **Kit d'époque** :
  - écaille de blindage ;
  - rivet lourd ;
  - contrefort incliné ;
  - fente de braise ;
  - pointe de basalte.
- **Matériaux** : tungstène #3E3D42, rouille brûlée #5A3A2A. Luminance **42** : l'époque la plus sombre, pour un
  contraste maximal avec la braise.
- **Lumière** : de jour, fentes de braise #FF4A10 (`draw_as_glow`). La nuit, halo rouge-orangé. **Animation :
  pulsation lente des braises** (8 à 16 images, `frame_sequence`).
- **Δ** : les cylindres et les lignes laissent place aux coins massifs ; la palette s'assombrit.

| Famille | Niveau impair (9) | O / L | Niveau pair (10) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 5) | **Citadelle volcanique** : pyramide tronquée à gradins en blindage sombre ; **contreforts inclinés** aux 4 coins ; porte en ogive rougeoyante ; 2 pointes de basalte. | 1,32 / 3,55 | — | porte et fentes (animées par script) |
| Mitrailleuse | **Tête en coin** (blindage incliné à l'avant, profil trapézoïdal) ; 2 canons lourds en tungstène ; socle à contreforts. | 1,29 / 2,02 | **Jupe d'écailles inclinée** autour de l'avant du socle, qui dépasse de 0,15 au sud et sur les côtés | fentes du socle (pulsation) |
| Laser | Capot trapézoïdal avec **fente d'émission rougeoyante** et ailettes de dissipation. | 1,47 / 1,83 | **Pointes de basalte** aux coins avant | fente (glow) |
| Mur | **Glacis** : face avant inclinée ; dents sur l'arête ; joints de braise. | 0,46 | **Pointe de basalte haute** au centre de chaque tuile, +0,20 | joints (glow fixe) |
| Foreuse | Carcasse blindée en pyramide tronquée ; **trépan en tungstène rougeoyant**. | 0,73 / 3,01 | **Cône de cheminée volcanique** au sommet (invariant), +0,35 | trépan et cône (pulsation) |
| Four | **Four-forge en tronc de pyramide** noir ; **bouche de lave** à l'avant ; fissures rougeoyantes. | 0,66 / 2,04 | **Rigole de coulée de lave** qui déborde à l'avant, +0,20 au sud | lave (pulsation) |
| Assembleur 2 | Presse blindée à capot incliné ; fente de marteau rougeoyante. | 0,47 / 2,71 | **Contreforts inclinés** à gauche et à droite, qui dépassent de 0,15 | fente (pulsation) |

### Époque 6 · Électricité (ère II, T2)
- **Ressources** : batteries.
- **Signature** : **piles d'isolateurs** (disques de céramique empilés : colonnes « crantées »), **bobines**,
  arcs. 3 événements.
- **Kit d'époque** :
  - isolateur (disque) ;
  - pile d'isolateurs (3 hauteurs) ;
  - bobine de cuivre ;
  - tore de Tesla ;
  - éclateur ;
  - feuille d'animation d'arc (partagée).
- **Matériaux** : céramique #D8D4C8 patinée, cuivre de bobine #B0703A, acier #5C6168. Luminance 64 : le
  **premier matériau clair**.
- **Lumière** : de jour, arcs cyan #60D0FF. La nuit, halo cyan. **Animation : arcs et étincelles** (feuille de
  16 images invariante, partagée).
- **Δ** : on passe du sombre incliné au clair vertical et empilé.

| Famille | Niveau impair (11) | O / L | Niveau pair (12) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 6) | **Centrale de commandement** : tour centrale ; **2 hautes piles d'isolateurs** sur les côtés ; **tore de Tesla** au sommet ; arcs entre les piles. | 1,55 / 3,58 | — | arcs (animés par script) |
| Mitrailleuse | **Mitrailleuse électrique** : moteur bobiné et **4 canons rotatifs** ; isolateurs dorsaux. | 1,40 / 2,04 | **2 condensateurs** (piles d'isolateurs courtes) aux coins avant du socle | arc animé sur le socle |
| Laser | Émetteur entouré d'**isolateurs empilés** (la tête évoque une mini-bobine Tesla) ; bobine annulaire. | 1,58 / 1,86 | **Bobine au sol** devant le socle, reliée par un arc animé | arc (socle) |
| Mur | **Clôture électrique** : poteau à isolateurs sur chaque tuile, fils tendus au-dessus d'un muret. | 0,52 | **Isolateur double et plaque « danger »** sur le poteau, +0,15 | arc fixe (glow) |
| Foreuse | **Moteur bobiné** au sommet (gros cylindre de cuivre) ; 2 piles d'isolateurs aux angles arrière. | 0,82 / 3,03 | **Éclateur à pointe** au sommet (invariant), +0,30 | arcs animés |
| Four | **Four à arc** : **3 électrodes verticales** isolées sur le toit (iconique) ; cuve ronde. | 0,75 / 2,05 | **Transformateur à ailettes** sur le flanc gauche | arcs entre électrodes |
| Assembleur 2 | **Bras de soudure à l'arc** sur le toit ; bobines aux coins. | 0,57 / 2,75 | **Anneau de bobine vertical** au-dessus, +0,30 | étincelles de soudure |

### Époque 7 · Cristal (ère III, **T3**)
- **Ressources** : **cristal de résonance** (plaine de cristal).
- **Signature** : **pointes de cristal asymétriques** violettes qui jaillissent (couronne irrégulière). 3
  événements.
- **Kit d'époque** :
  - grappe de cristaux (3 tailles) ;
  - sertissure en bronze ;
  - prisme ;
  - éclat isolé.
- **Matériaux** : bronze #6A5236, pierre #4A4038, cristal #9A5CFF. Le cristal est rendu **opaque à au moins
  50 % d'alpha**, pour compter dans la silhouette. Luminance 55.
- **Lumière** : de jour, cristaux luisants #B070FF. La nuit, halo violet. **Animation : respiration des
  cristaux** (16 images, pulsation de l'émissif).
- **Δ** : début de l'ère III. Les verticales usinées deviennent des pointes organiques et asymétriques.

| Famille | Niveau impair (13) | O / L | Niveau pair (14) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 7) | **Sanctuaire de résonance** : socle de pierre taillée ; **grand cristal central** (point le plus haut) ; 4 éclats satellites ; armature de bronze. | 1,78 / 3,62 | — | cristal qui respire (script) |
| Mitrailleuse | **Canon à éclats** : tête de bronze à 2 canons ; **grappe de cristaux dorsale** (focalisateur). | 1,51 / 2,06 | **Grappes de cristaux** aux coins avant du socle | cristaux du socle (pulsation) |
| Laser | La lentille devient un **grand prisme de cristal** saillant à l'avant de la tête. | 1,70 / 1,88 | **Anneau de petits cristaux** devant le socle | prisme et anneau |
| Mur | Muret de pierre d'où jaillissent **2 à 3 pointes de cristal** par tuile, de hauteurs irrégulières (variantes). | 0,57 | **Cristal plus haut** au centre, +0,20 | cristaux (glow fixe) |
| Foreuse | **Foreuse à résonance** : 4 cristaux aux coins, inclinés vers la tige ; cadre de bronze. | 0,90 / 3,05 | **Grappe de cristal** au sommet de la tour (invariant), +0,30 | pulsation |
| Four | **Creuset tenu par 4 griffes de cristal** pointées vers le haut. | 0,85 / 2,07 | **Prisme focalisateur** au-dessus du creuset, +0,25 | creuset violet |
| Assembleur 2 | Corps bas ; **couronne de cristaux** sur le toit. | 0,68 / 2,79 | **Grand cristal central** au-dessus, +0,30 | pulsation |

### Époque 8 · Marais (ère III, T3)
- **Ressources** : **méthane** (marais).
- **Signature** : **bulbes et sphères de verre**, conduits toxiques. Tout s'arrondit. 3 à 4 événements.
- **Kit d'époque** :
  - bulbe de verre (3 tailles) ;
  - cuve de verre cylindrique ;
  - conduit vert-de-gris ;
  - feuille d'animation de bulles (partagée).
- **Matériaux** : verre #8FBF4A (alpha ≥ 0,5), vert-de-gris #4F6B5A, caoutchouc #2A2A28. Luminance 60.
- **Lumière** : de jour, liquide luminescent #A8FF3A. La nuit, halo vert-jaune. **Animation : bulles
  montantes** (16 à 24 images).
- **Δ** : les pointes deviennent des rondeurs ; le violet devient vert-jaune.

| Famille | Niveau impair (15) | O / L | Niveau pair (16) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 8) | **Serre-laboratoire** : bâtiment bas ; **3 dômes de verre** de tailles décroissantes ; conduits. | 2,00 / 3,66 | — | bulles (script) |
| Mitrailleuse | Tête à 2 canons et **réservoir-bulbe dorsal** (projectiles corrosifs). | 1,62 / 2,08 | **Bonbonne de verre** sur le flanc du socle | bulles au socle |
| Laser | Émetteur dans une **ampoule de verre frontale** remplie de plasma vert. | 1,81 / 1,91 | **Condensateurs en bulbes** aux coins avant | ampoule |
| Mur | **Panneaux de verre épais** à sommet bombé, remplis de liquide vert ; armature vert-de-gris. | 0,62 | **Globe** sur chaque tuile, +0,20 | liquide (glow fixe) |
| Foreuse | **Lixiviation** : 2 cuves sphériques en verre aux coins arrière, conduits vers la tige. | 0,99 / 3,07 | **Bulbe-distillateur** au sommet (invariant), +0,30 | bulles |
| Four | **Creuset-alambic sphérique** sur une base ; **col de cygne** qui monte. | 0,94 / 2,08 | **Second alambic** sur le flanc gauche | bulles |
| Assembleur 2 | **3 fioles-réacteurs bouillonnantes** sur le toit. | 0,78 / 2,83 | **Grand bulbe central** et serpentin, +0,30 | bulles |

### Époque 9 · Atome (ère III, T3)
- **Ressources** : uranium.
- **Signature** : blindage plombé **à chanfreins** (octogones), **tours de refroidissement hyperboloïdes**,
  hublots verts, trèfle. 4 événements.
- **Kit d'époque** :
  - hyperboloïde (3 tailles) ;
  - panneau chanfreiné ;
  - hublot ;
  - trèfle ;
  - conduit annelé ;
  - balise de radiation.
- **Matériaux** : plomb #4A5058, accents jaune d'avertissement #C9A227, béton #7A7670. Luminance 56.
- **Lumière** : de jour, cœurs et hublots vert uranium #5CFF4A. La nuit, halo vert. **Animation :
  `effect = "uranium-glow"`** (WorkingVisualisation : gratuit) et pulsation.
- **Δ** : les rondeurs de verre laissent place aux octogones lourds et aux hyperboloïdes.

| Famille | Niveau impair (17) | O / L | Niveau pair (18) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 9) | **Bunker atomique** : corps octogonal chanfreiné ; **2 tours de refroidissement** ; dôme de confinement. | 2,23 / 3,69 | — | hublots verts (script) |
| Mitrailleuse | Tête **octogonale plombée** ; 2 canons à manchons de refroidissement ; hublot vert. | 1,73 / 2,09 | **Plaque plombée avec trèfle** devant les coins du socle | hublot (tête, fixe) |
| Laser | Tête octogonale, **cœur vert** visible par un hublot. | 1,92 / 1,94 | **Évents annelés** aux coins avant | cœur |
| Mur | **Blocs de plomb chanfreinés** (profil octogonal) ; bandes d'avertissement. | 0,68 | **Évent annelé** sur chaque tuile, +0,15 | bande verte (glow fixe) |
| Foreuse | Blindage octogonal ; **évent hyperboloïde** au-dessus de la tige. | 1,08 / 3,09 | **Balise de radiation** au sommet (invariant), +0,25 | `uranium-glow` |
| Four | Cœur vert sous **dôme chanfreiné** ; petite **tour de refroidissement** à l'arrière. | 1,03 / 2,10 | **Conduit annelé** sur le flanc droit | `uranium-glow` |
| Assembleur 2 | **Cellule chaude plombée** : corps octogonal, hublot vert, **2 bras télémanipulateurs** sur le toit. | 0,88 / 2,87 | **Tour de refroidissement miniature**, +0,30 | `uranium-glow` |

### Époque 10 · Haute technologie (ère IV, **T4**)
- **Ressources** : processeurs.
- **Signature** : **carénages lisses** et **dômes**, **antennes fouet**, paraboles, voyants. **Les corps se
  lèvent** : pieds courts visibles sous le corps (V ≥ 1 à 6 %, §4). 4 événements.
- **Kit d'époque** :
  - dôme lisse ;
  - radôme ;
  - antenne fouet ;
  - parabole ;
  - pied télescopique ;
  - bandeau de voyants.
- **Matériaux** : carénage gris clair #A8ADB3, noir mat #222428. Luminance 82.
- **Lumière** : de jour, voyants bleus #3AA8FF et écrans. La nuit, halo bleu. **Animation : voyants qui
  clignotent** (`frame_sequence`) et écran qui défile.
- **Δ** : début de l'ère IV. L'industrie lourde fait place à une technique propre ; la palette s'éclaircit ;
  premiers vides sous les corps.

| Famille | Niveau impair (19) | O / L / V | Niveau pair (20) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 10) | **QG radar** : coque lisse arrondie **sur pieds courts** ; grand **radôme** ; **antenne fouet** très haute (tige) ; parabole tournante (script). | 2,46 / 3,73 / 4 % | — | voyants, parabole |
| Mitrailleuse | Tête en **dôme caréné**, 4 canons courts dans un manchon, capteur optique ; socle sur **3 pieds courts**. | 1,84 / 2,11 / 3 % | **Petit radôme de visée** au coin avant | voyants clignotants |
| Laser | **Tête-dôme** à fente bleue, antenne courte. | 2,04 / 1,96 / 1 % | **Batterie carénée** devant le socle | fente bleue |
| Mur | Panneaux lisses à **bandeau lumineux bleu** ; capteur en demi-sphère ; pied en retrait (petit vide sous la crête). | 0,73 / 4 % | **Antenne fine** sur chaque tuile, +0,20 | bandeau (glow fixe) |
| Foreuse | Boîtier lisse **sur pieds** ; **mât de capteurs** au-dessus de la tour. | 1,16 / 3,11 / 3 % | **Parabole tournée vers le ciel** au sommet (invariante), +0,30 | voyants |
| Four | **Four à induction** : capsule lisse verticale, anneaux bleus ; pieds courts. | 1,13 / 2,12 / 5 % | **Antenne et écran** latéraux | anneaux bleus |
| Assembleur 2 | Coque lisse à **dôme transparent** ; **3 bras robotisés articulés** animés ; pieds courts. | 0,99 / 2,91 / 6 % | **Antenne-parabole**, +0,30 | écrans |

### Époque 11 · Titane (ère IV, T4)
- **Ressources** : nouvelle ressource (nouveau biome, contenu du lot X0).
- **Signature** : **ailerons triangulaires** blancs (silhouette **en flèche**, élancée), structures légères
  **sur pieds**. 4 à 5 événements.
- **Kit d'époque** :
  - aileron (3 tailles) ;
  - flèche ;
  - pied en V ;
  - bandeau lumineux.
- **Matériaux** : alliage blanc #C9C6BE (patine et salissures obligatoires, p95 ≤ 240), titane #8E9AA6.
  Luminance 100.
- **Lumière** : de jour, lignes bleu-blanc #BFE6FF. La nuit, halo blanc-bleu. **Animation : chenillard** (la
  lumière court le long des ailerons).
- **Δ** : les dômes laissent place aux ailerons tranchants ; tout s'allonge ; les vides s'agrandissent.

| Famille | Niveau impair (21) | O / L / V | Niveau pair (22) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 11) | **Tour blanche** : tour effilée ; **4 ailerons triangulaires** ; posée sur **4 pieds** (vides au sol) ; flèche. | 2,69 / 3,76 / 8 % | — | chenillard (script) |
| Mitrailleuse | Tête **effilée à ailerons arrière** ; 2 canons longs ; socle **tripode**. | 1,95 / 2,13 / 7 % | **Ailerons de socle** aux coins avant | lignes |
| Laser | **Tête en fuseau** à ailerons ; socle tripode. | 2,15 / 1,99 / 2 % | **Aileron-condensateur** devant le socle | lignes |
| Mur | Plaques d'alliage **en dents de scie inclinées** (ailerons) avec **ajours** entre les dents. | 0,79 / 8 % | **Aileron central** plus haut, +0,20 | bandeau |
| Foreuse | **Tour élancée à ailerons** ; cadre léger **sur pieds**. | 1,25 / 3,13 / 7 % | **Flèche-capteur** au sommet (invariante), +0,35 | chenillard |
| Four | **Four vertical élancé** à ailerons de refroidissement, sur 4 pieds. | 1,22 / 2,13 / 10 % | **Aileron dorsal**, +0,25 | chenillard |
| Assembleur 2 | **Portique blanc à ailerons** sur 4 pieds, côtés ouverts. | 1,09 / 2,95 / 12 % | **Grue en flèche**, +0,30 | chenillard |

### Époque 12 · Supraconducteurs (ère IV, T4)
- **Ressources** : terres rares (contenu X0).
- **Signature** : **anneaux en lévitation** ; **vides visibles** entre les pièces (premières pièces vraiment
  flottantes) ; noir et chrome ; givre cryogénique. 5 événements.
- **Kit d'époque** :
  - anneau chromé (3 diamètres) ;
  - noyau noir ;
  - pylône ;
  - bloc flottant ;
  - givre.
- **Matériaux** : noir profond #26282E, chrome #9AA3AD, givre #DDEEFF. Luminance 60 (fort contraste).
- **Lumière** : de jour, anneaux cyan #4AF0FF. La nuit, halo cyan. **Animation : rotation des anneaux** sur les
  modules fixes seulement (socle, corps, visualisations), et givre qui scintille.
- **Δ** : la silhouette se **fragmente** (vides). Le blanc devient noir et chrome.

| Famille | Niveau impair (23) | O / L / V | Niveau pair (24) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 12) | **Nexus** : noyau noir vertical ; **3 anneaux chromés horizontaux** en lévitation, espacés (vides) ; 4 pylônes. | 2,92 / 3,79 / 12 % | — | anneaux (script) |
| Mitrailleuse | **Fusil à rail** : **2 longs rails** parallèles et anneaux d'accélération ; la tête flotte au-dessus d'un **socle annulaire** (vide entre les deux). | 2,07 / 2,15 / 10 % | **Anneau flottant au sol** (socle), qui dépasse de 0,10 de chaque côté | anneau du socle (rotation) |
| Laser | **Lentille en lévitation** entre 2 anneaux. | 2,26 / 2,02 / 2 % | **Pylônes** aux coins avant | lentille |
| Mur | **Plinthe basse** et **bloc supérieur en lévitation** (vide de 0,10 à 0,15 entre les deux) ; anneau. | 0,84 / 12 % | **Petit anneau flottant** au-dessus de chaque tuile, +0,20 | interstice (glow fixe) |
| Foreuse | Tige entourée d'**anneaux flottants** ; cadre sur pieds. | 1,34 / 3,14 / 10 % | **Anneau supplémentaire** au sommet (invariant), +0,25 | rotation |
| Four | **Creuset en lévitation** entre 2 anneaux magnétiques (vide dessous). | 1,32 / 2,15 / 15 % | **Pylône cryogénique** à gauche | rotation |
| Assembleur 2 | **Plateau de travail en lévitation** ; anneaux ; pièces flottantes animées. | 1,19 / 2,98 / 18 % | **Anneau vertical** au-dessus, +0,30 | rotation |

### Époque 13 · Fusion (ère V, **T5**)
- **Ressources** : hélium-3 (contenu X0).
- **Signature** : **tore de plasma lumineux horizontal** autour d'une **sphère** ou d'une coque (« planète à
  anneau ») ; trépieds. 5 événements.
- **Kit d'époque** :
  - sphère de confinement ;
  - tore de plasma (émissif) ;
  - trépied ;
  - injecteur ;
  - feuille d'animation de plasma (partagée).
- **Matériaux** : céramique blanche #D9D6CF, cuivre #B0703A. Luminance 92.
- **Lumière** : de jour, plasma magenta #FF4FD8 (cœur #FF9A3A), très visible. La nuit, halo fort. **Animation :
  plasma qui tourne** (16 à 32 images).
- **Δ** : début de l'ère V. Les anneaux froids deviennent un tore brûlant ; la sphère devient la masse
  principale.

| Famille | Niveau impair (25) | O / L / V | Niveau pair (26) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 13) | **Citadelle-réacteur** : sphère de confinement sur **trépied** ; **tore de plasma** horizontal autour ; flèche. | 3,14 / 3,83 / 17 % | — | plasma (script) |
| Mitrailleuse | **Canon à plasma** : tête sphérique ceinturée d'un tore, 2 canons courts ; socle sur trépied. | 2,18 / 2,16 / 13 % | **Injecteurs** aux coins avant du socle | plasma du socle |
| Laser | Émetteur au centre d'un **tore de plasma** vertical. | 2,37 / 2,05 / 3 % | **Petit tore au sol** | tore (tir) |
| Mur | Plinthe et **pylône par tuile** ; **champ de plasma** entre les pylônes (couche émissive, hors masque). | 0,89 / 17 % | **Sphère** au sommet du pylône, +0,20 | champ (glow fixe) |
| Foreuse | **Foreuse à plasma** : tore autour de la tige ; coque sphérique sur trépied. | 1,43 / 3,16 / 13 % | **Injecteur** au sommet (invariant), +0,25 | plasma animé |
| Four | **Sphère sur trépied** et tore de plasma : grand vide sous la sphère. | 1,41 / 2,17 / 20 % | **Second tore incliné**, +0,25 | plasma animé |
| Assembleur 2 | Noyau sphérique dans un cadre ; tore de plasma. | 1,29 / 3,02 / 23 % | **Couronne d'injecteurs**, +0,30 | plasma animé |

### Époque 14 · Orbite (ère V, T5)
- **Ressources** : météorites (contenu X0).
- **Signature** : **panneaux dorés dépliés en ailes** (la silhouette **la plus large**), **paraboles**,
  balises. 5 à 6 événements.
- **Kit d'époque** :
  - panneau solaire doré (2 tailles) ;
  - parabole ;
  - mât-balise ;
  - réservoir sphérique doré ;
  - bras articulé.
- **Matériaux** : feuille d'or #C9A23A **froissée** (jamais lisse), blanc #CFCBC2, cellules #1E2A55.
  Luminance 88.
- **Lumière** : de jour, reflets bleus des cellules #2F6BFF et balises rouges #FF2A2A. La nuit, balises et halo
  doré. **Animation : balises qui clignotent**, reflet qui court sur les cellules.
- **Δ** : la silhouette passe de la sphère compacte à l'aile large ; l'or arrive.

| Famille | Niveau impair (27) | O / L / V | Niveau pair (28) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 14) | **Spatioport de commandement** : tour ; **2 ailes de panneaux dorés** dépliées (jusqu'à L 3,86) ; grande parabole ; mât-balise. | 3,37 / 3,86 / 21 % | — | balises (script) |
| Mitrailleuse | Tête-satellite : 2 canons, **2 petits panneaux dorés** latéraux (pas plus larges que L) ; parabole de visée. | 2,29 / 2,18 / 17 % | **Mât-balise** au coin avant | balise clignotante (socle) |
| Laser | **Émetteur en parabole** dorée. | 2,49 / 2,07 / 4 % | **Panneaux solaires** devant le socle | cellules |
| Mur | **Bouclier en panneaux dorés** inclinés, ajouré entre les panneaux ; petites paraboles. | 0,95 / 21 % | **Balise** sur chaque tuile, +0,15 | balise (glow fixe, sans clignotement) |
| Foreuse | **Foreuse orbitale** : panneaux dorés en ailes et câble-mât. | 1,51 / 3,18 / 17 % | **Parabole** au sommet (invariante), +0,30 | balises |
| Four | **Four solaire** : **pétales-miroirs dorés** concentrant la lumière sur un creuset. | 1,51 / 2,18 / 25 % | **Pétale supplémentaire** à l'arrière, +0,25 | creuset éclatant |
| Assembleur 2 | Plate-forme à panneaux dorés ; parabole ; bras de grue. | 1,40 / 3,06 / 29 % | **Réservoir sphérique doré**, +0,30 | balises |

### Époque 15 · Légende (ère V, T5)
- **Ressources** : matière exotique (contenu X0).
- **Signature** : **couronne** de flèches multiples, **base flottante** (vide maximal), **halo de particules**,
  or blanc et nacre. 6 événements.
- **Kit d'époque** :
  - flèche de couronne (3 tailles) ;
  - anneau-halo ;
  - socle flottant ;
  - feuille d'animation de particules (partagée par toutes les familles).
- **Matériaux** : or blanc #E8DCB0 (patiné), nacre #D8D2C8, cristal clair. Luminance 108.
- **Lumière** : de jour, lumière blanche dorée #FFF2C0 et particules. La nuit, **halo maximal** (niveau 30).
  **Animation : particules** (feuille invariante de 32 à 60 images, partagée).
- **Δ** : les ailes larges font place à la couronne verticale et à la base flottante. C'est la silhouette la
  plus éloignée du niveau 1 (vérification D1-3).

| Famille | Niveau impair (29) | O / L / V | Niveau pair (30) : pièce | Lumière |
|---|---|---|---|---|
| Centre (niv. 15) | **Palais** : **couronne de 5 flèches** en or blanc ; anneau-halo ; base flottante (vide sous la couronne). Sommet O 3,60. | 3,60 / 3,90 / 25 % | — | particules, halo maximal (script) |
| Mitrailleuse | Tête en **couronne de canons** (6 canons en étoile) flottant sur un **socle-disque** ; halo. | 2,40 / 2,20 / 20 % | **Petites flèches** aux coins avant | particules du socle |
| Laser | **Couronne de prismes émetteurs** ; halo. | 2,60 / 2,10 / 5 % | **Anneau-halo au sol** | particules |
| Mur | Plinthe et **créneaux flottants en or blanc** ; vides entre les merlons et sous la crête. | 1,00 / 25 % | **Flèche de couronne** sur chaque tuile, +0,20 | crête (glow fixe) |
| Foreuse | **Plate-forme flottante** ; tour-flèche ; couronne de petites flèches. | 1,60 / 3,20 / 20 % | **Halo** au sommet (invariant) | particules |
| Four | **Creuset en couronne** flottant ; halo. | 1,60 / 2,20 / 30 % | **Seconde couronne**, +0,20 | particules |
| Assembleur 2 | **Couronne de flèches** et noyau flottant ; cadre ajouré (V ≥ 35 %). | 1,50 / 3,10 / 35 % | **Halo de particules** au-dessus | particules |

---

## 6. Questions de design pour le Directeur Créatif (5 au plus, toutes changent la production)

> **Réponses du Directeur Créatif (21/10, 18 h 49), qui font désormais règle pour V3** (OBJECTIFS §4,
> Q8 à Q12) :
> - **Q-V1-1 → (a)** : « si ajourer veut dire changer le design, c'est oui ». Ajourer veut dire changer la
>   forme (vides, pieds, pièces en lévitation). Le seuil D1-3 reste à 50 % pour toutes les familles.
> - **Q-V1-2** : « comme vous le sentez, il ne serait pas déconant de voir une usine de 10x10 à un moment,
>   par exemple sur des réacteurs d'antimatière ou quoi ». Les plafonds proposés ci-dessous sont
>   retenus pour les 7 familles, dont l'emprise ne change pas. Les nouveaux bâtiments des époques hautes
>   et des branches avancées (lot X0) peuvent être très grands, jusqu'à 10 × 10.
> - **Q-V1-3** : « oui je suis d'accord ».
> - **Q-V1-4** : « oui ».
> - **Q-V1-5** : « oui si vous voulez, je sais pas vraiment l'impact que ça aura en vérité ». Décision de
>   l'architecte : **aucune économie** (2 images de tir, déploiement du laser en 15 images), sauf si le
>   temps de rendu par image mesuré par V0 l'impose.

**Q-V1-1. Les machines denses aux époques 10 à 15 : ajourées ou très hautes ?**
- Pour que le dernier niveau ne ressemble plus au premier (D1-3 < 50 %), le four et l'assembleur doivent
  laisser vide **30 à 35 %** de leur silhouette d'origine ; le mur et la mitrailleuse **20 à 25 %**.
- Trois choix :
  - **(a)** corps sur pieds, pièces en lévitation, structures ajourées (proposé) ;
  - **(b)** bâtiments **beaucoup plus hauts** sans vide : four environ 4 tuiles au-dessus de l'emprise,
    assembleur environ 5,3, mur environ 2,1 ;
  - **(c)** un seuil D1-3 assoupli pour ces familles.

**Q-V1-2. Hauteur maximale à l'époque 15.**
- Proposition :
  - tourelles **+2,4 à +2,6 tuiles** au-dessus de leur emprise ;
  - foreuse, four et assembleur **+1,5 à +1,6** ;
  - mur **+1,0** ;
  - centre **+3,6**.
- Plus haut, c'est plus spectaculaire, mais cela cache les bâtiments situés juste au nord (rangées de machines,
  tourelles derrière les murs).

**Q-V1-3. Une signature d'époque commune aux 7 familles.**
- Exemple : à l'époque 9, tout a des octogones et des tours de refroidissement ; à l'époque 12, tout a des
  anneaux flottants.
- Les familles d'une même époque deviennent cousines, et on lit « c'est l'époque 9 » d'un coup d'œil ;
  l'identité de famille (canons, lentille, cheminée…) dit « c'est une mitrailleuse ».
- Validez-vous ce principe et les 5 ères de 3 époques ?

**Q-V1-4. Niveau 1.**
- Les 6 familles vanilla gardent leur sprite vanilla au niveau 1 (aucune image à produire, référence du
  critère D1-3).
- Le **centre d'époque 1 est redessiné** en poste de pionnier : aujourd'hui, c'est un corps de roboport avec un
  radar, qui se lit comme un bâtiment de fin de partie.
- D'accord ?

**Q-V1-5. Deux économies sur les tourelles.**
- La mitrailleuse passe d'**1 image de tir au lieu de 2** : on perd le recul du canon, pour -42 % d'images sur
  la famille.
- Le laser se **déploie en 8 images au lieu de 15**, pour -22 %.
- Les 64 directions de rotation restent dans tous les cas.

---

## 7. Ordre de production conseillé à V3
1. **Pilote V0/V3** : les pièces du niveau 2 (sacs de sable, barbelé, chevalement, hotte, potence), posées sur
   le vanilla. Elles testent l'accord d'une pièce rendue avec le vanilla (H-V1) au plus bas coût : 7 poses.
2. Familles bon marché d'abord (four, centre, mur), pour roder le pipeline et les tests V4 sur 15 époques.
3. Assembleur, puis foreuse.
4. Tourelles en dernier, une fois le coût réel d'une pose connu et les options Q-V1-5 tranchées.
5. Pour chaque famille, **époques 1, 8 et 15 d'abord**, pour fixer tôt les deux bornes et le milieu
   (D1-2, D1-3), puis remplir.

---

## 8. Ce qui n'est pas vérifié
- **Aucun rendu**, aucune capture : ce document n'a rien vu en jeu. Toutes les silhouettes d'époque sont des
  propositions ❔.
- Le périmètre du masque D1-3 (sans ombre, éclat, lumière ni décalcomanie au sol), la marge IoU ≤ 0,45 et les
  indicateurs du §1.4 sont des **propositions de mesure** à valider.
- Les aires A30 sont des **estimations** (boîte × remplissage de 0,5 à 0,75). Le vide réel à laisser se mesure
  sur les rendus.
- **Moteur** :
  - correspondance exacte entre connexion et clé du mur ;
  - découpage des sprites hauts en bord d'écran ;
  - rendu du `blend_mode = "multiplicative"` pour les ombres de pièces ;
  - durée de vie des objets `rendering` attachés au centre lors d'un remplacement ;
  - limite de taille des feuilles de sprites (4096 px retenu par prudence) ;
  - coût GPU de centaines de lumières de murs.
- La mémoire vidéo (0,8 à 1,4 Go) est une estimation non compressée. Le temps de chargement et le temps de rendu
  par pose ne sont pas mesurés.
- Le défaut D3 du centre actuel (radar sans ombre) est déduit du code, **pas vu en capture**.
- Les couleurs proposées (albédos, émissifs) sont des valeurs de départ. Seules comptent les mesures sur le
  rendu (§1.5).
