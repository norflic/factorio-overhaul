# OBJECTIFS : cahier des charges et suivi

> **Version compressée du 7/11/2026** (source : 341d43f9, 321 Ko). Historique complet : archive figée
> `docs/archives/OBJECTIFS_ARCHIVE_2026-11-07.md` (chaque renvoi « archive »).
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
> **États du §2 et du §3** : le dernier état écrit, daté ; A1, C2, C5, D1, E2, E4 mis à jour le 7/11 vers 16 h. Documents liés : `REPRISE.md`, `CLAUDE.md`, ARCHITECTURE.md, BALANCE_SHEET.md, RD_LOG.md.

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

| ID | Objectif | État actuel (dernière mention datée) |
|---|---|---|
| A1 | Performance 60 UPS, puis ×10 réel (7/11) | ❌ sur votre partie : script 2,87 ms par tick, p99 45,2, pire 302 ms (0.6.58, B58-detail, 7/11) ; ×10 visé : au plus 1,67 ms par tick, moteur compris |
| B1 | Logistique « Compaction ×4 », usines à paliers | ❌ rien en jeu (22/10) |
| B2 | Modules à nombreux paliers | ✅ ; multipliés, icônes validées (0.4.27) ; icônes à redessiner (7/11) |
| B3 | Déchiqueteurs supérieurs, « nouveaux designs » | 🟨 teinte, échelle, lueur seulement (22/10) |
| B4 | Armes, défenses, munitions | ✅ ; tirs par âge en prototype non fusionné (27/10) |
| B5 | Autres tourelles et lanceurs | ✅ 👁 votre verdict manque |
| B6 | Ressources à effets | ✅ ; monnaies garanties (0.4.5), titane (0.4.21), 4 minerais refaits (30/10) |
| B7 | Biomes vraiment différents | ✅ 👁 ; « Les biomes sont mieux également » (30/10) |
| C1 | Guerre « 100 contre 100 contre 100 contre 100 » | 🟨 23 à 48 soldats par faction à 59 min (24/10) |
| C2 | Des PNJ qui jouent | 🟨 âge 2 atteint par 3 factions (4/11) ; pétrole et pack chimique non prouvés ; maillons D0 à D3 (7/11) |
| C3 | Défense de tours | ✅ (E19) |
| C4 | PvP | 🟨 critères ❔ à valider (22/10) |
| C5 | Équipes de PNJ organisées | 🟨 30 PNJ, pôles, fenêtre en jeu ; ❌ votre équipe bloquée à 2 PNJ dans votre partie du 7/11 (0.6.58) |
| D1 | Des designs qui changent | 🟨 4 familles sur 7 par âge en jeu ; laser, centre et mur pas en jeu (7/11) |
| D2 | Effets lumineux | 🟨 la nuit ; socle animé (0.4.18) |
| D3 | Précision du rendu | 🟨 aucune revue en gros plan (22/10) |
| D4 | Optimisation graphique | 🟨 (22/10) ; plancher tenu (27/10) ; mémoire vidéo non limitante (5/11) |
| E1 | Échelons façon Clash of Clans | 🟨 Q-V2c-1 ouverte ; centre de l'âge 5 recalé (5/11) |
| E2 | Chaque niveau se voit | ❌ 4 familles sur 7 ; tests D1 (gris, vignette, recouvrement) non prouvés sur elles |
| E3 | Boucle « presque idle game » | 🟨 ; Q-T4-1 ouverte |
| E4 | Interface des niveaux | 🟨 panneau au clic livré (0.6.52, 5/11) ; **prouvé en partie réelle avec images le 7/11** (29 OK, R2 compris, RD_LOG E260) ; reste : R3 et R4 à essayer à la main, et votre verdict sur la planche |
| F1 | Jeu continu en 15 époques | 🟨 ; titane en jeu (0.4.21), X2 non fusionné (25/10), X3 hors jeu (27/10) |
| IA | Feuille de route vidéo (7/11) | ⏳ validée par vous (15 h 20) ; à 16 h 20 : L0 mesuré ; règles pures testées, NON branchées : L1, L2, L3, L4, L5, L6, L7, L10, L12, L13 ; L11, L8, L9 en cours ; plan d'intégration écrit (`fo-logs/2026-11-07_VIDEO-AUTOMATISATION/INTEGRATION_VIDEO.md`) ; rien en jeu |

---

## 3. Détail des objectifs

Demandes, essais, preuves : archive, §3.

### A1 · Performance : 60 UPS
- Critères : script ≤ 1,5 ms/tick en moyenne ; p99 ≤ 2 ms ; moins de 0,01 % des ticks au-delà de 16,7 ms sur 30 à
  60 min ; banc épinglé sur les cœurs P, étalon `[FO-CALIB]`.
- État : ❌ sur votre sauvegarde (`autosave1-2121.zip`, 255 min, 4 factions, votre équipe à 30 PNJ) : les trois critères
  manquent. B58-detail (0.6.58, `--seul`, profileur détaillé qui ajoute son coût, 36 000 ticks, 7/11 15 h 21, relu par
  `perf3.py`) : script 2,87 ms en moyenne, p99 45,2, pire tick 302,1 ms, 3,9 % des ticks au-delà de 16 ms ;
  `sched:timers` 37 %, `team:build` 32 %. Mesure seule de 0.6.58 (7/11 13 h 06) : 3,658 ms, p99 37,9, pire 199,7.
  Étape E1 de la pensée d'équipe : 41 à 51 ms en moyenne (chiffre de perf3 transmis par le lead, non relu).
- Reste : PERF4, CERVEAU-CENTRAL, MORTS ; remesurer chaque version sur votre sauvegarde.
- **Nouvelle cible (7/11, 17 h 13)** : « Ce que j'aimerai c'est faire tourner le jeu en x10 naturellement quoi, surtout
  avec la configuration de mon PC (qui est quand même assez puissante) » ; et avant : « comment optimiser tellement qu'il
  est vraiment plus possible de trouver une autre idée ou logique ». Critère ajouté : **×10 réel sur votre sauvegarde**,
  soit 600 UPS, donc au plus 1,67 ms par tick en moyenne, moteur ET script compris. Le 5/11 (0.6.53), ×10 ne donnait que ×2,2
  à ×2,9. Inventaire en cours, script (x10-script) et moteur (x10-moteur), dans `fo-logs/2026-11-07_X10/` ; mesure A/B de la
  0.6.59 lancée (perf3), avec le temps du moteur par catégorie.
  MESURÉ (relu par perf3 le 7/11 à 17 h 25 dans `--benchmark-verbose all`, archive `fo-logs/2026-11-05_PERF4/A2-base0656-off`,
  0.6.56, votre sauvegarde, profileur éteint, `--seul`) :
  - total : 4,68 ms en moyenne, p50 2,27, p99 91,5, pire 337, soit 214 UPS ;
  - **moteur seul : 1,83 ms en moyenne** (entités 1,09 ; chemins 0,18 ; électricité 0,13 ; carte 0,12 ; particules 0,08 ;
    ramasse-miettes Lua 0,08, pire 29,6), soit 547 UPS ;
  - script : 2,85 ms en moyenne, mais p50 0,33 : le coût du script est surtout dans les PICS.
  Déduit : même avec un script à 0, le moteur seul dépasse 1,67 ms sur cette sauvegarde. ×10 demande donc AUSSI de baisser le
  coût des entités. Ce qui le baisse beaucoup risque de changer ce que vous voyez ; ce sera votre décision. Le rendu, absent de
  `--benchmark`, s'ajoute en jeu.

### B1 · Logistique « Compaction ×4 » et usines à paliers
- Critères ❔ : tapis T2 à T5 au débit de BALANCE_SHEET §3 (±2 %) ; objets denses faits et défaits en T2 et T3 ; une
  usine T5 produit 256 fois plus par tapis qu'une T1 ; énergie sans blocage ; un design par palier (D1).
- État : ❌ modèle `shared/balance_model.lua` et H-B1 seulement (22/10) ; à faire après le visuel (Q5). Décision liée :
  R-QCM-25, logistique au-delà de 120 objets/s.

### B2 · Modules à nombreux paliers
- État : ✅ jusqu'au palier 10 (E15) ; multipliés (MOD-1, 0.4.18), recettes par lots (MOD-2, 0.4.22), barème D-17 et
  icônes validées (MOD-3, 0.4.27). Reste : icônes à redessiner (7/11, design-modules).

### B3 · Déchiqueteurs supérieurs et nouveaux designs
- Critères : paliers 5 à 8, 4 familles et contres ✅ ; ❔ forme reconnaissable autant que la couleur ❌.
- État : 🟨 (E15, E19) ; teinte, échelle, carapace lumineuse la nuit (22/10).

### B4 · Armes, défenses, munitions
- État : ✅ banc en moteur réel, contres vérifiés (E15, E18). Tirs par âge : prototype non fusionné (`tirs`), D-21.

### B5 · Autres tourelles et lanceurs
- État : ✅ 👁 tourelle-canon, mortier, tour à arc, pulvérisateur d'acide, lance-grenades, fusil à rail, arc portatif ;
  votre verdict visuel manque.

### B6 · Ressources à effets
- État : ✅ tungstène, cristal, méthane (garantis sur toute carte, M0, 0.4.5), poison et soin des biomes ; titane de
  l'âge 11 (X1, 0.4.21) ; 30/10 : 4 minerais refaits, icônes à faire. Ouvertes : Q-M0-1, Q-M0-2.

### B7 · Biomes vraiment différents
- Critères ❔ : un biome se reconnaît sans légende, de jour et de nuit ; aucun n'est une simple teinte vanilla.
- État : ✅ 👁 (E23 ; B0, 0.4.16) ; 30/10 : « Les biomes sont mieux également ».

### C1 · Guerre « 100 contre 100 contre 100 contre 100 »
- Critères ❔ : 4 factions d'au moins 100 combattants en 90 min au plus ; batailles à cette taille ; budget A1.
- État : 🟨 23 à 48 soldats par faction à 59 min (PNJ-VÉRIF, 0.4.12, 24/10) ; groupes amputés à leur création (F174).

### C2 · Des PNJ qui jouent
- Critères : un cerveau par équipe ✅ ; armes fabriquées ✅ ; pose, minage, fonte ✅ ; recherche en packs ✅ ; pétrole
  et pack chimique : non prouvé ; ❔ époques franchies par les IA : en partie.
- État : 🟨. Âge 2 atteint par 3 factions à 43 min sur la graine de votre partie (corr-defaut7, 4/11 ; 123456789 en perd
  2) ; au-delà : non prouvé. Pétrole allumé par défaut (0.6.30), éteint dans vos réglages le 5/11 ; pétrole et pack
  chimique des factions : non prouvés. 7/11 : maillons cassés D0 à D3 (`docs/IA_WORKFLOW.md` §5), factions et votre équipe.
- Reste : L3 à L6 (TODO_VIDEO §G) ; question D3 au DC (sortie pleine d'un produit saturé : arrêt ou service).

### C3 · Défense de tours
- État : ✅ (E19) : vagues, boss, défaite détectée, 0,06 ms/tick.

### C4 · PvP
- Q4 : « oui (et différents niveaux de difficulté) ». Critères ❔ à valider : 5 difficultés ; ciblage du joueur après
  une grâce ; effet mesurable ; base témoin attaquée en Normal, pas en Paisible ; budget A1.
- État : 🟨 C4-1, C4-2, C4-4, C4-5 ✅ ; C4-3 🟨 (ordre strict non prouvé hors du modèle nominal) (22/10) ; QX3.

### C5 · Équipes de PNJ organisées (nouveau, 21/10, 21 h 35)
- Critères ❔ : 30 PNJ par faction, 4 factions ; cerveau et managers ; lignes automatisées ; interface ; résurrection
  chiffrée ; progression mesurée ; 4 × 30 PNJ en moteur réel, budget A1.
- État : 🟨. Tenus : 30 PNJ et 4 factions (`ia1-scale` 17 OK, 24/10), interface (IA1-i, validée). En partie : pôles
  (`ia1-poles` 15 OK, 2 ECHEC depuis 0.4.29). ❌ dans votre partie du 7/11 (0.6.58) : équipe tombée à 2 PNJ, fer à 0,
  aucune recrue depuis 123 min (recrue payée en fer, D1 de TODO_VIDEO §G) ; budget A1 non tenu. Non prouvés : lignes
  automatisées à 30 PNJ, progression.
- Reste : recrue gratuite sous l'effectif de départ (SPIRALE-FER) ; L3, L6 ; portée 16 (`portee-16` 15 OK, 7/11 15 h 39).

### D1 · Des designs qui changent, pas seulement la couleur
- Critères ❔ : test du gris ; vignette ; recouvrement < 50 % (Q13) ; emprise et détail croissants (Q23) ; regard naïf ;
  alignement au pixel (R4).
- État : 🟨. En jeu par âge : mitrailleuse (0.4.13 ; « Ok pour les mitrailleuses j'aime bien »), four (0.4.30),
  assembleur (0.4.31 ; « les assemblages sont bons finalement », 27/10), foreuse (0.6.2, provisoire). Pas en jeu : laser
  (validé le 4/11 ; production FINIE le 5/11 à 22 h 12, 925 rendus sur 925, 0 erreur ; feuilles 318 PNG ; pas encore fusionnée : mesure au plancher puis fusion, lot laser-f1c, 7/11), centre-vaisseau (âges 0, 8, 15 validés ; 14 et 15 à refaire), mur
  (arrêté le 29/10). Tests du gris, de la vignette, du recouvrement sur les nouvelles familles : non prouvés.
- Reste : votre verdict en jeu sur le four et la foreuse ; laser, centre, mur.

### D2 · Effets lumineux (« glowing »)
- Critères ❔ : lumière visible de jour dès l'époque 3 ; animations aux époques hautes ; halo de nuit selon le niveau.
- État : 🟨 la nuit seulement (E23) ; socle animé de la mitrailleuse (0.4.18, 👁).

### D4 · Optimisation graphique (Q19, 21/10)
- Critères ❔ : PC à 8 Go de mémoire vidéo, atlas ≤ 6 Go ; basse qualité rendue et lisible (Q21) ; chargement + 30 s au
  plus ; temps de rendu chiffré ; usine géante à 60 images/s dans les deux qualités.
- État : 🟨 (E40, 22/10) ; plancher tenu à 12 pages (27/10) ; laser à 14 pages sur 16 (4/11) ; 5/11 : la mémoire vidéo
  ne limite plus les designs.

### D3 · Précision du rendu
- Critères ❔ : aucun calque décalé ni ombre fausse ; revue en gros plan aux zooms 1 et 2.
- État : 🟨 socle caché sous le four (F42), ombres du centre (F48) ; aucune revue en gros plan.

### E1 · Échelons façon Clash of Clans (mécanique)
- Critères : le centre plafonne ; coûts croissants ; amélioration instantanée (Q19) ; contenu conservé ; centre de 1 à
  15, familles de 1 à 30 ; bonus de recherche hérité ; condition du centre (Q16).
- État : 🟨 `content` 317 OK (22/10) ; QX10 non tenu, centre 15 en 3 h 27 par le chemin court (Q-V2c-1) ; 5/11 :
  plastique et passage vers l'âge 5 recalés.

### E2 · Qualité des niveaux : chaque niveau se voit
- Critères : D1 à D3 pour toutes les familles et époques. État : ❌ 4 familles sur 7 par âge en jeu ; D1 à D3 non prouvés
  sur elles.

### E3 · Boucle « presque idle game »
- Critères ❔ : alimentation par tapis ✅ ; score de puissance ❌ ; objectifs par époque ❌ ; plus de familles à
  niveaux ❌ ; factions et défense de tours à niveaux ❌. État : 🟨 ; Q-T4-1 ouverte.

### E4 · Interface des niveaux
- Critères : panneau (niveau, gains, coût, condition du centre) ; touche U et bouton ; rangée de murs en une fois.
- État : 🟨. Vu par vous le 4/11, gênant au survol. Depuis 0.6.52 (5/11, `content` 554 OK) : au clic par défaut, réglage
  par joueur, Maj+U ; à vérifier en jeu : `player.opened` après un remplacement. U, bouton, rangée de murs : prouvés en
  moteur simulé ; en partie réelle : non prouvé.

### F1 · Jeu continu en 15 époques (nouveau, 21/10, 17 h 35)
- Critères ❔ : 15 époques à la suite ; par époque une ressource, un bâtiment, une silhouette ; durée longue (époque 15
  vers 60 h) ; IA en époques ; budget A1 à l'époque 15 ; branches avancées fabricables depuis la carte.
- État : 🟨 cadre V2 ; époque 15 à 52 h 36 au modèle (V2c), non prouvé en partie ; X0 hors jeu ; en jeu : monnaies
  des âges 5, 7, 8 et titane ; X2 non fusionné (25/10) ; X3 hors jeu (27/10).

---

## 4. Questions et réponses

Toutes les décisions. Vos mots entre « » (au-delà de 300 caractères, extrait avec « […] » ; entier : archive, §4) ;
hors guillemets, la lecture de l'orchestrateur. Puis les questions ouvertes.

| ID | Date | Sujet | Votre réponse | Conséquence |
|---|---|---|---|---|
| Q1 | 21/10 17 h 35 | Ampleur du changement de forme | « Pièces + 15 époques… » (citation en F1, archive) | D1 révisé ; F1 créé |
| Q2 | 21/10 17 h 35 | Nouvelles images rendues | Oui | Règle 8 levée ; protocole H-V1 |
| Q3 | 21/10 17 h 35 | Par quoi commencer | Refaire le visuel des 7 familles | Phase V d'abord |
| Q4 | 21/10 18 h 07 | Les factions vous attaquent | « oui (et différents niveaux de difficulté) » | C4 ; lot IA0 |
| Q5 | 21/10 17 h 35 | Compaction ×4 : quand | « Tout de suite après le visuel » | Phase C après la phase V |
| Q6 | 21/10 18 h 07 | 2 niveaux par époque | « oui c'est bien » | Lot V2 |
| Q7 | 21/10 18 h 07 | Les 15 époques du §6 | « oui, mais en faite rajoutez carrément des branches de matière noire etc, en mode vraiment un truc avancé (il faut donc imaginer le scénario et les crafts également évidemment) » | §6 validé ; lot X0 ; F1-6 |
| Q8 | 21/10 18 h 49 | Machines « pleines » des époques 10 à 15 | « si ajourer veut dire changer le design, c'est oui » | Ajourer = changer la forme ; D1-3 à 50 % |
| Q9 | 21/10 18 h 49 | Hauteur à l'époque 15 | « comme vous le sentez, il ne serait pas déconant de voir une usine de 10x10 à un moment, par exemple sur des réacteurs d'antimatière ou quoi. » | Plafonds de V1 ; nouveaux bâtiments jusqu'à 10 × 10 |
| Q10 | 21/10 18 h 49 | Forme commune par époque, 5 ères | « oui je suis d'accord » | Règle de V3 |
| Q11 | 21/10 18 h 49 | Niveau 1 vanilla ; centre 1 en poste de pionnier | « oui » | Appliqué |
| Q12 | 21/10 18 h 49 | Moins d'images de tir | « oui si vous voulez, je sais pas vraiment l'impact que ça aura en vérité. » | Pas d'économie par défaut (R4) |
| Q13 | 21/10 18 h 54 | Amender D1-3 | « Oui, j'accepte l'amendement de D1-3 : socle exclu de la silhouette et mesure insensible à la taille (seuil à étalonner sur les premières pièces). » | D1-3 amendé |
| Q14 à Q17, QX1 à QX9 | 21/10 21 h 25 | Recommandations de l'architecte | « OK pour toutes vos recommandations sur Q14 à Q17 et QX1 à QX9. » | Q14 option A ; Q15 PV ramenés ; Q16 condition légère ; Q17 sans objet ; QX1 brûleur ; QX2 oui ; QX3 défaite en Impitoyable ; QX4 énergie nette ; QX5 noms gardés ; QX6 sans objet ; QX7 60 h = Porte ; QX8 niveau 1 ; QX9 recherche allégée |
| Q18 | 21/10 21 h 38 | Quand construire IA1 | « Oui : IA1 se construit en parallèle de la Compaction, juste après le visuel. » | V, puis C et IA1, puis X, puis I |
| Q19 | 21/10 21 h 45 | Amélioration, PNJ, scénario | « […] Alors que là, l'idée, c'est si on a les ressources, on améliore, terminé. […] j'ai relu votre scénario et le scénario est bien […] » (citation complète : archive) | Amélioration instantanée ; C5 précisé ; X0 approuvé ; D4 |
| Q20 | 21/10 21 h 52 | Synthèse de Q19 ; mémoire vidéo | « Ok, oui, continuez, la synthèse est parfaite. […] Concernant la mémoire vidéo, partez du principe que je jouerai sur des PC qui auront au minimum 8 Go de VRAM. Ce PC actuel en a 16. C'est une RX 6900 XT […] globalement 8 Go de VRAM, c'est bien pour la mémoire vidéo. » | D4-1 : 8 Go minimum |
| Q21 | 21/10 21 h 55 | Basse qualité | « veillez vraiment à ce que la version basse qualité soit pas si basse que ça […] » (citation complète : archive) | D4-2 renforcé ; D4-5 |
| Q22 | 21/10 22 h | Autonomie de la nuit | « vous avez carte blanche, je valide entièrement toutes vos décisions. Seulement, voilà, évitez en fait les utilisations d'outils MCP qui nécessitent une validation préalable […] puisque bah, je serai en train de dormir » | Design validé seulement par votre verdict |
| Q-IA1-1 à Q-IA1-7 | 24/10 10 h 25 | Équipes de PNJ organisées | « A » (construire IA1 maintenant) | Défauts réversibles (D-14) : Q-IA1-1 coûts X0 ; Q-IA1-2 30 dès l'époque 1 ; Q-IA1-3 profil léger ; Q-IA1-4 gabarits ; Q-IA1-5 mode Assisté ; Q-IA1-6 partie durable ; Q-IA1-7 rangs |
| Q23 | 22/10 7 h 20 | Puissance perçue et taille | « […] on a vraiment l'impression que ce niveau-là est plus puissant que le niveau du dessous […] c'est pas que on agrandir l'échelle finalement, c'est on augmente aussi les détails, voilà. » (citation complète : archive) | D1-4 révisé ; D1-4 bis |
| Q24 | 22/10 7 h 40 | Changement de taille | « Q24 : agrandissement sur place si la place autour est libre ; sinon l'amélioration est refusée et le contour nécessaire s'affiche. Aussi, notez bien l'avancée du projet quelque part, histoire que si un autre agent doit reprendre la gestion du projet, elle ne recommence pas tout » | V3-T, V3-T2 ; `REPRISE.md` |
| Q25 | 22/10 15 h 48 | Délégation des choix visuels | « je verrai les templates àlus tard car vous savez parfaitement quoi faire » | Choix provisoires, réversibles |
| Q-S1, Q-S2, Q-S3 | 22/10 16 h 45 | Emprise pour toutes les familles ; luminance ; regard naïf | « Q S1 çui, Q S2 oui et " oui. […] on n a pas l" cote changement d epoque avec un DA par epoque […] » (citation complète : archive) | Oui aux trois (V3-T2) ; V3-E |
| Q-T2-1 | 22/10 21 h 06 | Machines sans place pour grandir | « QT21 option B » | Bouton « libérer la place » (0.4.4) ; Q-T3-1 |
| Q-T2-2 | 22/10 21 h 06 et 21 h 12 | Production par tuile qui baisse | « QT22 j'ai rien compris » ; puis « QT22 ah ouais non du coup, l'idée est vraiment d'avoir un idle massif en fait, des coûts qui augmentent évidemment, mais ça typiquement c'est pas possible donc A » | A ; V3-T4 non intégré (Q-T4-1) |
| Q-P1 | 23/10 16 h 20 | Disque | « pour le disque c tout bon, pour les dessins des canons c est la A,  pour la question 3 on fait la C, long mais tant pis » → A | 1 776,5 Mo déplacés vers `C:\Users\evan2\fo-archives` |
| Q-P2 | 23/10 16 h 20 | Tête de la mitrailleuse | « pour les dessins des canons c est la A » | 64 positions (A3) |
| Q-P3 | 23/10 16 h 20 ; 24/10 8 h 35 | Objets hors des 7 familles | « pour la question 3 on fait la C, long mais tant pis » ; « la longue, un design par âge, c'est B » | Un design par âge |
| Q-A4-1, Q-A4-2, Q-A4-3 | 24/10 8 h 35 à 10 h 15 | Éclat, socle animé, couleur d'équipe | Q-A4-1 : « B mais A sur les dernières aires » ; « je voudrai qu'il grossisse au fur et à mesure des aires, docn en gros, le dernier il est gros » ; Q-A4-2 : « 3) A » ; Q-A4-3 : « 4) B » ; puis « c'est atroce à vior, il faut que ce soit de petits éléments qui soient changé de couleur et aussi pas autant saturé, c'est très désagréable » | Éclat croissant (0.4.11) ; socle animé (0.4.18) ; petits éléments désaturés |
| Q-M1-4/5, Q-F1, Q-A3F | 24/10 15 h 45 | Tungstène de nuit ; laser ; fentes de l'âge 11 | « pour répondre à vos questions : 1) A, 2) A, 3) A » | Tout gardé |
| R-20H | 24/10 20 h | Ressources, machines, PNJ, modules | « aussi, je trouve qu'il n'y a pas assez de nouvelles ressources, pas assez de nouvelles machines […] on veut du +30% par niveau (cumulatif, donc par exempel vitesse de 1 * 1.3 * 1.3 * 1.3) […] » (citation complète : archive) | Analyses ; Q-B1, Q-B2 |
| Q-B1, Q-B2, R-20H30 | 24/10 20 h 30 | Paliers et emplacements des modules | « QB1 en fait c'est aps ça, l'idée et que par exemple, au palier 1 on A +50% de vitesse, au palier 2 on a +80% […] QB2 B, on commence à 5 et ensuite +1 par niveau » (citation complète : archive) | Modules multipliés ; 5 emplacements, +1 par niveau |
| B-Q1 à B-Q4 | 24/10 21 h 40 | Biomes | « B1 D, B2 A, B3 B, B4 B » | B0 (0.4.16) |
| Q-M1 à Q-M3 | 24/10 21 h 50 | Modules au-delà de × 328 | « M1 A, M2 A, M3 A mais en fait on va réduire, il faut que l'énergie consomé soit légèrement inférieur à la productivité gagnée, par exemple : +50% vitesse / +30% consomations d'énergie, je dirait que la consomation d'énergie en plus doit être 60% du bonus apporté à la productivité » | MOD-1 ; énergie à 60 % du bonus |
| Q-MATIN-25 | 25/10 5 h (réponse 9 h 15) | Onze questions de la nuit | « j'ai rien compris au formart de réponse, pour moi ça veut rien dire, posez moi les questions ICI avec un choix QCM où je peux cliquer dessus et ça fonctionne DANS claude code » | Reposées en QCM (R-QCM-25) |
| R-QCM-25 | 25/10 9 h 15 | 26 choix | Q-M5 : « Garder l'écart (Recommandé) » ; logistique : « il faut tout simplement des bras robotique capable de prendre énormément d'objets à la fois, et d'avoir des convoyeurs capable d'augmenter exponentiellement leur vitresse […] » (citation complète : archive) ; hydrogène : « Une recette qui l'utilise » ; recrues : « Défendre d'abord » ; centre (X2) : « Accepter la hausse » ; sous-produits : « Leur donner un usage » ; fond : « Laisser grandir » ; minage à la main : « Garder 20 % » ; balises : « Garder par âge » ; palier : « Garder le romain » ; productivité : « Engrenage » ; modules : « Couleur par type » ; balises si modules colorés : « Couleur de l'âge » ; équipe : « 25 % » ; pièces : « seulement les liserés je pense que c'est mieux. Aussi, si c'est possible d'automaiser la teinte ça ferai qu'on pourrai en théorie choisir le nombre d'équipe dans la partie » ; équipe la nuit : « Laisser ainsi » ; laser : « Troisième ronde » ; ilménite : « I2 sombre » ; ilménite la nuit : « Assombrir » ; saumure : « Visuel propre » ; monazite : « À refaire » ; gardes : « Couper les gardes » ; Q-M4 : « multiplier aussi mais moins violament que la vitesse, d'ailleur la vitress on va baisser l'augmentation par palier, et on garde la multiplication pour les 2 » ; D-16 : « Oui, tout garder » ; vitesse : « +20 %, puis +10 %/palier » ; productivité : « +10 %, puis +5 %/palier » | D-17 |
| R-QCM-25b | 25/10 10 h 40 | Plafond (× 328,67, erreur corrigée) ; malus ; efficacité ; 30 modules | « Pas de plafond (× 328) » ; « Réduire de moitié » ; « Garder » ; « j'ai pas vu, faire mopi un artefact », puis « Validé tel quel » | D-17 complétée ; modules VALIDÉS |
| R-QCM-25c | 25/10 11 h 20 | Défendre d'abord (factions) ; coffre ; occupation | « Oui, toutes » ; « L'équipe le défend » ; « Donner du travail » | D-17 complétée |
| R-QCM-25d | 25/10 12 h 15 | Fenêtre « Équipe et factions » | « Validée, en jeu » | IA1-i (0.4.28) |
| R-QCM-25e | 25/10 12 h 40 | Le four, 15 âges | « Oui, enrichir » ; « (j'ai choisi enrichir mais en fait c'est pas si mal, je pense qu'il faut pas beaucoup plus que les fours soient parfait) » | Ronde légère |
| R-QCM-25f | 25/10 12 h 50 | L'assembleur, 15 âges | « En fait, les assembleurs sont bien dans l'idée mais j'ai l'impression que certain ont juste une plateforme et un truc posé dessus, ça fait pas précis, pas détaillé et aussi ils sont tous carré, mais peut être qu'on peut aussi en faire des circulaires » | F3-A2 |
| R-QCM-25g | 25/10 13 h | Cerveau des PNJ (IA3-DIAG) | « en fait ils doivent jouer comme des joueurs, mais qui s'organisent […] il faut que vous réfléchissiez à comment un humain réfléchi, et transcrire ça pour les IA […] » ; ouvriers : « 8, après les corrections (Recommandé) » ; ordre : « Selon le caractère (Recommandé) » ; pétrole : « ils doivent se débrouiller pour chercher du pétrole, comme les joueurs quoi […] c'est une section à paert entière car ça fait partie intégrante du gameplay ! » (citation complète : archive) | D-18 : section IA3 |
| R-QCM-25h | 25/10 15 h | Four retouché ; foreuse ; foreuses de X0 | « Validé, production » ; « Oui, enrichir nettement » ; « Elles restent à part » | F2-B ; F4-A2 ; Q-C3 |
| R-QCM-25i | 25/10 15 h 20 | L'assembleur, 2e ronde | « 3e ronde (Recommandé) » | F3-A3 |
| R-25j | 25/10 15 h 20 | Demande | « Aussi en parallèle, oubliez pas de lancer un banc sur vraiment le développement profond des IA/PNJ. » | IA3 en parallèle |
| R-25k | 25/10 17 h 40 | Section IA (17 à 21 jours) | « alors par contre 17 à 21 jours non, vous mettez le budget si il faut mais mettrez des agents sur le coup en permanance pour avancer sur la partie IA. » | Agents en permanence |
| R-QCM-25l | 25/10 18 h 30 | L'assembleur, 3e ronde | « Validé, production » | F3-B (0.4.31) |
| R-4/11-DESIGNS | 4/11 8 h 25 | 70 images de la nuit | « je valide tous les designs » | Tous validés ; 0.6.48 |
| QCM-4/11 | 4/11 8 h 35 | Géants ; Bourdon ; directions ; tourelles du QG | « 1 géant dès l'âge 10 » ; « sortie automatique mais on doit pouvoir les déplacer manuellement hein, contrôler les robots » ; « 16 pour les plus vus seulement » ; « Placement groupé dès la pose » | BOURDON-SORTIE ; RB16 ; QG-GROUPE2 |
| QCM-4/11-KITS | 4/11 8 h 50 | Icône des kits de robots | « Caisse de famille » | 0.6.48 |
| QCM-4/11-REGLEB | 4/11 10 h 05 | Bande de champ qui retombe | « Réserve, plus de nouvel essai » | Bande en réserve |
| QCM-4/11-SORTIE | 4/11 11 h 30 | 0.6.49 et Azure | « Sans Azure, vers 12 h » | Azure en 0.6.50 |
| DC-4/11-LASER | 4/11 11 h 35 | Tourelles laser | « on avait des tourelles lazer déjà présent dans le mod mais je le trouvent pas, elles sont où ? » ; « Lancer la 3e ronde maintenant » | F1-C |
| QCM-4/11-LASER-F1C | 4/11 13 h 15 | Laser, 3e ronde | « Valider, lancer la production » | Design validé (9fb91918) |
| QCM-4/11-SUITE | 4/11 13 h 30 | Chantiers à relancer | « Dépenses du stock dormant, Périmètres de défense, "et investir en recherche, armement" » | DEPENSES, PERIMETRE |
| QCM-4/11-DEFAUT7 | 4/11 17 h 30 | Âge 2 d'Azure | « Intégrer + attaquer la suite » | Intégré ; AGEBLOCAGE |
| DC-4/11-30MIN | 4/11 18 h 07 | Délai | « vous avez 30 minutes pour implementer les derniers objectifs et avoir une version jouable » | 0.6.51 avec le seul défaut 7 |
| QCM-4/11-MURS | 4/11 18 h 05 | Murs de votre équipe | « Oui, enceinte et avant-postes (Recommandé) » | Non livré en 0.6.51 ; repris le 5/11 |
| QCM-4/11-RECRUES | 4/11 18 h 40 | Recrues sur stock dormant | « Oui, comme les factions (Recommandé) » | DEPENSES2 |
| DC-4/11-GRAPHE | 4/11 18 h 55 | Graphe des chaînes | « […] il me faudrait une sorte de graph format avec les icones et usines pour bien se repérer […] Quelqu'un qui ne connais pas le mod, en regardant ce graph il doit comprendre comment faire ses usines […] » (citation complète : archive) | `fo-logs/2026-11-04_GRAPHE/index.html` |
| DC-4/11-DANGER | 4/11 19 h 10 | « Trop dangereux » | « déssactive le comportement "trop dangereux", l'idée est qu'ils continuent de travailler en évitant le danger. Actuellement ils font juste rien quand c'est "trop dangereux" (la moindre petite attaque même d'un avant-poste) » ; « (continuer à travailler tout en évitant le danger ou en défandant) » | DANGER-ACTIF |
| DC-4/11-PAUSE | 4/11 19 h 25 | PNJ immobiles | « […] Le seul problème, c'est qu'ils sont perpétuellement en trop dangereux ou en alezan, donc ils ne font plus rien. […] le comportement trop dangereux devient juste un mode pause pour toutes les IA de la partie. » (citation complète : archive) | Seuls les ouvriers exposés réagissent |
| DC-4/11-JEU | 4/11 19 h 30 | Laisser jouer le DC | « Laisse-moi jouer au jeu s'il te plaît. Je peux pas jouer s'il y a d'autres instances de Factorio qui tournent. Merci. » | Bancs arrêtés |
| DC-4/11-SURVOL | 4/11 19 h 40 | Fenêtres au survol | « Aussi pour les pop-ups d'améliorations ou autre, dès que le curseur passe sur un truc, c'est ultra chiant. Il faudrait que ce soit déclenchable ou même dans l'interface uniquement quand on clique sur le bâtiment concerné. » | PANNEAU : au clic |
| DC-4/11-FINJEU | 4/11 19 h 46 | Fin de partie | « j'ai fini de jouer, corrigez un maximum d'éléments. » | Gel levé |
| QCM-4/11-BASE, QCM-4/11-PACKS, QCM-4/11-COUTXP, QCM-4/11-DEMIVIE | 4/11 19 h 48 | Base de départ ; packs des âges 9 et 13 ; technologies et Demi-Vie des robots expérimentaux | « Base de départ toujours en dernier (Recommandé) » ; « Oui, tous les packs de l'âge (Recommandé) » ; « Le double du robot précédent (Recommandé) » ; « 100 circuits avancés + 70 servomoteurs (Recommandé) » | Rayon de 64 tuiles ; corr-xp-couts |
| DC-5/11-ESSAIS | 5/11 14 h 25 | Règle des essais | « Relâchez en train de voir des derniers essais, y a pas de dernier essai. Les objectifs doivent être atteints, c'est tout. » | Correction jusqu'à l'objectif |
| DC-5/11-PERF | 5/11 14 h 30 | Performance à ×10 | « […] le jeu devrait très bien tourner vitesse fois dix […] on devrait pas avoir de freeze ou de ralentissement comme observé in game » (citation complète : archive) | PERF3 |
| DC-5/11-CADENCE | 5/11 14 h 48 | Cadence | « Motivez vos troupe, mettez les bouchées doubles si il faut » | ÉTAGE 5 en parallèle |
| QCM-5/11-RHO8, QCM-5/11-RALLIEMENT | 5/11 14 h 50 | Suffixe « ρ8 » ; trait de ralliement | « Retirer « ρ8 » (Recommandé) » ; « Au clic, comme le panneau (Recommandé) » | corr-panneau2 |
| QCM-5/11-PLASTIQUE | 5/11 15 h 45 | Valeur du plastique | « Aligner sur 1,0 (Recommandé) » | value = 1.0 |
| DC-5/11-PREUVES | 5/11 16 h | Preuves d'avancement | « […] Il ne suffit pas de dire qu'on travaille pour travailler, faut des preuves des efforts. […] Si vos équipes sont incapables de réfléchir, changez-les. […] » (citation complète : archive) | Micro-scénario avant partie longue ; preuve toutes les 45 min |
| QCM-5/11-ZONE | 5/11 16 h 20 | Base visée en dernier | « Toute la base qui grandit (Recommandé) » ; « Le coffre protège toujours » | QG-ZONE |
| QCM-5/11-CENTRE4 | 5/11 16 h 30 | Centre vers l'âge 5 ; processeur | « Moitié plastique, moitié moteurs (Recommandé) » ; « Aligner sur 46 (Recommandé) » | corr-plastique |
| QCM-5/11-THERMIQUES | 5/11 20 h 45 | 201 foreuses thermiques | « Remplacer au fur et à mesure » | FOREUSES-THERMIQUES |
| QCM-5/11-XP | 5/11 21 h 30 | Unités expérimentales | mort : « Les deux » ; écart : « 4 âges de moins (Recommandé) » ; survie : « 3 min » ; cibles : « Tout, jusqu'à la fin (Recommandé) » ; salves : « 5 salves (Recommandé) » ; zone : « +15 par age » ; trace : « Cratère et sol brûlé (Recommandé) » ; designs : « Un titan plus gros que le Bourdon, De nouvelles attaques, L'impact sur la carte, Des modules (portée, puissance) » ; « vous ferez tout en 10 heures, le temps que je dorme. […] » (citation complète : archive) | EXPERIMENTAUX-PUISSANCE |
| QCM-7/11 | 7/11 10 h 55 | Après l'essai 0.6.56 | coffres : « Oui, prise et dépôt (Recommandé) » ; géants : « 16 directions (Recommandé) » ; séquelles : « Cratère et verre, pas de falaises (Recommandé) » ; mitrailleur : « 16, comme le fusilier (Recommandé) » ; Bourdon : « non temporaire mais de 10 minutes, d'ailleur, je pense que les dégas visible permanant devraient en réaliter durer 1 heure, se résorber » ; titan : « × 1,25 » ; modules : « Prix selon l'âge du géant (Recommandé) » ; factions : « Oui, selon leur âge (Recommandé) » | Traces de 1 h, jamais de falaises ; Atlas × 1,25 |
| QCM-7/11-PARTIE | 7/11 14 h 25 | Équipe à 2 PNJ ; tourelles ; grenadier | « je veux toujours n ouvriers minimum, donc 12 si 12 au départ. Au delas ça coute des ressources » ; « Portée 16 d'abord (Recommandé) » ; « en fait il a de très très fortes chances que ce soit les pnj qui les aient prise mais j'ai aucune preuve » ; « Garder 26, unité de siège (Recommandé) » | Recrue gratuite sous l'effectif de départ (SPIRALE-FER) ; portée 16 en 0.6.59 |
| AUTONOMIE-7/11 | 7/11 15 h 40 à 16 h 45 | Rythme et ressources du PC | « vous avez toutes les ressources du PC a disposition, pendant les 60 prochaines minutes. Finalisez au maximum la todo liste vidéo et les objectifs ! » ; « continuez a dev tant que vous n'avez pas TOUT FINI » ; « on garde le rythme, juste mettez max une instance blender et une instance factorio en arrière plan » ; 16 h 48 : « Tu peux y aller sur les ressources du pc pendant au moins 1 heure encore (donc investissement ressource + agents au MAX) » | Travail continu sur la TODO de la vidéo et les objectifs. De 16 h 45 à 16 h 48 : banc à 1 place, Blender `--slots 1` (deux tickets en copie arrêtés et remis en file). Depuis 16 h 48, pour 1 h au moins : 3 places, 2 Blender ; agents ajoutés (laser en jeu, panneau prouvé en partie réelle, branchement de la vidéo sur 5 fronts) |
| QCM-7/11-RECUL | 7/11 16 h 56 | Recrue gratuite sous un campeur | « Oui, avec le filet (Recommandé) » | Une recrue gratuite tuée moins de 60 s après son apparition double l'attente de la suivante (600, 1 200, 2 400, puis 3 600 ticks au plus) ; remise à 0 après 5 min sans mort rapide. Sur 30 min de campeur : environ 25 recrues au lieu de 360. Sans campeur : cadence inchangée (`shared/team/spirale.lua`, effondrement) |
| QCM-7/11-X10 | 7/11 17 h 40 | Leviers du moteur pour le ×10 (rapport `fo-logs/2026-11-07_X10/MOTEUR.md`) | usines : « Oui, figées hors de vue (Recommandé) » ; trajets : « Marche réelle, chemins mieux gérés (Recommandé) » ; effets : « Allégés loin de vous seulement (Recommandé) » | Usines des factions figées (en pause, économie comptée à part) quand aucun joueur ni aucune menace n'est à moins de 200 tuiles, réveil à l'approche, avec une mesure M1 d'abord ; PNJ qui marchent toujours pour de vrai, sans recherche vouée à l'échec et avec les chemins répétés gardés en mémoire ; effets de combat allégés seulement loin du DC |
| D-19 | 27/10 8 h 25 | Le calcul (X3) | « "Je propose qu’il fonctionne comme l’électricité : un centre de calcul le produit en consommant du courant et du refroidissement." Complètement d’accord je valide » | Comme l'électricité |
| R-QCM-27a | 27/10 10 h 15 | X3 : voie obligatoire ; robots ; pièces montées ; calcul | « Fonderie de puces à l'âge 10 » ; « Ils faudrait créer d’autres robots, si vous voulez un peu un style d’inspiration ça serait style Suprême Commander 2 (modérateur revemp mod (designs plus créatif et complet)) » ; « Oui une partie du coût des niveau en pièces montée. A noter que si l’IA est autonome elle le fera d’elle même, il faut que ce soit un choix logique et nom encré en dur c’est très important » ; « Non stockable, par script » | D-20 (1) à (4) |
| R-QCM-27b | 27/10 17 h 35 | Tirs, puissance, son | « Bonne direction, plus fort » ; « Aussi les dégâts » ; « Plus fort et plus grave » | D-21 |
| QCU 29/10 | 29/10 20 h 50 | 7 arbitrages | « Supprimer le plafond » ; « oui garder mais il faut faire attention si c'est des pnj qui meurent proche de la base […] » ; « Oui, lancer le lot » ; « Supprimer le gel » ; « la fonderie grandit en fonction du nombre de foreuses qu'elle a en input, donc dynamiquement, ni 2, ni 4, ni 8, mais dynamique » ; « oui hors du mur mais potentiellement l'entourer d'un mur et d'une ou 2 tourelle » ; « Oui, ressources d'abord » (citation complète : archive) | Vague 8 (six lots) |
| QCU PREVISION | 29/10 22 h 15 | Prévoir ; coût de la défense | « Comme le joueur » ; « Oui, compter la défense » | PREVISION |
| QCU calcul | 30/10 11 h et 12 h 30 | Machines amont du calcul | « Oui, les 4 aussi » ; « A : four rotatif » ; « A : 3 électrodes » | Kit des machines amont |

### Questions encore ouvertes (texte de la source, en entier)

- **Q-V2c-1** (22/10). QX10 (passage du centre ≈ 10 % du budget) n'est tenu qu'aux époques 1 à 4 : la règle de place (le coût tient dans la moitié du coffre du centre) et les monnaies d'aujourd'hui le bornent à 3,35 % puis 0,11 % du budget, et le centre 15 s'atteint en 3 h 27 par le chemin le plus court (52 h 30 au calendrier). Remède : (a) un objet dense propre au passage (le « Codex k » du scénario X0) ; (b) un remplaçant dense provisoire en attendant les monnaies de X0 ; (c) une règle de place assouplie (ou un coffre plus grand) pour le seul centre ; ou (d) accepter l'écart ? → Recommandation : (a), le Codex k de X0 ; d'ici là, QX10 et le rythme de 52 h sont NON CONFORMES.
- **Q-V2c-2** (22/10). Depuis Q19 (amélioration instantanée), l'« Horloge éternelle » (6e ouvrier, 2 sabliers par chantier, QX6) et le « Sablier quantique » (− 25 % de durée de chantier) du scénario X0 n'ont plus d'effet. Que doivent-ils offrir ? (par exemple : remise sur le coût des améliorations, amélioration d'une zone entière d'un coup, rangées de tous les bâtiments) → En attente de votre réponse.
- **Q-T3** (22/10). Migration des emprises d'une sauvegarde 0.4.1 (RD_LOG E46, 22/10) : une mitrailleuse collée à une ligne de murs et nourrie par un bras placé derrière elle n'a pas la place de grandir. Elle reste à sa position, hors grille, en service, avec sa nouvelle taille (chevauchement toléré, journalisé). Est-ce acceptable, ou faut-il une autre règle, par exemple déplacer aussi le bras ? → Rattachée à Q-T2-1 (répondue B, bouton « libérer la place », 0.4.4).
- **Q-M0-1** (23/10). **Gisement garanti dans une partie NEUVE** (lot M0, version 0.4.5, RD_LOG E73, E74, F133). Le tungstène (âge 5), le cristal (âge 7) et le méthane (âge 8) sont désormais garantis sur toute carte : un site posé par script entre 200 et 700 tuiles du départ. Sur 5 graines essayées, 3 n'avaient pas l'une des trois monnaies à cette distance. Dans une partie neuve, le jeu ne sait pas encore ce que la graine cache à 500 tuiles. A = le site garanti est TOUJOURS posé (actuel) : parfois un gisement de plus que la graine n'en avait ; B = seulement si la graine n'en a pas : environ 2 s de plus à la création de la carte (environ 2 850 chunks générés) et une sauvegarde bien plus grosse → Recommandation : A, comportement livré en 0.4.5.
- **Q-M0-2** (23/10). **Aspect du site garanti** (lot M0, captures `<racine>\fo-logs\2026-10-23_suite\M0\captures-2\`, critère B7). Le site se voit comme un disque net de cendres (ou de plaine de cristal, ou de marais) posé sur le sol voisin. A = le garder ainsi ; B = l'adoucir (bord fondu, décor du biome) avec le kit sol et décor du lot M2 → Recommandation : B, avec le kit sol de M2.
- **Q-T3-1** (23/10). **Rangées collées et bouton « Libérer la place »** (lot V3-T3, E59). Le bouton ne libère que les bâtiments qui ont un côté libre : au milieu d'une rangée collée, un voisin gêne toujours (usine dense de test : 5 libérables sur 19 ; défense dense : 2 sur 13). Posée sur la page des planches V3-E le 23/10 à 0 h 20 : A = garder ainsi ; B = le bouton déplace aussi les voisins, en cascade ; C = agrandir une rangée entière d'un coup, mise en page refaite → Recommandation de l'orchestrateur : C (gros lot)
- **Q-T4-1** (22/10). **Rentabilité des améliorations et « idle massif »** (lot V3-T4, 22/10, 22 h 40 ; branche `worktree-wf_9d38a6df-249-1`, tête `2b18742`, NON intégrée). Le lot V3-T4 applique Q-T2-2 (A) pour la DENSITÉ : un bâtiment agrandi vaut au moins les petits posés à sa place, production par tuile croissante, mesurée en moteur réel. Mais pour tenir le calendrier (époque 15 vers 60 h), il a multiplié les coûts (jusqu'à × 6 au niveau 30), et une amélioration ne se rembourse plus : passer la foreuse du niveau 29 au niveau 30 coûte l'équivalent de 510 heures de sa production supplémentaire (342 h en 0.4.3, déjà non rentable). 12 nouveaux écarts connus (23 en tout), dont la place des coûts dans le coffre du centre et le DPS des tourelles (Q14). Posée dans le chat le 22/10 vers 22 h 45 : A = vrai idle (chaque niveau produit nettement plus que le précédent, les coûts montent aussi vite, chaque amélioration se rembourse en moins d'une heure de jeu, la partie garde environ 60 h ; gros rééquilibrage) ; B = garder la progression actuelle (on améliore pour avancer d'époque, pas pour la rentabilité) → Recommandation : A ; V3-T4 non intégré en attendant.
- **Q-S0-1** (23/10). **Sons de tir de la mitrailleuse par ère** (lot S0 ; page d'écoute https://claude.ai/artifact/Ap4JoXCgvxJJR29b5QceU3 , le son du jeu de base d'abord, puis les 5 ères, un tir seul et une rafale chacune). Pour chaque ère : A = garder ; B = changer (dites quoi : plus grave, plus sec, moins de basse…) ; C = refaire → Sons provisoires depuis 0.4.7, réversibles ; jamais plus forts que la vanilla (mesuré).
- Q-X3-1 à Q-X3-3 (27/10, archive §7) ; R-QCM-27a répond à quatre questions « X3 ». Attendent aussi votre décision
  (§5) : Meshy (27/10), le TIROIR (5/11), le géant et les icônes des modules (7/11), votre super robot (1/11).

---

## 5. Historique des écarts signalés par vous

Plus récents d'abord ; extraits mot pour mot (entier : archive, §5 et fin du §7) ; « — » : sans état écrit.

### Les quatre écarts du 7/11 (votre partie 0.6.58, `0e340b99`)

- **Recrues et PNJ morts** (14 h 05, dicté) : « quand ils meurent, déjà je me retrouvais avec deux ouvriers et le problème, c'est qu'ils ne faisaient plus rien. […] » ;
  « j'ai du mal à vous croire puisque les agents ne respawnent pas. En tout cas, de mon équipe, les workers sont morts et ont juste pas respawn. »
  ⏳ Code lu (déduit) : la tâche d'un PNJ tué n'est PAS perdue. MESURÉ au journal figé
  `fo-logs/2026-11-07_PARTIE-DC-0658/factorio-current-1415.log` : 46 PNJ de l'équipe tués (25 sans tâche, à 6-7 tuiles
  du QG, par les tireurs des factions) ; dernière recrue à 123,4 min (effectif 12) ; fer à 0 au coffre presque toute la
  partie (cuivre 5 385). La recrue se paie en plaques : sans fer, ni recrue, ni tourelle, ni munitions (spirale,
  déduite). Vous aviez raison. QCM-7/11-PARTIE : recrue gratuite et équipée sous l'effectif de départ. Lot SPIRALE-FER.
- **Tourelles disparues** (14 h 10, dicté) : « j'avais posé des tourelles tout autour de la base, tourelles qu'ils ont, je ne sais pas par quelle raison, volontairement enlevées et du coup ils se sont retrouvés sans défense »
  ⏳ MESURÉ : 0 tourelle enlevée par le chantier ; 40 tuées près du QG par les factions, dont 31 par un tireur AU-DELÀ
  de leur portée (fo-lvl-gun-4 : 19,2 ; fo-amber-gunner à 21,2 tuiles) : elles disparaissent sans tirer. Réserve : un
  retrait sans journal n'est pas exclu ; piste (déduite) : le minage à la main d'un PNJ sur la tuile d'une tourelle.
  danger5 : tous les chemins qui retirent une tourelle, journal [FO-TOURELLE-RETIREE] ; portée 16 (b142714d, 0.6.59).
  ✅ Piste PROUVÉE le 7/11 à 16 h 22 (moteur réel, témoin 0.6.58, RD_LOG F389) : un PNJ de votre équipe mine à la main une
  mitrailleuse posée sur du minerai en 7,5 s, et elle finit dans son sac. Vous aviez vu juste (« très fortes chances que ce
  soit les pnj »). Les deux causes s'ajoutent : le minage à la main, et les tirs hors de portée. Correctifs pour la 0.6.59 :
  portée 16 (E258, 15 OK) et refus de miner une tuile qui porte un bâtiment (`8e34b8c4`).
  ✅ PROUVÉ en moteur réel le 7/11 vers 16 h 55 (`minage-tourelle`, témoin 2 OK 2 ECHEC → branche **4 OK, 0 ECHEC**) :
  la tourelle reste en place, la tuile libre voisine est minée, et le refus est journalisé (« minage refuse : selection =
  gun-turret … batiment sur la tuile de minerai »). Fusionné dans essai-0659 (`85a673b9`), relecture statique en cours.
- **Vidéo d'automatisation** (14 h 40 et 14 h 50, écrit ; https://www.youtube.com/watch?v=PGiTkkMOfiw) :
  « Analysez la vidéo pour en tirer les bons aspets qui nous feront avancer rapidement. […] » ; « […] on peut au moins récupérer 50% de la logique globale. […] doit être exhaustif et surtout qu'on puisse l'implémenter dans notre logique (tiers dynamique, etc...) »
  ✅ Analyse validée ; ⏳ lots en cours (commit 2c46a377). Vidéo de Chris Uehlinger. Livrés vers 15 h 10 : `docs/IA_WORKFLOW.md` (carte de l'IA de faction,
  lecture obligatoire), `docs/VIDEO_AUTOMATISATION.md` (57 mécanismes, lots L0 à L13), `docs/TODO_VIDEO.md` (204
  lignes). Votre verdict (15 h 20) : « je viens d'ouvrir la TODO_VIDEO.md, et je trouve que vous avez parfaitement retiré les informations utiles de la vidéo, même plus. Vous avez donc la "roadmap" pour améliorer au maximum le mod ! » → TODO_VIDEO §G = feuille de
  route de l'IA ; L0 (mesures) et L1 (rang calculé) lancés.
- **Coffres pleins** (14 h 12, dicté) : « ils se sont retrouvés avec des coffres remplis de pierres. Ils avaient plus de place pour visiblement mutualiser les ressources et du coup, ils ont pas pensé à poser des coffres. […] Donc les coffres, il faudrait prévoir en fait. »
  ⏳ MESURÉ : « sature [copper-plate stone] » pendant des dizaines de minutes ; même défaut que le 5/11 (STOCKAGE,
  ouvert). COFFRES (charbonmain) : stockage prévu avant la saturation, place gardée au fer et au charbon.
  ⏳ MESURÉ en moteur réel le 7/11 (banc `collecte-fer`, flux2, archive `fo-logs/2026-11-07_COLLECTE/lot`) : avec 2 PNJ,
  l'un explore et l'autre mine de la PIERRE à la main pendant que le fer est à 0. La collecte urgente du fer (priorité
  94) reste libre pendant 60 s et plus. Rien ne rappelle un PNJ occupé (`team.lua:939` ne vise que la file sûre). La règle
  de collecte choisit pourtant le bon coffre. Lot ajouté : rappel d'un seul PNJ, minage de pierre d'abord, jamais un PNJ
  en défense. La recrue gratuite réduit aussi ce cas.
  ⏳ MESURÉ à nouveau le 7/11 vers 17 h (banc `stockage-plein` v2, charbonmain) : la règle du coffre urgent se déclenche
  (« fabrication de wooden-chest »), mais en 70 s aucun PNJ ne la prend (« inactifs 0/4, libres 23 » : éclaireur, minage
  de fer à 111 tuiles). Une tâche de priorité 90 n'interrompt aucune tâche en cours. C'est le maillon D1 d'IA_WORKFLOW
  (« 0 PNJ libre, 16 tâches libres » dans votre partie). Une seule règle de rappel, générale (toute tâche de priorité 90
  ou plus, quand aucun PNJ n'est libre), sert la collecte du fer et le coffre urgent (flux2).

### Lignes ouvertes ou sans état

| Date | Votre constat (extrait) | État ou suite |
|---|---|---|
| 7/11 10 h 58 | « d'ailleur, il faudrait redesigner les modules de vitesse, productivité etc car ils sont pas beau » | ⏳ design-modules ; rien remplacé avant votre verdict |
| 7/11 10 h 45 | « je viens de voir le design du nouveau géant, ajoutez des détails. » | ⏳ design-titan |
| 5/11 21 h 43 | « […] Il se tournerait et tirerait un gros rayon lazer et tournerait sur un angle de 30 degrès […] » | ⏳ design-attaques ; faisabilité à vérifier |
| 5/11 21 h 40 | « au niveau du stockage, ils ont atteint une limite visiblement. […] » | ⏳ À prouver ; STOCKAGE, COFFRES-JOUEUR |
| 5/11 21 h 35 | « […] ce n'est vraiment pas la mémoire vidéo qui pose un problème actuellement dans le jeu, c'est vraiment les ralentissements. […] » | ⏳ 6 à 7 ms par tick ; PERF4, CERVEAU-CENTRAL |
| 5/11 21 h 20 | « Je remarque également un problème d'optimisation. […] » | ⏳ PERF4, CERVEAU-CENTRAL |
| 5/11 21 h 10 | « pourquoi ils ont pas de pétrole toujours ? […] » ; « […] Je valide entièrement 100 % 150 % même des unités expérimentales […] » | ⏳ Pétrole éteint dans vos réglages ; EXPERIMENTAUX-PUISSANCE |
| 5/11 20 h 30 | « […] Les ressources dans les coffres que j'ai posés n'ont jamais été utilisées, jamais, pas une fois » | ⏳ FOREUSES-THERMIQUES, STOCKAGE, COFFRES-JOUEUR, CHAMP-COUVERTURE, TIROIR |
| 3/11 | « le nouveau design ne corrige en rien ce problème et pire, il désoptimise la production […] » | — Au 3/11 (0.6.43) : fonderie à tapis sans production prouvée ; thermiques PARTIEL ; malls, ECHELON, DEFENSE absents de main |
| 2/11 4 h 30 | « ce genre de problème avec les ressources et les gisements, c'est revenu au moins une dizaine de fois » | ⏳ REGARD, CHAMP, FLUX, ENERGIE, DEFENSE, AGES, PARITE, C4 |
| 1/11 8 h 50 | « de mon cote je viens tout juste de tester les designs 3D et c est in royabl, mais vraiment bleufant […] » | ⏳ En attente de vous |
| 1/11 8 h 40 | « […] il faudrait en avoir des plus petits, histoire d avoir des defenses ou attaques plus abordables. […] pour le QG il faudrait re oir le style ddu 14 et du 15, ils onft pas de details, pas badass » | ⏳ Petits expérimentaux ; QG 14 et 15 refaits |
| 1/11 2 h 20 | « toujours en autonomie pour les 14 prochaines heures. […] » | ⏳ Jusque vers 16 h 30 |
| 1/11 0 h 30 | « assurez moi que les bases s ameliore a l infini » | ⏳ Non assuré ; C1, C2, C3 |
| 31/10 soir | « designez egalement des robots "experimentaux" en mode ultra enorme […] » | ⏳ États clés ; dézoom non prouvé |
| 31/10 soir | « commencez egalement la phase de construction de robots a la supreme commandsr 1 et 2 » | ⏳ Plan des robots |
| 31/10 soir | « trouvez quoi faire en mieux pour les elements actuel, lancez une partie […] » | ⏳ `dc-evolution`, rapport à faire |
| 31/10 soir | QG : « je valide les designs, ils sont super » | ⏳ Âges 0, 8, 15 validés ; série lancée |
| 31/10 (3 lignes) | « il faut pas s'arrêter à 80 % du champ » ; « automatiser EN FONCTION DU BESOIN […] » ; « […] On doit pouvoir avoir une megabase si jamais on laisse tçurner e jeu des heures tout seul. […] » | — Vague 13 ; INDUSTRIE |
| 30/10 (5 lignes) | « je n'aime pas du tout la forme de ces minerais : Blende, Cassitérite, Minerai d'ilménite, Minerai de monazite. Il faut les refaire. […] » ; « refaites les QG, plus de details […] » ; « en fait il va falloir en theorie beaucoup de machines […] » ; « changez les icones mais si non c'est pas mal » ; « tout en parallele » | — Minerais refaits ; QG ; CALCUL-V2 |
| 29/10 soir (4 lignes) | « on dev la fonction, on vérifie les biais ou bugs ou scénarios oubliés qui peuvent être embêtants et c'est validé. […] » ; « […] l'idée est qu'on répare + protège (donc on s'adapte) et ensuite on continue et on améliore […] » ; « il y a absolument aucune prévision […] » ; « […] envoyer un scout pour repérage […] » | — PILE-PRIORITE, PREVISION, RECO-DIRECTION, AMELIORATION |
| 29/10 19 h 55 | « ils sont super laid, mais genre vraiment ultra laid. L'idée est là mais ça manque de TOUT. […] » ; « Pause totale du design » | — Centre v5 refusé ; nez du vaisseau vers la DROITE |
| 29/10 15 h à 16 h 20 (6 lignes, 0.6.15 et 0.6.16) | « en fait enlevez la limite, le vrai probleme du fer c'est principalement le fait qu'ils ne capitalisent pas assez […] » ; « on veut des rangées de foreuses en fait […] » ; « ils reconstruisent pas les convoyeurs, ils reconstruisent pas les usines, […] les fours » ; « il faut vraiment réussir à utiliser nos ressources » ; « autant sécuriser notre base directement » ; « la Ligue Azur a éliminé tout le monde » | — PRIORITE-RESSOURCES, AGENCEMENT, POTEAUX-ASTAR, REBUILD-SUIVI |
| 29/10 14 h | « j'ai remarqué beaucoup d'améliorations et beaucoup de défauts » | ⏳ Vague 3 |
| 29/10 10 h 50 et 12 h 05 (2 lignes) | « mettez le budget sur les corrections des remarques que j'ai faites précédemment » ; « honnêtement je préfère une analyse statique du code par un agent plutôt que de tester la moindre ligne de code tout le temps […] » | — Relecture statique, tests rapides, un `content` |
| 29/10 9 h 45 à 10 h 40 (3 lignes) | « le centre est pas mal mais j'aurai aimé que ça suivît plus la forme de la fusée en fait […] » ; « Vaisseau couché, long » ; « […] elles sont pas très propres pour le moment […] » | — Le centre est la fusée de départ ; CENTRE-FUSEE |
| 29/10 8 h 40 | (audit de D-26, pas une citation) | ⏳ 1 remarque dans main, 8 parquées, 5 sans code |
| 28/10 14 h 45 | « ils utilisent toujours massivement des foreuses thermiques […] » | ⏳ D-25 : un optimiseur, lots A à F |
| 28/10 soir | « vérifier le stockage également + agrandir régulièrement le stockage » | ⏳ D-26 : `docs/NUIT_PLAN.md` |
| 28/10 9 h 05 | « "ne visent que ce qu'elles ont reconnu" oui mais à noter qu'elles doivent aussi faire de la reconnaissance comme un joueur finalement » | ⏳ Après `recon` |
| 28/10 7 h 50 | « 3) seulement ce qu'elles ont reconnu en fait, elles peuvent pas viser un avant-poste qui n'a pas été vu […] » | ⏳ D-24 |
| 27/10 21 h 40 | « Aussi, faites en sorte que les IA du joueur principal soient au moins équivalentes […] » | ⏳ Critère P (parité) |
| 27/10 19 h 05 | « […] Actuellement, c'est exactement la même chose qu'hier. […] » | ⏳ Étape 1 (`capib`) |
| 27/10 18 h 50 | « […] Et en fait là, les IA font vraiment rien quoi. […] » | ⏳ CAPIB relancé, K-A à K-F |
| 27/10 15 h 30 | « Ok ouais je vois. Il reste encore beaucoup à faire du coup » | ⏳ PETROLE, PERF2 |
| 27/10 13 h 45 | (essai, pas une citation) | ⏳ Meshy : à votre décision |
| 27/10 13 h 40 | « […] on a l'impression qu'elle tire mais y a aucun effet spécial […] » | ⏳ TIRS (`tirs`) |
| 27/10 13 h | « Pas besoin de créer les comptes, connectez-vous directement avec mon compte Google […] » | ⏳ Impossible ici ; essai sans compte |
| 27/10 12 h 30 | « […] il y a qu'une toute petite partie du gisement de fer qui est prise […] » | ⏳ Capitalisation |
| 27/10 12 h 05 | « Remarque : Le scaling des IA est aussi et surtout dans la maximisation des gisements, de la fonte et des crafts en fait […] » | ⏳ `capitalisation-pnj` |
| 27/10 11 h 30 | « ultracode si nécessaire » | ⏳ `ia-fin-cerveau` |
| 27/10 11 h 25 | « Est-ce que vous avez fait des recherches pour les rendu 3D gratuits sur Internet faits par ia ? » | ⏳ Essai à décider |
| 27/10 10 h 30 | « […] il est peut être possible de générer gratuitement en ligne des modèles 3D à partir de texte fourni […] » | ⏳ À tester (H-3D-1) |
| 27/10 10 h 25 | « (Pour les robots peut être que c’est plus pertinent de trouver des modèles gratuit sur internet […] » | ⏳ Noté |
| 27/10 8 h | « […] avoir un graphe un tout petit peu plus réaliste […] » | ⏳ X3, hors jeu |
| 27/10 7 h 10 | « […] l'idée, c'est de pouvoir créer un véritable cerveau quelqu'un qui généralise […] » | ⏳ IA-G |
| 26/10 22 h 25 | « J'aimerais que vous vous concentriez principalement sur le cerveau des IA […] » | ⏳ IA_ATTENDUS ; IA-V2, IA1-d, IA3-k |
| 25/10 18 h 45 | « ils farment de la pierre et du charbon et ils font rien de plus […] » | ⏳ IA3-c, IA3-f, IA3-b |
| 25/10 18 h 40 | « […] y en a plein qui foutent rien, et plein qui ne vont pas chercher le fer alors qu'ils en ont besoin, pas de parallélisme, pas de coordination, pas de cerveau tout simplement. » | ⏳ IA3-b, IA3-c |
| 25/10 11 h 35 | « je remarque que les IA/pnj sont vraiment lent, avancent pas vite technilogiquement […] » | ⏳ IA3-DIAG |
| 25/10 11 h 25 | « aussi j'ai remarqué que sur les 8 PNJ y en avait pas mal qui faisaient rien […] » | ⏳ IA1-b2 |
| 25/10 10 h | « Le fait que seule la teinte change pour les fours ainsi que les machines à construire et les foreuses, ça c'est complètement à bannir. […] » | ⏳ F2 à F4 (en jeu depuis) |
| 24/10 10 h 25 | « A » (construire IA1 maintenant) | ⏳ IA1 lancé |
| 24/10 8 h 35 | « L'éclat de tir : B mais A sur les dernières aires, 3) A, 4) B […] » | ⏳ À appliquer (§4) |
| 23/10 15 h 05 | « en fait la liste serait beaucoup plus exhaustive […] » | ⏳ Plan |
| 23/10 14 h 50 | « c est valide, les styles sont parfait […] » | ✅ design ; ⏳ intégration (A3-final, 0.4.13) |
| 23/10 12 h 40 | « […] je prefererai un truc genre bigbang ou maitrise cosmique du nean […] » | ⏳ Ère V refaite |
| 23/10 9 h 48 | « […] seul siucis c est que c ezt trop uniforme en therme de palette de cçuleur […] » | ⏳ Palette (passe 5) |
| 23/10 7 h 50 | « […] je pense pas qu'il faille mettre à la poubelle […] » | ⏳ Passe 5 |
| 22/10 7 h 15 | « […] Ça manque de détail en fait les dizaines sont pas mal, je dis pas […] » | ❌ Ouvert ; V3-S |
| 21/10 17 h 26 | « je ne vois QUE un changement de couleur/teinte » | ❌ Ouvert |
| 21/10 14 h 17 | marais « ultra vert » | 👁 Verdict manque (30/10 : biomes « mieux ») |
| 21/10 14 h | « c'est surtout la couleur qui change, ce n'est pas un nouveau design » | 🟨 Corrigé pour les armes |

### Lignes closes (✅ ; détail dans l'archive)

1/11 2 h 30, décider sans votre verdict (« Faite tout sans mon verdict a partir d ici, vous remplacez mon oeil de qualite […] »),
noté ✅ · 31/10, pétrole des factions allumé, clos (0.6.30) · 27/10 21 h 30, leviers de capitalisation, clos (0.6.5) ·
27/10 21 h, six exigences sur les IA, clos (0.6.5) · 27/10 7 h 50, refaire quelques assembleurs, sans objet · 25/10
10 h 50, interface plutôt que commandes, clos (0.4.28) · 24/10 8 h 30, mitrailleuse en jeu appréciée, clos (0.4.10) ·
22/10 16 h 45, une DA par époque, clos (validé le 23/10).

---

## 6. Feuille de route (ordre fixé par vos réponses Q3 et Q5)

En cours et à venir ; plan détaillé du 23/10 et étapes faites : archive, §6.

1. Phase 0, reprise : faite (21/10).
2. Phase V, visuel des 7 familles : 4 en jeu par âge ; détail en D1.
3. Phase C, Compaction ×4 (B1) : pas commencée.
4. Phase X : monnaies des âges 5, 7, 8 et titane en jeu ; X2 non fusionné, X3 hors jeu ; calcul (CALCUL-V2) ;
   robots et unités expérimentales : designs validés (4/11), puissance en cours.
5. Phase I, idle (E3) : pas commencée.
6. Phase IA (C1, C2, C4, C5) : chantier principal depuis le 26/10 (« concentrez-vous là-dessus […] »).

**Les 15 époques** (validées par Q7) : 1 Pionnier, 2 Forge, 3 Vapeur, 4 Pétrole (T2), 5 Volcan (tungstène),
6 Électricité, 7 Cristal (T3), 8 Marais (méthane), 9 Atome, 10 Haute technologie (T4), 11 Titane, 12 Supraconducteurs
(terres rares), 13 Fusion (T5), 14 Orbite, 15 Légende. Ère V renommée le 23/10 pour la mitrailleuse : 13 Antimatière,
14 La Porte, 15 Néant (noms du jeu à changer). Détail des époques : archive, §6.

---

## 7. Reprise dans Claude Code (multi-agent)

Lecture : `CLAUDE.md` §2 (`REPRISE.md` d'abord). Suivi des lots de la session 6 et tâches du 22/10 : archive, §7.

**Règle d'or** : un seul agent intégrateur modifie les fichiers partagés :
- `data.lua`, `control.lua`, `settings.lua`, `info.json` ;
- `shared/levels/config.lua` ;
- les documents.

Chaque lot crée ses **propres fichiers de traduction** (`locale/fr/<lot>.cfg`, `locale/en/<lot>.cfg`) :
Factorio charge tous les `.cfg` du dossier, ce qui évite les conflits de fusion.

**Définition de « terminé »** (d'origine ; allégée le 29/10, preuves renforcées le 5/11) :
1. Bancs hors jeu verts.
2. Étape data sans nouvelle erreur, api_lint à 0.
3. Banc `content` vert en moteur réel.
4. Captures revues (pour ce qui se voit).
5. Mise à jour d'OBJECTIFS.md (état, preuve, date) et de RD_LOG (faits et expériences).
6. Pour le visuel : **votre verdict**.

### Lots actifs ou parqués (dernier état écrit, daté ; état des branches : `REPRISE.md`)

| Date | Lots (branche, commit ou agent) | État |
|---|---|---|
| 7/11 | SPIRALE-FER (effondrement) ; COFFRES (charbonmain) ; tourelles retirées (danger5 ; b142714d dans la 0.6.59) ; fer des coffres de sortie (flux2) ; lots L0 et L1 de TODO_VIDEO (après video-auto, carte-ia) ; titan, icônes des modules (design-titan, design-modules) | ⏳ |
| 5/11 | EXPERIMENTAUX-PUISSANCE (experimentaux, design-attaques) ; PERF3, PERF4 (perf3) ; CERVEAU-CENTRAL ; FOREUSES-THERMIQUES (charbonmain) ; STOCKAGE (munitions) ; COFFRES-JOUEUR, QG-ZONE (qgzone) ; CHAMP-COUVERTURE ; TIROIR (à valider) ; corr-plastique (calculv2) ; ÉTAGE 5 ; PERIMETRE2 G3 repris (`diag-perimetre2` 46e6b0e9) | ⏳ |
| 4/11 | DEPENSES2 (361803ea / 3a50bb3b bloquant ; ddd82445 refusé) ; PANNEAU (`corr-panneau`, `corr-panneau2`) ; DANGER-ACTIF (defense3, puis danger5) ; AGEBLOCAGE (`corr-defaut7` 16f1b3e0 intégré) ; F1-C (`design-laser-f1c` 9fb91918) ; BOURDON-SORTIE, RB16 (robotsjeu) ; QG-GROUPE2 (qggroupe) ; AZURE règle B (0.6.50) ; corr-xp-couts ; graphe (page-dc) | état écrit le 4 ou le 5/11 |
| 3/11 | malls par tapis, ECHELON, DEFENSE (contour des champs) | parqués, absents de main |
| 2/11 | REGARD, CHAMP, FLUX, ENERGIE, DEFENSE, AGES, PARITE, C4 | ⏳ |
| 31/10 et 1/11 | INDUSTRIE (plan) ; C1 centre, C2 demande, C3 extension ; QG des 15 âges ; robots | ⏳ |
| 29/10 | 22 lots lancés (liste : archive, fin du §7) | état non repris |
| 29/10 | réseau, poteaux (2 voies), reconstruction, nids, refill, minage à la main, fortification, CAPI-annulation | parqués sur branche |
| 28/10 | `ia-lots-reponses-dc` (worktrees `centrale`, `kit`, `recon`) ; `ia-optimiseurs-dc` | ⏳ |
| 27/10 | tirs ronde 5 (`tirs` 43aab26), pétrole (`petrole`), PERF2 (`perf2`), X3 (`x3`), robots, 3D ; CAPIB (`capib` 6bbbb05) | gelés sur leurs branches ; CAPIB ⏳ |
| 22/10 | V3-T4 (`worktree-wf_9d38a6df-249-1`, tête `2b18742`) | 🟨 non intégré, attend Q-T4-1 |

Fusionnés avec un reste ouvert (au 27/10 ; archive §7) : IA-G (K10 non tenu), IA-V2 (régression sur une graine),
IA1-b et IA1-b2 (objectif non atteint, contrôles rouges), PERF, AUTO, CAPITAL, IA3-e (éteints), CAPI (non branché) ;
verdict en jeu attendu : F2, F3, F4 ; 👁 : A4, A4-SOCLE, A3-final, F1-B, M1, X1-TITANE, V1 ; F5 à refaire.
