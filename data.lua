-- Étape data : déclaration de prototypes uniquement. Aucune logique runtime ici.

require("prototypes.companion.body")
require("prototypes.world")
require("prototypes.titanium")
require("prototypes.superconductors")
-- Lot AMELIO-CRAFTS (intégration 0.6.22, déplacé depuis la fin de prototypes/titanium.lua comme le demandait le lot) : chaînes des
-- âges 2 à 11 ; APRÈS les supraconducteurs (les torchères de l'oxygène prennent l'icône des fluides de X2), AVANT les pistes de
-- RESSOURCES qui s'en servent (galène, étain, combustible usé, bauxite, géothermie, zinc).
require("prototypes.crafts")
require("prototypes.galena") -- lot AMELIO-RESSOURCES : plomb (âge 9), thorium (âge 12)
require("prototypes.tin") -- lot AMELIO-RESSOURCES, piste ÉTAIN : carte imprimée (âge 4, X3) ; après prototypes.crafts
require("prototypes.spent_fuel") -- lot AMELIO-RESSOURCES : combustible usé de l'âge 9 (piscine, vitrification, dépôt)
require("prototypes.bauxite") -- lot AMELIO-RESSOURCES, piste BAUXITE : aluminium (âge 6, X3), pylône haute tension (X0) ; après prototypes.crafts
require("prototypes.geothermal") -- lot AMELIO-RESSOURCES, piste GÉOTHERMIE : fumerolle, capteur, vapeur et soufre (âge 5, X0) ; après prototypes.crafts
require("prototypes.zinc") -- lot AMELIO-RESSOURCES, piste ZINC : blende, zinc, laiton, manomètre à tube de Bourdon (âge 3, X3) ; après prototypes.crafts
require("prototypes.compute") -- lot CALCUL (30/10) : puces, processeur, mémoire, carte mère, baies, carte graphique, processeur quantique, centre de calcul ; après étain, bauxite, X2 et CRAFTS
require("prototypes.compute_v2") -- lot CALCUL-V2 (30/10) : une machine par étape, centre de calcul modulaire (baies) ; juste après prototypes.compute
require("prototypes.modules")
require("prototypes.enemies")
require("prototypes.arsenal")
require("prototypes.arsenal_special")
require("prototypes.faction")
require("prototypes.robot_parts") -- lot RB-4 (1/11) : pièces d'X3 des robots (servomoteur, capteur, contrôleur, noyau, actionneur, module laser) ; après compute, bauxite, tin, superconductors
require("prototypes.robots") -- lot RB-1 (31/10) : robots, atelier d'automates, kit, unités par propriétaire ; après prototypes.enemies
require("prototypes.levels")
require("prototypes.tirs") -- lot TIRS : effets de tir par âge (explosions, traçantes) et effet script des chargeurs
require("prototypes.vitrine")
require("prototypes.debug_cerveau") -- lot DEBUG-CERVEAU : bouton de raccourci et touche de la vue « Cerveau »
require("prototypes.gui") -- lot IA1-i : raccourci et touche de l'interface « Équipe et factions »
require("prototypes.dezoom") -- dézoom étendu : Ctrl + molette, deux touches
require("prototypes.commande") -- lot s43 UX-COMMANDE : outil de commandement
require("prototypes.bourdon") -- lot BOURDON : l'expérimental de l'âge 15, sprites, effets, son, touche
require("prototypes.experimentaux") -- lot EXPERIMENTAUX : les expérimentaux de la famille EXP2 (Mât-Foudre, Géode, Sarracénie, Demi-Vie, Veilleuse) ; après prototypes.robots
