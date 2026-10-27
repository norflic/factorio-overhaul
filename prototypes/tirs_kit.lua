--[[
  Tirs des tourelles par âge (lot TIRS) : boîte à outils de l'étape data, PURE (ne lit ni n'écrit data.raw ; les
  appelants passent les tables). Utilisée par prototypes/tirs.lua (explosions, traçantes, traits), par
  prototypes/levels/gun.lua (son du tir en couches) et par prototypes/levels/laser.lua (faisceau de l'âge, sous la
  garde de l'interface : seuls des champs graphiques ou sonores y changent).
]]

local R = require("shared.tirs.regles")

local K = {}

--- Applique fn à chaque définition d'image d'une animation (couches et hr_version comprises).
function K.chaque(anim, fn)
  if type(anim) ~= "table" then return end
  if anim.layers then
    for _, l in ipairs(anim.layers) do K.chaque(l, fn) end
    return
  end
  fn(anim)
  if anim.hr_version then fn(anim.hr_version) end
end

--- Une animation isolée ou une liste de variations -> liste de variations.
function K.variations(a)
  if a.filename or a.filenames or a.layers or a.stripes then return { a } end
  return a
end

function K.agrandir(anim, f)
  K.chaque(anim, function(l)
    l.scale = (l.scale or 1) * f
    if l.shift then
      local x, y = l.shift[1] or l.shift.x or 0, l.shift[2] or l.shift.y or 0
      l.shift = { x * f, y * f }
    end
  end)
end

function K.teinter(anim, c)
  K.chaque(anim, function(l) l.tint = R.couleur(c) end)
end

--- Durée de l'animation en ticks (animation_speed = images / durée).
function K.duree(anim, ticks)
  K.chaque(anim, function(l)
    local n = (l.frame_count or 1) * (l.repeat_count or 1)
    l.animation_speed = n / ticks
  end)
end

--- Couche lumineuse additive (dessinée par-dessus le jour, visible la nuit).
function K.lumineux(anim)
  K.chaque(anim, function(l)
    l.draw_as_glow = true
    l.blend_mode = "additive"
  end)
end

--- Lumière du moteur (texture de lumière par défaut du core : aucune image nouvelle).
function K.lumiere(l)
  return { intensity = l.intensite, size = l.taille, color = R.couleur(l.couleur) }
end

--- Son du tir de l'âge : la couche S0 de l'ère (variations, volume de l'ère) et les couches AJOUTÉES de l'âge
--- (fichiers vanilla référencés, jamais copiés). Sans couche ajoutée : la liste de variations d'avant (S0, inchangé).
--- La vitesse de lecture va dans CHAQUE variation (SoundDefinition.min_speed / max_speed) : posée sur la couche à côté
--- de `variations`, le moteur l'IGNORE (doc 1.1.91 de Sound.min_speed : « Only loaded if both `variations` and `speed`
--- are not defined » ; défaut du prototype de la ronde 3, relevé par le critique).
function K.son_tir(variations_s0, A)
  local couches = A and A.son and A.son.couches
  if not couches or #couches == 0 then return variations_s0 end
  local layers = { { variations = variations_s0 } }
  for _, c in ipairs(couches) do
    local v = {}
    for i, f in ipairs(R.fichiers(c.fichiers)) do
      v[i] = { filename = f, volume = c.volume }
      if c.vitesse then v[i].min_speed, v[i].max_speed = c.vitesse[1], c.vitesse[2] end
    end
    layers[#layers + 1] = {
      variations = v,
      allow_random_repeat = false,
      aggregation = { max_count = c.max, remove = true, count_already_playing = true },
    }
  end
  return { layers = layers }
end

--- Son simple d'une explosion (impact) : variations vanilla référencées, aggregation.
function K.son_simple(s)
  local v = {}
  for i, f in ipairs(R.fichiers(s.fichiers)) do v[i] = { filename = f, volume = s.volume } end
  return { variations = v, aggregation = { max_count = s.max, remove = true, count_already_playing = true } }
end

-- Textures BLANCHES (lumière, LA blanc mesuré) du faisceau laser vanilla, mêmes cadres que les textures rouges.
local BLANC = {
  ["__base__/graphics/entity/laser-turret/hr-laser-body.png"] = "__base__/graphics/entity/laser-turret/hr-laser-body-light.png",
  ["__base__/graphics/entity/laser-turret/hr-laser-end.png"] = "__base__/graphics/entity/laser-turret/hr-laser-end-light.png",
}

--- Habille un faisceau (copie de laser-beam) : corps et bouts en textures blanches teintées (teinte), épaissis
--- (epaisseur), cœur lumineux (coeur) et lumière au sol (sol). Champs graphiques seulement : head, tail, body,
--- light_animations, ground_light_animations.
function K.faisceau_blanc(b, spec)
  local function corps(a, c, k)
    K.chaque(a, function(l)
      l.filename = BLANC[l.filename] or l.filename
      l.tint = R.couleur(c)
      l.blend_mode = "additive"
    end)
    K.agrandir(a, k)
  end
  for _, champ in ipairs({ "head", "tail" }) do
    if b[champ] then corps(b[champ], spec.teinte, spec.epaisseur) end
  end
  for _, v in ipairs(K.variations(b.body or {})) do corps(v, spec.teinte, spec.epaisseur) end
  local la = b.light_animations
  if la then
    for _, champ in ipairs({ "head", "tail" }) do
      if la[champ] then corps(la[champ], spec.coeur, 0.6 * spec.epaisseur) end
    end
    for _, v in ipairs(K.variations(la.body or {})) do corps(v, spec.coeur, 0.6 * spec.epaisseur) end
  end
  local gl = b.ground_light_animations
  if gl and spec.sol then
    for _, champ in ipairs({ "head", "tail", "body" }) do
      if gl[champ] then
        for _, v in ipairs(K.variations(gl[champ])) do
          K.chaque(v, function(l) l.tint = R.couleur(spec.sol) end)
          K.agrandir(v, math.sqrt(spec.epaisseur))
        end
      end
    end
  end
  return b
end

return K
