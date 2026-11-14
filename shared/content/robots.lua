--[[
  Lots RB-1 CHAÎNE (31/10) et RB-4 GAMME (1/11) : les ROBOTS, données pures (PLAN.md fo-logs/2026-10-31_ROBOTS, §0, §2, §5 bis).
  Lua PUR : lu par prototypes/robots.lua (étape data), script/robots/* (exécution) et tests/robots_test.lua (hors jeu).

  Décisions tenues ici :
  - un robot terrestre est une `unit` d'une force non ennemie ; un GÉANT (âges 13 à 15) est une `spider-vehicle` (lot RB-5) ;
    une usine est un `assembling-machine` qui fabrique un KIT (objet de pile 1) ; un balayage de script (script/robots/usine.lua)
    transforme le kit en unité (§0.2) ;
  - UN prototype d'unité par propriétaire (le joueur et les 4 factions) : une unité n'a pas de couleur au jeu (§3) ; un géant n'a
    qu'un prototype, celui du joueur (la couleur d'une araignée s'écrit à l'exécution) ;
  - 12 robots, 4 usines (Atelier, Hall, Dock, Portique) ; premier robot à l'âge 3 : le Trotte-Vapeur (§0.4, Q1) ;
  - points : P 1, M 2, G 4, géant 12 ; plafond = 12 + 6 × âge (§3) ; réglage `fo-war-robots-cap` (0 = automatique) ;
    géants : 1, 2 puis 3 par force aux âges 13, 14 et 15 ;
  - PV et dégâts : CALIBRÉS par shared/robots/duel.lua (voir Ro.ROBOTS), jamais à la main.
  Visuel : les 12 robots ont leurs feuilles de jeu (lots RB-V1 et ROBOTS-JEU, graphics/robots, D-6) ; Ro.PROVISIONAL = false depuis ROBOTS-JEU.
  Aucun nom d'objet ici n'est lu par shared/ai3 ni script/ai3 (tests/iag_test.lua §8) : le cerveau lira les prototypes (RB-3).
]]

local Ech = require("shared.robots.echelle")
local Va = require("shared.robots.variantes") -- lot s43-robots : variantes complémentaires

local Ro = {}

Ro.PROVISIONAL = false -- lot ROBOTS-JEU (3/11) : vrai visuel des 12 robots ; plus de « visuel provisoire » dans les noms et descriptions

Ro.SETTING = "fo-war-robots"         -- réglage maître (runtime-global) : éteint = ni balayage, ni unité, ni ordre
Ro.SETTING_CAP = "fo-war-robots-cap" -- plafond en points (0 = automatique : 12 + 6 × âge)

Ro.PREFIX = "fo-robot-"
Ro.SUBGROUP = "fo-robots"
Ro.AMMO_CATEGORY = "fo-robot" -- catégorie de munition des armes des robots (les améliorations, plus tard, comme upgrade_damage)
Ro.SHELL_CATEGORY = "fo-robot-shell" -- catégorie de munition des canons des géants (munition posée par script, lot RB-5)

--- Propriétaires d'un prototype d'unité : le joueur (toute force qui n'est pas une faction) et les 4 factions du mod
--- (shared/faction/config.lua, F.factions ; tests/robots_test.lua contrôle l'égalité des clés).
Ro.OWNERS = { "player", "scarlet", "azure", "emerald", "amber" }
Ro.PLAYER_OWNER = "player"

--- Points d'une classe (boîte, §2).
Ro.POINTS = { P = 1, M = 2, G = 4, giant = 12 }

--- Plafond en points : base + par âge × âge (âge 1 à 15 ; 30 à l'âge 3, 102 à l'âge 15).
Ro.CAP_BASE = 12
Ro.CAP_PER_AGE = 6
Ro.AGES = 15
--- Géants admis par force : âge − 12 (0 avant l'âge 13), au plus 3.
Ro.GIANT_FIRST_AGE = 13
Ro.GIANT_MAX = 3

--- Les 4 USINES (PLAN §5 bis) : un bâtiment par palier, à l'âge où il arrive, sans niveaux. `copy` : l'assembleur vanilla qui donne le
--- comportement ; `sheet` : ses images (graphics/robots/usines, lot US-V1) ; sortie côté sud. Ni fluide ni productivité (le kit pèse 1 case : RB0-3). `tech` : la
--- technologie qui la débloque. `ingredients` : au plus 100 de chaque (RB0-1).
Ro.FACTORIES = {
  {
    name = "fo-robot-workshop", tier = 1, age = 3, size = 3, kw = 300, module_slots = 2, speed = 1,
    category = "fo-robots-1", copy = "assembling-machine-2", sheet = "atelier", tech = "fo-robot-automata",
    ingredients = { { "engine-unit", 10 }, { "steel-plate", 20 }, { "iron-gear-wheel", 40 }, { "electronic-circuit", 10 } },
    time = 5,
  },
  {
    name = "fo-robotics-bay", tier = 2, age = 7, size = 5, kw = 2500, module_slots = 4, speed = 1,
    category = "fo-robots-2", copy = "assembling-machine-3", sheet = "hall", tech = "fo-robot-bay",
    ingredients = { { "fo-servo-motor", 10 }, { "fo-controller", 6 }, { "fo-optical-sensor", 10 }, { "steel-plate", 40 }, { "concrete", 40 } },
    time = 20,
  },
  {
    name = "fo-robot-dock", tier = 3, age = 10, size = 7, kw = 8000, module_slots = 4, speed = 1,
    category = "fo-robots-3", copy = "assembling-machine-3", sheet = "dock", tech = "fo-robot-dock",
    ingredients = { { "processing-unit", 20 }, { "fo-guidance-core", 10 }, { "fo-servo-motor", 20 }, { "steel-plate", 100 }, { "concrete", 100 } },
    time = 30,
  },
  {
    name = "fo-robot-gantry", tier = 4, age = 13, size = 11, kw = 30000, module_slots = 6, speed = 1,
    category = "fo-robots-4", copy = "assembling-machine-3", sheet = "portique", tech = "fo-robot-gantry",
    ingredients = { { "fo-titanium-plate", 100 }, { "fo-superconducting-coil", 50 }, { "processing-unit", 50 }, { "fo-magnetic-actuator", 20 },
      { "fo-laser-module", 20 }, { "steel-plate", 100 }, { "concrete", 100 } },
    time = 60,
  },
}
Ro.WORKSHOPS = Ro.FACTORIES -- RB-1 : ancien nom (l'interface et les bancs le lisent)
Ro.CATEGORIES = { "fo-robots-1", "fo-robots-2", "fo-robots-3", "fo-robots-4" }

--- Les 12 robots (PLAN §2). Chaque robot a une FORME (`hp0`, `dmg0` : PV et dégâts par tir du plan, dont seul le rapport compte) et des
--- chiffres CALIBRÉS (`hp`, `shot.damage`) : ceux que shared/robots/duel.lua calcule pour que le robot gagne son duel (1 contre 3
--- déchiqueteurs du palier de son âge, marge Duel.TARGET) ; tests/robots_duel_test.lua les contrôle, `--calibrer` les imprime.
--- `shot` = { dégâts par tir, cadence en ticks } ; `dtype` : type de dégâts (les résistances des déchiqueteurs sont lues par type) ;
--- `area` : rayon d'une explosion ; `area_share` : part des dégâts reçue par les voisins de la cible, MESURÉE au moteur (rb-duel : Bobineur 0,5 ;
--- rb-geant : Héliaste 1 sur des cibles groupées ; Chanfrein 0,75 entre les deux, non mesuré en duel) ; `min_range` : artillerie ; `heal`, `engineer` : soutien ; `giant` : araignée (spider-vehicle).
--- `ingredients` : au plus 100 de chaque (un bras ne livre pas plus, RB0-1) ; `mu` : valeur visée (tests/robots_test.lua : ±20 %).
Ro.ROBOTS = {
  {
    id = "steam-trotter", age = 3, class = "P", role = "assault-light", factory = "fo-robot-workshop", dtype = "physical",
    hp0 = 900, dmg0 = 50, hp = 416, shot = { damage = 23.1, cooldown = 30 }, range = 18, speed = 0.14, half = 0.4, tons = 2,
    ingredients = { { "engine-unit", 10 }, { "steel-plate", 22 } }, time = 8, mu = 200,
  },
  {
    id = "scalehide", age = 5, class = "M", role = "assault-heavy", factory = "fo-robot-workshop", dtype = "physical",
    hp0 = 5000, dmg0 = 100, hp = 2710, shot = { damage = 54.3, cooldown = 40 }, range = 14, speed = 0.09, half = 0.6, tons = 3.5,
    ingredients = { { "fo-tungsten-plate", 100 }, { "engine-unit", 20 }, { "steel-plate", 30 }, { "plastic-bar", 33 }, { "battery", 20 } },
    time = 15, mu = 680,
  },
  {
    id = "coiler", age = 6, class = "P", role = "anti-swarm", factory = "fo-robot-workshop", dtype = "electric", area = 4, area_share = 0.5,
    hp0 = 2500, dmg0 = 225, hp = 926, shot = { damage = 83.4, cooldown = 45 }, range = 14, speed = 0.13, half = 0.4, tons = 2,
    ingredients = { { "battery", 60 }, { "steel-plate", 30 }, { "engine-unit", 15 } }, time = 12, mu = 610,
  },
  {
    id = "needle", age = 7, class = "M", role = "long-range", factory = "fo-robotics-bay", dtype = "laser",
    hp0 = 4000, dmg0 = 1200, hp = 2770, shot = { damage = 830, cooldown = 60 }, range = 36, speed = 0.10, half = 0.6, tons = 4,
    ingredients = { { "fo-resonance-crystal", 100 }, { "battery", 100 }, { "fo-servo-motor", 20 }, { "steel-plate", 100 } }, time = 20, mu = 2240,
  },
  {
    id = "bellwether", age = 8, class = "M", role = "support", factory = "fo-robotics-bay", dtype = "physical", hp_rule = "screen",
    hp0 = 12000, dmg0 = 0, hp = 7780, shot = { damage = 0, cooldown = 60 }, range = 12, speed = 0.11, half = 0.6, tons = 4,
    heal = { amount = 172, radius = 12, max = 30, period = 60 },
    ingredients = { { "fo-methane-barrel", 100 }, { "battery", 100 }, { "fo-resonance-crystal", 100 }, { "fo-optical-sensor", 100 },
      { "fo-controller", 20 }, { "fo-servo-motor", 25 } }, time = 25, mu = 4100,
  },
  {
    id = "chamfer", age = 9, class = "G", role = "artillery", factory = "fo-robotics-bay", dtype = "explosion", area = 3, area_share = 0.75, min_range = 12,
    hp0 = 15000, dmg0 = 2000, hp = 54300, shot = { damage = 7240, cooldown = 120 }, range = 45, speed = 0.07, half = 0.9, tons = 5,
    ingredients = { { "uranium-238", 100 }, { "fo-lead-plate", 100 }, { "steel-plate", 100 }, { "fo-servo-motor", 40 }, { "fo-controller", 40 },
      { "fo-optical-sensor", 100 }, { "battery", 100 }, { "processing-unit", 60 }, { "plastic-bar", 100 } }, time = 40, mu = 11250,
  },
  {
    id = "trowel", age = 10, class = "M", role = "engineer", factory = "fo-robot-dock", dtype = "laser",
    hp0 = 12000, dmg0 = 300, hp = 43200, shot = { damage = 1080, cooldown = 30 }, range = 20, speed = 0.14, half = 0.6, tons = 4,
    engineer = { radius = 20, ghosts = 4, repair = 500, repair_max = 8 },
    -- DEFAUTS-DC (QCM du DC 9/11 12 h 10, option A) : noyaux de guidage 40 -> 79 ; le processeur de l'age 10 est passe de 75 a 46 MU
    -- (bdcc443c, 5/11) et la Truelle tombait a 10 778 MU (0,787 du but 13 700) : 13 679 MU, 0,998 du but.
    ingredients = { { "processing-unit", 100 }, { "fo-guidance-core", 79 }, { "fo-servo-motor", 20 }, { "steel-plate", 100 },
      { "fo-controller", 20 }, { "fo-optical-sensor", 100 }, { "battery", 100 } }, time = 40, mu = 13700,
  },
  {
    id = "finback", age = 11, class = "M", role = "assault-fast", factory = "fo-robot-dock", dtype = "laser",
    hp0 = 30000, dmg0 = 1000, hp = 63000, shot = { damage = 2100, cooldown = 20 }, range = 24, speed = 0.24, half = 0.6, tons = 3,
    ingredients = { { "fo-titanium-plate", 100 }, { "processing-unit", 60 }, { "fo-graphics-card", 40 }, { "fo-guidance-core", 100 },
      { "fo-servo-motor", 50 }, { "fo-controller", 50 }, { "fo-optical-sensor", 100 }, { "battery", 100 }, { "steel-plate", 100 },
      { "fo-titanium-composite", 100 }, { "fo-motherboard", 60 } }, time = 50, mu = 25060,
  },
  {
    id = "levite", age = 12, class = "G", role = "assault-heavy", factory = "fo-robot-dock", dtype = "electric",
    hp0 = 60000, dmg0 = 3000, hp = 250000, shot = { damage = 12500, cooldown = 30 }, range = 30, speed = 0.10, half = 0.9, tons = 6,
    ingredients = { { "fo-superconducting-coil", 100 }, { "fo-titanium-plate", 100 }, { "processing-unit", 100 }, { "fo-magnetic-actuator", 100 },
      { "fo-laser-module", 100 }, { "fo-graphics-card", 100 }, { "fo-guidance-core", 100 }, { "low-density-structure", 100 },
      { "fo-titanium-composite", 100 }, { "fo-servo-motor", 100 }, { "fo-motherboard", 100 }, { "fo-controller", 100 } }, time = 90, mu = 68700,
  },
  {
    id = "toroid", age = 13, class = "giant", role = "experimental-assault", factory = "fo-robot-gantry", dtype = "electric",
    hp0 = 600000, dmg0 = 10000, hp = 834000, shot = { damage = 13900, cooldown = 30 }, range = 100, speed = 0.12, half = 1.5, tons = 12,
    giant = { scale = 1.5, leg_scale = 1, leg_speed = 0.2 },
    segment = { ingredients = { { "fo-superconducting-coil", 100 }, { "processing-unit", 100 }, { "fo-magnetic-actuator", 100 },
      { "fo-laser-module", 60 }, { "fo-titanium-plate", 100 } }, time = 30 },
    ingredients = {}, time = 120, mu = 251000,
  },
  {
    id = "heliast", age = 14, class = "giant", role = "experimental-artillery", factory = "fo-robot-gantry", dtype = "fire", area = 4, area_share = 1,
    hp0 = 1000000, dmg0 = 40000, hp = 1870000, shot = { damage = 74600, cooldown = 60 }, range = 100, speed = 0.09, half = 2, tons = 14,
    giant = { scale = 2, leg_scale = 1, leg_speed = 0.085 },
    segment = { ingredients = { { "fo-superconducting-coil", 100 }, { "processing-unit", 100 }, { "fo-magnetic-actuator", 100 },
      { "fo-laser-module", 100 }, { "fo-graphics-card", 100 }, { "fo-guidance-core", 100 }, { "low-density-structure", 50 } }, time = 30 },
    ingredients = {}, time = 120, mu = 459000,
  },
  {
    id = "crowned", age = 15, class = "giant", role = "experimental-final", factory = "fo-robot-gantry", dtype = "laser",
    hp0 = 2500000, dmg0 = 50000, hp = 2660000, shot = { damage = 53300, cooldown = 30 }, range = 100, speed = 0.10, half = 2, tons = 16,
    giant = { scale = 2.2, leg_scale = 1, leg_speed = 0.092 },
    segment = { ingredients = { { "fo-superconducting-coil", 100 }, { "processing-unit", 100 }, { "fo-magnetic-actuator", 100 },
      { "fo-laser-module", 100 }, { "fo-graphics-card", 100 }, { "fo-guidance-core", 100 }, { "low-density-structure", 100 },
      { "fo-servo-motor", 100 }, { "fo-motherboard", 100 }, { "fo-titanium-plate", 100 }, { "fo-titanium-composite", 100 } }, time = 30 },
    final = { { "processing-unit", 100 }, { "fo-magnetic-actuator", 100 }, { "fo-laser-module", 100 } },
    ingredients = {}, time = 120, mu = 584000,
  },
}

--- Chaîne des géants : 10 segments (recette du dock) + assemblage final (portique, 120 s).
Ro.SEGMENTS = 10
--- Valeurs supposées (MU) d'objets sans valeur dans le scénario (déclarées, jamais présentées comme mesures).
Ro.MU_ASSUMED = { ["fo-lead-plate"] = 2 }
--- Écarts au plan, déclarés : composition des ingrédients faute des objets des âges 13 à 15 (cellule de plasma, superalliage, matière
--- exotique : absents du jeu à 0.6.32) et du biopolymère (le baril de méthane le remplace, monnaie de l'âge 8 en jeu).
Ro.DEVIATIONS = {
  "geants (ages 13 a 15) : bobines, processeurs, actionneurs, modules laser, cartes graphiques, noyaux : les objets des ages 13 a 15 du scenario ne sont pas en jeu",
  "Couronne : 584 000 MU contre 840 000 du plan (au plus 100 de chaque ingredient par recette, RB0-1)",
  "Cloche : baril de methane (monnaie de l'age 8 en jeu) a la place du biopolymere",
  "Levite : ne franchit pas l'eau (RB0 E5 : le masque reduit traverse aussi murs et batiments)",
  "Geants : portee 100 (RB0 : zones mortes au-dela de l'echelle 3 avec un canon de portee 60)",
}

--- Technologies (PLAN §6) : une par palier d'usine et par robot ; `factories`, `robots` (id) et `segments` (id des géants) qu'elle ouvre.
Ro.TECHS = {
  { name = "fo-robot-automata", epoch = 3, count = 100, time = 30, prerequisites = { "engine" }, factories = { "fo-robot-workshop" }, robots = { "steam-trotter" } },
  { name = "fo-robot-heavy", epoch = 5, count = 120, time = 30, prerequisites = { "fo-robot-automata" }, robots = { "scalehide" } },
  { name = "fo-robot-coil", epoch = 6, count = 120, time = 30, prerequisites = { "fo-robot-heavy", "battery" }, robots = { "coiler" } },
  { name = "fo-robot-bay", epoch = 7, count = 150, time = 30, prerequisites = { "fo-robot-coil", "fo-servo-mechanisms" },
    factories = { "fo-robotics-bay" }, robots = { "needle" } },
  { name = "fo-robot-bellwether", epoch = 8, count = 150, time = 30, prerequisites = { "fo-robot-bay" }, robots = { "bellwether" } },
  { name = "fo-robot-mortar", epoch = 9, count = 150, time = 30, prerequisites = { "fo-robot-bellwether", "uranium-processing" }, robots = { "chamfer" } },
  { name = "fo-robot-dock", epoch = 10, count = 200, time = 30, prerequisites = { "fo-robot-mortar", "fo-robot-guidance" },
    factories = { "fo-robot-dock" }, robots = { "trowel" } },
  { name = "fo-robot-finback", epoch = 11, count = 200, time = 30, prerequisites = { "fo-robot-dock", "fo-titanium-processing" }, robots = { "finback" } },
  { name = "fo-robot-levite", epoch = 12, count = 250, time = 30, prerequisites = { "fo-robot-finback", "fo-magnetic-drive" }, robots = { "levite" } },
  { name = "fo-robot-gantry", epoch = 13, count = 300, time = 30, prerequisites = { "fo-robot-levite" },
    factories = { "fo-robot-gantry" }, robots = { "toroid" } },
  { name = "fo-robot-gantry-heliast", epoch = 14, count = 300, time = 30, prerequisites = { "fo-robot-gantry" }, robots = { "heliast" } },
  { name = "fo-robot-gantry-crowned", epoch = 15, count = 300, time = 30, prerequisites = { "fo-robot-gantry-heliast" }, robots = { "crowned" } },
}
Ro.TECH = Ro.TECHS[1] -- RB-1 : technologie du premier robot (raccourci « Armée »)

--- Ordres du joueur (RB-1 : appel direct ; RB-2 : l'outil de sélection `Ro.TOOL_ORDER`, mêmes fonctions).
Ro.ORDERS = { "move", "attack" }

--- Lot RB-2 JOUEUR : outils et interface. Outil d'ordre (raccourci « Armée » en fin de barre) : glisser = choisir ses robots,
--- Maj + glisser = marche-attaque vers la zone, bouton droit = attaquer ce qui est encadré, Maj + bouton droit = aller (touches
--- de la doc SelectionToolPrototype, jamais jouées par un script : RB0 E6). Outil de ralliement : un clic ou un glisser fixe le
--- point de ralliement d'un atelier.
Ro.TOOL_ORDER = "fo-robot-order"
Ro.TOOL_RALLY = "fo-robot-rally"
Ro.SHORTCUT = "fo-robot-order" -- raccourci (action « spawn-item ») et touche (custom-input) du même nom
Ro.INPUT_KEY = "ALT + R"
--- Événement de l'outil -> action : choisir ses robots, marche-attaque, attaquer ce qui est encadré, aller.
Ro.TOOL_ACTIONS = { selected = "choose", alt = "attack", reverse = "strike", alt_reverse = "move" }
Ro.MIN_ZONE = 6        -- rayon minimal d'une zone d'ordre (tuiles) : un clic sans glisser donne ce rayon
Ro.SELECTION_MAX = 200 -- robots choisis au plus (un joueur ne commande pas plus que le plafond)
Ro.QUEUE_MAX = 12      -- entrées d'une file d'atelier
Ro.KEEP_MAX = 99       -- « maintenir N » : N au plus
Ro.ALERT_COOLDOWN = 300 -- ticks entre deux alertes de pertes (par force)
Ro.LOSS_FLUSH = 120    -- ticks sans perte avant le message de bilan des pertes
Ro.ATTACK_RADIUS = 24 -- rayon de la zone d'une marche-attaque (tuiles)
Ro.RALLY_DEPTH = 9    -- ralliement par défaut : tuiles au sud du point de sortie
Ro.SELECT_RADIUS = 1  -- clic sans glisser : rayon de sélection (tuiles ; défaut du plan, E6 non tranché)

--- Lot RB-4 : soutien. Impulsion de soin (Cloche) et d'ingénieur (Truelle) : toutes les `period` ticks ; au plus `max` cibles.
Ro.SUPPORT_PERIOD = 60
--- Lot RB-5 : géants. Un géant reçoit des obus par script ; il garde au moins MIN, jamais plus de TOP dans son magasin.
Ro.GIANT_AMMO = { min = 2, top = 4 }
Ro.GIANT_PATH_STEP = 6  -- un point de chemin sur 6 pousse l'autopilote (RB0 E3)
Ro.GIANT_PATH_BOX = 1   -- demi-boîte de la demande de chemin d'un géant (RB0 E3)
Ro.GIANT_HOLD = 4       -- tuiles : un géant est « arrivé » quand il est à moins de cette distance de son but

--- Lot s43-robots : 3 VARIANTES complémentaires (shared/robots/variantes.lua : soutien de terrain âge 4, éclaireur âge 5,
--- anti-blindé âge 9), dérivées d'un parent par règle pure, ajoutées APRÈS les 12 du plan (ordre et indices des 12 inchangés).
do
  local plan = {}
  for _, r in ipairs(Ro.ROBOTS) do plan[r.id] = r end
  for _, v in ipairs(Va.build(function(id) return plan[id] end)) do Ro.ROBOTS[#Ro.ROBOTS + 1] = v end
  for _, t in ipairs(Va.techs()) do Ro.TECHS[#Ro.TECHS + 1] = t end
end
Ro.PLAN_COUNT = 12 -- les 12 robots du plan ; au-delà, des variantes (r.variant = id du parent)

local by_id, by_kit, by_recipe, by_factory = {}, {}, {}, {}

function Ro.kit_name(id) return Ro.PREFIX .. "kit-" .. id end
function Ro.recipe_name(id) return Ro.PREFIX .. "make-" .. id end
function Ro.unit_name(owner, id) return Ro.PREFIX .. owner .. "-" .. id end
function Ro.segment_name(id) return Ro.PREFIX .. "segment-" .. id end
function Ro.segment_recipe_name(id) return Ro.PREFIX .. "make-segment-" .. id end
function Ro.shell_name(id) return Ro.PREFIX .. "shell-" .. id end
function Ro.gun_name(id) return Ro.PREFIX .. "gun-" .. id end

for _, r in ipairs(Ro.ROBOTS) do
  r.kit = Ro.kit_name(r.id)
  r.recipe = Ro.recipe_name(r.id)
  r.points = Ro.POINTS[r.class]
  r.dps = r.shot.damage * 60 / r.shot.cooldown
  r.is_giant = r.giant ~= nil
  if r.is_giant then
    -- Règle d'échelle (lot EXPERIMENTAUX-PUISSANCE, réponses du DC du 5/11 ; appliquée aux géants de robotsjeu avec l'accord du lead) :
    -- E1 PV et résistances d'écart d'âge, E2 salve par cible, E3 salve de zone de 15 × (âge − 9) tuiles, E4 cratère. Les PV écrits plus
    -- haut (834 000, 1 870 000, 2 660 000 : calibrage des duels) sont remplacés ; le canon (shot) reste tel quel.
    r.hp = Ech.pv(r.age)
    r.resistances = Ech.resistances(r.age)
    r.salve = Ech.salve(r.age, r.dtype)
    r.zone = Ech.rayon(r.age)
    r.cratere = Ech.cratere(r.age)
    r.zone_cooldown = Ech.CADENCE_ZONE
  end
  if r.segment then
    r.segment_item = Ro.segment_name(r.id)
    r.segment_recipe = Ro.segment_recipe_name(r.id)
    -- l'assemblage final : 10 segments, plus les ingrédients propres du robot (`final`)
    local ings = { { r.segment_item, Ro.SEGMENTS } }
    for _, g in ipairs(r.final or {}) do ings[#ings + 1] = g end
    r.ingredients = ings
  end
  by_id[r.id], by_kit[r.kit], by_recipe[r.recipe] = r, r, r
  by_factory[r.factory] = by_factory[r.factory] or {}
  by_factory[r.factory][#by_factory[r.factory] + 1] = r
end

local factory_by_name = {}
for _, w in ipairs(Ro.FACTORIES) do factory_by_name[w.name] = w end

function Ro.robot(id) return by_id[id] end
function Ro.robot_of_kit(name) return by_kit[name] end
function Ro.robot_of_recipe(name) return by_recipe[name] end
function Ro.factory(name) return factory_by_name[name] end
function Ro.is_factory(name) return factory_by_name[name] ~= nil end
Ro.workshop = Ro.factory         -- RB-1 : anciens noms
Ro.is_workshop = Ro.is_factory
--- Robots fabriqués par un bâtiment (liste dans l'ordre des données).
function Ro.robots_of(factory_name) return by_factory[factory_name] or {} end
--- Robots qui ont une chaîne de segments (les géants).
function Ro.giants()
  local out = {}
  for _, r in ipairs(Ro.ROBOTS) do if r.is_giant then out[#out + 1] = r end end
  return out
end

--- Propriétaires d'un prototype pour ce robot : tous pour une unité, le joueur seul pour un géant.
function Ro.owners_of(r)
  if r.is_giant then return { Ro.PLAYER_OWNER } end
  return Ro.OWNERS
end

--- Nom de prototype lu en (propriétaire, robot) ; nil si ce n'est pas une unité de robot.
function Ro.parse_unit(name)
  if type(name) ~= "string" or name:sub(1, #Ro.PREFIX) ~= Ro.PREFIX then return nil end
  local rest = name:sub(#Ro.PREFIX + 1)
  for _, owner in ipairs(Ro.OWNERS) do
    local head = owner .. "-"
    if rest:sub(1, #head) == head then
      local id = rest:sub(#head + 1)
      if by_id[id] then return owner, id end
    end
  end
  return nil
end

--- Propriétaire d'une force : la clé de la faction si c'en est une (`faction_keys[force_name]`), sinon le joueur.
function Ro.owner_of(force_name, faction_keys)
  return (faction_keys and faction_keys[force_name]) or Ro.PLAYER_OWNER
end

--- Nom du prototype que crée la force `owner` pour le robot `r` (un géant : toujours celui du joueur).
function Ro.proto_name(owner, r)
  if r.is_giant then return Ro.unit_name(Ro.PLAYER_OWNER, r.id) end
  return Ro.unit_name(owner, r.id)
end

--- Noms de tous les prototypes d'unité (propriétaires dans l'ordre de Ro.OWNERS, robots dans l'ordre des données).
function Ro.unit_names()
  local out = {}
  for _, owner in ipairs(Ro.OWNERS) do
    for _, r in ipairs(Ro.ROBOTS) do
      if not r.is_giant then out[#out + 1] = Ro.unit_name(owner, r.id) end
    end
  end
  for _, r in ipairs(Ro.ROBOTS) do
    if r.is_giant then out[#out + 1] = Ro.unit_name(Ro.PLAYER_OWNER, r.id) end
  end
  return out
end

--- Géants admis pour une force à l'âge `age` : 0 avant l'âge 13, puis 1, 2, 3.
function Ro.giant_allowed(age)
  age = math.floor(tonumber(age) or 1)
  return math.max(0, math.min(Ro.GIANT_MAX, age - Ro.GIANT_FIRST_AGE + 1))
end

--- Une technologie par nom.
function Ro.tech(name)
  for _, t in ipairs(Ro.TECHS) do if t.name == name then return t end end
  return nil
end

--- Recettes débloquées par une technologie (défaut : la première) : usines, kits, segments (noms, dans l'ordre des données).
function Ro.tech_unlocks(tech)
  tech = tech or Ro.TECHS[1]
  local out = {}
  for _, n in ipairs(tech.factories or {}) do out[#out + 1] = n end
  for _, id in ipairs(tech.robots or {}) do
    local r = by_id[id]
    if r.segment then out[#out + 1] = r.segment_recipe end
    out[#out + 1] = r.recipe
  end
  return out
end

return Ro
