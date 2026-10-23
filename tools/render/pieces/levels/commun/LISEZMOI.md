# Kit commun des familles (lot K0, 23/10/2026)

Ce dossier contient ce que la mitrailleuse (`../gun_e`) a construit et qui sert à TOUTES les familles de bâtiments à
niveaux : laser, four, assembleur, foreuse, centre, mur. Il a été sorti de `gun_e` **sans changer une valeur**. La
preuve : `construction.py --tout --forte` donne la même empreinte FORTE (scène entière, lumières de halo comprises,
matrices, modificateurs, maillage évalué, matières complètes, appels de matières et graines) sur les 72 variantes de la
mitrailleuse et sur les habillages d'essai, avant le lot (`93e3d89`) et après sa correction. Journal :
`fo-logs/2026-10-23_suite/K0/` (preuves de la correction : `K0/correction/`).

Les designs de la mitrailleuse sont validés par le Directeur Créatif (23/10, 14 h 50). Toute retouche d'un fichier de
ce dossier doit garder ces empreintes identiques (voir « Contrôle » plus bas).

**Ce qui n'est pas identique, sans effet** (dit franchement) : l'ordre des clés de `HABILLAGE` dans les fichiers d'âge
(les clés communes viennent en tête ; valeurs et habillage fusionné identiques) et l'ordre d'insertion des clés du
dictionnaire `M` aux âges 10 et 12 (alias de rôle posés après les matières de l'âge ; appels `metal()` et graines dans
l'ordre d'origine ; aucun code ne parcourt `M` dans l'ordre).

**Graines de bruit inertes** (fait découvert à la vérification de K0, antérieur au lot) : dans Blender 5.2.2, la prise
W d'un bruit 3D est inactive et `"W" in noeud.inputs` rend faux. Le passage en bruit 4D de `fo_scene.mat_metal`,
`mat_emissive` et `kit._insert_stain` / `_insert_streaks` ne se fait donc jamais : aucune graine n'est appliquée, et
les matières de même échelle de grain ont le même motif. L'ordre des appels `metal()` garde quand même les graines
d'origine (contrôlé par `--forte`). **Ne pas corriger sans le Directeur Créatif** : rendre les graines actives
changerait tous les designs validés.

## Ce qu'il y a ici

| Fichier | Rôle | Dans Blender ? |
|---|---|---|
| `kit.py` | matières de la lignée et bibliothèque d'accents, règle de reflets (`REFLETS`), accumulateur de géométrie `Geo`, `PREFIXE` des noms de matière | oui |
| `parts.py`, `parts2.py`, `parts3.py` | pièces industrielles : caissons, poutres, caillebotis, colonnes à goussets, moteurs, réservoirs, radiateurs, trémie, armoires, vannes, manomètres, échelles, conduits | oui |
| `formes.py` | accessoires d'âge : cristal, trèfle, isolateurs, lanterne, briques, volant, fût, octogones, parabole, anneaux, hublots, nappes de câbles | oui |
| `silhouettes.py` | contours et hauteurs des FORMES (pont, coupole, jupe, trémie), Python pur | non |
| `repere.py` | `Y(yn)` (y de jeu vers le nord), `at(g, x, yn, rz)` (repère posé) | oui |
| `habillage.py` | habillage de MATIÈRE d'un corps de lignée : `HABILLAGE_LIGNEE` (clés communes), `habillage(ep, defaut)`, `mats_habilles`, `habille`, `@_lignee`, `mat`, `capot` | non (pur) |
| `pont.py` | motifs du pont (caillebotis, planches, dalles, tôles), liseré, tables des formes de pont, hasard local, parapets, garde-corps, filets, flancs, troncs | oui |
| `places.py` | solveur des places libres (distances, meilleure place, dégagements, hauteur libre), lecture des littéraux d'un fichier d'âge | non (pur) |
| `ages.py` | **registre des 15 âges** : noms (13 Antimatière, 14 La Porte, 15 Néant), ères, familles de couleur des foyers, palette 60/30/10 de chaque âge (table explicite `PALETTE`), foyers et matières (`FOYER`, `CORPS`, `matieres`, `palette`) | non (pur) |
| `famille.py` | profil d'une famille pour les outils (contrat de `profil.py`) ; oublie les modules d'une autre famille avant d'en charger une | non |
| `tests/test_famille.py` | test du choix de famille, `--famille` contre `FO_FAMILLE`, avec la famille factice `tests/fam_essai` | non |
| `compo.py` | composition hors moteur (sol, ombres, lueur, nuit) | non |
| `ilots.py` | îlots et trous enfermés, **bloquant** | non |
| `gris.py` | test de FORME en gris entre âges voisins de même taille | non |
| `mesures.py` | charte, familles de foyers, points blancs, pièce paire | non |
| `dominance.py` | progression de puissance, vanilla en tête | non |
| `vignettes.py` | vignettes lettrées d'une ronde de lecture ; jeux nommés EXACTEMENT « E », « G », « N » | non |
| `apercu.py` | planche d'aperçu | non |
| `construction.py` | empreinte de construction sans rendu (géométrie ; matières avec `--matieres` ; empreinte FORTE avec `--forte`, celle du contrôle) | oui |
| `empreintes.py` | comparaison de deux empreintes | non |

Restent dans `gun_e`, car propres à la mitrailleuse :
- `corps.py` (corps de lignée : colonne, trémie, tête, canons) ;
- `cotes.py` ;
- `accroches.py` (ses obstacles et ses places) ;
- `epNN.py` ;
- `epoques.py` (contrat, emprise `COTE`, clés propres de `HABILLAGE_DEFAUT`) ;
- `piece.py`, `rendre.py`, `batch_blender.py`, `habillages.py`, `corps_choix.py` ;
- `profil.py`.

## Faire une nouvelle famille (exemple : `four_e`)

1. **Dossier** `tools/render/pieces/levels/four_e/`, frère de `commun/` et de `gun_e/`.
2. **Chemins.** Le module que `piece.py` importe en premier (`epoques.py` dans `gun_e`) met `../commun` dans
   `sys.path` (copier le bloc « LOT K0 » d'en-tête de `gun_e/epoques.py`). `batch_blender.py` fait de même avant
   `import kit`. Aucun fichier de la famille ne doit porter le nom d'un module de `commun/`.
3. **Corps de lignée** (`corps.py` de la famille) :
   - le SQUELETTE de la famille : emprise, raccords, points de jeu, organe principal et organe de liaison
     (catalogue §D.2 ; §D.3 de l'ère V : `fo-logs/2026-10-23_suite/K0/D3_ere_V.md`) ;
   - il dessine avec `kit.Geo`, `parts*`, `formes` et `pont` ;
   - il pose ses pièces de lignée sous `@_lignee` (ou `with habille(g, c)`), pour que l'habillage de l'âge s'applique ;
   - son `Ctx` porte au moins `M`, `Mh = mats_habilles(g.M, hab)`, `pont = pont_cfg(hab)`, `hab`.
4. **Habillage.** `HABILLAGE_DEFAUT` de la famille = ses clés propres + `**habillage.HABILLAGE_LIGNEE` + ses formes.
   `epoques.habillage(ep)` appelle `habillage.habillage(ep, HABILLAGE_DEFAUT)`.
5. **Fichiers d'âge** `epNN.py`. Un même âge = la même matière et la même lumière que la mitrailleuse :
   ```python
   import ages
   FOYER = ages.FOYER[5]
   HABILLAGE = dict(ages.CORPS[5], <clés propres au four>)
   def matieres(metal, M):
       ages.matieres(5, metal, M)        # matières de l'âge, ordre d'appel d'origine (graines de bruit)
       M["gueule"] = M["fonte_noire"]    # alias de rôle propres au four (jamais un nouvel appel metal() ici
                                         # pour une matière de l'âge : il décalerait les graines)
   ```
   - La palette 60/30/10 de l'âge est la table `ages.PALETTE[5]` : `dominante`, `secondaire`, `accent` (matières,
     la première est la principale) et `lumiere` (l'accent lumineux, le foyer), avec la `source` de chaque ligne.
     `ages.palette(5)` la rend avec, à part, les `capots` du corps de lignée, l'acier, le pont et le `foyer`.
     Attention : les capots ne sont PAS toujours la dominante et la secondaire (âges 3, 11 et 15).
   - Âge 7 : la secondaire (pierre claire) est DÉDUITE de la ronde 1, non dite par le DC (voir `source`).
   - Ne jamais modifier une valeur de `ages.py` : ce serait changer la mitrailleuse validée.
   - Un âge qui veut une variante crée une matière de plus dans SON `matieres`, après `ages.matieres`.
6. **Profil** `profil.py` (contrat complet en tête de `commun/famille.py`). Il donne :
   - les noms des variantes et les parties ;
   - les poses ;
   - la composition d'un niveau (`level_layers`) ;
   - le bâtiment vanilla de référence (`REF_VANILLA`). Il doit être mesuré dans `docs/da/mesures_vanilla.json`, sinon
     `dominance.py` refuse. Le mur (`stone-wall`) n'y est PAS encore ;
   - les cibles de la charte ;
   - les variantes d'une vignette et d'une ronde ;
   - les trous voulus.

   Exemple complet : `gun_e/profil.py`.
7. **Outils.** Tous les outils prennent `--famille four_e`, ou la variable `FO_FAMILLE=four_e` :
   ```
   py -3.9 tools/render/pieces/levels/commun/ilots.py --famille four_e --out DIR
   py -3.9 tools/render/pieces/levels/commun/gris.py --famille four_e --out DIR --pose E,N --planche gris.png
   py -3.9 tools/render/pieces/levels/commun/mesures.py --famille four_e --out DIR --json mesures.json
   py -3.9 tools/render/pieces/levels/commun/dominance.py --famille four_e --mesures mesures.json
   py -3.9 tools/render/pieces/levels/commun/vignettes.py --famille four_e --dest …/vignettes-E --src DIR --jeu E
   ```
   - Sans `--famille`, les outils travaillent sur `gun_e`, comme avant le lot K0.
   - `--famille` et `FO_FAMILLE` donnent le même résultat : `famille.charger` oublie les modules d'une autre famille
     déjà importés (`compo.py` charge `gun_e` à l'import) avant de charger le profil. Preuve :
     `py -3.9 tools/render/pieces/levels/commun/tests/test_famille.py` → « [K0-FAMILLE] 12 OK, 0 ECHEC(S) ».
     Un outil ne doit donc garder aucune référence à un module d'une famille après `K.utiliser(...)`.
   - Le rendu de ronde (`rendre.py --ronde`) lit `profil.ronde(e)`.

## Contrôle (à refaire après toute retouche du kit commun)

Toujours par le verrou de rendu (interdit n° 6) :
```
python tools/render/with_render_lock.py -- C:/Users/evan2/tools/blender-5.2.2/blender.exe -b --factory-startup
    -noaudio --python-exit-code 1 -P tools/render/pieces/levels/commun/construction.py --
    --famille gun_e --tout --forte --matieres --out APRES.json
py -3.9 tools/render/pieces/levels/commun/empreintes.py AVANT.json APRES.json --forte --matieres
```
- Attendu : « [FO-EMPREINTES] 72 variantes comparées, 0 différente(s), 0 absente(s) (forte) », code 0.
- Sans `--forte`, l'empreinte ne voit ni les lumières de halo, ni la position ou la rotation des objets, ni les
  modificateurs, ni les graines : un mutant « halos × 1,5 » passait (vérification de K0). Toujours `--forte`.
- Habillages d'essai : `--habillages f_forge,f_vapeur,… --forte` (constructions du témoin), comparées par
  `empreintes.py AVANT.json APRES.json --forte` (sans `--matieres`, que le mode `--habillages` n'écrit pas en détail).
- Durées mesurées le 23/10 (sans rendu) : 72 variantes `--forte --matieres` en 213 s ; 165 constructions
  d'habillages `--forte` en 376 s (journaux dans `fo-logs/2026-10-23_suite/K0/correction/`).
- Empreinte « avant » d'une version archivée : extraire `git archive <commit> tools/render`, recopier le
  `construction.py` actuel dans `pieces/levels/commun/` de l'archive, puis le lancer depuis l'archive avec
  `--famille gun_e`. `--dossier CHEMIN` construit un dossier de famille ailleurs (le dossier passe devant `commun/`).

## Nommage des jeux du test à l'aveugle final

| Jeu | Couleur | Pose | Dossier |
|---|---|---|---|
| « E » | couleur | E | `vignettes-E` |
| « G » | gris | E | `vignettes-G` |
| « N » | couleur | N | `vignettes-N` |

- `vignettes.py --jeu E|G|N` règle la pose et le gris, et écrit `"nom"` dans la clé JSON.
- L'outil refuse un dossier `vignettes-X` qui ne porte pas le nom de son jeu.
- Le compositeur recopie le champ `nom` tel quel. À la passe 5, le test final n'a pas été fait faute de ces noms exacts.
