# tools/graphe : carte du code pour les agents (lot GRAPHIFY)

Construit en local (Python 3.9, bibliothèque standard, sans réseau, sans LLM) un graphe de `shared/`, `script/`, `prototypes/`,
`settings/`, `migrations/` et des `.lua` de la racine : modules `require`, fonctions (nom, ligne de début et de fin), appels,
références de fonctions passées en rappel, abonnements (`Events.on*`, `script.on_*`, `commands.add_command`,
`remote.add_interface`, `Scheduler.define_lane/timer`), réglages lus (`settings.global[...]`, constantes résolues), états
(`Storage.declare/ns`) et lignes de journal `[FO-*]`.

- Construire (environ 3 s) : `py -3.9 -B tools/graphe/build.py` -> `tools/graphe/out/graphe.json` + `INDEX.md` (hors git).
- Interroger (30 lignes au plus) : `py -3.9 -B tools/graphe/q.py <cible>`, où la cible est :
  `Mig.think` ou `script.team.migration_champ:Mig.think` (fonction : appelants, appelés, chaîne causale du déclencheur à la
  fonction, journaux émis et en aval, réglages, états) ; `[FO-FONTE]` (qui l'émet et par quelle chaîne) ;
  `script/team/adopte.lua` (module) ; `on_tick` ou `fo-adopte.migrate` (abonnements) ; `fo-war-adopte` (réglage) ; `ns:pteam`.
- `INDEX.md` donne d'un coup d'oeil tous les déclencheurs, tous les journaux, les réglages et les états.
- Lire un graphe avant de faire des `grep` en rafale : la chaîne causale évite de reconstruire à la main déclencheur -> décision
  -> action -> effet. Le graphe repère où lire ; il ne remplace pas la lecture du code ni la preuve en moteur réel.
- `~` devant un appel = deviné (nom court unique dans le dépôt), non prouvé. Les appels dynamiques (`handlers[name](...)`,
  méthodes sur un objet, réglages lus par un intermédiaire) ne sont PAS vus : une chaîne « sans déclencheur » veut dire « non
  résolu », pas « jamais appelé ». Regénérer après un changement de code (le graphe porte le commit dans `INDEX.md`).
- Tests (hors jeu, mini-dépôt jetable, moins d'une seconde) : `py -3.9 -B tools/graphe/test_graphe.py` -> 33 OK.
