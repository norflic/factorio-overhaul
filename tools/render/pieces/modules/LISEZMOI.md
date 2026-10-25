# Icônes des modules (lot MOD-V, 25/10 ; choix du DC appliqués au lot MOD-3, D-17)

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
tomber au pixel près (grille de 32 px dessinée à la main) ; un rendu 3D réduit ne le garantit pas. Les couleurs des balises viennent
quand même du registre commun des âges (`../levels/commun/ages.py`) : `ages.matieres()` est appelée avec une fausse
fonction `metal()` qui relève les couleurs (rgb linéaires), la rugosité et la métallicité.

## Règles de design

| | Vitesse | Productivité | Efficacité |
|---|---|---|---|
| Silhouette (le type se lit à la FORME) | chevron « > » | engrenage à 8 dents (D-17) | feuille ovale, tige en bas à gauche |
| Couleur du corps (D-17 : « Couleur par type ») | bleu | orange | vert |
| Lumière | chevron court à la pointe | moyeu | nervure |

**Lot MOD-3 (version 2 de l'outil, décision D-17 du DC, 25/10)** : corps coloré PAR TYPE (`TYPE_COULEURS`), productivité
en ENGRENAGE (`geo_productivite_engrenage` ; la croix du 2e jet de MOD-V reste dans `geo_productivite`), chiffre romain
gardé, teintes des BALISES à la couleur de l'ÂGE (inchangées depuis MOD-V). MOD-V avait écarté l'engrenage parce qu'en
mode Alt il se confondait avec l'icône de recette de la roue dentée (gris) ; la couleur orange du type doit l'en
distinguer : à juger sur les captures du lot MOD-3.

- **Couleur du corps = type** ; plus sombre au palier 1 (62 %), pleine au palier 10.
- **Teinte des balises = âge qui débloque le palier** (`shared/content/epochs.lua`, contrôlé par `verifier_epoques()`) :
  palier 1 → âge 6 (porcelaine blanche, arcs bleus) ; paliers 2 à 5 → âge 10 (ivoire chaud, voyants bleus) ; paliers 6
  à 10 → âge 14 (indigo de nuit, blanc d'étoile) : `beacon_tint`, primaire = dominante de l'âge, secondaire = foyer.
- **Montée du palier** : (1) teinte du champ ; (2) éclat du cœur et halo, croissants de 1 à 10 ; (3) pièces à la lumière
  du type, en nombre = rang dans la génération (paliers 2 à 5 : 1 à 4 voyants ; 6 à 10 : 1 à 5 étoiles) ; (4) plaque
  gravée du chiffre romain, coin HAUT GAUCHE (le coin bas droit d'une case porte le nombre d'objets).
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
