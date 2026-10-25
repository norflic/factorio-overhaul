--[[
  Équipes IA : économie RÉELLE (objets du jeu, bâtiments qui tournent). Pur Lua, partagé par le runtime et
  les tests hors-jeu.

  Une équipe = un QG (coffre : le STOCK de l'équipe), des OUVRIERS (corps "character" qui marchent, minent,
  fabriquent, posent des bâtiments, ravitaillent, se défendent) et des SOLDATS (unités) équipés avec des
  objets fabriqués par l'équipe. Un CERVEAU D'ÉQUIPE unique (shared/team/planner.lua) sait ce qu'il reste à
  faire et comment le faire ; les ouvriers exécutent ses tâches.
]]

local T = {}

---------------------------------------------------------------------------------------------------
-- Stock de départ (dans le QG) : de quoi lancer charbon et fer sans attendre, comme l'épave du joueur.
---------------------------------------------------------------------------------------------------
T.start_kit = {
  { "burner-mining-drill", 12 }, { "stone-furnace", 8 }, { "iron-chest", 4 },
  { "coal", 150 }, { "iron-plate", 200 }, { "copper-plate", 60 }, { "stone", 80 },
  { "firearm-magazine", 40 },
}
T.start_smelters = 2       -- fours posés au QG dès la fondation (fonderie : minerai d'appoint, acier, briques)
T.hq_inventory = 200
-- Avant IA1-a : 2 ouvriers de départ et « 2 + 1 par avant-poste » (T.workers_wanted). Depuis IA1-a, le départ
-- est le réglage fo-npc-start (8) et le plafond fo-war-workers (shared/team/scale.lua) ; ces valeurs ne servent
-- plus qu'aux vues construites sans les champs IA1-a (tests d'avant IA1-a).
T.start_workers = 2

---------------------------------------------------------------------------------------------------
-- Équipements (« s'armer ») : un ouvrier ou un soldat n'existe que si son équipement a été fabriqué.
---------------------------------------------------------------------------------------------------
T.kits = {
  worker    = { { "pistol", 1 }, { "firearm-magazine", 10 } },
  rifleman  = { { "submachine-gun", 1 }, { "firearm-magazine", 5 } },
  gunner    = { { "submachine-gun", 1 }, { "piercing-rounds-magazine", 5 }, { "light-armor", 1 } },
  rocketeer = { { "grenade", 8 }, { "light-armor", 1 } }, -- grenadier (clé historique « rocketeer »)
}
-- Munitions que l'ouvrier garde sur lui pour se défendre (prélevées de son équipement).
T.worker_gun = "pistol"
T.worker_ammo = "firearm-magazine"
T.worker_ammo_keep = 10

---------------------------------------------------------------------------------------------------
-- Avant-postes : foreuses à combustible (alimentées en charbon par les ouvriers) ; minerais fondus sur place.
---------------------------------------------------------------------------------------------------
T.DRILL = "burner-mining-drill"
T.drill_drop = { -0.5, -1.3 } -- vector_to_place_result vanilla de la foreuse à combustible (orientation nord)
T.outposts = {
  coal   = { resource = "coal",       sink = "iron-chest",    product = "coal",         drills = 4 },
  iron   = { resource = "iron-ore",   sink = "stone-furnace", product = "iron-plate",   drills = 8 },
  copper = { resource = "copper-ore", sink = "stone-furnace", product = "copper-plate", drills = 3 },
  stone  = { resource = "stone",      sink = "iron-chest",    product = "stone",        drills = 2 },
}
T.OUTPOST_ORDER = { "coal", "iron", "copper", "stone" }
-- Un avant-poste s'agrandit sur son gisement jusqu'à 12 foreuses avant qu'on en cherche un autre (moteur
-- réel : à 480 tuiles du centre, la carte n'offre souvent qu'un gisement de chaque minerai par faction).
-- Un palier « N avant-postes de fer » se lit donc « N × drills foreuses de fer ».
T.outpost_max_drills = 12
-- Session 4, moteur réel (E16 it. 8) : le fer est le goulot de toute l'échelle (armée, recherche) ; le
-- gisement de fer de départ est plus large et accueille 20 foreuses, la pierre (peu demandée) 8.
T.outpost_max = { iron = 20, stone = 8 }
function T.max_drills(kind) return T.outpost_max[kind] or T.outpost_max_drills end
-- Rayon des gisements de la zone de départ, par type d'avant-poste (tuiles).
T.seed_radius = { coal = 8, iron = 11, copper = 8, stone = 6 }
T.fuel = "coal"
T.fuel_per_burner = 5       -- charbon posé à la construction et visé à chaque ravitaillement
T.fuel_refill_to = 10       -- le ravitailleur complète chaque brûleur jusqu'à 10 charbons
T.fuel_low = 3              -- en dessous : ravitaillement urgent
T.collect_at = 40           -- production en attente qui justifie une tournée
T.service_period = 3 * 3600 -- tournée d'entretien au moins toutes les 3 minutes

-- Fonderie du QG : fours alimentés par les ouvriers (acier, briques, minerai d'appoint).
T.SMELTER = "stone-furnace"
T.smelter_inputs = {        -- produit visé -> (entrée, quantité d'entrée par produit)
  ["steel-plate"] = { "iron-plate", 5 },
  ["stone-brick"] = { "stone", 2 },
  ["iron-plate"] = { "iron-ore", 1 },
  ["copper-plate"] = { "copper-ore", 1 },
}

-- Tourelles : munitions visées par tourelle, seuil de ravitaillement.
T.turret_ammo_target = 20
T.turret_ammo_low = 8
-- Les tourelles reçoivent des chargeurs standard (bon marché) ; l'acier va aux mitrailleurs.
T.turret_ammo = "firearm-magazine"

-- DÉFENDRE D'ABORD (lot IA1-b2, décision D-17 du 25/10 : « l'équipe pose des tourelles à un avant-poste AVANT d'y
-- envoyer des ouvriers »). Tourelles voulues par avant-poste : 1, plus 1 par tranche de 8 foreuses (un avant-poste qui
-- s'agrandit pollue plus et attire plus d'attaques : il se défend de nouveau avant le prochain agrandissement).
-- Posées pleines (T.defend_ammo = T.turret_ammo_target chargeurs chacune : Outposts.fortify remplit la première tourelle
-- avant la suivante, une demi-dose la laissait vide). Priorité T.defend_prio : URGENCE (O.URGENT_PRIO = 90), prise par
-- n'importe quel PNJ, comme le ravitaillement.
T.defend_ammo = T.turret_ammo_target
T.defend_prio = 90
-- Votre équipe suit toujours « défendre d'abord » ; les factions seulement si T.defend_first_factions. Mesuré au lot
-- IA1-b2 (essais 1 à 3, protocole 30 contre 10, moteur réel) : à 30 PNJ, la règle aide les factions (tués par les ennemis
-- 83 -> 25 à 54, production +9 à +20 %) ; à 10 PNJ, elle nuit (production -7 à -11 %, tués 19 -> 12 à 28) ; et au
-- moteur simulé (tests/pvp_test.lua) elle casse l'ordre des attaques par difficulté (Impitoyable 3 attaques, Difficile 4).
-- Une partie normale (guide : 4 ouvriers par faction) ressemble au cas 10 : NON appliquée aux factions (décision au DC).
T.defend_first_factions = false
-- Recrues retenues T.recruit_calm ticks après la perte d'un PNJ (0 : jamais). Essayé à 60 s (essais 1 à 4 du lot) : moins
-- de recrues tuées à leur arrivée, mais pendant une longue attaque du QG l'équipe restait sous son effectif de départ
-- avec du fer (verif-guide graine 1618033988 : 5 min de suite, ECHEC du contrôle de reconstruction) et le QG, moins
-- gardé, tombait. COUPÉ.
T.recruit_calm = 0
-- Avant-poste MEURTRIER : un PNJ tué en y allant ; sans ses tourelles, plus personne n'y va pendant 10 min (ni tournée,
-- ni agrandissement, ni fond), sauf pour y poser les tourelles.
T.lethal_ticks = 10 * 3600
-- Tourelles du QG (posées d'abord) et fer gardé pour les recrues : la défense ne fabrique pas sous ce plancher.
T.defend_hq = 2
T.defend_iron_floor = 150
function T.defend_turrets(drills) return 1 + math.floor((drills or 0) / 8) end

---------------------------------------------------------------------------------------------------
-- Recherche : niveaux payés en VRAIS packs de science, fabriqués par l'équipe.
-- Le pack chimique demande du pétrole : les niveaux 4-5 attendent l'objectif Pétrole.
---------------------------------------------------------------------------------------------------
T.research = {
  [1] = { { "automation-science-pack", 30 } },
  [2] = { { "automation-science-pack", 50 }, { "logistic-science-pack", 40 } },
  [3] = { { "automation-science-pack", 80 }, { "logistic-science-pack", 60 }, { "military-science-pack", 30 } },
  [4] = { { "automation-science-pack", 120 }, { "logistic-science-pack", 100 }, { "military-science-pack", 60 }, { "chemical-science-pack", 40 } },
  [5] = { { "automation-science-pack", 200 }, { "logistic-science-pack", 160 }, { "military-science-pack", 100 }, { "chemical-science-pack", 100 } },
}

---------------------------------------------------------------------------------------------------
-- Objectifs d'équipe, dans l'ordre. Le cerveau poursuit le premier objectif non atteint (en continuant
-- d'entretenir ce qui existe) ; une fois l'échelle gravie, il entretient et étend.
--   outposts = { [type] = nombre }, smelters = n, tech = n, soldiers = n, stock = { [objet] = n },
--   outpost_turrets = n (tourelles par avant-poste)
---------------------------------------------------------------------------------------------------
T.ladder = {
  { key = "coal",     need = { outposts = { coal = 1 } } },
  { key = "iron",     need = { outposts = { iron = 1 } } },
  { key = "copper",   need = { outposts = { copper = 1 } } },
  { key = "stone",    need = { outposts = { stone = 1 } } },
  { key = "defense",  need = { stock = { ["firearm-magazine"] = 60 } } },
  { key = "army",     need = { soldiers = 10 } },
  { key = "iron2",    need = { outposts = { iron = 2, coal = 2 } } },
  { key = "tech1",    need = { tech = 1 } },
  { key = "smelter",  need = { smelters = 4 } },
  { key = "army2",    need = { soldiers = 25 } },
  { key = "iron3",    need = { outposts = { iron = 3, copper = 2, coal = 3 } } },
  { key = "tech2",    need = { tech = 2 } },
  { key = "fortify",  need = { outpost_turrets = 1 } },
  { key = "iron4",    need = { outposts = { iron = 4, coal = 4, stone = 2 } } },
  { key = "tech3",    need = { tech = 3 } },
  { key = "expand",   need = { outposts = { iron = 5, copper = 3, coal = 5 } } },
  { key = "oil",      need = { tech = 4 } }, -- pétrole : pack chimique (étape suivante du chantier)
}
-- Équipe du JOUEUR (compagnons au travail autour du coffre d'équipe) : pas d'armée ni de recherche (le
-- joueur recherche lui-même), une économie qui grandit et qui se défend.
T.player_ladder = {
  { key = "coal",     need = { outposts = { coal = 1 } } },
  { key = "iron",     need = { outposts = { iron = 1 } } },
  { key = "copper",   need = { outposts = { copper = 1 } } },
  { key = "stone",    need = { outposts = { stone = 1 } } },
  { key = "defense",  need = { stock = { ["firearm-magazine"] = 60 } } },
  { key = "iron2",    need = { outposts = { iron = 2, coal = 2 } } },
  { key = "smelter",  need = { smelters = 4 } },
  { key = "copper2",  need = { outposts = { copper = 2 } } },
  { key = "fortify",  need = { outpost_turrets = 1 } },
  { key = "iron3",    need = { outposts = { iron = 3, copper = 2, coal = 3, stone = 2 } } },
  { key = "expand",   need = { outposts = { iron = 4, copper = 3, coal = 4 } } },
}
T.player_workers_max = 8 -- avant IA1-a ; remplacé par le réglage fo-player-team-npc-max (30)

-- Patience : un objectif sans progrès pendant 12 min est mis de côté 15 min (gisement introuvable, chemin
-- impossible...) ; l'équipe passe au suivant au lieu de rester bloquée.
T.goal_patience = 12 * 3600
T.goal_defer = 15 * 3600

-- Technologies vanilla débloquées pour la force de l'équipe à chaque niveau (recettes fabricables).
T.unlocks = {
  -- Lot PNJ-VÉRIF : la technologie des tourelles s'appelle « gun-turret » en 1.1.91 (« turrets » n'existe pas :
  -- unlock() l'ignorait et aucune faction ne pouvait fabriquer de tourelle). Contrôle : harness, « T.unlocks ».
  [0] = { "military", "gun-turret", "stone-wall" },
  [1] = { "logistic-science-pack", "steel-processing", "military-2", "heavy-armor", "physical-projectile-damage-1", "weapon-shooting-speed-1" },
  [2] = { "military-science-pack", "rocketry", "physical-projectile-damage-2", "weapon-shooting-speed-2", "gate" },
  [3] = { "military-3", "physical-projectile-damage-3", "weapon-shooting-speed-3", "stronger-explosives-1" },
  [4] = { "physical-projectile-damage-4", "weapon-shooting-speed-4" },
  [5] = { "physical-projectile-damage-5", "weapon-shooting-speed-5" },
}

-- Taille d'armée visée (après l'objectif "army") selon la personnalité (facteur de soldiers_max).
T.army_share = { conqueror = 0.8, technocrat = 0.45, builder = 0.4, balanced = 0.6 }
T.kit_batch = 5             -- équipements fabriqués par lot

-- Ouvriers voulus : 2 + 1 par avant-poste, plafonné par engineers_max.
function T.workers_wanted(outposts, max)
  return math.min(max, T.start_workers + outposts)
end

return T
