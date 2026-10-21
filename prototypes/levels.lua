--[[
  Niveaux de bâtiments (session 5) : centre de commandement + niveaux 2 à 10 de chaque famille.
  Données et règles : shared/levels/config.lua. Runtime (chantiers, plafond, ouvriers) : script/levels/.

  Design « Clash of Clans » sans nouvel asset (règle 8) : à chaque niveau, un MATÉRIAU différent (teinte
  choisie sur aperçus calculés à partir des fichiers du jeu), un SOCLE découpé dans une texture de sol
  vanilla (pavé, béton, béton raffiné, béton de sécurité, or), une LUEUR additive, un HALO de nuit et une
  taille qui croît ; le centre de commandement gagne en plus des pièces (antennes, radar agrandi).
]]

local lib = require("prototypes.lib")
local Evo = require("prototypes.evolution")
local L = require("shared.levels.config")

local out = {}

---------------------------------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------------------------------
local function is_sprite(t)
  return type(t) == "table" and (t.filename or t.filenames or t.stripes) ~= nil
end

local function get_path(t, path)
  for i = 1, #path - 1 do
    t = t[path[i]]
    if type(t) ~= "table" then return nil end
  end
  return t, path[#path]
end

local function scale_energy(s, f)
  local num, unit = tostring(s):match("^([%d%.]+)(%a+)$")
  if not num then return s end
  return string.format("%.4g", tonumber(num) * f) .. unit
end

--- Applique les statistiques de la famille au niveau n.
local function apply_stats(p, family, n)
  for _, st in ipairs(family.stats) do
    local parent, key = get_path(p, st.path)
    if parent then
      local v = parent[key]
      if v == nil then v = st.default end
      if type(v) == "number" then
        local nv = L.apply_stat(st, v, n)
        if key == "inventory_size" then nv = math.floor(nv + 0.5) end
        parent[key] = nv
      elseif type(v) == "string" then
        -- Puissance « 90kW » : même formule sur le nombre.
        local num = tonumber(v:match("^([%d%.]+)"))
        if num then parent[key] = scale_energy(v, L.apply_stat(st, num, n) / num) end
      end
    end
  end
  if family.resist_step then
    p.resistances = p.resistances or {}
    for dtype, step in pairs(family.resist_step) do
      local found
      for _, r in ipairs(p.resistances) do
        if r.type == dtype then found = r end
      end
      if not found then
        found = { type = dtype, decrease = 0, percent = 0 }
        table.insert(p.resistances, found)
      end
      found.decrease = (found.decrease or 0) + step * (n - 1)
    end
    table.sort(p.resistances, function(a, b) return a.type < b.type end)
  end
end

---------------------------------------------------------------------------------------------------
-- Socle : texture de sol vanilla découpée à l'emprise du bâtiment.
---------------------------------------------------------------------------------------------------
local FOUNDATION_TILE = {
  ["stone-path"] = "stone-path",
  ["concrete"] = "concrete",
  ["refined-concrete"] = "refined-concrete",
  ["refined-hazard-concrete"] = "refined-hazard-concrete-left",
}

local function foundation_sprite(spec, size)
  local tile = data.raw.tile[FOUNDATION_TILE[spec.tile]]
  local v = tile.variants
  local src
  if v.material_background then
    src = v.material_background
  else
    -- Pavé : variante 4×4 de la texture principale (bords intérieurs nets).
    for _, m in ipairs(v.main) do
      if m.size == 4 then src = m end
    end
  end
  local px = 32 * size
  local s = {
    filename = src.picture, width = px, height = px, x = 0, y = 0, priority = "low",
    tint = spec.tint,
  }
  if src.hr_version then
    s.hr_version = {
      filename = src.hr_version.picture, width = 2 * px, height = 2 * px, x = 0, y = 0, scale = 0.5,
      priority = "low", tint = spec.tint,
    }
  end
  return s
end

--- Insère le socle en PREMIÈRE couche (dessous) de chaque liste de couches de `anim`, en épousant le
--- nombre d'images et d'orientations des couches voisines.
local function add_foundation(anim, sprite, seen)
  seen = seen or {}
  if type(anim) ~= "table" or seen[anim] then return end
  seen[anim] = true
  if type(anim.layers) == "table" then
    local first = anim.layers[1]
    local f = table.deepcopy(sprite)
    local function fit(dst, ref)
      if not ref then return end
      local frames = (ref.frame_count or 1) * (ref.repeat_count or 1)
      if frames > 1 then dst.repeat_count = frames end
      if ref.direction_count and ref.direction_count > 1 then
        dst.direction_count = ref.direction_count
        dst.line_length = ref.direction_count
      elseif ref.direction_count then
        dst.direction_count = 1
      end
    end
    fit(f, first)
    if f.hr_version then fit(f.hr_version, first and (first.hr_version or first)) end
    table.insert(anim.layers, 1, f)
    return
  end
  if is_sprite(anim) then return end
  for k, v in pairs(anim) do
    if type(v) == "table" and k ~= "hr_version" then add_foundation(v, sprite, seen) end
  end
end

--- Convertit un sprite isolé en { layers = { sprite } } pour pouvoir y empiler socle, reflet et halo.
local function layered(t, key)
  local v = t[key]
  if is_sprite(v) then t[key] = { layers = { v } } end
end

---------------------------------------------------------------------------------------------------
-- Champs graphiques par type : « main » reçoit matériau, taille, reflet, halo ; « base » reçoit le socle.
---------------------------------------------------------------------------------------------------
local TURRET_HEAD = { "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation", "folding_animation" }

local function graphic_fields(p)
  local t = p.type
  if t == "ammo-turret" or t == "electric-turret" then
    local main = { p.base_picture }
    for _, f in ipairs(TURRET_HEAD) do if p[f] then main[#main + 1] = p[f] end end
    local scaled = { p.base_picture, p.energy_glow_animation }
    for _, f in ipairs(TURRET_HEAD) do if p[f] then scaled[#scaled + 1] = p[f] end end
    return main, { p.base_picture }, scaled
  elseif t == "wall" then
    return { p.pictures }, {}, {}
  elseif t == "mining-drill" then
    local main, base = {}, {}
    for _, gs in ipairs({ p.graphics_set, p.wet_mining_graphics_set }) do
      if gs and gs.animation then
        main[#main + 1] = gs.animation
        base[#base + 1] = gs.animation
      end
    end
    return main, base, { p.graphics_set, p.wet_mining_graphics_set }
  elseif t == "furnace" or t == "assembling-machine" then
    return { p.animation }, { p.animation }, { p.animation, p.working_visualisations }
  elseif t == "container" then
    return { p.picture }, { p.picture }, { p.picture }
  end
  error("type non géré : " .. t)
end

--- Habille le prototype `p` (déjà copié) aux couleurs du niveau n.
local function dress(p, family, n)
  if p.type == "furnace" or p.type == "assembling-machine" then layered(p, "animation") end
  if p.type == "container" then layered(p, "picture") end
  if p.type == "ammo-turret" or p.type == "electric-turret" then layered(p, "base_picture") end
  local main, base, scaled = graphic_fields(p)
  local mat = L.materials[n]
  -- 1. Taille (avant d'ajouter le socle, qui reste à l'emprise exacte).
  if not family.no_scale then
    for _, a in ipairs(scaled) do if a then lib.scale_sprites(a, L.sprite_scale(n)) end end
  end
  -- 2. Matériau.
  if mat.tint then
    for _, a in ipairs(main) do lib.tint_sprites(a, mat.tint) end
  end
  -- 3. Reflet (lueur additive) et halo de nuit.
  local g = L.glow[n]
  if g then
    for _, a in ipairs(main) do Evo.sheen_layers(a, g.color, g.alpha) end
  end
  local h = L.halo[n]
  if h then
    local color = (g and g.color) or mat.tint or { r = 1, g = 1, b = 1 }
    for _, a in ipairs(main) do Evo.light_layers(a, color, h) end
  end
  -- 4. Socle.
  local fspec = L.foundation[n]
  if fspec and not family.no_foundation then
    local sprite = foundation_sprite(fspec, family.size)
    for _, a in ipairs(base) do add_foundation(a, sprite) end
  end
end

local function level_icons(proto_or_item, n)
  local mat = L.materials[n]
  local icon, size, mip = proto_or_item.icon, proto_or_item.icon_size, proto_or_item.icon_mipmaps
  if not icon and proto_or_item.icons then
    icon, size, mip = proto_or_item.icons[1].icon, proto_or_item.icons[1].icon_size or proto_or_item.icon_size, proto_or_item.icons[1].icon_mipmaps
  end
  return lib.tier_icons(icon, size or 64, mat.tint, n, mip)
end

---------------------------------------------------------------------------------------------------
-- Centre de commandement, niveau 1 : corps de roboport complet (portes fermées), radar sur le toit.
---------------------------------------------------------------------------------------------------
local CC = L.by_key.command

local function still(sp, frame_x)
  local s = table.deepcopy(sp)
  local function fix(t)
    t.frame_count, t.repeat_count, t.animation_speed, t.line_length, t.direction_count = nil, nil, nil, nil, nil
    t.x, t.y = frame_x or 0, 0
    t.apply_projection = nil
    t.priority = t.priority or "medium"
    if t.hr_version then fix(t.hr_version) end
  end
  fix(s)
  return s
end

local function moved(sp, dx, dy, scale)
  local s = table.deepcopy(sp)
  local function mv(t)
    local sh = t.shift or { 0, 0 }
    local x, y = sh[1] or sh.x or 0, sh[2] or sh.y or 0
    t.shift = { x * (scale or 1) + dx, y * (scale or 1) + dy }
    if scale then t.scale = (t.scale or 1) * scale end
    if t.hr_version then mv(t.hr_version) end
  end
  mv(s)
  return s
end

--- Pièces du centre selon son niveau : antenne de balise au niveau 4, seconde antenne et radar agrandi au 7.
local function cc_picture(n)
  local rp = data.raw.roboport.roboport
  local radar = data.raw.radar.radar.pictures.layers[1]
  local beacon_top = data.raw.beacon.beacon.graphics_set.animation_list[2].animation
  local layers = {}
  for _, l in ipairs(rp.base.layers) do layers[#layers + 1] = table.deepcopy(l) end
  layers[#layers + 1] = still(rp.base_patch)
  layers[#layers + 1] = still(rp.door_animation_up)
  layers[#layers + 1] = still(rp.door_animation_down)
  local radar_scale = n >= 7 and 0.58 or 0.46
  layers[#layers + 1] = moved(still(radar), -1.05, -1.45 - (n >= 7 and 0.1 or 0), radar_scale)
  if n >= 4 then layers[#layers + 1] = moved(still(beacon_top), 1.15, -1.25, 0.75) end
  if n >= 7 then layers[#layers + 1] = moved(still(beacon_top), 1.45, 0.35, 0.65) end
  return { layers = layers }
end

local function command_center(n)
  local c = lib.copy("container", "steel-chest")
  local rp = data.raw.roboport.roboport
  c.name = L.name(CC, n)
  c.collision_box = table.deepcopy(rp.collision_box)
  c.selection_box = table.deepcopy(rp.selection_box)
  c.max_health = 3000
  c.inventory_size = 48
  c.corpse = rp.corpse
  c.dying_explosion = rp.dying_explosion
  c.damaged_trigger_effect = table.deepcopy(rp.damaged_trigger_effect)
  c.resistances = table.deepcopy(rp.resistances)
  c.open_sound = table.deepcopy(rp.open_sound)
  c.close_sound = table.deepcopy(rp.close_sound)
  c.vehicle_impact_sound = table.deepcopy(rp.vehicle_impact_sound)
  c.picture = cc_picture(n)
  c.circuit_wire_connection_point, c.circuit_connector_sprites, c.circuit_wire_max_distance = nil, nil, nil
  c.fast_replaceable_group = "fo-lvl-command"
  c.next_upgrade = nil
  c.icon, c.icon_size, c.icon_mipmaps = rp.icon, rp.icon_size, rp.icon_mipmaps
  return c
end

---------------------------------------------------------------------------------------------------
-- Génération
---------------------------------------------------------------------------------------------------
local BASE_GROUP = { gun = "fo-lvl-gun", laser = "fo-lvl-laser" }

-- Les tourelles vanilla n'ont pas de groupe de remplacement : sans groupe, le moteur refuse de
-- remplacer un niveau par le suivant.
for key, group in pairs(BASE_GROUP) do
  local f = L.by_key[key]
  data.raw[f.type][f.base].fast_replaceable_group = group
end

local function level_name(family, n)
  if family.key == "command" then return { "entity-name.fo-command-center" } end
  return { "entity-name." .. family.base }
end

for _, family in ipairs(L.families) do
  local base_item_name = family.base
  for n = 1, L.MAX do
    local name = L.name(family, n)
    local p
    if family.key == "command" then
      p = command_center(n)
      apply_stats(p, family, n)
      dress(p, family, n)
    elseif n >= 2 then
      p = lib.copy(family.type, family.base)
      p.name = name
      p.next_upgrade = nil
      p.fast_replaceable_group = BASE_GROUP[family.key] or p.fast_replaceable_group
      apply_stats(p, family, n)
      dress(p, family, n)
    end
    if p then
      -- Paramètres en CHAÎNES : le chargeur de prototypes n'accepte pas de nombre dans une chaîne localisée.
      p.localised_name = { "fo-levels.name", level_name(family, n), tostring(n) }
      p.localised_description = { "fo-levels.desc", tostring(n), { "fo-levels.material-" .. L.materials[n].key } }
      p.minable = { mining_time = (p.minable and p.minable.mining_time) or 0.5, result = name }
      p.placeable_by = nil
      local icons = level_icons(p, n)
      lib.set_icons(p, icons)
      if family.key == "command" then
        p.flags = { "placeable-player", "player-creation" }
      end
      out[#out + 1] = p

      local item
      if family.key == "command" then
        item = lib.copy("item", "roboport")
        item.subgroup = "storage"
        item.stack_size = 1
      else
        item = lib.copy("item", base_item_name)
      end
      item.name = name
      item.place_result = name
      item.localised_name = p.localised_name
      item.localised_description = p.localised_description
      item.order = (data.raw.item[base_item_name] and data.raw.item[base_item_name].order or "z") .. "-lvl" .. string.format("%02d", n)
      if family.key == "command" then item.order = "a[items]-z[fo-command-center]-" .. string.format("%02d", n) end
      lib.set_icons(item, level_icons(item, n))
      out[#out + 1] = item
    end
  end
end

-- Recette du centre de commandement niveau 1 (disponible dès le départ, comme l'hôtel de ville).
out[#out + 1] = lib.recipe("fo-command-center",
  { { "iron-chest", 4 }, { "iron-gear-wheel", 20 }, { "electronic-circuit", 10 }, { "stone-brick", 20 } },
  "fo-command-center", 1, 5, { enabled = true })

-- Raccourci d'amélioration (touche U).
out[#out + 1] = { type = "custom-input", name = "fo-level-up", key_sequence = "U", consuming = "none", order = "a" }

data:extend(out)
