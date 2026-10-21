# BALANCE SHEET — Modèle quantitatif

> Source unique : `shared/balance_model.lua`. Les tables ci-dessous sont générées par
> `lua5.2 tools/print_balance.lua` : ne pas les éditer à la main, modifier le modèle.
> Dernière mise à jour : 2026-10-21, session 4 (économie réelle des équipes, arsenal spécial, défense de
> tours, résistances de famille par palier ; mesures en moteur réel).
> Tables générées : `lua5.2 tools/print_balance.lua`, `lua5.2 tools/print_content.lua` ; mesures de
> partie : `tools/autotest/` (scénarios `default`, `waves`, `pteam`, `content`).

## 1. Contraintes moteur (vérifiées dans la doc 1.1.91 livrée avec le jeu)

| Contrainte | Valeur | Source |
|---|---|---|
| Débit tapis | `items/s = speed × 480` | `TransportBeltConnectablePrototype.speed` |
| Quantum de vitesse | `1/256` → paliers de **1,875 items/s** | idem (virgule fixe 8 bits) |
| Complétions de recette | **1 par tick et par machine** (60/s) ; la productivité excédentaire n'est pas plafonnée | `CraftingMachinePrototype` (note `allowed_effects`) |
| Pathfinder | 10 nouvelles requêtes/tick, 1 000 nœuds/tick (défauts) | `PathFinderMapSettings` |
| Vision des unités | max 100 ; ≥ 50 provoque des regroupements spontanés | `UnitPrototype.vision_distance` |
| Plafond souple tapis | 0,25 tile/tick = 120 items/s | **hypothèse H-B1**, à valider |

## 2. Référence vanilla (relevée dans `data/base/prototypes/entity/entities.lua`)

| Entité | Valeur |
|---|---|
| Tapis jaune / rouge / bleu | 15 / 30 / 45 items/s |
| Assembleur 1 / 2 / 3 | vitesse 0,5 / 0,75 / 1,25 |
| Four pierre / acier / électrique | vitesse 1 / 2 / 2 |
| Bras (rotation, tours/tick) | burner 0,01 · basique 0,014 · long 0,02 · rapide/filtre/stack 0,04 |
| Personnage | course 0,15 tile/tick · minage 0,5 · craft 1 · 80 slots · 250 PV |
| Plaque de fer | 3,2 s ; four en pierre 90 kW → **288 kJ par plaque** |

## 3. Logistique : « Compaction ×4 » (VALIDÉE le 2026-10-20)

Idée : chaque palier multiplie le **débit matière** Φ d'un tapis par 4, en combinant vitesse ×2 et densité ×2 jusqu'au plafond de vitesse (T4), puis densité seule (T5). La taille d'un module de production reste constante (32 machines par tapis), donc chaque palier est un vrai saut sans explosion du nombre d'entités.

| Palier | Tapis (items/s) | speed | ρ (MU/item) | Φ tapis (MU/s) | ×Φ | MU/s par machine | items/s par machine | kJ/MU | kW par machine | MW par tapis | Mouvements / 1000 MU |
|---|---|---|---|---|---|---|---|---|---|---|---|
| T1 | 15 | 0.03125 | 1 | 15 | ×1 | 0.47 | 0.47 | 288 | 135 | 4.3 | 3000 |
| T2 | 30 | 0.06250 | 2 | 60 | ×4 | 1.88 | 0.94 | 230 | 432 | 13.8 | 1500 |
| T3 | 60 | 0.12500 | 4 | 240 | ×4 | 7.50 | 1.88 | 184 | 1382 | 44.2 | 750 |
| T4 | 120 | 0.25000 | 8 | 960 | ×4 | 30.00 | 3.75 | 147 | 4424 | 141.6 | 375 |
| T5 | 120 | 0.25000 | 32 | 3840 | ×4 | 120.00 | 3.75 | 118 | 14156 | 453.0 | 94 |

Contraintes moteur : toutes respectées (vitesses multiples de 1/256, ≤ plafond H-B1, crafts/s ≪ 60).

## 4. Lecture de design

1. **UPS ↓ quand le jeu grandit.** Les mouvements d'objets par 1 000 MU chutent de 3 000 (T1) à 94 (T5), soit ÷32. Une méga-usine T5 produit 256× plus de matière par tapis qu'en T1 avec un nombre d'entités comparable par module. C'est la convergence recherchée : l'hyper-scaling *améliore* l'UPS au lieu de le détruire.
2. **Le plafond de 60 crafts/s n'est jamais approché** (3,75 items/s par machine en T5) : la densité absorbe la croissance, pas la cadence.
3. **ANGLE MORT : l'énergie.** La puissance par machine croît de ×3,2 par palier (×4 de débit × 0,8 d'efficacité). Un seul tapis T5 alimenté demande **≈ 450 MW**, plus de 11 réacteurs nucléaires vanilla (40 MW chacun). Sans paliers énergétiques au même rythme, le joueur sera bloqué par l'électricité et non par la logistique. Deux leviers possibles : `energy_decay` plus fort (0,5 donne ×2 par palier), ou une filière énergie T1 à T5 dédiée.
4. **Anti-obsolescence.** Chaque palier doit garder une niche :
   - T1-T2 : bon marché, compacts, sans infrastructure. C'est ce que construisent les compagnons (sous-usines autonomes) et les avant-postes.
   - T3 : demande une infrastructure (fluide de refroidissement, chaleur).
   - T4-T5 : énormes, n'acceptent que des objets denses. La chaîne de compaction (ρ1 → ρ8 → ρ32), qui tourne sur machines T2-T3, reste donc indispensable en amont.
   - Le minage doit suivre : à T5, extraire du minerai ρ1 exigerait 256 tapis T1. Il faut des foreuses T4-T5 qui produisent directement du **concentré** (ρ8-ρ32).
5. **Paramètre libre majeur : la croissance de la demande.** Pour que ×4 de capacité reste un défi, le coût des recherches de palier k doit croître d'environ ×4 aussi. À fixer avec l'arbre technologique.

## 5. Paramètres ouverts (Directeur Créatif)

| Paramètre | Valeur proposée | Effet |
|---|---|---|
| Facteur de saut Φ | ×4 | ressenti du « vrai saut » vs inflation des nombres |
| Machines par tapis | 32 | taille des modules de production |
| `energy_decay` | 0,8 | pression énergétique par palier |
| Densités | 1, 2, 4, 8, 32 | nombre et complexité des étapes de compaction |
| Taille de pile des objets denses | à définir | en ρ32, une pile de 100 vaut 3 200 MU : stockage et logistique robot à repenser |

## 6. Modules : 10 paliers

Principes : la vitesse devient **plus économe** en énergie par produit aux paliers hauts (récompense réelle) ;
le malus de vitesse de la productivité est plafonné à -15 % dès le palier 3 (sinon plancher moteur à -80 %) ;
l'efficacité atteint le plancher de consommation au palier 9, puis réduit la pollution.
Recettes : palier k = 2 × palier k-1 + puces + ingrédient de famille (cristal de résonance pour la vitesse,
plaques de tungstène pour la productivité, structures légères pour l'efficacité). Paliers 6+ : science spatiale.

#### Modules (effet d'UN module)

| Palier | Vitesse : vitesse / conso | Productivité : prod / vitesse / conso / pollution | Efficacité : conso / pollution |
|---|---|---|---|
| 1 (vanilla) | +20 % / +50 % | +4 % / -5 % / +40 % / +5 % | -30 % / +0 % |
| 2 (vanilla) | +30 % / +60 % | +6 % / -10 % / +60 % / +7 % | -40 % / +0 % |
| 3 (vanilla) | +50 % / +70 % | +10 % / -15 % / +80 % / +10 % | -50 % / +0 % |
| 4 | +70 % / +80 % | +13 % / -15 % / +90 % / +12 % | -55 % / -5 % |
| 5 | +90 % / +90 % | +16 % / -15 % / +100 % / +14 % | -60 % / -10 % |
| 6 | +115 % / +100 % | +20 % / -15 % / +110 % / +16 % | -65 % / -15 % |
| 7 | +140 % / +110 % | +24 % / -15 % / +120 % / +18 % | -70 % / -20 % |
| 8 | +170 % / +120 % | +28 % / -15 % / +130 % / +20 % | -75 % / -25 % |
| 9 | +200 % / +130 % | +33 % / -15 % / +140 % / +22 % | -80 % / -30 % |
| 10 | +240 % / +140 % | +40 % / -15 % / +150 % / +25 % | -80 % / -40 % |

#### Machine à 4 emplacements remplis du même module

| Palier | Vitesse ×4 : cadence / énergie par produit | Productivité ×4 : produits par cycle / énergie par produit |
|---|---|---|
| 1 | ×1.80 / ×1.67 | ×1.16 / ×2.80 |
| 2 | ×2.20 / ×1.55 | ×1.24 / ×4.57 |
| 3 | ×3.00 / ×1.27 | ×1.40 / ×7.50 |
| 4 | ×3.80 / ×1.11 | ×1.52 / ×7.57 |
| 5 | ×4.60 / ×1.00 | ×1.64 / ×7.62 |
| 6 | ×5.60 / ×0.89 | ×1.80 / ×7.50 |
| 7 | ×6.60 / ×0.82 | ×1.96 / ×7.40 |
| 8 | ×7.80 / ×0.74 | ×2.12 / ×7.31 |
| 9 | ×9.00 / ×0.69 | ×2.32 / ×7.11 |
| 10 | ×10.60 / ×0.62 | ×2.60 / ×6.73 |


**Point de vigilance : boucles de productivité.** Les modules de productivité sont limités aux recettes
intermédiaires vanilla + `fo-tungsten-plate`. Règle : **jamais** de recette réversible (compaction ↔
décompaction) dans cette liste, sinon productivité + boucle = matière infinie.

## 7. Déchiqueteurs : 8 paliers × 4 familles

#### Déchiqueteurs : paliers 5-8 (relatifs au palier 4 vanilla, « énorme »)

| Palier | Nom | PV | Dégâts | Vitesse | Résistance +plate/+% | Taille | Pollution pour attaquer |
|---|---|---|---|---|---|---|---|
| 5 | colossal | ×3 (déchiqueteur 9000, cracheur 4500) | ×2 | ×0.97 | +8 / +8 | ×1.21 | ×2.5 |
| 6 | titan | ×8 (déchiqueteur 24000, cracheur 12000) | ×4 | ×0.94 | +16 / +16 | ×1.42 | ×6.0 |
| 7 | apex | ×20 (déchiqueteur 60000, cracheur 30000) | ×7 | ×0.90 | +24 / +24 | ×1.62 | ×15.0 |
| 8 | primordial | ×50 (déchiqueteur 150000, cracheur 75000) | ×12 | ×0.87 | +32 / +32 | ×1.83 | ×40.0 |

#### Courbes d'apparition (évolution → poids)

| Palier | Points (évolution : poids) |
|---|---|
| 1 small | 0.00 : 0.30 → 0.35 : 0.00 |
| 2 medium | 0.10 : 0.00 → 0.35 : 0.30 → 0.50 : 0.05 → 0.60 : 0.00 |
| 3 big | 0.30 : 0.00 → 0.50 : 0.30 → 0.65 : 0.05 → 0.75 : 0.00 |
| 4 behemoth | 0.45 : 0.00 → 0.62 : 0.30 → 0.78 : 0.05 → 0.88 : 0.00 |
| 5 colossal | 0.58 : 0.00 → 0.75 : 0.30 → 0.90 : 0.05 → 1.00 : 0.02 |
| 6 titan | 0.70 : 0.00 → 0.85 : 0.30 → 1.00 : 0.10 |
| 7 apex | 0.80 : 0.00 → 0.95 : 0.25 → 1.00 : 0.25 |
| 8 primordial | 0.90 : 0.00 → 1.00 : 0.20 |

Familles (nids dédiés, plus loin du départ) : **blindée** (PV ×1,5, physique +12 fixe / +60 %, explosion
+10 / +30 %, lente → contrer au laser, au tungstène, aux explosifs), **ignée** (immunisée au feu, embrase le sol à sa mort → balles, laser), **couvée** (libère
2 unités du palier inférieur à sa mort → dégâts de zone), **foudroyante** (rapide, morsures électriques qui
ignorent les murs vanilla → balles, mur blindé isolé).

Résistance de famille par palier (session 4) : la part fixe est nulle aux paliers 1-2 et croît jusqu'au
palier 8 (fixe × (palier − 2) / 6) ; la part en pourcentage croît jusqu'au palier 4 (% × palier / 4).
Ainsi un petit blindé reste vulnérable aux chargeurs ordinaires (défense de tours, vague 4) et un blindé
énorme ou supérieur exige les contres prévus (banc de contenu).

## 8. Arsenal

| Élément | Valeurs | Répond à |
|---|---|---|
| Munitions au tungstène | 40 physique | blindés |
| Munitions explosives | 30 physique + 15 explosion (rayon 2) | masses, couvées |
| Munitions incendiaires | 30 physique + brûlure ; recette au méthane | couvées (inutiles contre les ignés) |
| Munitions à plasma | 70 physique + 30 laser | blindés de haut palier |
| Mitrailleuse lourde | cadence ×2, portée 22 | — |
| Tourelle mitrailleuse lourde 3×3 | 2 000 PV, portée 24, cadence et dégâts ×1,5 | — |
| Tourelle laser lourde 3×3 | 3 000 PV, portée 32, dégâts ×2 par rapport à la tourelle laser, énergie ×2,5 | ignés |
| Mur renforcé / blindé | 1 200 / 3 500 PV ; le blindé résiste à l'électricité | foudroyants |

**Arsenal spécial (session 4)** : nouvelles FAMILLES d'armes, pas seulement des paliers.

| Élément | Valeurs | Répond à | Technologie |
|---|---|---|---|
| Tourelle-canon (3×3) | 2 200 PV, portée 5-32, tir toutes les 75 ticks, obus de char | blindés isolés | fo-siege-weapons (4) |
| Obus en tungstène | 420 physique + 100 explosion, traverse 4 cibles (obus ordinaire : 200 + 100) | blindés de haut palier | 4 |
| Mortier (3×3) | 1 600 PV, portée 14-46, tir toutes les 120 ticks | masses à distance | 4 |
| Obus de mortier | 180 explosion + 30 physique, rayon 5 | couvées, groupes | 4 |
| Tour à arc (2×2) | 1 200 PV, portée 20, arc 45 électrique rayon 3,5, 1,2 MJ par arc (réserve 1,5 MJ) | groupes de couvées (inutile contre les foudroyants) | fo-arc-and-acid (5) |
| Pulvérisateur d'acide (2×3) | 1 500 PV, portée 4-26, acide sulfurique, 14 acide + ralentissement 50 % | ignés (immunisés au feu) | 5 |
| Lance-grenades (main) | portée 24, cadence 45 ticks, grenade 45 explosion rayon 3,5 | groupes | 4 |
| Arc portatif (main) | portée 16, cadence 30 ticks, cellule 30 électrique rayon 3 | groupes rapprochés | 5 |
| Fusil à rail (main) | portée 40, cadence 75 ticks, balle 380 physique en LIGNE de 40 tuiles | colonnes | fo-railgun (6) |

Les contres voulus (vérifiés au banc de contenu, voir E15/E17) : tungstène > obus ordinaire contre les
blindés, mortier > mitrailleuse contre un groupe, arc efficace contre les couvées et inutile contre les
foudroyants, acide > lance-flammes contre les ignés, rail > mitraillette contre une colonne.

## 9. Monde : ressources à effets et biomes

| Ressource / biome | Effet natif (prototype) | Effet runtime |
|---|---|---|
| Tungstène (cendres volcaniques) | minerai dur : foreuses électriques uniquement | — |
| Cristal de résonance (plaine de cristal) | combustible : accélération ×1,5, vitesse de pointe ×1,3, émissions ×0,5 | — |
| Méthane (marais toxique) | fluide combustible ; jet de lance-flammes +50 % (pétrole léger +10 %), soit +12 % de dégâts TOTAUX mesurés (le bonus ne touche pas les brûlures) : 1 241 contre 1 111 PV/s sur un béhémoth ; craquage 100 → 60 gaz de pétrole | — |
| Cendres volcaniques | marche ×0,9, friction véhicule ×1,6 | — |
| Plaine de cristal | marche ×1,1 | soin +1 PV/s |
| Marais toxique | marche ×0,7, friction ×2, forte absorption de pollution | poison 2 PV/s |

Génération (session 3, mesurée en moteur réel) : régions de bruit multi-octave, échelle 1/200 à 1/260 ;
seuils retouchés : cendres 0,32 (humidité < 0,5), plaine de cristal 0,5 (aux > 0,45), marais 0,55
(humidité > 0,5). Gisements LIÉS AU BIOME : la favorabilité du bruit « spot-noise » qui place les centres
de gisement est le masque du biome (96 points candidats, graine propre), sans toucher au placement des
minerais vanilla. Mesures sur ~1 600 chunks autour des QG : cendres 32 k tuiles, plaine 95 k, marais 138 k ;
tungstène 1 221 tuiles, cristal 222, méthane 11 puits. Le poison du marais ne touche que le joueur et ses compagnons :
les ingénieurs de faction en sont exemptés (le pathfinder ne pondère pas les tuiles, l'IA ne peut pas l'éviter).

Aspect des biomes (session 4, après revue des captures en moteur réel) : une teinte de tuile ne fait que
multiplier la texture (F36) ; chaque biome a donc une TEXTURE propre et un décor propre.

| Biome | Sol | Décor (densité par tuile ; nombre mesuré sur la carte de test, ~1 600 chunks) |
|---|---|---|
| Cendres volcaniques | sol calciné des cratères, gris charbon | roches en fusion à cœur rougeoyant la nuit 0,006 (152), aiguilles de basalte 0,009 (254), arbres calcinés 0,02 (493), plaques de cendre, scories, braises |
| Plaine de cristal | surface vitrifiée miroitante (shader d'eau peu profonde, terrain ferme), reflets lilas, pas sur du pavé | amas de cristal violets lumineux 0,010 (817, minage : cristal + pierre), éclats cyan lumineux 0,012 (847), poussière, buissons, cailloux lilas |
| Marais toxique | eau croupie olive-brune, reflets vaseux | arbres des marais 0,03 (3 743), troncs morts 0,01 (1 117), roseaux, écume, mousse, souches |

Minerais (aperçus calculés sur les textures du jeu avant chaque choix, F38) : le tungstène prend la forme
en blocs de la pierre, métal sombre à reflets acier bleutés pulsés (6 s) ; le cristal de résonance prend
la texture neutre du fer, violet vif, éclats violets pulsés (3 s) qui luisent dans le noir. Les éclats
sont la texture du gisement lui-même en additif (celle de l'uranium est vert pur et ne se recolore pas).

Nids de famille : probabilité × 0,4 (`family_nest_share`). À 1 800 tuiles : 39 % des nids sont de
famille (blindée 87, ignée 21), le reste vanilla ; couvée et foudroyante plus loin (facteurs 6 et 8).

## 10. Factions IA : économie réelle et dynamique (session 4)

L'économie à registre (MU) des sessions 2-3 est **remplacée** : tout est objet réel dans le coffre du QG.

| Paramètre | Valeur |
|---|---|
| Stock de départ (QG, 200 cases) | 12 foreuses à combustible, 8 fours, 4 coffres en fer, 150 charbon, 200 fer, 60 cuivre, 80 pierre, 40 chargeurs |
| Fonderie de départ | 2 fours au QG (4 avec l'objectif « fonderie ») : minerai d'appoint, acier, briques |
| Ouvriers | 2 au départ ; voulus = 2 + 1 par avant-poste (plafond 10) ; kit : pistolet + 10 chargeurs ; embauche de secours sans arme si l'équipe n'a plus d'ouvrier |
| Soldats (kits) | fusilier : mitraillette + 5 chargeurs ; mitrailleur : mitraillette + 5 perforants + armure légère ; grenadier : 8 grenades + armure ; par lots de 5 |
| Avant-postes | foreuse à combustible → four (fer 8, cuivre 3 foreuses) ou coffre (charbon 4, pierre 2) par palier ; agrandis jusqu'à 20 foreuses (fer), 12 (charbon, cuivre), 8 (pierre) |
| Entretien | 5 charbons posés par brûleur, complétés à 10 ; urgence sous 3 ; tournée à 40 produits en attente ou toutes les 3 min ; charbon : production visée ≥ 1,4 × consommation |
| Tourelles | 20 chargeurs visés, ravitaillement sous 8 |
| Recherche (packs réels) | niv. 1 : 30 rouges ; niv. 2 : 50 rouges + 40 verts ; niv. 3 : 80 + 60 + 30 militaires ; niv. 4-5 : pack chimique (pétrole, chantier suivant) |
| Technologies vanilla débloquées | niv. 0 : militaire, tourelles, murs ; 1 : pack vert, acier, militaire 2, armure lourde, dégâts/cadence 1 ; 2 : pack militaire, roquettes, dégâts/cadence 2, portes ; 3 : militaire 3, dégâts/cadence 3, explosifs 1 |
| Échelle d'objectifs | charbon → fer → cuivre → pierre → défense (60 chargeurs) → armée (10) → fer II → recherche 1 → fonderie (4 fours) → grande armée (25) → fer III → recherche 2 → avant-postes défendus → fer IV → recherche 3 → expansion → pétrole |
| Patience | objectif sans progrès en 12 min : mis de côté 15 min |
| Armée visée (après l'objectif « armée ») | conquérant 80 %, équilibré 60 %, technocrate 45 %, bâtisseur 40 % de l'armée maximale |
| Attaque | taille minimale envoyée = 20 / agressivité (conquérant 13, équilibré 20, technocrate 25, bâtisseur 28) ; garnison gardée 20-40 % ; force ≥ 1,3 × défense estimée de la cible |
| Zone de départ | à 46 tuiles du QG : fer rayon 11, charbon et cuivre rayon 8, pierre rayon 6 (3 000 par tuile) |
| Prospection | disque de 12,5 chunks, élargi à 18 après un tour sans trouvaille ; 8 sites en réserve au plus |
| Personnalités | Ordre Écarlate = conquérant, Ligue Azur = technocrate, Consortium Émeraude = bâtisseur, Dynastie Ambre = équilibrée |
| Distance des QG au centre | 480 tuiles |

**Moteur réel (session 4, version finale)**, graine 20261020, 60 min, 4 équipes, 50 compagnons, benchmark
épinglé sur les cœurs P (soldats = garnison + groupes ; fer livré = plaques déposées au stock depuis le début) :

| Temps | Faction | Tech | Avant-postes | Soldats | Ouvriers | Attaques | Pertes | Objectif | Fer livré |
|---|---|---|---|---|---|---|---|---|---|
| 10 min | Scarlet | 0 | 5 | 10 | 6 | 0 | 0 | tech1 | 830 |
| 10 min | Azure | 0 | 4 | 5 | 6 | 0 | 0 | army | 798 |
| 10 min | Emerald | 0 | 4 | 10 | 6 | 0 | 0 | army | 632 |
| 10 min | Amber | 0 | 4 | 10 | 6 | 0 | 0 | iron2 | 786 |
| 20 min | Scarlet | 2 | 6 | 25 | 8 | 1 | 0 | iron3 | 3476 |
| 20 min | Azure | 0 | 4 | 25 | 5 | 0 | 0 | iron2 | 1713 |
| 20 min | Emerald | 1 | 6 | 8 | 8 | 0 | 12 | army2 | 2956 |
| 20 min | Amber | 0 | 4 | 15 | 6 | 0 | 10 | iron2 | 1680 |
| 30 min | Scarlet | 2 | 6 | 24 | 8 | 2 | 16 | iron3 | 4883 |
| 30 min | Azure | 1 | 4 | 15 | 6 | 0 | 15 | army2 | 3437 |
| 30 min | Emerald | 2 | 6 | 27 | 8 | 0 | 13 | iron3 | 6060 |
| 30 min | Amber | 2 | 4 | 20 | 6 | 0 | 10 | army2 | 3232 |
| 45 min | Scarlet | 2 | 5 | 26 | 8 | 3 | 34 | iron4 | 7217 |
| 45 min | Azure | 2 | 4 | 0 | 1 | 0 | 35 | iron2 | 4461 |
| 45 min | Emerald | 3 | 7 | 40 | 9 | 0 | 13 | fortify | 8850 |
| 45 min | Amber | 3 | 4 | 23 | 6 | 1 | 17 | iron2 | 4558 |
| 59 min | Scarlet | 2 | 6 | 58 | 8 | 7 | 37 | fortify | 8900 |
| 59 min | Azure | 2 | 2 | 0 | 1 | 0 | 35 | army2 | 4951 |
| 59 min | Emerald | 3 | 7 | 40 | 9 | 0 | 18 | iron3 | 11379 |
| 59 min | Amber | 3 | 5 | 33 | 7 | 2 | 17 | iron3 | 6127 |

Lecture : les quatre équipes déroulent l'échelle (charbon → défense en 5-7 min, armée vers 8 min,
recherche 1 entre 12 et 25 min, recherche 3 pour deux équipes vers 40 min) ; 10 attaques en 60 min, la
première à 15,8 min (le conquérant) ; la Ligue Azur, cible répétée, perd son armée et tous ses ouvriers sauf celui de
l'embauche de secours, et survit ; le bâtisseur (Émeraude) a la plus grosse économie (11 400 plaques de
fer livrées). Le fer reste le goulot de toute l'échelle. Coût : script 0,14 ms/tick en moyenne (p99
0,86 ms), 8 ticks sur 216 000 au-delà de 16,7 ms. Les tirages diffèrent d'une partie à l'autre (une
partie précédente avait vu la Ligue Azur anéantie vers 50 min).


### Historique : économie à registre (sessions 2-3, abandonnée en session 4)
Revenu en MU (QG 1 MU/s, foreuses électriques inactives à 0,5 MU/s), soldats payés en MU, recherche à
1 200 × 2^tech MU. En moteur réel (session 3, 30 min) : technologie 3-4, 3-7 avant-postes, 33-100 soldats.
Remplacée parce qu'elle ne faisait pas JOUER les équipes (aucun objet réel, aucun bâtiment qui tourne).

## 11. Défense de tours (session 4)

| Paramètre | Valeur |
|---|---|
| Activation | à tout moment (`/fo-waves on [secondes]`, bouton) ; 120 s de construction avant la vague 1 |
| Construction entre deux vagues | max(45, 120 − 3 × vague) secondes |
| Budget de vague | 24 × 1,3^(vague − 1), dépensé au coût du palier (1, 3, 10, 30, 90, 260, 700, 2 000) |
| Palier maximal | 1 + vague / 4 (petits jusqu'à la vague 3, moyens 4-7, gros 8-11, énormes 12-15…) |
| Familles | blindés dès la vague 4, ignés 7, couvées 9, foudroyants 12 |
| Boss | toutes les 5 vagues : palier 2 + vague / 5 (gros à 5, énorme à 10, colossal à 15…), escorte à 70 % du budget |
| Points d'apparition | 190 tuiles du centre (barycentre des tourelles) : 1 (vagues 1-4), 2 (5-11), 3 (12+) ; 12 unités/s |
| Récompense | fer 40 + 20 n, cuivre 20 + 10 n, perforants 10 + 4 n ; acier 5 n dès 4 ; tungstène 4 n dès 8 ; boss : cristal 10 n, processeurs n |
| Groupes bloqués | relance si inactif ; nouveau point d'apparition après 30 s sans se rapprocher ; rappel au bout de 6 min |
| Défaite | assaillants dans la base et plus aucune tourelle à 60 tuiles : mode arrêté, record conservé |

## 12. Niveaux de bâtiments « façon Clash of Clans » : 15 époques (session 5, refait au lot V2)

Directeur Créatif : « niveau Clash of Clans en termes d'échelons, de qualité de levels… pratiquement idle
game ». Réponses du 21/10, 18 h 07 : Q6 « oui c'est bien » (2 niveaux par époque, 30 niveaux) ; Q7 (les 15
époques d'OBJECTIFS §6 validées). Données : `shared/levels/config.lua` (pur, testé) ; prototypes :
`prototypes/levels.lua` (point d'entrée), `prototypes/levels/common.lua` (tout le non-visuel) et un fichier
de visuel par famille ; runtime : `script/levels/`.

> **Tous les tableaux chiffrés de cette section sont CALCULÉS sur la configuration** par
> `lua5.2 tests/levels_test.lua --tables` (ne pas les retoucher à la main : changer la config, relancer).
>
> **État au 21/10 (lot V2)** : cadre posé et prouvé **hors jeu** seulement (règles, courbe, chantiers et
> migration en moteur simulé, étape data, api_lint). **Non prouvé en moteur réel** : le banc `content` est
> réservé au lot P1 pendant ce lot. Visuel : **provisoire** (le schéma rejeté en E25, sur 15 époques) ; aucun
> progrès visuel n'est revendiqué. Le modèle de durée de jeu repose sur des **hypothèses ❔** à valider en
> partie réelle.

**Règles**
- **15 époques = 15 niveaux du centre de commandement** (l'hôtel de ville, 4×4, un par force) : le niveau du
  centre EST l'époque. Les 6 autres familles (mitrailleuse, tourelle laser, mur, foreuse électrique, four en
  acier, machine d'assemblage 2) ont **30 niveaux**, 2 par époque : les niveaux 2e-1 et 2e appartiennent à
  l'époque e ; le 1er change la silhouette, le 2e ajoute une pièce (visuel : lots V3). Le niveau 1 est le
  bâtiment vanilla (ou le centre de base).
- **Plafond** : un bâtiment ne dépasse jamais **2 × niveau du centre** (0.3.0 : centre + 1) ; le niveau n
  exige donc un centre ⌈n/2⌉. Sans centre, rien ne s'améliore.
- **Ouvriers** (chantiers simultanés) : 1 (centre 1-3), 2 (4-6), 3 (7-9), 4 (10-12), 5 (13-15). Les murs n'en
  occupent pas.
- **Paiement** : le stock du centre d'abord, puis l'inventaire du joueur (l'usine alimente le centre par
  convoyeurs : boucle « idle »). Stockage du centre : 48 cases + 16 par niveau (272 au niveau 15).
- **Chantier** : bâtiment hors service, barre de progression ; au terme, remplacement moteur « rapide »
  (contenu, recette, modules, munitions, fils conservés ; santé en proportion ; F39). Murs instantanés,
  rangée entière. Démonté en chantier : moitié du coût rendue ; détruit : perdu. Réglage de partie
  `fo-level-time-factor` (0 = instantané).

**Courbe de coûts et de durées PAR ÉPOQUE** (principe : « la croissance se fait par époque, nouveau
matériau requis, pas par exposant »)
- **Quelle monnaie** : une amélioration se paie avec le **matériau de l'époque pendant laquelle on la fait**.
  Familles : l'époque du niveau visé. Centre : passer au niveau n OUVRE l'époque n et se paie avec la monnaie
  de l'époque n - 1 (le centre est la porte de l'époque suivante).
- **Combien** : coût = panier de base de la famille + valeur d'époque.
  - Panier de base (époque 1 : fer, cuivre, pierre, engrenages, circuits) : **croissance linéaire**,
    × (1 + 0,15 (n - 2)) pour les familles (× 5,2 au niveau 30), × (1 + 0,4 (n - 2)) pour le centre (× 6,2
    au niveau 15).
  - Valeur d'époque = `epoch_value` de la famille × `value_mult` de l'époque (table ci-dessous, réglable
    époque par époque), × 1,25 au 2e niveau d'une époque. Elle se paie à **60 % en matériau de l'époque** et
    40 % en matériau de l'époque précédente (murs : 100 % matériau de l'époque). Le matériau de l'époque est
    toujours exigé, au moins 1.
  - Conversion valeur → quantité : valeur ÷ valeur unitaire de l'objet, arrondi lisible (entier sous 20,
    multiple de 5 sous 100, de 10 au-delà). Règle de monotonie : si l'arrondi rendait un niveau moins cher
    (en valeur) que le précédent, on ajoute du matériau de l'époque jusqu'à le dépasser (cas des murs).
  - Les quantités restent bornées (**au plus 1 130 objets d'une sorte**, testé ≤ 1 500) parce que le matériau
    change à chaque époque : la valeur monte, le nombre d'objets non. 1,5^28 ≈ 85 000 (ancienne courbe)
    n'apparaît plus nulle part.
- **Durée** : `time0` de la famille × `time_mult` de l'époque (× 1,1 au 2e niveau) ; centre : 60 s ×
  `cc_time_mult` de l'époque qui le paie (1 min pour le niveau 2, 1 h pour le niveau 15). Durées strictement
  croissantes (testé).
- **Valeur unitaire** (unités de matière brute : 1 = une plaque de fer ; 10 unités de fluide = 1),
  approximations d'après les recettes vanilla : plaque de fer 1, de cuivre 1, brique 2, engrenage 2, circuit
  2,5, acier 5, moteur 9 (acier, engrenage, 2 tuyaux), plastique 3 (20 gaz + charbon → 2), tungstène 4
  (2 minerais durs), batterie 9 (fer, cuivre, 20 acide), cristal 3 (minerai de biome), baril de méthane 10
  (50 méthane + baril d'acier), uranium 238 14 (10 minerais + acide), processeur 75, structure légère 45,
  moteur électrique 20, combustible nucléaire 130, unité de contrôle de fusée 150, pack de science spatiale
  250 (une fusée ≈ 245 000 pour 1 000 packs).

**Table d'indirection « matériau d'époque → objet »** (`L.epoch_materials`) : le jeu reste valide
AUJOURD'HUI (chaque objet de coût existe, vérifié hors jeu sur l'étape data et, au chargement, par le runtime
qui journalise `[FO-LEVELS]`). Les époques 11 à 15 utilisent des **remplaçants provisoires** existants ; le
lot X0 conçoit les matériaux voulus. Pour brancher un matériau livré, l'intégrateur change `item` et `value`
de la ligne de l'époque, et rien d'autre : toutes les quantités suivent. L'objet de l'époque 8 est le baril
de méthane que le jeu de base génère pour chaque fluide (un objet réel, pas un remplaçant). Le moteur
(`engine-unit`) tient lieu de matériau « vapeur » : l'eau et la vapeur sont des fluides, qu'on ne stocke pas
dans un coffre.

**Modèle de durée de jeu** (OBJECTIFS F1-3 ❔ : époque 1 en ~30 min, époque 15 vers ~60 h cumulées). Il
relie la courbe aux heures de jeu sous des **hypothèses à valider** (`L.target`) :
- durée visée de l'époque e : 0,5 × 1,261^(e-1) h (somme des 15 époques : 60 h) ;
- production de l'usine pendant l'époque e : de 2 u/s (fours à combustible) à 1 200 u/s (fin de partie, avec
  la Compaction ×4 du lot C), table `L.target.production` ;
- 30 % de la production consacrée aux niveaux ;
- base de référence : mitrailleuses 4 + 3 (e-1), tourelles laser à partir de l'époque 6 (4 + 4 (e-6)), murs
  20 + 30 (e-1), foreuses 6 + 8 (e-1), fours et machines d'assemblage à partir de l'époque 3 ; chaque bâtiment
  ajouté rattrape aussi les niveaux précédents.

Lecture : la dépense de la base de référence reste entre **0,63 et 1,41 fois** le budget de chaque époque
(testé entre 0,5 et 1,6) ; les époques 3 et 4 sont les plus chères (× 1,4 : on y améliore beaucoup de
bâtiments récents avec une petite usine). La charge des ouvriers reste ≤ 1 (au plus 1,0 à l'époque 6, juste
avant le 3e ouvrier). Un joueur qui ne monte que son centre va beaucoup plus vite ; un joueur qui monte tout
suit à peu près la cible. **Ces ordres de grandeur ne valent que ce que valent les hypothèses** : une partie
réelle (production mesurée, nombre de bâtiments) doit les recaler, en touchant les tables par époque.

**Statistiques** (niveau 1 = valeur vanilla × facteur ; tableaux complets plus bas)
- mêmes formules qu'en 0.3.0, prolongées jusqu'au niveau 30 : PV × (1 + 0,15 (n-1)), dégâts × (1 + 0,08 (n-1)),
  portée + 0,25 / niveau, rotation + 5 % / niveau, minage + 10 % / niveau (énergie + 7 %), vitesse des fours
  et machines + 8 % / niveau (énergie + 6 %) ; centre : PV × (1 + 0,2 (n-1)), + 16 cases / niveau ;
- **murs rééquilibrés** : 0.3.0 donnait PV × 1,3^(n-1), soit × 2 000 au niveau 30 (≈ 700 000 PV) ; c'est
  désormais × (1 + 0,5 (n-1)), 350 → 5 425 PV, et la réduction fixe physique et explosion passe de + 1 à
  + 0,5 par niveau (physique 3 → 17,5 au niveau 30, comparable au mur blindé du mod) ;
- toutes les statistiques sont strictement croissantes et au plus × 16 entre le niveau 1 et le dernier
  (testé) ; le dernier niveau rejoint les versions « lourdes » du mod sans les écraser (repères ci-dessous).
  L'énergie croît moins vite que la vitesse : l'investissement « idle » paie, sans saut de tier.

**Compatibilité des sauvegardes 0.3.0** (prouvée en moteur simulé, `tests/migration_test.lua`)
- Les noms `fo-command-center` et `fo-lvl-<famille>-<n>` (n ≤ 10) gardent leur sens : même famille, même
  niveau. L'état `global.fo.levels` garde sa forme : aucune donnée à convertir. Au changement de version, une
  réparation défensive retire les chantiers dont le bâtiment a disparu, remet en service un bâtiment dont la
  cible n'existerait plus, et recompte les ouvriers.
- Un chantier 0.3.0 en cours se termine normalement. Un bâtiment au niveau 10 (l'ancien maximum) peut
  monter au 11 si le centre est au niveau 6 ou plus. Les statistiques des niveaux 1 à 10 sont celles de
  0.3.0, **sauf les PV et résistances des murs** (un mur niveau 10 passe de 3 712 à 1 925 PV).
- Les coûts et durées changent pour tous les niveaux : le niveau 2 coûte environ la moitié de 0.3.0
  (mitrailleuse : 10 fer, 5 engrenages, 5 cuivre au lieu de 20, 10, 10) ; les ressources des biomes restent
  des monnaies, mais à leur époque (tungstène aux niveaux 9-10, cristal aux niveaux 13-14) et non plus comme
  supplément des niveaux 7 et 9.

**Design par niveau : PROVISOIRE, REJETÉ** (E25 : « je ne vois QUE un changement de couleur/teinte »). Le
lot V2 ne revendique aucun progrès visuel. Ce qui existe : teinte de l'époque (palette `kit.palette` de
`prototypes/levels/common.lua`), léger reflet au 2e niveau d'une époque, lueur à partir de l'époque 5, halo de
nuit à partir de l'époque 6, socle de tuiles, et une échelle **plafonnée à + 10 %** au dernier niveau
(0.3.0 : + 1,2 % par niveau, qui aurait donné + 35 % au niveau 30). Le centre garde ses antennes (époques 4
et 7). La cible reste OBJECTIFS.md D1 : chaque famille reçoit son visuel par époque dans
`prototypes/levels/<famille>.lua` (lots V3), à travers l'interface documentée en tête de `common.lua`.

**Défauts connus**
- Les recherches de dégâts des tourelles listent, dans leur infobulle, 29 lignes de plus par tourelle (une par
  niveau : héritage F21 par effets de technologie, 9 lignes en 0.3.0). Fonctionnel, mais chargé à l'écran.
- Quand un objet du panier de base est aussi une monnaie d'époque (acier, batterie de la tourelle laser), sa
  quantité peut baisser d'un niveau au suivant (laser : 11 aciers au niveau 6, 9 au niveau 7) ; la valeur
  totale, elle, croît toujours.
- Le remplaçant de l'époque 15 (pack de science spatiale) exige d'avoir lancé une fusée, et celui de
  l'époque 13 (combustible nucléaire) l'enrichissement de l'uranium : à confirmer en partie réelle.
- Coût script des niveaux non mesuré au banc épinglé (H-L1).

#### Les 15 époques et la table d'indirection des matériaux

| Époque | Thème | Matériau voulu | Objet en jeu aujourd'hui | Valeur unitaire (u) | Valeur d'époque (× époque 2) | Chantiers des bâtiments (× époque 1) | Chantier du centre payé dans l'époque (× 1 min) | Centre (niveau) | Niveaux des bâtiments | Ouvriers |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Pionnier | fer, cuivre, pierre (panier de base) | panier de base | — | 0 | 1 | 1 | 1 | 1-2 | 1 |
| 2 | Forge | acier | `steel-plate` | 5 | 1 | 1,4 | 2 | 2 | 3-4 | 1 |
| 3 | Vapeur | moteur (mécanique de l'ère vapeur) | `engine-unit` | 9 | 1,6 | 1,9 | 3 | 3 | 5-6 | 1 |
| 4 | Pétrole | plastique | `plastic-bar` | 3 | 2,5 | 2,5 | 5 | 4 | 7-8 | 2 |
| 5 | Volcan | plaque de tungstène | `fo-tungsten-plate` | 4 | 4 | 3,1 | 8 | 5 | 9-10 | 2 |
| 6 | Électricité | batterie | `battery` | 9 | 6,5 | 3,6 | 12 | 6 | 11-12 | 2 |
| 7 | Cristal | cristal de résonance | `fo-resonance-crystal` | 3 | 10,5 | 4,6 | 16 | 7 | 13-14 | 3 |
| 8 | Marais | méthane (baril) | `fo-methane-barrel` | 10 | 22 | 5,6 | 20 | 8 | 15-16 | 3 |
| 9 | Atome | uranium | `uranium-238` | 14 | 39 | 6,6 | 25 | 9 | 17-18 | 3 |
| 10 | Haute technologie | processeur | `processing-unit` | 75 | 68 | 8,4 | 30 | 10 | 19-20 | 4 |
| 11 | Titane | plaque de titane | `low-density-structure` **provisoire** (voulu : `fo-titanium-plate`) | 45 | 120 | 10 | 36 | 11 | 21-22 | 4 |
| 12 | Supraconducteurs | supraconducteur (terres rares) | `electric-engine-unit` **provisoire** (voulu : `fo-superconductor`) | 20 | 210 | 12 | 42 | 12 | 23-24 | 4 |
| 13 | Fusion | hélium-3 | `nuclear-fuel` **provisoire** (voulu : `fo-helium-3`) | 130 | 375 | 15 | 50 | 13 | 25-26 | 5 |
| 14 | Orbite | fragment de météorite | `rocket-control-unit` **provisoire** (voulu : `fo-meteorite`) | 150 | 665 | 17,5 | 60 | 14 | 27-28 | 5 |
| 15 | Légende | matière exotique | `space-science-pack` **provisoire** (voulu : `fo-exotic-matter`) | 250 | 1 180 | 21 | — | 15 | 29-30 | 5 |

#### Repères : niveau 1, niveau 10 (maximum de 0.3.0), dernier niveau, comparés au vanilla et au contenu du mod

| Famille | Statistique | Niveau 1 | Niveau 10 | Dernier niveau | Repère |
|---|---|---|---|---|---|
| Centre de commandement | max_health | 3 000 | 8 400 | 11 400 (niveau 15) | — |
| Centre de commandement | inventory_size | 48 | 192 | 272 (niveau 15) | coffre en acier : 48 cases |
| Mitrailleuse | max_health | 400 | 940 | 2 140 (niveau 30) | tourelle lourde (mod) : 2 000 |
| Mitrailleuse | damage_modifier | 1 | 1,72 | 3,32 (niveau 30) | tourelle lourde (mod) : 1,5 |
| Mitrailleuse | range | 18 | 20,25 | 25,25 (niveau 30) | tourelle lourde (mod) : 24 ; ver géant : 48 |
| Tourelle laser | max_health | 1 000 | 2 350 | 5 350 (niveau 30) | tourelle laser lourde (mod) : 3 000 |
| Tourelle laser | damage_modifier | 2 | 3,44 | 6,64 (niveau 30) | tourelle laser lourde (mod) : 4 |
| Tourelle laser | range | 24 | 26,25 | 31,25 (niveau 30) | tourelle laser lourde (mod) : 32 |
| Mur | max_health | 350 | 1 925 | 5 425 (niveau 30) | mur renforcé : 1 200 ; mur blindé : 3 500 |
| Mur | physical | 3 | 7,5 | 17,5 (niveau 30) | mur blindé : 3 + 15 = 18 (et 50 %) |
| Foreuse électrique | mining_speed | 0,5 | 0,95 | 1,95 (niveau 30) | foreuse électrique vanilla : 0,5 |
| Four en acier | crafting_speed | 2 | 3,44 | 6,64 (niveau 30) | four électrique vanilla : 2 |
| Machine d'assemblage 2 | crafting_speed | 0,75 | 1,29 | 2,49 (niveau 30) | machine d'assemblage 3 vanilla : 1,25 |

#### Modèle de durée de jeu (hypothèses de `L.target`, à valider en partie réelle)

| Époque | Durée visée | Cumul | Production (u/s) | Budget niveaux (u) | Dépense de la base de référence (u) | Dépense / budget | Temps d'ouvriers | Capacité des ouvriers | Charge des ouvriers | Chantier du centre suivant |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 30 min | 30 min | 2 | 1 080 | 685 | 0,63 | 2 min 15 s | 30 min | 0,07 | 300 u, 1 min |
| 2 | 37 min 50 s | 1 h 07 | 5 | 3 405 | 3 842 | 1,13 | 10 min 11 s | 37 min 50 s | 0,27 | 515 u, 2 min |
| 3 | 47 min 42 s | 1 h 55 | 10 | 8 587 | 12 109 | 1,41 | 30 min 46 s | 47 min 42 s | 0,65 | 777 u, 3 min |
| 4 | 1 h 00 | 2 h 55 | 17 | 18 407 | 25 553 | 1,39 | 1 h 07 | 2 h 00 | 0,56 | 1 041 u, 5 min |
| 5 | 1 h 15 | 4 h 11 | 27 | 36 865 | 42 571 | 1,15 | 1 h 53 | 2 h 31 | 0,75 | 1 375 u, 8 min |
| 6 | 1 h 35 | 5 h 47 | 40 | 68 870 | 75 405 | 1,09 | 3 h 10 | 3 h 11 | 1 | 1 885 u, 12 min |
| 7 | 2 h 00 | 7 h 47 | 60 | 130 267 | 115 904 | 0,89 | 4 h 47 | 6 h 01 | 0,79 | 2 615 u, 16 min |
| 8 | 2 h 32 | 10 h 19 | 88 | 240 925 | 207 562 | 0,86 | 6 h 46 | 7 h 36 | 0,89 | 4 458 u, 20 min |
| 9 | 3 h 11 | 13 h 31 | 125 | 431 543 | 363 355 | 0,84 | 9 h 10 | 9 h 35 | 0,96 | 7 063 u, 25 min |
| 10 | 4 h 01 | 17 h 33 | 180 | 783 614 | 659 334 | 0,84 | 12 h 45 | 16 h 07 | 0,79 | 11 435 u, 30 min |
| 11 | 5 h 04 | 22 h 38 | 260 | 1 427 309 | 1 145 140 | 0,8 | 16 h 50 | 20 h 19 | 0,83 | 19 425 u, 36 min |
| 12 | 6 h 24 | 29 h 03 | 380 | 2 630 530 | 2 059 885 | 0,78 | 22 h 01 | 25 h 38 | 0,86 | 33 225 u, 42 min |
| 13 | 8 h 04 | 37 h 08 | 560 | 4 888 356 | 3 889 341 | 0,8 | 29 h 24 | 40 h 24 | 0,73 | 58 150 u, 50 min |
| 14 | 10 h 11 | 47 h 19 | 820 | 9 026 175 | 7 346 878 | 0,81 | 37 h 12 | 50 h 57 | 0,73 | 102 150 u, 1 h 00 |
| 15 | 12 h 51 | 60 h 10 | 1 200 | 16 656 595 | 13 543 626 | 0,81 | 46 h 28 | 64 h 15 | 0,72 | — |

#### Centre de commandement (15 niveaux)

| Niveau | Époque | PV | cases | Coût du passage à ce niveau | Valeur (u) | Durée |
|---|---|---|---|---|---|---|
| 1 | 1 Pionnier | 3 000 | 48 | — | — | — |
| 2 | 2 Forge | 3 600 | 64 | 100 iron-plate, 50 copper-plate, 50 stone-brick, 20 electronic-circuit | 300 | 1 min |
| 3 | 3 Vapeur | 4 200 | 80 | 140 iron-plate, 70 copper-plate, 70 stone-brick, 30 electronic-circuit, 18 steel-plate | 515 | 2 min |
| 4 | 4 Pétrole | 4 800 | 96 | 180 iron-plate, 90 copper-plate, 90 stone-brick, 35 electronic-circuit, 16 engine-unit, 19 steel-plate | 777 | 3 min |
| 5 | 5 Volcan | 5 400 | 112 | 220 iron-plate, 110 copper-plate, 110 stone-brick, 45 electronic-circuit, 75 plastic-bar, 17 engine-unit | 1 041 | 5 min |
| 6 | 6 Électricité | 6 000 | 128 | 260 iron-plate, 130 copper-plate, 130 stone-brick, 50 electronic-circuit, 90 fo-tungsten-plate, 80 plastic-bar | 1 375 | 8 min |
| 7 | 7 Cristal | 6 600 | 144 | 300 iron-plate, 150 copper-plate, 150 stone-brick, 60 electronic-circuit, 65 battery, 100 fo-tungsten-plate | 1 885 | 12 min |
| 8 | 8 Marais | 7 200 | 160 | 340 iron-plate, 170 copper-plate, 170 stone-brick, 70 electronic-circuit, 320 fo-resonance-crystal, 70 battery | 2 615 | 16 min |
| 9 | 9 Atome | 7 800 | 176 | 380 iron-plate, 190 copper-plate, 190 stone-brick, 75 electronic-circuit, 200 fo-methane-barrel, 440 fo-resonance-crystal | 4 458 | 20 min |
| 10 | 10 Haute technologie | 8 400 | 192 | 420 iron-plate, 210 copper-plate, 210 stone-brick, 85 electronic-circuit, 250 uranium-238, 230 fo-methane-barrel | 7 063 | 25 min |
| 11 | 11 Titane | 9 000 | 208 | 460 iron-plate, 230 copper-plate, 230 stone-brick, 90 electronic-circuit, 80 processing-unit, 290 uranium-238 | 11 435 | 30 min |
| 12 | 12 Supraconducteurs | 9 600 | 224 | 500 iron-plate, 250 copper-plate, 250 stone-brick, 100 electronic-circuit, 240 low-density-structure, 95 processing-unit | 19 425 | 36 min |
| 13 | 13 Fusion | 10 200 | 240 | 540 iron-plate, 270 copper-plate, 270 stone-brick, 110 electronic-circuit, 950 electric-engine-unit, 280 low-density-structure | 33 225 | 42 min |
| 14 | 14 Orbite | 10 800 | 256 | 580 iron-plate, 290 copper-plate, 290 stone-brick, 120 electronic-circuit, 260 nuclear-fuel, 1 130 electric-engine-unit | 58 150 | 50 min |
| 15 | 15 Légende | 11 400 | 272 | 620 iron-plate, 310 copper-plate, 310 stone-brick, 120 electronic-circuit, 400 rocket-control-unit, 310 nuclear-fuel | 102 150 | 1 h 00 |

#### Mitrailleuse (30 niveaux)

| Niveau | Époque | PV | dégâts × | portée | Coût du passage à ce niveau | Valeur (u) | Durée |
|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 400 | 1 | 18 | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 460 | 1,08 | 18,25 | 10 iron-plate, 5 iron-gear-wheel, 5 copper-plate | 25 | 9 s |
| 3 | 2 Forge (silhouette) | 520 | 1,16 | 18,5 | 12 iron-plate, 6 iron-gear-wheel, 6 copper-plate, 1 steel-plate | 35 | 11 s |
| 4 | 2 Forge (+ pièce) | 580 | 1,24 | 18,75 | 13 iron-plate, 7 iron-gear-wheel, 7 copper-plate, 2 steel-plate | 44 | 12 s |
| 5 | 3 Vapeur (silhouette) | 640 | 1,32 | 19 | 15 iron-plate, 7 iron-gear-wheel, 7 copper-plate, 1 engine-unit, 2 steel-plate | 55 | 15 s |
| 6 | 3 Vapeur (+ pièce) | 700 | 1,4 | 19,25 | 16 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 2 engine-unit, 2 steel-plate | 68 | 17 s |
| 7 | 4 Pétrole (silhouette) | 760 | 1,48 | 19,5 | 18 iron-plate, 9 iron-gear-wheel, 9 copper-plate, 6 plastic-bar, 1 engine-unit | 72 | 20 s |
| 8 | 4 Pétrole (+ pièce) | 820 | 1,56 | 19,75 | 19 iron-plate, 10 iron-gear-wheel, 10 copper-plate, 8 plastic-bar, 2 engine-unit | 91 | 22 s |
| 9 | 5 Volcan (silhouette) | 880 | 1,64 | 20 | 20 iron-plate, 10 iron-gear-wheel, 10 copper-plate, 7 fo-tungsten-plate, 6 plastic-bar | 96 | 25 s |
| 10 | 5 Volcan (+ pièce) | 940 | 1,72 | 20,25 | 20 iron-plate, 11 iron-gear-wheel, 11 copper-plate, 9 fo-tungsten-plate, 8 plastic-bar | 113 | 27 s |
| 11 | 6 Électricité (silhouette) | 1 000 | 1,8 | 20,5 | 25 iron-plate, 12 iron-gear-wheel, 12 copper-plate, 5 battery, 8 fo-tungsten-plate | 138 | 29 s |
| 12 | 6 Électricité (+ pièce) | 1 060 | 1,88 | 20,75 | 25 iron-plate, 13 iron-gear-wheel, 13 copper-plate, 7 battery, 10 fo-tungsten-plate | 167 | 32 s |
| 13 | 7 Cristal (silhouette) | 1 120 | 1,96 | 21 | 25 iron-plate, 13 iron-gear-wheel, 13 copper-plate, 25 fo-resonance-crystal, 6 battery | 193 | 37 s |
| 14 | 7 Cristal (+ pièce) | 1 180 | 2,04 | 21,25 | 30 iron-plate, 14 iron-gear-wheel, 14 copper-plate, 30 fo-resonance-crystal, 7 battery | 225 | 40 s |
| 15 | 8 Marais (silhouette) | 1 240 | 2,12 | 21,5 | 30 iron-plate, 15 iron-gear-wheel, 15 copper-plate, 16 fo-methane-barrel, 35 fo-resonance-crystal | 340 | 45 s |
| 16 | 8 Marais (+ pièce) | 1 300 | 2,2 | 21,75 | 30 iron-plate, 16 iron-gear-wheel, 16 copper-plate, 20 fo-methane-barrel, 45 fo-resonance-crystal | 413 | 49 s |
| 17 | 9 Atome (silhouette) | 1 360 | 2,28 | 22 | 35 iron-plate, 16 iron-gear-wheel, 16 copper-plate, 20 uranium-238, 19 fo-methane-barrel | 553 | 53 s |
| 18 | 9 Atome (+ pièce) | 1 420 | 2,36 | 22,25 | 35 iron-plate, 17 iron-gear-wheel, 17 copper-plate, 25 uranium-238, 25 fo-methane-barrel | 686 | 58 s |
| 19 | 10 Haute technologie (silhouette) | 1 480 | 2,44 | 22,5 | 35 iron-plate, 18 iron-gear-wheel, 18 copper-plate, 7 processing-unit, 25 uranium-238 | 964 | 1 min 07 s |
| 20 | 10 Haute technologie (+ pièce) | 1 540 | 2,52 | 22,75 | 35 iron-plate, 19 iron-gear-wheel, 19 copper-plate, 8 processing-unit, 30 uranium-238 | 1 112 | 1 min 14 s |
| 21 | 11 Titane (silhouette) | 1 600 | 2,6 | 23 | 40 iron-plate, 19 iron-gear-wheel, 19 copper-plate, 19 low-density-structure, 8 processing-unit | 1 552 | 1 min 20 s |
| 22 | 11 Titane (+ pièce) | 1 660 | 2,68 | 23,25 | 40 iron-plate, 20 iron-gear-wheel, 20 copper-plate, 25 low-density-structure, 10 processing-unit | 1 975 | 1 min 28 s |
| 23 | 12 Supraconducteurs (silhouette) | 1 720 | 2,76 | 23,5 | 40 iron-plate, 20 iron-gear-wheel, 20 copper-plate, 75 electric-engine-unit, 20 low-density-structure | 2 500 | 1 min 36 s |
| 24 | 12 Supraconducteurs (+ pièce) | 1 780 | 2,84 | 23,75 | 45 iron-plate, 20 iron-gear-wheel, 20 copper-plate, 95 electric-engine-unit, 30 low-density-structure | 3 355 | 1 min 46 s |
| 25 | 13 Fusion (silhouette) | 1 840 | 2,92 | 24 | 45 iron-plate, 20 iron-gear-wheel, 20 copper-plate, 20 nuclear-fuel, 90 electric-engine-unit | 4 505 | 2 min |
| 26 | 13 Fusion (+ pièce) | 1 900 | 3 | 24,25 | 45 iron-plate, 25 iron-gear-wheel, 25 copper-plate, 25 nuclear-fuel, 110 electric-engine-unit | 5 570 | 2 min 12 s |
| 27 | 14 Orbite (silhouette) | 1 960 | 3,08 | 24,5 | 50 iron-plate, 25 iron-gear-wheel, 25 copper-plate, 30 rocket-control-unit, 25 nuclear-fuel | 7 875 | 2 min 20 s |
| 28 | 14 Orbite (+ pièce) | 2 020 | 3,16 | 24,75 | 50 iron-plate, 25 iron-gear-wheel, 25 copper-plate, 40 rocket-control-unit, 30 nuclear-fuel | 10 025 | 2 min 34 s |
| 29 | 15 Légende (silhouette) | 2 080 | 3,24 | 25 | 50 iron-plate, 25 iron-gear-wheel, 25 copper-plate, 35 space-science-pack, 40 rocket-control-unit | 14 875 | 2 min 48 s |
| 30 | 15 Légende (+ pièce) | 2 140 | 3,32 | 25,25 | 50 iron-plate, 25 iron-gear-wheel, 25 copper-plate, 40 space-science-pack, 45 rocket-control-unit | 16 875 | 3 min 05 s |

#### Tourelle laser (30 niveaux)

| Niveau | Époque | PV | dégâts × | portée | Coût du passage à ce niveau | Valeur (u) | Durée |
|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 1 000 | 2 | 24 | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 1 150 | 2,16 | 24,25 | 5 steel-plate, 5 electronic-circuit, 3 battery | 65 | 13 s |
| 3 | 2 Forge (silhouette) | 1 300 | 2,32 | 24,5 | 8 steel-plate, 6 electronic-circuit, 3 battery | 82 | 17 s |
| 4 | 2 Forge (+ pièce) | 1 450 | 2,48 | 24,75 | 10 steel-plate, 7 electronic-circuit, 4 battery | 104 | 18 s |
| 5 | 3 Vapeur (silhouette) | 1 600 | 2,64 | 25 | 10 steel-plate, 7 electronic-circuit, 4 battery, 2 engine-unit | 122 | 23 s |
| 6 | 3 Vapeur (+ pièce) | 1 750 | 2,8 | 25,25 | 11 steel-plate, 8 electronic-circuit, 5 battery, 3 engine-unit | 147 | 25 s |
| 7 | 4 Pétrole (silhouette) | 1 900 | 2,96 | 25,5 | 9 steel-plate, 9 electronic-circuit, 5 battery, 10 plastic-bar, 2 engine-unit | 161 | 30 s |
| 8 | 4 Pétrole (+ pièce) | 2 050 | 3,12 | 25,75 | 10 steel-plate, 10 electronic-circuit, 6 battery, 13 plastic-bar, 3 engine-unit | 195 | 33 s |
| 9 | 5 Volcan (silhouette) | 2 200 | 3,28 | 26 | 10 steel-plate, 10 electronic-circuit, 6 battery, 12 fo-tungsten-plate, 11 plastic-bar | 210 | 37 s |
| 10 | 5 Volcan (+ pièce) | 2 350 | 3,44 | 26,25 | 11 steel-plate, 11 electronic-circuit, 7 battery, 15 fo-tungsten-plate, 13 plastic-bar | 245 | 41 s |
| 11 | 6 Électricité (silhouette) | 2 500 | 3,6 | 26,5 | 12 steel-plate, 12 electronic-circuit, 16 battery, 13 fo-tungsten-plate | 286 | 43 s |
| 12 | 6 Électricité (+ pièce) | 2 650 | 3,76 | 26,75 | 13 steel-plate, 13 electronic-circuit, 19 battery, 16 fo-tungsten-plate | 333 | 48 s |
| 13 | 7 Cristal (silhouette) | 2 800 | 3,92 | 27 | 13 steel-plate, 13 electronic-circuit, 17 battery, 40 fo-resonance-crystal | 371 | 55 s |
| 14 | 7 Cristal (+ pièce) | 2 950 | 4,08 | 27,25 | 14 steel-plate, 14 electronic-circuit, 20 battery, 55 fo-resonance-crystal | 450 | 1 min 01 s |
| 15 | 8 Marais (silhouette) | 3 100 | 4,24 | 27,5 | 15 steel-plate, 15 electronic-circuit, 9 battery, 25 fo-methane-barrel, 60 fo-resonance-crystal | 624 | 1 min 07 s |
| 16 | 8 Marais (+ pièce) | 3 250 | 4,4 | 27,75 | 16 steel-plate, 16 electronic-circuit, 9 battery, 35 fo-methane-barrel, 75 fo-resonance-crystal | 776 | 1 min 14 s |
| 17 | 9 Atome (silhouette) | 3 400 | 4,56 | 28 | 16 steel-plate, 16 electronic-circuit, 10 battery, 35 uranium-238, 30 fo-methane-barrel | 1 000 | 1 min 19 s |
| 18 | 9 Atome (+ pièce) | 3 550 | 4,72 | 28,25 | 17 steel-plate, 17 electronic-circuit, 10 battery, 40 uranium-238, 40 fo-methane-barrel | 1 178 | 1 min 27 s |
| 19 | 10 Haute technologie (silhouette) | 3 700 | 4,88 | 28,5 | 18 steel-plate, 18 electronic-circuit, 11 battery, 11 processing-unit, 40 uranium-238 | 1 619 | 1 min 41 s |
| 20 | 10 Haute technologie (+ pièce) | 3 850 | 5,04 | 28,75 | 19 steel-plate, 19 electronic-circuit, 11 battery, 14 processing-unit, 50 uranium-238 | 1 992 | 1 min 51 s |
| 21 | 11 Titane (silhouette) | 4 000 | 5,2 | 29 | 19 steel-plate, 19 electronic-circuit, 12 battery, 30 low-density-structure, 13 processing-unit | 2 576 | 2 min |
| 22 | 11 Titane (+ pièce) | 4 150 | 5,36 | 29,25 | 20 steel-plate, 20 electronic-circuit, 12 battery, 40 low-density-structure, 16 processing-unit | 3 258 | 2 min 12 s |
| 23 | 12 Supraconducteurs (silhouette) | 4 300 | 5,52 | 29,5 | 20 steel-plate, 20 electronic-circuit, 12 battery, 130 electric-engine-unit, 35 low-density-structure | 4 433 | 2 min 24 s |
| 24 | 12 Supraconducteurs (+ pièce) | 4 450 | 5,68 | 29,75 | 20 steel-plate, 20 electronic-circuit, 13 battery, 160 electric-engine-unit, 45 low-density-structure | 5 492 | 2 min 38 s |
| 25 | 13 Fusion (silhouette) | 4 600 | 5,84 | 30 | 20 steel-plate, 20 electronic-circuit, 13 battery, 35 nuclear-fuel, 150 electric-engine-unit | 7 817 | 3 min |
| 26 | 13 Fusion (+ pièce) | 4 750 | 6 | 30,25 | 25 steel-plate, 25 electronic-circuit, 14 battery, 45 nuclear-fuel, 190 electric-engine-unit | 9 964 | 3 min 18 s |
| 27 | 14 Orbite (silhouette) | 4 900 | 6,16 | 30,5 | 25 steel-plate, 25 electronic-circuit, 14 battery, 55 rocket-control-unit, 40 nuclear-fuel | 13 764 | 3 min 30 s |
| 28 | 14 Orbite (+ pièce) | 5 050 | 6,32 | 30,75 | 25 steel-plate, 25 electronic-circuit, 15 battery, 65 rocket-control-unit, 50 nuclear-fuel | 16 573 | 3 min 51 s |
| 29 | 15 Légende (silhouette) | 5 200 | 6,48 | 31 | 25 steel-plate, 25 electronic-circuit, 15 battery, 55 space-science-pack, 65 rocket-control-unit | 23 823 | 4 min 12 s |
| 30 | 15 Légende (+ pièce) | 5 350 | 6,64 | 31,25 | 25 steel-plate, 25 electronic-circuit, 16 battery, 70 space-science-pack, 80 rocket-control-unit | 29 832 | 4 min 37 s |

#### Mur (30 niveaux)

| Niveau | Époque | PV | réduction physique | réduction explosion | Coût du passage à ce niveau | Valeur (u) | Durée |
|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 350 | 3 | 10 | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 525 | 3,5 | 10,5 | 3 stone-brick | 6 | instantané |
| 3 | 2 Forge (silhouette) | 700 | 4 | 11 | 3 stone-brick, 1 steel-plate | 11 | instantané |
| 4 | 2 Forge (+ pièce) | 875 | 4,5 | 11,5 | 4 stone-brick, 1 steel-plate | 13 | instantané |
| 5 | 3 Vapeur (silhouette) | 1 050 | 5 | 12 | 4 stone-brick, 1 engine-unit | 17 | instantané |
| 6 | 3 Vapeur (+ pièce) | 1 225 | 5,5 | 12,5 | 5 stone-brick, 1 engine-unit | 19 | instantané |
| 7 | 4 Pétrole (silhouette) | 1 400 | 6 | 13 | 5 stone-brick, 4 plastic-bar | 22 | instantané |
| 8 | 4 Pétrole (+ pièce) | 1 575 | 6,5 | 13,5 | 6 stone-brick, 4 plastic-bar | 24 | instantané |
| 9 | 5 Volcan (silhouette) | 1 750 | 7 | 14 | 6 stone-brick, 4 fo-tungsten-plate | 28 | instantané |
| 10 | 5 Volcan (+ pièce) | 1 925 | 7,5 | 14,5 | 7 stone-brick, 4 fo-tungsten-plate | 30 | instantané |
| 11 | 6 Électricité (silhouette) | 2 100 | 8 | 15 | 7 stone-brick, 2 battery | 32 | instantané |
| 12 | 6 Électricité (+ pièce) | 2 275 | 8,5 | 15,5 | 8 stone-brick, 2 battery | 34 | instantané |
| 13 | 7 Cristal (silhouette) | 2 450 | 9 | 16 | 8 stone-brick, 7 fo-resonance-crystal | 37 | instantané |
| 14 | 7 Cristal (+ pièce) | 2 625 | 9,5 | 16,5 | 8 stone-brick, 9 fo-resonance-crystal | 43 | instantané |
| 15 | 8 Marais (silhouette) | 2 800 | 10 | 17 | 9 stone-brick, 4 fo-methane-barrel | 58 | instantané |
| 16 | 8 Marais (+ pièce) | 2 975 | 10,5 | 17,5 | 9 stone-brick, 6 fo-methane-barrel | 78 | instantané |
| 17 | 9 Atome (silhouette) | 3 150 | 11 | 18 | 10 stone-brick, 6 uranium-238 | 104 | instantané |
| 18 | 9 Atome (+ pièce) | 3 325 | 11,5 | 18,5 | 10 stone-brick, 7 uranium-238 | 118 | instantané |
| 19 | 10 Haute technologie (silhouette) | 3 500 | 12 | 19 | 11 stone-brick, 2 processing-unit | 172 | instantané |
| 20 | 10 Haute technologie (+ pièce) | 3 675 | 12,5 | 19,5 | 11 stone-brick, 3 processing-unit | 247 | instantané |
| 21 | 11 Titane (silhouette) | 3 850 | 13 | 20 | 12 stone-brick, 5 low-density-structure | 249 | instantané |
| 22 | 11 Titane (+ pièce) | 4 025 | 13,5 | 20,5 | 12 stone-brick, 7 low-density-structure | 339 | instantané |
| 23 | 12 Supraconducteurs (silhouette) | 4 200 | 14 | 21 | 12 stone-brick, 20 electric-engine-unit | 424 | instantané |
| 24 | 12 Supraconducteurs (+ pièce) | 4 375 | 14,5 | 21,5 | 13 stone-brick, 25 electric-engine-unit | 526 | instantané |
| 25 | 13 Fusion (silhouette) | 4 550 | 15 | 22 | 13 stone-brick, 6 nuclear-fuel | 806 | instantané |
| 26 | 13 Fusion (+ pièce) | 4 725 | 15,5 | 22,5 | 14 stone-brick, 7 nuclear-fuel | 938 | instantané |
| 27 | 14 Orbite (silhouette) | 4 900 | 16 | 23 | 14 stone-brick, 9 rocket-control-unit | 1 378 | instantané |
| 28 | 14 Orbite (+ pièce) | 5 075 | 16,5 | 23,5 | 15 stone-brick, 11 rocket-control-unit | 1 680 | instantané |
| 29 | 15 Légende (silhouette) | 5 250 | 17 | 24 | 15 stone-brick, 9 space-science-pack | 2 280 | instantané |
| 30 | 15 Légende (+ pièce) | 5 425 | 17,5 | 24,5 | 16 stone-brick, 12 space-science-pack | 3 032 | instantané |

#### Foreuse électrique (30 niveaux)

| Niveau | Époque | PV | minage | kW | Coût du passage à ce niveau | Valeur (u) | Durée |
|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 300 | 0,5 | 90 | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 345 | 0,55 | 96,3 | 10 iron-plate, 5 iron-gear-wheel, 3 electronic-circuit | 28 | 7 s |
| 3 | 2 Forge (silhouette) | 390 | 0,6 | 102,6 | 12 iron-plate, 6 iron-gear-wheel, 3 electronic-circuit, 1 steel-plate | 37 | 8 s |
| 4 | 2 Forge (+ pièce) | 435 | 0,65 | 108,9 | 13 iron-plate, 7 iron-gear-wheel, 4 electronic-circuit, 1 steel-plate | 42 | 9 s |
| 5 | 3 Vapeur (silhouette) | 480 | 0,7 | 115,2 | 15 iron-plate, 7 iron-gear-wheel, 4 electronic-circuit, 1 engine-unit, 1 steel-plate | 53 | 11 s |
| 6 | 3 Vapeur (+ pièce) | 525 | 0,75 | 121,5 | 16 iron-plate, 8 iron-gear-wheel, 5 electronic-circuit, 1 engine-unit, 1 steel-plate | 59 | 13 s |
| 7 | 4 Pétrole (silhouette) | 570 | 0,8 | 127,8 | 18 iron-plate, 9 iron-gear-wheel, 5 electronic-circuit, 4 plastic-bar, 1 engine-unit | 70 | 15 s |
| 8 | 4 Pétrole (+ pièce) | 615 | 0,85 | 134,1 | 19 iron-plate, 10 iron-gear-wheel, 6 electronic-circuit, 4 plastic-bar, 1 engine-unit | 75 | 17 s |
| 9 | 5 Volcan (silhouette) | 660 | 0,9 | 140,4 | 20 iron-plate, 10 iron-gear-wheel, 6 electronic-circuit, 4 fo-tungsten-plate, 4 plastic-bar | 83 | 19 s |
| 10 | 5 Volcan (+ pièce) | 705 | 0,95 | 146,7 | 20 iron-plate, 11 iron-gear-wheel, 7 electronic-circuit, 5 fo-tungsten-plate, 5 plastic-bar | 95 | 20 s |
| 11 | 6 Électricité (silhouette) | 750 | 1 | 153 | 25 iron-plate, 12 iron-gear-wheel, 7 electronic-circuit, 3 battery, 5 fo-tungsten-plate | 114 | 22 s |
| 12 | 6 Électricité (+ pièce) | 795 | 1,05 | 159,3 | 25 iron-plate, 13 iron-gear-wheel, 8 electronic-circuit, 4 battery, 6 fo-tungsten-plate | 131 | 24 s |
| 13 | 7 Cristal (silhouette) | 840 | 1,1 | 165,6 | 25 iron-plate, 13 iron-gear-wheel, 8 electronic-circuit, 15 fo-resonance-crystal, 3 battery | 143 | 28 s |
| 14 | 7 Cristal (+ pièce) | 885 | 1,15 | 171,9 | 30 iron-plate, 14 iron-gear-wheel, 8 electronic-circuit, 18 fo-resonance-crystal, 4 battery | 168 | 30 s |
| 15 | 8 Marais (silhouette) | 930 | 1,2 | 178,2 | 30 iron-plate, 15 iron-gear-wheel, 9 electronic-circuit, 9 fo-methane-barrel, 20 fo-resonance-crystal | 233 | 34 s |
| 16 | 8 Marais (+ pièce) | 975 | 1,25 | 184,5 | 30 iron-plate, 16 iron-gear-wheel, 9 electronic-circuit, 12 fo-methane-barrel, 25 fo-resonance-crystal | 280 | 37 s |
| 17 | 9 Atome (silhouette) | 1 020 | 1,3 | 190,8 | 35 iron-plate, 16 iron-gear-wheel, 10 electronic-circuit, 12 uranium-238, 11 fo-methane-barrel | 370 | 40 s |
| 18 | 9 Atome (+ pièce) | 1 065 | 1,35 | 197,1 | 35 iron-plate, 17 iron-gear-wheel, 10 electronic-circuit, 15 uranium-238, 14 fo-methane-barrel | 444 | 44 s |
| 19 | 10 Haute technologie (silhouette) | 1 110 | 1,4 | 203,4 | 35 iron-plate, 18 iron-gear-wheel, 11 electronic-circuit, 4 processing-unit, 14 uranium-238 | 595 | 50 s |
| 20 | 10 Haute technologie (+ pièce) | 1 155 | 1,45 | 209,7 | 35 iron-plate, 19 iron-gear-wheel, 11 electronic-circuit, 5 processing-unit, 17 uranium-238 | 714 | 55 s |
| 21 | 11 Titane (silhouette) | 1 200 | 1,5 | 216 | 40 iron-plate, 19 iron-gear-wheel, 12 electronic-circuit, 11 low-density-structure, 4 processing-unit | 903 | 1 min |
| 22 | 11 Titane (+ pièce) | 1 245 | 1,55 | 222,3 | 40 iron-plate, 20 iron-gear-wheel, 12 electronic-circuit, 14 low-density-structure, 6 processing-unit | 1 190 | 1 min 06 s |
| 23 | 12 Supraconducteurs (silhouette) | 1 290 | 1,6 | 228,6 | 40 iron-plate, 20 iron-gear-wheel, 12 electronic-circuit, 45 electric-engine-unit, 13 low-density-structure | 1 595 | 1 min 12 s |
| 24 | 12 Supraconducteurs (+ pièce) | 1 335 | 1,65 | 234,9 | 45 iron-plate, 20 iron-gear-wheel, 13 electronic-circuit, 55 electric-engine-unit, 16 low-density-structure | 1 938 | 1 min 19 s |
| 25 | 13 Fusion (silhouette) | 1 380 | 1,7 | 241,2 | 45 iron-plate, 20 iron-gear-wheel, 13 electronic-circuit, 12 nuclear-fuel, 55 electric-engine-unit | 2 778 | 1 min 30 s |
| 26 | 13 Fusion (+ pièce) | 1 425 | 1,75 | 247,5 | 45 iron-plate, 25 iron-gear-wheel, 14 electronic-circuit, 15 nuclear-fuel, 65 electric-engine-unit | 3 380 | 1 min 39 s |
| 27 | 14 Orbite (silhouette) | 1 470 | 1,8 | 253,8 | 50 iron-plate, 25 iron-gear-wheel, 14 electronic-circuit, 19 rocket-control-unit, 14 nuclear-fuel | 4 805 | 1 min 45 s |
| 28 | 14 Orbite (+ pièce) | 1 515 | 1,85 | 260,1 | 50 iron-plate, 25 iron-gear-wheel, 15 electronic-circuit, 25 rocket-control-unit, 18 nuclear-fuel | 6 228 | 1 min 56 s |
| 29 | 15 Légende (silhouette) | 1 560 | 1,9 | 266,4 | 50 iron-plate, 25 iron-gear-wheel, 15 electronic-circuit, 20 space-science-pack, 20 rocket-control-unit | 8 138 | 2 min 06 s |
| 30 | 15 Légende (+ pièce) | 1 605 | 1,95 | 272,7 | 50 iron-plate, 25 iron-gear-wheel, 16 electronic-circuit, 25 space-science-pack, 30 rocket-control-unit | 10 890 | 2 min 19 s |

#### Four en acier (30 niveaux)

| Niveau | Époque | PV | vitesse | kW | Coût du passage à ce niveau | Valeur (u) | Durée |
|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 300 | 2 | 90 | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 345 | 2,16 | 95,4 | 3 steel-plate, 5 stone-brick | 25 | 6 s |
| 3 | 2 Forge (silhouette) | 390 | 2,32 | 100,8 | 4 steel-plate, 6 stone-brick | 32 | 7 s |
| 4 | 2 Forge (+ pièce) | 435 | 2,48 | 106,2 | 5 steel-plate, 7 stone-brick | 39 | 8 s |
| 5 | 3 Vapeur (silhouette) | 480 | 2,64 | 111,6 | 5 steel-plate, 7 stone-brick, 1 engine-unit | 48 | 10 s |
| 6 | 3 Vapeur (+ pièce) | 525 | 2,8 | 117 | 6 steel-plate, 8 stone-brick, 1 engine-unit | 55 | 10 s |
| 7 | 4 Pétrole (silhouette) | 570 | 2,96 | 122,4 | 5 steel-plate, 9 stone-brick, 3 plastic-bar, 1 engine-unit | 61 | 13 s |
| 8 | 4 Pétrole (+ pièce) | 615 | 3,12 | 127,8 | 6 steel-plate, 10 stone-brick, 4 plastic-bar, 1 engine-unit | 71 | 14 s |
| 9 | 5 Volcan (silhouette) | 660 | 3,28 | 133,2 | 6 steel-plate, 10 stone-brick, 4 fo-tungsten-plate, 3 plastic-bar | 75 | 16 s |
| 10 | 5 Volcan (+ pièce) | 705 | 3,44 | 138,6 | 7 steel-plate, 11 stone-brick, 5 fo-tungsten-plate, 4 plastic-bar | 89 | 17 s |
| 11 | 6 Électricité (silhouette) | 750 | 3,6 | 144 | 7 steel-plate, 12 stone-brick, 3 battery, 4 fo-tungsten-plate | 102 | 18 s |
| 12 | 6 Électricité (+ pièce) | 795 | 3,76 | 149,4 | 8 steel-plate, 13 stone-brick, 3 battery, 5 fo-tungsten-plate | 113 | 20 s |
| 13 | 7 Cristal (silhouette) | 840 | 3,92 | 154,8 | 8 steel-plate, 13 stone-brick, 13 fo-resonance-crystal, 3 battery | 132 | 23 s |
| 14 | 7 Cristal (+ pièce) | 885 | 4,08 | 160,2 | 8 steel-plate, 14 stone-brick, 16 fo-resonance-crystal, 4 battery | 152 | 25 s |
| 15 | 8 Marais (silhouette) | 930 | 4,24 | 165,6 | 9 steel-plate, 15 stone-brick, 8 fo-methane-barrel, 18 fo-resonance-crystal | 209 | 28 s |
| 16 | 8 Marais (+ pièce) | 975 | 4,4 | 171 | 9 steel-plate, 16 stone-brick, 10 fo-methane-barrel, 20 fo-resonance-crystal | 237 | 31 s |
| 17 | 9 Atome (silhouette) | 1 020 | 4,56 | 176,4 | 10 steel-plate, 16 stone-brick, 10 uranium-238, 9 fo-methane-barrel | 312 | 33 s |
| 18 | 9 Atome (+ pièce) | 1 065 | 4,72 | 181,8 | 10 steel-plate, 17 stone-brick, 13 uranium-238, 12 fo-methane-barrel | 386 | 36 s |
| 19 | 10 Haute technologie (silhouette) | 1 110 | 4,88 | 187,2 | 11 steel-plate, 18 stone-brick, 3 processing-unit, 12 uranium-238 | 484 | 42 s |
| 20 | 10 Haute technologie (+ pièce) | 1 155 | 5,04 | 192,6 | 11 steel-plate, 19 stone-brick, 4 processing-unit, 15 uranium-238 | 603 | 46 s |
| 21 | 11 Titane (silhouette) | 1 200 | 5,2 | 198 | 12 steel-plate, 19 stone-brick, 10 low-density-structure, 4 processing-unit | 848 | 50 s |
| 22 | 11 Titane (+ pièce) | 1 245 | 5,36 | 203,4 | 12 steel-plate, 20 stone-brick, 12 low-density-structure, 5 processing-unit | 1 015 | 55 s |
| 23 | 12 Supraconducteurs (silhouette) | 1 290 | 5,52 | 208,8 | 12 steel-plate, 20 stone-brick, 40 electric-engine-unit, 11 low-density-structure | 1 395 | 1 min |
| 24 | 12 Supraconducteurs (+ pièce) | 1 335 | 5,68 | 214,2 | 13 steel-plate, 20 stone-brick, 45 electric-engine-unit, 14 low-density-structure | 1 635 | 1 min 06 s |
| 25 | 13 Fusion (silhouette) | 1 380 | 5,84 | 219,6 | 13 steel-plate, 20 stone-brick, 10 nuclear-fuel, 45 electric-engine-unit | 2 305 | 1 min 15 s |
| 26 | 13 Fusion (+ pièce) | 1 425 | 6 | 225 | 14 steel-plate, 25 stone-brick, 13 nuclear-fuel, 55 electric-engine-unit | 2 910 | 1 min 23 s |
| 27 | 14 Orbite (silhouette) | 1 470 | 6,16 | 230,4 | 14 steel-plate, 25 stone-brick, 16 rocket-control-unit, 12 nuclear-fuel | 4 080 | 1 min 28 s |
| 28 | 14 Orbite (+ pièce) | 1 515 | 6,32 | 235,8 | 15 steel-plate, 25 stone-brick, 20 rocket-control-unit, 15 nuclear-fuel | 5 075 | 1 min 36 s |
| 29 | 15 Légende (silhouette) | 1 560 | 6,48 | 241,2 | 15 steel-plate, 25 stone-brick, 17 space-science-pack, 19 rocket-control-unit | 7 225 | 1 min 45 s |
| 30 | 15 Légende (+ pièce) | 1 605 | 6,64 | 246,6 | 16 steel-plate, 25 stone-brick, 20 space-science-pack, 25 rocket-control-unit | 8 880 | 1 min 56 s |

#### Machine d'assemblage 2 (30 niveaux)

| Niveau | Époque | PV | vitesse | kW | Coût du passage à ce niveau | Valeur (u) | Durée |
|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 350 | 0,75 | 150 | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 402,5 | 0,81 | 159 | 10 iron-plate, 5 iron-gear-wheel, 5 electronic-circuit | 33 | 7 s |
| 3 | 2 Forge (silhouette) | 455 | 0,87 | 168 | 12 iron-plate, 6 iron-gear-wheel, 6 electronic-circuit, 1 steel-plate | 44 | 8 s |
| 4 | 2 Forge (+ pièce) | 507,5 | 0,93 | 177 | 13 iron-plate, 7 iron-gear-wheel, 7 electronic-circuit, 1 steel-plate | 50 | 9 s |
| 5 | 3 Vapeur (silhouette) | 560 | 0,99 | 186 | 15 iron-plate, 7 iron-gear-wheel, 7 electronic-circuit, 1 engine-unit, 1 steel-plate | 61 | 11 s |
| 6 | 3 Vapeur (+ pièce) | 612,5 | 1,05 | 195 | 16 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 1 engine-unit, 1 steel-plate | 66 | 13 s |
| 7 | 4 Pétrole (silhouette) | 665 | 1,11 | 204 | 18 iron-plate, 9 iron-gear-wheel, 9 electronic-circuit, 4 plastic-bar, 1 engine-unit | 80 | 15 s |
| 8 | 4 Pétrole (+ pièce) | 717,5 | 1,17 | 213 | 19 iron-plate, 10 iron-gear-wheel, 10 electronic-circuit, 4 plastic-bar, 1 engine-unit | 85 | 17 s |
| 9 | 5 Volcan (silhouette) | 770 | 1,23 | 222 | 20 iron-plate, 10 iron-gear-wheel, 10 electronic-circuit, 4 fo-tungsten-plate, 4 plastic-bar | 93 | 19 s |
| 10 | 5 Volcan (+ pièce) | 822,5 | 1,29 | 231 | 20 iron-plate, 11 iron-gear-wheel, 11 electronic-circuit, 5 fo-tungsten-plate, 5 plastic-bar | 105 | 20 s |
| 11 | 6 Électricité (silhouette) | 875 | 1,35 | 240 | 25 iron-plate, 12 iron-gear-wheel, 12 electronic-circuit, 3 battery, 5 fo-tungsten-plate | 126 | 22 s |
| 12 | 6 Électricité (+ pièce) | 927,5 | 1,41 | 249 | 25 iron-plate, 13 iron-gear-wheel, 13 electronic-circuit, 4 battery, 6 fo-tungsten-plate | 144 | 24 s |
| 13 | 7 Cristal (silhouette) | 980 | 1,47 | 258 | 25 iron-plate, 13 iron-gear-wheel, 13 electronic-circuit, 15 fo-resonance-crystal, 3 battery | 156 | 28 s |
| 14 | 7 Cristal (+ pièce) | 1032,5 | 1,53 | 267 | 30 iron-plate, 14 iron-gear-wheel, 14 electronic-circuit, 18 fo-resonance-crystal, 4 battery | 183 | 30 s |
| 15 | 8 Marais (silhouette) | 1 085 | 1,59 | 276 | 30 iron-plate, 15 iron-gear-wheel, 15 electronic-circuit, 9 fo-methane-barrel, 20 fo-resonance-crystal | 248 | 34 s |
| 16 | 8 Marais (+ pièce) | 1137,5 | 1,65 | 285 | 30 iron-plate, 16 iron-gear-wheel, 16 electronic-circuit, 12 fo-methane-barrel, 25 fo-resonance-crystal | 297 | 37 s |
| 17 | 9 Atome (silhouette) | 1 190 | 1,71 | 294 | 35 iron-plate, 16 iron-gear-wheel, 16 electronic-circuit, 12 uranium-238, 11 fo-methane-barrel | 385 | 40 s |
| 18 | 9 Atome (+ pièce) | 1242,5 | 1,77 | 303 | 35 iron-plate, 17 iron-gear-wheel, 17 electronic-circuit, 15 uranium-238, 14 fo-methane-barrel | 462 | 44 s |
| 19 | 10 Haute technologie (silhouette) | 1 295 | 1,83 | 312 | 35 iron-plate, 18 iron-gear-wheel, 18 electronic-circuit, 4 processing-unit, 14 uranium-238 | 612 | 50 s |
| 20 | 10 Haute technologie (+ pièce) | 1347,5 | 1,89 | 321 | 35 iron-plate, 19 iron-gear-wheel, 19 electronic-circuit, 5 processing-unit, 17 uranium-238 | 734 | 55 s |
| 21 | 11 Titane (silhouette) | 1 400 | 1,95 | 330 | 40 iron-plate, 19 iron-gear-wheel, 19 electronic-circuit, 11 low-density-structure, 4 processing-unit | 921 | 1 min |
| 22 | 11 Titane (+ pièce) | 1452,5 | 2,01 | 339 | 40 iron-plate, 20 iron-gear-wheel, 20 electronic-circuit, 14 low-density-structure, 6 processing-unit | 1 210 | 1 min 06 s |
| 23 | 12 Supraconducteurs (silhouette) | 1 505 | 2,07 | 348 | 40 iron-plate, 20 iron-gear-wheel, 20 electronic-circuit, 45 electric-engine-unit, 13 low-density-structure | 1 615 | 1 min 12 s |
| 24 | 12 Supraconducteurs (+ pièce) | 1557,5 | 2,13 | 357 | 45 iron-plate, 20 iron-gear-wheel, 20 electronic-circuit, 55 electric-engine-unit, 16 low-density-structure | 1 955 | 1 min 19 s |
| 25 | 13 Fusion (silhouette) | 1 610 | 2,19 | 366 | 45 iron-plate, 20 iron-gear-wheel, 20 electronic-circuit, 12 nuclear-fuel, 55 electric-engine-unit | 2 795 | 1 min 30 s |
| 26 | 13 Fusion (+ pièce) | 1662,5 | 2,25 | 375 | 45 iron-plate, 25 iron-gear-wheel, 25 electronic-circuit, 15 nuclear-fuel, 65 electric-engine-unit | 3 408 | 1 min 39 s |
| 27 | 14 Orbite (silhouette) | 1 715 | 2,31 | 384 | 50 iron-plate, 25 iron-gear-wheel, 25 electronic-circuit, 19 rocket-control-unit, 14 nuclear-fuel | 4 833 | 1 min 45 s |
| 28 | 14 Orbite (+ pièce) | 1767,5 | 2,37 | 393 | 50 iron-plate, 25 iron-gear-wheel, 25 electronic-circuit, 25 rocket-control-unit, 18 nuclear-fuel | 6 253 | 1 min 56 s |
| 29 | 15 Légende (silhouette) | 1 820 | 2,43 | 402 | 50 iron-plate, 25 iron-gear-wheel, 25 electronic-circuit, 20 space-science-pack, 20 rocket-control-unit | 8 163 | 2 min 06 s |
| 30 | 15 Légende (+ pièce) | 1872,5 | 2,49 | 411 | 50 iron-plate, 25 iron-gear-wheel, 25 electronic-circuit, 25 space-science-pack, 30 rocket-control-unit | 10 913 | 2 min 19 s |
