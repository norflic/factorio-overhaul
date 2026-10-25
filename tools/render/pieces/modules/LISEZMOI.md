# Icônes des modules (lot MOD-V, 25/10)

Demande du Directeur Créatif (24/10, mot pour mot) : « nouveaux modules (car en fait ils ont tous le même aspet / couleur
en plus) ». Avant ce lot, les paliers 1 à 3 étaient les icônes vanilla et les paliers 4 à 10 la même icône vanilla
teintée (rampe de couleur), avec un chiffre et une puce superposés.

**Proposition, non validée : seul le verdict du Directeur Créatif valide un design.**

## Ce que fait l'outil

`icones.py` dessine les 30 icônes d'objet (3 types × 10 paliers) et les 30 icônes de technologie, sans Blender :
champs de distance signée à 512 px, relief (hauteur → normales → lumière du nord-ouest, spéculaire selon la rugosité et
la métallicité de la matière), réduction par moyenne de boîtes en lumière linéaire, puis plaque du palier posée au pixel.
Aucun hasard : deux passages donnent les mêmes octets (`--check`).

Pourquoi un rendu 2D plutôt que le kit Blender : l'icône se juge à 32 px dans l'inventaire et le chiffre du palier doit y
tomber au pixel près (grille de 32 px dessinée à la main) ; un rendu 3D réduit ne le garantit pas. Les couleurs viennent
quand même du registre commun des âges (`../levels/commun/ages.py`) : `ages.matieres()` est appelée avec une fausse
fonction `metal()` qui relève les couleurs (rgb linéaires), la rugosité et la métallicité.

## Règles de design

| | Vitesse | Productivité | Efficacité |
|---|---|---|---|
| Silhouette (le type se lit à la FORME) | chevron « > » | croix « + » (le produit en plus) | feuille ovale, tige en bas à gauche |
| Lumière | chevron court à la pointe | centre | nervure |

Premier jet de la productivité : un engrenage à 8 dents (`geo_productivite_engrenage`, gardé pour mémoire) ; en mode Alt,
il se confondait avec l'icône de recette de la roue dentée affichée juste au-dessus des modules (capture du 25/10).

- **Couleur = âge qui débloque le palier** (`shared/content/epochs.lua`, contrôlé par `verifier_epoques()`) :
  palier 1 → âge 6 (Électricité : porcelaine blanche, bleu machine, arcs bleus) ; paliers 2 à 5 → âge 10 (Haute
  technologie : ivoire chaud, gris technique, anthracite, voyants bleus) ; paliers 6 à 10 → âge 14 (La Porte : indigo de
  nuit, blanc lunaire, blanc d'étoile). Règle 60/30/10 de l'âge : champ = dominante, cadre = secondaire, lumière = foyer.
- **Montée du palier** : (1) matières de la génération ; (2) éclat du cœur et halo, croissants de 1 à 10 ;
  (3) pièces propres à l'âge, en nombre = rang dans la génération (âge 10 : 1 à 4 voyants ; âge 14 : 1 à 5 étoiles) ;
  (4) plaque gravée du chiffre romain, coin HAUT GAUCHE (le coin bas droit d'une case porte le nombre d'objets).
- Plaque : vecteur à 64 px et dans les technologies ; AU PIXEL à 32 px (glyphes I 1 × 5, V 3 × 5, X 5 × 5) ; absente
  à 16 et 8 px (un chiffre n'y tient pas).
- Contour sombre d'environ 1 px à 64 px autour de la silhouette (lisibilité sur fond clair).

## Commandes (depuis la racine du mod)

```
py -3.9 tools/render/pieces/modules/icones.py                      # écrit graphics/modules : 60 PNG, MANIFEST.json, icons.lua (environ 60 s)
py -3.9 tools/render/pieces/modules/icones.py --check              # régénère en mémoire, compare au manifeste et aux fichiers ; code 1 si écart
py -3.9 tools/render/pieces/modules/icones.py --planche <png>      # planche des 30 icônes (64 px, 32 px, 32 px x 2), fond sombre et clair
py -3.9 tools/render/pieces/modules/icones.py --out <dossier> ...  # ailleurs (essais)
```

## Sorties (`graphics/modules/`, commitées : 1,5 Mo)

- `<objet>.png` : 64 px + 3 mipmaps (bande 120 × 64), `icon_size = 64`, `icon_mipmaps = 4` ;
- `tech/<technologie>.png` : 256 px + 3 mipmaps (bande 480 × 256), `icon_size = 256`, `icon_mipmaps = 4` ;
- `MANIFEST.json` : sha256 de chaque fichier, type, palier, âge, teintes de balise ;
- `icons.lua` : la même table pour l'étape data, lue par `prototypes/modules.lua` (icônes et `beacon_tint` : primaire =
  couleur du champ, secondaire = lumière de l'âge).

Ne jamais retoucher un PNG à la main : modifier `icones.py`, régénérer, `--check`.
