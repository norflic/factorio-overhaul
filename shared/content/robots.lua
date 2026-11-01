--[[
  Lot RB-1 CHAÎNE (31/10) : les ROBOTS, données pures (PLAN.md fo-logs/2026-10-31_ROBOTS, §0, §2, §5 bis). Lua PUR : lu par
  prototypes/robots.lua (étape data), script/robots/* (exécution) et tests/robots_test.lua (hors jeu).

  Décisions tenues ici :
  - un robot terrestre est une `unit` d'une force non ennemie ; une usine est un `assembling-machine` qui fabrique un KIT
    (objet de pile 1) ; un balayage de script (script/robots/usine.lua) transforme le kit en unité (§0.2) ;
  - UN prototype d'unité par propriétaire (le joueur et les 4 factions) : une unité n'a pas de couleur au jeu (§3) ;
  - premier robot à l'âge 3 : le Trotte-Vapeur (§0.4, Q1), fabriqué à l'Atelier d'automates (T1, 3 × 3, §5 bis) ;
  - points : P 1, M 2, G 4, géant 12 ; plafond = 12 + 6 × âge (§3) ; réglage `fo-war-robots-cap` (0 = automatique).
  Visuel PROVISOIRE (Ro.PROVISIONAL) : petit cracheur vanilla teinté gris acier, 0 image neuve (RB-1 ; vrai visuel : lot RB-V0).
  Aucun nom d'objet ici n'est lu par shared/ai3 ni script/ai3 (tests/iag_test.lua §8) : le cerveau lira les prototypes (RB-3).
]]

local Ro = {}

Ro.PROVISIONAL = true -- visuel provisoire (voir l'en-tête) ; marqué dans les noms et descriptions

Ro.SETTING = "fo-war-robots"         -- réglage maître (runtime-global) : éteint = ni balayage, ni unité, ni ordre
Ro.SETTING_CAP = "fo-war-robots-cap" -- plafond en points (0 = automatique : 12 + 6 × âge)

Ro.PREFIX = "fo-robot-"
Ro.SUBGROUP = "fo-robots"
Ro.AMMO_CATEGORY = "fo-robot" -- catégorie de munition des armes des robots (les améliorations, plus tard, comme upgrade_damage)

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

--- Atelier d'automates (T1, âge 3). Provisoire : copie teintée de l'assembleur 2 ; ni fluide ni productivité (le kit pèse 1 case :
--- RB0-3, la productivité n'ajoute jamais un second kit).
Ro.WORKSHOPS = {
  {
    name = "fo-robot-workshop", tier = 1, age = 3, size = 3, kw = 300, module_slots = 2, speed = 1,
    category = "fo-robots-1", copy = "assembling-machine-2", tint = { r = 0.66, g = 0.62, b = 0.55 },
    ingredients = { { "engine-unit", 10 }, { "steel-plate", 20 }, { "iron-gear-wheel", 40 }, { "electronic-circuit", 10 } },
    time = 5,
  },
}
Ro.CATEGORIES = { "fo-robots-1" }

--- Les robots. `shot` = { dégâts physiques, cadence en ticks } : DPS = dégâts × 60 / cadence. PV et DPS : première estimation du
--- plan, à recaler par le banc de duel (RB-4). `ingredients` : au plus 100 de chaque (un bras livre au plus ~100 d'un
--- ingrédient, RB0-1) ; `mu` : valeur visée (but du plan : secondes du débit de fin d'âge, §2) ; coût réel = tests/robots_test.lua.
Ro.ROBOTS = {
  {
    id = "steam-trotter", age = 3, class = "P", role = "assault-light", factory = "fo-robot-workshop",
    hp = 900, shot = { damage = 50, cooldown = 30 }, range = 18, speed = 0.14, half = 0.4, tons = 2,
    ingredients = { { "engine-unit", 10 }, { "steel-plate", 22 } }, time = 8, mu = 200,
  },
}

--- Technologie qui débloque l'atelier et le kit du Trotte-Vapeur (âge 3 : packs et unités par les règles des lots CRAFTS).
Ro.TECH = { name = "fo-robot-automata", epoch = 3, count = 100, time = 30, prerequisites = { "engine" } }

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

local by_id, by_kit, by_recipe, by_factory = {}, {}, {}, {}

function Ro.kit_name(id) return Ro.PREFIX .. "kit-" .. id end
function Ro.recipe_name(id) return Ro.PREFIX .. "make-" .. id end
function Ro.unit_name(owner, id) return Ro.PREFIX .. owner .. "-" .. id end

for _, r in ipairs(Ro.ROBOTS) do
  r.kit = Ro.kit_name(r.id)
  r.recipe = Ro.recipe_name(r.id)
  r.points = Ro.POINTS[r.class]
  r.dps = r.shot.damage * 60 / r.shot.cooldown
  by_id[r.id], by_kit[r.kit], by_recipe[r.recipe] = r, r, r
  by_factory[r.factory] = by_factory[r.factory] or {}
  by_factory[r.factory][#by_factory[r.factory] + 1] = r
end

local workshop_by_name = {}
for _, w in ipairs(Ro.WORKSHOPS) do workshop_by_name[w.name] = w end

function Ro.robot(id) return by_id[id] end
function Ro.robot_of_kit(name) return by_kit[name] end
function Ro.robot_of_recipe(name) return by_recipe[name] end
function Ro.workshop(name) return workshop_by_name[name] end
function Ro.is_workshop(name) return workshop_by_name[name] ~= nil end
--- Robots fabriqués par un bâtiment (liste dans l'ordre des données).
function Ro.robots_of(factory_name) return by_factory[factory_name] or {} end

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

--- Noms de tous les prototypes d'unité (propriétaires dans l'ordre de Ro.OWNERS, robots dans l'ordre des données).
function Ro.unit_names()
  local out = {}
  for _, owner in ipairs(Ro.OWNERS) do
    for _, r in ipairs(Ro.ROBOTS) do out[#out + 1] = Ro.unit_name(owner, r.id) end
  end
  return out
end

--- Recettes débloquées par la technologie : atelier(s) et kit(s) (noms, dans l'ordre des données).
function Ro.tech_unlocks()
  local out = {}
  for _, w in ipairs(Ro.WORKSHOPS) do out[#out + 1] = w.name end
  for _, r in ipairs(Ro.ROBOTS) do out[#out + 1] = r.recipe end
  return out
end

return Ro
