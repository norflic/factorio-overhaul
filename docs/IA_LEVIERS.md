# Les leviers de capitalisation (lot LEVIERS)

Règle pure : `shared/ai3/leviers.lua` (appelée par `shared/ai3/capitalisation.lua`). Tests : `tests/leviers_test.lua`
(règle, 16 mutants), `tests/leviers_exec_test.lua` (exécutant). Exécutant : `script/team/equiper.lua`. Banc en moteur réel :
`scenarios/leviers-modules.lua`.

## La demande (DC, 27/10, vers 21 h 30)

« la recherche des drones pour augmenter la vitesse de construction et la précision des améliorations, peut-être que c'est
aussi une manière de capitaliser. Il faudrait définir plein de conditions différentes de comment capitaliser en quelles
circonstances en fonction du gain que ça peut apporter » ; et, si tous les points de ressources sont pris ou trop
dangereux : « c'est peut-être plus rentable de ajouter des modules de vitesse à des fours ou des modules de productivité à
des foreuses ».

## Ce qui existait

Les leviers de la capitalisation étaient `couvrir`, `ouvrir`, `fours`, `chaine`, `packs`, `labos`, `energie`. Les
recherches à effet (`mining-drill-productivity-bonus`, `laboratory-speed`, `worker-robot-speed`…) n'avaient qu'un poids
FIXE de rôle (`R.MODIFIER_ROLE`, `Gen.V_BONUS`). Aucun exécutant de modules chez les factions.

## Le catalogue (lu dans les DONNÉES, rien en dur)

| Levier | Données lues | Gain (MU/min) | Coût |
|---|---|---|---|
| `equiper` : modules dans des machines posées | effets de chaque module en centièmes (`module_effects`), recettes permises (`limitations`), emplacements et effets permis de chaque machine (`module_inventory_size`, `allowed_effects`), modules déjà posés | sortie de plus × valeur de l'objet, bornée par la demande (+ 25 % d'avance), moins l'énergie de plus | modules (MU) + pose (PNJ-s) |
| `techno` : recherche à effet | types de `R.LEVER_EFFECT`, valeur du modificateur, packs, durée, prérequis | capacité de plus × valeur (foreuses : minerai ; laboratoires : secondes de recherche ; travail : PNJ-min × production par PNJ) | packs et secondes de laboratoire (MU), RETARD = temps de recherche aux laboratoires posés |

- **Barème D-17 de MOD-1** (`shared/content/module_mult.lua`) : facteurs de vitesse, de productivité et d'énergie
  MULTIPLIÉS, énergie au plafond comprise. Sortie de plus par machine : `débit × (S' × P' − S × P)`, `S` et `P` en rapport à 1
  avant et après la pose.
- **Une vitesse de plus exige l'entrée de plus** : la part servie est bornée par le minerai livré (hors main et stock) ou
  l'ingrédient couvert. Sans entrée de plus, seul un module de productivité rapporte.
- **Le module doit être obtenable** : au coffre ou fabricable à la main aujourd'hui. Sinon l'option rentable est refusée
  « recherche : <module> » et le module est DEMANDÉ à la recherche (`res.want` → `Auto.want`).
- **Part de l'étage = 1** : un module s'ajoute à une chaîne qui existe (machines posées, entrée livrée) ; la valeur de la
  sortie de plus lui revient en entier (une machine neuve la partage avec son amont : `Ca.share`).

## Les circonstances

Chaque ordre de levier porte `repli` quand la ressource brute derrière son objet n'a plus de place : tous ses gisements
sont couverts, dangereux, interdits ou épuisés (ou aucun n'est connu : « absente »). Le retour accepté devient alors
l'horizon d'un gisement (`Ca.H_LIFE`, 60 min ; ÷ 4 sous menace) au lieu de `T_max` du caractère : sans autre
investissement possible pour la même demande, un levier qui se rembourse vaut mieux que rien. Hors repli, `T_max` du
caractère s'applique comme pour une machine. La construction « goulot » (bras libres épuisés) donne son plein gain à la
recherche du travail des PNJ ; sinon 25 %. Le tri reste celui de la règle (retour `T`, profondeur, clé) : l'extraction, de
retour plus court, passe avant tant qu'un site est libre.

`res.repli` = `{ blocked, levers, refus, none, text }` : ressources bloquées (besoin, fourni, gisements), leviers retenus,
refus, ou RAISON de n'en avoir aucun (« aucune machine à emplacements dans les données », « aucun module ne rapporte
assez »…). Journal : `[FO-CERVEAU] <faction> : repli : …`, écrit quand la SITUATION change (ressources bloquées, leviers),
jamais à l'horloge.

## Exécution

- `equiper` : le cerveau (`Capi.think`) retrouve les machines du groupe décidé au relevé de la minute, poste une tâche
  `equiper` par lot de 6 machines (`Equip.BATCH`), dès que les modules sont au coffre ; le PNJ les prend (prise stricte),
  marche jusqu'à chaque machine, les insère (`can_insert` du moteur) et la balise cachée du barème est recalculée tout de
  suite (`Mult.refresh`). Le résultat est écrit dans l'ordre ouvert (`inserted`, `refused`, `why_refused`). Aucun module posé
  sans le travail d'un PNJ.
- `techno` : l'ordre ouvert donne à la technologie `Gen.V_WANTED` dans le choix de la recherche (`ctx.levers` de `Gen.choose`),
  au lieu du poids fixe de rôle. Fini quand la technologie est faite ; abandonné après 30 min sans progrès (repli de 10 min
  × 2^refus).
- Un ordre refusé par l'exécutant n'est pas redemandé tout de suite (`input.skip`, repli exponentiel de `Capi.BACKOFF`).

## Défauts et limites (à ne pas cacher)

- Un seul type de module par groupe et par ordre (le suivant se décide après la pose). Pas de mélange vitesse + productivité
  décidé d'un coup.
- Les gains chiffrés sont en MU/min de la règle X0 ; la valeur d'une seconde de laboratoire ou d'un PNJ-minute vient des
  mêmes estimations que le reste de la capitalisation, pas d'une mesure.
- Le retour du repli (60 min) est un choix de conception, non calibré en jeu.
- `fo-capi block_sites` (banc seulement) déclare les gisements interdits ; la détection du danger elle-même n'est pas touchée.
- Pollution, sous-produits et recettes à plusieurs produits : ignorés (comme le reste de la règle).
- Les techs « drones » : seuls les types de `R.LEVER_EFFECT` comptent ; `worker-robot-storage` (une quantité, pas une
  fraction) est écarté.

## Recherche qui débloque une meilleure machine (28/10)

Entrée `input.successors` = machines supérieures de chaque machine posée, lues aux prototypes par le lot AMELIORER
(`Capital.successors_of`, aucune logique de successeur ici). Pour chaque machine posée dont un successeur n'est pas encore
fabricable, la technologie qui le débloque (`D.unlocked_by`) est chiffrée : gain = vitesse supérieure × machines posées, borné
par la demande (+ 25 % d'avance, et par l'entrée de plus : minerai livré, ingrédient couvert) ; coût = packs et secondes de
laboratoire de la technologie ET de ses prérequis non faits + machines neuves ; retour = coût ÷ gain + retard, accepté jusqu'à
l'horizon d'un gisement (60 min). Une technologie retenue (`res.unlocks`) donne à toute sa chaîne la valeur d'un objet voulu
(`Capi.techs_wanted` → `Gen.choose`, sans le quart des machines « pour plus tard »). Journal : `[FO-CERVEAU] … recherche … pour …`.
Mesuré en moteur réel (4 graines, etape1-guide, avec ameliorer) : le choix de la recherche du four d'acier tombe avant 30 min
pour 5 forces sur 8 qui ont au moins 6 fours (0 sur 8 au témoin) ; palier 2 inchangé (médiane 11,8 min), palier 3 19,25 → 20,0 min.
Défaut : le choix n'est pas la fin de la recherche (non mesurée) ; votre équipe n'atteint jamais 6 fours dans ces parties.
