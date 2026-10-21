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
    ctx : table en LECTURE SEULE (écrire un de ses champs arrête l'étape data) :
      family    : COPIE de la famille (config : key, type, base, size, max…) ; la modifier est refusé
      level     : n (1 à 30 ; centre : 1 à 15)
      epoch     : époque du niveau (1 à 15) ; centre : epoch = level
      step      : 1 = premier niveau de l'époque (la silhouette CHANGE), 2 = second (une pièce S'AJOUTE) ;
                  le centre n'a qu'un niveau par époque (step = 1)
      epoch_key : clé de l'époque ("pioneer", "forge", "steam"… : config L.epochs)
      color     : COPIE de la couleur de l'époque { r, g, b } (interface ; teinte du visuel provisoire)
      L         : la configuration (shared/levels/config.lua), à lire seulement (vérifié)
      kit       : boîte à outils visuelle (ci-dessous), à lire seulement (vérifié)
  icons(icons, ctx) reçoit les icônes par défaut (icône vanilla teintée + numéro du niveau) et renvoie la
  liste à poser sur l'entité et sur l'objet.

  Règles (vérifiées par Common.dress : une violation arrête l'étape data avec un message clair) :
    - dress ne modifie QUE des champs graphiques ou sonores. Garde INVERSÉE : tout le prototype est comparé
      avant et après l'appel, sauf la liste blanche GRAPHIC_KEYS et les clés qui contiennent un mot visuel
      (VISUAL_WORDS : picture, animation, sprite, sound, glow, shadow, light, smoke, icon…) ; dans les champs
      de jeu, seules les sous-clés visuelles (VISUAL_SUBKEYS : source_offset, gun_center_shift…) sont libres.
      Un champ de jeu oublié de toute liste est donc protégé par défaut.
    - Animations à durée de jeu (preparing, folding, attacking, starting_attack, ending_attack des
      tourelles) : on peut changer images et vitesse, pas la DURÉE (nombre d'images / vitesse).
    - dress ne modifie jamais data.raw : les prototypes sources de la famille (vanilla copié, objet ; centre :
      coffre en acier, roboport, radar, balise) sont comparés avant et après chaque appel.
    - dress ne modifie ni la config, ni ctx.kit, ni le style commun (prototypes/levels/style.lua).
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
    kit.palette                    palette provisoire par époque (glow, foundation) : STYLE COMMUN des
                                   7 familles, dans prototypes/levels/style.lua (un seul propriétaire)
    kit.lib, kit.Evo               prototypes/lib.lua et prototypes/evolution.lua
]]

local lib = require("prototypes.lib")
local Evo = require("prototypes.evolution")
local L = require("shared.levels.config")
local Style = require("prototypes.levels.style")

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
-- Garde de l'interface (INVERSÉE depuis la correction du lot V2) : TOUT le prototype est capturé avant
-- et après dress, SAUF une liste blanche de clés graphiques ou sonores. Une clé de jeu nouvelle ou oubliée
-- est donc protégée par défaut. En plus :
--   - les vitesses d'animation des tourelles (preparing_speed…) sont libres, mais la DURÉE de l'animation
--     (nombre d'images / vitesse) ne doit pas changer : c'est un délai de jeu (déploiement, repli) ;
--   - les prototypes SOURCES de la famille (data.raw) ne doivent pas bouger ;
--   - l'état partagé (config, boîte à outils, style commun) ne doit pas bouger ;
--   - ctx est en lecture seule (écrire un champ de ctx est une erreur ; family et color sont des copies).
---------------------------------------------------------------------------------------------------
local function set(list)
  local t = {}
  for _, k in ipairs(list) do t[k] = true end
  return t
end

-- Clés de premier niveau graphiques ou sonores, exactes.
local GRAPHIC_KEYS = set({
  "picture", "pictures", "animation", "animations", "idle_animation", "base_picture", "base_patch",
  "folded_animation", "preparing_animation", "prepared_animation", "prepared_alternative_animation",
  "attacking_animation", "folding_animation", "starting_attack_animation", "ending_attack_animation",
  "energy_glow_animation", "graphics_set", "wet_mining_graphics_set", "working_visualisations",
  "water_reflection", "integration_patch", "integration_patch_render_layer", "drawing_box",
  "radius_visualisation_picture", "circuit_connector_sprites", "circuit_wire_connection_point",
  "circuit_wire_connection_points", "visual_merge_group", "status_colors", "corpse", "dying_explosion",
  "glow_light_intensity", "energy_glow_animation_flicker_strength", "turret_base_has_direction",
  "base_render_layer", "gun_animation_render_layer", "gun_animation_secondary_draw_order",
  "base_picture_render_layer", "base_picture_secondary_draw_order", "always_draw_idle_animation",
  "match_animation_speed_to_activity", "default_recipe_tint", "shift_animation_waypoints",
  "shift_animation_waypoint_stop_duration", "shift_animation_transition_duration", "map_color",
  "friendly_map_color", "enemy_map_color", "scale_info_icons", "show_recipe_icon", "show_recipe_icon_on_map",
  "entity_info_icon_shift", "alert_icon_shift", "alert_icon_scale", "scale_entity_info_icon",
  "draw_entity_info_icon_background", "icon", "icons", "icon_size", "icon_mipmaps",
})
-- Mots qui marquent une clé graphique ou sonore, à tous les niveaux (« pipe_picture », « smoke »,
-- « wall_diode_red », « module_info_icon_shift »…).
local VISUAL_WORDS = { "picture", "cover", "smoke", "light", "animation", "sprite", "sound", "glow", "shadow",
  "visualis", "visualiz", "reflection", "diode", "icon" }
-- Sous-clés graphiques exactes dans les champs de jeu : origine du faisceau, de la douille, du canon.
local VISUAL_SUBKEYS = set({ "source_offset", "projectile_center", "projectile_creation_distance",
  "projectile_orientation_offset", "gun_center_shift", "gun_barrel_length", "shell_particle" })
-- Animation → sa vitesse : la durée images / vitesse est un délai de jeu (règle de durée).
local TIMED_ANIMATIONS = {
  { "preparing_animation", "preparing_speed" }, { "folding_animation", "folding_speed" },
  { "attacking_animation", "attacking_speed" }, { "starting_attack_animation", "starting_attack_speed" },
  { "ending_attack_animation", "ending_attack_speed" },
}
local SPEED_KEYS = {}
for _, t in ipairs(TIMED_ANIMATIONS) do SPEED_KEYS[t[2]] = true end

local function has_visual_word(k)
  if type(k) ~= "string" then return false end
  for _, w in ipairs(VISUAL_WORDS) do
    if k:find(w, 1, true) then return true end
  end
  return false
end

local function nested_visual(k)
  return VISUAL_SUBKEYS[k] or has_visual_word(k)
end

local function graphic_top(k)
  return type(k) == "string" and (GRAPHIC_KEYS[k] or SPEED_KEYS[k] or has_visual_word(k))
end

--- Sérialisation déterministe (clés triées). skip(k) : sous-clés ignorées (nil : aucune).
local function serialize(v, skip, seen)
  local t = type(v)
  if t ~= "table" then return t == "string" and string.format("%q", v) or tostring(v) end
  seen = seen or {}
  if seen[v] then return "<cycle>" end
  seen[v] = true
  local keys = {}
  for k in pairs(v) do
    if not (skip and skip(k)) then keys[#keys + 1] = k end
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. serialize(v[k], skip, seen) end
  seen[v] = nil
  return "{" .. table.concat(parts, ",") .. "}"
end

--- Nombre d'images d'une animation (couches : la plus longue ; 4 orientations : le nord).
local function frames(a)
  if type(a) ~= "table" then return nil end
  if type(a.layers) == "table" then
    local m
    for _, l in ipairs(a.layers) do
      local f = frames(l)
      if f and (not m or f > m) then m = f end
    end
    return m
  end
  if a.north then return frames(a.north) end
  if a.filename or a.filenames or a.stripes then return (a.frame_count or 1) * (a.repeat_count or 1) end
  return nil
end

local function game_snapshot(p)
  local snap = {}
  for k, v in pairs(p) do
    if not graphic_top(k) then snap[k] = serialize(v, nested_visual) end
  end
  for _, t in ipairs(TIMED_ANIMATIONS) do
    local f = frames(p[t[1]])
    if f then snap["durée de " .. t[1]] = string.format("%.6f", f / (p[t[2]] or 1)) end
  end
  return snap
end

local function check_snapshot(before, p, where)
  local after = game_snapshot(p)
  local keys = {}
  for k in pairs(before) do keys[#keys + 1] = k end
  for k in pairs(after) do if before[k] == nil then keys[#keys + 1] = k end end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do
    if after[k] ~= before[k] then
      error("prototypes/levels/" .. where .. " : dress a modifié le champ de jeu « " .. tostring(k)
        .. " » (interface : seuls les champs graphiques)")
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

--- Palette PROVISOIRE par époque : style commun des 7 familles, dans prototypes/levels/style.lua (un seul
--- propriétaire). Lecture seule.
kit.palette = Style.palette

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
  c.max_health = L.CC_HEALTH
  c.inventory_size = L.CC_INVENTORY
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

--- Contexte passé aux fichiers de famille : en LECTURE SEULE (écrire un champ est une erreur). family et
--- color sont des COPIES (les modifier n'a d'effet que sur ce niveau, et la garde le refuse pour family).
--- Renvoie ctx et sa table interne (pour la garde).
function Common.context(family, n)
  local e = L.epoch_of(family, n)
  local ep = L.epochs[e]
  local inner = {
    family = table.deepcopy(family), level = n, epoch = e, step = L.step_of(family, n), epoch_key = ep.key,
    color = table.deepcopy(ep.color), L = L, kit = kit,
  }
  local ctx = setmetatable({}, {
    __index = inner,
    __newindex = function(_, k) error("prototypes/levels : ctx est en lecture seule (champ « " .. tostring(k) .. " »)", 2) end,
  })
  return ctx, inner
end

-- Prototypes SOURCES lus pour fabriquer les niveaux d'une famille : dress ne doit jamais les modifier.
local SOURCES = {
  command = { { "container", "steel-chest" }, { "roboport", "roboport" }, { "radar", "radar" },
              { "beacon", "beacon" }, { "item", "roboport" } },
}
local function sources_of(family)
  return SOURCES[family.key] or { { family.type, family.base }, { "item", family.base } }
end

local function sources_snapshot(family)
  local out = {}
  for _, src in ipairs(sources_of(family)) do
    local t = data.raw[src[1]]
    out[#out + 1] = src[1] .. "/" .. src[2] .. "=" .. serialize(t and t[src[2]])
  end
  return out
end

-- État partagé : la config (données), la boîte à outils et le style commun.
local function shared_snapshot()
  return serialize({ epochs = L.epochs, materials = L.epoch_materials, families = L.families,
    item_value = L.item_value, stack_size = L.stack_size, kit = kit, style = Style })
end

--- Appelle visual.dress(p, ctx) sous la garde de l'interface (voir plus haut). `cache` : instantanés des
--- sources et de l'état partagé pris AVANT le premier appel de la famille (facultatif : sinon pris ici).
--- Une violation arrête l'étape data avec un message qui nomme le fichier et le niveau.
function Common.dress(visual, p, family, n, cache)
  cache = cache or {}
  cache.sources = cache.sources or sources_snapshot(family)
  cache.shared = cache.shared or shared_snapshot()
  cache.family = cache.family or serialize(family)
  local where = family.key .. ".lua (niveau " .. n .. ")"
  local ctx, inner = Common.context(family, n)
  local before = game_snapshot(p)
  visual.dress(p, ctx)
  check_snapshot(before, p, where)
  if serialize(inner.family) ~= cache.family then
    error("prototypes/levels/" .. where .. " : dress a modifié ctx.family (lecture seule)")
  end
  local now = sources_snapshot(family)
  for i, s in ipairs(now) do
    if s ~= cache.sources[i] then
      error("prototypes/levels/" .. where .. " : dress a modifié le prototype source data.raw."
        .. s:match("^([^=]+)"):gsub("/", "."))
    end
  end
  if shared_snapshot() ~= cache.shared then
    error("prototypes/levels/" .. where .. " : dress a modifié l'état partagé (config, ctx.kit ou style commun)")
  end
  return ctx
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
    local cache = {}
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
        local e = L.epoch_of(family, n)
        local ep = L.epochs[e]
        -- Paramètres en CHAÎNES (F43) : le chargeur refuse un nombre dans une chaîne localisée de prototype.
        p.localised_name = { "fo-levels.name", level_name(family), tostring(n) }
        if family.key == "command" then
          -- Le centre énonce la règle : plafond des bâtiments (2 × son niveau) et ouvriers.
          p.localised_description = { "fo-epochs.desc-cc", tostring(n), tostring(e), { "fo-epochs.name-" .. ep.key },
            tostring(L.building_cap(n)), tostring(L.builders(n)) }
        else
          p.localised_description = { "fo-epochs.desc", tostring(n), tostring(e), { "fo-epochs.name-" .. ep.key } }
        end
        p.minable = { mining_time = (p.minable and p.minable.mining_time) or 0.5, result = name }
        p.placeable_by = nil
        if family.key == "command" then p.flags = { "placeable-player", "player-creation" } end

        -- Visuel : fichier de la famille, sous garde.
        local dctx = Common.dress(visual, p, family, n, cache)
        lib.set_icons(p, family_icons(visual, p, dctx))
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
        lib.set_icons(item, family_icons(visual, item, dctx))
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
Common.game_snapshot = game_snapshot
return Common
