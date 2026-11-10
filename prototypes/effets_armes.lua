--[[
  Lot POLISSAGE-FX (10/11) : effets de particules et lumières dynamiques des armes avancées et des titans, à l'étape
  data-final-fixes (APRÈS l'arsenal, les armes par âge et les titans : tous les prototypes habillés existent). Règle pure :
  shared/content/effets_armes.lua (Fx) : une recette d'effets par MODE, la COULEUR lue dans la table de l'arme (A.ages[].glow,
  A.hand_weapons[].tint, A.cataclysm.tint, T.ALLIES[].lueur) : aucune couleur écrite ici.

  Par pack (Fx.armes) :
  - impact  : explosion vanilla copiée, teintée, mise à l'échelle, durée bornée, FLASH de lumière (pleine intensité, tenue,
              extinction), étincelles (optimized-particle teintées, nombre borné), onde de choc (feuille ONDE teintée) ;
  - bouche  : flash de bouche (explosion-hit teinté + lumière) posé en source_effects du tir des tourelles (faisceau, projectile) ;
  - projectile : lumière portée, traînée (trivial-smoke teintée, cadence bornée), corps VORTEX (feuille, additive) pour l'orbe de
              plasma et la roquette de singularité ; l'impact s'ajoute à l'arrivée ;
  - champ   : le nuage du lanceur de singularités (smoke-with-trigger) prend le vortex pour animation ;
  - titans  : griffes et éclair de singularité reçoivent leur onde, les tirs des drones leur lumière et leur traînée ;
  - animations « fo-fx-vortex » et « fo-fx-onde » (blanches) pour rendering.draw_animation (pulsation de la Sentinelle, script).
  Feuilles : graphics/effets/sprites.lua (tools/render/pieces/effets/vortex.py, PNG hors git, D-6). Tout est porté par le
  moteur : aucun effet par tick côté script (UPS). Âge 1 (cinétique) : délégué au lot TIRS (prototypes/tirs.lua).
]]

local K = require("prototypes.tirs_kit")
local Fx = require("shared.content.effets_armes")
local A = require("shared.content.arsenal")
local T = require("shared.robots.titans")
local SPR = require("__factorio-overhaul__/graphics/effets/sprites")

local out = {}
local packs, refus = Fx.armes(A, T)
for _, r in ipairs(refus) do error("[factorio-overhaul] effets_armes : " .. tostring(r.nom) .. " : " .. tostring(r.motif)) end
for _, p in ipairs(packs) do
  local motifs = Fx.verifier(p)
  if #motifs > 0 then error("[factorio-overhaul] effets_armes : " .. table.concat(motifs, " ; ")) end
end

local function rgba(c, a) return Fx.rgba(c, a) end
local function color(c) return { r = c.r, g = c.g, b = c.b } end

--- Animation d'une feuille (vortex, onde) : rangée de `images` images, échelle = diamètre en tuiles, durée en ticks (une boucle).
local function feuille_anim(cle, c, echelle, duree)
  local s = SPR[cle]
  assert(s, "effets_armes : feuille absente de graphics/effets/sprites.lua : " .. tostring(cle))
  local k = echelle / Fx.FEUILLE_TUILES
  local function une(d, hr)
    return { filename = d.filename, width = d.width, height = d.height, frame_count = s.images, line_length = s.images,
      animation_speed = s.images / duree, scale = d.scale * k, tint = rgba(c), blend_mode = "additive", draw_as_glow = true,
      priority = "extra-high", flags = { "linear-minification" } }
  end
  local a = une(s.lr, false)
  a.hr_version = une(s.hr, true)
  return a
end

local function lumiere(l) return { intensity = l.intensite, size = l.taille, color = color(l.couleur) } end

--- Nom affiché d'un effet : celui de son arme (entité pour une tourelle ou un titan, objet pour une arme de poing ou une capsule) :
--- aucune clé de traduction nouvelle (F43 : un paramètre de localised_name est une chaîne).
local function nom_affiche(pack)
  for _, t in ipairs({ "gun", "capsule", "item" }) do
    if data.raw[t] and data.raw[t][pack.nom] and not (data.raw["electric-turret"][pack.nom] or data.raw["ammo-turret"][pack.nom]) then
      return { "item-name." .. pack.nom }
    end
  end
  return { "entity-name." .. pack.nom }
end

--- Éclair de lumière d'une explosion : pleine intensité tout de suite, tenue une part de la vie, puis extinction ; `onde` : la
--- lumière part plus petite et grandit.
local function flash(e, l)
  e.light = lumiere(l)
  e.light_intensity_factor_initial, e.light_intensity_factor_final = 1, 0
  e.light_intensity_peak_start_progress, e.light_intensity_peak_end_progress = 0, l.tenue or 0.35
  e.light_size_factor_initial, e.light_size_factor_final = l.onde or 1, 1
  e.light_size_peak_start_progress, e.light_size_peak_end_progress = l.onde and 0.7 or 0, 1
end

--- Particule teintée (copie d'une optimized-particle vanilla) ; rend son nom.
local function particule(nom, et, c, affiche)
  local src = data.raw["optimized-particle"][et.source]
  assert(src, "effets_armes : particule vanilla absente " .. tostring(et.source))
  local p = table.deepcopy(src)
  p.name = nom
  p.localised_name = affiche
  for _, v in ipairs(K.variations(p.pictures)) do K.teinter(v, rgba(c)) end
  out[#out + 1] = p
  return nom
end

local function etincelles(nom, et, c, affiche)
  local monte = et.montee or 0.04
  return {
    type = "create-particle", particle_name = particule(nom, et, c, affiche), repeat_count = et.nombre,
    affects_target = false, show_in_tooltip = false,
    offset_deviation = { { -0.25, -0.25 }, { 0.25, 0.25 } },
    initial_height = 0.6, initial_height_deviation = 0.3,
    initial_vertical_speed = monte, initial_vertical_speed_deviation = 0.5 * monte,
    speed_from_center = et.vitesse, speed_from_center_deviation = 0.6 * et.vitesse,
    frame_speed = 0.5, frame_speed_deviation = 0.2,
  }
end

--- Onde de choc : explosion dont l'animation est la feuille ONDE teintée ; rend son nom.
local function onde(nom, o, c, l, affiche)
  local e = {
    type = "explosion", name = nom, flags = { "not-on-map", "hidden" }, subgroup = "explosions", localised_name = affiche,
    animations = { feuille_anim("onde", c, o.echelle, o.duree) }, rotate = false,
  }
  if l then flash(e, l) end
  out[#out + 1] = e
  return nom
end

--- Explosion d'impact d'un pack (nil si le pack n'en a pas de source : l'onde seule est alors l'impact) ; rend son nom.
local function impact(pack)
  local i = pack.impact
  if not i then return nil end
  local c = pack.couleur
  local nom = Fx.nom(pack, "impact")
  local effets = {}
  if i.etincelles then effets[#effets + 1] = etincelles(Fx.nom(pack, "etincelle"), i.etincelles, c, nom_affiche(pack)) end
  if i.onde then effets[#effets + 1] = { type = "create-entity", entity_name = onde(Fx.nom(pack, "onde"), i.onde, c, not i.source and i.lumiere or nil, nom_affiche(pack)) } end
  if not i.source then return Fx.nom(pack, "onde") end
  local src = data.raw.explosion[i.source]
  assert(src, "effets_armes : explosion vanilla absente " .. tostring(i.source))
  local anims = K.variations(table.deepcopy(src.animations))
  for _, a in ipairs(anims) do
    K.agrandir(a, i.echelle)
    K.teinter(a, rgba(c))
    K.duree(a, i.duree)
  end
  local e = {
    type = "explosion", name = nom, flags = { "not-on-map", "hidden" }, subgroup = "explosions",
    localised_name = nom_affiche(pack), animations = anims, rotate = false, sound = src.sound,
    smoke = src.smoke, smoke_count = src.smoke_count, smoke_slow_down_factor = src.smoke_slow_down_factor,
  }
  if i.lumiere then flash(e, i.lumiere) end
  if #effets > 0 then e.created_effect = { type = "direct", action_delivery = { type = "instant", target_effects = effets } } end
  out[#out + 1] = e
  return nom
end

--- Flash de bouche d'un pack ; rend son nom (nil sans bouche).
local function bouche(pack)
  local b = pack.bouche
  if not b then return nil end
  local src = data.raw.explosion["explosion-hit"]
  local anims = K.variations(table.deepcopy(src.animations))
  for _, a in ipairs(anims) do
    K.agrandir(a, 1.2)
    K.teinter(a, rgba(pack.couleur))
    K.duree(a, b.duree)
  end
  local e = {
    type = "explosion", name = Fx.nom(pack, "bouche"), flags = { "not-on-map", "hidden" }, subgroup = "explosions",
    localised_name = nom_affiche(pack), animations = anims, rotate = false,
  }
  flash(e, { taille = b.taille, intensite = b.intensite, couleur = pack.couleur, tenue = 0.5 })
  out[#out + 1] = e
  return e.name
end

--- Traînée d'un projectile : trivial-smoke teintée (couleur de l'arme, alpha de la recette) ; rend la SmokeSource.
local function trainee(pack, t)
  local src = data.raw["trivial-smoke"][t.source]
  assert(src, "effets_armes : fumée vanilla absente " .. tostring(t.source))
  local s = table.deepcopy(src)
  s.name = Fx.nom(pack, "trainee")
  s.localised_name = nom_affiche(pack)
  s.color = rgba(pack.couleur, t.alpha)
  s.start_scale, s.end_scale = t.debut, t.fin
  s.duration = t.duree
  s.fade_away_duration = math.floor(t.duree * 0.6)
  s.affected_by_wind = false
  out[#out + 1] = s
  return { name = s.name, deviation = { 0.1, 0.1 }, frequency = t.frequence, position = { 0, 0 },
    starting_frame = 3, starting_frame_deviation = 5, starting_frame_speed = 0, starting_frame_speed_deviation = 5 }
end

--- Ajoute `effet` aux target_effects de la livraison instantanée d'une action « direct » (table ou liste).
local function ajoute_cible(action, effet)
  local items = action.type and { action } or action
  for _, it in ipairs(items) do
    local ds = it.action_delivery
    ds = ds and (ds.type and { ds } or ds) or {}
    for _, d in ipairs(ds) do
      if d.type == "instant" then
        d.target_effects = d.target_effects or {}
        local te = d.target_effects.type and { d.target_effects } or d.target_effects
        te[#te + 1] = effet
        d.target_effects = te
        return true
      end
    end
  end
  return false
end

--- Remplace les create-entity d'un nom donné dans les effets d'une action (arcs : explosion-hit -> impact de l'arme).
local function remplace_entite(t, de, vers, seen)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if t.type == "create-entity" and t.entity_name == de then t.entity_name = vers return end
  for _, v in pairs(t) do remplace_entite(v, de, vers, seen) end
end

local function projectile(p, pack, nom_impact)
  local pr = pack.projectile
  if not (p and pr) then return end
  if pr.lumiere then p.light = lumiere(pr.lumiere) end
  if pr.trainee then p.smoke = { trainee(pack, pr.trainee) } end
  if pr.vortex then
    p.animation = feuille_anim("vortex", pack.couleur, pr.vortex.echelle, 24)
    p.shadow = nil
    p.rotatable = false
  end
  if nom_impact and p.action then ajoute_cible(p.action, { type = "create-entity", entity_name = nom_impact }) end
end

local function source_bouche(t, nom_bouche)
  if not (t and nom_bouche) then return end
  local ap = t.attack_parameters
  local d = ap and ap.ammo_type and ap.ammo_type.action and ap.ammo_type.action.action_delivery
  if d then d.source_effects = { type = "create-explosion", entity_name = nom_bouche } end
end

---------------------------------------------------------------------------------------------------
-- Animations blanches pour rendering.draw_animation (teintées par le script : couleur de la règle du titan)
---------------------------------------------------------------------------------------------------
for _, cle in ipairs({ "vortex", "onde" }) do
  local a = feuille_anim(cle, { r = 1, g = 1, b = 1 }, Fx.FEUILLE_TUILES, 24)   -- blanc : le script teinte (couleur de la règle)
  a.type, a.name = "animation", Fx.PREFIXE .. cle
  out[#out + 1] = a
end

---------------------------------------------------------------------------------------------------
-- Habillage par pack
---------------------------------------------------------------------------------------------------
local nb = 0
for _, pack in ipairs(packs) do
  if not pack.delegue then
    nb = nb + 1
    local ni, nbo = impact(pack), bouche(pack)
    local nom = pack.nom
    if pack.mode == "laser" then
      local b = data.raw.beam[nom .. "-beam"]
      if b and b.action and ni then ajoute_cible(b.action, { type = "create-entity", entity_name = ni }) end
      source_bouche(data.raw["electric-turret"][nom], nbo)
    elseif pack.mode == "arc" then
      for _, s in ipairs({ "-arc-1", "-arc-2" }) do
        local b = data.raw.beam[nom .. s]
        if b and ni then remplace_entite(b.action, "explosion-hit", ni, {}) end
      end
      source_bouche(data.raw["electric-turret"][nom], nbo)
    elseif pack.mode == "plasma" then
      projectile(data.raw.projectile[nom .. "-orb"], pack, ni)
      source_bouche(data.raw["electric-turret"][nom], nbo)
    elseif pack.mode == "rail" then
      local ammo = data.raw.ammo[A.hand_weapons[1].ammo] -- la balle du fusil à rail, lue dans les données de l'arme
      for _, h in ipairs(A.hand_weapons) do if h.name == nom then ammo = data.raw.ammo[h.ammo] end end
      local act = ammo and ammo.ammo_type and ammo.ammo_type.action
      if act and ni then
        ajoute_cible(act, { type = "create-entity", entity_name = ni })
        local items = act.type and { act } or act
        for _, it in ipairs(items) do if it.type == "line" and nbo then it.source_effects = { type = "create-explosion", entity_name = nbo } end end
      end
    elseif pack.mode == "singularite" then
      projectile(data.raw.projectile[nom .. "-projectile"], pack, ni)
      local cloud = data.raw["smoke-with-trigger"][nom .. "-field"]
      if cloud and pack.champ and pack.champ.vortex then
        cloud.animation = feuille_anim("vortex", pack.couleur, pack.champ.vortex.echelle, 36)
        cloud.color = rgba(pack.couleur, 0.6)
        cloud.render_layer = "object"
      end
    elseif pack.mode == "champ" then
      local eq = data.raw["active-defense-equipment"][nom]
      local act = eq and eq.attack_parameters.ammo_type.action
      if act and ni then
        ajoute_cible(act, { type = "create-entity", entity_name = ni })
        local items = act.type and { act } or act
        items[#items + 1] = { type = "direct", action_delivery = { type = "instant", source_effects = { { type = "create-entity", entity_name = Fx.nom(pack, "onde") } } } }
      end
    elseif pack.mode == "orbital" then
      local marker = data.raw["combat-robot"][nom .. "-marker"]
      local d = marker and marker.destroy_action and marker.destroy_action.action_delivery
      if d and d.source_effects then
        local se = d.source_effects.type and { d.source_effects } or d.source_effects
        se[#se + 1] = { type = "create-entity", entity_name = Fx.nom(pack, "onde") }
        d.source_effects = se
      end
    elseif pack.mode == "titan" then
      for _, r in ipairs(T.ALLIES) do
        if r.name == nom then
          if r.griffes then
            local e = data.raw.explosion[T.PREFIX .. "griffe"]
            if e and ni then
              e.created_effect = { type = "direct", action_delivery = { type = "instant", target_effects = { { type = "create-entity", entity_name = ni } } } }
              flash(e, pack.impact.lumiere)
            end
          end
          if r.singularite then
            local e = data.raw.explosion[T.PREFIX .. "singularite-eclair"]
            if e and ni then
              e.created_effect = { type = "direct", action_delivery = { type = "instant", target_effects = { { type = "create-entity", entity_name = ni } } } }
              flash(e, pack.impact.lumiere)
            end
          end
          if r.drones then
            local fumee = trainee(pack, pack.projectile.trainee)   -- UNE fumée pour tous les paliers (même nom)
            for palier = 1, T.PALIERS do
              local p = data.raw.projectile[T.PREFIX .. "drone-tir-" .. palier]
              if p then
                p.light = lumiere(pack.projectile.lumiere)
                p.smoke = { table.deepcopy(fumee) }
              end
            end
          end
        end
      end
    end
  end
end

data:extend(out)
log("[FO-EFFETS] " .. #out .. " prototype(s) d'effets pour " .. nb .. " arme(s) et titan(s) (couleurs lues dans leurs tables)")
