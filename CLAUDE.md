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
4. `RD_LOG.md` : faits F1 à F118 (F102 lu dans le binaire, pas en moteur réel ; F103 à F110 : lot V3-T3, intégré ;
   F111 à F118 : lot V3-T4, livré NON intégré), expériences E1 à E64 (E3 jamais attribué ; E56 à E59 : V3-T3 ; E60 à
   E62 : V3-T4 ; E63 et E64 : V3-E, passes 3 et 4, jugées « pas prêt »), hypothèses ouvertes (H-V2, H-X1, H-L1 (mesurée en partie au lot V3-T2), H-B1, H-E1, H-T4-1 ; H-T1 et
   H-V1 validées ; H-T3 : (1) prouvée en moteur réel, (2) prémisse réfutée par F77, filet prouvé seulement en
   expérience de contrôle). Prochains identifiants : **F119, E65**.

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
lua5.2 tests/migration_test.lua  -> 82 OK
lua5.2 tests/levels_test.lua     -> 1642 OK   (+ 11 « écarts connus » au contrat, comptés à part ; rejoue aussi le harness, environ 5 s ; --tables : BALANCE_SHEET §12 ; --calibrate : courbe recalculée sur le calendrier X0 depuis un état de référence fixe ; FO_VERBOSE_CLEAR=1 : détail des cas de « libérer la place »)
lua5.2 tests/pvp_test.lua        -> 596 OK   (de 3 à 5 min : 195 s le 22/10 entre 22 h 50 et 22 h 55, 194 s à 20 h 11, 180 s à 19 h 05, 301 s plus tôt le même jour ; "pure" en argument : 502 OK, partie pure seule)
lua5.2 tests/epochs_test.lua     -> 16665 OK (graphe de fabrication du lot X0)
lua5.2 tests/org_test.lua        -> 362 OK   (modèle des rôles des équipes de PNJ, lot IA1)
lua5.2 tests/datastage/harness.lua "<racine>/data" .   -> 0 nouvelle erreur, Règles moteur : 0 violation(s) (les cas faux de l'auto-contrôle y sont comptés), 0 clé manquante ; points de jeu vanilla 18 entités / 51 points, mod 61 / 182 ; auto-contrôle 11/11 ; code de sortie 0 (--dump-proto type/nom, --dump-final type/nom, --verbose)
python tools/api_lint.py "<racine>/doc-html" "<chemin absolu du mod>"   -> 609 usages, 0 erreur (mod de test compris ; chaînes et commentaires ignorés depuis le 21/10)
python -B tools/autotest/tests/run_d4m.py --logs "<racine>/fo-logs"   -> 5/5 étapes (banc D4m hors jeu ; unitaires de vram.py 99 OK ; 13 journaux archivés : atlas attendus selon les réglages déclarés par chaque journal ; À LANCER DEPUIS GIT BASH : sous PowerShell, lua5.2 n'est pas dans le PATH et le banc donne 2/5)
python -B tools/autotest/tests/mut_atlas.py --logs "<racine>/fo-logs" --out <dossier jetable, ni fo-logs ni une archive>   -> 40 OK (7 témoins acceptés, 21 mutants refusés, 11 cas du garde-fou, 1 contrôle final)
python -B tools/autotest/tests/mut_vram.py [--work <dossier jetable>]   -> témoin nul survivant ; 18/18 mutants détectés (18 par un contrôle, 0 par un plantage), code 0 (règle de l'atlas virtuel de vram.py, hors jeu, environ 10 s, 7 s sur main le 22/10 ; lot R1, RD_LOG E55 ; lua5.2 du PATH par défaut : depuis Git Bash, ou --lua <chemin complet de lua5.2.exe> sous PowerShell)
python -B tools/autotest/tests/test_ht3_journal.py   -> 15 OK (contrôle du journal des bancs de migration, --tag et messages aux joueurs compris, hors jeu)
python -B tools/autotest/tests/bat_double_source/run.py   -> 4 OK (fo-autotest.bat en double source, faux factorio.exe et robocopy.exe ; gcc de C:\mingw64 requis)
```
`levels_test` et `migration_test` acceptent `FO_DATA_DIR=<racine>/data` pour une copie du mod hors de
l'arborescence du jeu.
Chiffres mesurés sur `main` le 22/10 de 22 h 50 environ à 22 h 55 (fin de la sortie : 22:55:17), après l'intégration du lot V3-T3 (fusion `8a28804`, version
0.4.4 ; pvp en 195 s). Avant V3-T3 (lot R1, 22/10, 20 h 11) : migration 81, levels 1577, api_lint 535 ; le correcteur
de V3-T3 annonçait 615 usages dans son worktree, `main` en compte 609 (écart non expliqué, noté tel quel). Avant R1 :
migration 79, levels 1575, api_lint 519, unitaires de vram.py 57. La branche du lot V3-T4 (NON intégrée) donne
d'autres chiffres (levels 1 615 + 23 écarts connus, api_lint 558) : ce ne sont pas ceux de `main`.

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
   attend `BILAN : 317 OK, 0 ECHEC(S)` (lot V3-T2, observé en moteur réel sur `main` le 22/10, `done.txt` à
   19:05:39,98 ; rejoué après le lot R1, 20:11:14,81, et après le lot V3-T3, 22:50:45,71) : 210 contrôles du banc, dont 63 de niveaux, + 2 de l'exemple greffé `checks/exemple.lua` + 26 du
   greffon `checks/levels_taille.lua` + 54 de `checks/levels_machines.lua` + 25 de `checks/levels_points.lua` ; la
   ligne « greffons » du journal dit « exemple 2 OK 0 ECHEC, levels_taille 26 OK 0 ECHEC, levels_machines 54 OK
   0 ECHEC, levels_points 25 OK 0 ECHEC » (63 OK dans `create.log`, 254 dans `benchmark.log`). 238 avant V3-T2,
   212 avant V3-T, 209 avant V2c.
4. Archiver les journaux qui servent de preuve dans `<racine>\fo-logs\<date>_<lot>_<scénario>\` (hors du
   dépôt), car le banc suivant efface `fo-autotest\`.

**Double source : migration d'une vraie sauvegarde** (suite H-T3, RD_LOG E46 ; `tools/autotest/README.md` §1.1).
La variable d'environnement `FO_CREATE_SRC` donne une autre source de factorio-overhaul pour la seule création de
la carte ; le benchmark rejoue la même carte avec la source habituelle. Sous PowerShell :
```
$env:FO_CREATE_SRC = 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3T-suites\ht3\src-0.4.1'
& 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 700 ht3-migration 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'
$env:FO_CREATE_SRC = $null
python -B tools/autotest/ht3_journal.py 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest'
```
- `src-0.4.1` est identique à `git archive 91097e6` (version 0.4.1) ; `fo-autotest\create-source.txt` dit quelle
  source a créé la carte.
- Attendu : « [FO-HT3-MIGRATION] BILAN : 30 OK, 0 ECHEC(S) » dans `benchmark.log` (29 avant le lot V3-T2 : le
  centre 15 grandit désormais lui aussi), ET « JOURNAL H-T3 : 7 OK, 0 ECHEC(S) », code 0. Observé sur `main` le
  22/10 (`done.txt` 19:05:52,39 ; après le lot R1, 20:11:32,11 ; après le lot V3-T3, 22:51:10,76).

Migration 0.4.2 → 0.4.3 quand toutes les familles grandissent (lot V3-T2, RD_LOG E50 ; usine dense de 24 machines) :
```
$env:FO_CREATE_SRC = 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3T2\src-0.4.2'
& 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 700 t2-migration 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'
$env:FO_CREATE_SRC = $null
python -B tools/autotest/ht3_journal.py --tag FO-T2-MIGRATION 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest'
```
- `src-0.4.2` est identique à `git archive c4d37e5` (version 0.4.2) : à GARDER, c'est la source de création de ce
  banc.
- Attendu : « [FO-T2-MIGRATION] BILAN : 64 OK, 0 ECHEC(S) » dans `benchmark.log`, ET « JOURNAL FO-T2-MIGRATION :
  26 OK, 0 ECHEC(S) », code 0 ; journal du mod : « mise à jour des emprises : 21 bâtiment(s) reposé(s), 3 déjà en
  place, 19 laissé(s) ». Observé sur `main` le 22/10 (`done.txt` 19:05:48,49 ; après le lot R1, 20:11:28,04 ; après le
  lot V3-T3, 22:51:06,58). Depuis V3-T3, le journal du banc dit aussi « LIBERER LA PLACE (plan seul, hors bilan) :
  5 liberable(s) sur 19 laisse(s) » : ligne HORS bilan, qui ne change ni le BILAN ni le contrôle du journal.

Migration d'une DÉFENSE DENSE (lot R1, RD_LOG E54 ; 21 tourelles derrière un mur continu, bras électriques, convoyeur
de munitions, poteaux), création 0.4.1 :
```
$env:FO_CREATE_SRC = 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3T-suites\ht3\src-0.4.1'
& 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 1200 t2-defense 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'
$env:FO_CREATE_SRC = $null
python -B tools/autotest/ht3_journal.py --tag FO-T2-DEFENSE 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest'
```
- Attendu depuis 0.4.1 : « [FO-T2-DEFENSE] BILAN : 36 OK, 0 ECHEC(S) » dans `benchmark.log`, ET « JOURNAL
  FO-T2-DEFENSE : 19 OK, 0 ECHEC(S) », code 0 ; journal du mod : « 8 bâtiment(s) reposé(s), 0 déjà en place,
  13 laissé(s) ». Observé sur `main` le 22/10 (`done.txt` 20:11:36,19 ; après le lot V3-T3, 22:51:15,21 ; ligne hors
  bilan « LIBERER LA PLACE (plan seul, hors bilan) : 2 liberable(s) sur 13 »).
- Création 0.4.2 : même commande avec `$env:FO_CREATE_SRC = 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3T2\src-0.4.2'`.
  Attendu : 36 OK, ET « JOURNAL FO-T2-DEFENSE : 11 OK, 0 ECHEC(S) », code 0 ; journal du mod « 5, 0, 5 ». Observé sur
  `main` le 22/10 (`done.txt` 20:11:40,52 ; après le lot V3-T3, 22:51:19,45 ; hors bilan : 0 libérable sur 5).
- Le scénario n'existe qu'en double source : `src-0.4.1` (= `git archive 91097e6`) et `src-0.4.2` (= `git archive
  c4d37e5`) sont à GARDER.

« Libérer la place » pour un bâtiment laissé HORS GRILLE par une vraie migration (lot V3-T3, RD_LOG E59 ; un script
ne sait pas fabriquer un bâtiment hors grille, F104) :
```
$env:FO_CREATE_SRC = 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3T2\src-0.4.2'
& 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 1000 t3-migration 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'
$env:FO_CREATE_SRC = $null
```
- Attendu : « [FO-T3-MIGRATION] BILAN : 7 OK, 0 ECHEC(S) » dans `benchmark.log`, code 0. Observé sur `main` le 22/10
  (`done.txt` 22:51:53,59). **Il faut 1 000 ticks** : un passage à 700 ticks (22:51:02,43) s'arrête avant le
  contrôle, sans BILAN (`fo-logs\2026-10-22_V3T3-integration\t3-migration\NOTE.txt`).

Pour les quatre bancs en double source :
- Le banc s'arrête avec le code 1, sans `done.txt`, si la copie de création n'est pas remplacée en entier.
- Toujours vider la variable après usage : elle reste définie pour les bancs suivants de la même session
  PowerShell, `fo-captures.bat` compris. Avec `fo-captures.bat`, elle a été essayée deux fois (lot V3-T2,
  `fo-captures.bat t2-migration`, code 0) : la carte du banc est créée par la source de création et la session
  avec images rejoue la migration.
- Préférer `$env:FO_CREATE_SRC = $null` : sous Claude Code, `Remove-Item Env:FO_CREATE_SRC` peut être refusé
  par la protection de chemin de l'outil (REPRISE.md §6).

**Contact bord à bord des recherches par zone** (lot R1, RD_LOG E53, F96 ; sans double source) :
`& 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 60 bord-a-bord 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'`
→ « [FO-BORD-A-BORD] BILAN : 12 OK, 0 ECHEC(S) » (45 cas comparés à la règle du moteur simulé ; observé sur `main`
le 22/10, `done.txt` 20:11:23,82 ; après le lot V3-T3, 22:50:54,07). Un ECHEC veut dire que le moteur simulé (`tests/mock_engine.lua`) ne suit plus le
moteur réel : l'aligner, puis rejouer tous les bancs hors jeu.

**Machines agrandies, pour les captures** (lot V3-T2, sans double source) :
`& 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 1500 t2-machines 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'`
→ « [FO-T2-MACHINES] BILAN : 80 OK, 0 ECHEC(S) » (observé sur `main` le 22/10, `done.txt` 19:05:44,44 ; après le lot
R1, 20:11:19,61 ; après le lot V3-T3, 22:50:50,22). Pour les
images : `& "<racine>\fo-captures.bat" t2-machines "<source>"` depuis PowerShell.

**« Libérer la place »** (lot V3-T3, RD_LOG E59 ; sans double source ; zones A à V et L, vrais robots en zone R) :
`& 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 1900 t3-libere 'H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'`
→ « [FO-T3-LIBERE] BILAN : 41 OK, 0 ECHEC(S) » (observé sur `main` le 22/10, `done.txt` 22:50:58,19). Le scénario
contrôle au tick 1 800 (`check_tick`, à cause des vrais robots) : il faut au moins 1 900 ticks. Images :
`& "<racine>\fo-captures.bat" t3-libere "<source>"` depuis PowerShell, 4 captures prises après le bilan
(`shots_delay` = 1 840).

Scénarios :
- `default` : guerre à économie réelle et compagnons ;
- `content` : banc de contenu, 317 contrôles avec les greffons (les contrôles greffés ne se chargent que pour
  `content` et les scénarios greffés de base `content`) ;
- `ht3-migration` (scénario greffé) : migration d'une sauvegarde 0.4.1, en double source seulement (ci-dessus) ;
- `t2-migration` (scénario greffé, lot V3-T2) : migration d'une sauvegarde 0.4.2, en double source seulement
  (ci-dessus) ; `t2-machines` (scénario greffé, lot V3-T2) : greffons `levels_machines` et `levels_points` joués
  au tick 60, pour les captures ;
- `t2-defense` (scénario greffé, lot R1) : migration d'une défense dense, en double source seulement (ci-dessus) ;
  `bord-a-bord` (scénario greffé, lot R1) : contact exact zone/boîte en moteur réel (ci-dessus) ;
- `t3-libere` (scénario greffé, lot V3-T3) : bouton « Libérer la place » en moteur réel, 1 900 ticks (ci-dessus) ;
  `t3-migration` (scénario greffé, lot V3-T3) : le même bouton pour un bâtiment laissé hors grille, en double source
  `src-0.4.2` seulement, 1 000 ticks (ci-dessus) ;
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
- **F70 et F74** (lot V3-T) : `create_entity` SANS `fast_replace` pose le nouveau bâtiment par-dessus l'ancien
  encore présent, sans vérifier la place (le script doit la vérifier avant) ; en revanche, il a retiré
  lui-même le fantôme de mur recouvert (un seul cas observé).
- **F76, F77 et F79** (suite H-T3) : au chargement, une entité dont le prototype a changé de taille garde sa
  position et prend la nouvelle boîte ; `on_configuration_changed` est aussi appelé, avec `mod_changes` VIDE,
  quand les données de prototypes existants changent sans montée de version (attribution aux données :
  déduite, non prouvée) ; un bras a retrouvé seul une cible remplacée par script (un seul cas joué : bras à
  combustible).
- **F83 à F95** (lot V3-T2, remplacement par script d'une machine) :
  - un four neuf ignore l'écriture de `crafting_progress` (F83) ; l'écrire sur un assembleur À L'ARRÊT (seul cas
    joué) rend `is_crafting()` vrai et donne une fabrication gratuite (F84) ;
  - `create_entity{fast_replace = true}` à une position hors grille ne remplace rien et pose le nouveau bâtiment
    PAR-DESSUS l'ancien, en rendant une entité valide (F86) ;
  - le bâtiment créé pendant que l'ancien existe n'est pas raccordé aux tuyaux de l'ancien : un téléport sur place
    les refait, `update_connections()` non (F90) ; un assembleur créé sans recette ignore `direction` (F91) ;
  - les positions du moteur sont en virgule fixe (1/256) : jamais d'égalité exacte (F92) ;
  - la barre rouge d'un coffre limite aussi `insert` par script, et un coffre sans barre rend `get_bar()` = cases
    + 1 (F95).
- **F96** (lot R1) : `find_entities_filtered{area}` et `count_entities_filtered{area}` rendent aussi une entité qui
  TOUCHE seulement la zone, par un bord ou un coin (intervalles fermés) : refiltrer par chevauchement strict
  (`Foot.overlap`) quand le contact ne compte pas. Les boîtes rendues sont en virgule fixe 1/256 (F98).
- **F103 à F109** (lot V3-T3, marques et fantômes par script) : annuler la marque de démontage d'une entité RETIRE le
  fantôme posé dessus (retirer les fantômes d'abord, F103) ; un script ne fabrique pas un bâtiment hors grille,
  `create_entity` et `teleport` recalent (F104) ; `can_place_entity` d'un `entity-ghost` est inutilisable et
  `create_entity` d'un fantôme ne contrôle pas la place (F105, F108) ; `copy_settings` sur un fantôme recopie filtres,
  conditions, demandes et barre, mais pas la taille de pile imposée (F107) ; `revive` rend un NOUVEAU numéro d'unité
  (F109).

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
