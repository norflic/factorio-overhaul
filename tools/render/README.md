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
  processeur i5-12600KF, 8 fils) ;
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

## Les cinq passes et le post-traitement

| Passe | Contenu (Cycles, CPU) | Devient |
|---|---|---|
| `main` | pièce éclairée : soleil d'ouest 48°, appoint zénithal sans ombre, ciel faible, sol invisible qui renvoie la lumière | couche principale |
| `ao` | occlusion ambiante à courte portée de la pièce sur le sol | liseré de contact sombre, composé SOUS la couche principale (comme les bâtiments vanilla) |
| `shadow` | ombre du seul soleil sur un sol attrape-ombre | couche ombre (noire, alpha = part d'ombre ; le moteur l'affiche à 50 %) |
| `glow` | émission seule, cachée par les parties opaques | couche lueur, additive, codée RGB = c/max, A = max |
| `light` | lumière reçue des sources de halo (éclairage direct seul), bornée par des fenêtres circulaires | couche halo, additive |

Puis : masque éventuel par l'alpha d'un sprite vanilla posé sur la même grille (variante « four »),
recadrage aligné sur la grille paire relative à la position de l'entité, réduction 2× en lumière
linéaire prémultipliée pour la version 32 px/tuile (masquée ensuite par le sprite vanilla 32 px).

## Déterminisme

Mêmes entrées → **mêmes octets** : Cycles sur CPU, graine fixe (`fo_calib.SEED`), nombre d'échantillons
fixe, échantillonnage adaptatif, débruitage, guidage et tramage coupés, 8 fils, PNG 16 bits relus sans
conversion. Vérifié le 21/10/2026 : deux rendus complets → **18 fichiers sur 18 identiques**
(`render.py --check`). Non vérifié : indépendance vis-à-vis du nombre de fils et d'une autre version de
Blender ou d'un autre processeur (écart possible dans les derniers bits ; on refait alors le manifeste).

## Ce que l'outil ne prouve PAS

- Le rendu en moteur réel (zooms, filtrage des mipmaps, carte des lumières de nuit) : la maquette
  applique les formules des shaders du jeu (`data/core/graphics/shaders`), mais `lightMul` et
  `lightAdd` du moteur sont inconnus. Seules les captures en jeu et le verdict du Directeur Créatif
  valident un design.
