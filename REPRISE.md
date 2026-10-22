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
> **Dernière mise à jour : 22/10/2026, 15 h** (orchestrateur, session Claude Code `8a9c0503`, qui reprend
> la session `6b481308` du 21-22/10, coupée à 8 h 55 par la limite d'usage hebdomadaire de son compte ;
> jalon : lot V3-T intégré à 14 h 50). Mettez à jour ce fichier à chaque jalon.

## 1. En dix lignes
1. Mod Factorio 1.1.91, version **0.4.2** (depuis l'intégration de V3-T), dépôt git `main` dans ce dossier.
2. Bancs sur `main` (rejoués le 22/10, de 14 h 51 à 14 h 55), tous verts sauf d4m :
   - hors jeu : run 114, war 92, td 270, pteam 15, migration 50, levels 1564 (+11 écarts connus),
     epochs 16665, org 362, pvp 596 ;
   - étape data : 0 erreur ;
   - api_lint : 434 usages, 0 erreur ;
   - d4m : 4/5, échec PRÉEXISTANT de l'outil (l'étape des journaux archivés exige 15 atlas, les journaux
     D4m 3 à 5 en ont 14 ; même échec sur l'ancien `main` `91097e6`) ;
   - **moteur réel `content` : 238 OK** (210 du banc, 2 de l'exemple, 26 du greffon `levels_taille`).
3. Fait et prouvé en moteur réel :
   - outillage P0 et P1 (captures automatiques) ;
   - V2, V2b et V2c (15 époques, 30 niveaux, amélioration INSTANTANÉE, condition du centre) ;
   - V3-T, pour la mitrailleuse seule : emprise croissante (2×2 → 6×6, une taille par ère) et
     agrandissement sur place (Q24 : refus sans paiement et contour si la place manque) ;
   - IA0 et IA0b (les factions attaquent le joueur, 5 difficultés, bases défendues, assaut coordonné) ;
   - budget A1 (0,108 ms/tick) ;
   - D4m (mémoire vidéo 1,7 Go en haute qualité, 60 UPS avec l'usine géante).
4. Conçu hors jeu, pas encore en jeu :
   - X0 : scénario « La Caustique d'Érèbe », 15 époques et 4 branches, **approuvé par le DC** ;
   - IA1 : équipes de 30 PNJ, pôles, généralistes, production adaptative.
5. Visuel :
   - pipeline 3D (V0, V0b) étalonné ; style de la cheminée V0 validé par le DC ;
   - **aperçus V3 phase 1 REJETÉS** (22/10, 7 h 15) : manque de détail, direction artistique de Factorio
     non respectée, niveaux hauts pas plus « badass ».
6. Nouvelles règles visuelles (Q23 et Q24) :
   - les bâtiments GRANDISSENT avec les époques, jusqu'à environ 6×6, avec plus de détail ;
   - test du regard naïf ;
   - agrandissement sur place si la place est libre : **mécanique faite (V3-T), pour la mitrailleuse
     seulement** ; le visuel reste provisoire (sprite actuel agrandi, sans détail).
7. **En cours : V3-S, reprise** (13 h 20, workflow `wf_ed692a11-bba` de la session `8a9c0503`).
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
   ACTIVÉE pour la seule mitrailleuse ; les autres familles attendent Q-S1. Preuves : RD_LOG E44, F70 à
   F75 ; journaux `<racine>\fo-logs\2026-10-22_V3T\` et `<racine>\fo-logs\2026-10-22_V3T-integration_content\`.
   Non prouvé en moteur réel : panneau et aperçu au sol, migration d'une vraie sauvegarde (H-T3), transfert
   autre que munitions et PV (fluides, brûleur, recette, fils, réglages de foreuse), remboursement F40,
   machines agrandies (liste complète : RD_LOG E44).
8. Ensuite :
   - lot V3-E : direction artistique PAR ÉPOQUE de la mitrailleuse (style V3-S retenu par le DC le 22/10 à
     16 h 45 ; canons, tuyaux et accents changés selon chaque âge), puis les 6 autres familles ;
   - activation des tailles croissantes pour les 6 autres familles (Q-S1 : oui), après l'intégration des
     suites de V3-T ;
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
| **V3-S** direction artistique | Charte ✅ intégrée. Première passe ✅ jugée (E45) : industriel gagnant de peu (6/10), aucune approche au niveau du vanilla ; page pour le DC https://claude.ai/artifact/EjdBUNfU1BLdkTU7cqWWMB . ⏳ Passe de synthèse (run `wf_eaa96606-5f1`, lancée à 16 h 25, session `8a9c0503`) : variantes « affût » et « resserre » en worktrees isolés | `<racine>\fo-logs\2026-10-22_V3S\` (première passe : `industriel\`, `hightech\`, `hybride\`, `juges\`, `presentation\`) ; `<racine>\fo-logs\2026-10-22_V3S-synthese\` |
| **V3-T** emprise croissante et agrandissement sur place (Q23, Q24) | ✅ intégré le 22/10 à 14 h 50 (`13b4134`, version 0.4.2) ; moteur réel `content` 238 OK ; activé pour la mitrailleuse seule ; aucun visuel nouveau ; non prouvé en moteur réel : panneau et aperçu au sol, migration d'une vraie sauvegarde (H-T3), transfert autre que munitions et PV, remboursement F40, machines agrandies | E44, F70 à F75 ; `<racine>\fo-logs\2026-10-22_V3T\` (notes `NOTES_V3T.md`, `content-final`, captures de la phase initiale), `<racine>\fo-logs\2026-10-22_V3T-integration_content\` |
| Test de Stable Diffusion local | ✅ fait (E42) : utile pour l'inspiration et l'img2img depuis un sprite existant, jamais pour des sprites finaux ; planche envoyée au DC | `<racine>\fo-logs\2026-10-22_SD-test\` |

## 3. Ce qui reste ouvert chez le Directeur Créatif
- **V3-S : verdict rendu** le 22/10 à 16 h 45 (style retenu, « parfaits », « époustouflants surtout pour les
  canons » ; il manque une direction artistique par époque : lot V3-E). Prochain regard : les planches V3-E.
- Q-V2c-1 et Q-V2c-2 : rythme du centre et chemin le plus court vers l'époque 15 (OBJECTIFS §4).
- Q-S1 à Q-S3 : **répondues oui** par le DC le 22/10 à 16 h 45 (échelle pour toutes les familles, plafond 6×6
  pour les machines, centre 4 → 8, mur inchangé ; luminance de la charte pour toutes les époques ; regard naïf
  par des agents sans contexte).
- Q-IA1-1 à Q-IA1-7 : équipes de PNJ (OBJECTIFS §4, avec les recommandations).
- Critères marqués ❔ (C4, C5, D4…) : à faire valider quand l'occasion se présente.
- Répondues récemment : Q19 (amélioration instantanée), Q20 et Q21 (mémoire vidéo, basse qualité
  soignée), Q22 (carte blanche la nuit du 21 au 22/10, terminée), Q23 (taille et puissance perçue), Q24
  (agrandissement sur place si la place est libre).

## 4. Branches et worktrees (`.claude/worktrees/`)
- **Fusionnées** : tout ce qui est marqué ✅ au §2.
- **Non fusionnées, à GARDER** :
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
- **Antislashs dans les scripts Python écrits en ligne** (heredoc dans Bash) : ils peuvent être réduits
  en route, et `\fo-logs` devient alors un caractère de contrôle. Le 22/10, 5 chemins de documents ont été
  abîmés puis réparés. Pour modifier un document qui contient des chemins Windows, utilisez l'outil
  d'édition, ou un script écrit dans un FICHIER. Contrôle : `repare_ctrl.py` (caractères de contrôle dans
  les documents).
- Les agents déposent parfois des diffs pour l'intégrateur dans le dossier temporaire de la session,
  qui peut disparaître. Appliquez-les vite, ou copiez-les dans `fo-logs`.
- Le DC peut jouer pendant les bancs : jamais d'arrêt global de factorio.exe, fermeture ciblée seulement
  (CLAUDE.md §4).
- **Python** : le `python` par défaut (3.14) a Pillow, mais PAS numpy. Les outils de mesure de la charte
  (`tools/da/`) se lancent avec `py -3.9` (numpy 2.0.2 et Pillow). Les scripts Blender utilisent le Python
  intégré à Blender (3.13).

## 7. Prochaines étapes, dans l'ordre
1. ~~V3-S~~ : fait. Charte intégrée (13 h 25), première passe jugée (E45), verdict du DC le 22/10 à 16 h 45 :
   style retenu ; il manque une direction artistique par époque.
2. Ensuite, sans attendre :
   - lot V3-E (run lancé le 22/10 vers 16 h 55) : la mitrailleuse sur les 15 époques, même style, canons,
     tuyaux et accents selon la fiche de chaque époque (`docs/DESIGN_EPOQUES.md` §5) ; puis les 6 autres
     familles avec la même méthode, la taille croissante (Q23, Q-S1) et la charte ;
   - ~~la mécanique d'agrandissement sur place (Q24)~~ : **faite** (lot V3-T, intégré le 22/10 à 14 h 50),
     activée pour la mitrailleuse. Avec la réponse à Q-S1, activer les autres familles = leur ligne dans
     `L.footprints`, plus 3 attentes de `levels_test` à réécrire et `get_control_behavior` à ajouter au
     moteur simulé (OBJECTIFS D1-4) ; puis un banc en moteur réel d'une machine agrandie.
   - Suites de l'intégrateur proposées par V3-T, NON faites (OBJECTIFS §7) : règle « raccord et point de
     dépôt hors de la boîte » dans `tests/datastage/harness.lua` ; `get_control_behavior`,
     `destroy_decoratives` et recherche par boîte dans `tests/mock_engine.lua` ; correction de l'étape d4m
     qui exige 15 atlas par journal.
   - H-T3 : prouver en moteur réel la migration d'une sauvegarde 0.4.1 (protocole dans RD_LOG).
3. V4, contrôle visuel : gris, vignettes, recouvrement, gros plans, banc `content`, galerie jour et nuit
   en jeu, mesures D4 refaites avec les sprites V3 ; puis le verdict du DC.
4. Ensuite, en parallèle (Q18) :
   - Compaction ×4 (C1 à C5) ;
   - construction d'IA1 (12 lots, `docs/EQUIPES_PNJ.md` §16).
5. Contenu des époques X1 à X15 (`docs/SCENARIO_EPOQUES.md`), puis idle (E3).
6. Hypothèses encore ouvertes :
   - H-T3 : migration des emprises sur une vraie sauvegarde 0.4.1 (lot V3-T) ;
   - H-L1 : coût du système des niveaux, à mesurer sur banc épinglé (le calcul de place du panneau de V3-T
     n'est pas mesuré non plus) ;
   - H-X1 ;
   - H-V2 ;
   - H-B1.
