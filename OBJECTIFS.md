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
> Dernière mise à jour : 2026-10-21, 17 h 45, fin de la session 5. **Passage à Claude Code**
> (multi-agent) : voir §7 et `CLAUDE.md` à la racine du mod.
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
| C4 | PvP | 🟨 | Les factions ne font que riposter (Q4 ouverte) |
| D1 | **Des designs qui changent, pas seulement la couleur** | ❌ niveaux, 🟨 ailleurs | Niveaux : teinte + 1,2 % de taille + socle + lueur. Constat du 21/10, 17 h 26 |
| D2 | Effets lumineux (« glowing ») | 🟨 | Effets la nuit seulement |
| D3 | Précision du rendu | 🟨 | Socle caché sous le four ; aucune revue en gros plan |
| E1 | Échelons façon Clash of Clans (mécanique) | ✅ | 180/180 en moteur réel. À étendre à 15 époques (F1) |
| E2 | **Qualité des niveaux : chaque niveau se voit** | ❌ | Même constat que D1 |
| E3 | Boucle « presque idle game » | 🟨 | Mécanismes idle manquants (liste en E3) |
| E4 | Interface des niveaux (panneau, touche U) | 🟨 | Jamais vue à l'écran en moteur réel |
| **F1** | **Jeu continu en 15 époques** | ❌ | Nouvel objectif (17 h 35) : le cadre est à poser (§3 F1, §6) |

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
- **Demande** : « TD + PvP ».
- **État** : 🟨 Les factions s'affrontent entre elles. Avec vous, elles restent en cessez-le-feu tant que
  vous ne les attaquez pas. **Q4 ouverte.**

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
  4. L'emprise au sol reste la même, pour ne pas changer le jeu. La hauteur visuelle peut croître.
  5. Ombres, socles et calques sont alignés au pixel en gros plan (R4).
- **Preuve** : galerie jour et nuit, la même en gris, planche de vignettes, gros plans, mesure
  automatique des silhouettes.
- **État**
  - ❌ niveaux : teinte, +1,2 %/niveau, socle (caché sous le four), lueur et halo la nuit ; seul le
    centre gagne des antennes.
  - 🟨 ailleurs : armes spéciales et tourelles lourdes composées ; déchiqueteurs en teinte et lueur.

### D2 · Effets lumineux (« glowing »)
- **Critères d'acceptation** ❔
  1. Des éléments lumineux **visibles de jour** à partir de l'époque 3 environ.
  2. Des animations (pulsation, étincelles, particules) dans les époques hautes.
  3. La nuit, un halo proportionnel au niveau.
- **État** : 🟨 Halos et lueurs prouvés la nuit (E23) ; faibles de jour ; aucune animation propre aux
  niveaux.

### D3 · Précision du rendu
- **Critères d'acceptation** ❔
  1. Aucun calque décalé, aucune ombre fausse, aucun élément caché.
  2. Une revue en gros plan aux zooms 1 et 2 pour chaque famille et chaque époque.
- **État** : 🟨 Défaut connu : socle invisible sous le four en acier (F42). Aucune revue en gros plan.

### E1 · Échelons façon Clash of Clans (mécanique)
- **Demande** : « niveau clash of clans en termes d'échelons, de qualité de levels… pratiquement idle
  game ».
- **Critères d'acceptation** (tous ✅)
  1. Un centre de commandement (l'hôtel de ville) plafonne les autres bâtiments.
  2. Les ouvriers limitent les chantiers simultanés.
  3. Coûts et durées croissent ; les ressources des biomes servent de monnaie aux hauts niveaux.
  4. Le bâtiment est hors service pendant son chantier.
  5. Contenu, recette, munitions et santé sont conservés.
  6. 7 familles × 10 niveaux.
  7. Le bonus de recherche est hérité.
- **État** : ✅ **180/180 en moteur réel** (E24, 21/10, 17 h 30). **À étendre** à 15 époques (F1), ce
  qui implique de refaire la courbe de coûts (BALANCE_SHEET §12).

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
  4. Une file de chantiers (le suivant démarre dès qu'un ouvrier se libère). ❌
  5. Plus de familles à niveaux : tapis, bras, labos, énergie, tourelles spéciales, radars. ❌
  6. Les factions IA et la défense de tours utilisent aussi les niveaux et les époques. ❌
- **État** : 🟨

### E4 · Interface des niveaux
- **Critères d'acceptation**
  1. Le panneau au survol affiche niveau, gains, coût (vert ou rouge), durée et ouvriers.
  2. La touche U et le bouton « Améliorer » fonctionnent.
  3. Une rangée de murs s'améliore en une fois.
- **État** : 🟨 Testé hors jeu (556 contrôles), chantiers prouvés en moteur réel par l'interface
  distante. **Le panneau n'a jamais été vu à l'écran.**

### F1 · Jeu continu en 15 époques (nouveau, 21/10, 17 h 35)
- **Demande** : « Pièces + 15 époques, comme je le disais, si je veux jouer en continue je veux pouvoir
  avoir des ressources exploitables, de nouveaux batiments etc, ça implique devoir ajouter une grande
  quantité de contenu mais c'est souhaité, c'est l'idée finalement. »
- **Ce que nous en comprenons** ❔ (à confirmer, Q6 et Q7)
  - **15 époques = 15 niveaux du centre de commandement.** Comme l'hôtel de ville de Clash of Clans,
    le niveau du centre définit l'époque.
  - Chaque époque ouvre, pour chaque bâtiment, **2 niveaux de plus** (proposition, Q6). Les bâtiments
    vont donc jusqu'au niveau 30, et le niveau maximal d'un bâtiment vaut 2 × le niveau du centre.
  - Visuel :
    - le **1er niveau d'une époque** fait changer la silhouette ;
    - le **2e niveau** ajoute une pièce.
  - Chaque époque apporte aussi **du contenu nouveau** :
    - au moins une **ressource exploitable** ou un matériau ;
    - de **nouveaux bâtiments** ou familles ;
    - tous les 3 époques, un **palier logistique** Compaction (B1).
  - Les ouvriers passent de 1 à 5 (un de plus toutes les 3 époques).
- **Critères d'acceptation** ❔
  1. Les 15 époques sont jouables à la suite sur une même carte, sans blocage.
  2. Chaque époque apporte au moins une ressource ou un matériau, au moins un bâtiment nouveau, et une
     silhouette nouvelle pour chaque famille à niveaux.
  3. La durée de jeu visée est longue et croissante. Proposition ❔ : époque 1 en 30 min, époque 15 au
     bout de 60 h cumulées environ. La courbe est à chiffrer dans BALANCE_SHEET.
  4. Les IA progressent aussi en époques (C2-6).
  5. Le budget A1 est tenu à l'époque 15, avec une base de fin de partie.
- **État** : ❌ Le cadre est à poser. Proposition d'époques au §6, **à valider par vous**.

---

## 4. Questions et réponses

| ID | Question | Votre réponse (21/10, 17 h 35) | Conséquence |
|---|---|---|---|
| Q1 | Ampleur du changement de forme ? | « Pièces + 15 époques… » (citation complète en F1) | D1 révisé ; F1 créé |
| Q2 | Nouvelles images (pièces 3D rendues) en plus des pièces vanilla ? | Oui | Règle 8 levée (ARCHITECTURE §2) ; protocole H-V1 |
| Q3 | Par quoi commencer ? | Refaire le visuel des 7 familles | Phase V en premier (§6) |
| Q4 | PvP : les factions vous attaquent-elles d'elles-mêmes ? | **Ouverte** | — |
| Q5 | Compaction ×4 : quand ? | « Tout de suite après le visuel » | Phase C juste après la phase V |
| Q6 | ❔ Combien de niveaux par époque ? | **Ouverte** (proposition : 2, soit 30 niveaux) | Fixe le nombre de prototypes et de visuels (2 × 15 × familles) |
| Q7 | ❔ La liste des 15 époques du §6 vous convient-elle (thèmes, ressources) ? | **Ouverte** | Fixe le contenu à produire |

## 5. Historique des écarts signalés par vous

| Date | Votre constat | Réponse | Statut |
|---|---|---|---|
| 21/10, 14 h | « c'est surtout la couleur qui change, ce n'est pas un nouveau design » | Silhouettes composées (armes spéciales), lueurs, biomes refaits | 🟨 Corrigé pour les armes, pas pour les niveaux |
| 21/10, 14 h 17 | Biomes pas assez différents, marais « ultra vert » | Textures choisies d'après leur couleur mesurée, décor dense | 👁 Votre verdict manque |
| 21/10, 17 h 26 | Niveaux : « je ne vois QUE un changement de couleur/teinte » | Constat exact (E25 rejeté). Critères D1 posés ; phase V | ❌ Ouvert |

---

## 6. Feuille de route (ordre fixé par vos réponses Q3 et Q5)

### Proposition des 15 époques ❔ (Q7, à valider ; chaque ligne devient un lot de contenu)

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
| X1 à X15 Époques | C, Q7 | un dossier par époque | Ressource, biome, bâtiments, prouvés au banc |

**Banc en moteur réel = ressource partagée.**
- `fo-autotest.bat` prend un verrou et **efface `fo-autotest\` à chaque lancement**. Les tests sont donc
  lancés un par un, et chaque agent copie ses journaux avant le test suivant.
- Autre possibilité : rendre le dossier de test paramétrable, un par lot. Les mesures de performance
  restent alors réservées à un passage seul, épinglé.

**Définition de « terminé » pour un lot**
1. Bancs hors jeu verts.
2. Étape data sans nouvelle erreur, api_lint à 0.
3. Banc `content` vert en moteur réel.
4. Captures revues (pour ce qui se voit).
5. Mise à jour d'OBJECTIFS.md (état, preuve, date) et de RD_LOG (faits et expériences).
6. Pour le visuel : **votre verdict**.
