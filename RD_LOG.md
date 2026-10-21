# RD_LOG — Journal de R&D

> Chaque entrée : **ID · statut · énoncé · protocole · résultat**.
> Statuts : `FAIT` (vérifié dans une source), `VALIDÉ` / `REJETÉ` (prouvé par expérience), `OUVERT` (à tester).
> Ordre : le plus récent en haut de chaque section.

## Session 6 — 2026-10-21 (soir) : reprise dans Claude Code, orchestration multi-agent

### Décisions du Directeur Créatif
- Prompt d'orchestration (`ORCHESTRATEUR.md`) : « aller le plus vite possible SANS baisser la qualité.
  Le parallélisme sert la vitesse, les preuves servent la qualité. » Ordre : P0, puis P1, V0 et V1 en
  parallèle ; Q4, Q6 et Q7 posées en une fois ; V2 après Q6 ; V3 après le verdict sur V0.
- 17 h 55, pendant P0 : « ultracodez si necessaire » (orchestration multi-agent autorisée là où elle
  sert).
- 18 h 07, réponses aux questions ouvertes :
  - **Q4 (PvP)** : « oui (et différents niveaux de difficulté) ». Les factions attaquent le joueur
    d'elles-mêmes ; un réglage fixe la difficulté (lot IA0, critères C4 proposés).
  - **Q6 (niveaux par époque)** : « oui c'est bien ». 2 niveaux par époque, 30 niveaux par bâtiment,
    15 niveaux pour le centre de commandement (lot V2).
  - **Q7 (15 époques)** : « oui, mais en faite rajoutez carrément des branches de matière noire etc, en
    mode vraiment un truc avancé (il faut donc imaginer le scénario et les crafts également
    évidemment) ». Liste du §6 validée ; branches avancées, scénario et arbres de fabrication à concevoir
    (lot X0, critère F1-6).
- 18 h 49, réponses aux questions de design de la bible V1 (OBJECTIFS §4, Q8 à Q12) :
  - **Q8** : « si ajourer veut dire changer le design, c'est oui ». Les machines pleines des époques 10
    à 15 seront ajourées : vides, pieds, pièces en lévitation. C'est un changement de forme, pas de
    couleur, et le seuil D1-3 reste à 50 %.
  - **Q9** : « comme vous le sentez, il ne serait pas déconant de voir une usine de 10x10 à un moment, par
    exemple sur des réacteurs d'antimatière ou quoi. » Les plafonds de V1 sont retenus pour les 7
    familles, dont l'emprise reste inchangée. Les nouveaux bâtiments des époques hautes et des branches
    avancées peuvent aller jusqu'à 10 × 10 (entrée du lot X0).
  - **Q10** : « oui je suis d'accord » (forme commune par époque, 5 ères de 3 époques).
  - **Q11** : « oui » (niveau 1 vanilla ; centre d'époque 1 redessiné en poste de pionnier).
  - **Q12** : « oui si vous voulez, je sais pas vraiment l'impact que ça aura en vérité. » Décision de
    l'architecte : aucune économie par défaut. Le recul du canon et le déploiement complet du laser se
    voient en gros plan (R4). Les économies ne reviendront en discussion que si le temps de rendu par
    image, mesuré par V0, l'impose.
- 18 h 54, **Q13 (amendement de D1-3 après E27)** : « Oui, j'accepte l'amendement de D1-3 : socle exclu
  de la silhouette et mesure insensible à la taille (seuil à étalonner sur les premières pièces). »
  D1-3 devient : IoU < 0,50, sur un masque sans couches plates au sol, ET IoU normalisée en échelle sous
  un seuil à étalonner (proposition 0,75).
- 19 h 36, **verdict V0** : « Verdict V0 : le style de la cheminée s'intègre bien au vanilla, validé. Corrigez les défauts techniques relevés et lancez la production V3. »
  Ordre retenu : V0b (corrections du pipeline, verrou de rendu, outil de mesure D1) et V3 phase 1
  (modélisation et aperçus des 7 familles) en parallèle ; V3 phase 2 (rendu final, branchement en
  jeu) après l'intégration de V2 et de V0b.

### Décisions d'architecture et d'outillage (lot P0)
- Dépôt git `main` dans le dossier du mod. `.gitattributes` `* -text` : `core.autocrlf=true` sur ce PC
  aurait converti les fins de ligne dans les worktrees. Worktrees des agents dans `.claude/worktrees/`
  (ignoré).
- Lua 5.2.4 compilé depuis la source officielle (lua.org, md5 `913fdb32…`, sha256 `b9e2e4aa…`
  vérifiés) avec `gcc -O2 -DLUA_COMPAT_ALL` (options par défaut du Makefile 5.2), sans DLL tierce
  (KERNEL32, msvcrt) : `C:\Users\evan2\bin\lua5.2.exe`.
- `fo-autotest.bat` : source du mod en 3e paramètre (test d'un worktree), copie par `robocopy` qui
  exclut `.git`, `.claude` et `tools\render`, `source.txt` dans les résultats, code 2 si le verrou est
  pris.
- `tests/datastage/harness.lua` : liste des `.cfg` par `dir /b` sous Windows.
- Fichiers orphelins `script/faction/engineer.lua` et `tools/sim_war.lua` supprimés (aucun `require`,
  vérifié par `grep`). L'expérience E4 qui utilisait `tools/sim_war.lua` reste lisible dans l'historique
  git (commit `4b2a1e0`).

### Faits vérifiés (sources du jeu 1.1.91, vérification adverse indépendante du 21/10, 19 h)
Ils ont été proposés par le lot V1, puis refaits par trois vérificateurs qui n'avaient pas vu la
production. Leurs scripts sont dans le dossier temporaire de session de l'orchestrateur ; les mesures de V1
sont dans `docs/epoques/mesures/`. Rien n'est encore vérifié en moteur.

| ID | Fait | Conséquence |
|---|---|---|
| F44 | Schéma 1.1.91 : ni le centre de commandement (type `container`, copie de `steel-chest`) ni le mur (`WallPrototype`, `pictures` de type WallPictures) n'ont de champ animable (0 sur 83 et 0 sur 92 propriétés). Les tourelles en ont 10 : `base_picture` en Animation4Way, 9 RotatedAnimation4Way dont `energy_glow_animation`, qui existe aussi pour la mitrailleuse. La foreuse, le four et l'assembleur en ont 3 (`animation`, `idle_animation`, `working_visualisations`). L'animation d'une machine est en pause quand la machine est à l'arrêt. | Pour animer le centre ou le mur : une entité compagnon, ou `rendering.draw_animation`, qui existe en 1.1.91. Sinon, des lueurs fixes. On ne sait pas si le moteur fait défiler `base_picture` d'une tourelle (non vérifié en moteur). |
| F45 | Part de l'emprise (tuiles entières, alpha ≥ 128, couches hr sans ombre ni lumière) couverte par la silhouette vanilla : four en acier 86,5 % ; assembleur 2 77,3 % ; mitrailleuse 69,7 à 72,4 % ; laser 43,5 à 45,5 % ; foreuse 51,8 à 62,0 % ; mur isolé 59,0 % ; centre actuel 65,7 %. Le chiffre dépend fortement de la définition (four : 92,6 % à alpha ≥ 1, 100 % de la collision_box). | Généralise F42 : une pièce n'est visible que si elle DÉPASSE. Le four laisse encore 0,54 t² non couverts : seule une capture dira si le socle est vraiment invisible. |
| F46 | Socle des tourelles jamais recouvert par la tête, tous états affichés compris : mitrailleuse 50,5 %, laser 69,3 %. Bande visible sur toute la largeur : mitrailleuse y ≥ +0,11 tuile, laser y ≥ -0,05 tuile. | Zone sûre pour la pièce du niveau pair posée sur le socle des tourelles. |
| F47 | Les ombres vanilla (`draw_as_shadow`) d'objets verticaux partent **plein est** (cap de 84 à 91° sur 5 sprites) : la lumière vient de l'ouest. Leur longueur vaut environ 1,1 fois la hauteur à l'écran. Le décalage des barycentres ombre/corps (cap médian 125°) ne mesure pas le soleil. Les ombres sont en gris + alpha OU en RGBA presque noir. Les lumières sont des PNG gris teintés par le moteur, ou des PNG couleur sans teinte. **La proposition de V1 (« soleil au nord-ouest, ombres vers l'est-sud-est ») était fausse : réfutée.** | Bible §1.6 corrigée ; V0 prévenu. Toute ombre rendue se cale sur des objets verticaux. |
| F48 | Le centre de commandement actuel ne copie du radar que son corps (`prototypes/levels.lua:254`, `:262`) ; l'ombre du radar n'est jamais ajoutée, et les têtes de balise (niveau 4 et plus) n'ont pas d'ombre propre non plus. La seule ombre du centre est celle du roboport. | Défaut D3 déduit du code (non vu en capture) : le centre sera redessiné en V3 (Q11). |

### Faits vérifiés en moteur réel ou dans les sources (lots P1 et V0, 21/10, 18 h 20 à 19 h 10)
| ID | Fait | Conséquence |
|---|---|---|
| F49 | `--benchmark-graphics <carte> --benchmark-ticks N` charge la partie AVEC rendu. Un joueur local est connecté dès le tick 0, `take_screenshot` fonctionne, `game.speed` est respecté, et le jeu s'arrête seul après N ticks (« automatic-quit », code 0). Protocole : chaînes du binaire, puis 15 sessions. | Base de `fo-captures.bat` : plus aucune session à fermer à la main (H-T1). |
| F50 | Options du binaire 1.1.91 trouvées par lecture des chaînes : `benchmark-graphics`, `benchmark-frame`, `until-tick` (exige `--load-game`), `window-size`, `disable-migration-window`, `cache-sprite-atlas`, `graphics-quality`, `low-vram`, `dump-data`, `instrument-mod`… Aucune option ne permet de quitter après une capture. | Outillage. |
| F51 | `take_screenshot` rend hors écran : captures identiques au pixel en fenêtre réduite et en 640×360. Paramètres en 1.1.91 : player, by_player, surface, position, resolution, zoom, path, show_gui, show_entity_info, show_cursor_building_preview, anti_alias, quality, allow_in_replay, daytime, water_tick, force_render ; et `game.set_wait_for_screenshots_to_finish()`. | La session de test peut rester réduite, sans prendre le focus. |
| F52 | Les faisceaux (lasers) et les jets (lance-flammes) ne sont pas déterministes au pixel d'une session à l'autre : 5 captures sur 84, environ 1 % des pixels chacune. Tout le reste est identique au même tick. | Une comparaison automatique de captures doit masquer faisceaux et jets. |
| F53 | Extension de F30 : en fenêtre réduite ou en priorité basse, Windows place le jeu sur les cœurs E. Les sprites se chargent alors en 35 à 160 s au lieu de 12 s, et l'étalon passe de 2,3 à 7-13 ms. | Session visuelle : utiliser le cache d'atlas (F54). Aucune mesure de performance en session visuelle. |
| F54 | Cache des atlas (`cache-sprite-atlas`, `compress-sprite-atlas-cache`) : fichier de 391 Mo, sprites en 4 à 9 s, aucun pixel changé. | Activé par défaut dans `fo-visual`. |
| F55 | Une capture 1600×900 anticrénelée avec `force_render` coûte environ 0,5 s, et le jeu tombe vers 17 UPS pendant la série. | Les captures sont espacées de 10 ticks. |
| F56 | `require` d'un fichier absent : « module X not found; no such file __mod__/X.lua … ». | Repli des greffons de scénarios. |
| F57 | Un poteau sans image, `collision_mask = {}`, de portée 64, alimente des bâtiments vanilla sans être vu. | Vitrine sans poteau dans le cadre. |
| F58 | Shader d'ombre (`shadow-a8.frag`) : alpha affiché = alpha du sprite × 0,5, en noir. Les ombres vanilla sont nettes (rampe de 1 à 2 px), avec un cœur à alpha 1. | Pipeline V0 : ombres nettes, à pleine opacité dans le PNG. |
| F59 | Nuit (`game.frag`) : `final = mix(LUT(c), c, clamp(lumières) × lightMul + lightAdd)`, avec la LUT `lut-night.png` en 16³. | Maquette de nuit hors moteur. `lightMul` et `lightAdd` restent inconnus. |
| F60 | Projection vanilla orthographique à 45°. La grille du sol est étirée de √2 en profondeur : une tuile vers le sud vaut 1,414 unité Blender. Mesuré sur les tuyaux, confirmé par la doc `apply_projection`. | Caméra du pipeline V0. |
| F61 | Les bâtiments vanilla portent un liseré de contact sombre (alpha de 0,94 à 0,1 sur environ 9 px HR). Les coffres n'en ont pas. | Pipeline V0 : liseré rendu (0,84 / 0,56 / 0,26 à 1, 3 et 6 px). |
| F62 | En moteur réel, des couches `draw_as_glow` et `draw_as_light` dans le `picture` d'une `simple-entity-with-owner` s'affichent : lueur visible de jour, halo au sol la nuit (captures 009, 010, 017, 018 de `fo-logs\2026-10-21_V0_vitrine-cheminee\`). | Voie valide pour des pièces lumineuses fixes. |
| F63 | En moteur réel, l'étape data accepte `require("__factorio-overhaul__/graphics/…")` vers un fichier Lua du mod. Banc `content` à 182 OK le 21/10 à 19 h 06. | Le pipeline peut générer un `sprites.lua` par pièce. |
| F65 | `laser-turret` : `energy_source.buffer_capacity` = 801 kJ et `ammo_type.energy_consumption` = 800 kJ par tir (relu avec `--dump-final`) : le tampon doit contenir un tir. `nuclear-fuel` s'empile par 1, alors que `uranium-235` et `uranium-238` s'empilent par 100. | Lot V2 : l'énergie et le tampon du laser croissent ensemble ; un matériau d'époque s'empile par 50 au moins (`L.MIN_MATERIAL_STACK`). |
| F64 | `draw_as_light` est une carte de lumière en espace écran : elle révèle la couleur de jour de TOUT ce qu'elle recouvre, bâtiments compris, et pas seulement le sol. Un trou dans la couche (par exemple la forme d'un objet qui bloquait la lumière dans le rendu) se voit donc comme une zone sombre sur le bâtiment (E31). | Une pièce posée sur un bâtiment doit avoir sa passe light rendue avec un volume de remplacement de ce bâtiment ; la flaque au sol reste hors de sa silhouette (lot V0b). |

### Expériences menées
**E33 · VALIDÉ · PvP en moteur réel (lot IA0, scénarios greffés, 21/10, 20 h 40 à 20 h 45)** :

| Scénario | Durée | BILAN | Résultat |
|---|---|---|---|
| `ia0-normal` | 216 000 ticks (60 min) | 14 OK | 1re attaque au tick 72 001 (Écarlate, 16 soldats, défense estimée 8), soit pile à la fin de la grâce (72 000) ; base témoin touchée au tick 78 060 ; 3 attaques en tout |
| `ia0-paisible` | 216 000 ticks | 11 OK | Base témoin intacte : 8 bâtiments sur 8, aucun touché |
| `ia0-difficile` | 144 000 ticks | 7 OK | 1re attaque au tick 43 201 (12 min) ; 6 attaques de 3 factions, de 13 à 43 soldats |

- Non mesurés : `ia0-big` et `ia0-perf` (A1, banc épinglé).
- Journaux : `<racine>\fo-logs\2026-10-21_integration_IA0_ia0-*`.

**E32 · VALIDÉ · Cadre des 15 époques en moteur réel (lot V2, banc `content` patché, 21/10, 20 h 39)** :
- Bilan : **209 OK, 0 ÉCHEC**, soit 207 contrôles du lot V2 et 2 de l'exemple greffé.
- Contrôles en jeu :
  - 195 prototypes de niveaux, avec leurs groupes de remplacement ;
  - héritage F21 jusqu'au niveau 30 ;
  - piles du jeu égales au miroir ; règle de place à chaque niveau ;
  - force au centre 14 et 6 familles au niveau 27 : 5 chantiers simultanés, le 6e refusé
    (« no-builder »), le niveau 29 refusé (« cc-too-low ») ;
  - au niveau 28, munitions, santé, recette et contenu conservés ;
  - chantiers du centre 14 → 15 et de la mitrailleuse 28 → 30 ;
  - aucun secours manuel.
- Journal : `[FO-LEVELS] 19 objets de coût, tous présents ; 5 matériaux d'époque provisoires`.
- Hors jeu : levels 1 228 et migration 27. La garde de `dress` est testée sur 32 cas d'agent V3 :
  8 acceptés, 24 refusés.
- Contre-vérification finale : 1 majeur, corrigé au lot V2b. La garde ne compare qu'une partie de la
  config, et une modification de `data.raw` hors des prototypes sources passe.
- Modèle de durée : 60 h 26 pour 60 h visées. Non prouvé en partie réelle.

**E31 · Défauts trouvés · Vérification indépendante des 18 captures V0 (3 vérificateurs, mesures au pixel)** :
- Méthode :
  - recalage de chaque couche sur la capture (recherche exhaustive du décalage) ;
  - carte des lumières de nuit reconstruite à partir de la paire jour/nuit et de la LUT `lut-night.png` ;
  - photométrie par masques.
- Rapport : `<racine>o-logs6-10-21_V0_verif-captures
apport.md`.
- Conforme : les 4 couches tombent exactement sur leurs décalages déclarés (0 px d'écart) aux zooms 1, 2 et 4,
  de jour comme de nuit ; l'ombre part du pied ; aucun pixel de la cheminée ne passe devant le four.
- **Bloquant** (four équipé, nuit) : la passe light a été rendue sans le four. Elle projette donc un trou en
  forme du pied caché sur le toit du four : carte des lumières à 0,00 contre 0,24 autour, sur 1 562 px. La
  façade reçoit 3 fois la lumière d'un four vanilla (0,29 contre 0,09). Cela tient à F64.
- Majeurs :
  - la passe light éclaire aussi le fût et la collerette ;
  - le halo est trop grand (242×266 px hr contre 152×126 en vanilla) ;
  - la collerette est translucide (cerceau mince et géométrie sous le pixel) ;
  - le rendu est trop mat (matériaux diffus, filtre de 1,5 px qui adoucit les arêtes) ;
  - la lisibilité au zoom 1 est en défaut.
- Mineurs : ordre de composition (liseré de 1 px), liseré de contact calculé sans le four, lumière trop
  bleue, cadrage des gros plans, qualité « normale » non testée.
- **Leçon** : le verdict de style du Directeur Créatif et la vérification technique au pixel sont deux
  contrôles distincts et nécessaires. Le défaut bloquant n'était visible ni pour l'orchestrateur ni dans les
  captures envoyées. Corrections : lot V0b.

**E30 · VALIDÉ (technique) · Intégration de P1 et V0 sur `main`, et vitrine V0 en moteur réel** :
- Après fusion :
  - hors jeu : run 114, war 86, td 270, pteam 15, migration 12, levels 556 ;
  - étape data : 498 prototypes, 0 nouvelle erreur, 0 violation, 0 clé manquante ;
  - api_lint : 342 usages, 0 erreur. Le premier passage annonçait 1 968 usages, car l'outil parcourait
    aussi `.claude/worktrees/` ; il est corrigé.
  - moteur réel `content` : **182 OK, 0 ÉCHEC** (19 h 06, source `main`).
- Vitrine V0 (`fo-captures.bat vitrine`, sol `dirt-4`) : code 0 en 96 s, 18 captures sur 18, session
  fermée par le pilote, focus pris 0 fois sur 176 échantillons, aucun processus de test restant.
- Captures : `<racine>\fo-logs\2026-10-21_V0_vitrine-cheminee\fo-shots\`.
- Design : **👁 en attente du verdict du Directeur Créatif**. Vérification indépendante des captures
  en cours.

**E29 · VALIDÉ (technique) · Pipeline de rendu V0 (Blender 5.2.2, hors moteur)** :
- Étalonnage avant/après (détails dans `tools/render/CALIBRATION.md`) :
  - rapport façade/dessus : 0,588 → 0,368 (vanilla 0,356–0,398) ;
  - corrélation des profils de tuyaux : 0,918 / 0,874 → 0,981 / 0,970 ;
  - ombres plein est, soleil à 48° d'élévation (vanilla 47,6–50,3°).
- Déterminisme : 18 fichiers identiques sur 18, sur deux rendus complets.
- Durée : 118,6 s pour la pièce (2 variantes, 5 passes, 256 échantillons).
- Photométrie : 5 mesures sur 7 dans les plages vanilla. **Hors plage : écart-type 0,148 (vanilla
  0,177–0,243) et p95 0,560 (0,657–0,847)**, faute de reflets francs. Défaut connu, non corrigé.

**E28 · VALIDÉ · Captures entièrement automatiques (lot P1, H-T1)** :
- Galerie `content`, deux passages de suite : code 0 ; 84 captures lisibles sur 84 ; 117 s puis 79 s ;
  aucun processus restant. 79 captures sur 84 sont identiques au pixel (F52).
- Vitrine d'exemple : 26/26 en 22 s. Guerre `default` : 21/21, mise en route de 36 000 ticks en 77 s.
- Chemins d'échec : codes 2, 3, 6 et 7 obtenus comme prévu.
- Greffons : 182 = 180 + 2 ; le scénario d'exemple donne 5 OK ; une erreur Lua devient un ECHEC compté.
- Archives : `<racine>\fo-logs\2026-10-21_P1_*`.

**E27 · VALIDÉ, avec correction · Recouvrement des silhouettes du design rejeté (hors moteur)** :
- Protocole : IoU des masques (alpha ≥ 128, couches hr sans ombre, 128 px par tuile, même origine, 4
  poses pour les tourelles et la foreuse) entre le niveau 1 et le niveau 10 de la session 5.
- Résultats :
  - sans le socle : 0,65 à 0,82 (mur : 1,00), ce qui reproduit la mesure de V1 ;
  - avec le socle réel, dalle opaque comptée dans le masque : laser 0,465 à 0,474, foreuse 0,489 à 0,580,
    centre 0,600, mitrailleuse 0,665 à 0,693, assembleur 0,750, four 0,776, mur 1,00.
- Conclusion :
  - D1-3 tel qu'écrit aurait refusé 6 familles sur 7, mais **laissé passer la tourelle laser**, dont la
    forme est pourtant identique au vanilla ;
  - un simple agrandissement sans pièce nouvelle passe sous 0,50 dès ×1,20 à ×1,41 ;
  - l'IoU mesure surtout un rapport d'aires.
- Amendement proposé (OBJECTIFS D1) : exclure les couches plates au sol, et ajouter une IoU normalisée
  en échelle. Elle vaut 1,000 pour le design rejeté et 0,903 pour le centre actuel.

**E26 · VALIDÉ · Reprise P0 : tous les bancs depuis Claude Code, sur le PC du Directeur Créatif** :
- Hors jeu : run 114, war 86, td 270, pteam 15, migration 12, levels 556 (0 échec).
- Étape data : 496 prototypes, 0 nouvelle erreur, 0 violation des règles moteur, 0 clé manquante.
  1er passage : 1 736 clés « manquantes », un faux négatif de l'outil sous Windows (`ls` dans
  `io.popen`, qui passe par `cmd.exe`) ; corrigé.
- api_lint : 318 usages puis 317 après la suppression de `engineer.lua`, 0 erreur.
- Moteur réel, `content`, 4 000 ticks : **180 OK, 0 échec**, deux passages (17 h 54 et 17 h 57, le
  second après la suppression des orphelins). Benchmark : 4 000 ticks en 0,77 s, tick moyen 0,19 à
  0,22 ms, maximum 8,3 à 8,8 ms. Banc complet (copie, carte, benchmark) en 4 s : la durée « 1 à 2 min »
  notée auparavant ne vaut plus pour `content`. Journaux : `<racine>\fo-logs\2026-10-21_P0_content*\`.
- Verrou : `fo-autotest.bat` lancé avec le verrou pris rend le code 2 (vérifié).

### Hypothèses (session 6)
- **H-T1 · VALIDÉE** (E28) : captures entièrement automatiques, sans session à fermer à la main.
- **H-V1 · VALIDÉE (verdict du Directeur Créatif, 21/10, 19 h 36)** : le pipeline est étalonné (E29) et la
  pièce est posée en jeu (E30). Verdict : « Verdict V0 : le style de la cheminée s'intègre bien au vanilla, validé. Corrigez les défauts techniques relevés et lancez la production V3. »
  Défauts techniques à corriger (lot V0b) : photométrie trop mate (E29), anneau translucide la nuit.
- **H-V2 · OUVERTE** (lot V1) : des silhouettes ajourées (vides, pieds, pièces en lévitation, Q8)
  tiennent le critère D1-3, dans sa version amendée, sans dépasser les plafonds de hauteur (Q9).
  Protocole : mesure automatique (V4) sur les premières pièces rendues.
- Note machine (lue en lecture seule par V1, sans intérêt moteur) : la carte graphique est une RX 6900 XT
  de 16 Go. La mémoire vidéo des sprites des 30 niveaux (estimée de 0,8 à 1,4 Go non compressés) n'est donc
  pas une contrainte.

## Session 5 — 2026-10-21 (fin d'après-midi) : niveaux façon Clash of Clans, cahier des charges

### Décisions du Directeur Créatif
- 16 h 10 : « Très bien, c'est un bon début, continuez, j'ai dit "niveau clash of clans" en therme
  d'échelons, de qualité de "levels" etc etc en fait, pratiquement idle game dans l'idée. »
- 17 h 26, après la galerie des niveaux : « Je viens de voir l'image et pour le moment je ne vois QUE un
  changement de couleur/teinte. Je pense qu'il est nécessaire de noter correctement les objectifs et leur
  attentes respective, dans un fichier dans le projet factorio moding car il faut pouvoir bien comparer ce
  que j'attend avec ce que vous faire. » → création d'**OBJECTIFS.md** (cahier des charges et suivi),
  désormais la référence pour comparer attentes et livraisons.
- Réponses du Directeur Créatif aux questions Q1, Q2, Q3 et Q5 d'OBJECTIFS.md (17 h 35) :
  - **Forme** : « Pièces + 15 époques, comme je le disais, si je veux jouer en continue je veux pouvoir
    avoir des ressources exploitables, de nouveaux batiments etc, ça implique devoir ajouter une grande
    quantité de contenu mais c'est souhaité, c'est l'idée finalement. »
  - **Graphismes** : nouvelles images autorisées (pièces 3D rendues dans le style Factorio). La règle 8
    (« zéro nouvel asset ») est donc **levée**.
  - **Priorité** : refaire d'abord le visuel des 7 familles.
  - **Compaction ×4** (tapis et usines T2 à T5) : tout de suite après le visuel.
- 17 h 37 : passage à **Claude Code** pour le travail multi-agent : « notez bien tout (notamment dans
  les objectifs) ». Le mode d'emploi est dans `CLAUDE.md` (racine du mod) et la reprise dans
  OBJECTIFS.md §6 et §7.

### Décisions d'architecture
- **Niveaux** (ARCHITECTURE §7 bis, BALANCE_SHEET §12) :
  - un prototype par niveau (`fo-lvl-<famille>-<n>`) ;
  - remplacement moteur en fin de chantier (`fast_replace`) ;
  - centre de commandement unique par force, qui plafonne les niveaux ;
  - ouvriers, paiement par le stock du centre, panneau « Évolution » et touche U ;
  - règles pures dans `shared/levels/config.lua`.
- **Rejeté par le Directeur Créatif** : un design par niveau fait d'une teinte de matériau, d'une
  échelle de +1,2 %/niveau, d'un socle de tuiles et d'une lueur. La silhouette restait identique.
  Nouveau critère : OBJECTIFS.md D1 (test du gris, test de la vignette, niveau final ≠ niveau 1).
- **Écart découvert en rédigeant OBJECTIFS.md** : « Compaction ×4 » n'existe qu'en modèle chiffré
  (`shared/balance_model.lua`). Aucun tapis, aucune machine, aucun objet dense n'est implémenté en jeu.

### Faits vérifiés en moteur réel
| ID | Fait | Conséquence |
|---|---|---|
| F39 | `create_entity{fast_replace = true, spill = false, raise_built = true}` remplace le bâtiment comme un remplacement rapide à la main. Sont conservés : munitions (25 chargeurs), recette (`iron-gear-wheel`), contenu (20 engrenages), stock d'un coffre (7 piles). L'ancienne entité est détruite. Il faut un `fast_replaceable_group` commun, et les tourelles vanilla n'en ont pas. | Groupes `fo-lvl-gun` / `fo-lvl-laser` donnés aux tourelles vanilla. Le secours manuel reste compté (`fallback`) et le banc exige 0. |
| F40 | Avec `raise_built = true`, `create_entity` appelle nos gestionnaires `on_built` de façon SYNCHRONE. Si l'un d'eux détruit l'entité, `create_entity` renvoie `nil`, et non une entité invalide. | Le banc teste `not (e and e.valid)`. Le refus d'un second centre de commandement se produit dans `on_built`. |
| F41 | `surface.find_entity(nom, position)` sur une entité 1×1 doit viser le CENTRE de la tuile (x,5). Au coin, elle renvoie `nil` : la rangée de murs donnait 0/0. | Les positions des murs du banc sont en x,5. La recherche en largeur de `start_row` part des positions réelles des entités. |
| F42 | Un socle posé en première couche est invisible sous un sprite qui couvre toute l'emprise (four en acier). | Un socle ne suffit pas pour un bâtiment « plein ». Il faut des pièces qui DÉPASSENT la silhouette. |
| F43 | Les paramètres d'un `localised_name` de prototype doivent être des chaînes : un nombre est refusé par le validateur de schéma (LocalisedString). | `tostring(n)` dans les noms de niveaux. |

### Expériences menées
**E25 · REJETÉ (verdict du Directeur Créatif) · Galerie visuelle des 70 niveaux** :
- **Protocole** : 7 familles × 10 niveaux en rangées, captures de jour et de nuit, et vues hautes centrées
  sur les niveaux 7 à 10 (`shots.lua`, captures `niveaux-<famille>[-nuit][-haut]`).
- **Constats techniques** :
  - chaque niveau a son matériau ;
  - socles visibles sauf sous le four ;
  - halos des niveaux 6 à 10 visibles la nuit ;
  - le centre de commandement gagne des antennes aux niveaux 4 et 7.
- **Verdict** : « je ne vois QUE un changement de couleur/teinte ».
- **Cause** : la silhouette est la même du niveau 1 au niveau 10 (F42 pour le socle).
- **Suite** : OBJECTIFS.md D1/E2.

**E24 · VALIDÉ · Niveaux en moteur réel (scénario `content`, 4 000 ticks)** :
- 1er passage : 179/180. La rangée de murs donnait 0/0 (F41).
- 2e passage (21/10, 17 h 30) : **180/180**.
- Les 35 contrôles de niveaux prouvent :
  - 70 prototypes présents, aux statistiques strictement croissantes ;
  - un objet par niveau ;
  - bonus de recherche hérité (mitrailleuse 1,90 = niveau 10 1,90) ;
  - un seul centre par force ;
  - chantier payé par le centre, tourelle hors service pendant le chantier ;
  - refus « pas d'ouvrier libre » et « centre trop bas » ;
  - remplacement au même endroit, avec munitions (25), santé en proportion (230/460) et recette
    conservées ;
  - stock du centre conservé au remplacement ;
  - rangée de 5 murs instantanée ;
  - 0 secours manuel.
- Hors jeu :
  - `tests/levels_test.lua` : 556 OK ;
  - autres suites inchangées et vertes (run 114, war 86, td 270, pteam 15, migration 12) ;
  - api_lint : 317 appels, 0 erreur ;
  - étape data : 496 prototypes, 0 nouvelle erreur.

### Hypothèses
- **H-V1 · OUVERTE** : des pièces 3D rendues dans le style Factorio s'intègrent sans rupture
  visuelle.
  - Conventions : haute résolution 64 px/tuile affichée à l'échelle 0,5 ; ombre séparée
    `draw_as_shadow` ; éclairage et palette mesurés sur les sprites vanilla ; masques lumineux séparés
    `draw_as_glow` / `draw_as_light`.
  - Moyen envisagé : Blender sans interface (module Python `bpy`), ou rendu maison.
  - Protocole : rendre UNE pièce, la poser à côté de bâtiments vanilla, capturer de jour et de nuit
    aux zooms 1 et 2, comparer la lumière, l'ombre et le grain, puis obtenir le verdict du Directeur
    Créatif.
- **H-L1 · OUVERTE** : coût script des niveaux nul hors chantier, ≤ 0,02 ms/tick avec 4 chantiers et 1
  panneau ouvert. Il n'a pas encore été mesuré au benchmark épinglé.
- **H-T1 · OUVERTE** : rendre les captures entièrement automatiques, sans session interactive à
  fermer à la main.
  - Piste 1 : vérifier si `factorio.exe --help` (1.1.91) propose un benchmark avec rendu.
  - Piste 2, à défaut : fermer la session `fo-visual` en ciblant SA ligne de commande. Ne jamais
    arrêter tous les `factorio.exe`, car le joueur peut être en partie.

## Session 4 — 2026-10-21 (matin et après-midi) : économie réelle, équipes qui jouent, nouvelles armes, défense de tours

### Décisions du Directeur Créatif
- « Les PNJ doivent pouvoir jouer : s'armer, se défendre, participer à l'économie de l'équipe en posant
  des bâtiments. Une mini-intelligence par ÉQUIPE (pas par PNJ) qui sait ce qu'il reste à faire et comment,
  avec un objectif d'équipe (le fer, le pétrole…) ; les IA s'organisent pour y arriver et font des crafts. »
- « Si tu ne peux pas m'assurer que tout fonctionne, le travail n'est pas terminé. »
- Visuels : combiner couleurs, tailles ET nouveaux styles ; plus de contenu (autres tourelles, lanceurs) ;
  mode défense de tours activable à tout moment, en plus de la guerre.
- Après les premières captures (14 h) : « c'est surtout la couleur qui change, ce n'est pas un nouveau
  design » ; biomes vraiment différents ; « à la mode des évolutions de Clash of Clans » pour les minerais,
  les tourelles, les usines : le design évolue avec le niveau, effets lumineux, « de la précision ».

### Décisions d'architecture
- **Fin du registre MU** : tout ce qu'une faction possède est un objet réel dans le coffre de son QG
  (stock). Avant-postes = foreuses à combustible qui tournent, chacune déversant dans un four (fer,
  cuivre) ou un coffre (charbon, pierre) ; fonderie au QG (minerai d'appoint, acier, briques).
- **Cerveau d'équipe pur** (`shared/team/planner.lua`) : échelle d'objectifs, « ce qui manque » calculé
  par un livre de recettes construit sur les VRAIES recettes (`shared/team/book.lua`), tâches priorisées ;
  le runtime (`script/team/`) n'exécute que des verbes : miner, fabriquer, porter, poser, ravitailler,
  agrandir, fortifier, fondre, se défendre.
- **S'armer** : un soldat n'est créé que si son équipement (mitraillette + chargeurs, armure, grenades)
  a été fabriqué ; un ouvrier porte un pistolet et tire sur les ennemis proches.
- **Recherche payée en packs** fabriqués par l'équipe (rouge, vert, militaire) ; les niveaux 4-5
  demandent le pack chimique (pétrole) : prochain chantier.
- **Équipe du joueur** : coffre d'équipe ; mêmes ouvriers, même cerveau, échelle sans armée ni recherche.
- **Zone de départ par faction** : un gisement de chaque ressource de base à ~46 tuiles du QG (F15).
- **Arsenal spécial** : de nouvelles FAMILLES d'armes (canon, mortier, arc, acide, rail, lance-grenades)
  assemblées à partir de pièces graphiques vanilla (règle 8 élargie : silhouettes composées), chacune
  avec un contre vérifié au banc de contenu.
- **Défense de tours** : mode activable à tout moment, force dédiée `fo-horde` en paix avec les
  déchiqueteurs naturels, règles pures dans `shared/td/waves.lua`, défaite gérée (base tombée).
- **Résistances de famille par palier** : la part fixe des résistances de famille croît avec le palier.
- **Migration 0.2 → 0.3** : une guerre à MU d'une ancienne sauvegarde est arrêtée proprement.
- **Évolution visuelle** (`prototypes/evolution.lua`) : un palier se voit à sa forme et à sa lumière
  (pièces d'autres machines, couches additives `draw_as_glow`), plus jamais à la seule teinte ; biomes à
  textures et décors propres ; minerais à formes et éclats propres.

### Faits vérifiés en moteur réel
| ID | Fait | Conséquence |
|---|---|---|
| F20 | Le moteur tronque chaque effet de module au pourcent entier : 1,15 en flottant (1,1499…) donne +114 %. | Epsilon positif sur les effets générés. |
| F21 | Les bonus de recherche « turret-attack » sont attachés à un NOM de tourelle : une copie de la mitrailleuse n'en hérite pas (la tourelle lourde tuait 2× moins vite que la mitrailleuse). | Les tourelles du mod reçoivent les mêmes effets que leur modèle (data-final-fixes). |
| F22 | Lance-flammes et pulvérisateurs sont orientés : ils ne tirent que dans un cône de 120°. | Banc de contenu : tourelles orientées vers la cible. |
| F23 | Une RotatedAnimation à fichiers multiples exige `slice` (un RotatedSprite réemployé fait refuser le prototype au chargement). | Règle moteur ajoutée au banc data-stage ; fût du mortier corrigé. |
| F24 | `require` est interdit pendant un événement (une fonction d'interface distante l'appelait). | Le moteur simulé refuse aussi `require` pendant un événement. |
| F25 | Le contenu d'une requête de test transmise par le surveillant devient le nombre de ticks du benchmark. | La requête contient le nombre de ticks. |
| F26 | Poser une entité pour lire son point de dépôt puis la détruire coûte cher : jusqu'à 400 ms sur un gisement déjà occupé. | Point de dépôt calculé (vecteur du prototype), essais plafonnés. |
| F27 | Des ouvriers qui rentrent tous au même point se gênent : départs de chemin bloqués (150 échecs en 30 min), tournées perdues, plaques bloquées dans les fours. | Une case par ouvrier autour du QG. |
| F28 | Viser le centre d'un gisement couvert de foreuses fait échouer le pathfinder (« but occupé »). | Point d'accès = position de l'ouvrier au moment de la construction. |
| F29 | Un personnage qui fabrique des chargeurs ou une arme les ÉQUIPE automatiquement (cases arme et munitions) : invisibles dans l'inventaire principal, ils ne revenaient jamais au stock. 400 plaques de fer « disparaissaient » par équipe en 30 min, défense et armée bloquées. | Au dépôt, l'ouvrier vide aussi ses cases arme, munitions et armure (il garde son pistolet et 10 chargeurs). |
| F30 | Sur ce PC (Intel 12e génération : cœurs P et E), le benchmark lancé en arrière-plan ralentit d'un facteur 3 après quelques minutes et subit des pauses jusqu'à 170 ms : une charge Lua FIXE chronométrée toutes les 10 s passe de 2,3 ms à 7-14 ms (pics 67-173 ms). Une carte vide (5 s de benchmark) n'est pas touchée. Épinglé sur les cœurs P : 30 min de jeu en 40 s au lieu de 6 min, étalon stable (médiane 2,5 ms, max 5,1 ms). | Étalon machine [FO-CALIB] dans chaque test ; benchmark épinglé sur les cœurs P, priorité au-dessus de la normale. Les pics des itérations 1 à 8 de E16 sont donc à relativiser. |
| F31 | Un arbre à « variations » exige `colors` (« Key colors not found » au chargement). | Palette conservée et assombrie ; règle `tree-colors` au banc data-stage (vérifiée sur l'erreur réelle). |
| F32 | Le bonus de dégâts d'un fluide de lance-flammes ne s'applique qu'au jet direct, pas aux brûlures : méthane ×1,25 contre pétrole léger ×1,1 restait dans le bruit (237 contre 245 PV/s). | Méthane ×1,5, et banc corrigé : sur un « big » (375 PV, tué en 1,5 s) la mise en route du jet masquait tout écart (237 contre 245 PV/s à ×1,25 comme à ×1,5). Sur un béhémoth (3 000 PV) : méthane 1 241 PV/s, pétrole léger 1 111 PV/s (+12 % au total). Banc de contenu : 145/145. |
| F33 | « Ouvrir » Factorio par l'outil de contrôle du PC démarre une seconde instance sur la configuration du joueur (menu principal) au lieu de passer la fenêtre de test au premier plan. | Ne jamais l'utiliser pour Factorio ; la session de test prend ses captures seule. |
| F34 | En session visuelle, le scénario « freeplay » joue la cinématique de l'épave à l'arrivée du joueur puis affiche son message d'accueil, qui MET LE JEU EN PAUSE en solo jusqu'à <Tab> : captures bloquées à 34/55, et aucune mesure après les captures dans les sessions précédentes. | Le mod de test coupe l'introduction et l'épave (`set_skip_intro`, `set_disable_crashsite`) à la création de la carte ; sans effet sur les bancs (aucun joueur n'y est créé). |
| F35 | En bord de zone générée, un chunk n'a que ses tuiles (ni décor, ni entités) ; le choix « premières tuiles trouvées » tombait là : sol nu sur les 9 captures de biome. Par ailleurs `global` est propre à chaque mod : le mod de test ne voyait aucun QG (0 capture de QG ou d'avant-poste depuis la session 3). | Point de capture choisi dans un chunk entièrement généré (et ses 8 voisins), noté par la quantité de décor ; QG et avant-postes lus par l'interface `points_of_interest`. |
| F36 | Une teinte de tuile ne fait que MULTIPLIER la texture : toutes les textures terrestres vanilla sont chaudes (sable, terre, désert), aucune ne vire au lilas ; et la texture de base des eaux peu profondes est bleu-vert, qu'une teinte verte sature (« ultra vert »). | Plaine de cristal sur la texture d'eau peu profonde (surface miroitante, terrain ferme, sans gerbes, pas sur du pavé), reflets lilas ; marais olive-brun, reflets vaseux ; cendres gris charbon ; décor plus dense. |
| F37 | La copie lumineuse des seuls masques d'une tête de tourelle (une bande de quelques pixels) ne se voit pas de nuit ; celle des masques d'un déchiqueteur (carapace) se voit nettement. La bobine de la tour à arc (texture de lumière de la balise) restait invisible même à pleine intensité, en tête comme sur le socle. | Tourelles lourdes : halo de nuit `draw_as_light` de toute la tête (vérifié : tête bleutée / rose la nuit). Tour à arc : arcs de charge de l'accumulateur (vraie couche alpha) sur le socle + halo de nuit (vérifié en capture : arcs cyan de jour, halo bleu de nuit). |
| F38 | Mesuré sur les fichiers du jeu : la texture d'éclat de l'uranium est vert pur (0,45 ; 1 ; 0) et la texture du minerai d'uranium presque sans bleu (moyenne 0,22 ; 0,31 ; 0,07). Teintés, le « cristal violet » était brun-olive à éclat jaune et le tungstène verdâtre ; la texture de la balise (bobine de la tour à arc) est presque transparente (alpha moyen 0,003). | Choix de texture d'après la couleur MESURÉE des fichiers, aperçus calculés avant d'écrire le prototype ; éclats = texture du gisement lui-même en additif ; cristal sur la texture neutre du fer ; bobine à pleine intensité + halo de nuit. |

### Expériences menées
**E15 · VALIDÉ · Banc de contenu en moteur réel (113 contrôles, avant l'arsenal spécial)** : chaque recette du mod tourne dans sa
machine ; les 30 modules donnent l'effet attendu ; chaque munition et tourelle tue une cible immobile ; les
contres voulus sont vérifiés (tungstène > perforant, laser > perforant contre les blindés, foudroyants
résistants au laser, méthane > pétrole léger…) ; ennemis, nids, morts ignées et couvées, murs, minerai dur,
méthane, cristal, poison et soin des biomes. 1er passage : 107/113 ; 6 écarts corrigés (F20-F22) ; 2e
passage : 113/113.

**E16 · Équipes à économie réelle (moteur réel, 30 min)** : itérations
| Itération | Constat | Correction |
|---|---|---|
| 1 | gisements introuvables : 2 factions sans fer, bloquées dès le 2e objectif | zone de départ par faction |
| 2 | chantier abandonné (stock pris entre-temps) : site perdu | le site revient à la réserve |
| 3 | tournées en échec « but occupé » | point d'accès de l'avant-poste |
| 4 | fer épuisé : plus aucune plaque, équipe figée | fonderie de départ, minage à la main par les ouvriers inoccupés |
| 5 | pics de script (5 % des ticks > 2 ms, jusqu'à 480 ms) | point de dépôt calculé (F26) |
| 6 | départs bloqués au QG (F27) | une case par ouvrier |
| 7 | défense et armée bloquées : le fer « disparaît » (F29) | dépôt des cases arme, munitions, armure |
| 8 | 30 min : 4 équipes à 24-30 soldats, recherche 1-2, mais une seule attaque (29,7 min) ; 3 équipes sur 4 sans 2e gisement de fer (objectif « fer II » mis de côté) | seuil d'attaque = taille de la personnalité (13 à 28) ; gisement de fer de départ plus large (20 foreuses) ; prospection élargie à 18 chunks après un tour infructueux |
| 9 | (benchmark épinglé, F30) 2 attaques en 30 min ; une équipe sans ouvriers (tués) ne peut plus rien fabriquer ; une autre bloquée : 151 « chemin introuvable » depuis le pied de son QG (départ dans la boîte élargie du QG) | embauche de secours sans arme ; point de départ poussé hors des obstacles de la boîte élargie |
| 10 | 60 min : guerre réelle (34 attaques, la Ligue Azur anéantie à ~50 min), recherche 2-3 ; des avant-postes perdus jamais reconstruits ; « avant-postes défendus » jamais atteint | reconstruction d'un avant-poste perdu (le gisement revient à la réserve) ; objectif atteint à 75 % des avant-postes défendus |
| 11 | une équipe sans fer pendant 50 min : son avant-poste de fer détruit, le kit complet (8 foreuses) infabricable, l'ouvrier minait des tuiles couvertes par les fours restants (4 minerais en 50 min) | reconstruction minimale (2 paires) ; minage sur une tuile libre ; sorties de minage d'au moins 20 minerais |

**E17 · VALIDÉ · Coût réel (benchmark épinglé sur les cœurs P, 30 min, 4 équipes à économie réelle,
~70 agents riches, 50 compagnons)** : script 0,10 ms/tick en moyenne (p99 0,58 ms, max 13,6 ms) ; tick
complet 0,39 ms (p99 1,58 ms) ; 2 ticks sur 108 000 au-delà de 16,7 ms ; 47 ticks de script > 2 ms
(0,04 %), tous attribués (ouvriers qui agissent, pensée d'équipe, chemins longs). Les mesures des
itérations 1 à 8 (script p99 ≈ 5 ms, pics de 1,6 s) étaient faussées par la machine (F30).

**E18 · VALIDÉ · Arsenal spécial en moteur réel** : 1er passage 135/144 ; la tour à arc ne tirait pas
(réserve d'énergie copiée de la tourelle laser : 801 kJ pour un arc de 1,2 MJ), l'arc portatif non plus
(paramètres d'attaque « projectile » avec une munition à rayon), l'obus en tungstène (tout physique)
était moins bon que l'obus ordinaire contre les blindés (qui résistent au physique), le mortier moins bon
que la mitrailleuse contre un groupe de 6 ; corrigés. 2e passage : **145/145**.

**E19 · VALIDÉ · Défense de tours en moteur réel (base témoin : 12 mitrailleuses à munitions
perforantes, sans recherche ni réparation, guerre des factions en parallèle)** : 1er passage, vagues 1-3
repoussées, vague 4 (petits et moyens blindés) quasi immunisée (8 dégâts contre 12 de résistance fixe)
rase la base et reste plantée au centre jusqu'au rappel (6 min) ; correctifs : résistance fixe de famille
proportionnelle au palier, palier maximal toutes les 4 vagues, boss 2 + vague/5, défaite détectée (base
tombée → mode arrêté proprement), groupes bloqués relancés ou repartis d'un autre point. 2e passage
(30 min) : vagues 1-4 repoussées (160 tués), la base témoin tombe au boss de la vague 5 et le mode s'arrête
avec son record. Coût : script 0,06 ms/tick, tick complet p99 1,4 ms.

**E20 · VALIDÉ · Équipe du joueur en moteur réel (15 min, guerre en parallèle)** : coffre d'équipe posé
(400 fer, 3 pistolets…) ; 6 ouvriers recrutés avec les équipements du coffre ; charbon 0,5 min, fer 1,8,
cuivre 4,1, pierre 7,0, défense 7,5 ; fer du coffre 400 → 1 165 en 15 min (1 239 plaques livrées).
Limite : l'objectif « fer II » attend un 2e gisement de fer près du départ du joueur.

**E21 · VALIDÉ · Guerre à économie réelle sur 60 min (moteur réel épinglé, version finale)** : tableau
dans BALANCE_SHEET §10 ; défense à 5-7 min, armée à 8-11 min, recherche 1 à 12-25 min, recherche 3 pour
deux équipes vers 40 min ; 10 attaques, la première à 15,8 min ; une équipe ruinée par des attaques
répétées survit grâce à l'embauche de secours (une partie précédente : 34 attaques et une élimination à
~50 min). Script 0,14 ms/tick (p99 0,86 ms), 8 ticks sur 216 000 au-delà de 16,7 ms.

**E22 · VALIDÉ · Charge maximale (scénario `stress`, 10 min, 402 agents riches)** : voir H5.

**E23 · VALIDÉ · Revue visuelle en moteur réel, jour et nuit (session 4, après-midi)** : 4 passages
(carte de guerre + arène de contenu). 1er passage : 34 captures sur 55 puis jeu en pause (F34), biomes
pris en bord de carte sans décor et aucun QG (F35). 2e : biomes enfin visibles, mais minerais verdâtres
(F38), marais trop vert (F36), bobine de la tour à arc invisible (F37). 3e et 4e : cendres gris charbon,
roches en fusion et braises qui rougeoient la nuit ; plaine vitrifiée lilas à amas violets et éclats cyan
lumineux ; marais olive en forêt de troncs morts ; tungstène en métal sombre à reflets acier, cristal violet
vif qui luit la nuit ; carapaces des familles lumineuses la nuit ; tour à arc à arcs cyan. QG, avant-postes
et équipe du joueur capturés (24 captures de guerre, 55 de contenu). Banc de contenu repassé à chaque
changement de prototype : 145/145 (4 fois).

### Outillage (session 4)
- `fo-autotest.bat` épinglé sur les cœurs P (F30) ; étalon `[FO-CALIB]` ; 30 min de jeu en ~40 s.
- `shots.lua` : captures automatiques en session graphique ; ne PAS « ouvrir » Factorio par l'outil de
  contrôle du PC une fois `fo-visual.bat` lancé : cela démarre une seconde instance sur la configuration
  du joueur (constaté, refermée aussitôt depuis son menu principal).
- `tests/migration_test.lua` (sauvegarde 0.2 → 0.3), tests de reconstruction, d'embauche de secours, de
  groupes bloqués et de base tombée.

### Hypothèses (mise à jour)
- **H-P1 · CADUQUE** : les à-coups « un par minute pendant les combats » (F19) venaient en grande partie
  de la machine (F30) : épinglé, 1 à 2 ticks sur 108 000-216 000 dépassent 16,7 ms.
- **H5 · VALIDÉE** (E22) : 402 agents riches (380 compagnons + ouvriers des 4 équipes), guerre en cours :
  script 0,50 ms/tick en moyenne (p99 1,5 ms, budget 1,5 ms), tick complet 2,1 ms (p99 4,5 ms) ; la
  locomotion pèse 0,26 ms/tick.
- **H-M1 · OUVERTE** : erreur à l'écran d'une simulation du menu principal (« biter_base_player_attack »,
  ligne 68) observée une fois avec le mod chargé ; non reproduite, cause non établie, sans effet en partie.
- **H-E1 · OUVERTE** : au-delà de 60 min, l'échelle mène au pétrole (pack chimique) que les équipes ne
  savent pas encore produire : elles stagnent en recherche 3 (prochain chantier).

## Session 3 — 2026-10-20 (nuit) : passage au moteur réel

### Décisions du Directeur Créatif
- « Utilisez mon PC, faites vos tests vous-même » ; contrôle total accordé pour la nuit, objectif : un
  Factorio Overhaul abouti au matin.

### Outillage (nouveau)
- `fo-autotest.bat` : test en moteur réel **isolé** (dossier de mods, dossier d'écriture et config séparés :
  la partie, les sauvegardes et le journal du joueur ne sont jamais touchés, on peut jouer pendant un test).
  Benchmark `--benchmark-verbose all` : temps par tick et par poste du moteur (dont `scriptUpdate`).
- `fo-autotest-watch.bat` : lancé une fois par le joueur ; relance le test dès que Claude dépose
  `fo-autotest-request.txt`. Paramètres dans `fo-autotest-params.txt` (`<ticks> <scénario>`).
  Scénarios du mod de test : `default` (4 factions, 50 compagnons), `stress` (armées financées, 380 compagnons).
- `tools/autotest/analyze.py` : synthèse des journaux et des temps par tick (moyenne, p50, p99, max, par minute).
- `fo-visual.bat` : ouvre le jeu AVEC images sur la dernière carte de test, dans un dossier séparé.
- Banc data-stage : signature des erreurs de littéral enrichie (valeur attendue/obtenue) — le bruit vanilla
  masquait une vraie erreur — et `tests/datastage/engine_rules.lua` (règles de chargement du moteur non
  exprimables dans le schéma : énergie, résistances ≤ 100 %, vision ≤ 100, points d'apparition triés…).
- Leçon d'exploitation : **ne jamais réécrire un .bat en cours d'exécution** (cmd relit le fichier par
  décalage d'octets : une ancienne fenêtre a exécuté un morceau du nouveau script).
- Leçon d'exploitation : le pont de fichiers peut renvoyer une **ancienne version** d'un fichier recommité
  sous le même chemin de staging ; on copie chaque envoi dans un dossier de staging unique
  (`/mnt/user-data/outputs/_c/<horodatage>/…`) et on vérifie les tailles sur l'appareil après envoi.

### Faits vérifiés en moteur réel
| ID | Fait | Conséquence |
|---|---|---|
| F12 | `range_mode` n'accepte que `center-to-center` et `bounding-box-to-bounding-box` en 1.1.91. | Soldats corrigés ; banc data-stage durci. |
| F13 | `--create` exécute `on_init` des mods et sauvegarde ; `--benchmark` rejoue N ticks sans affichage ; `--benchmark-verbose all` donne ~30 postes de temps par tick (ns), dont `scriptUpdate`. | Mesure directe du coût du mod, poste par poste. |
| F14 | Un départ de `request_path` qui chevauche un autre corps (foule d'agents) échoue d'emblée. | Départ recalé sur le point libre le plus proche : échecs 69 % → 0,4 %. |
| F15 | Hors zone de départ, les gisements sont rares (fondu jusqu'à 420 tuiles, ~2,5 gisements/km² par minerai). | QG à 480 tuiles, prospection sur 12 chunks. |
| F16 | Convertir un nombre en chaîne (clé `"cx:cy"`) coûte ~4 µs dans le Lua du jeu. | Clés de chunk numériques. |
| F17 | `LuaSurface.calculate_tile_properties` n'accepte pas d'expression de bruit nommée arbitraire (même déclarée dans `property_expression_names`). | Mesure des biomes par recensement de tuiles générées. |
| F18 | Une commande composée de groupe échoue entière si une étape est inaccessible (lac, falaise). | Itinéraire calculé par le pathfinder avant le départ. |
| F19 | Sans guerre (même carte, scénario témoin), le moteur ne fait aucun à-coup (0,03 ms/tick). Avec la guerre, ~1 image par minute dépasse 16,7 ms (20 à 120 ms), dans `gameUpdate` sans poste attribué, au moment des combats ; ni l'expansion des biters, ni la paix avec eux, ni des garnisons au repos, ni l'absence de séparation des unités ne les suppriment. Les gestionnaires d'événements du mod sont mesurés : ils sont négligeables. | Coût moteur des combats de masse (C++), à réduire par la taille des escouades (H-P1). |

### Expériences menées (moteur réel, carte graine 20261020, 30 min de jeu chacune)
**E8 · VALIDÉ · Chargement complet du mod** : étape data, prototypes, carte, `on_init`, 30 min de jeu sans
erreur ; jeu lancé AVEC images (`fo-visual.bat`) : « Sprites loaded » sans erreur, compagnons visibles et
en marche, surcouche de débogage (états, chemins) affichée.

**E9 · VALIDÉ · H1 en moteur réel** : efficacité de déplacement 0,93-0,94 sur 450 000 tuiles parcourues
(mode « lazy », pilotage tous les 4 ticks). Le pilotage espacé des agents riches est viable.

**E10 · VALIDÉ après 4 corrections · Pathfinding des agents** : 69 % d'échecs au départ → 0,4 %.
Cause : départ chevauchant un autre corps (F14). Aussi : destinations d'errance sur l'eau exclues,
pas de marge de boîte ni de grille grossière pour les longs trajets, relance après blocage, rappel au QG
des ingénieurs enclavés.

**E11 · VALIDÉ après 9 itérations · Économie des factions en moteur réel**
| Itération | Avant-postes / faction à 30 min | Tech | Revenu MU/s | Cause corrigée |
|---|---|---|---|---|
| 1 | 0 | 0 | 1,9 | chemins (E10), poison du marais sur les ingénieurs, remboursement partiel |
| 3 | 0-3 | 1-2 | 5-7 | QG trop près du centre (F15), sondes trop espacées, prospection coûteuse |
| 6 | 0-4 | 1-3 | 7-18 | attaques mort-nées (F18) : itinéraires calculés |
| 9 | **3-7** | **3-4** | **20-29** | QG enclavés : vérification d'accès + déménagement ; ingénieurs rappelés |
Simulateur hors-jeu au même instant : 6-11 avant-postes, tech 2-3, 34-39 MU/s : ordre de grandeur atteint.

**E12 · VALIDÉ · Coût script** : moyenne 0,12 ms/tick, p99 ≈ 1 ms (budget 1,5 ms) avec 4 factions,
~300 soldats, 50 compagnons et 16 ingénieurs. Prospection 0,012 ms/tick, commandants 0,002 ms/tick.

**E13 · VALIDÉ · Monde** : biomes présents (cendres 32 k, plaine 95 k, marais 138 k tuiles sur ~1 600 chunks) ;
tungstène 1 221 tuiles, cristal 222, méthane 11 puits près des QG ; à 1 800 tuiles, 39 % des nids sont des
nids de famille (blindée, ignée), les familles couvée et foudroyante apparaissant plus loin.

**E14 · REJETÉ · Origine des à-coups moteur** (F19) : quatre expériences témoins (expansion coupée, paix
avec les biters, garnisons au repos, sans séparation) ; aucune ne les supprime.

### Hypothèses (mise à jour)
- **H1 · VALIDÉE** (E9). **H-F3 · VALIDÉE** (attaques et pertes réelles). **H-W1 · VALIDÉE** (E13).
- **H-F4 · VALIDÉE en partie** : le jeu charge et affiche les prototypes ; l'aspect des soldats reste à
  regarder de près en partie normale.
- **H5 · OUVERTE** : 430 agents riches non mesurés en moteur réel ; le scénario `stress` est prêt
  (`fo-autotest-params.txt` : `108000 stress`).
- **H-P1 · OUVERTE** : des escouades de 20 au lieu de 60 réduisent les à-coups des combats.

## Session 2 — 2026-10-20 : contenu en paliers, monde, factions IA v0, bancs de vérification

### Décisions du Directeur Créatif
- Compaction ×4 **validée**. Multijoueur hors périmètre pour l'instant : **solo avec PNJ**, version 1.1.91.
- Ajouts demandés : modules à nombreux paliers, déchiqueteurs supérieurs et nouveaux designs, armes,
  défenses, munitions, ressources à effets, biomes ; vision d'une guerre « 100 contre 100 contre 100 contre 100 ».

### Faits vérifiés
| ID | Fait | Conséquence |
|---|---|---|
| F8 | La licence (`data/eula.txt`) autorise l'usage personnel mais interdit de distribuer une version altérée du jeu. Le moteur est un binaire C++ natif : on ne peut pas le décompiler en un code source recompilable. | Rien ne passe par le moteur : tout le contenu demandé est faisable par l'étape data (Lua de `data/base`, lisible) et l'API runtime. |
| F9 | Les animations vanilla des déchiqueteurs, vers, nids et du personnage sont produites par des fonctions globales paramétrées (taille, teintes). | Nouveaux paliers et familles sans aucun nouvel asset. |
| F10 | L'évolution des ennemis est plafonnée à 1,0 par le moteur. | Les 8 paliers sont redistribués sur [0, 1]. |
| F11 | `resource-autoplace` garde un état global (`resource_autoplace__patch_metasets`). | Sans conséquence en jeu ; le banc data-stage remet l'état Lua à zéro entre ses deux passes. |

### Expériences menées
**E7 · VALIDÉ · Test de fumée de la guerre (moteur simulé, `tests/war_test.lua`, 62 tests)**
- 4 factions × 20 min : avant-postes construits par les ingénieurs (4 à 7 par faction), armées de 38 à 60,
  8 à 16 attaques par faction, pertes, technologie 1-2 ; foreuses inactives ; compteurs cohérents ;
  `global` sérialisable ; reprise après rechargement en pleine guerre ; déterminisme ; élimination à la perte
  du QG ; déclaration de guerre au joueur ; arrêt propre ; poison du marais, soin du cristal ; couvée.
- Premier passage : 57/58. Échec réel : **aucune recherche sous attrition forte** (voir E4).

**E6 · VALIDÉ après correction · Banc data-stage (`tests/datastage/`)**
- Rejoue core → base → mod (data, updates, final-fixes) en Lua 5.2 en 5 s ; 2 505 prototypes vanilla,
  295 du mod ; validateur de schéma, références croisées, chemins d'images, localisation FR/EN.
- Étalonné sur vanilla (tout ce qu'il signale sur vanilla est du bruit) et éprouvé par erreurs plantées
  (type faux, propriété mal orthographiée, propriété manquante, item, technologie et cadavre inexistants,
  traductions absentes) : toutes détectées.
- Défaut trouvé et corrigé : résultats **non déterministes** (plafond d'erreurs par prototype + ordre de
  `pairs` variable en Lua 5.2) → parcours triés, plus de plafond. 3 exécutions identiques ensuite.
- Défaut trouvé et corrigé : explosion combinatoire sur les unions récursives des expressions de bruit →
  expressions de bruit traitées comme opaques. **Conséquence : la génération de carte (biomes) n'est
  vérifiable qu'en moteur réel** (autotest).

**E5 · VALIDÉ · Contrôle d'API étendu** : 146 usages contre `runtime-api.json`, 0 erreur ; règle affinée pour
les méthodes positionnelles dont le paramètre est une table (`set_command`, `insert`, `is_chunk_generated`).

**E4 · VALIDÉ après 6 itérations · Calibrage du cerveau des factions (`tools/sim_war.lua`)**
| Itération | Constat | Correction |
|---|---|---|
| v1 | Tout l'argent part en soldats, aucun avant-poste, attaques suicides | réserve économique, budget militaire sur le surplus, attaque sur avantage estimé |
| v2 | Revenu englouti : 80 MU de munitions toutes les 5 s | réapprovisionnement seulement des tourelles à court |
| v3 | Armées pleines à 10 min, recherche bloquée | coûts relevés, effectif cible par personnalité, épargne au-delà |
| v4 | Escarmouches permanentes | logique de campagne : accumuler 60 % de l'effectif cible puis frapper |
| v5 | Acharnement collectif sur la plus faible, boule de neige | coalition contre le leader, raids sur avant-postes, rattrapage, améliorations sans fin |
| v6 | En jeu simulé (E7) : technologie gelée sous attrition | **fonds de recherche** (15 % du revenu, intouchable) |
- Résultat final : technologie 3 à 30 min, maximum à 60 min ; 3 factions sur 4 à 100 soldats entre 45 et
  90 min ; personnalités lisibles ; aucune élimination en 2 h dans le modèle.

### Hypothèses ouvertes (session 2)
**H-W1 · OUVERT · Les expressions de bruit des biomes compilent et produisent des taches de ~200 tuiles.**
- Protocole : autotest (création de carte) puis carte en jeu ; ajuster `threshold`/`scale` dans `shared/content/world.lua`.

**H-F3 · OUVERT · Des unités d'une force non-ennemie exécutent les commandes de groupe (`compound`).**
- Protocole : autotest, rapport `[FO-WAR]` : attaques > 0 et pertes > 0 à 10 min.

**H-F4 · OUVERT · Les soldats humanoïdes (animations du personnage sur un prototype `unit`) s'affichent correctement.**
- Protocole : `/fo-war start` en partie normale, observer une garnison.

**H5 (reformulée) · OUVERT · Coût réel de 4 × 100 soldats + 40 ingénieurs + 50 compagnons.**
- Protocole : autotest : temps par tick du benchmark + lignes profiler `[FO-BENCH]`.

## Session 1 — 2026-10-20 : socle, spike compagnon, modèle de paliers

### Faits vérifiés (doc 1.1.91 livrée avec le jeu, `doc-html/*.json`)

| ID | Fait | Conséquence |
|---|---|---|
| F1 | Un `character` **associé** à un joueur (`associated_player`) est déconnecté avec lui en multijoueur. | Les corps de compagnons ne sont jamais associés ; propriétaire stocké dans l'agent. |
| F2 | Pathfinder partagé avec les biters : 10 nouvelles requêtes/tick, 1 000 nœuds/tick (défauts). Résultats asynchrones, `try_again_later` possible. | `PathService` avec plafond en vol, relances, tickets, timeout. |
| F3 | Une machine ne complète qu'**une recette par tick**. Vitesse tapis en virgule fixe 1/256. | Contraintes codées dans `balance_model.lua`. |
| F4 | `LuaProfiler` non sérialisable ; `on_load` sans accès à `game`. | Aucun budget piloté par le temps mesuré ; caches locaux paresseux. |
| F5 | Un seul handler par événement et par mod (`script.on_event` écrase). | Bus `Events` multi-abonnés, câblage statique. |
| F6 | `LuaEntity.mine{inventory=…}` accepte un inventaire d'entité ou un inventaire script. `LuaEntity.active = false` sort une entité de la boucle de mise à jour. | Repli pour H2 ; base de H-F1. |
| F7 | `LuaRandomGenerator` est sauvegardable, mais on lui préfère un RNG maison testable hors-jeu. | `script/core/rng.lua`. |

### Expériences menées

**E2 · VALIDÉ · Banc hors-jeu du compagnon (moteur simulé, `tests/run.lua`, 114 tests au vert)**
- Monde H1 vraie, 60 compagnons, 3 600 ticks, mode lazy : efficacité de déplacement **0,94**, 480+ arrivées, verdict « H1 confirmée » correct.
- Monde H1 fausse, mode lazy : efficacité **0,03**, verdict « H1 rejetée » correct. Puis mode every k=1 : efficacité **0,94**.
- Correction de prévision : en H1 fausse, la prévision était 1/k ≈ 0,25. La mesure donne ≈ 0, car en lazy la direction change trop rarement pour relancer la marche. Le discriminant est donc encore plus net que prévu.
- Également validés : déterminisme (état global identique sur deux exécutions), sérialisabilité de `global` (aucune fonction), reprise après sauvegarde/rechargement, comportement « follow », nettoyage complet (agents, voies, rendus), résultats de chemin périmés ignorés.
- Limite : le moteur simulé n'a ni obstacles ni coût réel. Ce banc valide la **logique**, pas les performances ni le comportement réel du moteur.

**E1 · REJETÉ puis remplacé · Ordonnanceur v1 « curseur round-robin »**
- Énoncé : un curseur parcourant une liste, n/P éléments par tick, retrait par échange avec le dernier élément.
- Résultat : sous rotation (3 % de retraits, 2 % de retraits d'autres ids, 3 % d'ajouts par passage) → doubles passages dans un même tick et attentes jusqu'à **12 ticks pour P = 7** et **73 pour P = 60**.
- Causes : (1) l'échange avec le dernier élément le fait passer devant les autres en attente ; (2) le débit n/P baisse quand on retire des éléments déjà traités, sans réduire le travail restant du cycle ; (3) un ajout après le retour en début de liste se place derrière des éléments déjà vus dans le tick.
- Remplacement : **roue de périodes** (créneau fixe par id). Résultat sur P ∈ {1, 3, 7, 60} × 5 graines : 0 double passage, attente max ≤ P, **période exacte** entre deux passages.

### Hypothèses ouvertes (priorité décroissante)

**H1 · OUVERT · `walking_state` persiste d'un tick à l'autre pour un character sans joueur.**
- Enjeu : ×3 sur le coût de locomotion (k = 4 contre k = 1) et donc sur le plafond de compagnons (≈ 430 contre ≈ 145 pour 0,3 ms).
- Protocole (en jeu, 5 min) : `/fo-bench spawn 20` → attendre 2 min → `/fo-bench report`. Le rapport donne le verdict automatiquement (seuil 0,6).

**H0 · OUVERT · Un `character` sans joueur reste pleinement simulé** (marche, PV, dégâts, régénération).
- Protocole : observer les compagnons du test H1 ; en frapper un (arme) et vérifier PV et mort (le registre doit le retirer, voir `report`).

**H5 · OUVERT · Coût par compagnon : c_cerveau ≈ 15 µs, c_pilotage ≈ 3 µs.**
- Protocole : `/fo-bench prof on`, `/fo-bench reset`, puis paliers N = 50, 200, 500. À chaque palier, `report` après 60 s, et F4 → `show-time-usage` (lignes *Script update*, *Path finder*). Ensuite, test UPS reproductible : sauvegarder la partie avec N compagnons, puis
  `bin\x64\factorio.exe --benchmark "<chemin complet>\saves\fo-bench-500.zip" --benchmark-ticks 3600 --benchmark-runs 3 --disable-audio`.
- Critère : en déduire N_max pour 0,3 ms et mettre à jour ARCHITECTURE §4.

**H4 · OUVERT · Une marge de 0,15 tuile sur la bbox de pathfinding réduit les blocages** (le suivi 8 directions coupe les coins).
- Protocole A/B : zone boisée, 50 compagnons, `PATH_BBOX_PAD` = 0 puis 0,15 puis 0,3 ; comparer `blocages / arrivées`.

**H2 · OUVERT · Minage par un character sans joueur** via `update_selected_entity` + `mining_state`.
- Repli si échec : minage scripté (minuterie = temps de minage / vitesse, puis `LuaEntity.mine{inventory = inventaire du corps}` ; pour les minerais, décrément de `amount` et insertion).

**H3 · OUVERT · Fabrication via `begin_crafting` sur un character sans joueur.**
- Repli : fabrication scriptée (retrait des ingrédients, minuterie, insertion des produits). Plus simple et plus déterministe : c'est le choix par défaut si H3 pose le moindre problème.

**H-B1 · OUVERT · Plafond souple des tapis à 0,25 tile/tick (120 items/s).**
- Protocole : prototypes de test à 0,25 et 0,5 ; mesurer le débit réel des bras (prise sur tapis) et des chargeurs ; repérer les pertes de prise.

**H-F1 · OUVERT · Bâtiments de faction inactifs (`active = false`) + registre comptable ≈ coût UPS nul.**
- Protocole : 2 000 assembleurs actifs contre inactifs ; comparer *Entity update* (F4) et le benchmark.

**H-F2 · OUVERT · Les groupes d'unités échouent sur les longs trajets** (> 200 tuiles) sans étapes intermédiaires.
- Protocole : 10 groupes de 20 unités, cibles à 100, 300 et 600 tuiles ; mesurer le taux d'échec (`on_ai_command_completed`) avec et sans planificateur par chunk.
