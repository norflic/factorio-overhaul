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

---------------------------------------------------------------------------------------------------
-- Lot ARMES-AGES (9/11, directive du DC « balistique, armements et tourelles PAR ÂGE ») : la lignée « Bastion »,
-- UNE tourelle par âge d'armement dont le MODE d'attaque change (pas seulement les dégâts) :
--   âge 1 : cinetique (chargeurs, projectile)      âge 3 : arc (arcs électriques EN CHAÎNE : cible, puis voisins, puis leurs voisins)
--   âge 2 : laser (faisceau focalisé)              âge 4 : plasma (artillerie à zone : orbe lourde guidée, explosion de zone)
-- Un âge d'armement = une ÈRE des niveaux (shared/levels/config.lua : L.ERA_EPOCHS = 3 époques par ère) :
-- âge 1 = époques 1-3, âge 2 = 4-6, âge 3 = 7-9, âge 4 = 10-12. Les PNJ lisent ces DONNÉES (mode, âge, rôle, tech) : aucun
-- nom en dur dans les cerveaux. Prototypes : prototypes/arsenal_ages.lua ; test pur : tests/arsenal_ages_test.lua.
-- Équilibrage PROVISOIRE (le DC tranche) : coûts voisins de A.turrets et A.special_turrets ; la recherche (tech.count) et
-- la valeur des ingrédients croissent strictement avec l'âge (testé).
---------------------------------------------------------------------------------------------------
A.AGE_EPOCHS = 3
A.MODES = { "cinetique", "laser", "arc", "plasma" }

local PACKS = {
  age1 = { "automation-science-pack", "logistic-science-pack" },
  age2 = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack" },
  age3 = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack", "production-science-pack", "utility-science-pack" },
  age4 = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack", "production-science-pack", "utility-science-pack" },
}
A.AGE_PACKS = PACKS

A.ages = {
  {
    age = 1, mode = "cinetique", name = "fo-bastion-1", copy_type = "ammo-turret", copy = "gun-turret", role = "ligne",
    tint = { r = 0.78, g = 0.82, b = 0.92 }, glow = { r = 1.00, g = 0.75, b = 0.35 },
    hp = 700, range = 20, cooldown = 5, damage_modifier = 1.25, ammo_category = "bullet",
    ingredients = { { "gun-turret", 1 }, { "steel-plate", 8 }, { "iron-gear-wheel", 10 } },
    tech = { name = "fo-bastion-1", icon_from = "gun-turret", prerequisites = { "gun-turret", "military-2" },
      packs = PACKS.age1, count = 120, time = 30 },
  },
  {
    age = 2, mode = "laser", name = "fo-bastion-2", copy_type = "electric-turret", copy = "laser-turret", role = "ligne",
    tint = { r = 0.70, g = 0.95, b = 1.00 }, glow = { r = 0.35, g = 0.90, b = 1.00 },
    hp = 1400, range = 28, cooldown = 30, damage_modifier = 3, energy = "1200kJ", energy_scale = 1.5,
    beam = { copy = "laser-beam", teinte = { 0.45, 0.92, 1.00 }, coeur = { 0.85, 1.00, 1.00 }, epaisseur = 1.3 },
    ingredients = { { "laser-turret", 1 }, { "plastic-bar", 20 }, { "fo-tungsten-plate", 10 }, { "advanced-circuit", 10 } },
    tech = { name = "fo-bastion-2", icon_from = "laser-turret", prerequisites = { "fo-bastion-1", "laser-turret", "fo-tungsten-processing" },
      packs = PACKS.age2, count = 350, time = 30 },
  },
  {
    age = 3, mode = "arc", name = "fo-bastion-3", copy_type = "electric-turret", copy = "laser-turret", role = "nuee",
    tint = { r = 0.55, g = 0.80, b = 1.00 }, glow = { r = 0.45, g = 0.85, b = 1.00 },
    hp = 2000, range = 24, cooldown = 45, energy = "2MJ",
    -- arc : dégâts électriques sur la cible, puis SAUTS : chaque saut frappe les ennemis à `radius` du maillon précédent
    -- (part `share` des dégâts) ; le 1er saut tire un arc visible vers chacun (faisceau), le 2e frappe seulement.
    arc = { damage = 70, hops = { { radius = 4.5, share = 0.6, beam = true }, { radius = 3.5, share = 0.35 } } },
    ingredients = { { "laser-turret", 1 }, { "fo-resonance-crystal", 20 }, { "battery", 20 }, { "advanced-circuit", 15 } },
    tech = { name = "fo-bastion-3", icon_from = "laser-turret", prerequisites = { "fo-bastion-2", "fo-arc-and-acid" },
      packs = PACKS.age3, count = 700, time = 45 },
  },
  {
    age = 4, mode = "plasma", name = "fo-bastion-4", copy_type = "electric-turret", copy = "laser-turret", role = "siege",
    platform = "artillery",
    tint = { r = 0.95, g = 0.70, b = 1.00 }, glow = { r = 1.00, g = 0.45, b = 0.95 },
    hp = 3000, range = 36, min_range = 6, cooldown = 90, energy = "6MJ",
    -- plasma : orbe lourde (projectile guidé), dégâts directs puis explosion de zone (laser + explosion)
    plasma = { direct = 200, radius = 5, area = { laser = 250, explosion = 150 }, speed = 0.25 },
    ingredients = { { "laser-turret", 2 }, { "processing-unit", 10 }, { "fo-titanium-plate", 20 }, { "fo-superconducting-coil", 5 } },
    tech = { name = "fo-bastion-4", icon_from = "artillery", prerequisites = { "fo-bastion-3", "fo-titanium-processing", "fo-superconductors" },
      packs = PACKS.age4, count = 1500, time = 60 },
  },
}

-- Armes de poing et équipement expérimentaux du lot (mécaniques RÉELLES de 1.1, limites nommées dans prototypes/arsenal_ages.lua) :
--   fusil à rail        : DÉJÀ livré en session 4 (A.special_guns « fo-railgun », balle « fo-rail-slug » : action « line »,
--                         traverse tout sur 40 tuiles) ; inscrit ici pour que les cerveaux et le test le voient par les données ;
--   lanceur de singularités : projectile (roquette) qui ouvre un CHAMP (smoke-with-trigger) : dégâts électriques de zone et
--                         ralentissement à 15 % (sticker) pendant `duration` ticks. Pas d'attraction native en 1.1 : les
--                         ennemis sont RETENUS dans le champ, pas tirés vers son centre ;
--   projecteur de champ : équipement de défense active (active-defense-equipment, déclenché par sa télécommande) : onde qui
--                         REPOUSSE (push-back), ralentit (sticker), et pose un ANNEAU de flammes plasma (fire, durée bornée)
--                         autour du porteur. Pas de mur temporaire natif (aucun prototype à collision ET durée de vie).
A.hand_weapons = {
  { name = "fo-railgun", age = 3, mode = "rail", existing = "special_guns", ammo = "fo-rail-slug", tech = { name = "fo-railgun" } },
  {
    name = "fo-singularity-launcher", age = 3, mode = "singularite", copy = "rocket-launcher", ammo = "fo-singularity-charge",
    ammo_category = "fo-singularity", range = 30, cooldown = 90,
    tint = { r = 0.60, g = 0.35, b = 0.95 },
    field = { radius = 5.5, duration = 360, cooldown = 20, damage = 12, burst = 80, slow = 0.15, slow_ticks = 60 },
    ingredients = { { "rocket-launcher", 1 }, { "fo-resonance-crystal", 20 }, { "advanced-circuit", 15 }, { "battery", 10 } },
    ammo_ingredients = { { "fo-resonance-crystal", 3 }, { "battery", 1 }, { "explosives", 2 } }, ammo_energy = 8,
    tech = { name = "fo-singularity-launcher", icon_from = "rocketry", prerequisites = { "fo-bastion-3", "rocketry" },
      packs = PACKS.age3, count = 800, time = 45 },
  },
  {
    name = "fo-field-projector", age = 2, mode = "champ", copy = "discharge-defense-equipment", remote = "fo-field-projector-remote",
    tint = { r = 0.40, g = 0.90, b = 1.00 }, buffer = "6MJ", energy = "3MJ", cooldown = 300,
    field = { radius = 9, push = 5, slow = 0.3, slow_ticks = 180, damage = 20,
      ring = { count = 10, distance = 4, lifetime = 480, damage_per_tick = 0.4 } },
    ingredients = { { "energy-shield-equipment", 1 }, { "fo-tungsten-plate", 10 }, { "advanced-circuit", 10 }, { "battery", 5 } },
    remote_ingredients = { { "electronic-circuit", 1 } },
    tech = { name = "fo-field-projector", icon_from = "energy-shield-equipment", prerequisites = { "fo-bastion-2", "energy-shield-equipment" },
      packs = PACKS.age2, count = 400, time = 30 },
  },
}

-- Arme cataclysmique (prototype ACTIVABLE) : la FRAPPE ORBITALE. Capsule lancée sur une position ; à l'arrivée, un drone de
-- marquage (combat-robot immobile, durée de vie `delay` ticks) dont la destroy_action est la frappe : flash (explosion
-- nucléaire vanilla teintée), brûlure au sol et trois cercles de dégâts (force « not-same » : épargne les siens).
-- Recette verrouillée derrière la DERNIÈRE technologie de l'âge 4 (fo-bastion-4).
A.cataclysm = {
  name = "fo-orbital-strike", age = 4, mode = "orbital", copy = "poison-capsule", marker_copy = "defender",
  tint = { r = 1.00, g = 0.55, b = 0.25 }, range = 30, cooldown = 600, delay = 180,
  blast = { { radius = 8, laser = 2500, explosion = 1500 }, { radius = 16, explosion = 800 }, { radius = 24, explosion = 250 } },
  ingredients = { { "fo-superconducting-coil", 5 }, { "processing-unit", 10 }, { "explosives", 20 }, { "fo-resonance-crystal", 20 } },
  energy = 30,
  tech = { name = "fo-orbital-strike", icon_from = "atomic-bomb", prerequisites = { "fo-bastion-4" },
    packs = PACKS.age4, count = 2500, time = 60 },
}

-- Lot ASSAUTS-TITANESQUES (10/11) : BARRIÈRE ÉNERGÉTIQUE DE PÉRIMÈTRE, arme de fin de partie de l'âge 4. Mécanique RÉELLE de 1.1 :
-- une tourelle électrique 1×1 (emprise d'un mur : les ennemis contournent ou la mordent) à portée COURTE qui décharge un arc sur tout
-- ennemi qui franchit son champ (dégâts électriques de zone + autocollant de ralentissement) ; sans courant, le moteur l'éteint. Une
-- ligne de bornes espacées de `field.radius` × 2 au plus fait une barrière continue. Les PNJ la voient comme une tourelle électrique
-- (type du moteur) ; role « perimetre » pour les cerveaux qui lisent ces données. Sprites : rendu Blender (tools/render/pieces/arsenal/
-- barriere.py -> graphics/arsenal/barriere), tête vanilla réduite par-dessus. Équilibrage PROVISOIRE (le DC tranche).
A.perimetre = {
  name = "fo-perimeter-barrier", age = 4, mode = "barriere", copy_type = "electric-turret", copy = "laser-turret", role = "perimetre",
  tint = { r = 0.75, g = 0.80, b = 0.90 }, glow = { r = 0.10, g = 0.90, b = 1.00 },
  hp = 1800, range = 3.5, cooldown = 20, energy = "250kJ", buffer = "3MJ", input = "1.5MW", drain = "15kW",
  field = { radius = 2.5, damage = 45, dtype = "electric", slow = 0.35, slow_ticks = 90 },
  ingredients = { { "fo-armored-wall", 2 }, { "fo-superconducting-coil", 2 }, { "processing-unit", 2 }, { "fo-resonance-crystal", 4 } },
  tech = { name = "fo-perimeter-barrier", icon_from = "stone-wall", prerequisites = { "fo-bastion-4", "fo-superconductors" },
    packs = PACKS.age4, count = 1800, time = 60 },
}

--- Entrée de la lignée pour un âge (1 à 4), ou nil.
function A.age_turret(age)
  for _, t in ipairs(A.ages) do if t.age == age then return t end end
  return nil
end

--- Âge d'armement d'une époque des niveaux (1 à 4 ; au-delà de l'âge 4, l'âge 4 reste le dernier mode).
function A.age_of_epoch(epoch)
  local a = math.floor((epoch - 1) / A.AGE_EPOCHS) + 1
  if a > #A.ages then a = #A.ages end
  if a < 1 then a = 1 end
  return a
end

return A
