# Base de motifs industriels (lot MOTIFS)

Généré par `lua5.2 tools/motifs_doc.lua > docs/MOTIFS.md` : ne pas modifier à la main (la source est `shared/team/motifs/`).

Demande du DC (8/11, vers 18 h 45) : des blocs compacts, équilibrés en entrées/sorties, strictement duplicables (coller les modules en série de gauche à droite ou de haut en bas) ; une base classée par taille, nombre d'entrées (n), de sorties (m) et modularité, que les scripts de placement INTERROGENT pour choisir et adapter le motif au terrain.

## Comment c'est fait

- Un **motif** est une **tuile** répétable le long d'un axe (période, emprise l × h). Ses pièces sont décrites par **rôle** (`machine_fonte`, `machine_asm`, `bras`, `bras_long`, `tapis_entree`, `tapis_sortie`, `repartiteur`, `souterrain_*`, `poteau`, `tuyau`, `tuyau_souterrain`, `coffre`, `foreuse`, `chevalet`…), **jamais par nom d'objet** : la correspondance rôle → prototype se fait en jeu, d'après les prototypes lus (vitesses, tailles, portée des bras).
- **Orientations** : la répétition est écrite de gauche à droite ; `catalogue.instancier(id, n, { rot, miroir })` donne les 8 orientations (4 quarts de tour × miroir), donc aussi « de haut en bas ».
- **Sélection** : `choix.lua` (`Choix.choisir`) reçoit le terrain (rectangle libre, obstacles, ou carte de tuiles libres), la demande (jeton et débit, ou nombre de voies, ou entrées et sorties d'un équilibreur), les entrées disponibles (côté, position, ce qu'elles portent), et ce que le client a lu aux prototypes. Elle rend le motif, le nombre de tuiles qui **tient et suffit**, l'orientation, le rectangle réservé, le débit, et la **cause** de chaque motif écarté.
- **Vérification** : `lua5.2 tests/motifs_test.lua` (cohérence de chaque motif, orientations, équilibreurs par suivi de flux, 25 terrains de sélection, coût en instructions, mutants).
- **Honnêteté sur l'origine** : `ref_dc` = transcrit des 4 images du DC ; `forum` / `wiki` = la logique du motif vient de la source citée (page lue par résumé de recherche, pas de blueprint copié) ; `derive` = géométrie déduite par nous. Dans tous les cas les coordonnées sont les nôtres, vérifiées hors jeu ; **rien n'est prouvé en moteur réel** (aucun banc lancé par ce lot).

Lecture des dessins : `>` `<` `^` `v` tapis (sens de la marche) ; `n` `e` `s` `o` bras (côté de PRISE ; majuscule = bras long) ; `u` `U` entrée / sortie de tapis souterrain ; `=` répartiteur ; `+` poteau ; `~` tuyau ; `t` tuyau souterrain ; `#` coffre ; `A…Z` machines.

## Les 4 références du DC (en tête)

| Image | Motif | Ce qu'on y a lu |
|---|---|---|
| `Fonderie.png` | `fonte-2x2-double-central` | colonne de fours doubles, tapis central partagé, sorties en haut et en bas, répétée de gauche à droite |
| `Mall1.png` | `asm-grille-3-directe` | grille 3 × N : trois machines par colonne, insertion directe, sortie en coffre ; chaque colonne peut changer de recette |
| `Patern1.png` | `asm-2e-1s` | la tuile élémentaire : un assembleur entre deux tapis d'entrée (bras court, bras long) et un tapis de sortie |
| `Patern_Mall2.png` | `asm-cable-circuit-3-2-double` (et `-simple`) | 3 machines de câble pour 2 de circuits en insertion directe, entre cuivre, fer et sortie |

## Classement

Débit estimé par tuile : recettes de base, bras de base (0,83 et 1,15 objet/s, sans bonus de pile), voie de tapis jaune. **Estimation** calculée par `Choix.debit`, jamais mesurée en jeu.

| Motif | Famille | Tuile l × h | Entrées n | Sorties m | Modularité | Machines / tuile | Débit estimé / tuile | Origine |
|---|---|---|---|---|---|---|---|---|
| `asm-1e-1s` | asm | 4 × 7 | 1 | 1 | série (x ou y) | 1 | 0.63 engrenages/s (0,5 s, 2 plaques) | derive |
| `asm-2e-1s` | asm | 4 × 8 | 2 | 1 | série (x ou y) | 1 | 0.63 objets/s (recette 0,5 s, machine 0,75) | ref_dc |
| `asm-3e-1s` | asm | 4 × 9 | 3 | 1 | série (x ou y) | 1 | 0.63 objets/s (recette 0,5 s, machine 0,75) | derive |
| `asm-miroir-2e` | asm | 4 × 14 | 2 | 2 | série (x ou y) | 2 | 1.27 objets/s (recette 0,5 s, machine 0,75) | derive |
| `asm-miroir-2e-coffres` | asm | 4 × 14 | 2 | 1 | série (x ou y) | 2 | (voir la règle cliente) | ref_dc |
| `asm-chaine-1-1` | asm | 8 × 8 | 2 | 1 | série (x ou y) | 2 | (voir la règle cliente) | derive |
| `asm-grille-3-directe` | asm | 5 × 15 | 2 | 1 | série (x ou y) | 3 | (voir la règle cliente) | ref_dc |
| `asm-chaine-1-2` | asm | 12 × 8 | 2 | 1 | série (x ou y) | 3 | (voir la règle cliente) | derive |
| `asm-cable-circuit-3-2-simple` | asm | 9 × 12 | 2 | 1 | série (x ou y) | 5 | 1.49 circuits/s | ref_dc |
| `asm-cable-circuit-3-2-double` | asm | 9 × 22 | 3 | 1 | série (x ou y) | 10 | 2.99 circuits/s | ref_dc |
| `bus-4-voies` | bus | 1 × 4 | 4 | 0 | série (x ou y) | 0 | (voir la règle cliente) | wiki |
| `bus-8-voies` | bus | 1 × 8 | 8 | 0 | série (x ou y) | 0 | (voir la règle cliente) | wiki |
| `bus-piquage-voie-exterieure` | bus | 6 × 8 | 4 | 5 | tuile unique | 0 | (voir la règle cliente) | wiki |
| `chimie-rangee-1f-1e-1s` | chimie | 3 × 8 | 2 | 1 | série (x ou y) | 1 | (voir la règle cliente) | derive |
| `chimie-rangee-2f-sortie` | chimie | 4 × 7 | 2 | 1 | série (x ou y) | 1 | (voir la règle cliente) | derive |
| `chimie-rangee-2f-1e-1s` | chimie | 4 × 8 | 3 | 1 | série (x ou y) | 1 | (voir la règle cliente) | derive |
| `centrale-vapeur-rangee` | energie | 4 × 14 | 2 | 1 | série (x ou y) | 3 | 1800.00 kW | derive |
| `equilibreur-1-2` | equilibreur | 3 × 2 | 1 | 2 | tuile unique | 0 | (voir la règle cliente) | wiki |
| `equilibreur-2-2` | equilibreur | 3 × 2 | 2 | 2 | tuile unique | 0 | (voir la règle cliente) | wiki |
| `equilibreur-1-4` | equilibreur | 5 × 4 | 1 | 4 | tuile unique | 0 | (voir la règle cliente) | wiki |
| `equilibreur-2-4` | equilibreur | 5 × 4 | 2 | 4 | tuile unique | 0 | (voir la règle cliente) | wiki |
| `equilibreur-4-4` | equilibreur | 10 × 5 | 4 | 4 | tuile unique | 0 | (voir la règle cliente) | wiki |
| `fonte-2x2-simple` | fonte | 4 × 6 | 1 | 1 | série (x ou y) | 2 | 0.62 plaques/s (four de pierre) | forum |
| `fonte-3x3-simple` | fonte | 6 × 7 | 1 | 1 | série (x ou y) | 2 | 1.25 plaques/s (four électrique) | derive |
| `fonte-2x2-double-central` | fonte | 4 × 11 | 1 | 2 | série (x ou y) | 4 | 1.25 plaques/s (four de pierre) | ref_dc |
| `fonte-2x2-double-central-fusion` | fonte | 4 × 11 | 1 | 1 | série (x ou y) | 4 | (voir la règle cliente) | ref_dc |
| `fonte-2x2-double-sortie-centrale` | fonte | 4 × 11 | 2 | 1 | série (x ou y) | 4 | 1.25 plaques/s (four de pierre) | forum |
| `fonte-chaine-directe-3x3` | fonte | 6 × 11 | 1 | 1 | série (x ou y) | 4 | (voir la règle cliente) | forum |
| `fonte-3x3-double-central` | fonte | 6 × 13 | 1 | 2 | série (x ou y) | 4 | 2.50 plaques/s (four électrique) | derive |
| `fonte-3x3-double-central-fusion` | fonte | 6 × 13 | 1 | 1 | série (x ou y) | 4 | (voir la règle cliente) | ref_dc |
| `fonte-3x3-double-sortie-centrale` | fonte | 6 × 13 | 2 | 1 | série (x ou y) | 4 | 2.50 plaques/s (four électrique) | derive |
| `labo-chaine-bras` | labo | 4 × 5 | 1 | 1 | série (x ou y) | 1 | (voir la règle cliente) | derive |
| `labo-rangee-tapis` | labo | 4 × 5 | 1 | 1 | série (x ou y) | 1 | 0.03 unités de recherche/s (30 s) | derive |
| `labo-rangee-miroir` | labo | 4 × 9 | 1 | 1 | série (x ou y) | 2 | 0.07 unités de recherche/s (30 s) | derive |
| `foreuses-2x2-combustion-2xN` | mine | 2 × 5 | 0 | 1 | série (x ou y) | 2 | 0.50 minerai/s (foreuse à combustion) | forum |
| `foreuses-boucle-charbon` | mine | 6 × 2 | 0 | 1 | série (x ou y) | 2 | 0.50 charbon/s brut (foreuse à combustion) | derive |
| `foreuses-3x3-simple-face` | mine | 4 × 4 | 0 | 1 | série (x ou y) | 1 | 0.50 minerai/s (foreuse électrique) | forum |
| `foreuses-2xN-tapis-central` | mine | 7 × 7 | 0 | 1 | série (x ou y) | 4 | 2.00 minerai/s (foreuse électrique) | forum |
| `chevalets-ligne` | petrole | 3 × 5 | 0 | 1 | série (x ou y) | 1 | (voir la règle cliente) | forum |
| `chevalets-double` | petrole | 3 × 9 | 0 | 1 | série (x ou y) | 2 | (voir la règle cliente) | forum |
| `raffinerie-rangee-base` | petrole | 5 × 9 | 1 | 1 | série (x ou y) | 1 | (voir la règle cliente) | derive |
| `packs-rouges-rangee` | science | 4 × 7 | 2 | 1 | série (x ou y) | 2 | (voir la règle cliente) | derive |
| `packs-verts-rangee` | science | 4 × 9 | 2 | 1 | série (x ou y) | 3 | (voir la règle cliente) | derive |

43 motifs : asm 10, bus 3, chimie 3, energie 1, equilibreur 5, fonte 9, labo 3, mine 4, petrole 3, science 2.

## Ratios usuels (calculés, jamais écrits dans le catalogue)

`Choix.rapport(amont, aval, jeton)` donne le nombre de machines amont par machine aval d'après les recettes et les vitesses lues en jeu ; `Choix.bras_necessaires` et `Choix.machines_par_voie` donnent les bras et les machines par voie de tapis. Valeurs pour les recettes de base à vitesses égales :

| Liaison | Données de recette | Ratio amont : aval | Motif qui le réalise |
|---|---|---|---|
| engrenage → pack rouge | 0,5 s, 1 engrenage ; 5 s, 1 engrenage | 0.10 (1 : 10) | aucun en insertion directe : `asm-chaine-1-2` ne fait que 1 : 2 (l'amont tournerait à 20 %) ; passer par un tapis d'engrenages (`asm-2e-1s`, `asm-miroir-2e`) |
| câble → circuit | 0,5 s, 2 câbles ; 0,5 s, 3 câbles | 1.50 (3 : 2) | `asm-cable-circuit-3-2-simple`, `asm-cable-circuit-3-2-double` |
| plaque → acier | 3,2 s, 1 plaque ; 16 s, 5 plaques | 1.00 (1 : 1) | `fonte-chaine-directe-3x3` |
| four de plaques → machine d'engrenages (vitesse 2 → 0,75) | 3,2 s, 1 plaque ; 0,5 s, 2 plaques | 4.80 | tapis (aucun motif en insertion directe) |

Un bras de base (0,83 objet/s) qui prend sur un tapis porte 0,83 × 0,85 × 0,9 = 0,635 objet/s : un four d'acier (0,625 objet/s de plaques) l'occupe presque entièrement. Une voie de tapis jaune (7,5 objets/s) nourrit 12 fours d'acier ou 24 fours de pierre.

## Les motifs

### `asm-1e-1s` : Tuile d'assemblage à 1 entrée, 1 sortie

Famille **asm**, usages : mall, assemblage, engrenage. Origine : **derive**. Tuile 4 × 7, période 4, répétable en série, 1 entrée(s), 1 sortie(s), 1 machine(s) par tuile.

Un assembleur entre un tapis d'entrée au nord et un tapis de sortie au sud ; deux bras de chaque côté.

Pièces d'une tuile : bras ×4, machine_asm ×1, poteau ×1, tapis_entree ×4, tapis_sortie ×4.
Place minimale : 4 × 7 (une tuile). Doit rester droit : tapis_entree:1 (rangée 0), tapis_sortie:1 (rangée 6).

```
>>>>>>>>
.nn..nn.
AAA.BBB.
AAA+BBB+
AAA.BBB.
.nn..nn.
>>>>>>>>
```

Sources : https://wiki.factorio.com/Inserters ; https://wiki.factorio.com/Tutorial:Main_bus

### `asm-2e-1s` : Tuile d'assemblage à 2 entrées, 1 sortie (référence du DC)

Famille **asm**, usages : mall, assemblage, tapis. Origine : **ref_dc** (Patern1.png). Tuile 4 × 8, période 4, répétable en série, 2 entrée(s), 1 sortie(s), 1 machine(s) par tuile.

Référence du DC : un assembleur entre deux tapis d'entrée en haut (bras court sur le premier, bras long vers le second) et un tapis de sortie en bas ; poteau dans la case libre.

Pièces d'une tuile : bras ×2, bras_long ×1, machine_asm ×1, poteau ×1, tapis_entree ×8, tapis_sortie ×4.
Place minimale : 4 × 8 (une tuile). Doit rester droit : tapis_entree:2 (rangée 0), tapis_entree:1 (rangée 1), tapis_sortie:1 (rangée 7).

```
>>>>>>>>
>>>>>>>>
.Nn..Nn.
AAA.BBB.
AAA+BBB+
AAA.BBB.
..n...n.
>>>>>>>>
```

Sources : https://wiki.factorio.com/Inserters ; https://wiki.factorio.com/Tutorial:Main_bus

### `asm-3e-1s` : Tuile d'assemblage à 3 entrées, 1 sortie

Famille **asm**, usages : mall, assemblage, bras. Origine : **derive**. Tuile 4 × 9, période 4, répétable en série, 3 entrée(s), 1 sortie(s), 1 machine(s) par tuile.

Deux tapis d'entrée au nord (bras court, bras long) ; au sud, le troisième tapis d'entrée contre la machine et le tapis de sortie derrière lui (bras long de sortie qui passe par-dessus).

Pièces d'une tuile : bras ×2, bras_long ×2, machine_asm ×1, poteau ×1, tapis_entree ×12, tapis_sortie ×4.
Place minimale : 4 × 9 (une tuile). Doit rester droit : tapis_entree:2 (rangée 0), tapis_entree:1 (rangée 1), tapis_entree:3 (rangée 7), tapis_sortie:1 (rangée 8).

```
>>>>>>>>
>>>>>>>>
.Nn..Nn.
AAA.BBB.
AAA+BBB+
AAA.BBB.
.Ns..Ns.
>>>>>>>>
>>>>>>>>
```

Sources : https://wiki.factorio.com/Inserters ; https://wiki.factorio.com/Tutorial:Main_bus

### `asm-miroir-2e` : Deux rangées d'assembleurs en miroir sur 2 tapis d'entrée centraux

Famille **asm**, usages : mall, assemblage. Origine : **derive**. Tuile 4 × 14, période 4, répétable en série, 2 entrée(s), 2 sortie(s), 2 machine(s) par tuile.

Deux tapis d'entrée au milieu, un assembleur au nord et un au sud par tuile, sorties sur les tapis extérieurs : densité maximale pour une recette à 2 entrées.

Pièces d'une tuile : bras ×4, bras_long ×2, machine_asm ×2, poteau ×2, tapis_entree ×8, tapis_sortie ×8.
Place minimale : 4 × 14 (une tuile). Doit rester droit : tapis_sortie:1 (rangée 0), tapis_entree:1 (rangée 6), tapis_entree:2 (rangée 7), tapis_sortie:2 (rangée 13).

```
>>>>>>>>
..s...s.
AAA.CCC.
AAA+CCC+
AAA.CCC.
.Ss..Ss.
>>>>>>>>
>>>>>>>>
.Nn..Nn.
BBB.DDD.
BBB+DDD+
BBB.DDD.
..n...n.
>>>>>>>>
```

Sources : https://wiki.factorio.com/Inserters ; https://wiki.factorio.com/Tutorial:Main_bus

### `asm-miroir-2e-coffres` : Deux rangées d'assembleurs en miroir, sortie en coffres (mall à 4 voies)

Famille **asm**, usages : mall, assemblage, coffres. Origine : **ref_dc** (Mall1.png). Tuile 4 × 14, période 4, répétable en série, 2 entrée(s), 1 sortie(s), 2 machine(s) par tuile.

Comme asm-miroir-2e, mais chaque machine dépose son produit dans SON coffre (côté extérieur) au lieu d'un tapis de sortie : des produits tous différents ne se mêlent pas. Deux tapis d'entrée au centre portent chacun DEUX objets, un par voie (A, B sur le premier ; C, D sur le second) ; chaque machine a un bras court et un bras long. Les deux machines d'une tuile ont chacune leur recette (groupes « haut » et « bas »).

Pièces d'une tuile : bras ×4, bras_long ×2, coffre ×2, machine_asm ×2, poteau ×2, tapis_entree ×8.
Place minimale : 4 × 14 (une tuile). Doit rester droit : tapis_entree:1 (rangée 6), tapis_entree:2 (rangée 7).

```
..#...#.
..s...s.
AAA.CCC.
AAA+CCC+
AAA.CCC.
.Ss..Ss.
>>>>>>>>
>>>>>>>>
.Nn..Nn.
BBB.DDD.
BBB+DDD+
BBB.DDD.
..n...n.
..#...#.
```

Sources : https://wiki.factorio.com/Inserters ; https://wiki.factorio.com/Tutorial:Main_bus

### `asm-chaine-1-1` : Chaîne d'assembleurs 1 → 1, insertion directe

Famille **asm**, usages : chaine, mall. Origine : **derive**. Tuile 8 × 8, période 8, répétable en série, 2 entrée(s), 1 sortie(s), 2 machine(s) par tuile.

L'assembleur amont prend la matière A et passe son produit à l'assembleur aval par un bras ; l'aval prend B (bras long) et sort le produit.

Pièces d'une tuile : bras ×3, bras_long ×1, machine_asm ×2, poteau ×2, tapis_entree ×16, tapis_sortie ×8.
Place minimale : 8 × 8 (une tuile). Doit rester droit : tapis_entree:2 (rangée 0), tapis_entree:1 (rangée 1), tapis_sortie:1 (rangée 7).

```
>>>>>>>>>>>>>>>>
>>>>>>>>>>>>>>>>
.n...N...n...N..
AAA+BBB.CCC+DDD.
AAAoBBB.CCCoDDD.
AAA.BBB+CCC.DDD+
.....n.......n..
>>>>>>>>>>>>>>>>
```

Sources : https://wiki.factorio.com/Inserters ; https://wiki.factorio.com/Tutorial:Main_bus

### `asm-grille-3-directe` : Colonne de 3 assembleurs à insertion directe (grille 3 × N)

Famille **asm**, usages : mall, chaine. Origine : **ref_dc** (Mall1.png). Tuile 5 × 15, période 5, répétable en série, 2 entrée(s), 1 sortie(s), 3 machine(s) par tuile.

Référence du DC : chaque colonne de la grille porte 3 machines ; la machine du haut et celle du bas prennent chacune sur un tapis d'entrée (haut, bas) et passent leur produit à celle du milieu par insertion directe ; la machine du milieu dépose son produit dans un coffre (quai). Les colonnes se collent de gauche à droite, chacune pouvant faire une recette différente.

Pièces d'une tuile : bras ×5, coffre ×1, machine_asm ×3, poteau ×4, tapis_entree ×10.
Place minimale : 5 × 15 (une tuile). Doit rester droit : tapis_entree:1 (rangée 0), tapis_entree:2 (rangée 14).

```
>>>>>>>>>>
.n.+..n.+.
AAA..DDD..
AAA..DDD..
AAA..DDD..
.n.+..n.+.
BBB..EEE..
BBBo#EEEo#
BBB..EEE..
.s.+..s.+.
CCC..FFF..
CCC..FFF..
CCC..FFF..
.s.+..s.+.
>>>>>>>>>>
```

Sources : https://wiki.factorio.com/Inserters ; https://wiki.factorio.com/Tutorial:Main_bus

### `asm-chaine-1-2` : Chaîne d'assembleurs 1 → 2, insertion directe

Famille **asm**, usages : chaine, mall. Origine : **derive**. Tuile 12 × 8, période 12, répétable en série, 2 entrée(s), 1 sortie(s), 3 machine(s) par tuile.

Un assembleur amont au milieu nourrit directement ses deux voisins aval, à gauche et à droite.

Pièces d'une tuile : bras ×5, bras_long ×2, machine_asm ×3, poteau ×5, tapis_entree ×24, tapis_sortie ×12.
Place minimale : 12 × 8 (une tuile). Doit rester droit : tapis_entree:2 (rangée 0), tapis_entree:1 (rangée 1), tapis_sortie:1 (rangée 7).

```
>>>>>>>>>>>>>>>>>>>>>>>>
>>>>>>>>>>>>>>>>>>>>>>>>
.N...n...N...N...n...N..
AAA+BBB+CCC+DDD+EEE+FFF+
AAAeBBBoCCC.DDDeEEEoFFF.
AAA+BBB+CCC.DDD+EEE+FFF.
.n.......n...n.......n..
>>>>>>>>>>>>>>>>>>>>>>>>
```

Sources : https://wiki.factorio.com/Inserters ; https://wiki.factorio.com/Tutorial:Main_bus

### `asm-cable-circuit-3-2-simple` : Circuits : 3 machines de câble pour 2 de circuits, une face

Famille **asm**, usages : circuits, chaine. Origine : **ref_dc** (Patern_Mall2.png). Tuile 9 × 12, période 9, répétable en série, 2 entrée(s), 1 sortie(s), 5 machine(s) par tuile.

Moitié haute de la référence du DC : un tapis de cuivre, 3 machines amont, 2 machines aval, un tapis de fer et un tapis de sortie.

Pièces d'une tuile : bras ×16, bras_long ×2, machine_asm ×5, poteau ×8, tapis_entree ×18, tapis_sortie ×9.
Place minimale : 9 × 12 (une tuile). Doit rester droit : tapis_entree:1 (rangée 0), tapis_entree:2 (rangée 10), tapis_sortie:1 (rangée 11).

```
>>>>>>>>>>>>>>>>>>
nn+nn.nn+nn+nn.nn+
AAABBBCCCFFFGGGHHH
AAABBBCCCFFFGGGHHH
AAABBBCCCFFFGGGHHH
+nnn+nnn++nnn+nnn+
.DDD.EEE..III.JJJ.
.DDD.EEE..III.JJJ.
.DDD.EEE..III.JJJ.
+ssN+ssN++ssN+ssN+
>>>>>>>>>>>>>>>>>>
>>>>>>>>>>>>>>>>>>
```

Sources : https://wiki.factorio.com/Electronic_circuit ; https://wiki.factorio.com/Green_circuit ; https://forums.factorio.com/viewtopic.php?p=62228 ; https://forums.factorio.com/viewtopic.php?p=204665

### `asm-cable-circuit-3-2-double` : Circuits : 3 machines de câble pour 2 de circuits, double face

Famille **asm**, usages : circuits, chaine. Origine : **ref_dc** (Patern_Mall2.png). Tuile 9 × 22, période 9, répétable en série, 3 entrée(s), 1 sortie(s), 10 machine(s) par tuile.

Référence du DC : un tapis de cuivre en haut, un en bas, deux tapis au centre (fer, sortie). Par tuile et par face : 3 machines amont qui alimentent par insertion directe 2 machines aval (la machine amont du milieu sert les deux). Rapport 3:2 de la recette amont à une machine par unité de temps égale ; 6 amont et 4 aval par tuile.

Pièces d'une tuile : bras ×30, bras_long ×6, machine_asm ×10, poteau ×16, tapis_entree ×27, tapis_sortie ×9.
Place minimale : 9 × 22 (une tuile). Doit rester droit : tapis_entree:1 (rangée 0), tapis_entree:2 (rangée 10), tapis_sortie:1 (rangée 11), tapis_entree:3 (rangée 21).

```
>>>>>>>>>>>>>>>>>>
nn+nn.nn+nn+nn.nn+
AAABBBCCCKKKLLLMMM
AAABBBCCCKKKLLLMMM
AAABBBCCCKKKLLLMMM
+nnn+nnn++nnn+nnn+
.DDD.EEE..NNN.OOO.
.DDD.EEE..NNN.OOO.
.DDD.EEE..NNN.OOO.
+ssN+ssN++ssN+ssN+
>>>>>>>>>>>>>>>>>>
>>>>>>>>>>>>>>>>>>
+NNs+NNs++NNs+NNs+
.FFF.GGG..PPP.QQQ.
.FFF.GGG..PPP.QQQ.
.FFF.GGG..PPP.QQQ.
+sss+sss++sss+sss+
HHHIIIJJJRRRSSSTTT
HHHIIIJJJRRRSSSTTT
HHHIIIJJJRRRSSSTTT
ss+ss.ss+ss+ss.ss+
>>>>>>>>>>>>>>>>>>
```

Sources : https://wiki.factorio.com/Electronic_circuit ; https://wiki.factorio.com/Green_circuit ; https://forums.factorio.com/viewtopic.php?p=62228 ; https://forums.factorio.com/viewtopic.php?p=204665

### `bus-4-voies` : Bus de 4 voies

Famille **bus**, usages : bus. Origine : **wiki**. Tuile 1 × 4, période 1, répétable en série, 4 entrée(s), 0 sortie(s), 0 machine(s) par tuile.

Voies de bus parallèles, une case de large par tuile : se prolonge à volonté ; aucune machine, aucun poteau.

Pièces d'une tuile : tapis_entree ×4.
Place minimale : 1 × 4 (une tuile). Doit rester droit : tapis_entree:1 (rangée 0), tapis_entree:2 (rangée 1), tapis_entree:3 (rangée 2), tapis_entree:4 (rangée 3).

```
>>
>>
>>
>>
```

Sources : https://wiki.factorio.com/Tutorial:Main_bus ; https://wiki.factorio.com/Balancers ; https://wiki.factorio.com/Transport_belts/Physics

### `bus-8-voies` : Bus de 8 voies

Famille **bus**, usages : bus. Origine : **wiki**. Tuile 1 × 8, période 1, répétable en série, 8 entrée(s), 0 sortie(s), 0 machine(s) par tuile.

Voies de bus parallèles, une case de large par tuile : se prolonge à volonté ; aucune machine, aucun poteau.

Pièces d'une tuile : tapis_entree ×8.
Place minimale : 1 × 8 (une tuile). Doit rester droit : tapis_entree:1 (rangée 0), tapis_entree:2 (rangée 1), tapis_entree:3 (rangée 2), tapis_entree:4 (rangée 3), tapis_entree:5 (rangée 4), tapis_entree:6 (rangée 5), tapis_entree:7 (rangée 6), tapis_entree:8 (rangée 7).

```
>>
>>
>>
>>
>>
>>
>>
>>
```

Sources : https://wiki.factorio.com/Tutorial:Main_bus ; https://wiki.factorio.com/Balancers ; https://wiki.factorio.com/Transport_belts/Physics

### `bus-piquage-voie-exterieure` : Bus de 4 voies avec piquage de la voie extérieure

Famille **bus**, usages : bus, piquage. Origine : **wiki**. Tuile 6 × 8, période 6, tuile unique, 4 entrée(s), 5 sortie(s), 0 machine(s) par tuile.

Un répartiteur sur la 4e voie : la moitié continue dans le bus, l'autre moitié part vers le sud par un tapis qui tourne. Les trois autres voies passent droit. Tuile unique.

Pièces d'une tuile : repartiteur ×1, tapis ×19, tapis_entree ×4, tapis_sortie ×5.
Place minimale : 6 × 8 (une tuile). Doit rester droit : rien sur toute la largeur.

```
>>>>>>
>>>>>>
>>>>>>
>=>>>>
.=>v..
...v..
...v..
...v..
```

Sources : https://wiki.factorio.com/Tutorial:Main_bus

### `chimie-rangee-1f-1e-1s` : Rangée d'usines chimiques, 1 fluide, 1 entrée solide, 1 sortie solide

Famille **chimie**, usages : chimie, plastique. Origine : **derive**. Tuile 3 × 8, période 3, répétable en série, 2 entrée(s), 1 sortie(s), 1 machine(s) par tuile.

Une conduite au nord (un seul fluide : aucun risque de mélange), usines jointives (période 3), tapis d'entrée solide puis tapis de sortie au sud.

Pièces d'une tuile : bras ×1, bras_long ×1, machine_chimie ×1, poteau ×1, tapis_entree ×3, tapis_sortie ×3, tuyau ×4.
Place minimale : 3 × 8 (une tuile). Doit rester droit : tapis_entree:1 (rangée 6), tapis_sortie:1 (rangée 7).

```
~~~~~~
~..~..
AAABBB
AAABBB
AAABBB
sN+sN+
>>>>>>
>>>>>>
```

Sources : https://wiki.factorio.com/Chemical_plant ; https://wiki.factorio.com/Oil_processing

### `chimie-rangee-2f-sortie` : Rangée d'usines chimiques, 2 fluides, sortie solide

Famille **chimie**, usages : chimie, soufre. Origine : **derive**. Tuile 4 × 7, période 4, répétable en série, 2 entrée(s), 1 sortie(s), 1 machine(s) par tuile.

Deux fluides arrivent par le nord (F1 rangée 0, F2 rangée 1) sans se toucher grâce aux tuyaux souterrains ; produit solide sorti par bras sur un tapis au sud. Période 4 (3 de machine, 1 de passage).

Pièces d'une tuile : bras ×2, machine_chimie ×1, poteau ×1, tapis_sortie ×4, tuyau ×3, tuyau_souterrain ×4.
Place minimale : 8 × 7 (une tuile, tête et queue comprises). Doit rester droit : tapis_sortie:1 (rangée 6).

```
.~~t.t~t.t..
~t~t~t~t~t.t
..AAA.BBB...
..AAA.BBB...
..AAA.BBB...
..nn+.nn+...
>>>>>>>>>>>>
```

Sources : https://wiki.factorio.com/Chemical_plant ; https://wiki.factorio.com/Oil_processing

### `chimie-rangee-2f-1e-1s` : Rangée d'usines chimiques, 2 fluides, 1 entrée solide, 1 sortie solide

Famille **chimie**, usages : chimie. Origine : **derive**. Tuile 4 × 8, période 4, répétable en série, 3 entrée(s), 1 sortie(s), 1 machine(s) par tuile.

Comme la rangée à 2 fluides, avec un tapis d'entrée solide contre les machines (bras court) et le tapis de sortie derrière (bras long).

Pièces d'une tuile : bras ×1, bras_long ×1, machine_chimie ×1, poteau ×1, tapis_entree ×4, tapis_sortie ×4, tuyau ×3, tuyau_souterrain ×4.
Place minimale : 8 × 8 (une tuile, tête et queue comprises). Doit rester droit : tapis_entree:1 (rangée 6), tapis_sortie:1 (rangée 7).

```
.~~t.t~t.t..
~t~t~t~t~t.t
..AAA.BBB...
..AAA.BBB...
..AAA.BBB...
..sN+.sN+...
>>>>>>>>>>>>
>>>>>>>>>>>>
```

Sources : https://wiki.factorio.com/Chemical_plant ; https://wiki.factorio.com/Oil_processing

### `centrale-vapeur-rangee` : Centrale à vapeur extensible : pompe, chaudières, machines à vapeur (1 : 2)

Famille **energie**, usages : energie, vapeur. Origine : **derive**. Tuile 4 × 14, période 4, répétable en série, 2 entrée(s), 1 sortie(s), 3 machine(s) par tuile.

Même disposition que le gabarit « centrale » de modules.lua, en tuiles : une chaudière 3 × 2 et, au-dessus, deux machines à vapeur 3 × 5 empilées (la vapeur passe par contact) ; l'eau traverse les chaudières par un tuyau dans le passage de la tuile ; la pompe de rive est dans la tête (à l'ouest, sur le raccord d'eau de la première chaudière) ; deux bras à combustion par chaudière prennent le charbon sur un tapis qui entre à l'est. Une tuile : 1,8 MW. Une pompe alimente 20 chaudières au plus (1 200 / 60 par seconde).

Pièces d'une tuile : bras ×2, chaudiere ×1, machine_vapeur ×2, pompe ×0, poteau ×2, tapis_entree ×4, tuyau ×1.
Place minimale : 5 × 14 (une tuile, tête et queue comprises). Doit rester droit : rien sur toute la largeur.

```
.BBB.EEE.
.BBB.EEE.
.BBB+EEE+
.BBB.EEE.
.BBB.EEE.
.CCC.FFF.
.CCC.FFF.
.CCC+FFF+
.CCC.FFF.
.CCC.FFF.
.DDD.GGG.
ADDD~GGG~
.s.s.s.s.
<<<<<<<<<
```

Sources : https://wiki.factorio.com/Steam_engine ; https://wiki.factorio.com/Boiler ; https://wiki.factorio.com/Offshore_pump ; https://wiki.factorio.com/Power_production

### `equilibreur-1-2` : Répartiteur 1 vers 2

Famille **equilibreur**, usages : equilibreur, repartition. Origine : **wiki**. Tuile 3 × 2, période 3, tuile unique, 1 entrée(s), 2 sortie(s), 0 machine(s) par tuile.

Un répartiteur : une voie d'entrée, deux voies de sortie à parts égales.

Pièces d'une tuile : repartiteur ×1, tapis_entree ×1, tapis_sortie ×2.
Place minimale : 3 × 2 (une tuile). Doit rester droit : rien sur toute la largeur.

```
>=>
.=>
```

Sources : https://wiki.factorio.com/Balancers ; https://forums.factorio.com/viewtopic.php?p=425342

### `equilibreur-2-2` : Équilibreur 2 vers 2

Famille **equilibreur**, usages : equilibreur, repartition. Origine : **wiki**. Tuile 3 × 2, période 3, tuile unique, 2 entrée(s), 2 sortie(s), 0 machine(s) par tuile.

Un répartiteur à deux entrées et deux sorties : égalise les deux tapis (une sortie bloquée reporte tout sur l'autre).

Pièces d'une tuile : repartiteur ×1, tapis_entree ×2, tapis_sortie ×2.
Place minimale : 3 × 2 (une tuile). Doit rester droit : rien sur toute la largeur.

```
>=>
>=>
```

Sources : https://wiki.factorio.com/Balancers ; https://forums.factorio.com/viewtopic.php?p=425342

### `equilibreur-1-4` : Arbre 1 vers 4

Famille **equilibreur**, usages : equilibreur, repartition. Origine : **wiki**. Tuile 5 × 4, période 5, tuile unique, 1 entrée(s), 4 sortie(s), 0 machine(s) par tuile.

Trois répartiteurs en arbre plan (1 puis 2) : une entrée, quatre sorties égales.

Pièces d'une tuile : repartiteur ×3, tapis ×2, tapis_entree ×1, tapis_sortie ×4.
Place minimale : 5 × 4 (une tuile). Doit rester droit : rien sur toute la largeur.

```
...=>
>=>=>
.=>=>
...=>
```

Sources : https://wiki.factorio.com/Balancers ; https://forums.factorio.com/viewtopic.php?p=425342

### `equilibreur-2-4` : Arbre 2 vers 4

Famille **equilibreur**, usages : equilibreur, repartition. Origine : **wiki**. Tuile 5 × 4, période 5, tuile unique, 2 entrée(s), 4 sortie(s), 0 machine(s) par tuile.

Un répartiteur de mélange puis deux d'arbre : deux entrées, quatre sorties égales.

Pièces d'une tuile : repartiteur ×3, tapis ×2, tapis_entree ×2, tapis_sortie ×4.
Place minimale : 5 × 4 (une tuile). Doit rester droit : rien sur toute la largeur.

```
...=>
>=>=>
>=>=>
...=>
```

Sources : https://wiki.factorio.com/Balancers ; https://forums.factorio.com/viewtopic.php?p=425342

### `equilibreur-4-4` : Équilibreur 4 vers 4 (papillon)

Famille **equilibreur**, usages : equilibreur, repartition. Origine : **wiki**. Tuile 10 × 5, période 10, tuile unique, 4 entrée(s), 4 sortie(s), 0 machine(s) par tuile.

Deux étages de deux répartiteurs ; entre les étages, la deuxième voie descend en colonne 3 sous les voies 3 et 4 (tapis souterrains) pour que les paires de l'étage 2 mêlent chacune une voie de chaque paire de l'étage 1 : chaque entrée se répartit en quatre quarts égaux, pour toute combinaison d'entrées pleines ou vides.

Pièces d'une tuile : repartiteur ×4, souterrain_entree ×2, souterrain_sortie ×2, tapis ×24, tapis_entree ×4, tapis_sortie ×4.
Place minimale : 10 × 5 (une tuile). Doit rester droit : rien sur toute la largeur.

```
>=>>>>>>=>
>=>v.>>>=>
>=uvU^>>=>
>=uvU>^>=>
...>>>>^..
```

Sources : https://wiki.factorio.com/Balancers ; https://forums.factorio.com/viewtopic.php?p=425342

### `fonte-2x2-simple` : Colonne de fonte 2×2, une rangée

Famille **fonte**, usages : fonte, acier. Origine : **forum**. Tuile 4 × 6, période 4, répétable en série, 1 entrée(s), 1 sortie(s), 2 machine(s) par tuile.

Une rangée de fours : tapis d'entrée au nord, tapis de sortie au sud ; 6 tuiles de haut, la plus étroite.

Pièces d'une tuile : bras ×4, machine_fonte ×2, poteau ×2, tapis_entree ×4, tapis_sortie ×4.
Place minimale : 4 × 6 (une tuile). Doit rester droit : tapis_entree:1 (rangée 0), tapis_sortie:1 (rangée 5).

```
>>>>>>>>
n+n.n+n.
AABBCCDD
AABBCCDD
n+n.n+n.
>>>>>>>>
```

Sources : https://forums.factorio.com/viewtopic.php?p=15569 ; https://forums.factorio.com/viewtopic.php?p=46359 ; https://forums.factorio.com/viewtopic.php?p=194325

### `fonte-3x3-simple` : Colonne de fonte 3×3 (électrique), une rangée

Famille **fonte**, usages : fonte, acier. Origine : **derive**. Tuile 6 × 7, période 6, répétable en série, 1 entrée(s), 1 sortie(s), 2 machine(s) par tuile.

Pièces d'une tuile : bras ×4, machine_fonte ×2, poteau ×2, tapis_entree ×6, tapis_sortie ×6.
Place minimale : 6 × 7 (une tuile). Doit rester droit : tapis_entree:1 (rangée 0), tapis_sortie:1 (rangée 6).

```
>>>>>>>>>>>>
.n+.n..n+.n.
AAABBBCCCDDD
AAABBBCCCDDD
AAABBBCCCDDD
.n+.n..n+.n.
>>>>>>>>>>>>
```

Sources : https://forums.factorio.com/viewtopic.php?p=15569 ; https://forums.factorio.com/viewtopic.php?p=46359 ; https://forums.factorio.com/viewtopic.php?p=194325

### `fonte-2x2-double-central` : Colonne de fonte 2×2, deux rangées, tapis central partagé

Famille **fonte**, usages : fonte, acier. Origine : **ref_dc** (Fonderie.png). Tuile 4 × 11, période 4, répétable en série, 1 entrée(s), 2 sortie(s), 4 machine(s) par tuile.

Référence du DC : le minerai et le combustible arrivent par le tapis du milieu (voie 1 minerai, voie 2 combustible), deux rangées de fours de côté 2, plaques sortant par les tapis du haut et du bas ; se colle de gauche à droite.

Pièces d'une tuile : bras ×8, machine_fonte ×4, poteau ×3, tapis_entree ×4, tapis_sortie ×8.
Place minimale : 4 × 11 (une tuile). Doit rester droit : tapis_sortie:1 (rangée 0), tapis_entree:1 (rangée 5), tapis_sortie:2 (rangée 10).

```
>>>>>>>>
s+s.s+s.
AABBEEFF
AABBEEFF
s+s.s+s.
>>>>>>>>
n.n.n.n.
CCDDGGHH
CCDDGGHH
n+n.n+n.
>>>>>>>>
```

Sources : https://forums.factorio.com/viewtopic.php?p=15569 ; https://forums.factorio.com/viewtopic.php?p=46359 ; https://forums.factorio.com/viewtopic.php?p=194325

### `fonte-2x2-double-central-fusion` : Colonne de fonte 2×2, deux rangées, tapis central partagé, sorties fusionnées en queue

Famille **fonte**, usages : fonte, acier, sortie-unique. Origine : **ref_dc** (Fonderie.png). Tuile 4 × 11, période 4, répétable en série, 1 entrée(s), 1 sortie(s), 4 machine(s) par tuile.

Comme la colonne de référence du DC, avec la queue de Fonderie.png : les deux tapis de plaques rejoignent par les côtés un seul tapis de sortie (plaques du haut sur la voie 1, du bas sur la voie 2), au bout de la colonne ; le tapis du milieu s'arrête devant la queue.

Pièces d'une tuile : bras ×8, machine_fonte ×4, poteau ×3, tapis ×0, tapis_entree ×4, tapis_sortie ×8.
Place minimale : 7 × 11 (une tuile, tête et queue comprises). Doit rester droit : tapis_sortie:1 (rangée 0), tapis_entree:1 (rangée 5), tapis_sortie:2 (rangée 10).

```
>>>>>>>>>v.
s+s.s+s..v.
AABBEEFF.v.
AABBEEFF.v.
s+s.s+s..v.
>>>>>>>>.>>
n.n.n.n..^.
CCDDGGHH.^.
CCDDGGHH.^.
n+n.n+n..^.
>>>>>>>>>^.
```

Sources : https://forums.factorio.com/viewtopic.php?p=15569 ; https://forums.factorio.com/viewtopic.php?p=46359 ; https://forums.factorio.com/viewtopic.php?p=194325

### `fonte-2x2-double-sortie-centrale` : Colonne de fonte 2×2, deux rangées, sortie centrale

Famille **fonte**, usages : fonte, acier. Origine : **forum**. Tuile 4 × 11, période 4, répétable en série, 2 entrée(s), 1 sortie(s), 4 machine(s) par tuile.

Deux tapis d'entrée à l'extérieur, un seul tapis de sortie au centre qui reçoit les deux rangées (une voie chacune).

Pièces d'une tuile : bras ×8, machine_fonte ×4, poteau ×3, tapis_entree ×8, tapis_sortie ×4.
Place minimale : 4 × 11 (une tuile). Doit rester droit : tapis_entree:1 (rangée 0), tapis_sortie:1 (rangée 5), tapis_entree:2 (rangée 10).

```
>>>>>>>>
n+n.n+n.
AABBEEFF
AABBEEFF
n+n.n+n.
>>>>>>>>
s.s.s.s.
CCDDGGHH
CCDDGGHH
s+s.s+s.
>>>>>>>>
```

Sources : https://forums.factorio.com/viewtopic.php?p=15569 ; https://forums.factorio.com/viewtopic.php?p=46359 ; https://forums.factorio.com/viewtopic.php?p=194325

### `fonte-chaine-directe-3x3` : Chaîne directe de fours 3×3 (matière → plaque → acier)

Famille **fonte**, usages : acier, chaine. Origine : **forum**. Tuile 6 × 11, période 6, répétable en série, 1 entrée(s), 1 sortie(s), 4 machine(s) par tuile.

Deux fours en série par insertion directe : le premier fond la matière, le second la transforme (même vitesse : un pour un).

Pièces d'une tuile : bras ×6, machine_fonte ×4, poteau ×3, tapis_entree ×6, tapis_sortie ×6.
Place minimale : 6 × 11 (une tuile). Doit rester droit : tapis_entree:1 (rangée 0), tapis_sortie:1 (rangée 10).

```
>>>>>>>>>>>>
.n+.n..n+.n.
AAABBBEEEFFF
AAABBBEEEFFF
AAABBBEEEFFF
.n+.n..n+.n.
CCCDDDGGGHHH
CCCDDDGGGHHH
CCCDDDGGGHHH
.n+.n..n+.n.
>>>>>>>>>>>>
```

Sources : https://forums.factorio.com/viewtopic.php?p=273173 ; https://forums.factorio.com/viewtopic.php?p=249120

### `fonte-3x3-double-central` : Colonne de fonte 3×3 (électrique), deux rangées, tapis central

Famille **fonte**, usages : fonte, acier. Origine : **derive**. Tuile 6 × 13, période 6, répétable en série, 1 entrée(s), 2 sortie(s), 4 machine(s) par tuile.

Même disposition que la référence du DC avec des fours de côté 3 : pas de combustible, le minerai occupe les deux voies.

Pièces d'une tuile : bras ×8, machine_fonte ×4, poteau ×3, tapis_entree ×6, tapis_sortie ×12.
Place minimale : 6 × 13 (une tuile). Doit rester droit : tapis_sortie:1 (rangée 0), tapis_entree:1 (rangée 6), tapis_sortie:2 (rangée 12).

```
>>>>>>>>>>>>
.s+.s..s+.s.
AAABBBEEEFFF
AAABBBEEEFFF
AAABBBEEEFFF
.s+.s..s+.s.
>>>>>>>>>>>>
.n..n..n..n.
CCCDDDGGGHHH
CCCDDDGGGHHH
CCCDDDGGGHHH
.n+.n..n+.n.
>>>>>>>>>>>>
```

Sources : https://forums.factorio.com/viewtopic.php?p=15569 ; https://forums.factorio.com/viewtopic.php?p=46359 ; https://forums.factorio.com/viewtopic.php?p=194325

### `fonte-3x3-double-central-fusion` : Colonne de fonte 3×3 (électrique), deux rangées, tapis central, sorties fusionnées en queue

Famille **fonte**, usages : fonte, acier, sortie-unique. Origine : **ref_dc**. Tuile 6 × 13, période 6, répétable en série, 1 entrée(s), 1 sortie(s), 4 machine(s) par tuile.

Colonne électrique à fours de côté 3 avec la même queue : les deux tapis de plaques se fusionnent en un seul tapis de sortie à l'est.

Pièces d'une tuile : bras ×8, machine_fonte ×4, poteau ×3, tapis ×0, tapis_entree ×6, tapis_sortie ×12.
Place minimale : 9 × 13 (une tuile, tête et queue comprises). Doit rester droit : tapis_sortie:1 (rangée 0), tapis_entree:1 (rangée 6), tapis_sortie:2 (rangée 12).

```
>>>>>>>>>>>>>v.
.s+.s..s+.s..v.
AAABBBEEEFFF.v.
AAABBBEEEFFF.v.
AAABBBEEEFFF.v.
.s+.s..s+.s..v.
>>>>>>>>>>>>.>>
.n..n..n..n..^.
CCCDDDGGGHHH.^.
CCCDDDGGGHHH.^.
CCCDDDGGGHHH.^.
.n+.n..n+.n..^.
>>>>>>>>>>>>>^.
```

Sources : https://forums.factorio.com/viewtopic.php?p=15569 ; https://forums.factorio.com/viewtopic.php?p=46359 ; https://forums.factorio.com/viewtopic.php?p=194325

### `fonte-3x3-double-sortie-centrale` : Colonne de fonte 3×3 (électrique), deux rangées, sortie centrale

Famille **fonte**, usages : fonte, acier. Origine : **derive**. Tuile 6 × 13, période 6, répétable en série, 2 entrée(s), 1 sortie(s), 4 machine(s) par tuile.

Pièces d'une tuile : bras ×8, machine_fonte ×4, poteau ×3, tapis_entree ×12, tapis_sortie ×6.
Place minimale : 6 × 13 (une tuile). Doit rester droit : tapis_entree:1 (rangée 0), tapis_sortie:1 (rangée 6), tapis_entree:2 (rangée 12).

```
>>>>>>>>>>>>
.n+.n..n+.n.
AAABBBEEEFFF
AAABBBEEEFFF
AAABBBEEEFFF
.n+.n..n+.n.
>>>>>>>>>>>>
.s..s..s..s.
CCCDDDGGGHHH
CCCDDDGGGHHH
CCCDDDGGGHHH
.s+.s..s+.s.
>>>>>>>>>>>>
```

Sources : https://forums.factorio.com/viewtopic.php?p=15569 ; https://forums.factorio.com/viewtopic.php?p=46359 ; https://forums.factorio.com/viewtopic.php?p=194325

### `labo-chaine-bras` : Laboratoires en chaîne : un bras passe les packs d'un laboratoire au suivant

Famille **labo**, usages : labo, recherche, chaine. Origine : **derive**. Tuile 4 × 5, période 4, répétable en série, 1 entrée(s), 1 sortie(s), 1 machine(s) par tuile.

Aucun tapis le long de la rangée : un seul bras en tête prend les packs sur le tapis d'entrée et chaque laboratoire les passe au suivant. Le nombre de laboratoires est borné par ce que les bras portent (le premier bras porte les packs de tous les suivants) ; la queue pose le dernier laboratoire.

Pièces d'une tuile : bras ×1, machine_labo ×1, poteau ×1, tapis_entree ×0.
Place minimale : 9 × 5 (une tuile, tête et queue comprises). Doit rester droit : rien sur toute la largeur.

```
.............
..AAA.BBB.CCC
>oAAAoBBBoCCC
.+AAA+BBB+CCC
.............
```

Sources : https://wiki.factorio.com/Lab ; https://wiki.factorio.com/Inserters

### `labo-rangee-tapis` : Laboratoires en rangée sur un tapis de packs

Famille **labo**, usages : labo, recherche. Origine : **derive**. Tuile 4 × 5, période 4, répétable en série, 1 entrée(s), 1 sortie(s), 1 machine(s) par tuile.

Un tapis porte les packs (un type par voie) ; chaque laboratoire en prend avec deux bras. Période 4.

Pièces d'une tuile : bras ×2, machine_labo ×1, poteau ×1, tapis_entree ×4.
Place minimale : 4 × 5 (une tuile). Doit rester droit : tapis_entree:1 (rangée 0).

```
>>>>>>>>
.nn..nn.
AAA.BBB.
AAA+BBB+
AAA.BBB.
```

Sources : https://wiki.factorio.com/Lab ; https://wiki.factorio.com/Inserters

### `labo-rangee-miroir` : Laboratoires en rangée, deux faces sur un même tapis de packs

Famille **labo**, usages : labo, recherche. Origine : **derive**. Tuile 4 × 9, période 4, répétable en série, 1 entrée(s), 1 sortie(s), 2 machine(s) par tuile.

Le tapis de packs au milieu nourrit un laboratoire au nord et un au sud par tuile : le double de laboratoires pour la même longueur de tapis.

Pièces d'une tuile : bras ×4, machine_labo ×2, poteau ×2, tapis_entree ×4.
Place minimale : 4 × 9 (une tuile). Doit rester droit : tapis_entree:1 (rangée 4).

```
AAA.CCC.
AAA.CCC.
AAA+CCC+
.ss..ss.
>>>>>>>>
.nn..nn.
BBB+DDD+
BBB.DDD.
BBB.DDD.
```

Sources : https://wiki.factorio.com/Lab ; https://wiki.factorio.com/Inserters

### `foreuses-2x2-combustion-2xN` : Champ de foreuses 2×2 à combustion, 2 × N, sur un tapis central

Famille **mine**, usages : extraction. Origine : **forum**. Tuile 2 × 5, période 2, répétable en série, 0 entrée(s), 1 sortie(s), 2 machine(s) par tuile.

Foreuses jointives de côté 2 de part et d'autre d'un tapis, sans poteau (combustion) ; période 2.

Pièces d'une tuile : foreuse ×2, tapis_sortie ×2.
Place minimale : 2 × 5 (une tuile). Doit rester droit : tapis_sortie:1 (rangée 2).

```
AACC
AACC
>>>>
BBDD
BBDD
```

Sources : https://forums.factorio.com/viewtopic.php?p=158464 ; https://forums.factorio.com/viewtopic.php?p=19252

### `foreuses-boucle-charbon` : Paire de foreuses à combustion en boucle de combustible

Famille **mine**, usages : extraction, bootstrap. Origine : **derive**. Tuile 6 × 2, période 6, répétable en série, 0 entrée(s), 1 sortie(s), 2 machine(s) par tuile.

Deux foreuses face à face : chacune dépose son charbon dans un coffre, et un bras à combustion reprend le charbon du coffre de l'autre pour la recharger. Elles se tiennent seules ; le surplus s'accumule dans les coffres (quai de collecte). Période 6 : se colle en série. Le débit annoncé est brut (le combustible brûlé par les foreuses n'est pas déduit).

Pièces d'une tuile : bras ×2, coffre ×2, foreuse ×2.
Place minimale : 6 × 2 (une tuile). Doit rester droit : rien sur toute la largeur.

```
AA#oBBCC#oDD
AAe#BBCCe#DD
```

Sources : https://wiki.factorio.com/Burner_mining_drill ; https://forums.factorio.com/viewtopic.php?p=158464

### `foreuses-3x3-simple-face` : Rangée de foreuses 3×3 d'un seul côté du tapis

Famille **mine**, usages : extraction. Origine : **forum**. Tuile 4 × 4, période 4, répétable en série, 0 entrée(s), 1 sortie(s), 1 machine(s) par tuile.

Une rangée de foreuses au nord d'un tapis (voie 1) ; période 4 : une foreuse et un passage pour le poteau.

Pièces d'une tuile : foreuse ×1, poteau ×1, tapis_sortie ×4.
Place minimale : 4 × 4 (une tuile). Doit rester droit : tapis_sortie:1 (rangée 3).

```
AAA.BBB.
AAA.BBB.
AAA+BBB+
>>>>>>>>
```

Sources : https://forums.factorio.com/viewtopic.php?p=158464 ; https://forums.factorio.com/viewtopic.php?p=19252

### `foreuses-2xN-tapis-central` : Champ de foreuses 3×3, 2 × N, sur un tapis central

Famille **mine**, usages : extraction. Origine : **forum**. Tuile 7 × 7, période 7, répétable en série, 0 entrée(s), 1 sortie(s), 4 machine(s) par tuile.

Une rangée de foreuses de chaque côté d'un tapis ; deux foreuses par rangée et par tuile avec un poteau dans le passage du milieu (période 7). La rangée du nord remplit la voie 1, celle du sud la voie 2.

Pièces d'une tuile : foreuse ×4, poteau ×1, tapis_sortie ×7.
Place minimale : 7 × 7 (une tuile). Doit rester droit : tapis_sortie:1 (rangée 3).

```
AAA.BBBEEE.FFF
AAA.BBBEEE.FFF
AAA+BBBEEE+FFF
>>>>>>>>>>>>>>
CCC.DDDGGG.HHH
CCC.DDDGGG.HHH
CCC.DDDGGG.HHH
```

Sources : https://forums.factorio.com/viewtopic.php?p=158464 ; https://forums.factorio.com/viewtopic.php?p=19252

### `chevalets-ligne` : Ligne de chevalets sur une conduite collectrice

Famille **petrole**, usages : petrole, chevalets. Origine : **forum**. Tuile 3 × 5, période 3, répétable en série, 0 entrée(s), 1 sortie(s), 1 machine(s) par tuile.

Chevalets jointifs (période 3) orientés vers le nord, un piquage chacun sur la conduite collectrice du nord.

Pièces d'une tuile : chevalet ×1, poteau ×1, tuyau ×4.
Place minimale : 3 × 5 (une tuile). Doit rester droit : rien sur toute la largeur.

```
~~~~~~
+.~+.~
AAABBB
AAABBB
AAABBB
```

Sources : https://wiki.factorio.com/Oil_processing ; https://forums.factorio.com/viewtopic.php?p=158464

### `chevalets-double` : Deux lignes de chevalets de part et d'autre d'une conduite collectrice

Famille **petrole**, usages : petrole, chevalets. Origine : **forum**. Tuile 3 × 9, période 3, répétable en série, 0 entrée(s), 1 sortie(s), 2 machine(s) par tuile.

La conduite du milieu reçoit directement la sortie des chevalets du nord (orientés vers le sud) et du sud (orientés vers le nord) ; poteau moyen requis (les deux rangées de poteaux sont à 8 tuiles).

Pièces d'une tuile : chevalet ×2, poteau ×2, tuyau ×3.
Place minimale : 3 × 9 (une tuile). Doit rester droit : rien sur toute la largeur.
Poteau exigé : aire 3.5, fil 9.0.

```
+..+..
AAACCC
AAACCC
AAACCC
~~~~~~
BBBDDD
BBBDDD
BBBDDD
+..+..
```

Sources : https://wiki.factorio.com/Oil_processing ; https://forums.factorio.com/viewtopic.php?p=158464

### `raffinerie-rangee-base` : Rangée de raffineries (traitement de base) sur deux conduites

Famille **petrole**, usages : petrole, raffinage. Origine : **derive**. Tuile 5 × 9, période 5, répétable en série, 1 entrée(s), 1 sortie(s), 1 machine(s) par tuile.

Brut par la conduite du sud (un piquage par raffinerie), gaz sorti par la conduite du nord ; période 5 (côté de la raffinerie), un poteau par tuile ; même géométrie que le gabarit « raffinerie » de modules.lua.

Pièces d'une tuile : machine_raffinerie ×1, poteau ×1, tuyau ×12.
Place minimale : 5 × 9 (une tuile). Doit rester droit : rien sur toute la largeur.

```
~~~~~~~~~~
....~....~
AAAAABBBBB
AAAAABBBBB
AAAAABBBBB
AAAAABBBBB
AAAAABBBBB
+..~.+..~.
~~~~~~~~~~
```

Sources : https://wiki.factorio.com/Oil_refinery ; https://wiki.factorio.com/Oil_processing ; https://forums.factorio.com/viewtopic.php?p=227781

### `packs-rouges-rangee` : Packs rouges : une assembleuse d'engrenages en tête, une assembleuse de packs par tuile

Famille **science**, usages : science, packs-rouges. Origine : **derive**. Tuile 4 × 7, période 4, répétable en série, 2 entrée(s), 1 sortie(s), 2 machine(s) par tuile.

Le tapis du haut porte le cuivre (voie 2) et reçoit les engrenages de la machine de tête (voie 1) ; chaque tuile fabrique des packs avec les deux. Le nombre de tuiles servies par la machine d'engrenages (1 pour 10 à vitesses égales) est calculé d'après les recettes.

Pièces d'une tuile : bras ×4, machine_asm ×1, poteau ×1, tapis_entree ×4, tapis_sortie ×4.
Place minimale : 9 × 7 (une tuile, tête et queue comprises). Doit rester droit : tapis_entree:1 (rangée 0), tapis_sortie:1 (rangée 6).

```
>>>>>>>>>>>>>
..ss..nn..nn.
.AAA.BBB.CCC.
.AAA+BBB+CCC+
.AAA.BBB.CCC.
..ss..nn..nn.
>>>>.>>>>>>>>
```

Sources : https://wiki.factorio.com/Science_pack ; https://wiki.factorio.com/Automation_science_pack ; https://wiki.factorio.com/Logistic_science_pack

### `packs-verts-rangee` : Packs verts : machines de bras et de tapis en tête, une assembleuse de packs par tuile

Famille **science**, usages : science, packs-verts. Origine : **derive**. Tuile 4 × 9, période 4, répétable en série, 2 entrée(s), 1 sortie(s), 3 machine(s) par tuile.

Deux tapis naissent dans la tête : les bras (tapis proche) et les convoyeurs (tapis lointain, bras long) ; chaque tuile prend un de chaque. Le rapport réel est calculé d'après les recettes : une machine de bras sert 12 assembleuses de packs, une machine de convoyeurs 24. Deux tapis d'entrée (fer et engrenages ; circuits) alimentent la tête.

Pièces d'une tuile : bras ×2, bras_long ×1, machine_asm ×1, poteau ×1, tapis ×8, tapis_entree ×0, tapis_sortie ×4.
Place minimale : 13 × 9 (une tuile, tête et queue comprises). Doit rester droit : tapis_sortie:1 (rangée 7).

```
>>>>>>>>>>>>>>>>>
>>>>>>>>>>>>>>>>>
..s...SS..Nn..Nn.
+AAA+BBB+CCC.DDD.
.AAA.BBB.CCC+DDD+
.AAA.BBB.CCC.DDD.
+ssS+ss....n...n.
>>>>>>>..>>>>>>>>
>>>>.............
```

Sources : https://wiki.factorio.com/Science_pack ; https://wiki.factorio.com/Automation_science_pack ; https://wiki.factorio.com/Logistic_science_pack
