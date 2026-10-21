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

## 12. Niveaux de bâtiments « façon Clash of Clans » (session 5)

Directeur Créatif : « niveau Clash of Clans en termes d'échelons, de qualité de levels… pratiquement idle
game ». Données : `shared/levels/config.lua` (pur, testé) ; prototypes : `prototypes/levels.lua` ;
runtime : `script/levels/`.

> **État au 21/10, 17 h 40 : version provisoire à 10 niveaux.** Le Directeur Créatif veut **15 époques**
> pour jouer en continu (OBJECTIFS.md F1). Chaque époque apporte une nouvelle silhouette, des ressources
> exploitables et de nouveaux bâtiments, et chaque niveau ajoute une pièce. La courbe ci-dessous
> (×1,5 par niveau) explose au-delà du niveau 10 : 1,5^28 ≈ 85 000. Elle est donc **à refaire** avec le
> nombre de niveaux par époque retenu (proposition : 2, soit 30 niveaux, comme l'hôtel de ville de Clash
> of Clans qui ouvre environ 2 niveaux de défense par niveau). Le principe à retenir : la croissance se
> fait **par époque** (nouveau matériau requis), pas par exposant.

**Règles**
- 7 familles × 10 niveaux : centre de commandement, mitrailleuse, tourelle laser, mur, foreuse électrique,
  four en acier, machine d'assemblage 2. Le niveau 1 est le bâtiment vanilla (ou le centre de base).
- **Centre de commandement** (l'hôtel de ville, 4×4, un par force) : un bâtiment ne dépasse jamais
  `niveau du centre + 1` ; sans centre, rien ne s'améliore. **Ouvriers** : 1 chantier simultané
  (centre 1-3), 2 (4-6), 3 (7-9), 4 (10). Stockage 48 → 192 cases.
- **Paiement** : le stock du centre d'abord, puis l'inventaire du joueur. L'usine alimente le centre par
  convoyeurs et inserteurs : c'est la production qui nourrit la progression (boucle « idle »).
- **Chantier** : durée `t0 × 1,5^(n-2)`, bâtiment hors service, barre de progression ; au terme,
  remplacement moteur « rapide » (contenu, recette, modules, fils conservés), santé en proportion.
  Murs instantanés, rangée entière. Démonté en chantier : moitié du coût rendue ; détruit : perdu.
  Réglage de partie `fo-level-time-factor` (0 = instantané).
- **Coût** : `base × croissance^(n-2)` (croissance 1,5 ; 1,6 pour le centre) + matériaux de palier :
  acier (niv. 4+), circuits (5+), circuits avancés (6+), **tungstène (7+)**, unités de traitement et
  **cristal de résonance (9+)** : les ressources des biomes deviennent les monnaies des hauts niveaux.

**Statistiques par niveau n** (valeur du niveau 1 × facteur)

| Famille | PV | Effet principal | Autre |
|---|---|---|---|
| Centre de commandement | × (1 + 0,20 (n-1)) : 3 000 → 8 400 | plafond et ouvriers | stockage + 16 cases / niveau |
| Mitrailleuse | × (1 + 0,15 (n-1)) : 400 → 940 | dégâts × (1 + 0,08 (n-1)) : × 1,72 au niv. 10 | portée + 0,25 / niveau (18 → 20,25) ; rotation + 5 % / niveau |
| Tourelle laser | 1 000 → 2 350 | dégâts × 1,72 au niv. 10 | portée 24 → 26,25 |
| Mur | × 1,30^(n-1) : 350 → 3 712 | réduction fixe physique et explosion + 1 / niveau | — |
| Foreuse électrique | 300 → 705 | vitesse de minage × (1 + 0,10 (n-1)) : 0,5 → 0,95 | énergie × (1 + 0,07 (n-1)) |
| Four en acier | 300 → 705 | vitesse × (1 + 0,08 (n-1)) : 2 → 3,44 | énergie × (1 + 0,06 (n-1)) |
| Machine d'assemblage 2 | 350 → 822 | vitesse × (1 + 0,08 (n-1)) : 0,75 → 1,29 | énergie × (1 + 0,06 (n-1)) |

Lecture : l'énergie croît moins vite que la vitesse (récompense réelle) ; une machine d'assemblage 2 au
niveau 10 dépasse la 3 vanilla (1,25) : c'est l'investissement « idle » qui paie, pas un saut de tier.

**Coûts** (passage au niveau 2 → passage au niveau 10)

| Famille | Durée | Niveau 2 | Niveau 10 |
|---|---|---|---|
| Centre de commandement | 30 s → 12 min 48 s | 100 iron-plate, 50 copper-plate, 50 stone-brick, 20 electronic-circuit | 4290 iron-plate, 2150 copper-plate, 2150 stone-brick, 1280 electronic-circuit, 670 steel-plate, 130 advanced-circuit, 130 tungsten-plate, 25 processing-unit, 40 resonance-crystal |
| Mitrailleuse | 10 s → 4 min 16 s | 20 iron-plate, 10 iron-gear-wheel, 10 copper-plate | 510 iron-plate, 260 iron-gear-wheel, 260 copper-plate, 110 steel-plate, 75 electronic-circuit, 25 advanced-circuit, 25 tungsten-plate, 6 processing-unit, 9 resonance-crystal |
| Tourelle laser | 15 s → 6 min 24 s | 10 steel-plate, 10 electronic-circuit, 6 battery | 430 steel-plate, 370 electronic-circuit, 150 battery, 40 advanced-circuit, 40 tungsten-plate, 9 processing-unit, 15 resonance-crystal |
| Mur | instantané | 4 stone-brick | 100 stone-brick, 10 steel-plate, 8 electronic-circuit, 3 advanced-circuit, 3 tungsten-plate, 1 processing-unit, 1 resonance-crystal |
| Foreuse électrique | 12 s → 5 min 07 s | 20 iron-plate, 10 iron-gear-wheel, 6 electronic-circuit | 510 iron-plate, 260 iron-gear-wheel, 225 electronic-circuit, 110 steel-plate, 25 advanced-circuit, 25 tungsten-plate, 6 processing-unit, 9 resonance-crystal |
| Four en acier | 10 s → 4 min 16 s | 6 steel-plate, 10 stone-brick | 260 steel-plate, 260 stone-brick, 75 electronic-circuit, 25 advanced-circuit, 25 tungsten-plate, 6 processing-unit, 9 resonance-crystal |
| Machine d'assemblage 2 | 15 s → 6 min 24 s | 20 iron-plate, 10 iron-gear-wheel, 10 electronic-circuit | 510 iron-plate, 260 iron-gear-wheel, 335 electronic-circuit, 110 steel-plate, 25 advanced-circuit, 25 tungsten-plate, 6 processing-unit, 9 resonance-crystal |

**Design par niveau : REJETÉ** (E25 : « je ne vois QUE un changement de couleur/teinte »). La ladder de
matériaux peut servir de code couleur d'appoint. La forme est la règle : voir OBJECTIFS.md D1.
Ancienne ladder (même code couleur pour toutes les familles) :
1 fer (vanilla) · 2 acier bleuté + socle de pavés · 3 cuivre + béton · 4 or + béton raffiné · 5 jade + lueur ·
6 améthyste + halo de nuit · 7 obsidienne à lueur de braise + socle de béton de sécurité · 8 rubis ·
9 saphir · 10 or blanc, socle doré, lueur et halo maximaux. Taille du sprite + 1,2 % par niveau. Le centre
de commandement gagne une antenne de balise au niveau 4, une seconde et un radar agrandi au niveau 7.
