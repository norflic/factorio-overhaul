# CLAUDE.md : Factorio Overhaul (« Factorio V2 »), mode d'emploi de reprise

Mod de **conversion totale** pour **Factorio 1.1.91**. Ce fichier contient les règles, les chemins, les
commandes et les pièges à connaître. **La vérité sur les attentes est dans `OBJECTIFS.md`** : lisez-le
avant tout travail.

## 1. Rôles et ton
- L'utilisateur (Evan) est le **Directeur Créatif**. Il décide du contenu, du design et des priorités.
- Vous êtes **Architecte Principal & Lead R&D**. Vous répondez **en français**.
- **Jamais complaisant** : un défaut, même le vôtre, se dit et s'écrit dans OBJECTIFS.md.
- Standard de preuve : « Si tu ne peux pas m'assurer que tout fonctionne, c'est que le travail n'est
  donc pas terminé. » Rien n'est terminé sans preuve en **moteur réel**, et sans captures pour ce qui
  se voit.
- Le Directeur Créatif juge le visuel sur capture : **seul son verdict valide un design** (critères
  D1 à D3 d'OBJECTIFS.md).

## 2. Lecture obligatoire, dans cet ordre
1. `OBJECTIFS.md` : demandes citées, critères d'acceptation, état réel, questions ouvertes, feuille de
   route, lots multi-agents (§7).
2. `ARCHITECTURE.md` : §2 règles non négociables, §7 bis niveaux, §8 bancs de vérification.
3. `BALANCE_SHEET.md` : chiffres. §12 niveaux (courbe provisoire, à refaire pour les 15 époques).
4. `RD_LOG.md` : faits moteur F1 à F43, expériences E1 à E25, hypothèses ouvertes (H-V1, H-L1, H-T1,
   H-B1, H-E1). Prochains identifiants : **F44, E26**.

## 3. Chemins (PC Windows du Directeur Créatif)
| Quoi | Chemin |
|---|---|
| Racine du jeu (installation portable) | `H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\` |
| Source du mod (ce dossier) | `<racine>\mods\factorio-overhaul\` |
| Exécutable | `<racine>\bin\x64\factorio.exe` |
| Données du jeu (banc de l'étape data) | `<racine>\data\` (Lua lisible de `core` et `base`) |
| Documentation API 1.1.91 | `<racine>\doc-html\` (`runtime-api.json`, `prototype-api.json`) |
| Bancs en moteur réel | `<racine>\fo-autotest.bat`, `fo-visual.bat`, `fo-autotest-watch.bat` (sources dans `tools\autotest\` : recopier à la racine après modification) |
| Résultats du banc | `<racine>\fo-autotest\` : `create.log`, `benchmark.log`, `benchmark-stdout.txt`, `done.txt` |
| Captures | `<racine>\fo-visual\write\script-output\fo-shots\` |

## 4. Interdits absolus (protègent le jeu et les parties du Directeur Créatif)
1. **Ne jamais toucher** à `<racine>\saves\`, `<racine>\config\`, `player-data.json`,
   `achievements*.dat`, `blueprint-storage.dat`, ni à `<racine>\mods\mod-list.json` et aux autres mods.
2. **Ne jamais lancer `factorio.exe` directement.** Passer uniquement par `fo-autotest.bat` ou
   `fo-visual.bat`, qui utilisent des dossiers d'écriture et de mods SÉPARÉS.
3. **Ne jamais arrêter tous les `factorio.exe`** : le Directeur Créatif peut être en partie. Pour
   fermer la session de test, ciblez sa ligne de commande (qui contient `fo-visual`), par exemple :
   `Get-CimInstance Win32_Process -Filter "Name='factorio.exe'" | ? CommandLine -like '*fo-visual*' | Invoke-CimMethod -MethodName Terminate`
4. **Un seul banc à la fois.** `fo-autotest.bat` prend le verrou `<racine>\fo-autotest.lock` et
   **efface `fo-autotest\`** à chaque lancement : copiez vos journaux avant le banc suivant. Un verrou
   orphelin (aucun `factorio.exe` dont la ligne de commande contient `fo-autotest`) se supprime avec
   `rmdir`.
5. Aucune donnée personnelle, aucun identifiant, rien à publier.

## 5. Commandes
Toutes les commandes se lancent depuis la racine du mod, sauf mention.

**Bancs hors jeu** (Lua 5.2 ; sous Windows, le binaire peut s'appeler `lua52.exe` ou `lua.exe`, à
installer s'il manque, par exemple LuaBinaries 5.2.4). Résultats attendus aujourd'hui :
```
lua5.2 tests/run.lua             -> 114 OK
lua5.2 tests/war_test.lua        -> 86 OK
lua5.2 tests/td_test.lua         -> 270 OK
lua5.2 tests/pteam_test.lua      -> 15 OK
lua5.2 tests/migration_test.lua  -> 12 OK
lua5.2 tests/levels_test.lua     -> 556 OK
lua5.2 tests/datastage/harness.lua "<racine>/data" .   -> 0 nouvelle erreur (--dump-proto type/nom, --dump-final type/nom, --verbose)
python tools/api_lint.py "<racine>/doc-html" "<chemin absolu du mod>"   -> 0 erreur
```

**Banc en moteur réel** (sans affichage, environ 1 à 2 min pour `content`) :
1. Écrire `<ticks> <scenario>` dans `<racine>\fo-autotest-params.txt`, par exemple `4000 content`.
2. Lancer `<racine>\fo-autotest.bat nopause 4000`. L'appel est bloquant ; `done.txt` marque la fin.
3. Lire le résultat avec `grep "\[FO-CONTENT\]" fo-autotest\create.log fo-autotest\benchmark.log`. On
   attend `BILAN : 180 OK, 0 ECHEC(S)` (21/10).

Scénarios :
- `default` : guerre à économie réelle et compagnons ;
- `content` : banc de contenu, 180 contrôles ;
- `waves` : défense de tours et guerre ;
- `pteam` : équipe du joueur ;
- `stress` : 402 agents ;
- `baseline`, `noexp`, `peace`, `parked`, `worker`.

Performance :
- La commande est `python tools/autotest/analyze.py "<racine>\fo-autotest" --spikes`.
- Surveiller l'étalon `[FO-CALIB]`. Le processeur est hybride (F30) : le banc est épinglé sur les
  cœurs P. Une mesure prise en arrière-plan sans épinglage est fausse.

**Banc visuel** (après un banc `fo-autotest`, car il réutilise sa carte et ses mods) :
- Lancer `<racine>\fo-visual.bat`.
- Le mod de test place la caméra et capture automatiquement (`tools/autotest/fo-autotest/shots.lua`),
  de jour, de nuit et en vue haute.
- Les captures sont numérotées dans `fo-shots\`.
- Il faut ensuite fermer la session (interdit n° 3). Les automatiser entièrement est l'objet de
  H-T1 / lot P1.

`fo-autotest-watch.bat` (surveillance d'un fichier de requête) servait aux sessions cloud. Il est
inutile dans Claude Code : lancez le `.bat` directement.

## 6. Règles de code (ARCHITECTURE §2, résumé)
- Cycle settings → data → control. `control.lua` ne contient que des `require`. Les abonnements aux
  événements sont statiques (bus `Events`).
- `on_load` ne modifie jamais `global`. `global` n'est nommé que dans `script/core/storage.lua`
  (marqueur PORT-2.0).
- **Déterminisme** :
  - aucun ordre de `pairs` : on itère toujours sur des listes triées ;
  - RNG maison, pas de trigonométrie dans la simulation ;
  - aucune décision pilotée par un temps mesuré ;
  - jamais de fonction dans `global`.
- `shared/` contient du Lua PUR (données et règles, testables hors jeu). `prototypes/` génère, et
  `script/` exécute.
- `require` est interdit pendant un événement (F24).
- Traductions FR et EN obligatoires. Un paramètre de `localised_name` de prototype doit être une
  chaîne (F43).

## 7. Pièges moteur déjà payés (détails dans RD_LOG)
- **F21** : les bonus de recherche des tourelles sont attachés au NOM. Une copie doit les recevoir
  (`data-final-fixes.lua`).
- **F23** : une RotatedAnimation à plusieurs fichiers exige `slice`.
- **F29** : un personnage qui fabrique une arme ou des munitions les équipe automatiquement.
- **F30** : sur processeur hybride, le banc doit être épinglé sur les cœurs P.
- **F33** : ne jamais « ouvrir » Factorio par un outil de contrôle du PC, car cela lance une seconde
  instance sur la vraie configuration.
- **F34** : l'introduction de « freeplay » met le jeu en pause (coupée par le mod de test).
- **F35** : `global` est propre à chaque mod ; un chunk en bord de zone n'a que ses tuiles.
- **F36 et F38** : une teinte ne fait que MULTIPLIER. Mesurez la couleur réelle d'une texture avant de
  la choisir.
- **F37** : la copie lumineuse d'un masque fin ne se voit pas. Utilisez un halo `draw_as_light` ou une
  vraie couche alpha.
- **F39** : `create_entity{fast_replace=true, spill=false, raise_built=true}` conserve contenu, recette
  et munitions. Cela exige un `fast_replaceable_group` commun.
- **F40** : `raise_built` appelle nos gestionnaires de façon synchrone. Si l'entité y est détruite,
  `create_entity` renvoie `nil`.
- **F41** : `find_entity` sur une entité 1×1 doit viser le centre de la tuile (x,5).
- **F42** : un socle sous un sprite qui couvre toute l'emprise est invisible. Il faut des pièces qui
  DÉPASSENT la silhouette.

## 8. Discipline documentaire (exigence R6 : « notez bien tout »)
Après chaque lot, et avant de déclarer quoi que ce soit terminé :
1. **OBJECTIFS.md** : état, preuve, date de chaque objectif touché. Une réponse du Directeur Créatif
   s'inscrit dans le §4, citée mot pour mot.
2. **RD_LOG.md** : décisions (citées), faits moteur `F44+`, expériences `E26+` (protocole, résultat
   chiffré), hypothèses.
3. **ARCHITECTURE.md** pour toute structure nouvelle, **BALANCE_SHEET.md** pour tout chiffre nouveau,
   et `changelog.txt`.

Le projet claude.ai « Factorio moding » garde une copie de ces documents (`claude/*.md`). Quand c'est
possible, mettez-la à jour ; sinon, signalez au Directeur Créatif qu'elle est en retard.

## 9. Travail multi-agent
- Le découpage en lots, les dépendances et les fichiers possédés par chaque lot sont dans OBJECTIFS.md
  §7.
- **Un seul intégrateur** touche les fichiers partagés : `data.lua`, `control.lua`, `settings.lua`,
  `info.json`, `shared/levels/config.lua` et les documents.
- Chaque lot a ses propres fichiers de traduction : `locale/fr/<lot>.cfg`, `locale/en/<lot>.cfg`.
- Le banc en moteur réel est **séquentiel** (interdit n° 4).
- Fichiers orphelins sur le PC : `script/faction/engineer.lua` et `tools/sim_war.lua` datent des
  sessions 2-3 et ne sont chargés par rien (`control.lua` ne les requiert pas). Au lot P0, vérifiez-le
  par un `grep`, puis supprimez-les.
- Le dépôt git est à créer au lot P0 : `git init` dans ce dossier, avec le `.gitignore` fourni. Il est
  indispensable aux worktrees des agents.
