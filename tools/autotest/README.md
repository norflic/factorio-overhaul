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
| `vram.py` | (lot D4m) Mémoire vidéo d'une session avec images : atlas estimés, mesure directe, chargement, images/s (§5) |
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
| 9 | (lot D4m) qualité des sprites ou usage de la mémoire vidéo demandés NON appliqués (ligne « Graphics options » du journal) : mesure non valable |

`fo-autotest.bat` rend 0 dès que le banc a tourné : lire ensuite le BILAN
(`grep "\[FO-CONTENT\] BILAN" fo-autotest\benchmark.log`).

**Verrou.** `<racine>\fo-autotest.lock` (un dossier) : les trois commandes le prennent, une seule session
moteur à la fois. `fo-captures.bat` le tient pour toute la chaîne (variable `FO_LOCK_HELD` transmise aux deux
autres). Verrou orphelin (aucun `factorio.exe` dont la ligne de commande contient `fo-autotest` ou `fo-visual`) :
`rmdir "<racine>\fo-autotest.lock"`.

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
`--measure`, `--size LxH`, et la fenêtre `hd` (§5).

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
banc `content` compte **182 OK = 180 du socle + 2 greffés**.

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
mémoire vidéo et images par seconde mesurées dans les deux qualités, 60 images/s visées).

### 5.1 Outils

**`vram.py`** (ne lance rien, lit des fichiers) :

```
python tools/autotest/vram.py <journal ou dossier> [--samples vram.tsv] [--perf perf-stats.csv]
                              [--stdout stdout.txt] [--seuil-go 6] [--json sortie.json]
python tools/autotest/vram.py --sonde        (les compteurs GPU de Windows sont-ils lisibles ?)
```

Le dossier peut être `fo-shots`, une archive `fo-logs\...` ou `fo-visual` : le journal (`factorio.log`,
`visual.log` ou `factorio-current.log`), `vram.tsv`, `perf-stats.csv` et `stdout.txt` y sont cherchés. Rapport :
réglages appliqués (qualité, usage de la mémoire vidéo, compression DXT, budget Windows), un atlas par ligne avec
sa catégorie et une FOURCHETTE d'octets, totaux par catégorie, verdict D4-1 sur l'estimation haute, chargement,
mesure directe, UPS et images/s. Règle d'octets par pixel (justification en tête du script) :

| Atlas | Octets par pixel (bas–haut) | Raison |
|---|---|---|
| drapeau `not-compressed` (icônes) | 4–4 | RGBA 8 bits, exclu de la compression |
| compression « high-quality » (défaut) | 1–1 | BC3 ou YCoCg-DXT5 (formats que le jeu teste au chargement), 16 octets par bloc 4×4 |
| compression « low-quality » | 0,5–1 | BC1 supposé, non vérifié |
| compression « none » | 4–4 | RGBA 8 bits |
| drapeau `alpha-mask` (ombres, masques) | 0,5–1 compressé ; 1–4 sans | un canal utile ; format exact absent du journal |
| mipmaps (« Generated mipmaps (N) ») | × (1 + 1/4 + …) | N niveaux en tout (bas) ou en plus de la base (haut) |

Essai sur les journaux existants (21/10) : 4 sessions de `fo-logs` (vitrine, guerre, galerie sans cache, essai 1)
donnent toutes 15 atlas, 1,070 milliard de pixels, **1,10 à 1,25 Go estimés** (haute qualité, DXT
« high-quality »), 4,28 Go sans compression (F66). Le « CurrentUsage » des lignes `[Local Video Memory]` est lu au
démarrage du moteur graphique, AVANT tout chargement (2 Mio) : ce n'est pas l'occupation du jeu. Une estimation
ne prouve rien : la mesure directe ci-dessous tranche.

**Pilote `visual_session.py`** (options par `FO_VISUAL_ARGS`, aucun `.bat` modifié) :

| Option | Effet |
|---|---|
| `--quality high\|normal` (alias `--graphics-quality`, nom de l'option du lot V0b ; `low` et `very-low` acceptés, migrés vers normal par le jeu) | Clé `graphics-quality` du `config.ini` DE TEST (`fo-visual\config.ini`, section `[graphics]`) ; toute valeur sauf `high` est aussi passée au binaire (`--graphics-quality`, qui n'accepte que normal, low, very-low). Vérifiée dans le journal : écart = code 9 |
| `--video-memory all\|high\|medium\|low` | Clé `video-memory-usage` et option `--video-memory-usage` du binaire ; vérifiée de même |
| `--measure` | Le jeu écrit ses statistiques de rendu (`--output-perf-stats fo-visual\perf-stats.csv`, recopié dans `fo-shots`) et le pilote attend la FIN NATURELLE du mode benchmark (budget `--ticks`) au lieu de fermer la session au marqueur |
| fenêtre `hd` (3e argument de `fo-captures.bat`) | 1920 × 1080, affichée SANS prendre le focus ; `--size LxH` change la taille |

Toujours actif (même sans `--measure`) : relevé toutes les 0,5 s de la mémoire vidéo **du seul PID de la session de
test** (compteurs Windows `\GPU Process Memory(pid_<PID>_*)\Dedicated Usage` et `Shared Usage`, lus par PDH sous
leurs noms ANGLAIS, donc indépendants de la langue de Windows ; lecture seule), de l'occupation de toute la carte
(`\GPU Adapter Memory(*)\Dedicated Usage`, tous programmes confondus) et de la mémoire vive du processus
(`GetProcessMemoryInfo`). Sorties dans `fo-shots` : `vram.tsv`, `memoire.txt` (rapport `vram.py`), `factorio.log`,
`stdout.txt`, et les lignes « memoire video DEDIEE du jeu : pic …, moyenne … » de `session.txt`. Le pilote note aussi
le nombre de `factorio.exe` hors test au lancement : s'il n'est pas nul, images/s et occupation de la carte sont
faussées (une autre partie partage la carte et le processeur).

Clés et options vérifiées dans le binaire 1.1.91 (lecture des chaînes, sans lancer le jeu) : `graphics-quality`
(« accepted values: normal, low, very-low » ; dans la configuration, « 'low' and 'very-low' options are deprecated
and will be migrated to 'normal' »), `video-memory-usage` (« all, high, medium, low »), `output-perf-stats`
(« path of file to which rendering performance statistics measurements should be saved »), colonnes du fichier
(`prepare`, `cpu-render`, `cpu-flip`, `sleep`, `cpu-frame`, `sprite-count`, `draw-call-count`, `tiles-rendered`,
`gpu-frame`, `frames-skipped`…) et résumé (`prepare> avg: … med: … min: … max:`, idem `render`, `flip`, `frame`) ;
`--benchmark-graphics` imprime aussi « Performed N updates in X ms » et « avg/min/max » en fin NATURELLE.
L'option `--graphics-quality normal` est prouvée en moteur par le lot V0b (journal « [Graphics quality: normal] »).

### 5.2 Scénario greffé `d4-geant`

`fo-autotest/scenarios/d4-geant.lua` : usine de **288 × 180 tuiles** de béton en (64, −96), 4 fois la suite des
familles à niveaux lues dans `shared/levels/config.lua` (noms par `LV.name`, nombre de niveaux par `f.max`, taille
par le prototype chargé : le banc reste valable quand les sprites V3 arrivent), une bande par famille : tapis en
boucle fermée chargés d'objets (normal, rapide, express), bras (4 sortes) de part et d'autre, bâtiments de la
famille à tous les niveaux. Essai à blanc (moteur simulé, 21/10) : **4 240 bâtiments à niveaux** (centre 228,
mitrailleuse 380, laser 380, mur 2 304, foreuse 284, four 380, assembleur 284 ; tous les niveaux de chaque
famille), 14 016 tapis, 2 544 bras, 46 752 objets sur les tapis, 2 556 minerais, aucun chevauchement. Tout travaille :
assembleurs (paquets rouges), fours (acier, charbon), foreuses (minerai sous chacune, sortie sur le tapis), tourelles
chargées, alimentation invisible (6 zones de 128 × 128).

Session avec images : la caméra du joueur (spectateur) tient des vues fixes, chacune chronométrée par un LuaProfiler
(UPS) : `repere-debut` (zone vide, 180 ticks), `z030-jour` (zoom 0,3, midi, 600), `repere-1` (60), `z050-jour`,
`repere-2`, `z030-nuit` (minuit), `repere-3`, `z050-nuit`, puis `repere-fin` jusqu'à la fin. Les vues « repère »
(zone vide de 160 × 100 tuiles, presque aucun sprite) découpent `perf-stats.csv` en phases. Captures APRÈS les
mesures (tick 2 790 environ) : `usine-z030-jour`, `-z050-jour`, `-z030-nuit`, `-z050-nuit`, `usine-z030-hd-jour`
(1920 × 1080), `usine-detail-z1-jour`, `-z1-nuit`, `-z2-jour`. Marqueur de fin vers le tick 2 911.

Contrôles (`[FO-D4-GEANT]`, BILAN attendu **12 OK** dans `fo-autotest\create.log` + `benchmark.log`) : prototypes de
tous les niveaux présents, tous les niveaux posés, au moins 3 000 bâtiments, 10 000 tapis et 2 000 bras, objets sur
les tapis, aucune pose refusée, alimentation, champ rempli ; au tick 120 : assembleurs et fours au travail (80 %),
foreuses (25 %), aucun ennemi dans l'usine.

### 5.3 Procédure pour l'orchestrateur (moteur réel)

Préalables : aucun autre banc (verrou), **aucune partie du Directeur Créatif en cours** pour les étapes 3 et 4
(fenêtre affichée, cœurs P pris) ; vérifier par
`Get-CimInstance Win32_Process -Filter "Name='factorio.exe'" | Select ProcessId, CommandLine` (lecture seule).
`<source>` = chemin du worktree D4m, ou `""` après intégration. Depuis Git Bash, à la racine du jeu :

```
cd "<racine>"
python "<source>/tools/autotest/vram.py" --sonde                     # compteurs GPU lisibles (sans rien lancer)
# 1. Haute qualité, galerie (fenêtre réduite, aucune gêne)
FO_VISUAL_ARGS="--quality high" ./fo-captures.bat d4-geant "<source>"
#    -> archiver fo-visual\write\script-output\fo-shots\ et fo-autotest\*.log dans fo-logs\<date>_D4m_haute-galerie\
# 2. Qualité normale, galerie (le premier passage refait le cache des atlas : chargement plus long, noter les deux)
FO_VISUAL_ARGS="--quality normal" ./fo-captures.bat d4-geant "<source>"
#    -> fo-logs\<date>_D4m_normale-galerie\
# 3. Haute qualité, mesure des images/s (fenêtre 1920x1080 sans focus, cœurs P, fin naturelle au tick 3 200)
FO_VISUAL_ARGS="--quality high --measure --ticks 3200 --pcores" ./fo-captures.bat d4-geant "<source>" hd
#    -> fo-logs\<date>_D4m_haute-mesure\
# 4. Qualité normale, mesure
FO_VISUAL_ARGS="--quality normal --measure --ticks 3200 --pcores" ./fo-captures.bat d4-geant "<source>" hd
#    -> fo-logs\<date>_D4m_normale-mesure\
python "<source>/tools/autotest/vram.py" "<racine>/fo-logs/<date>_D4m_haute-mesure"   # relire une archive
```

Depuis PowerShell : `$env:FO_VISUAL_ARGS = "--quality normal"; & "<racine>\fo-captures.bat" d4-geant "<source>";
Remove-Item Env:FO_VISUAL_ARGS`. Durée de chaque passage : non mesurée à ce jour (création de la carte plus longue
que `content` : usine et alentours ; puis 2 790 ticks de vues mesurées, 46 s à 60 UPS, et les captures).

À relever pour chaque passage (code de sortie attendu : 0 ; 9 = qualité non appliquée, mesure à jeter) :

| Quoi | Où |
|---|---|
| BILAN `[FO-D4-GEANT]` 12 OK | `fo-autotest\create.log`, `benchmark.log` |
| qualité, usage de la mémoire vidéo, DXT réellement appliqués | `session.txt` (« reglages appliques ») |
| mémoire vidéo DÉDIÉE du jeu : pic et moyenne (D4-1, D4-5) ; occupation de toute la carte ; mémoire vive privée | `session.txt`, détail par phase dans `memoire.txt` |
| atlas : nombre, pixels, estimation (à comparer au pic mesuré) | `memoire.txt` |
| chargement : « sprites charges a », « jeu initialise a », cache lu ou refait (D4-3) | `session.txt` |
| UPS par vue (`phase d4-geant z030-jour : … UPS`) | `session.txt` |
| images/s par vue, p95 de `cpu-frame`, `gpu-frame`, contrôle du zoom (tuiles z030/z050 ≈ 2,78) | `memoire.txt` (passages 3 et 4) |
| captures : lisibilité de loin, gigantisme, nuit ; haute contre normale côte à côte (D4-2, verdict du Directeur Créatif) | `planche-01.png` et les 8 PNG |

**Non prouvé à ce jour (à confirmer au premier passage, puis à consigner dans RD_LOG) :**
1. `--output-perf-stats` écrit-il bien un fichier en fin naturelle de `--benchmark-graphics`, avec quelles colonnes et
   quelle unité ? `vram.py` lit le CSV de façon tolérante (en-tête cherché, unité devinée par la médiane de
   `cpu-frame`) ; si le format diffère, l'adapter (`parse_perf_csv`). Si aucun fichier : images/s NON mesurées,
   seules restent les UPS par vue et le résumé « Performed … / avg » de `stdout.txt`.
2. En fenêtre réduite, le jeu dessine-t-il ? (sinon les images/s ne valent qu'en fenêtre `hd`.)
3. L'instance `pid_<PID>_…` du compteur « GPU Process Memory » apparaît-elle pour le jeu (`--sonde` l'a vue pour
   d'autres programmes le 21/10 : 30 instances) ?
4. `LuaPlayer.zoom = 0,3` est-il appliqué tel quel (contrôle des tuiles z030/z050) ?
5. Le budget `--ticks 3200` suffit-il pour atteindre le marqueur avant la fin naturelle (sinon code 7 : augmenter) ?
6. Clé `graphics-quality=high` du `config.ini` de test : le journal la confirme (sinon code 9) ; le défaut de ce PC
   (preset « very-high ») est déjà la haute qualité.
7. Le BILAN 12 OK, les seuils « au travail » et la pose (4 240 bâtiments) ne sont prouvés qu'à blanc (moteur simulé).
