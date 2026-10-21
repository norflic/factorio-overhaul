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

### 10 bis. PvP et difficulté (lot IA0, 21/10)
Réglage de partie `fo-pvp-difficulty` (runtime-global). Paramètres : `shared/faction/config.lua`.

| Niveau | Agressif | Grâce (min) | Délai entre attaques (min) | Part des forces | keep_mult | min_mult | size_mult | save_min |
|---|---|---|---|---|---|---|---|---|
| Paisible | non | — | — | 0 | 1 | 1 | 1 | 0 |
| Facile | oui | 45 | 15 | 0,20 | 1,5 | 0,6 | 0,6 | 0 |
| Normal (défaut) | oui | 30 | 8 | 0,40 | 1 | 1 | 1 | 3 |
| Difficile | oui | 18 | 5 | 0,65 | 0,5 | 0,9 | 1,4 | 5 |
| Impitoyable | oui | 10 | 3 | 0,90 | 0,25 | 0,8 | 1,5 | 7 |

Règles :
- La grâce est divisée par l'agressivité de la personnalité. Préavis : 2 min.
- Coalition contre un joueur leader : part = s + 0,25 × (1 - s).
- Le territoire du joueur compte 2 secteurs pour 1 avant-poste (valeur provisoire).
- Repérage : disque de rayon 24 secteurs (1 793 secteurs, 1 536 tuiles), 1 secteur toutes les 8 ticks ;
  le balayage complet prend 4 min.

Mesures :

| Banc | Facile | Normal | Difficile | Impitoyable |
|---|---|---|---|---|
| Moteur simulé (2 factions, 45 min) : 1re attaque | 30,0 min | 20,0 min | 12,0 min | 8,8 min |
| Moteur simulé : nombre d'attaques | 1 | 4 | 6 | 8 |
| Moteur simulé : taille moyenne | 11,0 | 18,0 | 18,7 | 19,4 |
| Moteur réel (4 factions, E33) | — | 1re à 20,0 min ; 3 attaques en 60 min ; 16 soldats | 1re à 12,0 min ; 6 attaques en 40 min ; 13 à 43 soldats | — |

**Défaut connu (lot IA0b)** : une base défendue n'est jamais attaquée. Il suffit de 3 tourelles en tech 0,
ou de 8 à 10 en tech 2. Cause : la règle « force ≥ 1,3 × défense », combinée au repli sur la faction rivale
après `save_min`.

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
`prototypes/levels.lua` (point d'entrée), `prototypes/levels/common.lua` (tout le non-visuel et la garde de
l'interface), `prototypes/levels/style.lua` (style commun par époque) et un fichier de visuel par famille ;
runtime : `script/levels/`.

> **Tous les tableaux chiffrés de cette section sont CALCULÉS sur la configuration** par
> `lua5.2 tests/levels_test.lua --tables | tr -d '\r'` (ne pas les retoucher à la main : changer la config,
> relancer ; `tr` retire les retours chariot que `print` ajoute sous Windows, le fichier est en LF).
>
> **État au 21/10 (lot V2, après correction)** : cadre posé et prouvé **hors jeu** seulement (règles,
> courbe, place dans le coffre, chantiers et migration en moteur simulé, garde de l'étape data, api_lint).
> **Non prouvé en moteur réel** : le banc `content` est réservé au lot P1 pendant ce lot (le diff de
> `content_test.lua` qui le prouvera est livré à l'intégrateur). Visuel : **provisoire** (le schéma rejeté en
> E25, sur 15 époques) ; aucun progrès visuel n'est revendiqué. Le modèle de durée de jeu repose sur des
> **hypothèses ❔** à valider en partie réelle.

**Règles**
- **15 époques = 15 niveaux du centre de commandement** (l'hôtel de ville, 4×4, un par force) : le niveau du
  centre EST l'époque. Les 6 autres familles (mitrailleuse, tourelle laser, mur, foreuse électrique, four en
  acier, machine d'assemblage 2) ont **30 niveaux**, 2 par époque : les niveaux 2e-1 et 2e appartiennent à
  l'époque e ; le 1er change la silhouette, le 2e ajoute une pièce (visuel : lots V3). Le niveau 1 est le
  bâtiment vanilla (ou le centre de base).
- **Plafond** : un bâtiment ne dépasse jamais **2 × niveau du centre** (0.3.0 : centre + 1) ; le niveau n
  exige donc un centre ⌈n/2⌉. Sans centre, rien ne s'améliore. Le panneau du centre affiche ce plafond
  (`L.building_cap`), et la description du centre l'énonce avec le nombre d'ouvriers.
- **Ouvriers** (chantiers simultanés) : 1 (centre 1-3), 2 (4-6), 3 (7-9), 4 (10-12), 5 (13-15). Les murs n'en
  occupent pas.
- **Paiement** : le stock du centre d'abord, puis l'inventaire du joueur (l'usine alimente le centre par
  convoyeurs : boucle « idle »). Stockage du centre : 48 cases + 16 par niveau (272 au niveau 15). Un joueur
  n'ouvre et n'améliore que les bâtiments de SA force (le centre payeur est celui de la force du bâtiment).
- **Place (correction V2)** : chaque chantier tient dans **la moitié du coffre du centre qui le paie**
  (centre : le centre lui-même au niveau n - 1 ; famille : le plus petit centre qui l'autorise, ⌈n/2⌉),
  calculé avec les vraies tailles de pile (`L.stack_size`, relevées sur l'étape data). Testé à chaque niveau ;
  le pire chantier est le centre 12 → 13 (84 cases sur 224, 38 %). Avant la correction, le combustible
  nucléaire (pile de 1) rendait le centre 14 → 15 **impayable** (366 cases pour un coffre de 256).
- **Chantier** : bâtiment hors service, barre de progression ; au terme, remplacement moteur « rapide »
  (contenu, recette, modules, munitions, fils conservés ; santé en proportion ; F39). Murs instantanés,
  rangée entière, tant que le stock suffit. Démonté en chantier : moitié du coût rendue (sauf un objet retiré
  du jeu depuis) ; détruit : perdu. Réglage de partie `fo-level-time-factor` (0 = instantané).

**Courbe de coûts et de durées PAR ÉPOQUE** (principe : « la croissance se fait par époque, nouveau
matériau requis, pas par exposant »)
- **Quelle monnaie** : une amélioration se paie avec le **matériau de l'époque pendant laquelle on la fait**.
  Familles : l'époque du niveau visé. Centre : passer au niveau n OUVRE l'époque n et se paie avec la monnaie
  de l'époque n - 1 (le centre est la porte de l'époque suivante).
- **Combien** : coût = panier de base de la famille + valeur d'époque.
  - Panier de base (époque 1 : fer, cuivre, pierre, engrenages, circuits) : **croissance linéaire**,
    × (1 + 0,15 (n - 2)) pour toutes les familles et le centre (× 5,2 au niveau 30, × 2,95 au centre 15).
    Correction V2 : les paniers des 5 familles à chantier sont réduits de 40 % (mitrailleuse : 6 fer,
    3 engrenages, 3 cuivre au niveau 2) et celui du centre porté à 260 fer, 130 cuivre, 130 briques,
    50 circuits (775 u), pour tenir la durée visée des époques 1 à 4 (modèle ci-dessous).
  - Valeur d'époque = `epoch_value` de la famille × `value_mult` de l'époque (table ci-dessous, réglable
    époque par époque), × 1,25 au 2e niveau d'une époque. Elle se paie à **60 % en matériau de l'époque** et
    40 % en matériau de l'époque précédente (murs : 100 % matériau de l'époque). **Exception de l'époque 2** :
    l'époque 1 n'a pas de matériau, l'acier paie 100 % (avant la correction, ces 40 % disparaissaient sans
    bruit). Le matériau de l'époque est toujours exigé, au moins 1 ; celui de l'époque précédente seulement
    si sa part vaut au moins un demi-objet.
  - Conversion valeur → quantité : valeur ÷ valeur unitaire de l'objet, arrondi lisible (entier sous 20,
    multiple de 5 sous 100, de 10 au-delà). Règle de monotonie : si l'arrondi rendait un niveau moins cher
    (en valeur) que le précédent, on ajoute du matériau de l'époque jusqu'à le dépasser (cas des murs).
  - Les quantités restent bornées (**au plus 1 840 objets d'une sorte** : moteurs électriques du centre 14,
    testé ≤ 2 000) parce que le matériau change à chaque époque : la valeur monte, le nombre d'objets non. La
    vraie contrainte est la **place** (règle ci-dessus). 1,5^28 ≈ 85 000 (ancienne courbe) n'apparaît plus.
  - La valeur, elle, croît de façon **géométrique** dans les faits (`value_mult` ≈ × 1,7 par époque à partir de
    l'époque 7), compensée par la production supposée (≈ × 1,46 par époque) et les durées (≈ × 1,2).
- **Durée** : `time0` de la famille × `time_mult` de l'époque (× 1,1 au 2e niveau) ; centre : 60 s ×
  `cc_time_mult` de l'époque qui le paie (1 min pour le niveau 2, 1 h pour le niveau 15). Durées strictement
  croissantes (testé). Correction V2 : `time_mult` réduit (× 18,5 à l'époque 15 au lieu de × 21, et surtout
  aux époques 2 à 6) pour que les ouvriers ne soient jamais occupés à plus de 62 % (testé ≤ 70 %) ; il saute
  aux époques 7, 10 et 13, quand un ouvrier s'ajoute.
- **Valeur unitaire** (unités de matière brute : 1 = une plaque de fer ; 10 unités de fluide = 1),
  approximations d'après les recettes vanilla : plaque de fer 1, de cuivre 1, brique 2, engrenage 2, circuit
  2,5, acier 5, moteur 9 (acier, engrenage, 2 tuyaux), plastique 3 (20 gaz + charbon → 2), tungstène 4
  (2 minerais durs), batterie 9 (fer, cuivre, 20 acide), cristal 3 (minerai de biome), baril de méthane 10
  (50 méthane + baril d'acier), uranium 238 14 (10 minerais + acide), processeur 75, structure légère 45,
  moteur électrique 16 (moteur 9 + 2 circuits + 15 lubrifiant = 15,5 ; 20 avant la correction), uranium 235
  45 (Kovarex : 3 uranium 238 par uranium 235, plus le temps), unité de contrôle de fusée 150, pack de science
  spatiale 250 (une fusée ≈ 245 000 pour 1 000 packs). Une seule valeur par objet : un objet du panier qui est
  aussi une monnaie (acier, batterie) prend celle de la table d'indirection (testé).

**Table d'indirection « matériau d'époque → objet »** (`L.epoch_materials`) : le jeu reste valide
AUJOURD'HUI (chaque objet de coût existe, vérifié hors jeu sur l'étape data et, au chargement, par le runtime
qui journalise `[FO-LEVELS]`). Les époques 11 à 15 utilisent des **remplaçants provisoires** existants ; le
lot X0 conçoit les matériaux voulus. Pour brancher un matériau livré, l'intégrateur change `item` et `value`
de la ligne de l'époque, ajoute sa pile à `L.stack_size`, et rien d'autre : toutes les quantités suivent.
**Contrainte transmise au lot X0** : un matériau d'époque s'empile par **50 au moins** (`L.MIN_MATERIAL_STACK`) ;
les remplaçants d'aujourd'hui à 10 (baril de méthane, structure légère, unité de contrôle de fusée) tiennent
la règle de place, testée. **Correction V2** : le remplaçant de l'époque 13 (hélium-3) n'est plus le
combustible nucléaire (pile de 1) mais l'**uranium 235** (pile de 100, même porte : l'enrichissement de
Kovarex). L'objet de l'époque 8 est le baril de méthane que le jeu de base génère pour chaque fluide (un objet
réel, pas un remplaçant). Le moteur (`engine-unit`) tient lieu de matériau « vapeur » : l'eau et la vapeur
sont des fluides, qu'on ne stocke pas dans un coffre.

**Modèle de durée de jeu** (OBJECTIFS F1-3 ❔ : époque 1 en ~30 min, époque 15 vers ~60 h cumulées). Il
relie la courbe aux heures de jeu sous des **hypothèses à valider** (`L.target`) :
- durée visée de l'époque e : 0,5 × 1,261^(e-1) h (somme des 15 époques : 60 h 10). C'est une ENTRÉE ;
- production de l'usine pendant l'époque e : de 2 u/s (fours à combustible) à 1 200 u/s (fin de partie, avec
  la Compaction ×4 du lot C), table `L.target.production` ;
- 30 % de la production consacrée aux niveaux ;
- base de référence : mitrailleuses 4 + 3 (e-1), tourelles laser à partir de l'époque 6 (4 + 4 (e-6)), murs
  20 + 30 (e-1), foreuses 6 + 8 (e-1), fours et machines d'assemblage à partir de l'époque 3 ; chaque bâtiment
  ajouté rattrape aussi les niveaux précédents.

La **durée impliquée** (correction V2) est le RÉSULTAT : le plus long de « payer la dépense de la base de
référence avec 30 % de la production » et « faire ses chantiers avec les ouvriers disponibles ». Avec la courbe
corrigée, chaque époque est entre **-2 % et +20 %** de sa cible (testé ± 25 %), l'époque 1 en **29 min**, le
total à **60 h 26** (testé 60 h ± 10 %), et les ouvriers occupés au plus à **62 %** (testé ≤ 70 %). Avant la
correction : époque 1 en 19 min, époques 3 et 4 à + 40 %, total 52 h, ouvriers saturés à l'époque 6.

Ce que ce chiffre n'est pas, en clair : **visée 60 h ; impliquée 60 h 26 avec des ouvriers jamais au repos
ou occupés à 75 %, 73 h s'ils ne travaillent que la moitié du temps ; 86 h si l'usine produit 30 % de moins,
46 h si elle produit 30 % de plus (tableau de sensibilité) ; non prouvé en partie réelle.** Il faut en outre
**relancer les chantiers à la main** : la base de référence en demande 567 à l'époque 6 (11 s en moyenne,
un toutes les 10 s), 963 à l'époque 9, 1 755 à l'époque 15 (un toutes les 26 s). Sans file de chantiers
(E3-4 ❌), la cible dépend du doigté du joueur : c'est l'inverse d'un jeu « presque idle », et seule la file
de chantiers le corrige (lot I, hors V2). Enfin, le **chemin « centre seul »** (monter le centre sans rien
d'autre) ne coûte que 0,9 % de la dépense de la base de référence (chiffre sous le tableau) : la cible de 60 h
ne tient que si le joueur améliore toute sa base, et rien ne l'y oblige (question ouverte pour le Directeur
Créatif : faut-il une condition façon Clash of Clans, par exemple des bâtiments au niveau 2e exigés avant le
centre e + 1 ?).

**Statistiques** (niveau 1 = valeur vanilla × facteur ; tableaux complets plus bas)
- mêmes formules qu'en 0.3.0, prolongées jusqu'au niveau 30 : PV × (1 + 0,15 (n-1)), portée + 0,25 / niveau,
  rotation + 5 % / niveau, minage + 10 % / niveau (énergie + 7 %), vitesse des fours et machines + 8 % /
  niveau (énergie + 6 %) ; centre : PV × (1 + 0,2 (n-1)), + 16 cases / niveau ;
- **dégâts des tourelles dégressifs (correction V2)** : + 8 % par niveau jusqu'au niveau 10 (0.3.0, inchangé),
  puis + 2 % par niveau : × 2,12 au niveau 30 (au lieu de × 3,32). En DPS (dégâts × cadence), la mitrailleuse
  30 vaut 0,94 fois la tourelle lourde du mod (2,12 contre 2,25 : dégâts 1,5 × cadence 1,5) et la tourelle
  laser 30 1,06 fois la tourelle laser lourde (4,24 contre 4) ; testé : entre 0,8 et 1,1 fois la version
  lourde. Avant la correction, la mitrailleuse 30 faisait 1,48 fois la lourde et l'égalait dès le niveau 17 ;
  le laser la dépassait dès le niveau 14. Elles gardent plus de PV et de portée que les lourdes, sur une
  emprise plus petite : **c'est un choix assumé à confirmer par le Directeur Créatif** (option B du
  vérificateur : donner des niveaux aux tourelles lourdes, ou les retirer) ;
- **énergie de la tourelle laser (correction V2)** : l'énergie par tir et le tampon croissent de 4 % par
  niveau (800 → 1 728 kJ au niveau 30, la lourde : 2 000 kJ) ; les dégâts par joule du niveau 30 restent à
  ± 10 % du niveau 1 (testé), et le tampon contient toujours un tir (testé). Avant, l'énergie ne bougeait
  pas : dégâts par joule × 4,15 par rapport à la lourde ;
- **murs rééquilibrés** : 0.3.0 donnait PV × 1,3^(n-1), soit × 2 000 au niveau 30 (≈ 700 000 PV) ; c'est
  désormais × (1 + 0,5 (n-1)), 350 → 5 425 PV, et la réduction fixe physique et explosion passe de + 1 à
  + 0,5 par niveau (physique 3 → 17,5 au niveau 30, comparable au mur blindé du mod) ;
- **foreuse, four, machine** : l'énergie croît moins vite que la vitesse (foreuse 30 : énergie × 3,03 pour un
  minage × 3,90 ; four et machine 30 : énergie × 2,74 pour une vitesse × 3,32). Repère utile (tableau) : une
  foreuse 30 avec 3 modules de vitesse du palier 10 du mod tire 16 minerais/s, plus qu'un tapis jaune ;
- toutes les statistiques sont strictement croissantes et au plus × 16 entre le niveau 1 et le dernier
  (testé).

**Compatibilité des sauvegardes 0.3.0** (prouvée en moteur simulé seulement, `tests/migration_test.lua`)
- Les noms `fo-command-center` et `fo-lvl-<famille>-<n>` (n ≤ 10) gardent leur sens : même famille, même
  niveau. L'état `global.fo.levels` garde sa forme : aucune donnée à convertir. Au changement de version, une
  réparation défensive retire les chantiers dont le bâtiment a disparu, remet en service un bâtiment dont la
  cible n'existerait plus, retire d'un coût enregistré un objet disparu du jeu, recompte les ouvriers, et
  **ramène au nouveau maximum les PV d'un bâtiment qui le dépasse** (`Levels.clamp_health` : murs 0.3.0).
- Un chantier 0.3.0 en cours se termine normalement. Un bâtiment au niveau 10 (l'ancien maximum) peut
  monter au 11 si le centre est au niveau 6 ou plus. Les statistiques des niveaux 1 à 10 sont celles de
  0.3.0, **sauf les PV et résistances des murs** (un mur niveau 10 passe de 3 712 à 1 925 PV, réduction
  physique de 12 à 7,5) : **rupture à faire acter par le Directeur Créatif** ; le comportement du moteur réel
  au chargement d'une vraie sauvegarde 0.3.0 n'est pas prouvé.
- Les coûts et durées changent pour tous les niveaux : le niveau 2 coûte environ 30 % de 0.3.0
  (mitrailleuse : 6 fer, 3 engrenages, 3 cuivre au lieu de 20, 10, 10) ; les ressources des biomes restent
  des monnaies, mais à leur époque (tungstène aux niveaux 9-10, cristal aux niveaux 13-14) et non plus comme
  supplément des niveaux 7 et 9.

**Design par niveau : PROVISOIRE, REJETÉ** (E25 : « je ne vois QUE un changement de couleur/teinte »). Le
lot V2 ne revendique aucun progrès visuel. Ce qui existe : teinte de l'époque (palette du **style commun**
`prototypes/levels/style.lua`, Q10, à confier à un seul propriétaire), léger reflet au 2e niveau d'une époque,
lueur à partir de l'époque 5, halo de nuit à partir de l'époque 6, socle de tuiles, et une échelle
**plafonnée à + 10 %** au dernier niveau (0.3.0 : + 1,2 % par niveau, qui aurait donné + 35 % au niveau 30).
Le centre garde ses antennes (époques 4 et 7). La cible reste OBJECTIFS.md D1 : chaque famille reçoit son
visuel par époque dans `prototypes/levels/<famille>.lua` (lots V3), à travers l'interface documentée en tête
de `common.lua`. **Garde de l'interface (correction V2, complétée au lot V2b)** : elle capture TOUT le
prototype sauf une liste blanche graphique (une clé de jeu oubliée est protégée par défaut), vérifie la durée
des animations de déploiement des tourelles et rend `ctx` en lecture seule. Depuis V2b, elle compare par
copie profonde puis comparaison de contenu : la config `L` EN ENTIER (toutes ses clés, fonctions comprises,
quel que soit le chemin : `ctx.L`, `require`, table rendue par `L.parse`), `ctx.kit` et le style commun après
chaque `dress` et après chaque `icons` (le refus nomme la fonction et le niveau fautifs) ; `data.raw` après
chaque famille (types surveillés, types des sources, types référencés par les sources) puis en entier après la
dernière ; le prototype de chaque niveau de nouveau après `icons`, en fin de famille et après la DERNIÈRE
famille (une famille suivante ne peut plus changer une famille fermée). Chaque refus nomme le fichier, le
niveau et le chemin exact. Voie officielle pour un visuel propre (faisceau, reste, explosion) : `ctx.declare` ;
la copie déclarée est comparée à sa source après `edit`, puis de nouveau après le `dress` et l'`icons` du
niveau, en fin de famille et après la dernière famille. Le fichier de famille est chargé À L'INTÉRIEUR de la
garde de sa famille (son code de premier niveau est gardé comme `dress`) et `generate` appelle ses fonctions de
garde par des locales (remplacer `Common.dress` depuis un fichier de famille n'a plus d'effet). Limites
écrites en tête de `common.lua` : la garde arrête les erreurs, pas un contournement délibéré (bibliothèque
`debug`, fonction globale remplacée, métatable posée sur `L`, écart restauré avant la comparaison).
Tests hors jeu (`levels_test`) : 81 cas d'agent V3 (15 acceptés, 66 refusés, motif vérifié pour chaque refus,
dont 12 cas de la contre-vérification : copie déclarée modifiée après `edit` (jeu, nom, nom affiché), `icons`
fautif, famille suivante) et 42 sondes, une par clé de `L`, toutes refusées avec leur chemin ; 4 mutants de la garde
(revérifications retirées une à une) sont tous détectés (1 à 6 échecs chacun). Sondes dans l'étape data
réelle (harness, copies hors dépôt, 21/10 vers 23 h) : 35 sondes, 31 refusées avec fichier, niveau et chemin
(dont p17 copie déclarée gardée, p20 `icons` du niveau 9, p22 `Common.dress` remplacé, p23 famille suivante,
code de premier niveau du fichier) ; 4 acceptées : un faisceau déclaré (749 prototypes, `fo-lvl-laser-9`
tire `fo-lvl-laser-9-beam`, dégâts de la source), un reste et une explosion déclarés (750 prototypes), et les
deux limites écrites (métatable sur `L`, `L.rebuild()` puis restauration), 0 erreur, 0 clé de traduction
manquante.

**Coût de la garde sur l'étape data** (harness complet ; temps ÉCOULÉ de `generate` : `os.clock` de ce
`lua5.2` (msvcrt) mesure l'horloge murale, 2,047 s affichées pendant un sommeil de 2 s, donc sensible à la
charge. 5 tours entrelacés le 21/10 vers 23 h, processus épinglé sur les cœurs P (masque FFF, F30), priorité
au-dessus de la normale, ramasse-miettes normal ; PC partagé avec d'autres agents. Coût de la garde : écart au
« sans garde » du même tour)

| Variante | `generate`, temps écoulé | Coût de la garde |
|---|---|---|
| Sans garde (garde contournée) | 0,116 à 0,173 s (médiane 0,130) | — |
| Garde V2 (`4240248`, chaînes sérialisées après chaque `dress`) | 1,58 à 2,11 s (médiane 1,64) | 1,44 à 1,99 s (médiane 1,52) |
| Garde V2b (`3c78a6a`, copie unique de data.raw, comparaisons par famille) | 0,65 à 0,98 s (médiane 0,75) | 0,51 à 0,81 s (médiane 0,64) |
| Garde V2b corrigée (contre-vérification : icons, familles, copies déclarées) | 0,70 à 0,90 s (médiane 0,88) | 0,56 à 0,78 s (médiane 0,71) |

Synthèse : la garde coûte de **0,56 à 0,78 s** de temps écoulé (médiane 0,71 s), **- 53 %** en médiane face à la
garde V2. La contre-vérification de V2b, avec son propre chronomètre (collecte complète comprise), trouvait
0,61 à 0,86 s (médiane 0,77 s) pour V2b et 1,52 à 2,43 s (médiane 1,62 s) pour V2, soit - 52 % : l'annonce
précédente (« ≈ 0,6 s, - 62 % », « temps processeur ») était optimiste et mal nommée. Les fourchettes de V2b et
de V2b corrigée se recouvrent : l'écart des médianes (+ 0,07 s) est dans le bruit. La décomposition (garde
instrumentée, 3 passes, temps écoulés) chiffre l'ajout de la correction à **0,03 à 0,06 s** : état partagé
après chaque `icons` 0,02 à 0,04 s, revérification de toutes les familles 0,011 à 0,017 s, chargement des
fichiers 0,002 s au plus. Le reste : copie de data.raw 0,11 à 0,18 s ; comparaisons de data.raw par famille
0,24 à 0,39 s ; tout data.raw (passe finale) 0,09 à 0,13 s ; état partagé après `dress` 0,02 à 0,03 s ;
prototypes des niveaux (après `dress`, `icons` et en fin de famille) 0,04 à 0,06 s ; instantanés de jeu 0,01 à
0,02 s ; types surveillés et référencés 0,01 s.

**Mémoire** (ramasse-miettes arrêté pendant `generate`, une passe par variante) : `generate` alloue 27,1 Mo
sans garde, 89,0 Mo avec la garde V2b (**+ 61,9 Mo passagers**), 92,9 Mo avec la garde corrigée (+ 65,8 Mo),
249,0 Mo avec la garde V2 (+ 221,9 Mo). Après collecte, 17,2 Mo restent dans les 4 cas (les prototypes
générés) : la garde ne retient rien. Le chiffre précédent (26,6 Mo) ne comptait que la copie de data.raw.
**Déterminisme** : data.raw sérialisé trié après `generate` (23,3 Mo) a la même empreinte sha256 sans garde,
avec V2b et avec la garde corrigée : la garde ne change aucun prototype. Non mesuré : le temps de chargement
en moteur réel.

**Défauts connus**
- Les recherches de dégâts des tourelles listent, dans leur infobulle, 29 lignes de plus par tourelle (une par
  niveau : héritage F21 par effets de technologie ; `physical-projectile-damage-1` affiche 31 effets
  `turret-attack`, 11 en 0.3.0). Fonctionnel, mais chargé ; l'API 1.1.91 n'a pas de champ pour masquer un
  effet. Accepté.
- Au changement d'époque, la monnaie de l'époque précédente passe de 60 % × 1,25 à 40 % de la valeur d'époque :
  sa quantité baisse d'un niveau au suivant dès que `value_mult[e] / value_mult[e-1]` < 1,875, soit **49 cas**
  (compté par `levels_test` : par exemple mitrailleuse niveau 27, uranium 235 100 → 85). La valeur totale,
  elle, croît toujours (testé).
- Les remplaçants des époques 13 (uranium 235 : enrichissement de Kovarex) et 15 (pack de science spatiale :
  une fusée lancée) sont des portes technologiques à confirmer en partie réelle.
- Relance manuelle des chantiers (un toutes les 10 à 26 s dans la base de référence) : voir le modèle ; il
  manque la file de chantiers (E3-4).
- Coût script des niveaux non mesuré au banc épinglé (H-L1) ; mesuré en moteur simulé seulement (vérification
  adverse du lot V2 : 0,5 µs par tick pour 5 chantiers, 28 µs par tick pour 295).

#### Les 15 époques et la table d'indirection des matériaux

| Époque | Thème | Matériau voulu | Objet en jeu aujourd'hui | Valeur unitaire (u) | Pile | Valeur d'époque (× époque 2) | Chantiers des bâtiments (× époque 1) | Chantier du centre payé dans l'époque (× 1 min) | Centre (niveau) | Niveaux des bâtiments | Ouvriers |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Pionnier | fer, cuivre, pierre (panier de base) | panier de base | — | — | 0 | 1 | 1 | 1 | 1-2 | 1 |
| 2 | Forge | acier | `steel-plate` | 5 | 100 | 1 | 1,25 | 2 | 2 | 3-4 | 1 |
| 3 | Vapeur | moteur (mécanique de l'ère vapeur) | `engine-unit` | 9 | 50 | 1,1 | 1,4 | 3 | 3 | 5-6 | 1 |
| 4 | Pétrole | plastique | `plastic-bar` | 3 | 100 | 1,25 | 1,55 | 5 | 4 | 7-8 | 2 |
| 5 | Volcan | plaque de tungstène | `fo-tungsten-plate` | 4 | 100 | 5 | 1,75 | 8 | 5 | 9-10 | 2 |
| 6 | Électricité | batterie | `battery` | 9 | 200 | 9,1 | 1,95 | 12 | 6 | 11-12 | 2 |
| 7 | Cristal | cristal de résonance | `fo-resonance-crystal` | 3 | 50 | 18,5 | 3,2 | 16 | 7 | 13-14 | 3 |
| 8 | Marais | méthane (baril) | `fo-methane-barrel` | 10 | 10 | 32 | 3,6 | 20 | 8 | 15-16 | 3 |
| 9 | Atome | uranium | `uranium-238` | 14 | 100 | 54 | 4,1 | 25 | 9 | 17-18 | 3 |
| 10 | Haute technologie | processeur | `processing-unit` | 75 | 100 | 93,5 | 6,8 | 30 | 10 | 19-20 | 4 |
| 11 | Titane | plaque de titane | `low-density-structure` **provisoire** (voulu : `fo-titanium-plate`) | 45 | 10 | 160 | 7,6 | 36 | 11 | 21-22 | 4 |
| 12 | Supraconducteurs | supraconducteur (terres rares) | `electric-engine-unit` **provisoire** (voulu : `fo-superconductor`) | 16 | 50 | 275 | 8,6 | 42 | 12 | 23-24 | 4 |
| 13 | Fusion | hélium-3 | `uranium-235` **provisoire** (voulu : `fo-helium-3`) | 45 | 100 | 490 | 13 | 50 | 13 | 25-26 | 5 |
| 14 | Orbite | fragment de météorite | `rocket-control-unit` **provisoire** (voulu : `fo-meteorite`) | 150 | 10 | 810 | 15,5 | 60 | 14 | 27-28 | 5 |
| 15 | Légende | matière exotique | `space-science-pack` **provisoire** (voulu : `fo-exotic-matter`) | 250 | 2 000 | 1 460 | 18,5 | — | 15 | 29-30 | 5 |

#### Repères : niveau 1, niveau 10 (maximum de 0.3.0), dernier niveau, comparés au vanilla et au contenu du mod

| Famille | Statistique | Niveau 1 | Niveau 10 | Dernier niveau | Repère |
|---|---|---|---|---|---|
| Centre de commandement | max_health | 3 000 | 8 400 | 11 400 (niveau 15) | — |
| Centre de commandement | inventory_size | 48 | 192 | 272 (niveau 15) | coffre en acier : 48 cases |
| Mitrailleuse | max_health | 400 | 940 | 2 140 (niveau 30) | tourelle lourde (mod) : 2 000 |
| Mitrailleuse | damage_modifier | 1 | 1,72 | 2,12 (niveau 30) | tourelle lourde (mod) : 1,5 |
| Mitrailleuse | dps | 1 | 1,72 | 2,12 (niveau 30) | tourelle lourde (mod) : 2,25 (dégâts 1,5 × cadence 1,5) |
| Mitrailleuse | range | 18 | 20,25 | 25,25 (niveau 30) | tourelle lourde (mod) : 24 ; ver géant : 48 |
| Tourelle laser | max_health | 1 000 | 2 350 | 5 350 (niveau 30) | tourelle laser lourde (mod) : 3 000 |
| Tourelle laser | damage_modifier | 2 | 3,44 | 4,24 (niveau 30) | tourelle laser lourde (mod) : 4 |
| Tourelle laser | dps | 1 | 1,72 | 2,12 (niveau 30) | tourelle laser lourde (mod) : 2 (même cadence) |
| Tourelle laser | energy_consumption | 800 | 1 088 | 1 728 (niveau 30) | tourelle laser lourde (mod) : 2 000 kJ |
| Tourelle laser | range | 24 | 26,25 | 31,25 (niveau 30) | tourelle laser lourde (mod) : 32 |
| Mur | max_health | 350 | 1 925 | 5 425 (niveau 30) | mur renforcé : 1 200 ; mur blindé : 3 500 |
| Mur | physical | 3 | 7,5 | 17,5 (niveau 30) | mur blindé : 3 + 15 = 18 (et 50 %) |
| Foreuse électrique | mining_speed | 0,5 | 0,95 | 1,95 (niveau 30) | vanilla + 3 modules de vitesse 3 : 1,25 minerai/s ; niveau 30 + 3 modules de vitesse palier 10 : 15,99 minerai/s (tapis jaune : 15/s) |
| Four en acier | crafting_speed | 2 | 3,44 | 6,64 (niveau 30) | four électrique vanilla : 2, avec 2 emplacements de module (le four en acier n'en a aucun) |
| Machine d'assemblage 2 | crafting_speed | 0,75 | 1,29 | 2,49 (niveau 30) | machine d'assemblage 3 vanilla : 1,25, avec 4 emplacements (la machine 2 en a 2) |

#### Modèle de durée de jeu (hypothèses de `L.target`, à valider en partie réelle)

| Époque | Durée visée | Cumul visé | Production (u/s) | Budget niveaux (u) | Dépense de la base de référence (u) | Dépense / budget | Temps d'ouvriers | Capacité des ouvriers | Charge des ouvriers | Durée impliquée | Cumul impliqué | Chantier du centre suivant |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 30 min | 30 min | 2 | 1 080 | 1 057 | 0,98 | 2 min 15 s | 30 min | 0,07 | 29 min 22 s | 29 min 22 s | 775 u, 1 min |
| 2 | 37 min 50 s | 1 h 07 | 5 | 3 405 | 3 817 | 1,12 | 9 min 27 s | 37 min 50 s | 0,25 | 42 min 24 s | 1 h 11 | 1 038 u, 2 min |
| 3 | 47 min 42 s | 1 h 55 | 10 | 8 587 | 10 340 | 1,2 | 25 min 11 s | 47 min 42 s | 0,53 | 57 min 27 s | 2 h 09 | 1 177 u, 3 min |
| 4 | 1 h 00 | 2 h 55 | 17 | 18 407 | 19 714 | 1,07 | 48 min 31 s | 2 h 00 | 0,4 | 1 h 04 | 3 h 13 | 1 330 u, 5 min |
| 5 | 1 h 15 | 4 h 11 | 27 | 36 865 | 36 976 | 1 | 1 h 14 | 2 h 31 | 0,49 | 1 h 16 | 4 h 29 | 1 990 u, 8 min |
| 6 | 1 h 35 | 5 h 47 | 40 | 68 870 | 69 617 | 1,01 | 1 h 59 | 3 h 11 | 0,62 | 1 h 36 | 6 h 06 | 2 745 u, 12 min |
| 7 | 2 h 00 | 7 h 47 | 60 | 130 267 | 131 010 | 1,01 | 3 h 19 | 6 h 01 | 0,55 | 2 h 01 | 8 h 07 | 4 238 u, 16 min |
| 8 | 2 h 32 | 10 h 19 | 88 | 240 925 | 238 756 | 0,99 | 4 h 31 | 7 h 36 | 0,59 | 2 h 30 | 10 h 38 | 6 410 u, 20 min |
| 9 | 3 h 11 | 13 h 31 | 125 | 431 543 | 431 143 | 1 | 5 h 57 | 9 h 35 | 0,62 | 3 h 11 | 13 h 50 | 9 815 u, 25 min |
| 10 | 4 h 01 | 17 h 33 | 180 | 783 614 | 775 762 | 0,99 | 9 h 48 | 16 h 07 | 0,61 | 3 h 59 | 17 h 49 | 15 690 u, 30 min |
| 11 | 5 h 04 | 22 h 38 | 260 | 1 427 309 | 1 424 411 | 1 | 12 h 33 | 20 h 19 | 0,62 | 5 h 04 | 22 h 53 | 26 115 u, 36 min |
| 12 | 6 h 24 | 29 h 03 | 380 | 2 630 530 | 2 608 030 | 0,99 | 15 h 52 | 25 h 38 | 0,62 | 6 h 21 | 29 h 15 | 43 485 u, 42 min |
| 13 | 8 h 04 | 37 h 08 | 560 | 4 888 356 | 4 892 828 | 1 | 24 h 19 | 40 h 24 | 0,6 | 8 h 05 | 37 h 20 | 75 700 u, 50 min |
| 14 | 10 h 11 | 47 h 19 | 820 | 9 026 175 | 9 049 029 | 1 | 31 h 37 | 50 h 57 | 0,62 | 10 h 13 | 47 h 33 | 124 385 u, 1 h 00 |
| 15 | 12 h 51 | 60 h 10 | 1 200 | 16 656 595 | 16 703 062 | 1 | 39 h 32 | 64 h 15 | 0,62 | 12 h 53 | 60 h 26 | — |

#### Sensibilité de la durée impliquée totale (15 époques)

| Production supposée | Ouvriers jamais au repos | Ouvriers occupés à 75 % | Ouvriers occupés à 50 % |
|---|---|---|---|
| × 0,7 | 86 h 21 | 86 h 21 | 86 h 21 |
| × 1 | 60 h 26 | 60 h 26 | 73 h 00 |
| × 1,3 | 46 h 29 | 49 h 12 | 72 h 20 |

Chemin « centre seul » (centre 1 → 15, rien d'autre) : 314 891 u et 5 h 10 de chantiers, soit 0,9 % de la dépense de la base de référence.

#### Centre de commandement (15 niveaux)

| Niveau | Époque | PV | cases | Coût du passage à ce niveau | Valeur (u) | Durée | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier | 3 000 | 48 | — | — | — | — |
| 2 | 2 Forge | 3 600 | 64 | 260 iron-plate, 130 copper-plate, 130 stone-brick, 50 electronic-circuit | 775 | 1 min | 8 / 48 |
| 3 | 3 Vapeur | 4 200 | 80 | 300 iron-plate, 150 copper-plate, 150 stone-brick, 55 electronic-circuit, 30 steel-plate | 1 038 | 2 min | 9 / 64 |
| 4 | 4 Pétrole | 4 800 | 96 | 340 iron-plate, 170 copper-plate, 170 stone-brick, 65 electronic-circuit, 11 engine-unit, 13 steel-plate | 1 177 | 3 min | 11 / 80 |
| 5 | 5 Volcan | 5 400 | 112 | 380 iron-plate, 190 copper-plate, 190 stone-brick, 75 electronic-circuit, 40 plastic-bar, 8 engine-unit | 1 330 | 5 min | 11 / 96 |
| 6 | 6 Électricité | 6 000 | 128 | 420 iron-plate, 210 copper-plate, 210 stone-brick, 80 electronic-circuit, 110 fo-tungsten-plate, 100 plastic-bar | 1 990 | 8 min | 15 / 112 |
| 7 | 7 Cristal | 6 600 | 144 | 460 iron-plate, 230 copper-plate, 230 stone-brick, 90 electronic-circuit, 90 battery, 140 fo-tungsten-plate | 2 745 | 12 min | 15 / 128 |
| 8 | 8 Marais | 7 200 | 160 | 490 iron-plate, 250 copper-plate, 250 stone-brick, 95 electronic-circuit, 560 fo-resonance-crystal, 120 battery | 4 238 | 16 min | 25 / 144 |
| 9 | 9 Atome | 7 800 | 176 | 530 iron-plate, 270 copper-plate, 270 stone-brick, 100 electronic-circuit, 290 fo-methane-barrel, 640 fo-resonance-crystal | 6 410 | 20 min | 55 / 160 |
| 10 | 10 Haute technologie | 8 400 | 192 | 570 iron-plate, 290 copper-plate, 290 stone-brick, 110 electronic-circuit, 350 uranium-238, 320 fo-methane-barrel | 9 815 | 25 min | 49 / 176 |
| 11 | 11 Titane | 9 000 | 208 | 610 iron-plate, 310 copper-plate, 310 stone-brick, 120 electronic-circuit, 110 processing-unit, 400 uranium-238 | 15 690 | 30 min | 22 / 192 |
| 12 | 12 Supraconducteurs | 9 600 | 224 | 650 iron-plate, 330 copper-plate, 330 stone-brick, 130 electronic-circuit, 320 low-density-structure, 130 processing-unit | 26 115 | 36 min | 50 / 208 |
| 13 | 13 Fusion | 10 200 | 240 | 690 iron-plate, 340 copper-plate, 340 stone-brick, 130 electronic-circuit, 1 550 electric-engine-unit, 370 low-density-structure | 43 485 | 42 min | 84 / 224 |
| 14 | 14 Orbite | 10 800 | 256 | 730 iron-plate, 360 copper-plate, 360 stone-brick, 140 electronic-circuit, 980 uranium-235, 1 840 electric-engine-unit | 75 700 | 50 min | 64 / 240 |
| 15 | 15 Légende | 11 400 | 272 | 770 iron-plate, 380 copper-plate, 380 stone-brick, 150 electronic-circuit, 490 rocket-control-unit, 1 080 uranium-235 | 124 385 | 1 h 00 | 77 / 256 |

#### Mitrailleuse (30 niveaux)

| Niveau | Époque | PV | dégâts × | portée | Coût du passage à ce niveau | Valeur (u) | Durée | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 400 | 1 | 18 | — | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 460 | 1,08 | 18,25 | 6 iron-plate, 3 iron-gear-wheel, 3 copper-plate | 15 | 9 s | 3 / 48 |
| 3 | 2 Forge (silhouette) | 520 | 1,16 | 18,5 | 7 iron-plate, 3 iron-gear-wheel, 3 copper-plate, 2 steel-plate | 26 | 10 s | 4 / 64 |
| 4 | 2 Forge (+ pièce) | 580 | 1,24 | 18,75 | 8 iron-plate, 4 iron-gear-wheel, 4 copper-plate, 3 steel-plate | 35 | 11 s | 4 / 64 |
| 5 | 3 Vapeur (silhouette) | 640 | 1,32 | 19 | 9 iron-plate, 4 iron-gear-wheel, 4 copper-plate, 2 engine-unit, 1 steel-plate | 44 | 11 s | 5 / 80 |
| 6 | 3 Vapeur (+ pièce) | 700 | 1,4 | 19,25 | 10 iron-plate, 5 iron-gear-wheel, 5 copper-plate, 2 engine-unit, 1 steel-plate | 48 | 12 s | 5 / 80 |
| 7 | 4 Pétrole (silhouette) | 760 | 1,48 | 19,5 | 11 iron-plate, 5 iron-gear-wheel, 5 copper-plate, 5 plastic-bar, 1 engine-unit | 50 | 12 s | 5 / 96 |
| 8 | 4 Pétrole (+ pièce) | 820 | 1,56 | 19,75 | 11 iron-plate, 6 iron-gear-wheel, 6 copper-plate, 5 plastic-bar, 1 engine-unit | 53 | 14 s | 5 / 96 |
| 9 | 5 Volcan (silhouette) | 880 | 1,64 | 20 | 12 iron-plate, 6 iron-gear-wheel, 6 copper-plate, 9 fo-tungsten-plate, 8 plastic-bar | 90 | 14 s | 5 / 112 |
| 10 | 5 Volcan (+ pièce) | 940 | 1,72 | 20,25 | 13 iron-plate, 7 iron-gear-wheel, 7 copper-plate, 11 fo-tungsten-plate, 10 plastic-bar | 108 | 15 s | 5 / 112 |
| 11 | 6 Électricité (silhouette) | 1 000 | 1,74 | 20,5 | 14 iron-plate, 7 iron-gear-wheel, 7 copper-plate, 7 battery, 11 fo-tungsten-plate | 142 | 16 s | 5 / 128 |
| 12 | 6 Électricité (+ pièce) | 1 060 | 1,76 | 20,75 | 15 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 9 battery, 14 fo-tungsten-plate | 176 | 17 s | 5 / 128 |
| 13 | 7 Cristal (silhouette) | 1 120 | 1,78 | 21 | 16 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 45 fo-resonance-crystal, 10 battery | 265 | 26 s | 5 / 144 |
| 14 | 7 Cristal (+ pièce) | 1 180 | 1,8 | 21,25 | 17 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 55 fo-resonance-crystal, 12 battery | 314 | 28 s | 6 / 144 |
| 15 | 8 Marais (silhouette) | 1 240 | 1,82 | 21,5 | 18 iron-plate, 9 iron-gear-wheel, 9 copper-plate, 25 fo-methane-barrel, 50 fo-resonance-crystal | 445 | 29 s | 7 / 160 |
| 16 | 8 Marais (+ pièce) | 1 300 | 1,84 | 21,75 | 19 iron-plate, 9 iron-gear-wheel, 9 copper-plate, 30 fo-methane-barrel, 65 fo-resonance-crystal | 541 | 32 s | 8 / 160 |
| 17 | 9 Atome (silhouette) | 1 360 | 1,86 | 22 | 20 iron-plate, 10 iron-gear-wheel, 10 copper-plate, 30 uranium-238, 25 fo-methane-barrel | 720 | 33 s | 7 / 176 |
| 18 | 9 Atome (+ pièce) | 1 420 | 1,88 | 22,25 | 20 iron-plate, 10 iron-gear-wheel, 10 copper-plate, 35 uranium-238, 30 fo-methane-barrel | 840 | 36 s | 7 / 176 |
| 19 | 10 Haute technologie (silhouette) | 1 480 | 1,9 | 22,5 | 20 iron-plate, 11 iron-gear-wheel, 11 copper-plate, 9 processing-unit, 30 uranium-238 | 1 148 | 54 s | 5 / 192 |
| 20 | 10 Haute technologie (+ pièce) | 1 540 | 1,92 | 22,75 | 20 iron-plate, 11 iron-gear-wheel, 11 copper-plate, 11 processing-unit, 40 uranium-238 | 1 438 | 1 min | 5 / 192 |
| 21 | 11 Titane (silhouette) | 1 600 | 1,94 | 23 | 25 iron-plate, 12 iron-gear-wheel, 12 copper-plate, 25 low-density-structure, 10 processing-unit | 1 936 | 1 min 01 s | 7 / 208 |
| 22 | 11 Titane (+ pièce) | 1 660 | 1,96 | 23,25 | 25 iron-plate, 12 iron-gear-wheel, 12 copper-plate, 30 low-density-structure, 13 processing-unit | 2 386 | 1 min 07 s | 7 / 208 |
| 23 | 12 Supraconducteurs (silhouette) | 1 720 | 1,98 | 23,5 | 25 iron-plate, 12 iron-gear-wheel, 12 copper-plate, 120 electric-engine-unit, 30 low-density-structure | 3 331 | 1 min 09 s | 9 / 224 |
| 24 | 12 Supraconducteurs (+ pièce) | 1 780 | 2 | 23,75 | 25 iron-plate, 13 iron-gear-wheel, 13 copper-plate, 150 electric-engine-unit, 35 low-density-structure | 4 039 | 1 min 16 s | 10 / 224 |
| 25 | 13 Fusion (silhouette) | 1 840 | 2,02 | 24 | 25 iron-plate, 13 iron-gear-wheel, 13 copper-plate, 80 uranium-235, 150 electric-engine-unit | 6 064 | 1 min 44 s | 7 / 240 |
| 26 | 13 Fusion (+ pièce) | 1 900 | 2,04 | 24,25 | 30 iron-plate, 14 iron-gear-wheel, 14 copper-plate, 100 uranium-235, 180 electric-engine-unit | 7 452 | 1 min 54 s | 8 / 240 |
| 27 | 14 Orbite (silhouette) | 1 960 | 2,06 | 24,5 | 30 iron-plate, 14 iron-gear-wheel, 14 copper-plate, 40 rocket-control-unit, 85 uranium-235 | 9 897 | 2 min 04 s | 8 / 256 |
| 28 | 14 Orbite (+ pièce) | 2 020 | 2,08 | 24,75 | 30 iron-plate, 15 iron-gear-wheel, 15 copper-plate, 50 rocket-control-unit, 110 uranium-235 | 12 525 | 2 min 16 s | 10 / 256 |
| 29 | 15 Légende (silhouette) | 2 080 | 2,1 | 25 | 30 iron-plate, 15 iron-gear-wheel, 15 copper-plate, 40 space-science-pack, 45 rocket-control-unit | 16 825 | 2 min 28 s | 9 / 272 |
| 30 | 15 Légende (+ pièce) | 2 140 | 2,12 | 25,25 | 30 iron-plate, 16 iron-gear-wheel, 16 copper-plate, 55 space-science-pack, 60 rocket-control-unit | 22 828 | 2 min 43 s | 10 / 272 |

#### Tourelle laser (30 niveaux)

| Niveau | Époque | PV | dégâts × | portée | Coût du passage à ce niveau | Valeur (u) | Durée | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 1 000 | 2 | 24 | — | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 1 150 | 2,16 | 24,25 | 3 steel-plate, 3 electronic-circuit, 2 battery | 41 | 13 s | 3 / 48 |
| 3 | 2 Forge (silhouette) | 1 300 | 2,32 | 24,5 | 7 steel-plate, 3 electronic-circuit, 2 battery | 61 | 15 s | 3 / 64 |
| 4 | 2 Forge (+ pièce) | 1 450 | 2,48 | 24,75 | 9 steel-plate, 4 electronic-circuit, 3 battery | 82 | 17 s | 3 / 64 |
| 5 | 3 Vapeur (silhouette) | 1 600 | 2,64 | 25 | 6 steel-plate, 4 electronic-circuit, 3 battery, 2 engine-unit | 85 | 17 s | 4 / 80 |
| 6 | 3 Vapeur (+ pièce) | 1 750 | 2,8 | 25,25 | 7 steel-plate, 5 electronic-circuit, 3 battery, 2 engine-unit | 93 | 18 s | 4 / 80 |
| 7 | 4 Pétrole (silhouette) | 1 900 | 2,96 | 25,5 | 5 steel-plate, 5 electronic-circuit, 4 battery, 5 plastic-bar, 1 engine-unit | 98 | 19 s | 5 / 96 |
| 8 | 4 Pétrole (+ pièce) | 2 050 | 3,12 | 25,75 | 6 steel-plate, 6 electronic-circuit, 4 battery, 6 plastic-bar, 1 engine-unit | 108 | 20 s | 5 / 96 |
| 9 | 5 Volcan (silhouette) | 2 200 | 3,28 | 26 | 6 steel-plate, 6 electronic-circuit, 4 battery, 15 fo-tungsten-plate, 13 plastic-bar | 180 | 21 s | 5 / 112 |
| 10 | 5 Volcan (+ pièce) | 2 350 | 3,44 | 26,25 | 7 steel-plate, 7 electronic-circuit, 4 battery, 19 fo-tungsten-plate, 17 plastic-bar | 216 | 23 s | 5 / 112 |
| 11 | 6 Électricité (silhouette) | 2 500 | 3,48 | 26,5 | 7 steel-plate, 7 electronic-circuit, 17 battery, 18 fo-tungsten-plate | 278 | 23 s | 4 / 128 |
| 12 | 6 Électricité (+ pièce) | 2 650 | 3,52 | 26,75 | 8 steel-plate, 8 electronic-circuit, 20 battery, 25 fo-tungsten-plate | 340 | 26 s | 4 / 128 |
| 13 | 7 Cristal (silhouette) | 2 800 | 3,56 | 27 | 8 steel-plate, 8 electronic-circuit, 21 battery, 75 fo-resonance-crystal | 474 | 38 s | 5 / 144 |
| 14 | 7 Cristal (+ pièce) | 2 950 | 3,6 | 27,25 | 8 steel-plate, 8 electronic-circuit, 26 battery, 95 fo-resonance-crystal | 579 | 42 s | 5 / 144 |
| 15 | 8 Marais (silhouette) | 3 100 | 3,64 | 27,5 | 9 steel-plate, 9 electronic-circuit, 6 battery, 40 fo-methane-barrel, 85 fo-resonance-crystal | 777 | 43 s | 9 / 160 |
| 16 | 8 Marais (+ pièce) | 3 250 | 3,68 | 27,75 | 9 steel-plate, 9 electronic-circuit, 6 battery, 50 fo-methane-barrel, 110 fo-resonance-crystal | 952 | 48 s | 11 / 160 |
| 17 | 9 Atome (silhouette) | 3 400 | 3,72 | 28 | 10 steel-plate, 10 electronic-circuit, 7 battery, 45 uranium-238, 45 fo-methane-barrel | 1 218 | 49 s | 9 / 176 |
| 18 | 9 Atome (+ pièce) | 3 550 | 3,76 | 28,25 | 10 steel-plate, 10 electronic-circuit, 7 battery, 60 uranium-238, 55 fo-methane-barrel | 1 528 | 54 s | 10 / 176 |
| 19 | 10 Haute technologie (silhouette) | 3 700 | 3,8 | 28,5 | 11 steel-plate, 11 electronic-circuit, 7 battery, 15 processing-unit, 55 uranium-238 | 2 041 | 1 min 22 s | 5 / 192 |
| 20 | 10 Haute technologie (+ pièce) | 3 850 | 3,84 | 28,75 | 11 steel-plate, 11 electronic-circuit, 7 battery, 19 processing-unit, 65 uranium-238 | 2 481 | 1 min 30 s | 5 / 192 |
| 21 | 11 Titane (silhouette) | 4 000 | 3,88 | 29 | 12 steel-plate, 12 electronic-circuit, 8 battery, 45 low-density-structure, 17 processing-unit | 3 462 | 1 min 31 s | 9 / 208 |
| 22 | 11 Titane (+ pièce) | 4 150 | 3,92 | 29,25 | 12 steel-plate, 12 electronic-circuit, 8 battery, 55 low-density-structure, 20 processing-unit | 4 137 | 1 min 40 s | 10 / 208 |
| 23 | 12 Supraconducteurs (silhouette) | 4 300 | 3,96 | 29,5 | 12 steel-plate, 12 electronic-circuit, 8 battery, 210 electric-engine-unit, 50 low-density-structure | 5 772 | 1 min 43 s | 13 / 224 |
| 24 | 12 Supraconducteurs (+ pièce) | 4 450 | 4 | 29,75 | 13 steel-plate, 13 electronic-circuit, 9 battery, 260 electric-engine-unit, 60 low-density-structure | 7 039 | 1 min 54 s | 15 / 224 |
| 25 | 13 Fusion (silhouette) | 4 600 | 4,04 | 30 | 13 steel-plate, 13 electronic-circuit, 9 battery, 130 uranium-235, 250 electric-engine-unit | 10 029 | 2 min 36 s | 10 / 240 |
| 26 | 13 Fusion (+ pièce) | 4 750 | 4,08 | 30,25 | 14 steel-plate, 14 electronic-circuit, 9 battery, 160 uranium-235, 310 electric-engine-unit | 12 346 | 2 min 52 s | 12 / 240 |
| 27 | 14 Orbite (silhouette) | 4 900 | 4,12 | 30,5 | 14 steel-plate, 14 electronic-circuit, 10 battery, 65 rocket-control-unit, 140 uranium-235 | 16 245 | 3 min 06 s | 12 / 256 |
| 28 | 14 Orbite (+ pièce) | 5 050 | 4,16 | 30,75 | 15 steel-plate, 15 electronic-circuit, 10 battery, 80 rocket-control-unit, 180 uranium-235 | 20 303 | 3 min 25 s | 13 / 256 |
| 29 | 15 Légende (silhouette) | 5 200 | 4,2 | 31 | 15 steel-plate, 15 electronic-circuit, 10 battery, 70 space-science-pack, 80 rocket-control-unit | 29 703 | 3 min 42 s | 12 / 272 |
| 30 | 15 Légende (+ pièce) | 5 350 | 4,24 | 31,25 | 16 steel-plate, 16 electronic-circuit, 10 battery, 90 space-science-pack, 95 rocket-control-unit | 36 960 | 4 min 04 s | 14 / 272 |

#### Mur (30 niveaux)

| Niveau | Époque | PV | réduction physique | réduction explosion | Coût du passage à ce niveau | Valeur (u) | Durée | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 350 | 3 | 10 | — | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 525 | 3,5 | 10,5 | 3 stone-brick | 6 | instantané | 1 / 48 |
| 3 | 2 Forge (silhouette) | 700 | 4 | 11 | 3 stone-brick, 1 steel-plate | 11 | instantané | 2 / 64 |
| 4 | 2 Forge (+ pièce) | 875 | 4,5 | 11,5 | 4 stone-brick, 1 steel-plate | 13 | instantané | 2 / 64 |
| 5 | 3 Vapeur (silhouette) | 1 050 | 5 | 12 | 4 stone-brick, 1 engine-unit | 17 | instantané | 2 / 80 |
| 6 | 3 Vapeur (+ pièce) | 1 225 | 5,5 | 12,5 | 5 stone-brick, 1 engine-unit | 19 | instantané | 2 / 80 |
| 7 | 4 Pétrole (silhouette) | 1 400 | 6 | 13 | 5 stone-brick, 4 plastic-bar | 22 | instantané | 2 / 96 |
| 8 | 4 Pétrole (+ pièce) | 1 575 | 6,5 | 13,5 | 6 stone-brick, 4 plastic-bar | 24 | instantané | 2 / 96 |
| 9 | 5 Volcan (silhouette) | 1 750 | 7 | 14 | 6 stone-brick, 4 fo-tungsten-plate | 28 | instantané | 2 / 112 |
| 10 | 5 Volcan (+ pièce) | 1 925 | 7,5 | 14,5 | 7 stone-brick, 4 fo-tungsten-plate | 30 | instantané | 2 / 112 |
| 11 | 6 Électricité (silhouette) | 2 100 | 8 | 15 | 7 stone-brick, 2 battery | 32 | instantané | 2 / 128 |
| 12 | 6 Électricité (+ pièce) | 2 275 | 8,5 | 15,5 | 8 stone-brick, 3 battery | 43 | instantané | 2 / 128 |
| 13 | 7 Cristal (silhouette) | 2 450 | 9 | 16 | 8 stone-brick, 12 fo-resonance-crystal | 52 | instantané | 2 / 144 |
| 14 | 7 Cristal (+ pièce) | 2 625 | 9,5 | 16,5 | 8 stone-brick, 15 fo-resonance-crystal | 61 | instantané | 2 / 144 |
| 15 | 8 Marais (silhouette) | 2 800 | 10 | 17 | 9 stone-brick, 6 fo-methane-barrel | 78 | instantané | 2 / 160 |
| 16 | 8 Marais (+ pièce) | 2 975 | 10,5 | 17,5 | 9 stone-brick, 8 fo-methane-barrel | 98 | instantané | 2 / 160 |
| 17 | 9 Atome (silhouette) | 3 150 | 11 | 18 | 10 stone-brick, 8 uranium-238 | 132 | instantané | 2 / 176 |
| 18 | 9 Atome (+ pièce) | 3 325 | 11,5 | 18,5 | 10 stone-brick, 10 uranium-238 | 160 | instantané | 2 / 176 |
| 19 | 10 Haute technologie (silhouette) | 3 500 | 12 | 19 | 11 stone-brick, 2 processing-unit | 172 | instantané | 2 / 192 |
| 20 | 10 Haute technologie (+ pièce) | 3 675 | 12,5 | 19,5 | 11 stone-brick, 3 processing-unit | 247 | instantané | 2 / 192 |
| 21 | 11 Titane (silhouette) | 3 850 | 13 | 20 | 12 stone-brick, 7 low-density-structure | 339 | instantané | 2 / 208 |
| 22 | 11 Titane (+ pièce) | 4 025 | 13,5 | 20,5 | 12 stone-brick, 9 low-density-structure | 429 | instantané | 2 / 208 |
| 23 | 12 Supraconducteurs (silhouette) | 4 200 | 14 | 21 | 12 stone-brick, 35 electric-engine-unit | 584 | instantané | 2 / 224 |
| 24 | 12 Supraconducteurs (+ pièce) | 4 375 | 14,5 | 21,5 | 13 stone-brick, 45 electric-engine-unit | 746 | instantané | 2 / 224 |
| 25 | 13 Fusion (silhouette) | 4 550 | 15 | 22 | 13 stone-brick, 20 uranium-235 | 926 | instantané | 2 / 240 |
| 26 | 13 Fusion (+ pièce) | 4 725 | 15,5 | 22,5 | 14 stone-brick, 25 uranium-235 | 1 153 | instantané | 2 / 240 |
| 27 | 14 Orbite (silhouette) | 4 900 | 16 | 23 | 14 stone-brick, 11 rocket-control-unit | 1 678 | instantané | 3 / 256 |
| 28 | 14 Orbite (+ pièce) | 5 075 | 16,5 | 23,5 | 15 stone-brick, 14 rocket-control-unit | 2 130 | instantané | 3 / 256 |
| 29 | 15 Légende (silhouette) | 5 250 | 17 | 24 | 15 stone-brick, 12 space-science-pack | 3 030 | instantané | 2 / 272 |
| 30 | 15 Légende (+ pièce) | 5 425 | 17,5 | 24,5 | 16 stone-brick, 15 space-science-pack | 3 782 | instantané | 2 / 272 |

#### Foreuse électrique (30 niveaux)

| Niveau | Époque | PV | minage | kW | Coût du passage à ce niveau | Valeur (u) | Durée | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 300 | 0,5 | 90 | — | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 345 | 0,55 | 96,3 | 6 iron-plate, 3 iron-gear-wheel, 2 electronic-circuit | 17 | 7 s | 3 / 48 |
| 3 | 2 Forge (silhouette) | 390 | 0,6 | 102,6 | 7 iron-plate, 3 iron-gear-wheel, 2 electronic-circuit, 1 steel-plate | 23 | 8 s | 4 / 64 |
| 4 | 2 Forge (+ pièce) | 435 | 0,65 | 108,9 | 8 iron-plate, 4 iron-gear-wheel, 3 electronic-circuit, 2 steel-plate | 34 | 8 s | 4 / 64 |
| 5 | 3 Vapeur (silhouette) | 480 | 0,7 | 115,2 | 9 iron-plate, 4 iron-gear-wheel, 3 electronic-circuit, 1 engine-unit, 1 steel-plate | 39 | 8 s | 5 / 80 |
| 6 | 3 Vapeur (+ pièce) | 525 | 0,75 | 121,5 | 10 iron-plate, 5 iron-gear-wheel, 3 electronic-circuit, 1 engine-unit, 1 steel-plate | 42 | 9 s | 5 / 80 |
| 7 | 4 Pétrole (silhouette) | 570 | 0,8 | 127,8 | 11 iron-plate, 5 iron-gear-wheel, 4 electronic-circuit, 4 plastic-bar | 43 | 9 s | 4 / 96 |
| 8 | 4 Pétrole (+ pièce) | 615 | 0,85 | 134,1 | 11 iron-plate, 6 iron-gear-wheel, 4 electronic-circuit, 4 plastic-bar | 45 | 10 s | 4 / 96 |
| 9 | 5 Volcan (silhouette) | 660 | 0,9 | 140,4 | 12 iron-plate, 6 iron-gear-wheel, 4 electronic-circuit, 5 fo-tungsten-plate, 5 plastic-bar | 69 | 11 s | 5 / 112 |
| 10 | 5 Volcan (+ pièce) | 705 | 0,95 | 146,7 | 13 iron-plate, 7 iron-gear-wheel, 4 electronic-circuit, 7 fo-tungsten-plate, 6 plastic-bar | 83 | 12 s | 5 / 112 |
| 11 | 6 Électricité (silhouette) | 750 | 1 | 153 | 14 iron-plate, 7 iron-gear-wheel, 5 electronic-circuit, 4 battery, 6 fo-tungsten-plate | 101 | 12 s | 5 / 128 |
| 12 | 6 Électricité (+ pièce) | 795 | 1,05 | 159,3 | 15 iron-plate, 8 iron-gear-wheel, 5 electronic-circuit, 5 battery, 8 fo-tungsten-plate | 121 | 13 s | 5 / 128 |
| 13 | 7 Cristal (silhouette) | 840 | 1,1 | 165,6 | 16 iron-plate, 8 iron-gear-wheel, 5 electronic-circuit, 25 fo-resonance-crystal, 6 battery | 174 | 19 s | 5 / 144 |
| 14 | 7 Cristal (+ pièce) | 885 | 1,15 | 171,9 | 17 iron-plate, 8 iron-gear-wheel, 6 electronic-circuit, 30 fo-resonance-crystal, 7 battery | 201 | 21 s | 5 / 144 |
| 15 | 8 Marais (silhouette) | 930 | 1,2 | 178,2 | 18 iron-plate, 9 iron-gear-wheel, 6 electronic-circuit, 13 fo-methane-barrel, 30 fo-resonance-crystal | 271 | 22 s | 6 / 160 |
| 16 | 8 Marais (+ pièce) | 975 | 1,25 | 184,5 | 19 iron-plate, 9 iron-gear-wheel, 6 electronic-circuit, 17 fo-methane-barrel, 35 fo-resonance-crystal | 327 | 24 s | 6 / 160 |
| 17 | 9 Atome (silhouette) | 1 020 | 1,3 | 190,8 | 20 iron-plate, 10 iron-gear-wheel, 7 electronic-circuit, 16 uranium-238, 15 fo-methane-barrel | 432 | 25 s | 6 / 176 |
| 18 | 9 Atome (+ pièce) | 1 065 | 1,35 | 197,1 | 20 iron-plate, 10 iron-gear-wheel, 7 electronic-circuit, 20 uranium-238, 19 fo-methane-barrel | 528 | 27 s | 6 / 176 |
| 19 | 10 Haute technologie (silhouette) | 1 110 | 1,4 | 203,4 | 20 iron-plate, 11 iron-gear-wheel, 7 electronic-circuit, 5 processing-unit, 19 uranium-238 | 701 | 41 s | 5 / 192 |
| 20 | 10 Haute technologie (+ pièce) | 1 155 | 1,45 | 209,7 | 20 iron-plate, 11 iron-gear-wheel, 7 electronic-circuit, 7 processing-unit, 25 uranium-238 | 935 | 45 s | 5 / 192 |
| 21 | 11 Titane (silhouette) | 1 200 | 1,5 | 216 | 25 iron-plate, 12 iron-gear-wheel, 8 electronic-circuit, 15 low-density-structure, 6 processing-unit | 1 194 | 46 s | 6 / 208 |
| 22 | 11 Titane (+ pièce) | 1 245 | 1,55 | 222,3 | 25 iron-plate, 12 iron-gear-wheel, 8 electronic-circuit, 19 low-density-structure, 7 processing-unit | 1 449 | 50 s | 6 / 208 |
| 23 | 12 Supraconducteurs (silhouette) | 1 290 | 1,6 | 228,6 | 25 iron-plate, 12 iron-gear-wheel, 8 electronic-circuit, 70 electric-engine-unit, 17 low-density-structure | 1 954 | 52 s | 7 / 224 |
| 24 | 12 Supraconducteurs (+ pièce) | 1 335 | 1,65 | 234,9 | 25 iron-plate, 13 iron-gear-wheel, 9 electronic-circuit, 90 electric-engine-unit, 20 low-density-structure | 2 414 | 57 s | 7 / 224 |
| 25 | 13 Fusion (silhouette) | 1 380 | 1,7 | 241,2 | 25 iron-plate, 13 iron-gear-wheel, 9 electronic-circuit, 45 uranium-235, 85 electric-engine-unit | 3 459 | 1 min 18 s | 6 / 240 |
| 26 | 13 Fusion (+ pièce) | 1 425 | 1,75 | 247,5 | 30 iron-plate, 14 iron-gear-wheel, 9 electronic-circuit, 55 uranium-235, 110 electric-engine-unit | 4 316 | 1 min 26 s | 7 / 240 |
| 27 | 14 Orbite (silhouette) | 1 470 | 1,8 | 253,8 | 30 iron-plate, 14 iron-gear-wheel, 10 electronic-circuit, 25 rocket-control-unit, 50 uranium-235 | 6 083 | 1 min 33 s | 7 / 256 |
| 28 | 14 Orbite (+ pièce) | 1 515 | 1,85 | 260,1 | 30 iron-plate, 15 iron-gear-wheel, 10 electronic-circuit, 30 rocket-control-unit, 65 uranium-235 | 7 510 | 1 min 42 s | 7 / 256 |
| 29 | 15 Légende (silhouette) | 1 560 | 1,9 | 266,4 | 30 iron-plate, 15 iron-gear-wheel, 10 electronic-circuit, 25 space-science-pack, 25 rocket-control-unit | 10 085 | 1 min 51 s | 7 / 272 |
| 30 | 15 Légende (+ pièce) | 1 605 | 1,95 | 272,7 | 30 iron-plate, 16 iron-gear-wheel, 10 electronic-circuit, 30 space-science-pack, 35 rocket-control-unit | 12 837 | 2 min 02 s | 8 / 272 |

#### Four en acier (30 niveaux)

| Niveau | Époque | PV | vitesse | kW | Coût du passage à ce niveau | Valeur (u) | Durée | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 300 | 2 | 90 | — | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 345 | 2,16 | 95,4 | 2 steel-plate, 3 stone-brick | 16 | 6 s | 2 / 48 |
| 3 | 2 Forge (silhouette) | 390 | 2,32 | 100,8 | 3 steel-plate, 3 stone-brick | 21 | 6 s | 2 / 64 |
| 4 | 2 Forge (+ pièce) | 435 | 2,48 | 106,2 | 5 steel-plate, 4 stone-brick | 33 | 7 s | 2 / 64 |
| 5 | 3 Vapeur (silhouette) | 480 | 2,64 | 111,6 | 4 steel-plate, 4 stone-brick, 1 engine-unit | 37 | 7 s | 3 / 80 |
| 6 | 3 Vapeur (+ pièce) | 525 | 2,8 | 117 | 4 steel-plate, 5 stone-brick, 1 engine-unit | 39 | 8 s | 3 / 80 |
| 7 | 4 Pétrole (silhouette) | 570 | 2,96 | 122,4 | 4 steel-plate, 5 stone-brick, 4 plastic-bar | 42 | 8 s | 3 / 96 |
| 8 | 4 Pétrole (+ pièce) | 615 | 3,12 | 127,8 | 4 steel-plate, 6 stone-brick, 4 plastic-bar | 44 | 9 s | 3 / 96 |
| 9 | 5 Volcan (silhouette) | 660 | 3,28 | 133,2 | 4 steel-plate, 6 stone-brick, 5 fo-tungsten-plate, 4 plastic-bar | 64 | 9 s | 4 / 112 |
| 10 | 5 Volcan (+ pièce) | 705 | 3,44 | 138,6 | 4 steel-plate, 7 stone-brick, 6 fo-tungsten-plate, 5 plastic-bar | 73 | 10 s | 4 / 112 |
| 11 | 6 Électricité (silhouette) | 750 | 3,6 | 144 | 5 steel-plate, 7 stone-brick, 4 battery, 5 fo-tungsten-plate | 95 | 10 s | 4 / 128 |
| 12 | 6 Électricité (+ pièce) | 795 | 3,76 | 149,4 | 5 steel-plate, 8 stone-brick, 5 battery, 7 fo-tungsten-plate | 114 | 11 s | 4 / 128 |
| 13 | 7 Cristal (silhouette) | 840 | 3,92 | 154,8 | 5 steel-plate, 8 stone-brick, 20 fo-resonance-crystal, 5 battery | 146 | 16 s | 4 / 144 |
| 14 | 7 Cristal (+ pièce) | 885 | 4,08 | 160,2 | 6 steel-plate, 8 stone-brick, 30 fo-resonance-crystal, 6 battery | 190 | 18 s | 4 / 144 |
| 15 | 8 Marais (silhouette) | 930 | 4,24 | 165,6 | 6 steel-plate, 9 stone-brick, 12 fo-methane-barrel, 25 fo-resonance-crystal | 243 | 18 s | 5 / 160 |
| 16 | 8 Marais (+ pièce) | 975 | 4,4 | 171 | 6 steel-plate, 9 stone-brick, 14 fo-methane-barrel, 30 fo-resonance-crystal | 278 | 20 s | 5 / 160 |
| 17 | 9 Atome (silhouette) | 1 020 | 4,56 | 176,4 | 7 steel-plate, 10 stone-brick, 14 uranium-238, 13 fo-methane-barrel | 381 | 21 s | 5 / 176 |
| 18 | 9 Atome (+ pièce) | 1 065 | 4,72 | 181,8 | 7 steel-plate, 10 stone-brick, 17 uranium-238, 16 fo-methane-barrel | 453 | 23 s | 5 / 176 |
| 19 | 10 Haute technologie (silhouette) | 1 110 | 4,88 | 187,2 | 7 steel-plate, 11 stone-brick, 4 processing-unit, 16 uranium-238 | 581 | 34 s | 4 / 192 |
| 20 | 10 Haute technologie (+ pièce) | 1 155 | 5,04 | 192,6 | 7 steel-plate, 11 stone-brick, 6 processing-unit, 20 uranium-238 | 787 | 37 s | 4 / 192 |
| 21 | 11 Titane (silhouette) | 1 200 | 5,2 | 198 | 8 steel-plate, 12 stone-brick, 13 low-density-structure, 5 processing-unit | 1 024 | 38 s | 5 / 208 |
| 22 | 11 Titane (+ pièce) | 1 245 | 5,36 | 203,4 | 8 steel-plate, 12 stone-brick, 16 low-density-structure, 6 processing-unit | 1 234 | 42 s | 5 / 208 |
| 23 | 12 Supraconducteurs (silhouette) | 1 290 | 5,52 | 208,8 | 8 steel-plate, 12 stone-brick, 60 electric-engine-unit, 15 low-density-structure | 1 699 | 43 s | 6 / 224 |
| 24 | 12 Supraconducteurs (+ pièce) | 1 335 | 5,68 | 214,2 | 9 steel-plate, 13 stone-brick, 75 electric-engine-unit, 18 low-density-structure | 2 081 | 47 s | 6 / 224 |
| 25 | 13 Fusion (silhouette) | 1 380 | 5,84 | 219,6 | 9 steel-plate, 13 stone-brick, 40 uranium-235, 75 electric-engine-unit | 3 071 | 1 min 05 s | 5 / 240 |
| 26 | 13 Fusion (+ pièce) | 1 425 | 6 | 225 | 9 steel-plate, 14 stone-brick, 50 uranium-235, 90 electric-engine-unit | 3 763 | 1 min 12 s | 5 / 240 |
| 27 | 14 Orbite (silhouette) | 1 470 | 6,16 | 230,4 | 10 steel-plate, 14 stone-brick, 19 rocket-control-unit, 45 uranium-235 | 4 953 | 1 min 18 s | 5 / 256 |
| 28 | 14 Orbite (+ pièce) | 1 515 | 6,32 | 235,8 | 10 steel-plate, 15 stone-brick, 25 rocket-control-unit, 55 uranium-235 | 6 305 | 1 min 25 s | 6 / 256 |
| 29 | 15 Légende (silhouette) | 1 560 | 6,48 | 241,2 | 10 steel-plate, 15 stone-brick, 20 space-science-pack, 25 rocket-control-unit | 8 830 | 1 min 33 s | 6 / 272 |
| 30 | 15 Légende (+ pièce) | 1 605 | 6,64 | 246,6 | 10 steel-plate, 16 stone-brick, 25 space-science-pack, 30 rocket-control-unit | 10 832 | 1 min 42 s | 6 / 272 |

#### Machine d'assemblage 2 (30 niveaux)

| Niveau | Époque | PV | vitesse | kW | Coût du passage à ce niveau | Valeur (u) | Durée | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 350 | 0,75 | 150 | — | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 402,5 | 0,81 | 159 | 6 iron-plate, 3 iron-gear-wheel, 3 electronic-circuit | 20 | 7 s | 3 / 48 |
| 3 | 2 Forge (silhouette) | 455 | 0,87 | 168 | 7 iron-plate, 3 iron-gear-wheel, 3 electronic-circuit, 1 steel-plate | 26 | 8 s | 4 / 64 |
| 4 | 2 Forge (+ pièce) | 507,5 | 0,93 | 177 | 8 iron-plate, 4 iron-gear-wheel, 4 electronic-circuit, 2 steel-plate | 36 | 8 s | 4 / 64 |
| 5 | 3 Vapeur (silhouette) | 560 | 0,99 | 186 | 9 iron-plate, 4 iron-gear-wheel, 4 electronic-circuit, 1 engine-unit, 1 steel-plate | 41 | 8 s | 5 / 80 |
| 6 | 3 Vapeur (+ pièce) | 612,5 | 1,05 | 195 | 10 iron-plate, 5 iron-gear-wheel, 5 electronic-circuit, 1 engine-unit, 1 steel-plate | 47 | 9 s | 5 / 80 |
| 7 | 4 Pétrole (silhouette) | 665 | 1,11 | 204 | 11 iron-plate, 5 iron-gear-wheel, 5 electronic-circuit, 5 plastic-bar | 49 | 9 s | 4 / 96 |
| 8 | 4 Pétrole (+ pièce) | 717,5 | 1,17 | 213 | 11 iron-plate, 6 iron-gear-wheel, 6 electronic-circuit, 4 plastic-bar | 50 | 10 s | 4 / 96 |
| 9 | 5 Volcan (silhouette) | 770 | 1,23 | 222 | 12 iron-plate, 6 iron-gear-wheel, 6 electronic-circuit, 5 fo-tungsten-plate, 5 plastic-bar | 74 | 11 s | 5 / 112 |
| 10 | 5 Volcan (+ pièce) | 822,5 | 1,29 | 231 | 13 iron-plate, 7 iron-gear-wheel, 7 electronic-circuit, 7 fo-tungsten-plate, 6 plastic-bar | 91 | 12 s | 5 / 112 |
| 11 | 6 Électricité (silhouette) | 875 | 1,35 | 240 | 14 iron-plate, 7 iron-gear-wheel, 7 electronic-circuit, 4 battery, 6 fo-tungsten-plate | 106 | 12 s | 5 / 128 |
| 12 | 6 Électricité (+ pièce) | 927,5 | 1,41 | 249 | 15 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 5 battery, 8 fo-tungsten-plate | 128 | 13 s | 5 / 128 |
| 13 | 7 Cristal (silhouette) | 980 | 1,47 | 258 | 16 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 25 fo-resonance-crystal, 6 battery | 181 | 19 s | 5 / 144 |
| 14 | 7 Cristal (+ pièce) | 1032,5 | 1,53 | 267 | 17 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 30 fo-resonance-crystal, 7 battery | 206 | 21 s | 5 / 144 |
| 15 | 8 Marais (silhouette) | 1 085 | 1,59 | 276 | 18 iron-plate, 9 iron-gear-wheel, 9 electronic-circuit, 13 fo-methane-barrel, 30 fo-resonance-crystal | 279 | 22 s | 6 / 160 |
| 16 | 8 Marais (+ pièce) | 1137,5 | 1,65 | 285 | 19 iron-plate, 9 iron-gear-wheel, 9 electronic-circuit, 17 fo-methane-barrel, 35 fo-resonance-crystal | 335 | 24 s | 6 / 160 |
| 17 | 9 Atome (silhouette) | 1 190 | 1,71 | 294 | 20 iron-plate, 10 iron-gear-wheel, 10 electronic-circuit, 16 uranium-238, 15 fo-methane-barrel | 439 | 25 s | 6 / 176 |
| 18 | 9 Atome (+ pièce) | 1242,5 | 1,77 | 303 | 20 iron-plate, 10 iron-gear-wheel, 10 electronic-circuit, 20 uranium-238, 19 fo-methane-barrel | 535 | 27 s | 6 / 176 |
| 19 | 10 Haute technologie (silhouette) | 1 295 | 1,83 | 312 | 20 iron-plate, 11 iron-gear-wheel, 11 electronic-circuit, 5 processing-unit, 19 uranium-238 | 711 | 41 s | 5 / 192 |
| 20 | 10 Haute technologie (+ pièce) | 1347,5 | 1,89 | 321 | 20 iron-plate, 11 iron-gear-wheel, 11 electronic-circuit, 7 processing-unit, 25 uranium-238 | 945 | 45 s | 5 / 192 |
| 21 | 11 Titane (silhouette) | 1 400 | 1,95 | 330 | 25 iron-plate, 12 iron-gear-wheel, 12 electronic-circuit, 15 low-density-structure, 6 processing-unit | 1 204 | 46 s | 6 / 208 |
| 22 | 11 Titane (+ pièce) | 1452,5 | 2,01 | 339 | 25 iron-plate, 12 iron-gear-wheel, 12 electronic-circuit, 19 low-density-structure, 7 processing-unit | 1 459 | 50 s | 6 / 208 |
| 23 | 12 Supraconducteurs (silhouette) | 1 505 | 2,07 | 348 | 25 iron-plate, 12 iron-gear-wheel, 12 electronic-circuit, 70 electric-engine-unit, 17 low-density-structure | 1 964 | 52 s | 7 / 224 |
| 24 | 12 Supraconducteurs (+ pièce) | 1557,5 | 2,13 | 357 | 25 iron-plate, 13 iron-gear-wheel, 13 electronic-circuit, 90 electric-engine-unit, 20 low-density-structure | 2 424 | 57 s | 7 / 224 |
| 25 | 13 Fusion (silhouette) | 1 610 | 2,19 | 366 | 25 iron-plate, 13 iron-gear-wheel, 13 electronic-circuit, 45 uranium-235, 85 electric-engine-unit | 3 469 | 1 min 18 s | 6 / 240 |
| 26 | 13 Fusion (+ pièce) | 1662,5 | 2,25 | 375 | 30 iron-plate, 14 iron-gear-wheel, 14 electronic-circuit, 55 uranium-235, 110 electric-engine-unit | 4 328 | 1 min 26 s | 7 / 240 |
| 27 | 14 Orbite (silhouette) | 1 715 | 2,31 | 384 | 30 iron-plate, 14 iron-gear-wheel, 14 electronic-circuit, 25 rocket-control-unit, 50 uranium-235 | 6 093 | 1 min 33 s | 7 / 256 |
| 28 | 14 Orbite (+ pièce) | 1767,5 | 2,37 | 393 | 30 iron-plate, 15 iron-gear-wheel, 15 electronic-circuit, 30 rocket-control-unit, 65 uranium-235 | 7 523 | 1 min 42 s | 7 / 256 |
| 29 | 15 Légende (silhouette) | 1 820 | 2,43 | 402 | 30 iron-plate, 15 iron-gear-wheel, 15 electronic-circuit, 25 space-science-pack, 25 rocket-control-unit | 10 098 | 1 min 51 s | 7 / 272 |
| 30 | 15 Légende (+ pièce) | 1872,5 | 2,49 | 411 | 30 iron-plate, 16 iron-gear-wheel, 16 electronic-circuit, 30 space-science-pack, 35 rocket-control-unit | 12 852 | 2 min 02 s | 8 / 272 |
