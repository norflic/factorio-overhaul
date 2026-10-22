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
> **Dernière mise à jour : 22/10/2026, 7 h 45** (orchestrateur, session Claude Code du 21-22/10).
> Mettez à jour ce fichier à chaque jalon.

## 1. En dix lignes
1. Mod Factorio 1.1.91, version **0.4.1**, dépôt git `main` dans ce dossier.
2. Bancs verts sur `main` :
   - hors jeu : run 114, war 92, td 270, pteam 15, migration 29, levels 1459 (+11 écarts connus),
     epochs 16665, org 362, pvp 596 ;
   - étape data : 0 erreur ;
   - api_lint : 378, 0 erreur ;
   - **moteur réel `content` : 212 OK**.
3. Fait et prouvé en moteur réel :
   - outillage P0 et P1 (captures automatiques) ;
   - V2, V2b et V2c (15 époques, 30 niveaux, amélioration INSTANTANÉE, condition du centre) ;
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
   - agrandissement sur place si la place est libre.
7. **En cours : V3-S** (charte de direction artistique, 3 approches sur la mitrailleuse) et le test de
   Stable Diffusion local.
8. Ensuite :
   - verdict du DC sur V3-S, puis reprise des 7 familles ;
   - Compaction ×4 (C) et construction d'IA1, en parallèle (Q18) ;
   - contenu des époques (X1 à X15) ;
   - idle (I).
9. Le DC suit souvent depuis son **téléphone** : envoyez les images dans le chat (SendUserFile, mode
   render), avec un texte court.
10. Ne déclarez jamais un design réussi : seul le verdict du DC le valide.

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
| **V3-S** direction artistique | ⏳ workflow en cours (run `wf_483106c7-c7f`) | sorties attendues dans `<racine>\fo-logs\2026-10-22_V3S\` |
| Test de Stable Diffusion local | ⏳ agent en cours | sorties attendues dans `<racine>\fo-logs\2026-10-22_SD-test\` |

## 3. Ce qui reste ouvert chez le Directeur Créatif
- **Verdict sur V3-S** : les planches comparatives sont à lui envoyer dès qu'elles sont prêtes.
- Q-V2c-1 et Q-V2c-2 : rythme du centre et chemin le plus court vers l'époque 15 (OBJECTIFS §4).
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

## 6. Pièges d'outillage déjà payés
- **F69** : depuis Git Bash, `fo-captures.bat` avec une source entre guillemets échoue, parce que
  `cmd /c` coupe le chemin à l'espace. Lancez-le depuis **PowerShell**. `fo-autotest.bat` sans argument
  entre guillemets fonctionne depuis Git Bash.
- `fo-autotest.bat` rend le code **2** si le verrou est pris : rien n'a tourné. Vérifiez toujours
  l'heure de `done.txt`.
- api_lint ignore les chaînes et les commentaires Lua (correctif du 21/10).
- `pairs` en Lua 5.2 hors jeu est NON déterministe (graine de hachage aléatoire), contrairement au jeu.
  Triez toujours les clés.
- Les agents déposent parfois des diffs pour l'intégrateur dans le dossier temporaire de la session,
  qui peut disparaître. Appliquez-les vite, ou copiez-les dans `fo-logs`.
- Le DC peut jouer pendant les bancs : jamais d'arrêt global de factorio.exe, fermeture ciblée seulement
  (CLAUDE.md §4).

## 7. Prochaines étapes, dans l'ordre
1. À la livraison de V3-S :
   - intégrer la charte (`fo-logs\2026-10-22_V3S\charte\DA_FACTORIO.md`) dans `docs/` ;
   - envoyer les planches au DC ;
   - attendre son verdict.
2. Après le verdict :
   - reprendre V3 pour les 7 familles avec la direction retenue, la taille croissante (Q23) et la
     charte ;
   - en parallèle : la mécanique d'agrandissement sur place (Q24 : place libre, sinon refus et contour
     affiché, remplacement par script avec transfert du contenu), la nouvelle échelle de tailles et
     les tests.
3. V4, contrôle visuel : gris, vignettes, recouvrement, gros plans, banc `content`, galerie jour et nuit
   en jeu, mesures D4 refaites avec les sprites V3 ; puis le verdict du DC.
4. Ensuite, en parallèle (Q18) :
   - Compaction ×4 (C1 à C5) ;
   - construction d'IA1 (12 lots, `docs/EQUIPES_PNJ.md` §16).
5. Contenu des époques X1 à X15 (`docs/SCENARIO_EPOQUES.md`), puis idle (E3).
6. Hypothèses encore ouvertes :
   - H-L1 : coût du système des niveaux, à mesurer sur banc épinglé ;
   - H-X1 ;
   - H-V2 ;
   - H-B1.
