# Calculs d'équilibre (généré)

> **Document GÉNÉRÉ** par `lua5.2 tools/calc/equilibre.lua` (piste CALCULS). Ne pas éditer : relancer le calculateur.
> Données : `tools/calc/donnees.lua` (`harness.lua --dump-calc`, étape data FINALE vanilla 1.1.91 + mod), `shared/levels/config.lua`,
> `shared/content/modules.lua` (barème D-17), `shared/content/epochs.lua` (calendrier X0). Contrôlé par `lua5.2 tests/calc_test.lua`.

## 0. Méthode et hypothèses

- **Matière brute (MU)** : coût minimal, en minerai extrait, d'une unité nette de l'objet (programme linéaire sur TOUTES les recettes du jeu :
  sous-produits jetés s'ils ne servent pas, boucles comprises : Kovarex, chlore du titane, craquage). 1 minerai solide = 1 MU, 10 unités de
  fluide de gisement = 1 MU, eau et vapeur gratuites ; l'uranium consomme 1 acide sulfurique par minerai.
- **Hypothèses de modules** (machines au niveau maximal de l'époque, 2e ; meilleur palier dont la recette est rangée à l'époque, `X.base_recipe_epochs`) :
  - **H0** : aucun module (c'est le modèle actuel de `levels_test --tables` et de `--calibrate`) ;
  - **H1** : modules de vitesse dans toutes les cases (ne change que le nombre de machines) ;
  - **H2r** : modules de productivité dans toutes les cases des machines qui les admettent (limitation du jeu), foreuses EXCLUES ;
  - **H2** : comme H2r, foreuses comprises (le minerai lui-même est multiplié).
- Fusion : four en acier de la famille, sans case : jamais de module (le four électrique vanilla, 2 cases, n'est pas compté).
- Recherche de productivité minière vanilla, balises et bonus d'équipe : NON comptés.

## 1. Incohérences relevées (14)

| Gravité | Constat |
|---|---|
| FAUX | Époque 4 : `plastic-bar` déclarée 1,5 u, matière brute réelle 0,99 (rapport 1,52, hors de 0,67 à 1,5). |
| FAUX | Époque 5 : `fo-tungsten-plate` déclarée 2 u, matière brute réelle 1 (rapport 2, hors de 0,67 à 1,5). |
| BIAIS | Époque 7 : `fo-resonance-crystal` déclarée 3 u, matière brute réelle 1 (rapport 3, hors de 0,67 à 1,5) ; rareté assumée par X0 (gisements rares, valeur de monnaie au-dessus du minerai). |
| FAUX | Époque 10 : `processing-unit` déclarée 75 u, matière brute réelle 45,34 (rapport 1,65, hors de 0,67 à 1,5). |
| BIAIS | Époque 15 : `space-science-pack` déclarée 250 u, matière brute réelle 133,41 (rapport 1,87, hors de 0,67 à 1,5) ; monnaie provisoire. |
| NOTE | Détour : dès l'époque 10, la chaîne la moins chère de `plastic-bar` sous H2 abandonne `crude-oil` (brut principal de H0) : coal-liquefaction, fo-polyethylene, fo-steam-cracking, gisement:coal, heavy-oil-cracking, light-oil-cracking. |
| NOTE | Détour : dès l'époque 10, la chaîne la moins chère de `battery` sous H2 abandonne `crude-oil` (brut principal de H0) : battery, coal-liquefaction, copper-plate, fo-iron-concentrate, fo-iron-plate-r8, fo-iron-plate-r8-unpacking, gisement:coal, gisement:copper-ore, gisement:iron-ore, heavy-oil-cracking, light-oil-cracking, sulfur, sulfuric-acid. |
| NOTE | Détour : dès l'époque 14, la chaîne la moins chère de `processing-unit` sous H2 abandonne `copper-ore` (brut principal de H0) : advanced-circuit, coal-liquefaction, electronic-circuit, fo-iron-concentrate, fo-iron-plate-r8, fo-iron-plate-r8-unpacking, fo-polyethylene, fo-steam-cracking, gisement:coal, gisement:iron-ore, heavy-oil-cracking, light-oil-cracking, processing-unit, sulfur, sulfuric-acid. |
| BIAIS | command : le niveau 5 coûte × 2,76 du niveau 4 (2 285 → 6 318 u). |
| BIAIS | command : le niveau 11 coûte × 4,19 du niveau 10 (16 055 → 67 260 u). |
| NOTE | assembler niveau 20 (époque 10) : 24 modules de productivité palier 5 dépassent le plafond × 328,67 du moteur (cases perdues). |
| NOTE | drill niveau 20 (époque 10) : 24 modules de productivité palier 5 dépassent le plafond × 328,67 du moteur (cases perdues). |
| NOTE | Recettes d'assembleur qui dépasseraient 60 fabrications/s (le moteur bride) avec la machine de l'époque pleine de modules de vitesse : époque 6 : 21 ; époque 7 : 78 ; époque 8 : 90 ; époque 9 : 91 ; époque 10 : 211 ; époque 11 : 211 ; époque 12 : 211 ; époque 13 : 214 ; époque 14 : 214 ; époque 15 : 214. |
| NOTE | Bruts sans gisement ni recette (comptés 1 MU) : wood. |

## 2. Monnaies d'époque : valeur déclarée contre matière brute réelle

| Époque | Objet en jeu | Valeur déclarée (u) | MU réelle H0 | Déclarée / réelle | MU réelle H2 (modules de l'époque) | Gain H2 | Monnaie X0 (papier) | Valeur X0 |
|---|---|---|---|---|---|---|---|---|
| 2 | `steel-plate` | 5 | 5 | 1 | 5 | × 1 | même | 5 |
| 3 | `engine-unit` | 9 | 9 | 1 | 9 | × 1 | même | 9 |
| 4 | `plastic-bar` | 1,5 | 0,99 | 1,52 | 0,99 | × 1 | même | 1,5 |
| 5 | `fo-tungsten-plate` | 2 | 1 | 2 | 1 | × 1 | même | 2 |
| 6 | `battery` | 5,5 | 5,35 | 1,03 | 0,56 | × 9,64 | même | 5,5 |
| 7 | `fo-resonance-crystal` | 3 | 1 | 3 | 0,18 | × 5,56 | même | 3 |
| 8 | `fo-methane-barrel` | 10 | 10 | 1 | 0,85 | × 11,82 | `fo-biopolymer` (absent du jeu) | 4 |
| 9 | `uranium-238` | 14 | 11,76 | 1,19 | 1,03 | × 11,4 | même | 14 |
| 10 | `processing-unit` | 75 | 45,34 | 1,65 | 1,3 × 10^-6 | × 3,5 × 10^7 | même | 75 |
| 11 | `fo-titanium-plate` | 20 | 25,95 | 0,77 | 0,05 | × 555,45 | même | 20 |
| 12 | `fo-superconducting-coil` | 60 | 82,28 | 0,73 | 7,4 × 10^-3 | × 1,1 × 10^4 | même | 60 |
| 13 | `uranium-235` (provisoire) | 45 | 34,54 | 1,3 | 1 × 10^-3 | × 3,4 × 10^4 | `fo-plasma-cell` (absent du jeu) | 25 |
| 14 | `rocket-control-unit` (provisoire) | 150 | 102,73 | 1,46 | 1,7 × 10^-7 | × 5,9 × 10^8 | `fo-superalloy` (absent du jeu) | 45 |
| 15 | `space-science-pack` (provisoire) | 250 | 133,41 | 1,87 | 9 × 10^-3 | × 1,5 × 10^4 | `fo-stabilized-exotic-matter` (absent du jeu) | 1500 |

Paniers de base (L.item_value) :

| Objet | Valeur déclarée | MU réelle H0 |
|---|---|---|
| `iron-plate` | 1 | 1 |
| `copper-plate` | 1 | 1 |
| `stone-brick` | 2 | 2 |
| `iron-gear-wheel` | 2 | 2 |
| `electronic-circuit` | 2,5 | 2,5 |

## 3. Machines des niveaux : vitesse, emprise, cases et modules (barème D-17, multiplication, plafond × 328,67)

### Assembleur

| Niveau | Époque | Vitesse | Côté | Vitesse / tuile | Cases | Palier dispo. | × vitesse (H1) | Vitesse / tuile H1 | × productivité (H2) | × sortie (H2) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 0,75 | 3 | 0,083 | 5 | — | 1 | 0,083 | 1 | 1 |
| 2 | 1 | 0,81 | 3 | 0,09 | 6 | — | 1 | 0,09 | 1 | 1 |
| 3 | 2 | 0,87 | 3 | 0,097 | 7 | — | 1 | 0,097 | 1 | 1 |
| 4 | 2 | 0,93 | 3 | 0,103 | 8 | — | 1 | 0,103 | 1 | 1 |
| 5 | 3 | 0,99 | 3 | 0,11 | 9 | — | 1 | 0,11 | 1 | 1 |
| 6 | 3 | 1,05 | 3 | 0,117 | 10 | — | 1 | 0,117 | 1 | 1 |
| 7 | 4 | 1,11 | 4 | 0,069 | 11 | — | 1 | 0,069 | 1 | 1 |
| 8 | 4 | 1,17 | 4 | 0,073 | 12 | — | 1 | 0,073 | 1 | 1 |
| 9 | 5 | 1,23 | 4 | 0,077 | 13 | — | 1 | 0,077 | 1 | 1 |
| 10 | 5 | 1,29 | 4 | 0,081 | 14 | — | 1 | 0,081 | 1 | 1 |
| 11 | 6 | 1,35 | 4 | 0,084 | 15 | 1 / 1 | 15,41 | 1,3 | 4,18 | 3,09 |
| 12 | 6 | 1,41 | 4 | 0,088 | 16 | 1 / 1 | 18,49 | 1,629 | 4,59 | 3,3 |
| 13 | 7 | 1,47 | 5 | 0,059 | 17 | 1 / 1 | 22,19 | 1,305 | 5,05 | 3,59 |
| 14 | 7 | 1,53 | 5 | 0,061 | 18 | 1 / 1 | 26,62 | 1,629 | 5,56 | 3,89 |
| 15 | 8 | 1,59 | 5 | 0,064 | 19 | 1 / 1 | 31,95 | 2,032 | 6,12 | 4,16 |
| 16 | 8 | 1,65 | 5 | 0,066 | 20 | 1 / 1 | 38,34 | 2,53 | 6,73 | 4,51 |
| 17 | 9 | 1,71 | 5 | 0,068 | 21 | 1 / 1 | 46,01 | 3,147 | 7,4 | 4,81 |
| 18 | 9 | 1,77 | 5 | 0,071 | 22 | 1 / 1 | 55,21 | 3,909 | 8,14 | 5,21 |
| 19 | 10 | 1,83 | 6 | 0,051 | 23 | 5 / 5 | 328,67 | 16,707 | 328,67 | 65,73 |
| 20 | 10 | 1,89 | 6 | 0,053 | 24 | 5 / 5 | 328,67 | 17,255 | 328,67 | 65,73 |
| 21 | 11 | 1,95 | 6 | 0,054 | 25 | 5 / 5 | 328,67 | 17,803 | 328,67 | 65,73 |
| 22 | 11 | 2,01 | 6 | 0,056 | 26 | 5 / 5 | 328,67 | 18,351 | 328,67 | 65,73 |
| 23 | 12 | 2,07 | 6 | 0,057 | 27 | 5 / 5 | 328,67 | 18,899 | 328,67 | 65,73 |
| 24 | 12 | 2,13 | 6 | 0,059 | 28 | 5 / 5 | 328,67 | 19,446 | 328,67 | 65,73 |
| 25 | 13 | 2,19 | 6 | 0,061 | 29 | 5 / 5 | 328,67 | 19,994 | 328,67 | 65,73 |
| 26 | 13 | 2,25 | 6 | 0,062 | 30 | 5 / 5 | 328,67 | 20,542 | 328,67 | 65,73 |
| 27 | 14 | 2,31 | 6 | 0,064 | 31 | 10 / 10 | 328,67 | 21,09 | 328,67 | 65,73 |
| 28 | 14 | 2,37 | 6 | 0,066 | 32 | 10 / 10 | 328,67 | 21,637 | 328,67 | 65,73 |
| 29 | 15 | 2,43 | 6 | 0,068 | 33 | 10 / 10 | 328,67 | 22,185 | 328,67 | 65,73 |
| 30 | 15 | 2,49 | 6 | 0,069 | 34 | 10 / 10 | 328,67 | 22,733 | 328,67 | 65,73 |

### Four

| Niveau | Époque | Vitesse | Côté | Vitesse / tuile | Cases | Palier dispo. | × vitesse (H1) | Vitesse / tuile H1 | × productivité (H2) | × sortie (H2) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 2 | 2 | 0,5 | 0 | — | 1 | 0,5 | 1 | 1 |
| 2 | 1 | 2,16 | 2 | 0,54 | 0 | — | 1 | 0,54 | 1 | 1 |
| 3 | 2 | 2,32 | 2 | 0,58 | 0 | — | 1 | 0,58 | 1 | 1 |
| 4 | 2 | 2,48 | 2 | 0,62 | 0 | — | 1 | 0,62 | 1 | 1 |
| 5 | 3 | 2,64 | 2 | 0,66 | 0 | — | 1 | 0,66 | 1 | 1 |
| 6 | 3 | 2,8 | 2 | 0,7 | 0 | — | 1 | 0,7 | 1 | 1 |
| 7 | 4 | 2,96 | 3 | 0,329 | 0 | — | 1 | 0,329 | 1 | 1 |
| 8 | 4 | 3,12 | 3 | 0,347 | 0 | — | 1 | 0,347 | 1 | 1 |
| 9 | 5 | 3,28 | 3 | 0,364 | 0 | — | 1 | 0,364 | 1 | 1 |
| 10 | 5 | 3,44 | 3 | 0,382 | 0 | — | 1 | 0,382 | 1 | 1 |
| 11 | 6 | 3,6 | 3 | 0,4 | 0 | 1 / 1 | 1 | 0,4 | 1 | 1 |
| 12 | 6 | 3,76 | 3 | 0,418 | 0 | 1 / 1 | 1 | 0,418 | 1 | 1 |
| 13 | 7 | 3,92 | 4 | 0,245 | 0 | 1 / 1 | 1 | 0,245 | 1 | 1 |
| 14 | 7 | 4,08 | 4 | 0,255 | 0 | 1 / 1 | 1 | 0,255 | 1 | 1 |
| 15 | 8 | 4,24 | 4 | 0,265 | 0 | 1 / 1 | 1 | 0,265 | 1 | 1 |
| 16 | 8 | 4,4 | 4 | 0,275 | 0 | 1 / 1 | 1 | 0,275 | 1 | 1 |
| 17 | 9 | 4,56 | 4 | 0,285 | 0 | 1 / 1 | 1 | 0,285 | 1 | 1 |
| 18 | 9 | 4,72 | 4 | 0,295 | 0 | 1 / 1 | 1 | 0,295 | 1 | 1 |
| 19 | 10 | 4,88 | 5 | 0,195 | 0 | 5 / 5 | 1 | 0,195 | 1 | 1 |
| 20 | 10 | 5,04 | 5 | 0,202 | 0 | 5 / 5 | 1 | 0,202 | 1 | 1 |
| 21 | 11 | 5,2 | 5 | 0,208 | 0 | 5 / 5 | 1 | 0,208 | 1 | 1 |
| 22 | 11 | 5,36 | 5 | 0,214 | 0 | 5 / 5 | 1 | 0,214 | 1 | 1 |
| 23 | 12 | 5,52 | 5 | 0,221 | 0 | 5 / 5 | 1 | 0,221 | 1 | 1 |
| 24 | 12 | 5,68 | 5 | 0,227 | 0 | 5 / 5 | 1 | 0,227 | 1 | 1 |
| 25 | 13 | 5,84 | 6 | 0,162 | 0 | 5 / 5 | 1 | 0,162 | 1 | 1 |
| 26 | 13 | 6 | 6 | 0,167 | 0 | 5 / 5 | 1 | 0,167 | 1 | 1 |
| 27 | 14 | 6,16 | 6 | 0,171 | 0 | 10 / 10 | 1 | 0,171 | 1 | 1 |
| 28 | 14 | 6,32 | 6 | 0,176 | 0 | 10 / 10 | 1 | 0,176 | 1 | 1 |
| 29 | 15 | 6,48 | 6 | 0,18 | 0 | 10 / 10 | 1 | 0,18 | 1 | 1 |
| 30 | 15 | 6,64 | 6 | 0,184 | 0 | 10 / 10 | 1 | 0,184 | 1 | 1 |

### Foreuse

| Niveau | Époque | Vitesse | Côté | Vitesse / tuile | Cases | Palier dispo. | × vitesse (H1) | Vitesse / tuile H1 | × productivité (H2) | × sortie (H2) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 0,5 | 3 | 0,056 | 5 | — | 1 | 0,056 | 1 | 1 |
| 2 | 1 | 0,55 | 3 | 0,061 | 6 | — | 1 | 0,061 | 1 | 1 |
| 3 | 2 | 0,6 | 3 | 0,067 | 7 | — | 1 | 0,067 | 1 | 1 |
| 4 | 2 | 0,65 | 3 | 0,072 | 8 | — | 1 | 0,072 | 1 | 1 |
| 5 | 3 | 0,7 | 3 | 0,078 | 9 | — | 1 | 0,078 | 1 | 1 |
| 6 | 3 | 0,75 | 3 | 0,083 | 10 | — | 1 | 0,083 | 1 | 1 |
| 7 | 4 | 0,8 | 4 | 0,05 | 11 | — | 1 | 0,05 | 1 | 1 |
| 8 | 4 | 0,85 | 4 | 0,053 | 12 | — | 1 | 0,053 | 1 | 1 |
| 9 | 5 | 0,9 | 4 | 0,056 | 13 | — | 1 | 0,056 | 1 | 1 |
| 10 | 5 | 0,95 | 4 | 0,059 | 14 | — | 1 | 0,059 | 1 | 1 |
| 11 | 6 | 1 | 4 | 0,062 | 15 | 1 / 1 | 15,41 | 0,963 | 4,18 | 3,09 |
| 12 | 6 | 1,05 | 4 | 0,066 | 16 | 1 / 1 | 18,49 | 1,213 | 4,59 | 3,3 |
| 13 | 7 | 1,1 | 5 | 0,044 | 17 | 1 / 1 | 22,19 | 0,976 | 5,05 | 3,59 |
| 14 | 7 | 1,15 | 5 | 0,046 | 18 | 1 / 1 | 26,62 | 1,225 | 5,56 | 3,89 |
| 15 | 8 | 1,2 | 5 | 0,048 | 19 | 1 / 1 | 31,95 | 1,534 | 6,12 | 4,16 |
| 16 | 8 | 1,25 | 5 | 0,05 | 20 | 1 / 1 | 38,34 | 1,917 | 6,73 | 4,51 |
| 17 | 9 | 1,3 | 5 | 0,052 | 21 | 1 / 1 | 46,01 | 2,393 | 7,4 | 4,81 |
| 18 | 9 | 1,35 | 5 | 0,054 | 22 | 1 / 1 | 55,21 | 2,981 | 8,14 | 5,21 |
| 19 | 10 | 1,4 | 6 | 0,039 | 23 | 5 / 5 | 328,67 | 12,782 | 328,67 | 65,73 |
| 20 | 10 | 1,45 | 6 | 0,04 | 24 | 5 / 5 | 328,67 | 13,238 | 328,67 | 65,73 |
| 21 | 11 | 1,5 | 6 | 0,042 | 25 | 5 / 5 | 328,67 | 13,695 | 328,67 | 65,73 |
| 22 | 11 | 1,55 | 6 | 0,043 | 26 | 5 / 5 | 328,67 | 14,151 | 328,67 | 65,73 |
| 23 | 12 | 1,6 | 6 | 0,044 | 27 | 5 / 5 | 328,67 | 14,608 | 328,67 | 65,73 |
| 24 | 12 | 1,65 | 6 | 0,046 | 28 | 5 / 5 | 328,67 | 15,064 | 328,67 | 65,73 |
| 25 | 13 | 1,7 | 6 | 0,047 | 29 | 5 / 5 | 328,67 | 15,521 | 328,67 | 65,73 |
| 26 | 13 | 1,75 | 6 | 0,049 | 30 | 5 / 5 | 328,67 | 15,977 | 328,67 | 65,73 |
| 27 | 14 | 1,8 | 6 | 0,05 | 31 | 10 / 10 | 328,67 | 16,433 | 328,67 | 65,73 |
| 28 | 14 | 1,85 | 6 | 0,051 | 32 | 10 / 10 | 328,67 | 16,89 | 328,67 | 65,73 |
| 29 | 15 | 1,9 | 6 | 0,053 | 33 | 10 / 10 | 328,67 | 17,346 | 328,67 | 65,73 |
| 30 | 15 | 1,95 | 6 | 0,054 | 34 | 10 / 10 | 328,67 | 17,803 | 328,67 | 65,73 |

## 4. Chaînes : machines pour 1 monnaie par seconde, machines de l'époque

| Époque | Monnaie | Machines H0 | Tuiles H0 | Machines H1 (vitesse) | Tuiles H1 | Machines H2 | Tuiles H2 | Fluides de gisement H0 (u/s) | Machines H0 (détail) |
|---|---|---|---|---|---|---|---|---|---|
| 2 | `steel-plate` | 13,5 | 139 | 13,5 | 139 | 13,5 | 139 | — | 2,6 fo-arc-furnace, 2,67 fo-coke-oven, 0,4 fo-lvl-assembler-4, 7,69 fo-lvl-drill-4, 0,1 fo-ore-concentrator |
| 3 | `engine-unit` | 29,4 | 283 | 29,4 | 283 | 29,4 | 283 | — | 2,73 fo-arc-furnace, 2,67 fo-coke-oven, 11,79 fo-lvl-assembler-6, 12 fo-lvl-drill-6, 0,23 fo-ore-concentrator |
| 4 | `plastic-bar` | 1,9 | 25 | 1,9 | 25 | 1,9 | 25 | crude-oil 6,6 | 0,72 chemical-plant, 0,02 fo-electrolyzer, 0,39 fo-lvl-drill-8, 0,44 fo-steam-cracker, 0,33 oil-refinery |
| 5 | `fo-tungsten-plate` | 2,3 | 36 | 2,3 | 36 | 2,3 | 36 | — | 0,07 fo-arc-furnace, 0,1 fo-lvl-assembler-10, 2,11 fo-lvl-drill-10, 0,03 fo-ore-concentrator |
| 6 | `battery` | 12,1 | 149 | 6,1 | 70 | 6,3 | 68 | crude-oil 29,5 | 7,15 chemical-plant, 0,05 fo-arc-furnace, 0,11 fo-electrolyzer, 0,12 fo-lvl-assembler-12, 2,29 fo-lvl-drill-12, 0,85 fo-lvl-furnace-12, 0,05 fo-ore-concentrator, 1,48 oil-refinery |
| 7 | `fo-resonance-crystal` | 1,3 | 33 | 0 | 1 | 0,3 | 8 | — | 1,3 fo-lvl-drill-14 |
| 8 | `fo-methane-barrel` | 10,3 | 190 | 4,7 | 57 | 1,1 | 19 | fo-methane 50 | 2,6 fo-arc-furnace, 2,67 fo-coke-oven, 0,95 fo-lvl-assembler-16, 4 fo-lvl-drill-16, 0,1 fo-ore-concentrator |
| 9 | `uranium-238` | 29,6 | 519 | 10,1 | 102 | 12,9 | 154 | crude-oil 14,9 | 12,08 centrifuge, 1,58 chemical-plant, 0,01 fo-arc-furnace, 0,06 fo-electrolyzer, 0,01 fo-lvl-assembler-18, 15,07 fo-lvl-drill-18, 0,01 fo-ore-concentrator, 0,74 oil-refinery |
| 10 | `processing-unit` | 92,2 | 2658 | 23,1 | 518 | 0,1 | 3 | crude-oil 33,6, fo-brine 0,5 | 4,67 chemical-plant, 1,97 fo-arc-furnace, 17,5 fo-cleanroom, 1 fo-coke-oven, 0,34 fo-electrolyzer, 0,38 fo-jaw-crusher, 17,6 fo-lvl-assembler-20, 28,92 fo-lvl-drill-20, 15,87 fo-lvl-furnace-20, 0,47 fo-ore-concentrator, 1,78 fo-steam-cracker, 1,68 oil-refinery |
| 11 | `fo-titanium-plate` | 45,6 | 1053 | 10,6 | 98 | 13,3 | 129 | fo-brine 54,5 | 5 chemical-plant, 0,77 fo-arc-furnace, 6 fo-coke-oven, 9,27 fo-electrolyzer, 0,5 fo-kroll-reactor, 23,55 fo-lvl-drill-22, 0,53 fo-ore-concentrator |
| 12 | `fo-superconducting-coil` | 182,5 | 4273 | 44,1 | 701 | 12,9 | 98 | crude-oil 82,8, fo-brine 55 | 21,98 chemical-plant, 2,55 fo-arc-furnace, 17,5 fo-cleanroom, 10 fo-coil-winder, 7 fo-coke-oven, 0,8 fo-cryogenic-unit, 10,1 fo-electrolyzer, 6 fo-extraction-column, 0,38 fo-jaw-crusher, 0,5 fo-kroll-reactor, 19,98 fo-lvl-assembler-24, 56,06 fo-lvl-drill-24, 15,77 fo-lvl-furnace-24, 1,08 fo-ore-concentrator, 6 fo-sintering-furnace, 2,67 fo-steam-cracker, 4,14 oil-refinery |
| 13 | `uranium-235` | 135,5 | 2177 | 38,7 | 359 | 2,8 | 26 | crude-oil 43,7 | 94,26 centrifuge, 4,65 chemical-plant, 0,02 fo-arc-furnace, 0,16 fo-electrolyzer, 0,03 fo-lvl-assembler-26, 34,15 fo-lvl-drill-26, 0,02 fo-ore-concentrator, 2,18 oil-refinery |
| 14 | `rocket-control-unit` | 181,7 | 5672 | 35,5 | 1136 | 0,2 | 8 | crude-oil 99,2, fo-brine 0,5 | 11,88 chemical-plant, 2,47 fo-arc-furnace, 17,5 fo-cleanroom, 1 fo-coke-oven, 0,58 fo-electrolyzer, 0,37 fo-jaw-crusher, 56,49 fo-lvl-assembler-28, 50,14 fo-lvl-drill-28, 29,11 fo-lvl-furnace-28, 0,97 fo-ore-concentrator, 6,22 fo-steam-cracker, 4,96 oil-refinery |
| 15 | `space-science-pack` | 251,8 | 7255 | 46,2 | 1314 | 3,8 | 82 | crude-oil 196,6, fo-brine 15,5 | 35,48 chemical-plant, 4,48 fo-arc-furnace, 19,25 fo-cleanroom, 4,82 fo-coke-oven, 3,4 fo-electrolyzer, 0,41 fo-jaw-crusher, 0,14 fo-kroll-reactor, 74,42 fo-lvl-assembler-30, 59,79 fo-lvl-drill-30, 31,56 fo-lvl-furnace-30, 1,24 fo-ore-concentrator, 6,64 fo-steam-cracker, 9,83 oil-refinery, 0,3 rocket-silo |

## 5. Coût de chaque niveau : valeur déclarée, matière brute réelle H0 et H2

Valeur déclarée : `L.cost_value` (ce que compte le calendrier). Réelle : quantités × MU réelle de chaque objet, à l'époque où l'on paie.

### Centre

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 310 iron-plate, 160 copper-plate, 160 stone-brick, 60 electronic-circuit | 940 | — | 940 | 1 | 940 | 9 / 24 |
| 3 | 2 | 360 iron-plate, 180 copper-plate, 180 stone-brick, 70 electronic-circuit, 80 steel-plate | 1 475 | 1,57 | 1 475 | 1 | 1 475 | 10 / 32 |
| 4 | 3 | 400 iron-plate, 210 copper-plate, 210 stone-brick, 80 electronic-circuit, 70 engine-unit, 85 steel-plate | 2 285 | 1,55 | 2 285 | 1 | 2 285 | 14 / 40 |
| 5 | 4 | 450 iron-plate, 230 copper-plate, 230 stone-brick, 85 electronic-circuit, 1 990 plastic-bar, 220 engine-unit | 6 318 | 2,76 | 5 301 | 0,84 | 5 301 | 37 / 48 |
| 6 | 5 | 500 iron-plate, 260 copper-plate, 260 stone-brick, 95 electronic-circuit, 1 820 fo-tungsten-plate, 1 620 plastic-bar | 7 588 | 1,2 | 4 940 | 0,65 | 4 940 | 48 / 56 |
| 7 | 6 | 540 iron-plate, 280 copper-plate, 280 stone-brick, 110 electronic-circuit, 670 battery, 1 230 fo-tungsten-plate | 7 800 | 1,03 | 6 470 | 0,83 | 948 | 30 / 64 |
| 8 | 7 | 590 iron-plate, 300 copper-plate, 300 stone-brick, 110 electronic-circuit, 1 260 fo-resonance-crystal, 460 battery | 8 075 | 1,04 | 5 486 | 0,68 | 710 | 42 / 72 |
| 9 | 8 | 640 iron-plate, 330 copper-plate, 330 stone-brick, 120 electronic-circuit, 380 fo-methane-barrel, 850 fo-resonance-crystal | 8 280 | 1,03 | 6 580 | 0,79 | 693 | 71 / 80 |
| 10 | 9 | 680 iron-plate, 350 copper-plate, 350 stone-brick, 130 electronic-circuit, 600 uranium-238, 560 fo-methane-barrel | 16 055 | 1,94 | 14 710 | 0,92 | 1 217 | 78 / 88 |
| 11 | 10 | 730 iron-plate, 380 copper-plate, 380 stone-brick, 140 electronic-circuit, 520 processing-unit, 1 860 uranium-238 | 67 260 | 4,19 | 47 666 | 0,71 | 39 | 42 / 96 |
| 12 | 11 | 780 iron-plate, 400 copper-plate, 400 stone-brick, 150 electronic-circuit, 1 990 fo-titanium-plate, 350 processing-unit | 68 405 | 1,02 | 69 873 | 1,02 | 99 | 41 / 104 |
| 13 | 12 | 820 iron-plate, 420 copper-plate, 420 stone-brick, 160 electronic-circuit, 1 000 fo-superconducting-coil, 2 000 fo-titanium-plate | 102 480 | 1,5 | 136 668 | 1,33 | 107 | 50 / 112 |
| 14 | 13 | 870 iron-plate, 450 copper-plate, 450 stone-brick, 170 electronic-circuit, 2 000 uranium-235, 1 000 fo-superconducting-coil | 152 645 | 1,49 | 154 009 | 1,01 | 16 | 50 / 120 |
| 15 | 14 | 910 iron-plate, 470 copper-plate, 470 stone-brick, 180 electronic-circuit, 760 rocket-control-unit, 1 690 uranium-235 | 192 820 | 1,26 | 139 222 | 0,72 | 7 | 114 / 128 |

### Mitrailleuse

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 6 iron-plate, 3 iron-gear-wheel, 3 copper-plate | 15 | — | 15 | 1 | 15 | 3 / 24 |
| 3 | 2 | 7 iron-plate, 3 iron-gear-wheel, 3 copper-plate, 3 steel-plate | 31 | 2,07 | 31 | 1 | 31 | 4 / 32 |
| 4 | 2 | 8 iron-plate, 4 iron-gear-wheel, 4 copper-plate, 4 steel-plate | 40 | 1,29 | 40 | 1 | 40 | 4 / 32 |
| 5 | 3 | 9 iron-plate, 4 iron-gear-wheel, 4 copper-plate, 2 engine-unit, 1 steel-plate | 44 | 1,1 | 44 | 1 | 44 | 5 / 40 |
| 6 | 3 | 10 iron-plate, 5 iron-gear-wheel, 5 copper-plate, 2 engine-unit, 2 steel-plate | 53 | 1,2 | 53 | 1 | 53 | 5 / 40 |
| 7 | 4 | 11 iron-plate, 5 iron-gear-wheel, 5 copper-plate, 25 plastic-bar, 3 engine-unit | 91 | 1,71 | 78 | 0,86 | 78 | 5 / 48 |
| 8 | 4 | 11 iron-plate, 6 iron-gear-wheel, 6 copper-plate, 30 plastic-bar, 3 engine-unit | 101 | 1,12 | 86 | 0,85 | 86 | 5 / 48 |
| 9 | 5 | 12 iron-plate, 6 iron-gear-wheel, 6 copper-plate, 55 fo-tungsten-plate, 50 plastic-bar | 215 | 2,13 | 134 | 0,63 | 134 | 5 / 56 |
| 10 | 5 | 13 iron-plate, 7 iron-gear-wheel, 7 copper-plate, 70 fo-tungsten-plate, 60 plastic-bar | 264 | 1,23 | 163 | 0,62 | 163 | 5 / 56 |
| 11 | 6 | 14 iron-plate, 7 iron-gear-wheel, 7 copper-plate, 40 battery, 70 fo-tungsten-plate | 395 | 1,5 | 319 | 0,81 | 43 | 5 / 64 |
| 12 | 6 | 15 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 50 battery, 90 fo-tungsten-plate | 494 | 1,25 | 397 | 0,8 | 53 | 5 / 64 |
| 13 | 7 | 16 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 140 fo-resonance-crystal, 50 battery | 735 | 1,49 | 448 | 0,61 | 53 | 7 / 72 |
| 14 | 7 | 17 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 170 fo-resonance-crystal, 65 battery | 909 | 1,24 | 559 | 0,62 | 65 | 8 / 72 |
| 15 | 8 | 18 iron-plate, 9 iron-gear-wheel, 9 copper-plate, 80 fo-methane-barrel, 180 fo-resonance-crystal | 1 385 | 1,52 | 1 025 | 0,74 | 99 | 15 / 80 |
| 16 | 8 | 19 iron-plate, 9 iron-gear-wheel, 9 copper-plate, 100 fo-methane-barrel, 220 fo-resonance-crystal | 1 706 | 1,23 | 1 266 | 0,74 | 122 | 18 / 80 |
| 17 | 9 | 20 iron-plate, 10 iron-gear-wheel, 10 copper-plate, 100 uranium-238, 100 fo-methane-barrel | 2 450 | 1,44 | 2 226 | 0,91 | 176 | 14 / 88 |
| 18 | 9 | 20 iron-plate, 10 iron-gear-wheel, 10 copper-plate, 130 uranium-238, 120 fo-methane-barrel | 3 070 | 1,25 | 2 779 | 0,91 | 220 | 17 / 88 |
| 19 | 10 | 20 iron-plate, 11 iron-gear-wheel, 11 copper-plate, 35 processing-unit, 130 uranium-238 | 4 498 | 1,47 | 3 168 | 0,7 | 2 | 6 / 96 |
| 20 | 10 | 20 iron-plate, 11 iron-gear-wheel, 11 copper-plate, 45 processing-unit, 160 uranium-238 | 5 668 | 1,26 | 3 975 | 0,7 | 3 | 6 / 96 |
| 21 | 11 | 25 iron-plate, 12 iron-gear-wheel, 12 copper-plate, 250 fo-titanium-plate, 45 processing-unit | 8 436 | 1,49 | 8 590 | 1,02 | 12 | 7 / 104 |
| 22 | 11 | 25 iron-plate, 12 iron-gear-wheel, 12 copper-plate, 310 fo-titanium-plate, 55 processing-unit | 10 386 | 1,23 | 10 601 | 1,02 | 15 | 8 / 104 |
| 23 | 12 | 25 iron-plate, 12 iron-gear-wheel, 12 copper-plate, 150 fo-superconducting-coil, 300 fo-titanium-plate | 15 061 | 1,45 | 20 189 | 1,34 | 15 | 8 / 112 |
| 24 | 12 | 25 iron-plate, 13 iron-gear-wheel, 13 copper-plate, 190 fo-superconducting-coil, 380 fo-titanium-plate | 19 064 | 1,27 | 25 560 | 1,34 | 19 | 9 / 112 |
| 25 | 13 | 25 iron-plate, 13 iron-gear-wheel, 13 copper-plate, 360 uranium-235, 180 fo-superconducting-coil | 27 064 | 1,42 | 27 310 | 1,01 | 2 | 9 / 120 |
| 26 | 13 | 30 iron-plate, 14 iron-gear-wheel, 14 copper-plate, 450 uranium-235, 230 fo-superconducting-coil | 34 122 | 1,26 | 34 540 | 1,01 | 2 | 11 / 120 |
| 27 | 14 | 30 iron-plate, 14 iron-gear-wheel, 14 copper-plate, 200 rocket-control-unit, 440 uranium-235 | 49 872 | 1,46 | 35 817 | 0,72 | 0 | 28 / 128 |
| 28 | 14 | 30 iron-plate, 15 iron-gear-wheel, 15 copper-plate, 250 rocket-control-unit, 550 uranium-235 | 62 325 | 1,25 | 44 756 | 0,72 | 0 | 34 / 128 |
| 29 | 15 | 30 iron-plate, 15 iron-gear-wheel, 15 copper-plate, 200 space-science-pack, 230 rocket-control-unit | 84 575 | 1,36 | 50 384 | 0,6 | 2 | 27 / 136 |
| 30 | 15 | 30 iron-plate, 16 iron-gear-wheel, 16 copper-plate, 250 space-science-pack, 280 rocket-control-unit | 104 578 | 1,24 | 62 194 | 0,59 | 2 | 32 / 136 |

### Laser

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 3 steel-plate, 3 electronic-circuit, 2 battery | 34 | — | 33 | 0,99 | 33 | 3 / 24 |
| 3 | 2 | 9 steel-plate, 3 electronic-circuit, 2 battery | 64 | 1,9 | 63 | 1 | 63 | 3 / 32 |
| 4 | 2 | 11 steel-plate, 4 electronic-circuit, 3 battery | 82 | 1,28 | 81 | 0,99 | 81 | 3 / 32 |
| 5 | 3 | 6 steel-plate, 4 electronic-circuit, 3 battery, 3 engine-unit | 84 | 1,02 | 83 | 0,99 | 83 | 4 / 40 |
| 6 | 3 | 8 steel-plate, 5 electronic-circuit, 3 battery, 2 engine-unit | 87 | 1,04 | 87 | 0,99 | 87 | 4 / 40 |
| 7 | 4 | 5 steel-plate, 5 electronic-circuit, 4 battery, 40 plastic-bar, 5 engine-unit | 165 | 1,89 | 143 | 0,87 | 143 | 5 / 48 |
| 8 | 4 | 6 steel-plate, 6 electronic-circuit, 4 battery, 50 plastic-bar, 6 engine-unit | 196 | 1,19 | 170 | 0,87 | 170 | 5 / 48 |
| 9 | 5 | 6 steel-plate, 6 electronic-circuit, 4 battery, 95 fo-tungsten-plate, 85 plastic-bar | 385 | 1,96 | 245 | 0,64 | 245 | 5 / 56 |
| 10 | 5 | 7 steel-plate, 7 electronic-circuit, 4 battery, 120 fo-tungsten-plate, 100 plastic-bar | 465 | 1,21 | 293 | 0,63 | 293 | 6 / 56 |
| 11 | 6 | 7 steel-plate, 7 electronic-circuit, 70 battery, 120 fo-tungsten-plate | 678 | 1,46 | 547 | 0,81 | 73 | 5 / 64 |
| 12 | 6 | 8 steel-plate, 8 electronic-circuit, 85 battery, 150 fo-tungsten-plate | 828 | 1,22 | 665 | 0,8 | 88 | 5 / 64 |
| 13 | 7 | 8 steel-plate, 8 electronic-circuit, 90 battery, 230 fo-resonance-crystal | 1 245 | 1,5 | 772 | 0,62 | 90 | 8 / 72 |
| 14 | 7 | 8 steel-plate, 8 electronic-circuit, 106 battery, 290 fo-resonance-crystal | 1 513 | 1,22 | 917 | 0,61 | 108 | 9 / 72 |
| 15 | 8 | 9 steel-plate, 9 electronic-circuit, 6 battery, 130 fo-methane-barrel, 290 fo-resonance-crystal | 2 271 | 1,5 | 1 690 | 0,74 | 162 | 22 / 80 |
| 16 | 8 | 9 steel-plate, 9 electronic-circuit, 6 battery, 170 fo-methane-barrel, 370 fo-resonance-crystal | 2 911 | 1,28 | 2 170 | 0,75 | 207 | 28 / 80 |
| 17 | 9 | 10 steel-plate, 10 electronic-circuit, 7 battery, 170 uranium-238, 160 fo-methane-barrel | 4 094 | 1,41 | 3 711 | 0,91 | 293 | 21 / 88 |
| 18 | 9 | 10 steel-plate, 10 electronic-circuit, 7 battery, 220 uranium-238, 200 fo-methane-barrel | 5 194 | 1,27 | 4 699 | 0,9 | 372 | 26 / 88 |
| 19 | 10 | 11 steel-plate, 11 electronic-circuit, 7 battery, 60 processing-unit, 210 uranium-238 | 7 561 | 1,46 | 5 309 | 0,7 | 4 | 7 / 96 |
| 20 | 10 | 11 steel-plate, 11 electronic-circuit, 7 battery, 75 processing-unit, 260 uranium-238 | 9 386 | 1,24 | 6 577 | 0,7 | 5 | 7 / 96 |
| 21 | 11 | 12 steel-plate, 12 electronic-circuit, 8 battery, 410 fo-titanium-plate, 75 processing-unit | 13 959 | 1,49 | 14 175 | 1,02 | 19 | 9 / 104 |
| 22 | 11 | 12 steel-plate, 12 electronic-circuit, 8 battery, 520 fo-titanium-plate, 90 processing-unit | 17 284 | 1,24 | 17 710 | 1,02 | 24 | 10 / 104 |
| 23 | 12 | 12 steel-plate, 12 electronic-circuit, 8 battery, 250 fo-superconducting-coil, 500 fo-titanium-plate | 25 134 | 1,45 | 33 680 | 1,34 | 25 | 11 / 112 |
| 24 | 12 | 13 steel-plate, 13 electronic-circuit, 9 battery, 310 fo-superconducting-coil, 630 fo-titanium-plate | 31 347 | 1,25 | 42 003 | 1,34 | 32 | 14 / 112 |
| 25 | 13 | 13 steel-plate, 13 electronic-circuit, 9 battery, 600 uranium-235, 300 fo-superconducting-coil | 45 147 | 1,44 | 45 555 | 1,01 | 3 | 12 / 120 |
| 26 | 13 | 14 steel-plate, 14 electronic-circuit, 9 battery, 750 uranium-235, 380 fo-superconducting-coil | 56 705 | 1,26 | 57 326 | 1,01 | 4 | 15 / 120 |
| 27 | 14 | 14 steel-plate, 14 electronic-circuit, 10 battery, 330 rocket-control-unit, 740 uranium-235 | 82 960 | 1,46 | 59 621 | 0,72 | 0 | 44 / 128 |
| 28 | 14 | 15 steel-plate, 15 electronic-circuit, 10 battery, 410 rocket-control-unit, 920 uranium-235 | 103 068 | 1,24 | 74 065 | 0,72 | 0 | 54 / 128 |
| 29 | 15 | 15 steel-plate, 15 electronic-circuit, 10 battery, 340 space-science-pack, 380 rocket-control-unit | 142 168 | 1,38 | 84 562 | 0,59 | 3 | 42 / 136 |
| 30 | 15 | 16 steel-plate, 16 electronic-circuit, 10 battery, 420 space-science-pack, 470 rocket-control-unit | 175 675 | 1,24 | 104 488 | 0,59 | 4 | 51 / 136 |

### Mur

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 3 stone-brick | 6 | — | 6 | 1 | 6 | 1 / 24 |
| 3 | 2 | 3 stone-brick, 1 steel-plate | 11 | 1,83 | 11 | 1 | 11 | 2 / 32 |
| 4 | 2 | 4 stone-brick, 1 steel-plate | 13 | 1,18 | 13 | 1 | 13 | 2 / 32 |
| 5 | 3 | 4 stone-brick, 1 engine-unit | 17 | 1,31 | 17 | 1 | 17 | 2 / 40 |
| 6 | 3 | 5 stone-brick, 1 engine-unit | 19 | 1,12 | 19 | 1 | 19 | 2 / 40 |
| 7 | 4 | 5 stone-brick, 7 plastic-bar | 21 | 1,08 | 17 | 0,83 | 17 | 2 / 48 |
| 8 | 4 | 6 stone-brick, 9 plastic-bar | 26 | 1,24 | 21 | 0,82 | 21 | 2 / 48 |
| 9 | 5 | 6 stone-brick, 16 fo-tungsten-plate | 44 | 1,73 | 28 | 0,64 | 28 | 2 / 56 |
| 10 | 5 | 7 stone-brick, 19 fo-tungsten-plate | 52 | 1,18 | 33 | 0,63 | 33 | 2 / 56 |
| 11 | 6 | 7 stone-brick, 11 battery | 75 | 1,43 | 73 | 0,98 | 9 | 2 / 64 |
| 12 | 6 | 8 stone-brick, 13 battery | 88 | 1,17 | 86 | 0,98 | 11 | 2 / 64 |
| 13 | 7 | 8 stone-brick, 40 fo-resonance-crystal | 136 | 1,55 | 56 | 0,41 | 10 | 2 / 72 |
| 14 | 7 | 8 stone-brick, 50 fo-resonance-crystal | 166 | 1,22 | 66 | 0,4 | 12 | 2 / 72 |
| 15 | 8 | 9 stone-brick, 20 fo-methane-barrel | 218 | 1,31 | 218 | 1 | 20 | 3 / 80 |
| 16 | 8 | 9 stone-brick, 30 fo-methane-barrel | 318 | 1,46 | 318 | 1 | 28 | 4 / 80 |
| 17 | 9 | 10 stone-brick, 30 uranium-238 | 440 | 1,38 | 373 | 0,85 | 33 | 2 / 88 |
| 18 | 9 | 10 stone-brick, 35 uranium-238 | 510 | 1,16 | 432 | 0,85 | 39 | 2 / 88 |
| 19 | 10 | 11 stone-brick, 10 processing-unit | 772 | 1,51 | 475 | 0,62 | 0 | 2 / 96 |
| 20 | 10 | 11 stone-brick, 12 processing-unit | 922 | 1,19 | 566 | 0,61 | 0 | 2 / 96 |
| 21 | 11 | 12 stone-brick, 70 fo-titanium-plate | 1 424 | 1,54 | 1 841 | 1,29 | 3 | 2 / 104 |
| 22 | 11 | 12 stone-brick, 85 fo-titanium-plate | 1 724 | 1,21 | 2 230 | 1,29 | 4 | 2 / 104 |
| 23 | 12 | 12 stone-brick, 40 fo-superconducting-coil | 2 424 | 1,41 | 3 315 | 1,37 | 0 | 2 / 112 |
| 24 | 12 | 13 stone-brick, 50 fo-superconducting-coil | 3 026 | 1,25 | 4 140 | 1,37 | 0 | 2 / 112 |
| 25 | 13 | 13 stone-brick, 100 uranium-235 | 4 526 | 1,5 | 3 480 | 0,77 | 0 | 2 / 120 |
| 26 | 13 | 14 stone-brick, 130 uranium-235 | 5 878 | 1,3 | 4 519 | 0,77 | 0 | 3 / 120 |
| 27 | 14 | 14 stone-brick, 55 rocket-control-unit | 8 278 | 1,41 | 5 678 | 0,69 | 0 | 7 / 128 |
| 28 | 14 | 15 stone-brick, 70 rocket-control-unit | 10 530 | 1,27 | 7 221 | 0,69 | 0 | 8 / 128 |
| 29 | 15 | 15 stone-brick, 55 space-science-pack | 13 780 | 1,31 | 7 367 | 0,53 | 1 | 2 / 136 |
| 30 | 15 | 16 stone-brick, 70 space-science-pack | 17 532 | 1,27 | 9 371 | 0,53 | 1 | 2 / 136 |

### Foreuse

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 6 iron-plate, 3 iron-gear-wheel, 2 electronic-circuit | 17 | — | 17 | 1 | 17 | 3 / 24 |
| 3 | 2 | 7 iron-plate, 3 iron-gear-wheel, 2 electronic-circuit, 2 steel-plate | 28 | 1,65 | 28 | 1 | 28 | 4 / 32 |
| 4 | 2 | 8 iron-plate, 4 iron-gear-wheel, 3 electronic-circuit, 3 steel-plate | 39 | 1,38 | 39 | 1 | 39 | 4 / 32 |
| 5 | 3 | 9 iron-plate, 4 iron-gear-wheel, 3 electronic-circuit, 2 engine-unit, 1 steel-plate | 48 | 1,23 | 48 | 1 | 48 | 5 / 40 |
| 6 | 3 | 10 iron-plate, 5 iron-gear-wheel, 3 electronic-circuit, 2 engine-unit, 1 steel-plate | 51 | 1,06 | 51 | 1 | 51 | 5 / 40 |
| 7 | 4 | 11 iron-plate, 5 iron-gear-wheel, 4 electronic-circuit, 14 plastic-bar, 2 engine-unit | 70 | 1,39 | 63 | 0,9 | 63 | 5 / 48 |
| 8 | 4 | 11 iron-plate, 6 iron-gear-wheel, 4 electronic-circuit, 18 plastic-bar, 2 engine-unit | 78 | 1,11 | 69 | 0,88 | 69 | 5 / 48 |
| 9 | 5 | 12 iron-plate, 6 iron-gear-wheel, 4 electronic-circuit, 35 fo-tungsten-plate, 30 plastic-bar | 149 | 1,91 | 99 | 0,66 | 99 | 5 / 56 |
| 10 | 5 | 13 iron-plate, 7 iron-gear-wheel, 4 electronic-circuit, 40 fo-tungsten-plate, 35 plastic-bar | 170 | 1,14 | 112 | 0,66 | 112 | 5 / 56 |
| 11 | 6 | 14 iron-plate, 7 iron-gear-wheel, 5 electronic-circuit, 25 battery, 40 fo-tungsten-plate | 258 | 1,52 | 214 | 0,83 | 27 | 5 / 64 |
| 12 | 6 | 15 iron-plate, 8 iron-gear-wheel, 5 electronic-circuit, 30 battery, 50 fo-tungsten-plate | 309 | 1,2 | 254 | 0,82 | 32 | 5 / 64 |
| 13 | 7 | 16 iron-plate, 8 iron-gear-wheel, 5 electronic-circuit, 80 fo-resonance-crystal, 30 battery | 450 | 1,46 | 285 | 0,63 | 32 | 6 / 72 |
| 14 | 7 | 17 iron-plate, 8 iron-gear-wheel, 6 electronic-circuit, 100 fo-resonance-crystal, 35 battery | 541 | 1,2 | 335 | 0,62 | 38 | 6 / 72 |
| 15 | 8 | 18 iron-plate, 9 iron-gear-wheel, 6 electronic-circuit, 45 fo-methane-barrel, 100 fo-resonance-crystal | 801 | 1,48 | 601 | 0,75 | 56 | 10 / 80 |
| 16 | 8 | 19 iron-plate, 9 iron-gear-wheel, 6 electronic-circuit, 60 fo-methane-barrel, 130 fo-resonance-crystal | 1 042 | 1,3 | 782 | 0,75 | 73 | 12 / 80 |
| 17 | 9 | 20 iron-plate, 10 iron-gear-wheel, 7 electronic-circuit, 60 uranium-238, 55 fo-methane-barrel | 1 448 | 1,39 | 1 313 | 0,91 | 102 | 10 / 88 |
| 18 | 9 | 20 iron-plate, 10 iron-gear-wheel, 7 electronic-circuit, 75 uranium-238, 70 fo-methane-barrel | 1 808 | 1,25 | 1 639 | 0,91 | 128 | 11 / 88 |
| 19 | 10 | 20 iron-plate, 11 iron-gear-wheel, 7 electronic-circuit, 20 processing-unit, 75 uranium-238 | 2 610 | 1,44 | 1 848 | 0,71 | 1 | 5 / 96 |
| 20 | 10 | 20 iron-plate, 11 iron-gear-wheel, 7 electronic-circuit, 25 processing-unit, 90 uranium-238 | 3 195 | 1,22 | 2 251 | 0,7 | 2 | 5 / 96 |
| 21 | 11 | 25 iron-plate, 12 iron-gear-wheel, 8 electronic-circuit, 140 fo-titanium-plate, 25 processing-unit | 4 744 | 1,49 | 4 836 | 1,02 | 7 | 6 / 104 |
| 22 | 11 | 25 iron-plate, 12 iron-gear-wheel, 8 electronic-circuit, 180 fo-titanium-plate, 30 processing-unit | 5 919 | 1,25 | 6 101 | 1,03 | 8 | 6 / 104 |
| 23 | 12 | 25 iron-plate, 12 iron-gear-wheel, 8 electronic-circuit, 90 fo-superconducting-coil, 180 fo-titanium-plate | 9 069 | 1,53 | 12 146 | 1,34 | 9 | 6 / 112 |
| 24 | 12 | 25 iron-plate, 13 iron-gear-wheel, 9 electronic-circuit, 110 fo-superconducting-coil, 220 fo-titanium-plate | 11 074 | 1,22 | 14 834 | 1,34 | 11 | 8 / 112 |
| 25 | 13 | 25 iron-plate, 13 iron-gear-wheel, 9 electronic-circuit, 210 uranium-235, 110 fo-superconducting-coil | 16 124 | 1,46 | 16 378 | 1,02 | 1 | 8 / 120 |
| 26 | 13 | 30 iron-plate, 14 iron-gear-wheel, 9 electronic-circuit, 260 uranium-235, 130 fo-superconducting-coil | 19 581 | 1,21 | 19 758 | 1,01 | 1 | 8 / 120 |
| 27 | 14 | 30 iron-plate, 14 iron-gear-wheel, 10 electronic-circuit, 120 rocket-control-unit, 260 uranium-235 | 29 783 | 1,52 | 21 392 | 0,72 | 0 | 18 / 128 |
| 28 | 14 | 30 iron-plate, 15 iron-gear-wheel, 10 electronic-circuit, 140 rocket-control-unit, 320 uranium-235 | 35 485 | 1,19 | 25 521 | 0,72 | 0 | 21 / 128 |
| 29 | 15 | 30 iron-plate, 15 iron-gear-wheel, 10 electronic-circuit, 120 space-science-pack, 130 rocket-control-unit | 49 585 | 1,4 | 29 449 | 0,59 | 1 | 17 / 136 |
| 30 | 15 | 30 iron-plate, 16 iron-gear-wheel, 10 electronic-circuit, 150 space-science-pack, 160 rocket-control-unit | 61 587 | 1,24 | 36 535 | 0,59 | 1 | 20 / 136 |

### Four

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 2 steel-plate, 3 stone-brick | 16 | — | 16 | 1 | 16 | 2 / 24 |
| 3 | 2 | 4 steel-plate, 3 stone-brick | 26 | 1,62 | 26 | 1 | 26 | 2 / 32 |
| 4 | 2 | 5 steel-plate, 4 stone-brick | 33 | 1,27 | 33 | 1 | 33 | 2 / 32 |
| 5 | 3 | 4 steel-plate, 4 stone-brick, 1 engine-unit | 37 | 1,12 | 37 | 1 | 37 | 3 / 40 |
| 6 | 3 | 4 steel-plate, 5 stone-brick, 1 engine-unit | 39 | 1,05 | 39 | 1 | 39 | 3 / 40 |
| 7 | 4 | 4 steel-plate, 5 stone-brick, 12 plastic-bar, 1 engine-unit | 57 | 1,46 | 51 | 0,89 | 51 | 4 / 48 |
| 8 | 4 | 4 steel-plate, 6 stone-brick, 15 plastic-bar, 2 engine-unit | 73 | 1,27 | 65 | 0,89 | 65 | 4 / 48 |
| 9 | 5 | 4 steel-plate, 6 stone-brick, 30 fo-tungsten-plate, 25 plastic-bar | 130 | 1,79 | 87 | 0,67 | 87 | 4 / 56 |
| 10 | 5 | 4 steel-plate, 7 stone-brick, 35 fo-tungsten-plate, 30 plastic-bar | 149 | 1,15 | 99 | 0,66 | 99 | 4 / 56 |
| 11 | 6 | 5 steel-plate, 7 stone-brick, 19 battery, 35 fo-tungsten-plate | 214 | 1,43 | 176 | 0,82 | 26 | 4 / 64 |
| 12 | 6 | 5 steel-plate, 8 stone-brick, 25 battery, 45 fo-tungsten-plate | 269 | 1,26 | 220 | 0,82 | 32 | 4 / 64 |
| 13 | 7 | 5 steel-plate, 8 stone-brick, 70 fo-resonance-crystal, 25 battery | 389 | 1,45 | 245 | 0,63 | 31 | 5 / 72 |
| 14 | 7 | 6 steel-plate, 8 stone-brick, 85 fo-resonance-crystal, 30 battery | 466 | 1,2 | 292 | 0,63 | 37 | 5 / 72 |
| 15 | 8 | 6 steel-plate, 9 stone-brick, 40 fo-methane-barrel, 90 fo-resonance-crystal | 718 | 1,54 | 538 | 0,75 | 54 | 8 / 80 |
| 16 | 8 | 6 steel-plate, 9 stone-brick, 50 fo-methane-barrel, 110 fo-resonance-crystal | 878 | 1,22 | 658 | 0,75 | 65 | 10 / 80 |
| 17 | 9 | 7 steel-plate, 10 stone-brick, 50 uranium-238, 50 fo-methane-barrel | 1 255 | 1,43 | 1 143 | 0,91 | 92 | 8 / 88 |
| 18 | 9 | 7 steel-plate, 10 stone-brick, 65 uranium-238, 60 fo-methane-barrel | 1 565 | 1,25 | 1 419 | 0,91 | 115 | 9 / 88 |
| 19 | 10 | 7 steel-plate, 11 stone-brick, 18 processing-unit, 65 uranium-238 | 2 317 | 1,48 | 1 637 | 0,71 | 1 | 4 / 96 |
| 20 | 10 | 7 steel-plate, 11 stone-brick, 20 processing-unit, 80 uranium-238 | 2 677 | 1,16 | 1 904 | 0,71 | 2 | 4 / 96 |
| 21 | 11 | 8 steel-plate, 12 stone-brick, 120 fo-titanium-plate, 20 processing-unit | 3 964 | 1,48 | 4 085 | 1,03 | 6 | 5 / 104 |
| 22 | 11 | 8 steel-plate, 12 stone-brick, 150 fo-titanium-plate, 25 processing-unit | 4 939 | 1,25 | 5 091 | 1,03 | 7 | 5 / 104 |
| 23 | 12 | 8 steel-plate, 12 stone-brick, 75 fo-superconducting-coil, 150 fo-titanium-plate | 7 564 | 1,53 | 10 128 | 1,34 | 8 | 5 / 112 |
| 24 | 12 | 9 steel-plate, 13 stone-brick, 95 fo-superconducting-coil, 190 fo-titanium-plate | 9 571 | 1,27 | 12 819 | 1,34 | 10 | 5 / 112 |
| 25 | 13 | 9 steel-plate, 13 stone-brick, 180 uranium-235, 90 fo-superconducting-coil | 13 571 | 1,42 | 13 694 | 1,01 | 1 | 5 / 120 |
| 26 | 13 | 9 steel-plate, 14 stone-brick, 230 uranium-235, 110 fo-superconducting-coil | 17 023 | 1,25 | 17 068 | 1 | 1 | 7 / 120 |
| 27 | 14 | 10 steel-plate, 14 stone-brick, 100 rocket-control-unit, 220 uranium-235 | 24 978 | 1,47 | 17 950 | 0,72 | 0 | 15 / 128 |
| 28 | 14 | 10 steel-plate, 15 stone-brick, 120 rocket-control-unit, 280 uranium-235 | 30 680 | 1,23 | 22 080 | 0,72 | 0 | 17 / 128 |
| 29 | 15 | 10 steel-plate, 15 stone-brick, 100 space-science-pack, 110 rocket-control-unit | 41 580 | 1,36 | 24 721 | 0,59 | 1 | 14 / 136 |
| 30 | 15 | 10 steel-plate, 16 stone-brick, 130 space-science-pack, 140 rocket-control-unit | 53 582 | 1,29 | 31 807 | 0,59 | 1 | 17 / 136 |

### Assembleur

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 6 iron-plate, 3 iron-gear-wheel, 3 electronic-circuit | 20 | — | 20 | 1 | 20 | 3 / 24 |
| 3 | 2 | 7 iron-plate, 3 iron-gear-wheel, 3 electronic-circuit, 2 steel-plate | 31 | 1,56 | 31 | 1 | 31 | 4 / 32 |
| 4 | 2 | 8 iron-plate, 4 iron-gear-wheel, 4 electronic-circuit, 3 steel-plate | 41 | 1,34 | 41 | 1 | 41 | 4 / 32 |
| 5 | 3 | 9 iron-plate, 4 iron-gear-wheel, 4 electronic-circuit, 2 engine-unit, 1 steel-plate | 50 | 1,22 | 50 | 1 | 50 | 5 / 40 |
| 6 | 3 | 10 iron-plate, 5 iron-gear-wheel, 5 electronic-circuit, 2 engine-unit, 1 steel-plate | 56 | 1,11 | 56 | 1 | 56 | 5 / 40 |
| 7 | 4 | 11 iron-plate, 5 iron-gear-wheel, 5 electronic-circuit, 14 plastic-bar, 2 engine-unit | 73 | 1,31 | 65 | 0,9 | 65 | 5 / 48 |
| 8 | 4 | 11 iron-plate, 6 iron-gear-wheel, 6 electronic-circuit, 18 plastic-bar, 2 engine-unit | 83 | 1,14 | 74 | 0,89 | 74 | 5 / 48 |
| 9 | 5 | 12 iron-plate, 6 iron-gear-wheel, 6 electronic-circuit, 35 fo-tungsten-plate, 30 plastic-bar | 154 | 1,86 | 104 | 0,67 | 104 | 5 / 56 |
| 10 | 5 | 13 iron-plate, 7 iron-gear-wheel, 7 electronic-circuit, 40 fo-tungsten-plate, 35 plastic-bar | 177 | 1,15 | 119 | 0,67 | 119 | 5 / 56 |
| 11 | 6 | 14 iron-plate, 7 iron-gear-wheel, 7 electronic-circuit, 25 battery, 40 fo-tungsten-plate | 263 | 1,49 | 219 | 0,83 | 27 | 5 / 64 |
| 12 | 6 | 15 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 30 battery, 50 fo-tungsten-plate | 316 | 1,2 | 262 | 0,83 | 32 | 5 / 64 |
| 13 | 7 | 16 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 80 fo-resonance-crystal, 30 battery | 457 | 1,45 | 293 | 0,64 | 32 | 6 / 72 |
| 14 | 7 | 17 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 100 fo-resonance-crystal, 35 battery | 546 | 1,19 | 340 | 0,62 | 38 | 6 / 72 |
| 15 | 8 | 18 iron-plate, 9 iron-gear-wheel, 9 electronic-circuit, 45 fo-methane-barrel, 100 fo-resonance-crystal | 809 | 1,48 | 609 | 0,75 | 56 | 10 / 80 |
| 16 | 8 | 19 iron-plate, 9 iron-gear-wheel, 9 electronic-circuit, 60 fo-methane-barrel, 130 fo-resonance-crystal | 1 050 | 1,3 | 790 | 0,75 | 74 | 12 / 80 |
| 17 | 9 | 20 iron-plate, 10 iron-gear-wheel, 10 electronic-circuit, 60 uranium-238, 55 fo-methane-barrel | 1 455 | 1,39 | 1 320 | 0,91 | 102 | 10 / 88 |
| 18 | 9 | 20 iron-plate, 10 iron-gear-wheel, 10 electronic-circuit, 75 uranium-238, 70 fo-methane-barrel | 1 815 | 1,25 | 1 647 | 0,91 | 128 | 11 / 88 |
| 19 | 10 | 20 iron-plate, 11 iron-gear-wheel, 11 electronic-circuit, 20 processing-unit, 75 uranium-238 | 2 620 | 1,44 | 1 858 | 0,71 | 1 | 5 / 96 |
| 20 | 10 | 20 iron-plate, 11 iron-gear-wheel, 11 electronic-circuit, 25 processing-unit, 90 uranium-238 | 3 205 | 1,22 | 2 261 | 0,71 | 2 | 5 / 96 |
| 21 | 11 | 25 iron-plate, 12 iron-gear-wheel, 12 electronic-circuit, 140 fo-titanium-plate, 25 processing-unit | 4 754 | 1,48 | 4 846 | 1,02 | 7 | 6 / 104 |
| 22 | 11 | 25 iron-plate, 12 iron-gear-wheel, 12 electronic-circuit, 180 fo-titanium-plate, 30 processing-unit | 5 929 | 1,25 | 6 111 | 1,03 | 8 | 6 / 104 |
| 23 | 12 | 25 iron-plate, 12 iron-gear-wheel, 12 electronic-circuit, 90 fo-superconducting-coil, 180 fo-titanium-plate | 9 079 | 1,53 | 12 156 | 1,34 | 9 | 6 / 112 |
| 24 | 12 | 25 iron-plate, 13 iron-gear-wheel, 13 electronic-circuit, 110 fo-superconducting-coil, 220 fo-titanium-plate | 11 084 | 1,22 | 14 844 | 1,34 | 11 | 8 / 112 |
| 25 | 13 | 25 iron-plate, 13 iron-gear-wheel, 13 electronic-circuit, 210 uranium-235, 110 fo-superconducting-coil | 16 134 | 1,46 | 16 388 | 1,02 | 1 | 8 / 120 |
| 26 | 13 | 30 iron-plate, 14 iron-gear-wheel, 14 electronic-circuit, 260 uranium-235, 130 fo-superconducting-coil | 19 593 | 1,21 | 19 770 | 1,01 | 1 | 8 / 120 |
| 27 | 14 | 30 iron-plate, 14 iron-gear-wheel, 14 electronic-circuit, 120 rocket-control-unit, 260 uranium-235 | 29 793 | 1,52 | 21 402 | 0,72 | 0 | 18 / 128 |
| 28 | 14 | 30 iron-plate, 15 iron-gear-wheel, 15 electronic-circuit, 140 rocket-control-unit, 320 uranium-235 | 35 498 | 1,19 | 25 533 | 0,72 | 0 | 21 / 128 |
| 29 | 15 | 30 iron-plate, 15 iron-gear-wheel, 15 electronic-circuit, 120 space-science-pack, 130 rocket-control-unit | 49 598 | 1,4 | 29 461 | 0,59 | 1 | 17 / 136 |
| 30 | 15 | 30 iron-plate, 16 iron-gear-wheel, 16 electronic-circuit, 150 space-science-pack, 160 rocket-control-unit | 61 602 | 1,24 | 36 550 | 0,59 | 1 | 20 / 136 |

## 6. Calendrier : durée impliquée par époque selon l'hypothèse de modules

Même modèle que `levels_test --tables` (base de référence `L.target.base`, 30 % de la production X0 aux niveaux) ; seule la valeur des
coûts change : déclarée, puis matière brute réelle sous H0, H2r, H2.

| Époque | Durée X0 | Dépense déclarée (u) | Impliquée (déclarée) | Dépense réelle H0 | Impliquée H0 | Dépense réelle H2r | Impliquée H2r | Dépense réelle H2 | Impliquée H2 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 0 h 30 | 1 222 | 0 h 30 | 1 222 | 0 h 30 | 1 222 | 0 h 30 | 1 222 | 0 h 30 |
| 2 | 1 h 00 | 4 464 | 1 h 00 | 4 464 | 1 h 00 | 4 464 | 1 h 00 | 4 464 | 1 h 00 |
| 3 | 1 h 30 | 12 202 | 1 h 30 | 12 202 | 1 h 30 | 12 202 | 1 h 30 | 12 202 | 1 h 30 |
| 4 | 2 h 00 | 29 762 | 2 h 00 | 26 535 | 1 h 47 | 26 535 | 1 h 47 | 26 535 | 1 h 47 |
| 5 | 2 h 30 | 68 411 | 2 h 31 | 48 256 | 1 h 46 | 48 256 | 1 h 46 | 48 256 | 1 h 46 |
| 6 | 3 h 00 | 151 135 | 3 h 02 | 127 619 | 2 h 34 | 78 141 | 1 h 34 | 17 024 | 0 h 21 |
| 7 | 3 h 30 | 317 988 | 3 h 30 | 197 046 | 2 h 10 | 135 319 | 1 h 29 | 24 338 | 0 h 16 |
| 8 | 4 h 00 | 671 786 | 4 h 03 | 530 036 | 3 h 11 | 335 672 | 2 h 01 | 49 877 | 0 h 18 |
| 9 | 4 h 30 | 1 363 375 | 4 h 29 | 1 189 901 | 3 h 55 | 808 482 | 2 h 40 | 95 910 | 0 h 19 |
| 10 | 5 h 00 | 2 782 296 | 5 h 00 | 1 958 372 | 3 h 32 | 517 404 | 0 h 56 | 1 557 | 0 h 00 |
| 11 | 5 h 30 | 5 582 967 | 5 h 30 | 5 815 159 | 5 h 43 | 2 803 058 | 2 h 46 | 8 525 | 0 h 01 |
| 12 | 6 h 00 | 11 217 290 | 6 h 02 | 14 553 141 | 7 h 50 | 3 274 054 | 1 h 46 | 9 958 | 0 h 00 |
| 13 | 6 h 30 | 22 062 090 | 6 h 30 | 21 534 358 | 6 h 20 | 1 174 026 | 0 h 21 | 3 564 | 0 h 00 |
| 14 | 7 h 00 | 43 390 660 | 6 h 59 | 32 217 121 | 5 h 11 | 637 155 | 0 h 06 | 1 937 | 0 h 00 |
| 15 | 7 h 00 | 79 273 298 | 6 h 59 | 48 447 203 | 4 h 16 | 1 221 090 | 0 h 06 | 3 714 | 0 h 00 |
| **Total** | **59 h 30** | | **59 h 36** | | **51 h 17** | | **20 h 19** | | **7 h 49** |

## 7. Recherche par époque (coûts FINAUX de l'étape data)

Époque d'une technologie : règle QX9 de la config (`L.vanilla_tech_epoch`), relevée au maximum de ses prérequis. Packs valorisés en MU réelle H0.

| Époque | Technologies | Unités | Temps de labo (labo-heures, vitesse 1) | Packs (MU) | Budget X0 de l'époque (u) | Packs / budget | Visée X0 : 35 % |
|---|---|---|---|---|---|---|---|
| 1 | 5 | 216 | 1,6 | 648 | 4 054 | 16 % | dans la fourchette |
| 2 | 16 | 259 | 1,7 | 2 093 | 14 826 | 14,1 % | dans la fourchette |
| 3 | 17 | 226 | 2,5 | 5 057 | 40 662 | 12,4 % | dans la fourchette |
| 4 | 46 | 463 | 4,2 | 14 150 | 99 130 | 14,3 % | dans la fourchette |
| 5 | 5 | 1 490 | 12,4 | 78 825 | 226 561 | 34,8 % | dans la fourchette |
| 6 | 41 | 1 174 | 10,3 | 122 646 | 497 094 | 24,7 % | dans la fourchette |
| 7 | 2 | 800 | 9,6 | 53 542 | 1 060 369 | 5 % | **écart** |
| 8 | 7 | 533 | 4,5 | 55 813 | 2 215 750 | 2,5 % | **écart** |
| 9 | 5 | 1 300 | 10,8 | 59 300 | 4 557 694 | 1,3 % | **écart** |
| 10 | 81 | 19 316 | 254,5 | 3 002 261 | 9 259 223 | 32,4 % | dans la fourchette |
| 11 | 0 | 0 | 0 | 0 | 18 622 549 | 0 % | **écart** |
| 12 | 1 | 1 500 | 25 | 297 855 | 37 144 935 | 0,8 % | **écart** |
| 13 | 2 | 2 700 | 22,5 | 518 153 | 73 575 568 | 0,7 % | **écart** |
| 14 | 17 | 226 200 | 3753,3 | 69 151 123 | 144 873 923 | 47,7 % | dans la fourchette |
| 15 | 0 | 0 | 0 | 0 | 264 887 907 | 0 % | **écart** |

## 8. Proposition de courbe des 15 époques (NON appliquée : à trancher par le Directeur Créatif, Q-CALC-1)

Trois voies, chiffrées sur le même modèle :

- **(A) Suivre la productivité réelle** : multiplier la valeur d'époque par le gain H2 des monnaies de l'époque, pour que la durée
  impliquée sous H2 retombe sur le calendrier X0 (coûts affichés × le gain).
- **(B) Garder les coûts** : la partie raccourcit sous H2 (colonne « Impliquée H2 » du §6).
- **(C) Exclure les monnaies d'époque de la productivité** (limitation des modules) : la durée revient vers H0 ; la productivité ne sert
  plus qu'à l'usine (recherche, munitions, paniers de base).

| Époque | value_mult actuel | cc_value actuel | Rapport réel H0 / déclaré | Gain H2 (dépense) | value_mult (A) | cc_value (A) | Valeur de monnaie proposée (MU réelle arrondie) |
|---|---|---|---|---|---|---|---|
| 1 | 0 | 0 | 1 | × 1 | 0,1 | 0 | — |
| 2 | 1,43 | 407 | 1 | × 1 | 1,4 | 410 | 5 |
| 3 | 1,46 | 1 050 | 1 | × 1 | 1,5 | 1 050 | 9 |
| 4 | 5,1 | 4 980 | 0,89 | × 1 | 5,1 | 4 980 | 1 |
| 5 | 15,5 | 6 060 | 0,71 | × 1 | 15,5 | 6 060 | 1 |
| 6 | 29,5 | 6 160 | 0,84 | × 7,5 | 220 | 46 200 | 5,4 |
| 7 | 57,7 | 6 290 | 0,62 | × 8,1 | 470 | 50 900 | 1 |
| 8 | 110 | 6 380 | 0,79 | × 10,63 | 1 170 | 67 800 | 10 |
| 9 | 204 | 14 100 | 0,87 | × 12,41 | 2 530 | 174 900 | 11,8 |
| 10 | 365 | 65 000 | 0,7 | × 1257,69 | 459 100 | 8,2 × 10^7 | 45 |
| 11 | 687 | 66 300 | 1,04 | × 682,17 | 468 600 | 4,5 × 10^7 | 25 |
| 12 | 1250 | 100 000 | 1,3 | × 1461,52 | 1 826 900 | 1,5 × 10^8 | 80 |
| 13 | 2260 | 150 000 | 0,98 | × 6042,96 | 1,4 × 10^7 | 9,1 × 10^8 | 35 |
| 14 | 4140 | 190 000 | 0,74 | × 1,7 × 10^4 | 6,9 × 10^7 | 3,2 × 10^9 | 100 |
| 15 | 7070 | 0 | 0,61 | × 1,3 × 10^4 | 9,2 × 10^7 | 0 | 130 |

Lecture : sous H2, l'époque e est payée « Gain H2 » fois plus vite qu'en H0 ; (A) remet chaque époque à sa durée X0 en multipliant
valeur d'époque et passage du centre par ce gain (les quantités affichées grandissent d'autant : la règle de place du coffre est alors
à revérifier, `levels_test`). La dernière colonne aligne la valeur déclarée des monnaies sur leur coût réel (règle du modèle : « valeur
de l'objet en unités de matière brute ») ; elle ne change ni `value_mult` ni le calendrier, seulement les QUANTITÉS demandées.
