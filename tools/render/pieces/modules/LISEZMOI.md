# Icônes des modules, version 3 (lot ART-MODULES, 9/11 : refonte holographique)

Directive du Directeur Créatif (9/11, mot pour mot) : « refonte graphique complète des modules : les icônes actuelles
(vitesse, productivité, efficacité, paliers 1 à 10) sont obsolètes ; remplacer l'intégralité des sprites et icônes par
des designs modernes, holographiques ou techno-organiques à haute lisibilité ; code couleur franc : Vitesse = cyan
électrique, Productivité = ambre/orange ionique, Efficacité = vert émeraude/biologique. »

**Proposition, non validée : seul le verdict du Directeur Créatif valide un design.** Les choix ci-dessous sont
provisoires ; le DC tranche sur la planche (`fo-logs/2026-11-09_ART-MODULES/PLANCHE-2026-11-09.png`).

Historique : version 1 = lot MOD-V (25/10, relief métallique aux couleurs de l'âge) ; version 2 = lot MOD-3 (D-17,
couleur par type, engrenage, chiffre romain) ; version 3 = ce lot (tout le dessin est refait, les sorties gardent
la même forme).

## Ce que fait l'outil

`icones.py` dessine les 30 icônes d'objet (3 familles × 10 paliers) et les 30 icônes de technologie, sans Blender :
champs de distance signée à 512 px, couleurs émissives en lumière linéaire, halo (flou gaussien), réduction par
moyenne de boîtes, puis étiquette du palier posée AU PIXEL à 32 px. Aucun hasard, aucune horloge : deux passages
donnent les mêmes octets (`--check`), et le rendu parallèle (`--jobs`, un processus par image) donne les mêmes
octets que le rendu séquentiel (`--jobs 1`), vérifié le 9/11.

Pourquoi un rendu 2D plutôt que Blender : l'icône se juge à 32 px dans l'inventaire et le chiffre du palier doit y
tomber au pixel près ; un rendu 3D réduit ne le garantit pas.

## Choix visuels provisoires (version 3)

| | Vitesse (`speed`) | Productivité (`productivity`) | Efficacité (`effectivity`) |
|---|---|---|---|
| Liseré lumineux | `#00E5FF` cyan électrique | `#FF9E1B` ambre ionique | `#1FE88A` vert émeraude |
| Cœur lumineux (glyphe, palier 1) | `#B8FBFF` | `#FFE2A8` | `#C4FFDF` |
| Corps sombre | `#071824` | `#1F1005` | `#061C12` |
| Blanc du glyphe (palier 10) | `#EAFDFF` | `#FFF5E0` | `#ECFFF3` |
| Glyphe | ÉCLAIR plein (zigzag, pointe en bas à gauche) | ENGRENAGE plein à 8 dents, FLÈCHE montante en creux dans le moyeu | HEXAGONE évidé (cellule) et FEUILLE pleine, nervure en creux |

- **Forme commune** (cohérence entre familles) : puce octogonale (carré à coins coupés), cœur sombre à dégradé
  radial teinté de la famille, micro-trame hexagonale et balayage horizontal très faibles (techno-organique),
  liseré lumineux de 1,2 px à 32 px avec halo qui déborde de la silhouette, fin filet intérieur, contour sombre
  d'environ 1 px autour (lisibilité sur fond clair).
- **Famille** : lisible à la COULEUR et au GLYPHE dès 16 px (éclair = trait diagonal clair ; engrenage = disque
  clair ; feuille-hexagone = anneau et lentille).
- **Palier** : CHIFFRE ARABE 1 à 10 sur une étiquette en HAUT À GAUCHE (le coin bas droit d'une case d'inventaire
  porte le nombre d'objets) : police 3 × 5 au pixel à 32 px (le « 10 » fait 7 px de large), même grille agrandie × 2
  à 64 px et dans les technologies ; JAUGE de 10 segments au bas de la puce, k segments allumés (64 px et
  technologies seulement : 10 segments ne tiennent pas à 32 px) ; éclat du liseré, largeur du halo et blancheur du
  glyphe croissent de 1 à 10 ; aux 16 et 8 px, l'étiquette reste visible en bloc (le chiffre n'y tient pas).
- **Teintes des balises** (`beacon_tint`) : INCHANGÉES depuis la version 2, couleur de l'ÂGE qui débloque le
  palier (D-17 : « Couleur de l'âge » ; palier 1 → âge 6 ; 2 à 5 → âge 10 ; 6 à 10 → âge 14, contrôlé par
  `verifier_epoques()` contre `shared/content/epochs.lua`), relevées dans `../levels/commun/ages.py`.

## Commandes (depuis la racine du mod)

```
py -3.9 tools/render/pieces/modules/icones.py                      # écrit graphics/modules : 60 PNG, MANIFEST.json, icons.lua (environ 40 s sur 16 cœurs)
py -3.9 tools/render/pieces/modules/icones.py --check              # régénère en mémoire, compare au manifeste et aux fichiers ; code 1 si écart
py -3.9 tools/render/pieces/modules/icones.py --planche <png>      # planche des 30 icônes (64, 32, 16 px et 16 px x 4), fond sombre et clair
py -3.9 tools/render/pieces/modules/icones.py --jobs 1             # rendu séquentiel (mêmes octets)
py -3.9 tools/render/pieces/modules/icones.py --out <dossier> ...  # ailleurs (essais)
```

## Sorties (`graphics/modules/`, commitées : environ 2,6 Mo)

- `<objet>.png` : 64 px + 3 mipmaps (bande 120 × 64), `icon_size = 64`, `icon_mipmaps = 4` ;
- `tech/<technologie>.png` : 256 px + 3 mipmaps (bande 480 × 256), `icon_size = 256`, `icon_mipmaps = 4` ;
- `MANIFEST.json` : sha256 de chaque fichier, type, palier, âge, teintes de balise, version de l'outil (3) ;
- `icons.lua` : la même table pour l'étape data, lue par `prototypes/modules.lua` (forme inchangée).

Ne jamais retoucher un PNG à la main : modifier `icones.py`, régénérer, `--check`.
