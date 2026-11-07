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
  PRIX SELON L'ÂGE DU GÉANT (QCM-7/11 du DC : « Prix selon l'âge du géant », « Un module coûte une part fixe de la valeur du géant qui le
  porte : juste pour tous les âges » ; lecture (b) du lead) : un objet n'a qu'un prix, donc c'est le BONUS qui suit le géant qui le porte.
  Sur un géant de l'âge a, un module vaut bonus nominal × valeur(âge du palier) / valeur(a) (M.bonus_of) : nominal sur le géant de son
  palier, plus fort sur un géant plus jeune (moins cher), plus faible sur un plus vieux ; arrondi, au moins 1. La valeur pour la valeur
  tient ainsi sur CHAQUE géant (le module coûte toujours COST_SHARE du géant de son palier). Géants des factions : M.bonus_age.
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
--- `age` : celui de Xp.GEANTS (contrôlé par le test).
M.SLOTS = {
  { id = "cairn", slots = 2, age = 10 },
  { id = "stylet", slots = 2, age = 11 },
  { id = "trombe", slots = 3, age = 12 },
  { id = "ixion", slots = 3, age = 13 },
  { id = "tournesol", slots = 4, age = 14 },
}

---------------------------------------------------------------------------------------------------
-- Noms
---------------------------------------------------------------------------------------------------
function M.name(type_id, tier) return M.PREFIX .. type_id .. "-" .. tier end
function M.recipe_name(type_id, tier) return M.PREFIX .. "make-" .. type_id .. "-" .. tier end
function M.tech_name(type_id, tier) return M.TECH_PREFIX .. type_id .. "-" .. tier end
function M.grid_name(giant_id) return M.GRID_PREFIX .. giant_id end

local type_by_id, tier_by_n, by_name, slots_by_id, age_by_id = {}, {}, {}, {}, {}
for _, t in ipairs(M.TYPES) do type_by_id[t.id] = t end
for _, t in ipairs(M.TIERS) do tier_by_n[t.tier] = t end
for _, s in ipairs(M.SLOTS) do slots_by_id[s.id] = s.slots ; age_by_id[s.id] = s.age end
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
--- Âge d'un géant à grille (nil pour un identifiant inconnu) ; identifiant d'un nom de grille (nil si ce n'en est pas une).
function M.giant_age(giant_id) return age_by_id[giant_id] end
function M.giant_of_grid(grid_name)
  if type(grid_name) ~= "string" or grid_name:sub(1, #M.GRID_PREFIX) ~= M.GRID_PREFIX then return nil end
  local id = grid_name:sub(#M.GRID_PREFIX + 1)
  return slots_by_id[id] and id or nil
end

---------------------------------------------------------------------------------------------------
-- Valeur d'un géant selon son âge (prix au prorata de l'âge, QCM-7/11)
---------------------------------------------------------------------------------------------------
--- Valeur (MU) d'un géant de l'âge `age` (entier) : courbe géométrique par les géants des paliers (Cairn 41 000 à l'âge 10, Trombe 137 000
--- au 12, Tournesol 459 000 au 14 ; le Stylet, 75 000 au 11, et l'Ixion, 251 000 au 13, y tombent à 0,1 % près), prolongée au-delà du
--- dernier palier par sa raison (environ 840 000 à l'âge 15) ; en deçà du premier palier, sa valeur. Paliers espacés de 2 âges (contrôlé
--- par le test) : la raison d'un âge est une racine carrée, sans puissance fractionnaire (même résultat sur toute machine).
function M.value(age)
  age = math.floor(tonumber(age) or 0)
  local T = M.TIERS
  if age <= T[1].age then return T[1].ref_mu end
  -- T[i] : dernier palier atteint (sa valeur exacte, sans arrondi de produit) ; raison : celle du segment qui suit (le dernier au-delà)
  local i = 1
  while i < #T and T[i + 1].age <= age do i = i + 1 end
  local j = math.min(i, #T - 1)
  local a, b = T[j], T[j + 1]
  local r = math.sqrt(b.ref_mu / a.ref_mu)
  local v = T[i].ref_mu
  for _ = 1, age - T[i].age do v = v * r end
  return v
end

--- Bonus (pourcents entiers) du module `m` posé sur un géant de l'âge `age` ; sans âge, le bonus nominal (sur le géant de son palier).
function M.bonus_of(m, age)
  if age == nil then return m.bonus end
  local x = m.bonus * M.value(m.age) / M.value(age)
  return math.max(1, math.floor(x + 0.5))
end

---------------------------------------------------------------------------------------------------
-- Règle du bonus
---------------------------------------------------------------------------------------------------
--- Bonus d'une grille, à partir de la LISTE des noms des équipements posés (LuaEquipmentGrid::equipment, un nom par équipement) :
--- { portee = pourcents, puissance = pourcents, brut = { portee =, puissance = } } ; les noms inconnus sont ignorés (un équipement d'un autre
--- mod ne compte pas). Chaque module vaut M.bonus_of(m, age) (`age` : celui du géant qui porte la grille ; sans âge, le nominal). Somme
--- d'entiers par type, puis plafond du type.
function M.bonus(names, age)
  local brut = {}
  for _, t in ipairs(M.TYPES) do brut[t.id] = 0 end
  for _, n in ipairs(names or {}) do
    local m = by_name[n]
    if m then brut[m.type] = brut[m.type] + M.bonus_of(m, age) end
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

--- Bonus le plus fort qu'un géant peut porter, par type (tous ses emplacements du meilleur palier ouvert à l'âge `age`, à la valeur de ce
--- module SUR CE GÉANT, plafonné).
function M.max_bonus(giant_id, age)
  local out = {}
  local n = M.slots(giant_id)
  local g_age = M.giant_age(giant_id)
  for _, t in ipairs(M.TYPES) do
    local best = 0
    for _, m in ipairs(M.MODULES) do
      local b = M.bonus_of(m, g_age)
      if m.type == t.id and m.age <= (age or 99) and b > best then best = b end
    end
    out[t.id] = math.min(best * n, t.cap)
  end
  return out
end

--- Coup « hors portée de base » : la cible est au-delà de la portée du géant SANS module (le tir n'existe que grâce au module de portée).
--- Sert au marqueur visuel du script. `d` : distance à la cible (tuiles).
function M.beyond_base(r, d) return d > r.range end

---------------------------------------------------------------------------------------------------
-- Factions (QCM-7/11 du DC : « Oui, selon leur âge » ; leurs géants reçoivent les modules de leur âge)
---------------------------------------------------------------------------------------------------
--- Garniture de `n` emplacements sur un géant de l'âge `g_age` : le meilleur palier ouvert à l'âge `age` (par défaut celui du géant),
--- PUISSANCE d'abord jusqu'à son plafond, puis PORTÉE, chaque module compté à sa valeur sur ce géant. Rend la liste des noms à poser.
function M.loadout_n(n, g_age, age)
  local out = {}
  age = age or g_age
  for _, tid in ipairs({ "puissance", "portee" }) do
    local best
    for _, m in ipairs(M.MODULES) do
      if m.type == tid and m.age <= (age or 0) and (not best or m.bonus > best.bonus) then best = m end
    end
    if best then
      local cap = type_by_id[tid].cap
      local sum = 0
      while #out < n and sum < cap do
        out[#out + 1] = best.name
        sum = sum + M.bonus_of(best, g_age)
      end
    end
  end
  return out
end

--- Garniture d'un géant à grille (Cairn à Tournesol) quand son camp a ouvert l'âge `age`.
function M.loadout(giant_id, age)
  return M.loadout_n(M.slots(giant_id), M.giant_age(giant_id), age)
end

--- Bonus d'un géant de FACTION sans grille (Torique, Héliaste, Couronné de robotsjeu ; appel posé par le lot EXPERIMENTAUX dans
--- script/robots/geant.lua, au crochet Armee.hooks.giant_setup) : `n` emplacements garnis des modules de son âge (M.loadout_n), comptés à
--- leur valeur sur lui. Rend une table neuve, jamais nil : { portee = fraction, puissance = fraction (0,25 = +25 %, prêtes pour
--- G.set_bonus), pct = { portee =, puissance = } (pourcents entiers), modules = { noms } } ; des zéros sous l'âge du premier palier ou
--- sans emplacement.
function M.bonus_age(age, n)
  age = math.floor(tonumber(age) or 0)
  n = math.floor(tonumber(n) or 0)
  local names = {}
  if age >= M.TIERS[1].age and n > 0 then names = M.loadout_n(n, age, age) end
  local b = M.bonus(names, age)
  return { portee = b.portee / 100, puissance = b.puissance / 100, pct = { portee = b.portee, puissance = b.puissance }, modules = names }
end

return M
