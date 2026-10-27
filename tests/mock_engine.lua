--[[
  Moteur Factorio SIMULÉ pour les tests hors-jeu (Lua 5.2). Partagé par tests/run.lua et tests/war_test.lua.

  Simule : événements, pathfinder asynchrone (latence, échecs, "busy", requêtes perdues), physique 8
  directions, persistance ou non de walking_state (H1), forces et relations, entités (inventaires de
  tourelle, commandes d'unités, mort/destruction), groupes d'unités avec combats abstraits, gisements,
  tuiles, rendu, fichiers, sauvegarde/rechargement (les tables locales sont perdues, `global` conservé).
  Suite d'intégration du lot V3-T : la boîte d'une entité (bounding_box) et la recherche par zone
  (find_entities_filtered et count_entities_filtered avec `area`) suivent la BOÎTE DE COLLISION du prototype,
  comme le moteur ; comportement de circuit (get_control_behavior, get_or_create_control_behavior), recette
  d'une machine (get_recipe, set_recipe) et retrait des décors (surface.destroy_decoratives, appels relevés).

  Il ne simule PAS le vrai moteur : il valide la logique Lua, la sérialisabilité, le déterminisme.
  Toute API appelée par le mod et absente d'ici provoque une erreur explicite (tables strictes).
]]

local M = {}

local MOD_MODULE_PATTERN = "^script%."

local W -- monde courant

--- Lot IA-G : prototypes d'objets du mock, ITÉRABLES (forme de LuaItemPrototype : name, type, fuel_value,
--- localised_name), tirés des recettes ; types militaires et pouvoir calorifique des combustibles vanilla.
local ITEM_TYPE = {
  ["firearm-magazine"] = "ammo", ["piercing-rounds-magazine"] = "ammo", ["shotgun-shell"] = "ammo",
  ["piercing-shotgun-shell"] = "ammo", ["uranium-rounds-magazine"] = "ammo", ["rocket"] = "ammo",
  ["pistol"] = "gun", ["submachine-gun"] = "gun", ["shotgun"] = "gun", ["combat-shotgun"] = "gun",
  ["rocket-launcher"] = "gun", ["light-armor"] = "armor", ["heavy-armor"] = "armor", ["modular-armor"] = "armor",
  ["grenade"] = "capsule", ["cluster-grenade"] = "capsule", ["poison-capsule"] = "capsule",
  ["slowdown-capsule"] = "capsule", ["defender-capsule"] = "capsule",
}
local FUEL_VALUE = { coal = 4e6, wood = 2e6, ["solid-fuel"] = 12e6 }
function M.item_prototypes(recipes)
  local out = {}
  local function add(n)
    if not out[n] then
      out[n] = { name = n, type = ITEM_TYPE[n] or "item", fuel_value = FUEL_VALUE[n] or 0,
        localised_name = { "item-name." .. n } }
    end
  end
  local names = {}
  for name in pairs(recipes or {}) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local r = recipes[name]
    for _, p in ipairs(r.products or {}) do if p.type ~= "fluid" then add(p.name) end end
    for _, i in ipairs(r.ingredients or {}) do if i.type ~= "fluid" then add(i.name) end end
  end
  for _, n in ipairs({ "coal", "copper-ore", "iron-ore", "stone", "wood" }) do add(n) end
  return setmetatable(out, { __index = function(_, name)
    return { name = name, localised_name = { "item-name." .. name } }
  end })
end

function M.world() return W end

--- Lot IA3-c : prototypes de technologies du mock (forme de LuaTechnologyPrototype) depuis la fixture des coûts FINAUX
--- (tests/fixtures/tech_ai3_final.lua, contrôlée en moteur réel par le scénario ia3-donnees, F275). Lu une fois.
local tech_cache = nil
function M.technology_prototypes()
  if tech_cache then return tech_cache end
  local raw = dofile("tests/fixtures/tech_ai3_final.lua")
  local out = {}
  for name, t in pairs(raw) do
    local ing, eff = {}, {}
    for _, i in ipairs(t.ingredients or {}) do ing[#ing + 1] = { type = "item", name = i[1], amount = i[2] } end
    for _, r in ipairs(t.unlocks or {}) do eff[#eff + 1] = { type = "unlock-recipe", recipe = r } end
    out[name] = { name = name, enabled = true, hidden = false, research_unit_ingredients = ing, effects = eff,
      research_unit_count = t.count, research_unit_energy = t.time * 60, prerequisites = {} }
  end
  for name, t in pairs(raw) do
    for _, p in ipairs(t.prerequisites or {}) do if out[p] then out[name].prerequisites[p] = out[p] end end
  end
  tech_cache = out
  return out
end

local function strict(t, what)
  return setmetatable(t, { __index = function(_, k) error(what .. " inconnu : " .. tostring(k), 2) end })
end

function M.ls_to_string(ls)
  if type(ls) ~= "table" then return tostring(ls) end
  if ls._profiler then return "<profiler>" end
  local parts = {}
  for i = 2, #ls do parts[#parts + 1] = M.ls_to_string(ls[i]) end
  if ls[1] ~= "" and type(ls[1]) == "string" then return "{" .. ls[1] .. ":" .. table.concat(parts, ",") .. "}" end
  return table.concat(parts)
end

local DIRV = {
  [0] = { 0, -1 }, { 0.7071, -0.7071 }, { 1, 0 }, { 0.7071, 0.7071 },
  { 0, 1 }, { -0.7071, 0.7071 }, { -1, 0 }, { -0.7071, -0.7071 },
}

---------------------------------------------------------------------------------------------------
-- Forces
---------------------------------------------------------------------------------------------------
local function new_force(name)
  -- Lot V3-T3 : index de la force (LuaForce.index ; game.forces[index] la retrouve, voir new_world).
  W.force_index = (W.force_index or 0) + 1
  local f = { _lua_object = true, name = name, index = W.force_index, valid = true, _cease = {}, _ammo_mod = {}, _turret_mod = {} }
  f.get_spawn_position = function(surface) return { x = 0, y = 0 } end
  -- Lot V3-T3 : messages à une force (relevés).
  f.print = function(s) W.force_prints = W.force_prints or {}; W.force_prints[#W.force_prints + 1] = M.ls_to_string(s) end
  f.chart = function(surface, area) assert(surface and area, "chart : arguments") end
  f.set_cease_fire = function(other, v)
    local n = type(other) == "string" and other or other.name
    assert(type(v) == "boolean", "set_cease_fire : booléen attendu")
    f._cease[n] = v
  end
  f.get_cease_fire = function(other)
    local n = type(other) == "string" and other or other.name
    return f._cease[n] or false
  end
  f._friends = {}
  f.set_friend = function(other, v) f._friends[type(other) == "string" and other or other.name] = v end
  f._tags = {}
  f.add_chart_tag = function(surface, tag)
    assert(surface and tag and tag.position, "add_chart_tag : arguments")
    local t = { _lua_object = true, valid = true, position = tag.position, text = tag.text }
    t.destroy = function() t.valid = false end
    f._tags[#f._tags + 1] = t
    return t
  end
  f.set_ammo_damage_modifier = function(ammo, m) assert(type(ammo) == "string" and type(m) == "number") f._ammo_mod[ammo] = m end
  f.set_turret_attack_modifier = function(t, m) assert(type(t) == "string" and type(m) == "number") f._turret_mod[t] = m end
  -- Recettes : toutes débloquées dans le mock ; technologies : marquables comme recherchées.
  f.recipes = setmetatable({}, { __index = function(t2, name)
    if not W.recipes[name] then return nil end
    local r = { name = name, enabled = true }
    rawset(t2, name, r)
    return r
  end })
  f.technologies = setmetatable({}, { __index = function(t2, name)
    local tech = { name = name, researched = false, enabled = true }
    rawset(t2, name, tech)
    return tech
  end })
  -- Lot IA3-c (laboratoire du QG, F269, F270) : recherche d'une force sans joueur ; écrire research_progress = 1
  -- termine la recherche (technologie recherchée, événement on_research_finished, by_script = false).
  f.laboratory_speed_modifier = 0
  f.current_research = nil
  f.add_research = function(name)
    local tech = f.technologies[type(name) == "string" and name or name.name]
    if tech.researched then return false end
    f.current_research = tech
    rawset(f, "_progress", 0)
    return true
  end
  setmetatable(f, { __newindex = function(t2, k, v)
    if k == "research_progress" then
      rawset(t2, "_progress", v)
      local cur = rawget(t2, "current_research")
      if cur and v >= 1 then
        cur.researched = true
        rawset(t2, "current_research", nil)
        rawset(t2, "_progress", 0)
        local h = W.events[defines.events.on_research_finished]
        if h then h({ research = { name = cur.name, force = t2 }, by_script = false, tick = _G.game.tick }) end
      end
      return
    end
    rawset(t2, k, v)
  end, __index = function(t2, k)
    if k == "research_progress" then return rawget(t2, "_progress") or 0 end
  end })
  return f
end

local function force_of(x)
  if type(x) == "string" then
    local f = W.forces[x]
    assert(f, "force inconnue : " .. x)
    return f
  end
  return x
end

---------------------------------------------------------------------------------------------------
-- Entités
---------------------------------------------------------------------------------------------------
local function fire_died(e, killer_force)
  local h = W.events[defines.events.on_entity_died]
  if h then h({ entity = e, force = killer_force, cause = nil, tick = _G.game.tick }) end
end

local function destroy_entity(e)
  if not e.valid then return end
  e.valid = false
  if e._occ then W.occupied[e._occ] = nil end
  if e._registered then
    W.destroyed_queue[#W.destroyed_queue + 1] = { unit_number = e.unit_number, registration_number = e._registered }
  end
end

local WRITABLE = { active = "_active", operable = "_operable", health = "_health" }

---------------------------------------------------------------------------------------------------
-- Inventaires (capacité illimitée : le mock valide la logique, pas la place disponible)
---------------------------------------------------------------------------------------------------
local function new_inventory()
  local inv = { _items = {}, valid = true }
  inv.insert = function(items)
    assert(type(items) == "table" and items.name and items.count, "LuaInventory.insert : {name, count} attendu")
    local n = math.floor(items.count)
    if n <= 0 then return 0 end
    inv._items[items.name] = (inv._items[items.name] or 0) + n
    return n
  end
  inv.remove = function(items)
    assert(type(items) == "table" and items.name, "LuaInventory.remove : {name, count} attendu")
    local have = inv._items[items.name] or 0
    local n = math.min(have, math.floor(items.count or have))
    if n <= 0 then return 0 end
    inv._items[items.name] = have - n
    if inv._items[items.name] == 0 then inv._items[items.name] = nil end
    return n
  end
  inv.get_item_count = function(name)
    if name then return inv._items[name] or 0 end
    local n = 0
    for _, c in pairs(inv._items) do n = n + c end
    return n
  end
  inv.get_contents = function()
    local c = {}
    for k, v in pairs(inv._items) do c[k] = v end
    return c
  end
  inv.is_empty = function() return next(inv._items) == nil end
  inv.clear = function() inv._items = {} end
  -- Étape 1 : service_smelters lit la 1re pile (inv[1]) ; le mock rend la première (par nom) comme une pile lisible
  return setmetatable(inv, { __index = function(_, k)
    if k ~= 1 then return nil end
    local names = {}
    for n in pairs(inv._items) do names[#names + 1] = n end
    table.sort(names)
    if #names == 0 then return { valid_for_read = false, count = 0 } end
    return { valid_for_read = true, name = names[1], count = inv._items[names[1]] }
  end })
end
M.new_inventory = new_inventory

local function inv_of(t, which)
  t._invs[which] = t._invs[which] or new_inventory()
  return t._invs[which]
end

-- Inventaire « naturel » d'un objet inséré par LuaEntity.insert, selon le type d'entité.
local function default_inventory(t, item)
  local I = defines.inventory
  if t.type == "ammo-turret" then return inv_of(t, I.turret_ammo) end
  if t.type == "container" then return inv_of(t, I.chest) end
  if t.type == "character" then return inv_of(t, I.character_main) end
  if t.type == "furnace" or t.type == "mining-drill" then
    if item == "coal" then return inv_of(t, I.fuel) end
    return inv_of(t, I.furnace_source)
  end
  return inv_of(t, I.chest)
end

local function recipe(name)
  return W.recipes[name]
end

--- Boîte de collision d'un prototype, relative à la position : { x0, y0, x1, y1 }. Formats acceptés : celui du
--- runtime ({ left_top = {x, y}, right_bottom = {x, y} }) et celui de l'étape data ({ {x, y}, {x, y} }).
--- Prototype sans boîte : 1×1 (± 0,5), la boîte de toute entité simulée avant la suite d'intégration de V3-T
--- (les prototypes intégrés ont tous leur boîte vanilla ; seul un prototype déclaré par un banc sans boîte, ou un
--- nom inconnu, la reçoit encore). Monde créé avec legacy_boxes = true (ancien modèle, comparaison) : 1×1 partout.
local function collision_of(name)
  local cb = (not W.legacy_boxes) and W.prototype(name).collision_box
  if type(cb) == "table" then
    local lt, rb = cb.left_top or cb[1], cb.right_bottom or cb[2]
    if lt and rb then
      return { x0 = lt.x or lt[1], y0 = lt.y or lt[2], x1 = rb.x or rb[1], y1 = rb.y or rb[2] }
    end
  end
  return { x0 = -0.5, y0 = -0.5, x1 = 0.5, y1 = 0.5 }
end
M.collision_of = collision_of

--- La boîte de collision de l'entité e touche-t-elle la zone `area` ({ {x0, y0}, {x1, y1} } ou left_top /
--- right_bottom) ? Doc 1.1.91 de find_entities_filtered : « entities colliding with that area ». Le contact bord à
--- bord et par un coin COMPTE (intervalles fermés) : OBSERVÉ en moteur réel le 22/10 (suite « défense dense », RD_LOG
--- E53, scénario greffé tools/autotest/fo-autotest/scenarios/bord-a-bord.lua : mur, mitrailleuse et laser 7, 4 bords,
--- 2 coins et une zone nulle posée sur le bord, tous rendus par find_entities_filtered et count_entities_filtered ;
--- un écart de 1/256 n'est pas rendu). Avant cette date, le moteur simulé l'excluait (choix non observé, E47). Tenu
--- par tests/migration_test.lua. Monde à legacy_boxes = true : ancien modèle, la seule POSITION dans la zone (bords
--- compris).
local function touches_area(e, area)
  local lt, rb = area.left_top or area[1], area.right_bottom or area[2]
  local ax0, ay0, ax1, ay1 = lt.x or lt[1], lt.y or lt[2], rb.x or rb[1], rb.y or rb[2]
  if W.legacy_boxes then return e._x >= ax0 and e._x <= ax1 and e._y >= ay0 and e._y <= ay1 end
  local b = collision_of(e.name)
  return e._x + b.x0 <= ax1 and ax0 <= e._x + b.x1 and e._y + b.y0 <= ay1 and ay0 <= e._y + b.y1
end

-- Masques par défaut des types que les bancs posent (data/core/lualib/collision-mask-util.lua, default_masks) ;
-- un type absent de cette liste prend le masque des bâtiments.
local BUILDING_MASK = { "item-layer", "object-layer", "player-layer", "water-tile" }
local DEFAULT_MASKS = {
  character = { "player-layer", "train-layer", "consider-tile-transitions" },
  unit = { "player-layer", "train-layer", "not-colliding-with-itself" },
  ["item-entity"] = { "item-layer" },
  ["entity-ghost"] = { "ghost-layer" },
  ["tile-ghost"] = { "ghost-layer" },
  resource = { "resource-layer" },
  cliff = { "item-layer", "object-layer", "player-layer", "water-tile", "not-colliding-with-itself" },
}

--- Le masque de collision de l'entité e contient-il au moins une des couches demandées (`layers` : une couche ou
--- une liste, paramètre collision_mask de find_entities_filtered) ? Masque du prototype (dictionnaire ou liste),
--- sinon celui par défaut du type. Interprétation « au moins une couche » : celle de la doc 1.1.91 telle que nous
--- la lisons, pas observée en moteur réel. Monde à legacy_boxes = true : filtre ignoré (ancien modèle).
local function mask_hits(e, layers)
  if W.legacy_boxes then return true end
  local m = W.prototype(e.name).collision_mask or DEFAULT_MASKS[e.type] or BUILDING_MASK
  local set = {}
  for k, v in pairs(m) do
    if type(k) == "number" then set[v] = true elseif v then set[k] = true end
  end
  for _, l in ipairs(type(layers) == "table" and layers or { layers }) do
    if set[l] then return true end
  end
  return false
end
M.mask_hits = mask_hits

local CRAFTERS = { ["assembling-machine"] = true, furnace = true, ["rocket-silo"] = true }

-- Champs de LuaMiningDrillControlBehavior (1.1.91) : lire ou écrire un autre champ est une erreur (table stricte).
local DRILL_CB = { circuit_enable_disable = true, connect_to_logistic_network = true, circuit_read_resources = true,
  resource_read_mode = true, circuit_condition = true, logistic_condition = true }

--- Comportement de circuit (LuaControlBehavior) d'une entité. Le moteur n'en a pas tant qu'aucun fil ni réglage
--- ne l'a créé (get_control_behavior rend nil) ; get_or_create_control_behavior le crée. Foreuse : les champs de
--- LuaMiningDrillControlBehavior, aux valeurs par défaut (faux, mode 0, conditions « < 0 ») ; autres types :
--- table libre.
local function new_control_behavior(e)
  local cb = { valid = true, type = e.type }
  if e.type ~= "mining-drill" then return cb end
  local v = { circuit_enable_disable = false, connect_to_logistic_network = false, circuit_read_resources = false,
    resource_read_mode = 0, circuit_condition = { condition = { comparator = "<", constant = 0 } },
    logistic_condition = { condition = { comparator = "<", constant = 0 } } }
  return setmetatable(cb, {
    __index = function(_, k)
      if not DRILL_CB[k] then error("LuaMiningDrillControlBehavior : champ inconnu " .. tostring(k), 2) end
      return v[k]
    end,
    __newindex = function(_, k, x)
      if not DRILL_CB[k] then error("LuaMiningDrillControlBehavior : écriture d'un champ inconnu " .. tostring(k), 2) end
      if k == "circuit_condition" or k == "logistic_condition" then
        assert(type(x) == "table" and type(x.condition) == "table", k .. " : { condition = {...} } attendu")
      end
      v[k] = x
    end,
  })
end

local new_entity -- déclarée plus bas (revive, lot V3-T3, en a besoin dans EntityMT)

local EntityMT = {
  __index = function(t, k)
    if k == "position" then return { x = t._x, y = t._y } end
    if k == "unit_group" then return (t._group and t._group.valid) and t._group or nil end
    if k == "bounding_box" then
      -- Lot V3-T3 : un fantôme a la boîte de l'entité qu'il porte.
      local b = collision_of(rawget(t, "_ghost_name") or t.name)
      return { left_top = { x = t._x + b.x0, y = t._y + b.y0 }, right_bottom = { x = t._x + b.x1, y = t._y + b.y1 } }
    end
    if k == "get_control_behavior" then return function() return rawget(t, "_cb") end end
    if k == "get_or_create_control_behavior" then
      return function()
        if not rawget(t, "_cb") then rawset(t, "_cb", new_control_behavior(t)) end
        return rawget(t, "_cb")
      end
    end
    if k == "get_recipe" then
      return function()
        assert(CRAFTERS[t.type], "get_recipe : entité sans recette (" .. tostring(t.type) .. ")")
        local r = rawget(t, "_recipe")
        return r and { name = r, valid = true } or nil
      end
    end
    if k == "set_recipe" then
      return function(r)
        assert(t.type == "assembling-machine", "set_recipe : machine d'assemblage attendue (" .. tostring(t.type) .. ")")
        local name = type(r) == "table" and r.name or r
        assert(name == nil or type(name) == "string", "set_recipe : nom ou LuaRecipe attendu")
        rawset(t, "_recipe", name)
        return {}
      end
    end
    if k == "walking_state" then return { walking = t._walking, direction = t._dir } end
    if k == "destroy" then return function() destroy_entity(t) return true end end
    if k == "die" then
      return function(force, cause)
        if not t.valid then return false end
        fire_died(t, force and force_of(force) or nil)
        destroy_entity(t)
        return true
      end
    end
    if k == "teleport" then
      return function(pos)
        assert(type(pos) == "table" and pos.x and pos.y, "teleport : position attendue")
        t._x, t._y = pos.x, pos.y
        return true
      end
    end
    if k == "damage" then
      return function(amount, force, dtype)
        assert(type(amount) == "number" and force, "damage : arguments")
        t._health = t._health - amount
        if t._health <= 0 then t.die(force) end
        return amount
      end
    end
    if k == "color" then return t._color end
    if k == "health" then return t._health end
    if k == "get_health_ratio" then
      return function() return t._health / (W.prototype(t.name).max_health or 100) end
    end
    if k == "active" then return t._active end
    if k == "prototype" then return W.prototype(t.name) end
    if k == "insert" then
      return function(items)
        assert(type(items) == "table" and items.name and items.count, "insert : {name, count} attendu")
        return default_inventory(t, items.name).insert(items)
      end
    end
    if k == "get_inventory" then
      return function(which)
        assert(type(which) == "number", "get_inventory : index attendu")
        return inv_of(t, which)
      end
    end
    if k == "get_main_inventory" then return function() return inv_of(t, defines.inventory.character_main) end end
    if k == "get_fuel_inventory" then return function() return inv_of(t, defines.inventory.fuel) end end
    if k == "get_module_inventory" then return function() return nil end end -- lot MOD-1 : pas de modules au mock
    -- Étape 1 : service_smelters lit is_crafting ; un four du mock fond d'un coup (pas de fabrication en cours entre deux ticks)
    if k == "is_crafting" then return function() return false end end
    if k == "get_output_inventory" then
      return function()
        if t.type == "container" then return inv_of(t, defines.inventory.chest) end
        return inv_of(t, defines.inventory.furnace_result)
      end
    end
    if k == "get_item_count" then
      return function(name)
        local n = 0
        for _, inv in pairs(t._invs) do n = n + inv.get_item_count(name) end
        return n
      end
    end
    if k == "remove_item" then
      return function(items)
        assert(type(items) == "table" and items.name, "remove_item : {name, count} attendu")
        local want, got = items.count or math.huge, 0
        local idx = {}
        for i in pairs(t._invs) do idx[#idx + 1] = i end
        table.sort(idx)
        for _, i in ipairs(idx) do
          if got >= want then break end
          got = got + t._invs[i].remove({ name = items.name, count = want - got })
        end
        return got
      end
    end
    -- Lot V3-T3 (« libérer la place », script/levels/free.lua) : marques de démontage, points d'un bras, fils d'un
    -- poteau, fantômes (revive), minage dans un inventaire. Géométrie du bras vanilla relevée en moteur réel (essai
    -- E56) : orienté au nord, il PREND une tuile au nord et DÉPOSE 1,2 tuile au sud.
    if k == "to_be_deconstructed" then return function() return rawget(t, "_decon") == true end end
    if k == "order_deconstruction" then
      return function(force, player)
        assert(force, "order_deconstruction(force, player) : force attendue")
        if not t.valid then return false end
        rawset(t, "_decon", true)
        return true
      end
    end
    if k == "cancel_deconstruction" then
      return function(force, player)
        assert(force, "cancel_deconstruction(force, player) : force attendue")
        rawset(t, "_decon", false)
        -- Moteur réel (F103 provisoire, lot V3-T3) : un fantôme posé SUR l'entité est retiré avec la marque.
        for _, g in ipairs(W.entities) do
          if g.valid and rawget(g, "_ghost_name") and math.floor(g._x) == math.floor(t._x) and math.floor(g._y) == math.floor(t._y) then
            destroy_entity(g)
          end
        end
      end
    end
    if t.type == "inserter" and (k == "pickup_position" or k == "drop_position") then
      local v = DIRV[t.direction or 0]
      if k == "pickup_position" then return { x = t._x + v[1], y = t._y + v[2] } end
      return { x = t._x - 1.2 * v[1], y = t._y - 1.2 * v[2] }
    end
    if k == "neighbours" then
      if t.type == "electric-pole" then return { copper = rawget(t, "_copper") or {}, red = {}, green = {} } end
      return nil
    end
    -- Lot IA3-e : fil de cuivre entre deux poteaux (raccordement d'un module du plan directeur).
    if k == "connect_neighbour" and t.type == "electric-pole" then
      return function(other)
        if not (other and other.valid and other.type == "electric-pole") then return false end
        local a, b = rawget(t, "_copper") or {}, rawget(other, "_copper") or {}
        for _, x in ipairs(a) do if x == other then return false end end
        a[#a + 1] = other
        b[#b + 1] = t
        rawset(t, "_copper", a)
        rawset(other, "_copper", b)
        return true
      end
    end
    if k == "ghost_name" then return rawget(t, "_ghost_name") end
    if k == "ghost_prototype" and rawget(t, "_ghost_name") then return W.prototype(rawget(t, "_ghost_name")) end
    if k == "revive" then
      return function(opts)
        if not (t.valid and rawget(t, "_ghost_name")) then return nil end
        local e = new_entity(rawget(t, "_ghost_name"), t._x, t._y, t.surface, t.force)
        e.direction = t.direction
        destroy_entity(t)
        local h = opts and opts.raise_revive and W.events[defines.events.script_raised_revive]
        if h then h({ entity = e, tick = _G.game.tick }) end
        return {}, e
      end
    end
    if k == "mine" then
      return function(opts)
        if not t.valid then return false end
        if opts and opts.inventory then
          opts.inventory.insert({ name = t.name, count = 1 })
          local idx = {}
          for i in pairs(t._invs) do idx[#idx + 1] = i end
          table.sort(idx)
          for _, i in ipairs(idx) do
            local c = t._invs[i].get_contents()
            local names = {}
            for name in pairs(c) do names[#names + 1] = name end
            table.sort(names)
            for _, name in ipairs(names) do opts.inventory.insert({ name = name, count = c[name] }) end
          end
        end
        local h = opts and opts.raise_destroyed and W.events[defines.events.script_raised_destroy]
        if h then h({ entity = t, tick = _G.game.tick }) end
        destroy_entity(t)
        return true
      end
    end
    if k == "drop_position" then return { x = t._x, y = t._y - 1.3 } end
    if k == "crafting_queue_size" then return #t._craft end
    if k == "begin_crafting" then
      return function(a)
        assert(type(a) == "table" and a.recipe and a.count, "begin_crafting : {count, recipe} attendu")
        local r = recipe(a.recipe)
        assert(r, "begin_crafting : recette inconnue " .. tostring(a.recipe))
        local main = inv_of(t, defines.inventory.character_main)
        local done = 0
        for _ = 1, a.count do
          local ok = true
          for _, ing in ipairs(r.ingredients) do if main.get_item_count(ing.name) < ing.amount then ok = false end end
          if not ok then break end
          for _, ing in ipairs(r.ingredients) do main.remove({ name = ing.name, count = ing.amount }) end
          t._craft[#t._craft + 1] = { recipe = a.recipe, due = _G.game.tick + math.ceil(r.energy * 60) }
          done = done + 1
        end
        return done
      end
    end
    if k == "update_selected_entity" then return function(pos) assert(pos.x and pos.y, "update_selected_entity : position") end end
    if k == "mining_state" then return t._mining or { mining = false } end
    if k == "shooting_state" then return t._shooting or { state = 0 } end
    if k == "set_command" then
      return function(cmd)
        assert(type(cmd) == "table" and cmd.type, "set_command : commande invalide")
        t._command = cmd
      end
    end
    return nil
  end,
  __newindex = function(t, k, v)
    if k == "walking_state" then
      assert(type(v) == "table" and type(v.walking) == "boolean" and type(v.direction) == "number", "walking_state invalide")
      t._walking = v.walking
      t._dir = v.direction
      W.walk_writes = W.walk_writes + 1
      return
    end
    if k == "color" then rawset(t, "_color", v) return end
    if k == "mining_state" then
      assert(type(v) == "table" and type(v.mining) == "boolean", "mining_state invalide")
      rawset(t, "_mining", v)
      return
    end
    if k == "shooting_state" then
      assert(type(v) == "table" and v.state ~= nil, "shooting_state invalide")
      rawset(t, "_shooting", v)
      return
    end
    if k == "health" then
      rawset(t, "_health", math.max(0, math.min(v, W.prototype(t.name).max_health or v)))
      return
    end
    if WRITABLE[k] then rawset(t, WRITABLE[k], v) return end
    error("écriture inattendue sur une entité : " .. tostring(k), 2)
  end,
}

new_entity = function(name, x, y, surface, force)
  W.unit = W.unit + 1
  local proto = W.prototype(name)
  local e = {
    _lua_object = true, name = name, type = proto.type or "entity", valid = true, unit_number = W.unit,
    surface = surface, force = force_of(force), _x = x, _y = y, _walking = false, _dir = 0, _registered = false,
    _health = proto.max_health or 100, _active = true, _operable = true, _command = false, _occ = false,
    _invs = {}, _craft = {}, direction = 0, _burn = 0, _drill_acc = 0, _mine_acc = 0, _group = false,
  }
  setmetatable(e, EntityMT)
  W.entities[#W.entities + 1] = e
  return e
end
M.new_entity = function(...) return new_entity(...) end

local function straight_path(s, g)
  local dx, dy = g.x - s.x, g.y - s.y
  local d = math.sqrt(dx * dx + dy * dy)
  local n = math.max(1, math.ceil(d))
  local path = {}
  for i = 1, n do
    path[i] = { position = { x = s.x + dx * i / n, y = s.y + dy * i / n }, needs_destroy_to_reach = false }
  end
  return path
end

local function occ_key(pos) return math.floor(pos.x / 3) .. ":" .. math.floor(pos.y / 3) end

---------------------------------------------------------------------------------------------------
-- Groupes d'unités
---------------------------------------------------------------------------------------------------
local GroupMT = {
  __index = function(g, k)
    if k == "members" then
      local out = {}
      for _, u in ipairs(g._members) do if u.valid and u._group == g then out[#out + 1] = u end end
      return out
    end
    if k == "position" then
      local n, sx, sy = 0, 0, 0
      for _, u in ipairs(g._members) do
        if u.valid and u._group == g then n, sx, sy = n + 1, sx + u._x, sy + u._y end
      end
      if n == 0 then return { x = g._pos.x, y = g._pos.y } end
      return { x = sx / n, y = sy / n }
    end
    if k == "state" then
      return g._done and _G.defines.group_state.finished or _G.defines.group_state.moving
    end
    return nil
  end,
}

local function new_group(position, force)
  W.group_number = W.group_number + 1
  local g = { _lua_object = true, valid = true, group_number = W.group_number, _members = {}, _command = false,
    _force = force_of(force), _pos = { x = position.x, y = position.y } }
  g.add_member = function(u)
    assert(u and u.valid, "add_member : unité invalide")
    g._members[#g._members + 1] = u
    u._group = g
  end
  g.set_command = function(cmd)
    assert(type(cmd) == "table" and cmd.type, "set_command (groupe) : commande invalide")
    if cmd.type == defines.command.compound then
      assert(type(cmd.commands) == "table" and #cmd.commands > 0, "compound sans commandes")
      assert(cmd.structure_type ~= nil, "compound sans structure_type")
    end
    g._command = cmd
    g._since = _G.game.tick
    g._done = false
  end
  g.start_moving = function() end
  g.destroy = function() g.valid = false end
  setmetatable(g, GroupMT)
  W.groups[#W.groups + 1] = g
  return g
end

-- Combat abstrait : une attaque se termine après attack_delay ticks ; 30 % des membres meurent et, si
-- des entités d'une autre faction se trouvent près de la destination, l'une d'elles est détruite.
local function step_groups(tick)
  for _, g in ipairs(W.groups) do
    if g.valid and g._command and not g._done then
      local cmd = g._command
      -- Lot IA2-c : une commande composée qui finit par un déplacement (éclaireur, arrêt au rassemblement avancé,
      -- retour par l'itinéraire) n'attaque pas : seule la dernière commande décide (moteur réel : go_to_location).
      local is_attack = cmd.type == defines.command.attack_area
        or (cmd.type == defines.command.compound and cmd.commands[#cmd.commands].type ~= defines.command.go_to_location)
      local delay = is_attack and W.attack_delay or W.return_delay
      if tick - g._since >= delay then
        g._done = true
        if is_attack then
          local members = g.members
          local deaths = math.floor(#members * 0.3)
          local last = cmd.type == defines.command.compound and cmd.commands[#cmd.commands] or cmd
          local dest = last.destination
          -- Option (lot IA0) : près d'une tourelle du joueur hors cessez-le-feu, les morts sont attribuées à
          -- la force « player » (c'est la tourelle qui repousse l'attaque, comme en moteur réel).
          local killer = nil
          if W.turrets_kill and g._force.name:match("^fo%-") then
            local pf = _G.game.forces.player
            if not pf.get_cease_fire(g._force) then
              for _, e in ipairs(W.entities) do
                if e.valid and e.force == pf and e.name == "gun-turret" then
                  local dx, dy = e._x - dest.x, e._y - dest.y
                  if dx * dx + dy * dy < 40 * 40 then killer = pf break end
                end
              end
            end
          end
          for i = 1, deaths do members[i].die(killer) end
          local hit = false
          for _, e in ipairs(W.entities) do
            if e.valid and e.force ~= g._force and e.force.name:match("^fo%-") and e.name ~= "fo-faction-hq" then
              local dx, dy = e._x - dest.x, e._y - dest.y
              if dx * dx + dy * dy < 40 * 40 and (e.name == "burner-mining-drill" or e.name == "gun-turret") then
                e.die(g._force)
                hit = true
                break
              end
            end
          end
          -- Option (lot IA0) : une attaque de faction détruit aussi une installation du joueur proche.
          if not hit and W.groups_hit_player and g._force.name:match("^fo%-") and g._force.name ~= "fo-horde" then
            for _, e in ipairs(W.entities) do
              if e.valid and e.force.name == "player" and e.type ~= "character" then
                local dx, dy = e._x - dest.x, e._y - dest.y
                if dx * dx + dy * dy < 40 * 40 then
                  e.die(g._force)
                  break
                end
              end
            end
          end
        end
        local h = W.events[defines.events.on_ai_command_completed]
        if h then h({ unit_number = g.group_number, result = defines.behavior_result.success, was_distracted = false, tick = tick }) end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Monde
---------------------------------------------------------------------------------------------------
function M.new_world(opts)
  opts = opts or {}
  W = {
    h1 = opts.h1 ~= false,
    latency = opts.latency or 3,
    p_busy = opts.p_busy or 0.03,
    p_nopath = opts.p_nopath or 0.03,
    p_lost = opts.p_lost or 0.01,
    seed = opts.seed or 42,
    attack_delay = opts.attack_delay or 900,
    return_delay = opts.return_delay or 300,
    unit = 0, entities = {}, events = {}, nth = {}, commands = {},
    pending_paths = {}, path_id = 0, destroyed_queue = {},
    renders = {}, render_id = 0, lines_drawn = 0, prints = {}, logs = {}, files = {},
    walk_writes = 0, reg = 0, groups = {}, group_number = 0, occupied = {}, game_prints = {}, produced = {}, burned = 0,
    patches = opts.patches or {},
    tile_at = opts.tile_at or function() return "grass-1" end,
    settings = {
      ["fo-debug-render"] = true, ["fo-companion-steer-period"] = opts.steer or 4,
      ["fo-companion-brain-period"] = opts.brain or 60, ["fo-path-max-inflight"] = 6,
      ["fo-level-time-factor"] = 1,
      ["fo-pvp-difficulty"] = opts.difficulty or "normal", -- lot IA0 : défaut du jeu
      -- lot PNJ-JOUABLE : lancement de la guerre par les réglages de carte (défauts du jeu)
      ["fo-war-autostart"] = opts.war_autostart or false, ["fo-war-factions"] = 2,
      ["fo-war-soldiers"] = 30, ["fo-war-workers"] = 30, -- lot SCALE : défaut 4 -> 30 (P1 d'IA3-d)
      -- Lot IA3-c : cerveau par besoins (settings/ia3c.lua). Lot IA-V2 : ALLUMÉ par défaut comme le jeu (0.5.0) ;
      -- éteint par l'option (ia3_cerveau = false) ou par FO_IA3_CERVEAU=0 (bancs « bascule éteinte », pvp_test compris).
      ["fo-war-ia3-cerveau"] = (opts.ia3_cerveau ~= false) and (os.getenv("FO_IA3_CERVEAU") ~= "0"),
      -- Lot IA3-e : ÉTEINT par défaut comme le jeu (settings/ia3e.lua) ; allumé par l'option (ia3e = true) ou FO_IA3E=1
      ["fo-war-ia3e"] = (opts.ia3e == true) or (os.getenv("FO_IA3E") == "1"),
      -- Lot CAPITAL : ÉTEINT par défaut comme le jeu (settings/capital.lua) ; allumé par l'option (capital = true) ou FO_CAPITAL=1
      ["fo-war-capital"] = (opts.capital == true) or (os.getenv("FO_CAPITAL") == "1"),
      -- Lot CAPIB : ÉTEINT par défaut comme le jeu (settings/capi.lua) ; allumé par l'option (capi = true) ou FO_CAPI=1
      -- (n'agit qu'avec fo-war-ia3e : FO_IA3E=1)
      ["fo-war-capi"] = (opts.capi == true) or (os.getenv("FO_CAPI") == "1"),
      -- lot IA3-k : comportements visibles (défaut du jeu : allumé)
      ["fo-war-ia3-comportement"] = opts.ia3k ~= false,
    },
    groups_hit_player = opts.groups_hit_player or false, -- lot IA0 : les attaques de faction touchent le joueur
    turrets_kill = opts.turrets_kill or false, -- lot IA0 : les tourelles du joueur tuent les attaquants
    -- Suite d'intégration de V3-T : true = ANCIEN modèle des boîtes (toute entité 1×1, recherche par zone sur la
    -- seule position, filtre collision_mask ignoré). Aucun banc ne l'utilise : option de COMPARAISON seulement
    -- (rejouer un banc dans l'ancien modèle pour voir ce que les boîtes changent). Correction de la suite : l'écart
    -- pvp « Normal 18,2 > Difficile 18,0 » relevé par le constructeur venait d'un modèle HYBRIDE : boîtes 1×1 par
    -- défaut pour les prototypes intégrés (QG, mitrailleuse, personnage...). Avec les boîtes vanilla ci-dessous,
    -- tests/pvp_test.lua passe sans cette option (596 OK) ; le filtre collision_mask n'y change rien (rejoué sans
    -- lui : journal identique).
    legacy_boxes = opts.legacy_boxes or false,
  }
  math.randomseed(W.seed)

  -- Prototypes intégrés : boîtes de collision et masques RÉELS (correction de la suite d'intégration de V3-T ;
  -- avant, seuls fo-companion et les unités fo-* avaient une boîte, tous les autres recevaient le 1×1 par défaut).
  -- Boîtes relevées par `lua5.2 tests/datastage/harness.lua "<racine>/data" . --dump-final <type>/<nom>` (prototypes
  -- FINAUX, mod compris) ; masques absents de ces prototypes, donc ceux par défaut de leur type
  -- (data/core/lualib/collision-mask-util.lua, default_masks). Format runtime (LuaEntityPrototype).
  local function box(x0, y0, x1, y1)
    return { left_top = { x = x0, y = y0 }, right_bottom = { x = x1, y = y1 } }
  end
  local MASK_BUILDING = { ["item-layer"] = true, ["object-layer"] = true, ["player-layer"] = true, ["water-tile"] = true }
  local MASK_CHARACTER = { ["player-layer"] = true, ["train-layer"] = true, ["consider-tile-transitions"] = true }
  local MASK_UNIT = { ["player-layer"] = true, ["train-layer"] = true, ["not-colliding-with-itself"] = true }
  W.prototypes = {
    ["fo-companion"] = {
      type = "character", running_speed = 0.15, max_health = 250,
      collision_box = box(-0.2, -0.2, 0.2, 0.2), collision_mask = MASK_CHARACTER,
    },
    -- Lot IA-G : catégories de fabrication et de minage du personnage (relevé du cerveau général).
    character = { type = "character", max_health = 250, collision_box = box(-0.2, -0.2, 0.2, 0.2),
      collision_mask = MASK_CHARACTER, crafting_categories = { crafting = true }, resource_categories = { ["basic-solid"] = true } },
    -- Copie de crash-site-spaceship (prototypes/faction.lua) : boîte décentrée de l'épave vanilla.
    ["fo-faction-hq"] = { type = "container", max_health = 25000, collision_box = box(-8.7, -3.3, 6.9, 4.5),
      collision_mask = MASK_BUILDING },
    ["gun-turret"] = { type = "ammo-turret", max_health = 400, collision_box = box(-0.7, -0.7, 0.7, 0.7),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "gun-turret", count = 1 } } },
    ["electric-mining-drill"] = { type = "mining-drill", max_health = 300,
      resource_categories = { ["basic-solid"] = true, ["fo-hard-solid"] = true },
      collision_box = box(-1.4, -1.4, 1.4, 1.4), collision_mask = MASK_BUILDING, items_to_place_this = { { name = "electric-mining-drill", count = 1 } } },
    -- Lot IA-G : objet qui pose, source d'énergie, catégories (relevé du cerveau général, comme le moteur).
    ["burner-mining-drill"] = { type = "mining-drill", max_health = 150, collision_box = box(-0.7, -0.7, 0.7, 0.7),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "burner-mining-drill", count = 1 } },
      resource_categories = { ["basic-solid"] = true }, burner_prototype = { effectivity = 1 }, mining_speed = 0.25 },
    ["stone-furnace"] = { type = "furnace", max_health = 200, collision_box = box(-0.7, -0.7, 0.7, 0.7),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "stone-furnace", count = 1 } },
      crafting_categories = { smelting = true }, burner_prototype = { effectivity = 1 }, crafting_speed = 1 },
    ["iron-chest"] = { type = "container", max_health = 200, collision_box = box(-0.35, -0.35, 0.35, 0.35),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "iron-chest", count = 1 } } },
    ["fo-team-chest"] = { type = "container", max_health = 800, collision_box = box(-0.35, -0.35, 0.35, 0.35),
      collision_mask = MASK_BUILDING },
    ["wooden-chest"] = { type = "container", max_health = 100, collision_box = box(-0.35, -0.35, 0.35, 0.35),
      collision_mask = MASK_BUILDING },
    -- Ennemis vanilla posés par tests/td_test.lua (boîtes finales : le mod ne les agrandit pas). Points de vie : ceux
    -- de l'ancien prototype générique (200), gardés tels quels pour ne changer que les boîtes.
    ["small-biter"] = { type = "unit", max_health = 200, collision_box = box(-0.2, -0.2, 0.2, 0.2),
      collision_mask = MASK_UNIT },
    ["small-spitter"] = { type = "unit", max_health = 200, collision_box = box(-0.3, -0.3, 0.3, 0.3),
      collision_mask = MASK_UNIT },
    -- Lot V3-T3 : fantôme d'entité (sa boîte est celle de l'entité portée ; masque par défaut : ghost-layer).
    ["entity-ghost"] = { type = "entity-ghost", max_health = 1 },
    -- Lot IA3-e : bâtiments des modules du plan directeur (shared/team/modules.lua), posés par les PNJ des factions
    -- (objet qui les pose : items_to_place_this ; boîtes vanilla).
    ["transport-belt"] = { type = "transport-belt", max_health = 150, collision_box = box(-0.4, -0.4, 0.4, 0.4),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "transport-belt", count = 1 } } },
    inserter = { type = "inserter", max_health = 150, collision_box = box(-0.15, -0.15, 0.15, 0.15),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "inserter", count = 1 } } },
    ["burner-inserter"] = { type = "inserter", max_health = 100, collision_box = box(-0.15, -0.15, 0.15, 0.15),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "burner-inserter", count = 1 } } },
    ["fast-inserter"] = { type = "inserter", max_health = 150, collision_box = box(-0.15, -0.15, 0.15, 0.15),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "fast-inserter", count = 1 } } },
    ["medium-electric-pole"] = { type = "electric-pole", max_health = 100, collision_box = box(-0.15, -0.15, 0.15, 0.15),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "medium-electric-pole", count = 1 } }, max_wire_distance = 9 },
    ["big-electric-pole"] = { type = "electric-pole", max_health = 150, collision_box = box(-0.65, -0.65, 0.65, 0.65),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "big-electric-pole", count = 1 } }, max_wire_distance = 30 },
    ["assembling-machine-1"] = { type = "assembling-machine", max_health = 300, collision_box = box(-1.2, -1.2, 1.2, 1.2),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "assembling-machine-1", count = 1 } } },
    boiler = { type = "boiler", max_health = 200, collision_box = box(-1.29, -0.79, 1.29, 0.79),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "boiler", count = 1 } } },
    ["steam-engine"] = { type = "generator", max_health = 400, collision_box = box(-1.35, -2.35, 1.35, 2.35),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "steam-engine", count = 1 } } },
    ["offshore-pump"] = { type = "offshore-pump", max_health = 150, collision_box = box(-0.6, -0.05, 0.6, 0.3),
      collision_mask = MASK_BUILDING, items_to_place_this = { { name = "offshore-pump", count = 1 } } },
    -- Lot IA3-c : laboratoire vanilla (laboratoire du QG des factions).
    lab = { type = "lab", max_health = 150, collision_box = box(-1.2, -1.2, 1.2, 1.2), collision_mask = MASK_BUILDING,
      items_to_place_this = { { name = "lab", count = 1 } }, researching_speed = 1,
      lab_inputs = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack",
        "production-science-pack", "utility-science-pack", "space-science-pack" } },
  }
  W.recipes = dofile("tests/fixtures/recipes.lua")
  -- Soldats et unités du mod : prototype d'unité générique, boîte des soldats (prototypes/faction.lua, ± 0,2) et
  -- masque par défaut des unités (aucun soldat n'en déclare).
  setmetatable(W.prototypes, { __index = function(_, name)
    if type(name) == "string" and name:match("^fo%-") then
      return {
        type = "unit", max_health = 200,
        collision_box = box(-0.2, -0.2, 0.2, 0.2),
        collision_mask = MASK_UNIT,
      }
    end
  end })
  -- Nom inconnu : unité générique SANS boîte (collision_of rend alors le 1×1 historique). Aucun banc n'en pose
  -- aujourd'hui hors des noms ci-dessus et de ceux qu'il déclare lui-même (relevé de la correction de la suite).
  W.prototype = function(name)
    return W.prototypes[name] or { type = "unit", max_health = 200 }
  end

  local events = {
    on_tick = 1, on_runtime_mod_setting_changed = 2, on_script_path_request_finished = 3, on_entity_destroyed = 4,
    on_entity_died = 5, on_ai_command_completed = 6, on_gui_click = 7,
    on_built_entity = 8, on_robot_built_entity = 9, script_raised_built = 10,
    script_raised_revive = 11, script_raised_destroy = 12, on_player_mined_entity = 13, on_robot_mined_entity = 14,
    on_selected_entity_changed = 15, on_player_left_game = 16,
    on_chunk_charted = 17, -- lot M0 : étiquettes des sites garantis (script/world/guarantee.lua)
    -- lot PNJ-VÉRIF : le livre de recettes des équipes est oublié quand les recherches d'une force changent
    on_research_finished = 18, on_research_reversed = 19, on_technology_effects_reset = 20, on_force_reset = 21,
    -- lot MOD-1 : modules multiplicatifs (script/modules/mult.lua) ; le mock ne modélise PAS les modules
    -- (get_module_inventory rend nil : aucune machine suivie), le moteur réel est prouvé par « mod1-modules »
    on_gui_opened = 22, on_gui_closed = 23, on_player_fast_transferred = 24, on_entity_settings_pasted = 25,
    -- lot MOD-2 : recettes par lots (script/modules/lots.lua) : lots activés à la création d'une force ; le mock ne
    -- modélise PAS les lots (fixture vanilla : aucun « fo-lot ») ; le moteur réel est prouvé par « mod2-lots »
    on_force_created = 26,
    -- lot IA1-i : interface « Équipe et factions » (script/gui/team_window.lua) : raccourci et onglets ; le mock n'a
    -- qu'un conteneur d'interface minimal (gui.screen), tests/ia1i_test.lua y greffe le sien
    on_lua_shortcut = 27, on_gui_selected_tab_changed = 28, on_player_display_resolution_changed = 29,
    on_player_display_scale_changed = 30,
  }
  _G.defines = {
    -- Lot IA3-e : plan directeur des factions (fantômes : can_place_entity{build_check_type = ghost_revive}).
    build_check_type = { script = 0, manual = 1, manual_ghost = 2, script_ghost = 3, blueprint_ghost = 4, ghost_revive = 5 },
    direction = strict({ north = 0, northeast = 1, east = 2, southeast = 3, south = 4, southwest = 5, west = 6, northwest = 7 }, "defines.direction"),
    events = strict(events, "defines.events"),
    command = strict({ attack = 0, attack_area = 1, build_base = 2, compound = 3, flee = 4, go_to_location = 5, group = 6, stop = 7, wander = 8 }, "defines.command"),
    distraction = strict({ by_anything = 0, by_damage = 1, by_enemy = 2, none = 3 }, "defines.distraction"),
    group_state = strict({ gathering = 0, moving = 1, attacking_distraction = 2, attacking_target = 3, finished = 4, pathfinding = 5, wander_in_group = 6 }, "defines.group_state"),
    compound_command = strict({ logical_and = 0, logical_or = 1, return_last = 2 }, "defines.compound_command"),
    inventory = strict({ turret_ammo = 1, chest = 2, character_main = 3, character_guns = 4, character_ammo = 5,
      fuel = 6, furnace_source = 7, furnace_result = 8, character_armor = 9 }, "defines.inventory"),
    shooting = strict({ not_shooting = 0, shooting_enemies = 1, shooting_selected = 2 }, "defines.shooting"),
    behavior_result = strict({ in_progress = 0, fail = 1, success = 2, deleted = 3 }, "defines.behavior_result"),
  }

  W.forces = { player = new_force("player"), enemy = new_force("enemy"), neutral = new_force("neutral") }
  -- Lot V3-T3 : game.forces[index] (LuaCustomTable du moteur : par nom OU par index) ; métatable seulement, pairs ne
  -- voit que les noms.
  setmetatable(W.forces, { __index = function(t, k)
    if type(k) ~= "number" then return nil end
    for _, f in pairs(t) do if f.index == k then return f end end
    return nil
  end })

  -- Lot M0 : graine de la carte (garantie des monnaies, script/world/guarantee.lua) et tuiles posées par script
  -- (set_tiles : relevées dans W.tile_override, lues avant W.tile_at par get_tile et find_tiles_filtered).
  local surface = { _lua_object = true, index = 1, valid = true, name = "nauvis", map_gen_settings = { seed = W.seed } }
  W.tile_override = {}
  local function tile_name_at(x, y)
    return W.tile_override[x .. "," .. y] or W.tile_at(x, y)
  end
  surface.find_non_colliding_position = function(name, center, radius, precision)
    assert(type(name) == "string" and center and radius and precision, "find_non_colliding_position : arguments")
    return { x = center.x, y = center.y }
  end
  -- Lot M0 : les trois ressources du mod (sites garantis) suivent le même modèle de gisements ponctuels.
  local RESOURCES = { ["iron-ore"] = true, ["copper-ore"] = true, ["coal"] = true, ["stone"] = true,
    ["fo-tungsten-ore"] = true, ["fo-resonance-crystal"] = true, ["fo-methane"] = true,
    ["fo-ilmenite"] = true, ["fo-brine"] = true } -- lot X1-TITANE
  surface.create_entity = function(t)
    if t.position and t.position.x == nil and t.position[1] ~= nil then t.position = { x = t.position[1], y = t.position[2] } end -- lot IA3-e
    if t.position and t.position.x == nil then t.position = { x = t.position[1], y = t.position[2] } end
    if RESOURCES[t.name] then
      -- Ressource posée par script : regroupée en gisements ponctuels (modèle de W.patches).
      for _, p in ipairs(W.patches) do
        local dx, dy = p.x - t.position.x, p.y - t.position.y
        if (p.name or "iron-ore") == t.name and dx * dx + dy * dy < 100 then
          p.amount = (p.amount or 0) + (t.amount or 0)
          return { valid = true, name = t.name }
        end
      end
      W.patches[#W.patches + 1] = { x = t.position.x, y = t.position.y, name = t.name, amount = t.amount }
      return { valid = true, name = t.name }
    end
    if t.name == "flying-text" then
      W.flying = (W.flying or 0) + 1
      return { valid = true, name = t.name }
    end
    if t.name == "entity-ghost" then
      -- Lot V3-T3 : fantôme posé par script (create_entity ne vérifie pas la place, F70).
      assert(t.inner_name and t.position and t.force, "create_entity(entity-ghost) : inner_name, position et force attendus")
      local g = new_entity("entity-ghost", t.position.x, t.position.y, surface, t.force)
      rawset(g, "_ghost_name", t.inner_name)
      if t.direction then g.direction = t.direction end
      return g
    end
    assert(t.name and t.position and t.force, "create_entity : arguments")
    local old
    if t.fast_replace then
      -- Remplacement rapide simulé : même position, contenus transférés, ancienne entité retirée.
      for _, o in ipairs(W.entities) do
        if o.valid and o._x == t.position.x and o._y == t.position.y and o.type ~= "character" then old = o end
      end
      if not old then return nil end
    end
    local e = new_entity(t.name, t.position.x, t.position.y, surface, t.force)
    if t.direction then e.direction = t.direction end
    if old then
      for idx, inv in pairs(old._invs) do e._invs[idx] = inv end
      old._invs = {}
      rawset(e, "_recipe", rawget(old, "_recipe"))  -- F39 : la recette est conservée
      destroy_entity(old)
      W.fast_replaced = (W.fast_replaced or 0) + 1
    end
    if t.raise_built and W.events[defines.events.script_raised_built] then
      W.events[defines.events.script_raised_built]({ entity = e, tick = _G.game.tick })
    end
    if t.name == "electric-mining-drill" or t.name == "gun-turret" then
      e._occ = occ_key(t.position)
      W.occupied[e._occ] = true
    end
    return e
  end
  surface.can_place_entity = function(t)
    if t.position and t.position.x == nil and t.position[1] ~= nil then t.position = { x = t.position[1], y = t.position[2] } end -- lot IA3-e
    assert(t.name and t.position, "can_place_entity : arguments")
    return not W.occupied[occ_key(t.position)]
  end
  surface.request_path = function(t)
    assert(t.bounding_box and t.collision_mask and t.start and t.goal and t.force, "request_path : paramètres requis")
    W.path_id = W.path_id + 1
    local r = math.random()
    if r < W.p_lost then return W.path_id end -- jamais de réponse : doit finir en timeout
    local ev = { id = W.path_id, due = _G.game.tick + W.latency }
    r = math.random()
    if r < W.p_busy then ev.try_again_later = true
    elseif r < W.p_busy + W.p_nopath then ev.path = nil
    else ev.path = straight_path(t.start, t.goal) end
    W.pending_paths[#W.pending_paths + 1] = ev
    return W.path_id
  end
  surface.request_to_generate_chunks = function(pos, r) assert(pos and r, "request_to_generate_chunks : arguments") end
  surface.force_generate_chunk_requests = function() end
  surface.is_chunk_generated = function(cpos) assert(cpos and cpos.x and cpos.y, "is_chunk_generated : ChunkPosition") return true end
  surface.get_tile = function(x, y)
    assert(type(x) == "number" and type(y) == "number", "get_tile(x, y) : entiers attendus")
    local name = tile_name_at(x, y)
    return {
      name = name, valid = true,
      collides_with = function(layer)
        assert(type(layer) == "string", "LuaTile.collides_with(layer) : chaîne attendue")
        return layer == "water-tile" and (name == "water" or name == "deepwater")
      end,
    }
  end
  surface.create_unit_group = function(t)
    assert(t.position and t.force, "create_unit_group : arguments")
    return new_group(t.position, t.force)
  end
  local function is_resource_name(n)
    -- Lot IA3-f : liste de noms (regards de la carte de connaissance) : ressource si TOUS les noms en sont.
    if type(n) == "table" then
      if #n == 0 then return false end
      for _, x in ipairs(n) do if not is_resource_name(x) then return false end end
      return true
    end
    if type(n) ~= "string" then return false end
    for _, p in ipairs(W.patches) do if (p.name or "iron-ore") == n then return true end end
    return n == "iron-ore" or n == "copper-ore" or n == "coal" or n == "stone"
  end
  local function name_matches(want, name)
    if want == nil then return true end
    if type(want) == "table" then
      for _, x in ipairs(want) do if x == name then return true end end
      return false
    end
    return want == name
  end
  surface.find_entities_filtered = function(t)
    local out = {}
    -- Lot IA3-e : position en tableau { x, y } (acceptée par le moteur, utilisée par le plan directeur).
    if t.position and t.position.x == nil and t.position[1] ~= nil then
      local c = {}
      for k, v in pairs(t) do c[k] = v end
      c.position = { x = t.position[1], y = t.position[2] }
      t = c
    end
    if t.invert then
      -- Filtre inversé (seul usage du mod : « tout sauf les ressources » dans une zone).
      -- Lot M0 : « toute force sauf celles-ci » (bâtiments d'un joueur ou d'une IA sous un site garanti).
      local ex, exf = {}, {}
      for _, ty in ipairs(type(t.type) == "table" and t.type or { t.type }) do ex[ty] = true end
      for _, f in ipairs(type(t.force) == "table" and t.force or { t.force }) do exf[type(f) == "string" and f or f.name] = true end
      for _, e in ipairs(W.entities) do
        if e.valid and not ex[e.type] and not (t.force and exf[e.force.name]) then
          local ok = true
          if t.area then ok = touches_area(e, t.area) end
          if ok and t.position and t.radius then
            local dx, dy = e._x - t.position.x, e._y - t.position.y
            ok = dx * dx + dy * dy <= t.radius * t.radius
          end
          if ok then
            out[#out + 1] = e
            if t.limit and #out >= t.limit then break end
          end
        end
      end
      return out
    end
    if t.type == "resource" or is_resource_name(t.name) then
      local cx, cy, rad
      if t.area then
        cx, cy = (t.area[1][1] + t.area[2][1]) / 2, (t.area[1][2] + t.area[2][2]) / 2
        rad = (t.area[2][1] - t.area[1][1]) / 2
      else
        assert(t.position and t.radius, "find_entities_filtered(resource) : position + radius ou area attendus")
        cx, cy, rad = t.position.x, t.position.y, t.radius
      end
      for _, p in ipairs(W.patches) do
        local dx, dy = p.x - cx, p.y - cy
        if dx * dx + dy * dy <= (rad + 4) ^ 2 and name_matches(t.name, p.name or "iron-ore") then
          for ix = -2, 2 do
            for iy = -2, 2 do
              -- amount (lot M0) : la quantité du gisement répartie sur ses 25 entités simulées.
              out[#out + 1] = { valid = true, name = p.name or "iron-ore", type = "resource",
                amount = math.floor((p.amount or 25000) / 25),
                position = { x = p.x + ix * 2, y = p.y + iy * 2 },
                prototype = { resource_category = p.category or "basic-solid" }, destroy = function() end }
              if t.limit and #out >= t.limit then return out end
            end
          end
        end
      end
      return out
    end
    for _, e in ipairs(W.entities) do
      if e.valid then
        local ok = true
        if t.force then ok = ok and e.force.name == (type(t.force) == "string" and t.force or t.force.name) end
        if t.name then
          local names = type(t.name) == "table" and t.name or { t.name }
          local match = false
          for _, n in ipairs(names) do if e.name == n then match = true end end
          ok = ok and match
        end
        if t.position and t.radius then
          local dx, dy = e._x - t.position.x, e._y - t.position.y
          ok = ok and dx * dx + dy * dy <= t.radius * t.radius
        end
        -- Zone : boîte de collision du prototype (moteur), plus la seule position (suite d'intégration de V3-T).
        if t.area then ok = ok and touches_area(e, t.area) end
        -- Masque (start_blocker de path_service) : seules les entités qui ont une des couches demandées.
        if t.collision_mask then ok = ok and mask_hits(e, t.collision_mask) end
        -- Lot V3-T3 : nom porté par un fantôme.
        if t.ghost_name then ok = ok and rawget(e, "_ghost_name") == t.ghost_name end
        if t.type then
          local types = type(t.type) == "table" and t.type or { t.type }
          local match = false
          for _, ty in ipairs(types) do if e.type == ty then match = true end end
          ok = ok and match
        end
        if ok then out[#out + 1] = e end
      end
    end
    return out
  end
  surface.count_tiles_filtered = function(t)
    assert(t.area or (t.position and t.radius), "count_tiles_filtered : zone attendue")
    return 0
  end
  -- Lot M0 : tuiles d'une zone { {x0, y0}, {x1, y1} } (bornes du moteur : x0 <= x < x1), sans autre filtre.
  surface.find_tiles_filtered = function(t)
    assert(t.area and not t.name and not t.position, "find_tiles_filtered (moteur simulé) : zone seule attendue")
    local lt, rb = t.area[1], t.area[2]
    local out = {}
    -- Lot IA3-e : filtre `collision_mask = "water-tile"` (relevé de l'eau du plan directeur, script/team/build.lua) :
    -- sans lui, toutes les tuiles de la zone revenaient comme de l'eau et aucun module ne trouvait de place.
    local water_only = t.collision_mask == "water-tile"
    for y = math.floor(lt[2]), math.ceil(rb[2]) - 1 do
      for x = math.floor(lt[1]), math.ceil(rb[1]) - 1 do
        local name = tile_name_at(x, y)
        if not water_only or name:find("water", 1, true) then
          out[#out + 1] = { name = name, position = { x = x, y = y }, valid = true }
        end
      end
    end
    return out
  end
  surface.set_tiles = function(tiles, correct_tiles, remove_colliding_entities)
    assert(type(tiles) == "table", "set_tiles : liste attendue")
    for _, t in ipairs(tiles) do
      local p = t.position
      local x, y = p.x or p[1], p.y or p[2]
      assert(type(t.name) == "string" and x and y, "set_tiles : { name, position } attendu")
      W.tile_override[x .. "," .. y] = t.name
    end
    W.tiles_set = (W.tiles_set or 0) + #tiles
  end
  surface.regenerate_decorative = function(names, chunks)
    assert(type(names) == "table" and type(chunks) == "table", "regenerate_decorative : listes attendues")
    W.decor_regenerated = (W.decor_regenerated or 0) + #chunks
  end
  surface.count_entities_filtered = function(t)
    -- Compteur d'appels (lot V2c : coût du recensement Q16 en cache, tests/levels_test.lua).
    W.count_calls = (W.count_calls or 0) + 1
    return #surface.find_entities_filtered(t)
  end
  surface.spill_item_stack = function(pos, stack)
    assert(pos and stack and stack.name, "spill_item_stack : arguments")
    W.spilled = W.spilled or {}
    W.spilled[stack.name] = (W.spilled[stack.name] or 0) + (stack.count or 1)
  end
  surface.play_sound = function(t) assert(t.path, "play_sound : path attendu") end
  -- Décors (retirés sous un bâtiment agrandi, lot V3-T) : le moteur simulé n'en pose pas ; il vérifie la forme de
  -- l'appel (zone { {x0, y0}, {x1, y1} } ou position) et relève chaque zone dans W.decoratives_cleared.
  surface.destroy_decoratives = function(t)
    assert(type(t) == "table" and (t.area or t.position), "destroy_decoratives : zone attendue")
    if t.area then
      local lt, rb = t.area.left_top or t.area[1], t.area.right_bottom or t.area[2]
      assert(lt and rb and (lt.x or lt[1]) and (rb.x or rb[1]), "destroy_decoratives : zone { {x0, y0}, {x1, y1} } attendue")
    end
    W.decoratives_cleared = W.decoratives_cleared or {}
    W.decoratives_cleared[#W.decoratives_cleared + 1] = t.area or t.position
  end
  surface.find_entity = function(name, pos)
    local x, y = pos.x or pos[1], pos.y or pos[2]
    for _, o in ipairs(W.entities) do
      if o.valid and o.name == name and math.floor(o._x) == math.floor(x) and math.floor(o._y) == math.floor(y) then return o end
    end
    return nil
  end
  surface.find_nearest_enemy = function(t)
    assert(t.position and t.max_distance, "find_nearest_enemy : position et max_distance attendus")
    return nil
  end
  W.surface = surface

  local player_char = new_entity("character", 0, 0, surface, "player")
  local function gui_container()
    local c = { _children = {} }
    c.add = function(spec)
      assert(spec.type and spec.name or spec.type, "gui.add : type attendu")
      local el = gui_container()
      for k, v in pairs(spec) do el[k] = v end
      el.valid = true
      el.destroy = function() el.valid = false; if spec.name then c._children[spec.name] = nil end end
      if spec.name then c._children[spec.name] = el end
      return el
    end
    return setmetatable(c, { __index = function(t, k) return rawget(t, "_children")[k] end })
  end
  W.player = {
    _lua_object = true, index = 1, valid = true, admin = true, connected = true, surface = surface, force = W.forces.player,
    character = player_char,
    print = function(s) W.prints[#W.prints + 1] = M.ls_to_string(s) end,
    gui = { top = gui_container(), left = gui_container(), screen = gui_container() },
    insert = function(items) return player_char.insert(items) end,
    get_main_inventory = function() return player_char.get_main_inventory() end,
    create_local_flying_text = function(t) W.local_texts = W.local_texts or {}; W.local_texts[#W.local_texts + 1] = M.ls_to_string(t.text) end,
  }
  setmetatable(W.player, { __index = function(_, k) if k == "position" then return player_char.position end end })

  _G.global = {}
  _G.settings = { global = setmetatable({}, { __index = function(_, k)
    local v = W.settings[k]
    if v == nil then error("paramètre inconnu : " .. k, 2) end
    return { value = v }
  end }) }
  _G.script = {
    on_init = function(f) W.on_init = f end,
    on_load = function(f) W.on_load = f end,
    on_configuration_changed = function(f) W.on_config = f end,
    on_event = function(id, f) W.events[id] = f end,
    on_nth_tick = function(n, f) W.nth[n] = f end,
    register_on_entity_destroyed = function(e) W.reg = W.reg + 1; e._registered = W.reg; return W.reg end,
  }
  _G.commands = { add_command = function(name, help, fn) W.commands[name] = fn end }
  W.remote = {}
  _G.remote = {
    add_interface = function(name, fns)
      assert(type(name) == "string" and type(fns) == "table", "add_interface : arguments")
      W.remote[name] = fns
    end,
    call = function(name, fn, ...)
      local i = W.remote[name]
      assert(i and i[fn], "remote.call : interface/fonction inconnue " .. tostring(name) .. "." .. tostring(fn))
      local prev = W.dispatching
      W.dispatching = true
      local res = { pcall(i[fn], ...) }
      W.dispatching = prev
      if not res[1] then error(res[2], 0) end
      return table.unpack(res, 2)
    end,
  }
  _G.rendering = {
    draw_text = function(t)
      assert(t.text and t.surface and t.target and t.color, "draw_text : arguments")
      W.render_id = W.render_id + 1; W.renders[W.render_id] = { text = t.text, target = t.target }; return W.render_id
    end,
    draw_line = function(t)
      assert(t.from and t.to and t.surface and t.color and t.width, "draw_line : arguments")
      W.lines_drawn = W.lines_drawn + 1; return 0
    end,
    is_valid = function(id)
      local r = W.renders[id]
      if r and not r.target.valid then W.renders[id] = nil; return false end
      return r ~= nil
    end,
    set_text = function(id, text) W.renders[id].text = text end,
    draw_rectangle = function(t)
      assert(t.color and t.surface and t.left_top and t.right_bottom, "draw_rectangle : arguments")
      W.render_id = W.render_id + 1; W.renders[W.render_id] = { target = t.left_top, rect = true }; return W.render_id
    end,
    set_right_bottom = function(id, target, offset)
      assert(W.renders[id] and target and offset, "set_right_bottom : arguments")
      W.renders[id].rb = offset
    end,
    draw_light = function(t)
      assert(t.sprite and t.surface and t.target, "draw_light : arguments")
      W.lights = (W.lights or 0) + 1; return 0
    end,
    set_color = function(id, c) W.renders[id].color = c end,
    destroy = function(id) W.renders[id] = nil end,
  }
  _G.log = function(s) W.logs[#W.logs + 1] = M.ls_to_string(s) end
  local function profiler()
    local p = { _profiler = true, t = 0 }
    p.restart = function() end
    p.stop = function() end
    p.reset = function() end
    p.add = function(o) end
    p.divide = function(n) assert(n > 0) end
    return p
  end
  _G.game = {
    tick = 0,
    surfaces = { [1] = surface, nauvis = surface },
    -- Lot M0 : tuiles naturelles (autoplace) et eau, pour la garantie des monnaies (script/world/guarantee.lua).
    tile_prototypes = setmetatable({}, { __index = function(_, name)
      local natural = { ["grass-1"] = true, ["grass-2"] = true, ["dirt-1"] = true, ["sand-1"] = true, ["water"] = true,
        ["deepwater"] = true, ["fo-volcanic-ash"] = true, ["fo-crystal-flats"] = true, ["fo-toxic-marsh"] = true }
      local water = name == "water" or name == "deepwater"
      if not natural[name] and not (type(name) == "string" and (name:match("concrete") or name == "stone-path" or name == "landfill")) then return nil end
      return { name = name, autoplace_specification = natural[name] and {} or nil,
        collision_mask = water and { ["water-tile"] = true } or { ["ground-tile"] = true } }
    end }),
    forces = W.forces,
    connected_players = { W.player },
    entity_prototypes = W.prototypes,
    recipe_prototypes = W.recipes,
    -- Lot IA-G : objets ITÉRABLES (relevé du cerveau général : type, pouvoir calorifique), tirés des recettes du mock ;
    -- un nom absent garde la réponse d'avant (nom localisé seulement).
    item_prototypes = M.item_prototypes(W.recipes),
    -- Lot MOD-1 : aucun prototype de module au mock (la règle est testée à part, tests/module_mult_test.lua).
    get_filtered_item_prototypes = function(filters) return {} end,
    -- Lot IA3-c : technologies FINALES (vanilla + mod, tests/fixtures/tech_ai3_final.lua) et entités par type.
    technology_prototypes = M.technology_prototypes(),
    -- Lots IA3-c et IA3-f (fusion IA-V2) : entités par type ; pour les ressources (regards de la carte de connaissance),
    -- les 4 de base et celles des gisements en plus.
    get_filtered_entity_prototypes = function(filters)
      assert(type(filters) == "table" and filters[1] and filters[1].filter == "type", "get_filtered_entity_prototypes : filtre de type attendu")
      local out = {}
      local want = filters[1].type
      for name, p in pairs(W.prototypes) do if p.type == want then out[name] = p end end
      if want == "resource" then
        -- Lot IA-G : catégorie et produit du minage (relevé du cerveau général).
        local function res(n)
          return { name = n, type = "resource", resource_category = "basic-solid",
            mineable_properties = { minable = true, products = { { type = "item", name = n, amount = 1 } } } }
        end
        for _, n in ipairs({ "coal", "copper-ore", "iron-ore", "stone" }) do out[n] = out[n] or res(n) end
        for _, p in ipairs(W.patches) do local n = p.name or "iron-ore"; out[n] = out[n] or res(n) end
      end
      return out
    end,
    get_player = function(i) if i == 1 then return W.player end end,
    is_multiplayer = function() return false end,
    create_profiler = function() return profiler() end,
    create_inventory = function(size)
      assert(type(size) == "number", "create_inventory : taille attendue")
      local inv = new_inventory()
      inv.destroy = function() inv.valid = false end
      return inv
    end,
    create_force = function(name)
      assert(not W.forces[name], "create_force : force déjà existante " .. name)
      local n = 0
      for _ in pairs(W.forces) do n = n + 1 end
      assert(n < 64, "create_force : limite moteur de 64 forces")
      W.forces[name] = new_force(name)
      return W.forces[name]
    end,
    print = function(s) W.game_prints[#W.game_prints + 1] = M.ls_to_string(s) end,
    write_file = function(name, data, append, pi)
      W.files[name] = ((append and W.files[name]) or "") .. M.ls_to_string(data)
    end,
  }
end

-- Factorio interdit require() pendant un événement (seulement au chargement du script) : le mock le
-- vérifie aussi (moteur réel, session 4 : un require dans une fonction d'interface distante a arrêté
-- un banc de test à la première minute).
local real_require = require
_G.require = function(name)
  if W and W.dispatching then error("require('" .. tostring(name) .. "') pendant un événement : interdit par le moteur", 2) end
  return real_require(name)
end

local function dispatch(fn, ...)
  local prev = W.dispatching
  W.dispatching = true
  local ok, err = pcall(fn, ...)
  W.dispatching = prev
  if not ok then error(err, 0) end
end
M.dispatch = dispatch

function M.load_mod()
  for name in pairs(package.loaded) do
    if name:match(MOD_MODULE_PATTERN) or name:match("^shared%.") then package.loaded[name] = nil end
  end
  W.events, W.nth, W.commands, W.remote = {}, {}, {}, {}
  dofile("control.lua")
end

function M.new_game(opts)
  M.new_world(opts)
  M.load_mod()
  dispatch(W.on_init)
end

function M.command(name, text)
  dispatch(W.commands[name], { name = name, parameter = text, player_index = 1, tick = _G.game.tick })
end

function surface_find_resource(pos)
  local best, best_d
  for _, p in ipairs(W.patches) do
    local dx, dy = p.x - pos.x, p.y - pos.y
    local d = dx * dx + dy * dy
    if d <= 8 * 8 and (not best_d or d < best_d) then best, best_d = p.name or "iron-ore", d end
  end
  return best
end
local surface_find_resource = surface_find_resource

local DRILL_PERIOD = 240     -- foreuse à combustible : 0,25 minerai/s
local FUEL_PERIOD = 1600     -- un charbon toutes les ~27 s (foreuse ; four : 2 666 ticks)
local MINE_PERIOD = 120      -- minage à la main : 0,5 objet/s
local SMELT = { ["iron-ore"] = "iron-plate", ["copper-ore"] = "copper-plate", ["stone"] = "stone-brick", ["iron-plate"] = "steel-plate" }

local function entity_at(pos)
  for _, e in ipairs(W.entities) do
    if e.valid and (e.type == "furnace" or e.type == "container") and math.abs(e._x - pos.x) <= 1.2 and math.abs(e._y - pos.y) <= 1.2 then
      return e
    end
  end
end

local function burn(e, tick)
  local fuel = inv_of(e, defines.inventory.fuel)
  if fuel.get_item_count("coal") <= 0 then return false end
  e._burn = (e._burn or 0) + 1
  local period = e.type == "furnace" and FUEL_PERIOD * 5 / 3 or FUEL_PERIOD
  if e._burn * 60 >= period then
    e._burn = 0
    fuel.remove({ name = "coal", count = 1 })
    W.burned = (W.burned or 0) + 1
  end
  return true
end

local function step_economy(tick)
  if tick % 60 ~= 0 then return end
  for i = 1, #W.entities do
    local e = W.entities[i]
    if e.valid then
      if #e._craft > 0 and e._craft[1].due <= tick then
        local c = table.remove(e._craft, 1)
        for _, p in ipairs(recipe(c.recipe).products) do
          -- Comme le moteur : un personnage range ses armes et munitions fabriquées dans ses emplacements.
          local target = defines.inventory.character_main
          if p.name:find("magazine") and inv_of(e, defines.inventory.character_ammo).get_item_count() < 600 then
            target = defines.inventory.character_ammo
          elseif (p.name == "pistol" or p.name == "submachine-gun") and inv_of(e, defines.inventory.character_guns).get_item_count() < 3 then
            target = defines.inventory.character_guns
          end
          inv_of(e, target).insert({ name = p.name, count = p.amount })
        end
      end
      if e.type == "character" and e._mining and e._mining.mining then
        e._mine_acc = (e._mine_acc or 0) + 60
        if e._mine_acc >= MINE_PERIOD then
          e._mine_acc = 0
          local res = surface_find_resource(e._mining.position)
          if res then inv_of(e, defines.inventory.character_main).insert({ name = res, count = 1 }) end
        end
      end
      if e.name == "burner-mining-drill" then
        local res = surface_find_resource({ x = e._x, y = e._y })
        local sink = res and entity_at(e.drop_position)
        if sink and burn(e, tick) then
          e._drill_acc = (e._drill_acc or 0) + 60
          if e._drill_acc >= DRILL_PERIOD then
            e._drill_acc = 0
            if sink.type == "furnace" then inv_of(sink, defines.inventory.furnace_source).insert({ name = res, count = 1 })
            else inv_of(sink, defines.inventory.chest).insert({ name = res, count = 1 }) end
            W.produced[res] = (W.produced[res] or 0) + 1
          end
        end
      end
      if e.type == "furnace" then
        local src = inv_of(e, defines.inventory.furnace_source)
        for item, out in pairs(SMELT) do
          local need = item == "iron-plate" and 5 or (item == "stone" and 2 or 1)
          if src.get_item_count(item) >= need and burn(e, tick) then
            src.remove({ name = item, count = need })
            inv_of(e, defines.inventory.furnace_result).insert({ name = out, count = 1 })
            break
          end
        end
      end
    end
  end
end

local function step_physics()
  local speed = 0.15
  for i = 1, #W.entities do
    local e = W.entities[i]
    if e.valid and e._walking then
      local v = DIRV[e._dir]
      e._x = e._x + v[1] * speed
      e._y = e._y + v[2] * speed
      if not W.h1 then e._walking = false end -- H1 fausse : l'ordre de marche ne dure qu'un tick
    end
  end
end

local run_ticks_inner
function M.run_ticks(n)
  dispatch(run_ticks_inner, n)
end
run_ticks_inner = function(n)
  for _ = 1, n do
    local tick = _G.game.tick + 1
    _G.game.tick = tick
    local still = {}
    for i = 1, #W.pending_paths do
      local ev = W.pending_paths[i]
      if ev.due <= tick then
        W.events[defines.events.on_script_path_request_finished]({
          id = ev.id, tick = tick, path = ev.path, try_again_later = ev.try_again_later or false,
        })
      else
        still[#still + 1] = ev
      end
    end
    W.pending_paths = still
    W.events[defines.events.on_tick]({ tick = tick })
    local ns = {}
    for nn in pairs(W.nth) do ns[#ns + 1] = nn end
    table.sort(ns)
    for _, nn in ipairs(ns) do if tick % nn == 0 then W.nth[nn]({ tick = tick, nth_tick = nn }) end end
    step_physics()
    step_economy(tick)
    step_groups(tick)
    local q = W.destroyed_queue
    W.destroyed_queue = {}
    for i = 1, #q do
      W.events[defines.events.on_entity_destroyed]({ tick = tick, unit_number = q[i].unit_number, registration_number = q[i].registration_number })
    end
  end
end

-- Sérialisation déterministe de global (objets moteur -> "E<n>"), échoue sur fonction/userdata.
function M.serialize(v, seen)
  seen = seen or {}
  local t = type(v)
  if t == "number" then return string.format("%.17g", v) end
  if t == "string" then return string.format("%q", v) end
  if t == "boolean" or t == "nil" then return tostring(v) end
  if t == "table" then
    if rawget(v, "_lua_object") then
      return "E" .. tostring(rawget(v, "unit_number") or rawget(v, "group_number") or rawget(v, "name") or rawget(v, "index"))
    end
    if seen[v] then return "<ref>" end
    seen[v] = true
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      if type(a) == type(b) then return a < b end
      return type(a) < type(b)
    end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. M.serialize(v[k], seen) end
    seen[v] = nil
    return "{" .. table.concat(parts, ",") .. "}"
  end
  error("type non sérialisable dans global : " .. t)
end

--- Copie de global comme le ferait une sauvegarde puis un chargement : les objets moteur (_lua_object)
--- sont conservés tels quels, et les références PARTAGÉES restent partagées (memo), comme le moteur les
--- restaure (lot IA0 : sans memo, deux chemins vers une même table devenaient deux tables distinctes et
--- la partie rechargée divergeait de la partie continue, ce que le moteur réel ne fait pas).
function M.deepcopy_global(v, memo)
  if type(v) ~= "table" or rawget(v, "_lua_object") then return v end
  memo = memo or {}
  if memo[v] then return memo[v] end
  local c = {}
  memo[v] = c
  for k, x in pairs(v) do c[M.deepcopy_global(k, memo)] = M.deepcopy_global(x, memo) end
  return c
end

return M
