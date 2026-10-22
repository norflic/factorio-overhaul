# Étalonnage du pipeline de rendu sur les sprites vanilla (lot V0, H-V1)

> Mesuré le 21/10/2026 sur les fichiers de Factorio 1.1.91 (`<racine>\data`), sans moteur.
> Reproduire : `python -P tools/render/calib/measure_vanilla.py "<racine>/data"` (mesures vanilla,
> sortie complète dans [calib/vanilla_mesures.txt](calib/vanilla_mesures.txt)) et
> `python -P tools/render/calib/run_calib.py "<racine>/data" --tag apres` (formes simples rendues et
> comparées). Constantes : [fo_calib.py](fo_calib.py). Toutes les tailles sont en pixels HR
> (64 px/tuile ; au zoom 1 le jeu les affiche à moitié).
>
> **Statut** : les chiffres ci-dessous sont des mesures. Le jugement visuel en jeu (captures jour/nuit,
> zooms 1 et 2) n'est **pas fait** : il revient au Directeur Créatif (OBJECTIFS D1 à D3).

## 1. Résumé

| Grandeur | Vanilla (mesure) | Rendu V0 avant réglage | Rendu V0 après | Réglage retenu |
|---|---|---|---|---|
| Échelle | tuile = 64 × 64 px HR | 64 × 64 | 64 × 64 (plaque d'une tuile : somme d'alpha 64,0 en largeur) | `PX_PER_UNIT_HR = 64` |
| Projection | caméra orthographique à 45°, sol non raccourci (§2) | — | brides 0,743 ; bouche 0,726 (même méthode de mesure) contre vanilla 0,707 à 0,742 et 0,737 | `THETA_DEG = 45` |
| Tuyau N-S / E-O | 39 / 38 px (rapport 0,97) | 40 / 39 | 40 / 39 | rayon 0,305 unité |
| Sphère | arc supérieur du dôme du labo : cercle, écart 0,62 px | — | dôme rendu : cercle de 64,02 px pour 64 | (projection orthographique) |
| Direction des ombres | plein est (pente −5,5° à +1,1°) | plein est | plein est | soleil à l'ouest, azimut 270° |
| Élévation du soleil | 47,6° à 50,3° (moyenne 48,7°) | 48° | 48° | `SUN_ELEV_DEG = 48` |
| Longueur d'ombre / hauteur à l'écran (poteaux) | 1,17 à 1,28 | 1,275 | 1,275 | — |
| Netteté des ombres | rampe 1 à 2 px, cœur alpha 1,0 | nette | nette | `SUN_ANGLE_DEG = 0` |
| Opacité affichée des ombres | alpha × 0,5 (shader du moteur) | — | couche noire, alpha 1 au cœur | — |
| IoU de l'ombre du coffre en bois | — | 0,940 | 0,941 | — |
| Façade sud / dessus (coffres, sRGB) | 0,356 (bois), 0,369 (fer), 0,398 (acier) | **0,588** | **0,368** | soleil 1,9 ; appoint zénithal 1,5 ; ciel 0,08 ; sol 0,15 |
| Profil du tuyau N-S (pic, en rayons) | −0,368 | −0,474 | **−0,368** | appoint zénithal |
| Profil du tuyau E-O (pic) | −0,459 | −0,368 | −0,421 | — |
| Corrélation des profils N-S / E-O | — | 0,918 / 0,874 | **0,981 / 0,970** | acier : métal 0,6, rugosité 0,5 |
| Liseré de contact (alpha, d = 1 à 10 px sous le bord) | 0,94 0,69 0,54 0,41 0,36 0,24 0,21 0,16 0,09 0,10 | aucun (0,96 0,27 0 …, simple anticrénelage) | 0,84 0,69 0,56 0,44 0,34 0,26 0,19 0,13 0,09 0,05 | AO à 0,38 unité, alpha = min(1 ; 5,5 × occlusion²) |
| Silhouette du coffre en bois (IoU) | — | 0,922 | 0,922 | (géométrie et ancrage) |

Images avant / après (gauche : vanilla, droite : rendu) :

| | Avant | Après |
|---|---|---|
| Coffre (sol, ombre affichée à 50 %) | ![](calib/img/avant-coffre.png) | ![](calib/img/apres-coffre.png) |
| Tuyaux | ![](calib/img/avant-tuyaux.png) | ![](calib/img/apres-tuyaux.png) |

## 2. Projection : comment le sol et la hauteur apparaissent

**Hypothèses comparées.**
- (A) image étirée verticalement après un rendu orthographique : les objets ronds sont ronds au rendu,
  puis l'image est étirée de 1/cos θ pour que le sol soit carré ;
- (B) caméra orthographique inclinée de θ, et grille de tuiles étirée en profondeur dans la scène.
  Les objets ronds restent ronds, et une tuile vers le sud mesure 1/cos θ unité.

**Mesures qui tranchent** (§2.1 à §2.3 de `vanilla_mesures.txt`) :
1. **Tuyaux.** Le tuyau nord-sud fait 39 px de large, le tuyau est-ouest 38 px d'épaisseur (alpha ≥ 0,98 ;
   40-41 px à 0,8, ombre portée comprise). (A) donnerait un tuyau est-ouest 1/cos θ plus épais, soit
   +41 % à 45°. **(A) est rejetée.** (B) donne 1,0.
2. **Cercles verticaux face caméra.** Arc d'une bride plate, rapport b/a attendu sin θ :
   - `pipe-to-ground-up` : 0,707 (écart 0,15 px) ;
   - `pipe-cover-south` : 0,729 ;
   - `pipe-cover-north` : 0,742 ;
   - `pipe-ending-down` : 0,739.

   Les bouchons bombés (0,80 à 0,86) sont exclus : le dôme dépasse la bride.
3. **Cercle horizontal.** Bouche de la cheminée du four en acier, ellipse complète : 0,735 à 0,741
   selon le seuil (écart 0,27 à 0,36 px). Le puits du silo, de forme irrégulière, donne 0,673 sur sa
   boîte englobante.
4. **Biais de la méthode, mesuré sur nos rendus à θ = 45° exactement** (vérité 0,7071) :
   - arc supérieur d'une cheminée : 0,726 ;
   - disque face caméra de 0,05 d'épaisseur : 0,743.

   La méthode surestime donc de +0,02 à +0,04. Les mesures vanilla (0,707 à 0,742 et 0,737)
   tombent dans cette fourchette pour θ = 45°. À θ = 48°, on attendrait 0,685 pour la bouche et 0,78 pour
   les brides.
5. **Sphère.** L'arc supérieur du dôme du labo s'ajuste à un cercle (écart 0,62 px) : la projection est
   orthographique, une sphère y reste un cercle. Notre dôme rendu donne un cercle de 64,02 px pour 64.
6. **Documentation du moteur.** Pour `RotatedSprite.apply_projection` (`prototype-api.json`), elle
   écrit : « the 45 degree angle for projection is used ».

**Retenu : θ = 45°, modèle (B).** Correspondance écran, en px HR relatifs à la position de l'entité :
- u = 64·X ;
- v = −64·(Y·cos 45° + Z·sin 45°).

Une tuile vers le sud vaut √2 = 1,414 unité Blender. Une unité de hauteur fait 45,25 px. Incertitude
sur θ : ±2° environ.

**Ancrage** (§2.4). Les bords opaques des bâtiments tombent sur les bords de leur emprise :
- bord bas : four 63 px pour 64, coffres 31 px pour 32, four en pierre 59 px pour 64 ;
- côtés : four −62 / +63 px ;
- le haut dépasse l'emprise (four −81, coffres −38/−39).

Notre convention : le sol Blender correspond exactement à la grille des tuiles, et l'origine est la
position de l'entité au sol. Le `shift` est calculé, multiple exact de 1/64. Vérifications :
- plaque d'une tuile rendue : 64 × 64 px, centrée ;
- coffre en bois reproduit (dessus 37 px, façade 31 px, bord avant à +30,5 px) : IoU 0,922 avec le
  sprite vanilla posé à son `shift`.

## 3. Lumière

### 3.1 Direction et élévation du soleil
- **Direction : plein est à l'écran.**
  - L'ombre du coffre en bois couvre en vertical −7 à +33 px, exactement la bande de contact au sol de la
    boîte (−6,5 à +30,5).
  - Le bout de l'ombre du petit poteau est à la hauteur de son pied (y = +9 et +9).
  - Je n'avais pas supposé de soleil au nord-ouest : l'azimut 270° (ouest pur) a été fixé d'emblée sur
    ces mesures.
  - Mesure indépendante de l'orchestrateur, reçue pendant le lot : pente de la ligne médiane des ombres
    d'objets verticaux de −5,5° à +1,1°, soit un cap de 84 à 91°. Détail : petit poteau +1,1°, moyen −5,5°,
    grand −2,2°, sous-station −1,5°, radar −3,5°. **Concordant.** L'orchestrateur précise que le
    décalage entre les barycentres de l'ombre et du corps (≈ 125°) vient de la hauteur du corps à l'écran,
    pas du soleil : il ne sert pas à caler l'azimut.
- **Élévation.** tan e = hauteur à l'écran / (longueur de l'ombre × sin 45°) :
  - petit poteau : 47,8° ;
  - poteau moyen : 50,3° ;
  - grand poteau : 49,0° ;
  - coffre en bois : 47,6°.

  Moyenne 48,7°, **retenu 48°**. Rapport longueur d'ombre / hauteur à l'écran :
  - vanilla : 1,17 à 1,28 (orchestrateur : 1,07 à 1,30) ;
  - rendu : 1,275.

  L'ombre de notre coffre fait 69 px de long, contre 71 (bois), 75 (fer) et 79 (acier) : ces coffres
  vanilla sont plus hauts que la boîte d'essai.

### 3.2 Ombres
- **Engine (fait, `data/core/graphics/shaders/shadow-a8.frag`).** `shadow = texture.w * 0.5`, couleur
  noire. Une ombre pleine assombrit donc le sol de 50 %.
- Les sprites d'ombre vanilla ont un cœur d'alpha 1,0, un RGB noir ou presque noir (gris + alpha, ou
  RGBA : `hr-iron-chest-shadow.png`, `hr-substation-shadow.png`) et une rampe d'anticrénelage de 1 à
  2 px seulement (§4.1).
- Rendu : sol attrape-ombre éclairé par le seul soleil, angle apparent 0, couche noire. Alpha = part
  d'ombre.

### 3.3 Équilibre des lumières (façades)
Médiane de luminance (sRGB) de la façade sud divisée par celle du dessus :
- vanilla : 0,356 (coffre en bois), 0,369 (fer), 0,398 (acier) ;
- premier essai (soleil 3,2, ciel uniforme 0,55, sol 0,22) : **0,588**, façades trop claires ;
- balayages (`calib/sweep.py`) :
  - ciel 0,05 / 0,12 / 0,20 : 0,416 / 0,451 / 0,483 ;
  - sol 0,08 / 0,12 / 0,16 : 0,308 / 0,348 / 0,384.
- retenu : ciel 0,08, sol 0,15, soit **0,368**. Dessus 0,509 pour un gris de 50 % (vanilla 0,455 à 0,504).

### 3.4 Appoint zénithal (profils des tuyaux)
- Avec le soleil seul à 48°, le reflet du tuyau nord-sud tombe à −0,47 rayon. Vanilla : −0,37.
- La lumière vanilla est donc plus zénithale sur les surfaces courbes, alors que les ombres disent 48°.
- Un **soleil zénithal sans ombre** (intensité 1,5, soleil principal ramené à 1,9) donne :
  - pic N-S à −0,368 (vanilla −0,368) ;
  - pic E-O à −0,421 (vanilla −0,459) ;
  - corrélation des profils de 0,981 (N-S) et 0,970 (E-O) ;
  - un rapport façade/dessus inchangé (0,363 à 0,368), car l'appoint vertical n'éclaire pas les façades.
- Acier de référence : métal 0,6, rugosité 0,5 (balayage : métal 0,3 / 0,6, rugosité 0,5 / 0,65).
- Écart restant : la luminance moyenne du tuyau rendu est 0,494, contre 0,425 en vanilla. C'est un choix de
  matériau par pièce.

## 4. Liseré de contact et couches lumineuses

### 4.1 Liseré
- **Vanilla.** Les sprites principaux des bâtiments (four en acier, four en pierre, assembleur 2,
  mitrailleuse, réservoir, labo) portent sous leur bord bas un liseré sombre semi-transparent. Alpha
  médian à d = 1…12 px : 0,943 0,691 0,541 0,405 0,357 0,244 0,208 0,155 0,093 0,104 0,057 0,047.
  Les coffres n'en ont pas.
- **Rendu.** Passe `ao` : occlusion ambiante limitée à 0,38 unité, de la pièce sur le sol. Alpha =
  min(1 ; 5,5 × occlusion²), couleur droite (0,035 ; 0,030 ; 0,025), composé sous la couche principale.
  Profil obtenu : 0,841 0,691 0,558 0,442 0,344 0,257 0,186 0,130 0,085 0,051 0,029 0,013. Écart maximal
  0,10 à d = 1, ≤ 0,05 au-delà.
- Balayage : portée 0,30 à 0,50, gamma 2 et 3, force 5,1 à 13.

### 4.2 Lueur et halo : formules du moteur
Fait, lu dans `data/core/graphics/shaders/game.frag` :

```
final = mix(LUT(couleur), couleur, clamp(lightmap) * lightMul + lightAdd)
```

- La nuit, la LUT est `core/graphics/color_luts/lut-night.png` (`utility-constants`, heures 0,45 à 0,55).
- `draw_as_glow` dessine le sprite normalement, puis dans la carte des lumières : visible de jour et
  de nuit.
- `draw_as_light` dessine dans la seule carte des lumières : il révèle la couleur de jour de ce qui est
  dessous.
- Disposition de la LUT, vérifiée : 16 tranches de bleu côte à côte, x = rouge, y = vert. La LUT
  identité rend l'entrée à 2·10⁻¹⁶ près.

Codage de nos couches additives (`blend_mode = "additive"`) :
- RGB = c / max(c), A = max(c), soit un prémultiplié égal à c ;
- correct en mode normal comme en additif ;
- aucune zone noire opaque.

Couleurs mesurées :
- **Lueur rendue** (cheminée seule) : moyenne prémultipliée (0,59 ; 0,31 ; 0,11), maximum (1,00 ; 0,62 ;
  0,25) ;
- **vanilla :**
  - feu du four `hr-steel-furnace-working.png` : max (1,00 ; 0,83 ; 0,24) ;
  - lumière au sol `hr-steel-furnace-ground-light.png` : prémultiplié max (0,79 ; 0,39 ; 0,04) ;
  - orchestrateur : lumières des fours orange de (99,49,3) à (241,144,2), en PNG couleur sans teinte.

Halo (V0, **remplacé au lot V0b**, voir §5 ter) : éclairage direct seul de six sources ponctuelles devant la
grille d'évents, borné par deux fenêtres circulaires (flaque au sol pleine jusqu'à 1,1 tuile du pied, nulle à
2,1 ; cœur autour des évents). Mesuré en moteur (rapport V0) : 6,3 tuiles² au lieu de 0,9 à 1,8, cœur
blanc sur le fût, trou à la forme du pied caché sur le four équipé (F64). V0b : flaque au sol seulement,
pièce découpée, valeurs linéaires.

## 5. Photométrie de la couche principale (pixels opaques, sRGB)

| Sprite | L moyenne | écart-type | p05 | p50 | p95 | saturation | grain |
|---|---|---|---|---|---|---|---|
| **Cheminée V0 (rendu final)** | **0,275** | **0,148** | **0,072** | **0,240** | **0,560** | **0,338** | **0,061** |
| four en acier | 0,236 | 0,201 | 0,015 | 0,181 | 0,661 | 0,355 | 0,064 |
| assembleur 2 | 0,251 | 0,196 | 0,032 | 0,194 | 0,660 | 0,404 | 0,057 |
| socle de mitrailleuse | 0,178 | 0,219 | 0,000 | 0,092 | 0,690 | 0,166 | 0,049 |
| réservoir | 0,329 | 0,192 | 0,073 | 0,285 | 0,668 | 0,381 | 0,036 |
| chaudière | 0,274 | 0,190 | 0,052 | 0,225 | 0,657 | 0,333 | 0,050 |
| radar | 0,271 | 0,177 | 0,071 | 0,225 | 0,658 | 0,296 | 0,055 |
| coffre en acier | 0,361 | 0,230 | 0,105 | 0,293 | 0,841 | 0,256 | 0,064 |
| poteau moyen | 0,277 | 0,230 | 0,000 | 0,231 | 0,738 | 0,523 | 0,082 |

Le grain est l'écart-type du passe-haut 3 × 3 de la luminance.

**Dans les plages vanilla** : luminance moyenne, médiane, p05, saturation, grain.

**Hors plage, défaut assumé et non corrigé** :
- écart-type 0,148 (vanilla 0,177 à 0,243) ;
- p95 0,560 (vanilla 0,657 à 0,847).

La cheminée a moins de reflets francs que les bâtiments vanilla. Cause probable : une pièce surtout
verticale, sans dessus plats éclairés par le soleil et l'appoint. Les cerclages en laiton ont fait
monter la saturation de 0,197 à 0,338, mais pas le p95. Pistes :
- plus de pièces horizontales claires (passerelle et lèvre en tôle claire) ;
- reflets d'arête plus vifs.

### 5 bis. Lot V0b : photométrie du CORPS (hors zones émissives), 21/10/2026

La mesure du tableau ci-dessus porte sur toute la couche, braises comprises (vérification V0, rapport 3 :
« fausse conformité »). `fo_checks.photometry` mesure désormais le CORPS seul (alpha ≥ 0,99, hors lueur
dilatée de 2 px). Même méthode, cheminée seule :

| Rendu | L moy | écart-type | p05 | p50 | p95 | part > 0,5 | grain | gradient | réglage |
|---|---|---|---|---|---|---|---|---|---|
| V0 (fichier livré) | 0,271 | 0,131 | 0,114 | 0,238 | 0,511 | 5,3 % | 0,054 | 0,056 | — |
| V0b, filtre 1,0 px (balayage 1) | 0,318 | 0,150 | 0,128 | 0,300 | 0,514 | 6,0 % | **0,089** | 0,080 | rejeté : grain hors plage |
| V0b, filtre 1,5 px (même balayage) | 0,321 | 0,143 | 0,134 | 0,302 | 0,519 | 5,9 % | 0,072 | 0,074 | gardé |
| métal 0,25 (moins de reflets, plus de Lambert) | 0,307 | 0,144 | 0,141 | 0,268 | 0,503 | 5,1 % | 0,071 | 0,072 | sans effet |
| sol des reflets 0,8, ciel des reflets 0 | 0,361 | 0,164 | 0,132 | 0,344 | 0,607 | 20,6 % | 0,077 | 0,087 | — |
| sol des reflets 1,0, ciel 0 | 0,387 | 0,176 | 0,137 | 0,371 | 0,663 | 23,8 % | 0,079 | 0,093 | trop clair |
| **V0b livré** (256 échantillons, sol 0,8, ciel 0, tôle (0,20 ; 0,17 ; 0,13) métal 0,85 rugosité 0,22) | **0,363** | **0,166** | **0,139** | **0,339** | **0,624** | **21,3 %** | **0,076** | **0,088** | — |
| plages vanilla (§5) | 0,178–0,361 | 0,177–0,243 | 0–0,105 | 0,092–0,293 | 0,657–0,847 | — | 0,036–0,082 | — | — |

Balayages : 21 configurations à 96 échantillons (scripts hors dépôt, scratchpad du lot), rendus par le verrou.

**Bilan honnête : la photométrie du corps n'est PAS dans les plages vanilla.** Écart-type +27 % et p95 +22 %
par rapport à V0 (gradient +57 %), mais l'écart-type (0,166) et le p95 (0,624) restent sous le minimum
vanilla, le p05 (0,139) au-dessus du maximum, la moyenne (0,363) et la médiane (0,339) au-dessus. Causes
mesurées :
- un fût vertical vu à 45° n'a ni dessus plat éclairé ni creux profond : aucun réglage de matériau n'a fait
  descendre le p05 sous 0,105 (21 essais) ; les sombres vanilla viennent des intérieurs de bâtiments ;
- avec l'éclairage étalonné, un cylindre vertical ne reçoit aucun reflet spéculaire du soleil ni de
  l'appoint (demi-vecteur à 56° de toute normale horizontale) : seuls les reflets du SOL peuvent créer la
  bande claire vanilla, d'où le sol des reflets (`GROUND_GLOSSY_ALBEDO`) ; il éclaircit aussi les tons moyens ;
- le filtre de 1,0 px (constat du rapport) ajoute surtout du bruit : grain 0,089, hors plage. Gardé à 1,5.
La pièce est donc plus claire et plus métallique que V0 (aspect acier clair). **Le style a été validé sur
V0 : le Directeur Créatif doit revoir ce changement de ton** (captures du lot V0b).

**Rejeté par la vérification des captures V0b, puis remplacé par le correcteur V0b (§5 quater)** : ce réglage
déplaçait la plage tonale vers le haut au lieu de l'élargir et changeait le style validé.

### 5 ter. Lot V0b : halo (draw_as_light) étalonné en moteur

| Mesure (capture debut-z2, même scène que V0) | V0 | V0b | four vanilla (même capture) |
|---|---|---|---|
| surface à λ ≥ 0,1 | 7,10 tuile² | **1,45** | 1,70 |
| intégrale | 1,64 | **0,38** | 0,67 |
| pic (p99) | 0,279 | **0,315** | 0,572 (vacille) |
| portées S / E / O à λ ≥ 0,1 | 1,48 / 1,64 / 1,50 (N 2,19) | **0,86 / 0,88 / 0,86** | — |
| λ sur le corps de la cheminée (médiane, p90) | 0,006 / 0,48 | **0,000 / 0,005** | corps du four 0,03 |
| λ sur la collerette | 0,47 | **0,001** | — |

Réglage : 6 sources de 50 W (300 W), couleur (1 ; 0,49 ; 0,05) de `hr-steel-furnace-ground-light.png`,
fenêtre au sol pleine jusqu'à 0,55 tuile, nulle à 1,05 tuile, valeurs linéaires. Hors moteur (`render.py`) :
pic 0,474, surface 1,53 tuile². La passerelle cache le sol au pied des évents : la flaque est un anneau
(disque sombre de 0,45 tuile autour du pied), géométrie réelle, pas un défaut de calcul.

### 5 quater. Correcteur V0b : retour au ton V0 (22/10/2026)

**Constat de la vérification des captures V0b** (vérification adverse, mesures en jeu) : le « sol clair dans les
reflets » (`GROUND_GLOSSY_ALBEDO` 0,8) n'élargissait pas la plage tonale, il la DÉPLAÇAIT vers le haut : médiane
du corps 83-86/255 (bible : 52 ± 10 à l'époque 2, 58 ± 10 à l'époque 3), 1,9 fois la médiane du four porteur
(V0 : 1,3), pixels neutres doublés, aspect argenté. Le style validé le 21/10 portait sur V0. Le correcteur revient
au ton V0 et cherche le contraste dans les SOMBRES.

**Référence de même nature.** Les plages du §5 sont celles de bâtiments ENTIERS (intérieurs, tuyaux, dessus plats).
La cheminée du four en acier vanilla (`hr-steel-furnace.png`, colonnes 103-152 ou 112-152, lignes 0-118, même
méthode `fo_checks.photometry`) est bien plus sombre et moins contrastée que le four entier :

| Sprite | p05 | p50 | p95 | écart-type | bible p05/p50/p95 | saturation | lap./éc.-type | pics isolés |
|---|---|---|---|---|---|---|---|---|
| four en acier entier | 0,015 | 0,181 | 0,661 | 0,201 | 4/46/169 | 0,36 | 1,19 | 0,66 % |
| sa cheminée (103-152) | 0,020 | 0,148 | 0,423 | 0,148 | 6/38/112 | 0,31 | 1,33 | 0,49 % |
| sa cheminée (112-152) | 0,019 | 0,143 | 0,319 | 0,101 | 5/36/82 | 0,31 | 1,71 | 0,38 % |

En jeu (capture V0b 020, z2 de jour, cheminée du four PORTEUR ÉTEINT de la rangée 03, mêmes pixels que le
sprite, script `chimney_ref.py`) : p05 0,019, p50 0,148 (38/255), p95 0,408, écart-type 0,142, saturation 0,34 :
identique au fichier (écart moyen −0,4/255). Attention : le four vanilla ALLUMÉ est recouvert de jour par sa
visualisation de marche additive (+27, +12, +1 /255 en moyenne sur sa cheminée) ; les références « four allumé »
des vérifications V0 et V0b (p50 0,263, p95 0,908) sont donc gonflées.

Une cheminée vanilla a donc des noirs profonds (p05 0,02), des tons moyens sombres et PEU de hautes lumières
(p95 0,32-0,42). Viser le p95 et l'écart-type d'un bâtiment entier (≥ 0,657 et ≥ 0,177) pousse une cheminée vers
l'argenté.

**Balayages** (96 échantillons, cheminée seule, couche principale composée avec le liseré ; scripts hors dépôt,
`<scratchpad>/v0bf/sweep2.py`, rendus par le verrou ; « env. sombre » = `GROUND_GLOSSY_ALBEDO` 0,05 et
`SKY_GLOSSY_FACTOR` 0) :

| Rendu | p05 | p50 | p95 | éc.-type | bible p50 | pics | remarque |
|---|---|---|---|---|---|---|---|
| V0b implémenteur (sol des reflets 0,8) | 0,137 | 0,335 | 0,623 | 0,166 | 87 | 1,20 % | rejeté (vérification) |
| matériaux V0, géométrie V0b | 0,112 | 0,248 | 0,519 | 0,139 | 64 | 1,01 % | base |
| tôle plus sombre, suie de couronne, lèvre et grille noires (d2) | 0,099 | 0,203 | 0,436 | 0,133 | 53 | 1,16 % | — |
| d2 + reflet de façade (soleil spéculaire seul sous l'horizon, 4 à 8 W) | 0,139-0,147 | 0,277-0,316 | 0,865-0,998 | 0,209-0,231 | 71-80 | 1,9-2,4 % | rejeté : médiane +20, blancs saturés, échelle en treillis clair |
| d2 + rivets sombres et rugueux (k1) | 0,099 | 0,200 | 0,404 | 0,125 | 52 | 0,81 % | — |
| k1 + env. sombre (k3) | 0,072 | 0,157 | 0,385 | 0,130 | 41 | 0,86 % | noirs atteints, médiane trop basse |
| k1 + env. sombre, tôle (0,20 à 0,30) | 0,077-0,081 | 0,164-0,171 | 0,445 | 0,135-0,138 | 43-44 | 0,81-0,84 % | la couleur de la tôle ne pèse presque pas : la rouille (50 % de la surface) fait la médiane |
| k1 + sol 0,10 (`GROUND_ALBEDO`, essai) | 0,073 | 0,167 | 0,445 | 0,137 | 43 | 0,84 % | non retenu : changerait l'éclairage diffus étalonné |
| k1 + cerclages laiton plus clairs (k10) | 0,099 | 0,205 | 0,464 | 0,136 | 53 | 0,75 % | — |
| k10 + env. sombre ou 0,08, rouille plus claire (0,34 à 0,46), tores 0,40, rivets mats (n1, n2, n4, n6) | 0,078-0,085 | 0,167-0,178 | 0,476-0,477 | 0,137-0,139 | 43-46 | 0,77 % | la rouille non plus ne remonte pas la médiane : sous la cible de l'époque 3 |
| **k10 + tores 0,40 + rivets mats, environnement par défaut (n5, RETENU)** | **0,100** | **0,206** | **0,494** | **0,137** | **53** | **0,75 %** | — |

Règle de choix écrite AVANT le balayage final (`<scratchpad>/v0bf/chain.py`) : médiane bible 50 à 56 (la
variante four, plus claire, doit rester sous 1,3 × 46 = 59,8), pics ≤ 0,75 %, puis p05 le plus bas ; repli
n5. Aucune configuration à environnement sombre n'atteint la médiane : n5 est retenu. **Le compromis est donc
explicite** : les noirs profonds (p05 0,078) coûtent 10 niveaux de médiane (43-44/255, sous la cible de
l'époque 3) ; garder la bible coûte les noirs (p05 0,100, la cheminée vanilla est à 0,02). À trancher par le
Directeur Créatif si l'époque 2 seule suffit pour cette pièce.

Les « pics isolés » restants étaient des points BLANCS saturés (255, 255, 2xx) sur les cerclages en TORE (section
ronde : le reflet du soleil y tient sur un pixel), pas sur les rivets : matériau `ring` plus rugueux (0,40).

**Braises** : leur surface éteinte (couche principale) gardait un reflet spéculaire gris (diélectrique), ajouté
sous la lueur : braises (243, 162, 30), bleu/rouge 0,12-0,16. Surface mate (rugosité 1, `Specular IOR Level` 0) :
(232, 141, 6), bleu/rouge 0,02 ; pixels clairs 0,08, saturation 0,92 (feu vanilla en jeu, même capture : voir la
mesure en moteur ci-dessous).

**Rendu final** (256 échantillons, `render.py`, sprites HR livrés, méthode `fo_checks.photometry`) : cheminée
seule p05 0,101, p50 0,206, p95 0,502, écart-type 0,138, bible 19/53/132, saturation 0,29, laplacien/écart-type
1,48 (V0 1,84), pics isolés 0,73 % (V0b 1,17 %, four en acier 0,66 %) ; variante four, partie visible : bible
29/55/140, **rapport au four porteur 55/46 = 1,19** (≤ 1,3 ; V0b 2,00). Règles 1 à 3 de la bible : conformes
pour les époques 2 et 3. Déterminisme : deux rendus indépendants (`render.py --check` de la chaîne de choix, puis `render.py`, pièce reformatée entre les deux sans changer ses valeurs) : **18 fichiers sur 18 identiques**.

**En moteur réel** (`<racine>\fo-logs\2026-10-21_V0b_vitrine-final\`, captures `haute`, `normale`,
`diagnostic` ; scripts des vérificateurs V0b et du correcteur dans `mesures\`), corps hors lueur, z2 de jour :

| Mesure | V0 | V0b implémenteur | **correcteur** | cheminée vanilla (porteur éteint) | assembleur 2 | four éteint (corps) |
|---|---|---|---|---|---|---|
| moyenne | 0,270 | 0,362 | **0,243** | 0,172 | 0,248 | 0,253 |
| écart-type | 0,131 | 0,165 | **0,138** | 0,142 | 0,190 | 0,211 |
| p05 | 0,113 | 0,141 | **0,100** | 0,019 | 0,034 | 0,035 |
| p50 | 0,237 (60/255) | 0,338 (86) | **0,205 (52)** | 0,148 (38) | 0,198 (50) | 0,191 (49) |
| p95 | 0,509 | 0,630 | **0,503** | 0,408 | 0,645 | 0,728 |
| saturation | 0,28 | 0,26 | **0,29** | 0,34 | 0,41 | — |
| p50 / p50 du four porteur éteint (0,191) | 1,24 | 1,77 | **1,07** | — | — | — |

Qualité graphique normale (sprites 32 px) : p50 0,216, écart-type 0,126, p05 0,114, p95 0,494.

Braises de jour (pixels de lueur ≥ 0,9, `ember.py`) : (249, 152, 4), bleu/rouge 0,02, saturation 0,98 ; feu du
four vanilla de la même capture (sprite recalé) : (218, 148, 21), 0,10, 0,90 ; V0b (255, 199, 89), 0,35. Les
braises sont maintenant un peu PLUS saturées que le feu vanilla (aucun bleu).

**Bilan honnête.** Le ton revient à celui de V0 (médiane 52/255 contre 60, aspect tôle brune sombre) et la règle 1
de la bible est tenue ; la médiane égale celle de l'assembleur 2. Le défaut « rendu trop mat » n'est PAS corrigé
au sens des bâtiments entiers (écart-type 0,138 contre 0,190-0,211, p05 0,100 contre 0,034, p95 0,503 contre
0,645-0,728) ; face à la cheminée vanilla, l'écart-type est égal (0,138 contre 0,142) et les hautes lumières plus
fortes, mais les noirs restent bien plus clairs (p05 0,100 contre 0,019). Les noirs profonds demandent soit de
quitter la cible de l'époque 3 (environnement sombre : p05 0,078, médiane 43), soit une géométrie à creux
(intérieur visible, gorges profondes), soit un éclairage d'ambiance plus faible pour TOUTES les pièces
(`SKY_STRENGTH`, `GROUND_ALBEDO` : hors du périmètre du correcteur, changerait les rendus V3). Décision du
Directeur Créatif attendue (planches `planches-dc\`).

## 6. Maquette hors moteur

`calib/maquette.py` compose les fichiers livrés, avec leurs tailles et `shift` du manifeste, sur la
texture vanilla `hr-dirt-4.png` (rangées opaques 320 à 575). La composition suit l'ordre du moteur :
1. les ombres, au maximum des alphas, puis le sol × (1 − 0,5 × alpha) ;
2. les entités, triées par y puis x ;
3. la lueur, additive ;
4. la nuit : LUT `lut-night.png` et carte des lumières.

Scène : assembleur 2, four en acier, cheminée seule, four équipé de la cheminée, mitrailleuse.

| Zoom 1 jour | Zoom 1 nuit |
|---|---|
| ![](calib/img/maquette-zoom1-jour.png) | ![](calib/img/maquette-zoom1-nuit.png) |

Gros plans ×3 au zoom 2 :
- four équipé, de jour : ![](calib/img/gros-plan-four-jour-x3.png)
- four équipé, de nuit : ![](calib/img/gros-plan-four-nuit-x3.png)
- cheminée seule : ![](calib/img/gros-plan-cheminee-jour-x3.png)

Le zoom 2 complet est dans `tools/render/out/maquette/final/` (non versionné).

**Limites de la maquette, non prouvées hors moteur.**
- `lightMul` et `lightAdd` sont pris à 1 et 0.
- Le jeu ajoute une lumière ambiante de nuit, celle du joueur et la carte de détail.
- Le zoom 1 est une moyenne 2 × 2 des sprites HR, alors que le jeu filtre par mipmaps.
- La mitrailleuse est montée sans son masque de couleur de force.
- Les ombres sont combinées par maximum. Le mélange exact du tampon A8 du moteur n'est pas lu, et deux
  ombres pleines donnent 1 dans les deux cas.
