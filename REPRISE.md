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
> **Dernière mise à jour : 23/10/2026, vers 18 h 30** (agent des documents du run `wf_2f1793c9-578`, session
> `8a9c0503` ; jalon : plan de la suite lancé ; lots **A1** (outils de la mitrailleuse : rose des 8 directions, E66,
> E67, E70 ; fusion `5a95650`) et **M0** (monnaies des âges 5, 7 et 8 garanties ; fusion `da2e16f`, **version 0.4.5**)
> fusionnés dans `main` à 17 h 44 ; bancs en moteur réel rejoués sur `main` de 17:45:17 à 17:46:17, hors jeu vers
> 17 h 50 ; lot **K0** (kit commun des familles) livré et corrigé ; **lots INT-K0, INT-GARDE et INT-GRAINE fusionnés vers
> 18 h 40** (`e4e8416`, `b80f2bb`, `0db5493`), tous les bancs rejoués verts sur `main` de 18:42 à 18:50, dont `content` et
> `monde` sur la graine 123456789 ; `.bat` de la racine recopiés). ⏳ **Lot A2 lancé vers 19 h 05** (run `wf_0143e61e-944`, session
> `8a9c0503` ; la mitrailleuse en jeu à 4 directions ; décision D-6 : feuilles dans `graphics/levels/gun/`, hors de git, manifeste
> commité ; sorties `<racine>\fo-logs\2026-10-24_A2\`). Mise à jour précédente : 22/10/2026, 23 h 08 (heure du PC ; orchestrateur, session Claude Code `8a9c0503`, qui
> reprend la session `6b481308` du 21-22/10, coupée à 8 h 55 par la limite d'usage hebdomadaire de son compte ;
> jalon : lot V3-T3 (« Libérer la place », réponse B à Q-T2-1) intégré dans `main` (fusion `8a28804`, changelog
> `4a7a365` ; **version 0.4.4**), bancs en moteur réel rejoués sur `main` de 22:50:45 à 22:51:53, hors jeu jusqu'à 22:55:17 ; lot V3-T4 (réponse A à Q-T2-2)
> livré sur sa branche, **NON intégré** (Q-T4-1) ; jalons précédents : lot R1 intégré à 20 h 11 (fusions `dcc97b3` et
> `58db82c`, version 0.4.3), lot V3-T2 intégré à 19 h 05 (fusion `681dd5c`, version 0.4.3), suites de V3-T intégrées à
> 17 h 25, lot V3-T intégré à 14 h 50). Mettez à jour ce fichier à chaque jalon.

## 1. En dix lignes
1. Mod Factorio 1.1.91, version **0.4.5** (depuis la fusion du lot M0, le 23/10 à 17 h 44 ; 0.4.4 depuis V3-T3, le
   22/10 à 22 h 50 ; 0.4.3 depuis V3-T2), dépôt git `main` dans ce dossier.
2. Bancs sur `main` (rejoués le 23/10 après les fusions d'A1 et M0 : moteur réel de 17:45:17 à 17:46:17, archives
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
     E prouvée), rose des 8 directions (page DC https://claude.ai/artifact/9zVUA65YE4wVfaaxobjZ6W , pas encore jugée),
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
   - **mitrailleuse V3-E : designs des 15 âges VALIDÉS par le DC** (23/10, 14 h 50) ; pas encore en jeu (lot A2) ;
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
   §6 ; détail au §7 ci-dessous) : finir les intégrations en cours (INT-K0, INT-GARDE, INT-GRAINE), puis **A2 : la
   mitrailleuse EN JEU à 4 directions**, puis **A3 : 64 directions, rendu de nuit** (Q-P2 : A). Historique :
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
| **V3-S** direction artistique | Charte ✅ intégrée. Première passe ✅ jugée (E45) : industriel gagnant de peu (6/10), aucune approche au niveau du vanilla ; page pour le DC https://claude.ai/artifact/EjdBUNfU1BLdkTU7cqWWMB . ✅ Style retenu par le DC le 22/10 à 16 h 45 (E45). Passe de synthèse (run `wf_eaa96606-5f1`, lancée à 16 h 25, session `8a9c0503` ; variantes « affût » et « resserre ») arrêtée à 16 h 47, sans livrable | `<racine>\fo-logs\2026-10-22_V3S\` (première passe : `industriel\`, `hightech\`, `hybride\`, `juges\`, `presentation\`) ; `<racine>\fo-logs\2026-10-22_V3S-synthese\` |
| **V3-T** emprise croissante et agrandissement sur place (Q23, Q24) | ✅ intégré le 22/10 à 14 h 50 (`13b4134`, version 0.4.2) ; moteur réel `content` 238 OK ; activé pour la mitrailleuse seule ; aucun visuel nouveau ; non prouvé en moteur réel : panneau et aperçu au sol, transfert autre que munitions et PV, remboursement F40, machines agrandies (la migration d'une vraie sauvegarde est prouvée depuis : ligne suivante) | E44, F70 à F75 ; `<racine>\fo-logs\2026-10-22_V3T\` (notes `NOTES_V3T.md`, `content-final`, captures de la phase initiale), `<racine>\fo-logs\2026-10-22_V3T-integration_content\` |
| **Suites de V3-T** : H-T3, bancs hors jeu, d4m | ✅ intégrées le 22/10 (fusions `e1a6a6f`, `1f2ff79`, `18a00d4`, puis `c4d37e5`) ; version inchangée (0.4.2). Moteur réel sur `main` : `content` 238 OK (17:06:23) ; migration réelle 0.4.1 → 0.4.2 : 29 OK, journal 7 OK (17:06:44). H-T3 : (1) prouvée en moteur réel ; (2) prémisse réfutée (F77) ; filet prouvé seulement en expérience de contrôle. Hors jeu : migration 60, harness avec la règle des points de jeu (0 violation), api_lint 447, d4m 5/5. Non prouvé, entre autres (liste complète : RD_LOG E46 à E48) : rechargement d'une carte déjà migrée, défense dense, amélioration d'une mitrailleuse laissée hors grille, contact bord à bord de `find_entities_filtered` en moteur réel, machines agrandies en moteur réel | E46 à E48, F76 à F82 ; `<racine>\fo-logs\2026-10-22_V3T-suites\` (`ht3\`, `harness-mock-levels\`, `d4m\`, chacun avec ses `NOTES.md`), `<racine>\fo-logs\2026-10-22_V3T-suites-integration\` (`content\`, `ht3-migration\`) |
| **V3-E** direction artistique par époque de la mitrailleuse | ✅ **Designs des 15 âges validés par le DC** (23/10, 14 h 50) : âges 1 à 12 de la passe 5 (E65), ère V cosmique (13 Antimatière, 14 La Porte, 15 Néant ; `6d0e961`). Branche `v3e-final` fusionnée dans `main` (`93e3d89`, outils de rendu seulement). Rendus définitifs : âges 1 à 12 dans `<racine>\fo-logs\2026-10-23_V3E-p5\bas|haut\sprites\`, âges 13 à 15 dans `<racine>\fo-logs\2026-10-23_V3E-ereV\sprites\` (les e13 à e15 de `V3E-p5\haut` et `final` sont l'ANCIENNE ère V refusée : `REFUSES.txt`). Test final (run `wf_c46edecb-f29`) : couleur 13 et 15 sur 15, gris 5 et 5, pose N 7 cheminées sur 15, écarts 2,6. Pages : https://claude.ai/artifact/73XHitUsLE1G49yPPWKtFG (finale), https://claude.ai/artifact/SWLGoaBpAHcsax5z6zzhfw (suivi). **Pas encore en jeu.** Suite : plan `<racine>\fo-logs\2026-10-23_plan-suite\PLAN_SUITE.md` (page DC https://claude.ai/artifact/5L4V5zFDiHP1kL7fTt8CgW ; questions Q-P1 à Q-P3) ; run `wf_2bade7c0-0e8` (lancé vers 15 h 55, terminé) : A1, K0 et M0, chacun dans son worktree avec vérification adverse et correction ; sorties `<racine>\fo-logs\2026-10-23_suite\` ; A1 et M0 fusionnés à 17 h 44, K0 en cours d'intégration (lignes ci-dessous) | `<racine>\fo-logs\2026-10-23_V3E-p5\` ; `<racine>\fo-logs\2026-10-23_V3E-ereV\` ; `<racine>\fo-logs\2026-10-23_plan-suite\` |
| **V3-T2** emprise croissante des 5 autres familles (Q-S1 : oui) | ✅ intégré le 22/10 à 19 h 05 (fusion `--no-ff` `681dd5c` de `worktree-wf_04ba1f63-d67-1` : ingénieur `3e9a23e`, `f5f6a77`, `be0ee03` ; correcteur `e84ca84`), **version 0.4.3** ; changelog `aec3baf`. Moteur réel sur `main` : `content` 317 OK, `t2-machines` 80 OK, `t2-migration` 64 OK + journal 26 OK, `ht3-migration` 30 OK + journal 7 OK (`done.txt` 19:05:39 à 19:05:52). Hors jeu : migration 79, levels 1575, api_lint 519, test_ht3_journal 15, le reste inchangé. Revue : 19 défauts, le majeur confirmé par témoin (`be0ee03` : 308 OK, 9 échecs dont 1 artefact du témoin) et corrigé. Visuel provisoire, laid aux grandes tailles, sans verdict du DC. Questions Q-T2-1 et Q-T2-2 posées au DC. Non prouvé : liste dans RD_LOG E49 à E52 | E49 à E52, F83 à F95 ; `<racine>\fo-logs\2026-10-22_V3T2\` (`NOTES_V3T2.md`, passages de l'ingénieur et du correcteur, captures, `src-0.4.2` à GARDER), `<racine>\fo-logs\2026-10-22_V3T2-integration\` |
| **R1** robustesse : défense dense, contact bord à bord, atlas virtuel | ✅ intégré le 22/10 (run `wf_c34819e9-18a`, lancé à 19 h 38, session `8a9c0503` ; deux suites, chacune constructeur, revue adverse, correcteur ; fusions `dcc97b3` de `worktree-wf_c34819e9-18a-1`, tête `f41753d`, et `58db82c` de `-2`, tête `75863a5` ; changelog 0.4.3 complété, `870f045`) ; version inchangée (0.4.3). Moteur réel sur `main` (`done.txt` 20:11:14,81 à 20:11:40,52) : `content` 317, `t2-machines` 80, `bord-a-bord` 12, `t2-migration` 64 + 26, `ht3-migration` 30 + 7, `t2-defense` 36 + 19 (création 0.4.1) et 36 + 11 (0.4.2). Hors jeu : migration 81, levels 1577, api_lint 535, mut_vram 18/18, le reste inchangé. Défense dense : elle marche, 13 tourelles sur 21 laissées depuis 0.4.1, visuel laid NON jugé (E54). Contact bord à bord RENDU par le moteur réel (F96), moteur simulé aligné (21 écarts sur 45, puis 0 ; E53) ; `move_ground_items` corrigé (défaut du mod trouvé par la revue). `vram.py` compte l'atlas virtuel (E55) ; le « 14/14 » du constructeur vram était FAUX (13/14). Revues : 2 majeurs et 6 mineurs, tous confirmés et corrigés. Non prouvé : liste dans RD_LOG E53 à E55 | E53 à E55, F96 à F102 ; `<racine>\fo-logs\2026-10-22_R1\` (`defense\NOTES.md`, `defense\correcteur\`, `defense\captures-t2-defense-0.4.1\` ; `vram\NOTES.md`, `vram\correcteur\`), `<racine>\fo-logs\2026-10-22_R1-integration\` |
| **V3-T3** bouton « Libérer la place » (Q-T2-1 : « QT21 option B ») | ✅ intégré le 22/10 à 22 h 50 (run lancé à 21 h 10, session `8a9c0503` ; ingénieur, revue adverse à 3 regards, correcteur ; fusion `8a28804` de `worktree-wf_49a2ed53-111-1` : ingénieur `f26e9c3`, correcteur `d0b40da` ; changelog 0.4.4, `4a7a365`), **version 0.4.4**. Moteur réel sur `main` (`done.txt` 22:50:45,71 à 22:51:53,59) : `content` 317, `t2-machines` 80, `bord-a-bord` 12, **`t3-libere` 41**, `t2-migration` 64 + 26, `ht3-migration` 30 + 7, `t2-defense` 36 + 19 et 36 + 11, **`t3-migration` 7** (1 000 ticks ; le premier passage à 700 ticks, trop court, n'a pas de BILAN). Hors jeu : migration 82, levels 1642, api_lint 609 (615 annoncés par le correcteur dans son worktree : écart non expliqué), le reste inchangé. Revue : 24 défauts, dont 2 bloquants (plan partiel exécuté, Annuler pas sûr), 23 traités, 1 réfuté. **Limites** : rangées collées (5 libérables sur 19 dans l'usine dense, 2 sur 13 dans la défense dense) ; fils de circuit non refaits ; joueur réel non joué ; noms de prototypes en chaînes dans `global.fo.levels_free.names` (écart à « nombres seulement », ARCHITECTURE §7 bis, signalé par le correcteur comme écart à faire valider, pas encore soumis au DC). Non prouvé : liste dans RD_LOG E59 | E56 à E59, F103 à F110 ; `<racine>\fo-logs\2026-10-22_V3T3\` (`NOTES_V3T3.md`, §5 du correcteur qui fait foi ; `correcteur\captures-t3-libere\`, 4 images), `<racine>\fo-logs\2026-10-22_V3T3-integration\` |
| **V3-T4** la production suit la surface (Q-T2-2 : réponse A) | 🟨 **livré, NON intégré** (run lancé à 21 h 15, session `8a9c0503` ; ingénieur, revue adverse à 3 regards, 23 défauts, correcteur ; branche `worktree-wf_9d38a6df-249-1`, partie de `e27bda9`, tête `2b18742`, version non changée). Raison : **Q-T4-1** (§3) : densité tenue (production par tuile croissante, mesurée), rentabilité non tenue (foreuse 29 → 30 remboursée en 510 h, contre 342 h en 0.4.3 ; four et assembleur à valeur ajoutée nulle). Sur la branche : `content` 331, `t4-production` 21 (5 300 ticks), autres bancs verts ; levels 1 615 + 23 écarts connus, api_lint 558. Pour l'intégrer après la réponse : fusion sur 0.4.4 (conflit attendu avec V3-T3 dans `tests/levels_test.lua`, seul fichier modifié des deux côtés, vérifié par `git merge-tree`), `levels_test.lua --calibrate`, renumérotation des identifiants cités dans le code (F111 à F118, E60 à E62), tous les bancs | E60 à E62, F111 à F118, H-T4-1 ; `<racine>\fo-logs\2026-10-22_V3T4\` (`NOTES_V3T4.md`, §9 du correcteur qui fait foi ; `tables_BALANCE_SHEET_12_corrige.md` ; passages `01_` à `23_`) |
| **A0** ménage et garde-fous (plan, étapes 1 et 2) | 🟨 en partie : fusion de `v3e-final` (`93e3d89`), `REFUSES.txt`, identifiants réservés, phrases du DC inscrites, déplacement Q-P1 fait (1 776,5 Mo vers `C:\Users\evan2\fo-archives\fo-logs\`). **Non fait** : tri des worktrees (59 dossiers relevés à 18 h 14), seuil de 1 Go libre avant chaque paquet de rendu, magasin des feuilles hors de git (D-6 B, préalable d'A2) | RD_LOG, décisions du 23/10 ; OBJECTIFS §7 |
| **A1** rose des 8 directions, E66, E67, E70 | ✅ fusionné le 23/10 à 17 h 44 (`5a95650` ; constructeur `44e0a4b`, correcteur `741917a`), outils seulement, version inchangée. Dégel D-9 de `piece.py` prouvé (36 fichiers sur 36 identiques octet à octet) ; rose : 112 têtes en aperçu, **19 trous enfermés sur 112** (à trancher avant A3), pose N toujours « cheminée » à 8 âges, page https://claude.ai/artifact/9zVUA65YE4wVfaaxobjZ6W (pas de verdict du DC) ; E66 : gain 44,7 % (le 51 % de la première mesure était faux, défaut majeur de la vérification, corrigé) ; E67 : garde du kit fausse (INT-GARDE) ; E70 : `orientation` pour orienter une tête à l'arrêt ; `a1-tourelle` 5 OK sur copie jetable | E66, E67, E70, F120 à F122 ; `<racine>\fo-logs\2026-10-23_suite\A1\` (`NOTES.md`, `INTEGRATION.md`, `verification.md`, `rose\`, `e66\`, `moteur\`) |
| **M0** socle du monde : monnaies des âges 5, 7, 8 garanties | ✅ fusionné le 23/10 à 17 h 44 (`da2e16f` ; constructeur `28fe15b`, correcteur `d6766d7`), **version 0.4.5**. Moteur réel sur `main` : `monde` 89, `m0-reprise` 15, `m0-migration` 9, tous les bancs existants verts ; hors jeu : `monde_test` 157, api_lint 669. Vérification : M-1 (échec définitif et muet) corrigé ; M-2 (générateur depuis `X.resources` et `X.tiles`) REPORTÉ aux lots X par l'orchestrateur ; 9 mineurs non traités (accès à pied, pire cas 767 ms, message perdu à `on_init`, décor, factions, sauvegarde de migration quasi vide, garantie non générique, anomalie des graines 1 et 42). Questions Q-M0-1 et Q-M0-2 (§3) | E73 à E76, F130 à F135 ; `<racine>\fo-logs\2026-10-23_suite\M0\` (`NOTES.md` §6 du correcteur, `INTEGRATION.md`, `verification.md`, `correction\`, `captures-2\`), `<racine>\fo-logs\2026-10-23_integration-0.4.5\` |
| **K0** kit commun des familles | ✅ intégré par INT-K0 (fusion `e4e8416`) ; branche `worktree-wf_2bade7c0-0e8-2`, constructeur `0cee947`, tête `87c4fb1`. Aucun design validé changé (empreinte FORTE, 72 variantes et 165 habillages, graines comprises). Vérification : 4 majeurs du lot corrigés ; 1 majeur antérieur NON corrigé (F136, graines inertes : décision du DC) ; 5 mineurs dits (dont `stone-wall` non mesuré et la séparation des âges 4 et 5 par la seule saturation) | E71, E72, F136 ; `<racine>\fo-logs\2026-10-23_suite\K0\` (`NOTES.md` section « Correction », `INTEGRATION.md`, `verification.md`, `correction\`, `D3_ere_V.md`) |
| **INT-K0, INT-GARDE, INT-GRAINE** | ✅ fusionnés vers 18 h 40 (`e4e8416`, `b80f2bb`, `0db5493`), version 0.4.5 inchangée ; kit commun sur `main` sans design changé ; garde des durées selon E67 (levels 1 661) ; `FO_MAP_SEED` (défaut 20261020 ; `$env:FO_MAP_SEED = $null` après usage, F139) ; bancs verts (`content` et `monde` aussi sur la graine 123456789) | `<racine>\fo-logs\2026-10-23_suite\INT-*\` ; `<racine>\fo-logs\2026-10-23_integration-0.4.5-b\` ; F137 à F139 |
| Test de Stable Diffusion local | ✅ fait (E42) : utile pour l'inspiration et l'img2img depuis un sprite existant, jamais pour des sprites finaux ; planche envoyée au DC | `<racine>\fo-logs\2026-10-22_SD-test\` |

## 3. Ce qui reste ouvert chez le Directeur Créatif
- **Pages pour le DC (23/10)** : finale de la mitrailleuse https://claude.ai/artifact/73XHitUsLE1G49yPPWKtFG ; plan de
  la suite https://claude.ai/artifact/5L4V5zFDiHP1kL7fTt8CgW ; rose des 8 directions (lot A1)
  https://claude.ai/artifact/9zVUA65YE4wVfaaxobjZ6W (aucun verdict ; à regarder surtout : pose N « cheminée », pose S
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
