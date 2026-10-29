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
-- Lot KIT (28/10, réponse du DC : « idéalement il faudrait vraiment pas leur donner de ressources : ils ne doivent pas avoir
-- plus que le joueur principal, ils doivent eux-mêmes récolter les ressources nécessaires au début ; évidemment pour les
-- tests c'est beaucoup plus simple qu'ils aient des ressources de base »). Le kit de départ d'une faction est celui de
-- votre équipe : AUCUN objet au coffre, AUCUN four posé (seuls les fo-npc-start ouvriers armés, T.kits.worker, sont
-- communs). Source unique des deux équipes : shared/team/fondation.lua (F.grant). Le kit GÉNÉREUX d'avant (de quoi lancer
-- charbon et fer sans attendre, comme l'épave du joueur) ne sert plus qu'aux bancs : réglage fo-war-kit-genereux,
-- allumé par tools/autotest/fo-autotest/control.lua. Les 50 bois du lot PLANDIR sont retirés (le bois se récolte).
T.start_kit = {}
T.start_smelters = 0
T.start_kit_generous = {
  { "burner-mining-drill", 12 }, { "stone-furnace", 8 }, { "iron-chest", 4 },
  { "coal", 150 }, { "iron-plate", 200 }, { "copper-plate", 60 }, { "stone", 80 },
  { "firearm-magazine", 40 },
}
T.start_smelters_generous = 2 -- fours posés au QG dès la fondation (fonderie : minerai d'appoint, acier, briques)
T.hq_smelters = 2             -- taille de la fonderie du QG reposée en secours (planificateur, manque de plaques)
-- Lot KIT (décision de l'orchestrateur, 28/10, veto possible du DC) : une faction n'a pas de technologie au départ (votre
-- équipe n'en a pas : elle recherche « gun-turret »). EXCEPTION DOCUMENTÉE : les 4 tourelles de QG (chargées de 20 chargeurs,
-- script/faction/war.lua) restent offertes aux factions, plancher de défense : aucun joueur humain ne défend une faction, et
-- sans elles l'économie de fer sans stock ne tient pas la défense du début (mesuré en moteur réel, etape1-guide 123456789 :
-- 0 soldat et 0 tourelle à 60 min pour les deux factions, contre 5 à 7 et 5 à 6 sur main). Votre équipe n'en reçoit jamais.
T.start_hq_turrets = 4
T.start_hq_turrets_generous = 4
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
-- Lot SCALE (correction après revue, 27/10) : DISPOSITION des machines du QG en rangées. Règle : shared/ai3/places.lua
-- (PURE, sans nom du jeu) ; le PAS est l'emprise du prototype posé (sa collision_box, lue au runtime) plus l'écart ci-
-- dessous : aucune position n'est écrite pour une taille de bâtiment. Le bloc de départ (first = { colonnes, places })
-- redonne, avec les emprises du jeu de base (four 2 × 2, laboratoire 3 × 3), EXACTEMENT les places de main 0.6.1
-- (outposts.lua, SMELTER_OFFSETS ; script/ai3/cerveau.lua, LAB_OFFSETS), dans leur ordre : une partie en cours garde ses
-- places ; la suite prolonge les rangées (tests/scale_test.lua §8). Chaque place est recalée sur la grille du bâtiment et
-- vérifiée avant la pose (script/ai3/places_qg.lua) ; search : rayon de la recherche de SECOURS autour d'une place des
-- rangées quand toutes sont prises (terrain encombré), celui de main 0.6.1 (4 tuiles pour les fours, 8 pour les
-- laboratoires).
T.hq_rows = {
  -- Fonderie, à l'est du coffre du QG (main) : fours JOINTIFS dans une rangée (écart 0 : un PNJ les garnit à la main,
  -- aucun bras entre eux), une allée d'une tuile entre deux rangées (le PNJ y passe) ; rangées vers le nord ; 8 fours
  -- par rangée (la rangée de main, 4 fours, prolongée vers l'est : le bloc reste à moins de 16 tuiles du coffre).
  smelter = { origin = { 9, -7 }, dir = { 1, -1 }, gap = { 0, 1 }, first = { 4, 6 }, per_row = 8, search = 4 },
  -- Laboratoires, à l'ouest du coffre (main) : une tuile libre autour de chacun (main : on les garnit à la main de tous
  -- les côtés) ; rangées vers le nord ; 4 par rangée (le carré de main, 2 × 2, prolongé vers l'ouest).
  lab = { origin = { -10, -7 }, dir = { -1, -1 }, gap = { 1, 1 }, first = { 2, 4 }, per_row = 4, search = 8 },
}
-- Places générées : au moins 2 fois les machines voulues (une place peut être prise : coffre, tourelles du QG, foreuses
-- de fond, chantier en cours ; la place prise est sautée par find_non_colliding_position).
T.hq_rows_slack = 2
-- ANNEXES du QG (lot COFFRE, constat du DC du 27/10, 18 h 50 : « le coffre est complètement rempli depuis un bon moment mais
-- il est jamais vidé, il y a jamais d'autres coffres alors qu'il y a 15 coffres [en stock] »). Le coffre du QG a un nombre de
-- cases fini (T.hq_inventory ; 96 pour le coffre de votre équipe) : plein, plus aucun ouvrier ne peut y déposer et la partie
-- s'arrête. Des coffres supplémentaires se posent donc autour du QG (bloc `T.annex.block`, côté extérieur) dès que les cases se
-- remplissent ; le STOCK de l'équipe est le coffre du QG ET ses annexes (script/team/stock.lua : toute lecture, prise et
-- dépôt passe par là). Données (aucun objet écrit dans le cerveau) :
--   kinds    : coffres posables, dans l'ordre de préférence ; `slots` = cases (pour estimer le besoin) ; `cheap` = ne coûte
--              aucune plaque (fabricable même quand le cerveau manque de plaques) ;
--   grow_at  : remplissage (cases prises / cases) du total QG + annexes à partir duquel un coffre se pose ;
--   park_at  : remplissage du coffre du QG à partir duquel l'excédent passe aux annexes, jusqu'à park_to ;
--   keep     : piles d'un même objet laissées dans le coffre du QG au rangement (le reste, par piles entières, part aux annexes) ;
--   max      : annexes au plus (= les places du bloc ci-dessous au sud ; A.capacity les recompte selon la face et l'emprise) ;
--   early_*  : AGRANDISSEMENT RÉGULIER (lot STOCKAGE, remarque 9 du DC : « agrandir régulièrement le stockage »). Sans attendre
--              grow_at, un coffre de plus se pose quand le total QG + annexes reste à early_at ou plus pendant early_ticks de
--              suite (la fenêtre repart si le remplissage tombe sous early_keep, et repart à chaque pose : au plus un coffre
--              toutes les 5 min par ce chemin), OU quand un dépôt a été refusé il y a moins de refused_ticks (coffre plein
--              pour l'objet, quel qu'il soit : aucun nom d'objet en dur) ;
--   retry    : ticks d'attente après un échec de pose avec un coffre en main (plus de place libre dans le bloc) ;
--   gap      : tuiles libres autour d'une annexe (les PNJ passent) ;
--   block    : BLOC des annexes, en tuiles depuis le centre du QG : rangées de near à far dans le sens de l'EXTÉRIEUR, colonnes
--              de -half à +half. Il reste DANS le lot (0, 0) du treillis (shared/team/plan.lua : 24 × 24, demi-côté 12) : ni
--              rue (tapis, poteaux) ni lot voisin du plan directeur. Au sud, 12 colonnes × 4 rangées = 48 places (24 avant) ;
--              au nord (QG au nord de l'origine de la carte), half = 7 pour laisser les fours (est, x >= 8) et les laboratoires
--              (ouest, x <= -8,5) : 8 colonnes × 4 rangées = 32 places. Les places les plus proches du QG d'abord.
T.annex = {
  kinds = { { item = "iron-chest", slots = 32 }, { item = "wooden-chest", slots = 16, cheap = true } },
  grow_at = 0.70, park_at = 0.80, park_to = 0.60, keep = 1, max = 48, want = 2,
  early_at = 0.60, early_keep = 0.55, early_ticks = 5 * 3600, refused_ticks = 3600, retry = 1800, gap = 1,
  block = { near = 5, far = 11, half_south = 11, half_north = 7 },
}
-- Fournée d'une tournée « smelt » (script/team/worker.lua) : minerai porté = T.smelt_per_furnace entrées par four du QG,
-- au moins T.smelt_trip_min (la fournée de main 0.6.1 : 20 entrées pour les 4 fours de la fonderie de base d'une
-- faction, d'où 5 par four) : une fonderie agrandie par les bras libres (shared/ai3/bras.lua, Br.smelters) n'est pas
-- limitée à 20 minerais par tournée.
T.smelt_per_furnace = 5
T.smelt_trip_min = 20

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
-- Une partie normale (guide : 4 ouvriers par faction) ressemble au cas 10.
-- Réponse du DC (R-QCM-25c, 25/10 vers 11 h 20) : « Oui, toutes » : la DÉFENSE (tourelles d'avant-poste, construction
-- avec tourelles, avant-poste meurtrier) vaut pour toutes les factions ; la croissance et le fond dès l'effectif de départ
-- restent à votre équipe (une faction a sa propre taille, fo-war-workers).
T.defend_first_factions = true
-- Recrues retenues T.recruit_calm ticks après la perte d'un PNJ (0 : jamais). Essayé à 60 s (essais 1 à 4 du lot) : moins
-- de recrues tuées à leur arrivée, mais pendant une longue attaque du QG l'équipe restait sous son effectif de départ
-- avec du fer (verif-guide graine 1618033988 : 5 min de suite, ECHEC du contrôle de reconstruction) et le QG, moins
-- gardé, tombait. COUPÉ.
T.recruit_calm = 0
-- Avant-poste MEURTRIER : un PNJ tué en y allant ; sans ses tourelles, plus personne n'y va pendant 10 min (ni tournée,
-- ni agrandissement, ni fond), sauf pour y poser les tourelles.
T.lethal_ticks = 10 * 3600
-- Lot SCALE (correction après revue, 27/10) : QG OCCUPÉ par les biters (factions seulement). Quand T.hq_lethal_deaths PNJ
-- d'une faction sont tués par les biters (force « enemy ») à moins de Worker.SAFE_HOME tuiles de son QG en moins de
-- T.hq_lethal_window ticks, la faction ne recrute plus (ni recrue de survie, ni secours sans arme) pendant
-- T.hq_lethal_ticks : chaque recrue y mourait à son arrivée. Moteur réel : s3-scale10 (Ambre, 122 PNJ tués par des
-- spitters à 8 à 10 tuiles du QG en 14 min), s5-scale10 (Ambre, 198), s5-guide30 graine 577215664 (Azur, 264 en 25 min,
-- la partie du guide) : la reconstruction au plancher en remettait 1 à 2 à chaque pensée, environ 10 morts par minute.
-- Une attaque qui passe (1 ou 2 PNJ tués) ne retient rien : la retenue après toute perte (T.recruit_calm, ci-dessus) a
-- été essayée et coupée (le QG, moins gardé, tombait). Même durée que l'avant-poste meurtrier.
T.hq_lethal_deaths = 3
T.hq_lethal_window = 2 * 3600
T.hq_lethal_ticks = T.lethal_ticks
-- ... sauf si sa ressource manque au coffre (moins de T.lethal_need unités) : on y retourne quand même.
T.lethal_need = 50
-- Tourelles du QG (posées d'abord) et fer gardé pour les recrues : la défense ne fabrique pas sous ce plancher.
-- R-QCM-25c (b) « L'équipe le défend » : 4 tourelles autour du coffre (les 4 diagonales d'Outposts.fortify : tous les
-- côtés, l'attaque d'une faction vise le côté le moins défendu, IA2-c).
T.defend_hq = 4
T.defend_iron_floor = 150
T.defend_copper_floor = 30 -- 6 pistolets de recrues
-- Votre équipe sans tourelle possible : aucun site d'avant-poste au-delà de cette distance du coffre (tuiles ; D-18).
-- 300 demandé (D-18) ; 400 retenu : à 300, sur la graine 1618033988 du guide, les sites restants (337 à 368 tuiles)
-- étaient tous refusés, 2 avant-postes, fer à 35, équipe perdue à 35 min ; ceux de 314159265 (582 à 588) restent exclus.
T.site_max_noturret = 400
-- R-QCM-25c (b) : dès qu'une faction a déclaré la guerre au joueur, des PNJ armés restent au coffre : un quart de
-- l'équipe, au moins 2, au plus 6 (gardes de T.guard_ticks, relevées ; priorité T.guard_prio, au-dessus des tournées).
T.guard_prio = 85
T.guard_ticks = 3600
function T.hq_guards(n) return math.min(6, math.max(2, math.floor((n or 0) / 4))) end
-- QG menacé : unités ennemies à moins de T.hq_threat_radius tuiles du coffre ; toute l'équipe en garde (urgence).
T.hq_threat_radius = 48
T.guard_threat_prio = 96
T.guard_threat_ticks = 1200
-- R-QCM-25c (c) « Donner du travail » : le minage de fond de votre équipe se fait PRÈS DU COFFRE (rayon, tuiles ;
-- 27 PNJ tués à 74 tuiles en minant au fond, protocole 30 contre 10) ; transport = tournée de fond d'un avant-poste qui a
-- au moins T.transport_min objets à rapporter (ni meurtrier non défendu, ni pendant la prudence). T.transport_near : limite
-- essayée sans tourelle (essai 7), retirée (ctx.transport_d2 reste pour les bancs hors jeu).
-- Rayon gardé à 96 (celui d'IA1-b) : 40 tuiles (essai 6) et 64 (essai 7) ne trouvaient presque rien à miner sur la carte
-- d'ia1-poles (équipe occupée 36,7 % et 50,7 %) ; la tuile reste à plus de 40 tuiles d'un nid ou d'un ver.
T.near_mine = 96
-- Croissance de votre équipe : seulement en gardant ce fer au coffre (munitions, tourelles, recrues de survie).
T.grow_iron_reserve = 400
T.grow_period = 5 * 3600 -- une recrue de croissance toutes les 5 min au plus (règle de croissance, D-18)
T.transport_min = 10
-- Porteurs de fond au plus par avant-poste. 4 essayés : ia1-poles 70 -> 75 % seulement (la production manque), et plus
-- de PNJ exposés sur les cartes hostiles (verif-guide 1618033988 : porteurs tués à 87-99 tuiles) : 2 gardés.
T.transport_porters = 2
T.transport_near = 64
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
