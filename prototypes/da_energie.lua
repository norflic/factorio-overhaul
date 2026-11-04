-- Lot DA-ENERGIE (4/11) : vrais visuels des bâtiments d'énergie, de nucléaire et de géologie, à la place des copies vanilla
-- teintées (lib.tint_sprites, lib.scale_sprites) : piscine d'entreposage, dépôt géologique, amplificateur de résonance.
-- Feuilles : graphics/da/energie/ (PNG hors de git, D-6 : tools/render/pieces/da_energie/feuilles.py), décrites par le
-- sprites.lua généré. Chargé à la fin de prototypes/geothermal.lua (après crafts, galena, spent_fuel, geothermal : les
-- prototypes habillés existent). Emprises, boîtes, recettes et statistiques INCHANGÉES : seules les images changent.
-- Un bâtiment absent de sprites.lua garde son visuel provisoire.

local lib = require("prototypes.lib")
local SPR = require("__factorio-overhaul__/graphics/da/energie/sprites")

--- Couche d'une feuille : normale (32 px/tuile) + hr_version (64 px/tuile, scale 0,5). kind : main, shadow, glow, light.
--- o.frames : rangée de o.frames images (pièce mobile) ; o.rep : image fixe répétée (synchronisée avec une rangée) ;
--- o.speed : animation_speed.
local function couche(def, kind, o)
  o = o or {}
  local function une(r, hr)
    local t = { filename = r.filename, width = r.width, height = r.height, shift = { r.shift[1], r.shift[2] }, priority = "high" }
    if o.frames then
      t.frame_count, t.line_length = o.frames, o.frames
    elseif o.rep then
      t.frame_count, t.repeat_count = 1, o.rep
    end
    if o.speed then t.animation_speed = o.speed end
    if kind == "shadow" then
      t.draw_as_shadow = true
    elseif kind == "glow" then
      t.draw_as_glow = true
      t.blend_mode = "additive"
      t.flags = { "linear-minification" }
    elseif kind == "light" then
      t.draw_as_light = true
      t.blend_mode = "additive"
    else
      t.flags = { "linear-minification" }
    end
    if hr then t.scale = 0.5 end
    return t
  end
  local s = une(def.lr, false)
  s.hr_version = une(def.hr, true)
  return s
end

local function boite(u) return { { u.boite[1][1], u.boite[1][2] }, { u.boite[2][1], u.boite[2][2] } } end

local function icones(u) return { { icon = u.icone.filename, icon_size = u.icone.icon_size, icon_mipmaps = u.icone.icon_mipmaps } } end

local function habiller_objet(name, u)
  local it = data.raw.item[name]
  if it then lib.set_icons(it, icones(u)) end
end

local function carte(e, u)
  e.map_color = { r = u.map_color[1], g = u.map_color[2], b = u.map_color[3] }
  e.friendly_map_color = e.map_color
end

---------------------------------------------------------------------------------------------------
-- Piscine d'entreposage (assembling-machine 4×4) : image fixe + pont polaire tournant (rangée d'images, un demi-tour par
-- cycle), lueur Tcherenkov animée avec le pont (occlusion juste), lumière bleue au travail.
---------------------------------------------------------------------------------------------------
do
  local u, e = SPR.piscine, data.raw["assembling-machine"]["fo-cooling-pool"]
  if u and e then
    local n = u.mobile.images
    local v = 0.01      -- un demi-tour du pont en 1 200 ticks à vitesse 1 (20 s)
    e.animation = { layers = { couche(u.main, "main", { rep = n, speed = v }), couche(u.mobile, "main", { frames = n, speed = v }),
      couche(u.shadow, "shadow", { rep = n, speed = v }) } }
    e.idle_animation = nil
    local vis = { { fadeout = true, animation = couche(u.mobile_glow, "glow", { frames = n, speed = v }),
      light = { intensity = 0.55, size = 9, color = { r = 0.25, g = 0.6, b = 1.0 } } } }
    if u.glow then vis[#vis + 1] = { fadeout = true, animation = couche(u.glow, "glow", { rep = n, speed = v }) } end
    e.working_visualisations = vis
    e.drawing_box = boite(u)
    e.water_reflection = nil
    carte(e, u)
    lib.set_icons(e, icones(u))
    habiller_objet(e.name, u)
  end
end

---------------------------------------------------------------------------------------------------
-- Dépôt géologique (container 6×6) : image FIXE (F44) ; lueurs fixes (feux, fenêtres) ; flaque du projecteur sur le trèfle
-- (draw_as_light : visible la nuit seulement).
---------------------------------------------------------------------------------------------------
do
  local u, e = SPR.depot, data.raw.container["fo-geological-repository"]
  if u and e then
    local L = { couche(u.main, "main"), couche(u.shadow, "shadow") }
    if u.glow then L[#L + 1] = couche(u.glow, "glow") end
    if u.lumiere then L[#L + 1] = couche(u.lumiere, "light") end
    e.picture = { layers = L }
    e.drawing_box = boite(u)
    e.water_reflection = nil
    e.scale_info_icons = true
    carte(e, u)
    lib.set_icons(e, icones(u))
    habiller_objet(e.name, u)
  end
end

---------------------------------------------------------------------------------------------------
-- Amplificateur de résonance (beacon 3×3) : image fixe + anneau de lentilles qui tourne (rangée, un tiers de tour par
-- cycle : 3 lentilles), lueur du cristal animée avec l'anneau, halo au sol teinté par les modules (apply_tint).
---------------------------------------------------------------------------------------------------
do
  local u, b = SPR.reso, data.raw.beacon["fo-resonance-amplifier"]
  if u and b then
    local n = u.mobile.images
    local v = 0.1       -- un tiers de tour en 120 ticks
    local glow = { couche(u.mobile_glow, "glow", { frames = n, speed = v }) }
    if u.glow then glow[#glow + 1] = couche(u.glow, "glow", { rep = n, speed = v }) end
    local list = {
      { render_layer = "object", always_draw = true, animation = { layers = { couche(u.main, "main", { rep = n, speed = v }),
        couche(u.mobile, "main", { frames = n, speed = v }), couche(u.shadow, "shadow", { rep = n, speed = v }) } } },
      { render_layer = "object", always_draw = false, animation = { layers = glow } },
    }
    if u.lumiere then
      list[#list + 1] = { render_layer = "object", always_draw = false, apply_tint = true, draw_as_light = true, draw_as_sprite = false,
        animation = couche(u.lumiere, "light", { rep = n, speed = v }) }
    end
    b.graphics_set = {
      animation_progress = 1,
      draw_animation_when_idle = true,
      draw_light_when_idle = false,
      module_icons_suppressed = false,
      apply_module_tint = "primary",
      module_tint_mode = "mix",
      no_modules_tint = { 0.4, 0.9, 1.0 },
      random_animation_offset = true,
      animation_list = list,
    }
    b.base_picture, b.animation, b.animation_shadow = nil, nil, nil
    b.drawing_box = boite(u)
    b.water_reflection = nil
    carte(b, u)
    lib.set_icons(b, icones(u))
    habiller_objet(b.name, u)
  end
end

---------------------------------------------------------------------------------------------------
-- Réacteur à sels fondus (reactor 5×5) : image fixe ; lueur du sel au travail (working_light_picture) ; état CHAUFFÉ du
-- collecteur en heat_picture (seul l'écart de lueur du cadre, rendu à part : critique du 4/11) ; plus de tuyaux vanilla
-- dessous (les 12 piquages sont dans l'image) ; plaques de raccord vanilla gardées.
---------------------------------------------------------------------------------------------------
do
  local u, e = SPR.msr, data.raw.reactor["fo-molten-salt-reactor"]
  if u and e then
    e.picture = { layers = { couche(u.main, "main"), couche(u.shadow, "shadow") } }
    if u.glow then e.working_light_picture = couche(u.glow, "glow") end
    if u.chaleur then
      e.heat_buffer = table.deepcopy(e.heat_buffer)
      e.heat_buffer.heat_picture = couche(u.chaleur, "glow")
    end
    e.lower_layer_picture, e.heat_lower_layer_picture = nil, nil
    e.use_fuel_glow_color = false
    e.light = { intensity = 0.55, size = 12, color = { r = 1.0, g = 0.45, b = 0.12 } }
    e.drawing_box = boite(u)
    e.water_reflection = nil
    carte(e, u)
    lib.set_icons(e, icones(u))
    habiller_objet(e.name, u)
  end
end

---------------------------------------------------------------------------------------------------
-- Capteur géothermique (mining-drill 3×3, sortie de fluide) : une base par direction (raccord aux positions du chevalet
-- vanilla), lueur du forage au travail, panache de vapeur = fumée vanilla teintée en blanc (0 image de plus : F186).
---------------------------------------------------------------------------------------------------
do
  local u, e = SPR.geo, data.raw["mining-drill"]["fo-geothermal-tap"]
  if u and e and u.directions then
    local base, glow = {}, {}
    for _, d in ipairs({ "north", "east", "south", "west" }) do
      local c = u.directions[d]
      base[d] = { layers = { couche(c.main, "main"), couche(c.shadow, "shadow") } }
      if c.glow then glow[d .. "_animation"] = couche(c.glow, "glow") end
    end
    e.base_picture = base
    e.base_render_layer = "object"
    e.animations = nil
    local vis = {}
    if glow.north_animation then
      glow.fadeout = true
      glow.light = { intensity = 0.4, size = 5, color = { r = 1.0, g = 0.4, b = 0.1 } }
      vis[#vis + 1] = glow
    end
    -- haut du silencieux : x = 0,62, y = 1,40, z = 2,26 en unités du rendu (m_geo.py), soit (0,62 ; -2,59) tuiles à l'écran
    vis[#vis + 1] = { fadeout = true, constant_speed = true, animation = {
      filename = "__base__/graphics/entity/smoke/smoke.png", width = 152, height = 120, line_length = 5, frame_count = 60,
      animation_speed = 0.25, scale = 0.45, shift = { 0.62 - 0.25, -2.59 - 0.4 }, priority = "high", flags = { "smoke" },
      tint = { r = 0.92, g = 0.93, b = 0.95, a = 0.5 },
    } }
    e.graphics_set = { working_visualisations = vis }
    e.drawing_box = boite(u)
    e.water_reflection = nil
    carte(e, u)
    lib.set_icons(e, icones(u))
    habiller_objet(e.name, u)
  end
end
