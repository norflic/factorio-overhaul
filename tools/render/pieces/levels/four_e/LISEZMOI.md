# Kit de famille du FOUR (`four_e`, lot F2-A, 25/10/2026)

Gabarit de `../commun/LISEZMOI.md` (« Faire une nouvelle famille ») ; AUCUN fichier de `../commun/`, `../gun_e/` ni
`../laser_e/` n'est modifié. Fiches des 15 âges (font foi pour l'intention) : `fo-logs/2026-10-25_F2/FICHES_FOUR.md` ;
notes, mesures, défauts : `fo-logs/2026-10-25_F2/NOTES.md`. Aucun design n'est validé : le Directeur Créatif juge.

| Fichier | Rôle | Dans Blender ? |
|---|---|---|
| `epoques.py` | registre et CONTRAT des fichiers d'âge (chambre, fumée, pièce ; clés propres `gueule`, `foyer`), emprise `COTE`, triplets « en 3 mots » `TRIPLETS` | non |
| `cotes.py` | cotes de la lignée par taille (sole, tablier, enveloppe, gueule, fumée, places avant, plafond à l'écran), règle de la bouche de fumée `fumee_valide` | non |
| `corps.py` | lignée MINCE : sole, caisson du foyer et GUEULE (signal fixe), `bouche_fumee` (signal fixe, quart nord-est, relevée), patins, bac ; aides de forme (`boite`, `tronc`, `briques_sud`, `rect_arrondi`, `couronne_poly`, `tube_v`, `cyl_v`) | oui |
| `piece.py` | variantes `e01-piece` (sous le four vanilla), `eNN-socle`, `eNN-piece`, témoin `kS-socle`, `kS-piece` ; préfixe des matières « four » | oui (build) |
| `profil.py` | profil des outils communs ; UNE pose (nommée « E ») ; référence vanilla `steel-furnace` (dump du lot dans `fo-logs/2026-10-25_F2/ref/`) | non |
| `rendre.py`, `batch_blender.py` | COPIES de `laser_e` (rendu par paquets sous le verrou, post-traitement) ; changent : pièce, noms `hr-four-…`, champ `kit`, bouche de fumée dans `spec.json`, pas de têtes | oui (batch) |
| `planche.py` | planches du DC : 15 âges par ère, ou mitrailleuse validée à côté du four | non |
| `ep00.py` | témoin : la lignée seule (caisson riveté, cheminée ronde) | oui |
| `ep01.py` à `ep15.py` | les 15 âges | oui |
| `tests/test_four.py` | tests hors Blender (`--sprites DIR` : bouches de fumée rendues) | non |

Commandes :
```
py -3.9 tools/render/pieces/levels/four_e/tests/test_four.py [--sprites DIR]
python tools/render/with_render_lock.py -- C:/Users/evan2/tools/blender-5.2.2/blender.exe -b --factory-startup -noaudio --python-exit-code 1 -P tools/render/pieces/levels/commun/construction.py -- --famille four_e --names e02-socle,e02-piece --out DIR/k.json
PYTHONUTF8=1 py -3.9 tools/render/pieces/levels/four_e/rendre.py --epochs 1,2,3 --parts socle,piece --apercu --samples 32 --out DIR
PYTHONUTF8=1 py -3.9 tools/render/pieces/levels/four_e/rendre.py --only e05-socle --samples 32 --out DIR      (avec halo de nuit)
py -3.9 tools/render/pieces/levels/commun/ilots.py --famille four_e --out DIR
py -3.9 tools/render/pieces/levels/four_e/planche.py --four DIR --mode ages|gun [--nuit] [--pair] --dest planche.png
```
