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
| FAUX | Époque 5 : `fo-tungsten-plate` déclarée 2 u, matière brute réelle 1 (rapport 2, hors de 0,67 à 1,5). |
| BIAIS | Époque 7 : `fo-resonance-crystal` déclarée 3 u, matière brute réelle 1 (rapport 3, hors de 0,67 à 1,5) ; rareté assumée par X0 (gisements rares, valeur de monnaie au-dessus du minerai). |
| FAUX | Époque 10 : `processing-unit` déclarée 75 u, matière brute réelle 45,34 (rapport 1,65, hors de 0,67 à 1,5). |
| BIAIS | Époque 15 : `space-science-pack` déclarée 250 u, matière brute réelle 133,41 (rapport 1,87, hors de 0,67 à 1,5) ; monnaie provisoire. |
| NOTE | Détour : dès l'époque 10, la chaîne la moins chère de `plastic-bar` sous H2 abandonne `crude-oil` (brut principal de H0) : coal-liquefaction, fo-polyethylene, fo-steam-cracking, gisement:coal, heavy-oil-cracking, light-oil-cracking. |
| NOTE | Détour : dès l'époque 10, la chaîne la moins chère de `battery` sous H2 abandonne `crude-oil` (brut principal de H0) : battery, coal-liquefaction, copper-plate, fo-iron-concentrate, fo-iron-plate-r8, fo-iron-plate-r8-unpacking, gisement:coal, gisement:copper-ore, gisement:iron-ore, heavy-oil-cracking, light-oil-cracking, sulfur, sulfuric-acid. |
| NOTE | Détour : dès l'époque 10, la chaîne la moins chère de `processing-unit` sous H2 abandonne `copper-ore` (brut principal de H0) : advanced-circuit, coal-liquefaction, electronic-circuit, fo-iron-concentrate, fo-iron-plate-r8, fo-iron-plate-r8-unpacking, fo-polyethylene, fo-sand, fo-steam-cracking, fo-water-electrolysis, gisement:coal, gisement:iron-ore, heavy-oil-cracking, light-oil-cracking, processing-unit, sulfur, sulfuric-acid. |
| BIAIS | command : le niveau 11 coûte × 4,19 du niveau 10 (16 055 → 67 260 u). |
| NOTE | assembler niveau 20 (époque 10) : 24 modules de productivité palier 5 dépassent le plafond × 328,67 du moteur (cases perdues). |
| NOTE | drill niveau 20 (époque 10) : 24 modules de productivité palier 5 dépassent le plafond × 328,67 du moteur (cases perdues). |
| NOTE | Recettes d'assembleur qui dépasseraient 60 fabrications/s (le moteur bride) avec la machine de l'époque pleine de modules de vitesse : époque 6 : 90 ; époque 7 : 109 ; époque 8 : 123 ; époque 9 : 151 ; époque 10 : 257 ; époque 11 : 264 ; époque 12 : 267 ; époque 13 : 270 ; époque 14 : 270 ; époque 15 : 273. |
| NOTE | Bruts sans gisement ni recette (comptés 1 MU) : wood. |

## 2. Monnaies d'époque : valeur déclarée contre matière brute réelle

| Époque | Objet en jeu | Valeur déclarée (u) | MU réelle H0 | Déclarée / réelle | MU réelle H2 (modules de l'époque) | Gain H2 | Monnaie X0 (papier) | Valeur X0 |
|---|---|---|---|---|---|---|---|---|
| 2 | `steel-plate` | 5 | 5 | 1 | 5 | × 1 | même | 5 |
| 3 | `engine-unit` | 9 | 9 | 1 | 9 | × 1 | même | 9 |
| 4 | `plastic-bar` | 1 | 0,99 | 1,01 | 0,99 | × 1 | même | 1 |
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
| 2 | 1 | 0,862 | 3 | 0,096 | 6 | — | 1 | 0,096 | 1 | 1 |
| 3 | 2 | 0,992 | 3 | 0,11 | 7 | — | 1 | 0,11 | 1 | 1 |
| 4 | 2 | 1,141 | 3 | 0,127 | 8 | — | 1 | 0,127 | 1 | 1 |
| 5 | 3 | 1,312 | 3 | 0,146 | 9 | — | 1 | 0,146 | 1 | 1 |
| 6 | 3 | 1,509 | 3 | 0,168 | 10 | — | 1 | 0,168 | 1 | 1 |
| 7 | 4 | 1,735 | 4 | 0,108 | 11 | — | 1 | 0,108 | 1 | 1 |
| 8 | 4 | 1,995 | 4 | 0,125 | 12 | — | 1 | 0,125 | 1 | 1 |
| 9 | 5 | 2,294 | 4 | 0,143 | 13 | — | 1 | 0,143 | 1 | 1 |
| 10 | 5 | 2,638 | 4 | 0,165 | 14 | — | 1 | 0,165 | 1 | 1 |
| 11 | 6 | 3,034 | 4 | 0,19 | 15 | 1 / 1 | 15,41 | 2,922 | 4,18 | 3,09 |
| 12 | 6 | 3,489 | 4 | 0,218 | 16 | 1 / 1 | 18,49 | 4,032 | 4,59 | 3,3 |
| 13 | 7 | 4,013 | 5 | 0,161 | 17 | 1 / 1 | 22,19 | 3,562 | 5,05 | 3,59 |
| 14 | 7 | 4,615 | 5 | 0,185 | 18 | 1 / 1 | 26,62 | 4,914 | 5,56 | 3,89 |
| 15 | 8 | 5,307 | 5 | 0,212 | 19 | 1 / 1 | 31,95 | 6,782 | 6,12 | 4,16 |
| 16 | 8 | 6,103 | 5 | 0,244 | 20 | 1 / 1 | 38,34 | 9,359 | 6,73 | 4,51 |
| 17 | 9 | 7,018 | 5 | 0,281 | 21 | 1 / 1 | 46,01 | 12,916 | 7,4 | 4,81 |
| 18 | 9 | 8,071 | 5 | 0,323 | 22 | 1 / 1 | 55,21 | 17,824 | 8,14 | 5,21 |
| 19 | 10 | 9,282 | 6 | 0,258 | 23 | 5 / 5 | 328,67 | 84,738 | 328,67 | 65,73 |
| 20 | 10 | 10,674 | 6 | 0,296 | 24 | 5 / 5 | 328,67 | 97,449 | 328,67 | 65,73 |
| 21 | 11 | 12,275 | 6 | 0,341 | 25 | 5 / 5 | 328,67 | 112,066 | 328,67 | 65,73 |
| 22 | 11 | 14,116 | 6 | 0,392 | 26 | 5 / 5 | 328,67 | 128,876 | 328,67 | 65,73 |
| 23 | 12 | 16,234 | 6 | 0,451 | 27 | 5 / 5 | 328,67 | 148,208 | 328,67 | 65,73 |
| 24 | 12 | 18,669 | 6 | 0,519 | 28 | 5 / 5 | 328,67 | 170,439 | 328,67 | 65,73 |
| 25 | 13 | 21,469 | 6 | 0,596 | 29 | 5 / 5 | 328,67 | 196,005 | 328,67 | 65,73 |
| 26 | 13 | 24,689 | 6 | 0,686 | 30 | 5 / 5 | 328,67 | 225,406 | 328,67 | 65,73 |
| 27 | 14 | 28,393 | 6 | 0,789 | 31 | 10 / 10 | 328,67 | 259,217 | 328,67 | 65,73 |
| 28 | 14 | 32,651 | 6 | 0,907 | 32 | 10 / 10 | 328,67 | 298,099 | 328,67 | 65,73 |
| 29 | 15 | 37,549 | 6 | 1,043 | 33 | 10 / 10 | 328,67 | 342,814 | 328,67 | 65,73 |
| 30 | 15 | 43,182 | 6 | 1,199 | 34 | 10 / 10 | 328,67 | 394,236 | 328,67 | 65,73 |

### Four

| Niveau | Époque | Vitesse | Côté | Vitesse / tuile | Cases | Palier dispo. | × vitesse (H1) | Vitesse / tuile H1 | × productivité (H2) | × sortie (H2) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 2 | 2 | 0,5 | 0 | — | 1 | 0,5 | 1 | 1 |
| 2 | 1 | 2,3 | 2 | 0,575 | 0 | — | 1 | 0,575 | 1 | 1 |
| 3 | 2 | 2,645 | 2 | 0,661 | 0 | — | 1 | 0,661 | 1 | 1 |
| 4 | 2 | 3,042 | 2 | 0,76 | 0 | — | 1 | 0,76 | 1 | 1 |
| 5 | 3 | 3,498 | 2 | 0,875 | 0 | — | 1 | 0,875 | 1 | 1 |
| 6 | 3 | 4,023 | 2 | 1,006 | 0 | — | 1 | 1,006 | 1 | 1 |
| 7 | 4 | 4,626 | 3 | 0,514 | 0 | — | 1 | 0,514 | 1 | 1 |
| 8 | 4 | 5,32 | 3 | 0,591 | 0 | — | 1 | 0,591 | 1 | 1 |
| 9 | 5 | 6,118 | 3 | 0,68 | 0 | — | 1 | 0,68 | 1 | 1 |
| 10 | 5 | 7,036 | 3 | 0,782 | 0 | — | 1 | 0,782 | 1 | 1 |
| 11 | 6 | 8,091 | 3 | 0,899 | 0 | 1 / 1 | 1 | 0,899 | 1 | 1 |
| 12 | 6 | 9,305 | 3 | 1,034 | 0 | 1 / 1 | 1 | 1,034 | 1 | 1 |
| 13 | 7 | 10,701 | 4 | 0,669 | 0 | 1 / 1 | 1 | 0,669 | 1 | 1 |
| 14 | 7 | 12,306 | 4 | 0,769 | 0 | 1 / 1 | 1 | 0,769 | 1 | 1 |
| 15 | 8 | 14,151 | 4 | 0,884 | 0 | 1 / 1 | 1 | 0,884 | 1 | 1 |
| 16 | 8 | 16,274 | 4 | 1,017 | 0 | 1 / 1 | 1 | 1,017 | 1 | 1 |
| 17 | 9 | 18,715 | 4 | 1,17 | 0 | 1 / 1 | 1 | 1,17 | 1 | 1 |
| 18 | 9 | 21,523 | 4 | 1,345 | 0 | 1 / 1 | 1 | 1,345 | 1 | 1 |
| 19 | 10 | 24,751 | 5 | 0,99 | 0 | 5 / 5 | 1 | 0,99 | 1 | 1 |
| 20 | 10 | 28,464 | 5 | 1,139 | 0 | 5 / 5 | 1 | 1,139 | 1 | 1 |
| 21 | 11 | 32,733 | 5 | 1,309 | 0 | 5 / 5 | 1 | 1,309 | 1 | 1 |
| 22 | 11 | 37,643 | 5 | 1,506 | 0 | 5 / 5 | 1 | 1,506 | 1 | 1 |
| 23 | 12 | 43,289 | 5 | 1,732 | 0 | 5 / 5 | 1 | 1,732 | 1 | 1 |
| 24 | 12 | 49,783 | 5 | 1,991 | 0 | 5 / 5 | 1 | 1,991 | 1 | 1 |
| 25 | 13 | 57,25 | 6 | 1,59 | 0 | 5 / 5 | 1 | 1,59 | 1 | 1 |
| 26 | 13 | 65,838 | 6 | 1,829 | 0 | 5 / 5 | 1 | 1,829 | 1 | 1 |
| 27 | 14 | 75,714 | 6 | 2,103 | 0 | 10 / 10 | 1 | 2,103 | 1 | 1 |
| 28 | 14 | 87,071 | 6 | 2,419 | 0 | 10 / 10 | 1 | 2,419 | 1 | 1 |
| 29 | 15 | 100,131 | 6 | 2,781 | 0 | 10 / 10 | 1 | 2,781 | 1 | 1 |
| 30 | 15 | 115,151 | 6 | 3,199 | 0 | 10 / 10 | 1 | 3,199 | 1 | 1 |

### Foreuse

| Niveau | Époque | Vitesse | Côté | Vitesse / tuile | Cases | Palier dispo. | × vitesse (H1) | Vitesse / tuile H1 | × productivité (H2) | × sortie (H2) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 0,5 | 3 | 0,056 | 5 | — | 1 | 0,056 | 1 | 1 |
| 2 | 1 | 0,575 | 3 | 0,064 | 6 | — | 1 | 0,064 | 1 | 1 |
| 3 | 2 | 0,661 | 3 | 0,073 | 7 | — | 1 | 0,073 | 1 | 1 |
| 4 | 2 | 0,76 | 3 | 0,084 | 8 | — | 1 | 0,084 | 1 | 1 |
| 5 | 3 | 0,875 | 3 | 0,097 | 9 | — | 1 | 0,097 | 1 | 1 |
| 6 | 3 | 1,006 | 3 | 0,112 | 10 | — | 1 | 0,112 | 1 | 1 |
| 7 | 4 | 1,157 | 4 | 0,072 | 11 | — | 1 | 0,072 | 1 | 1 |
| 8 | 4 | 1,33 | 4 | 0,083 | 12 | — | 1 | 0,083 | 1 | 1 |
| 9 | 5 | 1,53 | 4 | 0,096 | 13 | — | 1 | 0,096 | 1 | 1 |
| 10 | 5 | 1,759 | 4 | 0,11 | 14 | — | 1 | 0,11 | 1 | 1 |
| 11 | 6 | 2,023 | 4 | 0,126 | 15 | 1 / 1 | 15,41 | 1,948 | 4,18 | 3,09 |
| 12 | 6 | 2,326 | 4 | 0,145 | 16 | 1 / 1 | 18,49 | 2,688 | 4,59 | 3,3 |
| 13 | 7 | 2,675 | 5 | 0,107 | 17 | 1 / 1 | 22,19 | 2,374 | 5,05 | 3,59 |
| 14 | 7 | 3,076 | 5 | 0,123 | 18 | 1 / 1 | 26,62 | 3,276 | 5,56 | 3,89 |
| 15 | 8 | 3,538 | 5 | 0,142 | 19 | 1 / 1 | 31,95 | 4,521 | 6,12 | 4,16 |
| 16 | 8 | 4,069 | 5 | 0,163 | 20 | 1 / 1 | 38,34 | 6,239 | 6,73 | 4,51 |
| 17 | 9 | 4,679 | 5 | 0,187 | 21 | 1 / 1 | 46,01 | 8,611 | 7,4 | 4,81 |
| 18 | 9 | 5,381 | 5 | 0,215 | 22 | 1 / 1 | 55,21 | 11,883 | 8,14 | 5,21 |
| 19 | 10 | 6,188 | 6 | 0,172 | 23 | 5 / 5 | 328,67 | 56,492 | 328,67 | 65,73 |
| 20 | 10 | 7,116 | 6 | 0,198 | 24 | 5 / 5 | 328,67 | 64,966 | 328,67 | 65,73 |
| 21 | 11 | 8,183 | 6 | 0,227 | 25 | 5 / 5 | 328,67 | 74,711 | 328,67 | 65,73 |
| 22 | 11 | 9,411 | 6 | 0,261 | 26 | 5 / 5 | 328,67 | 85,918 | 328,67 | 65,73 |
| 23 | 12 | 10,822 | 6 | 0,301 | 27 | 5 / 5 | 328,67 | 98,805 | 328,67 | 65,73 |
| 24 | 12 | 12,446 | 6 | 0,346 | 28 | 5 / 5 | 328,67 | 113,626 | 328,67 | 65,73 |
| 25 | 13 | 14,313 | 6 | 0,398 | 29 | 5 / 5 | 328,67 | 130,67 | 328,67 | 65,73 |
| 26 | 13 | 16,459 | 6 | 0,457 | 30 | 5 / 5 | 328,67 | 150,27 | 328,67 | 65,73 |
| 27 | 14 | 18,928 | 6 | 0,526 | 31 | 10 / 10 | 328,67 | 172,811 | 328,67 | 65,73 |
| 28 | 14 | 21,768 | 6 | 0,605 | 32 | 10 / 10 | 328,67 | 198,733 | 328,67 | 65,73 |
| 29 | 15 | 25,033 | 6 | 0,695 | 33 | 10 / 10 | 328,67 | 228,543 | 328,67 | 65,73 |
| 30 | 15 | 28,788 | 6 | 0,8 | 34 | 10 / 10 | 328,67 | 262,824 | 328,67 | 65,73 |

## 4. Chaînes : machines pour 1 monnaie par seconde, machines de l'époque

| Époque | Monnaie | Machines H0 | Tuiles H0 | Machines H1 (vitesse) | Tuiles H1 | Machines H2 | Tuiles H2 | Fluides de gisement H0 (u/s) | Machines H0 (détail) |
|---|---|---|---|---|---|---|---|---|---|
| 2 | `steel-plate` | 12,3 | 128 | 12,3 | 128 | 12,3 | 128 | — | 2,6 fo-arc-furnace, 2,67 fo-coke-oven, 0,33 fo-lvl-assembler-4, 6,58 fo-lvl-drill-4, 0,1 fo-ore-concentrator |
| 3 | `engine-unit` | 22,8 | 223 | 22,8 | 223 | 22,8 | 223 | — | 2,73 fo-arc-furnace, 2,67 fo-coke-oven, 8,2 fo-lvl-assembler-6, 8,95 fo-lvl-drill-6, 0,23 fo-ore-concentrator |
| 4 | `plastic-bar` | 1,8 | 23 | 1,8 | 23 | 1,8 | 23 | crude-oil 6,6 | 0,72 chemical-plant, 0,02 fo-electrolyzer, 0,25 fo-lvl-drill-8, 0,44 fo-steam-cracker, 0,33 oil-refinery |
| 5 | `fo-tungsten-plate` | 1,3 | 20 | 1,3 | 20 | 1,3 | 20 | — | 0,07 fo-arc-furnace, 0,05 fo-lvl-assembler-10, 1,14 fo-lvl-drill-10, 0,03 fo-ore-concentrator |
| 6 | `battery` | 10,3 | 124 | 5,5 | 64 | 5,6 | 60 | crude-oil 29,5 | 7,15 chemical-plant, 0,05 fo-arc-furnace, 0,11 fo-electrolyzer, 0,05 fo-lvl-assembler-12, 1,03 fo-lvl-drill-12, 0,34 fo-lvl-furnace-12, 0,05 fo-ore-concentrator, 1,48 oil-refinery |
| 7 | `fo-resonance-crystal` | 0,5 | 12 | 0 | 0 | 0,1 | 3 | — | 0,49 fo-lvl-drill-14 |
| 8 | `fo-methane-barrel` | 6,9 | 103 | 4,6 | 54 | 0,8 | 12 | fo-methane 50 | 2,6 fo-arc-furnace, 2,67 fo-coke-oven, 0,26 fo-lvl-assembler-16, 1,23 fo-lvl-drill-16, 0,1 fo-ore-concentrator |
| 9 | `uranium-238` | 18,3 | 237 | 9,8 | 97 | 11,1 | 110 | crude-oil 14,9 | 12,08 centrifuge, 1,58 chemical-plant, 0,01 fo-arc-furnace, 0,06 fo-electrolyzer, 0 fo-lvl-assembler-18, 3,78 fo-lvl-drill-18, 0,01 fo-ore-concentrator, 0,74 oil-refinery |
| 10 | `processing-unit` | 41,6 | 981 | 10 | 188 | 0 | 1 | crude-oil 33,6, fo-brine 0,5 | 4,67 chemical-plant, 1,97 fo-arc-furnace, 17,5 fo-cleanroom, 1 fo-coke-oven, 0,34 fo-electrolyzer, 0,37 fo-jaw-crusher, 3,12 fo-lvl-assembler-20, 5,89 fo-lvl-drill-20, 2,81 fo-lvl-furnace-20, 0,47 fo-ore-concentrator, 1,78 fo-steam-cracker, 1,68 oil-refinery |
| 11 | `fo-titanium-plate` | 26 | 344 | 10,5 | 96 | 13,1 | 123 | fo-brine 54,5 | 5 chemical-plant, 0,77 fo-arc-furnace, 6 fo-coke-oven, 9,27 fo-electrolyzer, 0,5 fo-kroll-reactor, 3,88 fo-lvl-drill-22, 0,53 fo-ore-concentrator |
| 12 | `fo-superconducting-coil` | 102,2 | 1536 | 29,9 | 344 | 12,5 | 87 | crude-oil 82,8, fo-brine 55 | 21,98 chemical-plant, 2,55 fo-arc-furnace, 17,5 fo-cleanroom, 10 fo-coil-winder, 7 fo-coke-oven, 0,8 fo-cryogenic-unit, 10,1 fo-electrolyzer, 6 fo-extraction-column, 0,37 fo-jaw-crusher, 0,5 fo-kroll-reactor, 2,28 fo-lvl-assembler-24, 7,43 fo-lvl-drill-24, 1,8 fo-lvl-furnace-24, 1,08 fo-ore-concentrator, 6 fo-sintering-furnace, 2,67 fo-steam-cracker, 4,14 oil-refinery |
| 13 | `uranium-235` | 104,9 | 1077 | 38,6 | 356 | 2,8 | 26 | crude-oil 43,7 | 94,26 centrifuge, 4,65 chemical-plant, 0,02 fo-arc-furnace, 0,16 fo-electrolyzer, 0 fo-lvl-assembler-26, 3,63 fo-lvl-drill-26, 0,02 fo-ore-concentrator, 2,18 oil-refinery |
| 14 | `rocket-control-unit` | 56,4 | 1163 | 8,2 | 154 | 0 | 1 | crude-oil 99,2, fo-brine 0,5 | 11,88 chemical-plant, 2,47 fo-arc-furnace, 17,5 fo-cleanroom, 1 fo-coke-oven, 0,58 fo-electrolyzer, 0,38 fo-jaw-crusher, 4,1 fo-lvl-assembler-28, 4,26 fo-lvl-drill-28, 2,11 fo-lvl-furnace-28, 0,97 fo-ore-concentrator, 6,22 fo-steam-cracker, 4,96 oil-refinery |
| 15 | `space-science-pack` | 96,2 | 1653 | 16 | 229 | 2,5 | 37 | crude-oil 196,6, fo-brine 15,5 | 35,48 chemical-plant, 4,48 fo-arc-furnace, 19,25 fo-cleanroom, 4,82 fo-coke-oven, 3,4 fo-electrolyzer, 0,41 fo-jaw-crusher, 0,14 fo-kroll-reactor, 4,29 fo-lvl-assembler-30, 4,05 fo-lvl-drill-30, 1,82 fo-lvl-furnace-30, 1,24 fo-ore-concentrator, 6,64 fo-steam-cracker, 9,83 oil-refinery, 0,3 rocket-silo |

## 5. Coût de chaque niveau : valeur déclarée, matière brute réelle H0 et H2

Valeur déclarée : `L.cost_value` (ce que compte le calendrier). Réelle : quantités × MU réelle de chaque objet, à l'époque où l'on paie.

### Centre

| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 310 iron-plate, 160 copper-plate, 160 stone-brick, 60 electronic-circuit | 940 | — | 940 | 1 | 940 | 9 / 24 |
| 3 | 2 | 360 iron-plate, 180 copper-plate, 180 stone-brick, 70 electronic-circuit, 80 steel-plate | 1 475 | 1,57 | 1 475 | 1 | 1 475 | 10 / 32 |
| 4 | 3 | 400 iron-plate, 210 copper-plate, 210 stone-brick, 80 electronic-circuit, 70 engine-unit, 85 steel-plate | 2 285 | 1,55 | 2 285 | 1 | 2 285 | 14 / 40 |
| 5 | 4 | 450 iron-plate, 230 copper-plate, 230 stone-brick, 85 electronic-circuit, 1 990 plastic-bar, 150 engine-unit | 4 693 | 2,05 | 4 671 | 1 | 4 671 | 35 / 48 |
| 6 | 5 | 500 iron-plate, 260 copper-plate, 260 stone-brick, 95 electronic-circuit, 1 500 fo-tungsten-plate, 2 000 plastic-bar | 6 518 | 1,39 | 4 996 | 0,77 | 4 996 | 47 / 56 |
| 7 | 6 | 540 iron-plate, 280 copper-plate, 280 stone-brick, 110 electronic-circuit, 670 battery, 1 230 fo-tungsten-plate | 7 800 | 1,2 | 6 470 | 0,83 | 948 | 30 / 64 |
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
| 7 | 4 | 11 iron-plate, 5 iron-gear-wheel, 5 copper-plate, 45 plastic-bar, 3 engine-unit | 98 | 1,85 | 98 | 0,99 | 98 | 5 / 48 |
| 8 | 4 | 11 iron-plate, 6 iron-gear-wheel, 6 copper-plate, 55 plastic-bar, 4 engine-unit | 120 | 1,22 | 119 | 0,99 | 119 | 5 / 48 |
| 9 | 5 | 12 iron-plate, 6 iron-gear-wheel, 6 copper-plate, 55 fo-tungsten-plate, 75 plastic-bar | 215 | 1,79 | 159 | 0,74 | 159 | 5 / 56 |
| 10 | 5 | 13 iron-plate, 7 iron-gear-wheel, 7 copper-plate, 70 fo-tungsten-plate, 95 plastic-bar | 269 | 1,25 | 198 | 0,74 | 198 | 5 / 56 |
| 11 | 6 | 14 iron-plate, 7 iron-gear-wheel, 7 copper-plate, 40 battery, 70 fo-tungsten-plate | 395 | 1,47 | 319 | 0,81 | 43 | 5 / 64 |
| 12 | 6 | 15 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 45 battery, 85 fo-tungsten-plate | 457 | 1,16 | 365 | 0,8 | 49 | 5 / 64 |
| 13 | 7 | 16 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 140 fo-resonance-crystal, 50 battery | 735 | 1,61 | 448 | 0,61 | 53 | 7 / 72 |
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
| 7 | 4 | 5 steel-plate, 5 electronic-circuit, 4 battery, 75 plastic-bar, 6 engine-unit | 189 | 2,17 | 187 | 0,99 | 187 | 5 / 48 |
| 8 | 4 | 6 steel-plate, 6 electronic-circuit, 4 battery, 95 plastic-bar, 7 engine-unit | 225 | 1,19 | 223 | 0,99 | 223 | 5 / 48 |
| 9 | 5 | 6 steel-plate, 6 electronic-circuit, 4 battery, 95 fo-tungsten-plate, 120 plastic-bar | 377 | 1,68 | 280 | 0,74 | 280 | 6 / 56 |
| 10 | 5 | 7 steel-plate, 7 electronic-circuit, 4 battery, 120 fo-tungsten-plate, 160 plastic-bar | 475 | 1,26 | 352 | 0,74 | 352 | 7 / 56 |
| 11 | 6 | 7 steel-plate, 7 electronic-circuit, 70 battery, 120 fo-tungsten-plate | 678 | 1,43 | 547 | 0,81 | 73 | 5 / 64 |
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
| 7 | 4 | 5 stone-brick, 13 plastic-bar | 23 | 1,21 | 23 | 0,99 | 23 | 2 / 48 |
| 8 | 4 | 6 stone-brick, 16 plastic-bar | 28 | 1,22 | 28 | 0,99 | 28 | 2 / 48 |
| 9 | 5 | 6 stone-brick, 16 fo-tungsten-plate | 44 | 1,57 | 28 | 0,64 | 28 | 2 / 56 |
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
| 7 | 4 | 11 iron-plate, 5 iron-gear-wheel, 4 electronic-circuit, 25 plastic-bar, 2 engine-unit | 74 | 1,47 | 74 | 1 | 74 | 5 / 48 |
| 8 | 4 | 11 iron-plate, 6 iron-gear-wheel, 4 electronic-circuit, 35 plastic-bar, 2 engine-unit | 86 | 1,16 | 86 | 1 | 86 | 5 / 48 |
| 9 | 5 | 12 iron-plate, 6 iron-gear-wheel, 4 electronic-circuit, 35 fo-tungsten-plate, 45 plastic-bar | 149 | 1,73 | 114 | 0,76 | 114 | 5 / 56 |
| 10 | 5 | 13 iron-plate, 7 iron-gear-wheel, 4 electronic-circuit, 40 fo-tungsten-plate, 55 plastic-bar | 172 | 1,15 | 131 | 0,76 | 131 | 5 / 56 |
| 11 | 6 | 14 iron-plate, 7 iron-gear-wheel, 5 electronic-circuit, 20 battery, 40 fo-tungsten-plate | 231 | 1,34 | 188 | 0,81 | 24 | 5 / 64 |
| 12 | 6 | 15 iron-plate, 8 iron-gear-wheel, 5 electronic-circuit, 30 battery, 50 fo-tungsten-plate | 309 | 1,34 | 254 | 0,82 | 32 | 5 / 64 |
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
| 7 | 4 | 4 steel-plate, 5 stone-brick, 25 plastic-bar, 2 engine-unit | 73 | 1,87 | 73 | 1 | 73 | 4 / 48 |
| 8 | 4 | 4 steel-plate, 6 stone-brick, 30 plastic-bar, 2 engine-unit | 80 | 1,1 | 80 | 1 | 80 | 4 / 48 |
| 9 | 5 | 4 steel-plate, 6 stone-brick, 30 fo-tungsten-plate, 35 plastic-bar | 127 | 1,59 | 97 | 0,76 | 97 | 4 / 56 |
| 10 | 5 | 4 steel-plate, 7 stone-brick, 35 fo-tungsten-plate, 45 plastic-bar | 149 | 1,17 | 114 | 0,76 | 114 | 4 / 56 |
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
| 7 | 4 | 11 iron-plate, 5 iron-gear-wheel, 5 electronic-circuit, 25 plastic-bar, 2 engine-unit | 77 | 1,38 | 76 | 1 | 76 | 5 / 48 |
| 8 | 4 | 11 iron-plate, 6 iron-gear-wheel, 6 electronic-circuit, 35 plastic-bar, 2 engine-unit | 91 | 1,19 | 91 | 1 | 91 | 5 / 48 |
| 9 | 5 | 12 iron-plate, 6 iron-gear-wheel, 6 electronic-circuit, 35 fo-tungsten-plate, 45 plastic-bar | 154 | 1,69 | 119 | 0,77 | 119 | 5 / 56 |
| 10 | 5 | 13 iron-plate, 7 iron-gear-wheel, 7 electronic-circuit, 40 fo-tungsten-plate, 55 plastic-bar | 180 | 1,17 | 139 | 0,77 | 139 | 5 / 56 |
| 11 | 6 | 14 iron-plate, 7 iron-gear-wheel, 7 electronic-circuit, 20 battery, 40 fo-tungsten-plate | 236 | 1,31 | 193 | 0,82 | 24 | 5 / 64 |
| 12 | 6 | 15 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 30 battery, 50 fo-tungsten-plate | 316 | 1,34 | 262 | 0,83 | 32 | 5 / 64 |
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
| 4 | 2 h 00 | 29 913 | 2 h 01 | 29 803 | 2 h 00 | 29 803 | 2 h 00 | 29 803 | 2 h 00 |
| 5 | 2 h 30 | 68 160 | 2 h 30 | 53 359 | 1 h 58 | 53 359 | 1 h 58 | 53 359 | 1 h 58 |
| 6 | 3 h 00 | 149 063 | 3 h 00 | 127 923 | 2 h 34 | 78 485 | 1 h 35 | 17 099 | 0 h 21 |
| 7 | 3 h 30 | 318 276 | 3 h 30 | 199 571 | 2 h 12 | 136 757 | 1 h 30 | 24 597 | 0 h 16 |
| 8 | 4 h 00 | 672 074 | 4 h 03 | 532 561 | 3 h 12 | 337 105 | 2 h 02 | 50 090 | 0 h 18 |
| 9 | 4 h 30 | 1 363 663 | 4 h 29 | 1 192 425 | 3 h 55 | 809 912 | 2 h 40 | 96 085 | 0 h 19 |
| 10 | 5 h 00 | 2 782 584 | 5 h 01 | 1 960 897 | 3 h 32 | 517 906 | 0 h 56 | 1 559 | 0 h 00 |
| 11 | 5 h 30 | 5 583 255 | 5 h 30 | 5 817 684 | 5 h 44 | 2 803 560 | 2 h 46 | 8 526 | 0 h 01 |
| 12 | 6 h 00 | 11 217 578 | 6 h 02 | 14 555 666 | 7 h 50 | 3 274 556 | 1 h 46 | 9 959 | 0 h 00 |
| 13 | 6 h 30 | 22 062 378 | 6 h 30 | 21 536 883 | 6 h 21 | 1 174 528 | 0 h 21 | 3 565 | 0 h 00 |
| 14 | 7 h 00 | 43 390 948 | 6 h 59 | 32 219 646 | 5 h 11 | 637 369 | 0 h 06 | 1 938 | 0 h 00 |
| 15 | 7 h 00 | 79 273 586 | 6 h 59 | 48 449 728 | 4 h 16 | 1 221 304 | 0 h 06 | 3 715 | 0 h 00 |
| **Total** | **59 h 30** | | **59 h 34** | | **51 h 46** | | **20 h 46** | | **8 h 13** |

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
| 10 | 86 | 22 016 | 277 | 3 538 400 | 9 259 223 | 38,2 % | dans la fourchette |
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
| 4 | 6,25 | 3 310 | 1 | × 1 | 6,3 | 3 310 | 1 |
| 5 | 15,5 | 5 000 | 0,78 | × 1 | 15,5 | 5 000 | 1 |
| 6 | 29 | 6 160 | 0,86 | × 7,48 | 220 | 46 100 | 5,4 |
| 7 | 57,3 | 6 290 | 0,63 | × 8,11 | 460 | 51 000 | 1 |
| 8 | 110 | 6 380 | 0,79 | × 10,63 | 1 170 | 67 800 | 10 |
| 9 | 204 | 14 100 | 0,87 | × 12,41 | 2 530 | 175 000 | 11,8 |
| 10 | 365 | 65 000 | 0,7 | × 1258,08 | 459 200 | 8,2 × 10^7 | 45 |
| 11 | 687 | 66 300 | 1,04 | × 682,34 | 468 800 | 4,5 × 10^7 | 25 |
| 12 | 1250 | 100 000 | 1,3 | × 1461,55 | 1 826 900 | 1,5 × 10^8 | 80 |
| 13 | 2260 | 150 000 | 0,98 | × 6041,08 | 1,4 × 10^7 | 9,1 × 10^8 | 35 |
| 14 | 4140 | 190 000 | 0,74 | × 1,7 × 10^4 | 6,9 × 10^7 | 3,2 × 10^9 | 100 |
| 15 | 7070 | 0 | 0,61 | × 1,3 × 10^4 | 9,2 × 10^7 | 0 | 130 |

Lecture : sous H2, l'époque e est payée « Gain H2 » fois plus vite qu'en H0 ; (A) remet chaque époque à sa durée X0 en multipliant
valeur d'époque et passage du centre par ce gain (les quantités affichées grandissent d'autant : la règle de place du coffre est alors
à revérifier, `levels_test`). La dernière colonne aligne la valeur déclarée des monnaies sur leur coût réel (règle du modèle : « valeur
de l'objet en unités de matière brute ») ; elle ne change ni `value_mult` ni le calendrier, seulement les QUANTITÉS demandées.
