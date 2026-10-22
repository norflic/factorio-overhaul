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
0. **`REPRISE.md`** : où en est le projet, ce qui tourne, quoi faire ensuite (à lire EN PREMIER par un
   orchestrateur qui reprend ; à mettre à jour à chaque jalon).
1. `OBJECTIFS.md` : demandes citées, critères d'acceptation, état réel, questions ouvertes, feuille de
   route, lots multi-agents (§7).
2. `ARCHITECTURE.md` : §2 règles non négociables, §7 bis niveaux, §8 bancs de vérification.
3. `BALANCE_SHEET.md` : chiffres. §12 niveaux (courbe provisoire, à refaire pour les 15 époques).
4. `RD_LOG.md` : faits moteur F1 à F69, expériences E1 à E41, hypothèses ouvertes (H-V2, H-X1, H-L1,
   H-B1, H-E1 ; H-T1 et H-V1 validées). Prochains identifiants : **F70, E42**.

## 3. Chemins (PC Windows du Directeur Créatif)
| Quoi | Chemin |
|---|---|
| Racine du jeu (installation portable) | `H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\` |
| Source du mod (ce dossier) | `<racine>\mods\factorio-overhaul\` |
| Exécutable | `<racine>\bin\x64\factorio.exe` |
| Données du jeu (banc de l'étape data) | `<racine>\data\` (Lua lisible de `core` et `base`) |
| Documentation API 1.1.91 | `<racine>\doc-html\` (`runtime-api.json`, `prototype-api.json`) |
| Bancs en moteur réel | `<racine>\fo-autotest.bat`, `fo-visual.bat`, `fo-captures.bat`, `fo-autotest-watch.bat` (sources dans `tools\autotest\` : recopier les `.bat` à la racine après modification ; mode d'emploi complet : `tools\autotest\README.md`) |
| Résultats du banc | `<racine>\fo-autotest\` : `create.log`, `benchmark.log`, `benchmark-stdout.txt`, `done.txt` |
| Captures | `<racine>\fo-visual\write\script-output\fo-shots\` : `NNN-<scène>.png`, `index.txt`, `planche-NN.png`, `session.txt` |
| Rendu 3D (lot V0) | Blender 5.2.2 LTS : `C:\Users\evan2\tools\blender-5.2.2\blender.exe` ; pipeline : `tools\render\README.md`, `tools\render\CALIBRATION.md` |

## 4. Interdits absolus (protègent le jeu et les parties du Directeur Créatif)
1. **Ne jamais toucher** à `<racine>\saves\`, `<racine>\config\`, `player-data.json`,
   `achievements*.dat`, `blueprint-storage.dat`, ni à `<racine>\mods\mod-list.json` et aux autres mods.
2. **Ne jamais lancer `factorio.exe` directement.** Passer uniquement par `fo-autotest.bat` ou
   `fo-visual.bat`, qui utilisent des dossiers d'écriture et de mods SÉPARÉS.
3. **Ne jamais arrêter tous les `factorio.exe`** : le Directeur Créatif peut être en partie. Pour
   fermer la session de test, ciblez sa ligne de commande (qui contient `fo-visual`), par exemple :
   `Get-CimInstance Win32_Process -Filter "Name='factorio.exe'" | ? CommandLine -like '*fo-visual*' | Invoke-CimMethod -MethodName Terminate`
   Depuis le lot P1, `fo-visual.bat` ferme lui-même sa session : d'abord le PID qu'il a lancé, puis tout
   `factorio.exe` dont la ligne de commande contient le chemin complet du dossier `fo-visual`.
4. **Un seul banc à la fois.** `fo-autotest.bat`, `fo-visual.bat` et `fo-captures.bat` partagent le verrou
   `<racine>\fo-autotest.lock` (code de sortie 2 s'il est pris). `fo-autotest.bat`
   **efface `fo-autotest\`** à chaque lancement : copiez vos journaux avant le banc suivant. Un verrou
   orphelin (aucun `factorio.exe` dont la ligne de commande contient `fo-autotest`) se supprime avec
   `rmdir`.
5. Aucune donnée personnelle, aucun identifiant, rien à publier.
6. **Blender uniquement par le verrou de rendu** : `python tools/render/with_render_lock.py -- <commande>`.
   Au plus 2 rendus à la fois sur le PC, en priorité inférieure à la normale pour ne pas gêner une partie
   en cours. Le verrou est `<racine>\fo-render.lock.<k>` ; un verrou orphelin est repris tout seul.

## 5. Commandes
Toutes les commandes se lancent depuis la racine du mod, sauf mention.

**Bancs hors jeu** (Lua 5.2.4, compilé le 21/10 depuis la source officielle de lua.org, sommes
vérifiées, avec le gcc de `C:\mingw64` : `C:\Users\evan2\bin\lua5.2.exe`. Ce dossier est dans le PATH
de Git Bash, donc `lua5.2` y fonctionne tel quel ; sous PowerShell, donner le chemin complet).
Résultats attendus aujourd'hui :
```
lua5.2 tests/run.lua             -> 114 OK
lua5.2 tests/war_test.lua        -> 92 OK
lua5.2 tests/td_test.lua         -> 270 OK
lua5.2 tests/pteam_test.lua      -> 15 OK
lua5.2 tests/migration_test.lua  -> 29 OK
lua5.2 tests/levels_test.lua     -> 1459 OK   (+ 11 « écarts connus » au contrat, comptés à part ; rejoue aussi le harness, environ 4 s ; --tables : BALANCE_SHEET §12 ; --calibrate : courbe recalculée sur le calendrier X0 depuis un état de référence fixe)
lua5.2 tests/pvp_test.lua        -> 596 OK   (environ 4 min 30 ; "pure" en argument : 502 OK, partie pure seule)
lua5.2 tests/epochs_test.lua     -> 16665 OK (graphe de fabrication du lot X0)
lua5.2 tests/org_test.lua        -> 362 OK   (modèle des rôles des équipes de PNJ, lot IA1)
lua5.2 tests/datastage/harness.lua "<racine>/data" .   -> 0 nouvelle erreur (--dump-proto type/nom, --dump-final type/nom, --verbose)
python tools/api_lint.py "<racine>/doc-html" "<chemin absolu du mod>"   -> 381 usages, 0 erreur (mod de test compris ; chaînes et commentaires ignorés depuis le 21/10)
python -B tools/autotest/tests/run_d4m.py --logs "<racine>/fo-logs"   -> 5/5 étapes (banc D4m hors jeu)
```

**Banc en moteur réel** (sans affichage ; `content` à 4 000 ticks : environ 5 s en tout, mesuré le 21/10) :
1. Écrire `<ticks> <scenario> [source du mod]` dans `<racine>\fo-autotest-params.txt`, par exemple
   `4000 content`. La source (chemin absolu, espaces permis) est facultative : par défaut
   `<racine>\mods\factorio-overhaul` ; on y met le chemin d'un worktree pour tester un lot avant de
   l'intégrer. La copie exclut `.git`, `.claude` et `tools\render`. `fo-autotest\source.txt` dit quelle
   source a été testée.
2. Lancer `<racine>\fo-autotest.bat nopause 4000`. L'appel est bloquant ; `done.txt` marque la fin.
   Depuis Git Bash : `cd "<racine>" && ./fo-autotest.bat nopause 4000` (`cmd //c` ne le trouve pas).
   **Code de sortie 2 = verrou pris, rien n'a tourné** : `fo-autotest\` contient alors les journaux du
   banc PRÉCÉDENT. Toujours vérifier le code de sortie et l'heure de `done.txt`.
3. Lire le résultat avec `grep "\[FO-CONTENT\]" fo-autotest\create.log fo-autotest\benchmark.log`. On
   attend `BILAN : 212 OK, 0 ECHEC(S)` (lot V2c, observé en moteur réel le 22/10 à 2 h 43 : 210
   contrôles, dont 63 de niveaux, + 2 de l'exemple greffé `checks/exemple.lua` ; 209 avant V2c).
4. Archiver les journaux qui servent de preuve dans `<racine>\fo-logs\<date>_<lot>_<scénario>\` (hors du
   dépôt), car le banc suivant efface `fo-autotest\`.

Scénarios :
- `default` : guerre à économie réelle et compagnons ;
- `content` : banc de contenu, 212 contrôles ;
- scénarios greffés du lot IA0 (PvP) : `ia0-normal` et `ia0-paisible` (216 000 ticks), `ia0-difficile`
  (144 000), `ia0-big` et `ia0-perf` (performance, banc épinglé). Les scénarios de guerre intégrés
  tournent en difficulté « Paisible », pour rester comparables aux mesures E17 à E22 ;
- `waves` : défense de tours et guerre ;
- `pteam` : équipe du joueur ;
- `stress` : 402 agents ;
- `baseline`, `noexp`, `peace`, `parked`, `worker`.

Performance :
- La commande est `python tools/autotest/analyze.py "<racine>\fo-autotest" --spikes`.
- Surveiller l'étalon `[FO-CALIB]`. Le processeur est hybride (F30) : le banc est épinglé sur les
  cœurs P. Une mesure prise en arrière-plan sans épinglage est fausse.

**Captures en une commande, sans intervention** (lot P1, H-T1 validée) :
- Commande : `fo-captures.bat [scenario] [source] [fenetre]` ; depuis Git Bash, SANS argument entre
  guillemets : `cd "<racine>" && ./fo-captures.bat content`. **Avec une source, lancer depuis PowerShell**
  (`& "<racine>\fo-captures.bat" vitrine "<source>"`) : Git Bash coupe le chemin à l'espace (F69).
- Le jeu est lancé en `--benchmark-graphics` et s'arrête seul. La fenêtre reste réduite et ne prend
  jamais le focus. Le cache d'atlas charge les sprites en 5 s environ.
- Codes de sortie :
  - 0 : succès ;
  - 2 : verrou pris ;
  - 3 : délai dépassé ;
  - 4 : captures manquantes ;
  - 5 : un processus de test reste ouvert ;
  - 6 : vitrine refusée ;
  - 7 : erreur du jeu ;
  - 8 : banc en échec.
- Durées : `content` de 80 à 120 s ; vitrine V0 : 96 s.
- **Vitrine** : déposer `<racine>\fo-vitrine.lua` (format au §3 de `tools/autotest/README.md`), puis
  `fo-captures.bat vitrine [source]`.
- **Bancs d'un autre lot**, sans toucher aux fichiers de P1 : `scenarios/<nom>.lua`, `checks/<nom>.lua`
  et `checks/index.lua` dans `tools/autotest/fo-autotest/` (§4 du README).
- Il faut Python et Pillow, tous deux installés.
- **Toujours regarder les images** : un code 0 prouve que les fichiers existent, pas qu'ils sont justes.

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
- **F44** : ni le centre (`container`) ni le mur ne sont animables par prototype. Il faut une entité
  compagnon ou `rendering.draw_animation`.
- **F47** : les ombres vanilla partent PLEIN EST (la lumière vient de l'ouest) et mesurent environ 1,1 ×
  la hauteur à l'écran.
- **F49 à F57** (lot P1, captures en moteur) :
  - `--benchmark-graphics` donne une session avec rendu qui s'arrête seule ;
  - `take_screenshot` rend hors écran ;
  - les faisceaux et les jets ne sont pas déterministes au pixel ;
  - en fenêtre réduite, Windows place le jeu sur les cœurs E, et le cache d'atlas compense.

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
- Dépôt git (créé au lot P0, 21/10) : branche `main` dans ce dossier. `.gitattributes` (`* -text`)
  conserve les octets tels quels, car `core.autocrlf=true` sur ce PC. Les worktrees des agents vivent
  dans `.claude/worktrees/` (ignoré par git et exclu de la copie du banc).
- Fichiers orphelins `script/faction/engineer.lua` et `tools/sim_war.lua` : supprimés au lot P0 après
  vérification par `grep` (aucun `require`).
