--[[
  Lot DESIGN-MODULES (5/11) : MODULES DES GÉANTS expérimentaux, prototypes. Données et règle : shared/robots/experimentaux_modules.lua ;
  exécution : script/robots/experimentaux_modules.lua ; icônes : graphics/modules-geants (tools/render/pieces/modules/icones_geants.py,
  commitées comme graphics/modules). PROPOSITION : rien en jeu sans le verdict du DC.

  À charger APRÈS prototypes/experimentaux.lua (qui charge prototypes/experimentaux_geants.lua) : ce fichier POSE la grille sur les 5
  géants déjà déclarés (data.raw["spider-vehicle"]) sans toucher aux fichiers du lot EXPERIMENTAUX.
  - catégorie d'équipement propre : les grilles des géants n'acceptent que nos modules, nos modules n'entrent dans aucune autre grille ;
  - équipement de type `battery-equipment` SANS capacité : il ne fait rien par lui-même, le script lit la grille au tir ;
  - un objet par module (placed_as_equipment_result), une recette à l'usine de robots de son âge, une technologie par module.
]]

local lib = require("prototypes.lib")
local Mod = require("shared.robots.experimentaux_modules")
local Xp = require("shared.robots.experimentaux")
local Ro = require("shared.content.robots")
local C = require("shared.content.crafts")
local ICONES = require("__factorio-overhaul__/graphics/modules-geants/icons")
local SPR = require("__factorio-overhaul__/graphics/robots/experimentaux/sprites")

local DIR = "__factorio-overhaul__/graphics/modules-geants/"
local out = {}

out[#out + 1] = { type = "equipment-category", name = Mod.CATEGORY }
out[#out + 1] = { type = "item-subgroup", name = Mod.SUBGROUP, group = "combat", order = "z[fo]-robots-xp-modules" }

-- Grilles : 2 cases de haut, 2 × emplacements de large ; posées sur les géants déjà déclarés
for _, r in ipairs(Xp.GEANTS) do
  local w, h = Mod.grid_size(r.id)
  assert(w > 0, "experimentaux_modules : geant sans emplacement " .. r.id)
  out[#out + 1] = { type = "equipment-grid", name = Mod.grid_name(r.id), width = w, height = h, equipment_categories = { Mod.CATEGORY } }
end

local function ingredients(list)
  local l = {}
  for _, g in ipairs(list) do l[#l + 1] = { type = "item", name = g[1], amount = g[2] } end
  return l
end

--- Technologie d'un module : autant d'unités que celle du géant de son âge (Xp.tech_units de la technologie de robot qui le précède),
--- packs de l'âge.
local function tech_count(after_giant)
  local g = Xp.robot(after_giant:sub(#Xp.PREFIX + 1))
  assert(g and g.is_giant, "experimentaux_modules : prérequis qui n'est pas un géant " .. tostring(after_giant))
  local robot_tech = Ro.tech(g.after)
  assert(robot_tech, "experimentaux_modules : technologie de robot absente " .. tostring(g.after))
  return Xp.tech_units(C.tech_count(robot_tech))
end

--- Icône du géant qui ouvre le palier d'un module (sprites des expérimentaux, D-6).
local function giant_icon(m)
  local id = Mod.tier(m.tier).after:sub(#Xp.PREFIX + 1)
  local i = SPR.corps[id] and SPR.corps[id].icone
  assert(i, "experimentaux_modules : icone du geant absente " .. id)
  return i
end

for _, m in ipairs(Mod.MODULES) do
  local ic = ICONES.objets[m.name]
  local eq = ICONES.equipements[m.name]
  local tc = ICONES.technos[m.tech]
  assert(ic and eq and tc, "experimentaux_modules : icones absentes pour " .. m.name .. " (icones_geants.py)")
  local icons = { { icon = DIR .. ic.fichier, icon_size = ic.icon_size, icon_mipmaps = ic.icon_mipmaps } }
  -- F43 : paramètres en chaînes. Bonus du module sur chacun des 5 géants (prix selon l'âge, QCM-7/11), ramené au plafond, puis le plafond.
  local params = {}
  for _, g in ipairs(Mod.SLOTS) do params[#params + 1] = tostring(math.min(Mod.bonus_of(m, g.age), Mod.type(m.type).cap)) end
  params[#params + 1] = tostring(Mod.type(m.type).cap)
  local function desc(cle) return { cle, params[1], params[2], params[3], params[4], params[5], params[6] } end
  out[#out + 1] = {
    type = "battery-equipment", name = m.name,
    localised_name = { "item-name." .. m.name }, localised_description = desc("item-description." .. m.name),
    sprite = { filename = DIR .. eq.fichier, width = eq.largeur, height = eq.hauteur, priority = "medium",
      hr_version = { filename = DIR .. eq.hr_fichier, width = eq.hr_largeur, height = eq.hr_hauteur, priority = "medium", scale = 0.5 } },
    shape = { width = Mod.SIDE, height = Mod.SIDE, type = "full" },
    energy_source = { type = "electric", usage_priority = "tertiary" },
    categories = { Mod.CATEGORY },
    background_color = eq.fond, background_border_color = eq.bord,
    take_result = m.name,
  }
  out[#out + 1] = {
    type = "item", name = m.name,
    localised_name = { "item-name." .. m.name }, localised_description = desc("item-description." .. m.name),
    icons = icons, subgroup = Mod.SUBGROUP, order = string.format("%s-%d", m.type, m.tier),
    placed_as_equipment_result = m.name, stack_size = 10,
  }
  local f = Ro.factory(m.factory)
  assert(f, "experimentaux_modules : usine inconnue " .. tostring(m.factory))
  out[#out + 1] = {
    type = "recipe", name = m.recipe, category = f.category, enabled = false, energy_required = Mod.TIME,
    ingredients = ingredients(m.ingredients), results = { { type = "item", name = m.name, amount = 1 } }, main_product = m.name,
    localised_name = { "item-name." .. m.name },
  }
  out[#out + 1] = lib.technology({
    name = m.tech,
    localised_name = { "technology-name." .. m.tech }, localised_description = desc("technology-description." .. m.tech),
    -- icône : le géant qui ouvre le palier, et le module en surimpression dans le quart bas droit (critique du 5/11 : le seul glyphe
    -- agrandi était pauvre). Couches : 256 / 64 = × 4 pour le géant ; le module à moitié, décalé de 64 (unités de l'icône finale).
    icons = { { icon = giant_icon(m).filename, icon_size = giant_icon(m).size },
      { icon = DIR .. tc.fichier, icon_size = tc.icon_size, icon_mipmaps = tc.icon_mipmaps, scale = 0.5, shift = { 64, 64 } } },
    effects = { lib.unlock(m.recipe) }, prerequisites = m.prerequisites,
    count = tech_count(Mod.tier(m.tier).after), packs = C.packs(m.age), time = 30,
    order = string.format("z[fo]-robots-xp-modules-%s-%d", m.type, m.tier),
  })
end

data:extend(out)

-- La grille des géants (VehiclePrototype::equipment_grid). Le prototype du géant reste celui du lot EXPERIMENTAUX : seule la grille s'ajoute.
for _, r in ipairs(Xp.GEANTS) do
  local proto = data.raw["spider-vehicle"][r.name]
  assert(proto, "experimentaux_modules : geant absent (charger apres prototypes/experimentaux) " .. r.name)
  proto.equipment_grid = Mod.grid_name(r.id)
end
