# Kit minerai : feuilles de gisement (lot M1, 24/10/2026)

Rend un gisement de ressource solide au format EXACT des minerais vanilla de Factorio 1.1.91
(`data/base/prototypes/entity/resources.lua`) : feuille `stages` de 8 variantes (`frame_count = 8`, colonnes) × 8 stades
(`variation_count = 8`, lignes ; ligne 0 = le stade le plus riche, `stage_counts` décroissants), cadre de 128 px en hr
(`scale = 0.5`) et 64 px en normale, couche d'effet additive facultative (`stages_effect`, comme
`hr-uranium-ore-glow.png`), icône 64 px + 3 mipmaps (`icon_mipmaps = 4`, 120 × 64) et 3 images de l'objet au sol
(`pictures`). Témoin : le tungstène (`graphics/ressources/tungstene/`, branché par `shared/content/world.lua`,
champ `sheet`, et `prototypes/world.lua`). Le kit ne touche à AUCUN fichier du kit des familles (`levels/commun`) ni à
`fo_scene.py` : les designs de la mitrailleuse ne peuvent pas changer.

| Fichier | Rôle | Blender ? |
|---|---|---|
| `directions.py` | directions artistiques (formes, matières, comptes par stade, couche d'effet, réglages `CALIB`), couverture vanilla visée | non (pur) |
| `gisement.py` | pièce de rendu : toute la grille (64 cellules + 4 icônes) en UN rendu par `blender/render_piece.py` | oui |
| `feuille.py` | rendu (par le verrou) et post-traitement : cadres, ombre et liseré intégrés, fondu de bordure, réduction 2×, effet, icônes, `MANIFEST.json` | non (appelle Blender) |
| `mesure.py` | mesures contre la vanilla (couverture, luminance, reflets, ΔE CIE76) et planche hors moteur jour / nuit, zooms 1 et 2 | non |
| `check_gisement.py` | contrôle de la feuille livrée (manifeste, format, stades, bordure, normale) ; `--mutants` | non |

## Commandes (depuis la racine du mod)

```
# rendu complet d'une direction (Blender TOUJOURS par le verrou ; environ 25 min à 128 échantillons, 5 à 8 min à 32)
python tools/render/with_render_lock.py --disque <sorties> -- py -3.9 tools/render/pieces/ressources/feuille.py \
    --direction A4 --samples 128 --travail <sorties>/travail --sortie <sorties>/A4
# icônes en gros plan seules (20 s), après la feuille (elles remplacent les icônes tirées de la grille)
python tools/render/with_render_lock.py --disque <sorties> -- py -3.9 tools/render/pieces/ressources/feuille.py \
    --direction A4 --icones-seules --samples 128 --travail <sorties>/travail --sortie <sorties>/A4
# post-traitement seul (sans Blender) : --post-seul (puis --icones-seules --post-seul pour remettre les icônes)
# mesures et planche
py -3.9 tools/render/pieces/ressources/mesure.py --data "<racine>/data" --feuille A4=<sorties>/A4 --planche p.png
# contrôle de la feuille livrée
py -3.9 tools/render/pieces/ressources/check_gisement.py --mutants   -> « BILAN : 5 OK, 0 ECHEC(S) », « 6/6 refusés »
```

## Faire un autre minerai

1. Une direction dans `directions.py` (formes : `touffes`/`lames` de cristaux, `roches`, `blocs`, `grains`, tapis de
   `fins` ; matières `MAT`, valeurs linéaires ; `effet` : `"eclats"` (reflets les plus clairs, en additif), `"lave"`
   (passe de lueur), ou rien ; `CALIB` ; `ICONE` pour l'icône en gros plan ; `GRAINE`).
2. Régler les comptes par stade pour suivre `COUVERTURE_VANILLA` (lire la couverture dans la sortie de `feuille.py`).
3. `mesure.py` contre la vanilla (et contre les minerais du mod déjà faits) ; captures en jeu (scénario greffé
   `m1-minerai` comme modèle) ; verdict du Directeur Créatif.
4. Brancher : `sheet = { dir, name, mining_visualisation_tint, effet = {...} }` dans la ressource de
   `shared/content/world.lua` (garder le NOM du prototype : sinon migration).
