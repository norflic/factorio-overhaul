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

### 10 bis. PvP et difficulté (lot IA0, 21/10 ; base défendue : lot IA0b, 21/10)
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

**Base défendue (lot IA0b, corrigé après vérification adverse).** Défense estimée de la cible = 8 × tourelles à
40 tuiles (inchangé).

| Niveau | Rapport de force exigé (avant prudence) | Siège au plus (min) | Plafond du siège (part de l'armée visée) | Assaut coordonné : fenêtre (min) | Jointe à (part du besoin) | Reprise contre le joueur sans attaque lancée (min) |
|---|---|---|---|---|---|---|
| Facile | 1,5 | 0 (jamais de siège) | — | — | — | 120 |
| Normal | 0,9 | 20 | 95 % | — | — | 64 |
| Difficile | 0,65 | 30 | 100 % | 2 | 80 % | 40 |
| Impitoyable | 0,5 | 45 | 100 % | 3 | 70 % | 24 |

| Personnalité | Prudence (× rapport) | Rapport exigé : Facile / Normal / Difficile / Impitoyable | Armée visée (100 soldats max.) |
|---|---|---|---|
| Conquérant | 0,75 | 1,125 / 0,675 / 0,488 / 0,375 | 80 |
| Équilibré | 0,90 | 1,350 / 0,810 / 0,585 / 0,450 | 60 |
| Technocrate | 0,95 | 1,425 / 0,855 / 0,618 / 0,475 | 45 |
| Bâtisseur | 1,00 | 1,500 / 0,900 / 0,650 / 0,500 | 40 |

Règles du lot IA0b :
- **Besoin** = max(taille minimale, rapport exigé × défense / force du soldat). Avant IA0b : 1,3 × défense à
  tous les niveaux. Exemple, 3 tourelles (24) en tech 0 : le conquérant exigeait 32 soldats envoyés ; il en
  exige 17 en Normal, 12 en Difficile, 10 (taille minimale) en Impitoyable, 27 en Facile.
- **Siège** : sans le besoin, la faction garde ses soldats pour le joueur (plus d'attaque contre sa rivale)
  pendant au plus `siege_min`. Expiré : une attaque contre la rivale (répit), puis un nouveau siège. Besoin
  atteint à l'expiration : elle frappe avec ce qu'elle a.
- **Dissuasion** : si la garnison nécessaire dépasse le plafond (part de l'armée visée), pas de siège ; la
  faction attaque sa rivale. Facile ne fait jamais de siège.
- **Plancher des attaques suivantes** : après `save_min`, la faction attaque dès 0,75 × la taille visée (au
  plus 0,95 × ce que l'armée visée entière peut envoyer, au moins le besoin). Taille visée face à une
  défense : size_mult × prudence × défense / force. Sans ce plancher, les niveaux élevés (plus téméraires)
  frappaient une base défendue avec MOINS de soldats que Normal.
- **Attente « save » plus longue qu'avant (compromis voulu, documenté à la demande du vérificateur)** : quand
  le besoin est atteint mais pas le plancher, la faction attend jusqu'à `siege_min` (20, 30 ou 45 min) et non
  plus `save_min` (3, 5 ou 7 min). Effet mesuré (sonde du vérificateur, 90 s par soldat, base sans tourelle,
  Impitoyable) : équilibré 11 → 9 attaques, technocrate 11 → 7 (attaques plus grosses). Borner cette attente
  à 1,5, 2 ou 3 × `save_min` a été essayé : écarts d'ordre strict sur la grille du vérificateur à 45 s par
  soldat 10, 13 et 6 (contre 1), à 90 s 73, 81 et 70 (contre 61) ; non retenu.
- **Assaut coordonné** (Difficile, Impitoyable) : une attaque prête contre le joueur ouvre une fenêtre et
  fixe la **cible commune** (position et défense estimée de sa cible). Une autre faction s'y joint, contre
  cette cible : soit sous son besoin (calculé contre la défense de la cible commune), avec au moins 80 %
  (Difficile) ou 70 % (Impitoyable) de ce besoin et **jamais sous la taille minimale du niveau** ; soit dès
  son plancher, sans attendre la fin de `save_min`. Une attaque jointe n'ouvre pas de fenêtre ; la fenêtre
  (2 ou 3 min) ne dépasse pas l'intervalle entre deux attaques (5 ou 3 min) : une faction ne se joint jamais
  à sa propre fenêtre. Avant correction, les jointes partaient sous la taille minimale (7 soldats pour 10)
  et chaque faction visait son propre secteur.
- **Taille minimale contre le joueur plafonnée par l'armée visée** (0,9 × ce que l'armée visée peut envoyer) :
  bâtisseur, Normal, 28 → 21. Avec 100 soldats maximum, seul le bâtisseur change ; avec 60
  (`/fo-war start … 60`, moteur simulé de `pvp_test`), le technocrate aussi (25 → 15 en Normal).
- **Guerre ENTRE factions inchangée depuis IA0** (correction du vérificateur) : le plafond `rival_min_cap`
  livré au premier passage du lot changeait la guerre entre factions à tous les niveaux, Paisible compris ;
  il est retiré. `S.attack` est identique à une copie figée de celle d'IA0 (`pvp_test` : 58 176 cas) ; moteur
  simulé, Paisible, 4 factions, 60 min, armée maximale 100 et 60 : attaques par faction identiques à celles
  du code IA0 (Écarlate 43 et 31, Azur 23 et 4, Émeraude 4 et 0, Ambre 29 et 29). Le bâtisseur n'attaque
  donc toujours jamais sa rivale (28 > 24 envoyables) : défaut antérieur (E21), hors du contrat IA0b.
- **Fin de l'impasse de la règle du déficit** (défaut antérieur au lot, relevé par le vérificateur) : après
  une attaque contre le joueur, une faction n'en redevenait « due » qu'après avoir attaqué sa rivale ; si elle
  ne le pouvait pas (bâtisseur ; rivale trop défendue), elle n'attaquait plus jamais le joueur (sonde du
  vérificateur, rivale de défense 30 : technocrate et bâtisseur, 1 attaque en 180 min à tous les niveaux).
  Désormais, une faction qui n'a rien lancé (ni contre le joueur, ni contre une faction) depuis 8 ×
  l'intervalle du niveau se retourne contre le joueur (tableau ci-dessus). Essais : 4 × l'intervalle casse
  l'ordre et prive la rivale d'attaques en Impitoyable (6 écarts) ; 10 × donne 39 écarts à 90 s par soldat
  (contre 61) mais la reprise prend 80 min en Normal. Une reprise immédiate quand la rivale est hors de portée
  de l'armée visée a aussi été essayée : le bâtisseur, limité par sa production, attaquait alors autant en
  Normal qu'en Difficile (29 écarts) ; non retenue.
- Ordre de grandeur (loi de Lanchester au carré, non mesuré en moteur réel) : une tourelle à munitions
  perforantes (400 PV, 80 dégâts/s) vaut 2,6 fusiliers (200 PV, 24 dégâts/s) ; le rapport le plus téméraire
  (conquérant, Impitoyable) envoie 3 fusiliers par tourelle estimée. Une jointe à 70 % du besoin en envoie
  2,1 : sous la parité si elle arrivait seule ; elle vise la même cible dans la même fenêtre que l'attaque qui
  l'a ouverte. **Le caractère non suicidaire des attaques jointes n'est PAS prouvé en moteur réel.**
- Force des soldats (`S.soldier_strength`, antérieure au lot, non corrigée) : le mitrailleur (tech 1, 11,55
  fusiliers) vaut 2,5 fois le grenadier (tech 2, 4,54). Le besoin contre une base défendue est donc 2,5 fois
  plus grand en tech 2 qu'en tech 1 : 8 tourelles sont plus dures en tech 2 qu'en tech 1, ce qui déforme les
  configurations par technologie (hypothèse à consigner au RD_LOG).

Mesures (campagne pure, `tests/pvp_test.lua` : 180 min, 1 soldat toutes les 45 s jusqu'à l'**armée visée**
du planificateur ; une rivale toujours disponible, défense 10). Cellule : 1re attaque · nombre · taille
moyenne ; « jamais » = aucune attaque en 180 min. Avant = code du lot IA0, même modèle. Après = code corrigé
(les lignes du conquérant, de l'équilibré et du technocrate sont identiques au premier passage du lot ; le
bâtisseur attaque moins souvent qu'au premier passage, qui le faisait attaquer sa rivale grâce au plafond
retiré).

| Base | Personnalité | Facile avant → après | Normal avant → après | Difficile avant → après | Impitoyable avant → après |
|---|---|---|---|---|---|
| 2 tourelles, tech 0 | Conquérant | jamais → jamais | jamais → 22,8 min · 13 · 15,5 | jamais → 12,0 min · 20 · 17,1 | jamais → 8,2 min · 26 · 18,7 |
| 2 tourelles, tech 0 | Équilibré | jamais → jamais | jamais → 33,8 min · 10 · 20,0 | 18,8 min · 15 · 23,6 → 18,0 min · 15 · 23,5 | 17,2 min · 16 · 28,7 → 13,5 min · 16 · 28,4 |
| 2 tourelles, tech 0 | Technocrate | jamais → jamais | 44,2 min · 8 · 25,0 → identique | 22,5 min · 12 · 28,3 → identique | 18,0 min · 14 · 31,9 → 16,5 min · 14 · 31,9 |
| 2 tourelles, tech 0 | Bâtisseur | jamais → jamais | jamais → 42,9 min · 3 · 24,0 | 25,8 min · 1 · 27,0 → 25,8 min · 4 · 30,8 | 18,8 min · 1 · 22,0 → 18,8 min · 6 · 33,7 |
| 3 tourelles, tech 0 | Conquérant | jamais → jamais | jamais → 25,5 min · 12 · 17,0 | jamais → 12,0 min · 16 · 21,2 | jamais → 8,2 min · 19 · 25,4 |
| 3 tourelles, tech 0 | Équilibré | jamais → jamais | jamais → 33,8 min · 10 · 20,0 | jamais → 18,0 min · 14 · 24,6 | jamais → 13,5 min · 16 · 29,1 |
| 3 tourelles, tech 0 | Technocrate | jamais → jamais | jamais → 44,2 min · 8 · 25,0 | 29,2 min · 10 · 32,0 → 22,5 min · 12 · 28,3 | 27,0 min · 14 · 32,7 → 16,5 min · 14 · 31,9 |
| 3 tourelles, tech 0 | Bâtisseur | jamais → jamais | jamais → 42,9 min · 3 · 24,0 | 30,0 min · 1 · 32,0 → 25,8 min · 4 · 30,8 | 27,0 min · 1 · 32,0 → 18,8 min · 6 · 33,7 |
| 6 tourelles, tech 0 | Conquérant | jamais → jamais | jamais → 50,2 min · 6 · 33,0 | jamais → 20,2 min · 9 · 37,3 | jamais → 14,2 min · 11 · 38,9 |
| 6 tourelles, tech 0 | Équilibré | jamais → jamais | jamais → 64,5 min · 4 · 39,0 | jamais → 26,2 min · 7 · 43,6 | jamais → 18,0 min · 9 · 46,0 |
| 6 tourelles, tech 0 | Technocrate | jamais → jamais | jamais → jamais | jamais → 27,8 min · 8 · 34,4 | jamais → 19,5 min · 10 · 36,5 |
| 6 tourelles, tech 0 | Bâtisseur | jamais → jamais | jamais → jamais | jamais → 30,0 min · 4 · 32,0 | jamais → 20,2 min · 6 · 34,0 |
| 8 tourelles, tech 2 | Conquérant | jamais → jamais | jamais → 22,8 min · 13 · 15,5 | 16,5 min · 1 · 19,0 → 12,0 min · 20 · 17,1 | 28,7 min · 25 · 19,0 → 8,2 min · 26 · 18,7 |
| 8 tourelles, tech 2 | Équilibré | jamais → jamais | 33,8 min · 10 · 20,0 → identique | 18,0 min · 15 · 23,5 → identique | 15,8 min · 16 · 28,6 → 13,5 min · 16 · 28,4 |
| 8 tourelles, tech 2 | Technocrate | jamais → jamais | 44,2 min · 8 · 25,0 → identique | 22,5 min · 12 · 28,3 → identique | 16,5 min · 14 · 31,9 → identique |
| 8 tourelles, tech 2 | Bâtisseur | jamais → jamais | jamais → 42,9 min · 3 · 24,0 | 25,8 min · 1 · 27,0 → 25,8 min · 4 · 30,8 | 18,8 min · 1 · 22,0 → 18,8 min · 6 · 33,7 |
| 12 tourelles, tech 2 | Conquérant | jamais → jamais | jamais → 23,2 min · 16 · 15,9 | jamais → 12,0 min · 18 · 20,6 | jamais → 8,2 min · 21 · 23,0 |
| 12 tourelles, tech 2 | Équilibré | jamais → jamais | jamais → 33,8 min · 13 · 20,0 | jamais → 18,0 min · 16 · 24,4 | jamais → 13,5 min · 17 · 28,7 |
| 12 tourelles, tech 2 | Technocrate | jamais → jamais | jamais → 44,2 min · 10 · 25,0 | 25,5 min · 13 · 29,2 → 22,5 min · 13 · 28,9 | 23,2 min · 14 · 32,4 → 16,5 min · 14 · 31,9 |
| 12 tourelles, tech 2 | Bâtisseur | jamais → jamais | jamais → 42,9 min · 3 · 24,0 | 26,2 min · 1 · 28,0 → 25,8 min · 4 · 30,8 | 24,0 min · 1 · 28,0 → 18,8 min · 6 · 33,7 |

Rivale de défense 30 (configurations ajoutées après vérification ; le technocrate et le bâtisseur ne peuvent
pas l'attaquer). Après correction, 4 personnalités × 4 niveaux :

| Base | Personnalité | Facile | Normal | Difficile | Impitoyable |
|---|---|---|---|---|---|
| 1 tourelle, tech 0 | Conquérant | 30,0 min · 9 · 11,1 | 20,0 min · 7 · 29,4 | 12,0 min · 11 · 29,5 | 8,2 min · 18 · 22,6 |
| 1 tourelle, tech 0 | Équilibré | 47,0 min · 4 · 24,0 | 30,0 min · 6 · 29,7 | 18,0 min · 10 · 31,6 | 13,5 min · 13 · 32,0 |
| 1 tourelle, tech 0 | Technocrate | 56,2 min · 2 · 21,0 | 37,5 min · 3 · 29,0 | 22,5 min · 4 · 33,8 | 16,5 min · 7 · 38,0 |
| 1 tourelle, tech 0 | Bâtisseur | 64,3 min · 1 · 15,0 | 42,9 min · 3 · 24,0 | 25,8 min · 4 · 30,8 | 18,8 min · 6 · 33,7 |
| 3 tourelles, tech 0 | Conquérant | 30,0 min · 4 · 27,2 | 20,0 min · 7 · 29,4 | 12,0 min · 10 · 29,2 | 8,2 min · 16 · 28,1 |
| 3 tourelles, tech 0 | Équilibré | jamais | 30,0 min · 6 · 29,7 | 18,0 min · 9 · 32,4 | 13,5 min · 12 · 33,6 |
| 3 tourelles, tech 0 | Technocrate | jamais | 37,5 min · 3 · 29,0 | 22,5 min · 4 · 33,8 | 16,5 min · 7 · 38,0 |
| 3 tourelles, tech 0 | Bâtisseur | jamais | 42,9 min · 3 · 24,0 | 25,8 min · 4 · 30,8 | 18,8 min · 6 · 33,7 |

Lecture :
- **Facile est dissuadé dès 2 tourelles en tech 0** (les 4 personnalités ; correction du premier passage, qui
  disait « dès 3 ») et attaque une base d'une tourelle (1re attaque de 32,8 à 64,3 min selon la
  personnalité). En tech 2, le bâtisseur est déjà dissuadé à 6 tourelles (plus petite base essayée en tech 2), les
  autres dès 8. Cause : Facile ne
  fait jamais de siège et se replie aussitôt sur sa rivale. 2 tourelles ne sont pas une « forte défense » :
  **question au Directeur Créatif** (Facile dissuadé dès 2 tourelles en tech 0 : acceptable ?).
- Normal attaque toute base de 1 à 3 tourelles en tech 0 (les 4 personnalités) ; 6 tourelles en tech 0
  dissuadent encore le technocrate et le bâtisseur en Normal (armées visées 45 et 40).
- Difficile et Impitoyable attaquent les bases de 6 tourelles en tech 0 et de 8 tourelles en tech 2 (les 4
  personnalités). L'ordre strict (1re attaque plus tôt, plus d'attaques, plus grandes ; part plus grande pour
  une faction qui attaque aussi sa rivale) tient dans les 9 configurations à rivale de défense 10 × 4
  personnalités, parmi les niveaux qui attaquent.
- Avec une rivale de défense 30, les attaques exigées ont lieu et l'impasse est levée (au moins 2 attaques en
  Normal, Difficile et Impitoyable pour toutes les personnalités), mais l'ordre strict **ne tient pas** : 3 écarts sur les 2
  configurations, tous chez le conquérant (Facile 9 attaques contre 7 en Normal ; taille moyenne Impitoyable
  22,6 contre 29,5 en Difficile, et 28,1 contre 29,2). Cause : l'effectif envoyé est la garnison disponible ;
  la garnison accumulée pour une rivale difficile gonfle les attaques des niveaux où le joueur est moins
  souvent dû. Non corrigé (hors contrat), non exigé par le banc, imprimé par `pvp_test`.
- Les rivales reçoivent encore des attaques après la déclaration : au moins 4 en Normal et en Difficile, au
  moins 1 en Impitoyable, dans toutes les configurations à rivale de défense 10 (sauf le bâtisseur, qui n'en
  attaque jamais aucune).
- **Sensibilité (sonde du vérificateur, 32 bases × 4 personnalités × 4 niveaux)**, nombre d'écarts d'ordre
  strict ; les critères d'attaque du contrat tiennent dans toutes ces variantes :

  | Variante du modèle | Code IA0 | Premier passage IA0b | Après correction |
  |---|---|---|---|
  | 45 s par soldat (nominal) | 146 | 1 | 1 (tech 2, 16 tourelles, hors contrat) |
  | 30 s par soldat | — | 22 | 22 (taille moyenne du conquérant, Difficile contre Impitoyable) |
  | 60 s par soldat | 158 | 30 | 0 |
  | 90 s par soldat | 258 | 57 | 61 (nombre d'attaques ; 1re attaque du technocrate, Facile contre Normal) |
  | 30 % de survivants | — | 24 | 18 |
  | Rivale de défense 30 | 195 | 141 | 20 |

  L'ordre strict n'est donc **pas prouvé** hors du modèle nominal (45 s par soldat, rivale de défense 10).
  Le moteur réel produit plus lentement (E21 : Écarlate à 25 soldats à 20 min et 26 à 45 min) : au rythme
  probable du moteur réel, l'ordre du NOMBRE d'attaques n'est pas garanti. Le nombre d'attaques et leur
  taille moyenne sont relevés dans les journaux des scénarios moteur (`total : …`) pour le mesurer en réel.
- Partie pure à 4 factions (conquérant, technocrate, bâtisseur, équilibré), bases défendues : attaques
  jointes en Difficile (6 à 26 selon la configuration) et en Impitoyable (9 à 39), toutes dans la fenêtre
  d'une autre faction, contre la cible commune, aucune sous la taille minimale du niveau (la plus petite :
  16 soldats) ; aucune en Facile et en Normal. Dans cette partie à 4, un écart d'ordre : équilibré, 6
  tourelles en tech 0, taille moyenne 42,9 en Difficile contre 42,5 en Impitoyable.

Mesures en moteur simulé (`pvp_test`, tourelles qui tuent, base agrandie de 36 assembleurs pour ne pas être
rasée avant la fin). Ce banc lance la guerre avec **60 soldats au maximum** (`/fo-war start 2 60 …`), les
scénarios moteur avec 100 : avec 60, la taille minimale d'Azur (technocrate) contre le joueur est plafonnée
à 15 au lieu de 25 (d'où la taille moyenne de Normal sous celle d'IA0), et Azur ne peut pas attaquer sa
rivale (17 envoyables < 25) : la fin de l'impasse règle alors son rythme contre le joueur.

| Banc | Facile | Normal | Difficile | Impitoyable |
|---|---|---|---|---|
| 2 factions, 45 min, 1 tourelle : 1re attaque | 30,0 min | 20,0 min (IA0 : 20,0) | 12,0 min | 8,8 min |
| idem : nombre d'attaques | 1 | 4 | 6 (IA0 : 6) | 9 (IA0 : 8) |
| idem : taille moyenne | 11,0 | 16,8 (IA0 : 18,0) | 18,7 | 19,9 (IA0 : 19,4) |

**Mise à jour du 22/10 (suite V3-T des bancs hors jeu, RD_LOG E47).** Le moteur simulé donne désormais aux
prototypes intégrés leurs boîtes de collision vanilla (avant : 1×1). `pvp_test` reste à 596 OK, mais la taille
moyenne de la ligne ci-dessus devient **Normal 17,2 < Difficile 17,7 < Impitoyable 20,5** (le tableau garde
l'ancien modèle : 16,8 < 18,7 < 19,9). 5 lignes du journal de `pvp_test` diffèrent de l'ancien modèle ; les
autres lignes du tableau ne sont pas relevées à nouveau ici. Lequel des deux modèles est le plus proche du jeu
réel : rien ne le dit. Un état intermédiaire (modèle hybride du constructeur de la suite) donnait Normal 18,2 >
Difficile 18,0 : c'était un artefact des boîtes 1×1 par défaut, à ne pas retenir.

| Banc (moteur simulé, 4 factions) | Code IA0 | Après correction |
|---|---|---|
| Normal, 12 tourelles, 60 min (`pvp_test`) | 2 attaques (Azur seule, 1re à 46,5 min) ; Écarlate déclarée à 20 min, 0 attaque | 11 attaques de 4 factions (Écarlate 5), 1re à 22,8 min (défense estimée 96), 6 sièges, 1 dissuasion |
| Impitoyable, 6 tourelles, 40 min (`pvp_test`) | 12 attaques, 0 jointe | 16 attaques, 8 jointes, 8 fenêtres |
| `ia0-defendue` (Normal, 3 tourelles, 60 min, essai à blanc) | 11 OK, 0 ÉCHEC ; 9 attaques | 11 OK, 0 ÉCHEC ; 10 attaques (taille moyenne 20,7), 6 sièges |
| `ia0-defendue-impitoyable` (40 min, essai à blanc) | 12 OK, **2 ÉCHECS** (aucune fenêtre, aucune jointe) ; 12 attaques | 14 OK, 0 ÉCHEC ; 13 attaques dont 6 jointes (contre la cible commune), 7 fenêtres |
| `ia0-defendue-forte` (Normal, 12 tourelles, 60 min, essai à blanc) | 12 OK, **1 ÉCHEC** (Écarlate : 0 attaque) ; 7 attaques | 13 OK, 0 ÉCHEC ; 13 attaques, Écarlate 5 (1re au tick 74 103, défense 96) |

`ia0-defendue` n'est pas discriminant (l'ancien code le passe) ; `ia0-defendue-impitoyable` ne l'est que par
l'assaut coordonné, `ia0-defendue-forte` que par l'attaque d'Écarlate. Le moteur simulé fait monter les
factions en tech 2 vers 20 min, comme Écarlate en moteur réel (E21) : à 3 tourelles, la règle de force ne
lie plus, même avec l'ancien code.

Moteur réel :

| Banc | Facile | Normal | Difficile | Impitoyable |
|---|---|---|---|---|
| E33 (lot IA0, 4 factions, base d'une tourelle) | — | 1re à 20,0 min ; 3 attaques en 60 min ; 16 soldats | 1re à 12,0 min ; 6 attaques en 40 min ; 13 à 43 soldats | — |
| Lot IA0b (`ia0-defendue`, `ia0-defendue-impitoyable`, `ia0-defendue-forte`, et `ia0-defendue-forte` sur main en témoin négatif) | — | **non mesuré** | — | **non mesuré** |

Le nombre d'attaques entre niveaux est mesuré hors jeu ; en moteur réel, seule la 1re attaque l'est. Budget
de script : inchangé par construction (aucun calcul par tick ajouté, tout se fait dans la pensée du
commandant en O(1)), **non mesuré en moteur réel**.

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

## 12. Niveaux de bâtiments « façon Clash of Clans » : 15 époques (session 5, refait au lot V2, amélioration instantanée et calendrier X0 au lot V2c)

Directeur Créatif : « niveau Clash of Clans en termes d'échelons, de qualité de levels… pratiquement idle
game ». Réponses du 21/10, 18 h 07 : Q6 « oui c'est bien » (2 niveaux par époque, 30 niveaux) ; Q7 (les 15
époques d'OBJECTIFS §6 validées). Lot V2c (OBJECTIFS §4) : Q19 (amélioration instantanée), Q16 (condition du
centre), QX7 (« 60 h = ouverture de la Porte »), QX9 (recherche vanilla allégée), QX10 (une seule source pour
le calendrier ; passage du centre ≈ 10 % du budget). Données : `shared/levels/config.lua` (pur, testé) ;
prototypes : `prototypes/levels.lua` (point d'entrée), `prototypes/levels/common.lua` (tout le non-visuel et la
garde de l'interface), `prototypes/levels/style.lua` (style commun par époque) et un fichier de visuel par
famille ; runtime : `script/levels/` ; recherche vanilla : `data-final-fixes.lua`.

> **Tous les tableaux chiffrés de cette section sont CALCULÉS sur la configuration** par
> `lua5.2 tests/levels_test.lua --tables | tr -d '\r'` (ne pas les retoucher à la main : changer la config,
> relancer ; `tr` retire les retours chariot que `print` ajoute sous Windows, le fichier est en LF). La courbe
> elle-même (`value_mult`, `cc_value`, panier du centre) est recalculée par `lua5.2 tests/levels_test.lua
> --calibrate` sur le calendrier du scénario X0, puis reportée dans la config (des NOMBRES écrits : aucun calcul
> en flottants de logarithme ou de puissance au chargement du jeu, même résultat sur tous les clients).
> Correction V2c (vérification) : `--calibrate` part d'un **état de référence fixe** (panier V2 du centre,
> 260/130/130/50, valeurs d'époque à 0), jamais de la config en place ; `levels_test` vérifie que la config
> livrée EST sa sortie (aucune retouche à la main ; la version précédente n'était pas un point fixe).
>
> **État au 22/10 (lot V2c, après correction)** : prouvé **hors jeu** (levels_test 1 459 OK et **11 écarts
> connus** au contrat comptés à part, migration_test 29 OK, étape data 0 erreur, api_lint 0 erreur). **Non
> prouvé en moteur réel** : le diff du banc `content` (`content_test.lua`, 63 contrôles de niveaux, bilan
> attendu 212 OK) est livré à l'orchestrateur, qui seul passe le moteur (mise à jour : passé en moteur réel le
> 22/10 à 2 h 43, 212 OK, E38 ; 238 OK depuis le lot V3-T, 22/10 à 14 h 51, E44). Le modèle de durée de jeu repose sur
> des **hypothèses ❔** à valider en partie réelle. **QX10 n'est PAS tenu** (passage du centre sous 5 % du
> budget aux époques 5 à 14) et le calendrier de 52 h n'est tenu que par la base de référence complète (chemin
> le plus court : 3 h 27) : à trancher par le Directeur Créatif. Visuel : provisoire (E25), inchangé par V2c.

**Règles**
- **15 époques = 15 niveaux du centre de commandement** (l'hôtel de ville, 4×4, un par force) : le niveau du
  centre EST l'époque. Les 6 autres familles (mitrailleuse, tourelle laser, mur, foreuse électrique, four en
  acier, machine d'assemblage 2) ont **30 niveaux**, 2 par époque : les niveaux 2e-1 et 2e appartiennent à
  l'époque e ; le 1er change la silhouette, le 2e ajoute une pièce (visuel : lots V3). Le niveau 1 est le
  bâtiment vanilla (ou le centre de base).
- **Plafond** : un bâtiment ne dépasse jamais **2 × niveau du centre** (0.3.0 : centre + 1) ; le niveau n
  exige donc un centre ⌈n/2⌉. Sans centre, rien ne s'améliore. Le panneau du centre affiche ce plafond
  (`L.building_cap`).
- **Amélioration INSTANTANÉE (Q19, lot V2c)** : « si on a les ressources, on améliore, terminé ». Le coût est
  prélevé (stock du centre d'abord, puis inventaire du joueur) et le bâtiment est aussitôt remplacé par le
  niveau suivant en remplacement rapide moteur (contenu, recette, modules, munitions, fils conservés ; santé
  en proportion ; F39). Plus de durée, plus de bâtiment hors service, plus d'ouvriers ni de refus
  « no-builder » : autant d'améliorations qu'on peut en payer, dans le même tick (testé : 6 au centre 1).
  Les murs gardent le bouton « Toute la rangée » (`row`). Le réglage `fo-level-time-factor` est sans objet
  (diff de retrait proposé à l'intégrateur).
- **Condition du centre (Q16, lot V2c)** : pour passer le centre du niveau c au niveau c + 1, chaque famille
  dont la force possède AU MOINS UN bâtiment (tout niveau, vanilla compris) doit en avoir un au niveau
  min(30, 2c) (`L.cc_condition_level`, `L.cc_blockers`). Une famille non possédée ne bloque pas. Refus
  « cc-families » sans paiement ; le panneau du centre affiche le niveau visé et nomme les familles qui
  bloquent ; l'interface distante renvoie le motif. Recensement en jeu : `count_entities_filtered{ force, name,
  limit = 1 }` SANS zone, au plus 2 recherches par famille et par surface (une famille absente ou sous le
  niveau visé coûte un balayage de toute la surface), pour le CENTRE seulement. Correction V2c (vérification) :
  le panneau se rafraîchit toutes les 30 ticks ; le recensement est donc gardé **en cache par force** (dans
  `global`, même état sur tous les clients) : une construction le met à jour exactement, un retrait de bâtiment
  à niveaux l'invalide, il expire après 600 ticks, et chaque **décision** (touche U, bouton, interface
  distante) refait le recensement complet. Testé en moteur simulé : 10 aperçus = 1 recensement, panneau du
  centre ouvert 300 ticks = 0 recensement. **Coût d'un recensement en moteur réel sur une grande carte : non
  mesuré** (borné désormais à un par force et par 10 s pendant qu'un panneau du centre est ouvert, plus un par
  décision et par retrait suivi d'un rafraîchissement).
- **Paiement** : le stock du centre d'abord, puis l'inventaire du joueur (l'usine alimente le centre par
  convoyeurs : boucle « idle »). Testé (V2c) : centre à moitié approvisionné, le joueur ne paie que le
  complément ; un refus « no-resources » ne débite personne. Stockage du centre : 48 cases + 16 par niveau
  (272 au niveau 15). Un joueur n'ouvre et n'améliore que les bâtiments de SA force (le centre payeur est celui
  de la force du bâtiment) ; une rangée de murs ne s'étend pas aux murs d'une autre force (testé).
- **Place** : chaque coût tient dans **la moitié du coffre du centre qui le paie** (centre : le centre
  lui-même au niveau n - 1 ; famille : le plus petit centre qui l'autorise, ⌈n/2⌉), calculé avec les vraies
  tailles de pile (`L.stack_size`, relevées sur l'étape data). Testé à chaque niveau ; le pire coût est le
  centre 12 → 13 (100 cases sur 224, 45 %).

**Courbe de coûts PAR ÉPOQUE** (principe : « la croissance se fait par époque, nouveau matériau requis, pas
par exposant »)
- **Quelle monnaie** : une amélioration se paie avec le **matériau de l'époque pendant laquelle on la fait**.
  Familles : l'époque du niveau visé. Centre : passer au niveau n OUVRE l'époque n et se paie avec la monnaie
  de l'époque n - 1 (le centre est la porte de l'époque suivante).
- **Combien** : coût = panier de base + valeur d'époque, le tout × `L.TEAM_FACTOR` (1 aujourd'hui).
  - Panier de base (époque 1 : fer, cuivre, pierre, engrenages, circuits) : **croissance linéaire**,
    × (1 + 0,15 (n - 2)). Paniers des 6 familles inchangés depuis V2 (mitrailleuse : 6 fer, 3 engrenages,
    3 cuivre au niveau 2). Panier du centre recalibré (V2c) : **310 fer, 160 cuivre, 160 briques, 60 circuits**,
    exactement ce que le joueur paie au passage 1 → 2 (940 u ; V2 : 775 u). La version livrée avant correction
    écrivait 315/155/155/60 (930 u) mais faisait payer 320/160/160/60 (arrondi), soit 960 u.
  - Valeur d'époque des familles = `epoch_value` de la famille × `value_mult` de l'époque, × 1,25 au 2e
    niveau d'une époque. Valeur d'époque du centre = `cc_value` de l'époque qui paie le passage (nouveau
    champ V2c ; V2 : `epoch_value` 150 × `value_mult`). Elle se paie à **60 % en matériau de l'époque** et 40 %
    en matériau de l'époque précédente (murs : 100 % matériau de l'époque ; époque 2 : l'acier paie 100 %).
    Le matériau de l'époque est toujours exigé, au moins 1 ; celui de l'époque précédente seulement si sa
    part vaut au moins un demi-objet.
  - Conversion valeur → quantité : valeur ÷ valeur unitaire de l'objet, arrondi lisible (entier sous 20,
    multiple de 5 sous 100, de 10 au-delà). Règle de monotonie : si l'arrondi rendait un niveau moins cher
    (en valeur) que le précédent, on ajoute du matériau de l'époque jusqu'à le dépasser.
  - Les quantités restent bornées (**au plus 2 000 objets d'une sorte**, testé : les moteurs électriques du
    centre 14 l'atteignent) parce que le matériau change à chaque époque. La vraie contrainte est la **place**.
- **Recalibrage V2c** : le temps d'attente ne rythme plus le jeu, ce sont les COÛTS. `value_mult` passe de
  1 → 1 460 (V2) à 1,43 → 7 070 (× 4,8 à l'époque 15 : le budget X0 est 4,8 fois celui du modèle V2), et le
  centre reçoit sa propre table `cc_value`. Méthode (`--calibrate`, depuis l'état de référence fixe) : (1) le
  panier V2 du centre est mis à l'échelle pour combler le budget des niveaux de l'époque 1 que les paniers des
  bâtiments laissent, puis arrondi comme le joueur le paie ; (2) chaque passage du centre vise
  10 % du budget de l'époque, borné par la place (45 % du coffre payeur, au plus 2 000 objets d'une sorte) et
  par la croissance stricte de son coût (chaque borne vaut au plus 97 % de la suivante) ; (3) aux époques 2
  à 15, `value_mult` (+ 2 % au moins d'une époque à l'autre) comble le reste du budget des niveaux ; si les
  bâtiments le dépassent déjà au plus petit `value_mult` permis (époque 3 : fours et machines arrivent et
  rattrapent 3 niveaux, la monotonie interdit de faire moins cher que l'époque 2), le passage du centre cède
  la différence.
- **Valeur unitaire** (unités de matière brute : 1 = une plaque de fer ; 10 unités de fluide = 1 ; même unité
  que le « MU » du scénario X0), approximations d'après les recettes vanilla : plaque de fer 1, de cuivre 1,
  brique 2, engrenage 2, circuit 2,5, acier 5, moteur 9, plastique 3, tungstène 4, batterie 9, cristal 3,
  baril de méthane 10, uranium 238 14, processeur 75, structure légère 45, moteur électrique 16, uranium 235
  45, unité de contrôle de fusée 150, pack de science spatiale 250. Une seule valeur par objet (testé).

**Table d'indirection « matériau d'époque → objet »** (`L.epoch_materials`) : inchangée par V2c. Le jeu reste
valide AUJOURD'HUI (chaque objet de coût existe, vérifié hors jeu sur l'étape data et, au chargement, par le
runtime qui journalise `[FO-LEVELS]`). Les époques 11 à 15 utilisent des **remplaçants provisoires** existants
(le scénario X0 propose ses monnaies : `X.currencies`, diff au §10 du scénario). Pour brancher un matériau
livré, l'intégrateur change `item` et `value` de la ligne de l'époque, ajoute sa pile à `L.stack_size`, puis
relance `--calibrate` (les bornes de place du centre changent avec la densité de la monnaie).

**Modèle de durée de jeu (lot V2c)**. Le calendrier a UNE source, le scénario approuvé : `L.target` en RECOPIE
les valeurs au chargement de la config (durée `X.epoch_hours` : 0,5 h × k, au plus 7 h ; débit moyen
`X.rate_avg` : de 2,25 à 10 511 u/s ; budget `X.budget` = débit moyen × durée ; heure de la Porte), sans courbe
propre ; la copie est comparée par la garde de dress comme le reste de la config (correction V2c : avant, la
config relisait X à chaque appel, et un dress qui modifiait X la changeait). L'ancienne courbe de V2
(0,5 × 1,261^(e-1) h, production de 2 à 1 200 u/s) n'existe plus. Hypothèses conservées (à valider en partie
réelle) :
- 30 % de la production consacrée aux niveaux (centre compris ; X0 : la recherche en prend 35 %) ;
- base de référence de V2 : mitrailleuses 4 + 3 (e-1), tourelles laser à partir de l'époque 6 (4 + 4 (e-6)),
  murs 20 + 30 (e-1), foreuses 6 + 8 (e-1), fours et machines d'assemblage à partir de l'époque 3 ; chaque
  bâtiment ajouté rattrape aussi les niveaux précédents. Elle suit le jeu d'AUJOURD'HUI (murs et foreuses dès
  l'époque 1) ; le re-rangement prévu par X0 (`X.v2_family_epochs` : murs et fours à l'époque 2, foreuses à
  l'époque 3) la changera, et la courbe sera à recalibrer ;
- `L.TEAM_FACTOR` (lot IA1, « recalibrer les coûts des époques sur joueur + équipe ») : production de la force
  rapportée à celle du joueur seul ; tous les coûts sont multipliés par ce facteur et la production du modèle
  aussi. **1 aujourd'hui (joueur seul)**. Testé à 2 : coûts × 2,00 à 2,01 (2,004 sur l'ensemble des niveaux,
  mesure de la vérification ; le contrôle porte sur le laser 30), durées à 15 % près par époque (les
  planchers des époques 2 à 4, « au moins 1 objet » et monotonie, ne doublent pas), total à 2 % près ; mais 9
  passages du centre (vers les niveaux 5, 6, 8, 9, 10 et 12 à 15) sortent alors de la règle de place : le lot
  IA1 relancera `--calibrate` avec son facteur.

La **durée impliquée** est le RÉSULTAT : le temps de payer la dépense de la base de référence avec 30 % de la
production (même méthode que V2, sans le terme des ouvriers, qui n'existent plus). Avec la courbe V2c, chaque
époque est à **± 1,5 %** de sa durée X0 (testé ± 5 %), l'époque 15 est atteinte à **52 h 36** (X0 : 52 h 30,
testé ± 2 %) et la Porte ouverte à **59 h 35** (X0 : 59 h 30, QX7 « 60 h = ouverture de la Porte » ; testé
± 2 %). Production × 0,7 : 85 h ; × 1,3 : 46 h. **Non prouvé en partie réelle.** **Limite (vérification
V2c)** : ces heures supposent que le joueur monte TOUTE la base de référence. Rien ne l'y oblige : le chemin le
plus court (centre + un bâtiment de chaque famille possédée monté au niveau visé, condition Q16) atteint le
centre 15 en **3 h 27** avec 30 % de la production X0 (1 h 02 avec 100 % ; centre seul : 2 h 20), contre
52 h 30 au calendrier ; les époques 7 à 14 s'y franchissent en 6 à 10 min chacune (époques 1 à 6 : 14 à 34 min). Écart connu au contrat
QX7 (compté par `levels_test`), lié à QX10 ci-dessous.

**Passage du centre (QX10) : NON CONFORME au-delà de l'époque 4, borné par la règle de place.** Contrat : le
passage du centre pèse environ 10 % du budget de l'époque. Obtenu : 23,2 % (époque 1 : le centre comble le budget
que les paniers des bâtiments laissent), 9,95 % (2), 5,6 % (3 : il cède aux fours et machines), 7,4 % (4), puis
3,35 %, 1,57 %, 0,76 %, 0,37 %, 0,35 %, 0,52 %, 0,27 %, 0,14 %, 0,11 % et 0,13 % (époques 5 à 14) : à l'époque
14, 192 820 u pour 14,5 M u visés (75 fois moins). `levels_test` compte ces 10 époques comme **écarts connus**
(ni OK, ni échec) ; le contrôle « au plus près de la borne de place » ne vérifie que le calibrage, pas le
contrat. Cause, chiffrée par `--calibrate` : le passage vers n doit tenir dans 45 % du coffre du centre n - 1
avec des monnaies peu denses (baril de méthane à 100 u par case, cristal à 150) ; seul, le passage 8 → 9 tient
au plus 8 310 u (10 % du budget : 221 575 u ; même à 50 % du coffre et sans plafond de quantité : 9 300 u,
0,42 %), et comme un passage ne coûte jamais moins que le précédent, les passages 4 → 5 à 8 → 9 restent sous
cette borne (de 7 383 à 8 280 u, + 3 % par époque). Le centre ne pèse que 0,29 % de la dépense totale (V2 :
0,9 %) ; avec la condition Q16, le chemin le plus court vers le centre 15 coûte 0,96 % de la dépense de la base
de référence. L'écart est STRUCTUREL avec les monnaies d'aujourd'hui. Remèdes possibles, **à trancher par le
Directeur Créatif** : (a) un objet dense propre au passage (le « Codex k » du scénario X0, qui en porterait la
valeur) ; (b) un remplaçant dense provisoire, comme pour les monnaies 11 à 15, en attendant les monnaies de X0
(biopolymère à 400 u par case à l'époque 8) ; (c) une règle de place assouplie pour le seul centre, ou un
coffre plus grand (+ 32 cases par niveau au lieu de 16 doublerait la borne). Option partielle chiffrée par la
vérification, non appliquée (elle rend le coût du centre non monotone et ne règle pas les époques 8 à 14) :
lever la croissance stricte du coût du centre aux époques 4 à 7 donnerait 10 / 6,5 / 4,4 / 1,1 % au lieu de
7,4 / 3,3 / 1,6 / 0,76 %.

**QX9 : recherche vanilla allégée (lot V2c)**. `data-final-fixes.lua` multiplie le nombre d'unités de chaque
technologie vanilla par `X.VANILLA_UNIT_SCALE` de son époque (0,9 ; 0,15 ; 0,07 ; 0,04 aux époques 1 à 4 ;
0,15 à l'époque 6 ; 0,25 à l'époque 10 ; 1 ailleurs), arrondi, au moins 1. Époque d'une technologie (règle
du lot X0, `tests/epochs_test.lua`) : re-rangement explicite (`X.vanilla_tech_epochs`), sinon la plus haute
époque des recettes qu'elle débloque (`X.base_recipe_epochs`), sinon celle de ses packs. Les technologies du
mod (« fo- ») et les recherches infinies ne changent pas. Résultat sur les 183 technologies vanilla de 1.1.91 à
nombre d'unités fixe (192 en tout, dont 9 infinies ; levels_test exécute `data-final-fixes.lua` sur
`data/base/prototypes/technology.lua`) : **170 allégées**
(époque 1 : 7, 2 : 18, 3 : 21, 4 : 47, 6 : 24, 10 : 53) ; exemples : automatisation 10 → 1, acier 50 → 8,
pétrole 100 → 4, logistique 20 → 18, pack utilitaire 100 → 25 ; char (époque 5) 250 inchangé.
**Correction V2c (vérification, étape data réelle)** : `base/data-updates.lua` rattache à `fluid-handling` les
recettes de baril de CHAQUE fluide, dont le méthane du mod, rangé à l'époque 8 par X0 ; `fluid-handling` passait
donc à l'époque 8 et gardait 50 unités (169 technologies allégées en jeu, et non 170). Ces recettes générées
(`fill-<fluide>-barrel`, `empty-<fluide>-barrel` ; `L.generated_barrel`) ne rangent plus la technologie :
`fluid-handling` reste à l'époque 4 (X0), 50 → 2 unités. `levels_test` le vérifie désormais sur l'étape data
RÉELLE (il rejoue le harness : `fluid-handling` à 2 unités, journal
`[FO-LEVELS] recherche vanilla allégée (QX9) : 170 technologie(s)`), et `content_test` contrôle
`fluid-handling` (2) et `mining-productivity-1` (250 → 10, re-rangée par X0) en moteur réel.
**Part du budget (mesure V2c)** : la recherche vanilla allégée, payée avec les packs VANILLA de chaque
technologie (valeurs en MU du modèle X0 : rouge 2,5, vert 6,2, militaire 22,8, bleu 19,9, production 69,7,
utilitaire 32, espace 105,5), prend **17,8 / 15,9 / 14,1 / 13,2 %** du budget X0 des époques 1 à 4 (X0 vise
17,5 % avec ses fenêtres de packs), puis 5,7 % (5), 10,2 % (6), 4,8 % (7), 0,07 % (8), 2,6 % (9), 7,1 % (10).
Elle n'est donc pas « presque gratuite » aux époques 2 à 4 : 13 à 16 % du budget, un peu moins que dans X0
(ses fenêtres comptent des packs plus chers, militaire compris). Aux époques 5 et suivantes, le reste de la
recherche visée par X0 (35 % du budget) dépend des technologies nouvelles de X0, pas encore en jeu. Limite :
en jeu, les packs vanilla ne suivent PAS encore la fenêtre de packs du scénario X0 (lots X1 à X15). Une
technologie d'un autre mod (sans préfixe « fo- ») serait traitée comme une vanilla.

**Statistiques** (niveau 1 = valeur vanilla × facteur ; tableaux complets plus bas ; inchangées par V2c)
- mêmes formules qu'en 0.3.0, prolongées jusqu'au niveau 30 : PV × (1 + 0,15 (n-1)), portée + 0,25 / niveau,
  rotation + 5 % / niveau, minage + 10 % / niveau (énergie + 7 %), vitesse des fours et machines + 8 % /
  niveau (énergie + 6 %) ; centre : PV × (1 + 0,2 (n-1)), + 16 cases / niveau ;
- **dégâts des tourelles dégressifs** : + 8 % par niveau jusqu'au niveau 10, puis + 2 % par niveau : × 2,12
  au niveau 30. En DPS, la mitrailleuse 30 vaut 0,94 fois la tourelle lourde du mod et la tourelle laser 30
  1,06 fois la tourelle laser lourde (option A de Q14, acceptée) ;
- **énergie de la tourelle laser** : l'énergie par tir et le tampon croissent de 4 % par niveau ; les dégâts
  par joule du niveau 30 restent à ± 10 % du niveau 1, et le tampon contient toujours un tir (testé) ;
- **murs** : PV × (1 + 0,5 (n-1)), 350 → 5 425 PV ; réduction fixe physique et explosion + 0,5 par niveau ;
- **foreuse, four, machine** : l'énergie croît moins vite que la vitesse ;
- toutes les statistiques sont strictement croissantes et au plus × 16 entre le niveau 1 et le dernier
  (testé).

**Compatibilité des sauvegardes** (prouvée en moteur simulé seulement : `tests/migration_test.lua` pour 0.3.0,
`tests/levels_test.lua` pour 0.4.0)
- Les noms `fo-command-center` et `fo-lvl-<famille>-<n>` gardent leur sens : même famille, même niveau.
- **Chantiers en cours (0.3.0 et 0.4.0) : ACHEVÉS au chargement** (décision V2c). Leur coût est déjà payé ;
  Q19 dit « si on a les ressources, on améliore, terminé » : le joueur retrouve le niveau acheté. Annuler et
  rembourser aurait versé le coût entier dans un coffre peut-être plein (objets au sol) et obligé à relancer
  à la main. Le chantier d'un centre est achevé lui aussi, SANS la condition Q16, qui n'existait pas quand il
  a été payé. Bâtiment disparu : chantier perdu (compté). Cible invalide (niveau déjà atteint, ou au-delà du
  maximum) : bâtiment remis en service, chantier perdu (testé depuis la correction V2c). Les barres de progression sont effacées, les
  ouvriers et le réglage de durée enregistrés sont retirés. Fait dans `on_configuration_changed`, et par un
  filet toutes les 30 ticks si la sauvegarde est rechargée sans changement de version (testé dans les deux
  cas). Limite : un bâtiment en chantier démonté entre le chargement et le filet (30 ticks au plus, 0 avec un
  changement de version) perd son chantier sans remboursement (V2 : moitié rendue).
- Réparation défensive conservée : centre disparu oublié, PV au-dessus du nouveau maximum ramenés au maximum
  (`Levels.clamp_health` : murs 0.3.0, Q15).
- L'interface distante de 0.4.0 reste appelable : `levels_time_factor` est sans effet, `levels_status` renvoie
  0 ouvrier et 0 chantier (testé) ; diff de nettoyage proposé pour `script/remote.lua`.

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
**Correction V2c (sonde probe_x de la vérification)** : la config V2c lisait le scénario X0 à l'appel
(`X.VANILLA_UNIT_SCALE` en data-final-fixes, le calendrier) ; un `dress` qui écrivait
`require("shared.content.epochs").VANILLA_UNIT_SCALE[3] = 3` était ACCEPTÉ et `automation` passait de 1 à
30 unités. Désormais la config recopie au chargement tout ce qu'elle lit dans X (`L.VANILLA_UNIT_SCALE`,
`L.target`), comparé avec le reste de `L`, et la garde compare EN PLUS le scénario X0 entier à la fermeture de
chaque famille (refus « a modifié le scénario X0 X.… », qui nomme la famille). Coût mesuré (harness, 5 passes,
copie instrumentée hors dépôt) : 0,002 à 0,006 s pour la copie, 0,014 à 0,015 s pour les 7 comparaisons (X
compte environ 16 000 nœuds, 23 fois la config : le comparer après chaque `dress` coûterait de l'ordre de
0,8 s, d'où la comparaison par famille).
Tests hors jeu (`levels_test`) : 85 cas d'agent V3 (V2c : + 2, `cc_value` et `L.TEAM_FACTOR` ; correction V2c :
+ 2, scénario X0 modifié par `require`, valeur et fonction) (15 acceptés, 70 refusés, motif vérifié pour chaque refus,
dont 12 cas de la contre-vérification : copie déclarée modifiée après `edit` (jeu, nom, nom affiché), `icons`
fautif, famille suivante) et 46 sondes, une par clé de `L`, toutes refusées avec leur chemin ; 4 mutants de la garde
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
  sa quantité baisse d'un niveau au suivant dans **37 cas** (compté par `levels_test` ; V2 : 49), surtout au
  centre (par exemple centre 6, plastique 1 200 → 810). La valeur totale, elle, croît toujours (testé).
- **Passage du centre (QX10) NON CONFORME au-delà de l'époque 4**, et **calendrier de 52 h tenu seulement par la
  base de référence complète** (chemin le plus court : 3 h 27) : voir plus haut (borne de place, monnaies peu
  denses ; remèdes à trancher par le Directeur Créatif). `levels_test` compte 11 écarts connus.
- **Le pire coût occupe 45 % du coffre payeur** (centre 12 → 13 : 100 cases sur 224 ; V2 : 38 %) : le centre
  est calibré au plus près de la borne de place ; il reste 5 % de marge sous la règle (50 %).
- Les remplaçants des époques 13 (uranium 235 : enrichissement de Kovarex) et 15 (pack de science spatiale :
  une fusée lancée) sont des portes technologiques à confirmer en partie réelle.
- Coût d'UN recensement de la condition Q16 (`count_entities_filtered` sans zone, centre seulement) et coût
  script des niveaux non mesurés au banc épinglé (H-L1). Le cache par force borne le nombre de recensements
  (voir « Condition du centre ») ; une mesure en moteur réel sur une grande carte (d4-geant), panneau du centre
  ouvert, reste à faire. Les chantiers n'existent plus : le passage toutes les 30 ticks ne coûte plus rien hors
  du filet des sauvegardes 0.4.0 (`next` sur une table vide).
- Un bâtiment est remplacé par une NOUVELLE entité à chaque niveau (remplacement rapide) : monter de 28 à 30
  d'affilée fait deux remplacements et deux célébrations dans le même tick (voulu : Q19).

#### Les 15 époques et la table d'indirection des matériaux

| Époque | Thème | Matériau voulu | Objet en jeu aujourd'hui | Valeur unitaire (u) | Pile | Valeur d'époque des bâtiments (value_mult) | Monnaie du passage du centre payé dans l'époque (cc_value, u) | Centre (niveau) | Niveaux des bâtiments | Condition du passage suivant (Q16) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Pionnier | fer, cuivre, pierre (panier de base) | panier de base | — | — | 0 | panier seul | 1 | 1-2 | un bâtiment de chaque famille possédée au niveau 2 |
| 2 | Forge | acier | `steel-plate` | 5 | 100 | 1,43 | 407 | 2 | 3-4 | un bâtiment de chaque famille possédée au niveau 4 |
| 3 | Vapeur | moteur (mécanique de l'ère vapeur) | `engine-unit` | 9 | 50 | 1,46 | 1 050 | 3 | 5-6 | un bâtiment de chaque famille possédée au niveau 6 |
| 4 | Pétrole | plastique | `plastic-bar` | 3 | 100 | 4,5 | 6 000 | 4 | 7-8 | un bâtiment de chaque famille possédée au niveau 8 |
| 5 | Volcan | plaque de tungstène | `fo-tungsten-plate` | 4 | 100 | 15,5 | 6 060 | 5 | 9-10 | un bâtiment de chaque famille possédée au niveau 10 |
| 6 | Électricité | batterie | `battery` | 9 | 200 | 29,2 | 6 160 | 6 | 11-12 | un bâtiment de chaque famille possédée au niveau 12 |
| 7 | Cristal | cristal de résonance | `fo-resonance-crystal` | 3 | 50 | 57,9 | 6 290 | 7 | 13-14 | un bâtiment de chaque famille possédée au niveau 14 |
| 8 | Marais | méthane (baril) | `fo-methane-barrel` | 10 | 10 | 110 | 6 380 | 8 | 15-16 | un bâtiment de chaque famille possédée au niveau 16 |
| 9 | Atome | uranium | `uranium-238` | 14 | 100 | 204 | 14 100 | 9 | 17-18 | un bâtiment de chaque famille possédée au niveau 18 |
| 10 | Haute technologie | processeur | `processing-unit` | 75 | 100 | 371 | 46 000 | 10 | 19-20 | un bâtiment de chaque famille possédée au niveau 20 |
| 11 | Titane | plaque de titane | `low-density-structure` **provisoire** (voulu : `fo-titanium-plate`) | 45 | 10 | 675 | 47 300 | 11 | 21-22 | un bâtiment de chaque famille possédée au niveau 22 |
| 12 | Supraconducteurs | supraconducteur (terres rares) | `electric-engine-unit` **provisoire** (voulu : `fo-superconductor`) | 16 | 50 | 1 250 | 48 700 | 12 | 23-24 | un bâtiment de chaque famille possédée au niveau 24 |
| 13 | Fusion | hélium-3 | `uranium-235` **provisoire** (voulu : `fo-helium-3`) | 45 | 100 | 2 270 | 80 100 | 13 | 25-26 | un bâtiment de chaque famille possédée au niveau 26 |
| 14 | Orbite | fragment de météorite | `rocket-control-unit` **provisoire** (voulu : `fo-meteorite`) | 150 | 10 | 4 140 | 190 000 | 14 | 27-28 | un bâtiment de chaque famille possédée au niveau 28 |
| 15 | Légende | matière exotique | `space-science-pack` **provisoire** (voulu : `fo-exotic-matter`) | 250 | 2 000 | 7 070 | — | 15 | 29-30 | — |

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

#### Modèle de durée de jeu (calendrier du scénario X0 ; hypothèses de `L.target`, à valider en partie réelle)

| Époque | Durée X0 | Atteinte X0 | Débit moyen X0 (u/s) | Budget de l'époque X0 (u) | Budget des niveaux (30 %) | Dépense de la base de référence (u) | Dépense / budget des niveaux | Passage du centre suivant (u) | Part du budget de l'époque | Durée impliquée | Cumul impliqué |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 30 min | 0 h | 2 | 4 054 | 1 216 | 1 222 | 1 | 940 | 23,18 % | 30 min 08 s | 30 min 08 s |
| 2 | 1 h 00 | 30 min | 4 | 14 826 | 4 448 | 4 464 | 1 | 1 475 | 9,95 % | 1 h 00 | 1 h 30 |
| 3 | 1 h 30 | 1 h 30 | 8 | 40 662 | 12 199 | 12 202 | 1 | 2 285 | 5,62 % | 1 h 30 | 3 h 00 |
| 4 | 2 h 00 | 3 h 00 | 14 | 99 130 | 29 739 | 29 860 | 1 | 7 383 | 7,45 % | 2 h 00 | 5 h 00 |
| 5 | 2 h 30 | 5 h 00 | 25 | 226 561 | 67 968 | 67 917 | 1 | 7 588 | 3,35 % | 2 h 29 | 7 h 30 |
| 6 | 3 h 00 | 7 h 30 | 46 | 497 094 | 149 128 | 147 996 | 0,99 | 7 825 | 1,57 % | 2 h 58 | 10 h 29 |
| 7 | 3 h 30 | 10 h 30 | 84 | 1 060 369 | 318 111 | 320 788 | 1,01 | 8 065 | 0,76 % | 3 h 31 | 14 h 01 |
| 8 | 4 h 00 | 14 h 00 | 154 | 2 215 750 | 664 725 | 672 400 | 1,01 | 8 280 | 0,37 % | 4 h 02 | 18 h 03 |
| 9 | 4 h 30 | 18 h 00 | 281 | 4 557 694 | 1 367 308 | 1 364 437 | 1 | 16 055 | 0,35 % | 4 h 29 | 22 h 33 |
| 10 | 5 h 00 | 22 h 30 | 514 | 9 259 223 | 2 777 767 | 2 778 380 | 1 | 48 310 | 0,52 % | 5 h 00 | 27 h 33 |
| 11 | 5 h 30 | 27 h 30 | 941 | 18 622 549 | 5 586 765 | 5 610 201 | 1 | 49 455 | 0,27 % | 5 h 31 | 33 h 04 |
| 12 | 6 h 00 | 33 h 00 | 1 720 | 37 144 935 | 11 143 481 | 11 221 590 | 1,01 | 51 110 | 0,14 % | 6 h 02 | 39 h 07 |
| 13 | 6 h 30 | 39 h 00 | 3 144 | 73 575 568 | 22 072 670 | 22 060 978 | 1 | 82 795 | 0,11 % | 6 h 29 | 45 h 37 |
| 14 | 7 h 00 | 45 h 30 | 5 749 | 144 873 923 | 43 462 177 | 43 409 954 | 1 | 192 820 | 0,13 % | 6 h 59 | 52 h 36 |
| 15 | 7 h 00 | 52 h 30 | 10 511 | 264 887 907 | 79 466 372 | 79 293 152 | 1 | — | — | 6 h 59 | 59 h 35 |

#### Sensibilité de la durée impliquée totale (15 époques)

| Production supposée | Durée impliquée totale |
|---|---|
| × 0,7 | 85 h 08 |
| × 1 | 59 h 35 |
| × 1,3 | 45 h 50 |

Chemin « centre seul » (centre 1 → 15) : 484 385 u, soit 0,29 % de la dépense de la base de référence. Avec la condition Q16 (un bâtiment de chaque famille possédée monté jusqu'au niveau visé, ici les 6 familles jusqu'au niveau 28) : 1 602 362 u, soit 0,96 % (V2, sans condition : 0,9 %).

En heures (chemin le plus court, payé au débit moyen X0 de chaque époque) : centre 15 atteint en **3 h 27** avec 30 % de la production X0 et les 6 familles possédées (1 h 02 avec 100 % ; centre seul, aucune famille possédée : 2 h 20), pour **52 h 30** au calendrier X0. Le calendrier n'est tenu que si le joueur monte toute la base de référence : rien ne l'y oblige (écart connu, compté par `levels_test`).

#### Centre de commandement (15 niveaux)

| Niveau | Époque | PV | cases | Coût du passage à ce niveau | Valeur (u) | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|
| 1 | 1 Pionnier | 3 000 | 48 | — | — | — |
| 2 | 2 Forge | 3 600 | 64 | 310 iron-plate, 160 copper-plate, 160 stone-brick, 60 electronic-circuit | 940 | 9 / 48 |
| 3 | 3 Vapeur | 4 200 | 80 | 360 iron-plate, 180 copper-plate, 180 stone-brick, 70 electronic-circuit, 80 steel-plate | 1 475 | 10 / 64 |
| 4 | 4 Pétrole | 4 800 | 96 | 400 iron-plate, 210 copper-plate, 210 stone-brick, 80 electronic-circuit, 70 engine-unit, 85 steel-plate | 2 285 | 14 / 80 |
| 5 | 5 Volcan | 5 400 | 112 | 450 iron-plate, 230 copper-plate, 230 stone-brick, 85 electronic-circuit, 1 200 plastic-bar, 270 engine-unit | 7 383 | 30 / 96 |
| 6 | 6 Électricité | 6 000 | 128 | 500 iron-plate, 260 copper-plate, 260 stone-brick, 95 electronic-circuit, 910 fo-tungsten-plate, 810 plastic-bar | 7 588 | 31 / 112 |
| 7 | 7 Cristal | 6 600 | 144 | 540 iron-plate, 280 copper-plate, 280 stone-brick, 110 electronic-circuit, 410 battery, 620 fo-tungsten-plate | 7 825 | 23 / 128 |
| 8 | 8 Marais | 7 200 | 160 | 590 iron-plate, 300 copper-plate, 300 stone-brick, 110 electronic-circuit, 1 260 fo-resonance-crystal, 280 battery | 8 065 | 41 / 144 |
| 9 | 9 Atome | 7 800 | 176 | 640 iron-plate, 330 copper-plate, 330 stone-brick, 120 electronic-circuit, 380 fo-methane-barrel, 850 fo-resonance-crystal | 8 280 | 71 / 160 |
| 10 | 10 Haute technologie | 8 400 | 192 | 680 iron-plate, 350 copper-plate, 350 stone-brick, 130 electronic-circuit, 600 uranium-238, 560 fo-methane-barrel | 16 055 | 78 / 176 |
| 11 | 11 Titane | 9 000 | 208 | 730 iron-plate, 380 copper-plate, 380 stone-brick, 140 electronic-circuit, 370 processing-unit, 1 310 uranium-238 | 48 310 | 35 / 192 |
| 12 | 12 Supraconducteurs | 9 600 | 224 | 780 iron-plate, 400 copper-plate, 400 stone-brick, 150 electronic-circuit, 630 low-density-structure, 250 processing-unit | 49 455 | 83 / 208 |
| 13 | 13 Fusion | 10 200 | 240 | 820 iron-plate, 420 copper-plate, 420 stone-brick, 160 electronic-circuit, 1 830 electric-engine-unit, 430 low-density-structure | 51 110 | 100 / 224 |
| 14 | 14 Orbite | 10 800 | 256 | 870 iron-plate, 450 copper-plate, 450 stone-brick, 170 electronic-circuit, 1 070 uranium-235, 2 000 electric-engine-unit | 82 795 | 71 / 240 |
| 15 | 15 Légende | 11 400 | 272 | 910 iron-plate, 470 copper-plate, 470 stone-brick, 180 electronic-circuit, 760 rocket-control-unit, 1 690 uranium-235 | 192 820 | 114 / 256 |

#### Mitrailleuse (30 niveaux)

| Niveau | Époque | PV | dégâts × | portée | Coût du passage à ce niveau | Valeur (u) | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 400 | 1 | 18 | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 460 | 1,08 | 18,25 | 6 iron-plate, 3 iron-gear-wheel, 3 copper-plate | 15 | 3 / 48 |
| 3 | 2 Forge (silhouette) | 520 | 1,16 | 18,5 | 7 iron-plate, 3 iron-gear-wheel, 3 copper-plate, 3 steel-plate | 31 | 4 / 64 |
| 4 | 2 Forge (+ pièce) | 580 | 1,24 | 18,75 | 8 iron-plate, 4 iron-gear-wheel, 4 copper-plate, 4 steel-plate | 40 | 4 / 64 |
| 5 | 3 Vapeur (silhouette) | 640 | 1,32 | 19 | 9 iron-plate, 4 iron-gear-wheel, 4 copper-plate, 2 engine-unit, 1 steel-plate | 44 | 5 / 80 |
| 6 | 3 Vapeur (+ pièce) | 700 | 1,4 | 19,25 | 10 iron-plate, 5 iron-gear-wheel, 5 copper-plate, 2 engine-unit, 2 steel-plate | 53 | 5 / 80 |
| 7 | 4 Pétrole (silhouette) | 760 | 1,48 | 19,5 | 11 iron-plate, 5 iron-gear-wheel, 5 copper-plate, 11 plastic-bar, 2 engine-unit | 77 | 5 / 96 |
| 8 | 4 Pétrole (+ pièce) | 820 | 1,56 | 19,75 | 11 iron-plate, 6 iron-gear-wheel, 6 copper-plate, 14 plastic-bar, 3 engine-unit | 98 | 5 / 96 |
| 9 | 5 Volcan (silhouette) | 880 | 1,64 | 20 | 12 iron-plate, 6 iron-gear-wheel, 6 copper-plate, 30 fo-tungsten-plate, 25 plastic-bar | 225 | 5 / 112 |
| 10 | 5 Volcan (+ pièce) | 940 | 1,72 | 20,25 | 13 iron-plate, 7 iron-gear-wheel, 7 copper-plate, 35 fo-tungsten-plate, 30 plastic-bar | 264 | 5 / 112 |
| 11 | 6 Électricité (silhouette) | 1 000 | 1,74 | 20,5 | 14 iron-plate, 7 iron-gear-wheel, 7 copper-plate, 25 battery, 35 fo-tungsten-plate | 400 | 5 / 128 |
| 12 | 6 Électricité (+ pièce) | 1 060 | 1,76 | 20,75 | 15 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 30 battery, 45 fo-tungsten-plate | 489 | 5 / 128 |
| 13 | 7 Cristal (silhouette) | 1 120 | 1,78 | 21 | 16 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 140 fo-resonance-crystal, 30 battery | 730 | 7 / 144 |
| 14 | 7 Cristal (+ pièce) | 1 180 | 1,8 | 21,25 | 17 iron-plate, 8 iron-gear-wheel, 8 copper-plate, 170 fo-resonance-crystal, 40 battery | 911 | 8 / 144 |
| 15 | 8 Marais (silhouette) | 1 240 | 1,82 | 21,5 | 18 iron-plate, 9 iron-gear-wheel, 9 copper-plate, 80 fo-methane-barrel, 180 fo-resonance-crystal | 1 385 | 15 / 160 |
| 16 | 8 Marais (+ pièce) | 1 300 | 1,84 | 21,75 | 19 iron-plate, 9 iron-gear-wheel, 9 copper-plate, 100 fo-methane-barrel, 220 fo-resonance-crystal | 1 706 | 18 / 160 |
| 17 | 9 Atome (silhouette) | 1 360 | 1,86 | 22 | 20 iron-plate, 10 iron-gear-wheel, 10 copper-plate, 100 uranium-238, 100 fo-methane-barrel | 2 450 | 14 / 176 |
| 18 | 9 Atome (+ pièce) | 1 420 | 1,88 | 22,25 | 20 iron-plate, 10 iron-gear-wheel, 10 copper-plate, 130 uranium-238, 120 fo-methane-barrel | 3 070 | 17 / 176 |
| 19 | 10 Haute technologie (silhouette) | 1 480 | 1,9 | 22,5 | 20 iron-plate, 11 iron-gear-wheel, 11 copper-plate, 35 processing-unit, 130 uranium-238 | 4 498 | 6 / 192 |
| 20 | 10 Haute technologie (+ pièce) | 1 540 | 1,92 | 22,75 | 20 iron-plate, 11 iron-gear-wheel, 11 copper-plate, 45 processing-unit, 160 uranium-238 | 5 668 | 6 / 192 |
| 21 | 11 Titane (silhouette) | 1 600 | 1,94 | 23 | 25 iron-plate, 12 iron-gear-wheel, 12 copper-plate, 110 low-density-structure, 45 processing-unit | 8 386 | 15 / 208 |
| 22 | 11 Titane (+ pièce) | 1 660 | 1,96 | 23,25 | 25 iron-plate, 12 iron-gear-wheel, 12 copper-plate, 140 low-density-structure, 55 processing-unit | 10 486 | 18 / 208 |
| 23 | 12 Supraconducteurs (silhouette) | 1 720 | 1,98 | 23,5 | 25 iron-plate, 12 iron-gear-wheel, 12 copper-plate, 560 electric-engine-unit, 130 low-density-structure | 14 871 | 28 / 224 |
| 24 | 12 Supraconducteurs (+ pièce) | 1 780 | 2 | 23,75 | 25 iron-plate, 13 iron-gear-wheel, 13 copper-plate, 700 electric-engine-unit, 170 low-density-structure | 18 914 | 34 / 224 |
| 25 | 13 Fusion (silhouette) | 1 840 | 2,02 | 24 | 25 iron-plate, 13 iron-gear-wheel, 13 copper-plate, 360 uranium-235, 680 electric-engine-unit | 27 144 | 21 / 240 |
| 26 | 13 Fusion (+ pièce) | 1 900 | 2,04 | 24,25 | 30 iron-plate, 14 iron-gear-wheel, 14 copper-plate, 450 uranium-235, 850 electric-engine-unit | 33 922 | 25 / 240 |
| 27 | 14 Orbite (silhouette) | 1 960 | 2,06 | 24,5 | 30 iron-plate, 14 iron-gear-wheel, 14 copper-plate, 200 rocket-control-unit, 440 uranium-235 | 49 872 | 28 / 256 |
| 28 | 14 Orbite (+ pièce) | 2 020 | 2,08 | 24,75 | 30 iron-plate, 15 iron-gear-wheel, 15 copper-plate, 250 rocket-control-unit, 550 uranium-235 | 62 325 | 34 / 256 |
| 29 | 15 Légende (silhouette) | 2 080 | 2,1 | 25 | 30 iron-plate, 15 iron-gear-wheel, 15 copper-plate, 200 space-science-pack, 230 rocket-control-unit | 84 575 | 27 / 272 |
| 30 | 15 Légende (+ pièce) | 2 140 | 2,12 | 25,25 | 30 iron-plate, 16 iron-gear-wheel, 16 copper-plate, 250 space-science-pack, 280 rocket-control-unit | 104 578 | 32 / 272 |

#### Emprise au sol par niveau (lot V3-T, Q23 et Q24 ; intégré le 22/10 à 14 h 50, version 0.4.2)

Table `L.footprints` de `shared/levels/config.lua`, relue avec `L.footprint` et `L.range_bonus` (lua5.2, 22/10). Ce
tableau est écrit à la main : `levels_test --tables` ne le produit pas. La colonne « portée » du tableau de la
mitrailleuse ci-dessus est la STATISTIQUE ; le prototype reçoit en plus le bonus de portée ci-dessous.

**Mitrailleuse (seule famille activée)** : une taille de plus par ère de 3 époques.

| Ère | Époques | Niveaux | Emprise | Collision | Sélection | Bonus de portée | Portée du prototype (statistique + bonus), premier et dernier niveau de l'ère |
|---|---|---|---|---|---|---|---|
| I | 1 à 3 | 1 à 6 | 2×2 (vanilla) | ± 0,7 | ± 1 | 0 | 18 et 19,25 |
| II | 4 à 6 | 7 à 12 | 3×3 | ± 1,2 | ± 1,5 | + 0,5 | 20 et 21,25 |
| III | 7 à 9 | 13 à 18 | 4×4 | ± 1,7 | ± 2 | + 1 | 22 et 23,25 |
| IV | 10 à 12 | 19 à 24 | 5×5 | ± 2,2 | ± 2,5 | + 1,5 | 24 et 25,25 |
| V | 13 à 15 | 25 à 30 | 6×6 | ± 2,7 | ± 3 | + 2 | 26 et 27,25 |

- **Boîtes** : sélection = le carré exact (± côté / 2) ; collision = le carré réduit de 0,3 tuile de chaque côté,
  comme le vanilla (mitrailleuse ± 0,7, machine 3×3 ± 1,2, roboport ± 1,7).
- **Bonus de portée = (côté − côté du niveau 1) / 2.** Raison : la portée du moteur se mesure depuis le CENTRE
  (`range_mode` « center-to-center » par défaut en 1.1.91). Sans ce complément, une mitrailleuse 6×6 porterait
  2 tuiles de moins au-delà de son bord qu'une 2×2 du même niveau ; avec lui, la portée au-delà du bord reste
  celle de la statistique. Contrôlé en moteur réel sur les 30 prototypes (`content`, greffon `levels_taille`,
  22/10).
- **Positions candidates** : (b − a + 1)² = 4 à chaque changement de taille d'une tuile. En montant d'une taille à
  la fois, le bâtiment se décale d'une demi-tuile vers le nord-ouest aux tailles impaires et revient sur son
  centre d'origine aux tailles paires (règle de position : ARCHITECTURE §7 bis).
- **Contour de refus** : 300 ticks (5 s).

**Rayon d'extraction d'une foreuse agrandie : r + (b − a) / 2** (même débord au-delà du bord). Foreuse
électrique vanilla 3×3 : 2,49 (5×5 tuiles) ; 4×4 : 2,99 ; 5×5 : 3,49 ; 6×6 : 3,99 (8×8 tuiles). Prévu par le code
et vérifié à l'étape data réelle sur une copie jetable (foreuse 25 : rayon 3,99, dépôt en (−0,5 ; −3,35)), **NON
activé** dans le jeu livré.

**Échelle PROPOSÉE pour les autres familles, NON VALIDÉE (Q-S1 ouverte ; aucune ligne dans `L.footprints`)** :

| Famille | Niveau 1 (vanilla) | Proposition du commentaire de `config.lua` (ères I à V) | Proposition de la charte (`docs/DA_FACTORIO.md`, Q-S1) |
|---|---|---|---|
| Tourelle laser | 2×2 | 2, 3, 4, 5, 6 | non citée (la règle « une taille de plus par ère » donnerait 2×2 → 6×6) |
| Foreuse électrique | 3×3 | 3, 4, 5, 6, 6 | non citée (la même règle donnerait 3×3 → 7×7) |
| Machine d'assemblage 2 | 3×3 | 3, 4, 5, 6, 6 | 3×3 → 7×7 |
| Four en acier | 2×2 | 2, 3, 4, 5, 6 ou 2, 4, 5, 6, 6 | 2×2 → 6×6 |
| Centre de commandement (15 niveaux) | 4×4 | 4, 5, 6, 7, 8 | 4×4 → 8×8 |
| Mur | 1×1 | inchangé (pas de ligne) | ? |

Les deux propositions divergent pour les machines 3×3 (6×6 ou 7×7 à l'ère V) ; OBJECTIFS D1-4 propose « machines
3×3 → 6×6 ». La garde `L.footprint_errors` impose un niveau 1
égal à la taille vanilla et une emprise qui ne rétrécit jamais : « four 3 → 6 » est donc refusé.

#### Tourelle laser (30 niveaux)

| Niveau | Époque | PV | dégâts × | portée | Coût du passage à ce niveau | Valeur (u) | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 1 000 | 2 | 24 | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 1 150 | 2,16 | 24,25 | 3 steel-plate, 3 electronic-circuit, 2 battery | 41 | 3 / 48 |
| 3 | 2 Forge (silhouette) | 1 300 | 2,32 | 24,5 | 9 steel-plate, 3 electronic-circuit, 2 battery | 71 | 3 / 64 |
| 4 | 2 Forge (+ pièce) | 1 450 | 2,48 | 24,75 | 11 steel-plate, 4 electronic-circuit, 3 battery | 92 | 3 / 64 |
| 5 | 3 Vapeur (silhouette) | 1 600 | 2,64 | 25 | 6 steel-plate, 4 electronic-circuit, 3 battery, 3 engine-unit | 94 | 4 / 80 |
| 6 | 3 Vapeur (+ pièce) | 1 750 | 2,8 | 25,25 | 8 steel-plate, 5 electronic-circuit, 3 battery, 2 engine-unit | 98 | 4 / 80 |
| 7 | 4 Pétrole (silhouette) | 1 900 | 2,96 | 25,5 | 5 steel-plate, 5 electronic-circuit, 4 battery, 18 plastic-bar, 4 engine-unit | 164 | 5 / 96 |
| 8 | 4 Pétrole (+ pièce) | 2 050 | 3,12 | 25,75 | 6 steel-plate, 6 electronic-circuit, 4 battery, 25 plastic-bar, 5 engine-unit | 201 | 5 / 96 |
| 9 | 5 Volcan (silhouette) | 2 200 | 3,28 | 26 | 6 steel-plate, 6 electronic-circuit, 4 battery, 45 fo-tungsten-plate, 40 plastic-bar | 381 | 5 / 112 |
| 10 | 5 Volcan (+ pièce) | 2 350 | 3,44 | 26,25 | 7 steel-plate, 7 electronic-circuit, 4 battery, 60 fo-tungsten-plate, 50 plastic-bar | 479 | 5 / 112 |
| 11 | 6 Électricité (silhouette) | 2 500 | 3,48 | 26,5 | 7 steel-plate, 7 electronic-circuit, 45 battery, 60 fo-tungsten-plate | 698 | 4 / 128 |
| 12 | 6 Électricité (+ pièce) | 2 650 | 3,52 | 26,75 | 8 steel-plate, 8 electronic-circuit, 55 battery, 75 fo-tungsten-plate | 855 | 4 / 128 |
| 13 | 7 Cristal (silhouette) | 2 800 | 3,56 | 27 | 8 steel-plate, 8 electronic-circuit, 55 battery, 230 fo-resonance-crystal | 1 245 | 8 / 144 |
| 14 | 7 Cristal (+ pièce) | 2 950 | 3,6 | 27,25 | 8 steel-plate, 8 electronic-circuit, 71 battery, 290 fo-resonance-crystal | 1 569 | 9 / 144 |
| 15 | 8 Marais (silhouette) | 3 100 | 3,64 | 27,5 | 9 steel-plate, 9 electronic-circuit, 6 battery, 130 fo-methane-barrel, 290 fo-resonance-crystal | 2 292 | 22 / 160 |
| 16 | 8 Marais (+ pièce) | 3 250 | 3,68 | 27,75 | 9 steel-plate, 9 electronic-circuit, 6 battery, 170 fo-methane-barrel, 370 fo-resonance-crystal | 2 932 | 28 / 160 |
| 17 | 9 Atome (silhouette) | 3 400 | 3,72 | 28 | 10 steel-plate, 10 electronic-circuit, 7 battery, 170 uranium-238, 160 fo-methane-barrel | 4 118 | 21 / 176 |
| 18 | 9 Atome (+ pièce) | 3 550 | 3,76 | 28,25 | 10 steel-plate, 10 electronic-circuit, 7 battery, 220 uranium-238, 200 fo-methane-barrel | 5 218 | 26 / 176 |
| 19 | 10 Haute technologie (silhouette) | 3 700 | 3,8 | 28,5 | 11 steel-plate, 11 electronic-circuit, 7 battery, 60 processing-unit, 210 uranium-238 | 7 586 | 7 / 192 |
| 20 | 10 Haute technologie (+ pièce) | 3 850 | 3,84 | 28,75 | 11 steel-plate, 11 electronic-circuit, 7 battery, 75 processing-unit, 270 uranium-238 | 9 551 | 7 / 192 |
| 21 | 11 Titane (silhouette) | 4 000 | 3,88 | 29 | 12 steel-plate, 12 electronic-circuit, 8 battery, 180 low-density-structure, 70 processing-unit | 13 512 | 22 / 208 |
| 22 | 11 Titane (+ pièce) | 4 150 | 3,92 | 29,25 | 12 steel-plate, 12 electronic-circuit, 8 battery, 230 low-density-structure, 90 processing-unit | 17 262 | 27 / 208 |
| 23 | 12 Supraconducteurs (silhouette) | 4 300 | 3,96 | 29,5 | 12 steel-plate, 12 electronic-circuit, 8 battery, 940 electric-engine-unit, 220 low-density-structure | 25 102 | 44 / 224 |
| 24 | 12 Supraconducteurs (+ pièce) | 4 450 | 4 | 29,75 | 13 steel-plate, 13 electronic-circuit, 9 battery, 1 170 electric-engine-unit, 280 low-density-structure | 31 499 | 55 / 224 |
| 25 | 13 Fusion (silhouette) | 4 600 | 4,04 | 30 | 13 steel-plate, 13 electronic-circuit, 9 battery, 610 uranium-235, 1 140 electric-engine-unit | 45 869 | 33 / 240 |
| 26 | 13 Fusion (+ pièce) | 4 750 | 4,08 | 30,25 | 14 steel-plate, 14 electronic-circuit, 9 battery, 760 uranium-235, 1 420 electric-engine-unit | 57 106 | 40 / 240 |
| 27 | 14 Orbite (silhouette) | 4 900 | 4,12 | 30,5 | 14 steel-plate, 14 electronic-circuit, 10 battery, 330 rocket-control-unit, 740 uranium-235 | 82 995 | 44 / 256 |
| 28 | 14 Orbite (+ pièce) | 5 050 | 4,16 | 30,75 | 15 steel-plate, 15 electronic-circuit, 10 battery, 410 rocket-control-unit, 920 uranium-235 | 103 103 | 54 / 256 |
| 29 | 15 Légende (silhouette) | 5 200 | 4,2 | 31 | 15 steel-plate, 15 electronic-circuit, 10 battery, 340 space-science-pack, 380 rocket-control-unit | 142 203 | 42 / 272 |
| 30 | 15 Légende (+ pièce) | 5 350 | 4,24 | 31,25 | 16 steel-plate, 16 electronic-circuit, 10 battery, 420 space-science-pack, 470 rocket-control-unit | 175 710 | 51 / 272 |

#### Mur (30 niveaux)

| Niveau | Époque | PV | réduction physique | réduction explosion | Coût du passage à ce niveau | Valeur (u) | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 350 | 3 | 10 | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 525 | 3,5 | 10,5 | 3 stone-brick | 6 | 1 / 48 |
| 3 | 2 Forge (silhouette) | 700 | 4 | 11 | 3 stone-brick, 1 steel-plate | 11 | 2 / 64 |
| 4 | 2 Forge (+ pièce) | 875 | 4,5 | 11,5 | 4 stone-brick, 1 steel-plate | 13 | 2 / 64 |
| 5 | 3 Vapeur (silhouette) | 1 050 | 5 | 12 | 4 stone-brick, 1 engine-unit | 17 | 2 / 80 |
| 6 | 3 Vapeur (+ pièce) | 1 225 | 5,5 | 12,5 | 5 stone-brick, 1 engine-unit | 19 | 2 / 80 |
| 7 | 4 Pétrole (silhouette) | 1 400 | 6 | 13 | 5 stone-brick, 4 plastic-bar | 22 | 2 / 96 |
| 8 | 4 Pétrole (+ pièce) | 1 575 | 6,5 | 13,5 | 6 stone-brick, 4 plastic-bar | 24 | 2 / 96 |
| 9 | 5 Volcan (silhouette) | 1 750 | 7 | 14 | 6 stone-brick, 8 fo-tungsten-plate | 44 | 2 / 112 |
| 10 | 5 Volcan (+ pièce) | 1 925 | 7,5 | 14,5 | 7 stone-brick, 10 fo-tungsten-plate | 54 | 2 / 112 |
| 11 | 6 Électricité (silhouette) | 2 100 | 8 | 15 | 7 stone-brick, 6 battery | 68 | 2 / 128 |
| 12 | 6 Électricité (+ pièce) | 2 275 | 8,5 | 15,5 | 8 stone-brick, 8 battery | 88 | 2 / 128 |
| 13 | 7 Cristal (silhouette) | 2 450 | 9 | 16 | 8 stone-brick, 40 fo-resonance-crystal | 136 | 2 / 144 |
| 14 | 7 Cristal (+ pièce) | 2 625 | 9,5 | 16,5 | 8 stone-brick, 50 fo-resonance-crystal | 166 | 2 / 144 |
| 15 | 8 Marais (silhouette) | 2 800 | 10 | 17 | 9 stone-brick, 20 fo-methane-barrel | 218 | 3 / 160 |
| 16 | 8 Marais (+ pièce) | 2 975 | 10,5 | 17,5 | 9 stone-brick, 30 fo-methane-barrel | 318 | 4 / 160 |
| 17 | 9 Atome (silhouette) | 3 150 | 11 | 18 | 10 stone-brick, 30 uranium-238 | 440 | 2 / 176 |
| 18 | 9 Atome (+ pièce) | 3 325 | 11,5 | 18,5 | 10 stone-brick, 35 uranium-238 | 510 | 2 / 176 |
| 19 | 10 Haute technologie (silhouette) | 3 500 | 12 | 19 | 11 stone-brick, 10 processing-unit | 772 | 2 / 192 |
| 20 | 10 Haute technologie (+ pièce) | 3 675 | 12,5 | 19,5 | 11 stone-brick, 12 processing-unit | 922 | 2 / 192 |
| 21 | 11 Titane (silhouette) | 3 850 | 13 | 20 | 12 stone-brick, 30 low-density-structure | 1 374 | 4 / 208 |
| 22 | 11 Titane (+ pièce) | 4 025 | 13,5 | 20,5 | 12 stone-brick, 40 low-density-structure | 1 824 | 5 / 208 |
| 23 | 12 Supraconducteurs (silhouette) | 4 200 | 14 | 21 | 12 stone-brick, 160 electric-engine-unit | 2 584 | 5 / 224 |
| 24 | 12 Supraconducteurs (+ pièce) | 4 375 | 14,5 | 21,5 | 13 stone-brick, 200 electric-engine-unit | 3 226 | 5 / 224 |
| 25 | 13 Fusion (silhouette) | 4 550 | 15 | 22 | 13 stone-brick, 100 uranium-235 | 4 526 | 2 / 240 |
| 26 | 13 Fusion (+ pièce) | 4 725 | 15,5 | 22,5 | 14 stone-brick, 130 uranium-235 | 5 878 | 3 / 240 |
| 27 | 14 Orbite (silhouette) | 4 900 | 16 | 23 | 14 stone-brick, 55 rocket-control-unit | 8 278 | 7 / 256 |
| 28 | 14 Orbite (+ pièce) | 5 075 | 16,5 | 23,5 | 15 stone-brick, 70 rocket-control-unit | 10 530 | 8 / 256 |
| 29 | 15 Légende (silhouette) | 5 250 | 17 | 24 | 15 stone-brick, 55 space-science-pack | 13 780 | 2 / 272 |
| 30 | 15 Légende (+ pièce) | 5 425 | 17,5 | 24,5 | 16 stone-brick, 70 space-science-pack | 17 532 | 2 / 272 |

#### Foreuse électrique (30 niveaux)

| Niveau | Époque | PV | minage | kW | Coût du passage à ce niveau | Valeur (u) | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 300 | 0,5 | 90 | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 345 | 0,55 | 96,3 | 6 iron-plate, 3 iron-gear-wheel, 2 electronic-circuit | 17 | 3 / 48 |
| 3 | 2 Forge (silhouette) | 390 | 0,6 | 102,6 | 7 iron-plate, 3 iron-gear-wheel, 2 electronic-circuit, 2 steel-plate | 28 | 4 / 64 |
| 4 | 2 Forge (+ pièce) | 435 | 0,65 | 108,9 | 8 iron-plate, 4 iron-gear-wheel, 3 electronic-circuit, 3 steel-plate | 39 | 4 / 64 |
| 5 | 3 Vapeur (silhouette) | 480 | 0,7 | 115,2 | 9 iron-plate, 4 iron-gear-wheel, 3 electronic-circuit, 2 engine-unit, 1 steel-plate | 48 | 5 / 80 |
| 6 | 3 Vapeur (+ pièce) | 525 | 0,75 | 121,5 | 10 iron-plate, 5 iron-gear-wheel, 3 electronic-circuit, 2 engine-unit, 1 steel-plate | 51 | 5 / 80 |
| 7 | 4 Pétrole (silhouette) | 570 | 0,8 | 127,8 | 11 iron-plate, 5 iron-gear-wheel, 4 electronic-circuit, 6 plastic-bar, 1 engine-unit | 58 | 5 / 96 |
| 8 | 4 Pétrole (+ pièce) | 615 | 0,85 | 134,1 | 11 iron-plate, 6 iron-gear-wheel, 4 electronic-circuit, 8 plastic-bar, 2 engine-unit | 75 | 5 / 96 |
| 9 | 5 Volcan (silhouette) | 660 | 0,9 | 140,4 | 12 iron-plate, 6 iron-gear-wheel, 4 electronic-circuit, 16 fo-tungsten-plate, 14 plastic-bar | 140 | 5 / 112 |
| 10 | 5 Volcan (+ pièce) | 705 | 0,95 | 146,7 | 13 iron-plate, 7 iron-gear-wheel, 4 electronic-circuit, 20 fo-tungsten-plate, 18 plastic-bar | 171 | 5 / 112 |
| 11 | 6 Électricité (silhouette) | 750 | 1 | 153 | 14 iron-plate, 7 iron-gear-wheel, 5 electronic-circuit, 14 battery, 20 fo-tungsten-plate | 247 | 5 / 128 |
| 12 | 6 Électricité (+ pièce) | 795 | 1,05 | 159,3 | 15 iron-plate, 8 iron-gear-wheel, 5 electronic-circuit, 17 battery, 25 fo-tungsten-plate | 297 | 5 / 128 |
| 13 | 7 Cristal (silhouette) | 840 | 1,1 | 165,6 | 16 iron-plate, 8 iron-gear-wheel, 5 electronic-circuit, 80 fo-resonance-crystal, 18 battery | 447 | 6 / 144 |
| 14 | 7 Cristal (+ pièce) | 885 | 1,15 | 171,9 | 17 iron-plate, 8 iron-gear-wheel, 6 electronic-circuit, 100 fo-resonance-crystal, 25 battery | 573 | 6 / 144 |
| 15 | 8 Marais (silhouette) | 930 | 1,2 | 178,2 | 18 iron-plate, 9 iron-gear-wheel, 6 electronic-circuit, 45 fo-methane-barrel, 100 fo-resonance-crystal | 801 | 10 / 160 |
| 16 | 8 Marais (+ pièce) | 975 | 1,25 | 184,5 | 19 iron-plate, 9 iron-gear-wheel, 6 electronic-circuit, 60 fo-methane-barrel, 130 fo-resonance-crystal | 1 042 | 12 / 160 |
| 17 | 9 Atome (silhouette) | 1 020 | 1,3 | 190,8 | 20 iron-plate, 10 iron-gear-wheel, 7 electronic-circuit, 60 uranium-238, 55 fo-methane-barrel | 1 448 | 10 / 176 |
| 18 | 9 Atome (+ pièce) | 1 065 | 1,35 | 197,1 | 20 iron-plate, 10 iron-gear-wheel, 7 electronic-circuit, 75 uranium-238, 70 fo-methane-barrel | 1 808 | 11 / 176 |
| 19 | 10 Haute technologie (silhouette) | 1 110 | 1,4 | 203,4 | 20 iron-plate, 11 iron-gear-wheel, 7 electronic-circuit, 20 processing-unit, 75 uranium-238 | 2 610 | 5 / 192 |
| 20 | 10 Haute technologie (+ pièce) | 1 155 | 1,45 | 209,7 | 20 iron-plate, 11 iron-gear-wheel, 7 electronic-circuit, 25 processing-unit, 95 uranium-238 | 3 265 | 5 / 192 |
| 21 | 11 Titane (silhouette) | 1 200 | 1,5 | 216 | 25 iron-plate, 12 iron-gear-wheel, 8 electronic-circuit, 65 low-density-structure, 25 processing-unit | 4 869 | 11 / 208 |
| 22 | 11 Titane (+ pièce) | 1 245 | 1,55 | 222,3 | 25 iron-plate, 12 iron-gear-wheel, 8 electronic-circuit, 80 low-density-structure, 30 processing-unit | 5 919 | 12 / 208 |
| 23 | 12 Supraconducteurs (silhouette) | 1 290 | 1,6 | 228,6 | 25 iron-plate, 12 iron-gear-wheel, 8 electronic-circuit, 330 electric-engine-unit, 80 low-density-structure | 8 949 | 18 / 224 |
| 24 | 12 Supraconducteurs (+ pièce) | 1 335 | 1,65 | 234,9 | 25 iron-plate, 13 iron-gear-wheel, 9 electronic-circuit, 410 electric-engine-unit, 95 low-density-structure | 10 909 | 22 / 224 |
| 25 | 13 Fusion (silhouette) | 1 380 | 1,7 | 241,2 | 25 iron-plate, 13 iron-gear-wheel, 9 electronic-circuit, 210 uranium-235, 400 electric-engine-unit | 15 924 | 14 / 240 |
| 26 | 13 Fusion (+ pièce) | 1 425 | 1,75 | 247,5 | 30 iron-plate, 14 iron-gear-wheel, 9 electronic-circuit, 260 uranium-235, 500 electric-engine-unit | 19 781 | 16 / 240 |
| 27 | 14 Orbite (silhouette) | 1 470 | 1,8 | 253,8 | 30 iron-plate, 14 iron-gear-wheel, 10 electronic-circuit, 120 rocket-control-unit, 260 uranium-235 | 29 783 | 18 / 256 |
| 28 | 14 Orbite (+ pièce) | 1 515 | 1,85 | 260,1 | 30 iron-plate, 15 iron-gear-wheel, 10 electronic-circuit, 140 rocket-control-unit, 320 uranium-235 | 35 485 | 21 / 256 |
| 29 | 15 Légende (silhouette) | 1 560 | 1,9 | 266,4 | 30 iron-plate, 15 iron-gear-wheel, 10 electronic-circuit, 120 space-science-pack, 130 rocket-control-unit | 49 585 | 17 / 272 |
| 30 | 15 Légende (+ pièce) | 1 605 | 1,95 | 272,7 | 30 iron-plate, 16 iron-gear-wheel, 10 electronic-circuit, 150 space-science-pack, 160 rocket-control-unit | 61 587 | 20 / 272 |

#### Four en acier (30 niveaux)

| Niveau | Époque | PV | vitesse | kW | Coût du passage à ce niveau | Valeur (u) | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 300 | 2 | 90 | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 345 | 2,16 | 95,4 | 2 steel-plate, 3 stone-brick | 16 | 2 / 48 |
| 3 | 2 Forge (silhouette) | 390 | 2,32 | 100,8 | 4 steel-plate, 3 stone-brick | 26 | 2 / 64 |
| 4 | 2 Forge (+ pièce) | 435 | 2,48 | 106,2 | 5 steel-plate, 4 stone-brick | 33 | 2 / 64 |
| 5 | 3 Vapeur (silhouette) | 480 | 2,64 | 111,6 | 4 steel-plate, 4 stone-brick, 1 engine-unit | 37 | 3 / 80 |
| 6 | 3 Vapeur (+ pièce) | 525 | 2,8 | 117 | 4 steel-plate, 5 stone-brick, 1 engine-unit | 39 | 3 / 80 |
| 7 | 4 Pétrole (silhouette) | 570 | 2,96 | 122,4 | 4 steel-plate, 5 stone-brick, 5 plastic-bar, 1 engine-unit | 54 | 4 / 96 |
| 8 | 4 Pétrole (+ pièce) | 615 | 3,12 | 127,8 | 4 steel-plate, 6 stone-brick, 7 plastic-bar, 2 engine-unit | 71 | 4 / 96 |
| 9 | 5 Volcan (silhouette) | 660 | 3,28 | 133,2 | 4 steel-plate, 6 stone-brick, 14 fo-tungsten-plate, 12 plastic-bar | 124 | 4 / 112 |
| 10 | 5 Volcan (+ pièce) | 705 | 3,44 | 138,6 | 4 steel-plate, 7 stone-brick, 17 fo-tungsten-plate, 16 plastic-bar | 150 | 4 / 112 |
| 11 | 6 Électricité (silhouette) | 750 | 3,6 | 144 | 5 steel-plate, 7 stone-brick, 12 battery, 18 fo-tungsten-plate | 219 | 4 / 128 |
| 12 | 6 Électricité (+ pièce) | 795 | 3,76 | 149,4 | 5 steel-plate, 8 stone-brick, 15 battery, 20 fo-tungsten-plate | 256 | 4 / 128 |
| 13 | 7 Cristal (silhouette) | 840 | 3,92 | 154,8 | 5 steel-plate, 8 stone-brick, 70 fo-resonance-crystal, 15 battery | 386 | 5 / 144 |
| 14 | 7 Cristal (+ pièce) | 885 | 4,08 | 160,2 | 6 steel-plate, 8 stone-brick, 85 fo-resonance-crystal, 19 battery | 472 | 5 / 144 |
| 15 | 8 Marais (silhouette) | 930 | 4,24 | 165,6 | 6 steel-plate, 9 stone-brick, 40 fo-methane-barrel, 90 fo-resonance-crystal | 718 | 8 / 160 |
| 16 | 8 Marais (+ pièce) | 975 | 4,4 | 171 | 6 steel-plate, 9 stone-brick, 50 fo-methane-barrel, 110 fo-resonance-crystal | 878 | 10 / 160 |
| 17 | 9 Atome (silhouette) | 1 020 | 4,56 | 176,4 | 7 steel-plate, 10 stone-brick, 50 uranium-238, 50 fo-methane-barrel | 1 255 | 8 / 176 |
| 18 | 9 Atome (+ pièce) | 1 065 | 4,72 | 181,8 | 7 steel-plate, 10 stone-brick, 65 uranium-238, 60 fo-methane-barrel | 1 565 | 9 / 176 |
| 19 | 10 Haute technologie (silhouette) | 1 110 | 4,88 | 187,2 | 7 steel-plate, 11 stone-brick, 18 processing-unit, 65 uranium-238 | 2 317 | 4 / 192 |
| 20 | 10 Haute technologie (+ pièce) | 1 155 | 5,04 | 192,6 | 7 steel-plate, 11 stone-brick, 20 processing-unit, 80 uranium-238 | 2 677 | 4 / 192 |
| 21 | 11 Titane (silhouette) | 1 200 | 5,2 | 198 | 8 steel-plate, 12 stone-brick, 55 low-density-structure, 20 processing-unit | 4 039 | 9 / 208 |
| 22 | 11 Titane (+ pièce) | 1 245 | 5,36 | 203,4 | 8 steel-plate, 12 stone-brick, 70 low-density-structure, 25 processing-unit | 5 089 | 10 / 208 |
| 23 | 12 Supraconducteurs (silhouette) | 1 290 | 5,52 | 208,8 | 8 steel-plate, 12 stone-brick, 280 electric-engine-unit, 65 low-density-structure | 7 469 | 15 / 224 |
| 24 | 12 Supraconducteurs (+ pièce) | 1 335 | 5,68 | 214,2 | 9 steel-plate, 13 stone-brick, 350 electric-engine-unit, 85 low-density-structure | 9 496 | 18 / 224 |
| 25 | 13 Fusion (silhouette) | 1 380 | 5,84 | 219,6 | 9 steel-plate, 13 stone-brick, 180 uranium-235, 340 electric-engine-unit | 13 611 | 11 / 240 |
| 26 | 13 Fusion (+ pièce) | 1 425 | 6 | 225 | 9 steel-plate, 14 stone-brick, 230 uranium-235, 430 electric-engine-unit | 17 303 | 14 / 240 |
| 27 | 14 Orbite (silhouette) | 1 470 | 6,16 | 230,4 | 10 steel-plate, 14 stone-brick, 100 rocket-control-unit, 220 uranium-235 | 24 978 | 15 / 256 |
| 28 | 14 Orbite (+ pièce) | 1 515 | 6,32 | 235,8 | 10 steel-plate, 15 stone-brick, 120 rocket-control-unit, 280 uranium-235 | 30 680 | 17 / 256 |
| 29 | 15 Légende (silhouette) | 1 560 | 6,48 | 241,2 | 10 steel-plate, 15 stone-brick, 100 space-science-pack, 110 rocket-control-unit | 41 580 | 14 / 272 |
| 30 | 15 Légende (+ pièce) | 1 605 | 6,64 | 246,6 | 10 steel-plate, 16 stone-brick, 130 space-science-pack, 140 rocket-control-unit | 53 582 | 17 / 272 |

#### Machine d'assemblage 2 (30 niveaux)

| Niveau | Époque | PV | vitesse | kW | Coût du passage à ce niveau | Valeur (u) | Cases / coffre du centre payeur |
|---|---|---|---|---|---|---|---|
| 1 | 1 Pionnier (vanilla) | 350 | 0,75 | 150 | — | — | — |
| 2 | 1 Pionnier (+ pièce) | 402,5 | 0,81 | 159 | 6 iron-plate, 3 iron-gear-wheel, 3 electronic-circuit | 20 | 3 / 48 |
| 3 | 2 Forge (silhouette) | 455 | 0,87 | 168 | 7 iron-plate, 3 iron-gear-wheel, 3 electronic-circuit, 2 steel-plate | 31 | 4 / 64 |
| 4 | 2 Forge (+ pièce) | 507,5 | 0,93 | 177 | 8 iron-plate, 4 iron-gear-wheel, 4 electronic-circuit, 3 steel-plate | 41 | 4 / 64 |
| 5 | 3 Vapeur (silhouette) | 560 | 0,99 | 186 | 9 iron-plate, 4 iron-gear-wheel, 4 electronic-circuit, 2 engine-unit, 1 steel-plate | 50 | 5 / 80 |
| 6 | 3 Vapeur (+ pièce) | 612,5 | 1,05 | 195 | 10 iron-plate, 5 iron-gear-wheel, 5 electronic-circuit, 2 engine-unit, 1 steel-plate | 56 | 5 / 80 |
| 7 | 4 Pétrole (silhouette) | 665 | 1,11 | 204 | 11 iron-plate, 5 iron-gear-wheel, 5 electronic-circuit, 6 plastic-bar, 1 engine-unit | 61 | 5 / 96 |
| 8 | 4 Pétrole (+ pièce) | 717,5 | 1,17 | 213 | 11 iron-plate, 6 iron-gear-wheel, 6 electronic-circuit, 8 plastic-bar, 2 engine-unit | 80 | 5 / 96 |
| 9 | 5 Volcan (silhouette) | 770 | 1,23 | 222 | 12 iron-plate, 6 iron-gear-wheel, 6 electronic-circuit, 16 fo-tungsten-plate, 14 plastic-bar | 145 | 5 / 112 |
| 10 | 5 Volcan (+ pièce) | 822,5 | 1,29 | 231 | 13 iron-plate, 7 iron-gear-wheel, 7 electronic-circuit, 20 fo-tungsten-plate, 18 plastic-bar | 179 | 5 / 112 |
| 11 | 6 Électricité (silhouette) | 875 | 1,35 | 240 | 14 iron-plate, 7 iron-gear-wheel, 7 electronic-circuit, 14 battery, 20 fo-tungsten-plate | 252 | 5 / 128 |
| 12 | 6 Électricité (+ pièce) | 927,5 | 1,41 | 249 | 15 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 17 battery, 25 fo-tungsten-plate | 304 | 5 / 128 |
| 13 | 7 Cristal (silhouette) | 980 | 1,47 | 258 | 16 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 80 fo-resonance-crystal, 18 battery | 454 | 6 / 144 |
| 14 | 7 Cristal (+ pièce) | 1032,5 | 1,53 | 267 | 17 iron-plate, 8 iron-gear-wheel, 8 electronic-circuit, 100 fo-resonance-crystal, 25 battery | 578 | 6 / 144 |
| 15 | 8 Marais (silhouette) | 1 085 | 1,59 | 276 | 18 iron-plate, 9 iron-gear-wheel, 9 electronic-circuit, 45 fo-methane-barrel, 100 fo-resonance-crystal | 809 | 10 / 160 |
| 16 | 8 Marais (+ pièce) | 1137,5 | 1,65 | 285 | 19 iron-plate, 9 iron-gear-wheel, 9 electronic-circuit, 60 fo-methane-barrel, 130 fo-resonance-crystal | 1 050 | 12 / 160 |
| 17 | 9 Atome (silhouette) | 1 190 | 1,71 | 294 | 20 iron-plate, 10 iron-gear-wheel, 10 electronic-circuit, 60 uranium-238, 55 fo-methane-barrel | 1 455 | 10 / 176 |
| 18 | 9 Atome (+ pièce) | 1242,5 | 1,77 | 303 | 20 iron-plate, 10 iron-gear-wheel, 10 electronic-circuit, 75 uranium-238, 70 fo-methane-barrel | 1 815 | 11 / 176 |
| 19 | 10 Haute technologie (silhouette) | 1 295 | 1,83 | 312 | 20 iron-plate, 11 iron-gear-wheel, 11 electronic-circuit, 20 processing-unit, 75 uranium-238 | 2 620 | 5 / 192 |
| 20 | 10 Haute technologie (+ pièce) | 1347,5 | 1,89 | 321 | 20 iron-plate, 11 iron-gear-wheel, 11 electronic-circuit, 25 processing-unit, 95 uranium-238 | 3 275 | 5 / 192 |
| 21 | 11 Titane (silhouette) | 1 400 | 1,95 | 330 | 25 iron-plate, 12 iron-gear-wheel, 12 electronic-circuit, 65 low-density-structure, 25 processing-unit | 4 879 | 11 / 208 |
| 22 | 11 Titane (+ pièce) | 1452,5 | 2,01 | 339 | 25 iron-plate, 12 iron-gear-wheel, 12 electronic-circuit, 80 low-density-structure, 30 processing-unit | 5 929 | 12 / 208 |
| 23 | 12 Supraconducteurs (silhouette) | 1 505 | 2,07 | 348 | 25 iron-plate, 12 iron-gear-wheel, 12 electronic-circuit, 330 electric-engine-unit, 80 low-density-structure | 8 959 | 18 / 224 |
| 24 | 12 Supraconducteurs (+ pièce) | 1557,5 | 2,13 | 357 | 25 iron-plate, 13 iron-gear-wheel, 13 electronic-circuit, 410 electric-engine-unit, 95 low-density-structure | 10 919 | 22 / 224 |
| 25 | 13 Fusion (silhouette) | 1 610 | 2,19 | 366 | 25 iron-plate, 13 iron-gear-wheel, 13 electronic-circuit, 210 uranium-235, 400 electric-engine-unit | 15 934 | 14 / 240 |
| 26 | 13 Fusion (+ pièce) | 1662,5 | 2,25 | 375 | 30 iron-plate, 14 iron-gear-wheel, 14 electronic-circuit, 260 uranium-235, 500 electric-engine-unit | 19 793 | 16 / 240 |
| 27 | 14 Orbite (silhouette) | 1 715 | 2,31 | 384 | 30 iron-plate, 14 iron-gear-wheel, 14 electronic-circuit, 120 rocket-control-unit, 260 uranium-235 | 29 793 | 18 / 256 |
| 28 | 14 Orbite (+ pièce) | 1767,5 | 2,37 | 393 | 30 iron-plate, 15 iron-gear-wheel, 15 electronic-circuit, 140 rocket-control-unit, 320 uranium-235 | 35 498 | 21 / 256 |
| 29 | 15 Légende (silhouette) | 1 820 | 2,43 | 402 | 30 iron-plate, 15 iron-gear-wheel, 15 electronic-circuit, 120 space-science-pack, 130 rocket-control-unit | 49 598 | 17 / 272 |
| 30 | 15 Légende (+ pièce) | 1872,5 | 2,49 | 411 | 30 iron-plate, 16 iron-gear-wheel, 16 electronic-circuit, 150 space-science-pack, 160 rocket-control-unit | 61 602 | 20 / 272 |
