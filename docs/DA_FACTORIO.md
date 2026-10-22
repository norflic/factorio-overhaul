# DA_FACTORIO : charte de direction artistique mesurable (lot V3-S)

> **Statut.** Proposition de l'analyste DA, 22/10/2026. **Rien n'est validé** : seul le Directeur Créatif
> valide un design, sur capture. Les seuils ci-dessous servent à refuser automatiquement ce qui est
> clairement hors du style, pas à accepter à sa place.
>
> **Base de mesure.** 28 bâtiments vanilla 1.1.91 (sprites hr, couches et décalages lus dans le Lua
> vanilla par `tests/datastage/harness.lua --dump-proto`), la cheminée V0 validée (commit `4599023`) et sa
> version V0b finale, et 100 aperçus rejetés de V3 phase 1 (mitrailleuse 28, laser 28, assembleur 29,
> centre 15). Tout est mesuré par le même code (`tools/da/da_lib.py`) à 64 px par tuile, sur le corps seul.
> Chiffres bruts (dans `docs/da/`) : `mesures_vanilla.json`, `mesures_apercus_v3p1.json`, `analyse.txt`,
> `seuils_verdicts.txt`, `progression_v3p1.txt`. Planches : `docs/da/planche-A-vanilla-contre-v3p1.png`,
> `docs/da/planche-B-echelle-vanilla.png`.
>
> **Intégration.** Copiée dans le dépôt le 22/10 à 13 h 25 par l'orchestrateur, sans changement de fond :
> seuls les chemins sont adaptés (`outils/` → `tools/da/`, chiffres et planches → `docs/da/`). L'original
> et les dumps restent dans `<racine>\fo-logs\2026-10-22_V3S\charte\`.

---

## 0. Résumé

1. **Le vanilla a une densité de détail constante par tuile, quelle que soit la taille.** Sur 28 bâtiments,
   le nombre de petites pièces suit `pièces ≈ 29,5 × masse¹·⁰⁰` (masse en tuiles² de corps) : du coffre
   1×1 au silo 9×9, environ **29 pièces par tuile²**. Un grand bâtiment vanilla n'est jamais un
   agrandissement : le silo porte 1 885 petites pièces, le réacteur 509, la mitrailleuse 156.
2. **Le vanilla est sombre, chaud, peu saturé, et ses lumières sont petites.** Luminance médiane du corps de
   43 à 76 (médiane 56), 96 % des pixels colorés en teinte chaude, 3 % de pixels saturés, aucune plage
   saturée de plus de 0,34 tuile², zone lumineuse de jour de 0 à 13 % du corps (médiane 3 %).
3. **Le vanilla est massif.** L'emprise est remplie à 80 % (médiane) ; 97 % du corps résiste à une
   ouverture morphologique de 0,27 tuile (« part massive ») ; le dépassement au-dessus de l'emprise vaut
   au plus 0,41 fois le côté (poteaux exclus).
4. **La cheminée V0 validée tombe dans toutes ces bandes** (Laplacien 31, 30 pièces/tuile², grain 3,8,
   luminance médiane 64, 100 % de teinte chaude, 0 % de couleur froide, part massive 0,94). C'est la
   preuve que les seuils décrivent bien le style que le Directeur Créatif a accepté.
5. **Aucun des 100 aperçus de V3 phase 1 ne passe les planchers** (médiane : 9 planchers échoués sur 23 ;
   vanilla : 1). Les trois causes de l'orchestrateur sont confirmées en chiffres :
   - **détail** : 69 à 82 % des niveaux sous chacun des planchers de détail D1 à D5, 84 % sous le plancher
     de grain P1, 91 % au-dessus du plafond de surfaces planes P4 ; le grain est sous le minimum vanilla
     dans 80 % des niveaux ;
   - **couleur** : à l'ère IV, 0 à 6 % de teinte chaude (vanilla 96 %), luminance médiane 81 à 123
     (vanilla au plus 76) ; foyers lumineux et plages saturées jusqu'à 1,4 à 1,8 tuile² (vanilla au plus
     0,44) ;
   - **puissance** : de l'époque 2 à l'époque 15, la mitrailleuse garde la même masse (×1,01) et perd
     57 % de ses petites pièces (×0,43) ; seul le dépassement en hauteur augmente (ρ = 0,95), porté par
     des mâts et des empilements fins. La règle de dominance (§6) n'est respectée que sur 2 paires
     d'époques consécutives sur 13.
6. **Règle nouvelle** : la puissance perçue se lit dans l'**emprise**, la **masse**, le **nombre de pièces**,
   les **systèmes fonctionnels**, l'**énergie visible** et l'**animation**. Chacun de ces indicateurs ne baisse
   jamais d'une époque à la suivante, et au moins deux augmentent. La couleur d'époque est réservée aux
   éléments lumineux. Le corps reste du métal sombre, chaud et usé, à toutes les époques.

---

## 1. Ce que le Directeur Créatif a demandé (cité)

- Verdict du 22/10, 7 h 15 : « ça ne respecte pas la direction artistique du jeu un peu […] Ça manque de
  détail […] on a pas l'impression que les niveaux supérieurs sont vraiment plus badasque les niveaux
  inférieurs en réalité. » (cité tel que transmis par l'orchestrateur)
- Précision du 22/10, 7 h 20 (elle prime) : « si jamais on ne connaît pas le jeu et qu'on regarde tel niveau,
  on a vraiment l'impression que ce niveau-là est plus puissant que le niveau du dessous […] il y a aussi un
  manque de taille […] les dernières machines pour construire, elles sont de taille […] 6 par six […] avec
  la taille, c'est pas que on agrandir l'échelle finalement, c'est on augmente aussi les détails ».
- Antérieurement : « c'est surtout la couleur qui change, ce n'est pas un nouveau design » ; « c'est
  vraiment de la précision que je veux » ; « pas uniquement on change la saturation ou la teinte ». Style
  validé : la cheminée V0 (tôle brune rouillée, cerclages laiton, braises).

**Traduction en exigences mesurables** (chacune a son indicateur au §5 ou au §6) :

| Exigence | Indicateur |
|---|---|
| Respecter la DA du jeu | 23 planchers du §5, calés sur le vanilla et vérifiés sur la cheminée V0 |
| Plus de détail, de la précision | D1 à D5 (densité par tuile) et P1 à P4 (patine), jamais en baisse d'une époque à l'autre |
| Un niveau supérieur paraît plus puissant à un œil naïf | Règle de dominance du §6.1 et test du §6.5 |
| La taille augmente | Échelle d'emprise du §6.2 (2×2 → 6×6 pour la mitrailleuse, proposition) |
| Plus grand = plus de détails, pas un agrandissement | Pièces totales ≥ 26 × masse (loi vanilla, §3.2) |
| Pas seulement la teinte | C1 à C8 : le corps reste sombre et chaud ; la couleur d'époque ne vit que dans L1-L2 |

---

## 2. Méthode de mesure

### 2.1 Composition
- Couches vanilla : celles du prototype (Lua vanilla, `hr_version`), image 0, mitrailleuse, laser et
  artillerie en **pose E** (index `direction_count / 4`). Les masques `apply_runtime_tint` sont teintés de la
  couleur de joueur par défaut (orange 0,869 / 0,5 / 0,13). Les `working_visualisations` de mécanisme sont
  incluses (tour de la foreuse, hélices du four électrique) ; fumée et vapeur sont exclues.
- **Corps** = couches dessinées comme sprite (`main`, `draw_as_glow`, masque d'équipe), alpha ≥ 0,5. Sont
  exclues : ombres (`draw_as_shadow`), lumières (`draw_as_light`, blend additif), décalcomanies au sol
  (`integration_patch`).
- Tout est composé à **64 px par tuile** (hr, `scale = 0,5`), origine au centre de l'entité.
- **Intérieur** = corps érodé de 2 px (on ne mesure pas l'anticrénelage de la silhouette).
- Luminance `L = 0,299 R + 0,587 G + 0,114 B` sur 0-255.

### 2.2 Définitions des indicateurs
| Id | Indicateur | Définition exacte |
|---|---|---|
| D1 | Laplacien moyen | moyenne de \|∇²L\| (noyau 4-voisins) sur l'intérieur |
| D2 | Laplacien au zoom 1 | idem après réduction 2×2 (32 px/tuile, la vue du joueur) |
| D3 | Petites pièces par tuile² | taches de \|G(σ=1) − G(σ=3)\| > 10 (flou normalisé par le masque), connexes (8), de 4 à 256 px (0,001 à 0,06 tuile²), claires et sombres, divisées par la masse en tuiles² |
| D4 | Contraste local | écart-type de L dans une fenêtre 7×7, moyenné sur l'intérieur |
| D5 | Part de contours | part de l'intérieur où Sobel(G(σ=0,7)) / 8 > 12 |
| P1 | Grain des surfaces | moyenne de \|L − G(σ=1)\| sur les surfaces planes (Sobel < 6) : rayures, rouille, salissure |
| P2 | Variance basse fréquence | écart-type de G(σ=2) − G(σ=8) sur les surfaces planes : taches et coulures |
| P3 | Creux sombres | part de l'intérieur où L < G(σ=3) − 20 : joints, occlusion, crasse dans les creux |
| P4 | Surfaces planes | part de l'intérieur où Sobel < 6 (trop haut = tôle lisse de synthèse) |
| C1 | Luminance médiane du corps | p50 de L |
| C2 | Reflets | p95 de L |
| C3 | Teinte chaude | part des pixels colorés (chroma ≥ 0,08) hors lumineux de teinte ≤ 70° ou ≥ 330° |
| C4 | Part saturée | part du corps en S ≥ 0,5 et V ≥ 0,5 |
| C5 | Part saturée hors lumineux | idem, hors zone lumineuse |
| C6 | Plus grande plage saturée | plus grand groupe connexe de pixels saturés, en tuiles² |
| C7 | Peinture froide | part du corps en S ≥ 0,35, V ≥ 0,3, teinte froide (70-330°), hors lumineux |
| C8 | Quasi-blanc | part du corps en L ≥ 220, hors lumineux |
| L1 | Zone lumineuse de jour | (couches `draw_as_glow` d'intensité > 0,25 ∪ pixels « auto-éclairés » V ≥ 0,85 et S ≥ 0,35), dilatée de 3 px, en part du corps |
| L2 | Plus grand foyer lumineux | plus grand groupe connexe de la zone lumineuse, en tuiles² |
| M1 | Remplissage de l'emprise | part du carré d'emprise couverte par le corps |
| M2 | Masse | tuiles² de corps par tuile² d'emprise (dépassements compris) |
| M3 | Part massive | part du corps qui résiste à une ouverture par un carré de 17 px (0,27 tuile) ; « très massive » : 33 px (0,52 tuile) |
| O | Dépassement haut | haut du corps au-dessus du bord nord de l'emprise, en tuiles |

### 2.3 Limites (dites franchement)
- Ce sont des **indicateurs**, pas un jugement. D3 compte des taches de contraste : la rouille et la
  salissure y entrent autant que les rivets. C'est voulu (le vanilla en a), mais un bruit de rendu
  pourrait gonfler D3 et P1. Les aperçus V3p1 sont rendus à 32 échantillons et débruités : s'ils étaient
  bruités, leurs scores seraient **flattés**, donc les écarts mesurés ici sont plutôt sous-estimés.
- Les lumières moteur (`LightDefinition`) du vanilla ne sont pas des sprites : le halo de nuit vanilla n'est
  donc pas mesurable ici. Le halo des aperçus est donné à titre indicatif seulement (§7.4).
- « Foyers lumineux » (nombre) inclut les reflets jaunes très clairs : il est indicatif, pas un seuil.
- Une seule image (image 0) et une seule pose par bâtiment. L'animation n'est pas mesurée sur les
  sprites ; ses règles (§6.3) viennent des `frame_count` lus dans le Lua vanilla.
- La composition « cheminée + four » de la planche A n'est pas la scène de jeu (la cheminée se pose
  derrière le four) ; ses chiffres de masse ne servent pas de référence. Ses chiffres de détail et de
  palette, si.
- Le test du regard naïf (§6.5) n'a pas été fait sur des personnes : la règle de dominance en est un
  substitut automatique, pas une preuve.

---

## 3. Ce que mesure le vanilla 1.1.91

### 3.1 Bandes mesurées (28 bâtiments)
Bâtiments : coffre en acier, four en pierre, four en acier, four électrique, chaudière, machine à vapeur,
turbine, échangeur de chaleur, assembleuses 1, 2 et 3, mitrailleuse, tourelle laser, artillerie, foreuse,
chevalet de pompage, réservoir, raffinerie, usine chimique, accumulateur, sous-station, radar, labo,
**balise, roboport, centrifugeuse, réacteur nucléaire, silo à fusée** (le vanilla « avancé » est en gras).

| Indicateur | min | p25 | **médiane** | p75 | max | Cheminée V0 |
|---|---|---|---|---|---|---|
| D1 Laplacien moyen | 18,6 | 27,7 | **31,4** | 35,5 | 40,6 | 31,3 |
| D2 Laplacien au zoom 1 | 28,3 | 40,2 | **47,1** | 51,5 | 66,6 | 41,0 |
| D3 Petites pièces / tuile² | 16,4 | 25,7 | **29,6** | 32,9 | 44,4 | 30,1 |
| D4 Contraste local 7×7 | 18,4 | 24,8 | **27,0** | 30,3 | 38,9 | 24,0 |
| D5 Part de contours | 0,243 | 0,364 | **0,407** | 0,459 | 0,578 | 0,342 |
| P1 Grain des surfaces | 3,22 | 4,07 | **4,74** | 5,63 | 7,56 | 3,80 |
| P2 Variance basse fréquence | 14,1 | 17,8 | **20,5** | 23,2 | 26,7 | 16,5 |
| P3 Creux sombres | 0,104 | 0,169 | **0,187** | 0,224 | 0,312 | 0,111 |
| P4 Surfaces planes | 0,192 | 0,267 | **0,336** | 0,381 | 0,476 | 0,429 |
| C1 Luminance p50 | 43 | 50 | **56** | 68 | 76 | 64 |
| C2 Luminance p95 | 144 | 167 | **181** | 199 | 216 | 153 |
| C3 Teinte chaude | 0,28 | 0,85 | **0,96** | 0,99 | 1,00 | 1,00 |
| C4 Part saturée | 0,001 | 0,018 | **0,029** | 0,050 | 0,132 | 0,059 |
| C5 Part saturée hors lumineux | 0,001 | 0,008 | **0,016** | 0,021 | 0,064 | 0,000 |
| C6 Plus grande plage saturée (t²) | 0,000 | 0,018 | **0,064** | 0,112 | 0,341 | 0,041 |
| C7 Peinture froide | 0,000 | 0,000 | **0,000** | 0,002 | 0,153 | 0,000 |
| L1 Zone lumineuse de jour | 0,000 | 0,014 | **0,027** | 0,040 | 0,133 | 0,110 |
| L2 Plus grand foyer (t²) | 0,000 | 0,017 | **0,057** | 0,136 | 0,440 | 0,107 |
| M1 Remplissage de l'emprise | 0,45 | 0,72 | **0,80** | 0,87 | 0,99 | (pièce) |
| M2 Masse / tuile d'emprise | 0,55 | 0,77 | **0,87** | 0,92 | 1,11 | (pièce) |
| M3 Part massive (0,27 t) | 0,63 | 0,93 | **0,97** | 0,98 | 0,99 | 0,94 |
| M3b Part très massive (0,52 t) | 0,22 | 0,83 | **0,92** | 0,96 | 1,00 | 0,28 (pièce fine) |
| O / côté de l'emprise (sans la sous-station) | -0,07 | 0,04 | **0,13** | 0,24 | 0,41 (sous-station, un poteau : 0,86) | — |

Les extrêmes s'expliquent : le réservoir, la raffinerie et le réacteur ont de grandes tôles (D bas) ; le
coffre est minuscule (L haut) ; le chevalet, l'accumulateur et la sous-station portent une peinture froide
(vert, bleu) ; la foreuse, le chevalet et la tourelle laser sont ajourés (M bas). **Ce sont des exceptions
isolées, jamais cumulées** : un bâtiment vanilla échoue en médiane à 1 plancher sur 23 (§5).

### 3.2 La loi d'échelle : la taille multiplie les pièces, pas la taille des pièces
Régression sur les 28 bâtiments : **`log(pièces) = 0,997 · log(masse) + 3,385`**, soit `pièces ≈ 29,5 × masse`.

| Emprise | Densité médiane (pièces / tuile²) | Laplacien médian |
|---|---|---|
| 2×2 | 31,0 | 36,0 |
| 3×3 | 29,6 | 31,6 |
| ≥ 4×4 | 26,8 | 26,5 |

Exemples (planche B) : mitrailleuse 2×2, 156 pièces ; artillerie 3×3, 296 ; roboport 4×4, 270 ; réacteur
5×5, 509 ; silo 9×9, **1 885**. Le Laplacien baisse un peu sur les très grands bâtiments (grandes tôles),
la densité de pièces non. **C'est exactement la demande du Directeur Créatif** : « avec la taille […] on
augmente aussi les détails ».

### 3.3 Comment le vanilla montre la progression (et où il ne la montre pas)
- **Entre paliers d'une même machine, le vanilla progresse peu** : assembleuses 1 → 2 → 3, même masse
  (7,1 / 7,0 / 7,0 tuiles²), pièces 183 → 226 → 239 (+31 %), part saturée 0,017 → 0,045 : c'est surtout la
  **peinture** (gris, bleu, vert-jaune). Machine à vapeur → turbine : 401 → 303 pièces. **Le vanilla ne
  satisfait donc pas lui-même la demande « on dirait plus puissant »** pour ses paliers ; il ne faut pas le
  copier sur ce point.
- **La puissance du vanilla de fin de partie vient de bâtiments nouveaux, plus grands, à densité égale** :
  labo 155 pièces (6,3 t²) → balise 282 (7,1) → roboport 270 (10,1) → réacteur 509 (17,7) → silo 1 885
  (70,6). C'est ce mécanisme que la charte impose à chaque époque.
- Les bâtiments avancés ont **plus d'animation** : assembleuses 32 images ; centrifugeuse 3 couches de
  64 images + 3 couches de lumière de 64 images ; silo 4 animations de 32 images ; roboport 3 animations ;
  balise 45 images de lumière ; raffinerie flamme de 60 images. Base : mitrailleuse 2 images de tir, chaudière
  feu de 64 images, four électrique 12 + 4 + 4.

---

## 4. Le vocabulaire visuel de Factorio

Ce qui fait « Factorio », vu sur les sprites mesurés (planches A et B) et chiffré quand c'est possible.

1. **Mécanique fonctionnelle.** Chaque volume a une fonction lisible : cuve, moteur, engrenage, bras,
   piston, échangeur, conduit, armoire électrique. Rien n'est une forme abstraite (pas de cône, de disque
   ou d'anneau nus). Une forme sans fonction se voit comme un décor de science-fiction, pas comme une
   machine.
2. **Tuyaux et câbles partout.** Gaines annelées couleur cuivre (centrifugeuse, réacteur, silo), coudes,
   brides boulonnées, faisceaux de câbles rouges et bleus (roboport), raccords qui sortent du corps. Ils
   cassent la silhouette et portent une grande part des « petites pièces » (D3).
3. **Rivets, boulons, plaques.** Tôles découpées en panneaux à joints, boulons aux angles, cerclages
   (cheminée V0), trappes, charnières. Ce sont eux qui tiennent la surface plane sous 34 % (P4).
4. **Grilles et perforations.** Tambours perforés (centrifugeuse), grilles d'aération, caillebotis (sol du
   silo), ventilateurs (turbine). Les ouvertures montrent un mécanisme derrière, jamais du vide.
5. **Bandes de danger.** Jaune et noir sur les zones qui bougent ou qui tuent : base de l'artillerie,
   bras de la centrifugeuse, fosse du silo. Elles sont la seule couleur vive « peinte » admise en
   quantité (le jaune est une teinte chaude, C3).
6. **Usure.** Rouille, coulures, salissure dans les creux (P3 médian 19 % du corps), arêtes claires usées
   (17 %), grain sur toute tôle (P1 médian 4,7). Aucune surface propre ou uniforme.
7. **Palette de métal désaturé, chaud et sombre.** Médiane de luminance 56 (43 à 76), reflets francs (p95
   144 à 216), saturation moyenne 0,35 mais **très peu de pixels vraiment saturés** (2,9 %) ; 96 % des
   pixels colorés sont chauds (rouille, laiton, cuivre, kaki, jaune). Le bleu, le vert et le violet
   n'existent qu'en touches.
8. **Lumière chaude et localisée.** Foyers petits (médiane 0,06 tuile², max 0,44), zone lumineuse de jour
   médiane 3 % (max 13 %, le four en pierre et sa gueule de feu). La lumière vient d'un **orifice** (gueule,
   hublot, voyant, tube), pas d'une surface entière.
9. **Masse ancrée au sol.** Corps qui remplit l'emprise (80 %), presque entièrement massif (97 %), qui
   déborde peu vers le haut (au plus 0,41 × le côté, hors poteaux). L'élancement vient d'éléments
   fonctionnels (cheminée, antenne, bras) posés **sur** une masse, jamais d'un corps porté par des mâts.
10. **Ancre de style : la cheminée V0.** Tôle brune rouillée, cerclages laiton, rivets, braises au sommet :
    elle passe tous les planchers de détail, de patine et de palette du §5 (seul M1 ne s'applique pas à une
    pièce posée sur un bâtiment).

---

## 5. Seuils chiffrés

**Plancher** = refus automatique (un bâtiment vanilla en échoue en médiane 1 sur 23). **Cible** = la
médiane vanilla, à viser. Les planchers « grands » valent pour une emprise d'au moins 4×4 (16 tuiles²),
parce que les grands bâtiments vanilla ont de grandes tôles. Colonnes de droite : nombre de bâtiments
vanilla (sur 28) et de niveaux V3 phase 1 (sur 100) **en échec** ; la cheminée V0 passe tout sauf M1.

| Id | Indicateur | Plancher ≤ 3×3 | Plancher ≥ 4×4 | Cible | Vanilla en échec | V3p1 en échec |
|---|---|---|---|---|---|---|
| D1 | Laplacien moyen | ≥ 27 | ≥ 22 | 31 | 6 | **73** |
| D2 | Laplacien au zoom 1 | ≥ 40 | ≥ 33 | 47 | 7 | **82** |
| D3 | Petites pièces / tuile² | ≥ 24 | ≥ 24 | 29 | 3 | **81** |
| D4 | Contraste local 7×7 | ≥ 22 | ≥ 18 | 27 | 1 | **69** |
| D5 | Part de contours | ≥ 0,30 | ≥ 0,24 | 0,40 | 1 | **79** |
| P1 | Grain des surfaces | ≥ 3,4 | ≥ 3,4 | 4,7 | 1 | **84** |
| P2 | Variance basse fréquence | ≥ 16 | ≥ 16 | 20 | 1 | 41 |
| P3 | Creux sombres | ≥ 0,10 | ≥ 0,10 | 0,18 | 0 | 47 |
| P4 | Surfaces planes | ≤ 0,45 | ≤ 0,48 | 0,34 | 1 | **91** |
| C1 | Luminance p50 du corps | 43 à 76 | 43 à 76 | 50 à 60 | 1 | 39 |
| C2 | Luminance p95 | ≤ 216 | ≤ 216 | 185 | 1 | 17 |
| C3 | Teinte chaude | ≥ 0,70 | ≥ 0,70 | 0,95 | 3 | 34 |
| C4 | Part saturée | ≤ 0,13 | ≤ 0,13 | 0,04 | 1 | 17 |
| C5 | Part saturée hors lumineux | ≤ 0,04 | ≤ 0,04 | 0,02 | 4 | 10 |
| C6 | Plus grande plage saturée | ≤ 0,35 t² | ≤ 0,35 t² | 0,10 t² | 0 | 10 |
| C7 | Peinture froide hors lumineux | ≤ 0,06 | ≤ 0,06 | 0 | 2 | 13 |
| C8 | Quasi-blanc hors lumineux | ≤ 0,04 | ≤ 0,04 | 0,015 | 1 | 2 |
| L1 | Zone lumineuse de jour | ≤ 0,15 | ≤ 0,15 | selon l'époque (§6.2) | 0 | 32 |
| L2 | Plus grand foyer lumineux | ≤ 0,45 t² | ≤ 0,45 t² | 0,15 t² | 0 | 19 |
| M1 | Remplissage de l'emprise | ≥ 0,60 | ≥ 0,60 | 0,80 | 3 | **63** |
| M2 | Masse / tuile d'emprise | ≥ 0,65 | ≥ 0,65 | 0,87 | 4 | 13 |
| M3 | Part massive (0,27 t) | ≥ 0,88 | ≥ 0,88 | 0,97 | 4 | 35 |

(C1 compte les deux bornes : 35 niveaux au-dessus de 76, 4 en dessous de 43.)

**Plafonds anti-bouillie** (ne pas confondre détail et bruit) : D1 ≤ 41, D3 ≤ 45 pièces/tuile², P1 ≤ 7,6
(maximums vanilla). Au-delà, l'image devient un grain illisible au zoom 1.

**Ce qui n'est PAS un seuil** : le nombre de foyers lumineux (sensible aux reflets jaunes) et le halo de
nuit (non comparable au vanilla, §2.3). Ils sont mesurés et suivis.

Outil : `python tools/da/seuils.py docs/da/mesures_vanilla.json <mesures d'un lot>.json` donne le verdict
par niveau. Pour un nouveau lot, il suffit d'ajouter sa famille à `tools/da/mesure_apercus.py`.

---

## 6. Règles de progression de puissance

### 6.1 Principe : la dominance
Pour une même famille, l'époque `e + 1` **domine** l'époque `e` :
- aucun des indicateurs de puissance ne baisse : **emprise**, **masse** (tuiles² de corps), **petites
  pièces totales**, **systèmes fonctionnels**, **énergie visible** (zone lumineuse de jour), **animations** ;
- **au moins deux** augmentent strictement, dont la masse ou les pièces totales ;
- la **densité** (D3) ne baisse pas de plus de 5 % et reste ≥ 26 pièces/tuile² (0,9 × loi vanilla) ;
- les planchers du §5 restent tenus : la palette (C1 à C8) **ne bouge pas** avec l'époque.

Ce qui ne compte **pas** comme gain de puissance : une teinte, une saturation, un éclaircissement du
corps, un mât, une antenne, un anneau ou un étage fin qui fait monter O sans masse (tiges de moins de
0,15 tuile, comme dans la bible §1.4), un vide.

### 6.2 Échelle des tailles et cibles par époque (mitrailleuse, proposition à valider)
Échelle proposée par l'orchestrateur : une taille de plus par ère. Dans une ère (même emprise), la
puissance monte par le **remplissage** (de 0,75 à 0,90 de masse par tuile d'emprise), les **pièces**, les
**systèmes**, l'**énergie** et l'**animation**.

Formules : `masse_min(e) = max(côté² × m, 1,03 × masse_min(e−1))`, avec m = 0,75 / 0,82 / 0,90 pour la 1re /
2e / 3e époque de l'ère ; `pièces_min(e) = max(26 × masse_min(e), 1,10 × pièces_min(e−1))`. Départ : la
mitrailleuse vanilla mesurée (3,5 tuiles², 156 pièces).

| Ère | Époque (niveau impair) | Emprise | Masse min (t²) | Petites pièces min | O max (t) | Zone lumineuse de jour | Systèmes fonctionnels | Animations |
|---|---|---|---|---|---|---|---|---|
| I | 1 (n1, vanilla) | 2×2 | 3,5 (mesurée) | 156 (mesurées) | 0,8 | 0,02 | 3 | 1 (tir) |
| I | 2 (n3) | 2×2 | 3,6 | 172 | 0,8 | 0,00 à 0,03 (nuit seulement) | 3 | 1 |
| I | 3 (n5) | 2×2 | 3,7 | 189 | 0,8 | 0,02 à 0,04 (1re lueur de jour) | 4 | 2 |
| II | 4 (n7) | 3×3 | 6,8 | 208 | 1,2 | 0,03 à 0,05 | 5 | 2 |
| II | 5 (n9) | 3×3 | 7,4 | 228 | 1,2 | 0,03 à 0,06 | 5 | 2 |
| II | 6 (n11) | 3×3 | 8,1 | 251 | 1,2 | 0,04 à 0,06 | 6 | 3 |
| III | 7 (n13) | 4×4 | 12,0 | 312 | 1,6 | 0,05 à 0,07 | 7 | 3 |
| III | 8 (n15) | 4×4 | 13,1 | 343 | 1,6 | 0,05 à 0,08 | 7 | 3 |
| III | 9 (n17) | 4×4 | 14,4 | 378 | 1,6 | 0,06 à 0,08 | 8 | 4 |
| IV | 10 (n19) | 5×5 | 18,8 | 488 | 2,0 | 0,07 à 0,09 | 9 | 4 |
| IV | 11 (n21) | 5×5 | 20,5 | 536 | 2,0 | 0,07 à 0,10 | 10 | 4 |
| IV | 12 (n23) | 5×5 | 22,5 | 590 | 2,0 | 0,08 à 0,10 | 10 | 5 |
| V | 13 (n25) | 6×6 | 27,0 | 702 | 2,4 | 0,09 à 0,11 | 11 | 5 |
| V | 14 (n27) | 6×6 | 29,5 | 772 | 2,4 | 0,10 à 0,12 | 12 | 6 |
| V | 15 (n29) | 6×6 | 32,4 | 849 | 2,4 | 0,10 à 0,12 (plancher 0,15) | 13 | 6 |

Témoins demandés : **niveau 11** (époque 6, 3×3) ≥ 8,1 t² et ≥ 251 pièces ; **niveau 21** (époque 11, 5×5)
≥ 20,5 t² et ≥ 536 pièces ; **niveau 29** (époque 15, 6×6) ≥ 32,4 t² et ≥ 849 pièces, soit **5,4 fois les
pièces de la mitrailleuse vanilla**, à la même densité qu'elle. Le niveau pair ajoute sa pièce **en plus**
(+0,10 tuile² au moins, critère D1-1 inchangé) et ne descend sous aucun minimum de son époque.

`O max` suit la borne vanilla `O ≤ 0,40 × côté` (hors poteaux). La hauteur croît donc avec l'emprise,
« modérément », et toujours portée par de la masse.

**Systèmes fonctionnels** (comptés sur la fiche de l'époque, à la main) : un système est un groupe qui a une
fonction lisible. Pour la mitrailleuse, dans l'ordre d'apparition proposé : tête à canons, alimentation
en munitions, socle pivotant (ère I) ; blindage frontal, refroidissement des canons, deuxième arme ou
canons jumelés (ère II) ; chargeur automatique, conduits et câblage, capteur ou viseur (ère III) ;
générateur ou condensateur, tourelle secondaire, radiateurs (ère IV) ; plusieurs tourelles secondaires,
réserve d'énergie visible, blindage à plaques multiples (ère V). Chaque époque reprend tout ce qui
précède. Le kit d'époque de la bible (§1.3) habille ces systèmes ; il ne les remplace pas.

**Animations** (plafonds de coût de la bible §1.6 inchangés : animer le socle, jamais ajouter d'images à la
tête hors tir) : chaîne de munitions, flamme, braise qui pulse, arcs, voyants qui clignotent, ventilateurs,
pistons, plasma. Repère vanilla : 1 à 2 animations pour un bâtiment de base, 3 à 4 pour un bâtiment
avancé (centrifugeuse, silo, roboport).

### 6.3 Les autres familles
Même dominance, même formule de pièces (`≥ 26 × masse`), même palette. L'échelle d'emprise de chaque
famille est **une question ouverte pour le Directeur Créatif** (Q-S1 ci-dessous) : la règle « une taille de
plus par ère » donnerait 3×3 → 7×7 pour l'assembleur et 4×4 → 8×8 pour le centre (le silo vanilla fait
9×9). À défaut, la règle minimale est : emprise jamais en baisse, masse et pièces en hausse à chaque
époque.

### 6.4 La couleur d'époque
- Le **corps** garde la palette vanilla à toutes les époques : C1 (luminance p50 de 43 à 76, cible 50 à 60),
  C3 (≥ 70 % de teinte chaude), C7 (peinture froide ≤ 6 %), C8 (quasi-blanc ≤ 4 %).
- Les matériaux d'époque (céramique, alliage blanc, or blanc, nacre, cristal) ne sont admis qu'en
  **accents** (≤ 15 % du corps, règle déjà écrite dans la bible §1.5), **patinés** (P1 ≥ 3,4 sur ces
  surfaces aussi), et posés sur une structure de métal sombre.
- La **couleur d'époque** (cyan, magenta, vert uranium, violet) vit **uniquement dans les éléments
  lumineux** : gueules, hublots, tubes, voyants, fentes, bobines. Chaque foyer fait au plus 0,45 tuile² ;
  aucun anneau, dôme ou cristal saturé de plus de 0,35 tuile² (C6). La quantité de lumière monte avec
  l'époque (§6.2, colonne « zone lumineuse »), la taille de chaque foyer non : on ajoute **des** foyers.
- Bandes de danger jaune et noir, laiton, cuivre : admis à toutes les époques (teintes chaudes).

### 6.5 Le test du regard naïf
- **Planche** : pour chaque famille, les paires (e, e+1) et (e, e+3), côte à côte, **au même zoom** (zoom 1 et
  zoom 2), à côté de bâtiments vanilla de référence (mitrailleuse, assembleuse 2, roboport, réacteur) pour
  que la taille se lise. Ordre gauche-droite mélangé, clé à part.
- **Question** : « lequel est le plus puissant ? ». Cible : 100 % des paires (e, e+3) et au moins 90 % des
  paires (e, e+1) devinées sans hésiter. Le juge est le Directeur Créatif (ou une personne qui ne connaît pas
  le jeu, s'il le souhaite).
- **Substitut automatique, avant toute planche** : la règle de dominance du §6.1 sur les chiffres mesurés
  (`tools/da/progression.py`). Une paire qui ne domine pas est refusée avant d'être montrée.

---

## 7. Écarts mesurés de V3 phase 1 (aperçus rejetés le 22/10)

### 7.1 Bilan
- **0 niveau sur 100** ne passe les 23 planchers ; médiane : **9 planchers échoués** (vanilla : 1, max 7).
- Seuls deux niveaux s'approchent du style : mitrailleuse n11-n12 (époque 6, bobine d'isolateurs : 4 et 2
  échecs) et centre n01 (1 échec). Le pire : assembleur n25-n26 (anneau magenta, 17 échecs), n13 (cristaux,
  16).

### 7.2 Détail et patine (cause 1 confirmée)
| Famille | D1 Laplacien (ère I → V) | D3 pièces/t² (I → V) | P1 grain (I → V) | Pièces totales (I → V) | Vanilla de la famille |
|---|---|---|---|---|---|
| Mitrailleuse | 19,3 → 24,7 | 23,2 → 12,7 | 2,40 → 2,53 | 79 → 40 | 28,8 ; 44,4 ; 3,55 ; 156 |
| Laser | 22,8 → 26,3 | 26,4 → 21,5 | 2,67 → 3,05 | 95 → 53 | 37,0 ; 30,7 ; 4,71 ; 78 |
| Assembleur | 15,4 → 17,2 | 19,6 → 12,7 | 2,17 → 1,90 | 86 → 91 | 31,6 ; 32,4 ; 4,76 ; 226 |
| Centre | 30,7 → 27,8 | 24,1 → 25,2 | 3,67 → 3,61 | 277 → 457 | (médiane vanilla 31,4 ; 29,6 ; 4,74) |

- Le grain des surfaces est **sous le minimum vanilla (3,22) dans 80 niveaux sur 100** : tôles lisses de
  synthèse, sans rouille ni salissure. 91 niveaux ont trop de surfaces planes (P4).
- Au zoom 1 (la vue du joueur), le Laplacien des aperçus vaut 16 à 37 en moyenne par ère contre 47 pour le
  vanilla : **21 à 65 % de détail en moins à l'écran**.
- Le centre est la seule famille dont le détail tient à peu près (Laplacien dans la bande vanilla, grain
  3,1 à 3,7, sous la médiane 4,7) : son écart est surtout de palette (7.3).

### 7.3 Couleur (cause 2 confirmée)
| Famille | C1 luminance p50 (ère I → V) | C3 teinte chaude à l'ère IV | L2 plus grand foyer, max (t²) | C6 plus grande plage saturée, max (t²) |
|---|---|---|---|---|
| Mitrailleuse | 53 → 107 | 0,005 | 0,70 (n25) | 0,15 (n17) |
| Laser | 56 → 106 | 0,058 | 0,45 (n25) | 0,41 (n25, anneau magenta) |
| Assembleur | 54 → 94 | 0,000 | 1,80 (n30) | 1,41 (n25, anneau magenta) |
| Centre | 56 → 98 | 0,333 | 1,61 (n08) | 1,38 (n08, dôme vert) |
| Vanilla | 43 à 76 (médiane 56) | médiane 0,96 | ≤ 0,44 | ≤ 0,34 |

- **Les corps blanchissent avec l'époque** (ρ = 0,69 à 0,80 entre luminance et époque) : 35 niveaux au-dessus
  de la luminance maximale du vanilla. C'est la palette de la bible (§1.5 : cibles 82, 100, 92, 88, 108
  aux époques 10, 11, 13, 14 et 15) qui l'impose : **ces cibles sont hors du vanilla** et doivent être
  retirées (§8).
- À l'ère IV, les corps sont **gris-bleu froids** (0 à 6 % de teinte chaude). 34 niveaux sous le plancher C3.
- Les couleurs d'époque sont portées par des **volumes entiers** lumineux (anneaux, dômes, cristaux) de
  0,4 à 1,8 tuile², jusqu'à 4 fois le plus grand foyer vanilla (0,44, la flamme de la raffinerie). 32 niveaux dépassent 15 % de zone lumineuse
  (vanilla : 13 % au plus, le four en pierre).

### 7.4 Puissance et masse (cause 3 confirmée)
| Famille | M1 remplissage (ère I → V) | M3 part massive (I → V) | O dépassement (I → V) | Masse, époque 2 → 15 | Pièces, époque 2 → 15 | Dominance (§6.1) |
|---|---|---|---|---|---|---|
| Mitrailleuse | 0,61 → 0,30 | 0,93 → 0,77 | 0,96 → 2,28 | ×1,01 | **×0,43** | 2/13 |
| Laser | 0,58 → 0,34 | 0,92 → 0,76 | 1,00 → 2,35 | ×0,66 | ×0,86 | 2/13 |
| Assembleur | 0,55 → 0,52 | 0,78 → 0,71 | 0,47 → 1,61 | ×1,20 | ×0,86 | 3/13 |
| Centre | 0,63 → 0,55 | 0,98 → 0,98 | 1,34 → 3,64 | ×1,37 (de l'époque 1) | ×1,04 | 1/14 |

- La **seule** grandeur qui croît avec l'époque est le dépassement O (ρ = 0,89 à 0,96). Il est porté par des
  mâts, des colonnes de disques et des antennes : à l'époque 15, la mitrailleuse dépasse de 2,44 tuiles sur
  une emprise de 2 (O / côté = 1,22, trois fois la borne vanilla), avec seulement 3,45 tuiles² de corps, soit
  autant que la mitrailleuse vanilla, et 36 petites pièces contre 156.
- **La densité de détail baisse avec l'époque** (ρ entre D3 et l'époque : -0,72 pour la mitrailleuse, -0,54
  pour l'assembleur) : exactement l'inverse de la demande.
- Remplissage sous 0,60 dans 63 niveaux ; la règle « ajourer » (Q8) et le critère D1-3 ont produit des vides
  nus (mitrailleuse n25 : 15 % de l'emprise remplie ; laser n21 : 11 %).
- Halo de nuit (indicatif) : 2 à 24 tuiles² d'intensité > 0,25 (laser n29 : 23,8) ; le plus grand halo
  sprite vanilla mesuré fait 0,56 tuile².

### 7.5 Niveaux témoins (rapport à la mitrailleuse vanilla)
| Niveau | D1 | D3 pièces/t² | Pièces | P1 grain | C1 p50 | M1 | M3 | Masse (t²) | Cible §6.2 |
|---|---|---|---|---|---|---|---|---|---|
| n11 (ép. 6) | 26,7 (×0,93) | 29,1 (×0,66) | 92 | 3,84 | 69 | 0,51 | 0,85 | 3,16 | 3×3 ; ≥ 8,1 t² ; ≥ 251 pièces |
| n21 (ép. 11) | 20,7 (×0,72) | 12,6 (×0,28) | 33 | 2,13 | 114 | 0,18 | 0,87 | 2,62 | 5×5 ; ≥ 20,5 t² ; ≥ 536 pièces |
| n29 (ép. 15) | 31,7 (×1,10) | 10,4 (×0,24) | 36 | 3,46 | 123 | 0,40 | 0,77 | 3,45 | 6×6 ; ≥ 32,4 t² ; ≥ 849 pièces |

Le niveau 29 a **4 % des pièces** que la charte lui demande et **9 fois moins** de masse.

---

## 8. Ce que la bible DESIGN_EPOQUES doit changer (proposition)

1. **§1.5, tableau des albédos** : retirer les luminances médianes cibles 82, 100, 92, 88 et 108 (époques
   10, 11, 13, 14 et 15), toutes au-dessus du maximum vanilla (76). Remplacer par « luminance p50 du corps entre 45 et 72 à toutes les époques ».
   Les albédos clairs (céramique, alliage blanc, or blanc, nacre, carénage gris clair) deviennent des
   accents ≤ 15 % du corps, patinés.
2. **§1.2 et §1.4, « vides » des ères IV et V et IoU de D1-3** : supprimer le « vide minimal croissant /
   maximal ». Avec une emprise qui grandit, D1-3 passe tout seul (mitrailleuse : 3,5 tuiles² au niveau 1
   contre au moins 32 au niveau 29 ; IoU ≤ 0,11). « Ajourer » se relit : treillis, caillebotis, grilles,
   perforations **devant un mécanisme** ; M1 ≥ 0,60 et M3 ≥ 0,88 à toutes les époques.
3. **§1.2, langage de forme des ères IV et V** (« corps sur pieds », « pièces en lévitation », « base
   flottante ») : admis seulement si la masse et les pièces de l'époque sont tenues (§6.2) ; les pieds et
   anneaux ne comptent pas dans la masse.
4. **§1.4, plafonds O** (mitrailleuse 2,40 au niveau 30 sur 2×2) : remplacer par `O ≤ 0,40 × côté` avec
   l'emprise du §6.2.
5. **D1-4 « emprise identique »** : déjà remplacé par la décision Q23 (commit `fae5579`) ; cette charte en
   donne les chiffres.
6. **§1.6, halo de nuit `I(N) = 0,05 + 0,02·N`** : à plafonner (les aperçus mesurent jusqu'à 24 tuiles² de
   halo). Proposition : rayon de halo ≤ 1,5 × le côté de l'emprise.

---

## 9. Questions pour le Directeur Créatif

- **Q-S1** : l'échelle d'emprise « une taille de plus par ère » vaut-elle pour toutes les familles
  (assembleur 3×3 → 7×7, centre 4×4 → 8×8, four 2×2 → 6×6, mur 1×1 → ?) ou seulement pour la
  mitrailleuse ?
- **Q-S2** : la cible de luminance du corps (50 à 60, plafond 76) vaut-elle aussi pour les époques
  « blanches » (11 Titane, 13 Fusion, 15 Légende) ? La charte dit oui ; leur matériau d'époque passerait en
  accents patinés.
- **Q-S3** : le test du regard naïf se fait-il par vous seul, ou voulez-vous qu'on le fasse passer à une
  personne qui ne connaît pas le jeu ?

---

## 10. Reproduction

Depuis `tools/da/` (Python, numpy, Pillow ; aucun moteur, aucun Blender). Les chemins `../` ci-dessous
visaient le dossier d'origine `<racine>\fo-logs\2026-10-22_V3S\charte\` ; dans le dépôt, les chiffres sont
dans `docs/da/` :

```
# 1. dumps vanilla (depuis la racine du mod)
lua5.2 tests/datastage/harness.lua "<racine>/data" . --dump-proto <type>/<nom>   > <dumps>/<type>_<nom>.txt
# 2. cheminée V0 (validée) : git show 4599023:graphics/vitrine/cheminee/<fichier>  > <v0>/<fichier>
# 3. mesures
python mesure_vanilla.py <dumps> "<racine>/data" ../mesures_vanilla.json [<composés>]
FO_DUMPS=<dumps> python mesure_apercus.py "<racine>/mods/factorio-overhaul" <v0> ../mesures_apercus_v3p1.json [<composés>]
python analyse.py ../mesures_vanilla.json ../mesures_apercus_v3p1.json > ../analyse.txt
python seuils.py ../mesures_vanilla.json ../mesures_apercus_v3p1.json > ../seuils_verdicts.txt
python progression.py ../mesures_apercus_v3p1.json > ../progression_v3p1.txt
python planches_charte.py <composés vanilla> <composés aperçus> ../mesures_vanilla.json ../mesures_apercus_v3p1.json ..
```

Durée mesurée : 4 s pour le vanilla, 15 s pour les 104 compositions d'aperçus et de cheminée. Résultat
déterministe (deux passes : JSON identiques à l'octet). Sous Windows, `PYTHONIOENCODING=utf-8` pour les
sorties texte.

**Interpréteur** (constaté à l'intégration, 22/10, 13 h 30) : le `python` par défaut du PC (3.14) n'a PAS
numpy. Lancez les outils avec `py -3.9` (numpy 2.0.2 et Pillow). Contrôle : depuis la racine du mod,
`py -3.9 -B tools/da/seuils.py docs/da/mesures_vanilla.json docs/da/mesures_apercus_v3p1.json` et
`tools/da/analyse.py` redonnent `docs/da/seuils_verdicts.txt` et `docs/da/analyse.txt` à l'octet près ;
`progression.py` redonne `docs/da/progression_v3p1.txt`.
