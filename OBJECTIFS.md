# OBJECTIFS : cahier des charges et suivi

> **Rôle du document.** C'est la référence commune entre vous, le Directeur Créatif, et l'équipe de
> développement (architecte, R&D, agents). Il sert à **comparer ce que vous attendez avec ce qui est
> livré**. Chaque objectif donne :
> - **votre demande**, citée ;
> - **ce que nous en comprenons** ;
> - **les critères d'acceptation**, vérifiables en jeu ;
> - **la preuve exigée** ;
> - **l'état réel**, sans complaisance.
>
> **Règles de tenue**
> - Vous corrigez librement les critères. Nous n'en changeons aucun sans votre accord : nous proposons,
>   vous validez.
> - Un critère marqué ❔ est une **proposition, pas encore validée par vous**.
> - Un objectif n'est « ATTEINT » que si tous ses critères sont prouvés en moteur réel (Factorio
>   1.1.91, sur votre PC). Tout ce qui se voit exige en plus **votre verdict sur capture**.
> - **Chaque agent qui livre met ce fichier à jour** : état, preuve, date.
>
> **États**
> - ✅ ATTEINT (prouvé)
> - 🟨 PARTIEL
> - ❌ NON ATTEINT
> - ⏳ EN COURS
> - 👁 À JUGER PAR VOUS : prouvé techniquement, votre avis visuel manque
>
> **Citations.** Les guillemets « » reproduisent vos messages ; (r) signale une demande consignée en
> la reformulant dans le RD_LOG.
>
> Dernière mise à jour : 2026-10-24, vers 7 h 35 (orchestrateur) : **A4-préparation fusionné, version 0.4.10** : éclat
> de tir aux couleurs de l'âge à chaque coup, socle animé en essai sur l'âge 6 ; trois questions pour vous (Q-A4-1 à
> Q-A4-3, §4). Avant : 2026-10-24, vers 4 h 15 : **A3-jeu fusionné, version 0.4.9** : la tête de la
> mitrailleuse des âges 2 à 8 tourne sur 64 positions dans votre partie ; les âges 9 à 15 suivront après la production.
> Avant : 2026-10-24, vers 2 h 45 : **S0-suite fusionné, version 0.4.8** (le tir de
> chaque ère est bien joué en jeu ; volume légèrement baissé aux ères I à IV) ; A3-jeu en reprise après une panne des
> serveurs. Avant : 2026-10-24, vers 0 h 10 : **A3-préparation fusionné ; production des têtes à
> 64 directions lancée à 0 h 00** (768 têtes, 8 à 10,5 h ; §7). Avant : 2026-10-23, vers 23 h 10 : **lot S0 fusionné,
> version 0.4.7** : la
> mitrailleuse a un tir par ère, provisoire, à écouter (https://claude.ai/artifact/Ap4JoXCgvxJJR29b5QceU3 ; question Q-S0-1, §4) ; un
> défaut du lot : des sessions de test ont émis du son sur votre PC vers 21 h 30 à 22 h 15, corrigé (§7). Avant :
> 2026-10-23, vers 21 h 15 : **lot A2 fusionné, version 0.4.6** : la mitrailleuse
> validée est EN JEU (30 niveaux, 4 directions ; §7) ; page https://claude.ai/artifact/DcVt6j6PVctVQteegWJamt . Avant :
> 2026-10-23, vers 18 h 30 (agent des documents du run `wf_2f1793c9-578`) : plan de la suite
> (§6, étapes ; §7, suivi des lots A0, A1, K0, M0) ; **lot A1 fusionné** (outils : rose des 8 directions, E66, E67,
> E70) ; **lot M0 fusionné, version 0.4.5** (monnaies des âges 5, 7 et 8 garanties sur toute carte ; questions Q-M0-1
> et Q-M0-2, §4) ; lot K0 livré, en cours d'intégration. Avant : 2026-10-22, vers 23 h, session 6 (Claude Code,
> orchestrateur) : **lot V3-T3 intégré**
> (version 0.4.4 : bouton « libérer la place », réponse B à Q-T2-1, prouvé en moteur réel, vrais robots compris ;
> limite : dans une rangée de bâtiments collés, seuls les bouts se libèrent) ; **lot V3-T4 livré sur sa branche, NON
> intégré** (réponse A à Q-T2-2 : la densité est tenue, la rentabilité ne l'est pas ; question Q-T4-1 posée, §4) ; suivi
> au §7. Avant : 20 h 21, **lot R1 (robustesse) intégré**
> (défense dense migrée en moteur réel : elle marche, mais 13 tourelles sur 21 d'une ligne 0.4.1 sont laissées : les
> 8 du tronçon A, hors grille, se chevauchent entre elles ; les 5 du tronçon C chevauchent mur, convoyeur, poteaux et
> bras ; à votre jugement, Q-T2-1 ; contact bord à bord des recherches par zone
> observé, moteur simulé aligné, un faux compte d'objets au sol corrigé ; atlas virtuel compté par `vram.py`), suivi
> des lots au §7. Avant : 19 h 20, **lot V3-T2 intégré**
> (version 0.4.3 : toutes les familles grandissent sauf le mur, prouvé en moteur réel ; visuel provisoire laid aux
> grandes tailles ; deux questions nouvelles pour vous, Q-T2-1 et Q-T2-2, §4) ; 17 h 25,
> suites de V3-T intégrées (migration d'une vraie sauvegarde 0.4.1 prouvée en moteur réel, H-T3 ; règle des points
> de jeu du harness et moteur simulé à boîtes vanilla ; banc d4m corrigé, 5/5) ; 14 h 56, lot V3-T intégré (emprise croissante de la mitrailleuse et agrandissement sur place, Q23 et Q24 ; version
> 0.4.2). Session 5 close le 21/10 à 17 h 45.
>
> Documents liés :
> - `CLAUDE.md` : mode d'emploi de reprise ;
> - ARCHITECTURE.md : comment c'est construit ;
> - BALANCE_SHEET.md : les chiffres ;
> - RD_LOG.md : les preuves et expériences.

---

## 0. Règles entre nous (exigences permanentes)

| ID | Exigence | Vos mots | Application |
|---|---|---|---|
| R1 | Rien n'est « fini » sans preuve | « Si tu ne peux pas m'assurer que tout fonctionne, c'est que le travail n'est donc pas terminé. Reprends tout le travail et finalise-le. » | Bancs automatisés en moteur réel sur votre PC, plus captures jour et nuit pour tout ce qui se voit. Chaque résultat chiffré est noté dans RD_LOG. |
| R2 | Les tests se font sans vous | « utilisez mon pc, c'est plus simple, faite vos tests vous-même » | Les bancs (`fo-autotest.bat`, `fo-visual.bat`) tournent dans des dossiers isolés. Vos sauvegardes, votre configuration et votre dossier mods ne sont jamais touchés. |
| R3 | Un résultat abouti, pas un brouillon | « je veux que demain matin le "Factorio V2" / Factorio Overhaul soit PARFAIT » | Les écarts sont écrits ici, même gênants (exemples : D1, B1). |
| R4 | De la précision | « c'est vraiment de la précision que je veux » | Critères visuels jugés en gros plan, aux zooms 1 et 2 : aucun calque décalé, aucune ombre fausse, aucun scintillement. |
| R5 | Pas de complaisance | consigne de rôle | Les défauts sont signalés, y compris dans notre propre travail. |
| R6 | Tout est noté | « notez bien tout (notament dans les objectifs) » | Les décisions vont dans RD_LOG, l'état dans ce fichier, la manière de travailler dans CLAUDE.md. Avant de livrer, un agent met à jour les documents concernés. |

## 1. Contraintes fixes

| Contrainte | Valeur | Conséquence |
|---|---|---|
| Moteur | Factorio **1.1.91**, non modifiable : binaire natif, et la licence interdit de distribuer un jeu altéré | Tout passe par l'étape data (prototypes, images) et l'API runtime (Lua). |
| Mode | Solo avec PNJ ; le multijoueur reste possible | Code déterministe obligatoire. |
| Performance | 60 UPS. Le script du mod reste ≤ 1,5 ms/tick en moyenne sur votre PC (i5-12600KF) | Chaque système est mesuré au banc épinglé. |
| Graphismes | Pièces vanilla recomposées, **et nouvelles images autorisées** (votre réponse à Q2) | Les nouvelles images suivent les conventions du style Factorio, fixées par H-V1 (RD_LOG). |

---

## 2. Tableau de bord

| ID | Objectif | État | Écart principal aujourd'hui |
|---|---|---|---|
| A1 | Performance 60 UPS | ✅ (sauf niveaux) | Coût du système de niveaux non mesuré (H-L1) |
| B1 | Logistique « Compaction ×4 », usines à paliers T1 à T5 | ❌ | **Modèle validé, rien en jeu.** Priorité : tout de suite après le visuel (Q5) |
| B2 | Modules à nombreux paliers | ✅ | — |
| B3 | Déchiqueteurs supérieurs, « nouveaux designs » | 🟨 | Statistiques prouvées ; le design se limite à la teinte, l'échelle et la lueur |
| B4 | Armes, défenses, munitions | ✅ | — |
| B5 | Autres tourelles et lanceurs | ✅ 👁 | Votre verdict visuel manque |
| B6 | Ressources à effets | ✅ | — |
| B7 | Biomes vraiment différents | ✅ 👁 | Votre verdict manque |
| C1 | Guerre « 100 contre 100 contre 100 contre 100 » | 🟨 | 24 à 30 soldats par armée, pas 100 |
| C2 | Des PNJ qui jouent, un cerveau par équipe | 🟨 | Pétrole jamais produit : stagnation après la recherche 3 |
| C3 | Défense de tours activable à tout moment | ✅ | — |
| C4 | PvP | 🟨 | Attaques contre vous, 5 difficultés, bases défendues attaquées, assaut coordonné et budget A1 **prouvés en moteur réel** (22/10). Restent : ordre strict des niveaux non prouvé hors du modèle nominal ; critères C4 encore ❔ (à valider par vous) |
| **C5** | **Équipes de PNJ organisées, environ 30 par faction** | ❌ | Conception livrée et intégrée (IA1, `docs/EQUIPES_PNJ.md`) ; construction après le visuel (Q18) ; 7 questions Q-IA1 |
| D1 | **Des designs qui changent, pas seulement la couleur** | ❌ niveaux, 🟨 ailleurs | Niveaux : teinte + 1,2 % de taille + socle + lueur. Constat du 21/10, 17 h 26. Emprise croissante (D1-4) : mécanique livrée pour toutes les familles sauf le mur (V3-T puis V3-T2, 22/10, moteur réel), avec un visuel provisoire, laid aux grandes tailles (sprite actuel agrandi ×2 à ×3, aucun détail ajouté) ; questions Q-T2-1 et Q-T2-2 ouvertes |
| D2 | Effets lumineux (« glowing ») | 🟨 | Effets la nuit seulement |
| D3 | Précision du rendu | 🟨 | Socle caché sous le four ; aucune revue en gros plan |
| E1 | Échelons façon Clash of Clans (mécanique) | 🟨 | V2c (22/10, corrigé) : amélioration instantanée, condition du centre (Q16), coûts recalibrés sur X0 ; **prouvé en moteur réel** (`content` 212 OK, 22/10, 2 h 43 ; 170 technologies vanilla allégées). **Non conforme** : passage du centre ≈ 10 % du budget (QX10) tenu aux époques 1 à 4 seulement (3,35 % à 0,11 % ensuite, règle de place) ; calendrier de 52 h tenu par la base de référence complète seulement (chemin le plus court : 3 h 27). À trancher : Q-V2c-1 |
| E2 | **Qualité des niveaux : chaque niveau se voit** | ❌ | Même constat que D1 |
| E3 | Boucle « presque idle game » | 🟨 | Mécanismes idle manquants. Plus de chantiers à relancer depuis V2c (amélioration instantanée, Q19) : l'écart « un chantier toutes les 10 s » est sans objet |
| E4 | Interface des niveaux (panneau, touche U) | 🟨 | Jamais vue à l'écran en moteur réel |
| **F1** | **Jeu continu en 15 époques** | 🟨 | Cadre posé et prouvé en moteur réel (V2) ; calendrier unique (X0) recopié par les niveaux, durée impliquée 59 h 35 pour la base de référence complète (V2c, hors jeu ; rien n'impose ce rythme : Q-V2c-1) ; contenu des époques en conception (X0) ; visuel en production (V3) |

---

## 3. Détail des objectifs

### A1 · Performance : 60 UPS
- **Demande** : budget 60 UPS (cadre de rôle).
- **Critères d'acceptation**
  1. Script du mod ≤ 1,5 ms/tick en moyenne.
  2. p99 ≤ 2 ms en jeu normal.
  3. Moins de 0,01 % des ticks au-delà de 16,7 ms, sur 30 à 60 min de jeu.
- **Preuve** : benchmark épinglé sur les cœurs P, avec l'étalon `[FO-CALIB]`.
- **État** : ✅
  - E17 : 0,10 ms en moyenne.
  - E21 : 0,14 ms sur 60 min de guerre.
  - E22 : 0,50 ms avec 402 agents.
  - **Les niveaux ne sont pas mesurés** (H-L1).
  - Toute nouvelle famille, époque ou logistique doit être remesurée.

### B1 · Logistique « Compaction ×4 » et usines à paliers
- **Demande** :
  - paliers logistiques à « vrai saut », validés le 2026-10-20 ;
  - plan des usines à paliers approuvé (r) ;
  - **à faire tout de suite après le visuel** (votre réponse à Q5).
- **Ce que nous en comprenons**
  - 5 paliers de tapis et de machines. Le débit matière est multiplié par 4 à chaque palier : vitesse ×2
    et densité ×2, puis densité seule (BALANCE_SHEET §3).
  - Une chaîne de compaction, avec des objets denses de ρ2 à ρ32.
  - Des foreuses de concentré aux paliers hauts.
  - Une filière énergie qui suit le même rythme.
  - Proposition ❔ : un palier logistique toutes les 3 époques (§6).
- **Critères d'acceptation** ❔
  1. Les tapis T2 à T5 existent en jeu, avec un débit mesuré conforme à BALANCE_SHEET §3 (±2 %).
  2. Les objets denses sont produits et défaits par des machines T2 et T3.
  3. Une usine T5 produit 256 fois plus par tapis qu'une T1, pour un nombre d'entités comparable.
  4. L'énergie suit : aucun blocage électrique imposé.
  5. Chaque palier a un design propre (critères D1).
- **État** : ❌ **Non implémenté.** Il n'existe que le modèle chiffré (`shared/balance_model.lua`) et
  l'hypothèse ouverte H-B1 (plafond des tapis).

### B2 · Modules à nombreux paliers
- **État** : ✅ Vitesse, productivité et efficacité jusqu'au palier 10 ; les 30 modules donnent l'effet
  attendu en moteur réel (E15).

### B3 · Déchiqueteurs supérieurs et nouveaux designs
- **Demande** (r) : « déchiqueteurs supérieurs et nouveaux designs ».
- **Critères d'acceptation**
  1. Les paliers 5 à 8 et les 4 familles existent, avec des contres vérifiés. ✅
  2. ❔ Chaque famille se reconnaît à sa **forme** autant qu'à sa couleur. ❌
- **État** : 🟨 Statistiques et contres prouvés (E15, E19). Le design se limite à la teinte, à l'échelle
  et à une carapace lumineuse la nuit.

### B4 · Armes, défenses, munitions
- **État** : ✅ Banc de contenu en moteur réel, tous contres vérifiés (E15, E18).

### B5 · Autres tourelles et lanceurs
- **Demande** : « plus de contenu (autres tourelles, lanceurs) ».
- **État** : ✅ 👁
  - Tourelle-canon, mortier, tour à arc, pulvérisateur d'acide, lance-grenades, fusil à rail, arc
    portatif.
  - Silhouettes composées de pièces vanilla.
  - **Votre verdict visuel manque.**

### B6 · Ressources à effets
- **État** : ✅
  - Tungstène : minerai dur.
  - Cristal de résonance.
  - Méthane : +12 % de dégâts réels contre un béhémoth.
  - Poison et soin des biomes.
  - **23/10, version 0.4.5 (lot M0)** : ces trois ressources, monnaies des âges 5, 7 et 8, sont GARANTIES sur toute
    carte (un site posé par script à 200-700 tuiles du départ, marqué sur la carte ; une sauvegarde existante reçoit
    ce qui lui manque ; un échec est annoncé et repris). Avant, 3 graines sur 5 essayées pouvaient bloquer la partie
    (RD_LOG E73, E74). Preuve en moteur réel sur `main` : `monde` 89 OK, `m0-reprise` 15 OK, `m0-migration` 9 OK
    (17 h 45). Aspect du site : Q-M0-2 ; partie neuve : Q-M0-1. Accès à pied non garanti sur une carte à beaucoup
    d'eau (7 sites sur 15 non reliés au départ sur ces cartes).

### B7 · Biomes vraiment différents
- **Demande** : biomes « vraiment différents ». Votre retour à 14 h 17 : « ultra vert ».
- **Critères d'acceptation** ❔
  1. Chaque biome se reconnaît sur une capture sans légende, de jour comme de nuit.
  2. Aucun biome ne passe pour une simple teinte d'un sol vanilla.
- **État** : ✅ 👁 Refaits (E23) : cendres gris charbon avec braises la nuit, plaine de cristal vitrifiée
  lilas, marais olive à troncs morts. **Votre verdict manque.**

### C1 · Guerre « 100 contre 100 contre 100 contre 100 »
- **Critères d'acceptation** ❔
  1. 4 factions atteignent chacune au moins 100 combattants en 90 min de jeu au plus.
  2. Les batailles opposent réellement des groupes de cette taille.
  3. Le budget A1 est tenu.
- **État** : 🟨 Économie réelle et guerres réelles : 34 attaques, une élimination à environ 50 min.
  Mais les armées plafonnent à 24 à 30 soldats en 30 à 60 min.
  - **24/10, lot PNJ-VÉRIF (version 0.4.12, RD_LOG E118 à E120, F171 à F174)** : défaut grave trouvé et corrigé, présent
    depuis 0.4.5 : les soldats ne rentraient pas après une attaque lointaine et la faction relançait des attaques vides
    (52 « attaques » pour 5 réelles dans `default`). Après correction : 0 attaque fantôme, 0 soldat loin du QG à 59 min
    (17 rappels, 17 arrivées), 23 à 48 soldats par faction à 59 min ; les factions fabriquent enfin des tourelles (la
    technologie était mal nommée, « fortify » jamais atteint avant) ; décision d'attaque sur la garnison proche (0 attaque
    sous le seuil). Reste : depuis 0.4.5, 2 factions sur 4 n'attaquent toujours pas dans `default` (3 sur 4 avant la
    correction ; cause non établie) ; groupes amputés à leur création (F174, non corrigé) ; plafond à la recherche 3.
    Guide de partie test pour le DC : `fo-logs\2026-10-24_PNJ\GUIDE_PARTIE.md` (partie réduite `pnj-reduit` 12 OK).

### C2 · Des PNJ qui jouent
- **Demande** (r) : « Les PNJ doivent pouvoir jouer : s'armer, se défendre, participer à l'économie de
  l'équipe en posant des bâtiments. Une mini-intelligence par ÉQUIPE (pas par PNJ) qui sait ce qu'il
  reste à faire et comment, avec un objectif d'équipe (le fer, le pétrole…) ; les IA s'organisent pour y
  arriver et font des crafts. »
- **Critères d'acceptation**
  1. Un seul cerveau par équipe. ✅
  2. Les soldats sont armés de matériel réellement fabriqué. ✅
  3. Les ouvriers posent des bâtiments, minent et fondent. ✅
  4. La recherche est payée en packs. ✅
  5. L'équipe atteint le pétrole et le pack chimique. ❌
  6. ❔ Les équipes IA franchissent elles aussi les époques (F1). ❌
- **État** : 🟨 Prouvé jusqu'à la recherche 3 (E16, E20, E21) ; ensuite, stagnation (H-E1).

### C3 · Défense de tours
- **État** : ✅ (E19)
  - Vagues, boss, familles et récompenses.
  - Défaite détectée.
  - 0,06 ms/tick.

### C4 · PvP
- **Demande** : « TD + PvP ». Réponse à Q4 (21/10, 18 h 07) : « oui (et différents niveaux de
  difficulté) ».
- **Ce que nous en comprenons** : les factions vous attaquent d'elles-mêmes, et un réglage de partie
  fixe la difficulté. Le cessez-le-feu actuel devient le niveau le plus doux.
- **Critères d'acceptation** ❔ (proposés, à valider par vous)
  1. Un réglage de partie offre plusieurs niveaux de difficulté (proposition : Paisible, Facile,
     Normal, Difficile, Impitoyable). « Paisible » garde le comportement actuel (cessez-le-feu rompu si
     vous attaquez).
  2. Hors « Paisible », les factions vous prennent pour cible d'elles-mêmes, après un délai de grâce,
     avec la même logique que contre une faction rivale.
  3. La difficulté règle de façon mesurable le délai de grâce, la fréquence et la taille des attaques
     contre vous, et la part de leurs forces qui vous vise.
  4. Prouvé en moteur réel : une base témoin du joueur est attaquée au niveau « Normal » après le délai
     de grâce, et ne l'est pas au niveau « Paisible ».
  5. Le budget A1 est tenu.
- **État** : 🟨 Lot IA0 intégré le 21/10 à 20 h 45.
  - C4-1 ✅ Le réglage « Factions : difficulté » propose Paisible, Facile, Normal (par défaut),
    Difficile et Impitoyable. Il se modifie en cours de partie avec 2 min de préavis. L'ancien réglage de
    cessez-le-feu est retiré. Une sauvegarde 0.3.0 en guerre garde ses hostilités.
  - C4-2 ✅ Vous devenez une cible comme une faction rivale, et vous êtes prévenu à chaque déclaration et
    à chaque attaque. Deux écarts à la lettre demeurent : la coalition n'agit que sur la part des forces,
    et vous n'êtes jamais traité comme « le voisin ».
  - C4-3 🟨 L'ordre strict des niveaux est prouvé hors jeu. Première attaque en moteur simulé :
    Facile 30 min, Normal 20, Difficile 12, Impitoyable 8,8 ; en moteur réel : Normal 20 min,
    Difficile 12 min.
    - Écart du 21/10 (une base bien défendue n'était jamais attaquée) **corrigé par IA0b** : siège
      (accumulation contre le joueur), rapport de force par niveau et par personnalité, assaut coordonné
      en Difficile et en Impitoyable. **Prouvé en moteur réel** (E36). Facile reste dissuadé dès 2
      tourelles en tech 0, comme prévu.
    - Non prouvé : l'ordre strict hors du modèle nominal (écarts chiffrés dans BALANCE_SHEET §10 bis).
  - C4-4 ✅ **Moteur réel** (E33) :
    - Normal : 1re attaque au tick 72 001, à la fin de la grâce ; base témoin touchée au tick 78 060 ;
    - Paisible : base témoin intacte, 8 bâtiments sur 8 ;
    - Difficile : 1re attaque à 12 min, 6 attaques.
  - C4-5 ✅ **Mesuré sur banc épinglé** (E41, 22/10, 3 h 10) : `ia0-perf` (60 min, 4 factions, 50 compagnons, Normal), script 0,108 ms/tick (p99 0,70) ; `ia0-big` (base de 5 022 entités), script 0,059 ms/tick (p99 0,49) ; repérage PvP 0,004 ms/tick. Le budget de 1,5 ms est tenu.
  - Limites documentées : seule la force `player` est visée ; les installations ne sont repérées qu'à
    1 536 tuiles du départ au plus.

### C5 · Équipes de PNJ organisées (nouveau, 21/10, 21 h 35)
- **Demande** (citation, coupes signalées par […]) : « Au niveau des ouvriers, vous parlez de 6 ouvriers. Pourquoi que 6? […] mettons 4 factions. Pourquoi pas 10 ouvriers par faction? […] tout au début, ça parlait plutôt de 100, joueurs par faction […] peut-être que 100 joueurs, c'est trop, mais prendre, je sais pas moi, 30 de constructions, enfin de PNJ […] par faction, bah, c'était bien, parce qu'en fait, l'idée, c'était vraiment aussi d'avoir une évolution nette, rapide, relativement rapide […] 30 PNJ qui se comporteraient exactement comme des joueurs, qui essaieraient de s'organiser, avec si vous voulez des managers aussi […] qui s'occuperait des ressources, […] de la construction, […] tout ce qui va être automatisé, la construction de tel ou tel objet, […] d'améliorer par exemple les infrastructures existantes […] pouvoir concentrer ses efforts sur collecte de ressources, […] une interface pour vraiment manager en fait ces équipes, […] un conflit en fait de production, un conflit d'évolution également de ressources, qui va réussir à acquérir quelles ressources à certains endroits, un conflit entre les factions, pouvoir s'attaquer, pouvoir également ressusciter des workers, […] à combien ça coûte, la vitesse également des workers, parce que peut-être qu'ils pourront crafter plus vite, s'améliorer plus vite, se déplacer légèrement plus vite aussi, que le joueur principal »
- **Ce que nous en comprenons**
  - « Ouvriers » désigne aujourd'hui deux choses différentes :
    - le **nombre de chantiers d'amélioration simultanés** des niveaux, de 1 à 5 (`L.MAX_BUILDERS`), comme
      les huttes d'ouvriers de Clash of Clans : un réglage de rythme, pas une limite technique ;
    - les **ouvriers PNJ** des factions, de vrais personnages, 10 au plus par faction et 8 pour votre équipe.
  - Votre demande porte sur les seconds : environ **30 PNJ par faction**, 4 factions par défaut, qui jouent
    comme des joueurs et s'organisent avec des **managers** par domaine (ressources, construction,
    production automatisée, amélioration des infrastructures existantes, défense).
  - S'y ajoutent :
    - une **interface de gestion** de votre propre équipe : où porter l'effort ;
    - un **conflit de production et de ressources** entre factions : gisements disputés, attaques ;
    - la **résurrection** des PNJ, avec un coût ;
    - la **progression** des PNJ (vitesse de fabrication, de déplacement et d'amélioration), qui peut
      dépasser celle du joueur.
  - Techniquement, c'est faisable : 402 personnages autonomes ont été mesurés à 0,50 ms/tick (E22), pour un
    budget de 1,5 ms. 4 × 30 PNJ plus votre équipe font environ 150 personnages.
- **Critères d'acceptation** ❔ (proposés, à valider par vous)
  1. Taille des équipes réglable, 30 PNJ par faction par défaut ; nombre de factions réglable, 4 par défaut.
  2. Un cerveau par équipe, et des managers par domaine qui répartissent les PNJ selon les besoins.
  3. Les PNJ construisent de vraies lignes de production automatisées (pas seulement des avant-postes),
     et améliorent les bâtiments existants (niveaux et époques, E3-6).
  4. Votre équipe se pilote par une interface : répartition de l'effort par domaine, priorités, objectifs.
  5. Un PNJ mort peut être ressuscité au centre, contre un coût et un délai chiffrés.
  6. Les PNJ progressent (fabrication, déplacement, minage, inventaire), mesurés contre le joueur.
  7. En moteur réel, 4 factions de 30 PNJ se disputent les gisements et s'attaquent, en tenant le
     budget A1.
- **Précision du Directeur Créatif (21/10, 21 h 45, Q19)** :
  - **Amélioration instantanée** : un PNJ va jusqu'au bâtiment avec les ressources et l'améliore, comme un
    joueur.
  - **Le cœur de la R&D** : une logique de production ADAPTATIVE pilotée par les objectifs, qui s'adapte au
    terrain. Exemple : il faut des circuits rouges → le débit de circuits verts manque → il faut du
    plastique → du pétrole → des pompes et des tuyaux.
  - **Organisation** : des pôles (extraction ; avancement de la base, qui allie tout ; protection) et
    **environ 5 généralistes « couteaux suisses »** sur 30. Ce sont des ouvriers à part entière, qui
    pilotent chacun une partie.
  - **Le joueur** donne l'orientation principale et concentre l'effort.
  - **Contrôle de zones** : par exemple, 2 PNJ posent et ravitaillent des tourelles pour tenir une zone,
    sans gâcher le visuel.
- **État** : ❌ Rien n'est en jeu. **Conception livrée et intégrée** (lot IA1, 22/10, 1 h 15 :
  `docs/EQUIPES_PNJ.md`, modèle pur `shared/team/org.lua`, `tests/org_test.lua` à 362 OK) :
  - organisation : un cerveau par équipe, 3 pôles (Extraction, Base, Territoire), 5 managers de calcul,
    environ 1 généraliste sur 6 (5 sur 30), des exécutants ;
  - réaffectation sans jamais interrompre une tâche ;
  - production adaptative : calcul des débits à partir du but, puis modules d'usine éprouvés posés sur des
    parcelles adaptées au terrain ;
  - territoire (bordure visible seulement en mode Alt), gisements disputés ;
  - interface à 5 onglets (maquettes au §8) ;
  - résurrection chiffrée et progression par rangs (au rang 5 : fabrication ×3, minage ×2,5, course +15 %) ;
  - budget estimé de 0,26 à 0,33 ms/tick pour 150 PNJ ;
  - 12 lots de construction, chacun prouvé en moteur réel ;
  - **cause précise du blocage après la recherche 3 trouvée (H-E1, F67)**.
  Construction : en parallèle de la Compaction, après le visuel (Q18). Questions Q-IA1-1 à Q-IA1-7 au §4. Construction : en parallèle de la Compaction, juste après le visuel (Q18).

### D1 · Des designs qui changent, pas seulement la couleur
- **Demandes**
  - Combiner couleurs, tailles ET nouveaux styles.
  - « c'est surtout la couleur qui change, ce n'est pas un nouveau design » (14 h).
  - « pour le moment je ne vois QUE un changement de couleur/teinte » (21/10, 17 h 26).
  - Réponse à Q1 : « Pièces + 15 époques ».
- **Ce que nous en comprenons** :
  - à chaque **niveau**, une **pièce visible** s'ajoute ou change ;
  - à chaque **époque** (15 en tout), la **silhouette** se métamorphose, comme dans Clash of Clans, où
    un canon niveau 1 et un canon niveau 21 n'ont plus rien de commun ;
  - la couleur n'est qu'un complément.
- **Critères d'acceptation** ❔ (proposés ; Q1 validée dans son principe)
  1. **Test du gris** : une capture de tous les niveaux d'une famille côte à côte, en niveaux de gris,
     au zoom 1. Chaque niveau diffère du précédent par au moins une pièce visible (ajoutée,
     remplacée ou agrandie).
  2. **Test de la vignette** : les 15 époques d'une famille, réduites à 64 px, se reconnaissent et se
     classent dans l'ordre par la silhouette seule.
  3. **Le dernier niveau ne ressemble plus au premier** : silhouettes (masques alpha des sprites)
     communes à moins de 50 % (mesure automatique sur les sprites, voir V4).
     **Faille trouvée le 21/10 (RD_LOG E27)** : tel qu'écrit, ce critère laisse passer un simple
     agrandissement du sprite vanilla, dès ×1,2 à ×1,4, ainsi que la tourelle laser du design rejeté,
     posée sur sa dalle. **Amendement VALIDÉ par vous le 21/10 à 18 h 54** (Q13) :
     - (a) les couches plates posées au sol (socle, dalle) ne comptent pas dans la silhouette ;
     - (b) on ajoute une mesure insensible à la taille : on agrandit le niveau 1 jusqu'à ce qu'il
       ressemble le plus possible au dernier niveau, et le recouvrement restant doit rester sous un
       seuil étalonné sur les premières pièces (proposition : 0,75). Le design rejeté obtient 1,00, c'est-à-dire
       qu'il est refusé.
  4. ~~L'emprise au sol reste la même, pour ne pas changer le jeu.~~ **Révisé le 22/10 (Q23)** : l'EMPRISE
     GRANDIT avec les époques, jusqu'à environ 6 × 6 pour les dernières machines ; la hauteur croît moins. Un
     plus grand bâtiment porte PLUS de détails (densité de détail par tuile au moins égale au vanilla) : ce
     n'est jamais un simple agrandissement d'échelle. Échelle de tailles proposée ❔ : une taille de plus par
     ère (tourelles 2×2 → 6×6 ; machines 3×3 → 6×6 ; centre 4×4 → 8×8 ; mur 1×1). Mode d'amélioration au
     changement de taille : Q24.
     **État de D1-4 (22/10, 14 h 56, lot V3-T intégré, E44)** :
     - 🟨 **mécanique livrée pour la seule mitrailleuse** : 2×2 aux niveaux 1 à 6, 3×3 de 7 à 12, 4×4 de 13 à
       18, 5×5 de 19 à 24, 6×6 de 25 à 30 (une taille par ère de 3 époques ; table `L.footprints`). Prouvé en
       moteur réel (`content` 238 OK, 0 échec, 22/10 à 14 h 51) : agrandissement sur place, refus sans paiement
       et contour, transfert des munitions et des PV, chaîne 6 → 30 revenue au centre d'origine ;
     - ❌ **aucun détail ajouté** : le visuel est PROVISOIRE (le sprite actuel des niveaux mis à l'échelle de
       l'emprise), donc un simple agrandissement, ce que ce critère interdit. Le visuel attend le verdict sur V3-S ;
     - ⏳ **autres familles** : en attente de Q-S1 (charte `docs/DA_FACTORIO.md` : l'échelle vaut-elle pour toutes
       les familles ?). Pour le JEU, activer une famille, c'est ajouter sa ligne dans `L.footprints` : prototypes,
       place, migration et panneau suivent ; l'étape data réelle passe avec les 6 familles activées (0 erreur).
       Côté TESTS, il faudra en plus réécrire 3 attentes de `levels_test` liées à la table livrée et ajouter
       `get_control_behavior` au moteur simulé (`tests/mock_engine.lua`). Aucune machine agrandie n'a tourné, ni
       en moteur simulé avec sa ligne activée, ni en moteur réel.
     - **Mise à jour du 22/10, 17 h 25 (suites de V3-T intégrées, RD_LOG E47)** : côté TESTS, l'activation d'une
       famille se fait désormais par sa SEULE ligne de `L.footprints` : les attentes de `levels_test` et de
       `migration_test` sont calculées depuis la table, et le moteur simulé a `get_control_behavior`, la recherche
       par boîte et les boîtes vanilla. Prouvé HORS JEU sur une copie jetable à 6 familles activées (run 114,
       war 92, td 270, pteam 15, migration 60, levels 1564, org 362, pvp 596, harness 0 erreur, 0 violation,
       0 clé manquante). Le harness vérifie aussi les points de jeu (raccords, dépôts) de toute entité du mod.
       Reste le MOTEUR RÉEL : aucune machine agrandie n'y a tourné (tâche ouverte, §7).
     **État de D1-4 (22/10, 19 h 20, lot V3-T2 intégré, version 0.4.3 ; RD_LOG E49 à E52)** :
     - 🟨 **mécanique livrée pour TOUTES les familles sauf le mur, prouvée en moteur réel** (Q-S1 : oui) : tourelle
       laser et four 2×2 → 6×6, foreuse et assembleur 3×3 → 6×6 (6×6 dès l'ère IV), centre 4×4 → 8×8, mitrailleuse
       inchangée (2×2 → 6×6), mur 1×1. `content` **317 OK, 0 échec** sur `main` (22/10, 19:05:39,98) :
       agrandissement sur place avec transfert réel (recette, contenu, modules, fluides, fabrication en cours,
       orientation, fils et réglages de circuit, barre du coffre), refus sans paiement et contour en usine dense,
       chaînes 6 → 30 et centre 1 → 15, points de jeu servis dans les 4 orientations (même coffre, même tuyau) ;
       `t2-machines` 80 OK ; migration réelle 0.4.2 → 0.4.3 : 64 OK, journal 26 OK ;
     - ❌ **visuel PROVISOIRE et laid aux grandes tailles** : le sprite actuel agrandi ×2 à ×3, flou et pixelisé (four
       et laser 6×6 surtout), aucune pièce nouvelle ; la tête du laser et le haut de la foreuse débordent de leur
       socle vers le haut ; le centre 8×8 déborde de son socle en bas et la tête du radar sort en haut à gauche,
       décalée ; après migration, les machines hors grille se superposent d'une demi-tuile. Captures :
       `<racine>\fo-logs\2026-10-22_V3T2\captures-content\` (`070-niveaux-laser-haut.png`,
       `086-niveaux-drill-haut.png`, `094-niveaux-furnace-haut.png`, `102-niveaux-assembler-haut.png`,
       `052-niveaux-command-01-15.png`, planches 1 à 3), `corr-captures-t2-machines\` (`009-gros-plan-chaines-30.png`,
       `010-gros-plan-centre-15.png`, `006-points-refus.png`), `corr-captures-t2-migration\`
       (`002-migration-dense-assembleurs-fours.png`, `003-migration-dense-foreuses-lasers.png`). Ce critère interdit
       un simple agrandissement : il n'est donc PAS tenu tant que les sprites V3 (lot V3-E) ne sont pas faits.
       Votre verdict manque ;
     - ❓ **deux questions de jeu** (§4) : Q-T2-1 (dans une usine réelle, une machine bordée de ses bras ne
       grandit jamais sans démontage ; 18 machines sur 24 d'une usine dense restent hors grille à la migration) et
       Q-T2-2 (la production par tuile BAISSE quand la machine grandit). **Répondues le 22/10** (B à 21 h 06, A à
       21 h 12) : Q-T2-1 appliquée par V3-T3 (0.4.4, bouton « libérer la place »), avec la limite des rangées collées
       (5 libérables sur 19 dans l'usine dense de test) ; Q-T2-2 appliquée en partie par V3-T4, NON intégrée
       (rentabilité non tenue : Q-T4-1, ouverte).
  4 bis. **Test du regard naïf** (Q23) : un inconnu qui voit deux niveaux côte à côte dit sans hésiter
     lequel est le plus puissant.
  5. Ombres, socles et calques sont alignés au pixel en gros plan (R4).
- **Preuve** : galerie jour et nuit, la même en gris, planche de vignettes, gros plans, mesure
  automatique des silhouettes.
- **État**
  - ❌ niveaux : teinte, +1,2 %/niveau, socle (caché sous le four), lueur et halo la nuit ; seul le
    centre gagne des antennes.
  - 🟨 **four (lot F2, 25/10 au soir, version 0.4.30 de la branche du lot)** : un design par âge aux niveaux 3 à 30 (validé par
    vous sur planches, R-QCM-25h), pièce et teinte au niveau pair, feu animé de la couleur de l'âge ; en jeu, captures
    regardées par l'architecte (`fo-logs\2026-10-25_F2\captures\flaque\`) ; votre verdict EN JEU manque.
  - 🟨 ailleurs : armes spéciales et tourelles lourdes composées ; déchiqueteurs en teinte et lueur.

### D2 · Effets lumineux (« glowing »)
- **Critères d'acceptation** ❔
  1. Des éléments lumineux **visibles de jour** à partir de l'époque 3 environ.
  2. Des animations (pulsation, étincelles, particules) dans les époques hautes.
  3. La nuit, un halo proportionnel au niveau.
- **État** : 🟨 Halos et lueurs prouvés la nuit (E23) ; faibles de jour ; aucune animation propre aux
  niveaux.

### D4 · Optimisation graphique (Q19, 21/10)
- **Demande** : « il faut que ce soit également optimisé […] il faut pas qu'il y ait 1 million de polygones ».
- **Ce que nous en comprenons** : en jeu, nos bâtiments 3D sont des IMAGES pré-rendues (sprites). Le nombre
  de polygones ne coûte que du temps de rendu dans Blender, jamais des images par seconde dans Factorio.
  Les vrais coûts en jeu sont :
  - la mémoire vidéo et la taille des atlas de sprites ;
  - le nombre d'images d'animation ;
  - le poids des fichiers ;
  - le temps de chargement.
- **Critères d'acceptation** ❔
  1. **PC cible : 8 Go de mémoire vidéo au minimum** (votre réponse du 21/10, 21 h 52 ; ce PC en a 16). Les
     atlas de sprites du jeu entier (vanilla + mod), en haute qualité, tiennent dans 6 Go, mesurés, pour
     garder une marge. Les sprites de niveaux sont estimés de 0,8 à 1,4 Go non compressés (V1).
  2. **Basse qualité « pas si basse »** (Q21) :
     - les sprites de qualité « normale » (32 px par tuile) sont RENDUS par le pipeline à leur taille, et
       non tirés d'une réduction floue de la haute qualité ;
     - ils gardent les silhouettes lisibles : les tests D1 (gris, vignette, recouvrement) passent aussi
       en basse qualité ;
     - ils gardent la sensation de gigantisme des usines vues de loin.
     Moins prioritaire que la haute qualité, mais jamais bâclée.
  5. **Vue d'usine géante** (Q21) : un banc pose des milliers de bâtiments à niveaux dans le champ, en vue
     éloignée. On mesure, dans les deux qualités, la mémoire vidéo occupée par le jeu (compteurs GPU de
     Windows) et les images par seconde sur ce PC : 60 images/s visées.
  3. Le chargement du jeu ne s'allonge pas de plus de 30 s (mesuré au banc).
  4. Le temps de rendu hors jeu reste raisonnable : chiffré par famille.
- **État** : 🟨 **mesuré en moteur réel le 22/10 à 3 h** (E40), avec les sprites ACTUELS (avant V3) :
  - D4-1 ✅ provisoire : mémoire vidéo DÉDIÉE mesurée sur le processus de test, haute qualité, pic 1,59 à
    1,70 Go (atlas estimés de 1,10 à 1,25 Go). Le plafond est de 6 Go.
  - D4-2 : qualité normale 0,67 Go ; plancher (normale, mémoire faible, compression basse) 0,42 Go. Les
    sprites basse qualité RENDUS de V3 restent à produire et à juger.
  - D4-5 🟨 : 60 UPS dans toutes les vues de l'usine géante. La plus chargée montre 2 588 bâtiments à
    niveaux, 2 800 tapis et 2 598 bras, au zoom 0,3 en 1920×1080. Les images par seconde ne sont PAS
    mesurées : le jeu n'a pas écrit son fichier de statistiques de rendu.
  - Mémoire vive du jeu : pic 3,9 Go en haute qualité, 2,0 Go en normale.
  - **À remesurer quand les sprites V3 seront en jeu.**
  - Première estimation, tirée des journaux de chargement (F66) : les atlas du jeu actuel (vanilla + mod,
    haute qualité) font environ 1,1 Go avec la compression DXT active par défaut, 4,25 Go sans
    compression, pour 16 Go sur ce PC.
  - Une image n'est chargée qu'UNE fois, quel que soit le nombre de bâtiments posés : une usine
    gigantesque ne coûte pas plus de mémoire vidéo qu'un seul bâtiment ; elle coûte du temps de dessin.
  - Banc de mesure : lot D4m.

### D3 · Précision du rendu
- **Critères d'acceptation** ❔
  1. Aucun calque décalé, aucune ombre fausse, aucun élément caché.
  2. Une revue en gros plan aux zooms 1 et 2 pour chaque famille et chaque époque.
- **État** : 🟨 Défauts connus :
  - socle invisible sous le four en acier (F42) ;
  - trou du halo sur le four équipé de la cheminée V0 (E31) : **corrigé par V0b** (écart 0,245 → 0,011) ;
  - centre de commandement : le radar et les têtes de balise n'ont pas d'ombre (F48, déduit du code,
    non vu en capture ; le centre sera redessiné en V3).
  Aucune revue en gros plan.

### E1 · Échelons façon Clash of Clans (mécanique)
- **Demande** : « niveau clash of clans en termes d'échelons, de qualité de levels… pratiquement idle
  game ».
- **Critères d'acceptation** (1 à 7 prouvés en moteur réel par V2 avant Q19 ; 3, 4 et 8 révisés ou ajoutés
  par V2c, prouvés hors jeu seulement ; mise à jour : passés en moteur réel le 22/10 à 2 h 43, 212 OK, E38 ;
  238 OK depuis V3-T, E44 ; 317 OK depuis V3-T2, 22/10 à 19 h 05, E49)
  1. Un centre de commandement (l'hôtel de ville) plafonne les autres bâtiments.
  2. ~~Les ouvriers limitent les chantiers simultanés.~~ Sans objet depuis Q19 (amélioration instantanée). Les PNJ
     améliorent eux aussi les bâtiments en y apportant les ressources (C5, lot IA1).
  3. Les coûts croissent (les durées n'existent plus depuis Q19) ; les ressources des biomes servent de
     monnaie aux hauts niveaux.
  4. ~~Le bâtiment est hors service pendant son chantier.~~ **Révisé le 21/10 (Q19)** : l'amélioration est
     INSTANTANÉE dès que les ressources sont là, comme poser un bâtiment. Plus de durée de chantier, plus de
     limite d'« ouvriers » de chantier (lot V2c).
  5. Contenu, recette, munitions et santé sont conservés.
  6. 7 familles : centre de 1 à 15, les 6 autres de 1 à 30 (V2 ; 10 niveaux en 0.3.0).
  7. Le bonus de recherche est hérité.
  8. **Q16 (lot V2c)** : le centre ne passe du niveau c à c + 1 que si chaque famille possédée a un bâtiment
     au niveau min(30, 2c) ; le panneau dit ce qui bloque.
- **État** : ✅ Étendu à 15 époques par le lot V2, prouvé en moteur réel (`content` **209 OK, 0
  échec**, 21/10, 20 h 39 ; E32). Le banc couvre :
  - 195 niveaux : centre de 1 à 15, 6 familles de 1 à 30 ;
  - plafond = 2 × le niveau du centre ; ouvriers de 1 à 5 ;
  - chantiers du centre 14 → 15 et de la mitrailleuse 28 → 30 ;
  - règle de place : un chantier tient dans la moitié du coffre du centre ;
  - héritage F21 jusqu'au niveau 30 ;
  - 0 secours manuel.
  La courbe par époque est dans BALANCE_SHEET §12. Q14 à Q16 répondues (21/10, 21 h 25) ; question ouverte :
  Q-V2c-1 (§4).
- **Lot V2c (22/10, hors jeu ; moteur réel NON passé)** (mise à jour : passé en moteur réel le 22/10 à
  2 h 43, 212 OK, E38 ; 238 OK depuis V3-T, E44 ; 317 OK depuis V3-T2, 22/10 à 19 h 05, E49) : amélioration instantanée (Q19 : payée, puis
  remplacement rapide dans le même appel ; plus d'ouvriers, de durées, de bâtiment hors service) ;
  condition du centre (Q16 : refus « cc-families » sans paiement, panneau et interface distante) ;
  chantiers 0.3.0 et 0.4.0 en cours ACHEVÉS au chargement ; coûts recalibrés sur le calendrier X0
  (BALANCE_SHEET §12). Correction après vérification (2 vérificateurs, 13 problèmes) : garde de dress étendue
  au scénario X0 (sonde probe_x refusée), recensement Q16 en cache par force (panneau du centre ouvert :
  0 recensement en 300 ticks ; chaque décision recense en entier), fluid-handling allégée en jeu (barils
  générés), `--calibrate` reproductible (la config livrée est sa sortie), paiement mixte, chantiers à cible
  invalide et rangée mixte testés. Preuves : levels_test 1 459 OK et **11 écarts connus** comptés à part,
  migration_test 29 OK, étape data 0 erreur, api_lint 0 erreur. Diff du banc `content` livré : 63 contrôles
  de niveaux (60 avant), **BILAN attendu 212 OK** (mise à jour : passé en moteur réel le 22/10 à 2 h 43,
  212 OK, E38 ; 238 OK depuis V3-T, E44 ; 317 OK depuis V3-T2, 22/10 à 19 h 05, E49).
  **Non conforme (QX10)** : le passage du centre vaut 23,2 %, 9,95 %, 5,6 % et 7,4 % du budget aux époques
  1 à 4, puis de 3,35 % à 0,11 % (époque 14 : 192 820 u pour 14,5 M u visés, 75 fois moins) : la règle de
  place (moitié du coffre) et des monnaies peu denses (baril de méthane, cristal) le bornent ; l'écart est
  structurel. **Conséquence (QX7)** : le chemin le plus court (centre + un bâtiment de chaque famille
  possédée au niveau visé) atteint le centre 15 en 3 h 27 avec 30 % de la production X0, contre 52 h 30 au
  calendrier : les 52 h ne valent que si le joueur monte toute la base de référence. Remèdes chiffrés
  (BALANCE_SHEET §12) : Q-V2c-1.

### E2 · Qualité des niveaux : chaque niveau se voit
- **Critères d'acceptation** : D1, D2 et D3 appliqués à toutes les familles et à toutes les époques.
- **État** : ❌

### E3 · Boucle « presque idle game »
- **Ce que nous en comprenons** : la progression avance d'elle-même grâce à la production. On revient
  améliorer, les chiffres montent, chaque palier se ressent, et le jeu dure (F1).
- **Critères d'acceptation** ❔
  1. L'usine alimente le centre par tapis, et la progression en découle. ✅
  2. Un score de « puissance de base » s'affiche et croît. ❌
  3. Des objectifs et récompenses par époque. ❌
  4. ~~Une file de chantiers (le suivant démarre dès qu'un ouvrier se libère).~~ Sans objet depuis Q19
     (amélioration instantanée, lot V2c).
  5. Plus de familles à niveaux : tapis, bras, labos, énergie, tourelles spéciales, radars. ❌
  6. Les factions IA et la défense de tours utilisent aussi les niveaux et les époques. ❌
- **État** : 🟨 L'écart chiffré par V2 (un chantier à relancer toutes les 10 s à l'époque 6) est **sans objet
  depuis V2c** : il n'y a plus de chantier, chaque amélioration payable se fait aussitôt. Les critères 2, 3, 5
  et 6 restent à faire.

### E4 · Interface des niveaux
- **Critères d'acceptation**
  1. Le panneau au survol affiche niveau, gains, coût (vert ou rouge) et « amélioration instantanée » ; sur
     le centre, la condition de son passage (niveau visé, familles qui bloquent ; Q16, lot V2c).
  2. La touche U et le bouton « Améliorer » fonctionnent.
  3. Une rangée de murs s'améliore en une fois.
- **État** : 🟨 Testé hors jeu en moteur simulé (levels_test, V2c : panneau, touche U, bouton, rangée de
  murs, condition du centre et recensement en cache). Amélioration instantanée par l'interface distante :
  prouvée en moteur réel par le banc `content` (212 OK le 22/10 à 2 h 43, E38 ; 238 OK depuis V3-T ; 317 OK depuis V3-T2, 22/10 à 19 h 05, E49 ; les
  chantiers de V2 avaient été prouvés en moteur réel le 21/10). **Le panneau n'a jamais été vu à l'écran.**
  Lot V3-T (22/10) : le panneau d'un bâtiment qui va grandir montre la nouvelle taille, dessine au sol, pour
  son seul joueur, la place retenue (carré vert, avec la direction si la position habituelle est prise et que
  le bâtiment s'étend d'un autre côté) ou le contour à libérer (orange, avec ce qui gêne) ; le bouton reste
  actif pour un refus « no-room » (le clic refuse sans payer et dessine le contour 300 ticks). Prouvé en moteur simulé seulement (levels_test),
  sans capture : le mode benchmark n'a pas de joueur.

### F1 · Jeu continu en 15 époques (nouveau, 21/10, 17 h 35)
- **Demande** : « Pièces + 15 époques, comme je le disais, si je veux jouer en continue je veux pouvoir
  avoir des ressources exploitables, de nouveaux batiments etc, ça implique devoir ajouter une grande
  quantité de contenu mais c'est souhaité, c'est l'idée finalement. »
- **Réponses du 21/10, 18 h 07** : Q6 « oui c'est bien » ; Q7 « oui, mais en faite rajoutez carrément
  des branches de matière noire etc, en mode vraiment un truc avancé (il faut donc imaginer le scénario
  et les crafts également évidemment). »
- **Ce que nous en comprenons** (Q6 et Q7 validées)
  - **15 époques = 15 niveaux du centre de commandement.** Comme l'hôtel de ville de Clash of Clans,
    le niveau du centre définit l'époque.
  - Chaque époque ouvre, pour chaque bâtiment, **2 niveaux de plus** (validé, Q6). Les bâtiments
    vont donc jusqu'au niveau 30, et le niveau maximal d'un bâtiment vaut 2 × le niveau du centre.
  - **Branches avancées** (Q7) : en plus des 15 époques du §6, des branches de physique avancée
    (matière noire, et d'autres du même ordre), chacune avec son **scénario** (pourquoi, quoi, quel
    enjeu) et ses **arbres de fabrication** complets. Conception : lot X0.
  - Visuel :
    - le **1er niveau d'une époque** fait changer la silhouette ;
    - le **2e niveau** ajoute une pièce.
  - Chaque époque apporte aussi **du contenu nouveau** :
    - au moins une **ressource exploitable** ou un matériau ;
    - de **nouveaux bâtiments** ou familles ;
    - tous les 3 époques, un **palier logistique** Compaction (B1).
  - ~~Les ouvriers passent de 1 à 5 (un de plus toutes les 3 époques).~~ Sans objet depuis Q19 (amélioration
    instantanée, lot V2c).
- **Critères d'acceptation** ❔
  1. Les 15 époques sont jouables à la suite sur une même carte, sans blocage.
  2. Chaque époque apporte au moins une ressource ou un matériau, au moins un bâtiment nouveau, et une
     silhouette nouvelle pour chaque famille à niveaux.
  3. La durée de jeu visée est longue et croissante. Proposition ❔ : époque 1 en 30 min, époque 15 au
     bout de 60 h cumulées environ. La courbe est à chiffrer dans BALANCE_SHEET.
  4. Les IA progressent aussi en époques (C2-6).
  5. Le budget A1 est tenu à l'époque 15, avec une base de fin de partie.
  6. ❔ Des branches avancées (matière noire, etc.) existent, chacune avec un scénario écrit et des
     arbres de fabrication complets. Chaque objet est fabricable à partir des ressources de la carte,
     ce qui est vérifié automatiquement hors jeu, puis en moteur réel quand la branche est implémentée.
- **État** : 🟨
  - **Cadre posé (V2), prouvé en moteur réel** (voir E1).
  - Durée de jeu donnée par le modèle (lot V2c, calendrier du scénario X0 lu par `L.target`, coûts
    recalibrés) : époque 15 atteinte à 52 h 36 (X0 : 52 h 30), Porte ouverte à 59 h 35 (QX7 : 60 h),
    chaque époque à 1,5 % près de sa durée X0 ; 85 h ou 46 h si la production vaut × 0,7 ou × 1,3. **Non
    prouvé en partie réelle.** (V2 : 60 h 26 sur sa propre courbe, abandonnée.) **Limite** : ces heures
    supposent que le joueur monte toute la base de référence ; le chemin le plus court atteint le centre 15
    en 3 h 27 (30 % de la production X0). Le rythme n'est donc pas imposé (QX10 non tenu, Q-V2c-1).
  - Recherche vanilla allégée (QX9, lot V2c) : 170 technologies vanilla sur 183 à nombre fixe d'unités
    (par exemple automatisation 10 → 1, acier 50 → 8, fluid-handling 50 → 2 après correction : les barils
    générés pour chaque fluide la faisaient passer à l'époque 8). Vérifié sur l'étape data réelle (harness) ;
    non vu en jeu. Payée en packs vanilla, elle prend 13 à 18 % du budget X0 aux époques 1 à 4 (X0 : 17,5 %).
  - 5 matériaux d'époque sont encore provisoires (époques 11 à 15), en attendant X0.
  - X0 livré (21/10, 21 h 15, hors jeu) : « La Caustique d'Érèbe ». Scénario en 4 actes ; 15 époques ;
    4 branches avancées de l'époque 7 à 14 (A matière noire, B antimatière, C chronodynamique,
    D matière étrange), 3 niveaux chacune, avec une merveille au niveau III ; fin de partie : la Porte
    d'Érèbe (silo 10 × 10, 30 min sous 5 GW). Volume : 123 objets, 19 fluides, 80 bâtiments, 15 ressources,
    264 recettes, 78 technologies, soit environ 2 250 prototypes avec les niveaux. Graphe vérifié hors jeu :
    tout se fabrique depuis la carte. **Rien n'est en jeu** (lots X1 à X15). Questions QX1 à QX9.
  - ⏳ V3 (visuel) : en production.

---

## 4. Questions et réponses

| ID | Question | Votre réponse (21/10, 17 h 35) | Conséquence |
|---|---|---|---|
| Q1 | Ampleur du changement de forme ? | « Pièces + 15 époques… » (citation complète en F1) | D1 révisé ; F1 créé |
| Q2 | Nouvelles images (pièces 3D rendues) en plus des pièces vanilla ? | Oui | Règle 8 levée (ARCHITECTURE §2) ; protocole H-V1 |
| Q3 | Par quoi commencer ? | Refaire le visuel des 7 familles | Phase V en premier (§6) |
| Q4 | PvP : les factions vous attaquent-elles d'elles-mêmes ? | 21/10, 18 h 07 : « oui (et différents niveaux de difficulté) » | C4 révisé ; lot IA0 |
| Q5 | Compaction ×4 : quand ? | « Tout de suite après le visuel » | Phase C juste après la phase V |
| Q6 | Combien de niveaux par époque ? | 21/10, 18 h 07 : « oui c'est bien » (2 par époque, soit 30 niveaux) | Lot V2 lancé ; 2 × 15 × familles prototypes et visuels |
| Q7 | La liste des 15 époques du §6 vous convient-elle (thèmes, ressources) ? | 21/10, 18 h 07 : « oui, mais en faite rajoutez carrément des branches de matière noire etc, en mode vraiment un truc avancé (il faut donc imaginer le scénario et les crafts également évidemment) » | §6 validé ; branches avancées, scénario et crafts : lot X0 ; F1-6 |
| Q8 | Machines « pleines » (four, assembleur) aux époques 10 à 15 : pour passer sous 50 % de recouvrement (D1-3), (a) structures ajourées ou en lévitation, (b) bâtiments bien plus hauts (four ~4 tuiles, assembleur ~5,3 au-dessus de l'emprise), ou (c) seuil assoupli pour ces familles ? (bible V1, `docs/DESIGN_EPOQUES.md` §6, question 1 ; proposition de V1 : a) | 21/10, 18 h 49 : « si ajourer veut dire changer le design, c'est oui » | (a) retenu : ajourer = changer la forme (vides, pieds, pièces en lévitation), pas la couleur ; D1-3 reste à 50 % pour toutes les familles |
| Q9 | Plafonds de hauteur à l'époque 15 au-dessus de l'emprise : tourelles +2,4 à +2,6 tuiles, machines +1,5 à +1,6, mur +1,0, centre +3,6. Plus haut = plus spectaculaire, mais cache les bâtiments au nord | 21/10, 18 h 49 : « comme vous le sentez, il ne serait pas déconant de voir une usine de 10x10 à un moment, par exemple sur des réacteurs d'antimatière ou quoi. » | Plafonds de V1 retenus pour les 7 familles (emprise inchangée, D1-4) ; les NOUVEAUX bâtiments des époques hautes et des branches avancées peuvent être très grands, jusqu'à 10 × 10 (entrée du lot X0) |
| Q10 | Une forme commune aux 7 familles par époque, et 5 ères de 3 époques calées sur les paliers T1 à T5 : principe validé ? | 21/10, 18 h 49 : « oui je suis d'accord » | Forme commune par époque et 5 ères de 3 époques : règle de V3 |
| Q11 | Niveau 1 : sprite vanilla inchangé pour les 6 familles, et centre d'époque 1 redessiné en poste de pionnier ? | 21/10, 18 h 49 : « oui » | Niveau 1 vanilla pour les 6 familles ; centre d'époque 1 redessiné en poste de pionnier |
| Q12 | Économies sur les tourelles : 1 image de tir au lieu de 2 (−42 % d'images sur la mitrailleuse), déploiement du laser en 8 images au lieu de 15 (−22 %) ? | 21/10, 18 h 49 : « oui si vous voulez, je sais pas vraiment l'impact que ça aura en vérité. » | Décision de l'architecte : **pas d'économie par défaut** (R4, précision : recul du canon et déploiement complets). On n'y revient que si le temps de rendu mesuré par V0 l'impose, et on vous le dira |
| Q13 | Amender D1-3 (faille E27 : un simple agrandissement passait) ? | 21/10, 18 h 54 : « Oui, j'accepte l'amendement de D1-3 : socle exclu de la silhouette et mesure insensible à la taille (seuil à étalonner sur les premières pièces). » | D1-3 amendé : (a) couches plates au sol exclues du masque ; (b) recouvrement normalisé en échelle ≤ seuil à étalonner (proposition 0,75) ; s'ajoute à IoU < 0,50 |
| Q14 | Tourelles à niveaux et tourelles lourdes du mod : (A) dégâts +2 %/niveau après le niveau 10, d'où un DPS au niveau 30 de 0,94 × la mitrailleuse lourde et 1,06 × le laser lourd (appliqué par V2) ; ou (B) des niveaux pour les tourelles lourdes, ou leur retrait ? | 21/10, 21 h 25 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » → option A conservée | Tourelles à niveaux : DPS du niveau 30 ≈ tourelles lourdes |
| Q15 | Sauvegardes 0.3.0 : un mur de niveau 10 passe de 3 712 à 1 925 PV (nouvelle courbe). D'accord ? | 21/10, 21 h 25 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » → accepté | Murs 0.3.0 : PV ramenés au nouveau maximum au chargement |
| Q16 | Condition façon Clash of Clans pour monter le centre (par exemple, tous les bâtiments au niveau maximal de l'époque) ? Aujourd'hui, monter le centre seul ne coûte que 0,9 % de la dépense | 21/10, 21 h 25 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » → oui, condition légère : au moins un bâtiment de chaque famille possédée au niveau maximal de l'époque pour monter le centre | Lot V2c : fait (22/10, hors jeu ; moteur réel à passer) |
| Q17 | Avancer la file de chantiers (E3-4) avant la Compaction ? Sans elle, il faut relancer un chantier toutes les 10 s à l'époque 6 | 21/10, 21 h 25 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » → oui, la file de chantiers passe avant la Compaction | **Sans objet depuis Q19** (amélioration instantanée) |
| QX1 | Phase « brûleur » aux époques 1 et 2, l'électricité n'arrivant qu'à l'époque 3 ? | 21/10, 21 h 25 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » → oui | Lots X1-X3 |
| QX2 | Le Serment (époque 13) : une seule maîtrise de branche (III) et sa merveille avant l'époque 15, les autres à l'époque 15 ? | 21/10, 21 h 25 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » → oui | Branches |
| QX3 | Défaite si une faction ouvre sa Porte avant vous (X0 : en Difficile et en Impitoyable) ? | 21/10, 21 h 25 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » → défaite seulement en Impitoyable | C4, fin de partie |
| QX4 | Antimatière : (a) environ 1,8 GW nets par réacteur (rendement positif, fiction assumée) ou (b) simple stockage d'énergie ? | 21/10, 21 h 25 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » → (a) énergie nette, fiction assumée | Branche B |
| QX5 | Les noms : Érèbe, Caustique, Cœur, Convoi, Compagnie, Porte ? | 21/10, 21 h 25 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » → noms conservés (Érèbe, Caustique, Cœur, Convoi, Compagnie, Porte) | Textes |
| QX6 | Un 6e ouvrier offert par la merveille « Horloge éternelle », au-delà de « 1 à 5 » ? | 21/10, 21 h 25 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » → oui | ~~F1 : 6e ouvrier par la merveille~~ **Sans objet depuis Q19** (plus d'ouvriers) ; nouvel effet de l'Horloge éternelle : Q-V2c-2 |
| QX7 | « Époque 15 vers 60 h » : heure où l'on ATTEINT l'époque 15, ou heure où l'on ouvre la Porte (lecture actuelle : époque 15 à 52,5 h, Porte à 59,5 h) ? | 21/10, 21 h 25 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » → 60 h = ouverture de la Porte (époque 15 vers 52 h) | Lot V2c : modèle tenu pour la base de référence COMPLÈTE (époque 15 à 52 h 36, Porte à 59 h 35 ; hors jeu) ; chemin le plus court : centre 15 en 3 h 27 (30 % de la production) : rythme non imposé, voir Q-V2c-1 |
| QX8 | Les bâtiments vanilla qui arrivent après l'époque 1 (mur, four, foreuse, assembleur, laser) naissent au niveau 1 et rattrapent leurs niveaux en payant, ou naissent au niveau de leur époque ? | 21/10, 21 h 25 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » → naissance au niveau 1, rattrapage payant | E1, F1 |
| QX9 | Aux époques 2 à 4, 6 et 10, la recherche vanilla coûte jusqu'à 11 fois le budget du modèle : alléger la recherche vanilla (×0,04 à ×0,25 d'unités) ou plus de production plus tôt ? | 21/10, 21 h 25 : « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » → alléger la recherche vanilla des premières époques | Lot V2c : fait hors jeu (`data-final-fixes.lua`, 170 technologies allégées, fluid-handling comprise après correction ; étape data réelle vérifiée) ; moteur réel à passer |
| Q18 | Quand construire IA1 (équipes de PNJ organisées, C5) ? | 21/10, 21 h 38 : « Oui : IA1 se construit en parallèle de la Compaction, juste après le visuel. » | Ordre : visuel (V) → Compaction (C) ET IA1 en parallèle (fichiers distincts) → contenu des époques (X) → idle (I) |
| Q19 | Précision sur l'amélioration, les PNJ et le scénario (transcription du 21/10, 21 h 45) | « quand je parlais d'amélioration […] Dans Clash of Clans, c'est on améliore et on attend. Alors que là, l'idée, c'est si on a les ressources, on améliore, terminé. Parce que c'est comme pour poser les constructions […] c'est instantané. Bah, c'est pareil pour l'amélioration en vérité. […] la logique en fait de pipeline […] de production, qui s'adapterait à l'environnement […] il y aurait différents pôles […] peut-être que 5 entre guillemets, et ces 5 là ils piloteraient en fait différentes parties […] ça serait vraiment des ouvriers à part entière, mais qui soient multifonctions […] les couteaux suisses […] concentrer nos efforts sur tel ou tel aspect, que ce soit la ressource, que ce soit l'amélioration de la base […] la protection […] pouvoir dire je veux contrôler cette zone là […] j'ai relu votre scénario et le scénario est bien […] je l'aime bien. Très difficile à mon avis à faire en modèle, etc., 3D, mais je suis sûr que vos agents y arriveront. Paralyser un maximum pour essayer d'avancer au plus vite, mais tant que c'est qualitatif […] et pas uniquement on change la saturation ou la teinte des bâtiments […] il faut que ce soit également optimisé […] il faut pas qu'il y ait 1 million de polygones » | (1) **Amélioration instantanée** dès que les ressources sont là, pour le joueur comme pour les PNJ : plus de durée ni de limite de chantiers (E1 révisé ; Q17 sans objet) → lot V2c. (2) C5 précisé : production adaptative pilotée par les objectifs, pôles, environ 5 généralistes sur 30, contrôle de zones → lot IA1 relancé. (3) **Scénario X0 approuvé**. (4) 3D : qualité exigée, parallélisme maximal, budget d'optimisation (D4) |
| Q20 | Synthèse de Q19 conforme ? Mémoire vidéo visée ? | 21/10, 21 h 52 : « Ok, oui, continuez, la synthèse est parfaite. […] Concernant la mémoire vidéo, partez du principe que je jouerai sur des PC qui auront au minimum 8 Go de VRAM. Ce PC actuel en a 16. C'est une RX 6900 XT […] globalement 8 Go de VRAM, c'est bien pour la mémoire vidéo. » | Synthèse validée ; D4-1 : PC cible à 8 Go de mémoire vidéo minimum, atlas du jeu ≤ 6 Go |
| Q21 | Basse qualité et saturation de la mémoire vidéo | 21/10, 21 h 55 : « veillez vraiment à ce que la version basse qualité soit pas si basse que ça, mais qu'il puisse être […] qu'on puisse garder, si on veut, la sensation de gigantisme, en fait, par exemple, des usines factoriaux. […] quand vous dites que la basse qualité n'est plus la priorité, c'est d'accord, hein, complètement, mais par contre, il faut quand même que la basse qualité puisse avoir un certain range […] pour pouvoir vraiment faire tourner le jeu correctement. Parce que j'ai l'impression qu'en fait, en ayant des images de haute qualité, ça fait que même avec mes 16 Go de RAM, j'ai l'impression que je vais saturer très vite. Alors que peut-être pas du tout, je me trompe » | D4-2 renforcé (basse qualité rendue, lisible, gigantisme) ; D4-5 (banc d'usine géante, mémoire vidéo et images/s mesurées dans les deux qualités) ; estimation actuelle au §3 D4 |
| Q22 | Autonomie pendant la nuit du 21 au 22/10 | 21/10, 22 h : « vous avez carte blanche, je valide entièrement toutes vos décisions. Seulement, voilà, évitez en fait les utilisations d'outils MCP qui nécessitent une validation préalable […] puisque bah, je serai en train de dormir » | L'orchestrateur décide seul jusqu'au retour du Directeur Créatif (intégrations, lots suivants, arbitrages techniques). Exception : un DESIGN n'est toujours validé que par son verdict sur captures (CLAUDE.md §1) ; les planches sont préparées pour son retour. Aucun outil qui demande une autorisation |
| Q-IA1-1 | Les 30 PNJ doivent-ils donner une « évolution nette, rapide », quitte à raccourcir la partie ? (a) coûts X0 inchangés ; (b) X0 aux époques 1 à 3, coûts relevés ensuite ; (c) recalibrage complet (annule l'accélération) | 24/10, vers 10 h 25 : « A » (construire IA1 maintenant) ; proposition par défaut de l'orchestrateur appliquée : (a) coûts X0 inchangés, tant que m n'est pas mesuré (réversible ; D-14) | Rythme F1-3 |
| Q-IA1-2 | Montée des effectifs : (1) plafonds de 15, 25 puis 30 (30 PNJ vers 1 h 30) ; (2) 30 dès l'époque 1, seul le stock freine ; (3) départ à 30 | 24/10, vers 10 h 25 : « A » (construire IA1 maintenant) ; proposition par défaut de l'orchestrateur appliquée : (2) 30 PNJ dès l'époque 1, seul le stock freine (réversible ; D-14) | C5-1 |
| Q-IA1-3 | Résurrection : une mort coûte 33 à 78 s de production à l'époque 1, moins de 2 s dès l'époque 10. Faut-il qu'une mort pèse davantage plus tard ? | 24/10, vers 10 h 25 : « A » (construire IA1 maintenant) ; proposition par défaut de l'orchestrateur appliquée : profil « léger » et table de résurrection du §9 de docs/EQUIPES_PNJ.md (réversible ; D-14) | C5-5 |
| Q-IA1-4 | Usines : des modules éprouvés (gabarits) plutôt qu'un dessin tuile par tuile, avec la possibilité de dessiner vos propres modules en jeu ? | 24/10, vers 10 h 25 : « A » (construire IA1 maintenant) ; proposition par défaut de l'orchestrateur appliquée : oui : modules éprouvés (gabarits en Lua) (réversible ; D-14) | C5-3 |
| Q-IA1-5 | Votre équipe en mode « Assisté » par défaut (elle construit dans des zones que vous tracez, première couronne de 8 lots constructible d'office), mode « Autonome » en option ? | 24/10, vers 10 h 25 : « A » (construire IA1 maintenant) ; proposition par défaut de l'orchestrateur appliquée : oui : mode « Assisté » par défaut, zone constructible par défaut (réversible ; D-14) | C5-4 |
| Q-IA1-6 | Que pilotent les 5 généralistes ? (1) un domaine chacun ; (2) des parties durables de la base, avec des exécutants nommés ; (3) des projets de bout en bout | 24/10, vers 10 h 25 : « A » (construire IA1 maintenant) ; proposition par défaut de l'orchestrateur appliquée : (2) chaque généraliste pilote une partie durable, avec des exécutants nommés (réversible ; D-14) | C5-2 |
| Q-IA1-7 | « S'améliorer plus vite » : les rangs des PNJ, ou la vitesse d'amélioration des bâtiments ? En fin de partie, les PNJ gardent-ils un léger avantage de vitesse sur le joueur ? | 24/10, vers 10 h 25 : « A » (construire IA1 maintenant) ; proposition par défaut de l'orchestrateur appliquée : les rangs ; avantage de vitesse maintenu (armure à exosquelettes en fin de partie) (réversible ; D-14) | C5-6 |
| Q23 | Précision sur la puissance perçue et la taille (22/10, 7 h 20) | « il y a un truc qui est assez difficile à faire en design […] si jamais on ne connaît pas le jeu et qu'on regarde tel niveau, on a vraiment l'impression que ce niveau-là est plus puissant que le niveau du dessous […] Et surtout, il y a aussi un manque de taille, il y a un problème également de taille, des bâtiments, ça fait bizarre d'avoir un bâtiment qui est vraiment très petit […] les dernières machines pour construire, elles sont de taille, je sais pas moi 6 par six, par exemple, ça m'étonnerait pas […] des tailles qui augmentent des hauteurs qui augmentent aussi un peu pas les hauteurs moins mais les tailles oui, peut-être beaucoup plus […] Et du coup avec la taille, c'est pas que on agrandir l'échelle finalement, c'est on augmente aussi les détails, voilà. » | D1-4 révisé (emprise croissante, détail croissant), D1-4 bis (regard naïf) ; V3-S relancé avec ces règles. **22/10, 14 h 50 (lot V3-T intégré)** : tailles croissantes ACTIVES pour la mitrailleuse (2×2 → 6×6, une taille par ère) ; autres familles en attente de Q-S1 ; détail croissant : pas encore (visuel provisoire agrandi). **22/10, 19 h 05 (lot V3-T2 intégré, version 0.4.3)** : tailles croissantes actives pour toutes les familles sauf le mur ; détail croissant : toujours pas (visuel provisoire, laid aux grandes tailles) |
| Q24 | Quand un bâtiment change de taille (par exemple 3×3 → 4×4) : (1) il s'agrandit sur place si la place autour est libre, sinon l'amélioration est refusée et le contour nécessaire s'affiche ; ou (2) la nouvelle taille est un bâtiment à part, à construire à côté (l'ancien garde sa taille) ? | 22/10, 7 h 40 : « Q24 : agrandissement sur place si la place autour est libre ; sinon l'amélioration est refusée et le contour nécessaire s'affiche. Aussi, notez bien l'avancée du projet quelque part, histoire que si un autre agent doit reprendre la gestion du projet, elle ne recommence pas tout » | Agrandissement sur place si la place est libre, sinon refus avec le contour nécessaire affiché (remplacement par script, contenu transféré) ; état du projet tenu dans `REPRISE.md`. **Fait pour la mitrailleuse (lot V3-T, intégré le 22/10 à 14 h 50, `13b4134`, version 0.4.2)** : prouvé en moteur réel (`content` 238 OK) pour l'agrandissement, le refus sans paiement et le contour ; panneau, aperçu au sol et migration d'une vraie sauvegarde prouvés en moteur simulé seulement (H-T3). **22/10, 17 h 06** : migration d'une vraie sauvegarde 0.4.1 prouvée en moteur réel, sur une carte de banc (RD_LOG E46) ; une mitrailleuse sans place reste hors grille (question Q-T3). **22/10, 19 h 05 (lot V3-T2)** : même règle pour toutes les familles sauf le mur, prouvée en moteur réel (E49 à E51) ; dans une usine dense, elle bloque la plupart des machines (question Q-T2-1) |
| Q-V2c-1 | QX10 (passage du centre ≈ 10 % du budget) n'est tenu qu'aux époques 1 à 4 : la règle de place (le coût tient dans la moitié du coffre du centre) et les monnaies d'aujourd'hui le bornent à 3,35 % puis 0,11 % du budget, et le centre 15 s'atteint en 3 h 27 par le chemin le plus court (52 h 30 au calendrier). Remède : (a) un objet dense propre au passage (le « Codex k » du scénario X0) ; (b) un remplaçant dense provisoire en attendant les monnaies de X0 ; (c) une règle de place assouplie (ou un coffre plus grand) pour le seul centre ; ou (d) accepter l'écart ? | — (ouverte, lot V2c, 22/10) | Recommandation de l'architecte : (a), le Codex k étant déjà prévu par X0 ; d'ici là, QX10 et le rythme de 52 h sont NON CONFORMES (comptés « écarts connus » par levels_test) |
| Q-V2c-2 | Depuis Q19 (amélioration instantanée), l'« Horloge éternelle » (6e ouvrier, 2 sabliers par chantier, QX6) et le « Sablier quantique » (− 25 % de durée de chantier) du scénario X0 n'ont plus d'effet. Que doivent-ils offrir ? (par exemple : remise sur le coût des améliorations, amélioration d'une zone entière d'un coup, rangées de tous les bâtiments) | — (ouverte, lot V2c, 22/10) | Diff de nettoyage de `shared/content/epochs.lua` et de `docs/SCENARIO_EPOQUES.md` proposé (commentaires « sans objet depuis Q19 ») ; l'effet nouveau attend votre réponse |
| Q-S1 | L'échelle d'emprise « une taille de plus par ère » vaut-elle pour toutes les familles (assembleur 3×3 → 7×7, centre 4×4 → 8×8, four 2×2 → 6×6, mur 1×1 → ?) ou seulement pour la mitrailleuse ? (charte `docs/DA_FACTORIO.md` §9, lot V3-S, 22/10) | 22/10, 16 h 45 (saisi au téléphone, page des planches V3-S lue) : « Q S1 çui, Q S2 oui et " oui. j ai regarde et les designs sont fou, je lss trçuve parfait mais on n a pas l" cote changement d epoque avec un DA par epoque, en revanche les dezigns actuel sçnt absoluement epoustçuflan surtout pour les canons et je pense quil est facile de reprendre le meme style en mode changer des canons et des tuyaux àour correspondre a une DA d un age, pour le moment je trçuve que c est trs precis et je vçus felic_te » | **Q-S1, Q-S2, Q-S3 : oui** (lu comme l'échelle affichée sur la page : toutes les familles grandissent, plafond 6×6 pour les machines de production, centre 4 → 8, mur inchangé ; luminance de la charte pour toutes les époques ; regard naïf par des agents sans contexte). Avant la réponse : Bloque l'activation des autres familles dans `L.footprints` (lot V3-T : seule la mitrailleuse est activée, D1-4) ; propositions divergentes pour les machines 3×3 (6×6 ou 7×7 à l'ère V, BALANCE_SHEET §12). Q-S2 (luminance des époques « blanches ») et Q-S3 (qui passe le test du regard naïf) : même charte, §9, ouvertes aussi. **22/10, 15 h 50 : tranchée PROVISOIREMENT par l'orchestrateur (délégation Q25)** : oui pour toutes les familles, plafond 6×6 pour les machines de production (Q23 : « 6 par six ») : foreuse et assembleur 3 → 6, four et tourelle laser 2 → 6, centre 4 → 8, mur 1×1 inchangé. Q-S2 : oui (corps à 50-60 de luminance, plafond 76 ; matériau d'époque en accents patinés). Q-S3 : test passé à l'aveugle par des agents sans contexte, en attendant votre regard ou celui d'une personne qui ne connaît pas le jeu. Réversible : la table `L.footprints` et les planches restent à votre jugement. **22/10, 19 h 05 : Q-S1 appliquée** (lot V3-T2, version 0.4.3, prouvée en moteur réel ; RD_LOG E49) : toutes les familles grandissent sauf le mur ; visuel provisoire ; questions Q-T2-1 et Q-T2-2 nées de ce lot |
| Q-T3 | Migration des emprises d'une sauvegarde 0.4.1 (RD_LOG E46, 22/10) : une mitrailleuse collée à une ligne de murs et nourrie par un bras placé derrière elle n'a pas la place de grandir. Elle reste à sa position, hors grille, en service, avec sa nouvelle taille (chevauchement toléré, journalisé). Est-ce acceptable, ou faut-il une autre règle, par exemple déplacer aussi le bras ? | — (ouverte, 22/10, 17 h 20) | En attendant : comportement actuel (laissée en place et journalisée). Combien de tourelles seraient ainsi laissées dans une vraie partie : inconnu (aucune défense dense jouée ; **jouée depuis, 22/10, 20 h 11, lot R1, E54** : sur une ligne SYNTHÉTIQUE créée par 0.4.1, 13 tourelles sur 21 laissées, toutes en service ; dans vos vraies parties, toujours inconnu). **22/10, 19 h 20 : rattachée à Q-T2-1** (même nature, pour toutes les familles) : une seule réponse suffit pour les deux. **Depuis 0.4.4 (lot V3-T3, 22/10, 22 h 50)** : le bouton « libérer la place » traite le cas cité (mitrailleuse collée au mur, nourrie par un bras : zone B1 de `t3-libere`, prouvée en moteur réel) ; dans une ligne jointive, seuls les bouts se libèrent (2 tourelles sur 13 sur la défense dense ; Q-T2-1) |
| Q-T2-1 | **Usine réelle et règle du carré contenant (Q24)** (lot V3-T2, RD_LOG E49 et E50, 22/10). En jeu normal, une machine bordée de ses bras sur deux côtés opposés ne peut JAMAIS grandir sans démontage : passer à la taille suivante demande une rangée libre au nord ou au sud ET une colonne libre à l'est ou à l'ouest. Le banc a dû détruire un voisin et un bras pour agrandir un assembleur et un four d'une usine dense. À la migration 0.4.2 → 0.4.3 d'une usine dense typique de 24 machines de niveau 8, **18 restent hors grille (75 %)** : assembleurs 6/6, fours 6/6, foreuses 2/6, lasers 4/6, plus un centre 6 entouré de bras. Elles continuent de marcher (fabrication, extraction, bras, énergie), mais leurs sprites se superposent d'une demi-tuile, et leur amélioration suivante est refusée tant que la place n'est pas libérée (un message à la migration donne leur nombre et 5 liens de carte). Q-T3 (mitrailleuse collée aux murs) est la même question. Que voulez-vous ? Options de la revue du lot (relecteur du défaut 7, puis correcteur) : (a) accepter tel quel : la reconstruction devient un rythme de jeu, on libère la place à la main, le contour montre quoi retirer ; (b) décaler automatiquement les bras collés au bâtiment (la piste de Q-T3 : « déplacer aussi le bras ») ; (c) ne faire grandir la machine qu'au moment où on la repose à la main ; (d) une amélioration « en rangée » qui reconstruit la ligne (comme « Toute la rangée » des murs). Option ajoutée par l'orchestrateur, absente des sources du lot : (e) un bouton « libérer la place » qui retire ce qui gêne (bras, convoyeurs, voisins), le rend au joueur, puis agrandit. Aucune de ces options n'est conçue ni chiffrée ; toute autre réponse est possible. **Posée dans le chat le 22/10 vers 19 h 12 avec trois lettres : A = (a), B = (e), C = (d)** : une réponse « A », « B » ou « C » se lit avec cette correspondance. **Complément du 22/10, 20 h 21 (lot R1, RD_LOG E54) : une défense dense jouée en moteur réel.** Ligne synthétique de 21 tourelles (11 mitrailleuses, 10 lasers) derrière un mur continu, un bras par mitrailleuse sur un convoyeur de munitions, 24 poteaux. Créée par 0.4.1 puis chargée par 0.4.3 : **13 tourelles sur 21 sont laissées** (tous les tronçons jointifs) : les 8 du tronçon A, hors grille, se chevauchent entre elles ; les 5 du tronçon C, sur la grille mais agrandies en 4×4 et 6×6, chevauchent le mur, le convoyeur, les poteaux, les bras et leurs voisines ; seul le tronçon aéré (une colonne libre entre les tourelles) est reposé proprement. Sur les captures, les poteaux semblent plantés au milieu des sprites de A : c'est un effet du dessin, aucune boîte de A ne touche un poteau. Créée par 0.4.2 : 5 lasers sur 10 laissés : 3 hors grille sans aucun chevauchement (A), 2 qui chevauchent le convoyeur, des poteaux, un bras et leurs voisines (C) ; aucun mur n'est chevauché. Dans les deux cas, la défense MARCHE : **21 tourelles sur 21 tirent, 63 ennemis sur 63 tués**, chaque mitrailleuse nourrie par son bras, chaque laser sur le réseau. Deux captures (création 0.4.1) attendent votre regard : `<racine>\fo-logs\2026-10-22_R1\defense\captures-t2-defense-0.4.1\` | 22/10, 21 h 06 : « QT21 option B » (B = bouton « libérer la place », option (e) ci-contre ; telle que posée dans le chat : il marque les gêneurs à démonter et pose des fantômes pour les reconstruire décalés) | **Retenu par vous (B) le 22/10 à 21 h 06 : la règle Q24 reste, et un bouton « libérer la place » s'ajoute (lot V3-T3, lancé à 21 h 10)**. **Appliquée par V3-T3 (version 0.4.4, intégrée le 22/10 à 22 h 50, fusion `8a28804` ; RD_LOG E56 à E59)** : sans clic, rien ne change ; au clic, les gêneurs sont marqués à démonter et des fantômes les reposent décalés, réglages compris, tout ou rien ; « Annuler » remet l'usine comme avant ; prouvé en moteur réel (`t3-libere` 41 OK, vrais robots compris ; `t3-migration` 7 OK : un bâtiment laissé hors grille par une vraie migration est remis sur la grille). **Limite : les rangées collées.** Le bouton ne libère qu'un bâtiment qui a un côté libre : au milieu d'une rangée jointive, un voisin gêne toujours. Sur l'usine dense de test, 5 bâtiments libérables sur 19 laissés (les bouts de rangée et le centre) ; sur la défense dense, 2 tourelles sur 13 (création 0.4.1) et 0 sur 5 (création 0.4.2). Le bouton ne règle donc pas les dispositions qui ont motivé cette question ; une question de suite vous sera posée avec les planches V3-E (déplacer aussi les voisins en cascade, agrandir une rangée entière d'un coup, ou accepter la limite). Autres limites : fils de circuit des gêneurs reposés non refaits (un message le dit) ; panneau jamais joué par un vrai joueur. Recommandation de l'orchestrateur qui avait précédé : garder la règle Q24 (agrandissement sur place, sinon refus et contour) et ajouter un bouton « libérer la place » (e, sa propre proposition). En attendant : comportement actuel (refus et contour ; à la migration, laissée hors grille, en service, journalisée, message aux joueurs). L'usine dense jouée est UNE disposition synthétique : la part de machines bloquées dans vos vraies parties est inconnue, et vos sauvegardes n'ont été ni touchées ni testées |
| Q-T2-2 | **Production par tuile qui baisse quand la machine grandit** (lot V3-T2, BALANCE_SHEET §12, 22/10). La vitesse croît de niveau en niveau, mais l'emprise croît plus vite : un 6×6 de niveau 30 produit MOINS par tuile qu'un niveau 6 de base, dans toutes les familles chiffrées (assembleur, four, foreuse, tourelles). Production par tuile (vitesse du niveau / côté²), niveau 6 → niveau 30 : assembleur 0,117 (3×3) → 0,069 (6×6), creux à 0,051 au niveau 19 ; four 0,700 (2×2) → 0,184 (6×6) ; foreuse 0,083 (3×3) → 0,054 (6×6), creux à 0,039 au niveau 19 ; tourelles laser et mitrailleuse (dégâts, relatifs au niveau 1 ; mêmes multiplicateurs et mêmes tailles, donc mêmes chiffres) 0,35 (2×2) → 0,059 (6×6) : sur la surface d'une mitrailleuse 6×6 de niveau 30 (× 2,12), neuf mitrailleuses 2×2 de niveau 6 font 9 × 1,4 = 12,6. Le joueur a donc intérêt à ne faire que le minimum d'améliorations exigé par Q16 (condition du centre). Faut-il (a) que la production suive la surface (vitesse, emplacements de modules : au moins la production par tuile du niveau 6), (b) assumer la taille comme un prestige (puissance visible, condition Q16 du centre) au prix de la densité, ou (c) autre chose ? **Posée dans le chat le 22/10 vers 19 h 12 : A = (a), B = (b)** | 22/10, 21 h 06 : « QT22 j'ai rien compris » ; question reformulée dans le chat à 21 h 08 (exemple du four : 9 fois plus de place pour 2,4 fois plus de vitesse) ; RÉPONSE 22/10, 21 h 12 : « QT22 ah ouais non du coup, l'idée est vraiment d'avoir un idle massif en fait, des coûts qui augmentent évidemment, mais ça typiquement c'est pas possible donc A » | **Retenu par vous (A) le 22/10 à 21 h 12 : la production suit la surface (la grande machine vaut au moins les petites qu'on poserait à sa place), dans l'esprit d'un « idle massif », avec des coûts qui augmentent (lot V3-T4, lancé à 21 h 15)**. **Appliquée EN PARTIE par V3-T4, NON intégrée (Q-T4-1)** : sur sa branche (`worktree-wf_9d38a6df-249-1`, tête `2b18742`), la densité est tenue (production par tuile croissante, mesurée en moteur réel : RD_LOG E60 à E62) ; la rentabilité des améliorations ne l'est pas, et elle est même pire qu'en 0.4.3 pour la foreuse et l'assembleur (foreuse 29 → 30 remboursée en 510 h, contre 342 h). Le jeu livré (0.4.4) garde la production par tuile de 0.4.3, qui baisse quand la machine grandit (tableau ci-contre et BALANCE_SHEET §12), jusqu'à votre réponse à Q-T4-1. Recommandation de l'orchestrateur qui avait précédé : la production par tuile ne doit pas baisser (a). Argument de l'orchestrateur, absent des sources du lot : la baisse irait à rebours de la Compaction ×4. Cet argument est discutable : B1 porte sur le débit par tapis des paliers T1 à T5 (machines distinctes, 32 par tapis), pas sur le niveau d'une même machine. Aucune règle n'est retenue avant votre réponse : chiffres actuels inchangés (tableau complet : BALANCE_SHEET §12) |
| Q-P1 | **Disque** (plan de la suite, 23/10, 16 h ; `fo-logs\2026-10-23_plan-suite\PLAN_SUITE.md` §7). Il reste 1,9 Go sur H:, où sont aussi vos sauvegardes ; la mitrailleuse en jeu prend environ 0,4 Go, les 6 familles environ 2 Go de plus. A = déplacer vers `C:\Users\evan2\fo-archives` 0,6 Go de fichiers de calcul régénérables et les images des 5 anciennes galeries P1 (1,1 Go ; journaux gardés) ; B = seulement les 0,6 Go ; C = un autre disque | 23/10, vers 16 h 20 : « pour le disque c tout bon, pour les dessins des canons c est la A,  pour la question 3 on fait la C, long mais tant pis » → **A** | **Appliqué le 23/10 vers 16 h 25** : 1 776,5 Mo déplacés vers `C:\Users\evan2\fo-archives\fo-logs\` (104 `.npy` de `2026-10-22_V3E`, 609,1 Mo ; les PNG des 5 galeries P1, 5 × 233,5 Mo ; journaux laissés en place ; un `DEPLACE_VERS_C.txt` dans chaque dossier). Après coup, H: affiche 16,3 Go libres (C: 9,1 Go) : bien plus que le déplacement ; la différence ne vient pas de l'orchestrateur |
| Q-P2 | **Tête de la mitrailleuse en jeu** : A = 64 positions comme la vanilla, une image par position (canon de l'âge 15 par sauts de 0,4 tuile), éclat de tir par âge, tête toujours levée, environ une nuit de rendu ; B = vanilla complète (recul, levée animée), environ trois nuits ; C = 32 positions, une demi-nuit, sauts de presque une tuile | 23/10, vers 16 h 20 : « pour les dessins des canons c est la A » → **A** (64 positions) | Retenu : 64 positions, une image par position, éclat de tir par âge, tête toujours levée (lot A3) |
| Q-P3 | **Rythme des objets hors des 7 familles** (exemple : le four à coke, né à l'âge 2) : A = un design par ère (5 au plus), pièce du niveau pair entre deux, environ 70 designs pour les 28 machines X0 ; même règle par palier pour tapis et bras ; B = un design par âge (environ 190) ; C = un seul design par machine (28) | 23/10, vers 16 h 20 : « pour la question 3 on fait la C, long mais tant pis » ; confirmé le 24/10, vers 8 h 35 : « la longue, un design par âge, c'est B » | **B** : un design par âge pour les objets hors des 7 familles (environ 190 designs, dont les 28 machines X0) ; à appliquer aux lots X |
| Q-M0-1 | **Gisement garanti dans une partie NEUVE** (lot M0, version 0.4.5, RD_LOG E73, E74, F133). Le tungstène (âge 5), le cristal (âge 7) et le méthane (âge 8) sont désormais garantis sur toute carte : un site posé par script entre 200 et 700 tuiles du départ. Sur 5 graines essayées, 3 n'avaient pas l'une des trois monnaies à cette distance. Dans une partie neuve, le jeu ne sait pas encore ce que la graine cache à 500 tuiles. A = le site garanti est TOUJOURS posé (actuel) : parfois un gisement de plus que la graine n'en avait ; B = seulement si la graine n'en a pas : environ 2 s de plus à la création de la carte (environ 2 850 chunks générés) et une sauvegarde bien plus grosse | — (ouverte, 23/10 ; pas encore posée dans le chat) | Recommandation de l'orchestrateur : **A**. En attendant : A (comportement livré en 0.4.5). Dans une sauvegarde existante, seul ce qui manque est posé |
| Q-M0-2 | **Aspect du site garanti** (lot M0, captures `<racine>\fo-logs\2026-10-23_suite\M0\captures-2\`, critère B7). Le site se voit comme un disque net de cendres (ou de plaine de cristal, ou de marais) posé sur le sol voisin. A = le garder ainsi ; B = l'adoucir (bord fondu, décor du biome) avec le kit sol et décor du lot M2 | — (ouverte, 23/10 ; pas encore posée dans le chat) | Recommandation de l'orchestrateur : **B, quand le kit sol de M2 existera** ; d'ici là, le disque net reste. Relevé de l'agent et du vérificateur, pas un verdict : les braises du biome forment de larges taches rouge sombre qui, de jour, évoquent du sang ; le bord du marais est en marches d'escalier (défaut des biomes existants, M2 et M3) ; le décor d'un AUTRE biome reste parfois dans le disque, et les braises semblent déborder du disque (non prouvé) ; les puits de méthane sont à peine lisibles |
| Q-T3-1 | **Rangées collées et bouton « Libérer la place »** (lot V3-T3, E59). Le bouton ne libère que les bâtiments qui ont un côté libre : au milieu d'une rangée collée, un voisin gêne toujours (usine dense de test : 5 libérables sur 19 ; défense dense : 2 sur 13). Posée sur la page des planches V3-E le 23/10 à 0 h 20 : A = garder ainsi ; B = le bouton déplace aussi les voisins, en cascade ; C = agrandir une rangée entière d'un coup, mise en page refaite | — (ouverte, 23/10, 0 h 20) | Recommandation de l'orchestrateur : C (gros lot) |
| Q-T4-1 | **Rentabilité des améliorations et « idle massif »** (lot V3-T4, 22/10, 22 h 40 ; branche `worktree-wf_9d38a6df-249-1`, tête `2b18742`, NON intégrée). Le lot V3-T4 applique Q-T2-2 (A) pour la DENSITÉ : un bâtiment agrandi vaut au moins les petits posés à sa place, production par tuile croissante, mesurée en moteur réel. Mais pour tenir le calendrier (époque 15 vers 60 h), il a multiplié les coûts (jusqu'à × 6 au niveau 30), et une amélioration ne se rembourse plus : passer la foreuse du niveau 29 au niveau 30 coûte l'équivalent de 510 heures de sa production supplémentaire (342 h en 0.4.3, déjà non rentable). 12 nouveaux écarts connus (23 en tout), dont la place des coûts dans le coffre du centre et le DPS des tourelles (Q14). Posée dans le chat le 22/10 vers 22 h 45 : A = vrai idle (chaque niveau produit nettement plus que le précédent, les coûts montent aussi vite, chaque amélioration se rembourse en moins d'une heure de jeu, la partie garde environ 60 h ; gros rééquilibrage) ; B = garder la progression actuelle (on améliore pour avancer d'époque, pas pour la rentabilité) | — (ouverte, 22/10, 22 h 45) | Recommandation de l'orchestrateur : A. En attendant, V3-T4 n'est PAS intégré : le jeu garde l'équilibre de 0.4.3 (la version 0.4.4, depuis l'intégration de V3-T3 le 22/10 à 22 h 50, ne change que la place). Chiffres et options : RD_LOG E62 |
| Q-S0-1 | **Sons de tir de la mitrailleuse par ère** (lot S0 ; page d'écoute https://claude.ai/artifact/Ap4JoXCgvxJJR29b5QceU3 , le son du jeu de base d'abord, puis les 5 ères, un tir seul et une rafale chacune). Pour chaque ère : A = garder ; B = changer (dites quoi : plus grave, plus sec, moins de basse…) ; C = refaire | — (ouverte, 23/10, 23 h) | Sons provisoires en jeu depuis 0.4.7, réversibles ; jamais plus forts que la vanilla (mesuré) |
| Q-MATIN-25 (25/10, vers 5 h ; page https://claude.ai/artifact/N8rHLyXYL7rYqnVjf7atj3) | Huit questions de la nuit, avec images : (1) aspect des modules, MOD-V Q1 à Q4 (teinte des balises par type, chiffre du palier, croix ou engrenage de la productivité, couleur par âge ou par type) ; (2) **Q-M5, défaut trouvé par l'orchestrateur** : au plafond du moteur (× 328,67), l'énergie est AUSSI bornée à × 328,67 et rattrape la vitesse dès environ 6 modules de palier 10 (34 × P10 : vitesse × 328,67, énergie × 328,67, capture `fo-logs\2026-10-24_MOD1\captures-2\x-mod1-gui-F-plafond-34-palier10.png`) : la règle D-15 « énergie plus basse que le gain » ne tient plus au plafond ; A garder, B garder l'écart (énergie bornée à vitesse^(ln Π(1+0,6b) / ln Π(1+b)), environ × 76 pour × 328) ; (3) logistique au-delà d'environ 120 objets/s par machine (A coffre de sortie sans limite, B robots, C laisser la limite) ; (4) couleur d'équipe, A5 Q1 à Q3 ; (5) laser F1-B (A produire et mettre en jeu, B troisième ronde, C revoir des âges) ; (6) titane : feuille I3 ou I2, nuit trop claire et sol bleu vif, saumure au visuel du pétrole ; (7) hydrogène en trop (A torchère, B recette qui l'utilise, C laisser) ; (8) confirmer les choix provisoires D-16 ; (9) ajoutée vers 7 h : plafond des recrues de votre équipe (46 en 1 h sur une graine après la correction de 0.4.24 ; A laisser, B plafonner, par exemple 10 par heure, C défendre d'abord les avant-postes) ; (10) ajoutée vers 8 h 30 : grandes équipes (IA1-b : fond inactif à l'effectif de départ, plafond du minage à la main 20 %, gardes 23 % du temps) ; (11) ajoutée vers 8 h 35 : terres rares de l'âge 12 (X2, NON fusionné : prix du centre +26 à +84 % aux époques 10 à 13, aspect de la monazite et du sol, sous-produits sans usage) | ✅ Répondu le 25/10 vers 9 h 15, par QCM dans Claude Code (le DC : « j'ai rien compris au formart de réponse, pour moi ça veut rien dire, posez moi les questions ICI avec un choix QCM où je peux cliquer dessus et ça fonctionne DANS claude code ») | Réponses mot pour mot : lignes R-QCM-25 ci-dessous ; décision D-17 (RD_LOG) |
| R-QCM-25 (25/10, vers 9 h 15) | Q-M5, modules au plafond (énergie = vitesse au plafond × 328) | ✅ « Garder l'écart (Recommandé) » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Logistique au-delà d'environ 120 objets/s par machine | ✅ « il faut tout simplement des bras robotique capable de prendre énormément d'objets à la fois, et d'avoir des convoyeurs capable d'augmenter exponentiellement leur vitresse et même au bout d'un moment peut être que ce sera qu'un tupe ou je sais pas qui simulera les objets car ça sera beaucoup trop rapide pour le pc à générer je pense » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Hydrogène en trop de la chaîne du titane | ✅ « Une recette qui l'utilise » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Recrues de votre équipe (46 en 1 h sur une graine) | ✅ « Défendre d'abord » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Prix du centre aux époques 10 à 13 avec la bobine (+26 à +84 %, X2) | ✅ « Accepter la hausse » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Sous-produits sans usage des terres rares (X2) | ✅ « Leur donner un usage » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Travail de fond des équipes (inactif à l'effectif de départ) | ✅ « Laisser grandir » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Plafond du minage à la main (20 % dès la recherche 1) | ✅ « Garder 20 % » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Voyants des balises (MOD-V Q1) | ✅ « Garder par âge » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Chiffre du palier des modules (MOD-V Q2) | ✅ « Garder le romain » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Symbole de la productivité (MOD-V Q3) | ✅ « Engrenage » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Couleur des modules (MOD-V Q4) | ✅ « Couleur par type » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Précision : voyants des balises si les modules sont colorés par type | ✅ « Couleur de l'âge » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Force de la couleur d'équipe (A5 Q1) | ✅ « 25 % » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Pièces portant la couleur d'équipe (A5 Q2) | ✅ « seulement les liserés je pense que c'est mieux. Aussi, si c'est possible d'automaiser la teinte ça ferai qu'on pourrai en théorie choisir le nombre d'équipe dans la partie » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Couleur d'équipe la nuit (A5 Q3) | ✅ « Laisser ainsi » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Tourelle laser, 15 âges (F1-B) | ✅ « Troisième ronde » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Feuille de l'ilménite (X1) | ✅ « I2 sombre » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Nuit trop claire de l'ilménite, sol des cratères bleu vif (X1) | ✅ « Assombrir » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Puits de saumure au visuel du pétrole (X1) | ✅ « Visuel propre » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Aspect de la monazite et des sables noirs (X2) | ✅ « À refaire » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Gardes d'avant-postes de votre équipe (23 % du temps) | ✅ « Couper les gardes » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Productivité additionnée ou multipliée (Q-M4) | ✅ « multiplier aussi mais moins violament que la vitesse, d'ailleur la vitress on va baisser l'augmentation par palier, et on garde la multiplication pour les 2 » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Choix provisoires D-16 (personnalité tirée, brouillard, alliances tacites, IA qui peut dépasser le joueur, E1 à E3, S1 à S5) | ✅ « Oui, tout garder » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Paliers de vitesse (plus doux) | ✅ « +20 %, puis +10 %/palier » | D-17 |
| R-QCM-25 (25/10, vers 9 h 15) | Paliers de productivité (multipliés) | ✅ « +10 %, puis +5 %/palier » | D-17 |
| R-QCM-25b (25/10, vers 10 h 40 ; lot MOD-3) | **ERREUR DE L'ORCHESTRATEUR corrigée** : au QCM de 9 h 15, la productivité était dite « plafonnée par le jeu à +327 % (un peu plus de × 4) » ; le vrai plafond est × 328,67 (+32 767 %, F199). Question reposée avec les vrais chiffres (5 modules de palier 10 : × 9 objets ; 14 modules : 328 engrenages pour 1 plaque) | ✅ « Pas de plafond (× 328) » | D-17 complétée |
| R-QCM-25b | Malus de vitesse des modules de productivité (−5 à −15 % chacun) | ✅ « Réduire de moitié » | D-17 complétée |
| R-QCM-25b | Efficacité relativement deux fois plus forte avec les paliers de vitesse plus doux | ✅ « Garder » | D-17 complétée |
| R-QCM-25b | Verdict sur le design des 30 modules (planche envoyée en fichier) | « j'ai pas vu, faire mopi un artefact » → planches ajoutées à l'Atlas des designs (section Modules) ; question reposée : ✅ « Validé tel quel » (défauts signalés avant le verdict : chiffre romain illisible en petit, engrenage proche de la roue dentée en mode Alt) | ✅ design des modules VALIDÉ par le DC |
| R-QCM-25c (25/10, vers 11 h 20 ; lot IA1-b2) | « Défendre d'abord » appliqué aussi aux FACTIONS (mesuré : à 30 PNJ, 2 à 3 fois moins de morts ; à 4, −7 à −11 % de production et Impitoyable moins agressive que Difficile) | ✅ « Oui, toutes » (recaler ensuite les difficultés) | D-17 complétée |
| R-QCM-25c | Coffre de votre équipe détruit par une attaque de faction à 53 min (graine 271828182 du guide) | ✅ « L'équipe le défend » (PNJ armés au coffre dès la déclaration de guerre, tourelles autour dès qu'elles sont possibles) | D-17 complétée |
| R-QCM-25c | Occupation à 76 % sans gardes (objectif 85 %) | ✅ « Donner du travail » (minage près du coffre, transport entre avant-postes et coffre) | D-17 complétée |
| R-QCM-25d (25/10, vers 12 h 15 ; lot IA1-i) | Verdict sur la fenêtre « Équipe et factions » (captures dans l'Atlas des designs, section Interface de gestion) | ✅ « Validée, en jeu » | Fusion après la correction du lancement de guerre (réglages de carte) |
| R-QCM-25e (25/10, vers 12 h 40 ; lot F2-A) | Le four, 15 âges (Atlas des designs, section « Four (proposition, 15 âges) ») : direction ? | ✅ « Oui, enrichir » (réponse donnée deux fois : la première après un clic manqué, reposée à la demande du DC) | Ronde d'enrichissement LÉGÈRE ; précision du DC : « (j'ai choisi enrichir mais en fait c'est pas si mal, je pense qu'il faut pas beaucoup plus que les fours soient parfait) » : silhouettes et idées d'âge gardées, petites pièces sur les surfaces planes des âges 9 à 14, nuit des âges 1, 3, 11, lueur de l'âge 15 |
| R-QCM-25f (25/10, vers 12 h 50 ; lot F3-A) | L'assembleur, 15 âges : boîtes plates, même bac de sortie ; que faire ? | « En fait, les assembleurs sont bien dans l'idée mais j'ai l'impression que certain ont juste une plateforme et un truc posé dessus, ça fait pas précis, pas détaillé et aussi ils sont tous carré, mais peut être qu'on peut aussi en faire des circulaires » | Ronde F3-A2 : idées d'âge gardées ; machines intégrées (pas « plateforme + objet posé »), précises et détaillées ; silhouettes variées, dont circulaires, dans l'emprise carrée |
| R-QCM-25g (25/10, vers 13 h ; diagnostic IA3-DIAG) | Par quoi commencer (3 corrections rapides, vraies usines, recherche d'abord seule) ? | « en fait ils doivent jouer comme des joueurs, mais qui s'organisent, par exemple : y a les ressources pour faire une machine a vapeur, ils vont pas tous s'arracher les ressources pour la crafter. Ensuite concernant les évolution, il faut que ce soit algorithmisé dans le sens où on peut pas faire ça pour tous les bâtiments en fait, il faut que vous réfléchissiez à comment un humain réfléchi, et transcrire ça pour les IA, et aussi, comment un groupe d'humain (organisé) réfléchirai en jouant à factorio. » | D-18 |
| R-QCM-25g | Ouvriers par faction au départ | ✅ « 8, après les corrections (Recommandé) » | D-18 |
| R-QCM-25g | Recherche ou armée d'abord | ✅ « Selon le caractère (Recommandé) » | D-18 |
| R-QCM-25g | Blocage à la recherche 3 (pétrole) | « ils doivent se débrouiller pour chercher du pétrole, comme les joueurs quoi, mais peut être que pour aller chercher du pétrole les IA évaluent la sécurité d'abord, donc peut être s'équiper en grenade ou tourelle et munitions histoire de si ils sont attaqué ils peuvent les poser pour se défendre. En fait la conception des IA/PNJ est vraiment dur et vous pouvez pas juste me poser des questions à tour de rôle, c'est une section à paert entière car ça fait partie intégrante du gameplay ! » | D-18 |
| R-QCM-25h (25/10, vers 15 h ; lots F2-A2 et F4-A) | Le four retouché (F2-A2) : valider pour la production ? (le DC avait d'abord répondu à côté : « je trouve pas précisément les nouveaux assembleurs par rapport aux aciens » : la 2e ronde de l'assembleur n'était pas encore sur la page) | ✅ « Validé, production » | Lot F2-B : rendu final, animation, mise en jeu, mémoire vidéo au plancher |
| R-QCM-25h | La foreuse, 15 âges (F4-A) : direction ? | ✅ « Oui, enrichir nettement » | Ronde F4-A2 |
| R-QCM-25h | Q-C3 : foreuses lourde, à concentré, profonde du scénario X0 | ✅ « Elles restent à part » | Trois bâtiments à part, dessin plus tard ; la famille de 30 niveaux ne les touche pas |
| R-QCM-25i (25/10, vers 15 h 20 ; lot F3-A2) | L'assembleur, 2e ronde (7 âges sur 14 vraiment changés, L et portiques encore carrés) : suite ? | ✅ « 3e ronde (Recommandé) » | Ronde F3-A3 : embases découpées, âges 7, 9, 10 refaits, âge 15 lisible, nuit |
| R-25j (25/10, vers 15 h 20) | Demande : « Aussi en parallèle, oubliez pas de lancer un banc sur vraiment le développement profond des IA/PNJ. » | — | Section IA3 lancée en parallèle (revue adverse de la conception, fondations IA3-0, puis lots IA3-a et suivants) |
| R-25k (25/10, vers 17 h 40) | Sur le plan de la section IA (17 à 21 jours d'agents) : « alors par contre 17 à 21 jours non, vous mettez le budget si il faut mais mettrez des agents sur le coup en permanance pour avancer sur la partie IA. » | — | Section IA3 en développement continu et parallèle : IA3-a, IA3-b, IA3-c, IA3-f et IA1-d en même temps ; un agent relancé dès qu'un lot finit ; l'intégrateur fusionne lot par lot avec les bancs |
| R-QCM-25l (25/10, vers 18 h 30 ; lot F3-A3) | L'assembleur, 3e ronde (socles découpés, âges 7, 10, 14, 15 refaits ; restent faibles : âge 2, nuit des âges 2 et 3, densité des âges 10, 12, 15) : suite ? | ✅ « Validé, production » | Lot F3-B : rendu final, animation, mémoire vidéo, mise en jeu |
| Q-M1 à Q-M3 (24/10, vers 21 h 35 ; lot MOD-0, modules) | M1 au-delà de × 328 ; M2 plafond de 60 fabrications/s ; M3 énergie d'une machine très rapide | ✅ Réponse du DC, 24/10 vers 21 h 50 : « M1 A, M2 A, M3 A mais en fait on va réduire, il faut que l'énergie consomé soit légèrement inférieur à la productivité gagnée, par exemple : +50% vitesse / +30% consomations d'énergie, je dirait que la consomation d'énergie en plus doit être 60% du bonus apporté à la productivité » → multiplication jusqu'à × 328 (plafond du moteur), rien au-delà ; recettes par lots (× 10, × 100) choisies automatiquement selon la vitesse ; énergie laissée au joueur, MAIS chaque module ajoute en énergie 60 % de son bonus (+50 % de vitesse → +30 % d'énergie), et ces facteurs se multiplient aussi. Q-M4 (types et paliers, productivité multipliée ?) en attente. Lot MOD-1 (mécanisme) lancé |
| B-Q1 à B-Q4 (24/10, vers 21 h 35 ; lot B0, biomes) | Plaine de cristal (A eau violette d'avant, B eau violette aux bords corrigés, C sol lilas pâle, D sol mauve bruyère livré) ; marais (A correction avec méthane naturel décalé, B sol de boue, C ancien marais) ; grain fin aux frontières (A non, B oui) ; végétation vanilla sur la plaine (A garder, B retirer) | ✅ Réponse du DC, 24/10 vers 21 h 40 : « B1 D, B2 A, B3 B, B4 B » → sol mauve bruyère ; marais corrigé, décalage du méthane accepté ; grain fin à ajouter (garantie à revérifier) ; végétation retirée de la plaine. Suite confiée à l'agent de B0 |
| Q-B1, Q-B2 et R-20H30 (24/10, vers 20 h 30) | Réponses et demandes du DC : « aussi, créer de nouveau minerais, designs tous différents, nouveaux modules (car en fait ils ont tous le même aspet / couleur en plus). En fait j'ai ouvert le jeu et cheaté pouvoir voir ce que je pouvais faire mais je pense que tout n'était pas du tout fini et du coup j'ai vu des défauts qui de toute façon aurai été corrigé, comme aussi el fait qu'il y a un biome violet et il est bizare et les transitions entre biomes sont ultra pixélisé (ça fait de gros carés et donc je pense que c'est ça qui fait en sorte qeu ce soit bizare car y coupe entre un fond jaune ou vert avec du bleu/violet). QB1 en fait c'est aps ça, l'idée et que par exemple, au palier 1 on A +50% de vitesse, au palier 2 on a +80%, au palier 3 +110%, mais que quand on les mets sur une machine, le calcul de la vitesse finale soit V = v_base * bonus_module1 * bonus_module2 *bonus_module3 ... QB2 B, on commence à 5 et ensuite +1 par niveau » | 🟨 Compris ainsi : les MODULES ont des paliers (vitesse : palier 1 +50 %, palier 2 +80 %, palier 3 +110 %, soit +30 points par palier) et se cumulent en MULTIPLIANT (V = v_base × 1,5 × 1,5 × …) au lieu de l'addition du moteur ; l'énergie suit au même taux ; emplacements de modules des bâtiments à niveaux : 5 au niveau 1, puis +1 par niveau (34 au niveau 30) ; nouveaux modules au design distinct (forme et couleur par type et par palier) ; nouveaux minerais, designs tous différents ; biome violet à revoir ; transitions entre biomes en gros carrés à corriger. Étude de faisabilité moteur (MOD-0) et diagnostic des biomes (B0) lancés |
| R-20H (24/10, vers 20 h) | Demande du DC en trois points : « aussi, je trouve qu'il n'y a pas assez de nouvelles ressources, pas assez de nouvelles machines (alors ok c'est pas fini mais j'aimerai que vous analysiez attentivement le sénario du gameplay prévu). Aussi, améliorez autant que possible les choix avec une certaine intelligence des PNJ, on doit vraimetn avoir du mal à prédire que ce soit un PNJ/une IA, dans l'idée elle devrait pouvoir s'adapter (le chef d'équipe) et du coup on ne pourrai pas retrouver les mêmes paterns contarirement aux jeux de stratégies classique comme command and conquer ou Supreme commander 2 qui font des bases très circulaire et en fait ne s'étendent pas vraiment, et du coup ça impose une sorte de limite, là où un joueur voudrai scale un max et capitaliser, un pnj ne verra pas vraiment ce choix. Aussi, j'ai remarqué que les bonus de vitesse ou de produxtion sont médiocre, on veut du +30% par niveau (cumulatif, donc par exempel vitesse de 1 * 1.3 * 1.3 * 1.3) et ne pas avoir de limite dans le nombre de module qu'on peut importer (les coûts d'énergie aussi se multiplient, mais doivent croitre au même niveau). » | 🟨 (1) et (2) : analyses lancées (fo-logs\2026-10-24_ANALYSE\SCENARIO.md et IA_ADAPTATIVE.md) ; (3) bonus +30 % cumulés et modules sans limite : questions de précision posées (Q-B1, Q-B2), rien changé avant la réponse |
| Q-M1-4/5, Q-F1, Q-A3F (24/10, vers 15 h 40) | Trois questions posées avec les images : (1) **tungstène de nuit** : A garder la lueur turquoise, B plus discret, C autre couleur ; (2) **laser** : A garder la direction des essais (tour ronde sans canons, émetteur lumineux) et l'enrichir, B changer ; (3) **3 petites fentes de l'âge 11** de la mitrailleuse : A ça va, B à reboucher | ✅ Réponse du DC, 24/10 vers 15 h 45 : « pour répondre à vos questions : 1) A, 2) A, 3) A » → lueur turquoise gardée ; direction du laser gardée, à enrichir aux rondes F1-B ; fentes acceptées |
| Q-A4-1 | **L'éclat de tir de la mitrailleuse** (lot A4) : à chaque coup, une flamme aux couleurs de l'âge sort du bout des canons. A = la grande flamme (en jeu aujourd'hui) ; B = une petite flamme, plus discrète, qui pèse les deux tiers en mémoire vidéo | 24/10, vers 8 h 35 : « B mais A sur les dernières aires » | Précisé le 24/10 vers 8 h 45 : « je voudrai qu'il grossisse au fur et à mesure des aires, docn en gros, le dernier il est gros » → l'éclat grossit d'ère en ère, de B (ère I) à A (ère V), par paliers égaux : **appliqué en version 0.4.11** (`195ac60` ; a4-eclat 3 OK, captures regardées) |
| Q-A4-2 | **Le socle lumineux animé** (lot A4) : à l'âge 6, les lueurs du socle bougent doucement (essai, visible de nuit ; la tête couvre en partie le socle). A = l'étendre aux 10 autres âges lumineux (environ 6 h 30 de rendu, la nuit) ; B = le garder pour quelques âges ; C = le retirer | 24/10, vers 8 h 35 : « 3) A » | Socle animé étendu aux 10 autres âges lumineux : production d'environ 6,4 h de Blender, la nuit (une place de rendu), puis intégration et bancs |
| Q-A4-3 | **Couleur d'équipe** (lot A4) : la tête peut prendre la couleur de l'équipe, comme les véhicules du jeu de base. A = non ; B = une bande colorée sur la tête (environ 1 % de mémoire vidéo de plus) ; C = une pastille (presque rien) ; D = toute la couleur dominante (environ 4 %) | 24/10, vers 8 h 35 : « 4) B » | Couleur d'équipe par une BANDE colorée sur la tête (environ 1 % de mémoire vidéo de plus, estimé par les boîtes d'alpha) : rendu du masque par âge et par direction à faire (lot à ouvrir), coût de rendu à mesurer ; 24/10 vers 10 h 15, sur l'essai de l'option D (page du matin) : « c'est atroce à vior, il faut que ce soit de petits éléments qui soient changé de couleur et aussi pas autant saturé, c'est très désagréable » → masque sur de PETITS éléments seulement (bande, liserés, voyants), couleur d'équipe désaturée ; essai sur 2 ou 3 âges montré au DC avant toute production |
| Q25 | Délégation des choix visuels pendant la phase V | 22/10, 15 h 48 : « je verrai les templates àlus tard car vous savez parfaitement quoi faire » | L'orchestrateur ne bloque plus sur le verdict des planches : il retient la direction désignée par les juges (mesures et œil de directeur artistique, test du regard naïf), tranche provisoirement Q-S1 à Q-S3, et enchaîne V3 des 7 familles puis V4. Les planches restent publiées (page claude.ai privée) pour votre regard ultérieur ; **rien n'est déclaré validé à votre place** (D1 à D3) : chaque choix est consigné comme provisoire et réversible |

## 5. Historique des écarts signalés par vous

| Date | Votre constat | Réponse | Statut |
|---|---|---|---|
| 26/10, vers 22 h 25 (macro de nuit, reçu le 27/10 à 1 h 12 ; le DC dort et ne répondra pas) | Après avoir joué 0.4.30 : « J'aimerais que vous vous concentriez principalement sur le cerveau des IA parce qu'il y a beaucoup beaucoup beaucoup d'éléments à revoir, notamment toutes les toutes les toutes les actions illogiques et le fait qu'ils n'automatisent pas, qu'ils craftent beaucoup à la main, qu'ils ne fassent pas de recherches réelles. Enfin bon, il y a énormément de trucs autant dans les actions que dans les logiques, dans les usines, dans un peu de tout, dans le sens où ils ne jouent pas comme des joueurs. Voilà, donc toute la partie cerveau à refaire. Il y a quelques tests que j'ai dû faire. Les trajets sont prévisibles, même si ils voient très clairement que il va avoir quelqu'un sur leur trajet, ils vont quand même continuer. Ils ne s'adaptent pas du tout. Ils n'ont pas de comportement visible, typiquement la peur, dans le sens où ils vont éviter le danger, ou à l'inverse l'agressivité. Et beaucoup d'agents ne font rien. D'ailleurs, il y a bien des milices, mais il y a beaucoup d'agents qui font rien. Ils ne scalent pas d'ailleurs aussi. Ça, c'est un point que je remarque, ils ne scalent pas alors qu'ils pourraient. Voilà. Il y a beaucoup d'éléments, j'ai certainement pas tout cité dans le prompt, mais il faudra établir cette liste que je ne pourrai pas valider mais qui sera de la logique évidente. Donc je n'aurai normalement pas besoin de valider une logique d'intelligence évidente qui sera faite par des agents, etc. Mais du coup, concentrez-vous là-dessus et en parallèle, continuez l'avancée des designs. » | Juste, et chiffré par le journal de sa partie (0.4.30, 4 factions, 8 PNJ, Impitoyable, 41 min) : recherche 1 seulement à 14-23 min ; Écarlate perd **26 PNJ en 41 min** aux mêmes 87 à 103 tuiles du QG (tâche « service ») ; effectif figé à 8. La partie jouée est l'ANCIEN cerveau : aucun lot IA3 n'était fusionné (5 branches presque finies hors jeu le 25/10). La liste demandée est écrite : `docs/IA_ATTENDUS.md` (familles A décider, B s'organiser, C se déplacer et réagir, D lisibilité ; 24 lignes, chacune avec un critère en moteur réel). Lancés : IA-V2 (réunir b, c, f, allumés par défaut, puis fusion), IA1-d (construction, puis automatisation), **IA3-k (nouveau : trajets variés, réaction à un ennemi vu, peur, agressivité, mémoire du danger, soldats occupés)** ; designs en parallèle (assembleur F3-B) | ⏳ En cours |
| 25/10, vers 18 h 45 | Suite de la même partie : « ils farment de la pierre et du charbon et ils font rien de plus, ils en ont a foison, mais n'explorent pas et regardent même pas autour d'eux » | Juste : l'extraction ne s'arrête pas quand le stock dépasse le besoin (« stock dormant », B5 d'IA_ADAPTATIVE), et rien ne déclenche l'exploration quand une ressource utile (le fer) manque ou n'est pas connue. Transmis aux lots IA3-c (buts par BESOIN : un stock suffisant libère ses PNJ vers ce qui manque), IA3-f (exploration quand une ressource utile manque, regard autour du QG) et IA3-b (marché des tâches pondéré par le besoin) | ⏳ En cours |
| 25/10, vers 18 h 40 | Capture de sa partie (`fo-logs/2026-10-25_DC-captures/pnj-inactifs-fer-ignore.png`) : « encore un exemple parfait de l'imperfection des PNJ, y en a plein qui foutent rien, et plein qui ne vont pas chercher le fer alors qu'ils en ont besoin, pas de parallélisme, pas de coordination, pas de cerveau tout simplement. » | Juste. Au-dessus du coffre : « Objectif : Charbon — il manque : 62 Plaque de fer » ; une dizaine de PNJ attendent au coffre ; un gisement de fer proche n'est pas exploité ; un PNJ va seul à la pierre, un autre au charbon. Cause : l'échelle à un seul objectif (le charbon) ne déplie pas le besoin (le fer) ; un seul minage à la main par minerai ; PNJ libres sans tâche de leur pôle. Devient le CAS DE TEST des lots IA3-b (plusieurs PNJ minent quand une plaque manque) et IA3-c (dépliage des buts : le charbon demande du fer, donc extraire et fondre le fer en parallèle) | ⏳ En cours (IA3-b, IA3-c) |
| 25/10, vers 11 h 35 | En regardant une partie : « je remarque que les IA/pnj sont vraiment lent, avancent pas vite technilogiquement alors qu'ils pourraient, je comprend pas. Bon, du coup je remarque qu'il y a une grande marge de progression dans la conception des IA. Aussi, ils avancent pas en parallèle aussi. » | Juste : factions plafonnées à la recherche 3 (pas de pétrole, lot IA1-e2 non fait) ; objectifs d'équipe menés l'un après l'autre (plan directeur IA1-d non fait) ; à 4 ouvriers par faction, l'économie est petite. Diagnostic chiffré lancé (IA3-DIAG : où part le temps, ce qui serait possible, plan de lots), puis correction | ⏳ En cours |
| 25/10, vers 11 h 25 | Observé en jouant : « aussi j'ai remarqué que sur les 8 PNJ y en avait pas mal qui faisaient rien et ils retournaient au coffre et attendaient » | Défaut connu (guide : « environ 1 ouvrier sur 3 attend » ; IA1-b : le travail de fond n'est actif qu'au-delà de l'effectif de départ, F241) : transmis au lot IA1-b2 (réponse « Donner du travail ») avec un objectif chiffré : inactifs ≤ 15 % à 8 PNJ dans la partie du guide (critère C5-2 de `docs/EQUIPES_PNJ.md`) | ⏳ En cours |
| 25/10, vers 10 h 50 | Texte sur les factions et les commandes d'équipe (`/fo-team org`, `orientation`…) : « Juste un truc où je suis pas d'accord, c'est les commandes pour manager, l'idée serait plutôt d'avoir une interface. Pas des commandes à taper, c'est chaint ça en jeu. » | Juste : l'interface à onglets prévue (`docs/EQUIPES_PNJ.md` §8, lot IA1-i) n'a jamais été construite ; les commandes ne devaient servir qu'aux bancs. Lot IA1-i lancé : interface ouverte par un raccourci et une touche, onglets de l'équipe et un onglet Factions (ce que montrait `/fo-war status`) ; les commandes restent pour les bancs | ✅ Fait : version 0.4.28, fenêtre validée par le DC |
| 25/10, vers 10 h | Atlas des designs (https://claude.ai/artifact/Dfvg6UEeQN5YYAYHZRS5Pt), image « Niveaux 21 à 30 : seule la teinte change » : « Le fait que seule la teinte change pour les fours ainsi que les machines à construire et les foreuses, ça c'est complètement à bannir. Seule la teinte elle change. Je veux bien qu'il y ait des changements de teinte d'un palier à l'autre, mais bon, au bout d'un moment là, non, c'est beaucoup trop laid. Là, c'est vraiment beaucoup trop laid. » | Défaut reconnu : four, assembleur, foreuse (et centre, mur) n'ont que l'image du jeu de base teintée et agrandie ; les lots de design par âge F2 à F6 du plan (`fo-logs/2026-10-23_plan-suite/PLAN_SUITE.md`, même méthode que la mitrailleuse) n'ont jamais été lancés : ils passent en tête des priorités visuelles. Une teinte peut distinguer les deux niveaux d'un même âge, jamais remplacer le design d'un âge | ⏳ À faire (lots F2 à F4 d'abord) |
| 22/10, 16 h 45 | Planches V3-S (3 approches de la mitrailleuse) : designs « parfaits », « absolument époustouflants surtout pour les canons », « très précis », « je vous félicite » ; MAIS « on n'a pas le côté changement d'époque avec une DA par époque » ; piste : « reprendre le même style en mode changer des canons et des tuyaux pour correspondre à une DA d'un âge » (citation complète : §4, Q-S1) | Style des planches V3-S retenu tel quel : votre verdict prime sur celui des juges (qui notaient 6 sur 10) ; la passe de synthèse qui retouchait la forme est ARRÊTÉE (16 h 47). Lot **V3-E** : même style, canons, tuyaux et accents changés selon la direction artistique de chaque époque (bible V1, `docs/DESIGN_EPOQUES.md` §5), mitrailleuse sur les 15 époques d'abord. **Reformulation confirmée par vous le 22/10 vers 17 h 20** (« c'est exactement ça ») : « Même style et même précision, mais chaque époque a sa propre direction artistique, qui se voit d'un coup d'œil. Surtout par les canons et les tuyaux, pas par une simple couleur » (Vapeur : cerclages de laiton, tuyaux de cuivre, manomètres ; Atome : canons blindés de plomb, conduits épais, petite lueur verte ; Fusion : canons à plasma, anneaux lumineux, gaines de céramique ; Légende : or blanc, couronnes, particules) | ✅ **Design validé par vous le 23/10 à 14 h 50** (15 âges ; ère V refaite en Antimatière, La Porte, Néant). Historique : passe 3 (E63, 22/10 23 h 59) et passe 4 (E64, 23/10 5 h 40) jugées « pas prêt » : environ 7 à 8 âges sur 15 reconnus en description libre, pour un seuil de 12 ; canons dressés lus comme des cheminées ; la précision au zoom 2 est intacte. Défaut de l'orchestrateur : le test du catalogue (avec la liste des triplets) n'a pas été appliqué aux passes 3 et 4, et il n'avait lieu qu'à la fin. Passe 5 lancée le 23/10 vers 6 h 05 (test pendant la construction, en rondes) ; page de la passe 4 : https://claude.ai/artifact/1JLASdszGV6fHUSUHPKoVx |
| 23/10, 7 h 50 | Canons de V3-E (pages des passes 3 et 4) : « un retour sur les canonds : je les trouves parfait, même si j'attendai un peu plus de design exhautique, en fait je pense que pour les canons c'est un peu normal que ce soit comme ça, pour le reste (usines, foreuses, etc... hormis les bras mécaniques je pense (qui seront "juste plus rapide" avec un léger nouveau design peut être) le reste devra avoir plus de design surprenant, mais les canons sont vraiment bien. En fait le pour qui me dérange un peu c'est que dans clash of clans, les designs, changent vraiment beaucoup d'une évolution à une autre, et du coup on remarque vraiment la différence (bon eux ils ont pas ta problématique qui est d'augmenter la taille etc et du coup t'as parfaitement faitp, le soucis c'est vraiment quand je les vois j'ai un effet wow mais j'ai encore du mal à deviner en fait quel est le grade légende par exemple, je pense pas qu'il faille mettre à la poubelle, mais simplement revoir le niveau de différence entre chaque age en fait, et du coup la DA avec, je pense qu'on va benchmark la DA de l'age avec les canons du coup » | Rien n'est jeté. La mitrailleuse devient l'ÉTALON de la direction artistique de chaque âge. Passe 5 réorientée à 7 h 55 (RD_LOG, décisions du 23/10) : chaque âge change la matière de tout le bâtiment, sa silhouette, ses canons, ses tuyaux et sa lumière, avec une progression de prestige jusqu'à la Légende ; nouveau test à l'aveugle des écarts entre âges voisins (critère Clash of Clans). Pour les autres familles (lot V3) : designs plus surprenants ; bras mécaniques « juste plus rapides », au plus un léger nouveau design | ⏳ En cours (passe 5, run `wf_5b157c7b-fa0`) |
| 23/10, 9 h 48 | Aperçus de la ronde 2 de la passe 5 : « alors, je viens de voir et c est parfait, les designs sont vrm bien, seul siucis c est que c ezt trop uniforme en therme de palette de cçuleur; mais si non les designs sont vraiment top » | Designs de la ronde 2 validés par vous ; chantier : la palette. Chaque âge reçoit une couleur dominante propre, différente de ses voisins, et chaque bâtiment une dominante, une secondaire et un accent (60/30/10) ; consigne donnée aux constructeurs à 9 h 50, à partir de la ronde 3. **Lecture confirmée par vous** (« oui c est parfaitement ca ») | ⏳ En cours (passe 5) |
| 23/10, 12 h 40 | Aperçus de la ronde 5 de la passe 5 : « je viens tout juste de voir la xerniere ronde et je trouve que tous les batiments sont pratiquement parfait sauf les 3 derniers, la couleur ne mne va pas, pareil pour le theme legende, je prefererai un truc genre bigbang ou maitrise cosmique du nean, je penze que le defaut est suttout lie au senario pour le coup » | Âges 1 à 12 retenus tels quels (rendus définitifs lancés à 12 h 33). Âges 13 à 15 à refaire après un nouveau scénario de l'ère V ; question posée dans le chat : A = ère V cosmique (13 Étoile, 14 Nébuleuse, 15 Néant / Big Bang ; recommandation), B = seule la Légende devient Big Bang / Néant, Fusion et Orbite recolorées, C = autre ; sans réponse vers 14 h : A. Option A précisée dans le chat pour suivre l'histoire du jeu : 13 **Antimatière** (bouteilles magnétiques, annihilation violette et bleue), 14 **La Porte** (espace profond, étoiles, anneau de la Porte), 15 **Néant** ou Singularité (maîtrise du trou noir du Cœur, « un Big Bang tenu en laisse ») ; seuls le nom et l'apparence changent, pas le contenu. **Votre réponse (vers 13 h 10) : « l option A est bien »** | ⏳ En cours : ère V refaite (run `wf_5f1609fb-473`, lancé vers 13 h 15 ; sorties `<racine>\fo-logs\2026-10-23_V3E-ereV\`) ; noms des âges dans le jeu (`shared/content/epochs.lua`, `locale`) à changer à l'intégration |
| 23/10, 14 h 50 | Ère V cosmique, aperçus de la ronde 2 : « c est valide, les styles sont parfait, j aime beaucoup, il reste evidemment les animation et les bruits mais si non c est parfait, je valide les designs de l ere V, il manque encore les biomes, des styles de mineraux, de nouvelles ressources et des moyens pour les e ploiter mais si non cest bien, passez a le suite » | **Designs de la mitrailleuse validés par vous pour les 15 âges** (1 à 12 : passe 5, ronde 5 ; ère V : ronde 2, `6d0e961`) ; branche `v3e-final` (`40cad92`). Rendus définitifs de l'ère V et planches finales en cours (run `wf_c46edecb-f29`). Suite : intégration en jeu de la mitrailleuse (animations et bruits compris), puis les 6 autres familles (designs plus surprenants) ; biomes, styles de minerais, nouvelles ressources et moyens de les exploiter : lots B6, B7, X1 à X15 | ✅ design validé ; ⏳ intégration en jeu |
| 23/10, 15 h 05 | Portée de la suite : « en fait la liste serait beaucoup plus exhaustive que les simples quelques elements listes precedemment, comme les cçnvoyeurs par exemple, ou des balles, ou des nukes, ou des robots de defense, ou des bras mecanique, ou encore des ressources, des mineraux, des animations etc etc etc » | La refonte visuelle et sonore porte sur tout le jeu (inventaire exhaustif de data.raw par catégorie, ce qui change à chaque âge, par paliers ou une fois) ; plan en cours (run `wf_632b4009-57a`) | ⏳ Plan en cours |
| 24/10, 10 h 25 | Équipes de PNJ organisées (IA1) : « A » (les construire maintenant, en parallèle du visuel) | Construction d'IA1 lancée (première vague IA1-0, IA1-a, IA1-c) ; propositions par défaut pour Q-IA1-1 à 7 (D-14) | ⏳ En cours |
| 24/10, 8 h 35 | Réponses aux questions de la page du matin : « L'éclat de tir : B mais A sur les dernières aires, 3) A, 4) B, 5) (Rappel : la question 3 du plan) la longue, un design par âge, c'est B » | Q-A4-1 : B puis A aux dernières ères (à préciser) ; Q-A4-2 : A (socle animé partout) ; Q-A4-3 : B (bande de couleur d'équipe) ; Q-P3 : B (un design par âge) | ⏳ À appliquer |
| 24/10, 8 h 30 | La mitrailleuse en jeu (page du matin, version 0.4.10) : « Ok pour les mitrailleuses j'aime bien » | Verdict positif sur la mitrailleuse telle qu'elle est en jeu (64 positions, sons par ère, éclat de tir A, socle animé en essai à l'âge 6, restes à la taille) ; choix provisoires gardés ; les questions précises (Q-S0-1, Q-A4-1 à 3, confirmation de Q-P3) restent ouvertes sans bloquer la suite | ✅ |
| 21/10, 14 h | « c'est surtout la couleur qui change, ce n'est pas un nouveau design » | Silhouettes composées (armes spéciales), lueurs, biomes refaits | 🟨 Corrigé pour les armes, pas pour les niveaux |
| 21/10, 14 h 17 | Biomes pas assez différents, marais « ultra vert » | Textures choisies d'après leur couleur mesurée, décor dense | 👁 Votre verdict manque |
| 21/10, 17 h 26 | Niveaux : « je ne vois QUE un changement de couleur/teinte » | Constat exact (E25 rejeté). Critères D1 posés ; phase V | ❌ Ouvert |
| 22/10, 7 h 15 | Planches V3 phase 1 (centre, mitrailleuse, laser, assembleur) : « Alors en regardant plus près j'ai l'impression que ça ne respecte pas la direction artistique du jeu un peu. C'est peut-être qu'impression de ma part. Mais du coup, j'ai l'impression que ça ne respecte pas la direction artistique du jeu. Ça manque de détail en fait les dizaines sont pas mal, je dis pas, mais j'ai l'impression que ça manque de détail et en fait, on a pas l'impression que les niveaux supérieurs sont vraiment plus badasque les niveaux inférieurs en réalité. » | Constat juste. Causes analysées par l'orchestrateur : (1) détail mécanique trop faible (formes primitives propres, peu de tuyaux, rivets, câbles, crasse) ; (2) couleurs d'époque posées sur des corps entiers (rose, vert, cyan) au lieu des seuls éléments lumineux ; (3) la règle « ajourer » (Q8) et le critère D1-3 ont poussé les époques hautes vers des mâts fins et des formes creuses, moins massives, donc moins « badass ». Finition de la phase 1 arrêtée ; lot V3-S (direction artistique et progression de puissance) lancé sur une famille témoin avant toute reprise | ❌ Ouvert |

---

## 6. Feuille de route (ordre fixé par vos réponses Q3 et Q5)

### Les 15 époques (validées par Q7 le 21/10 ; chaque ligne devient un lot de contenu ; branches avancées à concevoir au lot X0)

| Époque | Thème | Ressources ou matériaux nouveaux | Bâtiments et familles nouveaux (pistes) | Logistique | Direction artistique de la silhouette |
|---|---|---|---|---|---|
| 1 | Pionnier | fer, cuivre, charbon, pierre | bâtiments de base (vanilla) | T1 | fer brut, bois, rivets, sacs de sable |
| 2 | Forge | acier | four en acier, murs de pierre | T1 | plaques d'acier boulonnées, cerclages |
| 3 | Vapeur | eau, vapeur | chaudières, machines à vapeur | T1 | cheminées, tuyaux de cuivre, manomètres |
| 4 | Pétrole | pétrole, plastique, soufre | raffinerie, chimie | **T2** | cuves, conduites, jauges, passerelles |
| 5 | Volcan | **tungstène** (biome cendres) | tourelle-canon, mortier | T2 | blindage sombre, rivets lourds, braises |
| 6 | Électricité | batteries | tour à arc, tourelle laser | T2 | bobines, isolateurs, arcs lumineux |
| 7 | Cristal | **cristal de résonance** (plaine de cristal) | amplificateurs à cristal | **T3** | cristaux enchâssés, lueur violette |
| 8 | Marais | **méthane** (marais) | pulvérisateur d'acide, lance-flammes | T3 | cuves de verre, bulles, conduits toxiques |
| 9 | Atome | uranium | nucléaire | T3 | blindage plombé, lueur verte |
| 10 | Haute technologie | processeurs | robots, radars avancés | **T4** | carénages lisses, voyants, antennes |
| 11 | Titane | *nouvelle ressource* (nouveau biome) | structures légères | T4 | alliage blanc, ailerons |
| 12 | Supraconducteurs | *terres rares* (nouvelle ressource) | rail, aimants, fusil à rail | T4 | anneaux magnétiques, pièces en lévitation |
| 13 | Fusion | *hélium-3* (nouvelle ressource) | réacteur à fusion | **T5** | confinement de plasma, anneaux lumineux |
| 14 | Orbite | *météorites* (nouvelle ressource) | lanceurs, satellites | T5 | panneaux dorés, paraboles |
| 15 | Légende | *matière exotique* (nouvelle ressource) | merveilles | T5 | or blanc, couronnes, particules |

### Ordre des chantiers
1. **Phase 0, reprise** : environnement Claude Code, git, bancs verts (§7).
2. **Phase V, visuel des 7 familles** (Q3) : pipeline de rendu (H-V1), bible des époques, refonte par
   famille, critères D1 à D3, puis votre verdict.
3. **Phase C, Compaction ×4** (Q5) : tapis, bras et chargeurs T2 à T5, objets denses, machines,
   énergie, visuels, banc de débit en moteur réel (H-B1).
4. **Phase X, contenu des époques** : ressources, biomes, bâtiments, époque par époque (F1).
5. **Phase I, idle** : score de puissance, objectifs et récompenses, file de chantiers, plus de
   familles (E3).
6. **Phase IA** : pétrole et époques pour les équipes IA (C2), armées de 100 (C1), PvP (C4).

### Plan de la suite (23/10, après la validation de la mitrailleuse)
Le détail (buts, dépendances, estimations, preuves exigées, contraintes de disque et de rendu) est dans
`<racine>\fo-logs\2026-10-23_plan-suite\PLAN_SUITE.md` (page pour vous : https://claude.ai/artifact/HqmTtxz3dajFS4fnc4a6xV).
Il précise l'ordre ci-dessus pour la refonte visuelle et sonore de TOUT ce qui se voit et s'entend (votre demande du
23/10, 15 h 05). Les étapes, dans l'ordre ; l'état de chaque lot est au §7, « Suivi des lots » :
1. et 2. A0 (ménage et garde-fous), puis A1 (la rose des 8 directions de la mitrailleuse, E66, E67, E70) ;
3. A2 : la mitrailleuse EN JEU à 4 directions (premières captures en jeu d'un design V3) ;
4. A3 : 64 directions (Q-P2 : A), rendu de nuit ;
5. A4 (éclats de tir, socle animé, ruines, couleur d'équipe) et S0 (la chaîne des sons) ;
   en parallèle des étapes 3 à 5, sans rendu : K0 (kit commun des familles) et M0 (socle du monde : monnaies des
   âges 5, 7 et 8 garanties) ;
6. F1 à F6 : les 6 autres familles (laser, four, assembleur, foreuse, centre, mur), une à la fois ;
7. M1 à M3 : le monde (un minerai témoin, un sol témoin, puis les 3 biomes refaits), en parallèle de l'étape 6 ;
8. la logistique avec la Compaction (phase C) ;
9. le contenu des époques par ère (phase X), puis le combat (armes, effets, robots, ennemis).
La phase I (idle) et la phase IA restent après, comme ci-dessus. Q-P3 (rythme des objets hors des 7 familles) est à
confirmer avant les lots X.

---

## 7. Reprise dans Claude Code (multi-agent)

**À lire d'abord**, dans cet ordre :
1. `CLAUDE.md` : règles, chemins, commandes, pièges ;
2. ce fichier ;
3. ARCHITECTURE.md (§2 règles, §7 bis niveaux, §8 bancs) ;
4. BALANCE_SHEET.md §12 ;
5. RD_LOG.md, sessions 5 et 4.

### État exact à la fin de la session 5 (21/10, 17 h 45)
- Tout le code est synchronisé dans `mods\factorio-overhaul` sur votre PC. Pas encore de dépôt git.
- Bancs verts :
  - hors jeu : run 114, war 86, td 270, pteam 15, migration 12, levels 556 ;
  - api_lint : 0 erreur ;
  - étape data : 0 nouvelle erreur ;
  - **moteur réel, scénario `content` : 180/180** (21/10, 17 h 30).
- Galerie des niveaux (70 prototypes, jour, nuit et vues hautes) capturée, puis **rejetée** sur le
  design (E25).
- Une session `fo-visual` (Factorio de test) peut être restée ouverte. Pour la fermer : menu Échap →
  Quitter, ou arrêt ciblé sur la ligne de commande qui contient `fo-visual` (jamais tous les
  `factorio.exe`).

### Découpage en lots parallèles

**Règle d'or** : un seul agent intégrateur modifie les fichiers partagés :
- `data.lua`, `control.lua`, `settings.lua`, `info.json` ;
- `shared/levels/config.lua` ;
- les documents.

Chaque lot crée ses **propres fichiers de traduction** (`locale/fr/<lot>.cfg`, `locale/en/<lot>.cfg`) :
Factorio charge tous les `.cfg` du dossier, ce qui évite les conflits de fusion.

| Lot | Dépend de | Fichiers possédés | Livrable et preuve |
|---|---|---|---|
| P0 Reprise | — | `.gitignore`, outillage | `git init`, Lua 5.2 et Python installés, tous les bancs verts depuis Claude Code, `content` 180/180, fichiers orphelins `script/faction/engineer.lua` et `tools/sim_war.lua` supprimés |
| P1 Captures automatiques (H-T1) | P0 | `tools/autotest/` | Galerie produite et session fermée sans intervention humaine |
| V0 Pipeline de rendu (H-V1) | P0 | `tools/render/` (nouveau), `graphics/` (nouveau) | Une pièce 3D rendue (principal, ombre, lueur) posée à côté de bâtiments vanilla, captures jour et nuit aux zooms 1 et 2, **votre verdict** |
| V1 Bible des époques | — (en parallèle de V0) | `docs/DESIGN_EPOQUES.md` (nouveau) | 15 époques × 7 familles : silhouette, pièces, matériaux, lumière ; planches de concept dès que V0 est prêt |
| V2 Cadre des 15 époques | P0, Q6 | `shared/levels/config.lua`, `prototypes/levels/` (découpage en un fichier par famille), `tests/levels_test.lua`, BALANCE_SHEET §12 | Niveaux par époque, nouvelle courbe, ouvriers 1 à 5, tests verts |
| V3-a à V3-g Une famille chacune (centre, mitrailleuse, laser, mur, foreuse, four, assembleur) | V0, V1, V2 | `graphics/levels/<famille>/`, `prototypes/levels/<famille>.lua`, `locale/*/levels-<famille>.cfg` | Sprites des 15 époques et des pièces ; D1 mesuré automatiquement ; galerie |
| V4 Contrôle visuel | V3 | `tools/render/check_silhouettes.py`, `content_test.lua` (galerie) | Test du gris, vignettes, recouvrement des silhouettes < 50 %, gros plans, banc `content` vert, **votre verdict** |
| C1 à C5 Compaction ×4 | V4 | `prototypes/logistics/`, `shared/content/logistics.lua` (nouveaux) | Débits mesurés en moteur réel (H-B1), chaîne de densité, énergie, visuels |
| X0 Scénario, crafts et branches avancées | Q7 | `docs/SCENARIO_EPOQUES.md` (nouveau), `shared/content/epochs.lua` (nouveau, données pures), `tests/epochs_test.lua` (nouveau) | Scénario, arbres de fabrication des 15 époques et des branches avancées ; graphe vérifié hors jeu (tout objet fabricable depuis les ressources) |
| X1 à X15 Époques | C, X0 | un dossier par époque | Ressource, biome, bâtiments, prouvés au banc |
| IA0 PvP et difficulté (C4) | Q4 | `shared/faction/*`, `script/faction/*`, `settings/faction.lua` (nouveau), `tests/war_test.lua`, `locale/*/ia0.cfg` | Attaques contre le joueur selon la difficulté ; tests hors jeu ; scénario moteur réel après P1 |

**Banc en moteur réel = ressource partagée.**
- `fo-autotest.bat` prend un verrou et **efface `fo-autotest\` à chaque lancement**. Les tests sont donc
  lancés un par un, et chaque agent copie ses journaux avant le test suivant.
- Autre possibilité : rendre le dossier de test paramétrable, un par lot. Les mesures de performance
  restent alors réservées à un passage seul, épinglé.

### Suivi des lots (session 6)

| Lot | État | Preuve | Date |
|---|---|---|---|
| P0 Reprise | ✅ | Dépôt git `main` (commit initial `4b2a1e0` = état de fin de session 5). Lua 5.2.4 compilé depuis lua.org (sommes vérifiées), Python 3.14.7 présent. Hors jeu : run 114, war 86, td 270, pteam 15, migration 12, levels 556 ; étape data : 496 prototypes, 0 nouvelle erreur, 0 violation, 0 clé de traduction manquante ; api_lint : 317 usages, 0 erreur. **Moteur réel `content` : 180 OK, 0 échec**, deux fois (avant et après la suppression des orphelins ; E26). Aucune session `fo-visual` ouverte, aucun verrou orphelin. Orphelins supprimés. | 21/10, 17 h 57 |
| P1 Captures automatiques | ✅ H-T1 validée | `fo-captures.bat` : galerie `content` deux fois (code 0, 84/84, 117 s et 79 s, 0 processus restant), vitrine 26/26, guerre 21/21 ; codes 2, 3, 6, 7 testés ; greffons de scénarios et de contrôles. **Revérifié par l'orchestrateur après fusion** : `content` 182 OK, 0 échec (19 h 06) ; code de fermeture relu (ne vise que le PID lancé et la ligne de commande `fo-visual`) | 21/10, 19 h 10 |
| V0 Pipeline de rendu | ✅ **style validé par vous** (21/10, 19 h 36 : « Verdict V0 : le style de la cheminée s'intègre bien au vanilla, validé. Corrigez les défauts techniques relevés et lancez la production V3. ») ; défauts techniques à corriger au lot V0b | Blender 5.2.2 (somme vérifiée) ; étalonnage mesuré (E29) ; cheminée rivetée rendue (4 couches) et posée en jeu à côté du vanilla ; 18/18 captures jour/nuit, zooms 1, 2 et 4 (E30). Défauts connus : pièce trop mate (écart-type et p95 hors plages vanilla), anneau translucide la nuit | 21/10, 19 h 36 |
| V1 Bible des époques | 🟨 👁 bible livrée et intégrée (`docs/DESIGN_EPOQUES.md`, 1 153 lignes, + `docs/epoques/mesures/`) ; aucune planche (attend V0) ; questions Q8 à Q12 ouvertes ; faits vérifiés par 3 vérificateurs adverses : F44, F45, F46, F48 confirmés avec corrections, F47 (soleil au nord-ouest) RÉFUTÉ et corrigé (ombres plein est), E27 corrigé ; bible corrigée | Fusion `b1348e2` ; mesures vanilla sourcées fichier par fichier ; rien de vérifié en jeu | 21/10, 18 h 45 |
| V0b Corrections du pipeline | ✅ technique, intégré ; 👁 planches V0 / V0b envoyées pour votre regard (le style V0 validé est conservé) | Trou du halo du four équipé corrigé (écart au voisinage 0,245 → 0,011) ; collerette opaque (0 pixel transparent enfermé, contre 49) ; braises orange (b/r 0,42 → 0,02, comme le feu vanilla) ; photométrie du corps au niveau de l'assembleur vanilla (p50 0,205 contre 0,198) ; recalage au pixel ; qualité normale capturée ; contrôles de la bible bloquants dans le pipeline ; déterminisme 18/18 ; `content` 212 OK après fusion ; planches : fo-logs\2026-10-21_V0b_vitrine-final\planches-dc | 22/10, 2 h 45 |
| V3 phase 1 : modélisation des 7 familles | ❌ **direction artistique rejetée par vous** (22/10, 7 h 15 : manque de détail, ne respecte pas la DA de Factorio, niveaux hauts pas plus « badass ») ; finition arrêtée, travail conservé (silhouettes et scripts réutilisables) | Aperçus des 15 époques du centre et des 30 niveaux de 3 familles ; D1-3 tenu en mesure, mais la mesure ne disait rien de la DA ni de la progression de puissance | 22/10, 7 h 15 |
| V3-S Direction artistique Factorio et progression « badass » | ✅ **Style retenu par vous le 22/10 à 16 h 45** (« parfaits », « époustouflants surtout pour les canons », « très précis ») sur les planches de la première passe (E45 ; https://claude.ai/artifact/2jA1RqTTiF7GDWwPkSjXKJ) ; charte intégrée (E43) ; Q-S1 à Q-S3 : oui. Écart signalé : pas de direction artistique par époque → lot V3-E. Passe de synthèse (run `wf_eaa96606-5f1`) arrêtée à 16 h 47, sans livrable : elle retouchait la forme que vous approuvez | `docs/da/` ; `<racine>\fo-logs\2026-10-22_V3S\` | 22/10, 16 h 50 |
| V3-T Emprise croissante et agrandissement sur place (Q23, Q24) | ✅ **intégré dans `main` le 22/10 à 14 h 50** (fusion `13b4134` de `de6e628` + `3b06952`), **version 0.4.2** ; mécanique ACTIVÉE pour la seule mitrailleuse (2×2 → 3×3 → 4×4 → 5×5 → 6×6, une taille par ère), autres familles en attente de Q-S1 ; **aucun visuel nouveau** (sprite actuel agrandi, provisoire : le visuel attend votre verdict sur V3-S). 3 relecteurs adverses : 17 défauts (5 majeurs), 16 corrigés et 1 réfuté en moteur réel (F74). **Non prouvé en moteur réel** : panneau, aperçu au sol et bouton (pas de joueur en mode benchmark ; moteur simulé seulement, aucune capture) ; migration d'une vraie sauvegarde 0.4.1, filet compris (H-T3 ; **prouvée en moteur réel depuis, sur une carte de banc, filet en expérience de contrôle seulement : ligne suivante**) ; remboursement F40 inventaire par inventaire ; transfert des fluides, du brûleur, de la recette, des fils et des réglages de foreuse ; machines agrandies (étape data réelle seulement) | **Moteur réel** `content` sur `main` : **238 OK, 0 échec** (210 du banc, 2 de l'exemple, 26 du greffon `levels_taille` ; 22/10, 14 h 51 ; 13 contours, 13 refus, 8 agrandissements, 0 renversé, 0 échec, 0 forcé, 0 laissé). Hors jeu : run 114, war 92, td 270, pteam 15, migration 50, levels 1 564 + 11 écarts connus, pvp 596, epochs 16 665, org 362 ; étape data 0 erreur ; api_lint 434 usages, 0 erreur ; d4m 4/5 (échec préexistant de l'outil, sans lien ; corrigé depuis, 5/5 : ligne suivante). Mutations : 24 jouées, 23 tuées, 1 équivalente. RD_LOG E44, F70 à F75 ; journaux `<racine>\fo-logs\2026-10-22_V3T\` et `<racine>\fo-logs\2026-10-22_V3T-integration_content\` | 22/10, 14 h 56 |
| Suites de V3-T : H-T3 (migration réelle), bancs hors jeu (harness, moteur simulé, `levels_test`), d4m | ✅ **intégrées dans `main` le 22/10** (fusions `--no-ff` `e1a6a6f`, `1f2ff79` et `18a00d4`, puis `c4d37e5` : commentaire de `footprint_problems`) ; version inchangée (0.4.2). Chaque suite : un constructeur, une revue adverse, un correcteur (H-T3 : 5 défauts mineurs ; bancs : 1 majeur et 4 mineurs ; d4m : 1 majeur et 3 mineurs ; tous confirmés et corrigés, la carte de H-T3 en partie seulement). **H-T3 : (1) prouvée en moteur réel ; (2) prémisse réfutée (F77) ; filet prouvé seulement en expérience de contrôle.** Constat remonté : une mitrailleuse collée à une ligne de murs et nourrie par un bras placé derrière reste hors grille, en service (question Q-T3, §4). Harness : règle des points de jeu (raccords, dépôts) pour toute entité. Moteur simulé : boîtes vanilla de tous les prototypes intégrés (le modèle hybride du constructeur faussait pvp : artefact « Normal 18,2 > Difficile 18,0 », à ne pas transmettre à IA0b). **Non prouvé**, entre autres (liste complète : RD_LOG E46 à E48) : rechargement réel d'une carte déjà migrée ; défense dense ; amélioration ultérieure d'une mitrailleuse laissée hors grille (coince7, rempart7) ; crochets `on_replaced`, transfert d'un chantier 0.4.0 et `st.cc` d'un centre reposé (moteur simulé seulement) ; vrai échec partiel de robocopy (simulé seulement) ; effet de `FO_CREATE_SRC` sur `fo-captures.bat` ; contact bord à bord et filtre `collision_mask` de `find_entities_filtered` en moteur réel ; machines agrandies en moteur réel | **Moteur réel** sur `main` : `content` **238 OK, 0 échec** (`done.txt` 22/10/2026 17:06:23,34) ; migration réelle 0.4.1 → 0.4.2 en double source (scénario `ht3-migration`, 700 ticks, `mod_changes` 0.4.1 -> 0.4.2) : **29 OK, 0 échec**, journal **7 OK**, 6 reposées, 2 déjà en place, 3 laissées (17:06:44,67). Hors jeu sur `main` (17 h 06 à 17 h 13) : run 114, war 92, td 270, pteam 15, migration 60, levels 1 564 + 11 écarts connus, epochs 16 665, org 362, pvp 596 ; harness 0 erreur nouvelle, 0 violation, points de jeu vanilla 18 entités / 51 points et mod 61 / 182, auto-contrôle 11/11, 0 clé manquante ; api_lint 447 usages, 0 erreur ; d4m **5/5** ; mut_atlas 40 OK ; test_ht3_journal 9 OK ; bat_double_source 4 OK. RD_LOG E46 à E48, F76 à F82 ; journaux `<racine>\fo-logs\2026-10-22_V3T-suites\` et `<racine>\fo-logs\2026-10-22_V3T-suites-integration\` | 22/10, 17 h 25 |
| V3-T2 Emprise croissante des 5 autres familles (Q-S1 : oui) | ✅ **intégré dans `main` le 22/10 à 19 h 05** (fusion `--no-ff` `681dd5c` de la branche `worktree-wf_04ba1f63-d67-1` : ingénieur `3e9a23e`, `f5f6a77`, `be0ee03` ; correcteur `e84ca84`), **version 0.4.3** ; entrée 0.4.3 du changelog réécrite pour le joueur (`aec3baf`). Tourelle laser et four 2×2 → 6×6, foreuse et assembleur 3×3 → 6×6, centre 4×4 → 8×8, une taille par ère (mur inchangé). Transfert complet (recette, contenu, modules, fluides, fabrication en cours reprise au tick suivant, orientation, fils et réglages de circuit, barre et filtres) ; points de jeu servis gardés (dépôt d'une foreuse, raccords de tuyau) ; bâtiment hors grille remis sur la grille par script (F86) ; message de migration aux joueurs ; doublons hérités relevés. Revue adverse : 3 relecteurs, 19 défauts ; le majeur (points servis selon l'orientation) CONFIRMÉ en moteur réel par un témoin sur `be0ee03` (308 OK, 9 échecs dont 1 artefact du témoin) et corrigé ; deux défauts plus graves trouvés en le prouvant (F90 : 12 assembleurs sur 12 privés de leur tuyau ; F91 : 9 assembleurs tournés sur 9 revenus au nord), corrigés. **Visuel provisoire, laid aux grandes tailles** (sprite actuel agrandi ×2 à ×3), sans votre verdict (D1-4). **Questions ouvertes pour vous** : Q-T2-1 (usine réelle : une machine bordée de ses bras ne grandit jamais sans démontage ; 18 sur 24 hors grille à la migration ; Q-T3 rattachée) et Q-T2-2 (production par tuile qui baisse). **Non prouvé** (liste complète : RD_LOG E49 à E52) : migration d'une machine EN fabrication (non jouable : `--create` sauvegarde au tick 0 ; moteur simulé seulement) ; seconde amélioration avant le `on_tick` du mod (défauts 2 et 15 : sans joueur, non reproductible) ; raccords du fluide de minage, boîte à fluide de sortie, fluide chaud rendu ; panneau, lignes « hors grille » et « points-moved », message de migration à l'écran (pas de joueur en mode benchmark) ; filet sans montée de version pour 0.4.3 et second chargement d'une carte migrée ; doublons hérités (détection hors jeu seulement ; « F86 touchait 0.4.2 » : inféré) ; F85 avec un vrai poteau ; dispositions d'usine autres que la disposition synthétique ; vos sauvegardes (ni touchées ni testées) | **Moteur réel sur `main`** (22/10, `done.txt` de 19:05:39,98 à 19:05:52,39 ; archives `<racine>\fo-logs\2026-10-22_V3T2-integration\`) : `content` **317 OK, 0 échec** (210 du banc, 2 de l'exemple, 26 de `levels_taille`, 54 de `levels_machines`, 25 de `levels_points`) ; `t2-machines` **80 OK** ; migration réelle 0.4.2 → 0.4.3 (`t2-migration`, double source `src-0.4.2`) **64 OK**, journal `--tag FO-T2-MIGRATION` **26 OK** (21 reposés, 3 déjà en place, 19 laissés) ; `ht3-migration` (0.4.1 → 0.4.3) **30 OK**, journal **7 OK**. Hors jeu sur `main` (19 h 05 à 19 h 10) : run 114, war 92, td 270, pteam 15, migration 79, levels 1 575 + 11 écarts connus, epochs 16 665, org 362, pvp 596 ; harness 0 erreur nouvelle, 0 violation, mod 61 entités / 182 points, auto-contrôle 11/11, 0 clé manquante ; api_lint 519 usages, 0 erreur ; d4m 5/5 ; mut_atlas 40 OK ; test_ht3_journal 15 OK ; bat_double_source 4 OK. RD_LOG E49 à E52, F83 à F95 ; notes et passages du lot : `<racine>\fo-logs\2026-10-22_V3T2\` (`NOTES_V3T2.md`) | 22/10, 19 h 20 |
| R1 Robustesse : défense dense, contact bord à bord, atlas virtuel | ✅ **intégré dans `main` le 22/10** (run `wf_c34819e9-18a`, lancé à 19 h 38 ; deux suites, chacune avec un constructeur, une revue adverse et un correcteur ; fusions `dcc97b3` de la branche `worktree-wf_c34819e9-18a-1`, tête `f41753d`, et `58db82c` de `-2`, tête `75863a5` ; changelog 0.4.3 complété, `870f045`) ; version inchangée (0.4.3). **Suite « défense dense et bord à bord »** : scénario greffé `t2-defense` (ligne de 21 tourelles derrière un mur, en double source 0.4.1 ou 0.4.2 → 0.4.3 ; E54) : la défense migrée MARCHE (21 tourelles sur 21 tirent, 63 ennemis sur 63 tués), mais **depuis 0.4.1, 13 tourelles sur 21 sont laissées** : les 8 du tronçon A, hors grille, se chevauchent entre elles ; les 5 du tronçon C chevauchent le mur, le convoyeur, les poteaux et les bras ; depuis 0.4.2, 5 lasers laissés : 3 hors grille sans chevauchement (A), 2 qui chevauchent convoyeur, poteaux, un bras et leurs voisines (C), aucun mur ; **laid, non jugé** (Q-T2-1 complétée). Scénario greffé `bord-a-bord` (E53) : le moteur réel REND le contact bord à bord (F96) ; le moteur simulé l'excluait (21 écarts sur 45 cas), il est aligné (intervalles fermés : 0 écart). **Défaut du mod trouvé par la revue et corrigé** : `move_ground_items` déplaçait et comptait à tort un objet au sol qui touchait seulement le bord d'un bâtiment agrandi (prouvé hors jeu, contre-épreuve 1 échec). **Suite « vram »** (E55) : `vram.py` compte l'atlas virtuel du plancher (0,20 à 0,31 Go → 0,28 à 0,53 Go) ; le banc de mutations du constructeur était FAUX (« 14/14 » annoncé, 13/14 en réalité, et aucune copie ne tournait) : remplacé par `mut_vram.py`, versionné (témoin nul, 18/18). Revues : défense 1 majeur et 3 mineurs, vram 1 majeur et 3 mineurs, tous confirmés et corrigés. Faits F96 à F102 (F102 lu dans le binaire, pas en moteur réel). **Non prouvé** (liste complète : RD_LOG E53 à E55) : l'aspect de la ligne migrée (votre verdict) ; sélection, minage, remplacement et amélioration d'une tourelle laissée par le joueur ; vos sauvegardes, une vraie attaque, une création 0.4.0 ; rechargement réel d'une carte déjà migrée ; objet au sol exactement bord à bord en moteur réel (correctif prouvé hors jeu seulement) ; balayages par secteurs jointifs de `pvp.lua`, `sites.lua`, `war.lua` face au contact bord à bord ; raccord automatique des poteaux (F101, déduit) ; résidence et format des pages de l'atlas virtuel (F102 : hypothèses) ; aucune mesure de performance | **Moteur réel sur `main`** (22/10, `done.txt` de 20:11:14,81 à 20:11:40,52 ; archives `<racine>\fo-logs\2026-10-22_R1-integration\`) : `content` **317 OK** ; `t2-machines` **80 OK** ; `bord-a-bord` **12 OK** ; `t2-migration` **64 OK** + journal 26 OK ; `ht3-migration` **30 OK** + journal 7 OK ; `t2-defense` création 0.4.1 **36 OK + journal 19 OK** (« 8 reposé(s), 0 déjà en place, 13 laissé(s) ») ; création 0.4.2 **36 OK + journal 11 OK** (« 5, 0, 5 »). Hors jeu sur `main` (20 h 11 à 20 h 16) : run 114, war 92, td 270, pteam 15, migration **81**, levels **1 577** + 11 écarts connus, epochs 16 665, org 362, pvp 596 (194 s) ; harness 0 erreur nouvelle, 0 violation, points de jeu vanilla 18 / 51 et mod 61 / 182, auto-contrôle 11/11, 0 clé manquante ; api_lint **535** usages, 0 erreur ; d4m 5/5 ; mut_atlas 40 OK ; test_ht3_journal 15 OK ; bat_double_source 4 OK ; mut_vram « témoin nul survivant ; 18/18 mutants détectés ». RD_LOG E53 à E55, F96 à F102 ; notes et passages du lot : `<racine>\fo-logs\2026-10-22_R1\` (`defense\NOTES.md`, `vram\NOTES.md`) | 22/10, 20 h 21 |
| V3-T3 Bouton « Libérer la place » (Q-T2-1 : réponse B, « QT21 option B ») | ✅ **intégré dans `main` le 22/10 à 22 h 50** (fusion `8a28804` de la branche `worktree-wf_49a2ed53-111-1` : ingénieur `f26e9c3`, correcteur `d0b40da`), **version 0.4.4** ; changelog 0.4.4 (`4a7a365`). La règle Q24 ne change pas (sans clic : refus et contour). Au clic (panneau « Évolution », ou `levels_free_room` pour le banc) : les gêneurs sont MARQUÉS à démonter (robots, ou le joueur à la main ; le mod ne détruit rien) et des FANTÔMES les reposent décalés, mêmes réglages (filtres, conditions de circuit, demandes, barre) ; bras décalé le long de son axe avec ce qui le sert, convoyeur en BOSSE ou raccourci, poteau décalé si ses fils et sa zone d'alimentation tiennent, murs refermés par des murs de base ; TOUT OU RIEN (un gêneur qu'on ne sait pas reposer : refus, rien touché, gêneurs en violet et listés avec leur position) ; coût et condition Q16 exigés au clic ; agrandissement en attente, fait dès que la place est libre ; « Annuler », l'expiration (30 min) ou le bâtiment disparu remettent l'usine comme avant. Revue adverse à 3 regards : 24 défauts (2 bloquants : plan partiel exécuté, Annuler pas sûr), 23 confirmés et traités, 1 réfuté. **Limites** : (1) **rangées collées** : seul un bâtiment qui a un côté libre se libère ; plan seul sur les bâtiments laissés par les vraies migrations : **5 libérables sur 19** dans l'usine dense de test (`t2-migration`), **2 sur 13** dans la défense dense (`t2-defense`, création 0.4.1), 0 sur 5 (création 0.4.2) : le bouton ne règle pas les dispositions qui ont motivé Q-T2-1 (question de suite à poser avec les planches V3-E) ; (2) **fils de circuit** des gêneurs reposés NON refaits (message `free-wired`, non joué) ; (3) **joueur réel non joué** : panneau, boutons et jeu à la main (minage puis pose) prouvés en moteur simulé et par script seulement (pas de joueur en mode benchmark). Écart à la règle « nombres seulement » de `global` : noms de prototypes gardés en chaînes dans `global.fo.levels_free.names` (ARCHITECTURE §7 bis), signalé par le correcteur comme écart à faire valider, pas encore soumis à vous. Autres non prouvés (RD_LOG E59) : expiration et bâtiment disparu en moteur réel, place d'origine prise à l'annulation, fusion de deux réseaux par un poteau reposé, foreuses, fours, lasers et centre en moteur réel, coût bloqué au clic (non fait), coût en temps (H-L1), vos usines réelles ; visuel sans votre verdict | **Moteur réel sur `main`** (22/10, archives `<racine>\fo-logs\2026-10-22_V3T3-integration\`, code 0) : `content` **317 OK** (`done.txt` 22:50:45,71) ; `t2-machines` 80 ; `bord-a-bord` 12 ; **`t3-libere` 41 OK** (22:50:58,19 ; zones A, B1, B2, C1, C2, D, E, F, G, R avec de VRAIS robots, V, L) ; `t2-migration` 64 + journal 26 ; `ht3-migration` 30 + journal 7 ; `t2-defense` 36 + 19 (création 0.4.1) et 36 + 11 (0.4.2) ; **`t3-migration` 7 OK** (double source `src-0.4.2`, 1 000 ticks, 22:51:53,59 ; un premier passage à 700 ticks était trop court, sans BILAN : `NOTE.txt`). Hors jeu sur `main` : run 114, war 92, td 270, pteam 15, migration **82**, levels **1 642** + 11 écarts connus, epochs 16 665, org 362, pvp 596 (195 s) ; harness 0 erreur nouvelle, 0 violation, 0 clé manquante, 11/11 ; api_lint **609** usages, 0 erreur (le correcteur annonçait 615 dans son worktree : écart non expliqué, noté tel quel) ; d4m 5/5 ; mut_atlas 40 ; mut_vram 18/18 ; test_ht3_journal 15 ; bat_double_source 4. Mutants hors jeu : 9 sur 9 détectés. Captures : `<racine>\fo-logs\2026-10-22_V3T3\correcteur\captures-t3-libere\` (4 images, dont 2 de l'après). RD_LOG E56 à E59, F103 à F110 ; notes `<racine>\fo-logs\2026-10-22_V3T3\NOTES_V3T3.md` (§5 : correcteur, fait foi) | 22/10, 23 h |
| V3-T4 La production suit la surface (Q-T2-2 : réponse A) | 🟨 **LIVRÉ, NON INTÉGRÉ** (branche `worktree-wf_9d38a6df-249-1`, partie de `e27bda9` ; ingénieur `f86f2fb`, `37c9c3f`, `4ee10f1` ; correcteur `2b18742` ; version non changée). Raison : **Q-T4-1** (§4) : la DENSITÉ est tenue, la RENTABILITÉ ne l'est pas. Règle de la branche : statistique(n) = v1 × m(n) × R(n), R = (côté(n)/côté(1))² (vitesse, minage, dégâts par tir, énergie, pollution, cartouches arrondies au chargeur) : production par tuile strictement croissante, mesurée en moteur réel (écart < 0,03 % à la théorie). Coûts recalibrés pour tenir le calendrier : jusqu'à × 7,33 (four ; foreuse × 6,27, assembleur × 6,26 ; au niveau 30 : × 5,96 à × 6,85 ; foreuse 61 587 → 367 087 u, four 53 582 → 367 082 u) ; foreuse 29 → 30 remboursée en 510 h de valeur ajoutée (0.4.3 : 342 h) ; 16 améliorations sur 29 au-delà de la durée de leur époque (0.4.3 : 16 aussi) ; four et assembleur à valeur ajoutée nulle. Écarts connus 11 → 23 (place des coûts dans le coffre : 2 coûts d'un même niveau au plus bas, contre 10 à 12 ; 6 baisses de coût aux niveaux 4 à 6 ; Q14 dépassé ; PV par tuile × 0,51 au niveau 30 pour les tourelles et le four ; plafond d'une fabrication par tick avec modules ; voie unique de la foreuse). Calendrier 59 h 30 = MODÈLE conditionnel au gain, dépense de niveaux seule (192 h si le gain sert à la place ; 34 h si la recherche X0 ne suit pas). Revue adverse à 3 regards : 23 défauts. **Non prouvé** : l'hypothèse du gain (usine réelle), la pollution totale, la défense face aux tourelles à niveaux du joueur, le panneau, le ressenti « idle massif ». Pour l'intégrer après votre réponse : fusion sur 0.4.4 (conflit attendu avec V3-T3 dans `tests/levels_test.lua`, seul fichier modifié des deux côtés, vérifié par `git merge-tree`), `--calibrate`, renumérotation, tous les bancs | **Sur la branche** (archives `<racine>\fo-logs\2026-10-22_V3T4\`, passages `01_` à `23_`) : moteur réel `content` **331 OK** (22:37:11,09) ; `t4-production` **21 OK** (5 300 ticks, 22:38:32,19, commit exact `2b18742`) ; `t2-machines` 80 ; `bord-a-bord` 12 ; `t2-migration` 64 + 26 ; `ht3-migration` 30 + 7 ; `t2-defense` 36 + 19 et 36 + 11. Hors jeu (22 h 33 à 22 h 36) : migration 81, levels **1 615** + 23 écarts connus, api_lint **558**, le reste vert. Mutants : 6 sur 7 tués. Tableaux corrigés (NON reportés dans BALANCE_SHEET : le jeu livré n'a pas cet équilibre) : `<racine>\fo-logs\2026-10-22_V3T4\tables_BALANCE_SHEET_12_corrige.md`. RD_LOG E60 à E62, F111 à F118, H-T4-1 ; notes `NOTES_V3T4.md` (§9 : correcteur, fait foi) | 22/10, 23 h |
| A0 Ménage et garde-fous (plan de la suite, étapes 1 et 2) | 🟨 **fait en partie** (orchestrateur). Fait : fusion de `v3e-final` dans `main` (`93e3d89`, outils de rendu de la mitrailleuse validée) ; `REFUSES.txt` dans `fo-logs\2026-10-23_V3E-p5\final\sprites\` (âges 13 à 15 de ce dossier = ancienne ère V refusée) ; blocs d'identifiants réservés (RD_LOG, en-tête) ; vos phrases de 14 h 50 et 15 h 05 inscrites (§5, RD_LOG) ; Q-P1 (A) appliquée vers 16 h 25. **Non fait** : tri des worktrees périmés ; seuil de 1 Go libre sur H: avant chaque paquet de rendu (absent de `with_render_lock.py`). Le magasin des feuilles hors du mod (D-6 B) est remplacé par la décision D-6 de l'orchestrateur (feuilles dans le mod, hors de git, manifeste commité ; RD_LOG, 23/10, 19 h 05), appliquée par A2 | Déplacement Q-P1 : 1 776,5 Mo vers `C:\Users\evan2\fo-archives\fo-logs\` (un `DEPLACE_VERS_C.txt` par dossier) ; H: affiche ensuite 16,3 Go libres, bien plus que le déplacement (cause extérieure au projet ; 17 Go libres relevés à 18 h 14). Worktrees relevés à 18 h 14 : 59 dossiers dans `.claude\worktrees`, 60 lignes de `git worktree list`. RD_LOG, décisions du 23/10 | 23/10, 18 h 30 |
| A1 Rose des 8 directions de la mitrailleuse, E66, E67, E70 (plan, étape 2) | ✅ **fusionné dans `main` le 23/10 à 17 h 44** (fusion `5a95650` de la branche `worktree-wf_2bade7c0-0e8-1` : constructeur `44e0a4b`, correcteur `741917a` ; run `wf_2bade7c0-0e8`) ; outils seulement (`tools/render/pieces/levels/gun_e/`, `tools/autotest/a1/`, scénario greffé `a1-tourelle`), aucun fichier du mod en jeu, version inchangée. **Dégel D-9** de `piece.py` (directions `d00` à `d63`) prouvé : 36 fichiers sur 36 identiques octet à octet aux sprites validés. **Rose** : 112 têtes en aperçu (âges 2 à 15 × 8 directions), planches hors moteur, page https://claude.ai/artifact/3wt4uyQfxBLigQEXfZ14Vv , **pas encore jugée par vous** ; relevés : pose N toujours lue comme une cheminée à 8 âges (F119), pose S où l'arme se perd presque au zoom 1 aux âges 10 et 12 à 15, **19 trous enfermés sur 112** (gros en SE, S, SO aux âges 4 à 7) qui bloqueraient une production à 64 directions avec la règle actuelle (à trancher avant A3). **E66** : ombre à 32 échantillons = du grain sans biais ; gain de temps de la tête entière **44,7 %**, mesuré dos à dos (le 51 % de la première mesure était faux). **E67** : la levée dure 1 / vitesse (la garde du kit a tort, F120 ; correction : lot INT-GARDE). **E70** : origine au nord, sens horaire ; `orientation` s'écrit et tient (moyen retenu pour A2) ; le moteur choisit l'image par `apply_projection` (F121, conséquence pour le pipeline déduite). Vérification adverse : 1 défaut majeur (le 51 %, corrigé par une nouvelle mesure) et 8 mineurs (couverture du socle corrigée ; libellés de F120 à F122 corrigés à la consignation ; colonnes diagonales de la rose d08… au lieu de d06, d26, d38, d58 vues en jeu ; `variants.get()` et `--kit --dirs` ; deux scripts de preuve hors dépôt ; un heredoc avec antislashs : non corrigés). **Non prouvé** : la rose en moteur ; l'ombre en moteur ; le réglage d'échantillons par passe dans le kit (D-7) ; une cible ennemie imposée ; `folding` et les autres animations ; la limite du secteur « cheminée » (d01 à d07 non rendues) | Identité : `fo-logs\2026-10-23_suite\A1\identite\identite.txt` (« TOUT IDENTIQUE OCTET A OCTET », code 0), rejouée par le vérificateur. Moteur réel, copie jetable : `a1-tourelle` **5 OK, 0 échec** (`done.txt` 15:56:07,00 ; vérificateur 16:48:01,51) ; captures 20 sur 20 ; sur le mod livré, le scénario se refuse proprement. Sur le worktree : `content` 317 OK (16:48:32,04), api_lint 614 usages, 0 erreur. E66 dos à dos : 90 rendus, une session Blender, deux places du verrou tenues, 3 répétitions (`A1\e66\temps_dos_a_dos\`). RD_LOG E66, E67, E70, F120 à F122 ; notes `A1\NOTES.md`, `INTEGRATION.md`, `verification.md` | 23/10, 18 h 30 |
| A2 La mitrailleuse en jeu à 4 directions (plan, étape 3) | ✅ 👁 **fusionné dans `main` le 23/10 vers 20 h 50, version 0.4.6** (run `wf_0143e61e-944` ; constructeur `ba9edef`, vérification adverse, correcteur `4837368` ; fusion `e0088bd`, changelog `ef64f79`). La mitrailleuse des 15 âges est EN JEU avec les designs que vous avez validés : 30 niveaux, socle, pièce des niveaux pairs, tête à 4 directions (N, E, S, O), tête toujours levée, lueurs et halos de nuit, ombres, icône par âge, éclat de tir au bout des canons (règle du moteur mesurée, E68), reste et explosion à la taille de l'emprise. Vérification : 4 défauts majeurs, tous corrigés et prouvés. **Limites dites** : 4 directions seulement (64 au lot A3, Q-P2 : A) ; pose N encore lue « cheminée » à plusieurs âges ; pose S : canons vus de face ; nuits très sombres ; l'ombre de la tête ne tombe que sur le sol (F124). **Non prouvé** : restes et explosions vus en destruction ; icônes d'âge dans l'interface ; éclat au pixel (± 0,2 tuile à l'œil) ; bouchon arrière posé par secteur (saut à juger en A3). Rien à valider de votre côté (page : https://claude.ai/artifact/DcVt6j6PVctVQteegWJamt) | Moteur réel sur `main` 0.4.6 (23/10, `done.txt` de 20:53:22,75 à 20:54:56,46 ; archives `<racine>\fo-logs\2026-10-23_integration-0.4.6\`) : `content` 317 ; `monde` 89 ; `m0-reprise` 15 ; `m0-migration` 9 ; `t2-machines` 80 ; `t3-libere` 41 ; `bord-a-bord` 12 ; `ht3-migration` 30 + journal 7 ; `t2-migration` 64 + 26 ; `t2-defense` 36 + 19 (0.4.1) et 36 + 11 (0.4.2) ; `t3-migration` 7 ; **`gun-rose` 11** (20:54:32,19) ; sur la graine 123456789 : `content` 317 et `monde` 89 ; `fo-captures.bat gun-rose` : code 0, 90 captures (`captures-gun-rose\`). Hors jeu (fin à 21:02) : run 114, war 92, td 270, pteam 15, migration 82, monde 157, **levels 1 662** + 11 écarts connus, epochs 16 665, org 362, pvp 596 (369 s) ; harness code 0 (Règles 0, Images 0, étalonnage vanilla 0 sur 2 505 prototypes, auto-contrôles 11/11 et 17/17, **Feuilles mitrailleuse 318, 0 manquant, 0 écart**, 0 clé) ; **api_lint 676** ; d4m 5/5 ; **mut_atlas 50** ; test_ht3_journal 15 ; bat_double_source 25 ; mut_vram 18/18 ; **check_gun_sheets `--sources --mutants` 12 OK** ; RD_LOG E68, F123 à F129 ; `<racine>\fo-logs\2026-10-24_A2\` | 23/10, 21 h 15 |
| S0 La chaîne des sons (plan, étape 5) | ✅ 👁 **fusionné dans `main` le 23/10 vers 22 h 55, version 0.4.7** (run `wf_e1ae9f59-b47` ; constructeur `cdf8d32`, vérification adverse, correcteur `e3a50dc` ; fusion `4593893`, changelog `e4d9e03`). La mitrailleuse a un tir propre à chaque ère (5 ères, 4 variations chacune), dérivé des tirs du jeu de base, plus grave d'ère en ère, jamais plus fort qu'eux (mesuré). Le banc de l'étape data refuse un son manquant (un son manquant bloque le jeu au menu, F151). **Défaut du lot, dit franchement** : des sessions de test réglées à volume 0 ont quand même émis du son sur votre PC (environ −35 dB), entre 21 h 30 et 22 h 15 ; corrigé (pilote audio « disk » et garde qui coupe la session au moindre son ; silence mesuré) ; la consigne de l'orchestrateur ne demandait pas de MESURER le silence : c'est ma faute. **Non prouvé** : le tir joué en jeu (entendu dans une session de test) ; votre écoute (Q-S0-1) | Moteur réel sur `main` 0.4.7 (23/10, `done.txt` de 22:57:15,32 à 22:59:00,81 ; archives `<racine>\fo-logs\2026-10-23_integration-0.4.7\`) : `content` 317 ; `monde` 89 ; `m0-reprise` 15 ; `m0-migration` 9 ; `t2-machines` 80 ; `t3-libere` 41 ; `bord-a-bord` 12 ; `ht3-migration` 30 + journal 7 ; `t2-migration` 64 + 26 ; `t2-defense` 36 + 19 (0.4.1) et 36 + 11 (0.4.2) ; `t3-migration` 7 ; `gun-rose` 11, et 11 avec `FO_AUDIO=1` ; sur la graine 123456789 : `content` 317 et `monde` 89 ; **`fo-captures.bat gun-rose` avec `FO_AUDIO=1`** : code 0, 90 captures, « Driver:disk » et « Loading sounds... » au journal, garde : 0 session audio Windows du jeu en 2 416 relevés, crête 0 (`captures-gun-rose-audio\session.txt`). Hors jeu : run 114, war 92, td 270, pteam 15, migration 82, monde 157, levels 1 662 + 11 écarts connus, epochs 16 665, org 362, pvp 596 (387 s) ; harness code 0 (**Sons 0 violation**, auto-contrôle 13/13 ; images 17/17, feuilles 318) ; api_lint 676 ; d4m 5/5 ; mut_atlas 50 ; test_ht3_journal 15 ; **bat_double_source 40** ; mut_vram 18/18 ; **test_audio_session 21** ; **`sons.py --check` 20** ; check_gun_sheets 12 ; `test_audio_guard` (4 OK au lot) NON rejoué par l'orchestrateur : il joue 3 s d'un son de 30 Hz à −70 dBFS sur la vraie sortie du PC ; page https://claude.ai/artifact/Ap4JoXCgvxJJR29b5QceU3 ; RD_LOG E69, F150 à F154 ; `<racine>\fo-logs\2026-10-24_S0\` | 23/10, 23 h 10 |
| S0-suite Suites des sons | ✅ **fusionné dans `main` le 24/10 vers 2 h 30, version 0.4.8** (run `wf_93b960d8-a9c` ; fusion `4ffd852` ; accepté par le vérificateur, 3 mineurs). Le tir de chaque ère est prouvé JOUÉ en jeu, avec le bon son (36 tirs sur 36, sans aucun son vers votre PC) ; le contrôle des fichiers son relit tout le fichier (un fichier coupé ou au mauvais format ne passe plus) ; volume des ères I à IV baissé de 0,2 à 0,4 dB pour que les rafales restent nettement sous le jeu de base. **Défaut dit** : le banc des tirs entendus a échoué 1 fois sur 5 (un tir non reconnu) | Sur `main` après la fusion (24/10, `done.txt` de 2:28:28,32 à 2:30:22,15 ; archives `<racine>\fo-logs\2026-10-24_integration-S0-suite\`) : les 17 bancs en moteur réel verts (`content` 317, `monde` 89, `m0-reprise` 15, `m0-migration` 9, `t2-machines` 80, `t3-libere` 41, `bord-a-bord` 12, `ht3-migration` 30, `t2-migration` 64, `t2-defense` 36 et 36, `t3-migration` 7, `gun-rose` 11 et 11 avec `FO_AUDIO=1`, **`s0-tir` 5**, `content` 317 et `monde` 89 sur la graine 123456789) ; session avec son `fo-captures s0-tir` (`FO_AUDIO=1`), deux passages, garde : 0 session audio Windows du jeu : `tirs_joues.py` **35/36 au 1er passage** (un tir de l'ère II non reconnu au site 6, corrélations du site 0,54 à 0,57 contre 0,65 à 0,98 ailleurs ; BILAN ECHEC) puis **36/36 au 2e** (site 6 : 0,67 à 0,98) : banc un peu instable, 1 échec sur 5 passages en tout (lot, vérificateur, intégration) ; hors jeu : run 114, war 92, td 270, pteam 15, migration 82, monde 157, levels 1 662 + 11, epochs 16 665, org 362, pvp 596 (381 s), harness code 0 (Sons auto-contrôle 24/24), api_lint 682, d4m 5/5, mut_atlas 50, ht3_journal 15, bat_double_source 40, mut_vram 18/18, test_audio_session 21, `sons.py --check` 20, check_gun_sheets 12, **mut_sons 6** ; RD_LOG E113, F155, F156 | 24/10, 2 h 45 |
| A3 Têtes de la mitrailleuse à 64 directions (plan, étape 4 ; Q-P2 : A) | ⏳ **préparation fusionnée le 24/10 vers 0 h (`a7f1166`), production de nuit lancée à 0 h 00** (run `wf_e1ae9f59-b47` ; constructeur `16121ec`, vérification adverse, correcteur `9c16e3d`). 840 têtes (14 âges × 60 directions ; vos poses N, E, S, O ne sont pas refaites) ; ombre rendue plus vite (D-7, 42,8 % de temps gagné, reste de l'image identique au pixel) ; bouchon des âges 4 à 7 posé par secteur avec une rampe, pour qu'il n'apparaisse pas d'un coup en tournant (saut ramené de 482 à 1 222 px à 123 à 241 px) ; 72 petits trous acceptés (surtout les ailettes de l'âge 11) ; essai en vraie qualité de l'âge 5 regardé : rotation continue. **Pas encore en jeu** : lot A3-jeu après la production (feuilles à 64 directions, gun.lua, bancs, mémoire vidéo, captures). **Non prouvé** : votre verdict sur la rotation, la rampe et les trous ; mémoire vidéo réelle (estimée 1,44 à 1,64 Go en haute) | Après fusion, sur `main` : `test_garde_disque` 11 OK, `test_produire_a3` 43 OK, `test_famille` 12 OK, `check_gun_sheets --sources --mutants` 12 OK, `produire_a3.py --dry-run` « 72 faites, 768 à faire » ; RD_LOG E105 à E108, F140 à F145 ; `<racine>\fo-logs\2026-10-24_A3\` (`NOTES.md`, `INTEGRATION.md`, `verification.md`, `pilote\`) | 24/10, 0 h 10 |
| A3-jeu Têtes à 64 directions dans le jeu | 🟨 👁 **âges 2 à 8 en jeu depuis la version 0.4.9** (24/10 vers 3 h 55 ; fusion `3fe1da6` ; repris après une panne des serveurs, vérifié, 1 défaut majeur corrigé) ; les âges 9 à 15 restent à 4 directions jusqu'à la fin de la production des têtes, puis passent à 64 par une seule commande (`FINALISATION.md`). Dans le jeu, chaque image montrée est la bonne (252 contrôles, 0 faux). Éclat de tir de l'âge 2 : 11 directions réglées à part, tirées et regardées par un agent (D-12). **Non prouvé** : votre verdict ; âges 9 à 15 en jeu ; mémoire vidéo réelle aux 15 âges (estimée 1,30 à 1,47 Go en haute) ; images de la mitrailleuse : environ 160 Mo aux 15 âges (le double de l'estimation d'A3) | Sur `main` après la fusion (`3fe1da6`) et la régénération des feuilles (`feuilles.py --ages-64 2,3,4,5,6,7,8` : 318 PNG, 52,06 Mo, 505 sources, 7 âges à 64 directions, 7 à 4 ; `git status` propre ; `check_gun_sheets --sources --mutants` 17 OK) : moteur réel, 24/10, `done.txt` de 3:53:12,64 à 3:55:17,74 (archives `<racine>\fo-logs\2026-10-24_integration-A3-jeu\`) : les 17 bancs verts, dont **`gun-rose` 13 OK** (et 13 avec `FO_AUDIO=1`), `content` 317, `t2-defense` 36 et 36, `s0-tir` 5 ; `fo-captures gun-rose` : code 0, **150 captures**, `gun_rose_images.py` « 252 OK, 0 FAUX, 28 ambigu(s) » (les ambiguës : directions à 45° pile des âges encore à 4) ; rose de l'âge 8 à zoom 2 regardée par l'orchestrateur ; hors jeu : run 114, war 92, td 270, pteam 15, migration 82, monde 157, levels 1 662 + 11, epochs 16 665, org 362, pvp 596 (366 s), harness code 0 (ligne « Tetes mitrailleuse (A3-jeu) : 7 age(s) a 64 directions, 7 a 4 », auto-contrôle 4/4), api_lint 683, d4m 5/5, mut_atlas 50, ht3_journal 15, bat_double_source 40, mut_vram 18/18, test_audio_session 21, `sons.py --check` 20, mut_sons 6 ; RD_LOG E109 à E111, F146 à F148 ; `<racine>\fo-logs\2026-10-24_A3-jeu\` | 24/10, 4 h 15 |
| A4 La mitrailleuse vivante (plan, étape 5) | 🟨 👁 **préparation fusionnée le 24/10 vers 7 h 30, version 0.4.10** (run `wf_0e7edcdd-4f2` ; vérifiée, 2 majeurs corrigés). À chaque coup, un éclat aux couleurs de l'âge jaillit au bout des canons, dans toutes les directions de la tête (118 contrôles justes sur 118) ; restes et explosion à la taille de la mitrailleuse, vus en destruction réelle (ce sont ceux du jeu de base agrandis : défaut dit) ; socle lumineux animé en ESSAI sur l'âge 6 seulement (effet discret) ; couleur d'équipe essayée, non branchée. **Questions** : Q-A4-1 à Q-A4-3 (§4). **Non prouvé** : votre verdict ; éclat des âges 11 à 15 à 64 directions en jeu | Sur `main` après la fusion (`ab4f1b6`) et la régénération des feuilles (`--ages-64 2,3,4,5,6,7,8` : 336 PNG, 54,75 Mo, 506 sources ; `git status` propre ; `check_gun_sheets --sources --mutants` 19 OK) : moteur réel, 24/10, `done.txt` de 7:24:15,12 à 7:26:24,05 (archives `<racine>\fo-logs\2026-10-24_integration-A4\`, sans copie du mod) : les 21 bancs verts, dont `content` 317, `gun-rose` 13 (et 13 avec `FO_AUDIO=1`), `s0-tir` 5, `d4-geant` 18, **`a4-eclat` 3, `a4-ruines` 5, `a4-socle` 2**, migrations et défenses avec leurs journaux (7, 26, 19, 11) ; hors jeu : run 114, war 92, td 270, pteam 15, migration 82, monde 157, levels 1 662 + 11, epochs 16 665, org 362, pvp 596 (375 s), harness code 0 (Feuilles 336), api_lint 707, d4m 5/5, mut_atlas 50, ht3_journal 15, bat_double_source 47, mut_vram 18/18, test_audio_session 21, `sons.py --check` 20, check_gun_sheets 19, mut_sons 6 ; RD_LOG E112, E114 à E116, F149, F157 à F160 ; `<racine>\fo-logs\2026-10-24_A4\` | 24/10, 7 h 35 |
| K0 Kit commun des familles (plan, en parallèle des étapes 3 à 5) | ✅ **intégré dans `main` le 23/10 vers 18 h 40 par le lot INT-K0** (fusion `e4e8416` ; run `wf_2f1793c9-578` ; branche `worktree-wf_2bade7c0-0e8-2`, constructeur `0cee947`, tête `87c4fb1`). Outils seulement (`tools/render/pieces/levels/commun/`, profils de famille, registre des âges `ages.py`, contrôle d'empreinte FORTE ; ARCHITECTURE §7 ter). Familles de couleur des foyers des âges 5 et 6 tranchées sans changer de rendu ; ère V inscrite (13 violet d'annihilation, 14 blanc stellaire, 15 incandescence blanc-or). **Aucun design validé n'a changé** (E71). Vérification adverse : 5 défauts majeurs : 4 du lot (choix de famille qui lisait la mitrailleuse en silence, ordre des graines de l'âge 6, contrôle aveugle aux halos et aux positions, mauvaise couleur secondaire de `palette()`), tous corrigés ; 1 ANTÉRIEUR au lot : **les graines de bruit sont inertes dans Blender 5.2.2** (F136), non corrigé : l'activer changerait tous vos designs validés, décision à vous soumettre ; 5 mineurs dits (nommage du test final corrigé à moitié, ordre des clés, scripts d'A1 cassés par le déplacement, `stone-wall` non mesuré, âges 4 et 5 séparés par la seule saturation : question proposée, pas encore posée). **Non prouvé** : un profil d'une autre famille que la mitrailleuse (le premier lot F éprouvera le contrat) | Empreinte forte `93e3d89` contre la branche corrigée : « 72 variantes comparées, 0 différente(s), 0 absente(s) (forte) », graines comprises ; habillages d'essai 165 sur 165 ; mutants vus (halos × 1,5 ; ordre de l'âge 6) ; test `commun/tests/test_famille.py` 12 OK (3 OK et 9 échecs sur le code non corrigé) ; constructions SANS rendu, par le verrou de rendu ; aucun `factorio.exe`. RD_LOG E71, E72, F136 ; notes `fo-logs\2026-10-23_suite\K0\NOTES.md` (section « Correction »), `INTEGRATION.md`, `verification.md`, `correction\` | 23/10, 18 h 30 |
| M0 Socle du monde : monnaies des âges 5, 7 et 8 garanties (plan, en parallèle des étapes 3 à 5) | ✅ **fusionné dans `main` le 23/10 à 17 h 44** (fusion `da2e16f` de la branche `worktree-wf_2bade7c0-0e8-3` : constructeur `28fe15b`, correcteur `d6766d7`), **version 0.4.5**. Tungstène (âge 5), cristal (âge 7) et méthane (âge 8) garantis sur toute carte, à 200-700 tuiles du départ, sur la terre ferme, marqués sur la carte : partie neuve à `on_init` (site toujours posé : Q-M0-1), sauvegarde existante à `on_configuration_changed` et par un filet toutes les 10 s (ce qui manque seulement) ; un échec n'est plus définitif : les joueurs sont prévenus et la garantie est reprise (10 s, 20 s, 40 s… au plus 10 min), avec d'autres emplacements puis des critères plus larges (bord de lac comblé, distance allongée). Les 3 ressources existantes sont générées depuis les données (sortie identique). Le risque était réel : 3 graines sur 5 n'avaient pas l'une des monnaies à la distance prévue (E73). Vérification adverse : 2 majeurs (M-1 : échec définitif et muet, **corrigé** ; M-2 : générateur depuis `X.resources` et `X.tiles` non fait, **requalifié et REPORTÉ aux lots X** par l'orchestrateur : 34 prototypes sur 35 n'existent pas encore) et 9 mineurs (accès à pied : 7 sites sur 15 non reliés au départ sur des cartes à eau maximale ; coût du pire cas jusqu'à 767 ms ; message perdu à `on_init` ; décor ; factions ; sauvegarde de migration quasi vide ; garantie non générique ; anomalie des graines 1 et 42), non traités. Questions Q-M0-1 et Q-M0-2 (§4). **Non prouvé** : un échec naturel suivi d'une reprise ; le niveau 3 de reprise en moteur réel ; la voie `on_init` sur une autre graine que 20261020 (graine paramétrable : lot INT-GRAINE) ; l'accès à pied ; vos sauvegardes ; le visuel (votre verdict) ; les bancs de durée `ia0-*` (leurs cartes changent : 3 sites de plus, non rejoués) | **Moteur réel sur `main`** (23/10, `done.txt` de 17:45:17,75 à 17:46:17,15 ; archives `<racine>\fo-logs\2026-10-23_integration-0.4.5\`) : `content` **317 OK** ; **`monde` 89 OK** ; **`m0-reprise` 15 OK** ; **`m0-migration` 9 OK** (double source `src-0.4.4` = `git archive 93e3d89`, à GARDER) ; `t2-machines` 80 ; `t3-libere` 41 ; `bord-a-bord` 12 ; `ht3-migration` 30 + journal 7 ; `t2-migration` 64 + 26 ; `t2-defense` 36 + 19 (0.4.1) et 36 + 11 (0.4.2) ; `t3-migration` 7. Hors jeu sur `main` (vers 17 h 50, après les fusions d'A1 et M0) : run 114, war 92, td 270, pteam 15, migration 82, **monde_test 157**, levels 1 642 + 11 écarts connus, epochs 16 665, org 362, pvp 596 ; harness 0 erreur ; api_lint **669** usages, 0 erreur ; d4m 5/5 ; mut_atlas 40 ; test_ht3_journal 15 ; bat_double_source 4 ; mut_vram 18/18. RD_LOG E73 à E76, F130 à F135 ; notes `fo-logs\2026-10-23_suite\M0\NOTES.md` (§6 : correcteur), `INTEGRATION.md`, `verification.md`, `correction\` | 23/10, 18 h 30 |
| INT-K0, INT-GARDE, INT-GRAINE (intégrations de la suite) | ✅ **fusionnés dans `main` le 23/10 vers 18 h 40** (run `wf_2f1793c9-578` ; fusions `e4e8416`, `b80f2bb`, `0db5493` ; chacun accepté par son vérificateur adverse, défauts mineurs seulement). INT-K0 : le kit commun (K0) est sur `main`, aucun design validé changé (empreinte forte 0 différence sur 72 variantes ; têtes d00 et d16 identiques octet à octet) ; scripts d'A1 réparés. INT-GARDE : garde des durées d'animation des tourelles corrigée selon E67 (une tête à 1 image à la vitesse vanilla est acceptée ; une vitesse changée est refusée). INT-GRAINE : graine des bancs paramétrable (`FO_MAP_SEED`, défaut 20261020), `.bat` recopiés à la racine. Version du mod inchangée (0.4.5). **Non prouvé** : les animations autres que la levée (doc seulement) ; les bornes 0 et 4294967295 de la graine dans le vrai moteur | Moteur réel sur `main` après les fusions (23/10, `done.txt` de 18:42:28,16 à 18:43:51,14 ; archives `<racine>\fo-logs\2026-10-23_integration-0.4.5-b\`) : `content` 317 ; `monde` 89 ; `m0-reprise` 15 ; `m0-migration` 9 ; `t2-machines` 80 ; `t3-libere` 41 ; `bord-a-bord` 12 ; `ht3-migration` 30 + journal 7 ; `t2-migration` 64 + 26 ; `t2-defense` 36 + 19 (0.4.1) et 36 + 11 (0.4.2) ; `t3-migration` 7 ; **sur une autre graine (`FO_MAP_SEED` = 123456789, `seed.txt` relu)** : `content` 317 et `monde` 89. Hors jeu (vers 18 h 50) : run 114, war 92, td 270, pteam 15, migration 82, monde 157, **levels 1 661** + 11 écarts connus, epochs 16 665, org 362, pvp 596 ; harness 0 erreur ; api_lint 669 ; d4m 5/5 ; mut_atlas 40 ; test_ht3_journal 15 ; **bat_double_source 25** ; mut_vram 18/18 ; RD_LOG F137 à F139 | 23/10, 19 h |
| V2 Cadre des 15 époques | ✅ intégré (contre-vérification : 1 majeur et 5 mineurs → lot V2b) | Hors jeu : levels 1 228, migration 27 ; étape data 748 prototypes, 0 erreur ; **moteur réel `content` 209 OK, 0 échec** (20 h 39) ; journaux <racine>\fo-logs\2026-10-21_integration_* | 21/10, 20 h 40 |
| X0 Scénario, crafts, branches | ✅ hors jeu ; **scénario approuvé par vous** (Q19 : « le scénario est bien […] je l'aime bien ») ; QX1 à QX9 répondues | « La Caustique d'Érèbe » : `docs/SCENARIO_EPOQUES.md`, données pures `shared/content/epochs.lua`, banc `tests/epochs_test.lua` (16 665 OK, 0 échec ; 3 défauts injectés tous détectés) ; 3 concepteurs, 2 juges, 3 critiques (45 problèmes, dont 19 majeurs ou bloquants, corrigés) ; rien en jeu | 21/10, 21 h 15 |
| IA0 PvP et difficulté | 🟨 intégré, C4-4 prouvé en moteur réel ; A1 non mesuré ; base défendue jamais attaquée → lot IA0b | pvp_test 274, war 92 ; ia0-normal 14 OK, ia0-paisible 11 OK, ia0-difficile 7 OK (20 h 40 à 20 h 45) | 21/10, 20 h 45 |
| IA0b Base défendue attaquée selon la difficulté | ✅ intégré et prouvé en moteur réel | Hors jeu : pvp_test 596 OK. **Moteur réel** (22/10, 0 h 53 à 0 h 55) : ia0-defendue 11 OK (base de 3 tourelles attaquée au tick 96 601) ; ia0-defendue-forte 13 OK (12 tourelles, défense 96 : Écarlate revient à 16, 29, 40 puis 46 soldats) ; ia0-defendue-impitoyable 14 OK (assaut coordonné : Écarlate ouvre au tick 50 700, Ambre et Émeraude le rejoignent) ; journaux fo-logs\2026-10-22_integration_IA0b-V2b_* | 22/10, 0 h 55 |
| V2b Garde de dress complète (config entière et data.raw) + mineurs | ✅ intégré | levels_test 1 325 OK (81 cas de garde, motifs vérifiés ; 4 mutants détectés) ; **moteur réel `content` 209 OK** avec la garde (le vrai chargeur accepte les fichiers de famille chargés sous garde) | 22/10, 0 h 52 |
| V2c Amélioration instantanée (Q19), condition du centre (Q16), recalibrage par les coûts (QX7, QX9, QX10) | ✅ intégré et prouvé en moteur réel ; 2 écarts connus soumis à vous (Q-V2c-1 : part du centre aux époques 5 à 14 ; Q-V2c-2 : centre 15 atteignable en 3 h 27 par le chemin le plus court) | Hors jeu : levels 1 459 OK + 11 écarts connus, migration 29. **Moteur réel** : `content` **212 OK, 0 échec** (22/10, 2 h 43 ; fluid-handling 50 → 2, oil-processing 100 → 4, 170 technologies allégées) | 22/10, 2 h 45 |
| F3 La machine d'assemblage aux 15 âges (F3-A à F3-A3, F3-B) | 🟨 👁 **fusionnée le 27/10 vers 2 h 30, version 0.4.31** (designs validés par vous, R-QCM-25l « Validé, production ») ; votre verdict EN JEU attendu | Production : 29 variantes à 128 échantillons (E204) ; feuilles hors de git (D-6, 234 PNG, 6,09 Mo, `assembleur_e/feuilles.py`) ; `prototypes/levels/assembler.lua` : machine de l'âge aux niveaux 3 à 30 (teinte et pièce au niveau pair), niveau 2 = vanilla + établi aux coins avant, lueur rejouée en marche et lumière de l'âge, brides dessinées aux raccords de jeu, icône, reste, explosion, couleur de carte. Moteur réel (branche, par la file) : `f3-assembleurs` 6 OK, migration d'une partie 0.4.29 6 OK, content 331, t2-machines 80, mod1-modules 85, mod2-lots 28, gun-rose 13, f2-fours 3 ; 41 captures REGARDÉES (`fo-logs\2026-10-25_F3\captures\finales\`) ; plancher avec le four : atlas virtuel toujours à 12 pages, mémoire dédiée 0,44 Go (F306). Hors jeu sur `main` : harness 0, levels_test 1 666, api_lint 1 107. **Défauts dits** : 3 poches de sol nouvelles (âges 10, 11, 15 : conduite déplacée au raccord de jeu) que vous n'avez pas vues sur les planches validées ; âge 2 et nuits des âges 2 et 3 retouchés APRÈS votre verdict ; nuit faible aux âges 1, 10, 13 ; la machine ne bouge pas (seule la lueur scintille) | 27/10 |
| F2 Le four aux 15 âges (F2-A, F2-A2, F2-B) | 🟨 👁 **fusionné le 25/10 au soir (`88f3ca4`), version 0.4.30** (designs validés par vous, R-QCM-25h « Validé, production ») ; votre verdict EN JEU attendu (vous avez joué 0.4.30 le 26/10, sans remarque sur le four) | Production : 29 variantes à 128 échantillons, 7 094 s (E184) ; feuilles hors de git (D-6, 208 PNG, 4,32 Mo, `four_e/feuilles.py`) ; `prototypes/levels/furnace.lua` : four de l'âge aux niveaux 3 à 30 (teinte et pièce au niveau pair), niveau 2 = vanilla + bûches, feu animé partagé teinté (F276), lueur, halo et flaque de lumière du moteur (F277), fumée à la bouche de l'âge, icône, reste, explosion, couleur de carte. Moteur réel : `f2-fours` 3 OK, 40 captures REGARDÉES (`fo-logs\2026-10-25_F2\captures\flaque\`) ; harness 0, levels_test 1 665 OK, content 331, t2-machines 80, gun-rose 13 (inchangé), migration d'une sauvegarde 0.4.28 avec ses fours 3 OK ; plancher : atlas virtuel toujours à 12 pages, mémoire dédiée inchangée (0,44 Go, F278), aucun levier nécessaire. **Défauts dits** : la fumée est placée par une position ESTIMÉE (panaches vus sur capture, aux âges 6 et 9 surtout ; départ à la bouche non mesuré) ; le niveau 2 reste le four vanilla ; aucun test à l'aveugle des triplets ; D3 du four de 33 à 83 % de la mitrailleuse | 25/10 |
| IA1-b2 Votre équipe défend d'abord, grandit, sans gardes | ✅ fusionné le 25/10 vers 17 h (`a3bf828`, **version 0.4.29**) ; ❌ 3 contrôles rouges (défauts ouverts) | morts 123 → 66 (96 → 35 avec tourelles), inactifs 45-84 % → ~8 % sur les bonnes graines ; MAIS verif-guide rouge sur 314159265 (avant-postes détruits à 56 min, sans recherche), ia1b2-guide rouge sur 577215664 (coffre tombé faute de fer), ia1-poles à 75 % ; suite : section IA3 ; RD_LOG E172, E173, F251 à F253 |
| IA3 Le cerveau des PNJ (section, décision D-18) | 🟨 conception FUSIONNÉE (`db7911c`), revue adverse et fondations IA3-0 FUSIONNÉES (`f613db1`) ; rien de branché ; IA3-a prêt, attend IA1-b2 | cerveau générique (buts sur le graphe des recettes, registre des réservations, place de marché, expéditions évaluées) ; E180 (recherche d'une faction sans joueur) et E181 (tourelle posée près des biters) prouvés en moteur réel ; RD_LOG E178 à E181, F269 à F275 |
| IA1-i Fenêtre « Équipe et factions » | ✅ fusionné le 25/10 vers 12 h 30 (`63c480c`, **version 0.4.28**) ; ✅ VALIDÉE par le DC | remplace les commandes à taper (demande du DC du 25/10, 10 h 50) ; Maj+T ou bouton de la barre ; onglets Mon équipe, Orientation, Factions, PNJ ; Territoire et Chantiers à venir ; RD_LOG E174, E175, F263 à F265 |
| MOD-V et MOD-3 Modules : barème D-17 et icônes propres | ✅ fusionné le 25/10 vers 11 h (`18bc98d`, **version 0.4.27**) ; ✅ design VALIDÉ par le DC | vitesse et productivité multipliées (+20/+10 et +10/+5 par palier), plafond × 328, malus de productivité réduit de moitié, écart d'énergie au plafond ; RD_LOG E155, E156, E170, E171, F225 à F227, F248, F249 |
| IA1-b Pôles, managers, généralistes | ✅ fusionné le 25/10 vers 8 h 25 (`f33cfbb`, **version 0.4.26**) ; ❌ objectif principal NON atteint : 30 PNJ ne livrent pas plus que 10 (0,95) | organisation en pôles, travail de fond, interface `/fo-team org`, `vue`, `orientation` ; production +53 % ; MAIS morts × 9 hors du QG (F239) ; fond inactif dans une partie par défaut ; questions au DC (frein, plafond du minage à la main, gardes) ; RD_LOG E164, E165, F239 à F241 |
| IA1-e1 Solveur de débits et diagnostic | ✅ fusionné le 25/10 vers 7 h 15 (`e64ab49`, jeu inchangé : rien n'est branché) | vraies recettes, retour sur investissement de chaque option (base de la capitalisation IA2-d) ; `ia1-diag` 27 OK, « agrandir » appliqué : +90/min mesurés = prédits ; améliorer, remplacer, construire : modèle seul ; RD_LOG E166, E167, F242 à F244 |
| IA2-c Les factions sous brouillard, modèle du joueur | ✅ fusionné le 25/10 vers 6 h 35 (`16204fa`, **version 0.4.25**) ; variété en léger recul | éclaireurs et patrouilles ; contournement des tourelles (8 attaques sur 10 par un côté sans défense) ; renoncement au rassemblement ; 1re attaque variée ; MAIS entropie des côtés 1,35 → 1,00 (au seuil) et des postures 1,53 → 1,48 (sous le seuil 1,5), attaques 182 → 140 en 2 h ; écart-type de la 1re attaque 3,1 min (D-16 en demandait 4 : impossible dans 20 à 32 min) ; RD_LOG E161, E162, F234 à F236 |
| VERIF-NUIT Vérification adverse de 0.4.16 à 0.4.23 | ✅ rapport le 25/10 vers 5 h 40 (`fo-logs/2026-10-25_VERIF-NUIT/verification.md`) ; défaut 1 CORRIGÉ et fusionné le 25/10 vers 6 h 30 (`0d14010`, **version 0.4.24** ; banc `verif-guide` durci : 1 ECHEC sur 0.4.23, 15 OK sur 0.4.24 aux deux graines) ; guide réécrit ; question au DC : plafond de recrues (46 en 1 h sur une graine, environ 2 700 fers par heure) | 13 bancs en moteur réel (4 graines), 0 erreur, 0 plantage, aucune faction anéantie en 1 h, mêmes décisions au rejeu, migrations 0.4.15 vertes, 428 clés FR et EN. **DÉFAUT MAJEUR 1** : l'équipe du joueur décimée ne se reconstruit jamais (survie d'IA2-a2 réservée aux factions ; le seul ouvrier ne fabrique jamais le pistolet de la recrue ; 1 à 3 PNJ toute l'heure avec 4 000 fers au coffre) ; contournement donné au DC : pistolets et chargeurs au coffre. **DÉFAUT MAJEUR 2** : guide de partie resté à 0.4.15 : réécrit par l'orchestrateur (ancien gardé, `GUIDE_PARTIE-0.4.15.md`). Mineurs : gel de 0,5 à 0,7 s au lancement de la guerre ; ligne « chef » de `/fo-war status` en français seulement ; coffre d'équipe détruit = équipe renvoyée (vu : 8 → 0 à 51 min) ; coutures de biomes possibles dans une ancienne partie (non prouvé) ; sauvegarde 0.4.11 non rejouée |
| F1-B Laser : rondes de design des 15 âges | ✅ fusionné le 25/10 vers 4 h 30 (`c12c9a1`, outils seulement) ; 👁 verdict du DC (`fo-logs\2026-10-25_F1B\planches_DC\`) | 15 âges rendus ; aveugle 15/15 ; pose N en échec (âges 1, 6, 12) ; richesse et masse sous la mitrailleuse ; rien en jeu ; RD_LOG E157, E158, F228 à F230 |
| IA2-b Expansion des factions par la carte | ✅ fusionné le 25/10 vers 3 h 25 (`714d29a`, **version 0.4.23**) ; seuils de forme atteints en partie | bases orientées vers le meilleur côté (0,75 → 0,91), choix par valeur (0,65 → 0,94), orphelins repris ; « plus proche d'abord » pire (0,81) ; suite IA2-c, IA2-d ; RD_LOG E153, E154, F222 à F224 |
| MOD-2 Recettes par lots au-delà de 60 fabrications/s | ✅ fusionné le 25/10 vers 2 h 50 (`e4963d7`, **version 0.4.22**) ; décision du DC à prendre : logistique au-delà d'environ 120 objets/s par machine | Q-M2 a appliquée ; 1 630 engrenages/s mesurés ; machines du titane exclues des lots en attendant ; RD_LOG E151, E152, F219 à F221 |
| X1-TITANE Le titane de l'âge 11 en jeu | ✅ fusionné le 25/10 vers 2 h 45 (`eaf7b0b`, **version 0.4.21**) ; 👁 verdict du DC (feuille de l'ilménite, nuit, machines provisoires) | première ressource « prévue » mise en jeu (S5) ; défauts connus : hydrogène sans exutoire, saumure au visuel du pétrole ; RD_LOG E145, E146, F210, F211 |
| IA2-a et IA2-a2 Chef de faction adaptatif, guerres rééquilibrées | ✅ fusionné le 25/10 vers 2 h 20 (`90f7518`, **version 0.4.20**) | demande R-20H : côtés, tailles, raids et décisions variés ; le bâtisseur attaque ; 1 faction anéantie sur 16 en 2 h (après correction) ; plantage F216 corrigé ; restent IA2-b (expansion par la carte), IA2-c (modèle du joueur), IA2-d (capitalisation) ; RD_LOG E147 à E150, F213 à F218 |
| IA2-0 Caractère des factions tiré de la carte, mesure de référence | ✅ fusionné le 24/10 vers 23 h 10 (`ffa2a57`, **version 0.4.19**) | premier pas de la demande R-20H (PNJ imprévisibles) ; effet volontairement limité au délai de grâce et à la guerre en Paisible ; outil de mesure M1 à M3 ; IA2-a (chef adaptatif) en cours ; RD_LOG E143, E144, F207 à F209 |
| MOD-1 Modules qui se multiplient | ✅ fusionné le 24/10 vers 22 h 20 (`7cffdba`, **version 0.4.18**) ; Q-M4 en attente (productivité additive) | décision D-15 appliquée ; plafond × 328,67 ; énergie à 60 % du bonus ; 5 emplacements + 1 par niveau ; recettes par lots au-delà de 60 fabrications/s : lot MOD-2 à faire ; RD_LOG E133 à E135, E138 à E140, F190 à F194, F199 à F203 |
| A4-SOCLE Socle animé de la mitrailleuse aux 11 âges lumineux | ✅ fusionné le 24/10 vers 22 h 20 (`a1fa1fc`, version 0.4.18) ; 👁 verdict du DC sur les GIF | Q-A4-2 A appliquée ; plancher : pas de page d'atlas en plus, mise au net plus lente (F205) ; RD_LOG E141, E142, F204 à F206 |
| IA1-a Échelle 30 des équipes de PNJ | ✅ fusionné le 24/10 vers 22 h (`f625f17`, **version 0.4.17**) ; choix provisoires D-16 (E1 A, E2 A, E3 A), à confirmer par le DC | réglages unifiés `fo-war-*`, recrutement par le stock, frein par le travail, 64 places au QG ; 30 PNJ ne livrent pas plus que 10 tant qu'IA1-b ne crée pas le travail (F182) ; RD_LOG E124, E125, F180 à F182 |
| B0 Biomes : biome violet et transitions en carrés | ✅ fusionné le 24/10 vers 21 h 20 (`848b64c`, **version 0.4.16**) ; verdict du DC appliqué (B1 D, B2 A, B3 B, B4 B) | cause prouvée (F195) ; plaine de cristal en sol mauve bruyère, marais sous les sols, grain fin ; garantie des monnaies intacte (monde 89, m0-reprise 15) ; RD_LOG E136, E137, F195 à F198 |
| IA1-c Gabarits de modules des équipes organisées | ✅ fusionné le 24/10 vers 19 h 15 (`e074595`, Lua pur et outils, rien d'actif en jeu) | `ia1-modules` 136 et `content` 317 sur `main` ; 2 majeurs corrigés ; règle d'amélioration `M.upgrade_plan` PROVISOIRE (sur place tant que l'emprise ne change pas, puis remplacement du module), à confirmer au lot IA1-f ; RD_LOG E126, E127, F183 à F185 |
| M1 Kit minerai, témoin tungstène | ✅ fusionné le 24/10 vers 15 h 10 (`45966bf`, **version 0.4.14**) ; 👁 à juger par le DC (teinte de nuit, palette acier dominante, Q-M1-3 à Q-M1-5) | `m1-minerai` 7, `monde` 89 sur `main` ; lueur de nuit mesurée en moteur (7 OK sur 7) ; RD_LOG E77 à E80, E131, E132, F167 à F170, F188, F189 |
| IA1-0 Risques moteur des équipes organisées | ✅ fusionné (`7c51cdd`, outils seulement) | `ia1-risques` 65 OK sur `main` ; R2 se réalise (repli mesuré), R4 NON pour le ravivage d'un poteau ; RD_LOG E121 à E123, F175 à F179 ; R8, R9 non joués |
| F1-A Laser : fiches des 15 âges et kit de famille | ✅ fusionné (`5cb936c`, outils seulement) ; prochaine étape F1-B (rondes, test à l'aveugle) | 4e jet du kit après 6 défauts majeurs ; RD_LOG E81 à E84, F163 à F165 ; aucun design déclaré réussi |
| A3-final La mitrailleuse à 64 directions aux 15 âges | ✅ fusionné le 24/10 vers 15 h (`0f8e10d`, **version 0.4.13**) ; 👁 à juger par le DC : 3 petites fentes acceptées à l'âge 11, taille des éclats des grands âges | 840 têtes, 0 erreur ; 14 âges à 64 + l'âge 1 ; aucune direction d'éclat écartée ; gun-rose images 280 OK ; atlas virtuel du plancher plein (F186) ; RD_LOG E128 à E130, F186, F187 ; non prouvé : temps de chargement (PC chargé) |
| PNJ-VÉRIF Gameplay des PNJ v0 vérifié en moteur réel, guide de partie test | ✅ fusionné le 24/10 vers 14 h 25 (`655ef62`, **version 0.4.12**) | testeur, vérificateur adverse (6 majeurs), correcteur ; `content` 317, `verif-tourelles` 7, `pnj-reduit` 12 sur `main` ; war 105, api_lint 728 ; RD_LOG E118 à E120, F171 à F174 ; non prouvé : partie jouée à la main, combat capturé, F174 |
| IA1 Conception des équipes de PNJ organisées (C5) | ✅ conception intégrée ; 👁 7 questions à vous poser | 3 concepteurs, 2 juges, 2 critiques (10 majeurs et 14 mineurs corrigés) ; org_test 362 OK ; aucun comportement en jeu | 22/10, 1 h 15 |
| D4m Banc mémoire vidéo et usine géante (D4) | ✅ banc intégré et passé en moteur réel (5 passages, code 0, BILAN 16 OK chacun) | Mémoire vidéo dédiée mesurée : 1,59 à 1,70 Go (haute), 0,67 Go (normale), 0,42 Go (plancher) ; 60 UPS avec 2 588 bâtiments à niveaux à l'écran ; images/s non mesurées ; journaux fo-logs\2026-10-22_D4m_* ; à refaire avec les sprites V3 | 22/10, 3 h |

**Suites du lot V3-T pour l'intégrateur** (proposées par le lot le 22/10 à 14 h 56 ; **faites et intégrées le 22/10
vers 17 h**, ligne « Suites de V3-T » ci-dessus) :
1. ✅ `tests/datastage/harness.lua` : règle des points de jeu (raccord hors de la boîte et sur un centre de tuile,
   dépôt de foreuse hors de la boîte et des tuiles), pour toute entité du mod (`tests/datastage/engine_rules.lua`,
   RD_LOG E47, F82).
2. ✅ `tests/mock_engine.lua` : `get_control_behavior`, `destroy_decoratives`, recherche par zone sur la boîte, boîtes
   vanilla de tous les prototypes intégrés (E47). Fait hors jeu seulement.
3. ✅ Correction de l'outil d4m : atlas attendus selon les réglages de chaque journal ; d4m 5/5 sur `main` (E48, F80).
4. ✅ H-T3 : migration d'une vraie sauvegarde 0.4.1 prouvée en moteur réel, sur une carte de banc (E46).

**Tâches ouvertes restantes** (22/10, 17 h 25 ; mises à jour le 22/10 à 19 h 20, après le lot V3-T2, à 20 h 21,
après le lot R1, puis vers 23 h, après les lots V3-T3 et V3-T4) :
- ✅ faire tourner une machine agrandie en moteur réel : fait (lot V3-T2, E49 ; les 5 familles) ;
- ✅ effet de `FO_CREATE_SRC` sur `fo-captures.bat` : essayé deux fois par le lot V3-T2 (17 h 53 et 18 h 53, E50) : la
  carte est créée par la source de création et la session avec images rejoue la migration ;
- ✅ outillage : compter l'atlas virtuel dans l'estimation de `vram.py` (F81) : **fait** (lot R1, 22/10, E55) ; plancher
  0,28 à 0,53 Go au lieu de 0,20 à 0,31 Go. Reste ouvert : où vivent les pages et quel est leur format (F102 ; pour
  trancher, une session au plancher avec `compress-virtual-atlas` ou `streamed-atlas-physical-vram-size` fixés dans
  le `config.ini` de TEST, option à câbler dans `visual_session.py`, banc en moteur réel sans mesure de performance
  pendant un rendu Blender) ;
- ✅ observer en moteur réel le contact bord à bord de `find_entities_filtered{area}` : **fait** (lot R1, 22/10, E53,
  F96 : le contact est RENDU) ; moteur simulé aligné ; `move_ground_items` corrigé. Restent : les balayages par
  secteurs jointifs de `pvp.lua`, `sites.lua` et `war.lua`, non examinés ; le filtre `position` seule, ignoré par le
  moteur simulé ;
- ✅ jouer une défense dense : **faite** (lot R1, 22/10, E54 : 21 tourelles, mur continu, bras électriques, poteaux,
  convoyeur commun ; elle marche, 13 tourelles sur 21 laissées depuis 0.4.1) ; l'aspect attend votre verdict
  (Q-T2-1) ;
- ✅ réparer le commentaire abîmé de `tools/autotest/fo-autotest/checks/levels_points.lua` (ligne 26, U+0082 et une
  tabulation dans un chemin) : **fait** dans le commit `98ac826` (22/10, 19 h 37), relu le 22/10 à 20 h 20 : aucun
  caractère de contrôle dans le fichier ;
- nouvelles (lot V3-T3, 22/10, 23 h) : vous poser la question des rangées collées (déplacer les voisins en cascade,
  agrandir une rangée entière, ou accepter la limite) avec les planches V3-E ; jouer le panneau et les boutons avec un
  vrai joueur, y compris le jeu à la main sans robots ; refaire les fils de circuit des gêneurs reposés, ou le
  décider ; jouer l'expiration et le bâtiment disparu en moteur réel ; jouer foreuses, fours, lasers et centre ;
  mesurer le coût en temps (H-L1) ; expliquer l'écart api_lint 615 (worktree) contre 609 (`main`) ; faire valider
  par vous (ou retirer) l'écart `levels_free.names` (noms de prototypes en chaînes dans `global`, ARCHITECTURE
  §7 bis), signalé par le correcteur comme « écart à faire valider » et perdu à l'intégration ;
- nouvelles (lot V3-T4, 22/10, 23 h) : votre réponse à Q-T4-1 (§4), puis reprendre la branche (`--calibrate`, fusion
  sur 0.4.4, renumérotation F111 à F118 et E60 à E62 dans le code, tous les bancs) ; questions proposées par son
  correcteur, pas encore posées : place des coûts dans le coffre, tourelles (Q14, PV par tuile, blindés), contrats
  d'avant (2 000 objets, × 16 par bâtiment), modules et balises ;
- nouvelles (lot V3-T2) : ~~vos réponses à Q-T2-1 et Q-T2-2 (§4)~~ : **reçues** le 22/10 (B à 21 h 06, A à 21 h 12) ; prouver en moteur réel la migration d'une machine EN
  fabrication (outillage à écrire : `--create` sauvegarde au tick 0) ; jouer les raccords du fluide de minage d'une
  foreuse et la boîte à fluide de sortie d'un assembleur ; jouer une disposition d'usine réelle (insertion directe
  entre machines, balises) ;
- nouvelles (lot R1) : sélection, minage et remplacement par le joueur d'une tourelle laissée qui chevauche un mur, un
  convoyeur ou un poteau ; poser un objet au sol exactement bord à bord dans un banc en moteur réel ; corriger
  `python vram.py --help`, qui plante quand la sortie est redirigée (UnicodeEncodeError cp1252, préexistant) ;
- tâches d'avant, toujours ouvertes :
- recharger en moteur réel une carte déjà migrée (sauvegardée après la migration, puis rechargée) : **toujours non
  prouvé** (le lot R1 ne l'a pas joué) ;
- jouer l'amélioration d'une mitrailleuse laissée hors grille (coince7, rempart7) : non jouée (celle d'un
  assembleur laissé hors grille est jouée depuis V3-T2, E50 ; aucune tourelle laissée de la défense dense n'a été
  améliorée, E54). Lié aux questions Q-T3 et Q-T2-1 (§4).

**Écarts trouvés pendant P0** (corrigés, et notés parce qu'ils faussaient des preuves)
- Sous Windows, le banc de l'étape data annonçait 1 736 clés de traduction manquantes : il listait les
  `.cfg` avec `ls`, que `cmd.exe` ne connaît pas. Les traductions étaient complètes ; l'outil est corrigé.
- Quand le verrou était pris, `fo-autotest.bat` sortait avec le code 0 en laissant les journaux du banc
  précédent : un agent pouvait lire un ancien `180 OK` comme un succès. Il sort désormais avec le code 2.
- La copie du mod vers le banc emportait tout le dossier : elle aurait recopié `.git` et les worktrees
  des agents. Elle les exclut désormais.

**Règle du banc pendant la phase parallèle** : le moteur réel est réservé à un seul agent à la fois. P1
(qui en refait l'outillage) en est l'utilisateur pendant son lot ; V0 et V1 travaillent hors moteur ;
l'orchestrateur passe les bancs d'intégration entre deux lots.

**Définition de « terminé » pour un lot**
1. Bancs hors jeu verts.
2. Étape data sans nouvelle erreur, api_lint à 0.
3. Banc `content` vert en moteur réel.
4. Captures revues (pour ce qui se voit).
5. Mise à jour d'OBJECTIFS.md (état, preuve, date) et de RD_LOG (faits et expériences).
6. Pour le visuel : **votre verdict**.
