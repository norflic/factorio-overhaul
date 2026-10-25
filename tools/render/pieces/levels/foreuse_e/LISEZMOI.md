# Kit de famille de la FOREUSE ÉLECTRIQUE (`foreuse_e`, lot F4-A, 25/10/2026)

Suit le gabarit de `../commun/LISEZMOI.md` (« Faire une nouvelle famille ») ; n'a modifié AUCUN fichier de `../commun/`,
`../gun_e/` ni `../laser_e/`. Fiches des 15 âges (font foi) : `fo-logs/2026-10-25_F4/FICHES_FOREUSE.md` ; notes du lot :
`fo-logs/2026-10-25_F4/NOTES.md`. Aucun design n'est validé : le Directeur Créatif juge.

| Fichier | Rôle | Dans Blender ? |
|---|---|---|
| `cotes.py` | cotes de la lignée par taille (3 à 6), points de jeu (sortie du minerai, raccords, rayon d'extraction : règle de `shared/levels/points.lua`) | non |
| `epoques.py` | registre et CONTRAT des fichiers d'âge, emprise `COTE`, directions et angles, triplets « en 3 mots » `TRIPLETS` | non |
| `corps.py` | corps de lignée (tablier, montants, puits, goulotte et flèche, moteur, raccords, trépan, tour du témoin), repère des tuiles tourné (`repere`), outils de forme | oui |
| `piece.py` | variantes `e01-piece`, `eNN-N|E|S|O` (corps tourné), `eNN-piece` (pièce paire, une pour 4 directions), témoin `kS-…` ; préfixe « fore » | oui (build) |
| `profil.py` | profil des outils communs (contrat `commun/famille.py`) ; vanilla `electric-mining-drill` lu dans le dump du lot | non |
| `rendre.py`, `batch_blender.py` | COPIES de `laser_e` (rendu par paquets sous le verrou, post-traitement) ; noms `hr-fore-…`, toutes les passes | oui (batch) |
| `planche.py` | planches : âges côte à côte, jour et nuit, foreuse contre mitrailleuse validée (`--gun`) | non |
| `ep00.py` | témoin : la lignée seule | oui |
| `ep01.py` à `ep15.py` | les 15 âges | oui |
| `tests/test_foreuse.py` | tests hors Blender (points de jeu croisés avec `points.lua` par lua5.2) | non |

Commandes :
```
py -3.9 tools/render/pieces/levels/foreuse_e/tests/test_foreuse.py
PYTHONUTF8=1 py -3.9 tools/render/pieces/levels/foreuse_e/rendre.py --kit 3,6 --samples 16 --out DIR
PYTHONUTF8=1 py -3.9 tools/render/pieces/levels/foreuse_e/rendre.py --epochs 2,3 --parts N,E,piece --samples 32 --out DIR
py -3.9 tools/render/pieces/levels/commun/ilots.py --famille foreuse_e --out DIR --epochs 2,3
py -3.9 tools/render/pieces/levels/foreuse_e/planche.py --src DIR --ages 1,…,15 --poses N,E --jour-nuit --dest X.png
py -3.9 tools/render/pieces/levels/foreuse_e/planche.py --src DIR --gun --poses N --dest X.png
```
Aperçus du lot : `--samples 32` SANS `--apercu` (la planche de nuit a besoin de la passe halo).
