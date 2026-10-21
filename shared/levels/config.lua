--[[
  Niveaux de bâtiments « façon Clash of Clans » (session 5, Directeur Créatif : « niveau Clash of Clans en
  termes d'échelons, de qualité de levels… pratiquement idle game dans l'idée »). Pur Lua : données et
  règles, testables hors jeu ; lues par l'étape data (prototypes/levels.lua) et le runtime (script/levels/).

  Règles du jeu :
  - Chaque famille de bâtiments a 10 niveaux. Le niveau 1 est le bâtiment vanilla (ou le centre de
    commandement de base) ; les niveaux 2 à 10 sont des prototypes à part, posables, minables (on récupère
    l'objet DU NIVEAU : un bâtiment ramassé garde son niveau).
  - Le CENTRE DE COMMANDEMENT (l'hôtel de ville) plafonne tout : un bâtiment ne dépasse jamais
    niveau du centre + 1. Sans centre, rien ne s'améliore. Un seul centre par force.
  - Les OUVRIERS D'AMÉLIORATION : 1 chantier à la fois aux niveaux 1-3 du centre, puis 2, 3, 4.
  - Une amélioration coûte des objets (prélevés dans l'inventaire du joueur puis dans le centre) et dure
    un temps qui croît géométriquement ; le bâtiment est HORS SERVICE pendant le chantier. Les murs
    s'améliorent instantanément (comme dans Clash of Clans), rangée entière possible.
  - Le DESIGN change à chaque niveau (voir L.materials, L.foundation, L.glow, L.halo) : matériau, socle,
    lueur, halo de nuit, taille.
]]

local L = {}

L.MAX = 10
L.PREFIX = "fo-lvl-"

---------------------------------------------------------------------------------------------------
-- Design par niveau : une couleur de matériau DIFFÉRENTE à chaque niveau (lisible d'un coup d'œil, comme
-- les murs de Clash of Clans), puis socle, lueur et halo qui s'ajoutent. Les teintes multiplient les
-- sprites vanilla (gris, jaune, brun) : choisies sur aperçus calculés à partir des fichiers du jeu.
---------------------------------------------------------------------------------------------------
L.materials = {
  [1] = { key = "iron" },
  [2] = { key = "steel", tint = { r = 0.80, g = 0.88, b = 1.00 } },
  [3] = { key = "copper", tint = { r = 1.00, g = 0.66, b = 0.50 } },
  [4] = { key = "gold", tint = { r = 1.00, g = 0.86, b = 0.42 } },
  [5] = { key = "jade", tint = { r = 0.62, g = 0.95, b = 0.76 } },
  [6] = { key = "amethyst", tint = { r = 0.82, g = 0.62, b = 1.00 } },
  [7] = { key = "obsidian", tint = { r = 0.46, g = 0.43, b = 0.54 } },
  [8] = { key = "ruby", tint = { r = 1.00, g = 0.50, b = 0.50 } },
  [9] = { key = "sapphire", tint = { r = 0.58, g = 0.80, b = 1.00 } },
  [10] = { key = "white-gold", tint = { r = 1.00, g = 0.94, b = 0.74 } },
}

--- Lueur (couche additive « draw_as_glow », visible jour et nuit) : couleur et intensité.
L.glow = {
  [5] = { color = { r = 0.40, g = 1.00, b = 0.65 }, alpha = 0.06 },
  [6] = { color = { r = 0.65, g = 0.30, b = 1.00 }, alpha = 0.10 },
  [7] = { color = { r = 1.00, g = 0.32, b = 0.06 }, alpha = 0.18 },
  [8] = { color = { r = 1.00, g = 0.15, b = 0.20 }, alpha = 0.18 },
  [9] = { color = { r = 0.20, g = 0.70, b = 1.00 }, alpha = 0.22 },
  [10] = { color = { r = 1.00, g = 0.88, b = 0.55 }, alpha = 0.30 },
}

--- Halo de nuit (copie « draw_as_light » du sprite) : intensité.
L.halo = { [6] = 0.20, [7] = 0.30, [8] = 0.35, [9] = 0.40, [10] = 0.60 }

--- Socle sous le bâtiment (texture d'un sol vanilla découpée à la taille de l'emprise).
L.foundation = {
  [2] = { tile = "stone-path" },
  [3] = { tile = "concrete" },
  [4] = { tile = "refined-concrete" },
  [5] = { tile = "refined-concrete" },
  [6] = { tile = "refined-concrete" },
  [7] = { tile = "refined-hazard-concrete" },
  [8] = { tile = "refined-hazard-concrete" },
  [9] = { tile = "refined-hazard-concrete" },
  [10] = { tile = "refined-concrete", tint = { r = 1.00, g = 0.84, b = 0.42 } },
}

--- Taille du sprite (le bâtiment « grandit » un peu à chaque niveau ; emprise inchangée).
function L.sprite_scale(n) return 1 + 0.012 * (n - 1) end

---------------------------------------------------------------------------------------------------
-- Familles
--   stats : { chemin, op, k } appliqué au prototype du niveau 1 :
--     "mul" : v × (1 + k·(n-1))     "add" : v + k·(n-1)     "pow" : v × k^(n-1)
--   cost  : coût du passage au niveau n (n ≥ 2) : base × growth^(n-2), plus les matériaux de palier
--   time  : durée du chantier vers le niveau n : time0 × 1,5^(n-2) secondes (0 = instantané)
---------------------------------------------------------------------------------------------------
L.families = {
  {
    key = "command", type = "container", base = "fo-command-center", size = 4,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.20 },
      { path = { "inventory_size" }, op = "add", k = 16 },
    },
    cost = { base = { { "iron-plate", 100 }, { "copper-plate", 50 }, { "stone-brick", 50 }, { "electronic-circuit", 20 } },
             growth = 1.6, tier_scale = 4 },
    time0 = 30,
  },
  {
    key = "gun", type = "ammo-turret", base = "gun-turret", size = 2,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "attack_parameters", "damage_modifier" }, op = "mul", k = 0.08, default = 1 },
      { path = { "attack_parameters", "range" }, op = "add", k = 0.25 },
      { path = { "rotation_speed" }, op = "mul", k = 0.05 },
    },
    cost = { base = { { "iron-plate", 20 }, { "iron-gear-wheel", 10 }, { "copper-plate", 10 } }, growth = 1.5, tier_scale = 1 },
    time0 = 10,
  },
  {
    key = "laser", type = "electric-turret", base = "laser-turret", size = 2,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "attack_parameters", "damage_modifier" }, op = "mul", k = 0.08, default = 1 },
      { path = { "attack_parameters", "range" }, op = "add", k = 0.25 },
      { path = { "rotation_speed" }, op = "mul", k = 0.05 },
    },
    cost = { base = { { "steel-plate", 10 }, { "electronic-circuit", 10 }, { "battery", 6 } }, growth = 1.5, tier_scale = 1.5 },
    time0 = 15,
  },
  {
    key = "wall", type = "wall", base = "stone-wall", size = 1, instant = true, no_foundation = true, no_scale = true,
    stats = {
      { path = { "max_health" }, op = "pow", k = 1.30 },
    },
    -- Résistances : +1 de réduction fixe physique et explosion par niveau (en plus de la vanilla).
    resist_step = { physical = 1, explosion = 1 },
    cost = { base = { { "stone-brick", 4 } }, growth = 1.5, tier_scale = 0.1 },
    time0 = 0,
  },
  {
    key = "drill", type = "mining-drill", base = "electric-mining-drill", size = 3,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "mining_speed" }, op = "mul", k = 0.10 },
      { path = { "energy_usage" }, op = "mul", k = 0.07 },
    },
    cost = { base = { { "iron-plate", 20 }, { "iron-gear-wheel", 10 }, { "electronic-circuit", 6 } }, growth = 1.5, tier_scale = 1 },
    time0 = 12,
  },
  {
    key = "furnace", type = "furnace", base = "steel-furnace", size = 2,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "crafting_speed" }, op = "mul", k = 0.08 },
      { path = { "energy_usage" }, op = "mul", k = 0.06 },
    },
    cost = { base = { { "steel-plate", 6 }, { "stone-brick", 10 } }, growth = 1.5, tier_scale = 1 },
    time0 = 10,
  },
  {
    key = "assembler", type = "assembling-machine", base = "assembling-machine-2", size = 3,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "crafting_speed" }, op = "mul", k = 0.08 },
      { path = { "energy_usage" }, op = "mul", k = 0.06 },
    },
    cost = { base = { { "iron-plate", 20 }, { "iron-gear-wheel", 10 }, { "electronic-circuit", 10 } }, growth = 1.5, tier_scale = 1 },
    time0 = 15,
  },
}

--- Matériaux de palier ajoutés au coût à partir du niveau `from` (quantité × tier_scale × growth^(n-from)).
L.tier_costs = {
  { from = 4, item = "steel-plate", amount = 10 },
  { from = 5, item = "electronic-circuit", amount = 10 },
  { from = 6, item = "advanced-circuit", amount = 5 },
  { from = 7, item = "fo-tungsten-plate", amount = 8 },
  { from = 9, item = "processing-unit", amount = 4 },
  { from = 9, item = "fo-resonance-crystal", amount = 6 },
}

L.by_key = {}
for i, f in ipairs(L.families) do
  f.index = i
  L.by_key[f.key] = f
end

---------------------------------------------------------------------------------------------------
-- Noms
---------------------------------------------------------------------------------------------------
function L.name(family, n)
  if n == 1 then return family.base end
  return L.PREFIX .. family.key .. "-" .. n
end

local lookup = {}
for _, f in ipairs(L.families) do
  for n = 1, L.MAX do lookup[L.name(f, n)] = { family = f, level = n } end
end

--- Famille et niveau d'un nom d'entité ou d'objet, ou nil.
function L.parse(name)
  local r = lookup[name]
  if r then return r.family, r.level end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Règles
---------------------------------------------------------------------------------------------------
--- Valeur d'une statistique au niveau n à partir de la valeur du niveau 1.
function L.apply_stat(stat, v1, n)
  if stat.op == "mul" then return v1 * (1 + stat.k * (n - 1)) end
  if stat.op == "add" then return v1 + stat.k * (n - 1) end
  if stat.op == "pow" then return v1 * stat.k ^ (n - 1) end
  error("op inconnue " .. tostring(stat.op))
end

local function round_nice(x)
  if x < 10 then return math.max(1, math.floor(x + 0.5)) end
  if x < 100 then return math.floor(x / 5 + 0.5) * 5 end
  return math.floor(x / 10 + 0.5) * 10
end

--- Coût du passage au niveau n (n ≥ 2) : liste triée { {nom, quantité}, ... } (déterministe).
function L.cost(family, n)
  assert(n >= 2 and n <= L.MAX, "niveau hors bornes")
  local c = family.cost
  local acc, order = {}, {}
  local function add(item, q)
    if not acc[item] then order[#order + 1] = item; acc[item] = 0 end
    acc[item] = acc[item] + q
  end
  for _, b in ipairs(c.base) do add(b[1], round_nice(b[2] * c.growth ^ (n - 2))) end
  for _, t in ipairs(L.tier_costs) do
    if n >= t.from then add(t.item, round_nice(t.amount * c.tier_scale * c.growth ^ (n - t.from))) end
  end
  local out = {}
  for _, item in ipairs(order) do out[#out + 1] = { item, acc[item] } end
  return out
end

--- Durée du chantier vers le niveau n, en ticks (0 = instantané). factor : réglage de partie.
function L.time_ticks(family, n, factor)
  if family.instant or family.time0 == 0 then return 0 end
  return math.floor(family.time0 * 1.5 ^ (n - 2) * 60 * (factor or 1) + 0.5)
end

--- Niveau maximal autorisé pour une famille selon le niveau du centre de commandement (0 = pas de centre).
function L.max_level(family, cc_level)
  if family.key == "command" then return L.MAX end
  if not cc_level or cc_level < 1 then return 1 end
  return math.min(L.MAX, cc_level + 1)
end

--- Ouvriers d'amélioration (chantiers simultanés) selon le niveau du centre.
function L.builders(cc_level)
  if not cc_level or cc_level < 1 then return 0 end
  return 1 + math.floor((cc_level - 1) / 3)
end

--- Peut-on lancer l'amélioration vers le niveau n ? Renvoie true ou false, raison (clé de locale).
function L.check(family, n, cc_level, busy_builders)
  if n > L.MAX then return false, "max" end
  if n > L.max_level(family, cc_level) then
    if not cc_level or cc_level < 1 then return false, "no-cc" end
    return false, "cc-too-low"
  end
  if not (family.instant or family.time0 == 0) and (busy_builders or 0) >= L.builders(cc_level) then
    return false, "no-builder"
  end
  return true
end

return L
