--[[
  Tirs des tourelles par âge (lot TIRS, 27/10) : prototypes de l'étape data. Données : shared/tirs/ages.lua ; règles
  pures : shared/tirs/regles.lua ; runtime : script/tirs/tirs.lua. Requis par data.lua APRÈS prototypes.levels (la
  garde des familles est fermée) et après l'arsenal (les 4 chargeurs du mod existent).

  1. Par âge témoin : explosions de bouche et d'impact, traçante (projectile sans dégâts, son action crée l'impact à
     l'arrivée), trait (faisceau SANS action), particules et fumées teintées ; uniquement des fichiers vanilla déjà
     chargés par le jeu (aucune image nouvelle).
  2. Les chargeurs « bullet » reçoivent un AmmoType propre aux TOURELLES (source_type = "turret"), copie exacte du
     leur plus un effet `script` (T.ID, probabilité T.probabilite) ; le pistolet-mitrailleur, les véhicules et tout
     autre tireur gardent l'AmmoType d'avant (« default »).
  3. Garde : chaque prototype du lot est relu par R.verifier_prototype (aucun effet de jeu) et chaque AmmoType
     « turret » est comparé au « default » (seul l'effet script diffère) ; un écart arrête l'étape data.
]]

local T = require("shared.tirs.ages")
local R = require("shared.tirs.regles")
local K = require("prototypes.tirs_kit")

local motifs = R.verifier_ages(T)
if #motifs > 0 then error("[factorio-overhaul] shared/tirs/ages.lua : " .. table.concat(motifs, " ; ")) end

local out = {}          -- prototypes du lot, dans l'ordre de création
local permis = {}       -- noms d'explosions, de particules et de fumées que les actions du lot peuvent citer

local function nom_affiche(age) return { "fo-tirs.effet", tostring(age) } end

--- Fumée teintée (copie de la fumée vanilla) ; rend son nom.
local function fumee(nom, spec, age)
  local src = data.raw["trivial-smoke"][spec.source]
  assert(src, "prototypes/tirs.lua : fumee vanilla absente " .. tostring(spec.source))
  local s = table.deepcopy(src)
  s.name = nom
  s.color = R.couleur(spec.couleur)
  s.localised_name = nom_affiche(age)
  out[#out + 1] = s
  permis[nom] = true
  return nom
end

--- Particule teintée (copie de la particule vanilla) ; rend son nom.
local function particule(nom, spec, age)
  local src = data.raw["optimized-particle"][spec.source]
  assert(src, "prototypes/tirs.lua : particule vanilla absente " .. tostring(spec.source))
  local p = table.deepcopy(src)
  p.name = nom
  for _, v in ipairs(K.variations(p.pictures)) do K.teinter(v, spec.teinte) end
  p.localised_name = nom_affiche(age)
  out[#out + 1] = p
  permis[nom] = true
  return nom
end

--- Animations d'une explosion : copiées d'une explosion vanilla (source) ou d'une image de T.IMAGES.
local function animations(spec)
  local anims
  if spec.source then
    local src = data.raw.explosion[spec.source]
    assert(src, "prototypes/tirs.lua : explosion vanilla absente " .. tostring(spec.source))
    anims = K.variations(table.deepcopy(src.animations))
  else
    local img = table.deepcopy(T.IMAGES[spec.image])
    K.lumineux(img)
    anims = { img }
  end
  for _, a in ipairs(anims) do
    K.agrandir(a, spec.echelle)
    K.teinter(a, spec.teinte)
    if spec.duree then K.duree(a, spec.duree) end
  end
  return anims
end

--- Explosion d'un âge (bouche ou impact) ; rend son nom.
local function explosion(nom, spec, age)
  local e = {
    type = "explosion", name = nom, flags = { "not-on-map", "hidden" }, subgroup = "explosions",
    localised_name = nom_affiche(age), animations = animations(spec), rotate = spec.tourne == true,
  }
  if spec.lumiere then
    e.light = K.lumiere(spec.lumiere)
    -- éclair : intensité pleine tout de suite, puis s'éteint ; onde : la lumière grandit de `onde` à 1
    e.light_intensity_factor_initial, e.light_intensity_factor_final = 1, 0
    e.light_intensity_peak_start_progress, e.light_intensity_peak_end_progress = 0, 0.35
    local o = spec.lumiere.onde
    e.light_size_factor_initial, e.light_size_factor_final = o or 1, 1
    e.light_size_peak_start_progress, e.light_size_peak_end_progress = o and 0.7 or 0, 1
  end
  if spec.fumee then
    e.smoke = fumee(nom .. "-fumee", spec.fumee, age)
    e.smoke_count = spec.fumee.nombre
    e.smoke_slow_down_factor = 1
  end
  if spec.etincelles then
    local et = spec.etincelles
    e.created_effect = { type = "direct", action_delivery = { type = "instant", target_effects = { {
      type = "create-particle", particle_name = particule(nom .. "-etincelle", et, age), repeat_count = et.nombre,
      affects_target = false, show_in_tooltip = false,
      offset_deviation = { { -0.25, -0.25 }, { 0.25, 0.25 } },
      initial_height = 0.8, initial_height_deviation = 0.4,
      initial_vertical_speed = 0.04, initial_vertical_speed_deviation = 0.04,
      speed_from_center = et.vitesse, speed_from_center_deviation = 0.6 * et.vitesse,
      frame_speed = 0.5, frame_speed_deviation = 0.2,
    } } } }
  end
  if spec.son then e.sound = K.son_simple(spec.son) end
  out[#out + 1] = e
  permis[nom] = true
  return nom
end

-- Le faisceau vanilla dont le trait reprend les cadres (laser-beam : textures blanches de même cadre, K.BLANC).
local function trait(nom, spec, age)
  local b = table.deepcopy(data.raw.beam["laser-beam"])
  b.name = nom
  b.localised_name = nom_affiche(age)
  b.action = nil
  b.working_sound = nil
  b.damage_interval = 1000
  b.random_target_offset = false
  K.faisceau_blanc(b, { teinte = spec.teinte, coeur = spec.coeur, epaisseur = spec.epaisseur,
    sol = { spec.teinte[1] * 0.6, spec.teinte[2] * 0.6, spec.teinte[3] * 0.6 } })
  out[#out + 1] = b
  return nom
end

local function trace(nom, spec, impacts, age)
  local img = table.deepcopy(T.IMAGES[spec.image])
  K.lumineux(img)
  K.agrandir(img, spec.echelle)
  K.teinter(img, spec.teinte)
  local p = {
    type = "projectile", name = nom, flags = { "not-on-map" }, localised_name = nom_affiche(age),
    acceleration = 0, rotatable = true, animation = img,
    light = spec.lumiere and K.lumiere(spec.lumiere) or nil,
  }
  if spec.trainee then
    p.smoke = { {
      name = fumee(nom .. "-fumee", spec.trainee, age), deviation = { 0.1, 0.1 }, frequency = spec.trainee.frequence,
      position = { 0, 0 }, starting_frame = 3, starting_frame_deviation = 5, starting_frame_speed = 0,
      starting_frame_speed_deviation = 5,
    } }
  end
  local effets = {}
  for i, n in ipairs(impacts) do effets[i] = { type = "create-explosion", entity_name = n } end
  p.action = { type = "direct", action_delivery = { type = "instant", target_effects = effets } }
  out[#out + 1] = p
  return nom
end

for _, age in ipairs(T.temoins) do
  local A = T.ages[age]
  for i, spec in ipairs(A.bouche) do explosion(R.nom(T, age, "bouche", i), spec, age) end
  local impacts = {}
  for i, spec in ipairs(A.impact) do impacts[i] = explosion(R.nom(T, age, "impact", i), spec, age) end
  if A.trace then trace(R.nom(T, age, "trace"), A.trace, impacts, age) end
  if A.trait then trait(R.nom(T, age, "trait"), A.trait, age) end
end

-- Garde du lot : aucun prototype ne porte d'effet de jeu.
for _, p in ipairs(out) do
  local m = R.verifier_prototype(p, permis)
  if m then error("[factorio-overhaul] prototypes/tirs.lua : " .. m) end
end
data:extend(out)

---------------------------------------------------------------------------------------------------
-- Chargeurs : AmmoType propre aux tourelles = copie + effet script (le reste du chargeur ne change pas).
---------------------------------------------------------------------------------------------------
local function liste(t) if t.type ~= nil then return { t } end return t end

local function avec_script(at)
  local c = table.deepcopy(at)
  c.source_type = "turret"
  local item = liste(c.action)[1]
  local d = liste(item.action_delivery)[1]
  assert(d.type == "instant", "prototypes/tirs.lua : livraison « " .. tostring(d.type) .. " » non prise en charge")
  local te = d.target_effects
  if te == nil then te = {} elseif te.type ~= nil then te = { te } end
  te[#te + 1] = { type = "script", effect_id = T.ID, probability = T.probabilite, show_in_tooltip = false }
  d.target_effects = te
  return c
end

local noms = {}
for n, item in pairs(data.raw.ammo) do
  local at = item.ammo_type
  if at and at.category == "bullet" and at.source_type == nil then noms[#noms + 1] = n end
end
table.sort(noms)

local function egal(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not egal(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

for _, n in ipairs(noms) do
  local item = data.raw.ammo[n]
  local base = item.ammo_type
  local tourelle = avec_script(base)
  -- garde : la copie « turret », sans son dernier effet (le script) ni source_type, est l'AmmoType d'avant
  local relu = table.deepcopy(tourelle)
  relu.source_type = nil
  local d = liste(liste(relu.action)[1].action_delivery)[1]
  local dernier = table.remove(d.target_effects)
  local avant = table.deepcopy(base)
  local da = liste(liste(avant.action)[1].action_delivery)[1]
  if da.target_effects ~= nil and da.target_effects.type ~= nil then da.target_effects = { da.target_effects } end
  if not (dernier.type == "script" and dernier.effect_id == T.ID and egal(relu, avant)) then
    error("[factorio-overhaul] prototypes/tirs.lua : l'AmmoType « turret » de " .. n .. " differe du sien hors effet script")
  end
  -- moteur réel : dans une LISTE d'AmmoType, chaque entrée exige source_type (« Key "source_type" not found », F357)
  base.source_type = "default"
  item.ammo_type = { base, tourelle }
end
-- Sons déclarés (contrôle de l'étape data, lu au journal du banc : l'API runtime 1.1.91 n'expose pas les sons) : chaque
-- mitrailleuse d'un âge témoin porte 1 + #couches couches (S0 de l'ère, puis celles de la table), chaque niveau de
-- l'âge 15 du laser porte son faisceau déclaré.
local L = require("shared.levels.config")
local sons = {}
for _, f in ipairs(L.families) do
  for n = 2, f.max do
    local e = L.epoch_of(f, n)
    local A = T.ages[e]
    local p = A and data.raw[f.type] and data.raw[f.type][L.name(f, n)]
    if p and f.key == "gun" then
      local voulu = A.son and (1 + #A.son.couches) or 0
      local snd = p.attack_parameters.sound
      local vu = (snd and snd.layers) and #snd.layers or 0
      if vu ~= voulu then
        error("[factorio-overhaul] prototypes/tirs.lua : " .. p.name .. " porte " .. vu .. " couche(s) de son, attendu " .. voulu)
      end
      sons[#sons + 1] = p.name .. "=" .. (vu == 0 and "S0" or (vu .. " couches"))
    elseif p and f.key == "laser" and A.laser then
      local d = p.attack_parameters.ammo_type.action.action_delivery
      if d.beam ~= L.name(f, n) .. "-faisceau" then
        error("[factorio-overhaul] prototypes/tirs.lua : " .. p.name .. " tire " .. tostring(d.beam) .. ", attendu son faisceau")
      end
      sons[#sons + 1] = p.name .. "=" .. d.beam
    end
  end
end
log("[FO-TIRS] sons et faisceaux des ages temoins : " .. table.concat(sons, " "))
log("[FO-TIRS] " .. #out .. " prototype(s) d'effets (ages " .. table.concat(T.temoins, ", ") .. ") ; chargeurs a effet "
  .. "script pour les tourelles : " .. #noms .. " (" .. table.concat(noms, ", ") .. ")")
