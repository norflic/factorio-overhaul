# Pipeline de rendu 3D (lot V0, hypothèse H-V1)

Une pièce décrite par un **script de modélisation Python** devient, en **une commande**, les sprites
Factorio 1.1.91 de ses quatre couches, prêts à charger : principale, ombre (`draw_as_shadow`), lueur
(`draw_as_glow`) et halo (`draw_as_light`), en haute résolution (64 px/tuile, `scale = 0.5`) et en
résolution normale (32 px/tuile). L'étalonnage (projection, lumière, ombres, liseré de contact,
photométrie) est mesuré sur les sprites vanilla : voir [CALIBRATION.md](CALIBRATION.md).

## Installation (hors dépôt)

| Quoi | Valeur |
|---|---|
| Blender | **5.2.2 LTS** (hash de build `d13f752e3b9c`, compilé le 2026-09-15), version portable `.zip` |
| Source | `https://download.blender.org/release/Blender5.2/blender-5.2.2-windows-x64.zip` (site officiel uniquement) |
| SHA-256 publiée (`blender-5.2.2.sha256`, même dossier) | `3849d17a682cba006075aaa3f3597ecb5c9c30ec31035b2e092c53e40679b535` |
| SHA-256 mesurée du fichier téléchargé | identique (vérifiée avant décompression, 21/10/2026) |
| Chemin | `C:\Users\evan2\tools\blender-5.2.2\blender.exe` (914 Mo ; l'archive .zip a été supprimée après décompression, la somme publiée est gardée dans `C:\Users\evan2\tools\dl-blender-5.2.2\`) |
| Autre chemin | variable d'environnement `FO_BLENDER` |
| Python système | 3.14 avec `numpy` et `Pillow` (`python -m pip install --user pillow numpy`, PyPI) |

Seule la version 5.2.2 est validée : une autre version de Blender peut donner d'autres octets (voir
« Déterminisme »).

## Commande unique

Depuis la racine du mod :

```
python -P tools/render/render.py tools/render/pieces/cheminee.py
```

- options : `--variants seule,four` (par défaut toutes), `--samples N` (défaut 256, `fo_calib.SAMPLES`),
  `--data "<racine>/data"` (sprites vanilla qui servent de masque) ;
- durée mesurée : **118,6 s** pour les 2 variantes de la cheminée (5 passes chacune, 256 échantillons,
  processeur i5-12600KF, 8 fils) ; 357 s au lot V0b, avec deux autres Blender en cours (production V3) ;
- sorties :
  - `graphics/<dest>/hr-<pièce>-<variante>-<couche>.png` et `<pièce>-<variante>-<couche>.png` ;
  - `graphics/<dest>/<pièce>-icon.png` (64 px + 3 mipmaps) ;
  - `graphics/<dest>/sprites.lua` : tailles, `shift` exacts (multiples de 1/64 de tuile), chemins
    `__factorio-overhaul__/...` ; **généré, ne pas modifier** ; lu par `prototypes/vitrine.lua` ;
  - `tools/render/manifests/<pièce>.json` : sommes SHA-256 de chaque fichier, réglages, versions, durées.
- caches : `tools/render/cache/` (rendus 16 bits et `.npy`), `tools/render/out/` (planches) : ignorés
  par git.

Contrôles :

```
python -P tools/render/render.py tools/render/pieces/cheminee.py --check   # déterminisme (octets)
python -P tools/render/check_sprites.py                                     # tailles, shift, grille, sommes
python -P tools/render/calib/run_calib.py "<racine>/data" --tag apres       # étalonnage contre vanilla
python -P tools/render/calib/maquette.py  "<racine>/data" --tag final       # maquette jour/nuit, zooms 1 et 2
```

## Écrire une pièce

Un fichier `tools/render/pieces/<pièce>.py` définit :

```python
PIECE = {"name": "...",
         "variants": {"<v>": {"dest": "vitrine/<pièce>", "anchor_tiles": (tx, ty),
                              "mask": {...}}},          # masque facultatif par un sprite vanilla
         "halo": [{"at": (dx, dy, z), "r": (plein, nul)}], # fenêtres du halo, en tuiles
         "margin_px": 96}
def build(S, C, variant): ...    # S = blender/fo_scene.py, C = fo_calib.py
```

Conventions de modélisation (CALIBRATION.md §2) :
- 1 unité Blender = **largeur d'une tuile** ; +X est, +Y nord, +Z haut ; l'origine est la position de
  l'entité au niveau du sol ;
- les objets sont modélisés à leurs **vraies proportions** (un cercle est un cercle) ; une tuile de jeu
  vers le sud vaut `1/cos 45° = 1,414` unité en Y : utiliser `C.tile_to_blender(tx, ty, z)` ;
- une hauteur de 1 unité fait 45,25 px HR à l'écran ;
- outils : `S.box`, `S.cylinder` (`radius2` pour un cône, `caps=False` pour un tube ouvert), `S.torus`,
  `S.sphere`, `S.rivet_ring`, `S.join` ; matériaux `S.mat_metal` (grain, rouille, crasse des creux),
  `S.mat_flat`, `S.mat_emissive` (couches lueur et halo) ; `S.halo_light` (source ponctuelle de la seule
  passe halo : lumière portée sans bruit).

## Nouveautés V0b (corrections après la vérification des captures V0)

Toutes les entrées restent les mêmes (fichiers, fonctions, paramètres, variables de module de
`fo_scene`, `fo_post`, `fo_calib`, `render.py`) ; les nouveautés sont des clés ou des paramètres
**facultatifs**. Rapport d'origine : `<racine>\fo-logs\2026-10-21_V0_verif-captures\rapport.md`.

**Comportements V0b, À ACTIVER par pièce** (correcteur V0b : par défaut, rien ne change pour une pièce
existante, en particulier les familles V3 qui passent par `fo_scene.render_passes` ; leurs rendus validés
restent reproductibles à l'octet après la fusion). Une pièce les active par
`PIECE["calib"] = {"LIGHT_HOLDOUT": True}` (la cheminée le fait) ; **toute pièce nouvelle avec un halo doit
l'activer**. Trois changements, plus un code de sortie :

| Quoi | V0 (défaut) | V0b (`LIGHT_HOLDOUT` vrai pour la pièce) | Réglage |
|---|---|---|---|
| 1. Passe `light` (`fo_scene.render_passes`) | pièce gris clair éclairée, sources émissives visibles | pièce **découpée** (`is_holdout` : alpha 0 sur sa silhouette, elle garde son ombre) ; parties cachées invisibles ; volumes de remplacement noirs | `PIECE["calib"]["LIGHT_HOLDOUT"]` (ou `fo_calib.LIGHT_HOLDOUT`, défaut `False`) |
| 2. Couche halo de `render.py` | `additive_layer` des valeurs sRGB, fenêtres au sol et « cœur » | `fo_post.light_layer` : valeurs **linéaires** × `LIGHT_SCALE`, × min(alpha du rendu, 1 − alpha de la passe principale) | `PIECE["light_mode"] = "v0"` / `"v0b"`, sinon suit `LIGHT_HOLDOUT` |
| 3. Variante masquée (`mask`) de `render.py` | couches `main` et `glow` découpées par l'alpha du sprite vanilla | `glow` et halo découpés ; `main` **non** découpée (le jeu dessine le bâtiment par-dessus) ; liseré de contact retiré dans la silhouette du bâtiment dilatée de `AO_DISTANCE` | idem (`light_mode`) |
| Code de sortie de `render.py` | 0 | **3** si un contrôle bloquant échoue (les fichiers et le manifeste sont écrits quand même) | — |

Historique : l'implémenteur V0b avait mis `LIGHT_HOLDOUT = True` par défaut ; le correcteur V0b l'a remis à
`False` (vérification V0b : sinon la passe halo de toutes les familles V3 changeait à la fusion).

L'étalonnage de la scène (soleil, appoint, ciel, sol, filtre de pixel 1,5 px, liseré) ne change pas : le
filtre de 1,0 px a été essayé et rejeté (CALIBRATION §5).

Pourquoi le halo change : `draw_as_light` est une carte des lumières en **espace écran** qui révèle la
couleur de JOUR de tout ce qu'elle recouvre (F64). Une pièce éclairée dans sa propre couche halo apparaît
en plein jour la nuit (collerette V0 : λ 0,43 contre 0,03 pour un four vanilla) ; un bâtiment recouvert par
la flaque est éclairé sur toute sa hauteur (four équipé V0 : λ 0,20 contre 0,03) ; une partie cachée qui
bloquait la lumière laisse un « trou » à sa forme (défaut bloquant V0). La lueur des parties émissives passe
par la couche `glow` (`draw_as_glow` dessine aussi dans la carte des lumières).

**Clés facultatives d'une pièce** (`PIECE`) :
- `"calib": {"NOM": valeur}` : surcharges d'étalonnage de la pièce (passées à Blender par `--set`, et lues
  par `render.py` pour `LIGHT_HOLDOUT`), par exemple `{"LIGHT_HOLDOUT": True}` ;
- `"epoque"` : époque (entier) ou époques (liste) que la pièce sert : active les règles de palette de la
  bible, **bloquantes** (contrôles ci-dessous) ;
- `"light_mode": "v0" | "v0b"` ; `"light_scale"` (multiplie `LIGHT_SCALE`) ;
- `"enclosed_tolerance_px"` : pixels transparents enfermés tolérés (ouvertures voulues ; défaut 0) ;
- dans une variante : `"occluders": [{"box": (x0, y0, x1, y1), "h": hauteur}]` (volume de remplacement,
  tuiles relatives à l'entité, hauteur en unités Blender) ; `"mask_layers"` (défaut `("glow",)`).

**Outils de modélisation** (`fo_scene`) :
- `S.mark_hidden(obj)` : partie cachée par le bâtiment porteur. Rendue dans la couche principale (le
  bâtiment la recouvre en jeu), retirée de la passe `ao`, invisible à la caméra dans la passe `light`, et
  elle **garde son ombre** ;
- `S.add_occluder(size, loc)` : volume de remplacement (boîte noire) présent dans la seule passe `light` ;
  il bloque la lumière et ne la reçoit pas ;
- `S.mat_emissive(..., main_scale=0.0)` : surface ÉTEINTE dans la couche principale ; la lueur additive seule
  donne la couleur, comme le feu vanilla. Avec 1,0 (défaut, V0), l'émission compte deux fois en jeu ;
- `fo_calib.GROUND_GLOSSY_ALBEDO` et `fo_calib.SKY_GLOSSY_FACTOR` : sol et ciel vus par les SEULS rayons
  spéculaires (défaut `None` : comme V0) ; à régler par pièce dans `"calib"`. Effet mesuré : CALIBRATION
  §5 bis : un sol clair dans les reflets éclaircit TOUS les tons moyens d'une pièce verticale (cheminée V0b à
  0,8 : médiane 83-86/255, aspect argenté, rejeté par la vérification) ;
- `S.mat_metal(..., soot=(z0, z1, part), dirt_distance=0.25)` (correcteur V0b, facultatifs) : suie selon la
  hauteur du monde (couleur × (1 − part) et surface mate entre z0 et z1 ; z1 < z0 pour une suie vers le bas),
  portée de la crasse des creux ;
- `S.mat_emissive(..., crust=(échelle, part, graine))` (correcteur V0b, facultatif) : croûte d'un lit de
  braises (émission × 1 − part + part × bruit) ; un lit uniforme se lit comme un disque orange plat.
- surface ÉTEINTE d'une braise (`main_scale=0`) : la rendre MATE dans la pièce (`Roughness` 1, `Specular IOR
  Level` 0 sur le Principled BSDF du matériau renvoyé) ; sinon son reflet spéculaire gris s'ajoute sous la lueur
  et bleuit les braises (cheminée : bleu/rouge 0,12-0,16 avant, 0,02 après ; CALIBRATION §5 quater) ;
- pièces en TORE (cerclages, mains courantes, bourrelets) : rugosité 0,40 au moins ; plus lisse, le reflet du
  soleil y tient sur UN pixel saturé en blanc (« lucioles » : pics isolés, scintillement au zoom 1).

Essai REJETÉ (correcteur V0b, CALIBRATION §5 quater) : un « reflet de façade » (soleil spéculaire seul sous
l'horizon, pour la bande claire des cylindres vanilla) donnait le p95 et l'écart-type des bâtiments vanilla, mais
montait la médiane de 20 niveaux (71-80/255), saturait les rivets en blanc et changeait l'échelle en treillis
clair ; le code a été retiré.

**Contrôles automatiques** (`fo_checks.py`, appelés par `render.py`, détail dans le manifeste, clé
`checks` ; `render.py` sort avec le code 3 sur un échec bloquant) :
- bloquants : pixels transparents enfermés dans la silhouette (le sol se voit au travers) ; plus de 3 % de
  l'énergie du halo sur la pièce ou sur le bâtiment porteur ; poche sombre enfermée dans le halo ;
- bloquants ajoutés par le correcteur V0b : règles de palette de la bible (`docs/DESIGN_EPOQUES.md` §1.5)
  quand la pièce déclare `"epoque"` : médiane du corps (alpha ≥ 0,5, hors lueur, /255) à ± 10 de la cible de
  CHAQUE époque déclarée (`fo_calib.BIBLE_MEDIAN`), entre 40 et 110, p95 ≤ 240, saturation moyenne ≤ 0,45 ;
  pour une variante posée sur un bâtiment vanilla, médiane de la partie visible / médiane du sprite porteur
  ≤ `fo_calib.CARRIER_RATIO_MAX` (1,3 ; cheminée V0 1,3, V0b 1,9 en jeu) ;
- mesurés (avertissements) : éléments plus fins que 2 px HR, photométrie du CORPS hors zones émissives
  comparée à `fo_calib.PHOTO_RANGES` (écart-type, p05, **p50**, p95, moyenne, **saturation**, **rapport
  laplacien / écart-type**, **part de pics isolés d'un pixel** ; en gras : ajouts du correcteur), plus grand
  carré émissif (D2-1 : 8 px HR au moins), pic, surface et portées N/S/E/O du halo (`LIGHT_PEAK_RANGE`,
  `LIGHT_AREA_RANGE`).
`check_sprites.py` refait sur les PNG livrés les contrôles bloquants (trous, halo sur la pièce ou le
bâtiment, poches, règles de la bible, rapport au bâtiment porteur).

### Règle des pièces posées sur un bâtiment vanilla (exemple : `pieces/cheminee.py`, variante `four`)
1. **Composition** : les couches de la pièce (ombre, principale) sont insérées AVANT celles du bâtiment
   (`table.insert(animation.layers, 1, couche)`) : le jeu dessine le bâtiment par-dessus et compose
   lui-même ses bords anticrénelés. Ne pas découper la couche principale (`mask_layers` sans `"main"`).
2. **Passe halo** : un volume de remplacement du bâtiment (`occluders`), **inscrit** dans la silhouette de
   son sprite (une boîte plus grande noircit le sol vu juste au-dessus du toit).
3. **Parties cachées** : `S.mark_hidden(obj)` (pied, socle...) : pas de liseré de contact sans cause
   visible, pas de trou dans le halo, ombre gardée.
4. **Flaque au sol hors de la silhouette du bâtiment** : `mask` (sprite vanilla aux deux résolutions) ; le
   halo est découpé par son alpha, aucun halo sur le corps du bâtiment.
5. **Lueur et halo en visualisations de marche** quand le bâtiment en a (four, assembleur, foreuse) :
   `working_visualisations` avec `fadeout = true`, lueur en `draw_as_light = true` (sprite + carte des
   lumières), halo en `draw_as_light = true, draw_as_sprite = false` (idiome vanilla du four en acier) : ils
   s'éteignent avec le bâtiment.
6. **Ancre** sur la grille de 1/32 de tuile (la version 32 px/tuile tombe alors au pixel).

**Filtrage au zoom 1 (toutes les pièces, prouvé en moteur au lot V0b)** : poser
`flags = { "linear-minification" }` sur la couche principale ET sur la lueur (normale et `hr_version` ; la
lueur depuis le correcteur V0b, `working_visualisations` comprises). Sans ce drapeau, la
couche HR d'un mod est échantillonnée au PLUS PROCHE au zoom 1 (rangées de rivets crénelées, scintillement
possible) ; avec lui, elle est filtrée 2×2 comme les bâtiments vanilla. Mesure (cheminée seule, capture z1) :
sans drapeau, plus proche 0,056 contre moyenne 2×2 0,088 ; avec, moyenne 2×2 0,053 contre plus proche 0,086.
Lueur (correcteur V0b, script `z1glow.py`, captures z1 de jour, 175 px de lueur, erreur moyenne /255 contre la
composition prédite) : sans drapeau (captures de l'implémenteur V0b), plus proche (0, 0) 3,2 contre moyenne 2×2
14,9 ; avec, moyenne 2×2 3,2 contre plus proche 14,3 à 15,5 ; même résultat pour la lueur du four équipé, qui
est une `working_visualisations`.
Scintillement au zoom 1 (correcteur V0b, vitrine `phases_z1`, captures `diagnostic`) : une caméra décalée de
0,25, 0,5 ou 0,75 pixel donne une image IDENTIQUE au pixel près pour la cheminée (|ΔL| ≤ 0,02/255) : la
position de la caméra de `take_screenshot` est ramenée sur la grille des pixels (vers le bas, 0,75 px ne
décale pas). Aucun scintillement de phase sous-pixel n'existe donc dans les captures ; en partie, avec une
caméra qui suit le joueur, NON PROUVÉ.
Attention : les drapeaux suivent l'IMAGE. Deux prototypes qui utilisent le même fichier avec des drapeaux
différents reçoivent le même filtrage (observé : la cheminée sans drapeau était filtrée tant qu'un double
avec drapeau existait). Exemple : `prototypes/vitrine.lua` (`MAIN_FLAGS`).

**Épaisseur minimale** : tout élément fait au moins 2 px HR (0,031 unité) ; un élément plus fin devient
une frange semi-transparente (le sol se voit au travers, et la nuit l'anneau ressort).

## Les cinq passes et le post-traitement

| Passe | Contenu (Cycles, CPU) | Devient |
|---|---|---|
| `main` | pièce éclairée : soleil d'ouest 48°, appoint zénithal sans ombre, ciel faible, sol invisible qui renvoie la lumière | couche principale |
| `ao` | occlusion ambiante à courte portée de la pièce sur le sol | liseré de contact sombre, composé SOUS la couche principale (comme les bâtiments vanilla) |
| `shadow` | ombre du seul soleil sur un sol attrape-ombre | couche ombre (noire, alpha = part d'ombre ; le moteur l'affiche à 50 %) |
| `glow` | émission seule, cachée par les parties opaques | couche lueur, additive, codée RGB = c/max, A = max |
| `light` | lumière reçue des sources de halo sur le sol (éclairage direct seul), pièce découpée (V0b), bornée par des fenêtres circulaires centrées sur le pied (en espace écran = espace tuile pour le sol) | couche halo, additive, valeurs linéaires |

Puis : masque éventuel par l'alpha d'un sprite vanilla posé sur la même grille (variante « four » :
lueur et halo), recadrage aligné sur la grille paire relative à la position de l'entité, réduction 2× en
lumière linéaire prémultipliée pour la version 32 px/tuile (masquée ensuite par le sprite vanilla 32 px).

## Verrou de rendu

`with_render_lock.py` : 2 places sur le PC, priorité basse, verrous orphelins repris. Aucune file
d'attente : la première scrutation qui trouve une place la prend (`--poll S`, défaut et **minimum** 5 s depuis
le correcteur V0b : à 0,5 s, un agent passait devant les autres). Mesuré le 21/10
pendant la production V3 : jusqu'à 11 min d'attente pour une place. Regrouper ses rendus dans UNE commande
(un script qui enchaîne les passages) plutôt que de reprendre le verrou à chaque essai.

**Limite constatée (correcteur V0b, 22/10, non corrigée)** : le minimum de 5 s ne vaut que pour l'attente
interne. Les files des lots V3 relancent `--wait 0` toutes les secondes (par exemple
`pieces/levels/assembler/rendre.py`) et reprennent chaque place libérée en moins de 5 s. Mesure du correcteur :
aucune place en 15 min de scrutation à 5 s ; à la même cadence d'une seconde que les lots V3, place obtenue
après 41 min et 1 778 essais. L'équité demande une vraie file d'attente (tickets ordonnés dans le dossier du
verrou), à faire par l'intégrateur avec tous les lots.

## Déterminisme

Mêmes entrées → **mêmes octets** : Cycles sur CPU, graine fixe (`fo_calib.SEED`), nombre d'échantillons
fixe, échantillonnage adaptatif, débruitage, guidage et tramage coupés, 8 fils, PNG 16 bits relus sans
conversion. Vérifié le 21/10/2026 : deux rendus complets → **18 fichiers sur 18 identiques**
(`render.py --check`) ; refait au lot V0b sur la pièce corrigée (holdout, volumes de remplacement,
surcharges `calib`) : **18 sur 18 identiques** (276,5 s). Refait par le correcteur V0b (22/10) sur la pièce finale (tores, croûte des braises, suie) : **18 sur 18
identiques** entre deux rendus indépendants (303,7 s chacun). Non vérifié : indépendance vis-à-vis du nombre de fils et d'une autre version de
Blender ou d'un autre processeur (écart possible dans les derniers bits ; on refait alors le manifeste).

## Ce que l'outil ne prouve PAS

- Le rendu en moteur réel (zooms, filtrage des mipmaps, carte des lumières de nuit) : la maquette
  applique les formules des shaders du jeu (`data/core/graphics/shaders`), mais `lightMul` et
  `lightAdd` du moteur sont inconnus. Seules les captures en jeu et le verdict du Directeur Créatif
  valident un design.
