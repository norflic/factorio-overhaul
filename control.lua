--[[
  Point d'entrée runtime. Règle d'architecture : ce fichier ne contient QUE du câblage.

  L'ordre des require fixe :
    1. l'ordre d'initialisation des namespaces de stockage (Storage.declare) ;
    2. l'ordre d'exécution des handlers d'un même événement (ex. on_tick : scheduler puis pompe de pathfinding).
  Tous les handlers sont enregistrés statiquement, à l'identique en on_init et on_load (pas d'enregistrement
  conditionnel : c'est la source n°1 de désynchronisation en multijoueur).
]]

local Events = require("script.core.events")

-- Socle (indépendant de tout gameplay)
require("script.core.storage")
require("script.core.config")
require("script.core.profiler")
require("script.core.scheduler")
require("script.core.path_service")

-- Agents riches : données, déplacement, rendu, navigation, décision
require("script.companion.registry")
require("script.companion.locomotion")
require("script.companion.render")
require("script.agents.nav")
require("script.companion.brain")
require("script.companion.bench")

-- Monde : dangers et bienfaits des biomes, mécaniques des déchiqueteurs
require("script.world.hazards")
require("script.world.enemy_mechanics")
require("script.world.guarantee") -- lot M0 : monnaies des époques 5, 7 et 8 garanties sur toute carte
require("script.world.explosions_mort") -- lot X10, Q5 et Q5b : explosions de mort recréées près d'un joueur seulement

-- Factions IA (pilier 2) : état, équipes (cerveau d'équipe, tâches, ouvriers), commandant, guerre
require("script.faction.state")
require("script.team.board")
require("script.team.worker")
require("script.team.team")
require("script.team.player_team")
require("script.team.ia1_remote") -- lot IA1-a : mesures des équipes (interface « fo-ia1 », lecture seule)
require("script.ai3.comportement") -- lot IA3-k : comportements visibles (crochets de script/team/worker.lua)
require("script.ai3.soldats") -- lot IA3-k : rôles des soldats (patrouille, garde, escorte, nettoyage, défense)
require("script.faction.commander")
require("script.faction.war")
require("script.ai3.exploration") -- lot IA3-f : carte de connaissance, yeux des PNJ, éclaireurs (exploration sous brouillard)
require("script.ai3.jalons") -- lot VIDEO-TRACES (V03) : journal [FO-JALON], époque atteinte par chaque faction

-- Mode défense de tours (activable à tout moment)
require("script.td.director")

-- Niveaux de bâtiments façon Clash of Clans : centre de commandement, chantiers, panneau « Évolution »
require("script.levels.levels")
require("script.levels.panel")
require("script.scenario.journal") -- piste SCENARIOS : journal d'époque (intro, Codex, objectifs, /fo-journal)

-- Modules multiplicatifs (lot MOD-1, D-15) : balise cachée de complément par machine, balayage tournant
require("script.modules.mult")

-- Calcul (lot CALCUL, D-19, D-20 (4)) : centres de calcul lus toutes les 60 ticks, calcul non stockable, bonus de recherche
require("script.compute.compute")

-- Tirs des tourelles par âge (lot TIRS) : bouche, traçante, impact et trait des âges de shared/tirs/ages.lua
require("script.tirs.tirs")

-- Interface de gestion en jeu « Équipe et factions » (lot IA1-i) : raccourci, touche Maj + T, onglets
require("script.gui.team_window")

-- Dézoom étendu : Ctrl + molette écrit player.zoom sous la limite de la molette (shared/gui/dezoom.lua)
require("script.gui.dezoom")
require("script.debug.cerveau") -- lot DEBUG-CERVEAU (8/11) : vue « Cerveau » par joueur (zones, écart IA / réel, décisions, améliorations), rien sans spectateur

-- Robots (lot RB-1, 31/10) : ateliers, kits en unités, plafond en points, ordres du joueur
require("script.robots.usine")
require("script.robots.faction") -- lot RB-3 : la demande de robots des factions (au mall d'INDUSTRIE)
require("script.robots.outils") -- lot RB-2 : outils de sélection, ralliement, alerte de pertes (l'interface : script/gui/robots.lua, via la fenêtre)
-- Le Bourdon, expérimental de l'âge 15 (lot BOURDON) : démonstration, /fo-bourdon, /fo-glas
require("script.robots.bourdon")
require("script.robots.experimentaux") -- lot EXPERIMENTAUX : effets, lancer des capsules, interface « fo-xp »

-- Lot VIDEO (0.6.61) : migration UNIQUE des quatre réglages de carte de la vidéo dans une partie d'avant la 0.6.61
require("script.ai3.video_reglages")
require("script.ai3.ouvriers_reglage")

-- Pilotage sans joueur (tests automatisés, scénarios)
require("script.remote")

Events.bind()
