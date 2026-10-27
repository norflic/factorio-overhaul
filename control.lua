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

-- Factions IA (pilier 2) : état, équipes (cerveau d'équipe, tâches, ouvriers), commandant, guerre
require("script.faction.state")
require("script.team.board")
require("script.team.worker")
require("script.team.team")
require("script.team.player_team")
require("script.team.ia1_remote") -- lot IA1-a : mesures des équipes (interface « fo-ia1 », lecture seule)
require("script.ai3.comportement") -- lot IA3-k : comportements visibles (crochets de script/team/worker.lua)
require("script.faction.commander")
require("script.faction.war")

-- Mode défense de tours (activable à tout moment)
require("script.td.director")

-- Niveaux de bâtiments façon Clash of Clans : centre de commandement, chantiers, panneau « Évolution »
require("script.levels.levels")
require("script.levels.panel")

-- Modules multiplicatifs (lot MOD-1, D-15) : balise cachée de complément par machine, balayage tournant
require("script.modules.mult")

-- Interface de gestion en jeu « Équipe et factions » (lot IA1-i) : raccourci, touche Maj + T, onglets
require("script.gui.team_window")

-- Pilotage sans joueur (tests automatisés, scénarios)
require("script.remote")

Events.bind()
