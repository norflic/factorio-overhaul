--[[
  Lot DESIGN-MODULES (5/11 au 6/11) : MODULES DES GÉANTS expérimentaux (Cairn, Stylet, Trombe, Ixion, Tournesol), données et règles PURES.
  Demande du DC (5/11, en jouant) : « pouvoir peut-être rajouter des modules de range ou de puissance d'attaque de pourcentage dans les au sein
  des unités expérimentales » ; au QCM : « Des modules (portée, puissance) ». PROPOSITION : rien en jeu sans le verdict du DC.

  Mécanique (voir prototypes/experimentaux_modules.lua et script/robots/experimentaux_modules.lua) :
  - chaque géant (spider-vehicle, VehiclePrototype::equipment_grid) reçoit une GRILLE d'équipement de 2 cases de haut et de 2 × `slots` de
    large, qui n'accepte QUE la catégorie M.CATEGORY : ni bouclier, ni exosquelette, ni laser vanilla ; nos modules n'entrent pas non plus
    dans une armure ou un spidertron ;
  - un module occupe 2 × 2 cases (un emplacement) ; il ne fait RIEN par lui-même (équipement de type batterie, sans capacité) : le script lit
    la grille au moment du tir et en tire le bonus (M.bonus), sans rien garder entre deux tirs (aucun état, aucune migration) ;
  - la portée et le coup d'un géant sont des valeurs du SCRIPT (le géant n'a pas d'arme, prototypes/experimentaux_geants.lua) : aucun
    prototype en variante n'est nécessaire (la portée d'une arme d'unité ou de tourelle, elle, est figée par le prototype).

  Règle : bonus en POURCENTS ENTIERS, additionnés par type, puis plafonnés (M.TYPES[*].cap). Portée effective = portée × (100 + bonus) / 100,
  coup effectif = coup × (100 + bonus) / 100. CHIFFRES PROVISOIRES, NON CALIBRÉS (pas de rb-duel) : à juger par le DC.
  Déterminisme : listes, aucun pairs, aucun hasard ; sommes d'entiers (l'ordre de lecture de la grille ne change rien).
]]

local M = {}

M.PREFIX = "fo-xp-module-"   -- objets et équipements : fo-xp-module-<type>-<palier>
M.CATEGORY = "fo-xp-module"  -- catégorie d'équipement : seules les grilles des géants l'acceptent
M.GRID_PREFIX = "fo-xp-grille-"
M.TECH_PREFIX = "fo-xp-modules-"
M.SUBGROUP = "fo-robots-xp-modules"
M.SIDE = 2                   -- un module occupe SIDE × SIDE cases
M.LOG = "[FO-XP-MODULES]"

--- Les deux types demandés par le DC. `stat` : la valeur du géant qu'ils multiplient (champ de Xp.GEANTS) ; `cap` : plafond du bonus total
--- (pourcents) ; au-delà, un module de plus ne sert à rien (le plafond pousse à MÊLER les types dans les grands géants).
--- Plafond de portée : +50 % (Tournesol 60 -> 90 tuiles, trois chunks ; recherche d'ennemi au plus à 90 tuiles toutes les 30 ticks).
--- Chaque plafond vaut exactement DEUX modules du palier III (2 × 25 et 2 × 50) : aucun point perdu au meilleur palier (critique du 5/11 :
--- avec une portée III à +30, deux modules perdaient 10 points).
M.TYPES = {
  { id = "portee", stat = "range", cap = 50 },
  { id = "puissance", stat = "shot", cap = 100 },
}

--- Paliers : âge de la technologie (celui du géant qui l'ouvre), usine (Ro.FACTORIES : Dock dès l'âge 10, Portique dès l'âge 13),
--- technologie de géant prérequise (Xp.tech_name). Un module coûte environ le DIXIÈME du géant de son âge (Cairn 41 000 MU, Trombe 137 000,
--- Tournesol 459 000) : contrôlé à ± 25 % par tests/experimentaux_modules_test.lua (même fonction de MU que les robots).
M.TIERS = {
  { tier = 1, age = 10, factory = "fo-robot-dock", after = "fo-xp-cairn", ref_mu = 41000 },
  { tier = 2, age = 12, factory = "fo-robot-dock", after = "fo-xp-trombe", ref_mu = 137000 },
  { tier = 3, age = 14, factory = "fo-robot-gantry", after = "fo-xp-tournesol", ref_mu = 459000 },
}
M.COST_SHARE = 0.1           -- part du géant de l'âge que coûte un module
M.TIME = 30                  -- secondes de fabrication

--- Les 6 modules : bonus (pourcents) et recette (au plus 100 de chaque ingrédient, aucun plus tardif que l'âge du palier).
--- PORTÉE : optique et guidage (capteurs, cœurs de guidage, cartes graphiques, modules laser).
--- PUISSANCE : énergie et force (batteries, servomoteurs, bobines supraconductrices, actionneurs magnétiques, uranium).
M.MODULES = {
  { type = "portee", tier = 1, bonus = 10,
    ingredients = { { "fo-optical-sensor", 100 }, { "fo-guidance-core", 20 }, { "processing-unit", 20 }, { "fo-controller", 20 }, { "steel-plate", 50 } } },
  { type = "portee", tier = 2, bonus = 15,
    ingredients = { { "fo-laser-module", 60 }, { "fo-graphics-card", 40 }, { "fo-guidance-core", 40 }, { "fo-optical-sensor", 100 },
      { "fo-titanium-plate", 50 }, { "processing-unit", 50 } } },
  { type = "portee", tier = 3, bonus = 25,
    ingredients = { { "fo-laser-module", 100 }, { "fo-graphics-card", 100 }, { "fo-guidance-core", 100 }, { "fo-superconducting-coil", 100 },
      { "fo-titanium-composite", 100 }, { "processing-unit", 100 }, { "low-density-structure", 100 } } },
  { type = "puissance", tier = 1, bonus = 15,
    ingredients = { { "battery", 100 }, { "fo-servo-motor", 30 }, { "processing-unit", 20 }, { "fo-controller", 20 }, { "uranium-238", 50 } } },
  { type = "puissance", tier = 2, bonus = 30,
    ingredients = { { "fo-superconducting-coil", 60 }, { "fo-magnetic-actuator", 60 }, { "fo-servo-motor", 50 }, { "processing-unit", 50 },
      { "battery", 100 }, { "fo-titanium-plate", 50 } } },
  { type = "puissance", tier = 3, bonus = 50,
    ingredients = { { "fo-superconducting-coil", 100 }, { "fo-magnetic-actuator", 100 }, { "fo-laser-module", 100 }, { "fo-graphics-card", 60 },
      { "processing-unit", 100 }, { "fo-guidance-core", 60 }, { "fo-titanium-composite", 100 }, { "uranium-238", 100 } } },
}

--- Emplacements par géant (2 × 2 cases chacun) : plus le géant est tardif, plus il en a. Les identifiants sont ceux de Xp.GEANTS.
M.SLOTS = {
  { id = "cairn", slots = 2 },
  { id = "stylet", slots = 2 },
  { id = "trombe", slots = 3 },
  { id = "ixion", slots = 3 },
  { id = "tournesol", slots = 4 },
}

---------------------------------------------------------------------------------------------------
-- Noms
---------------------------------------------------------------------------------------------------
function M.name(type_id, tier) return M.PREFIX .. type_id .. "-" .. tier end
function M.recipe_name(type_id, tier) return M.PREFIX .. "make-" .. type_id .. "-" .. tier end
function M.tech_name(type_id, tier) return M.TECH_PREFIX .. type_id .. "-" .. tier end
function M.grid_name(giant_id) return M.GRID_PREFIX .. giant_id end

local type_by_id, tier_by_n, by_name, slots_by_id = {}, {}, {}, {}
for _, t in ipairs(M.TYPES) do type_by_id[t.id] = t end
for _, t in ipairs(M.TIERS) do tier_by_n[t.tier] = t end
for _, s in ipairs(M.SLOTS) do slots_by_id[s.id] = s.slots end
for _, m in ipairs(M.MODULES) do
  local t = tier_by_n[m.tier]
  m.name = M.name(m.type, m.tier)
  m.recipe = M.recipe_name(m.type, m.tier)
  m.tech = M.tech_name(m.type, m.tier)
  m.age = t.age
  m.factory = t.factory
  -- prérequis : la technologie du géant de l'âge, et le palier précédent du même type
  m.prerequisites = { t.after }
  if m.tier > 1 then m.prerequisites[2] = M.tech_name(m.type, m.tier - 1) end
  by_name[m.name] = m
end

function M.type(id) return type_by_id[id] end
function M.tier(n) return tier_by_n[n] end
--- Le module d'un nom d'objet ou d'équipement ; nil sinon.
function M.of_name(name) return type(name) == "string" and by_name[name] or nil end
--- Emplacements d'un géant (0 pour un identifiant inconnu : pas de grille).
function M.slots(giant_id) return slots_by_id[giant_id] or 0 end
--- Taille de la grille d'un géant : largeur, hauteur (cases).
function M.grid_size(giant_id) return M.SIDE * M.slots(giant_id), M.SIDE end

---------------------------------------------------------------------------------------------------
-- Règle du bonus
---------------------------------------------------------------------------------------------------
--- Bonus d'une grille, à partir de la LISTE des noms des équipements posés (LuaEquipmentGrid::equipment, un nom par équipement) :
--- { portee = pourcents, puissance = pourcents, brut = { portee =, puissance = } } ; les noms inconnus sont ignorés (un équipement d'un autre
--- mod ne compte pas). Somme d'entiers par type, puis plafond du type.
function M.bonus(names)
  local brut = {}
  for _, t in ipairs(M.TYPES) do brut[t.id] = 0 end
  for _, n in ipairs(names or {}) do
    local m = by_name[n]
    if m then brut[m.type] = brut[m.type] + m.bonus end
  end
  local out = { brut = brut }
  for _, t in ipairs(M.TYPES) do out[t.id] = math.min(brut[t.id], t.cap) end
  return out
end

--- Bonus nul (géant sans grille, ou grille vide).
M.ZERO = M.bonus({})

--- Valeur effective : `base` × (100 + pourcents) / 100.
function M.apply(base, pct) return base * (100 + (pct or 0)) / 100 end
--- Portée et coup effectifs d'un géant (r : entrée de Xp.GEANTS) pour un bonus (M.bonus).
function M.range(r, b) return M.apply(r.range, (b or M.ZERO).portee) end
function M.shot(r, b) return M.apply(r.shot, (b or M.ZERO).puissance) end

--- Bonus le plus fort qu'un géant peut porter, par type (tous ses emplacements du meilleur palier ouvert à l'âge `age`, plafonné).
function M.max_bonus(giant_id, age)
  local out = {}
  local n = M.slots(giant_id)
  for _, t in ipairs(M.TYPES) do
    local best = 0
    for _, m in ipairs(M.MODULES) do
      if m.type == t.id and m.age <= (age or 99) and m.bonus > best then best = m.bonus end
    end
    out[t.id] = math.min(best * n, t.cap)
  end
  return out
end

--- Coup « hors portée de base » : la cible est au-delà de la portée du géant SANS module (le tir n'existe que grâce au module de portée).
--- Sert au marqueur visuel du script. `d` : distance à la cible (tuiles).
function M.beyond_base(r, d) return d > r.range end

---------------------------------------------------------------------------------------------------
-- Factions (réserve : aujourd'hui, aucune faction ne pose de géant expérimental, script/robots/armee.lua ne fait que les compter)
---------------------------------------------------------------------------------------------------
--- Garniture d'un géant de faction à l'âge `age` : le meilleur palier ouvert, PUISSANCE d'abord jusqu'à son plafond, puis PORTÉE.
--- Rend la liste des noms de modules à poser (au plus M.slots(giant_id)).
function M.loadout(giant_id, age)
  local out = {}
  local n = M.slots(giant_id)
  local order = { "puissance", "portee" }
  for _, tid in ipairs(order) do
    local best
    for _, m in ipairs(M.MODULES) do
      if m.type == tid and m.age <= (age or 0) and (not best or m.bonus > best.bonus) then best = m end
    end
    if best then
      local cap = type_by_id[tid].cap
      local sum = 0
      while #out < n and sum < cap do
        out[#out + 1] = best.name
        sum = sum + best.bonus
      end
    end
  end
  return out
end

return M
