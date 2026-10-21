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
   Options : `--disable-audio --disable-migration-window`.
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
écran. Prix : en fenêtre réduite, Windows place le jeu sur les cœurs E (étalon `[FO-CALIB]` 8 à 13 ms au lieu de
2,3 ms) : 75 à 95 s pour la galerie `content` au lieu de 40 s en `small`. Options du pilote, par la variable
`FO_VISUAL_ARGS` : `--pcores` (épingle sur les cœurs P : plus rapide, mais prend ces cœurs à une partie en
cours), `--priority below` (déconseillé : chargement des sprites 160 s), `--mode load` (ancien mode
`--load-game`, fermé par le pilote seulement), `--ticks N`.

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
| `session.txt` | Résumé de la session (commande, durées, gêne, processus, code) |
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
