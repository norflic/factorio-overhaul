# CLAUDE.md : Factorio Overhaul (« Factorio V2 »), l'essentiel

Mod de **conversion totale** pour **Factorio 1.1.91**. Réduit à l'essentiel le 27/10 au soir, avec l'accord du DC (QCM,
19 h 15) : ce fichier est relu par CHAQUE agent. **Tout le reste** (résultats attendus de chaque banc, scénarios, pièges
moteur F21 à F295, historique des chiffres) est dans **`docs/MEMO_COMPLET.md`** : le lire seulement pour la partie qui sert.

## 1. Rôles, ton, méthode
- L'utilisateur (Evan) est le **Directeur Créatif** (DC). Il décide du contenu, du design et des priorités. Vous êtes
  **Architecte Principal & Lead R&D**. Vous répondez **en français**.
- **Jamais complaisant** : un défaut, même le vôtre, se dit et s'écrit dans OBJECTIFS.md.
- Standard de preuve : « Si tu ne peux pas m'assurer que tout fonctionne, c'est que le travail n'est donc pas terminé. »
  Rien n'est terminé sans preuve en **moteur réel**, et sans captures pour ce qui se voit. Seul le DC valide un design.
- **Méthode depuis le 27/10 au soir** (OBJECTIFS §5, 19 h 05) :
  - un seul fil de travail, au plus 1 agent à la fois ; pas de workflow, pas de boucle de surveillance ;
  - la seule preuve d'un progrès des IA est **la partie du DC aux réglages livrés, filmée** (scénario `etape1-guide`) ;
  - un défaut à la fois, puis une partie filmée ; arrêt et compte rendu au DC après 2 essais sans progrès visible ;
  - aucun réglage nouveau « éteint par défaut » : on change le comportement par défaut ;
  - rapports au DC : 3 lignes et des images (il suit depuis son téléphone) ; documents : une ligne par étape.

## 2. À lire avant de travailler
`REPRISE.md` (où en est le projet), puis `OBJECTIFS.md` (attentes, réponses du DC). Au besoin : `ARCHITECTURE.md`,
`BALANCE_SHEET.md`, `RD_LOG.md` (faits F, expériences E ; prochains libres : **F372, E249**).

## 3. Chemins
- Racine du jeu : `F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\` (disque exFAT : pas de liens durs, copier). **Ne plus
  rien écrire sur H:** (copie figée).
- Source du mod : `<racine>\mods\factorio-overhaul\` (dépôt git, branche `main` ; worktrees dans `.claude\worktrees\`).
- Données du jeu : `<racine>\data\` ; API 1.1.91 : `<racine>\doc-html\`.
- Archives des bancs : `<racine>\fo-logs\<date>_<lot>\`. Captures : `<racine>\fo-visual\write\script-output\fo-shots\`.
- Blender 5.2.2 : `C:\Users\evan2\tools\blender-5.2.2\blender.exe` ; Lua 5.2 : `lua5.2` (Git Bash) ou
  `C:\Users\evan2\bin\lua5.2.exe` (PowerShell).

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
4. **Bancs toujours par la FILE** : `py -3.9 -B tools/autotest/banc.py --out <archive> [--graine N] [--creation <source>]
   [--son] [--captures] [--visuel="<args>"] [--seul] --qui <lot> -- <ticks> <scenario> <source>`. Jusqu'à 3 places
   (`<racine>\fo-banc-places.txt`, **remettre 1 quand le DC joue**) ; les images ne tournent qu'à la place 1 ; toute mesure
   de performance se lance avec `--seul`. Ne jamais appeler `fo-autotest.bat` en boucle soi-même. Détails :
   `docs/MEMO_COMPLET.md` §4.
5. Aucune donnée personnelle, aucun identifiant, rien à publier.
6. **Blender uniquement par le verrou de rendu** : `python tools/render/with_render_lock.py -- <commande>`.
   Au plus 2 rendus à la fois sur le PC, en priorité inférieure à la normale. Refus (code 4) sous 1 Go libre.
7. **Jamais de son sur la vraie sortie du PC** (lot S0, F152) : une session de test avec son passe UNIQUEMENT par
   `FO_AUDIO=1` (pilote SDL `disk` pour le seul jeu de test, garde de crête qui tue la session, code 10). Les
   volumes à 0 du `config.ini` de test NE suffisent PAS : des sessions de test ont été audibles chez le DC le 23/10.

## 5. Commandes utiles
- **Worktree neuf : copier ou régénérer les feuilles hors de git** (D-6), sinon le jeu refuse le mod :
  `py -3.9 tools/render/pieces/levels/gun_e/feuilles.py` (376 PNG), puis `four_e`, `assembleur_e`, `foreuse_e`
  (`.../<kit>/feuilles.py`, sans argument). Copier depuis un checkout qui les a est plus rapide.
- **La partie du DC filmée** (preuve des IA) : `py -3.9 -B tools/autotest/banc.py --out <archive> --qui <lot> --captures
  --visuel="--ticks 216200 --timeout 7200" -- 216200 etape1-guide <source>` (journal `[FO-ETAPE1-GUIDE]`, photos
  `etape1-<faction>-<10|20|40|60>min-<base|qg>.png`). Sur 2 graines (`--graine 271828182`, `--graine 1618033988`) avant de conclure.
- Garde-fous avant une fusion : `lua5.2 tests/run.lua`, `lua5.2 tests/pvp_test.lua` (1305 OK, 3 à 6 min), le harness
  `lua5.2 tests/datastage/harness.lua "<racine>/data" .` (code 0), et le banc `content` (331 OK). Les attendus de tous les
  autres bancs : `docs/MEMO_COMPLET.md` §5.
- Écrire dans un document un texte qui contient une barre oblique inverse : outil Edit ou Write, jamais heredoc ni
  `py -c` (la barre doublée est réduite et corrompt le texte).

## 6. Règles de code (ARCHITECTURE §2)
- Cycle settings → data → control. `control.lua` ne contient que des `require`. Abonnements statiques (bus `Events`).
- `on_load` ne modifie jamais `global` ; `global` n'est nommé que dans `script/core/storage.lua`.
- Déterminisme : jamais d'ordre de `pairs` (listes triées), RNG maison, pas de trigonométrie dans la simulation, aucune
  décision pilotée par un temps mesuré, jamais de fonction dans `global`. `require` interdit pendant un événement (F24).
- `shared/` : Lua PUR (testable hors jeu) ; `prototypes/` génère ; `script/` exécute. Pas de chemin « en dur » dans le
  cerveau des IA (`tests/iag_test.lua` §8) : il lit les prototypes et les recettes.
- Traductions FR et EN obligatoires ; un paramètre de `localised_name` de prototype est une chaîne (F43).
- Un seul intégrateur touche `data.lua`, `control.lua`, `settings.lua`, `info.json`, `shared/levels/config.lua` et les
  documents. `.gitattributes` (`* -text`) garde les octets ; fins de ligne LF dans le code.
