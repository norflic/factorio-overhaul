-- Lot RB-0 (31/10), essais E1 à E9 : prototypes de TEST, chargés SEULEMENT par la copie jetable du mod que fabrique
-- tools/autotest/robots/jetable.py (ce fichier y est recopié à la racine et appelé en fin de data-final-fixes.lua).
-- JAMAIS dans le mod livré.
--
--   E1/E7 : catégorie `rb0-robots`, machine `rb0-atelier` (3x3, 2 emplacements de module), kits `rb0-kit` et
--           `rb0-kit-b` (stack_size = 1), recettes à ingrédients au-delà d'une pile.
--   E2/E4/E5 : unités `rb0-u-<tag>` (boîte de collision ±tag/10 : 04 06 09 14 24), clones de `medium-biter`, et
--           `rb0-u-flot` (masque de collision réduit, boîte ±0,4).
--   E3/E4/E9 : araignées `rb0-spider-<n>` (create_spidertron vanilla, échelle n), canons `rb0-gun-<portée>`
--           (catégorie de munition `rb0-shell`), `rb0-spider-1-nomt` (sans cible militaire).
--   E6 : outil de sélection `rb0-selection` (glisser, Maj + glisser, droit, Maj + droit).
--   E8 : feuilles de remplissage `rb0-fill-<k>` si `rb0_fill.lua` existe (écrit par jetable.py --remplissage).

local protos = {}

local function dc(t) return table.deepcopy(t) end

local ICON_IRON = data.raw.item["iron-plate"]

-----------------------------------------------------------------------------------------------------------------
-- E1, E7 : machine, kits, recettes
-----------------------------------------------------------------------------------------------------------------
protos[#protos + 1] = { type = "recipe-category", name = "rb0-robots" }

local function kit(nom)
  return {
    type = "item", name = nom, localised_name = { "", nom },
    icon = ICON_IRON.icon, icon_size = ICON_IRON.icon_size, icon_mipmaps = ICON_IRON.icon_mipmaps,
    subgroup = "intermediate-product", order = "z[" .. nom .. "]", stack_size = 1,
  }
end
protos[#protos + 1] = kit("rb0-kit")
protos[#protos + 1] = kit("rb0-kit-b")

local atelier = dc(data.raw["assembling-machine"]["assembling-machine-2"])
atelier.name = "rb0-atelier"
atelier.localised_name = { "", "rb0-atelier" }
atelier.minable = nil
atelier.placeable_by = nil
atelier.fast_replaceable_group = nil
atelier.next_upgrade = nil
atelier.crafting_categories = { "rb0-robots" }
atelier.crafting_speed = 1
atelier.module_specification = { module_slots = 2 }
atelier.allowed_effects = { "consumption", "speed", "productivity", "pollution" }
atelier.energy_usage = "150kW"
atelier.energy_source = { type = "electric", usage_priority = "secondary-input", emissions_per_minute = 0 }
protos[#protos + 1] = atelier

local function recette(nom, ingredients, produit, temps)
  return {
    type = "recipe", name = nom, localised_name = { "", nom }, category = "rb0-robots", enabled = true,
    energy_required = temps, ingredients = ingredients, results = { { produit, 1 } }, allow_productivity = true,
    subgroup = "intermediate-product", order = "z[" .. nom .. "]",
  }
end
-- A : 10 plaques de fer -> kit (E1, E7). Grand : 200 pierres (pile 50) + 400 plaques (pile 100) -> kit B (E1).
-- B : 6 plaques de cuivre + 3 pierres -> kit B (E7).
protos[#protos + 1] = recette("rb0-kit-a", { { "iron-plate", 10 } }, "rb0-kit", 2)
protos[#protos + 1] = recette("rb0-kit-grand", { { "stone", 200 }, { "iron-plate", 400 } }, "rb0-kit-b", 3)
protos[#protos + 1] = recette("rb0-kit-b-cu", { { "copper-plate", 6 }, { "stone", 3 } }, "rb0-kit-b", 2)
-- Cristal du mod, si présent : 200 cristaux (pile lue au moteur) -> kit B.
if data.raw.item["fo-resonance-crystal"] then
  protos[#protos + 1] = recette("rb0-kit-cristal", { { "fo-resonance-crystal", 200 }, { "copper-plate", 4 } }, "rb0-kit-b", 3)
end

do -- témoin vanilla : même recette dans la catégorie « crafting », pour une assembling-machine-2 non modifiée
  local r = recette("rb0-kit-2ing-vanilla", { { "stone", 40 }, { "iron-plate", 80 } }, "rb0-kit", 1)
  r.category = "crafting"
  protos[#protos + 1] = r
end
protos[#protos + 1] = recette("rb0-kit-2ing-petit", { { "stone", 40 }, { "iron-plate", 80 } }, "rb0-kit", 1)

-- Variantes de E1 (quantité d'un seul ingrédient au-delà d'une pile, livré par bras) : pierre (pile 50) et plaque de fer (pile 100).
local VAR_QUANTITES = { { "stone", 20 }, { "stone", 50 }, { "stone", 60 }, { "stone", 100 }, { "stone", 200 },
  { "iron-plate", 100 }, { "iron-plate", 150 }, { "iron-plate", 300 } }
for _, v in ipairs(VAR_QUANTITES) do
  protos[#protos + 1] = recette("rb0-kit-" .. v[1] .. "-" .. v[2], { { v[1], v[2] } }, "rb0-kit", 1)
end

-- Les modules de productivité vanilla ont une LISTE de recettes permises : y ajouter les nôtres (E1, bonus de sortie).
for _, m in pairs(data.raw.module) do
  if m.effect and m.effect.productivity and m.limitation then
    for _, r in ipairs(protos) do
      if r.type == "recipe" then m.limitation[#m.limitation + 1] = r.name end
    end
  end
end

-----------------------------------------------------------------------------------------------------------------
-- E2, E4, E5 : unités à boîte de collision choisie
-----------------------------------------------------------------------------------------------------------------
local base = data.raw.unit["medium-biter"]
local function unite(nom, demi, masque)
  local u = dc(base)
  u.name = nom
  u.localised_name = { "", nom }
  u.minable = nil
  u.max_health = 3000
  u.healing_per_tick = 0
  u.resistances = nil
  u.collision_box = { { -demi, -demi }, { demi, demi } }
  u.selection_box = { { -math.max(demi, 0.7), -math.max(demi, 0.7) - 0.8 }, { math.max(demi, 0.7), math.max(demi, 0.7) } }
  u.movement_speed = 0.2
  u.vision_distance = 30
  u.corpse = nil
  u.dying_explosion = nil
  u.loot = nil
  -- comme les soldats de faction (prototypes/faction.lua) : une commande qui échoue ne détruit pas l'unité
  u.ai_settings = { destroy_when_commands_fail = false, allow_try_return_to_spawner = false, do_separation = true }
  if masque then u.collision_mask = masque end
  return u
end
for _, c in ipairs({ { "04", 0.4 }, { "06", 0.6 }, { "09", 0.9 }, { "14", 1.4 }, { "24", 2.4 } }) do
  protos[#protos + 1] = unite("rb0-u-" .. c[1], c[2])
end
protos[#protos + 1] = unite("rb0-u-flot", 0.4, { "not-colliding-with-itself" })

-----------------------------------------------------------------------------------------------------------------
-- E3, E4, E9 : canons, munition, araignées
-----------------------------------------------------------------------------------------------------------------
protos[#protos + 1] = { type = "ammo-category", name = "rb0-shell" }
protos[#protos + 1] = {
  type = "ammo", name = "rb0-shell", localised_name = { "", "rb0-shell" },
  icon = "__base__/graphics/icons/firearm-magazine.png", icon_size = 64, icon_mipmaps = 4,
  ammo_type = {
    category = "rb0-shell",
    action = {
      type = "direct",
      action_delivery = { type = "instant", target_effects = { { type = "damage", damage = { amount = 500, type = "physical" } } } },
    },
  },
  magazine_size = 10, stack_size = 200, subgroup = "ammo", order = "z[rb0-shell]",
}
local ROCKET_GUN = data.raw.gun["spidertron-rocket-launcher-1"]
for _, portee in ipairs({ 45, 60, 100 }) do
  protos[#protos + 1] = {
    type = "gun", name = "rb0-gun-" .. portee, localised_name = { "", "rb0-gun-" .. portee },
    icon = ROCKET_GUN.icon, icon_size = ROCKET_GUN.icon_size, icon_mipmaps = ROCKET_GUN.icon_mipmaps,
    subgroup = "gun", flags = { "hidden" }, order = "z[rb0-gun-" .. portee .. "]",
    attack_parameters = {
      type = "projectile", ammo_category = "rb0-shell", cooldown = 30, range = portee,
      projectile_creation_distance = 0, sound = ROCKET_GUN.attack_parameters.sound,
    },
    stack_size = 1,
  }
end

data:extend(protos)
protos = {}

-- Araignées : fonction vanilla create_spidertron (global, définie par data/base/prototypes/entity/entities.lua).
local function araignee(nom, echelle, jambe, vitesse_jambe, canons)
  create_spidertron({ name = nom, scale = echelle, leg_scale = jambe, leg_thickness = 1, leg_movement_speed = vitesse_jambe })
  local s = data.raw["spider-vehicle"][nom]
  s.localised_name = { "", nom }
  s.minable = nil
  s.equipment_grid = nil
  s.inventory_size = 20
  s.trash_inventory_size = 0
  if canons then s.guns = canons end
  for i = 1, 8 do
    data.raw["spider-leg"][nom .. "-leg-" .. i].localised_name = { "", nom .. " leg" }
  end
  return s
end

araignee("rb0-spider-1", 1, 1, 1)                                   -- vanilla, 4 lance-roquettes
local nomt = araignee("rb0-spider-1-nomt", 1, 1, 1)                  -- vanilla sans cible militaire
nomt.spider_engine.military_target = nil
araignee("rb0-spider-2", 2, 1, 2, { "rb0-gun-45" })
araignee("rb0-spider-3", 3, 1, 3, { "rb0-gun-60" })
araignee("rb0-spider-5", 5, 1.2, 5, { "rb0-gun-60" })               -- environ 40 tuiles de pattes à pattes
araignee("rb0-spider-5l", 5, 1.2, 5, { "rb0-gun-100" })             -- limite de portée
araignee("rb0-spider-8", 8, 1, 8, { "rb0-gun-60" })                 -- limite de taille
-- E9 (portée selon la taille) : échelles intermédiaires et canons croisés
araignee("rb0-spider-4", 4, 1, 4, { "rb0-gun-60" })
araignee("rb0-spider-6", 6, 1, 6, { "rb0-gun-60" })
araignee("rb0-spider-3l", 3, 1, 3, { "rb0-gun-100" })
araignee("rb0-spider-5g45", 5, 1.2, 5, { "rb0-gun-45" })
araignee("rb0-spider-8l", 8, 1, 8, { "rb0-gun-100" })

-----------------------------------------------------------------------------------------------------------------
-- E6 : outil de sélection (Directeur Créatif : « glisser = choisir mes robots », Maj = marche-attaque, droit = attaquer)
-----------------------------------------------------------------------------------------------------------------
local function couleur(r, g, b) return { r = r, g = g, b = b, a = 0.5 } end
protos[#protos + 1] = {
  type = "selection-tool", name = "rb0-selection", localised_name = { "", "rb0-selection" },
  icon = ICON_IRON.icon, icon_size = ICON_IRON.icon_size, icon_mipmaps = ICON_IRON.icon_mipmaps,
  flags = { "hidden", "only-in-cursor", "spawnable" }, subgroup = "tool", order = "z[rb0-selection]", stack_size = 1,
  selection_color = couleur(0.2, 0.9, 0.2), alt_selection_color = couleur(0.9, 0.9, 0.2),
  reverse_selection_color = couleur(0.9, 0.2, 0.2), alt_reverse_selection_color = couleur(0.2, 0.2, 0.9),
  chart_selection_color = couleur(0.2, 0.9, 0.2), chart_alt_selection_color = couleur(0.9, 0.9, 0.2),
  chart_reverse_selection_color = couleur(0.9, 0.2, 0.2), chart_alt_reverse_selection_color = couleur(0.2, 0.2, 0.9),
  selection_count_button_color = couleur(0.2, 0.9, 0.2), alt_selection_count_button_color = couleur(0.9, 0.9, 0.2),
  reverse_selection_count_button_color = couleur(0.9, 0.2, 0.2), alt_reverse_selection_count_button_color = couleur(0.2, 0.2, 0.9),
  selection_cursor_box_type = "entity", alt_selection_cursor_box_type = "entity",
  reverse_selection_cursor_box_type = "not-allowed", alt_reverse_selection_cursor_box_type = "not-allowed",
  selection_mode = { "same-force" },                 -- glisser : mes robots
  alt_selection_mode = { "nothing" },                -- Maj + glisser : une zone, sans entité
  reverse_selection_mode = { "enemy" },              -- bouton droit : ce qui est ennemi
  alt_reverse_selection_mode = { "nothing" },        -- Maj + droit : une zone, sans entité
  entity_type_filters = { "unit", "spider-vehicle" },
  reverse_entity_type_filters = { "unit", "unit-spawner", "turret", "spider-vehicle" },
}
data:extend(protos)
protos = {}

-----------------------------------------------------------------------------------------------------------------
-- E8 : feuilles de remplissage (jetable.py --remplissage N écrit rb0_fill.lua et graphics/rb0/fill-<k>.png)
-----------------------------------------------------------------------------------------------------------------
local ok, FILL = pcall(require, "rb0_fill")
if ok and type(FILL) == "table" then
  for k, f in ipairs(FILL.feuilles) do
    protos[#protos + 1] = {
      type = "simple-entity-with-owner", name = "rb0-fill-" .. k, localised_name = { "", "rb0-fill-" .. k },
      icon = ICON_IRON.icon, icon_size = ICON_IRON.icon_size, icon_mipmaps = ICON_IRON.icon_mipmaps,
      flags = { "placeable-neutral", "placeable-off-grid", "not-on-map" },
      max_health = 100, collision_box = { { -1, -1 }, { 1, 1 } }, collision_mask = {}, selection_box = { { -1, -1 }, { 1, 1 } },
      render_layer = "object", picture = {
        filename = "__factorio-overhaul__/" .. f.fichier, priority = "extra-high", width = f.cote, height = f.cote,
        scale = FILL.echelle or 0.0125,
      },
    }
  end
end
if #protos > 0 then data:extend(protos) end
log("[RB0-JETABLE] prototypes de test chargés ; remplissage : " .. tostring(ok and #FILL.feuilles or 0) .. " feuille(s)")
