# Centre de commandement = la fusée de départ : brief de design (lot CENTRE-FUSEE, 29/10, premier jet)

**Directive du DC** (OBJECTIFS, 28/10 soir et 29/10 vers 9 h 45) : « c'est la fusée de départ, qu'on doit réparer, puis améliorer (évidemment par défaut on a nos IA, et tout le monde a ses IA, pas besoin de la réparer pour l'avoir) » ; « passer les âges et il aurait un style par âge ». Le centre n'est donc plus un « hôtel de ville » : c'est **une seule fusée**, épave au départ, réparée, puis transformée âge par âge **sans que sa silhouette disparaisse**.
Statut : concept à valider par le DC sur captures (`fo-logs\2026-10-29_NUIT\CENTRE-FUSEE\planches\`). Rien n'est en jeu.

## 1. La forme (silhouette fixe, tous âges)
Fusée à étages **debout sur son aire**, vue du jeu en trois quarts (kit `tools/render/pieces/levels/fusee_e/`) :
- **de bas en haut** : 3 tuyères sous un jupon ; coque basse (porte éclairée au SUD, bande de danger) ; anneau d'inter-étage ; coque haute (3 hublots au sud) ; ogive ; antenne et feu. **4 ailettes en diagonale** (2 visibles à l'avant) sur **4 pieds**.
- **Proportions** (échelle ×1,15 comprise) : fût de 1,7 tuile de large, ailettes sur 3,7 tuiles, hauteur au feu de nez ≈ 7 unités = **≈ 315 px HR (157 px au zoom 1)**, soit 5 tuiles d'écran. Sprite le plus grand : voir RAPPORT (âge 15 : 1 076 × 948 px HR pour 8×8).
- **Emprise** : celle du centre actuel, carrée, **4×4 (âges 1-3), 5×5 (4-6), 6×6 (7-9), 7×7 (10-12), 8×8 (13-15)** (`shared/levels/config.lua`, `L.footprints.command`). La fusée garde la même taille ; **l'aire et les modules grandissent** avec l'emprise. Les ailettes de l'âge 1 dépassent l'aire de 4×4 d'un demi-pied (acceptable, comme les sprites vanilla).
- **Signal de jeu fixe** : porte éclairée au sud (comme tous les bâtiments du mod). La nuit, hublots et porte restent allumés ; la couleur du foyer suit la famille de l'âge (`ages.FOYER`).

## 2. Les états
| État | Image | Emprise |
|---|---|---|
| **Épave (âge 0, départ)** | fusée **couchée** dans un cratère roussi, étage haut éventré (dents de tôle, nervures), ogive arrachée posée à côté, une ailette perdue, tuyère éclatée, braises, fumée figée, bourrelet de roches | 4×4 (sprite plus large, ≈ 6 tuiles) |
| **Réparée (âge 1, Pionnier)** | la même fusée **dressée**, coque jaune de l'épave rapiécée (tôles, bâche, cordage), ailettes et nez rouges, échafaudage de bois, rampe, lanternes, fanion | 4×4 |
| **Âges 2 à 15** | la même fusée, matière et modules de l'âge (§3) | 4 à 8 |
Le jaune de l'épave est celui du vaisseau vanilla : le joueur reconnaît **sa** fusée.

## 3. Comment chaque âge transforme la même fusée
Règles : (a) la **coque** (fût, ailettes, ogive, porte) prend la matière et les bandes de l'âge (`ages.py`, mêmes palettes que mitrailleuse, four, etc.) ; (b) les **modules** se posent **autour** (jamais devant la porte, jamais sur la silhouette) ; (c) un module **nouveau par âge**, les précédents restent (sauf quand l'âge change de matière) ; (d) un détail de **nez** propre à l'ère ; (e) lueur et halo à la couleur de l'âge.

| Ère | Âges | Coque | Modules autour | Nez |
|---|---|---|---|---|
| I | 1 Pionnier, 2 Forge, 3 Vapeur | jaune rapiécé → fer martelé, briques → laiton, cuivre | échafaudage de bois (1), forge et enclume + cheminée (2), chaudière et sifflet de vapeur (3) | fanion, brasero, soupape |
| II | 4 Pétrole, 5 Volcan, 6 Électricité | jaune et noir de chantier → basalte et lave → blanc et bleu | portique d'acier, cuves, torchère (4) ; coulée de lave et cheminée volcanique (5) ; pylônes Tesla (6) | mât radio, braise, arcs bleus |
| III | 7 Cristal, 8 Marais, 9 Atome | cristal violet → vert-de-gris → béton plombé | clusters de cristaux (7) ; pilotis, serre, bocal vert (8) ; dôme de confinement et radôme (9) | cristal, bocal, radôme |
| IV | 10 Haute techno, 11 Titane, 12 Supraconducteurs | acier bleuté → titane clair → givre | paraboles et passerelles (10) ; radar tournant (11) ; anneau supraconducteur givré (12) | parabole, ailerons, anneau |
| V | 13 Antimatière, 14 La Porte, 15 Néant | noir et violet → pierre blanche → noir et or | cuve de confinement et bouteilles (13) ; anneau de la Porte sur pieds (14) ; **disque segmenté en lévitation** et obélisques d'or (15) | éclairs, étoile, sphère noire flottante |
Rendus du premier jet : épave, 1, 4, 8, 15. Les 10 autres âges se déduisent de la table (même code, un module par âge ; 4 à 6 h de rendu pour tout produire à 128 échantillons, comme les autres kits).

## 4. Réparation et amélioration (proposition)
- **Départ** : l'épave est posée à l'emplacement de départ, **un seul exemplaire par camp** (votre équipe et chaque faction). Les IA (équipe du joueur, factions) existent **sans** réparation : elles gardent leur QG, leur stock et leur cerveau actuels (`fo-faction-hq` : 25 000 PV, non minable ; devient l'épave des factions, même sprite teinté de leur couleur).
- **Épave = niveau 0** du centre : rien de plus que maintenant sans centre (les autres familles restent à leur niveau 1 vanilla).
- **Réparer** (une fois, bouton sur la fenêtre de l'épave) : coût proposé = paquets de réparation + matériaux de l'âge 1 (de l'ordre du coût actuel d'un niveau 1 → 2 ; chiffres à fixer en BALANCE_SHEET). Effet : l'épave devient le **centre niveau 1** (fusée dressée) et **débloque le plafond des autres bâtiments** comme le centre actuel (`L.CC_MAX`, niveau du centre = niveau maximal des familles).
- **Améliorer** : le bouton et les paniers actuels (niveaux 1 → 15), un niveau = un âge ; l'image change à chaque niveau (même fusée, modules de l'âge). Aucun démontage : le remplacement garde contenu et réglages (F39).
- **Faction IA** : par défaut leur QG reste l'épave (aucun coût) ; option : il se « répare » visuellement avec leur âge de recherche (voir Q17-f).

## 5. Questions à trancher par le DC (question 17 de `docs/QUESTIONS_DC.md`, option par défaut en gras)
- **a. Forme** : fusée **debout** réparée / couchée comme un vaisseau de l'âge 1 à 15 (épave seule couchée).
- **b. Départ** : **une épave par camp dès le tick 0** / seulement pour le joueur.
- **c. Coût de réparation** : **paquets de réparation + matériaux de l'âge 1** / gratuit.
- **d. Nombre d'images** : **épave + 15 âges** / épave + 5 ères.
- **e. Évolution** : **la fusée ne change pas de taille, les modules grandissent avec l'emprise** / la fusée grandit aussi.
- **f. QG des factions** : **épave fixe, teintée de leur couleur** / se répare avec leur âge.
- **g. Plafond** : **le plafond des autres bâtiments suit le niveau du centre, comme aujourd'hui** / la réparation donne un plafond fixe.
- **h. Tourelles de pied** : **les 2 mitrailleuses d'âge aux coins avant de l'aire (déjà composées par `centre_e/satellites.py`)** / aucune.
