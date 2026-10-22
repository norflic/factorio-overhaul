# Mitrailleuse, exploration « hybride progressive » (lot V3-S)

Niveaux témoins 11 (époque 6, 3×3), 21 (époque 11, 5×5), 29 (époque 15, 6×6) et pièce du niveau 30. Rien n'est
validé : seul le Directeur Créatif valide un design.

## Fichiers
| Fichier | Rôle |
|---|---|
| `geo.py` | géométrie en Python pur (un maillage par matériau) |
| `kit.py` | visserie, tôlerie, tuyaux, canons rotatifs (`gatling(..., vent=)` : évents incandescents) |
| `parts.py` | volumes du socle (gaines annelées, réservoirs, cheminée, générateur, radiateurs, tours de cellules, couronne à contreforts) et coque lissée de la tête (`loft`, `plate_loft`) |
| `design.py` | composition des niveaux, matériaux, systèmes et animations comptés |
| `apercu.py` | aperçu hors Blender (masse, remplissage, O) en 10 s |
| `blender_render.py`, `rendre.py` | rendu Cycles PAR LE VERROU (`with_render_lock.py`), post-traitement de `fo_post.py` (inchangé) ; `--layers main,glow` pour les essais rapides ; taches basse fréquence (`add_mottle`) |
| `mesure.py` | indicateurs de la charte (`da_lib`, `seuils`) en pose E et N, dominance |
| `progression_hyb.py` | `progression.py` de l'analyste exécuté tel quel sur nos mesures |
| `planches.py` | planches (`planches`) et images du regard naïf (`regard`, clé imprimée seulement) |

## Commandes (Python 3.9 : `py -3.9`, qui a numpy et Pillow)
```
py -3.9 rendre.py --samples 128 --cache <cache> --out <sprites>
py -3.9 mesure.py <sprites> <mesures.json> [<corps>]
py -3.9 progression_hyb.py <mesures.json> <sortie> E
py -3.9 planches.py planches <sprites> <dumps vanilla> <sortie>
py -3.9 planches.py regard <sprites> <dumps vanilla> <sortie>
```
Dumps vanilla : `lua5.2 tests/datastage/harness.lua "<racine>/data" . --dump-proto <type>/<nom>` pour
`ammo-turret/gun-turret`, `electric-turret/laser-turret`, `assembling-machine/assembling-machine-3`,
`reactor/nuclear-reactor`, `rocket-silo/rocket-silo`.

## Choix à prouver en moteur
- Le socle déborde au-dessus du bord nord de l'emprise (volumes arrière) : le prototype devra déclarer
  `base_picture_render_layer = "object"` et `gun_animation_secondary_draw_order = 1` (non vérifié en jeu).
- La tête est dessinée par-dessus tout le socle : rien du socle devant elle ne monte dans sa zone à l'écran ;
  la pièce du niveau 30 (lance-roquettes) est à l'avant, bas, hors de la zone de la tête (F46).
