# Icônes de la chaîne du calcul (lot CALC-ICONES-A, 30/10)

État : **PROPOSITION**, en attente du verdict du Directeur Créatif.
Page : `<racine>/fo-logs/2026-10-30_DESIGN-CALCUL/CALC-ICONES-A/index.html`.

| Fichier | Rôle |
|---|---|
| `palette.py` | Palette COMMUNE : couleurs de fonction des puces (logique ambre, DRAM vert d'eau, SRAM violet), matières, couleurs d'âge. Propriétaire : CALC-ICONES-A. CALC-ICONES-B la RELIT sans la modifier. |
| `moteur2d.py` | Moteur 2,5 D : champs de distance à 512 px, relief éclairé du nord-ouest, extrusion pour la vue 3/4 (`Toile.dalle`), boîtes en vraie vue 3/4 (`Vue34`, `boite3d`), réduction linéaire en 64/32/16/8. |
| `dessins.py` | Les 10 dessins, plus la table `ICONES` (nom, âge, type). |
| `icones_composants.py` | Génère `graphics/calcul/icones/*.png`, `MANIFEST.json` et `icons-a.lua`. `--check` : 0 écart attendu, sinon code 1. |
| `planche.py` | Planches de contrôle : avant/après, vanilla, inventaire, marque du « Processeur gravé ». |

```
py -3.9 tools/render/pieces/calcul/icones_composants.py            # écrit graphics/calcul/icones
py -3.9 tools/render/pieces/calcul/icones_composants.py --check    # « 10 icône(s), 0 écart(s) »
py -3.9 tools/render/pieces/calcul/planche.py --icones graphics/calcul/icones --data "<racine>/data" --out <dossier>
```

Aucun Blender n'intervient. La génération est déterministe : le bruit vient d'un `RandomState` à graine fixe. Elle dure environ 45 s pour les 10 icônes.
