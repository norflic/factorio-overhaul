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
> Dernière mise à jour : 2026-10-21, 18 h, session 6 (Claude Code, orchestrateur) : **lot P0 terminé**,
> suivi des lots au §7. Session 5 close à 17 h 45.
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
| C4 | PvP | ✅ | Attaques contre vous, 5 difficultés, bases défendues attaquées, assaut coordonné et budget A1 **prouvés en moteur réel** (22/10). Écarts mineurs : ordre strict hors modèle nominal, un seul joueur visé |
| **C5** | **Équipes de PNJ organisées, environ 30 par faction** | ❌ | Conception livrée et intégrée (IA1, `docs/EQUIPES_PNJ.md`) ; construction après le visuel (Q18) ; 7 questions Q-IA1 |
| D1 | **Des designs qui changent, pas seulement la couleur** | ❌ niveaux, 🟨 ailleurs | Niveaux : teinte + 1,2 % de taille + socle + lueur. Constat du 21/10, 17 h 26 |
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
  par V2c, prouvés hors jeu seulement)
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
- **Lot V2c (22/10, hors jeu ; moteur réel NON passé)** : amélioration instantanée (Q19 : payée, puis
  remplacement rapide dans le même appel ; plus d'ouvriers, de durées, de bâtiment hors service) ;
  condition du centre (Q16 : refus « cc-families » sans paiement, panneau et interface distante) ;
  chantiers 0.3.0 et 0.4.0 en cours ACHEVÉS au chargement ; coûts recalibrés sur le calendrier X0
  (BALANCE_SHEET §12). Correction après vérification (2 vérificateurs, 13 problèmes) : garde de dress étendue
  au scénario X0 (sonde probe_x refusée), recensement Q16 en cache par force (panneau du centre ouvert :
  0 recensement en 300 ticks ; chaque décision recense en entier), fluid-handling allégée en jeu (barils
  générés), `--calibrate` reproductible (la config livrée est sa sortie), paiement mixte, chantiers à cible
  invalide et rangée mixte testés. Preuves : levels_test 1 459 OK et **11 écarts connus** comptés à part,
  migration_test 29 OK, étape data 0 erreur, api_lint 0 erreur. Diff du banc `content` livré : 63 contrôles
  de niveaux (60 avant), **BILAN attendu 212 OK**.
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
  banc `content` V2c à passer (attendu 212 OK ; les chantiers de V2 avaient été prouvés en moteur réel le
  21/10). **Le panneau n'a jamais été vu à l'écran.**

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
| Q-IA1-1 | Les 30 PNJ doivent-ils donner une « évolution nette, rapide », quitte à raccourcir la partie ? (a) coûts X0 inchangés ; (b) X0 aux époques 1 à 3, coûts relevés ensuite ; (c) recalibrage complet (annule l'accélération) | **Ouverte** (proposition : (a) jusqu'à la mesure du gain réel d'une équipe, puis (a) ou (b) avec vous) | Rythme F1-3 |
| Q-IA1-2 | Montée des effectifs : (1) plafonds de 15, 25 puis 30 (30 PNJ vers 1 h 30) ; (2) 30 dès l'époque 1, seul le stock freine ; (3) départ à 30 | **Ouverte** (proposition : (2) avec (a) ou (b), (1) avec (c)) | C5-1 |
| Q-IA1-3 | Résurrection : une mort coûte 33 à 78 s de production à l'époque 1, moins de 2 s dès l'époque 10. Faut-il qu'une mort pèse davantage plus tard ? | **Ouverte** | C5-5 |
| Q-IA1-4 | Usines : des modules éprouvés (gabarits) plutôt qu'un dessin tuile par tuile, avec la possibilité de dessiner vos propres modules en jeu ? | **Ouverte** (proposition : oui) | C5-3 |
| Q-IA1-5 | Votre équipe en mode « Assisté » par défaut (elle construit dans des zones que vous tracez, première couronne de 8 lots constructible d'office), mode « Autonome » en option ? | **Ouverte** (proposition : oui) | C5-4 |
| Q-IA1-6 | Que pilotent les 5 généralistes ? (1) un domaine chacun ; (2) des parties durables de la base, avec des exécutants nommés ; (3) des projets de bout en bout | **Ouverte** (proposition : 2) | C5-2 |
| Q-IA1-7 | « S'améliorer plus vite » : les rangs des PNJ, ou la vitesse d'amélioration des bâtiments ? En fin de partie, les PNJ gardent-ils un léger avantage de vitesse sur le joueur ? | **Ouverte** (proposition : les rangs ; avantage maintenu) | C5-6 |
| Q-V2c-1 | QX10 (passage du centre ≈ 10 % du budget) n'est tenu qu'aux époques 1 à 4 : la règle de place (le coût tient dans la moitié du coffre du centre) et les monnaies d'aujourd'hui le bornent à 3,35 % puis 0,11 % du budget, et le centre 15 s'atteint en 3 h 27 par le chemin le plus court (52 h 30 au calendrier). Remède : (a) un objet dense propre au passage (le « Codex k » du scénario X0) ; (b) un remplaçant dense provisoire en attendant les monnaies de X0 ; (c) une règle de place assouplie (ou un coffre plus grand) pour le seul centre ; ou (d) accepter l'écart ? | — (ouverte, lot V2c, 22/10) | Recommandation de l'architecte : (a), le Codex k étant déjà prévu par X0 ; d'ici là, QX10 et le rythme de 52 h sont NON CONFORMES (comptés « écarts connus » par levels_test) |
| Q-V2c-2 | Depuis Q19 (amélioration instantanée), l'« Horloge éternelle » (6e ouvrier, 2 sabliers par chantier, QX6) et le « Sablier quantique » (− 25 % de durée de chantier) du scénario X0 n'ont plus d'effet. Que doivent-ils offrir ? (par exemple : remise sur le coût des améliorations, amélioration d'une zone entière d'un coup, rangées de tous les bâtiments) | — (ouverte, lot V2c, 22/10) | Diff de nettoyage de `shared/content/epochs.lua` et de `docs/SCENARIO_EPOQUES.md` proposé (commentaires « sans objet depuis Q19 ») ; l'effet nouveau attend votre réponse |

## 5. Historique des écarts signalés par vous

| Date | Votre constat | Réponse | Statut |
|---|---|---|---|
| 21/10, 14 h | « c'est surtout la couleur qui change, ce n'est pas un nouveau design » | Silhouettes composées (armes spéciales), lueurs, biomes refaits | 🟨 Corrigé pour les armes, pas pour les niveaux |
| 21/10, 14 h 17 | Biomes pas assez différents, marais « ultra vert » | Textures choisies d'après leur couleur mesurée, décor dense | 👁 Votre verdict manque |
| 21/10, 17 h 26 | Niveaux : « je ne vois QUE un changement de couleur/teinte » | Constat exact (E25 rejeté). Critères D1 posés ; phase V | ❌ Ouvert |

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
apport.md | 21/10, 19 h 55 |
| V3 phase 1 : modélisation des 7 familles | ⏳ workflow lancé (aperçus des 30 niveaux, auto-mesure D1 ; rien en jeu avant V2 et V0b) | — | 21/10, 19 h 40 ; relancé à 20 h 35 après l'arrêt de la session (environ 2 000 lignes par famille conservées) |
| V2 Cadre des 15 époques | ✅ intégré (contre-vérification : 1 majeur et 5 mineurs → lot V2b) | Hors jeu : levels 1 228, migration 27 ; étape data 748 prototypes, 0 erreur ; **moteur réel `content` 209 OK, 0 échec** (20 h 39) ; journaux <racine>\fo-logs\2026-10-21_integration_* | 21/10, 20 h 40 |
| X0 Scénario, crafts, branches | ✅ hors jeu ; **scénario approuvé par vous** (Q19 : « le scénario est bien […] je l'aime bien ») ; QX1 à QX9 répondues | « La Caustique d'Érèbe » : `docs/SCENARIO_EPOQUES.md`, données pures `shared/content/epochs.lua`, banc `tests/epochs_test.lua` (16 665 OK, 0 échec ; 3 défauts injectés tous détectés) ; 3 concepteurs, 2 juges, 3 critiques (45 problèmes, dont 19 majeurs ou bloquants, corrigés) ; rien en jeu | 21/10, 21 h 15 |
| IA0 PvP et difficulté | 🟨 intégré, C4-4 prouvé en moteur réel ; A1 non mesuré ; base défendue jamais attaquée → lot IA0b | pvp_test 274, war 92 ; ia0-normal 14 OK, ia0-paisible 11 OK, ia0-difficile 7 OK (20 h 40 à 20 h 45) | 21/10, 20 h 45 |
| IA0b Base défendue attaquée selon la difficulté | ✅ intégré et prouvé en moteur réel | Hors jeu : pvp_test 596 OK. **Moteur réel** (22/10, 0 h 53 à 0 h 55) : ia0-defendue 11 OK (base de 3 tourelles attaquée au tick 96 601) ; ia0-defendue-forte 13 OK (12 tourelles, défense 96 : Écarlate revient à 16, 29, 40 puis 46 soldats) ; ia0-defendue-impitoyable 14 OK (assaut coordonné : Écarlate ouvre au tick 50 700, Ambre et Émeraude le rejoignent) ; journaux fo-logs\2026-10-22_integration_IA0b-V2b_* | 22/10, 0 h 55 |
| V2b Garde de dress complète (config entière et data.raw) + mineurs | ✅ intégré | levels_test 1 325 OK (81 cas de garde, motifs vérifiés ; 4 mutants détectés) ; **moteur réel `content` 209 OK** avec la garde (le vrai chargeur accepte les fichiers de famille chargés sous garde) | 22/10, 0 h 52 |
| V2c Amélioration instantanée (Q19), condition du centre (Q16), recalibrage par les coûts (QX7, QX9, QX10) | ✅ intégré et prouvé en moteur réel ; 2 écarts connus soumis à vous (Q-V2c-1 : part du centre aux époques 5 à 14 ; Q-V2c-2 : centre 15 atteignable en 3 h 27 par le chemin le plus court) | Hors jeu : levels 1 459 OK + 11 écarts connus, migration 29. **Moteur réel** : `content` **212 OK, 0 échec** (22/10, 2 h 43 ; fluid-handling 50 → 2, oil-processing 100 → 4, 170 technologies allégées) | 22/10, 2 h 45 |
| IA1 Conception des équipes de PNJ organisées (C5) | ✅ conception intégrée ; 👁 7 questions à vous poser | 3 concepteurs, 2 juges, 2 critiques (10 majeurs et 14 mineurs corrigés) ; org_test 362 OK ; aucun comportement en jeu | 22/10, 1 h 15 |
| D4m Banc mémoire vidéo et usine géante (D4) | ✅ banc intégré et passé en moteur réel (5 passages, code 0, BILAN 16 OK chacun) | Mémoire vidéo dédiée mesurée : 1,59 à 1,70 Go (haute), 0,67 Go (normale), 0,42 Go (plancher) ; 60 UPS avec 2 588 bâtiments à niveaux à l'écran ; images/s non mesurées ; journaux fo-logs6-10-22_D4m_* ; à refaire avec les sprites V3 | 22/10, 3 h |

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
