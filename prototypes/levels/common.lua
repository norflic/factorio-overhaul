--[[
  Niveaux de bâtiments : génération des prototypes, partie COMMUNE (lot V2, session 6).
  Données et règles : shared/levels/config.lua. Runtime : script/levels/. Point d'entrée : prototypes/levels.lua.

  Ce fichier calcule TOUT ce qui n'est pas visuel : noms, statistiques, objets, minage, groupes de
  remplacement rapide (F39), traductions, recette du centre, touche U. Le visuel de chaque famille vit dans
  SON fichier, prototypes/levels/<famille>.lua (un agent du lot V3 par fichier) :
    command.lua (centre de commandement), gun.lua (mitrailleuse), laser.lua (tourelle laser), wall.lua (mur),
    drill.lua (foreuse électrique), furnace.lua (four en acier), assembler.lua (machine d'assemblage 2).

  =====================================================================================================
  INTERFACE D'UN FICHIER DE FAMILLE
  =====================================================================================================
  Le fichier renvoie une table :

    return {
      dress = function(p, ctx) ... end,          -- OBLIGATOIRE
      icons = function(icons, ctx) return icons end, -- FACULTATIF (icônes de l'entité ET de l'objet)
    }

  dress(p, ctx) est appelée une fois par niveau généré : centre, niveaux 1 à 15 ; autres familles,
  niveaux 2 à 30 (le niveau 1 est le bâtiment vanilla, jamais modifié).
    p   : le prototype d'entité, déjà COPIÉ et chiffré (nom, statistiques, minage, groupe…). Le centre
          arrive avec l'image du coffre en acier : dress doit poser `p.picture`.
    ctx : table en lecture seule :
      family    : la famille (config : key, type, base, size, max…)
      level     : n (1 à 30 ; centre : 1 à 15)
      epoch     : époque du niveau (1 à 15) ; centre : epoch = level
      step      : 1 = premier niveau de l'époque (la silhouette CHANGE), 2 = second (une pièce S'AJOUTE) ;
                  le centre n'a qu'un niveau par époque (step = 1)
      epoch_key : clé de l'époque ("pioneer", "forge", "steam"… : config L.epochs)
      color     : couleur de l'époque { r, g, b } (interface ; teinte du visuel provisoire)
      L         : la configuration (shared/levels/config.lua), à lire seulement
      kit       : boîte à outils visuelle (ci-dessous)
  icons(icons, ctx) reçoit les icônes par défaut (icône vanilla teintée + numéro du niveau) et renvoie la
  liste à poser sur l'entité et sur l'objet.

  Règles (vérifiées ici : une violation arrête l'étape data avec un message clair) :
    - dress ne modifie QUE des champs graphiques : animations, sprites, couches lumineuses, ombres.
      Les champs de jeu (nom, type, PV, emprise, collision, sélection, groupe de remplacement, minage,
      vitesses, énergie, portée, dégâts, résistances, inventaire, traductions…) sont comparés avant et après
      l'appel (GAME_FIELDS ci-dessous).
    - L'emprise au sol ne change jamais (critère D1-4) ; seule la hauteur visuelle peut croître.
    - Nouvelles images : graphics/levels/<famille>/ (lots V3). Chemins "__factorio-overhaul__/graphics/…".

  Boîte à outils `ctx.kit` (fonctions pures sur les tables de sprites) :
    kit.provisional(p, ctx, opts)  visuel PROVISOIRE de la session 5 (teinte d'époque, socle, reflet, halo,
                                   échelle plafonnée) ; opts.foundation = false, opts.scale = false
    kit.graphic_fields(p)          main, base, scaled : listes des animations principales, des animations
                                   qui reçoivent un socle, de celles qu'on agrandit
    kit.layered(t, key)            transforme t[key] (sprite isolé) en { layers = { sprite } }
    kit.tint(anim, color)          teinte (multiplie) toutes les couches non lumineuses
    kit.scale(anim, f)             agrandit toutes les couches (échelle et décalage)
    kit.sprite_scale(ctx)          échelle provisoire du niveau : 1 → 1,10 au dernier niveau (plafonnée)
    kit.sheen(anim, color, alpha)  reflet additif draw_as_glow (visible de jour)
    kit.halo(anim, color, k)       halo de nuit draw_as_light
    kit.foundation_sprite(tile, size, tint) / kit.add_foundation(anim, sprite)   socle en première couche
    kit.still(sprite, frame_x) / kit.moved(sprite, dx, dy, scale)              pièces fixes, déplacées
    kit.palette                    palette provisoire par époque (glow, foundation)
    kit.lib, kit.Evo               prototypes/lib.lua et prototypes/evolution.lua
]]

local lib = require("prototypes.lib")
local Evo = require("prototypes.evolution")
local L = require("shared.levels.config")

local VISUALS = {
  command = require("prototypes.levels.command"),
  gun = require("prototypes.levels.gun"),
  laser = require("prototypes.levels.laser"),
  wall = require("prototypes.levels.wall"),
  drill = require("prototypes.levels.drill"),
  furnace = require("prototypes.levels.furnace"),
  assembler = require("prototypes.levels.assembler"),
}

local Common = {}

---------------------------------------------------------------------------------------------------
-- Statistiques (non visuel)
---------------------------------------------------------------------------------------------------
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
    local types = {}
    for dtype in pairs(family.resist_step) do types[#types + 1] = dtype end
    table.sort(types)
    for _, dtype in ipairs(types) do
      local step = family.resist_step[dtype]
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
-- Garde de l'interface : champs de jeu qu'un fichier de famille n'a pas le droit de modifier.
---------------------------------------------------------------------------------------------------
local GAME_FIELDS = {
  "name", "type", "max_health", "collision_box", "selection_box", "fast_replaceable_group", "next_upgrade",
  "minable", "placeable_by", "flags", "localised_name", "localised_description", "resistances",
  "inventory_size", "mining_speed", "crafting_speed", "energy_usage", "rotation_speed",
  "resource_categories", "crafting_categories", "module_specification", "allowed_effects", "tile_width",
  "tile_height", "collision_mask", "vector_to_place_result", "input_fluid_box", "output_fluid_box",
  "fluid_boxes", "energy_source", "call_for_help_radius", "mining_area", "result_inventory_size",
  "source_inventory_size",
}
local ATTACK_FIELDS = { "range", "min_range", "damage_modifier", "cooldown", "type", "ammo_category" }

-- Sous-clés graphiques ignorées dans les champs de jeu (images de tuyaux, fumée, lumière du brûleur…).
local VISUAL_SUBKEYS = { "picture", "cover", "smoke", "light", "animation", "sprite", "sound", "glow", "shadow" }

local function is_visual_key(k)
  if type(k) ~= "string" then return false end
  for _, w in ipairs(VISUAL_SUBKEYS) do
    if k:find(w, 1, true) then return true end
  end
  return false
end

local function serialize(v, seen)
  local t = type(v)
  if t ~= "table" then return tostring(v) end
  seen = seen or {}
  if seen[v] then return "<cycle>" end
  seen[v] = true
  local keys = {}
  for k in pairs(v) do
    if not is_visual_key(k) then keys[#keys + 1] = k end
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. serialize(v[k], seen) end
  seen[v] = nil
  return "{" .. table.concat(parts, ",") .. "}"
end

local function game_snapshot(p)
  local snap = {}
  for _, k in ipairs(GAME_FIELDS) do snap[k] = serialize(p[k]) end
  local ap = p.attack_parameters or {}
  for _, k in ipairs(ATTACK_FIELDS) do snap["attack_parameters." .. k] = serialize(ap[k]) end
  return snap
end

local function check_snapshot(before, p, where)
  local after = game_snapshot(p)
  for k, v in pairs(before) do
    if after[k] ~= v then
      error("prototypes/levels/" .. where .. " : dress a modifié le champ de jeu « " .. k .. " » (interface : seuls les champs graphiques)")
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Boîte à outils visuelle (pour les fichiers de famille)
---------------------------------------------------------------------------------------------------
local function is_sprite(t)
  return type(t) == "table" and (t.filename or t.filenames or t.stripes) ~= nil
end

local kit = { lib = lib, Evo = Evo }

function kit.layered(t, key)
  local v = t[key]
  if is_sprite(v) then t[key] = { layers = { v } } end
end

function kit.tint(anim, color) if anim then lib.tint_sprites(anim, color) end end
function kit.scale(anim, f) if anim then lib.scale_sprites(anim, f) end end
function kit.sheen(anim, color, alpha) if anim then return Evo.sheen_layers(anim, color, alpha) end return 0 end
function kit.halo(anim, color, k) if anim then return Evo.light_layers(anim, color, k) end return 0 end

--- Échelle provisoire : +10 % au plus, atteinte au dernier niveau (emprise inchangée).
function kit.sprite_scale(ctx)
  local f = ctx.family
  if f.max <= 1 then return 1 end
  return 1 + 0.10 * (ctx.level - 1) / (f.max - 1)
end

local TURRET_HEAD = { "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation", "folding_animation" }

--- Champs graphiques par type : « main » reçoit teinte, reflet, halo ; « base » le socle ; « scaled » l'échelle.
function kit.graphic_fields(p)
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

local FOUNDATION_TILE = {
  ["stone-path"] = "stone-path",
  ["concrete"] = "concrete",
  ["refined-concrete"] = "refined-concrete",
  ["refined-hazard-concrete"] = "refined-hazard-concrete-left",
}

--- Socle : texture de sol vanilla découpée à l'emprise (size × size tuiles).
function kit.foundation_sprite(tile_name, size, tint)
  local tile = data.raw.tile[FOUNDATION_TILE[tile_name] or tile_name]
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
  local s = { filename = src.picture, width = px, height = px, x = 0, y = 0, priority = "low", tint = tint }
  if src.hr_version then
    s.hr_version = {
      filename = src.hr_version.picture, width = 2 * px, height = 2 * px, x = 0, y = 0, scale = 0.5,
      priority = "low", tint = tint,
    }
  end
  return s
end

--- Insère le socle en PREMIÈRE couche (dessous) de chaque liste de couches de `anim`, en épousant le
--- nombre d'images et d'orientations des couches voisines.
function kit.add_foundation(anim, sprite, seen)
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
  local keys = {}
  for k, v in pairs(anim) do
    if type(v) == "table" and k ~= "hr_version" then keys[#keys + 1] = k end
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do kit.add_foundation(anim[k], sprite, seen) end
end

--- Pièce fixe : première image d'un sprite animé (ou celle de la colonne frame_x).
function kit.still(sp, frame_x)
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

--- Pièce déplacée (en tuiles) et mise à l'échelle.
function kit.moved(sp, dx, dy, scale)
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

--- Palette PROVISOIRE par époque (reprise de la session 5, rejetée sur le design : E25). Lueur visible de
--- jour à partir de l'époque 5, halo de nuit à partir de l'époque 6, socle à partir du niveau 2.
kit.palette = {
  glow = {
    [5] = { r = 1.00, g = 0.32, b = 0.06 }, [6] = { r = 0.30, g = 0.80, b = 1.00 },
    [7] = { r = 0.65, g = 0.30, b = 1.00 }, [8] = { r = 0.50, g = 1.00, b = 0.30 },
    [9] = { r = 0.40, g = 1.00, b = 0.40 }, [10] = { r = 0.40, g = 0.90, b = 1.00 },
    [11] = { r = 0.90, g = 0.95, b = 1.00 }, [12] = { r = 0.20, g = 0.70, b = 1.00 },
    [13] = { r = 1.00, g = 0.40, b = 0.90 }, [14] = { r = 1.00, g = 0.85, b = 0.40 },
    [15] = { r = 1.00, g = 0.88, b = 0.55 },
  },
  foundation = {
    [1] = { tile = "stone-path" }, [2] = { tile = "stone-path" }, [3] = { tile = "concrete" },
    [4] = { tile = "concrete" }, [5] = { tile = "refined-concrete" }, [6] = { tile = "refined-concrete" },
    [7] = { tile = "refined-concrete" }, [8] = { tile = "refined-hazard-concrete" },
    [9] = { tile = "refined-hazard-concrete" }, [10] = { tile = "refined-hazard-concrete" },
    [11] = { tile = "refined-concrete" }, [12] = { tile = "refined-concrete" },
    [13] = { tile = "refined-concrete", tint = { r = 0.90, g = 0.80, b = 1.00 } },
    [14] = { tile = "refined-concrete", tint = { r = 1.00, g = 0.84, b = 0.42 } },
    [15] = { tile = "refined-concrete", tint = { r = 1.00, g = 0.92, b = 0.70 } },
  },
}

--- Visuel PROVISOIRE (aucun progrès visuel revendiqué : c'est le schéma rejeté en E25, ramené à 15 époques
--- et à une échelle plafonnée). Teinte de l'époque, reflet au 2e niveau d'une époque, lueur (époque 5+),
--- halo de nuit (époque 6+), socle (niveau 2+).
function kit.provisional(p, ctx, opts)
  opts = opts or {}
  if p.type == "furnace" or p.type == "assembling-machine" then kit.layered(p, "animation") end
  if p.type == "container" then kit.layered(p, "picture") end
  if p.type == "ammo-turret" or p.type == "electric-turret" then kit.layered(p, "base_picture") end
  local main, base, scaled = kit.graphic_fields(p)
  local e, step = ctx.epoch, ctx.step
  -- 1. Taille (avant le socle, qui reste à l'emprise exacte).
  if opts.scale ~= false then
    local f = kit.sprite_scale(ctx)
    for _, a in ipairs(scaled) do kit.scale(a, f) end
  end
  -- 2. Teinte de l'époque.
  if e >= 2 then
    for _, a in ipairs(main) do kit.tint(a, ctx.color) end
  end
  -- 3. Reflet (lueur additive) : époque 5+, et un léger reflet au 2e niveau de chaque époque.
  local glow = kit.palette.glow[e]
  local alpha = 0
  if glow then alpha = math.min(0.30, 0.05 + 0.017 * (e - 5)) end
  if step == 2 then alpha = alpha + 0.04 end
  if alpha > 0 then
    local c = glow or ctx.color
    for _, a in ipairs(main) do kit.sheen(a, c, alpha) end
  end
  -- 4. Halo de nuit : époque 6+.
  if e >= 6 then
    local k = math.min(0.65, 0.15 + 0.03 * (e - 6) + 0.05 * (step - 1))
    for _, a in ipairs(main) do kit.halo(a, glow or ctx.color, k) end
  end
  -- 5. Socle (niveau 2+).
  local fspec = kit.palette.foundation[e]
  if opts.foundation ~= false and fspec and ctx.level >= 2 then
    local sprite = kit.foundation_sprite(fspec.tile, ctx.family.size, fspec.tint)
    for _, a in ipairs(base) do kit.add_foundation(a, sprite) end
  end
end

---------------------------------------------------------------------------------------------------
-- Icônes par défaut : icône vanilla teintée de la couleur d'époque + numéro du niveau.
---------------------------------------------------------------------------------------------------
local function default_icons(proto_or_item, ctx)
  local icon, size, mip = proto_or_item.icon, proto_or_item.icon_size, proto_or_item.icon_mipmaps
  if not icon and proto_or_item.icons then
    local i1 = proto_or_item.icons[1]
    icon, size, mip = i1.icon, i1.icon_size or proto_or_item.icon_size, i1.icon_mipmaps
  end
  local tint = ctx.epoch >= 2 and ctx.color or nil
  return lib.tier_icons(icon, size or 64, tint, ctx.level, mip)
end

local function family_icons(visual, proto_or_item, ctx)
  local icons = default_icons(proto_or_item, ctx)
  if visual.icons then icons = visual.icons(icons, ctx) end
  return icons
end

---------------------------------------------------------------------------------------------------
-- Centre de commandement : squelette NON visuel (emprise et sons du roboport, coffre de 48 cases).
-- L'image vient de prototypes/levels/command.lua.
---------------------------------------------------------------------------------------------------
local CC = L.by_key.command

local function command_center_skeleton(n)
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
  c.circuit_wire_connection_point, c.circuit_connector_sprites, c.circuit_wire_max_distance = nil, nil, nil
  c.fast_replaceable_group = "fo-lvl-command"
  c.next_upgrade = nil
  c.icon, c.icon_size, c.icon_mipmaps = rp.icon, rp.icon_size, rp.icon_mipmaps
  return c
end

---------------------------------------------------------------------------------------------------
-- Génération
---------------------------------------------------------------------------------------------------
-- Les tourelles vanilla n'ont pas de groupe de remplacement : sans groupe, le moteur refuse de
-- remplacer un niveau par le suivant (F39).
local BASE_GROUP = { gun = "fo-lvl-gun", laser = "fo-lvl-laser" }

local function level_name(family)
  if family.key == "command" then return { "entity-name.fo-command-center" } end
  return { "entity-name." .. family.base }
end

--- Contexte passé aux fichiers de famille.
function Common.context(family, n)
  local e = L.epoch_of(family, n)
  local ep = L.epochs[e]
  return {
    family = family, level = n, epoch = e, step = L.step_of(family, n), epoch_key = ep.key,
    color = ep.color, L = L, kit = kit,
  }
end

function Common.generate()
  local out = {}
  for _, key in ipairs({ "gun", "laser" }) do
    local f = L.by_key[key]
    data.raw[f.type][f.base].fast_replaceable_group = BASE_GROUP[key]
  end

  for _, family in ipairs(L.families) do
    local visual = VISUALS[family.key]
    assert(visual and type(visual.dress) == "function", "prototypes/levels/" .. family.key .. ".lua : fonction dress manquante")
    for n = 1, family.max do
      local name = L.name(family, n)
      local p
      if family.key == "command" then
        p = command_center_skeleton(n)
        apply_stats(p, family, n)
      elseif n >= 2 then
        p = lib.copy(family.type, family.base)
        p.name = name
        p.next_upgrade = nil
        p.fast_replaceable_group = BASE_GROUP[family.key] or p.fast_replaceable_group
        apply_stats(p, family, n)
      end
      if p then
        local ctx = Common.context(family, n)
        local ep = L.epochs[ctx.epoch]
        -- Paramètres en CHAÎNES (F43) : le chargeur refuse un nombre dans une chaîne localisée de prototype.
        p.localised_name = { "fo-levels.name", level_name(family), tostring(n) }
        p.localised_description = { "fo-epochs.desc", tostring(n), tostring(ctx.epoch), { "fo-epochs.name-" .. ep.key } }
        p.minable = { mining_time = (p.minable and p.minable.mining_time) or 0.5, result = name }
        p.placeable_by = nil
        if family.key == "command" then p.flags = { "placeable-player", "player-creation" } end

        -- Visuel : fichier de la famille, sous garde.
        local before = game_snapshot(p)
        visual.dress(p, ctx)
        check_snapshot(before, p, family.key .. ".lua (niveau " .. n .. ")")
        lib.set_icons(p, family_icons(visual, p, ctx))
        out[#out + 1] = p

        local item
        local base_item_name = family.base
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
        if family.key == "command" then
          item.order = "a[items]-z[fo-command-center]-" .. string.format("%02d", n)
        else
          item.order = (data.raw.item[base_item_name] and data.raw.item[base_item_name].order or "z") .. "-lvl" .. string.format("%02d", n)
        end
        lib.set_icons(item, family_icons(visual, item, ctx))
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
end

Common.kit = kit
return Common
