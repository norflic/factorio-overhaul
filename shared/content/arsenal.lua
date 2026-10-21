--[[
  Arsenal : munitions, armes, tourelles et murs en paliers. Pur Lua.

  Logique de conception : chaque arme répond à une famille de déchiqueteurs (shared/content/enemies.lua)
  et consomme une ressource nouvelle (shared/content/world.lua) :
  - Tungstène  -> perforation (blindés), tourelle lourde, murs blindés ;
  - Méthane    -> munitions incendiaires (contre couvées en masse ; inutiles contre les ignés) ;
  - Cristal    -> plasma (dégâts laser, ignore l'armure physique des blindés) et tourelle laser lourde.
]]

local A = {}

A.tungsten_tint = { r = 0.55, g = 0.62, b = 0.80 }

A.ammo = {
  {
    name = "fo-tungsten-rounds-magazine", tier = 4, tech = 1,
    tint = { r = 0.60, g = 0.70, b = 0.95 },
    damage = { physical = 40 },
    ingredients = { { "piercing-rounds-magazine", 1 }, { "fo-tungsten-plate", 2 } },
    energy = 5,
  },
  {
    name = "fo-explosive-rounds-magazine", tier = 5, tech = 2,
    tint = { r = 1.00, g = 0.65, b = 0.35 },
    damage = { physical = 30 },
    splash = { type = "explosion", amount = 15, radius = 2 },
    ingredients = { { "fo-tungsten-rounds-magazine", 1 }, { "explosives", 1 } },
    energy = 6,
  },
  {
    name = "fo-incendiary-rounds-magazine", tier = 6, tech = 2,
    tint = { r = 1.00, g = 0.40, b = 0.20 },
    damage = { physical = 30 },
    sticker = "fire-sticker",
    ingredients = { { "fo-tungsten-rounds-magazine", 1 }, { type = "fluid", name = "fo-methane", amount = 20 } },
    category = "chemistry",
    energy = 6,
  },
  {
    name = "fo-plasma-rounds-magazine", tier = 7, tech = 3,
    tint = { r = 0.85, g = 0.45, b = 1.00 },
    damage = { physical = 70, laser = 30 },
    ingredients = { { "fo-tungsten-rounds-magazine", 1 }, { "fo-resonance-crystal", 2 }, { "processing-unit", 1 } },
    energy = 10,
  },
}

A.guns = {
  {
    name = "fo-heavy-machine-gun", copy = "submachine-gun", tech = 1,
    tint = { r = 0.60, g = 0.68, b = 0.90 },
    cooldown = 3, range = 22, movement_slow_down_factor = 0.5,
    ingredients = { { "submachine-gun", 1 }, { "fo-tungsten-plate", 10 }, { "steel-plate", 5 } },
  },
}

A.turrets = {
  {
    name = "fo-heavy-gun-turret", copy_type = "ammo-turret", copy = "gun-turret", tech = 1,
    tint = { r = 0.80, g = 0.84, b = 0.95 },
    -- Évolution (session 4) : socle d'artillerie blindé au lieu du socle agrandi, voyants bleu tungstène.
    platform = "artillery", glow = { r = 0.35, g = 0.65, b = 1.00 },
    scale = 1.5, hp = 2000, range = 24, cooldown = 4, damage_modifier = 1.5,
    ingredients = { { "gun-turret", 2 }, { "fo-tungsten-plate", 20 }, { "steel-plate", 10 } },
  },
  {
    name = "fo-heavy-laser-turret", copy_type = "electric-turret", copy = "laser-turret", tech = 2,
    tint = { r = 0.92, g = 0.82, b = 1.00 },
    -- Évolution (session 4) : posée sur le socle d'une balise, lueur de cristal violette.
    platform = "beacon", glow = { r = 0.80, g = 0.35, b = 1.00 },
    scale = 1.5, hp = 3000, range = 32, damage_modifier = 2, energy_scale = 2.5, -- ×2 vs tourelle laser vanilla
    ingredients = { { "laser-turret", 2 }, { "fo-resonance-crystal", 10 }, { "fo-tungsten-plate", 20 } },
  },
}

A.walls = {
  {
    name = "fo-reinforced-wall", tech = 1,
    tint = { r = 0.78, g = 0.80, b = 0.88 },
    hp = 1200,
    resist_bonus = { physical = { 5, 10 }, explosion = { 10, 20 }, impact = { 0, 10 } },
    ingredients = { { "stone-wall", 1 }, { "steel-plate", 2 }, { "concrete", 5 } },
  },
  {
    name = "fo-armored-wall", tech = 2,
    tint = { r = 0.48, g = 0.55, b = 0.75 },
    hp = 3500,
    resist_bonus = { physical = { 15, 30 }, explosion = { 20, 40 }, acid = { 0, 15 }, electric = { 0, 30 } },
    ingredients = { { "fo-reinforced-wall", 1 }, { "fo-tungsten-plate", 4 } },
  },
}

A.techs = {
  {
    name = "fo-heavy-weapons-1", icon_from = "military-3",
    prerequisites = { "military-3", "fo-tungsten-processing" },
    packs = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack" },
    count = 300, time = 30,
  },
  {
    name = "fo-heavy-weapons-2", icon_from = "military-4",
    prerequisites = { "fo-heavy-weapons-1", "laser-turret", "fo-methane-processing", "military-4" },
    packs = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack", "utility-science-pack" },
    count = 600, time = 45,
  },
  {
    name = "fo-heavy-weapons-3", icon_from = "uranium-ammo",
    prerequisites = { "fo-heavy-weapons-2", "uranium-ammo" },
    packs = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack", "production-science-pack", "utility-science-pack" },
    count = 1200, time = 60,
  },
}

---------------------------------------------------------------------------------------------------
-- Session 4 : nouvelles FAMILLES d'armes, chacune avec une silhouette composée de pièces vanilla
-- (socle d'une tourelle, tête d'une autre) et un rôle face aux familles de déchiqueteurs :
--   canon         : coups lourds perforants (obus de char)     -> blindés
--   mortier       : obus en cloche, zone, angle mort rapproché -> couvées en masse, nids
--   arc électrique: frappe de zone, saute d'une cible à l'autre -> nuées ; inutile contre les foudroyants
--   pulvérisateur : jet d'acide (acide sulfurique), ralentit    -> ignés (immunisés au feu), blindés
---------------------------------------------------------------------------------------------------
A.special_turrets = {
  {
    name = "fo-cannon-turret", style = "cannon", tech = 4,
    tint = { r = 0.70, g = 0.72, b = 0.62 }, hp = 2200, range = 32, min_range = 5, cooldown = 75,
    ingredients = { { "gun-turret", 2 }, { "steel-plate", 25 }, { "engine-unit", 4 }, { "fo-tungsten-plate", 15 } },
  },
  {
    name = "fo-mortar-turret", style = "mortar", tech = 4,
    tint = { r = 0.55, g = 0.60, b = 0.42 }, hp = 1600, range = 46, min_range = 14, cooldown = 120,
    ingredients = { { "steel-plate", 30 }, { "iron-gear-wheel", 20 }, { "electronic-circuit", 15 }, { "stone-brick", 20 } },
  },
  {
    name = "fo-tesla-turret", style = "tesla", tech = 5,
    tint = { r = 0.45, g = 0.85, b = 1.00 }, hp = 1200, range = 20, cooldown = 45,
    arc_damage = 45, arc_radius = 3.5, energy = "1.2MJ",
    ingredients = { { "laser-turret", 1 }, { "fo-resonance-crystal", 15 }, { "copper-cable", 60 }, { "advanced-circuit", 10 } },
  },
  {
    name = "fo-acid-sprayer", style = "acid", tech = 5,
    tint = { r = 0.55, g = 1.00, b = 0.35 }, hp = 1500, range = 26, min_range = 4,
    acid_damage = 14, slow = 0.5, fluid = "sulfuric-acid",
    ingredients = { { "flamethrower-turret", 1 }, { "plastic-bar", 20 }, { "fo-tungsten-plate", 10 }, { "pipe", 10 } },
  },
}

A.special_ammo = {
  {
    name = "fo-mortar-shell", category = "fo-mortar", tech = 4, copy_icon = "explosive-cannon-shell",
    tint = { r = 0.55, g = 0.60, b = 0.42 }, explosion = 180, physical = 30, radius = 5,
    ingredients = { { "grenade", 1 }, { "steel-plate", 2 }, { "iron-gear-wheel", 1 } }, energy = 6,
  },
  {
    name = "fo-tungsten-cannon-shell", category = "cannon-shell", tech = 4, copy_icon = "cannon-shell",
    tint = { r = 0.60, g = 0.70, b = 0.95 }, physical = 420, explosion = 100, pierce = 4,
    ingredients = { { "cannon-shell", 1 }, { "fo-tungsten-plate", 3 } }, energy = 8,
  },
  {
    name = "fo-launcher-grenade", category = "fo-launcher-grenade", tech = 4, copy_icon = "grenade",
    tint = { r = 0.80, g = 0.75, b = 0.40 }, explosion = 45, radius = 3.5,
    ingredients = { { "grenade", 1 }, { "iron-plate", 1 } }, energy = 2,
  },
  {
    name = "fo-rail-slug", category = "fo-rail-slug", tech = 6, copy_icon = "uranium-rounds-magazine",
    tint = { r = 0.55, g = 0.70, b = 1.00 }, physical = 380, line_range = 40,
    ingredients = { { "fo-tungsten-plate", 4 }, { "copper-cable", 4 } }, energy = 4,
  },
  {
    name = "fo-arc-cell", category = "fo-arc-cell", tech = 5, copy_icon = "battery",
    tint = { r = 0.45, g = 0.85, b = 1.00 }, arc_damage = 30, arc_radius = 3,
    ingredients = { { "battery", 1 }, { "copper-cable", 4 } }, energy = 3,
  },
}

A.special_guns = {
  {
    name = "fo-grenade-launcher", copy = "rocket-launcher", ammo = "fo-launcher-grenade", tech = 4,
    tint = { r = 0.80, g = 0.75, b = 0.40 }, range = 24, cooldown = 45,
    ingredients = { { "submachine-gun", 1 }, { "steel-plate", 10 }, { "iron-gear-wheel", 10 } },
  },
  {
    name = "fo-railgun", copy = "submachine-gun", ammo = "fo-rail-slug", tech = 6,
    tint = { r = 0.55, g = 0.70, b = 1.00 }, range = 40, cooldown = 75,
    ingredients = { { "fo-heavy-machine-gun", 1 }, { "fo-tungsten-plate", 30 }, { "advanced-circuit", 10 }, { "fo-resonance-crystal", 10 } },
  },
  {
    name = "fo-arc-gun", copy = "submachine-gun", ammo = "fo-arc-cell", tech = 5,
    tint = { r = 0.45, g = 0.85, b = 1.00 }, range = 16, cooldown = 30,
    ingredients = { { "submachine-gun", 1 }, { "fo-resonance-crystal", 10 }, { "battery", 10 } },
  },
}

-- Technologies 4-6 (suite de fo-heavy-weapons 1-3).
A.special_techs = {
  [4] = {
    name = "fo-siege-weapons", icon_from = "tank",
    prerequisites = { "fo-heavy-weapons-1", "tank", "military-3" },
    packs = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack" },
    count = 500, time = 30,
  },
  [5] = {
    name = "fo-arc-and-acid", icon_from = "laser-turret",
    prerequisites = { "fo-heavy-weapons-2", "sulfur-processing", "battery" },
    packs = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack", "utility-science-pack" },
    count = 800, time = 45,
  },
  [6] = {
    name = "fo-railgun", icon_from = "uranium-ammo",
    prerequisites = { "fo-heavy-weapons-3", "fo-arc-and-acid" },
    packs = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack", "production-science-pack", "utility-science-pack" },
    count = 1500, time = 60,
  },
}

return A
