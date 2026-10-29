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

## 1. Incohérences relevées (12)

| Gravité | Constat |
|---|---|
| FAUX | Époque 4 : `plastic-bar` déclarée 3 u, matière brute réelle 1,53 (rapport 1,97, hors de 0,67 à 1,5). |
| FAUX | Époque 5 : `fo-tungsten-plate` déclarée 4 u, matière brute réelle 2 (rapport 2, hors de 0,67 à 1,5). |
| FAUX | Époque 6 : `battery` déclarée 9 u, matière brute réelle 5,48 (rapport 1,64, hors de 0,67 à 1,5). |
| BIAIS | Époque 7 : `fo-resonance-crystal` déclarée 3 u, matière brute réelle 1 (rapport 3, hors de 0,67 à 1,5) ; rareté assumée par X0 (gisements rares, valeur de monnaie au-dessus du minerai). |
| NOTE | Détour : dès l'époque 10, la chaîne la moins chère de `plastic-bar` sous H2 abandonne `crude-oil` (brut principal de H0) : coal-liquefaction, gisement:coal, heavy-oil-cracking, light-oil-cracking, plastic-bar. |
| NOTE | Détour : dès l'époque 10, la chaîne la moins chère de `battery` sous H2 abandonne `crude-oil` (brut principal de H0) : battery, coal-liquefaction, copper-plate, gisement:coal, gisement:copper-ore, gisement:iron-ore, heavy-oil-cracking, iron-plate, light-oil-cracking, sulfur, sulfuric-acid. |
| BIAIS | command : le niveau 5 coûte × 3,23 du niveau 4 (2 285 → 7 383 u). |
| BIAIS | command : le niveau 11 coûte × 3,26 du niveau 10 (16 055 → 52 380 u). |
| NOTE | assembler niveau 20 (époque 10) : 24 modules de productivité palier 5 dépassent le plafond × 328,67 du moteur (cases perdues). |
| NOTE | drill niveau 20 (époque 10) : 24 modules de productivité palier 5 dépassent le plafond × 328,67 du moteur (cases perdues). |
| NOTE | Recettes d'assembleur qui dépasseraient 60 fabrications/s (le moteur bride) avec la machine de l'époque pleine de modules de vitesse : époque 6 : 14 ; époque 7 : 70 ; époque 8 : 79 ; époque 9 : 80 ; époque 10 : 174 ; époque 11 : 174 ; époque 12 : 174 ; époque 13 : 177 ; époque 14 : 177 ; époque 15 : 177. |
| NOTE | Bruts sans gisement ni recette (comptés 1 MU) : wood. |

## 2. Monnaies d'époque : valeur déclarée contre matière brute réelle

| Époque | Objet en jeu | Valeur déclarée (u) | MU réelle H0 | Déclarée / réelle | MU réelle H2 (modules de l'époque) | Gain H2 | Monnaie X0 (papier) | Valeur X0 |
|---|---|---|---|---|---|---|---|---|
| 2 | `steel-plate` | 5 | 5 | 1 | 5 | × 1 | même | 5 |
| 3 | `engine-unit` | 9 | 9 | 1 | 9 | × 1 | même | 9 |
| 4 | `plastic-bar` | 3 | 1,53 | 1,97 | 1,53 | × 1 | même | 3 |
| 5 | `fo-tungsten-plate` | 4 | 2 | 2 | 2 | × 1 | même | 4 |
| 6 | `battery` | 9 | 5,48 | 1,64 | 0,56 | × 9,86 | même | 9 |
| 7 | `fo-resonance-crystal` | 3 | 1 | 3 | 0,18 | × 5,56 | même | 3 |
| 8 | `fo-methane-barrel` | 10 | 10 | 1 | 0,85 | × 11,72 | `fo-biopolymer` (absent du jeu) | 4 |
| 9 | `uranium-238` | 14 | 11,82 | 1,18 | 1,03 | × 11,46 | même | 14 |
| 10 | `processing-unit` | 75 | 70,97 | 1,06 | 1,3 × 10^-6 | × 5,4 × 10^7 | même | 75 |
| 11 | `fo-titanium-plate` | 20 | 25,95 | 0,77 | 0,05 | × 555,45 | même | 20 |
| 12 | `electric-engine-unit` (provisoire) | 16 | 16,31 | 0,98 | 3,9 × 10^-6 | × 4,2 × 10^6 | `fo-superconducting-coil` (absent du jeu) | 60 |
| 13 | `uranium-235` (provisoire) | 45 | 34,73 | 1,3 | 1 × 10^-3 | × 3,5 × 10^4 | `fo-plasma-cell` (absent du jeu) | 25 |
| 14 | `rocket-control-unit` (provisoire) | 150 | 133,73 | 1,12 | 1,9 × 10^-7 | × 7,2 × 10^8 | `fo-superalloy` (absent du jeu) | 45 |
| 15 | `space-science-pack` (provisoire) | 250 | 199,96 | 1,25 | 0,01 | × 1,8 × 10^4 | `fo-stabilized-exotic-matter` (absent du jeu) | 1500 |

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
| 2 | `steel-plate` | 20,6 | 121 | 20,6 | 121 | 20,6 | 121 | — | 7,69 fo-lvl-drill-4, 12,9 fo-lvl-furnace-4 |
| 3 | `engine-unit` | 39 | 271 | 39 | 271 | 39 | 271 | — | 10,95 fo-lvl-assembler-6, 12 fo-lvl-drill-6, 16 fo-lvl-furnace-6 |
| 4 | `plastic-bar` | 2,2 | 32 | 2,2 | 32 | 2,2 | 32 | crude-oil 10,3 | 1,06 chemical-plant, 0,59 fo-lvl-drill-8, 0,51 oil-refinery |
| 5 | `fo-tungsten-plate` | 6,1 | 84 | 6,1 | 84 | 6,1 | 84 | — | 4,21 fo-lvl-drill-10, 1,86 fo-lvl-furnace-10 |
| 6 | `battery` | 13 | 157 | 7,2 | 79 | 7 | 73 | crude-oil 30,8 | 7,09 chemical-plant, 2,29 fo-lvl-drill-12, 2,04 fo-lvl-furnace-12, 1,54 oil-refinery |
| 7 | `fo-resonance-crystal` | 1,3 | 33 | 0 | 1 | 0,3 | 8 | — | 1,3 fo-lvl-drill-14 |
| 8 | `fo-methane-barrel` | 12 | 235 | 7,4 | 119 | 1,5 | 27 | fo-methane 50 | 0,73 fo-lvl-assembler-16, 4 fo-lvl-drill-16, 7,27 fo-lvl-furnace-16 |
| 9 | `uranium-238` | 29,6 | 521 | 10,1 | 104 | 12,9 | 155 | crude-oil 15,5 | 12,08 centrifuge, 1,56 chemical-plant, 15,07 fo-lvl-drill-18, 0,14 fo-lvl-furnace-18, 0,77 oil-refinery |
| 10 | `processing-unit` | 122,3 | 3793 | 42,7 | 1051 | 0,1 | 3 | crude-oil 48,7 | 5,03 chemical-plant, 28,57 fo-lvl-assembler-20, 45,59 fo-lvl-drill-20, 40,7 fo-lvl-furnace-20, 2,44 oil-refinery |
| 11 | `fo-titanium-plate` | 45,6 | 1053 | 10,6 | 98 | 13,3 | 129 | fo-brine 54,5 | 5 chemical-plant, 0,77 fo-arc-furnace, 6 fo-coke-oven, 9,27 fo-electrolyzer, 0,5 fo-kroll-reactor, 23,55 fo-lvl-drill-22, 0,53 fo-ore-concentrator |
| 12 | `electric-engine-unit` | 34,5 | 1071 | 11,4 | 280 | 0,1 | 3 | — | 1,5 chemical-plant, 11,27 fo-lvl-assembler-24, 9,88 fo-lvl-drill-24, 10,7 fo-lvl-furnace-24, 1,15 oil-refinery |
| 13 | `uranium-235` | 135,6 | 2187 | 38,9 | 370 | 2,8 | 26 | crude-oil 45,5 | 94,26 centrifuge, 4,57 chemical-plant, 34,15 fo-lvl-drill-26, 0,32 fo-lvl-furnace-26, 2,28 oil-refinery |
| 14 | `rocket-control-unit` | 208,3 | 6993 | 59,4 | 2084 | 0,2 | 8 | crude-oil 151,3 | 15,67 chemical-plant, 64,45 fo-lvl-assembler-28, 64,11 fo-lvl-drill-28, 56,51 fo-lvl-furnace-28, 7,56 oil-refinery |
| 15 | `space-science-pack` | 315,5 | 10037 | 90,2 | 3102 | 4,7 | 152 | crude-oil 306,9 | 43,22 chemical-plant, 86,58 fo-lvl-assembler-30, 86,81 fo-lvl-drill-30, 83,29 fo-lvl-furnace-30, 15,35 oil-refinery, 0,3 rocket-silo |

## 5. Coût de chaque niveau : valeur déclarée, matière brute réelle H0 et H2

Valeur déclarée : `L.cost_value` (ce que compte le calendrier). Réelle : quantités × MU réelle de chaque objet, à l'époque où l'on paie.

### Centre

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 310 iron-plate, 160 copper-plate, 160 stone-brick, 60 electronic-circuit | 940 | — | 940 | 1 | 940 | 9 / 24 |
| 3 | 2 | 360 iron-plate, 180 copper-plate, 180 stone-brick, 70 electronic-circuit, 80 steel-plate | 1 475 | 1,57 | 1 475 | 1 | 1 475 | 10 / 32 |
| 4 | 3 | 400 iron-plate, 210 copper-plate, 210 stone-brick, 80 electronic-circuit, 70 engine-unit, 85 steel-plate | 2 285 | 1,55 | 2 285 | 1 | 2 285 | 14 / 40 |
| 5 | 4 | 450 iron-plate, 230 copper-plate, 230 stone-brick, 85 electronic-circuit, 1 200 plastic-bar, 270 engine-unit | 7 383 | 3,23 | 5 613 | 0,76 | 5 613 | 30 / 48 |
| 6 | 5 | 500 iron-plate, 260 copper-plate, 260 stone-brick, 95 electronic-circuit, 910 fo-tungsten-plate, 810 plastic-bar | 7 588 | 1,03 | 4 573 | 0,6 | 4 573 | 31 / 56 |
| 7 | 6 | 540 iron-plate, 280 copper-plate, 280 stone-brick, 110 electronic-circuit, 410 battery, 620 fo-tungsten-plate | 7 825 | 1,03 | 5 141 | 0,66 | 805 | 23 / 64 |
| 8 | 7 | 590 iron-plate, 300 copper-plate, 300 stone-brick, 110 electronic-circuit, 1 260 fo-resonance-crystal, 280 battery | 8 065 | 1,03 | 4 559 | 0,57 | 628 | 41 / 72 |
| 9 | 8 | 640 iron-plate, 330 copper-plate, 330 stone-brick, 120 electronic-circuit, 380 fo-methane-barrel, 850 fo-resonance-crystal | 8 280 | 1,03 | 6 580 | 0,79 | 696 | 71 / 80 |
| 10 | 9 | 680 iron-plate, 350 copper-plate, 350 stone-brick, 130 electronic-circuit, 600 uranium-238, 560 fo-methane-barrel | 16 055 | 1,94 | 14 748 | 0,92 | 1 220 | 78 / 88 |
| 11 | 10 | 730 iron-plate, 380 copper-plate, 380 stone-brick, 140 electronic-circuit, 400 processing-unit, 1 440 uranium-238 | 52 380 | 3,26 | 47 631 | 0,91 | 32 | 36 / 96 |
| 12 | 11 | 780 iron-plate, 400 copper-plate, 400 stone-brick, 150 electronic-circuit, 1 550 fo-titanium-plate, 280 processing-unit | 54 355 | 1,04 | 62 457 | 1,15 | 78 | 36 / 104 |
| 13 | 12 | 820 iron-plate, 420 copper-plate, 420 stone-brick, 160 electronic-circuit, 2 000 electric-engine-unit, 1 070 fo-titanium-plate | 55 880 | 1,03 | 62 867 | 1,13 | 56 | 71 / 112 |
| 14 | 13 | 870 iron-plate, 450 copper-plate, 450 stone-brick, 170 electronic-circuit, 1 070 uranium-235, 2 000 electric-engine-unit | 82 795 | 1,48 | 72 421 | 0,87 | 8 | 71 / 120 |
| 15 | 14 | 910 iron-plate, 470 copper-plate, 470 stone-brick, 180 electronic-circuit, 760 rocket-control-unit, 1 690 uranium-235 | 192 820 | 2,33 | 163 096 | 0,85 | 7 | 114 / 128 |

### Mitrailleuse

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 6 iron-plate, 3 iron-gear-wheel, 3 copper-plate | 15 | — | 15 | 1 | 15 | 3 / 24 |
| 3 | 2 | 7 iron-plate, 3 iron-gear-wheel, 3 copper-plate, 3 steel-plate | 31 | 2,07 | 31 | 1 | 31 | 4 / 32 |
| 4 | 2 | 8 iron-plate, 4 iron-gear-wheel, 4 copper-plate, 4 steel-plate | 40 | 1,29 | 40 | 1 | 40 | 4 / 32 |
| 5 | 3 | 9 iron-plate, 4 iron-gear-wheel, 4 copper-plate, 2 engine-unit, 1 steel-plate | 44 | 1,1 | 44 | 1 | 44 | 5 / 40 |
| 6 | 3 | 10 iron-plate, 5 iron-gear-wheel, 5 copper-plate, 2 engine-unit, 2 steel-plate | 53 | 1,2 | 53 | 1 | 53 | 5 / 40 |
| 7 | 4 | 11 iron-plate, 5 iron-gear-wheel, 5 copper-plate, 11 plastic-bar, 2 engine-unit | 77 | 1,45 | 61 | 0,79 | 61 | 5 / 48 |
| 8 | 4 | 11 iron-plate, 6 iron-gear-wheel, 6 copper-plate, 14 plastic-bar, 3 engine-unit | 98 | 1,27 | 77 | 0,79 | 77 | 5 / 48 |
| 9 | 5 | 12 iron-plate, 6 iron-gear-wheel, 6 copper-plate, 30 fo-tungsten-plate, 25 plastic-bar | 225 | 2,3 | 128 | 0,57 | 128 | 5 / 56 |
| 10 | 5 | 13 iron-plate, 7 iron-gear-wheel, 7 copper-plate, 35 fo-tungsten-plate, 30 plastic-bar | 264 | 1,17 | 150 | 0,57 | 150 | 5 / 56 |
| 11 | 6 | 14 iron-plate, 7 iron-gear-wheel, 7 copper-plate, 25 battery, 35 fo-tungsten-plate | 400 | 1,52 | 242 | 0,6 | 34 | 5 / 64 |
| 12 | 6 | 15 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 30 battery, 45 fo-tungsten-plate | 489 | 1,22 | 293 | 0,6 | 42 | 5 / 64 |
| 13 | 7 | 16 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 140 fo-resonance-crystal, 30 battery | 730 | 1,49 | 344 | 0,47 | 44 | 7 / 72 |
| 14 | 7 | 17 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 170 fo-resonance-crystal, 40 battery | 911 | 1,25 | 430 | 0,47 | 54 | 8 / 72 |
| 15 | 8 | 18 iron-plate, 9 iron-gear-wheel, 9 copper-plate, 80 fo-methane-barrel, 180 fo-resonance-crystal | 1 385 | 1,52 | 1 025 | 0,74 | 99 | 15 / 80 |
| 16 | 8 | 19 iron-plate, 9 iron-gear-wheel, 9 copper-plate, 100 fo-methane-barrel, 220 fo-resonance-crystal | 1 706 | 1,23 | 1 266 | 0,74 | 123 | 18 / 80 |
| 17 | 9 | 20 iron-plate, 10 iron-gear-wheel, 10 copper-plate, 100 uranium-238, 100 fo-methane-barrel | 2 450 | 1,44 | 2 232 | 0,91 | 176 | 14 / 88 |
| 18 | 9 | 20 iron-plate, 10 iron-gear-wheel, 10 copper-plate, 130 uranium-238, 120 fo-methane-barrel | 3 070 | 1,25 | 2 787 | 0,91 | 221 | 17 / 88 |
| 19 | 10 | 20 iron-plate, 11 iron-gear-wheel, 11 copper-plate, 35 processing-unit, 130 uranium-238 | 4 498 | 1,47 | 4 074 | 0,91 | 2 | 6 / 96 |
| 20 | 10 | 20 iron-plate, 11 iron-gear-wheel, 11 copper-plate, 45 processing-unit, 160 uranium-238 | 5 668 | 1,26 | 5 138 | 0,91 | 3 | 6 / 96 |
| 21 | 11 | 25 iron-plate, 12 iron-gear-wheel, 12 copper-plate, 250 fo-titanium-plate, 45 processing-unit | 8 436 | 1,49 | 9 743 | 1,15 | 12 | 7 / 104 |
| 22 | 11 | 25 iron-plate, 12 iron-gear-wheel, 12 copper-plate, 310 fo-titanium-plate, 55 processing-unit | 10 386 | 1,23 | 12 010 | 1,16 | 15 | 8 / 104 |
| 23 | 12 | 25 iron-plate, 12 iron-gear-wheel, 12 copper-plate, 560 electric-engine-unit, 300 fo-titanium-plate | 15 021 | 1,45 | 16 980 | 1,13 | 14 | 18 / 112 |
| 24 | 12 | 25 iron-plate, 13 iron-gear-wheel, 13 copper-plate, 700 electric-engine-unit, 370 fo-titanium-plate | 18 664 | 1,24 | 21 083 | 1,13 | 17 | 21 / 112 |
| 25 | 13 | 25 iron-plate, 13 iron-gear-wheel, 13 copper-plate, 360 uranium-235, 680 electric-engine-unit | 27 144 | 1,45 | 23 656 | 0,87 | 0 | 21 / 120 |
| 26 | 13 | 30 iron-plate, 14 iron-gear-wheel, 14 copper-plate, 450 uranium-235, 850 electric-engine-unit | 33 922 | 1,25 | 29 562 | 0,87 | 1 | 25 / 120 |
| 27 | 14 | 30 iron-plate, 14 iron-gear-wheel, 14 copper-plate, 200 rocket-control-unit, 440 uranium-235 | 49 872 | 1,47 | 42 098 | 0,84 | 0 | 28 / 128 |
| 28 | 14 | 30 iron-plate, 15 iron-gear-wheel, 15 copper-plate, 250 rocket-control-unit, 550 uranium-235 | 62 325 | 1,25 | 52 608 | 0,84 | 0 | 34 / 128 |
| 29 | 15 | 30 iron-plate, 15 iron-gear-wheel, 15 copper-plate, 200 space-science-pack, 230 rocket-control-unit | 84 575 | 1,36 | 70 825 | 0,84 | 2 | 27 / 136 |
| 30 | 15 | 30 iron-plate, 16 iron-gear-wheel, 16 copper-plate, 250 space-science-pack, 280 rocket-control-unit | 104 578 | 1,24 | 87 513 | 0,84 | 3 | 32 / 136 |

### Laser

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 3 steel-plate, 3 electronic-circuit, 2 battery | 41 | — | 33 | 0,83 | 33 | 3 / 24 |
| 3 | 2 | 9 steel-plate, 3 electronic-circuit, 2 battery | 71 | 1,74 | 63 | 0,9 | 63 | 3 / 32 |
| 4 | 2 | 11 steel-plate, 4 electronic-circuit, 3 battery | 92 | 1,3 | 81 | 0,89 | 81 | 3 / 32 |
| 5 | 3 | 6 steel-plate, 4 electronic-circuit, 3 battery, 3 engine-unit | 94 | 1,02 | 83 | 0,89 | 83 | 4 / 40 |
| 6 | 3 | 8 steel-plate, 5 electronic-circuit, 3 battery, 2 engine-unit | 98 | 1,04 | 87 | 0,89 | 87 | 4 / 40 |
| 7 | 4 | 5 steel-plate, 5 electronic-circuit, 4 battery, 18 plastic-bar, 4 engine-unit | 164 | 1,68 | 123 | 0,75 | 123 | 5 / 48 |
| 8 | 4 | 6 steel-plate, 6 electronic-circuit, 4 battery, 25 plastic-bar, 5 engine-unit | 201 | 1,23 | 150 | 0,75 | 150 | 5 / 48 |
| 9 | 5 | 6 steel-plate, 6 electronic-circuit, 4 battery, 45 fo-tungsten-plate, 40 plastic-bar | 381 | 1,9 | 218 | 0,57 | 218 | 5 / 56 |
| 10 | 5 | 7 steel-plate, 7 electronic-circuit, 4 battery, 60 fo-tungsten-plate, 50 plastic-bar | 479 | 1,26 | 271 | 0,57 | 271 | 5 / 56 |
| 11 | 6 | 7 steel-plate, 7 electronic-circuit, 45 battery, 60 fo-tungsten-plate | 698 | 1,46 | 419 | 0,6 | 59 | 4 / 64 |
| 12 | 6 | 8 steel-plate, 8 electronic-circuit, 55 battery, 75 fo-tungsten-plate | 855 | 1,23 | 511 | 0,6 | 72 | 4 / 64 |
| 13 | 7 | 8 steel-plate, 8 electronic-circuit, 55 battery, 230 fo-resonance-crystal | 1 245 | 1,46 | 591 | 0,47 | 74 | 8 / 72 |
| 14 | 7 | 8 steel-plate, 8 electronic-circuit, 71 battery, 290 fo-resonance-crystal | 1 569 | 1,26 | 739 | 0,47 | 92 | 9 / 72 |
| 15 | 8 | 9 steel-plate, 9 electronic-circuit, 6 battery, 130 fo-methane-barrel, 290 fo-resonance-crystal | 2 292 | 1,46 | 1 690 | 0,74 | 163 | 22 / 80 |
| 16 | 8 | 9 steel-plate, 9 electronic-circuit, 6 battery, 170 fo-methane-barrel, 370 fo-resonance-crystal | 2 932 | 1,28 | 2 170 | 0,74 | 209 | 28 / 80 |
| 17 | 9 | 10 steel-plate, 10 electronic-circuit, 7 battery, 170 uranium-238, 160 fo-methane-barrel | 4 118 | 1,4 | 3 723 | 0,9 | 294 | 21 / 88 |
| 18 | 9 | 10 steel-plate, 10 electronic-circuit, 7 battery, 220 uranium-238, 200 fo-methane-barrel | 5 218 | 1,27 | 4 714 | 0,9 | 373 | 26 / 88 |
| 19 | 10 | 11 steel-plate, 11 electronic-circuit, 7 battery, 60 processing-unit, 210 uranium-238 | 7 586 | 1,45 | 6 862 | 0,9 | 4 | 7 / 96 |
| 20 | 10 | 11 steel-plate, 11 electronic-circuit, 7 battery, 75 processing-unit, 260 uranium-238 | 9 411 | 1,24 | 8 517 | 0,91 | 5 | 7 / 96 |
| 21 | 11 | 12 steel-plate, 12 electronic-circuit, 8 battery, 410 fo-titanium-plate, 75 processing-unit | 13 987 | 1,49 | 16 098 | 1,15 | 19 | 9 / 104 |
| 22 | 11 | 12 steel-plate, 12 electronic-circuit, 8 battery, 520 fo-titanium-plate, 90 processing-unit | 17 312 | 1,24 | 20 018 | 1,16 | 25 | 10 / 104 |
| 23 | 12 | 12 steel-plate, 12 electronic-circuit, 8 battery, 930 electric-engine-unit, 500 fo-titanium-plate | 25 042 | 1,45 | 28 277 | 1,13 | 24 | 27 / 112 |
| 24 | 12 | 13 steel-plate, 13 electronic-circuit, 9 battery, 1 160 electric-engine-unit, 620 fo-titanium-plate | 31 139 | 1,24 | 35 156 | 1,13 | 29 | 34 / 112 |
| 25 | 13 | 13 steel-plate, 13 electronic-circuit, 9 battery, 610 uranium-235, 1 140 electric-engine-unit | 45 869 | 1,47 | 39 922 | 0,87 | 1 | 33 / 120 |
| 26 | 13 | 14 steel-plate, 14 electronic-circuit, 9 battery, 760 uranium-235, 1 420 electric-engine-unit | 57 106 | 1,24 | 49 705 | 0,87 | 1 | 40 / 120 |
| 27 | 14 | 14 steel-plate, 14 electronic-circuit, 10 battery, 330 rocket-control-unit, 740 uranium-235 | 82 995 | 1,45 | 69 990 | 0,84 | 0 | 44 / 128 |
| 28 | 14 | 15 steel-plate, 15 electronic-circuit, 10 battery, 410 rocket-control-unit, 920 uranium-235 | 103 103 | 1,24 | 86 947 | 0,84 | 0 | 54 / 128 |
| 29 | 15 | 15 steel-plate, 15 electronic-circuit, 10 battery, 340 space-science-pack, 380 rocket-control-unit | 142 203 | 1,38 | 118 972 | 0,84 | 4 | 42 / 136 |
| 30 | 15 | 16 steel-plate, 16 electronic-circuit, 10 battery, 420 space-science-pack, 470 rocket-control-unit | 175 710 | 1,24 | 147 012 | 0,84 | 5 | 51 / 136 |

### Mur

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 3 stone-brick | 6 | — | 6 | 1 | 6 | 1 / 24 |
| 3 | 2 | 3 stone-brick, 1 steel-plate | 11 | 1,83 | 11 | 1 | 11 | 2 / 32 |
| 4 | 2 | 4 stone-brick, 1 steel-plate | 13 | 1,18 | 13 | 1 | 13 | 2 / 32 |
| 5 | 3 | 4 stone-brick, 1 engine-unit | 17 | 1,31 | 17 | 1 | 17 | 2 / 40 |
| 6 | 3 | 5 stone-brick, 1 engine-unit | 19 | 1,12 | 19 | 1 | 19 | 2 / 40 |
| 7 | 4 | 5 stone-brick, 4 plastic-bar | 22 | 1,16 | 16 | 0,73 | 16 | 2 / 48 |
| 8 | 4 | 6 stone-brick, 4 plastic-bar | 24 | 1,09 | 18 | 0,75 | 18 | 2 / 48 |
| 9 | 5 | 6 stone-brick, 8 fo-tungsten-plate | 44 | 1,83 | 28 | 0,64 | 28 | 2 / 56 |
| 10 | 5 | 7 stone-brick, 10 fo-tungsten-plate | 54 | 1,23 | 34 | 0,63 | 34 | 2 / 56 |
| 11 | 6 | 7 stone-brick, 6 battery | 68 | 1,26 | 47 | 0,69 | 6 | 2 / 64 |
| 12 | 6 | 8 stone-brick, 8 battery | 88 | 1,29 | 60 | 0,68 | 8 | 2 / 64 |
| 13 | 7 | 8 stone-brick, 40 fo-resonance-crystal | 136 | 1,55 | 56 | 0,41 | 10 | 2 / 72 |
| 14 | 7 | 8 stone-brick, 50 fo-resonance-crystal | 166 | 1,22 | 66 | 0,4 | 12 | 2 / 72 |
| 15 | 8 | 9 stone-brick, 20 fo-methane-barrel | 218 | 1,31 | 218 | 1 | 20 | 3 / 80 |
| 16 | 8 | 9 stone-brick, 30 fo-methane-barrel | 318 | 1,46 | 318 | 1 | 28 | 4 / 80 |
| 17 | 9 | 10 stone-brick, 30 uranium-238 | 440 | 1,38 | 375 | 0,85 | 33 | 2 / 88 |
| 18 | 9 | 10 stone-brick, 35 uranium-238 | 510 | 1,16 | 434 | 0,85 | 39 | 2 / 88 |
| 19 | 10 | 11 stone-brick, 10 processing-unit | 772 | 1,51 | 732 | 0,95 | 0 | 2 / 96 |
| 20 | 10 | 11 stone-brick, 12 processing-unit | 922 | 1,19 | 874 | 0,95 | 0 | 2 / 96 |
| 21 | 11 | 12 stone-brick, 70 fo-titanium-plate | 1 424 | 1,54 | 1 841 | 1,29 | 3 | 2 / 104 |
| 22 | 11 | 12 stone-brick, 85 fo-titanium-plate | 1 724 | 1,21 | 2 230 | 1,29 | 4 | 2 / 104 |
| 23 | 12 | 12 stone-brick, 160 electric-engine-unit | 2 584 | 1,5 | 2 633 | 1,02 | 0 | 5 / 112 |
| 24 | 12 | 13 stone-brick, 190 electric-engine-unit | 3 066 | 1,19 | 3 124 | 1,02 | 0 | 5 / 112 |
| 25 | 13 | 13 stone-brick, 100 uranium-235 | 4 526 | 1,48 | 3 499 | 0,77 | 0 | 2 / 120 |
| 26 | 13 | 14 stone-brick, 130 uranium-235 | 5 878 | 1,3 | 4 543 | 0,77 | 0 | 3 / 120 |
| 27 | 14 | 14 stone-brick, 55 rocket-control-unit | 8 278 | 1,41 | 7 383 | 0,89 | 0 | 7 / 128 |
| 28 | 14 | 15 stone-brick, 70 rocket-control-unit | 10 530 | 1,27 | 9 391 | 0,89 | 0 | 8 / 128 |
| 29 | 15 | 15 stone-brick, 55 space-science-pack | 13 780 | 1,31 | 11 028 | 0,8 | 1 | 2 / 136 |
| 30 | 15 | 16 stone-brick, 70 space-science-pack | 17 532 | 1,27 | 14 030 | 0,8 | 1 | 2 / 136 |

### Foreuse

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 6 iron-plate, 3 iron-gear-wheel, 2 electronic-circuit | 17 | — | 17 | 1 | 17 | 3 / 24 |
| 3 | 2 | 7 iron-plate, 3 iron-gear-wheel, 2 electronic-circuit, 2 steel-plate | 28 | 1,65 | 28 | 1 | 28 | 4 / 32 |
| 4 | 2 | 8 iron-plate, 4 iron-gear-wheel, 3 electronic-circuit, 3 steel-plate | 39 | 1,38 | 39 | 1 | 39 | 4 / 32 |
| 5 | 3 | 9 iron-plate, 4 iron-gear-wheel, 3 electronic-circuit, 2 engine-unit, 1 steel-plate | 48 | 1,23 | 48 | 1 | 48 | 5 / 40 |
| 6 | 3 | 10 iron-plate, 5 iron-gear-wheel, 3 electronic-circuit, 2 engine-unit, 1 steel-plate | 51 | 1,06 | 51 | 1 | 51 | 5 / 40 |
| 7 | 4 | 11 iron-plate, 5 iron-gear-wheel, 4 electronic-circuit, 6 plastic-bar, 1 engine-unit | 58 | 1,15 | 49 | 0,85 | 49 | 5 / 48 |
| 8 | 4 | 11 iron-plate, 6 iron-gear-wheel, 4 electronic-circuit, 8 plastic-bar, 2 engine-unit | 75 | 1,29 | 63 | 0,84 | 63 | 5 / 48 |
| 9 | 5 | 12 iron-plate, 6 iron-gear-wheel, 4 electronic-circuit, 16 fo-tungsten-plate, 14 plastic-bar | 140 | 1,87 | 87 | 0,62 | 87 | 5 / 56 |
| 10 | 5 | 13 iron-plate, 7 iron-gear-wheel, 4 electronic-circuit, 20 fo-tungsten-plate, 18 plastic-bar | 171 | 1,22 | 104 | 0,61 | 104 | 5 / 56 |
| 11 | 6 | 14 iron-plate, 7 iron-gear-wheel, 5 electronic-circuit, 14 battery, 20 fo-tungsten-plate | 247 | 1,44 | 157 | 0,64 | 21 | 5 / 64 |
| 12 | 6 | 15 iron-plate, 8 iron-gear-wheel, 5 electronic-circuit, 17 battery, 25 fo-tungsten-plate | 297 | 1,2 | 187 | 0,63 | 25 | 5 / 64 |
| 13 | 7 | 16 iron-plate, 8 iron-gear-wheel, 5 electronic-circuit, 80 fo-resonance-crystal, 18 battery | 447 | 1,51 | 223 | 0,5 | 26 | 6 / 72 |
| 14 | 7 | 17 iron-plate, 8 iron-gear-wheel, 6 electronic-circuit, 100 fo-resonance-crystal, 25 battery | 573 | 1,28 | 285 | 0,5 | 33 | 6 / 72 |
| 15 | 8 | 18 iron-plate, 9 iron-gear-wheel, 6 electronic-circuit, 45 fo-methane-barrel, 100 fo-resonance-crystal | 801 | 1,4 | 601 | 0,75 | 56 | 10 / 80 |
| 16 | 8 | 19 iron-plate, 9 iron-gear-wheel, 6 electronic-circuit, 60 fo-methane-barrel, 130 fo-resonance-crystal | 1 042 | 1,3 | 782 | 0,75 | 74 | 12 / 80 |
| 17 | 9 | 20 iron-plate, 10 iron-gear-wheel, 7 electronic-circuit, 60 uranium-238, 55 fo-methane-barrel | 1 448 | 1,39 | 1 317 | 0,91 | 103 | 10 / 88 |
| 18 | 9 | 20 iron-plate, 10 iron-gear-wheel, 7 electronic-circuit, 75 uranium-238, 70 fo-methane-barrel | 1 808 | 1,25 | 1 644 | 0,91 | 129 | 11 / 88 |
| 19 | 10 | 20 iron-plate, 11 iron-gear-wheel, 7 electronic-circuit, 20 processing-unit, 75 uranium-238 | 2 610 | 1,44 | 2 366 | 0,91 | 1 | 5 / 96 |
| 20 | 10 | 20 iron-plate, 11 iron-gear-wheel, 7 electronic-circuit, 25 processing-unit, 95 uranium-238 | 3 265 | 1,25 | 2 957 | 0,91 | 2 | 5 / 96 |
| 21 | 11 | 25 iron-plate, 12 iron-gear-wheel, 8 electronic-circuit, 140 fo-titanium-plate, 25 processing-unit | 4 744 | 1,45 | 5 477 | 1,15 | 7 | 6 / 104 |
| 22 | 11 | 25 iron-plate, 12 iron-gear-wheel, 8 electronic-circuit, 180 fo-titanium-plate, 30 processing-unit | 5 919 | 1,25 | 6 870 | 1,16 | 8 | 6 / 104 |
| 23 | 12 | 25 iron-plate, 12 iron-gear-wheel, 8 electronic-circuit, 330 electric-engine-unit, 170 fo-titanium-plate | 8 749 | 1,48 | 9 863 | 1,13 | 8 | 12 / 112 |
| 24 | 12 | 25 iron-plate, 13 iron-gear-wheel, 9 electronic-circuit, 410 electric-engine-unit, 220 fo-titanium-plate | 11 034 | 1,26 | 12 470 | 1,13 | 10 | 15 / 112 |
| 25 | 13 | 25 iron-plate, 13 iron-gear-wheel, 9 electronic-circuit, 210 uranium-235, 400 electric-engine-unit | 15 924 | 1,44 | 13 890 | 0,87 | 0 | 14 / 120 |
| 26 | 13 | 30 iron-plate, 14 iron-gear-wheel, 9 electronic-circuit, 260 uranium-235, 500 electric-engine-unit | 19 781 | 1,24 | 17 264 | 0,87 | 0 | 16 / 120 |
| 27 | 14 | 30 iron-plate, 14 iron-gear-wheel, 10 electronic-circuit, 120 rocket-control-unit, 260 uranium-235 | 29 783 | 1,51 | 25 160 | 0,84 | 0 | 18 / 128 |
| 28 | 14 | 30 iron-plate, 15 iron-gear-wheel, 10 electronic-circuit, 140 rocket-control-unit, 320 uranium-235 | 35 485 | 1,19 | 29 920 | 0,84 | 0 | 21 / 128 |
| 29 | 15 | 30 iron-plate, 15 iron-gear-wheel, 10 electronic-circuit, 120 space-science-pack, 130 rocket-control-unit | 49 585 | 1,4 | 41 465 | 0,84 | 1 | 17 / 136 |
| 30 | 15 | 30 iron-plate, 16 iron-gear-wheel, 10 electronic-circuit, 150 space-science-pack, 160 rocket-control-unit | 61 587 | 1,24 | 51 478 | 0,84 | 2 | 20 / 136 |

### Four

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 2 steel-plate, 3 stone-brick | 16 | — | 16 | 1 | 16 | 2 / 24 |
| 3 | 2 | 4 steel-plate, 3 stone-brick | 26 | 1,62 | 26 | 1 | 26 | 2 / 32 |
| 4 | 2 | 5 steel-plate, 4 stone-brick | 33 | 1,27 | 33 | 1 | 33 | 2 / 32 |
| 5 | 3 | 4 steel-plate, 4 stone-brick, 1 engine-unit | 37 | 1,12 | 37 | 1 | 37 | 3 / 40 |
| 6 | 3 | 4 steel-plate, 5 stone-brick, 1 engine-unit | 39 | 1,05 | 39 | 1 | 39 | 3 / 40 |
| 7 | 4 | 4 steel-plate, 5 stone-brick, 5 plastic-bar, 1 engine-unit | 54 | 1,38 | 47 | 0,86 | 47 | 4 / 48 |
| 8 | 4 | 4 steel-plate, 6 stone-brick, 7 plastic-bar, 2 engine-unit | 71 | 1,31 | 61 | 0,85 | 61 | 4 / 48 |
| 9 | 5 | 4 steel-plate, 6 stone-brick, 14 fo-tungsten-plate, 12 plastic-bar | 124 | 1,75 | 78 | 0,63 | 78 | 4 / 56 |
| 10 | 5 | 4 steel-plate, 7 stone-brick, 17 fo-tungsten-plate, 16 plastic-bar | 150 | 1,21 | 92 | 0,62 | 92 | 4 / 56 |
| 11 | 6 | 5 steel-plate, 7 stone-brick, 12 battery, 18 fo-tungsten-plate | 219 | 1,46 | 141 | 0,64 | 23 | 4 / 64 |
| 12 | 6 | 5 steel-plate, 8 stone-brick, 15 battery, 20 fo-tungsten-plate | 256 | 1,17 | 163 | 0,64 | 26 | 4 / 64 |
| 13 | 7 | 5 steel-plate, 8 stone-brick, 70 fo-resonance-crystal, 15 battery | 386 | 1,51 | 193 | 0,5 | 27 | 5 / 72 |
| 14 | 7 | 6 steel-plate, 8 stone-brick, 85 fo-resonance-crystal, 19 battery | 472 | 1,22 | 235 | 0,5 | 32 | 5 / 72 |
| 15 | 8 | 6 steel-plate, 9 stone-brick, 40 fo-methane-barrel, 90 fo-resonance-crystal | 718 | 1,52 | 538 | 0,75 | 55 | 8 / 80 |
| 16 | 8 | 6 steel-plate, 9 stone-brick, 50 fo-methane-barrel, 110 fo-resonance-crystal | 878 | 1,22 | 658 | 0,75 | 66 | 10 / 80 |
| 17 | 9 | 7 steel-plate, 10 stone-brick, 50 uranium-238, 50 fo-methane-barrel | 1 255 | 1,43 | 1 146 | 0,91 | 93 | 8 / 88 |
| 18 | 9 | 7 steel-plate, 10 stone-brick, 65 uranium-238, 60 fo-methane-barrel | 1 565 | 1,25 | 1 423 | 0,91 | 115 | 9 / 88 |
| 19 | 10 | 7 steel-plate, 11 stone-brick, 18 processing-unit, 65 uranium-238 | 2 317 | 1,48 | 2 103 | 0,91 | 1 | 4 / 96 |
| 20 | 10 | 7 steel-plate, 11 stone-brick, 20 processing-unit, 80 uranium-238 | 2 677 | 1,16 | 2 422 | 0,9 | 2 | 4 / 96 |
| 21 | 11 | 8 steel-plate, 12 stone-brick, 120 fo-titanium-plate, 20 processing-unit | 3 964 | 1,48 | 4 598 | 1,16 | 6 | 5 / 104 |
| 22 | 11 | 8 steel-plate, 12 stone-brick, 150 fo-titanium-plate, 25 processing-unit | 4 939 | 1,25 | 5 731 | 1,16 | 7 | 5 / 104 |
| 23 | 12 | 8 steel-plate, 12 stone-brick, 280 electric-engine-unit, 150 fo-titanium-plate | 7 544 | 1,53 | 8 523 | 1,13 | 7 | 10 / 112 |
| 24 | 12 | 9 steel-plate, 13 stone-brick, 350 electric-engine-unit, 190 fo-titanium-plate | 9 471 | 1,26 | 10 710 | 1,13 | 9 | 11 / 112 |
| 25 | 13 | 9 steel-plate, 13 stone-brick, 180 uranium-235, 340 electric-engine-unit | 13 611 | 1,44 | 11 867 | 0,87 | 0 | 11 / 120 |
| 26 | 13 | 9 steel-plate, 14 stone-brick, 230 uranium-235, 430 electric-engine-unit | 17 303 | 1,27 | 15 073 | 0,87 | 0 | 14 / 120 |
| 27 | 14 | 10 steel-plate, 14 stone-brick, 100 rocket-control-unit, 220 uranium-235 | 24 978 | 1,44 | 21 091 | 0,84 | 0 | 15 / 128 |
| 28 | 14 | 10 steel-plate, 15 stone-brick, 120 rocket-control-unit, 280 uranium-235 | 30 680 | 1,23 | 25 852 | 0,84 | 0 | 17 / 128 |
| 29 | 15 | 10 steel-plate, 15 stone-brick, 100 space-science-pack, 110 rocket-control-unit | 41 580 | 1,36 | 34 787 | 0,84 | 1 | 14 / 136 |
| 30 | 15 | 10 steel-plate, 16 stone-brick, 130 space-science-pack, 140 rocket-control-unit | 53 582 | 1,29 | 44 799 | 0,84 | 2 | 17 / 136 |

### Assembleur

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 6 iron-plate, 3 iron-gear-wheel, 3 electronic-circuit | 20 | — | 20 | 1 | 20 | 3 / 24 |
| 3 | 2 | 7 iron-plate, 3 iron-gear-wheel, 3 electronic-circuit, 2 steel-plate | 31 | 1,56 | 31 | 1 | 31 | 4 / 32 |
| 4 | 2 | 8 iron-plate, 4 iron-gear-wheel, 4 electronic-circuit, 3 steel-plate | 41 | 1,34 | 41 | 1 | 41 | 4 / 32 |
| 5 | 3 | 9 iron-plate, 4 iron-gear-wheel, 4 electronic-circuit, 2 engine-unit, 1 steel-plate | 50 | 1,22 | 50 | 1 | 50 | 5 / 40 |
| 6 | 3 | 10 iron-plate, 5 iron-gear-wheel, 5 electronic-circuit, 2 engine-unit, 1 steel-plate | 56 | 1,11 | 56 | 1 | 56 | 5 / 40 |
| 7 | 4 | 11 iron-plate, 5 iron-gear-wheel, 5 electronic-circuit, 6 plastic-bar, 1 engine-unit | 61 | 1,09 | 52 | 0,85 | 52 | 5 / 48 |
| 8 | 4 | 11 iron-plate, 6 iron-gear-wheel, 6 electronic-circuit, 8 plastic-bar, 2 engine-unit | 80 | 1,32 | 68 | 0,85 | 68 | 5 / 48 |
| 9 | 5 | 12 iron-plate, 6 iron-gear-wheel, 6 electronic-circuit, 16 fo-tungsten-plate, 14 plastic-bar | 145 | 1,81 | 92 | 0,64 | 92 | 5 / 56 |
| 10 | 5 | 13 iron-plate, 7 iron-gear-wheel, 7 electronic-circuit, 20 fo-tungsten-plate, 18 plastic-bar | 179 | 1,23 | 112 | 0,63 | 112 | 5 / 56 |
| 11 | 6 | 14 iron-plate, 7 iron-gear-wheel, 7 electronic-circuit, 14 battery, 20 fo-tungsten-plate | 252 | 1,41 | 162 | 0,64 | 21 | 5 / 64 |
| 12 | 6 | 15 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 17 battery, 25 fo-tungsten-plate | 304 | 1,21 | 194 | 0,64 | 25 | 5 / 64 |
| 13 | 7 | 16 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 80 fo-resonance-crystal, 18 battery | 454 | 1,49 | 231 | 0,51 | 26 | 6 / 72 |
| 14 | 7 | 17 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 100 fo-resonance-crystal, 25 battery | 578 | 1,27 | 290 | 0,5 | 33 | 6 / 72 |
| 15 | 8 | 18 iron-plate, 9 iron-gear-wheel, 9 electronic-circuit, 45 fo-methane-barrel, 100 fo-resonance-crystal | 809 | 1,4 | 609 | 0,75 | 57 | 10 / 80 |
| 16 | 8 | 19 iron-plate, 9 iron-gear-wheel, 9 electronic-circuit, 60 fo-methane-barrel, 130 fo-resonance-crystal | 1 050 | 1,3 | 790 | 0,75 | 74 | 12 / 80 |
| 17 | 9 | 20 iron-plate, 10 iron-gear-wheel, 10 electronic-circuit, 60 uranium-238, 55 fo-methane-barrel | 1 455 | 1,39 | 1 324 | 0,91 | 103 | 10 / 88 |
| 18 | 9 | 20 iron-plate, 10 iron-gear-wheel, 10 electronic-circuit, 75 uranium-238, 70 fo-methane-barrel | 1 815 | 1,25 | 1 652 | 0,91 | 129 | 11 / 88 |
| 19 | 10 | 20 iron-plate, 11 iron-gear-wheel, 11 electronic-circuit, 20 processing-unit, 75 uranium-238 | 2 620 | 1,44 | 2 376 | 0,91 | 1 | 5 / 96 |
| 20 | 10 | 20 iron-plate, 11 iron-gear-wheel, 11 electronic-circuit, 25 processing-unit, 95 uranium-238 | 3 275 | 1,25 | 2 967 | 0,91 | 2 | 5 / 96 |
| 21 | 11 | 25 iron-plate, 12 iron-gear-wheel, 12 electronic-circuit, 140 fo-titanium-plate, 25 processing-unit | 4 754 | 1,45 | 5 487 | 1,15 | 7 | 6 / 104 |
| 22 | 11 | 25 iron-plate, 12 iron-gear-wheel, 12 electronic-circuit, 180 fo-titanium-plate, 30 processing-unit | 5 929 | 1,25 | 6 880 | 1,16 | 8 | 6 / 104 |
| 23 | 12 | 25 iron-plate, 12 iron-gear-wheel, 12 electronic-circuit, 330 electric-engine-unit, 170 fo-titanium-plate | 8 759 | 1,48 | 9 873 | 1,13 | 8 | 12 / 112 |
| 24 | 12 | 25 iron-plate, 13 iron-gear-wheel, 13 electronic-circuit, 410 electric-engine-unit, 220 fo-titanium-plate | 11 044 | 1,26 | 12 480 | 1,13 | 10 | 15 / 112 |
| 25 | 13 | 25 iron-plate, 13 iron-gear-wheel, 13 electronic-circuit, 210 uranium-235, 400 electric-engine-unit | 15 934 | 1,44 | 13 900 | 0,87 | 0 | 14 / 120 |
| 26 | 13 | 30 iron-plate, 14 iron-gear-wheel, 14 electronic-circuit, 260 uranium-235, 500 electric-engine-unit | 19 793 | 1,24 | 17 276 | 0,87 | 0 | 16 / 120 |
| 27 | 14 | 30 iron-plate, 14 iron-gear-wheel, 14 electronic-circuit, 120 rocket-control-unit, 260 uranium-235 | 29 793 | 1,51 | 25 170 | 0,84 | 0 | 18 / 128 |
| 28 | 14 | 30 iron-plate, 15 iron-gear-wheel, 15 electronic-circuit, 140 rocket-control-unit, 320 uranium-235 | 35 498 | 1,19 | 29 933 | 0,84 | 0 | 21 / 128 |
| 29 | 15 | 30 iron-plate, 15 iron-gear-wheel, 15 electronic-circuit, 120 space-science-pack, 130 rocket-control-unit | 49 598 | 1,4 | 41 478 | 0,84 | 1 | 17 / 136 |
| 30 | 15 | 30 iron-plate, 16 iron-gear-wheel, 16 electronic-circuit, 150 space-science-pack, 160 rocket-control-unit | 61 602 | 1,24 | 51 493 | 0,84 | 2 | 20 / 136 |

## 6. Calendrier : durée impliquée par époque selon l'hypothèse de modules

Même modèle que `levels_test --tables` (base de référence `L.target.base`, 30 % de la production X0 aux niveaux) ; seule la valeur des
coûts change : déclarée, puis matière brute réelle sous H0, H2r, H2.

| Époque | Durée X0 | Dépense déclarée (u) | Impliquée (déclarée) | Dépense réelle H0 | Impliquée H0 | Dépense réelle H2r | Impliquée H2r | Dépense réelle H2 | Impliquée H2 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 0 h 30 | 1 222 | 0 h 30 | 1 222 | 0 h 30 | 1 222 | 0 h 30 | 1 222 | 0 h 30 |
| 2 | 1 h 00 | 4 464 | 1 h 00 | 4 464 | 1 h 00 | 4 464 | 1 h 00 | 4 464 | 1 h 00 |
| 3 | 1 h 30 | 12 202 | 1 h 30 | 12 202 | 1 h 30 | 12 202 | 1 h 30 | 12 202 | 1 h 30 |
| 4 | 2 h 00 | 29 860 | 2 h 00 | 25 116 | 1 h 41 | 25 116 | 1 h 41 | 25 116 | 1 h 41 |
| 5 | 2 h 30 | 67 917 | 2 h 30 | 45 608 | 1 h 41 | 45 608 | 1 h 41 | 45 608 | 1 h 41 |
| 6 | 3 h 00 | 147 996 | 2 h 59 | 98 551 | 1 h 59 | 64 066 | 1 h 17 | 13 958 | 0 h 17 |
| 7 | 3 h 30 | 320 788 | 3 h 32 | 165 183 | 1 h 49 | 119 916 | 1 h 19 | 21 568 | 0 h 14 |
| 8 | 4 h 00 | 672 400 | 4 h 03 | 517 412 | 3 h 07 | 331 838 | 2 h 00 | 49 307 | 0 h 18 |
| 9 | 4 h 30 | 1 364 437 | 4 h 29 | 1 180 769 | 3 h 53 | 804 705 | 2 h 39 | 95 444 | 0 h 19 |
| 10 | 5 h 00 | 2 779 650 | 5 h 00 | 2 493 010 | 4 h 29 | 519 132 | 0 h 56 | 1 562 | 0 h 00 |
| 11 | 5 h 30 | 5 572 191 | 5 h 29 | 6 374 492 | 6 h 17 | 2 796 936 | 2 h 45 | 8 506 | 0 h 01 |
| 12 | 6 h 00 | 11 140 390 | 6 h 00 | 12 199 182 | 6 h 34 | 2 951 044 | 1 h 35 | 8 975 | 0 h 00 |
| 13 | 6 h 30 | 22 049 088 | 6 h 30 | 19 212 336 | 5 h 39 | 888 518 | 0 h 16 | 2 695 | 0 h 00 |
| 14 | 7 h 00 | 43 398 064 | 6 h 59 | 37 449 942 | 6 h 02 | 622 498 | 0 h 06 | 1 893 | 0 h 00 |
| 15 | 7 h 00 | 79 281 262 | 6 h 59 | 66 354 110 | 5 h 51 | 1 325 845 | 0 h 07 | 4 033 | 0 h 00 |
| **Total** | **59 h 30** | | **59 h 31** | | **52 h 02** | | **19 h 23** | | **7 h 31** |

## 7. Recherche par époque (coûts FINAUX de l'étape data)

Époque d'une technologie : règle QX9 de la config (`L.vanilla_tech_epoch`), relevée au maximum de ses prérequis. Packs valorisés en MU réelle H0.

| Époque | Technologies | Unités | Temps de labo (labo-heures, vitesse 1) | Packs (MU) | Budget X0 de l'époque (u) | Packs / budget | Visée X0 : 35 % |
|---|---|---|---|---|---|---|---|
| 1 | 5 | 216 | 1,6 | 648 | 4 054 | 16 % | dans la fourchette |
| 2 | 13 | 198 | 1,5 | 1 483 | 14 826 | 10 % | **écart** |
| 3 | 16 | 215 | 2,4 | 4 677 | 40 662 | 11,5 % | **écart** |
| 4 | 41 | 409 | 3,8 | 11 617 | 99 130 | 11,7 % | dans la fourchette |
| 5 | 4 | 1 200 | 10 | 63 813 | 226 561 | 28,2 % | dans la fourchette |
| 6 | 35 | 761 | 6,8 | 64 123 | 497 094 | 12,9 % | dans la fourchette |
| 7 | 2 | 800 | 9,6 | 55 928 | 1 060 369 | 5,3 % | **écart** |
| 8 | 5 | 183 | 1,6 | 4 162 | 2 215 750 | 0,2 % | **écart** |
| 9 | 3 | 1 050 | 8,8 | 41 264 | 4 557 694 | 0,9 % | **écart** |
| 10 | 70 | 16 466 | 230,7 | 3 222 266 | 9 259 223 | 34,8 % | dans la fourchette |
| 11 | 0 | 0 | 0 | 0 | 18 622 549 | 0 % | **écart** |
| 12 | 1 | 1 500 | 25 | 375 801 | 37 144 935 | 1 % | **écart** |
| 13 | 2 | 2 700 | 22,5 | 657 741 | 73 575 568 | 0,9 % | **écart** |
| 14 | 17 | 226 200 | 3753,3 | 95 761 078 | 144 873 923 | 66,1 % | **écart** |
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
| 4 | 4,5 | 6 000 | 0,84 | × 1 | 4,5 | 6 000 | 1,5 |
| 5 | 15,5 | 6 060 | 0,67 | × 1 | 15,5 | 6 060 | 2 |
| 6 | 29,2 | 6 160 | 0,67 | × 7,06 | 210 | 43 500 | 5,5 |
| 7 | 57,9 | 6 290 | 0,51 | × 7,66 | 440 | 48 200 | 1 |
| 8 | 110 | 6 380 | 0,77 | × 10,49 | 1 150 | 66 900 | 10 |
| 9 | 204 | 14 100 | 0,87 | × 12,37 | 2 520 | 174 400 | 11,8 |
| 10 | 370 | 50 300 | 0,9 | × 1595,75 | 590 400 | 8 × 10^7 | 70 |
| 11 | 687 | 51 800 | 1,14 | × 749,42 | 514 900 | 3,9 × 10^7 | 25 |
| 12 | 1240 | 53 400 | 1,1 | × 1359,28 | 1 685 500 | 7,3 × 10^7 | 16,3 |
| 13 | 2270 | 80 100 | 0,87 | × 7129,29 | 1,6 × 10^7 | 5,7 × 10^8 | 35 |
| 14 | 4140 | 190 000 | 0,86 | × 2 × 10^4 | 8,2 × 10^7 | 3,8 × 10^9 | 130 |
| 15 | 7070 | 0 | 0,84 | × 1,6 × 10^4 | 1,2 × 10^8 | 0 | 200 |

Lecture : sous H2, l'époque e est payée « Gain H2 » fois plus vite qu'en H0 ; (A) remet chaque époque à sa durée X0 en multipliant
valeur d'époque et passage du centre par ce gain (les quantités affichées grandissent d'autant : la règle de place du coffre est alors
à revérifier, `levels_test`). La dernière colonne aligne la valeur déclarée des monnaies sur leur coût réel (règle du modèle : « valeur
de l'objet en unités de matière brute ») ; elle ne change ni `value_mult` ni le calendrier, seulement les QUANTITÉS demandées.
