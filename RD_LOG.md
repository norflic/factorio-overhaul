# RD_LOG — Journal de R&D

> Chaque entrée : **ID · statut · énoncé · protocole · résultat**.
> Statuts : `FAIT` (vérifié dans une source), `VALIDÉ` / `REJETÉ` (prouvé par expérience), `OUVERT` (à tester).
> Ordre : le plus récent en haut de chaque section.
> Prochains identifiants libres (24/10, vers 5 h 50, après la fusion de D4m-géant) : **F163** et **E118** hors blocs ; F157 à F160, E114 à E116 réservés à A4 ; F161, F162, E117 : D4m-géant. Avant (24/10, vers 4 h 15, après la fusion d'A3-jeu) : **F157** et **E114** hors blocs ; F146 à F148 et E109 à E111 : A3-jeu ; **F149 et E112 réservés à A4**. Avant (24/10, vers 2 h 45, après la fusion de S0-suite) : **F157** hors blocs ; F155, F156 et **E113** : S0-suite ; **E114** hors blocs. Avant (24/10, vers 0 h 10, après la fusion d'A3-préparation) : **F155** hors blocs ; F140 à F145 et E105 à E108 : A3-préparation ; **F146 à F149 et E109 à E112 réservés à A3-jeu et A4**. Avant (23/10, vers 23 h 10, après la fusion du lot S0) : **F155** hors blocs ; F150 à F154 : S0 (F154 hors de son bloc F150 à F153) ; E69 : S0 ; F140 à F149 et E105 à E108 : toujours réservés à A3 et A4. Avant (23/10, vers 21 h 15, après la fusion du lot A2) : **F150** hors blocs ; **F140 à F149 réservés à A3 et A4** ; F123 à F129 et E68 : A2 (le bloc F120 à F129 d'A1 à A4 est épuisé) ; en expériences, **E105 à E108 réservés à A3 et A4** (leur bloc E66 à E70 est épuisé : E66, E67, E70 à A1, E68 à A2, E69 à S0 ; E81 à E104 : lots F1 à F6). Avant (23/10, vers 19 h, après les fusions d'INT-K0, INT-GARDE et INT-GRAINE) : **F140** ; F137 à F139 : INT-GRAINE (cmd.exe et PowerShell). Avant (23/10, vers 18 h 30, après la consignation des lots A1, K0 et M0) : **F137** (F123 à F129 restent réservés à A2 à A4) ; en expériences, aucun numéro hors des blocs réservés : **E68** (A2 à A4), **E69** (S0), **E77 à E80** (M1, M2), **E81 et suivants** (lots F, par blocs de 4). Attribués le 23/10 : F120 à F122 (A1), F130 à F135 (M0 ; F135 hors du bloc), F136 (vérification de K0, Blender) ; E66, E67, E70 (A1), E71, E72 (K0), E73 à E76 (M0 ; l'« E77 » proposé par le correcteur de M0 est consigné dans E74, E77 étant réservé à M1 et M2). Avant : (23/10, vers 14 h 55, après la consignation de la passe 5 de V3-E, E65 et F119) **F120, E66**. Blocs RÉSERVÉS par le plan de la suite (23/10, 16 h ; `fo-logs\2026-10-23_plan-suite\PLAN_SUITE.md` §6) : mitrailleuse A1 à A4 : E66 à E70 et F120 à F129 (E69 : sons, lot S0) ; K0 : E71 et E72 ; M0 : E73 à E76 et F130 à F134 ; M1 et M2 : E77 à E80 ; chaque lot F : un bloc de 4 expériences à partir de E81. E3 n'a jamais été attribué (la numérotation passe de E2 à E4).

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

- 21 h 25, réponse groupée aux questions Q14 à Q17 et QX1 à QX9 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » Décisions qui en découlent :
  - **Q14** : option A (le DPS du niveau 30 égale à peu près celui des tourelles lourdes).
  - **Q15** : rupture des PV des murs 0.3.0 acceptée.
  - **Q16** : condition légère pour monter le centre (au moins un bâtiment de chaque famille possédée au
    niveau maximal de l'époque).
  - **Q17** : la file de chantiers passe avant la Compaction.
  - **QX1** : phase brûleur aux époques 1 et 2.
  - **QX2** : le Serment.
  - **QX3** : défaite par la Porte seulement en Impitoyable.
  - **QX4** : antimatière en énergie nette (fiction assumée).
  - **QX5** : noms conservés.
  - **QX6** : 6e ouvrier par la merveille.
  - **QX7** : 60 h = ouverture de la Porte.
  - **QX8** : bâtiments tardifs nés au niveau 1, avec un rattrapage payant.
  - **QX9** : recherche vanilla allégée aux premières époques.
  - Mises en œuvre : Q16, Q17, QX7, QX9 et QX10 (arbitrage de l'architecte : le passage du centre pèse
    une vraie part du budget d'époque, comme chez X0) → lot V2c, après V2b. Les autres décisions
    relèvent des lots X et IA.

- 21 h 35, **nouvelle demande, équipes de PNJ organisées** (OBJECTIFS C5) : « Au niveau des ouvriers, vous parlez de 6 ouvriers. Pourquoi que 6? […] mettons 4 factions. Pourquoi pas 10 ouvriers par faction? […] tout au début, ça parlait plutôt de 100, joueurs par faction […] peut-être que 100 joueurs, c'est trop, mais prendre, je sais pas moi, 30 de constructions, enfin de PNJ […] par faction, bah, c'était bien, parce qu'en fait, l'idée, c'était vraiment aussi d'avoir une évolution nette, rapide, relativement rapide […] 30 PNJ qui se comporteraient exactement comme des joueurs, qui essaieraient de s'organiser, avec si vous voulez des managers aussi […] qui s'occuperait des ressources, […] de la construction, […] tout ce qui va être automatisé, la construction de tel ou tel objet, […] d'améliorer par exemple les infrastructures existantes […] pouvoir concentrer ses efforts sur collecte de ressources, […] une interface pour vraiment manager en fait ces équipes, […] un conflit en fait de production, un conflit d'évolution également de ressources, qui va réussir à acquérir quelles ressources à certains endroits, un conflit entre les factions, pouvoir s'attaquer, pouvoir également ressusciter des workers, […] à combien ça coûte, la vitesse également des workers, parce que peut-être qu'ils pourront crafter plus vite, s'améliorer plus vite, se déplacer légèrement plus vite aussi, que le joueur principal »
  → conception lancée (lot IA1). Les deux sens du mot « ouvriers » (chantiers simultanés des niveaux,
  et PNJ des factions) y sont distingués ; leur unification est proposée.

- 21 h 38, **Q18 (ordre)** : « Oui : IA1 se construit en parallèle de la Compaction, juste après le visuel. »

- 21 h 45, **Q19, précision sur l'amélioration, les PNJ et le scénario** (transcription) : « quand je parlais d'amélioration […] Dans Clash of Clans, c'est on améliore et on attend. Alors que là, l'idée, c'est si on a les ressources, on améliore, terminé. Parce que c'est comme pour poser les constructions […] c'est instantané. Bah, c'est pareil pour l'amélioration en vérité. […] la logique en fait de pipeline […] de production, qui s'adapterait à l'environnement […] il y aurait différents pôles […] peut-être que 5 entre guillemets, et ces 5 là ils piloteraient en fait différentes parties […] ça serait vraiment des ouvriers à part entière, mais qui soient multifonctions […] les couteaux suisses […] concentrer nos efforts sur tel ou tel aspect, que ce soit la ressource, que ce soit l'amélioration de la base […] la protection […] pouvoir dire je veux contrôler cette zone là […] j'ai relu votre scénario et le scénario est bien […] je l'aime bien. Très difficile à mon avis à faire en modèle, etc., 3D, mais je suis sûr que vos agents y arriveront. Paralyser un maximum pour essayer d'avancer au plus vite, mais tant que c'est qualitatif […] et pas uniquement on change la saturation ou la teinte des bâtiments […] il faut que ce soit également optimisé […] il faut pas qu'il y ait 1 million de polygones »
  Décisions :
  - **L'amélioration devient instantanée** dès que les ressources sont là, comme poser un bâtiment, pour le
    joueur comme pour les PNJ. Les durées de chantier et la limite de chantiers simultanés disparaissent
    (E1-2 et E1-4 révisés) ; Q17 (file de chantiers) est sans objet. Mise en œuvre : lot V2c.
  - **C5 précisé** :
    - production adaptative pilotée par les objectifs ;
    - pôles ;
    - environ 5 généralistes « couteaux suisses » sur 30 ;
    - le joueur oriente ;
    - contrôle de zones.
    La conception d'IA1 a été relancée avec cette précision.
  - **Scénario X0 approuvé** par le Directeur Créatif.
  - **3D** : qualité exigée, parallélisme maximal, et un budget d'optimisation (nouvel objectif D4 : mémoire
    vidéo, atlas, chargement ; le nombre de polygones n'a pas de coût en jeu, car les modèles sont pré-rendus
    en images).

- 21 h 52, **Q20** : « Ok, oui, continuez, la synthèse est parfaite. […] Concernant la mémoire vidéo, partez du principe que je jouerai sur des PC qui auront au minimum 8 Go de VRAM. Ce PC actuel en a 16. C'est une RX 6900 XT […] globalement 8 Go de VRAM, c'est bien pour la mémoire vidéo. »
  → synthèse de Q19 validée ; PC cible : 8 Go de mémoire vidéo au minimum (D4-1 : atlas du jeu ≤ 6 Go).

- 21 h 55, **Q21** : « veillez vraiment à ce que la version basse qualité soit pas si basse que ça, mais qu'il puisse être […] qu'on puisse garder, si on veut, la sensation de gigantisme, en fait, par exemple, des usines factoriaux. […] quand vous dites que la basse qualité n'est plus la priorité, c'est d'accord, hein, complètement, mais par contre, il faut quand même que la basse qualité puisse avoir un certain range […] pour pouvoir vraiment faire tourner le jeu correctement. Parce que j'ai l'impression qu'en fait, en ayant des images de haute qualité, ça fait que même avec mes 16 Go de RAM, j'ai l'impression que je vais saturer très vite. Alors que peut-être pas du tout, je me trompe »
  → D4-2 renforcé, D4-5 ajouté, lot D4m (banc de mémoire vidéo et d'usine géante).

- 22 h, **Q22 (autonomie pendant la nuit)** : « vous avez carte blanche, je valide entièrement toutes vos
  décisions. Seulement, voilà, évitez en fait les utilisations d'outils MCP qui nécessitent une validation
  préalable […] puisque bah, je serai en train de dormir ». L'orchestrateur décide seul jusqu'au retour du
  Directeur Créatif. Un design reste soumis à son verdict sur captures : les planches seront prêtes à son
  retour.

- 22/10, 7 h 15, **verdict sur les planches V3 phase 1** : « Alors en regardant plus près j'ai l'impression que ça ne respecte pas la direction artistique du jeu un peu. C'est peut-être qu'impression de ma part. Mais du coup, j'ai l'impression que ça ne respecte pas la direction artistique du jeu. Ça manque de détail en fait les dizaines sont pas mal, je dis pas, mais j'ai l'impression que ça manque de détail et en fait, on a pas l'impression que les niveaux supérieurs sont vraiment plus badasque les niveaux inférieurs en réalité. »
  Décisions :
  - finition de la phase 1 arrêtée (travail conservé) ;
  - lot V3-S : définir une charte de direction artistique MESURABLE (densité de détail, palette, patine,
    masse) à partir des sprites vanilla et de la cheminée V0 validée ;
  - la puissance doit croître avec l'époque : plus de masse, de blindage, de complexité mécanique et
    d'énergie visible, jamais des formes plus grêles ;
  - « ajourer » (Q8) se relit comme des treillis et des structures mécaniques denses, et non comme des vides
    nus ;
  - les couleurs d'époque sont réservées aux éléments lumineux ;
  - validation sur UNE famille témoin (la mitrailleuse) avant de reprendre les 7.

- 22/10, 7 h 20, **Q23, puissance perçue et taille** : « il y a un truc qui est assez difficile à faire en design […] si jamais on ne connaît pas le jeu et qu'on regarde tel niveau, on a vraiment l'impression que ce niveau-là est plus puissant que le niveau du dessous […] Et surtout, il y a aussi un manque de taille, il y a un problème également de taille, des bâtiments, ça fait bizarre d'avoir un bâtiment qui est vraiment très petit […] les dernières machines pour construire, elles sont de taille, je sais pas moi 6 par six, par exemple, ça m'étonnerait pas […] des tailles qui augmentent des hauteurs qui augmentent aussi un peu pas les hauteurs moins mais les tailles oui, peut-être beaucoup plus […] Et du coup avec la taille, c'est pas que on agrandir l'échelle finalement, c'est on augmente aussi les détails, voilà. »
  → D1-4 révisé : l'emprise grandit avec les époques, jusqu'à environ 6 × 6, avec plus de détail.
  Ajout du test du regard naïf. V3-S arrêté puis relancé avec ces règles (échelle proposée pour la
  mitrailleuse : 2×2, 3×3, 4×4, 5×5, 6×6 par ère).
  Question Q24 : agrandissement sur place si la place est libre, ou bâtiment à part.
- 22/10, 7 h 22 : Stable Diffusion local. Le Directeur Créatif : « je pense que le stabelle diffusion locale
  c'est mauvaise idée euh parce que il est pas très puissant. Et faites des tests, sait jamais faites des
  tests et dites-moi du coup. » → test lancé (concepts seulement, rien installé ni téléchargé).

- 22/10, 7 h 40, **Q24** : « Q24 : agrandissement sur place si la place autour est libre ; sinon l'amélioration est refusée et le contour nécessaire s'affiche. Aussi, notez bien l'avancée du projet quelque part, histoire que si un autre agent doit reprendre la gestion du projet, elle ne recommence pas tout »
  → mécanique d'agrandissement à faire avec la reprise de V3 ; création de `REPRISE.md` (état du projet pour
  l'orchestrateur suivant), à tenir à jour à chaque jalon.

- 22/10, 21 h 06, **Q-T2-1 (usine réelle et règle du carré contenant)** : « QT21 option B ». B = le bouton
  « libérer la place », tel que posé dans le chat : « On garde la règle, et j'ajoute un bouton "libérer la place". Il
  marque les gêneurs à démonter par les robots et pose des fantômes pour les reconstruire décalés. »
  → lot V3-T3, lancé à 21 h 10, intégré dans `main` le 22/10 à 22 h 50 (fusion `8a28804`, version 0.4.4 ; E56 à E59,
  F103 à F110). La règle Q24 ne change pas. Limite déclarée : dans une rangée de bâtiments collés, seuls les bouts de
  rangée se libèrent (5 sur 19 sur l'usine dense de test, 2 sur 13 sur la défense dense ; E59).
- 22/10, 21 h 06, **Q-T2-2 (production par tuile)** : « QT22 j'ai rien compris ». Question reformulée dans le chat à
  21 h 08 (exemple du four : 9 fois plus de place pour 2,4 fois plus de vitesse). Réponse à 21 h 12 : « QT22 ah ouais
  non du coup, l'idée est vraiment d'avoir un idle massif en fait, des coûts qui augmentent évidemment, mais ça
  typiquement c'est pas possible donc A » (A = la production suit la surface ; améliorer reste toujours rentable).
  → lot V3-T4, lancé à 21 h 15, livré sur sa branche (`worktree-wf_9d38a6df-249-1`, tête `2b18742`) et **NON intégré** :
  la densité est tenue, la rentabilité ne l'est pas (E60 à E62, F111 à F118 ; question Q-T4-1, posée dans le chat
  vers 22 h 45, ouverte).
- 23/10, vers 7 h 50, **retour sur les canons (pages des passes 3 et 4 de V3-E)** : « un retour sur les canonds : je les trouves parfait, même si j'attendai un peu plus de design exhautique, en fait je pense que pour les canons c'est un peu normal que ce soit comme ça, pour le reste (usines, foreuses, etc... hormis les bras mécaniques je pense (qui seront "juste plus rapide" avec un léger nouveau design peut être) le reste devra avoir plus de design surprenant, mais les canons sont vraiment bien. En fait le pour qui me dérange un peu c'est que dans clash of clans, les designs, changent vraiment beaucoup d'une évolution à une autre, et du coup on remarque vraiment la différence (bon eux ils ont pas ta problématique qui est d'augmenter la taille etc et du coup t'as parfaitement faitp, le soucis c'est vraiment quand je les vois j'ai un effet wow mais j'ai encore du mal à deviner en fait quel est le grade légende par exemple, je pense pas qu'il faille mettre à la poubelle, mais simplement revoir le niveau de différence entre chaque age en fait, et du coup la DA avec, je pense qu'on va benchmark la DA de l'age avec les canons du coup ».
  Lecture : (1) canons « parfaits », effet « wow », style et précision gardés (rien à la poubelle) ; (2) MAIS d'un âge
  à l'autre la différence doit être aussi franche qu'entre deux évolutions d'une défense de Clash of Clans, et la
  Légende doit se deviner ; (3) la mitrailleuse sert d'ÉTALON pour la direction artistique de chaque âge ; (4) les
  autres familles (usines, foreuses…) auront des designs plus surprenants encore ; les bras mécaniques seront
  « juste plus rapides », avec au plus un léger nouveau design.
  → passe 5 de V3-E arrêtée à 7 h 55 au début de sa ronde 1 (travail gardé : commits `4027228` et `aaf827d`), puis
  reprise vers 8 h 05 avec un principe révisé : chaque âge change la matière de TOUT le bâtiment (second temps du kit :
  clés d'habillage du pont, de la trémie, de l'acier, des rivets), sa silhouette (superstructures d'âge), ses canons,
  ses tuyaux et sa lumière, avec une progression de prestige jusqu'à l'or blanc lumineux de la Légende ; nouveau test
  à l'aveugle « des écarts » (paires d'âges de même taille notées de 1 à 5, critère Clash of Clans ; objectif moyenne
  ≥ 4, aucune sous 3, Légende désignée comme grade ultime par tous les lecteurs) ; 4 rondes au plus.
- 23/10, vers 9 h 48, **aperçus de la ronde 2 de la passe 5 (page de suivi)** : « alors, je viens de voir et c est parfait, les designs sont vrm bien, seul siucis c est que c ezt trop uniforme en therme de palette de cçuleur; mais si non les designs sont vraiment top ».
  Lecture : les designs (formes, canons, précision) de la ronde 2 sont validés par le DC ; le seul défaut est la
  PALETTE, trop uniforme. Les deux sens sont appliqués : (1) d'un âge à l'autre, une couleur dominante propre à chaque
  âge, différente de ses voisins (plus de trois âges gris 10 à 12, ni deux âges sombres à touches rouges 2 et 5, ni deux
  laitons 3 et 4) ; (2) dans chaque bâtiment, une dominante, une secondaire qui contraste et un accent vif (60/30/10).
  → consigne écrite à 9 h 50 dans les journaux des deux plages (`fo-logs\2026-10-23_V3E-p5\bas\journal.md` et
  `haut\journal.md`), que les constructeurs lisent au début de chaque ronde : palette en priorité dès la ronde 3 ; les
  clés de forme du troisième temps du kit (lancé à 9 h 48, avant cette remarque) deviennent facultatives, à n'utiliser
  que là où un âge se confond encore avec son voisin.
  Lecture confirmée par le DC dans le chat : « oui c est parfaitement ca ».
- 23/10, vers 12 h 40, **aperçus de la ronde 5 de la passe 5 (page de suivi)** : « je viens tout juste de voir la xerniere ronde et je trouve que tous les batiments sont pratiquement parfait sauf les 3 derniers, la couleur ne mne va pas, pareil pour le theme legende, je prefererai un truc genre bigbang ou maitrise cosmique du nean, je penze que le defaut est suttout lie au senario pour le coup ».
  Lecture : âges 1 à 12 « pratiquement parfaits » (ils partent en rendus définitifs, lancés à 12 h 33) ; âges 13 à 15
  (Fusion, Orbite, Légende) : couleurs refusées, thème « Légende » refusé, sommet voulu « Big Bang » ou « maîtrise
  cosmique du néant » ; le défaut vient du SCÉNARIO de ces âges, pas de l'exécution.
  → question posée dans le chat (A : ère V entièrement cosmique, 13 Étoile, 14 Nébuleuse, 15 Néant / Big Bang,
  recommandation ; B : Fusion et Orbite gardées avec de nouvelles couleurs, seule la Légende devient Big Bang / Néant ;
  C : autre). Sans réponse à la fin des rendus définitifs (vers 14 h), l'orchestrateur part sur A. Les noms des âges
  dans le jeu changeront à l'intégration.
  Option A précisée ensuite dans le chat pour suivre l'histoire du jeu (`shared/content/epochs.lua` : antimatière et
  strangelets à l'âge 13, la Porte sur le trou noir du Cœur à l'âge 14, le Cœur qui s'éveille à l'âge 15) : 13
  Antimatière, 14 La Porte, 15 Néant (ou Singularité). Réponse du DC vers 13 h 10 : « l option A est bien ».
  → run `wf_5f1609fb-473` (ère V cosmique), lancé vers 13 h 15 dans le worktree `v3e-ereV` (depuis `v3e-p5-haut`,
  `68ec5a1`) : fiches de direction artistique, rondes jugées à l'aveugle (descriptions des âges 13 à 15 remplacées),
  production, validation, planches. Les âges 1 à 12 ne sont pas touchés ; leurs aperçus de la ronde 5 sont copiés
  dans `fo-logs\2026-10-23_V3E-ereV\ref\`.
- 23/10, vers 14 h 50, **ère V cosmique, aperçus de la ronde 2 (page de suivi)** : « c est valide, les styles sont parfait, j aime beaucoup, il reste evidemment les animation et les bruits mais si non c est parfait, je valide les designs de l ere V, il manque encore les biomes, des styles de mineraux, de nouvelles ressources et des moyens pour les e ploiter mais si non cest bien, passez a le suite ».
  → **Designs de la mitrailleuse VALIDÉS par le DC pour les 15 âges** : âges 1 à 12 de la ronde 5 de la passe 5 (E65),
  ère V de la ronde 2 du run `wf_5f1609fb-473` (commit `6d0e961`). Ronde 3 de l'ère V arrêtée à 14 h 55 (travail gardé
  sur la branche `v3e-ereV-r3-wip`) ; branche de référence `v3e-final` (`40cad92`, worktree `v3e-p5-kit`) = âges 1 à 12
  de `v3e-p5` + ère V de `6d0e961`. Rendus définitifs de l'ère V, test à l'aveugle final des 15 âges et planches
  finales : run `wf_c46edecb-f29`, lancé vers 15 h.
  Restent dits par le DC : les animations et les bruits de la mitrailleuse ; les biomes, des styles de minerais, de
  nouvelles ressources et des moyens de les exploiter (lots B6, B7 et X1 à X15). « Passez à la suite » : déploiement
  de la méthode aux 6 autres familles (lots V3), avec des designs plus surprenants (consigne du 23/10, 7 h 50), et
  intégration en jeu de la mitrailleuse.
- 23/10, vers 15 h 05, **portée de la suite** : « en fait la liste serait beaucoup plus exhaustive que les simples quelques elements listes precedemment, comme les cçnvoyeurs par exemple, ou des balles, ou des nukes, ou des robots de defense, ou des bras mecanique, ou encore des ressources, des mineraux, des animations etc etc etc ».
  Lecture : la refonte porte sur TOUT ce qui se voit et s'entend dans le jeu (logistique, munitions, robots, ressources,
  minerais, animations, sons…), pas seulement les 7 familles de niveaux. → étude de la suite relancée en ce sens (run
  `wf_632b4009-57a` : inventaire exhaustif de data.raw, intégration en jeu de la mitrailleuse, déploiement de la
  méthode, contenu ; critique ; synthèse `fo-logs\2026-10-23_plan-suite\PLAN_SUITE.md`).
- 23/10, vers 16 h 20, **questions du plan** (Q-P1 à Q-P3) : « pour le disque c tout bon, pour les dessins des canons c est la A,  pour la question 3 on fait la C, long mais tant pis ».
  → Q-P1 = A : 1 776,5 Mo déplacés vers `C:\Users\evan2\fo-archives\fo-logs\` (journaux laissés en place) ; H: affiche
  ensuite 16,3 Go libres, bien plus que ce déplacement (cause extérieure au projet). Q-P2 = A : 64 positions. Q-P3 : C
  annoncée, mais « long » désigne B (un design par âge) : confirmation demandée.
- 23/10, vers 18 h 45, **intégrations de la suite** (run `wf_2f1793c9-578`, chacune vérifiée par un agent adverse ; aucun défaut
  bloquant ni majeur, défauts mineurs notés dans `fo-logs\2026-10-23_suite\INT-*\verification.md`) : **INT-K0** (fusion
  `e4e8416` : kit commun sur `main` ; empreinte FORTE des 72 variantes 0 différence contre `93e3d89` ; têtes d00 et d16 des âges
  2, 9 et 15 identiques octet à octet aux poses validées ; `rose.py` et `e66.py` réparés et identiques à A1 ; `test_famille`
  12 OK), **INT-GARDE** (fusion `b80f2bb` : garde des durées des animations de tourelle selon E67 : vitesses = clés de jeu,
  nombre d'images libre, durée = 1 / vitesse ; levels_test 1 661 ; mutants de l'ancienne règle détectés ; seule la levée est
  mesurée en moteur, les autres animations suivent la doc), **INT-GRAINE** (fusion `0db5493` : `FO_MAP_SEED` dans
  `fo-autotest.bat` et `fo-captures.bat`, défaut 20261020 inchangé, valeurs filtrées ; F137 à F139 ; `.bat` recopiés à la
  racine par l'orchestrateur après vérification que la racine était identique à l'ancienne source). Moteur réel sur `main` après les fusions (23/10, `done.txt` de 18:42:28,16 à 18:43:51,14 ; archives `<racine>\fo-logs\2026-10-23_integration-0.4.5-b\`) : `content` 317 ; `monde` 89 ; `m0-reprise` 15 ; `m0-migration` 9 ; `t2-machines` 80 ; `t3-libere` 41 ; `bord-a-bord` 12 ; `ht3-migration` 30 + journal 7 ; `t2-migration` 64 + 26 ; `t2-defense` 36 + 19 (0.4.1) et 36 + 11 (0.4.2) ; `t3-migration` 7 ; **sur une autre graine (`FO_MAP_SEED` = 123456789, `seed.txt` relu)** : `content` 317 et `monde` 89. Hors jeu (vers 18 h 50) : run 114, war 92, td 270, pteam 15, migration 82, monde 157, **levels 1 661** + 11 écarts connus, epochs 16 665, org 362, pvp 596 ; harness 0 erreur ; api_lint 669 ; d4m 5/5 ; mut_atlas 40 ; test_ht3_journal 15 ; **bat_double_source 25** ; mut_vram 18/18.
- 23/10, vers 19 h 05, **décision D-6 de l'orchestrateur (lot A2)** : les feuilles d'images du jeu vivent DANS le dossier du mod
  (`graphics/levels/<famille>/`), sinon la partie du DC ne les voit pas, mais HORS de git (`.gitignore`) ; un manifeste commité
  (fichier, taille, sha256, dimensions) et la commande de régénération depuis les sprites de production les décrivent ; les
  bancs copient le dossier du mod tel quel. Le plan proposait un magasin `<racine>\fo-sprites\` hors du mod : écarté, car il
  exigeait de changer les `.bat` ET laissait la partie du DC sans images. → lot **A2** (mitrailleuse en jeu à 4 directions)
  lancé vers 19 h 05 (run `wf_0143e61e-944` ; sorties `fo-logs\2026-10-24_A2\` ; identifiants réservés F123 à F129, E68).
- 23/10, vers 20 h 50, **fusion du lot A2 et version 0.4.6** (orchestrateur ; fusion `e0088bd` de
  `worktree-wf_0143e61e-944-1` : constructeur `ba9edef`, correcteur `4837368` ; changelog `ef64f79`). Vérification
  adverse (`fo-logs\2026-10-24_A2\verification.md`) : 4 défauts majeurs, tous corrigés et prouvés (ordre socle puis
  pièce des niveaux pairs ; éclat de l'âge 12 à 1,25 tuile ; garde D4m élargie sans cause, cause trouvée : F125 ;
  D-6 qui cassait un checkout neuf, désormais signalé par le harness et `levels_test` avec la commande de
  régénération). Après la fusion, `feuilles.py` a régénéré dans `main` les 318 PNG (13,04 Mo), `git status` propre. Moteur réel sur `main` 0.4.6 (23/10, `done.txt` de 20:53:22,75 à 20:54:56,46 ; archives `<racine>\fo-logs\2026-10-23_integration-0.4.6\`) : `content` 317 ; `monde` 89 ; `m0-reprise` 15 ; `m0-migration` 9 ; `t2-machines` 80 ; `t3-libere` 41 ; `bord-a-bord` 12 ; `ht3-migration` 30 + journal 7 ; `t2-migration` 64 + 26 ; `t2-defense` 36 + 19 (0.4.1) et 36 + 11 (0.4.2) ; `t3-migration` 7 ; **`gun-rose` 11** (20:54:32,19) ; sur la graine 123456789 : `content` 317 et `monde` 89 ; `fo-captures.bat gun-rose` : code 0, 90 captures (`captures-gun-rose\`). Hors jeu (fin à 21:02) : run 114, war 92, td 270, pteam 15, migration 82, monde 157, **levels 1 662** + 11 écarts connus, epochs 16 665, org 362, pvp 596 (369 s) ; harness code 0 (Règles 0, Images 0, étalonnage vanilla 0 sur 2 505 prototypes, auto-contrôles 11/11 et 17/17, **Feuilles mitrailleuse 318, 0 manquant, 0 écart**, 0 clé) ; **api_lint 676** ; d4m 5/5 ; **mut_atlas 50** ; test_ht3_journal 15 ; bat_double_source 25 ; mut_vram 18/18 ; **check_gun_sheets `--sources --mutants` 12 OK**. Mineurs non traités : `NOTES.md` §13.7 (lueur du socle sous la tête dans la carte de lumière ; bouchon
  arrière par secteur, à trancher avant A3 ; `fo-captures.bat d4-geant` code 0 malgré un banc en échec ; restes et
  explosions jamais vus en destruction ; icônes d'âge jamais vues dans l'interface). Écart relevé à l'intégration : le
  correcteur annonçait 92 captures `gun-rose`, son dossier en contient 90, comme `main`. Correctif de l'orchestrateur :
  `check_gun_sheets.py` plantait sur la console cp1252 (caractère « ≠ ») sans `PYTHONIOENCODING` ; sortie passée en
  UTF-8 comme `ht3_journal.py`, 12 OK. Identifiants : bloc F120 à F129 épuisé ; F140 à F149 et E105 à E108 réservés à
  A3 et A4. Page pour le DC : https://claude.ai/artifact/THuwtt63j4DN8TNSSgzz9B (rien à valider).
- 23/10, vers 21 h 25, **run `wf_e1ae9f59-b47`** (orchestrateur ; deux chaînes en parallèle, A3-préparation et S0,
  chacune constructeur, vérificateur adverse, correcteur). **Décisions de l'orchestrateur pour A3** (délégation Q25) :
  D-7 appliquée (ombre à 32 échantillons, autres passes à 128, sous réserve d'identité octet à octet des autres passes) ;
  **D-10** : le bouchon arrière des âges 4 à 7 n'est posé que dans les directions où la fente se verrait sans lui
  (trou > 8 px hr), saut aux bords mesuré et regardé ; trous enfermés traités avant la production ; garde de 1 Go dans
  `with_render_lock.py` ; production de nuit lancée par l'orchestrateur après la vérification.
- 23/10, vers 22 h 55, **fusion du lot S0 et version 0.4.7** (fusion `4593893` de `worktree-wf_e1ae9f59-b47-2` :
  constructeur `cdf8d32`, correcteur `e3a50dc` ; changelog `e4d9e03` ; `fo-autotest.bat` recopié à la racine après
  contrôle que la racine était l'ancienne source). Sons COMMITÉS (20 OGG, 0,5 Mo, `sound/levels/gun/`, avec `sons.lua`
  généré et un manifeste ; contrairement aux PNG de D-6, ils sont petits). **Défaut bloquant de la vérification,
  confirmé** : les sessions de test « son actif, volumes à 0 » émettaient du son sur la sortie du PC (crête −34,6 dBFS,
  relevé WASAPI) ; sessions 05, 06, 08, 09 et 13 du constructeur et v04 du vérificateur, entre 21 h 30 et 22 h 15
  environ : probablement audibles chez le DC. **Faute de l'orchestrateur** : la consigne exigeait « volume 0 prouvé avant
  tout lancement », pas une MESURE de la sortie. Règle depuis : toute session avec son passe par `FO_AUDIO=1`, le pilote
  SDL `disk` et le garde de crête (`audio_guard.py`, code 10) ; jamais de vraie sortie audio (CLAUDE.md §4). Correction
  prouvée : 0 session audio Windows du jeu, relevé indépendant 0,000000 sur 41 550 relevés. Moteur réel sur `main` 0.4.7 (23/10, `done.txt` de 22:57:15,32 à 22:59:00,81 ; archives `<racine>\fo-logs\2026-10-23_integration-0.4.7\`) : `content` 317 ; `monde` 89 ; `m0-reprise` 15 ; `m0-migration` 9 ; `t2-machines` 80 ; `t3-libere` 41 ; `bord-a-bord` 12 ; `ht3-migration` 30 + journal 7 ; `t2-migration` 64 + 26 ; `t2-defense` 36 + 19 (0.4.1) et 36 + 11 (0.4.2) ; `t3-migration` 7 ; `gun-rose` 11, et 11 avec `FO_AUDIO=1` ; sur la graine 123456789 : `content` 317 et `monde` 89 ; **`fo-captures.bat gun-rose` avec `FO_AUDIO=1`** : code 0, 90 captures, « Driver:disk » et « Loading sounds... » au journal, garde : 0 session audio Windows du jeu en 2 416 relevés, crête 0 (`captures-gun-rose-audio\session.txt`). Hors jeu : run 114, war 92, td 270, pteam 15, migration 82, monde 157, levels 1 662 + 11 écarts connus, epochs 16 665, org 362, pvp 596 (387 s) ; harness code 0 (**Sons 0 violation**, auto-contrôle 13/13 ; images 17/17, feuilles 318) ; api_lint 676 ; d4m 5/5 ; mut_atlas 50 ; test_ht3_journal 15 ; **bat_double_source 40** ; mut_vram 18/18 ; **test_audio_session 21** ; **`sons.py --check` 20** ; check_gun_sheets 12 ; `test_audio_guard` (4 OK au lot) NON rejoué par l'orchestrateur : il joue 3 s d'un son de 30 Hz à −70 dBFS sur la vraie sortie du PC. Page
  d'écoute : https://claude.ai/artifact/3pqTNcBVakEah1qB2gF5dG (sons PROVISOIRES, Q-S0-1). Écarts : le constructeur puis le correcteur ont recopié
  temporairement leur `.bat` à la racine sous un AUTRE nom (`fo-autotest-s0.bat`, `fo-autotest-s0c.bat`, effacés
  ensuite) : les `.bat` de la racine n'ont pas été touchés, mais la consigne ne le prévoyait pas. Non prouvé : le tir
  joué en jeu (l'auditeur des sessions avec images n'est pas aux sites de tir) ; la source du fond sonore insensible
  aux volumes (F152).
- 24/10, vers 0 h, **fusion du lot A3-préparation** (orchestrateur ; fusion `a7f1166` de `worktree-wf_e1ae9f59-b47-1` :
  constructeur `16121ec`, correcteur `9c16e3d` ; outils de rendu seulement, version inchangée). Vérification adverse
  (`fo-logs\2026-10-24_A3\verification.md`) : 1 défaut majeur (M-1 : une exception tuait un fil de `produire_a3.py`
  sans bruit et le code de sortie pouvait valoir 0 avec des têtes manquantes), corrigé et prouvé (`test_produire_a3`,
  43 OK) ; 8 mineurs, dont m-4 corrigé ; m-2, m-3, m-6 à m-9 laissés (`NOTES.md` §14). Après fusion, sur `main` : `test_garde_disque` 11 OK, `test_produire_a3` 43 OK, `test_famille` 12 OK, `check_gun_sheets --sources --mutants` 12 OK, `produire_a3.py --dry-run` « 72 faites, 768 à faire ».
  **Décision de l'orchestrateur : production sur UNE place de rendu** (m-2, F145 : deux sessions n'apportent pas plus
  de débit et chargent deux fois le PC du DC ; une place reste libre pour les autres lots). **Production de nuit
  lancée le 24/10 à 0 h 00** : `cd <mod> && PYTHONUTF8=1 py -3.9 tools/render/pieces/levels/gun_e/produire_a3.py --places 1` (Git Bash, en arrière-plan ; sortie `<racine>\fo-logs\2026-10-24_A3\production-nuit.out`) ; 768 têtes (14 âges × 60 directions, moins les 72 du pilote), durée
  prévue 8 à 10,5 h ; journal `production.log` ; arrêt propre par le fichier `STOP` ; reprenable par la même commande.
- 24/10, vers 0 h 25, **run `wf_93b960d8-a9c`** (A3-jeu progressif et S0-suite, sans Blender ; le premier essai
  `wf_232ab1e0-846` a échoué à 0 h 20 sans rien faire : session placée hors du dépôt git, aucun worktree possible).
  **S0-suite** accepté par son vérificateur (aucun bloquant ni majeur, 3 mineurs). **Le constructeur d'A3-jeu a été
  coupé vers 2 h 20 par une erreur de serveur (529, surcharge)**, après 3 commits (`3b81356`, `5d1e4a6`, `b2bf80d` :
  âges 2 à 7 à 64 directions, repli à 4, éclat sur toutes les directions, gun-rose à 20 directions) ; une première
  reprise (`wf_17da36fe-9d2`) a échoué aussitôt sur la même erreur ; reprise relancée à 2 h 33 (`wf_bcc3f79d-bc7`).
- 24/10, vers 2 h 30, **fusion de S0-suite** (fusion `4ffd852` de `worktree-wf_93b960d8-a9c-2` : `d6d8c59`, `fd80dc4`,
  `729cb4e`) puis **version 0.4.8** (volume du tir par ère). **Décision D-11 de l'orchestrateur** (délégation Q25) :
  le contrat de volume des rafales est le contrat « distribution » (chaque quantile de l'ère au moins 0,5 dB sous la
  vanilla, sur 5 longueurs × 101 suites de variations ; vérifié sur les 1 024 suites possibles de 5 tirs) ; le contrat
  « apparié » (même suite pour la vanilla et l'ère) n'est pas tenu (+0,33 à +1,28 dB sur 50 ms) et coûterait 1,1 à
  2,0 dB de volume : pas soumis au DC, qui jugera à l'oreille (Q-S0-1). Sur `main` après la fusion (24/10, `done.txt` de 2:28:28,32 à 2:30:22,15 ; archives `<racine>\fo-logs\2026-10-24_integration-S0-suite\`) : les 17 bancs en moteur réel verts (`content` 317, `monde` 89, `m0-reprise` 15, `m0-migration` 9, `t2-machines` 80, `t3-libere` 41, `bord-a-bord` 12, `ht3-migration` 30, `t2-migration` 64, `t2-defense` 36 et 36, `t3-migration` 7, `gun-rose` 11 et 11 avec `FO_AUDIO=1`, **`s0-tir` 5**, `content` 317 et `monde` 89 sur la graine 123456789) ; session avec son `fo-captures s0-tir` (`FO_AUDIO=1`), deux passages, garde : 0 session audio Windows du jeu : `tirs_joues.py` **35/36 au 1er passage** (un tir de l'ère II non reconnu au site 6, corrélations du site 0,54 à 0,57 contre 0,65 à 0,98 ailleurs ; BILAN ECHEC) puis **36/36 au 2e** (site 6 : 0,67 à 0,98) : banc un peu instable, 1 échec sur 5 passages en tout (lot, vérificateur, intégration) ; hors jeu : run 114, war 92, td 270, pteam 15, migration 82, monde 157, levels 1 662 + 11, epochs 16 665, org 362, pvp 596 (381 s), harness code 0 (Sons auto-contrôle 24/24), api_lint 682, d4m 5/5, mut_atlas 50, ht3_journal 15, bat_double_source 40, mut_vram 18/18, test_audio_session 21, `sons.py --check` 20, check_gun_sheets 12, **mut_sons 6**.
- 24/10, vers 3 h 50, **reprise d'A3-jeu achevée** (run `wf_bcc3f79d-bc7` : reprise `6bd7a46` après le constructeur
  coupé ; le vérificateur n'avait pas pu démarrer au premier passage, la session de l'orchestrateur étant sortie du dépôt
  git, relancé par `resumeFromRunId` ; vérification : 0 bloquant, 1 majeur, 8 mineurs ; correcteur `1e09519`). Défaut
  majeur confirmé et corrigé : pour l'âge 2, l'ajustement de l'éclat écartait 11 directions sur 64 (dont E et O validées)
  au lieu d'appliquer le refus à 0,5 tuile (sans exclusion, 0,568 tuile en d54). **Décision D-12 de l'orchestrateur**
  (délégation Q25, provisoire) : option A du correcteur : une direction écartée du réglage n'est admise que si elle a été
  tirée en jeu, REGARDÉE et inscrite dans `feuilles.ECLAT_ECARTEES_OK_DEFAUT` (sinon l'âge reste à 4 directions) ; les 11
  directions de l'âge 2 sont inscrites ; de même, les 5 têtes « HORS REGLE » (jours mécaniques de 10 à 17 px, âges 3 et
  6) regardées sont acceptées par `HORS_REGLE_OK_DEFAUT`. Les deux listes sont au manifeste et seront montrées au DC.
- 24/10, vers 3 h 55, **fusion d'A3-jeu** (`3fe1da6`) puis **version 0.4.9** : la tête des âges 2 à 8 tourne sur 64
  positions dans la partie du DC ; les âges 9 à 15 passeront à 64 après la production, par `FINALISATION.md`
  (`<racine>\fo-logs\2026-10-24_A3-jeu\`). Sur `main` après la fusion (`3fe1da6`) et la régénération des feuilles (`feuilles.py --ages-64 2,3,4,5,6,7,8` : 318 PNG, 52,06 Mo, 505 sources, 7 âges à 64 directions, 7 à 4 ; `git status` propre ; `check_gun_sheets --sources --mutants` 17 OK) : moteur réel, 24/10, `done.txt` de 3:53:12,64 à 3:55:17,74 (archives `<racine>\fo-logs\2026-10-24_integration-A3-jeu\`) : les 17 bancs verts, dont **`gun-rose` 13 OK** (et 13 avec `FO_AUDIO=1`), `content` 317, `t2-defense` 36 et 36, `s0-tir` 5 ; `fo-captures gun-rose` : code 0, **150 captures**, `gun_rose_images.py` « 252 OK, 0 FAUX, 28 ambigu(s) » (les ambiguës : directions à 45° pile des âges encore à 4) ; rose de l'âge 8 à zoom 2 regardée par l'orchestrateur ; hors jeu : run 114, war 92, td 270, pteam 15, migration 82, monde 157, levels 1 662 + 11, epochs 16 665, org 362, pvp 596 (366 s), harness code 0 (ligne « Tetes mitrailleuse (A3-jeu) : 7 age(s) a 64 directions, 7 a 4 », auto-contrôle 4/4), api_lint 683, d4m 5/5, mut_atlas 50, ht3_journal 15, bat_double_source 40, mut_vram 18/18, test_audio_session 21, `sons.py --check` 20, mut_sons 6. Mineurs non traités (m-1 à m-8 de `verification.md`) :
  `git status` sali par `feuilles.py` sans option pendant la production (le nombre de têtes manquantes est écrit), PNG
  effacés avant les refus (pas d'écriture atomique), permutation cohérente non vue par `check_gun_sheets`, centre de plage
  seul contrôlé dans `gun-rose`, forme diagonale de F126 non mesurée, comparaison D4m d'une heure à l'autre, README de
  `gun_e` absent.
- 24/10, vers 4 h 15, **run `wf_0e7edcdd-4f2`** (A4-préparation et D4m-géant, presque sans Blender pendant la
  production). Vers 5 h 45, **fusion de D4m-géant** (`d7efe80` de `worktree-wf_0e7edcdd-4f2-2` : constructeur
  `0a13534`, correcteur `4dbea8d`) : le banc `d4-geant` est recalé (F128 résolu : chaque niveau à sa taille, F161) ;
  vérification : 1 majeur (le contrôle « 64 images demandées » était une tautologie de la formule, rien n'était lu du
  moteur), corrigé par une galerie de 960 mitrailleuses (64 par âge) dont les images sont relues dans le moteur ;
  `fo-captures.bat` rend 8 quand un BILAN du banc est en échec (mineurs non traités : un banc arrêté avant son BILAN
  rend toujours 0 ; le code 8 a deux sens). Sur `main` après la fusion (`d7efe80`), 24/10 : `d4-geant` **18 OK** (`done.txt` 5:46:15,72), `content` 317 (5:46:22,71), `gun-rose` 13 (5:46:29,24) ; archives `<racine>\fo-logs\2026-10-24_integration-D4m-geant\` ; hors jeu : bat_double_source **47**, run_d4m 5/5, api_lint **685** ; `fo-captures.bat` recopié à la racine à 5:45:53, verrou des bancs libre, après contrôle que la racine était l'ancienne source. Ménage du disque (orchestrateur) : copies du mod retirées
  de 6 archives d'intégration (2,16 Go) et 35 worktrees fusionnés et propres retirés (branches gardées) ; le dossier
  d'A4 a dépassé la consigne de 1 Go (1,8 Go à 5 h 10) : alerte posée sous 4 Go libres.

### Décisions d'architecture et d'outillage (plan de la suite ; lots A0, A1, K0, M0 ; 23/10, après 15 h)
- **Plan de la suite** (`fo-logs\2026-10-23_plan-suite\PLAN_SUITE.md`, synthèse de 15 h 35 à 16 h 15) : refonte
  visuelle et sonore de tout ce qui se voit et s'entend, en 9 étapes ; ordre et suivi des lots : OBJECTIFS §6 et §7.
  Run `wf_2bade7c0-0e8` (lancé vers 15 h 55) : lots A1, K0 et M0, chacun dans son worktree, avec un constructeur, une
  vérification adverse et un correcteur ; sorties `fo-logs\2026-10-23_suite\`.
- **Lot A0 (orchestrateur), fait en partie** : fusion de `v3e-final` dans `main` (`93e3d89`) ; `REFUSES.txt` posé dans
  `fo-logs\2026-10-23_V3E-p5\final\sprites\` ; identifiants réservés (en-tête de ce fichier) ; phrases du DC de 14 h 50
  et 15 h 05 inscrites ; déplacement Q-P1 (A) fait vers 16 h 25. **Non fait au 23/10, 18 h 30** : tri des worktrees
  périmés (relevé à 18 h 14 : 59 dossiers dans `.claude\worktrees`, 60 lignes de `git worktree list`) ; seuil de 1 Go
  libre sur H: avant chaque paquet de rendu (absent de `tools/render/with_render_lock.py`) ; magasin des feuilles hors
  de git (décision D-6 B).
- **Dégel D-9 de `piece.py`** (lot A1) : directions `dKK` = −2π·K/64 (K = 00 à 63 ; 0 = nord, sens horaire, comme le
  moteur : E70), `d00` égal à `N` et `d16` égal à `E` à l'égalité exacte des flottants ; variantes `eNN-tete-dKK` et
  `kS-tete-dKK` construites à la demande, table explicite inchangée (72 variantes) ; `rendre.py --dirs rose|N,NE,…|d00,…`.
  Preuve, en moteur de RENDU : `rendre.py --epochs 2,9,15 --parts "" --dirs N,E --samples 128` (329 s, code 0), puis
  `identite.py` : **36 fichiers sur 36 identiques octet à octet** aux sprites validés (âges 2, 9, 15 ; poses N et E ;
  couches main, shadow, glow ; hr et normale ; sha256 = ceux des spec.json). Rejouée par le vérificateur depuis le code
  commité (âges 2 et 9, 24 fichiers : identiques). Pièges latents relevés par la vérification (mineur D7, non corrigé,
  aucun appelant touché) : `PIECE["variants"].get("e02-tete-d08")` rend `None` (`dict.get` n'appelle pas
  `__missing__`) ; `rendre.py --kit … --dirs …` ignore `--dirs` sans rien dire.
- **Orienter une tête de tourelle à l'arrêt** (pour le scénario `gun-rose` du lot A2) : écrire `LuaEntity.orientation`
  (F122). Ne PAS mettre `apply_projection = false` et ne pas « corriger » les angles du rendu (F121, déduit).
- **Garde des durées d'animation du kit des niveaux** (`prototypes/levels/common.lua`) : fausse (E67, F120) ; correction
  confiée au lot INT-GARDE (run `wf_2f1793c9-578`, en cours à 18 h 30) : les vitesses deviennent des clés de JEU
  inchangées, le nombre d'images devient libre, la durée vaut 1 / vitesse.
- **Ombre de la tête à 32 échantillons** (E66) : retenue pour l'estimation d'A3, avec le gain MESURÉ dos à dos de
  44,7 % sur la tête entière (le 51 % de la première mesure est faux). Le réglage des échantillons par passe
  (décision D-7) n'existe pas encore dans le kit (`batch_blender.py`) : à ajouter avant A3.
- **Générateur de ressources et de sols depuis `X.resources` et `X.tiles` : REPORTÉ AUX LOTS X** (décision de
  l'orchestrateur, 23/10, sur le défaut M-2 de la vérification du lot M0). Raison : sur 35 prototypes interrogés par
  le correcteur (15 ressources de `X.resources`, leurs 15 produits, 5 tuiles de `X.tiles` ; `harness --dump-final`,
  `fo-logs\2026-10-23_suite\M0\correction\m2-prototypes-interroges.txt`), **34 n'existent pas encore** ; seul
  `item/stone` existe, produit de `fo-impact-breccia`, dont le biome `fo-crater-fields` est lui-même absent. Le
  générateur n'aurait aucune entrée à traiter. Chaque lot X l'étendra avec ses images (X-II fumerolle, X-III galène,
  X-IV cratères et sables noirs, X-V évents, sol étrange, abysse), et étendra `G.specs()` aux `placement.guaranteed` de
  `X.resources` (mineur m-8). Ce que M0 livre : les 3 ressources existantes générées depuis `W.resource_order`, sortie
  identique (E75).
- **Garantie des monnaies (lot M0)** : dans une partie neuve, le site est TOUJOURS posé (choix du lot ; Q-M0-1 posée
  au DC) ; un échec n'est plus définitif (correction M-1 : reprise par paliers). La graine paramétrable des bancs
  (`FO_MAP_SEED`, proposée par M0, fichier du lot P1) est confiée au lot INT-GRAINE (en cours à 18 h 30).
- **Kit commun des familles (lot K0)** : `tools/render/pieces/levels/commun/` (ARCHITECTURE §7 ter), en cours
  d'intégration par le lot INT-K0 (branche `worktree-wf_2bade7c0-0e8-2`, tête `87c4fb1`). Graines de bruit inertes
  (F136) : **NON corrigées**, décision du DC requise (les activer changerait tous les designs validés).
- Écart de méthode déclaré par le lot A1 : un correctif de `rose.py` passé par un heredoc Bash qui contenait des sauts
  de ligne échappés, contre la consigne (REPRISE §6) ; diff vérifié ligne à ligne, rien d'abîmé (relu par le
  vérificateur, mineur D9).

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

### Faits vérifiés en moteur réel (lot D4m-géant, banc d4-geant recalé, 24/10, 4 h 05 à 5 h 15 ; fusionné dans `main`, `d7efe80`)
Preuves : `fo-logs\2026-10-24_D4m-geant\` (`NOTES.md` §1 à §7 et « Correction », `verification.md`). Expérience : E117.

| ID | Fait | Conséquence |
|---|---|---|
| F161 | **Observé en moteur réel**. Un greffon qui dimensionne une famille à niveaux par son PLUS GRAND côté et centre les niveaux plus petits dans la case perd le contact bras/tapis de ces niveaux (731 bras reliés sur 2 440, 193 foreuses sur 376) ; depuis 0.4.3, un niveau se pose à SA taille, collé à ce qu'il sert. Un moteur simulé qui pose tous les niveaux au côté de base laisse un essai à blanc vert sur un banc rouge. | `d4-geant.lua` pose chaque niveau à sa taille ; `d4_dryrun.lua` lit `L.footprint` et la règle des points. |
| F162 | **Observé en moteur réel** (572 tourelles de l'usine, puis 960 de la galerie, 2×2 à 6×6). L'orientation écrite au tick 30 sur des mitrailleuses à niveaux, chargées, sans cible, avec ou sans bras, est relue identique (à 1/1024) au tick 120 ; l'image relue par l'inverse d'`orientation_image` donne les 64 valeurs par âge. Au-delà du tick 120 : vu à l'œil seulement. | F122 et F123 tiennent dans une usine dense ; la galerie de `d4-geant` charge les 64 images de chaque âge pour la mesure de mémoire vidéo. |

### Faits vérifiés en moteur réel (lot A3-jeu, têtes à 64 directions en jeu, 24/10, 0 h 25 à 4 h ; fusionné dans `main`, `3fe1da6`, version 0.4.9)
Bloc A3 et A4 : F146 à F149 ; A3-jeu prend F146 à F148. Preuves : `fo-logs\2026-10-24_A3-jeu\` (`NOTES.md` §4 à §10 et
§13 ; `verification.md` ; `captures-reprise\`, `correction\`, `d4m-reprise\`). Expériences : E109 à E111.

| ID | Fait | Conséquence |
|---|---|---|
| F146 | **Observé en moteur réel** (E109). Une tête `RotatedAnimation` à `direction_count = 64`, `line_length = 8`, en UN fichier par couche (côté jusqu'à 3 296 px essayé), sans `slice`, se charge, et le moteur montre l'image K pour l'orientation `orientation_image(K)` (`apply_projection` vrai) : 140 tourelles sur 140 reconnues au pixel (marge minimale 8,4) ; seul le centre de la plage de chaque image est contrôlé. | Feuilles 8 × 8 par couche, âge et résolution ; `gun_rose_images.py` compare chaque capture aux feuilles. |
| F147 | **Mesuré, indirect** (E111, lignes « Created atlas bitmap »). Le moteur range dans l'atlas les images ROGNÉES de leurs marges transparentes : l'atlas grandit de 1,10 à 1,18 × les pixels de la boîte d'alpha de chaque image, soit 0,53 à 0,58 × les cellules entières. | Estimer la mémoire vidéo sur les boîtes d'alpha, pas sur les cellules : 15 âges à 64 directions ≈ 1,30 à 1,47 Go en haute, 0,46 à 0,51 Go en normale (extrapolé). |
| F148 | **Observé en moteur réel** (E111). En `--video-memory low` (plancher), les sprites d'objets vont dans l'atlas virtuel, de taille FIXE (9 pages de 4 096², 151 Mpx) : ajouter 7 âges de têtes à 64 directions ne change ni ces pages ni le compteur de mémoire dédiée (0,42 Go) ; seul l'atlas d'ombres grandit. | Au plancher, le coût des 64 directions est surtout dans l'atlas d'ombres. |

### Faits vérifiés en moteur réel (lot S0-suite, le tir joué en jeu, 24/10, 0 h 25 à 2 h 15 ; fusionné dans `main`, `4ffd852`, version 0.4.8)
Preuves : `fo-logs\2026-10-24_S0-suite\` (`NOTES.md` §1 à §4, `verification.md`, `moteur\`, `rafales\`). Expérience : E113.

| ID | Fait | Conséquence |
|---|---|---|
| F155 | **Observé en moteur réel** (sessions 02, 04 et 10 du lot ; témoin : c02 de S0). En `--benchmark-graphics` avec le pilote SDL `disk`, l'écouteur des sons du monde est le joueur connecté : le téléporter près d'une tourelle suffit pour que chacun de ses tirs soit dans la sortie mixée, avec le fichier de son prototype (36 tirs sur 36, ère juste) ; sans téléportation (`gun-rose`), aucun tir entendu. `game-effects-volume=0` du `config.ini` passé par `--config` ne coupe pas les tirs. La sortie `disk` avance de 0,982 s pour 60 ticks. Le volume du prototype (`SoundDefinition.volume`) s'applique (baisse de 0,21 à 0,41 dB retrouvée à 0,1 dB près). | Banc `s0-tir` + `tools/sound/tirs_joues.py` : un tir est joué, avec quel fichier, à quel instant et à quel volume relatif. Instable à la marge : 1 échec sur 5 passages (un tir non reconnu, corrélation sous 0,50). |
| F156 | **Observé en moteur réel** (sessions 05 et 06 ; avec images et son). Un `.ogg` au flux OPUS est accepté au chargement, puis le jeu lève « Exception at tick 161: Audio clip sample "<fichier>" not loaded! » au premier tir qui tire cette variation (la suite en partie normale n'est pas observée) ; un Ogg Vorbis COUPÉ à 60 % ne donne aucune erreur, et les tirs qui le tirent sont muets (2 sur 6 ; attribution à cette variation déduite). | Ni le chargement des sons (F151) ni `fo-autotest.bat` ne voient un mauvais codec ou un fichier tronqué : règle « sons » du harness relisant tout le flux (Vorbis, en-têtes, pages, fin de flux ; `mut_sons.py`, 6 OK). |

### Faits vérifiés (lot A3-préparation, têtes à 64 directions, 23/10, 21 h 25 au 24/10, 0 h ; fusionné dans `main`, `a7f1166`)
Bloc réservé à A3 et A4 : F140 à F149 ; A3-préparation prend F140 à F145. Preuves : `fo-logs\2026-10-24_A3\` (`NOTES.md`
§10, §11 et §14 ; `verification.md` ; `d7\`, `masques\`, `bouchon\`, `trous\`, `pilote\`, `reprise\`, `estimation\`).
Expériences : E105 à E108.

| ID | Fait | Conséquence |
|---|---|---|
| F140 | **Observé** (Blender 5.2.2, Cycles, pipeline ; E105). Dans une session, rendre UNE passe avec un autre nombre d'échantillons laisse les autres passes identiques octet à octet au rendu d'origine (8 poses, 32 fichiers), et la passe modifiée est octet à octet celle d'un rendu entier à ce nombre (ombre à 32 = rose d'A1). | D-7 sans risque pour les designs validés : `--samples-passes shadow=32` ; gain mesuré dos à dos 42,8 % sur la tête entière. |
| F141 | **Observé** (pipeline ; E106). L'alpha de la couche principale d'une tête ne dépend pas des matières : un rendu à émission noire, sans rebond ni sol, à 16 échantillons, au cadrage de production, donne 99,75 à 99,91 % de pixels binaires identiques à la production à 128 (56 poses) ; plus grand trou enfermé à 3 px près. | Masques rapides (0,2 s par pose) pour la règle des trous et le cadre, validés contre la production. |
| F142 | **Observé** (pipeline ; E107). Les rayons qui traversent la fente arrière des âges 4 à 7 passent par l'avant-haut puis l'arrière-bas de la boîte du bouchon d'A2 : aucune plaque mince ne les arrête tous (9 formes) ; la boîte réduite à 20 % de sa profondeur côté bras les arrête aux bords du secteur, réduite à 10 % non (âge 7 : 14 px). | D-10 : secteur mesuré par âge (4 : d20 à d44 ; 5 et 6 : d21 à d43 ; 7 : d19 à d46) et rampe de profondeur jusqu'à 80 % ; saut au bord 123 à 241 px hr au lieu de 482 à 1 222 ; d16 et d32 identiques octet à octet. |
| F143 | **Mesuré** (masques ; E106). Sur les 60 directions nouvelles des 14 âges (840 poses), 72 (8,6 %) ont un trou enfermé de plus de 8 px hors bouchon : surtout l'âge 11 (28 poses, jusqu'à 382 px, ailettes détachées vues à plat) ; ailleurs au plus 44 px. | Aucun comblé : acceptés avec classe et raison (`trous_a3.py`) ; à montrer au DC (jour bras/coque de l'âge 9, ailettes de l'âge 11). |
| F144 | **Lu dans la doc 1.1.91** (`prototype-api.json`), NON essayé en moteur. Un fichier d'image est limité à 8 192 px de large et de haut ; une feuille de tête à 64 directions (8 × 8 images) tient dans un seul fichier à tous les âges (au plus 4 896 × 3 424 px hr). | A3-jeu : une feuille par couche, âge et résolution, sans `slice` (F23). |
| F145 | **Observé sur le PC du DC, NON isolé** (vérificateur : e05-tete-d21 en 23,3 s seule contre 45,4 s à deux ; e15 : 77 s contre 143,5 s). Deux sessions Blender de rendu de tête en parallèle (8 fils chacune, priorité basse) ne donnent qu'environ 1,0 à 1,1 fois le débit d'une seule ; un banc d'un autre lot tournait pendant une partie des mesures. Le plan supposait 1,59. | Production sur une place (`--places 1`) : même durée, une place libre, moitié moins de charge. |

### Faits vérifiés en moteur réel (lot S0, la chaîne des sons, 23/10, 21 h 25 à 22 h 45 ; fusionné dans `main`, `4593893`, version 0.4.7)
Bloc réservé à S0 : F150 à F153 ; F154 pris hors du bloc (le « F152 bis » du correcteur devient F153, son F153 devient
F154). Preuves : `fo-logs\2026-10-24_S0\` (`NOTES.md` §2, §3 et §7 qui fait foi ; `verification.md` ; `moteur\`,
`correction\`). Expérience : E69.

| ID | Fait | Conséquence |
|---|---|---|
| F150 | **Observé en moteur réel** (E69, sessions 03 et 04). En `--create` et `--benchmark` (« Running in headless mode »), aucun son n'est chargé, avec ou sans `--disable-audio` : journaux identiques hors horodatages ; un fichier son manquant passe sans erreur. | `fo-autotest.bat` ne voit pas un son manquant : le banc des fichiers son est `FO_AUDIO=1` + `fo-captures.bat`, et la règle « sons » du harness hors jeu. |
| F151 | **Observé en moteur réel** (E69, sessions 05 à 08, 13). En `--benchmark-graphics` sans `--disable-audio`, le jeu ouvre l'audio (SDL, 44 100 Hz) et charge TOUS les sons des prototypes au démarrage (« Loading sounds... », 1,7 s après le lancement) ; un fichier manquant donne « Error SoundLibrary.cpp:56: Missing sound when loading sound library: <fichier> », le jeu revient au menu SANS les mods (« Resetting config ») et y reste jusqu'à l'arrêt automatique (122 s observées) ; avec `--disable-audio`, le même mutant passe. | Un son manquant bloque la partie du DC au menu : règle « sons » du harness (fichier présent, extension .ogg, .wav ou .voc, en-tête juste). |
| F152 | **Mesuré** (vérification : relevé WASAPI à la sortie du PC ; correction : sortie du pilote SDL `disk`). Les 9 clés `[sound]` à 0 du `config.ini` de test (`master-volume`, `music-volume`, `game-effects-volume`, `gui-effects-volume`, `walking-sound-volume`, `environment-sounds-volume`, `alerts-volume`, `wind-volume`, `simulation-volume` ; noms lus dans le binaire 1.1.91) NE rendent PAS la session silencieuse : crête −34,6 dBFS, continue dès 3,6 s ; aux volumes par défaut, crête −21,6 dBFS ; de 10 à 24 s, les deux sorties sont le même signal (corrélation 1,000). Source de ce fond : non identifiée. | Une session de test avec son ne doit JAMAIS ouvrir la vraie sortie : pilote `disk` (F153) et garde de crête. |
| F153 | **Observé en moteur réel** (correction de S0, sessions c01 à c03). Le SDL de Factorio 1.1.91 n'a PAS le pilote audio `dummy` (« Audio target 'dummy' not available », « Resetting... », puis « Driver:wasapi » : retour à la vraie sortie) ; il a le pilote `disk` (`SDL_AUDIODRIVER=disk`, `SDL_DISKAUDIOFILE`) : « Driver:disk », aucune session audio Windows, la sortie mixée est écrite dans le fichier au rythme réel, les sons sont chargés et un son manquant fait toujours échouer le chargement. | `FO_AUDIO=1` passe `SDL_AUDIODRIVER=disk` au seul jeu de test ; le pilote de session exige « Driver:disk » et « Loading sounds » au journal, sinon code 10. |
| F154 | **Observé** (Blender 5.2.2, module `aud`). Il décode l'OGG et le MP3 et écrit WAV, OGG Vorbis et MP3 ; l'encodeur Ogg tire au hasard le numéro de série du flux : deux encodages du même WAV diffèrent de 32 octets (série et CRC de chaque page), l'audio décodé est identique. | `tools/sound/sons.py` fixe la série et recalcule les CRC : sorties identiques au sha256 d'un passage à l'autre. |

### Faits vérifiés en moteur réel (lot A2, la mitrailleuse en jeu à 4 directions, 23/10, 19 h 05 à 21 h 00 ; fusionné dans `main`, `e0088bd`, version 0.4.6)
Bloc réservé à A1 à A4 : F120 à F129 ; A2 prend F123 à F129 (bloc épuisé ; A3 et A4 : F140 à F149). Run `wf_0143e61e-944`
(constructeur `ba9edef`, vérification adverse, 4 majeurs ; correcteur `4837368`). Preuves : `fo-logs\2026-10-24_A2\`
(`NOTES.md` §9, et §13.6 qui fait foi quand les deux diffèrent ; `verification.md` ; `correction\`). Scénarios greffés
`gun-rose` et `a2-icones`. Expérience : E68.

| ID | Fait | Conséquence |
|---|---|---|
| F123 | **Observé en moteur réel** (`gun-rose`). Une RotatedAnimation à 4 directions, une image, `line_length = 1` (feuille en colonne) est lue de haut en bas N, E, S, O : `orientation` écrite à 0 ; 0,25 ; 0,5 ; 0,75 dessine la 1re, 2e, 3e, 4e ligne (canons en haut, à droite, en bas, à gauche), `apply_projection` laissé vrai. 150 tourelles des 30 niveaux, avec munitions et sans cible : orientation écrite tenue du tick 30 au tick 900 (F122 étendu à toutes les tailles). | Les feuilles de tête à 4 directions sont rangées N, E, S, O de haut en bas ; à 64 directions (A3), rotation uniforme (F121). |
| F124 | **Observé sur captures** (moteur réel, zoom 2, jour). L'ombre (`draw_as_shadow`) de la tête d'une tourelle ne s'affiche que sur le sol : elle n'assombrit pas le socle (`base_picture`) de la même entité. | L'ombre de la tête tombe à l'est sur le sol, jamais sur le socle ; une ombre sur le socle devrait être peinte dans le socle (non demandé). |
| F125 | **Observé en moteur réel** (passages D4m en qualité normale, copies jetables, `correction\d4m-icones\`). Avec les icônes d'âge de la mitrailleuse (64 px + 3 mipmaps, bande 120 × 64), l'atlas [icon] de la qualité normale (mémoire « all » et « low ») perd `linear-mip-level` selon le NOMBRE d'icônes : 14 → absent ; 13 ou 15 → présent ; 14 icônes au contenu vanilla → absent ; atlas 8192 × 2288 dans les 4 cas ; en haute qualité, à 14, présent. Mécanisme dans le moteur : inconnu (pas de source). Remplace la proposition du constructeur (cause non identifiée). | Le drapeau dépend du rangement de l'atlas, pas du contenu ni de la taille. Effet visible en mode Alt (zooms 0,45 ; 0,7 ; 1,3) : nul au pixel ; dans l'interface : non mesuré. `run_d4m.py` ne tolère l'absence qu'en qualité normale ET avec la ligne « [FO-GUN-ICONES] » du mod dans le journal. |
| F126 | **Mesuré en moteur réel** (E68 : 60 tourelles, un niveau par âge × N, E, S, O ; contrôle final 60/60 à 1/32 de tuile, écart max 0,0089). L'éclat de tir d'une munition « instant » (`source_effects`, explosion `explosion-gunshot`) naît en projectile_center + projectile_creation_distance × (vx, vy) / √(vx² + (vy / 0,7071)²), v = cible − projectile_center ; en E et O, une cible proche le décale de distance × centre.y / portée. Une entité explosion se trouve par `find_entities_filtered{name = …}` au tick de sa création. Remplace la proposition du constructeur (modèle à décalage constant, réfuté). | Règle utilisée par `feuilles.py` (F129) et contrôlée par `gun-rose`. L'éclat se VOIT 1 tuile plus haut (hauteur par défaut d'une explosion) : supposé d'après la doc et la vanilla, non mesuré au pixel. |
| F127 | **Observé** (banc en moteur réel, dossier `fo-autotest\mods`). `fo-autotest.bat` recopie aussi les fichiers ignorés par git présents sur le disque de la source : 321 fichiers de `graphics/levels/gun` (318 PNG et les 3 fichiers commités). | La décision D-6 (PNG hors de git) ne prive pas les bancs des images ; une source SANS PNG (checkout ou worktree neuf) donne un mod que l'étape data refuse : lancer `feuilles.py` d'abord. |
| F128 | **Observé en moteur réel, préexistant** (banc `d4-geant` sur `main` 0.4.5). Le banc donne 10 OK, 6 ECHEC : ses seuils (5 000 bâtiments, 5 000 tapis, 4 000 bras, champ réel) datent de 0.4.1 ; avec les emprises de 0.4.3, l'usine n'en loge que 3 312. | Recaler `d4-geant` sur les emprises de 0.4.3 dans un lot D4m ; jusque-là, ses mesures de mémoire vidéo portent sur une usine plus petite que prévu. |
| F129 | **Déduit de F126** (pas d'expérience propre). Pour une cible lointaine dans la direction u, la règle de F126 rend centre + distance × (ux ; 0,7071 × uy) : une tourelle ne peut placer l'éclat au bout de canons dessinés dans les 4 directions que si leur longueur verticale à l'écran vaut 0,7071 × leur longueur horizontale. | `feuilles.py` ajuste `projectile_center` et `projectile_creation_distance` par âge, par moindres carrés sur les 4 directions, et refuse un âge au-delà de 0,5 tuile (écart max 0,076 à 0,167 tuile ; âge 2 : 0,404). |

### Fait vérifié dans Blender 5.2.2 (vérification et correction du lot K0, 23/10, 16 h 40 à 18 h 06 ; lot en cours d'intégration)
Trouvé par le vérificateur adverse du lot K0 (défaut 3 de `fo-logs\2026-10-23_suite\K0\verification.md`), confirmé
par son correcteur. Il est ANTÉRIEUR à K0 : il touche le pipeline de rendu depuis le lot V0 (`fo_scene.py`), donc
tous les designs validés de la mitrailleuse. Prochain numéro libre après le bloc de M0 : F136.

| ID | Fait | Conséquence |
|---|---|---|
| F136 | **Observé dans Blender 5.2.2** (scripts `verification\debug_w.py`, sorties `w_avant.txt` et `w_apres.txt` ; construction sans rendu de `e06-socle`). Sur un `ShaderNodeTexNoise` en 3D, la prise W est inactive : `"W" in node.inputs` rend FAUX et `node.inputs["W"]` lève `KeyError`, alors que W figure dans la liste des prises. Le test `if "W" in n.inputs: n.noise_dimensions = "4D"` de `fo_scene.mat_metal`, `mat_emissive` et de `kit._insert_stain` / `_insert_streaks` n'est donc JAMAIS vrai : le bruit reste en 3D, W vaut 0, **aucune graine de bruit n'est appliquée** (210 nœuds de bruit sur 210 en 3D avec W = 0 sur `e06-socle`). Contre-épreuve du correcteur : le lot K0 non corrigé (`0cee947`) décalait 7 graines de l'âge 6, sans aucune différence d'objet ni de matière à l'empreinte forte. | Toutes les matières de même échelle de grain ont le MÊME motif de bruit ; l'ordre des appels `metal()` et les graines n'ont aujourd'hui aucun effet sur l'image. **Non corrigé** : activer les graines changerait TOUS les designs validés : décision du DC requise. Dit dans `commun/ages.py`, `commun/LISEZMOI.md` et en commentaire de `commun/kit.py` (branche K0). Le contrôle d'empreinte forte relève quand même les graines, pour le jour où elles agiront. |
| F137 | **Observé dans cmd.exe** (lot INT-GRAINE, banc hors jeu `bat_double_source`, premier passage 20 OK et 5 ÉCHECS). En expansion retardée, `!VAR:x=!` sur une variable VIDE (donc non définie) ne rend pas le vide mais le texte `x=` : la graine « 42 » privée de ses chiffres devenait « 5= » et était refusée. | Toute substitution dans un `.bat` doit être gardée par `if defined VAR`. Gardé comme mutant m2 du banc. |
| F138 | **Observé dans cmd.exe** (lot INT-GRAINE, mutant m1 = la proposition du lot M0, racine jetable inspectée). `set SEED=%FO_MAP_SEED%` (expansion immédiate) EXÉCUTE ce qui suit un `&` dans la valeur : `FO_MAP_SEED=1&echo PIEGE>piege2.txt` a créé `piege2.txt` et laissé SEED=1. Entre guillemets, la valeur n'a rien exécuté mais a été passée au moteur en un seul argument. | Une variable d'environnement lue par un `.bat` se lit en expansion retardée dans un `setlocal`, et se filtre (chiffres seulement pour la graine) avant tout usage : c'est ce que fait `fo-autotest.bat` depuis INT-GRAINE. |
| F139 | **Observé sur ce PC** (PowerShell 7.6.7 ; vérificateur d'INT-GRAINE, défaut m-1). `$env:FO_MAP_SEED = ''` ne retire PAS la variable : elle reste définie, vide, pour les processus lancés ensuite (une valeur vide héritée reste présente pour `cmd`, F137). | Pour vider une variable de banc (`FO_CREATE_SRC`, `FO_MAP_SEED`), toujours `$env:X = $null` ; le `.bat` traite de toute façon une valeur vide comme absente (graine 20261020). |

### Faits vérifiés en moteur réel (lot M0, socle du monde, 23/10, 15 h 50 à 16 h 46 ; fusionné dans `main`, `da2e16f`, version 0.4.5)
Bloc réservé à M0 : F130 à F134 ; F135 vient du correcteur (hors du bloc, attribué ici, aucun autre lot ne l'a pris).
Sources : `fo-autotest.bat` sur le worktree `wf_2bade7c0-0e8-3` (constructeur `28fe15b`, correcteur `d6766d7`), code 0
et `done.txt` relu ; journaux `fo-logs\2026-10-23_suite\M0\` (notes `NOTES.md`, §6 du correcteur ; vérification
`verification.md`). Expériences : E73 à E76.

| ID | Fait | Conséquence |
|---|---|---|
| F130 | **Observé en moteur réel** (16:08:26, `m0-migration-v044-meme-version-bis`). Une sauvegarde 0.4.4 rechargée par la source M0 LAISSÉE en version 0.4.4 appelle `on_configuration_changed`, avec `mod_changes` VIDE, `mod_startup_settings_changed` faux et `migration_applied` faux, alors que les prototypes sont identiques à ceux de 0.4.4 à l'étape data (E75). Témoin : la même carte rechargée par une copie de 0.4.4 (seul ajout : un fichier du mod de test sous `tools/`) ne l'appelle PAS (16:08:10, `temoin-v044-v044`). | Le déclencheur est un changement du contenu du mod (scripts, traductions ou données internes), pas seulement des prototypes : cela AFFAIBLIT l'attribution « aux données » de F77 (déjà dite « déduite, non prouvée »). Ce qui change exactement : NON PROUVÉ (une somme de contrôle des fichiers du mod est supposée). La garantie ne compte pas sur cet appel : version montée à 0.4.5 et filet `on_nth_tick(600)`. |
| F131 | **Observé en moteur réel** (sonde du 16:01:46, `sonde-cartographie`). En `--create` puis `--benchmark` (`fo-autotest.bat`), RIEN n'est cartographié : `force.chart` posé à `on_init` ou au tick 2 ne produit rien en 400 ticks ; `is_chunk_charted` reste faux, même pour le chunk (0, 0) ; aucun `on_chunk_charted` ; `add_chart_tag` rend `nil` juste après `chart` comme 118 ticks plus tard. En `--benchmark-graphics` (`fo-captures.bat`), la cartographie tourne : les 3 étiquettes en attente sont posées par `on_chunk_charted` (sessions de 16 h 10 et 16 h 12, `captures-1`, `captures-2`). | `add_chart_tag` juste après `chart` échoue (chunk pas encore cartographié) : il faut attendre `on_chunk_charted` (fait par `script/world/guarantee.lua`). Un banc sans images ne peut pas contrôler une étiquette de carte posée ; il contrôle qu'elle reste en attente. |
| F132 | **Observé en moteur réel** (sonde du 15:50:20). `LuaSurface.calculate_tile_properties` accepte en 1.1.91 `elevation`, `moisture`, `aux`, `tile:<tuile>:probability`, `entity:<ressource>:probability` et `entity:<ressource>:richness` ; les valeurs sont rendues sur une surface sans aucun chunk généré, et identiques après génération. Un nom de couche de bruit du mod (`fo-biome-volcanic`) est absent du résultat, sans erreur. | Moyen de rejeter un candidat à bas coût AVANT de générer ses chunks (mineur m-2 de la vérification de M0 : non utilisé par M0). |
| F133 | **Mesuré en moteur réel** (LuaProfiler, journaux du banc `monde`). Génération forcée (`request_to_generate_chunks` + `force_generate_chunk_requests`) : 3 × 3 chunks à `on_init` en 19,8 ms ; sur une surface neuve, rayon 4 (225 chunks) en 108 ms, jusqu'au rayon 16 (1 540 chunks) en 1,0 s en tout ; rayon 23 (environ 2 850 chunks) en 1,89 à 1,97 s (5 graines). À l'`on_init` de la carte de banc, `get_chunks` voit déjà 418 chunks (statut non relevé). `delete_surface` : la demande prend 0,01 ms. | Savoir dans une partie neuve si la graine a déjà un gisement à 200-700 tuiles coûterait environ 2 s et une sauvegarde bien plus grosse : d'où le choix « site toujours posé » d'une partie neuve (Q-M0-1). |
| F134 | **Observé en moteur réel** (banc `monde`, cas D, 16:09:25 et 16:13:17). `count_entities_filtered{area, force = {"enemy", "neutral"}, invert = true, limit = 1}` compte bien une entité d'une autre force (coffre de « player ») dans la zone. | Le refus « batiment » de la garantie marche : le candidat 1 est refusé, le coffre reste intact. Seul un coffre a été joué (mineur m-6 : ni base, ni forces `fo-*`). |
| F135 | **Observé en moteur réel, un seul cas** (correcteur, `correction\m0-reprise-1\benchmark.log`, `done.txt` 16:44:35,08). `LuaSurface.set_tiles(tiles)` sans troisième argument (défaut `remove_colliding_entities = true`) RETIRE un coffre en bois du joueur recouvert par une tuile d'eau : 47 coffres sur 48 au contrôle final, et le candidat 8 de l'essai 0 refusé « sol » au lieu de « batiment ». | Dans un script, poser l'eau AVANT les entités (le banc `m0-reprise` corrigé le fait : 48 coffres intacts). La garantie elle-même ne pose de l'eau nulle part ; elle en retire (niveau 2 : eau comblée par le sol du biome). |

### Faits vérifiés en moteur réel (lot A1, directions et levée de la tourelle, 23/10, 15 h 52 à 16 h 48 ; fusionné dans `main`, `5a95650`)
Bloc réservé à A1 à A4 : F120 à F129 ; A1 prend F120 à F122. Sources : copie JETABLE du mod (`tools/autotest/a1/jetable.py` :
mod du worktree + prototypes de test en fin de `data-final-fixes`, têtes « flèches » numérotées), scénario greffé
`a1-tourelle` ; passage de référence `fo-logs\2026-10-23_suite\A1\moteur\banc3_1000ticks_final\` (`done.txt` 15:56:07,00,
« [FO-A1-TOURELLE] BILAN : 5 OK, 0 ECHEC(S) ») ; rejoué par le vérificateur sur une copie neuve (16:48:01,51, mêmes
chiffres) ; captures `moteur\captures\` (20 sur 20). Libellés corrigés selon les mineurs D4, D5 et D6 de la
vérification (`A1\verification.md`). Expériences : E67, E70.

| ID | Fait | Conséquence |
|---|---|---|
| F120 | **Observé en moteur réel** (E67 : 5 variantes, 20 tourelles, les 4 répliques identiques au tick près). La levée d'une tourelle (`preparing_animation`) dure **1 / `preparing_speed` ticks, à un tick près** (latence de détection de la cible comprise : 13 ticks pour 1/v = 12,5 ; 63 pour 62,5), **quels que soient le nombre d'images et `repeat_count`** (5 images, 1 image, 1 image × 5). Seule la DIFFÉRENCE est prouvée exactement : 63 − 13 = 50 = 62,5 − 12,5 ; arrondi au tick supérieur ou tick de détection : non séparés. La doc 1.1.91 le dit ; la garde du kit des niveaux (« images × repeat_count / vitesse », `prototypes/levels/common.lua`) le contredit. | La garde du kit laisse passer un changement de JEU (une tête à 1 image avec `preparing_speed` = 0,016 « garde » 62,5 ticks pour le kit, mais lève 5 fois plus lentement que la vanilla) et refuserait un changement purement visuel : correction en cours (lot INT-GARDE). Une seule image et `repeat_count = 1` suffisent pour la levée. NON JOUÉS : `folding`, `attacking`, `starting_attack`, `ending_attack`. |
| F121 | **Observé en moteur réel** (E70, captures 005 à 020), conséquence pour le pipeline **DÉDUITE**. Avec `apply_projection` (vrai par défaut), le moteur choisit l'image k d'une RotatedAnimation de 64 directions par la projection de l'orientation sur une rotation UNIFORME vue à 45° : N, E, S, O → images 0, 16, 32, 48 ; orientation 0,125 (cible au nord-est du monde) → image **6** (35,26° = atan(tan 45° × cos 45°)), 0,375 → 26, 0,625 → 38, 0,875 → 58. La tête repliée (`folded_animation` à 64 directions) suit la même règle. | Les feuilles `dKK` du pipeline (rotation uniforme −2π·K/64, caméra à 45°) seraient donc dans la convention du moteur : ne pas mettre `apply_projection = false`, ne pas corriger les angles du rendu. DÉDUIT par le calcul (vérifié en 4 points, chacun à ±½ image près) : seules des flèches 2D ont été vues en jeu, aucune feuille `dKK`. À prouver sur la première capture d'A2 (à 64 directions, la tête doit viser la cible au nord-est). Règle vue aux 8 directions seulement. La rose des planches (colonnes d08, d24, d40, d56) montre donc une cible à 54,7° du nord, pas le nord-est exact (mineur D2). |
| F122 | **Observé en moteur réel** (E70). `LuaEntity.shooting_target` écrit **vers une entité NEUTRE** (coffre indestructible) est accepté sans erreur, puis effacé dès le tick suivant ; la tête ne bouge pas (orientation 0 jusqu'au tick 900, avec ou sans munitions, flèche ou mitrailleuse vanilla). `LuaEntity.orientation` d'une tourelle se LIT (40 sur 40) et s'ÉCRIT (8 sur 8, sans erreur) ; l'orientation écrite TIENT sans cible du tick 60 au tick 900, et la tête est dessinée dans cette direction, levée ou repliée selon l'état. | Moyen retenu pour orienter une tête à l'arrêt (scénario `gun-rose` d'A2) : écrire `orientation`. Rien de plus général sur `shooting_target` : une cible ENNEMIE imposée (autre que celle que la tourelle choisirait) n'a pas été jouée (mineur D6). |

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

### Faits vérifiés en moteur réel (lot V3-T4, la production suit la surface, 22/10, 21 h 36 à 22 h 38 ; lot LIVRÉ, NON INTÉGRÉ)
Numéros DÉFINITIFS, attribués à la consignation des lots V3-T3 et V3-T4 (22/10, vers 23 h). Les deux lots ont tourné en
parallèle et ont proposé des numéros provisoires qui se chevauchent à partir de F103 et de E56. Règle retenue : le
lot INTÉGRÉ (V3-T3) garde ses numéros, parce que son code dans `main` les cite (`free.lua` : F103, E58 ; `clear.lua`,
`levels_clear_cases.lua`, `t3-migration.lua` : E56 ; `mock_engine.lua`, `t3-libere.lua` : F103) ; le lot non intégré
(V3-T4) prend le bloc suivant. Correspondance pour V3-T4 :
- faits : F103 → **F111**, F104 → **F112**, F105 → **F113**, F106 → **F114**, F107 → **F115**, F108 → **F116**,
  F109 → **F117**, F110 → **F118** ;
- expériences : E56 → **E60**, E57 → **E61**, E58 → **E62** ;
- les commentaires et les libellés de la branche citent encore les numéros provisoires (par exemple « F107 », « (E58) »
  dans les libellés du greffon `levels_production`) : à renommer à l'intégration du lot, si elle a lieu.

Sources : `fo-autotest.bat` lancé avec le worktree `wf_9d38a6df-249-1` comme source (branche
`worktree-wf_9d38a6df-249-1`, partie de `main` `e27bda9` ; ingénieur `f86f2fb`, `37c9c3f`, `4ee10f1` ; correcteur
`2b18742`), code 0 et `done.txt` relu à chaque passage. Archives : `<racine>\fo-logs\2026-10-22_V3T4\` (passages `01_` à
`23_` ; notes `NOTES_V3T4.md` : §1 à §8 de l'ingénieur, §9 du correcteur, qui fait foi). Ces faits portent sur le
MOTEUR : ils valent quel que soit le sort du lot. F3 (« une recette par tick », session 1) est CONFIRMÉ en moteur réel
par E62, sans nouveau numéro. Hypothèse ouverte : H-T4-1. Expériences : E60 à E62.

| ID | Fait | Conséquence |
|---|---|---|
| F111 | **Observé en moteur réel** (E60, version `f86f2fb`, passage `02_t4-production_cadence_E56`, 21:37:45,84). Une mitrailleuse (ammo-turret, chargeurs) ne tire pas plus de 30 fois par seconde, même avec un délai entre tirs inférieur à 2 ticks. Délai 6 ticks → 10,00 tirs/s ; 2,667 → 22,50 ; 1,5 → 30,00 (40 attendus) ; 0,96 → 30,00 (62,5) ; 0,667 → 30,00 (90). La doc 1.1.91 (`BaseAttackParameters.cooldown` : « If < 1, multiple shots can be performed in one tick ») ne le dit pas. | Le lot V3-T4 a renoncé à faire porter la règle de surface par la CADENCE des tourelles (la recherche de cadence, + 150 % pour les balles, aurait aussi été perdue) : ce sont les DÉGÂTS par tir qui portent R. Cause non prouvée : hypothèse H-T4-1. |
| F112 | **Observé en moteur réel, sur une version NON livrée** (E60, `f86f2fb`). Une tourelle laser dont le délai entre deux tirs (4,44 ticks) était inférieur à la durée de son faisceau superposait ses faisceaux et infligeait toute sa cadence (DPS × 19,08 du niveau 1, débit d'entrée de 186 624 kW). | Réécrit par le correcteur : sans objet pour la règle livrée par la branche, où le laser garde son délai de 40 ticks (relu par le harness : cooldown 40). À lire comme un résultat d'E60, pas comme un fait applicable au mod. |
| F113 | **Observé en moteur réel** (E61, passages `03_` et `04_` ; rejoué au passage `23_`, 22:38:32,19). Avec `crafting_speed` 59,76 (four) et 9,96 (assembleur) et `mining_speed` 7,8 (foreuse), le moteur fabrique et extrait exactement à la vitesse du prototype : écart < 0,03 % sur 40 s (`products_finished` + `crafting_progress`, `mining_progress`). La doc 1.1.91 ne donne aucun maximum (« positive »). | Aucune borne moteur sur la vitesse dans la plage du lot. La limite réelle est ailleurs : une fabrication par tick pour l'assembleur (F3, E62) et un seul point de dépôt pour la foreuse (F117). |
| F114 | **Observé en moteur réel** (E61 ; rejoué au passage `23_`). `emissions_per_minute` est la pollution à pleine consommation : les statistiques de pollution du jeu donnent, par objet, la valeur du prototype divisée par la production (four : 0,1067 → 0,0321 par plaque, du niveau 1 au niveau 30). | Multiplier énergie et pollution par R garde l'énergie et la pollution PAR OBJET de la courbe d'avant (× 0,301 = 1/m(30) pour le four et l'assembleur, × 0,256 pour la foreuse). La pollution TOTALE d'une usine qui convertit le gain en débit est multipliée par ce gain : effet sur l'évolution et les attaques non analysé. |
| F115 | **Observé en moteur réel** (E62, passages `12_` à `14_`, 22:26:30,56 à 22:30:17,34). Avec `ammo_consumption_modifier` > 1, un tir de mitrailleuse ne prend QUE sur le chargeur entamé : il consomme min(modificateur, cartouches restantes du chargeur), sans entamer le suivant. Chargeurs de 10, 10 tirs/s : modificateur 2,25 → 2,0 cartouches par tir ; 4 → 3,33 ; 6,25 → 5 ; 9 → 5. Avec 2,50025 / 3,33367 / 5,0005 / 10,001 : 2,5 / 3,333 / 5 / 10, exactement. La doc 1.1.91 dit seulement « Must be greater than or equal to 0 ». | La 6×6 ne prenait que 5 cartouches par tir au lieu de 9 (munitions 1,8 fois trop rentables avec le modificateur 9 ; R fois sans modificateur, version de l'ingénieur). Correctif de la branche : modificateur arrondi au chargeur (`L.magazine_quantize`), soit 1 ; 2,5 ; 3,33 ; 5 ; 10 cartouches par tir, et par dégât × 1,11 ; 0,83 ; 0,80 ; 1,11 de la courbe d'avant. La marge de 0,01 % n'est pas prouvée nécessaire (le mutant sans marge survit hors jeu). |
| F116 | **Observé en moteur réel** (E62). Une foreuse n'a PAS de plafond d'un résultat par tick : foreuse 30 avec 3 modules de vitesse de palier 10, sortie dans un coffre vidé à chaque tick : 63,96 minerais/s mesurés, égal à la théorie. | Contraste avec F3 (assembleur). Le débit réel d'une foreuse est borné par sa sortie (F117). |
| F117 | **Observé en moteur réel** (E62). La même foreuse, qui dépose sur un tapis express, ne remplit qu'UNE voie : 22,22 minerais/s mesurés, pour une voie de 22,5/s (`belt_speed` × 60 × 4). Un seul point de dépôt par foreuse. | Une foreuse 6×6 de haut niveau avec modules vaut moins sur un tapis que les foreuses plus petites posées à sa place : la règle « la grande vaut au moins les petites » (Q-T2-2, A) ne tient pas avec des modules aux niveaux 13 et 19 (écart connu de la branche). |
| F119 | (Pipeline de rendu, mesuré par le kit de la passe 5 de V3-E, 23/10.) Avec la caméra des sprites (inclinaison de 45°), un tube horizontal dirigé vers le nord se projette EXACTEMENT comme un tube vertical : à l'écran, y et z valent chacun 0,707, et sa bouche ne fait jamais face à la caméra. Une bague autour du fût se lit comme le haut d'une cheminée. | Un canon dressé en pose N ne se distingue d'une cheminée que par sa silhouette : faisceau qui converge en pointe, une seule bague à la culasse, aucun chapeau plus large que le faisceau (« canon effilé », `corps.canon_effile`). Un détail ajouté au bout ne suffit pas. |
| F118 | **Observé en moteur réel** (E62). La formule de résistance du moteur 1.1 est vérifiée au dixième près à 6 tourelles, contre `fo-armored-colossal-biter` (physique 26 fixe, 78 % ; aucune résistance au laser) : si les dégâts dépassent la part fixe, (dégâts − fixe) × (1 − %). DPS mesurés : mitrailleuse 1 au tungstène 30,8/s (7,70 par tuile) ; mitrailleuse 30 1 621,8/s (45,05 par tuile) ; tourelle lourde 112,2/s (12,47) ; lasers 1, 30 et lourd 30,0, 572,4 et 60,0/s (7,50 ; 15,90 ; 6,67 par tuile). | Des dégâts par tir multipliés par R traversent une résistance FIXE : au niveau 1, laser et tungstène font jeu égal ; au niveau 30, la mitrailleuse au tungstène fait 2,8 fois le laser par tuile. Le laser perd son rôle de contre des blindés (question du correcteur, Q-T4-3 proposée). Branche « 1/(2 − x) » (dégâts sous la part fixe) non mesurée : la régénération de l'unité, 0,1 PV par tick, la masquerait. |

### Faits vérifiés en moteur réel (lot V3-T3, « Libérer la place », 22/10, 21 h 41 à 22 h 51)
Numéros DÉFINITIFS (même consignation, 22/10, vers 23 h ; règle ci-dessus) : le lot V3-T3, intégré, GARDE ses numéros
provisoires, qui se suivent sans trou après F102 : F103 à F106 de l'ingénieur, F107 à F110 du correcteur ; expériences
E56 et E57 de l'ingénieur, E58 et E59 du correcteur. Les renvois du code de `main` restent justes ; le mot
« provisoire » des commentaires (`mock_engine.lua`, `t3-libere.lua`) est périmé.

Sources : `fo-autotest.bat` lancé depuis PowerShell, code 0 et `done.txt` relu à chaque passage, sur le worktree
`wf_49a2ed53-111-1` (branche `worktree-wf_49a2ed53-111-1`, partie de `main` `e7caed1` ; ingénieur `f26e9c3`, passage
final de 21:57:50 à 21:58:30 ; correcteur `d0b40da`, passages `passe1-*` de 22:45:34 à 22:46:07), puis sur `main` après la
fusion `8a28804` (22:50:45,71 à 22:51:53,59). Archives : `<racine>\fo-logs\2026-10-22_V3T3\` (notes `NOTES_V3T3.md` :
§1 à §4 de l'ingénieur, §5 du correcteur, qui fait foi ; `essai-E56\`, `correcteur\essai-E58\`) et
`<racine>\fo-logs\2026-10-22_V3T3-integration\`. Confirmés au passage, sans nouveau numéro : F79 et F89 (le bras d'entrée
vise la machine agrandie ; le bras reposé prend dans l'assembleur 7) ; un poteau moyen reconstruit par `revive` se
relie seul à son voisin (un cas, comme F101). Expériences : E56 à E59.

| ID | Fait | Conséquence |
|---|---|---|
| F103 | **Observé en moteur réel** (`t3-libere`, tick 60 ; ingénieur, 22/10 à 21:41 et 21:51 ; observé une seconde fois par le correcteur). Annuler par script la marque de démontage (`cancel_deconstruction`) d'une entité sur laquelle un fantôme a été posé par script RETIRE ce fantôme ; miner l'entité marquée le GARDE. | Payé : le premier passage comptait 4 fantômes retirés au lieu de 6. `Free.cancel` retire les fantômes du mod AVANT d'annuler les marques (étape f, en dernier, de `script/levels/free.lua`) ; même ordre quand une exécution est refusée par le moteur. |
| F104 | **Observé en moteur réel** (essai jetable E56). `create_entity` d'un assembleur 4×4 à une position hors grille (310,5 ; 250,5) le pose en (311 ; 251), et `teleport` vers (320,5 ; 250,5) le recale aussi, en (321 ; 251) : un script ne fabrique pas un bâtiment hors grille ; seule une migration le fait (F76). Cohérent avec F86 (position recalée par `create_entity`). | Le cas « bâtiment laissé hors grille » ne se joue qu'en double source : scénario `t3-migration` (création par `src-0.4.2`). |
| F105 | **Observé en moteur réel** (E56). `can_place_entity{name = "entity-ghost", inner_name, build_check_type = script_ghost}`, avec ou sans `forced`, n'est pas utilisable pour tester la place d'un fantôme : il rend true pour un bras posé sur un bras NON marqué et false pour un convoyeur sur une tuile libre. `can_place_entity{name = <nom réel>, build_check_type = ghost_revive}` rend false sur une entité marquée et true sur une tuile libre. Au passage : `create_entity` accepte un fantôme posé par-dessus une entité marquée ; `order_deconstruction` rend true ; `mine{inventory}` rend l'objet ; `revive` rend l'entité, orientation gardée. | La place d'un fantôme est contrôlée par la règle PURE, sur la scène relevée (`shared/levels/clear.lua`). Le banc vérifie ensuite chaque place avec `ghost_revive` juste avant de construire (ingénieur : 29 places, 0 refusée). |
| F106 | **Observé en moteur réel** (E56, puis zones A, B1 et E de `t3-libere` et `t3-migration`). Bosse d'une tuile dans une ligne de convoyeurs (tuile amont tournée vers l'extérieur, tuiles décalées, retour sur la tuile aval, qui devient un virage) : la ligne reste continue, et un bras posé sur l'ancienne tuile prend sur la bosse (4 plaques en 360 ticks). | Base de la règle 2 de `clear.lua` (« BOSSE ») : un convoyeur n'est jamais décalé seul. Une bosse coûte 2 convoyeurs de plus par tuile de profondeur. Deux bosses à la suite sur une même ligne marchent (zone G, E59). |
| F107 | **Observé en moteur réel** (essai jetable E58, correcteur, 22/10 à 22 h 19). `LuaEntity.copy_settings` sur un `entity-ghost` recopie les filtres et le mode d'un bras filtrant, sa condition de circuit, les demandes d'un coffre de demande et la barre d'un coffre ; tout est gardé au `revive`. La taille de pile imposée n'est PAS recopiée (0 après `revive`) ; posée directement sur le fantôme, elle est acceptée (2 sur le fantôme, 1 après `revive` : bornée par la force). | Les gêneurs reposés gardent leurs réglages (défauts 3 et 14 de la revue) ; la taille de pile est posée à part. Tenu en moteur réel par la zone A d'E59 (bras filtrant : filtre sur le fantôme, puis sur le bras reconstruit). Les fils de circuit, eux, ne sont pas refaits (message `free-wired`, non joué). |
| F108 | **Observé en moteur réel** (E58). `create_entity` d'un fantôme par-dessus une entité NON marquée est accepté (un bras sur un convoyeur). | Le moteur ne protège pas la place d'un fantôme : le script la contrôle lui-même (`place_free` de `clear.lua`). Étend F70 (pose sans contrôle de place) aux fantômes. |
| F109 | **Observé en moteur réel** (E58). `revive` rend une entité de NOUVEAU numéro d'unité (11 → 36). | Une entité construite à partir d'un fantôme du mod se retrouve par nom, position, direction et force, jamais par le numéro du fantôme (annulation après reconstruction, E59 zone C2). |
| F110 | **Observé en moteur réel** (E58, puis zone R d'E59). Avec de vrais robots de construction, un convoyeur marqué qui porte un fantôme tourné est démonté (environ 150 ticks après la marque, à 6 tuiles du roboport), puis le fantôme est construit (environ 60 ticks plus tard) ; un fantôme libre est construit sans attendre ; les objets démontés vont au coffre de stockage. Zone R : démontage fini au tick 390, agrandissement à la vérification du tick 450, reconstruction finie au tick 930. | Le mode principal du bouton (robots) marche en moteur réel. Sans robots (époques 4 à 9, avant les robots de construction), le joueur démonte et pose à la main : non joué par un vrai joueur. |

### Faits vérifiés en moteur réel ou dans le binaire (lot R1, robustesse, 22/10, 19 h 38 à 20 h 11)
Numéros DÉFINITIFS, attribués à l'intégration des documents du lot (22/10, vers 20 h 20). Les deux suites du lot
(run `wf_c34819e9-18a`, session `8a9c0503` ; chacune : un constructeur, une revue adverse, un correcteur) avaient
donné des numéros provisoires qui se chevauchaient. Correspondance :
- suite « défense dense et bord à bord » : F96 à F101 gardent leur numéro (les commentaires de `levels.lua` et de
  `levels_test.lua` citent « F96 provisoire, E53 », ceux de `migration_test.lua`, `mock_engine.lua` et
  `scenarios/bord-a-bord.lua` citent E53 : tous ces renvois restent justes, seul le mot « provisoire » est périmé) ;
- suite « vram » : son F96 (chaînes du binaire) devient **F102** ; sa « précision de F81 », relue dans un journal
  archivé et non nouvelle en moteur, ne prend pas de numéro : elle complète F81 ; son expérience E53 devient **E55**
  (les notes `fo-logs\2026-10-22_R1\vram\NOTES.md` disent encore « E53 (proposée) »).

Sources :
- F96 à F101 : `fo-autotest.bat` (scénarios greffés `bord-a-bord` et `t2-defense`, ce dernier en double source),
  lancé par le constructeur (`e74871d`, 19 h 48 à 19 h 55), par le correcteur (`f41753d`, 20:08:11 à 20:08:39), puis
  sur `main` après les fusions `dcc97b3` et `58db82c` (20:11:14 à 20:11:40) ; code 0 et `done.txt` relu à chaque
  passage. Archives : `<racine>\fo-logs\2026-10-22_R1\defense\` (`NOTES.md`, §4 : correcteur ; `correcteur\`) et
  `<racine>\fo-logs\2026-10-22_R1-integration\` ;
- F102 : lecture des chaînes de `factorio.exe` 1.1.91, en lecture seule, sans lancer le jeu (suite vram, `dac93fd` puis
  `75863a5`) ; ce n'est PAS un essai en moteur réel. Notes : `<racine>\fo-logs\2026-10-22_R1\vram\NOTES.md`.
Expériences : E53 à E55.

| ID | Fait | Conséquence |
|---|---|---|
| F96 | **Observé en moteur réel** (scénario `bord-a-bord` ; 22/10 à 19:48, 19:53 et 20:08, puis sur `main` à 20:11:23,82). `find_entities_filtered{area}` et `count_entities_filtered{area}` rendent une entité dont la boîte de collision TOUCHE la zone exactement : par chacun des 4 bords, par un coin (2 coins essayés), ou par une zone NULLE posée sur le bord. Un écart de 1/256 de tuile n'est pas rendu ; un chevauchement de 1/256 l'est. Ce sont des intervalles FERMÉS. Vu sur 3 entités : mur de pierre (± 0,29), mitrailleuse vanilla (± 0,7), tourelle laser 7 du mod (± 1,2). | Toute recherche par zone qui ne doit pas compter le simple contact doit refiltrer par chevauchement strict. Le moteur simulé, qui excluait le contact par choix (E47), est aligné (E53). `Levels.move_ground_items` ne refiltrait pas l'objet trouvé : corrigé le 22/10 (E53). Non examinés : les balayages par secteurs jointifs de `pvp.lua`, `sites.lua` et `war.lua`. |
| F97 | **Observé en moteur réel** (mêmes passages). `position` seule (sans rayon) rend l'entité quand le point est sur le bord ou au coin de sa boîte de collision (boîte fermée). `position` + `radius` compare la distance du CENTRE de l'entité : un rayon exactement égal à cette distance la rend, un rayon de 1/256 de moins non ; un cercle qui entre dans la boîte sans contenir le centre ne la rend pas. | Conforme à la doc 1.1.91 (« Looks for the center ») et au moteur simulé pour le rayon. Le moteur simulé ignore toujours `position` seule (aucun usage du mod) : non aligné. |
| F98 | **Observé en moteur réel** (mêmes passages). `bounding_box` rend les boîtes de collision en virgule fixe 1/256 : 0,29 donne 74/256, 0,7 donne 179/256, 1,2 donne 307/256. | Étend F92 aux boîtes. Troncature ou arrondi au plus proche : NON tranché (les trois valeurs donnent le même résultat dans les deux cas). Les zones de recherche d'un banc se bâtissent sur la boîte RENDUE, jamais sur celle du prototype. |
| F99 | **Observé en moteur réel** (`t2-defense`, création 0.4.1 et 0.4.2 ; 22/10, 19 h 54, 20 h 08 et 20 h 11). Une tourelle LAISSÉE par la migration (hors grille, ou sur la grille mais chevauchante) continue de fonctionner : son bras la nourrit, le laser reste sur le réseau et chargé, elle tire et tue. Le laser 25 de C, laissé en 6×6 sur sa position 2×2, couvre 6 tuiles de convoyeur et 2 bras (ceux de C3-M25 et de C5-M13 ; création 0.4.1) : le convoyeur passe dessous et porte toujours les munitions, et les deux bras couverts nourrissent encore leur tourelle (C3-M25 et C5-M13 à 10 munitions après le combat, 383 et 323 de dégâts infligés depuis la migration). En création 0.4.2, il couvre 6 tuiles de convoyeur et 1 bras (celui de C5-M13). Vu sur 13 tourelles laissées (création 0.4.1) et 5 (création 0.4.2). | Étend F88 aux tourelles et à une ligne de défense : la migration ne désarme pas une défense. Le défaut est visuel et d'usage (Q-T2-1). |
| F100 | **Observé en moteur réel** (`t2-defense`, création 0.4.1 ; tick FEED = 170). Confirme F79 et F89 pour des TOURELLES : 4 mitrailleuses reposées par script (`Levels.repair`, création 0.4.1 seulement : B1-M7, B3-M7, B5-M8 et B7-M8) sont retrouvées par leur bras électrique : `drop_target` vaut la nouvelle tourelle, qui reçoit 2 ou 3 munitions avant le tick 170 (B1 : 2 ; B3, B5, B7 : 3). Elles sont sur une ligne de plusieurs tourelles nourries par un convoyeur commun, cas absent de F79 et de F89. Les 4 autres tourelles reposées de B sont des lasers, sans bras ; en création 0.4.2, aucune mitrailleuse n'est reposée (11 « même taille »). | **Corrigé par le correcteur de la suite** : la première version disait « 8 mitrailleuses reposées » (faux : 4) et « élargit F79, qui ne reposait que sur un bras à combustible » (faux : F89 couvrait déjà les bras électriques). Le remplacement par script n'a pas à recâbler les bras d'une ligne de défense. |
| F101 | **Déduit, non observé directement** (`t2-defense`, mêmes passages). Des poteaux moyens posés par `create_entity` se raccordent seuls à leurs voisins à portée : 24 poteaux, aucun raccord ajouté par `connect_neighbour`, un seul réseau pour les 10 lasers et l'interface électrique. | Ce qui est prouvé : un seul réseau, 10 lasers chargés. Ce qui est déduit : le raccord automatique. La valeur que rend `connect_neighbour` sur des poteaux déjà raccordés n'a pas été lue. |
| F102 | **Lu dans le binaire 1.1.91, pas un essai en moteur réel** (chaînes de `factorio.exe`, lecture seule, aucun lancement ; sens DÉDUIT ; suite vram). Clés de `config.ini` voisines de `texture-compression-level` : `texture-streaming`, `streamed-atlas-physical-vram-size` et `compress-virtual-atlas` (valeurs par défaut absentes du binaire). Assertion « this->virtualAtlasPage->getFormat() == BitmapFormat::RGBA_8888 » (près de `src\Graphics\Atlas.cpp`). Message « Couldn't create %s bitmap … Probably not enough video memory », partagé par « virtual atlas » et « atlas ». Lignes « Created virtual atlas page %ux%u [%s] » (au singulier), « Atlas memory size: %.2fMB; %.2fMB (virtual) » et « Size of sprites outside of atlas: %.2fMB », absentes des 13 journaux archivés. | Base de la règle de l'atlas virtuel de `vram.py` (E55). NON prouvés : où vivent les pages de l'atlas virtuel et leur format en mémoire vidéo. Lecture la plus probable : la locale (« kept in RAM until needed by the GPU ») parle des sprites SOURCES hors atlas, et les pages sont le cache PHYSIQUE côté carte. |

### Faits vérifiés en moteur réel (lot V3-T2, emprise croissante de toutes les familles, 22/10, 17 h 21 à 19 h 05)
Numéros DÉFINITIFS, attribués à l'intégration du lot (22/10, vers 19 h 15). Les numéros provisoires du lot se suivent
sans trou après F82 et sont gardés : F83 à F89 de l'ingénieur, F90 à F95 du correcteur. Deux corrections du
correcteur sur les faits de l'ingénieur : F87 est RESTREINT à l'orientation nord, et F84, vu une fois puis perdu
(archive supprimée), est CONFIRMÉ (rejoué et archivé).

Sources : `fo-autotest.bat` lancé depuis PowerShell, code 0 et `done.txt` relu à chaque passage, sur le worktree
`wf_04ba1f63-d67-1` (ingénieur : `3e9a23e`, `f5f6a77`, `be0ee03` ; correcteur : `e84ca84`), puis sur `main` après la
fusion `681dd5c` (19 h 05). Archives : `<racine>\fo-logs\2026-10-22_V3T2\` (notes `NOTES_V3T2.md` : §3 et §8 de
l'ingénieur, §9 du correcteur) et `<racine>\fo-logs\2026-10-22_V3T2-integration\`. Expériences : E49 à E52.

| ID | Fait | Conséquence |
|---|---|---|
| F83 | **Observé en moteur réel** (`content-3-bilans-avant-correctif`, 17 h 33, avant le correctif). Un four neuf (`create_entity`, puis inventaires transférés) ignore l'écriture de `crafting_progress` : relue 0,000 au lieu de 0,506. Une fusion en cours a déjà pris son minerai : le four agrandi en pleine fusion perdait 1 minerai et sa progression (bilan de fer 205 → 204). | Corrigé : les ingrédients de la fabrication en cours sont rendus à la nouvelle machine, et la progression est notée puis reposée au premier tick où elle refabrique la même recette (`Levels.resume_progress`). Bilan de fer 205 constant, progression 0,506 → 0,522 à ACT + 2 (`final-content`). |
| F84 | **CONFIRMÉ en moteur réel.** Vu une première fois par l'ingénieur (archive `content-6`, supprimée pour libérer le disque ; assembleur à l'arrêt, eau 30 < 50 : le correctif avait alors rendu 1 baril et 50 d'eau en trop). Rejoué et archivé par le correcteur (`corr-final-content`, 18 h 59), puis sur `main` (19 h 05). Écrire `crafting_progress = 0,25` sur un assembleur à l'arrêt SANS aucun ingrédient rend `is_crafting()` vrai (false → true, progression relue 0,250), et la machine FINIT la fabrication : 1 engrenage au tick 3000 (`products_finished` = 1 au passage du correcteur), sans une seule plaque. | Fabrication gratuite : ne jamais écrire la progression d'une machine qui ne fabrique pas. Le mod ne la recopie plus hors fabrication (correction du défaut 10) ; le banc ne l'écrit plus sur une machine à l'arrêt. |
| F85 | **Observé en moteur réel, avec le seul poteau invisible du mod de test** (`t2-migration-essai1`, 17 h 43 : assembleurs de `fo-t2-libre` qui fabriquent ; `final-t2-migration`, 18 h 00, ligne de journal « lasers de la force fo-t2-libre au tick 90 : laser7 993200 J (reseau true), laser25 1570000 J (reseau true), laserA 993200 J (reseau true), laserB 993200 J (reseau true) »). Un bâtiment électrique est alimenté par le poteau d'une AUTRE force dont la zone le couvre : les lasers de la force `fo-t2-libre`, qui n'a aucun poteau, sont reliés et chargés (993 200 J) par le poteau invisible de `fo-t2` (copie de la sous-station au masque vide, F57) ; ses assembleurs ont fabriqué 3 engrenages. | Une force « sans énergie » doit être tenue hors de toute zone de poteau. Avec un poteau vanilla : non essayé. |
| F86 | **Observé en moteur réel** (`t2-migration-amelioration-hors-grille`, 17 h 54, avant le correctif). `create_entity{fast_replace = true}` d'un assembleur 4×4 à une position HORS grille (306,5 ; 286,5) recale la position en (307 ; 287), ne remplace PAS l'ancien (il reste, avec son contenu) et pose le nouveau par-dessus. L'appel rend pourtant une entité valide du bon nom (« done », 0 secours) : deux machines superposées pour un seul coût. **Inféré, non rejoué** : que le même défaut touchait déjà 0.4.2 pour les mitrailleuses laissées hors grille par la migration 0.4.1 (même chemin de code). | Corrigé : un bâtiment hors grille ne passe jamais par le remplacement rapide moteur (`Levels.off_grid`) ; il est remis sur la grille par script, place vérifiée avant le paiement. Les doublons hérités sont relevés au chargement (`Levels.find_stacked`), jamais retirés. |
| F87 | **Observé en moteur réel, pour l'orientation NORD seulement** (`final-content` ; restriction du correcteur, `corr-final-content`). Foreuse 3×3 → 4×4 orientée nord, au rang 1 (sud-est) : le point de dépôt reste sur la MÊME tuile (le même coffre sert). Assembleur 3×3 → 4×4 orienté nord : le raccord d'entrée vise la même tuile (604,5 ; 260,5) qu'en 3×3. Tel que l'ingénieur l'énonçait (sans condition d'orientation), le fait était trop général : tournée vers le sud ou l'ouest, la position préférée faisait changer le point de tuile (E51). Rotation du moteur vérifiée : dépôt = centre + vecteur tourné (foreuse 3×3 tournée vers l'est : (1,848 ; 0) ; foreuse 4×4 tournée vers le sud : (0,496 ; 2,348)). | Base de la règle des points servis (E51, ARCHITECTURE §7 bis). |
| F88 | **Observé en moteur réel** (`final-t2-migration`, 18 h 00, puis `corr-final-t2-migration` et `main`). Les bâtiments laissés hors grille par la migration (chevauchement toléré) fonctionnent : en 510 ticks, 4 engrenages par assembleur laissé et 7 plaques par four laissé ; les foreuses laissées sont « working » et déposent sur le convoyeur qu'elles chevauchent (les deux du bout est attendent : convoyeur sans issue plein) ; les 24 bras visent toujours leur machine ; les lasers sont reliés et chargés. Les sprites se superposent d'une demi-tuile. | Une migration ne casse rien ; le défaut est visuel et d'usage (question Q-T2-1). |
| F89 | **Observé en moteur réel** (`final-content`). F79 vaut aussi pour les bras ÉLECTRIQUES (`inserter`) et pour les assembleurs et les fours : après un remplacement par script, `drop_target` vaut la nouvelle machine (fo-lvl-assembler-7, fo-lvl-furnace-7) et le bras la nourrit (coffres 100 → 99 et 177 → 160). | Le remplacement par script n'a pas à recâbler les bras. Un bras par famille, en dépôt, joué. |
| F90 | **Observé en moteur réel** (`corr-2-content-debug`, 18 h 48 ; `temoin-be0ee03-points`, 18 h 51). Un bâtiment créé par script pendant que l'ancien existe encore, l'ancien étant détruit ensuite, n'est PAS raccordé aux tuyaux que l'ancien occupait : 12 assembleurs agrandis sur 12 privés d'eau. `update_connections()` du nouveau ou du tuyau : sans effet ; `teleport(position)` sur place de l'un ou de l'autre : raccord refait. | Corrigé : téléport sur place après tout remplacement par script d'une entité à boîte à fluide (puis `update_connections()` pour une foreuse). Le défaut touchait aussi toute migration 0.4.3 d'un assembleur à fluide reposé ; en 0.4.2, seule la mitrailleuse (sans boîte à fluide) changeait de taille. Non joués : raccords du fluide de minage d'une foreuse, boîte à fluide de SORTIE. |
| F91 | **Observé en moteur réel** (mêmes passages). Un assembleur créé SANS recette n'est pas orientable : `create_entity` ignore `direction`. Les assembleurs à fluide tournés vers l'est, le sud ou l'ouest revenaient au nord après un agrandissement par script (9 sur 9), et perdaient leur tuyau. | Corrigé : recette donnée à la création (`recipe =` de `create_entity`) ; `Levels.transfer` la repose ensuite, sans effet. |
| F92 | **Observé en moteur réel** (`corr-2-content-debug` ; relu sur `main` à 19 h 05 : dépôt en 754,34765625). Le moteur rend les positions en virgule fixe (1/256 de tuile) : dépôt d'une foreuse 4×4 tournée vers l'est relu (2,34765625 ; −0,49609375) au lieu de (2,35 ; −0,5). | Toute égalité exacte avec une coordonnée de prototype échoue : le premier inverse de la règle des points a raté les 3 passages 4×4 → 5×5 non orientés au nord. Tolérance retenue : 1/64 (`Points.TOL`, `shared/levels/points.lua`). |
| F93 | **Observé en moteur réel** (`corr-final-content` ; `main`). Un assembleur en « sortie pleine » (état 22, 100 engrenages) EST en fabrication : `is_crafting()` vrai, `crafting_progress` = 1,000 (fabrication finie, produit non sorti). | Le transfert le traite comme une fabrication en cours : bilan de fer (plaques + 2 × engrenages) 220 constant à travers l'agrandissement 6 → 7. L'« arrêt à 4 engrenages » observé une fois par l'ingénieur (archive `content-4-debug` supprimée) n'est pas reproduit. |
| F94 | **Observé en moteur réel** (`corr-final-content` ; `main`). Le remplacement rapide MOTEUR à taille égale garde la fabrication en cours et sa progression : four 7 → 8 en pleine fusion, 0,896 → 0,896, bilan de fer 200 constant ; assembleur à moteurs 7 → 8, 0,254 → 0,254, bilan d'acier 101 constant ; four 6 → 7 (script, tick ACT) puis 7 → 8 (moteur, tick ACT + 1) : bilan 200 constant. | À taille égale, rien à faire. La progression notée par F83 suit la machine si le moteur la remplace avant qu'elle ait repris. |
| F95 | **Observé en moteur réel** (`corr-1-content`, 18 h 46 ; `temoin-be0ee03-points`). La barre rouge d'un coffre limite AUSSI `LuaInventory.insert` par script : barre posée à 10 cases par le banc, coût du niveau 2 refusé (« no-resources »). Un coffre sans barre rend `get_bar()` = nombre de cases + 1 (97 pour 96 cases). | La barre n'est recopiée que si elle limitait (`get_bar()` ≤ nombre de cases) : barre 5 gardée sur le centre 3 → 4 (80 → 96 cases). Recopier `get_bar()` tel quel aurait borné le nouveau coffre à la taille de l'ancien. |

Observation sans numéro (ingénieur, archive `content-4-debug` supprimée) : un assembleur 6 à engrenages sans bras de sortie
s'est arrêté en « full_output » à 4 engrenages. Non reproduite ; voir F93.

### Faits vérifiés (suites de V3-T, 22/10, 15 h 23 à 17 h 06)
Numéros DÉFINITIFS, attribués à l'intégration des trois suites (22/10, vers 17 h 20). Les suites avaient donné des
numéros provisoires qui se chevauchaient. Correspondance :
- suite H-T3 : F76, F77, F78 et F79 gardent leur numéro ;
- suite d4m : son F76 devient F80, son F77 devient F81 ;
- suite des bancs hors jeu : ses F76+ et F77+ deviennent ensemble F82.

Sources :
- F76 à F79 : `fo-autotest.bat` en double source (`FO_CREATE_SRC`, scénario greffé `ht3-migration`, E46), journaux
  dans `<racine>\fo-logs\2026-10-22_V3T-suites\ht3\` ;
- F80 et F81 : relecture des 13 journaux archivés de D4m et de P1, sans nouvelle session (E48) ;
- F82 : `tests/datastage/harness.lua` sur vanilla 1.1.91 et la doc 1.1.91 (E47). Ce n'est pas un essai en moteur
  réel.

| ID | Fait | Conséquence |
|---|---|---|
| F76 | **Observé en moteur réel** (passage c du constructeur, `113ddba`, 15 h 31 ; passages a à c du correcteur, `d6ba888`, 15 h 59). Au chargement d'une sauvegarde, une entité dont le prototype a changé de taille garde sa position enregistrée, sans recalage sur la grille ni destruction, et prend la nouvelle boîte. Relevés au passage c, avant la migration : mitrailleuse 7 en (310 ; 250) avec la boîte 308,80..311,20 ; mitrailleuse 19 en (330 ; 250) avec 327,80..332,20. Relevé après la migration : rempart7, laissée en place en (330 ; 292), avec 328,80..331,20. | Une sauvegarde 0.4.1 se charge sans perte. Entre le chargement et la migration, un bâtiment agrandi peut chevaucher ses voisins. Un bâtiment laissé faute de place GARDE la nouvelle taille, hors grille (« chevauchement toléré »). |
| F77 | **Observé en moteur réel** (passage b, deux fois : `113ddba` à 15 h 31, `d6ba888` à 15 h 59). `on_configuration_changed` est appelé au chargement quand les données de prototypes EXISTANTS ont changé, même sans montée de version ni prototype ajouté : `mod_changes` VIDE, `mod_startup_settings_changed false`, `migration_applied false`. « Checksum of factorio-overhaul » vaut 1706978588 à la création et 2895350727 au benchmark ; « Prototype list checksum » vaut 2254679425 des deux côtés. Témoins : un commentaire ajouté à `script/levels/levels.lua` (passage d) ne change pas la somme et n'appelle pas l'événement ; une copie identique (passage e) non plus. La doc 1.1.91 ne cite pas ce cas. **Déduit, non prouvé** : que ce soient les DONNÉES de prototypes qui déclenchent l'appel. Aucun essai n'a modifié le comportement du code de control sans changer les données. | Sans montée de version, c'est `Levels.repair` qui migre. La prémisse de la branche (2) de H-T3 (« le filet migre ») est donc fausse. On ne connaît aucun cas réel où le filet `on_nth_tick(30)` serait le seul recours. |
| F78 | **Observé en moteur réel** (`113ddba`, 15 h 31 ; précisé par le correcteur à 15 h 59). `LuaEntity.bounding_box` d'un mur relié à ses voisins déborde de la boîte de collision du prototype (± 0,29) du côté de ses voisins : 308,2109..308,9883 pour un mur en 308,5. Dans une ligne de murs horizontale, ce débord ne gagne pas la rangée voisine en hauteur : rempart7 (3×3 hors grille, boîte 290,80..293,20 en y) ne chevauche pas les murs de la rangée 290. | `Levels.room` lit `bounding_box` : il compte ces débords comme gêne dans le sens de la ligne. |
| F79 | **Observé en moteur réel** (correcteur, `d6ba888`, 15 h 59, dans les trois voies ; premier essai sur `a3bf9e4` à 15 h 56). Un bras dont la cible de dépôt est détruite puis remplacée par script (`Levels.resize_replace` : `destroy`, puis `create_entity{raise_built = true}`) vise la nouvelle entité sans aide du mod. Au tick 90, `drop_target` vaut fo-lvl-gun-7 n° 62 dans les trois voies, y compris celle du filet, où le remplacement a lieu au tick 30. Le bras continue de la nourrir : 3 puis 9 chargeurs du tick 90 au tick 600. Un seul cas joué (defense7, bras à combustible). | Le remplacement par script n'a pas à recâbler les bras. Non joués : inserteurs électriques, ligne qui alimente plusieurs tourelles. |
| F80 | **Observé dans des journaux archivés** (suite d4m, relecture de `fo-logs\2026-10-22_D4m_1` à `_5` et des 8 journaux P1 ; aucune nouvelle session). En 1.1.91, avec vanilla et le mod 0.4.1 ou antérieur, une session avec images crée 15 atlas « Created atlas bitmap » en haute qualité et 14 en qualité normale, avec la mémoire vidéo sur « all » comme sur « low ». L'écart est un second atlas « [none] » (sprites principaux) : en haute qualité, le premier mesure 16384×16364 ou 16384×16380, pour un bord maximal annoncé de 16384. Les 13 autres atlas figurent une fois PAR CATÉGORIE dans chacun des 13 journaux, avec les mêmes drapeaux, sauf un : l'atlas [low-object] porte linear-minification en haute qualité et au plancher, pas en normal/all. Pixels « [none] » : 475,8 Mpx en haute qualité, 141,0 en normale, 2,7 au plancher. **Déduit, non prouvé** : la cause (premier atlas plein, `hr_version`), cohérente avec les journaux et la doc, mais non mesurée sprite par sprite. | Un banc qui compte les atlas doit lire la qualité que déclare le journal. C'était la cause de l'échec d4m à 4/5 (E44), corrigé par E48. |
| F81 | **Observé dans un journal archivé** (`fo-logs\2026-10-22_D4m_5-plancher-mesure\visual.log`). Avec « Video memory usage: low » (« Tex.Stream.: 1 »), l'atlas « [none] » tombe à 2048×1316. Le journal ajoute alors une ligne du moteur « Created virtual atlas pages 4096x4096x9 », puis « Generated mipmaps for virtual atlas of size 16384x12288 ». Ces lignes sont absentes des 12 autres journaux. L'atlas virtuel, d'environ 151 Mpx, n'est pas une ligne « Created atlas bitmap ». Précision (suite vram du lot R1, 22/10, relue dans le même journal, non nouvelle en moteur) : la ligne de mipmaps annonce un atlas virtuel de 16384x12288 (201,3 Mpx, soit 12 surfaces de page de 4096²), alors que 9 pages seulement sont créées (151,0 Mpx) ; le nombre de niveaux de mipmaps n'est pas écrit. | Jusqu'au 22/10, `vram.py` le relevait et le signalait (« atlas VIRTUEL … NON compte ») sans le compter. Depuis la suite vram (lot R1, 22/10, commits `dac93fd` et `75863a5`), `vram.py` COMPTE les pages dans l'estimation : bas = pages × octets/px bas sous la DXT du journal ; haut = (pages + 1/3 de la plus grande surface, pages ou atlas virtuel annoncé) × octets/px haut. Résidence et compression sont des hypothèses (F102). Plancher : 0,28 à 0,53 Go, au lieu de 0,20 à 0,31 Go. La variante non compressée (0,81 Go) dépasse le pic dédié + partagé (0,52 Go) : exclue si les pages sont allouées en entier (E55). |
| F82 | **Relevé de l'étape data, pas un essai en moteur réel** (suite des bancs hors jeu, `harness.lua --verbose` sur vanilla 1.1.91, 22/10), complété par la doc 1.1.91. 18 entités vanilla portent des raccords de tuyau ou un point de dépôt, soit 51 points : assembling-machine-2 et 3, chemical-plant, oil-refinery, boiler, heat-exchanger, flamethrower-turret, steam-engine, steam-turbine, infinity-pipe, burner-mining-drill, electric-mining-drill, pumpjack, offshore-pump, pipe, pipe-to-ground, pump, storage-tank. Toutes ont leurs raccords hors de la boîte de collision et sur un centre de tuile, et leur dépôt hors de la boîte et des tuiles de la foreuse. Seule exception : le chevalet de pompage dépose en {0, 0}, dans sa boîte. Il ne dépose qu'un fluide, et la doc de `vector_to_place_result` dit : « a vector of {0,0} disables the yellow arrow alt-mode indicator ». Sans cette exception, la règle se déclenche sur `mining-drill/pumpjack` (essai du 22/10). Aucune entité vanilla n'utilise `pipe_connections[].positions`. | Base de la règle des points de jeu du harness (E47) ; une foreuse à `output_fluid_box` n'est pas contrôlée pour son dépôt. Ce que fait le moteur réel d'un raccord mal placé n'est PAS observé : c'est déduit de la géométrie. |

Observations sans numéro (moteur réel, suite H-T3) :
- pendant `on_init`, sans aucun tick écoulé, `LuaTransportLine.insert_at_back` n'accepte qu'un objet par voie d'un
  convoyeur. Sur un convoyeur seul, 8 essais donnent 2 chargeurs ; sur 4 convoyeurs, 8 chargeurs (essai sur
  `a3bf9e4` à 15 h 56, d'où le commit `d6ba888`) ;
- au tick 0 du passage c, le `on_tick` du mod de test s'exécute avant le filet `on_nth_tick(30)` de
  factorio-overhaul : ses lignes précèdent celle du filet dans le journal. Noté, non exploité.

### Faits vérifiés en moteur réel (lot V3-T, emprise croissante, 22/10, 13 h 56 à 14 h 51)
Banc `content` avec le greffon `checks/levels_taille.lua` (mitrailleuse, Factorio 1.1.91 sans affichage). Passages :
`content-1` et `content-2` (13 h 56, arbre de travail avant le commit) puis `content-3-captures` (13 h 57,
lancé après le commit `de6e628` de 13 h 57 min 17 s), 234 OK chacun, deux passages intermédiaires non
archivés (14 h 45 et 14 h 46, 238 OK), `content-final` (14 h 46, commit `3b06952`, 238 OK) et le banc
d'intégration sur `main` (14 h 51, 238 OK). Archives : `<racine>\fo-logs\2026-10-22_V3T\` et
`<racine>\fo-logs\2026-10-22_V3T-integration_content\`. Numéros attribués à l'intégration (22/10, 14 h 55).

| ID | Fait | Conséquence |
|---|---|---|
| F70 | `create_entity` SANS `fast_replace` pose une tourelle 3×3 par-dessus l'ancienne 2×2 encore présente : le moteur ne vérifie pas la place ; `raise_built` passe ; l'ancienne est détruite ensuite par le script (`destroy{raise_destroy = false}`). Preuve : « place libre : mitrailleuse 6 -> 7 agrandie aussitot », munitions transférées (10 chargeurs), PV en proportion (380 / 760), `resized 1, fallback 0, spilled 0` (banc d'intégration, 14 h 51). | Chemin de l'agrandissement sur place (Q24). Le moteur ne refusant rien, la place doit être vérifiée par le script AVANT (`Levels.room`) : sinon les bâtiments se chevauchent. |
| F71 | `create_entity{move_stuck_players = true}` écarte un personnage pris dans la nouvelle boîte : (549,2 ; 248,6) → (548,60 ; 248,00), juste hors de la boîte. | Un personnage ne bloque jamais un agrandissement ; le script ne le compte pas parmi les gênes. |
| F72 | Une boîte de collision et de sélection agrandie (3×3 à 6×6, marge de 0,3 tuile au style vanilla) est acceptée par l'étape data. Le remplacement rapide moteur fonctionne entre deux niveaux de MÊME taille avec un groupe commun à toutes les tailles : chaîne 6 → 30 de la mitrailleuse, 24 améliorations, 4 agrandissements par script, 20 remplacements rapides, 0 secours ; 30 prototypes contrôlés (« emprise 2x2 -> 6x6 par ere, collision au style vanilla, portee + (cote - 2) / 2, meme groupe »). | Un seul `fast_replaceable_group` par famille suffit ; F39 reste le chemin à taille égale. |
| F73 | `rendering.get_time_to_live(id)`, lu dans le tick du dessin, rend la durée entière (300). Les rectangles à durée limitée disparaissent seuls : 0 rectangle restant au tick 3000, 500 ticks après le dernier dessin (tick 2500). `get_forces` rend la seule force donnée au dessin. | Le contour de refus ne laisse rien dans `global` et ne demande aucun nettoyage. |
| F74 | `create_entity` (sans `fast_replace`, avec `raise_built` et `move_stuck_players`) d'une mitrailleuse 3×3 sur un fantôme de mur qu'elle heurte : le moteur RETIRE ce fantôme de lui-même. Le fantôme était valide juste avant, il ne l'est plus après, et le filet du script n'en a retiré aucun (« retire par le moteur (script : 0) », compteur final « fantomes retires 0 »). Observé à 14 h 46 (passage intermédiaire, puis `content-final`) et au banc d'intégration (14 h 51). | Défaut 5 de la relecture de V3-T réfuté en moteur réel (il n'existait que dans le moteur simulé). Le filet `remove_ghosts` est gardé ; il n'a jamais servi en moteur réel. |
| F75 | `find_non_colliding_position("item-on-ground", position de l'objet, 5, 0.25)`, appelé sous une mitrailleuse 3×3 neuve, rend une position hors de sa boîte : (550,00 ; 248,00) pour une boîte qui commence à y = 248,30. `LuaControl.teleport` sur un objet au sol (`item-entity`) réussit et l'objet reste valide (« deplaces 1 » ; pile de 3 plaques de fer non relue par le banc). | Un objet au sol recouvert par l'agrandissement est déposé juste à côté, à portée de ramassage. |

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
| F69 | Outillage : depuis Git Bash, un `.bat` dont le chemin contient des espaces, appelé avec un argument entre guillemets (par exemple une source de mod), est mal découpé par `cmd /c` (guillemets extrêmes retirés) : « 'H:\Factorio.v1.1.91' n'est pas reconnu… », code 1 sans rien lancer. `fo-autotest.bat` sans argument entre guillemets n'est pas touché. | Lancer `fo-captures.bat` avec une source depuis PowerShell (`& "<racine>\fo-captures.bat" d4-geant "<source>" hd`). |
| F68 | Étape data 1.1.91 : `base/data-updates.lua` génère un baril, une recette « fill-<fluide>-barrel » et une recette « empty-<fluide>-barrel » pour CHAQUE fluide sans `auto_barrel = false`, mods compris, et les ajoute TOUTES aux effets de `fluid-handling` (constante `technology_name` du fichier). Avec le mod : `fill-fo-methane-barrel` et `empty-fo-methane-barrel` y figurent (relu avec `tests/datastage/harness.lua --dump-final technology/fluid-handling`, 22/10). | Une règle qui range une technologie par ses recettes doit ignorer ces recettes générées : sinon fluid-handling suit l'époque du fluide le plus tardif (V2c, QX9 : époque 8 au lieu de 4, 50 unités au lieu de 2). |
| F67 | Recettes vanilla 1.1.91 : le moteur (`engine-unit`) est de catégorie `advanced-crafting`, le plastique et le soufre de catégorie `chemistry`. Ils ne se fabriquent PAS à la main, alors que les ouvriers des factions ne fabriquent qu'en `crafting` (vérifié dans `tests/fixtures/recipes.lua` et contrôlé par `org_test.lua`). | **Cause précise de H-E1** : le pack chimique exige un assembleur, une usine chimique ET du pétrole. Les équipes IA stagnaient donc après la recherche 3. Correction prévue aux lots IA1 (production adaptative, modules d'usine). |
| F66 | Au chargement d'une session avec images, le journal liste les atlas de sprites créés (« Created atlas bitmap L×H [drapeaux] »), avant toute partie. Toutes les images sont donc chargées UNE fois, indépendamment du nombre d'entités. Avec le jeu actuel (vanilla + mod, haute qualité, « DXT: high-quality »), on compte ≈ 1,07 milliard de pixels d'atlas, soit environ 1,1 Go estimés compressés et 4,25 Go sans compression ; le journal annonce aussi le budget de mémoire vidéo (« Budget: 15570MB »). Source : `fo-logs\2026-10-21_P1_vitrine-exemple-final\visual.log`. | Le coût d'une usine géante est du temps de dessin, pas de la mémoire vidéo. La mémoire se budgète par famille de sprites (D4). Une mesure directe est à faire (lot D4m). |
| F65 | `laser-turret` : `energy_source.buffer_capacity` = 801 kJ et `ammo_type.energy_consumption` = 800 kJ par tir (relu avec `--dump-final`) : le tampon doit contenir un tir. `nuclear-fuel` s'empile par 1, alors que `uranium-235` et `uranium-238` s'empilent par 100. | Lot V2 : l'énergie et le tampon du laser croissent ensemble ; un matériau d'époque s'empile par 50 au moins (`L.MIN_MATERIAL_STACK`). |
| F64 | `draw_as_light` est une carte de lumière en espace écran : elle révèle la couleur de jour de TOUT ce qu'elle recouvre, bâtiments compris, et pas seulement le sol. Un trou dans la couche (par exemple la forme d'un objet qui bloquait la lumière dans le rendu) se voit donc comme une zone sombre sur le bâtiment (E31). | Une pièce posée sur un bâtiment doit avoir sa passe light rendue avec un volume de remplacement de ce bâtiment ; la flaque au sol reste hors de sa silhouette (lot V0b). |

### Expériences menées
**E117 · VALIDÉ en moteur réel · Banc `d4-geant` recalé sur les emprises de 0.4.3 (lot D4m-géant, 24/10)** : usine
288 × 392 tuiles (5 343 bâtiments, 13 824 tapis, 9 091 bras ; seuils d'origine gardés), champ z0,3 en 1920 × 1080 :
1 019 bâtiments dont 619 machines, 63,8 % couverts (91 % de la couverture de 0.4.1), 7/7 familles ; galerie des têtes
(960 mitrailleuses, 64 images relues par âge) ; 18 OK au banc et dans 5 sessions (haute, normale, plancher), 60 UPS ;
mémoire dédiée à 7 âges à 64 directions : haute 1,64 à 1,65 Go par vue (pic 1,81), normale 0,65, plancher 0,42.
Limites : usine moins dense dans le champ qu'en 0.4.1 (1 019 bâtiments dessinés contre 2 588 ; machines plus grandes) ;
images par seconde non mesurées.

**E109 à E111 · Lot A3-jeu (24/10, 0 h 25 à 4 h ; runs `wf_93b960d8-a9c` puis `wf_bcc3f79d-bc7`)** : détail dans
`fo-logs\2026-10-24_A3-jeu\NOTES.md` §4 à §6 et §13.
- **E109 · VALIDÉ en moteur réel pour les âges 2 à 8 · 64 directions en jeu, intégration progressive** : un âge passe à
  64 dès que ses 64 têtes sont produites et contrôlées, sinon il reste à 4 ; `gun-rose` à 20 directions par niveau
  (dont d06, d26, d38, d58) : 13 OK ; captures comparées aux feuilles : 252 OK, 0 FAUX. Verdict du DC : non rendu.
- **E110 · VALIDÉ hors moteur, 4 directions et 11 directions écartées de l'âge 2 en moteur · Éclat de tir sur toutes les
  directions** : ajustement par âge sur toutes les directions disponibles, refus à 0,5 tuile ; âge 2 : 11 directions
  écartées, tirées en jeu et regardées (D-12). Limite : la forme diagonale de la règle F126 n'est pas mesurée hors de
  N, E, S, O.
- **E111 · MESURÉ · Mémoire vidéo à 64 directions** (F147, F148) : 10 passages `d4-geant`, haute 1,0875 → 1,1323 Gpx
  avec 7 âges, extrapolé à 15 âges 1,260 Gpx (1,30 à 1,47 Go) ; normale 0,3393 → 0,3509 Gpx (0,46 à 0,51 Go) ;
  chargement +0,25 s ; pic de 1,80 Go d'un passage non expliqué. Taille des PNG : 52 Mo à 7 âges, environ 160 Mo aux 15.

**E113 · VALIDÉ en moteur réel · Le tir de la mitrailleuse est joué en jeu, avec le son de son ère (lot S0-suite, 24/10,
0 h 25 à 2 h 30)** :
- Protocole : scénario greffé `s0-tir` (6 sites dans un ordre mêlé : ère III, vanilla, V, I, IV, II ; 6 cartouches
  isolées par site ; le joueur, écouteur, est téléporté sur chaque site) ; session `fo-captures` avec `FO_AUDIO=1`
  (pilote `disk`, garde de crête) ; analyse de `audio-disk.raw` par `tools/sound/tirs_joues.py` (filtre adapté contre
  les 20 tirs du mod et les 4 tirs vanilla ; droite tick → temps ajustée ; volumes en différentiel contre une session de
  référence).
- Résultats : lot 36/36 (deux sessions), vérificateur 36/36, intégration 35/36 puis 36/36 ; ère juste à chaque tir
  reconnu ; 0 détection sans tir ; volumes par ère retrouvés à 0,2 dB près ; mutants détectés (ères III et V échangées :
  12 tirs « ERE FAUSSE » ; journal permuté ; sortie de `gun-rose` : 0 détection). Garde : 0 session audio Windows du
  jeu à chaque passage.
- Limites : banc instable à la marge (corrélations d'un site parfois à 0,54 à 0,57, seuil 0,50) ; biais de volume par
  site à volumes égaux (−0,59 à +0,23 dB) non expliqué ; tirage uniforme des variations et limite de sons simultanés
  non mesurés ; écoute du DC : en attente (Q-S0-1).

**E105 à E108 · Lot A3-préparation (23/10, 21 h 25 au 24/10, 0 h ; run `wf_e1ae9f59-b47`)** : détail dans
`fo-logs\2026-10-24_A3\NOTES.md` §2 à §8 et §14.
- **E105 · VALIDÉ hors moteur · D-7, échantillons par passe** : identité octet à octet des passes principale et lueur
  (8 poses, 32 fichiers ; rejouée par le vérificateur avec ses propres sha256) ; ombre à 32 : grain sans biais (somme
  d'alpha 0,9998 à 1,0004 de celle à 128) ; gain 42,8 % dos à dos (ABBA, 3 têtes). L'ombre à 32 EN MOTEUR (DXT) reste
  à regarder sur les captures d'A3-jeu.
- **E106 · VALIDÉ hors moteur · Masques rapides et trous enfermés des 64 directions** (F141, F143) : 56/56 verdicts de
  trou identiques à la production ; 72 poses acceptées, aucune comblée.
- **E107 · MESURÉ · Bouchon arrière** (F142) : secteurs par âge, 9 formes, rampes 60, 80 et 90 % ; rampe 80 % retenue ;
  regardé en production à l'âge 5 et en essai rapide aux âges 4, 6, 7 ; verdict du DC non rendu.
- **E108 · VALIDÉ · Pilote de production** : âge 5 complet (60 têtes en 1 456 s, 0 erreur), 8 directions de l'âge 15
  (585 s), reprise (rien de refait ; une passe supprimée : seule cette tête refaite, PNG identiques), STOP avant et
  pendant (code 2) ; planche des 64 directions et animation de l'âge 5 regardées : rotation continue. Durée de la
  production complète : 8 à 10,5 h (vérificateur ; la borne de 6,5 h de `--dry-run` est trop optimiste, m-3).
  Estimation pour A3-jeu : +331 Mpx hr (173 si le moteur rogne le transparent, non prouvé), mémoire vidéo haute 1,44 à
  1,64 Go, normale 0,51 à 0,55 Go (sans passage D4m).

**E69 · VALIDÉ en moteur réel · Une session de test avec le son charge nos fichiers son, sans aucune sortie audio (lot
S0, 23/10, 21 h 30 à 22 h 45 ; constructeur, vérificateur, correcteur, run `wf_e1ae9f59-b47`)** :
- Protocole : `gun-rose` sur la source du lot et sur une copie « mutante » sans `tir-ere3-2.ogg` ; sessions sans
  images (`--create`, `--benchmark`) et avec images (`--benchmark-graphics`), son coupé ou actif ; relevé indépendant
  de la sortie du PC (WASAPI, outil du vérificateur) pendant chaque session avec images ; après la correction, pilote
  SDL `disk` et garde de crête.
- Résultats : sans images, aucun son chargé (F150) ; avec images et son actif, tous les sons chargés au démarrage, le
  mutant bloque les mods au menu (F151) ; les volumes à 0 ne coupent pas la sortie (F152, défaut bloquant de la
  vérification) ; pilote `disk` : « Driver:disk », « Loading sounds... », 0 session audio Windows du jeu, relevé
  indépendant 0,000000 sur 41 550 relevés, mutant toujours refusé (code 7 en 3,3 s) (F153). Sur `main` 0.4.7 :
  `fo-captures gun-rose` avec `FO_AUDIO=1`, code 0, garde 0 session en 2 416 relevés.
- Sons du lot : 20 OGG (5 ères × 4 variations dérivées des tirs vanilla), volume jamais au-dessus de la vanilla
  (écart maximal : tirs −0,32 dB, rafales −0,10 dB), plus grave à chaque ère (centroïde 646 Hz vanilla, puis 552, 478,
  353, 304, 178 Hz) ; octets reproductibles (F154).
- Limites : le tir n'est pas prouvé JOUÉ en jeu (aucun tir reconnu dans la sortie `disk` : l'auditeur n'est pas aux
  sites de tir) ; le garde n'a jamais tué un vrai Factorio en train de jouer du son (prouvé sur un témoin Python à
  −70 dBFS, tué en 0,62 s) ; écoute du DC : en attente (Q-S0-1).

**E68 · VALIDÉ en moteur réel · Où le moteur pose l'éclat de tir, et la bouche de la mitrailleuse par âge (lot A2,
23/10, 19 h 30 à 21 h 00 ; constructeur puis correcteur, run `wf_0143e61e-944`)** :
- Protocole : (1) sur les sprites, bouche = milieu des bouts des deux canons extrêmes, par pose (rangées de lignes dont
  le pixel opaque le plus avancé est à 24 px hr du plus avancé ; vanilla, un canon : 4 px) ; (2) en moteur réel,
  scénario `gun-rose` : 60 tourelles (un niveau impair par âge, niveaux 1 à 29, × N, E, S, O), chacune face à un ver
  géant ennemi aligné sur son centre réel à 11 tuiles, cessez-le-feu de l'ennemi, ver recréé s'il meurt ; position de
  l'entité `explosion-gunshot` relevée au tick du tir ; (3) marge vanilla au-delà du bout du canon : 0,339 tuile (N, E,
  O ; S exclu : le point le plus bas de la tête vanilla est la couronne dentée) ; (4) ajustement par âge de
  `projectile_center` et `projectile_creation_distance` sur les 4 directions, refus au-delà de 0,5 tuile ; (5) captures
  zoom 2 en tir à deux instants, regardées.
- Résultat : règle F126 (K = 0,7071 ; vanilla : 0,702 et 0,705 en N et S ; niveau 29 : 0,706 et 0,707). Contrôle final
  en moteur : **60/60 à 1/32 de tuile, écart max 0,0089** (worktree corrigé, `done.txt` 20:41:05,23 ; `main` 0.4.6,
  20:54:32,19). Premier passage du correcteur avec la règle simple : 40/60 (effet d'une cible proche en E et O :
  distance × centre.y / portée, 0,168 tuile au niveau 29 à 11 tuiles) ; le scénario n'a pas été affaibli (tolérance
  1/32). Écart prévu éclat-bouche par âge : max 0,076 (âge 7) à 0,167 (âge 9), **âge 2 : 0,404** (en S, l'éclat est à
  peu près AU bout des canons) ; vanilla par la même règle : 0,55 en S (couronne), 0,11 ailleurs. Défaut du
  constructeur corrigé : à l'âge 12, la médiane des lignes tombait dans un seul canon, éclat 1,25 tuile trop bas en S ;
  après correction, environ 0,4 tuile au-delà des bouts, entre les canons.
- Captures regardées (âges 2, 12, 13, 15 et vanilla ; `fo-logs\2026-10-24_A2\correction\planche-tir-niv*.png`) :
  éclat au bout des canons, entre eux. Rejouées sur `main` 0.4.6 (`2026-10-23_integration-0.4.6\captures-gun-rose\`).
- Limites : hauteur visible de 1 tuile supposée (doc et vanilla) ; position au pixel non mesurée (à l'œil ± 0,2 tuile) ;
  âges 3 à 11 et 14 contrôlés par la règle seule (60/60 en moteur) et les planches de sprites, pas photographiés en tir.

**E76 · VALIDÉ en moteur réel (sauvegarde de banc quasi vide) · Migration d'une vraie sauvegarde 0.4.4 vers la
garantie des monnaies (lot M0, 23/10, 16 h 06 à 17 h 45 ; double source)** :
- Protocole : scénario greffé `m0-migration` (700 ticks), carte créée par `fo-logs\2026-10-23_suite\M0\src-0.4.4`
  (= `git archive 93e3d89`, version 0.4.4, **à GARDER**) avec un coffre du joueur, puis rechargée par la source M0 ;
  contrôles : voie `on_configuration_changed`, gisements DÉJÀ connus comptés, site posé seulement pour ce qui manque,
  entités du joueur intactes.
- Résultat : « [FO-M0-MIGRATION] BILAN : 9 OK, 0 ECHEC(S) » (constructeur 16:06:53 puis 16:14:03 ; vérificateur
  16:27:35,97 ; correcteur 16:45:50,13 ; sur `main` après la fusion, `done.txt` 17:45:43,44). Version 0.4.4 → 0.4.5,
  configuration au tick 0 ; cristal (9 unités) et méthane (8 puits) déjà présents dans la zone générée : rien posé ;
  tungstène posé en (94, −228), à 246,6 tuiles, essai 4 (« 1:sol,2:batiment,3:sol » : le coffre posé à la création sur
  le candidat 2 est évité), en 105,6 à 113,2 ms (112,5 ms au passage du vérificateur). Même résultat quand la source M0
  reste en version 0.4.4 (F130).
- NON PROUVÉ : une sauvegarde avec une base, la guerre lancée (forces `fo-*`) et une zone explorée au-delà du départ
  (mineur m-6 : « entités du joueur 1 », le coffre seul) ; les sauvegardes du DC (ni touchées ni testées).

**E75 · VALIDÉ hors jeu (étape data réelle) · Les ressources du monde générées depuis les données, sortie identique
(lot M0, 23/10)** :
- Protocole : `prototypes/world.lua` ne code plus le tungstène, le cristal et le méthane à la main : une boucle sur
  `W.resource_order` appelle `ore_prototypes` ou `fluid_prototypes` selon `kind`. Vidage trié (`pp` du harness) des
  3 236 prototypes de `data.raw` (mod compris), 0.4.4 (`src-0.4.4`) contre M0 (outils `dumpall.lua` et `protodiff.py`,
  dans le dossier temporaire de la session du lot, NON versionnés).
- Résultat : 6 prototypes diffèrent (`optimized-decorative/brown-asterisk`, `brown-asterisk-mini`, `green-asterisk`,
  `green-asterisk-mini`, `red-asterisk`, `technology/fluid-handling`), exactement les 6 qui diffèrent aussi entre DEUX
  passages de 0.4.4 (ordre de `pairs` dans le Lua vanilla rejoué par le harness) ; les 829 prototypes `fo-*`, couches
  de bruit, expressions et contrôles sont identiques à l'octet. Vérificateur : `harness --dump-final` en 0.4.4 puis
  en M0, identique pour les 13 prototypes concernés (3 ressources, `fluid/fo-methane`, 3 contrôles d'autoplacement,
  recettes et objets) ; vidage complet NON refait par lui.
- Portée : seules les 3 ressources EN JEU passent par ce générateur. `X.resources` et `X.tiles` : reportés aux lots X
  (décision de l'orchestrateur, ci-dessus ; 34 prototypes sur 35 absents).

**E74 · VALIDÉ en moteur réel · La garantie des monnaies sur 6 cartes et 4 situations, puis l'échec et la reprise
(lot M0, 23/10, 16 h 09 à 16 h 46 ; correction M-1 comprise)** :
- Protocole : scénario greffé `monde` (700 ticks, contrôle final au tick 660) : nauvis (graine 20261020, garantie à
  `on_init`) et 5 graines (1, 42, 123456, 987654321, 3141592653) sur des surfaces créées par le scénario (réglages de
  nauvis, autre graine) : A surfaces neuves ; B surfaces explorées sur 23 chunks (gisements NATURELS relevés, puis
  garantie comme dans une sauvegarde) ; C autoplacement des 3 ressources à 0 ; D coffre du joueur sur le candidat 1 et
  eau sous le candidat 2 ; F filet (ressource « oubliée » au tick 300).
- Résultats (« [FO-MONDE] BILAN : 89 OK, 0 ECHEC(S) », 16:09:25 puis 16:13:17 ; 16:27:07,21 au vérificateur ;
  16:45:32,64 au correcteur ; 17:45:34,86 sur `main` ; session avec images 91 OK, étiquettes posées) :
  - nauvis : tungstène en (−34, −361), à 362,6 tuiles, essai 2 (candidat 1 sur l'eau) ; cristal en (33, 273), 275,0,
    essai 1 ; méthane en (−247, −286), 377,9, essai 1 ; 197 / 149 / 2 entités, gisement complet, biome dessous, tout
    dans l'anneau. Ces 3 sites sont désormais sur TOUTE carte de banc créée par `fo-autotest.bat` (loin des zones des
    greffons : x ≥ 300, y de 240 à 336) ;
  - A : 15 sites posés, tous complets (4 refus « sol ») ; B : posé seulement ce qui manque (graine 1 : méthane ;
    987654321 : tungstène ; 3141592653 : tungstène et méthane ; 42 et 123456 : rien), puis au moins `count` unités à
    moins de dmax pour les 3 ressources sur les 5 graines ; C : 0 gisement avant, 3 sites après ; D : « 1:batiment,2:sol »,
    candidat 3 retenu, coffre et eau intacts (F134) ; F : cristal oublié au tick 300, repris au tick 600 par le filet,
    son site compté, rien reposé.
  - Coût (LuaProfiler) : `on_init` d'une partie neuve, 3 sites, 136,4 ms (génération forcée comprise) ; configuration
    d'une sauvegarde 0.4.4, 105,6 à 113,2 ms ; filet sans rien à poser, 1,4 ms ; surface neuve de banc, 119 à 196 ms ;
    surface explorée, 11 à 21 ms. Une fois par ressource et par partie. Par tick : le filet (une boucle sur 3 clés) et
    `on_chunk_charted` : NON mesurés séparément (bornés par construction).
- Essais adverses du vérificateur (scénario `m0-verif`, copié dans `M0\verif\`) : 45 sites posés sur 15 cartes (W : eau
  au maximum ; R : minerais vanilla au maximum ; N : nauvis). Les 30 sites de R et N sont reliés au départ à pied et
  exploitables (fantôme forcé : 90 OK) ; **sur W, 7 sites sur 15 ne sont pas reliés au départ** dans la boîte explorée
  (« non relié » PLAUSIBLE, pas certain) ; le tungstène de W42 n'est trouvé qu'à l'**essai 14 sur 24** ; `apply` coûte
  121 à 283 ms sur N et R, **jusqu'à 767 ms** sur W42. D'où le défaut majeur M-1 : un échec était définitif et muet.
- **Suite : l'échec puis la reprise** (correction M-1 ; le correcteur proposait le numéro E77, réservé aux lots M1 et
  M2 : l'expérience est consignée ici). Scénario greffé `m0-reprise` (2 600 ticks, contrôle final au tick 2 460, graine
  20261020) : tungstène oublié ; gisements de tungstène retirés à moins de 500 tuiles avant chaque passage du filet ;
  coffres du joueur sur les 48 candidats des essais 0 et 1 ; eau sous la moitié ouest du cœur des 24 candidats de
  l'essai 2. Résultat : « [FO-M0-REPRISE] BILAN : 15 OK, 0 ECHEC(S) » (`correction\m0-reprise`, `done.txt` 16:45:02,98 ;
  sur `main`, 17:45:39,32). Tick 600 : essai 0, 24 refus (23 « batiment », 1 « voisin »), ressource NON marquée
  traitée, reprise prévue au tick 1 200 (2,8 ms). Tick 1 200 : essai 1, 24 refus, reprise au tick 2 400 (2,4 ms).
  Tick 1 800 : aucune passe. Tick 2 400 : essai 2, niveau 2, candidat 2 (le 1 refusé « gisement »), site en (96, −304)
  à 318,8 tuiles, 170 tuiles d'eau comblées par les cendres, 197 entités, 197 717 minerais, 0 tuile d'eau restante dans
  le disque, 48 coffres intacts (4,7 ms). Un premier passage (`m0-reprise-1`, 16:44:35,08) a révélé F135.
- NON PROUVÉ : un échec NATUREL (sans mise en scène) suivi d'une reprise ; le niveau 3 (anneau × 1,5), joué hors jeu
  seulement ; le coût d'un essai échoué qui doit générer les chunks de ses 24 candidats (ordre de grandeur : 767 ms
  pour 14 candidats sur W42 ; au pire répété à chaque reprise : 10 s, 20 s, 40 s… puis toutes les 10 min) ; l'accès à
  pied (m-1) ; le message d'échec à `on_init`, envoyé avant la création du joueur (m-3) ; la voie `on_init` réelle de
  nauvis sur une autre graine que 20261020 (attend `FO_MAP_SEED`, lot INT-GRAINE) ; les factions IA (m-7 : un QG peut
  se poser sur un site, probabilité estimée à 1 %, non jouée) ; décor (m-5 : entités d'un autre biome gardées dans le
  disque, braises qui débordent peut-être) ; le visuel (captures `captures-2`, à juger par le DC : Q-M0-2).

**E73 · VALIDÉ (le risque est réel) ; représentativité NON établie · Les monnaies manquent-elles sur une graine
quelconque ? (lot M0, banc `monde`, cas B, 23/10)** :
- Protocole : 5 graines, carte explorée sur 23 chunks (environ 736 tuiles), réglages de nauvis du banc ; compte
  NATUREL avant garantie, à moins de dmax (500 tuiles pour le tungstène, 600 pour le cristal, 700 pour le méthane) ;
  unités : 100 000 de minerai pour le tungstène, 60 000 pour le cristal, 1 puits pour le méthane.
- Résultats (entre parenthèses : distance du plus proche) :

  | Graine | Tungstène | Cristal | Méthane (puits) | Cendres à 200 / 500 / 700 tuiles |
  |---|---|---|---|---|
  | 1 | 35 (405) | 47 (354) | **0** | 29 629 / 137 766 / 225 327 |
  | 42 | 90 (426) | 81 (449) | 9 (667) | identiques à la graine 1 (voir ci-dessous) |
  | 123456 | 91 (288) | 86 (233) | 34 (444) | 794 / 44 528 / 61 506 |
  | 987654321 | **0** | 47 (184) | 50 (451) | **0 / 0 / 0** |
  | 3141592653 | **0** | 55 (397) | **0** | 0 / 70 289 / 270 873 |

  **3 graines sur 5 n'ont pas, à la distance prévue, au moins une des trois monnaies** : le blocage à l'âge 5 (ou 8)
  est réel. Graine 20261020 (nauvis du banc) : dans la seule zone générée de la sauvegarde 0.4.4, 9 unités de cristal
  (222 entités, le chiffre d'E13) et 8 puits de méthane, aucun tungstène. Relevé reproduit à l'identique par le
  vérificateur.
- Anomalie NON expliquée (mineur m-9) : les comptes de TUILES de biome des graines 1 et 42 sont identiques au chiffre
  près (29 629 / 137 766 / 225 327 de cendres, et 13 294 / 99 555 / 168 281), alors que les gisements diffèrent ; piste :
  le bruit des biomes (`factorio-multioctave-noise`, `seed0` = graine de la carte) varierait peu pour de petites
  graines. Tant qu'elle n'est pas expliquée, « 3 sur 5 » ne vaut pas statistique.

**E72 · VALIDÉ (table des familles) ; séparation des âges 4 et 5 FAIBLE, à soumettre au DC ; lot en cours
d'intégration · Familles de couleur des foyers des âges 5, 6 et 13 à 15 contre les mesures de la mitrailleuse
validée (lot K0, 23/10)** :
- Protocole : mesures des foyers de la mitrailleuse validée (âges 2 à 12 :
  `fo-logs\2026-10-23_V3E-p5\juges\mesures\mesures.txt` §2 ; 13 à 15 : `fo-logs\2026-10-23_V3E-ereV\controles\mesures.txt` §2), 14 âges × 2 poses ; contrôle
  `ages.verifier_mesures()` au chargement du registre ; `mesures.py` (nouvel outil) rejoué sur les sprites. Seule la
  TABLE change ; aucun rendu.
- Résultat : âge 5 « braise vive (rouge à orange, très saturé) », 345 à 36°, saturation 0,77 à 1,0 (mesuré : 31°,
  0,87 ; avant : « rouge braise », 345 à 14°) ; âge 6 « bleu électrique », 186 à 214°, 0,25 à 1,0 (mesuré : 210°, 0,48 ;
  avant : 186 à 202°) ; âge 4 resserré à 24 à 34°, saturation 0,50 à 0,77 (mesuré : 30°, 0,67) ; ère V inscrite :
  13 violet d'annihilation, 14 blanc stellaire, 15 incandescence blanc-or. Les 28 mesures tombent dans leur famille ;
  aucune paire de voisins n'est compatible ; sur les sprites de production de l'ère V, 13, 14 et 15 « dans la
  famille » (poses E et N) ; sur `V3E-p5\final\sprites`, 5 et 6 passent de « HORS FAMILLE » à « dans la famille », et
  les ANCIENS 13 à 15 refusés (Fusion, Orbite, Légende) passent « HORS FAMILLE », comme attendu. Rejoué par le
  vérificateur : les 28 mesures sont exactement celles des fichiers sources.
- Limites : les âges 4 et 5 ne sont séparés que par la SATURATION (0,67 contre 0,87, frontière à 0,77, marge de 0,10 de
  chaque côté), seul couple de voisins dans ce cas ; la famille 15 (24 à 50°, 0,2 à 0,7) recouvre désormais la
  famille 4 ; compatibilités entre âges non voisins : avant K0 2-5, 2-14, 5-14, 6-12 ; après K0 2-5, 3-15, 4-15, 6-10,
  6-12, 6-14, 7-13, 11-14. Question proposée par le correcteur, PAS encore posée au DC : A garder (la forme sépare 4 et
  5) ; B décaler le foyer du Volcan (5) vers le rouge (nouveau rendu des âges 5 de la mitrailleuse) ; C décaler le
  Pétrole (4) vers le jaune. Le §D.3 du catalogue réécrit pour l'ère V (`K0\D3_ere_V.md`, hors dépôt) est une
  PROPOSITION non jugée par le DC.

**E71 · VALIDÉ (aucun design validé changé, empreinte FORTE) ; lot en cours d'intégration (INT-K0) · Refonte du kit
commun des familles sans toucher un design validé (lot K0, 23/10, 15 h 45 à 18 h 06)** :
- Protocole du constructeur : empreinte AVANT par l'outil d'origine (`gun_e/construction.py --tout`, `93e3d89`, 72
  variantes en 94 s, 15:45:54 à 15:47:30) ; empreinte AVANT géométrie + matières par le nouvel outil sur une archive
  (`git archive 93e3d89 tools/render/pieces/levels/gun_e`, `--tout --matieres --dossier`, 185 s) ; empreinte APRÈS
  sur le worktree refondu (`--famille gun_e --tout --matieres`, 119 s) ; 11 habillages d'essai × 5 tailles × 3
  variantes = 165 constructions de chaque côté ; comparaison par `commun/empreintes.py`. Toutes les constructions SANS
  rendu, par le verrou de rendu.
- Défaut trouvé en chemin par le constructeur lui-même : la première empreinte des matières ne lisait que les ENTRÉES
  des nœuds, alors que `fo_scene.mat_metal` pose couleur et rouille sur la SORTIE d'un nœud RGB ; un mutant
  (`basalte_capot` 0,115 → 0,116) passait inaperçu (`e05-socle` restait `cfcd614b6220`). Corrigé (sorties hachées :
  `bdda7b086e4b`), empreintes refaites ; les premières sont gardées pour mémoire (`v1_hash_sans_sorties\`).
- Résultat du lot : « 72 variantes comparées, 0 différente(s), 0 absente(s) (géométrie et matières) » ; même
  géométrie que l'outil d'origine (72 sur 72) ; habillages 165 sur 165 identiques ; outils de contrôle (îlots, gris,
  mesures, dominance, aperçu) identiques avant et après sur `V3E-p5\final\sprites`, hors des changements voulus (noms
  de l'ère V, familles 4, 5, 6, 13 à 15) ; `[K0-VIGNETTES] 7 OK, 0 ECHEC(S)`.
- Vérification adverse (16 h 40 à 17 h 30) : empreinte FORTE indépendante (tous les objets de `bpy.data` dont les
  lumières de halo, matrice monde, modificateurs, maillage évalué, entrées et sorties de tous les nœuds, monde, données
  Python des 16 modules d'âge) sur 237 constructions : **0 différence** ; mais 4 défauts MAJEURS du lot : (1) `--famille`
  chargeait en silence l'`epoques` de la mitrailleuse (une famille d'essai 1×1 lisait `COTE[5] = 3`) ; (2) l'ordre des
  `metal()` de l'âge 6 avait changé, donc ses graines (`porcelaine` 622 → 688…) ; (4) l'outil livré ne voyait ni les
  halos ni les transformations (mutant « halos × 1,5 » passé inaperçu : « 0 différente(s) ») ; (5) `palette(N)` donnait
  une mauvaise secondaire aux âges 3 et 15 (et 11, trouvé par le correcteur) ; plus le défaut 3, antérieur à K0 (F136).
- Correction (17 h 30 à 18 h 15, `K0\correction\`) : (1) `famille.charger` oublie les modules d'une autre famille
  (test `commun/tests/test_famille.py` : « [K0-FAMILLE] 12 OK, 0 ECHEC(S) » ; 3 OK et 9 ECHEC sur le code non corrigé
  `0cee947`) ; (2) `porcelaine` remise en 2e position de `ages._m06` (graines d'origine : 622, 633, 644… 688) ; (4)
  `construction.py --forte` et `empreintes.py --forte` (empreinte du vérificateur + relevé des appels `mat_metal`,
  `mat_emissive`, `mat_flat` avec leurs graines) ; (5) table explicite `ages.PALETTE[N]` et `verifier_palettes()`
  (âge 7 : secondaire DÉDUITE de la ronde 1, non dite par le DC). Preuve : empreinte forte de `93e3d89` (17:37:50 à
  17:41:22) contre le worktree corrigé (17:41:22 à 17:44:56) : **« 72 variantes comparées, 0 différente(s),
  0 absente(s) (forte) », graines comprises (4 360 graines relevées)** ; habillages : 165 sur 165 identiques (forte) ;
  l'empreinte forte voit le défaut 2 (`0cee947` contre `93e3d89` : 4 variantes e06 différentes, 8 écarts, objets et
  matières identiques) et le mutant halo (3 écarts nommés, `s05_halo_0` à `_2` ; « 0 différente(s) » sans `--forte`) ;
  l'outil du vérificateur sur le worktree corrigé : « 237 variantes, 0 differente(s) ; modules : 19 ecart(s) » (14
  ordres de clés de `HABILLAGE`, ordre d'insertion de `M` aux âges 10 et 12, et un artefact du faux `metal()` du
  script d'essai ; aucun appel réel de matière ne diffère).
- NON PROUVÉ : le paramétrage par famille n'est éprouvé que sur la mitrailleuse (seul profil existant) ; un réglage de
  nœud hors de la liste relevée ; `stone-wall` non mesuré pour la charte (`dominance.py` refusera le mur) ; `rendre.py`,
  `batch_blender.py`, `accroches.py` et `corps.plateforme` restent dans `gun_e` ; aucun rendu. À la fusion avec A1
  (INT-K0) : `rose.py` et `e66.py` d'A1 importent `compo` depuis `gun_e` (cassés par le déplacement : ajouter `commun`
  au `sys.path`), puis rejouer l'empreinte forte contre `K0\correction\avant.json`.

**E70 · VALIDÉ en moteur réel · Origine et sens des directions d'une tourelle ; `shooting_target` imposé ; image
choisie par le moteur (lot A1, 23/10, 15 h 52 à 16 h 48 ; copie jetable)** :
- Protocole : 5 groupes de 8 tourelles (N, NE, E, SE, S, SO, O, NO ; cible à 4 tuiles, diagonales à (4, 4)). G1 :
  « flèche » + munitions + coffre NEUTRE indestructible imposé par `shooting_target` ; G2 : idem sans munitions ;
  G3 : mitrailleuse vanilla + munitions + coffre neutre imposé ; G4 : flèche + munitions, gros ver ENNEMI (visée
  automatique, cessez-le-feu de l'ennemi) ; G5 : flèche + munitions, aucune cible, `orientation` écrite. « Flèche » :
  tête de test dont l'image k (64 directions) est une flèche tournée de k × 360/64° dans le sens horaire depuis le haut,
  numérotée, rouge levée, bleue repliée. Banc `fo-autotest.bat nopause 1000 a1-tourelle "<copie jetable>"`, captures
  `fo-captures.bat a1-tourelle "<copie>"`.
- Résultats (`A1\moteur\banc3_1000ticks_final\a1-tourelle.txt`, BILAN 5 OK, 15:56:07,00 ; captures 15 h 55, 20 sur 20) :
  - `orientation` d'une tourelle se lit (40 sur 40) et s'écrit (G5, 8 sur 8, sans erreur) ;
  - G4 : orientation finale = j/8 pour la direction j, 8 sur 8 : **origine au nord, sens horaire**, comme la doc ;
    rotation par le plus court chemin (au tick 80 : 0,12 vers l'E et le SE, 0,88 vers le S, le SO, l'O et le NO) ;
  - G1, G2, G3 : l'écriture de `shooting_target` vers l'entité neutre ne lève pas d'erreur, la cible est effacée au
    tick 61, la tête ne bouge pas jusqu'au tick 900 (« 1 / 8 » au bilan = la direction N, déjà au nord) ;
  - G5 : l'orientation écrite tient du tick 60 au tick 900 (8 sur 8) ;
  - captures : images 0, 6, 16, 26, 32, 38, 48, 58 pour N, NE, E, SE, S, SO, O, NO, en rouge (G4) comme en bleu (G5) :
    les diagonales ne sont PAS 8, 24, 40, 56 (`apply_projection`, F121).
  Rejoué par le vérificateur sur une copie neuve (16:48:01,51) : mêmes chiffres ; sur le mod LIVRÉ, le scénario se
  refuse proprement à l'init (« prototypes de test absents », 16:48:18,87) ; `content` 317 OK sur le worktree.
- NON PROUVÉ : une cible ENNEMIE imposée autre que celle que la tourelle choisirait ; la règle `apply_projection` aux
  64 directions (vue aux 8) ; une vraie feuille `dKK` en jeu (F121 déduit).

**E67 · VALIDÉ en moteur réel (levée seulement) · Durée réelle de la levée (`preparing`) d'une tourelle (lot A1,
23/10 ; copie jetable, même banc qu'E70)** :
- Protocole : 5 copies de la mitrailleuse vanilla, 4 répliques chacune, seules (64 tuiles d'écart), 20 chargeurs ; au
  tick 60, une mitrailleuse ennemie sans munitions apparaît à 8 tuiles à l'est. Mesures : tick où l'orientation quitte
  0 (la tête ne tourne qu'une fois levée), tick où la cible perd des PV (premier tir). Le vérificateur a relu
  `--dump-final` : la variante à 5 images a bien `frame_count = 5` sur toutes ses couches.
- Résultats (les 4 répliques identiques au tick près) :

  | Variante | images × repeat | vitesse | doc (1/v) | garde du kit (images/v) | tête tourne après | premier tir après |
  |---|---|---|---|---|---|---|
  | a1-e67-v5 | 5 × 1 | 0,08 | 12,5 | 62,5 | 13 ticks | 30 ticks |
  | a1-e67-i1 | 1 × 1 | 0,08 | 12,5 | 12,5 | 13 | 30 |
  | a1-e67-r5 | 1 × 5 | 0,08 | 12,5 | 62,5 | 13 | 30 |
  | a1-e67-i1-lent | 1 × 1 | 0,016 | 62,5 | 62,5 | 63 | 80 |
  | a1-e67-v5-lent | 5 × 1 | 0,016 | 62,5 | 312,5 | 63 | 80 |

  **La doc a raison, la garde du kit a tort** (F120). Premier tir 30 ticks après l'apparition de la cible : levée 13,
  rotation de 0 à 0,25 à 0,015 tour par tick, puis tir.
- NON PROUVÉ : `folding`, `attacking`, `starting_attack`, `ending_attack` (non joués ; la doc 1.1.91 dit la même phrase
  pour toutes) ; l'arrondi exact (F120 : à un tick près).

**E66 · VALIDÉ hors moteur (qualité) ; gain de temps MESURÉ dos à dos : 44,7 % ; ombre en moteur NON prouvée · L'ombre
de la tête de la mitrailleuse à 32 échantillons contre 128 (lot A1, 23/10, 15 h 48 à 17 h 27)** :
- Qualité, protocole : les têtes d00 et d16 de la rose (aperçu, toutes les passes à 32 échantillons ; la passe d'ombre
  est un rendu à part) contre les têtes N et E validées à 128, âges 2, 9 et 15 (6 poses) ; couche d'ombre recalée sur
  un canevas commun ; écart d'alpha (0 à 255) sur l'union des pixels d'ombre (`gun_e/e66.py`, `A1\e66\e66.txt`).
- Qualité, résultats :

  | Âge, pose | écart moyen (hr) | max | centile 99 | > 4 niveaux | > 16 niveaux | biais | normale : moyen / max |
  |---|---|---|---|---|---|---|---|
  | 2 N | 1,34 | 22 | 11 | 6,7 % | 0,22 % | +0,03 | 0,76 / 9 |
  | 2 E | 1,37 | 33 | 11 | 6,5 % | 0,18 % | +0,03 | 0,81 / 9 |
  | 9 N | 1,84 | 29 | 12 | 9,2 % | 0,19 % | −0,02 | 1,03 / 13 |
  | 9 E | 2,25 | 35 | 12 | 12,4 % | 0,29 % | −0,01 | 1,29 / 12 |
  | 15 N | 2,14 | 43 | 15 | 12,9 % | 0,57 % | −0,04 | 1,39 / 14 |
  | 15 E | 3,23 | 42 | 17 | 23,4 % | 1,11 % | −0,01 | 1,87 / 13 |

  L'écart est du GRAIN (bruit de Monte-Carlo, sans biais : moyenne d'alpha identique à 0,04 niveau près, contours
  identiques). Dans l'image composée hors moteur (socle + tête, ombre à 50 % comme `compo.py`) : au plus 7,5 à 11,2
  niveaux RVB au zoom 2, sur 0 à 11 pixels au-dessus de 8 niveaux par image ; au plus 3,7 niveaux au zoom 1
  (`e66-composition.txt`, script `e66_compo.py` HORS dépôt, non rejoué par le vérificateur). Sortie de `e66.py`
  rejouée par le vérificateur : identique.
- Temps, PREMIÈRE MESURE : **REFUSÉE** (défaut majeur D1 de la vérification) : « gain 51 % » tiré de deux rendus pris
  sous des charges différentes (128 : rendu d'identité pendant un banc ; 32 : la rose, avec d'autres lots qui
  rendaient) ; rapports 128/32 de 4,8 à 7,1, impossibles sans échantillonnage adaptatif ni débruitage
  (`fo_scene.py:51-52`). Ce 51 % est FAUX et ne doit être repris nulle part ; les « 36 % » du vérificateur mêlaient
  aussi deux charges.
- Temps, MESURE CORRIGÉE (correcteur, 17 h 07 à 17 h 27 ; `A1\e66\temps_dos_a_dos\`, outils
  `gun_e/e66_temps.py` et `e66_temps_blender.py`) : UNE session Blender, scène construite une fois par pose, chaque
  passe rendue SEULE (rendu par passe de la décision D-7) : ombre 32, ombre 128, main 128, lueur 128, ombre 1 ;
  3 répétitions en ordre alterné, chauffe non comptée ; les DEUX places du verrou de rendu tenues (aucun autre
  Blender pendant les 90 rendus), charge surveillée toutes les 2 s (0 rendu chevauché par un banc ou un factorio.exe ;
  autres processus : médiane 3,0 % de la machine) ; ombres de la répétition 1 identiques (sha256) aux sprites validés
  (128) et à la rose (32), 12 sur 12 ; pixels identiques d'une répétition à l'autre, 5 sur 5. Médianes (secondes) :

  | Pose | ombre 1 | ombre 32 | ombre 128 | 128/32 (3 rép.) | main 128 | lueur 128 | gain tête (3 rép.) |
  |---|---|---|---|---|---|---|---|
  | 2 N | 0,15 | 2,9 | 11,7 | 3,99 3,94 3,98 | 8,6 | 1,2 | 41,0 / 40,3 / 41,1 % |
  | 2 E | 0,18 | 2,9 | 11,6 | 3,91 3,97 3,96 | 7,0 | 1,0 | 43,6 / 44,2 / 44,2 % |
  | 9 N | 0,29 | 6,8 | 26,1 | 3,82 3,92 3,81 | 17,2 | 2,5 | 42,2 / 42,5 / 42,0 % |
  | 9 E | 0,30 | 6,6 | 26,6 | 3,87 4,00 4,03 | 17,6 | 2,6 | 42,0 / 42,6 / 42,7 % |
  | 15 N | 0,60 | 15,3 | 60,7 | 3,99 3,98 3,96 | 32,0 | 5,6 | 46,4 / 46,2 / 45,7 % |
  | 15 E | 0,63 | 15,1 | 60,3 | 3,94 4,01 4,00 | 31,2 | 5,6 | 46,4 / 46,7 / 46,4 % |

  L'ombre suit le modèle proportionnel (coût fixe 0,05 à 0,18 s ; 0,09 à 0,47 s par échantillon ; rapport 128/32 de
  3,81 à 4,03, 4,34 une fois au passage de contrôle ; attendu 3,92 à 3,97). **Tête entière (main 128 + lueur 128 +
  ombre), 6 poses : 328 à 330 s → 182 s, gain 44,7 %** (44,6 à 44,8 % sur les 3 répétitions ; 40 à 47 % selon la pose,
  plus fort sur les grandes têtes) : le plan supposait −45 % (« × 0,565 ») : confirmé. Temps absolus sur machine libre
  environ deux fois plus courts que sous charge (ombre 128 de l'âge 2 N : 11,7 s contre 22,6 s) : seul le RAPPORT
  mesuré dos à dos vaut.
- NON PROUVÉ : l'ombre rendue EN MOTEUR (passe d'ombre du jeu, compression DXT : à regarder sur la première capture
  d'A2) ; le gain sur l'horloge d'un paquet complet (construction de scène, démarrage de Blender, conversion et
  post-traitement non comptés : un peu plus faible) ; le kit (`batch_blender.py`, gelé) ne sait pas encore régler les
  échantillons par passe (D-7) : la rose a tout rendu à 32.
- **La rose des 8 directions** (même lot, rendue pour E66 et pour le DC ; aperçus à 32 échantillons, 112 têtes, 2 334 s
  d'horloge sur 2 sessions ; planches composées hors moteur `A1\rose\`, page https://claude.ai/artifact/9zVUA65YE4wVfaaxobjZ6W ;
  PAS vue en moteur, aucun verdict du DC) ; regard de l'agent, pas un verdict : pose N : le piège F119 reste visible
  (canons dressés lus comme des tubes verticaux aux âges 3, 4, 7, 8, 9, 13, 14 et 15) ; d08 et d56 : les canons se
  lisent comme des armes à tous les âges (mais d08 = cible à 54,7° du nord ; d01 à d07 non rendues : limite du secteur
  « cheminée » NON vérifiée) ; pose S : canons raccourcis (environ 0,7 × leur longueur), l'arme se perd presque au zoom
  1 aux âges 10, 12, 13, 14 et 15 ; la tête cache de 0,32 à 0,46 du socle (0,21 pour la tête vanilla de l'âge 1),
  maximum en S aux âges 2 à 15 (+3,5 à +9,9 points par rapport à E aux âges 2 à 9 ; +0,8 à +3,1 aux âges 10 à 15) ;
  **trous enfermés : 19 échecs sur 112** à la règle ≤ 8 px (`rose\trous.txt`), dont les gros en SE, S et SO aux âges 4
  (99 à 108 px), 5 (50 à 76), 6 (42 à 62) et 7 (199 à 249) : fente entre coupole et cadre arrière, géométrique ; ils
  bloqueraient une production à 64 directions avec la règle actuelle : à trancher avant A3 (combler par une pièce de
  fond dans le kit, ou accepter en S). Défaut d'outillage trouvé : `epoques.NOMS` de `main` donnait encore pour 13 à 15
  les noms de l'ancienne ère V refusée (corrigé dans `rose.py`, et par `ages.py` du lot K0 à son intégration).

**E65 · ÂGES 1 À 12 RETENUS PAR LE DC (« pratiquement parfaits ») ; ère V refusée, refaite (run `wf_5f1609fb-473`) ;
juges 6,5 à 7,5 sur 10, « pas prêt » pour les 6 autres familles · V3-E, cinquième passe : le test des âges pendant la
construction (23/10, 6 h 05 à 14 h 45 ; run `wf_5b157c7b-fa0`)** :
- Protocole :
  - kit en trois temps sur la branche `v3e-p5-kit` : `000a0a4` (vignettes lettrées et mélangées, clé sur la sortie
    standard seulement ; rendu de ronde à 32 échantillons ; règle D3 comptée dans la dominance ; gris en poses E et N ;
    pose N de la lignée ; clé d'habillage « capots » ; variante de corps B), `ca12d04` (habillage de TOUT le bâtiment :
    pont, trémie, acier, rivets ; points d'accroche des superstructures ; empreinte de construction identique quand
    les clés valent None, 72 variantes), `7587e76` (formes de pont, de coupole, de trémie et de jupe ; canon effilé) ;
  - test du catalogue §C appliqué PENDANT la construction : 2 lecteurs sans contexte, 15 vignettes mélangées et
    lettrées, liste des 15 triplets ; test des écarts (critère Clash of Clans du DC : paires d'âges de même taille
    notées de 1 à 5, plus évoluée, grade ultime) ; un lecteur de la pose N (« cheminée ? ») ;
  - 5 rondes de deux constructeurs (worktrees persistants `v3e-p5-bas` et `v3e-p5-haut`) ; production à 128
    échantillons (57 sprites) ; assemblage sur la branche `v3e-p5` (`3bb02b3`) ; deux juges ; planches.
- Interventions de l'orchestrateur, toutes par arrêt et reprise du run : variante de corps B écartée (7 h 35 : elle
  n'éclaircit pas, C1 inchangé, et réduit les petits contrastes de 29 à 47 % ; au test de la ronde 0 elle fait aussi
  moins bien que A : 10,0 bonnes réponses en moyenne contre 12,5, 8 confusions entre ères contre 5) ; consigne Clash of
  Clans du DC (7 h 55) ; arbitrage de charte (8 h 57 : plafonds C1, C2, L1, L2 et règle D3 rapportés, non bloquants
  pour les âges clairs voulus par le DC) ; troisième temps du kit (9 h 36, écarts plafonnés vers 3) ; remarque du DC
  sur la palette (9 h 50, transmise par le journal des plages, sans arrêt). Défaut d'outil : à la troisième reprise,
  le cache n'a pas rejoué les constructeurs de la ronde 2 (prompts identiques mot pour mot, clés de cache
  différentes, cause non trouvée) ; contourné en injectant dans le script le texte des résultats de la ronde 2.
- Résultats des rondes (aperçus à 32 échantillons ; « bons » = âges reconnus avec la liste des triplets, 2 lecteurs) :

  | Ronde | Bons sur 15 | Confusions entre ères | Écarts voisins (sur 5) | Légende grade ultime | Cheminées (pose N) |
  |---|---|---|---|---|---|
  | 0 (passe 4) | 13 et 12 | 5 | 2,2 et 2,0 | 1 sur 2 | — |
  | 1 | 13 et 15 | 0 | 2,9 et 2,6 | 2 sur 2 | 9 sur 15 |
  | 2 | 15 et 15 | 0 | 3,0 et 2,8 | 0 sur 2 | 8 sur 15 |
  | 3 (palette) | 15 et 15 | 0 | 2,7 et 2,7 | 2 sur 2 | 5 sur 15 |
  | 4 | 13 et 12 | 2 | 3,0 et 3,3 | 2 sur 2 | 12 sur 15 |
  | 5 | 10 et 15 | 3 | 3,5 et 3,2 | 2 sur 2 | 4 sur 15 |

  Le lecteur de la pose N est seul : ses chiffres varient beaucoup d'une ronde à l'autre (9, 8, 5, 12, 4).
- Production (contrôles refaits par le juge des mesures) : îlots et trous 0 échec sur 100 ; gris FORME 0 paire sous
  25 % en poses E et N ; points blancs au plus 12,3 par t² (vanilla 13,2) ; 57 spec.json conformes ; dominance 34
  défauts dont 13 baisses de D3 (5 paires sur 14 dominent en pose E).
- **Test à l'aveugle final NON FAIT** : défaut du script de l'orchestrateur, qui cherchait les jeux de vignettes sous
  les noms « E », « G », « N », alors que l'assembleur les a nommés « E (couleur, pose E) », etc. Les juges ont jugé
  sans lecture de la production. Le test final de l'ère V refaite couvrira les 15 âges en production.
- Juges : direction artistique 7 (âges 1 à 9), 6,5 (10 à 15), 6,5 (ensemble) ; mesures 6,5 (1 à 9), 7,5 (10 à 15) ;
  « pas prêt » pour les 6 autres familles. Progrès reconnu : chaque âge a sa matière d'ensemble, la Légende domine en
  mesure (luminance médiane 139 contre 106 au mieux ailleurs), précision intacte au zoom 2. Bloquants : RÉGRESSION des
  canons 13 à 15 (le canon effilé les a raccourcis et uniformisés ; le 15 a perdu ses bouches en couronne) ; saut
  porté par la couleur plus que par la forme (recouvrement des contours de 0,89 à 0,94 entre voisines) ; prestige non
  monotone en clarté (4→5, 6→7, 11→12, 13→14) et « plus évoluée » juste 15 fois sur 30 à la ronde 5 ; pose N 4 sur 15 ;
  accents de 4 et 5 identiques (orange 30° et 31°) ; pièce paire du 8 trop petite (0,070 t² pour 0,10) ; clé des
  vignettes présente dans les transcriptions de l'orchestrateur (hors de portée des lecteurs, à noter).
- Verdicts du DC pendant la passe : 9 h 48 « les designs sont vrm bien », palette trop uniforme (corrigée à la ronde
  3) ; 12 h 40 « tous les bâtiments sont pratiquement parfaits sauf les 3 derniers » ; ère V refaite (option A, run
  `wf_5f1609fb-473`). Ce verdict prime sur celui des juges pour les âges 1 à 12 ; leurs défauts mesurés restent notés
  pour une passe de finition.
- Sorties : `<racine>\fo-logs\2026-10-23_V3E-p5\` (kit, kit2, kit3, r0 à r5, bas, haut, final, juges, presentation) ;
  page de suivi https://claude.ai/artifact/SWLGoaBpAHcsax5z6zzhfw .

**E64 · NON VALIDÉ (juges : pas prêt) · V3-E, quatrième passe : un kit d'époque unifié, puis correction ciblée des
époques ratées (23/10, 0 h 25 à 5 h 40 ; run `wf_b0a51b34-fe1`)** :
- Protocole : un responsable du kit (worktree `wf_b0a51b34-fe1-1`, `c7f4f8f`) réunit les deux plages de la passe 3
  dans un seul dossier `tools/render/pieces/levels/gun_e/` (kit commun gelé, un fichier par époque `ep01.py` à
  `ep15.py`, outils communs : rendu par paquets, îlots et trous bloquants, mesures, gris FORME, dominance, vignettes
  mélangées) ; deux constructeurs en parallèle (époques 1 à 9 : `7300ead` ; 10 à 15 : `db7678b`) ; rendus de production
  à 128 échantillons (57 variantes, HR et 32 px) ; regard naïf à l'aveugle en couleur et en gris, en description libre ;
  deux juges (direction artistique, mesures) ; planches recomposées hors moteur. Branche de réunion `v3e-p4`
  (`200d5d5`, fusion faite par l'orchestrateur : `ep02` à `ep09` de la plage basse, `ep10` à `ep15` de la plage haute,
  kit identique à `c7f4f8f`, vérifié par `git diff`). Sorties : `<racine>\fo-logs\2026-10-23_V3E-p4\`.
- Progrès de construction (vérifiés par le juge des mesures) : un seul kit, la rupture de grammaire entre 9 et 10 a
  disparu (sauf les deux caissons gris clair de 10) ; l'organe d'époque s'ajoute à l'arme ; îlots et trous : 0 échec sur
  100 contrôles ; points blancs 11,2 par t² au plus (passe 3 : 17 à 44 ; vanilla 13,2) ; 28 foyers sur 28 dans leur
  famille ; FORME en gris ≥ 25 % pour les 10 paires de même taille en pose E (7 à moins de 3 points du seuil) ; précision
  intacte au zoom 2.
- Résultats d'identité : regard naïf en couleur, Spearman 0,979 et 4 inversions, ordre porté par la taille en trois
  paliers ; âges reconnus en description libre : 5 à 6 nets, 4 à 6 partiels, 4 à 5 faux, soit environ 7 à 8 sur 15 comme
  en passe 3 (seuil du catalogue : 12). Lus faux : 4 Pétrole « vapeur, laiton » (régression), 5 Volcan « runes de
  dragon », 6 Électricité « cheminée », 9 Atome « électrique », 11 Titane « militaire générique ». Regard naïf en GRIS
  invalide : le lecteur a mélangé deux identifiants de fichier (Forge et Cristal), Spearman 0,736 non significatif.
  Pose N : canons dressés toujours lus comme des cheminées, pire en plage haute. FORME en gris en pose N sous 25 % pour
  4 paires (4-5 21,2 %, 5-6 23,1 %, 8-9 22,3 %, 10-11 23,2 %), non mesurée par les constructeurs. Dominance : 4 défauts
  (4→5, 5→6 en E et N, 14→15), plus 4 si la règle « D3 ne baisse pas de plus de 5 % » était comptée (elle n'était
  qu'imprimée). Charte : 57 compositions sur 58 en échec bloquant (D3max de 47,6 à 67,5 pour un plafond de 45, P2).
  Juges : 6 et 6 sur 10 (direction artistique), 6 et 6,5 (mesures) ; « pas prêt » pour les 6 autres familles.
- Cause commune selon les juges : le corps de lignée est trop sombre et trop dense en petits contrastes ; il écrase tout
  ce qui n'est pas une couleur vive, et les époques bien lues (Cristal, Marais, Fusion, Orbite) sont celles qui ont une
  couleur franche. Le défaut « identité par la couleur » de la passe 3 n'est donc pas résolu, seulement déplacé.
- **Écart de protocole (faute de l'orchestrateur)** : le catalogue §C prévoit un regard naïf AVEC la liste des 15
  triplets « en 3 mots » (seuil : 12 sur 15, aucune confusion entre ères). Les passes 3 et 4 ont demandé une description
  libre, plus dure et non comparable au seuil. Et le test n'avait lieu qu'à la fin : les constructeurs corrigeaient sans
  mesure de lecture.
- Montré au DC : page privée https://claude.ai/artifact/6oWtaBeDK7gR5ALMySwjWb (23/10, vers 6 h 10), sans demande de
  validation ; il peut refuser qu'on touche au corps (« corps : non »).
- Suite : passe 5 (run `wf_5b157c7b-fa0`, lancée le 23/10 vers 6 h 05 ; worktrees persistants `v3e-p5-kit`,
  `v3e-p5-bas`, `v3e-p5-haut` depuis `v3e-p4` ; sorties `<racine>\fo-logs\2026-10-23_V3E-p5\`) : protocole du
  catalogue (liste des triplets, lettre dans l'image, contrôle des renvois par la taille citée) appliqué PENDANT la
  construction, en rondes (3 au plus) ; corps « valeurs groupées » essayé en ronde 0 contre le corps actuel, retenu
  seulement s'il gagne au moins une bonne réponse en moyenne ; pose N de la lignée, clé d'habillage « capots », règle D3
  comptée, gris en pose N ; production seulement après 12 sur 15 ou la 3e ronde.

**E63 · NON VALIDÉ (juges : pas prêt) · V3-E, troisième passe : la mitrailleuse sur les 15 époques, une direction
artistique par âge (22/10, 19 h 03 à 23 h 59 ; run `wf_0608aa1f-b85`)** :
- Protocole : catalogue `fo-logs\2026-10-22_V3E\catalogue\DA_PAR_EPOQUE.md` (15 fiches) ; deux constructeurs en
  parallèle (époques 1 à 9, branche `worktree-wf_0608aa1f-b85-2`, tête `69c3cc9` ; époques 10 à 15, `-3`, tête
  `d68f353`), relancés deux fois (17 h 31 : doublon d'agents ; 19 h 02 : époques encore distinguées par la couleur) ;
  rendus de production à 128 échantillons ; regard naïf à l'aveugle sur 15 vignettes mélangées, en couleur et en gris ;
  deux juges ; planches recomposées hors moteur.
- Résultats : regard naïf, ordre presque juste mais porté par la taille (Spearman 0,957 et 6 inversions en couleur ;
  0,979 et 4 en gris) ; environ 8 âges sur 15 reconnus sans légende (seuil du catalogue : 12). Bien lus : Vapeur,
  Pétrole, Cristal, Fusion, Orbite. Confusions : Électricité lue « vapeur », Marais « nucléaire », Atome « électronique »,
  Titane « industrie lourde », Légende « railgun » (rangée sous 13 et 14), Volcan « résistances ». Juges : 5 et 6 sur 10,
  « pas prêt » ; deux kits divergents (rupture entre 9 et 10), organe d'époque qui recouvre l'arme au lieu de s'y
  ajouter, identités par la couleur seule, ère I plus faible que la vanilla, tuyaux de la plage haute identiques,
  pose N lue comme des cheminées, 8 îlots détachés, points blancs de scintillement, vignettes écrites dans l'ordre.
- Montré au DC : page privée https://claude.ai/artifact/N47FzmN1QtKUbDMNAuHJA7 (23/10, 0 h 20).
- Suite : passe 4 (run `wf_b0a51b34-fe1`, lancée le 23/10 vers 0 h 25) : kit d'époque unifié, puis correction des
  époques 2, 5, 6, 8, 9, 10, 11, 12 et 15, tuyaux par époque, pose N, îlots et scintillements.

**E62 · VALIDÉ en moteur réel ; lot LIVRÉ, NON INTÉGRÉ (Q-T4-1) · Correction du lot V3-T4 : munitions, modules,
blindés, coûts et rentabilité (correcteur `2b18742`, 22/10, de 22 h 10 à 22 h 40 ; numéro provisoire E58)** :
- But : corriger les 23 défauts de la revue adverse à 3 regards du lot V3-T4 (Q-T2-2 répondue A le 22/10 à 21 h 12)
  et MESURER ce que l'ingénieur avait seulement calculé.
- Protocole (moteur réel) : seconde fenêtre du scénario greffé `t4-production` (5 300 ticks ; ticks 2 760 à 5 160,
  zone supplémentaire (588,352)-(868,520)) : assembleur 30 avec 2 modules de vitesse de palier 10 (engrenages) ;
  foreuse 30 avec 3 modules de vitesse de palier 10, sortie dans un coffre vidé à chaque tick, puis sur un tapis
  express ; 6 tourelles contre un blindé « colosse » (chargeurs au tungstène) ; cartouches par tir aux niveaux 7, 13,
  19, 25 et 30. Cible des tourelles : tourelle laser 30 sans courant, 5 350 PV (marge × 14 sur le plus gros coup).
- Passages (`<racine>\fo-logs\2026-10-22_V3T4\`, code 0, `done.txt` relu) :
  - `11_` (22:26:11,23) : 3 OK, 18 ECHEC, erreur du greffon (inventaire de munitions demandé à un laser), corrigée ;
  - `12_` (22:26:30,56) : 18 OK, 2 ECHEC : la 6×6 ne prend que 5 cartouches par tir au lieu de 9 (F115) ;
  - `13_` (22:28:06,44) : 19 OK, 2 ECHEC : modèle « chargeur entamé » confirmé aux tailles 7, 13, 19, 25 et 30 ;
  - `14_` (22:30:17,34) : 21 OK, 0 ECHEC : cartouches arrondies au chargeur, mesurées exactement ;
  - `15_` (22:31:13,87) : 21 OK (contrôle de la voie de tapis resserré) ;
  - `23_` (22:38:32,19), sur le commit exact `2b18742` : **21 OK, 0 ECHEC**.
- Résultats : F3 CONFIRMÉ (assembleur : 60,00 engrenages/s pour 115,5 demandés, `speed_bonus` lu 4,80), F115 à F118.
- Règle livrée par la branche (NOTES §9.2) : statistique(n) = v1 × m(n) × R(n), avec R(n) = (côté(n)/côté(1))². Suivent R :
  vitesse, minage, dégâts par tir, énergie, pollution, énergie par tir, tampon et débit d'entrée du laser, cartouches
  par tir de la mitrailleuse (arrondies au chargeur de 10 : 1 ; 2,5 ; 3,33 ; 5 ; 10). Ne suivent pas R : PV, portée,
  cadence, rotation, emplacements de modules. Production par tuile strictement croissante (× 3,32 au niveau 30 ; foreuse
  × 3,9) ; par bâtiment au niveau 30 : four × 29,9, assembleur × 13,3, foreuse × 15,6 ; dégâts de mitrailleuse × 19,08.
- Coûts et calendrier (`levels_test`, hors jeu ; `--calibrate` relancé) :
  - gain moyen G aux transitions (époques 1 à 3 : 1 ; 4 : 25/18 ; 5-6 : 16/9 ; 7 : 41/18 ; 8-9 : 25/9 ; 10 : 61/18 ;
    11 à 15 : 4), appliqué au débit et au budget X0 ; les familles de production paient en plus leur gain ;
  - `value_mult` des époques 2 à 15 : 1,5 ; 2,5 ; 8,44 ; 26,7 ; 45,7 ; 84,4 ; 188 ; 331 ; 562 ; 1 220 ; 2 200 ; 3 970 ;
    7 240 ; 12 200 (0.4.3 : 1,43 à 7 070) ; `cc_value` de l'époque 3 : 1 410 ;
  - coût du niveau 30, 0.4.3 → branche : foreuse 61 587 → 367 087 u ; four 53 582 → 367 082 u ; assembleur 61 602 →
    367 102 u ; mitrailleuse 104 578 → 183 578 u ; laser 175 710 → 304 210 u ; mur 17 532 → 30 032 u ;
  - calendrier = MODÈLE conditionnel à G, qui ne vaut que pour la dépense de niveaux : Porte à 59 h 30 ; production
    × 0,7 : 85 h 00 ; × 1,3 : 45 h 46 ; gain gardé en place : 192 h 05 ; recherche et jalon X0 non multipliés par G :
    34 h 11 ; chemin le plus court vers le centre 15 : 5 h 01 (centre seul : 2 h 23).
- **Pourquoi le lot n'est PAS intégré (Q-T4-1, OBJECTIFS §4)** : la DENSITÉ est tenue, la RENTABILITÉ ne l'est pas. La
  moitié « améliorer reste toujours rentable » de la réponse A manque : passer la foreuse du niveau 29 au niveau 30 se
  rembourse en 510 h de sa valeur ajoutée (0.4.3 : 342 h) ; 16 améliorations sur 29 se remboursent au-delà de la durée
  de leur époque (0.4.3 : 16 aussi), jusqu'à 73 fois cette durée ; four et assembleur : valeur ajoutée en matière NULLE (remboursement brut
  29 → 30 : 227 h et 106 h ; 0.4.3 : 298 h et 71 h). Options du correcteur : (a) une pente bien plus forte (+ 7,28 de
  multiplicateur par niveau au lieu de + 0,10) ; (b) des coûts calés sur le gain (foreuse 30 à 5 040 u au lieu de
  367 087, soit × 0,014 ; le calendrier ne tient plus). Posée dans le chat vers 22 h 45 ; recommandation de
  l'orchestrateur : A (vrai idle) ; le jeu garde l'équilibre de 0.4.3 en attendant.
- Écarts connus de la branche : 11 sur `main` → **23** (12 nouveaux) : 2 000 objets d'une sorte (2 980) ; × 16 par
  bâtiment (6 statistiques) ; Q14 mitrailleuse et Q14 laser (× 8,5 par tourelle ; par tuile × 2,12 et × 2,39 : la
  tourelle lourde du mod est un 3×3, le « 0,94 par tuile » de l'ingénieur était FAUX) ; assembleur ≤ 2 × la machine 3 ;
  centre 13 (3 coûts sur 6 dans le coffre) ; coûts sous 0.4.3 (6 baisses : foreuse niveaux 4, 5, 6 : 38 → 33, 47 → 38,
  50 → 46 ; assembleur : 41 → 36, 50 → 41, 55 → 51) ; améliorations en lot (2 coûts d'un même niveau dans le coffre au
  plus bas, contre 10 à 12 en 0.4.3 ; 39 niveaux sous 6) ; rentabilité (16 sur 29 ; 0.4.3 : 16 aussi, donc pas une aggravation par rapport au jeu livré) ; plafond par tick de l'assembleur
  avec modules ; voie unique de la foreuse ; PV par tuile (× 0,51 pour la mitrailleuse, le laser et le four au niveau
  30). QX10 à l'époque 4, ajouté par l'ingénieur, est résolu par le gain moyen (5,36 %). Aucun écart masqué.
- Bancs sur le worktree (`2b18742`) :
  - hors jeu (22 h 33 à 22 h 36) : run 114, war 92, td 270, pteam 15, migration 81, levels **1 615** (+ 23 écarts
    connus), pvp 596, epochs 16 665, org 362, harness 0 erreur nouvelle / 0 violation / 0 clé manquante (11/11),
    api_lint **558**, d4m 5/5, mut_atlas 40, mut_vram 18/18, test_ht3_journal 15, bat_double_source 4 ;
  - moteur réel (passages `16_` à `22_`, 22:37:11,09 à 22:37:47,01) : content **331** (317 + `levels_production` 14),
    t2-machines 80, bord-a-bord 12, t2-migration 64 + journal 26, ht3-migration 30 + journal 7, t2-defense 36 + 19
    (création 0.4.1) et 36 + 11 (0.4.2) ;
  - mutants (script jetable `t4_mutants.py`) : 6 sur 7 tués ; la marge de 0,01 % des cartouches survit.
- Pour une intégration éventuelle : la branche part de `e27bda9`, AVANT V3-T3 ; elle touche des fichiers partagés
  (`shared/levels/config.lua`, `tests/datastage/harness.lua`) ; conflit attendu avec V3-T3 dans `tests/levels_test.lua`
  (seul fichier modifié des deux côtés, vérifié par `git merge-tree`). Après la fusion : relancer `lua5.2 tests/levels_test.lua --calibrate` (la sortie doit égaler la
  config), renuméroter les identifiants cités (F111 à F118, E60 à E62), rejouer tous les bancs. À transmettre au lot
  propriétaire de X0 : `X.TECH_UNITS` et `X.milestone_production` × gain, sinon le calendrier réel raccourcit (34 h).
- Non prouvé : l'hypothèse G (le joueur convertit le gain en débit ; `value_mult` provisoires jusqu'à un banc ou une
  partie d'usine réelle, bras et tapis compris) ; la pollution totale × G et son effet sur l'évolution et les
  attaques ; défense de tours, guerre et PvP face aux tourelles à niveaux du joueur (vagues ni rejouées ni
  recalibrées) ; la branche « 1/(2 − x) » de la résistance ; balises, modules de productivité, assembleur à fluide de
  haut niveau ; le panneau avec les nouvelles valeurs (aucune capture) ; le ressenti « idle massif » ; la cause de F111
  (H-T4-1). Le critère « remboursement dans la durée de l'époque » est une PROPOSITION du correcteur, pas une décision
  du Directeur Créatif.

**E61 · VALIDÉ en moteur réel (machine seule, nourrie par script) · Production réelle des bâtiments agrandis (lot V3-T4,
ingénieur, 22/10 ; numéro provisoire E57)** :
- Protocole : scénario greffé `t4-production` et greffon `checks/levels_production.lua` (version `37c9c3f`) : 12
  machines (four, assembleur, foreuse aux niveaux 1, 6, 7 et 30) et 4 tourelles, nourries par script, production
  mesurée sur 40 s (fenêtre des ticks 300 à 2 700) ; pollution par objet lue dans les statistiques du jeu.
- Résultats : écart à la théorie du prototype < 0,03 % (F113) ; pollution par objet = celle de la courbe d'avant
  (F114). Passages : `03_t4-production` (21:41:40,35) 13 OK, 0 ECHEC ; `04_content` (21:41:52,33) 329 OK (317 + 12 de
  `levels_production`) ; `05_` à `10_` (21:42:08,09 à 21:48:10,04) : t2-machines 80, t2-migration 64 + 26, ht3-migration
  30 + 7, t2-defense 36 + 19 et 36 + 11, bord-a-bord 12. Hors jeu (vers 21 h 45) : levels 1 610 (+ 12 écarts connus),
  api_lint 551, le reste inchangé.
- Limite : machine SEULE ; la production d'une usine réelle (bras, tapis, balises) n'est pas mesurée. Constaté au
  passage : un bras simple (0,83 objet/s) ne suffit plus dès le niveau 7 (four 7 affamé dans `levels_points` au
  premier passage, bras rapide posé). Plusieurs chiffres de l'ingénieur ont été corrigés ensuite (E62).

**E60 · VALIDÉ en moteur réel ; règle changée · Cadence des tourelles agrandies (lot V3-T4, ingénieur, version
`f86f2fb`, 22/10 ; numéro provisoire E56)** :
- Protocole : greffon `levels_production`, scénario `t4-production` (2 800 ticks, fenêtre 300-2 700) ; mitrailleuses
  aux niveaux 1, 7, 13, 19, 25 et 30, R porté par la CADENCE (délai divisé par R), cible soignée à chaque tick,
  cartouches comptées.
- Résultats : `01_content_premier` (21:36:09,78) 326 OK, 3 ECHEC (cadence plafonnée ; four 7 affamé) ;
  `02_t4-production_cadence_E56` (21:37:45,84) 11 OK, 2 ECHEC : la cadence × 9 ne donne que × 3 (F111) ; le laser à
  4,44 ticks superpose ses faisceaux (F112, version non livrée).
- Décision de l'ingénieur (`37c9c3f`) : les DÉGÂTS par tir portent R, la cadence ne change pas. Écart assumé par lui,
  repris comme question par le correcteur : contre des essaims de très faibles ennemis, la grande vaut moins que les
  petites ; contre des blindés à résistance fixe, bien plus (F118).

**E59 · VALIDÉ en moteur réel ; limite des rangées collées DÉCLARÉE, non résolue · « Libérer la place » corrigé : tout
ou rien, Annuler qui remet l'usine comme avant, vrais robots (lot V3-T3, correcteur, 22/10, à partir de 22 h 15 ;
commit `d0b40da` à 22 h 48 ; intégré dans `main` le 22/10 par la fusion `8a28804`, version 0.4.4)** :
- But : corriger les 24 défauts relevés par la revue adverse à 3 regards sur la version de l'ingénieur (E57), dont 2
  bloquants : un plan PARTIEL était exécuté (usine laissée cassée), et « Annuler » n'était pas sûr. Verdict de la revue
  sur E57 : « NON VALIDABLE en l'état ». 23 défauts confirmés et traités, 1 réfuté (défaut 8, `info.json` 0.4.4 : la
  tâche le demandait).
- Conception corrigée (détail : `NOTES_V3T3.md` §5.1 ; ARCHITECTURE §7 bis, « Libérer la place ») :
  - tout ou rien au niveau de la DEMANDE : un plan n'est exécuté que s'il est COMPLET ; sinon refus, rien de marqué,
    gêneurs entourés de VIOLET et listés avec leur position `[gps]` ; `C.choose` essaie la candidate du contour, puis les
    autres ; une marque ou un fantôme refusé par le moteur retire tout (motif `engine-refused`) ;
  - condition Q16 et coût réunis AU CLIC (seul le motif « no-room » ouvre le bouton) ; le coût peut encore être dépensé
    entre le clic et la libération (message, la demande attend, puis expire) ;
  - relevé = critère de `Levels.room` (`Levels.blocks`, `Levels.mask_layers`) ; carrés et gêneurs RÉSERVÉS entre
    demandes voisines ; réglages recopiés (`copy_settings`, F107) ; « Annuler », l'expiration (30 min) ou le bâtiment
    disparu remettent l'usine comme avant (étapes a à f de `free.lua`, marques annulées en dernier : F103) ; crochet
    `Levels.pending_box` (le bouton « Améliorer » et la touche U ne visent que le carré libéré) ; zone d'alimentation
    d'un poteau décalé vérifiée (poteaux cherchés jusqu'à 12 tuiles, contrôle prudent) ; aucun ordre de `pairs`.
- Protocole (moteur réel) : scénario greffé `t3-libere` (1 900 ticks ; `check_tick` 1 800 à cause des vrais robots) ;
  forces `fo-t3` (centre 15 qui paie), `fo-t3p` (centre vide d'abord), `fo-t3r` (robots réels) ; zones A, B1, B2, C1,
  C2, D, E, F, G, R, V et L (en-tête du scénario ; `tools/autotest/README.md` §4.1). Le banc joue les robots (il MINE les
  entités marquées dans un inventaire, puis construit les fantômes) sauf en R, où de vrais robots travaillent.
  `t3-migration` en double source (`src-0.4.2`, 1 000 ticks). En plus, `t2-migration` et `t2-defense` journalisent
  « LIBERER LA PLACE (plan seul, hors bilan) » pour chaque bâtiment laissé.
- Résultats (correcteur, `passe1-*`, 22:45:34 à 22:46:07 ; identiques sur `main`) : **`t3-libere` 41 OK, 0 ECHEC** (27
  dans E57) :
  - A : le bras de sortie, FILTRANT, garde son filtre sur le fantôme puis sur le bras reconstruit ; 9 fabrications,
    + 17 engrenages au coffre ;
  - C2 : bras démonté, puis Annuler : 3 marques annulées, 6 fantômes retirés, 1 fantôme posé à l'origine ; le banc le
    reconstruit, la machine refabrique (9 fois) ;
  - E : clic refusé « no-resources » sans le coût, accepté avec ; coût retiré : message au tick 420 ; coût revenu : la
    mitrailleuse grandit ;
  - F : assembleur serré entre deux voisins : refus « blocked » après 4 candidates essayées, rien de marqué, la machine
    fabrique toujours ;
  - G : deux voisins libérés l'un après l'autre : carrés disjoints (351-355 et 347-351), aucun fantôme dans le carré de
    l'autre ; les deux grandissent et fabriquent (10 et 9 fois, + 16 au coffre) ;
  - R, VRAIS robots (20 robots, roboport, stockage) : démontage fini au tick 390, agrandissement à la vérification de
    450, 6 fantômes construits par les robots au tick 930, puis 9 fabrications et + 15 au coffre (F110) ;
  - V : une voiture dans la candidate sud-est du contour : ni ignorée ni marquée ; la candidate nord-est (murs) est
    retenue, puis Annuler rend tout ;
  - B2 : les 2 murs de liaison (murs de BASE) sont dits au joueur ; D (sans clic) : rien ne change jusqu'au bilan ;
  - aucune entité détruite par le mod ; 0 renversé, 0 secours, 0 demande restante au bilan.
  `t3-migration` : 7 OK, 0 ECHEC (l'assembleur laissé hors grille par la vraie migration est remis sur la grille au
  niveau 9 après la libération ; l'usine remarche).
- **Limite déclarée, non résolue (défaut 13 de la revue) : les rangées collées.** Le bouton ne libère qu'un bâtiment
  qui a un côté libre ; au milieu d'une rangée jointive, un voisin gêne toujours. Plan seul sur les bâtiments laissés
  par les vraies migrations (journal, hors bilan) : `t2-migration` **5 libérables sur 19** (centre 6 ; assembleurs 1
  et 6, fours 1 et 6 : les BOUTS de rangée ; les 14 autres touchent un voisin) ; `t2-defense` création 0.4.1 **2 sur
  13** (A1 et A8, bouts de tronçon ; 5 tourelles de C non évaluables, « no-cc » : la force n'a pas de centre pour
  elles) ; création 0.4.2 **0 sur 5**. Le bouton ne règle donc pas les dispositions qui ont motivé Q-T2-1 (E50, E54).
  Question à poser au Directeur Créatif (proposée par le correcteur) : déplacer aussi les voisins en cascade, agrandir
  une rangée entière d'un coup, ou accepter la limite.
- Hors jeu : sur le worktree (22 h 40 à 22 h 50) run 114, war 92, td 270, pteam 15, migration 82, levels **1 642** (+ 11
  écarts connus ; 1 622 avant correction : 64 contrôles du lot, 41 cas purs et 23 en moteur simulé), pvp 596, epochs
  16 665, org 362, harness 0/0/0 (11/11), **api_lint 615** (8 membres ajoutés), d4m 5/5, mut_atlas 40, mut_vram 18/18,
  test_ht3_journal 15, bat_double_source 4. Mutants hors jeu sur le code corrigé (copie restaurée à l'identique,
  `cmp`) : 9 sur 9 détectés.
- Sur `main` après la fusion `8a28804` (version 0.4.4 ; changelog 0.4.4 commité ensuite, `4a7a365`) :
  - moteur réel (archives `<racine>\fo-logs\2026-10-22_V3T3-integration\`, code 0) : content **317** (22:50:45,71),
    t2-machines 80 (22:50:50,22), bord-a-bord 12 (22:50:54,07), **t3-libere 41 OK** (22:50:58,19), t2-migration 64 +
    journal 26 (22:51:06,58), ht3-migration 30 + journal 7 (22:51:10,76), t2-defense 36 + 19 (création 0.4.1,
    22:51:15,21) et 36 + 11 (0.4.2, 22:51:19,45), **t3-migration 7 OK** (22:51:53,59). Un premier passage de
    `t3-migration` à 700 ticks (22:51:02,43) était trop court, sans BILAN (`NOTE.txt`) : le banc demande 1 000 ticks ;
  - hors jeu (de 22 h 50 environ à 22 h 55, fin de la sortie à 22:55:17) : run 114, war 92, td 270, pteam 15,
    migration 82, levels 1 642 (+ 11), epochs 16 665, org 362, pvp 596 (195 s), harness 0/0/0 (11/11), **api_lint 609** usages, 0 erreur, d4m 5/5, mut_atlas 40, mut_vram 18/18,
    test_ht3_journal 15, bat_double_source 4. **Écart non expliqué, noté tel quel** : le correcteur annonçait 615
    usages dans son worktree, `main` en compte 609 ; la cause n'a pas été cherchée.
- Captures (`<racine>\fo-logs\2026-10-22_V3T3\correcteur\captures-t3-libere\`, `fo-captures.bat t3-libere`, 4 images
  prises après le bilan, `shots_delay` = 1 840) : `001-usine-dense-apres` (assembleur 4×4, bras filtrant reposé une
  tuile au sud, bosse traversée par les engrenages, poteau décalé et relié) ; `002-robots-apres` (zone R après les
  vrais robots) ; `003-liberee-avant-robots` (carré orange, gêneurs en jaune, places des fantômes en bleu clair ; l'icône
  rouge du moteur ne se voit pas à ce zoom ; les rectangles du bras et du poteau sont petits) ; `004-refus-voisins-violet`
  (F refusé, voisin en violet). `t3-migration` n'a pas été recapturé. Aucun verdict du Directeur Créatif.
- Non prouvé : le panneau et ses boutons avec un VRAI joueur, y compris un jeu entièrement à la main (minage puis
  pose) ; l'expiration (30 min) et le bâtiment disparu (moteur simulé seulement ; même code qu'Annuler, prouvé par C2) ;
  la place d'origine prise à l'annulation (`free-restore-blocked`, jamais rencontrée) ; la fusion de deux réseaux
  électriques par le raccord automatique d'un poteau reposé (non traitée) ; ligne raccourcie, coffre qui suit un bras ou
  le dépôt d'une foreuse, arbres et rochers, falaise, autre force, eau DANS la candidate (cas purs ou moteur simulé) ;
  foreuses, fours, lasers et centre (aucun cas propre en moteur réel) ; coût bloqué au clic (non fait) ; fils de
  circuit des gêneurs reposés (NON refaits : message `free-wired`, non joué) ; coût en temps (H-L1, non mesuré) ; les
  usines réelles du Directeur Créatif (jamais jouées) ; le visuel (aucun verdict).

**E58 · VALIDÉ en moteur réel (essai jetable) · Réglages des fantômes et vrais robots (lot V3-T3, correcteur, 22/10 à
22 h 19)** :
- Protocole : scénario jetable `<racine>\fo-logs\2026-10-22_V3T3\correcteur\essai-E58\t3-essai2.lua`, retiré du
  dépôt : `copy_settings` d'un bras filtrant, d'un coffre de demande et d'un coffre à barre vers un `entity-ghost`, puis
  `revive` ; fantôme posé sur une entité non marquée ; numéro d'unité avant et après `revive` ; roboport, robots et
  coffre de stockage devant un convoyeur marqué qui porte un fantôme tourné.
- Résultats : F107 à F110. Conséquences dans le code : `copy_settings` et taille de pile posée à part ; `place_free` ;
  entités construites retrouvées par nom, position, direction et force ; zone R de `t3-libere` (E59).

**E57 · VALIDÉ en moteur réel, puis REMPLACÉ par E59 · Premier jet de « Libérer la place » (lot V3-T3, ingénieur
`f26e9c3`, 22/10, de 21 h 10 à 22 h 05)** :
- Protocole : scénarios greffés `t3-libere` (1 500 ticks ; zones A, B1, B2, C1, C2, D, E ; le banc mine les marques et
  construit les fantômes par script) et `t3-migration` (double source `src-0.4.2`, 1 000 ticks).
- Résultats (passage final, `done.txt` de 21:57:50 à 21:58:30) : `t3-libere` 27 OK, 0 ECHEC ; `t3-migration` 7 OK ;
  autres bancs verts (content 317, t2-machines 80, bord-a-bord 12, t2-migration 64 + 26, ht3-migration 30 + 7,
  t2-defense 36 + 19 et 36 + 11). Hors jeu : migration 82, levels 1 622 (+ 11), api_lint 599. F103 observé au tick 60
  (le premier passage comptait 4 fantômes retirés au lieu de 6).
- Ce que la revue adverse a trouvé ensuite (24 défauts) : plan partiel exécuté, Annuler qui gardait un groupe commencé
  (bras reconstruit décalé pour un bâtiment qui ne grandit plus), candidate pas forcément libérable, réglages perdus,
  gêneurs du relevé différents de `Levels.room`, vrais robots jamais observés, ordre de `pairs`, et l'« écart à la
  consigne : aucun connu » des notes, FAUX (rangées collées). Tout est corrigé ou déclaré dans E59. Captures de ce
  premier jet (3 + 1 images, avant les robots) : `<racine>\fo-logs\2026-10-22_V3T3\captures-final-t3-libere\` et
  `captures-final-t3-migration\` (les deux assembleurs 4×4 laissés hors grille se chevauchent : laid, non jugé).

**E56 · VALIDÉ en moteur réel (essai jetable) · Appels du moteur pour « libérer la place » (lot V3-T3, ingénieur,
22/10, avant le premier passage de `t3-libere`)** :
- Protocole : scénario jetable `<racine>\fo-logs\2026-10-22_V3T3\essai-E56\t3-essai.lua`, retiré du dépôt :
  `create_entity` et `teleport` d'un 4×4 vers une position hors grille ; `order_deconstruction`, fantôme posé
  par-dessus une entité marquée, `mine{inventory}`, `revive` ; `can_place_entity` d'un fantôme (`script_ghost`, avec
  ou sans `forced`) et du nom réel (`ghost_revive`) ; bosse d'une tuile dans une ligne de convoyeurs.
- Résultats : F104, F105 et F106. Conséquences : `t3-migration` en double source ; place des fantômes contrôlée par la
  règle pure ; règle de la BOSSE.

**E55 · VALIDÉ (hors jeu) · Atlas virtuel compté par `vram.py` (lot R1, suite vram, 22/10 ; constructeur `dac93fd`
de 19 h 38 à 19 h 49, revue adverse, correcteur `75863a5` de 19 h 53 à 20 h 00 ; intégrée dans `main` le 22/10 par la
fusion `58db82c`)** :
- But : la tâche d'outillage ouverte depuis F81 (l'estimation du plancher d'E40 laissait l'atlas virtuel de côté).
- Protocole :
  - règle écrite en tête de `tools/autotest/vram.py` : pages comptées comme résidentes en mémoire vidéo et
    compressées comme un atlas « [none] » sous la DXT du journal ; bas = pages × octets/px bas, sans mipmaps ;
    haut = (pages + max(pages, atlas virtuel annoncé)/3) × octets/px haut ; variante RGBA 8888 (pages × 4) NON
    comptée, confrontée à la mesure directe (exclue si atlas bas + variante > pic dédié + pic partagé) ; chiffres du
    moteur (« Atlas memory size », « Size of sprites outside of atlas ») rapportés tels quels s'ils apparaissent ;
    ligne au singulier signalée, non comptée ; lignes ancrées sur l'horodatage du moteur ;
  - `unit_vram.py` sur les 33 lignes réelles du plancher (lignes 30 et 49 à 80 de
    `fo-logs\2026-10-22_D4m_5-plancher-mesure\visual.log` ; égalité vérifiée par script, chaînes identiques) ;
  - `table13.py` compare l'ancienne et la nouvelle estimation sur les 13 journaux archivés ;
  - `tools/autotest/tests/mut_vram.py` (versionné dans le dépôt) : un témoin nul, puis 18 mutants de `vram.py`.
- Résultats (correcteur, `75863a5`) :
  - unitaires de `vram.py` 99 OK (57 avant la suite, 96 au constructeur) ; `run_d4m.py` 5/5 (essai à blanc 11 OK,
    greffon 16 OK, intégration 17 OK, 13 journaux) ; `mut_atlas.py` 40 OK ; `mut_vram.py` : témoin nul survivant
    (99 OK), 18/18 mutants détectés, tous par un contrôle, 0 survivant, 0 motif introuvable, code 0 ;
  - 12 journaux inchangés (1,10 à 1,25 Go en haute qualité ; 0,40 à 0,45 Go en normale) ; plancher (D4m 5) :
    **0,2794 à 0,5270 Go** (atlas 0,2039 à 0,3089 + pages 0,0755 à 0,2181), contre 0,20 à 0,31 Go avant et un pic
    dédié mesuré de 0,42 Go ; variante non compressée 0,2039 + 0,6040 = 0,81 Go, au-dessus des 0,52 Go du pic dédié
    + partagé (0,42 + 0,10) : EXCLUE si les pages sont allouées en entier ;
  - archives non modifiées : SHA-256 de 793 fichiers identiques avant et après les bancs (les 43 dossiers de
    `fo-logs` qui contiennent un `visual.log`).
- Revue adverse : 1 défaut majeur et 3 mineurs, tous CONFIRMÉS puis corrigés.
  - Majeur : le banc de mutations du constructeur ne prouvait rien. Il ne copiait que `vram.py` et
    `visual_session.py` dans le dossier du mutant ; or `visual_session.py` importe `gallery`. Rejoué par le
    correcteur (`verif_ancien.py`) : une copie intacte sans `gallery.py` donne « ModuleNotFoundError: No module named
    'gallery' » ; avec une copie complète, 13 mutants sur 14 seulement sont détectés (« chiffre moteur sans ancrage »
    SURVIT ; « catégorie virtuelle absente » n'est détecté que par un plantage, KeyError). **Le « 14/14 » annoncé
    par le constructeur était FAUX : 13/14.** Correction : `mut_vram.py` dans le dépôt, qui copie TOUS les modules,
    exige un témoin nul survivant, distingue un refus par contrôle d'un plantage, et échoue sur un motif
    introuvable ; 18 mutants (les 14 d'origine et 4 nouveaux).
  - Mineurs : deux ancrages non testés (ligne au singulier, « Size of sprites outside of atlas ») et verdict D4-1 sur
    les atlas seuls : les 3 mutants du relecteur survivaient à l'ancien `unit_vram.py` ; fixture du plancher à 30
    lignes sur 33 (3 lignes du moteur manquaient) ; l'identifiant provisoire E53 du constructeur (aujourd'hui E55)
    désignait deux choses à la fois.
- Confrontation entre sessions (point 3 de l'expérience, NON automatisée) : en qualité normale (D4m 4, même fenêtre
  1920x1080), il reste 0,22 à 0,27 Go hors atlas ; au plancher, le pic dédié de 0,42 Go moins l'estimation basse
  comptée (0,28 Go) laisse au plus 0,14 Go hors atlas. Trois explications possibles : le reste hors atlas baisse au
  plancher (le pic partagé passe de 0,44 à 0,10 Go), les pages sont plus compressées que prévu, ou elles sont
  allouées en partie. Rien ne tranche.
- Preuves : `<racine>\fo-logs\2026-10-22_R1\vram\` (`NOTES.md`, `table13.txt`, `d4m-apres.txt` ; `mut_vram.py` et
  `mutations-vram.txt` du constructeur gardés comme trace, INVALIDES) et son sous-dossier `correcteur\`
  (`mutations-vram-correcteur.txt`, `ancien-banc-rejoue.txt`, `table13-correcteur.txt`, `sha256-archives.txt`). Sur
  `main` (22/10, vers 20 h 15) : d4m 5/5, mut_atlas 40 OK, mut_vram « témoin nul survivant ; 18/18 mutants
  détectés ».
- Limites (non prouvé) :
  - que les pages résident en mémoire vidéo, et leur format (compression selon la DXT du journal : hypothèse ; option
    `compress-virtual-atlas`, valeur par défaut inconnue) ; la variante RGBA 8888 n'est exclue que si les pages sont
    allouées en entier ;
  - l'emplacement et le nombre des niveaux de mipmaps : la borne d'un tiers est un majorant géométrique ;
  - l'estimation haute du plancher (0,53 Go) dépasse le pic dédié mesuré (0,42 Go) : elle surestime cette session
    (le rapport écrit « écart NÉGATIF ») ;
  - la ligne au singulier et les chiffres « Atlas memory size » et « Size of sprites outside of atlas » ne sont
    éprouvés que sur des lignes synthétiques ; les « MB » du jeu sont supposés valoir 2^20 octets ;
  - un seul journal contient un atlas virtuel : aucun autre réglage n'étalonne la règle ;
  - `mut_vram.py` ne prouve que la sensibilité de `unit_vram.py` aux 18 mutants écrits ;
  - aucun banc en moteur réel, aucune mesure de performance (le lot V3-E rendait dans Blender) ;
  - pour trancher la résidence et le format : une session au plancher avec `compress-virtual-atlas` ou
    `streamed-atlas-physical-vram-size` fixés dans le `config.ini` de TEST (option à câbler dans
    `visual_session.py`) ;
  - observation hors périmètre, non corrigée : `python vram.py --help` plante déjà sur `98ac826` (UnicodeEncodeError
    cp1252 sur « ≈ » de la docstring) quand la sortie est redirigée.
- Incident du correcteur, signalé au Directeur Créatif : un nettoyage `rm -f <dossier temporaire de session>/*.txt` a
  visé le dossier temporaire de la session `8a9c0503`, que d'autres agents partagent ; des fichiers `.txt` d'autres
  agents ont pu y être effacés (liste inconnue). Rien n'a été effacé dans `fo-logs` ni dans le dépôt (SHA-256 des
  archives identiques).

**E54 · VALIDÉ en moteur réel pour le fonctionnement ; visuel laid et NON jugé · Migration d'une défense dense (lot R1,
suite « défense dense et bord à bord », 22/10 ; constructeur `e74871d` de 19 h 38 à 19 h 58, revue adverse,
correcteur `f41753d` de 20 h 03 à 20 h 10 ; intégrée dans `main` le 22/10 par la fusion `dcc97b3`)** :
- But : la tâche ouverte « jouer une défense dense » (OBJECTIFS §7, Q-T3) : les essais précédents avaient joué une
  usine dense (E50) et des défenses ISOLÉES (E46), jamais une vraie ligne de défense.
- Protocole : scénario greffé `t2-defense` (`tools/autotest/fo-autotest/scenarios/t2-defense.lua`), double source
  (`FO_CREATE_SRC` = `<racine>\fo-logs\2026-10-22_V3T-suites\ht3\src-0.4.1`, version 0.4.1 où rien ne grandit, ou
  `<racine>\fo-logs\2026-10-22_V3T2\src-0.4.2`, version 0.4.2 où seule la mitrailleuse grandit), benchmark par 0.4.3,
  1 200 ticks ; journal contrôlé hors jeu par `ht3_journal.py --tag FO-T2-DEFENSE`. La carte (force `fo-def`) :
  - un mur de niveau 7 continu de deux rangées ; 21 tourelles (11 mitrailleuses, 10 lasers) alignées par l'arrière,
    en trois tronçons : A compact (M7 L7 M7 L7 M8 L8 M8 L8, jointives), C haut niveau compact (M13 L13 M25 L25 M13), B
    aéré (les 8 de A, une colonne libre avant chacune, une rangée libre devant la plus profonde) ;
  - un bras électrique par mitrailleuse (prend sur le convoyeur, dépose dans la tourelle), un convoyeur de munitions
    perforantes par tronçon (tête regarnie par script pendant le benchmark : amont simulé), 24 poteaux moyens et une
    interface électrique vanilla : un VRAI réseau ;
  - mitrailleuses VIDES à la création (sauvegarde au tick 0) : toute munition trouvée après la migration est arrivée
    par le bras ; victimes, dégâts et PV entamés posés sur chaque tourelle ;
  - classement au tick 90, munitions au tick 170, trois vagues de 21 biters moyens (ticks 200, 380 et 560, posés à
    9 tuiles du mur), contrôles au tick 1 100.
- Résultats (identiques chez le constructeur, le correcteur et sur `main`) :

  | Création | Reposées | Laissées | Même taille | Chevauchements vus des tourelles | Ligne du mod | BILAN | Journal |
  |---|---|---|---|---|---|---|---|
  | 0.4.1 | 8 (tout B : 4 mitrailleuses, 4 lasers) | **13 (tout A, tout C)** | 0 | 36 murs, 12 convoyeurs, 11 poteaux, 6 bras, 28 tourelles | « 8 bâtiment(s) reposé(s), 0 déjà en place, 13 laissé(s) » | 36 OK, 0 ECHEC | 19 OK |
  | 0.4.2 | 5 (B : 4 lasers ; A : le dernier laser) | 5 (3 lasers de A, 2 de C) | 11 (les mitrailleuses) | 6 convoyeurs, 2 poteaux, 1 bras, 8 tourelles | « 5, 0, 5 » | 36 OK, 0 ECHEC | 11 OK |

  Répartition des chevauchements (paires vues depuis chaque tourelle, d'où des doublons : un mur touché par deux
  tourelles compte deux fois) : en création 0.4.1, toutes les paires avec un mur, un convoyeur, un poteau ou un bras
  viennent des 5 tourelles de C ; les 8 de A, hors grille, ne chevauchent que leurs voisines. En création 0.4.2, les
  3 lasers laissés de A ne chevauchent rien ; les 2 de C chevauchent leurs voisines et un poteau chacun, le laser 25
  aussi le convoyeur (6 tuiles) et un bras ; aucun mur n'est chevauché.

  Dans les deux cas : chaque mitrailleuse est nourrie après la migration par SON bras (`drop_target` = la tourelle ;
  F100), les 10 lasers sont sur le réseau des poteaux et chargés (F101), les **21 tourelles sur 21 ont tiré** (dégâts
  infligés depuis la migration, sommés sur les 21 tourelles : 5 014 en création 0.4.1, 4 978 en 0.4.2 ; ceux posés
  à la création, 100 × k par tourelle, ne sont pas comptés), **63 biters tués sur 63**, mitrailleuses à 10 munitions après le
  combat, mur intact (150/150 et 182/182 murs), rien renversé, 0 échec de remplacement, 0 placement forcé, filet sans
  effet jusqu'au tick 1 100. Les tourelles laissées fonctionnent (F99).
- Passages : constructeur (`e74871d`) 19:54:07 (0.4.1) et 19:54:12 (0.4.2) ; correcteur (`f41753d`) 20:08:34 et
  20:08:39 ; `main` (fusions `dcc97b3` et `58db82c`) **20:11:36,19 : 36 OK + journal 19 OK** et **20:11:40,52 : 36 OK +
  journal 11 OK**, code 0.
- Premier essai raté par un défaut DU BANC (création 0.4.2, `t2-defense-0.4.2-essai1`, 34 OK, 2 ECHEC) : un seul bras
  nourricier (0,83 objet/s) pour 11 mitrailleuses (5 à sec) ; une vague de grands biters non finie en 340 ticks
  (20 vivants). Corrigé dans le banc (tête de convoyeur regarnie, 3 vagues de biters moyens, contrôle au tick 1 100).
  Aucun défaut du mod trouvé par la défense dense.
- Captures (`captures-t2-defense-0.4.1`, constructeur, 22/10 à 19 h 55, `fo-captures.bat t2-defense`, création 0.4.1,
  2/2 images aux ticks 100 et 110), regardées par l'intégrateur des documents :
  - `001-defense-ouest.png` : tronçon A, tourelles 3×3 laissées dont les socles s'imbriquent, poteaux plantés
    au milieu (effet du dessin : aucune boîte de A ne touche un poteau) ; tronçon C, tourelles 4×4 et 6×6 dessinées PAR-DESSUS le mur (elles le masquent) et dont le socle
    recouvre une partie du convoyeur ;
  - `002-defense-est.png` : tronçon B, reposé sur la grille, ligne propre.
  **C'est laid** (sprites agrandis provisoires de V3-T2, superposés), et **non jugé** : seul le Directeur Créatif
  valide un visuel. Les captures précèdent le correcteur, qui n'a rien changé à la carte ni au classement.
- Revue adverse de la suite : 1 défaut majeur et 3 mineurs, tous CONFIRMÉS puis corrigés : F100 disait « 8
  mitrailleuses reposées » (4 en réalité) ; F100 disait « élargit F79 » (F89 le faisait déjà) ; l'en-tête de
  `bord-a-bord.lua` restait au présent après l'alignement (E53) ; `move_ground_items` ne refiltrait pas l'objet
  trouvé (corrigé dans le mod, E53).
- Réponse franche pour le Directeur Créatif (Q-T2-1) : sur une ligne de défense typique de 0.4.1 (tout jointif, collé
  au mur), 13 tourelles sur 21 sont laissées : les 8 du tronçon A, hors grille, se chevauchent entre elles ; les 5 du
  tronçon C chevauchent le mur, le convoyeur, les poteaux et les bras ; depuis 0.4.2, 5 lasers sur 10 sont laissés :
  3 hors grille sans chevauchement (A), 2 qui chevauchent convoyeur, poteaux, un bras et leurs voisines (C), aucun
  mur ; la défense MARCHE dans tous les cas (nourrie, alimentée, elle tire et tue). [Corrigé le 22/10 par la revue
  des documents : la première version étendait aux 13 tourelles le chevauchement du mur, des bras, des poteaux et du
  convoyeur, qui ne concerne que le tronçon C.]
- Limites (non prouvé) :
  - l'aspect de la ligne migrée (captures ci-dessus, sans verdict) ;
  - sélection, minage et remplacement par le JOUEUR d'une tourelle laissée qui chevauche un mur, un convoyeur ou un
    poteau ; amélioration ultérieure d'une tourelle laissée ;
  - aucune sauvegarde du Directeur Créatif rejouée ; ligne synthétique (21 tourelles, une seule orientation, ni
    lance-flammes, ni tourelle lourde, ni mur à portes) ; amont du convoyeur simulé par script ;
  - vagues de biters moyens posés à 9 tuiles du mur : une vraie attaque (grands biters, cracheurs, expansion) n'est
    pas jouée ; création 0.4.0 et plus ancienne : non jouée ;
  - rechargement réel d'une carte déjà migrée : toujours non joué ;
  - aucune mesure de performance (le lot V3-E rendait dans Blender).

**E53 · VALIDÉ en moteur réel ; moteur simulé aligné ; défaut du mod trouvé et corrigé · Contact bord à bord des
recherches par zone (lot R1, suite « défense dense et bord à bord », 22/10, 19 h 48 à 20 h 11)** :
- But : la limite d'E47 (« le contact bord à bord de `find_entities_filtered{area}` en moteur réel n'est pas observé ;
  le moteur simulé l'exclut par choix »).
- Protocole : scénario greffé `bord-a-bord` (`tools/autotest/fo-autotest/scenarios/bord-a-bord.lua`, 60 ticks, cas
  joués au tick 5, contrôles au tick 30). Trois entités en force neutre, zone vidée : mur de pierre (± 0,29),
  mitrailleuse vanilla (± 0,7), tourelle laser 7 du mod (3×3, ± 1,2). Les zones sont bâties sur la boîte RENDUE
  (`bounding_box`). Par entité, 15 cas comparés à la règle du moteur simulé, soit **45 cas** : zone égale à la boîte,
  chevauchement de 1/256 et écart de 1/256 (témoins), contact par chacun des 4 bords et par 2 coins, zone nulle sur
  le bord et dedans, et 4 cas de rayon (distance exacte, 1/256 de moins, cercle qui touche la boîte sans contenir le
  centre, cercle centré 1/4 de tuile hors de la boîte, qui y entre jusqu'à 1/256 du centre sans le contenir) ; `find_entities_filtered` et `count_entities_filtered` chacun. La
  `position` seule (bord, coin, dedans) est journalisée, non comparée.
- Résultats :
  - premier passage (19:48:32,08, `bord-a-bord-essai1`) : **11 OK, 1 ECHEC : 21 écarts sur 45 cas**, tous des
    contacts exacts (4 bords, 2 coins, zone nulle sur le bord, pour chacune des 3 entités) RENDUS par le moteur réel
    et exclus par le moteur simulé (F96) ;
  - alignement : `touches_area` de `tests/mock_engine.lua` passe en **intervalles fermés** (contact par un bord ou un
    coin compris) ; `migration_test` 79 → 81 contrôles (le voisin bord à bord EST rendu, l'écart de 1/256 ne l'est pas,
    contact par un coin) ; contre-épreuve avec l'ancienne règle stricte : 79 OK, 2 ECHEC ;
  - second passage : **0 écart, 12 OK** (constructeur 19:53:55 ; correcteur 20:08:11 ; `main` 20:11:23,82) ;
  - `position` seule et rayon : F97 ; boîtes en virgule fixe : F98.
- Défaut du mod trouvé par la revue adverse et corrigé par le correcteur (`f41753d`) : les recherches par zone des
  niveaux refiltrent par chevauchement strict (`Foot.overlap` dans `Levels.room`, `remove_ghosts` et, depuis le
  correcteur de la suite, `move_ground_items`), `Points.inside`, écart explicite de `find_stacked`. Avant ce correctif,
  `move_ground_items` poussait, et comptait à tort, un objet au sol qui touchait seulement le bord du bâtiment, ou le
  journalisait « laissé sous » sans place libre (son test du rectangle portait sur la DESTINATION, jamais sur l'objet
  trouvé). Correctif d'une condition dans `script/levels/levels.lua` (`Foot.overlap` strict sur la `bounding_box` de
  l'objet, sur le modèle de `remove_ghosts`) ; 2 contrôles dans `tests/levels_test.lua` (objet de ± 0,25 posé
  exactement bord à bord, puis par un coin, sans position libre : ni poussé, ni compté, ni journalisé,
  `find_non_colliding_position` jamais appelé) : levels 1575 → **1577** ; contre-épreuve sans le correctif : 1576 OK,
  1 ECHEC (« appels 2 »). En moteur réel, `content` 317 OK : l'objet au sol de `levels_taille`, posé SOUS le bâtiment,
  est toujours sorti (« deplaces 1 »). Changelog 0.4.3 complété (`870f045`).
- Limites (non prouvé) :
  - le correctif de `move_ground_items` est prouvé hors jeu (2 contrôles, une contre-épreuve) ; en moteur réel, seule
    l'absence de régression l'est : aucun objet exactement bord à bord n'a été posé dans un banc en moteur réel ;
  - les balayages par secteurs jointifs de `pvp.lua`, `sites.lua` et `war.lua` (une entité sur la frontière comptée
    dans deux secteurs) n'ont pas été examinés ;
  - le moteur simulé ignore toujours le filtre `position` seule ;
  - F98 : troncature ou arrondi au plus proche, non tranché.

**E52 · VALIDÉ en moteur réel · Fabrications en cours à travers l'agrandissement et le remplacement rapide (lot
V3-T2, correcteur, 22/10, 18 h 46 à 18 h 59 ; rejoué sur `main` à 19 h 05)** :
- Protocole : greffon `checks/levels_points.lua` du banc `content` (4 000 ticks, zone 4 : x 732 à 860, y 240 à 336),
  actions au tick ACT = 1760, bilans de matière avant, juste après et au tick 3000 :
  - C : four 7 → 8 en pleine fusion et assembleur à moteurs 7 → 8 en pleine fabrication, par le remplacement rapide
    moteur (même taille) ; four 6 → 7 par script au tick ACT, puis 7 → 8 par le moteur au tick ACT + 1 ;
  - D : assembleur en « sortie pleine » (100 engrenages) agrandi 6 → 7 ; F84 rejoué (assembleur à l'arrêt, sans
    ingrédient, `crafting_progress` écrit à 0,25) ;
  - barre : centre 3 d'une force à part, barre rouge à 5 cases, agrandi 4×4 → 5×5.
- Résultats (`corr-final-content`, `done.txt` 18:59:09,74 ; identiques sur `main`, 19:05:39,98) :
  - F94 : four 0,896 → 0,896 juste après, 0,912 à ACT + 2, bilan de fer 200 / 200 / 200 ; assembleur 0,254 → 0,254,
    0,256 à ACT + 2, bilan d'acier 101 constant ; four 6 → 7 → 8 : bilan 200 constant, progression 0,858 à ACT + 1
    et à ACT + 2 ;
  - F93 : état 22, fabrication vraie, progression 1,000 ; bilan de fer 220 avant et au tick 3000 ;
  - F84 : `is_crafting()` false → true, progression relue 0,250 ; 1 engrenage au tick 3000, sans aucune plaque ;
  - F95 : barre 5 gardée, 80 → 96 cases ;
  - compteurs globaux sur `main` : 69 agrandissements, 4 progressions reposées, 0 en attente, 0 objet renversé,
    0 fluide perdu, 0 échec, 0 placement forcé.
- Limites (non prouvé) :
  - défauts 2 et 15 des relecteurs (seconde amélioration traitée avant le `on_tick` du mod, sur une machine déjà
    repartie) : plausibles, NON reproductibles sans joueur (le banc agit dans le `on_tick` de fo-autotest, après
    celui du mod). Corrigés dans les deux chemins et tenus en moteur simulé seulement (`migration_test`, mutations
    m10 et m11 tuées) ; en moteur réel, seul le chemin normal est joué (script au tick ACT, moteur à ACT + 1) ;
  - fluide rendu à sa température et compteur `fluid_lost` : aucune recette à fluide chaud jouée ;
  - migration 0.4.2 → 0.4.3 d'une machine EN fabrication : NON jouable avec ce banc (`--create` sauvegarde la carte
    au tick 0, aucune machine n'y fabrique) ; moteur simulé seulement (`migration_test` : ingrédients rendus,
    progression reposée au premier tick) ;
  - bonus de productivité (`bonus_progress`) et modules d'une machine en pleine fabrication : non joués.

**E51 · VALIDÉ en moteur réel après correction ; défaut majeur CONFIRMÉ par un témoin · Points de jeu servis selon
l'orientation (lot V3-T2, défauts 1 et 6 de la revue ; correcteur, 22/10, 18 h 40 à 18 h 59 ; rejoué sur `main` à
19 h 05)** :
- Origine : deux relecteurs sur trois. La règle de position (`shared/levels/footprint.lua`) ignore l'orientation ;
  les points de jeu sont écrits pour le nord et tournés par le moteur. Sur un côté pair, un point « au milieu »
  d'un bord est décalé d'une demi-tuile ; tourné de 180°, le décalage change de sens. Une foreuse tournée vers le
  sud ou l'ouest pouvait donc déposer à côté de son coffre après l'agrandissement, sans refus ni message, et un
  assembleur à fluide tourné de 180° perdre son tuyau. Démontré par calcul, jamais joué par l'ingénieur (F87 trop
  général).
- Correction : règle des points servis (`shared/levels/points.lua`, pur ; `Levels.served_points`) : une position
  qui ferait sortir un point servi de l'entité qui le sert n'est pas libre (ARCHITECTURE §7 bis).
- Protocole : greffon `checks/levels_points.lua` (banc `content`, 4 000 ticks), section A : 12 foreuses
  (4 orientations × passages 6 → 7, 12 → 13, 18 → 19, soit 3×3 → 4×4, 4×4 → 5×5, 5×5 → 6×6) qui déposent dans un
  coffre, et 12 assembleurs à fluide (mêmes orientations et passages) raccordés à un tuyau infini ; section B :
  foreuse tournée vers le sud dont la seule position qui garde le dépôt est murée, et assembleur cerné (voisins et
  bras) ; section X : expérience des remèdes au raccord (rien, `update_connections()` du nouveau ou du tuyau,
  téléport sur place de l'un ou de l'autre). **Témoin** : le même banc sur `git archive be0ee03` (code de
  l'ingénieur) plus le nouveau greffon.
- Résultats du témoin `be0ee03` (`temoin-be0ee03-points`, `done.txt` 18:51:25) : **308 OK, 9 ÉCHEC**. Sept échecs portent sur les défauts ci-dessous ; un est un artefact du témoin (« erreur Lua
  dans tick : No such function: factorio-overhaul.levels_bench_resume » : interface absente de `be0ee03`) ; le
  dernier est le contrôle des compteurs globaux (« aucun objet renverse, aucun fluide perdu, aucun echec, aucun
  placement force »), dont le journal ne détaille pas la cause :
  - 6 foreuses sur 12, toutes celles tournées vers le sud ou l'ouest, aux 3 passages, déposent à côté du coffre
    (+0 minerai) ;
  - 9 assembleurs tournés sur 9 reviennent au nord (F91) ;
  - 12 assembleurs sur 12 sont privés de leur tuyau (F90 ; 2 barils seulement, avec l'eau transférée) ;
  - la barre du coffre du centre est relue à 97, soit aucune limite (F95) ;
  - le refus attendu passe en « done ».
- Résultats après la correction (`e84ca84`, `corr-final-content` 18:59:09,74 : **317 OK, 0 ÉCHEC** ; `main`
  19:05:39,98 : 317 OK) :
  - même coffre pour les 12 foreuses (cible du moteur), minerai en hausse : +17 au passage 6, +23 au 12, +29 au 18 ;
  - même tuyau pour les 12 assembleurs (10 barils remplis chacun), orientation gardée ;
  - rangs retenus aux passages 6, 12 et 18 : nord 1, 3, 1 ; est 2, 1, 2 ; sud 4, 2, 4 ; ouest 3, 4, 3 ;
  - refus de la foreuse sud : « no-room », contour au rang 3 (nord-est), gêne « point:iron-chest », rien payé ;
    assembleur cerné : « no-room », gênes fo-lvl-assembler-6 et inserter ;
  - raccords : avant la correction, seul un téléport sur place les refaisait ; après, « rien » suffit, puisque le
    mod téléporte lui-même.
- Hors jeu : `levels_test` (24 cas purs : 12 déplacés avec l'ancienne règle, 0 avec la nouvelle ; règle inversible,
  virgule fixe comprise (F92) ; deux raccords opposés : refus ; équivalence des convoyeurs ; foreuse tournée vers le
  sud en moteur simulé ; refus « point:iron-chest » et ligne du panneau ; clés FR et EN). Mutations tuées hors jeu :
  m14 (points servis ignorés), m18 (tolérance de virgule fixe), m19 (équivalence des convoyeurs). Survivent hors jeu,
  faute de barre, de boîte à fluide et d'orientation dans le moteur simulé : m15 (barre), m16 (téléport des
  raccords), m17 (recette à la création) ; elles sont tenues en moteur réel par `levels_points`, sur lequel le
  témoin, qui n'a aucune des trois, échoue exactement.
- Captures (`corr-captures-t2-machines`, `fo-captures.bat t2-machines`, code 0, 12/12 images, BILAN 79 OK, arbre entre
  `be0ee03` et `e84ca84`) : `005-points-orientations.png`, `006-points-refus.png` (contour orange, gênes rouges,
  coffre servi en jaune), `011-gros-plan-points-foreuses.png`, `012-gros-plan-points-assembleurs.png`.
- Limites (non prouvé) : raccords du fluide de minage d'une foreuse et boîte à fluide de SORTIE d'un assembleur (même
  code, non joués) ; le téléport d'une foreuse (F90) n'est vérifié que par son dépôt et son extraction ;
  équivalence des convoyeurs jouée hors jeu et sur les bouts de rangée de l'usine dense seulement (aucun dépôt sur
  un convoyeur d'une autre ligne) ; ligne « points-moved » du panneau en moteur simulé seulement ; la source du
  témoin (bloc-notes du correcteur : `git archive be0ee03` plus 2 fichiers) n'est pas gardée dans `fo-logs`, elle se
  reconstruit à l'identique.

**E50 · VALIDÉ en moteur réel, sur une carte de banc ; constat de design remonté (Q-T2-1) · Migration réelle 0.4.2 →
0.4.3 quand toutes les familles grandissent (lot V3-T2 ; ingénieur 17 h 43 à 18 h 00, correcteur 18 h 52 à 18 h 59,
`main` 19 h 05)** :
- Protocole : double source (`FO_CREATE_SRC` = `<racine>\fo-logs\2026-10-22_V3T2\src-0.4.2`, identique octet pour
  octet à `git archive c4d37e5`, version 0.4.2, où seule la mitrailleuse grandit ; vérifié par le relecteur 3),
  scénario greffé `t2-migration`, 700 ticks, contrôles aux ticks 90 et 600 ; journal contrôlé hors jeu par
  `ht3_journal.py --tag FO-T2-MIGRATION`. La carte, posée par 0.4.2 aux anciennes tailles :
  - force `fo-t2-libre`, sans poteau (contenu comparé exactement) : pour chaque famille un niveau 7 libre, un niveau
    élevé libre (laser et four 25, foreuse et assembleur 19, tous 6×6 en 0.4.3), une paire de niveau 7 collée ; une
    mitrailleuse 7 témoin (déjà 3×3 en 0.4.2) ;
  - centres 15 (force `fo-t2`, 4×4 → 8×8), 10 (`fo-t2-c7`, 4×4 → 7×7, coffre garni) et 6 (`fo-t2-c5`, 4×4 → 5×5, un
    bras sur chaque côté) ;
  - **usine dense typique** de 24 machines de niveau 8 (force `fo-t2`, alimentée) : 6 assembleurs collés (bras
    d'entrée au nord, de sortie au sud vers un convoyeur), une colonne de 6 fours (bras à l'ouest et à l'est,
    convoyeur), 6 foreuses en deux rangées face à face autour d'un convoyeur, 6 lasers collés derrière un mur.
- Voie : `on_configuration_changed` au tick 0 (`mod_changes` factorio-overhaul 0.4.2 -> 0.4.3), puis `Levels.repair` :
  « 21 bâtiment(s) reposé(s), 3 déjà en place, 19 laissé(s) faute de place (chevauchement toléré) » ; compteurs
  migrated 21, overlap_kept 19 ; spilled, resize_failed et forced à 0 ; aucun objet au sol. Messages aux joueurs
  (correction du défaut 9) : force fo-t2, 18 laissés ; fo-t2-c5, 1 ; 0 doublon. Filet sans effet jusqu'au tick 600.
- Résultats :
  - libres : laser 7, four 7, foreuse 7 et 19, assembleur 7 et 19, centre 10 REPOSÉS sur la grille, sans
    chevauchement, contenu et PV identiques ; laser 25, four 25 et centre 15 DÉJÀ EN PLACE (même entité) ;
    mitrailleuse 7 inchangée ; les 4 paires collées reposées toutes les deux, sans se chevaucher ; centres 15, 10 et
    6 toujours suivis par leur force ; relevé des emprises égal à la table (7 familles, tous niveaux) ;
  - **usine dense : 18 machines sur 24 restent HORS GRILLE (75 %)** : assembleurs 6/6, fours 6/6, foreuses 2/6 (le
    milieu de chaque rangée), lasers 4/6 ; reposées : les 4 foreuses et les 2 lasers des bouts (dépôt toujours sur le
    convoyeur). Le centre 6, entouré de bras, est laissé lui aussi. Toutes en service (F88) ;
  - amélioration ultérieure d'un assembleur laissé (8 → 9) : avant le correctif F86, « done » avec deux machines
    superposées ; après, refus « no-room » (son propre bras sud gêne la remise sur la grille), coût non payé ; une
    fois le bras retiré, remise sur la grille au niveau 9 en (306 ; 287), sans chevauchement, ancienne disparue.
- Passages : `final-t2-migration` (`be0ee03`, 18:00:44,83) 62 OK, journal 23 OK ; `corr-final-t2-migration` (`e84ca84`,
  18:59:20,03) **64 OK**, journal **26 OK** ; `main` (19:05:48,49) **64 OK**, journal **26 OK**, code 0 (rejoué sur
  l'archive par l'intégrateur des documents : même résultat).
- Migration 0.4.1 → 0.4.3 (`ht3-migration`, création `<racine>\fo-logs\2026-10-22_V3T-suites\ht3\src-0.4.1`) : **30 OK**
  (29 d'avant, plus le centre 15 qui grandit désormais lui aussi, compté « déjà en place »), journal **7 OK** ; sur
  `main` (19:05:52,39) : « 6 bâtiment(s) reposé(s), 3 déjà en place, 3 laissé(s) », messages fo-ht3 2 et player 1.
- Captures avec images en double source (`fo-captures.bat t2-migration`, `FO_CREATE_SRC` = `src-0.4.2`, code 0) :
  `captures-t2-migration` (17 h 53, 2 images) et `corr-captures-t2-migration` (18 h 53, 3/3 :
  `001-migration-libres.png`, `002-migration-dense-assembleurs-fours.png`, `003-migration-dense-foreuses-lasers.png`) ;
  la superposition d'une demi-tuile se voit. **Premier usage de `FO_CREATE_SRC` avec `fo-captures.bat`** : la carte
  du banc est créée par la source de création (`banc-create-source.txt`) et la session avec images rejoue la
  migration (`factorio.log` : « 21 bâtiment(s) reposé(s), 3 déjà en place, 19 laissé(s) »).
- Limites (non prouvé) : variante sans montée de version (filet seul) pour 0.4.3 ; vrai second chargement d'une carte
  migrée ; doublons hérités relevés hors jeu seulement (aucune carte 0.4.2 avec doublons rejouée) ; message de
  migration à l'écran (journal seulement, pas de joueur en mode benchmark) ; l'usine dense est UNE disposition
  synthétique (insertion directe entre machines, balises : non jouées) ; F85 vu avec le seul poteau invisible du mod
  de test ; les sauvegardes du Directeur Créatif n'ont été ni touchées ni testées.

**E49 · VALIDÉ en moteur réel pour la mécanique des 5 familles ; visuel PROVISOIRE, laid aux grandes tailles, sans
verdict du DC · Emprise croissante de toutes les familles (lot V3-T2, Q-S1 : oui ; ingénieur 17 h 18 à 18 h 00,
revue adverse, correcteur 18 h 40 à 19 h 05 ; intégré dans `main` le 22/10 à 19 h 05, fusion `--no-ff` `681dd5c`,
version 0.4.3)** :
- Demandes : Q-S1 (22/10, 16 h 45 : oui), Q23 (« 6 par six »), Q24 (agrandissement sur place, sinon refus et contour).
- Table livrée (`L.footprints`, `shared/levels/config.lua`) : command {4,5,6,7,8}, gun {2,3,4,5,6} (inchangée),
  laser {2,3,4,5,6}, drill {3,4,5,6,6}, furnace {2,3,4,5,6}, assembler {3,4,5,6,6} ; le mur n'a pas de ligne.
  108 niveaux changent d'emprise depuis 0.4.2 (4 familles × 24 niveaux, plus 12 niveaux du centre). Chiffres :
  BALANCE_SHEET §12.
- Protocole : banc `content` (4 000 ticks) avec le greffon `checks/levels_machines.lua` (zone 3 : x 588 à 716, y 240
  à 336 ; 54 contrôles) : A, place libre et transfert réel du contenu ; B, usine dense (refus, retrait des gênes
  annoncées, agrandissement) ; C, chaînes 6 → 30 et centre 1 → 15 ; prototypes des 5 familles, tous niveaux. Scénario
  greffé `t2-machines` (1 500 ticks : les greffons `levels_machines` et `levels_points` joués au tick 60, pour les
  captures).
- Résultats (`final-content`, `be0ee03`, `done.txt` 18:00:40,38 : 292 OK, 0 ÉCHEC) :
  - assembleur 6 → 7 : 4×4 en (605 ; 263), position préférée ; recette fill-water-barrel, barils vides 10/10, pleins
    3/3, modules 2/2, eau 30/30, PV 0,60 ; tuyau infini posé au raccord lu sur l'entité, visée (604,5 ; 260,5) : 7
    barils remplis ensuite ; bras ouest nourrit la nouvelle machine (F89). Assembleur EN fabrication de moteurs :
    bilan d'acier 101 avant, juste après et au tick 3000 ; progression 0,061 → 0,063 à ACT + 2 ;
  - foreuse 6 → 7 : 4×4 en (621 ; 263) ; fil rouge vers le combinateur et réglages transférés (lecture du gisement,
    mode 1, condition A > 0) ; progression 0,850 ; dépôt en (620,5 ; 260,652) dans le MÊME coffre, +17 minerais ;
    une foreuse sans minerai sous son ancienne zone mine la bande nouvelle (643,5 ; 265,5), 16 minerais ; rayon
    2,49 → 2,99 ;
  - four 6 → 7 : un bras au nord bloque les positions nord, 3e position (sud-ouest) en (659,5 ; 262,5) ; charbon 9/9,
    minerai 1 + 1 rendu (F83), plaques 25 → 44 (25 → 43 dans une version précédente des notes, lu sur le passage
    d'avant le correctif : corrigé), combustible en train de brûler (reste 587 370 J), PV 0,80 ; bilan de fer 205
    constant ; le bras nourrit le nouveau four (177 → 160) ;
  - laser 6 → 7 : 3×3 en (679,5 ; 261,5) ; énergie 961 200 J, victimes 7/7, dégâts 1 234,5, PV 0,50 ; portée 26,00
    (statistique 25,5 + 0,5) ; relié au réseau ;
  - centre : chaîne 1 → 15 (force à part), 4 agrandissements (5×5, 6×6, 7×7, 8×8), coffres 9/9, charbon 50/50 ;
  - usine dense : 5 refus « no-room » (assembleur et four entre leurs voisins et leurs bras ; foreuse et laser entre
    leurs voisins ; centre 3 entouré de bras), coût non payé, contour ; les gênes annoncées retirées (exactement
    elles), agrandissement à la position du contour ;
  - chaînes 6 → 30 : 4, 3, 4 et 3 agrandissements par script (laser, foreuse, four, assembleur), le reste en
    remplacement rapide moteur, 0 secours ; contenu et recette conservés ;
  - prototypes : emprise de la table, collision au style vanilla (niveaux au côté de base : boîtes vanilla
    intactes), même groupe, rayon d'extraction r + (côté − 3)/2, portée + (côté − 2)/2, raccords hors de la boîte et
    sur un centre de tuile ; 0 renversé, 0 échec, 0 forcé, 0 secours.
- Passages de mise au point gardés : `content-0-table-seule` (17:21:11,22 : table activée, rien d'autre, 238 OK) ;
  `content-3-bilans-avant-correctif` (288 OK, 3 ÉCHEC : F83).
- Après le correcteur (`e84ca84`) : `content` **317 OK** (exemple 2, `levels_taille` 26, `levels_machines` 54,
  `levels_points` 25) et `t2-machines` **80 OK** (18:59:15,13) ; sur `main` (19:05:39,98 et 19:05:44,44) : 317 OK et
  80 OK. 317 = 210 du banc + 107 greffés, recompté par l'intégrateur des documents dans `create.log` (63 OK) et
  `benchmark.log` (254 OK).
- Revue adverse : 3 relecteurs, 19 défauts. Suivi du correcteur :
  - 1 et 6 (points servis selon l'orientation, majeur) : confirmés en moteur réel, corrigés (E51) ; F90 et F91, plus
    graves, trouvés en le prouvant, corrigés ;
  - 3 (barre du coffre) : confirmé (témoin : 97), corrigé ; 9 (message de migration), 10 (progression recopiée hors
    fabrication), 11 (panneau), 16 (couverture hors jeu), 17 (classement « laissé » tautologique) : corrigés ;
    4 (fluide rendu) : corrigé, non joué ;
  - 2 et 15 (seconde amélioration avant le `on_tick`) : plausibles, corrigés, non reproductibles sans joueur ;
    5 : joué (F94) ;
  - 7 (usine réelle) et 8 (production par tuile) : confirmés, non corrigeables dans le lot : questions Q-T2-1 et
    Q-T2-2 (OBJECTIFS §4) ;
  - 12 (captures) : en partie (refus et usine dense capturés ; aucun verdict du DC) ; 13 (preuves) : F84 rejoué, F93
    relevé, doublons détectés, coût du `on_tick` mesuré (H-L1) ; 14 (migration d'une machine en fabrication) : non
    jouable ; 18 (notes) : corrigé ; 19 (disque) : 2,5 Go libres à 19 h 00, rien supprimé.
- Hors jeu sur `main` (19 h 05 à 19 h 10) : run 114, war 92, td 270, pteam 15, migration **79** (60 avant le lot),
  levels **1 575** (+ 11 écarts connus ; 1 564 avant), epochs 16 665, org 362, pvp 596 ; harness 0 erreur nouvelle,
  0 violation, points de jeu mod 61 entités / 182 points, auto-contrôle 11/11, 0 clé manquante ; api_lint **519**
  usages, 0 erreur (447 avant) ; d4m 5/5 ; mut_atlas 40 OK ; test_ht3_journal **15 OK** (9 avant) ;
  bat_double_source 4 OK. Mutations du correcteur (sur une copie, témoin 79 / 1 575) : m4a, m4c, m7, m9, m10, m11,
  m12, m13, m14, m18, m19 tuées hors jeu ; m15, m16, m17 tenues en moteur réel seulement (E51).
- Captures (`fo-captures.bat`, code 0 ; images regardées par l'ingénieur et le correcteur, deux d'entre elles par
  l'intégrateur des documents) : `captures-t2-machines` (17 h 47 : `005-gros-plan-assembleur-foreuse.png`,
  `006-gros-plan-four-laser.png`, `007-gros-plan-chaines-30.png`, `008-gros-plan-centre-15.png`),
  `corr-captures-t2-machines` (18 h 53, 12 images), `captures-content` (17 h 48 : `052-niveaux-command-01-15.png`,
  `070-niveaux-laser-haut.png`, `086-niveaux-drill-haut.png`, `094-niveaux-furnace-haut.png`,
  `102-niveaux-assembler-haut.png`, planches 1 à 3), tous dans `<racine>\fo-logs\2026-10-22_V3T2\`. **Verdict franc :
  visuel PROVISOIRE et laid aux grandes tailles** : bitmaps agrandis ×2 à ×3, flous et pixelisés (four et laser
  6×6 surtout) ; aucune pièce nouvelle ; la tête du laser et le haut de la foreuse débordent de leur socle vers le
  haut ; le centre 8×8 déborde de son socle en bas et la tête du radar sort en haut à gauche, décalée ; après
  migration, les machines hors grille se superposent d'une demi-tuile. Les sprites V3 (lot V3-E) restent
  indispensables. Aucun verdict du DC.
- Non prouvé (en plus des limites d'E50 à E52) : panneau, aperçu au sol, ligne « hors grille » et ligne
  « points-moved » (pas de joueur en mode benchmark ; moteur simulé seulement) ; fils de circuit d'un assembleur ou
  d'un four (sans objet en 1.1 selon le relecteur 1 : ces machines n'ont pas de circuit) ; tir du laser agrandi à sa
  nouvelle portée (seule la portée du prototype est contrôlée) ; zone d'extraction agrandie : un seul coin (sud-est)
  de la bande nouvelle ; remboursement F40 : moteur simulé seulement.

**E48 · VALIDÉ (hors jeu) · Banc d4m corrigé : atlas attendus selon les réglages de chaque journal (suite d4m de
V3-T, 22/10 ; bancs du correcteur rejoués de 15 h 36 à 15 h 50 ; intégrée dans `main` le 22/10 par la fusion
`18a00d4`, tête `c023664`)** :
- Origine de l'échec à 4/5 (E44) : l'étape 5 de `tools/autotest/tests/run_d4m.py` cherchait seulement « (15) » dans
  la ligne « -- Atlas de sprites (N) » du rapport de `vram.py`. Or le nombre d'atlas dépend de la qualité (F80) :
  15 en haute qualité, 14 en normale et au plancher. `vram.py` ne contenait aucune constante 15.
- Correction (commits `796ac4d` du constructeur, puis `c023664` du correcteur) :
  - table `ATLAS_ATTENDUS`, de clé (qualité, mémoire vidéo, DXT), lue dans la ligne « Graphics options » à travers
    le JSON de `vram.py`. Trois entrées, étalonnées sur les 13 journaux : high/all/high-quality, 15 atlas dont
    2 [none] ; normal/all/high-quality, 14 dont 1 ; normal/low/low-quality, 14 dont 1, avec l'atlas virtuel et le
    drapeau « plancher ». Une combinaison non étalonnée est un échec ;
  - `AUTRES_ATLAS` : les 13 signatures de drapeaux hors [none], chacune exactement une fois. Seule variante
    tolérée : linear-minification sur [low-object] ;
  - `SEUIL_NONE_PX` = 4096², soit 16,8 Mpx : au plancher, les pixels [none] restent sous ce seuil ; ailleurs, ils
    le dépassent. C'est une ligne de partage entre les valeurs observées (2,7, 141,0 et 475,8 Mpx), pas une
    limite du moteur ;
  - `vram.py` : `RE_ATLAS`, `RE_MIP` et la nouvelle `RE_VIRTUAL` sont ancrées sur l'horodatage du moteur. Une
    impression de script qui contient ces mots ne compte plus. L'atlas virtuel est relevé (`virtual_atlases`) et
    signalé, mais toujours hors de l'estimation (F81).
- Revue adverse : 1 défaut majeur et 3 mineurs, tous confirmés puis corrigés.
  - Majeur : le garde-fou de `--out` de `mut_atlas.py` était mal placé. Rejoué avec le code de `796ac4d` : `--out`
    égal au dossier d'archives était accepté, puis l'étape 5 lisait 23 journaux, dont 15 en écart.
  - Mineurs : composition des atlas non contrôlée (3 mutations survivaient, dont un plancher non appliqué) ; atlas
    virtuel détecté par une simple sous-chaîne ; formulation « une fois chacun » au lieu de « une fois par
    catégorie ».
- Résultats du correcteur (worktree, `c023664`) :
  - `run_d4m.py --logs fo-logs` : 5/5, code 0. Essai à blanc 11 OK, greffon 16 OK, unitaires de `vram.py` 57 OK
    (51 avant), intégration 17 OK, 13 journaux sans écart ;
  - `mut_atlas.py` : 40 OK sur 40. Ce sont 7 témoins acceptés, 21 mutants refusés, 11 cas du garde-fou et 1 contrôle
    final (aucune des 28 copies n'est lue par l'étape 5) ;
  - boîte noire sur le dossier des mutants : 28 journaux lus, 21 en écart, exactement les 21 mutants ;
  - mutations du code corrigé : 6 sur 7 détectées. La 7e (retrait de `normcase`) est équivalente sur ce poste,
    car `realpath` de Python 3.14 sous Windows rétablit déjà la casse.
- Sur `main` après l'intégration (rejoués le 22/10 à 17 h 12) : d4m 5/5 ; mut_atlas 40 OK, avec `--out` hors de
  `fo-logs`.
- Preuves : `<racine>\fo-logs\2026-10-22_V3T-suites\d4m\` (sorties du constructeur à la racine, du correcteur dans
  `correcteur\`, `NOTES.md`).
- Limites :
  - la cause du second atlas [none] reste déduite (F80) ;
  - pourquoi l'atlas [low-object] porte linear-minification en haute qualité et au plancher, mais pas en
    normal/all : observé, pas expliqué (c'est la seule variation que l'étape tolère) ;
  - que le format « horodatage puis message » vaille pour TOUTE ligne d'atlas du moteur : vrai dans les 13
    journaux, supposé ailleurs (une ligne sans horodatage ne serait plus comptée, et l'étape échouerait) ;
  - les réglages non observés (mémoire high ou medium, DXT none, haute qualité avec mémoire low…) sont refusés
    tant qu'aucun journal réel ne les étalonne ;
  - la composition et le seuil devront être réétalonnés avec les sprites V3 (l'étape échouera alors, c'est voulu) ;
  - une archive sans `visual.log` (dossier d'un banc `content`, par exemple) n'est pas reconnue par le garde-fou ;
  - l'atlas virtuel n'est toujours pas compté dans l'estimation de `vram.py` (tâche ouverte, OBJECTIFS §7). **Fait
    depuis** (lot R1, 22/10, E55).

**E47 · VALIDÉ (hors jeu) · Règle des points de jeu dans le harness, moteur simulé à boîtes vanilla, attentes de
`levels_test` tirées de `L.footprints` (suite des bancs hors jeu de V3-T, 22/10 ; bancs du constructeur finis à
16 h 07, du correcteur à 17 h 03 ; intégrée dans
`main` le 22/10 par la fusion `1f2ff79`, tête `da9d283`)** :
- But : les suites 1 et 2 de V3-T (OBJECTIFS §7), et les 3 attentes de `levels_test` liées à la table livrée (D1-4).
- Règle des points de jeu (`tests/datastage/engine_rules.lua`), comptée dans « Règles moteur : N violation(s) » :
  - pipe-inside : raccord de tuyau hors de la boîte de collision, le bord comptant comme dedans ;
  - pipe-off-center : raccord sur un centre de tuile (sautée pour une entité `placeable-off-grid`) ;
  - drop-inside : dépôt de foreuse hors de la boîte ;
  - drop-on-footprint : dépôt hors des TUILES de la foreuse. Une foreuse 4×4 restée aux points vanilla dépose en
    −1,85 : hors de sa boîte (±1,7), mais sur ses tuiles (±2).
  Vérifiée sur vanilla d'abord : 18 entités, 51 points, 0 alerte (F82). Exception du chevalet de pompage prouvée
  par désactivation. Mod : 61 entités, 182 points, 0 violation. Auto-contrôle de 11 cas fabriqués à chaque passage ;
  depuis la correction, un cas faux compte dans les violations.
- Mutations de l'étape data :
  - `move_point` désactivé seul : l'étape data s'arrête dans `footprint_problems` (`common.lua:1255`,
    fo-lvl-drill-7), comme le moteur réel s'arrêterait au chargement ;
  - `move_point` désactivé et `footprint_problems` neutralisé : le harness seul attrape 222 violations (90
    pipe-inside, 90 pipe-off-center, 18 drop-inside, 24 drop-on-footprint), code 1 ;
  - rotation vers l'est fausse : « Règles moteur : 1 violation(s) (dont 1 cas faux de l'auto-contrôle) », 10/11,
    code 1.
- Moteur simulé (`tests/mock_engine.lua`) : `bounding_box` et recherche par zone sur la boîte du prototype (formats
  runtime et étape data ; contact bord à bord exclu jusqu'au 22/10, puis compris : E53, observé en moteur réel),
  `get_control_behavior` et `get_or_create_control_behavior`
  (foreuse), `get_recipe` et `set_recipe`, `destroy_decoratives` relevé.
- Défaut MAJEUR de la revue, confirmé et corrigé : le constructeur appelait « fidèle » un modèle hybride. Les
  prototypes intégrés au moteur simulé (QG, mitrailleuse, foreuses, four, coffres, personnage) n'avaient pas de
  boîte et recevaient le 1×1 ; les petits déchiqueteurs tombaient sur le prototype générique.
  - Correction : boîtes vanilla relevées par `harness --dump-final`. QG {−8,7 ; −3,3 ; 6,9 ; 4,5}, décentré
    (copie de crash-site-spaceship) ; gun-turret, burner-mining-drill et stone-furnace ±0,7 ; electric-mining-drill
    ±1,4 ; coffres ±0,35 ; character et fo-companion ±0,2 ; small-biter ±0,2 ; small-spitter ±0,3.
  - Masques par défaut de leur type ; filtre `collision_mask` (au moins une couche commune) dans la recherche non
    inversée. `legacy_boxes` (l'ancien modèle) reste une option de comparaison, qu'aucun banc n'utilise.
- PvP : avec le modèle hybride, `pvp_test` tombait à 594 OK, 2 échecs (taille moyenne d'attaque Normal 18,2 >
  Difficile 18,0). Avec les boîtes vanilla : 596 OK, et `pvp_test.lua` est identique à `edac1b3`.
  - Mesure par niveau : Normal 17,2 < Difficile 17,7 < Impitoyable 20,5 (ancien modèle : 16,8 < 18,7 < 19,9).
  - Trois variantes donnent un journal identique : sans le filtre de masque, avec une boîte ±1,2 pour
    assembling-machine-1, avec `limit` respecté. L'écart venait donc des boîtes 1×1 par défaut.
  - « Normal 18,2 > Difficile 18,0 » est un artefact : à ne PAS transmettre à IA0b.
- Trajectoires changées par les boîtes, tous les bancs restant verts :
  - run.lua : départs dégagés 11 → 34 dans un scénario, 39 → 147 dans un autre ;
  - war_test : stocks et nombre d'attaques différents ;
  - td et pteam : identiques.
  Lequel des deux modèles est le plus proche du jeu réel : rien ne le dit.
- Attentes de `levels_test` et `migration_test` calculées depuis `L.footprints` (relevé à 24 niveaux, liste des
  niveaux qui changent, fours niveau 25, portée du laser), et `FO_DATA_DIR` accepté. `migration_test` : 50 → 55
  (constructeur), puis 60 (correction).
  - Les 5 contrôles de la correction : boîte au format de l'étape data, contact bord à bord exclu (contrôle inversé
    le 22/10 : le contact est compris, E53), zone qui mord de
    0,01, filtre `collision_mask`, boîtes intégrées gun-turret et QG égales au vanilla.
  - Le transfert de circuit règle aussi `connect_to_logistic_network = true` et une `logistic_condition` non par
    défaut.
- Mutations du moteur simulé et de `Levels.transfer`, toutes tuées par `migration_test` :
  - zone par position seule, boîte 1×1, décors non relevés : 1 échec chacune ;
  - `get_control_behavior` retiré : arrêt du banc ;
  - runtimeonly (format data), edgein (bord à bord), nologi, nologinet, nomask : 59 OK et 1 échec chacune ;
  - unitbox : 57 OK et 3 échecs.
- Copie jetable aux 6 familles activées (laser {2,3,4,5,6}, drill {3,4,5,6,6}, assembler {3,4,5,6,6}, furnace
  {2,3,4,5,6}, command {4,5,6,7,8}) : run 114, war 92, td 270, pteam 15, migration 60, levels 1564, org 362, pvp 596,
  harness 0/0/0 et 11/11, api_lint 434/0.
  - Revue : chaque famille activée seule donne levels 1564 et migration 55, 0 échec.
  - Témoin `edac1b3` aux 6 familles : migration 37 OK et 13 échecs, levels 6 échecs. La suite corrige donc de
    vrais échecs.
- Preuves : `<racine>\fo-logs\2026-10-22_V3T-suites\harness-mock-levels\` (`NOTES.md` du constructeur,
  `correcteur\NOTES.md`, journaux et outils). Aucun banc en moteur réel.
- Limites (non prouvé) :
  - le contact bord à bord de `find_entities_filtered{area}` en moteur réel n'est pas observé. Le moteur simulé
    l'exclut par choix, tenu par un contrôle ; ce n'est pas un fait. **Levée le 22/10 (lot R1, E53)** : le moteur
    réel REND le contact bord à bord (F96) ; le moteur simulé l'exclut jusqu'au 22/10, puis le comprend (intervalles
    fermés) ;
  - le filtre `collision_mask` du moteur réel est lu dans la doc, non observé ;
  - la recherche non inversée ignore toujours `limit` ; `count_entities_filtered` n'est pas comparé au moteur
    réel ; `get_control_behavior` ne simule que la foreuse ;
  - assembling-machine-1 (`pvp_test`) et fo-command-center (`levels_test`) restent en 1×1, car ces bancs les
    déclarent sans boîte ;
  - l'ordre nord, est, sud, ouest de `pipe_connections[].positions` est supposé d'après la doc ;
  - le chargeur du moteur réel face à un raccord dans la boîte n'est pas observé. Qu'un dépôt sur les tuiles hors
    de la boîte (drop-on-footprint) soit inutilisable en jeu est déduit de la géométrie ;
  - aucune machine agrandie n'a tourné en moteur réel : la copie à 6 familles n'est prouvée que hors jeu ;
  - `epochs_test` sur une copie hors de l'arborescence du jeu : 16540 OK, 1 échec (chemins relatifs, préexistant) ;
  - le dernier passage complet du correcteur a précédé le changement d'une ligne de commentaire de
    `mock_engine.lua`. Les bancs rejoués sur `main` (22/10, 17 h 06 à 17 h 13) couvrent l'état final.

**E46 · H-T3 : (1) PROUVÉE en moteur réel ; (2) prémisse réfutée (F77) ; filet prouvé seulement en expérience de
contrôle · Migration d'une vraie sauvegarde 0.4.1 vers 0.4.2 (suite H-T3 de V3-T, 22/10, 15 h 23 à 16 h 05 ;
intégrée dans `main` le 22/10 par la fusion `e1a6a6f`, tête `d6ba888` ; rejouée sur `main` à 17 h 06)** :
- Outillage :
  - `fo-autotest.bat` : variable d'environnement facultative `FO_CREATE_SRC`. Si elle est définie, la copie de
    factorio-overhaul faite pour l'étape `--create` vient de ce chemin. À l'étape [2b/4], cette copie est effacée
    puis remplacée par la source habituelle avant le `--benchmark`. Le mod de test vient toujours de la source
    habituelle, et `create-source.txt` n'est écrit qu'en double source. Ajout du correcteur : arrêt avec le code 1,
    sans `done.txt` ni benchmark, si la copie de création n'est pas effacée en entier ou si robocopy de la source
    du benchmark rend 8 ou plus. Sans la variable, ce bloc est sauté ;
  - `greffons.lua` : les contrôles greffés ne sont chargés que pour `content` ou un scénario greffé de base
    `content`. Sans cela, le mod de test récent ne se chargeait pas avec la source 0.4.1 :
    `checks/levels_taille.lua` requiert `shared/levels/footprint.lua`, absent de 0.4.1 ;
  - `script/remote.lua` : `levels_status` rend aussi `footprints` et `footprints_stale` (le `global` d'un mod est
    illisible depuis un autre, F35) ;
  - nouveaux fichiers : scénario greffé `ht3-migration.lua`, contrôle du journal `ht3_journal.py`, bancs hors jeu
    `test_ht3_journal.py` (9 OK) et `bat_double_source/run.py` (4 OK : faux factorio.exe et faux robocopy.exe
    compilés avec le gcc de `C:\mingw64`, racines jetables).
- Carte : créée par 0.4.1 (`src-0.4.1`, identique à `git archive 91097e6`), puis rejouée par 0.4.2.
  - 13 mitrailleuses posées en 2×2 et un centre 15 : libre7, libre19, pair13, pair30, coince7 (coffre et murs),
    eau25 (eau), duoA et duoB (voisines collées), voisin8, bas3, bas6 ;
  - deux défenses types, ajoutées par le correcteur, en force « player » et posées avec `raise_built` : defense7
    (ligne de 10 murs une rangée devant, bras à combustible nourri par 4 convoyeurs) et rempart7 (murs collés
    devant, bras nourri par un coffre) ;
  - munitions (dont un chargeur entamé à 4 coups) et PV variés.
- Trois voies, jouées par le correcteur sur `d6ba888` (15 h 59, code 0 chacune) :
  - a, montée de version : `mod_changes` { factorio-overhaul 0.4.1 -> 0.4.2 }, migration par `Levels.repair` ;
  - b, sans montée de version (`git archive d6ba888`, `info.json` remis à 0.4.1) : `on_configuration_changed` est
    QUAND MÊME appelé, avec `mod_changes` vide (F77), et `Levels.repair` migre (ligne 1000 de `levels.lua`) ;
  - c, expérience de contrôle (même copie, ligne 998 de `levels.lua` neutralisée) : relevé PÉRIMÉ au premier tick,
    puis migration par le filet `on_nth_tick(30)` (« emprises (filet, sans changement de version) : 6, 2, 3 ») ;
  - témoins du constructeur (`113ddba`, 15 h 31) : d (un commentaire ajouté à `levels.lua`) et e (copie
    identique). `on_configuration_changed` n'est pas appelé, la somme ne change pas.
- Résultat, identique dans a, b et c : « [FO-HT3-MIGRATION] BILAN : 29 OK, 0 ECHEC(S) » et « JOURNAL H-T3 : 7 OK,
  0 ECHEC(S) ».
  - 6 reposées : libre7 en (309,5 ; 249,5) et libre19 en (329,5 ; 249,5), à la candidate 1 ; duoA, duoB et voisin8 ;
    defense7, n° 32 → n° 62, en (309,5 ; 291,5) ;
  - 2 déjà en place (pair13 en 4×4, pair30 en 6×6, même entité) ;
  - 3 laissées faute de place et journalisées : coince7 en (310 ; 275), gênée par le coffre et les murs ; eau25 en
    (330 ; 275), par l'eau ; rempart7 en (330 ; 292), par le bras ;
  - bas3 et bas6 inchangées ;
  - munitions case par case (piercing:37:4 conservé) et PV en proportion ; « aucun chevauchement : 10 boites
    controlees » ; compteurs migrated 6, overlap_kept 3, resized 6 ; spilled, resize_failed, forced et ground_left
    à 0 ; centre 15 suivi ; relevé écrit ;
  - filet sans effet une fois le relevé à jour : garde `footprints_stale` faux, et aucune ligne rejournalisée
    jusqu'au tick 600 ;
  - defense7 : le bras vise la nouvelle tourelle et la nourrit, 3 puis 9 chargeurs (F79) ; rempart7 : laissée hors
    grille, boîte 328,80..331,20 × 290,80..293,20, sans chevauchement réel, toujours nourrie (3 puis 8).
- **Constat à remonter** : une mitrailleuse collée à une ligne de murs et nourrie par un bras placé derrière reste
  hors grille, en service, chevauchement toléré. Dans une vraie défense, ce cas peut être courant ; combien de
  tourelles seraient ainsi laissées dans une vraie partie, on ne le sait pas.
- Revue adverse : 5 défauts mineurs, tous confirmés et corrigés.
  - Journalisation des mitrailleuses laissées non contrôlée par le banc : le scénario écrit les lignes « JOURNAL
    ATTENDU », et `ht3_journal.py` les compare aux lignes [FO-LEVELS]. En moteur simulé, la mutation était déjà
    refusée (`migration_test` 49 OK, 1 ECHEC).
  - Intitulé « H-T3 prouvée » trop large : statut en trois parties (ci-dessus).
  - rmdir et robocopy de l'étape [2b/4] non vérifiés. Reproduit hors jeu sur le .bat de `113ddba` : code 0 avec un
    fichier ancien resté au benchmark, ou avec un benchmark sans `info.json`. `bat_double_source` donne 2 OK et
    2 ECHEC sur `113ddba`, 4 OK sur `d6ba888`.
  - Carte peu représentative : defense7 et rempart7 ajoutées. Corrigé EN PARTIE : pas de défense dense.
  - Libellé « second passage » : renommé, c'est le garde qui est vérifié.
- Intégration sur `main` (22/10) :
  - fusion `e1a6a6f` ; la copie racine de `fo-autotest.bat` est identique à `tools/autotest/fo-autotest.bat` (cmp).
    Elle avait été installée par la suite en tenant le verrou ;
  - banc `content` : « [FO-CONTENT] BILAN : 238 OK, 0 ECHEC(S) », `done.txt` du 22/10/2026 à 17:06:23,34 ;
  - `ht3-migration` en double source (`FO_CREATE_SRC` = `<racine>\fo-logs\2026-10-22_V3T-suites\ht3\src-0.4.1`,
    700 ticks) : `mod_changes` 0.4.1 -> 0.4.2 ; « mise à jour des emprises : 6 bâtiment(s) reposé(s), 2 déjà en
    place, 3 laissé(s) faute de place (chevauchement toléré) » ; 29 OK, 0 ECHEC ; `done.txt` à 17:06:44,67 ;
    `ht3_journal.py` donne 7 OK, 0 ECHEC (rejoué sur l'archive par l'intégrateur des documents : même résultat,
    code 0) ;
  - archives : `<racine>\fo-logs\2026-10-22_V3T-suites-integration\content\` et `…\ht3-migration\`.
- Preuves de la suite : `<racine>\fo-logs\2026-10-22_V3T-suites\ht3\` (`NOTES.md` ; `correcteur-d6ba888\<passage>\`
  avec create.log, benchmark.log, done.txt, source.txt, create-source.txt, commit.txt, code-de-sortie.txt et
  ht3_journal.txt ; passages a à e du constructeur).
- Non prouvé :
  - un vrai second CHARGEMENT d'une carte déjà migrée, sauvegardée puis rechargée ;
  - une défense dense : beaucoup de tourelles côte à côte, des inserteurs électriques, des poteaux, une ligne qui
    alimente plusieurs tourelles ;
  - l'amélioration ultérieure d'une mitrailleuse laissée hors grille (coince7, rempart7) ;
  - les crochets `on_replaced`, le transfert d'un chantier 0.4.0 et la mise à jour de `st.cc` pour un centre
    reposé : moteur simulé seulement ;
  - la propagation de `FO_CREATE_SRC` par `fo-captures.bat` ; un vrai échec partiel de robocopy (simulé par un
    faux robocopy.exe) ;
  - les sauvegardes du Directeur Créatif : ni touchées ni testées. Aucune capture : rien de visuel n'est nouveau.
  Le filet `on_nth_tick(30)` coûte une comparaison toutes les 30 ticks, sans cas réel connu où il serait le seul
  recours (F77). Le garder ou le retirer n'est pas décidé.

**E45 · STYLE RETENU PAR LE DC (22/10, 16 h 45), direction artistique par époque manquante ; juges : aucune approche au niveau du vanilla · Trois approches de la mitrailleuse jugées (lot V3-S, 22/10,
13 h 20 à 16 h 10, run `wf_ed692a11-bba`)** :
- Protocole : 3 explorateurs (industriel lourd, haute technologie, hybride) reprennent les essais coupés à 8 h 55
  (REPRISE §5) et livrent en production (128 échantillons, 64 px par tuile, poses N et E) les niveaux 11 (3×3), 21
  (5×5), 29 (6×6) et la pièce du 30 ; test du regard naïf à l'aveugle (6 paires, clé seulement dans la valeur de
  retour) ; 2 juges indépendants : mesures (tools/da refait sur les sprites) et œil de directeur artistique ;
  planches recomposées pour le téléphone.
- Résultats : industriel 6 et 6 sur 10 (gagnant de peu), hybride 5,5 et 4, haute technologie 5 et 5. Regard naïf :
  industriel 6/6, hybride 6/6 ; haute technologie NON FAIT (le juge naïf a regardé les images d'une autre série :
  la consigne citait des noms de fichiers sans dossier ; corrigé dans les consignes suivantes : chemins absolus).
  Dominance 4 sur 4 (1 → 11 → 21 → 29 → 30) dans les trois approches, plus aucune dalle plate.
- Défauts communs (les deux juges) : pas de forme maîtresse (assemblage de modules face à la sphère du réacteur et
  à l'anneau du silo) ; arme qui ne domine pas la masse (sauf haute technologie en pose E) ; reflets C2 de 114 à 144,
  sous le MINIMUM vanilla (144 ; médiane 181) ; P2 de 13 à 15 sous le plancher de 16 partout (défaut du pipeline
  partagé) ; pose N lue comme des cheminées d'usine ; niveau 30 indiscernable du 29 (certitude naïve 2) ; nuit en
  « fenêtres allumées » (hybride, haute technologie). Industriel : D3 de 48 à 57 au-dessus du plafond de 45, baisse
  de 8,8 % entre n11 et n21. Hybride : seule densité constante (42,7 → 44,2 → 44,2). Haute technologie : densité qui
  chute de 15 % entre n11 et n21.
- Décision (orchestrateur, délégation Q25) : ne pas étendre une direction à 6/10 aux 7 familles ; passe de synthèse
  sur la mitrailleuse (run `wf_eaa96606-5f1`, 2 variantes partant de l'industriel : « affût rond » et « industrielle
  resserrée », avec les greffes des juges). Page privée pour le DC :
  https://claude.ai/artifact/EjdBUNfU1BLdkTU7cqWWMB .
- Preuves : `<racine>\fo-logs\2026-10-22_V3S\` (`industriel\`, `hightech\`, `hybride\`, `juges\`, `presentation\`) ;
  branches `worktree-wf_483106c7-c7f-2` (industriel, `265574d`), `-3` (haute technologie), `-4` (hybride, `e0571df`).
- Limites : tout est composé hors moteur ; rien n'a été vu en jeu.
- Verdict du DC (22/10, 16 h 45, page lue au téléphone) : « Q S1 çui, Q S2 oui et " oui. j ai regarde et les designs sont fou, je lss trçuve parfait mais on n a pas l" cote changement d epoque avec un DA par epoque, en revanche les dezigns actuel sçnt absoluement epoustçuflan surtout pour les canons et je pense quil est facile de reprendre le meme style en mode changer des canons et des tuyaux àour correspondre a une DA d un age, pour le moment je trçuve que c est trs precis et je vçus felic_te ». Lecture : le style des trois approches est retenu, les canons en tête ; il manque une direction artistique PAR ÉPOQUE (canons, tuyaux, accents propres à chaque âge). Son verdict prime sur celui des juges : la passe de synthèse `wf_eaa96606-5f1`, qui retouchait la forme, est arrêtée à 16 h 47 sans livrable. Suite : lot V3-E (mitrailleuse sur les 15 époques).

**E44 · VALIDÉ en moteur réel pour la mécanique de la mitrailleuse ; panneau, migration et autres familles NON
prouvés en moteur réel · Emprise croissante et agrandissement sur place (lot V3-T, Q23 et Q24, 22/10, 13 h 45 à
14 h 51)** :
- Demandes : Q24 (22/10, 7 h 40) « agrandissement sur place si la place autour est libre ; sinon l'amélioration
  est refusée et le contour nécessaire s'affiche » ; Q23 (7 h 20), des tailles qui augmentent.
- Décisions de l'orchestrateur :
  - mécanique ACTIVÉE pour la seule mitrailleuse, famille témoin de V3-S ;
  - échelle 2×2 → 3×3 → 4×4 → 5×5 → 6×6, une taille par ère de 3 époques (niveaux 1-6, 7-12, 13-18, 19-24,
    25-30 ; BALANCE_SHEET §12) ;
  - les autres familles attendent Q-S1 (charte V3-S, §9) ;
  - version montée à 0.4.2 à l'intégration, pour que `on_configuration_changed` migre les sauvegardes.
- Parcours : un ingénieur en worktree (`de6e628`), 3 relecteurs adverses (17 défauts, dont 5 majeurs), un
  correcteur (`3b06952`, 17 défauts traités : 16 corrigés et tenus par un test, le défaut 5 réfuté en moteur réel
  par F74). Fusion `--no-ff` dans `main` le 22/10 à 14 h 50 (commit `13b4134`), puis `integrateur.diff`
  (`tools/api_lint.py`, membres de V3-T) et version 0.4.2. Notes de l'ingénieur :
  `<racine>\fo-logs\2026-10-22_V3T\NOTES_V3T.md`.
- Protocole en moteur réel : banc `content` (4 000 ticks) avec le greffon `checks/levels_taille.lua`, 26
  contrôles joués au tick 1700 et à la vérification (tick 3000) ; force « fo-lv-taille » au centre 15 ; obstacles
  posés à la main (mur, coffre, eau, fantôme de mur, objet au sol, personnage, vrai minerai `iron-ore`).
- Résultats en moteur réel (banc d'intégration sur `main`, `done.txt` « termine 22/10/2026 14:51:18,38 », code 0,
  source = dossier du mod en version 0.4.2 non commitée) : **BILAN : 238 OK, 0 ECHEC(S)**, soit 210 contrôles du
  banc, 2 de l'exemple greffé et 26 du greffon. Valeurs clés observées :
  - place libre : 6 → 7 agrandie aussitôt, 3×3 en (469,5 ; 249,5), collision 468,30 à 470,70 ; 10 chargeurs
    transférés ; PV 380 / 760 ; objet de l'ancien niveau disparu ;
  - mur au nord et coffre au sud : refus « no-room », coût NON payé, contour 3×3 de (488, 248) à (491, 251),
    visible de la seule force du bâtiment pendant 300 ticks, gêne « stone-wall » ;
  - eau au nord et au sud : refus, gêne « tile:water » ;
  - position préférée bloquée, 2e libre : agrandissement au nord-est (530,5 ; 249,5), rang 2 ;
  - cas W (eau au nord, coffre au sud) : contour sur la sud-ouest (rang 3, gêne « iron-chest »), puis, le coffre
    retiré, agrandissement à cette position (489,5 ; 270,5) ;
  - personnage écarté (F71), objet au sol sorti (F75), fantôme retiré par le moteur (F74), minerai sous la
    préférée de P : agrandie au rang 1, minerai valide ;
  - chaîne 6 → 30 : 24 améliorations, 4 agrandissements, 0 secours ; centres successifs (469,5 ; 289,5) en
    3×3, (470 ; 290) en 4×4, (469,5 ; 289,5) en 5×5, (470 ; 290) en 6×6 : le niveau 30 est revenu au centre
    d'origine (règle de parité), avec ses 20 chargeurs ;
  - compteurs finaux : 13 contours, 13 refus, 8 agrandissements, 0 objet renversé, 0 échec de remplacement,
    0 placement forcé, 0 objet laissé sous un bâtiment ; contours effacés par le moteur (0 rectangle au tick 3000).
  - `content-final` (worktree, commit `3b06952`, 14 h 46) avait donné le même bilan.
- Mutations (copie jetable du worktree) : à la relecture du premier commit, 24 jouées, 15 tuées ; après
  correction, **24 jouées, 23 tuées, 1 équivalente** (`was_cc` dans la migration : `create_entity{raise_built}`
  appelle `on_built`, qui suit déjà le centre ; la double mutation `was_cc` + `on_built` est tuée, 2 échecs).
- Étape data réelle sur une copie jetable où les 6 familles sont activées par leur seule ligne : 0 erreur,
  0 violation. Niveau 25 : la foreuse dépose en (−0,5 ; −3,35), extrait sur un rayon de 3,99 (8×8 tuiles),
  raccords en (−3,5 ; −0,5), (3,5 ; −0,5) et (−0,5 ; 3,5) ; l'assembleur a ses raccords en (−0,5 ; ±3,5) ; la
  collision des quatre familles 6×6 vaut ±2,7 ; la portée du laser vaut 32. Centre 15 (8×8) : collision ±3,7.
  Côté tests, la même copie casse 3 attentes de `levels_test` (relevé à 24 niveaux, « 5 fours niveau 25 ») et
  `migration_test` (le moteur simulé n'a pas `get_control_behavior` sur une foreuse).
- Bancs hors jeu rejoués sur `main` après l'intégration (22/10, 14 h 51 à 14 h 55) : run 114, war 92, td 270,
  pteam 15, **migration 50** (29 avant V3-T), **levels 1 564** (1 459) + 11 écarts connus, pvp 596 (179 s), epochs
  16 665, org 362 ; étape data : 911 prototypes, 0 erreur nouvelle, 0 violation, 0 clé manquante ; **api_lint 434
  usages, 0 erreur** (le lot annonçait 437 avec le même diff ; écart de 3 non expliqué) ; d4m **4/5** : l'étape
  « vram.py sur 13 journaux archivés » échoue AUSSI sur l'ancien `main` (`91097e6`, rejoué le 22/10 à 14 h 56 dans
  un worktree jetable, puis de nouveau à 15 h 10 par le correcteur des documents : 4/5, code 1, même étape ;
  aucun fichier de l'outil d4m ne diffère entre `91097e6` et `13b4134`) : elle exige 15 atlas par journal, et les journaux D4m 3
  à 5 (qualité normale et plancher) en ont 14. Défaut de l'outil de test, préexistant, sans lien avec V3-T.
  **Corrigé le 22/10 par la suite d4m (E48, F80) : d4m 5/5 sur `main` (rejoué le 22/10 à 17 h 12).**
- Limites (non prouvé) :
  - en moteur réel, le panneau, son aperçu au sol (carré vert, contour orange), le bouton actif pour « no-room »
    et le clic : le mode benchmark n'a pas de joueur ; prouvés en moteur simulé seulement, sans capture ;
  - la migration d'une vraie sauvegarde 0.4.1, avec ou sans montée de version, filet compris (H-T3) : moteur
    simulé seulement (**prouvée en moteur réel depuis, sur une carte de banc : E46, 22/10 ; filet en expérience de
    contrôle seulement ; sans montée de version, c'est `Levels.repair` qui migre, F77**) ;
  - le remboursement F40 inventaire par inventaire : moteur simulé seulement (aucun gestionnaire actuel ne
    détruit le bâtiment neuf) ;
  - le transfert des fluides, du brûleur, de la recette, des fils de circuit et des réglages de foreuse :
    moteur simulé seulement ;
  - les machines agrandies (foreuse, assembleur, four, laser, centre) : étape data réelle seulement, aucun
    runtime ni visuel ;
  - fils de connexion, connecteurs de circuit et image de la zone d'extraction : non déplacés ;
  - visuel PROVISOIRE : le sprite actuel des niveaux (celui de `main`, rejeté le 21/10) mis à l'échelle de
    l'emprise par `kit.sprite_scale` (aucun détail ajouté, ce que D1-4 interdit à terme) ; aucune capture nouvelle après les
    corrections (captures de la phase initiale : `<racine>\fo-logs\2026-10-22_V3T\captures\`, 056 à 063, 109 à
    111) ; le visuel attend le verdict sur V3-S.

**E38 · VALIDÉ, y compris en moteur réel (`content` 212 OK, 0 échec, 22/10, 2 h 43 ; journal « recherche vanilla allégée (QX9) : 170 technologie(s) ») · Amélioration instantanée, condition du centre,
recalibrage sur le calendrier X0, recherche vanilla allégée (lot V2c, 22/10)** :
- Décisions appliquées (citées au §4 d'OBJECTIFS) : Q19 « si on a les ressources, on améliore, terminé » ;
  Q16 « condition légère » ; QX7 « 60 h = ouverture de la Porte (époque 15 vers 52 h) » ; QX9 « alléger la
  recherche vanilla des premières époques » ; QX10 (arbitrage de l'architecte) : une seule source pour le
  calendrier, passage du centre ≈ 10 % du budget.
- Décision de l'implémenteur (sauvegardes) : un chantier 0.3.0 ou 0.4.0 en cours est ACHEVÉ au chargement,
  pas annulé et remboursé (coût déjà payé ; Q19 ; un remboursement entier pourrait déborder du coffre).
- Protocole du recalibrage : `lua5.2 tests/levels_test.lua --calibrate` lit le calendrier X0 (durée, débit
  moyen, budget), garde les hypothèses de V2 (30 % de la production pour les niveaux, base de référence) et
  résout, époque par époque : panier du centre (époque 1), `cc_value` (10 % visés, borné par la place et par
  la croissance stricte), `value_mult` (le reste du budget).
- Résultats (après correction) : durée impliquée de chaque époque à 1,5 % près de X0 ; époque 15 à 52 h 36,
  Porte à 59 h 35 (X0 : 52,5 h et 59,5 h), pour la base de référence COMPLÈTE. **Passage du centre : 23,2 %,
  9,95 %, 5,6 %, 7,4 % du budget aux époques 1 à 4, puis 3,35 % → 0,11 %** : QX10 NON CONFORME après
  l'époque 4. Cause chiffrée : la monnaie de l'époque 8 (baril de méthane, 100 u par case) borne le passage
  8 → 9 à 8 310 u (10 % visés : 221 575 u ; 9 300 u même à 50 % du coffre sans plafond de quantité) et, par
  la croissance stricte, tous les passages précédents. Pire coût : 45 % du coffre payeur (centre 12 → 13).
- Chemin le plus court (mesure ajoutée au banc par la correction) : centre + un bâtiment de chaque famille
  possédée monté au niveau visé (Q16) : centre 15 en **3 h 27** avec 30 % de la production X0 (1 h 02 avec
  100 % ; centre seul : 2 h 20), contre 52 h 30 au calendrier ; époques 7 à 14 en 6 à 10 min chacune. Le
  calendrier n'est tenu que par la base de référence complète : écart connu au contrat QX7, lié à QX10.
- Essais écartés (chiffrés) : un panier des bâtiments × 2,75 à l'époque 1 faisait déborder les époques 2 à 4
  de 33 à 84 % (monotonie et rattrapage) ; d'où le panier du centre qui comble l'époque 1 (23 %).
- QX9 : `data-final-fixes.lua` exécuté hors jeu sur les 192 technologies de `technology.lua` : 170
  allégées (automatisation 10 → 1, acier 50 → 8, pétrole 100 → 4, logistique 20 → 18, pack utilitaire
  100 → 25), char (époque 5) et 9 recherches infinies inchangés. Étape data RÉELLE : la vérification a trouvé
  169, `fluid-handling` restant à 50 unités (F68) ; corrigé (barils générés ignorés), `levels_test` rejoue
  désormais le harness : `fluid-handling` à 2, journal « 170 technologie(s) ». Part du budget X0 de cette
  recherche, payée en packs vanilla (MU du modèle X0) : 17,8 / 15,9 / 14,1 / 13,2 % aux époques 1 à 4 (X0 :
  17,5 % avec ses fenêtres de packs).
- Correction après vérification (2 vérificateurs, 13 problèmes ; correcteur, 22/10) :
  - garde de dress : la sonde probe_x (un `dress` qui écrit `X.VANILLA_UNIT_SCALE[3] = 3`) était acceptée et
    `automation` passait de 1 à 30 unités ; la config recopie désormais au chargement ce qu'elle lit dans X,
    et la garde compare X à la fermeture de chaque famille (refus motivé ; coût : 0,017 à 0,021 s par étape
    data, 5 passes) ;
  - recensement Q16 : 12 `count_entities_filtered` sans zone à chaque rafraîchissement du panneau du centre
    (toutes les 30 ticks) ; mis en cache par force dans `global` (construction : mise à jour exacte ; retrait :
    invalidation ; expiration 600 ticks ; chaque décision recense en entier). Moteur simulé : 10 aperçus =
    1 recensement, panneau ouvert 300 ticks = 0 ;
  - `--calibrate` n'était pas un point fixe (relancé depuis la config : panier 310/150/150/60 au lieu de
    315/155/155/60, 7 `cc_value` différents) et le panier écrit (930 u) n'était pas celui payé (960 u) : il
    part désormais d'un état de référence fixe, la config livrée est sa sortie (testé), panier 310/160/160/60
    payé tel quel ;
  - tests ajoutés (mutants M10, M18, M19 de la vérification, désormais tués) : paiement mixte centre puis
    joueur, chantiers 0.4.0 à cible invalide remis en service, rangée de murs mixte avec centre adverse
    approvisionné ; 12 mutants ciblés de la correction : 11 tués, 1 équivalent (calibrage déjà au point fixe).
- Bancs (après correction) : levels_test 1 459 OK et 11 écarts connus comptés à part (QX10 aux époques 5 à
  14, QX7), migration_test 29 OK (27), run 114, war 92, td 270, pteam 15, epochs 16 665, pvp 596 ; étape
  data : 911 prototypes ajoutés ou modifiés (200 technologies), 0 erreur, 0 violation, 0 clé manquante ;
  api_lint 362 usages, 0 erreur. Fusion simulée avec main (8dbfba6) sans conflit : org_test 362, d4_dryrun
  11 OK, étape data 0 erreur, api_lint 377 usages 0 erreur.
- Non fait : banc `content` en moteur réel (réservé à l'orchestrateur ; attendu 212 OK) ; panneau jamais vu à
  l'écran ; coût d'UN recensement Q16 sur une grande carte non mesuré (H-L1) ; QX10 non tenu (Q-V2c-1).

**E43 · VALIDÉ (comme outil de mesure ; la charte reste à valider par le DC) · Charte de direction artistique mesurée sur le vanilla (lot V3-S, 22/10, 7 h 20 à 7 h 42)** :
- Protocole :
  - mesurés : 28 bâtiments vanilla 1.1.91 (sprites hr, couches et décalages lus par `harness.lua
    --dump-proto`), la cheminée V0 validée (commit `4599023`) avec sa version V0b, et les 100 aperçus
    rejetés de V3 phase 1 ;
  - même code partout (`tools/da/da_lib.py`) : 64 px par tuile, corps seul ;
  - 23 indicateurs : détail D1 à D5, patine P1 à P4, palette C1 à C8, lumière L1 et L2, masse M1 à M3.
- Résultats :
  - **loi vanilla : pièces ≈ 29,5 × masse**, en tuiles² de corps (pente log-log de 0,997) ; la densité
    est constante du coffre 1×1 au silo 9×9 (mitrailleuse 156 pièces, réacteur 509, silo 1 885) ;
  - un bâtiment vanilla échoue à 1 seuil sur 23 en médiane ; la cheminée V0 passe tout ce qui
    s'applique à une pièce. L'étalonnage tient ;
  - V3 phase 1 : 0 niveau sur 100 ne passe, 9 seuils échoués en médiane. De l'époque 2 à 15, la
    mitrailleuse garde sa masse (×1,01) et perd ses pièces (×0,43) ; la dominance n'est tenue que sur 2
    paires d'époques sur 13. Les corps blanchissent (luminance p50 jusqu'à 123, vanilla ≤ 76).
  - Mesure déterministe : deux passes donnent des JSON identiques à l'octet (4 s pour le vanilla, 15 s
    pour les aperçus).
- Intégration (13 h 25) :
  - `docs/DA_FACTORIO.md`, `docs/da/` et `tools/da/` ;
  - relancés depuis le dépôt avec `py -3.9`, `seuils.py`, `analyse.py` et `progression.py` redonnent les
    fichiers d'origine à l'octet ;
  - le `python` 3.14 par défaut n'a pas numpy.
- Limites (charte §2.3) :
  - indicateurs approchés : D3 compte aussi la rouille ;
  - halo de nuit non comparable, car le vanilla éclaire par des `LightDefinition` ;
  - une seule pose, sans animation ;
  - regard naïf jamais testé sur des personnes.
- Questions ouvertes : Q-S1 à Q-S3 (charte §9).

**E42 · Résultat mitigé · Stable Diffusion local, pour des images de concept (22/10, 7 h 25 à 7 h 50)** :
- Installation : AUTOMATIC1111 (version AMD v1.10.1) avec ZLUDA, sur la RX 6900 XT. Modèles présents :
  DreamShaper 8 (SD 1.5), DreamShaper XL 2.1 Turbo (SDXL) et SD 1.5 de base. Ni ControlNet ni LoRA.
- Lancement : serveur d'API seul, hors ligne, priorité basse, sorties redirigées. Rien n'a été installé
  ni téléchargé, et aucun fichier de l'installation n'a été modifié. Seul le cache de ZLUDA a grossi de
  3 Mo.
- **Incident** : au premier lancement, le serveur a écouté sur toutes les interfaces du réseau local
  pendant environ 1 min, avant d'être relancé en local seulement (127.0.0.1).
- Mesures :
  - SDXL Turbo en fp16 : 17 à 19 s par image en 1024×1024 ;
  - avec le réglage fp32 de l'utilisateur : 15 à 18 s PAR PAS, car la mémoire vidéo déborde ;
  - SD 1.5 : 7 s par image, inutilisable (aucune tourelle).
- Jugement :
  - utile pour l'INSPIRATION : rouille et rivets crédibles, masse, canons multiples. Les images
    « légendaires » donnent une vraie impression de puissance ;
  - défauts : caméra instable, ombres vers l'ouest (l'inverse de Factorio), « 6×6 » ignoré, palette
    brune uniforme, détails illogiques de près ;
  - échecs nets : aucune progression dans une série (copies identiques) ; une « machine 6×6 » qui n'est
    qu'un champ de tuyaux ;
  - piste la plus utile : img2img depuis un sprite existant, à un débruitage de 0,55. Il garde la caméra,
    la silhouette et la palette, et ajoute du détail.
- Jamais un sprite final : une image 2D isolée n'a ni cohérence entre directions ni calques séparés.
- Planche et journaux : `<racine>\fo-logs\2026-10-22_SD-test\`.

**E41 · VALIDÉ · Budget A1 avec le PvP, banc épinglé (22/10, 3 h 10)** :
- `ia0-perf` : 216 000 ticks, 4 factions, 50 compagnons, difficulté Normale, conditions d'E21.
  - Script : 0,108 ms/tick en moyenne, p99 0,699, maximum 13,9 ms.
  - Tick complet : 0,468 ms (p99 1,646).
  - 92 ticks de script au-dessus de 2 ms sur 215 399, tous attribués (act, team, chemins).
  - Étalon machine : médiane 2,52 ms.
  - E21 donnait 0,14 ms (p99 0,86).
- `ia0-big` : base de 5 022 entités sur 31 secteurs, 40 min.
  - Script : 0,059 ms/tick (p99 0,489).
  - Tick complet : 0,339 ms (p99 2,29 ; maximum 103 ms, dû au générateur de carte, pas au mod).
- `pvp:scan` : 0,0043 ms/tick en moyenne dans les deux bancs.
- Journaux et analyses : `<racine>\fo-logs\2026-10-22_A1_*`.

**E40 · VALIDÉ · Mémoire vidéo et usine géante en moteur réel (lot D4m, 22/10, 2 h 50 à 3 h)** :
- Protocole : greffon `d4-geant` (6 672 bâtiments à niveaux, 7 072 tapis, 6 088 bras sur 288 × 188 tuiles).
  Sur chaque passage, deux mesures :
  - compteurs GPU de Windows, sur le seul processus de test ;
  - UPS par phase de vue.
- Résultats (sprites actuels, avant V3) :

  | Passage | Mémoire dédiée, pic | Mémoire dédiée, moyenne | Atlas estimés | Mémoire vive privée, pic |
  |---|---|---|---|---|
  | Haute qualité | 1,59 à 1,70 Go | 1,47 Go | 1,10 à 1,25 Go | 3,7 à 3,9 Go |
  | Normale | 0,67 Go | 0,61 Go | 0,40 à 0,45 Go | 1,95 Go |
  | Plancher (normale, mémoire faible, compression basse) | 0,42 Go | 0,39 Go | 0,20 à 0,31 Go | 2,05 Go |

  Plancher : atlas estimés 0,20 à 0,31 Go hors atlas virtuel ; 0,28 à 0,53 Go en comptant ses pages (lot R1, 22/10,
  E55).

- UPS : 60,0 à 60,1 dans les 4 vues (zooms 0,3 et 0,5, jour et nuit). La plus chargée montre 2 588
  bâtiments à niveaux, 2 800 tapis et 2 598 bras en 1920×1080.
- Images/s : non mesurées. Avec `--output-perf-stats`, le jeu n'a écrit aucun fichier. VSync est actif sur
  un écran à 144 Hz.
- Chargement avec le cache d'atlas : sprites chargés en 3,3 à 4,5 s.
- La carte occupe 4,3 Go au total, tous programmes confondus.
- Journaux : `<racine>\fo-logs\2026-10-22_D4m_*`.

**E39 · VALIDÉ (technique) · Pipeline de rendu corrigé, en moteur réel (lot V0b, 22/10, 2 h 40)** :
- Mesures sur les captures en jeu, z2 de jour, corps hors lueur :

  | Mesure | V0 | Premier essai | Corrigé | Références vanilla |
  |---|---|---|---|---|
  | p50 | 0,237 | 0,338 (rejeté : trop clair) | 0,205 | assembleur 0,198, four éteint 0,191 |
  | Écart-type | 0,131 | 0,165 | 0,138 | cheminée vanilla 0,142 |
  | Rapport au four porteur | 1,24 | 1,77 | 1,07 | maximum 1,3 |

- Halo du four équipé : écart du trou au voisinage 0,245 → 0,011, en qualité haute comme normale.
  Façade : λ 0,064, contre 0,090 pour le four vanilla. Four éteint : aucune flaque.
- Collerette : 49 → 0 pixel transparent enfermé.
- Braises : rapport bleu/rouge 0,42 → 0,02 (feu vanilla : 0,10).
- Recalage au pixel ; phases de caméra au zoom 1 : |ΔL| ≤ 0,02/255.
- Déterminisme 18/18 ; `content` 212 OK après fusion.
- Le premier essai, plus clair, s'éloignait du style validé : le correcteur est revenu au ton V0.
  Les règles 1 à 3 de la bible sont maintenant bloquantes dans `render.py` (code 3).
- Planches V0 / premier essai / corrigé envoyées au Directeur Créatif : `<racine>\fo-logs\2026-10-21_V0b_vitrine-final\planches-dc\`.

**E37 · VALIDÉ (hors jeu) · Conception des équipes de PNJ organisées (lot IA1, 22/10, 1 h 15)** :
- 3 concepteurs (organisation, joueur, technique), relancés après la précision Q19.
- 2 juges ; gagnante : la conception technique (82 points, contre 77 et 75).
- 2 critiques : 10 majeurs et 14 mineurs, corrigés (§19 bis du document).
- Modèle pur `shared/team/org.lua` et `tests/org_test.lua` : **362 OK**. Il vérifie :
  - des affectations déterministes et stables (6 changements par heure au plus) ;
  - qu'une tâche n'est jamais interrompue ;
  - les urgences, les zones, la résurrection, les rangs ;
  - les jetons de travail globaux (400 unités par tick pour tout le mod).
- Mesure sur le journal archivé `ia0-normal` : 24 % d'ouvriers inactifs après 30 min ; à 59 min, 7 sur 28
  seulement construisent ou fabriquent. La limite actuelle est le manque de travail, pas le coût.
- Budget estimé : 0,26 ms/tick pour 150 PNJ (estimation haute : 0,33). Non mesuré en jeu.

**E36 · VALIDÉ · Bases défendues attaquées, en moteur réel (lot IA0b, 22/10, 0 h 53 à 0 h 55)** :
- `ia0-defendue` (Normal, 3 tourelles, défense 24, 60 min) : **11 OK, 0 échec**. Attaques d'Écarlate
  (tick 96 601, 16 soldats), d'Ambre (143 405, 21) et d'Émeraude (162 605, 21).
- `ia0-defendue-forte` (Normal, 12 tourelles, défense 96, 60 min) : **13 OK**. Écarlate attaque au tick
  72 001, puis revient avec 29, 40 et 46 soldats ; la défense estimée tombe de 96 à 8, puis à 0.
- `ia0-defendue-impitoyable` (6 tourelles, 40 min) : **14 OK**. Assaut coordonné : fenêtre ouverte par
  Écarlate au tick 50 700 sur (-88, 10). Ambre (51 004) et Émeraude (56 405) le rejoignent sur la même
  cible, marqués « (assaut coordonné) ». Écarlate ouvre ensuite 4 fenêtres de plus.
- Banc `content` sur le même `main` : 209 OK.
- Non mesurés : le budget A1 (`ia0-big`, `ia0-perf`) ; le témoin négatif en moteur réel (il est fait en
  moteur simulé : 1 et 2 échecs avec le code IA0).

**E35 · VALIDÉ · Garde de dress complète (lot V2b)** :
- Hors jeu : `levels_test` 1 325 OK.
  - 81 cas de garde (15 acceptés, 66 refusés), chaque motif de refus vérifié ; plus 42 sondes de config.
  - 4 mutants de la garde, tous détectés.
- Coût sur l'étape data : +0,03 à 0,06 s instrumentés, et +66 Mo de pic de tas pendant `generate`.
- **Moteur réel** : `content` 209 OK avec les fichiers de famille chargés sous la garde (`require` dans
  `Common.generate`, accepté par le vrai chargeur).
- Faits outillage :
  - `os.clock` du lua5.2 Windows mesure l'horloge murale ;
  - le Lua 5.2.4 hors jeu tire la graine de hachage au hasard, donc l'ordre de `pairs` y varie d'un
    processus à l'autre. Le Lua de Factorio, lui, est déterministe. Les 3 boucles de prototypes qui
    produisaient des listes dans l'ordre de `pairs` sont triées depuis le 22/10
    (`enemies.lua`, `arsenal.lua` ×2).

**E34 · VALIDÉ (hors jeu) · Graphe de fabrication des 15 époques et des branches (lot X0, 21/10, 21 h 15)** :
- Conception par 3 concepteurs aux angles différents (récit, systèmes de production, rythme), notés par
  2 juges. Gagnante : « La Caustique d'Érèbe » (102 points, contre 99,5 et 98), enrichie des meilleures
  idées des deux autres.
- Relecture par 3 critiques adverses (fidélité, moteur, équilibre) : 45 problèmes, dont 19 majeurs ou
  bloquants, corrigés en version 2.
- Banc `tests/epochs_test.lua` : **16 665 OK, 0 échec**. Il contrôle :
  - que tout objet se fabrique depuis les ressources de la carte ;
  - l'absence d'anachronisme et d'énergie ou de matière gratuites ;
  - les limites de la doc 1.1.91, dont il relit 13 phrases ;
  - la cohérence avec la config des niveaux (V2) et des factions (IA0).
- Contre-épreuve : 3 défauts injectés (énergie gratuite, anachronisme, recette supprimée) sont tous
  détectés.
- **Rien n'existe en jeu.** Les mécaniques à risque sont listées au §8 du document : torchère à recette
  automatique, foreuse sur une ressource créée par script, chaleur à 5 000 °C, labo à 19 entrées…
- Hypothèse **H-X1 · OUVERTE** : le coût de script des systèmes X reste ≤ 0,05 ms/tick.

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
- Rapport : `<racine>\fo-logs\2026-10-21_V0_verif-captures\rapport.md`.
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
- **H-T4-1 · OUVERTE** (lot V3-T4, E60, F111 ; 22/10) : la mitrailleuse plafonne à 30 tirs/s parce que son
  `attacking_speed` vaut 0,5 (une image d'attaque toutes les 2 ticks). Cause non prouvée ; la doc 1.1.91 ne dit rien de
  ce plafond. Protocole proposé par l'intégrateur des documents (non joué) : sur une copie jetable de la mitrailleuse,
  faire varier `attacking_speed` (0,5 ; 1 ; 2) à délai fixe sous 2 ticks, et mesurer la cadence comme dans E60. Sans
  objet tant que les tourelles portent R par les dégâts.
- **H-T3 · (1) prouvée en moteur réel ; (2) prémisse réfutée (F77) ; filet prouvé seulement en expérience de
  contrôle** (suite H-T3, E46, 22/10, commit `d6ba888` ; journaux dans
  `<racine>\fo-logs\2026-10-22_V3T-suites\ht3\correcteur-d6ba888\` ; rejouée sur `main` le 22/10 à 17 h 06 :
  `<racine>\fo-logs\2026-10-22_V3T-suites-integration\ht3-migration\`).
  - Une carte est créée par 0.4.1 (`git archive 91097e6`), puis rejouée par 0.4.2 sur la même carte grâce à la
    double source du banc (`FO_CREATE_SRC`). Elle contient 13 mitrailleuses posées en 2×2 et un centre 15, dont
    deux défenses types en force player (ligne de murs, bras à combustible nourri par convoyeur ou par coffre).
  - Après migration : 6 sont reposées à la position de la règle (candidate 1 pour libre7, libre19 et defense7) ; 2
    de côté pair sont déjà en place (même entité) ; 3 sont laissées faute de place (murs et coffre ; eau ; murs
    collés et bras) ; 2 de niveau 1 à 6 sont inchangées. Munitions case par case et PV en proportion conservés,
    aucun chevauchement. Le bras vise la tourelle reposée et la nourrit encore (F79). Le relevé est écrit.
  - Contrôle du journal (`ht3_journal.py`) : une ligne « laissé en place » par mitrailleuse laissée, une seule
    ligne de bilan, de la voie attendue. Le filet reste sans effet une fois le relevé à jour (garde vérifié
    jusqu'au tick 600). Résultat : 29 OK, 0 ECHEC, et journal 7 OK dans les trois voies.
  - (1) Montée de version : migration par `on_configuration_changed` (0.4.1 -> 0.4.2). PROUVÉE.
  - (2) Version non montée : `on_configuration_changed` est QUAND MÊME appelé, avec `mod_changes` vide (F77), et
    c'est `Levels.repair` qui migre. La prémisse « le filet migre » est donc fausse. Le filet n'a été exercé
    qu'en expérience de contrôle (migration au chargement neutralisée dans une copie jetable) : 29 OK.
  - **Constat** : une mitrailleuse collée à une ligne de murs et nourrie par un bras placé derrière reste hors
    grille, en service, chevauchement toléré (rempart7). Question au Directeur Créatif (Q-T3, OBJECTIFS §4) : est-ce
    acceptable, ou faut-il une autre règle (par exemple déplacer aussi le bras) ? Depuis le lot V3-T2 (22/10,
    19 h 05), Q-T3 est rattachée à Q-T2-1 : même nature, pour toutes les familles (18 machines sur 24 d'une usine
    dense restent hors grille, E50).
  - Non prouvé : rechargement d'une carte déjà migrée ; défense dense ; amélioration ultérieure d'une tourelle
    laissée hors grille ; crochets `on_replaced` et chantiers 0.4.0 en moteur réel (liste complète : E46). Depuis le
    lot R1 (22/10, 20 h 11) : défense dense JOUÉE en moteur réel (E54 : 13 tourelles sur 21 laissées depuis 0.4.1, 5 sur
    21 depuis 0.4.2, toutes en service) ; le reste toujours non prouvé.
  Énoncé et protocole d'origine (22/10, 14 h 56, alors OUVERTE ; lot V3-T, E44 ; nom repris du lot V3-T, H-T2
  n'est attribué à rien) : en moteur réel, une vraie sauvegarde 0.4.1 chargée avec la version 0.4.2 repose bien ses mitrailleuses de niveau 7 et plus à leur nouvelle emprise. Voie normale : la
  montée de version déclenche `on_configuration_changed`, puis `Levels.repair` et `Levels.migrate_footprints` ;
  à défaut (version non montée), le filet `on_nth_tick(30)` migre au premier passage si
  `Levels.footprints_stale()` voit que le relevé `global.fo.levels.footprints` diffère de la table. Attendu :
  bâtiment reposé à la première position libre (contenu, PV en proportion, crochets `on_replaced`, centre
  suivi), laissé en place et journalisé sans place, second chargement sans effet.
  Aujourd'hui prouvé en moteur simulé seulement (`migration_test`, 50 OK). La doc 1.1.91 ne cite pas le
  changement d'une `collision_box` parmi les déclencheurs de `on_configuration_changed`, d'où le filet.
  Protocole proposé (outillage à écrire) : le banc crée la carte (étape `create`) avec la source 0.4.1 (worktree
  jetable au commit `91097e6`), y pose des mitrailleuses de niveaux 7 à 30 (dont deux voisines collées, une
  sans place, et des munitions), puis la rejoue (étape `benchmark`) avec la source 0.4.2 ; une seconde passe
  rejoue la même carte avec le code 0.4.2 dont `info.json` garde 0.4.1 (aucun changement de version : le filet
  seul). La sauvegarde de test vit dans le dossier d'écriture
  du banc (`fo-autotest\`), JAMAIS dans `<racine>\saves\`. Contrôles : positions, munitions, PV, ligne
  « [FO-LEVELS] mise à jour des emprises » (montée de version ; écrite seulement si un bâtiment est reposé ou
  laissé) ou « [FO-LEVELS] emprises (filet, sans changement de version) » (seconde passe), compteurs
  `levels_status`.
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
  panneau ouvert. Il n'a pas encore été mesuré au benchmark épinglé. **Mise à jour V2c (22/10)** : plus de
  chantiers ; le coût à mesurer devient celui d'UN recensement de la condition Q16 (au plus 12
  `count_entities_filtered{ limit = 1 }` sans zone par surface) sur une grande carte où une famille n'est pas
  possédée (recherche sans résultat sur toute la surface). Depuis la correction V2c, le recensement est en
  cache par force : au plus un par 600 ticks pendant qu'un panneau du centre est ouvert, plus un par décision
  sur le centre et par retrait de bâtiment à niveaux suivi d'un rafraîchissement. Protocole proposé : carte
  d4-geant, panneau du centre ouvert, banc épinglé, `[FO-PROF]` sur 3 600 ticks.
  **Mesure PARTIELLE (lot V3-T2, 22/10, 18 h 46 à 19 h 05 ; défaut 13 de la revue)** : le lot ajoute un abonnement
  `on_tick` permanent, `Levels.resume_progress` (reprise des fabrications en cours après un agrandissement). Son coût
  à liste VIDE, le cas courant, est mesuré par l'interface `levels_bench_resume` (100 000 appels de suite sous un
  `LuaProfiler`, au journal ; banc épinglé `/AFFINITY FFF`) :
  - banc `content` : 9,98 à 12,99 ms pour 100 000 appels, sur 6 passages (`corr-1` à `corr-4`, `corr-final-content`,
    `main` à 19 h 05), soit 0,10 à 0,13 µs par appel ;
  - scénario `t2-machines` : 25,4 à 37,8 ms, sur 4 passages (`corr-5`, `corr-6`, `corr-final`, `main`), soit 0,25 à
    0,38 µs par appel. Cause de l'écart avec `content` non établie (le correcteur l'attribue à une machine chargée par
    d'autres agents ; non vérifié).
  Au pire 0,38 µs par appel du corps de la fonction, soit moins de 0,03 % du budget A1 (1,5 ms par tick) pour un
  appel par tick. Le coût de l'appel de l'abonnement `on_tick` par le moteur à chaque tick n'est PAS mesuré (la
  boucle appelle la fonction directement). Rien ne dépend de cette mesure.
  **Toujours NON mesurés** : le coût avec des progressions en attente, un recensement Q16 sur une grande carte, le
  calcul de place du panneau (V3-T) et celui des points servis (V3-T2). H-L1 reste OUVERTE.
  **Lot V3-T3 (22/10)** : un abonnement de plus, `on_nth_tick(60)` (`Free.check`, demandes « libérer la place » en
  attente ; liste vide : un seul test), et le relevé de la scène au clic (au plus 64 gêneurs, poteaux cherchés jusqu'à
  12 tuiles) : coût NON mesuré (aucune mesure de performance pendant les rendus Blender du lot V3-E).
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
| F3 | Une machine ne complète qu'**une recette par tick**. Vitesse tapis en virgule fixe 1/256. **Confirmé en moteur réel le 22/10** (E62, lot V3-T4, branche non intégrée) : assembleur 30 avec 2 modules de vitesse de palier 10, engrenages : 60,00/s mesurés pour 115,5 demandés. Une foreuse n'a pas ce plafond (F116). | Contraintes codées dans `balance_model.lua`. |
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
