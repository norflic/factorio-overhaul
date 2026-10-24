# Kit de famille de la TOURELLE LASER (`laser_e`, lot F1-A, 24/10/2026)

Kit gelé AVANT les rondes de lecture (familles.md §3.4), APRÈS son quatrième jet (correction du lot F1-A, 24/10 : proue
et flèches de joues pour montrer la direction de tir, tourillons petits et mats, caisson arrière bas et étroit, paliers
sous l'axe, anneau penché fermé par un diaphragme, options de silhouette de l'affût `contour`, `rayons`, `pilotis`,
`interstice`, `etoiles`, et MAQUETTES des 14 affûts `epoques.MAQUETTES` / variantes `mNN-…`). Il suit le gabarit de
`../commun/LISEZMOI.md` (« Faire une nouvelle famille ») et n'a modifié AUCUN fichier de `../commun/` ni de `../gun_e/`
(designs validés de la mitrailleuse ; preuve du lot, hors du kit : `fo-logs/2026-10-24_F1/outils/preuve_intact.py`).

Fiches des 15 âges (font foi) : `fo-logs/2026-10-24_F1/FICHES_LASER.md`. Rondes préparées : `fo-logs/2026-10-24_F1/RONDES.md`.

| Fichier | Rôle | Dans Blender ? |
|---|---|---|
| `epoques.py` | registre et CONTRAT des fichiers d'âge du laser (emplacements, clés d'habillage propres : `cerclages`, `forme_affut` (dont `contour`, `rayons`, `pilotis`, `interstice`, `etoiles`), `forme_tete`, `condensateurs`), emprise `COTE`, triplets « en 3 mots » `TRIPLETS` (relus contre la pose E), MAQUETTES des 14 affûts `MAQUETTES` et module maquette `maquette(N)` | non |
| `cotes.py` | cotes de la lignée par taille (affût, pivot, condensateurs, tête, enveloppe de l'émetteur, places), proue, contours (`facteur_contour`, `profil_contour`), historique des 4 jets | non |
| `corps.py` | corps de lignée : affût rond à gradins, couronne de condensateurs, pivot, liaisons radiales, patin ; options de silhouette (contour, interstice, pilotis, étoiles, rayons) ; tête : platine, PROUE, support (étrier et berceau à flèches de joues et paliers, anneau penché à diaphragme et `dans_anneau`, fourche), caisson arrière bas, lentille, émetteur du témoin ; `FO_LASER_SANS=emetteur` (contrôle seulement) | oui |
| `piece.py` | variantes `e01-piece`, `eNN-socle`, `eNN-piece`, `eNN-tete-N|E`, `eNN-tete-dKK` (à la demande, d00 = nord, sens horaire), témoin `kS-…`, maquettes `mNN-socle|tete-N|tete-E|tete-dKK` (N = 2 à 15) ; préfixe des matières « lase » | oui (build) |
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
PYTHONUTF8=1 py -3.9 tools/render/pieces/levels/laser_e/rendre.py --apercu --samples 32 --only m02-socle,m03-socle --out DIR
PYTHONUTF8=1 py -3.9 tools/render/pieces/levels/laser_e/rendre.py --apercu --samples 32 --epochs 15 --parts "" --dirs rose --out DIR
py -3.9 tools/render/pieces/levels/commun/apercu.py --famille laser_e --out DIR --epochs k2,3,9,15 --zoom 2 --dest planche.png
py -3.9 tools/render/pieces/levels/laser_e/planche_gun.py --laser DIR --ages 1,3,9,15 --zoom 1 --dest planche.png
```
