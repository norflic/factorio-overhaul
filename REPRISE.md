# REPRISE : état du projet pour l'orchestrateur suivant

> **À lire en premier** par tout agent qui reprend la gestion du projet. Les fichiers de référence sont
> les suivants :
> - `OBJECTIFS.md` : le contrat, avec les citations du Directeur Créatif, les critères et le suivi des
>   lots au §7 ;
> - `CLAUDE.md` : les règles, les commandes et les interdits ;
> - `RD_LOG.md` : les preuves.
>
> Ce fichier dit OÙ on en est, CE QUI TOURNE et QUOI FAIRE ENSUITE. Ne recommence rien de ce qui est
> marqué fait.
>
> **27/10, 15 h 25 : `main` = 0.6.3** (PERF, AUTO, CAPITAL par fast-forward de `valid063`, conflit cerveau.lua résolu ; réglages
> fo-war-ia3e et fo-war-capital ÉTEINTS ; décisions identiques à 0.6.0 ; K10 seul 0,379 ms, p99 5,48). Reste de l'atelier : SCALE
> (en correction). Puis : brancher CAPI (après SCALE), lot de performance suivant (A* étalé, pensée découpée, boucle du PNJ refusé),
> TIRS (en correction). Worktrees perf, auto, capital, valid063 à retirer quand l'atelier sera fini.
>
> **27/10, 14 h 20 : CAPI FUSIONNÉ (règle pure, rien en jeu)** : `shared/ai3/capitalisation.lua`, test 151 OK, `docs/IA_CAPITALISATION.md` ;
> livraison `fo-logs\2026-10-27_CAPI\INTEGRATION.md` (plan de branchement en 10 étapes §5, critères C1 à C9, `RESUME_DC.md`). Q-CAPI-1
> tranchée par l'intégrateur d'après le DC (12 h 30) : couverture complète du gisement sans plafond « 2 × le besoin ». À FAIRE après la
> fusion de SCALE, AUTO et CAPITAL : brancher (préalable : gisements comptés en entier, pas à 64 tuiles), étaler le coût, prouver en jeu
> avec l'image d'une base (critères de l'OBJECTIFS §4, 12 h 30). Worktree `capi` retiré.
>
> **27/10, 13 h 50 : `main` = 0.6.2** (foreuse aux 15 âges EN JEU, `8217fb0`, provisoire ; ronde 2 du centre en outils, `ba6c9ac` ;
> sur main : harness 0, feuilles foreuse 580, levels 1667, api_lint 1260, f4-foreuses 7 OK, content 331 ; agent design TERMINÉ,
> worktrees design retirés). **Workflow `tirs-par-age` LANCÉ** (`wf_91cd3f5e-b4a`, worktree `tirs`, `fo-logs\2026-10-27_TIRS`,
> F357 à F360, E238 à E240) : demande du DC (tirs et sons des tourelles à la mesure de l'âge). Essai 3D par IA fini : rester en
> procédural ; Meshy à la décision du DC. Workflows en cours : `ia-fin-cerveau` (PERF, SCALE, AUTO, CAPITAL), `capitalisation-pnj`,
> `tirs-par-age`. Banc à 3 places.
>
> **27/10, 12 h 10 : CAPITALISATION** (le DC, 12 h 05 : « Le scaling des IA est aussi et surtout dans la maximisation des gisements,
> de la fonte et des crafts […] c'est le concept de capitalisation qu'il faut implémenter » ; « Et concernant la recherche IA ? »).
> Workflow `capitalisation-pnj` (relancé à 12 h 15 avec la précision du DC « plus de gisements, plus de fours dans la limite de ce qu'on peut faire fondre, si assembleurs disponibles des chaînes de production » : run `wf_181b9d75-fba` ; le premier run `wf_6987f189-654` est arrêté, hors jeu, worktree `capi`, livraison `fo-logs\2026-10-27_CAPI\INTEGRATION.md`
> et `RESUME_DC.md`) : règle pure + test + doc, PLAN DE BRANCHEMENT à appliquer après la fusion de SCALE et AUTO, puis preuve en
> moteur réel (capacité qui croît, inactifs ≤ 20 % à 30 PNJ, 30 contre 10 ≥ 1,2, paliers de recherche, laboratoires qui grandissent).
>
> **27/10, 11 h 40 : WORKFLOW `ia-fin-cerveau` LANCÉ** (le DC : « ultracode si nécessaire » ; run `wf_7e757943-a80` ; NE JAMAIS écrire par
> SendMessage à ses agents) : 4 lots en parallèle, chacun suivi d'un critique adverse et d'un correcteur si défaut majeur ; worktrees
> `.claude/worktrees/perf`, `scale`, `auto`, `capital` (branches du même nom, partis de main 0.6.1 `2d6cb75`, feuilles copiées) ;
> livraisons `fo-logs\2026-10-27_PERF`, `_SCALE`, `_AUTO`, `_CAPITAL` ; bancs `--qui PERF|SCALE|AUTO|CAPITAL`. À l'arrivée : fusionner
> lot par lot (conflits attendus sur shared/ai3/general.lua, buts.lua, cerveau.lua), rejouer la validation complète sur main (comme
> `valid060`), K10 `--seul`. Recherche 3D par IA FAITE (`fo-logs\2026-10-27_3D-IA\RAPPORT.md`) : essai à décider par le DC.
>
> **27/10, 11 h 30 : IA3-e FUSIONNÉ, `main` = 0.6.1**, réglage `fo-war-ia3e` ÉTEINT (décisions identiques à 0.6.0) ; worktree `ia3e`
> gardé pour la suite (rallumer : lot des foreuses, K1, règles dans le cerveau général). Restent : IA3-d (+ P1), design F4-B et F5-A2,
> recherche 3D par IA (agent lancé, rapport `fo-logs\2026-10-27_3D-IA\RAPPORT.md`), lot de performance (K10 0,441 ms), bilan au DC.
>
> **27/10, 11 h 15 : 0.6.0 VALIDÉE sur `main`** (garde-fous verts, `ia1b2-guide` 1618033988 réparé ; `iag_test` 93 OK après
> admission des types du moteur d'IA3-k). **K10 NON tenu : 0,441 ms par tick, p99 6,6 ms, mesuré seul** (0,291 en 0.5.0) : lot de
> performance à ouvrir (profileur par composant : itinéraires d'IA3-k, catalogue d'IA-G étalé). Les points 1 de la reprise de 10 h 45
> sont faits ; restent 2 à 6. Agents IA3-e et design arrêtés par la limite d'usage à 10 h 45, à relancer par SendMessage.
>
> **27/10, 10 h 45 : POINT DE REPRISE (limite d'usage de la session atteinte).** `main` = **0.6.0** (`4424be0`, documents `2427c2b`,
> `c99d2fe`) : IA-V2 + correctif 0.5.2 (`7236ffa`), IA3-k 0.5.1, IA-G 0.6.0. **À FAIRE EN PREMIER** :
> 1. Lire la validation de 0.6.0 : `fo-logs\2026-10-27_integration-0.6.0\series.txt` et `bilans.txt` (« FINI » quand tout est passé :
>    verif-guide 271828182 et 1618033988, content, pnj-reduit, ia1b2-guide 1618033988, iag-partie × 2, ia3k-route, iag-jetable sur
>    `jetable-src`, puis K10 `--seul` ia1-scale) ; instantané testé : worktree `.claude/worktrees/valid060` (branche `valid060`) ;
>    série hors jeu : `<scratchpad>\serie_valid060\bilan.txt`. Consigner dans RD_LOG (E199, E220 à E223) et OBJECTIFS ; un échec se
>    corrige en avant sur `main`. Retirer ensuite `valid060`.
> 2. IA3-e (agent `aa204fd5af007dd61`) : `git merge main` 0.6.0 dans `ia3e`, conflits sur le cerveau, réglage `fo-war-ia3e` ÉTEINT ;
>    rapport attendu vers 12 h ; fusionner s'il est vert réglage éteint.
> 3. IA3-d (branche `ia3d`, agent terminé) : fusionner `main` dedans, puis P1 (`fo-war-workers` 4 → 30) avec verif-guide sur 4 graines.
> 4. Design (agent `af602e63c702fb3b4`) : F4-B (foreuse en jeu) et F5-A2 (centre) en cours ; fusion de F4-B après mémoire vidéo au plancher.
> 5. Banc : `fo-banc-places.txt` = 3 (le DC n'utilise pas le PC jusque vers 17 h) ; le remettre à 1 quand il joue.
> 6. Bilan au DC de l'échéance de 12 h 10 (« cerveau des IA fini ») : franc ; non tenus connus : palier 2, inactifs à 30 PNJ (45 %),
>    automatisation éteinte par défaut, buts d'amélioration des niveaux absents (D-20 (3)), A8 et A9 non commencés.
> Page du DC : https://claude.ai/artifact/617hK5AkCWh1vu7HCzViU5 (à mettre à jour avec 0.5.1, 0.5.2, 0.6.0 et X3).
>
> **27/10, 10 h 35 : IA3-k FUSIONNÉ, `main` = 0.5.1** (`cd36d4b`) : comportements visibles allumés (`fo-war-ia3-comportement`).
> Preuve du lot sur main 0.5.0 + lot (C2 24/24 et 14/14 sans mort, C5 1 mort contre 27 et 48, C3 7 OK, B5 et C4, D1) ; fusion
> propre, main depuis la base du lot : outils, X3 (non lu par le jeu) et documents seulement. Sur `main` 0.5.1 (intégrateur) : série
> hors jeu, content, verif-guide 271828182 et 1618033988 lancés. Fusions d'essai : main + ia3k + iag PROPRE ; + ia3e : conflits
> settings.lua et tests/mock_engine.lua seulement. Défauts ouverts : économie d'une faction sans soldat sous un nid ; C1 allongement ;
> K10 (mesure `--seul` de l'intégrateur sur main après les fusions). Worktree `ia3k` gardé tant que l'agent tourne.
>
> **27/10, 10 h 40 : IA3-e LIVRÉ (2e fois), réglage `fo-war-ia3e` ÉTEINT par défaut** (tête `d52a2d0` ; INTEGRATION.md §0 bis) :
> éteint, automatisation et plan des factions inertes (verif-guide 1618033988 15 OK, content 331) ; allumé : aucune fonderie posée
> (lot des foreuses introuvable : « tapis des foreuses (pas de lot) », « (trop long) »), K1 instable (une faction différente recule
> à chaque correction). Fusion main + ia3e : PROPRE ; main + ia3e + iag : CONFLITS dans script/ai3/cerveau.lua, shared/ai3/buts.lua,
> shared/ai3/cerveau.lua, shared/ai3/projets.lua, tests/mock_engine.lua. **Ordre décidé** : IA-G d'abord dans `main` (vers 11 h 15),
> puis l'agent IA3-e (`aa204fd5af007dd61`) fait `git merge main` dans `ia3e`, résout en gardant le cerveau d'IA-G et en branchant
> `A.decide*` à son point de jonction, rejoue hors jeu + verif-guide + content réglage éteint ; fusion ensuite.
>
> **27/10, 10 h 15 : X3 FUSIONNÉ (proposition hors jeu, `f76af76`, `0f78e4f`) et D-20 du DC** (QCM) : fonderie de puces OBLIGATOIRE
> à l'âge 10 ; gamme de robots à concevoir « style Supreme Commander 2 » ; une partie des niveaux en pièces montées, que le cerveau
> des PNJ doit faire DE LUI-MÊME (rien en dur) ; calcul NON stockable, par script. À reporter dans `shared/content/x3.lua` et §3.7 au
> lot de mise en jeu (X3-0…), après la priorité IA. Worktree `x3` à retirer (refusé : dossier courant de la session).
>
> **27/10, 9 h 55 : IA3-e LIVRÉ, NON FUSIONNÉ** (tête `d7e8a7d` = main 0.5.0 + lot ; `fo-logs\2026-10-27_IA3-e\INTEGRATION.md`) :
> règle « main ou machine » pour TOUT objet (module généré depuis la recette), ordre tiré de la profondeur du graphe, interface
> pure pour IA-G (§0) ; verif-guide 15 OK × 2, content 331, ia1-build-plaine 12, K11, K10 0,157 ms en `--seul`. **Refusé en
> l'état** : sur la tête, AUCUN module de production seul à 45 min (fonderie posée loin du gisement, quai de minerai vide), part à
> la main 93 à 100 %, **K1 RECULE** (amber 42 min → jamais). Agent relancé (correctifs : fonderie au gisement, cause du recul de
> K1, réglage de carte `fo-war-ia3e` allumé seulement si tenu) ; livraison vers 11 h 10. IA-G : gel vers 11 h, rapport, point
> de jonction avec `A.decide*`. **Plan jusqu'à 12 h 15** : fusion IA-G puis IA3-e vers 11 h 15, preuve commune sur 3 places ;
> IA3-d (avec P1) et IA3-k ensuite. Garde-fous d'IA-V2 revenus sur 0.5.0 : verif-guide 577215664 15 OK (13 avant), brouillard
> 10 OK, réduite 1618033988 5 OK, ia1-poles 15 OK 2 ECHEC (défaut ouvert depuis 0.4.29, inchangé) ; restent verif-guide
> 1618033988 et ia1b2-guide.
>
> **27/10, 9 h 05 : BANC À 3 PLACES DÉPLOYÉ** (fusion `cf7053b` de `banc2`, agent terminé ; `fo-autotest.bat` recopié à la racine,
> l'ancien gardé dans `fo-logs\fo-autotest.bat.avant-banc2`) ; `<racine>\fo-banc-places.txt` = **3** (REMETTRE 1 quand le DC joue).
> Tests : test_banc_file 78 OK, bat_double_source 70 OK (rejoués par l'intégrateur). Moteur réel : `content` 331 OK à la place 2
> (14 s, sans attente) pendant la session d'images d'IA3-e à la place 1 (`fo-logs\2026-10-27_integration-0.5.0\content`). Les
> tickets déposés par des banc.py ANCIENS (avant 9 h 03) ne passent que par la place 1 : agents priés de les relancer. Toute
> mesure K10 avec `--seul` ; les mesures K10 prises avant ce déploiement pendant d'autres bancs sont à refaire seules.
>
> **27/10, 8 h 55 : PC LIBRE 8 h ET BANC À PLUSIEURS PLACES.** Le DC, vers 8 h 50 : « Vous pouvez potentiellement accélérer le jeu
> beaucoup plus pour 1 partie à la fois […] (Et au pire ça ram mais c'est pas grave si ?) », puis vers 8 h 55 : « Je n'utilise pas
> mon pc pour les 8 prochaines heures donc vous pouvez y aller (sans faire planter le pc quand même mais vous avez compris) ».
> Mesure : un banc tourne déjà sans limite de vitesse (`ia3-fer-joueur`, 54 000 ticks : copie 2 s, création 5 s, simulation 9 s,
> archivage 4 s, ATTENTE en file 965 s) : le frein est la file. Agent BANC2 lancé (worktree `banc2`) : `FO_PLACE` 1 à 3 dans
> `fo-autotest.bat` (dossiers `fo-autotest`, `-2`, `-3` ; verrous `.lock`, `-2.lock`, `-3.lock`), banc.py à N places lues dans
> `<racine>\fo-banc-places.txt` (défaut 2), tickets exclusifs (`--captures`, `--visuel`, `--son`, `--seul` pour toute mesure K10),
> place supplémentaire seulement avec 6 Go libres. Déploiement par l'intégrateur après relecture ; l'interdit n° 4 de CLAUDE.md
> sera réécrit à ce moment. Disque F: 154,6 Go libres, C: 12,9 Go (à surveiller).
>
> **27/10, 8 h 40 : IA-V2 FUSIONNÉ, `main` = 0.5.0** (`6c631d5`) : le nouveau cerveau (marché IA3-b, cerveau par besoins IA3-c,
> exploration IA3-f) ALLUMÉ par défaut. Hors jeu sur la fusion (worktree `integ`, retiré ensuite) : 32 tests verts, harness 0,
> api_lint 1179, pvp 1305. Moteur réel sur la branche (même code) : content 331, verif-guide 15 OK × 2 graines, cas du DC, migration
> 12 OK, K11 ; NON tenus : K1, K5, K10 (0,291 ms), B1 à 30 PNJ. **6 garde-fous en jeu encore en file** sous `--qui IA-V2` (série
> `travaux-final-a.txt`, `-b.txt` du dossier `fo-logs\2026-10-27_IA-V2\`, relançable par `./serie.sh` ; ce qui est fait est sauté) :
> pnj-reduit, ia1-poles, ia3-brouillard, ia1b2-guide, verif-guide 1618033988 et 577215664 : À CONSIGNER (E199) à leur retour ;
> un échec se corrige en avant sur `main`. **Prévenus de faire `git merge main`** : IA-G, IA3-e, IA3-k ; IA3-d (agent terminé) :
> l'intégrateur fusionne `main` dans `ia3d` à sa fusion. Worktree `ia-v2` GARDÉ tant que la série de l'agent tourne.
>
> **27/10, 8 h 05 : WORKFLOW X3 LANCÉ à la demande du DC** (« lancer un workflow pour avoir d'autres minerais […] tel minerai à
> telle époque […] des processeurs […] technologies laser […] impressions […] cartes graphiques […] calcul […] robots de défense »,
> OBJECTIFS §4) : run `wf_75a10ea1-27c` (8 agents, HORS JEU, aucun banc ni Blender), worktree `.claude/worktrees/x3` (branche `x3`
> partie de `main` e2930ad) ; données pures NOUVELLES `shared/content/x3.lua` + `tests/x3_test.lua` + §3.7 de SCENARIO_EPOQUES ;
> epochs.lua NON modifié (il est lu par le jeu : niveaux, titane, garantie) ; livrables `fo-logs\2026-10-27_X3\INTEGRATION.md` et
> `RESUME_DC.md` ; F337 à F340, E224 à E226 (prochains libres F341, E227). Ne JAMAIS écrire par SendMessage à un agent de ce
> workflow (doublon). Mise en jeu après la priorité IA. **D-19 (8 h 25, validé par le DC)** : le calcul comme l'électricité
> (centre de calcul qui consomme courant et refroidissement) : vérifier à la livraison de X3 que la synthèse le respecte.
>
> **27/10, 7 h 50 : le DC demande de refaire QUELQUES âges de l'assembleur** (OBJECTIFS §4, mot pour mot) : 15 très réussi,
> 14 « partiellement » (un élément décentré), d'autres très basiques malgré l'âge ; « le gameplay fonctionnel avec les IA reste
> la priorité ». Lot **F3-C** mis à la FIN de la file du design (après F4-B et F5-A2) ; âges à refaire, lecture provisoire de
> l'intégrateur : 4, 9, 10, 11, et la correction du 14. **ANNULÉ vers 8 h par le DC** (« les assemblages sont bons finalement […]
> j'avais regardé les ancienne ») : rien à refaire, design prévenu. Une boucle de vérification toutes les 10 min est armée (CronCreate
> `5d7f4995`, session seulement) : avancement des branches, file du banc, noms du jeu dans le code de décision.
>
> **27/10, 7 h 15 : CONSIGNE DU DC (réveillé, contrôle à distance) : le cerveau des IA FINI en 5 h, et un cerveau qui
> GÉNÉRALISE** (« si ils font des chemins en dur […] dans le code, ça risque pas de le faire […] un véritable cerveau quelqu'un
> qui généralise », OBJECTIFS §4). Constat vérifié : décisions des factions sur l'échelle écrite à la main (`T.ladder`,
> `T.research`, avant-postes iron, copper, coal de `shared/team/planner.lua`) ; `shared/ai3/graphe.lua` (dépliage générique,
> IA3_CERVEAU §3) JAMAIS branché. **Lot IA-G LANCÉ** (agent `a53268fe1401a6fb1`, branche `iag`, worktree
> `.claude/worktrees/iag`, base ia-v2 `c826b48` + `main` = `9efc142`, feuilles copiées ; notes `fo-logs\2026-10-27_IA-G\` ;
> F331 à F336, E220 à E223, prochains libres F337, E224 ; bancs `--qui IA-G`) : catalogue depuis les prototypes, choix des
> recherches par leur valeur, dépliage branché vers les exécutants (tableau, plan d'IA1-d, exploration), échelle remplacée,
> test anti-noms ; preuve de GÉNÉRALISATION exigée (copie jetable du mod aux données changées, même code). Échéance vers
> 12 h 15. Messages : IA-V2 livre vite sans chantier neuf (il a corrigé traits et valeur en `c826b48`) ; IA3-e généralise
> « main ou machine » à tout objet et garde une interface pure pour IA-G ; IA3-k sans seuils ni positions en dur.
> Ordre des fusions : IA-V2, puis IA-G et IA3-e, puis IA3-d (avec P1), puis IA3-k.
>
> **27/10, 7 h 40 : IA3-d LIVRÉ, NON FUSIONNÉ (attend IA-V2)** : branche `ia3d` (tête `d97181c`, contient ia-v2 `4e0388b` et
> `main` 0.4.32), worktree `.claude/worktrees/ia3d` GARDÉ ; agent terminé (`af7c16550a493a161`). Notes
> `fo-logs\2026-10-27_IA3-d\NOTES.md`, `INTEGRATION.md` (brouillons F315 à F318, E210, E211, OBJECTIFS, changelog, CLAUDE.md).
> Règle d'effectif des factions `shared/ai3/effectif.lua` : recrue quand du travail attend 2 min au-delà des bras libres et
> que la recrue se paie ; prouvée par une charge injectée (`ia3d-charge` 13 OK : 8 → 14 et 8 → 10). **Croissance NON obtenue en
> partie de 2 h** (`ia3d-croissance` 7 OK 2 ECHEC) : sous le cerveau d'ia-v2, 28 à 58 % des PNJ sans tâche, aucun travail
> n'attend 2 min ; 30 contre 10 = 1,09. Cause : le travail engendré par le cerveau (IA-V2, IA3-e), pas le recrutement ;
> transmis à IA-V2 (B1) et à IA3-e le 27/10 vers 7 h 35. **À FAIRE À SA FUSION** (après IA-V2 et IA3-e) : `git merge main`
> dans `ia3d`, série hors jeu, `ia3d-charge`, `verif-guide` sur 4 graines, et **P1 : défaut de `fo-war-workers` 4 → 30**
> (D-14 « 30 dès l'époque 1 » ; aujourd'hui une faction part à min(8, 4) = 4 = son plafond et ne grandit jamais, F315) ;
> rejouer `verif-guide` AVEC P1 (factions à 8 au départ : tempo contre le joueur, K9) ; P2 textes des réglages
> `fo-recruit-idle-max` et `fo-war-workers`. Défauts déclarés : part de PNJ sans tâche visible en hausse (les recrues de
> l'ancien frein la cachaient), cuivre −46 à −49 % non expliqué, `war_test` modifié (105 OK). **Vérifié par l'intégrateur :
> `traits_test` 64 OK 1 ECHEC et `valeur_test` 50 OK 1 ECHEC sur ia-v2 `948888e`** (verts sur `main`) : bloquants pour IA-V2,
> signalés à IA-V2.
>
> **27/10, 7 h 15 : DESIGN. Kits de la foreuse et du centre FUSIONNÉS dans `main`** (outils seulement, aucune version montée,
> rien en jeu, aucun design validé) : `859cfab` (foreuse_e, rondes F4-A à F4-A3 : charte moyenne 28,7, âges 10 et 12 sous 25,
> âges 12 et 14 sous 70 % de la mitrailleuse, âge 1 noir de nuit) et `d5cf09d` (centre_e, ronde 1 : 15 silhouettes, grands étages
> « mouchetés », mâts trop petits). Sur `main` : test_foreuse 149 OK, test_centre 81 OK, test_assembleur 217, test_four 179.
> RD_LOG : F260 à F262, F309 à F313, E93 à E96, E206 à E209 ; OBJECTIFS §7 : lignes F4 et F5. Planches :
> `fo-logs\2026-10-25_F4\planches_DC_A3\`, `fo-logs\2026-10-27_F5\planches_DC\`. **Design RELANCÉ** (même agent
> `af602e63c702fb3b4`, par SendMessage) : F4-A4 (âges 14, 12, 10, nuit de l'âge 1, poses S et O ; worktree
> `agent-a235f8f5537d5ec4f`), puis **F4-B : la foreuse EN JEU, décidée PROVISOIREMENT par l'intégrateur** (délégation du 22/10 ;
> direction du DC « Oui, enrichir nettement », pas de verdict sur les planches : réversible), mémoire vidéo au PLANCHER d'abord
> (F186) ; pendant les rendus, F5-A2 (centre, ronde 2, worktree `f5a`). Réservés : F4-A4 et F4-B F324 à F327, E215 à E217 ;
> F5-A2 F328 à F330, E218, E219 ; **prochains libres F331, E220**. Bancs du design : `--qui F4-B`.
>
> **27/10, 4 h 30 : IA1-d FUSIONNÉ, `main` = 0.4.32** (`d414f34`, version et changelog `4197173`) : plan directeur et
> construction par fantômes (`script/team/build.lua`, `shared/team/plan.lua`), NEUTRE tant qu'aucun cerveau ne l'appelle ;
> 5 terrains `ia1-build-*` 12 OK sur la branche ; F292 à F295, E195 à E197. Bancs sur `main` par la file : ia1-build-plaine
> 12 OK (4:23:41), content 331 OK (4:29:59), pvp 1305 ; archives `fo-logs\2026-10-27_integration-0.4.32\`. Proposition d'appel pour IA3-e : `fo-logs\2026-10-25_IA1-d\INTEGRATION.md` §6.
> **IA3-e LANCÉ à 4 h 45** (A4, « ils craftent beaucoup à la main ») : branche `ia3e`, worktree `.claude/worktrees/ia3e`, base
> `d427633` = tête d'`ia-v2` + `main` 0.4.32 (conflit unique `team.lua` résolu par l'intégrateur : `Build.think` puis
> `Board.assign`) ; notes `fo-logs\2026-10-27_IA3-e\` ; F319 à F323, E212 à E214 (prochains libres F324, E215). Phase 1 hors
> jeu (règle pure `shared/ai3/automatiser.lua`, branchement au cerveau), phase 2 par la file. **À la fusion d'IA-V2 : prévenir
> IA3-e, IA3-d et IA3-k de faire `git merge main`** (essais à blanc : ia-v2 + main = 1 conflit, `team.lua` ; ia-v2 + ia3k =
> 3 conflits, `worker.lua`, `settings.lua`, `tests/mock_engine.lua`). IA-V2 a été prié de fusionner `main` 0.4.32 AVANT sa
> série finale. Worktree IA1-d (`agent-a39bad97…`) retiré.
>
> **27/10, 4 h : FILE DU BANC À TOUR DE RÔLE, IA3-d LANCÉ.**
> - `banc.py` (`dc343d5`) sert désormais les lots à tour de rôle (étiquette `--qui`), puis premier arrivé, premier servi dans un
>   lot. Pourquoi : à 3 h 35, IA1-d a déposé 14 bancs d'un coup, et les bancs du cas du DC d'IA-V2 attendaient derrière (environ
>   1 h). Contrôle : `tools/autotest/tests/test_banc_file.py` 13 OK. Les lanceurs DÉJÀ en attente gardent l'ancienne règle
>   (code chargé au départ) ; les trois agents IA ont été priés d'appeler le banc.py de main par son chemin absolu et de garder
>   au plus 4 bancs en file.
> - **IA3-d** (A7, « ils ne scalent pas ») : branche `ia3d`, worktree `.claude/worktrees/ia3d`, créée sur la tête d'`ia-v2`
>   (`0302af1`) ; notes `fo-logs\2026-10-27_IA3-d\` ; F315 à F318, E210, E211 (prochains libres F319, E212). Phase 1 HORS JEU
>   (diagnostic sur les archives d'IA1-b, règle pure `shared/ai3/effectif.lua`, tests) ; phase 2 par la file, au plus 3
>   bancs en file. À relancer s'il s'arrête faute de banc.
> - Worktrees retirés (fusionnés dans `main`) : F3-B (`agent-ad00d688…`) et `agent-aa8c5e5b…` (documents 0.4.30).
>
> **27/10, 2 h 40 : F3-B FUSIONNÉ, `main` = 0.4.31** (`91f07a2` : assembleur en jeu, feuilles par
> `assembleur_e/feuilles.py`, F306 à F308, E204, E205 ; `banc.py` accepte `--visuel "--…"`, F307). Bancs sur `main` par la file :
> archives `fo-logs\2026-10-27_integration-0.4.31\`. **Design relancé** (même agent, `af602e63c702fb3b4`) : F4-A3 (foreuse,
> 3e ronde, branche `worktree-agent-a235f8f5537d5ec4f`, cible « visible au zoom 1 », F309-F311, E206-E207, planches dans
> `fo-logs\2026-10-25_F4\planches_DC_A3\`), puis F5-A (centre, ronde 1, worktree `.claude/worktrees/f5a` branche `f5a`,
> F312-F314, E208-E209, `fo-logs\2026-10-27_F5\`). **Page de suivi pour le téléphone du DC** :
> https://claude.ai/artifact/617hK5AkCWh1vu7HCzViU5 (source : `chantier.html` + `img/` dans le scratchpad de la session
> `bf870ee5` ; à republier à chaque lot fusionné). La liste IA_ATTENDUS compte **22** comportements (A1-A9, B1-B5, C1-C7,
> D1), pas 24 comme dit au DC à 1 h 50.
>
> **27/10, 1 h 45 : REPRISE APRÈS LA COUPURE HEBDOMADAIRE (orchestrateur, session `bf870ee5`, lancée par une macro de nuit ;
> le DC dort et ne répond pas).**
> - **Le projet vit sur F:** (`F:\Factorio.v1.1.91 Modding\…`, exFAT, 211 Go libres) : le DC a tout copié le 26/10 vers 21 h 15,
>   H: étant plein (471 Mo). H: est figée (commit `88f3ca4`, parties du DC du 26/10) : NE RIEN Y ÉCRIRE. Outils repointés vers F:
>   (`b2237de`), worktrees réparés à la main, `safe.directory` global, verrous orphelins de F: retirés. `content` 331 OK depuis F:.
> - **File d'attente du banc** (`d80fd8d`) : `tools/autotest/banc.py` pour TOUS les agents (CLAUDE.md §4, interdit 4).
> - **Demande du DC (26/10, OBJECTIFS §5, 1re ligne)** : « toute la partie cerveau à refaire » (pas d'automatisation, craft à la
>   main, pas de vraie recherche, trajets prévisibles, aucune réaction à un ennemi vu, ni peur ni agressivité, agents inactifs,
>   milices inactives, ne « scalent » pas), designs en parallèle. Liste demandée écrite : **`docs/IA_ATTENDUS.md`** (A, B, C, D).
>   Journal de sa partie (0.4.30, ANCIEN cerveau) : Écarlate a perdu 26 PNJ en 41 min au même endroit (87 à 103 tuiles, « service »).
> - **AGENTS LANCÉS vers 1 h 40** (chacun : NOTES.md avec POINT DE REPRISE dans son dossier fo-logs ; s'il est coupé, nouvel agent
>   avec le même brief, en lisant ses NOTES et le dernier commit de sa branche) :
>   - **IA-V2** : branche `ia-v2` (worktree `.claude/worktrees/ia-v2`), fusion d'IA3-b, IA3-f, IA3-c (IA3-a en repli), allumés par
>     défaut, cas du DC, série avant/après 4 graines, garde-fous ; `fo-logs\2026-10-27_IA-V2\` ; F296-F299, E198-E199 ; vise 0.5.0 ;
>   - **IA1-d** : sa branche `worktree-agent-a39bad97bdb746bc4`, centrale refusée à corriger, 5 terrains, garde-fous, proposition
>     pour IA3-e ; `fo-logs\2026-10-25_IA1-d\` ; F292-F295, E195-E197 ;
>   - **IA3-k (nouveau)** : branche `ia3k` (worktree `.claude/worktrees/ia3k`), famille C d'IA_ATTENDUS (carte du danger, trajets
>     variés et qui évitent, réaction à un ennemi vu, mémoire des morts, peur, agressivité, soldats occupés, états visibles) ;
>     `fo-logs\2026-10-27_IA3-k\` ; F300-F305, E200-E203 ;
>   - **Design** : F3-B (assembleur : fin de production, feuilles, mémoire vidéo au plancher, bancs, captures ; vise 0.4.31 ;
>     F306-F308, E204-E205) puis F4-A2 (foreuse enrichie : fin des rendus, planches pour le DC).
> - ENSUITE (après IA-V2) : IA3-e (automatiser, avec IA1-d), IA3-d (effectif qui grandit : « ils ne scalent pas »), IA3-g, IA3-h.
>   Designs ensuite : F5 (centre), F6 (mur), X2-suite, A5-suite, F1-C.
> **20 h 40, F3-B (assembleur en production) arrêté proprement** (branche `worktree-agent-ad00d688396c75623`, dernier commit
> `b15db4a` ; elle contient `main` 0.4.29 ET la branche du four F2-B, qui se dit 0.4.30 : fusionner F2-B AVANT F3-B) : production
> 21 variantes sur 29 (le paquet 6 a continué seul ; reprendre par `rendre.py --only` sur les variantes absentes, commande dans
> `fo-logs\2026-10-25_F3\NOTES.md`) ; intégration faite sur des feuilles d'ESSAI (`prototypes/levels/assembler.lua`, feuilles hors
> git par `assembleur_e/feuilles.py`, contrôle `asm_sheets.lua`, scénario `f3-assembleurs` 6 OK en moteur réel, captures de jour et
> de nuit regardées) ; animation au coût le plus bas (lueur rejouée au travail, aucune image en plus). RESTE : fin de production,
> feuilles régénérées, mémoire vidéo au plancher avec le four, content, t2-machines, mod1-modules, mod2-lots, migration 0.4.29
> (`src-0.4.29` prête), captures finales.
> **20 h 30, IA3-c arrêté proprement** (branche `worktree-agent-a4f8ddc966cf133ed`, dernier commit `ecc8348`, intégrateur `dedfd43`,
> réglage `fo-war-ia3-cerveau` éteint ; instantané à tester `fo-logs\2026-10-25_IA3-c\src-a\factorio-overhaul`) : cerveau par
> besoins écrit et branché ; HORS JEU vert (ai3_cerveau 40 OK : le cas du DC est résolu au moteur simulé ; pvp 1305 allumé et
> éteint après 5 corrections) ; AUCUN banc en moteur réel (verrou jamais obtenu en 30 min) : RESTE le cas du DC en jeu
> (`ia3c-dc-*`), la série avant / après sur 4 graines, la migration, la fenêtre, les garde-fous. **LEÇON : 5 agents IA se
> disputent UN banc ; à la reprise, ne relancer que 2 agents qui ont besoin du banc à la fois (les autres en travail hors jeu),
> ou leur donner des créneaux.**
> **20 h 15, IA3-b arrêté proprement** (branche `worktree-agent-a1c27739bad6e06fc`, dernier commit `cb0ccd5`, commit intégrateur
> `ec8cbd0` pour le réglage `fo-war-ia3-marche`, éteint par défaut) : CAS DU DC CORRIGÉ en moteur réel (scénario `ia3b-fer`) :
> 62 plaques de fer en 4,7 min (jamais avant), PNJ sans tâche pendant le manque 61,7 % → 2,0 %, 3 mineurs de fer en même temps,
> objectif charbon atteint en 5,4 min ; hors jeu ia3b 31 OK, pvp 1305 (réglage allumé et éteint). RESTE avant fusion : séries
> `ia3b-reduit` et `ia3b-default` (K3, K4, K5 après), garde-fous en moteur réel (ia1-poles, verif-guide et ia1b2-guide 4 graines,
> content, pnj-reduit, pnj-auto, ia0-normal, ia1-scale, coût, déterminisme) ; notes `fo-logs\2026-10-25_IA3-b\NOTES.md`.
> **POINT DE 19 H 10, AVANT LA COUPURE HEBDOMADAIRE** : état identique au point de 18 h 50 ci-dessous (rien de fusionné depuis ;
> `main` = 0.4.29). Les 8 agents ont été coupés à 18 h 55, relancés vers 19 h, puis priés de commiter et de mettre à jour leur
> POINT DE REPRISE. À la reprise : pour chaque lot (IA3-a, IA3-b, IA3-c, IA3-f, IA1-d, F2-B, F3-B, F4-A2), lire le dernier commit de
> sa branche `worktree-agent-…` (`git worktree list`) et le POINT DE REPRISE de `fo-logs\2026-10-25_<lot>\NOTES.md`, puis relancer
> (SendMessage si l'agent répond, sinon nouvel agent avec le brief résumé au point de 17 h 45 et les constats du DC). Vérifier
> d'abord les verrous orphelins (`fo-autotest.lock`, `fo-render.lock.*`) et les processus de test restés ouverts.
> **POINT DE 18 H 50, AVANT UNE COUPURE PAR LA LIMITE D'USAGE (à lire en premier pour reprendre)** :
> - `main` = **0.4.29**, documenté (`5aa7b4c` et suivants). Le DC joue cette version. Guide de partie à jour :
>   `fo-logs\2026-10-24_PNJ\GUIDE_PARTIE.md`. Pages : Atlas des designs Dfvg6UEeQN5YYAYHZRS5Pt (source `designs/` du dossier de
>   travail de l'orchestrateur : `manifeste.json`, `build_page.py`), page du matin N8rHLyXYL7rYqnVjf7atj3.
> - DEMANDES DU DC EN VIGUEUR : questions par QCM cliquable (AskUserQuestion) ; l'IA des PNJ est une section que NOUS concevons
>   (D-18), avec « des agents sur le coup en permanance » (R-25k) : relancer un agent IA dès qu'un lot finit ; ses constats en
>   jouant (OBJECTIFS §5, 18 h 40 et 18 h 45, capture `fo-logs\2026-10-25_DC-captures\pnj-inactifs-fer-ignore.png`) : PNJ inactifs
>   au coffre, fer manquant jamais cherché (« Objectif : Charbon — il manque : 62 Plaque de fer »), pierre et charbon extraits
>   sans fin, aucune exploration : CAS DE TEST des lots IA3-b, IA3-c, IA3-f.
> - AGENTS EN COURS (chacun a un worktree `.claude/worktrees/agent-…` et un dossier `fo-logs\2026-10-25_<lot>\` avec NOTES.md
>   et un POINT DE REPRISE en tête ; s'ils sont coupés : SendMessage pour reprendre, ou nouvel agent avec le même brief en
>   lisant le dernier commit de la branche et ces NOTES) :
>   - IA3-a recherche d'abord (`fo-logs\2026-10-25_IA3-a`) ; IA3-b marché des tâches et registre (`…_IA3-b`) ; IA3-c nouveau
>     cerveau derrière `fo-ia3-cerveau` (`…_IA3-c`) ; IA3-f exploration sous brouillard, équipe du joueur comprise (`…_IA3-f`) ;
>     IA1-d plan directeur et construction (`…_IA1-d`) : périmètres de fichiers dans le point de 17 h 45 ci-dessous ;
>   - F2-B four en PRODUCTION (validé par le DC), F3-B assembleur en PRODUCTION (validé), F4-A2 foreuse « enrichir nettement » :
>     `fo-logs\2026-10-25_F2`, `…_F3`, `…_F4`.
> - EN ATTENTE (D-17) : X2-suite (monazite et sables noirs à refaire, usages des sous-produits, puis fusion de X2 : branche
>   `worktree-agent-a94df9d4c17247154`), X1-suite (hydrogène, ilménite I2 et nuit, saumure), A5-suite (couleur d'équipe 25 %,
>   liserés, teinte automatique), F1-C (3e ronde du laser), LOG-1 (logistique au-delà de 120 objets/s), F5 et F6 (centre, mur) ;
>   IA suivants : IA3-d (après b), IA3-g (après c et f), IA3-e (après c et IA1-d), IA3-h, IA3-i, IA3-j.
> - DÉFAUTS OUVERTS de 0.4.29 : `verif-guide` 314159265 (14 OK), `ia1b2-guide` 577215664 (13 OK), `ia1-poles` (15 OK, 2 ECHEC).
> - À L'INTÉGRATION de chaque lot : bancs sur `main` (scripts `bancs_04xx.ps1` du dossier de travail comme modèle), documents
>   (RD_LOG, OBJECTIFS, les deux CLAUDE.md identiques, changelog, info.json), worktree retiré ; disque surveillé (≥ 2 Go).
> **Point de 17 h 45** : `main` = **0.4.29** (IA1-b2 fusionné avec 3 défauts ouverts, documenté `5aa7b4c` ; IA3-0 fusionné
> `f613db1`). Le DC (R-25k) : « mettrez des agents sur le coup en permanance pour avancer sur la partie IA » : SECTION IA EN
> PARALLÈLE, relancer un agent dès qu'un lot finit (dépendances : `docs/IA3_CERVEAU.md` §6.2). En cours, chacun dans son
> périmètre de fichiers : IA3-a (recherche d'abord ; F279-F281, E186-E187), IA3-b (marché des tâches et registre ; board,
>   worker, org ; F282-F284, E188-E189), IA3-c (nouveau cerveau derrière `fo-ia3-cerveau` ; buts, projets, cerveau ; F285-F288,
>   E190-E192), IA3-f (exploration sous brouillard, carte de connaissance ; F289-F291, E193-E194), IA1-d (plan directeur et
>   construction, chemin critique ; F292-F295, E195-E197). Rendus : F2-B (four en production ; F276-F278, E184-E185), F3-A3
>   (assembleur, 3e ronde), F4-A2 (foreuse enrichie). SUIVANTS IA : IA3-d (effectif 8, après b), IA3-g (expéditions, après c et
>   f), IA3-e (automatiser, après c et IA1-d), IA3-h (pétrole), IA3-i (âges), IA3-j (lisibilité). Feuilles de la mitrailleuse
>   des worktrees : liens durs depuis `main` (même MANIFEST) au lieu de régénérer.
> **Point de 15 h 30** : conception IA3 FUSIONNÉE (`db7911c` : `docs/IA3_CERVEAU.md`, `shared/ai3/`, tests 31, 24, 15 OK ;
> rien de branché). Verdicts du DC : four VALIDÉ pour la production (lot F2-B lancé : rendu final, animation, mémoire vidéo
> au plancher, mise en jeu) ; foreuse « enrichir nettement » (F4-A2) ; foreuses X0 gardées à part (Q-C3) ; assembleur 3e
> ronde (F3-A3). Le DC demande le développement profond de l'IA en parallèle : agent IA3-dev lancé (revue adverse du document,
> IA3-0 fondations avec E180 et E181 en moteur réel, puis IA3-a « recherche d'abord » APRÈS la fusion d'IA1-b2). IA1-b2
> relancé pour finir ses 3 contrôles rouges (ia1-poles, verif-guide 314159265, ia1b-scale10). 5 agents en cours.
> **Point de 14 h 05 (après une coupure par la limite d'usage, 13 h 10 à 14 h)** : `main` = **0.4.28** (fenêtre « Équipe et
> factions », validée par le DC ; régression d'intégration de `levels_test` corrigée, `cf25906`) ; 0.4.27 = modules au barème
> D-17 et icônes validées. Documents à jour jusqu'à 0.4.28 (`c86b966`). Décisions du jour : D-17 (réponses R-QCM-25 à 25f),
> D-18 (l'IA des PNJ est une section à concevoir de bout en bout, sans questions au DC à chaque étape). LOTS EN COURS (reprendre
> un agent coupé par SendMessage ; s'il est perdu, relancer avec le même brief en lisant son dernier commit et ses NOTES) :
>   - IA1-b2, branche `worktree-agent-a00f8ab45b9529fa2` (dernier commit `7e483cc`) : défendre d'abord pour TOUTES les factions
>     (ordre strict de pvp_test à rétablir), l'équipe défend son coffre, travail pour les PNJ libres (inactifs ≤ 15 % à 8 PNJ),
>     correctif du solveur au plafond (MOD-3 INTEGRATION §7) ; NON fusionnable avant `verif-guide` 15 OK sur 4 graines ;
>   - F2-A2 (four, retouches légères), branche `worktree-agent-aa8c5e5bc03addfbd` (`89f7907`) ;
>   - F3-A2 (assembleur : corps intégré, détaillé, silhouettes variées dont circulaires), `worktree-agent-ad00d688396c75623`
>     (`f473739` + fichiers non commités au moment de la coupure) ;
>   - F4-A (foreuse), `worktree-agent-a235f8f5537d5ec4f` (`3055926`, ronde 1 en rendu au moment de la coupure) ;
>   - IA3 (conception du cerveau des PNJ, `docs/IA3_CERVEAU.md`) : RELANCÉ à 14 h (le premier architecte n'avait rien commité).
>   EN ATTENTE : X2 (terres rares, branche `worktree-agent-a94df9d4c17247154`, `6c3c248`) : refaire monazite et sables noirs,
>   donner un usage aux sous-produits, puis fusion (hausse du centre acceptée) ; X1-suite (hydrogène, ilménite I2 et nuit,
>   saumure) ; A5-suite (couleur d'équipe 25 %, liserés, teinte automatique) ; F1-C (3e ronde du laser) ; LOG-1 (logistique
>   au-delà de 120 objets/s) ; F5, F6 (centre, mur). Pages : page du matin N8rHLyXYL7rYqnVjf7atj3 ; Atlas des designs
>   Dfvg6UEeQN5YYAYHZRS5Pt (source `designs/` du dossier de travail : `manifeste.json`, `build_page.py`). Disque : 2,1 Go libres
>   à 14 h (cache d'atlas des captures effacé, régénérable ; vieux worktrees archivés dans `fo-logs/2026-10-25_menage-worktrees`).
>   Questions au DC : toujours par QCM cliquable (AskUserQuestion).
> **Point de 10 h 15** : page « Atlas des designs » publiée (https://claude.ai/artifact/Dfvg6UEeQN5YYAYHZRS5Pt ; source
> `designs/` du dossier de travail : `manifeste.json`, `gabarit.html`, `build_page.py`). Le DC BANNIT les familles qui ne
> changent que de teinte (OBJECTIFS §5, 25/10 vers 10 h) et choisit, par QCM, « les trois en même temps » : lancés F2-A
> (four), F3-A (assembleur), F4-A (foreuse) : fiches des 15 âges, kit de famille, aperçus, planches pour le DC ; rien en
> jeu ; rendus partagés sur les 2 places du verrou. Tournent aussi MOD-3 et IA1-b2 : 5 agents. Disque surveillé (2,8 Go).
> **Point de 9 h 25** : le DC a répondu à TOUT par QCM dans Claude Code (format exigé désormais : AskUserQuestion, jamais
> un code de réponse à taper) ; réponses mot pour mot dans OBJECTIFS §4 (R-QCM-25), décision **D-17** (RD_LOG). Lancés :
> MOD-3 (nouveaux paliers vitesse +20/+10 et productivité multipliée +10/+5, écart d'énergie au plafond, design MOD-V
> repris avec les choix du DC ; F248 à F250, E170, E171) et IA1-b2 (défendre d'abord, laisser grandir, gardes coupées ;
> F251 à F253, E172, E173). Page des designs demandée par le DC : images rassemblées par un agent dans `designs/` du
> dossier de travail. À LANCER ENSUITE (D-17) : X2-suite (monazite et sables noirs à refaire, usages des sous-produits,
> puis fusion de X2 : hausse du centre acceptée) ; X1-suite (recette qui consomme l'hydrogène, ilménite I2 et nuit
> assombrie, sol des cratères, saumure au visuel propre) ; A5-suite (25 %, liserés seulement, teinte automatique pour N
> équipes) ; F1-C (3e ronde du laser) ; LOG-1 (bras à grande capacité, convoyeurs à vitesse croissante, « tube » qui
> simule les objets : étude moteur d'abord). Worktrees de MOD-V et A5 retirés (branches gardées).
> **Point de 8 h 45 (le DC est réveillé ; bilan de la nuit envoyé)** : IA1-b fusionné (`f33cfbb`, **version 0.4.26**),
> 12 bancs en moteur réel verts sur main (`fo-logs` integration-0.4.26), documenté ; objectif « 30 livrent plus que 10 »
> NON atteint (0,95), morts × 9 hors du QG (F239). X2 (terres rares de l'âge 12) LIVRÉ NON FUSIONNÉ (branche
> worktree-agent-a94df9d4c17247154 ; commit intégrateur séparé `71eed72`) : en attente de la mesure de mémoire vidéo au
> plancher (agent relancé) ET de la question 11 du DC (prix du centre +26 à +84 %). Page du matin : 11 questions.
> **9 h** : mémoire vidéo de X2 MESURÉE (`d4-geant --measure`, 4 passages) : plancher 12 pages sur 12 comme main, compteur
> 0,42 Go comme main, jeu chargé ; atlas du terrain +1,2 Mpx ; l'atlas [icon] de la qualité normale perd
> `linear-mip-level` (F125, toléré). Le biome et la monazite changent la génération de toute la carte : les chiffres des bancs
> de durée (`ia0-normal`, `ia1-scale`) cités comme référence sont à refaire après la fusion (BILAN inchangés). X2 n'attend
> plus que la réponse du DC à la question 11. Aucun agent ne tourne ; en attente des réponses du DC (questions 1 à 11).
> **Point de 7 h 20** : IA1-e1 fusionné (`e64ab49`, jeu inchangé : solveur pur et banc `ia1-diag` 27 OK sur main,
> documents `cf5cce3`, BALANCE_SHEET : plastique 1,3 contre 3 MU non tranché). En cours : IA1-b (worktree), X2 (ressources
> de l'âge 12, terres rares, au modèle de X1 + petite usine sans script exigée ; F245 à F247, E168, E169).
> **Point de 6 h 50** : 0.4.24 fusionnée et prouvée (correction de la vérification adverse : votre équipe décimée se
> reconstruit ; `verif-guide` 1 ECHEC sur 0.4.23, 15 OK sur 0.4.24 aux 2 graines ; guide de partie réécrit pour 0.4.23+,
> ancien gardé). IA2-c fusionné (`16204fa`, version 0.4.25 : brouillard, éclaireurs, modèle de l'adversaire, côté le
> moins défendu) : PROUVÉ sur main (15 bancs en moteur réel verts, `done.txt` 6:38 à 6:48 ; pvp 1305, chef 62,
> adversaire 53, api_lint 975) et DOCUMENTÉ (`48fb7e3`). Guide de partie et page du matin mis à 0.4.25 (question 9 :
> plafond des recrues). Premier passage de la migration 0.4.23 : code 1 par erreur de chemin de l'intégrateur, rejoué juste.
> Lancés : IA1-b (pôles, managers, généralistes : donner du travail aux 30 PNJ ; F239 à F241, E164, E165) et IA1-e1
> (solveur de débits et diagnostic, retour sur investissement pour IA2-d ; F242 à F244, E166, E167), en worktrees.
> **Point de 4 h 45 (nuit)** : F1-B (rondes du laser, 15 âges) fusionné, OUTILS SEULEMENT (`c12c9a1`, documents
> `69ffdfe`) : aveugle 15/15, pose N en échec (âges 1, 6, 12), verdict du DC sur `fo-logs\2026-10-25_F1B\planches_DC\`.
> En cours : IA2-c (modèle du joueur, worktree, F234 à F236, E161, E162) ; VÉRIFICATION ADVERSE de 0.4.16 à 0.4.23
> (worktree, rapport `fo-logs\2026-10-25_VERIF-NUIT\verification.md` : parties longues, déterminisme, migration
> d'une sauvegarde 0.4.11 ou 0.4.15, guide de partie). En attente du DC : MOD-V (`1ed3ec0`), A5-ESSAI (`4e3fcad`).
> Page du matin PUBLIÉE vers 4 h 40 : https://claude.ai/artifact/N8rHLyXYL7rYqnVjf7atj3 (8 questions, aussi dans OBJECTIFS §4,
> ligne Q-MATIN-25 ; source `matin25/` du dossier de travail de l'orchestrateur). Disque : 18 vieux worktrees propres retirés
> à 5 h 10 (3,1 → 3,5 Go libres) ; les détachés gardent leur commit sous une branche `garde/wf_…` (12 branches) ; worktrees
> avec fichiers non suivis ou sorties de rendu ignorées : GARDÉS. Ensuite : intégrer IA2-c si ses garde-fous tiennent ;
> ajouter le rapport de la vérification adverse à la page.
> **Point de 3 h 35 (nuit)** : intégrées depuis 2 h 10 : MOD-2 (0.4.22, recettes par lots ; catégories `fo-*` du titane
> exclues des lots par l'intégrateur après un échec du contrôle des boîtes à fluide), IA2-b (0.4.23, expansion par la carte,
> seuils de forme en partie). MOD-V (modules au design distinct, branche worktree-agent-adfb469831c79e019, `1ed3ec0`) NON
> fusionné : lisibilité en jeu en recul (chiffre romain illisible à l'échelle d'interface, couleur par âge au lieu de par
> type) : 4 questions au DC (NOTES de MOD-V §6). En cours : F1-B (rondes du laser), A5-ESSAI (couleur d'équipe sur
> petits éléments, 3 âges, à montrer au DC). Au réveil du DC : page de la nuit.
> **Point de 2 h 10 (heure d'hiver ; passage à 3 h → 2 h cette nuit : les `done.txt` de 2 h à 3 h se répètent)** :
> fusionnés et prouvés : IA2-a et IA2-a2 (0.4.20, chef adaptatif, guerres rééquilibrées), X1 (0.4.21, titane de l'âge
> 11 ; premier agent bloqué 2 h 30, arrêté, fini par un second). En cours : MOD-2 (recettes par lots), IA2-b (expansion
> par la carte). Disque : 43 journaux `benchmark-stdout.txt` et `create-stdout.txt` des archives compressés sans perte
> (gzip), 3,3 → 4,0 Go libres. Ensuite : modules au design distinct, styles de minerais, F1-B.
> **Point de 0 h 45 (nuit)** : IA2-a (chef adaptatif v0) livré sur sa branche (`06e75c5`, worktree agent-a4454e244020a1012) ;
> variété nettement meilleure (côtés 0 → 1,31 bit, tailles 0,21 → 0,38, le bâtisseur attaque), garde-fous tenus (pvp 1 037,
> 0 échec), MAIS 3 factions anéanties sur 16 en 2 h (1 avant), une dès 25 min : NON fusionné. Correction IA2-a2 lancée
> sur la même branche (objectif : au plus 1 sur 16, aucune avant 60 min, variété gardée). X1 (titane) en cours.
> **Point de 23 h 15 (nuit)** : fusionnés et prouvés sur `main` : IA1-a (0.4.17), MOD-1 et A4-SOCLE (0.4.18), IA2-0
> (0.4.19) ; bancs en moteur réel et hors jeu verts à chaque version (archives `fo-logs\2026-10-24_integration-*` et
> `2026-10-25_integration-0.4.19`). En cours : X1 (titane de l'âge 11, worktree), IA2-a (chef d'équipe adaptatif v0,
> worktree). Ensuite : MOD-2 (recettes par lots), IA2-b (expansion par la carte), styles de minerais, modules au design
> distinct, F1-B. Le worktree d'IA2-0 n'a pas pu être effacé (fichier tenu) : `git worktree prune` plus tard.
> **NUIT DU 24 AU 25/10** : le DC dort (« passez la nuit a faire de votre mieux pour l'avancée du projet »). D-16 (RD_LOG) :
> choix provisoires pour M4, IA1 à IA5, E1 à E3. Ordre : intégrer MOD-1, A4-SOCLE, IA1-a ; puis MOD-2 ; IA2-0, IA2-a,
> IA2-b ; styles de minerais ; modules au design distinct ; F1-B. Deux agents à la fois, une place de rendu ; disque H:
> surveillé (14 worktrees fusionnés retirés à 21 h 40, 4,9 Go libres). Au réveil : une page de la nuit pour le DC.
> **Point de 21 h 35** : production du socle animé FINIE (19:51 à 21:29, code 0, 11 âges : 5 à 15) ; lot A4-SOCLE lancé
> (worktree : feuilles, banc a4-socle étendu, MESURE au plancher, images de nuit ; faits F204 à F206, E141, E142 ;
> version proposée 0.4.17). MOD-1 en cours. F1-B (rondes du laser) : à lancer quand un des deux agents aura fini.
> **Point de 21 h 25 : B0 fusionné, version 0.4.16** (`848b64c`, `3ff9751`) après le verdict du DC ; 8 bancs en moteur
> réel verts sur `main` (`fo-logs\2026-10-24_integration-0.4.16\`). Réponses du DC sur les modules : M1 a, M2 a, M3 a
> avec énergie = 60 % du bonus (D-15) ; Q-M4 en attente ; lot MOD-1 (mécanisme) en cours dans un worktree (faits F199 à
> F203, E138 à E140). En attente du DC : M4, S1 à S5, IA1 à IA5, E1 à E3, et son test de la partie.
> **Point de 21 h 35** : MOD-0 fini (branche worktree-agent-a62a9ed9477475af6, 2a1085b et 7a0a82c, outils de test
> seulement) : le moteur ADDITIONNE ; une balise cachée par machine rétablit le produit (0 voisine touchée sur 1 100) ;
> plafonds : × 328,67 par type d'effet (entier 16 bits en centièmes) et 60 fabrications par seconde (assembleurs, fours ;
> pas les foreuses) ; énergie 1 TW acceptée ; aucun événement quand un robot pose un module (balayage obligatoire).
> Page « Modules et biomes » envoyée au DC : https://claude.ai/artifact/AD8WJTepXqSqVD3xVEKXRQ (questions B1 à B4,
> M1 à M4). Faits proposés : MOD-0 F190 à F194, E133 à E135 ; B0 F195 à F197, E136, E137 (à inscrire à la fusion).
> **Point de 21 h 15** : B0 fini (branche worktree-agent-aeda9289b3fc0fb7d, 0b1a1a3) : cause des carrés prouvée
> (cristal et marais étaient des copies d'eau dans une couche au-dessus des sols, la frontière tombait sur la grille) ;
> cristal devenu un sol mauve bruyère, marais passé sous les sols ; b0-biomes 9, monde 89, m0-reprise 15, content 317 ;
> planches envoyées au DC, questions B-Q1 à B-Q4 (cristal, marais et méthane décalé, grain fin, végétation) ; fusion
> après son verdict. PIÈGE : feuilles.py sans argument ramasse les socles animés en cours de production (356 fichiers
> au lieu de 336) : ne pas régénérer les feuilles de main avant la fin de la production, ou passer --socle-anime.
> **Point de 21 h 05** : analyses finies (SCENARIO.md, IA_ADAPTATIVE.md, dans fo-logs 2026-10-24_ANALYSE) ; page de
> synthèse pour le DC https://claude.ai/artifact/1XgayKG82dW3LaFjngxdJp (questions S1 à S5, IA1 à IA5, E1 à E3, en
> attente). MOD-0 et B0 en cours (worktrees), production du socle animé en cours.
> **Point de 20 h 45** : correcteur d'IA1-a FINI dans sa branche (`153c696` ; main 0.4.15 fusionnée dedans ; réglages
> unifiés sur `fo-war-*` ; M1 corrigé, M2 mesuré sans conclure, défaut nouveau : faction décimée bloquée à 1 PNJ ;
> 23 attaques fantômes sur une graine ; 3 questions au DC dans `fo-logs\2026-10-24_IA1\IA1-a\INTEGRATION.md` §0.2) :
> fusion APRÈS le test du DC. Demandes du DC de 20 h et 20 h 30 (OBJECTIFS §4 R-20H, Q-B1, Q-B2) : agents en cours :
> analyse du scénario (ressources, machines) et analyse de l'IA adaptative (lecture seule, `fo-logs\2026-10-24_ANALYSE\`),
> MOD-0 (faisabilité des modules multiplicatifs, worktree, `fo-logs\2026-10-24_MOD0\`), B0 (biome violet et
> transitions en carrés, worktree, `fo-logs\2026-10-24_B0\`). Production du socle animé en cours.
> **Point de 19 h 50** : le DC donne son feu vert (« oui feu vert ») pour les travaux qui chargent le PC. Production du
> socle animé des âges 5, 7 à 15 LANCÉE vers 19 h 48 (`anime_socle.py`, une place de rendu, Blender en priorité basse ;
> journal `fo-logs/2026-10-24_A4/socle-anime/production-10-ages.log` ; environ 6,4 h estimées). Ensuite : `feuilles.py`,
> `check_gun_sheets`, `a4-socle` étendu, et MESURE de l'atlas du plancher (F186) avant toute intégration. Correcteur
> d'IA1-a en cours (agent seul, branche mise à jour avec main ; fusion seulement après le test du DC). F1-B (rondes du
> laser) : après IA1-a.
> **Point de 19 h 15 : IA1-c fusionné** (`e074595` ; correcteur repris par message après la coupure, `314069d`) :
> `ia1-modules` 136, `content` 317 sur `main` ; ia1_modules_test 1 018, api_lint 788. Le DC a changé de profil une
> troisième fois : 11 pages republiées (adresses mises à jour dans les documents) ; session avec images et sons
> `pnj-vue` sur 0.4.15 : code 0, pilote disk, sons chargés, 16 captures (`fo-logs\2026-10-24_integration-0.4.15\pnj-vue-son\`)
> ; guide et planche envoyés au DC. Reste : correcteur d'IA1-a (coupé deux fois ; `82dd19c` sur sa branche), puis IA1
> vague 2 ; F1-B ; socle animé des 10 autres âges (mesurer l'atlas du plancher, F186) ; couleur d'équipe.
> **Point de 15 h 55 : version 0.4.15, le jeu se lance avec les PNJ sans console** (`39048d5`) : à la demande du DC
> (« faite en sorte que la version du jeu soit jouable (avec les pnj etc) »), réglages de carte `fo-war-*` ;
> `pnj-auto` 7 OK, `content` 317, `pnj-reduit` 12 sur `main`. Réponses du DC : tungstène A, laser A, fentes de l'âge 11
> A. Session avec images ET sons (`FO_AUDIO=1`, `pnj-vue`) lancée pour vérifier que le mod se charge comme dans le
> vrai jeu. Correcteur d'IA1-c en cours (agent seul).
> **Point de 15 h 35 : M1, IA1-0 et F1-A fusionnés, version 0.4.14** (`45966bf`, `7c51cdd`, `5cb936c`, `dba020c` ; conflit
> du README des bancs résolu en gardant les deux paragraphes). Moteur réel sur `main` (`fo-logs\2026-10-24_integration-0.4.14\`,
> `done.txt` 15:08:35 à 15:09:36) : content 317, gun-rose 13, monde 89, m1-minerai 7, ia1-risques 65. Hors jeu : tous verts
> (api_lint 771, check_gisement 7 + 10/10 mutants, test_laser 127, pvp 596 en 518 s). À montrer au DC : le tungstène de jour
> et de nuit (`fo-logs\2026-10-24_M1\correction\planche-dc-tungstene-nuit.png`) et les planches du laser
> (`fo-logs\2026-10-24_F1\correction\planches_final\`). Reste : correcteurs d'IA1-a et IA1-c (coupés deux fois ; IA1-c a
> `a7d2dc6` et `838054d`), puis IA1 vague 2 ; F1-B (rondes du laser) ; socle animé des 10 autres âges (mesurer l'atlas
> du plancher, F186) ; couleur d'équipe (essai sur 2 ou 3 âges). Usage payant : un agent à la fois.
> **Point de 15 h 10 : A3-final fusionné, version 0.4.13** (`0f8e10d`, `7ee9c03`) : les 15 âges de la mitrailleuse à
> 64 directions (agent seul, `c8534df`). Feuilles régénérées dans `main` sans option (336 PNG, 155,14 Mo, 357 s ;
> check_gun_sheets 6 OK ; `git status` propre). Bancs en moteur réel sur `main` 0.4.13 (`done.txt` 15:04:20 à 15:06:45 ;
> `fo-logs\2026-10-24_integration-0.4.13\`) : content 317, gun-rose 13, d4-geant 18, a4-eclat 3, a4-ruines 5, a4-socle 2,
> s0-tir 5, verif-tourelles 7, pnj-reduit 12. Images envoyées au DC (diagonales jour et nuit, éclats 9 à 15, roses 9, 12,
> 15, fente de l'âge 11) ; questions : 3 fentes de l'âge 11 acceptables ? taille des éclats des grands âges ? **Atlas
> virtuel du plancher PLEIN (F186)** : le socle animé des 10 autres âges doit être mesuré au plancher avant intégration.
> Temps de chargement à remesurer PC au repos. Ensuite : intégrations M1 (tungstène), F1-A (kit laser, outils), IA1-0.
> **Point de 14 h 30 : PNJ-VÉRIF fusionné, version 0.4.12** (`655ef62`, `862eb60`). Correcteur seul (`f91a014`,
> `9355ced`) : M1 à M4 corrigés et prouvés (tourelles des factions et de l'équipe du joueur, soldats rappelés, garnison
> proche), M5 décrit, M6 et m1 à m3 dans le guide, m4 (captures de la partie réduite) non fait. Code testé = code de
> `main` (seuls les documents diffèrent). Sur `main` : `content` 317, `verif-tourelles` 7, `pnj-reduit` 12
> (`fo-logs\2026-10-24_integration-0.4.12\`). Guide envoyé au DC : `fo-logs\2026-10-24_PNJ\GUIDE_PARTIE.md`. Reste
> ouvert : F174 (groupes amputés à leur création), 2 factions sur 4 sans attaque dans `default` depuis 0.4.5, pics de
> script à remesurer sur machine calme. Ensuite : A3-final (version 0.4.13), puis intégrations M1, F1-A, IA1-0.
> **Point de 13 h 55** : le nouveau profil a lui aussi atteint sa limite de la semaine (remise à zéro le 27/10 à 1 h) ;
> le DC a ouvert l'usage payant (plafond 100 $/mois) et dit « reprenez ». **Règle tant que l'usage est payant : un
> seul agent à la fois, sans workflow à vérificateur ni correcteur systématiques ; l'orchestrateur relit lui-même.**
> Résultats de la reprise : F1-A corrigé (`7aea3b4`, 4e jet du kit laser) et M1 corrigé (`7ee2bab`, le tungstène luit de
> nuit) ; IA1-0 corrigé (`d86efb1`) ; correcteurs d'IA1-a et IA1-c de nouveau coupés (IA1-c a 2 commits de correction,
> `a7d2dc6`, `838054d`) ; A3-final de nouveau coupé (changements non commités dans `wf_a2163957-669-1`) ; vérificateur de
> PNJ-VÉRIF fini : correction des attaques fantômes confirmée, mais 6 défauts majeurs (tourelles des factions jamais
> débloquées, livre de recettes de l'équipe du joueur figé, soldats laissés au loin, garnison mal comptée, régression de
> 0.4.5, guide sans mises en garde sur les sauvegardes) ; **correcteur PNJ lancé seul vers 13 h 55** (agent unique,
> worktree `wf_dbbe3818-700-1`). Ensuite : A3-final, puis intégrations M1, F1-A, IA1-0.
> **Mise à jour précédente : 24/10/2026, vers 13 h 05** (orchestrateur, session `8a9c0503`) : la production des têtes est
> **finie** (11:59:25 : 840 / 840, 0 erreur ; 8 têtes HORS REGLE, dont 3 nouvelles à regarder : e11-d07, d22, d33). Vers
> 12 h, **limite hebdomadaire du compte claude.ai atteinte** : 7 agents coupés net (A3-final au bout de 2 min ; les
> correcteurs de F1-A, M1, IA1-0, IA1-a, IA1-c ; le vérificateur de PNJ-VÉRIF), un banc moteur tué (verrou orphelin retiré
> à 13 h). Le DC a changé de profil ; **les 11 pages ont été republiées sur le nouveau profil** (nouvelles adresses
> partout dans les documents) et les 4 runs relancés par `resumeFromRunId` vers 13 h, avec une note de reprise pour
> chaque agent coupé : `wf_a2163957-669` (A3-final, version proposée 0.4.12), `wf_dbbe3818-700`, `wf_7e687e38-811`,
> `wf_e12c2f9b-9c8`. Disque H: 5,9 Go libres (alerte sous 3 Go). Avant :
> **24/10/2026, vers 10 h 30** (orchestrateur, session `8a9c0503`) : version **0.4.11** (éclat
> qui grossit d'ère en ère) ; le DC a validé la mitrailleuse (« Ok pour les mitrailleuses j'aime bien ») et répondu aux
> questions (OBJECTIFS §4 : Q-A4-1 progression par ère, Q-A4-2 A, Q-A4-3 B en petits éléments désaturés, Q-P3 B) ; **D-14 :
> IA1 se construit maintenant**. EN COURS : production des têtes (816/840 à 10 h 15) puis A3-final (script prêt :
> scratchpad `wf_finalisation.js`) ; runs `wf_e12c2f9b-9c8` (F1-A kit laser, M1 minerai), `wf_dbbe3818-700` (PNJ-VÉRIF :
> gameplay des PNJ v0, guide de partie), `wf_7e687e38-811` (IA1 vague 1 : IA1-0, IA1-a, IA1-c). À FAIRE : socle animé
> des 10 autres âges (6,4 h de Blender, de nuit), essai de la couleur d'équipe (petits éléments, désaturée), rondes du
> laser (F1-B). Avant :
> **Dernière mise à jour : 24/10/2026, vers 7 h 35** (orchestrateur, session `8a9c0503` ; jalon : **A4-préparation et
> D4m-géant fusionnés, version 0.4.10** (`ab4f1b6`, `d7efe80`) ; production des têtes en cours (fin vers 9 h), puis
> `FINALISATION.md` d'A3-jeu). Avant : 24/10, vers 4 h 15 (jalon : **A3-jeu fusionné,
> version 0.4.9** (`3fe1da6`) : âges 2 à 8 à 64 directions en jeu ; production des têtes en cours (fin estimée entre
> 10 h et 13 h), puis `FINALISATION.md` d'A3-jeu). Avant : 24/10, vers 2 h 45 (jalon : **S0-suite fusionné,
> version 0.4.8** (`4ffd852`) ; A3-jeu coupé par une panne des serveurs (529) vers 2 h 20, reprise `wf_bcc3f79d-bc7`
> lancée à 2 h 33 dans le même worktree ; production des têtes toujours en cours). Avant : 24/10, vers 0 h 10 (jalon :
> **A3-préparation
> fusionné** (`a7f1166`) et **production des têtes à 64 directions LANCÉE à 0 h 00** (768 têtes, une place de rendu,
> 8 à 10,5 h ; tâche de fond de la session `8a9c0503` ; §7). Avant : 23/10, vers 23 h 10 (jalon : **lot S0 fusionné,
> version 0.4.7** : tir de la mitrailleuse par ère, provisoire (page d'écoute https://claude.ai/artifact/Ap4JoXCgvxJJR29b5QceU3) ; tous
> les bancs verts sur `main` 0.4.7 (moteur réel de 22:57:15 à 22:59:00) ; A3-préparation encore en cours dans le run
> `wf_e1ae9f59-b47`). Avant : vers 21 h 15 (jalon : **lot A2 fusionné,
> version 0.4.6** : la mitrailleuse validée est EN JEU, 30 niveaux à 4 directions (fusion `e0088bd`, changelog `ef64f79`) ;
> tous les bancs verts sur `main` 0.4.6 (moteur réel de 20:53:22 à 20:54:56, hors jeu jusqu'à 21:02) ; page pour le DC
> https://claude.ai/artifact/DcVt6j6PVctVQteegWJamt). Avant : vers 18 h 30 (agent des documents du run `wf_2f1793c9-578`,
> session `8a9c0503` ; jalon : plan de la suite lancé ; lots **A1** (outils de la mitrailleuse : rose des 8 directions, E66,
> E67, E70 ; fusion `5a95650`) et **M0** (monnaies des âges 5, 7 et 8 garanties ; fusion `da2e16f`, **version 0.4.5**)
> fusionnés dans `main` à 17 h 44 ; bancs en moteur réel rejoués sur `main` de 17:45:17 à 17:46:17, hors jeu vers
> 17 h 50 ; lot **K0** (kit commun des familles) livré et corrigé ; **lots INT-K0, INT-GARDE et INT-GRAINE fusionnés vers
> 18 h 40** (`e4e8416`, `b80f2bb`, `0db5493`), tous les bancs rejoués verts sur `main` de 18:42 à 18:50, dont `content` et
> `monde` sur la graine 123456789 ; `.bat` de la racine recopiés). Lot A2 lancé vers 19 h 05 (run `wf_0143e61e-944`, session
> `8a9c0503` ; la mitrailleuse en jeu à 4 directions ; décision D-6 : feuilles dans `graphics/levels/gun/`, hors de git, manifeste
> commité ; sorties `<racine>\fo-logs\2026-10-24_A2\`). Mise à jour précédente : 22/10/2026, 23 h 08 (heure du PC ; orchestrateur, session Claude Code `8a9c0503`, qui
> reprend la session `6b481308` du 21-22/10, coupée à 8 h 55 par la limite d'usage hebdomadaire de son compte ;
> jalon : lot V3-T3 (« Libérer la place », réponse B à Q-T2-1) intégré dans `main` (fusion `8a28804`, changelog
> `4a7a365` ; **version 0.4.4**), bancs en moteur réel rejoués sur `main` de 22:50:45 à 22:51:53, hors jeu jusqu'à 22:55:17 ; lot V3-T4 (réponse A à Q-T2-2)
> livré sur sa branche, **NON intégré** (Q-T4-1) ; jalons précédents : lot R1 intégré à 20 h 11 (fusions `dcc97b3` et
> `58db82c`, version 0.4.3), lot V3-T2 intégré à 19 h 05 (fusion `681dd5c`, version 0.4.3), suites de V3-T intégrées à
> 17 h 25, lot V3-T intégré à 14 h 50). Mettez à jour ce fichier à chaque jalon.

## 1. En dix lignes
1. Mod Factorio 1.1.91, version **0.4.7** (depuis la fusion du lot S0, le 23/10 vers 22 h 55 ; 0.4.6 depuis A2, le
   23/10 vers 20 h 50 ; 0.4.5 depuis M0, le
   23/10 à 17 h 44 ; 0.4.4 depuis V3-T3, le
   22/10 à 22 h 50 ; 0.4.3 depuis V3-T2), dépôt git `main` dans ce dossier.
2. Bancs sur `main` **0.4.7** (rejoués le 23/10 après la fusion de S0 : moteur réel de 22:57:15 à 22:59:00, archives
   `<racine>\fo-logs\2026-10-23_integration-0.4.7\`), tous verts ; changent : harness (règle « sons », 13/13),
   bat_double_source **40**, test_audio_session **21** et `sons.py --check` **20** (nouveaux), `gun-rose` aussi avec
   `FO_AUDIO=1`, et `fo-captures gun-rose` avec `FO_AUDIO=1` silencieux (garde : 0 session audio du jeu). Avant, sur
   0.4.6 (rejoués le 23/10 après la fusion d'A2 : moteur réel de 20:53:22 à 20:54:56, archives
   `<racine>\fo-logs\2026-10-23_integration-0.4.6\` ; hors jeu jusqu'à 21:02), tous verts ; changent : levels **1662**,
   api_lint **676**, mut_atlas **50**, harness (règle « images », feuilles de la mitrailleuse 318, 0 manquant),
   **`gun-rose` 11 OK** (nouveau) + 90 captures, check_gun_sheets 12 ; le reste comme ci-dessous. État précédent
   (rejoués le 23/10 après les fusions d'A1 et M0 : moteur réel de 17:45:17 à 17:46:17, archives
   `<racine>\fo-logs\2026-10-23_integration-0.4.5\` ; hors jeu vers 17 h 50), tous verts :
   - hors jeu : run 114, war 92, td 270, pteam 15, migration 82, **monde_test 157** (nouveau, lot M0), levels 1642
     (+11 écarts connus), epochs 16665, org 362, pvp 596 ;
   - étape data : 0 erreur nouvelle, 0 violation (règle des points de jeu comprise), 0 clé manquante, 11/11 ;
   - api_lint : **669** usages, 0 erreur (609 avant A1 et M0) ;
   - **moteur réel, garantie des monnaies (lot M0)** : `monde` 89 OK, `m0-reprise` 15 OK, `m0-migration` 9 OK
     (double source `<racine>\fo-logs\2026-10-23_suite\M0\src-0.4.4` = `git archive 93e3d89`, à GARDER) ; tous les
     bancs ci-dessous rejoués verts avec les 3 sites garantis sur la carte de banc (les `ia0-*` NON rejoués) ;
   - les chiffres ci-dessous, du 22/10, sont inchangés le 23/10 (`content` 317, `t2-machines` 80, `bord-a-bord` 12,
     `t3-libere` 41, `t2-migration` 64 + 26, `ht3-migration` 30 + 7, `t2-defense` 36 + 19 et 36 + 11, `t3-migration` 7) ;
   - (état du 22/10 après V3-T3 : moteur réel de 22:50:45 à 22:51:53, hors jeu de 22 h 50 environ à 22 h 55 ; pvp en
     195 s ; api_lint 609, le correcteur de V3-T3 annonçait 615 dans son worktree : écart non expliqué) ;
   - d4m : **5/5** (depuis Git Bash ; 2/5 sous PowerShell, `lua5.2` hors du PATH) ; mut_atlas 40 OK ; mut_vram
     « témoin nul survivant ; 18/18 mutants détectés » ; test_ht3_journal 15 OK ; bat_double_source 4 OK ;
   - **moteur réel `content` : 317 OK** (210 du banc, 2 de l'exemple, 26 de `levels_taille`, 54 de
     `levels_machines`, 25 de `levels_points`) ; `t2-machines` : 80 OK ; `bord-a-bord` : 12 OK ;
   - **moteur réel, migration d'une vraie sauvegarde 0.4.2 → 0.4.4** (double source, scénario `t2-migration`) :
     64 OK, journal `--tag FO-T2-MIGRATION` 26 OK ; **0.4.1 → 0.4.4** (`ht3-migration`) : 30 OK, journal 7 OK ;
   - **moteur réel, défense dense** (double source, `t2-defense`) : création 0.4.1, 36 OK + journal
     `--tag FO-T2-DEFENSE` 19 OK ; création 0.4.2, 36 OK + journal 11 OK ;
   - **moteur réel, « Libérer la place »** : `t3-libere` 41 OK (1 900 ticks, vrais robots en zone R) ; `t3-migration`
     7 OK (double source `src-0.4.2`, 1 000 ticks ; 700 ticks est trop court). Archives :
     `<racine>\fo-logs\2026-10-22_V3T3-integration\`.
3. Fait et prouvé en moteur réel :
   - outillage P0 et P1 (captures automatiques) ;
   - V2, V2b et V2c (15 époques, 30 niveaux, amélioration INSTANTANÉE, condition du centre) ;
   - V3-T, pour la mitrailleuse : emprise croissante (2×2 → 6×6, une taille par ère) et agrandissement sur place
     (Q24 : refus sans paiement et contour si la place manque) ;
   - **V3-T2** (22/10, 19 h 05) : la même mécanique pour toutes les familles sauf le mur (laser et four 2×2 → 6×6,
     foreuse et assembleur 3×3 → 6×6, centre 4×4 → 8×8), avec transfert complet, fabrication en cours reprise,
     points de jeu servis dans les 4 orientations, remise sur la grille d'un bâtiment hors grille, message de
     migration. Visuel provisoire, laid aux grandes tailles. Deux questions posées au DC (Q-T2-1, Q-T2-2, §3) ;
   - **H-T3** (suite de V3-T, 22/10) : une vraie sauvegarde 0.4.1 migre en 0.4.2, sur une carte de banc
     (E46). Statut exact : (1) prouvée en moteur réel ; (2) prémisse réfutée (F77 : sans montée de version,
     `on_configuration_changed` est quand même appelé et `Levels.repair` migre) ; filet prouvé seulement en
     expérience de contrôle. Constat : une mitrailleuse collée aux murs et nourrie par un bras derrière elle
     reste hors grille (question Q-T3) ;
   - **R1** (robustesse, 22/10, 20 h 11) : une DÉFENSE DENSE migre et MARCHE (21 tourelles sur 21 tirent, 63 ennemis
     sur 63 tués), mais 13 tourelles sur 21 d'une ligne 0.4.1 sont laissées : les 8 du tronçon A, hors grille, se
     chevauchent entre elles ; les 5 du tronçon C chevauchent mur, convoyeur, poteaux et bras ; depuis 0.4.2, 5 lasers
     laissés, aucun mur chevauché (laid, non jugé ; Q-T2-1 complétée) ; le contact bord à bord des recherches par zone est observé (F96), le
     moteur simulé aligné, un faux compte d'objets au sol corrigé dans le mod ; `vram.py` compte l'atlas virtuel
     (plancher 0,28 à 0,53 Go). RD_LOG E53 à E55, F96 à F102 ;
   - **V3-T3** (22/10, 22 h 50, version 0.4.4 ; réponse B du DC à Q-T2-1) : bouton « Libérer la place ». Les gêneurs
     sont marqués à démonter et des fantômes les reposent décalés, réglages compris, tout ou rien ; « Annuler » remet
     l'usine comme avant ; prouvé avec de vrais robots. Limites : au milieu d'une rangée collée, rien ne se libère
     (5 sur 19 dans l'usine dense de test, 2 sur 13 dans la défense dense) ; fils de circuit non refaits ; panneau
     jamais joué par un vrai joueur. RD_LOG E56 à E59, F103 à F110 ;
   - **M0** (23/10, 17 h 44, version 0.4.5) : tungstène, cristal et méthane (monnaies des âges 5, 7 et 8) garantis
     sur toute carte, à `on_init`, à `on_configuration_changed` et par un filet ; un échec est annoncé et repris par
     paliers. Avant, 3 graines sur 5 pouvaient bloquer la partie (E73). Limites : accès à pied non garanti (7 sites
     sur 15 non reliés au départ sur des cartes à eau maximale) ; générateur depuis `X.resources` et `X.tiles`
     REPORTÉ aux lots X (34 prototypes sur 35 absents) ; Q-M0-1 et Q-M0-2 (§3). RD_LOG E73 à E76, F130 à F135 ;
   - **A1** (23/10, 17 h 44, outils seulement) : directions `d00` à `d63` de la tête (identité octet à octet de N et
     E prouvée), rose des 8 directions (page DC https://claude.ai/artifact/3wt4uyQfxBLigQEXfZ14Vv , pas encore jugée),
     E66 (ombre à 32 échantillons : grain sans biais, **gain 44,7 %** mesuré dos à dos), E67 (levée = 1 / vitesse : la
     garde du kit a tort), E70 (origine nord, sens horaire, `orientation` s'écrit et tient). RD_LOG E66, E67, E70,
     F120 à F122 ;
   - IA0 et IA0b (les factions attaquent le joueur, 5 difficultés, bases défendues, assaut coordonné) ;
   - budget A1 (0,108 ms/tick) ;
   - D4m (mémoire vidéo 1,7 Go en haute qualité, 60 UPS avec l'usine géante).
4. Conçu hors jeu, pas encore en jeu :
   - X0 : scénario « La Caustique d'Érèbe », 15 époques et 4 branches, **approuvé par le DC** ;
   - IA1 : équipes de 30 PNJ, pôles, généralistes, production adaptative ;
   - **V3-T4** (réponse A du DC à Q-T2-2, « la production suit la surface ») : livré sur sa branche
     (`worktree-wf_9d38a6df-249-1`, tête `2b18742`), prouvé en moteur réel SUR LA BRANCHE, **NON intégré** : la densité
     est tenue, la rentabilité ne l'est pas (Q-T4-1, §3). RD_LOG E60 à E62, F111 à F118.
5. Visuel :
   - **mitrailleuse V3-E : designs des 15 âges VALIDÉS par le DC** (23/10, 14 h 50) ; **en jeu depuis 0.4.6** (lot A2,
     à 4 directions ; 64 positions au lot A3) ;
   - **kit commun des familles (K0)** : livré et corrigé (aucun design validé changé, empreinte forte), EN COURS
     d'intégration (INT-K0) ; F136 : les graines de bruit du pipeline sont inertes (non corrigé, décision du DC) ;
   - pipeline 3D (V0, V0b) étalonné ; style de la cheminée V0 validé par le DC ;
   - **aperçus V3 phase 1 REJETÉS** (22/10, 7 h 15) : manque de détail, direction artistique de Factorio
     non respectée, niveaux hauts pas plus « badass ».
6. Nouvelles règles visuelles (Q23 et Q24) :
   - les bâtiments GRANDISSENT avec les époques, jusqu'à environ 6×6, avec plus de détail ;
   - test du regard naïf ;
   - agrandissement sur place si la place est libre : **mécanique faite pour toutes les familles sauf le mur**
     (V3-T pour la mitrailleuse, V3-T2 pour les autres) ; le visuel reste provisoire (sprite actuel agrandi ×2 à
     ×3, sans détail, laid aux grandes tailles) ; depuis 0.4.4, bouton « Libérer la place » quand seule la place manque
     (V3-T3).
7. **V3-S : fait** (style retenu par le DC le 22/10 à 16 h 45, E45 ; lot V3-E lancé à 16 h 55, §7). Historique
   de sa reprise (13 h 20, workflow `wf_ed692a11-bba` de la session `8a9c0503`) :
   - La charte est livrée (7 h 42) et intégrée : `docs/DA_FACTORIO.md`, chiffres dans `docs/da/`,
     outils dans `tools/da/`.
   - Les 3 explorateurs (industriel, haute technologie, hybride) avaient été coupés à 8 h 55 pendant
     leurs itérations. Leur travail est commité dans leurs worktrees (`wf_483106c7-c7f-2`, `-3`, `-4`),
     et de nouveaux agents le reprennent.
   - La suite : test du regard naïf à l'aveugle, 2 juges, puis les planches pour le téléphone.
   - Le test de Stable Diffusion local est fait (E42) : c'est un outil d'inspiration seulement.
   **V3-T : terminé et intégré** (workflow `wf_2e0c7966-6df` lancé à 13 h 45, fini à 14 h 49 ; fusion dans
   `main` à 14 h 50, commit `13b4134` ; version 0.4.2) :
   - emprise par famille et par niveau, pilotée par `L.footprints` (`shared/levels/config.lua`) ;
   - agrandissement sur place si la place est libre ; sinon refus sans paiement, avec le contour affiché ;
   - contenu transféré ; sauvegardes migrées au chargement (`on_configuration_changed`, filet
     `on_nth_tick(30)`).
   ACTIVÉE pour la seule mitrailleuse (les autres familles depuis V3-T2, ci-dessous). Preuves : RD_LOG E44, F70 à
   F75 ; journaux `<racine>\fo-logs\2026-10-22_V3T\` et `<racine>\fo-logs\2026-10-22_V3T-integration_content\`.
   Non prouvé en moteur réel : panneau et aperçu au sol, transfert autre que munitions et PV (fluides,
   brûleur, recette, fils, réglages de foreuse), remboursement F40, machines agrandies (liste complète :
   RD_LOG E44). Depuis V3-T2 (RD_LOG E49), le transfert des fluides, du brûleur, de la recette, des fils et des
   réglages de foreuse, ainsi que les machines agrandies, sont prouvés en moteur réel ; restent non prouvés le
   panneau, l'aperçu au sol et le remboursement F40. La migration d'une vraie sauvegarde (H-T3) est prouvée en moteur réel le 22/10 à 15 h 59
   (worktree, `d6ba888`), puis rejouée sur `main` à 17 h 06 (E46), sauf le rechargement d'une carte déjà
   migrée, une défense dense (jouée depuis : lot R1, E54) et l'amélioration d'une mitrailleuse laissée hors grille
   (liste complète : RD_LOG E46).
   **Suites de V3-T : faites et intégrées** (22/10 ; workflow terminé à 17 h 01) : H-T3 en moteur réel (E46),
   règle des points de jeu du harness et moteur simulé à boîtes vanilla (E47), banc d4m corrigé (E48). Faits
   F76 à F82.
   **V3-T2 : terminé et intégré** (run `wf_04ba1f63-d67`, lancé vers 17 h 18 ; ingénieur, 3 relecteurs, correcteur ;
   fusion `--no-ff` `681dd5c` dans `main` à 19 h 05, version 0.4.3 ; changelog réécrit pour le joueur, `aec3baf`).
   Preuves : RD_LOG E49 à E52, F83 à F95 ; `<racine>\fo-logs\2026-10-22_V3T2\` (`NOTES_V3T2.md`) et
   `<racine>\fo-logs\2026-10-22_V3T2-integration\`. Le défaut majeur de la revue (points de jeu servis selon
   l'orientation) a été confirmé par un témoin en moteur réel, puis corrigé ; deux défauts plus graves trouvés en le
   prouvant (F90 : tuyau perdu ; F91 : orientation perdue), corrigés. Non prouvé, entre autres : migration d'une
   machine EN fabrication (non jouable avec `--create`), seconde amélioration avant le `on_tick` du mod, panneau et
   message à l'écran, raccords du fluide de minage, dispositions d'usine réelles.
8. Ensuite : **le plan de la suite** (`<racine>\fo-logs\2026-10-23_plan-suite\PLAN_SUITE.md` ; étapes dans OBJECTIFS
   §6 ; détail au §7 ci-dessous) : intégrations INT-K0, INT-GARDE, INT-GRAINE et **A2** (la mitrailleuse EN JEU à 4
   directions, 0.4.6) : faites ; ensuite **A3 : 64 directions, rendu de nuit** (Q-P2 : A). Historique :
   - lot V3-E : direction artistique PAR ÉPOQUE de la mitrailleuse (style V3-S retenu par le DC le 22/10 à
     16 h 45 ; canons, tuyaux et accents changés selon chaque âge), puis les 6 autres familles ; les sprites V3
     remplaceront le visuel agrandi de V3-T2, laid aux grandes tailles ;
   - ~~activation des tailles croissantes pour les 6 autres familles~~ : **faite** (V3-T2, 22/10, 19 h 05) ;
     ~~attendre les réponses du DC à Q-T2-1 et Q-T2-2~~ : reçues (B et A) ; Q-T2-1 appliquée (V3-T3, 0.4.4) ; Q-T2-2
     appliquée en partie par V3-T4, non intégré : attendre la réponse à Q-T4-1 ;
   - Compaction ×4 (C) et construction d'IA1, en parallèle (Q18) ;
   - contenu des époques (X1 à X15) ;
   - idle (I).
9. Le DC suit souvent depuis son **téléphone** : envoyez les images dans le chat (SendUserFile, mode
   render), avec un texte court.
10. Ne déclarez jamais un design réussi : seul le verdict du DC le valide. Depuis Q25 (22/10, 15 h 48 :
    « je verrai les templates àlus tard car vous savez parfaitement quoi faire »), on ne BLOQUE plus sur ce
    verdict : on enchaîne avec la direction des juges, chaque choix consigné comme provisoire et réversible.

## 2. Lots : état exact

| Lot | État | Où sont les preuves |
|---|---|---|
| P0 reprise, P1 captures automatiques | ✅ fusionnés | RD_LOG E26, E28 ; `fo-logs\2026-10-21_P1_*` |
| V0, V0b pipeline 3D et cheminée | ✅ fusionnés ; style validé (verdict du 21/10, 19 h 36) | E29, E30, E31, E39 ; `fo-logs\2026-10-21_V0b_vitrine-final\` |
| V1 bible des époques | ✅ fusionné (`docs/DESIGN_EPOQUES.md`) | E27, F44 à F48 |
| V2, V2b, V2c niveaux sur 15 époques | ✅ fusionnés, moteur réel 212 OK | E32, E35, E38 |
| IA0, IA0b PvP et difficulté | ✅ fusionnés, moteur réel | E33, E36, E41 |
| X0 scénario et crafts | ✅ fusionné, hors jeu ; scénario approuvé | E34 ; `docs/SCENARIO_EPOQUES.md` |
| IA1 conception des équipes de PNJ | ✅ fusionné, hors jeu ; Q-IA1-1 à 7 ouvertes | E37 ; `docs/EQUIPES_PNJ.md` |
| D4m mémoire vidéo et usine géante | ✅ fusionné, moteur réel | E40 ; `fo-logs\2026-10-22_D4m_*` |
| **V3 phase 1** modélisation des 7 familles | ❌ direction rejetée ; travail CONSERVÉ sur des branches non fusionnées (voir §4) | planches dans les branches `worktree-wf_1f9884be-7b6-1` à `-7`, `docs/epoques/planches/<famille>/` |
| **V3-S** direction artistique | Charte ✅ intégrée. Première passe ✅ jugée (E45) : industriel gagnant de peu (6/10), aucune approche au niveau du vanilla ; page pour le DC https://claude.ai/artifact/2jA1RqTTiF7GDWwPkSjXKJ . ✅ Style retenu par le DC le 22/10 à 16 h 45 (E45). Passe de synthèse (run `wf_eaa96606-5f1`, lancée à 16 h 25, session `8a9c0503` ; variantes « affût » et « resserre ») arrêtée à 16 h 47, sans livrable | `<racine>\fo-logs\2026-10-22_V3S\` (première passe : `industriel\`, `hightech\`, `hybride\`, `juges\`, `presentation\`) ; `<racine>\fo-logs\2026-10-22_V3S-synthese\` |
| **V3-T** emprise croissante et agrandissement sur place (Q23, Q24) | ✅ intégré le 22/10 à 14 h 50 (`13b4134`, version 0.4.2) ; moteur réel `content` 238 OK ; activé pour la mitrailleuse seule ; aucun visuel nouveau ; non prouvé en moteur réel : panneau et aperçu au sol, transfert autre que munitions et PV, remboursement F40, machines agrandies (la migration d'une vraie sauvegarde est prouvée depuis : ligne suivante) | E44, F70 à F75 ; `<racine>\fo-logs\2026-10-22_V3T\` (notes `NOTES_V3T.md`, `content-final`, captures de la phase initiale), `<racine>\fo-logs\2026-10-22_V3T-integration_content\` |
| **Suites de V3-T** : H-T3, bancs hors jeu, d4m | ✅ intégrées le 22/10 (fusions `e1a6a6f`, `1f2ff79`, `18a00d4`, puis `c4d37e5`) ; version inchangée (0.4.2). Moteur réel sur `main` : `content` 238 OK (17:06:23) ; migration réelle 0.4.1 → 0.4.2 : 29 OK, journal 7 OK (17:06:44). H-T3 : (1) prouvée en moteur réel ; (2) prémisse réfutée (F77) ; filet prouvé seulement en expérience de contrôle. Hors jeu : migration 60, harness avec la règle des points de jeu (0 violation), api_lint 447, d4m 5/5. Non prouvé, entre autres (liste complète : RD_LOG E46 à E48) : rechargement d'une carte déjà migrée, défense dense, amélioration d'une mitrailleuse laissée hors grille, contact bord à bord de `find_entities_filtered` en moteur réel, machines agrandies en moteur réel | E46 à E48, F76 à F82 ; `<racine>\fo-logs\2026-10-22_V3T-suites\` (`ht3\`, `harness-mock-levels\`, `d4m\`, chacun avec ses `NOTES.md`), `<racine>\fo-logs\2026-10-22_V3T-suites-integration\` (`content\`, `ht3-migration\`) |
| **V3-E** direction artistique par époque de la mitrailleuse | ✅ **Designs des 15 âges validés par le DC** (23/10, 14 h 50) : âges 1 à 12 de la passe 5 (E65), ère V cosmique (13 Antimatière, 14 La Porte, 15 Néant ; `6d0e961`). Branche `v3e-final` fusionnée dans `main` (`93e3d89`, outils de rendu seulement). Rendus définitifs : âges 1 à 12 dans `<racine>\fo-logs\2026-10-23_V3E-p5\bas|haut\sprites\`, âges 13 à 15 dans `<racine>\fo-logs\2026-10-23_V3E-ereV\sprites\` (les e13 à e15 de `V3E-p5\haut` et `final` sont l'ANCIENNE ère V refusée : `REFUSES.txt`). Test final (run `wf_c46edecb-f29`) : couleur 13 et 15 sur 15, gris 5 et 5, pose N 7 cheminées sur 15, écarts 2,6. Pages : https://claude.ai/artifact/7weEHAY2ieT2zcFvW1UcTc (finale), https://claude.ai/artifact/XgfoS5rkCyUbbPYRgLvnyg (suivi). **En jeu depuis 0.4.6** (lot A2, ligne plus bas). Suite : plan `<racine>\fo-logs\2026-10-23_plan-suite\PLAN_SUITE.md` (page DC https://claude.ai/artifact/HqmTtxz3dajFS4fnc4a6xV ; questions Q-P1 à Q-P3) ; run `wf_2bade7c0-0e8` (lancé vers 15 h 55, terminé) : A1, K0 et M0, chacun dans son worktree avec vérification adverse et correction ; sorties `<racine>\fo-logs\2026-10-23_suite\` ; A1 et M0 fusionnés à 17 h 44, K0 en cours d'intégration (lignes ci-dessous) | `<racine>\fo-logs\2026-10-23_V3E-p5\` ; `<racine>\fo-logs\2026-10-23_V3E-ereV\` ; `<racine>\fo-logs\2026-10-23_plan-suite\` |
| **V3-T2** emprise croissante des 5 autres familles (Q-S1 : oui) | ✅ intégré le 22/10 à 19 h 05 (fusion `--no-ff` `681dd5c` de `worktree-wf_04ba1f63-d67-1` : ingénieur `3e9a23e`, `f5f6a77`, `be0ee03` ; correcteur `e84ca84`), **version 0.4.3** ; changelog `aec3baf`. Moteur réel sur `main` : `content` 317 OK, `t2-machines` 80 OK, `t2-migration` 64 OK + journal 26 OK, `ht3-migration` 30 OK + journal 7 OK (`done.txt` 19:05:39 à 19:05:52). Hors jeu : migration 79, levels 1575, api_lint 519, test_ht3_journal 15, le reste inchangé. Revue : 19 défauts, le majeur confirmé par témoin (`be0ee03` : 308 OK, 9 échecs dont 1 artefact du témoin) et corrigé. Visuel provisoire, laid aux grandes tailles, sans verdict du DC. Questions Q-T2-1 et Q-T2-2 posées au DC. Non prouvé : liste dans RD_LOG E49 à E52 | E49 à E52, F83 à F95 ; `<racine>\fo-logs\2026-10-22_V3T2\` (`NOTES_V3T2.md`, passages de l'ingénieur et du correcteur, captures, `src-0.4.2` à GARDER), `<racine>\fo-logs\2026-10-22_V3T2-integration\` |
| **R1** robustesse : défense dense, contact bord à bord, atlas virtuel | ✅ intégré le 22/10 (run `wf_c34819e9-18a`, lancé à 19 h 38, session `8a9c0503` ; deux suites, chacune constructeur, revue adverse, correcteur ; fusions `dcc97b3` de `worktree-wf_c34819e9-18a-1`, tête `f41753d`, et `58db82c` de `-2`, tête `75863a5` ; changelog 0.4.3 complété, `870f045`) ; version inchangée (0.4.3). Moteur réel sur `main` (`done.txt` 20:11:14,81 à 20:11:40,52) : `content` 317, `t2-machines` 80, `bord-a-bord` 12, `t2-migration` 64 + 26, `ht3-migration` 30 + 7, `t2-defense` 36 + 19 (création 0.4.1) et 36 + 11 (0.4.2). Hors jeu : migration 81, levels 1577, api_lint 535, mut_vram 18/18, le reste inchangé. Défense dense : elle marche, 13 tourelles sur 21 laissées depuis 0.4.1, visuel laid NON jugé (E54). Contact bord à bord RENDU par le moteur réel (F96), moteur simulé aligné (21 écarts sur 45, puis 0 ; E53) ; `move_ground_items` corrigé (défaut du mod trouvé par la revue). `vram.py` compte l'atlas virtuel (E55) ; le « 14/14 » du constructeur vram était FAUX (13/14). Revues : 2 majeurs et 6 mineurs, tous confirmés et corrigés. Non prouvé : liste dans RD_LOG E53 à E55 | E53 à E55, F96 à F102 ; `<racine>\fo-logs\2026-10-22_R1\` (`defense\NOTES.md`, `defense\correcteur\`, `defense\captures-t2-defense-0.4.1\` ; `vram\NOTES.md`, `vram\correcteur\`), `<racine>\fo-logs\2026-10-22_R1-integration\` |
| **V3-T3** bouton « Libérer la place » (Q-T2-1 : « QT21 option B ») | ✅ intégré le 22/10 à 22 h 50 (run lancé à 21 h 10, session `8a9c0503` ; ingénieur, revue adverse à 3 regards, correcteur ; fusion `8a28804` de `worktree-wf_49a2ed53-111-1` : ingénieur `f26e9c3`, correcteur `d0b40da` ; changelog 0.4.4, `4a7a365`), **version 0.4.4**. Moteur réel sur `main` (`done.txt` 22:50:45,71 à 22:51:53,59) : `content` 317, `t2-machines` 80, `bord-a-bord` 12, **`t3-libere` 41**, `t2-migration` 64 + 26, `ht3-migration` 30 + 7, `t2-defense` 36 + 19 et 36 + 11, **`t3-migration` 7** (1 000 ticks ; le premier passage à 700 ticks, trop court, n'a pas de BILAN). Hors jeu : migration 82, levels 1642, api_lint 609 (615 annoncés par le correcteur dans son worktree : écart non expliqué), le reste inchangé. Revue : 24 défauts, dont 2 bloquants (plan partiel exécuté, Annuler pas sûr), 23 traités, 1 réfuté. **Limites** : rangées collées (5 libérables sur 19 dans l'usine dense, 2 sur 13 dans la défense dense) ; fils de circuit non refaits ; joueur réel non joué ; noms de prototypes en chaînes dans `global.fo.levels_free.names` (écart à « nombres seulement », ARCHITECTURE §7 bis, signalé par le correcteur comme écart à faire valider, pas encore soumis au DC). Non prouvé : liste dans RD_LOG E59 | E56 à E59, F103 à F110 ; `<racine>\fo-logs\2026-10-22_V3T3\` (`NOTES_V3T3.md`, §5 du correcteur qui fait foi ; `correcteur\captures-t3-libere\`, 4 images), `<racine>\fo-logs\2026-10-22_V3T3-integration\` |
| **V3-T4** la production suit la surface (Q-T2-2 : réponse A) | 🟨 **livré, NON intégré** (run lancé à 21 h 15, session `8a9c0503` ; ingénieur, revue adverse à 3 regards, 23 défauts, correcteur ; branche `worktree-wf_9d38a6df-249-1`, partie de `e27bda9`, tête `2b18742`, version non changée). Raison : **Q-T4-1** (§3) : densité tenue (production par tuile croissante, mesurée), rentabilité non tenue (foreuse 29 → 30 remboursée en 510 h, contre 342 h en 0.4.3 ; four et assembleur à valeur ajoutée nulle). Sur la branche : `content` 331, `t4-production` 21 (5 300 ticks), autres bancs verts ; levels 1 615 + 23 écarts connus, api_lint 558. Pour l'intégrer après la réponse : fusion sur 0.4.4 (conflit attendu avec V3-T3 dans `tests/levels_test.lua`, seul fichier modifié des deux côtés, vérifié par `git merge-tree`), `levels_test.lua --calibrate`, renumérotation des identifiants cités dans le code (F111 à F118, E60 à E62), tous les bancs | E60 à E62, F111 à F118, H-T4-1 ; `<racine>\fo-logs\2026-10-22_V3T4\` (`NOTES_V3T4.md`, §9 du correcteur qui fait foi ; `tables_BALANCE_SHEET_12_corrige.md` ; passages `01_` à `23_`) |
| **A0** ménage et garde-fous (plan, étapes 1 et 2) | ✅ fait : fusion de `v3e-final` (`93e3d89`), `REFUSES.txt`, identifiants réservés, phrases du DC inscrites, déplacement Q-P1 fait (1 776,5 Mo vers `C:\Users\evan2\fo-archives\fo-logs\`) ; seuil de 1 Go libre dans `with_render_lock.py` (A3-préparation, 24/10) ; **tri des worktrees le 24/10 vers 4 h 20** : 35 worktrees fusionnés dans `main` et propres retirés par `git worktree remove` (branches gardées) ; 37 restent (non fusionnés, dont V3-T4 en attente de Q-T4-1 et les branches V3 phase 1 ; avec des modifications ; ou de vérificateurs, à HEAD détachée) ; copies du mod (`mods\`, 59 Mo par banc) retirées des 6 archives d'intégration du 23 et du 24/10 (2,16 Go ; journaux gardés ; le script des bancs ne les copie plus) ; H: passe de 7,7 à 11 Go libres. Le magasin des feuilles hors du mod (D-6 B) est remplacé par la décision D-6 (feuilles dans le mod, hors de git), appliquée par A2 | RD_LOG, décisions du 23/10 ; OBJECTIFS §7 |
| **A1** rose des 8 directions, E66, E67, E70 | ✅ fusionné le 23/10 à 17 h 44 (`5a95650` ; constructeur `44e0a4b`, correcteur `741917a`), outils seulement, version inchangée. Dégel D-9 de `piece.py` prouvé (36 fichiers sur 36 identiques octet à octet) ; rose : 112 têtes en aperçu, **19 trous enfermés sur 112** (à trancher avant A3), pose N toujours « cheminée » à 8 âges, page https://claude.ai/artifact/3wt4uyQfxBLigQEXfZ14Vv (pas de verdict du DC) ; E66 : gain 44,7 % (le 51 % de la première mesure était faux, défaut majeur de la vérification, corrigé) ; E67 : garde du kit fausse (INT-GARDE) ; E70 : `orientation` pour orienter une tête à l'arrêt ; `a1-tourelle` 5 OK sur copie jetable | E66, E67, E70, F120 à F122 ; `<racine>\fo-logs\2026-10-23_suite\A1\` (`NOTES.md`, `INTEGRATION.md`, `verification.md`, `rose\`, `e66\`, `moteur\`) |
| **M0** socle du monde : monnaies des âges 5, 7, 8 garanties | ✅ fusionné le 23/10 à 17 h 44 (`da2e16f` ; constructeur `28fe15b`, correcteur `d6766d7`), **version 0.4.5**. Moteur réel sur `main` : `monde` 89, `m0-reprise` 15, `m0-migration` 9, tous les bancs existants verts ; hors jeu : `monde_test` 157, api_lint 669. Vérification : M-1 (échec définitif et muet) corrigé ; M-2 (générateur depuis `X.resources` et `X.tiles`) REPORTÉ aux lots X par l'orchestrateur ; 9 mineurs non traités (accès à pied, pire cas 767 ms, message perdu à `on_init`, décor, factions, sauvegarde de migration quasi vide, garantie non générique, anomalie des graines 1 et 42). Questions Q-M0-1 et Q-M0-2 (§3) | E73 à E76, F130 à F135 ; `<racine>\fo-logs\2026-10-23_suite\M0\` (`NOTES.md` §6 du correcteur, `INTEGRATION.md`, `verification.md`, `correction\`, `captures-2\`), `<racine>\fo-logs\2026-10-23_integration-0.4.5\` |
| **K0** kit commun des familles | ✅ intégré par INT-K0 (fusion `e4e8416`) ; branche `worktree-wf_2bade7c0-0e8-2`, constructeur `0cee947`, tête `87c4fb1`. Aucun design validé changé (empreinte FORTE, 72 variantes et 165 habillages, graines comprises). Vérification : 4 majeurs du lot corrigés ; 1 majeur antérieur NON corrigé (F136, graines inertes : décision du DC) ; 5 mineurs dits (dont `stone-wall` non mesuré et la séparation des âges 4 et 5 par la seule saturation) | E71, E72, F136 ; `<racine>\fo-logs\2026-10-23_suite\K0\` (`NOTES.md` section « Correction », `INTEGRATION.md`, `verification.md`, `correction\`, `D3_ere_V.md`) |
| **INT-K0, INT-GARDE, INT-GRAINE** | ✅ fusionnés vers 18 h 40 (`e4e8416`, `b80f2bb`, `0db5493`), version 0.4.5 inchangée ; kit commun sur `main` sans design changé ; garde des durées selon E67 (levels 1 661) ; `FO_MAP_SEED` (défaut 20261020 ; `$env:FO_MAP_SEED = $null` après usage, F139) ; bancs verts (`content` et `monde` aussi sur la graine 123456789) | `<racine>\fo-logs\2026-10-23_suite\INT-*\` ; `<racine>\fo-logs\2026-10-23_integration-0.4.5-b\` ; F137 à F139 |
| **A2** la mitrailleuse en jeu à 4 directions (plan, étape 3) | ✅ fusionné le 23/10 vers 20 h 50 (run `wf_0143e61e-944` ; constructeur `ba9edef`, correcteur `4837368` ; fusion `e0088bd`), **version 0.4.6** (`ef64f79`). Les 30 niveaux portent les designs validés : socle, pièce des niveaux pairs, tête à 4 directions, lueurs, halos, ombres, icône par âge, éclat de tir au bout des canons (E68), reste et explosion à la taille de l'emprise. Feuilles : décision D-6 (`graphics/levels/gun/`, 318 PNG hors de git, à régénérer par `feuilles.py` dans tout checkout ou worktree neuf, CLAUDE.md §5). Vérification : 4 majeurs, tous corrigés. Moteur réel sur `main` 0.4.6 : tous les bancs verts, `gun-rose` 11 OK, 90 captures ; hors jeu : levels 1662, api_lint 676, mut_atlas 50. Page DC https://claude.ai/artifact/DcVt6j6PVctVQteegWJamt (rien à valider). Non prouvé et mineurs : `NOTES.md` §13.7 (bouchon par secteur à trancher avant A3 ; restes et explosions jamais vus en destruction ; icônes d'âge jamais vues dans l'interface) | E68, F123 à F129 ; `<racine>\fo-logs\2026-10-24_A2\` (`NOTES.md` §13, `INTEGRATION.md`, `verification.md`, `correction\`, `sprites\` à GARDER) ; `<racine>\fo-logs\2026-10-23_integration-0.4.6\` |
| **S0** la chaîne des sons (plan, étape 5) | ✅ fusionné le 23/10 vers 22 h 55 (run `wf_e1ae9f59-b47` ; constructeur `cdf8d32`, correcteur `e3a50dc` ; fusion `4593893`), **version 0.4.7** (`e4d9e03`). Tir de la mitrailleuse par ère (20 OGG commités dans `sound/levels/gun/`), règle « sons » du harness, `FO_AUDIO=1` (pilote SDL `disk`, garde de crête `audio_guard.py`, code 10). **Défaut bloquant corrigé** : des sessions de test « volumes à 0 » ont émis du son chez le DC (21 h 30 à 22 h 15) ; faute de consigne de l'orchestrateur (aucune mesure du silence exigée). Sons PROVISOIRES : Q-S0-1, page https://claude.ai/artifact/Ap4JoXCgvxJJR29b5QceU3. Non prouvé : tir joué en jeu ; source du fond sonore (F152) | E69, F150 à F154 ; `<racine>\fo-logs\2026-10-24_S0\` (`NOTES.md` §7, `INTEGRATION.md`, `verification.md`, `correction\`, `ecoute\`) ; `<racine>\fo-logs\2026-10-23_integration-0.4.7\` |
| **S0-suite** suites des sons | ✅ fusionné le 24/10 vers 2 h 30 (`4ffd852`), **version 0.4.8** : tir joué en jeu prouvé (`s0-tir` + `tools/sound/tirs_joues.py`, E113), règle Vorbis du harness (`mut_sons.py` 6 OK), volume par ère (D-11). Banc des tirs entendus instable à la marge (1 échec sur 5) | E113, F155, F156 ; `<racine>\fo-logs\2026-10-24_S0-suite\` ; `<racine>\fo-logs\2026-10-24_integration-S0-suite\` |
| **A3-préparation** têtes à 64 directions (plan, étape 4) | ✅ fusionné le 24/10 vers 0 h (run `wf_e1ae9f59-b47` ; constructeur `16121ec`, correcteur `9c16e3d` ; fusion `a7f1166`), outils seulement, version inchangée. D-7 (ombre à 32, identité prouvée, 42,8 %), D-10 (bouchon par secteur mesuré et rampe 80 %), masques rapides, 72 trous acceptés, garde de 1 Go dans `with_render_lock.py`, `produire_a3.py` reprenable (défaut majeur M-1 corrigé). ⏳ **Production lancée à 0 h 00 sur une place** (768 têtes, 8 à 10,5 h). Non prouvé : verdict du DC (rotation, rampe, trous), mémoire vidéo réelle, limite de 8 192 px en moteur | E105 à E108, F140 à F145 ; `<racine>\fo-logs\2026-10-24_A3\` (`NOTES.md` §14, `INTEGRATION.md`, `verification.md` ; `sprites\`, `masques\m16\`, `bouchon\rampe80\` à GARDER) |
| **A3-jeu** têtes à 64 directions en jeu | 🟨 fusionné le 24/10 vers 3 h 55 (`3fe1da6`), **version 0.4.9** : âges 2 à 8 à 64 directions, 9 à 15 à 4 en attendant la production ; constructeur coupé par une panne des serveurs (529), repris (`6bd7a46`), vérifié, corrigé (`1e09519`, majeur : éclat de l'âge 2) ; D-12 (directions écartées et têtes « HORS REGLE » regardées, listées dans `feuilles.py`). **Reste** : après la production, suivre `FINALISATION.md` (régénérer les feuilles SANS option : tous les âges finis passent à 64 ; regarder les directions écartées prévues, dont d39 de l'âge 12 ; bancs, captures, D4m ; version 0.4.10) | E109 à E111, F146 à F148 ; `<racine>\fo-logs\2026-10-24_A3-jeu\` (`NOTES.md`, `INTEGRATION.md`, `FINALISATION.md`, `verification.md`, `outils\`) ; `<racine>\fo-logs\2026-10-24_integration-A3-jeu\` |
| **D4m-géant** banc de l'usine géante recalé | ✅ fusionné le 24/10 vers 5 h 45 (`d7efe80`) : `d4-geant` 18 OK sur `main` (F128 résolu, F161, F162, E117 ; galerie des têtes à 64 images par âge) ; `fo-captures.bat` recopié à la racine (code 8 sur un banc en échec). C'est le banc de la mesure D4m finale d'A3-jeu (`--ticks 3900` pour les passages `--measure`) | `<racine>\fo-logs\2026-10-24_D4m-geant\` (`NOTES.md`, `INTEGRATION.md` dont le tableau de référence à 7 âges) ; `<racine>\fo-logs\2026-10-24_integration-D4m-geant\` |
| **A4-préparation** la mitrailleuse vivante | ✅ fusionné le 24/10 vers 7 h 30 (`ab4f1b6`), **version 0.4.10** : éclat de tir 2D par âge et par direction (une image, dessin A provisoire, F149), restes et explosions vus en destruction (F157, F160), socle animé en ESSAI sur l'âge 6 (F158 ; sources à GARDER : `<racine>\fo-logs\2026-10-24_A4\socle-anime\sprites\`), masque d'équipe essayé et non branché (F159) ; D-13 ; questions Q-A4-1 à Q-A4-3 | E112, E114 à E116 ; `<racine>\fo-logs\2026-10-24_A4\` (`NOTES.md` §5 : suite après la production) ; `<racine>\fo-logs\2026-10-24_integration-A4\` |
| Test de Stable Diffusion local | ✅ fait (E42) : utile pour l'inspiration et l'img2img depuis un sprite existant, jamais pour des sprites finaux ; planche envoyée au DC | `<racine>\fo-logs\2026-10-22_SD-test\` |

## 3. Ce qui reste ouvert chez le Directeur Créatif
- **Page du matin (24/10, 7 h 45)** : https://claude.ai/artifact/CvFvAYSx4c1nLd3nJMFccp : ce que la nuit a donné (0.4.10)
  et les questions en attente : Q-S0-1 (sons), Q-A4-1 (éclat A ou B), Q-A4-2 (socle animé), Q-A4-3 (couleur d'équipe),
  confirmation de Q-P3 (B ou C). À mettre à jour quand les 15 âges sont à 64 directions (A3-final).
- **Page d'écoute S0 (23/10, 23 h)** : https://claude.ai/artifact/Ap4JoXCgvxJJR29b5QceU3 ; question **Q-S0-1** (OBJECTIFS §4) : pour
  chaque ère, garder, changer ou refaire le tir. Les sons sont en jeu depuis 0.4.7, provisoires.
- **Page A2 (23/10, 21 h)** : la mitrailleuse dans le vrai jeu, version 0.4.6
  https://claude.ai/artifact/DcVt6j6PVctVQteegWJamt (rien à valider ; vu : 4 directions seulement, pose N « cheminée », pose S
  canons vus de face, nuits très sombres, ombre de la tête sur le sol seulement).
- **Pages pour le DC (23/10)** : finale de la mitrailleuse https://claude.ai/artifact/7weEHAY2ieT2zcFvW1UcTc ; plan de
  la suite https://claude.ai/artifact/HqmTtxz3dajFS4fnc4a6xV ; rose des 8 directions (lot A1)
  https://claude.ai/artifact/3wt4uyQfxBLigQEXfZ14Vv (aucun verdict ; à regarder surtout : pose N « cheminée », pose S
  où l'arme se perd au zoom 1, trous enfermés en S).
- **Q-P3 À CONFIRMER** (OBJECTIFS §4) : réponse du 23/10 vers 16 h 20 « pour la question 3 on fait la C, long mais
  tant pis » ; or C était l'option la PLUS COURTE (un seul design par machine, 28) et « long mais tant pis » désigne
  plutôt B (un design par âge, environ 190). Confirmation demandée dans le chat vers 16 h 25, sans réponse à 18 h 30.
  Sans incidence avant les lots X. Q-P1 (A, appliquée) et Q-P2 (A : 64 positions) sont répondues.
- **Q-M0-1 et Q-M0-2, PAS encore posées dans le chat** (OBJECTIFS §4, lot M0) : Q-M0-1, site garanti TOUJOURS posé
  dans une partie neuve (A, actuel, recommandé) ou seulement si la graine n'en a pas (B, environ 2 s de plus à la
  création et une sauvegarde plus grosse) ; Q-M0-2, disque net de cendres (A) ou adouci avec le kit sol de M2 (B,
  recommandé quand ce kit existera). Captures : `<racine>\fo-logs\2026-10-23_suite\M0\captures-2\`.
- **À soumettre au DC, pas encore posé** : (1) F136, les graines de bruit du pipeline sont inertes : les activer
  changerait tous les designs validés (recommandation : ne rien changer pour la mitrailleuse ; décider pour les
  familles suivantes) ; (2) foyers des âges 4 (Pétrole) et 5 (Volcan) de même teinte orange, séparés par la seule
  saturation (question proposée par le correcteur de K0 : A garder, B Volcan vers le rouge avec nouveau rendu des
  âges 5, C Pétrole vers le jaune) ; (3) trous enfermés de la rose (19 sur 112) : combler par une pièce de fond, ou
  accepter en S, avant A3.
- **V3-S : verdict rendu** le 22/10 à 16 h 45 (style retenu, « parfaits », « époustouflants surtout pour les
  canons » ; il manque une direction artistique par époque : lot V3-E). Prochain regard : les planches V3-E.
- **Q-T4-1, posée dans le chat le 22/10 vers 22 h 45, OUVERTE** (OBJECTIFS §4 ; lot V3-T4, RD_LOG E62) : rentabilité
  des améliorations et « idle massif ». A = vrai idle (chaque niveau produit nettement plus que le précédent, les
  coûts montent aussi vite, chaque amélioration se rembourse en moins d'une heure de jeu, la partie garde environ
  60 h ; gros rééquilibrage) ; B = garder la progression actuelle (on améliore pour avancer d'époque, pas pour la
  rentabilité). Recommandation de l'orchestrateur : A. V3-T4 attend cette réponse sur sa branche ; le jeu garde
  l'équilibre de 0.4.3. Questions proposées par le correcteur de V3-T4, PAS encore posées : place des coûts dans le
  coffre du centre, tourelles (Q14 dépassé, PV par tuile, laser face aux blindés), contrats d'avant (2 000 objets,
  × 16 par bâtiment), modules et balises.
- **Question À POSER avec les planches V3-E : les rangées collées** (lot V3-T3, RD_LOG E59, défaut 13 de sa revue).
  Le bouton « Libérer la place » ne libère qu'un bâtiment qui a un côté libre : au milieu d'une rangée collée, un
  voisin gêne toujours (5 libérables sur 19 dans l'usine dense de test, 2 sur 13 dans la défense dense). Options
  proposées par le correcteur : (a) déplacer aussi les voisins, en cascade ; (b) agrandir une rangée entière d'un
  coup ; (c) accepter la limite. Pas encore posée : à envoyer avec les planches V3-E, pour ne pas multiplier les
  messages au DC.
- **Q-T2-1 et Q-T2-2 : RÉPONDUES le 22/10** (« QT21 option B » à 21 h 06 ; « QT22 […] donc A » à 21 h 12, après une
  reformulation : citations dans OBJECTIFS §4 et RD_LOG). Q-T2-1 appliquée par V3-T3 (0.4.4), avec la limite des
  rangées collées ; Q-T2-2 appliquée en partie par V3-T4, non intégrée (Q-T4-1). Énoncé d'origine, pour mémoire :
- Q-T2-1 et Q-T2-2, posées le 22/10 à 19 h 20 (lot V3-T2, OBJECTIFS §4) :
  - Q-T2-1, usine réelle : une machine bordée de ses bras sur deux côtés opposés ne grandit jamais sans démontage ;
    à la migration d'une usine dense de 24 machines, 18 restent hors grille (75 %). Options de la revue : accepter
    tel quel, décaler automatiquement les bras collés (piste de Q-T3), ne faire grandir la machine qu'à sa repose à
    la main, amélioration en rangée ; option ajoutée par l'orchestrateur : un bouton « libérer la place ». Aucune
    n'est conçue. Recommandation de l'orchestrateur : garder la règle Q24 et ajouter ce bouton. Q-T3 (mitrailleuse
    collée aux murs) y est rattachée. Complément du 22/10 à 20 h 21 (lot R1, E54) : sur une défense dense créée par
    0.4.1, 13 tourelles sur 21 sont laissées : les 8 du tronçon A, hors grille, se chevauchent entre elles ; les 5
    du tronçon C chevauchent le mur, le convoyeur, les poteaux et les bras ; depuis 0.4.2, 5 lasers laissés : 3 hors
    grille sans chevauchement (A), 2 qui chevauchent convoyeur, poteaux, un bras et leurs voisines (C), aucun mur ;
    sur les captures, les poteaux semblent plantés au milieu des sprites de A (effet du dessin, pas un chevauchement
    de boîtes) ; 21 sur 21 tirent,
    63 ennemis sur 63 tués ; deux captures attendent son regard
    (`<racine>\fo-logs\2026-10-22_R1\defense\captures-t2-defense-0.4.1\`) ;
  - Q-T2-2, production par tuile qui baisse quand la machine grandit (niveau 6 → niveau 30 : assembleur 0,117 →
    0,069, four 0,700 → 0,184, foreuse 0,083 → 0,054, tourelles laser et mitrailleuse 0,35 → 0,059 ;
    BALANCE_SHEET §12). Le joueur a intérêt à ne faire que le minimum d'améliorations exigé par Q16. Options : la
    production suit la surface, prestige assumé, ou autre. Recommandation de l'orchestrateur : la production par
    tuile ne doit pas baisser. Son argument (la Compaction ×4) est un avis, pas un constat : B1 porte sur le débit
    par tapis des paliers T1 à T5, pas sur le niveau d'une même machine.
  (Réponses reçues depuis : voir ci-dessus.)
- Q-V2c-1 et Q-V2c-2 : rythme du centre et chemin le plus court vers l'époque 15 (OBJECTIFS §4).
- Q-S1 à Q-S3 : **répondues oui** par le DC le 22/10 à 16 h 45 (échelle pour toutes les familles, plafond 6×6
  pour les machines, centre 4 → 8, mur inchangé ; luminance de la charte pour toutes les époques ; regard naïf
  par des agents sans contexte).
- Q-IA1-1 à Q-IA1-7 : équipes de PNJ (OBJECTIFS §4, avec les recommandations).
- Critères marqués ❔ (C4, C5, D4…) : à faire valider quand l'occasion se présente.
- Répondues récemment : Q19 (amélioration instantanée), Q20 et Q21 (mémoire vidéo, basse qualité
  soignée), Q22 (carte blanche la nuit du 21 au 22/10, terminée), Q23 (taille et puissance perçue), Q24
  (agrandissement sur place si la place est libre), Q-T2-1 (B, 22/10, 21 h 06) et Q-T2-2 (A, 22/10, 21 h 12).

## 4. Branches et worktrees (`.claude/worktrees/`)
- **Fusionnées** : tout ce qui est marqué ✅ au §2.
- **Fusionnées le 23/10** : `worktree-wf_2bade7c0-0e8-1` (lot A1, tête `741917a`, fusion `5a95650`) et
  `worktree-wf_2bade7c0-0e8-3` (lot M0, tête `d6766d7`, fusion `da2e16f`).
- **En cours d'intégration** : `worktree-wf_2bade7c0-0e8-2` (lot K0, tête `87c4fb1`) : fusion par le lot INT-K0 (run
  `wf_2f1793c9-578`) ; ne pas la fusionner à la main pendant ce run.
- **Non fusionnées, à GARDER** :
  - `worktree-wf_9d38a6df-249-1` (lot V3-T4, tête `2b18742`, partie de `e27bda9`) : livrée, NON intégrée, en attente
    de la réponse du DC à Q-T4-1. Ne pas la fusionner telle quelle : elle précède V3-T3 (conflit attendu dans
    `tests/levels_test.lua`, seul fichier modifié des deux côtés, vérifié par `git merge-tree`), et son équilibre dépend de la réponse ;
  - `worktree-wf_1f9884be-7b6-1` à `-7` : V3 phase 1, dans l'ordre centre, mitrailleuse, laser, mur,
    foreuse, four, assembleur. On y trouve des scripts de modélisation, des planches et des mesures D1.
    Leur direction est rejetée, mais les silhouettes et les scripts servent de base à la reprise.
    Ne pas fusionner tel quel.
- **Non fusionnées, PÉRIMÉES** (remplacées, ne pas fusionner) :
  - `worktree-wf_faf731d3-78b-*` : première tentative de V3, interrompue ;
  - `worktree-wf_3d6c1ffd-8dd-1` : première tentative de V0b, interrompue.
  Elles peuvent être supprimées avec l'accord du DC.
- Les worktrees des workflows en cours appartiennent à leurs agents : ne pas y écrire.

## 5. Reprendre un travail interrompu (limite d'usage, crash)
- Workflow interrompu : relancez `Workflow({scriptPath, resumeFromRunId})`. Les agents terminés sont
  servis depuis le cache ; seuls les agents échoués repartent. Les scripts sont dans le dossier de
  session `…\workflows\scripts\`, et chaque notification donne le run.
- Avant de relancer un agent coupé en plein travail :
  - commitez le travail partiel de son worktree (« Travail partiel interrompu… ») ;
  - ajoutez à son brief une consigne de reprise (« git checkout <branche> -- <chemins> ») ;
  - ne modifiez QUE le texte des agents à relancer, sinon le cache des autres saute.
- Verrous orphelins : `fo-autotest.lock` se supprime avec `rmdir` si aucun factorio.exe de test ne tourne ;
  `fo-render.lock.<k>` est repris tout seul par `with_render_lock.py`.
- **Session entière coupée** (limite d'usage, vécu le 22/10 à 8 h 55) : `resumeFromRunId` ne marche QUE
  dans la session qui a lancé le workflow. Depuis une nouvelle session, on reprend ainsi :
  1. lire le run, qui donne le résultat des agents finis et l'ID des agents coupés :
     `~\.claude\projects\H--Factorio-v1-1-91-Modding\<session>\workflows\wf_<run>.json` ;
  2. commiter le travail partiel de chaque worktree ;
  3. extraire le journal de chaque agent coupé (`<session>\subagents\workflows\wf_<run>\agent-<id>.jsonl`).
     Exemple d'extraction : `fo-logs\2026-10-22_V3S\reprise\notes_*.txt` ;
  4. mettre à l'abri ce que les agents avaient écrit dans le dossier temporaire de l'ANCIENNE session ;
  5. lancer un nouveau workflow dont les agents reprennent ces worktrees.

## 6. Pièges d'outillage déjà payés
- **F69** : depuis Git Bash, `fo-captures.bat` avec une source entre guillemets échoue, parce que
  `cmd /c` coupe le chemin à l'espace. Lancez-le depuis **PowerShell**. `fo-autotest.bat` sans argument
  entre guillemets fonctionne depuis Git Bash.
- `fo-autotest.bat` rend le code **2** si le verrou est pris : rien n'a tourné. Vérifiez toujours
  l'heure de `done.txt`.
- api_lint ignore les chaînes et les commentaires Lua (correctif du 21/10).
- `pairs` en Lua 5.2 hors jeu est NON déterministe (graine de hachage aléatoire), contrairement au jeu.
  Triez toujours les clés.
- **Antislashs dans un heredoc Bash ou une commande sed/echo : piège payé TROIS fois** (le 22/10). Ils sont
  réinterprétés en route : `\fo-logs` devient un saut de page (`\f`), `\2026` un caractère octal. La première
  fois, 5 chemins de documents ont été abîmés puis réparés. N'écrivez
  JAMAIS de texte qui contient des antislashs par un heredoc, sed ou echo : utilisez l'outil d'édition, ou un
  script Python écrit dans un FICHIER avec des chaînes brutes `r"..."`. Contrôle final obligatoire : aucun
  caractère de contrôle (U+0000 à U+001F sauf saut de ligne et tabulation, U+007F à U+009F) et aucun octet CR
  dans les documents modifiés (`repare_ctrl.py`). Payé une 4e fois dans un commentaire de code du lot V3-T2
  (`checks/levels_points.lua`, ligne 26 : U+0082 et une tabulation ; relevé le 22/10 à 19 h 15, réparé dans le
  commit `98ac826`, relu propre le 22/10 à 20 h 20) : le contrôle vaut aussi pour les fichiers de code d'un lot, pas
  seulement pour les documents.
- **`run_d4m.py` se lance depuis Git Bash** : sous PowerShell, `lua5.2` n'est pas dans le PATH et le banc donne 2/5
  (constaté par le lot R1, 22/10).
- **Dossier temporaire de session partagé** : le 22/10 vers 20 h, le correcteur de la suite vram (lot R1) a lancé un
  nettoyage `rm -f <dossier temporaire>/*.txt` qui a visé le dossier temporaire de la session `8a9c0503`, partagé
  par d'autres agents ; des fichiers `.txt` d'autres agents ont pu y être effacés (liste inconnue ; rien dans
  `fo-logs` ni dans le dépôt). Un agent ne nettoie que ses PROPRES fichiers, nommés un par un.
- **PowerShell sous Claude Code : `Remove-Item Env:FO_CREATE_SRC` peut être refusé par la protection de
  chemin** de l'outil. Observé par l'orchestrateur le 22/10 vers 17 h 06 : la commande entière a été refusée
  avant exécution (« Remove-Item on system path 'H:\Factorio.v1.1.91' is blocked »), rien n'a tourné. Videz
  plutôt la variable avec `$env:FO_CREATE_SRC = $null` (le README de l'outillage, §1.1, le montre depuis le commit
  `116ed94`, 22/10, 17 h 33).
- **Ne jamais envoyer de message (SendMessage) à un agent d'un Workflow en cours.** Le 22/10 à 17 h 26, un
  retour envoyé aux deux constructeurs V3-E a créé une COPIE de chacun, relancée depuis son transcript, pendant
  que l'original continuait dans le workflow : deux écritures concurrentes dans le même worktree, signalées par
  l'agent lui-même. Pour corriger un agent en route : arrêter le workflow (TaskStop), commiter son worktree,
  éditer le script et relancer avec `resumeFromRunId`.
- **Disque H: presque plein** (30 Go, dont 8,6 Go pour ce dossier ; le reste n'est pas à nous). Le 22/10 à
  18 h 25 il ne restait que 505 Mo : l'orchestrateur a DÉPLACÉ (robocopy /MOVE, rien d'effacé) vers
  `C:\Users\evan2\fo-archives\` les caches de rendu régénérables et deux archives anciennes :
  `fo-logs\2026-10-22_V3S\hybride\cache`, `industriel\cache`, `hightech\work`,
  `tools\render\cache` des worktrees `wf_483106c7-c7f-2`, `-3`, `-4`, `fo-logs\2026-10-22_V3S-synthese`
  (passe arrêtée, sans livrable) et `fo-logs\2026-10-21_session5_fo-shots_anciennes`. Libre ensuite :
  2,67 Go. Ne JAMAIS déplacer les archives `fo-logs\*` qui contiennent un `visual.log` (le banc d4m les lit)
  ni les preuves citées par RD_LOG. Surveiller la place avant un grand lot de rendus ou de captures.
  **Fichiers H: : 16,3 Go libres depuis le 23/10 vers 16 h 25** (17 Go relevés à 18 h 14). Ce jour-là, le plan
  relevait 1,9 Go libres à 15 h 34 ; sur la réponse A du DC à Q-P1, l'orchestrateur a déplacé 1 776,5 Mo vers
  `C:\Users\evan2\fo-archives\fo-logs\` (104 `.npy` de `2026-10-22_V3E`, les PNG des 5 galeries P1 ; journaux laissés
  en place, un `DEPLACE_VERS_C.txt` par dossier). La place gagnée dépasse de loin ce déplacement : la différence ne
  vient pas du projet (cause inconnue). C: : 9,1 Go libres après le déplacement : ne plus y déplacer sans regarder. Le
  seuil de 1 Go libre avant chaque paquet de rendu (lot A0) n'est PAS encore écrit.
- Les agents déposent parfois des diffs pour l'intégrateur dans le dossier temporaire de la session,
  qui peut disparaître. Appliquez-les vite, ou copiez-les dans `fo-logs`.
- Le DC peut jouer pendant les bancs : jamais d'arrêt global de factorio.exe, fermeture ciblée seulement
  (CLAUDE.md §4).
- **Identifiants provisoires des lots parallèles** : V3-T3 et V3-T4 ont tourné en même temps et ont tous deux proposé
  F103 et suivants, E56 et suivants. Règle appliquée le 22/10 vers 23 h : le lot intégré garde ses numéros (son code
  les cite), l'autre prend le bloc suivant (correspondance dans RD_LOG, en tête des faits de V3-T4). À l'avenir,
  donner à chaque lot parallèle un bloc réservé dans sa tâche. Fait depuis le plan de la suite (blocs en tête de
  RD_LOG) ; même ainsi, un correcteur a débordé (M0 proposait E77, réservé à M1 et M2 : consigné dans E74 ; F135, hors
  du bloc F130 à F134, gardé car libre) : vérifier chaque identifiant proposé contre la liste des blocs.
- **`t3-migration` demande 1 000 ticks** : à 700 ticks (le nombre de `ht3-migration` et `t2-migration`), il s'arrête avant
  son contrôle, sans BILAN (payé le 22/10 à 22:51:02).
- **Python** : le `python` par défaut (3.14) a Pillow, mais PAS numpy. Les outils de mesure de la charte
  (`tools/da/`) se lancent avec `py -3.9` (numpy 2.0.2 et Pillow). Les scripts Blender utilisent le Python
  intégré à Blender (3.13).

## 7. Prochaines étapes, dans l'ordre

**Au 23/10, 21 h 15 :** les étapes 1 (INT-K0, INT-GARDE, INT-GRAINE) et 3 (**A2**, version 0.4.6) ci-dessous sont
FAITES. Prochain lot : **A3, 64 directions, rendu de nuit** ; à trancher au lancement : le bouchon arrière posé par
secteur (d20 à d44, âges 4 à 7 : saut visible à la frontière ?), le réglage des échantillons par passe (D-7, ombre à
32, E66), les trous enfermés de la rose (19 sur 112) ; identifiants réservés F140 à F149 et E105 à E108. Suites d'A2
non traitées (`NOTES.md` §13.7) : lueur du socle sous la tête dans la carte de lumière, `fo-captures.bat d4-geant`
code 0 malgré un banc en échec, restes et explosions jamais vus en destruction, icônes d'âge jamais vues dans
l'interface ; `d4-geant` à recaler sur les emprises de 0.4.3 (F128). Reste d'A0 : tri des worktrees, seuil de 1 Go.
⏳ **Lancé vers 21 h 25 : run `wf_e1ae9f59-b47`** (session `8a9c0503`), deux chaînes en parallèle, chacune constructeur,
vérificateur adverse, correcteur : **A3-préparation** (D-7 échantillons par passe ; D-10 bouchon posé là où la fente se
voit ; trous enfermés sur 64 directions ; garde de 1 Go dans `with_render_lock.py` ; `produire_a3.py` reprenable ;
pilote âge 5 complet + 8 directions de l'âge 15 ; estimation mémoire vidéo ; sorties `<racine>\fo-logs\2026-10-24_A3\`)
et **S0** (sons : E69 avec volume 0, outil, règle du harness, tir par ère, page d'écoute ; `<racine>\fo-logs\2026-10-24_S0\`).
Ensuite : l'orchestrateur fusionne A3-préparation et lance la production de nuit (`INTEGRATION.md` d'A3), puis A3-jeu.
**S0 : FAIT** (fusion `4593893` vers 22 h 55, version 0.4.7 ; ligne du §2). **A3-préparation : FAIT** (fusion `a7f1166` le 24/10 vers 0 h ; ligne du §2).
⏳ **PRODUCTION DES TÊTES EN COURS depuis le 24/10 à 0 h 00** : `cd <mod> && PYTHONUTF8=1 py -3.9 tools/render/pieces/levels/gun_e/produire_a3.py --places 1` (Git Bash, en arrière-plan ; sortie `<racine>\fo-logs\2026-10-24_A3\production-nuit.out`) ; 768 têtes ; fin prévue entre 8 h et
10 h 30. Surveiller : `grep "PROGRESSION\|ECHEC\|HORS REGLE\|FIN" <racine>/fo-logs/2026-10-24_A3/production.log | tail -5`.
**Si la session qui l'a lancée meurt** : vérifier qu'aucun `py -3.9 … produire_a3.py` ne tourne (jamais deux à la fois :
m-7), puis relancer la MÊME commande (reprenable : une tête faite et contrôlée n'est jamais refaite). Arrêt propre :
créer le fichier `<racine>\fo-logs\2026-10-24_A3\STOP`. Fin : code 0 ET « FIN … reste 0 ; … manquent 0 sur 768 ;
erreurs 0 » ; puis `--dry-run` (« reste : 0 ») et `--controle-seul`. Ensuite : planches et animations par âge
(`INTEGRATION.md` d'A3 §4) pour le DC, puis le lot **A3-jeu** (§6 du même fichier).
⏳ **Lancé le 24/10 vers 0 h 25 : run `wf_93b960d8-a9c`** (session `8a9c0503` ; le premier essai `wf_232ab1e0-846` a échoué
sans rien faire : session placée hors du dépôt git, aucun worktree possible), deux chaînes en parallèle, SANS Blender :
**A3-jeu** (intégration progressive : chaque âge passe à 64 directions dès que ses 64 têtes sont produites, sinon reste
à 4 ; feuilles, `gun.lua`, éclat sur 64 directions, contrôles, `gun-rose` à 16 directions, D4m, captures ;
`<racine>\fo-logs\2026-10-24_A3-jeu\`, dont `FINALISATION.md` à jouer après la production) et **S0-suite** (tir joué en
jeu prouvé par le pilote audio `disk`, règle Vorbis du harness, marge des rafales ; `<racine>\fo-logs\2026-10-24_S0-suite\`).
Page pour le DC (24/10, 0 h 15) : rotation de l'âge 5 en 64 positions https://claude.ai/artifact/Y7BegpQpCaDxAArCAEWjLt .
**S0-suite : FAIT** (fusion `4ffd852`, version 0.4.8). **A3-jeu : constructeur coupé par une erreur de serveur (529)** vers
2 h 20 après 3 commits ; reprise `wf_bcc3f79d-bc7` lancée à 2 h 33 (même worktree `wf_93b960d8-a9c-1`, elle lit le
journal du constructeur coupé : `subagents\workflows\wf_93b960d8-a9c\agent-a074dd25b02e28754.jsonl`). Si elle échoue
encore : relancer le script `workflows\scripts\a3-jeu-reprise-wf_17da36fe-9d2.js` de la session `8a9c0503`.
**A3-jeu : FAIT pour les âges 2 à 8** (reprise, vérification et correction ; fusion `3fe1da6`, version 0.4.9). **À faire
après la production** : `<racine>\fo-logs\2026-10-24_A3-jeu\FINALISATION.md` (dans `main`, plus dans le worktree), puis
page pour le DC (rotation des 15 âges en jeu), version 0.4.10, documents.
⏳ **Lancé le 24/10 vers 4 h 15 : run `wf_0e7edcdd-4f2`** (session `8a9c0503`), deux chaînes en parallèle : **A4-préparation**
(éclat de tir 2D par âge et par direction, restes et explosions vus en destruction, socle animé préparé avec un pilote
de 15 min de Blender au plus, essai du masque d'équipe ; `<racine>\fo-logs\2026-10-24_A4\` ; F149, F157 à F160, E112,
E114 à E116) et **D4m-géant** (banc `d4-geant` recalé sur les emprises de 0.4.3, F128 ; `<racine>\fo-logs\2026-10-24_D4m-geant\` ;
F161, F162, E117). Pendant un run, la session de l'orchestrateur reste DANS le dépôt du mod (sinon les worktrees des
agents ne se créent pas).

**Au 23/10, 18 h 30 (plan de la suite, `<racine>\fo-logs\2026-10-23_plan-suite\PLAN_SUITE.md` §3 ; étapes dans
OBJECTIFS §6) :**
1. Finir le run `wf_2f1793c9-578` : **INT-K0** (fusion du kit commun ; réparer `rose.py` et `e66.py` d'A1 qui
   importent `compo` ; rejouer l'empreinte forte contre `K0\correction\avant.json`, attendu « 0 différente(s) ») ;
   **INT-GARDE** (garde des durées d'animation des tourelles, E67) ; **INT-GRAINE** (`FO_MAP_SEED` ; recopier le
   `.bat` à la racine, puis rejouer `content` sur la graine par défaut et sur une autre graine, et `monde`) ; puis
   tous les bancs, et la mise à jour des documents (K0 fusionné ; chiffres de CLAUDE.md §5).
2. Reste d'A0 : magasin des feuilles hors de git (D-6 B, préalable d'A2) ; seuil de 1 Go libre avant chaque paquet
   de rendu ; tri des worktrees périmés (59 dossiers ; jamais un worktree en cours).
3. **A2 : la mitrailleuse EN JEU à 4 directions** (étape 3) : poses S et O en production, feuilles et manifeste,
   `prototypes/levels/gun.lua` sans visuel provisoire (bouche et douilles par âge : E68), règle du harness sur les
   fichiers d'images, scénario `gun-rose` (orienter par `orientation`, F122), D4m en haute, normale et plancher,
   captures zooms 1 et 2 jour et nuit ; à vérifier sur la première capture : F121 (la tête vise le nord-est en
   diagonale), l'ombre de la tête en moteur (E66), la tête qui mange le socle ; verdict du DC.
4. **A3 : 64 directions, rendu de nuit** (étape 4 ; Q-P2 : A) : environ 868 rendus ; avec l'ombre à 32 (E66, gain
   44,7 %) une fois le réglage d'échantillons par passe ajouté au kit (D-7) ; trancher avant les trous enfermés de
   la rose (19 sur 112).
5. Ensuite : A4 (éclats de tir, socle animé, ruines) et S0 (sons, E69) ; F1 à F6 (les 6 autres familles, avec le
   kit commun) ; M1 à M3 (monde), en parallèle ; puis Compaction et contenu des époques (OBJECTIFS §6).
6. Suites de M0 non traitées : accès à pied (m-1), pire cas de coût (m-2, rejet à bas coût par
   `calculate_tile_properties`, F132), message perdu à `on_init` (m-3), décor (m-5), sauvegarde de migration avec
   base et guerre (m-6), factions IA (m-7, à noter pour IA1), garantie générique (m-8, avec les lots X), anomalie des
   graines 1 et 42 (m-9) ; rejouer les `ia0-*` avant de citer leurs chiffres.
7. Suites d'A1 non traitées : rendre d06, d26, d38, d58 (les diagonales vues en jeu) avant de montrer la rose comme
   définitive ; `variants.get()` et `--kit --dirs` (D7) ; commiter `e66_compo.py` et `planches.py` (hors dépôt, D8) ;
   jouer `folding` et les autres animations, et une cible ennemie imposée.

**Historique de cette liste (avant le 23/10) :**
1. ~~V3-S~~ : fait. Charte intégrée (13 h 25), première passe jugée (E45), verdict du DC le 22/10 à 16 h 45 :
   style retenu ; il manque une direction artistique par époque.
2. Ensuite, sans attendre :
   - lot V3-E (run `wf_0608aa1f-b85`, lancé le 22/10 à 16 h 55, session `8a9c0503` ; sorties dans
     `<racine>\fo-logs\2026-10-22_V3E\`) : la mitrailleuse sur les 15 époques, même style, canons,
     tuyaux et accents selon la fiche de chaque époque (`docs/DESIGN_EPOQUES.md` §5) ; puis les 6 autres
     familles avec la même méthode, la taille croissante (Q23, Q-S1) et la charte ;
   - ~~la mécanique d'agrandissement sur place (Q24)~~ : **faite** (lot V3-T, intégré le 22/10 à 14 h 50),
     activée pour la mitrailleuse ; ~~les autres familles (Q-S1 : oui)~~ : **faites** (lot V3-T2, intégré le
     22/10 à 19 h 05, version 0.4.3, prouvé en moteur réel : E49 à E52).
   - Suites ouvertes du lot V3-T2 :
     - ~~attendre les réponses du DC à Q-T2-1 et Q-T2-2~~ : reçues le 22/10 (B et A) ; suites : lots V3-T3 et V3-T4
       ci-dessous ;
     - prouver en moteur réel la migration d'une machine EN fabrication : non jouable avec ce banc (`--create`
       sauvegarde la carte au tick 0) ; outillage à écrire ;
     - jouer les raccords du fluide de minage d'une foreuse et la boîte à fluide de SORTIE d'un assembleur (même
       code que les raccords joués) ; jouer une disposition d'usine réelle (insertion directe entre machines,
       balises) et l'amélioration d'une mitrailleuse laissée hors grille ; ~~une défense dense~~ : **jouée** (lot R1,
       E54) ;
     - filet sans montée de version pour 0.4.3, second chargement d'une carte migrée, doublons hérités sur une
       vraie carte 0.4.2 : non joués ;
     - ~~réparer le commentaire abîmé de `checks/levels_points.lua`~~ : **fait** (commit `98ac826`) ;
     - visuel : les sprites V3 (lot V3-E) remplaceront le visuel agrandi, laid aux grandes tailles.
   - ~~Lot R1 (robustesse)~~ : **fait et intégré** le 22/10 (E53 à E55). Suites ouvertes du lot :
     - attendre le verdict du DC sur l'aspect de la défense migrée (captures `captures-t2-defense-0.4.1`, Q-T2-1) ;
     - sélection, minage, remplacement et amélioration par le joueur d'une tourelle laissée : non joués ;
     - poser un objet au sol exactement bord à bord dans un banc en moteur réel (le correctif de
       `move_ground_items` n'est prouvé que hors jeu) ;
     - examiner les balayages par secteurs jointifs de `pvp.lua`, `sites.lua` et `war.lua` face au contact bord à
       bord (F96) ; aligner le filtre `position` seule du moteur simulé ;
     - trancher la résidence et le format des pages de l'atlas virtuel (F102) : session au plancher avec
       `compress-virtual-atlas` ou `streamed-atlas-physical-vram-size` fixés dans le `config.ini` de TEST ;
     - corriger `python vram.py --help` (UnicodeEncodeError cp1252 quand la sortie est redirigée, préexistant) ;
     - mettre à jour la copie `claude/*.md` du projet claude.ai, en retard (CLAUDE.md §8).
   - ~~Lot V3-T3 (« Libérer la place »)~~ : **fait et intégré** le 22/10 à 22 h 50 (version 0.4.4 ; E56 à E59).
     Suites ouvertes du lot :
     - poser au DC la question des rangées collées avec les planches V3-E (§3) ;
     - jouer le panneau et les boutons avec un vrai joueur, y compris le jeu à la main sans robots (époques 4 à 9,
       avant les robots de construction) ;
     - fils de circuit des gêneurs reposés : les refaire, ou faire décider ; coût bloqué au clic : non fait ;
     - jouer en moteur réel l'expiration, le bâtiment disparu, la place d'origine prise à l'annulation, la fusion de
       deux réseaux par un poteau reposé, et les familles foreuse, four, laser et centre ;
     - mesurer le coût en temps (H-L1 : `on_nth_tick(60)` et relevé au clic) hors des rendus Blender ;
     - expliquer l'écart api_lint (615 annoncés par le correcteur dans son worktree, 609 sur `main`) ;
     - faire valider par le DC (ou retirer) l'écart `levels_free.names` (noms de prototypes en chaînes dans `global`,
       ARCHITECTURE §7 bis), signalé par le correcteur comme « écart à faire valider » ;
     - refaire les captures de `t3-migration` (non refaites après la correction) ; le visuel attend le DC.
   - **Lot V3-T4 (la production suit la surface) : livré, NON intégré** (branche `worktree-wf_9d38a6df-249-1`, tête
     `2b18742`). Ensuite :
     - attendre la réponse du DC à Q-T4-1 (§3) ; selon la réponse, reprendre l'équilibre (pente, coûts) sur la branche ;
     - pour l'intégrer : fusion sur 0.4.4 (conflit attendu avec V3-T3 dans `tests/levels_test.lua`, seul fichier
       modifié des deux côtés, vérifié par `git merge-tree`),
       `lua5.2 tests/levels_test.lua --calibrate` (la sortie doit égaler la config), renumérotation des identifiants
       cités dans le code (F111 à F118, E60 à E62), tous les bancs, puis BALANCE_SHEET §12 depuis
       `<racine>\fo-logs\2026-10-22_V3T4\tables_BALANCE_SHEET_12_corrige.md` (pas le fichier sans « _corrige », périmé) ;
     - transmettre au lot propriétaire de X0 : `X.TECH_UNITS` et `X.milestone_production` × gain (sinon le calendrier
       réel raccourcit, 34 h) ;
     - questions proposées par son correcteur, à poser au DC le moment venu (§3).
   - ~~Suites de l'intégrateur proposées par V3-T~~ : **faites et intégrées** le 22/10 (règle des points de
     jeu du harness, moteur simulé à boîtes vanilla, attentes de `levels_test` tirées de la table, correction
     de d4m : E47, E48).
   - ~~H-T3 : prouver en moteur réel la migration d'une sauvegarde 0.4.1~~ : **fait** (E46), avec le statut
     exact « (1) prouvée en moteur réel ; (2) prémisse réfutée (F77) ; filet prouvé seulement en expérience
     de contrôle ».
   - Tâches ouvertes restantes (OBJECTIFS §7) : recharger en moteur réel une carte déjà migrée (**toujours non
     prouvé**) ; jouer l'amélioration d'une mitrailleuse laissée hors grille (liée aux questions Q-T3 et Q-T2-1) ;
     ~~compter l'atlas virtuel dans l'estimation de `vram.py`~~ : fait (R1, E55) ; ~~observer en moteur réel le
     contact bord à bord de `find_entities_filtered`~~ : fait (R1, E53, F96) ; ~~jouer une défense dense~~ : faite
     (R1, E54) ; ~~faire tourner une machine agrandie en moteur réel~~ : fait (V3-T2).
3. V4, contrôle visuel : gris, vignettes, recouvrement, gros plans, banc `content`, galerie jour et nuit
   en jeu, mesures D4 refaites avec les sprites V3 ; puis le verdict du DC.
4. Ensuite, en parallèle (Q18) :
   - Compaction ×4 (C1 à C5) ;
   - construction d'IA1 (12 lots, `docs/EQUIPES_PNJ.md` §16).
5. Contenu des époques X1 à X15 (`docs/SCENARIO_EPOQUES.md`), puis idle (E3).
6. Hypothèses encore ouvertes :
   - ~~H-T3~~ : branche (1) prouvée en moteur réel le 22/10 (E46) ; prémisse de la branche (2) réfutée (F77) ;
     filet prouvé seulement en expérience de contrôle ;
   - H-L1 : coût du système des niveaux, à mesurer sur banc épinglé. Mesuré en partie au lot V3-T2 : le corps de
     `Levels.resume_progress` à liste vide, 100 000 appels en boucle, coûte 0,10 à 0,38 µs par appel ; le coût de
     l'appel de l'abonnement `on_tick` par le moteur à chaque tick n'est pas mesuré (RD_LOG, H-L1). Restent :
     progressions en attente, recensement Q16 sur une grande carte, calcul de place du panneau et des points
     servis ;
   - H-X1 ;
   - H-V2 ;
   - H-B1 ;
   - H-T4-1 (lot V3-T4, non intégré) : cause du plafond de 30 tirs/s de la mitrailleuse (F111).
