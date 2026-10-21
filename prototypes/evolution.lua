--[[
  Évolution visuelle par palier (session 4, demande du Directeur Créatif : « à la mode des évolutions de
  Clash of Clans : on ne change pas seulement la couleur, mais le design »).

  Sans fichier image ajouté, un palier supérieur se voit par des COUCHES en plus :
  - une couche lumineuse (copie additive des masques de l'animation : plaques de carapace, veines,
    tuyauteries) qui luit la nuit (draw_as_glow) et dont l'intensité croît avec le palier ;
  - des pièces ajoutées (antennes, réservoirs, accumulateurs...) : voir prototypes/arsenal_special.lua.

  Fonctions pures sur les tables de sprites de l'étape data : elles ne lisent ni n'écrivent data.raw.
]]

local Evo = {}

local function has_mask_flag(sp)
  if sp.apply_runtime_tint then return true end
  for _, f in ipairs(sp.flags or {}) do
    if f == "mask" then return true end
  end
  return false
end

local function is_sprite(t)
  return type(t) == "table" and (t.filename or t.filenames or t.stripes) ~= nil
end

local function mark_glow(sp, color, alpha)
  sp.tint = { r = color.r * alpha, g = color.g * alpha, b = color.b * alpha, a = alpha }
  sp.blend_mode = "additive"
  sp.draw_as_glow = true
  sp.draw_as_shadow = nil
  sp.apply_runtime_tint = nil
  if sp.hr_version then mark_glow(sp.hr_version, color, alpha) end
end

--- Ajoute à chaque liste de couches de `anim` une copie lumineuse de son DERNIER masque (le masque de
--- reflets des déchiqueteurs, la lueur des nids...). Gère les animations à couches, les tableaux de
--- variantes et les animations à 4 orientations. Renvoie le nombre de couches ajoutées.
function Evo.glow_masks(anim, color, alpha, seen)
  seen = seen or {}
  if type(anim) ~= "table" or seen[anim] then return 0 end
  seen[anim] = true
  local added = 0
  if type(anim.layers) == "table" then
    local src
    for i = #anim.layers, 1, -1 do
      local l = anim.layers[i]
      if is_sprite(l) and has_mask_flag(l) then
        src = l
        break
      end
    end
    if src then
      local g = table.deepcopy(src)
      mark_glow(g, color, alpha)
      anim.layers[#anim.layers + 1] = g
      return 1
    end
    return 0
  end
  for k, v in pairs(anim) do
    if type(v) == "table" and k ~= "hr_version" then added = added + Evo.glow_masks(v, color, alpha, seen) end
  end
  return added
end

local function mark_light(sp, color, intensity)
  sp.tint = { r = color.r * intensity, g = color.g * intensity, b = color.b * intensity, a = 1 }
  sp.blend_mode = "additive"
  sp.draw_as_light = true
  sp.draw_as_glow = nil
  sp.draw_as_shadow = nil
  sp.apply_runtime_tint = nil
  if sp.hr_version then mark_light(sp.hr_version, color, intensity) end
end

--- Halo de nuit : copie « lumière » (draw_as_light : invisible le jour, dessinée dans la carte des lumières
--- la nuit) de la couche PRINCIPALE de chaque liste de couches. La pièce entière s'éclaire de `color` la
--- nuit (moteur réel : la copie lumineuse des seuls masques d'une tête de tourelle, une bande de quelques
--- pixels, ne se voyait pas). Renvoie le nombre de couches ajoutées.
function Evo.light_layers(anim, color, intensity, seen)
  seen = seen or {}
  if type(anim) ~= "table" or seen[anim] then return 0 end
  seen[anim] = true
  if type(anim.layers) == "table" then
    for _, l in ipairs(anim.layers) do
      if is_sprite(l) and not l.draw_as_shadow and not l.draw_as_glow and not l.draw_as_light and not has_mask_flag(l) then
        local g = table.deepcopy(l)
        mark_light(g, color, intensity)
        anim.layers[#anim.layers + 1] = g
        return 1
      end
    end
    return 0
  end
  if is_sprite(anim) then return 0 end
  local added = 0
  for k, v in pairs(anim) do
    if type(v) == "table" and k ~= "hr_version" then added = added + Evo.light_layers(v, color, intensity, seen) end
  end
  return added
end

--- Reflet : copie additive « draw_as_glow » de la couche PRINCIPALE de chaque liste de couches, teinte
--- `color` × `alpha` (visible de jour comme de nuit : le matériau « brille »). Renvoie le nombre de couches.
function Evo.sheen_layers(anim, color, alpha, seen)
  seen = seen or {}
  if type(anim) ~= "table" or seen[anim] then return 0 end
  seen[anim] = true
  if type(anim.layers) == "table" then
    for _, l in ipairs(anim.layers) do
      if is_sprite(l) and not l.draw_as_shadow and not l.draw_as_glow and not l.draw_as_light and not has_mask_flag(l) then
        local g = table.deepcopy(l)
        mark_glow(g, color, alpha)
        anim.layers[#anim.layers + 1] = g
        return 1
      end
    end
    return 0
  end
  if is_sprite(anim) then return 0 end
  local added = 0
  for k, v in pairs(anim) do
    if type(v) == "table" and k ~= "hr_version" then added = added + Evo.sheen_layers(v, color, alpha, seen) end
  end
  return added
end

--- Copie lumineuse d'un sprite entier (pour les décors : roches en fusion, cristaux).
function Evo.glow_copy(sprite, color, alpha)
  local g = table.deepcopy(sprite)
  local function walk(t)
    if type(t) ~= "table" then return end
    if is_sprite(t) then mark_glow(t, color, alpha) end
    for k, v in pairs(t) do
      if k ~= "hr_version" then walk(v) end
    end
  end
  walk(g)
  return g
end

--- Intensité de la lueur d'un palier (1 à 8) : discrète aux premiers paliers, éclatante au dernier.
function Evo.tier_alpha(tier, base, step)
  return math.min(1, (base or 0.25) + (step or 0.08) * tier)
end

return Evo
