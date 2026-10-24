# Kit de famille de la TOURELLE LASER (`laser_e`, lot F1-A, 24/10/2026)

Kit gelé AVANT les rondes de lecture (familles.md §3.4). Il suit le gabarit de `../commun/LISEZMOI.md` (« Faire une
nouvelle famille ») et n'a modifié AUCUN fichier de `../commun/` ni de `../gun_e/` (designs validés de la mitrailleuse ;
contrôle : `tests/test_laser.py`, `git diff main...HEAD` vide sur ces deux dossiers).

Fiches des 15 âges (font foi) : `fo-logs/2026-10-24_F1/FICHES_LASER.md`. Rondes préparées : `fo-logs/2026-10-24_F1/RONDES.md`.

| Fichier | Rôle | Dans Blender ? |
|---|---|---|
| `epoques.py` | registre et CONTRAT des fichiers d'âge du laser (emplacements, clés d'habillage propres : `cerclages`, `forme_affut`, `forme_tete`, `condensateurs`), emprise `COTE`, triplets « en 3 mots » `TRIPLETS` | non |
| `cotes.py` | cotes de la lignée par taille (affût, pivot, condensateurs, tête, enveloppe de l'émetteur, places), historique des 3 jets | non |
| `corps.py` | corps de lignée : affût rond à gradins, couronne de condensateurs, pivot, liaisons radiales, patin ; tête : platine, support (étrier, berceau, anneau, fourche), caisson arrière, lentille, émetteur du témoin | oui |
| `piece.py` | variantes `e01-piece`, `eNN-socle`, `eNN-piece`, `eNN-tete-N|E`, `eNN-tete-dKK` (à la demande, d00 = nord, sens horaire), témoin `kS-…` ; préfixe des matières « lase » | oui (build) |
| `profil.py` | profil des outils communs (contrat `commun/famille.py`) ; référence vanilla `laser-turret` | non |
| `rendre.py`, `batch_blender.py` | COPIES de `gun_e` (rendu par paquets sous le verrou, post-traitement) ; seuls changent la pièce rendue, les noms `hr-lase-…`, le champ `kit` | oui (batch) |
| `planche_gun.py` | planche « mitrailleuse validée | laser » du même âge | non |
| `vignettes_mixte.py` | 30 vignettes numérotées mêlées « laser ou mitrailleuse ? » (clé sur la sortie standard) | non |
| `ep00.py` | témoin : la lignée seule | oui |
| `ep01.py`, `ep03.py`, `ep09.py`, `ep15.py` | âges d'ESSAI (aperçus du lot F1-A), exemples du contrat, à reprendre par les constructeurs | oui |
| `tests/test_laser.py` | tests du kit hors Blender | non |

Les 11 autres fichiers d'âge (`ep02`, `ep04` à `ep08`, `ep10` à `ep14`) sont à écrire par les constructeurs des rondes.

Commandes :
```
py -3.9 tools/render/pieces/levels/laser_e/tests/test_laser.py
python tools/render/with_render_lock.py -- C:/Users/evan2/tools/blender-5.2.2/blender.exe -b --factory-startup -noaudio --python-exit-code 1 -P tools/render/pieces/levels/commun/construction.py -- --famille laser_e --names k2-socle,k2-tete-E --out DIR/k.json
PYTHONUTF8=1 py -3.9 tools/render/pieces/levels/laser_e/rendre.py --kit 2,4,6 --apercu --samples 32 --per 9 --out DIR
PYTHONUTF8=1 py -3.9 tools/render/pieces/levels/laser_e/rendre.py --ronde 1,3,9,15 --out DIR
py -3.9 tools/render/pieces/levels/commun/apercu.py --famille laser_e --out DIR --epochs k2,3,9,15 --zoom 2 --dest planche.png
py -3.9 tools/render/pieces/levels/laser_e/planche_gun.py --laser DIR --ages 1,3,9,15 --zoom 1 --dest planche.png
```
