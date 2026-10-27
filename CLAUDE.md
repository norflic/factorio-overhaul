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
4. `RD_LOG.md` : faits F1 à F162 (F102 lu dans le binaire, pas en moteur réel ; F103 à F110 : lot
   V3-T3, intégré ; F111 à F118 : lot V3-T4, livré NON intégré ; F119 : V3-E ; F120 à F122 : lot A1 ; F130 à F135 : lot
   M0 ; F136 : Blender 5.2.2, vérification du lot K0 ; F123 à F129 : lot A2 ; F137 à F139 : INT-GRAINE ; F140 à F145 : A3-préparation ; F146 à F148 : A3-jeu ; F149, F157 à F160 : A4-préparation ; F150 à F154 : lot S0 ; F155, F156 : S0-suite ; F161, F162 : D4m-géant ; F171 à F174 : PNJ-VÉRIF ; F186, F187 : A3-final ; F190 à F194 : MOD-0 ; F199 à F203 : MOD-1 ; F204 à F206 : A4-SOCLE ; F207 à F209 : IA2-0 ; F213 à F218 : IA2-a et IA2-a2 ; F210, F211 : X1 ; F219 à F221 : MOD-2 ; F222 à F224 : IA2-b ; F228 à F230 : F1-B ; F237, F238 : VERIF-NUIT ; F234 à F236 : IA2-c ; F242 à F244 : IA1-e1 ; F239 à F241 : IA1-b ; F225 à F227, F248, F249 : MOD-V et MOD-3 ; F263 à F265 : IA1-i ; F269 à F275 : IA3 ; F254 à F256 : F2-A ; F276 à F278 : F2-B ; F251 à F253 : IA1-b2 ; F163 à F165 : F1-A ; F167 à F170, F188, F189 : M1 ; F175 à F179 : IA1-0 ; F180 à F182 : IA1-a ; F183 à F185 : IA1-c ; F195 à F198 : B0 ; F306 à F308 : F3-B ; F292 à F295 : IA1-d ; F296 à F298 : IA-V2 ; F300 à F305 : IA3-k ; F331 à F333 : IA-G ; F337 à F340 : X3 ; F260 à F262, F309 à F311 : F4-A à F4-A3 ; F312, F313 : F5-A),
   expériences E1 à E84, E105 à E123 et E128 à E132 (E3 jamais attribué ; E56 à E59 : V3-T3 ; E60 à E62 : V3-T4 ; E63 à E65 : V3-E,
   passes 3 à 5 ; E66, E67, E70 : A1 ; E68 : A2 ; E69 : S0 ; E71, E72 : K0 ; E73 à E76 : M0 ; E105 à E108 : A3-préparation ; E109 à E111 : A3-jeu ; E112, E114 à E116 : A4-préparation ; E113 : S0-suite ; E117 : D4m-géant ; E118 à E120 : PNJ-VÉRIF ; E128 à E130 : A3-final ; E133 à E135 : MOD-0 ; E138 à E140 : MOD-1 ; E141, E142 : A4-SOCLE ; E143, E144 : IA2-0 ; E147 à E150 : IA2-a et IA2-a2 ; E145, E146 : X1 ; E151, E152 : MOD-2 ; E153, E154 : IA2-b ; E157, E158 : F1-B ; E163 : VERIF-NUIT ; E161, E162 : IA2-c ; E166, E167 : IA1-e1 ; E164, E165 : IA1-b ; E155, E156, E170, E171 : MOD-V et MOD-3 ; E174, E175 : IA1-i ; E178 à E181 : IA3 ; E85 à E87 : F2-A ; E184, E185 : F2-B ; E172, E173 : IA1-b2 ; E77 à E80, E131, E132 : M1 ; E81 à E84 : F1-A ; E121 à E123 : IA1-0 ; E124, E125 : IA1-a ; E126, E127 : IA1-c ; E136, E137 : B0 ; E204, E205 : F3-B ; E195 à E197 : IA1-d ; E198, E199 : IA-V2 ; E200 à E203 : IA3-k ; E220 à E223 : IA-G ; E224 à E226 : X3 ; E93 à E96, E206, E207 : F4-A à F4-A3 ; E208, E209 : F5-A), hypothèses ouvertes (H-V2, H-X1, H-L1 (mesurée en partie au lot V3-T2), H-B1, H-E1, H-T4-1 ;
   H-T1 et H-V1 validées ; H-T3 : (1) prouvée en moteur réel, (2) prémisse réfutée par F77, filet prouvé seulement en
   expérience de contrôle). Prochains identifiants (24/10, 23 h 15) : **F216** et **E149** hors blocs (réservés : MOD-V F225 à F227, E155, E156 ; A5-ESSAI F231 à F233, E159, E160 ; X2 F245 à F247, E168, E169 ; MOD-3 F248 à F250, E170, E171 ; IA1-b2 F251 à F253, E172, E173 ; F2-A, F3-A, F4-A F254 à F262, E85 à E96 ; F2-B F276 à F278, E184, E185 ; IA3-a F279 à F281, E186, E187 ; IA1-d F292 à F295, E195 à E197 ; F3-B F306 à F308, E204, E205 ; IA3-d F315 à F318, E210, E211 ; IA3-e F319 à F323, E212 à E214 ; F4-A4 et F4-B F324 à F327, E215 à E217 ; F5-A2 F328 à F330, E218, E219 ; **prochains libres (27/10, 8 h 05) F341, E227**) (F163 à F185 et E118 à E127 sont réservés aux lots F1, M1, PNJ-VÉRIF et IA1) ; en
   expériences, rien hors des blocs réservés : E77 à E80 (M1, M2), E81 à E104 (lots F1 à F6, par blocs
   de 4). Les blocs réservés sont listés en tête de RD_LOG.

## 3. Chemins (PC Windows du Directeur Créatif)
| Quoi | Chemin |
|---|---|
| Racine du jeu (installation portable) | `F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\`  **Depuis le 27/10 (1 h), le projet vit sur F:** (disque Kingston exFAT, 211 Go libres) : le DC y a copié tout le dossier le 26/10 vers 21 h 15, H: étant plein (471 Mo libres). **Ne plus rien écrire sur H:** (copie figée au commit 88f3ca4, sources des feuilles toujours lisibles) ; sur exFAT, git exige `safe.directory` (posé en global pour le dépôt et ses worktrees) et les liens durs n'existent pas (copier les feuilles au lieu de les lier). |
| Source du mod (ce dossier) | `<racine>\mods\factorio-overhaul\` |
| Exécutable | `<racine>\bin\x64\factorio.exe` |
| Données du jeu (banc de l'étape data) | `<racine>\data\` (Lua lisible de `core` et `base`) |
| Documentation API 1.1.91 | `<racine>\doc-html\` (`runtime-api.json`, `prototype-api.json`) |
| Bancs en moteur réel | `<racine>\fo-autotest.bat`, `fo-visual.bat`, `fo-captures.bat`, `fo-autotest-watch.bat` (sources dans `tools\autotest\` : recopier les `.bat` à la racine après modification ; mode d'emploi complet : `tools\autotest\README.md`) |
| Résultats du banc | `<racine>\fo-autotest\` : `create.log`, `benchmark.log`, `benchmark-stdout.txt`, `done.txt` |
| Captures | `<racine>\fo-visual\write\script-output\fo-shots\` : `NNN-<scène>.png`, `index.txt`, `planche-NN.png`, `session.txt` |
| Rendu 3D (lot V0) | Blender 5.2.2 LTS : `C:\Users\evan2\tools\blender-5.2.2\blender.exe` ; pipeline : `tools\render\README.md`, `tools\render\CALIBRATION.md` |
| Feuilles de la mitrailleuse en jeu (lot A2, décision D-6) | `<mod>\graphics\levels\gun\` : 376 PNG (164 Mo depuis 0.4.18) HORS de git, régénérés par `feuilles.py` ; `MANIFEST.json`, `sprites.lua`, `sprites.json` commités ; sources dans `<racine>\fo-logs\`, à GARDER : `2026-10-23_V3E-p5\bas\sprites`, `2026-10-23_V3E-p5\haut\sprites`, `2026-10-23_V3E-ereV\sprites`, `2026-10-24_A2\sprites`, `2026-10-24_A3\sprites` (têtes à 64 directions), `2026-10-24_A4\socle-anime\sprites` (socle animé des âges 5 à 15) |
| Feuilles du four en jeu (lot F2-B, D-6) | `<mod>\graphics\levels\four\` : 208 PNG (4,3 Mo) HORS de git, régénérés par `tools/render/pieces/levels/four_e/feuilles.py` (sans argument) ; `MANIFEST.json`, `sprites.lua`, `sprites.json` commités ; source à GARDER : `<racine>\fo-logs\2026-10-25_F2\production\sprites` (29 variantes à 128 échantillons) |
| Feuilles de l'assembleur en jeu (lot F3-B, D-6) | `<mod>\graphics\levels\assembleur\` : 234 PNG (6,1 Mo) HORS de git, régénérés par `tools/render/pieces/levels/assembleur_e/feuilles.py` (sans argument) ; `MANIFEST.json`, `sprites.lua`, `sprites.json` commités ; source à GARDER : `<racine>\fo-logs\2026-10-25_F3\production\sprites` (29 variantes à 128 échantillons) |

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
4. **Bancs en parallèle par PLACES, toujours par la FILE** (lot BANC2, 27/10 vers 9 h ; le DC : « au pire ça ram mais c'est
   pas grave », « Je n'utilise pas mon pc pour les 8 prochaines heures donc vous pouvez y aller (sans faire planter le pc) »).
   Le banc a jusqu'à 3 places : `fo-autotest\` + `fo-autotest.lock`, `fo-autotest-2\` + `fo-autotest-2.lock`,
   `fo-autotest-3\` + `fo-autotest-3.lock` (variable `FO_PLACE` de `fo-autotest.bat`, posée par banc.py seulement ; à la main :
   code 3). Le nombre de places ouvertes est dans `<racine>\fo-banc-places.txt` (absent : 2 ; illisible ou hors de 1 à 3 : 1) ;
   **remettre 1 quand le DC joue**. Une place au-delà de la première exige 6 Go de mémoire libre. Les images
   (`fo-captures.bat`, `fo-visual.bat`, son) ne tournent qu'à la place 1 (verrou `fo-autotest.lock`, partagé avec
   `fo-visual`). Chaque `fo-autotest.bat` **efface le dossier de SA place** : banc.py archive avant de rendre le verrou.
   Tout agent lance ses bancs par la FILE : `py -3.9 -B tools/autotest/banc.py --out <archive> [--graine N] [--creation <source>]
   [--son] [--captures] [--visuel="<args>"] [--seul] --qui <lot> -- <ticks> <scenario> <source>` (TOUR DE RÔLE entre les lots
   `--qui`, premier arrivé, premier servi dans un lot ; même `--qui` pour tous les bancs d'un lot ; `--file` montre les places
   et la file). **Toute mesure de performance (K10, `analyze.py`, `[FO-CALIB]`, temps par tick) se lance avec `--seul`** :
   seule sur le PC, toutes places prises ; une mesure prise sans `--seul` est fausse (les bancs voisins partagent les cœurs P,
   F30). Ne jamais appeler `fo-autotest.bat` en boucle soi-même. Un verrou orphelin (aucun `factorio.exe` avec
   `\fo-autotest\`, `\fo-autotest-N\` ou `fo-visual`) est retiré par banc.py. Prouvé en moteur réel le 27/10 à 9 h 03 :
   `content` 331 OK à la place 2 pendant une session d'images à la place 1.
5. Aucune donnée personnelle, aucun identifiant, rien à publier.
6. **Blender uniquement par le verrou de rendu** : `python tools/render/with_render_lock.py -- <commande>`.
   Au plus 2 rendus à la fois sur le PC, en priorité inférieure à la normale pour ne pas gêner une partie
   en cours. Le verrou est `<racine>\fo-render.lock.<k>` ; un verrou orphelin est repris tout seul.
   Il refuse de lancer (code 4) s'il reste moins de 1 Go libre sur le disque de sortie (`--min-libre-go` ; lot A3).
7. **Jamais de son sur la vraie sortie du PC** (lot S0, F152) : une session de test avec son passe UNIQUEMENT par
   `FO_AUDIO=1` (pilote SDL `disk` pour le seul jeu de test, garde de crête qui tue la session, code 10). Les
   volumes à 0 du `config.ini` de test NE suffisent PAS : des sessions de test ont été audibles chez le DC le 23/10.

## 5. Commandes
Toutes les commandes se lancent depuis la racine du mod, sauf mention.

**Worktree ou checkout neuf : régénérer d'abord les feuilles de la mitrailleuse** (PNG hors de git, décision D-6) :
`py -3.9 tools/render/pieces/levels/gun_e/feuilles.py` + les arguments écrits dans `graphics/levels/gun/MANIFEST.json`
(champ `arguments` ; depuis 0.4.13 (24/10), **vide** : tous les âges à 64 directions ; 4 à 7 min ; attendu « [FO-FEUILLES]
376 fichiers PNG, 164.05 Mo, 936 sources ; têtes : 14 âge(s) à 64 directions, 0 à 4 » ; 164 Mo écrits sur F:), puis `py -3.9 tools/render/pieces/levels/gun_e/check_gun_sheets.py --sources` (6 OK) et
`git status` propre. Sans cela, le harness et `levels_test` échouent (ils impriment cette commande) et l'étape data
du jeu refuse le mod. **Même chose pour le four** (depuis 0.4.30, lot F2-B) : `py -3.9 tools/render/pieces/levels/four_e/feuilles.py`
→ « [FO-FEUILLES-FOUR] 208 fichiers PNG, 4.32 Mo » (sources : `fo-logs\2026-10-25_F2\production\sprites`). **Et pour
l'assembleur** (depuis 0.4.31, lot F3-B) : `py -3.9 tools/render/pieces/levels/assembleur_e/feuilles.py` → « [FO-FEUILLES-ASM]
234 fichiers PNG, 6.09 Mo » (sources : `fo-logs\2026-10-25_F3\production\sprites`). Sur F: (exFAT), copier, jamais de liens durs.

**Production des têtes de la mitrailleuse à 64 directions** (lot A3 ; `<racine>\fo-logs\2026-10-24_A3\INTEGRATION.md`) :
**TERMINÉE** le 24/10 à 11:59:25 (840 / 840, 0 erreur ; 8 têtes HORS REGLE regardées et acceptées) : ne plus la lancer.
Pour mémoire :
`PYTHONUTF8=1 py -3.9 tools/render/pieces/levels/gun_e/produire_a3.py --dry-run` (ce qui reste), puis la même commande
sans `--dry-run`, avec `--places 1` (F145), EN ARRIÈRE-PLAN (8 à 10,5 h pour 768 têtes). Reprenable ; arrêt propre par
le fichier `<racine>\fo-logs\2026-10-24_A3\STOP` ; **jamais deux lancements à la fois** ; codes : 0 fini, 1 erreur
(relancer), 2 STOP, 3 trous hors règle (regarder), 4 disque. Journal : `production.log` du même dossier.

**Bancs hors jeu** (Lua 5.2.4, compilé le 21/10 depuis la source officielle de lua.org, sommes
vérifiées, avec le gcc de `C:\mingw64` : `C:\Users\evan2\bin\lua5.2.exe`. Ce dossier est dans le PATH
de Git Bash, donc `lua5.2` y fonctionne tel quel ; sous PowerShell, donner le chemin complet).
Résultats attendus aujourd'hui :
```
lua5.2 tests/run.lua             -> 114 OK
lua5.2 tests/war_test.lua        -> 105 OK   (13 contrôles des soldats égarés depuis 0.4.12, lot PNJ-VÉRIF)
lua5.2 tests/td_test.lua         -> 270 OK
lua5.2 tests/pteam_test.lua      -> 37 OK   (reconstruction de votre équipe décimée depuis 0.4.24)
lua5.2 tests/migration_test.lua  -> 82 OK
lua5.2 tests/monde_test.lua      -> 201 OK   (garantie des monnaies des âges 5, 7 et 8, lot M0 : candidats, décision, sites, échec et reprise par paliers)
lua5.2 tests/levels_test.lua     -> 1666 OK   (+ 11 « écarts connus » au contrat, comptés à part ; dont le contrôle des feuilles de la mitrailleuse, lot A2, celui des feuilles du four depuis 0.4.30, lot F2-B, et celui de l'assembleur depuis 0.4.31, lot F3-B ; rejoue aussi le harness, environ 5 s ; --tables : BALANCE_SHEET §12 ; --calibrate : courbe recalculée sur le calendrier X0 depuis un état de référence fixe ; FO_VERBOSE_CLEAR=1 : détail des cas de « libérer la place »)
lua5.2 tests/pvp_test.lua        -> 1305 OK   (de 3 à 6 min selon la charge : 198 s, 217 s, 266 s et 373 s le 23/10 pendant des bancs moteur et d'autres agents ; 195 s le 22/10 entre 22 h 50 et 22 h 55, 194 s à 20 h 11, 180 s à 19 h 05, 301 s plus tôt le même jour ; "pure" en argument : 502 OK, partie pure seule)
lua5.2 tests/epochs_test.lua     -> 16665 OK (graphe de fabrication du lot X0)
lua5.2 tests/x3_test.lua         -> [X3] BILAN : 6002 OK   (proposition X3 jointe à X0 : voies jamais une porte, cerveau avec technologies, 28 mutants ; environ 48 s ; --court 5963 ; rien en jeu)
lua5.2 tests/org_test.lua        -> 366 OK   (modèle des rôles des équipes de PNJ, lot IA1)
lua5.2 tests/recipe_lots_test.lua -> BILAN : 67 OK   (recettes par lots, 10 mutants refusés, lot MOD-2)
lua5.2 tests/titanium_test.lua   -> 114 OK   (chaîne du titane de l'âge 11, lot X1)
lua5.2 tests/traits_test.lua     -> 65 OK   (caractère des factions tiré de la graine, lot IA2-0)
lua5.2 tests/chef_test.lua       -> 62 OK   (chef de faction adaptatif, lots IA2-a et IA2-a2 ; environ 2 min)
lua5.2 tests/valeur_test.lua     -> 53 OK   (valeur des sites d'expansion des factions, lot IA2-b ; 51 avant 0.5.0 : renouvellement de la réserve contrôlé dans une partie à l'ancien cerveau, lot IA-V2)
lua5.2 tests/ia3b_test.lua       -> [IA3-B] BILAN : 31 OK   (marché, registre, manque de plaques ; lot IA3-b, fusionné par IA-V2 en 0.5.0)
lua5.2 tests/ia3f_test.lua       -> [IA3F] BILAN : 32 OK    (exploration sous brouillard, moteur simulé ; lot IA3-f, par IA-V2)
lua5.2 tests/ai3_carte_test.lua  -> [AI3-CARTE] BILAN : 55 OK (carte de connaissance, pure ; lot IA3-f)
lua5.2 tests/ai3_cerveau_test.lua -> [AI3-CERVEAU] BILAN : 49 OK (cerveau par besoins, pur ; lot IA3-c, par IA-V2)
lua5.2 tests/iag_test.lua         -> [IAG] BILAN : 87 OK   (cerveau général, lot IA-G, 0.6.0 : catalogue des prototypes, choix valeur ÷ coût, H8, ressources clés, généralisation sur 4 jeux de données changés, ANTI-ÉCHELLE sur shared/ai3 et script/ai3, exemptions reglages.lua et paliers.lua ; 9 mutants)
lua5.2 tests/ia3k_regles_test.lua  -> [IA3K-REGLES] BILAN : 106 OK   (carte du danger, itinéraire, réaction ; 9 mutants ; lot IA3-k, 0.5.1)
lua5.2 tests/ia3k_soldats_test.lua -> [IA3K-SOLDATS] BILAN : 30 OK  (rôles des soldats ; 6 mutants ; lot IA3-k)
lua5.2 tests/ia3k_moteur_test.lua  -> [IA3K-MOTEUR] BILAN : 41 OK   (moteur simulé : variation, ver sur la route, peur, porte, escalade, changement de site, réglage éteint, déterminisme ; environ 15 s)
lua5.2 tests/adversaire_test.lua -> 53 OK   (modèle de l'adversaire sous brouillard, lot IA2-c)
PYTHONUTF8=1 python -B tools/autotest/tests/test_ia2c_joueur.py   -> 15 OK (outil de mesure du lot IA2-c)
PYTHONUTF8=1 python -B tools/autotest/tests/test_ia2_mesures.py   -> 50 OK (outil de mesure des PNJ, lot IA2-0 ; sans PYTHONUTF8 il plante à l'affichage de ρ)
lua5.2 tests/module_mult_test.lua -> BILAN : 95 OK   (barème D-17, productivité multipliée, écart d'énergie au plafond, 26 mutants ; lots MOD-1 et MOD-3)
py -3.9 tools/render/pieces/modules/icones.py --check   -> 30 objet(s), 30 techno(s), 0 écart(s) (icônes des modules, validées par le DC, lots MOD-V et MOD-3)
lua5.2 tests/ia1_scale_test.lua  -> 115 OK   (échelle 30 des équipes de PNJ, lot IA1-a)
lua5.2 tests/ia1_production_test.lua -> [IA1-E1] BILAN : 104 OK   (solveur de débits et diagnostic, lot IA1-e1 ; 18 mutants ; environ 2 s ; livre `tests/fixtures/recipes_ia1e.lua` à régénérer par `harness.lua ... --dump-recipes` si les recettes changent)
lua5.2 tests/plan_test.lua       -> [IA1-D PLAN] BILAN : 82 OK   (plan directeur pur, lot IA1-d : treillis, lots, rues, placement, tapis, poteaux ; §10 : équivalence des accélérations, 2 mutants)
lua5.2 tests/ai3_graphe_test.lua -> [AI3-GRAPHE] BILAN : 36 OK ; ai3_groupe_test 28 OK ; ai3_expedition_test 19 OK ; ai3_recherche_test 17 OK (section IA3, règles pures non branchées)
lua5.2 tests/ia1i_test.lua       -> 89 OK   (fenêtre « Équipe et factions », lot IA1-i : bouton contre commande, fenêtre ouverte contre fermée)
lua5.2 tests/ia1b2_test.lua      -> 62 OK   (votre équipe défend d'abord, coffre défendu, travail des PNJ libres, lot IA1-b2)
lua5.2 tests/ia1b_test.lua       -> 50 OK   (pôles, travail de fond, danger, prudence, lot IA1-b)
lua5.2 tests/ia1_modules_test.lua -> BILAN : 1018 OK   (gabarits de modules des équipes organisées, lot IA1-c ; 25 mutants)
python -B tools/team/test_bp2lua.py   -> 12 OK (conversion de plans en gabarits, lot IA1-c)
lua5.2 tests/datastage/harness.lua "<racine>/data" .   -> 0 nouvelle erreur, Règles moteur : 0 violation(s) (les cas faux de l'auto-contrôle y sont comptés), 0 clé manquante ; points de jeu vanilla 18 entités / 51 points, mod 61 / 182 ; auto-contrôle 11/11 ; Images : 0 violation(s) (fichier manquant ou rectangle hors image), étalonnage vanilla 0 sur 2 505 prototypes, auto-contrôle 17/17 ; Feuilles mitrailleuse (graphics/levels/gun, D-6) : 376 fichier(s) au manifeste, 0 manquant(s), 0 écart(s) ; Sons : 0 violation(s) (flux Ogg Vorbis relu en entier depuis S0-suite), étalonnage vanilla 0 sur 1 287 fichiers, mod 20 fichier(s), auto-contrôle 24/24 ; Technologies des équipes (T.unlocks) : 22 nom(s), 0 absent(s), auto-contrôle 2/2 (depuis 0.4.12, lot PNJ-VÉRIF) ; Tetes mitrailleuse (A3-jeu) : 14 age(s) a 64 directions, 0 a 4, 0 erreur(s), auto-contrôle 4/4 (depuis 0.4.13) ; Feuilles four (graphics/levels/four, D-6) : 208 fichier(s) au manifeste, 0 manquant(s), 0 écart(s), 208 image(s) de sprites.lua relue(s) (depuis 0.4.30, lot F2-B) ; Feuilles assembleur (graphics/levels/assembleur, D-6) : 234 fichier(s) au manifeste, 0 manquant(s), 0 écart(s), 234 image(s) de sprites.lua relue(s) (depuis 0.4.31, lot F3-B) ; code de sortie 0 (--dump-proto type/nom, --dump-final type/nom, --verbose)
python tools/api_lint.py "<racine>/doc-html" "<chemin absolu du mod>"   -> 1212 usages, 0 erreur (1179 avant IA3-k, 0.5.1 ; 1123 avant IA-V2, 0.5.0 ; 1107 avant le lot IA1-d, 0.4.32 ; 1102 avant le scénario f3-assembleurs, 1098 avant f2-fours) (mod de test compris ; chaînes et commentaires ignorés depuis le 21/10)
python -B tools/autotest/tests/run_d4m.py --logs "<racine>/fo-logs"   -> 5/5 étapes (banc D4m hors jeu ; essai à blanc du greffon 15 OK et BILAN attendu 18 depuis D4m-géant ; unitaires de vram.py 99 OK ; 13 journaux archivés : atlas attendus selon les réglages déclarés par chaque journal ; À LANCER DEPUIS GIT BASH : sous PowerShell, lua5.2 n'est pas dans le PATH et le banc donne 2/5)
python -B tools/autotest/tests/mut_atlas.py --logs "<racine>/fo-logs" --out <dossier jetable, ni fo-logs ni une archive>   -> 50 OK (depuis le lot A2 : l'atlas [icon] sans linear-mip-level n'est toléré qu'en qualité normale avec la ligne « [FO-GUN-ICONES] » du mod, F125 ; témoins A2 : `<racine>\fo-logs\2026-10-24_A2\correction\d4m\*-galerie`, à GARDER ; 40 avant A2)
python -B tools/autotest/tests/mut_vram.py [--work <dossier jetable>]   -> témoin nul survivant ; 18/18 mutants détectés (18 par un contrôle, 0 par un plantage), code 0 (règle de l'atlas virtuel de vram.py, hors jeu, environ 10 s, 7 s sur main le 22/10 ; lot R1, RD_LOG E55 ; lua5.2 du PATH par défaut : depuis Git Bash, ou --lua <chemin complet de lua5.2.exe> sous PowerShell)
python -B tools/autotest/tests/test_ht3_journal.py   -> 15 OK (contrôle du journal des bancs de migration, --tag et messages aux joueurs compris, hors jeu)
PYTHONUTF8=1 py -3.9 -B tools/autotest/tests/test_banc_file.py   -> BILAN : 78 OK (tour de rôle de la file du banc et PLACES depuis BANC2 : 3 bancs en même temps, passage de 3 à 1 place, images à la place 1 pendant les places 2 et 3, barrière --seul, garde-fou de 6 Go, cohabitation avec l'ancien banc.py ; vrais lanceurs sur une racine jetable avec un faux fo-autotest.bat ; environ 75 s ; aucun jeu lancé ; 13 avant BANC2)
python -B tools/autotest/tests/bat_double_source/run.py   -> 70 OK (FO_PLACE depuis BANC2, cas 15 à 18 ; 47 avant ; code 8 de fo-captures.bat sur un banc en échec depuis D4m-géant ; FO_AUDIO et pilote disk depuis S0 ; graine FO_MAP_SEED comprise depuis INT-GRAINE ; fo-autotest.bat en double source, faux factorio.exe et robocopy.exe ; gcc de C:\mingw64 requis)
py -3.9 tools/render/pieces/levels/gun_e/check_gun_sheets.py --sources --mutants   -> 19 OK (feuilles de la mitrailleuse, éclats et socle animé compris depuis A4 : manifeste, sha256, rectangles, poses au pixel contre les sources, directions écartées de l'éclat regardées, mutants refusés ; lots A2 et A3-jeu)
py -3.9 -B tests/datastage/mut_sons.py --work <dossier jetable hors du dépôt>   -> BILAN : 6 OK (règle « sons » : Opus, FLAC dans Ogg, fichier coupé… refusés ; environ 3 min ; lot S0-suite)
python -B tools/autotest/tests/test_audio_session.py   -> 21 OK (pilote de session avec son : environnement disk, pilote lu au journal, mesure de la sortie disk ; lot S0)
py -3.9 tools/sound/sons.py --check   -> 20 fichier(s) conformes (sons de la mitrailleuse : manifeste, volume, timbre ; lot S0)
python -B tools/autotest/tests/test_audio_guard.py   -> 4 OK (garde de crête ; ATTENTION : joue 3 s d'un son de 30 Hz à −70 dBFS, inaudible, sur la VRAIE sortie du PC ; ne pas lancer sans raison)
py -3.9 tools/render/tests/test_garde_disque.py   -> 11 OK (garde de disque du verrou de rendu : refus sous 1 Go libre, code 4 ; lot A3)
py -3.9 tools/render/pieces/ressources/check_gisement.py --mutants   -> BILAN : 7 OK, 0 ECHEC(S) ; mutants 10/10 refusés (feuilles de gisement du kit minerai, lot M1)
py -3.9 tools/render/pieces/levels/laser_e/tests/test_laser.py   -> [F1-LASER] 182 OK (kit de la tourelle laser, lots F1-A et F1-B : 15 âges)
py -3.9 tools/render/pieces/levels/four_e/tests/test_four.py   -> [F2-FOUR] 179 OK ; avec --sprites "<racine>/fo-logs/2026-10-25_F2/production/sprites" : 193 OK (kit du four, lots F2-A et F2-B)
PYTHONUTF8=1 py -3.9 tools/render/pieces/levels/assembleur_e/tests/test_assembleur.py   -> [F3-ASM] 217 OK (kit de l'assembleur, lots F3-A et F3-B ; sans PYTHONUTF8, il plante à l'affichage de « ⊂ »)
PYTHONUTF8=1 py -3.9 -B tools/render/pieces/levels/foreuse_e/tests/test_foreuse.py   -> [F4-FOREUSE] 149 OK (kit de la foreuse, lots F4-A à F4-A3 ; rien en jeu ; lua5.2 du PATH : Git Bash)
PYTHONUTF8=1 py -3.9 -B tools/render/pieces/levels/centre_e/tests/test_centre.py   -> [F5-CENTRE] 81 OK (kit du centre de commandement, lot F5-A ; rien en jeu)
PYTHONUTF8=1 py -3.9 tools/render/tests/test_produire_a3.py   -> 43 OK (production des têtes à 64 directions : pannes de lecture, exceptions, code de sortie, reprise ; faux rendre.py, sans Blender, environ 50 s ; lit A3\sprites et A3\masques\m16, à GARDER ; lot A3)
```
`levels_test` et `migration_test` acceptent `FO_DATA_DIR=<racine>/data` pour une copie du mod hors de
l'arborescence du jeu.
Chiffres mesurés sur `main` **0.4.7** le 23/10 vers 23 h, après la fusion du lot S0 (`4593893`) : nouveaux, harness
(règle « sons »), bat_double_source 40, test_audio_session 21, `sons.py --check` 20 ; pvp en 387 s ; bancs en moteur
réel rejoués (`done.txt` de 22:57:15 à 22:59:00 ; archives `<racine>\fo-logs\2026-10-23_integration-0.4.7\`), tous
verts. Avant : chiffres mesurés sur `main` **0.4.6** le 23/10 vers 21 h, après la fusion du lot A2 (`e0088bd`) : nouveaux, levels
1662, api_lint 676 (scénarios `gun-rose` et `a2-icones`), mut_atlas 50, harness (règle « images », feuilles),
check_gun_sheets 12 ; pvp en 369 s. Bancs en moteur réel rejoués (`done.txt` de 20:53:22 à 20:54:56 ; archives
`<racine>\fo-logs\2026-10-23_integration-0.4.6\`) : tous verts, chiffres ci-dessous inchangés, plus `gun-rose`.
Avant : chiffres mesurés sur `main` le 23/10 vers 17 h 50, après les fusions des lots A1 (`5a95650`, outils seulement) et M0
(`da2e16f`, **version 0.4.5**) : nouveaux depuis 0.4.4, `monde_test` 157 (banc nouveau) et api_lint 669 (A1 : scénario
`a1-tourelle` ; M0 : garantie et ses scénarios) ; tous les autres inchangés. Bancs en moteur réel rejoués sur `main`
le même jour (`done.txt` de 17:45:17 à 17:46:17 ; archives `<racine>\fo-logs\2026-10-23_integration-0.4.5\`, un
dossier par banc) : tous verts, chiffres ci-dessous. Avant (22/10 de 22 h 50 environ à 22 h 55,
fin de la sortie : 22:55:17, après l'intégration du lot V3-T3, fusion `8a28804`, version 0.4.4 ; pvp en 195 s) :
api_lint 609. Avant V3-T3 (lot R1, 22/10, 20 h 11) : migration 81, levels 1577, api_lint 535 ; le correcteur
de V3-T3 annonçait 615 usages dans son worktree, `main` en compte 609 (écart non expliqué, noté tel quel). Avant R1 :
migration 79, levels 1575, api_lint 519, unitaires de vram.py 57. La branche du lot V3-T4 (NON intégrée) donne
d'autres chiffres (levels 1 615 + 23 écarts connus, api_lint 558) : ce ne sont pas ceux de `main`.

**Graine de la carte des bancs** (lot INT-GRAINE, 23/10) : `$env:FO_MAP_SEED = '123456789'` avant `fo-autotest.bat` ou `fo-captures.bat`, puis `$env:FO_MAP_SEED = $null` (jamais `''`, F139). Sans variable : graine 20261020, comme avant. Valeur filtrée (chiffres seulement, au plus 4294967295) ; graine refusée : code 1 (8 pour `fo-captures.bat`) avant le verrou. La graine utilisée est écrite dans `fo-autotest\seed.txt`. Prouvé en moteur réel le 23/10 (18:43) : `content` 317 OK et `monde` 89 OK sur la graine 123456789.

**Session de test AVEC le son** (lot S0, E69 ; seule voie autorisée, interdit n° 7) : `$env:FO_AUDIO = '1'` avant
`fo-captures.bat` (ou `fo-autotest.bat`), puis `$env:FO_AUDIO = $null`. Le jeu de test reçoit `SDL_AUDIODRIVER=disk`
(sortie écrite dans `audio-disk.raw` du dossier de test, aucun périphérique ouvert, F153) et un garde de crête tue la
session au moindre son vers le PC (code 10 : ne pas relancer sans comprendre). Seule la session AVEC images charge
les sons (F150, F151) : `& "<racine>\fo-captures.bat" gun-rose "<racine>\mods\factorio-overhaul"` → code 0 et,
dans `session.txt`, « Driver:disk », « Loading sounds » et « sessions audio Windows du processus de test : 0 »
(observé sur `main` 0.4.7 le 23/10 vers 23 h). Un son manquant donne le code 7 (« Missing sound »).
**Tir joué en jeu** (lot S0-suite, E113) : même session avec le scénario `s0-tir`, puis
`py -3.9 tools/sound/tirs_joues.py "<racine>\fo-visual\audio-disk.raw" "<racine>\fo-visual\write\script-output\fo-shots\factorio.log" --avant "<racine>\fo-logs\2026-10-24_S0-suite\moteur\02-s0tir-son-disk\gains.json"`
→ « BILAN : 36 tir(s) au journal ; reconnus 36, ere juste 36 … volumes (differentiel) justes : OK », code 0. Instable à
la marge : 1 échec sur 5 passages (35/36) ; rejouer une fois avant de conclure. Sans images : `fo-autotest.bat nopause
3000 s0-tir` → « [FO-S0-TIR] BILAN : 5 OK ».

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
   19:05:39,98 ; rejoué après le lot R1, 20:11:14,81, après le lot V3-T3, 22:50:45,71, et le 23/10 après les fusions
   d'A1 et M0, 17:45:17,75, et sur 0.4.6, 20:53:22,75) : 210 contrôles du banc, dont 63 de niveaux, + 2 de l'exemple greffé `checks/exemple.lua` + 26 du
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
$env:FO_CREATE_SRC = 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3T-suites\ht3\src-0.4.1'
& 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 700 ht3-migration 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'
$env:FO_CREATE_SRC = $null
python -B tools/autotest/ht3_journal.py 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest'
```
- `src-0.4.1` est identique à `git archive 91097e6` (version 0.4.1) ; `fo-autotest\create-source.txt` dit quelle
  source a créé la carte.
- Attendu : « [FO-HT3-MIGRATION] BILAN : 30 OK, 0 ECHEC(S) » dans `benchmark.log` (29 avant le lot V3-T2 : le
  centre 15 grandit désormais lui aussi), ET « JOURNAL H-T3 : 7 OK, 0 ECHEC(S) », code 0. Observé sur `main` le
  22/10 (`done.txt` 19:05:52,39 ; après le lot R1, 20:11:32,11 ; après le lot V3-T3, 22:51:10,76) ; le 23/10 après les
  fusions d'A1 et M0, 17:46:00,37.

Migration 0.4.2 → 0.4.3 quand toutes les familles grandissent (lot V3-T2, RD_LOG E50 ; usine dense de 24 machines) :
```
$env:FO_CREATE_SRC = 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3T2\src-0.4.2'
& 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 700 t2-migration 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'
$env:FO_CREATE_SRC = $null
python -B tools/autotest/ht3_journal.py --tag FO-T2-MIGRATION 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest'
```
- `src-0.4.2` est identique à `git archive c4d37e5` (version 0.4.2) : à GARDER, c'est la source de création de ce
  banc.
- Attendu : « [FO-T2-MIGRATION] BILAN : 64 OK, 0 ECHEC(S) » dans `benchmark.log`, ET « JOURNAL FO-T2-MIGRATION :
  26 OK, 0 ECHEC(S) », code 0 ; journal du mod : « mise à jour des emprises : 21 bâtiment(s) reposé(s), 3 déjà en
  place, 19 laissé(s) ». Observé sur `main` le 22/10 (`done.txt` 19:05:48,49 ; après le lot R1, 20:11:28,04 ; après le
  lot V3-T3, 22:51:06,58 ; le 23/10 après A1 et M0, 17:46:04,55). Depuis V3-T3, le journal du banc dit aussi « LIBERER LA PLACE (plan seul, hors bilan) :
  5 liberable(s) sur 19 laisse(s) » : ligne HORS bilan, qui ne change ni le BILAN ni le contrôle du journal.

Migration d'une DÉFENSE DENSE (lot R1, RD_LOG E54 ; 21 tourelles derrière un mur continu, bras électriques, convoyeur
de munitions, poteaux), création 0.4.1 :
```
$env:FO_CREATE_SRC = 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3T-suites\ht3\src-0.4.1'
& 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 1200 t2-defense 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'
$env:FO_CREATE_SRC = $null
python -B tools/autotest/ht3_journal.py --tag FO-T2-DEFENSE 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest'
```
- Attendu depuis 0.4.1 : « [FO-T2-DEFENSE] BILAN : 36 OK, 0 ECHEC(S) » dans `benchmark.log`, ET « JOURNAL
  FO-T2-DEFENSE : 19 OK, 0 ECHEC(S) », code 0 ; journal du mod : « 8 bâtiment(s) reposé(s), 0 déjà en place,
  13 laissé(s) ». Observé sur `main` le 22/10 (`done.txt` 20:11:36,19 ; après le lot V3-T3, 22:51:15,21 ; ligne hors
  bilan « LIBERER LA PLACE (plan seul, hors bilan) : 2 liberable(s) sur 13 ») ; le 23/10 après A1 et M0, 17:46:08,87.
- Création 0.4.2 : même commande avec `$env:FO_CREATE_SRC = 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3T2\src-0.4.2'`.
  Attendu : 36 OK, ET « JOURNAL FO-T2-DEFENSE : 11 OK, 0 ECHEC(S) », code 0 ; journal du mod « 5, 0, 5 ». Observé sur
  `main` le 22/10 (`done.txt` 20:11:40,52 ; après le lot V3-T3, 22:51:19,45 ; hors bilan : 0 libérable sur 5) ; le
  23/10 après A1 et M0, 17:46:13,10.
- Le scénario n'existe qu'en double source : `src-0.4.1` (= `git archive 91097e6`) et `src-0.4.2` (= `git archive
  c4d37e5`) sont à GARDER.

« Libérer la place » pour un bâtiment laissé HORS GRILLE par une vraie migration (lot V3-T3, RD_LOG E59 ; un script
ne sait pas fabriquer un bâtiment hors grille, F104) :
```
$env:FO_CREATE_SRC = 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3T2\src-0.4.2'
& 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 1000 t3-migration 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'
$env:FO_CREATE_SRC = $null
```
- Attendu : « [FO-T3-MIGRATION] BILAN : 7 OK, 0 ECHEC(S) » dans `benchmark.log`, code 0. Observé sur `main` le 22/10
  (`done.txt` 22:51:53,59 ; le 23/10 après A1 et M0, 17:46:17,15). **Il faut 1 000 ticks** : un passage à 700 ticks
  (22:51:02,43) s'arrête avant le contrôle, sans BILAN (`fo-logs\2026-10-22_V3T3-integration\t3-migration\NOTE.txt`).

Migration d'une sauvegarde 0.4.4 vers la garantie des monnaies (lot M0, RD_LOG E76 ; sauvegarde avec un coffre du
joueur, gisements déjà connus comptés) :
```
$env:FO_CREATE_SRC = 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-23_suite\M0\src-0.4.4'
& 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 700 m0-migration 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'
$env:FO_CREATE_SRC = $null
```
- `src-0.4.4` est identique à `git archive 93e3d89` (version 0.4.4) : à GARDER.
- Attendu : « [FO-M0-MIGRATION] BILAN : 9 OK, 0 ECHEC(S) » dans `benchmark.log`, code 0 (pas de contrôle de journal).
  Observé sur `main` le 23/10 (`done.txt` 17:45:43,44) : cristal et méthane déjà là, tungstène posé en (94, −228).

Pour les cinq bancs en double source :
- Le banc s'arrête avec le code 1, sans `done.txt`, si la copie de création n'est pas remplacée en entier.
- Toujours vider la variable après usage : elle reste définie pour les bancs suivants de la même session
  PowerShell, `fo-captures.bat` compris. Avec `fo-captures.bat`, elle a été essayée deux fois (lot V3-T2,
  `fo-captures.bat t2-migration`, code 0) : la carte du banc est créée par la source de création et la session
  avec images rejoue la migration.
- Préférer `$env:FO_CREATE_SRC = $null` : sous Claude Code, `Remove-Item Env:FO_CREATE_SRC` peut être refusé
  par la protection de chemin de l'outil (REPRISE.md §6).

**Contact bord à bord des recherches par zone** (lot R1, RD_LOG E53, F96 ; sans double source) :
`& 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 60 bord-a-bord 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'`
→ « [FO-BORD-A-BORD] BILAN : 12 OK, 0 ECHEC(S) » (45 cas comparés à la règle du moteur simulé ; observé sur `main`
le 22/10, `done.txt` 20:11:23,82 ; après le lot V3-T3, 22:50:54,07 ; le 23/10 après A1 et M0, 17:45:56,31). Un ECHEC veut dire que le moteur simulé (`tests/mock_engine.lua`) ne suit plus le
moteur réel : l'aligner, puis rejouer tous les bancs hors jeu.

**Machines agrandies, pour les captures** (lot V3-T2, sans double source) :
`& 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 1500 t2-machines 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'`
→ « [FO-T2-MACHINES] BILAN : 80 OK, 0 ECHEC(S) » (observé sur `main` le 22/10, `done.txt` 19:05:44,44 ; après le lot
R1, 20:11:19,61 ; après le lot V3-T3, 22:50:50,22 ; le 23/10 après A1 et M0, 17:45:48,00). Pour les
images : `& "<racine>\fo-captures.bat" t2-machines "<source>"` depuis PowerShell.

**« Libérer la place »** (lot V3-T3, RD_LOG E59 ; sans double source ; zones A à V et L, vrais robots en zone R) :
`& 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 1900 t3-libere 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'`
→ « [FO-T3-LIBERE] BILAN : 41 OK, 0 ECHEC(S) » (observé sur `main` le 22/10, `done.txt` 22:50:58,19 ; le 23/10 après A1
et M0, 17:45:52,25). Le scénario
contrôle au tick 1 800 (`check_tick`, à cause des vrais robots) : il faut au moins 1 900 ticks. Images :
`& "<racine>\fo-captures.bat" t3-libere "<source>"` depuis PowerShell, 4 captures prises après le bilan
(`shots_delay` = 1 840).

**Garantie des monnaies des âges 5, 7 et 8** (lot M0, RD_LOG E73, E74 ; sans double source ; la graine de
`fo-autotest.bat` est fixe, 20261020 : le scénario joue 5 autres graines sur des surfaces qu'il crée) :
`& 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 700 monde 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'`
→ « [FO-MONDE] BILAN : 89 OK, 0 ECHEC(S) » (observé sur `main` le 23/10, `done.txt` 17:45:34,86). Images :
`& "<racine>\fo-captures.bat" monde "<source>"` depuis PowerShell (9 captures des 3 sites de nauvis ; 91 OK, car la
cartographie ne tourne qu'avec images, F131).
Échec puis reprise de la garantie (correction M-1 du lot M0, E74) :
`& 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 2600 m0-reprise 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'`
→ « [FO-M0-REPRISE] BILAN : 15 OK, 0 ECHEC(S) » (contrôle final au tick 2 460 : il faut 2 600 ticks ; observé sur
`main` le 23/10, `done.txt` 17:45:39,32).
**Depuis 0.4.5, toute carte de banc créée par `fo-autotest.bat` porte 3 sites garantis** sur nauvis (graine 20261020 :
(−34, −361), (33, 273), (−247, −286)), loin des zones des greffons ; tous les bancs ci-dessus sont verts avec. Les
bancs de durée et de performance `ia0-*` (216 000 ticks) NE sont PAS rejoués : leurs cartes changent (3 sites,
environ 50 chunks générés de plus) ; à rejouer avant de citer leurs chiffres comme référence.

**Usine géante et mémoire vidéo** (lot D4m, recalé au lot D4m-géant, RD_LOG E117) :
`& 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 600 d4-geant 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'`
→ « [FO-D4-GEANT] BILAN : 18 OK, 0 ECHEC(S) » (observé sur `main` le 24/10, `done.txt` 5:46:15,72 ; 10 OK, 6 ECHEC de 0.4.3
à 0.4.9, F128) : usine de 5 343 bâtiments, galerie de 960 mitrailleuses (64 images relues par âge). Mesure de la
mémoire vidéo : `tools/autotest/README.md` §5.3 (passages `--measure` avec `--ticks 3900`). Aux 15 âges à 64 directions (lot A3-final, 24/10, RD_LOG E130) : haute, 17 atlas,
1,273 Gpx, règle de vram.py 1,28 à 1,45 Go (compteur 1,81 Go dans les vues) ; normale, 0,396 Gpx, 0,46 à 0,51 Go (compteur
0,71 Go) ; plancher, compteur 0,42 Go, **atlas virtuel PLEIN : 12 pages sur 12** (F186) : toute addition graphique (socle
animé des 10 autres âges, par exemple) se mesure au plancher AVANT d'être intégrée. Temps de chargement mesurés pendant un
jeu du DC : à remesurer PC au repos.

**La mitrailleuse vivante** (lot A4-préparation, RD_LOG E112 à E116) : `fo-autotest.bat nopause 1000 a4-eclat <source>` →
« [FO-A4-ECLAT] BILAN : 3 OK » ; `nopause 1300 a4-ruines` → « 5 OK » (destruction réelle 2×2 à 6×6) ; `nopause 300
a4-socle` → « 2 OK » (socle animé de l'âge 6) ; observés sur `main` 0.4.10 le 24/10 (`done.txt` 7:25:48 à 7:25:57). Images :
`fo-captures.bat a4-eclat` puis `tools/autotest/a4_eclat_images.py` (`fo-logs\2026-10-24_A4\NOTES.md` §7).

**Levée et directions d'une tourelle** (lot A1, RD_LOG E67, E70) : SUR UNE COPIE JETABLE du mod seulement, qui ajoute
des prototypes de test (sur le mod livré, le scénario se refuse à l'init, « prototypes de test absents ») :
```
py -3.9 tools/autotest/a1/jetable.py --dest <dossier neuf, hors du dépôt>
& 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 1000 a1-tourelle '<dossier de la copie>'
```
→ « [FO-A1-TOURELLE] BILAN : 5 OK, 0 ECHEC(S) » (copie du lot, 23/10, `done.txt` 15:56:07,00 ; copie neuve du
vérificateur, 16:48:01,51). Images : `& "<racine>\fo-captures.bat" a1-tourelle "<copie>"` (20 captures, flèches
numérotées). Effacer la copie après usage (place sur le disque).

**La mitrailleuse en jeu** (lot A2, RD_LOG E68, F123 à F129 ; sans double source ; feuilles requises, voir « Worktree
ou checkout neuf » plus haut) :
`& 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-autotest.bat' nopause 1000 gun-rose 'F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul'`
→ « [FO-GUN-ROSE] BILAN : 13 OK, 0 ECHEC(S) » depuis A3-jeu (30 niveaux × 20 directions dont d06, d26, d38, d58, par `orientation`, tenue jusqu'au contrôle ; tir dans les 11 directions écartées de l'âge 2 ;
boîtes d'affichage, restes et explosions déclarés ; tir sur 60 sites, éclat à 1/32 de tuile de la règle F126 ; observé
sur `main` 0.4.6 le 23/10, `done.txt` 20:54:32,19). Images : `& "<racine>\fo-captures.bat" gun-rose "<source>"`
depuis PowerShell, 150 captures depuis A3-jeu (90 avant), puis `py -3.9 tools/autotest/gun_rose_images.py "<dossier des captures>" --feuilles "<source>\graphics\levels\gun"` → « BILAN : 280 OK, 0 FAUX, 0 ambigu(s) » aux 15 âges à 64 directions (lot A3-final, 24/10 ; 252 OK et 28 ambigus à 7 âges sur 0.4.9).
`a2-icones` (images seulement, qualité normale, mode Alt) : « [FO-A2-ICONES] BILAN : 2 OK », 4 captures (correcteur
d'A2 ; non rejoué sur `main`).

Scénarios :
- `default` : guerre à économie réelle et compagnons ;
- `content` : banc de contenu, 317 contrôles avec les greffons, inchangé en 0.4.5 et 0.4.6 (les contrôles greffés ne se chargent que pour
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
- `monde` (scénario greffé, lot M0, 700 ticks) : garantie des monnaies sur nauvis et 5 graines ; `m0-reprise` (lot M0,
  2 600 ticks) : échec puis reprise ; `m0-migration` (lot M0, 700 ticks) : migration d'une sauvegarde 0.4.4, en double
  source `src-0.4.4` seulement (ci-dessus) ;
- `s0-tir` (scénario greffé, lot S0-suite, 3 000 ticks) : tirs de 6 ères écoutés par le joueur téléporté (ci-dessus) ;
- `a1-tourelle` (scénario greffé, lot A1, 1 000 ticks) : levée et directions d'une tourelle, sur une copie jetable
  seulement (ci-dessus) ;
- `gun-rose` (scénario greffé, lots A2 et A3-jeu, 1 000 ticks) : la mitrailleuse en jeu, 20 directions par niveau et tir (ci-dessus) ;
  `a2-icones` (lot A2) : icônes en mode Alt, images seulement ;
- scénarios greffés du lot IA0 (PvP) : `ia0-normal` et `ia0-paisible` (216 000 ticks), `ia0-difficile`
  (144 000), `ia0-big` et `ia0-perf` (performance, banc épinglé). Les scénarios de guerre intégrés
  tournent en difficulté « Paisible », pour rester comparables aux mesures E17 à E22 ;
- `waves` : défense de tours et guerre ;
- `pteam` : équipe du joueur ;
- `stress` : 402 agents ;
- `mod2-lots` (lot MOD-2, 2 300 ticks) : recettes par lots, débits, bascule sans perte, fluides, 1 000 machines → « [FO-MOD2-LOTS]
  BILAN : 28 OK » (`main` 0.4.22, 25/10, `done.txt` 2:42:48) ; `mod2-migration` (600 ticks, DOUBLE SOURCE `FO_CREATE_SRC` =
  `<racine>\fo-logs\2026-10-25_MOD2\src-0.4.19`, à GARDER) → « 6 OK » ;
- `x1-titane` (lot X1, 3 800 ticks) : champ garanti, foreuse, chaîne de Kroll, niveau de l'âge 11 payé en titane →
  « [FO-X1-TITANE] BILAN : 27 OK » ; `x1-migration` (700 ticks, DOUBLE SOURCE `FO_CREATE_SRC` =
  `<racine>\fo-logs\2026-10-25_X1\src-0.4.16`, à GARDER) → « 8 OK » ; `m0-migration` → 11 OK (4 garanties) ; `content`
  → 331 OK et `monde` → 116 OK depuis 0.4.21 (`main`, 25/10, `done.txt` 2:39:56 à 2:40:45) ;
- `mod1-modules` (lots MOD-1 et MOD-3, 2 200 ticks) : modules qui se multiplient, mesurés contre la formule → « [FO-MOD1-MODULES]
  BILAN : 85 OK » depuis 0.4.27 (barème D-17) ; `mod3-migration` (200 ticks, DOUBLE SOURCE `FO_CREATE_SRC` =
  `<racine>\fo-logs\2026-10-25_MOD3\src-0.4.26\factorio-overhaul`, à GARDER) → « 14 OK » ; `mod1-migration` (200 ticks, DOUBLE SOURCE `FO_CREATE_SRC` =
  `<racine>\fo-logs\2026-10-24_MOD1\src-0.4.15`, à GARDER) → « 11 OK » ; images : `fo-captures.bat mod1-modules`
  (panneau « Modules (multipliés) ») ; `a4-socle` (300 ticks) : 12 tourelles, 11 socles animés et un témoin fixe → « 2 OK »,
  images : `fo-captures.bat a4-socle` puis `py -3.9 tools/autotest/a4_socle_images.py <fo-shots>` ;
- `b0-biomes` (lot B0, 400 ticks) : frontières des biomes et plaine de cristal → « [FO-B0-BIOMES] BILAN : 10 OK » (`main`
  0.4.16, 24/10, `done.txt` 21:19:56) ; images : `fo-captures.bat b0-biomes`, puis `py -3.9 tools/autotest/b0_bords.py`
  (part des bords sur la grille) ;
- `pnj-auto` (lot PNJ-JOUABLE, 2 600 ticks) : la guerre lancée par les réglages de carte `fo-war-*` (version 0.4.15),
  une fois par partie → « [FO-PNJ-AUTO] BILAN : 7 OK » (`main`, 24/10, `done.txt` 15:48:58) ;
- `ia1-scale` (lot IA1-a, 216 000 ticks, épinglé) : 4 factions et votre équipe à 30 PNJ → « [FO-IA1-SCALE] BILAN : 17 OK »
  (16 quand une faction est anéantie en cours de partie : son contrôle d'effectif est sauté ; `main` 0.4.17, 24/10,
  `done.txt` 21:58:29), puis `py -3.9 -B tools/autotest/ia1_scale.py <archive>` ; `ia1-sansfonds`, `ia1-sansfonds-stock`
  (mesure de l'armée sans financement, `tools/autotest/ia1_armee.py`) ; `ia1-migration` (double source, voir
  `fo-logs\2026-10-24_IA1\IA1-a\INTEGRATION.md` §0.6) ;
- `ia1-modules` (lot IA1-c, 128 000 ticks, environ 2 min) : 65 placements de gabarits, débits à ± 10 % après 25 min
  d'échauffement → « [FO-IA1-MODULES] BILAN : 136 OK » (`main`, 24/10, `done.txt` 19:12:43) ;
- `m1-minerai` (lot M1, 600 ticks) : gisements de 9 × 9 aux 8 stades, tungstène sur ses cendres → « [FO-M1-MINERAI] BILAN :
  7 OK » (observé sur `main` 0.4.14 le 24/10, `done.txt` 15:09:25) ; images : `fo-captures.bat m1-minerai`, 16 captures ;
- `ia1-risques` (lot IA1-0, 1 800 ticks) : risques moteur R1 à R5, R7 des équipes organisées → « [FO-IA1-RISQUES] BILAN :
  65 OK » (`main` 0.4.14, 15:09:36), puis `py -3.9 -B tools/autotest/ia1/risques.py <passes>` ; `ia1-carte` (images
  seulement) : R6 (`tools/autotest/README.md` §4.1) ;
- `ia1b2-guide` (lot IA1-b2, 216 000 ticks, la partie du guide avec la recherche « Tourelles » à 5 min ; FO_MAP_SEED) →
  « [FO-IA1B2-GUIDE] BILAN : 15 OK » sur 271828182 ; 13 OK sur 577215664 (défaut ouvert, 0.4.29) ; `verif-guide` se joue
  désormais sur 4 graines (271828182, 1618033988, 314159265, 577215664 : 14 OK sur 314159265, défaut ouvert) ;
  `ia1-poles` → 15 OK, 2 ECHEC depuis 0.4.29 (occupation 75 %, crise : défaut ouvert) ;
- `f2-fours` (lot F2-B, 400 ticks) : les 30 niveaux du four posés en 5 rangées, garnis, en marche → « [FO-F2-FOURS] BILAN :
  3 OK » (30 posés, 30 en marche au tick 300, plaques produites) ; images : `& "<racine>\fo-captures.bat" f2-fours "<source>"`,
  40 captures (5 ères au zoom 1, 15 âges au zoom 2, de jour et de nuit ; table `fo-shots\f2-fours-sites.tsv`) ; migration
  d'une sauvegarde 0.4.28 avec ses fours : même scénario en DOUBLE SOURCE `FO_CREATE_SRC` =
  `<racine>\fo-logs\2026-10-25_F2\src-0.4.28` (à GARDER ; feuilles de la mitrailleuse en liens durs) → 3 OK ;
- **depuis 0.6.0 (lot IA-G), le cerveau général** : `iag-partie` (162 000 ticks, 4 factions, Paisible, 45 min ; décisions [FO-CERVEAU],
  paliers A1), `iag-jetable` (même partie sur la copie de `py -3.9 tools/autotest/iag/jetable.py --src <source> --dest <neuf>` :
  données changées), `iag-photo` (captures du QG des factions) ; lecture `PYTHONUTF8=1 py -3.9 -B tools/autotest/iag_mesures.py <archives>` ;
- **depuis 0.5.1 (lot IA3-k), comportements visibles ALLUMÉS** (`fo-war-ia3-comportement`), 2 graines (20261020, 123456789) :
  `ia3k-route` (54 700) → « [FO-IA3K-ROUTE] BILAN : 8 OK » sur 20261020 (7 OK 1 ECHEC d'échantillon sur 123456789) ; `ia3k-memoire`
  (288 700) → 5 OK, économie : `py -3.9 -B tools/autotest/ia3k_economie.py <archive> 70` ; `ia3k-variete` (54 700) → 5 OK 1 ECHEC connu
  (allongement) ; `ia3k-peur` (30 100) → 7 OK ; `ia3k-soldats` (108 100) → 9 OK 1 ECHEC connu ; témoins `*-temoin` (réglage éteint) ;
  rejeu : `FO_BANC="<banc.py de main>" bash tools/autotest/ia3k_rejouer.sh "<source>" <archives> [rapide|complet|temoins]` ;
- **depuis 0.5.0 (lot IA-V2), le nouveau cerveau est ALLUMÉ par défaut** (réglages `fo-war-ia3-marche`, `fo-war-ia3-cerveau`) :
  `ia3b-fer` (54 100 ticks) → « [FO-IA3B-FER] BILAN : 8 OK » ; `ia3c-dc-apres` (72 100) → 9 OK ; `ia3c-dc-loin` → 4 OK ; `ia3-fer-joueur`
  (54 000) → 10 OK ; témoins tout éteint `ia3b-fer-avant`, `ia3c-dc-avant`, `ia3-fer-joueur-avant` (mesure) ; `ia3c-migration` (42 100)
  chemin A en DOUBLE SOURCE (`--creation <racine>/fo-logs/2026-10-27_IA-V2/src-0.4.30`, à GARDER) et chemin B → 12 OK chacun ;
  mesure `ia3c-reduit`, `ia3c-default` (432 000) puis `PYTHONUTF8=1 py -3.9 -B tools/autotest/iav2_mesures.py --avant <…> --apres <…>` ;
  K11 : `py -3.9 -B tools/autotest/iav2_empreinte.py <A> <B> --minutes 30` ; exploration `ia3-brouillard` (216 000) ;
- `ia1-build-plaine`, `-eau`, `-falaises`, `-foret`, `-reseau` (lot IA1-d, 132 000 ticks, 30 à 90 s) : plan directeur et
  construction par les PNJ (centrale, fonderies de fer et de cuivre avec foreuses et tapis), équipe renvoyée, puis 5 min
  SANS PNJ à 70 % de 112,5 plaques/min → « [FO-IA1-BUILD-<TERRAIN>] BILAN : 12 OK » chacun ; images : `banc.py --captures
  --visuel="--ticks 133000 --timeout 3600" -- 133000 ia1-build-plaine <source>` (35 min) ; `ia1d-fantomes` (120 ticks,
  diagnostic, 1 OK) ; `ia1d-couts` (200 ticks, coûts de ravivage, 1 OK). Le plan n'est allumé que par `Build.enable`
  (remote `fo-ia1d`) : aucun cerveau ne l'appelle avant IA3-e ;
- `f3-assembleurs` (lot F3-B, 400 ticks) : les 30 niveaux de l'assembleur en marche (engrenages, 2 modules de vitesse par
  machine), recette et modules gardés, raccords de tuyau des 4 emprises → « [FO-F3-ASSEMBLEURS] BILAN : 6 OK » ; images :
  `py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache" --qui <lot> -- 400 f3-assembleurs <source>`,
  41 captures (5 ères au zoom 1, 15 âges au zoom 2, jour et nuit, raccords ; table `fo-shots\f3-assembleurs-sites.tsv`) ;
  migration : même scénario en DOUBLE SOURCE (`--creation <racine>\fo-logs\2026-10-25_F3\src-0.4.29`, à GARDER) → 6 OK ;
- `ia3-recherche` (3 700 ticks) → « [FO-IA3-RECHERCHE] BILAN : 11 OK » (E180 : recherche d'une force sans joueur) ;
  `ia3-tourelle` (2 500) → « 9 OK » (E181 : tourelle posée près des biters puis reprise) ; `ia3-donnees` → « 2 OK » (F275) ;
- `ia1-gui` (lot IA1-i, 16 600 ticks) : fenêtre « Équipe et factions » → « [FO-IA1-GUI] BILAN : 7 OK » sans images ; avec
  images : `$env:FO_VISUAL_ARGS = '--ticks 17500'`, `fo-captures.bat ia1-gui <source>`, puis `$env:FO_VISUAL_ARGS = $null` →
  « 35 OK » dans `fo-shots\factorio.log` (ATTENTION : `fo-captures.bat` rend 0 même si ce BILAN porte des ECHEC : le lire) ;
- `ia1-poles` (lot IA1-b, 94 600 ticks) : pôles, crise, orientation, promotion → « [FO-IA1-POLES] BILAN : 17 OK » ;
  `ia1b-scale30` et `ia1b-scale10` (216 000) → 14 OK chacun, puis `python -B tools/autotest/ia1b_livre.py <arch 30>
  <arch 10>` (30 / 10 : 0,95 sur 0.4.26) ; `ia1b-migration` (37 000, DOUBLE SOURCE `FO_CREATE_SRC` =
  `<racine>\fo-logs\2026-10-25_IA1-b\src-0.4.25`, à GARDER ; feuilles de la mitrailleuse en liens durs) → 19 OK ;
- `ia1-diag` (lot IA1-e1, 108 100 ticks, moins de 1 min) : arène de modules, débits lus aux statistiques de force,
  manque de capacité et module affamé détectés, choix appliqué et mesuré → « [FO-IA1-DIAG] BILAN : 27 OK » (`main`,
  25/10, `done.txt` 7:12:27) ;
- `ia2c-cotes` (lot IA2-c, 216 000 ticks, tourelles du joueur à l'est seulement) → « [FO-IA2C-COTES] BILAN : 8 OK » ;
  `ia2c-renonce` (216 000) → « 7 OK » (renoncements : mesure) ; mesure : `py -3.9 -B tools/autotest/ia2c_joueur.py
  <bancs>` (`main` 0.4.25, 25/10, `done.txt` 6:43:23 et 6:44:22) ;
- `verif-guide` (lot VERIF-NUIT, 216 000 ticks, la partie exacte du guide du DC : réglages de carte, Facile, coffre
  garni ; À JOUER sur 2 graines : `$env:FO_MAP_SEED = '271828182'` puis `'1618033988'`, puis `$env:FO_MAP_SEED = $null`)
  → « [FO-VERIF-GUIDE] BILAN : 15 OK » (`main` 0.4.24, 25/10, `done.txt` 6:25:21 et 6:26:03) ; il ÉCHOUE si votre équipe
  reste 5 min de suite sous son effectif de départ avec du fer au coffre (1 ECHEC sur 0.4.23) ;
- `pnj-reduit` (lot PNJ-VÉRIF, 216 000 ticks) : la partie test du guide du DC (Facile, 2 factions, 30 soldats, 4 ouvriers,
  coffre d'équipe) → « [FO-PNJ-REDUIT] BILAN : 12 OK » ; `verif-tourelles` (108 000 ticks) → « [FO-VERIF-TOURELLES] BILAN :
  7 OK » (tourelles des factions et de l'équipe du joueur ; observés sur `main` 0.4.12 le 24/10, `done.txt` 14:20:38 et
  14:21:34) ; `verif-tourelles-avant` (témoin), `pnj-diag`, `pnj-diag-normal`, `pnj-vue`, `pnj-vue-attaque` (diagnostic et
  captures) ;
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
  - 8 : banc en échec (depuis D4m-géant, aussi quand un BILAN du banc porte un ECHEC : la session avec images a quand même tourné) ;
  - 10 : son vers la vraie sortie détecté par le garde, ou pilote audio autre que `disk` (lot S0).
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
- **F120 à F122** (lot A1, tourelles) : la levée dure 1 / `preparing_speed` ticks à un tick près, quel que soit le
  nombre d'images (F120) ; le moteur choisit l'image d'une tête à 64 directions par `apply_projection` : la diagonale
  nord-est montre l'image 6, pas 8 (F121) ; pour orienter une tête à l'arrêt, écrire `orientation` (`shooting_target`
  vers une entité neutre est effacé au tick suivant, F122).
- **F130 à F135** (lot M0, monde) : `on_configuration_changed` est appelé quand le CONTENU du mod change, même sans
  montée de version et à prototypes identiques (F130) ; en `--create`/`--benchmark`, rien n'est cartographié et
  `add_chart_tag` échoue : attendre `on_chunk_charted`, qui ne vient qu'avec images (F131) ; `set_tiles` sans
  troisième argument retire les entités recouvertes : poser l'eau AVANT les entités (F135).
- **F136** (Blender 5.2.2) : les graines de bruit du pipeline sont INERTES (`"W" in node.inputs` rend faux sur un
  bruit 3D) ; ne pas les « réparer » sans le DC : cela changerait tous les designs validés.
- **F123 à F129** (lot A2, la mitrailleuse en jeu) : une tête à 4 directions en feuille d'une colonne est lue N, E, S,
  O de haut en bas (F123) ; l'ombre de la tête ne tombe que sur le sol, jamais sur le socle de la même entité (F124) ;
  l'éclat de tir naît en projectile_center + distance × (vx, vy) / √(vx² + (vy / 0,7071)²) (F126) : une bouche par âge
  s'ajuste sur les 4 directions (F129) ; `fo-autotest.bat` recopie aussi les fichiers ignorés par git (F127) ; l'atlas
  [icon] de la qualité normale perd `linear-mip-level` selon le NOMBRE d'icônes (F125).
- **F150 à F153** (lot S0, sons) : sans images (`--create`, `--benchmark`), aucun son n'est chargé (F150) ; avec images,
  tous les sons sont chargés au démarrage et un son manquant renvoie le jeu au menu SANS les mods (F151) ; les volumes
  à 0 du `config.ini` ne coupent PAS la sortie (F152) ; le SDL du jeu n'a pas le pilote `dummy`, il a `disk` (F153).
- **F146 à F148** (lot A3-jeu) : une tête à 64 directions en un fichier par couche (8 × 8, `line_length` 8, sans `slice`)
  se charge et montre l'image K pour `orientation_image(K)` (F146) ; le moteur range dans l'atlas les images rognées de
  leurs marges transparentes (F147) ; au plancher, les objets vont dans l'atlas virtuel de taille fixe, seul l'atlas
  d'ombres grandit (F148).
- **F149, F157, F158** (lot A4) : une couche d'`attacking_animation` ne montre qu'UNE image, 1 tick par coup (avec 2
  images, seule celle d'indice 1) ; après `die()`, explosion et reste n'apparaissent que 13 ticks plus tard ; le
  `base_picture` d'une tourelle est animable (contrairement au centre et au mur, F44).
- **F161, F162** (lot D4m-géant) : un greffon qui centre les petits niveaux dans la case du plus grand perd leurs bras
  (poser chaque niveau à sa taille) ; l'orientation écrite d'une mitrailleuse à niveaux tient dans une usine dense.
- **F155, F156** (lot S0-suite) : l'écouteur des sons d'une session avec images est le joueur (le téléporter près de la
  source) ; un Ogg Opus passe le chargement puis lève une exception au premier tir, un Ogg Vorbis coupé passe sans
  erreur et reste muet : seule la règle « sons » du harness les voit.
- **F171 à F174** (lot PNJ-VÉRIF, groupes d'unités) : la fin d'un combat de distraction lève `on_ai_command_completed` avec
  `was_distracted = true`, le groupe reprend ensuite sa commande (ne pas la prendre pour la fin, F171) ; un long
  `go_to_location` d'un groupe arrêté dans une base ennemie échoue en 1 tick, un groupe NEUF posé sur une case libre
  rentre par étapes (F172) ; des unités ajoutées à un groupe lointain le quittent en moins de 5 ticks (F173) ; le moteur
  retire parfois des membres d'un groupe à sa création, sans événement (F174, cause inconnue).
- **F186, F187** (lot A3-final, mémoire vidéo) : au plancher, les pages de l'atlas virtuel croissent avec le contenu (9, 10, puis
  12) sous une taille adressée fixe de 12 pages : il est plein aux 15 âges à 64 directions (F186) ; le coût de rangement des
  têtes rognées dépend de la qualité (1,19 en haute, 1,44 en normale, F187).
- **F190 à F194, F199 à F203** (lots MOD-0 et MOD-1, modules) : le moteur ADDITIONNE les modules ; une balise cachée par
  machine porte le complément vers le produit (F201) ; × 328,67 au plus par effet (16 bits en centièmes) ; 60 fabrications
  par seconde au plus (assembleurs, fours) ; aucun événement quand un robot pose un module ; lire `module_effects` par
  ARRONDI au centième (F199) ; le drain n'est pas multiplié (F202) ; poser modules et balise AVANT de reverser une entrée
  pleine (F203).
- **F204 à F206** (lot A4-SOCLE) : au plancher, des couches animées vont dans un atlas ordinaire et l'atlas virtuel garde
  12 pages ; la mise au net y est plus lente (jusqu'à 11 s avec 11 socles animés à l'écran) ; `--output-perf-stats` perd
  l'espace du chemin (dossier sans espace).
- **F292 à F295** (lot IA1-d, construction par fantômes) : un fantôme non carré (chaudière, machine à vapeur) tombe à la
  position demandée dans les 4 directions et se ravive au même endroit (F292) ; un personnage DEBOUT sur l'emprise d'un
  fantôme en empêche le ravivage, `revive` ne rend rien (F293, déduit) ; le bout d'une ligne de falaises déborde de plus
  de 1,5 tuile au-delà de sa position (F294) ; un ravivage par script coûte 33 à 83 µs, 270 à 300 µs pour un poteau qui
  touche le réseau électrique (F295).
- **F251 à F253** (lot IA1-b2) : les PNJ meurent surtout en tournée vers des avant-postes lointains (F251) ; la partie du
  guide DIVERGE au moindre changement de l'équipe : conclure sur plusieurs graines (F252) ; des tourelles portées par
  un PNJ tué en route sont perdues (F253).
- **F263 à F265** (lot IA1-i) : un raccourci nouveau s'ajoute à la FIN de la barre propre au joueur (F263) ;
  `take_screenshot{show_gui}` suit l'échelle d'affichage du joueur (F264) ; en session de test, une fenêtre peut se
  fermer sans action du banc (F265).
- **F239 à F241** (lot IA1-b) : des PNJ au travail hors du QG meurent environ 9 fois plus (F239) ; le travail de fond
  d'une équipe à son effectif de départ peut la perdre (F241) : le fond ne sert qu'au-delà.
- **F242 à F244** (lot IA1-e1) : lire les débits sur les COMPTEURS (`get_input_count`), la moyenne par minute lit 0,3 à
  0,4 % trop haut (F242) ; un manque se concentre sur la machine en aval (F243) ; `insert_at_back` par script n'entre
  pas aux statistiques de production (F244).
- **F234 à F236** (lot IA2-c) : une attaque de zone s'arrête quand il n'y a plus de cible MILITAIRE dans le rayon
  (F234) ; un éclaireur seul est tué en route par les biters près de certains QG (F235) ; rassemblement puis
  `attack_area` à `on_ai_command_completed` mène l'attaque (F236).
- **F237, F238** (vérification de la nuit du 25/10) : en `--benchmark`, `log()` d'une chaîne traduite écrit l'ANGLAIS
  (F237) ; deux passages de la même carte donnent les mêmes décisions du mod (F238).
- **F219 à F221** (lot MOD-2) : `set_recipe` accepte une recette cachée et garde entrée et sortie, mais détruit les
  fluides de la fabrication en cours (F219) ; la boîte à fluide suit la recette (2 × la quantité, F220) ; un script ne
  remplit pas une entrée au-delà de sa limite d'insertion (F221).
- **F210, F211** (lot X1) : le cache des atlas des captures n'est pas refait quand seul le contenu d'une image change :
  l'effacer avant de capturer une feuille retouchée à taille égale (F210) ; `set_tiles` d'un sol ne retire ni arbres ni
  rochers (F211).
- **F213 à F218** (lots IA2-a et IA2-a2) : un point de passage choisi à 56 tuiles fixe le côté d'arrivée d'un groupe
  (F213) ; la défection à la création peut être systématique contre une cible lointaine (F214) ; un résultat de chemin
  peut arriver pour un PNJ déjà mort : vérifier `valid` avant tout appel, sinon la partie plante (F216).
- **F195 à F198** (lot B0, biomes) : une tuile copiée d'une eau et posée au-dessus des sols n'a pas de transition, d'où
  des bords en escalier (la mettre sous les sols, F195) ; changer la couche d'une tuile ou lui ajouter un grain change la
  génération, sites garantis exceptés (F196) ; ajouter des `noise-layer` nommées change la forêt vanilla ailleurs : passer
  par une graine numérique (F198).
- **F140 à F145** (lot A3, rendu) : une passe rendue à un autre nombre d'échantillons laisse les autres identiques
  octet à octet (F140) ; l'alpha d'une tête ne dépend pas des matières, d'où des masques rapides à 16 échantillons
  (F141) ; aucune plaque mince ne ferme la fente arrière des âges 4 à 7 (F142) ; 8 192 px au plus par fichier
  d'image (F144, doc) ; deux rendus Blender en parallèle ne vont pas plus vite qu'un seul sur ce PC (F145).

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
