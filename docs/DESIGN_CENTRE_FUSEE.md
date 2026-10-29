# Centre de commandement = le vaisseau de départ qui devient bâtiment : brief de design v2 (lot CENTRE-FUSEE, 29/10)

**Le DC a tranché** : « vaisseau couché, long » ; « en fonction des âges, la fusée se métamorphose en bâtiment, une sorte de mix entre les 2, du coup c'est un bâtiment mais on peut observer que c'était une fusée avant » ; « un bâtiment construit sur une carcasse de squelette qui garderait son côté de dinosaure visible mais c'est clairement un bâtiment ». La v1 (fusée debout) est refusée et gardée comme essai (`fusee.py`). Concept à valider sur captures (dossier `fo-logs/2026-10-29_NUIT/CENTRE-FUSEE/planches/v3/`, la v2 est dans `planches/`). **v3 propreté (verdict du DC sur la v2 : « les maquettes ne sont pas très propres, même si l'idée est là »)** : tout tient dans l'emprise (vaisseau comprimé de 10 % en longueur), joints de coque à pas constant avec rivets, fenêtres et côtes sur la même grille, coque en peinture unie, cabanes ancrées dans la coque, fond uni, 64 échantillons. **Essai 3** : âge 1 à ailes en delta rouges bordées de crème (un vaisseau, plus un dirigeable) ; âge 8 à toit de tuiles brique, lignes et cheminées (plus une peau de coque), nez vitré en façade et côtes au-dessus du toit ; âge 15 à crâne, épine, arches et tuyères en or clair sur halle noire et sol clair. Les 5 états sont rendus par le verrou, un à la fois ; rien n'est en jeu. Les IA existent dès le départ et n'exigent pas la réparation.

## 1. Forme et empreinte
Vaisseau **couché, plus long que large** : **nez (crâne) à l'ouest**, **3 tuyères (queue) à l'est**, coque cylindrique à ogive, 2 ailes en flèche, dérive sur le dos, hublots et cockpit à l'avant, porte éclairée au SUD (signal de jeu fixe). Une seule pose (un conteneur ne tourne pas).
- **Empreinte rectangulaire 2 : 1** (largeur = le côté carré actuel) : **8×4 (âges 1-3), 10×5 (4-6), 12×6 (7-9), 14×7 (10-12), 16×8 (13-15)**, au lieu de 4×4 à 8×8. À 16×8 on retrouve la boîte de l'épave vanilla (15,6 × 7,8).
- **Hauteur** (z, 1 unité = 0,707 tuile d'écran) : mât ou flèche compris, ≈ 3,5 tuiles d'écran à l'âge 1, ≈ 6 à 6,5 à l'âge 15 ; le reste du bâtiment reste sous 4 tuiles.
- **Ce que cela implique pour le jeu (sans y toucher)** : `L.footprints.command` passe de « un côté » à « largeur × longueur » (`shared/levels/footprint.lua`, règle de place Q24, `apply_footprint`, contour, migration depuis les carrés actuels) ; boîtes de collision et de sélection rectangulaires (prototypes/levels/command.lua) ; conteneur non rotatif donc UNE orientation (nez à l'ouest) ; sprites plus grands (le plus grand ≈ 1 880 × 1 230 px HR avec les marges du rendu, à mesurer en vram : D4m, atlas virtuel plein au plancher, F186) ; `fo-faction-hq` prendrait la même épave (boîte déjà 2 : 1).

## 2. La carcasse (l'image du DC) et la règle de métamorphose
| Os du dinosaure | Pièce du vaisseau | Devient à l'âge élevé |
|---|---|---|
| **crâne** | nez : ogive, hublots, verrière | proue du bâtiment, toujours en peau, hublots → fenêtres |
| **épine** | quille sur le dos | faîtière du toit (bois, cuivre, or) |
| **côtes** | anneaux de coque | arches qui sortent des murs et dépassent du toit |
| **queue** | collerette et 3 tuyères à l'arrière | colonnes de pied, en peau jusqu'à l'âge 15 |
| **flancs** | 2 ailes + dérive | hangars, galeries, puis contreforts et tours |
**Règles** : (1) le crâne, l'épine, les côtes et les tuyères restent visibles à TOUS les âges ; (2) la **peau** de la coque est remplacée par les murs du bâtiment en partant du VENTRE (le milieu), jamais par les bouts ; (3) un âge ajoute un module et ne retire que ce que le bâtiment remplace ; (4) la matière de l'âge (`ages.py`) habille le bâtiment ET la peau restante.
Schéma texte (`=` peau de vaisseau, `#` bâtiment, `A` côtes) :
```
0  épave   ==  ==A==A==  ==      40 % de peau, ventre ouvert, crâne arraché à côté
1  réparé  =========A====A=====  100 % peau, cabanes de bois sur le dos, passerelle
4  mi-mi   ====A###A###A###A===  45 % peau (nez, queue), ventre en bâtiment à 2 niveaux
8  bâtiment ==A#########A===    30 % peau (nez, queue), grande halle, côtes au-dessus du toit
15 citadelle =A###A###A###A==    10 % peau (crâne noir, tuyères d'or), arches et faîtière d'or
```
| Âge | Part de peau | Ce qui s'ajoute | Ce qui disparaît |
|---|---|---|---|
| 0 | 40 % | cratère, débris, braises | ailette, ogive (arrachée), ventre |
| 1 | 100 % | cabanes de bois, passerelle, rampe, fanion, pièces de tôle | cratère |
| 2-3 | 90 → 75 % | forge de briques et cheminée ; chaudière dans le ventre | pieds d'atterrissage |
| 4 | 45 % | rez + étage jaune et noir, portique radio, cuves, torchère, hangars d'aile | peau du ventre, pieds |
| 5-7 | 40 → 35 % | coulée de lave ; pylônes Tesla ; toit de cristal | hangars → annexes |
| 8 | 30 % | halle de bois et cuivre sur pilotis, serre, galeries, bocaux verts | cockpit à l'air |
| 9-12 | 25 → 15 % | dôme de confinement ; paraboles ; radar, titane ; anneau supraconducteur | ailes en flèche → galeries |
| 13-14 | 15 → 12 % | cuve de confinement, anneau de la Porte | |
| 15 | 10 % | citadelle noire à créneaux, donjon étagé, tours aux bouts d'aile, arches et épine d'or | ailes (→ contreforts) |
Les 5 états du premier jet suivent cette courbe (épave, 1, 4, 8, 15). Pas de 15 âges avant le verdict du DC.

## 3. Mécanique (proposition, rien de codé)
Épave au départ pour chaque camp (niveau 0 : ce qu'est « sans centre » aujourd'hui) ; **Réparer** une fois (paquets de réparation + matériaux de l'âge 1, ordre de grandeur d'un niveau 1 → 2 actuel, à chiffrer en BALANCE_SHEET) → centre niveau 1, plafond des autres familles comme aujourd'hui (`L.CC_MAX`) ; **Améliorer** : les 15 niveaux actuels, un niveau = un âge = une étape de la métamorphose ; le remplacement garde contenu et réglages (F39). Les IA gardent leur QG (`fo-faction-hq`, 25 000 PV) sans réparer.

## 4. Question 17 (défauts)
**a.** Forme : **vaisseau couché long** (tranché). **b.** Épave dès le tick 0 pour **chaque camp** (défaut). **c.** Coût : **paquets de réparation + matériaux de l'âge 1**. **d.** Images : **épave + 15 âges** (après verdict). **e.** Emprise : **2 : 1, 8×4 à 16×8** (le DC dit s'il veut une emprise plus petite, p. ex. 6×3 à 12×6, ou carrée). **f.** QG des factions : **même épave fixe, teintée de leur couleur**. **g.** Plafond : **suit le niveau du centre**. **h.** Orientation : **une seule (nez à l'ouest)** / deux (nez à l'ouest ou au nord, coût : double de sprites). **i.** Mitrailleuses d'âge aux coins avant : **non** (la forme longue n'a pas de coin avant ; `satellites.py` à réécrire si oui).
