# Bancs en moteur réel : `tools/autotest/`

Outillage du lot P1 (« Captures entièrement automatiques », hypothèse H-T1). Tout tourne dans des dossiers
**séparés** (`<racine>\fo-autotest\`, `<racine>\fo-visual\`) : jamais dans `saves\`, `config\` ni `mods\` du
Directeur Créatif. `<racine>` = `H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\`.

| Fichier | Rôle |
|---|---|
| `fo-autotest.bat` | Banc sans affichage : copie du mod, création de la carte, benchmark de N ticks |
| `fo-visual.bat` | Session AVEC images, entièrement automatique : captures, fermeture, index, planche |
| `fo-captures.bat` | **Une seule commande** : `fo-autotest.bat` puis `fo-visual.bat`, verrou tenu tout du long |
| `visual_session.py` | Pilote de la session graphique (appelé par `fo-visual.bat`) |
| `gallery.py` | Index et planche-contact d'un dossier de captures (utilisable seul) |
| `compare_shots.py` | Comparaison pixel à pixel de deux séries de captures |
| `analyze.py` | Analyse des performances d'un banc (`--spikes`) |
| `vram.py` | (lot D4m) Mémoire vidéo d'une session avec images : atlas estimés, mesure directe, chargement, champ réel, images/s (§5) |
| `ht3_journal.py` | (suite H-T3) Contrôle du journal d'un passage du banc de migration `ht3-migration` (§1.1) ; (lot V3-T2) option `--tag FO-T2-MIGRATION` pour le banc `t2-migration`, et contrôle des messages de migration aux joueurs ; (lot R1) `--tag FO-T2-DEFENSE` pour le banc `t2-defense` |
| `tests/` | (lot D4m) Bancs HORS JEU de `vram.py`, du pilote et du greffon `d4-geant` : `run_d4m.py` (§5.1) ; (suite H-T3) `test_ht3_journal.py` et `bat_double_source/run.py` (§1.1 ; graine `FO_MAP_SEED` : §1.2) ; (lot R1) `mut_vram.py`, banc de mutations de la règle de l'atlas virtuel de `vram.py` (§5.1) |
| `gun_rose_images.py` | (lot A3-jeu) Image de tête MONTRÉE par le moteur contre l'image attendue, sur les captures `rose64-ageNN-z2-jour` de `fo-captures.bat gun-rose` : `py -3.9 tools/autotest/gun_rose_images.py "<fo-shots>" --feuilles "<source>/graphics/levels/gun"` (BILAN « N OK, 0 FAUX », code 0) |
| `fo-autotest-watch.bat` | Ancienne surveillance pour les sessions cloud (inutile dans Claude Code) |
| `fo-autotest/` | Mod de test : `control.lua`, `content_test.lua`, `shots.lua`, `vitrine.lua`, `greffons.lua`, `terrain.lua`, `data.lua`, `scenarios/`, `checks/` |

**Installation.** Les trois `.bat` se recopient à la racine du jeu (`<racine>\fo-*.bat`) après chaque
modification ; les scripts Python ne se recopient pas : `fo-visual.bat` prend `visual_session.py` et
`gallery.py` dans la copie du mod faite par le dernier banc (`fo-autotest\mods\factorio-overhaul\tools\autotest\`),
donc toujours dans la même version que le mod de test. Dépendances : Python 3 et Pillow
(`python -m pip install --user pillow`).

## 1. Commandes

Depuis Git Bash : `cd "<racine>" && ./fo-captures.bat content`. Depuis PowerShell :
`& "<racine>\fo-captures.bat" content`. Toutes les commandes sont bloquantes et rendent un code de sortie fiable.

```
fo-captures.bat [scenario] [source du mod] [fenetre]
    scenario : content (défaut, 4 000 ticks : contrôles + galerie) | vitrine | <scénario greffé> |
               default, waves, pteam... (600 ticks de banc, puis la mise en route de la session visuelle)
    source   : chemin absolu du mod à tester ; absent ou "" : 3e champ de fo-autotest-params.txt,
               sinon <racine>\mods\factorio-overhaul
    fenetre  : min (défaut) | small | normal
fo-autotest.bat [nopause] [ticks] [scenario] [source]      (défaut : fo-autotest-params.txt)
    variables facultatives : FO_CREATE_SRC (source de création, §1.1), FO_MAP_SEED (graine, défaut 20261020, §1.2),
                             FO_AUDIO (1 : son actif sans sortie audio, pilote SDL disk et garde de crête, §1.3)
fo-visual.bat   [nopause] [fenetre] [delai_s]              (défaut : min, 900 s)
```

Codes de sortie :

| Code | Sens |
|---|---|
| 0 | Succès : toutes les captures prévues sont sur disque et lisibles, session fermée, aucun processus de test restant |
| 1 | Préparation impossible (pas de carte, pas de pilote, session de test déjà ouverte...) |
| 2 | **Verrou pris : rien n'a tourné** (`fo-autotest\` contient les résultats du banc PRÉCÉDENT) |
| 3 | Délai dépassé : la session a été fermée par le pilote |
| 4 | Captures manquantes ou illisibles |
| 5 | Un `factorio.exe` de test est encore présent après fermeture |
| 6 | Vitrine : au moins une entité refusée (prototype inconnu, `create_entity` refusé...) |
| 7 | Erreur du jeu (journal), ou session terminée sans marqueur de fin (budget de ticks trop court) |
| 8 | (`fo-captures.bat`) le banc `fo-autotest` a échoué : pas de carte |
| 9 | (lot D4m) qualité des sprites, usage de la mémoire vidéo ou compression des textures demandés NON appliqués (ligne « Graphics options » du journal) : mesure non valable |

`fo-autotest.bat` rend 0 dès que le banc a tourné : lire ensuite le BILAN
(`grep "\[FO-CONTENT\] BILAN" fo-autotest\benchmark.log`).

**Verrou.** `<racine>\fo-autotest.lock` (un dossier) : les trois commandes le prennent, une seule session
moteur à la fois. `fo-captures.bat` le tient pour toute la chaîne (variable `FO_LOCK_HELD` transmise aux deux
autres). Verrou orphelin (aucun `factorio.exe` dont la ligne de commande contient `fo-autotest` ou `fo-visual`) :
`rmdir "<racine>\fo-autotest.lock"`.

### 1.1 Double source : une carte créée par une version, rejouée par une autre (suite H-T3)

Pour prouver la migration d'une VRAIE sauvegarde (créée par une version publiée du mod, rechargée par la
suivante), `fo-autotest.bat` accepte une variable d'environnement facultative, **`FO_CREATE_SRC`** : le chemin
absolu d'une autre source de `factorio-overhaul`, utilisée pour la seule étape `--create`. Déroulé :

1. `[1/4]` copie de `FO_CREATE_SRC` comme `factorio-overhaul` ; le mod de test (`fo-autotest`) vient, lui,
   TOUJOURS de la source habituelle (argument 4, sinon `fo-autotest-params.txt`) ;
2. `[2/4]` création de la carte avec cette copie (`create.log`) ;
3. `[2b/4]` la copie de `factorio-overhaul` est REMPLACÉE par la source habituelle ;
4. `[3/4]` benchmark sur la même carte (`benchmark.log`) : le moteur recharge la sauvegarde avec l'autre
   version (montée de version : `on_configuration_changed` ; version inchangée : seuls les filets du mod).

Traces : `fo-autotest\source.txt` = source du benchmark (inchangé), `fo-autotest\create-source.txt` = source de
création (écrit seulement en double source). À l'étape `[2b/4]`, si la copie de création n'a pas pu être
effacée en entier (fichier tenu ouvert...) ou si `robocopy` de la source du benchmark rend 8 ou plus, le banc
s'ARRÊTE avec le code 1, sans `done.txt` ni benchmark : sinon des fichiers de l'ancienne source resteraient
mêlés à la nouvelle sans que rien ne le signale (défaut relevé par le correcteur de la suite H-T3). Banc hors jeu
de ces cas (faux `factorio.exe` et faux `robocopy.exe` compilés par le gcc de `C:\mingw64`, racines jetables dans
le dossier temporaire, aucun accès à la racine du jeu) :
`python -B tools/autotest/tests/bat_double_source/run.py` → « BILAN : 4 OK, 0 ECHEC(S) » (sur le `.bat` d'avant
la correction, `--bat <fichier>` : 2 OK, 2 ECHEC). Sans la variable, le comportement est **identique à l'ancien**
(même copie, mêmes fichiers). Mêmes protections : dossiers d'écriture et de mods séparés, verrou, aucun accès à
`saves\`. La variable reste définie pour les bancs suivants de la même session PowerShell : la vider après usage.
Elle passe aussi par `fo-captures.bat`, qui appelle `fo-autotest.bat` : essayé deux fois par le lot V3-T2 (22/10,
17 h 53 et 18 h 53, `fo-captures.bat t2-migration <source>` avec `FO_CREATE_SRC` = `src-0.4.2`, code 0). La carte
du banc est créée par la source de création (`banc-create-source.txt` dans l'archive du premier essai ; pour le second, seul `factorio.log` le montre :
`mod_changes { factorio-overhaul 0.4.2 -> 0.4.3 }`) et la session
avec images, qui reprend la carte et les mods du dernier banc, rejoue la migration (`factorio.log`).

Comme le mod de test vient de la source récente alors que `factorio-overhaul` est ancien pendant la création,
`greffons.lua` ne charge les contrôles greffés (`checks/`) que pour le banc `content` (ou un scénario greffé de
base `content`) : un contrôle récent qui requiert un fichier absent de l'ancienne version ne bloque plus le
chargement des autres scénarios.

Exemple (PowerShell ; Git Bash coupe les chemins à l'espace, F69) : scénario greffé `ht3-migration`, carte
créée par 0.4.1 (`git archive 91097e6`), rejouée par le worktree 0.4.2 :

```
$env:FO_CREATE_SRC = "<dossier jetable>\src-0.4.1"
& "<racine>\fo-autotest.bat" nopause 700 ht3-migration "<worktree 0.4.2>"
$env:FO_CREATE_SRC = $null
```
(Sous Claude Code, `Remove-Item Env:...` peut être refusé par la protection de chemin de l'outil : préférer
`$env:X = $null`.)

Résultat : `grep "\[FO-HT3-MIGRATION\]\|\[FO-LEVELS\]" fo-autotest\create.log fo-autotest\benchmark.log`. Le
scénario (`scenarios/ht3-migration.lua`) refuse une carte créée par une source qui connaît déjà les emprises
(contrôle ECHEC dès la création). Pour la voie sans montée de version, rejouer avec une copie de la source
récente dont `info.json` garde la version de création (le moteur appelle quand même `on_configuration_changed`,
`mod_changes` vide : c'est `Levels.repair` qui migre ; le filet `on_nth_tick(30)` ne s'exerce que si la migration
au chargement est neutralisée dans une copie jetable).

Second exemple (lot V3-T2) : scénario greffé `t2-migration`, carte créée par 0.4.2
(`<racine>\fo-logs\2026-10-22_V3T2\src-0.4.2` = `git archive c4d37e5`, à garder), rejouée par 0.4.3 : toutes les
familles grandissent ; force sans énergie avec un niveau 7, un niveau élevé et une paire collée de chaque famille ;
centres 15, 10 et 6 ; usine dense de 24 machines de niveau 8 (RD_LOG E50) :

```
$env:FO_CREATE_SRC = "<racine>\fo-logs\2026-10-22_V3T2\src-0.4.2"
& "<racine>\fo-autotest.bat" nopause 700 t2-migration "<source 0.4.3>"
$env:FO_CREATE_SRC = $null
python -B tools/autotest/ht3_journal.py --tag FO-T2-MIGRATION "<racine>\fo-autotest"
```

Attendu sur `main` (22/10, 19:05:48,49) : « [FO-T2-MIGRATION] BILAN : 64 OK, 0 ECHEC(S) » et « JOURNAL
FO-T2-MIGRATION : 26 OK, 0 ECHEC(S) », code 0 ; ligne du mod « mise à jour des emprises : 21 bâtiment(s)
reposé(s), 3 déjà en place, 19 laissé(s) faute de place ». `ht3-migration` donne 30 OK depuis 0.4.3 (le centre 15
grandit lui aussi, compté « déjà en place ») et journal 7 OK. Rejoués sur `main` après le lot R1 (22/10, 20:11:28,04
et 20:11:32,11) : mêmes chiffres.

Troisième exemple (lot R1, RD_LOG E54) : scénario greffé `t2-defense`, migration d'une DÉFENSE DENSE. Une ligne de
21 tourelles (11 mitrailleuses, 10 lasers) en trois tronçons (A compact, C haut niveau compact, B aéré) derrière un
mur continu de niveau 7, un bras électrique par mitrailleuse sur un convoyeur de munitions par tronçon (tête regarnie
par script pendant le benchmark), 24 poteaux moyens sur une interface électrique vanilla ; mitrailleuses vides à la
création. Classement au tick 90, munitions au tick 170, trois vagues de 21 biters moyens (ticks 200, 380, 560),
contrôles au tick 1 100. Double source SEULEMENT, création 0.4.1 ou 0.4.2 :

```
$env:FO_CREATE_SRC = "<racine>\fo-logs\2026-10-22_V3T-suites\ht3\src-0.4.1"   # ou "<racine>\fo-logs\2026-10-22_V3T2\src-0.4.2"
& "<racine>\fo-autotest.bat" nopause 1200 t2-defense "<source 0.4.3>"
$env:FO_CREATE_SRC = $null
python -B tools/autotest/ht3_journal.py --tag FO-T2-DEFENSE "<racine>\fo-autotest"
```

Attendu sur `main` (22/10) :
- création 0.4.1 (20:11:36,19) : « [FO-T2-DEFENSE] BILAN : 36 OK, 0 ECHEC(S) » et « JOURNAL FO-T2-DEFENSE : 19 OK,
  0 ECHEC(S) », code 0 ; ligne du mod « 8 bâtiment(s) reposé(s), 0 déjà en place, 13 laissé(s) » ;
- création 0.4.2 (20:11:40,52) : 36 OK et journal 11 OK, code 0 ; ligne du mod « 5, 0, 5 ».
Images (création 0.4.1) : `fo-captures.bat t2-defense "<source>"` depuis PowerShell, avec la même variable ; 2 captures
(`001-defense-ouest.png` : tronçons A et C ; `002-defense-est.png` : tronçon B). Exemple archivé :
`<racine>\fo-logs\2026-10-22_R1\defense\captures-t2-defense-0.4.1\`.

**Critère d'un passage : le BILAN du scénario sans échec ET le contrôle du journal à 0.** Le mod de test ne lit
pas le journal du moteur ; le scénario y écrit ce qu'il DOIT contenir (lignes « JOURNAL ATTENDU ») et
`tools/autotest/ht3_journal.py` le compare aux lignes `[FO-LEVELS]` : une ligne « laissé en place » par
bâtiment laissé et aucune autre, une seule ligne de bilan des emprises, de la voie attendue (« mise à jour
des emprises » = `Levels.repair` ; « emprises (filet, … » = filet) et avec les mêmes nombres ; depuis le lot V3-T2,
si le scénario a écrit des lignes « JOURNAL ATTENDU : message <force> <laissés> <doublons> », chaque message de
migration aux joueurs (« [FO-LEVELS] message de migration à la force … ») est journalisé exactement une fois avec
ces nombres, et aucun autre. L'option `--tag <BALISE>` (balise sans crochets, `FO-HT3-MIGRATION` par défaut) lit
les lignes d'un autre scénario au même format :

```
python -B tools/autotest/ht3_journal.py "<racine>\fo-autotest"        -> JOURNAL H-T3 : n OK, 0 ECHEC(S), code 0
python -B tools/autotest/ht3_journal.py --tag FO-T2-MIGRATION "<racine>\fo-autotest"   -> JOURNAL FO-T2-MIGRATION : n OK, 0 ECHEC(S), code 0
python -B tools/autotest/tests/test_ht3_journal.py                     -> BILAN : 15 OK, 0 ECHEC(S) (hors jeu)
```

### 1.2 Graine de la carte : `FO_MAP_SEED` (lot INT-GRAINE)

`fo-autotest.bat` crée la carte avec `--map-gen-seed 20261020` par défaut. La variable d'environnement facultative
**`FO_MAP_SEED`** donne une autre graine, sans autre changement (même copie, mêmes fichiers, même benchmark) :

```
$env:FO_MAP_SEED = '987654321'
& "<racine>\fo-autotest.bat" nopause 4000 content "<source>"
$env:FO_MAP_SEED = $null
Get-Content "<racine>\fo-autotest\seed.txt"        # -> 987654321
```

- **Absente ou vide** : graine 20261020, comme avant (sous PowerShell, `$env:FO_MAP_SEED = ''` retire la variable ;
  une valeur vide transmise par un autre programme est aussi ramenée au défaut).
- **Valeur acceptée** : chiffres seulement, zéros de tête retirés (`0042` → 42), de 0 à 4 294 967 295 (graine du
  moteur : entier 32 bits non signé). La graine passée au moteur est la forme sans zéros de tête.
- **Valeur refusée** (lettres, signe, espace, nombre trop grand, caractères spéciaux) : message « Graine invalide
  dans FO_MAP_SEED : [...] », **code 1 AVANT la prise du verrou** : rien n'a tourné, `fo-autotest\` contient encore
  les résultats du banc PRÉCÉDENT (comme pour le code 2). La valeur n'est lue qu'en expansion retardée : un
  guillemet, `&`, `|`, `%` ou `!` ne peut ni casser le script ni exécuter une commande (la forme simple
  `set SEED=%FO_MAP_SEED%` exécutait `1&echo PIEGE>piege2.txt` : constaté hors jeu, mutant `m1` du lot INT-GRAINE).
- **Trace** : `fo-autotest\seed.txt` contient la graine utilisée (une ligne, écrite à l'étape `[1/4]`, aussi quand la
  création échoue) ; la ligne `[2/4]` de la console dit « (graine N, defaut) » ou « (graine N, FO_MAP_SEED) ».
- `fo-captures.bat` appelle `fo-autotest.bat` : la variable s'y applique de la même façon (graine refusée : code 8,
  session visuelle non lancée). `fo-visual.bat` reprend la carte du dernier banc, donc sa graine.
- Compatible avec `FO_CREATE_SRC` (double source) : la graine s'applique à l'étape `--create`, la seule qui génère
  la carte.
- Comme `FO_CREATE_SRC`, la variable reste définie pour les bancs suivants de la même session PowerShell : la
  vider après usage (`$env:FO_MAP_SEED = $null`). **Les bancs dont les contrôles supposent la graine 20261020**
  (`m0-migration`, `m0-reprise`, et toute mesure de référence de performance) se jouent SANS la variable.

Banc hors jeu (faux `factorio.exe`, racines jetables, aucun accès à la racine du jeu) :
`python -B tools/autotest/tests/bat_double_source/run.py` → « BILAN : 25 OK, 0 ECHEC(S) » : les 4 cas de la double
source, plus défaut 20261020 (sans variable et en double source), variable vide → défaut, 6 graines acceptées (dont
4294967295, 0, zéros de tête, et en double source), 10 graines refusées (rien n'a tourné, aucune commande injectée
exécutée), et le passage par `fo-captures.bat` (graine transmise ; graine refusée → code 8). Sur le `.bat` d'avant
le lot (`--bat <fichier> --captures <fichier>`) : 4 OK, 21 ECHEC. Depuis le lot S0 : 40 OK (cas 10 à 13 du son, §1.3).

### 1.3 Son actif SANS sortie audio : `FO_AUDIO` (lot S0, E69 ; corrigé après la vérification)
Par défaut, tous les bancs passent `--disable-audio` : aucun son n'est chargé, et un fichier son manquant ne se voit
pas. **`FO_AUDIO=1`** lance la session SANS `--disable-audio`, pour que le jeu CHARGE les fichiers son, mais sans
rien envoyer aux haut-parleurs du PC :
```
$env:FO_AUDIO = '1'
& "<racine>\fo-captures.bat" gun-rose "<source>"
$env:FO_AUDIO = $null
```
- **Pilote SDL `disk`** : le `factorio.exe` de test, et lui seul, reçoit `SDL_AUDIODRIVER=disk` et
  `SDL_DISKAUDIOFILE=<dossier de test>\audio-disk.raw` (`visual_session.py` : environnement du seul processus lancé ;
  `fo-autotest.bat` : variables locales au script). Ce pilote (« direct-to-disk audio », chaînes du binaire 1.1.91)
  n'ouvre aucun périphérique : la sortie mixée du jeu est écrite dans le fichier (16 bits, 2 voies, 44 100 Hz,
  au rythme réel), puis mesurée dans `session.txt` (« sortie du pilote disk : … crête … RMS … »). Le journal doit dire
  « [Audio] Backend:SDL(default); Driver:disk » puis « Loading sounds... » : sinon code 10. **« dummy » n'existe pas**
  dans le SDL du jeu : « Audio target 'dummy' not available », « SDL_AUDIODRIVER is set to "dummy". Resetting... »,
  puis le jeu RETOMBE sur wasapi (vraie sortie).
- **Garde de crête** (`audio_guard.py`, lecture seule) : toutes les 10 ms, les sessions audio Windows (WASAPI) de toutes
  les sorties actives ; si le processus de test y a une session (vraie sortie ouverte) ou une crête non nulle, il est
  TUÉ tout de suite (son PID seulement) et le pilote rend le **code 10**. Garde indisponible : code 1, rien n'est
  lancé. Un pilote autre que `disk` lu dans le journal tue aussi la session (code 10). Rapport du garde dans
  `session.txt` (« garde de crete : … sessions audio Windows du processus de test : 0 … crete max 0.000000 »).
- **Les volumes à 0 ne coupent PAS le son** (F152) : les 9 clés de la section `[sound]` (`master-volume`,
  `music-volume`, `game-effects-volume`, `gui-effects-volume`, `walking-sound-volume`, `environment-sounds-volume`,
  `alerts-volume`, `wind-volume`, `simulation-volume`) restent écrites à 0 dans le `config.ini` DE TEST et relues avant
  le lancement, mais avec le pilote wasapi la session a émis −34,6 dBFS de crête (vérification du lot), et la sortie
  du pilote disk avec ces 9 clés à 0 est, de 10 à 24 s, le MÊME signal qu'avec les volumes par défaut (corrélation
  1,000, écart 0,00 dB ; seules les 7 premières secondes diffèrent). Elles ne sont qu'une précaution de plus.
- **Seule la session avec images charge les sons** (E69) : en `--create` et `--benchmark` (« headless »), le journal
  est le même avec ou sans `--disable-audio`, et un son manquant passe sans erreur. En `--benchmark-graphics` avec le
  pilote disk, un son manquant donne « Error SoundLibrary.cpp:56: Missing sound when loading sound library:
  <fichier> » et `visual_session.py` s'arrête dès cette ligne (code 7). Donc : `fo-captures.bat` avec `FO_AUDIO=1`
  est LE banc des fichiers son ; `fo-autotest.bat` seul ne les charge pas.
- Valeurs : absente ou vide → son coupé, comme avant ; « 1 » → son actif ; toute autre valeur → `fo-autotest.bat`
  rend le code 1 AVANT le verrou (`fo-captures.bat` : code 8), `visual_session.py` le code 1. Lue en expansion
  retardée seulement, comme `FO_MAP_SEED` : aucune commande injectée ne s'exécute (cas 12 du banc hors jeu).
- Comme les autres variables, la vider après usage : `$env:FO_AUDIO = $null`.
- Preuve du silence (lot S0, correction, 23/10) : garde « 0 session, 0 relevé non nul » sur 2 429 tours ; relevé
  WASAPI indépendant pendant toute la session (`fo-logs\2026-10-24_S0\correction\meter-*.txt`) : aucune session du
  jeu, crête 0,000000 sur toutes les sorties.

- **Le tir JOUÉ, entendu dans la sortie disk** (lot S0-suite, 24/10) : le scénario greffé `s0-tir` (§4.1) place
  l'écouteur (le joueur connecté de la session avec images, téléporté) sur six tourelles qui tirent des cartouches
  isolées ; `py -3.9 tools/sound/tirs_joues.py <racine>\fo-visual\audio-disk.raw <fo-shots>\factorio.log` retrouve
  chaque tir dans la sortie (filtre adapté contre les 20 tirs du mod et les 4 tirs vanilla), avec son ère et son
  instant. Observé : 36 tirs sur 36 reconnus, ère juste, résidu ≤ 16,7 ms ; la clé `game-effects-volume=0` ne les
  coupe pas (F152). Sans écouteur sur le site (session `gun-rose`), aucun tir ne s'entend.

Bancs hors jeu : `bat_double_source/run.py` (cas 10 à 13 : défaut inchangé, sans variable SDL ; son actif aux deux
lancements avec `SDL_AUDIODRIVER=disk` et le fichier de sortie du dossier de test, même si l'appelant avait un autre
pilote ; valeurs refusées ; passage par `fo-captures.bat`), `python -B tools/autotest/tests/test_audio_session.py` →
« BILAN : 21 OK » (filtre, `prepare`, mutants du `config.ini`, ligne d'erreur réelle reconnue, ligne de commande,
environnement, pilote lu dans le journal, mesure de la sortie disk) et `python -B tools/autotest/tests/test_audio_guard.py`
→ « BILAN : 4 OK » (garde sur la VRAIE sortie du PC : témoin négatif silencieux, témoin positif de 30 Hz à −70 dBFS,
inaudible, vu et TUÉ en moins de 1 s).

## 2. Session visuelle automatique (`fo-visual.bat`)

1. `fo-visual\` est reconstruit à partir du dernier banc : mods, carte (`fo-visual-map.zip`), `config.ini`
   (écriture dans `fo-visual\write`, langue fr, fenêtré). Le dossier de captures est vidé.
2. Le jeu est lancé en **`--benchmark-graphics <carte> --benchmark-ticks N`** : il charge la partie avec images,
   un joueur local est connecté, et **il s'arrête seul** au bout de N ticks (« Quitting: automatic-quit »,
   code 0). Même si le pilote est tué, aucune session ne reste ouverte. N = 7 200 pour `content`, `vitrine`
   et les scénarios greffés, 40 000 pour les scénarios de guerre (mise en route de 36 000 ticks à ×8).
   Options : `--disable-audio --disable-migration-window` ; `config.ini` active le cache des atlas de sprites
   (`cache-sprite-atlas`, `compress-sprite-atlas-cache` : `fo-visual\write\atlas-cache.dat`, 391 Mo, refait
   seul quand les sprites changent).
3. Le mod de test (`shots.lua`) prend ses captures (`take_screenshot` avec `force_render = true`, une toutes les
   10 ticks), appelle `game.set_wait_for_screenshots_to_finish()`, attend 60 ticks, puis écrit `done.txt`.
4. Le pilote attend `done.txt` (délai maximal), échoue tôt si le journal contient une erreur fatale, puis
   **décode chaque PNG en entier** (jusqu'à 30 s de marge).
5. Fermeture : `TerminateProcess` sur le PID lancé, puis vérification par la liste des processus ; seul un
   `factorio.exe` dont la ligne de commande contient le dossier `fo-visual` peut être fermé. Les autres
   `factorio.exe` (partie du Directeur Créatif) ne sont jamais touchés ; leur nombre est seulement noté.
6. `gallery.py` écrit l'index et les planches ; `session.txt` résume tout (commande, durées, gêne, code).

**Gêne minimale (mesurée le 21/10, lot P1).** Fenêtre `min` par défaut : démarrée réduite sans activation
(`SW_SHOWMINNOACTIVE`), elle ne prend jamais le focus et n'apparaît que dans la barre des tâches. Les captures
sont **identiques au pixel** quelle que soit la fenêtre (réduite, 640×360) : `take_screenshot` rend hors
écran. En fenêtre réduite, Windows place le jeu sur les cœurs E (étalon `[FO-CALIB]` 7 à 13 ms au lieu de
2,3 ms) : sans cache, le chargement des sprites prenait 35 à 140 s ; **avec le cache des atlas, 5 s**, et la
partie elle-même (84 captures) environ 1 min. Le premier passage après un changement de sprites refait le
cache (environ +40 s). Options du pilote, par la variable `FO_VISUAL_ARGS` : `--no-atlas-cache`,
`--pcores` (épingle sur les cœurs P : plus rapide, mais prend ces cœurs à une partie en cours),
`--priority below` (déconseillé : chargement des sprites 160 s), `--mode load` (ancien mode `--load-game`,
fermé par le pilote seulement), `--ticks N` ; lot D4m : `--quality high|normal`, `--video-memory all|high|medium|low`,
`--texture-compression none|high-quality|low-quality`, `--measure`, `--size LxH`, et la fenêtre `hd` (§5).

**Non-déterminisme connu.** Deux sessions sur la même carte donnent des captures identiques au pixel, sauf
les faisceaux (lasers) et les jets (lance-flammes), dont l'animation ne suit pas le tick de jeu : 5 captures
sur 84 de la galerie `content` (duels 9, 12, 13, 14, 25), environ 1 % des pixels chacune.

### Sorties (`<racine>\fo-visual\write\script-output\fo-shots\`)

| Fichier | Contenu |
|---|---|
| `NNN-<scène>.png` | Captures, numérotées dans l'ordre de la liste (nommage déterministe) |
| `plan.txt` | Nombre de captures prévues |
| `index.tsv` | Une ligne par capture demandée : num, fichier, scène, x, y, zoom, daytime, tick, résolution, alt_mode, anti_alias |
| `index.txt` | Index lisible : zoom, heure du jour (jour/nuit), tick, taille, état (OK, absente, illisible) |
| `planche-NN.png` | Planche-contact, 48 vignettes légendées par planche |
| `session.txt` | Résumé de la session (commande, durées, gêne, processus, mémoire, code) |
| `vram.tsv`, `memoire.txt` | (lot D4m) Relevés de mémoire du processus de test toutes les 0,5 s ; rapport de `vram.py` (§5) |
| `factorio.log`, `stdout.txt` | (lot D4m) Journal et sortie standard du jeu, recopiés en fin de session |
| `perf-stats.csv` | (lot D4m, `--measure`) Statistiques de rendu écrites par le jeu en quittant |
| `vitrine.txt` | (vitrine) état de chaque rangée |
| `done.txt` | Marqueur de fin écrit par le mod de test |

Les captures restent hors du dépôt git. Le banc suivant les efface : archiver ce qui sert de preuve dans
`<racine>\fo-logs\<date>_<lot>_<objet>\`.

## 3. Vitrine : captures d'entités au choix, sans modifier ces fichiers

Déposer `<racine>\fo-vitrine.lua` (ou nommer un autre fichier par la variable `FO_VITRINE`), puis
`fo-captures.bat vitrine [source du mod]`. `fo-autotest.bat` recopie ce fichier dans le mod de test
(`vitrine_params.lua`) ; sans lui, l'exemple intégré `fo-autotest/vitrine_exemple.lua` (entités vanilla) sert.

```lua
return {
  sol = "concrete",            -- tuile vanilla (défaut : concrete, gris neutre ; décor retiré)
  entites = {                  -- une rangée par entrée, dans cet ordre
    "radar",                                                          -- forme courte : le nom seul
    { name = "assembling-machine-3", recette = "iron-gear-wheel" },   -- recette + ingrédients ×20
    { name = "electric-furnace", contenu = { { "iron-ore", 50 } } },  -- objets insérés
    { name = "flamethrower-turret", direction = "east" },             -- north, east, south, west
    { name = "electric-mining-drill", minerai = "copper-ore" },       -- minerai sous la zone d'extraction
    { name = "stone-wall", rangee = 5 },                              -- n exemplaires côte à côte
    { name = "small-biter", force = "enemy", actif = false },         -- force, entité figée
    { name = "fo-lvl-gun-3", raise_built = true },                    -- déclenche les gestionnaires du mod
  },
  references = nil,            -- facultatif : remplace la liste des références (mêmes formes d'entrée)
  gros_plans = { 2 },          -- zooms des gros plans (2 = résolution native des sprites HR)
  alt_mode = false,            -- icônes « Alt »
  anti_alias = false,          -- false : pixels tels qu'en jeu
}
```

Chaque rangée : l'entité demandée, puis les références vanilla (machine d'assemblage 2 qui fabrique, four en
acier allumé, mitrailleuse chargée, tourelle laser, 3 murs de pierre, foreuse électrique sur du fer), 3 tuiles
d'écart, alimentées par un poteau et une source **invisibles** (`fo-autotest-power-pole`,
`fo-autotest-power-source`, définis par `fo-autotest/data.lua`) : aucun poteau dans le cadre. Faune : cessez-le-feu
et zone vidée sur 160 tuiles.

Captures (jour = daytime 0, nuit = 0,5), pour la rangée `k` de l'entité `<nom>` :

| Fichier | Vue |
|---|---|
| `NNN-vitrine-ensemble-jour/nuit` | Toutes les rangées (s'il y en a plusieurs) |
| `NNN-vitrine-kk-<nom>-rangee-z1-jour/nuit` | Rangée entière, zoom 1 |
| `NNN-vitrine-kk-<nom>-debut-z2-jour/nuit` | Entité et premières références, zoom 2 |
| `NNN-vitrine-kk-<nom>-gros-plan-z<z>-jour/nuit` | Entité seule, cadre serré, pour chaque zoom de `gros_plans` |

Une entité refusée donne une ligne `[FO-VITRINE] ECHEC` dans `fo-autotest\create.log`, une rangée `ECHEC`
dans `vitrine.txt` et le **code de sortie 6** (les captures sont prises quand même).

## 4. Greffons : scénarios et contrôles ajoutés par d'autres lots

Un lot ajoute ses bancs dans **ses propres fichiers** du mod de test, sans modifier `control.lua`,
`content_test.lua` ni `shots.lua`. Tous les `require` ont lieu au chargement du mod, jamais pendant un
événement (F24). Chaque crochet est appelé sous `pcall` : une erreur Lua devient une ligne `ECHEC` comptée dans
le BILAN, et la partie continue. Pas de fonction dans `global` : l'état persistant passe par `ctx.state()`.

### 4.1 Scénario greffé : `fo-autotest/scenarios/<nom>.lua`

Un nom de scénario inconnu de `control.lua` (`fo-autotest-params.txt` : `600 <nom>`, ou
`fo-captures.bat <nom>`) charge ce fichier. Il renvoie une table :

| Champ | Quand | Rôle |
|---|---|---|
| `description` | — | Texte du journal |
| `base` | — | Facultatif : scénario intégré préparé d'abord (`default`, `pteam`, `waves`, `content`...) |
| `init(ctx)` | `on_init`, à la création de la carte (`--create`) | Construire la carte, poser une base témoin... |
| `tick(ctx, e)` | Chaque tick (banc ET session visuelle) | Mesures, actions ; coupé après une erreur |
| `check_tick` | — | Tick de `finish` (défaut 3 000) : le banc doit durer au moins autant |
| `finish(ctx)` | Au tick `check_tick` | Contrôles finaux ; le BILAN suit automatiquement |
| `shots(ctx, add)` | Session visuelle | Facultatif : `add(nom, x, y, zoom, daytime[, {res = {w, h}, info = bool, aa = bool}])` |
| `shots_delay` | — | Ticks avant la première capture (défaut 90) |

Journal : `[FO-<NOM>] OK     <contrôle> : <détail>`, `[FO-<NOM>] ECHEC  ...`, puis
`[FO-<NOM>] BILAN : n OK, m ECHEC(S)` (même format que `[FO-CONTENT]`).
Exemple qui fonctionne : `scenarios/exemple.lua` (machine témoin alimentée qui fabrique ; 5 contrôles, 2 captures).

Scénarios greffés des lots de niveaux :
- `ht3-migration` (suite H-T3) et `t2-migration` (lot V3-T2) : migration d'une sauvegarde ancienne, en double
  source seulement (§1.1) ; le journal se contrôle avec `ht3_journal.py` (`--tag FO-T2-MIGRATION` pour le second) ;
- `t2-machines` (lot V3-T2, 1 500 ticks) : joue les greffons `checks/levels_machines.lua` et
  `checks/levels_points.lua` (§4.2) au tick 60, chacun dans sa zone et avec son propre état (sous-table de
  `ctx.state()`), et rejoue les refus au tick 1440 ; vérification au tick 1400, captures à partir du tick 1450.
  Dans le banc `content`, ces greffons n'agissent qu'aux ticks 1750 et 1760, après les captures de la galerie :
  ce scénario sert à photographier les machines APRÈS l'agrandissement et les contours de refus
  (`& "<racine>\fo-captures.bat" t2-machines "<source>"`). Attendu sur `main` (22/10, 19:05:44,44 ; 20:11:19,61 après le
  lot R1) : « [FO-T2-MACHINES] BILAN : 80 OK, 0 ECHEC(S) » ;
- `t2-defense` (lot R1, 1 200 ticks) : migration d'une défense dense, en double source seulement (§1.1, troisième
  exemple) ; journal : `ht3_journal.py --tag FO-T2-DEFENSE` ;
- `bord-a-bord` (lot R1, 60 ticks ; cas joués au tick 5, contrôles au tick 30) : contact EXACT entre une zone de
  recherche et la boîte de collision d'une entité, en moteur réel (RD_LOG E53, F96 à F98). Trois entités en force
  neutre (mur de pierre ± 0,29, mitrailleuse vanilla ± 0,7, laser 7 du mod ± 1,2), zones bâties sur la boîte RENDUE
  (`bounding_box`) ; 45 cas (4 bords, 2 coins, zones nulles, chevauchement et écart de 1/256, rayons), chacun joué
  avec `find_entities_filtered` et `count_entities_filtered` et comparé à la règle du moteur simulé (`STRICT = false` :
  intervalles fermés, comme `tests/mock_engine.lua` depuis le 22/10). Un écart est un ECHEC : aligner le moteur
  simulé, puis rejouer tous les bancs hors jeu. `position` seule est journalisée, pas comparée. Sans double source :
  `& "<racine>\fo-autotest.bat" nopause 60 bord-a-bord "<source>"`. Attendu sur `main` (22/10, 20:11:23,82) :
  « [FO-BORD-A-BORD] BILAN : 12 OK, 0 ECHEC(S) ». Premier passage avant l'alignement (19:48) : 11 OK, 1 ECHEC,
  21 écarts sur 45 cas.
- `t3-libere` (lot V3-T3, 1 900 ticks ; `check_tick` = 1 800, à cause des vrais robots) : bouton « Libérer la place »
  en moteur réel (RD_LOG E59), par l'interface distante `levels_free_room`, comme le bouton du panneau. Zone de
  (300, 240) à (444, 344), douze zones (en-tête du scénario) :
  - A : usine dense (assembleur 6 bordé d'un bras d'entrée et d'un bras de sortie FILTRANT, convoyeurs, voisin collé,
    poteau) ; B1 : mitrailleuse collée à un mur, nourrie par un bras (Q-T3) ; B2 : mur épais et eau (candidate
    nord-est, ligne refermée par 2 murs de liaison) ;
  - C1 : Annuler tout de suite ; C2 : Annuler après le démontage du bras (usine remise comme avant, la machine
    refabrique) ; D : sans clic, rien ne change ;
  - E : coût absent (clic refusé), présent, retiré (la demande attend), revenu (agrandissement) ; F : assembleur
    serré entre deux voisins (refus « blocked », rien de marqué) ; G : deux voisins libérés l'un après l'autre
    (carrés disjoints) ;
  - R : VRAIS robots de construction (roboport, 20 robots, coffre de stockage) ; V : une voiture dans la candidate
    (signalée, autre candidate retenue) ; L : clic APRÈS le bilan, pour les captures (et F recliqué : refus en violet).
  Forces `fo-t3` (centre 15 qui paie), `fo-t3p` (centre 15 vide d'abord), `fo-t3r` (robots réels). Ailleurs qu'en R, le
  banc joue les robots : il MINE les entités marquées dans un inventaire (rien ne se perd), le mod agrandit le bâtiment
  de lui-même à sa vérification périodique (60 ticks), puis le banc construit les fantômes (`revive`). Sans double
  source : `& "<racine>\fo-autotest.bat" nopause 1900 t3-libere "<source>"`. Attendu sur `main` (22/10, 22:50:58,19) :
  « [FO-T3-LIBERE] BILAN : 41 OK, 0 ECHEC(S) ». Images : `& "<racine>\fo-captures.bat" t3-libere "<source>"` depuis
  PowerShell, 4 captures prises après le bilan (`shots_delay` = 1 840) : `001-usine-dense-apres`, `002-robots-apres`,
  `003-liberee-avant-robots`, `004-refus-voisins-violet`. Exemple archivé :
  `<racine>\fo-logs\2026-10-22_V3T3\correcteur\captures-t3-libere\` ;
- `t3-migration` (lot V3-T3, 1 000 ticks) : « libérer la place » pour un bâtiment laissé HORS GRILLE par une VRAIE
  migration, en double source SEULEMENT (§1.1 ; un script ne sait pas fabriquer un bâtiment hors grille : RD_LOG F104).
  Création par `<racine>\fo-logs\2026-10-22_V3T2\src-0.4.2` (deux assembleurs 8 collés, en 3×3, force `fo-t3m`) ;
  benchmark par 0.4.4 : l'assembleur laissé hors grille est refusé (« no-room ») ; au clic, bras sud et deux tuiles du
  convoyeur marqués, fantômes posés ; les marques minées, il est remis sur la grille au niveau 9 de lui-même ; l'usine
  remarche :
  ```
  $env:FO_CREATE_SRC = "<racine>\fo-logs\2026-10-22_V3T2\src-0.4.2"
  & "<racine>\fo-autotest.bat" nopause 1000 t3-migration "<source 0.4.4>"
  $env:FO_CREATE_SRC = $null
  ```
  Attendu sur `main` (22/10, 22:51:53,59) : « [FO-T3-MIGRATION] BILAN : 7 OK, 0 ECHEC(S) ». À 700 ticks, le banc
  s'arrête avant le contrôle, sans BILAN (passage du 22/10 à 22:51:02,43). Pas de contrôle de journal.

Scénario greffé du lot A2 (mitrailleuse V3-E en jeu, 24/10) :
- `gun-rose` (1 000 ticks ; contrôle au tick 900) : en (3000, −2400), une rangée par niveau (âge e : niveau impair,
  puis niveau pair 10 tuiles plus bas ; âge 1 : niveaux 1 et 2), chacune avec la mitrailleuse VANILLA puis le niveau
  orienté N, E, S, O par `orientation` écrite au tick 30 (E70, F122) ; en (3200, −2400), 60 sites de TIR en grille de 8
  colonnes à 80 tuiles (un niveau par âge, niveaux impairs 1 à 29, face à un ver géant ennemi au N, à l'E, au S et à
  l'O, aligné sur le centre RÉEL de la tourelle, cessez-le-feu de l'ennemi, ver recréé s'il meurt).
  Contrôles : prototypes, 150 + 60 tourelles posées, orientation écrite, tenue 30 ticks après et au tick 900,
  `drawing_box` plus haute que la sélection (niveaux 3 à 30 ; niveau 2 vanilla sans), reste agrandi (copie déclarée
  « -restes ») dès 3×3, chaque tourelle de tir a consommé des chargeurs et vise sa cible, et (correction A2, E68)
  l'ÉCLAT (entité `explosion-gunshot`, relevée par `find_entities_filtered`) naît en projectile_center + distance ×
  (vx, vy) / |(vx, vy / 0,7071)| (v = cible − projectile_center, valeurs du prototype) à 1/32 de tuile près, 60/60.
  Sans double source : `& "<racine>\fo-autotest.bat" nopause 1000 gun-rose "<source>"`. Attendu (correction A2) :
  « [FO-GUN-ROSE] BILAN : 11 OK, 0 ECHEC(S) » (10 avant la correction). Images :
  `& "<racine>\fo-captures.bat" gun-rose "<source>"` : 92 captures (par âge, zoom 1, jour et nuit ; âges 3, 9, 15 au
  zoom 2 ; niveaux PAIRS 10, 18, 30 au zoom 2, jour et nuit ; tir des niveaux 1, 3, 23, 25 et 29 en 4 directions,
  zoom 2, deux instants). Les feuilles d'images de la mitrailleuse (`graphics/levels/gun/*.png`) sont HORS de git
  (D-6) : un worktree neuf doit d'abord les régénérer (`py -3.9 tools/render/pieces/levels/gun_e/feuilles.py`) ; le
  harness et `levels_test` le disent (« Feuilles mitrailleuse : … manquant(s) » suivi de la commande) et échouent.
- `a2-icones` (correction A2 ; 120 ticks ; pour les images) : tourelles chargées, coffres garnis, assembleurs, en mode
  Alt, captures aux zooms 0,3 ; 0,45 ; 0,7 ; 1,3 (entre deux niveaux de mipmap) : effet visible de `linear-mip-level`
  sur l'atlas [icon] (F125), à comparer entre deux copies du mod. `$env:FO_VISUAL_ARGS = '--quality normal'`, puis
  `& "<racine>\fo-captures.bat" a2-icones "<source>"`, puis `$env:FO_VISUAL_ARGS = $null`. Attendu :
  « [FO-A2-ICONES] BILAN : 2 OK, 0 ECHEC(S) », 4 captures.

Scénario greffé du lot S0-suite (le son du tir JOUÉ en jeu, 24/10) :
- `s0-tir` (3 000 ticks sans images ; contrôle au tick 2 640) : six sites à 240 tuiles d'écart, en (2600 + 240 k,
  −3200), joués l'un après l'autre dans un ordre mêlé (ère III, vanilla, ère V, ère I, ère IV, ère II ; niveaux 13, 1,
  25, 3, 19, 9), chacun une fenêtre de 420 ticks ; une tourelle face à un ver géant ennemi 11 tuiles au nord
  (cessez-le-feu de l'ennemi) ; la tourelle ne reçoit qu'UNE cartouche à la fois (chargeur réduit à 1, champ `ammo`),
  toutes les 60 ticks, 6 par site : chaque tir est un son isolé. Le tick où la cartouche disparaît est écrit au journal
  (« [FO-S0-TIR] TIR<TAB>site=…<TAB>niveau=…<TAB>ere=…<TAB>tick=… » ; le tir et son son ont lieu au tick PRÉCÉDENT,
  `on_tick` venant avant la mise à jour des entités : vu en moteur, exception du mutant Opus au tick 161 pour un tir
  journalisé au tick 162). Session avec images : au début de chaque fenêtre, le joueur est téléporté 8 tuiles au sud de
  la tourelle (écouteur). Contrôles : 6 tirs par site, dans la fenêtre, séparés d'au moins 50 ticks, et (avec images)
  écouteur placé sur chaque site. Sans images : `& "<racine>\fo-autotest.bat" nopause 3000 s0-tir "<source>"` →
  « [FO-S0-TIR] BILAN : 5 OK, 0 ECHEC(S) » (24/10, 00:13:05). Avec images ET son (seule voie : §1.3) :
  ```
  $env:FO_AUDIO = '1'
  & "<racine>\fo-captures.bat" s0-tir "<source>"
  $env:FO_AUDIO = $null
  py -3.9 tools/sound/tirs_joues.py "<racine>\fo-visual\audio-disk.raw" "<racine>\fo-visual\write\script-output\fo-shots\factorio.log"
  ```
  → code 0, 6 captures, « [FO-S0-TIR] BILAN : 6 OK » dans `fo-shots\factorio.log`, garde « sessions audio Windows du
  processus de test : 0 … crete max 0.000000 », puis « [FO-TIRS-JOUES] BILAN : 36 tir(s) au journal ; reconnus 36, ere
  juste 36, instant juste (+/- 60 ms) 36 ; detections sans tir 0 : OK » (24/10 vers 00 h 15). Mutant : ères III et V
  échangées dans une copie du mod → 12 tirs « ERE FAUSSE », code 1.

Scénarios greffés du lot M0 (socle du monde : garantie des monnaies des époques 5, 7 et 8, `script/world/guarantee.lua`) :
- `monde` (700 ticks ; contrôle final au tick 660) : PLUSIEURS GRAINES sans toucher à `fo-autotest.bat` (graine
  20261020 par défaut ; depuis le lot INT-GRAINE, `FO_MAP_SEED` change celle de nauvis, §1.2) : chaque graine est jouée sur une surface créée par le scénario (`game.create_surface`, réglages de nauvis,
  autre graine). Nauvis (garantie posée à on_init), 5 graines (1, 42, 123456, 987654321, 3141592653) en surface neuve
  (A) et explorée sur 23 chunks (B : relevé des gisements NATURELS, puis garantie comme dans une sauvegarde), une carte
  sans les 3 ressources (C), des obstacles (D : coffre du joueur, eau), le filet périodique (F, tick 600). Sans double
  source : `& "<racine>\fo-autotest.bat" nopause 700 monde "<source>"`. Attendu (lot M0, 23/10, 16:13:17) :
  « [FO-MONDE] BILAN : 89 OK, 0 ECHEC(S) ». En `--create`/`--benchmark`, rien n'est cartographié : les étiquettes de
  carte restent en attente (contrôlé). Avec images : `& "<racine>\fo-captures.bat" monde "<source>"` (9 captures des 3
  sites de nauvis, jour, nuit, de près ; la cartographie y tourne : 91 OK, étiquettes posées) ;
- `m0-migration` (700 ticks), double source SEULEMENT : une sauvegarde 0.4.4 rechargée par la source M0
  (`on_configuration_changed`), gisements déjà connus comptés, coffre du joueur évité :
  ```
  $env:FO_CREATE_SRC = "<racine>\fo-logs\2026-10-23_suite\M0\src-0.4.4"
  & "<racine>\fo-autotest.bat" nopause 700 m0-migration "<source M0>"
  $env:FO_CREATE_SRC = $null
  ```
  `src-0.4.4` = `git archive 93e3d89` (version 0.4.4) : à GARDER. Attendu (23/10, 16:14:03) : « [FO-M0-MIGRATION]
  BILAN : 9 OK, 0 ECHEC(S) ».
- `m0-reprise` (2 600 ticks ; contrôle final au tick 2 460 ; correction M-1) : sur nauvis, la garantie du tungstène
  ÉCHOUE deux fois (coffres du joueur sur les 24 candidats des essais 0 et 1, gisements de tungstène retirés à moins de
  dmax), n'est PAS marquée traitée, puis réussit au filet du tick 2 400 (essai 2, niveau 2 : eau posée sous la moitié
  des candidats, tolérée et comblée par les cendres). Sans double source :
  `& "<racine>\fo-autotest.bat" nopause 2600 m0-reprise "<source>"`. Attendu (23/10, `done.txt` 16:45:02,98) :
  « [FO-M0-REPRISE] BILAN : 15 OK, 0 ECHEC(S) ».

Depuis le lot V3-T3, `t2-migration` et `t2-defense` journalisent aussi, après leurs contrôles, une ligne
« LIBERER LA PLACE (plan seul, hors bilan) : n liberable(s) sur m laisse(s) : … » : `levels_free_room` en plan seul
(`{ dry = true }`, rien n'est posé) pour chaque bâtiment laissé par la migration. Cette ligne est HORS bilan : le
BILAN et le contrôle du journal par `ht3_journal.py` restent ceux d'avant (`t2-migration` 64 + 26 ; `ht3-migration`
30 + 7 ; `t2-defense` 36 + 19 et 36 + 11, verts sur `main` le 22/10 de 22:51:06 à 22:51:19). Valeurs sur `main` : 5
sur 19 (`t2-migration`), 2 sur 13 (`t2-defense`, création 0.4.1), 0 sur 5 (création 0.4.2) : seuls les bouts de
rangée se libèrent (RD_LOG E59).

### 4.2 Contrôles greffés au banc `content` : `fo-autotest/checks/<nom>.lua`

Ajouter le fichier et son nom dans `checks/index.lua` (une ligne par lot). Le fichier renvoie :

| Champ | Quand |
|---|---|
| `setup(ctx)` | Pendant la préparation du banc (`on_init`), après le socle |
| `tick(ctx, e)` | Chaque tick, facultatif |
| `verify(ctx)` | Au tick de vérification du banc (3 000), avant son BILAN |
| `shots(ctx, add)` | Facultatif : captures ajoutées à la galerie `content` (préfixe `greffon-<nom>-`) |

Les contrôles s'écrivent `[FO-CONTENT] OK     <nom> : <contrôle>` et sont **comptés dans le BILAN du banc
content**, suivi d'une ligne de détail : `[FO-CONTENT] greffons (checks/index.lua) : exemple 2 OK 0 ECHEC`.
Chaque greffon reçoit une zone libre `ctx.zone = { x0, y0, x1, y1 }` (128 × 96 tuiles à partir de (300, 240),
une par rang dans l'index, hors de l'arène) et `ctx.prepare_zone(tuile)`.
Exemple : `checks/exemple.lua` (tourelle laser alimentée sans poteau ; 2 contrôles, 1 capture). Avec lui, le
banc `content` comptait **182 OK = 180 du socle + 2 greffés** (lot P1).

Greffons de l'index au 22/10 (lot V3-T2), dans l'ordre, avec leur zone (x0 = 300 + 144 × (rang − 1), y de 240 à
336) :

| Rang | Greffon | Lot | Zone (x) | Contrôles | Ce qu'il joue |
|---|---|---|---|---|---|
| 1 | `exemple` | P1 | 300 à 428 | 2 | Tourelle laser alimentée sans poteau |
| 2 | `levels_taille` | V3-T | 444 à 572 | 26 | Mitrailleuse : agrandissement sur place, refus et contour, transfert, chaîne 6 → 30 |
| 3 | `levels_machines` | V3-T2 | 588 à 716 | 54 | Laser, foreuse, four, assembleur, centre : transfert réel du contenu, raccord et dépôt, usine dense (refus, retrait des gênes, agrandissement), chaînes 6 → 30 et 1 → 15, prototypes des 5 familles |
| 4 | `levels_points` | V3-T2 (correcteur) | 732 à 860 | 25 | Points de jeu servis dans les 4 orientations (12 foreuses, 12 assembleurs à fluide), refus, fabrications en cours à travers le remplacement rapide, sortie pleine, F84 rejoué, barre du coffre, coût du `on_tick` de reprise (H-L1) |

Avec eux, le banc `content` compte **317 OK = 210 du banc + 2 + 26 + 54 + 25** (`main`, 22/10, 19:05:39,98) ; la
ligne du journal dit « greffons (checks/index.lua) : exemple 2 OK 0 ECHEC, levels_taille 26 OK 0 ECHEC,
levels_machines 54 OK 0 ECHEC, levels_points 25 OK 0 ECHEC ». Les greffons V3-T2 agissent au tick 1750
(`levels_machines`) et 1760 (`levels_points`), après les captures de la galerie : pour des images des machines
agrandies, utiliser le scénario greffé `t2-machines` (§4.1).

### 4.3 Contexte `ctx`

| Membre | Rôle |
|---|---|
| `ctx.ok(nom, détail)`, `ctx.fail(nom, détail)`, `ctx.check(cond, nom, détail)` | Contrôles, comptés dans le BILAN |
| `ctx.log(msg)` | Ligne de journal avec l'étiquette du greffon |
| `ctx.state()` | Table persistante propre au greffon (dans un crochet seulement) |
| `ctx.surface()` | `game.surfaces[1]` |
| `ctx.call(fn, ...)` | `remote.call("factorio-overhaul", fn, ...)` : interface distante du mod |
| `ctx.remote(iface, fn, ...)`, `ctx.has(iface[, fn])` | Autre interface ; présence d'une interface ou d'une fonction |
| `ctx.prepare_area(x0, y0, x1, y1, tuile)` | Zone générée, vidée, pavée, sans décor |
| `ctx.power(x, y[, force])` | Alimentation invisible : poteau de portée 64 (zone 128 × 128) et source de 600 GW |
| `ctx.zone`, `ctx.prepare_zone(tuile)` | (contrôles greffés) zone réservée |

## 5. D4 : mémoire vidéo et usine géante (lot D4m)

Objet : OBJECTIFS.md D4-1 (atlas du jeu entier ≤ 6 Go en haute qualité, PC cible à 8 Go de mémoire vidéo),
D4-2 (basse qualité rendue, lisible, gigantisme gardé), D4-3 (chargement + 30 s au plus), D4-5 (usine géante :
mémoire vidéo et images par seconde mesurées dans les deux qualités, 60 images/s visées). Q21 : la basse qualité
doit garder « un certain range » pour faire tourner le jeu (16 Go de mémoire vive) : la procédure mesure aussi le
**plancher** (§5.3, passage 5).

### 5.1 Outils

**`vram.py`** (ne lance rien, lit des fichiers) :

```
python tools/autotest/vram.py <journal ou dossier> [--samples vram.tsv] [--perf perf-stats.csv]
                              [--stdout stdout.txt] [--seuil-go 6] [--json sortie.json]
python tools/autotest/vram.py --sonde        (les compteurs GPU de Windows sont-ils lisibles ?)
```

Le dossier peut être `fo-shots`, une archive `fo-logs\...` ou `fo-visual` : le journal (`factorio.log`,
`visual.log` ou `factorio-current.log`), `vram.tsv`, `perf-stats.csv` et `stdout.txt` y sont cherchés. Rapport :
réglages appliqués (qualité, usage de la mémoire vidéo, compression DXT, budget Windows, VSync, écran et sa
fréquence), un atlas par ligne avec sa catégorie et une FOURCHETTE d'octets, totaux par catégorie, verdict D4-1 sur
l'estimation haute, chargement (cache des atlas lu ou refait), mesure directe, champ réel des vues `d4-geant`
(lignes `CHAMP`), UPS par phase, images/s. Règle d'octets par pixel (justification en tête du script) :

| Atlas | Octets par pixel (bas–haut) | Statut et source |
|---|---|---|
| drapeau `not-compressed` (icônes) | 4–4 | Prouvé : drapeau du journal, « [Color: 32bit] » (RGBA 8 bits) |
| compression « high-quality » (défaut) | 1–1 | Prouvé par le journal : le jeu teste BC3 et YCoCg-DXT5 (« YCoCgDXT PSNR / BC3 PSNR »), 16 octets par bloc 4×4 |
| compression « low-quality » | 0,5–1 | **Hypothèse** (BC1, 8 octets par bloc). Sources partielles : le sens (« select low quality to reduce the size of sprites even more », `data/core/locale/en/core.cfg`, clé `texture-compression`) et le nuanceur `compress-rygDXT` du binaire ; format exact absent du journal |
| compression « none » | 4–4 | RGBA 8 bits |
| drapeau `alpha-mask` (ombres, masques) | 0,5–1 compressé ; 1–4 sans | **Hypothèse** : un canal utile (BC4 : le binaire contient le nuanceur `compress-bc4` ; ou A8/BC3) ; format exact absent du journal |
| mipmaps (« Generated mipmaps (N) ») | × (1 + 1/4 + …) | Journal : N niveaux en tout (bas) ou en plus de la base (haut) |
| pages d'atlas virtuel (plancher) | règle DXT d'un atlas « [none] » ; haut : + 1/3 de la plus grande surface pour les mipmaps | Dimensions prouvées par le journal ; résidence et compression : **hypothèses** (§5.1, « Atlas virtuel dans l'estimation ») |

La mesure directe (ci-dessous) tranche : une estimation ne prouve rien.

Essai sur les **8 journaux** de session archivés (21/10, `fo-logs\*\visual.log` : essai 1, galeries `content` sans
cache 1 et 2, galeries finales 1 et 2, guerre, vitrine finale, vitrine sans cache) : tous donnent 15 atlas,
1,070 milliard de pixels, **1,10 à 1,25 Go estimés** (haute qualité, DXT « high-quality »), 4,28 Go sans
compression (F66). Sprites chargés en **4,4 à 8,9 s** quand le cache des atlas est lu (4 sessions), **35,5 à 195,3 s**
quand il est refait (4 sessions). Toutes ont « [VSync: 1] » et un écran 3840 × 2160 à 144 Hz. Le « CurrentUsage »
des lignes `[Local Video Memory]` est lu au démarrage du moteur graphique, AVANT tout chargement (2 Mio) : ce n'est
pas l'occupation du jeu.

**Images par seconde.** Le fichier `--output-perf-stats` (option `--measure` du pilote) a les colonnes de
`PerformanceLogger.cpp` (lues dans le binaire) : `prepare`, `texture-streaming-analysis`, `texture-streaming-update`,
`cpu-render`, `cpu-flip`, `sleep`, `cpu-frame`, `sprite-count`, `draw-call-count`, `tiles-rendered`, `vt-tiles-*`,
`gpu-terrain-render`, `gpu-draw-engine-render`, `gpu-frame`, `sync-interval`, `last-present-count`, `present-count`,
`refresh-count`, `sync-refresh-count`, `frames-skipped`. Leur sens n'est pas documenté : `vram.py` calcule les images/s
par **plusieurs voies, à confronter**, par phase du scénario `d4-geant` :

| Voie | Calcul | Statut |
|---|---|---|
| phase | lignes du fichier pendant la vue / durée réelle de la vue (LuaProfiler du greffon) | suppose une ligne par image |
| max(cpu,gpu) | 1000 / moyenne de max(`cpu-frame`, `gpu-frame`) | une image ne dure pas moins que la plus longue des deux |
| cpu-frame | 1000 / moyenne de `cpu-frame` | **Hypothèse** « cpu-frame = durée totale de l'image » : si elle exclut l'attente du GPU, ce chiffre SURESTIME le cas visé (usine limitée par le GPU). Test : somme des `cpu-frame` / durée de la vue ≈ 1 |
| compteurs | écarts de `present-count` et `refresh-count` (s'ils croissent) / durée de la vue | sens supposé ; `refresh-count` devrait donner la fréquence de l'écran |

VSync actif (toutes les sessions archivées) : les images/s sont plafonnées à la fréquence de l'écran (144 Hz ici) ;
un plafond à 60 imposé par le jeu lui-même n'est pas prouvé. Les vues « repère » (zone vide) donnent l'UPS de la
**simulation seule** : si l'UPS d'une vue chargée tombe sous 60 alors que celui des repères reste à 60, c'est le
rendu qui limite ; si les repères tombent aussi, c'est la simulation de l'usine.

**Pilote `visual_session.py`** (options par `FO_VISUAL_ARGS`, aucun `.bat` modifié) :

| Option | Effet |
|---|---|
| `--quality high\|normal` (alias `--graphics-quality`, même nom que l'option du correctif temporaire V0b ; `low` et `very-low` acceptés, migrés vers normal par le jeu) | Clé `graphics-quality` du `config.ini` DE TEST (`fo-visual\config.ini`, section `[graphics]`) ; toute valeur sauf `high` est aussi passée au binaire (`--graphics-quality`, qui n'accepte que normal, low, very-low). Vérifiée dans le journal : écart = code 9 |
| `--video-memory all\|high\|medium\|low` | Clé `video-memory-usage` et option `--video-memory-usage` du binaire ; vérifiée de même |
| `--texture-compression none\|high-quality\|low-quality` | Clé `texture-compression-level` du `config.ini` DE TEST (aucune option du binaire) ; vérifiée par « [DXT: …] » du journal : écart = code 9. Valeurs supposées (§ Non prouvé) |
| `--measure` | Le jeu écrit ses statistiques de rendu (`--output-perf-stats fo-visual\perf-stats.csv`, recopié dans `fo-shots`) et le pilote attend la FIN NATURELLE du mode benchmark (budget `--ticks`) au lieu de fermer la session au marqueur |
| fenêtre `hd` (3e argument de `fo-captures.bat`) | 1920 × 1080, affichée SANS prendre le focus ; `--size LxH` change la taille |

Toujours actif (même sans `--measure`) : relevé toutes les 0,5 s de la mémoire vidéo **du seul PID de la session de
test** (compteurs Windows `\GPU Process Memory(pid_<PID>_*)\Dedicated Usage` et `Shared Usage`, lus par PDH sous
leurs noms ANGLAIS, donc indépendants de la langue de Windows ; lecture seule), de l'occupation de toute la carte
(`\GPU Adapter Memory(*)\Dedicated Usage`, tous programmes confondus) et de la mémoire vive du processus
(`GetProcessMemoryInfo`). Sorties dans `fo-shots` : `vram.tsv`, `memoire.txt` (rapport `vram.py`), `factorio.log`,
`stdout.txt`, et dans `session.txt` : mémoire vidéo dédiée (pic, moyenne ; en fenêtre réduite, **borne basse**
signalée), champ réel de chaque vue, UPS par phase, VSync et fréquence de l'écran, images/s par voie. Le pilote note
aussi le nombre de `factorio.exe` hors test au lancement : s'il n'est pas nul, images/s et occupation de la carte
sont faussées (une autre partie partage la carte et le processeur).

Clés et options lues dans le binaire 1.1.91 (chaînes, sans lancer le jeu) : `graphics-quality` (« accepted values:
normal, low, very-low » ; dans la configuration, « 'low' and 'very-low' options are deprecated and will be migrated
to 'normal' »), `video-memory-usage` (« all, high, medium, low »), `output-perf-stats` (« path of file to which
rendering performance statistics measurements should be saved »), les colonnes ci-dessus, `texture-compression-level`,
`v-sync`, `halt-rendering-when-minimized` et `low-vram` (option du binaire : « sprites that are not put into sprite
atlases won't be allocated as texture objects » ; non câblée dans le pilote). Les clés de configuration
`texture-compression-level`, `v-sync` et `halt-rendering-when-minimized` sont dans le même bloc que `full-screen` et
`compress-sprite-atlas-cache` (section `[graphics]`, prouvée par le lot P1) ; leurs VALEURS ne figurent pas dans le
binaire. L'option `--graphics-quality normal` est prouvée en moteur par le lot V0b (journal « [Graphics quality:
normal] »).

**Bancs hors jeu** (`tools/autotest/tests/`, versés au lot D4m) : `python -B tools/autotest/tests/run_d4m.py
[--work DOSSIER] [--logs "<racine>/fo-logs"]` enchaîne l'essai à blanc du greffon (`d4_dryrun.lua`, moteur simulé),
les fixtures synthétiques (`make_fixtures.py`), les unitaires de `vram.py` (`unit_vram.py`), l'intégration du pilote
sur une racine factice avec un faux jeu (`driver_it.py`, `fake_game.py`) et, avec `--logs`, `vram.py` sur chaque
journal archivé. Attendu le 21/10 : **5/5 étapes** (essai à blanc 11 OK, BILAN du greffon 16 OK ; unitaires 51 OK ;
intégration 17 OK ; 8 journaux ; 57 unitaires et 13 journaux depuis le 22/10, voir ci-dessous). Ne lance
pas Factorio et n'écrit rien dans la racine du jeu. **À lancer depuis Git Bash** : l'essai à blanc appelle `lua5.2`,
qui n'est pas dans le PATH de PowerShell ; sous PowerShell, le banc donne 2/5 (code 127 de l'appel ; constaté le 22/10
par la suite « défense dense » du lot R1).

**Étape 5 : atlas attendus selon les réglages du journal** (corrigée le 22/10 ; avant, elle exigeait 15 atlas
partout et refusait les journaux D4m 3 à 5). Le nombre d'atlas dépend de ce que le journal déclare sur sa ligne
« Graphics options » (qualité, usage de la mémoire vidéo, compression DXT). La table `ATLAS_ATTENDUS` de
`run_d4m.py`, étalonnée sur les 13 journaux archivés au 22/10, donne pour chaque combinaison le nombre d'atlas en
tout, le nombre d'atlas « [none] » (sprites principaux), la présence d'un atlas virtuel et la taille des atlas
« [none] » par rapport au seuil `SEUIL_NONE_PX` (4096 × 4096, soit 16,8 Mpx) :

| Réglages déclarés | Atlas | dont « [none] » | Pixels « [none] » | Atlas virtuel | Journaux d'étalonnage |
|---|---|---|---|---|---|
| high / all / high-quality | 15 | 2 (16384×16364 plein, puis 16384×12676) | plus de 16,8 Mpx (475,8) | non | P1 (8), D4m 1 et 2 |
| normal / all / high-quality | 14 | 1 (16384×8604) | plus de 16,8 Mpx (141,0) | non | D4m 3 et 4 |
| normal / low / low-quality (plancher) | 14 | 1 (2048×1316) | au plus 16,8 Mpx (2,7) | oui (« Created virtual atlas pages 4096x4096x9 ») | D4m 5 |

Le seuil de 16,8 Mpx n'est pas une limite du moteur : c'est une ligne de partage entre les valeurs observées, égale
à une page d'atlas virtuel. Il refuse un plancher qui ne s'est pas appliqué, et un plancher appliqué à tort.

Les 13 autres atlas (liste `AUTRES_ATLAS` : decal, low-object, terrain, ombres, icônes, etc.) figurent **une fois par
catégorie** dans chacun des 13 journaux, avec les mêmes drapeaux, à une exception près : l'atlas « [low-object] »
porte `linear-minification` en haute qualité et au plancher, mais pas en qualité normale avec mémoire « all »
(observé, non expliqué). C'est la seule variation tolérée ; l'étape vérifie que chacune des 13 signatures est
présente exactement une fois, et qu'aucune autre n'apparaît. Les lignes comptées sont celles du **moteur** : une ligne
horodatée qui commence par « Created atlas bitmap » ou « Created virtual atlas pages ». Une impression de script
(« Script @…: … ») qui contient ces mots ne compte pas (`vram.py`, `RE_ATLAS` et `RE_VIRTUAL`). `vram.py` relève
l'atlas virtuel dans `virtual_atlases` et, depuis la suite « vram » (22/10), le COMPTE dans son estimation
(ci-dessous, « Atlas virtuel dans l'estimation »).

Des réglages absents de la table, ou une ligne « Graphics options » absente, font échouer l'étape : on ajoute une
entrée après avoir lu un journal réel, on n'en élargit jamais une. Attendu le 22/10 : **5/5 étapes, 13 journaux**
(unitaires de `vram.py` : 99 OK depuis la suite « vram », 57 avant, dont 6 sur les lignes du moteur et l'atlas
virtuel ; la suite en ajoute 42 sur le comptage de l'atlas virtuel).

**Atlas virtuel dans l'estimation** (suite « vram » du lot R1, 22/10, RD_LOG E55, F81 et F102 ; règle complète en tête
de `vram.py`). Au plancher
(« Video memory usage: low », « Tex.Stream.: 1 »), le journal prouve deux choses : la création de N pages de L×H pixels
(« Created virtual atlas pages 4096x4096x9 », 151,0 Mpx) et des mipmaps pour un atlas virtuel de 16384×12288
(201,3 Mpx, sans nombre de niveaux). Il ne dit ni où vivent les pages, ni leur format (clé `compress-virtual-atlas`
du binaire ; assertion « virtualAtlasPage->getFormat() == BitmapFormat::RGBA_8888 »). Lecture la plus probable, NON
prouvée : la locale (« kept in RAM until needed by the GPU ») parle des sprites SOURCES hors atlas, gardés en mémoire
vive ; les 9 pages créées, moins que les 12 surfaces de page de l'atlas virtuel annoncé, seraient le cache PHYSIQUE
côté carte (clé `streamed-atlas-physical-vram-size` du binaire). Cette lecture renforce le choix prudent de compter
les pages.

| Partie | Octets comptés | Statut |
|---|---|---|
| pages (« Created virtual atlas pages LxHxN ») | bas : pages × octets/px bas d'un atlas « [none] » sous la DXT du journal (0,5 en low-quality) ; haut : (pages + 1/3 de la plus grande surface, pages ou atlas virtuel annoncé) × octets/px haut (1) | Dimensions **prouvées** ; résidence en mémoire vidéo et compression : **hypothèses** (compter les pages est le sens prudent d'un budget) |
| mipmaps (« Generated mipmaps for virtual atlas of size VLxVH ») | haut seulement : au plus 1/3 de la plus grande surface (la série 1/4 + 1/16 + … reste sous 1/3) | Ligne **prouvée** ; emplacement des niveaux : **hypothèse** |
| variante non compressée (RGBA 8888) | pages × 4, sans mipmaps : NON comptée | Confrontée à la mesure directe : exclue si atlas (bas) + variante > pic dédié + pic partagé |
| « Atlas memory size: X MB; Y MB (virtual) », « Size of sprites outside of atlas » | rapportés tels quels s'ils apparaissent | Lignes du binaire ; jamais écrites dans les 13 journaux archivés |

Nouvelle estimation sur les 13 journaux archivés : 12 inchangées (aucun atlas virtuel : 1,10 à 1,25 Go en haute
qualité, 0,40 à 0,45 Go en normale) ; plancher (`2026-10-22_D4m_5-plancher-mesure`) : **0,28 à 0,53 Go** (atlas 0,20 à
0,31 Go, comme E40 ; pages 0,08 à 0,22 Go), contre un pic dédié mesuré de 0,42 Go. La variante non compressée
(0,20 + 0,60 = 0,81 Go) dépasse le pic dédié + partagé (0,52 Go) : exclue par la mesure, si les pages sont allouées
en entier. L'estimation haute (0,53 Go) dépasse la mesure : elle surestime cette session.

`python -B tools/autotest/tests/mut_vram.py [--work DOSSIER]` vérifie la règle par mutation (hors jeu, environ 10 s,
7 s sur `main` le 22/10 ; `lua5.2` du PATH par défaut : lancer depuis Git Bash, ou passer `--lua <chemin complet de
lua5.2.exe>` sous PowerShell) :
il copie TOUS les modules `.py` de `tools/autotest` dans un dossier jetable, joue d'abord un **témoin nul** (copie
intacte) qui doit survivre, puis 18 mutants de `vram.py` (pages hors du total, mipmaps au quart, pages non
compressées, ancrages des lignes du moteur retirés, verdict D4-1 sur les atlas seuls, etc.) que `unit_vram.py` doit
tous faire échouer. Il distingue un mutant refusé par un contrôle d'un mutant qui fait planter les unitaires, et
échoue si un motif n'est plus trouvé. Attendu le 22/10 : « témoin nul survivant ; 18/18 mutants détectés (18 par un
contrôle, 0 par un plantage) », code 0 (rejoué sur `main` le 22/10 vers 20 h 15 : même résultat). Le premier banc de
mutations du constructeur (archivé dans `fo-logs\2026-10-22_R1\vram\`) ne copiait pas `gallery.py` : toutes ses copies
plantaient, et son « 14/14 » ne prouvait rien (13/14 en réalité, RD_LOG E55).

`python -B tools/autotest/tests/mut_atlas.py --logs "<racine>/fo-logs" --out <dossier jetable>` vérifie l'étape par
mutation. Les témoins doivent passer : 4 copies intactes, plus 3 copies porteuses d'une variation sans effet (la
variante tolérée de « [low-object] », et deux impressions de script qui contiennent les mots du moteur). Les mutants
doivent être refusés, par exemple :
- une haute qualité à 14 atlas, une normale à 13 ou à 15 ;
- 15 atlas avec un seul « [none] », ou un atlas « [decal] » doublé à la place de l'atlas des icônes ;
- un atlas de terrain réétiqueté « [low-object] », ou un atlas d'icônes sans `linear-minification` ;
- un plancher dont l'atlas « [none] » a la taille de la qualité normale, et l'inverse ;
- une qualité déclarée qui ne correspond pas au contenu ;
- un plancher sans atlas virtuel, ou dont l'atlas virtuel n'apparaît que dans une impression de script ;
- des réglages non étalonnés ;
- (lot A2) un atlas d'icônes sans `linear-mip-level` en HAUTE qualité, ou sans `mipmap`, ou absent.

Lot A2 (24/10, correction) : avec les icônes d'âge de la mitrailleuse, l'atlas [icon] peut perdre `linear-mip-level`
en qualité NORMALE (mémoire « all » et plancher), pas en haute. Cause mesurée (F125,
`fo-logs\2026-10-24_A2\correction\d4m-icones`) : le RANGEMENT de l'atlas, ni le contenu ni la taille (14 icônes
d'âge : absent ; 13 ou 15 : présent ; 14 icônes au contenu vanilla : absent ; atlas 8192 × 2288 dans les 4 cas) ;
effet visible en mode Alt aux zooms 0,45, 0,7 et 1,3 : aucun pixel différent (scénario `a2-icones`). `run_d4m.py` ne
le tolère qu'en qualité normale ET si le journal porte le marqueur du mod « [FO-GUN-ICONES] » (écrit par
`prototypes/levels/gun.lua`), et l'imprime (« TOLERE ») ; `mut_atlas.py` lit les journaux de la correction
(`fo-logs\2026-10-24_A2\correction\d4m\*-galerie`, trois niveaux sous `fo-logs`, hors de l'étape 5) et refuse le même
journal SANS marqueur : attendu `50 OK, 0 ECHEC(S)` (48 au lot A2 avant correction, 40 avant A2).

Le script vérifie aussi son garde-fou sur un faux `fo-logs` temporaire, puis contrôle qu'aucune de ses copies n'est
lue par l'étape 5. Attendu : `40 OK, 0 ECHEC(S)`. L'étape 5 ne lit que `<logs>/*/visual.log`, un seul niveau sous
`fo-logs`. Le dossier jetable est donc refusé dans deux cas :
- s'il EST `fo-logs`, même écrit avec une autre casse ou avec un `..` : ses copies `<out>/<cas>/visual.log`
  seraient lues par l'étape 5 ;
- s'il se trouve DANS une archive que l'étape 5 lit (`fo-logs/X/…` avec `X/visual.log`) : on y mêlerait des mutants
  à une preuve.

Un sous-dossier de `fo-logs` qui n'est pas une archive est permis, par exemple
`fo-logs/2026-10-22_V3T-suites/d4m/mutants` : ses copies sont au moins deux niveaux plus bas.

### 5.2 Scénario greffé `d4-geant`

`fo-autotest/scenarios/d4-geant.lua` : usine de **288 × 188 tuiles** de béton en (64, −96), 2 fois la suite des
familles à niveaux lues dans `shared/levels/config.lua` (noms par `LV.name`, nombre de niveaux par `f.max`, taille par
le prototype chargé : le banc reste valable quand les sprites V3 arrivent), tournée pour que le mur ferme chaque cycle
(le centre de l'usine, entre deux cycles, montre les 7 familles même au zoom 0,5). Un bloc par famille, en
**sandwich** sans rangée vide : 4 rangées de machines jointives, 2 tapis en boucle fermée chargés d'objets (normal,
rapide, express), chaque tapis servant les deux rangées qui le bordent, bras d'une case (normal, rapide, empileur)
entre tapis et machines ; murs : 2 rangées pleines. Tout travaille : assembleurs (paquets rouges, un bras d'entrée et
un de sortie), fours (acier, charbon), foreuses (minerai sous chacune, dépôt DIRECT sur le tapis), tourelles chargées
et ravitaillées, alimentation invisible (6 zones de 128 × 128).

Essai à blanc (moteur simulé, 21/10) : **6 672 bâtiments à niveaux dans l'usine** (centre 568, mitrailleuse 1 144,
laser 1 144, mur 1 152, foreuse 760, four 1 144, assembleur 760 ; tous les niveaux de chaque famille), 7 072 tapis,
6 088 bras, 23 584 objets sur les tapis, 6 840 minerais, 26 684 entités, aucun chevauchement. **Champ réel** (ce que
la caméra dessine : rectangle de demi-côtés résolution / (64 × zoom) autour du centre (208, −2), entités dont la boîte
le touche) :

| Champ | Tuiles | Bâtiments à niveaux | dont machines | murs | Tapis | Bras | Familles |
|---|---|---|---|---|---|---|---|
| zoom 0,3, 1920 × 1080 (vues mesurées en `hd`, capture `-hd`) | 200 × 112 | **2 588** | 2 188 | 400 | 2 800 | 2 598 | 7/7, tous les niveaux |
| zoom 0,3, 1600 × 900 (captures) | 167 × 94 | **2 027** | 1 691 | 336 | 2 016 | 1 776 | 7/7 |
| zoom 0,5, 1920 × 1080 | 120 × 68 | **1 239** | 999 | 240 | 1 200 | 1 000 | 7/7 |
| zoom 0,5, 1600 × 900 (captures) | 100 × 56 | **974** | 774 | 200 | 800 | 600 | 6/7 |

Version précédente (commit c5b1015), pour mémoire : 4 240 bâtiments **dans l'usine**, dont 2 304 murs ; **dans le
champ** ≈ 1 224 (z0,3, 1600 × 900, dont 560 machines), ≈ 1 575 (z0,3 hd, 775 machines), ≈ 628 à 841 (z0,5, 228 à 361
machines) ; et un bras sur quatre (bras long, qui prend et dépose à deux cases) ne touchait pas le tapis : en
entrée il ne prenait rien, en sortie il aurait déposé au sol. Annoncer « 4 240 bâtiments » aurait surestimé d'un
facteur 3 à 7 la charge réellement dessinée. Aujourd'hui : 2,8 à 3,4 fois plus de
machines dans chaque champ. Limite physique : au zoom 0,5 (100 × 56 tuiles en 1600 × 900), des milliers de bâtiments de
2 × 2 à 4 × 4 avec leurs tapis sont impossibles ; « des milliers dans le champ » ne vaut qu'au zoom 0,3.

Session avec images : la caméra du joueur (spectateur) tient des vues fixes, chacune chronométrée par un LuaProfiler
(UPS) : `repere-debut` (zone vide, 180 ticks ; contient les contrôles du tick 120), `z030-jour` (zoom 0,3, midi, 600),
`repere-1` (60), `z050-jour`, `repere-2`, `z030-nuit` (minuit), `repere-3`, `z050-nuit`, puis `repere-fin` jusqu'à la
fin. Les repères (zone vide de 160 × 100 tuiles, presque aucun sprite) découpent `perf-stats.csv` en phases et donnent
l'UPS de la simulation seule. Chaque vue écrit son champ réel AVANT le chronomètre, avec la résolution réelle de la
fenêtre (`LuaPlayer.display_resolution` : en fenêtre réduite, quelques pixels, et `vram.py` le signale). Captures
APRÈS les mesures (ticks 2 790 à 2 860) : `usine-z030-jour`, `-z050-jour`, `-z030-nuit`, `-z050-nuit`,
`usine-z030-hd-jour` (1920 × 1080), `usine-detail-z1-jour`, `-z1-nuit`, `-z2-jour` (premier bloc d'assembleurs), chacune
avec sa ligne `CHAMP capture`. Marqueur de fin vers le tick 2 931.

Contrôles (`[FO-D4-GEANT]`, BILAN attendu **16 OK** dans `fo-autotest\benchmark.log` et dans le journal de la session ;
les 8 premiers aussi dans `create.log`) :
- à la création : prototypes de tous les niveaux présents ; tous les niveaux posés ; au moins 5 000 bâtiments à
  niveaux dans l'usine ; 5 000 tapis et 4 000 bras ; objets sur les tapis ; aucune pose refusée ; alimentation ;
  l'usine dépasse le champ z0,3 hd ;
- au tick 120 : **champ réel z0,3 en 1920 × 1080 : au moins 2 000 bâtiments à niveaux dont 1 500 machines** (seuil
  explicite ; à blanc : 2 588 et 2 188) ; toutes les familles et tous leurs niveaux dans ce champ ; **bras reliés**
  (prise et dépôt du moteur, `pickup_position` et `drop_position`, entre un tapis et un bâtiment à niveaux : tous) ;
  **foreuses** (dépôt sur un tapis : toutes) ; assembleurs, fours et foreuses au travail (80 %) ; aucun ennemi.

### 5.3 Procédure pour l'orchestrateur (moteur réel)

Préalables : aucun autre banc (verrou), **aucune partie du Directeur Créatif en cours** pour les passages en fenêtre
`hd` (fenêtre affichée, cœurs P pris) ; vérifier par
`Get-CimInstance Win32_Process -Filter "Name='factorio.exe'" | Select ProcessId, CommandLine` (lecture seule).
`<source>` = chemin du worktree D4m, ou `""` après intégration. Les passages sont **groupés par qualité** : chaque
changement de qualité ou de compression peut refaire le cache des atlas (36 à 196 s mesurés), et le passage qui le
refait ne compte pas pour D4-3. Depuis Git Bash, à la racine du jeu :

```
cd "<racine>"
python "<source>/tools/autotest/vram.py" --sonde                     # compteurs GPU lisibles (sans rien lancer)
# 1. Haute qualité, galerie (fenêtre réduite, aucune gêne)
FO_VISUAL_ARGS="--quality high" ./fo-captures.bat d4-geant "<source>"
#    -> archiver fo-visual\write\script-output\fo-shots\ et fo-autotest\*.log dans fo-logs\<date>_D4m_1-haute-galerie\
# 2. Haute qualité, mesure (fenêtre 1920x1080 sans focus, cœurs P, fin naturelle au tick 3 200)
FO_VISUAL_ARGS="--quality high --measure --ticks 3200 --pcores" ./fo-captures.bat d4-geant "<source>" hd
#    -> fo-logs\<date>_D4m_2-haute-mesure\
# 3. Qualité normale, galerie (refait sans doute le cache : chargement à part)
FO_VISUAL_ARGS="--quality normal" ./fo-captures.bat d4-geant "<source>"
#    -> fo-logs\<date>_D4m_3-normale-galerie\
# 4. Qualité normale, mesure
FO_VISUAL_ARGS="--quality normal --measure --ticks 3200 --pcores" ./fo-captures.bat d4-geant "<source>" hd
#    -> fo-logs\<date>_D4m_4-normale-mesure\
# 5. PLANCHER (bas de la plage, Q21) : qualité normale, mémoire vidéo « low », compression « low-quality », mesure
FO_VISUAL_ARGS="--quality normal --video-memory low --texture-compression low-quality --measure --ticks 3200 --pcores" ./fo-captures.bat d4-geant "<source>" hd
#    -> fo-logs\<date>_D4m_5-plancher-mesure\
# 6. (facultatif) intermédiaire : qualité normale, mémoire vidéo « medium », mesure
FO_VISUAL_ARGS="--quality normal --video-memory medium --measure --ticks 3200 --pcores" ./fo-captures.bat d4-geant "<source>" hd
python "<source>/tools/autotest/vram.py" "<racine>/fo-logs/<date>_D4m_2-haute-mesure"   # relire une archive
```

Depuis PowerShell : `$env:FO_VISUAL_ARGS = "--quality normal"; & "<racine>\fo-captures.bat" d4-geant "<source>";
$env:FO_VISUAL_ARGS = $null`. Durée de chaque passage : non mesurée à ce jour (création de l'usine, 26 684 entités ;
puis 2 760 ticks de vues chronométrées, 46 s à 60 UPS, les captures, et pour `--measure` l'attente du tick 3 200).

À relever pour chaque passage (code de sortie attendu : 0 ; 9 = réglage non appliqué, mesure à jeter) :

| Quoi | Où | Passages qui comptent |
|---|---|---|
| BILAN `[FO-D4-GEANT]` 16 OK | `fo-autotest\benchmark.log`, journal de session | tous |
| qualité, usage de la mémoire vidéo, DXT réellement appliqués | `session.txt` (« reglages appliques ») | tous |
| cache des atlas lu ou REFAIT ; « sprites charges a », « jeu initialise a » (D4-3) | `session.txt`, `memoire.txt` | comparer 2 et 4 (même état du cache) ; un passage qui refait le cache se compare à un autre qui le refait |
| mémoire vidéo DÉDIÉE du jeu : pic, moyenne, par phase (D4-1, D4-5) ; mémoire vive privée (Q21 : 16 Go) | `session.txt`, `memoire.txt` | **2, 4, 5 (et 6) seulement** ; en fenêtre réduite (1, 3), borne BASSE (tampons de rendu et de lumières à la taille de la fenêtre) |
| atlas : nombre, pixels, estimation (à confronter au pic mesuré) | `memoire.txt` | tous |
| champ réel de chaque vue (« champ reel de la vue … ») | `session.txt` | 2, 4, 5 : la vue doit compter ≈ 2 588 bâtiments à z0,3 ; en fenêtre réduite, presque rien |
| UPS par vue et par repère (simulation seule) | `session.txt`, `memoire.txt` | 2, 4, 5 |
| VSync et fréquence de l'écran (« VSync ACTIF, ecran 144 Hz ») | `session.txt` | 2, 4, 5 : avec VSync, plafond à la fréquence de l'écran |
| images/s par vue, par voie (phase, max(cpu,gpu), cpu-frame HYPOTHÈSE, compteurs) ; somme cpu-frame / durée ; contrôle du zoom (tuiles z030/z050 ≈ 2,78) | `session.txt`, `memoire.txt` | 2, 4, 5 |
| captures : lisibilité de loin, gigantisme, nuit ; haute, normale et plancher côte à côte (D4-2, verdict du Directeur Créatif) | `planche-01.png` et les 8 PNG | 1, 3, 5 |

**Non prouvé à ce jour (à confirmer au premier passage, puis à consigner dans RD_LOG) :**
1. `--output-perf-stats` écrit-il un fichier en fin naturelle de `--benchmark-graphics`, une ligne par image, en
   quelle unité ? `vram.py` le lit de façon tolérante (en-tête cherché, unité DEVINÉE par la médiane de `cpu-frame`) ;
   si le format diffère, adapter `parse_perf_csv`. Sans fichier : images/s NON mesurées, seules restent les UPS.
2. Sens des colonnes : `cpu-frame` = durée totale de l'image est une **hypothèse** (la voie « cpu-frame » surestime
   si elle exclut l'attente du GPU ; test : somme des `cpu-frame` / durée de la vue ≈ 1) ; `gpu-frame`, `sleep`,
   `cpu-flip`, `present-count` et `refresh-count` (cumulés ?) aussi. Seul l'accord des voies vaut mesure.
3. Les lignes « Performed N updates in X ms » et « avg: … min: … max: » sont voisines, dans le binaire, de « Running
   update %u », « checksum: %u » et « run %u: » : chemin `--benchmark` SANS images. Les écrit-il aussi en fin naturelle
   de `--benchmark-graphics` ? Aucun journal archivé ne le montre. Le résumé « prepare/render/frame> avg »
   (PerformanceLogger, sans doute) : écriture non prouvée non plus.
4. En fenêtre réduite, le jeu dessine-t-il ? Le binaire a une clé `halt-rendering-when-minimized` (valeur par défaut
   inconnue). Les images/s ne valent qu'en fenêtre `hd` ; la mémoire vidéo mesurée en fenêtre réduite n'est qu'une
   borne basse.
5. L'instance `pid_<PID>_…` du compteur « GPU Process Memory » apparaît-elle pour le jeu (`--sonde` l'a vue pour
   d'autres programmes le 21/10 : 30 instances) ?
6. `LuaPlayer.zoom = 0,3` est-il appliqué tel quel (contrôle des tuiles z030/z050) ?
7. Le budget `--ticks 3200` suffit-il pour atteindre le marqueur (tick 2 931) avant la fin naturelle (sinon code 7) ?
8. Clés du `config.ini` de test : `graphics-quality=high` (le défaut de ce PC, preset « very-high », est déjà la haute
   qualité) et `texture-compression-level` : nom lu dans le binaire, VALEURS (`none`, `high-quality`,
   `low-quality`) supposées d'après le journal « [DXT: high-quality] » et la locale. Une valeur refusée donne le code 9
   (journal) ou une erreur du jeu au démarrage (code 7).
9. Greffon en moteur : BILAN 16 OK, champ réel (boîtes du moteur ; l'essai à blanc les approche à ±0,3 tuile) et
   géométrie des bras et des foreuses (prouvée à blanc avec les vecteurs de base seulement ; les prototypes à niveaux
   peuvent différer). **Contrôles « au travail » : non testés** (le moteur simulé déclare tout au travail et `insert`
   réussit toujours).
10. Coût de la simulation : 26 684 entités, dont 6 088 bras et 760 assembleurs. Si l'UPS des repères tombe sous 60, les
    images/s mesurent la simulation autant que le rendu (que le jeu borne les images/s par l'UPS n'est pas prouvé ici).
11. Règles d'octets « alpha-mask » et « low-quality » : hypothèses (tableau ci-dessus) ; la mesure directe tranche.
