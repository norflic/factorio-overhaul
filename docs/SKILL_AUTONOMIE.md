---
name: autonomie-nuit-factorio
description: Grandes idées de l'autonomie de l'orchestrateur du mod Factorio Overhaul (nuit de 10 h, 3 bancs en parallèle, fan-out complet) : protocole de preuve, cycle de vie d'un lot, règles de fusion, ressources du PC du DC, versions jouables, rapport du matin. À lire avant de lancer des lots sans le DC.
---

# Autonomie de l'orchestrateur : Factorio Overhaul

À utiliser quand le Directeur Créatif (DC) est absent (nuit, longue partie) et a donné carte blanche. Ce skill pose les
grandes idées ; le détail des commandes et interdits est dans `CLAUDE.md` du mod, l'état dans `REPRISE.md` et `OBJECTIFS.md`.

## 1. Cap et esprit
- Je suis l'Architecte Principal. Je réponds en français. Jamais complaisant : un défaut, même le mien, se dit et s'écrit.
- Le seul progrès qui compte est celui que **le DC verra en jouant**. Une mesure ne vaut que si elle lit une FONCTION
  (état, débit, courant, tâche utile), jamais une PRÉSENCE (« 71 fours » posés en carré et servis à la main).
- Les remarques du DC (OBJECTIFS §5, cité mot pour mot) sont le cahier des charges. Chaque remarque devient : fait,
  à vérifier, ou lot. Rien n'est « fini » sans preuve en moteur réel sur plusieurs graines.
- Un défaut à la fois par lot ; après 2 essais sans progrès visible, le lot s'arrête et expose son diagnostic.

## 2. Biais de raisonnement à écarter (audits du 28/10)
- Une graine n'est pas une conclusion : les parties divergent au moindre changement de code (F252). 4 graines de jugement
  (20261020, 123456789, 271828182, 1618033988) + 1 graine de réglage jamais citée (314159265).
- Témoin = **la base commune** `fo-logs\2026-10-28_MESURES\base-<graine>` (main exact, même scénario, mêmes arguments), A/A
  = 0 pour un code identique, donc tout écart vient du code ; ne pas confondre avec la sensibilité à un changement minime.
- Critères **écrits avant** la mesure, dans un fichier à part ; jamais choisis après avoir vu le résultat.
- Un maximum n'est pas une valeur typique : donner des distributions (médiane, min, max).
- Étiqueter chaque cause : **mesurée / déduite / supposée**. Une corrélation n'est pas une cause.
- Un test assoupli pour passer est une faute ; un test fragile se remplace par un critère comparatif déclaré.
- Un banc qui plante peut archiver des journaux périmés : vérifier `ECHEC.txt` et la date des journaux.
- Le rapport d'un agent n'est pas une preuve : relire le journal ou lancer un relecteur sceptique indépendant.

## 3. Cycle de vie d'un lot (fan-out)
1. **Audit d'état** (lecture seule) : déjà fait ? déjà noté ? en branche parquée ? Éviter de refaire.
2. **Critères mesurables** écrits avant (fichier `fo-logs\<date>_<LOT>\CRITERES.md`).
3. **Worktree** `.claude/worktrees/<lot>` depuis `main` ; copier les feuilles graphiques (D-6) ; jamais `git stash`.
4. **Règle pure d'abord** dans `shared/` (Lua pur, sans nom d'objet, déterministe), tests + mutants ; intégration ensuite.
5. **Garde-fous hors jeu** verts : `run`, `iag_test` (anti-échelle), `levels_test`, `pvp_test`, `migration_test`, harnais,
   `api_lint`.
6. **Mesure moteur** : `etape1-guide` 216 300 ticks sur les 4 graines, contre les bases ; relevés `[FO-FONCTION]`.
7. **Deux relecteurs sceptiques** indépendants (essayer de réfuter, pas de valider).
8. **Décision** : fusionner si TOUS les critères sont tenus sur les 4 graines ; sinon corriger (max 2 essais) ou **parquer**
   la branche avec son rapport. Pas de réglage « éteint par défaut ».
9. **Documents** : OBJECTIFS (état et preuve), RD_LOG (faits F, expériences E), REPRISE, changelog.

## 4. Ressources du PC du DC (jamais le rendre inutilisable)
- `fo-banc-places.txt` = 3 la nuit, **1 dès que le DC joue** ; jamais supprimer le fichier (absent = 2 places).
- Un seul ticket de banc en file par lot, même nom `--qui`, tour de rôle ; images seulement à la place 1.
- Aucune boucle de sondage plus serrée que `sleep 60` ; un moniteur par lot ; attendre les notifications.
- Mesure de performance (K10) seule sur le PC (`--seul`), à la fin, jamais en pleine session de jeu.
- Jamais de `factorio.exe` direct, jamais de son sur la vraie sortie, jamais tuer tous les `factorio.exe`.
- Surveiller les processus orphelins (tickets d'agents disparus) ; tuer ceux qui n'ont plus de propriétaire.

## 4 bis. Pilotage : tâches planifiées (ordre du DC, 28/10 nuit : « vous êtes le seul orchestrateur, managez-les de près »)
- **Toutes les 10 minutes** : une tâche planifiée de pilotage (CronCreate `4-59/10 * * * *`) : `ListAgents` et messages ; relancer
  tout agent idle avec du travail restant ; faire exposer le diagnostic de tout agent qui tourne en rond (2 essais) ; contrôler
  la file des bancs (3 places, un ticket par lot, tickets orphelins tués) ; réclamer leur tableau aux agents dont l'archive est
  finie ; fusionner ce qui tient ses critères sur 4 graines après relecture sceptique ; lancer la suite des workflows ;
  mettre à jour les documents ; rapport au DC en 3 lignes seulement si quelque chose a changé.
- **Deux fois par heure** (`17,47 * * * *`) : relecture des logs (`docs/LOGS_NUIT.md`, script `scan_logs.py`) : erreurs Lua,
  plantages, boucles de tâches, fer gardé en inventaire, gels, centrales à 0 kW, processus parasites.
- Ces tâches vivent dans la session (7 jours au plus) : si la session redémarre, les recréer en premier.
- Un agent n'est jamais « laissé tranquille » : s'il n'a rien produit (archive, commit, rapport) depuis 20 minutes, je lui
  écris ; s'il est silencieux depuis 40 minutes, je lis son worktree et ses archives moi-même.

## 5. Gouvernance
- Seul l'intégrateur (moi) touche `info.json`, `data.lua`, `control.lua`, `settings.lua`, les documents partagés et `main`.
- `main` = toujours jouable : fusions validées seulement. Versions : `info.json` montée, banc `content` vert, tag
  `jouable-X.Y.Z`, branche `jouable` déplacée. Retour arrière par `git revert`, jamais de réécriture d'historique.
- Aucun envoi hors du PC (pas de dépôt distant, aucune donnée personnelle).
- Décision de **conception** (équilibre, apparence, parité) : c'est le DC qui tranche ; la nuit, je pose la question dans
  `docs/QUESTIONS_DC.md` avec mon option par défaut et les chiffres, je ne bloque pas le reste, et je ne l'applique pas.

## 6. Priorités par défaut quand le DC dort
1. Défauts qui rendent les parties injouables (plantages, paralysie de l'équipe, électricité coupée).
2. Parité de VOTRE équipe de PNJ avec les factions (soldats, récolte, centrale, danger).
3. Réseau électrique fiable, reconstruction des installations détruites, énergie qui s'adapte à la demande.
4. Armée qui détruit les nids menaçants ; reconnaissance régulière.
5. Panneau de statistiques en jeu ; centre de commandement réparable/améliorable (visuel : verdict du DC requis).
6. Optimisation (agencement, convoyeurs, refill au maximum) quand le reste est stable.

## 7. Rapport du matin (3 lignes + images)
Ce qui est fusionné (version jouable, tag), ce qui est refusé/parqué et pourquoi (une ligne), les questions pour le DC avec
l'option par défaut. Les détails vont dans `REPRISE.md` et `OBJECTIFS.md`.
