# SCENARIO_EPOQUES : la Caustique d'Érèbe (lot X0)

> **Rôle.** Scénario et conception complète des 15 époques et des branches avancées demandées par le
> Directeur Créatif (Q7) : ressources, bâtiments, arbres de fabrication, technologies, Compaction, énergie,
> niveaux, recherche, factions. Les lots X1 à X15, C, V2, I et IA0 s'en servent comme cahier de contenu.
>
> **Statut : PROPOSITION ❔.** Rien n'est implémenté en jeu. Rien n'est décidé sans le Directeur Créatif
> (questions au §9).
>
> **Source unique des chiffres : `shared/content/epochs.lua`** (Lua pur, mêmes noms internes). Les blocs
> encadrés par `<!-- GEN:… -->` sont **générés depuis ce fichier** (`lua5.2 tests/epochs_test.lua
> --write-doc`) et le banc **vérifie leur égalité** avec les données : un écart fait échouer le banc.
>
> **Vérifié hors jeu** par `lua5.2 tests/epochs_test.lua` (21/10, version 2 : résultat et périmètre au §6) :
> 0 recette infranchissable, 0 anachronisme, chaque recette nouvelle débloquée par exactement une
> technologie de son époque, propriétés moteur relues une à une dans la doc 1.1.91.
>
> **Non vérifié** : tout comportement en moteur réel, les débits réels en partie, le rythme ressenti
> (liste au §8). Le rythme F1-3 n'est vérifié que **comme modèle** (budgets, recherche à 35 %), pas en jeu.
>
> Rédigé le 21/10/2026 (session 6, lot X0), **corrigé le 21/10 (version 2)** après relecture : 19 défauts
> majeurs ou bloquants et 26 mineurs (§7).

---

## Sommaire

0. [En une page](#0-en-une-page)
1. [Le scénario](#1-le-scénario) : 1.1 Prémisse · 1.2 Fil narratif · 1.3 Fin de partie · 1.4 Factions et
   difficulté · 1.5 Déchiqueteurs · 1.6 Textes joueur
2. [Les branches avancées (Q7)](#2-les-branches-avancées-q7) : 2.1 Vue d'ensemble · 2.2 Déblocage et Serment ·
   2.3 à 2.6 les quatre branches · 2.7 Convergence
3. [Contenu par époque](#3-contenu-par-époque) : 3.1 Calendrier et monnaies · 3.2 Ressources · 3.3 Bâtiments et
   niveaux · 3.4 Arbres de fabrication · 3.5 Vanilla et existant · 3.6 Bilans · 3.7 Graphe réaliste et minerais
   par âge (lot X3, proposition, pas en jeu)
4. [Compaction, énergie, niveaux, recherche, boucle idle](#4-compaction-énergie-niveaux-recherche-boucle-idle)
5. [Contraintes moteur 1.1.91 et volume](#5-contraintes-moteur-1191-et-volume)
6. [Vérification hors jeu](#6-vérification-hors-jeu)
7. [Corrections](#7-corrections)
8. [Ce qui n'est pas vérifié](#8-ce-qui-nest-pas-vérifié)
9. [Ce qui reste à décider par le Directeur Créatif](#9-ce-qui-reste-à-décider-par-le-directeur-créatif)
10. [Pour l'intégrateur](#10-pour-lintégrateur)

---

## 0. En une page

- **La planète.** Érèbe orbite dans une **caustique de matière noire**. Un **trou noir primordial** capturé
  dans son noyau (« le Cœur ») focalise cette caustique et chauffe le manteau. Toutes les anomalies du jeu en
  découlent : volcan et tungstène, cristaux qui chantent, marais à méthane, matière étrange des cratères,
  faune agressive.
- **Les équipages.** Cinq vaisseaux-usines de la Compagnie (le « Convoi ») ont été dispersés à l'arrivée. Le
  joueur est l'ingénieur de l'Arche-5. Les quatre autres équipages sont les quatre factions IA, chacune avec
  sa **doctrine**.
- **Le but caché**, révélé à l'époque 14 : ancrer sur le Cœur une **Porte**, un trou de ver vers le système
  natal. **Victoire** : ouvrir la Porte d'Érèbe et la tenir 30 min, sous 5 GW, pendant la **Marée du Cœur**.
- **Quatre branches avancées** (Q7) : **A. Matière noire**, **B. Antimatière**, **C. Chronodynamique**,
  **D. Matière étrange**. Chacune est une **branche de recherche** (3 technologies de niveau, §4.4), avec une
  mécanique propre (marée, confinement, dilatation, contagion), un bâtiment et un usage dès le niveau I, et
  une merveille au niveau III. La matière exotique de l'époque 15 en est la convergence.
- **Le joueur en continu** (F1 : « si je veux jouer en continue je veux pouvoir avoir des ressources
  exploitables ») : chaque époque ouvre des ressources (15 ressources de carte, toutes à placement garanti),
  des matériaux et au moins **2 bâtiments de ligne principale** ; les paliers T4 et T5 ont leurs **foreuses
  de concentré** (30 et 120 MU/s par ensemble), et le puits gravitique de la branche A rend le minage infini.
- **Boucle « presque idle »** : Codex et lot de monnaie pour passer le centre, 5 jalons par époque,
  médaille, score de puissance, sabliers (1 par chantier) et dilatation (payée en énergie).
- **Rythme (modèle, non vérifié en jeu)** : époque 1 en 30 min, époque 15 atteinte vers 52,5 h, Porte vers
  59,5 h (F1-3 ; lecture à confirmer, QX7). La recherche de chaque époque consomme 35 % de son budget.
- **Volume (compté par le banc)** : §5.5. En résumé : environ 2 250 prototypes nouveaux, dont environ
  1 470 viennent des **niveaux** (un prototype par niveau, du niveau de naissance au niveau 30).

---

## 1. Le scénario

### 1.1 Prémisse : trois faits physiques, cachés au début, expliquent tout le jeu

1. **Érèbe traverse une caustique de matière noire.**
   - Les courants de matière noire du halo galactique se replient en surfaces très denses (hypothèse réelle
     des « caustiques » de Sikivie). Érèbe orbite dans l'une d'elles.
   - Dans cet univers, cette matière noire est un **champ d'axions froid**, faiblement couplé aux réseaux
     cristallins et aux champs magnétiques intenses (ce que cherchent les vrais haloscopes, comme ADMX).
2. **Le noyau abrite un trou noir primordial**, « le Cœur ».
   - Il a la masse d'un astéroïde et il est plus petit qu'un atome (la capture d'un tel objet par une
     planète est une hypothèse publiée).
   - Il focalise la caustique. L'accrétion et l'annihilation de matière noire capturée chauffent le manteau.
3. **La planète est donc anormale** :
   - volcanisme 40 fois trop actif : cendres, tungstène, fumerolles riches en hélium primordial ;
   - cristaux de résonance qui « chantent » au passage du vent d'axions ;
   - biosphère qui vit du méthane : le marais ;
   - faune nourrie par la chaleur du Cœur : les déchiqueteurs ;
   - dans les cratères, les reliques d'une **météorite de matière étrange** que le trou noir a attirée.

**Le Convoi.** Cinq vaisseaux-usines de la Compagnie partent exploiter « l'anomalie Érèbe ». À l'entrée dans
la caustique, une onde de marée gravitationnelle les disperse. L'Arche-5 s'écrase (l'épave du scénario
« freeplay ») ; son noyau récupéré devient le **centre de commandement**. Les quatre autres équipages
survivent ailleurs et deviennent les quatre factions.

**Le secret** (Codex XIV, archives orbitales de l'Arche). Le Convoi était une expédition vers le Cœur, pour
y ancrer une **Porte**, un trou de ver traversable stabilisé par de la matière exotique à densité d'énergie
négative (modèle de Morris et Thorne, 1988), vers le système natal à 40 années-lumière. Sans la Porte,
personne ne rentre. Celui qui l'ouvre tient Érèbe.

### 1.2 Fil narratif des 15 époques (liste d'OBJECTIFS §6, validée par Q7)

Quatre actes : survivre (époques 1 à 4), la planète est étrange (5 à 9), dompter les nouvelles physiques
(10 à 13), la vérité et la Porte (14 et 15). Chaque époque se ferme par un **Codex** (objet fabriqué, livré
au centre avec le lot de monnaie) qui porte le récit ; son texte complet est au §1.6. Les bâtiments de chaque
époque sont au §3.3.

<!-- GEN:narrative -->
| Ép. | Thème | Acte | Ce que l'on découvre (Codex de l'époque) | Pression |
|---|---|---|---|---|
| 1 | Pionnier | 1 | Sur la carte, des anomalies gravimétriques qu'aucun instrument ne lit. | délai de grâce, petits déchiqueteurs |
| 2 | Forge | 1 | Les balises des quatre autres équipages du Convoi : ils ont survécu. | premières patrouilles des factions |
| 3 | Vapeur | 1 | La planète rayonne plus de chaleur qu'elle n'en reçoit. | raids de déchiqueteurs plus gros |
| 4 | Pétrole | 1 | Le pétrole d'Érèbe est trop jeune : il se forme encore, chauffé d'en dessous. | premières attaques organisées des factions (Normal) |
| 5 | Volcan | 2 | Le flux géothermique est 40 fois trop fort : quelque chose chauffe le manteau. | blindés et ignés (cendres) |
| 6 | Électricité | 2 | Les orages magnétiques suivent les anomalies. | foudroyants attirés par les réseaux |
| 7 | Cristal | 2 | Les cristaux chantent sans source : la Ligue Azur publie l'hypothèse de la Caustique (A-I). | foudroyants renforcés |
| 8 | Marais | 2 | La vie d'Érèbe digère le méthane du sous-sol chauffé. | couvées |
| 9 | Atome | 2 | Le cuivre irradié émet des positons : premier piège d'antimatière (B-I). | l'Ordre Écarlate cherche l'arme absolue |
| 10 | Haute technologie | 3 | Un réseau de cristal gravé oscille sans énergie : premier cristal temporel (C-I). | exo-fantassins laser des factions |
| 11 | Titane | 3 | La brèche des cratères contient des inclusions trop denses : de la matière étrange (D-I). | nids de famille plus loin, plus gros |
| 12 | Supraconducteurs | 3 | L'haloscope capte la matière noire ; la Caustique a une marée (A-II). | les factions passent à l'époque 12 selon la difficulté |
| 13 | Fusion | 3 | Antimatière en quantité, strangelets (B-II, D-II). Le Serment : le joueur choisit sa doctrine. | la rivale jurée attaque davantage |
| 14 | Orbite | 4 | Révélation : le Convoi venait ouvrir une Porte sur le trou noir du Cœur. | pluies de météorites, course à la Porte des factions |
| 15 | Légende | 4 | Le Cœur s'éveille : failles, primordiaux, Marée du Cœur. | Marée du Cœur (siège final) |
<!-- /GEN:narrative -->

**Écarts avec le tableau §6 d'OBJECTIFS, déclarés.**
- **Époque 11 « structures légères »** : tenue. Trois bâtiments de ligne principale en titane s'ajoutent au
  réacteur de Kroll : pylône léger (sous-station 18 × 18, fil 32), bras léger en titane, tour d'observation.
- **Merveilles** : le §6 les place à l'époque 15. Ici, la merveille de la doctrine jurée s'ouvre à
  l'époque 14 (Serment), les trois autres à l'époque 15. C'est un **écart voulu** (récompense du Serment),
  soumis au Directeur Créatif avec QX2.

### 1.3 Fin de partie
- **La Porte d'Érèbe** est un `rocket-silo` réhabillé de **10×10** (Q9 : « une usine de 10x10 »). Le silo
  offre nativement la progression par « pièces » et le lancement (`fixed_recipe`, `rocket_parts_required`,
  vérifiés ; « Recipe products are ignored » : le segment n'est qu'un compteur, `counter_only`).
  - Ses 100 « pièces » sont des **segments d'anneau**, posés sous **50 MW** (consommation de fabrication du
    silo). La « charge utile » est la **Clé de phase**.
- **Charge de 30 minutes sous assaut : la Marée du Cœur.**
  - À `on_rocket_launched` avec la Clé, le script crée sous la Porte une **interface électrique cachée** de
    **5 GW** (`power_usage`, écriture vérifiée) et lit son `energy` toutes les 60 ticks : la charge avance
    si l'énergie est là, elle est **suspendue** sinon. Il faut 3 réacteurs à annihilation ou l'équivalent.
  - Le directeur de la défense de tours existant (`script/td/director.lua`) lance 12 vagues jusqu'aux
    primordiaux, un boss toutes les 3 vagues. En Difficile et en Impitoyable, les factions convergent aussi.
  - Si la Porte tient 30 min : **victoire** (`LuaGameScript.set_game_state`, vérifié). La victoire vanilla
    au satellite est coupée : `remote.call("silo_script", "set_no_victory", true)` (vérifié,
    `data/core/lualib/silo-script.lua`, l. 57).
  - **Échec** : si la charge n'aboutit pas alors que la Porte est debout, la Clé est perdue et le silo
    retrouve ses 100 segments (`LuaEntity.rocket_parts = 100`, écriture vérifiée) : on relance avec une
    nouvelle Clé. Si la Porte est **détruite**, tout est perdu.
- **À l'époque 15** (avant la victoire) : niveaux 29 et 30 (Q6 : centre au niveau 15) et maîtrises des
  doctrines non jurées. **Après la victoire, mode « Légende »** : 8 recherches infinies au pack exotique et le
  score de puissance ; on peut continuer à jouer.
- **Défaite ❔ (QX3)** : en Difficile et en Impitoyable, une faction qui ouvre sa propre Porte avant vous gagne
  (règles au §1.4).

### 1.4 Factions IA et difficulté (Q4 : « oui (et différents niveaux de difficulté) »)

| Faction (personnalité existante) | Doctrine | Pourquoi | Élite (époque 13 et après) | Rivale jurée |
|---|---|---|---|---|
| Ordre Écarlate (conquérant) | **B. Antimatière** | l'arme absolue | Lancier d'annihilation | Dynastie Ambre |
| Ligue Azur (technocrate) | **A. Matière noire** | comprendre la Caustique | Arpenteur gravitique | Consortium Émeraude |
| Consortium Émeraude (bâtisseur) | **D. Matière étrange** | tout transmuter, tout posséder | Colosse étrange | Ligue Azur |
| Dynastie Ambre (équilibrée) | **C. Chronodynamique** | une dynastie veut l'éternité | Spectre chronique | Ordre Écarlate |

- **Le Serment** (époque 13) change les relations : la faction de même doctrine dirige contre vous 0,5 fois
  sa part de forces (cessez-le-feu possible) ; sa rivale jurée 1,5 fois. Faisable : `LuaForce.set_cease_fire`
  et `set_friend` existent (vérifié).
- **Une seule source pour la difficulté : le lot IA0.** `shared/faction/config.lua` (F.pvp_order, F.pvp) fixe
  la grâce, l'intervalle minimal entre deux attaques, la part des forces dirigée contre vous, la taille des
  attaques et la réserve, et `settings/faction.lua` en fait le réglage de partie. **X0 n'y ajoute que ce qui
  touche aux époques**, avec les **mêmes clés** (le banc relit F.pvp_order et compare) :

<!-- GEN:difficulty -->
| Clé (F.pvp_order) | Difficulté | Évolution | Écart d'époque (plafond) | Crédit d'archive | Chantier de Porte |
|---|---|---|---|---|---|
| `peaceful` | Paisible | -0,05 | -2 | ×0,6 | non |
| `easy` | Facile | -0,05 | -1 | ×0,7 | non |
| `normal` | Normal | 0 | 0 | ×0,85 | non |
| `hard` | Difficile | +0,03 | 0 | ×1,3 | 9 h |
| `merciless` | Impitoyable | +0,06 | +1 | ×1,6 | 6 h |
<!-- /GEN:difficulty -->

- **Époques des factions : économie d'archive hybride** (seuils corrigés).
  - Honnêteté (C2-6) : le cerveau d'équipe réel stagne aujourd'hui à la recherche 3 (H-E1, pas de pétrole).
    Lui faire jouer les chaînes des époques 4 à 15 est hors de portée raisonnable.
  - Le **minage réel** des avant-postes (plaques livrées au QG, déjà mesurées) fait progresser l'époque de la
    faction : crédit = MU livrées × crédit de difficulté. Le **seuil de l'époque k suit le calendrier** :
    2,5 MU/s (débit d'une faction mesuré en moteur réel, 1,4 à 3,2 MU/s à 60 min, BALANCE_SHEET §10) × 3 600
    × l'heure à laquelle le joueur nominal atteint k : **4 500 MU** pour l'époque 2, **202 500** pour la 10,
    **472 500** pour la 15. L'époque est plafonnée par la vôtre plus l'écart.
  - Contrôlé par le banc : en Normal, une faction au débit mesuré atteint chaque époque à 25 % près de l'heure
    du joueur nominal (environ 18 % après lui), et son plafond ne la bloque jamais (0 % du temps, 20 % permis).
  - À chaque époque gagnée, la faction reçoit l'**équipement de l'époque** : c'est encore une imitation pour
    ce qui dépasse l'époque 4 ; à écrire tel quel dans OBJECTIFS C2.
  - Unités d'époque (`X.faction_units`) : fusilier, mitrailleur et grenadier (existants), lance-flammes (8),
    exo-fantassin laser (10), mécha léger (13), plus les 4 élites de doctrine.
- **Course à la Porte** (Difficile, Impitoyable ; QX3).
  - **Départ** : le chantier de Porte d'une faction commence quand **vous atteignez l'époque 15** (centre au
    niveau 15). Il est visible sur la carte.
  - **Durée** : 9 h en Difficile (plus que les 7 h de votre époque 15 : le joueur au rythme nominal ouvre la
    sienne 2 h avant), **6 h en Impitoyable** (voulu : la faction finit 1 h avant le joueur nominal ; il faut
    aller plus vite ou raser son chantier).
  - **Raid** : détruire le chantier le **remet à zéro** et vous rend 30 % des matériaux investis (façon Clash
    of Clans).

### 1.5 Les déchiqueteurs : la faune du Cœur
- La faune est nourrie par la chaleur du Cœur. Familles existantes liées à un biome et à une époque :
  blindés et ignés (cendres, époque 5), couvées (marais, 8), foudroyants (champs électriques, 6 et 7).
- **Fenêtre d'évolution bornée par votre époque** (`X.evolution_window`) : une fois par minute, le script
  ramène `LuaForce.evolution_factor` (écriture vérifiée) dans la fenêtre de votre époque, décalée selon la
  difficulté : de 0 à 0,10 à l'époque 1 jusqu'à 0,85 à 1,00 à l'époque 15. C'est l'équivalent de
  l'appariement par hôtel de ville de Clash of Clans. La même borne plafonne le palier des vagues de la
  défense de tours (`X.td_max_tier` : palier 2 aux époques 1-2, … primordiaux à l'époque 13).
- **Perturbation** (`X.perturbation`) : les productions exotiques poussent l'évolution vers le haut de la
  fenêtre, sans jamais la dépasser : +0,00005 par condensat d'axions, piège d'antihydrogène ou strangelet ;
  +0,0002 par matière exotique stabilisée.
- **Pollution native** : les bâtiments exotiques polluent fortement et attirent donc les attaques.
- **Butin** (`EntityWithHealthPrototype.loot`, vérifié) : un **tissu de déchiqueteur**, de 2 % (petit) à 8 %
  (primordial) par unité, 5 à 20 par nid. Il sert d'inoculum à l'époque 8 et de **méthane de digesteur** :
  la défense devient productive.
- **Gardiens** : à l'époque 15, des nids **primordiaux** entourent les failles du Cœur.

### 1.6 Textes vus par le joueur (FR et EN)

<!-- GEN:story -->
| Moment | Français | English |
|---|---|---|
| Introduction | L'Arche-5 s'est écrasée sur Érèbe. Son noyau devient votre centre de commandement : nourrissez-le, et il vous fera traverser les époques. | The Ark-5 has crashed on Erebus. Its core becomes your command center: feed it, and it will carry you through the epochs. |
| Codex I (Pionnier) | Jour 1. L'Arche-5 est une épave ; son noyau tient encore. Les gravimètres de bord affichent des anomalies que rien n'explique : la chute les aurait-elle faussés ? | Day 1. The Ark-5 is a wreck; its core still holds. The onboard gravimeters show anomalies nothing can explain: did the crash damage them? |
| Codex II (Forge) | Quatre balises répondent sur la fréquence du Convoi. Les autres équipages ont survécu, et ils s'arment. | Four beacons answer on the Convoy frequency. The other crews survived, and they are arming. |
| Codex III (Vapeur) | Le bilan thermique ne ferme pas : Érèbe rayonne plus de chaleur que son étoile ne lui en donne. Quelque chose chauffe la planète par en dessous. | The heat balance does not close: Erebus radiates more heat than its star gives it. Something heats the planet from below. |
| Codex IV (Pétrole) | Le pétrole d'Érèbe est jeune : il se forme encore, à quelques kilomètres sous nos pieds. Les géologues de l'Arche refusent d'y croire. | Erebus oil is young: it is still forming, a few kilometres beneath our feet. The Ark's geologists refuse to believe it. |
| Codex V (Volcan) | Le flux géothermique est quarante fois trop fort. Le manteau est chauffé de l'intérieur, comme par un cœur. | The geothermal flux is forty times too strong. The mantle is heated from within, as if by a heart. |
| Codex VI (Électricité) | Les orages magnétiques ne suivent pas les vents : ils suivent les anomalies gravimétriques. Nos réseaux les attirent. | Magnetic storms do not follow the winds: they follow the gravimetric anomalies. Our grids attract them. |
| Codex VII (Cristal) | Les cristaux chantent sans source. La Ligue Azur publie une hypothèse : Érèbe traverse une caustique de matière noire. | The crystals sing with no source. The Azure League publishes a hypothesis: Erebus is crossing a dark matter caustic. |
| Codex VIII (Marais) | La vie d'Érèbe respire le méthane qu'exhale un sous-sol chauffé. Tout ici se nourrit de la même chaleur. | Erebus life breathes the methane exhaled by a heated subsoil. Everything here feeds on the same heat. |
| Codex IX (Atome) | Le cuivre irradié émet des positons : nous avons piégé notre premier grain d'antimatière. L'Ordre Écarlate y voit déjà une arme. | Irradiated copper emits positrons: we have trapped our first speck of antimatter. The Scarlet Order already sees a weapon in it. |
| Codex X (Haute technologie) | Un réseau de cristal gravé oscille sans énergie : un cristal temporel. La Dynastie Ambre y voit l'éternité. | An etched crystal lattice oscillates with no power: a time crystal. The Amber Dynasty sees eternity in it. |
| Codex XI (Titane) | Les inclusions de la brèche sont bien trop denses : de la matière étrange, venue d'une météorite que quelque chose a attirée. Le Consortium Émeraude veut tout transmuter. | The breccia inclusions are far too dense: strange matter, from a meteorite something pulled in. The Emerald Consortium wants to transmute everything. |
| Codex XII (Supraconducteurs) | L'haloscope capte enfin le champ d'axions. La Caustique a une marée, et cette marée suit la rotation du noyau. | The haloscope finally detects the axion field. The Caustic has a tide, and that tide follows the rotation of the core. |
| Codex XIII (Fusion) | Antimatière en quantité, strangelets en cuve : la Caustique ne tolère qu'une seule grande perturbation. Il faut choisir sa doctrine : le Serment. | Antimatter in bulk, strangelets in vats: the Caustic tolerates only one great disturbance. A doctrine must be chosen: the Oath. |
| Codex XIV (Orbite) | Les archives orbitales de l'Arche parlent enfin : le Convoi venait ancrer une Porte sur le trou noir du Cœur. Sans elle, personne ne rentre. | The Ark's orbital archives finally speak: the Convoy came to anchor a Gate on the black hole at the Core. Without it, no one goes home. |
| Victoire | La Porte tient. Le trou de ver s'ouvre sur le système natal, à quarante années-lumière. Érèbe est à vous. | The Gate holds. The wormhole opens onto the home system, forty light-years away. Erebus is yours. |
| Défaite (QX3) | Une autre Porte s'est ouverte avant la vôtre. Le Convoi rentrera sans vous. | Another Gate opened before yours. The Convoy will go home without you. |

Canal : message de LuaGameScript.show_message_dialog (introduction, Codex livré) ; description de l'objet Codex ; écran de fin de set_game_state.
<!-- /GEN:story -->

---

## 2. Les branches avancées (Q7)

### 2.1 Vue d'ensemble

<!-- GEN:branches -->
| | A. Matière noire | B. Antimatière | C. Chronodynamique | D. Matière étrange |
|---|---|---|---|---|
| Doctrine de | Ligue Azur | Ordre Écarlate | Dynastie Ambre | Consortium Émeraude |
| Niveaux I, II, III (époque) | 7, 12, 14 (15 sans Serment) | 9, 13, 14 (15 sans Serment) | 10, 11, 14 (15 sans Serment) | 11, 13, 14 (15 sans Serment) |
| Mécanique propre | marée : rendement des veines de 50 à 150 % sur le cycle jour-nuit | confinement : 5 s sans courant et les pièges pleins s'annihilent | dilatation : accélère UNE machine voisine contre une consommation accrue ; un sablier par chantier | croissance autocatalytique ; une cuve qui déborde, manque de courant ou s'entasse contamine le sol |
| Ce qu'elle rapporte | minage infini n'importe où (puits gravitique), carte gravimétrique, bouclier de marée, Observatoire | énergie de fin de partie, grenade à positons, obus et lance d'annihilation, sonde profonde, Bastion | vitesse contre énergie, chantiers raccourcis (plafonnés), coffres intriqués (1 case, 2 à 4 paires), 6e ouvrier (QX6) | transmutation de la pierre en minerais rares, puits des déchets, munitions à inclusion, murs et armure, Monolithe |
| Coût et risque (chiffrés) | haloscope 20 MW + 2 condenseurs 15 MW ; hélium liquide ; la marée oblige à surconstruire (rendement 50 % à midi) | synchrotron 150 MW ; 5 s sans courant : les pièges pleins explosent (2 000 dégâts chacun, rayon 8) | chambre 5 MW (II) ou 10 MW (III) + consommation de la machine ×2 (II) ou ×3,5 (III) ; un cristal stable déphasé toutes les 120 s ; sans courant, la chambre perd son cristal (rupture de phase) | compresseur 100 MW, plasma ; contagion : sol étrange et 50 dégâts/s autour d'une cuve pleine 60 s, privée de courant 10 s, ou à plus de 8 cuves dans un rayon de 16 |
| Donnée de recherche | Relevé gravimétrique | Données d'annihilation | Données chronométriques | Données hadroniques |
| Produit exigé par la Porte | Condensat d'axions | Piège d'antihydrogène | Cristal temporel stable | Plaque étrange |
| Merveille | Observatoire de la Caustique | Bastion d'annihilation | Horloge éternelle | Monolithe étrange |
<!-- /GEN:branches -->

Appui scientifique réel : caustiques (Sikivie) et haloscopes à axions (ADMX) pour A ; cuivre 64 émetteur β+,
pièges de Penning et antihydrogène (CERN) pour B ; cristaux temporels sur processeur quantique (2021-2022)
pour C ; hypothèse de la matière étrange (Witten, 1984) pour D.

### 2.2 Déblocage, Serment, cumul
- **Une branche est une branche de recherche** : chaque niveau est une technologie (§4.4, `X.technologies`),
  qui débloque ses recettes, son bâtiment et son usage. Niveau I : payé avec la fenêtre de packs de l'époque.
  Niveaux II et III : payés avec la **donnée de la branche** et le pack de l'époque.
- **Verrou d'époque natif** : une technologie cachée `fo-epoch-k` (`enabled = false`) passe en
  `researched = true` (écriture vérifiée) quand le centre atteint le niveau k ; elle est prérequis de toutes
  les technologies de l'époque k.
- **Niveaux I et II : cumulables.** **Niveau III : le Serment** (centre au niveau 13). Choix **irréversible**
  d'une doctrine. Sa maîtrise s'ouvre à l'époque 14 ; les trois autres à l'époque 15 (`LuaTechnology.enabled`,
  écriture vérifiée, réservé à cet usage). Récit : la Caustique ne supporte qu'une seule « grande
  perturbation » tant que le Cœur n'est pas ancré.
- **La Porte exige les quatre branches au niveau II** : chaque segment d'anneau consomme 1 condensat
  d'axions (A), 1 piège d'antihydrogène (B), 1 cristal temporel stable (C) et 2 plaques étranges (D).
- **Une branche ne bloque jamais la ligne principale des époques 1 à 14** (contrôlé par le banc).

### 2.3 A. Matière noire (gravitique)
- **Récit.** À l'époque 7, les cristaux taillés vibrent sans source près des anomalies gravimétriques. À
  l'époque 12, l'haloscope capte le champ d'axions des **veines de caustique**. Dans une **cavité de
  résonance**, le champ se condense.
- **Niveau I (époque 7)** : résonateur de caustique (actif à 64 tuiles au plus d'une veine), relevé
  gravimétrique, et un usage hors recherche : la **carte gravimétrique** (révèle les veines et les gisements
  garantis à 8 chunks).
- **Veines** : 2 veines « visibles mais illisibles » posées au début de partie (80 à 200 tuiles), puis une
  pour 20 à 25 chunks balayés (`on_sector_scanned`, vérifié ; hachage de la graine et du chunk).
- **Mécanique : la marée.** Veines infinies dont le rendement vaut `amount / normal`. Table de 24 phases sans
  trigonométrie (`X.tide`) : 0,5 à midi, 1,5 à minuit, moyenne 1. **Coût de script corrigé** : seules les
  veines **sous un haloscope** sont mises à jour (registre tenu à la pose et au retrait), en tourniquet sur
  600 ticks, un lot par tick : O(tuiles sous haloscope ÷ 600) par tick, sans pic.
- **Ce qu'elle rapporte.**
  - **Puits gravitique** (II) : se pose n'importe où. Une interface propre au puits (`on_gui_opened`) fait
    choisir le minerai ; le script crée dessous 25 tuiles de la **remontée profonde** correspondante (une
    ressource par minerai, car une ressource 1.1 n'a qu'un produit), puis appelle
    `LuaEntity.update_connections()` (vérifié). Il brûle 1 condensat par minute (2 MW, la cavité est rendue)
    et sort **1 concentré ρ8/s, soit 8 MU/s**, à l'infini : la réponse au « jouer en continue » (F1).
  - **Puits gravitique II** (III) : 4 concentrés ρ8/s (32 MU/s), et seul à miner les remontées rares
    (tungstène, ilménite, monazite : catégorie `fo-deep-rare`).
  - **Bouclier de marée** (III) : −70 % de vitesse aux ennemis dans un rayon de 30.
  - **Observatoire de la Caustique** (merveille) : +20 % de productivité minière, marée bloquée à 150 %.

### 2.4 B. Antimatière (annihilation)
- **Récit.** À l'époque 9, du cuivre exposé au flux de neutrons d'un réacteur (cuivre 64, émetteur β+ réel)
  fournit des positons, pris dans des **pièges magnétiques**. À l'époque 13, un synchrotron alimenté par la
  fusion produit des antiprotons, recombinés en **antihydrogène**.
- **Note de physique honnête.** Dans notre univers, l'antimatière ne serait qu'un stockage. Sur Érèbe, le
  champ d'axions abaisse le seuil de création de paires : c'est la seule raison du rendement positif. C'est
  une **fiction déclarée** (liste blanche d'énergie du banc ; variante au §9, QX4).
- **Niveau I (époque 9)** : irradiateur et modérateur, et un usage hors recherche : la **grenade à positons**.
- **Mécanique : le confinement.** Un bâtiment qui contient des pièges pleins (modérateur, synchrotron,
  recombineur, réacteur à annihilation) doit rester alimenté : 5 s sans énergie et ses pièges s'annihilent
  (2 000 dégâts par piège, rayon 8). Le réacteur à annihilation est un réacteur à brûleur, sans entrée
  électrique : son confinement passe par une **interface électrique cachée de 20 MW** posée dessous, dont on
  lit l'énergie. Sa destruction à chaud passe par le `meltdown_action` natif (déclenché au-delà de 90 % de sa
  température maximale, désormais fixée à 5 000 °C).
- **Chiffres.** Synchrotron : 1 piège à antiprotons toutes les 30 s pour 150 MW. Piège d'antihydrogène :
  50 GJ. Le **réacteur à annihilation** (III, **10×10**, 2 GW de chaleur, `neighbour_bonus = 0`) en brûle 1
  toutes les 25 s ; sa chaleur va à **10 injecteurs de plasma** posés autour (32 connexions au plus) et à
  10 turbines MHD.
- **Ce qu'elle rapporte.** Énergie de fin de partie ; **fusion catalysée** (corrigée : +40 GJ par piège, moins
  que les 50 GJ du réacteur à annihilation : la maîtrise reste la meilleure) ; **obus d'annihilation** ;
  **lance d'annihilation** (III) ; **sonde profonde** (III) ; **Bastion d'annihilation** (merveille : +30 % de
  dégâts des munitions explosives et d'annihilation, `LuaForce.set_ammo_damage_modifier`, vérifié).

### 2.5 C. Chronodynamique (cristaux temporels)
- **Récit.** À l'époque 10, un réseau de cristal gravé sur silicium oscille sans énergie : un cristal temporel
  instable. À l'époque 11, verrouillé en phase par des oscillateurs, il se stabilise ; à l'époque 12,
  l'hélium liquide double la cadence. Dans cet univers, il peut « prêter » du temps.
- **Niveau I (époque 10)** : **banc de phase** (bâtiment) et un usage hors recherche : le **radar à réseau
  phasé à horloge de phase**, une variante qui économise 6 processeurs et 20 oscillateurs.
- **Production : une boucle de phase.** Le cristal se déphase en travaillant : la chambre rend un cristal
  instable toutes les **120 s** ; il faut le restabiliser.
- **Mécanique : la dilatation (corrigée).** C'est la branche « presque idle » (E3), mais elle se paie.
  - **Chambre de dilatation** (II) : +100 % de vitesse et **+100 % de consommation** à **une seule machine**
    voisine ; chambre II (III) : +200 % de vitesse, **+250 % de consommation**. L'énergie par produit ne
    baisse jamais. Ni foreuses, ni laboratoires, ni bâtiments à confinement.
  - Technique : une balise cachée créée **une fois** à la pose de la chambre (énergie nulle, sans collision),
    détruite au retrait ; l'effet se coupe ou se rend en retirant ou en insérant son module caché, avec une
    hystérésis (coupure après 3 contrôles successifs non « working ») ; `LuaEntity.speed_bonus` est en
    lecture seule (vérifié).
  - **Sablier quantique** (II) : **1 par fabrication**, avec 10 plaques de titane (la monnaie de l'époque) dans
    son coût ; **au plus 1 par chantier** (2 avec l'Horloge), qui retire 25 % de la durée initiale (10 min au
    moins). **Sans objet depuis Q19** (amélioration instantanée, lot V2c) : effet nouveau à décider (Q-V2c-2).
  - **Coffres intriqués** (II) : **1 case**, **2 paires** par force au niveau II, 4 au niveau III ; chaque
    paire active tire 20 MW. Le moteur n'expose pas les transferts : un prélèvement par objet est impossible
    à mesurer à bas coût, d'où un prélèvement constant. Le tapis intriqué reste écarté.
  - **Horloge éternelle** (merveille III) : 6e ouvrier (QX6), 2 sabliers par chantier, laboratoires +50 %.
    **Depuis Q19, seuls les laboratoires +50 % gardent un sens** ; le reste attend Q-V2c-2.
- **Risque** : la **rupture de phase** (une chambre privée de courant perd son cristal stable) et le coût
  énergétique de la dilatation.

### 2.6 D. Matière étrange
- **Récit.** À l'époque 11, la brèche d'impact des cratères livre de rares **inclusions étranges** (0,5 %),
  reliques d'une météorite de matière étrange. À l'époque 13, comprimée dans du plasma, une inclusion
  « germe » en strangelet confiné. Selon Witten, la matière étrange serait l'état le plus stable de la
  matière : un strangelet convertit la matière ordinaire qu'il touche.
- **Niveau I (époque 11)** : **trieur d'inclusions** (bâtiment) et un usage hors recherche : le **chargeur à
  inclusion** (dégâts de l'uranium +20 %).
- **Production : croissance autocatalytique.** 2 strangelets + 10 pierres + 10 sables → 3 strangelets
  (30 s, catalyseur 2). **Puits universel des déchets** : 1 strangelet + 32 X → 2 strangelets, pour
  X = laitier, sable, pierre, colis vitrifiés, sel usé.
- **Mécanique : la contagion (renforcée).** Une cuve dont la sortie reste pleine 60 s, **privée de courant
  10 s**, ou **entourée de plus de 8 cuves dans un rayon de 16**, déborde : le sol devient **sol étrange**
  (rayon +1 par minute, 12 au plus) et les bâtiments y prennent 50 dégâts/s.
- **Ce qu'elle rapporte.** **Transmutation (corrigée)** : 40 pierres → 20 minerais rares en **5 s** au
  transmutateur de **15 MW** (3,75 MJ par minerai au lieu de 50 ; tungstène, ilménite, monazite, uranium). Le
  **cristal de résonance est retiré des cibles** : combustible de 20 MJ, il aurait rendu 400 MJ pour 75 MJ
  investis (trouvé par le banc). **Plaque étrange** ; **mur étrange** (12 000 PV) ; **mur de neutronium**
  (III) ; **armure étrange** (III) ; **Monolithe étrange** (merveille : sa pose active, par
  `LuaRecipe.enabled`, 4 recettes de **transmutation résonante** qui rendent 40 minerais au lieu de 20).

### 2.7 Convergence : la matière exotique (époque 15)
- Le Cœur s'éveille : le script crée 3 à 5 **failles du Cœur** (ressources fluides infinies), entre 600 et
  1 200 tuiles du départ, gardées par des primordiaux.
- L'**ancre de faille** (qui consomme les quatre branches au niveau II) y capte la **matière exotique brute**
  en injectant du plasma. Le plasma voyage **en baril** (il retombe à 15 °C et perd sa chaleur, mais la
  faille ne l'exige pas) : une centrale à fusion n'est pas nécessaire à chaque faille. La matière exotique
  brute, elle, reste **sans baril**.
- **Repli conçu** (si la foreuse à entrée et sortie de fluide échoue en moteur réel, lot X15) : une machine
  7×7 à recette fixe (20 plasmas → 5 matières brutes/s), rendue active (`LuaEntity.active`, écriture
  vérifiée) seulement posée sur une faille, la faille devenant décorative (`X.fallback_recipes`).
- Le **stabilisateur de Casimir** fixe la matière brute dans des cavités à miroirs d'iridium (effet Casimir),
  la cavité servant de catalyseur. La matière exotique stabilisée nourrit la Porte, la Clé et le pack
  exotique (1 matière pour 20 packs : la recherche de l'époque 15 tient dans le débit de 3 failles).

---

## 3. Contenu par époque

### 3.1 Calendrier et monnaies (F1-3, Q5, Q6)

- Durée de l'époque k : 0,5 h × k, plafonnée à 7 h : **59,5 h** pour les 15 époques. Depuis le lot V2c, la
  config des niveaux recopie ce calendrier (`L.target`) : une seule source (QX10) ; la courbe propre de V2
  (0,5 × 1,261^(k−1) h) n'existe plus. Les coûts des niveaux sont calibrés pour que la base de référence
  complète tienne ce calendrier ; le chemin le plus court atteint pourtant le centre 15 en 3 h 27
  (BALANCE_SHEET §12, Q-V2c-1).
- Débit visé de l'usine : de 3 MU/s à 14 000 MU/s en fin d'époque (×1,83 par époque). **Budget** = débit
  **moyen** de l'époque × durée (correction : le débit de fin d'époque surestimait de 33 %).
- **Passage du centre** de k à k+1 : un **Codex k** plus un lot de monnaie de 10 % du budget de l'époque.
- **Monnaies au format V2** : **une monnaie principale par époque** ; un niveau payé à l'époque e coûte 60 %
  de sa valeur en monnaie de e et 40 % en monnaie de e−1 (`L.MAIN_SHARE`). Chaque monnaie est un **objet**
  (jamais un fluide), avec une **pile d'au moins 50** et une **valeur fixe en MU** (`X.currencies`). Les
  monnaies V2 qui existent déjà sont gardées telles quelles (même objet, même valeur, même pile, contrôlé).
  Changées : époque 8 (biopolymère au lieu du baril de méthane, pile de 10), 11 à 15 (les objets X0 que V2
  attendait sous d'autres noms : titane, bobine supraconductrice, cellule de plasma, superalliage, matière
  exotique). Diff au §10.
- Le superalliage (époque 14) se coule **aussi sans météorite** (bloc de fer ρ32 + titane + carbure) : la
  monnaie n'a plus de plafond de carte. La matière exotique (époque 15) en a un (3 failles garanties :
  0,3 unité/s) ; sa valeur (1 500 MU) traduit cette rareté.
- **Jalon de production** : 2 % du budget de l'époque, converti en monnaie (au lieu d'un nombre fixe qui ne
  mesurait plus rien après l'époque 6).
- **Recherche** : 35 % du budget de chaque époque (technologies nouvelles et vanilla re-rangée, §4.4).

<!-- GEN:calendar -->
| Ép. | Durée | Atteinte à | Palier | Ouvriers | Niveau max | Débit fin (MU/s) | Débit moyen | Budget (MU) | Passage du centre (MU) | Monnaie (valeur, pile) | Jalon de production | Recherche (% du budget) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 Pionnier | 0,5 h | 0 h | T1 | 1 | 2 | 3 | 2 | 4 054 | 405 | panier de base | 82 Plaque de fer | 34,7 % |
| 2 Forge | 1 h | 0,5 h | T1 | 1 | 4 | 5 | 4 | 14 826 | 1 483 | Plaque d'acier (5 MU, 100) | 60 Plaque d'acier | 35,5 % |
| 3 Vapeur | 1,5 h | 1,5 h | T1 | 1 | 6 | 10 | 8 | 40 662 | 4 066 | Moteur (9 MU, 50) | 91 Moteur | 35 % |
| 4 Pétrole | 2 h | 3 h | T2 | 2 | 8 | 18 | 14 | 99 130 | 9 913 | Plastique (3 MU, 100) | 661 Plastique | 35,2 % |
| 5 Volcan | 2,5 h | 5 h | T2 | 2 | 10 | 34 | 25 | 226 561 | 22 656 | Plaque de tungstène (4 MU, 100) | 1 133 Plaque de tungstène | 34,8 % |
| 6 Électricité | 3 h | 7,5 h | T2 | 2 | 12 | 61 | 46 | 497 094 | 49 709 | Batterie (9 MU, 200) | 1 105 Batterie | 35,2 % |
| 7 Cristal | 3,5 h | 10,5 h | T3 | 3 | 14 | 112 | 84 | 1 060 369 | 106 037 | Cristal de résonance (3 MU, 50) | 7 070 Cristal de résonance | 35 % |
| 8 Marais | 4 h | 14 h | T3 | 3 | 16 | 205 | 154 | 2 215 750 | 221 575 | Biopolymère (4 MU, 100) | 11 079 Biopolymère | 35 % |
| 9 Atome | 4,5 h | 18 h | T3 | 3 | 18 | 375 | 281 | 4 557 694 | 455 769 | Uranium 238 (14 MU, 100) | 6 511 Uranium 238 | 35,1 % |
| 10 Haute technologie | 5 h | 22,5 h | T4 | 4 | 20 | 685 | 514 | 9 259 223 | 925 922 | Processeur (75 MU, 100) | 2 470 Processeur | 35 % |
| 11 Titane | 5,5 h | 27,5 h | T4 | 4 | 22 | 1 253 | 941 | 18 622 549 | 1 862 255 | Plaque de titane ρ8 (20 MU, 100) | 18 623 Plaque de titane ρ8 | 35 % |
| 12 Supraconducteurs | 6 h | 33 h | T4 | 4 | 24 | 2 290 | 1 720 | 37 144 935 | 3 714 494 | Bobine supraconductrice (60 MU, 100) | 12 382 Bobine supraconductrice | 35 % |
| 13 Fusion | 6,5 h | 39 h | T5 | 5 | 26 | 4 188 | 3 144 | 73 575 568 | 7 357 557 | Cellule de plasma (25 MU, 100) | 58 861 Cellule de plasma | 35 % |
| 14 Orbite | 7 h | 45,5 h | T5 | 5 | 28 | 7 657 | 5 749 | 144 873 923 | 14 487 392 | Superalliage ρ32 (45 MU, 50) | 64 389 Superalliage ρ32 | 35 % |
| 15 Légende | 7 h | 52,5 h | T5 | 5 | 30 | 14 000 | 10 511 | 264 887 907 | — | Matière exotique stabilisée (1 500 MU, 50) | 117 728 Superalliage ρ32 | 35 % |
<!-- /GEN:calendar -->

**Gabarit d'époque façon Clash of Clans** (`X.epochs[k].milestones`) : 5 jalons par époque.
- **Production** : 2 % du budget en monnaie de l'époque (colonne ci-dessus).
- **Construction** : poser le bâtiment signature (par exemple 4 foreuses de concentré à l'époque 10).
- **Recherche** : 60 % des technologies nouvelles de l'époque (`X.milestone_research`, dénominateur compté).
- **Défense** : détruire 2 + k nids. **Exploration** : cartographier 64 × k chunks, ou trouver la ressource
  de l'époque.
- Récompense de chaque jalon : une caisse versée au centre (5 % du lot de passage) et 5 × k minutes de
  crédit d'accélération. Les 5 jalons donnent une **médaille** au choix : +2 % de productivité minière, +5 %
  de recherche ou +5 % de fabrication manuelle (attributs de force en écriture, vérifiés).
- **Score de puissance** : Σ(niveau × poids de la famille) + 500 × époque + 2 000 × merveille + 50 × jalon.

### 3.2 Ressources, tuiles, objets

**Toute ressource dont dépend un pack a une garantie de placement** (contrôlé : le banc retire chaque
ressource tour à tour et regarde quels packs deviennent impossibles). Une carte sèche ou sans cratère ne
bloque plus la partie : le script pose ce qui manque, à distance fixée.

<!-- GEN:resources -->
| Ressource | Époque | Produit | Où | Garantie de placement |
|---|---|---|---|---|
| Fumerolle | 5 | Gaz volcanique | cendres volcaniques | 2 fumerolles posées par script dans la première zone de cendres trouvée, ou sur une tache de cendres créée à cette distance si la graine n'en a pas (2, 250 à 600 tuiles) |
| Galène | 9 | Galène | gisements classiques à plus de 300 tuiles du départ | 2 gisements de 200 000 posés par script si l'autoplace n'en a mis aucun à cette distance (2, 300 à 600 tuiles) |
| Ilménite | 11 | Minerai d'ilménite | champs de cratères (nouveau biome) | au moins un champ de cratères complet (ilménite, lac de saumure, rempart de brèche) posé par script à 400-900 tuiles s'il n'en existe aucun (1, 400 à 900 tuiles) |
| Lac de saumure | 11 | Saumure | fond des cratères | dans le champ de cratères garanti (3 lacs) (1, 400 à 900 tuiles) |
| Brèche d'impact [D-I] | 11 | Pierre | remparts des cratères | dans le champ de cratères garanti (rempart) (1, 400 à 900 tuiles) |
| Monazite | 12 | Minerai de monazite | sables noirs (rivages, ou dunes sur carte sèche) | 2 taches de sables noirs à monazite posées par script, même sans eau (dunes de sable noir) (2, 400 à 900 tuiles) |
| Veine de caustique [A-II] | 12 | Flux sombre | partout ; 2 veines près du départ, puis 1 veine pour 20 à 25 chunks balayés au radar | 2 veines « visibles mais illisibles » posées au début de partie (hachage de la graine) (2, 80 à 200 tuiles) |
| Évent mantellique | 13 | Hélium-3 | cœur des cendres volcaniques, rare | 2 évents posés par script au cœur de la plus grande zone de cendres à cette distance (2, 500 à 1 000 tuiles) |
| Impact météoritique | 14 | Météorite ferreuse ρ8 | créé par les pluies de météorites (toutes les 20 à 40 min) ; infini (minimum 20 %) | la première pluie tombe à l'entrée dans l'époque 14, à 150-400 tuiles du centre (2, 150 à 400 tuiles) |
| Faille du Cœur | 15 | Matière exotique brute | 3 à 5 failles posées au réveil du Cœur, gardées par des primordiaux | 3 à 5 failles à des positions tirées de la graine (3, 600 à 1 200 tuiles) |
| Remontée profonde : fer [A-II] | 12 | Concentré de fer ρ8 | créée par le script sous un puits gravitique (minerai choisi par le joueur) | créée sous chaque puits posé : jamais absente |
| Remontée profonde : cuivre [A-II] | 12 | Concentré de cuivre ρ8 | créée par le script sous un puits gravitique (minerai choisi par le joueur) | créée sous chaque puits posé : jamais absente |
| Remontée profonde : tungstène [A-III] | 14 | Concentré de tungstène ρ8 | créée par le script sous un puits gravitique (minerai choisi par le joueur) | créée sous chaque puits posé : jamais absente |
| Remontée profonde : ilménite [A-III] | 14 | Concentré d'ilménite ρ8 | créée par le script sous un puits gravitique (minerai choisi par le joueur) | créée sous chaque puits posé : jamais absente |
| Remontée profonde : monazite [A-III] | 14 | Concentré de monazite ρ8 | créée par le script sous un puits gravitique (minerai choisi par le joueur) | créée sous chaque puits posé : jamais absente |
| Minerai de tungstène (existant) | 5 | Minerai de tungstène | fo-volcanic-ash | posé par script (lot M0) : un gisement de tungstène d'environ 200 000 sur un disque de cendres, partie neuve toujours, sauvegarde existante s'il n'en est connu aucun |
| Cristal de résonance (existant) | 7 | Cristal de résonance | fo-crystal-flats | posé par script (lot M0) : un gisement de cristal d'environ 120 000 sur une plaine de cristal, mêmes conditions |
| Méthane (existant) | 8 | Méthane | fo-toxic-marsh | posé par script (lot M0) : 2 puits de méthane à 150 % dans une flaque de marais, mêmes conditions (puits connus comptés) |
<!-- /GEN:resources -->

Ressources vanilla : fer, cuivre, charbon, pierre, bois et eau dans la zone de départ vanilla ; pétrole et
uranium par l'autoplace vanilla (une carte réglée sans pétrole ni uranium reste un choix du joueur).
Ressources « non garanties » qui ne servent à aucun pack : aucune.

Tuiles et biomes (`X.tiles`) : **asphalte** (époque 4, marche ×1,4), **champs de cratères** (11 ; texture
choisie d'après sa couleur **mesurée**, F36 et F38), **sables noirs** (12, rivages ou dunes), **sol étrange**
(13, posé par la contagion), **abysse du Cœur** (15).

**Objets et fluides nouveaux par époque** (`X.items`) :

<!-- GEN:items -->
| Ép. | Objets | Fluides (baril) |
|---|---|---|
| 1 | Tissu de déchiqueteur, Codex I : journal du pionnier | — |
| 2 | Coke, Laitier, Ciment, Sable, Codex II : carnet de forge | — |
| 3 | Verre, Manomètre, Codex III : registre des chaudières | — |
| 4 | Asphalte, Codex IV : relevés de forage | Éthylène |
| 5 | Carbure de tungstène, Trépan en carbure, Pack géologique, Codex V : atlas des cendres | Gaz volcanique |
| 6 | Graphite, Tôle magnétique, Fil émaillé, Bobine, Codex VI : schémas du réseau | — |
| 7 | Cristal taillé, Poudre de cristal, Lentille de résonance, Oscillateur à cristal, Pack de résonance, Cristal chargé, Relevé gravimétrique, Carte gravimétrique, Codex VII : partitions du cristal | — |
| 8 | Échantillon de vase, Culture méthanotrophe, Biopolymère, Pack biochimique, Codex VIII : herbier du marais | Hydrogène, Oxygène, Dioxyde de carbone |
| 9 | Galène, Plaque de plomb, Blindage plombé, Pack isotopique, Cuivre activé, Piège magnétique, Piège à positons, Données d'annihilation, Grenade à positons, Cellule usée refroidie, Colis vitrifié, Codex IX : cahier du réacteur | — |
| 10 | Silicium métallurgique, Silicium pur, Tranche de silicium, Cristal temporel instable, Données chronométriques, Concentré de fer ρ8, Concentré de cuivre ρ8, Concentré de tungstène ρ8, Billette de fer ρ8, Billette de cuivre ρ8, Billette de tungstène ρ8, Codex X : plans de la salle blanche | — |
| 11 | Minerai d'ilménite, Concentré d'ilménite ρ8, Laitier titanifère ρ8, Éponge de titane ρ8, Plaque de titane ρ8, Soude caustique, Chlorure de magnésium, Magnésium, Composite titane, Pack structurel, Cryostat, Inclusion étrange, Données hadroniques, Chargeur à inclusion, Cristal temporel stable, Sablier quantique, Codex XI : carte des cratères | Saumure, Chlore, Tétrachlorure de titane |
| 12 | Minerai de monazite, Concentré de monazite ρ8, Concentré de terres rares, Oxyde de thorium, Néodyme, Yttrium, Ruban supraconducteur, Aimant permanent, Bobine supraconductrice, Cellule de sel au thorium, Sel usé, Pack magnétique, Cellule SMES vide, Cellule SMES chargée, Cavité de résonance, Condensat d'axions, Codex XII : traité des aimants | Azote liquide, Oxygène liquide, Hélium, Hélium liquide, Flux sombre (sans baril) |
| 13 | Ilménite dégazée ρ8, Pastille de fusion, Pastille de fusion catalysée, Cellule de plasma, Pack plasma, Piège à antiprotons, Piège d'antihydrogène, Micro-charge d'antimatière, Obus d'annihilation, Strangelet confiné, Plaque étrange, Bloc de fer ρ32, Bloc de cuivre ρ32, Codex XIII : journal du confinement | Hélium-3, Eau lourde, Deutérium, Plasma |
| 14 | Météorite ferreuse ρ8, Météorite étrange ρ8, Ferronickel ρ8, Iridium, Superalliage ρ32, Miroir d'iridium, Ergol cryogénique, Remorqueur orbital, Centrale solaire orbitale, Sonde profonde, Armure étrange, Pièce de lanceur léger (compteur), Codex XIV : archives orbitales de l'Arche | Hydrogène liquide |
| 15 | Cavité de Casimir, Matière exotique stabilisée, Pack exotique, Segment d'anneau (compteur), Clé de phase | Matière exotique brute (sans baril) |
<!-- /GEN:items -->

### 3.3 Bâtiments nouveaux et niveaux (Q6)

- Taille maximale 10×10 (Q9) : la Porte et le réacteur à annihilation l'atteignent.
- **Au moins 2 bâtiments de ligne principale par époque** (contrôlé par le banc).
- **Niveaux** : chaque bâtiment déclare sa famille de niveaux et **naît au premier niveau de son époque**
  (2e−1), puis monte jusqu'au niveau 30 ; ou il est « sans niveau », avec sa raison écrite (réacteurs :
  l'énergie par combustible est fixée par la règle P5 ; merveilles ; coffres ; pylônes ; silos…).
- Les quatre familles d'énergie inhabituelles (chaleur, vapeur, brûleur à résidu, fluide brûlé) sont permises
  par le schéma 1.1.91 ; leur comportement est **non vérifié** en moteur (§8).

<!-- GEN:buildings -->
| Bâtiment | Ép. | Prototype 1.1 | Taille | Énergie | Rôle | Niveaux |
|---|---|---|---|---|---|---|
| Atelier à combustion | 1 | assembling-machine | 3×3 | brûleur (chemical), 0,15 MW | vitesse 0,5 | assembler, niveaux 1 à 30 |
| Laboratoire à combustion | 1 | lab | 3×3 | brûleur (chemical), 0,12 MW | — | lab, niveaux 1 à 30 |
| Four à coke | 2 | assembling-machine | 3×3 | brûleur (chemical), 0,18 MW | vitesse 1 | furnace, niveaux 3 à 30 |
| Haut fourneau | 2 | assembling-machine | 4×4 | brûleur (chemical), 0,6 MW | vitesse 1 | furnace, niveaux 3 à 30 |
| Concasseur | 2 | assembling-machine | 2×2 | brûleur (chemical), 0,12 MW | vitesse 1 | assembler, niveaux 3 à 30 |
| Marteau-pilon à vapeur | 3 | assembling-machine | 3×3 | vapeur, 0,9 MW | vitesse 1 | assembler, niveaux 5 à 30 |
| Foreuse à vapeur | 3 | mining-drill | 3×3 | vapeur, 0,45 MW | minage 0,75 (basic-solid) | drill, niveaux 5 à 30 |
| Torchère | 4 | furnace | 2×2 | 0,05 MW | vitesse 1 | sans niveau : puits de fluide : aucun débit utile à améliorer |
| Vapocraqueur | 4 | assembling-machine | 3×3 | 0,6 MW | vitesse 1 | process, niveaux 7 à 30 |
| Capteur géothermique | 5 | mining-drill | 3×3 | 0,3 MW | minage 1 (fo-fumarole) | drill, niveaux 9 à 30 |
| Four de frittage | 5 | assembling-machine | 3×3 | 0,6 MW | vitesse 1 | furnace, niveaux 9 à 30 |
| Foreuse lourde | 5 | mining-drill | 3×3 | 0,4 MW | minage 1 (basic-solid, fo-hard-solid) | drill, niveaux 9 à 30 |
| Four à arc | 6 | assembling-machine | 4×4 | 4,4 MW | vitesse 2 | furnace, niveaux 11 à 30 |
| Bobineuse | 6 | assembling-machine | 2×2 | 0,2 MW | vitesse 1 | assembler, niveaux 11 à 30 |
| Pylône haute tension | 6 | electric-pole | 2×2 | — | — | sans niveau : pylône : portée déjà au plafond moteur de 64 |
| Broyeur à mâchoires | 6 | assembling-machine | 3×3 | 0,5 MW | vitesse 2 | assembler, niveaux 11 à 30 |
| Taillerie | 7 | assembling-machine | 3×3 | 0,4 MW | vitesse 1 | assembler, niveaux 13 à 30 |
| Amplificateur de résonance | 7 | beacon | 3×3 | 0,6 MW | — | sans niveau : balise : son effet vient des modules ; un niveau contournerait la règle des modules |
| Résonateur de caustique [A-I] | 7 | assembling-machine | 2×2 | 0,5 MW | vitesse 1 ; recette fixe ; actif seulement à 64 tuiles au plus d'une veine | assembler, niveaux 13 à 30 |
| Station de charge | 7 | assembling-machine | 2×2 | 10 MW | vitesse 1 | sans niveau : rendement de charge fixé à 80 % par la règle d'énergie P5 |
| Générateur à cristal | 7 | burner-generator | 2×2 | produit 1 MW | — | energy, niveaux 13 à 30 |
| Reformeur | 8 | assembling-machine | 3×3 | 1 MW | vitesse 1 | process, niveaux 15 à 30 |
| Électrolyseur | 8 | assembling-machine | 3×3 | 3 MW | vitesse 1 | process, niveaux 15 à 30 |
| Bioréacteur | 8 | assembling-machine | 3×3 | 0,3 MW | vitesse 1 | process, niveaux 15 à 30 |
| Turbine à gaz | 8 | generator | 3×5 | produit 10 MW | — | energy, niveaux 15 à 30 |
| Irradiateur [B-I] | 9 | assembling-machine | 3×3 | chaleur 500 à 1 000 °C, 10 MW | vitesse 1 | assembler, niveaux 17 à 30 |
| Modérateur de positons [B-I] | 9 | assembling-machine | 3×3 | 2 MW | vitesse 1 ; confinement | assembler, niveaux 17 à 30 |
| Piscine d'entreposage | 9 | assembling-machine | 4×4 | aucune | vitesse 1 | sans niveau : stockage à durée fixe : le temps de refroidissement fait le jeu |
| Dépôt géologique | 9 | container | 6×6 | — | — | sans niveau : coffre |
| Salle blanche | 10 | assembling-machine | 5×5 | 4 MW | vitesse 1 | assembler, niveaux 19 à 30 |
| Radar à réseau phasé | 10 | radar | 3×3 | 1,2 MW | — | radar, niveaux 19 à 30 |
| Concentrateur | 10 | assembling-machine | 2×2 | 1,5 MW | vitesse 3,75 ; alimenté 1:1 en insertion directe par la foreuse de concentré (30 minerais/s → 3,75 concentrés/s) ; derrière des foreuses lourdes, par tapis (30 foreuses par concentrateur) | assembler, niveaux 19 à 30 |
| Foreuse de concentré | 10 | mining-drill | 5×5 | 3 MW | minage 30 (basic-solid, fo-hard-solid) ; sortie (vector_to_place_result) dans un concentrateur accolé : 30 MU/s par ensemble, 32 ensembles par tapis T4 | drill, niveaux 19 à 30 |
| Banc de phase [C-I] | 10 | assembling-machine | 3×3 | 0,8 MW | vitesse 1 | assembler, niveaux 19 à 30 |
| Réacteur de Kroll | 11 | assembling-machine | 4×4 | 2 MW | vitesse 1 | furnace, niveaux 21 à 30 |
| Pylône léger en titane | 11 | electric-pole | 2×2 | — | sous-station légère : fil 32, zone 18 × 18 | sans niveau : pylône |
| Bras léger en titane | 11 | inserter | 1×1 | 0,06 MW | bras long rapide à pile (portée 2) : alimente les machines T4 sans bras empileur | inserter, niveaux 21 à 30 |
| Tour d'observation | 11 | radar | 2×2 | 0,3 MW | vue rapprochée continue de 11 × 11 chunks, aucun balayage lointain : la sentinelle des avant-postes | radar, niveaux 21 à 30 |
| Trieur d'inclusions [D-I] | 11 | assembling-machine | 3×3 | 1,5 MW | vitesse 1 | assembler, niveaux 21 à 30 |
| Résonateur temporel [C-II] | 11 | assembling-machine | 3×3 | 8 MW | vitesse 1 | assembler, niveaux 21 à 30 |
| Chambre de dilatation [C-II] | 11 | assembling-machine | 3×3 | 5 MW | vitesse 1 ; recette fixe | sans niveau : effet de zone réglé par la branche C : un niveau multiplierait la dilatation |
| Coffre intriqué [C-II] | 11 | linked-container | 1×1 | — | 1 case ; 2 paires par force au niveau II, 4 au niveau III ; chaque paire active tire 20 MW (interface électrique cachée) | sans niveau : coffre |
| Unité cryogénique | 12 | assembling-machine | 5×5 | 4 MW | vitesse 1 | process, niveaux 23 à 30 |
| Colonne d'extraction | 12 | assembling-machine | 3×3 | 0,5 MW | vitesse 1 | process, niveaux 23 à 30 |
| Réacteur à sels fondus | 12 | reactor | 5×5 | brûleur (fo-thorium) → 160 MW de chaleur (voisinage 0, 1 000 °C) | — | sans niveau : puissance fixée par le bilan d'énergie P5 : un niveau changerait l'énergie tirée d'un combustible |
| Accumulateur supraconducteur | 12 | accumulator | 3×3 | — | — | energy, niveaux 23 à 30 |
| Locomotive maglev | 12 | locomotive | 2×6 | brûleur (fo-electric-storage) | — | sans niveau : véhicule |
| Haloscope [A-II] | 12 | mining-drill | 5×5 | 20 MW | minage 1 (fo-caustic) | drill, niveaux 23 à 30 |
| Condenseur gravitique [A-II] | 12 | assembling-machine | 4×4 | 15 MW | vitesse 1 | assembler, niveaux 23 à 30 |
| Puits gravitique [A-II] | 12 | mining-drill | 5×5 | brûleur (fo-axion), 2 MW | minage 1 (fo-deep) | drill, niveaux 23 à 30 |
| Colonne isotopique | 13 | assembling-machine | 3×3 | 2 MW | vitesse 1 | process, niveaux 25 à 30 |
| Réacteur à fusion | 13 | reactor | 7×7 | brûleur (fo-fusion) → 800 MW de chaleur (voisinage 0, 5 000 °C) | 4 injecteurs en contact direct (un par face) ou par caloduc haute température | sans niveau : puissance fixée par le bilan d'énergie P5 : un niveau changerait l'énergie tirée d'un combustible |
| Injecteur de plasma | 13 | boiler | 3×3 | chaleur 1 000 à 5 000 °C, 200 MW | chaudière en mode « output-to-separate-pipe » (vérifié) : hydrogène → plasma 1:1, porté de 15 à 5 000 °C | sans niveau : débit réglé sur la chaleur du réacteur |
| Turbine MHD | 13 | generator | 5×5 | produit 200 MW | puissance = (min(T, 5 000) - 15) × 40/s × 1 kJ ≈ 200 MW ; un plasma retombé à 15 °C (baril) ne donne rien | energy, niveaux 25 à 30 |
| Caloduc haute température | 13 | heat-pipe | 1×1 | — | le caloduc vanilla plafonne à 1 000 °C : il ne peut pas alimenter un injecteur | sans niveau : caloduc |
| Fonderie à plasma | 13 | assembling-machine | 5×5 | 10 MW | vitesse 1 | furnace, niveaux 25 à 30 |
| Foreuse profonde | 13 | mining-drill | 5×5 | 5 MW | minage 1 (fo-mantle) | drill, niveaux 25 à 30 |
| Foreuse de noyau | 13 | mining-drill | 7×7 | 8 MW | minage 120 (basic-solid, fo-hard-solid) ; sortie dans une fonderie à plasma accolée (32 minerais + plasma → bloc ρ32) : 120 MU/s par ensemble, 32 par tapis T5 | drill, niveaux 25 à 30 |
| Synchrotron [B-II] | 13 | assembling-machine | 9×9 | 150 MW | vitesse 1 ; confinement | assembler, niveaux 25 à 30 |
| Recombineur [B-II] | 13 | assembling-machine | 3×3 | 10 MW | vitesse 1 ; confinement | assembler, niveaux 25 à 30 |
| Compresseur hadronique [D-II] | 13 | assembling-machine | 5×5 | 100 MW | vitesse 1 | assembler, niveaux 25 à 30 |
| Cuve de catalyse [D-II] | 13 | assembling-machine | 4×4 | 30 MW | vitesse 1 ; contagion | assembler, niveaux 25 à 30 |
| Transmutateur [D-II] | 13 | assembling-machine | 4×4 | 15 MW | vitesse 1 | assembler, niveaux 25 à 30 |
| Mur étrange [D-II] | 13 | wall | 1×1 | — | 12 000 PV | wall, niveaux 25 à 30 |
| Rectenna | 14 | electric-energy-interface | 6×6 | produit 200 MW | reçoit UNE centrale solaire orbitale (200 MW chacune) : power_production réglée par script (écriture vérifiée) | sans niveau : comportement porté par le script ; un niveau n'aurait pas d'effet propre |
| Bouclier de déviation | 14 | electric-energy-interface | 4×4 | 30 MW | consommation par power_usage (écriture vérifiée) ; déviation des météorites par script | sans niveau : comportement porté par le script ; un niveau n'aurait pas d'effet propre |
| Lanceur orbital | 14 | rocket-silo | 9×9 | 10 MW | vitesse 1 ; recette fixe ; lanceur léger pour les charges utiles du mod (10 pièces bon marché) ; le silo vanilla garde le satellite | sans niveau : silo : pièce unique de lancement |
| Puits gravitique II [A-III] | 14 | mining-drill | 5×5 | brûleur (fo-axion), 4 MW | minage 4 (fo-deep, fo-deep-rare) | drill, niveaux 27 à 30 |
| Bouclier de marée [A-III] | 14 | electric-turret | 4×4 | 20 MW | — | special-turret, niveaux 27 à 30 |
| Observatoire de la Caustique [A-III] | 14 | simple-entity-with-owner | 9×9 | — | merveille : +20 % de productivité minière (mining_drill_productivity_bonus) ; marée bloquée à 150 % | sans niveau : merveille : pièce unique, effet de force appliqué par script |
| Réacteur à annihilation [B-III] | 14 | reactor | 10×10 | brûleur (fo-antimatter) → 2 000 MW de chaleur (voisinage 0, 5 000 °C) | confinement ; 10 injecteurs autour (32 connexions de chaleur au plus) ; confinement : interface électrique cachée de 20 MW sous le réacteur | sans niveau : puissance fixée par le bilan d'énergie P5 : un niveau changerait l'énergie tirée d'un combustible |
| Lance d'annihilation [B-III] | 14 | ammo-turret | 4×4 | — | — | special-turret, niveaux 27 à 30 |
| Bastion d'annihilation [B-III] | 14 | simple-entity-with-owner | 9×9 | — | merveille : +30 % de dégâts des munitions explosives et d'annihilation (LuaForce.set_ammo_damage_modifier, vérifié) | sans niveau : merveille : pièce unique, effet de force appliqué par script |
| Chambre de dilatation II [C-III] | 14 | assembling-machine | 3×3 | 10 MW | vitesse 1 ; recette fixe | sans niveau : effet de zone réglé par la branche C |
| Horloge éternelle [C-III] | 14 | simple-entity-with-owner | 9×9 | — | merveille : 6e ouvrier (QX6), 2 sabliers par chantier au lieu de 1, laboratoires +50 % (laboratory_speed_modifier) | sans niveau : merveille : pièce unique, effet de force appliqué par script |
| Mur de neutronium [D-III] | 14 | wall | 1×1 | — | 50 000 PV | wall, niveaux 27 à 30 |
| Monolithe étrange [D-III] | 14 | simple-entity-with-owner | 9×9 | — | merveille : active les 4 recettes de transmutation résonante (40 pierres → 40 minerais) : LuaRecipe.enabled (écriture vérifiée) | sans niveau : merveille : pièce unique, effet de force appliqué par script |
| Ancre de faille | 15 | mining-drill | 7×7 | 100 MW | minage 1 (fo-rift) | sans niveau : une ancre par faille : pièce de fin de partie |
| Stabilisateur de Casimir | 15 | assembling-machine | 5×5 | 500 MW | vitesse 1 | assembler, niveaux 29 à 30 |
| Porte d'Érèbe | 15 | rocket-silo | 10×10 | 50 MW | vitesse 1 ; recette fixe ; 50 MW pendant la pose des segments ; la charge de 30 min tire 5 GW par une interface électrique cachée (power_usage, écriture vérifiée), lue toutes les 60 ticks : suspendue si l'énergie manque ; en cas d'échec, Porte debout : rocket_parts remis à 100 (écriture vérifiée) | sans niveau : pièce unique de fin de partie |
<!-- /GEN:buildings -->

**Familles de niveaux** (V2 : familles existantes ; « proposée » : familles demandées par E3-5, statistiques à
fixer par le lot V2) :

<!-- GEN:levels -->
| Famille | Statut | Bâtiments à niveaux | Prototypes de niveau |
|---|---|---|---|
| foreuses (V2 : vitesse de minage +10 %/niveau) | V2 | Foreuse à vapeur (5), Capteur géothermique (9), Foreuse lourde (9), Foreuse de concentré (19), Haloscope (23), Puits gravitique (23), Foreuse profonde (25), Foreuse de noyau (25), Puits gravitique II (27) | 114 |
| fours (V2 : vitesse +8 %/niveau) | V2 | Four à coke (3), Haut fourneau (3), Four de frittage (9), Four à arc (11), Réacteur de Kroll (21), Fonderie à plasma (25) | 114 |
| machines d'assemblage (V2 : vitesse +8 %/niveau) | V2 | Atelier à combustion (1), Concasseur (3), Marteau-pilon à vapeur (5), Bobineuse (11), Broyeur à mâchoires (11), Taillerie (13), Résonateur de caustique (13), Irradiateur (17), Modérateur de positons (17), Salle blanche (19), Concentrateur (19), Banc de phase (19), Trieur d'inclusions (21), Résonateur temporel (21), Condenseur gravitique (23), Synchrotron (25), Recombineur (25), Compresseur hadronique (25), Cuve de catalyse (25), Transmutateur (25), Stabilisateur de Casimir (29) | 284 |
| murs (V2 : PV +50 %/niveau) | V2 | Mur étrange (25), Mur de neutronium (27) | 10 |
| procédés à fluides (vitesse, comme l'assembleur) | proposée (E3-5) | Vapocraqueur (7), Reformeur (15), Électrolyseur (15), Bioréacteur (15), Unité cryogénique (23), Colonne d'extraction (23), Colonne isotopique (25) | 94 |
| laboratoires (vitesse de recherche) | proposée (E3-5) | Laboratoire à combustion (1) | 30 |
| radars (portée, cadence de balayage) | proposée (E3-5) | Radar à réseau phasé (19), Tour d'observation (21) | 22 |
| générateurs et stockage (débit ; jamais le rendement : règle P5) | proposée (E3-5) | Générateur à cristal (13), Turbine à gaz (15), Accumulateur supraconducteur (23), Turbine MHD (25) | 48 |
| tourelles spéciales (dégâts dégressifs, comme V2) | proposée (E3-5) | Bouclier de marée (27), Lance d'annihilation (27) | 8 |
| bras (vitesse de rotation, pile) | proposée (E3-5) | Bras léger en titane (21) | 10 |
| **Total** | | | **734** entités de niveau + **734** objets |
<!-- /GEN:levels -->

**Re-rangement des familles V2 vanilla : le rattrapage.** Le mur et le four en acier arrivent à l'époque 2, la
foreuse électrique et l'assembleur 2 à l'époque 3, la tourelle laser à l'époque 6. Un tel bâtiment **naît au
niveau 1** et peut monter **aussitôt** jusqu'à 2 × l'époque du centre (règle `L.max_level` de V2, inchangée),
en payant les niveaux antérieurs avec les monnaies de leurs époques, déjà produites. Aucun niveau n'est perdu ;
les silhouettes des premières époques (bible V1) restent visibles pendant ce rattrapage. L'autre lecture
(« bande décalée » : le laser naîtrait au niveau 11) est posée au Directeur Créatif : **QX8**.

### 3.4 Arbres de fabrication (toutes les recettes nouvelles)

**Notation**
- « main ou assembleur » : catégorie `crafting` ; « assembleur » : `advanced-crafting` (impossible à la main).
- *(dense)* : recette qui recevra des variantes ρ du lot C (§4.1). (prod.) : productivité permise.
- [A-II] : branche et niveau. « p x % » : probabilité. [cat. n] : quantité catalytique. (rendu) : contenant
  ou sous-produit rendu, exclu du calcul des MU.
- *minage*, *combustion*, *lancement*, *cueillette*, *butin*, *chauffe*, *torchère* : pseudo-recettes et
  puits.
- La dernière colonne nomme la **technologie** qui débloque la recette (« départ » : dès le début ;
  « merveille » : activée par script à la pose de la merveille).
- Les recettes vanilla restent **inchangées** : les améliorations sont des **variantes** (moteur électrique
  bobiné, processeur en salle blanche, structure basse densité au titane, polyéthylène, acier au haut
  fourneau, engrenage forgé, superalliage de synthèse…).

<!-- GEN:recipes -->
#### Époque 1 · Pionnier
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Atelier à combustion | 6 Plaque de fer + 5 Engrenage + 6 Brique de pierre | 1 Atelier à combustion | main ou assembleur | 2 s | départ |
| Laboratoire à combustion | 10 Engrenage + 10 Câble de cuivre + 6 Brique de pierre + 4 Bois | 1 Laboratoire à combustion | main ou assembleur | 3 s | départ |
| Butin : tissu de déchiqueteur *butin* | — | Tissu de déchiqueteur (p 2 %) | main | 1 s | — |
| Codex I : journal du pionnier | 10 Pack d'automatisation + 20 Circuit électronique + 20 Plaque de fer + 20 Brique de pierre | 1 Codex I : journal du pionnier | main ou assembleur | 30 s | Journal du pionnier |

#### Époque 2 · Forge
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Four à coke | 20 Brique de pierre + 10 Plaque de fer | 1 Four à coke | main ou assembleur | 3 s | Cokéfaction |
| Concasseur | 10 Plaque de fer + 10 Engrenage + 5 Brique de pierre | 1 Concasseur | main ou assembleur | 2 s | Concassage |
| Haut fourneau | 40 Brique de pierre + 10 Plaque d'acier + 10 Engrenage | 1 Haut fourneau | main ou assembleur | 5 s | Haut fourneau |
| Cokéfaction *(dense)* (prod.) | 3 Charbon | 2 Coke | Four à coke | 4 s | Cokéfaction |
| Acier au haut fourneau *(dense)* | 4 Plaque de fer + 1 Coke | 1 Plaque d'acier + 1 Laitier | Haut fourneau | 12 s | Haut fourneau |
| Ciment de laitier *(dense)* | 2 Laitier + 1 Pierre | 2 Ciment | Concasseur ou Broyeur à mâchoires | 2 s | Concassage |
| Sable *(dense)* | 1 Pierre | 2 Sable | Concasseur ou Broyeur à mâchoires | 1 s | Concassage |
| Codex II : carnet de forge | 20 Plaque d'acier + 20 Ciment + 10 Pack logistique + 10 Coke | 1 Codex II : carnet de forge | main ou assembleur | 30 s | Carnet de forge |

#### Époque 3 · Vapeur
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Verre *(dense)* (prod.) | 4 Sable | 1 Verre | Four électrique ou Four en acier ou Four en pierre | 3,2 s | Verrerie |
| Manomètre (prod.) | 1 Verre + 1 Engrenage + 1 Tuyau | 1 Manomètre | main ou assembleur | 2 s | Verrerie |
| Marteau-pilon à vapeur | 10 Plaque d'acier + 4 Tuyau + 2 Manomètre + 10 Engrenage | 1 Marteau-pilon à vapeur | main ou assembleur | 5 s | Forge à vapeur |
| Foreuse à vapeur | 10 Plaque d'acier + 5 Tuyau + 2 Manomètre + 10 Engrenage | 1 Foreuse à vapeur | main ou assembleur | 4 s | Forge à vapeur |
| Engrenage forgé (prod.) | 3 Plaque de fer | 2 Engrenage | Marteau-pilon à vapeur | 1 s | Forge à vapeur |
| Béton au ciment *(dense)* | 4 Ciment + 6 Sable + 50 Eau | 10 Béton | Machine d'assemblage 2 ou Machine d'assemblage 3 | 10 s | Béton au ciment |
| Codex III : registre des chaudières | 10 Manomètre + 20 Béton + 10 Pack militaire + 10 Verre | 1 Codex III : registre des chaudières | main ou assembleur | 30 s | Registre des chaudières |

#### Époque 4 · Pétrole
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Torchère | 10 Plaque d'acier + 5 Tuyau + 2 Manomètre | 1 Torchère | main ou assembleur | 3 s | Torchère |
| Vapocraqueur | 10 Plaque d'acier + 10 Tuyau + 5 Manomètre + 5 Circuit électronique + 20 Brique de pierre | 1 Vapocraqueur | main ou assembleur | 5 s | Vapocraquage |
| Vapocraquage | 30 Gaz de pétrole + 20 Vapeur | 30 Éthylène | Vapocraqueur | 2 s | Vapocraquage |
| Polyéthylène (prod.) | 20 Éthylène + 1 Charbon | 3 Plastique | Usine chimique | 1 s | Vapocraquage |
| Asphalte | 10 Huile lourde + 5 Sable | 10 Asphalte | Usine chimique | 4 s | Asphalte |
| Codex IV : relevés de forage | 20 Plastique + 10 Circuit avancé + 10 Pack chimique + 20 Asphalte | 1 Codex IV : relevés de forage | main ou assembleur | 30 s | Relevés de forage |
| Torchère : Éthylène *torchère* | 100 Éthylène | — | Torchère | 1 s | Torchère |

#### Époque 5 · Volcan
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Capteur géothermique | 10 Plaque de tungstène + 20 Tuyau + 4 Manomètre + 5 Circuit électronique | 1 Capteur géothermique | main ou assembleur | 8 s | Géothermie |
| Captage : fumerolle *minage* | — | 200 Gaz volcanique | Capteur géothermique | 1 s | — |
| Séparation du gaz volcanique | 100 Gaz volcanique | 70 Vapeur + 1 Soufre | Usine chimique | 1 s | Géothermie |
| Four de frittage | 20 Brique de pierre + 10 Plaque de tungstène + 10 Circuit électronique + 5 Béton | 1 Four de frittage | main ou assembleur | 6 s | Pack géologique |
| Carbure de tungstène (prod.) | 2 Plaque de tungstène + 1 Coke | 2 Carbure de tungstène | Four de frittage | 8 s | Pack géologique |
| Trépan en carbure (prod.) | 1 Carbure de tungstène + 2 Plaque d'acier | 1 Trépan en carbure | main ou assembleur | 4 s | Pack géologique |
| Foreuse lourde | 1 Foreuse électrique + 4 Trépan en carbure + 10 Plaque d'acier + 5 Moteur | 1 Foreuse lourde | main ou assembleur | 8 s | Forage lourd |
| Pack géologique | 4 Trépan en carbure + 2 Moteur + 2 Soufre + 4 Pierre | 2 Pack géologique | main ou assembleur | 12 s | Pack géologique |
| Codex V : atlas des cendres | 20 Plaque de tungstène + 10 Carbure de tungstène + 10 Pack géologique + 5 Trépan en carbure | 1 Codex V : atlas des cendres | main ou assembleur | 30 s | Atlas des cendres |
| Torchère : gaz volcanique *torchère* | 100 Gaz volcanique | — | Torchère | 1 s | Géothermie |

#### Époque 6 · Électricité
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Four à arc | 20 Plaque d'acier + 10 Béton + 10 Circuit avancé + 40 Câble de cuivre | 1 Four à arc | main ou assembleur | 10 s | Fusion à l'arc |
| Bobineuse | 10 Plaque d'acier + 5 Circuit électronique + 10 Engrenage | 1 Bobineuse | main ou assembleur | 4 s | Tôle magnétique et bobinage |
| Graphite *(dense)* (prod.) | 4 Coke | 3 Graphite | Four à arc | 6 s | Fusion à l'arc |
| Acier électrique *(dense)* | 3 Plaque de fer + 1 Graphite | 1 Plaque d'acier | Four à arc | 3 s | Fusion à l'arc |
| Tôle magnétique *(dense)* (prod.) | 2 Plaque d'acier + 1 Sable | 2 Tôle magnétique | Four à arc | 4 s | Tôle magnétique et bobinage |
| Fil émaillé (prod.) | 2 Câble de cuivre + 1 Plastique | 4 Fil émaillé | Bobineuse | 2 s | Tôle magnétique et bobinage |
| Bobine (prod.) | 4 Fil émaillé + 2 Tôle magnétique | 1 Bobine | Bobineuse | 3 s | Tôle magnétique et bobinage |
| Pylône haute tension | 10 Plaque d'acier + 4 Câble de cuivre + 2 Bobine | 1 Pylône haute tension | main ou assembleur | 2 s | Haute tension |
| Broyeur à mâchoires | 1 Concasseur + 10 Plaque d'acier + 2 Bobine + 5 Circuit électronique | 1 Broyeur à mâchoires | main ou assembleur | 4 s | Broyeur à mâchoires |
| Moteur électrique bobiné | 1 Moteur + 1 Bobine + 2 Circuit électronique + 10 Lubrifiant | 1 Moteur électrique | Machine d'assemblage 2 ou Machine d'assemblage 3 | 10 s | Tôle magnétique et bobinage |
| Codex VI : schémas du réseau | 10 Bobine + 20 Batterie + 10 Pack de production + 10 Graphite | 1 Codex VI : schémas du réseau | main ou assembleur | 30 s | Schémas du réseau |

#### Époque 7 · Cristal
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Taillerie | 10 Plaque de tungstène + 5 Carbure de tungstène + 10 Circuit avancé + 2 Bobine | 1 Taillerie | main ou assembleur | 6 s | Pack de résonance |
| Taille du cristal | 2 Cristal de résonance + 20 Eau | 1 Cristal taillé + 1 Poudre de cristal | Taillerie | 5 s | Pack de résonance |
| Lentille de résonance (prod.) | 1 Cristal taillé + 2 Verre | 1 Lentille de résonance | Taillerie | 6 s | Pack de résonance |
| Oscillateur à cristal (prod.) | 1 Poudre de cristal + 1 Circuit électronique + 2 Fil émaillé | 2 Oscillateur à cristal | main ou assembleur | 3 s | Pack de résonance |
| Amplificateur de résonance | 1 Balise + 4 Lentille de résonance + 10 Oscillateur à cristal | 1 Amplificateur de résonance | main ou assembleur | 8 s | Amplificateur de résonance |
| Pack de résonance | 1 Lentille de résonance + 3 Oscillateur à cristal + 3 Bobine + 5 Circuit avancé + 2 Batterie | 1 Pack de résonance | main ou assembleur | 14 s | Pack de résonance |
| Résonateur de caustique [A-I] | 4 Lentille de résonance + 10 Oscillateur à cristal + 1 Radar + 10 Plaque de tungstène | 1 Résonateur de caustique | main ou assembleur | 8 s | Matière noire I : résonateur de caustique |
| Relevé gravimétrique [A-I] | 2 Oscillateur à cristal | 1 Relevé gravimétrique | Résonateur de caustique | 30 s | Matière noire I : résonateur de caustique |
| Carte gravimétrique [A-I] | 5 Relevé gravimétrique + 1 Radar | 1 Carte gravimétrique | main ou assembleur | 10 s | Matière noire I : résonateur de caustique |
| Station de charge | 10 Plaque d'acier + 4 Bobine + 5 Circuit avancé + 2 Accumulateur | 1 Station de charge | main ou assembleur | 6 s | Énergie cristalline |
| Charge du cristal | 1 Cristal taillé | 1 Cristal chargé | Station de charge | 2 s | Énergie cristalline |
| Générateur à cristal | 10 Plaque d'acier + 5 Bobine + 2 Lentille de résonance + 1 Machine à vapeur | 1 Générateur à cristal | main ou assembleur | 5 s | Énergie cristalline |
| Décharge : cristal chargé *combustion* | 1 Cristal chargé | 1 Cristal taillé | Générateur à cristal ou Locomotive maglev | 16 s | — |
| Codex VII : partitions du cristal | 5 Lentille de résonance + 10 Oscillateur à cristal + 10 Pack de résonance + 5 Cristal taillé | 1 Codex VII : partitions du cristal | main ou assembleur | 30 s | Partitions du cristal |

#### Époque 8 · Marais
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Abattage d'arbre des marais *cueillette* | — | 4 Bois + Échantillon de vase (p 30 %) | main | 1 s | — |
| Reformeur | 15 Plaque d'acier + 10 Tuyau + 5 Plaque de tungstène + 5 Circuit avancé | 1 Reformeur | main ou assembleur | 6 s | Reformage du méthane |
| Électrolyseur | 10 Plaque d'acier + 10 Bobine + 10 Circuit avancé + 10 Plastique | 1 Électrolyseur | main ou assembleur | 8 s | Pack biochimique |
| Bioréacteur | 10 Verre + 10 Plaque d'acier + 5 Tuyau + 5 Circuit électronique | 1 Bioréacteur | main ou assembleur | 5 s | Pack biochimique |
| Turbine à gaz | 20 Plaque d'acier + 10 Plaque de tungstène + 5 Bobine + 2 Moteur électrique | 1 Turbine à gaz | main ou assembleur | 8 s | Turbine à gaz |
| Reformage du méthane | 50 Méthane + 100 Vapeur | 200 Hydrogène + 50 Dioxyde de carbone | Reformeur | 2 s | Reformage du méthane |
| Électrolyse de l'eau | 100 Eau | 100 Hydrogène + 50 Oxygène | Électrolyseur | 2 s | Pack biochimique |
| Mise en culture (vase) | 5 Échantillon de vase + 50 Eau | 1 Culture méthanotrophe | Bioréacteur | 30 s | Pack biochimique |
| Mise en culture (tissu) | 5 Tissu de déchiqueteur + 50 Eau | 1 Culture méthanotrophe | Bioréacteur | 30 s | Pack biochimique |
| Croissance de la culture | 10 Culture méthanotrophe [cat. 10] + 100 Méthane + 50 Eau | 12 Culture méthanotrophe [cat. 10] | Bioréacteur | 20 s | Pack biochimique |
| Biopolymère (PHB) | 1 Culture méthanotrophe + 60 Méthane + 40 Oxygène | 4 Biopolymère + 20 Dioxyde de carbone | Bioréacteur | 10 s | Pack biochimique |
| Méthane de digesteur | 10 Tissu de déchiqueteur + 50 Eau | 60 Méthane | Bioréacteur | 20 s | Digesteur et carbonatation |
| Carbonatation du laitier | 50 Dioxyde de carbone + 2 Laitier | 3 Ciment | Usine chimique | 4 s | Digesteur et carbonatation |
| Pack biochimique | 4 Culture méthanotrophe + 20 Biopolymère + 4 Circuit avancé + 20 Acide sulfurique | 1 Pack biochimique | Usine chimique | 15 s | Pack biochimique |
| Codex VIII : herbier du marais | 20 Biopolymère + 5 Culture méthanotrophe + 10 Pack biochimique | 1 Codex VIII : herbier du marais | main ou assembleur | 30 s | Herbier du marais |
| Torchère : hydrogène *torchère* | 100 Hydrogène | — | Torchère | 1 s | Pack biochimique |
| Torchère : oxygène *torchère* | 100 Oxygène | — | Torchère | 1 s | Pack biochimique |
| Torchère : dioxyde de carbone *torchère* | 100 Dioxyde de carbone | — | Torchère | 1 s | Pack biochimique |

#### Époque 9 · Atome
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Minage : galène *minage* | — | 1 Galène | main ou Foreuse à combustion ou Foreuse à vapeur ou Foreuse électrique ou Foreuse lourde ou Foreuse de concentré ou Foreuse de noyau | 1 s | — |
| Plomb *(dense)* (prod.) | 2 Galène | 1 Plaque de plomb | Four électrique ou Four en acier ou Four en pierre | 3,2 s | Pack isotopique |
| Grillage de la galène *(dense)* | 4 Galène + 20 Oxygène | 3 Plaque de plomb + 1 Soufre | Four à arc | 4 s | Grillage de la galène |
| Blindage plombé (prod.) | 3 Plaque de plomb + 1 Plaque d'acier | 1 Blindage plombé | main ou assembleur | 3 s | Pack isotopique |
| Pack isotopique | 4 Blindage plombé + 4 Uranium 238 + 4 Oscillateur à cristal + 6 Circuit avancé | 1 Pack isotopique | main ou assembleur | 15 s | Pack isotopique |
| Irradiateur [B-I] | 20 Blindage plombé + 20 Caloduc + 10 Circuit avancé | 1 Irradiateur | main ou assembleur | 10 s | Antimatière I : positons |
| Modérateur de positons [B-I] | 10 Blindage plombé + 10 Bobine + 10 Plaque de tungstène + 10 Circuit avancé | 1 Modérateur de positons | main ou assembleur | 10 s | Antimatière I : positons |
| Activation du cuivre [B-I] | 10 Plaque de cuivre | 10 Cuivre activé | Irradiateur | 30 s | Antimatière I : positons |
| Piège magnétique [B-I] | 4 Bobine + 2 Blindage plombé + 2 Circuit avancé | 1 Piège magnétique | main ou assembleur | 10 s | Antimatière I : positons |
| Capture de positons [B-I] | 10 Cuivre activé + 1 Piège magnétique | 1 Piège à positons + 10 Plaque de cuivre (rendu) | Modérateur de positons | 60 s | Antimatière I : positons |
| Annihilation contrôlée [B-I] | 1 Piège à positons | 1 Piège magnétique (rendu) + 4 Données d'annihilation | Modérateur de positons | 20 s | Antimatière I : positons |
| Grenade à positons [B-I] | 1 Piège à positons + 1 Grenade | 1 Grenade à positons | main ou assembleur | 8 s | Antimatière I : positons |
| Piscine d'entreposage | 50 Béton + 20 Blindage plombé + 10 Tuyau + 1 Pompe côtière | 1 Piscine d'entreposage | main ou assembleur | 10 s | Combustible usé |
| Refroidissement en piscine | 10 Cellule d'uranium usée | 10 Cellule usée refroidie | Piscine d'entreposage | 600 s | Combustible usé |
| Vitrification | 2 Cellule usée refroidie + 4 Verre | 1 Colis vitrifié + 1 Uranium 238 | Four à arc | 20 s | Combustible usé |
| Dépôt géologique | 100 Béton + 50 Blindage plombé + 20 Plaque d'acier | 1 Dépôt géologique | main ou assembleur | 10 s | Combustible usé |
| Codex IX : cahier du réacteur | 20 Blindage plombé + 2 Cellule d'uranium + 10 Pack isotopique | 1 Codex IX : cahier du réacteur | main ou assembleur | 30 s | Cahier du réacteur |

#### Époque 10 · Haute technologie
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Salle blanche | 50 Béton + 20 Plaque d'acier + 20 Circuit avancé + 10 Verre + 10 Bobine | 1 Salle blanche | assembleur | 15 s | Silicium et salle blanche |
| Silicium métallurgique *(dense)* (prod.) | 4 Sable + 1 Graphite | 1 Silicium métallurgique | Four à arc | 6 s | Silicium et salle blanche |
| Silicium pur (prod.) | 2 Silicium métallurgique + 30 Hydrogène | 1 Silicium pur | Usine chimique | 8 s | Silicium et salle blanche |
| Tranche de silicium (prod.) | 1 Silicium pur | 4 Tranche de silicium | Salle blanche | 10 s | Silicium et salle blanche |
| Processeur en salle blanche (prod.) | 10 Circuit électronique + 2 Circuit avancé + 1 Tranche de silicium + 5 Acide sulfurique | 2 Processeur | Salle blanche | 15 s | Silicium et salle blanche |
| Radar à réseau phasé | 1 Radar + 10 Processeur + 20 Oscillateur à cristal + 10 Tôle magnétique | 1 Radar à réseau phasé | assembleur | 10 s | Radar à réseau phasé |
| Cristal temporel instable [C-I] | 1 Cristal taillé + 2 Tranche de silicium + 1 Processeur | 1 Cristal temporel instable | Salle blanche | 30 s | Chronodynamique I : cristal temporel |
| Banc de phase [C-I] | 20 Oscillateur à cristal + 5 Processeur + 20 Plaque d'acier + 10 Verre | 1 Banc de phase | assembleur | 10 s | Chronodynamique I : cristal temporel |
| Mesure de phase [C-I] | 1 Cristal temporel instable | 4 Données chronométriques + 1 Poudre de cristal | Banc de phase | 20 s | Chronodynamique I : cristal temporel |
| Radar à réseau phasé (horloge de phase) [C-I] | 1 Radar + 4 Processeur + 1 Cristal temporel instable + 10 Tôle magnétique | 1 Radar à réseau phasé | Banc de phase | 10 s | Chronodynamique I : cristal temporel |
| Concentrateur | 10 Plaque d'acier + 4 Bobine + 5 Processeur + 10 Carbure de tungstène | 1 Concentrateur | assembleur | 8 s | Foreuses de concentré (T4) |
| Foreuse de concentré | 1 Foreuse lourde + 10 Trépan en carbure + 10 Processeur + 10 Bobine + 20 Plaque d'acier | 1 Foreuse de concentré | assembleur | 15 s | Foreuses de concentré (T4) |
| Concentré de fer ρ8 | 8 Minerai de fer | 1 Concentré de fer ρ8 | Concentrateur | 1 s | Foreuses de concentré (T4) |
| Concentré de cuivre ρ8 | 8 Minerai de cuivre | 1 Concentré de cuivre ρ8 | Concentrateur | 1 s | Foreuses de concentré (T4) |
| Concentré de tungstène ρ8 | 8 Minerai de tungstène | 1 Concentré de tungstène ρ8 | Concentrateur | 1 s | Foreuses de concentré (T4) |
| Fonte de concentré de fer *(dense)* | 1 Concentré de fer ρ8 | 1 Billette de fer ρ8 | Four à arc | 0,533 s | Billettes ρ8 |
| Fonte de concentré de cuivre *(dense)* | 1 Concentré de cuivre ρ8 | 1 Billette de cuivre ρ8 | Four à arc | 0,533 s | Billettes ρ8 |
| Fonte de concentré de tungstène *(dense)* | 1 Concentré de tungstène ρ8 | 1 Billette de tungstène ρ8 | Four à arc | 1,066 s | Billettes ρ8 |
| Découpe de billette de fer | 1 Billette de fer ρ8 | 8 Plaque de fer | main ou assembleur | 1 s | Billettes ρ8 |
| Découpe de billette de cuivre | 1 Billette de cuivre ρ8 | 8 Plaque de cuivre | main ou assembleur | 1 s | Billettes ρ8 |
| Découpe de billette de tungstène | 1 Billette de tungstène ρ8 | 8 Plaque de tungstène | main ou assembleur | 1 s | Billettes ρ8 |
| Codex X : plans de la salle blanche | 20 Processeur + 10 Tranche de silicium + 10 Pack utilitaire | 1 Codex X : plans de la salle blanche | main ou assembleur | 30 s | Plans de la salle blanche |

#### Époque 11 · Titane
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Minage : ilménite *minage* | — | 1 Minerai d'ilménite | Foreuse électrique ou Foreuse lourde ou Foreuse de concentré ou Foreuse de noyau | 2 s | — |
| Concentré d'ilménite ρ8 | 8 Minerai d'ilménite | 1 Concentré d'ilménite ρ8 | Concentrateur | 1 s | Pack structurel (titane) |
| Pompage : saumure *minage* | — | 10 Saumure | Chevalet de pompage | 1 s | — |
| Minage : brèche d'impact *minage* [D-I] | — | 1 Pierre + Inclusion étrange (p 0,5 %) | Foreuse électrique ou Foreuse lourde ou Foreuse de concentré ou Foreuse de noyau | 2 s | — |
| Réacteur de Kroll | 30 Plaque d'acier + 20 Plaque de tungstène + 10 Bobine + 10 Processeur | 1 Réacteur de Kroll | assembleur | 12 s | Pack structurel (titane) |
| Fusion de l'ilménite *(dense)* | 2 Concentré d'ilménite ρ8 + 2 Coke | 1 Laitier titanifère ρ8 + 6 Plaque de fer | Four à arc | 1 s | Pack structurel (titane) |
| Électrolyse de la saumure | 100 Saumure | 40 Chlore + 40 Hydrogène + 1 Soude caustique + 1 Chlorure de magnésium | Électrolyseur | 3 s | Pack structurel (titane) |
| Chloration | 1 Laitier titanifère ρ8 + 1 Coke + 60 Chlore | 40 Tétrachlorure de titane | Usine chimique | 5 s | Pack structurel (titane) |
| Réduction de Kroll | 40 Tétrachlorure de titane + 2 Magnésium | 1 Éponge de titane ρ8 + 2 Chlorure de magnésium | Réacteur de Kroll | 0,5 s | Pack structurel (titane) |
| Électrolyse du chlorure de magnésium | 1 Chlorure de magnésium | 1 Magnésium + 15 Chlore | Électrolyseur | 3 s | Pack structurel (titane) |
| Refusion sous vide *(dense)* (prod.) | 1 Éponge de titane ρ8 | 1 Plaque de titane ρ8 | Four à arc | 0,533 s | Pack structurel (titane) |
| Tungstène par voie humide *(dense)* | 5 Minerai de tungstène + 1 Soude caustique + 40 Hydrogène | 4 Plaque de tungstène | Usine chimique | 8 s | Tungstène par voie humide |
| Cryostat (prod.) | 1 Plaque de titane ρ8 + 2 Biopolymère + 1 Processeur | 1 Cryostat | main ou assembleur | 10 s | Cryostat |
| Composite titane (prod.) | 1 Plaque de titane ρ8 + 2 Biopolymère + 1 Graphite | 2 Composite titane | main ou assembleur | 15 s | Pack structurel (titane) |
| Structure basse densité au titane (prod.) | 1 Composite titane + 4 Plaque de cuivre | 2 Structure basse densité | main ou assembleur | 15 s | Cryostat |
| Pack structurel | 4 Composite titane + 4 Plaque de titane ρ8 + 4 Carbure de tungstène + 1 Processeur | 1 Pack structurel | main ou assembleur | 20 s | Pack structurel (titane) |
| Trieur d'inclusions [D-I] | 2 Plaque de titane ρ8 + 1 Broyeur à mâchoires + 5 Processeur + 10 Tôle magnétique | 1 Trieur d'inclusions | assembleur | 10 s | Matière étrange I : inclusions |
| Chargeur à inclusion [D-I] | 1 Inclusion étrange + 10 Chargeur à l'uranium | 10 Chargeur à inclusion | main ou assembleur | 10 s | Matière étrange I : inclusions |
| Analyse d'inclusion [D-I] | 1 Inclusion étrange + 1 Processeur | 4 Données hadroniques | Trieur d'inclusions | 60 s | Matière étrange I : inclusions |
| Résonateur temporel [C-II] | 2 Plaque de titane ρ8 + 1 Cryostat + 10 Oscillateur à cristal + 10 Processeur | 1 Résonateur temporel | assembleur | 20 s | Chronodynamique II : verrouillage de phase |
| Cristal temporel stable (verrouillage de phase) [C-II] | 2 Cristal temporel instable + 4 Oscillateur à cristal | 1 Cristal temporel stable | Résonateur temporel | 80 s | Chronodynamique II : verrouillage de phase |
| Sablier quantique [C-II] | 1 Cristal temporel stable + 2 Oscillateur à cristal + 1 Processeur + 10 Plaque de titane ρ8 | 1 Sablier quantique | Salle blanche | 30 s | Chronodynamique II : verrouillage de phase |
| Chambre de dilatation [C-II] | 1 Amplificateur de résonance + 2 Cristal temporel stable + 10 Bobine + 5 Composite titane | 1 Chambre de dilatation | assembleur | 20 s | Chronodynamique II : verrouillage de phase |
| Maintien de phase [C-II] | 1 Cristal temporel stable | 1 Cristal temporel instable | Chambre de dilatation ou Chambre de dilatation II | 120 s | Chronodynamique II : verrouillage de phase |
| Coffre intriqué [C-II] | 2 Cristal temporel stable + 4 Plaque de titane ρ8 + 5 Processeur | 2 Coffre intriqué | assembleur | 20 s | Chronodynamique II : verrouillage de phase |
| Pylône léger en titane | 2 Plaque de titane ρ8 + 10 Câble de cuivre + 2 Circuit avancé | 1 Pylône léger en titane | main ou assembleur | 4 s | Structures légères |
| Bras léger en titane | 1 Bras empileur + 1 Plaque de titane ρ8 + 1 Bobine | 1 Bras léger en titane | main ou assembleur | 2 s | Structures légères |
| Tour d'observation | 1 Radar + 4 Composite titane + 2 Lentille de résonance | 1 Tour d'observation | main ou assembleur | 6 s | Structures légères |
| Codex XI : carte des cratères | 5 Plaque de titane ρ8 + 10 Composite titane + 10 Pack structurel | 1 Codex XI : carte des cratères | main ou assembleur | 30 s | Carte des cratères |
| Torchère : saumure *torchère* | 100 Saumure | — | Torchère | 1 s | Pack structurel (titane) |
| Torchère : chlore *torchère* | 100 Chlore | — | Torchère | 1 s | Pack structurel (titane) |
| Torchère : tétrachlorure de titane *torchère* | 100 Tétrachlorure de titane | — | Torchère | 1 s | Pack structurel (titane) |

#### Époque 12 · Supraconducteurs
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Minage : monazite *minage* | — | 1 Minerai de monazite | Foreuse électrique ou Foreuse lourde ou Foreuse de concentré ou Foreuse de noyau | 2 s | — |
| Concentré de monazite ρ8 | 8 Minerai de monazite | 1 Concentré de monazite ρ8 | Concentrateur | 1 s | Pack magnétique |
| Unité cryogénique | 40 Plaque d'acier + 3 Plaque de titane ρ8 + 10 Moteur électrique + 10 Processeur + 20 Tuyau | 1 Unité cryogénique | assembleur | 15 s | Pack magnétique |
| Colonne d'extraction | 3 Plaque de titane ρ8 + 10 Verre + 10 Tuyau + 5 Processeur | 1 Colonne d'extraction | assembleur | 8 s | Pack magnétique |
| Lessivage de la monazite | 1 Concentré de monazite ρ8 + 20 Acide sulfurique | 4 Concentré de terres rares + 1 Oxyde de thorium | Usine chimique | 8 s | Pack magnétique |
| Extraction par solvant | 4 Concentré de terres rares + 10 Huile légère | 2 Néodyme + 1 Yttrium | Colonne d'extraction | 6 s | Pack magnétique |
| Distillation de l'air | — | 50 Azote liquide + 15 Oxygène liquide | Unité cryogénique | 2 s | Pack magnétique |
| Séparation cryogénique du gaz volcanique | 100 Gaz volcanique + 10 Azote liquide | 70 Vapeur + 1 Soufre + 5 Hélium | Unité cryogénique | 1 s | Hélium |
| Liquéfaction de l'hélium | 20 Hélium + 20 Azote liquide | 10 Hélium liquide | Unité cryogénique | 4 s | Hélium |
| Ruban supraconducteur (YBCO) (prod.) | 1 Yttrium + 3 Plaque de cuivre + 20 Oxygène | 4 Ruban supraconducteur | Four de frittage | 6 s | Pack magnétique |
| Aimant permanent (NdFeB) (prod.) | 1 Néodyme + 2 Plaque de fer | 2 Aimant permanent | Four de frittage | 6 s | Pack magnétique |
| Bobine supraconductrice (prod.) | 4 Ruban supraconducteur + 1 Cryostat + 20 Azote liquide | 1 Bobine supraconductrice | Bobineuse | 10 s | Pack magnétique |
| Cellule de sel au thorium | 4 Oxyde de thorium + 1 Uranium 235 + 20 Chlore | 1 Cellule de sel au thorium | Usine chimique | 20 s | Sels fondus au thorium |
| Combustion : sel au thorium (160 MW) *combustion* | 1 Cellule de sel au thorium | 1 Sel usé | Réacteur à sels fondus | 200 s | — |
| Retraitement du sel | 2 Sel usé | 1 Oxyde de thorium + 1 Uranium 238 | Centrifugeuse | 30 s | Sels fondus au thorium |
| Réacteur à sels fondus | 200 Blindage plombé + 10 Plaque de titane ρ8 + 50 Processeur + 100 Béton | 1 Réacteur à sels fondus | assembleur | 60 s | Sels fondus au thorium |
| Accumulateur supraconducteur | 4 Bobine supraconductrice + 10 Accumulateur + 2 Cryostat | 1 Accumulateur supraconducteur | assembleur | 10 s | Stockage supraconducteur |
| Locomotive maglev | 1 Locomotive + 8 Aimant permanent + 4 Bobine supraconductrice + 10 Composite titane | 1 Locomotive maglev | assembleur | 20 s | Maglev |
| Cellule SMES vide | 2 Bobine supraconductrice + 1 Cryostat + 1 Plaque de titane ρ8 | 1 Cellule SMES vide | main ou assembleur | 10 s | Stockage supraconducteur |
| Charge de cellule SMES | 1 Cellule SMES vide | 1 Cellule SMES chargée | Station de charge | 50 s | Stockage supraconducteur |
| Décharge : cellule SMES *combustion* | 1 Cellule SMES chargée | 1 Cellule SMES vide | Locomotive maglev ou Générateur à cristal | 1 s | — |
| Pack magnétique | 2 Bobine supraconductrice + 4 Aimant permanent + 2 Plaque de titane ρ8 + 1 Processeur | 1 Pack magnétique | main ou assembleur | 20 s | Pack magnétique |
| Haloscope [A-II] | 4 Bobine supraconductrice + 2 Cryostat + 10 Lentille de résonance + 20 Processeur + 5 Plaque de titane ρ8 | 1 Haloscope | assembleur | 30 s | Matière noire II : haloscope |
| Captage : veine de caustique *minage* [A-II] | — | 20 Flux sombre | Haloscope | 1 s | — |
| Condenseur gravitique [A-II] | 4 Bobine supraconductrice + 20 Cristal taillé + 10 Processeur + 2 Cryostat | 1 Condenseur gravitique | assembleur | 20 s | Matière noire II : haloscope |
| Cavité de résonance [A-II] | 2 Lentille de résonance + 1 Bobine supraconductrice + 1 Cryostat | 1 Cavité de résonance | main ou assembleur | 15 s | Matière noire II : haloscope |
| Condensation d'axions [A-II] | 200 Flux sombre + 1 Cavité de résonance + 5 Hélium liquide | 1 Condensat d'axions | Condenseur gravitique | 20 s | Matière noire II : haloscope |
| Relevé de condensat [A-II] | 1 Condensat d'axions | 1 Cavité de résonance (rendu) + 10 Relevé gravimétrique | Condenseur gravitique | 10 s | Matière noire II : haloscope |
| Puits gravitique [A-II] | 1 Foreuse lourde + 4 Condensat d'axions + 10 Bobine supraconductrice + 20 Composite titane | 1 Puits gravitique | assembleur | 30 s | Matière noire II : haloscope |
| Combustion : condensat (puits, 2 MW) *combustion* [A-II] | 1 Condensat d'axions | 1 Cavité de résonance | Puits gravitique ou Puits gravitique II | 60 s | — |
| Remontée profonde : fer *minage* [A-II] | — | 1 Concentré de fer ρ8 | Puits gravitique ou Puits gravitique II | 1 s | — |
| Remontée profonde : cuivre *minage* [A-II] | — | 1 Concentré de cuivre ρ8 | Puits gravitique ou Puits gravitique II | 1 s | — |
| Cristal temporel stable (hélium liquide) [C-II] | 2 Cristal temporel instable + 5 Hélium liquide | 1 Cristal temporel stable | Résonateur temporel | 40 s | Chronodynamique II : cristal à l'hélium liquide |
| Codex XII : traité des aimants | 5 Bobine supraconductrice + 10 Aimant permanent + 10 Pack magnétique | 1 Codex XII : traité des aimants | main ou assembleur | 30 s | Traité des aimants |
| Torchère : azote liquide *torchère* | 100 Azote liquide | — | Torchère | 1 s | Pack magnétique |
| Torchère : oxygène liquide *torchère* | 100 Oxygène liquide | — | Torchère | 1 s | Pack magnétique |
| Torchère : hélium *torchère* | 100 Hélium | — | Torchère | 1 s | Hélium |
| Torchère : hélium liquide *torchère* | 100 Hélium liquide | — | Torchère | 1 s | Hélium |
| Torchère : flux sombre *torchère* [A-II] | 100 Flux sombre | — | Torchère | 1 s | Matière noire II : haloscope |

#### Époque 13 · Fusion
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Colonne isotopique | 20 Plaque d'acier + 2 Plaque de titane ρ8 + 10 Tuyau + 5 Processeur | 1 Colonne isotopique | assembleur | 10 s | Fusion D-³He et pack plasma |
| Réacteur à fusion | 200 Bobine supraconductrice + 100 Composite titane + 100 Cryostat + 200 Blindage plombé + 500 Béton | 1 Réacteur à fusion | assembleur | 120 s | Fusion D-³He et pack plasma |
| Injecteur de plasma | 10 Bobine supraconductrice + 10 Plaque de tungstène + 10 Caloduc | 1 Injecteur de plasma | assembleur | 20 s | Fusion D-³He et pack plasma |
| Turbine MHD | 20 Aimant permanent + 10 Bobine supraconductrice + 20 Plaque de tungstène + 20 Composite titane | 1 Turbine MHD | assembleur | 20 s | Turbine MHD |
| Fonderie à plasma | 50 Plaque de tungstène + 20 Bobine supraconductrice + 20 Béton + 10 Processeur | 1 Fonderie à plasma | assembleur | 30 s | Fusion D-³He et pack plasma |
| Foreuse profonde | 1 Foreuse lourde + 20 Carbure de tungstène + 10 Bobine supraconductrice + 10 Processeur | 1 Foreuse profonde | assembleur | 20 s | Fusion D-³He et pack plasma |
| Captage : évent mantellique *minage* | — | 4 Hélium-3 | Foreuse profonde | 1 s | — |
| Dégazage du régolithe | 1 Concentré d'ilménite ρ8 | 1 Ilménite dégazée ρ8 + 0,1 Hélium-3 | Four de frittage | 0,267 s | Dégazage du régolithe |
| Fusion de l'ilménite dégazée *(dense)* | 2 Ilménite dégazée ρ8 + 2 Coke | 1 Laitier titanifère ρ8 + 6 Plaque de fer | Four à arc | 1 s | Dégazage du régolithe |
| Distillation isotopique de l'hélium | 100 Hélium [cat. 90] + 10 Azote liquide | 90 Hélium [cat. 90] + 1 Hélium-3 | Unité cryogénique | 5 s | Fusion D-³He et pack plasma |
| Eau lourde (procédé Girdler) | 1 000 Eau | 10 Eau lourde | Colonne isotopique | 10 s | Fusion D-³He et pack plasma |
| Électrolyse de l'eau lourde | 100 Eau lourde | 100 Deutérium + 50 Oxygène | Électrolyseur | 2 s | Fusion D-³He et pack plasma |
| Pastille de fusion | 50 Deutérium + 50 Hélium-3 + 1 Composite titane | 1 Pastille de fusion | Unité cryogénique | 10 s | Fusion D-³He et pack plasma |
| Combustion : pastille (800 MW) *combustion* | 1 Pastille de fusion | — | Réacteur à fusion | 100 s | — |
| Ionisation (injecteur) *chauffe* | 40 Hydrogène | 40 Plasma | Injecteur de plasma | 1 s | — |
| Cellule de plasma (prod.) | 1 Aimant permanent + 1 Composite titane + 50 Plasma | 1 Cellule de plasma | Fonderie à plasma | 5 s | Fusion D-³He et pack plasma |
| Pack plasma | 2 Cellule de plasma + 2 Bobine supraconductrice + 2 Processeur | 1 Pack plasma | main ou assembleur | 25 s | Fusion D-³He et pack plasma |
| Coulée de bloc de fer *(dense)* | 4 Concentré de fer ρ8 + 0,5 Plasma | 1 Bloc de fer ρ32 | Fonderie à plasma | 0,267 s | Coulée au plasma (T5) |
| Coulée de bloc de cuivre *(dense)* | 4 Concentré de cuivre ρ8 + 0,5 Plasma | 1 Bloc de cuivre ρ32 | Fonderie à plasma | 0,267 s | Coulée au plasma (T5) |
| Coulée directe de minerai de fer | 32 Minerai de fer + 0,5 Plasma | 1 Bloc de fer ρ32 | Fonderie à plasma | 0,267 s | Coulée au plasma (T5) |
| Coulée directe de minerai de cuivre | 32 Minerai de cuivre + 0,5 Plasma | 1 Bloc de cuivre ρ32 | Fonderie à plasma | 0,267 s | Coulée au plasma (T5) |
| Foreuse de noyau | 1 Foreuse de concentré + 20 Bobine supraconductrice + 40 Carbure de tungstène + 20 Processeur | 1 Foreuse de noyau | assembleur | 30 s | Coulée au plasma (T5) |
| Caloduc haute température | 1 Caloduc + 4 Plaque de tungstène + 1 Ruban supraconducteur | 1 Caloduc haute température | main ou assembleur | 2 s | Fusion D-³He et pack plasma |
| Découpe de bloc de fer | 1 Bloc de fer ρ32 | 4 Billette de fer ρ8 | main ou assembleur | 1 s | Coulée au plasma (T5) |
| Découpe de bloc de cuivre | 1 Bloc de cuivre ρ32 | 4 Billette de cuivre ρ8 | main ou assembleur | 1 s | Coulée au plasma (T5) |
| Synchrotron [B-II] | 100 Bobine supraconductrice + 50 Aimant permanent + 50 Cryostat + 100 Processeur + 200 Béton | 1 Synchrotron | assembleur | 120 s | Antimatière II : antihydrogène |
| Recombineur [B-II] | 10 Bobine supraconductrice + 4 Cryostat + 10 Processeur + 10 Blindage plombé | 1 Recombineur | assembleur | 20 s | Antimatière II : antihydrogène |
| Production d'antiprotons (150 MW) [B-II] | 1 Piège magnétique + 100 Hydrogène | 1 Piège à antiprotons | Synchrotron | 30 s | Antimatière II : antihydrogène |
| Recombinaison (antihydrogène) [B-II] | 1 Piège à antiprotons + 1 Piège à positons | 1 Piège d'antihydrogène + 1 Piège magnétique (rendu) | Recombineur | 10 s | Antimatière II : antihydrogène |
| Micro-charge d'antimatière [B-II] | 1 Piège d'antihydrogène + 10 Plaque de tungstène + 10 Ruban supraconducteur | 10 Micro-charge d'antimatière + 1 Piège magnétique (rendu) | Recombineur | 20 s | Antimatière II : antihydrogène |
| Obus d'annihilation [B-II] | 1 Obus d'artillerie + 1 Micro-charge d'antimatière | 1 Obus d'annihilation | main ou assembleur | 10 s | Antimatière II : antihydrogène |
| Mesure d'annihilation [B-II] | 1 Piège d'antihydrogène | 1 Piège magnétique (rendu) + 20 Données d'annihilation | Recombineur | 10 s | Antimatière II : antihydrogène |
| Fusion catalysée par l'antimatière [B-II] | 2 Pastille de fusion + 2 Piège d'antihydrogène | 2 Pastille de fusion catalysée + 2 Piège magnétique (rendu) | Recombineur | 20 s | Antimatière II : antihydrogène |
| Combustion : pastille catalysée *combustion* [B-II] | 1 Pastille de fusion catalysée | — | Réacteur à fusion | 200 s | — |
| Compresseur hadronique [D-II] | 50 Bobine supraconductrice + 50 Plaque de tungstène + 20 Cryostat + 50 Processeur | 1 Compresseur hadronique | assembleur | 60 s | Matière étrange II : strangelets |
| Cuve de catalyse [D-II] | 20 Blindage plombé + 20 Bobine supraconductrice + 10 Cryostat + 10 Composite titane | 1 Cuve de catalyse | assembleur | 30 s | Matière étrange II : strangelets |
| Germination d'un strangelet [D-II] | 1 Inclusion étrange + 200 Plasma | 1 Strangelet confiné | Compresseur hadronique | 60 s | Matière étrange II : strangelets |
| Croissance étrange [D-II] | 2 Strangelet confiné [cat. 2] + 10 Pierre + 10 Sable | 3 Strangelet confiné [cat. 2] | Cuve de catalyse | 30 s | Matière étrange II : strangelets |
| Croissance étrange : conversion de laitier [D-II] | 1 Strangelet confiné [cat. 1] + 32 Laitier | 2 Strangelet confiné [cat. 1] | Cuve de catalyse | 30 s | Matière étrange II : strangelets |
| Croissance étrange : conversion de sable [D-II] | 1 Strangelet confiné [cat. 1] + 32 Sable | 2 Strangelet confiné [cat. 1] | Cuve de catalyse | 30 s | Matière étrange II : strangelets |
| Croissance étrange : conversion de pierre [D-II] | 1 Strangelet confiné [cat. 1] + 32 Pierre | 2 Strangelet confiné [cat. 1] | Cuve de catalyse | 30 s | Matière étrange II : strangelets |
| Croissance étrange : conversion de colis vitrifiés [D-II] | 1 Strangelet confiné [cat. 1] + 32 Colis vitrifié | 2 Strangelet confiné [cat. 1] | Cuve de catalyse | 30 s | Matière étrange II : strangelets |
| Croissance étrange : conversion de sel usé [D-II] | 1 Strangelet confiné [cat. 1] + 32 Sel usé | 2 Strangelet confiné [cat. 1] | Cuve de catalyse | 30 s | Matière étrange II : strangelets |
| Plaque de matière étrange [D-II] | 1 Strangelet confiné + 4 Plaque de tungstène | 2 Plaque étrange | Cuve de catalyse | 20 s | Matière étrange II : strangelets |
| Mesure hadronique [D-II] | 1 Strangelet confiné | 12 Données hadroniques | Compresseur hadronique | 10 s | Matière étrange II : strangelets |
| Transmutateur [D-II] | 50 Plaque étrange + 20 Bobine supraconductrice + 20 Processeur | 1 Transmutateur | assembleur | 60 s | Matière étrange II : strangelets |
| Transmutation : tungstène [D-II] | 1 Strangelet confiné [cat. 1] + 40 Pierre | 1 Strangelet confiné [cat. 1] + 20 Minerai de tungstène | Transmutateur | 5 s | Matière étrange II : strangelets |
| Transmutation : ilménite [D-II] | 1 Strangelet confiné [cat. 1] + 40 Pierre | 1 Strangelet confiné [cat. 1] + 20 Minerai d'ilménite | Transmutateur | 5 s | Matière étrange II : strangelets |
| Transmutation : monazite [D-II] | 1 Strangelet confiné [cat. 1] + 40 Pierre | 1 Strangelet confiné [cat. 1] + 20 Minerai de monazite | Transmutateur | 5 s | Matière étrange II : strangelets |
| Transmutation : uranium [D-II] | 1 Strangelet confiné [cat. 1] + 40 Pierre | 1 Strangelet confiné [cat. 1] + 20 Minerai d'uranium | Transmutateur | 5 s | Matière étrange II : strangelets |
| Mur étrange [D-II] | 1 Mur blindé + 2 Plaque étrange | 1 Mur étrange | main ou assembleur | 5 s | Matière étrange II : strangelets |
| Codex XIII : journal du confinement | 2 Pastille de fusion + 5 Cellule de plasma + 10 Pack plasma | 1 Codex XIII : journal du confinement | main ou assembleur | 30 s | Journal du confinement |
| Torchère : hélium-3 *torchère* | 100 Hélium-3 | — | Torchère | 1 s | Fusion D-³He et pack plasma |
| Torchère : eau lourde *torchère* | 100 Eau lourde | — | Torchère | 1 s | Fusion D-³He et pack plasma |
| Torchère : deutérium *torchère* | 100 Deutérium | — | Torchère | 1 s | Fusion D-³He et pack plasma |

#### Époque 14 · Orbite
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Transmutation résonante : tungstène [D-III] | 1 Strangelet confiné [cat. 1] + 40 Pierre | 1 Strangelet confiné [cat. 1] + 40 Minerai de tungstène | Transmutateur | 5 s | merveille : Monolithe étrange |
| Transmutation résonante : ilménite [D-III] | 1 Strangelet confiné [cat. 1] + 40 Pierre | 1 Strangelet confiné [cat. 1] + 40 Minerai d'ilménite | Transmutateur | 5 s | merveille : Monolithe étrange |
| Transmutation résonante : monazite [D-III] | 1 Strangelet confiné [cat. 1] + 40 Pierre | 1 Strangelet confiné [cat. 1] + 40 Minerai de monazite | Transmutateur | 5 s | merveille : Monolithe étrange |
| Transmutation résonante : uranium [D-III] | 1 Strangelet confiné [cat. 1] + 40 Pierre | 1 Strangelet confiné [cat. 1] + 40 Minerai d'uranium | Transmutateur | 5 s | merveille : Monolithe étrange |
| Minage : impact météoritique *minage* | — | 1 Météorite ferreuse ρ8 | Foreuse électrique ou Foreuse lourde ou Foreuse de concentré ou Foreuse de noyau | 3 s | — |
| Liquéfaction de l'hydrogène | 100 Hydrogène + 10 Azote liquide | 50 Hydrogène liquide | Unité cryogénique | 2 s | Lanceur orbital |
| Ergol cryogénique | 40 Hydrogène liquide + 20 Oxygène liquide + 1 Composite titane | 2 Ergol cryogénique | Usine chimique | 10 s | Lanceur orbital |
| Pièce de lanceur léger | 2 Composite titane + 2 Ergol cryogénique + 1 Processeur | 1 Pièce de lanceur léger | Lanceur orbital | 3 s | Lanceur orbital |
| Lanceur orbital | 200 Béton + 50 Composite titane + 50 Bobine supraconductrice + 50 Processeur + 100 Plaque d'acier | 1 Lanceur orbital | assembleur | 60 s | Lanceur orbital |
| Remorqueur orbital | 10 Composite titane + 4 Bobine supraconductrice + 4 Processeur + 10 Ergol cryogénique | 1 Remorqueur orbital | assembleur | 30 s | Lanceur orbital |
| Lancement : remorqueur orbital *lancement* | 1 Remorqueur orbital + 10 Pièce de lanceur léger | 400 Météorite ferreuse ρ8 + 50 Météorite étrange ρ8 | Lanceur orbital | 1 s | — |
| Centrale solaire orbitale | 50 Panneau solaire + 10 Composite titane + 10 Bobine supraconductrice + 10 Processeur | 1 Centrale solaire orbitale | assembleur | 60 s | Énergie orbitale |
| Lancement : centrale solaire orbitale (+200 MW, reçus par une rectenna) *lancement* | 1 Centrale solaire orbitale + 10 Pièce de lanceur léger | — | Lanceur orbital | 1 s | — |
| Concassage météoritique | 4 Météorite ferreuse ρ8 | 3 Ferronickel ρ8 + 1 Iridium + 2 Pierre | Concasseur ou Broyeur à mâchoires | 1,6 s | Météoritique |
| Concassage d'une météorite étrange | 1 Météorite étrange ρ8 | 5 Inclusion étrange + 2 Pierre | Concasseur ou Broyeur à mâchoires | 10 s | Météoritique |
| Superalliage (ferronickel météoritique) (prod.) | 3 Ferronickel ρ8 + 1 Plaque de titane ρ8 + 1 Carbure de tungstène + 0,5 Plasma | 1 Superalliage ρ32 | Fonderie à plasma | 0,267 s | Superalliage |
| Superalliage de synthèse | 1 Bloc de fer ρ32 + 1 Plaque de titane ρ8 + 2 Carbure de tungstène + 0,5 Plasma | 1 Superalliage ρ32 | Fonderie à plasma | 0,267 s | Superalliage |
| Miroir d'iridium (prod.) | 2 Iridium + 1 Verre + 1 Composite titane | 1 Miroir d'iridium | Salle blanche | 20 s | Optique à l'iridium |
| Rectenna | 20 Aimant permanent + 100 Fil émaillé + 20 Composite titane + 10 Processeur | 1 Rectenna | assembleur | 30 s | Énergie orbitale |
| Bouclier de déviation | 20 Bobine supraconductrice + 2 Superalliage ρ32 + 10 Processeur + 4 Cryostat | 1 Bouclier de déviation | assembleur | 30 s | Bouclier de déviation |
| Puits gravitique II [A-III] | 1 Puits gravitique + 10 Condensat d'axions + 5 Superalliage ρ32 | 1 Puits gravitique II | assembleur | 60 s | Maîtrise de la matière noire |
| Remontée profonde : tungstène *minage* [A-III] | — | 1 Concentré de tungstène ρ8 | Puits gravitique II | 1 s | — |
| Remontée profonde : ilménite *minage* [A-III] | — | 1 Concentré d'ilménite ρ8 | Puits gravitique II | 1 s | — |
| Remontée profonde : monazite *minage* [A-III] | — | 1 Concentré de monazite ρ8 | Puits gravitique II | 1 s | — |
| Bouclier de marée [A-III] | 10 Condensat d'axions + 10 Bobine supraconductrice + 5 Superalliage ρ32 | 1 Bouclier de marée | assembleur | 40 s | Maîtrise de la matière noire |
| Observatoire de la Caustique [A-III] | 200 Condensat d'axions + 500 Lentille de résonance + 50 Superalliage ρ32 + 300 Processeur | 1 Observatoire de la Caustique | assembleur | 600 s | Maîtrise de la matière noire |
| Réacteur à annihilation [B-III] | 300 Bobine supraconductrice + 50 Superalliage ρ32 + 500 Blindage plombé + 100 Cryostat | 1 Réacteur à annihilation | assembleur | 180 s | Maîtrise de l'antimatière |
| Bastion d'annihilation [B-III] | 100 Piège d'antihydrogène + 500 Blindage plombé + 50 Superalliage ρ32 + 300 Processeur | 1 Bastion d'annihilation | assembleur | 600 s | Maîtrise de l'antimatière |
| Combustion : antihydrogène (2 GW) *combustion* [B-III] | 1 Piège d'antihydrogène | 1 Piège magnétique | Réacteur à annihilation | 25 s | — |
| Lance d'annihilation [B-III] | 40 Bobine supraconductrice + 10 Superalliage ρ32 + 20 Processeur + 20 Micro-charge d'antimatière | 1 Lance d'annihilation | assembleur | 60 s | Maîtrise de l'antimatière |
| Sonde profonde [B-III] | 2 Piège d'antihydrogène + 10 Composite titane + 5 Processeur | 1 Sonde profonde | assembleur | 60 s | Maîtrise de l'antimatière |
| Lancement : sonde profonde *lancement* [B-III] | 1 Sonde profonde + 10 Pièce de lanceur léger | 50 Météorite étrange ρ8 + 400 Iridium | Lanceur orbital | 1 s | — |
| Chambre de dilatation II [C-III] | 1 Chambre de dilatation + 4 Cristal temporel stable + 2 Superalliage ρ32 | 1 Chambre de dilatation II | assembleur | 30 s | Maîtrise de la chronodynamique |
| Horloge éternelle [C-III] | 100 Cristal temporel stable + 200 Sablier quantique + 50 Superalliage ρ32 + 300 Processeur | 1 Horloge éternelle | assembleur | 600 s | Maîtrise de la chronodynamique |
| Mur de neutronium [D-III] | 1 Mur étrange + 8 Plaque étrange + 1 Superalliage ρ32 | 1 Mur de neutronium | main ou assembleur | 10 s | Maîtrise de la matière étrange |
| Armure étrange [D-III] | 40 Plaque étrange + 20 Composite titane + 10 Bobine supraconductrice | 1 Armure étrange | assembleur | 60 s | Maîtrise de la matière étrange |
| Monolithe étrange [D-III] | 500 Plaque étrange + 50 Strangelet confiné + 50 Superalliage ρ32 + 300 Processeur | 1 Monolithe étrange | assembleur | 600 s | Maîtrise de la matière étrange |
| Codex XIV : archives orbitales de l'Arche | 5 Superalliage ρ32 + 5 Miroir d'iridium + 10 Pack espace | 1 Codex XIV : archives orbitales de l'Arche | main ou assembleur | 30 s | Archives orbitales de l'Arche |
| Torchère : hydrogène liquide *torchère* | 100 Hydrogène liquide | — | Torchère | 1 s | Lanceur orbital |

#### Époque 15 · Légende
| Recette | Entrées | Sorties | Machine | Durée | Technologie |
|---|---|---|---|---|---|
| Ancre de faille | 4 Condensat d'axions + 4 Plaque étrange + 2 Piège d'antihydrogène + 2 Cristal temporel stable + 10 Superalliage ρ32 + 20 Bobine supraconductrice | 1 Ancre de faille | assembleur | 120 s | Matière exotique et pack exotique |
| Captage : faille du Cœur *minage* | 20 Plasma | 5 Matière exotique brute | Ancre de faille | 1 s | — |
| Stabilisateur de Casimir | 50 Miroir d'iridium + 20 Bobine supraconductrice + 10 Superalliage ρ32 + 50 Processeur | 1 Stabilisateur de Casimir | assembleur | 60 s | Matière exotique et pack exotique |
| Cavité de Casimir | 2 Miroir d'iridium + 1 Cristal temporel stable + 1 Bobine supraconductrice | 1 Cavité de Casimir | Salle blanche | 30 s | Matière exotique et pack exotique |
| Stabilisation de la matière exotique (500 MW) | 50 Matière exotique brute + 1 Cavité de Casimir [cat. 1] | 1 Matière exotique stabilisée + 1 Cavité de Casimir [cat. 1] | Stabilisateur de Casimir | 60 s | Matière exotique et pack exotique |
| Pack exotique | 1 Matière exotique stabilisée + 35 Superalliage ρ32 + 30 Processeur + 10 Miroir d'iridium | 20 Pack exotique | Salle blanche | 60 s | Matière exotique et pack exotique |
| Porte d'Érèbe | 500 Béton + 50 Superalliage ρ32 + 100 Bobine supraconductrice + 50 Miroir d'iridium + 20 Matière exotique stabilisée + 100 Processeur | 1 Porte d'Érèbe | assembleur | 300 s | La Porte d'Érèbe |
| Segment d'anneau | 2 Matière exotique stabilisée + 1 Superalliage ρ32 + 2 Plaque étrange + 1 Condensat d'axions + 1 Piège d'antihydrogène + 1 Cristal temporel stable | 1 Segment d'anneau | Porte d'Érèbe | 60 s | La Porte d'Érèbe |
| Clé de phase | 10 Matière exotique stabilisée + 10 Miroir d'iridium + 10 Sablier quantique | 1 Clé de phase | assembleur | 120 s | La Porte d'Érèbe |
| Ouverture de la Porte (charge de 30 min sous assaut, 5 GW) *lancement* | 1 Clé de phase + 100 Segment d'anneau | — | Porte d'Érèbe | 1 s | — |
<!-- /GEN:recipes -->

### 3.5 Contenu vanilla et existant
- **Aucune recette vanilla n'est modifiée** (contrôlé : aucune recette nouvelle ne porte un nom vanilla).
- **Phase « brûleur » aux époques 1 et 2 (QX1)** : assembleurs, laboratoire, foreuse électrique et énergie
  électrique vanilla sont rangés à l'époque 3.
- **Re-rangement complet** : chaque recette de base du graphe a une époque dans `X.base_recipe_epochs`, et le
  banc prouve qu'aucune n'est anachronique.
- **Jamais rangées** (`X.base_recipe_never`, corrigé) : l'**interface électrique vanilla** (500 GW pour 2
  plaques et 5 circuits : elle annulerait les 5 GW de la Porte et la règle P5) et les **chargeurs** (cachés
  en vanilla ; ils ne sortent de cette liste que sur décision du lot C). Le banc refuse toute recette
  vanilla cachée qui ne serait pas déclarée ; seule la pièce de fusée (recette fixe du silo) est tolérée.
- **Technologies vanilla scindées** (`X.vanilla_tech_splits`, relevées par le banc dans `technology.lua`) :
  `concrete` (3 et 4), `military-3` (2 et 4), `military-4` (2 et 10), `kovarex-enrichment-process` (9 et 10).
- **Coût des technologies vanilla re-rangées** (`X.VANILLA_UNIT_SCALE`) : aux époques 2 à 4, 6 et 10, la
  recherche vanilla, payée avec la fenêtre de packs, coûte de 1,3 à 11 fois le budget de l'époque. Son nombre
  d'unités est donc divisé (×0,04 à ×0,25) pour tenir dans 17,5 % du budget. C'est un **constat de modèle** :
  ou la courbe de débit des premières époques est trop basse, ou la recherche vanilla doit être allégée
  (**QX9**).
- **Productivité minière vanilla** re-rangée sur les paliers (`X.vanilla_tech_epochs` : époques 4, 7, 10, 13).
- Points notables : modules 2 et 3 vanilla à l'époque 10 (processeurs) ; modules 4 et 5 du mod à l'époque 10,
  6 à 10 à l'époque 14 ; tapis rouges (T2) à l'époque 4 ; tapis bleus (45/s, hors modèle) à l'époque 7,
  **à trancher par le lot C** ; robots, roboports, processeurs, artillerie à l'époque 10 ; silo et satellite à 14.
- **Corrections de l'existant** (`X.existing_overrides`, diff au §10) : tour à arc et arc portatif en bobines
  (époque 6) au lieu de cristal (époque 7) ; `fo-arc-and-acid` et `fo-heavy-weapons-2` scindées.

### 3.6 Bilans de chaîne chiffrés (calculés sur les recettes du §3.4)

**Époques 2 à 9**
- **Acier** : haut fourneau, 4 fers par acier au lieu de 5 ; le laitier devient du ciment ou absorbe du CO₂.
- **Engrenage forgé** : 1,5 fer par engrenage au lieu de 2, à la vapeur.
- **Plastique** (époque 4) : vapocraquage puis polyéthylène, 30 gaz → 4,5 plastiques au lieu de 3.
- **Fumerolle** : 200 gaz/s → 140 vapeurs/s (4,2 MW) et 2 soufres/s. Infinie.
- **Énergie transportable** : cristal chargé (20 MJ pour 16 rendus), cellule SMES (500 MJ pour 400 rendus).

**Époques 10 à 12 : Compaction T4**
- **Ligne principale** : foreuse de concentré (30 minerais/s) → concentrateur accolé 1:1 (3,75 concentrés/s)
  → four à arc (3,75 billettes/s, 30 MU/s, 4,4 MW). Un tapis T4 de billettes : 32 ensembles, 285 MW (§4.2).
- **Titane** (une plaque ρ8 = 8 MU) : 16 minerais d'ilménite, 3 cokes, 30 chlores nets ; réduction de Kroll à
  16 MU/s par réacteur (0,5 s par éponge), refusion à 30 MU/s.
- **Sels fondus** : cellule de 32 GJ en 200 s = 160 MW, **sans bonus de voisinage** (`neighbour_bonus = 0`).

**Époque 13 : fusion et Compaction T5**
- 1 réacteur de 800 MW (sans bonus de voisinage, 5 000 °C) brûle 1 pastille de 80 GJ toutes les 100 s :
  0,5 hélium-3/s et 0,5 deutérium/s. Sa chaleur va à **4 injecteurs en contact direct** (un par face) ou par
  **caloduc haute température** (le caloduc vanilla plafonne à 1 000 °C, sous le minimum de l'injecteur).
- Injecteur : chaudière en mode « output-to-separate-pipe » (vérifié) ; 200 MW portent 40 hydrogènes/s de 15
  à 5 000 °C (plasma : capacité 1 kJ/°C). Turbine MHD : (5 000 − 15) × 40/s × 1 kJ ≈ 200 MW.
- Hélium-3 : un évent mantellique (4/s) alimente 8 réacteurs ; à défaut, le dégazage du régolithe (0,1 par
  concentré d'ilménite, sous-produit du titane) ou la distillation isotopique de l'hélium.
- **Ligne principale T5** : foreuse de noyau (120 minerais/s) → fonderie à plasma accolée (32 minerais + 0,5
  plasma → 1 bloc ρ32 en 0,267 s, 120 MU/s). Un tapis T5 : 32 ensembles, 576 MW électriques + 299 MW de
  chaleur de plasma, soit 1,1 réacteur à fusion.

**Branches**
- **Matière noire** : 1 haloscope (20 MW) et 2 condenseurs → 0,1 condensat/s → 6 puits → 48 MU/s infinis.
- **Antimatière** : un réacteur à annihilation, 2 GW de chaleur, 10 injecteurs et 10 turbines MHD ; ≈ 1,8 GW
  nets une fois payés synchrotron, recombineur, modérateurs et irradiateurs.
- **Matière étrange** : chaque cuve ajoute 1 strangelet toutes les 30 s ; un transmutateur donne 4 minerais
  rares/s pour 8 pierres/s et 15 MW.

**La Porte (total de fin de partie ; calculé par le banc)**

<!-- GEN:gate -->
- **230 matières exotiques stabilisées**, soit **11 500 matières brutes**.
- **160 superalliages ρ32** (5 120 MU).
- Branches consommées (segments et ancre) : A : 104 × Condensat d'axions ; B : 102 × Piège d'antihydrogène ; C : 102 × Cristal temporel stable ; D : 204 × Plaque étrange.
- Énergie : 0,3 TJ pour poser les segments (50 MW), puis 9 TJ pour la charge (5 GW pendant 30 min).
<!-- /GEN:gate -->

### 3.7 Graphe réaliste et minerais par âge (lot X3, 27/10, proposition, pas en jeu)

> **Statut : PROPOSITION, rien en jeu.** Aucun prototype, aucune locale, aucun fichier du jeu ne lit ces
> données. Elles **enrichissent** le scénario approuvé sans le modifier : `shared/content/epochs.lua` est
> intact, les blocs `GEN:` ci-dessus décrivent toujours X0 seul.
>
> **Demande du DC** (27/10, vers 8 h, dictée) : « avoir d'autres minerais [...] tel minerai à telle époque
> [...] des graphes liés entre eux, avoir un peu plus de complexité à certains endroits, par exemple des
> processeurs [...] des technologies laser, [...] des impressions [...] des cartes graphiques, peut-être faire
> du calcul [...] comme si on essayait de monter en fait des machines [...] peut-être pour des robots, des
> vraiment des robots de défense ». Rappel du même jour : le cerveau des PNJ doit **généraliser** depuis les
> données (aucun chemin en dur).
>
> **Source des chiffres** : `shared/content/x3.lua`, joint à X0 par `X3.merge` (sur une copie fraîche, en fin
> de liste). **Banc** : `lua5.2 tests/x3_test.lua`, **5 084 OK, 0 échec** le 27/10 (détail au point 9).

**1. Le principe.** Trois chaînes marquantes, et presque rien ailleurs.
- **A. Imprimer les puces** : âges 4, 7 et 10.
- **B. Calculer** : âge 10, puis les âges 11 à 15.
- **C. Monter des machines, se défendre** : âges 6, 7, 10 et 12.

Le reste :
- **Quatre minerais nouveaux**, un seul par âge : blende (3), cassitérite (4), bauxite (6), quartz filonien (10).
- **Neuf âges sans aucun objet ni bâtiment nouveau** : 1, 2, 5, 8, 9, 11, 13, 14 et 15.
- **Volume** :

| | X0 | Fusion |
|---|---|---|
| Objets | 144 | 176 |
| Bâtiments | 80 | 86 |
| Recettes réelles | 247 | 283 |
| Technologies | 78 | 82 |
| Ressources | 15 | 19 |

  13 recettes X0 sont retouchées, et 11 technologies X0 sont étendues.

**2. Ressources par âge** (anciennes : X0 ; nouvelles : X3, en gras). « JEU » = en jeu aujourd'hui.

| Âge | Ressources X0 | Nouvelle (X3) | Traitement → usage |
|---|---|---|---|
| 1 | fer, cuivre, charbon, pierre, bois (vanilla) | — | — |
| 2 | — | — | — |
| 3 | eau (vanilla) | **Blende** : filons des collines rocheuses ; tétraèdres résineux miel à rubis ; 2 gisements de 200 000 garantis à 150-400 tuiles | cornue → zinc (+ laitier) → laiton → manomètre |
| 4 | pétrole (vanilla) | **Cassitérite** : placers au bord de l'eau ; galets brun chocolat à éclats de quartz ; 2 × 150 000 à 120-350 tuiles | four → étain → étamage des cartes, mémoire, carte graphique |
| 5 | tungstène (JEU), fumerolle | — | — |
| 6 | — | **Bauxite** : désert rouge (latérites) ; pisolithes brique-ocre ; 3 × 300 000 à 300-600 tuiles | frittage à la chaux → alumine (+ boue rouge → ciment) → cuve ignée → aluminium |
| 7 | cristal de résonance (JEU) | — | — |
| 8 | méthane (JEU) | — | — |
| 9 | uranium (vanilla), galène | — | — |
| 10 | — (le silicium venait du sable) | **Quartz filonien** : veines blanches de la plaine de cristal (JEU) ; prismes laiteux, sans lueur ; 2 × 200 000 à 400-800 tuiles | four à arc → creuset → tirage du lingot de silicium |
| 11 | ilménite et saumure (JEU), brèche | — | — |
| 12 | monazite, veines de caustique | — | — |
| 13 | évent mantellique | — | — |
| 14 | impacts météoritiques | — | — |
| 15 | failles du Cœur | — | — |

Couleurs de carte à mesurer avec `mesure.py` (règle M1 : ΔE ≥ 48). Trois paires risquent d'être trop proches :
- cassitérite et charbon ;
- bauxite et cuivre ;
- quartz et cristal (sans lueur).

**3. Les trois chaînes** ([machine] entre crochets).

```
A. IMPRIMER LES PUCES
âge 4  : cassitérite → étain ; éthylène + huile lourde → résine époxy
         cuivre + verre + résine → stratifié → [imprimante de circuits] + étain + acide → carte imprimée
         carte imprimée + 2 circuits électroniques + 1 plastique → circuit avancé (variante, à MU égale : 8,7)
âge 7  : cristal taillé + 2 lentilles + 2 bobines + aluminium → laser à cristal
âge 10 : 6 quartz → [four à arc] creuset ; 10 silicium pur + creuset → [tireuse] lingot
         lingot + 2 poudres de cristal + eau → [taillerie, scie à fil] 20 tranches
         résine époxy + huile légère + soufre → résine photosensible
         verre + tungstène + circuit avancé → [salle blanche] photomasque
         [lithographe à cristal : 4 lasers, UV par conversion de fréquence]
           10 tranches + masque + résine photosensible + acide → 10 tranches gravées
         4 gravées + 2 cartes + 4 plastiques → 2 processeurs (variante d'X0 refaite)
         gravée + carte + étain → 2 modules de mémoire
         4 gravées + 2 mémoires + carte + aluminium + étain → carte graphique

B. CALCULER
âge 10 : 10 cartes graphiques + 4 contrôleurs → centre de calcul (10 MW)
         [centre de calcul] 10 eau/s → 50 calcul/s (fluide sans baril, 200 kJ l'unité)
         contrôleur + carte graphique + 2 capteurs + 200 calcul → [atelier de robotique] noyau de pilotage
âge 11 : 3 silicium métallurgique + chlore (boucle déclarée) + hydrogène → 2 silicium pur (procédé Siemens)
âges 13 à 15 : noyaux dans les foreuses profonde et de noyau, la fonderie à plasma, le lanceur, le remorqueur ;
         cartes graphiques dans le radar à réseau phasé (10) et la Porte (15)

C. MONTER DES MACHINES, SE DÉFENDRE
âge 6  : 5 bauxites + pierre + eau → 2 alumines + 2 boues rouges ; boue rouge + pierre → ciment
         [cuve d'électrolyse ignée, 6 MW] 4 alumines + graphite → 2 aluminiums (Hall-Héroult)
         moteur électrique + bobine + 2 engrenages + circuit + aluminium → servomoteur
âge 7  : lentille + 2 oscillateurs + carte → 2 capteurs optiques ; 2 circuits avancés + 2 oscillateurs + carte → contrôleur
         distracteur + laser à cristal + 2 batteries → capsule de drone laser            (robot de défense n° 1)
âge 10 : 2 servomoteurs + capteur + contrôleur + 2 batteries + 20 calcul → [atelier] drone de garde   (n° 2)
âge 12 : servomoteur + 4 aimants permanents + composite → actionneur à aimants
         néodyme + yttrium + 2 alumines → [tireuse] 2 barreaux Nd:YAG ; barreau + lentille + 2 bobines + contrôleur → module laser
         4 actionneurs + noyau + 2 modules laser + 10 composites + 10 batteries → [atelier] robot de combat   (n° 3)
```

**4. Objets nouveaux** : 32 objets, dont 3 fluides. Aucun n'est sans usage (contrôlé).

| Âge | Objet | Rôle | Consommé par |
|---|---|---|---|
| 3 | Blende, Plaque de zinc, Laiton | minerai, matière ρ1, alliage | laiton ; manomètre (tube de Bourdon) |
| 4 | Cassitérite, Plaque d'étain | minerai, matière ρ1 | carte imprimée, mémoire, carte graphique |
| 4 | Résine époxy (fluide, baril) | liant | stratifié ; résine photosensible (10) |
| 4 | Stratifié cuivré, Carte de circuit imprimé | support, **impression des cartes** | circuit avancé sur carte, Codex IV ; capteur, contrôleur (7) ; processeur, mémoire, carte graphique (10) |
| 6 | Bauxite, Alumine, Boue rouge, Plaque d'aluminium | minerai, intermédiaire, sous-produit, matière ρ1 | électrolyse ignée, ciment ; servomoteur, pylône HT, laser (7), carte graphique (10) ; barreau Nd:YAG (12) |
| 6 | Servomoteur | actionneur, 1re génération | atelier de robotique, drone de garde (10) ; actionneur à aimants (12) |
| 7 | Laser à cristal | **premier laser** (la lentille sert enfin à un laser) | drone laser ; lithographe à cristal (10) |
| 7 | Capteur optique, Contrôleur programmable | la vue et le cerveau des machines | atelier, noyau, drone de garde, centre de calcul (10) ; module laser (12) |
| 7 | Capsule de drone laser | robot de défense n° 1 | lancée (munition) |
| 10 | Quartz filonien, Creuset de quartz, Lingot monocristallin | minerai, consommable du tirage, tirage Czochralski | tranches de silicium |
| 10 | Résine photosensible (fluide, baril), Photomasque, Tranche gravée | lithographie | processeur, mémoire, carte graphique |
| 10 | Module de mémoire, **Carte graphique** | puces | centre de calcul, noyau, radar à réseau phasé, Porte (15) |
| 10 | **Calcul** (fluide, sans baril) | ressource produite comme l'électricité | noyau de pilotage (200), drone de garde (20) |
| 10 | Noyau de pilotage | cerveau programmé | robot de combat (12) ; foreuses profonde et de noyau, fonderie à plasma (13) ; lanceur et remorqueur (14) |
| 10 | Capsule de drone de garde | robot de défense n° 2 | lancée (munition) |
| 12 | Actionneur à aimants | actionneur, 2e génération : l'aimant permanent entre enfin dans un moteur | robot de combat, unité cryogénique, foreuses, fonderie à plasma |
| 12 | Barreau laser Nd:YAG, Module laser | milieu laser (Y, Nd et alumine) ; arme et outil laser | robot de combat, foreuse de noyau (forage laser) |
| 12 | Robot de combat | robot de défense n° 3 | lancé (unité) |

Objets X0 qui gagnent des usages : alumine (Nd:YAG), poudre de cristal (abrasif de la scie à fil), lentille
(laser, capteur, module laser), oscillateur (capteur, contrôleur), aimant permanent (actionneur), yttrium et
néodyme (Nd:YAG), hydrogène et chlore (Siemens), résine et étain dans quatre chaînes.

**5. Bâtiments nouveaux** (6). Image provisoire : une copie teintée d'une machine vanilla, donc 0 page
d'atlas en plus.

| Âge | Bâtiment | Taille | Puissance | Catégorie | Fluides | Niveaux |
|---|---|---|---|---|---|---|
| 4 | Imprimante de circuits | 3×3 | 300 kW | `fo-circuit-printing` | 1 entrée | assembleurs |
| 6 | Cuve d'électrolyse ignée (la plus gourmande de l'âge 6) | 4×4 | 6 MW | `fo-fused-salt-electrolysis` | — | fours |
| 10 | Tireuse de cristal (lingot de silicium, barreau Nd:YAG) | 3×3 | 1,5 MW | `fo-crystal-pulling` | — | fours |
| 10 | Lithographe à cristal | 4×4 | 6 MW | `fo-lithography` | 2 entrées | assembleurs |
| 10 | Centre de calcul (recette fixe) | 4×4 | 10 MW | `fo-computing` | 1 + 1 | procédés |
| 10 | Atelier de robotique | 5×5 | 2,5 MW | `fo-robotics` | 1 entrée (calcul) | assembleurs |

**6. Technologies.** Les packs et les unités sont calculés comme dans X0.

Quatre technologies nouvelles, une par âge au plus :

| Technologie | Âge | Prérequis |
|---|---|---|
| Circuits imprimés | 4 | vapocraquage |
| Aluminium et servomoteurs | 6 | fusion à l'arc, tôle magnétique |
| Calcul et robotique | 10 | silicium |
| Robots de combat | 12 | pack magnétique, calcul |

Onze technologies X0 sont étendues :
- **Verrerie** devient « Verrerie et laiton » (zinc et laiton).
- **Pack de résonance** : capteur et contrôleur.
- **Amplificateur de résonance** devient « Amplificateur de résonance et laser à cristal » (laser et drone laser).
- **Silicium** devient « Silicium et fonderie de puces » (8 recettes).
- **Tungstène par voie humide** devient « Voie humide : tungstène et silicium » (procédé Siemens). En jeu, `T.TECHS` du titane n'est PAS changé.
- **Pack magnétique** : actionneur. L'unité cryogénique, débloquée ici, en a besoin.
- **Prérequis ajoutés** :
  - haute tension ← aluminium ;
  - radar à réseau phasé ← calcul ;
  - Codex IV ← circuits imprimés et asphalte.
- **Trois défauts d'X0 trouvés par `x3_test`** : un objet du même âge était requis hors des prérequis de sa technologie. Ils sont réparés dans la fusion :
  - l'asphalte du Codex IV ;
  - le ferronickel du superalliage (prérequis : météoritique) ;
  - les miroirs d'iridium du Codex XIV (prérequis : optique à l'iridium).

**Recalage de la recherche** (fusion seulement), pour garder la règle des 30 à 40 % du budget, visée 35 % :

| Âge | Unités X0 | Unités fusion | Part sans recalage | Raison |
|---|---|---|---|---|
| 4 | 100 | 77 | 40,1 % (hors règle) | technologie nouvelle |
| 6 | 180 | 146 | 39,3 % | technologie nouvelle |
| 10 | 1 175 | 1 040 | 37,3 % | technologie nouvelle |
| 11 | 3 760 | 3 910 | 33,6 % | packs moins chers |
| 12 | 5 950 | 5 790 | 36,0 % | technologie nouvelle |
| 13 | 10 200 | 11 630 | 30,9 % | packs moins chers |
| 14 | 12 430 | 13 820 | 31,6 % | packs moins chers |
| 15 | 184 100 | 207 800 | 31,0 % | packs moins chers |

Avec ces valeurs, chaque âge est à 35,0 %.

**7. Retouches de recettes X0** (13). Elles approfondissent sans rien remplacer : chaque recette garde son nom, son âge et sa technologie.
- **Manomètre** (3) : + 1 laiton (tube de Bourdon).
- **Codex IV** (4) : + 10 cartes imprimées.
- **Pylône haute tension** (6) : 4 aluminiums à la place de 4 câbles (conducteur aluminium-acier).
- **Tranche de silicium** (10) : 1 lingot + 2 poudres de cristal + 40 eau → 20 tranches, à la taillerie. Avant : 1 silicium pur → 4 tranches, en salle blanche.
- **Processeur en salle blanche** (10) : 4 tranches gravées + 2 cartes + 4 plastiques → 2 processeurs. Avant : 10 circuits verts + 2 circuits avancés + 1 tranche + acide.
- **Radar à réseau phasé** (10) : 2 cartes graphiques à la place de 4 processeurs.
- **Unité cryogénique** (12) : 3 actionneurs à la place de 10 moteurs électriques.
- **Foreuse profonde** et **fonderie à plasma** (13) : 3 actionneurs et 1 noyau à la place de 10 processeurs. La fusion exige donc le calcul (pilotage du plasma).
- **Foreuse de noyau** (13) : 6 actionneurs, 2 noyaux et 2 modules laser à la place de 20 processeurs et 20 carbures.
- **Lanceur orbital** (14) : 10 noyaux à la place de 40 processeurs.
- **Remorqueur orbital** (14) : 1 noyau à la place de 4 processeurs.
- **Porte d'Érèbe** (15) : 10 cartes graphiques à la place de 40 processeurs.

Aucune retouche ne vise une recette que `shared/content/titanium.lua` lit ou déplie (contrôlé ; mutant refusé).

**8. Les usages : pourquoi monter ces chaînes.**

*Robots de défense* : trois robots, par la mécanique vanilla des capsules, sans script à chaque tick.

| Âge | Robot | Mécanique | Rôle |
|---|---|---|---|
| 7 | Drone laser | capsule → `combat-robot` à faisceau laser, qui suit son lanceur 3 min | escorte |
| 10 | Drone de garde | capsule → `combat-robot` laser, `follows_player = false`, 10 min | garde un point, ravitaillé par l'usine |
| 12 | Robot de combat | capsule → `unit` de la force du lanceur | tient un avant-poste, escorte une expédition |

*Calcul* :
- **Production.** Une ressource produite comme l'électricité : 10 MW donnent 50 unités/s, soit 200 kJ l'unité. L'eau évaporée sert de refroidissement, sans sous-produit à évacuer.
- **Transport.** Par tuyau seulement (sans baril). L'atelier de robotique se pose donc à côté du centre de calcul.
- **Usage.**
  - Noyau de pilotage : 200 calculs, soit 40 MJ.
  - Drone de garde : 20 calculs.
  - Par les noyaux : foreuses, fonderie à plasma, lanceur.

*Machines montées* :
- Les pièces de 1re génération : servomoteur (6), capteur et contrôleur (7).
- Celles de 2e génération : actionneur à aimants, module laser (12).
- Elles entrent dans 6 bâtiments X0 des âges 12 à 14, à la place de processeurs et de moteurs.

*Valeurs en MU* : chemin le moins cher, calculé par `epochs_test` sur la fusion.

Pièces nouvelles :

| Objet | MU |
|---|---|
| Aluminium | 4,0 |
| Carte imprimée | 2,9 |
| Servomoteur | 29,8 |
| Laser à cristal | 30,2 |
| Capteur optique | 6,0 |
| Contrôleur programmable | 24,8 |
| Tranche gravée | 6,0 |
| Carte graphique | 43,7 |
| Noyau de pilotage | 80,6 |
| Actionneur à aimants | 48,9 |
| Module laser | 49,7 |
| Drone laser | 254 |
| Drone de garde | 99 |
| Robot de combat | 510 |

Le **processeur** coûte 16,6 MU par la voie gravée, contre 22,5 par la salle blanche d'X0 et 68 en vanilla. La valeur de la monnaie de l'âge 10 (75) reste au-dessus de ce coût.

Effet sur les **packs** (MU), aux âges qui bougent :

| Âge | X0 | Fusion |
|---|---|---|
| 10 (vanilla) | 32,0 | 28,1 |
| 11 | 115,7 | 109,8 |
| 12 | 146,9 | 129,2 |
| 13 | 157,5 | 134,0 |
| 14 (vanilla) | 105,5 | 99,0 |
| 15 | 111,4 | 102,6 |

La règle « pack nouveau ≥ pack précédent » reste tenue. Les marges les plus faibles sont entre les âges 14 et 15
(3,6 MU : pack exotique 102,6 contre pack spatial vanilla 99,0) et entre les âges 12 et 13 (4,8 MU) : toute baisse
nouvelle du processeur ou de la bobine supraconductrice se vérifie sur ces deux marges.

**9. Cerveau général et vérification** (27/10, worktree x3).
- **Lisible sans chemin en dur.**
  - Chaque catégorie nouvelle est servie par une machine.
  - Les recettes à la main sont des solides à produit unique.
  - Aucun cycle par produits principaux : le photomasque ne prend pas de processeur, et le chlore de Siemens est un catalyseur déclaré.
  - Aucune étape de la ligne principale n'est un script.
  - Les drones sont des munitions, que le cerveau lit comme telles.
- **Dépliage par le prototype du cerveau (`shared/ai3/graphe.lua`, `G.unfold`).** Mesure faite tout débloqué, toutes ressources connues, rien de construit. Profondeur maximale d'une chaîne : 14, dans X0 comme dans la fusion (la limite est de 64 passes). Faisabilité en 20 passes (17 dans X0).

  Nœuds pour 1 pack de chaque âge, X0 → fusion :

  | Âges | Nœuds X0 → fusion |
  |---|---|
  | 1 à 3 | 43-56 → 63-76 |
  | 4 à 9 | 150-309 → 170-328 |
  | 10 | 372 → 273 |
  | 11 à 13 | 1 123-1 179 → 1 660-1 698 |
  | 14 | 481 → 372 |
  | 15 | 2 158 → 2 560 |

  Cibles des trois chaînes :

  | Cible | Nœuds |
  |---|---|
  | Carte graphique | 584 |
  | Noyau de pilotage | 890 |
  | Robot de combat | 1 848 |

  **Aucun dépassement de 4 000 nœuds**, et tout reste payable. La hausse aux âges 1 à 3 vient du manomètre : le marteau-pilon demande désormais une ligne de zinc.
- **`lua5.2 tests/x3_test.lua` → [X3] BILAN : 5 084 OK, 0 ECHEC(S).** Il vérifie :
  - la fermeture ;
  - les usages ;
  - les recettes orphelines ;
  - les prérequis ;
  - le déblocage sur toute la fusion ;
  - la lisibilité par le cerveau ;
  - la concentration ;
  - la garde du titane ;
  - 11 mutants refusés : recettes cassées (3), objets sans usage (2), prérequis inversé, en cycle et postérieur, recette orpheline, retouche du titane, cycle de production.
- **`epochs_test` rejoué par ce banc** :
  - sur X seul : 16 665 OK ;
  - sur la fusion : 18 573 OK et 10 échecs. Ce sont tous des blocs `GEN:` de ce document, qui décrit X seul : c'est attendu.
- **Autres bancs, sur X seul et sur la fusion** : `titanium_test` 114 OK, `monde_test` 201 OK, `org_test` 366 OK, identiques.
- **`levels_test`** : sortie identique sur X seul et sur la fusion (1 663 OK). Les 3 échecs viennent des feuilles PNG absentes du worktree (D-6).

**10. Ce qui n'est PAS fait.**
- **Rien en jeu** : aucun prototype, aucune locale, aucune garantie de placement, aucun kit minerai M1, aucune image. Le jeu ne change pas, et `epochs.lua` non plus.
- **Écarté, ou laissé à plus tard** :
  - lithographie EUV, imprimante 3D métal, carte multicouche et plaque froide : ce serait un 4e endroit lourd ;
  - procédé Bayer et spath fluor : la soude n'arrive qu'à l'âge 11 ;
  - latérite (nickel, cobalt), spodumène (lithium), gallium, germanium, argent de la galène, barytine : des usages uniques ;
  - lance-drones et obus guidé : comportement moteur non prouvé ;
  - laboratoire accéléré par le calcul : un laboratoire 1.1.91 ne prend pas de fluide ;
  - pack d'utilité simulé : il baisserait un pack ;
  - cadre de robot piloté : plus cher que le vanilla.
- **Non décidé** :
  - payer une part des niveaux en pièces montées (fichier de l'intégrateur, Q-X3-3) ;
  - rendre la fonderie obligatoire (Q-X3-1) ;
  - le comportement des robots de combat (Q-X3-2).
- **À prouver en moteur réel** :
  - H-X3-1 : le drone né d'une capsule combat dans la force du lanceur ;
  - H-X3-2 : l'unité tient sa place sans commande ;
  - H-X3-3 : le calcul ne se mêle pas à l'eau.
- **Mémoire vidéo** (l'atlas virtuel est plein au plancher, F186). Pour intégrer :
  - 4 kits minerai ;
  - 6 bâtiments, en copies teintées ;
  - 32 icônes (F125).

  Il faudra mesurer au plancher, minerai par minerai, avec `d4-geant --measure`.
- **Pour intégrer** :
  - Recopier les entrées de `x3.lua` dans les sections d'`epochs.lua`, en plaçant chaque recette nouvelle APRÈS celle d'X0 qui fait le même objet. C'est le cas du ciment, du silicium pur et du circuit avancé. Sinon `T.maker` change.
  - Puis `--write-doc`.
  - Puis les entrées de `world.lua`, les garanties M0, les kits M1, les prototypes et les locales.
  - Enfin, régénérer les fixtures du cerveau : `recipes_ia1e`, `tech_ai3` et `entities_ai3`.

**11. Origine des idées** (synthèse de trois concepteurs).
- **Retenu de « puces, optique, impression et calcul »** :
  - l'imprimerie des cartes à l'âge 4 ;
  - le laser à cristal (UV par conversion de fréquence) ;
  - le creuset, le lingot, la résine photosensible, le photomasque, la tranche gravée et la mémoire ;
  - le processeur gravé ;
  - le centre de calcul et le calcul comme fluide ;
  - le procédé Siemens à l'âge 11 ;
  - les cartes graphiques dans la Porte ;
  - le drone laser de l'âge 7 (distracteur et laser à cristal).
- **Retenu de « minerais et géologie par âge »** :
  - la blende et le laiton du manomètre ;
  - la cassitérite (étain) ;
  - la bauxite, le frittage à la chaux, la boue rouge en ciment et la cuve Hall-Héroult ;
  - le quartz filonien ;
  - le barreau Nd:YAG à l'alumine ;
  - le pylône à l'aluminium ;
  - la poudre de cristal, abrasif de la scie à fil.
- **Retenu de « usages, machines assemblées et robots de défense »** :
  - le servomoteur, le capteur, le contrôleur ;
  - le noyau de pilotage, l'atelier de robotique et le drone de garde ;
  - l'actionneur à aimants, le module laser et le robot de combat ;
  - les 6 substitutions des âges 12 à 14 ;
  - la méthode de preuve par fusion en fin de liste.
- **Tranché** :
  - la « carte de calcul » et la « carte graphique » ne font qu'un objet ;
  - plus de processeur dans le photomasque, pour éviter un cycle ;
  - pas de creuset de quartz dans le Nd:YAG : en réalité, c'est un creuset d'iridium ;
  - un seul minerai par âge, alors que la proposition « minerais » en mettait huit.

---

## 4. Compaction, énergie, niveaux, recherche, boucle idle

### 4.1 Compaction ×4 (BALANCE_SHEET §3 ; un palier toutes les 3 époques, Q5)

| Palier | Époque | Tapis | ρ | Forme dense | Ligne principale (foreuse → transformation) |
|---|---|---|---|---|---|
| T1 | 1 | 15/s | 1 | plaque (vanilla) | foreuses vanilla, foreuse à vapeur (3), fours |
| T2 | 4 | 30/s | 2 | « paquet » | tapis rouge vanilla ; formes du lot C |
| T3 | 7 | 60/s | 4 | « lingot » | formes du lot C |
| T4 | 10 | 120/s | 8 | « billette » ou « concentré » | **foreuse de concentré** (vitesse de minage 30, 5×5) → **concentrateur** accolé 1:1 (vitesse 3,75 : 8 minerais → 1 concentré) → four à arc (0,533 s, 30 MU/s) ; découpe : billette → 8 plaques |
| T5 | 13 | 120/s | 32 | « bloc » | **foreuse de noyau** (vitesse de minage 120, 7×7) → **fonderie à plasma** accolée (32 minerais + 0,5 plasma → 1 bloc en 0,267 s, 120 MU/s) ; ou 4 concentrés + 0,5 plasma → 1 bloc ; découpe : bloc → 4 billettes |

- **Plan B1 tenu** (« des foreuses de concentré aux paliers hauts ») : à chaque palier, la meilleure foreuse
  de la ligne principale atteint au moins la moitié du débit par machine du modèle (30 MU/s en T4, 120 en T5),
  et le nombre de foreuses reste sous 2 000 à toutes les époques (117 foreuses de noyau pour 14 000 MU/s à
  l'époque 15 ; contrôlé par le banc). Les minerais durs (temps de minage 2) sortent à moitié de cadence.
- **Débit et énergie de chaque recette dense** (contrôlés) : toute recette dont le produit est une matière ρ8
  ou ρ32 tient au moins 0,5 × le débit par machine de son palier et au plus 2 × son énergie par MU (plasma
  compris). Les durées ont été recalibrées : fonte de concentré 0,533 s (tungstène 1,066 s), fusion de
  l'ilménite 1 s, Kroll 0,5 s, refusion du titane 0,533 s, dégazage 0,267 s, concassage météoritique 1,6 s,
  blocs et superalliage 0,267 s à la fonderie (0,5 plasma au lieu de 20). Four à arc : 4,4 MW (147 kJ/MU).
- **Règle anti-explosion + « densité née du palier »** (`X.dense_forms`) : une matière née à l'époque e avec
  la densité ρ n'existe qu'en ρ et aux densités des paliers strictement supérieurs. Le **titane, l'ilménite et
  la monazite naissent en ρ8**, le **superalliage en ρ32**.
- **Recettes denses** : 48 variantes pour le lot C, plus les intermédiaires denses ρ8 et ρ32.
- **Jamais de productivité** sur la compaction, la décompaction, la catalyse, la conversion ni la
  transmutation (contrôlé).

### 4.2 Énergie : chaque palier arrive avec sa source (MW calculés sur les recettes)

<!-- GEN:energy -->
| Palier | Tapis | Chaîne (sur les recettes) | MW électriques par tapis | MW de chaleur par tapis | Source de l'époque |
|---|---|---|---|---|---|
| T1 (ép. 1) | 15/s ρ1 = 15 MU/s | formes du lot C (modèle BALANCE_SHEET §3) | 4,3 (modèle) | — | vapeur : 1,8 MW par chaudière |
| T2 (ép. 4) | 30/s ρ2 = 60 MU/s | formes du lot C (modèle BALANCE_SHEET §3) | 13,8 (modèle) | — | géothermie : 4,2 MW par fumerolle |
| T3 (ép. 7) | 60/s ρ4 = 240 MU/s | formes du lot C (modèle BALANCE_SHEET §3) | 44,2 (modèle) | — | turbine à gaz 10 MW ; fission 40 MW |
| T4 (ép. 10) | 120/s ρ8 = 960 MU/s | 32 Four à arc + 32 Concentrateur + 32 Foreuse de concentré | 285 | 0 | sels fondus : 1,8 réacteur(s) de 160 MW par tapis |
| T5 (ép. 13) | 120/s ρ32 = 3 840 MU/s | 32 Fonderie à plasma + 32 Foreuse de noyau | 576 | 299 | fusion : 1,1 réacteur(s) de 800 MW par tapis |
<!-- /GEN:energy -->

- L'énergie par MU **ne remonte plus** aux paliers hauts (147 kJ/MU par machine en T4, 161 en T5 avec la
  chaleur du plasma) : « l'énergie suit » (Q5). Une chaîne compte plusieurs étages (foreuse, concentrateur,
  four), d'où un total par tapis supérieur au seul étage du modèle (141,6 et 453 MW).
- **Chaîne de chaleur (corrigée)** : les trois réacteurs nouveaux déclarent `neighbour_bonus = 0` (1 par
  défaut en 1.1.91, soit +100 % par voisin), une `max_temperature` (1 000 °C pour les sels fondus, 5 000 °C
  pour la fusion et l'annihilation) et un `max_transfer` au moins égal à leur puissance. Tout consommateur de
  chaleur exige moins que la température maximale de sa source (contrôlé). Le plasma : température par défaut
  15 °C, maximale 5 000 °C, capacité 1 kJ/°C.
- **Règle d'énergie (P5, contrôlée)** : un combustible fabriqué rend moins que ce qu'il coûte, sauf une liste
  blanche écrite : fission, fusion, annihilation (fiction déclarée), méthane de digesteur.
- L'**hydrogène, l'éthylène et l'ergol cryogénique n'ont aucune valeur de combustion**.
- **Orbitale** : une centrale solaire orbitale donne **200 MW**, reçus par **une** rectenna (200 MW de
  capacité) : la rectenna est dimensionnée pour une centrale.

### 4.3 Niveaux des bâtiments (V2), monnaies, ouvriers
- Centre de commandement : niveau = époque (1 à 15). Bâtiments : niveau maximal = 2 × niveau du centre (Q6).
- Monnaies au format V2 (§3.1) ; Codex k exigé pour passer le centre au niveau k+1 (diff au §10).
- ~~**Ouvriers** : 1 à 5 (un de plus toutes les 3 époques), +1 avec l'Horloge éternelle (QX6).~~ **Sans objet
  depuis Q19** (amélioration instantanée dès que le coût est payé, lot V2c) ; la colonne « Ouvriers » du
  tableau du §4 est à retirer de son générateur (`tests/epochs_test.lua --write-doc`).
- **Chantiers de zone** (à valider par V2, `X.zone_upgrade`) : un ouvrier améliore jusqu'à 10 bâtiments
  identiques dans un rayon de 20 tuiles, durée ×(1 + 0,1 × (N − 1)), coût ×N ; défenses à l'unité. Depuis
  Q19 : ni ouvrier ni durée ; une amélioration de zone instantanée (coût ×N) reste possible, à décider avec
  Q-V2c-2.
- **Volume des niveaux** : voir §3.3 et §5.5 (environ 730 entités de niveau et autant d'objets).

### 4.4 Recherche : l'arbre des technologies nouvelles

- **Packs** : 7 vanilla (automatisation 1, logistique 2, militaire 3, chimique 4, production 6, utilitaire 10,
  espace 14) et 8 nouveaux (géologique 5, résonance 7, biochimique 8, isotopique 9, structurel 11, magnétique
  12, plasma 13, exotique 15), plus 4 données de branche.
- **Fenêtre glissante** (`X.pack_window`, doublon du pack militaire corrigé) : jamais plus de 4 sortes de
  packs par technologie. Une technologie de pack se paie avec la fenêtre de l'époque précédente, et le banc
  vérifie que le pack se fabrique avec ce qu'elle débloque.
- **Coût des packs** : chaque pack nouveau coûte au moins autant que celui de l'époque précédente (MU des
  packs, de l'époque 1 à 15 : 2,5 ; 6,2 ; 22,8 ; 19,9 ; 23,6 ; 69,7 ; 87,4 ; 94 ; 104 ; 32 ; 116 ; 147 ;
  158 ; 106 ; 111). Les baisses aux époques 4, 10 et 14 sont des packs **vanilla inchangés** (QX4).
- **Coût par palier** : la recherche consomme 35 % du budget de chaque époque, et croît de ×7,4 à ×13,8
  d'un palier au suivant (au moins ×4, BALANCE_SHEET §4.5 ; contrôlé).
- **Arbre** : 78 technologies nouvelles (dont 13 de branche et 4 maîtrises), 8 recherches infinies, 14 verrous
  `fo-epoch-k`, plus environ 190 technologies vanilla re-rangées. Chaque recette nouvelle est débloquée par
  **exactement une** technologie de son époque (contrôlé) ; le graphe des prérequis est sans cycle.

<!-- GEN:techs -->
| Technologie | Ép. | Rôle | Prérequis | Packs | Unités | Recettes débloquées |
|---|---|---|---|---|---|---|
| Journal du pionnier | 1 | Codex | verrou fo-epoch-1 | Pack d'automatisation | 275 | 1 |
| Cokéfaction | 2 | — | verrou fo-epoch-2 | Pack logistique, Pack d'automatisation | 90 | 2 |
| Haut fourneau | 2 | — | Cokéfaction | Pack logistique, Pack d'automatisation | 90 | 2 |
| Concassage | 2 | — | Haut fourneau | Pack logistique, Pack d'automatisation | 90 | 3 |
| Carnet de forge | 2 | Codex | Concassage | Pack logistique, Pack d'automatisation | 45 | 1 |
| Verrerie | 3 | — | Concassage | Pack militaire, Pack logistique, Pack d'automatisation | 65 | 2 |
| Forge à vapeur | 3 | — | Verrerie | Pack militaire, Pack logistique, Pack d'automatisation | 65 | 3 |
| Béton au ciment | 3 | — | Concassage | Pack militaire, Pack logistique, Pack d'automatisation | 65 | 1 |
| Registre des chaudières | 3 | Codex | Forge à vapeur | Pack militaire, Pack logistique, Pack d'automatisation | 33 | 1 |
| Torchère | 4 | — | Verrerie | Pack chimique, Pack militaire, Pack logistique | 100 | 2 |
| Vapocraquage | 4 | — | Torchère | Pack chimique, Pack militaire, Pack logistique | 100 | 3 |
| Asphalte | 4 | — | verrou fo-epoch-4 | Pack chimique, Pack militaire, Pack logistique | 100 | 1 |
| Relevés de forage | 4 | Codex | Vapocraquage | Pack chimique, Pack militaire, Pack logistique | 50 | 1 |
| Pack géologique | 5 | pack | verrou fo-epoch-5 | Pack chimique, Pack militaire, Pack logistique | 290 | 4 |
| Géothermie | 5 | — | verrou fo-epoch-5 | Pack géologique, Pack chimique, Pack militaire | 290 | 3 |
| Forage lourd | 5 | — | verrou fo-epoch-5 | Pack géologique, Pack chimique, Pack militaire | 290 | 1 |
| Atlas des cendres | 5 | Codex | Géothermie, Forage lourd | Pack géologique, Pack chimique, Pack militaire | 145 | 1 |
| Fusion à l'arc | 6 | — | verrou fo-epoch-6 | Pack de production, Pack géologique, Pack chimique | 180 | 3 |
| Tôle magnétique et bobinage | 6 | — | Fusion à l'arc | Pack de production, Pack géologique, Pack chimique | 180 | 5 |
| Haute tension | 6 | — | Tôle magnétique et bobinage | Pack de production, Pack géologique, Pack chimique | 180 | 1 |
| Broyeur à mâchoires | 6 | — | Tôle magnétique et bobinage | Pack de production, Pack géologique, Pack chimique | 180 | 1 |
| Schémas du réseau | 6 | Codex | Haute tension | Pack de production, Pack géologique, Pack chimique | 90 | 1 |
| Pack de résonance | 7 | pack | verrou fo-epoch-7 | Pack de production, Pack géologique, Pack chimique | 255 | 5 |
| Amplificateur de résonance | 7 | — | verrou fo-epoch-7 | Pack de résonance, Pack de production, Pack géologique | 255 | 1 |
| Énergie cristalline | 7 | — | verrou fo-epoch-7 | Pack de résonance, Pack de production, Pack géologique | 255 | 3 |
| Partitions du cristal | 7 | Codex | Énergie cristalline | Pack de résonance, Pack de production, Pack géologique | 128 | 1 |
| Matière noire I : résonateur de caustique | 7 | A branche I | verrou fo-epoch-7 | Pack de résonance, Pack de production, Pack géologique | 383 | 3 |
| Pack biochimique | 8 | pack | verrou fo-epoch-8 | Pack de résonance, Pack de production, Pack géologique | 720 | 11 |
| Reformage du méthane | 8 | — | verrou fo-epoch-8 | Pack biochimique, Pack de résonance, Pack de production | 720 | 2 |
| Turbine à gaz | 8 | — | verrou fo-epoch-8 | Pack biochimique, Pack de résonance, Pack de production | 720 | 1 |
| Digesteur et carbonatation | 8 | — | verrou fo-epoch-8 | Pack biochimique, Pack de résonance, Pack de production | 720 | 2 |
| Herbier du marais | 8 | Codex | Reformage du méthane | Pack biochimique, Pack de résonance, Pack de production | 360 | 1 |
| Pack isotopique | 9 | pack | verrou fo-epoch-9 | Pack biochimique, Pack de résonance, Pack de production | 710 | 3 |
| Grillage de la galène | 9 | — | verrou fo-epoch-9 | Pack isotopique, Pack biochimique, Pack de résonance | 710 | 1 |
| Combustible usé | 9 | — | verrou fo-epoch-9 | Pack isotopique, Pack biochimique, Pack de résonance | 710 | 4 |
| Cahier du réacteur | 9 | Codex | Combustible usé | Pack isotopique, Pack biochimique, Pack de résonance | 355 | 1 |
| Antimatière I : positons | 9 | B branche I | verrou fo-epoch-9 | Pack isotopique, Pack biochimique, Pack de résonance | 1 065 | 7 |
| Silicium et salle blanche | 10 | — | verrou fo-epoch-10 | Pack utilitaire, Pack isotopique, Pack biochimique | 1 175 | 5 |
| Radar à réseau phasé | 10 | — | Silicium et salle blanche | Pack utilitaire, Pack isotopique, Pack biochimique | 1 175 | 1 |
| Foreuses de concentré (T4) | 10 | — | verrou fo-epoch-10 | Pack utilitaire, Pack isotopique, Pack biochimique | 1 175 | 5 |
| Billettes ρ8 | 10 | — | Foreuses de concentré (T4) | Pack utilitaire, Pack isotopique, Pack biochimique | 1 175 | 6 |
| Plans de la salle blanche | 10 | Codex | Silicium et salle blanche, Billettes ρ8 | Pack utilitaire, Pack isotopique, Pack biochimique | 588 | 1 |
| Chronodynamique I : cristal temporel | 10 | C branche I | Silicium et salle blanche | Pack utilitaire, Pack isotopique, Pack biochimique | 1 763 | 4 |
| Pack structurel (titane) | 11 | pack | verrou fo-epoch-11 | Pack utilitaire, Pack isotopique, Pack biochimique | 3 760 | 13 |
| Cryostat | 11 | — | verrou fo-epoch-11 | Pack structurel, Pack utilitaire, Pack isotopique | 3 760 | 2 |
| Tungstène par voie humide | 11 | — | verrou fo-epoch-11 | Pack structurel, Pack utilitaire, Pack isotopique | 3 760 | 1 |
| Structures légères | 11 | — | verrou fo-epoch-11 | Pack structurel, Pack utilitaire, Pack isotopique | 3 760 | 3 |
| Carte des cratères | 11 | Codex | Structures légères | Pack structurel, Pack utilitaire, Pack isotopique | 1 880 | 1 |
| Matière étrange I : inclusions | 11 | D branche I | verrou fo-epoch-11 | Pack structurel, Pack utilitaire, Pack isotopique | 5 640 | 3 |
| Chronodynamique II : verrouillage de phase | 11 | C branche II | Chronodynamique I : cristal temporel, Cryostat | Données chronométriques, Pack structurel | 7 520 | 6 |
| Pack magnétique | 12 | pack | verrou fo-epoch-12 | Pack structurel, Pack utilitaire, Pack isotopique | 5 950 | 12 |
| Hélium | 12 | — | verrou fo-epoch-12 | Pack magnétique, Pack structurel, Pack utilitaire | 5 950 | 4 |
| Sels fondus au thorium | 12 | — | verrou fo-epoch-12 | Pack magnétique, Pack structurel, Pack utilitaire | 5 950 | 3 |
| Stockage supraconducteur | 12 | — | verrou fo-epoch-12 | Pack magnétique, Pack structurel, Pack utilitaire | 5 950 | 3 |
| Maglev | 12 | — | Stockage supraconducteur | Pack magnétique, Pack structurel, Pack utilitaire | 5 950 | 1 |
| Traité des aimants | 12 | Codex | Sels fondus au thorium | Pack magnétique, Pack structurel, Pack utilitaire | 2 975 | 1 |
| Matière noire II : haloscope | 12 | A branche II | Matière noire I : résonateur de caustique, Hélium | Relevé gravimétrique, Pack magnétique | 11 900 | 7 |
| Chronodynamique II : cristal à l'hélium liquide | 12 | C branche II | Chronodynamique II : verrouillage de phase, Hélium | Données chronométriques, Pack magnétique | 11 900 | 1 |
| Fusion D-³He et pack plasma | 13 | pack | verrou fo-epoch-13 | Pack magnétique, Pack structurel, Pack utilitaire | 10 200 | 15 |
| Turbine MHD | 13 | — | verrou fo-epoch-13 | Pack plasma, Pack magnétique, Pack structurel | 10 200 | 1 |
| Dégazage du régolithe | 13 | — | verrou fo-epoch-13 | Pack plasma, Pack magnétique, Pack structurel | 10 200 | 2 |
| Coulée au plasma (T5) | 13 | — | verrou fo-epoch-13 | Pack plasma, Pack magnétique, Pack structurel | 10 200 | 7 |
| Journal du confinement | 13 | Codex | Turbine MHD | Pack plasma, Pack magnétique, Pack structurel | 5 100 | 1 |
| Antimatière II : antihydrogène | 13 | B branche II | Antimatière I : positons | Données d'annihilation, Pack plasma | 20 400 | 8 |
| Matière étrange II : strangelets | 13 | D branche II | Matière étrange I : inclusions | Données hadroniques, Pack plasma | 20 400 | 17 |
| Superalliage | 14 | — | verrou fo-epoch-14 | Pack espace, Pack plasma, Pack magnétique | 12 430 | 2 |
| Météoritique | 14 | — | verrou fo-epoch-14 | Pack espace, Pack plasma, Pack magnétique | 12 430 | 2 |
| Lanceur orbital | 14 | — | verrou fo-epoch-14 | Pack espace, Pack plasma, Pack magnétique | 12 430 | 6 |
| Énergie orbitale | 14 | — | Lanceur orbital | Pack espace, Pack plasma, Pack magnétique | 12 430 | 2 |
| Optique à l'iridium | 14 | — | Météoritique | Pack espace, Pack plasma, Pack magnétique | 12 430 | 1 |
| Bouclier de déviation | 14 | — | Superalliage | Pack espace, Pack plasma, Pack magnétique | 12 430 | 1 |
| Archives orbitales de l'Arche | 14 | Codex | Lanceur orbital, Superalliage | Pack espace, Pack plasma, Pack magnétique | 6 215 | 1 |
| Maîtrise de la matière noire | 14 (15 sans Serment) | A maîtrise (Serment) | Matière noire II : haloscope, Superalliage | Relevé gravimétrique, Pack espace | 37 290 | 3 |
| Maîtrise de l'antimatière | 14 (15 sans Serment) | B maîtrise (Serment) | Antimatière II : antihydrogène, Superalliage, Lanceur orbital | Données d'annihilation, Pack espace | 37 290 | 4 |
| Maîtrise de la chronodynamique | 14 (15 sans Serment) | C maîtrise (Serment) | Chronodynamique II : cristal à l'hélium liquide, Superalliage | Données chronométriques, Pack espace | 37 290 | 2 |
| Maîtrise de la matière étrange | 14 (15 sans Serment) | D maîtrise (Serment) | Matière étrange II : strangelets, Superalliage | Données hadroniques, Pack espace | 37 290 | 3 |
| Matière exotique et pack exotique | 15 | pack | Matière noire II : haloscope, Antimatière II : antihydrogène, Chronodynamique II : verrouillage de phase, Matière étrange II : strangelets, Optique à l'iridium | Pack espace, Pack plasma, Pack magnétique | 184 100 | 5 |
| La Porte d'Érèbe | 15 | Porte | Archives orbitales de l'Arche | Pack exotique, Pack espace, Pack plasma | 46 025 | 3 |
<!-- /GEN:techs -->

### 4.5 Boucle « presque idle » (E3)
- E3-1 (l'usine nourrit le centre) : existant.
- E3-2 (score de puissance) et E3-3 (objectifs et récompenses par époque) : jalons, caisses, crédits
  d'accélération, médailles, score (§3.1). Données prêtes ; rien n'est implémenté.
- E3-4 (file de chantiers) : au lot I ; les chantiers de zone et les sabliers s'y raccordent.
- E3-5 (plus de familles à niveaux) : 6 familles proposées au §3.3 (procédés, laboratoires, radars, énergie,
  tourelles spéciales, bras) ; tapis à décider avec le lot C.

---

## 5. Contraintes moteur 1.1.91 et volume

### 5.1 Faisable par prototypes (schéma vérifié dans `doc-html/prototype-api.json`)
- Ressources infinies (`infinite`, `minimum`, `normal`) ; combustibles à résidu (`burnt_result`) ; charges
  utiles de fusée (`rocket_launch_products`) : l'orbite se joue sans seconde surface.
- **Lanceur orbital** : un second `rocket-silo` (9×9, 10 pièces bon marché, `rocket_result_inventory_size = 3`)
  porte les charges utiles du mod ; le silo vanilla (inventaire de résultat de 1) garde le satellite.
  Chaque lancement de matière rend au moins deux fois son coût en MU, et ses produits tiennent dans les 3
  cases (contrôlé).
- Machines à énergie chaleur ou fluide ; générateur `burns_fluid` ; `ReactorPrototype` (« May not be a heat
  energy source » : brûleur) ; pas de `FusionReactorPrototype` ni de `SpoilablePrototype` en 1.1.91.
- Recette sans ingrédient et recette sans produit permises en toutes lettres.
- `LinkedContainerPrototype` (inventaire > 0), `BurnerGeneratorPrototype`, `simple-entity-with-owner` pour les
  merveilles (effets par script), `electric-energy-interface` pour le bouclier de déviation et les charges
  cachées.
- Pylône : `maximum_wire_distance` 64 au plus. Locomotive : brûleur ou `void` seulement.
- Barils : `auto_barrel` vrai par défaut ; 17 fluides en ont, le flux sombre et la matière exotique brute non.

### 5.2 Faisable par script (API runtime vérifiée dans `doc-html/runtime-api.json`, coût à mesurer)

| Système | API | Fréquence | Coût attendu |
|---|---|---|---|
| Verrou d'époque | `LuaTechnology.researched` (écriture) | à chaque niveau du centre | nul |
| Serment | `LuaTechnology.enabled` (écriture), `set_cease_fire`, `set_friend` | une fois | nul |
| Marée | `LuaEntity.amount` (écriture), veines sous haloscope seulement | tourniquet sur 600 ticks | O(tuiles sous haloscope ÷ 600) par tick |
| Veines | `on_sector_scanned`, `create_entity` | à chaque secteur balayé | faible |
| Remontées, failles | `on_gui_opened`, `create_entity`, `update_connections` | à la pose, au réveil | nul |
| Dilatation | balise cachée créée une fois ; module caché inséré ou retiré ; hystérésis | 60 ticks | O(chambres) |
| Confinement, contagion | `energy`, `status`, `set_tiles`, dégâts ; interface cachée du réacteur | 60 ticks | O(bâtiments à risque) |
| Coffres intriqués | `link_id`, interface cachée par paire | à la pose | nul |
| Rectennas | `power_production` (écriture) | à chaque lancement ou pose | nul |
| Pluies de météorites | `create_entity` | toutes les 20 à 40 min | pic ponctuel |
| Fenêtre d'évolution | `LuaForce.evolution_factor` (écriture) | 3 600 ticks | nul |
| Merveilles, médailles | `mining_drill_productivity_bonus`, `laboratory_speed_modifier`, `set_ammo_damage_modifier`, `LuaRecipe.enabled` | à la pose | nul |
| Porte et Marée du Cœur | `on_rocket_launched`, interface de 5 GW, `rocket_parts`, directeur des vagues, `set_game_state` | événement, 60 ticks | celui des vagues (E19 : 0,06 ms) |
| Récit | `show_message_dialog` | début, Codex livré | nul |

- **Hypothèse H-X1 · OUVERTE** : l'ensemble des systèmes X coûte au plus 0,05 ms/tick en moyenne à
  l'époque 15. À mesurer au banc épinglé (budget A1).

### 5.3 Infaisable ou contourné
- **Pas de péremption** en 1.1.91 : remplacée par des risques portés par les bâtiments (confinement,
  contagion).
- **Pas de bonus de vitesse par entité fixé par script** : la dilatation passe par une balise cachée.
- **Pas d'interception de projectile par tourelle** : le bouclier de déviation est scripté.
- **Pas de seconde surface** (station orbitale exclue).
- **Fluides 1.1** : le débit chute avec la longueur des conduites ; le flux sombre reste local ; le plasma
  voyage en baril, mais sans sa chaleur.
- Tapis : plafond H-B1 de 120/s ; 1 fabrication par tick et par machine (aucune recette n'en approche).

### 5.4 Ce que le banc impose aux données
Quantités d'objets entières de 1 à 65 535 ; durée > 0,001 s ; aucun ingrédient en double ; aucun fluide en
catégorie `crafting` ; un seul objet d'entrée par four ; probabilités dans ]0, 1] ; noms sans point, 200
caractères au plus ; pylônes et balises ≤ 64 ; bâtiments ≤ 10×10 ; **types de prototype réels** ; catégories
de fabrication non vides et consommation positive ; réacteurs avec `neighbour_bonus`, `max_temperature` et
`max_transfer` ; chaleur cohérente ; produits de lancement dans l'inventaire de résultat.

### 5.5 Volume de contenu (compté par le banc)

<!-- GEN:volume -->
| Catégorie | Nombre | Détail |
|---|---|---|
| Objets nouveaux | **123** | plus 2 compteurs de silo (segment d'anneau, pièce de lanceur léger) |
| Fluides nouveaux | **19** | dont 17 avec baril |
| Bâtiments nouveaux | **80** | chacun aussi un objet |
| Recettes réelles | **264** | 166 de fabrication, 81 de bâtiments, 17 de torchère |
| Pseudo-recettes | **29** | minage, combustion, lancement, cueillette, butin, chauffe |
| Barils (data-updates de base) | **17** objets, **34** recettes | `auto_barrel` vrai par défaut |
| Variantes denses (lot C) | **48** | plus les intermédiaires denses |
| Ressources de carte | **15** | dont 5 remontées profondes |
| Tuiles et biomes | **5** | |
| Technologies | **78** + 8 infinies + 14 verrous | plus environ 190 vanilla re-rangées (4 scindées) |
| Niveaux (Q6) | **734** entités + **734** objets | un prototype par niveau (ARCHITECTURE §7 bis), du niveau 2e-1 au niveau 30 |
| **Prototypes au total** | **≈ 2 253** | somme des lignes ci-dessus |
| Graphismes | — | 80 bâtiments (dont 4 merveilles 9×9 et 3 pièces 10×10) ; une pièce visuelle par niveau, soit 734 variantes ; environ 159 icônes ; 15 jeux de gisements ; 5 jeux de tuiles |
<!-- /GEN:volume -->

- **Hypothèse H-X2 · OUVERTE** : avec environ 1 470 prototypes de niveau (entités et objets) et leurs
  variantes visuelles, le temps de chargement et la mémoire restent acceptables. À mesurer au banc `content`
  (lot V2) avec N prototypes de niveau factices, avant de générer les niveaux de tous les bâtiments.

---

## 6. Vérification hors jeu

`lua5.2 tests/epochs_test.lua` depuis la racine du mod (ou d'un worktree). Résultat le 21/10 (version 2) :
**16 665 OK, 0 ECHEC(S)**. Ce nombre est surtout fait de contrôles unitaires ; ce qui compte est la liste
des propriétés vérifiées. Graphe contrôlé :

<!-- GEN:summary -->
597 recettes dans le graphe (255 de base, 15 pseudo-recettes de base, 34 de barils, 293 nouvelles), 78 technologies nouvelles.
<!-- /GEN:summary -->

Propriétés :

1. **Sources moteur** : `prototype-api.json` est **analysé** (mini-analyseur JSON) ; chaque phrase ou valeur
   citée est cherchée **dans la propriété nommée** (description, valeur par défaut, type ou caractère
   obligatoire), plus la liste des types de prototype réels.
2. **Structure, noms, traductions** : tableaux purs, préfixe `fo-`, unicité, noms FR et EN partout, **mots
   anglais interdits dans les noms français**, textes joueur.
3. **Graphe complet** : vanilla réelle (recettes cachées et interdites exclues), arsenal, modules, centre,
   **barils générés**, contenu nouveau ; point fixe trié et déterministe : 0 infranchissable, 0 anachronisme ;
   produit de chaque minage = produit de sa ressource.
4. **MU** : chemin le moins cher, fluides à 0,1 MU l'unité, **produits rendus exclus** (le cuivre rendu par la
   capture, les pièges et les cavités ne font plus s'effondrer les valeurs).
5. **Époques et monnaies** : ressources, 2 bâtiments de ligne principale, monnaie objet à pile ≥ 50 et valeur
   déclarée, lot de passage produisible en 25 % de l'époque, jalons, fenêtres sans doublon, packs croissants.
6. **Technologies** : déblocage unique, époque, branche, prérequis sans cycle, packs disponibles, pack
   fabricable avant sa recherche, **recherche à 30-40 % du budget** (vanilla relue dans `technology.lua`),
   croissance ≥ ×4 par palier, packs exotiques dans le débit des failles, **scissions vanilla**.
7. **Branches** : niveaux, Serment, recettes, bâtiment et usage hors recherche à chaque niveau, merveille,
   indépendance de la ligne principale, branche C bornée, B-III > B-II, transmutation ≤ 5 MJ par minerai.
8. **Règles de production** : sources et débouchés, productivité, `catalyst_amount`, énergie P5, MU ≥ 0,75 ρ.
9. **Compaction** : formes denses ; **débit et énergie par machine** des formes ρ8 et ρ32 ; foreuses de ligne
   principale à chaque palier ; plafond de 2 000 foreuses ; chaînes T4 et T5 en 1:1.
10. **Limites moteur** par recette et par bâtiment ; **cohérence des données** pour les boîtes de fluide (ce
    n'est pas un contrôle du moteur) ; chaleur ; lancements ; niveaux.
11. **Placement** : chaque ressource dont dépend un pack est garantie.
12. **Factions** : clés = F.pvp_order (lot IA0, relu), champs d'IA0 absents de X0, calendrier des factions,
    course à la Porte.
13. **La Porte** : 230, 11 500, 100 segments, 50 MW puis 5 GW, repli de l'ancre.
14. **Scénario** : chaque bloc généré de ce document est égal aux données.

**Défauts trouvés par le banc pendant la correction** : le cristal de résonance transmuté rendait 400 MJ pour
75 MJ (retiré) ; la billette de tungstène tombait à 14,995 MU/s (1,067 s → 1,066 s) ; la cavité de Casimir
valait 5 MU (partage des MU appliqué à une quantité catalytique nulle, corrigé dans le banc) ; le jalon de
production de l'époque 15 demandait 3 532 matières exotiques (passé au superalliage).

---

## 7. Corrections

### 7.1 Version 2 (21/10, après relecture)
**Bloquant**
1. Recettes denses calibrées sur le modèle (§4.1) : la fonte de concentré était 24 fois trop lente et 16 fois
   trop gourmande ; le bloc ρ32 coûtait 5,6 MJ par MU. Le contrôle existe désormais.

**Majeurs**
1. Difficulté : une seule source (lot IA0) ; X0 ne garde que évolution, écart, crédit et chantier de Porte.
2. Monnaies au format V2 (une par époque, objets, piles, valeurs ; diff au §10).
3. et 13. Foreuses de concentré T4 et T5 de ligne principale, plafond de foreuses.
4. 78 technologies nouvelles, avec prérequis, recettes, packs et unités.
5. Garanties de placement de toutes les ressources dont dépend un pack.
6. et 11. Niveaux déclarés pour chaque bâtiment ; volume recompté (environ 2 250 prototypes) ; rattrapage
   des familles V2 (QX8).
7. Époque 11 : structures légères ; merveilles à l'époque 14 déclarées comme écart.
8. Cinq remontées profondes (une ressource par minerai), choix du minerai par interface, `update_connections`.
9. Interface électrique vanilla et chargeurs jamais rangés ; recettes cachées refusées.
10. et 16. Chaîne de chaleur : `neighbour_bonus = 0`, `max_temperature`, `max_transfer`, caloduc haute
    température, plasma, injecteurs, turbines MHD.
11. Monnaies de valeur nulle ou plafonnées : valeurs fixes, superalliage sans plafond, produits rendus exclus.
12. Branche C bornée (dilatation payée, une chambre par machine, sabliers et coffres plafonnés).
13. Seuils des factions indexés sur le calendrier.
14. Course à la Porte : départ, durées, remise à zéro.
15. Rythme : budget au débit moyen, recherche à 35 %, coût des packs croissant ; « rythme : non vérifié en jeu ».

**Mineurs** (26) : noms français sans mots anglais, citation exacte ; merveilles en types réels, mécanisme du
Monolithe, merveille de la branche B ; mode Légende récrit ; QX6 et QX7 posées ; textes joueur et canal ;
budgets au format français et générateur avec contrôle d'égalité ; veines de départ ; rectenna expliquée ;
bâtiments comptés à leur époque d'ouverture ; usages et bâtiments des niveaux I ; banc plus honnête (ligne
toujours vraie supprimée, analyse JSON, types réels, champs obligatoires, « cohérence des données ») ; bouclier
de déviation et piscine corrigés ; Porte à 50 MW plus 5 GW par interface ; pièce de compteur ; lanceur orbital
à 3 cases ; barils décidés ; repli de l'ancre ; marée en tourniquet ; balise de dilatation créée une fois ;
confinement du réacteur par interface ; concentrateur 1:1 ; scissions vanilla ; fenêtre militaire sans
doublon ; fusion catalysée à 120 GJ ; transmutation à 3,75 MJ ; lancements rentables ; jalon de production à
2 % du budget.

### 7.2 Version 1 (proposition gagnante corrigée, greffes intégrées)
Modules rangés à l'époque 10 ; tour à arc en bobines ; aucune recette vanilla modifiée ; ergol cryogénique
sans combustion ; météorite étrange sans ferronickel ; Porte 10×10 ; calendrier de 59,5 h ; densités nées du
palier ; greffes des juges 1 et 2 (verrou d'époque, fenêtre d'évolution, économie d'archive, gabarit d'époque,
chantiers de zone, butin, fenêtre de packs, puits des déchets, coffres intriqués, fusion catalysée, évents
d'hélium-3, veines au balayage, énergie transportable, époque 4 étoffée).

---

## 8. Ce qui n'est pas vérifié

- **Tout, en moteur réel** : aucun prototype n'existe ; aucun banc `content` ne couvre ce contenu.
- Le **rythme ressenti** (F1-3) : seul le modèle est contrôlé (budgets, recherche, jalons).
- Les **débits réels** en partie et l'**équilibrage fin** ; les MU sont des estimations par le chemin le moins
  cher (fluides à 0,1 MU l'unité, eau et vapeur gratuites).
- L'**insertion directe** d'une foreuse dans un concentrateur ou une fonderie à 30 ou 120 objets/s.
- La physique des **fluides** en conduite ; le choix d'une recette de **four par le fluide entrant**
  (torchère).
- Les machines alimentées par la **chaleur** ou par la **vapeur** ; la chaîne de chaleur à **5 000 °C** ;
  l'injecteur en mode « output-to-separate-pipe » avec le plasma.
- Une **foreuse à entrée et sortie de fluide** sur une ressource fluide (ancre de faille ; repli conçu).
- `update_connections()` sur une **ressource créée par script après la pose** (puits gravitique).
- L'effet de la **réécriture de `amount`** sur le rendement d'une ressource infinie (marée).
- L'**affichage** d'un laboratoire à 19 entrées ; un pylône à zone d'alimentation de 0,5.
- `ModulePrototype.limitation` et `allowed_effects` appliqués aux **balises** (dilatation).
- Le **coût de script** (H-X1) ; le **coût de chargement** des niveaux (H-X2).
- Les **IA** au-delà de l'époque 4 (H-E1) : l'économie d'archive reste en partie une imitation.
- Le **diff V2** du §10 : essayé seulement sur une copie (23 échecs attendus ou à trancher, §10) ; non appliqué.
- Le **coût graphique** (80 bâtiments et environ 730 variantes de niveau en formes propres, D1).
- Les **traductions** : noms FR et EN dans les données ; les fichiers `.cfg` appartiennent aux lots X1 à X15.
- La copie du projet claude.ai (`claude/*.md`) n'est **pas** mise à jour par ce lot.

---

## 9. Ce qui reste à décider par le Directeur Créatif

- **QX1** : une phase « brûleur » aux époques 1 et 2, l'électricité n'arrivant qu'à l'époque 3. Acceptable ?
- **QX2** : le Serment, soit une seule maîtrise (III) et sa merveille avant l'époque 15 (les merveilles des
  autres doctrines à l'époque 15, au lieu de toutes à l'époque 15 comme au §6). Acceptable ?
- **QX3** : en Difficile et en Impitoyable, une faction qui ouvre sa Porte avant vous fait perdre la partie ;
  en Impitoyable, au rythme nominal, elle finit 1 h avant vous. Acceptable ?
- **QX4** : l'antimatière. (a) **≈ 1,8 GW nets par réacteur**, rendement positif déclaré fictif ; ou (b)
  l'antimatière n'est qu'un **stockage**. Proposition : (a).
- **QX5** : les noms Érèbe, Caustique, Cœur, Convoi, Compagnie et Porte vous conviennent-ils ?
- **QX6** : un **6e ouvrier** avec l'Horloge éternelle, au-delà du « 1 à 5 » d'OBJECTIFS F1. Acceptable ?
- **QX7** : F1-3 dit « époque 15 au bout de 60 h cumulées environ ». Est-ce l'heure où l'on **atteint**
  l'époque 15 (alors tout le calendrier s'allonge d'environ 13 %) ou celle où l'on **ouvre la Porte** (lecture
  actuelle : époque 15 atteinte à 52,5 h, Porte à 59,5 h) ?
- **QX8** : les bâtiments vanilla qui arrivent après l'époque 1 (mur, four, foreuse, assembleur, laser)
  naissent au niveau 1 et **rattrapent** leurs niveaux en payant les époques passées (proposition), ou
  **naissent au niveau de leur époque** (le laser au niveau 11) ?
- **QX9** : aux époques 2 à 4, 6 et 10, la recherche vanilla coûte plus que le budget du modèle (jusqu'à 11
  fois). Faut-il **alléger la recherche vanilla** (proposition : ×0,04 à ×0,25 d'unités) ou **relever le
  débit des premières époques** (plus de production plus tôt) ?
- **QX10** : le passage du centre vaut 10 % du budget de l'époque chez X0, mais 50 à 100 fois moins dans la
  courbe du lot V2 (`value_mult`). Lequel des deux doit gouverner ? Arbitré (X0 gouverne, lot V2c) ; tenu aux
  époques 1 à 4 seulement, la règle de place du centre bornant le passage à 3,35 puis 0,11 % du budget sans
  le Codex : Q-V2c-1.

---

## 10. Pour l'intégrateur

Ce lot n'a modifié **aucun fichier partagé**. Diffs et textes proposés :

**1. `shared/content/arsenal.lua`** (à appliquer **avec le lot X6**, quand la bobine `fo-coil` existe en jeu) :
```diff
@@ A.special_turrets, fo-tesla-turret (l. 138)
-    ingredients = { { "laser-turret", 1 }, { "fo-resonance-crystal", 15 }, { "copper-cable", 60 }, { "advanced-circuit", 10 } },
+    ingredients = { { "laser-turret", 1 }, { "fo-coil", 10 }, { "copper-cable", 60 }, { "advanced-circuit", 10 } },
@@ A.special_guns, fo-arc-gun (l. 190)
-    ingredients = { { "submachine-gun", 1 }, { "fo-resonance-crystal", 10 }, { "battery", 10 } },
+    ingredients = { { "submachine-gun", 1 }, { "fo-coil", 5 }, { "battery", 10 } },
```
Technologies à scinder : `fo-arc-and-acid` (arc 6, acide 8), `fo-heavy-weapons-2` (5, 7, 8) ; vanilla :
`X.vanilla_tech_splits`.

**2. `shared/levels/config.lua`** (lot V2) : monnaies X0 et Codex au passage du centre. Les époques 2 à 7, 9 et
10 gardent exactement la monnaie V2 (contrôlé par le banc, qui relit `L.epoch_materials` et `L.stack_size`).

**Essayé sur une copie du `main`** (21/10, `tests/levels_test.lua` du lot V2 : 1 228 OK avant, **1 237 OK et
23 échecs après**) ; le diff ne s'applique donc **pas d'un bloc** :
- 20 échecs « objet de coût existant en jeu » : les monnaies X0 et les Codex n'existent pas encore en jeu.
  **À appliquer époque par époque**, quand le lot X8, X11 à X15 (ou celui des Codex) a livré l'objet ;
  jusque-là, V2 garde son remplaçant provisoire ;
- 2 échecs sur les compteurs de remplaçants provisoires de V2 : à mettre à jour avec chaque époque basculée ;
- 1 échec « au plus 6 sortes d'objets par amélioration (7) » : le Codex porte le coût du centre à 7 sortes.
  Proposition : retirer la brique de pierre du panier de base du centre à partir du niveau 3, ou relever la
  règle de V2 à 7 sortes. Décision du lot V2.

<!-- GEN:v2diff -->
```lua
-- À insérer dans shared/levels/config.lua juste APRÈS la table L.stack_size (L.epoch_materials, L.item_value
-- et L.stack_size existent alors). Les époques absentes gardent leur monnaie V2 (identique à X0, contrôlé par le banc).
for _, m in ipairs({
  { 8, "fo-biopolymer", 4, 100 }, -- était fo-methane-barrel
  { 11, "fo-titanium-plate", 20, 100 }, -- était low-density-structure
  { 12, "fo-superconducting-coil", 60, 100 }, -- était electric-engine-unit
  { 13, "fo-plasma-cell", 25, 100 }, -- était uranium-235
  { 14, "fo-superalloy", 45, 50 }, -- était rocket-control-unit
  { 15, "fo-stabilized-exotic-matter", 1500, 50 }, -- était space-science-pack
}) do
  local e = L.epoch_materials[m[1]]
  e.item, e.value, e.want_item, e.provisional = m[2], m[3], nil, nil
  L.item_value[m[2]], L.stack_size[m[2]] = m[3], m[4]
end
-- Codex (lot X0) : le passage du centre au niveau n exige 1 Codex n-1 (valeur en MU calculée par le banc X0).
L.codex_value = { 133, 176, 311, 309, 310, 883, 925, 1002, 1180, 790, 1310, 1718, 1662, 1369 }
for k = 1, 14 do
  L.item_value["fo-codex-" .. k] = L.codex_value[k]
  L.stack_size["fo-codex-" .. k] = 10
end
-- Dans raw_cost(family, n), juste après la boucle du panier de base :
--   if family.key == "command" then add("fo-codex-" .. (n - 1), 1) end
```
<!-- /GEN:v2diff -->

**3. `OBJECTIFS.md`**
- F1-6 : « 🟨 conception livrée et corrigée (lot X0, version 2 : `docs/SCENARIO_EPOQUES.md`,
  `shared/content/epochs.lua`) ; vérifiée hors jeu (`tests/epochs_test.lua` : 16 665 OK, 0 échec) ; rien en
  moteur réel ».
- §4 : questions QX1 à QX10 (§9) ; §7 : suivi du lot X0 (version 2).
- C2 : écrire que les époques des IA au-delà de 4 sont une économie d'archive en partie imitée.
- C4-3 : la difficulté a une seule source (`shared/faction/config.lua`) ; X0 n'y ajoute que les champs
  d'époque, avec les mêmes clés.

**4. `RD_LOG.md`** : hypothèses **H-X1** (coût de script) et **H-X2** (coût de chargement des niveaux) ;
décision « QX4 supprimée : variantes au lieu de modifications vanilla » ; défauts trouvés par le banc (§6).

**5. `BALANCE_SHEET.md`** : nouvelle section « Époques » : calendrier et monnaies (§3.1), énergie par palier
(§4.2), foreuses T4 et T5 (§4.1), recherche à 35 % et échelle vanilla (§3.5), difficulté (§1.4).

**6. `ARCHITECTURE.md`** : `shared/content/epochs.lua` et `tests/epochs_test.lua` dans l'arborescence ;
verrou `fo-epoch-k`, systèmes X (§5.2), blocs générés du scénario (`--write-doc`). **`CLAUDE.md` §5** :
`lua5.2 tests/epochs_test.lua -> 16 665 OK`.

**7. `changelog.txt`** : « Lot X0 (version 2) : technologies, foreuses de concentré T4 et T5, monnaies au
format V2, garanties de placement, niveaux, chaîne de chaleur, difficulté alignée sur IA0 ».

**8. Aucun diff de `data-updates.lua`** : le silo vanilla garde son inventaire de résultat de 1 ; les charges
utiles du mod partent du lanceur orbital (3 cases).
